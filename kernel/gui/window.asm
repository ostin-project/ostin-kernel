;;======================================================================================================================
;;///// window.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;;======================================================================================================================
;;///// public functions ///////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

window.BORDER_SIZE = 5

uglobal
  common_colours    rd 32
  draw_limits       rect32_t
  buttontype        rd 1
  windowtypechanged rd 1
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_draw_state ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 12
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.set_draw_state, subfn, sysfn.not_implemented, \
    begin_drawing, \ ; 1
    end_drawing ; 2
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_draw_state.begin_drawing ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 12.1
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [CURRENT_TASK]

  .sys_newba2:
        mov     edi, [BTN_ADDR]
        cmp     dword[edi], 0 ; empty button list?
        je      .exit
        movzx   ebx, word[edi]
        inc     ebx
        mov     eax, edi

  .sys_newba:
        dec     ebx
        jz      .exit

        add     eax, 0x10
        cmp     cx, [eax]
        jnz     .sys_newba

        push    eax ebx ecx
        mov     ecx, ebx
        inc     ecx
        shl     ecx, 4
        mov     ebx, eax
        add     eax, 0x10
        call    memmove
        dec     dword[edi]
        pop     ecx ebx eax

        jmp     .sys_newba2

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_draw_state.end_drawing ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 12.2
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, [TASK_BASE]
        add     edx, draw_data - CURRENT_TASK
        mov     [edx + rect32_t.left], 0
        mov     [edx + rect32_t.top], 0
        mov     eax, [Screen_Max_Pos.x]
        mov     [edx + rect32_t.right], eax
        mov     eax, [Screen_Max_Pos.y]
        mov     [edx + rect32_t.bottom], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.draw_window ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 0
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, edx
        shr     eax, 24
        and     al, 0x0f
        cmp     al, 5
        jae     .exit

        push    eax
        inc     [mouse_pause]
        call    [_display.disable_mouse]
        call    window._.sys_set_window
        call    [_display.disable_mouse]
        pop     eax

        or      al, al
        jnz     @f

        ; type I - original style
        call    drawwindow_I
        jmp     window._.draw_window_caption.2

    @@: dec     al
        jnz     @f

        ; type II - only reserve area, no draw
        call    sys_window_mouse
        dec     [mouse_pause]
        call    [draw_pointer]
        jmp     .exit

    @@: dec     al
        jnz     @f

        ; type III  - new style
        call    drawwindow_III
        jmp     window._.draw_window_caption.2

    @@: ; type IV & V - skinned window (resizable & not)
        mov     eax, [TASK_COUNT]
        movzx   eax, [WIN_POS + eax * 2]
        cmp     eax, [CURRENT_TASK]
        setz    al
        movzx   eax, al
        push    eax
        call    drawwindow_IV
        jmp     window._.draw_window_caption.2

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.display_settings_ctl, subfn, sysfn.not_implemented, \
    redraw_screen, \ ; 0
    set_button_style, \ ; 1
    set_system_color_palette, \ ; 2
    get_system_color_palette, \ ; 3
    get_skinned_caption_height, \ ; 4
    get_screen_working_area, \ ; 5
    set_screen_working_area, \ ; 6
    get_skin_margins, \ ; 7
    set_skin ; 8
endg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]

;-----------------------------------------------------------------------------------------------------------------------
  ._.calculate_whole_screen: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        xor     ebx, ebx
        mov     ecx, [Screen_Max_Pos.x]
        mov     edx, [Screen_Max_Pos.y]
        jmp     calculatescreen

;-----------------------------------------------------------------------------------------------------------------------
  ._.redraw_whole_screen: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        mov     [draw_limits.left], eax
        mov     [draw_limits.top], eax
        mov     eax, [Screen_Max_Pos.x]
        mov     [draw_limits.right], eax
        mov     eax, [Screen_Max_Pos.y]
        mov     [draw_limits.bottom], eax
        mov     eax, window_data
        jmp     redrawscreen
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.redraw_screen ;////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.0: redraw screen
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 0
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        inc     ebx
        cmp     [windowtypechanged], ebx
        jne     .exit
        mov     [windowtypechanged], eax

        jmp     sysfn.display_settings_ctl._.redraw_whole_screen

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.set_button_style ;/////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.1: set button style
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 1
;> ecx = 0 (flat) or 1 (with gradient)
;-----------------------------------------------------------------------------------------------------------------------
        and     ecx, 1
        cmp     ecx, [buttontype]
        je      .exit
        mov     [buttontype], ecx
        mov     [windowtypechanged], ebx

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.set_system_color_palette ;/////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.2: set system color palette
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 2
;> ecx = pointer to color table
;> edx = size of color table
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        mov     esi, ecx
        and     edx, 127
        mov     edi, common_colours
        mov     ecx, edx
        rep
        movsb
        mov     [windowtypechanged], ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.get_system_color_palette ;/////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.3: get system color palette
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 3
;> ecx = pointer to color table buffer
;> edx = size of color table buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, ecx
        and     edx, 127
        mov     esi, common_colours
        mov     ecx, edx
        rep
        movsb
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.get_skinned_caption_height ;///////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.4: get skinned caption height
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 4
;-----------------------------------------------------------------------------------------------------------------------
;< eax = height in pixels
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [_skinh]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.get_screen_working_area ;//////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.5: get screen working area
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 5
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pack[16(left), 16(right)]
;< ebx = pack[16(top), 16(bottom)]
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [screen_workarea.left - 2]
        mov     ax, word[screen_workarea.right]
        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     eax, [screen_workarea.top - 2]
        mov     ax, word[screen_workarea.bottom]
        mov     [esp + 4 + regs_context32_t.ebx], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.set_screen_working_area ;//////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.6: set screen working area
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 6
;> ecx = pack[16(left), 16(right)]
;> edx = pack[16(top), 16(bottom)]
;-----------------------------------------------------------------------------------------------------------------------
        xor     esi, esi

        mov     edi, [Screen_Max_Pos.x]
        mov     eax, ecx
        movsx   ebx, ax
        sar     eax, 16
        cmp     eax, ebx
        jge     .check_horizontal
        inc     esi
        or      eax, eax
        jge     @f
        xor     eax, eax

    @@: mov     [screen_workarea.left], eax
        cmp     ebx, edi
        jle     @f
        mov     ebx, edi

    @@: mov     [screen_workarea.right], ebx

  .check_horizontal:
        mov     edi, [Screen_Max_Pos.y]
        mov     eax, edx
        movsx   ebx, ax
        sar     eax, 16
        cmp     eax, ebx
        jge     .check_if_redraw_needed
        inc     esi
        or      eax, eax
        jge     @f
        xor     eax, eax

    @@: mov     [screen_workarea.top], eax
        cmp     ebx, edi
        jle     @f
        mov     ebx, edi

    @@: mov     [screen_workarea.bottom], ebx

  .check_if_redraw_needed:
        or      esi, esi
        jz      .exit

        call    repos_windows
        jmp     sysfn.display_settings_ctl._.calculate_whole_screen

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.get_skin_margins ;/////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.7: get skin margins
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 7
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pack[16(left), 16(right)]
;< ebx = pack[16(top), 16(bottom)]
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [_skinmargins + 0]
        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     eax, [_skinmargins + 4]
        mov     [esp + 4 + regs_context32_t.ebx], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.display_settings_ctl.set_skin ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 48.8: set skin
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 8
;> ecx = pointer to FileInfoBlock struct
;-----------------------------------------------------------------------------------------------------------------------
;< eax = FS error code
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, ecx
        call    read_skin_file
        mov     [esp + 4 + regs_context32_t.eax], eax
        test    eax, eax
        jnz     .exit

        call    sysfn.display_settings_ctl._.calculate_whole_screen
        jmp     sysfn.display_settings_ctl._.redraw_whole_screen

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_window_shape ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 50
;-----------------------------------------------------------------------------------------------------------------------
;; Set window shape address:
;> ebx = 0
;> ecx = shape data address
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Set window shape scale:
;> ebx = 1
;> ecx = scale power (resulting scale is 2^ebx)
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [current_slot]

        test    ebx, ebx
        jne     .shape_scale
        mov     [edi + app_data_t.wnd_shape], ecx

  .shape_scale:
        dec     ebx
        jnz     .exit
        mov     [edi + app_data_t.wnd_shape_scale], ecx

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.move_window ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 67
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [CURRENT_TASK]
        shl     edi, 5
        add     edi, window_data

        test    [edi + window_data_t.fl_wdrawn], 1
        jz      .exit

        test    [edi + window_data_t.fl_wstate], WSTATE_MAXIMIZED
        jnz     .exit

        cmp     ebx, -1
        jne     @f
        mov     ebx, [edi + window_data_t.box.left]

    @@: cmp     ecx, -1
        jne     @f
        mov     ecx, [edi + window_data_t.box.top]

    @@: cmp     edx, -1
        jne     @f
        mov     edx, [edi + window_data_t.box.width]

    @@: cmp     esi, -1
        jne     @f
        mov     esi, [edi + window_data_t.box.height]

    @@: push    esi edx ecx ebx
        mov     eax, esp
        mov     bl, [edi + window_data_t.fl_wstate]
        call    window._.set_window_box
        add     esp, sizeof.box32_t

        ; NOTE: do we really need this? to be reworked
;       mov     [DONT_DRAW_MOUSE], 0 ; mouse pointer
;       mov     [MOUSE_BACKGROUND], 0 ; no mouse under
;       mov     [MOUSE_DOWN], 0 ; react to mouse up/down

        ; NOTE: do we really need this? to be reworked
;       call    [draw_pointer]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.window_settings ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 71
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx ; subfunction #1 - set window caption
        jnz     .exit_fail

        ; NOTE: only window owner thread can set its caption,
        ;       so there's no parameter for PID/TID

        mov     edi, [CURRENT_TASK]
        shl     edi, 5

        mov     [SLOT_BASE + edi * 8 + app_data_t.wnd_caption], ecx
        or      [window_data + edi + window_data_t.fl_wstyle], WSTYLE_HASCAPTION

        call    window._.draw_window_caption

        xor     eax, eax ; eax = 0 (success)
        ret

; .get_window_caption:
;       dec     eax ; subfunction #2 - get window caption
;       jnz     .exit_fail

        ; not implemented yet

  .exit_fail:
        xor     eax, eax
        inc     eax ; eax = 1 (fail)
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc set_window_defaults ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        mov     byte[window_data + sizeof.window_data_t + window_data_t.cl_titlebar + 3], 1 ; desktop is not movable
        push    eax ecx
        xor     eax, eax
        mov     ecx, WIN_STACK

    @@: inc     eax
        add     ecx, 2
        ; process no
        mov     [ecx], ax
        ; positions in stack
        mov     [ecx + WIN_POS - WIN_STACK], ax
        cmp     ecx, WIN_POS - 2
        jne     @b
        pop     ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculatescreen ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Scan all windows from bottom to top, calling `setscreen` for each one
;? intersecting given screen area
;-----------------------------------------------------------------------------------------------------------------------
;> eax = left
;> ebx = top
;> ecx = right
;> edx = bottom
;-----------------------------------------------------------------------------------------------------------------------
        push    esi
        pushfd
        cli

        mov     esi, 1
        call    window._.set_screen

        push    ebp

        mov     ebp, [TASK_COUNT]
        cmp     ebp, 1
        jbe     .exit

        push    edx ecx ebx eax

  .next_window:
        movzx   edi, [WIN_POS + esi * 2]
        shl     edi, 5

        cmp     [TASK_DATA + edi - sizeof.task_data_t + task_data_t.state], TSTATE_FREE
        je      .skip_window

        add     edi, window_data
        test    [edi + window_data_t.fl_wstate], WSTATE_MINIMIZED
        jnz     .skip_window

        mov     eax, [edi + window_data_t.box.left]
        cmp     eax, [esp + rect32_t.right]
        jg      .skip_window
        mov     ebx, [edi + window_data_t.box.top]
        cmp     ebx, [esp + rect32_t.bottom]
        jg      .skip_window
        mov     ecx, [edi + window_data_t.box.width]
        add     ecx, eax
        cmp     ecx, [esp + rect32_t.left]
        jl      .skip_window
        mov     edx, [edi + window_data_t.box.height]
        add     edx, ebx
        cmp     edx, [esp + rect32_t.top]
        jl      .skip_window

        cmp     eax, [esp + rect32_t.left]
        jae     @f
        mov     eax, [esp + rect32_t.left]

    @@: cmp     ebx, [esp + rect32_t.top]
        jae     @f
        mov     ebx, [esp + rect32_t.top]

    @@: cmp     ecx, [esp + rect32_t.right]
        jbe     @f
        mov     ecx, [esp + rect32_t.right]

    @@: cmp     edx, [esp + rect32_t.bottom]
        jbe     @f
        mov     edx, [esp + rect32_t.bottom]

    @@: push    esi
        movzx   esi, [WIN_POS + esi * 2]
        call    window._.set_screen
        pop     esi

  .skip_window:
        inc     esi
        dec     ebp
        jnz     .next_window

        pop     eax ebx ecx edx

  .exit:
        pop     ebp
        popfd
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc repos_windows ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [TASK_COUNT]
        mov     edi, window_data + 2 * sizeof.window_data_t
        call    force_redraw_background
        dec     ecx
        jle     .exit

  .next_window:
        mov     [edi + window_data_t.fl_redraw], 1
        test    [edi + window_data_t.fl_wstate], WSTATE_MAXIMIZED
        jnz     .fix_maximized

        mov     eax, [edi + window_data_t.box.left]
        add     eax, [edi + window_data_t.box.width]
        mov     ebx, [Screen_Max_Pos.x]
        cmp     eax, ebx
        jle     .fix_vertical
        mov     eax, [edi + window_data_t.box.width]
        sub     eax, ebx
        jle     @f
        mov     [edi + window_data_t.box.width], ebx

    @@: sub     ebx, [edi + window_data_t.box.width]
        mov     [edi + window_data_t.box.left], ebx

  .fix_vertical:
        mov     eax, [edi + window_data_t.box.top]
        add     eax, [edi + window_data_t.box.height]
        mov     ebx, [Screen_Max_Pos.y]
        cmp     eax, ebx
        jle     .fix_client_box
        mov     eax, [edi + window_data_t.box.height]
        sub     eax, ebx
        jle     @f
        mov     [edi + window_data_t.box.height], ebx

    @@: sub     ebx, [edi + window_data_t.box.height]
        mov     [edi + window_data_t.box.top], ebx
        jmp     .fix_client_box

  .fix_maximized:
        mov     eax, [screen_workarea.left]
        mov     [edi + window_data_t.box.left], eax
        sub     eax, [screen_workarea.right]
        neg     eax
        mov     [edi + window_data_t.box.width], eax
        mov     eax, [screen_workarea.top]
        mov     [edi + window_data_t.box.top], eax
        test    [edi + window_data_t.fl_wstate], WSTATE_ROLLEDUP
        jnz     .fix_client_box
        sub     eax, [screen_workarea.bottom]
        neg     eax
        mov     [edi + window_data_t.box.height], eax

  .fix_client_box:
        call    window._.set_window_clientbox

        add     edi, sizeof.window_data_t
        loop    .next_window

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_window_mouse ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        ; NOTE: commented out since doesn't provide necessary functionality
        ;       anyway, to be reworked
;       push    eax
;
;       mov     eax, [timer_ticks]
;       cmp     [new_window_starting], eax
;       jb      .exit
;
;       mov     [MOUSE_BACKGROUND], 0
;       mov     [DONT_DRAW_MOUSE], 0
;
;       mov     [new_window_starting], eax
;
; .exit:
;       pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc draw_rectangle ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pack[16(left), 16(right)]
;> ebx = pack[16(top), 16(bottom)]
;> esi = color
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx edi

        xor     edi, edi

  .flags_set:
        push    ebx

        ; set line color
        mov     ecx, esi

        ; draw top border
        rol     ebx, 16
        push    ebx
        rol     ebx, 16
        pop     bx
        call    [draw_line]

        ; draw bottom border
        mov     ebx, [esp - 2]
        pop     bx
        call    [draw_line]

        pop     ebx
        add     ebx, 1 * 65536 - 1

        ; draw left border
        rol     eax, 16
        push    eax
        rol     eax, 16
        pop     ax
        call    [draw_line]

        ; draw right border
        mov     eax, [esp - 2]
        pop     ax
        call    [draw_line]

        pop     edi ecx ebx eax
        ret

  .forced:
        push    eax ebx ecx edi
        xor     edi, edi
        inc     edi
        jmp     .flags_set
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc drawwindow_I_caption ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        push    [edx + window_data_t.cl_titlebar]
        mov     esi, edx

        mov     edx, [esi + window_data_t.box.top]
        mov     eax, edx
        lea     ebx, [edx + 21]
        inc     edx
        add     eax, [esi + window_data_t.box.height]

        cmp     ebx, eax
        jbe     @f
        mov     ebx, eax
    @@: push    ebx

        xor     edi, edi

  .next_line:
        mov     ebx, edx
        shl     ebx, 16
        add     ebx, edx
        mov     eax, [esi + window_data_t.box.left]
        inc     eax
        shl     eax, 16
        add     eax, [esi + window_data_t.box.left]
        add     eax, [esi + window_data_t.box.width]
        dec     eax
        mov     ecx, [esi + window_data_t.cl_titlebar]
        test    ecx, 0x80000000
        jz      @f
        sub     ecx, 0x00040404
        mov     [esi + window_data_t.cl_titlebar], ecx

    @@: and     ecx, 0x00ffffff
        call    [draw_line]
        inc     edx
        cmp     edx, [esp]
        jb      .next_line

        add     esp, 4
        pop     [esi + window_data_t.cl_titlebar]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc drawwindow_I ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        pushad

        ; window border

        mov     eax, [edx + window_data_t.box.left - 2]
        mov     ax, word[edx + window_data_t.box.left]
        add     ax, word[edx + window_data_t.box.width]
        mov     ebx, [edx + window_data_t.box.top - 2]
        mov     bx, word[edx + window_data_t.box.top]
        add     bx, word[edx + window_data_t.box.height]

        mov     esi, [edx + window_data_t.cl_frames]
        call    draw_rectangle

        ; window caption

        call    drawwindow_I_caption

        ; window client area

        ; do we need to draw it?
        mov     edi, [esi + window_data_t.cl_workarea]
        test    edi, 0x40000000
        jnz     .exit

        ; does client area have a positive size on screen?
        mov     edx, [esi + window_data_t.box.top]
        add     edx, 21 + 5
        mov     ebx, [esi + window_data_t.box.top]
        add     ebx, [esi + window_data_t.box.height]
        cmp     edx, ebx
        jg      .exit

        ; okay, let's draw it
        mov     eax, 1
        mov     ebx, 21
        mov     ecx, [esi + window_data_t.box.width]
        mov     edx, [esi + window_data_t.box.height]
        call    [drawbar]

  .exit:
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc drawwindow_III_caption ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [edx + window_data_t.cl_titlebar]
        push    ecx
        mov     esi, edx
        mov     edx, [esi + window_data_t.box.top]
        add     edx, 4
        mov     ebx, [esi + window_data_t.box.top]
        add     ebx, 20
        mov     eax, [esi + window_data_t.box.top]
        add     eax, [esi + window_data_t.box.height]

        cmp     ebx, eax
        jb      @f
        mov     ebx, eax

    @@: push    ebx

        xor     edi, edi

  .next_line:
        mov     ebx, edx
        shl     ebx, 16
        add     ebx, edx
        mov     eax, [esi + window_data_t.box.left]
        shl     eax, 16
        add     eax, [esi + window_data_t.box.left]
        add     eax, [esi + window_data_t.box.width]
        add     eax, 4 * 65536 - 4
        mov     ecx, [esi + window_data_t.cl_titlebar]
        test    ecx, 0x40000000
        jz      @f
        add     ecx, 0x00040404

    @@: test    ecx, 0x80000000
        jz      @f
        sub     ecx, 0x00040404

    @@: mov     [esi + window_data_t.cl_titlebar], ecx
        and     ecx, 0x00ffffff
        call    [draw_line]
        inc     edx
        cmp     edx, [esp]
        jb      .next_line

        add     esp, 4
        pop     [esi + window_data_t.cl_titlebar]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc drawwindow_III ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        pushad

        ; window border

        mov     eax, [edx + window_data_t.box.left - 2]
        mov     ax, word[edx + window_data_t.box.left]
        add     ax, word[edx + window_data_t.box.width]
        mov     ebx, [edx + window_data_t.box.top - 2]
        mov     bx, word[edx + window_data_t.box.top]
        add     bx, word[edx + window_data_t.box.height]

        mov     esi, [edx + window_data_t.cl_frames]
        shr     esi, 1
        and     esi, 0x007f7f7f
        call    draw_rectangle

        push    esi
        mov     ecx, 3
        mov     esi, [edx + window_data_t.cl_frames]

  .next_frame:
        add     eax, 1 * 65536 - 1
        add     ebx, 1 * 65536 - 1
        call    draw_rectangle
        dec     ecx
        jnz     .next_frame

        pop     esi
        add     eax, 1 * 65536 - 1
        add     ebx, 1 * 65536 - 1
        call    draw_rectangle

        ; window caption

        call    drawwindow_III_caption

        ; window client area

        ; do we need to draw it?
        mov     edi, [esi + window_data_t.cl_workarea]
        test    edi, 0x40000000
        jnz     .exit

        ; does client area have a positive size on screen?
        mov     edx, [esi + window_data_t.box.top]
        add     edx, 21 + 5
        mov     ebx, [esi + window_data_t.box.top]
        add     ebx, [esi + window_data_t.box.height]
        cmp     edx, ebx
        jg      .exit

        ; okay, let's draw it
        mov     eax, 5
        mov     ebx, 20
        mov     ecx, [esi + window_data_t.box.width]
        mov     edx, [esi + window_data_t.box.height]
        sub     ecx, 4
        sub     edx, 4
        call    [drawbar]

  .exit:
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc waredraw ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Activate window, redrawing if necessary
;-----------------------------------------------------------------------------------------------------------------------
        push    -1
        mov     eax, [TASK_COUNT]
        lea     eax, [WIN_POS + eax * 2]
        cmp     eax, esi
        pop     eax
        je      .exit

        ; is it overlapped by another window now?
        push    ecx
        call    window._.check_window_draw
        test    ecx, ecx
        pop     ecx
        jz      .do_not_draw

        ; yes it is, activate and update screen buffer
;       mov     [MOUSE_DOWN], 1
        call    window._.window_activate

        pushad
        mov     edi, [TASK_COUNT]
        movzx   esi, [WIN_POS + edi * 2]
        shl     esi, 5
        add     esi, window_data

        mov     eax, [esi + window_data_t.box.left]
        mov     ebx, [esi + window_data_t.box.top]
        mov     ecx, [esi + window_data_t.box.width]
        mov     edx, [esi + window_data_t.box.height]

        add     ecx, eax
        add     edx, ebx

        mov     edi, [TASK_COUNT]
        movzx   esi, [WIN_POS + edi * 2]
        call    window._.set_screen
        popad

        ; tell application to redraw itself
        mov     [edi + window_data_t.fl_redraw], 1
        xor     eax, eax
        jmp     .exit

  .do_not_draw:
        ; no it's not, just activate the window
        call    window._.window_activate
        xor     eax, eax
;       mov     [MOUSE_BACKGROUND], al
;       mov     [DONT_DRAW_MOUSE], al


  .exit:
;       mov     [MOUSE_DOWN], 0
        inc     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc minimize_window ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = window number on screen
;-----------------------------------------------------------------------------------------------------------------------
;# corrupts [dl*]
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        pushfd
        cli

        ; is it already minimized?
        movzx   edi, [WIN_POS + eax * 2]
        shl     edi, 5
        add     edi, window_data
        test    [edi + window_data_t.fl_wstate], WSTATE_MINIMIZED
        jnz     .exit

        push    eax ebx ecx edx esi

        ; no it's not, let's do that
        or      [edi + window_data_t.fl_wstate], WSTATE_MINIMIZED
        mov     eax, [edi + window_data_t.box.left]
        mov     [draw_limits.left], eax
        mov     ecx, eax
        add     ecx, [edi + window_data_t.box.width]
        mov     [draw_limits.right], ecx
        mov     ebx, [edi + window_data_t.box.top]
        mov     [draw_limits.top], ebx
        mov     edx, ebx
        add     edx, [edi + window_data_t.box.height]
        mov     [draw_limits.bottom], edx
        call    calculatescreen
        xor     esi, esi
        xor     eax, eax
        call    redrawscreen

        pop     esi edx ecx ebx eax

  .exit:
        popfd
        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc restore_minimized_window ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = window number on screen
;-----------------------------------------------------------------------------------------------------------------------
;# corrupts [dl*]
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        pushfd
        cli

        ; is it already restored?
        movzx   esi, [WIN_POS + eax * 2]
        mov     edi, esi
        shl     edi, 5
        add     edi, window_data
        test    [edi + window_data_t.fl_wstate], WSTATE_MINIMIZED
        jz      .exit

        ; no it's not, let's do that
        mov     [edi + window_data_t.fl_redraw], 1
        and     [edi + window_data_t.fl_wstate], not WSTATE_MINIMIZED
        mov     ebp, window._.set_screen
        cmp     eax, [TASK_COUNT]
        jz      @f
        mov     ebp, calculatescreen

    @@: mov     eax, [edi + window_data_t.box.left]
        mov     ebx, [edi + window_data_t.box.top]
        mov     ecx, [edi + window_data_t.box.width]
        mov     edx, [edi + window_data_t.box.height]
        add     ecx, eax
        add     edx, ebx
        call    ebp

;       mov     [MOUSE_BACKGROUND], 0

  .exit:
        popfd
        popad
        ret
kendp

; TODO: remove this proc
;-----------------------------------------------------------------------------------------------------------------------
kproc window_check_events ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        ; do we have window minimize/restore request?
        cmp     [window_minimize], 0
        je      .exit

        ; okay, minimize or restore top-most window and exit
        mov     eax, [TASK_COUNT]
        mov     bl, 0
        xchg    [window_minimize], bl
        dec     bl
        jnz     @f
        call    minimize_window
        jmp     .exit

    @@: call    restore_minimized_window

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_window_maximize_handler ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> esi = process slot
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, esi
        shl     edi, 5
        add     edi, window_data

        ; can window change its height?
        ; only types 2 and 3 can be resized
        mov     dl, [edi + window_data_t.fl_wstyle]
        test    dl, 2
        jz      .exit

        ; toggle normal/maximized window state
        mov     bl, [edi + window_data_t.fl_wstate]
        xor     bl, WSTATE_MAXIMIZED

        ; calculate and set appropriate window bounds
        test    bl, WSTATE_MAXIMIZED
        jz      .restore_size

        mov     eax, [screen_workarea.left]
        mov     ecx, [screen_workarea.top]
        push    [screen_workarea.bottom] \
                [screen_workarea.right] \
                ecx \
                eax
        sub     [esp + box32_t.width], eax
        sub     [esp + box32_t.height], ecx
        mov     eax, esp
        jmp     .set_box

  .restore_size:
        mov     eax, esi
        shl     eax, 8
        add     eax, SLOT_BASE + app_data_t.saved_box
        push    [eax + box32_t.height] \
                [eax + box32_t.width] \
                [eax + box32_t.top] \
                [eax + box32_t.left]
        mov     eax, esp

  .set_box:
        test    bl, WSTATE_ROLLEDUP
        jz      @f

        xchg    eax, ecx
        call    window._.get_rolledup_height
        mov     [ecx + box32_t.height], eax
        xchg    eax, ecx

    @@: call    window._.set_window_box
        add     esp, sizeof.box32_t

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_window_rollup_handler ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> esi = process slot
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, esi
        shl     edx, 8
        add     edx, SLOT_BASE

        ; toggle normal/rolled up window state
        mov     bl, [edi + window_data_t.fl_wstate]
        xor     bl, WSTATE_ROLLEDUP

        ; calculate and set appropriate window bounds
        test    bl, WSTATE_ROLLEDUP
        jz      .restore_size

        call    window._.get_rolledup_height
        push    eax \
                [edi + window_data_t.box.width] \
                [edi + window_data_t.box.top] \
                [edi + window_data_t.box.left]
        mov     eax, esp
        jmp     .set_box

  .restore_size:
        test    bl, WSTATE_MAXIMIZED
        jnz     @f
        add     esp, -sizeof.box32_t
        lea     eax, [edx + app_data_t.saved_box]
        jmp     .set_box

    @@: mov     eax, [screen_workarea.top]
        push    [screen_workarea.bottom] \
                [edi + window_data_t.box.width] \
                eax \
                [edi + window_data_t.box.left]
        sub     [esp + box32_t.height], eax
        mov     eax, esp

  .set_box:
        call    window._.set_window_box
        add     esp, sizeof.box32_t

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_window_start_moving_handler ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> eax = old (original) window box
;> esi = process slot
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, eax
        call    window._.draw_negative_box

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_window_end_moving_handler ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> eax = old (original) window box
;> ebx = new (final) window box
;> esi = process slot
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, ebx
        call    window._.draw_negative_box

        mov     edi, esi
        shl     edi, 5
        add     edi, window_data

        mov     eax, ebx
        mov     bl, [edi + window_data_t.fl_wstate]
        call    window._.set_window_box
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_window_moving_handler ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> eax = old (from previous call) window box
;> ebx = new (current) window box
;> esi = process_slot
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, eax
        call    window._.draw_negative_box
        mov     edi, ebx
        call    window._.draw_negative_box
        ret
kendp

;;======================================================================================================================
;;///// private functions //////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

iglobal
  align 4
  window_topleft dd \
    1, 21, \ ; type 0
    0,  0, \ ; type 1
    5, 20, \ ; type 2
    5,  ?, \ ; type 3 {set by skin}
    5,  ?    ; type 4 {set by skin}
endg

;uglobal
  ; NOTE: commented out since doesn't provide necessary functionality anyway,
  ;       to be reworked
; new_window_starting       dd ?
;endg

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.invalidate_screen ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> eax = old (original) window box
;> ebx = new (final) window box
;> edi = pointer to window_data_t struct
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx

        ; TODO: do we really need `draw_limits`?
        ; Yes, they are used by background drawing code.
        mov     ecx, [eax + box32_t.left]
        mov     edx, [ebx + box32_t.left]
        cmp     ecx, edx
        jle     @f
        mov     ecx, edx

    @@: mov     [draw_limits.left], ecx
        mov     ecx, [eax + box32_t.left]
        add     ecx, [eax + box32_t.width]
        add     edx, [ebx + box32_t.width]
        cmp     ecx, edx
        jae     @f
        mov     ecx, edx

    @@: mov     [draw_limits.right], ecx
        mov     ecx, [eax + box32_t.top]
        mov     edx, [ebx + box32_t.top]
        cmp     ecx, edx
        jle     @f
        mov     ecx, edx

    @@: mov     [draw_limits.top], ecx
        mov     ecx, [eax + box32_t.top]
        add     ecx, [eax + box32_t.height]
        add     edx, [ebx + box32_t.height]
        cmp     ecx, edx
        jae     @f
        mov     ecx, edx

    @@: mov     [draw_limits.bottom], ecx

        ; recalculate screen buffer at old position
        push    ebx
        mov     edx, [eax + box32_t.height]
        mov     ecx, [eax + box32_t.width]
        mov     ebx, [eax + box32_t.top]
        mov     eax, [eax + box32_t.left]
        add     ecx, eax
        add     edx, ebx
        call    calculatescreen
        pop     eax

        ; recalculate screen buffer at new position
        mov     edx, [eax + box32_t.height]
        mov     ecx, [eax + box32_t.width]
        mov     ebx, [eax + box32_t.top]
        mov     eax, [eax + box32_t.left]
        add     ecx, eax
        add     edx, ebx
        call    calculatescreen

        mov     eax, edi
        call    redrawscreen

        ; tell window to redraw itself
        mov     [edi + window_data_t.fl_redraw], 1

        pop     ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.set_window_box ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pointer to box32_t struct
;> bl = new window state flags
;> edi = pointer to window_data_t struct
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx esi

        ; don't do anything if the new box is identical to the old
        cmp     bl, [edi + window_data_t.fl_wstate]
        jnz     @f
        mov     esi, eax
        push    edi

if window_data_t.box

        add     edi, window_data_t.box

end if

        mov     ecx, 4
        repz
        cmpsd
        pop     edi
        jz      .exit

    @@: add     esp, -sizeof.box32_t

        mov     ebx, esp

if window_data_t.box

        lea     esi, [edi + window_data_t.box]

else

        mov     esi, edi ; optimization for window_data_t.box = 0

