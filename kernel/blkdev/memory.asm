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
  data range32_t
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
;> ebx ^= blkdev.memory.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        or      edx, edx
        jnz     .overflow_error
        lea     edx, [eax + ecx]
        cmp     edx, [ebx + blkdev.memory.device_data_t.data.length]
        ja      .overflow_error
        test    eax, 511
        jnz     .alignment_error
        test    ecx, 511
        jnz     .alignment_error

        push    esi edi
        mov     esi, [ebx + blkdev.memory.device_data_t.data.offset]
        add     esi, eax
        rep     movsb
        pop     edi esi

        xor     eax, eax
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret

  .alignment_error:
        mov     eax, -321 ; TODO: add error code
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.memory.write ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of bytes to write)
;> edx:eax #= offset
;> ebx ^= blkdev.memory.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        or      edx, edx
        jnz     .overflow_error
        lea     edx, [eax + ecx]
        cmp     edx, [ebx + blkdev.memory.device_data_t.data.length]
        ja      .overflow_error
        test    eax, 511
        jnz     .alignment_error
        test    ecx, 511
        jnz     .alignment_error

        push    esi edi
        mov     edi, [ebx + blkdev.memory.device_data_t.data.offset]
        add     edi, eax
        rep     movsb
        pop     edi esi

        xor     eax, eax
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret

  .alignment_error:
        mov     eax, -321 ; TODO: add error code
        ret
kendp
