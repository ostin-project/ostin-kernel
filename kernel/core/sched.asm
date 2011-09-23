;;======================================================================================================================
;;///// sched.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

include "mutex.asm"

uglobal
  align 4
  current_slot rd 1
  DONT_SWITCH  db ?
endg

align 32
;-----------------------------------------------------------------------------------------------------------------------
kproc irq0 ;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? IRQ0 HANDLER (TIMER INTERRUPT)
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        Mov     ds, ax, app_data
        mov     es, ax
        inc     [timer_ticks]
        mov     eax, [timer_ticks]
        call    playNote ; <<<--- Speaker driver
        sub     eax, [next_usage_update]
        cmp     eax, 100
        jb      .nocounter
        add     [next_usage_update], 100
        call    updatecputimes

  .nocounter:
        mov     al, 0x20 ; send End Of Interrupt signal
        out     0x20, al
        btr     dword[DONT_SWITCH], 0
        jc      .return
        call    find_next_task
        jz      .return  ; if there is only one running process
        call    do_change_task

  .return:
        popad
        iretd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc change_task ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli
        pushad

if 0

        ; <- must be refractoried, if used...
        cmp     [dma_task_switched], 1
        jne     .find_next_task
        mov     [dma_task_switched], 0
        mov     ebx, [dma_process]
        cmp     [CURRENT_TASK], ebx
        je      .return
        mov     edi, [dma_slot_ptr]
        mov     [CURRENT_TASK], ebx
        mov     [TASK_BASE], edi
        jmp     @f

  .find_next_task:

end if

        call    find_next_task
        jz      .return ; the same task -> skip switch

    @@: mov     [DONT_SWITCH], 1
        call    do_change_task

  .return:
        popad
        popfd
        ret
kendp

uglobal
align 4
; far_jump:
;   .offs dd ?
;   .sel  dw ?
  context_counter   dd 0
  next_usage_update dd 0
  timer_ticks       dd 0
; prev_slot         dd ?
; event_sched       dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc update_counters ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [TASK_BASE]
        rdtsc
        sub     eax, [edi + task_data_t.counter_add] ; time stamp counter add
        add     [edi + task_data_t.counter_sum], eax ; counter sum
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc updatecputimes ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        xchg    eax, [idleuse]
        mov     [idleusesec], eax
        mov     ecx, [TASK_COUNT]
        mov     edi, TASK_DATA

  .newupdate:
        xor     eax, eax
        xchg    eax, [edi + task_data_t.counter_sum]
        mov     [edi + task_data_t.cpu_usage], eax
        add     edi, sizeof.task_data_t
        loop    .newupdate
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc find_next_task ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Find next task to execute
;-----------------------------------------------------------------------------------------------------------------------
;< ebx = address of the app_data_t for the selected task (slot-base)
;< esi = previous slot-base ([current_slot] at the begin)
;< edi = address of the task_data_t for the selected task
;< ZF = 1 if the task is the same
;-----------------------------------------------------------------------------------------------------------------------
; warning:
;   [CURRENT_TASK] = bh, [TASK_BASE] = edi -- as result
;   [current_slot] is not set to new value (ebx)!!!
; scratched: eax,ecx
;-----------------------------------------------------------------------------------------------------------------------
        call    update_counters ; edi := [TASK_BASE]
        Mov     esi, ebx, [current_slot]

  .loop:
        cmp     bh, byte[TASK_COUNT]
        jb      @f
        xor     bh, bh
        mov     edi, TASK_DATA - sizeof.task_data_t

    @@: inc     bh ; ebx += app_data_t.size
        add     edi, sizeof.task_data_t ; edi += sizeof.task_data_t
        mov     al, [edi + task_data_t.state]
        test    al, al ; TSTATE_RUNNING
        jz      .found ; state == 0
        cmp     al, TSTATE_WAITING
        jne     .loop ; state == 1,2,3,4,9
        ; state == 5
        pushad  ; more freedom for [app_data_t.wait_test]
        call    [ebx + app_data_t.wait_test]
        mov     [esp + regs_context32_t.eax], eax
        popad
        or      eax, eax
        jnz     @f
        ; testing for timeout
        mov     ecx, [timer_ticks]
        sub     ecx, [ebx + app_data_t.wait_begin]
        cmp     ecx, [ebx + app_data_t.wait_timeout]
        jb      .loop

    @@: mov     [ebx + app_data_t.wait_param], eax ; retval for wait
        mov     [edi + task_data_t.state], TSTATE_RUNNING

  .found:
        mov     byte[CURRENT_TASK], bh
        mov     [TASK_BASE], edi
;       call    _rdtsc
        rdtsc
        mov     [edi + task_data_t.counter_add], eax ; for next using update_counters
        cmp     ebx, esi ; esi - previous slot-base
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc do_change_task ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = address of the app_data_t for incoming task (new)
;-----------------------------------------------------------------------------------------------------------------------
;# warning:
;#   [CURRENT_TASK] and [TASK_BASE] must be changed before (e.g. in find_next_task)
;#   [current_slot] is the outcoming (old), and set here to a new value (ebx)
;# scratched: eax,ecx,esi
;# TODO: Eliminate use of do_change_task in V86 and then move task_data_t.counter_add/sum handling to do_change_task
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, ebx
        xchg    esi, [current_slot]
        ; set new stack after saving old
        mov     [esi + app_data_t.saved_esp], esp
        mov     esp, [ebx + app_data_t.saved_esp]
        ; set new thread io-map
        Mov     dword[page_tabs + ((tss.io_map_0 and -4096) shr 10)], eax, [ebx + app_data_t.io_map]
        Mov     dword[page_tabs + ((tss.io_map_1 and -4096) shr 10)], eax, [ebx + app_data_t.io_map + 4]
        ; set new thread memory-map
        mov     ecx, app_data_t.dir_table
        mov     eax, [ebx + ecx] ; offset>0x7F
        cmp     eax, [esi + ecx] ; offset>0x7F
        je      @f
        mov     cr3, eax

    @@: ; set tss.esp0
        Mov     [tss.esp0], eax, [ebx + app_data_t.saved_esp0]

        mov     edx, [ebx + app_data_t.tls_base]
        cmp     edx, [esi + app_data_t.tls_base]
        je      @f

        mov     [tls_data_l + 2], dx
        shr     edx, 16
        mov     [tls_data_l + 4], dl
        mov     [tls_data_l + 7], dh

        mov     dx, app_tls
        mov     fs, dx

    @@: ; set gs selector unconditionally
        Mov     gs, ax, graph_data
        ; set CR0.TS
        cmp     bh, byte[fpu_owner] ; bh == incoming task (new)
        clts    ; clear a task switch flag
        je      @f
        mov     eax, cr0 ; and set it again if the owner of a fpu has changed
        or      eax, CR0_TS
        mov     cr0, eax

    @@: ; set context_counter (only for user pleasure ???)
        inc     [context_counter]
        ; set debug-registers, if it's necessary
        test    byte[ebx + app_data_t.dbg_state], 1
        jz      @f
        xor     eax, eax
        mov     dr6, eax
        lea     esi, [ebx + ecx + app_data_t.dbg_regs - app_data_t.dir_table] ; offset>0x7F
        cld

macro lodsReg [reg]
{
        lodsd
        mov     reg, eax
}

        lodsReg dr0, dr1, dr2, dr3, dr7

purge lodsReg

    @@: ret
kendp

if 0

; unused
;struct timer_t
;  next     dd ?
;  exp_time dd ?
;  func     dd ?
;  arg      dd ?
;ends

MAX_PROIRITY      = 0 ; highest, used for kernel tasks
MAX_USER_PRIORITY = 0 ; highest priority for user processes
USER_PRIORITY     = 7 ; default (should correspond to nice 0)
MIN_USER_PRIORITY = 14 ; minimum priority for user processes
IDLE_PRIORITY     = 15 ; lowest, only IDLE process goes here
NR_SCHED_QUEUES   = 16 ; MUST equal IDLE_PRIORYTY + 1

uglobal
  rdy_head rd 16
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc pick_task ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax

  .pick:
        mov     ebx, [rdy_head + eax * 4]
        test    ebx, ebx
        jz      .next

        mov     [next_task], ebx
        test    [ebx + flags.billable]
        jz      @f
        mov     [bill_task], ebx

    @@: ret

  .next:
        inc     eax
        jmp     .pick
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc shed ;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = task
;-----------------------------------------------------------------------------------------------------------------------
;< eax = task
;< ebx = queue
;< ecx = front if 1 or back if 0
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [eax + .tics_left], 0 ; signed compare
        mov     ebx, [eax + .priority]
        setg    ecx
        jg      @f

        mov     edx, [eax + .tics_quantum]
        mov     [eax + .ticks_left], edx
        cmp     ebx, IDLE_PRIORITY - 1
        je      @f
        inc     ebx

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc enqueue ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = task
;-----------------------------------------------------------------------------------------------------------------------
        call    shed  ; eax
        cmp     [rdy_head + ebx * 4], 0
        jnz     @f

        mov     [rdy_head + ebx * 4], eax
        mov     [rdy_tail + ebx * 4], eax
        mov     [eax + .next_ready], 0
        jmp     .pick

    @@: test    ecx, ecx
        jz      .back

        mov     ecx, [rdy_head + ebx * 4]
        mov     [eax + .next_ready], ecx
        mov     [rdy_head + ebx * 4], eax
        jmp     .pick

  .back:
        mov     ecx, [rdy_tail + ebx * 4]
        mov     [ecx + .next_ready], eax
        mov     [rdy_tail + ebx * 4], eax
        mov     [eax + .next_ready], 0

  .pick:
        call    pick_proc ; select next task
        ret
kendp

end if
