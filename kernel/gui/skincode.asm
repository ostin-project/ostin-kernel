;;======================================================================================================================
;;///// skincode.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
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

include "skindata.inc"

;skin_data = 0x00778000

;-----------------------------------------------------------------------------------------------------------------------
kproc read_skin_file ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        stdcall load_file, ebx
        test    eax, eax
        jz      .notfound
        cmp     dword[eax], 'SKIN'
        jnz     .noskin
        cmp     ebx, 32 * 1024
        jb      @f
        mov     ebx, 32 * 1024

    @@: lea     ecx, [ebx + 3]
        shr     ecx, 2
        mov     esi, eax
        mov     edi, skin_data
        rep
        movsd
        stdcall kernel_free, eax

        call    parse_skin_data
        xor     eax, eax
        ret

  .notfound:
        xor     eax, eax
        inc     eax
        ret

  .noskin:
        stdcall kernel_free, eax
        push    2
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc load_default_skin ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [_skinh], 22
        mov     ebx, _skin_file_default
        call    read_skin_file
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc parse_skin_data ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, skin_data
        cmp     [ebp + skin_header_t.ident], 'SKIN'
        jne     .exit

        mov     edi, skin_udata
        mov     ecx, (skin_udata.end - skin_udata) / 4
        xor     eax, eax
        rep
        stosd

        mov     ebx, [ebp + skin_header_t.params]
        add     ebx, skin_data
        mov     eax, [ebx + skin_params_t.skin_height]
        mov     [_skinh], eax
        mov     eax, [ebx + skin_params_t.colors.inner]
        mov     [skin_active.colors.inner], eax
        mov     eax, [ebx + skin_params_t.colors.outer]
        mov     [skin_active.colors.outer], eax
        mov     eax, [ebx + skin_params_t.colors.frame]
        mov     [skin_active.colors.frame], eax
        mov     eax, [ebx + skin_params_t.colors_1.inner]
        mov     [skin_inactive.colors.inner], eax
        mov     eax, [ebx + skin_params_t.colors_1.outer]
        mov     [skin_inactive.colors.outer], eax
        mov     eax, [ebx + skin_params_t.colors_1.frame]
        mov     [skin_inactive.colors.frame], eax
        lea     esi, [ebx + skin_params_t.dtp.data]
        mov     edi, common_colours
        mov     ecx, [ebx + skin_params_t.dtp.size]
        cmp     ecx, sizeof.system_colors_t
        jb      @f

        mov     ecx, sizeof.system_colors_t

    @@: rep
        movsb
        mov     eax, dword[ebx + skin_params_t.margin.right]
        mov     dword[_skinmargins + 0], eax
        mov     eax, dword[ebx + skin_params_t.margin.bottom]
        mov     dword[_skinmargins + 4], eax

        mov     ebx, [ebp + skin_header_t.bitmaps]
        add     ebx, skin_data

  .lp1:
        cmp     dword[ebx], 0
        je      .end_bitmaps
        movzx   eax, [ebx + skin_bitmaps_t.kind]
        movzx   ecx, [ebx + skin_bitmaps_t.type]
        dec     eax
        jnz     .not_left
        xor     eax, eax
        mov     edx, skin_active.left.data
        or      ecx, ecx
        jnz     @f
        mov     edx, skin_inactive.left.data

    @@: jmp     .next_bitmap

  .not_left:
        dec     eax
        jnz     .not_oper
        mov     esi, [ebx + skin_bitmaps_t.data]
        add     esi, skin_data
        mov     eax, [esi + 0]
        neg     eax
        mov     edx, skin_active.oper.data
        or      ecx, ecx
        jnz     @f
        mov     edx, skin_inactive.oper.data

    @@: jmp     .next_bitmap

  .not_oper:
        dec     eax
        jnz     .not_base
        mov     eax, [skin_active.left.width]
        mov     edx, skin_active.base.data
        or      ecx, ecx
        jnz     @f
        mov     eax, [skin_inactive.left.width]
        mov     edx, skin_inactive.base.data

    @@: jmp     .next_bitmap

  .not_base:
        add     ebx, 8
        jmp     .lp1

  .next_bitmap:
        mov     ecx, [ebx + skin_bitmaps_t.data]
        add     ecx, skin_data
        mov     [edx + 4], eax
        mov     eax, [ecx + 0]
        mov     [edx + 8], eax
        add     ecx, 8
        mov     [edx + 0], ecx
        add     ebx, 8
        jmp     .lp1

  .end_bitmaps:
        mov     ebx, [ebp + skin_header_t.buttons]
        add     ebx, skin_data

  .lp2:
        cmp     dword[ebx], 0
        je      .end_buttons
        mov     eax, [ebx + skin_buttons_t.type]
        dec     eax
        jnz     .not_close
        mov     edx, skin_btn_close
        jmp     .next_button

  .not_close:
        dec     eax
        jnz     .not_minimize
        mov     edx, skin_btn_minimize
        jmp     .next_button

  .not_minimize:
        add     ebx, sizeof.skin_buttons_t
        jmp     .lp2

  .next_button:
        movsx   eax, [ebx + skin_buttons_t.box.left]
        mov     [edx + skin_button_t.left], eax
        movsx   eax, [ebx + skin_buttons_t.box.top]
        mov     [edx + skin_button_t.top], eax
        movsx   eax, [ebx + skin_buttons_t.box.width]
        mov     [edx + skin_button_t.width], eax
        movsx   eax, [ebx + skin_buttons_t.box.height]
        mov     [edx + skin_button_t.height], eax
        add     ebx, sizeof.skin_buttons_t
        jmp     .lp2

  .end_buttons:
  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_putimage_with_check ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        or      ebx, ebx
        jz      @f
        call    sysfn.put_image.forced

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc drawwindow_IV_caption ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, skin_active
        or      al, al
        jnz     @f
        mov     ebp, skin_inactive

    @@: mov     esi, [esp + 4]
        mov     eax, [esi + legacy.slot_t.window.box.width] ; window width
        mov     edx, [ebp + skin_data_t.left.left]
        shl     edx, 16
        mov     ecx, [ebp + skin_data_t.left.width]
        shl     ecx, 16
        add     ecx, [_skinh]

        mov     ebx, [ebp + skin_data_t.left.data]
        call    sys_putimage_with_check

        mov     esi, [esp + 4]
        mov     eax, [esi + legacy.slot_t.window.box.width]
        sub     eax, [ebp + skin_data_t.left.width]
        sub     eax, [ebp + skin_data_t.oper.width]
        cmp     eax, [ebp + skin_data_t.base.left]
        jng     .non_base
        xor     edx, edx
        mov     ecx, [ebp + skin_data_t.base.width]
        jecxz   .non_base
        div     ecx

        inc     eax

        mov     ebx, [ebp + skin_data_t.base.data]
        mov     ecx, [ebp + skin_data_t.base.width]
        shl     ecx, 16
        add     ecx, [_skinh]
        mov     edx, [ebp + skin_data_t.base.left]
        sub     edx, [ebp + skin_data_t.base.width]
        shl     edx, 16

  .baseskinloop:
        shr     edx, 16
        add     edx, [ebp + skin_data_t.base.width]
        shl     edx, 16

        push    eax ebx ecx edx
        call    sys_putimage_with_check
        pop     edx ecx ebx eax

        dec     eax
        jnz     .baseskinloop

  .non_base:
        mov     esi, [esp + 4]
        mov     edx, [esi + legacy.slot_t.window.box.width]
        sub     edx, [ebp + skin_data_t.oper.width]
        inc     edx
        shl     edx, 16
        mov     ebx, [ebp + skin_data_t.oper.data]

        mov     ecx, [ebp + skin_data_t.oper.width]
        shl     ecx, 16
        add     ecx, [_skinh]
        call    sys_putimage_with_check

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc drawwindow_IV ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; param1 - aw_yes

        pusha

        push    edx

        mov     edi, edx

        mov     ebp, skin_active
        cmp     byte[esp + 4 + sizeof.regs_context32_t + 4], 0
        jne     @f
        mov     ebp, skin_inactive

    @@: mov     eax, [edi + legacy.slot_t.window.box.left]
        shl     eax, 16
        mov     ax, word[edi + legacy.slot_t.window.box.left]
        add     ax, word[edi + legacy.slot_t.window.box.width]
        mov     ebx, [edi + legacy.slot_t.window.box.top]
        shl     ebx, 16
        mov     bx, word[edi + legacy.slot_t.window.box.top]
        add     bx, word[edi + legacy.slot_t.window.box.height]
