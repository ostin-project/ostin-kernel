;;======================================================================================================================
;;///// fat.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011-2012 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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

struct fs.fat.vftbl_t
  allocate_cluster             dd ?
  get_next_cluster             dd ?
  get_or_allocate_next_cluster dd ?
  check_for_enough_clusters    dd ?
  delete_chain                 dd ?
  flush                        dd ?
ends

struct fs.fat.partition_t fs.partition_t
  fat_vftbl        dd ? ; ^= fs.fat.vftbl_t
  fat_sector       dd ?
  fat_size         dd ? ; in sectors
  root_dir_sector  dd ?
  data_area_sector dd ?
  cluster_size     dd ? ; in sectors
  buffer           rb 2 * 512
ends

iglobal
  JumpTable fs.fat, vftbl, 0, \
    read_file, \
    read_directory, \
    create_file, \
    write_file, \
    truncate_file, \
    get_file_info, \
    set_file_info, \
    -, \
    delete_file, \
    create_directory
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.calculate_fat_chain ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= ... (buffer)
;> edi ^= ... (fat)
;> eflags[df] ~= 0
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        lea     ebp, [edi + 2856 * 2] ; 2849 clusters

  .next:
        lodsd
        xchg    eax, ecx
        lodsd
        xchg    eax, ebx
        lodsd
        xchg    eax, ecx
        mov     edx, ecx

        shr     edx, 4 ; 8 ok
        shr     dx, 4 ; 7 ok
        xor     ch, ch
        shld    ecx, ebx, 20 ; 6 ok
        shr     cx, 4 ; 5 ok
        shld    ebx, eax, 12
        and     ebx, 0x0fffffff ; 4 ok
        shr     bx, 4 ; 3 ok
        shl     eax, 4
        and     eax, 0x0fffffff ; 2 ok
        shr     ax, 4 ; 1 ok

        stosd
        xchg    eax, ebx
        stosd
        xchg    eax, ecx
        stosd
        xchg    eax, edx
        stosd

        cmp     edi, ebp
        jb      .next

        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.restore_fat_chain ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= ... (fat)
;> edi ^= ... (buffer)
;> eflags[df] ~= 0
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        lea     ebp, [edi + 0x1200] ; 4274 bytes - all used FAT
        push    edi

  .next:
        lodsd
        xchg    eax, ebx
        lodsd
        xchg    eax, ebx

        shl     ax, 4
        shl     eax, 4
        shl     bx, 4
        shr     ebx, 4
        shrd    eax, ebx, 8
        shr     ebx, 8

        stosd
        xchg    eax, ebx
        stosw

        cmp     edi, ebp
        jb      .next

        ; duplicate fat chain
        pop     esi
        mov     edi, ebp
        mov     ecx, 0x1200 / 4
        rep
        movsd

        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.read_file ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.read_file_query_params_t
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= bytes read (on success)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.read_file('%s')\n", esi

        cmp     byte[esi], 0
        je      .access_denied_error

        cmp     dword[edx + fs.read_file_query_params_t.range.offset + 4], 0
        jne     .end_of_file_error

        call    fs.fat._.find_file_lfn
        jc      .file_not_found_error

        ; do not allow reading directories
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jnz     .access_denied_error

        mov     ebp, dword[edx + fs.read_file_query_params_t.range.offset]
        mov     eax, [edi + fs.fat.dir_entry_t.size]
        cmp     ebp, eax
        jae     .end_of_file_error

        mov     ecx, [edx + fs.read_file_query_params_t.range.length]
        sub     eax, ebp
        cmp     ecx, eax
        jbe     @f
        mov     ecx, eax

    @@: push    eax
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        call    fs.fat.util.cluster_to_sector
        mov     esi, eax
        pop     eax

        mov     edx, [edx + fs.read_file_query_params_t.buffer_ptr]
        push    edx

        jecxz   .done

  .read_next_sector:
        sub     ebp, 512
        jae     .skip_sector

        mov     eax, esi
        call    fs.fat._.read_sector
        jnz     .device_error_in_loop

        lea     eax, [edi + 512 + ebp]
        neg     ebp
        push    ebx ecx
        cmp     ecx, ebp
        jbe     @f
        mov     ecx, ebp

    @@: mov     ebx, edx
        call    memmove
        add     edx, ecx
        sub     [esp], ecx
        pop     ecx ebx

        xor     ebp, ebp

  .skip_sector:
        jecxz   .done

        push    edx ecx
        mov     eax, esi
        mov     esi, [ebx + fs.fat.partition_t.fat_vftbl]
        call    [esi + fs.fat.vftbl_t.get_next_cluster]
        pop     ecx
        jc      .end_of_file_error_in_loop

        add     esp, 4
        mov     esi, eax
        jmp     .read_next_sector

  .done:
        mov     ebx, edx
        pop     edx
        sub     ebx, edx

        xor     eax, eax ; ERROR_SUCCESS
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        or      ebx, -1
        ret

  .end_of_file_error_in_loop:
        pop     ebx eax
        sub     ebx, eax
        mov     eax, ERROR_END_OF_FILE
        ret

  .end_of_file_error:
        mov     eax, ERROR_END_OF_FILE
        xor     ebx, ebx
        ret

  .device_error_in_loop:
        add     esp, 4

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        or      ebx, -1
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.read_directory ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to directory
;> edx ^= fs.read_directory_query_params_t
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= directory entries read (on success)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.read_directory('%s')\n", esi

        cmp     byte[esi], 0
        je      .root_directory

        call    fs.fat._.find_file_lfn
        jc      .file_not_found_error

        ; do not allow reading files
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .access_denied_error

        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        call    fs.fat.util.cluster_to_sector
        push    eax
        jmp     .prepare_header

  .root_directory:
        push    [ebx + fs.fat.partition_t.root_dir_sector]

  .prepare_header:
        xor     eax, eax
        mov     ecx, sizeof.fs.file_info_header_t / 4
        mov     edi, [edx + fs.read_directory_query_params_t.buffer_ptr]
        rep
        stosd

        sub     esp, 262 * 2 ; reserve space for LFN
        mov     ebp, esp

        push    [edx + fs.read_directory_query_params_t.flags] ; for fs.fat.get_name: read ANSI/UNICODE names
        push    [edx + fs.read_directory_query_params_t.start_block]
        push    0 ; LFN indicator

        mov     ecx, [edx + fs.read_directory_query_params_t.count]
        lea     edx, [edi - sizeof.fs.file_info_header_t]
        mov     esi, edi ; ^= fs.file_info_t

        mov     [edx + fs.file_info_header_t.version], 1

  .read_next_sector:
        mov     eax, [esp + 12 + 262 * 2]
        call    fs.fat._.read_sector
        jnz     .error

  .get_entry_name:
        cmp     byte[esp], 0
        jne     .do_bdfe

        call    fs.fat.util.get_name
        jc      .move_to_next_entry

        cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        jne     .do_bdfe

        mov     byte[esp], 1
        jmp     .move_to_next_entry

  .do_bdfe:
        and     byte[esp], 0

        inc     [edx + fs.file_info_header_t.files_count] ; new file found
        dec     dword[esp + 4]
        jns     .move_to_next_entry
        dec     ecx
        js      .move_to_next_entry

        inc     [edx + fs.file_info_header_t.files_read] ; new file block copied
        call    fs.fat.util.fat_entry_to_bdfe

  .move_to_next_entry:
        lea     eax, [ebx + fs.fat.partition_t.buffer + 512]
        add     edi, sizeof.fs.fat.dir_entry_t
        cmp     edi, eax
        jb      .get_entry_name

        ; read next sector from FAT
        push    ecx ebp
        mov     eax, [esp + 12 + 262 * 2 + 8]
        mov     ebp, [ebx + fs.fat.partition_t.fat_vftbl]
        call    [ebp + fs.fat.vftbl_t.get_next_cluster]
        pop     ebp ecx
        jnc     @f

        cmp     eax, ERROR_END_OF_FILE
        je      .done
        jmp     .error

    @@: mov     [esp + 12 + 262 * 2], eax
        jmp     .read_next_sector

  .done:
        add     esp, 12 + 262 * 2 + 4

        mov     ebx, [edx + fs.file_info_header_t.files_read]
        xor     eax, eax
        dec     ecx
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: ret

  .error:
        add     esp, 12 + 262 * 2 + 4
        or      ebx, -1

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.begin_cluster_write ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax]
        call    fs.fat._.read_sector
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.end_cluster_write ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax]
        call    fs.fat._.write_sector
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.prev_cluster_write ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        lea     eax, [ebx + fs.fat.partition_t.buffer]
        cmp     edi, eax
        pop     eax
        jb      @f
        ret

    @@: call    fs.fat._.end_cluster_write
        jmp     fs.fat._.prev_dir_entry
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.next_cluster_write ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        lea     eax, [ebx + fs.fat.partition_t.buffer + 512]
        cmp     edi, eax
        pop     eax
        jae     @f
        ret

    @@: call    fs.fat._.end_cluster_write
        jmp     fs.fat._.next_dir_entry
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.extend_dir ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_ERROR, "FIXME: not implemented: fs.fat._.extend_dir\n"
        mov     eax, ERROR_NOT_IMPLEMENTED
        stc
        ret

        ; find free cluster in FAT
