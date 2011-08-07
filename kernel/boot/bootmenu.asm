;;======================================================================================================================
;;///// bootmenu.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

boot.MENU_RESULT_SELECT   = 0
boot.MENU_RESULT_CANCEL   = 1
boot.MENU_RESULT_SAVEBOOT = 2
boot.MENU_RESULT_BOOT     = 3

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.print_simple_menu_item ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si ^= pointer to item title
;> cx #= item index
;> dx #= value index
;-----------------------------------------------------------------------------------------------------------------------
        lodsw
        or      ax, ax
        jz      .exit

        xchg    ax, si
        call    boot.print_string

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.print_main_menu_item ;///////////////////////////////////////////////////////////////////////////////////////
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

        mov     cx, dx
        call    boot.print_vmode_menu_item
        jmp     .exit

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
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.print_list ;/////////////////////////////////////////////////////////////////////////////////////////////////
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
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.set_int_handler ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= new handler
;> cl #= interrupt number
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= old handler
;-----------------------------------------------------------------------------------------------------------------------
        cli
        push    es bx
        mov_s_  es, 0
        movzx   bx, cl
        shl     bx, 2
        push    dword[es:bx]
        mov     [es:bx], eax
        pop     eax
        pop     bx es
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.print_timer_char ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> al #= char to display
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        mov_s_  es, 0xb800
        mov     [es:80 * 25 * 2 - 4], al
        pop     es
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.int8_handler ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ds
        mov_s_  ds, cs
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
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.run_menu ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:bx ^= boot_menu_data_t
;> al ~= use timeout
;-----------------------------------------------------------------------------------------------------------------------
;< ax #= status code (one of boot.MENU_RESULT_*)
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
        mov_s_  si, [bx + boot_menu_data_t.items]
        mov_s_  bx, [bx + boot_menu_data_t.print_callback]
        xor     cx, cx
        mov     dx, bp
        lodsw
        call    boot.print_list
        pop     bx ds

  .wait_for_key:
        xor     ax, ax
        int     0x16

if KCONFIG_DEBUG

        pusha
        shr     ax, 4
        shr     al, 4
        cmp     al, 10
        jb      @f
        add     al, 'a' - '9' - 1
    @@: cmp     ah, 10
        jb      @f
        add     ah, 'a' - '9' - 1
    @@: add     ax, '00'
        push    es
        mov_s_  es, 0xb800
        mov     [es:0], ah
        mov     [es:2], al
        pop     es
        popa

end if

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

        mov     ax, boot.MENU_RESULT_CANCEL
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

    @@: xor     ax, ax ; boot.MENU_RESULT_SELECT
        mov     cx, bp
        jmp     .exit

  .f10_key:
        cmp     ch, 0x44 ; f10
        jne     .up_key

        mov     ax, boot.MENU_RESULT_SAVEBOOT
        jmp     .exit

  .up_key:
        cmp     ch, 0x48 ; up
        jne     .down_key

    @@: mov     si, [bx + boot_menu_data_t.items]
        lodsw
        dec     ax
        or      bp, bp
        xchg    ax, bp
        jz      .print_menu

        xchg    ax, bp
        dec     bp

        add     si, bp
        add     si, bp
        lodsw
        or      ax, ax
        jz      @b

        jmp     .print_menu

  .down_key:
        cmp     ch, 0x50 ; down
        jne     .f11_key

    @@: mov     si, [bx + boot_menu_data_t.items]
        lodsw
        dec     ax
        sub     ax, bp
        xchg    ax, bp
        jz      .print_menu

        xchg    ax, bp
        inc     bp

        add     si, bp
        add     si, bp
        lodsw
        or      ax, ax
        jz      @b

        jmp     .print_menu

  .f11_key:
        cmp     ch, 0x85 ; f11
        jne     .wait_for_key

        mov     ax, boot.MENU_RESULT_BOOT
        jmp     .exit

  .run_submenu:
        push    bx bp si
        mov     bx, si
        xor     al, al
        call    boot.run_menu
        pop     si bp bx

        cmp     al, boot.MENU_RESULT_CANCEL
        je      .clear_screen

        cmp     al, boot.MENU_RESULT_SAVEBOOT
        je      .exit
        cmp     al, boot.MENU_RESULT_BOOT
        je      .exit

        mov     [si + boot_menu_data_t.current_index], cx
        jmp     .clear_screen

  .exit:
        mov     cx, bp
        pop     bp bp
        ret
kendp
