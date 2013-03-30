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
  current_slot dd ?
  current_slot_ptr dd ?
  current_thread_ptr dd ?
  current_process_ptr dd ?
  DONT_SWITCH db ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc get_timer_ticks ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, dword[timer_ticks]
        ret
kendp

align 32
;-----------------------------------------------------------------------------------------------------------------------
kproc irq0 ;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? IRQ0 HANDLER (TIMER INTERRUPT)
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        Mov3    ds, ax, app_data
        mov     es, ax
        cld
        add     dword[timer_ticks], 1
        adc     dword[timer_ticks + 4], 0
        mov     eax, dword[timer_ticks]
        call    playNote ; <<<--- Speaker driver
        sub     eax, [next_usage_update]
        cmp     eax, 1 * KCONFIG_SYS_TIMER_FREQ
        jb      .nocounter
        add     [next_usage_update], 1 * KCONFIG_SYS_TIMER_FREQ
        call    updatecputimes

  .nocounter:
        xor     ecx, ecx
        call    irq_eoi

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
        cmp     [current_slot], ebx
        je      .return
        mov     edi, [dma_slot_ptr]
        mov     [current_slot], ebx
        mov     [current_slot_ptr], edi
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
; far_jump:
;   .offs dd ?
;   .sel  dw ?
  context_counter   dd 0
  next_usage_update dd 0
  timer_ticks       dq ?
; prev_slot         dd ?
; event_sched       dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc update_counters ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [current_thread_ptr]
        test    edi, edi
        jz      .exit

        rdtsc
        sub     eax, [edi + core.thread_t.stats.counter_add]
        add     [edi + core.thread_t.stats.counter_sum], eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc updatecputimes ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        xchg    eax, [idleuse]
        mov     [idleusesec], eax

        mov     ecx, .update_cpu_usage
        call    core.thread.enumerate
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .update_cpu_usage: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        xor     edi, edi
        xchg    edi, [eax + core.thread_t.stats.counter_sum]
        mov     [eax + core.thread_t.stats.cpu_usage], edi
        xor     eax, eax
        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc find_next_task ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Find next task to execute
;-----------------------------------------------------------------------------------------------------------------------
;< ebx = address of the legacy.slot_t for the selected task (slot-base)
;< esi = previous slot-base ([current_slot_ptr] at the begin)
;< edi = address of the legacy.slot_t for the selected task
;< ZF = 1 if the task is the same
;-----------------------------------------------------------------------------------------------------------------------
; warning:
;   [current_slot] = new slot number as result
;   [current_slot_ptr] is not set to new value!!!
; scratched: eax,ecx
;-----------------------------------------------------------------------------------------------------------------------
        call    update_counters
        mov     edi, [current_slot]
        Mov3    esi, ebx, [current_slot_ptr]

  .loop:
        cmp     edi, [legacy_slots.last_valid_slot]
        jb      @f
        xor     edi, edi
        mov     ebx, legacy_slots

    @@: inc     edi
        add     ebx, sizeof.legacy.slot_t
        mov     al, [ebx + legacy.slot_t.task.state]
        test    al, al ; THREAD_STATE_RUNNING
        jz      .found ; state == 0
        cmp     al, THREAD_STATE_WAITING
        jne     .loop ; state == 1,2,3,4,9
        ; state == 5
        pushad  ; more freedom for wait_test
        call    [ebx + legacy.slot_t.app.wait_test]
        mov     [esp + regs_context32_t.eax], eax
        popad
        or      eax, eax
        jnz     @f

        ; testing for timeout
        push    eax edx
        mov     eax, dword[timer_ticks]
        mov     edx, dword[timer_ticks + 4]
        push    dword[ebx + legacy.slot_t.app.wait_timeout + 4] dword[ebx + legacy.slot_t.app.wait_timeout]
        call    util.64bit.compare
        pop     edx eax
        jb      .loop

    @@: mov     [ebx + legacy.slot_t.app.wait_param], eax ; retval for wait
        mov     [ebx + legacy.slot_t.task.state], THREAD_STATE_RUNNING

  .found:
        mov     [current_slot], edi

        pushad

        mov     eax, ebx
        call    core.thread.compat.find_by_slot
        mov     [current_thread_ptr], eax
        test    eax, eax
        jz      @f

        mov     eax, [eax + core.thread_t.process_ptr]

    @@: mov     [current_process_ptr], eax
        popad

        mov     ecx, [current_thread_ptr]
        test    ecx, ecx
        jz      .exit

;       call    _rdtsc
        rdtsc
        mov     [ecx + core.thread_t.stats.counter_add], eax ; for next using update_counters

  .exit:
        mov     edi, ebx
        cmp     ebx, esi ; esi - previous slot-base
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc do_change_task ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = address of the legacy.slot_t for incoming task (new)
;-----------------------------------------------------------------------------------------------------------------------
;# warning:
;#   [current_slot] must be changed before (e.g. in find_next_task)
;#   [current_slot_ptr] is the outcoming (old), and set here to a new value (ebx)
;# scratched: eax,ecx,esi
;# TODO: Eliminate use of do_change_task in V86 and then move legacy.slot_t.task.counter_add/sum handling to
;#       do_change_task
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, ebx
        xchg    esi, [current_slot_ptr]
        ; set new stack after saving old
        mov     [esi + legacy.slot_t.app.saved_esp], esp
        mov     esp, [ebx + legacy.slot_t.app.saved_esp]
        ; set new thread io-map
        Mov3    dword[page_tabs + ((tss.io_map_0 and -4096) shr 10)], eax, [ebx + legacy.slot_t.app.io_map]
        Mov3    dword[page_tabs + ((tss.io_map_1 and -4096) shr 10)], eax, [ebx + legacy.slot_t.app.io_map + 4]
        ; set new thread memory-map
        mov     ecx, legacy.slot_t.app.dir_table
        mov     eax, [ebx + ecx] ; offset>0x7F
        cmp     eax, [esi + ecx] ; offset>0x7F
        je      @f
        mov     cr3, eax

    @@: ; set tss.esp0
        Mov3    [tss.esp0], eax, [ebx + legacy.slot_t.app.saved_esp0]

        mov     edx, [ebx + legacy.slot_t.app.tls_base]
        cmp     edx, [esi + legacy.slot_t.app.tls_base]
        je      @f

        mov     [gdts.tls_data.base_low], dx
        shr     edx, 16
        mov     [gdts.tls_data.base_mid], dl
        mov     [gdts.tls_data.base_high], dh

        mov     dx, app_tls
        mov     fs, dx

    @@: ; set gs selector unconditionally
        Mov3    gs, ax, graph_data
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
        test    byte[ebx + legacy.slot_t.app.dbg_state], 1
        jz      @f
        xor     eax, eax
        mov     dr6, eax
        lea     esi, [ebx + legacy.slot_t.app.dbg_regs] ; offset>0x7F

macro LodsReg [_reg]
{
        lodsd
        mov     _reg, eax
}

        LodsReg dr0, dr1, dr2, dr3, dr7

purge LodsReg

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
