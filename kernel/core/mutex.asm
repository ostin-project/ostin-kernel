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

struct mutex_t
  count dd ?
  next  dd ?
  prev  dd ?
ends

struct mutex_waiter_t
  next dd ?
  prev dd ?
  task dd ?
ends

; void  __fastcall mutex_init(struct mutex *lock)
align 4
mutex_init:
        lea     eax, [ecx + mutex_t.next]
        mov     [ecx + mutex_t.count], 1
        mov     [ecx + mutex_t.next], eax
        mov     [ecx + mutex_t.prev], eax
        ret


; void  __fastcall mutex_lock(struct mutex *lock)
align 4
mutex_lock:
        dec     [ecx + mutex_t.count]
        jns     .done

        pushfd
        cli

        push    esi
        sub     esp, sizeof.mutex_waiter_t

        mov     eax, [ecx + mutex_t.prev]
        lea     esi, [ecx + mutex_t.next]

        mov     [ecx + mutex_t.prev], esp
        mov     [esp + mutex_waiter_t.next], esi
        mov     [esp + mutex_waiter_t.prev], eax
        mov     [eax], esp

        mov     edx, [TASK_BASE]
        mov     [esp + mutex_waiter_t.task], edx

  .forever:
        mov     eax, -1
        xchg    eax, [ecx + mutex_t.count]
        dec     eax
        jz      @f

        mov     [edx + task_data_t.state], 1
        call    change_task
        jmp     .forever

    @@: mov     edx, [esp + mutex_waiter_t.next]
        mov     eax, [esp + mutex_waiter_t.prev]

        mov     [eax + mutex_waiter_t.next], edx
        cmp     [ecx + mutex_t.next], esi
        mov     [edx + mutex_waiter_t.prev], eax
        jne     @f

        mov     [ecx + mutex_t.count], 0

    @@: add     esp, sizeof.mutex_waiter_t

        pop     esi
        popfd

  .done:
        ret

; void  __fastcall mutex_unlock(struct mutex *lock)
align 4
mutex_unlock:
        pushfd
        cli

        lea     eax, [ecx + mutex_t.next]
        cmp     eax, [ecx + mutex_t.next]
        mov     [ecx + mutex_t.count], 1
        je      @f

        mov     eax, [eax + mutex_waiter_t.task]
        mov     [eax + task_data_t.state], 0

    @@: popfd
        ret
