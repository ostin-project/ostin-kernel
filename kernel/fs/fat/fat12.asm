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
  clust_tmp_flp         dd 0  ; used by analyze_directory and analyze_directory_to_write
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
        mov     edi, FDD_BUFF
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
        mov     edi, FDD_BUFF + 39
        mov     ecx, 15
        cld
        rep     cmpsb
        je      .same_label
        mov     [root_read], 0
        mov     [flp_fat], 0

  .same_label:
        mov     esi, FDD_BUFF + 39
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

;-----------------------------------------------------------------------------------------------------------------------
kproc save_flp_root ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        call    check_label
        cmp     [FDC_Status], 0
        jne     .unnecessary_root_save
        cmp     [root_read], 0
        je      .unnecessary_root_save
        mov     [FDD_Track], 0
        mov     [FDD_Head], 1
        mov     [FDD_Sector], 2
        mov     esi, FLOPPY_BUFF
        call    SeekTrack

  .save_flp_root_1:
        push    esi
        call    take_data_from_application_1
        pop     esi
        add     esi, 512
        call    WriteSectWithRetr
        cmp     [FDC_Status], 0
        jne     .unnecessary_root_save
        inc     [FDD_Sector]
        cmp     [FDD_Sector], 16
        jne     .save_flp_root_1

  .unnecessary_root_save:
        mov     [fdc_irq_func], util.noop
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc save_flp_fat ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        call    check_label
        cmp     [FDC_Status], 0
        jne     .unnecessary_flp_fat_save
        cmp     [flp_fat], 0
        je      .unnecessary_flp_fat_save
        mov     esi, FLOPPY_FAT
        mov     edi, FLOPPY_BUFF
        call    fs.fat12.restore_fat_chain
        mov     [FDD_Track], 0
        mov     [FDD_Head], 0
        mov     [FDD_Sector], 2
        mov     esi, FLOPPY_BUFF
        call    SeekTrack

  .save_flp_fat_1:
        push    esi
        call    take_data_from_application_1
        pop     esi
        add     esi, 512
        call    WriteSectWithRetr
        cmp     [FDC_Status], 0
        jne     .unnecessary_flp_fat_save
        inc     [FDD_Sector]
        cmp     [FDD_Sector], 19
        jne     .save_flp_fat_1
        mov     [FDD_Sector], 1
        mov     [FDD_Head], 1
        call    take_data_from_application_1
        call    WriteSectWithRetr
        cmp     [FDC_Status], 0
        jne     .unnecessary_flp_fat_save
        mov     [root_read], 0

  .unnecessary_flp_fat_save:
        mov     [fdc_irq_func], util.noop
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc save_chs_sector ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    calculate_chs
        call    WriteSectWithRetr
        ret
kendp

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
;-----------------------------------------------------------------------------------------------------------------------
;> eax = first cluster of the directory
;> ebx = pointer to filename
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 0, eax = sector where th file is found
;<            ebx = pointer in buffer [buffer .. buffer+511]
;<            ecx, edx, esi, edi not changed
;< if CF = 1, ...
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ; [esp+16]
        push    ecx
        push    edx
        push    esi
        push    edi

  .adr56_flp:
        mov     [clust_tmp_flp], eax
        add     eax, 31
        pusha
        call    read_chs_sector
        popa
        cmp     [FDC_Status], 0
        jne     .not_found_file_analyze_flp

        mov     ecx, 512 / 32
        mov     ebx, FDD_BUFF

  .adr1_analyze_flp:
        mov     esi, edx ; [esp+16]
        mov     edi, ebx
        cld
        push    ecx
        mov     ecx, 11
        rep     cmpsb
        pop     ecx
        je      .found_file_analyze_flp

        add     ebx, 32
        loop    .adr1_analyze_flp

        mov     eax, [clust_tmp_flp]
        shl     eax, 1 ; find next cluster from FAT
        add     eax, FLOPPY_FAT
        mov     eax, [eax]
        and     eax, 4095
        cmp     eax, 0x0ff8
        jb      .adr56_flp

  .not_found_file_analyze_flp:
        pop     edi
        pop     esi
        pop     edx
        pop     ecx
        add     esp, 4
        stc     ; file not found
        ret


  .found_file_analyze_flp:
        pop     edi
        pop     esi
        pop     edx
        pop     ecx
        add     esp, 4
        clc     ; file found
        ret
kendp

uglobal
  ; this is for delete support
  fd_prev_sector      dd ?
  fd_prev_prev_sector dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_root_next ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edi, OS_BASE + 0xd200 - 0x20
        jae     @f
        add     edi, 0x20
        ret     ; CF=0

    @@: ; read next sector
        inc     dword[eax]
        cmp     dword[eax], 14
        jae     flp_root_first.readerr
        push    [fd_prev_sector]
        pop     [fd_prev_prev_sector]
        push    eax
        mov     eax, [eax]
        add     eax, 19 - 1
        mov     [fd_prev_sector], eax
        pop     eax
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_root_first ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax]
        pusha
        add     eax, 19
        call    read_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .readerr
        mov     edi, FDD_BUFF
        ret     ; CF=0

  .readerr:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_rootmem_first ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, FLOPPY_BUFF
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_rootmem_next ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        add     edi, 0x20
        cmp     edi, FLOPPY_BUFF + 14 * 0x200
        cmc
kendp

;-----------------------------------------------------------------------------------------------------------------------
flp_rootmem_next_write: ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
flp_rootmem_begin_write: ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_rootmem_end_write ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_rootmem_extend_dir ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_notroot_next ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edi, OS_BASE + 0xd200 - 0x20
        jae     flp_notroot_next_sector
        add     edi, 0x20
        ret     ; CF=0
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_notroot_next_sector ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     ecx, [eax]
        push    [fd_prev_sector]
        pop     [fd_prev_prev_sector]
        add     ecx, 31
        mov     [fd_prev_sector], ecx
        mov     ecx, [(ecx - 31) * 2 + FLOPPY_FAT]
        and     ecx, 0x0fff
        cmp     ecx, 2849
        jae     flp_notroot_first.err2
        mov     [eax], ecx
        pop     ecx
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_notroot_first ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax]
        cmp     eax, 2
        jb      .err
        cmp     eax, 2849
        jae     .err
        pusha
        add     eax, 31
        call    read_chs_sector
        popa
        mov     edi, FDD_BUFF
        cmp     [FDC_Status], 0
        jnz     .err
        ret     ; CF=0

  .err2:
        pop     ecx

  .err:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_notroot_begin_write ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax]
        add     eax, 31
        call    read_chs_sector
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_notroot_end_write ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, [eax]
        add     eax, 31
        call    save_chs_sector
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_notroot_next_write ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edi, OS_BASE + 0xd200
        jae     @f
        ret

    @@: call    flp_notroot_end_write
        jmp     flp_notroot_next_sector
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc flp_notroot_extend_dir ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; find free cluster in FAT
        pusha
        xor     eax, eax
        mov     edi, FLOPPY_FAT
        mov     ecx, 2849
        repnz   scasw
        jnz     .notfound
        mov     word[edi - 2], 0x0fff ; mark as last cluster
        sub     edi, FLOPPY_FAT
        shr     edi, 1
        dec     edi
        mov     eax, [esp + regs_context32_t.eax]
        mov     ecx, [eax]
        mov     [FLOPPY_FAT + ecx * 2], di
        mov     [eax], edi
        xor     eax, eax
        mov     edi, FDD_BUFF
        mov     ecx, 128
        rep     stosd
        popa
        call    flp_notroot_end_write
        mov     edi, FDD_BUFF
        clc
        ret

  .notfound:
        popa
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fd_find_lfn ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi + ebp pointer to name
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 1 - file not found
;< CF = 0,
;<   edi = pointer to direntry
;<   eax = directory cluster (0 for root)
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi
        push    0
        push    flp_root_first
        push    flp_root_next

  .loop:
        call    fs.fat.find_long_name
        jc      .notfound
        cmp     byte[esi], 0
        jz      .found

  .continue:
        test    byte[edi + 11], 0x10
        jz      .notfound
        movzx   eax, word[edi + 26] ; cluster
        mov     [esp + 8], eax
        mov     dword[esp + 4], flp_notroot_first
        mov     dword[esp], flp_notroot_next
        jmp     .loop

  .notfound:
        add     esp, 12
        pop     edi esi
        stc
        ret

  .found:
        test    ebp, ebp
        jz      @f
        mov     esi, ebp
        xor     ebp, ebp
        jmp     .continue

    @@: mov     eax, [esp + 8]
        add     eax, 31
        cmp     dword[esp], flp_root_next
        jnz     @f
        add     eax, -31 + 19

    @@: add     esp, 16 ; CF=0
        pop     esi
        ret
kendp

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
kproc fs_FloppyRead ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for reading floppy
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
        cmp     byte[esi], 0
        je      fs.error.access_denied

        call    read_flp_fat

        push    edi
        call    fd_find_lfn
        jnc     .found
        pop     edi
        jmp     fs.error.file_not_found

  .found:
        test    ebx, ebx
        jz      .l1
        cmp     dword[ebx + 4], 0
        jz      @f
        xor     ebx, ebx

  .reteof:
        mov     eax, ERROR_END_OF_FILE ; EOF
        pop     edi
        ret

    @@: mov     ebx, [ebx]

  .l1:
        push    ecx edx
        push    0
        mov     eax, [edi + 28]
        sub     eax, ebx
        jb      .eof
        cmp     eax, ecx
        jae     @f
        mov     ecx, eax
        mov     byte[esp], ERROR_END_OF_FILE ; EOF

    @@: movzx   edi, word[edi + 26]

  .new:
        jecxz   .done
        test    edi, edi
        jz      .eof
        cmp     edi, 0x0ff8
        jae     .eof

        sub     ebx, 512
        jae     .skip

        lea     eax, [edi + 31]
        pusha
        call    read_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .err

        lea     eax, [FDD_BUFF + ebx + 512]
        neg     ebx
        push    ecx
        cmp     ecx, ebx
        jbe     @f
        mov     ecx, ebx

    @@: mov     ebx, edx
        call    memmove
        add     edx, ecx
        sub     [esp], ecx
        pop     ecx
        xor     ebx, ebx

  .skip:
        movzx   edi, word[edi * 2 + FLOPPY_FAT]
        jmp     .new

  .done:
        mov     ebx, edx
        pop     eax edx ecx edi
        sub     ebx, edx
        ret

  .eof:
        mov     ebx, edx
        pop     eax edx ecx
        jmp     .reteof

  .err:
        mov     ebx, edx
        pop     eax edx ecx edi
        sub     ebx, edx
        mov     al, ERROR_DEVICE_FAIL
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.read_directory ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to directory
;> edx ^= fs.read_directory_query_params_t
;> ebx ^= fs.partition_t
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
kproc fs_FloppyReadFolder ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for reading floppy folders
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to structure: 32-bit number = first wanted block, 0+ & flags (bitfields)
;> ecx = number of blocks to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = blocks read or -1 (folder not found)
;-----------------------------------------------------------------------------------------------------------------------
;# flags:
;#   bit 0 = 0 (ANSI names) or 1 (UNICODE names)
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        cmp     byte[esi], 0
        je      .root

        call    read_flp_fat

        call    fd_find_lfn
        jnc     .found
        pop     edi
        jmp     fs.error.file_not_found

  .found:
        test    byte[edi + 11], 0x10 ; do not allow read files
        jnz     .found_dir
        pop     edi
        jmp     fs.error.access_denied

  .found_dir:
        movzx   eax, word[edi + 26]
        add     eax, 31
        push    0
        jmp     .doit

  .root:
        mov     eax, 19
        push    14

  .doit:
        push    ecx ebp
        sub     esp, 262 * 2 ; reserve space for LFN
        mov     ebp, esp
        push    dword[ebx + 4] ; for fs.fat.get_name: read ANSI/UNICODE names
        mov     ebx, [ebx]
        ; init header
        push    eax ecx
        mov     edi, edx
        mov     ecx, 32 / 4
        xor     eax, eax
        rep     stosd
        pop     ecx eax
        mov     byte[edx], 1 ; version
        mov     esi, edi ; esi points to BDFE

  .main_loop:
        pusha
        call    read_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .error
        mov     edi, FDD_BUFF
        push    eax

  .l1:
        call    fs.fat.get_name
        jc      .l2
        cmp     byte[edi + 11], 0x0f
        jnz     .do_bdfe
        add     edi, 0x20
        cmp     edi, OS_BASE + 0xd200
        jb      .do_bdfe
        pop     eax
        inc     eax
        dec     byte[esp + 262 * 2 + 12]
        jz      .done
        jns     @f
        ; read next sector from FAT
        mov     eax, [(eax - 31 - 1) * 2 + FLOPPY_FAT]
        and     eax, 0x0fff
        cmp     eax, 0x0ff8
        jae     .done
        add     eax, 31
        mov     byte[esp + 262 * 2 + 12], 0

    @@: pusha
        call    read_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .error
        mov     edi, FDD_BUFF
        push    eax

  .do_bdfe:
        inc     dword[edx + 8] ; new file found
        dec     ebx
        jns     .l2
        dec     ecx
        js      .l2
        inc     dword[edx + 4] ; new file block copied
        call    fs.fat.fat_entry_to_bdfe

  .l2:
        add     edi, 0x20
        cmp     edi, OS_BASE + 0xd200
        jb      .l1
        pop     eax
        inc     eax
        dec     byte[esp + 262 * 2 + 12]
        jz      .done
        jns     @f
        ; read next sector from FAT
        mov     eax, [(eax - 31 - 1) * 2 + FLOPPY_FAT]
        and     eax, 0x0fff
        cmp     eax, 0x0ff8
        jae     .done
        add     eax, 31
        mov     byte[esp + 262 * 2 + 12], 0

    @@: jmp     .main_loop

  .error:
        add     esp, 262 * 2 + 4
        pop     ebp ecx edi edi
        or      ebx, -1
        mov     eax, ERROR_DEVICE_FAIL
        ret

  .done:
        add     esp, 262 * 2 + 4
        pop     ebp
        mov     ebx, [edx + 4]
        xor     eax, eax
        dec     ecx
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: pop     ecx edi edi
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
kproc fs_FloppyCreateFolder ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 1
        jmp     fs_FloppyRewrite.common
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_FloppyRewrite ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for writing sys floppy
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = ignored (reserved)
;> ecx = number of bytes to write, 0+
;> edx = mem location to data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = number of written bytes
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax

  .common:
        cmp     byte[esi], 0
        je      fs.error.access_denied

        call    read_flp_fat
        cmp     [FDC_Status], 0
        jnz     .fsfrfe

        pushad
        xor     edi, edi
        push    esi
;///        test    ebp, ebp
;///        jz      @f
;///        mov     esi, ebp

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
;///        test    ebp, ebp
;///        jnz     .hasebp

        call    read_flp_root
        cmp     [FDC_Status], 0
        jnz     .fsfrfe2

        push    flp_rootmem_extend_dir
        push    flp_rootmem_end_write
        push    flp_rootmem_next_write
        push    flp_rootmem_begin_write
        xor     ebp, ebp
        push    ebp
        push    flp_rootmem_first
        push    flp_rootmem_next
        jmp     .common1

;///  .hasebp:
;///        mov     eax, ERROR_ACCESS_DENIED
;///        cmp     byte[ebp], 0
;///        jz      .ret1
;///        push    ebp
;///        xor     ebp, ebp
;///        call    fd_find_lfn
;///        pop     esi
;///        jc      .notfound0
;///        jmp     .common0

  .noroot:
        mov     eax, ERROR_ACCESS_DENIED
        cmp     byte[edi + 1], 0
        jz      .ret1
        ; check existence
        mov     byte[edi], 0
        push    edi
        call    fd_find_lfn
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
        movzx   ebp, [edi + fs.fat.dir_entry_t.start_cluster.low] ; ebp=cluster
        mov     eax, ERROR_FAT_TABLE
        cmp     ebp, 2
        jb      .ret1
        cmp     ebp, 2849
        jae     .ret1

        push    flp_notroot_extend_dir
        push    flp_notroot_end_write
        push    flp_notroot_next_write
        push    flp_notroot_begin_write
        push    ebp
        push    flp_notroot_first
        push    flp_notroot_next

  .common1:
        call    fs.fat.find_long_name
        jc      .notfound
        ; found
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .exists_file
        ; found directory; if we are creating directory, return OK,
        ;                  if we are creating file, say "access denied"
        add     esp, 28
        popad
        test    al, al
        mov     eax, ERROR_ACCESS_DENIED
        jz      @f
        mov     al, ERROR_SUCCESS

    @@: xor     ebx, ebx
        ret

  .exists_file:
        ; found file; if we are creating directory, return "access denied",
        ;             if we are creating file, delete existing file and continue
        cmp     [esp + 28 + regs_context32_t.al], 0
        jz      @f
        add     esp, 28
        popad
        mov     eax, ERROR_ACCESS_DENIED
        xor     ebx, ebx
        ret

    @@: ; delete FAT chain
        push    edi
        xor     eax, eax
        mov     [edi + fs.fat.dir_entry_t.size], eax ; zero size
        xchg    ax, [edi + fs.fat.dir_entry_t.start_cluster.low] ; start cluster
        test    eax, eax
        jz      .done1

    @@: cmp     eax, 0x0ff8
        jae     .done1
        lea     edi, [FLOPPY_FAT + eax * 2] ; position in FAT
        xor     eax, eax
        xchg    ax, [edi]
        jmp     @b

  .done1:
        pop     edi
        call    fs.fat.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax
        call    fs.fat.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax
        or      byte[edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_ARCHIVE ; set 'archive' attribute
        jmp     .doit

  .notfound:
        ; file is not found; generate short name
        call    fs.fat.name_is_legal
        jc      @f
        add     esp, 28
        popad
        mov     eax, ERROR_FILE_NOT_FOUND
        xor     ebx, ebx
        ret

    @@: sub     esp, 12
        mov     edi, esp
        call    fs.fat.gen_short_name

  .test_short_name_loop:
        push    esi edi ecx
        mov     esi, edi
        lea     eax, [esp + 12 + 12 + 8]
        mov     [eax], ebp
        call    dword[eax - 4]
        jc      .found

  .test_short_name_entry:
        cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        jz      .test_short_name_cont
        mov     ecx, 11
        push    esi edi
        repz    cmpsb
        pop     edi esi
        jz      .short_name_found

  .test_short_name_cont:
        lea     eax, [esp + 12 + 12 + 8]
        call    dword[eax - 8]
        jnc     .test_short_name_entry
        jmp     .found

  .short_name_found:
        pop     ecx edi esi
        call    fs.fat.next_short_name
        jnc     .test_short_name_loop

  .disk_full:
        add     esp, 12 + 28
        popa
        mov     eax, ERROR_DISK_FULL
        xor     ebx, ebx
        ret

  .found:
        pop     ecx edi esi
        ; now find space in directory
        ; we need to save LFN <=> LFN is not equal to short name <=> generated name contains '~'
        mov     al, '~'
        push    ecx edi
        mov     ecx, 8
        repnz   scasb
        push    1
        pop     eax ; 1 entry
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
        ; find <eax> successive entries in directory
        xor     ecx, ecx
        push    eax
        lea     eax, [esp + 12 + 8 + 12 + 8]
        mov     [eax], ebp
        call    dword[eax - 4]
        pop     eax
        jnc     .scan_dir

  .fsfrfe3:
        add     esp, 8 + 8 + 12 + 28
        popad
        mov     eax, ERROR_DEVICE_FAIL
        xor     ebx, ebx
        ret

  .fsfrfe2:
        popad

  .fsfrfe:
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
        lea     eax, [esp + 12 + 8 + 12 + 8]
        call    dword[eax - 8]
        pop     eax
        jnc     .scan_dir

        cmp     [FDC_Status], 0
        jnz     .fsfrfe3

        push    eax
        lea     eax, [esp + 12 + 8 + 12 + 8]
        call    dword[eax + 16] ; extend directory
        pop     eax
        jnc     .scan_dir
        add     esp, 8 + 8 + 12 + 28
        popad
        mov     eax, ERROR_DISK_FULL
        xor     ebx, ebx
        ret

  .free:
        test    ecx, ecx
        jnz     @f
        mov     [esp], edi
        mov     ecx, [esp + 8 + 8 + 12 + 8]
        mov     [esp + 4], ecx
        xor     ecx, ecx

    @@: inc     ecx
        cmp     ecx, eax
        jb      .scan_cont
        ; found!
        ; calculate name checksum
        mov     eax, [esp + 8]
        call    fs.fat.calculate_name_checksum
        pop     edi
        pop     dword[esp + 8 + 12 + 8]
        ; edi points to first entry in free chunk
        dec     ecx
        jz      .nolfn
        push    esi
        push    eax

        lea     eax, [esp + 8 + 8 + 12 + 8]
        call    dword[eax + 4] ; begin write

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
        call    fs.fat.read_symbols
        mov     ax, 0x0f
        stosw
        mov     al, [esp + 4]
        stosb
        mov     cl, 6
        call    fs.fat.read_symbols
        xor     eax, eax
        stosw
        mov     cl, 2
        call    fs.fat.read_symbols
        pop     ecx
        lea     eax, [esp + 8 + 8 + 12 + 8]
        call    dword[eax + 8] ; next write
        xor     eax, eax
        loop    .writelfn
        pop     eax
        pop     esi
;       lea     eax, [esp + 8 + 12 + 8]
;       call    dword[eax + 12] ; end write

  .nolfn:
        xchg    esi, [esp]
        mov     ecx, 11
        rep     movsb
        sub     edi, 11
        mov     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_ARCHIVE ; attributes
        pop     esi ecx
        add     esp, 12
        mov     [edi + fs.fat.dir_entry_t.created_at.time_ms], 0 ; tenths of a second at file creation time
        call    fs.fat.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.created_at.time], ax ; creation time
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax ; last write time
        call    fs.fat.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.created_at.date], ax ; creation date
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax ; last write date
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax ; last access date
        and     [edi + fs.fat.dir_entry_t.start_cluster.high], 0 ; high word of cluster
        and     [edi + fs.fat.dir_entry_t.start_cluster.low], 0 ; low word of cluster - to be filled
        and     [edi + fs.fat.dir_entry_t.size], 0 ; file size - to be filled
        cmp     [esp + 28 + regs_context32_t.al], 0
        jz      .doit

        ; create directory
        mov     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY ; attributes: folder
        mov     ecx, 2 * sizeof.fs.fat.dir_entry_t
        mov     edx, edi

  .doit:
        lea     eax, [esp + 8]
        call    dword[eax + 12] ; flush directory
        push    ecx
        push    edi
        push    0
        mov     esi, edx
        test    ecx, ecx
        jz      .done

        mov     ecx, 2849
        mov     edi, FLOPPY_FAT
        push    0  ; first cluster

  .write_loop:
        ; allocate new cluster
        xor     eax, eax
        repnz   scasw
        mov     al, ERROR_DISK_FULL
        jnz     .ret
        dec     edi
        dec     edi

        mov     eax, edi
        sub     eax, FLOPPY_FAT

        shr     eax, 1 ; eax = cluster
        mov     word[edi], 0x0fff ; mark as last cluster
        xchg    edi, [esp + 4]
        cmp     dword[esp], 0
        jz      .first
        stosw
        jmp     @f

  .first:
        mov     [esp], eax

    @@: mov     edi, [esp + 4]
        inc     ecx
        ; write data
        push    ecx edi
        mov     ecx, 512
        cmp     dword[esp + 20], ecx
        jae     @f
        mov     ecx, [esp + 20]

    @@: mov     edi, FDD_BUFF
        cmp     [esp + 24 + 28 + regs_context32_t.al], 0
        jnz     .writedir
        push    ecx
        rep     movsb
        pop     ecx

  .writedircont:
        push    ecx
        sub     ecx, 512
        neg     ecx
        push    eax
        xor     eax, eax
        rep     stosb
        pop     eax
        add     eax, 31
        pusha
        call    save_chs_sector
        popa
        pop     ecx
        cmp     [FDC_Status], 0
        jnz     .diskerr
        sub     [esp + 20], ecx
        pop     edi ecx
        jnz     .write_loop

  .done:
        xor     eax, eax

  .ret:
        pop     ebx edi edi ecx
        mov     [esp + 28 + regs_context32_t.eax], eax
        lea     eax, [esp + 8]
        call    dword[eax + 4]
        mov     [edi + fs.fat.dir_entry_t.start_cluster.low], bx
        mov     ebx, esi
        sub     ebx, edx
        mov     [edi + fs.fat.dir_entry_t.size], ebx
        call    dword[eax + 12]
        mov     [esp + 28 + regs_context32_t.ebx], ebx
        test    ebp, ebp
        jnz     @f
        call    save_flp_root

    @@: add     esp, 28
        cmp     [FDC_Status], 0
        jnz     .err3
        call    save_flp_fat
        cmp     [FDC_Status], 0
        jnz     .err3
        popa
        ret

  .err3:
        popa
        mov     al, ERROR_DEVICE_FAIL
        xor     ebx, ebx
        ret

  .diskerr:
        sub     esi, ecx
        mov     eax, ERROR_DEVICE_FAIL
        pop     edi ecx
        jmp     .ret

  .writedir:
        push    ecx

        mov     ecx, sizeof.fs.fat.dir_entry_t / 4
        push    ecx esi
        rep     movsd
        pop     esi ecx

        mov     dword[edi - 32 + fs.fat.dir_entry_t.name], '.   '
        mov     dword[edi - 32 + fs.fat.dir_entry_t.name + 4], '    '
        mov     dword[edi - 32 + fs.fat.dir_entry_t.name + 8], '    '
        mov     [edi - 32 + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        mov     [edi - 32 + fs.fat.dir_entry_t.start_cluster.low], ax

        push    esi
        rep     movsd
        pop     esi

        mov     dword[edi - 32 + fs.fat.dir_entry_t.name], '..  '
        mov     dword[edi - 32 + fs.fat.dir_entry_t.name + 4], '    '
        mov     dword[edi - 32 + fs.fat.dir_entry_t.name + 8], '    '
        mov     [edi - 32 + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        mov     ecx, [esp + 28 + 8]
        mov     [edi - 32 + fs.fat.dir_entry_t.start_cluster.low], cx

        pop     ecx
        jmp     .writedircont
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat12.write_file ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.write_file_query_params_t
;> ebx ^= fs.partition_t
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
kproc fs_FloppyWrite ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for writing to floppy
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
        cmp     byte[esi], 0
        je      fs.error.access_denied

        call    read_flp_fat
        cmp     [FDC_Status], 0
        jnz     .ret11

        pushad
        call    fd_find_lfn
        jnc     .found
        popad
        push    ERROR_FILE_NOT_FOUND

  .ret0:
        pop     eax
        xor     ebx, ebx
        ret

  .ret11:
        push    ERROR_DEVICE_FAIL
        jmp     .ret0

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

        push    eax ; save directory cluster
        push    ERROR_SUCCESS ; return value=0

        call    fs.fat.get_time_for_file
        mov     [edi + 22], ax ; last write time
        call    fs.fat.get_date_for_file
        mov     [edi + 24], ax ; last write date
        mov     [edi + 18], ax ; last access date

        push    dword[edi + 28] ; save current file size

        cmp     ecx, [edi + 28]
        jbe     .length_ok
        cmp     ecx, ebx
        jz      .length_ok
        call    floppy_extend_file
        jnc     .length_ok

        ; floppy_extend_file can return two error codes: FAT table error or disk full.
        ; First case is fatal error, in second case we may write some data
        mov     [esp + 4], eax
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
        mov     ecx, [edi + 28]
        cmp     ecx, ebx
        ja      .length_ok

  .ret:
        pop     eax
        pop     eax
        mov     [esp + 4 + regs_context32_t.eax], eax ; eax=return value
        pop     eax
        sub     edx, [esp + regs_context32_t.edx]
        mov     [esp + regs_context32_t.ebx], edx ; ebx=number of written bytes
        popad
        ret

  .length_ok:
        ; save FAT & directory
        ; note that directory must be saved first because save_flp_fat uses buffer at 0xD000
        mov     esi, [edi + 28]
        movzx   edi, word[edi + 26] ; starting cluster
        mov     eax, [esp + 8]
        pusha
        call    save_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .device_err
        call    save_flp_fat
        cmp     [FDC_Status], 0
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
        lea     eax, [edi + 31] ; current sector
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

    @@: ; load sector if needed
        cmp     dword[esp + 4], 0 ; we don't need to read uninitialized data
        jz      .noread
        cmp     ecx, 0x200 ; we don't need to read sector if it is fully rewritten
        jz      .noread
        cmp     ecx, esi ; (same for the last sector)
        jz      .noread
        pusha
        call    read_chs_sector
        popa
        cmp     [FDC_Status], 0
        jz      @f

  .device_err2:
        pop     ecx
        jmp     .device_err

    @@:

  .noread:
        ; zero uninitialized data if file was extended (because floppy_extend_file does not this)
        push    eax ecx edi
        xor     eax, eax
        mov     ecx, 0x200
        sub     ecx, [esp + 4 + 12]
        jbe     @f
        mov     edi, FDD_BUFF
        add     edi, [esp + 4 + 12]
        rep     stosb

    @@: ; zero uninitialized data in the last sector
        mov     ecx, 0x200
        sub     ecx, esi
        jbe     @f
        mov     edi, FDD_BUFF
        add     edi, esi
        rep     stosb

    @@: pop     edi ecx eax
        ; copy new data
        push    eax
        mov     eax, edx
        neg     ebx
        jecxz   @f
        add     ebx, FDD_BUFF + 0x200
        call    memmove
        xor     ebx, ebx

    @@: pop     eax
        ; save sector
        pusha
        call    save_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .device_err2
        add     edx, ecx
        sub     [esp], ecx
        pop     ecx
        jz      .done

  .skip:
  .next_cluster:
        movzx   edi, word[edi * 2 + FLOPPY_FAT]
        sub     esi, 0x200
        jae     @f
        xor     esi, esi

    @@: sub     dword[esp], 0x200
        jae     .write_loop
        and     dword[esp], 0
        jmp     .write_loop

  .done:
        jmp     .ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc floppy_extend_file ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? extends file on floppy to given size (new data area is undefined)
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to direntry
;> ecx = new size
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 0 (ok), eax = 0
;< if CF = 1 (error), eax = error code (ERROR_FAT_TABLE or ERROR_DISK_FULL)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        ; find the last cluster of file
        movzx   eax, word[edi + 26] ; first cluster
        mov     ecx, [edi + 28]
        jecxz   .zero_size

    @@: sub     ecx, 0x200
        jbe     @f
        mov     eax, [eax * 2 + FLOPPY_FAT]
        and     eax, 0x0fff
        jz      .fat_err
        cmp     eax, 0x0ff8
        jb      @b

  .fat_err:
        pop     ecx
        push    ERROR_FAT_TABLE
        pop     eax
        stc
        ret

  .zero_size:
        xor     eax, eax
        jmp     .start_extend

    @@: push    eax
        mov     eax, [eax * 2 + FLOPPY_FAT]
        and     eax, 0x0fff
        cmp     eax, 0x0ff8
        pop     eax
        jb      .fat_err
        ; set length to full number of sectors
        sub     [edi + 28], ecx

  .start_extend:
        pop     ecx
        ; now do extend
        push    edx esi
        mov     esi, FLOPPY_FAT + 2 * 2 ; start scan from cluster 2
        mov     edx, 2847 ; number of clusters to scan

  .extend_loop:
        cmp     [edi + 28], ecx
        jae     .extend_done
        ; add new sector
        push    ecx
        push    edi

  .scan:
        mov     ecx, edx
        mov     edi, esi
        jecxz   .disk_full
        push    eax
        xor     eax, eax
        repnz   scasw
        pop     eax
        jnz     .disk_full
        mov     word[edi - 2], 0x0fff
        mov     esi, edi
        mov     edx, ecx
        sub     edi, FLOPPY_FAT
        shr     edi, 1
        dec     edi ; now edi=new cluster
        test    eax, eax
        jz      .first_cluster
        mov     [FLOPPY_FAT + eax * 2], di
        jmp     @f

  .first_cluster:
        pop     eax ; eax->direntry
        push    eax
        mov     [eax + 26], di

    @@: mov     eax, edi ; eax=new cluster
        pop     edi ; edi->direntry
        pop     ecx ; ecx=required size
        add     dword[edi + 28], 0x200
        jmp     .extend_loop

  .extend_done:
        mov     [edi + 28], ecx
        pop     esi edx
        xor     eax, eax ; CF=0
        ret

  .disk_full:
        pop     edi ecx
        pop     esi edx
        stc
        push    ERROR_DISK_FULL
        pop     eax
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
kproc fs_FloppySetFileEnd ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? set end of file on floppy
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = points to 64-bit number = new file size
;> ecx = ignored (reserved)
;> edx = ignored (reserved)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

        call    read_flp_fat
        cmp     [FDC_Status], 0
        jnz     ret11

        push    edi
        call    fd_find_lfn
        jnc     @f
        pop     edi
        push    ERROR_FILE_NOT_FOUND

  .ret:
        pop     eax
        jmp     .doret

    @@: ; must not be directory
        test    byte[edi + 11], 0x10
        jz      @f
        pop     edi
        jmp     fs.error.access_denied

    @@: ; file size must not exceed 4 Gb
        cmp     dword[ebx + 4], 0
        jz      @f
        pop     edi
        push    ERROR_END_OF_FILE
        jmp     .ret

    @@: push    eax
        ; set file modification date/time to current
        call    fs.fat.update_datetime
        mov     eax, [ebx]
        cmp     eax, [edi + 28]
        jb      .truncate
        ja      .expand
        pop     eax
        pushad
        call    save_chs_sector
        popad
        pop     edi
        xor     eax, eax
        cmp     [FDC_Status], 0
        jz      @f
        mov     al, ERROR_DEVICE_FAIL

    @@:

  .doret:
        mov     [fdc_irq_func], util.noop
        ret

  .expand:
        push    ecx
        push    dword[edi + 28] ; save old size
        mov     ecx, eax
        call    floppy_extend_file
        push    eax ; return code
        jnc     .expand_ok
        cmp     al, ERROR_DISK_FULL
        jz      .disk_full
        pop     eax ecx ecx edi edi
        jmp     .doret

  .device_err:
        pop     eax

  .device_err2:
        pop     ecx ecx eax edi
        push    ERROR_DEVICE_FAIL
        jmp     .ret

  .disk_full:
  .expand_ok:
        ; save directory & FAT
        mov     eax, [edi + 28]
        xchg    eax, [esp + 12]
        movzx   edi, word[edi + 26]
        pusha
        call    save_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .device_err
        call    save_flp_fat
        cmp     [FDC_Status], 0
        jnz     .device_err
        ; now zero new data
        ; edi = current cluster, [esp+12]=new size, [esp+4]=old size, [esp]=return code

  .zero_loop:
        sub     dword[esp + 4], 0x200
        jae     .next_cluster
        cmp     dword[esp + 4], -0x200
        jz      .noread
        lea     eax, [edi + 31]
        pusha
        call    read_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .err_next

  .noread:
        mov     ecx, [esp + 4]
        neg     ecx
        push    edi
        mov     edi, FDD_BUFF + 0x200
        add     edi, [esp + 8]
        xor     eax, eax
        mov     [esp + 8], eax
        rep     stosb
        pop     edi
        lea     eax, [edi + 31]
        pusha
        call    save_chs_sector
        popa
        cmp     [FDC_Status], 0
        jz      .next_cluster

  .err_next:
        mov     byte[esp], ERROR_DEVICE_FAIL

  .next_cluster:
        sub     dword[esp + 12], 0x200
        jbe     .expand_done
        movzx   edi, word[FLOPPY_FAT + edi * 2]
        jmp     .zero_loop

  .expand_done:
        pop     eax ecx ecx edi edi
        jmp     .doret

  .truncate:
        mov     [edi + 28], eax
        push    ecx
        movzx   ecx, word[edi + 26]
        test    eax, eax
        jz      .zero_size

    @@: ; find new last sector
        sub     eax, 0x200
        jbe     @f
        movzx   ecx, word[FLOPPY_FAT + ecx * 2]
        jmp     @b

    @@: ; we will zero data at the end of last sector - remember it
        push    ecx

        ; terminate FAT chain
        lea     ecx, [FLOPPY_FAT + ecx * 2]
        push    dword[ecx]
        mov     word[ecx], 0x0fff
        pop     ecx
        and     ecx, 0x0fff
        jmp     .delete

  .zero_size:
        and     word[edi + 26], 0
        push    0

  .delete:
        ; delete FAT chain starting with ecx
        ; mark all clusters as free
        cmp     ecx, 0x0ff8
        jae     .deleted
        lea     ecx, [FLOPPY_FAT + ecx + ecx]
        push    dword[ecx]
        and     word[ecx], 0
        pop     ecx
        and     ecx, 0x0fff
        jmp     .delete

  .deleted:
        mov     edi, [edi + 28]
        ; save directory & FAT
        mov     eax, [esp + 8]
        pusha
        call    save_chs_sector
        popa
        cmp     [FDC_Status], 0
        jnz     .device_err2
        call    save_flp_fat
        cmp     [FDC_Status], 0
        jnz     .device_err2
        ; zero last sector, ignore errors
        pop     eax
        add     eax, 31
        and     edi, 0x1ff
        jz      .truncate_done
        pusha
        call    read_chs_sector
        popa
        add     edi, FDD_BUFF
        mov     ecx, FDD_BUFF + 0x200
        sub     ecx, edi
        push    eax
        xor     eax, eax
        rep     stosb
        pop     eax
        pusha
        call    save_chs_sector
        popa

  .truncate_done:
        pop     ecx eax edi
        xor     eax, eax
        jmp     .doret
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

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_FloppyGetFileInfo ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jne     @f
        mov     eax, ERROR_NOT_IMPLEMENTED ; unsupported
        ret

    @@: call    read_flp_fat
        cmp     [FDC_Status], 0
        jnz     ret11

        push    edi
        call    fd_find_lfn
        jmp     fs_RamdiskGetFileInfo.finish
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
kproc fs_FloppySetFileInfo ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jne     @f
        mov     eax, ERROR_NOT_IMPLEMENTED ; unsupported
        ret

    @@: call    read_flp_fat
        cmp     [FDC_Status], 0
        jnz     ret11

        push    edi
        call    fd_find_lfn
        jnc     @f
        pop     edi
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

    @@: push    eax
        call    fs.fat.bdfe_to_fat_entry
        pop     eax

        pusha
        call    save_chs_sector
        popa
        pop     edi
        xor     eax, eax
        cmp     [FDC_Status], al
        jz      @f
        mov     al, ERROR_DEVICE_FAIL

    @@: ret
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

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_FloppyDelete ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? delete file or empty folder from floppy
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied ; cannot delete root!

        call    read_flp_fat
        cmp     [FDC_Status], 0
        je      @f
        push    ERROR_DEVICE_FAIL
        jmp     .pop_ret

    @@: and     [fd_prev_sector], 0
        and     [fd_prev_prev_sector], 0
        push    edi
        call    fd_find_lfn
        jnc     .found
        pop     edi
        push    ERROR_FILE_NOT_FOUND

  .pop_ret:
        pop     eax
        ret

  .found:
        cmp     dword[edi + fs.fat.dir_entry_t.name], '.   '
        je      .access_denied2
        cmp     dword[edi + fs.fat.dir_entry_t.name], '..  '
        je      .access_denied2
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        jz      .dodel
        ; we can delete only empty folders!
        push    eax
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        push    ebx
        pusha
        add     eax, 31
        call    read_chs_sector
        popa
        mov     ebx, FDD_BUFF + 2 * sizeof.fs.fat.dir_entry_t

  .checkempty:
        cmp     [ebx + fs.fat.dir_entry_t.name], 0
        je      .empty
        cmp     [ebx + fs.fat.dir_entry_t.name], 0xe5
        jne     .notempty
        add     ebx, sizeof.fs.fat.dir_entry_t
        cmp     ebx, FDD_BUFF + 0x200
        jb      .checkempty
        movzx   eax, word[FLOPPY_FAT + eax * 2]
        pusha
        add     eax, 31
        call    read_chs_sector
        popa
        mov     ebx, FDD_BUFF
        jmp     .checkempty

  .notempty:
        pop     ebx
        pop     eax

  .access_denied2:
        pop     edi
        jmp     fs.error.access_denied

  .empty:
        pop     ebx
        pop     eax
        pusha
        call    read_chs_sector
        popa

  .dodel:
        push    eax
        movzx   eax, [edi + fs.fat.dir_entry_t.start_cluster.low]
        xchg    eax, [esp]
        ; delete folder entry
        mov     byte[edi], 0xe5
        ; delete LFN (if present)

  .lfndel:
        cmp     edi, FDD_BUFF
        ja      @f
        cmp     [fd_prev_sector], 0
        je      .lfndone
        push    [fd_prev_sector]
        mov_s_  [fd_prev_sector], [fd_prev_prev_sector]
        and     [fd_prev_prev_sector], 0
        pusha
        call    save_chs_sector
        popa
        pop     eax
        pusha
        call    read_chs_sector
        popa
        mov     edi, FDD_BUFF + 0x200

    @@: sub     edi, sizeof.fs.fat.dir_entry_t
        cmp     [edi + fs.fat.dir_entry_t.name], 0xe5
        je      .lfndone
        cmp     [edi + fs.fat.dir_entry_t.attributes], 0x0f
        jne     .lfndone
        mov     [edi + fs.fat.dir_entry_t.name], 0xe5
        jmp     .lfndel

  .lfndone:
        pusha
        call    save_chs_sector
        popa
        ; delete FAT chain
        pop     eax
        test    eax, eax
        jz      .done

    @@: lea     eax, [FLOPPY_FAT + eax * 2]
        push    dword[eax]
        and     word[eax], 0
        pop     eax
        and     eax, 0x0fff
        jnz     @b

  .done:
        call    save_flp_fat
        pop     edi
        xor     eax, eax
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
