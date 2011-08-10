;;======================================================================================================================
;;///// iso9660.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

uglobal
  cd_current_pointer_of_input   dd 0
  cd_current_pointer_of_input_2 dd 0
  cd_mem_location               dd 0
  cd_counter_block              dd 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_CdRead ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for reading CD disk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename /dir1/dir2/.../dirn/file,0
;> ebx = pointer to 64-bit number = first wanted byte, 0+
;> ecx = number of bytes to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< ebx = bytes read or 0xffffffff file not found
;< eax = 0 ok read or other = errormsg
;-----------------------------------------------------------------------------------------------------------------------
;# if ebx = 0, start from first byte
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        cmp     byte[esi], 0
        jnz     @f

  .noaccess:
        pop     edi

  .noaccess_2:
        or      ebx, -1
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .noaccess_3:
        pop     eax edx ecx edi
        jmp     .noaccess_2


    @@: call    cd_find_lfn
        jnc     .found
        pop     edi
        cmp     [DevErrorCode], 0
        jne     .noaccess_2
        or      ebx, -1
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

  .found:
        mov     edi, [cd_current_pointer_of_input]
        test    byte[edi + 25], 010b ; do not allow read directories
        jnz     .noaccess
        test    ebx, ebx
        jz      .l1
        cmp     dword[ebx + 4], 0
        jz      @f
        xor     ebx, ebx

  .reteof:
        mov     eax, 6 ; end of file
        pop     edi
        ret

    @@: mov     ebx, [ebx]

  .l1:
        push    ecx edx
        push    0
        mov     eax, [edi + 10] ; real file section size
        sub     eax, ebx
        jb      .eof
        cmp     eax, ecx
        jae     @f
        mov     ecx, eax
        mov     byte[esp], 6

    @@: mov     eax, [edi + 2]
        mov     [CDSectorAddress], eax
        ; now eax=cluster, ebx=position, ecx=count, edx=buffer for data

  .new_sector:
        test    ecx, ecx
        jz      .done
        sub     ebx, 2048
        jae     .next
        add     ebx, 2048
        jnz     .incomplete_sector
        cmp     ecx, 2048
        jb      .incomplete_sector
        ; we may read and memmove complete sector
        mov     [CDDataBuf_pointer], edx
        call    ReadCDWRetr ; reading file sector
        cmp     [DevErrorCode], 0
        jne     .noaccess_3
        add     edx, 2048
        sub     ecx, 2048

  .next:
        inc     [CDSectorAddress]
        jmp     .new_sector

  .incomplete_sector:
        ; we must read and memmove incomplete sector
        mov     [CDDataBuf_pointer], CDDataBuf
        call    ReadCDWRetr ; reading file sector
        cmp     [DevErrorCode], 0
        jne     .noaccess_3
        push    ecx
        add     ecx, ebx
        cmp     ecx, 2048
        jbe     @f
        mov     ecx, 2048

    @@: sub     ecx, ebx
        push    edi esi ecx
        mov     edi, edx
        lea     esi, [CDDataBuf + ebx]
        cld
        rep     movsb
        pop     ecx esi edi
        add     edx, ecx
        sub     [esp], ecx
        pop     ecx
        xor     ebx, ebx
        jmp     .next

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
kproc fs_CdReadFolder ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for reading CD disk folder
;-----------------------------------------------------------------------------------------------------------------------
;> esi  points to filename  /dir1/dir2/.../dirn/file,0
;> ebx  pointer to structure 32-bit number = first wanted block, 0+ & flags (bitfields)
;> ecx  number of blocks to read, 0+
;> edx  mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 ok read or error code
;< ebx = blocks read or -1 (folder not found)
;-----------------------------------------------------------------------------------------------------------------------
;# flags:
;#   bit 0: 0 (ANSI names) or 1 (UNICODE names)
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        call    cd_find_lfn
        jnc     .found
        pop     edi
        cmp     [DevErrorCode], 0
        jne     .noaccess_1
        or      ebx, -1
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

  .found:
        mov     edi, [cd_current_pointer_of_input]
        test    byte[edi + 25], 010b ; do not allow read directories
        jnz     .found_dir
        pop     edi

  .noaccess_1:
        or      ebx, -1
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .found_dir:
        mov     eax, [edi + 2] ; eax=cluster
        mov     [CDSectorAddress], eax
        mov     eax, [edi + 10] ; directory size

  .doit:
        ; init header
        push    eax ecx
        mov     edi, edx
        mov     ecx, 32 / 4
        xor     eax, eax
        rep     stosd
        pop     ecx eax
        mov     byte[edx], 1 ; version
        mov     [cd_mem_location], edx
        add     [cd_mem_location], 32

        ; convert "БДВК" info "УСВК"

