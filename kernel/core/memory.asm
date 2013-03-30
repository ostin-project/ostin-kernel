;;======================================================================================================================
;;///// memory.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2006-2011 KolibriOS team <http://kolibrios.org/>
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
  page_start    rd 1
  page_end      rd 1
  ipc_tmp       rd 1
  ipc_pdir      rd 1
  ipc_ptab      rd 1
  proc_mem_map  rd 1
  proc_mem_pdir rd 1
  proc_mem_tab  rd 1
  tmp_task_pdir rd 1
  tmp_task_ptab rd 1
  pg_data       pages_data_t
endg

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc alloc_page ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli
        push    ebx

        cmp     [pg_data.pages_free], 1
        jle     .out_of_memory

        mov     ebx, [page_start]
        mov     ecx, [page_end]

  .l1:
        bsf     eax, [ebx]
        jnz     .found
        add     ebx, 4
        cmp     ebx, ecx
        jb      .l1
        pop     ebx
        popfd
        xor     eax, eax
        ret

  .found:
        dec     [pg_data.pages_free]
        jz      .out_of_memory

        btr     [ebx], eax
        mov     [page_start], ebx
        sub     ebx, sys_pgmap
        lea     eax, [eax + ebx * 8]
        shl     eax, 12
;       dec     [pg_data.pages_free]
        pop     ebx
        popfd
        ret

  .out_of_memory:
        mov     [pg_data.pages_free], 1
        xor     eax, eax
        pop     ebx
        popfd
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc alloc_pages stdcall, count:dword ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        push    ebx
        push    edi
        cli
        mov     eax, [count]
        add     eax, 7
        shr     eax, 3
        mov     [count], eax

        mov     ebx, [pg_data.pages_free]
        sub     ebx, 9
        js      .out_of_memory
        shr     ebx, 3
        cmp     eax, ebx
        jg      .out_of_memory

        mov     ecx, [page_start]
        mov     ebx, [page_end]

  .find:
        mov     edx, [count]
        mov     edi, ecx

  .match:
        cmp     byte[ecx], 0xff
        jne     .next
        dec     edx
        jz      .ok
        inc     ecx
        cmp     ecx, ebx
        jb      .match

  .out_of_memory:
  .fail:
        xor     eax, eax
        pop     edi
        pop     ebx
        popfd
        ret

  .next:
        inc     ecx
        cmp     ecx, ebx
        jb      .find
        pop     edi
        pop     ebx
        popfd
        xor     eax, eax
        ret

  .ok:
        sub     ecx, edi
        inc     ecx
        push    esi
        mov     esi, edi
        xor     eax, eax
        rep
        stosb
        sub     esi, sys_pgmap
        shl     esi, 3 + 12
        mov     eax, esi
        mov     ebx, [count]
        shl     ebx, 3
        sub     [pg_data.pages_free], ebx
        pop     esi
        pop     edi
        pop     ebx
        popfd
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc map_page stdcall, lin_addr:dword, phis_addr:dword, flags:dword ;///////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        mov     eax, [phis_addr]
        and     eax, not 0x0fff
        or      eax, [flags]
        mov     ebx, [lin_addr]
        shr     ebx, 12
        mov     [page_tabs + ebx * 4], eax
        mov     eax, [lin_addr]
        invlpg  [eax]
        pop     ebx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc map_space ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? not implemented
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc free_page ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = page address
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli
        shr     eax, 12 ; page index
        bts     [sys_pgmap], eax ; that's all!
        cmc
        adc     [pg_data.pages_free], 0
        shr     eax, 3
        and     eax, not 3 ; dword offset from page_map
        add     eax, sys_pgmap
        cmp     [page_start], eax
        ja      @f
        popfd
        ret

    @@: mov     [page_start], eax
        popfd
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc map_io_mem stdcall, base:dword, size:dword, flags:dword ;//////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    edi

        mov     eax, [base]
        add     eax, [size]
        add     eax, 4095
        and     eax, -4096
        mov     ecx, [base]
        and     ecx, -4096
        sub     eax, ecx
        mov     [size], eax

        stdcall alloc_kernel_space, eax
        test    eax, eax
        jz      .fail
        push    eax

        mov     edi, 0x1000
        mov     ebx, eax
        mov     ecx, [size]
        mov     edx, [base]
        shr     eax, 12
        shr     ecx, 12
        and     edx, -4096
        or      edx, [flags]

    @@: mov     [page_tabs + eax * 4], edx
        invlpg  [ebx]
        inc     eax
        add     ebx, edi
        add     edx, edi
        loop    @b

        pop     eax
        mov     edx, [base]
        and     edx, 4095
        add     eax, edx

  .fail:
        pop     edi
        pop     ebx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc commit_pages ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = page base + page flags
;> ebx = linear address
;> ecx = count
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jz      .fail

        push    edi

        push    eax ecx
        mov     ecx, pg_data.mutex
        call    mutex_lock
        pop     ecx eax

        mov     edi, ebx
        shr     edi, 12
        lea     edi, [page_tabs + edi * 4]

    @@: stosd
        invlpg  [ebx]
        add     eax, 0x1000
        add     ebx, 0x1000
        loop    @b

        pop edi

        mov     ecx, pg_data.mutex
        call    mutex_unlock

  .fail:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc release_pages ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = base
;> ecx = count
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp esi edi ebx

        mov     esi, eax
        mov     edi, eax

        shr     esi, 12
        lea     esi, [page_tabs + esi * 4]

        push    ecx
        mov     ecx, pg_data.mutex
        call    mutex_lock
        pop     ecx

        mov     ebp, [pg_data.pages_free]
        mov     ebx, [page_start]
        mov     edx, sys_pgmap

    @@: xor     eax, eax
        xchg    eax, [esi]
        invlpg  [edi]

        test    eax, 1
        jz      .next

        shr     eax, 12
        bts     [edx], eax
        cmc
        adc     ebp, 0
        shr     eax, 3
        and     eax, -4
        add     eax, edx
        cmp     eax, ebx
        jae     .next

        mov     ebx, eax

  .next:
        add     edi, 0x1000
        add     esi, 4
        loop    @b

        mov     [pg_data.pages_free], ebp

        mov     ecx, pg_data.mutex
        call    mutex_unlock
 
        pop     ebx edi esi ebp
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc unmap_pages ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = base
;> ecx = count
;-----------------------------------------------------------------------------------------------------------------------
        push    edi

        mov     edi, eax
        mov     edx, eax

        shr     edi, 10
        add     edi, page_tabs

        xor     eax, eax

    @@: stosd
        invlpg  [edx]
        add     edx, 0x1000
        loop    @b

        pop     edi
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc map_page_table stdcall, lin_addr:dword, phis_addr:dword ;//////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        mov     ebx, [lin_addr]
        shr     ebx, 22
        mov     eax, [phis_addr]
        and     eax, not 0x0fff
        or      eax, PG_UW ; + PG_NOCACHE
        mov     [master_tab + ebx * 4], eax
        mov     eax, [lin_addr]
        shr     eax, 10
        add     eax, page_tabs
        invlpg  [eax]
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc init_LFB ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  pg_count dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [LFBRange.address], -1
        jne     @f
        mov     [boot_var.enable_mtrr], 2
        ; max VGA = 640 * 480 * 4 = 1228800 bytes
        ;         + 32 * 640 * 4 = 81920 bytes for mouse pointer
        stdcall alloc_pages, (640 * 480 * 4 + 32 * 640 * 4 + 4095) / 4096

        push    eax
        call    alloc_page
        stdcall map_page_table, LFB_BASE, eax
        pop     eax
        or      eax, PG_UW
        mov     ebx, LFB_BASE
        ; max VGA = 640 * 480 * 4 = 1228800 bytes
        ;         + 32 * 640 * 4 = 81920 bytes for mouse pointer
        mov     ecx, (640 * 480 * 4 + 32 * 640 * 4 + 4095) / 4096
        call    commit_pages
        mov     [LFBRange.address], LFB_BASE
        ret

    @@: test    [SCR_MODE], 0100000000000000b
        jnz     @f
        mov     [boot_var.enable_mtrr], 2
        ret

    @@: call    init_mtrr

        mov     edx, LFB_BASE
        mov     esi, [LFBRange.address]
        mov     edi, 0x00c00000
        mov     [exp_lfb + 4], edx

        shr     edi, 12
        mov     [pg_count], edi
        shr     edi, 10

        bt      [cpu_caps], CAPS_PSE
        jnc     .map_page_tables
        or      esi, PG_LARGE + PG_UW
        mov     edx, sys_pgdir + (LFB_BASE shr 20)

    @@: mov     [edx], esi
        add     edx, 4
        add     esi, 0x00400000
        dec     edi
        jnz     @b

        bt      [cpu_caps], CAPS_PGE
        jnc     @f
        or      dword[sys_pgdir + (LFB_BASE shr 20)], PG_GLOBAL

    @@: mov     [LFBRange.address], LFB_BASE
        mov     eax, cr3 ; flush TLB
        mov     cr3, eax
        ret

  .map_page_tables:

    @@: call    alloc_page
        stdcall map_page_table, edx, eax
        add     edx, 0x00400000
        dec     edi
        jnz     @b

        mov     eax, [LFBRange.address]
        mov     edi, page_tabs + (LFB_BASE shr 10)
        or      eax, PG_UW
        mov     ecx, [pg_count]

    @@: stosd
        add     eax, 0x1000
        dec     ecx
        jnz     @b

        mov     [LFBRange.address], LFB_BASE
        mov     eax, cr3 ; flush TLB
        mov     cr3, eax

        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc new_mem_resize stdcall, new_size:dword ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx esi edi
 
        mov     edx, [current_slot_ptr]
        cmp     [edx + legacy.slot_t.app.heap_base], 0
        jne     .exit

        mov     edi, [new_size]
        add     edi, 4095
        and     edi, not 4095
        mov     [new_size], edi

        mov     esi, [edx + legacy.slot_t.app.mem_size]
        add     esi, 4095
        and     esi, not 4095

        cmp     edi, esi
        ja      .expand
        je      .exit

        mov     ebx, edi
        shr     edi, 12
        shr     esi, 12

        mov     ecx, pg_data.mutex
        call    mutex_lock

    @@: mov     eax, [app_page_tabs + edi * 4]
        test    eax, 1
        jz      .next

        mov     dword[app_page_tabs + edi * 4], 0
        invlpg  [ebx]
        call    free_page

  .next:
        inc     edi
        add     ebx, 0x1000
        cmp     edi, esi
        jb      @b

        mov     ecx, pg_data.mutex
        call    mutex_unlock

  .update_size:
        mov     edx, [current_slot_ptr]
        mov     ebx, [new_size]
        call    update_mem_size

  .exit:
        pop     edi esi ebx
        xor     eax, eax
        ret

  .expand:
        mov     ecx, pg_data.mutex
        call    mutex_lock

        xchg    esi, edi

        push    esi ; new size
        push    edi ; old size

        add     edi, 0x3fffff
        and     edi, not 0x3fffff
        add     esi, 0x3fffff
        and     esi, not 0x3fffff

        cmp     edi, esi
        jae     .grow

    @@: call    alloc_page
        test    eax, eax
        jz      .exit_fail

        stdcall map_page_table, edi, eax

        push    edi
        shr     edi, 10
        add     edi, page_tabs
        mov     ecx, 1024
        xor     eax, eax
        rep
        stosd
        pop     edi

        add     edi, 0x00400000
        cmp     edi, esi
        jb      @b

  .grow:
        pop     edi ;old size
        pop     ecx ;new size

        shr     edi, 10
        shr     ecx, 10
        sub     ecx, edi
        shr     ecx, 2 ;pages count
        mov     eax, 2

        add     edi, app_page_tabs
        rep
        stosd

        mov     ecx, pg_data.mutex
        call    mutex_unlock

        jmp     .update_size

  .exit_fail:
        mov     ecx, pg_data.mutex
        call    mutex_unlock

        add     esp, 8
        pop     edi esi ebx
        xor     eax, eax
        inc     eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc update_mem_size ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edx = slot base
;> ebx = new memory size
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax, ecx, edx
;-----------------------------------------------------------------------------------------------------------------------
        mov     [edx + legacy.slot_t.app.mem_size], ebx
        ; search threads and update
        ; application memory size infomation
        mov     ecx, [edx + legacy.slot_t.app.dir_table]
        mov     eax, 2

  .search_threads:
        ; eax = current slot
        ; ebx = new memory size
        ; ecx = page directory
        cmp     eax, [legacy_slots.last_valid_slot]
        jg      .search_threads_end
        mov     edx, eax
        shl     edx, 9 ; * sizeof.legacy.slot_t
        cmp     [legacy_slots + edx + legacy.slot_t.task.state], THREAD_STATE_FREE ; if slot empty?
        jz      .search_threads_next
        cmp     [legacy_slots + edx + legacy.slot_t.app.dir_table], ecx ; if it is our thread?
        jnz     .search_threads_next
        mov     [legacy_slots + edx + legacy.slot_t.app.mem_size], ebx ; update memory size

  .search_threads_next:
        inc     eax
        jmp     .search_threads

  .search_threads_end:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_pg_addr ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = linear address
;-----------------------------------------------------------------------------------------------------------------------
;< eax = phisical page address
;-----------------------------------------------------------------------------------------------------------------------
        shr     eax, 12
        mov     eax, [page_tabs + eax * 4]
        and     eax, 0xfffff000
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc page_fault_handler ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# Now it is called from core/sys32::exc_c (see stack frame there)
;-----------------------------------------------------------------------------------------------------------------------
.err_addr equ ebp - 4
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ; save exception number (#PF)
        mov     ebp, esp
        mov     ebx, cr2
        push    ebx ; that is locals: .err_addr = cr2
        inc     [pg_data.pages_faults]

        mov     eax, [pf_err_code]

        cmp     ebx, OS_BASE ; ebx == .err_addr
        jb      .user_space ; page in application memory

        cmp     ebx, page_tabs
        jb      .kernel_space ; page in kernel memory

        cmp     ebx, kernel_tabs
        jb      .alloc ; .app_tabs ; application page tables, simply create one

if 0 ; this is superfluous for now

        cmp     ebx, LFB_BASE
        jb      .core_tabs ; kernel page tables

        ; error

  .lfb:
        ; LFB area
        ; error
        jmp     .fail

end if

  .core_tabs:
  .fail: ; simply return to caller
        mov     esp, ebp
        pop     ebx ; restore exception number (#PF)
        ret

;       xchg    bx, bx
;       add     esp, 12 ; clear in stack: locals(.err_addr) + #PF + ret_to_caller
;       RestoreRing3Context
;       iretd

  .user_space:
        test    eax, PG_MAP
        jnz     .err_access ; page is present, access violation?

        shr     ebx, 12
        mov     ecx, ebx
        shr     ecx, 10
        mov     edx, [master_tab + ecx * 4]
        test    edx, PG_MAP
        jz      .fail ; page table not created, invalid address in application

        mov     eax, [page_tabs + ebx * 4]
        test    eax, 2
        jz      .fail ; address is not reserved for use, error

  .alloc:
        call    alloc_page
        test    eax, eax
        jz      .fail

        stdcall map_page, [.err_addr], eax, PG_UW

        mov     edi, [.err_addr]
        and     edi, 0xfffff000
        mov     ecx, 1024
        xor     eax, eax
        rep
        stosd

  .exit:
        ; iret with repeat fault instruction
        add     esp, 12 ; clear in stack: locals(.err_addr) + #PF + ret_to_caller
        RestoreRing3Context
        iretd

  .err_access:
        ; access denied? this may be a result of copy-on-write protection for DLL
        ; check list of HDLLs
        and     ebx, not 0x0fff
        mov     eax, [current_slot_ptr]
        mov     eax, [eax + legacy.slot_t.app.dlls_list_ptr]
        test    eax, eax
        jz      .fail
        mov     esi, [eax + dll_handle_t.next_ptr]

  .scan_hdll:
        cmp     esi, eax
        jz      .fail
        mov     edx, ebx
        sub     edx, [esi + dll_handle_t.range.address]
        cmp     edx, [esi + dll_handle_t.range.size]
        jb      .fault_in_hdll

  .scan_hdll.next:
        mov     esi, [esi + dll_handle_t.next_ptr]
        jmp     .scan_hdll

  .fault_in_hdll:
        ; allocate new page, map it as rw and copy data
        call    alloc_page
        test    eax, eax
        jz      .fail
        stdcall map_page, ebx, eax, PG_UW
        mov     edi, ebx
        mov     ecx, 1024
        sub     ebx, [esi + dll_handle_t.range.address]
        mov     esi, [esi + dll_handle_t.parent]
        mov     esi, [esi + dll_descriptor_t.data.address]
        add     esi, ebx
        rep
        movsd
        jmp     .exit

  .kernel_space:
        test    eax, PG_MAP
        jz      .fail ; page is not present

        test    eax, 12 ; U/S (+below)
        jnz     .fail ; application accessed the kernel memory
;       test    eax, 8
;       jnz     .fail ; reserved bit is set in page tables. added in P4/Xeon

        ; write attempt in protected kernel page
        cmp     ebx, tss.io_map_0
        jb      .fail

        cmp     ebx, tss.io_map_0 + 8192
        jae     .fail

        ; io permission map
        ; copy-on-write protection
        call    alloc_page
        test    eax, eax
        jz      .fail

        push    eax
        stdcall map_page, [.err_addr], eax, PG_SW
        pop     eax
        mov     edi, [.err_addr]
        and     edi, -4096
        lea     esi, [edi + (not tss.io_map_0) + 1] ; - tss._io_map_0

        mov     ebx, esi
        shr     ebx, 12
        mov     edx, [current_slot_ptr]
        or      eax, PG_SW
        mov     [edx + legacy.slot_t.app.io_map + ebx * 4], eax

        add     esi, [default_io_map]
        mov     ecx, 4096 / 4
        rep
        movsd
        jmp     .exit
endp

;-----------------------------------------------------------------------------------------------------------------------
proc map_mem stdcall, lin_addr:dword, slot:dword, ofs:dword, buf_size:dword, req_access:dword ;/////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? returns number of mapped bytes
;-----------------------------------------------------------------------------------------------------------------------
        push    0 ; initialize number of mapped bytes

        cmp     [buf_size], 0
        jz      .exit

        mov     eax, [slot]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + eax + legacy.slot_t.app.dir_table]
        and     eax, 0xfffff000

        stdcall map_page, [ipc_pdir], eax, PG_UW
        mov     ebx, [ofs]
        shr     ebx, 22
        mov     esi, [ipc_pdir]
        mov     edi, [ipc_ptab]
        mov     eax, [esi + ebx * 4]
        and     eax, 0xfffff000
        jz      .exit
        stdcall map_page, edi, eax, PG_UW
;       inc     ebx
;       add     edi, 0x1000
;       mov     eax, [esi + ebx * 4]
;       test    eax, eax
;       jz      @f
;       and     eax, 0xfffff000
;       stdcall map_page, edi, eax

    @@: mov     edi, [lin_addr]
        and     edi, 0xfffff000
        mov     ecx, [buf_size]
        add     ecx, 4095
        shr     ecx, 12
        inc     ecx

        mov     edx, [ofs]
        shr     edx, 12
        and     edx, 0x3ff
        mov     esi, [ipc_ptab]

  .map:
        stdcall safe_map_page, [slot], [req_access], [ofs]
        jnc     .exit
        add     dword[ebp - 4], 4096
        add     [ofs], 4096
        dec     ecx
        jz      .exit
        add     edi, 0x1000
        inc     edx
        cmp     edx, 0x400
        jnz     .map
        inc     ebx
        mov     eax, [ipc_pdir]
        mov     eax, [eax + ebx * 4]
        and     eax, 0xfffff000
        jz      .exit
        stdcall map_page, esi, eax, PG_UW
        xor     edx, edx
        jmp     .map

  .exit:
        pop     eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc map_memEx stdcall, lin_addr:dword, slot:dword, ofs:dword, buf_size:dword, req_access:dword ;///////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    0 ; initialize number of mapped bytes

        cmp     [buf_size], 0
        jz      .exit

        mov     eax, [slot]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + eax + legacy.slot_t.app.dir_table]
        and     eax, 0xfffff000

        stdcall map_page, [proc_mem_pdir], eax, PG_UW
        mov     ebx, [ofs]
        shr     ebx, 22
        mov     esi, [proc_mem_pdir]
        mov     edi, [proc_mem_tab]
        mov     eax, [esi + ebx * 4]
        and     eax, 0xfffff000
        test    eax, eax
        jz      .exit
        stdcall map_page, edi, eax, PG_UW

    @@: mov     edi, [lin_addr]
        and     edi, 0xfffff000
        mov     ecx, [buf_size]
        add     ecx, 4095
        shr     ecx, 12
        inc     ecx

        mov     edx, [ofs]
        shr     edx, 12
        and     edx, 0x3ff
        mov     esi, [proc_mem_tab]

  .map:
        stdcall safe_map_page, [slot], [req_access], [ofs]
        jnc     .exit
        add     dword[ebp - 4], 0x1000
        add     edi, 0x1000
        add     [ofs], 0x1000
        inc     edx
        dec     ecx
        jnz     .map

  .exit:
        pop     eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc safe_map_page stdcall, slot:dword, req_access:dword, ofs:dword ;///////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi + edx * 4 = pointer to page table entry
;> edi = linear address to map
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 0 (error) or 1 (ok)
;-----------------------------------------------------------------------------------------------------------------------
;# destroys: only eax
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [esi + edx * 4]
        test    al, PG_MAP
        jz      .not_present
        test    al, PG_WRITE
        jz      .resolve_readonly

  .map:
        ; normal case: writable page, just map with requested access
        stdcall map_page, edi, eax, [req_access]
        stc

  .fail:
        ret

  .not_present:
        ; check for alloc-on-demand page
        test    al, 2
        jz      .fail
        ; allocate new page, save it to source page table
        push    ecx
        call    alloc_page
        pop     ecx
        test    eax, eax
        jz      .fail
        or      al, PG_UW
        mov     [esi + edx * 4], eax
        jmp     .map

  .resolve_readonly:
        ; readonly page, probably copy-on-write
        ; check: readonly request of readonly page is ok
        test    [req_access], PG_WRITE
        jz      .map
        ; find control structure for this page
        pushf
        cli
        push    ebx ecx
        mov     eax, [slot]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + eax + legacy.slot_t.app.dlls_list_ptr]
        test    eax, eax
        jz      .no_hdll
        mov     ecx, [eax + dll_handle_t.next_ptr]

  .scan_hdll:
        cmp     ecx, eax
        jz      .no_hdll
        mov     ebx, [ofs]
        and     ebx, not 0x0fff
        sub     ebx, [ecx + dll_handle_t.range.address]
        cmp     ebx, [ecx + dll_handle_t.range.size]
        jb      .hdll_found
        mov     ecx, [ecx + dll_handle_t.next_ptr]
        jmp     .scan_hdll

  .no_hdll:
        pop     ecx ebx
        popf
        clc
        ret

  .hdll_found:
        ; allocate page, save it in page table, map it, copy contents from base
        mov     eax, [ecx + dll_handle_t.parent]
        add     ebx, [eax + dll_descriptor_t.data.address]
        call    alloc_page
        test    eax, eax
        jz      .no_hdll
        or      al, PG_UW
        mov     [esi + edx * 4], eax
        stdcall map_page, edi, eax, [req_access]
        push    esi edi
        mov     esi, ebx
        mov     ecx, 4096 / 4
        rep
        movsd
        pop     edi esi
        pop     ecx ebx
        popf
        stc
        ret
endp

align 16 ; very often call this subrutine
;-----------------------------------------------------------------------------------------------------------------------
kproc memmove ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? memory move in bytes
;-----------------------------------------------------------------------------------------------------------------------
;> eax = from
;> ebx = to
;> ecx = no of bytes
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jle     .ret

        push    esi edi ecx

        mov     edi, ebx
        mov     esi, eax

        test    ecx, not 011b
        jz      @f

        push    ecx
        shr     ecx, 2
        rep
        movsd
        pop     ecx
        and     ecx, 011b
        jz      .finish

    @@: rep
        movsb

  .finish:
        pop     ecx edi esi

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.ipc_ctl ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 60
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.ipc_ctl, subfn, sysfn.not_implemented, \
    set_buffer, \ ; 1
    send_message ; 2
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.ipc_ctl.set_buffer ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 60.1: set IPC buffer area
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 1
;> ecx = address of buffer
;> edx = size of buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [current_slot_ptr]
        pushf
        cli
        mov     [eax + legacy.slot_t.app.ipc.address], ecx ; set fields in extended information area
        mov     [eax + legacy.slot_t.app.ipc.size], edx

        add     edx, ecx
        add     edx, 4095
        and     edx, not 4095

  .touch:
        mov     eax, [ecx]
        add     ecx, 0x1000
        cmp     ecx, edx
        jb      .touch

        popf
        mov     [esp + 4 + regs_context32_t.eax], ebx ; ebx=0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.ipc_ctl.send_message ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 60.2: send message
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 2
;> ecx = PID
;> edx = address of message
;> esi = size of message
;-----------------------------------------------------------------------------------------------------------------------
        stdcall sys_ipc_send, ecx, edx, esi
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;align 4
;-----------------------------------------------------------------------------------------------------------------------
;proc set_ipc_buff ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     eax, [current_slot_ptr]
;       pushf
;       cli
;       mov     [eax + legacy.slot_t.app.ipc.offset], ebx ; set fields in extended information area
;       mov     [eax + legacy.slot_t.app.ipc.length], ecx
;
;       add     ecx, ebx
;       add     ecx, 4095
;       and     ecx, not 4095
;
; .touch:
;       mov     eax, [ebx]
;       add     ebx, 0x1000
;       cmp     ebx, ecx
;       jb      .touch
;
;       popf
;       xor     eax, eax
;       ret
;endp

;-----------------------------------------------------------------------------------------------------------------------
proc sys_ipc_send stdcall, PID:dword, msg_addr:dword, msg_size:dword ;//////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  dst_slot   dd ?
  dst_offset dd ?
  buf_size   dd ?
  used_buf   dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        pushf
        cli

        mov     eax, [PID]
        call    pid_to_slot
        test    eax, eax
        jz      .no_pid

        mov     [dst_slot], eax
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     edi, [legacy_slots + eax + legacy.slot_t.app.ipc.address]
        test    edi, edi
        jz      .no_ipc_area

        mov     ebx, edi
        and     ebx, 0x0fff
        mov     [dst_offset], ebx

        mov     esi, [legacy_slots + eax + legacy.slot_t.app.ipc.size]
        mov     [buf_size], esi

        mov     ecx, [ipc_tmp]
        cmp     esi, 0x40000 - 0x1000 ; size of [ipc_tmp] minus one page
        jbe     @f
        push    esi edi
        add     esi, 0x1000
        stdcall alloc_kernel_space, esi
        mov     ecx, eax
        pop     edi esi

    @@: mov     [used_buf], ecx
        stdcall map_mem, ecx, [dst_slot], edi, esi, PG_SW

        mov     edi, [dst_offset]
        add     edi, [used_buf]
        cmp     dword[edi], 0
        jnz     .ipc_blocked ; if dword[buffer]<>0 - ipc blocked now

        mov     edx, [edi + 4]
        lea     ebx, [edx + 8]
        add     ebx, [msg_size]
        cmp     ebx, [buf_size]
        ja      .buffer_overflow ; esi<0 - not enough memory in buffer

        mov     [edi + 4], ebx
        mov     eax, [current_slot_ptr]
        mov     eax, [eax + legacy.slot_t.task.pid] ; eax - our PID
        add     edi, edx
        mov     [edi], eax
        mov     ecx, [msg_size]

        mov     [edi + 4], ecx
        add     edi, 8
        mov     esi, [msg_addr]
;       add     esi, new_app_base
        rep
        movsb

        mov     ebx, [ipc_tmp]
        mov     edx, ebx
        shr     ebx, 12
        xor     eax, eax
        mov     [page_tabs + ebx * 4], eax
        invlpg  [edx]

        mov     ebx, [ipc_pdir]
        mov     edx, ebx
        shr     ebx, 12
        xor     eax, eax
        mov     [page_tabs + ebx * 4], eax
        invlpg  [edx]

        mov     ebx, [ipc_ptab]
        mov     edx, ebx
        shr     ebx, 12
        xor     eax, eax
        mov     [page_tabs + ebx * 4], eax
        invlpg  [edx]

        mov     eax, [dst_slot]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        or      [legacy_slots + eax + legacy.slot_t.app.event_mask], EVENT_IPC
        cmp     [check_idle_semaphore], 20
        jge     .ipc_no_cis

        mov     [check_idle_semaphore], 5

  .ipc_no_cis:
        push    0
        jmp     .ret

  .no_pid:
        popf
        mov     eax, 4
        ret

  .no_ipc_area:
        popf
        xor     eax, eax
        inc     eax
        ret

  .ipc_blocked:
        push    2
        jmp     .ret

  .buffer_overflow:
        push    3

  .ret:
        mov     eax, [used_buf]
        cmp     eax, [ipc_tmp]
        jz      @f
        stdcall free_kernel_space, eax

    @@: pop     eax
        popf
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_memory_info ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.20
;-----------------------------------------------------------------------------------------------------------------------
;       add     ecx, new_app_base
        cmp     ecx, OS_BASE
        jae     .fail

        mov     eax, [pg_data.pages_count]
        mov     [ecx], eax
        shl     eax, 12
        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     eax, [pg_data.pages_free]
        mov     [ecx + 4], eax
        mov     eax, [pg_data.pages_faults]
        mov     [ecx + 8], eax
        mov     eax, [heap_size]
        mov     [ecx + 12], eax
        mov     eax, [heap_free]
        mov     [ecx + 16], eax
        mov     eax, [heap_blocks]
        mov     [ecx + 20], eax
        mov     eax, [free_blocks]
        mov     [ecx + 24], eax
        ret

  .fail:
        or      [esp + 4 + regs_context32_t.eax], -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.system_service, subfn, sysfn.not_implemented, \
    get_task_switch_counter, \ ; 0
    change_task, \ ; 1
    performance_ctl, \ ; 2
    read_msr_register, \ ; 3
    write_msr_register, \ ; 4
    -, \
    -, \
    -, \
    -, \
    -, \
    -, \
    init_heap, \ ; 11
    user_alloc, \ ; 12
    user_free, \ ; 13
    get_event_ex, \ ; 14
    -, \
    get_service, \ ; 16
    call_service, \ ; 17
    -, \
    load_dll, \ ; 19
    user_realloc, \ ; 20
    load_driver, \ ; 21
    shmem_open, \ ; 22
    shmem_close, \ ; 23
    set_exception_handler, \ ; 24
    unmask_exception, \ ; 25
    user_unmap ; 25
endg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]

  .error:
        and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.init_heap ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.11
;-----------------------------------------------------------------------------------------------------------------------
        call    init_heap
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.user_alloc ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.12
;-----------------------------------------------------------------------------------------------------------------------
        stdcall user_alloc, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.user_free ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.13
;-----------------------------------------------------------------------------------------------------------------------
        stdcall user_free, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.get_event_ex ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.14
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, OS_BASE
        jae     sysfn.system_service.error
        mov     edi, ecx
        call    get_event_ex
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.get_service ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.16
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jz      sysfn.system_service.error
        cmp     ecx, OS_BASE
        jae     sysfn.system_service.error
        stdcall get_service, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.call_service ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.17
;-----------------------------------------------------------------------------------------------------------------------
        call    srv_handlerEx ; ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.load_dll ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.19
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, OS_BASE
        jae     sysfn.system_service.error
        stdcall load_library, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.user_realloc ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.20
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, edx
        mov     ebx, ecx
        call    user_realloc ; in: eax = pointer, ebx = new size
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.load_driver ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.21
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, OS_BASE
        jae     sysfn.system_service.error

        cmp     edx, OS_BASE
        jae     sysfn.system_service.error

        mov     edi, edx
        stdcall load_PE, ecx
        mov     esi, eax
        test    eax, eax
        jz      .exit

        push    edi
        push    DRV_ENTRY
        call    eax
        add     esp, 8
        test    eax, eax
        jz      .exit

        mov     [eax + service_t.entry], esi

  .exit:
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.shmem_open ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.22
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, OS_BASE
        jae     sysfn.system_service.error

        stdcall shmem_open, ecx, edx, esi
        mov     [esp + 4 + regs_context32_t.edx], edx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.shmem_close ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.23
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, OS_BASE
        jae     sysfn.system_service.error

        stdcall shmem_close, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.set_exception_handler ;//////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.24
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [current_slot_ptr]
        xchg    ecx, [eax + legacy.slot_t.app.exc_handler]
        xchg    edx, [eax + legacy.slot_t.app.except_mask]
        mov     [esp + 4 + regs_context32_t.eax], ecx ; reg_eax+8
        mov     [esp + 4 + regs_context32_t.ebx], edx ; reg_ebx+8
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.unmask_exception ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.25
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, 32
        jae     sysfn.system_service.error

        mov     eax, [current_slot_ptr]
        btr     [eax + legacy.slot_t.app.except_mask], ecx
        setc    [esp + 4 + regs_context32_t.al]
        jecxz   .exit
        bts     [eax + legacy.slot_t.app.except_mask], ecx

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.user_unmap ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.26
;-----------------------------------------------------------------------------------------------------------------------
        stdcall user_unmap, ecx, edx, esi
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc load_pe_driver stdcall, file:dword ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        stdcall load_PE, [file]
        test    eax, eax
        jz      .fail

        mov     esi, eax
        stdcall eax, DRV_ENTRY
        test    eax, eax
        jz      .fail

        mov     [eax + Service.entry], esi
        ret

  .fail:
        xor     eax, eax
        ret
