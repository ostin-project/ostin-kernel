;;======================================================================================================================
;;///// mousedrv.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;   check mouse
;
;   FB00  ->   FB0F   mouse memory 00 chunk count - FB0A-B x - FB0C-D y
;   FB10  ->   FB17   mouse color mem
;   FB21              x move
;   FB22              y move
;   FB30              color temp
;   FB28              high bits temp
;   FB4A  ->   FB4D   FB4A-B x-under - FB4C-D y-under
;   FC00  ->   FCFE   com1/ps2 buffer
;   FCFF              com1/ps2 buffer count starting from FC00

uglobal
  current_cursor   rd 1
  hw_cursor        rd 1
  mouse_active     rd 1
  mouse_pause      rd 1
  MouseTickCounter rd 1
  MOUSE_PICTURE    dd ?
  MOUSE_VISIBLE    dd ?
  MOUSE_CURSOR_POS point32_t
  MOUSE_SCROLL_OFS point16_t
  MOUSE_COLOR_MEM  dd ?
  COLOR_TEMP       dd ?
  MOUSE_CURSOR_UNDER_POS point32_t
  mousecount       dd 0x0
  mousedata        dd 0x0
  mouseunder       rb 0x600
  BTN_DOWN         db ?
endg

iglobal
  mouse_delay         dd 10
  mouse_speed_factor: dd 3
  mouse_timer_ticks   dd 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.mouse_ctl, subfn, sysfn.not_implemented, \
    get_screen_coordinates, \ ; 0
    get_window_coordinates, \ ; 1
    get_buttons_state, \ ; 2
    -, \ ; 3
    load_cursor, \ ; 4
    set_cursor, \ ; 5
    delete_cursor, \ ; 6
    get_scroll_info ; 7
endg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.get_screen_coordinates ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.0: get screen-relative cursor coordinates
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [MOUSE_CURSOR_POS.x - 2]
        mov     ax, word[MOUSE_CURSOR_POS.y]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.get_window_coordinates ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.1: get window-relative cursor coordinates
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, [TASK_BASE]
        mov     edi, [CURRENT_TASK]
        shl     edi, 8

        mov     eax, [MOUSE_CURSOR_POS.x]
        sub     eax, [esi - twdw + window_data_t.box.left]
        sub     eax, [SLOT_BASE + edi + app_data_t.wnd_clientbox.left]
        shl     eax, 16
        mov     ax, word[MOUSE_CURSOR_POS.y]
        sub     ax, word[esi - twdw + window_data_t.box.top]
        sub     ax, word[SLOT_BASE + edi + app_data_t.wnd_clientbox.top]

        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.get_buttons_state ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.2: get mouse buttons state
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, [BTN_DOWN]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.get_scroll_info ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.7: get mouse wheel changes from last query
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [TASK_COUNT]
        movzx   edi, [wnd_pos_to_pslot + edi * 2]
        cmp     edi, [CURRENT_TASK]
        jne     @f
        mov     ax, [MOUSE_SCROLL_OFS.x]
        shl     eax, 16
        mov     ax, [MOUSE_SCROLL_OFS.y]
        mov     [esp + 4 + regs_context32_t.eax], eax
        and     [MOUSE_SCROLL_OFS.x], 0
        and     [MOUSE_SCROLL_OFS.y], 0
        ret

    @@: and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.load_cursor ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.4: load cursor
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, OS_BASE
        jae     .exit

        stdcall load_cursor, ecx, edx
        mov     [esp + 4 + regs_context32_t.eax], eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.set_cursor ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.5: set cursor
;-----------------------------------------------------------------------------------------------------------------------
        stdcall set_cursor, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.delete_cursor ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.6: delete cursor
;-----------------------------------------------------------------------------------------------------------------------
        stdcall delete_cursor, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;///;-----------------------------------------------------------------------------------------------------------------------
