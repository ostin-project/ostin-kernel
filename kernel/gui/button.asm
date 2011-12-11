;;======================================================================================================================
;;///// button.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

GUI_BUTTON_MAX_COUNT = 4095
GUI_BUTTON_ID_MASK   = 0x00ffffff

struct sys_button_t
  pslot     dd ?
  union
    id      dd ?
    struct
            rb 3
      flags db ?
    ends
  ends
  box       box16_t
ends

static_assert sizeof.sys_button_t = 16

uglobal
  BTN_ADDR dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.define_button ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 8: define/undefine GUI button object
;-----------------------------------------------------------------------------------------------------------------------
;; Define button:
;> ebx = pack[16(x), 16(width)]
;> ecx = pack[16(y), 16(height)]
;> edx = pack[8(flags), 24(button identifier)]
;>       flags bits:
;>          7 (31) = 0
;>          6 (30) = don't draw button
;>          5 (29) = don't draw button frame when pressed
;> esi = button color
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;; Undefine button:
;> edx = pack[8(flags), 24(button identifier)]
;>       flags bits:
;>          7 (31) = 1
;-----------------------------------------------------------------------------------------------------------------------
        ; do we actually need to undefine the button?
        test    edx, 0x80000000
        jnz     .remove_button

        ; do we have free button slots available?
        mov     edi, [BTN_ADDR]
        mov     eax, [edi]
        cmp     eax, GUI_BUTTON_MAX_COUNT
        jge     .exit

        ; does it have positive size? (otherwise it doesn't have sense)
        or      bx, bx
        jle     .exit
        or      cx, cx
        jle     .exit

        ; make coordinates clientbox-relative
        push    eax
        mov     eax, [current_slot]
        rol     ebx, 16
        add     bx, word[eax + app_data_t.wnd_clientbox.left]
        rol     ebx, 16
        rol     ecx, 16
        add     cx, word[eax + app_data_t.wnd_clientbox.top]
        rol     ecx, 16
        pop     eax

        ; basic checks passed, define the button
        push    ebx ecx edx
        inc     eax
        mov     [edi], ax
        shl     eax, 4
        add     edi, eax
        ; NOTE: this code doesn't rely on sys_button_t struct, please revise it if you change something
        mov     eax, [CURRENT_TASK]
        stosd
        mov     eax, edx
        stosd   ; button id number and flags
        mov     eax, ecx
        rol     ebx, 16
        mov     ax, bx
        stosd   ; box left | box top
        mov     eax, ecx
        shl     eax, 16
        rol     ebx, 16
        mov     ax, bx
        stosd   ; box width | box height
        pop     edx ecx ebx

        ; do we also need to draw the button?
        test    edx, 0x40000000
        jnz     .exit

        ; draw button body

        pushad

        ; calculate window-relative coordinates
        movzx   edi, cx
        shr     ebx, 16
        shr     ecx, 16
        mov     eax, [TASK_BASE]
        add     ebx, [eax - twdw + window_data_t.box.left]
        add     ecx, [eax - twdw + window_data_t.box.top]
        mov     eax, ebx
        shl     eax, 16
        mov     ax, bx
        add     ax, [esp + regs_context32_t.bx]
        mov     ebx, ecx
        shl     ebx, 16
        mov     bx, cx

        ; calculate initial color
        mov     ecx, esi
        cmp     [buttontype], 0
        je      @f
        call    button._.incecx2

    @@: ; set button height counter
        mov     edx, edi

  .next_line:
        call    button._.button_dececx
        push    edi
        xor     edi, edi
        call    [draw_line]
        pop     edi
        add     ebx, 0x00010001
        dec     edx
        jnz     .next_line

        popad

        ; draw button frame

        push    ebx ecx

        ; calculate window-relative coordinates
        shr     ebx, 16
        shr     ecx, 16
        mov     eax, [TASK_BASE]
        add     ebx, [eax - twdw + window_data_t.box.left]
        add     ecx, [eax - twdw + window_data_t.box.top]

        ; top border
        mov     eax, ebx
        shl     eax, 16
        mov     ax, bx
        add     ax, [esp + 4]
        mov     ebx, ecx
        shl     ebx, 16
        mov     bx, cx
        push    ebx
        xor     edi, edi
        mov     ecx, esi
        call    button._.incecx
        call    [draw_line]

        ; bottom border
        movzx   edx, word[esp + 4 + 0]
        add     ebx, edx
        shl     edx, 16
        add     ebx, edx
        mov     ecx, esi
        call    button._.dececx
        call    [draw_line]

        ; left border
        pop     ebx
        push    edx
        mov     edx, eax
        shr     edx, 16
        mov     ax, dx
        mov     edx, ebx
        shr     edx, 16
        mov     bx, dx
        add     bx, [esp + 4 + 0]
        pop     edx
        mov     ecx, esi
        call    button._.incecx
        call    [draw_line]

        ; right border
        mov     dx, [esp + 4]
        add     ax, dx
        shl     edx, 16
        add     eax, edx
        add     ebx, 0x00010000
        mov     ecx, esi
        call    button._.dececx
        call    [draw_line]

        pop     ecx ebx

  .exit:
        ret

; FIXME: mutex needed
sysfn.define_button.remove_button:
        and     edx, GUI_BUTTON_ID_MASK
        mov     edi, [BTN_ADDR]
        mov     ebx, [edi]
        inc     ebx
        imul    esi, ebx, sizeof.sys_button_t
        add     esi, edi
        xor     ecx, ecx
        add     ecx, -sizeof.sys_button_t
        add     esi, sizeof.sys_button_t

  .next_button:
        dec     ebx
        jz      .exit

        add     ecx, sizeof.sys_button_t
        add     esi, -sizeof.sys_button_t

        ; does it belong to our process?
        mov     eax, [CURRENT_TASK]
        cmp     eax, [esi + sys_button_t.pslot]
        jne     .next_button

        ; does the identifier match?
        mov     eax, [esi + sys_button_t.id]
        and     eax, GUI_BUTTON_ID_MASK
        cmp     edx, eax
        jne     .next_button

        ; okay, undefine it
        push    ebx
        mov     ebx, esi
        lea     eax, [esi + sizeof.sys_button_t]
        call    memmove
        dec     dword[edi]
        add     ecx, -sizeof.sys_button_t
        pop     ebx
        jmp     .next_button

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_clicked_button_id ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 17: get clicked button identifier
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [CURRENT_TASK] ; TOP OF WINDOW STACK
        mov     [esp + 4 + regs_context32_t.eax], 1
        movzx   ecx, [WIN_STACK + ebx * 2]
        mov     edx, [TASK_COUNT] ; less than 256 processes
        cmp     ecx, edx
        jne     .exit
        movzx   eax, [BTN_COUNT]
        test    eax, eax
        jz      .exit
        mov     eax, [BTN_BUFF]
        and     al, 0xfe ; delete left button bit
        mov     [BTN_COUNT], 0
        mov     [esp + 4 + regs_context32_t.eax], eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_button_activate_handler ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pack[8(process slot), 24(button id)]
;> ebx = pack[16(button x coord), 16(button y coord)]
;> cl = mouse button mask this system button was pressed with
;-----------------------------------------------------------------------------------------------------------------------
        call    button._.find_button
        or      eax, eax
        jz      .exit

        mov     bl, [eax + sys_button_t.flags]
        call    button._.negative_button

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_button_deactivate_handler ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pack[8(process slot), 24(button id)]
;> ebx = pack[16(button x coord), 16(button y coord)]
;> cl = mouse button mask this system button was pressed with
;-----------------------------------------------------------------------------------------------------------------------
        call    button._.find_button
        or      eax, eax
        jz      .exit

        mov     bl, [eax + sys_button_t.flags]
        call    button._.negative_button

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_button_perform_handler ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pack[8(process slot), 24(button id)]
;> ebx = pack[16(button x coord), 16(button y coord)]
;> cl = mouse button mask this system button was pressed with
;-----------------------------------------------------------------------------------------------------------------------
        shl     eax, 8
        mov     al, cl

        ; FIXME: the rest of code assumes there could be at most 1 button in the buffer...
;       movzx   ebx, [BTN_COUNT]
;       mov     [BTN_BUFF + ebx * 4], eax
;       inc     bl
;       mov     [BTN_COUNT], bl
        ; FIXME: ... so we simplify it for now
        mov     [BTN_BUFF], eax
        mov     [BTN_COUNT], 1

        ret
kendp

;;======================================================================================================================
;;///// private functions //////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

;-----------------------------------------------------------------------------------------------------------------------
kproc button._.find_button ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Find system button by specified process slot, id and coordinates
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pack[8(process slot), 24(button id)] or 0
;> ebx = pack[16(button x coord), 16(button y coord)]
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pointer to sys_button_t struct or 0
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx esi edi

        mov     edx, eax
        shr     edx, 24
        and     eax, GUI_BUTTON_ID_MASK

        mov     edi, [BTN_ADDR]
        mov     ecx, [edi]
        imul    esi, ecx, sizeof.sys_button_t
        add     esi, edi
        inc     ecx
        add     esi, sizeof.sys_button_t

  .next_button:
        dec     ecx
        jz      .not_found

        add     esi, -sizeof.sys_button_t

        ; does it belong to our process?
        cmp     edx, [esi + sys_button_t.pslot]
        jne     .next_button

        ; does id match?
        mov     edi, [esi + sys_button_t.id]
        and     edi, GUI_BUTTON_ID_MASK
        cmp     eax, edi
        jne     .next_button

        ; do coordinates match?
        mov     edi, dword[esi + sys_button_t.box.left - 2]
        mov     di, [esi + sys_button_t.box.top]
        cmp     ebx, edi
        jne     .next_button

        ; okay, return it
        mov     eax, esi
        jmp     .exit

  .not_found:
        xor     eax, eax

  .exit:
        pop     edi esi edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc button._.dececx ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        sub     cl, 0x20
        jnc     @f
        xor     cl, cl

    @@: sub     ch, 0x20
        jnc     @f
        xor     ch, ch

    @@: rol     ecx, 16
        sub     cl, 0x20
        jnc     @f
        xor     cl, cl

    @@: rol     ecx, 16
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc button._.incecx ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        add     cl, 0x20
        jnc     @f
        or      cl, -1

    @@: add     ch, 0x20
        jnc     @f
        or      ch, -1

    @@: rol     ecx, 16
        add     cl, 0x20
        jnc     @f
        or      cl, -1

    @@: rol     ecx, 16
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc button._.incecx2 ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        add     cl, 0x14
        jnc     @f
        or      cl, -1

    @@: add     ch, 0x14
        jnc     @f
        or      ch, -1

    @@: rol     ecx, 16
        add     cl, 0x14
        jnc     @f
        or      cl, -1

    @@: rol     ecx, 16
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc button._.button_dececx ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? <description>
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [buttontype], 1
        jne     .finish

        push    eax
        mov     al, 1
        cmp     edi, 20
        jg      @f
        mov     al, 2

    @@: sub     cl, al
        jnc     @f
        xor     cl, cl

    @@: sub     ch, al
        jnc     @f
        xor     ch, ch

    @@: rol     ecx, 16
        sub     cl, al
        jnc     @f
        xor     cl, cl

    @@: rol     ecx, 16

        pop     eax

  .finish:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc button._.negative_button ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Invert system button border
;-----------------------------------------------------------------------------------------------------------------------
        ; if requested, do not display button border on press.
        test    bl, 0x20
        jnz     .exit

        pushad

        xchg    esi, eax

        mov     ecx, [esi + sys_button_t.pslot]
        shl     ecx, 5
        add     ecx, window_data

        mov     eax, dword[esi + sys_button_t.box.width - 2]
        mov     ax, [esi + sys_button_t.box.left]
        mov     ebx, dword[esi + sys_button_t.box.height - 2]
        mov     bx, [esi + sys_button_t.box.top]
        add     ax, word[ecx + window_data_t.box.left]
        add     bx, word[ecx + window_data_t.box.top]
        push    eax ebx
        pop     edx ecx
        rol     eax, 16
        rol     ebx, 16
        add     ax, cx
        add     bx, dx

        mov     esi, 0x01000000
        call    draw_rectangle.forced

        popad

  .exit:
        ret
kendp
