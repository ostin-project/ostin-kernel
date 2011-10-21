;;======================================================================================================================
;;///// event.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

WINDOW_MOVE_AND_RESIZE_FLAGS = \
  mouse.WINDOW_RESIZE_N_FLAG + \
  mouse.WINDOW_RESIZE_W_FLAG + \
  mouse.WINDOW_RESIZE_S_FLAG + \
  mouse.WINDOW_RESIZE_E_FLAG + \
  mouse.WINDOW_MOVE_FLAG

uglobal
  align 4
  event_start dd ?
  event_end   dd ?
  event_uid   dd 0
endg

EV_SPACE   = 512
; "virtual" event, fields used:
;   FreeEvents.next_ptr = event_start and
;   FreeEvents.prev_ptr = event_end
FreeEvents = event_start - event_t.next_ptr

;-----------------------------------------------------------------------------------------------------------------------
kproc init_events ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# used from kernel.asm
;-----------------------------------------------------------------------------------------------------------------------
        stdcall kernel_alloc, EV_SPACE * sizeof.event_t
        or      eax, eax
        jz      .fail
        ; eax - current event, ebx - previos event below
        mov     ecx, EV_SPACE ; current - in allocated space
        mov     ebx, FreeEvents ; previos - start of list
        push    ebx ; same will be the end of list

    @@: mov     [ebx + event_t.next_ptr], eax
        mov     [eax + event_t.prev_ptr], ebx
        mov     ebx, eax ; previos <- current
        add     eax, sizeof.event_t ; new current
        loop    @b
        pop     eax ; and here it becomes the end of list
        mov     [ebx + event_t.next_ptr], eax
        mov     [eax + event_t.prev_ptr], ebx

  .fail:
        ret
kendp

EVENT_WATCHED  equ 0x10000000 ; bit 28
EVENT_SIGNALED equ 0x20000000 ; bit 29
MANUAL_RESET   equ 0x40000000 ; bit 30
MANUAL_DESTROY equ 0x80000000 ; bit 31

;-----------------------------------------------------------------------------------------------------------------------
kproc create_event ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Moving event_t from FreeEvents list info ObjList list of current slot
;? event_t.state is set from ecx, event_t.code is set indirectly from esi (if esi<>0)
;-----------------------------------------------------------------------------------------------------------------------
;> esi = event data
;> ecx = flags
;-----------------------------------------------------------------------------------------------------------------------
;< eax = event (=0 => fail)
;< edx = uid
;-----------------------------------------------------------------------------------------------------------------------
;# scratched: ebx, ecx, esi, edi
;# EXPORT use
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [current_slot]
        add     ebx, app_data_t.obj
        mov     edx, [TASK_BASE]
        mov     edx, [edx + task_data_t.pid]
        pushfd
        cli
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc set_event ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Taking new event from FreeEvents, filling its fields as specified by ecx, edx, esi
;? and adding to list pointed by ebx.
;? Returning event itself (in eax), and its uid (in edx)
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = start-chain "virtual" event for entry new event Right of him
;> ecx = flags (copied to event_t.state)
;> edx = pid (copied to event_t.pid)
;> esi = event data (copied to event_t.code indirect, =0 => skip)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = event (=0 => fail)
;< edx = uid
;-----------------------------------------------------------------------------------------------------------------------
; scratched: ebx, ecx, esi, edi
;; INTERNAL use !!! don't use for Call
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, FreeEvents
        cmp     eax, [eax + event_t.next_ptr]
        jne     @f ; not empty ???
        pushad
        call    init_events
        popad
        jz      RemoveEventTo.break ; POPF+RET

    @@: mov     eax, [eax + event_t.next_ptr]
        mov     [eax + event_t.magic], 'EVNT'
        mov     [eax + event_t.destroy], destroy_event.internal
        mov     [eax + event_t.state], ecx
        mov     [eax + event_t.pid], edx
        inc     [event_uid]
        Mov     [eax + event_t.id], edx, [event_uid]
        or      esi, esi
        jz      RemoveEventTo
        lea     edi, [eax + event_t.code]
        mov     ecx, sizeof.event_code_t / 4
        cld
        rep     movsd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc RemoveEventTo ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pointer to event, WHICH is being inserted
