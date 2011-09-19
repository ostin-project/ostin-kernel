;;======================================================================================================================
;;///// floppy_ctl.asm ///////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

FLOPPY_CTL_DOR  = 0x3f2
FLOPPY_CTL_MSR  = 0x3f4
FLOPPY_CTL_FIFO = 0x3f5
FLOPPY_CTL_CCR  = 0x3f7

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.reset ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        call    blkdev.floppy.ctl._.prepare_for_interrupt

        push    eax edx
        mov     dx, FLOPPY_CTL_DOR
        mov     al, 0
        out     dx, al
        mov     al, 0x0c
        out     dx, al
        pop     edx eax

        call    blkdev.floppy.ctl._.wait_for_interrupt
        call    blkdev.floppy.ctl._.sense_interrupt
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.perform_dma_transfer ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read/write sector
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= pack[8(?), 8(DMA mode), 8(ST0 mask), 8(operation)]
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< FDD_DataBuffer ^= sector content (on success)
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx
        call    blkdev.floppy.ctl._.select_drive

        ; set transfer speed to 500 KB/s
        shl     eax, 8
        mov     dx, FLOPPY_CTL_CCR
        out     dx, al

        ; initialize DMA channel
        rol     eax, 8
        call    blkdev.floppy.ctl._.init_dma

        call    blkdev.floppy.ctl._.prepare_for_interrupt

        ; send read/write command
        shr     eax, 16
        call    blkdev.floppy.ctl._.out_byte
        mov     al, [ebx + blkdev.floppy.device_data_t.position.head]
        shl     al, 2
        call    blkdev.floppy.ctl._.out_byte
        mov     al, [ebx + blkdev.floppy.device_data_t.position.cylinder]
        call    blkdev.floppy.ctl._.out_byte
        mov     al, [ebx + blkdev.floppy.device_data_t.position.head]
        call    blkdev.floppy.ctl._.out_byte
        mov     al, [ebx + blkdev.floppy.device_data_t.position.sector]
        call    blkdev.floppy.ctl._.out_byte
        mov     al, 2 ; sector size code (512 bytes)
        call    blkdev.floppy.ctl._.out_byte
        mov     al, 18 ; number of sectors on track
        call    blkdev.floppy.ctl._.out_byte
        mov     al, 0x1b ; GPL value
        call    blkdev.floppy.ctl._.out_byte
        mov     al, 0xff ; DTL value
        call    blkdev.floppy.ctl._.out_byte

        ; wait for operation completion
        call    blkdev.floppy.ctl._.wait_for_interrupt
        cmp     eax, FDC_Normal
        jne     .exit

        ; get operation status
        call    blkdev.floppy.ctl._.get_status
        mov     al, [esp + 4 + 1]
        test    [ebx + blkdev.floppy.device_data_t.status.st0], al
        jnz     .error
        mov     eax, FDC_Normal
        jmp     .exit

  .error:
        mov     eax, FDC_SectorNotFound

  .exit:
        call    blkdev.floppy.ctl._.update_motor_timer
        pop     edx
        add     esp, 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.seek ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Seek to track
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        call    blkdev.floppy.ctl._.select_drive

        call    blkdev.floppy.ctl._.prepare_for_interrupt

        ; send "seek" command
        mov     al, 0x0f
        call    blkdev.floppy.ctl._.out_byte
        ; send head number
        mov     al, [ebx + blkdev.floppy.device_data_t.position.head]
        shl     al, 2
        call    blkdev.floppy.ctl._.out_byte
        ; send track number
        mov     al, [ebx + blkdev.floppy.device_data_t.position.cylinder]
        call    blkdev.floppy.ctl._.out_byte

        ; wait for operation to complete
        call    blkdev.floppy.ctl._.wait_for_interrupt
        cmp     eax, FDC_Normal
        jne     .exit

        call    blkdev.floppy.ctl._.sense_interrupt
        ; seek complete?
        test    [ebx + blkdev.floppy.device_data_t.status.st0], 0100000b
        je      .error
        ; specified track found?
        mov     al, [ebx + blkdev.floppy.device_data_t.status.cylinder]
        cmp     al, [ebx + blkdev.floppy.device_data_t.position.cylinder]
        jne     .error
        ; specified head found?
        mov     al, [ebx + blkdev.floppy.device_data_t.status.st0]
        and     al, 0100b
        shr     al, 2
        cmp     al, [ebx + blkdev.floppy.device_data_t.position.head]
        jne     .error

        ; operation completed successfully
        mov     eax, FDC_Normal
        jmp     .exit

  .error:
        ; track not found
        mov     eax, FDC_TrackNotFound

  .exit:
        call    blkdev.floppy.ctl._.update_motor_timer
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.recalibrate ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Recalibrate drive
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        call    blkdev.floppy.ctl._.select_drive

        call    blkdev.floppy.ctl._.prepare_for_interrupt

        ; send recalibrate command
        mov     al, 0x07
        call    blkdev.floppy.ctl._.out_byte
        mov     al, 0
        call    blkdev.floppy.ctl._.out_byte

        ; wait for operation completion
        call    blkdev.floppy.ctl._.wait_for_interrupt

        call    blkdev.floppy.ctl._.sense_interrupt

        call    blkdev.floppy.ctl._.update_motor_timer
        pop     eax
        ret
kendp

;;======================================================================================================================
;;///// private functions //////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

uglobal
  blkdev.floppy.ctl._.data:
    .interrupt_flag    db ?
    .last_drive_number db ? ; TODO: set to -1 on init
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.update_motor_timer ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Save FDD motor timer
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  [ebx + blkdev.floppy.device_data_t.motor_timer], [timer_ticks]

        ; TODO: remove this
        push    eax
        mov     al, [blkdev.floppy.ctl._.data.last_drive_number]
        inc     al
        mov     [flp_number], al
        mov     [fdd_motor_status], al
        mov_s_  [timer_fdd_motor], [timer_ticks]
        pop     eax

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.select_drive ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Save FDD motor timer
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx

        mov     cl, [ebx + blkdev.floppy.device_data_t.drive_number]
        cmp     cl, [blkdev.floppy.ctl._.data.last_drive_number]
        jne     .select_and_start_motor
        cmp     [ebx + blkdev.floppy.device_data_t.motor_timer], 0
        jne     .exit

  .select_and_start_motor:
        mov     dx, FLOPPY_CTL_DOR
        mov     al, 00010000b
        shl     al, cl
        or      al, cl
        or      al, 00001100b
        out     dx, al

        mov     [blkdev.floppy.ctl._.data.last_drive_number], cl

        ; reset timer tick counter
        mov     ecx, [timer_ticks]

  .wait_for_motor:
        ; wait for ~3 sec
        call    change_task
        mov     eax, [timer_ticks]
        sub     eax, ecx
        cmp     eax, 3 * 18
        jb      .wait_for_motor

  .exit:
        call    blkdev.floppy.ctl._.update_motor_timer
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.init_dma ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Initialize FDC DMA mode
;-----------------------------------------------------------------------------------------------------------------------
;> al #= DMA mode (0x46 - read from floppy, 0x4a - write to floppy)
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        xchg    al, ah
        mov     al, 6 ; mask channel 2 so we can reprogram it.
        out     0x0a, al
        xchg    al, ah
        out     0x0b, al
        mov     al, 0
        out     0x0c, al ; reset the flip-flop to a known state.
        mov     eax, FDD_BUFF - OS_BASE
        out     0x04, al ; set the channel 2 starting address to 0
        shr     eax, 8
        out     0x04, al
        shr     eax, 8
        out     0x81, al
        mov     al, 0
        out     0x0c, al ; reset flip-flop
        mov     al, 0xff ; set count (actual size -1)
        out     0x05, al
        mov     al, 0x01 ; block size (0x1ff = 511, 0x23ff = 9215)
        out     0x05, al
        mov     al, 2
        out     0x0a, al
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.out_byte ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write byte to FDC data port
;-----------------------------------------------------------------------------------------------------------------------
;> al = byte to write
;-----------------------------------------------------------------------------------------------------------------------
;< eflags[cf] ~= timeout error
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx
        mov     ah, al ; save byte in AH
        ; check if controller is ready to transfer data
        mov     dx, FLOPPY_CTL_MSR ; (FDC status port)
        mov     ecx, 0x10000 ; set timeout counter

  .test_rs:
        in      al, dx ; read RS register
        and     al, 0xc0 ; get bits 6 and 7
        cmp     al, 0x80 ; check bits 6 and 7
        je      .write_byte
        loop    .test_rs

        ; timeout error
        stc
        jmp     .exit

  .write_byte:
        ; write byte to data port
        inc     dx
        mov     al, ah
        out     dx, al
        clc

  .exit:
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.in_byte ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read byte from FDC data port
;-----------------------------------------------------------------------------------------------------------------------
;< al #= byte read (on success)
;< eflags[cf] ~= timeout error
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx
        ; check if controller is ready to transfer data
        mov     dx, FLOPPY_CTL_MSR ; (FDC status port)
        mov     ecx, 0x10000 ; set timeout counter

  .test_rs:
        in      al, dx ; read RS register
        and     al, 0xc0 ; get bits 6 and 7
        cmp     al, 0xc0 ; check bits 6 and 7
        je      .read_byte
        loop    .test_rs

        ; timeout error
        stc
        jmp     .exit

  .read_byte:
        ; read byte from data port
        inc     dx
        in      al, dx
        clc

  .exit:
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.get_status ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get operation status
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.st0], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.st1], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.st2], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.cylinder], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.head], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.sector], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.sector_size], al
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.sense_interrupt ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x08
        call    blkdev.floppy.ctl._.out_byte
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.st0], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.cylinder], al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.prepare_for_interrupt ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; reset interrupt flag
        and     [blkdev.floppy.ctl._.data.interrupt_flag], 0
        ; replace interrupt handler
        mov     [fdc_irq_func], .raise_fdc_interrupt_flag
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .raise_fdc_interrupt_flag: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        inc     [blkdev.floppy.ctl._.data.interrupt_flag]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.wait_for_interrupt ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Wait for FDC interrupt
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx

        ; reset timer tick counter
        mov     ecx, [timer_ticks]

  .check_flag:
        ; reset controller error code
        mov     eax, FDC_Normal

        ; check if FDC interrupt flag is set
        cmp     [blkdev.floppy.ctl._.data.interrupt_flag], 0
        jne     .exit ; interrupt occurred

        call    change_task

        ; check for timeout (~3 sec)
        mov     eax, [timer_ticks]
        sub     eax, ecx
        cmp     eax, 3 * 18
        jb      .check_flag

        ; timeout error
        mov     eax, FDC_TimeOut

  .exit:
        mov     [fdc_irq_func], util.noop
        pop     ecx
        ret
kendp
