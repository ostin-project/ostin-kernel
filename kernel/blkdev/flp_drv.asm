;;======================================================================================================================
;;///// flp_drv.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
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
;? Direct work with FDC
;;======================================================================================================================
;# References:
;# * "Programming on the hardware level" book by V.G. Kulakov
;;======================================================================================================================

uglobal
  flp_status dd 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc reserve_flp ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cli
        cmp     [flp_status], 0
        je      .reserve_flp_ok

        sti
        call    change_task
        jmp     reserve_flp

  .reserve_flp_ok:
        push    eax
        mov     eax, [CURRENT_TASK]
        shl     eax, 5
        mov     eax, [TASK_DATA + eax - sizeof.task_data_t + task_data_t.pid]
        mov     [flp_status], eax
        pop     eax
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
;kproc give_back_application_data ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? send data to application
;-----------------------------------------------------------------------------------------------------------------------
;       mov     edi, [TASK_BASE]
;       mov     edi, [edi + task_data_t.mem_start]
;       add     edi, ecx
;kendp

if defined COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
kproc give_back_application_data_1 ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, FDC_DMA_BUFFER
        xor     ecx, ecx
        mov     cx, 128
        rep
        movsd
        ret
kendp

end if ; COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
;kproc take_data_from_application ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? receive data from application
;-----------------------------------------------------------------------------------------------------------------------
;       mov     esi, [TASK_BASE]
;       mov     esi, [esi + task_data_t.mem_start]
;       add     esi, ecx
;kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc take_data_from_application_1 ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, FDC_DMA_BUFFER
        xor     ecx, ecx
        mov     cx, 128
        rep
        movsd
        ret
kendp

; Maximum sector coordinates values (these correspond to standard 3'' 1.44 MB disk)
MAX_Track   equ 79
MAX_Head    equ 1
MAX_Sector  equ 18

uglobal
  TickCounter      dd ?   ; timer tick counter
  FDC_Status       db ?   ; FDC operation error code
  FDD_IntFlag      db ?   ; FDD interrupt flag
  FDD_Time         dd ?   ; Time from last operation with FDD
  FDD_Type         db ?   ; FDD number

  ; sector coordinates
  FDD_Track        db ?
  FDD_Head         db ?
  FDD_Sector       db ?

  ; operation result block
  FDC_ST0          db ?
  FDC_ST1          db ?
  FDC_ST2          db ?
  FDC_C            db ?
  FDC_H            db ?
  FDC_R            db ?
  FDC_N            db ?

  ReadRepCounter   db ?   ; Read operation repeat counter
  RecalRepCounter  db ?   ; Recalibration operation repeat counter
; FDD_DataBuffer   rb 512 ; Buffer to store read sector
  fdd_motor_status db ?
  timer_fdd_motor  dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc Init_FDC_DMA ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Initialize FDC DMA mode
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        mov     al, 6 ; mask channel 2 so we can reprogram it.
        out     0x0a, al
        mov     al, [dmamode] ; 0x46 -> Read from floppy - 0x4a Write to floppy
        out     0x0b, al
        mov     al, 0
        out     0x0c, al ; reset the flip-flop to a known state.
        mov     eax, 0xd000
        out     0x04, al ; set the channel 2 starting address to 0
        shr     eax, 8
        out     0x04, al
        shr     eax, 8
        out     0x81, al
        mov     al, 0
        out     0x0c, al ; reset flip-flop
        mov     al, 0xff ; set count (actual size -1)
        out     0x5, al
        mov     al, 0x1 ; [dmasize] ; (0x1ff = 511 / 0x23ff = 9215)
        out     0x5, al
        mov     al, 2
        out     0xa, al
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc FDCDataOutput ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write byte to FDC data port
;-----------------------------------------------------------------------------------------------------------------------
;> al = byte to write
;-----------------------------------------------------------------------------------------------------------------------
;       pusha
        push    eax ecx edx
        mov     ah, al ; save byte in AH
        ; reset controller error code
        mov     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        ; check if controller is ready to transfer data
        mov     dx, 0x3f4 ; (FDC status port)
        mov     ecx, 0x10000 ; set timeout counter

  .TestRS:
        in      al, dx ; read RS register
        and     al, 0xc0 ; get bits 6 and 7
        cmp     al, 0x80 ; check bits 6 and 7
        je      .OutByteToFDC
        loop    .TestRS
        ; timeout error
        mov     [FDC_Status], FLOPPY_CTL_ERROR_TIMEOUT
        jmp     .End_5

  .OutByteToFDC:
        ; write byte to data port
        inc     dx
        mov     al, ah
        out     dx, al

  .End_5:
