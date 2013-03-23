;;======================================================================================================================
;;///// vesa20.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
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

; If you're planning to write your own video driver I suggest
; you replace the VESA12.INC file and see those instructions.

uglobal
  PUTPIXEL dd ?
  GETPIXEL dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc getpixel ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? getpixel
;-----------------------------------------------------------------------------------------------------------------------
;> eax = x coordinate
;> ebx = y coordinate
;-----------------------------------------------------------------------------------------------------------------------
;< ecx = 00 RR GG BB
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx edx edi
        call    [GETPIXEL]
        pop     edi edx ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Vesa20_getpixel24 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = x
;> ebx = y
;-----------------------------------------------------------------------------------------------------------------------
        imul    ebx, [BytesPerScanLine] ; ebx = y * y multiplier
        lea     edi, [eax + eax * 2] ; edi = x*3
        add     edi, ebx ; edi = x*3+(y*y multiplier)
        mov     ecx, [LFB_BASE + edi]
        and     ecx, 0x00ffffff
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Vesa20_getpixel32 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        imul    ebx, [BytesPerScanLine] ; ebx = y * y multiplier
        lea     edi, [ebx + eax * 4] ; edi = x*4+(y*y multiplier)
        mov     ecx, [LFB_BASE + edi]
        and     ecx, 0x00ffffff
        ret
kendp

virtual at esp
  putimg:
   .real_size      size32_t
   .image_box      box32_t
   .pti            dd ?
   .abs_pos        point32_t
   .line_increment dd ?
   .winmap_newline dd ?
   .screen_newline dd ?
   .stack_data = 4 * 12
   .context        regs_context32_t
   .ret_addr       dd ?
   .arg_0          dd ?
end virtual

align 16
;-----------------------------------------------------------------------------------------------------------------------
kproc vesa20_putimage ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer
;> ecx = size [x|y]
;> edx = coordinates [x|y]
;> ebp = pointer to 'get' function
;> esi = pointer to 'init' function
;> edi = parameter for 'get' function
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        call    [_display.disable_mouse]
        sub     esp, putimg.stack_data
        ; save pointer to image
        mov     [putimg.pti], ebx
        ; unpack the size
        mov     eax, ecx
        and     ecx, 0xffff
        shr     eax, 16
        mov     [putimg.image_box.width], eax
        mov     [putimg.image_box.height], ecx
        ; unpack the coordinates
        mov     eax, edx
        and     edx, 0xffff
        shr     eax, 16
        mov     [putimg.image_box.left], eax
        mov     [putimg.image_box.top], edx
        ; calculate absolute (i.e. screen) coordinates
        mov     eax, [current_slot_ptr]
        mov     ebx, [eax + legacy.slot_t.window.box.left]
        add     ebx, [putimg.image_box.left]
        mov     [putimg.abs_pos.x], ebx
        mov     ebx, [eax + legacy.slot_t.window.box.top]
        add     ebx, [putimg.image_box.top]
        mov     [putimg.abs_pos.y], ebx
        ; real_sx = MIN(wnd_sx-image_cx, image_sx);
        mov     ebx, [eax + legacy.slot_t.window.box.width] ; ebx = wnd_sx
        ; note that legacy.slot_t.window.box.width is one pixel less than real window x-size
        inc     ebx
        sub     ebx, [putimg.image_box.left]
        ja      @f
        add     esp, putimg.stack_data
        popad
        ret

    @@: cmp     ebx, [putimg.image_box.width]
        jbe     .end_x
        mov     ebx, [putimg.image_box.width]

  .end_x:
        mov     [putimg.real_size.width], ebx
        ; init real_sy
        mov     ebx, [eax + legacy.slot_t.window.box.height] ; ebx = wnd_sy
        inc     ebx
        sub     ebx, [putimg.image_box.top]
        ja      @f
        add     esp, putimg.stack_data
        popad
        ret

    @@: cmp     ebx, [putimg.image_box.height]
        jbe     .end_y
        mov     ebx, [putimg.image_box.height]

  .end_y:
        mov     [putimg.real_size.height], ebx
        ; line increment
        mov     eax, [putimg.image_box.width]
        mov     ecx, [putimg.real_size.width]
        sub     eax, ecx
;;      imul    eax, [putimg.source_bpp]
;       lea     eax, [eax + eax * 2]
        call    esi
        add     eax, [putimg.arg_0]
        mov     [putimg.line_increment], eax
        ; winmap new line increment
        mov     eax, [Screen_Max_Pos.x]
        inc     eax
        sub     eax, [putimg.real_size.width]
        mov     [putimg.winmap_newline], eax
        ; screen new line increment
        mov     eax, [BytesPerScanLine]
        movzx   ebx, [ScreenBPP]
        shr     ebx, 3
        imul    ecx, ebx
        sub     eax, ecx
        mov     [putimg.screen_newline], eax
        ; pointer to image
        mov     esi, [putimg.pti]
        ; pointer to screen
        mov     edx, [putimg.abs_pos.y]
        imul    edx, [BytesPerScanLine]
        mov     eax, [putimg.abs_pos.x]
        movzx   ebx, [ScreenBPP]
        shr     ebx, 3
        imul    eax, ebx
        add     edx, eax
        ; pointer to pixel map
        mov     eax, [putimg.abs_pos.y]
        imul    eax, [Screen_Max_Pos.x]
        add     eax, [putimg.abs_pos.y]
        add     eax, [putimg.abs_pos.x]
        add     eax, [_WinMapRange.address]
        xchg    eax, ebp
        ; get process number
        mov     ebx, [current_slot]
        cmp     [ScreenBPP], 32
        je      put_image_end_32

;put_image_end_24:
        mov     edi, [putimg.real_size.height]

align 4
  .new_line:
        mov     ecx, [putimg.real_size.width]
;       push    ebp edx

align 4
  .new_x:
        push    [putimg.context.edi]
        mov     eax, [putimg.context.ebp + 4]
        call    eax
        cmp     [ebp], bl
        jne     .skip
;       mov     eax, [esi] ; eax = RRBBGGRR
        mov     [LFB_BASE + edx], ax
        shr     eax, 16
        mov     [LFB_BASE + edx + 2], al

  .skip:
;       add     esi, 3 ; [putimg.source_bpp]
        add     edx, 3
        inc     ebp
        dec     ecx
        jnz     .new_x
;       pop     edx ebp
        add     esi, [putimg.line_increment]
        add     edx, [putimg.screen_newline] ; [BytesPerScanLine]
        add     ebp, [putimg.winmap_newline] ; [Screen_Max_Pos.x]
;       inc     ebp
        cmp     [putimg.context.ebp], putimage_get1bpp
        jz      .correct
        cmp     [putimg.context.ebp], putimage_get2bpp
        jz      .correct
        cmp     [putimg.context.ebp], putimage_get4bpp
        jnz     @f

  .correct:
        mov     eax, [putimg.context.edi]
        mov     byte[eax], 0x80

    @@: dec     edi
        jnz     .new_line

  .finish:
        add     esp, putimg.stack_data
        popad
        ret

put_image_end_32:
        mov     edi, [putimg.real_size.height]

align 4
  .new_line:
        mov     ecx, [putimg.real_size.width]
;       push    ebp edx

align 4
  .new_x:
        push    [putimg.context.edi]
        mov     eax, [putimg.context.ebp + 4]
        call    eax
        cmp     [ebp], bl
        jne     .skip
;       mov     eax, [esi] ; ecx = RRBBGGRR
        mov     [LFB_BASE + edx], eax

  .skip:
;       add     esi, [putimg.source_bpp]
        add     edx, 4
        inc     ebp
        dec     ecx
        jnz     .new_x
;       pop     edx ebp
        add     esi, [putimg.line_increment]
        add     edx, [putimg.screen_newline] ; [BytesPerScanLine]
        add     ebp, [putimg.winmap_newline] ; [Screen_Max_Pos.x]
;       inc     ebp
        cmp     [putimg.context.ebp], putimage_get1bpp
        jz      .correct
        cmp     [putimg.context.ebp], putimage_get2bpp
        jz      .correct
        cmp     [putimg.context.ebp], putimage_get4bpp
        jnz     @f

  .correct:
        mov     eax, [putimg.context.edi]
        mov     byte[eax], 0x80

    @@: dec     edi
        jnz     .new_line

  .finish:
        add     esp, putimg.stack_data
        popad
        call    VGA__putimage
        mov     [EGA_counter], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc __sys_putpixel ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = x coordinate
;> ebx = y coordinate
;> ecx = ?? RR GG BB    ; 0x01000000 negation
;> edi = 0x00000001 force
;-----------------------------------------------------------------------------------------------------------------------
;;;     mov     dword[novesachecksum], 0
        pushad
        cmp     [Screen_Max_Pos.x], eax
        jb      .exit
        cmp     [Screen_Max_Pos.y], ebx
        jb      .exit
        test    edi, 1 ; force ?
        jnz     .forced

        ; not forced:

        push    eax
        mov     edx, [_display.box.width] ; screen x size
        imul    edx, ebx
        add     eax, [_WinMapRange.address]
        movzx   edx, byte[eax + edx]
        cmp     edx, [current_slot]
        pop     eax
        jne     .exit

  .forced:
        ; check if negation
        test    ecx, 0x01000000
        jz      .noneg
        call    getpixel
        not     ecx
        mov     [esp + regs_context32_t.ecx], ecx

  .noneg:
        ; OK to set pixel
        call    [PUTPIXEL] ; call the real put_pixel function

  .exit:
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Vesa20_putpixel24 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = x
;> ebx = y
;-----------------------------------------------------------------------------------------------------------------------
        imul    ebx, [BytesPerScanLine] ; ebx = y * y multiplier
        lea     edi, [eax + eax * 2] ; edi = x*3
        mov     eax, [esp + 4 + regs_context32_t.ecx]
        mov     [LFB_BASE + ebx + edi], ax
        shr     eax, 16
        mov     [LFB_BASE + ebx + edi + 2], al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Vesa20_putpixel32 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = x
;> ebx = y
;-----------------------------------------------------------------------------------------------------------------------
        imul    ebx, [BytesPerScanLine] ; ebx = y * y multiplier
        lea     edi, [ebx + eax * 4] ; edi = x*4+(y*y multiplier)
        mov     eax, [esp + 4 + regs_context32_t.ecx] ; eax = color
        mov     [LFB_BASE + edi], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_edi ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, ebx
        imul    edi, [Screen_Max_Pos.x]
        add     edi, ebx
        add     edi, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc __sys_draw_line ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
; draw a line
;-----------------------------------------------------------------------------------------------------------------------
;? eax = pack[16(x1), 16(x2)]
;? ebx = pack[16(y1), 16(y2)]
;? ecx = color
;? edi = force ?
;-----------------------------------------------------------------------------------------------------------------------
;       inc     [mouse_pause]
        call    [_display.disable_mouse]

        pusha

dl_x1 equ esp + 20
dl_y1 equ esp + 16
dl_x2 equ esp + 12
dl_y2 equ esp + 8
dl_dx equ esp + 4
dl_dy equ esp + 0

        xor     edx, edx ; clear edx
        xor     esi, esi ; unpack arguments
        xor     ebp, ebp
        mov     si, ax ; esi = x2
        mov     bp, bx ; ebp = y2
        shr     eax, 16 ; eax = x1
        shr     ebx, 16 ; ebx = y1
        push    eax ; save x1
        push    ebx ; save y1
        push    esi ; save x2
        push    ebp ; save y2
        ; checking x-axis...
        sub     esi, eax ; esi = x2-x1
        push    esi ; save y2-y1
        jl      .x2lx1 ; is x2 less than x1 ?
        jg      .no_vline ; x1 > x2 ?
        mov     edx, ebp ; else (if x1=x2)
        call    vline
        push    edx ; necessary to rightly restore stack frame at .exit
        jmp     .exit

  .x2lx1:
        neg     esi            ; get esi absolute value

  .no_vline:
        ; checking y-axis...
        sub     ebp, ebx ; ebp = y2-y1
        push    ebp ; save y2-y1
        jl      .y2ly1 ; is y2 less than y1 ?
        jg      .no_hline ; y1 > y2 ?
        mov     edx, [dl_x2] ; else (if y1=y2)
        call    hline
        jmp     .exit

  .y2ly1:
        neg     ebp ; get ebp absolute value

  .no_hline:
        cmp     ebp, esi
        jle     .x_rules ; |y2-y1| < |x2-x1|  ?
        cmp     [dl_y2], ebx ; make sure y1 is at the begining
        jge     .no_reverse1
        neg     dword[dl_dx]
        mov     edx, [dl_x2]
        mov     [dl_x2], eax
        mov     [dl_x1], edx
        mov     edx, [dl_y2]
        mov     [dl_y2], ebx
        mov     [dl_y1], edx

  .no_reverse1:
        mov     eax, [dl_dx]
        cdq     ; extend eax sing to edx
        shl     eax, 16 ; using 16bit fix-point maths
        idiv    ebp ; eax = ((x2-x1)*65536)/(y2-y1)
        shl     edx, 1 ; correction for the remainder of the division
        cmp     ebp, edx
        jb      @f

        inc     eax

    @@: mov     edx, ebp ; edx = counter (number of pixels to draw)
        mov     ebp, 1 * 65536 ; <<16   ; ebp = dy = 1.0
        mov     esi, eax ; esi = dx
        jmp     .y_rules

  .x_rules:
        cmp     [dl_x2], eax ; make sure x1 is at the begining
        jge     .no_reverse2
        neg     dword[dl_dy]
        mov     edx, [dl_x2]
        mov     [dl_x2], eax
        mov     [dl_x1], edx
        mov     edx, [dl_y2]
        mov     [dl_y2], ebx
        mov     [dl_y1], edx

  .no_reverse2:
        xor     edx, edx
        mov     eax, [dl_dy]
        cdq     ; extend eax sing to edx
        shl     eax, 16 ; using 16bit fix-point maths
        idiv    esi ; eax = ((y2-y1)*65536)/(x2-x1)
        shl     edx, 1 ; correction for the remainder of the division
        cmp     esi, edx
        jb      @f

        inc     eax

    @@: mov     edx, esi ; edx = counter (number of pixels to draw)
        mov     esi, 1 * 65536 ; << 16 ; esi = dx = 1.0
        mov     ebp, eax ; ebp = dy

  .y_rules:
        mov     eax, [dl_x1]
        mov     ebx, [dl_y1]
        shl     eax, 16
        shl     ebx, 16

align 4
  .draw:
        push    eax ebx
        test    ah, 0x80 ; correction for the remainder of the division
        jz      @f

        add     eax, 1 shl 16

    @@: shr     eax, 16
        test    bh, 0x80 ; correction for the remainder of the division
        jz      @f

        add     ebx, 1 shl 16

    @@: shr     ebx, 16
        call    [putpixel]
        pop     ebx eax
        add     ebx, ebp ; y = y+dy
        add     eax, esi ; x = x+dx
        dec     edx
        jnz     .draw
        ; force last drawn pixel to be at (x2,y2)
        mov     eax, [dl_x2]
        mov     ebx, [dl_y2]
        call    [putpixel]

  .exit:
        add     esp, 6 * 4
        popa
;       dec     [mouse_pause]
        call    [draw_pointer]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hline ;///////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; draw an horizontal line
        ; eax = x1
        ; edx = x2
        ; ebx = y
        ; ecx = color
        ; edi = force ?

        push    eax edx
        cmp     edx, eax ; make sure x2 is above x1
        jge     @f
        xchg    eax, edx

align 4
    @@: call    [putpixel]
        inc     eax
        cmp     eax, edx
        jle     @b
        pop     edx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc vline ;///////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; draw a vertical line
        ; eax = x
        ; ebx = y1
        ; edx = y2
        ; ecx = color
        ; edi = force ?

        push    ebx edx
        cmp     edx, ebx ; make sure y2 is above y1
        jge     @f
        xchg    ebx, edx

align 4
    @@: call    [putpixel]
        inc     ebx
        cmp     ebx, edx
        jle     @b
        pop     edx ebx
        ret
kendp

virtual at esp
  drbar:
    .bar_sx       dd ?
    .bar_sy       dd ?
    .bar_cx       dd ?
    .bar_cy       dd ?
    .abs_cx       dd ?
    .abs_cy       dd ?
    .real_sx      dd ?
    .real_sy      dd ?
    .color        dd ?
    .line_inc_scr dd ?
    .line_inc_map dd ?
    .stack_data = 4 * 11
end virtual

;-----------------------------------------------------------------------------------------------------------------------
kproc vesa20_drawbar ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = cx
;> ebx = cy
;> ecx = xe
;> edx = ye
;> edi = color
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        call    [_display.disable_mouse]
        sub     esp, drbar.stack_data
        mov     [drbar.color], edi
        sub     edx, ebx
        jle     .exit
        sub     ecx, eax
        jle     .exit
        mov     [drbar.bar_sy], edx
        mov     [drbar.bar_sx], ecx
        mov     [drbar.bar_cx], eax
        mov     [drbar.bar_cy], ebx
        mov     edi, [current_slot_ptr]
        add     eax, [edi + legacy.slot_t.window.box.left] ; win_cx
        add     ebx, [edi + legacy.slot_t.window.box.top] ; win_cy
        mov     [drbar.abs_cx], eax
        mov     [drbar.abs_cy], ebx
        ; real_sx = MIN(wnd_sx-bar_cx, bar_sx);
        mov     ebx, [edi + legacy.slot_t.window.box.width] ; ebx = wnd_sx
        ; note that legacy.slot_t.window.box.width is one pixel less than real window x-size
        inc     ebx
        sub     ebx, [drbar.bar_cx]
        ja      @f

  .exit:
        add     esp, drbar.stack_data
        popad
        xor     eax, eax
        inc     eax
        ret

    @@: cmp     ebx, [drbar.bar_sx]
        jbe     .end_x
        mov     ebx, [drbar.bar_sx]

  .end_x:
        mov     [drbar.real_sx], ebx
        ; real_sy = MIN(wnd_sy-bar_cy, bar_sy);
        mov     ebx, [edi + legacy.slot_t.window.box.height] ; ebx = wnd_sy
        inc     ebx
        sub     ebx, [drbar.bar_cy]
        ja      @f
        add     esp, drbar.stack_data
        popad
        xor     eax, eax
        inc     eax
        ret

    @@: cmp     ebx, [drbar.bar_sy]
        jbe     .end_y
        mov     ebx, [drbar.bar_sy]

  .end_y:
        mov     [drbar.real_sy], ebx
        ; line_inc_map
        mov     eax, [Screen_Max_Pos.x]
        sub     eax, [drbar.real_sx]
        inc     eax
        mov     [drbar.line_inc_map], eax
        ; line_inc_scr
        mov     eax, [drbar.real_sx]
        movzx   ebx, [ScreenBPP]
        shr     ebx, 3
        imul    eax, ebx
        neg     eax
        add     eax, [BytesPerScanLine]
        mov     [drbar.line_inc_scr], eax
        ; pointer to screen
        mov     edx, [drbar.abs_cy]
        imul    edx, [BytesPerScanLine]
        mov     eax, [drbar.abs_cx]
;       movzx   ebx, [ScreenBPP]
;       shr     ebx, 3
        imul    eax, ebx
        add     edx, eax
        ; pointer to pixel map
        mov     eax, [drbar.abs_cy]
        imul    eax, [Screen_Max_Pos.x]
        add     eax, [drbar.abs_cy]
        add     eax, [drbar.abs_cx]
        add     eax, [_WinMapRange.address]
        xchg    eax, ebp
        ; get process number
        mov     ebx, [current_slot]
        cmp     [ScreenBPP], 24
        jne     draw_bar_end_32

draw_bar_end_24:
        mov     eax, [drbar.color] ;; BBGGRR00
        mov     bh, al ;; bh  = BB
        shr     eax, 8 ;; eax = RRGG
        ; eax - color high   RRGG
        ; bl - process num
        ; bh - color low    BB
        ; ecx - temp
        ; edx - pointer to screen
        ; esi - counter
        ; edi - counter
        mov     esi, [drbar.real_sy]

align 4
  .new_y:
        mov     edi, [drbar.real_sx]

align 4
  .new_x:
        cmp     byte[ebp], bl
        jne     .skip

        mov     [LFB_BASE + edx], bh
        mov     [LFB_BASE + edx + 1], ax

  .skip:
        ; add pixel
        add     edx, 3
        inc     ebp
        dec     edi
        jnz     .new_x
        ; add line
        add     edx, [drbar.line_inc_scr]
        add     ebp, [drbar.line_inc_map]
        test    eax, 0x00800000
        jz      @f
        test    bh, bh
        jz      @f
        dec     bh

    @@: dec     esi
        jnz     .new_y
        add     esp, drbar.stack_data
        popad
        xor     eax, eax
        ret

draw_bar_end_32:
        mov     eax, [drbar.color] ;; BBGGRR00
        mov     esi, [drbar.real_sy]

align 4
  .new_y:
        mov     edi, [drbar.real_sx]

align 4
  .new_x:
        cmp     byte[ebp], bl
        jne     .skip

        mov     [LFB_BASE + edx], eax

  .skip:
        ; add pixel
        add     edx, 4
        inc     ebp
        dec     edi
        jnz     .new_x
        ; add line
        add     edx, [drbar.line_inc_scr]
        add     ebp, [drbar.line_inc_map]
        test    eax, 0x80000000
        jz      @f
        test    al, al
        jz      @f
        dec     al

    @@: dec     esi
        jnz     .new_y
        add     esp, drbar.stack_data
        popad
        call    VGA_draw_bar
        xor     eax, eax
        mov     [EGA_counter], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc vesa20_drawbackground_tiled ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    [_display.disable_mouse]
        pushad
        ; External loop for all y from start to end
        mov     ebx, [legacy_os_idle_slot.draw.top] ; y start

  .dp2:
        mov     ebp, [legacy_os_idle_slot.draw.left] ; x start
        ; 1) Calculate pointers in WinMapAddress (does pixel belong to OS thread?) [ebp]
        ;                       and LFB data (output for our function) [edi]
        mov     eax, [BytesPerScanLine]
        mul     ebx
        xchg    ebp, eax
        add     ebp, eax
        add     ebp, eax
        add     ebp, eax
        cmp     [ScreenBPP], 24 ; 24 or 32 bpp ? - x size
        jz      @f
        add     ebp, eax

    @@: add     ebp, LFB_BASE
        ; ebp:=Y*BytesPerScanLine+X*BytesPerPixel+AddrLFB
        call    calculate_edi
        xchg    edi, ebp
        add     ebp, [_WinMapRange.address]
        ; Now eax=x, ebx=y, edi->output, ebp=offset in WinMapAddress
        ; 2) Calculate offset in background memory block
        push    eax
        xor     edx, edx
        mov     eax, ebx
        div     [BgrDataSize.height]   ; edx := y mod BgrDataSize.height
        pop     eax
        push    eax
        mov     ecx, [BgrDataSize.width]
        mov     esi, edx
        imul    esi, ecx                ; esi := (y mod BgrDataSize.height) * BgrDataSize.width
        xor     edx, edx
        div     ecx             ; edx := x mod BgrDataSize.width
        sub     ecx, edx
        add     esi, edx        ; esi := (y mod BgrDataSize.height)*BgrDataSize.width + (x mod BgrDataSize.width)
        pop     eax
        lea     esi, [esi * 3]
        add     esi, [img_background]
        xor     edx, edx
        inc     edx
        ; 3) Loop through redraw rectangle and copy background data
        ; Registers meaning:
        ; eax = x, ebx = y (screen coordinates)
        ; ecx = deltax - number of pixels left in current tile block
        ; edx = 1
        ; esi -> bgr memory, edi -> output
        ; ebp = offset in WinMapAddress

  .dp3:
        cmp     [ebp], dl
        jnz     .nbgp
        movsb
        movsb
        movsb
        jmp     @f

  .nbgp:
        add     esi, 3
        add     edi, 3

    @@: cmp     [ScreenBPP], 25 ; 24 or 32 bpp?
        sbb     edi, -1 ; +1 for 32 bpp
        ; I do not use 'inc eax' because this is slightly slower then 'add eax,1'
        add     ebp, edx
        add     eax, edx
        cmp     eax, [legacy_os_idle_slot.draw.right]
        ja      .dp4
        sub     ecx, edx
        jnz     .dp3
        ; next tile block on x-axis
        mov     ecx, [BgrDataSize.width]
        sub     esi, ecx
        sub     esi, ecx
        sub     esi, ecx
        jmp     .dp3

  .dp4:
        ; next scan line
        inc     ebx
        cmp     ebx, [legacy_os_idle_slot.draw.bottom]
        jbe     .dp2
        popad
        mov     [EGA_counter], 1
        call    VGA_drawbackground
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc vesa20_drawbackground_stretch ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    [_display.disable_mouse]
        pushad
        ; Helper variables
        ; calculate 2^32*(BgrDataSize.width-1) mod (ScreenWidth-1)
        mov     eax, [BgrDataSize.width]
        dec     eax
        xor     edx, edx
        div     [Screen_Max_Pos.x]
        push    eax ; high
        xor     eax, eax
        div     [Screen_Max_Pos.x]
        push    eax ; low
        ; the same for height
        mov     eax, [BgrDataSize.height]
        dec     eax
        xor     edx, edx
        div     [Screen_Max_Pos.y]
        push    eax ; high
        xor     eax, eax
        div     [Screen_Max_Pos.y]
        push    eax ; low
        ; External loop for all y from start to end
        mov     ebx, [legacy_os_idle_slot.draw.top] ; y start
        mov     ebp, [legacy_os_idle_slot.draw.left] ; x start
        ; 1) Calculate pointers in WinMapAddress (does pixel belong to OS thread?) [ebp]
        ;                       and LFB data (output for our function) [edi]
        mov     eax, [BytesPerScanLine]
        mul     ebx
        xchg    ebp, eax
        add     ebp, eax
        add     ebp, eax
        add     ebp, eax
        cmp     [ScreenBPP], 24 ; 24 or 32 bpp ? - x size
        jz      @f
        add     ebp, eax

    @@: ; ebp:=Y*BytesPerScanLine+X*BytesPerPixel+AddrLFB
        call    calculate_edi
        xchg    edi, ebp
        ; Now eax=x, ebx=y, edi->output, ebp=offset in WinMapAddress
        push    ebx
        push    eax
        ; 2) Calculate offset in background memory block
        mov     eax, ebx
        imul    ebx, dword[esp + 12]
        mul     dword[esp + 8]
        add     edx, ebx ; edx:eax = y * 2^32*(BgrDataSize.height-1)/(ScreenHeight-1)
        mov     esi, edx
        imul    esi, [BgrDataSize.width]
        push    edx
        push    eax
        mov     eax, [esp + 8]
        mul     dword[esp + 28]
        push    eax
        mov     eax, [esp + 12]
        mul     dword[esp + 28]
        add     [esp], edx
        pop     edx ; edx:eax = x * 2^32*(BgrDataSize.width-1)/(ScreenWidth-1)
        add     esi, edx
        lea     esi, [esi * 3]
        add     esi, [img_background]
        push    eax
        push    edx
        push    esi

        ; 3) Smooth horizontal
  .bgr_resmooth0:
        mov     ecx, [esp + 8]
        mov     edx, [esp + 4]
        mov     esi, [esp]
        push    edi
        mov     edi, bgr_cur_line
        call    smooth_line

  .bgr_resmooth1:
        mov     eax, [esp + 16 + 4]
        inc     eax
        cmp     eax, [BgrDataSize.height]
        jae     .bgr.no2nd
        mov     ecx, [esp + 8 + 4]
        mov     edx, [esp + 4 + 4]
        mov     esi, [esp + 4]
        add     esi, [BgrDataSize.width]
        add     esi, [BgrDataSize.width]
        add     esi, [BgrDataSize.width]
        mov     edi, bgr_next_line
        call    smooth_line

  .bgr.no2nd:
        pop     edi

  .sdp3:
        xor     esi, esi
        mov     ecx, [esp + 12]

        ; 4) Loop through redraw rectangle and copy background data
        ; Registers meaning:
        ; esi = offset in current line, edi -> output
        ; ebp = offset in WinMapAddress
        ; dword[esp] = offset in bgr data
        ; qword[esp+4] = x * 2^32 * (BgrDataSize.width-1) / (ScreenWidth-1)
        ; qword[esp+12] = y * 2^32 * (BgrDataSize.height-1) / (ScreenHeight-1)
        ; dword[esp+20] = x
        ; dword[esp+24] = y
        ; precalculated constants:
        ; qword[esp+28] = 2^32*(BgrDataSize.height-1)/(ScreenHeight-1)
        ; qword[esp+36] = 2^32*(BgrDataSize.width-1)/(ScreenWidth-1)
  .sdp3a:
        mov     eax, [_WinMapRange.address]
        cmp     byte[ebp + eax], 1
        jnz     .snbgp
        mov     eax, [bgr_cur_line + esi]
        test    ecx, ecx
        jz      .novert
        mov     ebx, [bgr_next_line + esi]
        call    [overlapping_of_points_ptr]

  .novert:
        mov     [LFB_BASE + edi], ax
        shr     eax, 16

        mov     [LFB_BASE + edi + 2], al

  .snbgp:
        cmp     [ScreenBPP], 25
        sbb     edi, -4
        add     ebp, 1
        mov     eax, [esp + 20]
        add     eax, 1
        mov     [esp + 20], eax
        add     esi, 4
        cmp     eax, [legacy_os_idle_slot.draw.right]
        jbe     .sdp3a

  .sdp4:
        ; next y
        mov     ebx, [esp + 24]
        add     ebx, 1
        mov     [esp + 24], ebx
        cmp     ebx, [legacy_os_idle_slot.draw.bottom]
        ja      .sdpdone
        ; advance edi, ebp to next scan line
        sub     eax, [legacy_os_idle_slot.draw.left]
        sub     ebp, eax
        add     ebp, [Screen_Max_Pos.x]
        add     ebp, 1
        sub     edi, eax
        sub     edi, eax
        sub     edi, eax
        cmp     [ScreenBPP], 24
        jz      @f
        sub     edi, eax

    @@: add     edi, [BytesPerScanLine]
        ; restore ecx,edx; advance esi to next background line
        mov     eax, [esp + 28]
        mov     ebx, [esp + 32]
        add     [esp + 12], eax
        mov     eax, [esp + 16]
        adc     [esp + 16], ebx
        sub     eax, [esp + 16]
        mov     ebx, eax
        lea     eax, [eax * 3]
        imul    eax, [BgrDataSize.width]
        sub     [esp], eax
        mov     eax, [legacy_os_idle_slot.draw.left]
        mov     [esp + 20], eax
        test    ebx, ebx
        jz      .sdp3
        cmp     ebx, -1
        jnz     .bgr_resmooth0
        push    edi
        mov     esi, bgr_next_line
        mov     edi, bgr_cur_line
        mov     ecx, [Screen_Max_Pos.x]
        inc     ecx
        rep
        movsd
        jmp     .bgr_resmooth1

  .sdpdone:
        add     esp, 44
        popad
        mov     [EGA_counter], 1
        call    VGA_drawbackground
        ret
kendp

uglobal
  bgr_cur_line  rd 1920 ; maximum width of screen
  bgr_next_line rd 1920
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc smooth_line ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [esi + 2]
        shl     eax, 16
        mov     ax, [esi]
        test    ecx, ecx
        jz      @f
        mov     ebx, [esi + 2]
        shr     ebx, 8
        call    [overlapping_of_points_ptr]

    @@: stosd
        mov     eax, [esp + 20 + 8]
        add     eax, 1
        mov     [esp + 20 + 8], eax
        cmp     eax, [legacy_os_idle_slot.draw.right]
        ja      @f
        add     ecx, [esp + 36 + 8]
        mov     eax, edx
        adc     edx, [esp + 40 + 8]
        sub     eax, edx
        lea     eax, [eax * 3]
        sub     esi, eax
        jmp     smooth_line

    @@: mov     eax, [legacy_os_idle_slot.draw.left]
        mov     [esp + 20 + 8], eax
        ret
kendp

align 16
;-----------------------------------------------------------------------------------------------------------------------
kproc overlapping_of_points ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------

if 0

        ; this version of procedure works, but is slower than next version
        push    ecx edx
        mov     edx, eax
        push    esi
        shr     ecx, 24
        mov     esi, ecx
        mov     ecx, ebx
        movzx   ebx, dl
        movzx   eax, cl
        sub     eax, ebx
        movzx   ebx, dh
        imul    eax, esi
        add     dl, ah
        movzx   eax, ch
        sub     eax, ebx
        imul    eax, esi
        add     dh, ah
        ror     ecx, 16
        ror     edx, 16
        movzx   eax, cl
        movzx   ebx, dl
        sub     eax, ebx
        imul    eax, esi
        pop     esi
        add     dl, ah
        mov     eax, edx
        pop     edx
        ror     eax, 16
        pop     ecx
        ret