;///kproc setmouse ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;///;-----------------------------------------------------------------------------------------------------------------------
;///;? set mousepicture -pointer
;///;-----------------------------------------------------------------------------------------------------------------------
;///        ; ps2 mouse enable
;///        mov     [MOUSE_PICTURE], mousepointer
;///        cli
;///        ret
;///kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc draw_mouse_under ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? return old picture
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [_display.restore_cursor], 0
        je      @f

        pushad
        mov     eax, [MOUSE_CURSOR_UNDER_POS.x]
        mov     ebx, [MOUSE_CURSOR_UNDER_POS.y]
        stdcall [_display.restore_cursor], eax, ebx
        popad
        ret

    @@: pushad
        xor     ecx, ecx
        xor     edx, edx

align  4
  .mres:
        mov     eax, [MOUSE_CURSOR_UNDER_POS.x]
        mov     ebx, [MOUSE_CURSOR_UNDER_POS.y]
        add     eax, ecx
        add     ebx, edx
        push    ecx
        push    edx
        push    eax
        push    ebx
        mov     eax, edx
        shl     eax, 6
        shl     ecx, 2
        add     eax, ecx
        add     eax, mouseunder
        mov     ecx, [eax]
        pop     ebx
        pop     eax
        mov     edi, 1 ; force
        call    [putpixel]
        pop     edx
        pop     ecx
        inc     ecx
        cmp     ecx, 16
        jnz     .mres
        xor     ecx, ecx
        inc     edx
        cmp     edx, 24
        jnz     .mres
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc save_draw_mouse ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [_display.move_cursor], 0
        je      .no_hw_cursor
        pushad

        mov     [MOUSE_CURSOR_UNDER_POS.x], eax
        mov     [MOUSE_CURSOR_UNDER_POS.y], ebx
        mov     eax, [MOUSE_CURSOR_POS.y]
        mov     ebx, [MOUSE_CURSOR_POS.x]
        push    eax
        push    ebx

        mov     ecx, [Screen_Max_Pos.x]
        inc     ecx
        mul     ecx
        add     eax, [_WinMapRange.address]
        movzx   edx, byte[ebx + eax]
        shl     edx, 8
        mov     esi, [SLOT_BASE + edx + app_data_t.cursor]

        cmp     esi, [current_cursor]
        je      .draw

        push    esi
        call    [_display.select_cursor]
        mov     [current_cursor], esi

  .draw:
        stdcall [_display.move_cursor], esi
        popad
        ret

  .fail:
        mov     ecx, [def_cursor]
        mov     [SLOT_BASE + edx + app_data_t.cursor], ecx
        stdcall [_display.move_cursor], ecx ; stdcall: [esp]=ebx,eax
        popad
        ret

  .no_hw_cursor:
        pushad
        ; save & draw
        mov     [MOUSE_CURSOR_UNDER_POS.x], eax
        mov     [MOUSE_CURSOR_UNDER_POS.y], ebx
        push    eax
        push    ebx
        xor     ecx, ecx
        xor     edx, edx

