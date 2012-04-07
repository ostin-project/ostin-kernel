;;======================================================================================================================
;;///// fat32.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
;; (c) 2002-2004 MenuetOS <http://menuetos.net/>
;;======================================================================================================================
;; This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
;; License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later
;; version.
;;
;; This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License along with this program. If not, see
;; <http://www.gnu.org/licenses/>.
;;======================================================================================================================

struct fs.fat16x.partition_data_t
  sectors_per_fat     dd ?
  number_of_fats      dd ?
  sectors_per_cluster dd ?
  bytes_per_sector    dd ? ; Note: if BPS <> 512 need lots of changes
  root_cluster        dd ? ; first rootdir cluster
  fat_start           dd ? ; start of fat table
  root_start          dd ? ; start of rootdir (only fat16)
  root_sectors        dd ? ; count of rootdir sectors (only fat16)
  data_start          dd ? ; start of data area (=first cluster 2)
  last_cluster        dd ? ; last availabe cluster
  adr_fsinfo          dd ? ; used only by fat32
  fatRESERVED         dd ?
  fatBAD              dd ?
  fatEND              dd ?
  fatMASK             dd ?
  fatStartScan        dd ?
ends

iglobal
  fs.fat16x.vftbl dd \
    fat32_HdRead, \
    fat32_HdReadFolder, \
    fat32_HdRewrite, \
    fat32_HdWrite, \
    fat32_HdSetFileEnd, \
    fat32_HdGetFileInfo, \
    fat32_HdSetFileInfo, \
    fs.error.not_implemented, \
    fat32_HdDelete, \
    fat32_HdRewrite
endg

uglobal
  align 4
  longname_sec1        dd 0   ; used by analyze_directory to save 2 previous
  longname_sec2        dd 0   ; directory sectors for delete long filename

  cluster_tmp          dd 0   ; used by analyze_directory and analyze_directory_to_write

  file_size            dd 0   ; used by file_read
endg

uglobal
  align 4
  fat_cache:           rb 512
  Sector512:                  ; label for dev_hdcd.inc
  buffer:              rb 512
  fsinfo_buffer:       rb 512
endg

uglobal
  fat16_root           db 0   ; flag for fat16 rootdir
  fat_change           db 0   ; 1=fat has changed
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc set_FAT ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = cluster
;> edx = value to save
;-----------------------------------------------------------------------------------------------------------------------
;< edx = old value
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx esi

        cmp     eax, 2
        jb      .sfc_error
        cmp     eax, [fat16x_data.last_cluster]
        ja      .sfc_error
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT16
        je      .sfc_1
        add     eax, eax

  .sfc_1:
        add     eax, eax
        mov     esi, 511
        and     esi, eax ; esi = position in fat sector
        shr     eax, 9 ; eax = fat sector
        add     eax, [fat16x_data.fat_start]
        mov     ebx, fat_cache

        cmp     eax, [fat_in_cache] ; is fat sector already in memory?
        je      .sfc_in_cache ; yes

        cmp     [fat_change], 0 ; is fat changed?
        je      .sfc_no_change ; no
        call    write_fat_sector ; yes. write it into disk
        cmp     [hd_error], 0
        jne     .sfc_error

  .sfc_no_change:
        mov     [fat_in_cache], eax ; save fat sector
        call    hd_read
        cmp     [hd_error], 0
        jne     .sfc_error

  .sfc_in_cache:
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT16
        jne     .sfc_test32

  .sfc_set16:
        xchg    [ebx + esi], dx ; save new value and get old value
        jmp     .sfc_write

  .sfc_test32:
        mov     eax, [fat16x_data.fatMASK]

  .sfc_set32:
        and     edx, eax
        xor     eax, -1 ; mask for high bits
        and     eax, [ebx + esi] ; get high 4 bits
        or      eax, edx
        mov     edx, [ebx + esi] ; get old value
        mov     [ebx + esi], eax ; save new value

  .sfc_write:
        mov     [fat_change], 1 ; fat has changed

  .sfc_nonzero:
        and     edx, [fat16x_data.fatMASK]

  .sfc_error:
        pop     esi ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_FAT ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = cluster
;-----------------------------------------------------------------------------------------------------------------------
;< eax = next cluster
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx esi

        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT16
        je      .gfc_1
        add     eax, eax

  .gfc_1:
        add     eax, eax
        mov     esi, 511
        and     esi, eax ; esi = position in fat sector
        shr     eax, 9 ; eax = fat sector
        add     eax, [fat16x_data.fat_start]
        mov     ebx, fat_cache

        cmp     eax, [fat_in_cache] ; is fat sector already in memory?
        je      .gfc_in_cache

        cmp     [fat_change], 0 ; is fat changed?
        je      .gfc_no_change ; no
        call    write_fat_sector ; yes. write it into disk
        cmp     [hd_error], 0
        jne     .hd_error_01

  .gfc_no_change:
        mov     [fat_in_cache], eax
        call    hd_read
        cmp     [hd_error], 0
        jne     .hd_error_01

  .gfc_in_cache:
        mov     eax, [ebx + esi]
        and     eax, [fat16x_data.fatMASK]

  .hd_error_01:
        pop     esi ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_free_FAT ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 0, eax = # first cluster found free
;< if CF = 1, disk full
;-----------------------------------------------------------------------------------------------------------------------
;# Note: for more speed need to use fat_cache directly
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     ecx, [fat16x_data.last_cluster] ; counter for full disk
        sub     ecx, 2
        mov     eax, [fat16x_data.fatStartScan]
        cmp     eax, 2
        jb      .gff_reset

  .gff_test:
        cmp     eax, [fat16x_data.last_cluster] ; if above last cluster start at cluster 2
        jbe     .gff_in_range

  .gff_reset:
        mov     eax, 2

  .gff_in_range:
        push    eax
        call    get_FAT ; get cluster state
        cmp     [hd_error], 0
        jne     .gff_not_found_1

        test    eax, eax ; is it free?
        pop     eax
        je      .gff_found ; yes
        inc     eax ; next cluster
        dec     ecx ; is all checked?
        jns     .gff_test ; no

  .gff_not_found_1:
        add     esp, 4

  .gff_not_found:
        pop     ecx ; yes. disk is full
        stc
        ret

  .gff_found:
        lea     ecx, [eax + 1]
        mov     [fat16x_data.fatStartScan], ecx
        pop     ecx
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc write_fat_sector ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? write changed fat to disk
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx

        mov     [fat_change], 0
        mov     eax, [fat_in_cache]
        cmp     eax, -1
        jz      .write_fat_not_used
        mov     ebx, fat_cache
        mov     ecx, [fat16x_data.number_of_fats]

  .write_next_fat:
        call    hd_write
        cmp     [hd_error], 0
        jne     .write_fat_not_used

        add     eax, [fat16x_data.sectors_per_fat]
        dec     ecx
        jnz     .write_next_fat

  .write_fat_not_used:
        pop     ecx ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc analyze_directory ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> EAX = first cluster of the directory
;> EBX = pointer to filename
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 0, eax = sector where th file is found
;<            ebx = pointer in buffer [buffer .. buffer+511]
;<            ecx, edx, esi, edi not changed
;< if CF = 1, filename not found
;-----------------------------------------------------------------------------------------------------------------------
;# Note: if cluster = 0, it's changed to read rootdir
;#       save 2 previous directory sectors in longname_sec
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx esi edi ebx ; ebx = [esp+0]
        mov     [longname_sec1], 0
        mov     [longname_sec2], 0

  .adr_new_cluster:
        mov     [cluster_tmp], eax
        mov     [fat16_root], 0
        cmp     eax, [fat16x_data.last_cluster]
        ja      .adr_not_found ; too big cluster number, something is wrong
        cmp     eax, 2
        jnb     .adr_data_cluster

        mov     eax, [fat16x_data.root_cluster] ; if cluster < 2 then read rootdir
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT16
        jne     .adr_data_cluster
        mov     eax, [fat16x_data.root_start]
        mov     edx, [fat16x_data.root_sectors]
        mov     [fat16_root], 1 ; flag for fat16 rootdir
        jmp     .adr_new_sector

  .adr_data_cluster:
        sub     eax, 2
        mov     edx, [fat16x_data.sectors_per_cluster]
        imul    eax, edx
        add     eax, [fat16x_data.data_start]

  .adr_new_sector:
        mov     ebx, buffer
        call    hd_read
        cmp     [hd_error], 0
        jne     .adr_not_found

        mov     ecx, 512 / sizeof.fs.fat.dir_entry_t ; count of dir entrys per sector = 16

  .adr_analyze:
        movzx   edi, [ebx + fs.fat.dir_entry_t.attributes] ; file attribute
        and     edi, FS_FAT_ATTR_LONG_NAME_MASK
        cmp     edi, FS_FAT_ATTR_LONG_NAME
        je      .adr_long_filename
        test    edi, FS_FAT_ATTR_VOLUME_ID ; skip over volume label
        jne     .adr_long_filename ; Note: label can be same name as file/dir

        mov     esi, [esp + 0] ; filename need to be uppercase
        mov     edi, ebx
        push    ecx
        mov     ecx, 11
        rep
        cmpsb   ; compare 8+3 filename
        pop     ecx
        je      .adr_found

  .adr_long_filename:
        add     ebx, sizeof.fs.fat.dir_entry_t ; position of next dir entry
        dec     ecx
        jnz     .adr_analyze

        mov     ecx, [longname_sec1] ; save 2 previous directory sectors
        mov     [longname_sec1], eax ; for delete long filename
        mov     [longname_sec2], ecx
        inc     eax ; next sector
        dec     edx
        jne     .adr_new_sector
        cmp     [fat16_root], 1 ; end of fat16 rootdir
        je      .adr_not_found

  .adr_next_cluster:
        mov     eax, [cluster_tmp]
        call    get_FAT ; get next cluster
        cmp     [hd_error], 0
        jne     .adr_not_found

        cmp     eax, 2 ; incorrect fat chain?
        jb      .adr_not_found ; yes
        cmp     eax, [fat16x_data.fatRESERVED] ; is it end of directory?
        jb      .adr_new_cluster ; no. analyse it

  .adr_not_found:
        pop     edi edi esi edx ecx ; first edi will remove ebx
        stc     ; file not found
        ret

  .adr_found:
        pop     edi edi esi edx ecx ; first edi will remove ebx
        clc     ; file found
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_data_cluster ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = cluster
;> ebx = pointer to buffer
;> edx = # blocks to read in buffer
;> esi = # blocks to skip over
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 0 (ok), ebx/edx/esi updated
;< if CF = 1, cluster out of range
;-----------------------------------------------------------------------------------------------------------------------
;# Note: if cluster = 0, it's changed to read rootdir
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx

        mov     [fat16_root], 0
        cmp     eax, [fat16x_data.last_cluster]
        ja      .gdc_error ; too big cluster number, something is wrong
        cmp     eax, 2
        jnb     .gdc_cluster

        mov     eax, [fat16x_data.root_cluster] ; if cluster < 2 then read rootdir
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT16
        jne     .gdc_cluster
        mov     eax, [fat16x_data.root_start]
        mov     ecx, [fat16x_data.root_sectors] ; Note: not cluster size
        mov     [fat16_root], 1 ; flag for fat16 rootdir
        jmp     .gdc_read

  .gdc_cluster:
        sub     eax, 2
        mov     ecx, [fat16x_data.sectors_per_cluster]
        imul    eax, ecx
        add     eax, [fat16x_data.data_start]

  .gdc_read:
        test    esi, esi ; first wanted block
        je      .gdcl1 ; yes, skip count is 0
        dec     esi
        jmp     .gdcl2

  .gdcl1:
        call    hd_read
        cmp     [hd_error], 0
        jne     .gdc_error

        add     ebx, 512 ; update pointer
        dec     edx

  .gdcl2:
        test    edx, edx ; is all read?
        je      .out_of_read

        inc     eax ; next sector
        dec     ecx
        jnz     .gdc_read

  .out_of_read:
        pop     ecx eax
        clc
        ret

  .gdc_error:
        pop     ecx eax
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_cluster_of_a_path ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to a path string
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 1, ERROR in the PATH
;< if CF = 0, eax = cluster
;-----------------------------------------------------------------------------------------------------------------------
;# example: the path
;#   "/files/data/document"
;# become
;#   "files......data.......document...0"
;# '.' = space char
;# '0' = char(0)
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx edx

        mov     eax, [fat16x_data.root_cluster]
        mov     edx, ebx

  .search_end_of_path:
        cmp     byte[edx], 0
        je      .found_end_of_path

        inc     edx ; '/'
        mov     ebx, edx
        call    analyze_directory
        jc      .directory_not_found

        mov     eax, dword[ebx + fs.fat.dir_entry_t.start_cluster.high - 2] ; read the HIGH 16bit cluster field
        mov     ax, [ebx + fs.fat.dir_entry_t.start_cluster.low] ; read the LOW 16bit cluster field
        and     eax, [fat16x_data.fatMASK]
        add     edx, 11 ; 8+3 (name+extension)
        jmp     .search_end_of_path

  .found_end_of_path:
        pop     edx ebx
        clc     ; no errors
        ret

  .directory_not_found:
        pop     edx ebx
        stc     ; errors occour
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc add_disk_free_space ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = cluster count
;-----------------------------------------------------------------------------------------------------------------------
;# Note: negative = remove clusters from free space
;#       positive = add clusters to free space
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx ; no change
        je      .add_dfs_no
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT32 ; free disk space only used by fat32
        jne     .add_dfs_no

        push    eax ebx
        mov     eax, [fat16x_data.adr_fsinfo]
        mov     ebx, fsinfo_buffer
        call    hd_read
        cmp     [hd_error], 0
        jne     .add_not_fs

        cmp     dword[ebx + 0x1fc], 0xaa550000 ; check sector id
        jne     .add_not_fs

        add     [ebx + 0x1e8], ecx
        mov_s_  dword[ebx + 0x1ec], [fat16x_data.fatStartScan]
        call    hd_write
;       cmp     [hd_error], 0
;       jne     .add_not_fs

  .add_not_fs:
        pop     ebx eax

  .add_dfs_no:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc file_read ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi = system call to write
;> eax = pointer to file-name
;> ecx = pointer to buffer
;> ebx = file blocks to read
;> edx = pointer to path
;> esi = first 512 block to read
;> edi = if 0 - read root
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = size of file/directory
;-----------------------------------------------------------------------------------------------------------------------
;# Error codes:
;#  3 - unknown FS
;#  5 - file not found
;#  6 - end of file
;#  9 - fat table corrupted
;#  10 - access denied
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT16
        jz      .fat_ok_for_reading
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT32
        jz      .fat_ok_for_reading
        xor     ebx, ebx
        mov     eax, ERROR_UNKNOWN_FS
        mov     [hd1_status], ebx
        ret

  .fat_ok_for_reading:
;       call    reserve_hd1

        pushad

        mov     ebx, edx
        call    get_cluster_of_a_path
        jc      .file_to_read_not_found

        test    edi, edi ; read rootdir
        jne     .no_read_root

        xor     eax, eax
        call    get_dir_size ; return rootdir size
        cmp     [hd_error], 0
        jne     .file_access_denied

        mov     [file_size], eax
        mov     eax, [fat16x_data.root_cluster]
        jmp     .file_read_start

  .no_read_root:
        mov     ebx, [esp + regs_context32_t.eax] ; file name
        call    analyze_directory
        jc      .file_to_read_not_found

        mov     eax, [ebx + fs.fat.dir_entry_t.size] ; file size
        test    [ebx + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY ; is it directory?
        jz      .read_set_size ; no

        mov     eax, dword[ebx + fs.fat.dir_entry_t.start_cluster.high - 2] ; FAT entry
        mov     ax, [ebx + fs.fat.dir_entry_t.start_cluster.low]
        and     eax, [fat16x_data.fatMASK]
        call    get_dir_size
        cmp     [hd_error], 0
        jne     .file_access_denied

  .read_set_size:
        mov     [file_size], eax

        mov     eax, dword[ebx + fs.fat.dir_entry_t.start_cluster.high - 2] ; FAT entry
        mov     ax, [ebx + fs.fat.dir_entry_t.start_cluster.low]
        and     eax, [fat16x_data.fatMASK]

  .file_read_start:
        mov     ebx, [esp + regs_context32_t.ecx] ; pointer to buffer
        mov     edx, [esp + regs_context32_t.ebx] ; file blocks to read
        mov     esi, [esp + regs_context32_t.esi] ; first 512 block to read

  .file_read_new_cluster:
        call    get_data_cluster
        jc      .file_read_eof ; end of file or cluster out of range

        test    edx, edx ; is all read?
        je      .file_read_OK ; yes

        call    get_FAT ; get next cluster
        cmp     [hd_error], 0
        jne     .file_access_denied

        cmp     eax, [fat16x_data.fatRESERVED] ; end of file
        jnb     .file_read_eof
        cmp     eax, 2 ; incorrect fat chain
        jnb     .file_read_new_cluster

        popad
        mov     [hd1_status], 0
        mov     ebx, [file_size]
        mov     eax, ERROR_FAT_TABLE
        ret

  .file_read_eof:
        cmp     [hd_error], 0
        jne     .file_access_denied
        popad
        mov     [hd1_status], 0
        mov     ebx, [file_size]
        mov     eax, ERROR_END_OF_FILE
        ret

  .file_read_OK:
        popad
        mov     [hd1_status], 0
        mov     ebx, [file_size]
        xor     eax, eax ; ERROR_SUCCESS
        ret

  .file_to_read_not_found:
        cmp     [hd_error], 0
        jne     .file_access_denied
        popad
        mov     [hd1_status], 0
        xor     ebx, ebx
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

  .file_access_denied:
        popad
        mov     [hd1_status], 0
        xor     ebx, ebx
        mov     eax, ERROR_ACCESS_DENIED
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_dir_size ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = first cluster (0 = rootdir)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = directory size in bytes
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        xor     edx, edx ; count of directory clusters
        test    eax, eax
        jnz     .dir_size_next

        mov     eax, [fat16x_data.root_sectors]
        shl     eax, 9 ; fat16 rootdir size in bytes
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT16
        je      .dir_size_ret
        mov     eax, [fat16x_data.root_cluster]

  .dir_size_next:
        cmp     eax, 2 ; incorrect fat chain
        jb      .dir_size_end
        cmp     eax, [fat16x_data.fatRESERVED] ; end of directory
        ja      .dir_size_end
        call    get_FAT ; get next cluster
        cmp     [hd_error], 0
        jne     .dir_size_ret

        inc     edx
        jmp     .dir_size_next

  .dir_size_end:
        imul    eax, [fat16x_data.sectors_per_cluster], 512 ; cluster size in bytes
        imul    eax, edx

  .dir_size_ret:
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc clear_cluster_chain ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = first cluster
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx
        xor     ecx, ecx ; cluster count

  .clean_new_chain:
        cmp     eax, [fat16x_data.last_cluster] ; end of file
        ja      .delete_OK
        cmp     eax, 2 ; unfinished fat chain or zero length file
        jb      .delete_OK
        cmp     eax, [fat16x_data.root_cluster] ; don't remove root cluster
        jz      .delete_OK

        xor     edx, edx
        call    set_FAT ; clear fat entry
        cmp     [hd_error], 0
        jne     .access_denied_01

        inc     ecx ; update cluster count
        mov     eax, edx ; old cluster
        jmp     .clean_new_chain

  .delete_OK:
        call    add_disk_free_space ; add clusters to free disk space

  .access_denied_01:
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc update_disk ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? write changed fat and cache to disk
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [fat_change], 0 ; is fat changed?
        je      .upd_no_change

        call    write_fat_sector
        cmp     [hd_error], 0
        jne     .update_disk_acces_denied

  .upd_no_change:
        call    write_cache

  .update_disk_acces_denied:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_find_lfn ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi + ebp = pointer to name
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 1, file not found
;< if CF = 0,
;<   edi = pointer to direntry
;<   eax = sector
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi
        push    0
        push    0
        push    fat16_root_first
        push    fat16_root_next
        mov     eax, [fat16x_data.root_cluster]
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT32
        jz      .fat32

  .loop:
        call    fs.fat.util.find_long_name
        jc      .notfound
        cmp     byte[esi], 0
        jz      .found

  .continue:
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .notfound
        and     dword[esp + 12], 0
        mov     eax, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     ax, [edi + fs.fat.dir_entry_t.start_cluster.low] ; cluster

  .fat32:
        mov     [esp + 8], eax
        mov     dword[esp + 4], fat_notroot_first
        mov     dword[esp], fat_notroot_next
        jmp     .loop

  .notfound:
        add     esp, 16
        pop     edi esi
        stc
        ret

  .found:
        test    ebp, ebp
        jz      @f
        mov     esi, ebp
        xor     ebp, ebp
        jmp     .continue

    @@: lea     eax, [esp + 8]
        cmp     dword[eax], 0
        jz      .root
        call    fat_get_sector
        jmp     .cmn

  .root:
        mov     eax, [eax + 4]
        add     eax, [fat16x_data.root_start]

  .cmn:
        add     esp, 20 ; CF=0
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat32_HdRead ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for reading hard disk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to 64-bit number = first wanted byte, 0+
;> ecx = number of bytes to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = bytes read or -1 (file not found)
;-----------------------------------------------------------------------------------------------------------------------
;# if ebx = 0, start from first byte
;-----------------------------------------------------------------------------------------------------------------------
        push    edi

        call    hd_find_lfn
        jnc     .found

        pop     edi
        cmp     [hd_error], 0
        jne     fs.error.access_denied
        jmp     fs.error.file_not_found

  .noaccess:
        pop     edi
        jmp     fs.error.access_denied

  .found:
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY ; do not allow read directories
        jnz     .noaccess
        test    ebx, ebx
        jz      .l1
        cmp     dword[ebx + 4], 0
        jz      @f
        xor     ebx, ebx

  .reteof:
        mov     eax, ERROR_END_OF_FILE
        pop     edi
        ret

    @@: mov     ebx, [ebx]

  .l1:
        push    ecx edx
        push    ERROR_SUCCESS
        mov     eax, [edi + fs.fat.dir_entry_t.size]
        sub     eax, ebx
        jb      .eof
        cmp     eax, ecx
        jae     @f
        mov     ecx, eax
        mov     byte[esp], ERROR_END_OF_FILE

    @@: mov     eax, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     ax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        ; now eax=cluster, ebx=position, ecx=count, edx=buffer for data

  .new_cluster:
        jecxz   .new_sector
        test    eax, eax
        jz      .eof
        cmp     eax, [fat16x_data.fatRESERVED]
        jae     .eof
        mov     [cluster_tmp], eax
        dec     eax
        dec     eax
        mov     edi, [fat16x_data.sectors_per_cluster]
        imul    eax, edi
        add     eax, [fat16x_data.data_start]

  .new_sector:
        test    ecx, ecx
        jz      .done
        sub     ebx, 512
        jae     .skip
        add     ebx, 512
        jnz     .force_buf
        cmp     ecx, 512
        jb      .force_buf
        ; we may read directly to given buffer
        push    ebx
        mov     ebx, edx
        call    hd_read
        pop     ebx
        cmp     [hd_error], 0
        jne     .noaccess_1
        add     edx, 512
        sub     ecx, 512
        jmp     .skip

  .force_buf:
        ; we must read sector to temporary buffer and then copy it to destination
        push    eax ebx
        mov     ebx, buffer
        call    hd_read
        mov     eax, ebx
        pop     ebx
        cmp     [hd_error], 0
        jne     .noaccess_3
        add     eax, ebx
        push    ecx
        add     ecx, ebx
        cmp     ecx, 512
        jbe     @f
        mov     ecx, 512

    @@: sub     ecx, ebx
        mov     ebx, edx
        call    memmove
        add     edx, ecx
        sub     [esp], ecx
        pop     ecx
        pop     eax
        xor     ebx, ebx

  .skip:
        inc     eax
        dec     edi
        jnz     .new_sector
        mov     eax, [cluster_tmp]
        call    get_FAT
        cmp     [hd_error], 0
        jne     .noaccess_1

        jmp     .new_cluster

  .noaccess_3:
        pop     eax

  .noaccess_1:
        pop     eax
        push    ERROR_DEVICE_FAIL

  .done:
        mov     ebx, edx
        pop     eax edx ecx edi
        sub     ebx, edx
        ret

  .eof:
        mov     ebx, edx
        pop     eax edx ecx
        sub     ebx, edx
        jmp     .reteof
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat32_HdReadFolder ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for reading hard disk folder
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to structure 32-bit number = first wanted block, 0+ & flags (bitfields)
;> ecx = number of blocks to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< ebx = blocks read or -1 (folder not found)
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
;# flags:
;#   bit 0: 0 (ANSI names) or 1 (UNICODE names)
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [fat16x_data.root_cluster]
        push    edi
        cmp     byte[esi], 0
        jz      .doit

        call    hd_find_lfn
        jnc     .found

        pop     edi
        jmp     fs.error.file_not_found

  .found:
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY ; do not allow read files
        jnz     .found_dir

        pop     edi
        jmp     fs.error.access_denied

  .found_dir:
        mov     eax, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     ax, [edi + fs.fat.dir_entry_t.start_cluster.low] ; eax=cluster

  .doit:
        push    esi ecx
        push    ebp
        sub     esp, 262 * 2 ; reserve space for LFN
        mov     ebp, esp
        push    dword[ebx + 4] ; for fs.fat.get_name: read ANSI/UNICODE name
        mov     ebx, [ebx]
        ; init header
        push    eax ecx
        mov     edi, edx
        mov     ecx, sizeof.fs.file_info_header_t / 4
        xor     eax, eax
        rep
        stosd
        pop     ecx eax
        mov     byte[edx + fs.file_info_header_t.version], 1 ; version
        mov     esi, edi ; esi points to BDFE

  .new_cluster:
        mov     [cluster_tmp], eax
        test    eax, eax
        jnz     @f
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT32
        jz      .notfound
        mov     eax, [fat16x_data.root_start]
        push    [fat16x_data.root_sectors]
        push    ebx
        jmp     .new_sector

    @@: dec     eax
        dec     eax
        imul    eax, [fat16x_data.sectors_per_cluster]
        push    [fat16x_data.sectors_per_cluster]
        add     eax, [fat16x_data.data_start]
        push    ebx

  .new_sector:
        mov     ebx, buffer
        mov     edi, ebx
        call    hd_read
        cmp     [hd_error], 0
        jnz     .notfound2
        add     ebx, 512
        push    eax

  .l1:
        call    fs.fat.util.get_name
        jc      .l2
        cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        jnz     .do_bdfe
        add     edi, sizeof.fs.fat.dir_entry_t
        cmp     edi, ebx
        jb      .do_bdfe
        pop     eax
        inc     eax
        dec     dword[esp + 4]
        jnz     @f
        mov     eax, [cluster_tmp]
        test    eax, eax
        jz      .done
        call    get_FAT
        cmp     [hd_error], 0
        jnz     .notfound2
        cmp     eax, 2
        jb      .done
        cmp     eax, [fat16x_data.fatRESERVED]
        jae     .done
        push    eax
        mov     eax, [fat16x_data.sectors_per_cluster]
        mov     [esp + 8], eax
        pop     eax
        mov     [cluster_tmp], eax
        dec     eax
        dec     eax
        imul    eax, [fat16x_data.sectors_per_cluster]
        add     eax, [fat16x_data.data_start]

    @@: mov     ebx, buffer
        mov     edi, ebx
        call    hd_read
        cmp     [hd_error], 0
        jnz     .notfound2
        add     ebx, 512
        push    eax

  .do_bdfe:
        inc     dword[edx + fs.file_info_header_t.files_count] ; new file found
        dec     dword[esp + 4]
        jns     .l2
        dec     ecx
        js      .l2
        inc     dword[edx + fs.file_info_header_t.files_read] ; new file block copied
        call    fs.fat.util.fat_entry_to_bdfe

  .l2:
        add     edi, sizeof.fs.fat.dir_entry_t
        cmp     edi, ebx
        jb      .l1
        pop     eax
        inc     eax
        dec     dword[esp + 4]
        jnz     .new_sector
        mov     eax, [cluster_tmp]
        test    eax, eax
        jz      .done
        call    get_FAT
        cmp     [hd_error], 0
        jnz     .notfound2
        cmp     eax, 2
        jb      .done
        cmp     eax, [fat16x_data.fatRESERVED]
        jae     .done
        push    eax
        mov     eax, [fat16x_data.sectors_per_cluster]
        mov     [esp + 8], eax
        pop     eax
        pop     ebx
        add     esp, 4
        jmp     .new_cluster

  .notfound2:
        add     esp, 8

  .notfound:
        add     esp, 262 * 2 + 4
        pop     ebp ecx esi edi
        jmp     fs.error.file_not_found

  .done:
        add     esp, 262 * 2 + 4 + 8
        pop     ebp
        mov     ebx, [edx + 4]
        xor     eax, eax ; ERROR_SUCCESS
        dec     ecx
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: pop     ecx esi edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat16_root_next ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edi, buffer + 0x200 - sizeof.fs.fat.dir_entry_t
        jae     fat16_root_next_sector
        add     edi, sizeof.fs.fat.dir_entry_t
        ret     ; CF=0
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat16_root_next_sector ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? read next sector
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  [longname_sec1], [longname_sec2]
        push    ecx
        mov     ecx, [eax + 4]
        push    ecx
        add     ecx, [fat16x_data.root_start]
        mov     [longname_sec2], ecx
        pop     ecx
        inc     ecx
        mov     [eax + 4], ecx
        cmp     ecx, [fat16x_data.root_sectors]
        pop     ecx
        jae     fat16_root_first.readerr
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat16_root_first ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax + 4]
        add     eax, [fat16x_data.root_start]
        push    ebx
        mov     edi, buffer
        mov     ebx, edi
        call    hd_read
        pop     ebx
        cmp     [hd_error], 0
        jnz     .readerr
        ret     ; CF=0

  .readerr:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat16_root_begin_write ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edi eax
        call    fat16_root_first
        pop     eax edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat16_root_end_write ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax + 4]
        add     eax, [fat16x_data.root_start]
        mov     ebx, buffer
        call    hd_write
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat16_root_next_write ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edi, buffer + 0x200
        jae     @f
        ret

    @@: call    fat16_root_end_write
        jmp     fat16_root_next_sector
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat16_root_extend_dir ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_next ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edi, buffer + 0x200 - sizeof.fs.fat.dir_entry_t
        jae     fat_notroot_next_sector
        add     edi, sizeof.fs.fat.dir_entry_t
        ret     ; CF=0
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_next_sector ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  [longname_sec1], [longname_sec2]
        push    eax
        call    fat_get_sector
        mov     [longname_sec2], eax
        pop     eax
        push    ecx
        mov     ecx, [eax + 4]
        inc     ecx
        cmp     ecx, [fat16x_data.sectors_per_cluster]
        jae     fat_notroot_next_cluster
        mov     [eax + 4], ecx
        jmp     @f
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_next_cluster ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [eax]
        call    get_FAT
        mov     ecx, eax
        pop     eax
        cmp     [hd_error], 0
        jnz     fat_notroot_next_err
        cmp     ecx, [fat16x_data.fatRESERVED]
        jae     fat_notroot_next_err
        mov     [eax], ecx
        and     dword[eax + 4], 0

    @@: pop     ecx
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_first ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    fat_get_sector
        push    ebx
        mov     edi, buffer
        mov     ebx, edi
        call    hd_read
        pop     ebx
        cmp     [hd_error], 0
        jnz     @f
        ret     ; CF=0
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_next_err ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pop     ecx

    @@: stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_begin_write ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edi
        call    fat_notroot_first
        pop     edi eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_end_write ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    fat_get_sector
        push    ebx
        mov     ebx, buffer
        call    hd_write
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_next_write ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edi, buffer + 0x200
        jae     @f
        ret

    @@: push    eax
        call    fat_notroot_end_write
        pop     eax
        jmp     fat_notroot_next_sector
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_notroot_extend_dir ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        call    get_free_FAT
        jnc     .found
        pop     eax
        ret     ; CF=1

  .found:
        push    edx
        mov     edx, [fat16x_data.fatEND]
        call    set_FAT
        mov     edx, eax
        mov     eax, [esp + 4]
        mov     eax, [eax]
        push    edx
        call    set_FAT
        pop     edx
        cmp     [hd_error], 0
        jz      @f
        pop     edx
        pop     eax
        stc
        ret

    @@: push    ecx
        or      ecx, -1
        call    add_disk_free_space
        ; zero new cluster
        mov     ecx, 512 / 4
        mov     edi, buffer
        push    edi
        xor     eax, eax
        rep
        stosd
        pop     edi
        pop     ecx
        mov     eax, [esp + 4]
        mov     [eax], edx
        and     dword[eax + 4], 0
        pop     edx
        mov     eax, [eax]
        dec     eax
        dec     eax
        push    ebx ecx
        mov     ecx, [fat16x_data.sectors_per_cluster]
        imul    eax, ecx
        add     eax, [fat16x_data.data_start]
        mov     ebx, edi

    @@: call    hd_write
        inc     eax
        loop    @b
        pop     ecx ebx eax
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_get_sector ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     ecx, [eax]
        dec     ecx
        dec     ecx
        imul    ecx, [fat16x_data.sectors_per_cluster]
        add     ecx, [fat16x_data.data_start]
        add     ecx, [eax + 4]
        mov     eax, ecx
        pop     ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat32_HdRewrite ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for writing hard disk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ecx = number of bytes to write, 0+
;> edx = mem location to data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = number of written bytes
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        xor     edi, edi
        push    esi
        test    ebp, ebp
        jz      @f
        mov     esi, ebp

    @@: lodsb
        test    al, al
        jz      @f
        cmp     al, '/'
        jnz     @b
        lea     edi, [esi - 1]
        jmp     @b

    @@: pop     esi
        test    edi, edi
        jnz     .noroot
        test    ebp, ebp
        jnz     .hasebp
        mov     ebp, [fat16x_data.root_cluster]
        cmp     [current_partition._.type], FS_PARTITION_TYPE_FAT32
        jz      .pushnotroot
        push    fat16_root_extend_dir
        push    fat16_root_end_write
        push    fat16_root_next_write
        push    fat16_root_begin_write
        xor     ebp, ebp
        push    ebp
        push    ebp
        push    fat16_root_first
        push    fat16_root_next
        jmp     .common1

  .hasebp:
        mov     eax, ERROR_ACCESS_DENIED
        cmp     byte[ebp], 0
        jz      .ret1
        push    ebp
        xor     ebp, ebp
        call    hd_find_lfn
        pop     esi
        jc      .notfound0
        jmp     .common0

  .noroot:
        mov     eax, ERROR_ACCESS_DENIED
        cmp     byte[edi + 1], 0
        jz      .ret1
        ; check existence
        mov     byte[edi], 0
        push    edi
        call    hd_find_lfn
        pop     esi
        mov     byte[esi], '/'
        jnc     @f

  .notfound0:
        mov     eax, ERROR_FILE_NOT_FOUND

  .ret1:
        mov     [esp + regs_context32_t.eax], eax
        popad
        xor     ebx, ebx
        ret

    @@: inc     esi

  .common0:
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY ; must be directory
        mov     eax, ERROR_ACCESS_DENIED
        jz      .ret1
        mov     ebp, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     bp, [edi + fs.fat.dir_entry_t.start_cluster.low] ; ebp=cluster
        mov     eax, ERROR_FAT_TABLE
        cmp     ebp, 2
        jb      .ret1

  .pushnotroot:
        push    fat_notroot_extend_dir
        push    fat_notroot_end_write
        push    fat_notroot_next_write
        push    fat_notroot_begin_write
        push    0
        push    ebp
        push    fat_notroot_first
        push    fat_notroot_next

  .common1:
        call    fs.fat.util.find_long_name
        jc      .notfound
        ; found
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .exists_file
        ; found directory; if we are creating directory, return OK,
        ;                  if we are creating file, say "access denied"
        add     esp, 32
        popad
        test    al, al
        jz      fs.error.access_denied

        xor     eax, eax ; ERROR_SUCCESS
        xor     ebx, ebx
        ret

  .exists_file:
        ; found file; if we are creating directory, return "access denied",
        ;             if we are creating file, delete existing file and continue
        cmp     [esp + 32 + regs_context32_t.al], 0
        jz      @f
        add     esp, 32
        popad
        jmp     fs.error.access_denied

    @@: ; delete FAT chain
        push    edi
        xor     eax, eax
        mov     [edi + fs.fat.dir_entry_t.size], eax ; zero size
        xor     ecx, ecx
        mov     eax, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     ax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        mov     [edi + fs.fat.dir_entry_t.start_cluster.high], cx
        mov     [edi + fs.fat.dir_entry_t.start_cluster.low], cx
        test    eax, eax
        jz      .done1

    @@: cmp     eax, [fat16x_data.fatRESERVED]
        jae     .done1
        push    edx
        xor     edx, edx
        call    set_FAT
        mov     eax, edx
        pop     edx
        inc     ecx
        jmp     @b

  .done1:
        pop     edi
        call    fs.fat.util.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax
        call    fs.fat.util.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax
        or      [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_ARCHIVE ; set 'archive' attribute
        jmp     .doit

  .notfound:
        ; file is not found; generate short name
        call    fs.fat.util.name_is_legal
        jc      @f
        add     esp, 32
        popad
        jmp     fs.error.file_not_found

    @@: sub     esp, 12
        mov     edi, esp
        call    fs.fat.util.gen_short_name

  .test_short_name_loop:
        push    esi edi ecx
        mov     esi, edi
        lea     eax, [esp + 12 + 12 + 8]
        mov     [eax], ebp
        and     dword[eax + 4], 0
        call    dword[eax - 4]
        jc      .found

  .test_short_name_entry:
        cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        jz      .test_short_name_cont
        mov     ecx, 11
        push    esi edi
        repz
        cmpsb
        pop     edi esi
        jz      .short_name_found

  .test_short_name_cont:
        lea     eax, [esp + 12 + 12 + 8]
        call    dword[eax - 8]
        jnc     .test_short_name_entry
        jmp     .found

  .short_name_found:
        pop     ecx edi esi
        call    fs.fat.util.next_short_name
        jnc     .test_short_name_loop

  .disk_full:
        add     esp, 12 + 32
        popa
        jmp     fs.error.disk_full

  .found:
        pop     ecx edi esi
        ; now find space in directory
        ; we need to save LFN <=> LFN is not equal to short name <=> generated name contains '~'
        mov     al, '~'
        push    ecx edi
        mov     ecx, 8
        repnz
        scasb
        mov_s_  eax, 1 ; 1 entry
        jnz     .notilde
        ; we need ceil(strlen(esi)/13) additional entries = floor((strlen(esi)+12+13)/13) total
        xor     eax, eax

    @@: cmp     byte[esi], 0
        jz      @f
        inc     esi
        inc     eax
        jmp     @b

    @@: sub     esi, eax
        add     eax, 12 + 13
        mov     ecx, 13
        push    edx
        cdq
        div     ecx
        pop     edx

  .notilde:
        push    -1
        push    -1
        push    -1
        ; find <eax> successive entries in directory
        xor     ecx, ecx
        push    eax
        lea     eax, [esp + 16 + 8 + 12 + 8]
        mov     [eax], ebp
        and     dword[eax + 4], 0
        call    dword[eax - 4]
        pop     eax
        jnc     .scan_dir

  .fsfrfe3:
        add     esp, 12 + 8 + 12 + 32
        popad
        mov     eax, ERROR_DEVICE_FAIL
        xor     ebx, ebx
        ret

  .scan_dir:
        cmp     [edi + fs.fat.dir_entry_t.name], 0
        jz      .free
        cmp     [edi + fs.fat.dir_entry_t.name], 0xe5
        jz      .free
        xor     ecx, ecx

  .scan_cont:
        push    eax
        lea     eax, [esp + 16 + 8 + 12 + 8]
        call    dword[eax - 8]
        pop     eax
        jnc     .scan_dir
        cmp     [hd_error], 0
        jnz     .fsfrfe3
        push    eax
        lea     eax, [esp + 16 + 8 + 12 + 8]
        call    dword[eax + 20] ; extend directory
        pop     eax
        jnc     .scan_dir
        add     esp, 12 + 8 + 12 + 32
        popad
        jmp     fs.error.disk_full

  .free:
        test    ecx, ecx
        jnz     @f
        mov     [esp], edi
        mov     ecx, [esp + 12 + 8 + 12 + 8]
        mov     [esp + 4], ecx
        mov     ecx, [esp + 12 + 8 + 12 + 12]
        mov     [esp + 8], ecx
        xor     ecx, ecx

    @@: inc     ecx
        cmp     ecx, eax
        jb      .scan_cont
        ; found!
        ; calculate name checksum
        mov     eax, [esp + 12]
        call    fs.fat.util.calculate_name_checksum
        pop     edi
        pop     dword[esp + 8 + 12 + 12]
        pop     dword[esp + 8 + 12 + 12]
        ; edi points to first entry in free chunk
        dec     ecx
        jz      .nolfn
        push    esi
        push    eax
        lea     eax, [esp + 8 + 8 + 12 + 8]
        call    dword[eax + 8] ; begin write
        mov     al, 0x40

  .writelfn:
        or      al, cl
        mov     esi, [esp + 4]
        push    ecx
        dec     ecx
        imul    ecx, 13
        add     esi, ecx
        stosb
        mov     cl, 5
        call    fs.fat.util.read_symbols
        mov     ax, FS_FAT_ATTR_LONG_NAME
        stosw
        mov     al, [esp + 4]
        stosb
        mov     cl, 6
        call    fs.fat.util.read_symbols
        xor     eax, eax
        stosw
        mov     cl, 2
        call    fs.fat.util.read_symbols
        pop     ecx
        lea     eax, [esp + 8 + 8 + 12 + 8]
        call    dword[eax + 12] ; next write
        xor     eax, eax
        loop    .writelfn
        pop     eax
        pop     esi
;       lea     eax, [esp + 8 + 12 + 8]
;       call    dword[eax + 16] ; end write

  .nolfn:
        xchg    esi, [esp]
        mov     ecx, 11
        rep
        movsb
        mov     word[edi], FS_FAT_ATTR_ARCHIVE ; attributes
        sub     edi, 11
        pop     esi ecx
        add     esp, 12
        mov     [edi + fs.fat.dir_entry_t.created_at.time_ms], 0 ; tenths of a second at file creation time
        call    fs.fat.util.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.created_at.time], ax ; creation time
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax ; last write time
        call    fs.fat.util.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.created_at.date], ax ; creation date
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax ; last write date
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax ; last access date
        xor     ecx, ecx
        mov     [edi + fs.fat.dir_entry_t.start_cluster.high], cx ; high word of cluster
        mov     [edi + fs.fat.dir_entry_t.start_cluster.low], cx ; low word of cluster - to be filled
        mov     [edi + fs.fat.dir_entry_t.size], ecx ; file size - to be filled
        cmp     byte[esp + 32 + 28], cl
        jz      .doit
        ; create directory
        mov     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY ; attributes: folder
        mov     edx, edi
        lea     eax, [esp + 8]
        call    dword[eax + 16] ; flush directory
        push    ecx
        mov     ecx, [fat16x_data.sectors_per_cluster]
        shl     ecx, 9
        jmp     .doit2

  .doit:
        lea     eax, [esp + 8]
        call    dword[eax + 16] ; flush directory
        push    ecx
        mov     ecx, [esp + 4 + 32 + 24]

  .doit2:
        push    ecx
        push    edi
        mov     esi, edx
        test    ecx, ecx
        jz      .done
        call    get_free_FAT
        jc      .diskfull
        push    eax
        mov     [edi + fs.fat.dir_entry_t.start_cluster.low], ax
        shr     eax, 16
        mov     [edi + fs.fat.dir_entry_t.start_cluster.high], ax
        lea     eax, [esp + 16 + 8]
        call    dword[eax + 16] ; flush directory
        pop     eax
        push    edx
        mov     edx, [fat16x_data.fatEND]
        call    set_FAT
        pop     edx

  .write_cluster:
        push    eax
        dec     eax
        dec     eax
        mov     ebp, [fat16x_data.sectors_per_cluster]
        imul    eax, ebp
        add     eax, [fat16x_data.data_start]
        ; write data

  .write_sector:
        cmp     [esp + 16 + 32 + regs_context32_t.al], 0
        jnz     .writedir
        mov     ecx, 512
        cmp     dword[esp + 8], ecx
        jb      .writeshort
        ; we can write directly from given buffer
        mov     ebx, esi
        add     esi, ecx
        jmp     .writecommon

  .writeshort:
        mov     ecx, [esp + 8]
        push    ecx
        mov     edi, buffer
        mov     ebx, edi
        rep
        movsb

  .writedircont:
        mov     ecx, buffer + 0x200
        sub     ecx, edi
        push    eax
        xor     eax, eax
        rep
        stosb
        pop     eax
        pop     ecx

  .writecommon:
        call    hd_write
        cmp     [hd_error], 0
        jnz     .writeerr
        inc     eax
        sub     dword[esp + 8], ecx
        jz      .writedone
        dec     ebp
        jnz     .write_sector
        ; allocate new cluster
        pop     eax
        mov     ecx, eax
        call    get_free_FAT
        jc      .diskfull
        push    edx
        mov     edx, [fat16x_data.fatEND]
        call    set_FAT
        xchg    eax, ecx
        mov     edx, ecx
        call    set_FAT
        pop     edx
        xchg    eax, ecx
        jmp     .write_cluster

  .diskfull:
        mov     eax, ERROR_DISK_FULL
        jmp     .ret

  .writeerr:
        pop     eax
        sub     esi, ecx
        mov     eax, ERROR_DEVICE_FAIL
        jmp     .ret

  .writedone:
        pop     eax

  .done:
        xor     eax, eax ; ERROR_SUCCESS

  .ret:
        pop     edi ecx
        mov     ebx, esi
        sub     ebx, edx
        pop     ebp
        mov     [esp + 32 + regs_context32_t.eax], eax
        lea     eax, [esp + 8]
        call    dword[eax + 8]
        mov     [edi + fs.fat.dir_entry_t.size], ebx
        call    dword[eax + 16]
        mov     [esp + 32 + regs_context32_t.ebx], ebx
        lea     eax, [ebx + 511]
        shr     eax, 9
        mov     ecx, [fat16x_data.sectors_per_cluster]
        lea     eax, [eax + ecx - 1]
        xor     edx, edx
        div     ecx
        mov     ecx, ebp
        sub     ecx, eax
        call    add_disk_free_space
        add     esp, 32
        call    update_disk
        popad
        ret

  .writedir:
        push    512
        mov     edi, buffer
        mov     ebx, edi
        mov     ecx, [fat16x_data.sectors_per_cluster]
        shl     ecx, 9
        cmp     ecx, [esp + 12]
        jnz     .writedircont
        dec     dword[esp + 16]
        push    esi
        mov     ecx, sizeof.fs.fat.dir_entry_t / 4
        rep
        movsd
        pop     esi
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name], '.   '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 4], '    '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 8], '    '
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        push    esi
        mov     ecx, sizeof.fs.fat.dir_entry_t / 4
        rep
        movsd
        pop     esi
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name], '..  '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 4], '    '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 8], '    '
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        mov     ecx, [esp + 20 + 8]
        cmp     ecx, [fat16x_data.root_cluster]
        jnz     @f
        xor     ecx, ecx

    @@: mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.start_cluster.low], cx
        shr     ecx, 16
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.start_cluster.high], cx
        jmp     .writedircont
