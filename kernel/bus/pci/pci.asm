;;======================================================================================================================
;;///// pci.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
;; (c) 2002 MenuetOS <http://menuetos.net/>
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

;mmio_pci_addr = 0x400 ; set actual PCI address here to activate user-MMIO

uglobal
  align 4
  pci_access_enabled rd 1 ; 0 = disabled , 1 = enabled
  pci_bios_entry     dd 0
                     dw pci_code_sel
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62: entry point for system PCI calls
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.pci_ctl, subfn, sysfn.not_implemented, \
    get_version, \ ; 0
    get_last_bus, \ ; 1
    get_access_mode, \ ; 2
    -, \
    read_register, \ ; 4
    read_register, \ ; 5
    read_register, \ ; 6
    -, \
    write_register, \ ; 8
    write_register, \ ; 9
    write_register, \ ; 10
    defined mmio_pci_addr ? mmio_init, \ ; 11
    defined mmio_pci_addr ? mmio_map, \ ; 12
    defined mmio_pci_addr ? mmio_unmap ; 13
endg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     bl, .countof.subfn
        jae     sysfn.not_implemented

        cmp     [pci_access_enabled], 0
        je      .error

        movzx   edx, bl
        jmp     [.subfn + edx * 4]

  .error:
        or      [esp + 4 + regs_context32_t.eax], -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pci_api_drv ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, 2
        ja      .fail

        cmp     [pci_access_enabled], 0
        je      .fail

        pusha
        call    [sysfn.pci_ctl.subfn + eax * 4]
        popa
        ret

  .fail:
        or      eax, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl.get_version ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62.0: get PCI version (AH.AL)
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, word[BOOT_VAR + BOOT_PCI_DATA + 2]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl.get_last_bus ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62.1: get last PCI bus in AL
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [BOOT_VAR + BOOT_PCI_DATA + 1]
        mov     [esp + 4 + regs_context32_t.al], al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl.get_access_mode ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62.2: get PCI access mechanism
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [BOOT_VAR + BOOT_PCI_DATA]
        mov     [esp + 4 + regs_context32_t.al], al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pci_service_not_supported ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        or      eax, -1
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pci_make_config_cmd ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; creates a command dword  for use with the PCI bus
        ; bus # in ah
        ; device+func in bh (dddddfff)
        ; register in bl
        ;
        ; command dword returned in eax ( 10000000 bbbbbbbb dddddfff rrrrrr00 )

        shl     eax, 8 ; move bus to bits 16-23
        mov     ax, bx ; combine all
        and     eax, 0x00ffffff
        or      eax, 0x80000000
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl.read_register ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62.4, 62.5, 62.6: read byte/word/dword from PCI register
;-----------------------------------------------------------------------------------------------------------------------
        ; cross
        mov     eax, ebx
        mov     ebx, ecx

        and     al, 0x03
        call    pci_read_reg

        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pci_read_reg ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? read a register from the PCI config space
;-----------------------------------------------------------------------------------------------------------------------
;> al = number of bytes to read (0 - byte, 1 - word, 2 - dword)
;> ah = bus
;> bh = device + func
;> bl = register address
;-----------------------------------------------------------------------------------------------------------------------
;< eax/ax/al = value read
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [BOOT_VAR + BOOT_PCI_DATA], 2 ; what mechanism will we use?
        je      .pci_read_reg_2

        ; mechanism 1
        push    esi ; save register size into ESI
        mov     esi, eax
        and     esi, 3

        call    pci_make_config_cmd
        mov     ebx, eax
        ; get current state
        mov     dx, 0x0cf8
        in      eax, dx
        push    eax

        ; set up addressing to config data
        mov     eax, ebx
        and     al, 0xfc ; make address dword-aligned
        out     dx, eax

        ; get requested DWORD of config data
        mov     dl, 0xfc
        and     bl, 3
        or      dl, bl ; add to port address first 2 bits of register address

        or      esi, esi
        jz      .pci_read_byte1
        cmp     esi, 1
        jz      .pci_read_word1
        cmp     esi, 2
        jz      .pci_read_dword1
        jmp     .pci_fin_read1

  .pci_read_byte1:
        in      al, dx
        jmp     .pci_fin_read1

  .pci_read_word1:
        in      ax, dx
        jmp     .pci_fin_read1

  .pci_read_dword1:
        in      eax, dx
        jmp     .pci_fin_read1

  .pci_fin_read1:
        ; restore configuration control
        xchg    eax, [esp]
        mov     dx, 0x0cf8
        out     dx, eax

        pop     eax
        pop     esi
        ret

  .pci_read_reg_2:
        ; mech#2 only supports 16 devices per bus
        test    bh, 128
        jnz     .pci_read_reg_err

        push    esi ; save register size into ESI
        mov     esi, eax
        and     esi, 3

        push    eax

        ; store current state of config space
        mov     dx, 0x0cf8
        in      al, dx
        mov     ah, al
        mov     dl, 0xfa
        in      al, dx

        xchg    eax, [esp]
        ; out 0x0cfa, bus
        mov     al, ah
        out     dx, al
        ; out 0x0cf8, 0x80
        mov     dl, 0xf8
        mov     al, 0x80
        out     dx, al

        ; compute addr
        shr     bh, 3 ; func is ignored in mechanism 2
        or      bh, 0xc0
        mov     dx, bx

        or      esi, esi
        jz      .pci_read_byte2
        cmp     esi, 1
        jz      .pci_read_word2
        cmp     esi, 2
        jz      .pci_read_dword2
        jmp     .pci_fin_read2

  .pci_read_byte2:
        in      al, dx
        jmp     .pci_fin_read2

  .pci_read_word2:
        in      ax, dx
        jmp     .pci_fin_read2

  .pci_read_dword2:
        in      eax, dx
