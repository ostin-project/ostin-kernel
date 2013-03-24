;;======================================================================================================================
;;///// atapi.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011-2012 Ostin project <http://ostin.googlecode.com/>
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

struct blk.atapi.device_t blk.ata.device_t
ends

iglobal
  blk.atapi.last_index  dd 0
  blk.atapi.name_prefix db 'atapi', 0

  JumpTable blk.atapi, vftbl, blk.not_implemented, \
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
;> eax ^= blk.atapi.ctl.device_t
;> cl #= drive number
;> edx ^= ident buffer
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= blk.atapi.device_t (0 on error)
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    eax ecx edx

        mov     eax, sizeof.blk.atapi.device_t
        call    malloc
        test    eax, eax
        jz      .exit

        xchg    eax, ebx

        mov     [ebx + blk.atapi.device_t._.vftbl], blk.atapi.vftbl

        lea     eax, [ebx + blk.ata.device_t._.partitions]
        mov     [ebx + blk.ata.device_t._.partitions.next_ptr], eax
        mov     [ebx + blk.ata.device_t._.partitions.prev_ptr], eax

        mov     eax, [esp + 8]
        mov     [ebx + blk.atapi.device_t.ctl], eax
        mov     al, [esp + 4]
        mov     [ebx + blk.atapi.device_t.drive_number], al

        mov     esi, [esp]
        lea     edi, [ebx + blk.atapi.device_t.ident]
        mov     ecx, 512 / 4
        rep
        movsd

        ; TODO: check supported command packet set
;       mov     edx, [esp]
;       movzx   edx, byte[edx + 0 + 1]
;       and     edx, 0x1f

        mov     eax, blk.atapi.name_prefix
        mov     ecx, [blk.atapi.last_index]
        call    blk.set_device_name

        inc     [blk.atapi.last_index]

        xchg    eax, ebx

  .exit:
        add     esp, 12
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.destroy ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Destroy ATAPI device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, ebx
        call    free
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
;> ebx ^= blk.atapi.device_t
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
        mov     al, [ebx + blk.atapi.device_t.drive_number]
        mov     ebx, [ebx + blk.atapi.device_t.ctl]
        call    blk.ata.ctl.select_drive
        pop     eax

        shrd    eax, edx, 2
        shr     ecx, 2

        push    10 ; retry count

  .retry:
        push    eax ecx edx edi

        call    blk.atapi.ctl.read
        test    eax, eax
        jz      .done

        pop     edi edx ecx eax

        dec     byte[esp]
        jnz     .retry
        jmp     .exit

  .done:
        pop     edi edx ecx
        add     esp, 4

  .exit:
        add     esp, 4
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
