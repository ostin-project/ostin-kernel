;;======================================================================================================================
;;///// heap.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2006-2010 KolibriOS team <http://kolibrios.org/>
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

struct memory_block_t linked_list_t
  prev_block dd ?
  next_block dd ?
  range      memory_range32_t
  flags      dd ?
  handle     dd ?
ends

macro CalcIndex _op
{
        shr     _op, 12
        dec     _op
        cmp     _op, 63
        jna     @f
        mov     _op, 63

    @@:
}

uglobal
  mem_block_list: rb 64 * sizeof.linked_list_t
  mem_used_list:  rb 64 * sizeof.linked_list_t
  mem_hash_cnt    rd 64
  heap_mutex      mutex_t
  heap_size       rd 1
  heap_free       rd 1
  heap_blocks     rd 1
  free_blocks     rd 1
  mem_block_mask  rd 2
  next_memblock   rd 1
  shmem_list      linked_list_t
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc md.add_to_used ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [esi + memory_block_t.range.address]
        mov     ebx, [esi + memory_block_t.range.address]
        shr     ebx, 6
        add     eax, ebx
        shr     ebx, 6
        add     eax, ebx
        shr     eax, 12
        and     eax, 63
        inc     [mem_hash_cnt + eax * 4]
 
        lea     ecx, [mem_used_list + eax * sizeof.linked_list_t]
        ListPrepend esi, ecx
        mov     [esi + memory_block_t.flags], USED_BLOCK
        mov     eax, [esi + memory_block_t.range.size]
        sub     [heap_free], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc md.find_used ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, eax
        mov     ebx, eax
        shr     ebx, 6
        add     ecx, ebx
        shr     ebx, 6
        add     ecx, ebx
        shr     ecx, 12
        and     ecx, 63
 
        lea     ebx, [mem_used_list + ecx * sizeof.linked_list_t]
        mov     esi, ebx

  .next:
        mov     esi, [esi + linked_list_t.next_ptr]
        cmp     esi, ebx
        je      .fail
 
        cmp     eax, [esi + memory_block_t.range.address]
        jne     .next
 
        ret

  .fail:
        xor     esi, esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc md.del_from_used ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    md.find_used
        test    esi, esi
        jz      .done
 
        cmp     [esi + memory_block_t.flags], USED_BLOCK
        jne     .fatal
 
        dec     [mem_hash_cnt + ecx * 4]
        ListDelete esi

  .done:
        ret

  .fatal:
        ; FIXME panic here
        xor     esi, esi
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc init_kernel_heap ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Initial heap state:
;?   +heap_size terminator USED_BLOCK
;?   +4096*MEM_BLOCK.sizeof free space FREE_BLOCK
;?   HEAP_BASE heap_descriptors USED_BLOCK
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, 64
        mov     edi, mem_block_list

    @@: mov     eax, edi
        stosd
        stosd
        loop    @b

        mov     ecx, 64
        mov     edi, mem_used_list

    @@: mov     eax, edi
        stosd
        stosd
        loop    @b

        stdcall alloc_pages, 32
        mov     ecx, 32
        mov     edx, eax
        mov     edi, HEAP_BASE

  .l1:
        stdcall map_page, edi, edx, PG_SW
        add     edi, 0x1000
        add     edx, 0x1000
        dec     ecx
        jnz     .l1

        mov     edi, HEAP_BASE ; descriptors
        mov     ebx, HEAP_BASE + sizeof.memory_block_t ; free space
        mov     ecx, HEAP_BASE + 2 * sizeof.memory_block_t ; terminator

        xor     eax, eax
        mov     [edi + memory_block_t.next_block], ebx
        mov     [edi + memory_block_t.prev_block], eax
        mov     [edi + memory_block_t.next_ptr], eax
        mov     [edi + memory_block_t.prev_ptr], eax
        mov     [edi + memory_block_t.range.address], HEAP_BASE
        mov     [edi + memory_block_t.range.size], 4096 * sizeof.memory_block_t
        mov     [edi + memory_block_t.flags], USED_BLOCK

        mov     [ecx + memory_block_t.next_block], eax
        mov     [ecx + memory_block_t.prev_block], ebx
        mov     [edi + memory_block_t.next_ptr], eax
        mov     [edi + memory_block_t.prev_ptr], eax
        mov     [edi + memory_block_t.range.address], eax
        mov     [edi + memory_block_t.range.size], eax
        mov     [edi + memory_block_t.flags], USED_BLOCK

        mov     [ebx + memory_block_t.next_block], ecx
        mov     [ebx + memory_block_t.prev_block], edi
        mov     [ebx + memory_block_t.range.address], HEAP_BASE + 4096 * sizeof.memory_block_t

        mov     ecx, [pg_data.kernel_pages]
        shl     ecx, 12
        sub     ecx, HEAP_BASE - OS_BASE + 4096 * sizeof.memory_block_t
        mov     [heap_size], ecx
        mov     [heap_free], ecx
        mov     [ebx + memory_block_t.range.size], ecx
        mov     [ebx + memory_block_t.flags], FREE_BLOCK

        mov     [mem_block_mask], eax
        mov     [mem_block_mask + 4], 0x80000000

        mov     ecx, mem_block_list + 63 * sizeof.linked_list_t
        ListPrepend ebx, ecx
 
        mov     ecx, 4096 - 3 - 1
        mov     eax, HEAP_BASE + 4 * sizeof.memory_block_t
 
        mov     [next_memblock], HEAP_BASE + 3 * sizeof.memory_block_t

    @@: mov     [eax - sizeof.memory_block_t + memory_block_t.next_ptr], eax
        add     eax, sizeof.memory_block_t
        loop    @b
 
        mov     [eax - sizeof.memory_block_t + memory_block_t.next_ptr], 0

        mov     ecx, heap_mutex
        call    mutex_init

        mov     [heap_blocks], 4094
        mov     [free_blocks], 4093
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_small_block ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = required size
;-----------------------------------------------------------------------------------------------------------------------
;< edi = memory block descriptor
;< ebx = descriptor index
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, eax
        shr     ecx, 12
        dec     ecx
        cmp     ecx, 63
        jle     .get_index
        mov     ecx, 63

  .get_index:
        lea     esi, [mem_block_mask]
        xor     ebx, ebx
        or      edx, -1

        cmp     ecx, 32
        jb      .bit_test

        sub     ecx, 32
        add     ebx, 32
        add     esi, 4

  .bit_test:
        shl     edx, cl
        and     edx, [esi]

  .find:
        bsf     edi, edx
        jz      .high_mask
        add     ebx, edi

        lea     ecx, [mem_block_list + ebx * sizeof.linked_list_t]
        mov     edi, ecx

  .next:
        mov     edi, [edi + memory_block_t.next_ptr]
        cmp     edi, ecx
        je      .err

        cmp     eax, [edi + memory_block_t.range.size]
        ja      .next
        ret

  .err:
        xor     edi, edi
        ret

  .high_mask:
        add     esi, 4
        cmp     esi, mem_block_mask + 8
        jae     .err
        add     ebx, 32
        mov     edx, [esi]
        jmp     .find
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc free_mem_block ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [next_memblock]
        mov     [eax + memory_block_t.next_ptr], ebx
        mov     [next_memblock], eax

        xor     ebx, ebx
        mov     [eax + memory_block_t.prev_ptr], ebx
        mov     [eax + memory_block_t.next_block], ebx
        mov     [eax + memory_block_t.prev_block], ebx
        mov     [eax + memory_block_t.range.address], ebx