;       mov     esi, [edi + 24]
;       shr     esi, 1
;       and     esi, 0x007f7f7f
        mov     esi, [ebp + skin_data_t.colors.outer]
        call    draw_rectangle
        mov     ecx, 3

  ._dw3l:
        add     eax, 1 * 65536 - 1
        add     ebx, 1 * 65536 - 1
        test    ax, ax
        js      .no_skin_add_button
        test    bx, bx
        js      .no_skin_add_button
        mov     esi, [ebp + skin_data_t.colors.frame] ; [edi + 24]
        call    draw_rectangle
        dec     ecx
        jnz     ._dw3l
        mov     esi, [ebp + skin_data_t.colors.inner]
        add     eax, 1 * 65536 - 1
        add     ebx, 1 * 65536 - 1
        test    ax, ax
        js      .no_skin_add_button
        test    bx, bx
        js      .no_skin_add_button
        call    draw_rectangle

        cmp     dword[skin_data], 'SKIN'
        je      @f
        xor     eax, eax
        xor     ebx, ebx
        mov     esi, [esp]
        mov     ecx, [esi + legacy.slot_t.window.box.width]
        inc     ecx
        mov     edx, [_skinh]
        mov     edi, [common_colours.grab] ; standard grab color
        call    [drawbar]
        jmp     .draw_clientbar

    @@: mov     al, [esp + 4 + sizeof.regs_context32_t + 4]
        call    drawwindow_IV_caption

  .draw_clientbar:
        mov     esi, [esp]

        mov     edx, [esi + legacy.slot_t.window.box.top] ; WORK AREA
        add     edx, 21 + 5
        mov     ebx, [esi + legacy.slot_t.window.box.top]
        add     ebx, [esi + legacy.slot_t.window.box.height]
        cmp     edx, ebx
        jg      ._noinside2
        mov     eax, 5
        mov     ebx, [_skinh]
        mov     ecx, [esi + legacy.slot_t.window.box.width]
        mov     edx, [esi + legacy.slot_t.window.box.height]
        sub     ecx, 4
        sub     edx, 4
        mov     edi, [esi + legacy.slot_t.window.cl_workarea]
        test    edi, 0x40000000
        jnz     ._noinside2
        call    [drawbar]

  ._noinside2:
        cmp     dword[skin_data], 'SKIN'
        jne     .no_skin_add_button

        ;* close button
        mov     edi, [BTN_ADDR]
        mov     eax, [edi + sys_buttons_header_t.count]
        cmp     eax, GUI_BUTTON_MAX_COUNT
        jge     .no_skin_add_button
        inc     eax
        mov     [edi + sys_buttons_header_t.count], eax

        shl     eax, 4 ; *= sizeof.sys_button_t
        add     eax, edi

        mov     ebx, [current_slot]
        mov     [eax + sys_button_t.pslot], ebx

        mov     ebx, 1
        mov     [eax + sys_button_t.id], ebx
        xor     ebx, ebx
        cmp     [skin_btn_close.left], 0
        jge     ._bCx_at_right
        mov     ebx, [esp]
        mov     ebx, [ebx + legacy.slot_t.window.box.width]
        inc     ebx

  ._bCx_at_right:
        add     ebx, [skin_btn_close.left]
        mov     [eax + sys_button_t.box.left], bx
        mov     ebx, [skin_btn_close.width]
        dec     ebx
        mov     [eax + sys_button_t.box.width], bx
        mov     ebx, [skin_btn_close.top]
        mov     [eax + sys_button_t.box.top], bx
        mov     ebx, [skin_btn_close.height]
        dec     ebx
        mov     [eax + sys_button_t.box.height], bx

        ;* minimize button
        mov     edi, [BTN_ADDR]
        mov     eax, [edi + sys_buttons_header_t.count]
        cmp     eax, GUI_BUTTON_MAX_COUNT
        jge     .no_skin_add_button
        inc     eax
        mov     [edi + sys_buttons_header_t.count], eax

        shl     eax, 4 ; *= sizeof.sys_button_t
        add     eax, edi

        mov     ebx, [current_slot]
        mov     [eax + sys_button_t.pslot], ebx

        mov     ebx, 65535
        mov     [eax + sys_button_t.id], ebx
        xor     ebx, ebx
        cmp     [skin_btn_minimize.left], 0
        jge     ._bMx_at_right
        mov     ebx, [esp]
        mov     ebx, [ebx + legacy.slot_t.window.box.width]
        inc     ebx

  ._bMx_at_right:
        add     ebx, [skin_btn_minimize.left]
        mov     [eax + sys_button_t.box.left], bx
        mov     ebx, [skin_btn_minimize.width]
        dec     ebx
        mov     [eax + sys_button_t.box.width], bx
        mov     ebx, [skin_btn_minimize.top]
        mov     [eax + sys_button_t.box.top], bx
        mov     ebx, [skin_btn_minimize.height]
        dec     ebx
        mov     [eax + sys_button_t.box.height], bx

  .no_skin_add_button:
        pop     edi
        popa

        ret     4
kendp
