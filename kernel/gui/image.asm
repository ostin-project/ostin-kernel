;;======================================================================================================================
;;///// image.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2007-2009 KolibriOS team <http://kolibrios.org/>
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
kproc sysfn.put_image ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 7
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, 0x80008000
        jnz     .exit
        test    ecx, 0x0000ffff
        jz      .exit
        test    ecx, 0xffff0000
        jnz     @f

  .exit:
        ret

    @@: mov     edi, [current_slot_ptr]
        add     dx, word[edi + legacy.slot_t.app.wnd_clientbox.top]
        rol     edx, 16
        add     dx, word[edi + legacy.slot_t.app.wnd_clientbox.left]
        rol     edx, 16

  .forced:
        push    ebp esi 0
        mov     ebp, putimage_get24bpp
        mov     esi, putimage_init24bpp
kendp

kproc sys_putimage_bpp
;       call    [disable_mouse] ; this will be done in xxx_putimage
;       mov     eax, vga_putimage
        cmp     [SCR_MODE], 0x12
        jz      @f
        mov     eax, vesa12_putimage
        cmp     [SCR_MODE], 0100000000000000b
        jae     @f
        cmp     [SCR_MODE], 0x13
        jnz     .doit

    @@: mov     eax, vesa20_putimage

  .doit:
        inc     [mouse_pause]
        call    eax
        dec     [mouse_pause]
        pop     ebp esi ebp
        jmp     [draw_pointer]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.put_image_with_palette ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 65
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to image
;> ecx = pack[16(xsize), 16(ysize)]
;> edx = pack[16(xstart), 16(ystart)]
;> esi = number of bits per pixel, must be 8, 24 or 32
;> edi = pointer to palette
;> ebp = row delta
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [current_slot]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        add     dx, word[legacy_slots + eax + legacy.slot_t.app.wnd_clientbox.top]
        rol     edx, 16
        add     dx, word[legacy_slots + eax + legacy.slot_t.app.wnd_clientbox.left]
        rol     edx, 16

  .forced:
        cmp     esi, 1
        jnz     @f
        push    edi
        mov     eax, [edi + 4]
        sub     eax, [edi]
        push    eax
        push    dword[edi]
        push    0xffffff80
        mov     edi, esp
        call    .put_mono_image
        add     esp, 12
        pop     edi
        ret

    @@: cmp     esi, 2
        jnz     @f
        push    edi
        push    0xffffff80
        mov     edi, esp
        call    .put_2bit_image
        pop     eax
        pop     edi
        ret

    @@: cmp     esi, 4
        jnz     @f
        push    edi
        push    0xffffff80
        mov     edi, esp
        call    .put_4bit_image
        pop     eax
        pop     edi
        ret

    @@: push    ebp esi ebp
        cmp     esi, 8
        jnz     @f
        mov     ebp, putimage_get8bpp
        mov     esi, putimage_init8bpp
        jmp     sys_putimage_bpp

    @@: cmp     esi, 15
        jnz     @f
        mov     ebp, putimage_get15bpp
        mov     esi, putimage_init15bpp
        jmp     sys_putimage_bpp

    @@: cmp     esi, 16
        jnz     @f
        mov     ebp, putimage_get16bpp
        mov     esi, putimage_init16bpp
        jmp     sys_putimage_bpp

    @@: cmp     esi, 24
        jnz     @f
        mov     ebp, putimage_get24bpp
        mov     esi, putimage_init24bpp
        jmp     sys_putimage_bpp

    @@: cmp     esi, 32
        jnz     @f
        mov     ebp, putimage_get32bpp
        mov     esi, putimage_init32bpp
        jmp     sys_putimage_bpp

    @@: pop     ebp esi ebp
        ret

  .put_mono_image:
        push    ebp esi ebp
        mov     ebp, putimage_get1bpp
        mov     esi, putimage_init1bpp
        jmp     sys_putimage_bpp

  .put_2bit_image:
        push    ebp esi ebp
        mov     ebp, putimage_get2bpp
        mov     esi, putimage_init2bpp
        jmp     sys_putimage_bpp

  .put_4bit_image:
        push    ebp esi ebp
        mov     ebp, putimage_get4bpp
        mov     esi, putimage_init4bpp
        jmp     sys_putimage_bpp
kendp

kproc putimage_init24bpp
        lea     eax, [eax * 3]
kendp

kproc putimage_init8bpp
        ret
kendp

align 16
kproc putimage_get24bpp
        movzx   eax, byte[esi + 2]
        shl     eax, 16
        mov     ax, [esi]
        add     esi, 3
        ret     4
kendp

align 16
kproc putimage_get8bpp
        movzx   eax, byte[esi]
        push    edx
        mov     edx, [esp + 8]
        mov     eax, [edx + eax * 4]
        pop     edx
        inc     esi
        ret     4
kendp

kproc putimage_init1bpp
        add     eax, ecx
        push    ecx
        add     eax, 7
        add     ecx, 7
        shr     eax, 3
        shr     ecx, 3
        sub     eax, ecx
        pop     ecx
        ret
kendp

align 16
kproc putimage_get1bpp
        push    edx
        mov     edx, [esp + 8]
        mov     al, [edx]
        add     al, al
        jnz     @f
        lodsb
        adc     al, al

    @@: mov     [edx], al
        sbb     eax, eax
        and     eax, [edx + 8]
        add     eax, [edx + 4]
        pop     edx
        ret     4
kendp

kproc putimage_init2bpp
        add     eax, ecx
        push    ecx
        add     ecx, 3
        add     eax, 3
        shr     ecx, 2
        shr     eax, 2
        sub     eax, ecx
        pop     ecx
        ret
kendp

align 16
kproc putimage_get2bpp
        push    edx
        mov     edx, [esp + 8]
        mov     al, [edx]
        mov     ah, al
        shr     al, 6
        shl     ah, 2
        jnz     .nonewbyte
        lodsb
        mov     ah, al
        shr     al, 6
        shl     ah, 2
        add     ah, 1

  .nonewbyte:
        mov     [edx], ah
        mov     edx, [edx + 4]
        movzx   eax, al
        mov     eax, [edx + eax * 4]
        pop     edx
        ret     4
kendp

kproc putimage_init4bpp
        add     eax, ecx
        push    ecx
        add     ecx, 1
        add     eax, 1
        shr     ecx, 1
        shr     eax, 1
        sub     eax, ecx
        pop     ecx
        ret
kendp

align 16
kproc putimage_get4bpp
        push    edx
        mov     edx, [esp + 8]
        add     byte[edx], 0x80
        jc      @f
        movzx   eax, byte[edx + 1]
        mov     edx, [edx + 4]
        and     eax, 0x0f
        mov     eax, [edx + eax * 4]
        pop     edx
        ret     4

    @@: movzx   eax, byte[esi]
        add     esi, 1
        mov     [edx + 1], al
        shr     eax, 4
        mov     edx, [edx + 4]
        mov     eax, [edx + eax * 4]
        pop     edx
        ret     4
kendp

kproc putimage_init32bpp
        shl     eax, 2
        ret
kendp

align 16
kproc putimage_get32bpp
        lodsd
        ret     4
kendp

kproc putimage_init15bpp
kendp

kproc putimage_init16bpp
        add     eax, eax
        ret
kendp

align 16
kproc putimage_get15bpp
; 0RRRRRGGGGGBBBBB -> 00000000RRRRR000GGGGG000BBBBB000
        push    ecx edx
        movzx   eax, word[esi]
        add     esi, 2
        mov     ecx, eax
        mov     edx, eax
        and     eax, 0x1f
        and     ecx, 0x1f shl 5
        and     edx, 0x1f shl 10
        shl     eax, 3
        shl     ecx, 6
        shl     edx, 9
        or      eax, ecx
        or      eax, edx
        pop     edx ecx
        ret     4
kendp

align 16
kproc putimage_get16bpp
; RRRRRGGGGGGBBBBB -> 00000000RRRRR000GGGGGG00BBBBB000
        push    ecx edx
        movzx   eax, word[esi]
        add     esi, 2
        mov     ecx, eax
        mov     edx, eax
        and     eax, 0x1f
        and     ecx, 0x3f shl 5
        and     edx, 0x1f shl 11
        shl     eax, 3
        shl     ecx, 5
        shl     edx, 8
        or      eax, ecx
        or      eax, edx
        pop     edx ecx
        ret     4
kendp