;> ebx = pointer to event, AFTER which it's being inserted
;-----------------------------------------------------------------------------------------------------------------------
;# scratched: ebx,ecx
;# INTERNAL use !!! don't use for Call
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, eax ; ecx=eax=Self, ebx=NewLeft
        xchg    ecx, [ebx + event_t.next_ptr] ; NewLeft.next_ptr=Self, ecx=NewRight
        cmp     eax, ecx ; stop, I'm thinking...
        je      .break ; - what if I'm a fool?
        mov     [ecx + event_t.prev_ptr], eax ; NewRight.prev_ptr=Self
        xchg    ebx, [eax + event_t.prev_ptr] ; Self.prev_ptr=NewLeft, ebx=OldLeft
        xchg    ecx, [eax + event_t.next_ptr] ; Self.next_ptr=NewRight, ecx=OldRight
        mov     [ebx + event_t.next_ptr], ecx ; OldLeft.next_ptr=OldRight
        mov     [ecx + event_t.prev_ptr], ebx ; OldRight.prev_ptr=OldLeft

  .break:
        popfd
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc NotDummyTest ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# INTERNAL use (not returned for fail !!!)
;-----------------------------------------------------------------------------------------------------------------------
        pop     edi
        call    DummyTest ; not returned for fail !!!
        mov     ebx, eax
        mov     eax, [ebx + event_t.pid]
        push    edi

  .small:
        ; a bit askew...
        pop     edi
        pushfd
        cli
        call    pid_to_slot ; saved all registers (eax - retval)
        shl     eax, 8
        jz      RemoveEventTo.break ; POPF+RET
        jmp     edi ; ordinary return
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc raise_event ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Setting up event_t.code data
;? If EVENT_SIGNALED flag is already set - doing nothing
;? Otherwise: this flag is being set, except if EVENT_WATCHED flag is set in edx
;? In that case EVENT_SIGNALED is only being set if EVENT_WATCHED is present in the event itself
;-----------------------------------------------------------------------------------------------------------------------
;> eax = event
;> ebx = uid (for Dummy testing)
;> edx = flags
;> esi = event data (=0 => skip)
;-----------------------------------------------------------------------------------------------------------------------
;# scratched: ebx, ecx, esi, edi
;# EXPORT use
;-----------------------------------------------------------------------------------------------------------------------
        call    NotDummyTest ; not returned for fail !!!
        or      esi, esi
        jz      @f
        lea     edi, [ebx + event_t.code]
        mov     ecx, sizeof.event_code_t / 4
        cld
        rep     movsd

    @@: test    byte[ebx + event_t.state + 3], EVENT_SIGNALED shr 24
        jnz     RemoveEventTo.break ; POPF+RET
        bt      edx, 28 ; EVENT_WATCHED
        jnc     @f
        test    byte[ebx + event_t.state + 3], EVENT_WATCHED  shr 24
        jz      RemoveEventTo.break ; POPF+RET

    @@: or      byte[ebx + event_t.state + 3], EVENT_SIGNALED shr 24
        add     eax, SLOT_BASE + app_data_t.ev
        xchg    eax, ebx
        jmp     RemoveEventTo
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc clear_event ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = event
;> ebx = uid (for Dummy testing)
;-----------------------------------------------------------------------------------------------------------------------
;# scratched: ebx, ecx
;# EXPORT use
;-----------------------------------------------------------------------------------------------------------------------
        call    NotDummyTest ; not returned for fail !!!
        add     eax, SLOT_BASE + app_data_t.obj
        and     byte[ebx + event_t.state + 3], not ((EVENT_SIGNALED + EVENT_WATCHED) shr 24)
        xchg    eax, ebx
        jmp     RemoveEventTo
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc send_event ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Creates new event_t (taking it from FreeEvents list) in EventList list of
;? target slot (eax=pid), with (indirect) data from esi, and state=EVENT_SIGNALED
;-----------------------------------------------------------------------------------------------------------------------
;> eax = slots pid, to sending new event
;> esi = pointer to sending data (in code field of new event)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = event (=0 => fail)
;< edx = uid
;-----------------------------------------------------------------------------------------------------------------------
;# warning:
;#   may be used as CDECL with such prefix...
;#     mov     esi,[esp+8]
;#     mov     eax,[esp+4]
;#   but not as STDCALL :(
;# scratched: ebx, ecx, esi, edi
;# EXPORT use
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, eax
        call    NotDummyTest.small ; not returned for fail !!!
        lea     ebx, [SLOT_BASE + eax + app_data_t.ev]
        mov     ecx, EVENT_SIGNALED
        jmp     set_event
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc DummyTest ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = event
;> ebx = uid (for Dummy testing)
;-----------------------------------------------------------------------------------------------------------------------
;# INTERNAL use (not returned for fail !!!)
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [eax + event_t.magic], 'EVNT'
        jne     @f
        cmp     [eax + event_t.id], ebx
        je      .ret

    @@: pop     eax
        xor     eax, eax

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Wait_events ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        or      ebx, -1 ; infinite timeout
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Wait_events_ex ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Waiting for an "abstract" event putting slot into 5th state.
;? Abstractness is in the fact that event is being detected by app_data_t.wait_test function,
;? which is provided by client and could do almost anything.
;? This allowes shed detecting the event reliably, without making any "dummy" switches to
;? do "our/foreign" kind of analysis inside the task.
;-----------------------------------------------------------------------------------------------------------------------
;> edx = wait_test, pointer to client testing function
;> ecx = wait_param, additional argument, probably needed for [wait_test]
;> ebx = wait_timeout
;-----------------------------------------------------------------------------------------------------------------------
;< eax = [wait_test] call result (=0 => timeout)
;-----------------------------------------------------------------------------------------------------------------------
;# scratched: esi
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, [current_slot]
        mov     [esi + app_data_t.wait_param], ecx
        pushad
        mov     ebx, esi ; still a question, what goes where...
        pushfd  ; consequence of general concept: allow test function to disable interrupts,
        cli     ; like if it was called from shed
        call    edx
        popfd
        mov     [esp + regs_context32_t.eax], eax
        popad
        or      eax, eax
        jnz     .exit

        mov     [esi + app_data_t.wait_test], edx

        push    edx
        mov     eax, ebx
        cdq
        cmp     eax, -1
        je      @f

        xor     edx, edx
        call    hs_to_ticks
        add     eax, [timer_ticks]
        adc     edx, [timer_ticks + 4]

    @@: mov     dword[esi + app_data_t.wait_timeout], eax
        mov     dword[esi + app_data_t.wait_timeout + 4], edx
        pop     edx

        mov     eax, [TASK_BASE]
        mov     [eax + task_data_t.state], TSTATE_WAITING
        call    change_task
        mov     eax, [esi + app_data_t.wait_param]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc wait_event ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Wait for EVENT_SIGNALED flag in a concrete Event
