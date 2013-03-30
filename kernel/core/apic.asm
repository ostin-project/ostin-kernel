;;======================================================================================================================
;;///// apic.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
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
;? Interrupt controller functions
;;======================================================================================================================

iglobal
  irq_count dd 24
endg

uglobal
  irq_mode dd ?
  ioapic_base dd ?
  lapic_base dd ?
endg

APIC_ID         = 0x20
APIC_TPR        = 0x80
APIC_EOI        = 0xb0
APIC_LDR        = 0xd0
APIC_DFR        = 0xe0
APIC_SVR        = 0xf0
APIC_ISR        = 0x100
APIC_ESR        = 0x280
APIC_ICRL       = 0x300
APIC_ICRH       = 0x310
APIC_LVT_LINT0  = 0x350
APIC_LVT_LINT1  = 0x360
APIC_LVT_ERR    = 0x370

; APIC timer
APIC_LVT_TIMER  = 0x320
APIC_TIMER_DIV  = 0x3e0
APIC_TIMER_INIT = 0x380
APIC_TIMER_CUR  = 0x390

; IOAPIC
IOAPIC_ID       = 0x0
IOAPIC_VER      = 0x1
IOAPIC_ARB      = 0x2
IOAPIC_REDTBL   = 0x10

;-----------------------------------------------------------------------------------------------------------------------
kproc apic_init ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [irq_mode], IRQ_PIC

        cmp     [acpi_ioapic_base], 0
        jz      .no_apic

        cmp     [acpi_lapic_base], 0
        jz      .no_apic

        stdcall load_file, dev_data_path
        test    eax, eax
        jz      .no_apic

        mov     [acpi_dev_data], eax
        mov     [acpi_dev_size], ebx

        call    irq_mask_all

        ; IOAPIC init
        stdcall map_io_mem, [acpi_ioapic_base], 0x20, PG_SW + PG_NOCACHE
        mov     [ioapic_base], eax

        mov     eax, IOAPIC_VER
        call    ioapic_read
        shr     eax, 16
        inc     al
        movzx   eax, al
        cmp     al, IRQ_RESERVED
        jbe     @f

        mov     al, IRQ_RESERVED

    @@: mov     [irq_count], eax

        ; Reroute IOAPIC & mask all interrupts
        xor     ecx, ecx
        mov     eax, IOAPIC_REDTBL

    @@: mov     ebx, eax
        call    ioapic_read
        mov     ah, 0x09 ; Delivery Mode: Lowest Priority, Destination Mode: Logical
        mov     al, cl
        add     al, 0x20 ; vector
        or      eax, 0x10000 ; Mask Interrupt
        cmp     ecx, 16
        jb      .set

        or      eax, 0xa000 ; <<< level-triggered active-low for IRQ16+

  .set:
        xchg    eax, ebx
        call    ioapic_write
        inc     eax
        mov     ebx, eax
        call    ioapic_read
        or      eax, 0xff000000 ; Destination Field
        xchg    eax, ebx
        call    ioapic_write
        inc     eax
        inc     ecx
        cmp     ecx, [irq_count]
        jb      @b

        call    lapic_init

        mov     [irq_mode], IRQ_APIC

        mov     al, 0x70
        out     0x22, al
        mov     al, 1
        out     0x23, al

        call    pci_irq_fixup

  .no_apic:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc lapic_init ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [lapic_base], 0
        jne     .done

        stdcall map_io_mem, [acpi_lapic_base], 0x1000, PG_SW + PG_NOCACHE
        mov     [lapic_base], eax
        mov     esi, eax

        ; Program Destination Format Register for Flat mode.
        mov     eax, [esi + APIC_DFR]
        or      eax, 0xf0000000
        mov     [esi + APIC_DFR], eax

        ; Program Logical Destination Register.
        mov     eax, [esi + APIC_LDR]
;       and     eax, 0xff000000
        and     eax, 0x00ffffff
        or      eax, 0x01000000 ;!!!!!!!!!!!!
        mov     [esi + APIC_LDR], eax

        ; Task Priority Register initialization.
        mov     eax, [esi + APIC_TPR]
        and     eax, 0xffffff00
        mov     [esi + APIC_TPR], eax

        ; Flush the queue
        mov     edx, 0

  .nxt2:
        mov     ecx, 32
        mov     eax, [esi + APIC_ISR + edx]

  .nxt:
        shr     eax, 1
        jnc     @f
        mov     dword[esi + APIC_EOI], 0 ; EOI

    @@: loop    .nxt

        add     edx, 0x10
        cmp     edx, 0x170
        jbe     .nxt2

        ; Spurious-Interrupt Vector Register initialization.
        mov     eax, [esi + APIC_SVR]
        or      eax, 0x1ff
        and     eax, 0xfffffdff
        mov     [esi + APIC_SVR], eax

        ; Initialize LVT LINT0 register. (INTR)
        mov     eax, 0x00700
;       mov     eax, 0x10700
        mov     [esi + APIC_LVT_LINT0], eax

        ; Initialize LVT LINT1 register. (NMI)
        mov     eax, 0x00400
        mov     [esi + APIC_LVT_LINT1], eax

        ; Initialize LVT Error register.
        mov     eax, [esi + APIC_LVT_ERR]
        or      eax, 0x10000 ; bit 16
        mov     [esi + APIC_LVT_ERR], eax

if KCONFIG_SYS_TIMER_FREQ <> 100
  err 'TODO: Support APIC timer frequency other than 100'
end if

        ; LAPIC timer
        ; pre init
        mov     dword[esi + APIC_TIMER_DIV], 1011b ; 1
        mov     dword[esi + APIC_TIMER_INIT], 0xffffffff ; max val
        push    esi
        mov     esi, 640 ; wait 0.64 sec
        call    delay_ms
        pop     esi
        mov     eax, [esi + APIC_TIMER_CUR] ; read current tick couner
        xor     eax, 0xffffffff ; eax = 0xffffffff - eax
        shr     eax, 6 ; eax /= 64; APIC ticks per 0.01 sec

        ; Start (every 0.01 sec)
        mov     dword[esi + APIC_LVT_TIMER], 0x30020 ; periodic int 0x20
        mov     dword[esi + APIC_TIMER_INIT], eax

  .done:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ioapic_read ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = IOAPIC register
;-----------------------------------------------------------------------------------------------------------------------
;< eax = read value
;-----------------------------------------------------------------------------------------------------------------------
        push    esi
        mov     esi, [ioapic_base]
        mov     [esi], eax
        mov     eax, [esi + 0x10]
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ioapic_write ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = IOAPIC register
;> ebx = value
;-----------------------------------------------------------------------------------------------------------------------
        push    esi
        mov     esi, [ioapic_base]
        mov     [esi], eax
        mov     [esi + 0x10], ebx
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pic_init ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Remap all IRQ to 0x20+ Vectors
;? IRQ0 to vector 0x20, IRQ1 to vector 0x21...
;-----------------------------------------------------------------------------------------------------------------------
        cli

        mov     al, 0x11 ; icw4, edge triggered
        out     0x20, al
        out     0xa0, al

        mov     al, 0x20 ; generate 0x20 +
        out     0x21, al
        mov     al, 0x28 ; generate 0x28 +
        out     0xa1, al

        mov     al, 0x04 ; slave at irq2
        out     0x21, al
        mov     al, 0x02 ; at irq9
        out     0xa1, al

        mov     al, 0x01 ; 8086 mode
        out     0x21, al
        out     0xa1, al

        call    irq_mask_all
;       mov     [irq_type_to_set], IRQ_TYPE_PIC

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pit_init ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Timer setup
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x34 ; pack[2(counter #0), 2(2 reads/writes), 3(rate generator), 1(binary value)]
        out     0x43, al
        mov     ax, 1193180 / KCONFIG_SYS_TIMER_FREQ ; should fit in word
        out     0x40, al ; lsb (bits 0..7)
        xchg    al, ah
        out     0x40, al ; msb (bits 8..15)

        and     dword[timer_ticks], 0
        and     dword[timer_ticks + 4], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc unmask_timer ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [irq_mode], IRQ_APIC
        je      @f

        stdcall enable_irq, 0
        ret

    @@: ; use PIT
        ; in some systems PIT no connected to IOAPIC
;       mov     eax, 0x14
;       call    ioapic_read
;       mov     ah, 0x09 ; Delivery Mode: Lowest Priority, Destination Mode: Logical
;       mov     al, 0x20
;       or      eax, 0x10000 ; Mask Interrupt
;       mov     ebx, eax
;       mov     eax, 0x14
;       call    ioapic_write
;       stdcall enable_irq, 2
;       ret

        ; use LAPIC timer
        mov     esi, [lapic_base]
        mov     eax, [esi + APIC_LVT_TIMER]
        and     eax, 0xfffeffff
        mov     [esi + APIC_LVT_TIMER], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc irq_mask_all ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Disable all IRQ
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [irq_mode], IRQ_APIC
        je      .apic

        mov     al, 0xff
        out     0x21,al

        out     0xa1,al
        mov     ecx,0x1000
        ret

  .apic:
        mov     ecx, [irq_count]
        mov     eax, 0x10

    @@: mov     ebx, eax
        call    ioapic_read
        or      eax, 0x10000 ; bit 16
        xchg    eax, ebx
        call    ioapic_write
        inc     eax
        inc     eax
        loop    @b

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc irq_eoi ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? End of interrupt
;-----------------------------------------------------------------------------------------------------------------------
;> cl = interrupt number
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [irq_mode], IRQ_APIC
        je      .apic

        cmp     cl, 8
        mov     al, 0x20
        jb      @f

        out     0xa0, al

    @@: out     0x20, al
        ret

  .apic:
        mov     eax, [lapic_base]
        mov     dword[eax + APIC_EOI], 0 ; EOI
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc enable_irq stdcall, irq_line:dword ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [irq_line]

        cmp     [irq_mode], IRQ_APIC
        je      .apic

        mov     edx, 0x21
        cmp     ebx, 8
        jb      @f

        mov     edx, 0xa1
        sub     ebx, 8

    @@: in      al, dx
        btr     eax, ebx
        out     dx, al
        ret

  .apic:
        shl     ebx, 1
        add     ebx, 0x10
        mov     eax, ebx
        call    ioapic_read
        and     eax, 0xfffeffff ; bit 16
        xchg    eax, ebx
        call    ioapic_write
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc pci_irq_fixup ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp

        mov     esi, [acpi_dev_data]
        mov     ebx, [acpi_dev_size]

        lea     edi, [esi+ebx]

  .iterate:
        cmp     esi, edi
        jae     .done

        mov     eax, [esi]

        cmp     eax, -1
        je      .done

        movzx   ebx, al
        movzx   ebp, ah

        stdcall pci_read32, ebp, ebx, 0

        cmp     eax, [esi + 4]
        jne     .skip

        mov     eax, [esi + 8]
        stdcall pci_write8, ebp, ebx, 0x3c, eax

  .skip:
        add     esi, 16
        jmp     .iterate

  .done:
        pop     ebp
        ret
kendp
