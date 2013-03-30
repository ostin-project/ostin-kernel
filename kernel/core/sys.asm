;;======================================================================================================================
;;///// sys.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
;; (c) 2003 MenuetOS <http://menuetos.net/>
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

uglobal
  application_table_status rd 1 ; 0 - free : other - pid
  idts                     rb 0x41 * (2 + 4 + 2)
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc build_interrupt_table ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, idts
        mov     esi, sys_int
        mov     ecx, 0x40
        mov     eax, (10001110b shl 24) + os_code

    @@: movsw   ; low word of code-entry
        stosd   ; interrupt gate type : os_code selector
        movsw   ; high word of code-entry
        loop    @b
        movsd   ; copy low  dword of trap gate for int 0x40
        movsd   ; copy high dword of trap gate for int 0x40
        lidt    [esi]
        ret
kendp

iglobal
  sys_int:
    ; exception handlers addresses (for interrupt gate construction)
    dd e0, e1, e2, e3, e4, e5, e6, except_7 ; SEE: core/fpu.inc
    dd e8, e9, e10, e11, e12, e13, page_fault_exc, e15
    dd e16, e17, e18, e19
    times 12 dd unknown_interrupt ; int_20..int_31

    ; interrupt handlers addresses (for interrupt gate construction)
    ; 0x20 .. 0x2F - IRQ handlers
    dd irq0, irq_serv.irq_1, irq_serv.irq_2
    dd irq_serv.irq_3, irq_serv.irq_4
    dd irq_serv.irq_5, irq_serv.irq_6, irq_serv.irq_7
    dd irq_serv.irq_8, irq_serv.irq_9, irq_serv.irq_10
    dd irq_serv.irq_11, irq_serv.irq_12, irqD, irq_serv.irq_14, irq_serv.irq_15
    dd irq_serv.irq_16, irq_serv.irq_17, irq_serv.irq_18, irq_serv.irq_19
    dd irq_serv.irq_20, irq_serv.irq_21, irq_serv.irq_22, irq_serv.irq_23
    times 32 - IRQ_RESERVED dd unknown_interrupt
    ; int_0x40 gate trap (for directly copied)
    dw i40 and 0x0ffff, os_code, 11101111b shl 8, i40 shr 16

  idtreg: ; data for LIDT instruction (!!! must be immediately below sys_int data)
    dw 2 * ($ - sys_int - 4) - 1
    dd idts
    dw 0 ; for alignment

  msg_fault_sel dd msg_exc_8, msg_exc_u, msg_exc_a, msg_exc_b, msg_exc_c, msg_exc_d, msg_exc_e

  msg_exc_8   db "Double fault", 0
  msg_exc_u   db "Undefined Exception", 0
  msg_exc_a   db "Invalid TSS", 0
  msg_exc_b   db "Segment not present", 0
  msg_exc_c   db "Stack fault", 0
  msg_exc_d   db "General protection fault", 0
  msg_exc_e   db "Page fault", 0
  msg_sel_ker db "kernel", 0
  msg_sel_app db "application", 0
endg

macro ExcWithoutCode [_num]
{
  e#_num:
        SaveRing3Context
        mov     bl, _num
        jmp     exc_c
}

ExcWithoutCode 0, 1, 2, 3, 4, 5, 6, 15, 16, 19

purge ExcWithoutCode

macro ExcWithCode [_num]
{
  e#_num:
        add     esp, 4
        SaveRing3Context
        mov     bl, _num
        jmp     exc_c
}

ExcWithCode 8, 9, 10, 11, 12, 13, 17, 18

purge ExcWithCode

uglobal
  pf_err_code dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc page_fault_exc ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; foolproof: selectors are currupted...
        pop     [ss:pf_err_code] ; valid until next #PF
        SaveRing3Context
        mov     bl, 14
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc exc_c ;///////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? exceptions (all but 7th - #NM)
;-----------------------------------------------------------------------------------------------------------------------
; Stack frame on exception/interrupt from 3rd ring + pushad (i.e. right here)
reg_ss     equ esp + sizeof.regs_context32_t + 16
reg_esp3   equ esp + sizeof.regs_context32_t + 12
reg_eflags equ esp + sizeof.regs_context32_t + 8
reg_cs3    equ esp + sizeof.regs_context32_t + 4
reg_eip    equ esp + sizeof.regs_context32_t + 0
;-----------------------------------------------------------------------------------------------------------------------
        ; load correct values into segment registers
        mov     ax, app_data
        mov     ds, ax
        mov     es, ax
        ; and set DF to standard
        cld

        movzx   ebx, bl

        ; redirect to V86 manager? (EFLAGS & 0x20000) != 0?
        test    byte[reg_eflags + 2], 2
        jnz     v86_exc_c
        cmp     bl, 14 ; #PF
        jne     @f
        call    page_fault_handler ; SEE: core/memory.inc

    @@: mov     esi, [current_slot_ptr]
        btr     [esi + legacy.slot_t.app.except_mask], ebx
        jnc     @f
        mov     eax, [esi + legacy.slot_t.app.exc_handler]
        test    eax, eax
        jnz     IRetToUserHook

    @@: cli
        mov     eax, [esi + legacy.slot_t.app.debugger_slot]
        test    eax, eax
        jnz     .debug
        sti
        ; not debuggee => say error and terminate
        call    show_error_parameters ;; only ONE using, inline ???
        mov     [esi + legacy.slot_t.task.state], THREAD_STATE_TERMINATING ; terminate
        jmp     change_task ; stack - here it does not matter at all, SEE: core/shed.inc

  .debug:
        ; we are debugged process, notify debugger and suspend ourself
        ; eax=debugger PID
        mov     ecx, 1 ; debug_message code=other_exception
        cmp     bl, 1 ; #DB
        jne     .notify ; notify debugger and suspend ourself
        mov     ebx, dr6 ; debug_message data=DR6_image
        xor     edx, edx
        mov     dr6, edx
        mov     edx, dr7
        mov     cl, not 8

  .l1:
        shl     dl, 2
        jc      @f
        and     bl, cl

    @@: sar     cl, 1
        jc      .l1
        mov     cl, 3 ; debug_message code=debug_exception

  .notify:
        push    ebx ; debug_message data
        push    [esi + legacy.slot_t.task.pid] ; PID
        push    ecx ; debug_message code ((here: ecx==1/3))
        mov     cl, 12 ; debug_message size
        call    debugger_notify ;; only ONE using, inline ??? SEE: core/debug.inc
        add     esp, 12
        mov     esi, [current_slot_ptr]
        mov     [esi + legacy.slot_t.task.state], THREAD_STATE_RUN_SUSPENDED ; suspended
        call    change_task ; SEE: core/shed.inc
        RestoreRing3Context
        iretd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc IRetToUserHook ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        xchg    eax, [reg_eip]
        sub     dword[reg_esp3], 8
        mov     edi, [reg_esp3]
        stosd
        mov     [edi], ebx
        RestoreRing3Context
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc unknown_interrupt ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; simply return control to interrupted process
        iretd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc show_error_parameters ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> bl = error vector
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, [current_slot_ptr] ; not scratched below
        lea     eax, [edx + legacy.slot_t.app.app_name]
        KLog    LOG_ERROR, "Process - forced terminate: #%u (%s)\n", [edx + legacy.slot_t.task.pid], \
                eax:PROCESS_MAX_NAME_LEN
        cmp     bl, 0x08
        jb      .l0
        cmp     bl, 0x0e
        jbe     .l1

  .l0:
        mov     bl, 0x09

  .l1:
        mov     eax, [msg_fault_sel + ebx * 4 - 0x08 * 4]
        KLog    LOG_ERROR, "%s\n", eax
        mov     eax, [reg_cs3 + 4]
        mov     edi, msg_sel_app
        mov     ebx, [reg_esp3 + 4]
        cmp     eax, app_code
        je      @f
        mov     edi, msg_sel_ker
        mov     ebx, [esp + 4 + regs_context32_t.esp]

    @@: KLog    LOG_ERROR, "EAX : %x EBX : %x ECX : %x\n", [esp + 4 + regs_context32_t.eax], \
                [esp + 4 + regs_context32_t.ebx], [esp + 4 + regs_context32_t.ecx]
        KLog    LOG_ERROR, "EDX : %x ESI : %x EDI : %x\n", [esp + 4 + regs_context32_t.edx], \
                [esp + 4 + regs_context32_t.esi], [esp + 4 + regs_context32_t.edi]
        KLog    LOG_ERROR, "EBP : %x EIP : %x ESP : %x\n", [esp + 4 + regs_context32_t.ebp], [reg_eip + 4], ebx
        KLog    LOG_ERROR, "Flags : %x CS : %x (%s)\n", [reg_eflags + 4], eax, edi
        ret
kendp

restore reg_ss
restore reg_esp3
restore reg_eflags
restore reg_cs
restore reg_eip

;-----------------------------------------------------------------------------------------------------------------------
kproc set_application_table_status ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        mov     eax, [current_slot_ptr]
        mov     eax, [eax + legacy.slot_t.task.pid]

        mov     [application_table_status], eax

        pop     eax

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.resize_app_memory ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 64
;-----------------------------------------------------------------------------------------------------------------------
;> eax = 64 - function number
;> ebx = 1 - single subfunction
;> ecx = new memory size
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or 1 (error)
;-----------------------------------------------------------------------------------------------------------------------
;       cmp     eax, 1
        dec     ebx
        jnz     .no_application_mem_resize

        stdcall new_mem_resize, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax

  .no_application_mem_resize:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc terminate ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? terminate application
;-----------------------------------------------------------------------------------------------------------------------
;> esi = slot
;-----------------------------------------------------------------------------------------------------------------------

.slot equ esp ; locals

        push    esi ; save .slot

        shl     esi, 9 ; * sizeof.legacy.slot_t
        cmp     [legacy_slots + esi + legacy.slot_t.app.dir_table], 0
        jne     @f
        pop     esi
        shl     esi, 9 ; * sizeof.legacy.slot_t
        mov     [legacy_slots + esi + legacy.slot_t.task.state], THREAD_STATE_FREE

        pusha
        lea     eax, [legacy_slots + esi]
        call    core.thread.compat.find_by_slot
        test    eax, eax
        jz      .thread_not_found_1

        push    [eax + core.thread_t.process_ptr]

        call    core.thread.free

        pop     eax
        lea     ecx, [eax + core.process_t.threads]
        cmp     [ecx + linked_list_t.next_ptr], ecx
        jne     .thread_not_found_1

        call    core.process.free

  .thread_not_found_1:
        popa

        ret

    @@: cli
        cmp     [application_table_status], 0
        je      .term9
        sti
        call    change_task
        jmp     @b

  .term9:
        call    set_application_table_status

        ; if the process is in V86 mode...
        mov     eax, [.slot]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     esi, [legacy_slots + eax + legacy.slot_t.app.pl0_stack]
        add     esi, sizeof.ring0_stack_data_t
        cmp     [legacy_slots + eax + legacy.slot_t.app.saved_esp0], esi
        jz      .nov86
        ; ...it has page directory for V86 mode
        mov     esi, [legacy_slots + eax + legacy.slot_t.app.saved_esp0]
        mov     ecx, [esi + 4]
        mov     [legacy_slots + eax + legacy.slot_t.app.dir_table], ecx
        ; ...and I/O permission map for V86 mode
        mov     ecx, [esi + 12]
        mov     [legacy_slots + eax + legacy.slot_t.app.io_map], ecx
        mov     ecx, [esi + 8]
        mov     [legacy_slots + eax + legacy.slot_t.app.io_map + 4], ecx

  .nov86:
        mov     esi, [.slot]
        shl     esi, 9 ; * sizeof.legacy.slot_t
        add     esi, legacy_slots + legacy.slot_t.app.obj

    @@: mov     eax, [esi + app_object_t.next_ptr]
        test    eax, eax
        jz      @f

        cmp     eax, esi
        je      @f

        push    esi
        call    [eax + app_object_t.destroy]
        KLog    LOG_DEBUG, "destroy app object\n"
        pop     esi
        jmp     @b

    @@: mov     eax, [.slot]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        stdcall destroy_app_space, [legacy_slots + eax + legacy.slot_t.app.dir_table], [legacy_slots + eax + legacy.slot_t.app.dlls_list_ptr]

        mov     esi, [.slot]
        cmp     [fpu_owner], esi ; if user fpu last -> fpu user = 1
        jne     @f

        mov     [fpu_owner], 1
        mov     eax, [legacy_os_idle_slot.app.fpu_state]
        clts
        bt      [cpu_caps], CAPS_SSE
        jnc     .no_SSE
        fxrstor [eax]
        jmp     @f

  .no_SSE:
        fnclex
        frstor  [eax]

    @@: mov     [key_buffer.count], 0 ; empty keyboard buffer
        mov     [button_buffer.count], 0 ; empty button buffer

        ; remove defined hotkeys
        mov     eax, hotkey_list

  .loop:
        cmp     [eax + hotkey_t.pslot], esi
        jnz     .cont
        mov     ecx, [eax + hotkey_t.next_ptr]
        jecxz   @f
        push    [eax + hotkey_t.prev_ptr]
        pop     [ecx + hotkey_t.prev_ptr]

    @@: mov     ecx, [eax + hotkey_t.prev_ptr]
        push    [eax + hotkey_t.next_ptr]
        pop     [ecx + hotkey_t.next_ptr]
        xor     ecx, ecx
        mov     [eax + hotkey_t.next_ptr], ecx
        mov     [eax + hotkey_t.mod_keys], ecx
        mov     [eax + hotkey_t.pslot], ecx
        mov     [eax + hotkey_t.prev_ptr], ecx

  .cont:
        add     eax, sizeof.hotkey_t
        cmp     eax, hotkey_list + HOTKEY_MAX_COUNT * sizeof.hotkey_t
        jb      .loop

        ; remove hotkeys in buffer
        mov     eax, hotkey_buffer

  .loop2:
        cmp     [eax + queued_hotkey_t.pslot], esi
        jnz     .cont2
        and     dword[eax + queued_hotkey_t.mod_keys], 0
        and     [eax + queued_hotkey_t.pslot], 0

  .cont2:
        add     eax, sizeof.queued_hotkey_t
        cmp     eax, hotkey_buffer + HOTKEY_BUFFER_SIZE * sizeof.queued_hotkey_t
        jb      .loop2

        mov     ecx, esi ; remove buttons

  .bnewba2:
        mov     edi, [BTN_ADDR]
        mov     eax, edi
        mov     ebx, [edi + sys_buttons_header_t.count]
        inc     ebx

  .bnewba:
        dec     ebx
        jz      .bnmba
        add     eax, sizeof.sys_button_t
        cmp     ecx, [eax + sys_button_t.pslot]
        jnz     .bnewba
        pusha
        mov     ecx, ebx
        inc     ecx
        shl     ecx, 4 ; *= sizeof.sys_button_t
        mov     ebx, eax
        add     eax, sizeof.sys_button_t
        call    memmove
        dec     [edi + sys_buttons_header_t.count]
        popa
        jmp     .bnewba2

  .bnmba:
        pusha   ; save window coordinates for window restoring
        shl     esi, 9 ; * sizeof.legacy.slot_t
        add     esi, legacy_slots
        mov     eax, [esi + legacy.slot_t.window.box.left]
        mov     [draw_limits.left], eax
        add     eax, [esi + legacy.slot_t.window.box.width]
        mov     [draw_limits.right], eax
        mov     eax, [esi + legacy.slot_t.window.box.top]
        mov     [draw_limits.top], eax
        add     eax, [esi + legacy.slot_t.window.box.height]
        mov     [draw_limits.bottom], eax

        xor     eax, eax
        mov     [esi + legacy.slot_t.window.box.left], eax
        mov     [esi + legacy.slot_t.window.box.width], eax
        mov     [esi + legacy.slot_t.window.box.top], eax
        mov     [esi + legacy.slot_t.window.box.height], eax
        mov     [esi + legacy.slot_t.window.cl_workarea], eax
        mov     [esi + legacy.slot_t.window.cl_titlebar], eax
        mov     [esi + legacy.slot_t.window.cl_frames], eax
        mov     dword[esi + legacy.slot_t.window.reserved], eax ; clear all flags: wstate, redraw, wdrawn
        lea     edi, [esi + legacy.slot_t.draw]
        mov     ecx, sizeof.legacy.draw_data_t / 4
        rep
        stosd
        popa

        ; debuggee test
        pushad
        mov     edi, esi
        shl     edi, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + edi + legacy.slot_t.app.debugger_slot]
        test    eax, eax
        jz      .nodebug
        MovStk  ecx, 8
        push    [legacy_slots + edi + legacy.slot_t.task.pid] ; PID
        push    2
        call    debugger_notify
        pop     ecx
        pop     ecx

  .nodebug:
        popad

        mov     ebx, [.slot]
        shl     ebx, 9 ; * sizeof.legacy.slot_t
        push    ebx
        mov     ebx, [legacy_slots + ebx + legacy.slot_t.app.pl0_stack]
        stdcall kernel_free, ebx

        pop     ebx
        mov     ebx, [legacy_slots + ebx + legacy.slot_t.app.cur_dir]
        stdcall kernel_free, ebx

        mov     edi, [.slot]
        shl     edi, 9 ; * sizeof.legacy.slot_t
        add     edi, legacy_slots

        mov     eax, [edi + legacy.slot_t.app.io_map]
        cmp     eax, [legacy_os_idle_slot.app.io_map]
        je      @f
        call    free_page

    @@: mov     eax, [edi + legacy.slot_t.app.io_map + 4]
        cmp     eax, [legacy_os_idle_slot.app.io_map + 4]
        je      @f
        call    free_page

    @@: mov     ecx, sizeof.legacy.app_data_t / 4
        add     edi, legacy.slot_t.app
        xor     eax, eax
        rep
        stosd

        ; activate window
        movzx   eax, [pslot_to_wnd_pos + esi * 2]
        cmp     eax, [legacy_slots.last_valid_slot]
        jne     .dont_activate
        pushad

  .check_next_window:
        dec     eax
        cmp     eax, 1
        jbe     .nothing_to_activate
        lea     esi, [wnd_pos_to_pslot + eax * 2]
        movzx   edi, word[esi] ; edi = process
        shl     edi, 9 ; * sizeof.legacy.slot_t
        cmp     [legacy_slots + edi + legacy.slot_t.task.state], THREAD_STATE_FREE ; skip dead slots
        je      .check_next_window
        add     edi, legacy_slots

        ; skip minimized windows
        test    [edi + legacy.slot_t.window.fl_wstate], WINDOW_STATE_MINIMIZED
        jnz     .check_next_window

        call    waredraw

  .nothing_to_activate:
        popad

  .dont_activate:
        push    esi ; remove hd1 & cd & flp reservation
        shl     esi, 9 ; * sizeof.legacy.slot_t
        mov     esi, [legacy_slots + esi + legacy.slot_t.task.pid]
        cmp     [hd1_status], esi
        jnz     @f
        call    free_hd_channel
        and     [hd1_status], 0

    @@: cmp     [cd_status], esi
        jnz     @f
        call    free_cd_channel
        and     [cd_status], 0

    @@: pop     esi
        cmp     [bgrlockpid], esi
        jnz     @f
        and     [bgrlockpid], 0
        and     [bgrlock], 0

    @@: pusha   ; remove all port reservations
        mov     edx, esi
        shl     edx, 9 ; * sizeof.legacy.slot_t
        mov     edx, [legacy_slots + edx + legacy.slot_t.task.pid]

  .rmpr0:
        mov     esi, [RESERVED_PORTS.count]

        test    esi, esi
        jz      .rmpr9

  .rmpr3:
        mov     edi, esi
        shl     edi, 4
        add     edi, RESERVED_PORTS

        cmp     edx, [edi + app_io_ports_range_t.pid]
        je      .rmpr4

        dec     esi
        jnz     .rmpr3

        jmp     .rmpr9

  .rmpr4:
        mov     ecx, 256
        sub     ecx, esi
        shl     ecx, 4

        mov     esi, edi
        add     esi, 16
        rep
        movsb

        dec     [RESERVED_PORTS.count]

        jmp     .rmpr0

  .rmpr9:
        popa
        mov     edi, esi ; do not run this process slot
        shl     edi, 9 ; * sizeof.legacy.slot_t
        mov     [legacy_slots + edi + legacy.slot_t.task.state], THREAD_STATE_FREE

        pusha
        lea     eax, [legacy_slots + edi]
        call    core.thread.compat.find_by_slot
        test    eax, eax
        jz      .thread_not_found_2

        push    [eax + core.thread_t.process_ptr]

        call    core.thread.free

        pop     eax
        lea     ecx, [eax + core.process_t.threads]
        cmp     [ecx + linked_list_t.next_ptr], ecx
        jne     .thread_not_found_2

        call    core.process.free

  .thread_not_found_2:
        popa

        ; debugger test - terminate all debuggees
        mov     eax, 2
        mov     ecx, legacy_slots + 2 * sizeof.legacy.slot_t + legacy.slot_t.app.debugger_slot

  .xd0:
        cmp     eax, [legacy_slots.last_valid_slot]
        ja      .xd1
        cmp     [ecx], esi
        jnz     @f
        and     dword[ecx], 0
        pushad
        xchg    eax, ecx
        mov     ebx, 2
        call    sysfn.system_ctl
        popad

    @@: inc     eax
        add     ecx, sizeof.legacy.slot_t
        jmp     .xd0

  .xd1:
;       call    systest
        sti     ; .. and life goes on

        mov     eax, [draw_limits.left]
        mov     ebx, [draw_limits.top]
        mov     ecx, [draw_limits.right]
        mov     edx, [draw_limits.bottom]
        call    calculatescreen
        xor     eax, eax
        xor     esi, esi
        call    redrawscreen

;       mov     [MOUSE_BACKGROUND], 0 ; no mouse background
;       mov     [DONT_DRAW_MOUSE], 0 ; draw mouse

        and     [application_table_status], 0
        add     esp, 4
        ret
kendp

restore .slot