;       mov     [eax + memory_block_t.range.size], ebx ; don't clear block size
        mov     [eax + memory_block_t.flags], ebx
        mov     [eax + memory_block_t.handle], ebx

        inc     [free_blocks]
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc alloc_kernel_space stdcall, size:dword ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  block_ind dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    esi
        push    edi

        mov     eax, [size]
        add     eax, 4095
        and     eax, not 4095
        mov     [size], eax

        cmp     eax, [heap_free]
        ja      .error

        mov     ecx, heap_mutex
        call    mutex_lock

        mov     eax, [size]
        call    get_small_block ; eax
        test    edi, edi
        jz      .error_unlock

        cmp     [edi + memory_block_t.flags], FREE_BLOCK
        jne     .error_unlock

        mov     [block_ind], ebx ; index of allocated block

        mov     eax, [edi + memory_block_t.range.size]
        cmp     eax, [size]
        je      .m_eq_size

        mov     esi, [next_memblock] ; new memory block
        test    esi, esi
        jz      .error_unlock

        dec     [free_blocks]
        mov     eax, [esi + memory_block_t.next_ptr]
        mov     [next_memblock], eax

        mov     [esi + memory_block_t.next_block], edi
        mov     eax, [edi + memory_block_t.prev_block]
        mov     [esi + memory_block_t.prev_block], eax
        mov     [edi + memory_block_t.prev_block], esi
        mov     [esi + memory_block_t.next_ptr], 0
        mov     [esi + memory_block_t.prev_ptr], 0
        mov     [eax + memory_block_t.next_block], esi

        mov     ebx, [edi + memory_block_t.range.address]
        mov     [esi + memory_block_t.range.address], ebx
        mov     edx, [size]
        mov     [esi + memory_block_t.range.size], edx
        add     [edi + memory_block_t.range.address], edx
        sub     [edi + memory_block_t.range.size], edx

        mov     eax, [edi + memory_block_t.range.size]
        CalcIndex eax
        cmp     eax, [block_ind]
        je      .add_used

        ListDelete edi

        mov     ecx, [block_ind]
        lea     edx, [mem_block_list + ecx * sizeof.linked_list_t]
        cmp     edx, [edx + linked_list_t.next_ptr]
        jne     @f
        btr     [mem_block_mask], ecx

    @@: bts     [mem_block_mask], eax
        lea     edx, [mem_block_list + eax * sizeof.linked_list_t] ; edx = list head
        ListPrepend edi, edx

  .add_used:
        call    md.add_to_used

        mov     ecx, heap_mutex
        call    mutex_unlock

        mov     eax, [esi + memory_block_t.range.address]
        pop     edi
        pop     esi
        pop     ebx
        ret

  .m_eq_size:
        ListDelete edi
        lea     edx, [mem_block_list + ebx * sizeof.linked_list_t]
        cmp     edx, [edx + linked_list_t.next_ptr]
        jne     @f
        btr     [mem_block_mask], ebx

    @@: mov     esi, edi
        jmp     .add_used

  .error_unlock:
        mov     ecx, heap_mutex
        call    mutex_unlock

  .error:
        xor     eax, eax
        pop     edi
        pop     esi
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc free_kernel_space stdcall uses ebx ecx edx esi edi, base:dword ;///////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, heap_mutex
        call    mutex_lock

        mov     eax, [base]
        call    md.del_from_used
        test    esi, esi
        jz      .fail

        mov     eax, [esi + memory_block_t.range.size]
        add     [heap_free], eax

        mov     edi, [esi + memory_block_t.next_block]
        cmp     [edi + memory_block_t.flags], FREE_BLOCK
        jne     .prev

        ListDelete edi

        mov     edx, [edi + memory_block_t.next_block]
        mov     [esi + memory_block_t.next_block], edx
        mov     [edx + memory_block_t.prev_block], esi
        mov     ecx, [edi + memory_block_t.range.size]
        add     [esi + memory_block_t.range.size], ecx

        CalcIndex ecx
 
        lea     edx, [mem_block_list + ecx * sizeof.linked_list_t]
        cmp     edx, [edx + linked_list_t.next_ptr]
        jne     @f
        btr     [mem_block_mask], ecx

    @@: mov     eax, edi
        call    free_mem_block

  .prev:
        mov     edi, [esi + memory_block_t.prev_block]
        cmp     [edi + memory_block_t.flags], FREE_BLOCK
        jne     .insert

        mov     edx, [esi + memory_block_t.next_block]
        mov     [edi + memory_block_t.next_block], edx
        mov     [edx + memory_block_t.prev_block], edi

        mov     eax, esi
        call    free_mem_block

        mov     ecx, [edi + memory_block_t.range.size]
        mov     eax, [esi + memory_block_t.range.size]
        add     eax, ecx
        mov     [edi + memory_block_t.range.size], eax

        CalcIndex eax ; new index
        CalcIndex ecx ; old index
        cmp     eax, ecx
        je      .m_eq

        push    ecx
        ListDelete edi
        pop     ecx

        lea     edx, [mem_block_list + ecx * sizeof.linked_list_t]
        cmp     edx, [edx + linked_list_t.next_ptr]
        jne     .add_block
        btr     [mem_block_mask], ecx

  .add_block:
        bts     [mem_block_mask], eax
        lea     edx, [mem_block_list + eax * sizeof.linked_list_t]
        ListPrepend edi, edx

  .m_eq:
        mov     ecx, heap_mutex
        call    mutex_unlock

        xor     eax, eax
        not     eax
        ret

  .insert:
        mov     [esi + memory_block_t.flags], FREE_BLOCK
        mov     eax, [esi + memory_block_t.range.size]
        CalcIndex eax
        mov     edi, esi
        jmp     .add_block

  .fail:
        mov     ecx, heap_mutex
        call    mutex_unlock

        xor     eax, eax
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc kernel_alloc stdcall, size:dword ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  lin_addr    dd ?
  pages_count dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    edi

        mov     eax, [size]
        add     eax, 4095
        and     eax, not 4095
        mov     [size], eax
        and     eax, eax
        jz      .err
        mov     ebx, eax
        shr     ebx, 12
        mov     [pages_count], ebx

        stdcall alloc_kernel_space, eax
        test    eax, eax
        jz      .err
        mov     [lin_addr], eax

        mov     ecx, [pages_count]
        mov     edx, eax
        mov     ebx, ecx

        shr     ecx, 3
        jz      .next

        and     ebx, not 7
        push    ebx
        stdcall alloc_pages, ebx
        pop     ecx ; yes ecx!!!
        and     eax, eax
        jz      .err

        mov     edi, eax
        mov     edx, [lin_addr]

    @@: stdcall map_page, edx, edi, PG_SW
        add     edx, 0x1000
        add     edi, 0x1000
        dec     ecx
        jnz     @b

  .next:
        mov     ecx, [pages_count]
        and     ecx, 7
        jz      .end

    @@: push    ecx
        call    alloc_page
        pop     ecx
        test    eax, eax
        jz      .err

        stdcall map_page, edx, eax, PG_SW
        add     edx, 0x1000
        dec     ecx
        jnz     @b

  .end:
        mov     eax, [lin_addr]
        pop     edi
        pop     ebx
        ret

  .err:
        xor     eax, eax
        pop     edi
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc kernel_free stdcall, base:dword ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx esi

        mov     ecx, heap_mutex
        call    mutex_lock

        mov     eax, [base]
        call    md.find_used

        mov     ecx, heap_mutex
        cmp     [esi + memory_block_t.flags], USED_BLOCK
        jne     .fail

        call    mutex_unlock

        mov     eax, [esi + memory_block_t.range.address]
        mov     ecx, [esi + memory_block_t.range.size]
        shr     ecx, 12
        call    release_pages ; eax, ecx
        stdcall free_kernel_space, [base]
        pop     esi ebx
        ret

  .fail:
        call    mutex_unlock
        xor     eax, eax
        pop     esi ebx
        ret
endp

;;;;;;;;;;;;;;      USER     ;;;;;;;;;;;;;;;;;

HEAP_TOP = 0x80000000

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc init_heap ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [current_slot_ptr]
        mov     eax, [ebx + legacy.slot_t.app.heap_top]
        test    eax, eax
        jz      @f
        sub     eax, [ebx + legacy.slot_t.app.heap_base]
        sub     eax, 4096
        ret

    @@: mov     esi, [ebx + legacy.slot_t.app.mem_size]
        add     esi, 4095
        and     esi, not 4095
        mov     [ebx + legacy.slot_t.app.mem_size], esi
        mov     eax, HEAP_TOP
        mov     [ebx + legacy.slot_t.app.heap_base], esi
        mov     [ebx + legacy.slot_t.app.heap_top], eax

        sub     eax, esi
        shr     esi, 10
        mov     ecx, eax
        sub     eax, 4096
        or      ecx, FREE_BLOCK
        mov     [page_tabs + esi], ecx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc user_alloc stdcall, alloc_size:dword ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    esi
        push    edi

        mov     ecx, [alloc_size]
        add     ecx, (4095 + 4096)
        and     ecx, not 4095

        mov     ebx, [current_slot_ptr]
        mov     esi, [ebx + legacy.slot_t.app.heap_base] ; heap_base
        mov     edi, [ebx + legacy.slot_t.app.heap_top] ; heap_top

  .l_0:
        cmp     esi, edi
        jae     .m_exit

        mov     ebx, esi
        shr     ebx, 12
        mov     eax, [page_tabs + ebx * 4]
        test    al, FREE_BLOCK
        jz      .test_used
        and     eax, 0xfffff000
        cmp     eax, ecx ; alloc_size
        jb      .m_next
        jz      @f

        lea     edx, [esi + ecx]
        sub     eax, ecx
        or      al, FREE_BLOCK
        shr     edx, 12
        mov     [page_tabs + edx * 4], eax

    @@: or      ecx, USED_BLOCK
        mov     [page_tabs + ebx * 4], ecx
        shr     ecx, 12
        inc     ebx
        dec     ecx
        jz      .no

    @@: mov     dword[page_tabs + ebx * 4], 2
        inc     ebx
        dec     ecx
        jnz     @b

  .no:
        mov     edx, [current_slot_ptr]
        mov     ebx, [alloc_size]
        add     ebx, 0x0fff
        and     ebx, not 0x0fff
        add     ebx, [edx + legacy.slot_t.app.mem_size]
        call    update_mem_size

        lea     eax, [esi + 4096]

        pop     edi
        pop     esi
        pop     ebx
        ret

  .test_used:
        test    al, USED_BLOCK
        jz      .m_exit

        and     eax, 0xfffff000

  .m_next:
        add     esi, eax
        jmp     .l_0

  .m_exit:
        xor     eax, eax
        pop     edi
        pop     esi
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc user_alloc_at stdcall, address:dword, alloc_size:dword ;///////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    esi
        push    edi

        mov     ebx, [current_slot_ptr]
        mov     edx, [address]
        and     edx, not 0x0fff
        mov     [address], edx
        sub     edx, 0x1000
        jb      .error
        mov     esi, [ebx + legacy.slot_t.app.heap_base]
        mov     edi, [ebx + legacy.slot_t.app.heap_top]
        cmp     edx, esi
        jb      .error

  .scan:
        cmp     esi, edi
        jae     .error
        mov     ebx, esi
        shr     ebx, 12
        mov     eax, [page_tabs + ebx * 4]
        mov     ecx, eax
        and     ecx, 0xfffff000
        add     ecx, esi
        cmp     edx, ecx
        jb      .found
        mov     esi, ecx
        jmp     .scan

  .error:
        xor     eax, eax
        pop     edi
        pop     esi
        pop     ebx
        ret

  .found:
        test    al, FREE_BLOCK
        jz      .error
        mov     eax, ecx
        sub     eax, edx
        sub     eax, 0x1000
        cmp     eax, [alloc_size]
        jb      .error

        ; Here we have 1 big free block which includes requested area.
        ; In general, 3 other blocks must be created instead:
        ; free at [esi, edx);
        ; busy at [edx, edx+0x1000+ALIGN_UP(alloc_size,0x1000));
        ; free at [edx+0x1000+ALIGN_UP(alloc_size,0x1000), ecx)
        ; First or third block (or both) may be absent.
        mov     eax, edx
        sub     eax, esi
        jz      .nofirst
        or      al, FREE_BLOCK
        mov     [page_tabs + ebx * 4], eax

  .nofirst:
        mov     eax, [alloc_size]
        add     eax, 0x1fff
        and     eax, not 0x0fff
        mov     ebx, edx
        add     edx, eax
        shr     ebx, 12
        or      al, USED_BLOCK
        mov     [page_tabs + ebx * 4], eax
        shr     eax, 12
        dec     eax
        jz      .second_nofill
        inc     ebx

  .fill:
        mov     dword[page_tabs + ebx * 4], 2
        inc     ebx
        dec     eax
        jnz     .fill

  .second_nofill:
        sub     ecx, edx
        jz      .nothird
        or      cl, FREE_BLOCK
        mov     [page_tabs + ebx * 4], ecx

  .nothird:
        mov     edx, [current_slot_ptr]
        mov     ebx, [alloc_size]
        add     ebx, 0x0fff
        and     ebx, not 0x0fff
        add     ebx, [edx + legacy.slot_t.app.mem_size]
        call    update_mem_size

        mov     eax, [address]

        pop     edi
        pop     esi
        pop     ebx
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc user_free stdcall, base:dword ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    esi

        mov     esi, [base]
        test    esi, esi
        jz      .exit

        push    ebx

        xor     ebx, ebx
        shr     esi, 12
        mov     eax, [page_tabs + (esi - 1) * 4]
        test    al, USED_BLOCK
        jz      .cantfree
        test    al, DONT_FREE_BLOCK
        jnz     .cantfree

        and     eax, not 4095
        mov     ecx, eax
        or      al, FREE_BLOCK
        mov     [page_tabs + (esi - 1) * 4], eax
        sub     ecx, 4096
        mov     ebx, ecx
        shr     ecx, 12
        jz      .released

  .release:
        xor     eax, eax
        xchg    eax, [page_tabs + esi * 4]
        test    al, 1
        jz      @f
        test    eax, PG_SHARED
        jnz     @f
        call    free_page
        mov     eax, esi
        shl     eax, 12
        invlpg  [eax]

    @@: inc     esi
        dec     ecx
        jnz     .release

  .released:
        push    edi

        mov     edx, [current_slot_ptr]
        mov     esi, [edx + legacy.slot_t.app.heap_base]
        mov     edi, [edx + legacy.slot_t.app.heap_top]
        sub     ebx, [edx + legacy.slot_t.app.mem_size]
        neg     ebx
        call    update_mem_size
        call    user_normalize
        pop     edi
        pop     ebx
        pop     esi
        ret

  .exit:
        xor     eax, eax
        inc     eax
        pop     esi
        ret

  .cantfree:
        xor     eax, eax
        pop     ebx
        pop     esi
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc user_unmap stdcall, base:dword, offset:dword, size:dword ;/////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx

        mov     ebx, [base] ; must be valid pointer
        test    ebx, ebx
        jz      .error

        mov     edx, [offset] ; check offset
        add     edx, ebx ; must be below 2Gb app limit
        js      .error

        shr     ebx, 12 ; chek block attributes
        lea     ebx, [page_tabs + ebx * 4]
        mov     eax, [ebx - 4] ; block attributes
        test    al, USED_BLOCK
        jz      .error
        test    al, DONT_FREE_BLOCK
        jnz     .error

        shr     edx, 12
        lea     edx, [page_tabs + edx * 4] ; unmap offset

        mov     ecx, [size]
        add     ecx, 4095
        shr     ecx, 12 ; unmap size in pages

        shr     eax, 12 ; block size + 1 page
        lea     ebx, [ebx + eax * 4 - 4] ; block end ptr
        lea     eax, [edx + ecx * 4] ; unmap end ptr

        cmp     eax, ebx ; check for overflow
        ja      .error

        mov     ebx, [offset]
        and     ebx, not 4095 ; is it required?

  .unmap:
        mov     eax, [edx] ; get page addres
        test    al, 1 ; page mapped ?
        jz      @F
        test    eax, PG_SHARED ; page shared?
        jnz     @F
        mov     dword[page_tabs + edx * 4], 2 ; mark page as reserved

        invlpg  [ebx] ; when we start using
        call    free_page ; empty c-o-w page instead this?

    @@: add     ebx, 4096
        add     edx, 4
        dec     ecx
        jnz     .unmap

        pop     ebx
        or      al, 1 ; return non zero on success
        ret

  .error:
        pop     ebx
        xor     eax, eax ; something wrong
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc user_normalize ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi = heap_base
;> edi = heap_top
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or 1 (error)
;-----------------------------------------------------------------------------------------------------------------------
;# destroys: ebx, edx, esi, edi
;-----------------------------------------------------------------------------------------------------------------------
        shr     esi, 12
        shr     edi, 12

    @@: mov     eax, [page_tabs + esi * 4]
        test    al, USED_BLOCK
        jz      .test_free
        shr     eax, 12
        add     esi, eax
        jmp     @b

  .test_free:
        test    al, FREE_BLOCK
        jz      .err
        mov     edx, eax
        shr     edx, 12
        add     edx, esi
        cmp     edx, edi
        jae     .exit

        mov     ebx, [page_tabs + edx * 4]
        test    bl, USED_BLOCK
        jz      .next_free

        shr     ebx, 12
        add     edx, ebx
        mov     esi, edx
        jmp     @b

  .next_free:
        test    bl, FREE_BLOCK
        jz      .err
        and     dword[page_tabs + edx * 4], 0
        add     eax, ebx
        and     eax, not 4095
        or      eax, FREE_BLOCK
        mov     [page_tabs + esi * 4], eax
        jmp     @b

  .exit:
        xor     eax, eax
        inc     eax
        ret

  .err:
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc user_realloc ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pointer
;> ebx = new size
;-----------------------------------------------------------------------------------------------------------------------
;< eax = new pointer or NULL
;-----------------------------------------------------------------------------------------------------------------------
        test    eax, eax
        jnz     @f
        ; realloc(NULL,sz) - same as malloc(sz)
        push    ebx
        call    user_alloc
        ret

    @@: push    ecx edx
        lea     ecx, [eax - 0x1000]
        shr     ecx, 12
        mov     edx, [page_tabs + ecx * 4]
        test    dl, USED_BLOCK
        jnz     @f
        ; attempt to realloc invalid pointer

  .ret0:
        pop     edx ecx
        xor     eax, eax
        ret

    @@: test    dl, DONT_FREE_BLOCK
        jnz     .ret0
        add     ebx, 0x1fff
        shr     edx, 12
        shr     ebx, 12
        ; edx = allocated size, ebx = new size
        add     edx, ecx
        add     ebx, ecx
        cmp     edx, ebx
        jb      .realloc_add

  .loop:
        ; release part of allocated memory
        cmp     edx, ebx
        jz      .release_done
        dec     edx
        xor     eax, eax
        xchg    eax, [page_tabs + edx * 4]
        test    al, 1
        jz      .loop
        call    free_page
        mov     eax, edx
        shl     eax, 12
        invlpg  [eax]
        jmp     .loop

  .release_done:
        sub     ebx, ecx
        cmp     ebx, 1
        jnz     .nofreeall
        mov     eax, [page_tabs + ecx * 4]
        and     eax, not 0x0fff
        mov     edx, [current_slot_ptr]
        mov     ebx, [edx + legacy.slot_t.app.mem_size]
        sub     ebx, eax
        add     ebx, 0x1000
        or      al, FREE_BLOCK
        mov     [page_tabs + ecx * 4], eax
        push    esi edi
        mov     esi, [edx + legacy.slot_t.app.heap_base]
        mov     edi, [edx + legacy.slot_t.app.heap_top]
        call    update_mem_size
        call    user_normalize
        pop     edi esi
        jmp     .ret0 ; all freed

  .nofreeall:
        sub     edx, ecx
        shl     ebx, 12
        or      ebx, USED_BLOCK
        xchg    [page_tabs + ecx * 4], ebx
        shr     ebx, 12
        sub     ebx, edx
        push    ebx ecx edx
        mov     edx, [current_slot_ptr]
        shl     ebx, 12
        sub     ebx, [edx + legacy.slot_t.app.mem_size]
        neg     ebx
        call    update_mem_size
        pop     edx ecx ebx
        lea     eax, [ecx + 1]
        shl     eax, 12
        push    eax
        add     ecx, edx
        lea     edx, [ecx + ebx]
        shl     ebx, 12
        jz      .ret
        push    esi
        mov     esi, [current_slot_ptr]
        mov     esi, [esi + legacy.slot_t.app.heap_top]
        shr     esi, 12

    @@: cmp     edx, esi
        jae     .merge_done
        mov     eax, [page_tabs + edx * 4]
        test    al, USED_BLOCK
        jnz     .merge_done
        and     dword[page_tabs + edx * 4], 0
        shr     eax, 12
        add     edx, eax
        shl     eax, 12
        add     ebx, eax
        jmp     @b

  .merge_done:
        pop     esi
        or      ebx, FREE_BLOCK
        mov     [page_tabs + ecx * 4], ebx

  .ret:
        pop     eax edx ecx
        ret

  .realloc_add:
        ; get some additional memory
        mov     eax, [current_slot_ptr]
        mov     eax, [eax + legacy.slot_t.app.heap_top]
        shr     eax, 12
        cmp     edx, eax
        jae     .cant_inplace
        mov     eax, [page_tabs + edx * 4]
        test    al, FREE_BLOCK
        jz      .cant_inplace
        shr     eax, 12
        add     eax, edx
        sub     eax, ebx
        jb      .cant_inplace
        jz      @f
        shl     eax, 12
        or      al, FREE_BLOCK
        mov     [page_tabs + ebx * 4], eax

    @@: mov     eax, ebx
        sub     eax, ecx
        shl     eax, 12
        or      al, USED_BLOCK
        mov     [page_tabs + ecx * 4], eax
        lea     eax, [ecx + 1]
        shl     eax, 12
        push    eax
        push    edi
        lea     edi, [page_tabs + edx * 4]
        mov     eax, 2
        sub     ebx, edx
        mov     ecx, ebx
        rep
        stosd
        pop     edi
        mov     edx, [current_slot_ptr]
        shl     ebx, 12
        add     ebx, [edx + legacy.slot_t.app.mem_size]
        call    update_mem_size
        pop     eax edx ecx
        ret

  .cant_inplace:
        push    esi edi
        mov     eax, [current_slot_ptr]
        mov     esi, [eax + legacy.slot_t.app.heap_base]
        mov     edi, [eax + legacy.slot_t.app.heap_top]
        shr     esi, 12
        shr     edi, 12
        sub     ebx, ecx

  .find_place:
        cmp     esi, edi
        jae     .place_not_found
        mov     eax, [page_tabs + esi * 4]
        test    al, FREE_BLOCK
        jz      .next_place
        shr     eax, 12
        cmp     eax, ebx
        jae     .place_found
        add     esi, eax
        jmp     .find_place

  .next_place:
        shr     eax, 12
        add     esi, eax
        jmp     .find_place

  .place_not_found:
        pop     edi esi
        jmp     .ret0

  .place_found:
        sub     eax, ebx
        jz      @f
        push    esi
        add     esi, ebx
        shl     eax, 12
        or      al, FREE_BLOCK
        mov     [page_tabs + esi * 4], eax
        pop     esi

    @@: mov     eax, ebx
        shl     eax, 12
        or      al, USED_BLOCK
        mov     [page_tabs + esi * 4], eax
        inc     esi
        mov     eax, esi
        shl     eax, 12
        push    eax
        mov     eax, [page_tabs + ecx * 4]
        and     eax, not 0xfff
        or      al, FREE_BLOCK
        sub     edx, ecx
        mov     [page_tabs + ecx * 4], eax
        inc     ecx
        dec     ebx
        dec     edx
        jz      .no

    @@: xor     eax, eax
        xchg    eax, [page_tabs + ecx * 4]
        mov     [page_tabs + esi * 4], eax
        mov     eax, ecx
        shl     eax, 12
        invlpg  [eax]
        inc     esi
        inc     ecx
        dec     ebx
        dec     edx
        jnz     @b

  .no:
        push    ebx
        mov     edx, [current_slot_ptr]
        shl     ebx, 12
        add     ebx, [edx + legacy.slot_t.app.mem_size]
        call    update_mem_size
        pop     ebx

    @@: mov     dword[page_tabs + esi * 4], 2
        inc     esi
        dec     ebx
        jnz     @b
        pop     eax edi esi edx ecx
        ret
kendp

if 0

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc alloc_dll ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushf
        cli
        bsf     eax, [dll_map]
        jnz     .find
        popf
        xor     eax, eax
        ret

  .find:
        btr     [dll_map], eax
        popf
        shl     eax, 5
        add     eax, dll_tab
        ret
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc alloc_service ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushf
        cli
        bsf     eax, [srv_map]
        jnz     .find
        popf
        xor     eax, eax
        ret

  .find:
        btr     [srv_map], eax
        popf
        shl     eax, 0x02
        lea     eax, [srv_tab + eax + eax * 8] ; srv_tab + eax * 36
        ret
endp

end if

;;;;;;;;;;;;;;      SHARED      ;;;;;;;;;;;;;;;;;

;-----------------------------------------------------------------------------------------------------------------------
kproc destroy_smap ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = shm_map object
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli

        push    esi
        push    edi

        mov     edi, eax
        mov     esi, [eax + smap_t.parent]
        test    esi, esi
        jz      .done

        lock
        dec     [esi + smem_t.refcount]
        jnz     .done

        mov     ecx, [esi + smem_t.prev_ptr]
        mov     edx, [esi + smem_t.next_ptr]

        mov     [ecx + smem_t.next_ptr], edx
        mov     [edx + smem_t.prev_ptr], ecx

        stdcall kernel_free, [esi + smem_t.range.address]
        mov     eax, esi
        call    free

  .done:
        mov     eax, edi
        call    destroy_kernel_object

        pop     edi
        pop     esi
        popfd

        ret