; .mainloop:
        mov     [cd_counter_block], 0
        dec     dword[CDSectorAddress]
        push    ecx

  .read_to_buffer:
        inc     [CDSectorAddress]
        mov     [CDDataBuf_pointer], CDDataBuf
        call    ReadCDWRetr ; reading directory sector
        cmp     [DevErrorCode], 0
        jne     .noaccess_1
        call    .get_names_from_buffer
        sub     eax, 2048
        ; is it the end of directory?
        ja      .read_to_buffer
        mov     edi, [cd_counter_block]
        mov     [edx + 8], edi
        mov     edi, [ebx]
        sub     [edx + 4], edi
        xor     eax, eax
        dec     ecx
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: pop     ecx edi
        mov     ebx, [edx + 4]
        ret

  .get_names_from_buffer:
        mov     [cd_current_pointer_of_input_2], CDDataBuf
        push    eax esi edi edx

  .get_names_from_buffer_1:
        call    cd_get_name
        jc      .end_buffer
        inc     dword[cd_counter_block]
        mov     eax, [cd_counter_block]
        cmp     [ebx], eax
        jae     .get_names_from_buffer_1
        test    ecx, ecx
        jz      .get_names_from_buffer_1
        mov     edi, [cd_counter_block]
        mov     [edx + 4], edi
        dec     ecx
        mov     esi, ebp
        mov     edi, [cd_mem_location]
        add     edi, 40
        test    dword[ebx + 4], 1 ; 0=ANSI, 1=UNICODE
        jnz     .unicode
