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

struct blkdev.memory.device_info_t
  data_ptr  dd ?
  data_size dd ?
ends

iglobal
  jump_table blkdev.memory, vftbl, , \
    read, \
    write
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.memory.read ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of bytes to read)
;> edx:eax #= offset
;> ebx ^= blkdev.memory.device_info_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        or      edx, edx
        jnz     .overflow_error

        lea     eax, [ecx + edx]
        cmp     eax, [ebx + blkdev.memory.device_info_t.data_size]
        ja      .overflow_error

        push    esi
        mov     esi, [ebx + blkdev.memory.device_info_t.data_ptr]
        add     esi, edx
        rep     movsb
        pop     esi
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.memory.write ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of bytes to write)
;> edx:eax #= offset
;> ebx ^= blkdev.memory.device_info_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        or      edx, edx
        jnz     .overflow_error

        lea     eax, [ecx + edx]
        cmp     eax, [ebx + blkdev.memory.device_info_t.data_size]
        ja      .overflow_error

        push    edi
        mov     edi, [ebx + blkdev.memory.device_info_t.data_ptr]
        add     edi, edx
        rep     movsb
        pop     edi
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp
