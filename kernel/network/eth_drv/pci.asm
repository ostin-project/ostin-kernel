;;======================================================================================================================
;;///// pci.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
;? The following functions provide access to the PCI interface.
;? These functions are used by scan_bus, and also some ethernet drivers
;;======================================================================================================================

; PCI Bus defines
PCI_HEADER_TYPE                = 0x0e ; 8 bit
PCI_BASE_ADDRESS_0             = 0x10 ; 32 bit
PCI_BASE_ADDRESS_5             = 0x24 ; 32 bits
PCI_BASE_ADDRESS_SPACE_IO      = 0x01
PCI_VENDOR_ID                  = 0x00 ; 16 bit
PCI_BASE_ADDRESS_IO_MASK       = 0xfffffffc

PCI_COMMAND_IO                 = 0x1   ; Enable response in I/O space
PCI_COMMAND_MEM                = 0x2   ; Enable response in mem space
PCI_COMMAND_MASTER             = 0x4   ; Enable bus mastering
PCI_LATENCY_TIMER              = 0x0d  ; 8 bits
PCI_COMMAND_SPECIAL            = 0x8   ; Enable response to special cycles
PCI_COMMAND_INVALIDATE         = 0x10  ; Use memory write and invalidate
PCI_COMMAND_VGA_PALETTE        = 0x20  ; Enable palette snooping
PCI_COMMAND_PARITY             = 0x40  ; Enable parity checking
PCI_COMMAND_WAIT               = 0x80  ; Enable address/data stepping
PCI_COMMAND_SERR               = 0x100 ; Enable SERR
PCI_COMMAND_FAST_BACK          = 0x200 ; Enable back-to-back writes

PCI_VENDOR_ID                  = 0x00  ; 16 bits
PCI_DEVICE_ID                  = 0x02  ; 16 bits
PCI_COMMAND                    = 0x04  ; 16 bits

PCI_BASE_ADDRESS_0             = 0x10  ; 32 bits
PCI_BASE_ADDRESS_1             = 0x14  ; 32 bits
PCI_BASE_ADDRESS_2             = 0x18  ; 32 bits
PCI_BASE_ADDRESS_3             = 0x1c  ; 32 bits
PCI_BASE_ADDRESS_4             = 0x20  ; 32 bits
PCI_BASE_ADDRESS_5             = 0x24  ; 32 bits

PCI_BASE_ADDRESS_MEM_TYPE_MASK = 0x06
PCI_BASE_ADDRESS_MEM_TYPE_32   = 0x00 ; 32 bit address
PCI_BASE_ADDRESS_MEM_TYPE_1M   = 0x02 ; Below 1M [obsolete]
PCI_BASE_ADDRESS_MEM_TYPE_64   = 0x04 ; 64 bit address

PCI_BASE_ADDRESS_IO_MASK       = not 0x03
PCI_BASE_ADDRESS_MEM_MASK      = not 0x0f
PCI_BASE_ADDRESS_SPACE_IO      = 0x01
PCI_ROM_ADDRESS                = 0x30 ; 32 bits

;-----------------------------------------------------------------------------------------------------------------------
kproc config_cmd ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? creates a command dword  for use with the PCI bus
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = bus #
;> ecx = devfn
;> edx = where
;-----------------------------------------------------------------------------------------------------------------------
;< eax = command dword
;-----------------------------------------------------------------------------------------------------------------------
;# Only eax destroyed
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     eax, ebx
        shl     eax, 16
        or      eax, 0x80000000
        shl     ecx, 8
        or      eax, ecx
        pop     ecx
        or      eax, edx
        and     eax, 0xfffffffc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcibios_read_config_byte ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? reads a byte from the PCI config space
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = bus #
;> ecx = devfn
;> edx = where (ls 16 bits significant)
;-----------------------------------------------------------------------------------------------------------------------
;< al = byte read (rest of eax zeroed)
;-----------------------------------------------------------------------------------------------------------------------
;# Only eax/edx destroyed
;-----------------------------------------------------------------------------------------------------------------------
        call    config_cmd
        push    dx
        mov     dx, 0xcf8
        out     dx, eax
        pop     dx

        xor     eax, eax
        and     dx, 0x03
        add     dx, 0xcfc
;       and     dx, 0xffc
        in      al, dx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcibios_read_config_word ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? reads a word from the PCI config space
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = bus #
;> ecx = devfn
;> edx = where (ls 16 bits significant)
;-----------------------------------------------------------------------------------------------------------------------
;< ax = word read (rest of eax zeroed)
;-----------------------------------------------------------------------------------------------------------------------
;# Only eax/edx destroyed
;-----------------------------------------------------------------------------------------------------------------------
        call    config_cmd
        push    dx
        mov     dx, 0xcf8
        out     dx, eax
        pop     dx

        xor     eax, eax
        and     dx, 0x02
        add     dx, 0xcfc
;       and     dx, 0xffc
        in      ax, dx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcibios_read_config_dword ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? reads a dword from the PCI config space
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = bus #
;> ecx = devfn
;> edx = where (ls 16 bits significant)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = dword read
;-----------------------------------------------------------------------------------------------------------------------
;# Only eax/edx destroyed
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        call    config_cmd
        push    dx
        mov     dx, 0xcf8
        out     dx, eax
        pop     dx
        xor     eax, eax
        mov     dx, 0xcfc
        in      eax, dx
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcibios_write_config_byte ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? write a byte to the PCI config space
;-----------------------------------------------------------------------------------------------------------------------
;> al = byte to write
;> ebx = bus #
;> ecx = devfn
;> edx = where (ls 16 bits significant)
;-----------------------------------------------------------------------------------------------------------------------
;# Only eax/edx destroyed
;-----------------------------------------------------------------------------------------------------------------------
        push    ax
        call    config_cmd
        push    dx
        mov     dx, 0xcf8
        out     dx, eax
        pop     dx
        pop     ax

        and     dx, 0x03
        add     dx, 0xcfc
        out     dx, al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcibios_write_config_word ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? write a word to the PCI config space
;-----------------------------------------------------------------------------------------------------------------------
;> ax = word to write
;> ebx = bus #
;> ecx = devfn
;> edx = where (ls 16 bits significant)
;-----------------------------------------------------------------------------------------------------------------------
;# Only eax/edx destroyed
;-----------------------------------------------------------------------------------------------------------------------
        push    ax
        call    config_cmd
        push    dx
        mov     dx, 0xcf8
        out     dx, eax
        pop     dx
        pop     ax

        and     dx, 0x02
        add     dx, 0xcfc
        out     dx, ax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc delay_us ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? delays for 30 to 60 us
;-----------------------------------------------------------------------------------------------------------------------
;# I would prefer this routine to be able to delay for
;# a selectable number of microseconds, but this works for now.
;# If you know a better way to do 2us delay, pleae tell me!
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    ecx

        mov     ecx, 2

        in      al, 0x61
        and     al, 0x10
        mov     ah, al

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
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc scan_bus ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Scans the PCI bus for a supported device
;? If a supported device is found, the drvr_ variables are initialised
;? to that drivers functions ( as defined in the PCICards table)
;-----------------------------------------------------------------------------------------------------------------------
;> [io_addr] = holds card I/O space. 32 bit, but only LS 16 bits valid
;> [pci_data] = holds the PCI vendor + device code
;> [pci_dev] = holds PCI bus dev #
;> [pci_bus] = holds PCI bus #
;-----------------------------------------------------------------------------------------------------------------------
;< [io_addr] = 0 (no card found)
;-----------------------------------------------------------------------------------------------------------------------
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
        cmp     eax, 0xffffffff
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
kendp

;-----------------------------------------------------------------------------------------------------------------------
proc CONFIG_CMD, where:byte ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, byte[pci_bus]
        shl     eax, 8
        mov     al, [pci_dev]
        shl     eax, 8
        mov     al, [where]
        and     al, not 3
        or      eax, 0x80000000
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc pci_read_config_byte, where:dword ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        stdcall CONFIG_CMD, [where]
        mov     dx, 0xcf8
        out     dx, eax
        mov     edx, [where]
        and     edx, 3
        add     edx, 0xcfc
        in      al, dx
        pop     edx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc pci_read_config_word, where:dword ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        stdcall CONFIG_CMD, [where]
        mov     dx, 0xcf8
        out     dx, eax
        mov     edx, [where]
        and     edx, 2
        add     edx, 0xcfc
        in      ax, dx
        pop     edx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc pci_read_config_dword, where:dword ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        stdcall CONFIG_CMD, [where]
        mov     edx, 0xcf8
        out     dx, eax
        mov     edx, 0xcfc
        in      eax, dx
        pop     edx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc pci_write_config_byte, where:dword, value:byte ;///////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        stdcall CONFIG_CMD, [where]
        mov     dx, 0xcf8
        out     dx, eax
        mov     edx, [where]
        and     edx, 3
        add     edx, 0xcfc
        mov     al, [value]
        out     dx, al
        pop     edx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc pci_write_config_word, where:dword, value:word ;///////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        stdcall CONFIG_CMD, [where]
        mov     dx, 0xcf8
        out     dx, eax
        mov     edx, [where]
        and     edx, 2
        add     edx, 0xcfc
        mov     ax, [value]
        out     dx, ax
        pop     edx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc pci_write_config_dword, where:dword, value:dword ;/////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        stdcall CONFIG_CMD, [where]
        mov     edx, 0xcf8
        out     dx, eax
        mov     edx, 0xcfc
        mov     eax, [value]
        out     dx, eax
        pop     edx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc adjust_pci_device ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Set device to be a busmaster in case BIOS neglected to do so.
;? Also adjust PCI latency timer to a reasonable value, 32.
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "adjust_pci_device\n"

        stdcall pci_read_config_word, PCI_COMMAND
        mov     bx, ax
        or      bx, PCI_COMMAND_MASTER or PCI_COMMAND_IO
        cmp     ax, bx
        je      @f
;       klog_   LOG_WARNING, "adjust_pci_device: The PCI BIOS has not enabled this device!\n"
;       klog_   LOG_WARNING, "Updating PCI command %x->%x. pci_bus %x pci_device_fn %x\n", ax, bx, [pci_bus]:2, \
;               [pci_dev]:2
        stdcall pci_write_config_word, PCI_COMMAND, ebx

    @@: stdcall pci_read_config_byte, PCI_LATENCY_TIMER
        cmp     al, 32
        jae     @f
;       klog_   LOG_WARNING, "adjust_pci_device: PCI latency timer (CFLT) is unreasonably low at %d.\n", al
;       klog_   LOG_WARNING, "Setting to 32 clocks.\n", al
        stdcall pci_write_config_byte, PCI_LATENCY_TIMER, 32

    @@: ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc pci_bar_start, index:dword ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Find the start of a pci resource
;-----------------------------------------------------------------------------------------------------------------------
        stdcall pci_read_config_dword, [index]
        test    eax, PCI_BASE_ADDRESS_SPACE_IO
        jz      @f
        and     eax, PCI_BASE_ADDRESS_IO_MASK
        jmp     .exit

    @@: push    eax
        and     eax, PCI_BASE_ADDRESS_MEM_TYPE_MASK
        cmp     eax, PCI_BASE_ADDRESS_MEM_TYPE_64
        jne     .not64
        mov     eax, [index]
        add     eax, 4
        stdcall pci_read_config_dword, eax
        or      eax, eax
        jz      .not64
;       klog_   LOG_WARNING, "pci_bar_start: Unhandled 64bit BAR\n"
        add     esp, 4
        or      eax, -1
        ret

  .not64:
        pop     eax
        and     eax, PCI_BASE_ADDRESS_MEM_MASK

  .exit:
        ret
endp