;       jmp     .unicode

  .ansi:
        cmp     [cd_counter_block], 2
        jbe     .ansi_parent_directory
        cld
        lodsw
        xchg    ah, al
        call    uni2ansi_char
        cld
        stosb
        ; check for filename end
        mov     ax, [esi]
        cmp     ax, 0x3b00 ; ';' - filename terminator
        je      .cd_get_parameters_of_file_1
        ; check for filenames not ending with terminator
        movzx   eax, byte[ebp - 33]
        add     eax, ebp
        sub     eax, 34
        cmp     esi, eax
        je      .cd_get_parameters_of_file_1
        ; check for end of directory
        movzx   eax, byte[ebp - 1]
        add     eax, ebp
        cmp     esi, eax
        jb      .ansi

  .cd_get_parameters_of_file_1:
        mov   byte[edi], 0
        call  cd_get_parameters_of_file
        add   [cd_mem_location], 304
        jmp   .get_names_from_buffer_1

  .ansi_parent_directory:
        cmp     [cd_counter_block], 2
        je      @f
        mov     byte[edi], '.'
        inc     edi
        jmp     .cd_get_parameters_of_file_1

    @@: mov     word[edi], '..'
        add     edi, 2
        jmp     .cd_get_parameters_of_file_1

  .unicode:
        cmp     [cd_counter_block], 2
        jbe     .unicode_parent_directory
        cld
        movsw
        ; check for end of filename
        mov     ax, [esi]
        cmp     ax, 0x3b00 ; ';' - filename terminator
        je      .cd_get_parameters_of_file_2
        ; check for filenames not ending with terminator
        movzx   eax, byte[ebp - 33]
        add     eax, ebp
        sub     eax, 34
        cmp     esi, eax
        je      .cd_get_parameters_of_file_2
        ; check for end of directory
        movzx   eax, byte[ebp - 1]
        add     eax, ebp
        cmp     esi, eax
        jb      .unicode

  .cd_get_parameters_of_file_2:
        mov     word[edi], 0
        call    cd_get_parameters_of_file
        add     [cd_mem_location], 560
        jmp     .get_names_from_buffer_1

  .unicode_parent_directory:
        cmp     [cd_counter_block], 2
        je      @f
        mov     word[edi], 0x2e00 ; '.'
        add     edi, 2
        jmp     .cd_get_parameters_of_file_2

    @@: mov     dword[edi], 0x2e002e00 ; '..'
        add     edi, 4
        jmp     .cd_get_parameters_of_file_2

  .end_buffer:
        pop     edx edi esi eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_get_parameters_of_file ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [cd_mem_location]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_get_parameters_of_file_1 ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; getting file attributes
        xor     eax, eax
        ; not an archived file
        inc     eax
        shl     eax, 1
        ; is it a directory?
        test    byte[ebp - 8], 2
        jz      .file
        inc     eax

  .file:
        ; disk label is not as in FAT, not present in that form
        ; not a system file
        shl     eax, 3
        ; is it a hidden file? (existence attribute)
        test    byte[ebp - 8], 1
        jz      .hidden
        inc     eax

  .hidden:
        shl     eax, 1
        ; file is always read-only since this is CD
        inc     eax
        mov     [edi], eax
        ; getting file time
        ; hours
        movzx   eax, byte[ebp - 12]
        shl     eax, 8
        ; minutes
        mov     al, [ebp - 11]
        shl     eax, 8
        ; seconds
        mov     al, [ebp - 10]
        ; file creation time
        mov     [edi + 8], eax
        ; file last access time
        mov     [edi + 16], eax
        ; file last modification time
        mov     [edi + 24], eax
        ; getting file date
        ; year
        movzx   eax, byte[ebp - 15]
        add     eax, 1900
        shl     eax, 8
        ; month
        mov     al, [ebp - 14]
        shl     eax, 8
        ; day
        mov     al, [ebp - 13]
        ; file creation date
        mov     [edi + 12], eax
        ; file last access date
        mov     [edi + 20], eax
        ; file last modification date
        mov     [edi + 28], eax
        ; getting filename encoding
        xor     eax, eax
        test    dword[ebx + 4], 1 ; 0=ANSI, 1=UNICODE
        jnz     .unicode_1
        mov     [edi + 4], eax
        jmp     @f

  .unicode_1:
        inc     eax
        mov     [edi + 4], eax

    @@: ; getting file size (in bytes)
        xor     eax, eax
        mov     [edi + 32 + 4], eax
        mov     eax, [ebp - 23]
        mov     [edi + 32], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_CdGetFileInfo ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# LFN variant for CD, get file/directory attributes structure
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f
        mov     eax, ERROR_NOT_IMPLEMENTED
        ret

    @@: push    edi
        call    cd_find_lfn
        pushfd
        cmp     [DevErrorCode], 0
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

    @@: mov     edi, edx
        push    ebp
        mov     ebp, [cd_current_pointer_of_input]
        add     ebp, 33
        call    cd_get_parameters_of_file_1
        pop     ebp
        and     dword[edi + 4], 0
        pop     edi
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_find_lfn ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi + ebp = pointer to name
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 1, file not found
;< if CF = 0,
;<   [cd_current_pointer_of_input] = direntry
;-----------------------------------------------------------------------------------------------------------------------
        mov     [cd_appl_data], 0
        push    eax esi
        ; sector 16 - beginning of volume descriptor set

        call    WaitUnitReady
        cmp     [DevErrorCode], 0
        jne     .access_denied

        call    prevent_medium_removal
        ; test read
        mov     [CDSectorAddress], 16
        mov     [CDDataBuf_pointer], CDDataBuf
        call    ReadCDWRetr ; _1
        cmp      [DevErrorCode], 0
        jne     .access_denied

        ; calculating last session
        call    WaitUnitReady
        cmp     [DevErrorCode], 0
        jne     .access_denied
        call    Read_TOC
        mov     ah, [CDDataBuf + 4 + 4]
        mov     al, [CDDataBuf + 4 + 5]
        shl     eax, 16
        mov     ah, [CDDataBuf + 4 + 6]
        mov     al, [CDDataBuf + 4 + 7]
        add     eax, 15
        mov     [CDSectorAddress], eax
;       mov     [CDSectorAddress], 15
        mov     [CDDataBuf_pointer], CDDataBuf


  .start:
        inc     [CDSectorAddress]
        call    ReadCDWRetr ; _1
        cmp      [DevErrorCode], 0
        jne     .access_denied

  .start_check:
        ; dummy check
        cmp     dword[CDDataBuf + 1], 'CD00'
        jne     .access_denied
        cmp     byte[CDDataBuf + 5], '1'
        jne     .access_denied
        ; is it a volume descriptor set terminator?
        cmp     byte[CDDataBuf], 0xff
        je      .access_denied
        ; is it a supplementary volume descriptor?
        cmp     byte[CDDataBuf], 0x2
        jne     .start
        ; is it an enhanced volume descriptor (version = 2)?
        cmp     byte[CDDataBuf + 6], 0x1
        jne     .start

        ; root directory parameters
        mov     eax, [CDDataBuf + 0x9c + 2] ; root directory start
        mov     [CDSectorAddress], eax
        mov     eax, [CDDataBuf + 0x9c + 10] ; root directory size
        cmp     byte[esi], 0
        jnz     @f
        mov     [cd_current_pointer_of_input], CDDataBuf + 0x9c
        jmp     .done

    @@: ; beginning search

  .mainloop:
        dec     [CDSectorAddress]

  .read_to_buffer:
        inc     dword[CDSectorAddress]
        mov     [CDDataBuf_pointer], CDDataBuf
        call    ReadCDWRetr ; reading directory sector
        cmp     [DevErrorCode], 0
        jne     .access_denied
        push    ebp
        call    cd_find_name_in_buffer
        pop     ebp
        jnc     .found
        sub     eax, 2048
        ; end of directory?
        cmp     eax, 0
        ja      .read_to_buffer

        ; needed entry not found

  .access_denied:
        pop     esi eax
        mov     [cd_appl_data], 1
        stc
        ret

  .found:
        ; needed entry found
        ; end of filename
        cmp    byte[esi - 1], 0
        jz    .done

  .nested:
        mov     eax, [cd_current_pointer_of_input]
        push    dword[eax + 2]
        pop     dword[CDSectorAddress] ; directory start
        mov     eax, [eax + 2 + 8] ; directory size
        jmp     .mainloop

  .done:
        ; pointer to file found
        test    ebp, ebp
        jz      @f
        mov     esi, ebp
        xor     ebp, ebp
        jmp     .nested

    @@: pop     esi eax
        mov     [cd_appl_data], 1
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_find_name_in_buffer ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [cd_current_pointer_of_input_2], CDDataBuf

  .start:
        call    cd_get_name
        jc      .not_found
        call    cd_compare_name
        jc      .start

  .found:
        clc
        ret

  .not_found:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_get_name ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     ebp, [cd_current_pointer_of_input_2]
        mov     [cd_current_pointer_of_input], ebp
        mov     eax, [ebp]
        test    eax, eax ; end of entries?
        jz      .next_sector
        cmp     ebp, CDDataBuf + 2048 ; end of buffer?
        jae     .next_sector
        movzx   eax, byte[ebp]
        add     [cd_current_pointer_of_input_2], eax ; next directory entry
        add     ebp, 33 ; pointer set to beginning of name
        pop     eax
        clc
        ret

  .next_sector:
        pop  eax
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_compare_name ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? compares ASCIIZ-names, case-insensitive (cp866 encoding)
;-----------------------------------------------------------------------------------------------------------------------
;> esi = pointer to name
;> ebp = pointer to name
;-----------------------------------------------------------------------------------------------------------------------
;< if ZF = 1 (if names match),
;<   esi = pointer to next component of name
;< if ZF = 0, esi is not changed
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;-----------------------------------------------------------------------------------------------------------------------
        push    esi eax edi
        mov     edi, ebp

  .loop:
        cld
        lodsb
        push    eax
        call    char_todown
        call    ansi2uni_char
        xchg    ah, al
        scasw
        pop     eax
        je      .coincides
        call    char_toupper
        call    ansi2uni_char
        xchg    ah, al
        sub     edi, 2
        scasw
        jne     .name_not_coincide

  .coincides:
        cmp     byte[esi], '/' ; path separator, end of current element name
        je      .done
        cmp     byte[esi], 0 ; path separator, end of current element name
        je      .done
        jmp     .loop

  .name_not_coincide:
        pop     edi eax esi
        stc
        ret

  .done:
        ; check for end of filename
        cmp     word[edi], 0x3b00 ; ';' - filename terminator
        je      .done_1
        ; check for filenames not ending with terminator
        movzx   eax, byte[ebp - 33]
        add     eax, ebp
        sub     eax, 34
        cmp     edi, eax
        je      .done_1
        ; check for end of directory
        movzx   eax, byte[ebp - 1]
        add     eax, ebp
        cmp     edi, eax
        jne     .name_not_coincide

  .done_1:
        pop   edi eax
        add   esp, 4
        inc   esi
        clc
        ret
kendp