end if

        xchg    eax, esi
        mov     ecx, sizeof.box32_t
        call    memmove
        xchg    eax, esi
        xchg    ebx, esi
        call    memmove
        mov     eax, ebx
        mov     ebx, esi

        call    window._.check_window_position
        call    window._.set_window_clientbox
        call    window._.invalidate_screen

        add     esp, sizeof.box32_t

        mov     cl, [esp + 4]
        mov     ch, cl
        xchg    cl, [edi + window_data_t.fl_wstate]

        or      cl, ch
        test    cl, WSTATE_MAXIMIZED
        jnz     .exit

        mov     eax, edi
        sub     eax, window_data
        shl     eax, 3
        add     eax, SLOT_BASE

        lea     ebx, [edi + window_data_t.box]
        xchg    esp, ebx

        pop     [eax + app_data_t.saved_box.left] \
                [eax + app_data_t.saved_box.top] \
                [eax + app_data_t.saved_box.width] \
                edx

        xchg    esp, ebx

        test    ch, WSTATE_ROLLEDUP
        jnz     .exit

        mov     [eax + app_data_t.saved_box.height], edx

  .exit:
        pop     esi ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.set_window_clientbox ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to window_data_t struct
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edi

        mov     eax, [_skinh]
        mov     [window_topleft + 8 * 3 + 4], eax
        mov     [window_topleft + 8 * 4 + 4], eax

        mov     ecx, edi
        sub     edi, window_data
        shl     edi, 3
        test    [ecx + window_data_t.fl_wstyle], WSTYLE_CLIENTRELATIVE
        jz      .whole_window

        movzx   eax, [ecx + window_data_t.fl_wstyle]
        and     eax, 0x0f
        mov     eax, [eax * 8 + window_topleft + 0]
        mov     [SLOT_BASE + edi + app_data_t.wnd_clientbox.left], eax
        shl     eax, 1
        neg     eax
        add     eax, [ecx + window_data_t.box.width]
        mov     [SLOT_BASE + edi + app_data_t.wnd_clientbox.width], eax

        movzx   eax, [ecx + window_data_t.fl_wstyle]
        and     eax, 0x0f
        push    [eax * 8 + window_topleft + 0]
        mov     eax, [eax * 8 + window_topleft + 4]
        mov     [SLOT_BASE + edi + app_data_t.wnd_clientbox.top], eax
        neg     eax
        sub     eax, [esp]
        add     eax, [ecx + window_data_t.box.height]
        mov     [SLOT_BASE + edi + app_data_t.wnd_clientbox.height], eax
        add     esp, 4
        jmp     .exit

  .whole_window:
        xor     eax, eax
        mov     [SLOT_BASE + edi + app_data_t.wnd_clientbox.left], eax
        mov     [SLOT_BASE + edi + app_data_t.wnd_clientbox.top], eax
        mov     eax, [ecx + window_data_t.box.width]
        mov     [SLOT_BASE + edi + app_data_t.wnd_clientbox.width], eax
        mov     eax, [ecx + window_data_t.box.height]
        mov     [SLOT_BASE + edi + app_data_t.wnd_clientbox.height], eax

  .exit:
        pop     edi ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.sys_set_window ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;< edx = pointer to window_data_t struct
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [CURRENT_TASK]
        shl     eax, 5
        add     eax, window_data

        ; save window colors
        mov     [eax + window_data_t.cl_workarea], edx
        mov     [eax + window_data_t.cl_titlebar], esi
        mov     [eax + window_data_t.cl_frames], edi

        mov     edi, eax

        ; was it already defined before?
        test    [edi + window_data_t.fl_wdrawn], 1
        jnz     .set_client_box
        or      [edi + window_data_t.fl_wdrawn], 1

        ; NOTE: commented out since doesn't provide necessary functionality anyway, to be reworked
;       mov     eax, [timer_ticks] ; [0xfdf0]
;       add     eax, 1 * KCONFIG_SYS_TIMER_FREQ
;       mov     [new_window_starting], eax

        ; no it wasn't, performing initial window definition
        movzx   eax, bx
        mov     [edi + window_data_t.box.width], eax
        movzx   eax, cx
        mov     [edi + window_data_t.box.height], eax
        sar     ebx, 16
        sar     ecx, 16
        mov     [edi + window_data_t.box.left], ebx
        mov     [edi + window_data_t.box.top], ecx

        call    window._.check_window_position

        push    ecx edi

        mov     cl, [edi + window_data_t.fl_wstyle]
        mov     eax, [edi + window_data_t.cl_frames]

        sub     edi, window_data
        shl     edi, 3
        add     edi, SLOT_BASE

        and     cl, 0x0f
        cmp     cl, 3
        je      @f
        cmp     cl, 4
        je      @f

        xor     eax, eax

    @@: mov     [edi + app_data_t.wnd_caption], eax

        mov     esi, [esp]
        add     edi, app_data_t.saved_box
        movsd
        movsd
        movsd
        movsd

        pop     edi ecx

        mov     esi, [CURRENT_TASK]
        movzx   esi, [WIN_STACK + esi * 2]
        lea     esi, [WIN_POS + esi * 2]
        call    waredraw

        mov     eax, [edi + window_data_t.box.left]
        mov     ebx, [edi + window_data_t.box.top]
        mov     ecx, [edi + window_data_t.box.width]
        mov     edx, [edi + window_data_t.box.height]
        add     ecx, eax
        add     edx, ebx
        call    calculatescreen

        mov     [KEY_COUNT], 0 ; empty keyboard buffer
        mov     [BTN_COUNT], 0 ; empty button buffer

  .set_client_box:
        ; update window client box coordinates
        call    window._.set_window_clientbox

        ; reset window redraw flag and exit
        mov     [edi + window_data_t.fl_redraw], 0
        mov     edx, edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.check_window_position ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Check if window is inside screen area
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to window_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx edx esi

        mov     eax, [edi + window_data_t.box.left]
        mov     ebx, [edi + window_data_t.box.top]
        mov     ecx, [edi + window_data_t.box.width]
        mov     edx, [edi + window_data_t.box.height]

        mov     esi, [Screen_Max_Pos.x]
        cmp     ecx, esi
        ja      .fix_width_high

  .check_left:
        or      eax, eax
        jl      .fix_left_low
        add     eax, ecx
        cmp     eax, esi
        jg      .fix_left_high

  .check_height:
        mov     esi, [Screen_Max_Pos.y]
        cmp     edx, esi
        ja      .fix_height_high

  .check_top:
        or      ebx, ebx
        jl      .fix_top_low
        add     ebx, edx
        cmp     ebx, esi
        jg      .fix_top_high

  .exit:
        pop     esi edx ecx ebx eax
        ret

  .fix_width_high:
        mov     ecx, esi
        mov     [edi + window_data_t.box.width], esi
        jmp     .check_left

  .fix_left_low:
        xor     eax, eax
        mov     [edi + window_data_t.box.left], eax
        jmp     .check_height

  .fix_left_high:
        mov     eax, esi
        sub     eax, ecx
        mov     [edi + window_data_t.box.left], eax
        jmp     .check_height

  .fix_height_high:
        mov     edx, esi
        mov     [edi + window_data_t.box.height], esi
        jmp     .check_top

  .fix_top_low:
        xor     ebx, ebx
        mov     [edi + window_data_t.box.top], ebx
        jmp     .exit

  .fix_top_high:
        mov     ebx, esi
        sub     ebx, edx
        mov     [edi + window_data_t.box.top], ebx
        jmp     .exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.get_titlebar_height ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to window_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [edi + window_data_t.fl_wstyle]
        and     al, 0x0f
        cmp     al, 0x03
        jne     @f
        mov     eax, [_skinh]
        ret

    @@: mov     eax, 21
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.get_rolledup_height ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to window_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [edi + window_data_t.fl_wstyle]
        and     al, 0x0f
        cmp     al, 0x03
        jb      @f
        mov     eax, [_skinh]
        add     eax, 3
        ret

    @@: or      al, al
        jnz     @f
        mov     eax, 21
        ret

    @@: mov     eax, 21 + 2
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.set_screen ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Reserve window area in screen buffer
;-----------------------------------------------------------------------------------------------------------------------
;> eax = left
;> ebx = top
;> ecx = right
;> edx = bottom
;> esi = process number
;-----------------------------------------------------------------------------------------------------------------------
virtual at esp
  ff_x     dd ?
  ff_y     dd ?
  ff_width dd ?
  ff_xsz   dd ?
  ff_ysz   dd ?
  ff_scale dd ?
end virtual

        pushad

        cmp     esi, 1
        jz      .check_for_shaped_window
        mov     edi, esi
        shl     edi, 5
        cmp     [window_data + edi + window_data_t.box.width], 0
        jnz     .check_for_shaped_window
        cmp     [window_data + edi + window_data_t.box.height], 0
        jz      .exit

  .check_for_shaped_window:
        mov     edi, esi
        shl     edi, 8
        add     edi, SLOT_BASE
        cmp     [edi + app_data_t.wnd_shape], 0
        jne     .shaped_window

        ; get x&y size
        sub     ecx, eax
        sub     edx, ebx
        inc     ecx
        inc     edx

        ; get WinMap start
        push    esi
        mov     edi, [Screen_Max_Pos.x]
        inc     edi
        mov     esi, edi
        imul    edi, ebx
        add     edi, eax
        add     edi, [_WinMapRange.address]
        pop     eax
        mov     ah, al
        push    ax
        shl     eax, 16
        pop     ax

  .next_line:
        push    ecx
        shr     ecx, 2
        rep
        stosd
        mov     ecx, [esp]
        and     ecx, 3
        rep
        stosb
        pop     ecx
        add     edi, esi
        sub     edi, ecx
        dec     edx
        jnz     .next_line

        jmp     .exit

  .shaped_window:
        ;  for (y=0; y <= x_size; y++)
        ;      for (x=0; x <= x_size; x++)
        ;          if (shape[coord(x,y,scale)]==1)
        ;             set_pixel(x, y, process_number);

        sub     ecx, eax
        sub     edx, ebx
        inc     ecx
        inc     edx

        push    [edi + app_data_t.wnd_shape_scale] ; push scale first -> for loop

        ; get WinMap start  -> ebp
        push    eax
        mov     eax, [Screen_Max_Pos.x] ; screen_sx
        inc     eax
        imul    eax, ebx
        add     eax, [esp]
        add     eax, [_WinMapRange.address]
        mov     ebp, eax

        mov     edi, [edi + app_data_t.wnd_shape]
        pop     eax

        ; eax = x_start
        ; ebx = y_start
        ; ecx = x_size
        ; edx = y_size
        ; esi = process_number
        ; edi = &shape
        ;       [scale]
        push    edx ecx ; for loop - x,y size

        mov     ecx, esi
        shl     ecx, 5
        mov     edx, [window_data + ecx + window_data_t.box.top]
        push    [window_data + ecx + window_data_t.box.width] ; for loop - width
        mov     ecx, [window_data + ecx + window_data_t.box.left]
        sub     ebx, edx
        sub     eax, ecx
        push    ebx eax ; for loop - x,y

        add     [ff_xsz], eax
        add     [ff_ysz], ebx

        mov     ebx, [ff_y]

  .ff_new_y:
        mov     edx, [ff_x]

  .ff_new_x:
        ; -- body --
        mov     ecx, [ff_scale]
        mov     eax, [ff_width]
        inc     eax
        shr     eax, cl
        push    ebx edx
        shr     ebx, cl
        shr     edx, cl
        imul    eax, ebx
        add     eax, edx
        pop     edx ebx
        add     eax, edi
        call    .read_byte
        test    al, al
        jz      @f
        mov     eax, esi
        mov     [ebp], al
        ; -- end body --

    @@: inc     ebp
        inc     edx
        cmp     edx, [ff_xsz]
        jb      .ff_new_x

        sub     ebp, [ff_xsz]
        add     ebp, [ff_x]
        add     ebp, [Screen_Max_Pos.x] ; screen.x
        inc     ebp
        inc     ebx
        cmp     ebx, [ff_ysz]
        jb      .ff_new_y

        add     esp, 24

  .exit:
        popad
        ret

  .read_byte:
        ; eax - address
        ; esi - slot
        push    eax ecx edx esi
        xchg    eax, esi
        lea     ecx, [esp + 12]
        mov     edx, 1
        call    read_process_memory
        pop     esi edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.window_activate ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Activate window
;-----------------------------------------------------------------------------------------------------------------------
;> esi = pointer to WIN_POS+ window data
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx

        ; if type of current active window is 3 or 4, it must be redrawn
        mov     ebx, [TASK_COUNT]
        movzx   ebx, [WIN_POS + ebx * 2]
        shl     ebx, 5
        add     eax, window_data
        mov     al, [window_data + ebx + window_data_t.fl_wstyle]
        and     al, 0x0f
        cmp     al, 0x03
        je      .set_window_redraw_flag
        cmp     al, 0x04
        jne     .move_others_down

  .set_window_redraw_flag:
        mov     [window_data + ebx + window_data_t.fl_redraw], 1

  .move_others_down:
        ; ax <- process no
        movzx   ebx, word[esi]
        ; ax <- position in window stack
        movzx   ebx, [WIN_STACK + ebx * 2]

        ; drop others
        xor     eax, eax

  .next_stack_window:
        cmp     eax, [TASK_COUNT]
        jae     .move_self_up
        inc     eax
        cmp     [WIN_STACK + eax * 2], bx
        jbe     .next_stack_window
        dec     [WIN_STACK + eax * 2]
        jmp     .next_stack_window

  .move_self_up:
        movzx   ebx, word[esi]
        ; number of processes
        mov     eax, [TASK_COUNT]
        ; this is the last (and the upper)
        mov     [WIN_STACK + ebx * 2], ax

        ; update on screen - window stack
        xor     eax, eax

  .next_window_pos:
        cmp     eax, [TASK_COUNT]
        jae     .reset_vars
        inc     eax
        movzx   ebx, [WIN_STACK + eax * 2]
        mov     [WIN_POS + ebx * 2], ax
        jmp     .next_window_pos

  .reset_vars:
        mov     [KEY_COUNT], 0
        mov     [BTN_COUNT], 0
        mov     [MOUSE_SCROLL_H], 0
        mov     [MOUSE_SCROLL_V], 0

        pop     ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.check_window_draw ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Check if window is necessary to draw
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to window_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     cl, [edi + window_data_t.fl_wstyle]
        and     cl, 0x0f
        cmp     cl, 3
        je      .exit.redraw ; window type 3
        cmp     cl, 4
        je      .exit.redraw ; window type 4

        push    eax ebx edx esi

        mov     eax, edi
        sub     eax, window_data
        shr     eax, 5

        movzx   eax, [WIN_STACK + eax * 2] ; get value of the curr process
        lea     esi, [WIN_POS + eax * 2] ; get address of this process at 0xC400

  .next_window:
        add     esi, 2

        mov     eax, [TASK_COUNT]
        lea     eax, [WIN_POS + eax * 2] ; number of the upper window

        cmp     esi, eax
        ja      .exit.no_redraw

        movzx   edx, word[esi]
        shl     edx, 5
        cmp     [TASK_DATA + edx - sizeof.task_data_t + task_data_t.state], TSTATE_FREE
        je      .next_window

        mov     eax, [edi + window_data_t.box.top]
        mov     ebx, [edi + window_data_t.box.height]
        add     ebx, eax

        mov     ecx, [window_data + edx + window_data_t.box.top]
        cmp     ecx, ebx
        jge     .next_window
        add     ecx, [window_data + edx + window_data_t.box.height]
        cmp     eax, ecx
        jge     .next_window

        mov     eax, [edi + window_data_t.box.left]
        mov     ebx, [edi + window_data_t.box.width]
        add     ebx, eax

        mov     ecx, [window_data + edx + window_data_t.box.left]
        cmp     ecx, ebx
        jge     .next_window
        add     ecx, [window_data + edx + window_data_t.box.width]
        cmp     eax, ecx
        jge     .next_window

        pop     esi edx ebx eax

  .exit.redraw:
        xor     ecx, ecx
        inc     ecx
        ret

  .exit.no_redraw:
        pop     esi edx ebx eax
        xor     ecx, ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.draw_window_caption ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        inc     [mouse_pause]
        call    [_display.disable_mouse]

        xor     eax, eax
        mov     edx, [TASK_COUNT]
        movzx   edx, [WIN_POS + edx * 2]
        cmp     edx, [CURRENT_TASK]
        jne     @f
        inc     eax

    @@: mov     edx, [CURRENT_TASK]
        shl     edx, 5
        add     edx, window_data
        movzx   ebx, [edx + window_data_t.fl_wstyle]
        and     bl, 0x0f
        cmp     bl, 3
        je      .draw_caption_style_3
        cmp     bl, 4
        je      .draw_caption_style_3

        jmp     .not_style_3

  .draw_caption_style_3:
        push    edx
        call    drawwindow_IV_caption
        add     esp, 4
        jmp     .2

  .not_style_3:
        cmp     bl, 2
        jne     .not_style_2

        call    drawwindow_III_caption
        jmp     .2

  .not_style_2:
        cmp     bl, 0
        jne     .2

        call    drawwindow_I_caption

  .2:
        mov     edi, [CURRENT_TASK]
        shl     edi, 5
        test    [window_data + edi + window_data_t.fl_wstyle], WSTYLE_HASCAPTION
        jz      .exit
        mov     edx, [SLOT_BASE + edi * 8 + app_data_t.wnd_caption]
        or      edx, edx
        jz      .exit

        movzx   eax, [window_data + edi + window_data_t.fl_wstyle]
        and     al, 0x0f
        cmp     al, 3
        je      .skinned
        cmp     al, 4
        je      .skinned

        jmp     .not_skinned

  .skinned:
        mov     ebp, [window_data + edi + window_data_t.box.left - 2]
        mov     bp, word[window_data + edi + window_data_t.box.top]
        movzx   eax, word[window_data + edi + window_data_t.box.width]
        sub     ax, [_skinmargins.left]
        sub     ax, [_skinmargins.right]
        push    edx
        cwde
        cdq
        mov     ebx, 6
        idiv    ebx
        pop     edx
        or      eax, eax
        js      .exit

        mov     esi, eax
        mov     ebx, dword[_skinmargins.left - 2]
        mov     bx, word[_skinh]
        sub     bx, [_skinmargins.bottom]
        sub     bx, [_skinmargins.top]
        sar     bx, 1
        adc     bx, 0
        add     bx, [_skinmargins.top]
        add     bx, -3
        add     ebx, ebp
        jmp     .dodraw

  .not_skinned:
        cmp     al, 1
        je      .exit

        mov     ebp, [window_data + edi + window_data_t.box.left - 2]
        mov     bp, word[window_data + edi + window_data_t.box.top]
        movzx   eax, word[window_data + edi + window_data_t.box.width]
        sub     eax, 16
        push    edx
        cwde
        cdq
        mov     ebx, 6
        idiv    ebx
        pop     edx
        or      eax, eax
        js      .exit

        mov     esi, eax
        mov     ebx, 0x00080007
        add     ebx, ebp

  .dodraw:
        mov     ecx, [common_colours + 16]
        or      ecx, 0x80000000
        xor     edi, edi
        call    dtext_asciiz_esi

  .exit:
        dec     [mouse_pause]
        call    [draw_pointer]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc window._.draw_negative_box ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Draw negative box
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to box32_t struct
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx esi
        mov     eax, [edi + box32_t.left - 2]
        mov     ax, word[edi + box32_t.left]
        add     ax, word[edi + box32_t.width]
        mov     ebx, [edi + box32_t.top - 2]
        mov     bx, word[edi + box32_t.top]
        add     bx, word[edi + box32_t.height]
        mov     esi, 0x01000000
        call    draw_rectangle.forced
        pop     esi ebx eax
        ret
kendp
