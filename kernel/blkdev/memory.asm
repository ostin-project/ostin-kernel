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

struct blkdev.memory.device_data_t
  data       range32_t
  needs_free db ?
ends

iglobal
  jump_table blkdev.memory, vftbl, , \
    destroy, \
    read, \
    write
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.memory.create ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Create memory device.
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= data (0 to allocate)
;> ecx #= size
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= blkdev.memory.device_data_t (0 on error)
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx eax

        mov     eax, sizeof.blkdev.memory.device_data_t
        call    malloc
        or      eax, eax
        jz      .cant_alloc_device_data_error

        xchg    eax, ebx

        and     [ebx + blkdev.memory.device_data_t.needs_free], 0

        pop     eax
        test    eax, eax
        jnz     .set_data

        push    dword[esp]
        call    kernel_alloc
        test    eax, eax
        jz      .cant_alloc_data_error

        inc     [ebx + blkdev.memory.device_data_t.needs_free]

  .set_data:
        mov     [ebx + blkdev.memory.device_data_t.data.offset], eax
        pop     [ebx + blkdev.memory.device_data_t.data.length]

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
kproc blkdev.memory.destroy ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Destroy memory device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.memory.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [ebx + blkdev.memory.device_data_t.needs_free], 0
        je      .free_device_data

        push    [ebx + blkdev.memory.device_data_t.data.offset]
        call    kernel_free

  .free_device_data:
        mov     eax, ebx
        call    free
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.memory.read ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read from memory device.
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of bytes to read)
;> edx:eax #= offset
;> ebx ^= blkdev.memory.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 4 GiB
        or      edx, edx
        jnz     .overflow_error

        ; check that read range lies inside device data range
        mov     edx, eax
        add     edx, ecx
        jc      .overflow_error
        cmp     edx, [ebx + blkdev.memory.device_data_t.data.length]
        ja      .overflow_error

        ; copy data to the supplied buffer
        push    esi edi
        mov     esi, [ebx + blkdev.memory.device_data_t.data.offset]
        add     esi, eax
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
kproc blkdev.memory.write ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write to memory device.
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of bytes to write)
;> edx:eax #= offset
;> ebx ^= blkdev.memory.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 4 GiB
        or      edx, edx
        jnz     .overflow_error

        ; check that write range lies inside device data range
        mov     edx, eax
        add     edx, ecx
        jc      .overflow_error
        cmp     edx, [ebx + blkdev.memory.device_data_t.data.length]
        ja      .overflow_error

        ; copy data from the supplied buffer
        push    esi edi
        mov     edi, [ebx + blkdev.memory.device_data_t.data.offset]
        add     edi, eax
        rep
        movsb
        pop     edi esi

        xor     eax, eax
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp
