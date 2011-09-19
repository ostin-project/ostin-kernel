;;======================================================================================================================
;;///// vesa12.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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

TRIDENT     equ 0
S3_VIDEO    equ 0
INTEL_VIDEO equ 0

if TRIDENT
  if S3_VIDEO or INTEL_VIDEO
    stop
  end if
end if

if S3_VIDEO
  if TRIDENT or INTEL_VIDEO
    stop
  end if
end if

if INTEL_VIDEO
  if S3_VIDEO or TRIDENT
    stop
  end if
end if

; A complete video driver should include the following types of function
;
; Putpixel
; Getpixel
;
; Drawimage
; Drawbar
;
; Drawbackground
;
; Modifying the set_bank -function is mostly enough
; for different Vesa 1.2 setups.


if TRIDENT

;-----------------------------------------------------------------------------------------------------------------------
kproc set_bank ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? set_bank for Trident videocards, work on Trident 9440
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli
        cmp     al, [BANK_RW]
        je      .retsb

        mov     [BANK_RW], al
        push    dx
        mov     dx, 0x3d8
        out     dx, al
        pop     dx

  .retsb:
        popfd
        ret
kendp

else if S3_VIDEO

;-----------------------------------------------------------------------------------------------------------------------
kproc set_bank ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? set_bank for S3 videocards, work on S3 ViRGE PCI (325)
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli
        cmp     al, [BANK_RW]
        je      .retsb

        mov     [BANK_RW], al
        push    ax
        push    dx
        push    cx
        mov     cl, al
        mov     dx, 0x3d4
        mov     al, 0x38
        out     dx, al ; CR38 Register Lock 1; Note: Traditionally 48h is used to unlock and 00h to lock
        inc     dx
        mov     al, 0x48
        out     dx, al ; 3d5 -?
        dec     dx
        mov     al, 0x31
        out     dx, al ; CR31 Memory Configuration Register
        ; 0  Enable Base Address Offset (CPUA BASE). Enables bank operation if set, disables if clear.
        ; 4-5  Bit 16-17 of the Display Start Address. For the 801/5,928 see index 51h, for the 864/964 see index 69h.

        inc     dx
        in      al, dx
        dec     dx
        mov     ah, al
        mov     al, 0x31
        out     dx, ax
        mov     al, ah
        or      al, 9
        inc     dx
        out     dx, al
        dec     dx
        mov     al, 0x35
        out     dx, al ; CR35 CRT Register Lock
        inc     dx
        in      al, dx
        dec     dx
        and     al, 0xf0
        mov     ch, cl
        and     ch, 0x0f
        or      ch, al
        mov     al, 0x35
        out     dx, al
        inc     dx
        mov     al, ch
        out     dx, ax
        dec     dx
        mov     al, 0x51 ; Extended System Control 2 Register
        out     dx, al
        inc     dx
        in      al, dx
        dec     dx
        and     al, 0xf3
        shr     cl, 2
        and     cl, 0x0c
        or      cl, al
        mov     al, 0x51
        out     dx, al
        inc     dx
        mov     al, cl
        out     dx, al
        dec     dx
        mov     al, 0x38
        out     dx, al
        inc     dx
        xor     al, al
        out     dx, al
        dec     dx
        pop     cx
        pop     dx
        pop     ax

  .retsb:
        popfd
        ret
kendp

else if INTEL_VIDEO

;-----------------------------------------------------------------------------------------------------------------------
kproc set_bank ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Set bank function for Intel 810/815 chipsets
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli

        cmp     al, [BANK_RW]
        je      .retsb

        mov     [BANK_RW], al
        push    ax
        push    dx
        mov     dx, 0x3ce
        mov     ah, al ; Save value for later use
        mov     al, 0x10 ; Index GR10 (Address Mapping)
        out     dx, al ; Select GR10
        inc     dl
        mov     al, 3 ; Set bits 0 and 1 (Enable linear page mapping)
        out     dx, al ; Write value
        dec     dl
        mov     al, 0x11 ; Index GR11 (Page Selector)
        out     dx, al ; Select GR11
        inc     dl
        mov     al, ah ; Write address
        out     dx, al ; Write the value
        pop     dx
        pop     ax

  .retsb:
        popfd
        ret
kendp

else

