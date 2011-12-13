;;======================================================================================================================
;;///// dev_hdcd.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
;? Find HDD and CD drives
;;======================================================================================================================
;# References:
;# * "Programming on the hardware level" book by V.G. Kulakov
;;======================================================================================================================

;-----------------------------------------------------------------------------------------------------------------------
FindHDD: ;//////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Find HDDs and CDs
;-----------------------------------------------------------------------------------------------------------------------
        mov     [ChannelNumber], 0
        mov     [DiskNumber], 0
        call    .FindHDD_3
;       mov     ax, [Sector512 + 176]
;       mov     [DRIVE_DATA + 6], ax
;       mov     ax, [Sector512 + 126]
;       mov     [DRIVE_DATA + 8], ax
;       mov     ax, [Sector512 + 128]
;       mov     [DRIVE_DATA + 8], ax
        mov     [DiskNumber], 1
        call    .FindHDD_3
;       mov     al, [Sector512 + 176]
;       mov     [DRIVE_DATA + 7], al
        inc     [ChannelNumber]
        mov     [DiskNumber], 0
        call    .FindHDD_3
;       mov     al, [Sector512 + 176]
;       mov     [DRIVE_DATA + 8], al
        mov     [DiskNumber], 1
        call    .FindHDD_1
;       mov     al, [Sector512 + 176]
;       mov     [DRIVE_DATA + 9], al

        jmp     EndFindHDD

;-----------------------------------------------------------------------------------------------------------------------
  .FindHDD_1: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        call    ReadHDD_ID
        cmp     [DevErrorCode], 0
        jne     .FindHDD_2
        cmp     word[Sector512 + 6], 16
        ja      .FindHDD_2
        cmp     word[Sector512 + 12], 255
        ja      .FindHDD_2
        inc     byte[DRIVE_DATA + 1]
        jmp     .FindHDD_2_2

  .FindHDD_2:
        call    DeviceReset
        cmp     [DevErrorCode], 0
        jne     .FindHDD_2_2
        call    ReadCD_ID
        cmp     [DevErrorCode], 0
        jne     .FindHDD_2_2
        inc     byte[DRIVE_DATA + 1]
        inc     byte[DRIVE_DATA + 1]

  .FindHDD_2_2:
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .FindHDD_3: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        call    .FindHDD_1
        shl     byte[DRIVE_DATA + 1], 2
        ret

uglobal
  SectorAddress dd ? ; address of sector read in LBA mode
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc ReadHDD_ID ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read HDD device identifier
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> [ChannelNumber] = channel number
;> [DiskNumber] = drive number on channel (0 or 1)
;-----------------------------------------------------------------------------------------------------------------------
;; Identification data block is read into Sector512.
;-----------------------------------------------------------------------------------------------------------------------
        ; set CHS mode
        mov     [ATAAddressMode], 0
        ; send device identification command
        mov     [ATAFeatures], 0
        mov     [ATAHead], 0
        mov     [ATACommand], 0xec
        call    SendCommandToHDD
        cmp     [DevErrorCode], 0 ; check for error
        jne     .End  ; exit, saving error code
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; status register address
        mov     ecx, 0x0000ffff

  .WaitCompleet:
        ; check commamd execution duration
        dec     ecx
;       cmp     ecx,0
        jz      .Error1 ; timeout error
        ; check if device is ready
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitCompleet
        test    al, 1 ; ERR signal state
        jnz     .Error6
        test    al, 0x08 ; DRQ signal state
        jz      .WaitCompleet
        ; receive data block from controller
;       mov     ax, ds
;       mov     es, ax
        mov     edi, Sector512 ; offset of Sector512
        mov     dx, [ATABasePortAddr] ; data register
        mov     cx, 256 ; number of words to read
        rep
        insw    ; receive data block
        ret

  .Error1:
        ; save error code
        mov     [DevErrorCode], 1
        ret

  .Error6:
        mov     [DevErrorCode], 6

  .End:
        ret
kendp

iglobal
  StandardATABases dw 0x1f0, 0x170 ; channels 1 and 2 standard base addresses
endg

uglobal
  ChannelNumber   dw ? ; channel number
  DiskNumber      db ? ; drive number
  ATABasePortAddr dw ? ; base address of ATA controller ports group

  ; ATA command arguments
  ATAFeatures     db ? ; capabilities
  ATASectorCount  db ? ; number of sectors to work on
  ATASectorNumber db ? ; start sector number
  ATACylinder     dw ? ; start cylinder number
  ATAHead         db ? ; start head number
  ATAAddressMode  db ? ; addressing mode (0 - CHS, 1 - LBA)
  ATACommand      db ? ; command code to execute

  ; Error code (0 - success, 1 - timeout, 2 - invalid addressing mode, 3 - invalid channel number,
  ; 4 - invalid drive number, 5 - invalid head number, 6 - command execution error)
  DevErrorCode    dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc SendCommandToHDD ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Send command to specified drive
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> [ChannelNumber] = channel number
;> [DiskNumber] = drive number (0 or 1)
;> [ATAFeatures] = "capabilities"
;> [ATASectorCount] = sectors count
;> [ATASectorNumber] = start sector number
;> [ATACylinder] = start cylinder number
;> [ATAHead] = start head number
;> [ATAAddressMode] = addressing mode (0 - CHS, 1 - LBA)
;> [ATACommand] = command code
;-----------------------------------------------------------------------------------------------------------------------
;< [DevErrorCode] - error code
;< [ATABasePortAddr] - base HDD address (on success)
;-----------------------------------------------------------------------------------------------------------------------
        ; check if addressing mode is valid
        cmp     [ATAAddressMode], 1
        ja      .Err2
        ; check if channel number is valid
        mov     bx, [ChannelNumber]
        cmp     bx, 2
        jae     .Err3
        ; set base address
        shl     bx, 1
        movzx   ebx, bx
        mov     ax, [ebx + StandardATABases]
        mov     [ATABasePortAddr], ax
        ; wait for HDD being ready to receive command
        ; select needed drive
        mov     dx, [ATABasePortAddr]
        add     dx, 6 ; heads register address
        mov     al, [DiskNumber]
        cmp     al, 1 ; check if drive number is valid
        ja      .Err4
        shl     al, 4
        or      al, 10100000b
        out     dx, al
        ; wait until drive is ready
        inc     dx
        mov     ecx, 0x0fff
