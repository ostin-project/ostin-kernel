;;======================================================================================================================
;;///// font.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
kproc dtext_asciiz_esi ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# for skins title out
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        xor     eax, eax
        inc     eax
        jmp     dtext.1
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc dtext ;///////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Text String Output
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = x & y
;> ecx = pack[1(A), 1(B), 2(font), 4(-), 24(color, 0xRRGGBB)]
;>   A = 0 (output esi characters) or 1 (output ASCIIZ string)
;>   B = 0 (don't fill background) or 1 (fill background with color eax)
;> edx = start of text
;> edi = 1 force
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        xor     eax, eax

  .1:
        pushad
        call    [_display.disable_mouse]

        movsx   eax, bx ; eax=y
        sar     ebx, 16 ; ebx=x
        xchg    eax, ebx ; eax=x, ebx=y
        cmp     esi, 255
        jb      .loop
        mov     esi, 255

  .loop:
        test    ecx, ecx
        js      .test_asciiz
        dec     esi
        js      .end
        jmp     @f

  .test_asciiz:
        cmp     byte[edx], 0
        jz      .end
        cmp     [esp + regs_context32_t.al], 1
        jne     @f
        dec     esi
        js      .end

    @@: inc     edx
        pushad
        movzx   edx, byte[edx - 1]
        test    ecx, 0x10000000
        jnz     .font2
        mov     esi, 9
        lea     ebp, [FONT_I + 8 * edx + edx]

  .symloop1:
        mov     dl, byte[ebp]
        or      dl, 1 shl 6

  .pixloop1:
        shr     dl, 1
        jz      .pixloop1end
        jnc     .nopix
        call    [putpixel]
        jmp     .pixloop1cont

  .nopix:
        test    ecx, 0x40000000
        jz      .pixloop1cont
        push    ecx
        mov     ecx, [esp + 4 + 0x20 + 0x20]
        call    [putpixel]
        pop     ecx

  .pixloop1cont:
        inc     eax
        jmp     .pixloop1

  .pixloop1end:
        sub     eax, 6
        inc     ebx
        inc     ebp
        dec     esi
        jnz     .symloop1
        popad
        add     eax, 6
        jmp     .loop

  .font2:
        add     edx, edx
        lea     ebp, [FONT_II + 4 * edx + edx + 1]
        push    9
        movzx   esi, byte[ebp - 1]

  .symloop2:
        mov     dl, byte[ebp]
        push    esi

  .pixloop2:
        shr     dl, 1
        jnc     .nopix2
        call    [putpixel]
        jmp     .pixloop2cont

  .nopix2:
        test    ecx, 0x40000000
        jz      .pixloop2cont
        push    ecx
        mov     ecx, [esp + 12 + 0x20 + 0x20]
        call    [putpixel]
        pop     ecx

  .pixloop2cont:
        inc     eax
        dec     esi
        jnz     .pixloop2
        pop     esi
        sub     eax, esi
        inc     ebx
        inc     ebp
        dec     dword[esp]
        jnz     .symloop2
        pop     eax
        add     [esp + regs_context32_t.eax], esi
        popad
        jmp     .loop

  .end:
        popad
        pop     eax
        ret
kendp