;       popa
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc FDCDataInput ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read byte from FDC data port
;-----------------------------------------------------------------------------------------------------------------------
;< al = byte read
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        push    dx
        ; reset controller error code
        mov     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        ; check if controller is ready to transfer data
        mov     dx, 0x3f4 ; (FDC status port)
        mov     ecx, 0x10000 ; set timeout counter

  .TestRS_1:
        in      al, dx ; read RS register
        and     al, 0xc0 ; get bits 6 and 7
        cmp     al, 0xc0 ; check bits 6 and 7
        je      .GetByteFromFDC
        loop    .TestRS_1
        ; timeout error
        mov     [FDC_Status], FLOPPY_CTL_ERROR_TIMEOUT
        jmp     .End_6

  .GetByteFromFDC:
        ; read byte from data port
        inc     dx
        in      al, dx

  .End_6:
        pop     dx
        pop     ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc FDCInterrupt ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? FDC interrupt handler
;-----------------------------------------------------------------------------------------------------------------------
        ; set interrupt flag
        mov     [FDD_IntFlag], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SetUserInterrupts ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Set FDC interrupt handler
;-----------------------------------------------------------------------------------------------------------------------
        and     [FDD_IntFlag], 0
        mov     [fdc_irq_func], FDCInterrupt
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc WaitFDCInterrupt ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Wait for FDC interrupt
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; reset controller error code
        mov     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        ; reset timer tick counter
        mov     eax, [timer_ticks]
        mov     [TickCounter], eax

  .TestRS_2:
        ; Wait until FDC interrupt flag is set
        cmp     [FDD_IntFlag], 0
        jnz     .End_7 ; interrupt occurred
        call    change_task
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter]
        cmp     eax, 3 * KCONFIG_SYS_TIMER_FREQ ; wait for 3 sec
;       jl      .TestRS_2
        jb      .TestRS_2
        ; timeout error
;       mov     [flp_status], 0
        mov     [FDC_Status], FLOPPY_CTL_ERROR_TIMEOUT

  .End_7:
        mov     [fdc_irq_func], util.noop
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc FDCSenseInterrupt ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x08
        call    FDCDataOutput
        call    FDCDataInput
        mov     [FDC_ST0], al
        call    FDCDataInput
        mov     [FDC_C], al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc FDDMotorON ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Turn FDD motor on
;-----------------------------------------------------------------------------------------------------------------------
        pusha
;       cmp     [fdd_motor_status], 1
;       je      fdd_motor_on
        mov     al, [flp_number]
        cmp     [fdd_motor_status], al
        je      .fdd_motor_on
        ; reset FDC
        mov     dx, 0x3f2 ; motor control port
        ; select and turn on disk motor
        cmp     [flp_number], 1
        jne     .FDDMotorON_B
;       call    FDDMotorOFF_B
        mov     al, 0x1c ; Floppy A
        jmp     .FDDMotorON_1

  .FDDMotorON_B:
;       call    FDDMotorOFF_A
        mov     al, 0x2d ; Floppy B

  .FDDMotorON_1:
        out     dx, al
        ; reset timer tick counter
        mov     eax, [timer_ticks]
        mov     [TickCounter], eax

  .dT:
        ; wait for 0.5 sec
        call    change_task
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter]
        cmp     eax, KCONFIG_SYS_TIMER_FREQ / 2
        jb      .dT
        cmp     [flp_number], 1
        jne     .fdd_motor_on_B
        mov     [fdd_motor_status], 1
        jmp     .fdd_motor_on

  .fdd_motor_on_B:
        mov     [fdd_motor_status], 2

  .fdd_motor_on:
        call    save_timer_fdd_motor
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc save_timer_fdd_motor ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Save FDD motor timer
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [timer_ticks]
        mov     [timer_fdd_motor], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc check_fdd_motor_status ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Check for FDD motor spindown delay
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [fdd_motor_status], 0
        je      .end_check_fdd_motor_status_1
        mov     eax, [timer_ticks]
        sub     eax, [timer_fdd_motor]
        cmp     eax, 5 * KCONFIG_SYS_TIMER_FREQ
        jb      .end_check_fdd_motor_status
        call    FDDMotorOFF
        mov     [fdd_motor_status], 0

  .end_check_fdd_motor_status_1:
        mov     [flp_status], 0

  .end_check_fdd_motor_status:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc FDDMotorOFF ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Turn FDD motor off
;-----------------------------------------------------------------------------------------------------------------------
        push    ax
        push    dx
        cmp     [flp_number], 1
        jne     .FDDMotorOFF_1
        call    .FDDMotorOFF_A
        jmp     .FDDMotorOFF_2

  .FDDMotorOFF_1:
        call    .FDDMotorOFF_B

  .FDDMotorOFF_2:
        pop     dx
        pop     ax
        ; reset cache flags due to stale info
        mov     [root_read], 0
        mov     [flp_fat], 0
        ret

  .FDDMotorOFF_A:
        mov     dx, 0x3f2 ; motor control port
        mov     al, 0x0c ; Floppy A
        out     dx, al
        ret

  .FDDMotorOFF_B:
        mov     dx, 0x3f2 ; motor control port
        mov     al, 0xd ; Floppy B
        out     dx, al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc RecalibrateFDD ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Recalibrate drive "A:"
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        call    save_timer_fdd_motor

        call    FDDMotorON

        call    SetUserInterrupts

        ; send "recalibrate" command
        mov     al, 0x07
        call    FDCDataOutput
        mov     al, 0
        call    FDCDataOutput

        ; wait for operation completion
        call    WaitFDCInterrupt

        call    FDCSenseInterrupt

;       cmp     [FDC_Status], 0
;       je      .no_fdc_status_error
;       mov     [flp_status], 0

; .no_fdc_status_error:
        call    save_timer_fdd_motor
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SeekTrack ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Seek to track
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> FDD_Track = track number (0-79)
;> FDD_Head = head number (0-1)
;-----------------------------------------------------------------------------------------------------------------------
;< FDC_Status = error code
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        call    save_timer_fdd_motor

        call    FDDMotorON

        call    SetUserInterrupts

        ; send "seek" command
        mov     al, 0x0f
        call    FDCDataOutput
        ; send head number
        mov     al, [FDD_Head]
        shl     al, 2
        call    FDCDataOutput
        ; send track number
        mov     al, [FDD_Track]
        call    FDCDataOutput
        ; wait for operation to complete

        call    WaitFDCInterrupt

        cmp     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        jne     .Exit

        ; save seek result
        call    FDCSenseInterrupt

        ; validate seek result
        ; seek complete?
        test    [FDC_ST0], 0100000b
        je      .Err
        ; specified track found?
        mov     al, [FDC_C]
        cmp     al, [FDD_Track]
        jne     .Err
        ; specified head found?
        mov     al, [FDC_ST0]
        and     al, 0100b
        shr     al, 2
        cmp     al, [FDD_Head]
        jne     .Err
        ; operation completed successfully
        mov     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        jmp     .Exit

  .Err:
        ; track not found
;       mov     [flp_status], 0
        mov     [FDC_Status], FLOPPY_CTL_ERROR_TRACK_NOT_FOUND

  .Exit:
        call    save_timer_fdd_motor
        popa
        ret
kendp

xxx db 0

;-----------------------------------------------------------------------------------------------------------------------
kproc ReadSector ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read sector
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> FDD_Track = track number (0-79)
;> FDD_Head = head number (0-1)
;> FDD_Sector = sector number (1-18)
;-----------------------------------------------------------------------------------------------------------------------
;< FDC_Status = error code
;< FDD_DataBuffer = sector content (on success)
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        call    save_timer_fdd_motor

        call    FDDMotorON

        ; set transfer speed to 500 KB/s
        mov     ax, 0
        mov     dx, 0x3f7
        out     dx, al

        ; initialise DMA channel
        mov     [dmamode], 0x46
        call    Init_FDC_DMA

        call    SetUserInterrupts

        ; send "read data" command
        mov     al, 0xe6 ; reading in multi-track mode
        call    FDCDataOutput
        mov     al, [FDD_Head]
        shl     al, 2
        call    FDCDataOutput
        mov     al, [FDD_Track]
        call    FDCDataOutput
        mov     al, [FDD_Head]
        call    FDCDataOutput
        mov     al, [FDD_Sector]
        call    FDCDataOutput
        mov     al, 2 ; sector size code (512 bytes)
        call    FDCDataOutput
        mov     al, 18 ; +1 ; 0x3f ; numberof sector on track
        call    FDCDataOutput
        mov     al, 0x1b ; GPL value
        call    FDCDataOutput
        mov     al, 0xff ; DTL value
        call    FDCDataOutput

        ; wait for operation completion
        call    WaitFDCInterrupt

        cmp     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        jne     .Exit_1
        mov     dx, 0x3f4 ; (FDC status port)
        mov     ecx, 0x10000 ; set timeout counter
    @@: in      al, dx ; read RS register
        and     al, 0xc0 ; get bits 6 and 7
        cmp     al, 0xc0 ; check bits 6 and 7
        je      @f
        loop    @b
        mov     [FDC_Status], FLOPPY_CTL_ERROR_TIMEOUT
        jmp     .Exit_1
    @@:

        ; get operation status
        call    GetStatusInfo

        test    [FDC_ST0], 11011000b
        jnz     .Err_1
        mov     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        jmp     .Exit_1

  .Err_1:
;       mov     [flp_status], 0
        mov     [FDC_Status], FLOPPY_CTL_ERROR_SECTOR_NOT_FOUND

  .Exit_1:
        call    save_timer_fdd_motor
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ReadSectWithRetr ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read sector (retry on errors)
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> FDD_Track = track number (0-79)
;> FDD_Head = head number (0-1)
;> FDD_Sector = sector number (1-18)
;-----------------------------------------------------------------------------------------------------------------------
;< FDC_Status = error code
;< FDD_DataBuffer = sector content (on success)
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; reset recalibration operation repeat counter
        mov     [RecalRepCounter], 0

  .TryAgain:
        ; reset read operation repeat counter
        mov     [ReadRepCounter], 0

        call    SeekTrack

  .ReadSector_1:
        call    ReadSector
        cmp     [FDC_Status], 0
        je      .Exit_2
        cmp     [FDC_Status], 1
        je      .Err_3
        ; try reading 3 times
        inc     [ReadRepCounter]
        cmp     [ReadRepCounter], 3
        jb      .ReadSector_1
        ; try recalibrating 3 times
        call    RecalibrateFDD
        inc     [RecalRepCounter]
        cmp     [RecalRepCounter], 3
        jb      .TryAgain
;       mov     [flp_status],0

  .Exit_2:
        popa
        ret

  .Err_3:
        mov     [flp_status], 0
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc WriteSector ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write sector
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> FDD_Track = track number (0-79)
;> FDD_Head = head number (0-1)
;> FDD_Sector = sector number (1-18)
;> FDD_DataBuffer = sector content to write
;-----------------------------------------------------------------------------------------------------------------------
;< FDC_Status = error code
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        call    save_timer_fdd_motor

        call    FDDMotorON

        ; set transfer speed to 500 KB/s
        mov     ax, 0
        mov     dx, 0x3f7
        out     dx, al

        ; initialize DMA channel
        mov     [dmamode], 0x4a
        call    Init_FDC_DMA

        call    SetUserInterrupts

        ; send "write data" command
        mov     al, 0xc5 ; 0x45 ; writing in multi-track mode
        call    FDCDataOutput
        mov     al, [FDD_Head]
        shl     al, 2
        call    FDCDataOutput
        mov     al, [FDD_Track]
        call    FDCDataOutput
        mov     al, [FDD_Head]
        call    FDCDataOutput
        mov     al, [FDD_Sector]
        call    FDCDataOutput
        mov     al, 2 ; sector size code (512 bytes)
        call    FDCDataOutput
        mov     al, 18 ; 0x3f ; number of sectors on track
        call    FDCDataOutput
        mov     al, 0x1b ; GPL value
        call    FDCDataOutput
        mov     al, 0xff ; DTL value
        call    FDCDataOutput

        ; wait for operation completion
        call    WaitFDCInterrupt

        cmp     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        jne     .Exit_3
        ; get operation status
        call    GetStatusInfo
        test    [FDC_ST0], 11000000b ; 11011000b
        jnz     .Err_2
        mov     [FDC_Status], FLOPPY_CTL_ERROR_SUCCESS
        jmp     .Exit_3

  .Err_2:
        mov     [FDC_Status], FLOPPY_CTL_ERROR_SECTOR_NOT_FOUND

  .Exit_3:
        call    save_timer_fdd_motor
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc WriteSectWithRetr ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write sector (retry on errors)
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> FDD_Track = track number (0-79)
;> FDD_Head = head number (0-1)
;> FDD_Sector = sector number (1-18)
;> FDD_DataBuffer = sector content to write
;-----------------------------------------------------------------------------------------------------------------------
;< FDC_Status = error code
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; reset recalibration operation repeat counter
        mov     [RecalRepCounter], 0

  .TryAgain_1:
        ; reset write operation repeat counter
        mov     [ReadRepCounter], 0

        call    SeekTrack

  .WriteSector_1:
        call    WriteSector
        cmp     [FDC_Status], 0
        je      .Exit_4
        cmp     [FDC_Status], 1
        je      .Err_4
        ; try writing 3 times
        inc     [ReadRepCounter]
        cmp     [ReadRepCounter], 3
        jb      .WriteSector_1
        ; try recalibrating 3 times
        call    RecalibrateFDD
        inc     [RecalRepCounter]
        cmp     [RecalRepCounter], 3
        jb      .TryAgain_1

  .Exit_4:
        popa
        ret

  .Err_4:
        mov     [flp_status], 0
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc GetStatusInfo ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get operation status
;-----------------------------------------------------------------------------------------------------------------------
        push    ax
        call    FDCDataInput
        mov     [FDC_ST0], al
        call    FDCDataInput
        mov     [FDC_ST1], al
        call    FDCDataInput
        mov     [FDC_ST2], al
        call    FDCDataInput
        mov     [FDC_C], al
        call    FDCDataInput
        mov     [FDC_H], al
        call    FDCDataInput
        mov     [FDC_R], al
        call    FDCDataInput
        mov     [FDC_N], al
        pop     ax
        ret
kendp