kendp

fat32_HdWrite.ret11:
        push    ERROR_DEVICE_FAIL

fat32_HdWrite.ret0:
        pop     eax
        xor     ebx, ebx
        ret

;-----------------------------------------------------------------------------------------------------------------------
kproc fat32_HdWrite ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for writing to hard disk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to 64-bit number = first wanted byte, 0+
;> ecx = number of bytes to write, 0+
;> edx = mem location to data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = bytes written (maybe 0)
;-----------------------------------------------------------------------------------------------------------------------
;# if ebx = 0, start from first byte
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        call    hd_find_lfn
        pushfd
        cmp     [hd_error], 0
        jz      @f
        popfd
        popad
        push    ERROR_DEVICE_FAIL
        jmp     .ret0

    @@: popfd
        jnc     .found
        popad
        jmp     fs.error.file_not_found

  .found:
        ; FAT does not support files larger than 4GB
        test    ebx, ebx
        jz      .l1
        cmp     dword[ebx + 4], 0
        jz      @f

  .eof:
        popad
        push    ERROR_END_OF_FILE
        jmp     .ret0

    @@: mov     ebx, [ebx]

  .l1:
        ; now edi points to direntry, ebx=start byte to write,
        ; ecx=number of bytes to write, edx=data pointer

        ; extend file if needed
        add     ecx, ebx
        jc      .eof ; FAT does not support files larger than 4GB
        push    eax ; save directory sector
        push    ERROR_SUCCESS ; return value=0

        call    fs.fat.util.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax ; last write time
        call    fs.fat.util.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax ; last write date
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax ; last access date

        push    [edi + fs.fat.dir_entry_t.size] ; save current file size
        cmp     ecx, [edi + fs.fat.dir_entry_t.size]
        jbe     .length_ok
        cmp     ecx, ebx
        jz      .length_ok
        call    hd_extend_file
        jnc     .length_ok
        mov     [esp + 4], eax
        ; hd_extend_file can return three error codes: FAT table error, device error or disk full.
        ; First two cases are fatal errors, in third case we may write some data
        cmp     al, ERROR_DISK_FULL
        jz      .disk_full
        pop     eax
        pop     eax
        mov     [esp + 4 + regs_context32_t.eax], eax
        pop     eax
        popad
        xor     ebx, ebx
        ret

  .disk_full:
        ; correct number of bytes to write
        mov     ecx, [edi + fs.fat.dir_entry_t.size]
        cmp     ecx, ebx
        ja      .length_ok

  .ret:
        call    update_disk
        cmp     [hd_error], 0
        jz      @f
        mov     byte[esp + 4], ERROR_DEVICE_FAIL

    @@: pop     eax
        pop     eax
        mov     [esp + 4 + regs_context32_t.eax], eax ; eax=return value
        pop     eax
        sub     edx, [esp + regs_context32_t.edx]
        mov     [esp + regs_context32_t.ebx], edx ; ebx=number of written bytes
        popad
        ret

  .length_ok:
        mov     esi, [edi + fs.fat.dir_entry_t.size]
        mov     eax, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     ax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        mov     edi, eax ; edi=current cluster
        xor     ebp, ebp ; ebp=current sector in cluster
        ; save directory
        mov     eax, [esp + 8]
        push    ebx
        mov     ebx, buffer
        call    hd_write
        pop     ebx
        cmp     [hd_error], 0
        jz      @f

  .device_err:
        mov     byte[esp + 4], ERROR_DEVICE_FAIL
        jmp     .ret

    @@: ; now ebx=start pos, ecx=end pos, both lie inside file
        sub     ecx, ebx
        jz      .ret

  .write_loop:
        ; skip unmodified sectors
        cmp     dword[esp], 0x200
        jb      .modify
        sub     ebx, 0x200
        jae     .skip
        add     ebx, 0x200

  .modify:
        ; get length of data in current sector
        push    ecx
        sub     ebx, 0x200
        jb      .hasdata
        neg     ebx
        xor     ecx, ecx
        jmp     @f

  .hasdata:
        neg     ebx
        cmp     ecx, ebx
        jbe     @f
        mov     ecx, ebx

    @@: ; get current sector number
        mov     eax, edi
        dec     eax
        dec     eax
        imul    eax, [fat16x_data.sectors_per_cluster]
        add     eax, [fat16x_data.data_start]
        add     eax, ebp
        ; load sector if needed
        cmp     dword[esp + 4], 0 ; we don't need to read uninitialized data
        jz      .noread
        cmp     ecx, 0x200 ; we don't need to read sector if it is fully rewritten
        jz      .noread
        cmp     ecx, esi ; (same for the last sector)
        jz      .noread
        push    ebx
        mov     ebx, buffer
        call    hd_read
        pop     ebx
        cmp     [hd_error], 0
        jz      @f

  .device_err2:
        pop     ecx
        jmp     .device_err

    @@:

  .noread:
        ; zero uninitialized data if file was extended (because hd_extend_file does not this)
        push    eax ecx edi
        xor     eax, eax
        mov     ecx, 0x200
        sub     ecx, [esp + 4 + 12]
        jbe     @f
        mov     edi, buffer
        add     edi, [esp + 4 + 12]
        rep
        stosb

    @@: ; zero uninitialized data in the last sector
        mov     ecx, 0x200
        sub     ecx, esi
        jbe     @f
        mov     edi, buffer
        add     edi, esi
        rep
        stosb

    @@: pop     edi ecx
        ; copy new data
        mov     eax, edx
        neg     ebx
        jecxz   @f
        add     ebx, buffer + 0x200
        call    memmove
        xor     ebx, ebx

    @@: pop     eax
        ; save sector
        push    ebx
        mov     ebx, buffer
        call    hd_write
        pop     ebx
        cmp     [hd_error], 0
        jnz     .device_err2
        add     edx, ecx
        sub     [esp], ecx
        pop     ecx
        jz      .ret

  .skip:
        ; next sector
        inc     ebp
        cmp     ebp, [fat16x_data.sectors_per_cluster]
        jb      @f
        xor     ebp, ebp
        mov     eax, edi
        call    get_FAT
        mov     edi, eax
        cmp     [hd_error], 0
        jnz     .device_err

    @@: sub     esi, 0x200
        jae     @f
        xor     esi, esi

    @@: sub     dword[esp], 0x200
        jae     @f
        and     dword[esp], 0

    @@: jmp     .write_loop
