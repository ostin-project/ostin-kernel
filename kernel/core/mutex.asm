;;======================================================================================================================
;;///// mutex.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2010 KolibriOS team <http://kolibrios.org/>
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

struct mutex_t linked_list_t
  count dd ?
ends

struct mutex_waiter_t linked_list_t
  task dd ?
ends

;-----------------------------------------------------------------------------------------------------------------------
kproc mutex_init ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# void  __fastcall mutex_init(struct mutex* lock)
;-----------------------------------------------------------------------------------------------------------------------
        mov     [ecx + mutex_t.next_ptr], ecx
        mov     [ecx + mutex_t.prev_ptr], ecx
        mov     [ecx + mutex_t.count], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc mutex_lock ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# void  __fastcall mutex_lock(struct mutex* lock)
;-----------------------------------------------------------------------------------------------------------------------
        dec     [ecx + mutex_t.count]
        jns     .done

        pushfd
        cli

        sub     esp, sizeof.mutex_waiter_t

        list_add_tail esp, ecx ; esp = new waiter, ecx = list head

        mov     edx, [current_slot_ptr]
        mov     [esp + mutex_waiter_t.task], edx

  .forever:
        mov     eax, -1
        xchg    eax, [ecx + mutex_t.count]
        dec     eax
        jz      @f

        mov     [edx + legacy.slot_t.task.state], THREAD_STATE_RUN_SUSPENDED
        call    change_task
        jmp     .forever

    @@: mov     edx, [esp + mutex_waiter_t.next_ptr]
        mov     eax, [esp + mutex_waiter_t.prev_ptr]

        mov     [eax + mutex_waiter_t.next_ptr], edx
        mov     [edx + mutex_waiter_t.prev_ptr], eax
        cmp     [ecx + mutex_t.next_ptr], ecx
        jne     @f

        mov     [ecx + mutex_t.count], 0

    @@: add     esp, sizeof.mutex_waiter_t

        popfd

  .done:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc mutex_unlock ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# void  __fastcall mutex_unlock(struct mutex* lock)
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli

        mov     eax, [ecx + mutex_t.next_ptr]
        cmp     eax, ecx
        mov     [ecx + mutex_t.count], 1
        je      @f

        mov     eax, [eax + mutex_waiter_t.task]
        mov     [eax + legacy.slot_t.task.state], THREAD_STATE_RUNNING

    @@: popfd
        ret
kendp
