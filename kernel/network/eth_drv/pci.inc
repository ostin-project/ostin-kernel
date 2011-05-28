;;======================================================================================================================
;;///// pci.inc //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2007 KolibriOS team <http://kolibrios.org/>
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

;***************************************************************************
;
;  PCI CODE FOLLOWS
;
;  the following functions provide access to the PCI interface.
;  These functions are used by scan_bus, and also some ethernet drivers
;
;***************************************************************************

; PCI Bus defines
PCI_HEADER_TYPE           equ 0x0e ; 8 bit
PCI_BASE_ADDRESS_0        equ 0x10 ; 32 bit
PCI_BASE_ADDRESS_5        equ 0x24 ; 32 bits
PCI_BASE_ADDRESS_SPACE_IO equ 0x01
PCI_VENDOR_ID             equ 0x00 ; 16 bit
PCI_BASE_ADDRESS_IO_MASK  equ 0x0fffffffc

config_cmd:
        ; Description
        ;   creates a command dword  for use with the PCI bus
        ; bus # in ebx
        ;   devfn in ecx
        ;   where in edx
        ; command dword returned in eax
        ; Only eax destroyed

        push    ecx
        mov     eax, ebx
        shl     eax, 16
        or      eax, 0x080000000
        shl     ecx, 8
        or      eax, ecx
        pop     ecx
        or      eax, edx
        and     eax, 0x0fffffffc
        ret

pcibios_read_config_byte:
        ; Description
        ;   reads a byte from the PCI config space
        ; bus # in ebx
        ;   devfn in ecx
        ;   where in edx ( ls 16 bits significant )
        ; byte returned in al ( rest of eax zero )
        ; Only eax/edx destroyed

        call    config_cmd
        push    dx
        mov     dx, 0x0cf8
        out     dx, eax
        pop     dx

        xor     eax, eax
        and     dx, 0x03
        add     dx, 0x0cfc
;       and     dx, 0x0ffc
        in      al, dx
        ret

pcibios_read_config_word:
        ; Description
        ;   reads a word from the PCI config space
        ; bus # in ebx
        ;   devfn in ecx
        ;   where in edx ( ls 16 bits significant )
        ; word returned in ax ( rest of eax zero )
        ; Only eax/edx destroyed

        call    config_cmd
        push    dx
        mov     dx, 0x0cf8
        out     dx, eax
        pop     dx

        xor     eax, eax
        and     dx, 0x02
        add     dx, 0x0cfc
;       and     dx, 0x0ffc
        in      ax, dx
        ret

pcibios_read_config_dword:
        ; Description
        ;   reads a dword from the PCI config space
        ; bus # in ebx
        ;   devfn in ecx
        ;   where in edx ( ls 16 bits significant )
        ; dword returned in eax
        ; Only eax/edx destroyed

        push    edx
        call    config_cmd
        push    dx
        mov     dx, 0x0cf8
        out     dx, eax
        pop     dx
        xor     eax, eax
        mov     dx, 0x0cfc
        in      eax, dx
        pop     edx
        ret

pcibios_write_config_byte:
        ; Description
        ;   write a byte in al to the PCI config space
        ; bus # in ebx
        ;   devfn in ecx
        ;   where in edx ( ls 16 bits significant )
        ; Only eax/edx destroyed

        push    ax
        call    config_cmd
        push    dx
        mov     dx, 0x0cf8
        out     dx, eax
        pop     dx
        pop     ax

        and     dx, 0x03
        add     dx, 0x0cfc
        out     dx, al
        ret

pcibios_write_config_word:
        ; Description
        ;   write a word in ax to the PCI config space
        ; bus # in ebx
        ;   devfn in ecx
        ;   where in edx ( ls 16 bits significant )
        ; Only eax/edx destroyed

    push    ax
    call    config_cmd
    push    dx
    mov     dx, 0xCF8
    out     dx, eax
    pop     dx
    pop     ax

    and     dx, 0x02
    add     dx, 0xCFC
    out     dx, ax
    ret

delay_us:
        ; Description
        ;   delays for 30 to 60 us
        ; I would prefer this routine to be able to delay for
        ; a selectable number of microseconds, but this works for now.
        ; If you know a better way to do 2us delay, pleae tell me!

        push    eax
        push    ecx

        mov     ecx, 2

        in      al, 0x61
        and     al, 0x10
        mov     ah, al
        cld

  .dcnt1:
        in      al, 0x61
        and     al, 0x10
        cmp     al, ah
        jz      .dcnt1

        mov     ah, al
        loop    .dcnt1

        pop     ecx
        pop     eax

        ret

scan_bus:
        ; Description
        ;   Scans the PCI bus for a supported device
        ;   If a supported device is found, the drvr_ variables are initialised
        ;   to that drivers functions ( as defined in the PCICards table)
        ; io_addr   holds card I/O space. 32 bit, but only LS 16 bits valid
        ;   pci_data  holds the PCI vendor + device code
        ;   pci_dev   holds PCI bus dev #
        ;   pci_bus   holds PCI bus #
        ; io_addr will be zero if no card found

        xor     eax, eax
        mov     [hdrtype], al
        mov     [pci_data], eax

        xor     ebx, ebx ; ebx = bus# 0 .. 255

  .sb_bus_loop:
        xor     ecx, ecx ; ecx = devfn# 0 .. 254  ( not 255? )

  .sb_devf_loop:
        mov     eax, ecx
        and     eax, 0x07

        cmp     eax, 0
        jne     .sb_001

        mov     edx, PCI_HEADER_TYPE
        call    pcibios_read_config_byte
        mov     [hdrtype], al
        jmp     .sb_002

  .sb_001:
        mov     al, [hdrtype]
        and     al, 0x080
        cmp     al, 0x080
        jne     .sb_inc_devf

  .sb_002:
        mov     edx, PCI_VENDOR_ID
        call    pcibios_read_config_dword
        mov     [vendor_device], eax
        cmp     eax, 0x0ffffffff
        je      .sb_empty
        cmp     eax, 0
        jne     .sb_check_vendor

  .sb_empty:
        mov     byte[hdrtype], 0
        jmp     .sb_inc_devf

  .sb_check_vendor:
        ; iterate though PCICards until end or match found
        mov     esi, PCICards

  .sb_check:
        cmp     dword[esi], 0
        je      .sb_inc_devf ; Quit if at last entry
        cmp     eax, [esi]
        je      .sb_got_card
        add     esi, PCICARDS_ENTRY_SIZE
        jmp     .sb_check

  .sb_got_card:
        ; indicate that we have found the card
        mov     [pci_data], eax
        mov     [pci_dev], ecx
        mov     [pci_bus], ebx

        ; Define the driver functions
        push    eax
        mov     eax, [esi + 4]
        mov     [drvr_probe], eax
        mov     eax, [esi + 8]
        mov     [drvr_reset], eax
        mov     eax, [esi + 12]
        mov     [drvr_poll], eax
        mov     eax, [esi + 16]
        mov     [drvr_transmit], eax
        mov     eax, [esi + 20]
        mov     [drvr_cable], eax
        pop     eax

        mov     edx, PCI_BASE_ADDRESS_0

  .sb_reg_check:
        call    pcibios_read_config_dword
        mov     [io_addr], eax
        and     eax, PCI_BASE_ADDRESS_IO_MASK
        cmp     eax, 0
        je      .sb_inc_reg
        mov     eax, [io_addr]
        and     eax, PCI_BASE_ADDRESS_SPACE_IO
        cmp     eax, 0
        je      .sb_inc_reg

        mov     eax, [io_addr]
        and     eax, PCI_BASE_ADDRESS_IO_MASK
        mov     [io_addr], eax

  .sb_exit1:
        ret

  .sb_inc_reg:
        add     edx, 4
        cmp     edx, PCI_BASE_ADDRESS_5
        jbe     .sb_reg_check

  .sb_inc_devf:
        inc     ecx
        cmp     ecx, 255
        jb      .sb_devf_loop
        inc     ebx
        cmp     ebx, 256
        jb      .sb_bus_loop

        ; We get here if we didn't find our card
        ; set io_addr to 0 as an indication
        xor     eax, eax
        mov     [io_addr], eax

  .sb_exit2:
        ret
