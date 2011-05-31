;;======================================================================================================================
;;///// ext_lib.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2007-2009 KolibriOS team <http://kolibrios.org/>
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

;============================================================================
;
;   External kernel dependencies (libraries) loading
;
;============================================================================

if 0

; The code currently does not work. Kill "if 0/end if" only after correcting
; to current kernel (dll.inc).
macro library [name,fname]
{
  forward
    dd __#name#_library_table__,__#name#_library_name__
  common
    dd 0
  forward
    __#name#_library_name__ db fname,0
}

macro import lname,[name,sname]
{
  common
    align 4
    __#lname#_library_table__:
  forward
    name dd __#name#_import_name__
  common
    dd 0
  forward
    __#name#_import_name__ db sname,0
}

macro export [name,sname]
{
align 4
  forward
    dd __#name#_export_name__,name
  common
    dd 0
  forward
    __#name#_export_name__ db sname,0
}



align 4            ; loading library (use kernel functions)
proc load_k_library stdcall, file_name:dword
locals
  coff      dd ?
  sym       dd ?
  strings   dd ?
  img_size  dd ?
  img_base  dd ?
  exports   dd ?
endl

        cli

        stdcall load_file, [file_name]
        test    eax, eax
        jz      .fail

        mov     [coff], eax
        movzx   ecx, [eax + coff_header_t.sections_cnt]
        xor     ebx, ebx

        lea     edx, [eax + 20]

    @@: add     ebx, [edx + coff_section_t.raw_data_size]
        add     ebx, 15
        and     ebx, not 15
        add     edx, sizeof.coff_section_t
        dec     ecx
        jnz     @b
        mov     [img_size], ebx

        stdcall kernel_alloc, [img_size]

        test    eax, eax
        jz      .fail
        mov     [img_base], eax

        mov     edx, [coff]
        movzx   ebx, [edx + coff_header_t.sections_cnt]
        mov     edi, [img_base]
        lea     eax, [edx + 20]

    @@: mov     [eax + coff_section_t.virtual_addr], edi
        mov     esi, [eax + coff_section_t.raw_data_ptr]
        test    esi, esi
        jnz     .copy
        add     edi, [eax + coff_section_t.raw_data_size]
        jmp     .next

  .copy:
        add     esi, edx
        mov     ecx, [eax + coff_section_t.raw_data_size]
        cld
        rep     movsb

  .next:
        add     edi, 15
        and     edi, not 15
        add     eax, sizeof.coff_section_t
        dec     ebx
        jnz     @b

        mov     ebx, [edx + coff_header_t.syms_ptr]
        add     ebx, edx
        mov     [sym], ebx
        mov     ecx, [edx + coff_header_t.syms_cnt]
        add     ecx, ecx
        lea     ecx, [ecx + ecx * 8] ; ecx *= 18 = nSymbols * sizeof.coff_symbol_t
        add     ecx, [sym]
        mov     [strings], ecx

        lea     eax, [edx + 20]

        stdcall fix_coff_symbols, eax, [sym], [edx + coff_header_t.syms_cnt], [strings], 0
        test    eax, eax
        jnz     @f

    @@: mov     edx, [coff]
        movzx   ebx, [edx + coff_header_t.sections_cnt]
        mov     edi, 0
        lea     eax, [edx + 20]

    @@: add     [eax + coff_section_t.virtual_addr], edi ; patch user space offset
        add     eax, sizeof.coff_section_t
        dec     ebx
        jnz     @b

        add     edx, 20
        stdcall fix_coff_relocs, [coff], edx, [sym]

        mov     ebx, [coff]
        stdcall get_coff_sym, [sym], [ebx + coff_header.syms_cnt], szEXPORTS
        mov     [exports], eax

        stdcall kernel_free, [coff]

        mov     eax, [exports]
        ret

  .fail:
        xor     eax, eax
        ret
endp

proc dll.Load, import_table:dword
        mov     esi, [import_table]

  .next_lib:
        mov     edx, [esi]
        or      edx, edx
        jz      .exit
        push    esi

        mov     edi, s_libname

        mov     al, '/'
        stosb
        mov esi, sysdir_path

    @@: lodsb
        stosb
        or      al, al
        jnz     @b
        dec     edi
        mov     dword[edi], '/lib'
        mov     byte[edi + 4], '/'
        add     edi, 5
        pop     esi
        push    esi
        mov     esi,[esi + 4]

    @@: lodsb
        stosb
        or      al, al
        jnz     @b

        pushad
        stdcall load_k_library, s_libname
        mov     [esp + 28], eax
        popad
        or      eax, eax
        jz      .fail
        stdcall dll.Link, eax, edx
        stdcall dll.Init, [eax + 4]
        pop     esi
        add     esi, 8
        jmp     .next_lib

  .exit:
        xor     eax, eax
        ret

  .fail:
        add     esp, 4
        xor     eax, eax
        inc     eax
        ret
endp

proc dll.Link, exp:dword, imp:dword
        push    eax
        mov     esi, [imp]
        test    esi, esi
        jz      .done

  .next:
        lodsd
        test    eax, eax
        jz      .done
        stdcall dll.GetProcAddress, [exp], eax
        or      eax, eax
        jz      @f
        mov     [esi - 4], eax
        jmp     .next

    @@: mov     dword[esp], 0

  .done:
        pop     eax
        ret
endp

proc dll.Init, dllentry:dword
        pushad
        mov     eax, mem.Alloc
        mov     ebx, mem.Free
        mov     ecx, mem.ReAlloc
        mov     edx, dll.Load
        stdcall [dllentry]
        popad
        ret
endp

proc dll.GetProcAddress, exp:dword, sz_name:dword
        mov     edx, [exp]

  .next:
        test    edx, edx
        jz      .end
        stdcall strncmp, [edx], [sz_name], -1
        test    eax, eax
        jz      .ok
        add     edx, 8
        jmp     .next

  .ok:
        mov     eax, [edx + 4]

  .end:
        ret
endp

;-----------------------------------------------------------------------------
proc mem.Alloc size ;/////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------
        push    ebx ecx
        stdcall kernel_alloc, [size]
        pop     ecx ebx
        ret
endp

;-----------------------------------------------------------------------------
proc mem.ReAlloc mptr, size;//////////////////////////////////////////////////
;-----------------------------------------------------------------------------
        push    ebx ecx esi edi eax
        mov     eax, [mptr]
        mov     ebx, [size]
        or      eax, eax
        jz      @f
        lea     ecx, [ebx + 4 + 4095]
        and     ecx, not 4095
        add     ecx, -4
        cmp     ecx, [eax - 4]
        je      .exit

    @@: mov     eax, ebx
        call    mem.Alloc
        xchg    eax, [esp]
        or      eax, eax
        jz      .exit
        mov     esi, eax
        xchg    eax, [esp]
        mov     edi, eax
        mov     ecx, [esi - 4]
        cmp     ecx, [edi - 4]
        jbe     @f
        mov     ecx, [edi - 4]

    @@: add     ecx, 3
        shr     ecx, 2
        cld
        rep     movsd
        xchg    eax, [esp]
        call    mem.Free

  .exit:
        pop     eax edi esi ecx ebx
        ret
endp

;-----------------------------------------------------------------------------
proc mem.Free mptr ;//////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------
        stdcall kernel_free, [mptr]
        ret
endp

uglobal
  s_libname db 64 dup (0)
endg

end if