;       jmp     pci_fin_read2

  .pci_fin_read2:
        ; restore configuration space
        xchg    eax, [esp]
        mov     dx, 0x0cfa
        out     dx, al
        mov     dl, 0xf8
        mov     al, ah
        out     dx, al

        pop     eax
        pop     esi
        ret

  .pci_read_reg_err:
        xor     eax, eax
        dec     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl.write_register ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62.8, 62.9, 62.10: write byte/word/dword to PCI register
;-----------------------------------------------------------------------------------------------------------------------
        ; cross
        mov     eax, ebx
        mov     ebx, ecx
        mov     ecx, edx

        and     al, 0x03
        call    pci_write_reg

        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pci_write_reg ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? write a register into the PCI config space
;-----------------------------------------------------------------------------------------------------------------------
;> al = number of bytes to write (0 - byte, 1 - word, 2 - dword)
;> ah = bus
;> bh = device + func
;> bl = register address (dword aligned)
;> ecx/cx/cl = value to write
;-----------------------------------------------------------------------------------------------------------------------

        cmp     [BOOT_VAR + BOOT_PCI_DATA], 2 ; what mechanism will we use?
        je      .pci_write_reg_2

        ; mechanism 1
        push    esi ; save register size into ESI
        mov     esi, eax
        and     esi, 3

        call    pci_make_config_cmd
        mov     ebx, eax
        ; get current state into ecx
        mov     dx, 0x0cf8
        in      eax, dx
        push    eax
        ; set up addressing to config data
        mov     eax, ebx
        and     al, 0xfc ; make address dword-aligned
        out     dx, eax
        ; write DWORD of config data
        mov     dl, 0xfc
        and     bl, 3
        or      dl, bl
        mov     eax, ecx

        or      esi, esi
        jz      .pci_write_byte1
        cmp     esi, 1
        jz      .pci_write_word1
        cmp     esi, 2
        jz      .pci_write_dword1
        jmp     .pci_fin_write1

  .pci_write_byte1:
        out     dx, al
        jmp     .pci_fin_write1

  .pci_write_word1:
        out     dx, ax
        jmp     .pci_fin_write1

  .pci_write_dword1:
        out     dx, eax
;       jmp     .pci_fin_write1

  .pci_fin_write1:
        ; restore configuration control
        pop     eax
        mov     dl, 0xf8
        out     dx, eax

        xor     eax, eax
        pop     esi

        ret

  .pci_write_reg_2:
        ; mech#2 only supports 16 devices per bus
        test    bh, 128
        jnz     .pci_write_reg_err


        push    esi ; save register size into ESI
        mov     esi, eax
        and     esi, 3

        push    eax
        ; store current state of config space
        mov     dx, 0x0cf8
        in      al, dx
        mov     ah, al
        mov     dl, 0xfa
        in      al, dx
        xchg    eax, [esp]
        ; out 0x0cfa, bus
        mov     al, ah
        out     dx, al
        ; out 0x0cf8,0x80
        mov     dl, 0xf8
        mov     al, 0x80
        out     dx, al
        ; compute addr
        shr     bh, 3 ; func is ignored in mechanism 2
        or      bh, 0xc0
        mov     dx, bx
        ; write register
        mov     eax, ecx

        or      esi, esi
        jz      .pci_write_byte2
        cmp     esi, 1
        jz      .pci_write_word2
        cmp     esi, 2
        jz      .pci_write_dword2
        jmp     .pci_fin_write2

  .pci_write_byte2:
        out     dx, al
        jmp     .pci_fin_write2

  .pci_write_word2:
        out     dx, ax
        jmp     .pci_fin_write2

  .pci_write_dword2:
        out     dx, eax
        jmp     .pci_fin_write2

  .pci_fin_write2:
        ; restore configuration space
        pop     eax
        mov     dx, 0x0cfa
        out     dx, al
        mov     dl, 0xf8
        mov     al, ah
        out     dx, al

        xor     eax, eax
        pop     esi
        ret

  .pci_write_reg_err:
        xor     eax, eax
        dec     eax
        ret
kendp

if defined mmio_pci_addr ; must be set above

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl.mmio_init ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62.11: initialize PCI MMIO
;-----------------------------------------------------------------------------------------------------------------------
;> bx = device's PCI bus address (bbbbbbbbdddddfff)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = user heap space available (bytes) or error code
;-----------------------------------------------------------------------------------------------------------------------
;# Error codes:
;#   -1 - PCI user access blocked
;#   -2 - device not registered for uMMIO service
;#   -3 - user heap initialization failure
;-----------------------------------------------------------------------------------------------------------------------
        ; cross
        mov     ebx, ecx

        cmp     bx, mmio_pci_addr
        je      @f
        mov     eax, -2
        jmp     .exit

    @@: call    init_heap ; (if not initialized yet)
        or      eax, eax
        jnz     .exit

        mov     eax, -3

  .exit:
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl.mmio_map ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62.12: map PCI memory block to user-accessible linear address
;-----------------------------------------------------------------------------------------------------------------------
;> ah = BAR#
;> ebx = block size (bytes)
;> ecx = offset in MMIO block (in 4K-pages, to avoid misaligned pages)
;> [mmio_pci_addr] = target device address
;-----------------------------------------------------------------------------------------------------------------------
;< eax = MMIO block's linear address in the userspace or error code
;-----------------------------------------------------------------------------------------------------------------------
;# WARNING! This VERY EXPERIMENTAL service is for one chosen PCI device only!
;# Error codes:
;#   -1 - user access to PCI blocked
;#   -2 - an invalid BAR register referred
;#   -3 - no i/o space on that BAR
;#   -4 - a port i/o BAR register referred
;#   -5 - dynamic userspace allocation problem
;-----------------------------------------------------------------------------------------------------------------------
        ; cross
        mov     eax, ebx
        mov     ebx, ecx
        mov     ecx, edx

        and     edx, 0x0000ffff
        cmp     ah, 6
        jc      .bar_0_5
        jz      .bar_rom
        mov     eax, -2
        jmp     .exit

  .bar_rom:
        mov     ah, 8 ; bar6 = Expansion ROM base address

  .bar_0_5:
        push    ecx
        add     ebx, 4095
        and     ebx, -4096
        push    ebx
        mov     bl, ah ; bl = BAR# (0..5), however bl=8 for BAR6
        shl     bl, 1
        shl     bl, 1
        add     bl, 0x10 ; now bl = BAR offset in PCI config. space
        mov     ax, mmio_pci_addr
        mov     bh, al ; bh = dddddfff
        mov     al, 2 ; al : DW to read
        call    pci_read_reg
        or      eax, eax
        jnz     @f
        mov     eax, -3 ; empty I/O space
        jmp     .mmio_ret_fail

    @@: test    eax, 1
        jz      @f
        mov     eax, -4 ; damned ports (not MMIO space)
        jmp     .mmio_ret_fail

    @@: pop     ecx ; ecx = block size, bytes (expanded to whole page)
        mov     ebx, ecx ; user_alloc destroys eax, ecx, edx, but saves ebx
        and     eax, 0xfffffff0
        push    eax ; store MMIO physical address + keep 2DWords in the stack
        stdcall user_alloc, ecx
        or      eax, eax
        jnz     mmio_map_over
        mov     eax, -5      ; problem with page allocation

  .mmio_ret_fail:
        pop     ecx
        pop     edx

  .exit:
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc mmio_map_over ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, ebx ; ecx = size (bytes, expanded to whole page)
        shr     ecx, 12 ; ecx = number of pages
        mov     ebx, eax ; ebx = linear address
        pop     eax ; eax = MMIO start
        pop     edx ; edx = MMIO shift (pages)
        shl     edx, 12 ; edx = MMIO shift (bytes)
        add     eax, edx ; eax = uMMIO physical address
        or      eax, PG_SHARED
        or      eax, PG_UW
        or      eax, PG_NOCACHE
        mov     edi, ebx
        call    commit_pages
        mov     eax, edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_ctl.mmio_unmap ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 62.13: unmap linear space previously tied to a PCI memory block
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = linear address of space previously allocated by pci_mmio_map
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 1 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
;# Error codes:
;#   -1 - if no user PCI access allowed
;#    0 - if unmapping failed
;-----------------------------------------------------------------------------------------------------------------------
        ; cross
        mov     ebx, ecx

        stdcall user_free, ebx

        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

end if

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

uglobal
  align 4
  ; VendID (2), DevID (2), Revision = 0 (1), Class Code (3), FNum (1), Bus (1)
  pci_emu_dat: times 30 * 10 db 0
endg

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.pci_bios32_ctl ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 57
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [pci_access_enabled], 1
        jne     .unsupported_func
        cmp     [pci_bios_entry], 0
        jz      .emulate_bios

        push    ds
        mov     ax, pci_data_sel
        mov     ds, ax
        mov     eax, ebp
        mov     ah, 0xb1
        call    pword[cs:pci_bios_entry]
        pop     ds

        jmp     .return
        ;-=-=-=-=-=-=-=-=

  .emulate_bios:
        cmp     ebp, 1 ; PCI_FUNCTION_ID
        jnz     .not_PCI_BIOS_PRESENT
        mov     edx, 'PCI '
        mov     al, [BOOT_VAR + BOOT_PCI_DATA]
        mov     bx, word[BOOT_VAR + BOOT_PCI_DATA + 2]
        mov     cl, [BOOT_VAR + BOOT_PCI_DATA + 1]
        xor     ah, ah
        jmp     .return_abcd

  .not_PCI_BIOS_PRESENT:
        cmp     ebp, 2 ; FIND_PCI_DEVICE
        jne     .not_FIND_PCI_DEVICE
        mov     ebx, pci_emu_dat

  .nxt:
        cmp     [ebx], dx
        jne     .no
        cmp     [ebx + 2], cx
        jne     .no
        dec     si
        jns     .no
        mov     bx, [ebx + 4]
        xor     ah, ah
        jmp     .return_ab

  .no:
        cmp     word[ebx], 0
        je      .dev_not_found
        add     ebx, 10
        jmp     .nxt

  .dev_not_found:
        mov     ah, 0x86 ; DEVICE_NOT_FOUND
        jmp     .return_a

  .not_FIND_PCI_DEVICE:
        cmp     ebp, 3 ; FIND_PCI_CLASS_CODE
        jne     .not_FIND_PCI_CLASS_CODE
        mov     esi, pci_emu_dat
        shl     ecx, 8

  .nxt2:
        cmp     [esi], ecx
        jne     .no2
        mov     bx, [esi]
        xor     ah, ah
        jmp     .return_ab

  .no2:
        cmp     dword[esi], 0
        je      .dev_not_found
        add     esi, 10
        jmp     .nxt2

  .not_FIND_PCI_CLASS_CODE:
        cmp     ebp, 8 ; READ_CONFIG_*
        jb      .not_READ_CONFIG
        cmp     ebp, 0x0a
        ja      .not_READ_CONFIG
        mov     eax, ebp
        mov     ah, bh
        mov     edx, edi
        mov     bh, bl
        mov     bl, dl
        call    pci_read_reg
        mov     ecx, eax
        xor     ah, ah ; SUCCESSFUL
        jmp     .return_abc

  .not_READ_CONFIG:
        cmp     ebp, 0x0b ; WRITE_CONFIG_*
        jb      .not_WRITE_CONFIG
        cmp     ebp, 0x0d
        ja      .not_WRITE_CONFIG
        lea     eax, [ebp + 1]
        mov     ah, bh
        mov     edx, edi
        mov     bh, bl
        mov     bl, dl
        call    pci_write_reg
        xor     ah, ah ; SUCCESSFUL
        jmp     .return_abc

  .not_WRITE_CONFIG:
  .unsupported_func:
        mov     ah, 0x81 ; FUNC_NOT_SUPPORTED

  .return:
        mov     [esp + 4 + regs_context32_t.edi], edi
        mov     [esp + 4 + regs_context32_t.esi], esi

  .return_abcd:
        mov     [esp + 4 + regs_context32_t.edx], edx

  .return_abc:
        mov     [esp + 4 + regs_context32_t.ecx], ecx

  .return_ab:
        mov     [esp + 4 + regs_context32_t.ebx], ebx

  .return_a:
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp
