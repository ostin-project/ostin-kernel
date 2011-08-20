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

struct blkdev.floppy.chs_t
  ; sector coordinates
  cylinder db ?
  head     db ?
  sector   db ?
ends

struct blkdev.floppy.status_t
  ; operation result block
  st0         db ?
  st1         db ?
  st2         db ?
  cylinder    db ?
  head        db ?
  sector      db ?
  sector_size db ?
ends

struct blkdev.floppy.device_info_t
  position     blkdev.floppy.chs_t
  status       blkdev.floppy.status_t
  drive_number db ?
  motor_timer  dd ?
ends

iglobal
  jump_table blkdev.floppy, vftbl, , \
    read, \
    write
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.read ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of bytes to read)
;> edx:eax #= offset
;> ebx ^= blkdev.floppy.device_info_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        or      edx, edx
        jnz     .overflow_error
        test    eax, 511
        jnz     .alignment_error
        test    ecx, 511
        jnz     .alignment_error

        push    ecx esi

  .next_sector:
        push    eax
        call    blkdev.floppy._.calculate_chs

        mov     eax, blkdev.floppy._.read_sector
        call    blkdev.floppy._.perform_operation_with_retry
        or      eax, eax
        jnz     .exit

        push    ecx
        cmp     ecx, 512
        jb      @f
        mov     ecx, 512

    @@: mov     esi, FDD_BUFF
        rep     movsb
        pop     ecx

        pop     eax
        add     eax, 512
        add     ecx, -512
        jg      .next_sector

        xor     eax, eax
        push    eax

  .exit:
        add     esp, 4
        pop     esi ecx
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret

  .alignment_error:
        mov     eax, -321 ; TODO: add error code
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.write ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of bytes to write)
;> edx:eax #= offset
;> ebx ^= blkdev.floppy.device_info_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        or      edx, edx
        jnz     .overflow_error
        test    eax, 511
        jnz     .alignment_error
        test    ecx, 511
        jnz     .alignment_error

        push    ecx edi

  .next_sector:
        push    eax
        call    blkdev.floppy._.calculate_chs

        push    ecx
        cmp     ecx, 512
        jb      @f
        mov     ecx, 512

    @@: mov     edi, FDD_BUFF
        rep     movsb
        pop     ecx

        mov     eax, blkdev.floppy._.write_sector
        call    blkdev.floppy._.perform_operation_with_retry
        or      eax, eax
        jnz     .exit

        pop     eax
        add     eax, 512
        add     ecx, -512
        jg      .next_sector

        xor     eax, eax
        push    eax

  .exit:
        add     esp, 4
        pop     edi ecx
        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret

  .alignment_error:
        mov     eax, -321 ; TODO: add error code
        ret
kendp

;;======================================================================================================================
;;///// private functions //////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy._.read_sector ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read sector
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_info_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< FDD_DataBuffer ^= sector content (on success)
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0xe6 ; reading in multi-track mode
        mov     ah, 11011000b
        jmp     blkdev.floppy.ctl.perform_dma_transfer
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy._.write_sector ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write sector
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_info_t
;> FDD_DataBuffer ^= sector content to write
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0xc5 ; writing in multi-track mode
        mov     ah, 11000000b
        jmp     blkdev.floppy.ctl.perform_dma_transfer
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy._.perform_operation_with_retry ;////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read sector (retry on errors)
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= operation callback (read/write sector)
;> ebx ^= blkdev.floppy.device_info_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx ebp

        mov     ebp, eax

        ; try recalibrating 3 times
        mov_s_  ecx, 3

  .next_seek_attempt:
        push    ecx

        call    blkdev.floppy.ctl.seek

        ; try reading 3 times
        mov_s_  ecx, 3

  .next_read_attempt:
        push    ecx

        call    ebp
        cmp     eax, FDC_Normal
        je      .exit
        cmp     eax, FDC_TimeOut
        je      .timeout_error

        pop     ecx
        dec     ecx
        jnz     .next_read_attempt

        call    blkdev.floppy.ctl.recalibrate

        pop     ecx
        dec     ecx
        jnz     .next_seek_attempt

        mov     eax, -123 ; TODO: add error code
        jmp     .exit

  .timeout_error:
        add     esp, 8

  .exit:
        pop     ebp ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy._.calculate_chs ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= LBA address
;> ebx ^= blkdev.floppy.device_info_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx
        mov_s_  ecx, 18
        xor     edx, edx
        div     ecx
        inc     edx
        mov     [ebx + blkdev.floppy.device_info_t.position.sector], dl
        xor     edx, edx
        mov_s_  ecx, 2
        div     ecx
        mov     [ebx + blkdev.floppy.device_info_t.position.cylinder], al
        mov     [ebx + blkdev.floppy.device_info_t.position.head], 0
        test    edx, edx
        jz      .exit
        inc     [ebx + blkdev.floppy.device_info_t.position.head]

  .exit:
        pop     edx ecx eax
        ret
kendp