;///        pusha
;///
;///        call    fs.fat12._.find_free_cluster
;///        jc      .not_found
;///
;///        mov     word[edi], 0x0fff ; mark as last cluster
;///
;///        lea     edx, [ebx + fs.fat.partition_t.fat]
;///
;///        mov     edi, [esp + regs_context32_t.eax]
;///        mov     ecx, [edi]
;///        mov     [edx + ecx * 2], ax
;///        mov     [edi], eax
;///
;///        xor     eax, eax
;///        lea     edi, [ebx + fs.fat.partition_t.buffer]
;///        mov     ecx, 512 / 4
;///        rep
;///        stosd
;///
;///        popa
;///        call    fs.fat._.end_cluster_write
;///        lea     edi, [ebx + fs.fat.partition_t.buffer]
;///        clc
;///        ret
;///
;///  .not_found:
;///        popa
;///        stc
;///        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.find_parent_dir ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebp #= parent directory start cluster
;< esi ^= file or directory name
;-----------------------------------------------------------------------------------------------------------------------
        xor     edi, edi
        push    esi

    @@: lodsb
        test    al, al
        jz      @f
        cmp     al, '/'
        jnz     @b
        lea     edi, [esi - 1]
        jmp     @b

    @@: pop     esi

        push    esi
        test    edi, edi
        jz      @f

        lea     esi, [edi + 1]

    @@: call    fs.fat.util.name_is_legal
        pop     esi
        jnc     .file_not_found_error

        test    edi, edi
        jnz     .not_root

        mov     ebp, [ebx + fs.fat.partition_t.root_dir_sector]

        jmp     .exit

  .not_root:
        cmp     byte[edi + 1], 0
        je      .access_denied_error

        ; check parent entry existence
        mov     byte[edi], 0
        push    edi
        call    fs.fat._.find_file_lfn
        pop     esi
        mov     byte[esi], '/'
        jc      .file_not_found_error

        ; edi ^= parent entry
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY ; must be directory
        jz      .access_denied_error

        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low] ; ebp #= cluster
        call    fs.fat.util.cluster_to_sector
        mov     ebp, eax

        inc     esi

  .exit:
        xor     eax, eax ; ERROR_SUCCESS
        ret

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .fat_table_error:
        mov     eax, ERROR_FAT_TABLE
        ret
kendp

;///;-----------------------------------------------------------------------------------------------------------------------
;///kproc fs.fat12._.find_free_cluster ;////////////////////////////////////////////////////////////////////////////////////
;///;-----------------------------------------------------------------------------------------------------------------------
;///;> ebx ^= fs.fat.partition_t
;///;-----------------------------------------------------------------------------------------------------------------------
;///;< Cf ~= 0 (ok) or 1 (error)
;///;< eax #= free cluster number
;///;< edi ^= free cluster in FAT
;///;-----------------------------------------------------------------------------------------------------------------------
;///        push    ecx
;///        mov     ecx, 2849
;///        lea     edi, [ebx + fs.fat.partition_t.fat]
;///
;///        xor     eax, eax
;///        repne
;///        scasw
;///        pop     ecx
;///        jne     .error
;///
;///        dec     edi
;///        dec     edi
;///        lea     eax, [edi - fs.fat.partition_t.fat]
;///        sub     eax, ebx
;///        shr     eax, 1
;///
;///        clc
;///        ret
;///
;///  .error:
;///        stc
;///        ret
;///kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.create_dir_entry ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;> edx #= number of free clusters
;> esi ^= entry name
;> [esp + 4] #= parent directory start cluster
;-----------------------------------------------------------------------------------------------------------------------
;< edi ^= fs.fat.dir_entry_t
;< [esp + 4] #= entry cluster
;-----------------------------------------------------------------------------------------------------------------------
        pusha

        push    ebp dword[esp + sizeof.regs_context32_t + 4]
        call    fs.fat.util.find_long_name
        pop     eax eax
        jnc     .access_denied_error

        ; file is not found; generate short name
        sub     esp, 12
        mov     edi, esp
        call    fs.fat.util.gen_short_name

  .test_short_name_loop:
        push    esi edi ecx
        mov     esi, edi
        lea     eax, [esp + 12 + 12 + sizeof.regs_context32_t + 4]
        mov     [eax], ebp
        call    fs.fat._.first_dir_entry
        jc      .short_name_not_found

  .test_short_name_entry:
        cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        je      .test_short_name_cont
        mov     ecx, 11
        push    esi edi
        repe
        cmpsb
        pop     edi esi
        je      .short_name_found

  .test_short_name_cont:
        lea     eax, [esp + 12 + 12 + sizeof.regs_context32_t + 4]
        call    fs.fat._.next_dir_entry
        jc      .short_name_not_found
        jmp     .test_short_name_entry

  .short_name_found:
        pop     ecx edi esi
        call    fs.fat.util.next_short_name
        jc      .disk_full_error
        jmp     .test_short_name_loop

  .short_name_not_found:
        pop     ecx edi esi

        ; check if error occured during (first|next)_entry
        or      eax, eax
        jnz     .device_error_5

        ; now find space in directory
        ; we need to save LFN <=> LFN is not equal to short name <=> generated name contains '~'
        mov     al, '~'
        push    ecx edi
        mov     ecx, 8
        repne
        scasb
        MovStk  eax, 1 ; 1 entry
        jne     .notilde

        ; we need `ceil(strlen(esi) / 13) + 1` additional entries = `floor((strlen(esi) + 12 + 13) / 13)` total
        mov     eax, esi
        call    util.string.length
        add     eax, 12 + 13
        mov     ecx, 13
        push    edx
        cdq
        div     ecx
        pop     edx

  .notilde:
        push    -1 ; first entry sector
        push    -1 ; first entry pointer

        ; find <eax> successive free entries in directory
        xor     ecx, ecx
        push    eax
        lea     eax, [esp + 4 + 8 + 8 + 12 + sizeof.regs_context32_t + 4]
        mov     [eax], ebp
        call    fs.fat._.first_dir_entry
        pop     eax
        ; TODO: check if there really was an error
        jc      .device_error_3

  .scan_dir:
        cmp     [edi + fs.fat.dir_entry_t.name + 0], 0
        je      .free
        cmp     [edi + fs.fat.dir_entry_t.name + 0], 0xe5
        je      .free

        xor     ecx, ecx

  .scan_cont:
        push    eax
        lea     eax, [esp + 4 + 8 + 8 + 12 + sizeof.regs_context32_t + 4]
        push    dword[eax]
        call    fs.fat._.next_dir_entry
        jc      .check_for_scan_error
        add     esp, 4
        pop     eax
        jmp     .scan_dir

  .check_for_scan_error:
        pop     dword[esp + 4 + 8 + 8 + 12 + sizeof.regs_context32_t + 4]
        or      eax, eax
        pop     eax
        jnz     .device_error_3

        mov     [eax], ecx

        push    eax
        lea     eax, [esp + 4 + 8 + 8 + 12 + sizeof.regs_context32_t + 4]
        call    fs.fat._.extend_dir
        pop     eax
        jc      .disk_full_error_2
        jmp     .scan_dir

  .free:
        test    ecx, ecx
        jnz     @f

        mov     [esp], edi ; save first entry pointer
        mov     ecx, [esp + 8 + 8 + 12 + sizeof.regs_context32_t + 4]
        mov     [esp + 4], ecx ; save first entry sector
        xor     ecx, ecx

    @@: inc     ecx
        cmp     ecx, eax
        jb      .scan_cont

        ; found!
        pop     edi ; edi points to first entry in free chunk
        pop     dword[esp + 8 + 12 + sizeof.regs_context32_t + 4]

        ; calculate name checksum
        mov     eax, [esp]
        call    fs.fat.util.calculate_name_checksum

        dec     ecx
        jz      .not_lfn

        push    esi eax

        lea     eax, [esp + 8 + 8 + 12 + sizeof.regs_context32_t + 4]
        call    fs.fat._.begin_cluster_write

        mov     al, 0x40

  .write_lfn:
        or      al, cl
        mov     esi, [esp + 4]

        push    ecx

        dec     ecx
        imul    ecx, 13
        add     esi, ecx
        stosb   ; sequence_number
        mov     cl, 5
        call    fs.fat.util.read_symbols ; name.part_1
        mov     ax, FS_FAT_ATTR_LONG_NAME
        stosw   ; attributes
        mov     al, [esp + 4]
        stosb   ; checksum
        mov     cl, 6
        call    fs.fat.util.read_symbols ; name.part_2
        xor     eax, eax
        stosw   ; start_cluster
        mov     cl, 2
        call    fs.fat.util.read_symbols ; name.part_3

        pop     ecx

        lea     eax, [esp + 8 + 8 + 12 + sizeof.regs_context32_t + 4]
        call    fs.fat._.next_cluster_write

        xor     eax, eax
        loop    .write_lfn

        pop     eax esi

  .not_lfn:
        xchg    esi, [esp]
        mov     ecx, 11
        rep
        movsb
        sub     edi, 11
        pop     esi ecx
        add     esp, 12

        mov     al, [esp + regs_context32_t.cl]
        mov     [edi + fs.fat.dir_entry_t.attributes], al
        and     [edi + fs.fat.dir_entry_t.created_at.time_ms], 0
        call    fs.fat.util.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.created_at.time], ax
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax
        call    fs.fat.util.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.created_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax

        mov     eax, [ebx + fs.fat.partition_t.fat_vftbl]
        call    [eax + fs.fat.vftbl_t.allocate_cluster]
        jc      .disk_full_error_3

        mov     eax, edx

        and     [edi + fs.fat.dir_entry_t.start_cluster.high], 0
        mov     [edi + fs.fat.dir_entry_t.start_cluster.low], ax
        and     [edi + fs.fat.dir_entry_t.size], 0

        lea     eax, [esp + sizeof.regs_context32_t + 4]
        call    fs.fat._.end_cluster_write

        and     [esp + regs_context32_t.eax], 0 ; ERROR_SUCCESS
        mov     [esp + regs_context32_t.edi], edi

  .exit:
        popa
        ret

  .disk_full_error_2:
        add     esp, 12

  .disk_full_error_3:
        add     esp, 16

  .disk_full_error:
        add     esp, sizeof.regs_context32_t
        mov     eax, ERROR_DISK_FULL
        ret

  .access_denied_error:
        add     esp, sizeof.regs_context32_t
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .device_error_3:
        add     esp, 4 + 16

  .device_error_5:
        add     esp, sizeof.regs_context32_t
        mov     eax, ERROR_DEVICE_FAIL
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.write_file ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;> eax #= data offset
;> ecx #= data size
;> esi ^= data
;> edi ^= fs.fat.dir_entry_t
;> [esp + 4] #= entry cluster
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jz      .success_exit

        pusha

        push    eax ecx edi

        push    eax
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        call    fs.fat.util.cluster_to_sector
        mov     ebp, eax
        pop     eax

  .write_loop:
        sub     dword[esp + 8], 512
        jae     .skip_cluster

        mov     eax, [esp + 8]
        neg     eax

        mov     ecx, [esp + 4]
        cmp     ecx, eax
        jbe     @f
        mov     ecx, eax

    @@: cmp     ecx, 512
        je      @f

        push    eax
        mov     eax, ebp
        call    fs.fat._.read_sector
        pop     eax
        jnz     .device_error

    @@: lea     edi, [ebx + fs.fat.partition_t.buffer]
        neg     eax
        add     eax, 512
        add     edi, eax
        push    ecx
        rep
        movsb

        mov     eax, ebp
        push    esi
        call    fs.fat._.write_sector
        pop     esi
        pop     ecx
        jnz     .device_error

        and     dword[esp + 8], 0
        sub     [esp + 4], ecx
        jz      .done

  .skip_cluster:
        mov     eax, ebp
        mov     edx, [ebx + fs.fat.partition_t.fat_vftbl]
        call    [edx + fs.fat.vftbl_t.get_or_allocate_next_cluster]
        jc      .error

        mov     ebp, eax
        jmp     .write_loop

  .done:
        pop     edi ecx eax

        lea     eax, [esp + sizeof.regs_context32_t + 4]
        call    fs.fat._.begin_cluster_write

        call    fs.fat.util.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax
        call    fs.fat.util.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax

        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jnz     @f

        mov     eax, [esp + regs_context32_t.eax]
        add     eax, [esp + regs_context32_t.ecx]
        cmp     eax, [edi + fs.fat.dir_entry_t.size]
        jbe     @f
        mov     [edi + fs.fat.dir_entry_t.size], eax

    @@: lea     eax, [esp + sizeof.regs_context32_t + 4]
        call    fs.fat._.end_cluster_write

        mov     eax, [ebx + fs.fat.partition_t.fat_vftbl]
        call    [eax + fs.fat.vftbl_t.flush]

        popa

  .success_exit:
        xor     eax, eax ; ERROR_SUCCESS

  .exit:
        ret

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL

  .error:
        add     esp, 12 + sizeof.regs_context32_t
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.create_directory ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to directory
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.create_directory('%s')\n", esi

        cmp     byte[esi], 0
        je      .access_denied_error

        call    fs.fat._.find_parent_dir
        test    eax, eax
        jnz     .exit

        push    ebp

        mov     cl, FS_FAT_ATTR_DIRECTORY
        call    fs.fat._.create_dir_entry
        test    eax, eax
        jnz     .free_stack_and_exit

        mov     esi, edi
        call    .get_dir_data

        call    fs.fat._.write_file
        test    eax, eax
        jnz     .free_stack_and_exit

        add     esp, 4

        mov     ebx, ecx

  .exit:
        ret

  .free_stack_and_exit:
        add     esp, 8
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .disk_full_error:
        mov     eax, ERROR_DISK_FULL
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .get_dir_data: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= fs.fat.dir_entry_t
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< esi ^= data
;< ecx #= data size
;-----------------------------------------------------------------------------------------------------------------------
        push    edi

        lea     edi, [ebx + fs.fat.partition_t.buffer + 512]
        push    edi

        MovStk  ecx, sizeof.fs.fat.dir_entry_t / 4

        push    ecx esi
        rep
        movsd
        pop     esi ecx

        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name], '.   '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 4], '    '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 8], '   '
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY

        rep
        movsd

        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name], '..  '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 4], '    '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 8], '   '
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.start_cluster.low], bp

        xor     eax, eax
        mov     ecx, (512 - 2 * sizeof.fs.fat.dir_entry_t) / 4
        rep
        stosd

        pop     esi
        mov     ecx, 512

        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.create_file ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.create_file_query_params_t
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= bytes written (on success)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.create_file('%s')\n", esi

        cmp     byte[esi], 0
        je      .access_denied_error

        push    edx