;? (being set, probably, by raise_event)
;? Doing nothing if MANUAL_RESET flag is set
;? Otherwise: EVENT_SIGNALED and EVENT_WATCHED event flags will be reset
;? If MANUAL_DESTROY event flag is set, event is moved to ObjList list of current slot,
;? otherwise, event is destroyes (with destroy_event.internal)
;-----------------------------------------------------------------------------------------------------------------------
;> eax = event
;> ebx = uid (for Dummy testing)
;-----------------------------------------------------------------------------------------------------------------------
;# scratched: ecx, edx, esi
;# EXPORT use
;-----------------------------------------------------------------------------------------------------------------------
        call    DummyTest
        mov     ecx, eax ; wait_param
        mov     edx, get_event_alone ; wait_test
        call    Wait_events ; timeout ignored
        jmp     wait_finish
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_event_ex ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? sysfn.system_service:14
;? Wait for any event in EventList list of current slot
;? Event code - copied into application memory (pointed by edi)
;? If MANUAL_RESET flag is set - doing nothing
;? Otherwise: EVENT_SIGNALED and EVENT_WATCHED event flags will be reset
;? If MANUAL_DESTROY event flag is set, event is moved to ObjList list of current slot,
;? otherwise, event is destroyes (with destroy_event.internal)
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to application memory to receive event_t.code
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pointer to event_t
;-----------------------------------------------------------------------------------------------------------------------
;# scratched: ebx, ecx, edx, esi, edi
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, get_event_queue ; wait_test
        call    Wait_events ; timeout ignored
        lea     esi, [eax + event_t.code]
        mov     ecx, sizeof.event_code_t / 4
        cld
        rep     movsd
        mov     [edi - sizeof.event_code_t + 2], cl ; clear priority field

wait_finish:
        test    byte[eax + event_t.state + 3], MANUAL_RESET shr 24
        jnz     get_event_queue.ret ; RET
        and     byte[eax + event_t.state + 3], not ((EVENT_SIGNALED + EVENT_WATCHED) shr 24)
        test    byte[eax + event_t.state + 3], MANUAL_DESTROY shr 24
        jz      destroy_event.internal
        mov     ebx, [current_slot]
        add     ebx, app_data_t.obj
        pushfd
        cli
        jmp     RemoveEventTo
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc destroy_event ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Move event_t into FreeEvents list, clearing magic, destroy, pid, id fields
;-----------------------------------------------------------------------------------------------------------------------
;> eax = event
;> ebx = uid (for Dummy testing)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pointer to event_t (=0 => fail)
;-----------------------------------------------------------------------------------------------------------------------
;# scratched: ebx, ecx
;# EXPORT use
;-----------------------------------------------------------------------------------------------------------------------
        call    DummyTest ; not returned for fail !!!

  .internal:
        xor     ecx, ecx ; clear common header
        pushfd
        cli
        mov     [eax + event_t.magic], ecx
        mov     [eax + event_t.destroy], ecx
        mov     [eax + event_t.pid], ecx
        mov     [eax + event_t.id], ecx
        mov     ebx, FreeEvents
        jmp     RemoveEventTo
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_event_queue ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Client testing function for get_event_ex
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to app_data_t of slot being tested
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pointer to event_t (=0 => fail)
;-----------------------------------------------------------------------------------------------------------------------
;# warning:
;#   * don't use [TASK_BASE],[current_slot],[CURRENT_TASK] - it is not for your slot
;#   * may be assumed, that interrupt are disabled
;#   * it is not restriction for scratched registers
;-----------------------------------------------------------------------------------------------------------------------
        add     ebx, app_data_t.ev
        mov     eax, [ebx + app_object_t.prev_ptr] ; checking from the end (FIFO)
        cmp     eax, ebx ; empty ???
        je      get_event_alone.ret0

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_event_alone ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Client testing function for wait_event
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to app_data_t of slot being tested
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pointer to event_t (=0 => fail)
;-----------------------------------------------------------------------------------------------------------------------
;# warning:
;#   * don't use [TASK_BASE],[current_slot],[CURRENT_TASK] - it is not for your slot
;#   * may be assumed, that interrupt are disabled
;#   * it is not restriction for scratched registers
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [ebx + app_data_t.wait_param]
        test    byte[eax + event_t.state + 3], EVENT_SIGNALED shr 24
        jnz     .ret
        or      byte[eax + event_t.state + 3], EVENT_WATCHED shr 24

  .ret0:
        xor     eax, eax ; NO event!!!

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.send_window_message ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 72
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        jnz     .ret ; subfunction==1 ?
;       pushfd  ; what for?
        cli
        sub     ecx, 2
        je      .sendkey
        dec     ecx
        jnz     .retf

  .sendbtn:
        cmp     [BTN_COUNT], 1
        jae     .result ; overflow
        inc     [BTN_COUNT]
        shl     edx, 8
        mov     [BTN_BUFF], edx
        jmp     .result

  .sendkey:
        movzx   eax, [KEY_COUNT]
        cmp     al, 120
        jae     .result ; overflow
        inc     [KEY_COUNT]
        mov     [KEY_BUFF + eax], dl

  .result:
        setae   [esp + 4 + regs_context32_t.al] ; initially, dword[esp+32]==72

  .retf:
;       popfd

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.check_for_event ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 11
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [current_slot] ; still a question, what goes where...
        pushfd  ; consequence of general concept: allow test function to disable interrupts,
        cli     ; like if it was called from shed
        call    get_event_for_app
        popfd
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.wait_for_event ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 10
;-----------------------------------------------------------------------------------------------------------------------
        or      ebx, -1 ; infinite timeout
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.wait_for_event_with_timeout ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 23
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, get_event_for_app ; wait_test
        call    Wait_events_ex ; ebx - timeout
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_event_for_app ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Client test function for applcations (f10,f23)
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to app_data_t of slot being tested
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pointer to event_t (=0 => no events)
;-----------------------------------------------------------------------------------------------------------------------
;# used from f10,f11,f23
;# warning:
;#   * don't use [TASK_BASE],[current_slot],[CURRENT_TASK] - it is not for your slot
;#   * may be assumed, that interrupt are disabled
;#   * it is not restriction for scratched registers
;-----------------------------------------------------------------------------------------------------------------------
        movzx   edi, bh ; bh  is assumed as [CURRENT_TASK]
        shl     edi, 5
        add     edi, TASK_DATA - sizeof.task_data_t ; edi is assumed as [TASK_BASE]
        mov     ecx, [edi + task_data_t.event_mask]

  .loop:
        ; until we reset all mask bits
        bsr     eax, ecx ; find non-zero mask bit (31 -> 0)
        jz      .no_events ; all mask bits reset but didn't find anything???
        btr     ecx, eax ; reset mask bit being checked
        ; jumping to this (eax) bit handler
        cmp     eax, 16
        jae     .IRQ ; eax=[16..31]=retvals, events irq0..irq15
        cmp     eax, 9
        jae     .loop ; eax=[9..15], ignored
        cmp     eax, 3
        je      .loop ; eax=3, ignored
        ja      .FlagAutoReset ; eax=[4..8], retvals=eax+1
        cmp     eax, 1
        jae     .BtKy ; eax=[1,2],  retvals=eax+1

  .WndRedraw:
        ; eax=0, retval WndRedraw=1
        cmp     [edi - twdw + window_data_t.fl_redraw], al ; al==0
        jne     .result
        jmp     .loop

  .no_events:
        xor     eax, eax
        ret

  .IRQ:
        ; TODO: do the same as for FlagAutoReset (BgrRedraw,Mouse,IPC,Stack,Debug)
        mov     edx, [irq_owner + eax * 4 - 64] ; eax==16+irq
        cmp     edx, [edi + task_data_t.pid]
        jne     .loop
        mov     edx, eax
        shl     edx, 12
        cmp     dword[IRQ_SAVE + edx - 0x10000], 0 ; edx==(16+irq)*0x1000
        je      .loop ; empty ???
        ret     ; retval = eax

  .FlagAutoReset:
        ; retvals: BgrRedraw=5, Mouse=6, IPC=7, Stack=8, Debug=9
        cmp     eax, 5 ; Mouse 5+1=6
        jne     @f
        push    eax
        ; If the window is captured and moved by the user, then no mouse events!!!
        mov     al, [mouse.active_sys_window.action]
        and     al, WINDOW_MOVE_AND_RESIZE_FLAGS
        test    al, al
        pop     eax
        jnz     .loop

    @@: btr     [ebx + app_data_t.event_mask], eax
        jnc     .loop

  .result:
        ; retval = eax+1
        inc     eax
        ret

  .BtKy:
        movzx   edx, bh
        movzx   edx, [WIN_STACK + edx * 2]
        je      .Keys ; eax=1, retval Keys=2

  .Buttons:
        ; eax=2, retval Buttons=3
        cmp     [BTN_COUNT], 0
        je      .loop ; empty ???
        cmp     edx, [TASK_COUNT]
        jne     .loop ; not Top ???
        mov     edx, [BTN_BUFF]
        shr     edx, 8
        cmp     edx, 0xffff ; -ID for Minimize-Button of Form
        jne     .result
        mov     [window_minimize], 1
        dec     [BTN_COUNT]
        jmp     .loop

  .Keys:
        ; eax==1
        cmp     edx, [TASK_COUNT]
        jne     @f ; not Top ???
        cmp     [KEY_COUNT], al ; al==1
        jae     .result ; not empty ???

    @@: mov     edx, hotkey_buffer

    @@: cmp     [edx], bh ; bh - slot for testing
        je      .result
        add     edx, 8
        cmp     edx, hotkey_buffer + 120 * 8
        jb      @b
        jmp     .loop
kendp
