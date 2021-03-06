;;======================================================================================================================
;;///// keyboard.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2012 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
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

VKEY_LSHIFT   = 0000000000000001b
VKEY_RSHIFT   = 0000000000000010b
VKEY_LCONTROL = 0000000000000100b
VKEY_RCONTROL = 0000000000001000b
VKEY_LALT     = 0000000000010000b
VKEY_RALT     = 0000000000100000b
VKEY_CAPSLOCK = 0000000001000000b
VKEY_NUMLOCK  = 0000000010000000b
VKEY_SCRLOCK  = 0000000100000000b

VKEY_SHIFT    = 0000000000000011b
VKEY_CONTROL  = 0000000000001100b
VKEY_ALT      = 0000000000110000b

HOTKEY_MAX_COUNT   = 256

struct hotkey_t
  next_ptr dd ?
  mod_keys dd ?
  pslot    dd ?
  prev_ptr dd ?
ends

assert sizeof.hotkey_t = 16
assert hotkey_t.next_ptr = 0

uglobal
  kb_state         dd 0
  ext_code         db 0

  keyboard_mode    db 0
  keyboard_data    db 0

  altmouseb        db 0
  ctrl_alt_del     db 0

  kb_lights        db 0

  align 4
  hotkey_scancodes rd 256     ; we have 256 scancodes
  hotkey_list:     rb HOTKEY_MAX_COUNT * sizeof.hotkey_t ; max HOTKEY_MAX_COUNT defined hotkeys
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.keyboard_ctl, subfn, sysfn.not_implemented, \
    set_input_mode, \ ; 1
    get_input_mode, \ ; 2
    get_modifiers_state, \ ; 3
    register_hotkey, \ ; 4
    unregister_hotkey ; 5
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        mov     edi, [current_slot]
        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.set_input_mode ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.1: set keyboard mode
;-----------------------------------------------------------------------------------------------------------------------
        shl     edi, 9 ; * sizeof.legacy.slot_t
        mov     [legacy_slots + edi + legacy.slot_t.app.keyboard_mode], cl
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.get_input_mode ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.2: get keyboard mode
;-----------------------------------------------------------------------------------------------------------------------
        shl     edi, 9 ; * sizeof.legacy.slot_t
        movzx   eax, [legacy_slots + edi + legacy.slot_t.app.keyboard_mode]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.get_modifiers_state ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.3: get keyboard ctrl, alt, shift
;-----------------------------------------------------------------------------------------------------------------------
;       xor     eax, eax
;       movzx   eax, byte[shift]
;       movzx   ebx, byte[ctrl]
;       shl     ebx, 2
;       add     eax, ebx
;       movzx   ebx, byte[alt]
;       shl     ebx, 3
;       add     eax, ebx
        mov     eax, [kb_state]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.register_hotkey ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.4
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, hotkey_list

    @@: cmp     [eax + hotkey_t.pslot], 0
        jz      .found_free
        add     eax, sizeof.hotkey_t
        cmp     eax, hotkey_list + HOTKEY_MAX_COUNT * sizeof.hotkey_t
        jb      @b
        mov     [esp + 4 + regs_context32_t.eax], 1
        ret

  .found_free:
        mov     [eax + hotkey_t.pslot], edi
        mov     [eax + hotkey_t.mod_keys], edx
        movzx   ecx, cl
        lea     ecx, [hotkey_scancodes + ecx * 4]
        mov     edx, [ecx]
        mov     [eax + hotkey_t.next_ptr], edx
        mov     [ecx], eax
        mov     [eax + hotkey_t.prev_ptr], ecx

        test    edx, edx
        jz      @f

        mov     [edx + hotkey_t.prev_ptr], eax

    @@: and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.unregister_hotkey ;////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.5