;///        call    fs.fat12._.get_free_clusters_count
;///        mov     ecx, [edx + fs.create_file_query_params_t.length]
;///        xchg    eax, ecx
;///        call    fs.fat._.bytes_to_clusters
;///        sub     ecx, eax ; new file would occupy <eax> clusters
;///        jb      .disk_full_error

;///        push    ecx
        call    fs.fat._.find_parent_dir
        test    eax, eax
;///        pop     edx
        jnz     .exit

        push    ebp

        xor     cl, cl
        call    fs.fat._.create_dir_entry
        test    eax, eax
        jnz     .free_stack_and_exit

        mov     esi, [esp + 4]
        mov     ecx, [esi + fs.create_file_query_params_t.length]
        mov     esi, [esi + fs.create_file_query_params_t.buffer_ptr]

        call    fs.fat._.write_file
        test    eax, eax
        jnz     .free_stack_and_exit

        add     esp, 4

        push    eax ecx
        mov     eax, [ebx + fs.fat.partition_t.fat_vftbl]
        call    [eax + fs.fat.vftbl_t.flush]
        pop     ecx eax
        jc      .device_error

        mov     ebx, ecx

  .exit:
        add     esp, 4
        ret

  .free_stack_and_exit:
        add     esp, 4 + 4
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .device_error:
        add     esp, 4
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .disk_full_error:
        add     esp, 4
        mov     eax, ERROR_DISK_FULL
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.write_file ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.write_file_query_params_t
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= bytes written (on success)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.write_file('%s')\n", esi

        cmp     byte[esi], 0
        je      .access_denied_error

        cmp     dword[edx + fs.write_file_query_params_t.range.offset + 4], 0
        jne     .disk_full_error

        call    fs.fat._.find_file_lfn
        jc      .file_not_found_error

        push    eax