else

        push    ecx edx
        mov     edx, eax
        push    esi
        shr     ecx, 26
        mov     esi, ecx
        mov     ecx, ebx
        shl     esi, 9
        movzx   ebx, dl
        movzx   eax, cl
        sub     eax, ebx
        movzx   ebx, dh
        add     dl, [BgrAuxTable + (eax + 0x100) + esi]
        movzx   eax, ch
        sub     eax, ebx
        add     dh, [BgrAuxTable + (eax + 0x100) + esi]
        ror     ecx, 16
        ror     edx, 16
        movzx   eax, cl
        movzx   ebx, dl
        sub     eax, ebx
        add     dl, [BgrAuxTable + (eax + 0x100) + esi]
        pop     esi
        mov     eax, edx
        pop     edx
        ror     eax, 16
        pop     ecx
        ret

end if

kendp

iglobal
  overlapping_of_points_ptr dd overlapping_of_points
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc init_background ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, BgrAuxTable
        xor     edx, edx

  .loop2:
        mov     eax, edx
        shl     eax, 8
        neg     eax
        mov     ecx, 0x200

  .loop1:
        mov     byte[edi], ah
        inc     edi
        add     eax, edx
        loop    .loop1
        add     dl, 4
        jnz     .loop2
        test    byte[cpu_caps + (CAPS_MMX / 8)], 1 shl (CAPS_MMX mod 8)
        jz      @f
        mov     [overlapping_of_points_ptr], overlapping_of_points_mmx

    @@: ret
kendp

align 16
;-----------------------------------------------------------------------------------------------------------------------
kproc overlapping_of_points_mmx ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        movd    mm0, eax
        movd    mm4, eax
        movd    mm1, ebx
        pxor    mm2, mm2
        punpcklbw mm0, mm2
        punpcklbw mm1, mm2
        psubw   mm1, mm0
        movd    mm3, ecx
        psrld   mm3, 24
        packuswb mm3, mm3
        packuswb mm3, mm3
        pmullw  mm1, mm3
        psrlw   mm1, 8
        packuswb mm1, mm2
        paddb   mm4, mm1
        movd    eax, mm4
        ret
kendp
