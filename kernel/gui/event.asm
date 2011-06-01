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
; "виртуальный" event, используются только поля:
; FreeEvents.next_ptr=event_start и FreeEvents.prev_ptr=event_end
FreeEvents = event_start - event_t.next_ptr

align 4
init_events:                                       ;; used from kernel.asm
        stdcall kernel_alloc, EV_SPACE * sizeof.event_t
        or      eax, eax
        jz      .fail
        ; eax - current event, ebx - previos event below
        mov     ecx, EV_SPACE ; current - in allocated space
        mov     ebx, FreeEvents ; previos - начало списка
        push    ebx ; оно же и конец потом будет

    @@: mov     [ebx + event_t.next_ptr], eax
        mov     [eax + event_t.prev_ptr], ebx
        mov     ebx, eax ; previos <- current
        add     eax, sizeof.event_t ; new current
        loop    @b
        pop     eax ; вот оно концом и стало
        mov     [ebx + event_t.next_ptr], eax
        mov     [eax + event_t.prev_ptr], ebx

  .fail:
        ret

EVENT_WATCHED  equ 0x10000000 ; бит 28
EVENT_SIGNALED equ 0x20000000 ; бит 29
MANUAL_RESET   equ 0x40000000 ; бит 30
MANUAL_DESTROY equ 0x80000000 ; бит 31

align 4
create_event: ;; EXPORT use
        ; info:
        ;    Переносим event_t из списка FreeEvents в список ObjList текущего слота
        ;    event_t.state устанавливаем из ecx, event_t.code косвенно из esi (если esi<>0)
        ; param:
        ;    esi - event data
        ;    ecx - flags
        ; retval:
        ;    eax - event (=0 => fail)
        ;    edx - uid
        ; scratched: ebx,ecx,esi,edi

        mov     ebx, [current_slot]
        add     ebx, APP_OBJ_OFFSET
        mov     edx, [TASK_BASE]
        mov     edx, [edx + task_data_t.pid]
        pushfd
        cli

set_event: ;; INTERNAL use !!! don't use for Call
        ; info:
        ;    Берем новый event из FreeEvents, заполняем его поля, как указано в ecx,edx,esi
        ;    и устанавливаем в список, указанный в ebx.
        ;    Возвращаем сам event (в eax), и его uid (в edx)
        ; param:
        ;    ebx - start-chain "virtual" event for entry new event Right of him
        ;    ecx - flags      (copied to event_t.state)
        ;    edx - pid        (copied to event_t.pid)
        ;    esi - event data (copied to event_t.code indirect, =0 => skip)
        ; retval:
        ;    eax - event (=0 => fail)
        ;    edx - uid
        ; scratched: ebx,ecx,esi,edi

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

RemoveEventTo: ;; INTERNAL use !!! don't use for Call
        ; param:
        ;    eax - указатель на event, КОТОРЫЙ вставляем
        ;    ebx - указатель на event, ПОСЛЕ которого вставляем
        ; scratched: ebx,ecx

        mov     ecx, eax ; ecx=eax=Self, ebx=NewLeft
        xchg    ecx, [ebx + event_t.next_ptr] ; NewLeft.next_ptr=Self, ecx=NewRight
        cmp     eax, ecx ; стоп, себе думаю...
        je      .break ; - а не дурак ли я?
        mov     [ecx + event_t.prev_ptr], eax ; NewRight.prev_ptr=Self
        xchg    ebx, [eax + event_t.prev_ptr] ; Self.prev_ptr=NewLeft, ebx=OldLeft
        xchg    ecx, [eax + event_t.next_ptr] ; Self.next_ptr=NewRight, ecx=OldRight
        mov     [ebx + event_t.next_ptr], ecx ; OldLeft.next_ptr=OldRight
        mov     [ecx + event_t.prev_ptr], ebx ; OldRight.prev_ptr=OldLeft

  .break:
        popfd
        ret