;-----------------------------------------------------------------------------------------------------------------------
kproc set_bank ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli

        cmp     al, [BANK_RW]
        je      .retsb

        mov     [BANK_RW], al
        push    ax
        push    dx
        mov     ah, al
        mov     dx, 0x3d4
        mov     al, 0x39
        out     dx, al
        inc     dl
        mov     al, 0xa5
        out     dx, al
        dec     dl
        mov     al, 0x6a
        out     dx, al
        inc     dl
        mov     al, ah
        out     dx, al
        dec     dl
        mov     al, 0x39
        out     dx, al
        inc     dl
        mov     al, 0x5a
        out     dx, al
        dec     dl
        pop     dx
        pop     ax

  .retsb:
        popfd
        ret
kendp

end if

;-----------------------------------------------------------------------------------------------------------------------
kproc vesa12_drawbackground ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    [_display.disable_mouse]

        push    eax
        push    ebx
        push    ecx
        push    edx

        xor     edx, edx
        mov     eax, dword[BgrDataWidth]
        mov     ebx, dword[BgrDataHeight]
        mul     ebx
        mov     ebx, 3
        mul     ebx
        mov     [imax], eax
        mov     eax, [draw_data + 32 + rect32_t.left]
        mov     ebx, [draw_data + 32 + rect32_t.top]
        xor     edi, edi ; no force

  .v12dp3:
        push    eax
        push    ebx

        cmp     dword[BgrDrawMode], 1 ; tiled background
        jne     .no_vesa12_tiled_bgr

        push    edx

        xor     edx, edx
        div     dword[BgrDataWidth]

        push    edx
        mov     eax, ebx
        xor     edx, edx
        div     dword[BgrDataHeight]
        mov     ebx, edx
        pop     eax

        pop     edx

  .no_vesa12_tiled_bgr:
        cmp     dword[BgrDrawMode], 2 ; stretched background
        jne     .no_vesa12_stretched_bgr

        push    edx

        mul     dword[BgrDataWidth]
        mov     ecx, [Screen_Max_X]
        inc     ecx
        div     ecx

        push    eax
        mov     eax, ebx
        mul     dword[BgrDataHeight]
        mov     ecx, [Screen_Max_Y]
        inc     ecx
        div     ecx
        mov     ebx, eax
        pop     eax

        pop     edx

  .no_vesa12_stretched_bgr:
        mov     esi, ebx
        imul    esi, dword[BgrDataWidth]
        add     esi, eax
        lea     esi, [esi * 3]
        add     esi, [img_background] ; IMG_BACKGROUND
        pop     ebx
        pop     eax

  .v12di4:
        mov     cl, [esi + 2]
        shl     ecx, 16
        mov     cx, [esi]
        pusha
        mov     esi, eax
        mov     edi, ebx
        mov     eax, [Screen_Max_X]
        add     eax, 1
        mul     ebx
        add     eax, [_WinMapAddress]
        cmp     byte[eax + esi], 1
        jnz     .v12nbgp
        mov     eax, [BytesPerScanLine]
        mov     ebx, edi
        mul     ebx
        add     eax, esi
        lea     eax, [VGABasePtr + eax + esi * 2]
        cmp     byte[ScreenBPP], 24
        jz      .v12bgl3
        add     eax, esi

  .v12bgl3:
        push    ebx
        push    eax

        sub     eax, VGABasePtr

        shr     eax, 16
        call    set_bank
        pop     eax
        and     eax, 65535
        add     eax, VGABasePtr
        pop     ebx

        mov     [eax], cx
        add     eax, 2
        shr     ecx, 16
        mov     [eax], cl
        sti

  .v12nbgp:
        popa
        add     esi, 3
        inc     eax
        cmp     eax, [draw_data + 32 + rect32_t.right]
        jg      .v12nodp31
        jmp     .v12dp3

  .v12nodp31:
        mov     eax, [draw_data + 32 + rect32_t.left]
        inc     ebx
        cmp     ebx, [draw_data + 32 + rect32_t.bottom]
        jg      .v12dp4
        jmp     .v12dp3

  .v12dp4:
        pop     edx
        pop     ecx
        pop     ebx
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc vesa12_drawbar ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    [_display.disable_mouse]