;///        call    fs.fat12._.get_free_clusters_count
;///        push    eax
;///        mov     eax, dword[edx + fs.write_file_query_params_t.range.offset]
;///        add     eax, [edx + fs.write_file_query_params_t.range.length]
;///        jc      .disk_full_error_3
;///        call    fs.fat._.bytes_to_clusters
;///        xchg    eax, ecx
;///        mov     eax, [edi + fs.fat.dir_entry_t.size]
;///        call    fs.fat._.bytes_to_clusters
;///        sub     ecx, edx
;///        pop     eax
;///        jle     @f
;///        sub     eax, ecx ; modified file would occupy <ecx> new clusters
;///        jl      .disk_full_error_2

    @@: mov     eax, dword[edx + fs.write_file_query_params_t.range.offset]
        mov     ecx, [edx + fs.create_file_query_params_t.length]
        mov     esi, [edx + fs.create_file_query_params_t.buffer_ptr]

        call    fs.fat._.write_file
        add     esp, 4
        test    eax, eax
        jnz     .exit

        mov     ebx, ecx

  .exit:
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .disk_full_error_3:
        add     esp, 4

  .disk_full_error_2:
        add     esp, 8

  .disk_full_error:
        mov     eax, ERROR_DISK_FULL
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.bytes_to_clusters ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= bytes
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= clusters
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        xor     edx, edx
        add     eax, 511
        adc     edx, 0
        shrd    eax, edx, 9
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.truncate_file ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.truncate_file_query_params_t
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.truncate_file('%s')\n", esi

        cmp     byte[esi], 0
        je      .access_denied_error

        ; file size must not exceed 4 Gb
        cmp     dword[edx + fs.truncate_file_query_params_t.new_size + 4], 0
        jne     .disk_full_error

        call    fs.fat._.find_file_lfn
        jc      .file_not_found_error

        ; must not be directory
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jnz     .access_denied_error

        push    eax

;///        call    fs.fat12._.get_free_clusters_count
;///        push    eax
        mov     eax, dword[edx + fs.truncate_file_query_params_t.new_size]
        call    fs.fat._.bytes_to_clusters
        xchg    eax, ecx
        mov     eax, [edi + fs.fat.dir_entry_t.size]
        call    fs.fat._.bytes_to_clusters
        sub     ecx, eax
;///        pop     eax
        jle     @f
