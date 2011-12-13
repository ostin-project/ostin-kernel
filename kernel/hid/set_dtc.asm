;;======================================================================================================================
;;///// set_dtc.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.dtc_ctl ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 22
;-----------------------------------------------------------------------------------------------------------------------
;< [esp + 4 + regs_context32_t.eax] = 0 (ok),  1 (wrong format) or 2 (battery low)
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.dtc_ctl, subfn, sysfn.not_implemented, \
    set_time, \ ; 0
    set_date, \ ; 1
    set_day_of_week, \ ; 2
    set_alarm_clock ; 3
endg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        cli
        mov     al, 0x0d
        out     0x70, al
        in      al, 0x71
        bt      ax, 7
        jnc     .error_battery_low

        jmp     [.subfn + ebx * 4]

  .error_battery_low:
        sti
        mov     [esp + 4 + regs_context32_t.eax], 2
        ret

  .error_wrong_format:
        sti
        mov     [esp + 4 + regs_context32_t.eax], 1
        ret

  .exit:
        dec     edx
        call    sysfn.dtc_ctl._.start_stop_clock
        sti
        and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.dtc_ctl.set_day_of_week ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 22.2
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 2
;> ecx = day of week, [1..7]
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx ; test day of week
        jz      sysfn.dtc_ctl.error_wrong_format
        cmp     ecx, 7
        ja      sysfn.dtc_ctl.error_wrong_format

        mov     edx, 0x70
        call    sysfn.dtc_ctl._.start_stop_clock

        dec     edx
        mov     al, 6
        out     dx, al
        inc     edx
        mov     al, cl
        out     dx, al

        jmp     sysfn.dtc_ctl.exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.dtc_ctl.set_date ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 22.1
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 1
;> ecx = date in BCD format, pack[8(0), 8(day), 8(month), 8(year)]
;-----------------------------------------------------------------------------------------------------------------------
        call    sysfn.dtc_ctl._.validate_and_convert_date
        jc      sysfn.dtc_ctl.error_wrong_format

        mov     edx, 0x70
        call    sysfn.dtc_ctl._.start_stop_clock

        dec     edx
        mov     al, 7 ; set days
        out     dx, al
        inc     edx
        mov     al, cl
        out     dx, al
        dec     edx
        mov     al, 8 ; set months
        out     dx, al
        inc     edx
        mov     al, ch
        out     dx, al
        dec     edx
        mov     al, 9 ; set years
        out     dx, al
        inc     edx
        shr     ecx, 8
        mov     al, ch
        out     dx, al

        jmp     sysfn.dtc_ctl.exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.dtc_ctl.set_time ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 22.0
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 0
;> ecx = time in BCD format, pack[8(0), 8(seconds), 8(minutes), 8(hours)]
;-----------------------------------------------------------------------------------------------------------------------
        call    sysfn.dtc_ctl._.validate_and_convert_time
        jc      sysfn.dtc_ctl.error_wrong_format

        mov     edx, 0x70
        call    sysfn.dtc_ctl._.start_stop_clock

        dec     edx
        xor     eax, eax ; al=0-set seconds
        out     dx, al
        inc     edx
        mov     al, cl
        out     dx, al
        dec     edx
        mov     al, 2 ; set minutes
        out     dx, al
        inc     edx
        mov     al, ch
        out     dx, al
        dec     edx
        mov     al, 4 ; set hours
        out     dx, al
        inc     edx
        shr     ecx, 8
        mov     al, ch
        out     dx, al

        jmp     sysfn.dtc_ctl.exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.dtc_ctl.set_alarm_clock ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 22.3
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 3
;> ecx = time in BCD format, pack[8(0), 8(seconds), 8(minutes), 8(hours)]
;-----------------------------------------------------------------------------------------------------------------------
        call    sysfn.dtc_ctl._.validate_and_convert_time
        jc      sysfn.dtc_ctl.error_wrong_format

        mov     edx, 0x70
        call    sysfn.dtc_ctl._.start_stop_clock

        dec     edx
        mov     al, 1 ; set seconds for al.
        out     dx, al
        inc     edx
        mov     al, cl
        out     dx, al
        dec     edx
        mov     al, 3 ; set minutes for al.
        out     dx, al
        inc     edx
        mov     al, ch
        out     dx, al
        dec     edx
        mov     al, 5 ; set hours for al.
        out     dx, al
        inc     edx
        shr     ecx, 8
        mov     al, ch
        out     dx, al
        dec     edx
        mov     al, 0x0b ; enable irq's
        out     dx, al
        inc     dx
        in      al, dx
        bts     ax, 5 ; set bit 5
        out     dx, al

        jmp     sysfn.dtc_ctl.exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.dtc_ctl._.validate_and_convert_date ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     cl, 0x99 ; test year
        ja      .error
        shl     ecx, 4
        cmp     cl, 0x90
        ja      .error
        cmp     ch, 0x99 ; test month
        ja      .error
        shr     ecx, 4
        test    ch, ch
        je      .error
        cmp     ch, 0x12
        ja      .error
        shl     ecx, 8
        bswap   ecx ; 00YYMMDD
        test    cl, cl ; test day
        je      .error
        shl     ecx, 4
        cmp     cl, 0x90
        ja      .error
        shr     ecx, 4
        cmp     ch, 2 ; February
        jne     .testday
        cmp     cl, 0x29
        ja      .error
        jmp     .exit

  .testday:
        cmp     ch, 8
        jb      .testday1 ; Aug-Dec
        bt      cx, 8
        jnc     .days31
        jmp     .days30

  .testday1:
        bt      cx, 8 ; Jan-Jul ex.Feb
        jnc     .days30

  .days31:
        cmp     cl, 0x31
        ja      .error
        jmp     .exit

  .days30:
        cmp     cl, 0x30
        ja      .error

  .exit:
        clc
        ret

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.dtc_ctl._.validate_and_convert_time ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     cl, 0x23
        ja      .error
        cmp     ch, 0x59
        ja      .error
        shl     ecx, 4
        cmp     cl, 0x90
        ja      .error
        cmp     ch, 0x92
        ja      .error
        shl     ecx, 4
        bswap   ecx ; 00HHMMSS
        cmp     cl, 0x59
        ja      .error
        shl     ecx, 4
        cmp     cl, 0x90
        ja      .error
        shr     ecx, 4

        clc
        ret

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.dtc_ctl._.start_stop_clock ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x0b
        out     dx, al
        inc     dx
        in      al, dx
        btc     ax, 7
        out     dx, al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_time ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 3
;-----------------------------------------------------------------------------------------------------------------------
        cli

    @@: mov     al, 10
        out     0x70, al
        in      al, 0x71
        test    al, al
        jns     @f
        mov     esi, 1
        call    delay_ms
        jmp     @b

    @@: xor     al, al ; seconds
        out     0x70, al
        in      al, 0x71
        movzx   ecx, al
        mov     al, 2 ; minutes
        shl     ecx, 16
        out     0x70, al
        in      al, 0x71
        movzx   edx, al
        mov     al, 4 ; hours
        shl     edx, 8
        out     0x70, al
        in      al, 0x71
        add     ecx, edx
        movzx   edx, al
        add     ecx, edx
        sti
        mov     [esp + 4 + regs_context32_t.eax], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_date ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 29
;-----------------------------------------------------------------------------------------------------------------------
        cli

    @@: mov     al, 10
        out     0x70, al
        in      al, 0x71
        test    al, al
        jns     @f
        mov     esi, 1
        call    delay_ms
        jmp     @b

    @@: mov     ch, 0
        mov     al, 7 ; date
        out     0x70, al
        in      al, 0x71
        mov     cl, al
        mov     al, 8 ; month
        shl     ecx, 16
        out     0x70, al
        in      al, 0x71
        mov     ch, al
        mov     al, 9 ; year
        out     0x70, al
        in      al, 0x71
        mov     cl, al

        sti
        mov     [esp + 4 + regs_context32_t.eax], ecx
        ret
kendp
