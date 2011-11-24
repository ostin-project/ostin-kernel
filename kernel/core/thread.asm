;;======================================================================================================================
;;///// task.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

THREAD_FLAG_VALID   = 0x01
THREAD_FLAG_PROCESS = 0x02

struct core.thread_events_t
  event_mask    dd ?
  queued_events dd ? ; app_data_t.event_mask
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

struct core.thread_t rb_tree_node_t
  id            dd ?
  parent_id     dd ?
  flags         dd ?
  heap_range    memory_range32_t ; app_data_t.heap_base, app_data_t.heap_top
  ipc_range     memory_range32_t ; app_data_t.ipc
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
  debugger_slot dd ?
  dbg_state     dd ?
  dbg_event_mem dd ?
  dbg_regs      core.thread_debug_regs_t
ends

static_assert sizeof.core.thread_t mod 4 = 0

struct core.process_t core.thread_t
  app_name      rb 11
                rb 5
  mem_range     memory_range32_t ; task_data_t.mem_start, app_data_t.mem_size
  dir_table     dd ?
  dlls_list_ptr dd ?
  obj           linked_list_t
ends

static_assert sizeof.core.process_t mod 4 = 0

struct gui.window_t
  box             box32_t
  wnd_clientbox   box32_t
  saved_box       box32_t
  union
    cl_workarea   dd ?
    struct
                  rb 3
      fl_wstyle   db ?
    ends
  ends
  cl_titlebar     dd ?
  cl_frames       dd ?
  reserved        db ?
  fl_wstate       db ?
  fl_wdrawn       db ?
  fl_redraw       db ?
  wnd_shape       dd ?
  wnd_shape_scale dd ?
  wnd_caption     dd ? ; ^= char*
  cursor          dd ? ; ^= cursor_t
  wnd_number      db ?
                  rb 3
ends

static_assert sizeof.gui.window_t mod 4 = 0

uglobal
  core.thread.tree_root  dd ?
  core.thread.tree_mutex mutex_t
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.create ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= [invalid] core.process_t or 0
;-----------------------------------------------------------------------------------------------------------------------
        ; allocate memory for process structure
        mov     eax, sizeof.core.process_t
        call    malloc
        or      eax, eax
        jz      .exit

        ; zero-initialize allocated memory
        push    eax
        xchg    eax, edi
        xor     eax, eax
        mov     ecx, sizeof.core.process_t / 4
        rep     stosd
        pop     eax

        call    core.thread._.initialize

        ; mark this thread as process
        or      [eax + core.process_t.flags], THREAD_FLAG_PROCESS

        klog_   LOG_DEBUG, "process #%u created\n", [eax + core.thread_t.id]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.create ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= [invalid] core.thread_t or 0
;-----------------------------------------------------------------------------------------------------------------------
        ; allocate memory for thread structure
        mov     eax, sizeof.core.thread_t
        call    malloc
        or      eax, eax
        jz      .exit

        ; zero-initialize allocated memory
        push    eax
        xchg    eax, edi
        xor     eax, eax
        mov     ecx, sizeof.core.thread_t / 4
        rep     stosd
        pop     eax

        call    core.thread._.initialize

        klog_   LOG_DEBUG, "thread #%u created\n", [eax + core.thread_t.id]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.destroy ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        klog_   LOG_DEBUG, "process/thread #%u destroyed\n", [eax + core.thread_t.id]

        ; ensure no one else has access to thread tree expect us
        mov     ecx, core.thread.tree_mutex
        call    mutex_lock

        ; remove thread from the tree
        mov     eax, [esp]
        call    util.rb_tree.remove
        mov     [core.thread.tree_root], eax

        ; free used memory
        mov     eax, [esp]
        call    free

        mov     ecx, core.thread.tree_mutex
        call    mutex_unlock

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

        ; ensure no one else has access to thread tree expect us
        mov     ecx, core.thread.tree_mutex
        call    mutex_lock

        mov     eax, [esp]
        mov     ebx, [core.thread.tree_root]
        mov     ecx, .compare_id
        call    util.b_tree.find
        xchg    eax, [esp]

        mov     ecx, core.thread.tree_mutex
        call    mutex_unlock

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

        ; ensure no one else has access to thread tree expect us
        mov     ecx, core.thread.tree_mutex
        call    mutex_lock

        ; enumerate tree to calculate unused thread ID
        pop     edx
        mov     ebx, [core.thread.tree_root]
        mov     ecx, .check_valid_and_call_back
        call    util.b_tree.enumerate

        push    eax
        mov     ecx, core.thread.tree_mutex
        call    mutex_unlock
        pop     eax
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
kproc core.thread.get_process ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= core.process_t
;-----------------------------------------------------------------------------------------------------------------------
        test    eax, eax
        jz      .exit

        test    [eax + core.thread_t.flags], THREAD_FLAG_PROCESS
        jnz     .exit

        mov     eax, [eax + core.thread_t.parent_id]
        call    core.thread.find_by_id

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.compat.find_by_task_data ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= task_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax + task_data_t.new_pid]
        call    core.thread.find_by_id
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.compat.find_by_app_data ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= app_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        sub     eax, SLOT_BASE
        shr     eax, 3
        add     eax, TASK_BASE - sizeof.task_data_t
        jmp     core.thread.compat.find_by_task_data
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.compat.init_with_app_data ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;> ebx ^= app_data_t
;-----------------------------------------------------------------------------------------------------------------------
        call    core.thread.compat.init_with_app_data

        push    ebx
        mov_s_  [eax + core.process_t.mem_range.size], [ebx + app_data_t.mem_size]
        mov_s_  [eax + core.process_t.dir_table], [ebx + app_data_t.dir_table]
        mov_s_  [eax + core.process_t.dlls_list_ptr], [ebx + app_data_t.dlls_list_ptr]
        mov_s_  [eax + core.process_t.obj.prev_ptr], [ebx + app_data_t.obj.prev_ptr]
        mov_s_  [eax + core.process_t.obj.next_ptr], [ebx + app_data_t.obj.next_ptr]

        sub     ebx, SLOT_BASE
        shr     ebx, 3
        add     ebx, TASK_DATA - sizeof.task_data_t

        mov_s_  [eax + core.process_t.mem_range.address], [ebx + task_data_t.mem_start]
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread.compat.init_with_app_data ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;> ebx ^= app_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx
        mov     ecx, [ebx + app_data_t.heap_base]
        mov     [eax + core.thread_t.heap_range.address], ecx
        neg     ecx
        add     ecx, [ebx + app_data_t.heap_top]
        mov     [eax + core.thread_t.heap_range.size], ecx

        mov     cl, [ebx + app_data_t.keyboard_mode]
        mov     [eax + core.thread_t.keyboard_mode], cl

        mov_s_  [eax + core.thread_t.events.list.prev_ptr], [ebx + app_data_t.ev.prev_ptr]
        mov_s_  [eax + core.thread_t.events.list.next_ptr], [ebx + app_data_t.ev.next_ptr]
        mov_s_  [eax + core.thread_t.saved_esp], [ebx + app_data_t.saved_esp]
        mov_s_  [eax + core.thread_t.saved_esp0], [ebx + app_data_t.saved_esp0]
        mov_s_  [eax + core.thread_t.pl0_stack], [ebx + app_data_t.pl0_stack]
        mov_s_  [eax + core.thread_t.fpu_state], [ebx + app_data_t.fpu_state]
        mov_s_  [eax + core.thread_t.except_mask], [ebx + app_data_t.except_mask]
        mov_s_  [eax + core.thread_t.exc_handler], [ebx + app_data_t.exc_handler]
        mov_s_  [eax + core.thread_t.cur_dir], [ebx + app_data_t.cur_dir]
        mov_s_  [eax + core.thread_t.tls_base], [ebx + app_data_t.tls_base]
        mov_s_  [eax + core.thread_t.io_map], [ebx + app_data_t.io_map]
        mov_s_  [eax + core.thread_t.io_map + 4], [ebx + app_data_t.io_map + 4]
        mov_s_  [eax + core.thread_t.debugger_slot], [ebx + app_data_t.debugger_slot]

        sub     ebx, SLOT_BASE
        shr     ebx, 3
        add     ebx, TASK_DATA - sizeof.task_data_t

        mov     cl, [ebx + task_data_t.state]
        mov     [eax + core.thread_t.state], cl

        mov_s_  [eax + core.thread_t.events.event_mask], [ebx + task_data_t.event_mask]

        mov_s_  [ebx + task_data_t.new_pid], [eax + core.thread_t.id]

        mov     ebx, eax
        mov     eax, [CURRENT_THREAD]
        call    core.thread.get_process
        test    eax, eax
        jz      .exit

        mov_s_  [ebx + core.thread_t.parent_id], [eax + core.thread_t.id]

  .exit:
        pop     ecx ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.thread._.initialize ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        ; ensure no one else has access to thread tree expect us
        mov     ecx, core.thread.tree_mutex
        call    mutex_lock

        ; enumerate tree to calculate unused thread ID
        mov     ebx, [core.thread.tree_root]
        mov     ecx, .check_used_id
        mov     edx, 1
        call    util.b_tree.enumerate
        ; we're optimistic here and hope we always find a free ID to use, hence no enumeration result check

        ; set thread ID to acquired one
        mov     eax, [esp]
        mov     [eax + core.thread_t.id], edx

        ; add thread to the tree
        mov     ebx, [core.thread.tree_root]
        mov     ecx, .compare_id
        call    util.rb_tree.insert
        mov     [core.thread.tree_root], eax

        mov     ecx, core.thread.tree_mutex
        call    mutex_unlock

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
