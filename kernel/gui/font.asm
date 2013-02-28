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

uglobal
  FONT_II rb 0xa00
  FONT_I  rb 0xa00
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.draw_text ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 4
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [TASK_BASE]
        mov     ebp, [eax - twdw + window_data_t.box.left]
        push    esi
        mov     esi, [current_slot]
        add     ebp, [esi + app_data_t.wnd_clientbox.left]
        shl     ebp, 16
        add     ebp, [eax - twdw + window_data_t.box.top]
        add     bp, word[esi + app_data_t.wnd_clientbox.top]
        pop     esi
        add     ebx, ebp
        mov     eax, edi
        xor     edi, edi
        jmp     dtext
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.draw_number ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 47
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pack[10(reserved), 6(number of digits to display), 8(number base), 8(number type)]
;>   al = 0 -> ebx is number
;>   al = 1 -> ebx is pointer
;>   ah = 0 -> display decimal
;>   ah = 1 -> display hexadecimal
;>   ah = 2 -> display binary
;> ebx = number or pointer
;> ecx = pack[16(x), 16(y)]
;> edx = color
;-----------------------------------------------------------------------------------------------------------------------
;# arguments are being shifted to match the description
;-----------------------------------------------------------------------------------------------------------------------
        ; It is not optimization
        mov     eax, ebx
        mov     ebx, ecx
        mov     ecx, edx
        mov     edx, esi
        mov     esi, edi

        xor     edi, edi

  .force:
        push    eax
        and     eax, 0x3fffffff
        cmp     eax, 0x0000ffff ; length > 0 ?
        pop     eax
        jge     .cont_displ
        ret

  .cont_displ:
        push    eax
        and     eax, 0x3fffffff
        cmp     eax, 61 shl 16 ; length <= 60 ?
        pop     eax
        jb      .cont_displ2
        ret

  .cont_displ2:
        pushad

        cmp     al, 1 ; ecx is a pointer ?
        jne     .displnl1
        mov     ebp, ebx
        add     ebp, 4
        mov     ebp, [ebp + new_app_base]
        mov     ebx, [ebx + new_app_base]

  .displnl1:
        sub     esp, 64

        test    ah, ah ; DECIMAL
        jnz     .no_display_desnum
        shr     eax, 16
        and     eax, 0xc03f
;       and     eax, 0x3f
        push    eax
        and     eax, 0x3f
        mov     edi, esp
        add     edi, 4 + 64 - 1
        mov     ecx, eax
        mov     eax, ebx
        mov     ebx, 10

  .d_desnum:
        xor     edx, edx
        call    division_64_bits
        div     ebx
        add     dl, '0'
        mov     [edi], dl
        dec     edi
        loop    .d_desnum

        pop     eax
        call    normalize_number
        call    draw_num_text
        add     esp, 64
        popad
        ret

  .no_display_desnum:
        cmp     ah, 0x01 ; HEXADECIMAL
        jne     .no_display_hexnum
        shr     eax, 16
        and     eax, 0xc03f
;       and     eax, 0x3f
        push    eax
        and     eax, 0x3f
        mov     edi, esp
        add     edi, 4 + 64 - 1
        mov     ecx, eax
        mov     eax, ebx
        mov     ebx, 16

  .d_hexnum:
        xor     edx, edx
        call    division_64_bits
        div     ebx

hexletters = __fdo_hexdigits

        add     edx, hexletters
        mov     dl, [edx]
        mov     [edi], dl
        dec     edi
        loop    .d_hexnum

        pop     eax
        call    normalize_number
        call    draw_num_text
        add     esp, 64
        popad
        ret

  .no_display_hexnum:
        cmp     ah, 0x02 ; BINARY
        jne     .no_display_binnum
        shr     eax, 16
        and     eax, 0xc03f
;       and     eax, 0x3f
        push    eax
        and     eax, 0x3f
        mov     edi, esp
        add     edi, 4 + 64 - 1
        mov     ecx, eax
        mov     eax, ebx
        mov     ebx, 2

  .d_binnum:
        xor     edx, edx
        call    division_64_bits
        div     ebx
        add     dl, '0'
        mov     [edi], dl
        dec     edi
        loop    .d_binnum

        pop     eax
        call    normalize_number
        call    draw_num_text
        add     esp, 64
        popad
        ret

  .no_display_binnum:
        add     esp, 64
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc normalize_number ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        test    ah, 0x080
        jz      .continue
        mov     ecx, '0'
        and     eax, 0x3f

    @@: inc     edi
        cmp     [edi], cl
        jne     .continue
        dec     eax
        cmp     eax, 1
        ja      @b

        mov     al, 1

  .continue:
        and     eax, 0x3f
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc division_64_bits ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        test    byte[esp + 1 + 4], 0x40
        jz      .continue
        push    eax
        mov     eax, ebp
        div     ebx
        mov     ebp, eax
        pop     eax

  .continue:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc draw_num_text ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, eax
        mov     edx, 64 + 4
        sub     edx, eax
        add     edx, esp
        mov     ebx, [esp + 64 + 32 - 8 + 4]

        ; add window start x & y
        mov     ecx, [TASK_BASE]

        mov     edi, [CURRENT_TASK]
        shl     edi, 8

        mov     eax, [ecx - twdw + window_data_t.box.left]
        add     eax, [SLOT_BASE + edi + app_data_t.wnd_clientbox.left]
        shl     eax, 16
        add     eax, [ecx - twdw + window_data_t.box.top]
        add     eax, [SLOT_BASE + edi + app_data_t.wnd_clientbox.top]
        add     ebx, eax
        mov     ecx, [esp + 64 + 32 - 12 + 4]
        and     ecx, not 0x80000000 ; force counted string
        mov     eax, [esp + 64 + 8] ; background color (if given)
        mov     edi, [esp + 64 + 4]
        jmp     dtext
kendp

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
