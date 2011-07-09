;;======================================================================================================================
;;///// boot_menu.asm ////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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
boot.print_simple_menu_item: ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si ^= pointer to item title
;> cx #= item index
;> dx #= value index
;-----------------------------------------------------------------------------------------------------------------------
        lodsw
        xchg    ax, si
        call    boot.print_string
        xor     al, al
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.print_main_menu_item: ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si ^= pointer to item title
;> cx #= item index
;> dx #= value index
;-----------------------------------------------------------------------------------------------------------------------
        call    boot.print_simple_menu_item

        cmp     cx, 4
        jae     .exit

        mov     al, ':'
        call    boot.print_char
        mov     al, ' '
        call    boot.print_char

        or      cx, cx
        jnz     @f

        jmp     draw_current_vmode

    @@: dec     cx
        jz      .print_on_off_value

        dec     cx
        jz      .print_on_off_value

        mov     si, dx
        shl     si, 1
        mov     si, [boot.data.boot_source_menu_options + si + 2]
        jmp     boot.print_string

  .print_on_off_value:
        mov     si, dx
        shl     si, 1
        mov     si, [boot.data.bool_menu_options + si + 2]
        jmp     boot.print_string

  .exit:
        xor     al, al
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.print_list: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Print list of values using provided callback function
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si ^= list, null-terminated
;> cs:bx ^= list item print callack, or 0 (to use boot.print_string)
;> ax #= items count
;> cx #= start item index
;> dx #= current item index
;-----------------------------------------------------------------------------------------------------------------------
        push    bp
        mov     bp, ax

        or      bx, bx
        jnz     .next_item

        mov     bx, boot.print_string

  .next_item:
        push    dx si

        ; print current item indicator
        mov     si, boot.data.s_inactive_item_prefix
        cmp     cx, dx
        jne     @f
        mov     si, boot.data.s_active_item_prefix

    @@: call    boot.print_string

        mov     si, cx
        shl     si, 1
        mov     si, [boot.data.main_menu_submenus + si]
        mov     dx, [si + boot_menu_data_t.current_index]

        pop     si
        push    si cx

        add     si, cx
        add     si, cx

        call    bx
        call    boot.print_crlf

        pop     cx si dx
        inc     cx
        dec     bp
        jnz     .next_item

  .exit:
        pop     bp
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.set_int_handler: ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= new handler
;> cl #= interrupt number
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= old handler
;-----------------------------------------------------------------------------------------------------------------------
        cli
        push    es bx
        push    0
        pop     es
        movzx   bx, cl
        shl     bx, 2
        push    dword[es:bx]
        mov     [es:bx], eax
        pop     eax
        pop     bx es
        sti
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.print_timer_char: ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> al #= char to display
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        push    0xb800
        pop     es
        mov     [es:80 * 25 * 2 - 4], al
        pop     es
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.int8_handler: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ds
        push    cs
        pop     ds
        pushf
        call    [boot.data.old_int8_handler]

        pushad

        call    boot.get_time
        sub     eax, [boot.data.timer_start_time]
        sub     ax, 18 * 5

        pushf

        neg     ax
        add     ax, 18 - 1
        mov     bx, 18
        xor     dx, dx
        div     bx
        add     al, '0'
        call    boot.print_timer_char

        popf
        js      .exit

        ; timed out, store f10 in key buffer
        mov     ah, 5
        mov     cx, 0x4400
        int     0x16

  .exit:
        popad
        pop     ds
        iret

;-----------------------------------------------------------------------------------------------------------------------
boot.run_menu: ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:bx ^= boot_menu_data_t
;> al ~= use timeout
;-----------------------------------------------------------------------------------------------------------------------
;< ax #= status code:
;        0 - select
;        1 - cancel
;        2 - continue boot
;< cx #= selected item index
;-----------------------------------------------------------------------------------------------------------------------
        or      al, al
        jz      .get_current_index

        push    ax

        ; save timer start time
        call    boot.get_time
        mov     [boot.data.timer_start_time], eax

        ; set timer interrupt handler
        mov     ax, cs
        shl     eax, 16
        mov     ax, boot.int8_handler
        mov     cl, 8
        call    boot.set_int_handler
        mov     [boot.data.old_int8_handler], eax

        pop     ax

  .get_current_index:
        push    bp
        push    ax
        mov     bp, [bx + boot_menu_data_t.current_index]

  .clear_screen:
        mov     di, 80 * (boot.data.s_logo.height + 2 + 2)
        mov     cx, 80 * (25 - boot.data.s_logo.height - 2 - 2 - 1)
        call    boot.clear_screen

  .print_menu:
        mov     dx, 1 * 256 + boot.data.s_logo.height + 2 + 2
        call    setcursor

        mov     si, [bx + boot_menu_data_t.title]
        call    boot.print_string
        mov     al, ':'
        call    boot.print_char
        call    boot.print_crlf
        call    boot.print_crlf

        push    ds bx
        push    [bx + boot_menu_data_t.items] \
                [bx + boot_menu_data_t.print_callback]
        pop     bx si
        xor     cx, cx
        mov     dx, bp
        lodsw
        call    boot.print_list
        pop     bx ds

  .wait_for_key:
        xor     ax, ax
        int     0x16

        pop     cx
        xchg    ax, cx
        or      al, al
        jz      @f

        ; restore timer interrupt
        mov     eax, [boot.data.old_int8_handler]
        mov     cl, 8
        call    boot.set_int_handler

        ; erase timer digit
        mov     al, ' '
        call    boot.print_timer_char

        ; don't go this road further
        xor     ax, ax

    @@: push    ax

        cmp     ch, 0x01 ; esc
        jne     .enter_key

        mov     ax, 1
        jmp     .exit

  .enter_key:
        cmp     ch, 0x1c ; enter
        jne     .f10_key

        mov     si, [bx + boot_menu_data_t.submenus]
        or      si, si
        jz      @f

        add     si, bp
        add     si, bp
        mov     si, [si]
        or      si, si
        jnz     .run_submenu

    @@: xor     ax, ax
        mov     cx, bp
        jmp     .exit

  .f10_key:
        cmp     ch, 0x44 ; f10
        jne     .up_key

        mov     ax, 2
        jmp     .exit

  .up_key:
        cmp     ch, 0x48 ; up
        jne     .down_key

        or      bp, bp
        jz      .wait_for_key

        dec     bp
        jmp     .print_menu

  .down_key:
        cmp     ch, 0x50 ; down
        jne     .wait_for_key

        mov     si, [bx + boot_menu_data_t.items]
        lodsw
        dec     ax
        cmp     bp, ax
        je      .wait_for_key

        inc     bp
        jmp     .print_menu

  .run_submenu:
        push    bx bp si
        mov     bx, si
        xor     al, al
        call    boot.run_menu
        pop     si bp bx

        cmp     al, 1
        je      .print_menu

        cmp     al, 2
        je      .exit

        mov     [si + boot_menu_data_t.current_index], cx
        jmp     .clear_screen

  .exit:
        pop     bp bp
        ret