kendp

hd_extend_file.zero_size:
        xor     eax, eax
        jmp     hd_extend_file.start_extend

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_extend_file ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? extends file on hd to given size (new data area is undefined)
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to direntry
;> ecx = new size
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 0 (ok), eax = 0
;< if CF = 1 (error), eax = error code (ERROR_FAT_TABLE or ERROR_DISK_FULL or ERROR_DEVICE_FAIL)
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp
        mov     ebp, [fat16x_data.sectors_per_cluster]
        imul    ebp, [fat16x_data.bytes_per_sector]
        push    ecx
        ; find the last cluster of file
        mov     eax, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     ax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        mov     ecx, [edi + fs.fat.dir_entry_t.size]
        jecxz   .zero_size

  .last_loop:
        sub     ecx, ebp
        jbe     .last_found
        call    get_FAT
        cmp     [hd_error], 0
        jz      @f

  .device_err:
        pop     ecx

  .device_err2:
        pop     ebp
        push    ERROR_DEVICE_FAIL

  .ret_err:
        pop     eax
        stc
        ret

    @@: cmp     eax, 2
        jb      .fat_err
        cmp     eax, [fat16x_data.fatRESERVED]
        jb      .last_loop

  .fat_err:
        pop     ecx ebp
        push    ERROR_FAT_TABLE
        jmp     .ret_err

  .last_found:
        push    eax
        call    get_FAT
        cmp     [hd_error], 0
        jz      @f
        pop     eax
        jmp     .device_err

    @@: cmp     eax, [fat16x_data.fatRESERVED]
        pop     eax
        jb      .fat_err
        ; set length to full number of clusters
        sub     [edi + fs.fat.dir_entry_t.size], ecx

  .start_extend:
        pop     ecx
        ; now do extend
        push    edx
        mov     edx, 2 ; start scan from cluster 2

  .extend_loop:
        cmp     [edi + fs.fat.dir_entry_t.size], ecx
        jae     .extend_done
        ; add new cluster
        push    eax
        call    get_free_FAT
        jc      .disk_full
        mov     edx, [fat16x_data.fatEND]
        call    set_FAT
        mov     edx, eax
        pop     eax
        test    eax, eax
        jz      .first_cluster
        push    edx
        call    set_FAT
        pop     edx
        jmp     @f

  .first_cluster:
        ror     edx, 16
        mov     [edi + fs.fat.dir_entry_t.start_cluster.high], dx
        ror     edx, 16
        mov     [edi + fs.fat.dir_entry_t.start_cluster.low], dx

    @@: push    ecx
        mov     ecx, -1
        call    add_disk_free_space
        pop     ecx
        mov     eax, edx
        cmp     [hd_error], 0
        jnz     .device_err3
        add     [edi + fs.fat.dir_entry_t.size], ebp
        jmp     .extend_loop

  .extend_done:
        mov     [edi + fs.fat.dir_entry_t.size], ecx
        pop     edx ebp
        xor     eax, eax ; ERROR_SUCCESS, CF=0
        ret

  .device_err3:
        pop     edx
        jmp     .device_err2

  .disk_full:
        pop     eax edx ebp
        mov_s_  eax, ERROR_DISK_FULL
        cmp     [hd_error], 0
        jz      @f
        mov     al, ERROR_DEVICE_FAIL

    @@: stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat32_HdSetFileEnd ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? set end of file on hard disk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = points to 64-bit number = new file size
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
    @@: push    edi
        call    hd_find_lfn
        pushfd
        cmp     [hd_error], 0
        jz      @f
        popfd
        push    ERROR_DEVICE_FAIL

  .ret:
        pop     eax
        ret

    @@: popfd
        jnc     @f
        pop     edi
        jmp     fs.error.file_not_found

    @@: ; must not be directory
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      @f
        pop     edi
        jmp     fs.error.access_denied

    @@: ; file size must not exceed 4 Gb
        cmp     dword[ebx + 4], 0
        jz      @f
        pop     edi
        push    ERROR_END_OF_FILE
        jmp     .ret

    @@: push    eax ; save directory sector
        ; set file modification date/time to current
        call    fs.fat.util.update_datetime
        mov     eax, [ebx]
        cmp     eax, [edi + fs.fat.dir_entry_t.size]
        jb      .truncate
        ja      .expand
        pop     eax
        mov     ebx, buffer
        call    hd_write
        pop     edi
        xor     eax, eax
        cmp     [hd_error], 0
        jz      @f
        mov     al, ERROR_DEVICE_FAIL

    @@: ret

  .expand:
        push    ebx ebp ecx
        push    [edi + fs.fat.dir_entry_t.size] ; save old size
        mov     ecx, eax
        call    hd_extend_file
        push    eax ; return code
        jnc     .expand_ok
        cmp     al, ERROR_DISK_FULL
        jz      .disk_full

  .pop_ret:
        call    update_disk
        pop     eax ecx ebp ebx ecx edi edi
        ret

  .expand_ok:
  .disk_full:
        ; save directory
        mov     eax, [edi + fs.fat.dir_entry_t.size]
        xchg    eax, [esp + 20]
        mov     ebx, buffer
        call    hd_write
        mov     eax, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     ax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        mov     edi, eax
        cmp     [hd_error], 0
        jz      @f

  .pop_ret11:
        mov     byte[esp], ERROR_DEVICE_FAIL
        jmp     .pop_ret

    @@: ; now zero new data
        xor     ebp, ebp
        ; edi=current cluster, ebp=sector in cluster
        ; [esp+20]=new size, [esp+4]=old size, [esp]=return code

  .zero_loop:
        sub     dword[esp + 4], 0x200
        jae     .next_cluster
        lea     eax, [edi - 2]
        imul    eax, [fat16x_data.sectors_per_cluster]
        add     eax, [fat16x_data.data_start]
        add     eax, ebp
        cmp     dword[esp + 4], -0x200
        jz      .noread
        mov     ebx, buffer
        call    hd_read
        cmp     [hd_error], 0
        jnz     .err_next

  .noread:
        mov     ecx, [esp + 4]
        neg     ecx
        push    edi
        mov     edi, buffer + 0x200
        add     edi, [esp + 8]
        push    eax
        xor     eax, eax
        mov     [esp + 12], eax
        rep
        stosb
        pop     eax
        pop     edi
        call    hd_write
        cmp     [hd_error], 0
        jz      .next_cluster

  .err_next:
        mov     byte[esp], ERROR_DEVICE_FAIL

  .next_cluster:
        sub     dword[esp + 20], 0x200
        jbe     .pop_ret
        inc     ebp
        cmp     ebp, [fat16x_data.sectors_per_cluster]
        jb      .zero_loop
        xor     ebp, ebp
        mov     eax, edi
        call    get_FAT
        mov     edi, eax
        cmp     [hd_error], 0
        jnz     .pop_ret11
        jmp     .zero_loop

  .truncate:
        mov     [edi + fs.fat.dir_entry_t.size], eax
        push    ecx
        mov     ecx, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     cx, [edi + fs.fat.dir_entry_t.start_cluster.low]
        push    eax
        test    eax, eax
        jz      .zero_size
        ; find new last cluster

    @@: mov     eax, [fat16x_data.sectors_per_cluster]
        shl     eax, 9
        sub     [esp], eax
        jbe     @f
        mov     eax, ecx
        call    get_FAT
        mov     ecx, eax
        cmp     [hd_error], 0
        jz      @b

  .device_err3:
        pop     eax ecx eax edi
        mov_s_  eax, ERROR_DEVICE_FAIL
        ret

    @@: ; we will zero data at the end of last sector - remember it
        push    ecx
        ; terminate FAT chain
        push    edx
        mov     eax, ecx
        mov     edx, [fat16x_data.fatEND]
        call    set_FAT
        mov     eax, edx
        pop     edx
        cmp     [hd_error], 0
        jz      @f

  .device_err4:
        pop     ecx
        jmp     .device_err3

  .zero_size:
        and     [edi + fs.fat.dir_entry_t.start_cluster.high], 0
        and     [edi + fs.fat.dir_entry_t.start_cluster.low], 0
        push    0
        mov     eax, ecx

    @@: ; delete FAT chain
        call    clear_cluster_chain
        cmp     [hd_error], 0
        jnz     .device_err4
        ; save directory
        mov     eax, [esp + 12]
        push    ebx
        mov     ebx, buffer
        call    hd_write
        pop     ebx
        cmp     [hd_error], 0
        jnz     .device_err4
        ; zero last sector, ignore errors
        pop     ecx
        pop     eax
        dec     ecx
        imul    ecx, [fat16x_data.sectors_per_cluster]
        add     ecx, [fat16x_data.data_start]
        push    eax
        sar     eax, 9
        add     ecx, eax
        pop     eax
        and     eax, 0x1ff
        jz      .truncate_done
        push    ebx eax
        mov     eax, ecx
        mov     ebx, buffer
        call    hd_read
        pop     eax
        lea     edi, [buffer + eax]
        push    ecx
        mov     ecx, 0x200
        sub     ecx, eax
        xor     eax, eax
        rep
        stosb
        pop     eax
        call    hd_write
        pop     ebx

  .truncate_done:
        pop     ecx eax edi
        call    update_disk
        xor     eax, eax ; ERROR_SUCCESS
        cmp     [hd_error], 0
        jz      @f
        mov     al, ERROR_DEVICE_FAIL

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat32_HdGetFileInfo ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f
        mov     eax, ERROR_NOT_IMPLEMENTED
        ret

    @@: push    edi
        call    hd_find_lfn
        pushfd
        cmp     [hd_error], 0
        jz      @f
        popfd
        pop     edi
        mov     eax, ERROR_DEVICE_FAIL
        ret

    @@: popfd
        jnc     @f
        pop     edi
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

    @@: push    esi ebp
        xor     ebp, ebp
        mov     esi, edx
        and     dword[esi + 4], 0
        call    fs.fat.util.fat_entry_to_bdfe.direct
        pop     ebp esi
        pop     edi
        xor     eax, eax ; ERROR_SUCCESS
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat32_HdSetFileInfo ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f
        mov     eax, ERROR_NOT_IMPLEMENTED
        ret

    @@: push    edi
        call    hd_find_lfn
        pushfd
        cmp     [hd_error], 0
        jz      @f
        popfd
        pop     edi
        mov     eax, ERROR_DEVICE_FAIL
        ret

    @@: popfd
        jnc     @f
        pop     edi
        jmp     fs.error.file_not_found

    @@: push    eax
        call    fs.fat.util.bdfe_to_fat_entry
        pop     eax
        mov     ebx, buffer
        call    hd_write
        call    update_disk
        pop     edi
        xor     eax, eax ; ERROR_SUCCESS
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat32_HdDelete ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? delete file or empty folder from hard disk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
        and     [longname_sec1], 0
        and     [longname_sec2], 0
        push    edi
        call    hd_find_lfn
        jnc     .found

        pop     edi
        jmp     fs.error.file_not_found

  .pop_ret:
        pop     eax
        ret

  .found:
        cmp     dword[edi + fs.fat.dir_entry_t.name], '.   '
        jz      .access_denied2
        cmp     dword[edi + fs.fat.dir_entry_t.name], '..  '
        jz      .access_denied2
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .dodel
        ; we can delete only empty folders!
        pushad
        mov     ebp, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     bp, [edi + fs.fat.dir_entry_t.start_cluster.low]
        xor     ecx, ecx
        lea     eax, [ebp - 2]
        imul    eax, [fat16x_data.sectors_per_cluster]
        add     eax, [fat16x_data.data_start]
        mov     ebx, buffer
        call    hd_read
        cmp     [hd_error], 0
        jnz     .err1
        add     ebx, 2 * sizeof.fs.fat.dir_entry_t

  .checkempty:
        cmp     [ebx + fs.fat.dir_entry_t.name], 0
        jz      .empty
        cmp     [ebx + fs.fat.dir_entry_t.name], 0xe5
        jnz     .notempty
        add     ebx, sizeof.fs.fat.dir_entry_t
        cmp     ebx, buffer + 0x200
        jb      .checkempty
        inc     ecx
        cmp     ecx, [fat16x_data.sectors_per_cluster]
        jb      @f
        mov     eax, ebp
        call    get_FAT
        cmp     [hd_error], 0
        jnz     .err1
        mov     ebp, eax
        xor     ecx, ecx

    @@: lea     eax, [ebp - 2]
        imul    eax, [fat16x_data.sectors_per_cluster]
        add     eax, [fat16x_data.data_start]
        add     eax, ecx
        mov     ebx, buffer
        call    hd_read
        cmp     [hd_error], 0
        jz      .checkempty

  .err1:
        popad

  .err2:
        pop     edi
        mov_s_  eax, ERROR_DEVICE_FAIL
        ret

  .notempty:
        popad

  .access_denied2:
        pop     edi
        jmp     fs.error.access_denied

  .empty:
        popad
        push    ebx
        mov     ebx, buffer
        call    hd_read
        pop     ebx
        cmp     [hd_error], 0
        jnz     .err2

  .dodel:
        push    eax
        mov     eax, dword[edi + fs.fat.dir_entry_t.start_cluster.high - 2]
        mov     ax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        xchg    eax, [esp]
        ; delete folder entry
        mov     [edi + fs.fat.dir_entry_t.name], 0xe5
        ; delete LFN (if present)

  .lfndel:
        cmp     edi, buffer
        ja      @f
        cmp     [longname_sec2], 0
        jz      .lfndone
        push    [longname_sec2]
        mov_s_  [longname_sec2], [longname_sec1]
        and     [longname_sec1], 0
        push    ebx
        mov     ebx, buffer
        call    hd_write
        mov     eax, [esp + 4]
        call    hd_read
        pop     ebx
        pop     eax
        mov     edi, buffer + 0x200

    @@: sub     edi, sizeof.fs.fat.dir_entry_t
        cmp     [edi + fs.fat.dir_entry_t.name], 0xe5
        jz      .lfndone
        cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        jnz     .lfndone
        mov     [edi + fs.fat.dir_entry_t.name], 0xe5
        jmp     .lfndel

  .lfndone:
        push    ebx
        mov     ebx, buffer
        call    hd_write
        pop     ebx
        ; delete FAT chain
        pop     eax
        call    clear_cluster_chain
        call    update_disk
        pop     edi
        xor     eax, eax ; ERROR_SUCCESS
        cmp     [hd_error], 0
        jz      @f
        mov     al, ERROR_DEVICE_FAIL

    @@: ret
kendp
