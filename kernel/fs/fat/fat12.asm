;;======================================================================================================================
;;///// fat12.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
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

struct fs.fat12.partition_data_t
  label         rb 16
  fat           rw (8 * 1024) / 2
  buffer        rb 9 * 1024
  is_fat_valid  db ?
  is_root_valid db ?
ends

uglobal
  n_sector              dd 0  ; temporary save for sector value
; clust_tmp_flp         dd 0  ; used by analyze_directory and analyze_directory_to_write
  path_pointer_flp      dd 0
  pointer_file_name_flp dd 0
; save_root_flag        db 0
  save_flag             db 0
  root_read             db 0  ; 0-necessary to load root, 1-not to load root
  flp_fat               db 0  ; 0-necessary to load fat, 1-not to load fat
  flp_number            db 0  ; 1- Floppy A, 2-Floppy B
  old_track             db 0  ; old value track
  flp_label             rb 15 ; Label and ID of inserted floppy disk
endg

iglobal
  jump_table fs.fat12, vftbl, 0, \
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
        rep     movsd

        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.expand_filename ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? exapand filename with '.' to 11 character
;-----------------------------------------------------------------------------------------------------------------------
;> eax - pointer to filename
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi ebx

        mov     edi, esp ; check for '.' in the name
        add     edi, 12 + 8

        mov     esi, eax

        mov     eax, edi
        mov     dword[eax + 0], '    '
        mov     dword[eax + 4], '    '
        mov     dword[eax + 8], '    '

  .flr1:
        cmp     byte[esi], '.'
        jne     .flr2
        mov     edi, eax
        add     edi, 7
        jmp     .flr3

  .flr2:
        mov     bl, [esi]
        mov     [edi], bl

  .flr3:
        inc     esi
        inc     edi

        mov     ebx, eax
        add     ebx, 11

        cmp     edi, ebx
        jbe     .flr1

        pop     ebx edi esi
        ret
kendp

if defined COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
kproc floppy_fileread ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? fileread - sys floppy
;-----------------------------------------------------------------------------------------------------------------------
;> eax = points to filename 11 chars  - for root directory
;> ebx = first wanted block       ; 1+ ; if 0 then set to 1
;> ecx = number of blocks to read ; 1+ ; if 0 then set to 1
;> edx = mem location to return data
;> esi = length of filename 12*X
;> edi = pointer to path   /fd/1/......  - for all files in nested directories
;-----------------------------------------------------------------------------------------------------------------------
;< ebx = size or 0xffffffff file not found
;< eax = 0 ok read or other = errormsg
;<       10 = access denied
;-----------------------------------------------------------------------------------------------------------------------
        mov     [save_flag], 0
        mov     [path_pointer_flp], edi
        test    esi, esi ; return ramdisk root
        jnz     .fr_noroot_1
        cmp     ebx, 224 / 16
        jbe     .fr_do_1
        mov     eax, ERROR_FILE_NOT_FOUND
        xor     ebx, ebx
        mov     [flp_status], ebx
        ret

  .fr_do_1:
        push    ebx ecx edx
        call    read_flp_root
        pop     edx ecx ebx
        cmp     [FDC_Status], 0
        jne     .fdc_status_error_1
        mov     edi, edx
        dec     ebx
        shl     ebx, 9
        mov     esi, FLOPPY_BUFF
        add     esi, ebx
        shl     ecx, 9
        cld
        rep     movsb
        xor     eax, eax
        xor     ebx, ebx
;       mov     eax, 0 ; ok read
;       mov     ebx, 0
        mov     [flp_status], eax
        ret

  .fdc_status_error_1:
        xor     eax, eax
        mov     [flp_status], eax
        mov     eax, ERROR_ACCESS_DENIED
        or      ebx, -1
        ret

  .fr_noroot_1:
        sub     esp, 32
        call    fs.fat12.expand_filename

  .frfloppy_1:
        test    ebx, ebx
        jnz     .frfl5_1
        mov     ebx, 1

  .frfl5_1:
        test    ecx, ecx
        jnz     .frfl6_1
        mov     ecx, 1

  .frfl6_1:
        dec     ebx
        push    eax
        push    eax ebx ecx edx esi edi
        call    read_flp_fat
        cmp     [FDC_Status], 0
        jne     .fdc_status_error_3_1
        mov     [FDD_Track], 0
        mov     [FDD_Head], 1
        mov     [FDD_Sector], 2
        call    SeekTrack
        mov     dh, 14

  .l.20_1:
        call    ReadSectWithRetr
        cmp     [FDC_Status], 0
        jne     .fdc_status_error_3_1
        mov     dl, 16
        mov     edi, FDC_DMA_BUFFER
        inc     [FDD_Sector]

  .l.21_1:
        mov     esi, eax ; Name of file we want
        mov     ecx, 11
        cld
        rep     cmpsb ; Found the file?
        je      .fifound_1 ; Yes
        add     ecx, 21
        add     edi, ecx ; Advance to next entry
        dec     dl
        test    dl, dl
        jnz     .l.21_1
        dec     dh
        test    dh, dh
        jnz     .l.20_1

  .fdc_status_error_3:
        mov     eax, ERROR_FILE_NOT_FOUND ; file not found ?
        or      ebx, -1
        add     esp, 32 + 28
        mov     [flp_status], 0
        ret

  .fdc_status_error_3_2:
        cmp     [FDC_Status], 0
        je      .fdc_status_error_3

  .fdc_status_error_3_1:
        add     esp, 32 + 28
        jmp     .fdc_status_error_1

  .fifound_1:
        mov     eax, [path_pointer_flp]
        cmp     byte[eax + 36], 0
        je      .fifound_2
        add     edi, 0x0f
        mov     eax, [edi]
        and     eax, 65535
        mov     ebx, [path_pointer_flp]
        add     ebx, 36
        call    get_cluster_of_a_path_flp
        jc      .fdc_status_error_3_2
        mov     ebx, [ebx - 11 + 28] ; file size
        mov     [esp + 20], ebx
        mov     [esp + 24], ebx
        jmp     .fifound_3

  .fifound_2:
        mov     ebx, [edi - 11 + 28] ; file size
        mov     [esp + 20], ebx
        mov     [esp + 24], ebx
        add     edi, 0x0f
        mov     eax, [edi]

  .fifound_3:
        and     eax, 65535
        mov     [n_sector], eax ; eax=cluster

  .frnew_1:
        add     eax, 31 ; bootsector + 2 * fat + filenames
        cmp     dword[esp + 16], 0 ; wanted cluster ?
        jne     .frfl7_1
        call    read_chs_sector
        cmp     [FDC_Status], 0
        jne     .fdc_status_error_5
        mov     edi, [esp + 8]
        call    give_back_application_data_1
        add     dword[esp + 8], 512
        dec     dword[esp + 12] ; last wanted cluster ?
        cmp     dword[esp + 12], 0
        je      .frnoread_1
        jmp     .frfl8_1

  .frfl7_1:
        dec     dword[esp + 16]

  .frfl8_1:
        mov     edi, [n_sector]
        shl     edi, 1 ; find next cluster from FAT
        add     edi, FLOPPY_FAT
        mov     eax, [edi]
        and     eax, 4095
        mov     edi, eax
        mov     [n_sector], edi
        cmp     edi, 4095 ; eof  - cluster
        jz      .frnoread2_1
        cmp     dword[esp + 24], 512 ; eof - size
        jb      .frnoread_1
        sub     dword[esp + 24], 512
        jmp     .frnew_1

  .frnoread2_1:
        cmp     dword[esp + 16], 0 ; eof without read ?
        je      .frnoread_1
        mov     [fdc_irq_func], util.noop
        pop     edi esi edx ecx
        add     esp, 4
        pop     ebx ; ebx <- eax : size of file
        add     esp, 36
        mov     eax, ERROR_END_OF_FILE ; end of file
        mov     [flp_status], 0
        ret

  .frnoread_1:
        pop     edi esi edx ecx
        add     esp, 4
        pop     ebx ; ebx <- eax : size of file
        add     esp, 36
        xor     eax, eax
        mov     [flp_status], eax
        ret

  .fdc_status_error_5:
        pop     edi esi edx ecx
        add     esp, 4
        pop     ebx ; ebx <- eax : size of file
        add     esp, 36
        jmp     .fdc_status_error_1
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc read_chs_sector ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    calculate_chs
        call    ReadSectWithRetr
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc read_flp_root ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        call    check_label
        cmp     [FDC_Status], 0
        jne     .unnecessary_root_read
        cmp     [root_read], 1
        je      .unnecessary_root_read
        mov     [FDD_Track], 0
        mov     [FDD_Head], 1
        mov     [FDD_Sector], 2
        mov     edi, FLOPPY_BUFF
        call    SeekTrack

  .read_flp_root_1:
        call    ReadSectWithRetr
        cmp     [FDC_Status], 0
        jne     .unnecessary_root_read
        push    edi
        call    give_back_application_data_1
        pop     edi
        add     edi, 512
        inc     [FDD_Sector]
        cmp     [FDD_Sector], 16
        jne     .read_flp_root_1
        mov     [root_read], 1

  .unnecessary_root_read:
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc read_flp_fat ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        call    check_label
        cmp     [FDC_Status], 0
        jne     .unnecessary_flp_fat
        cmp     [flp_fat], 1
        je      .unnecessary_flp_fat
        mov     [FDD_Track], 0
        mov     [FDD_Head], 0
        mov     [FDD_Sector], 2
        mov     edi, FLOPPY_BUFF
        call    SeekTrack

  .read_flp_fat_1:
        call    ReadSectWithRetr
        cmp     [FDC_Status], 0
        jne     .unnecessary_flp_fat
        push    edi
        call    give_back_application_data_1
        pop     edi
        add     edi, 512
        inc     [FDD_Sector]
        cmp     [FDD_Sector], 19
        jne     .read_flp_fat_1
        mov     [FDD_Sector], 1
        mov     [FDD_Head], 1
        call    ReadSectWithRetr
        cmp     [FDC_Status], 0
        jne     .unnecessary_flp_fat
        call    give_back_application_data_1
        mov     esi, FLOPPY_BUFF
        mov     edi, FLOPPY_FAT
        call    fs.fat12.calculate_fat_chain
        mov     [root_read], 0
        mov     [flp_fat], 1

  .unnecessary_flp_fat:
        popa
        ret
kendp

end if ; COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
kproc check_label ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        mov     [FDD_Track], 0
        mov     [FDD_Head], 0
        mov     [FDD_Sector], 1
        call    RecalibrateFDD
        cmp     [FDC_Status], 0
        jne     .fdc_status_error
        call    SeekTrack
        cmp     [FDC_Status], 0
        jne     .fdc_status_error
        call    ReadSectWithRetr
        cmp     [FDC_Status], 0
        jne     .fdc_status_error
        mov     esi, flp_label
        mov     edi, FDC_DMA_BUFFER + 39
        mov     ecx, 15
        cld
        rep     cmpsb
        je      .same_label
        mov     [root_read], 0
        mov     [flp_fat], 0

  .same_label:
        mov     esi, FDC_DMA_BUFFER + 39
        mov     edi, flp_label
        mov     ecx, 15
        cld
        rep     movsb
        popad
        ret

  .fdc_status_error:
        popad
        ret
kendp

if defined COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_chs ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     bl, [FDD_Track]
        mov     [old_track], bl
        mov     ebx, 18
        xor     edx, edx
        div     ebx
        inc     edx
        mov     [FDD_Sector], dl
        xor     edx, edx
        mov     ebx, 2
        div     ebx
        mov     [FDD_Track], al
        mov     [FDD_Head], 0
        test    edx, edx
        jz      .no_head_2
        inc     [FDD_Head]

  .no_head_2:
        mov     dl, [old_track]
        cmp     dl, [FDD_Track]
        je      .no_seek_track_1
        call    SeekTrack

  .no_seek_track_1:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_cluster_of_a_path_flp ;///////////////////////////////////////////////////////////////////////////////////////
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
        push    edx
        mov     edx, ebx

  .search_end_of_path_flp:
        cmp     [save_flag], 0
        jne     .search_end_of_path_flp_1
        cmp     byte[edx], 0
        je      .found_end_of_path_flp
        jmp     .search_end_of_path_flp_2

  .search_end_of_path_flp_1:
        cmp     byte[edx + 12], 0
        je      .found_end_of_path_flp

  .search_end_of_path_flp_2:
        inc     edx ; '/'
        call    analyze_directory_flp
        jc      .directory_not_found_flp

        mov     eax, [ebx + 20 - 2] ; read the HIGH 16bit cluster field
        mov     ax, [ebx + 26] ; read the LOW 16bit cluster field
        and     eax, 0x0fff ; [fatMASK]
        add     edx, 11 ; 8+3 (name+extension)
        jmp     .search_end_of_path_flp

  .found_end_of_path_flp:
        inc     edx
        mov     [pointer_file_name_flp], edx
        pop     edx
        clc     ; no errors
        ret

  .directory_not_found_flp:
        pop     edx
        stc     ; errors occour
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc analyze_directory_flp ;///////////////////////////////////////////////////////////////////////////////////////////

end if ; COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.read_file ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.read_file_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= bytes read (on success)
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .access_denied_error

        cmp     dword[edx + fs.read_file_query_params_t.range.offset + 4], 0
        jne     .end_of_file_error

        call    fs.fat12._.read_fat
        or      eax, eax
        jnz     .device_error

        call    fs.fat12._.find_file_lfn
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

    @@: movzx   esi, [edi + fs.fat.dir_entry_t.start_cluster.low]
        mov     edx, [edx + fs.read_file_query_params_t.buffer_ptr]
        push    edx

  .read_next_sector:
        jecxz   .done

        cmp     esi, 2
        jb      .end_of_file_error_in_loop
        cmp     esi, 0x0ff8
        jae     .end_of_file_error_in_loop

        sub     ebp, 512
        jae     .skip_sector

        lea     eax, [esi + 31]
        call    fs.fat12._.read_sector
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
        mov     eax, [ebx + fs.partition_t.user_data]
        movzx   esi, [eax + fs.fat12.partition_data_t.fat + esi * 2]
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
        add     esp, 4

  .end_of_file_error:
        mov     eax, ERROR_END_OF_FILE
        or      ebx, -1
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
kproc fs.fat12.read_directory ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to directory
;> edx ^= fs.read_directory_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= directory entries read (on success)
;-----------------------------------------------------------------------------------------------------------------------
        call    fs.fat12._.read_fat
        or      eax, eax
        jnz     .device_error

        cmp     byte[esi], 0
        je      .root_directory

        call    fs.fat12._.find_file_lfn
        jc      .file_not_found_error

        ; do not allow reading files
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .access_denied_error

        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        add     eax, 31
        push    eax
        push    0
        jmp     .prepare_header

  .root_directory:
        push    19
        push    14

  .prepare_header:
        xor     eax, eax
        mov     ecx, sizeof.fs.file_info_header_t / 4
        mov     edi, [edx + fs.read_directory_query_params_t.buffer_ptr]
        rep     stosd

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
        mov     eax, [esp + 12 + 262 * 2 + 4]
        call    fs.fat12._.read_sector
        jnz     .error

  .get_entry_name:
        cmp     byte[esp], 0
        jne     .do_bdfe

        call    fs.fat.get_name
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
        call    fs.fat.fat_entry_to_bdfe

  .move_to_next_entry:
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer + 512
        add     edi, sizeof.fs.fat.dir_entry_t
        cmp     edi, eax
        jb      .get_entry_name

        inc     dword[esp + 12 + 262 * 2 + 4]
        dec     dword[esp + 12 + 262 * 2]
        jz      .done ; end of root directory
        jns     .read_next_sector ; more sectors in root directory are available

        ; read next sector from FAT
        push    ebp
        mov     ebp, [ebx + fs.partition_t.user_data]
        mov     eax, [esp + 4 + 12 + 262 * 2 + 4]
        movzx   eax, [ebp + fs.fat12.partition_data_t.fat + (eax - 31 - 1) * 2]
        pop     ebp
        cmp     eax, 0x0ff8
        jae     .done ; end of ordinary directory

        add     eax, 31
        mov     [esp + 12 + 262 * 2 + 4], eax
        and     dword[esp + 12 + 262 * 2], 0
        jmp     .read_next_sector

  .done:
        add     esp, 12 + 262 * 2 + 8

        mov     ebx, [edx + fs.file_info_header_t.files_read]
        xor     eax, eax
        dec     ecx
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: ret

  .error:
        add     esp, 12 + 262 * 2 + 8
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
kproc util.noop ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.raise_cf ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_mem_first ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.buffer + 1024
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_mem_next ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        push    eax
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer + 1024 + 14 * 512
        add     edi, sizeof.fs.fat.dir_entry_t
        cmp     edi, eax
        pop     eax
        cmc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_begin_write ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax]
        add     eax, 19
        call    fs.fat12._.read_sector
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_end_write ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax]
        add     eax, 19
        call    fs.fat12._.write_sector
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_prev_write ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer
        cmp     edi, eax
        pop     eax
        jb      @f
        ret

    @@: call    fs.fat12._.root_end_write
        jmp     fs.fat12._.root_prev
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_begin_write ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax]
        add     eax, 31
        call    fs.fat12._.read_sector
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_end_write ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax]
        add     eax, 31
        call    fs.fat12._.write_sector
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_prev_write ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer
        cmp     edi, eax
        pop     eax
        jb      @f
        ret

    @@: call    fs.fat12._.notroot_end_write
        jmp     fs.fat12._.notroot_prev
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_next_write ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer + 512
        cmp     edi, eax
        pop     eax
        jae     @f
        ret

    @@: call    fs.fat12._.notroot_end_write
        jmp     fs.fat12._.notroot_next
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_extend_dir ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        ; find free cluster in FAT
        pusha

        call    fs.fat12._.find_free_cluster
        jc      .not_found

        mov     word[edi], 0x0fff ; mark as last cluster

        mov     edx, [ebx + fs.partition_t.user_data]
        add     edx, fs.fat12.partition_data_t.fat

        mov     edi, [esp + regs_context32_t.eax]
        mov     ecx, [edi]
        mov     [edx + ecx * 2], ax
        mov     [edi], eax

        xor     eax, eax
        mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.buffer
        mov     ecx, 512 / 4
        rep     stosd

        popa
        call    fs.fat12._.notroot_end_write
        mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.buffer
        clc
        ret

  .not_found:
        popa
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.string.length ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= string
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= length
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx esi
        xor     ecx, ecx
        xchg    eax, esi

    @@: lodsd

        or      al, al
        jz      .exit
        or      ah, ah
        jz      .add_1
        shr     eax, 16
        or      al, al
        jz      .add_2
        or      ah, ah
        jz      .add_3

        add     ecx, 4
        jmp     @b

  .add_3:
        inc     ecx

  .add_2:
        inc     ecx

  .add_1:
        inc     ecx

  .exit:
        xchg    eax, ecx
        pop     esi ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.find_parent_dir ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ecx ^= fs.fat.dir_handlers_t
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

    @@: call    fs.fat.name_is_legal
        pop     esi
        jnc     .file_not_found_error

        test    edi, edi
        jnz     .not_root

        xor     ebp, ebp
        mov     ecx, fs.fat12._.dir_handlers.root_mem

        jmp     .exit

  .not_root:
        cmp     byte[edi + 1], 0
        je      .access_denied_error

        ; check parent entry existence
        mov     byte[edi], 0
        push    edi
        call    fs.fat12._.find_file_lfn
        pop     esi
        mov     byte[esi], '/'
        jc      .file_not_found_error

        ; edi ^= parent entry
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY ; must be directory
        jz      .access_denied_error

        movzx   ebp, [edi + fs.fat.dir_entry_t.start_cluster.low] ; ebp #= cluster
        cmp     ebp, 2
        jb      .fat_table_error
        cmp     ebp, 2849
        jae     .fat_table_error

        mov     ecx, fs.fat12._.dir_handlers.non_root

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

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.get_free_clusters_count ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= number of free clusters
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx edi

        mov     ecx, 2849
        mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.fat
        xor     eax, eax
        xor     edx, edx

    @@: repne   scasw
        jne     .exit
        inc     edx
        jmp     @b

  .exit:
        xchg    eax, edx
        pop     edi edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.find_free_cluster ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< Cf ~= 0 (ok) or 1 (error)
;< eax #= free cluster number
;< edi ^= free cluster in FAT
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     ecx, 2849
        mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.fat

        xor     eax, eax
        repne   scasw
        pop     ecx
        jne     .error

        dec     edi
        dec     edi
        lea     eax, [edi - fs.fat12.partition_data_t.fat]
        sub     eax, [ebx + fs.partition_t.user_data]
        shr     eax, 1

        clc
        ret

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.create_dir_entry ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;> edx #= number of free clusters
;> esi ^= entry name
;> [esp + 4] ^= fs.fat.dir_handlers_t
;> [esp + 8] #= parent directory start cluster
;-----------------------------------------------------------------------------------------------------------------------
;< edi ^= fs.fat.dir_entry_t
;< [esp + 8] #= entry cluster
;-----------------------------------------------------------------------------------------------------------------------
        pusha

        push    ebp dword[esp + 4 + sizeof.regs_context32_t + 4]
        call    fs.fat.find_long_name
        pop     eax eax
        jnc     .access_denied_error

        ; file is not found; generate short name
        sub     esp, 12
        mov     edi, esp
        call    fs.fat.gen_short_name

  .test_short_name_loop:
        push    esi edi ecx
        mov     esi, edi
        lea     eax, [esp + 12 + 12 + sizeof.regs_context32_t + 4 + 4]
        mov     [eax], ebp
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.first_entry
        jc      .short_name_not_found

  .test_short_name_entry:
        cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        je      .test_short_name_cont
        mov     ecx, 11
        push    esi edi
        repe    cmpsb
        pop     edi esi
        je      .short_name_found

  .test_short_name_cont:
        lea     eax, [esp + 12 + 12 + sizeof.regs_context32_t + 4 + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.next_entry
        jc      .short_name_not_found
        jmp     .test_short_name_entry

  .short_name_found:
        pop     ecx edi esi
        call    fs.fat.next_short_name
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
        repne   scasb
        mov_s_  eax, 1 ; 1 entry
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
        lea     eax, [esp + 4 + 8 + 8 + 12 + sizeof.regs_context32_t + 4 + 4]
        mov     [eax], ebp
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.first_entry
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
        lea     eax, [esp + 4 + 8 + 8 + 12 + sizeof.regs_context32_t + 4 + 4]
        push    dword[eax]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.next_entry
        jc      .check_for_scan_error
        add     esp, 4
        pop     eax
        jmp     .scan_dir

  .check_for_scan_error:
        pop     dword[esp + 4 + 8 + 8 + 12 + sizeof.regs_context32_t + 4 + 4]
        or      eax, eax
        pop     eax
        jnz     .device_error_3

        mov     [eax], ecx

        ; are there free clusters left?
        cmp     [esp + 8 + 8 + 12 + regs_context32_t.edx], 0
        je      .disk_full_error_2

        push    eax
        lea     eax, [esp + 4 + 8 + 8 + 12 + sizeof.regs_context32_t + 4 + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.extend_dir
        pop     eax
        jc      .disk_full_error_2
        dec     [esp + 8 + 8 + 12 + regs_context32_t.edx]
        jmp     .scan_dir

  .free:
        test    ecx, ecx
        jnz     @f

        mov     [esp], edi ; save first entry pointer
        mov     ecx, [esp + 8 + 8 + 12 + sizeof.regs_context32_t + 4 + 4]
        mov     [esp + 4], ecx ; save first entry sector
        xor     ecx, ecx

    @@: inc     ecx
        cmp     ecx, eax
        jb      .scan_cont

        ; found!
        pop     edi ; edi points to first entry in free chunk
        pop     dword[esp + 8 + 12 + sizeof.regs_context32_t + 4 + 4]

        ; calculate name checksum
        mov     eax, [esp]
        call    fs.fat.calculate_name_checksum

        dec     ecx
        jz      .not_lfn

        push    esi eax

        lea     eax, [esp + 8 + 8 + 12 + sizeof.regs_context32_t + 4 + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.begin_write

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
        call    fs.fat.read_symbols ; name.part_1
        mov     ax, FS_FAT_ATTR_LONG_NAME
        stosw   ; attributes
        mov     al, [esp + 4]
        stosb   ; checksum
        mov     cl, 6
        call    fs.fat.read_symbols ; name.part_2
        xor     eax, eax
        stosw   ; start_cluster
        mov     cl, 2
        call    fs.fat.read_symbols ; name.part_3

        pop     ecx

        lea     eax, [esp + 8 + 8 + 12 + sizeof.regs_context32_t + 4 + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.next_write

        xor     eax, eax
        loop    .write_lfn

        pop     eax esi

  .not_lfn:
        xchg    esi, [esp]
        mov     ecx, 11
        rep     movsb
        sub     edi, 11
        pop     esi ecx
        add     esp, 12

        mov     al, [esp + regs_context32_t.cl]
        mov     [edi + fs.fat.dir_entry_t.attributes], al
        and     [edi + fs.fat.dir_entry_t.created_at.time_ms], 0
        call    fs.fat.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.created_at.time], ax
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax
        call    fs.fat.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.created_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax

        push    edi
        call    fs.fat12._.find_free_cluster
        mov     ecx, edi
        pop     edi
        jc      .disk_full_error_3

        mov     word[ecx], 0x0fff

        and     [edi + fs.fat.dir_entry_t.start_cluster.high], 0
        mov     [edi + fs.fat.dir_entry_t.start_cluster.low], ax
        and     [edi + fs.fat.dir_entry_t.size], 0

        lea     eax, [esp + sizeof.regs_context32_t + 4 + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.end_write

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
kproc fs.fat12._.write_file ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;> eax #= data offset
;> ecx #= data size
;> esi ^= data
;> edi ^= fs.fat.dir_entry_t
;> [esp + 4] ^= fs.fat.dir_handlers_t
;> [esp + 8] #= entry cluster
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jz      .success_exit

        pusha

        mov     ebp, [ebx + fs.partition_t.user_data]
        add     ebp, fs.fat12.partition_data_t.fat

        push    eax
        push    ecx
        push    edi

        movzx   ebp, [edi + fs.fat.dir_entry_t.start_cluster.low]

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
        lea     eax, [ebp + 31]
        call    fs.fat12._.read_sector
        pop     eax
        jnz     .device_error

    @@: mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.buffer
        neg     eax
        add     eax, 512
        add     edi, eax
        push    ecx
        rep     movsb

        lea     eax, [ebp + 31]
        push    esi
        call    fs.fat12._.write_sector
        pop     esi
        pop     ecx
        jnz     .device_error

        and     dword[esp + 8], 0
        sub     [esp + 4], ecx
        jz      .done

  .skip_cluster:
        call    .get_next_cluster
        jc      .disk_full_error
        jmp     .write_loop

  .done:
        pop     edi ecx eax

        lea     eax, [esp + sizeof.regs_context32_t + 4 + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.begin_write

        call    fs.fat.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax
        call    fs.fat.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax

        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jnz     @f

        mov     eax, [esp + regs_context32_t.eax]
        add     eax, [esp + regs_context32_t.ecx]
        cmp     eax, [edi + fs.fat.dir_entry_t.size]
        jbe     @f
        mov     [edi + fs.fat.dir_entry_t.size], eax

    @@: lea     eax, [esp + sizeof.regs_context32_t + 4 + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.end_write

        popa

  .success_exit:
        xor     eax, eax ; ERROR_SUCCESS

  .exit:
        ret

  .disk_full_error:
        add     esp, 12 + sizeof.regs_context32_t
        mov     eax, ERROR_DISK_FULL
        ret

  .device_error:
        add     esp, 12 + sizeof.regs_context32_t
        mov     eax, ERROR_DEVICE_FAIL
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .get_next_cluster: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx
        mov     edx, [ebx + fs.partition_t.user_data]
        lea     edx, [edx + fs.fat12.partition_data_t.fat + ebp * 2]
        movzx   ebp, word[edx]
        cmp     ebp, 0x0ff8
        jae     @f

        pop     edx eax
        clc
        ret

    @@: ; allocate new cluster
        call    fs.fat12._.find_free_cluster
        jc      @f

        mov     [edx], ax
        mov     word[edi], 0x0fff
        xchg    eax, ebp

    @@: pop     edx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.create_directory ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to directory
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .access_denied_error

        call    fs.fat12._.read_fat
        test    eax, eax
        jnz     .device_error

        call    fs.fat12._.get_free_clusters_count
        dec     eax ; new directory would occupy 1 cluster
        jb      .disk_full_error

        push    eax
        call    fs.fat12._.find_parent_dir
        test    eax, eax
        pop     edx
        jnz     .exit

        test    ebp, ebp
        jnz     @f

        call    fs.fat12._.read_root_directory
        or      eax, eax
        jnz     .device_error

    @@: push    ebp ecx

        mov     cl, FS_FAT_ATTR_DIRECTORY
        call    fs.fat12._.create_dir_entry
        test    eax, eax
        jnz     .free_stack_and_exit

        mov     esi, edi
        call    .get_dir_data

        call    fs.fat12._.write_file
        test    eax, eax
        jnz     .free_stack_and_exit

        add     esp, 8

        test    ebp, ebp
        jnz     @f

        call    fs.fat12._.write_root_directory
        or      eax, eax
        jnz     .device_error

    @@: call    fs.fat12._.write_fat
        or      eax, eax
        jnz     .device_error

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
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< esi ^= data
;< ecx #= data size
;-----------------------------------------------------------------------------------------------------------------------
        push    edi

        mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.buffer + 512
        push    edi

        mov_s_  ecx, sizeof.fs.fat.dir_entry_t / 4

        push    ecx esi
        rep     movsd
        pop     esi ecx

        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name], '.   '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 4], '    '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 8], '   '
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY

        rep     movsd

        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name], '..  '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 4], '    '
        mov     dword[edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.name + 8], '   '
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        mov     [edi - sizeof.fs.fat.dir_entry_t + fs.fat.dir_entry_t.start_cluster.low], bp

        xor     eax, eax
        mov     ecx, (512 - 2 * sizeof.fs.fat.dir_entry_t) / 4
        rep     stosd

        pop     esi
        mov     ecx, 512

        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.create_file ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.create_file_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= bytes written (on success)
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .access_denied_error

        push    edx

        call    fs.fat12._.read_fat
        test    eax, eax
        jnz     .device_error

        call    fs.fat12._.get_free_clusters_count
        mov     ecx, [edx + fs.create_file_query_params_t.length]
        xchg    eax, ecx
        call    fs.fat12._.bytes_to_clusters
        sub     ecx, eax ; new file would occupy <eax> clusters
        jb      .disk_full_error

        push    ecx
        call    fs.fat12._.find_parent_dir
        test    eax, eax
        pop     edx
        jnz     .exit

        test    ebp, ebp
        jnz     @f

        call    fs.fat12._.read_root_directory
        or      eax, eax
        jnz     .device_error

    @@: push    ebp ecx

        xor     cl, cl
        call    fs.fat12._.create_dir_entry
        test    eax, eax
        jnz     .free_stack_and_exit

        mov     esi, [esp + 8]
        mov     ecx, [esi + fs.create_file_query_params_t.length]
        mov     esi, [esi + fs.create_file_query_params_t.buffer_ptr]

        call    fs.fat12._.write_file
        test    eax, eax
        jnz     .free_stack_and_exit

        add     esp, 8

        test    ebp, ebp
        jnz     @f

        call    fs.fat12._.write_root_directory
        or      eax, eax
        jnz     .device_error

    @@: call    fs.fat12._.write_fat
        or      eax, eax
        jnz     .device_error

        mov     ebx, ecx

  .exit:
        add     esp, 4
        ret

  .free_stack_and_exit:
        add     esp, 8 + 4
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
kproc fs.fat12.write_file ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.write_file_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= bytes written (on success)
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .access_denied_error

        cmp     dword[edx + fs.write_file_query_params_t.range.offset + 4], 0
        jne     .disk_full_error

        call    fs.fat12._.read_fat
        test    eax, eax
        jnz     .device_error

        call    fs.fat12._.find_file_lfn
        jc      .file_not_found_error

        push    eax ecx

        call    fs.fat12._.get_free_clusters_count
        push    eax
        mov     eax, dword[edx + fs.write_file_query_params_t.range.offset]
        add     eax, [edx + fs.write_file_query_params_t.range.length]
        jc      .disk_full_error_3
        call    fs.fat12._.bytes_to_clusters
        xchg    eax, ecx
        mov     eax, [edi + fs.fat.dir_entry_t.size]
        call    fs.fat12._.bytes_to_clusters
        sub     ecx, edx
        pop     eax
        jle     @f
        sub     eax, ecx ; modified file would occupy <ecx> new clusters
        jl      .disk_full_error_2

    @@: mov     eax, dword[edx + fs.write_file_query_params_t.range.offset]
        mov     ecx, [edx + fs.create_file_query_params_t.length]
        mov     esi, [edx + fs.create_file_query_params_t.buffer_ptr]

        call    fs.fat12._.write_file
        add     esp, 8
        test    eax, eax
        jnz     .exit

        call    fs.fat12._.write_fat
        or      eax, eax
        jnz     .device_error

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
kproc fs.fat12._.bytes_to_clusters ;////////////////////////////////////////////////////////////////////////////////////
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
kproc fs.fat12.truncate_file ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.truncate_file_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .access_denied_error

        ; file size must not exceed 4 Gb
        cmp     dword[edx + fs.truncate_file_query_params_t.new_size + 4], 0
        jne     .disk_full_error

        call    fs.fat12._.read_fat
        test    eax, eax
        jnz     .device_error

        call    fs.fat12._.find_file_lfn
        jc      .file_not_found_error

        ; must not be directory
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jnz     .access_denied_error

        push    eax ecx

        call    fs.fat12._.get_free_clusters_count
        push    eax
        mov     eax, dword[edx + fs.truncate_file_query_params_t.new_size]
        call    fs.fat12._.bytes_to_clusters
        xchg    eax, ecx
        mov     eax, [edi + fs.fat.dir_entry_t.size]
        call    fs.fat12._.bytes_to_clusters
        sub     ecx, eax
        pop     eax
        jle     @f
        sub     eax, ecx ; modified file would occupy <ecx> new clusters
        jl      .disk_full_error_2

    @@: ; set file modification date/time to current
        call    fs.fat.update_datetime

        mov_s_  [edi + fs.fat.dir_entry_t.size], dword[edx + fs.truncate_file_query_params_t.new_size]

        mov     eax, [edi + fs.fat.dir_entry_t.size]
        call    fs.fat12._.bytes_to_clusters

        mov     ebp, [ebx + fs.partition_t.user_data]
        add     ebp, fs.fat12.partition_data_t.fat

        test    ecx, ecx
        jl      .truncate
        jg      .expand

        lea     eax, [esp + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.end_write
        jc      .device_error_2

        add     esp, 8
        xor     eax, eax ; ERROR_SUCCESS
        ret

  .expand:
        push    ecx
        mov     ecx, eax
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]

    @@: mov     edx, eax
        cmp     edx, 0x0ff8
        jae     .fat_table_error_2
        movzx   eax, word[ebp + eax * 2]
        dec     ecx
        jg      @b

        pop     ecx

    @@: call    fs.fat12._.find_free_cluster
        jc      .disk_full_error_2
        mov     [ebp + edx * 2], ax
        loop    @b

        mov     word[edi], 0x0fff
        jmp     .exit

  .truncate:
        add     ecx, eax
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]

    @@: mov     edx, eax
        cmp     edx, 0x0ff8
        jae     .fat_table_error
        movzx   eax, word[ebp + eax * 2]
        dec     ecx
        jg      @b

        mov     word[ebp + edx * 2], 0x0fff
        call    fs.fat12._.delete_fat_chain

  .exit:
        lea     eax, [esp + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.end_write
        jc      .device_error_2

        call    fs.fat12._.write_fat
        or      eax, eax
        jnz     .device_error_2

        add     esp, 8
        xor     eax, eax ; ERROR_SUCCESS
        ret

  .access_denied_error:
        mov_s_  eax, ERROR_ACCESS_DENIED
        ret

  .disk_full_error_2:
        add     esp, 8

  .disk_full_error:
        mov_s_  eax, ERROR_DISK_FULL
        ret

  .device_error_2:
        add     esp, 8

  .device_error:
        mov_s_  eax, ERROR_DEVICE_FAIL
        ret

  .file_not_found_error:
        mov_s_  eax, ERROR_FILE_NOT_FOUND
        ret

  .fat_table_error_2:
        add     esp, 4

  .fat_table_error:
        add     esp, 8
        mov_s_  eax, ERROR_FAT_TABLE
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.get_file_info ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> edx ^= fs.get_file_info_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .not_implemented_error

        call    fs.fat12._.read_fat
        or      eax, eax
        jnz     .device_error

        call    fs.fat12._.find_file_lfn
        jc      .file_not_found_error

        xor     ebp, ebp
        mov     esi, [edx + fs.get_file_info_query_params_t.buffer_ptr]
        and     [esi + fs.file_info_t.flags], 0
        call    fs.fat.fat_entry_to_bdfe.direct

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

ret11:
        mov     eax, ERROR_DEVICE_FAIL
        ret

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.set_file_info ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> edx ^= fs.set_file_info_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .not_implemented_error

        call    fs.fat12._.read_fat
        or      eax, eax
        jnz     .device_error

        call    fs.fat12._.find_file_lfn
        jc      .file_not_found_error

        push    eax
        mov     edx, [edx + fs.set_file_info_query_params_t.buffer_ptr]
        call    fs.fat.bdfe_to_fat_entry
        pop     eax

        call    fs.fat12._.write_sector
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
kproc fs.fat12._.delete_fat_chain ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= start cluster number
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp
        mov     ebp, [ebx + fs.partition_t.user_data]
        add     ebp, fs.fat12.partition_data_t.fat

  .next_cluster:
        cmp     eax, 2
        jb      .exit
        cmp     eax, 2849
        jae     .exit

        lea     eax, [ebp + eax * 2]
        push    dword[eax]
        and     word[eax], 0
        pop     eax
        and     eax, 0x0fff
        jmp     .next_cluster

  .exit:
        pop     ebp
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.delete_file ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .access_denied_error ; cannot delete root

        call    fs.fat12._.read_fat
        or      eax, eax
        jnz     .device_error

        call    fs.fat12._.find_file_lfn
        jc      .file_not_found_error

        push    0 eax ecx

        cmp     dword[edi + fs.fat.dir_entry_t.name], '.   '
        je      .access_denied_error_2
        cmp     dword[edi + fs.fat.dir_entry_t.name], '..  '
        je      .access_denied_error_2
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .delete_entry

        ; can delete empty folders only
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        push    edi eax fs.fat12._.dir_handlers.non_root

        lea     eax, [esp + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.first_entry
        jnc     @f
        or      eax, eax
        jnz     .device_error_2
        jmp     .empty

    @@: add     edi, 2 * sizeof.fs.fat.dir_entry_t

  .check_empty:
        cmp     [edi + fs.fat.dir_entry_t.name], 0
        je      @f
        cmp     [edi + fs.fat.dir_entry_t.name], 0xe5
        jne     .access_denied_error_3

    @@: lea     eax, [esp + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.next_entry
        jnc     .check_empty
        or      eax, eax
        jnz     .device_error_2

  .empty:
        add     esp, 8
        pop     edi

  .delete_entry:
        lea     eax, [esp + 4]
        push    edi
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.begin_write
        pop     edi

        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        mov     [esp + 8], eax

        ; delete folder entry
        mov     [edi + fs.fat.dir_entry_t.name], 0xe5

  .delete_lfn_entry:
        ; delete LFN (if present)
        add     edi, -sizeof.fs.fat.dir_entry_t

        lea     eax, [esp + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.prev_write
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
        lea     eax, [esp + 4]
        stdcall fs.fat.call_dir_handler, fs.fat.dir_handlers_t.end_write

  .delete_complete_eof:
        add     esp, 8

        ; delete FAT chain
        pop     eax
        call    fs.fat12._.delete_fat_chain

        call    fs.fat12._.write_fat
        or      eax, eax
        jnz     .device_error

        ret

  .access_denied_error_3:
        add     esp, 12

  .access_denied_error_2:
        add     esp, 12

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .device_error_2:
        add     esp, 12

  .device_error_3:
        add     esp, 12

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        ret
kendp

iglobal
  align 4
  fs.fat12._.dir_handlers:
    .root_mem dd \
      fs.fat12._.root_mem_first, \
      fs.fat12._.root_mem_next, \
      util.noop, \ ; prev_entry
      util.noop, \ ; begin_write
      util.noop, \ ; next_write
      util.noop, \ ; prev_write
      util.noop, \ ; end_write
      util.raise_cf ; extend_dir
    .root dd \
      fs.fat12._.root_first, \
      fs.fat12._.root_next, \
      fs.fat12._.root_prev, \
      fs.fat12._.root_begin_write, \
      util.noop, \ ; next_write
      fs.fat12._.root_prev_write, \
      fs.fat12._.root_end_write, \
      util.raise_cf ; extend_dir
    .non_root dd \
      fs.fat12._.notroot_first, \
      fs.fat12._.notroot_next, \
      fs.fat12._.notroot_prev, \
      fs.fat12._.notroot_begin_write, \
      fs.fat12._.notroot_next_write, \
      fs.fat12._.notroot_prev_write, \
      fs.fat12._.notroot_end_write, \
      fs.fat12._.notroot_extend_dir
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.check_partition_label ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;> ebp ^= fs.fat12.partition_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx esi edi

        xor     eax, eax
        call    fs.fat12._.read_sector
        jnz     .exit

        lea     esi, [ebp + fs.fat12.partition_data_t.label]
        add     edi, 39
        mov     ecx, 15
        push    esi edi
        rep     cmpsb
        pop     edi esi
        je      .exit ; eax = 0

        and     [ebp + fs.fat12.partition_data_t.is_fat_valid], 0
        and     [ebp + fs.fat12.partition_data_t.is_root_valid], 0

        xchg    esi, edi
        mov     ecx, 15
        rep     movsb

  .exit:
        pop     edi esi ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.read_fat ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx esi edi ebp

        mov     ebp, [ebx + fs.partition_t.user_data]

        ; FIXME: disk change detection is not a FS driver job
        call    fs.fat12._.check_partition_label
        or      eax, eax
        jnz     .exit

        cmp     [ebp + fs.fat12.partition_data_t.is_fat_valid], 0
        jne     .exit ; eax = 0

        mov     eax, 512
        cdq
        mov     ecx, 9 * 2 * 512
        lea     edi, [ebp + fs.fat12.partition_data_t.buffer]
        call    fs.read
        or      eax, eax
        jnz     .exit

        lea     esi, [ebp + fs.fat12.partition_data_t.fat]
        xchg    esi, edi
        call    fs.fat12.calculate_fat_chain

        and     [ebp + fs.fat12.partition_data_t.is_root_valid], 0
        inc     [ebp + fs.fat12.partition_data_t.is_fat_valid]

  .exit:
        pop     ebp edi esi edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.write_fat ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx esi edi ebp

        mov     ebp, [ebx + fs.partition_t.user_data]

        ; FIXME: disk change detection is not a FS driver job
        call    fs.fat12._.check_partition_label
        or      eax, eax
        jnz     .exit

        cmp     [ebp + fs.fat12.partition_data_t.is_fat_valid], 0
        je      .exit ; eax = 0

        lea     esi, [ebp + fs.fat12.partition_data_t.fat]
        lea     edi, [ebp + fs.fat12.partition_data_t.buffer]
        call    fs.fat12.restore_fat_chain

        mov     eax, 512
        cdq
        mov     ecx, 9 * 2 * 512
        lea     esi, [ebp + fs.fat12.partition_data_t.buffer]
        call    fs.write
        or      eax, eax
        jnz     .exit

        and     [ebp + fs.fat12.partition_data_t.is_root_valid], 0

  .exit:
        pop     ebp edi esi edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.read_root_directory ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx edi ebp

        mov     ebp, [ebx + fs.partition_t.user_data]

        ; FIXME: disk change detection is not a FS driver job
        call    fs.fat12._.check_partition_label
        or      eax, eax
        jnz     .exit

        cmp     [ebp + fs.fat12.partition_data_t.is_root_valid], 0
        jne     .exit ; eax = 0

        mov     eax, 19 * 512
        cdq
        mov     ecx, (33 - 19) * 512
        lea     edi, [ebp + fs.fat12.partition_data_t.buffer + 1024]
        call    fs.read
        or      eax, eax
        jnz     .exit

        inc     [ebp + fs.fat12.partition_data_t.is_root_valid]

  .exit:
        pop     ebp edi edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.write_root_directory ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx esi ebp

        mov     ebp, [ebx + fs.partition_t.user_data]

        ; FIXME: disk change detection is not a FS driver job
        call    fs.fat12._.check_partition_label
        or      eax, eax
        jnz     .exit

        cmp     [ebp + fs.fat12.partition_data_t.is_root_valid], 0
        je      .exit ; eax = 0

        mov     eax, 19 * 512
        cdq
        mov     ecx, (33 - 19) * 512
        lea     esi, [ebp + fs.fat12.partition_data_t.buffer + 1024]
        call    fs.write
        or      eax, eax
        jnz     .exit

  .exit:
        pop     ebp esi edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.find_file_lfn ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path
;> ebp ^= filename
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 1 - file not found
;< CF = 0,
;<   edi ^= fs.fat.dir_entry_t
;<   eax #= directory cluster
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi

        push    0
        push    fs.fat12._.dir_handlers.root

  .next_level:
        call    fs.fat.find_long_name
        jc      .not_found
        cmp     byte[esi], 0
        je      .found

  .continue:
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .not_found

        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        mov     [esp + 4], eax
        mov     dword[esp], fs.fat12._.dir_handlers.non_root
        jmp     .next_level

  .not_found:
        add     esp, 8
        pop     edi esi
        stc
        ret

  .found:
        test    ebp, ebp
        jz      @f
        mov     esi, ebp
        xor     ebp, ebp
        jmp     .continue

    @@: pop     ecx eax
        add     esp, 4 ; CF = 0
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_prev ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer
        cmp     edi, eax
        pop     eax
        jbe     .prev_sector

        sub     edi, sizeof.fs.fat.dir_entry_t
        ret     ; CF = 0

  .prev_sector:
        push    ecx
        mov     ecx, eax
        mov     eax, [ecx]
        test    eax, eax
        jz      .eof
        dec     eax
        mov     [ecx], eax
        pop     ecx
        call    fs.fat12._.root_read_cluster
        jc      .exit

        add     edi, 512 - sizeof.fs.fat.dir_entry_t

  .exit:
        ret

  .eof:
        pop     ecx
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_next ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer + 512 - sizeof.fs.fat.dir_entry_t
        cmp     edi, eax
        pop     eax
        jae     .next_sector

        add     edi, sizeof.fs.fat.dir_entry_t
        ret     ; CF = 0

  .next_sector:
        push    ecx
        mov     ecx, eax
        mov     eax, [ecx]
        cmp     eax, 14 - 1
        je      .eof
        inc     eax
        mov     [ecx], eax
        pop     ecx
        call    fs.fat12._.root_read_cluster
        ret

  .eof:
        pop     ecx
        xor     eax, eax
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_first ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax]
        call    fs.fat12._.root_read_cluster
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.root_read_cluster ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= cluster number
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, 14
        jae     .error

        add     eax, 19
        call    fs.fat12._.read_sector
        jnz     .error

        clc
        ret

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_prev ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer
        cmp     edi, eax
        pop     eax
        jbe     .prev_sector

        sub     edi, sizeof.fs.fat.dir_entry_t
        ret     ; CF = 0

  .prev_sector:
        push    ecx edi

        push    eax
        mov     eax, [eax]
        mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.fat
        mov     ecx, 2849
        repne   scasw
        pop     eax
        jne     .eof

        sub     edi, fs.fat12.partition_data_t.fat + 2
        sub     edi, [ebx + fs.partition_t.user_data]
        shr     edi, 1
        xchg    eax, edi
        stosd
        pop     edi ecx

        call    fs.fat12._.notroot_read_cluster
        jc      .exit

        add     edi, 512 - sizeof.fs.fat.dir_entry_t
        ret     ; CF = 0

  .eof:
        pop     edi ecx
        xor     eax, eax
        stc

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_next ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [ebx + fs.partition_t.user_data]
        add     eax, fs.fat12.partition_data_t.buffer + 512 - sizeof.fs.fat.dir_entry_t
        cmp     edi, eax
        pop     eax
        jae     .next_sector

        add     edi, sizeof.fs.fat.dir_entry_t
        ret     ; CF = 0

  .next_sector:
        push    ecx
        mov     ecx, eax
        mov     eax, [ecx]
        shl     eax, 1
        add     eax, [ebx + fs.partition_t.user_data]
        movzx   eax, [fs.fat12.partition_data_t.fat + eax]
        cmp     eax, 0x0ff8
        jae     .eof
        mov     [ecx], eax
        pop     ecx

        call    fs.fat12._.notroot_read_cluster
        ret

  .eof:
        pop     ecx
        xor     eax, eax
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_first ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax]
        call    fs.fat12._.notroot_read_cluster
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.notroot_read_cluster ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= cluster number
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        add     eax, -2
        cmp     eax, 2849 - 2
        jae     .error

        add     eax, 31 + 2
        call    fs.fat12._.read_sector
        jnz     .error

        clc
        ret

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.read_sector ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= sector number
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< edi ^= buffer
;< eflags[zf] = 1 (ok) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        shl     eax, 9 ; #= physical address
        cdq
        mov     ecx, 512
        mov     edi, [ebx + fs.partition_t.user_data]
        add     edi, fs.fat12.partition_data_t.buffer
        call    fs.read

        test    eax, eax
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12._.write_sector ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= sector number
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< eflags[zf] = 1 (ok) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        shl     eax, 9 ; #= physical address
        cdq
        mov     ecx, 512
        mov     esi, [ebx + fs.partition_t.user_data]
        add     esi, fs.fat12.partition_data_t.buffer
        call    fs.write

        test    eax, eax
        pop     edx ecx
        ret
kendp
