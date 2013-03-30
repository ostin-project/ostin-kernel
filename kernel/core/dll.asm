;;======================================================================================================================
;;///// dll.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2006-2010 KolibriOS team <http://kolibrios.org/>
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

DRV_COMPAT  = 5 ; minimal required drivers version
DRV_CURRENT = 6 ; current drivers model version

DRV_VERSION = (DRV_COMPAT shl 16) or DRV_CURRENT
PID_KERNEL  = 1 ; os_idle thread

MAX_DEFAULT_DLL_ADDR = 0x80000000
MIN_DEFAULT_DLL_ADDR = 0x70000000

struct coff_header_t
  machine      dw ?
  sections_cnt dw ?
  data_time    dd ?
  syms_ptr     dd ?
  syms_cnt     dd ?
  opt_header   dw ?
  flags        dw ?
ends

struct coff_section_t
  name             rb 8
  virtual_size     dd ?
  virtual_addr     dd ?
  raw_data_size    dd ?
  raw_data_ptr     dd ?
  relocs_ptr       dd ?
  line_numbers_ptr dd ?
  relocs_cnt       dw ?
  line_numbers_cnt dw ?
  characteristics  dd ?
ends

struct coff_reloc_t
  virtual_addr dd ?
  sym_index    dd ?
  type         dw ?
ends

struct coff_sym_t
  name            rb 8
  value           dd ?
  section_number  dw ?
  type            dw ?
  storage_class   db ?
  aux_symbols_cnt db ?
ends

uglobal
  srv          linked_list_t
  dll_list     linked_list_t
  dll_cur_addr dd MIN_DEFAULT_DLL_ADDR
endg

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc get_notify stdcall, p_ev:dword ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
  .wait:
        mov     ebx, [current_slot_ptr]
        test    [ebx + legacy.slot_t.app.event_mask], EVENT_NOTIFY
        jz      @f
        and     [ebx + legacy.slot_t.app.event_mask], not EVENT_NOTIFY
        mov     edi, [p_ev]
        mov     dword[edi], EV_INTR
        mov     eax, [ebx + legacy.slot_t.app.event]
        mov     [edi + 4], eax
        ret

    @@: call    change_task
        jmp     .wait
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc pci_read32 stdcall, bus:dword, devfn:dword, reg:dword ;////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        xor     eax, eax
        xor     ebx, ebx
        mov     ah, byte[bus]
        mov     al, 6
        mov     bh, byte[devfn]
        mov     bl, byte[reg]
        call    pci_read_reg
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc pci_read16 stdcall, bus:dword, devfn:dword, reg:dword ;////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        xor     eax, eax
        xor     ebx, ebx
        mov     ah, byte[bus]
        mov     al, 5
        mov     bh, byte[devfn]
        mov     bl, byte[reg]
        call    pci_read_reg
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc pci_read8 stdcall, bus:dword, devfn:dword, reg:dword ;/////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        xor     eax, eax
        xor     ebx, ebx
        mov     ah, byte[bus]
        mov     al, 4
        mov     bh, byte[devfn]
        mov     bl, byte[reg]
        call    pci_read_reg
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc pci_write8 stdcall, bus:dword, devfn:dword, reg:dword, val:dword ;/////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        xor     eax, eax
        xor     ebx, ebx
        mov     ah, byte[bus]
        mov     al, 8
        mov     bh, byte[devfn]
        mov     bl, byte[reg]
        mov     ecx, [val]
        call    pci_write_reg
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc pci_write16 stdcall, bus:dword, devfn:dword, reg:dword, val:dword ;////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        xor     eax, eax
        xor     ebx, ebx
        mov     ah, byte[bus]
        mov     al, 9
        mov     bh, byte[devfn]
        mov     bl, byte[reg]
        mov     ecx, [val]
        call    pci_write_reg
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc pci_write32 stdcall, bus:dword, devfn:dword, reg:dword, val:dword ;////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        xor     eax, eax
        xor     ebx, ebx
        mov     ah, byte[bus]
        mov     al, 10
        mov     bh, byte[devfn]
        mov     bl, byte[reg]
        mov     ecx, [val]
        call    pci_write_reg
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc srv_handler stdcall, ioctl:dword ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, [ioctl]
        test    esi, esi
        jz      .err

        mov     edi, [esi + ioctl_t.handle]
        cmp     [edi + service_t.magic], ' SRV'
        jne     .fail

        cmp     [edi + service_t.size], sizeof.service_t
        jne     .fail

        stdcall [edi + service_t.srv_proc], esi
        ret

  .fail:
        xor     eax, eax
        not     eax
        mov     [esi + ioctl_t.output.address], eax
        mov     [esi + ioctl_t.output.size], 4
        ret

  .err:
        xor     eax, eax
        not     eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc srv_handlerEx ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = io_control