;///        sub     eax, ecx ; modified file would occupy <ecx> new clusters
;///        jl      .disk_full_error_2

    @@: ; set file modification date/time to current
        call    fs.fat.util.update_datetime

        MovStk  [edi + fs.fat.dir_entry_t.size], dword[edx + fs.truncate_file_query_params_t.new_size]

        mov     eax, [edi + fs.fat.dir_entry_t.size]
        call    fs.fat._.bytes_to_clusters

        mov     ebp, [ebx + fs.fat.partition_t.fat_vftbl]

        test    ecx, ecx
        jl      .truncate
        jg      .expand

        lea     eax, [esp]
        call    fs.fat._.end_cluster_write
        jc      .device_error_2

        add     esp, 4
        xor     eax, eax ; ERROR_SUCCESS
        ret

  .expand:
        lea     ecx, [ecx + eax - 1]
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        call    fs.fat.util.cluster_to_sector

    @@: push    ecx
        call    [ebp + fs.fat.vftbl_t.get_or_allocate_next_cluster]
        pop     ecx
        jc      .disk_full_error_2
        loop    @b

        jmp     .exit

  .truncate:
        add     ecx, eax
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        call    fs.fat.util.cluster_to_sector

    @@: push    ecx
        call    [ebp + fs.fat.vftbl_t.get_next_cluster]
        pop     ecx
        jc      .fat_table_error
        loop    @b

        or      edx, -1 ; mark EOF
        call    [ebp + fs.fat.vftbl_t.delete_chain]
        jc      .device_error_2

  .exit:
        lea     eax, [esp]
        call    fs.fat._.end_cluster_write
        jc      .device_error_2

        call    [ebp + fs.fat.vftbl_t.flush]
        jc      .device_error_2

        add     esp, 4
        xor     eax, eax ; ERROR_SUCCESS
        ret

  .access_denied_error:
        MovStk  eax, ERROR_ACCESS_DENIED
        ret

  .disk_full_error_2:
        add     esp, 4

  .disk_full_error:
        MovStk  eax, ERROR_DISK_FULL
        ret

  .device_error_2:
        add     esp, 4

  .device_error:
        MovStk  eax, ERROR_DEVICE_FAIL
        ret

  .file_not_found_error:
        MovStk  eax, ERROR_FILE_NOT_FOUND
        ret

  .fat_table_error_2:
        add     esp, 4

  .fat_table_error:
        add     esp, 4
        MovStk  eax, ERROR_FAT_TABLE
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.get_file_info ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> edx ^= fs.get_file_info_query_params_t
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.get_file_info('%s')\n", esi

        cmp     byte[esi], 0
        je      .not_implemented_error

        call    fs.fat._.find_file_lfn
        jc      .file_not_found_error

        xor     ebp, ebp
        mov     esi, [edx + fs.get_file_info_query_params_t.buffer_ptr]
        and     [esi + fs.file_info_t.flags], 0
        call    fs.fat.util.fat_entry_to_bdfe.direct

        xor     eax, eax ; ERROR_SUCCESS
        ret

  .not_implemented_error:
        mov     eax, ERROR_NOT_IMPLEMENTED
        ret

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.set_file_info ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> edx ^= fs.set_file_info_query_params_t
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.set_file_info('%s')\n", esi

        cmp     byte[esi], 0
        je      .not_implemented_error

        call    fs.fat._.find_file_lfn
        jc      .file_not_found_error

        push    eax
        mov     edx, [edx + fs.set_file_info_query_params_t.buffer_ptr]
        call    fs.fat.util.bdfe_to_fat_entry
        pop     eax

        call    fs.fat._.write_sector
        jnz     .device_error

        xor     eax, eax ; ERROR_SUCCESS
        ret

  .not_implemented_error:
        mov     eax, ERROR_NOT_IMPLEMENTED
        ret

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.delete_file ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.delete_file('%s')\n", esi

        cmp     byte[esi], 0
        je      .access_denied_error ; cannot delete root

        call    fs.fat._.find_file_lfn
        jc      .file_not_found_error

        push    0 eax

        cmp     dword[edi + fs.fat.dir_entry_t.name], '.   '
        je      .access_denied_error_2
        cmp     dword[edi + fs.fat.dir_entry_t.name], '..  '
        je      .access_denied_error_2
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .delete_entry

        ; can delete empty folders only
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        call    fs.fat.util.cluster_to_sector

        push    edi eax

        lea     eax, [esp]
        call    fs.fat._.first_dir_entry
        jnc     @f

        test    eax, eax
        jnz     .device_error_2
        jmp     .empty

    @@: add     edi, 2 * sizeof.fs.fat.dir_entry_t

  .check_empty:
        cmp     [edi + fs.fat.dir_entry_t.name], 0
        je      @f
        cmp     [edi + fs.fat.dir_entry_t.name], 0xe5
        jne     .access_denied_error_3

    @@: lea     eax, [esp]
        call    fs.fat._.next_dir_entry
        jnc     .check_empty
        test    eax, eax
        jnz     .device_error_2

  .empty:
        add     esp, 4
        pop     edi

  .delete_entry:
        lea     eax, [esp]
        push    edi
        call    fs.fat._.begin_cluster_write
        pop     edi

        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        call    fs.fat.util.cluster_to_sector
        mov     [esp + 4], eax

        ; delete folder entry
        mov     [edi + fs.fat.dir_entry_t.name], 0xe5

  .delete_lfn_entry:
        ; delete LFN (if present)
        add     edi, -sizeof.fs.fat.dir_entry_t

        lea     eax, [esp]
        call    fs.fat._.prev_cluster_write
        jnc     @f

        test    eax, eax
        jnz     .device_error_3
        jmp     .delete_complete_eof

    @@: cmp     [edi + fs.fat.dir_entry_t.name], 0xe5
        je      .delete_complete
        cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        jne     .delete_complete

        mov     [edi + fs.fat.dir_entry_t.name], 0xe5
        jmp     .delete_lfn_entry

  .delete_complete:
        lea     eax, [esp]
        call    fs.fat._.end_cluster_write

  .delete_complete_eof:
        add     esp, 4
        pop     eax

        xor     edx, edx ; mark free
        mov     ebp, [ebx + fs.fat.partition_t.fat_vftbl]
        call    [ebp + fs.fat.vftbl_t.delete_chain]
        jc      .device_error

        xor     eax, eax ; ERROR_SUCCESS
        ret

  .access_denied_error_3:
        add     esp, 8

  .access_denied_error_2:
        add     esp, 8

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .device_error_2:
        add     esp, 8

  .device_error_3:
        add     esp, 8

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.find_file_lfn ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path
;> ebp ^= filename
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 1 - file not found
;< CF = 0,
;<   edi ^= fs.fat.dir_entry_t
;<   eax #= directory cluster
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi

        push    [ebx + fs.fat.partition_t.root_dir_sector]

  .next_level:
        call    fs.fat.util.find_long_name
        jc      .not_found
        cmp     byte[esi], 0
        je      .found

  .continue:
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .not_found

        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        call    fs.fat.util.cluster_to_sector
        mov     [esp], eax
        jmp     .next_level

  .not_found:
        add     esp, 4
        pop     edi esi
        stc
        ret

  .found:
        test    ebp, ebp
        jz      @f
        mov     esi, ebp
        xor     ebp, ebp
        jmp     .continue

    @@: pop     eax
        add     esp, 4 ; cF = 0
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.prev_dir_entry ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_ERROR, "FIXME: not implemented: fs.fat._.prev_dir_entry\n"
        mov     eax, ERROR_NOT_IMPLEMENTED
        stc
        ret

;///        push    eax
;///        lea     eax, [ebx + fs.fat.partition_t.buffer]
;///        cmp     edi, eax
;///        pop     eax
;///        jbe     .prev_sector
;///
;///        sub     edi, sizeof.fs.fat.dir_entry_t
;///        ret     ; CF = 0
;///
;///  .prev_sector:
;///        push    ecx edi
;///
;///        push    eax
;///        mov     eax, [eax]
;///        lea     edi, [ebx + fs.fat.partition_t.fat]
;///        mov     ecx, 2849
;///        repne
;///        scasw
;///        pop     eax
;///        jne     .eof
;///
;///        sub     edi, fs.fat.partition_t.fat + 2
;///        sub     edi, ebx
;///        shr     edi, 1
;///        xchg    eax, edi
;///        stosd
;///        pop     edi ecx
;///
;///        call    fs.fat._.read_cluster
;///        jc      .exit
;///
;///        add     edi, 512 - sizeof.fs.fat.dir_entry_t
;///        ret     ; CF = 0
;///
;///  .eof:
;///        pop     edi ecx
;///        xor     eax, eax
;///        stc
;///
;///  .exit:
;///        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.next_dir_entry ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        lea     eax, [ebx + fs.fat.partition_t.buffer + 512 - sizeof.fs.fat.dir_entry_t]
        cmp     edi, eax
        pop     eax
        jae     .next_sector

        add     edi, sizeof.fs.fat.dir_entry_t
        ret     ; CF = 0

  .next_sector:
        push    ecx edx

        mov     edx, eax
        mov     eax, [edx]
        mov     ecx, [ebx + fs.fat.partition_t.fat_vftbl]
        call    [ecx + fs.fat.vftbl_t.get_next_cluster]
        jc      .eof

        mov     [edx], eax

        pop     edx ecx

        call    fs.fat._.read_cluster
        ret

  .eof:
        pop     edx ecx
        xor     eax, eax
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.first_dir_entry ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax]
        call    fs.fat._.read_cluster
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.read_cluster ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= cluster number
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        call    fs.fat._.read_sector
        jnz     .error

        clc
        ret

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.read_sector ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= sector number
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< edi ^= buffer
;< eflags[zf] = 1 (ok) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat._.read_sector(0x%x:%u)\n", eax, eax
        push    ecx edx

        xor     edx, edx
        MovStk  ecx, 1
        lea     edi, [ebx + fs.fat.partition_t.buffer]
        call    fs.read

        test    eax, eax
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.write_sector ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= sector number
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< eflags[zf] = 1 (ok) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat._.write_sector(0x%x:%u)\n", eax, eax
        push    ecx edx

        xor     edx, edx
        MovStk  ecx, 1
        lea     esi, [ebx + fs.fat.partition_t.buffer]
        call    fs.write

        test    eax, eax
        pop     edx ecx
        ret
kendp