align 4
NotDummyTest: ;; INTERNAL use (not returned for fail !!!)
        pop     edi
        call    DummyTest ; not returned for fail !!!
        mov     ebx, eax
        mov     eax, [ebx + event_t.pid]
        push    edi

  .small:
        ; криво как-то...
        pop     edi
        pushfd
        cli
        call    pid_to_slot ; saved all registers (eax - retval)
        shl     eax, 8
        jz      RemoveEventTo.break ; POPF+RET
        jmp     edi ; штатный возврат

align 4
raise_event: ;; EXPORT use
        ; info:
        ;    Устанавливаем данные event_t.code
        ;    Если там флаг EVENT_SIGNALED уже активен - больше ничего
        ;    Иначе: этот флаг взводится, за исключением случая наличия флага EVENT_WATCHED в edx
        ;    В этом случае EVENT_SIGNALED взводится лишь при наличие EVENT_WATCHED в самом событии
        ; param:
        ;    eax - event
        ;    ebx - uid (for Dummy testing)
        ;    edx - flags
        ;    esi - event data (=0 => skip)
        ; scratched: ebx,ecx,esi,edi

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
        add     eax, SLOT_BASE + APP_EV_OFFSET
        xchg    eax, ebx
        jmp     RemoveEventTo

align 4
clear_event: ;; EXPORT use
        ; info:
        ;
        ; param:
        ;    eax - event
        ;    ebx - uid (for Dummy testing)
        ; scratched: ebx,ecx

        call    NotDummyTest ; not returned for fail !!!
        add     eax, SLOT_BASE + APP_OBJ_OFFSET
        and     byte[ebx + event_t.state + 3], not ((EVENT_SIGNALED + EVENT_WATCHED) shr 24)
        xchg    eax, ebx
        jmp     RemoveEventTo