;-----------------------------------------------------------------------------------------------------------------------
;< eax = error code
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, OS_BASE
        jae     .fail

        mov     eax, [ecx + ioctl_t.handle]
        cmp     [eax + service_t.magic], ' SRV'
        jne     .fail

        cmp     [eax + service_t.size], sizeof.service_t
        jne     .fail

        stdcall [eax + service_t.srv_proc], ecx
        ret

  .fail:
        or      eax, -1
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc get_service stdcall, sz_name:dword ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [sz_name]
        test    eax, eax
        jnz     @f
        ret

    @@: mov     edx, [srv.next_ptr]

    @@: cmp     edx, srv
        je      .not_load

        lea     eax, [edx + service_t.srv_name]
        stdcall strncmp, eax, [sz_name], 16
        test    eax, eax
        je      .ok

        mov     edx, [edx + service_t.next_ptr]
        jmp     @b

  .not_load:
        pop     ebp
        jmp     load_driver

  .ok:
        mov     eax, edx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc reg_service stdcall, name:dword, handler:dword ;///////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx

        xor     eax, eax

        cmp     [name], eax
        je      .fail

        cmp     [handler], eax
        je      .fail

        mov     eax, sizeof.service_t
        call    malloc
        test    eax, eax
        jz      .fail

        push    esi edi
        lea     edi, [eax + service_t.srv_name]
        mov     esi, [name]
        movsd
        movsd
        movsd
        movsd
        pop     edi esi

        mov     [eax + service_t.magic], ' SRV'
        mov     [eax + service_t.size], sizeof.service_t

        mov     ebx, srv
        mov     edx, [ebx + service_t.next_ptr]
        mov     [eax + service_t.next_ptr], edx
        mov     [eax + service_t.prev_ptr], ebx
        mov     [ebx + service_t.next_ptr], eax
        mov     [edx + service_t.prev_ptr], eax

        mov     ecx, [handler]
        mov     [eax + service_t.srv_proc], ecx
        pop     ebx
        ret

  .fail:
        xor     eax, eax
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc get_proc stdcall, exp:dword, sz_name:dword ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, [exp]

  .next:
        mov     eax, [edx]
        test    eax, eax
        jz      .end

        push    edx
        stdcall strncmp, eax, [sz_name], 16
        pop     edx
        test    eax, eax
        jz      .ok

        add     edx, 8
        jmp     .next

  .ok:
        mov     eax, [edx + 4]

  .end:
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc get_coff_sym stdcall, pSym:dword, count:dword, sz_sym:dword ;//////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
    @@: stdcall strncmp, [pSym], [sz_sym], 8
        test    eax, eax
        jz      .ok
        add     [pSym], 18
        dec     [count]
        jnz     @b
        xor     eax, eax
        ret

  .ok:
        mov     eax, [pSym]
        mov     eax, [eax + 8]
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc get_curr_task ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; FIXME: WTF? Exposing internal kernel structure it not a good idea
;       mov     eax, [current_slot]
;       shl     eax, 8
        xor     eax, eax
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc get_fileinfo stdcall, file_name:dword, info:dword ;////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  cmd     dd ?
  offset  dd ?
          dd ?
  count   dd ?
  buff    dd ?
          db ?
  name    dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        mov     ebx, [file_name]
        mov     ecx, [info]

        mov     [cmd], 5
        mov     [offset], eax
        mov     [offset + 4], eax
        mov     [count], eax
        mov     [buff], ecx
        mov     byte[buff + 4], al
        mov     [name], ebx

        mov     eax, 70
        lea     ebx, [cmd]
        int     0x40
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc read_file stdcall, file_name:dword, buffer:dword, off:dword, bytes:dword ;/////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  cmd     dd ?
  offset  dd ?
          dd ?
  count   dd ?
  buff    dd ?
          db ?
  name    dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        mov     ebx, [file_name]
        mov     ecx, [off]
        mov     edx, [bytes]
        mov     esi, [buffer]

        mov     [cmd], eax
        mov     [offset], ecx
        mov     [offset + 4], eax
        mov     [count], edx
        mov     [buff], esi
        mov     byte[buff + 4], al
        mov     [name], ebx

        pushad
        lea     ebx, [cmd]
        call    sysfn.file_system_lfn
        popad
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc load_file stdcall, file_name:dword ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? allocate kernel memory and loads the specified file
;-----------------------------------------------------------------------------------------------------------------------
;> [file_name] = full path to file
;-----------------------------------------------------------------------------------------------------------------------
;< eax = file image in kernel memory
;< ebx = size of file
;-----------------------------------------------------------------------------------------------------------------------
;# You mast call kernel_free() to delete each file loaded by the load_file() function
;-----------------------------------------------------------------------------------------------------------------------
locals
  attr      dd ?
  flags     dd ?
  cr_time   dd ?
  cr_date   dd ?
  acc_time  dd ?
  acc_date  dd ?
  mod_time  dd ?
  mod_date  dd ?
  file_size dd ?

  file      dd ?
  file2     dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        push    esi
        push    edi

        lea     eax, [attr]
        stdcall get_fileinfo, [file_name], eax
        test    eax, eax
        jnz     .fail

        mov     eax, [file_size]
        cmp     eax, 1024 * 1024 * 16
        ja      .fail

        stdcall kernel_alloc, [file_size]
        mov     [file], eax
        test    eax, eax
        jz      .fail

        stdcall read_file, [file_name], eax, 0, [file_size]
        cmp     ebx, [file_size]
        jne     .cleanup

        mov     eax, [file]
        cmp     dword[eax], 'KPCK'
        jne     .exit
        mov     ebx, [eax + 4]
        mov     [file_size], ebx
        stdcall kernel_alloc, ebx

        test    eax, eax
        jz      .cleanup

        mov     [file2], eax
        pushfd
        cli
        stdcall unpack, [file], eax
        popfd
        stdcall kernel_free, [file]
        mov     eax, [file2]
        mov     ebx, [file_size]

  .exit:
        push    eax
        lea     edi, [eax + ebx] ; cleanup remain space
        mov     ecx, 4096 ; from file end
        and     ebx, 4095
        jz      @f
        sub     ecx, ebx
        xor     eax, eax
        rep
        stosb

    @@: mov     ebx, [file_size]
        pop     eax
        pop     edi
        pop     esi
        ret

  .cleanup:
        stdcall kernel_free, [file]

  .fail:
        xor     eax, eax
        xor     ebx, ebx
        pop     edi
        pop     esi
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc get_proc_ex stdcall, proc_name:dword, imports:dword ;//////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
  .look_up:
        mov     edx, [imports]
        test    edx, edx
        jz      .end
        mov     edx, [edx]
        test    edx, edx
        jz      .end

  .next:
        mov     eax, [edx]
        test    eax, eax
        jz      .next_table

        push    edx
        stdcall strncmp, eax, [proc_name], 256
        pop     edx
        test    eax, eax
        jz      .ok

        add     edx, 8
        jmp     .next

  .next_table:
        add     [imports], 4
        jmp     .look_up

  .ok:
        mov     eax, [edx + 4]
        ret

  .end:
        xor     eax, eax
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc fix_coff_symbols stdcall uses ebx esi, sec:dword, symbols:dword, sym_count:dword, strings:dword, imports:dword ;///
;-----------------------------------------------------------------------------------------------------------------------
locals
  retval dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [symbols]
        mov     [retval], 1

  .fix:
        movzx   ebx, [edi + coff_sym_t.section_number]
        test    ebx, ebx
        jnz     .internal
        mov     eax, dword[edi + coff_sym_t.name]
        test    eax, eax
        jnz     @f

        mov     edi, [edi + 4]
        add     edi, [strings]

    @@: push    edi
        stdcall get_proc_ex, edi, [imports]
        pop     edi

        xor     ebx, ebx
        test    eax, eax
        jnz     @f

        KLog    LOG_ERROR, "unresolved %s\n", edi

        mov     [retval], 0

    @@: mov     edi, [symbols]
        mov     [edi + coff_sym_t.value], eax
        jmp     .next

  .internal:
        cmp     bx, -1
        je      .next
        cmp     bx, -2
        je      .next

        dec     ebx
        shl     ebx, 3
        lea     ebx, [ebx + ebx * 4]
        add     ebx, [sec]

        mov     eax, [ebx + coff_section_t.virtual_addr]
        add     [edi + coff_sym_t.value], eax

  .next:
        add     edi, sizeof.coff_sym_t
        mov     [symbols], edi
        dec     [sym_count]
        jnz     .fix
        mov     eax, [retval]
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc fix_coff_relocs stdcall uses ebx esi, coff:dword, sym:dword, delta:dword ;/////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  n_sec dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [coff]
        movzx   ebx, [eax + coff_header_t.sections_cnt]
        mov     [n_sec], ebx
        lea     esi, [eax + sizeof.coff_header_t]

  .fix_sec:
        mov     edi, [esi + coff_section_t.relocs_ptr]
        add     edi, [coff]

        movzx   ecx, [esi + coff_section_t.relocs_cnt]
        test    ecx, ecx
        jz      .next

  .reloc_loop:
        mov     ebx, [edi + coff_reloc_t.sym_index]
        add     ebx, ebx
        lea     ebx, [ebx + ebx * 8]
        add     ebx, [sym]

        mov     edx, [ebx + coff_sym_t.value]

        cmp     [edi + coff_reloc_t.type], 6
        je      .dir_32

        cmp     [edi + coff_reloc_t.type], 20
        jne     .next_reloc

  .rel_32:
        mov     eax, [edi + coff_reloc_t.virtual_addr]
        add     eax, [esi + coff_section_t.virtual_addr]
        sub     edx, eax
        sub     edx, 4
        jmp     .fix

  .dir_32:
        mov     eax, [edi + coff_reloc_t.virtual_addr]
        add     eax, [esi + coff_section_t.virtual_addr]

  .fix:
        add     eax, [delta]
        add     [eax], edx

  .next_reloc:
        add     edi, sizeof.coff_reloc_t
        dec     ecx
        jnz     .reloc_loop

  .next:
        add     esi, sizeof.coff_section_t
        dec     [n_sec]
        jnz     .fix_sec

  .exit:
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc rebase_coff stdcall uses ebx esi, coff:dword, sym:dword, delta:dword ;/////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  n_sec dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [coff]
        movzx   ebx, [eax + coff_header_t.sections_cnt]
        mov     [n_sec], ebx
        lea     esi, [eax + sizeof.coff_header_t]
        mov     edx, [delta]

  .fix_sec:
        mov     edi, [esi + coff_section_t.relocs_ptr]
        add     edi, [coff]

        movzx   ecx, [esi + coff_section_t.relocs_cnt]
        test    ecx, ecx
        jz      .next

  .reloc_loop:
        cmp     [edi + coff_reloc_t.type], 6
        jne     .next_reloc

  .dir_32:
        mov     eax, [edi + coff_reloc_t.virtual_addr]
        add     eax, [esi + coff_section_t.virtual_addr]
        add     [eax + edx], edx

  .next_reloc:
        add     edi, sizeof.coff_reloc_t
        dec     ecx
        jnz     .reloc_loop

  .next:
        add     esi, sizeof.coff_section_t
        dec     [n_sec]
        jnz     .fix_sec

  .exit:
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc load_driver stdcall, driver_name:dword ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  coff      dd ?
  sym       dd ?
  strings   dd ?
  img_size  dd ?
  img_base  dd ?
  start     dd ?

  exports   dd ? ; fake exports table
            dd ?
  file_name rb 13 + 16 + 4 + 1 ; '/sys/drivers/<up-to-16-chars>.obj'