align   4
  .drm:
        push    eax
        push    ebx
        push    ecx
        push    edx
        ; helloworld
        push    ecx
        add     eax, ecx ; save picture under mouse
        add     ebx, edx
        push    ecx
        call    getpixel
        mov     [COLOR_TEMP], ecx
        pop     ecx
        mov     eax, edx
        shl     eax, 6
        shl     ecx, 2
        add     eax, ecx
        add     eax, mouseunder
        mov     ebx, [COLOR_TEMP]
        mov     [eax], ebx
        pop     ecx
        mov     edi, edx; y cycle
        shl     edi, 4 ; *16 bytes per row
        add     edi, ecx ; x cycle
        mov     esi, edi
        add     edi, esi
        add     edi, esi ; *3
        add     edi, [MOUSE_PICTURE] ; we have our str address
        mov     esi, edi
        add     esi, 16 * 24 * 3
        push    ecx
        mov     ecx, [COLOR_TEMP]
        call    combine_colors
        mov     [MOUSE_COLOR_MEM], ecx
        pop     ecx
        pop     edx
        pop     ecx
        pop     ebx
        pop     eax
        add     eax, ecx ; we have x coord+cycle
        add     ebx, edx ; and y coord+cycle
        push    ecx
        mov     ecx, [MOUSE_COLOR_MEM]
        mov     edi, 1
        call    [putpixel]
        pop     ecx
        mov     ebx, [esp + 0] ; pure y coord again
        mov     eax, [esp + 4] ; and x
        inc     ecx ; +1 cycle
        cmp     ecx, 16 ; if more than 16
        jnz     .drm
        xor     ecx, ecx
        inc     edx
        cmp     edx, 24
        jnz     .drm
        add     esp, 8
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc combine_colors ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = color ( 00 RR GG BB )
;> edi = ref to new color byte
;> esi = ref to alpha byte
;-----------------------------------------------------------------------------------------------------------------------
;< ecx = new color ( roughly (ecx*[esi]>>8)+([edi]*[esi]>>8) )
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    ebx
        push    edx
        push    ecx
        xor     ecx, ecx
        ; byte 2
        mov     eax, 0xff
        sub     al, [esi + 0]
        mov     ebx, [esp]
        shr     ebx, 16
        and     ebx, 0xff
        mul     ebx
        shr     eax, 8
        add     ecx, eax
        xor     eax, eax
        xor     ebx, ebx
        mov     al, [edi + 0]
        mov     bl, [esi + 0]
        mul     ebx
        shr     eax, 8
        add     ecx, eax
        shl     ecx, 8
        ; byte 1
        mov     eax, 0xff
        sub     al, [esi + 1]
        mov     ebx, [esp]
        shr     ebx, 8
        and     ebx, 0xff
        mul     ebx
        shr     eax, 8
        add     ecx, eax
        xor     eax, eax
        xor     ebx, ebx
        mov     al, [edi + 1]
        mov     bl, [esi + 1]
        mul     ebx
        shr     eax, 8
        add     ecx, eax
        shl     ecx, 8
        ; byte 2
        mov     eax, 0xff
        sub     al, [esi + 2]
        mov     ebx, [esp]
        and     ebx, 0xff
        mul     ebx
        shr     eax, 8
        add     ecx, eax
        xor     eax, eax
        xor     ebx, ebx
        mov     al, [edi + 2]
        mov     bl, [esi + 2]
        mul     ebx
        shr     eax, 8
        add     ecx, eax
        pop     eax
        pop     edx
        pop     ebx
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc __sys_disable_mouse ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [MOUSE_VISIBLE], 0
        je      @f
        ret

    @@: pushad
        cmp     [CURRENT_TASK], 1
        je      .disable_m
        mov     edx, [CURRENT_TASK]
        shl     edx, 5
        add     edx, window_data
        mov     eax, [MOUSE_CURSOR_POS.x]
        mov     ebx, [MOUSE_CURSOR_POS.y]
        mov     ecx, [Screen_Max_Pos.x]
        inc     ecx
        imul    ecx, ebx
        add     ecx, eax
        add     ecx, [_WinMapRange.address]
        mov     eax, [CURRENT_TASK]
        cmp     al, [ecx]
        je      .yes_mouse_disable
        cmp     al, [ecx + 16]
        je      .yes_mouse_disable
        add     ebx, 10
        cmp     ebx, [Screen_Max_Pos.y]
        jae     .no_mouse_disable
        mov     ebx, [Screen_Max_Pos.x]
        inc     ebx
        imul    ebx, 10
        add     ecx, ebx
        cmp     al, [ecx]
        je      .yes_mouse_disable
        cmp     al, [ecx + 16]
        je      .yes_mouse_disable
        jmp     .no_mouse_disable

  .yes_mouse_disable:
        mov     edx, [CURRENT_TASK]
        shl     edx, 5
        add     edx, window_data
        mov     eax, [MOUSE_CURSOR_POS.x]
        mov     ebx, [MOUSE_CURSOR_POS.y]
        mov     ecx, [edx + 0] ; mouse inside the area ?
        add     eax, 10
        cmp     eax, ecx
        jb      .no_mouse_disable
        sub     eax, 10
        add     ecx, [edx + 8]
        cmp     eax, ecx
        jg      .no_mouse_disable
        mov     ecx, [edx + 4]
        add     ebx, 14
        cmp     ebx, ecx
        jb      .no_mouse_disable
        sub     ebx, 14
        add     ecx, [edx + 12]
        cmp     ebx, ecx
        jg      .no_mouse_disable

  .disable_m:
        cmp     [MOUSE_VISIBLE], 0
        jne     .no_mouse_disable
        pushf
        cli
        call    draw_mouse_under
        popf
        mov     [MOUSE_VISIBLE], 1

  .no_mouse_disable:
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc __sys_draw_pointer ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [mouse_pause], 0
        je      @f
        ret

    @@: push    eax
        mov     eax, dword[timer_ticks]
        sub     eax, [MouseTickCounter]
        cmp     eax, 1
        ja      @f
        pop     eax
        ret

    @@: mov     eax, dword[timer_ticks]
        mov     [MouseTickCounter], eax
        pop     eax
        pushad
        cmp     [MOUSE_VISIBLE], 0 ; mouse visible ?
        je      .chms00
        mov     [MOUSE_VISIBLE], 0
        mov     ebx, [MOUSE_CURSOR_POS.y]
        mov     eax, [MOUSE_CURSOR_POS.x]
        pushfd
        cli
        call    save_draw_mouse
        popfd

  .nodmu2:
        popad
        ret

  .chms00:
        mov     ecx, [MOUSE_CURSOR_UNDER_POS.x]
        mov     edx, [MOUSE_CURSOR_UNDER_POS.y]
        mov     ebx, [MOUSE_CURSOR_POS.y]
        mov     eax, [MOUSE_CURSOR_POS.x]
        cmp     eax, ecx
        jne     .redrawmouse
        cmp     ebx, edx
        jne     .redrawmouse
        jmp     .nodmp

  .redrawmouse:
        pushfd
        cli
        call    draw_mouse_under
        call    save_draw_mouse
        popfd

  .nodmp:
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
proc set_mouse_data stdcall, BtnState:dword, XMoving:dword, YMoving:dword, VScroll:dword, HScroll:dword ;///////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [BtnState]
        mov     [BTN_DOWN], al

        mov     eax, [XMoving]
        call    mouse_acceleration
        add     eax, [MOUSE_CURSOR_POS.x] ; [XCoordinate]
        test    eax, eax
        jns     .M1
        xor     eax, eax
        jmp     .M2

  .M1:
        cmp     eax, [Screen_Max_Pos.x] ; ScreenLength
        jl      .M2
        mov     eax, [Screen_Max_Pos.x] ; ScreenLength-1

  .M2:
        mov     [MOUSE_CURSOR_POS.x], eax ; [XCoordinate]

        mov     eax, [YMoving]
        neg     eax
        call    mouse_acceleration

        add     eax, [MOUSE_CURSOR_POS.y] ; [YCoordinate]
        test    eax, eax
        jns     .M3
        xor     eax, eax
        jmp     .M4

  .M3:
        cmp     eax, [Screen_Max_Pos.y] ; ScreenHeigth
        jl      .M4
        mov     eax, [Screen_Max_Pos.y] ; ScreenHeigth-1

  .M4:
        mov     [MOUSE_CURSOR_POS.y], eax ; [YCoordinate]

        mov     eax, [VScroll]
        add     [MOUSE_SCROLL_OFS.y], ax

        mov     eax, [HScroll]
        add     [MOUSE_SCROLL_OFS.x], ax

        mov     [mouse_active], 1
        mov     eax, dword[timer_ticks]
        mov     [mouse_timer_ticks], eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc mouse_acceleration ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, dword[timer_ticks]
        sub     eax, [mouse_timer_ticks]
        cmp     eax, [mouse_delay]
        pop     eax
        ja      @f
;       push    edx
        imul    eax, [mouse_speed_factor]
;       pop     edx

    @@: ret
kendp
