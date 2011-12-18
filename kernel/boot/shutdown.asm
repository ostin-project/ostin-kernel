;;======================================================================================================================
;;///// shutdown.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
;; (c) 2003 MenuetOS <http://menuetos.net/>
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
kproc pr_mode_exit ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; setup stack
        mov     ax, 0x3000
        mov     ss, ax
        mov     esp, 0xec00
        ; setup ds
        push    cs
        pop     ds

        lidt    [old_ints_h]
        ; remap IRQs
        mov     al, 0x11
        out     0x20, al
        call    rdelay
        out     0xa0, al
        call    rdelay

        mov     al, 0x08
        out     0x21, al
        call    rdelay
        mov     al, 0x70
        out     0xa1, al
        call    rdelay

        mov     al, 0x04
        out     0x21, al
        call    rdelay
        mov     al, 0x02
        out     0xa1, al
        call    rdelay

        mov     al, 0x01
        out     0x21, al
        call    rdelay
        out     0xa1, al
        call    rdelay

        mov     al, 0xb8
        out     0x21, al
        call    rdelay
        mov     al, 0xbd
        out     0xa1, al
        sti

  .temp_3456:
        xor     ax, ax
        mov     es, ax
        mov     al, [es:BOOT_SHUTDOWN_PARAM]
        cmp     al, 1
        jl      .nbw
        cmp     al, 4
        jle     .nbw32

  .nbw:
        in      al, 0x60
        cmp     al, 6
        jae     .nbw
        mov     bl, al

  .nbw2:
        in      al, 0x60
        cmp     al, bl
        je      .nbw2
        cmp     al, 240 ; ax, 240
        jne     .nbw31
        mov     al, bl
        dec     ax
        jmp     .nbw32

  .nbw31:
        add     bl, 128
        cmp     al, bl
        jne     .nbw
        sub     al, 129

  .nbw32:
        dec     ax
        dec     ax ; 2 = power off
        jnz     .no_apm_off
        call    APM_PowerOff
        jmp     $

  .no_apm_off:
        dec     ax ; 3 = reboot
        jnz     .restart_kernel ; 4 = restart kernel
        push    0x40
        pop     ds
        mov     word[0x0072], 0x1234
        jmp     0xf000:0xfff0

  .restart_kernel:
        mov     ax, 0x0003 ; set text mode for screen
        int     0x10
        jmp     0x4000:0x0000
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rdelay ;//////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc APM_PowerOff ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ax, 0x5304
        xor     bx, bx
        int     0x15
        ;!!!!!!!!!!!!!!!!!!!!!!!!
        mov     ax, 0x5300
        xor     bx, bx
        int     0x15
        push    ax

        mov     ax, 0x5301
        xor     bx, bx
        int     0x15

        mov     ax, 0x5308
        mov     bx, 1
        mov     cx, bx
        int     0x15

        mov     ax, 0x530e
        xor     bx, bx
        pop     cx
        int     0x15

        mov     ax, 0x530d
        mov     bx, 1
        mov     cx, bx
        int     0x15

        mov     ax, 0x530f
        mov     bx, 1
        mov     cx, bx
        int     0x15

        mov     ax, 0x5307
        mov     bx, 1
        mov     cx, 3
        int     0x15
        ;!!!!!!!!!!!!!!!!!!!!!!!!
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc restart_kernel_4000 ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cli

        push    ds
        pop     es
        mov     cx, 0x8000
        push    cx
        push    0x7000
        pop     ds
        xor     si, si
        xor     di, di
        rep
        movsw
        pop     cx
        mov     ds, cx
        push    0x2000
        pop     es
        rep
        movsw
        push    0x9000
        pop     ds
        push    0x3000
        pop     es
        mov     cx, 0xe000 / 2
        rep
        movsw

        wbinvd  ; write and invalidate cache

        mov     al, 00110100b
        out     0x43, al
        jcxz    $ + 2
        mov     al, 0xff
        out     0x40, al
        jcxz    $ + 2
        out     0x40, al
        jcxz    $ + 2
        sti

        ; We must read data from keyboard port,
        ; because there may be situation when previous keyboard interrupt is lost
        ; (due to return to real mode and IRQ reprogramming)
        ; and next interrupt will not be generated (as keyboard waits for handling)
        in      al, 0x60

        ; bootloader interface
        push    0x1000
        pop     ds
        mov     si, kernel_restart_bootblock
        mov     ax, 'KL'
        jmp     0x1000:0000
kendp
