;;======================================================================================================================
;;///// cdrom.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2007 KolibriOS team <http://kolibrios.org/>
;; (c) 2000-2004 MenuetOS <http://menuetos.net/>
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
  cdbase rw 1
  cdid   rw 1
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_cd_atapi_command ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushad

        mov     dx, [cdbase]
        add     dx, 6
        mov     ax, [cdid]
        out     dx, al
        mov     esi, 10
        call    delay_ms
        mov     dx, [cdbase]
        add     dx, 7
        in      al, dx
        and     al, 0x80
        cmp     al, 0
        jnz     .res
        jmp     .cdl6

  .res:
        mov     dx, [cdbase]
        add     dx, 7
        mov     al, 0x08
        out     dx, al
        mov     dx, [cdbase]
        add     dx, 0x206
        mov     al, 0x0e
        out     dx, al
        mov     esi, 1
        call    delay_ms
        mov     dx, [cdbase]
        add     dx, 0x206
        mov     al, 0x08
        out     dx, al
        mov     esi, 30
        call    delay_ms
        xor     cx, cx

  .cdl5:
        inc     cx
        cmp     cx, 10
        jz      .cdl6
        mov     dx, [cdbase]
        add     dx, 7
        in      al, dx
        and     al, 0x88
        cmp     al, 0x00
        jz      .cdl5
        mov     esi, 100
        call    delay_ms
        jmp     .cdl5

  .cdl6:
        mov     dx, [cdbase]
        add     dx, 4
        mov     al, 0
        out     dx, al
        mov     dx, [cdbase]
        add     dx, 5
        mov     al, 0
        out     dx, al
        mov     dx, [cdbase]
        add     dx, 7
        mov     al, 0xec
        out     dx, al
        mov     esi, 5
        call    delay_ms
        mov     dx, [cdbase]
        add     dx, 1
        mov     al, 0
        out     dx, al
        add     dx, 1
        mov     al, 0
        out     dx, al
        add     dx, 1
        mov     al, 0
        out     dx, al
        add     dx, 1
        mov     al, 0
        out     dx, al
        add     dx, 1
        mov     al, 128
        out     dx, al
        add     dx, 2
        mov     al, 0xa0
        out     dx, al
        xor     cx, cx
        mov     dx, [cdbase]
        add     dx, 7

  .cdl1:
        inc     cx
        cmp     cx, 100
        jz      .cdl2
        in      al, dx
        and     ax, 0x88
        cmp     al, 0x08
        jz      .cdl2
        mov     esi, 2
        call    delay_ms
        jmp     .cdl1

  .cdl2:
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_cdplay ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [cdbase], 0
        jnz     @f
        mov     eax, 1
        ret

    @@: mov     ax, 5
        push    ax
        push    ebx

  .cdplay:
        call    sys_cd_atapi_command
        cli
        mov     dx, [cdbase]
        mov     ax, 0x0047
        out     dx, ax
        mov     al, 1
        mov     ah, [esp + 0] ; min xx
        out     dx, ax
        mov     ax, [esp + 1] ; fr sec
        out     dx, ax
        mov     ax, 256 + 99
        out     dx, ax
        mov     ax, 0x0001
        out     dx, ax
        mov     ax, 0x0000
        out     dx, ax
        mov     esi, 10
        call    delay_ms
        sti
        add     dx, 7
        in      al, dx
        test    al, 1
        jz      .cdplayok
        mov     ax, [esp + 4]
        dec     ax
        mov     [esp + 4], ax
        cmp     ax, 0
        jz      .cdplayfail
        jmp     .cdplay

  .cdplayfail:
  .cdplayok:
        pop     ebx
        pop     ax
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_cdtracklist ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [cdbase], 0
        jnz     @f
        mov     eax, 1
        ret

    @@:push    ebx

  .tcdplay:
        call     sys_cd_atapi_command
        mov      dx, [cdbase]
        mov      ax, 0x43 + 2 * 256
        out      dx, ax
        mov      ax, 0
        out      dx, ax
        mov      ax, 0
        out      dx, ax
        mov      ax, 0
        out      dx, ax
        mov      ax, 200
        out      dx, ax
        mov      ax, 0
        out      dx, ax
        in       al, dx
        mov      cx, 1000
        mov      dx, [cdbase]
        add      dx, 7

  .cdtrnwewait:
        mov     esi, 10
        call    delay_ms
        in      al, dx
        and     al, 128
        cmp     al, 0
        jz      .cdtrl1
        loop    .cdtrnwewait

  .cdtrl1:
        ; read the result
        mov     ecx, [esp + 0]
        mov     dx, [cdbase]

  .cdtrread:
        add     dx, 7
        in      al, dx
        and     al, 8
        cmp     al, 8
        jnz     .cdtrdone
        sub     dx, 7
        in      ax, dx
        mov     [ecx], ax
        add     ecx, 2
        jmp     .cdtrread

  .cdtrdone:
        pop     ecx
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_cdpause ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [cdbase], 0
        jnz     @f
        mov     eax, 1
        ret

    @@:call    sys_cd_atapi_command

        mov     dx, [cdbase]
        mov     ax, 0x004b
        out     dx, ax
        mov     ax, 0
        out     dx, ax
        mov     ax, 0
        out     dx, ax
        mov     ax, 0
        out     dx, ax
        mov     ax, 0
        out     dx, ax
        mov     ax, 0
        out     dx, ax

        mov     esi, 10
        call    delay_ms
        add     dx, 7
        in      al, dx

        xor     eax, eax
        ret
kendp
