;;======================================================================================================================
;;///// atapi.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

struct blk.atapi.device_data_t blk.ata.device_data_t
ends

iglobal
  jump_table blk.atapi, vftbl, blk.not_implemented, \
    destroy, \
    read, \
    -
endg

include "atapi_ctl.asm"

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.create ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Create ATAPI device.
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= blk.atapi.device_data_t (0 on error)
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.destroy ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Destroy ATAPI device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.read ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read from ATAPI device.
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of blocks to read)
;> edx:eax #= offset (in blocks)
;> ebx ^= blk.atapi.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
;# ATAPI drives have block size of 2048 bytes (4 * 512), hence the checks and further normalization
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 8 TiB
        test    edx, 0xfffffffc
        jnz     .overflow_error
        test    al, 0x03
        jnz     .alignment_error
        test    cl, 0x03
        jnz     .alignment_error

        ; TODO: lock controller

        push    ebx ecx edx

        push    eax
        mov     al, [ebx + blk.atapi.device_data_t.drive_number]
        mov     ebx, [ebx + blk.atapi.device_data_t.ctl]
        call    blk.ata.ctl.select_drive
        pop     eax

        shrd    eax, edx, 2
        shr     ecx, 2

        push    10 ; retry count

  .retry:
        push    eax ecx edx edi

        call    blk.atapi.ctl.read
        test    eax, eax
        jz      .exit

        pop     edi edx ecx eax

        dec     byte[esp]
        jnz     .retry

  .exit:
        pop     edi edx ecx
        add     esp, 4 + 4
        pop     edx ecx ebx

        ; TODO: unlock controller

        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret

  .alignment_error:
        mov     eax, -234 ; TODO: add error code
        ret
kendp