;;      mov     dword[novesachecksum], 0
        sub     edx, ebx
        sub     ecx, eax
        push    esi
        push    edi
        push    eax
        push    ebx
        push    ecx
        push    edx
        mov     ecx, [TASK_BASE]
        add     eax, [ecx - twdw + window_data_t.box.left]
        add     ebx, [ecx - twdw + window_data_t.box.top]
        push    eax
        mov     eax, ebx ; y
        mov     ebx, [BytesPerScanLine]
        mul     ebx
        pop     ecx
        add     eax, ecx ; x
        add     eax, ecx
        add     eax, ecx
        cmp     byte[ScreenBPP], 24 ; 24 or 32 bpp ? - x start
        jz      .dbpi2412
        add     eax, ecx

  .dbpi2412:
        add     eax, VGABasePtr
        mov     edi, eax

        ; x size

        mov     eax, [esp + 4] ; [esp + 6]
        mov     ecx, eax
        add     ecx, eax
        add     ecx, eax
        cmp     byte[ScreenBPP], 24 ; 24 or 32 bpp ? - x size
        jz      .dbpi24312
        add     ecx, eax

  .dbpi24312:
        mov     ebx, [esp + 0]

        ; check limits ?

        push    eax
        push    ecx
        mov     eax, [TASK_BASE]
        mov     ecx, [eax + draw_data - CURRENT_TASK + rect32_t.left]
        cmp     ecx, 0
        jnz     .dbcblimitlset12
        mov     ecx, [eax + draw_data - CURRENT_TASK + rect32_t.top]
        cmp     ecx, 0
        jnz     .dbcblimitlset12
        mov     ecx, [eax + draw_data - CURRENT_TASK + rect32_t.right]
        cmp     ecx, [Screen_Max_X]
        jnz     .dbcblimitlset12
        mov     ecx, [eax + draw_data - CURRENT_TASK + rect32_t.bottom]
        cmp     ecx, [Screen_Max_Y]
        jnz     .dbcblimitlset12
        pop     ecx
        pop     eax
        push    0
        jmp     .dbcblimitlno12

  .dbcblimitlset12:
        pop     ecx
        pop     eax
        push    1

  .dbcblimitlno12:
        cmp     byte[ScreenBPP], 24     ; 24 or 32 bpp ?
        jz      dbpi24bit12
        jmp     dbpi32bit12
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc dbpi24bit12 ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? DRAWBAR 24 BBP
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    ebx
        push    edx
        mov     eax, ecx
        mov     ebx, 3
        div     ebx
        mov     ecx, eax
        pop     edx
        pop     ebx
        pop     eax
        cld

  .dbnewpi12:
        push    ebx
        push    edi
        push    ecx

        xor     edx, edx
        mov     eax, edi
        sub     eax, VGABasePtr
        mov     ebx, 3
        div     ebx
        add     eax, [_WinMapAddress]
        mov     ebx, [CURRENT_TASK]
        cld

  .dbnp2412:
        mov     dl, [eax]
        push    eax
        push    ecx
        cmp     dl, bl
        jnz     .dbimp24no12
        cmp     dword[esp + 5 * 4], 0
        jz      .dbimp24yes12
;       call    dbcplimit
;       jnz     .dbimp24no12

  .dbimp24yes12:
        push    edi
        mov     eax, edi
        sub     eax, VGABasePtr
        shr     eax, 16
        call    set_bank
        and     edi, 0xffff
        add     edi, VGABasePtr
        mov     eax, [esp + 8 + 3 * 4 + 16 + 4 + 4]
        stosw
        shr     eax, 16
        stosb
        sti
        pop     edi
        add     edi, 3
        pop     ecx
        pop     eax
        inc     eax
        loop    .dbnp2412
        jmp     .dbnp24d12

  .dbimp24no12:
        pop     ecx
        pop     eax
        cld
        add     edi, 3
        inc     eax
        loop    .dbnp2412

  .dbnp24d12:
        mov     eax, [esp + 3 * 4 + 16 + 4]
        test    eax, 0x80000000
        jz      .nodbgl2412
        cmp     al, 0
        jz      .nodbgl2412
        dec     eax
        mov     [esp + 3 * 4 + 16 + 4], eax

  .nodbgl2412:
        pop     ecx
        pop     edi
        pop     ebx
        add     edi, [BytesPerScanLine]
        dec     ebx
        jz      .dbnonewpi12
        jmp     .dbnewpi12

  .dbnonewpi12:
        add     esp, 7 * 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc dbpi32bit12 ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? DRAWBAR 32 BBP
;-----------------------------------------------------------------------------------------------------------------------
        cld
        shr     ecx, 2

  .dbnewpi3212:
        push    ebx
        push    edi
        push    ecx

        mov     eax, edi
        sub     eax, VGABasePtr
        shr     eax, 2
        add     eax, [_WinMapAddress]
        mov     ebx, [CURRENT_TASK]
        cld

  .dbnp3212:
        mov     dl, [eax]
        push    eax
        push    ecx
        cmp     dl, bl
        jnz     .dbimp32no12
        cmp     dword[esp + 5 * 4], 0
        jz      .dbimp32yes12
