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

; FDC error codes
FLOPPY_CTL_ERROR_SUCCESS          = 0 ; ok
FLOPPY_CTL_ERROR_TIMEOUT          = 1 ; timeout
;FLOPPY_CTL_ERROR_NO_DISK         = 2 ; no disk in drive (not used)
FLOPPY_CTL_ERROR_TRACK_NOT_FOUND  = 3 ; track not found
FLOPPY_CTL_ERROR_SECTOR_NOT_FOUND = 4 ; sector not found

; FDC registers
FLOPPY_CTL_DOR  = 0x3f2
FLOPPY_CTL_MSR  = 0x3f4
FLOPPY_CTL_FIFO = 0x3f5
FLOPPY_CTL_CCR  = 0x3f7

; FDC [not so] constants
FLOPPY_CTL_HEADS_PER_CYLINDER = 2
FLOPPY_CTL_SECTORS_PER_TRACK  = 18
FLOPPY_CTL_BYTES_PER_SECTOR   = 512

iglobal
  blkdev.floppy.ctl.irq_func dd util.noop
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.initialize ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, static_test_floppy_device_data
        call    blkdev.floppy.ctl.reset

        or      [blkdev.floppy.ctl._.data.last_drive_number], -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.reset ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Reset floppy device controller.
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
;? Perform floppy device DMA data transfer.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= pack[8(?), 8(DMA mode), 8(ST0 mask), 8(operation)]
;> ebx ^= blkdev.floppy.device_data_t
;> FDC_DMA_BUFFER ^= sector content (on write)
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code (one of FDC_*)
;< FDC_DMA_BUFFER ^= sector content (on successful read)
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
        or      al, [ebx + blkdev.floppy.device_data_t.drive_number]
        call    blkdev.floppy.ctl._.out_byte
        mov     al, [ebx + blkdev.floppy.device_data_t.position.cylinder]
        call    blkdev.floppy.ctl._.out_byte
        mov     al, [ebx + blkdev.floppy.device_data_t.position.head]
        call    blkdev.floppy.ctl._.out_byte
        mov     al, [ebx + blkdev.floppy.device_data_t.position.sector]
        call    blkdev.floppy.ctl._.out_byte
        mov     al, 2 ; sector size code (512 bytes)
        call    blkdev.floppy.ctl._.out_byte
        mov     al, FLOPPY_CTL_SECTORS_PER_TRACK ; number of sectors on track
        call    blkdev.floppy.ctl._.out_byte
        mov     al, 0x1b ; GPL value
        call    blkdev.floppy.ctl._.out_byte
        mov     al, 0xff ; DTL value
        call    blkdev.floppy.ctl._.out_byte

        ; wait for operation completion
        call    blkdev.floppy.ctl._.wait_for_interrupt
        test    eax, eax ; FLOPPY_CTL_ERROR_SUCCESS
        jnz     .exit

        ; get operation status
        call    blkdev.floppy.ctl._.get_status
        mov     al, [esp + 4 + 1]
        test    [ebx + blkdev.floppy.device_data_t.status.st0], al
        jnz     .error

        xor     eax, eax ; FLOPPY_CTL_ERROR_SUCCESS
        jmp     .exit

  .error:
        mov     eax, FLOPPY_CTL_ERROR_SECTOR_NOT_FOUND

  .exit:
        call    blkdev.floppy.ctl._.update_motor_timer
        pop     edx
        add     esp, 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.seek ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Seek to floppy track.
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
        test    eax, eax ; FLOPPY_CTL_ERROR_SUCCESS
        jnz     .exit

        call    blkdev.floppy.ctl._.sense_interrupt
        ; seek complete?
        test    [ebx + blkdev.floppy.device_data_t.status.st0], 0100000b
        je      .error
        ; specified track found?
        mov     al, [ebx + blkdev.floppy.device_data_t.status.position.cylinder]
        cmp     al, [ebx + blkdev.floppy.device_data_t.position.cylinder]
        jne     .error
        ; specified head found?
        mov     al, [ebx + blkdev.floppy.device_data_t.status.st0]
        and     al, 0100b
        shr     al, 2
        cmp     al, [ebx + blkdev.floppy.device_data_t.position.head]
        jne     .error

        ; operation completed successfully
        xor     eax, eax ; FLOPPY_CTL_ERROR_SUCCESS
        jmp     .exit

  .error:
        ; track not found
        mov     eax, FLOPPY_CTL_ERROR_TRACK_NOT_FOUND

  .exit:
        call    blkdev.floppy.ctl._.update_motor_timer
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.recalibrate ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Recalibrate floppy device.
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

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl.process_events ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Process FDC events which might have occured.
;-----------------------------------------------------------------------------------------------------------------------
;# Called from main OS loop.
;-----------------------------------------------------------------------------------------------------------------------
        ; TODO: make use of dynamic device data (not yet implemented)
        mov     ebx, static_test_floppy_device_data
        call    blkdev.floppy.ctl._.check_motor_timer
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
;? Save FDD motor timer.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  [ebx + blkdev.floppy.device_data_t.motor_timer], dword[timer_ticks]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.check_motor_timer ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Check for FDD motor spindown delay.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [ebx + blkdev.floppy.device_data_t.motor_timer]
        test    eax, eax
        jz      .exit

        sub     eax, dword[timer_ticks]
        add     eax, 2 * KCONFIG_SYS_TIMER_FREQ ; ~2 sec
        jg      .exit

        call    blkdev.floppy.ctl._.stop_motor

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.stop_motor ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Turn FDD motor off.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     cl, [ebx + blkdev.floppy.device_data_t.drive_number]

        mov     dx, FLOPPY_CTL_DOR
        mov     al, cl
        or      al, 00001100b
        out     dx, al

        klog_   LOG_DEBUG, "floppy motor #%u spin down\n", cl

        mov     [blkdev.floppy.ctl._.data.last_drive_number], cl
        and     [ebx + blkdev.floppy.device_data_t.motor_timer], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.select_drive ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Select floppy drive to operate on and spin its motor on, if necessary.
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
        ; TODO: check if this stops other drives' motors (which is not acceptable)
        mov     dx, FLOPPY_CTL_DOR
        mov     al, 00010000b
        shl     al, cl
        or      al, cl
        or      al, 00001100b
        out     dx, al

        klog_   LOG_DEBUG, "floppy motor #%u spin up\n", cl

        mov     [blkdev.floppy.ctl._.data.last_drive_number], cl

        ; reset timer tick counter
        mov     ecx, dword[timer_ticks]

  .wait_for_motor:
        ; wait for ~1/3 sec
        call    change_task
        mov     eax, dword[timer_ticks]
        sub     eax, ecx
        cmp     eax, KCONFIG_SYS_TIMER_FREQ / 3
        jb      .wait_for_motor

  .exit:
        call    blkdev.floppy.ctl._.update_motor_timer
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.init_dma ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Initialize FDC DMA mode.
;-----------------------------------------------------------------------------------------------------------------------
;> al #= DMA mode flags (0x46 - read from floppy, 0x4a - write to floppy)
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        xchg    al, ah
        mov     al, 6 ; mask channel 2 so we can reprogram it
        out     0x0a, al
        xchg    al, ah
        out     0x0b, al

        out     0x0c, al ; reset the flip-flop to a known state

        mov     eax, FDC_DMA_BUFFER - OS_BASE
        out     0x04, al ; set the channel 2 starting address to 0
        shr     eax, 8
        out     0x04, al

        shr     eax, 8 ; eax = 0
        out     0x81, al

        out     0x0c, al ; reset flip-flop

        mov     eax, FLOPPY_CTL_BYTES_PER_SECTOR - 1 ; set count (actual size -1)
        out     0x05, al
        shr     eax, 8
        out     0x05, al

        mov     al, 2
        out     0x0a, al

        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.out_byte ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write byte to FDC data port.
;-----------------------------------------------------------------------------------------------------------------------
;> al #= byte to write
;-----------------------------------------------------------------------------------------------------------------------
;< Cf ~= timeout error
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
;? Read byte from FDC data port.
;-----------------------------------------------------------------------------------------------------------------------
;< al #= byte read (on success)
;< Cf ~= timeout error
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
;? Get FDC operation status.
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
        mov     [ebx + blkdev.floppy.device_data_t.status.position.cylinder], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.position.head], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.position.sector], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.sector_size], al
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.sense_interrupt ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Send 'sense interrupt' command to FDC.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blkdev.floppy.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x08
        call    blkdev.floppy.ctl._.out_byte
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.st0], al
        call    blkdev.floppy.ctl._.in_byte
        mov     [ebx + blkdev.floppy.device_data_t.status.position.cylinder], al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.floppy.ctl._.prepare_for_interrupt ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Prepare for FDC interrupt.
;-----------------------------------------------------------------------------------------------------------------------
        ; reset interrupt flag
        and     [blkdev.floppy.ctl._.data.interrupt_flag], 0
        ; replace interrupt handler
        mov     [blkdev.floppy.ctl.irq_func], .raise_fdc_interrupt_flag
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
;? Wait for FDC interrupt.
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx

        ; reset timer tick counter
        mov     ecx, dword[timer_ticks]

  .check_flag:
        ; reset controller error code
        xor     eax, eax ; FLOPPY_CTL_ERROR_SUCCESS

        ; check if FDC interrupt flag is set
        cmp     [blkdev.floppy.ctl._.data.interrupt_flag], 0
        jne     .exit ; interrupt occurred

        call    change_task

        ; check for timeout (~3 sec)
        mov     eax, dword[timer_ticks]
        sub     eax, ecx
        cmp     eax, 3 * KCONFIG_SYS_TIMER_FREQ
        jb      .check_flag

        ; timeout error
        mov     eax, FLOPPY_CTL_ERROR_TIMEOUT

  .exit:
        mov     [blkdev.floppy.ctl.irq_func], util.noop
        pop     ecx
        ret
kendp