align 4
send_event: ;; EXPORT use
        ; info:
        ;    Создает новый event_t (вытаскивает из списка FreeEvents) в списке EventList
        ;    целевого слота (eax=pid), с данными из esi косвенно, и state=EVENT_SIGNALED
        ; param:
        ;    eax - slots pid, to sending new event
        ;    esi - pointer to sending data (in code field of new event)
        ; retval:
        ;    eax - event (=0 => fail)
        ;    edx - uid
        ; warning:
        ;    may be used as CDECL with such prefix...
        ;        mov     esi,[esp+8]
        ;        mov     eax,[esp+4]
        ;    but not as STDCALL :(
        ; scratched: ebx,ecx,esi,edi

        mov     edx, eax
        call    NotDummyTest.small ; not returned for fail !!!
        lea     ebx, [eax + SLOT_BASE + APP_EV_OFFSET]
        mov     ecx, EVENT_SIGNALED
        jmp     set_event

align 4
DummyTest: ;; INTERNAL use (not returned for fail !!!)
        ; param:
        ;    eax - event
        ;    ebx - uid (for Dummy testing)

        cmp     [eax + event_t.magic], 'EVNT'
        jne     @f
        cmp     [eax + event_t.id], ebx
        je      .ret

    @@: pop     eax
        xor     eax, eax

  .ret:
        ret

align 4
Wait_events:
        or      ebx, -1 ; infinite timeout

Wait_events_ex:
        ; info:
        ;    Ожидание "абстрактного" события через перевод слота в 5-ю позицию.
        ;    Абстрактность заключена в том, что факт события определяется функцией app_data_t.wait_test,
        ;    которая задается клиентом и может быть фактически любой.
        ;    Это позволяет shed-у надежно определить факт события, и не совершать "холостых" переключений,
        ;    предназначенных для разборок типа "свой/чужой" внутри задачи.
        ; param:
        ;    edx - wait_test, клиентская ф-я тестирования (адрес кода)
        ;    ecx - wait_param, дополнительный параметр, возможно необходимый для [wait_test]
        ;    ebx - wait_timeout
        ; retval:
        ;    eax - результат вызова [wait_test] (=0 => timeout)
        ; scratched: esi

        mov     esi, [current_slot]
        mov     [esi + app_data_t.wait_param], ecx
        pushad
        mov     ebx, esi ; пока это вопрос, чего куды сувать..........
        pushfd  ; это следствие общей концепции: пусть ф-я тестирования имеет
        cli     ; право рассчитывать на закрытые прерывания, как при вызове из shed
        call    edx
        popfd
        mov     [esp + 28], eax
        popad
        or      eax, eax
        jnz     @f ; RET
        mov     [esi + app_data_t.wait_test], edx
        mov     [esi + app_data_t.wait_timeout], ebx
        Mov     [esi + app_data_t.wait_begin], eax, [timer_ticks]
        mov     eax, [TASK_BASE]
        mov     [eax + task_data_t.state], 5
        call    change_task
        mov     eax, [esi + app_data_t.wait_param]

    @@: ret

align 4
wait_event: ;; EXPORT use
        ; info:
        ;    Ожидание флага EVENT_SIGNALED в совершенно конкретном Event
        ;    (устанавливаемого, надо полагать, через raise_event)
        ;    При активном флаге MANUAL_RESET - больше ничего
        ;    Иначе: флаги EVENT_SIGNALED и EVENT_WATCHED у полученного события сбрасываются,
        ;    и, при активном MANUAL_DESTROY - перемещается в список ObjList текущего слота,
        ;    а при не активном - уничтожается штатно (destroy_event.internal)
        ; param:
        ;    eax - event
        ;    ebx - uid (for Dummy testing)
        ; scratched: ecx,edx,esi

        call    DummyTest
        mov     ecx, eax ; wait_param
        mov     edx, get_event_alone ; wait_test
        call    Wait_events ; timeout ignored
        jmp     wait_finish

align 4
get_event_ex: ;; f68:14
        ; info:
        ;    Ожидание любого события в очереди EventList текущего слота
        ;    Данные события code - копируются в память приложения (косвенно по edi)
        ;    При активном флаге MANUAL_RESET - больше ничего
        ;    Иначе: флаги EVENT_SIGNALED и EVENT_WATCHED у полученного события сбрасываются,
        ;    и, при активном MANUAL_DESTROY - перемещается в список ObjList текущего слота,
        ;    а при не активном - уничтожается штатно (destroy_event.internal)
        ; param:
        ;    edi - адрес в коде приложения для копирования данных из event_t.code
        ; retval:
        ;    eax - собственно event_t (будем называть это его хэндлом)
        ; scratched: ebx,ecx,edx,esi,edi

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
        add     ebx, APP_OBJ_OFFSET
        pushfd
        cli
        jmp     RemoveEventTo

align 4
destroy_event: ;; EXPORT use
        ; info:
        ;    Переносим event_t в список FreeEvents, чистим поля magic,destroy,pid,id
        ; param:
        ;    eax - event
        ;    ebx - uid (for Dummy testing)
        ; retval:
        ;    eax - адрес объекта event_t (=0 => fail)
        ; scratched: ebx,ecx

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

align 4
get_event_queue:
        ; info:
        ;    клиентская ф-я тестирования для get_event_ex
        ; warning:
        ;   -don't use [TASK_BASE],[current_slot],[CURRENT_TASK] - it is not for your slot
        ;   -may be assumed, that interrupt are disabled
        ;   -it is not restriction for scratched registers
        ; param:
        ;    ebx - адрес app_data_t слота тестирования
        ; retval:
        ;    eax - адрес объекта event_t (=0 => fail)

        add     ebx, APP_EV_OFFSET
        mov     eax, [ebx + app_object_t.prev_ptr] ; выбираем с конца, по принципу FIFO
        cmp     eax, ebx ; empty ???
        je      get_event_alone.ret0

  .ret:
        ret

align 4
get_event_alone:
        ; info:
        ;    клиентская ф-я тестирования для wait_event
        ; warning:
        ;   -don't use [TASK_BASE],[current_slot],[CURRENT_TASK] - it is not for your slot
        ;   -may be assumed, that interrupt are disabled
        ;   -it is not restriction for scratched registers
        ; param:
        ;    ebx - адрес app_data_t слота тестирования
        ; retval:
        ;    eax - адрес объекта event_t (=0 => fail)

        mov     eax, [ebx + app_data_t.wait_param]
        test    byte[eax + event_t.state + 3], EVENT_SIGNALED shr 24
        jnz     .ret
        or      byte[eax + event_t.state + 3], EVENT_WATCHED shr 24

  .ret0:
        xor     eax, eax ; NO event!!!

  .ret:
        ret

align 4
sys_sendwindowmsg: ;; f72
        dec     ebx
        jnz     .ret ; subfunction==1 ?
;       pushfd  ; а нафига?
        cli
        sub     ecx, 2
        je      .sendkey
        dec     ecx
        jnz     .retf

  .sendbtn:
        cmp     byte[BTN_COUNT], 1
        jae     .result ; overflow
        inc     byte[BTN_COUNT]
        shl     edx, 8
        mov     [BTN_BUFF], edx
        jmp     .result

  .sendkey:
        movzx   eax, byte[KEY_COUNT]
        cmp     al, 120
        jae     .result ; overflow
        inc     byte[KEY_COUNT]
        mov     [KEY_COUNT + 1 + eax], dl

  .result:
        setae   byte[esp + 32] ; считаем, что исходно: dword[esp+32]==72

  .retf:
;       popfd

  .ret:
        ret

align 4
sys_getevent: ;; f11
        mov     ebx, [current_slot] ; пока это вопрос, чего куды сувать..........
        pushfd  ; это следствие общей концепции: пусть ф-я тестирования имеет
        cli     ; право рассчитывать на закрытые прерывания, как при вызове из shed
        call    get_event_for_app
        popfd
        mov     [esp + 32], eax
        ret

align 4
sys_waitforevent: ;; f10
        or      ebx, -1 ; infinite timeout

sys_wait_event_timeout: ;; f23
        mov     edx, get_event_for_app ; wait_test
        call    Wait_events_ex ; ebx - timeout
        mov     [esp + 32], eax
        ret

align 4
get_event_for_app: ;; used from f10,f11,f23
        ; info:
        ;    клиентская ф-я тестирования для приложений (f10,f23)
        ; warning:
        ;   -don't use [TASK_BASE],[current_slot],[CURRENT_TASK] - it is not for your slot
        ;   -may be assumed, that interrupt are disabled
        ;   -it is not restriction for scratched registers
        ; param:
        ;    ebx - адрес app_data_t слота тестирования
        ; retval:
        ;    eax - номер события (=0 => no events)

        movzx   edi, bh ; bh  is assumed as [CURRENT_TASK]
        shl     edi, 5
        add     edi, CURRENT_TASK ; edi is assumed as [TASK_BASE]
        mov     ecx, [edi + task_data_t.event_mask]

  .loop:
        ; пока не исчерпаем все биты маски
        bsr     eax, ecx ; находим ненулевой бит маски (31 -> 0)
        jz      .no_events ; исчерпали все биты маски, но ничего не нашли ???
        btr     ecx, eax ; сбрасываем проверяемый бит маски
        ; переходим на обработчик этого (eax) бита
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
        ; TODO: сделать так же, как и для FlagAutoReset (BgrRedraw,Mouse,IPC,Stack,Debug)
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
        movzx   edx, word[WIN_STACK + edx * 2]
        je      .Keys ; eax=1, retval Keys=2

  .Buttons:
        ; eax=2, retval Buttons=3
        cmp     byte[BTN_COUNT], 0
        je      .loop ; empty ???
        cmp     edx, [TASK_COUNT]
        jne     .loop ; not Top ???
        mov     edx, [BTN_BUFF]
        shr     edx, 8
        cmp     edx, 0xffff ; -ID for Minimize-Button of Form
        jne     .result
        mov     [window_minimize], 1
        dec     byte[BTN_COUNT]
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