;       call    dbcplimit
;       jnz     .dbimp32no12

  .dbimp32yes12:
        push    edi
        mov     eax, edi
        sub     eax, VGABasePtr
        shr     eax, 16
        call    set_bank
        and     edi, 0xffff
        add     edi, VGABasePtr
        mov     eax, [esp + 8 + 3 * 4 + 16 + 4 + 4]
        stosw
        shr     eax, 16
        stosb
        sti
        pop     edi
        add     edi, 4
        inc     ebp
        pop     ecx
        pop     eax
        inc     eax
        loop    .dbnp3212
        jmp     .dbnp32d12

  .dbimp32no12:
        pop     ecx
        pop     eax
        inc     eax
        add     edi, 4
        inc     ebp
        loop    .dbnp3212

  .dbnp32d12:
        mov     eax, [esp + 12 + 16 + 4]
        test    eax, 0x80000000
        jz      .nodbgl3212
        cmp     al, 0
        jz      .nodbgl3212
        dec     eax
        mov     [esp + 12 + 16 + 4], eax

  .nodbgl3212:
        pop     ecx
        pop     edi
        pop     ebx
        add     edi, [BytesPerScanLine]
        dec     ebx
        jz      .nodbnewpi3212
        jmp     .dbnewpi3212

  .nodbnewpi3212:
        add     esp, 7 * 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Vesa12_putpixel24 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, eax ; x
        mov     eax, ebx ; y
        lea     edi, [edi + edi * 2]
        mov     ebx, [BytesPerScanLine]
        mul     ebx
        add     edi, eax
        mov     eax, edi
        shr     eax, 16
        call    set_bank
        and     edi, 65535
        add     edi, VGABasePtr
        mov     eax, [esp + 28]
        stosw
        shr     eax, 16
        mov     [edi], al
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Vesa12_putpixel32 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, eax ; x
        mov     eax, ebx ; y
        shl     edi, 2
        mov     ebx, [BytesPerScanLine]
        mul     ebx
        add     edi, eax
        mov     eax, edi
        shr     eax, 16
        call    set_bank
        and     edi, 65535
        add     edi, VGABasePtr
        mov     ecx, [esp + 28]
        mov     [edi], ecx
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Vesa12_getpixel24 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, eax ; x
        mov     eax, ebx ; y
        lea     edi, [edi + edi * 2]
        mov     ebx, [BytesPerScanLine]
        mul     ebx
        add     edi, eax
        mov     eax, edi
        shr     eax, 16
        call    set_bank
        and     edi, 65535
        add     edi, VGABasePtr
        mov     ecx, [edi]
        and     ecx, 255 * 256 * 256 + 255 * 256 + 255
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Vesa12_getpixel32 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, eax ; x
        mov     eax, ebx ; y
        shl     edi, 2
        mov     ebx, [BytesPerScanLine]
        xor     edx, edx
        mul     ebx
        add     edi, eax
        mov     eax, edi
        shr     eax, 16
        call    set_bank
        and     edi, 65535
        add     edi, VGABasePtr
        mov     ecx, [edi]
        and     ecx, 255 * 256 * 256 + 255 * 256 + 255
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc vesa12_putimage ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to image
;> ecx = size [x|y]
;> edx = coordinates [x|y]
;> ebp = pointer to 'get' function
;> esi = pointer to 'init' function
;> edi = parameter for 'get' function
;-----------------------------------------------------------------------------------------------------------------------
;       mov     ebx, image
;       mov     ecx, 320 * 65536 + 240
;       mov     edx, 20 * 65536 + 20

        call    [_display.disable_mouse]

        mov     dword[novesachecksum], 0
        push    esi
        push    edi
        push    eax
        push    ebx
        push    ecx
        push    edx
        movzx   eax, word[esp + 2]
        movzx   ebx, word[esp + 0]
        mov     ecx, [TASK_BASE]
        add     eax, [ecx - twdw + window_data_t.box.left]
        add     ebx, [ecx - twdw + window_data_t.box.top]
        push    eax
        mov     eax, ebx ; y
        mul     dword[BytesPerScanLine]
        pop     ecx
        add     eax, ecx ; x
        add     eax, ecx
        add     eax, ecx
        cmp     byte[ScreenBPP], 24 ; 24 or 32 bpp ? - x start
        jz      .pi2412
        add     eax, ecx

  .pi2412:
        add     eax, VGABasePtr
        mov     edi, eax

        ; x size

        movzx   ecx, word[esp + 6]

        mov     esi, [esp + 8]
        movzx   ebx, word[esp + 4]

        ; check limits while draw ?

        push    ecx
        mov     eax, [TASK_BASE]
        cmp     dword[eax + draw_data - CURRENT_TASK + rect32_t.left], 0
        jnz     .dbcblimitlset212
        cmp     dword[eax + draw_data - CURRENT_TASK + rect32_t.top], 0
        jnz     .dbcblimitlset212
        mov     ecx, [eax + draw_data - CURRENT_TASK + rect32_t.right]
        cmp     ecx, [Screen_Max_X]
        jnz     .dbcblimitlset212
        mov     ecx, [eax + draw_data - CURRENT_TASK + rect32_t.bottom]
        cmp     ecx, [Screen_Max_Y]
        jnz     .dbcblimitlset212
        pop     ecx
        push    0
        jmp     .dbcblimitlno212

  .dbcblimitlset212:
        pop     ecx
        push    1

  .dbcblimitlno212:
        cmp     byte[ScreenBPP], 24 ; 24 or 32 bpp ?
        jnz     pi32bit12
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pi24bit12 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
  .newpi12:
        push    edi
        push    ecx
        push    ebx

        mov     edx, edi
        sub     edx, VGABasePtr
        mov     ebx, 3
        div     ebx
        add     edx, [_WinMapAddress]
        mov     ebx, [CURRENT_TASK]
        mov     bh, [esp + 4 * 3]

  .np2412:
        cmp     bl, [edx]
        jnz     .imp24no12
