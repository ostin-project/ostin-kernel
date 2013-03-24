;;======================================================================================================================
;;///// thread.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

THREAD_FLAG_VALID = 0x01

struct core.thread_events_t
  event_mask    dd ?
  queued_events dd ? ; legacy.slot_t.app.event_mask
  list          linked_list_t
  wait_timeout  dq ?
  wait_test     dd ?
  wait_param    dd ?
ends

struct core.thread_stats_t
  counter_sum dd ?
  counter_add dd ?
  cpu_usage   dd ?
ends

struct core.thread_debug_regs_t
  dr0 dd ?
  dr1 dd ?
  dr2 dd ?
  dr3 dd ?
  dr7 dd ?
ends

struct core.thread_debug_t
  debugger_slot dd ?
  state         dd ?
  event_mem     dd ?
  regs          core.thread_debug_regs_t
ends

struct core.thread_t rb_tree_node_t
  id            dd ?
  flags         dd ?
  process_ptr   dd ? ; ^= core.process_t
  window_ptr    dd ? ; ^= gui.window_t
  siblings      linked_list_t
  ipc_range     memory_range32_t
  state         db ?
  keyboard_mode db ?
                rb 2
  events        core.thread_events_t
  stats         core.thread_stats_t
  saved_esp     dd ?
  saved_esp0    dd ?
  pl0_stack     dd ?
  fpu_state     dd ?
  except_mask   dd ?
  exc_handler   dd ?
  cur_dir       dd ?
  tls_base      dd ?
  io_map        rd 2
  dir_table     dd ?
  debug         core.thread_debug_t
ends

assert sizeof.core.thread_t mod 4 = 0

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.alloc ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= parent core.process_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= [invalid] core.thread_t or 0
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        ; allocate memory for thread structure
        mov     eax, sizeof.core.thread_t
        call    malloc
        or      eax, eax
        jz      .exit

        push    eax

        ; zero-initialize allocated memory
        xchg    eax, edi
        xor     eax, eax
        mov     ecx, sizeof.core.thread_t / 4
        rep
        stosd

        call    core.thread._.lock_tree

        mov     eax, [esp]
        call    core.thread._.initialize

        mov     ecx, [esp + 4]
        mov     [eax + core.thread_t.process_ptr], ecx
        add     ecx, core.process_t.threads
        call    core.thread._.add_to_siblings_list

        call    core.thread._.unlock_tree

        pop     eax

        KLog    LOG_DEBUG, "thread #%u allocated\n", [eax + core.thread_t.id]

  .exit:
        add     esp, 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.free ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        KLog    LOG_DEBUG, "thread #%u freed\n", [eax + core.thread_t.id]

        call    core.thread._.lock_tree

        call    core.thread._.remove_from_siblings_list

        ; remove thread from the tree
        call    util.rb_tree.remove
        mov     [core.thread._.tree_root], eax

        ; free used memory
        mov     eax, [esp]
        call    free

        call    core.thread._.unlock_tree

        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.find_by_id ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= thread ID to find
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= core.thread_t or 0
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx edx eax

        call    core.thread._.lock_tree

        mov     eax, [esp]
        mov     ebx, [core.thread._.tree_root]
        mov     ecx, .compare_id
        call    util.b_tree.find
        xchg    eax, [esp]

        call    core.thread._.unlock_tree

        pop     eax edx ecx ebx
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .compare_id: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= thread ID to find
;> ebx ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, [ebx + core.thread_t.id]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.enumerate ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx ^= callback, f(eax)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx

        call    core.thread._.lock_tree

        pop     edx
        mov     ebx, [core.thread._.tree_root]
        mov     ecx, .check_valid_and_call_back
        call    util.b_tree.enumerate

        call    core.thread._.unlock_tree

        ret

;-----------------------------------------------------------------------------------------------------------------------
  .check_valid_and_call_back: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        test    [eax + core.thread_t.flags], THREAD_FLAG_VALID
        jz      @f

        jmp     edx

    @@: xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.compat.find_by_slot ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= legacy.slot_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax + legacy.slot_t.task.new_pid]
        call    core.thread.find_by_id
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.compat.init_with_slot ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;> ebx ^= legacy.slot_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx
        mov     cl, [ebx + legacy.slot_t.app.keyboard_mode]
        mov     [eax + core.thread_t.keyboard_mode], cl

        MovStk  [eax + core.thread_t.events.list.prev_ptr], [ebx + legacy.slot_t.app.ev.prev_ptr]
        MovStk  [eax + core.thread_t.events.list.next_ptr], [ebx + legacy.slot_t.app.ev.next_ptr]
        MovStk  [eax + core.thread_t.saved_esp], [ebx + legacy.slot_t.app.saved_esp]
        MovStk  [eax + core.thread_t.saved_esp0], [ebx + legacy.slot_t.app.saved_esp0]
        MovStk  [eax + core.thread_t.pl0_stack], [ebx + legacy.slot_t.app.pl0_stack]
        MovStk  [eax + core.thread_t.fpu_state], [ebx + legacy.slot_t.app.fpu_state]
        MovStk  [eax + core.thread_t.except_mask], [ebx + legacy.slot_t.app.except_mask]
        MovStk  [eax + core.thread_t.exc_handler], [ebx + legacy.slot_t.app.exc_handler]
        MovStk  [eax + core.thread_t.cur_dir], [ebx + legacy.slot_t.app.cur_dir]
        MovStk  [eax + core.thread_t.tls_base], [ebx + legacy.slot_t.app.tls_base]
        MovStk  [eax + core.thread_t.io_map], [ebx + legacy.slot_t.app.io_map]
        MovStk  [eax + core.thread_t.io_map + 4], [ebx + legacy.slot_t.app.io_map + 4]
        MovStk  [eax + core.thread_t.debug.debugger_slot], [ebx + legacy.slot_t.app.debugger_slot]

        mov     cl, [ebx + legacy.slot_t.task.state]
        mov     [eax + core.thread_t.state], cl

        MovStk  [eax + core.thread_t.events.event_mask], [ebx + legacy.slot_t.task.event_mask]

        MovStk  [ebx + legacy.slot_t.task.new_pid], [eax + core.thread_t.id]

  .exit:
        pop     ecx ebx eax
        ret
kendp

uglobal
  core.thread._.tree_root  dd ?
  core.thread._.tree_mutex mutex_t
  core.thread._.last_id    dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread._.lock_tree ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; FIXME: could lead to recursion in `find_next_task`, hot fix until scheduling is refactored
;       push    eax ecx edx
;       mov     ecx, core.thread._.tree_mutex
;       call    mutex_lock
;       pop     edx ecx eax
        pushfd
        pop     dword[core.thread._.tree_mutex]
        cli
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread._.unlock_tree ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; FIXME: could lead to recursion in `find_next_task`, hot fix until scheduling is refactored
;       push    eax ecx edx
;       mov     ecx, core.thread._.tree_mutex
;       call    mutex_unlock
;       pop     edx ecx eax
        push    dword[core.thread._.tree_mutex]
        popfd
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread._.initialize ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        ; enumerate tree to calculate unused thread ID
        mov     ebx, [core.thread._.tree_root]
        mov     ecx, .check_used_id
        mov     edx, [core.thread._.last_id]
        inc     edx
        jnz     @f

        inc     dl

    @@: call    util.b_tree.enumerate
        ; we're optimistic here and hope we always find a free ID to use, hence no enumeration result check

        ; set thread ID to acquired one
        mov     eax, [esp]
        mov     [eax + core.thread_t.id], edx
        mov     [core.thread._.last_id], edx

        ; add thread to the tree
        mov     ebx, [core.thread._.tree_root]
        mov     ecx, .compare_id
        call    util.rb_tree.insert
        mov     [core.thread._.tree_root], eax

        pop     eax
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .check_used_id: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edx, [eax + core.thread_t.id]
        jb      .interrupt_search
        jne     @f

        inc     edx

    @@: xor     eax, eax

  .interrupt_search:
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .compare_id: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= first core.thread_t
;> ebx ^= second core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [eax + core.thread_t.id]
        cmp     eax, [ebx + core.thread_t.id]
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread._.add_to_siblings_list ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;> ecx ^= linked_list_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx
        add     eax, core.thread_t.siblings

        push    [ecx + linked_list_t.next_ptr]
        mov     [ecx + linked_list_t.next_ptr], eax
        mov     [eax + linked_list_t.prev_ptr], ecx
        pop     ecx
        mov     [ecx + linked_list_t.prev_ptr], eax
        mov     [eax + linked_list_t.next_ptr], ecx

        pop     ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread._.remove_from_siblings_list ;/////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx
        add     eax, core.thread_t.siblings

        mov     ecx, [eax + linked_list_t.prev_ptr]
        MovStk  [ecx + linked_list_t.next_ptr], [eax + linked_list_t.next_ptr]
        mov     ecx, [eax + linked_list_t.next_ptr]
        MovStk  [ecx + linked_list_t.prev_ptr], [eax + linked_list_t.prev_ptr]

        pop     ecx eax
        ret
kendp