;-----------------------------------------------------------------------------------------------------------------------
        movzx   ebx, cl
        lea     ebx, [hotkey_scancodes + ebx * 4]
        mov     eax, [ebx]

  .scan:
        test    eax, eax
        jz      .notfound
        cmp     [eax + hotkey_t.pslot], edi
        jnz     .next
        cmp     [eax + hotkey_t.mod_keys], edx
        jz      .found

  .next:
        mov     eax, [eax + hotkey_t.next_ptr]
        jmp     .scan

  .notfound:
        mov     [esp + 4 + regs_context32_t.eax], 1
        ret

  .found:
        mov     ecx, [eax + hotkey_t.next_ptr]
        jecxz   @f

        mov     edx, [eax + hotkey_t.prev_ptr]
        mov     [ecx + hotkey_t.prev_ptr], edx

    @@: mov     ecx, [eax + hotkey_t.prev_ptr]
        mov     edx, [eax + hotkey_t.next_ptr]
        mov     [ecx + hotkey_t.next_ptr], edx

        xor     edx, edx
        mov     [eax + hotkey_t.mod_keys], edx
        mov     [eax + hotkey_t.pslot], edx
        mov     [eax + hotkey_t.prev_ptr], edx
        mov     [eax + hotkey_t.next_ptr], edx

        mov     [esp + 4 + regs_context32_t.eax], edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_key ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 2
;-----------------------------------------------------------------------------------------------------------------------
        mov     [esp + 4 + regs_context32_t.eax], 1
        ; test main buffer
        mov     ebx, [current_slot] ; TOP OF WINDOW STACK
        movzx   ecx, [pslot_to_wnd_pos + ebx * 2]
        mov     edx, [legacy_slots.last_valid_slot]
        cmp     ecx, edx
        jne     .finish
        cmp     [key_buffer.count], 0
        je      .finish
        movzx   eax, [key_buffer]
        shl     eax, 8
        push    eax
        dec     [key_buffer.count]
        and     [key_buffer.count], 127
        movzx   ecx, [key_buffer.count]
        add     ecx, 2
        mov     eax, key_buffer + 1
        mov     ebx, key_buffer
        call    memmove
        pop     eax

  .ret_eax:
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .finish:
        ; test hotkeys buffer
        mov     ecx, hotkey_buffer

    @@: cmp     [ecx + queued_hotkey_t.pslot], ebx
        jz      .found
        add     ecx, sizeof.queued_hotkey_t
        cmp     ecx, hotkey_buffer + HOTKEY_BUFFER_SIZE * sizeof.queued_hotkey_t
        jb      @b
        ret

  .found:
        mov     ax, [ecx + queued_hotkey_t.mod_keys]
        shl     eax, 16
        mov     ah, [ecx + queued_hotkey_t.scancode]
        mov     al, 2
        and     dword[ecx + queued_hotkey_t.mod_keys], 0
        and     [ecx + queued_hotkey_t.pslot], 0
        jmp     .ret_eax
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hotkey_do_test ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable hotkey_do_test, subfn, , \
    test0, \
    test1, \
    test2, \
    test3, \
    test4
endg
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     edx, [kb_state]
        shr     edx, cl
        add     cl, cl
        mov     eax, [eax + 4]
        shr     eax, cl
        and     eax, 15
        cmp     al, .countof.subfn
        jae     .fail
        xchg    eax, edx
        and     al, 3
        call    [.subfn + edx * 4]
        cmp     al, 1
        pop     eax
        ret

  .test0:
        test    al, al
        setz    al
        ret

  .test1:
        test    al, al
        setnp   al
        ret

  .test2:
        cmp     al, 3
        setz    al
        ret

  .test3:
        cmp     al, 1
        setz    al
        ret

  .test4:
        cmp     al, 2
        setz    al
        ret

  .fail:
        stc
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc set_keyboard_data ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [legacy_slots.last_valid_slot] ; top window process
        movzx   eax, [wnd_pos_to_pslot + eax * 2]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     al, [legacy_slots + eax + legacy.slot_t.app.keyboard_mode]
        mov     [keyboard_mode], al

        mov     eax, ecx

        push    ebx
        push    esi
        push    edi
        push    ebp

        call    send_scancode

        pop     ebp
        pop     edi
        pop     esi
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc irq1 ;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [legacy_slots.last_valid_slot] ; top window process
        movzx   eax, [wnd_pos_to_pslot + eax * 2]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     al, [legacy_slots + eax + legacy.slot_t.app.keyboard_mode]
        mov     [keyboard_mode], al

        in      al, 0x60
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc send_scancode ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ch = scancode
;> cl = ext_code
;> bh = 0 - normal key
;> bh = 1 - modifier (Shift/Ctrl/Alt)
;> bh = 2 - extended code
;-----------------------------------------------------------------------------------------------------------------------

        mov      [keyboard_data], al

        mov     ch, al
        cmp     al, 0xe0
        je      @f
        cmp     al, 0xe1
        jne     .normal_code

    @@: mov     bh, 2
        mov     [ext_code], al
        jmp     .writekey

  .normal_code:
        mov     cl, 0
        xchg    cl, [ext_code]
        and     al, 0x7f
        mov     bh, 1

    @@: cmp     al, 0x2a
        jne     @f
        cmp     cl, 0xe0
        je      .writekey
        mov     eax, VKEY_LSHIFT
        jmp     .modifier

    @@: cmp     al, 0x36
        jne     @f
        cmp     cl, 0xe0
        je      .writekey
        mov     eax, VKEY_RSHIFT
        jmp     .modifier

    @@: cmp     al, 0x38
        jne     @f
        mov     eax, VKEY_LALT
        test    cl, cl
        jz      .modifier
        mov     al, VKEY_RALT
        jmp     .modifier

    @@: cmp     al, 0x1d
        jne     @f
        mov     eax, VKEY_LCONTROL
        test    cl, cl
        jz      .modifier
        mov     al, VKEY_RCONTROL
        cmp     cl, 0xe0
        jz      .modifier
        mov     [ext_code], cl
        jmp     .writekey

    @@: cmp     al, 0x3a
        jne     @f
        mov     bl, 4
        mov     eax, VKEY_CAPSLOCK
        jmp     .no_key.xor

    @@: cmp     al, 0x45
        jne     @f
        test    cl, cl
        jnz     .writekey
        mov     bl, 2
        mov     eax, VKEY_NUMLOCK
        jmp     .no_key.xor

    @@: cmp     al, 0x46
        jne     @f
        mov     bl, 1
        mov     eax, VKEY_SCRLOCK
        jmp     .no_key.xor

    @@: xor     ebx, ebx
        test    ch, ch
        js      .writekey
        movzx   eax, ch ; plain key
        mov     bl, [keymap + eax]
        mov     edx, [kb_state]
        test    dl, VKEY_CONTROL ; ctrl alt del
        jz      .noctrlaltdel
        test    dl, VKEY_ALT
        jz      .noctrlaltdel
        cmp     ch, 0x53
        jne     .noctrlaltdel
        mov     [ctrl_alt_del], 1

  .noctrlaltdel:
        test    dl, VKEY_CONTROL ; ctrl on ?
        jz      @f
        sub     bl, 0x60

    @@: test    dl, VKEY_SHIFT ; shift on ?
        jz      @f
        mov     bl, [keymap_shift + eax]

    @@: test    dl, VKEY_ALT ; alt on ?
        jz      @f
        mov     bl, [keymap_alt + eax]

    @@: jmp     .writekey

  .modifier:
        test    ch, ch
        js      .modifier.up
        or      [kb_state], eax
        jmp     .writekey

  .modifier.up:
        not     eax
        and     [kb_state], eax
        jmp     .writekey

  .no_key.xor:
        mov     bh, 0
        test    ch, ch
        js      .writekey
        xor     [kb_state], eax
        xor     [kb_lights], bl
        call    set_lights

  .writekey:
        ; test for system hotkeys
        movzx   eax, ch
        cmp     bh, 1
        ja      .nohotkey
        jb      @f
        xor     eax, eax

    @@: mov     eax, [hotkey_scancodes + eax * 4]

  .hotkey_loop:
        test    eax, eax
        jz      .nohotkey
        mov     cl, 0
        call    hotkey_do_test
        jc      .hotkey_cont
        mov     cl, 2
        call    hotkey_do_test
        jc      .hotkey_cont
        mov     cl, 4
        call    hotkey_do_test
        jnc     .hotkey_found

  .hotkey_cont:
        mov     eax, [eax]
        jmp     .hotkey_loop

  .hotkey_found:
        mov     eax, [eax + hotkey_t.pslot]
        ; put key in buffer for process in slot eax
        mov     edi, hotkey_buffer

    @@: cmp     [edi + queued_hotkey_t.pslot], 0
        jz      .found_free
        add     edi, sizeof.queued_hotkey_t
        cmp     edi, hotkey_buffer + HOTKEY_BUFFER_SIZE * sizeof.queued_hotkey_t
        jb      @b

        ; no free space - replace first entry
        mov     edi, hotkey_buffer

  .found_free:
        mov     [edi + queued_hotkey_t.pslot], eax
        mov     al, ch
        cmp     bh, 1
        jnz     @f
        xor     eax, eax

    @@: mov     [edi + queued_hotkey_t.scancode], al
        mov     eax, [kb_state]
        mov     [edi + queued_hotkey_t.mod_keys], ax
        jmp     .exit.irq1

  .nohotkey:
        cmp     [keyboard_mode], 0 ; return from keymap
        jne     .scancode
        test    bh, bh
        jnz     .exit.irq1
        test    bl, bl
        jz      .exit.irq1

        ;.........................Part1 Start
        test    [kb_state], VKEY_NUMLOCK
        jz      .dowrite
        cmp     cl, 0xe0
        jz      .dowrite

        cmp     ch, 55
        jnz     @f
        mov     bl, 0x2a ; *
        jmp     .dowrite

    @@: cmp     ch, 71
        jb      .dowrite
        cmp     ch, 83
        ja      .dowrite