endp


align 4
;-----------------------------------------------------------------------------------------------------------------------
proc init_mtrr ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [boot_var.enable_mtrr], 2
        je      .exit

        bt      [cpu_caps], CAPS_MTRR
        jnc     .exit

        call    cache_disable

        mov     ecx, 0x2ff
        rdmsr
        ; has BIOS already initialized MTRRs?
        test    ah, 8
        jnz     .skip_init
        ; rarely needed, so mainly placeholder
        ; main memory - cached
        push    eax

        mov     eax, [MEM_AMOUNT]
        ; round eax up to next power of 2
        dec     eax
        bsr     ecx, eax
        mov     ebx, 2
        shl     ebx, cl
        dec     ebx
        ; base of memory range = 0, type of memory range = MEM_WB
        xor     edx, edx
        mov     eax, MEM_WB
        mov     ecx, 0x200
        wrmsr
        ; mask of memory range = 0xFFFFFFFFF - (size - 1), ebx = size - 1
        mov     eax, 0xffffffff
        mov     edx, 0x0000000f
        sub     eax, ebx
        sbb     edx, 0
        or      eax, 0x0800
        inc     ecx
        wrmsr
        ; clear unused MTRRs
        xor     eax, eax
        xor     edx, edx

    @@: wrmsr
        inc     ecx
        cmp     ecx, 0x210
        jb      @b
        ; enable MTRRs
        pop     eax
        or      ah, 8
        and     al, 0xf0 ; default memtype = UC
        mov     ecx, 0x2ff
        wrmsr

  .skip_init:
        stdcall set_mtrr, [LFBRange.address], [LFBRange.size], MEM_WC

        wbinvd  ; again invalidate

        call    cache_enable

  .exit:
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc set_mtrr stdcall, base:dword, size:dword, mem_type:dword ;/////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; find unused register
        mov     ecx, 0x201

    @@: rdmsr
        dec     ecx
        test    ah, 8
        jz      .found
        rdmsr
        mov     al, 0 ; clear memory type field
        cmp     eax, [base]
        jz      .ret
        add     ecx, 3
        cmp     ecx, 0x210
        jb      @b
        ; no free registers, ignore the call

  .ret:
        ret

  .found:
        ; found, write values
        xor     edx, edx
        mov     eax, [base]
        or      eax, [mem_type]
        wrmsr

        mov     ebx, [size]
        dec     ebx
        mov     eax, 0xffffffff
        mov     edx, 0x00000000
        sub     eax, ebx
        sbb     edx, 0
        or      eax, 0x0800
        inc     ecx
        wrmsr
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc create_ring_buffer stdcall, size:dword, flags:dword ;//////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  buf_ptr  dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [size]
        test    eax, eax
        jz      .fail

        add     eax, eax
        stdcall alloc_kernel_space, eax
        test    eax, eax
        jz      .fail

        push    ebx

        mov     [buf_ptr], eax

        mov     ebx, [size]
        shr     ebx, 12
        push    ebx

        stdcall alloc_pages, ebx
        pop     ecx

        test    eax, eax
        jz      .mm_fail

        push    edi

        or      eax, [flags]
        mov     edi, [buf_ptr]
        mov     ebx, [buf_ptr]
        mov     edx, ecx
        shl     edx, 2
        shr     edi, 10

    @@: mov     [page_tabs + edi], eax
        mov     [page_tabs + edi + edx], eax
        invlpg  [ebx]
        invlpg  [ebx + 0x10000]
        add     eax, 0x1000
        add     ebx, 0x1000
        add     edi, 4
        dec     ecx
        jnz     @b

        mov     eax, [buf_ptr]
        pop     edi
        pop     ebx
        ret

  .mm_fail:
        stdcall free_kernel_space, [buf_ptr]
        xor     eax, eax
        pop     ebx

  .fail:
        ret
endp