endl
;-----------------------------------------------------------------------------------------------------------------------
        lea     edx, [file_name]
        mov     dword[edx], '/sys'
        mov     dword[edx + 4], '/dri'
        mov     dword[edx + 8], 'vers'
        mov     byte[edx + 12], '/'
        mov     esi, [driver_name]

  .redo:
        lea     edx, [file_name]
        lea     edi, [edx + 13]
        mov     ecx, 16

    @@: lodsb
        test    al, al
        jz      @f
        stosb
        loop    @b

    @@: mov     dword[edi], '.obj'
        mov     byte[edi + 4], 0
        stdcall load_file, edx

        test    eax, eax
        jz      .exit

        mov     [coff], eax

        movzx   ecx, [eax + coff_header_t.sections_cnt]
        xor     ebx, ebx

        lea     edx, [eax + sizeof.coff_header_t]

    @@: add     ebx, [edx + coff_section_t.raw_data_size]
        add     ebx, 15
        and     ebx, not 15
        add     edx, sizeof.coff_section_t
        dec     ecx
        jnz     @b
        mov     [img_size], ebx

        stdcall kernel_alloc, ebx
        test    eax, eax
        jz      .fail
        mov     [img_base], eax

        mov     edi, eax
        xor     eax, eax
        mov     ecx, [img_size]
        add     ecx, 4095
        and     ecx, not 4095
        shr     ecx, 2
        rep
        stosd

        mov     edx, [coff]
        movzx   ebx, [edx + coff_header_t.sections_cnt]
        mov     edi, [img_base]
        lea     eax, [edx + sizeof.coff_header_t]

    @@: mov     [eax + coff_section_t.virtual_addr], edi
        mov     esi, [eax + coff_section_t.raw_data_ptr]
        test    esi, esi
        jnz     .copy
        add     edi, [eax + coff_section_t.raw_data_size]
        jmp     .next

  .copy:
        add     esi, edx
        mov     ecx, [eax + coff_section_t.raw_data_size]
        rep
        movsb

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

        lea     ebx, [exports]
        mov     dword[ebx], kernel_export
        mov     dword[ebx + 4], 0
        lea     eax, [edx + sizeof.coff_header_t]

        stdcall fix_coff_symbols, eax, [sym], [edx + coff_header_t.syms_cnt], [strings], ebx
        test    eax, eax
        jz      .link_fail

        mov     ebx, [coff]
        stdcall fix_coff_relocs, ebx, [sym], 0

        stdcall get_coff_sym, [sym], [ebx + coff_header_t.syms_cnt], szVersion
        test    eax, eax
        jz      .link_fail

        mov     eax, [eax]
        shr     eax, 16
        cmp     eax, DRV_COMPAT
        jb      .ver_fail

        cmp     eax, DRV_CURRENT
        ja      .ver_fail

        mov     ebx, [coff]
        stdcall get_coff_sym, [sym], [ebx + coff_header_t.syms_cnt], szSTART
        mov     [start], eax

        stdcall kernel_free, [coff]

        mov     ebx, [start]
        stdcall ebx, DRV_ENTRY
        test    eax, eax
        jnz     .ok

        stdcall kernel_free, [img_base]
        cmp     dword[file_name + 13], 'SOUN'
        jnz     @f
        cmp     dword[file_name + 17], 'D.ob'
        jnz     @f
        cmp     word[file_name + 21], 'j'
        jnz     @f
        mov     esi, aSis
        jmp     .redo

    @@: xor     eax, eax
        ret

  .ok:
        mov     ebx, [img_base]
        mov     [eax + service_t.base], ebx
        mov     ecx, [start]
        mov     [eax + service_t.entry], ecx
        ret

  .ver_fail:
        KLog    LOG_ERROR, "incompatible driver version: %s\n", [driver_name]
        jmp     .cleanup

  .link_fail:
        KLog    LOG_ERROR, "in module %s\n", [driver_name]

  .cleanup:
        stdcall kernel_free, [img_base]

  .fail:
        stdcall kernel_free, [coff]

  .exit:
        xor     eax, eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc coff_get_align ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edx = pointer to coff_section_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax = alignment as mask for bits to drop
;-----------------------------------------------------------------------------------------------------------------------
;# Rules:
;#   * if alignment is not given, use default = 4K
;#   * if alignment is given and is no more than 4K, use it
;#   * if alignment is more than 4K, revert to 4K
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     cl, byte[edx + coff_section_t.characteristics + 2]
        mov     eax, 1
        shr     cl, 4
        dec     cl
        js      .default
        cmp     cl, 12
        jbe     @f

  .default:
        mov     cl, 12

    @@: shl     eax, cl
        pop     ecx
        dec     eax
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc load_library stdcall, file_name:dword ;////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  fullname rb 260
  fileinfo fs.file_info_t
  coff     dd ?
  img_base dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        cli

        ; resolve file name
        mov     ebx, [file_name]
        lea     edi, [fullname + 1]
        mov     byte[edi - 1], '/'
        stdcall get_full_file_name, edi, 259
        test    al, al
        jz      .fail

        ; scan for required DLL in list of already loaded for this process,
        ; ignore timestamp
        mov     esi, [current_slot]
        shl     esi, 9 ; * sizeof.legacy.slot_t
        lea     edi, [fullname]
        mov     ebx, [legacy_slots + esi + legacy.slot_t.app.dlls_list_ptr]
        test    ebx, ebx
        jz      .not_in_process
        mov     esi, [ebx + dll_handle_t.next_ptr]

  .scan_in_process:
        cmp     esi, ebx
        jz      .not_in_process
        mov     eax, [esi + dll_handle_t.parent]
        add     eax, dll_descriptor_t.name
        stdcall strncmp, eax, edi, -1
        test    eax, eax
        jnz     .next_in_process
        ; simple variant: load DLL which is already loaded in this process
        ; just increment reference counters and return address of exports table
        inc     [esi + dll_handle_t.refcount]
        mov     ecx, [esi + dll_handle_t.parent]
        inc     [ecx + dll_descriptor_t.refcount]
        mov     eax, [ecx + dll_descriptor_t.exports]
        sub     eax, [ecx + dll_descriptor_t.defaultbase]
        add     eax, [esi + dll_handle_t.range.address]
        ret

  .next_in_process:
        mov     esi, [esi + dll_handle_t.next_ptr]
        jmp     .scan_in_process

  .not_in_process:
        ; scan in full list, compare timestamp
        lea     eax, [fileinfo]
        stdcall get_fileinfo, edi, eax
        test    eax, eax
        jnz     .fail
        mov     esi, [dll_list.next_ptr]

  .scan_for_dlls:
        cmp     esi, dll_list
        jz      .load_new
        lea     eax, [esi + dll_descriptor_t.name]
        stdcall strncmp, eax, edi, -1
        test    eax, eax
        jnz     .continue_scan

  .test_prev_dll:
        mov     eax, [fileinfo.modified_at.time] ; last modified time
        mov     edx, [fileinfo.modified_at.date] ; last modified date
        cmp     dword[esi + dll_descriptor_t.timestamp], eax
        jnz     .continue_scan
        cmp     dword[esi + dll_descriptor_t.timestamp + 4], edx
        jz      .dll_already_loaded

  .continue_scan:
        mov     esi, [esi + dll_descriptor_t.next_ptr]
        jmp     .scan_for_dlls

        ; new DLL
  .load_new:
        ; load file
        stdcall load_file, edi
        test    eax, eax
        jz      .fail
        mov     [coff], eax
        mov     [fileinfo.size.low], ebx

        ; allocate dll_descriptor_t struct; size is sizeof.dll_descriptor_t plus size of DLL name
        mov     esi, edi
        mov     ecx, -1
        xor     eax, eax
        repnz
        scasb
        not     ecx
        lea     eax, [ecx + sizeof.dll_descriptor_t]
        push    ecx
        call    malloc
        pop     ecx
        test    eax, eax
        jz      .fail_and_free_coff
        ; save timestamp
        lea     edi, [eax + dll_descriptor_t.name]
        rep
        movsb
        mov     esi, eax
        mov     eax, [fileinfo.modified_at.time]
        mov     dword[esi + dll_descriptor_t.timestamp], eax
        mov     eax, [fileinfo.modified_at.date]
        mov     dword[esi + dll_descriptor_t.timestamp + 4], eax
        ; initialize dll_descriptor_t struct
        and     [esi + dll_descriptor_t.refcount], 0 ; no dll_handle_t-s yet; later it will be incremented
        mov     [esi + dll_descriptor_t.next_ptr], dll_list
        mov     eax, [dll_list.prev_ptr]
        mov     [dll_list.prev_ptr], esi
        mov     [esi + dll_descriptor_t.prev_ptr], eax
        mov     [eax + dll_descriptor_t.next_ptr], esi

        ; calculate size of loaded DLL
        mov     edx, [coff]
        movzx   ecx, [edx + coff_header_t.sections_cnt]
        xor     ebx, ebx

        add     edx, sizeof.coff_header_t

    @@: call    coff_get_align
        add     ebx, eax
        not     eax
        and     ebx, eax
        add     ebx, [edx + coff_section_t.raw_data_size]
        add     edx, sizeof.coff_section_t
        dec     ecx
        jnz     @b
        ; it must be nonzero and not too big
        mov     [esi + dll_descriptor_t.data.size], ebx
        test    ebx, ebx
        jz      .fail_and_free_dll
        cmp     ebx, MAX_DEFAULT_DLL_ADDR - MIN_DEFAULT_DLL_ADDR
        ja      .fail_and_free_dll
        ; allocate memory for kernel-side image
        stdcall kernel_alloc, ebx
        test    eax, eax
        jz      .fail_and_free_dll
        mov     [esi + dll_descriptor_t.data.address], eax
        ; calculate preferred base address
        add     ebx, 0x1fff
        and     ebx, not 0x0fff
        mov     ecx, [dll_cur_addr]
        lea     edx, [ecx + ebx]
        cmp     edx, MAX_DEFAULT_DLL_ADDR
        jb      @f
        mov     ecx, MIN_DEFAULT_DLL_ADDR
        lea     edx, [ecx + ebx]

    @@: mov     [esi + dll_descriptor_t.defaultbase], ecx
        mov     [dll_cur_addr], edx

        ; copy sections and set correct values for VirtualAddress'es in headers
        push    esi
        mov     edx, [coff]
        movzx   ebx, [edx + coff_header_t.sections_cnt]
        mov     edi, eax
        add     edx, sizeof.coff_header_t

    @@: call    coff_get_align
        add     ecx, eax
        add     edi, eax
        not     eax
        and     ecx, eax
        and     edi, eax
        mov     [edx + coff_section_t.virtual_addr], ecx
        add     ecx, [edx + coff_section_t.raw_data_size]
        mov     esi, [edx + coff_section_t.raw_data_ptr]
        push    ecx
        mov     ecx, [edx + coff_section_t.raw_data_size]
        test    esi, esi
        jnz     .copy
        xor     eax, eax
        rep
        stosb
        jmp     .next

  .copy:
        add     esi, [coff]
        rep
        movsb

  .next:
        pop     ecx
        add     edx, sizeof.coff_section_t
        dec     ebx
        jnz     @b
        pop     esi

        ; save some additional data from COFF file
        ; later we will use COFF header, headers for sections and symbol table
        ; and also relocations table for all sections
        mov     edx, [coff]
        mov     ebx, [edx + coff_header_t.syms_ptr]
        mov     edi, [fileinfo.size.low]
        sub     edi, ebx
        jc      .fail_and_free_data
        mov     [esi + dll_descriptor_t.symbols_lim], edi
        add     ebx, edx
        movzx   ecx, [edx + coff_header_t.sections_cnt]
        lea     ecx, [ecx * 5]
        lea     edi, [edi + ecx * 8 + 20]
        add     edx, sizeof.coff_header_t

    @@: movzx   eax, [edx + coff_section_t.relocs_cnt]
        lea     eax, [eax * 5]
        lea     edi, [edi + eax * 2]
        add     edx, sizeof.coff_section_t
        sub     ecx, 5
        jnz     @b
        stdcall kernel_alloc, edi
        test    eax, eax
        jz      .fail_and_free_data
        mov     edx, [coff]
        movzx   ecx, [edx + coff_header_t.sections_cnt]
        lea     ecx, [ecx * 5]
        lea     ecx, [ecx * 2 + 5]
        mov     [esi + dll_descriptor_t.coff_hdr], eax
        push    esi
        mov     esi, edx
        mov     edi, eax
        rep
        movsd
        pop     esi
        mov     [esi + dll_descriptor_t.symbols_ptr], edi
        push    esi
        mov     ecx, [edx + coff_header_t.syms_cnt]
        mov     [esi + dll_descriptor_t.symbols_num], ecx
        mov     ecx, [esi + dll_descriptor_t.symbols_lim]
        mov     esi, ebx
        rep
        movsb
        pop     esi
        mov     ebx, [esi + dll_descriptor_t.coff_hdr]
        push    esi
        movzx   eax, [edx + coff_header_t.sections_cnt]
        lea     edx, [ebx + 20]

    @@: movzx   ecx, [edx + coff_section_t.relocs_cnt]
        lea     ecx, [ecx * 5]
        mov     esi, [edx + coff_section_t.relocs_ptr]
        mov     [edx + coff_section_t.relocs_ptr], edi
        sub     [edx + coff_section_t.relocs_ptr], ebx
        add     esi, [coff]
        shr     ecx, 1
        rep
        movsd
        adc     ecx, ecx
        rep
        movsw
        add     edx, sizeof.coff_section_t
        dec     eax
        jnz     @b
        pop     esi

        ; fixup symbols
        mov     edx, ebx
        mov     eax, [ebx + coff_header_t.syms_cnt]
        add     edx, sizeof.coff_header_t
        mov     ecx, [esi + dll_descriptor_t.symbols_num]
        lea     ecx, [ecx * 9]
        add     ecx, ecx
        add     ecx, [esi + dll_descriptor_t.symbols_ptr]

        stdcall fix_coff_symbols, edx, [esi + dll_descriptor_t.symbols_ptr], eax, ecx, 0
;       test    eax, eax
;       jnz     @f
;
;   @@:

        stdcall get_coff_sym, [esi + dll_descriptor_t.symbols_ptr], [ebx + coff_header_t.syms_cnt], szEXPORTS
        test    eax, eax
        jnz     @f

        stdcall get_coff_sym, [esi + dll_descriptor_t.symbols_ptr], [ebx + coff_header_t.syms_cnt], sz_EXPORTS

    @@: mov     [esi + dll_descriptor_t.exports], eax

        ; fix relocs in the hidden copy in kernel memory to default address
        ; it is first fix; usually this will be enough, but second fix
        ; can be necessary if real load address will not equal assumption
        mov     eax, [esi + dll_descriptor_t.data.address]
        sub     eax, [esi + dll_descriptor_t.defaultbase]
        stdcall fix_coff_relocs, ebx, [esi + dll_descriptor_t.symbols_ptr], eax

        stdcall kernel_free, [coff]

  .dll_already_loaded:
        inc     [esi + dll_descriptor_t.refcount]
        push    esi
        call    init_heap
        pop     esi

        mov     edi, [esi + dll_descriptor_t.data.size]
        stdcall user_alloc_at, [esi + dll_descriptor_t.defaultbase], edi
        test    eax, eax
        jnz     @f
        stdcall user_alloc, edi
        test    eax, eax
        jz      .fail_and_dereference

    @@: mov     [img_base], eax
        mov     eax, sizeof.dll_handle_t
        call    malloc
        test    eax, eax
        jz      .fail_and_free_user
        mov     ebx, [current_slot]
        shl     ebx, 9 ; * sizeof.legacy.slot_t
        mov     edx, [legacy_slots + ebx + legacy.slot_t.task.pid]
        mov     [eax + dll_handle_t.pid], edx
        push    eax
        call    init_dlls_in_thread
        pop     ebx
        test    eax, eax
        jz      .fail_and_free_user
        mov     edx, [eax + dll_handle_t.next_ptr]
        mov     [ebx + dll_handle_t.next_ptr], edx
        mov     [ebx + dll_handle_t.prev_ptr], eax
        mov     [eax + dll_handle_t.next_ptr], ebx
        mov     [edx + dll_handle_t.prev_ptr], ebx
        mov     eax, ebx
        mov     ebx, [img_base]
        mov     [eax + dll_handle_t.range.address], ebx
        mov     [eax + dll_handle_t.range.size], edi
        mov     [eax + dll_handle_t.refcount], 1
        mov     [eax + dll_handle_t.parent], esi
        mov     edx, ebx
        shr     edx, 12
        or      dword[page_tabs + (edx - 1) * 4], DONT_FREE_BLOCK
        ; copy entries of page table from kernel-side image to usermode
        ; use copy-on-write for user-mode image, so map as readonly
        xor     edi, edi
        mov     ecx, [esi + dll_descriptor_t.data.address]
        shr     ecx, 12

  .map_pages_loop:
        mov     eax, [page_tabs + ecx * 4]
        and     eax, not 0x0fff
        or      al, PG_USER
        xchg    eax, [page_tabs + edx * 4]
        test    al, 1
        jz      @f
        call    free_page

    @@: invlpg  [ebx + edi]
        inc     ecx
        inc     edx
        add     edi, 0x1000
        cmp     edi, [esi + dll_descriptor_t.data.size]
        jb      .map_pages_loop

        ; if real user-mode base is not equal to preferred base, relocate image
        sub     ebx, [esi + dll_descriptor_t.defaultbase]
        jz      @f
        stdcall rebase_coff, [esi + dll_descriptor_t.coff_hdr], [esi + dll_descriptor_t.symbols_ptr], ebx

    @@: mov     eax, [esi + dll_descriptor_t.exports]
        sub     eax, [esi + dll_descriptor_t.defaultbase]
        add     eax, [img_base]
        ret

  .fail_and_free_data:
        stdcall kernel_free, [esi + dll_descriptor_t.data.address]

  .fail_and_free_dll:
        mov     eax, esi
        call    free

  .fail_and_free_coff:
        stdcall kernel_free, [coff]

  .fail:
        xor     eax, eax
        ret

  .fail_and_free_user:
        stdcall user_free, [img_base]

  .fail_and_dereference:
        mov     eax, 1 ; delete 1 reference
        call    dereference_dll
        xor     eax, eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc init_dlls_in_thread ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? initialize [legacy.slot_t.app.dlls_list_ptr] for given thread
;-----------------------------------------------------------------------------------------------------------------------
;< eax = legacy.slot_t.app.dlls_list_ptr if all is OK, NULL if memory allocation failed
;-----------------------------------------------------------------------------------------------------------------------
;# DLL is per-process object, so legacy.slot_t.app.dlls_list_ptr must be kept in sync for all threads of one process.
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [current_slot_ptr]
        mov     eax, [ebx + legacy.slot_t.app.dlls_list_ptr]
        test    eax, eax
        jnz     .ret
        push    [ebx + legacy.slot_t.app.dir_table]
        mov     eax, 8
        call    malloc
        pop     edx
        test    eax, eax
        jz      .ret
        mov     [eax], eax
        mov     [eax + 4], eax
        mov     ecx, [legacy_slots.last_valid_slot]
        mov     ebx, legacy_os_idle_slot

  .set:
        cmp     [ebx + legacy.slot_t.app.dir_table], edx
        jnz     @f
        mov     [ebx + legacy.slot_t.app.dlls_list_ptr], eax

    @@: add     ebx, sizeof.legacy.slot_t
        dec     ecx
        jnz     .set

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc dereference_dll ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = number of references to delete
;> esi = pointer to dll_descriptor_t
;-----------------------------------------------------------------------------------------------------------------------
        sub     [esi + dll_descriptor_t.refcount], eax
        jnz     .ret
        mov     eax, [esi + dll_descriptor_t.next_ptr]
        mov     edx, [esi + dll_descriptor_t.prev_ptr]
        mov     [eax + dll_descriptor_t.prev_ptr], edx
        mov     [edx + dll_descriptor_t.next_ptr], eax
        stdcall kernel_free, [esi + dll_descriptor_t.coff_hdr]
        stdcall kernel_free, [esi + dll_descriptor_t.data.address]
        mov     eax, esi
        call    free

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc destroy_hdll ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx esi edi
        push    eax
        mov     ebx, [eax + dll_handle_t.range.address]
        mov     esi, [eax + dll_handle_t.parent]
        mov     edx, [esi + dll_descriptor_t.data.size]
        ; The following actions require the context of application where dll_handle_t is mapped.
        ; However, destroy_hdll can be called in the context of OS thread when
        ; cleaning up objects created by the application which is destroyed.
        ; So remember current cr3 and set it to page table of target.
        mov     eax, [ecx + legacy.slot_t.app.dir_table]
        ; Because we cheat with cr3, disable interrupts: task switch would restore
        ; page table from legacy.slot_t of current thread.
        ; Also set [current_slot_ptr] because it is used by user_free.
        pushf
        cli
        push    [current_slot_ptr]
        mov     [current_slot_ptr], ecx
        mov     ecx, cr3
        push    ecx
        mov     cr3, eax
        push    ebx ; argument for user_free
        mov     eax, ebx
        shr     ebx, 12
        push    ebx
        mov     esi, [esi + dll_descriptor_t.data.address]
        shr     esi, 12

  .unmap_loop:
        push    eax
        mov     eax, 2
        xchg    eax, [page_tabs + ebx * 4]
        mov     ecx, [page_tabs + esi * 4]
        and     eax, not 0x0fff
        and     ecx, not 0x0fff
        cmp     eax, ecx
        jz      @f
        call    free_page

    @@: pop     eax
        invlpg  [eax]
        add     eax, 0x1000
        inc     ebx
        inc     esi
        sub     edx, 0x1000
        ja      .unmap_loop
        pop     ebx
        and     dword[page_tabs + (ebx - 1) * 4], not DONT_FREE_BLOCK
        call    user_free
        ; Restore context.
        pop     eax
        mov     cr3, eax
        pop     [current_slot_ptr]
        popf
        ; Ok, cheating is done.
        pop     eax
        push    eax
        mov     esi, [eax + dll_handle_t.parent]
        mov     eax, [eax + dll_handle_t.refcount]
        call    dereference_dll
        pop     eax
        mov     edx, [eax + dll_handle_t.prev_ptr]
        mov     ebx, [eax + dll_handle_t.next_ptr]
        mov     [ebx + dll_handle_t.prev_ptr], edx
        mov     [edx + dll_handle_t.next_ptr], ebx
        call    free
        pop     edi esi ecx ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc destroy_all_hdlls ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = pointer to legacy.slot_t for slot
;> esi = dlls_list_ptr
;-----------------------------------------------------------------------------------------------------------------------
        test    esi, esi
        jz      .ret

  .loop:
        mov     eax, [esi + dll_handle_t.next_ptr]
        cmp     eax, esi
        jz      free
        call    destroy_hdll
        jmp     .loop

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc stop_all_services ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp
        mov     edx, [srv.next_ptr]

  .next:
        cmp     edx, srv
        je      .done
        cmp     [edx + service_t.magic], ' SRV'
        jne     .next
        cmp     [edx + service_t.size], sizeof.service_t
        jne     .next

        mov     ebx, [edx + service_t.entry]
        mov     edx, [edx + service_t.next_ptr]
        test    ebx, ebx
        jz      .next

        push    edx
        mov     ebp, esp
        push    0
        push    -1
        call    ebx
        mov     esp, ebp
        pop     edx
        jmp     .next

  .done:
        pop     ebp
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc create_kernel_object ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = size
;> ebx = PID
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        call    malloc
        pop     ebx
        test    eax, eax
        jz      .fail

        mov     ecx, [current_slot_ptr]
        add     ecx, legacy.slot_t.app.obj

        pushfd
        cli
        mov     edx, [ecx + app_object_t.next_ptr]
        mov     [eax + app_object_t.next_ptr], edx
        mov     [eax + app_object_t.prev_ptr], ecx
        mov     [eax + app_object_t.pid], ebx

        mov     [ecx + app_object_t.next_ptr], eax
        mov     [edx + app_object_t.prev_ptr], eax
        popfd

  .fail:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc destroy_kernel_object ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = object
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli
        mov     ebx, [eax + app_object_t.next_ptr]
        mov     ecx, [eax + app_object_t.prev_ptr]
        mov     [ebx + app_object_t.prev_ptr], ecx
        mov     [ecx + app_object_t.next_ptr], ebx
        popfd

        xor     edx, edx ; clear common header
        mov     [eax + app_object_t.prev_ptr], edx
        mov     [eax + app_object_t.next_ptr], edx
        mov     [eax + app_object_t.magic], edx
        mov     [eax + app_object_t.destroy], edx
        mov     [eax + app_object_t.pid], edx

        call    free ; release object memory
        ret
kendp
