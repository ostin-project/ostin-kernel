;;======================================================================================================================
;;///// floppy.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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

struct blk.floppy.device_t blk.device_t
  ctl          dd ? ; ^= blk.floppy.ctl.device_t
  drive_number db ?
ends

iglobal
  jump_table blk.floppy, vftbl, blk.not_implemented, \
    destroy, \
    read, \
    write
endg

include "floppy_ctl.asm"

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.create ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Create floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= blk.floppy.device_t (0 on error)
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.destroy ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Destroy floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.device_t
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.read ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read from floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of blocks to read)
;> edx:eax #= offset (in blocks)
;> ebx ^= blk.floppy.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 4 GiB
        test    edx, edx
        jnz     .overflow_error
        test    eax, not (0xffffffff shr 9)
        jnz     .overflow_error

        ; TODO: lock controller

        call    blk.floppy._.select_drive

        push    ecx esi edi

  .next_sector:
        push    eax ecx

        call    blk.floppy._.lba_to_chs

        ; read sector
        mov     eax, blk.floppy._.read_sector
        call    blk.floppy._.perform_operation_with_retry
        test    eax, eax
        jnz     .exit

        ; copy sector data from FDC DMA buffer to the supplied buffer
        mov     ecx, BLK_FLOPPY_CTL_BYTES_PER_SECTOR / 4
        mov     esi, FDC_DMA_BUFFER
        rep
        movsd

        pop     ecx eax
        inc     eax
        dec     ecx
        jnz     .next_sector

        xor     eax, eax
        push    eax

  .exit:
        ; TODO: unlock controller

        add     esp, 4
        pop     edi esi ecx
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.write ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write to floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of blocks to write)
;> edx:eax #= offset (in blocks)
;> ebx ^= blk.floppy.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 4 GiB
        test    edx, edx
        jnz     .overflow_error
        test    eax, not (0xffffffff shr 9)
        jnz     .overflow_error

        ; TODO: lock controller

        call    blk.floppy._.select_drive

        push    ecx esi edi

  .next_sector:
        push    eax ecx

        ; copy sector data from the supplied buffer to FDC DMA buffer
        mov     ecx, BLK_FLOPPY_CTL_BYTES_PER_SECTOR / 4
        mov     edi, FDC_DMA_BUFFER
        rep
        movsd

        call    blk.floppy._.lba_to_chs

        ; write sector
        mov     eax, blk.floppy._.write_sector
        call    blk.floppy._.perform_operation_with_retry
        test    eax, eax
        jnz     .exit

        pop     ecx eax
        inc     eax
        dec     ecx
        jnz     .next_sector

        xor     eax, eax
        push    eax

  .exit:
        ; TODO: unlock controller

        add     esp, 4
        pop     edi esi ecx
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp

;;======================================================================================================================
;;///// private functions //////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy._.select_drive ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Select floppy drive.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx
        mov     al, [ebx + blk.floppy.device_t.drive_number]
        mov     ebx, [ebx + blk.floppy.device_t.ctl]
        call    blk.floppy.ctl.select_drive
        pop     ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy._.read_sector ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read sector from floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< FDC_DMA_BUFFER ^= sector content (on success)
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, (0x46 shl 16) + (11011000b shl 8) + 0xe6 ; reading in multi-track mode
        jmp     blk.floppy.ctl.perform_dma_transfer
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy._.write_sector ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write sector to floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.ctl.device_t
;> FDC_DMA_BUFFER ^= sector content to write
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, (0x4a shl 16) + (11000000b shl 8) + 0xc5 ; writing in multi-track mode
        jmp     blk.floppy.ctl.perform_dma_transfer
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy._.perform_operation_with_retry ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Perform retriable floppy device operation.
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= operation callback (read/write sector)
;> ebx ^= blk.floppy.device_t
;> ecx @= pack[8(?), 8(sector), 8(head), 8(cylinder)]
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx ebp

        mov     ebx, [ebx + blk.floppy.device_t.ctl]
        mov     ebp, eax

        ; try recalibrating 3 times
        mov_s_  ecx, 3

  .next_seek_attempt:
        push    ecx

        mov     eax, [esp + 4 + 4]
        call    blk.floppy.ctl.seek
        test    eax, eax
        jnz     .recalibrate

        ; try reading 3 times
        mov_s_  ecx, 3

  .next_read_attempt:
        push    ecx

        call    ebp
        test    eax, eax ; BLK_FLOPPY_CTL_ERROR_SUCCESS
        jz      .free_stack_and_exit
        cmp     eax, BLK_FLOPPY_CTL_ERROR_TIMEOUT
        jne     @f

        ; controller timed out, need to reset
        call    blk.floppy.ctl.reset

    @@: pop     ecx
        dec     ecx
        jnz     .next_read_attempt

  .recalibrate:
        call    blk.floppy.ctl.recalibrate

        pop     ecx
        dec     ecx
        jnz     .next_seek_attempt

        mov     eax, -123 ; TODO: add error code
        jmp     .exit

  .free_stack_and_exit:
        add     esp, 8

  .exit:
        pop     ebp ecx ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy._.lba_to_chs ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Convert physical address to CHS.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= LBA
;> ebx ^= blk.floppy.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< ecx @= pack[8(?), 8(sector), 8(head), 8(cylinder)]
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx

        mov     ecx, BLK_FLOPPY_CTL_SECTORS_PER_TRACK
        xor     edx, edx
        div     ecx
        inc     edx

        push    edx

        xor     edx, edx
        mov     ecx, BLK_FLOPPY_CTL_HEADS_PER_CYLINDER
        div     ecx

        pop     ecx
        shl     ecx, 16
        mov     ch, dl
        mov     cl, al

  .exit:
        pop     edx eax
        ret
kendp