;       mov     eax, [timer_ticks]
;       mov     [TickCounter_1], eax

  .WaitHDReady:
        ; check execution duration
        dec     ecx
;       cmp     ecx, 0
        jz      .Err1
;       mov     eax, [timer_ticks]
;       sub     eax, [TickCounter_1]
;       cmp     eax, 3 * KCONFIG_SYS_TIMER_FREQ ; wait for 3 sec
;       ja      .Err1 ; timeout error
        ; read status register
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitHDReady
        test    al, 0x08 ; DRQ signal state
        jnz     .WaitHDReady
        ; load command into controller registers
        cli
        mov     dx, [ATABasePortAddr]
        inc     dx ; "capabilities" register
        mov     al, [ATAFeatures]
        out     dx, al
        inc     dx ; sectors counter
        mov     al, [ATASectorCount]
        out     dx, al
        inc     dx ; sector number register
        mov     al, [ATASectorNumber]
        out     dx, al
        inc     dx ; cylinder number (low byte)
        mov     ax, [ATACylinder]
        out     dx, al
        inc     dx ; cylinder number (high byte)
        mov     al, ah
        out     dx, al
        inc     dx ; head/drive number
        mov     al, [DiskNumber]
        shl     al, 4
        cmp     [ATAHead], 0x0f ; check if head number is valid
        ja      .Err5
        or      al, [ATAHead]
        or      al, 10100000b
        mov     ah, [ATAAddressMode]
        shl     ah, 6
        or      al, ah
        out     dx, al
        ; send command
        mov     al, [ATACommand]
        inc     dx ; command register
        out     dx, al
        sti
        ; reset error code
        mov     [DevErrorCode], 0
        ret

  .Err1:
        ; save error code
        mov     [DevErrorCode], 1
        ret

  .Err2:
        mov     [DevErrorCode], 2
        ret

  .Err3:
        mov     [DevErrorCode], 3
        ret

  .Err4:
        mov     [DevErrorCode], 4
        ret

  .Err5:
        mov     [DevErrorCode], 5
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ReadCD_ID ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read ATAPI device identifier
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> [ChannelNumber] = channel number
;> [DiskNumber] = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
;; Identification data block is read into Sector512.
;-----------------------------------------------------------------------------------------------------------------------
        ; set CHS mode
        mov     [ATAAddressMode], 0
        ; send device identification command
        mov     [ATAFeatures], 0
        mov     [ATASectorCount], 0
        mov     [ATASectorNumber], 0
        mov     [ATACylinder], 0
        mov     [ATAHead], 0
        mov     [ATACommand], 0xa1
        call    SendCommandToHDD
        cmp     [DevErrorCode], 0 ; check for error
        jne     .End_1 ; exit, saving error code
        ; wait for device to become ready
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; port 1x7h
        mov     ecx, 0x0000ffff

  .WaitCompleet_1:
        ; check execution duration
        dec     ecx
;       cmp     ecx, 0
        jz      .Error1_1 ; timeout error
        ; check if device it ready
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitCompleet_1
        test    al, 1 ; ERR signal state
        jnz     .Error6_1
        test    al, 0x08 ; DRQ signal state
        jz      .WaitCompleet_1
        ; receive data block from controller
;       mov     ax, ds
;       mov     es, ax
        mov     edi, Sector512  ; offset of Sector512
        mov     dx, [ATABasePortAddr] ; port 1x0h
        mov     cx, 256 ; number of words to read
        rep
        insw
        ret

  .Error1_1:
        ; save error code
        mov     [DevErrorCode], 1
        ret

  .Error6_1:
        mov     [DevErrorCode], 6

  .End_1:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc DeviceReset ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Reset device
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber - channel number (1 or 2)
;> DiskNumber - drive number on channel (0 or 1)
;-----------------------------------------------------------------------------------------------------------------------
        ; check if channel number is valid
        mov     bx, [ChannelNumber]
        cmp     bx, 2
        jae     .Err3_2
        ; set base address
        shl     bx, 1
        movzx   ebx, bx
        mov     dx, [ebx + StandardATABases]
        mov     [ATABasePortAddr], dx
        ; select needed drive
        add     dx, 6 ; heads register address
        mov     al, [DiskNumber]
        cmp     al, 1 ; check if drive number is valid
        ja      .Err4_2
        shl     al, 4
        or      al, 10100000b
        out     dx, al
        ; send "reset" command
        mov     al, 0x08
        inc     dx ; command register
        out     dx, al
        mov     ecx, 0x00080000

  .WaitHDReady_1:
        ; check execution duration
        dec     ecx
;       cmp     ecx, 0
        je      .Err1_2 ; timeout error
        ; read status register
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitHDReady_1
        ; reset error code
        mov     [DevErrorCode], 0
        ret

  .Err1_2:
        ; save error code
        mov     [DevErrorCode], 1
        ret

  .Err3_2:
        mov     [DevErrorCode], 3
        ret

  .Err4_2:
        mov     [DevErrorCode], 4
        ret
kendp

EndFindHDD:
