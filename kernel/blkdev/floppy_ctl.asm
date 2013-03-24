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
BLK_FLOPPY_CTL_ERROR_SUCCESS          = 0 ; ok
BLK_FLOPPY_CTL_ERROR_TIMEOUT          = 1 ; timeout
;BLK_FLOPPY_CTL_ERROR_NO_DISK         = 2 ; no disk in drive (not used)
BLK_FLOPPY_CTL_ERROR_TRACK_NOT_FOUND  = 3 ; track not found
BLK_FLOPPY_CTL_ERROR_SECTOR_NOT_FOUND = 4 ; sector not found

; FDC registers
BLK_FLOPPY_CTL_REG_STATUS_A        = 0 ; 'SRA', read-only
BLK_FLOPPY_CTL_REG_STATUS_B        = 1 ; 'SRB', read-only
BLK_FLOPPY_CTL_REG_DIGITAL_OUTPUT  = 2 ; 'DOR'
BLK_FLOPPY_CTL_REG_TAPE_DRIVE      = 3 ; 'TDR'
BLK_FLOPPY_CTL_REG_MAIN_STATUS     = 4 ; 'MSR', read-only
BLK_FLOPPY_CTL_REG_DATARATE_SELECT = 4 ; 'DSR', write-only
BLK_FLOPPY_CTL_REG_DATA_FIFO       = 5 ; 'FIFO'
BLK_FLOPPY_CTL_REG_DIGITAL_INPUT   = 7 ; 'DIR', read-only
BLK_FLOPPY_CTL_REG_CONFIG_CTL      = 7 ; 'CCR', write-only

; FDC [not so] constants
BLK_FLOPPY_CTL_HEADS_PER_CYLINDER = 2
BLK_FLOPPY_CTL_SECTORS_PER_TRACK  = 18
BLK_FLOPPY_CTL_BYTES_PER_SECTOR   = 512

struct blk.floppy.ctl.status_t
  ; operation result block
  st0         db ?
  st1         db ?
  st2         db ?
  sector_size db ?
ends

struct blk.floppy.ctl.device_t
  base_reg          dw ?
  position          chs8x8x8_t
  status            blk.floppy.ctl.status_t
  motor_timer       rd 4
  last_drive_number db ?
ends

iglobal
  blk.floppy.ctl.irq_func dd util.noop
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl.initialize ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; TODO: make use of dynamic device data (not yet implemented)
        mov     ebx, static_test_floppy_ctl_device_data
        call    blk.floppy.ctl.reset
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl.reset ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Reset floppy device controller.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        call    blk.floppy.ctl._.prepare_for_interrupt

        push    eax edx
        mov     dx, [ebx + blk.floppy.ctl.device_t.base_reg]
        add     dx, BLK_FLOPPY_CTL_REG_DIGITAL_OUTPUT
        mov     al, 0
        out     dx, al
        mov     al, 0x0c
        out     dx, al
        pop     edx eax

        call    blk.floppy.ctl._.wait_for_interrupt
        call    blk.floppy.ctl._.sense_interrupt
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl.perform_dma_transfer ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Perform floppy device DMA data transfer.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= pack[8(?), 8(DMA mode), 8(ST0 mask), 8(operation)]
;> ebx ^= blk.floppy.ctl.device_t
;> FDC_DMA_BUFFER ^= sector content (on write)
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code (one of FDC_*)
;< FDC_DMA_BUFFER ^= sector content (on successful read)
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx

        ; set transfer speed to 500 KB/s
        shl     eax, 8
        mov     dx, [ebx + blk.floppy.ctl.device_t.base_reg]
        add     dx, BLK_FLOPPY_CTL_REG_CONFIG_CTL
        out     dx, al

        ; initialize DMA channel
        rol     eax, 8
        call    blk.floppy.ctl._.init_dma

        call    blk.floppy.ctl._.prepare_for_interrupt

        ; send read/write command
        shr     eax, 16
        call    blk.floppy.ctl._.out_byte
        mov     al, [ebx + blk.floppy.ctl.device_t.position.head]
        shl     al, 2
        or      al, [ebx + blk.floppy.ctl.device_t.last_drive_number]
        call    blk.floppy.ctl._.out_byte
        mov     al, [ebx + blk.floppy.ctl.device_t.position.cylinder]
        call    blk.floppy.ctl._.out_byte
        mov     al, [ebx + blk.floppy.ctl.device_t.position.head]
        call    blk.floppy.ctl._.out_byte
        mov     al, [ebx + blk.floppy.ctl.device_t.position.sector]
        call    blk.floppy.ctl._.out_byte
        mov     al, 2 ; sector size code (512 bytes)
        call    blk.floppy.ctl._.out_byte
        mov     al, BLK_FLOPPY_CTL_SECTORS_PER_TRACK ; number of sectors on track
        call    blk.floppy.ctl._.out_byte
        mov     al, 0x1b ; GPL value
        call    blk.floppy.ctl._.out_byte
        mov     al, 0xff ; DTL value
        call    blk.floppy.ctl._.out_byte

        ; wait for operation completion
        call    blk.floppy.ctl._.wait_for_interrupt
        test    eax, eax ; BLK_FLOPPY_CTL_ERROR_SUCCESS
        jnz     .exit

        ; get operation status
        call    blk.floppy.ctl._.get_status
        mov     al, [esp + 4 + 1]
        test    [ebx + blk.floppy.ctl.device_t.status.st0], al
        jnz     .error

        xor     eax, eax ; BLK_FLOPPY_CTL_ERROR_SUCCESS
        jmp     .exit

  .error:
        mov     eax, BLK_FLOPPY_CTL_ERROR_SECTOR_NOT_FOUND

  .exit:
        call    blk.floppy.ctl._.update_motor_timer
        pop     edx
        add     esp, 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl.seek ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Seek to floppy track.
;-----------------------------------------------------------------------------------------------------------------------
;> eax @= pack[8(?), 8(sector), 8(head), 8(cylinder)]
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        call    blk.floppy.ctl._.prepare_for_interrupt

        ; send "seek" command
        mov     al, 0x0f
        call    blk.floppy.ctl._.out_byte
        ; send head number
        mov     al, [ebx + blk.floppy.ctl.device_t.last_drive_number]
        call    blk.floppy.ctl._.out_byte
        ; send track number
        mov     al, [esp + chs8x8x8_t.cylinder]
        call    blk.floppy.ctl._.out_byte

        ; wait for operation to complete
        call    blk.floppy.ctl._.wait_for_interrupt
        test    eax, eax ; BLK_FLOPPY_CTL_ERROR_SUCCESS
        jnz     .exit

        call    blk.floppy.ctl._.sense_interrupt
        ; seek complete?
        test    [ebx + blk.floppy.ctl.device_t.status.st0], 0100000b
        je      .error

        ; specified track found?
        mov     al, [ebx + blk.floppy.ctl.device_t.position.cylinder]
        cmp     al, [esp + chs8x8x8_t.cylinder]
        jne     .error

        ; operation completed successfully
        mov     al, [esp + chs8x8x8_t.head]
        mov     [ebx + blk.floppy.ctl.device_t.position.head], al
        mov     al, [esp + chs8x8x8_t.sector]
        mov     [ebx + blk.floppy.ctl.device_t.position.sector], al

        xor     eax, eax ; BLK_FLOPPY_CTL_ERROR_SUCCESS
        jmp     .exit

  .error:
        ; track not found
        mov     eax, BLK_FLOPPY_CTL_ERROR_TRACK_NOT_FOUND

  .exit:
        call    blk.floppy.ctl._.update_motor_timer
        add     esp, 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl.recalibrate ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Recalibrate floppy device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

  .retry:
        call    blk.floppy.ctl._.prepare_for_interrupt

        ; send recalibrate command
        mov     al, 0x07
        call    blk.floppy.ctl._.out_byte
        mov     al, [ebx + blk.floppy.ctl.device_t.last_drive_number]
        call    blk.floppy.ctl._.out_byte

        ; wait for operation completion
        call    blk.floppy.ctl._.wait_for_interrupt

        call    blk.floppy.ctl._.sense_interrupt
        test    [ebx + blk.floppy.ctl.device_t.status.st0], 0x20
        jz      .retry

        xor     al, al
        mov     [ebx + blk.floppy.ctl.device_t.position.cylinder], al
        mov     [ebx + blk.floppy.ctl.device_t.position.head], al
        inc     al
        mov     [ebx + blk.floppy.ctl.device_t.position.sector], al

        call    blk.floppy.ctl._.update_motor_timer
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl.select_drive ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Select floppy drive to operate on and spin its motor on, if necessary.
;-----------------------------------------------------------------------------------------------------------------------
;> al #= drive number
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx

        movzx   ecx, al
        cmp     cl, [ebx + blk.floppy.ctl.device_t.last_drive_number]
        jne     .select_and_start_motor
        cmp     [ebx + blk.floppy.ctl.device_t.motor_timer + ecx * 4], 0
        jne     .exit

  .select_and_start_motor:
        ; TODO: check if this stops other drives' motors (which is not acceptable)
        mov     dx, [ebx + blk.floppy.ctl.device_t.base_reg]
        add     dx, BLK_FLOPPY_CTL_REG_DIGITAL_OUTPUT
        mov     al, 00010000b
        shl     al, cl
        or      al, cl
        or      al, 00001100b
        out     dx, al

        KLog    LOG_DEBUG, "floppy motor #%u spin up\n", cl

        mov     [ebx + blk.floppy.ctl.device_t.last_drive_number], cl

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
        call    blk.floppy.ctl._.update_motor_timer
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl.process_events ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Process FDC events which might have occured.
;-----------------------------------------------------------------------------------------------------------------------
;# Called from main OS loop.
;-----------------------------------------------------------------------------------------------------------------------
        ; TODO: lock controller

        ; TODO: make use of dynamic device data (not yet implemented)
        mov     ebx, static_test_floppy_ctl_device_data

        xor     al, al
        call    blk.floppy.ctl._.check_motor_timer
;       mov     al, 1
;       call    blk.floppy.ctl._.check_motor_timer
;       mov     al, 2
;       call    blk.floppy.ctl._.check_motor_timer
;       mov     al, 3
;       call    blk.floppy.ctl._.check_motor_timer

        ; TODO: unlock controller

        ret
kendp

;;======================================================================================================================
;;///// private functions //////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

uglobal
  blk.floppy.ctl._.data:
    .interrupt_flag    db ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl._.update_motor_timer ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Save FDD motor timer.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        movzx   eax, [ebx + blk.floppy.ctl.device_t.last_drive_number]
        MovStk  [ebx + blk.floppy.ctl.device_t.motor_timer + eax * 4], dword[timer_ticks]
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl._.check_motor_timer ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Check for FDD motor spindown delay.
;-----------------------------------------------------------------------------------------------------------------------
;> al #= drive number
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        movzx   eax, al
        mov     eax, [ebx + blk.floppy.ctl.device_t.motor_timer + eax * 4]
        test    eax, eax
        jz      .exit

        sub     eax, dword[timer_ticks]
        add     eax, 2 * KCONFIG_SYS_TIMER_FREQ ; ~2 sec
        jg      .exit

        mov     al, [esp]
        call    blk.floppy.ctl._.stop_motor

  .exit:
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl._.stop_motor ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Turn FDD motor off.
;-----------------------------------------------------------------------------------------------------------------------
;> al #= drive number
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        movzx   ecx, al

        mov     dx, [ebx + blk.floppy.ctl.device_t.base_reg]
        add     dx, BLK_FLOPPY_CTL_REG_DIGITAL_OUTPUT
        mov     al, cl
        or      al, 00001100b
        out     dx, al

        KLog    LOG_DEBUG, "floppy motor #%u spin down\n", cl

        mov     [ebx + blk.floppy.ctl.device_t.last_drive_number], cl
        and     [ebx + blk.floppy.ctl.device_t.motor_timer + ecx * 4], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl._.init_dma ;///////////////////////////////////////////////////////////////////////////////////////
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

        mov     eax, BLK_FLOPPY_CTL_BYTES_PER_SECTOR - 1 ; set count (actual size -1)
        out     0x05, al
        shr     eax, 8
        out     0x05, al

        mov     al, 2
        out     0x0a, al

        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl._.out_byte ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write byte to FDC data port.
;-----------------------------------------------------------------------------------------------------------------------
;> al #= byte to write
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< Cf ~= timeout error
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx
        mov     ah, al ; save byte in AH
        ; check if controller is ready to transfer data
        mov     dx, [ebx + blk.floppy.ctl.device_t.base_reg]
        add     dx, BLK_FLOPPY_CTL_REG_MAIN_STATUS
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
kproc blk.floppy.ctl._.in_byte ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read byte from FDC data port.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< al #= byte read (on success)
;< Cf ~= timeout error
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx
        ; check if controller is ready to transfer data
        mov     dx, [ebx + blk.floppy.ctl.device_t.base_reg]
        add     dx, BLK_FLOPPY_CTL_REG_MAIN_STATUS
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
kproc blk.floppy.ctl._.get_status ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get FDC operation status.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.status.st0], al
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.status.st1], al
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.status.st2], al
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.position.cylinder], al
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.position.head], al
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.position.sector], al
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.status.sector_size], al
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl._.sense_interrupt ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Send 'sense interrupt' command to FDC.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.floppy.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x08
        call    blk.floppy.ctl._.out_byte
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.status.st0], al
        call    blk.floppy.ctl._.in_byte
        mov     [ebx + blk.floppy.ctl.device_t.position.cylinder], al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl._.prepare_for_interrupt ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Prepare for FDC interrupt.
;-----------------------------------------------------------------------------------------------------------------------
        ; reset interrupt flag
        and     [blk.floppy.ctl._.data.interrupt_flag], 0
        ; replace interrupt handler
        mov     [blk.floppy.ctl.irq_func], .raise_fdc_interrupt_flag
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .raise_fdc_interrupt_flag: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        inc     [blk.floppy.ctl._.data.interrupt_flag]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.floppy.ctl._.wait_for_interrupt ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Wait for FDC interrupt.
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx

        ; reset timer tick counter
        mov     ecx, dword[timer_ticks]

  .check_flag:
        ; reset controller error code
        xor     eax, eax ; BLK_FLOPPY_CTL_ERROR_SUCCESS

        ; check if FDC interrupt flag is set
        cmp     [blk.floppy.ctl._.data.interrupt_flag], 0
        jne     .exit ; interrupt occurred

        call    change_task

        ; check for timeout (~3 sec)
        mov     eax, dword[timer_ticks]
        sub     eax, ecx
        cmp     eax, 3 * KCONFIG_SYS_TIMER_FREQ
        jb      .check_flag

        ; timeout error
        mov     eax, BLK_FLOPPY_CTL_ERROR_TIMEOUT

  .exit:
        mov     [blk.floppy.ctl.irq_func], util.noop
        pop     ecx
        ret
kendp
