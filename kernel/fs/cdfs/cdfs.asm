;;======================================================================================================================
;;///// cdfs.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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

struct fs.cdfs.partition_t fs.partition_t
  buffer rb 4096
ends

iglobal
  JumpTable fs.cdfs, vftbl, 0, \
    read_file, \
    read_directory, \
    -, \
    -, \
    -, \
    get_file_info, \
    -, \
    -, \
    -, \
    -
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs.read_file ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.read_file_query_params_t
;> ebx ^= fs.cdfs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= bytes read (on success)
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .access_denied_error

        ; TODO: support offsets up to 8 TiB (43-bit)
        cmp     dword[edx + fs.read_file_query_params_t.range.offset + 4], 0
        jne     .end_of_file_error

        call    fs.cdfs._.find_file_lfn
        jc      .exit

        ; do not allow reading directories
        test    [edi + fs.iso9660.dir_entry_t.attributes], FS_ISO9660_ATTR_DIRECTORY
        jnz     .access_denied_error

        mov     ebp, dword[edx + fs.read_file_query_params_t.range.offset]
        mov     eax, [edi + fs.iso9660.dir_entry_t.size.lsb]
        cmp     ebp, eax
        jae     .end_of_file_error

        push    ERROR_SUCCESS 0

        mov     ecx, [edx + fs.read_file_query_params_t.range.length]
        sub     eax, ebp
        cmp     ecx, eax
        jbe     @f

        mov     ecx, eax
        mov     byte[esp + 4], ERROR_END_OF_FILE

    @@: mov     eax, ebp
        shr     eax, 11 ; / 2048
        add     eax, [edi + fs.iso9660.dir_entry_t.extent_loc.lsb]

        mov     edi, [edx + fs.read_file_query_params_t.buffer_ptr]

        and     ebp, 2048 - 1
        jnz     .incomplete_sector

        dec     eax

  .next_sector:
        inc     eax

        cmp     ecx, 2048
        jb      .incomplete_sector

        push    eax ecx

        xor     edx, edx
        shld    eax, edx, 2
        MovStk  ecx, 4
        call    fs.read
        test    eax, eax
        jnz     .device_error_2

        pop     ecx eax

        add     dword[esp], 2048
        add     edi, 2048
        add     ecx, -2048
        jz      .done
        jmp     .next_sector

  .incomplete_sector:
        push    eax edi
        call    fs.cdfs._.read_sector
        lea     esi, [edi + ebp]
        pop     edi eax
        jnz     .device_error

        not     ebp
        add     ebp, 2048

        push    ecx
        cmp     ecx, ebp
        jbe     @f

        mov     ecx, ebp

    @@: add     [esp + 4], ecx
        rep
        movsb
        pop     ecx

        sub     ecx, ebp
        jbe     .done

        xor     ebp, ebp
        jmp     .next_sector

  .done:
        pop     ebx eax

  .exit:
        ret

  .access_denied_error_2:
        pop     eax edx ecx

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        or      ebx, -1
        ret

  .eof:
        mov     ebx, edx
        pop     eax edx ecx
        sub     ebx, edx

  .end_of_file_error:
        mov     eax, ERROR_END_OF_FILE
        or      ebx, -1
        ret

  .device_error_2:
        add     esp, 8

  .device_error:
        add     esp, 8
        mov     eax, ERROR_DEVICE_FAIL
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs.read_directory ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to directory
;> edx ^= fs.read_directory_query_params_t
;> ebx ^= fs.cdfs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= directory entries read (on success)
;-----------------------------------------------------------------------------------------------------------------------
        call    fs.cdfs._.find_file_lfn
        jc      .exit

        ; do not allow reading files
        test    [edi + fs.iso9660.dir_entry_t.attributes], FS_ISO9660_ATTR_DIRECTORY
        jz      .access_denied_error

        push    [edx + fs.read_directory_query_params_t.start_block]
        push    [edi + fs.iso9660.dir_entry_t.size.lsb]
        push    [edi + fs.iso9660.dir_entry_t.extent_loc.lsb]

        ; init header
        mov     edi, [edx + fs.read_directory_query_params_t.buffer_ptr]
        mov     ecx, sizeof.fs.file_info_header_t / 4
        xor     eax, eax
        rep
        stosd

        mov     ecx, [edx + fs.read_directory_query_params_t.count]

        mov     ebp, edx

        lea     edx, [edi - sizeof.fs.file_info_header_t]
        mov     [edx + fs.file_info_header_t.version], 1 ; version

        pop     eax
        dec     eax

  .next_sector:
        inc     eax

        push    eax edi
        call    fs.cdfs._.read_sector ; reading directory sector
        mov     esi, edi
        pop     edi eax
        jnz     .device_error

        push    dword[esp + 4]
        call    fs.cdfs._.get_names_from_buffer
        pop     dword[esp + 4]

        add     dword[esp], -2048
        jnz     .next_sector

        add     esp, 8

        mov     ebx, [edx + fs.file_info_header_t.files_read]
        xor     eax, eax ; ERROR_SUCCESS
        test    ecx, ecx
        jz      .exit

        mov     al, ERROR_END_OF_FILE

  .exit:
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .device_error:
        add     esp, 8
        mov     eax, ERROR_DEVICE_FAIL
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs.get_file_info ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> edx ^= fs.get_file_info_query_params_t
;> ebx ^= fs.cdfs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      .not_implemented_error

        call    fs.cdfs._.find_file_lfn
        jc      .exit

        xor     eax, eax
        mov     esi, edi
        mov     edi, [edx + fs.get_file_info_query_params_t.buffer_ptr]
        call    fs.cdfs._.dir_entry_to_file_info

        xor     eax, eax ; ERROR_SUCCESS

  .exit:
        ret

  .not_implemented_error:
        mov     eax, ERROR_NOT_IMPLEMENTED
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs._.find_file_lfn ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path
;> ebp ^= filename
;> ebx ^= fs.cdfs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< Cf = 1,
;<   eax #= error code
;< Cf = 0,
;<   edi ^= fs.iso9660.dir_entry_t
;<   eax #= directory cluster
;-----------------------------------------------------------------------------------------------------------------------
;# TODO: multisession (iso13490/ecma168) support
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi

        mov     eax, 16 - 1

  .next_volume_descriptor:
        inc     eax

        push    eax
        call    fs.cdfs._.read_sector
        pop     eax
        jnz     .device_error

        ; dummy check
        cmp     dword[edi + fs.iso9660.vol_descr_t.std_ident], 'CD00'
        jne     .access_denied_error
        cmp     [edi + fs.iso9660.vol_descr_t.std_ident + 4], '1'
        jne     .access_denied_error
        ; is it a volume descriptor set terminator?
        cmp     [edi + fs.iso9660.vol_descr_t.descr_type], FS_ISO9660_VOL_TYPE_SET_TERM
        je      .access_denied_error
        ; is it a supplementary volume descriptor?
        cmp     [edi + fs.iso9660.vol_descr_t.descr_type], FS_ISO9660_VOL_TYPE_SUP_VOL_DESCR
        jne     .next_volume_descriptor
        ; is it an enhanced volume descriptor (version = 2)?
        cmp     [edi + fs.iso9660.vol_descr_t.descr_version], 1
        jne     .next_volume_descriptor

        add     edi, fs.iso9660.sup_vol_descr_t.root_dir_entry

        ; root directory start
        mov     eax, [edi + fs.iso9660.dir_entry_t.extent_loc.lsb]
        ; root directory size
        mov     ecx, [edi + fs.iso9660.dir_entry_t.size.lsb]

        cmp     byte[esi], 0
        je      .done

  .main_loop:
        ; beginning search
        dec     eax

  .read_to_buffer:
        inc     eax

        push    eax
        call    fs.cdfs._.read_sector
        pop     eax
        jnz     .device_error

        call    fs.cdfs._.find_name_in_buffer
        jnc     .found

        ; end of directory?
        add     ecx, -2048
        jnz     .read_to_buffer
        jmp     .file_not_found_error

  .found:
        ; needed entry found
        ; end of filename
        cmp     byte[esi - 1], 0
        jne     .nested

  .done:
        ; pointer to file found
        test    ebp, ebp ; Cf = 0
        jz      .exit

        mov     esi, ebp
        xor     ebp, ebp

  .nested:
        mov     eax, [edi + fs.iso9660.dir_entry_t.extent_loc.lsb]
        mov     ecx, [edi + fs.iso9660.dir_entry_t.size.lsb]
        jmp     .main_loop

  .exit:
        add     esp, 4
        pop     esi
        ret

  .file_not_found_error:
        mov     eax, ERROR_FILE_NOT_FOUND
        pop     edi esi
        stc
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        pop     edi esi
        stc
        ret

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        pop     edi esi
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs._.get_names_from_buffer ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.cdfs.partition_t
;> ecx #= entries to read
;> edx ^= fs.file_info_header_t
;> esi ^= input buffer
;> edi ^= output buffer
;> ebp ^= fs.read_directory_query_params_t
;-----------------------------------------------------------------------------------------------------------------------
;< ecx #= entries left to read
;< edi ^= output buffer, adjusted
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx

        lea     eax, [ebx + fs.cdfs.partition_t.buffer]

        mov     ebx, esp

        push    .get_entry
        call    fs.cdfs._.enumerate_buffer_entries

        pop     ebx eax
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .get_entry: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        inc     [edx + fs.file_info_header_t.files_count]
        cmp     dword[ebx + 8 + 4], 0
        ja      .skip_entry
        test    ecx, ecx
        jz      .exit

        dec     ecx
        inc     [edx + fs.file_info_header_t.files_read]

        mov     esi, eax
        mov     eax, [ebp + fs.read_directory_query_params_t.flags]
        call    fs.cdfs._.dir_entry_to_file_info
        call    fs.cdfs._.name_to_file_info_name

        add     edi, sizeof.fs.file_info_t + 264
        test    eax, FS_INFO_FLAG_UNICODE
        jz      .exit

        add     edi, 520 - 264
        jmp     .exit

  .skip_entry:
        dec     dword[ebx + 8 + 4]

  .exit:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs._.dir_entry_to_file_info ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= flags
