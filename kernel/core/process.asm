;;======================================================================================================================
;;///// process.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

PROCESS_FLAG_VALID = 0x01

struct core.process_t rb_tree_node_t
  id            dd ?
  flags         dd ?
  parent_id     dd ?
  name          rb 11
                rb 5
  mem_range     memory_range32_t
  heap_base     dd ?
  heap_top      dd ?
  dir_table     dd ?
  dlls_list_ptr dd ? ; ^= dll_handle_t
  obj           linked_list_t
  threads       linked_list_t
ends

static_assert sizeof.core.process_t mod 4 = 0

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.lock_tree ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx
        mov     ecx, core.process._.tree_mutex
        call    mutex_lock
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.unlock_tree ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx
        mov     ecx, core.process._.tree_mutex
        call    mutex_unlock
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.alloc ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= [invalid] core.process_t or 0
;-----------------------------------------------------------------------------------------------------------------------
        ; allocate memory for process structure
        mov     eax, sizeof.core.process_t
        call    malloc
        or      eax, eax
        jz      .exit

        push    eax

        ; zero-initialize allocated memory
        xchg    eax, edi
        xor     eax, eax
        mov     ecx, sizeof.core.process_t / 4
        rep     stosd

        call    core.process.lock_tree

        mov     eax, [esp]
        call    core.process._.initialize

        call    core.process.unlock_tree

        pop     eax

        klog_   LOG_DEBUG, "process #%u allocated\n", [eax + core.process_t.id]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.free ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.process_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        klog_   LOG_DEBUG, "process #%u freed\n", [eax + core.process_t.id]

        call    core.process.lock_tree

        ; remove process from the tree
        mov     eax, [esp]
        call    util.rb_tree.remove
        mov     [core.process._.tree_root], eax

        ; free used memory
        mov     eax, [esp]
        call    free

        call    core.process.unlock_tree

        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.find_by_id ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= process ID to find
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= core.process_t or 0
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx edx eax

        call    core.process.lock_tree

        mov     eax, [esp]
        mov     ebx, [core.process._.tree_root]
        mov     ecx, .compare_id
        call    util.b_tree.find
        xchg    eax, [esp]

        call    core.process.unlock_tree

        pop     eax edx ecx ebx
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .compare_id: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= process ID to find
;> ebx ^= core.process_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, [ebx + core.process_t.id]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.enumerate ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx ^= callback, f(eax)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx

        call    core.process.lock_tree

        pop     edx
        mov     ebx, [core.process._.tree_root]
        mov     ecx, .check_valid_and_call_back
        call    util.b_tree.enumerate

        call    core.process.unlock_tree

        ret

;-----------------------------------------------------------------------------------------------------------------------
  .check_valid_and_call_back: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.process_t
;-----------------------------------------------------------------------------------------------------------------------
        test    [eax + core.process_t.flags], PROCESS_FLAG_VALID
        jz      @f

        jmp     edx

    @@: xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process.compat.init_with_app_data ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.thread_t
;> ebx ^= app_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    dword[ebx + app_data_t.app_name] dword[ebx + app_data_t.app_name + 4] \
                dword[ebx + app_data_t.app_name + 8] dword[ebx + app_data_t.app_name + 12]
        pop     dword[eax + core.process_t.name + 12] dword[eax + core.process_t.name + 8] \
                dword[eax + core.process_t.name + 4] dword[eax + core.process_t.name]

        mov_s_  [eax + core.process_t.mem_range.size], [ebx + app_data_t.mem_size]
        mov_s_  [eax + core.process_t.heap_base], [ebx + app_data_t.heap_base]
        mov_s_  [eax + core.process_t.heap_top], [ebx + app_data_t.heap_top]
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

uglobal
  core.process._.tree_root  dd ?
  core.process._.tree_mutex mutex_t
  core.process._.last_id    dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc core.process._.initialize ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.process_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        ; enumerate tree to calculate unused process ID
        mov     ebx, [core.process._.tree_root]
        mov     ecx, .check_used_id
        mov     edx, [core.process._.last_id]
        inc     edx
        jnz     @f

        inc     dl

    @@: call    util.b_tree.enumerate
        ; we're optimistic here and hope we always find a free ID to use, hence no enumeration result check

        ; set process ID to acquired one
        mov     eax, [esp]
        mov     [eax + core.process_t.id], edx
        mov     [core.process._.last_id], edx

        ; add process to the tree
        mov     ebx, [core.process._.tree_root]
        mov     ecx, .compare_id
        call    util.rb_tree.insert
        mov     [core.process._.tree_root], eax

        ; init threads list
        mov     eax, [esp]
        lea     ecx, [eax + core.process_t.threads]
        mov     [eax + core.process_t.threads.prev_ptr], ecx
        mov     [eax + core.process_t.threads.next_ptr], ecx

        pop     eax
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .check_used_id: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= core.process_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edx, [eax + core.process_t.id]
        jb      .interrupt_search
        jne     @f

        inc     edx

    @@: xor     eax, eax

  .interrupt_search:
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .compare_id: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= first core.process_t
;> ebx ^= second core.process_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [eax + core.process_t.id]
        cmp     eax, [ebx + core.process_t.id]
        pop     eax
        ret
kendp
