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

struct blk.floppy.chs_t
  ; sector coordinates
  cylinder db ?
  head     db ?
  sector   db ?
ends

struct blk.floppy.status_t
  ; operation result block
  st0         db ?
  st1         db ?
  st2         db ?
  position    blk.floppy.chs_t
  sector_size db ?
ends

struct blk.floppy.device_data_t
  position     blk.floppy.chs_t
  status       blk.floppy.status_t
  drive_number db ?
  motor_timer  dd ?
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
;< eax ^= blk.floppy.device_data_t (0 on error)
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.destroy ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Destroy floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.device_data_t
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
;> ebx ^= blk.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 4 GiB
        test    edx, edx
        jnz     .overflow_error
        test    eax, not (0xffffffff shr 9)
        jnz     .overflow_error

        push    ecx esi edi

  .next_sector:
        push    eax
        call    blk.floppy._.calculate_chs

        ; read sector
        mov     eax, blk.floppy._.read_sector
        call    blk.floppy._.perform_operation_with_retry
        test    eax, eax
        jnz     .exit

        ; copy sector data from FDC DMA buffer to the supplied buffer
        push    ecx
        mov     ecx, BLK_FLOPPY_CTL_BYTES_PER_SECTOR / 4
        mov     esi, FDC_DMA_BUFFER
        rep
        movsd
        pop     ecx

        pop     eax
        inc     eax
        dec     ecx
        jnz     .next_sector

        xor     eax, eax
        push    eax

  .exit:
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
;> ebx ^= blk.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; check that offset is below 4 GiB
        test    edx, edx
        jnz     .overflow_error
        test    eax, not (0xffffffff shr 9)
        jnz     .overflow_error

        push    ecx esi edi

  .next_sector:
        push    eax
        call    blk.floppy._.calculate_chs

        ; copy sector data from the supplied buffer to FDC DMA buffer
        push    ecx
        mov     ecx, BLK_FLOPPY_CTL_BYTES_PER_SECTOR / 4
        mov     edi, FDC_DMA_BUFFER
        rep
        movsd
        pop     ecx

        ; write sector
        mov     eax, blk.floppy._.write_sector
        call    blk.floppy._.perform_operation_with_retry
        test    eax, eax
        jnz     .exit

        pop     eax
        inc     eax
        dec     ecx
        jnz     .next_sector

        xor     eax, eax
        push    eax

  .exit:
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
kproc blk.floppy._.read_sector ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read sector from floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.device_data_t
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
;> ebx ^= blk.floppy.device_data_t
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
;> ebx ^= blk.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx ebp

        mov     ebp, eax

        ; try recalibrating 3 times
        mov_s_  ecx, 3

  .next_seek_attempt:
        push    ecx

        call    blk.floppy.ctl.seek
        ; TODO: check for seek error

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

        call    blk.floppy.ctl.recalibrate

        pop     ecx
        dec     ecx
        jnz     .next_seek_attempt

        mov     eax, -123 ; TODO: add error code
        jmp     .exit

  .free_stack_and_exit:
        add     esp, 8

  .exit:
        pop     ebp ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy._.calculate_chs ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Convert physical address to CHS.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= LBA
;> ebx ^= blk.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx

        mov     ecx, BLK_FLOPPY_CTL_SECTORS_PER_TRACK
        xor     edx, edx
        div     ecx
        inc     edx
        mov     [ebx + blk.floppy.device_data_t.position.sector], dl
        xor     edx, edx
        mov     ecx, BLK_FLOPPY_CTL_HEADS_PER_CYLINDER
        div     ecx
        mov     [ebx + blk.floppy.device_data_t.position.cylinder], al
        mov     [ebx + blk.floppy.device_data_t.position.head], dl

  .exit:
        pop     edx ecx eax
        ret
kendp