;> esi ^= fs.iso9660.dir_entry_t
;> edi ^= fs.file_info_t
;-----------------------------------------------------------------------------------------------------------------------
;< edi ^= next fs.file_info_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        mov     [edi + fs.file_info_t.flags], eax

        mov     eax, FS_INFO_ATTR_ARCHIVED + FS_INFO_ATTR_READONLY
        test    [esi + fs.iso9660.dir_entry_t.attributes], FS_ISO9660_ATTR_DIRECTORY
        jz      @f
        or      al, FS_INFO_ATTR_DIR

    @@: test    [esi + fs.iso9660.dir_entry_t.attributes], FS_ISO9660_ATTR_EXISTENCE
        jz      @f
        or      al, FS_INFO_ATTR_HIDDEN

    @@: mov     [edi + fs.file_info_t.attributes], eax

        movzx   eax, [esi + fs.iso9660.dir_entry_t.recorded_at.hour]
        shl     eax, 8
        mov     al, [esi + fs.iso9660.dir_entry_t.recorded_at.minute]
        shl     eax, 8
        mov     al, [esi + fs.iso9660.dir_entry_t.recorded_at.second]
        mov     [edi + fs.file_info_t.created_at.time], eax
        mov     [edi + fs.file_info_t.accessed_at.time], eax
        mov     [edi + fs.file_info_t.modified_at.time], eax

        movzx   eax, [esi + fs.iso9660.dir_entry_t.recorded_at.year]
        add     eax, 1900
        shl     eax, 8
        mov     al, [esi + fs.iso9660.dir_entry_t.recorded_at.month]
        shl     eax, 8
        mov     al, [esi + fs.iso9660.dir_entry_t.recorded_at.day]
        mov     [edi + fs.file_info_t.created_at.date], eax
        mov     [edi + fs.file_info_t.accessed_at.date], eax
        mov     [edi + fs.file_info_t.modified_at.date], eax

        xor     eax, eax
        mov     [edi + fs.file_info_t.size.high], eax
        mov     eax, [esi + fs.iso9660.dir_entry_t.size.lsb]
        mov     [edi + fs.file_info_t.size.low], eax

        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs._.name_to_file_info_name ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= flags
;> esi ^= fs.iso9660.dir_entry_t
;> edi ^= fs.file_info_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx esi edi

        movzx   edx, [esi + fs.iso9660.dir_entry_t.name_size]
        shr     edx, 1

        add     esi, fs.iso9660.dir_entry_t.name
        add     edi, fs.file_info_t.name

        test    eax, FS_INFO_FLAG_UNICODE
        jnz     .unicode_name

  .ansi_name:
        mov     ecx, 264 - 1
        test    edx, edx
        jz      .ansi_name_special

  .ansi_name_next_char:
        lodsw
        xchg    ah, al

        cmp     ax, ';' ; filename terminator
        je      .ansi_name_done

        call    uni2ansi_char
        stosb

        dec     ecx
        jz      .ansi_name_done
        dec     edx
        jnz     .ansi_name_next_char

  .ansi_name_done:
        xor     al, al
        stosb
        jmp     .exit

  .ansi_name_special:
        cmp     byte[esi], 0 ; self
        jne     @f

        mov     al, '.'
        stosb
        jmp     .ansi_name_done

    @@: cmp     byte[esi], 1 ; parent
        jne     .ansi_name_done

        mov     ax, '..'
        stosw
        jmp     .ansi_name_done

  .unicode_name:
        mov     ecx, 260 - 1
        test    edx, edx
        jz      .unicode_name_special

  .unicode_name_next_char:
        lodsw
        xchg    ah, al

        cmp     ax, ';' ; filename terminator
        je      .unicode_name_done

        stosw

        dec     ecx
        jz      .unicode_name_done
        dec     edx
        jnz     .unicode_name_next_char

  .unicode_name_done:
        xor     ax, ax
        stosw
        jmp     .exit

  .unicode_name_special:
        cmp     byte[esi], 0 ; self
        jne     @f

        mov     ax, '.'
        stosw
        jmp     .unicode_name_done

    @@: cmp     byte[esi], 1 ; parent
        jne     .unicode_name_done

        mov     eax, ('.' shl 16) + '.'
        stosd
        jmp     .unicode_name_done

  .exit:
        pop     edi esi edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs._.enumerate_buffer_entries ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        add     eax, 2048
        push    eax
        add     eax, -2048

  .next_entry:
        cmp     eax, [esp]
        jae     .exit
        cmp     [eax + fs.iso9660.dir_entry_t.entry_size], 0
        je      .exit

        push    eax
        call    dword[esp + 4 + 4 + 4 + 4]
        pop     eax
        jnc     .exit

        push    eax
        movzx   eax, [eax + fs.iso9660.dir_entry_t.entry_size]
        add     [esp], eax
        pop     eax
        jmp     .next_entry

  .exit:
        pop     eax eax
        ret     4
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs._.find_name_in_buffer ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebp

        push    .compare
        xor     ebp, ebp
        lea     eax, [ebx + fs.cdfs.partition_t.buffer]
        call    fs.cdfs._.enumerate_buffer_entries
        test    ebp, ebp
        jz      .not_found

        mov     edi, ebp
        pop     ebp eax
        clc
        ret

  .not_found:
        pop     ebp eax
        stc
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .compare: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        lea     edi, [eax + fs.iso9660.dir_entry_t.name]
        call    fs.cdfs._.compare_name
        jc      .compare_exit

        lea     ebp, [edi - fs.iso9660.dir_entry_t.name]
        clc

  .compare_exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs._.compare_name ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? compares ASCIIZ-names, case-insensitive (cp866 encoding)
;-----------------------------------------------------------------------------------------------------------------------
;> esi = pointer to name
;> edi = pointer to name
;-----------------------------------------------------------------------------------------------------------------------
;< if ZF = 1 (if names match),
;<   esi = pointer to next component of name
;< if ZF = 0, esi is not changed
;-----------------------------------------------------------------------------------------------------------------------
        push    esi eax edi ebp
        mov     ebp, edi

  .loop:
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
        pop     ebp edi eax esi
        stc
        ret

  .done:
        ; check for end of filename
        cmp     word[edi], ';' shl 8 ; ';' - filename terminator
        je      .done_1
        ; check for filenames not ending with terminator
        movzx   eax, [ebp - fs.iso9660.dir_entry_t.name + fs.iso9660.dir_entry_t.entry_size]
        add     eax, ebp
        sub     eax, fs.iso9660.dir_entry_t.name + 1
        cmp     edi, eax
        je      .done_1
        ; check for end of directory
        movzx   eax, [ebp - fs.iso9660.dir_entry_t.name + fs.iso9660.dir_entry_t.name_size]
        add     eax, ebp
        cmp     edi, eax
        jne     .name_not_coincide

  .done_1:
        pop     ebp edi eax
        add     esp, 4
        inc     esi
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs._.read_sector ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= sector number
;> ebx ^= fs.cdfs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< edi ^= buffer
;< eflags[zf] = 1 (ok) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        xor     edx, edx
        shld    eax, edx, 2
        MovStk  ecx, 4
        lea     edi, [ebx + fs.cdfs.partition_t.buffer]
        call    fs.read

        test    eax, eax
        pop     edx ecx
        ret
kendp