;       push    eax
        movzx   eax, ch
        mov     bl, [numlock_map + eax - 71]
;       pop     eax
        ;.........................Part1 End

        jmp     .dowrite

  .scancode:
        mov     bl, ch

  .dowrite:
        movzx   eax, [key_buffer.count]
        cmp     al, KEY_BUFFER_SIZE
        jae     .exit.irq1
        inc     eax
        mov     [key_buffer.count], al
        mov     [key_buffer + eax - 1], bl

  .exit.irq1:
        mov     [check_idle_semaphore], 5

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc set_lights ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0xed
        call    kb_write
        mov     al, [kb_lights]
        call    kb_write
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc kb_read ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .kr_loop:
        in      al, 0x64
        test    al, 1
        jnz     .kr_ready
        loop    .kr_loop
        mov     ah, 1
        jmp     .kr_exit

  .kr_ready:
        push    ecx
        mov     ecx, 32

  .kr_delay:
        loop    .kr_delay
        pop     ecx
        in      al, 0x60
        xor     ah, ah

  .kr_exit:
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc kb_write ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        mov     dl, al
;       mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's
;
; .kw_loop1:
;       in      al, 0x64
;       test    al, 0x20
;       jz      .kw_ok1
;       loop    .kw_loop1
;       mov     ah, 1
;       jmp     .kw_exit
;
; .kw_ok1:
        in      al, 0x60
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .kw_loop:
        in      al, 0x64
        test    al, 2
        jz      .kw_ok
        loop    .kw_loop
        mov     ah, 1
        jmp     .kw_exit

  .kw_ok:
        mov     al, dl
        out     0x60, al
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .kw_loop3:
        in      al, 0x64
        test    al, 2
        jz      .kw_ok3
        loop    .kw_loop3
        mov     ah, 1
        jmp     .kw_exit

  .kw_ok3:
        mov     ah, 8

  .kw_loop4:
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .kw_loop5:
        in      al, 0x64
        test    al, 1
        jnz     .kw_ok4
        loop    .kw_loop5
        dec     ah
        jnz     .kw_loop4

  .kw_ok4:
        xor     ah, ah

  .kw_exit:
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc kb_cmd ;//////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .c_wait:
        in      al, 0x64
        test    al, 2
        jz      .c_send
        loop    .c_wait
        jmp     .c_error

  .c_send:
        mov     al, bl
        out     0x64, al
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .c_accept:
        in      al, 0x64
        test    al, 2
        jz      .c_ok
        loop    .c_accept

  .c_error:
        mov     ah, 1
        jmp     .c_exit

  .c_ok:
        xor     ah, ah

  .c_exit:
        ret
kendp

;..........................Part2 Start
iglobal
  numlock_map:
    db 0x37 ; Num 7
    db 0x38 ; Num 8
    db 0x39 ; Num 9
    db 0x2d ; Num -
    db 0x34 ; Num 4
    db 0x35 ; Num 5
    db 0x36 ; Num 6
    db 0x2b ; Num +
    db 0x31 ; Num 1
    db 0x32 ; Num 2
    db 0x33 ; Num 3
    db 0x30 ; Num 0
    db 0x2e ; Num .
endg
;..........................Part2 End