;       mov     eax, [esi]
        push    dword[esp + 4 * 3 + 20]
        call    ebp
;       cmp     bh, 0
;       jz      .imp24yes12
;       call    dbcplimit
;       jnz     .imp24no12

  .imp24yes12:
        push    edi
        push    eax
        mov     eax, edi
        sub     eax, VGABasePtr
        shr     eax, 16
        call    set_bank
        pop     eax
        and     edi, 0xffff
        add     edi, VGABasePtr
        mov     [edi], ax
        shr     eax, 16
        mov     [edi + 2], al
        pop     edi

  .imp24no12:
        inc     edx
;       add     esi, 3
        add     edi, 3
        dec     ecx
        jnz     .np2412

  .np24d12:
        pop     ebx
        pop     ecx
        pop     edi

        add     edi, [BytesPerScanLine]
        add     esi, [esp + 32]
        cmp     ebp, putimage_get1bpp
        jz      .correct
        cmp     ebp, putimage_get2bpp
        jz      .correct
        cmp     ebp, putimage_get4bpp
        jnz     @f

  .correct:
        mov     eax, [esp + 20]
        mov     byte[eax], 0x80

    @@: dec     ebx
        jnz     .newpi12

  .nonewpi12:
        pop     eax edx ecx ebx eax edi esi
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pi32bit12 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
  .newpi3212:
        push    edi
        push    ecx
        push    ebx

        mov     edx, edi
        sub     edx, VGABasePtr
        shr     edx, 2
        add     edx, [_WinMapAddress]
        mov     ebx, [CURRENT_TASK]
        mov     bh, [esp + 4 * 3]

  .np3212:
        cmp     bl, [edx]
        jnz     .imp32no12
;       mov     eax, [esi]
        push    dword[esp + 4 * 3 + 20]
        call    ebp
;       cmp     bh, 0
;       jz      .imp32yes12
;       call    dbcplimit
;       jnz     .imp32no12

  .imp32yes12:
        push    edi
        push    eax
        mov     eax, edi
        sub     eax, VGABasePtr
        shr     eax, 16
        call    set_bank
        pop     eax
        and     edi, 0xffff
        mov     [edi + VGABasePtr], eax
        pop     edi

  .imp32no12:
        inc     edx
;       add     esi, 3
        add     edi, 4
        dec     ecx
        jnz     .np3212

  .np32d12:
        pop     ebx
        pop     ecx
        pop     edi

        add     edi, [BytesPerScanLine]
        cmp     ebp, putimage_get1bpp
        jz      .correct
        cmp     ebp, putimage_get2bpp
        jz      .correct
        cmp     ebp, putimage_get4bpp
        jnz     @f

  .correct:
        mov     eax, [esp + 20]
        mov     byte[eax], 0x80

    @@: dec     ebx
        jnz     .newpi3212

  .nonewpi3212:
        pop     eax edx ecx ebx eax edi esi
        xor     eax, eax
        ret
kendp