kendp

E_NOTFOUND      = 5
E_ACCESS        = 10
E_NOMEM         = 30
E_PARAM         = 33

SHM_READ        = 0
SHM_WRITE       = 1

SHM_ACCESS_MASK = 3

SHM_OPEN        = (0 shl 2)
SHM_OPEN_ALWAYS = (1 shl 2)
SHM_CREATE      = (2 shl 2)

SHM_OPEN_MASK   = (3 shl 2)

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc shmem_open stdcall name:dword, size:dword, access:dword ;//////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  action       dd ?
  owner_access dd ?
  mapped       dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    esi
        push    edi

        mov     [mapped], 0
        mov     [owner_access], 0

        pushfd  ; mutex required
        cli

        mov     eax, [access]
        and     eax, SHM_OPEN_MASK
        mov     [action], eax

        mov     ebx, [name]
        test    ebx, ebx
        mov     edx, E_PARAM
        jz      .fail

        mov     esi, [shmem_list.next_ptr]

align 4

    @@: cmp     esi, shmem_list
        je      .not_found

        lea     edx, [esi + smem_t.name] ; link, base, size
        stdcall strncmp, edx, ebx, 32
        test    eax, eax
        je      .found

        mov     esi, [esi + smem_t.next_ptr]
        jmp     @b

  .not_found:
        mov     eax, [action]

        cmp     eax, SHM_OPEN
        mov     edx, E_NOTFOUND
        je      .fail

        cmp     eax, SHM_CREATE
        mov     edx, E_PARAM
        je      .create_shm

        cmp     eax, SHM_OPEN_ALWAYS
        jne     .fail

  .create_shm:
        mov     ecx, [size]
        test    ecx, ecx
        jz      .fail

        add     ecx, 4095
        and     ecx, -4096
        mov     [size], ecx

        mov     eax, sizeof.smem_t
        call    malloc
        test    eax, eax
        mov     esi, eax
        mov     edx, E_NOMEM
        jz      .fail

        stdcall kernel_alloc, [size]
        test    eax, eax
        mov     [mapped], eax
        mov     edx, E_NOMEM
        jz      .cleanup

        mov     ecx, [size]
        mov     edx, [access]
        and     edx, SHM_ACCESS_MASK

        mov     [esi + smem_t.range.address], eax
        mov     [esi + smem_t.range.size], ecx
        mov     [esi + smem_t.access], edx
        mov     [esi + smem_t.refcount], 0
        mov     [esi + smem_t.name + 28], 0

        lea     eax, [esi + smem_t.name]
        stdcall strncpy, eax, [name], 31

        mov     eax, [shmem_list.next_ptr]
        mov     [esi + smem_t.prev_ptr], shmem_list
        mov     [esi + smem_t.next_ptr], eax

        mov     [eax + smem_t.prev_ptr], esi
        mov     [shmem_list.next_ptr], esi

        mov     [action], SHM_OPEN
        mov     [owner_access], SHM_WRITE

  .found:
        mov     eax, [action]

        cmp     eax, SHM_CREATE
        mov     edx, E_ACCESS
        je      .exit

        cmp     eax, SHM_OPEN
        mov     edx, E_PARAM
        je      .create_map

        cmp     eax, SHM_OPEN_ALWAYS
        jne     .fail

  .create_map:
        mov     eax, [access]
        and     eax, SHM_ACCESS_MASK
        cmp     eax, [esi + smem_t.access]
        mov     [access], eax
        mov     edx, E_ACCESS
        ja      .fail

        mov     ebx, [current_slot_ptr]
        mov     ebx, [ebx + legacy.slot_t.task.pid]
        mov     eax, sizeof.smap_t

        call    create_kernel_object
        test    eax, eax
        mov     edi, eax
        mov     edx, E_NOMEM
        jz      .fail

        inc     [esi + smem_t.refcount]

        mov     [edi + smap_t.magic], 'SMAP'
        mov     [edi + smap_t.destroy], destroy_smap
        mov     [edi + smap_t.parent], esi
        mov     [edi + smap_t.base], 0

        stdcall user_alloc, [esi + smem_t.range.size]
        test    eax, eax
        mov     [mapped], eax
        mov     edx, E_NOMEM
        jz      .cleanup2

        mov     [edi + smap_t.base], eax

        mov     ecx, [esi + smem_t.range.size]
        mov     [size], ecx

        shr     ecx, 12
        shr     eax, 10

        mov     esi, [esi + smem_t.range.address]
        shr     esi, 10
        lea     edi, [page_tabs + eax]
        add     esi, page_tabs

        mov     edx, [access]
        or      edx, [owner_access]
        shl     edx, 1
        or      edx, PG_USER + PG_SHARED

    @@: lodsd
        and     eax, 0xfffff000
        or      eax, edx
        stosd
        loop @b

        xor     edx, edx

        cmp     [owner_access], 0
        jne     .fail

  .exit:
        mov     edx, [size]

  .fail:
        mov     eax, [mapped]

        popfd
        pop     edi
        pop     esi
        pop     ebx
        ret

  .cleanup:
        mov     [size], edx
        mov     eax, esi
        call    free
        jmp     .exit

  .cleanup2:
        mov     [size], edx
        mov     eax, edi
        call    destroy_smap
        jmp     .exit
endp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc shmem_close stdcall, name:dword ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [name]
        test    eax, eax
        jz      .fail

        push    esi
        push    edi
        pushfd
        cli

        mov     esi, [current_slot_ptr]
        add     esi, legacy.slot_t.app.obj

  .next:
        mov     eax, [esi + app_object_t.next_ptr]
        test    eax, eax
        jz      @f

        cmp     eax, esi
        mov     esi, eax
        je      @f

        cmp     [eax + smap_t.magic], 'SMAP'
        jne     .next

        mov     edi, [eax + smap_t.parent]
        test    edi, edi
        jz      .next

        lea     edi, [edi + smem_t.name]
        stdcall strncmp, [name], edi, 32
        test    eax, eax
        jne     .next

        stdcall user_free, [esi + smap_t.base]

        mov     eax, esi
        call    [esi + app_object_t.destroy]

    @@: popfd
        pop     edi
        pop     esi

  .fail:
        ret
endp

purge CalcIndex, RemoveFromList, RemoveFromFree, RemoveFromUsed
