;;======================================================================================================================
;;///// memory.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

struct blk.memory.device_data_t
  data       memory_range32_t
  needs_free db ?
ends

iglobal
  jump_table blk.memory, vftbl, blk.not_implemented, \
    destroy, \
    read, \
    write
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.memory.create ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Create memory device.
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= data (0 to allocate)
;> ecx #= size (in blocks)
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= blk.memory.device_data_t (0 on error)
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx eax

        mov     eax, sizeof.blk.memory.device_data_t
        call    malloc
        test    eax, eax
        jz      .cant_alloc_device_data_error

        xchg    eax, ebx

        and     [ebx + blk.memory.device_data_t.needs_free], 0

        pop     eax
        test    eax, eax
        jnz     .set_data

        mov     eax, [esp]
        test    eax, not (0xffffffff shr 9)
        jnz     .cant_alloc_data_error

        shl     eax, 9
        push    eax
        call    kernel_alloc
        test    eax, eax
        jz      .cant_alloc_data_error

        inc     [ebx + blk.memory.device_data_t.needs_free]

  .set_data:
        mov     [ebx + blk.memory.device_data_t.data.address], eax
        pop     [ebx + blk.memory.device_data_t.data.size]

        xchg    eax, ebx
        pop     ebx
        ret

  .cant_alloc_data_error:
        xchg    eax, ebx
        call    free

        xor     eax, eax
        push    eax

  .cant_alloc_device_data_error:
        add     esp, 4
        pop     ecx ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.memory.destroy ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Destroy memory device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.memory.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [ebx + blk.memory.device_data_t.needs_free], 0
        je      .free_device_data

        push    [ebx + blk.memory.device_data_t.data.address]
        call    kernel_free

  .free_device_data:
        mov     eax, ebx
        call    free
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.memory.read ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read from memory device.
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of blocks to read)
;> edx:eax #= offset (in blocks)
;> ebx ^= blk.memory.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 4 GiB
        test    edx, edx
        jnz     .overflow_error
        test    eax, not (0xffffffff shr 9)
        jnz     .overflow_error

        ; check that read range lies inside device data range
        mov     edx, eax
        add     edx, ecx
        jc      .overflow_error
        test    edx, not (0xffffffff shr 9)
        jnz     .overflow_error
        cmp     edx, [ebx + blk.memory.device_data_t.data.size]
        ja      .overflow_error

        ; copy data to the supplied buffer
        push    esi edi
        mov     esi, [ebx + blk.memory.device_data_t.data.address]
        shl     eax, 9
        add     esi, eax
        shl     ecx, 9
        rep
        movsb
        pop     edi esi

        xor     eax, eax
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.memory.write ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write to memory device.
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of blocks to write)
;> edx:eax #= offset (in blocks)
;> ebx ^= blk.memory.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 4 GiB
        test    edx, edx
        jnz     .overflow_error
        test    eax, not (0xffffffff shr 9)
        jnz     .overflow_error

        ; check that write range lies inside device data range
        mov     edx, eax
        add     edx, ecx
        jc      .overflow_error
        test    edx, not (0xffffffff shr 9)
        jnz     .overflow_error
        cmp     edx, [ebx + blk.memory.device_data_t.data.size]
        ja      .overflow_error

        ; copy data from the supplied buffer
        push    esi edi
        mov     edi, [ebx + blk.memory.device_data_t.data.address]
        shl     eax, 9
        add     edi, eax
        shl     ecx, 9
        rep
        movsb
        pop     edi esi

        xor     eax, eax
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp
