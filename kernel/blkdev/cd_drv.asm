;;======================================================================================================================
;;///// cd_drv.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2006-2011 KolibriOS team <http://kolibrios.org/>
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
;? Direct work with CD (ATAPI) devices
;;======================================================================================================================
;# References:
;# * "Programming on the hardware level" book by V.G. Kulakov
;;======================================================================================================================

MaxRetr        = 10       ; maximum retry count
BSYWaitTime    = 10 * KCONFIG_SYS_TIMER_FREQ ; maximum wait time for busy -> ready transition (in ticks)
NoTickWaitTime = 0x000fffff
CDBlockSize    = 2048

uglobal
  cdpos              rd 1
  cd_status          dd 0
  IDE_Channel_1      db 0
  IDE_Channel_2      db 0
  timer_ticks_enable rb 1 ; for cd driver
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc reserve_cd ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cli
        cmp     [cd_status], 0
        je      reserve_ok2

        sti
        call    change_task
        jmp     reserve_cd

reserve_ok2:
        push    eax
        mov     eax, [CURRENT_TASK]
        shl     eax, 5
        mov     eax, [TASK_DATA + eax - sizeof.task_data_t + task_data_t.pid]
        mov     [cd_status], eax
        pop     eax
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc reserve_cd_channel ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [ChannelNumber], 0
        jne     .secondary_channel

  .primary_channel:
        cli
        cmp     [IDE_Channel_1], 0
        je      @f
        sti
        call    change_task
        jmp     .primary_channel

    @@: mov     [IDE_Channel_1], 1
        jmp     .exit

  .secondary_channel:
        cli
        cmp     [IDE_Channel_2], 0
        je      @f
        sti
        call    change_task
        jmp     .secondary_channel

    @@: mov     [IDE_Channel_2], 1

  .exit:
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc free_cd_channel ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [ChannelNumber], 0
        jne     .secondary_channel

  .primary_channel:
        and     [IDE_Channel_1], 0
        ret

  .secondary_channel:
        and     [IDE_Channel_2], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ReadCDWRetr ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read sector (retry on errors)
;-----------------------------------------------------------------------------------------------------------------------
;> eax = block to read
;> ebx = destination
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        mov     eax, [CDSectorAddress]
        mov     ebx, [CDDataBuf_pointer]
        call    cd_calculate_cache
        xor     edi, edi
        add     esi, 8
        inc     edi

  .hdreadcache:
;       cmp     dword[esi + 4],0 ; empty
;       je      .nohdcache
        cmp     [esi], eax ; correct sector
        je      .yeshdcache

  .nohdcache:
        add     esi, 8
        inc     edi
        dec     ecx
        jnz     .hdreadcache
        call    find_empty_slot_CD_cache       ; ret in edi

        push    edi
        push    eax
        call    cd_calculate_cache_2
        shl     edi, 11
        add     edi, eax
        mov     [CDDataBuf_pointer], edi
        pop     eax
        pop     edi

        call    ReadCDWRetr_1
        cmp     [DevErrorCode], 0
        jne     .exit

        mov     [CDDataBuf_pointer], ebx
        call    cd_calculate_cache_1
        lea     esi, [edi * 8 + esi]
        mov     [esi], eax ; sector number
;       mov     dword[esi + 4], 1 ; hd read - mark as same as in hd

  .yeshdcache:
        mov     esi, edi
        shl     esi, 11 ; 9
        push    eax
        call    cd_calculate_cache_2
        add     esi, eax
        pop     eax
        mov     edi, ebx ; [CDDataBuf_pointer]
        mov     ecx, 2048 / 4
        rep
        movsd   ; move data

  .exit:
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ReadCDWRetr_1 ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Complete sector read (user data, subchannel info, control info)
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = disk number on channel
;> CDSectorAddress = address of sector to read
;-----------------------------------------------------------------------------------------------------------------------
;; Data is read into CDDataBuf.
;-----------------------------------------------------------------------------------------------------------------------
        pushad

        ; cycle until operation is complete or retry count reached
        mov     ecx, MaxRetr

  .NextRetr:
        ; send command
        push    ecx
;       pusha
        ; set sector size
;       mov     [CDBlockSize], 2048 ; 2352
        ; clear packet command buffer
        call    clear_packet_buffer
        ; create packet command for data sector reading
        ; set "Read CD" command code
        mov     byte[PacketCommand], 0x28  ; 0xbe
        ; set sector address
        mov     ax, word[CDSectorAddress + 2]
        xchg    al, ah
        mov     word[PacketCommand + 2], ax
        mov     ax, word[CDSectorAddress]
        xchg    al, ah
        mov     word[PacketCommand + 4], ax
;       mov     eax, [CDSectorAddress]
;       mov     [PacketCommand + 2], eax
        ; set number of sectors to read
        mov     byte[PacketCommand + 8], 1
        ; set complete sector read
;       mov     byte[PacketCommand + 9], 0xf8
        ; send command
        call    SendPacketDatCommand
        pop     ecx
;       ret

;       cmp     [DevErrorCode], 0
        test    eax, eax
        jz      .End_4

        or      ecx, ecx ; for cd load
        jz      .End_4
        dec     ecx

        cmp     [timer_ticks_enable], 0
        jne     @f
        mov     eax, NoTickWaitTime

  .wait:
;       test    eax, eax
        dec     eax
        jz      .NextRetr
        jmp     .wait

    @@: ; delay for 0.5 sec
;       mov     eax, [timer_ticks]
;       add     eax, KCONFIG_SYS_TIMER_FREQ / 2
;
; .Wait:
;       call    change_task
;       cmp     eax, [timer_ticks]
;       ja      .Wait
        loop    .NextRetr

  .End_4:
        mov     [DevErrorCode], eax
        popad
        ret
kendp

; Universal procedures providing packet commands execution in PIO mode

; Maximum allowed time to wait for device reaction to packet command (in ticks)
MaxCDWaitTime = 10 * KCONFIG_SYS_TIMER_FREQ ; 10 seconds

uglobal
  PacketCommand     rb 12   ; packet command buffer
; CDDataBuf         rb 4096 ; buffer for retrieving data from drive
; CDBlockSize       dw ?    ; size of block read, in bytes
  CDSectorAddress   dd ?    ; CD sector address to read
  TickCounter_1     dd ?    ; time current drive operation has started
  WURStartTime      dd ?    ; time waiting for device ready has started
  CDDataBuf_pointer dd ?    ; pointer to buffer for data read
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc SendPacketDatCommand ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Send packet command to ATAPI device, providing transfer of 1 data sector (2048 bytes) from device to host
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;> PacketCommand = 12-byte command packet
;> CDBlockSize = size of data block to receive
;-----------------------------------------------------------------------------------------------------------------------
;< eax = DevErrorCode
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
;       mov     [DevErrorCode], al
        ; set CHS mode
        mov     [ATAAddressMode], al
        ; send ATA command for transferring packet command
        mov     [ATAFeatures], al
        mov     [ATASectorCount], al
        mov     [ATASectorNumber], al
        ; set block size being transferred
        mov     [ATAHead], al
;       mov     ax, [CDBlockSize]
        mov     [ATACylinder], CDBlockSize
        mov     [ATACommand], 0xa0
        call    SendCommandToHDD_1
        test    eax, eax
;       cmp     [DevErrorCode], 0 ; check for error
        jnz     .End_8 ; exit, saving error code

        ; wait until drive is ready to receive packet command
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; port 1x7h
        mov     ecx, NoTickWaitTime

  .WaitDevice0:
        cmp     [timer_ticks_enable], 0
        jne     @f
        dec     ecx
;       test    ecx, ecx
        jz      .Err1_1
        jmp     .test

    @@: call    change_task
        ; check command execution duration
        mov     eax, dword[timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, BSYWaitTime
        ja      .Err1_1 ; timeout error

  .test:
        ; check if device is ready
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitDevice0
        test    al, 0x01 ; ERR signal state
        jnz     .Err6
        test    al, 0x08 ; DRQ signal state
        jz      .WaitDevice0

        ; send packet command
        cli
        mov     dx, [ATABasePortAddr]
        mov     ax, word[PacketCommand]
        out     dx, ax
        mov     ax, word[PacketCommand + 2]
        out     dx, ax
        mov     ax, word[PacketCommand + 4]
        out     dx, ax
        mov     ax, word[PacketCommand + 6]
        out     dx, ax
        mov     ax, word[PacketCommand + 8]
        out     dx, ax
        mov     ax, word[PacketCommand + 10]
        out     dx, ax
        sti

        ; wait for data to be ready
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; port 1x7h
        mov     ecx, NoTickWaitTime

  .WaitDevice1:
        cmp     [timer_ticks_enable], 0
        jne     @f
        dec     ecx
;       test    ecx, ecx
        jz      .Err1_1
        jmp     .test_1

    @@: call    change_task
        ; check command execution duration
        mov     eax, dword[timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, MaxCDWaitTime
        ja      .Err1_1 ; timeout error

  .test_1:
        ; check if device is ready
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitDevice1
        test    al, 0x01 ; ERR signal state
        jnz     .Err6_temp
        test    al, 0x08 ; DRQ signal state
        jz      .WaitDevice1
        ; reveice data block from controller
        mov     edi, [CDDataBuf_pointer] ; 0x7000 ; CDDataBuf
        ; set controller data register address
        mov     dx, [ATABasePortAddr] ; port 1x0h
        ; set counter to block size
        xor     ecx, ecx
        mov     cx, CDBlockSize
        ; calculate block size in 16-bit words
        shr     cx, 1 ; divide block size by 2
        ; receive data block
        cli
        rep
        insw
        sti

  .End_8:
        ; transfer succeeded
        xor     eax, eax
        ret

  .Err1_1:
        ; transfer failed
        xor     eax, eax
        inc     eax
        ret
;       mov     [DevErrorCode], 1
;       ret

  .Err6_temp:
        mov     eax, 7
        ret
;       mov     [DevErrorCode], 7
;       ret

  .Err6:
        mov     eax, 6
        ret
;       mov     [DevErrorCode], 6

; .End_8:
;       ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SendPacketNoDatCommand ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Send packet command to ATAPI device, providing no data transfer
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;> PacketCommand = 12-byte command packet
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        xor     eax, eax
;       mov     [DevErrorCode], al
        ; set CHS mode
        mov     [ATAAddressMode], al
        ; send ATA command for transferring packet command
        mov     [ATAFeatures], al
        mov     [ATASectorCount], al
        mov     [ATASectorNumber], al
        mov     [ATACylinder], ax
        mov     [ATAHead], al
        mov     [ATACommand], 0xa0
        call    SendCommandToHDD_1
;       cmp     [DevErrorCode], 0 ; check for error
        test    eax, eax
        jnz     .End_9  ; exit, saving error code
        ; wait until drive is ready to receive packet command
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; port 1x7h

  .WaitDevice0_1:
        call    change_task
        ; check command execution duration
        mov     eax, dword[timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, BSYWaitTime
        ja      .Err1_3 ; timeout error
        ; check if device is ready
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitDevice0_1
        test    al, 0x01 ; ERR signal state
        jnz     .Err6_1
        test    al, 0x08 ; DRQ signal state
        jz      .WaitDevice0_1

        ; send packet command
;       cli
        mov     dx, [ATABasePortAddr]
        mov     ax, word[PacketCommand]
        out     dx, ax
        mov     ax, word[PacketCommand + 2]
        out     dx, ax
        mov     ax, word[PacketCommand + 4]
        out     dx, ax
        mov     ax, word[PacketCommand + 6]
        out     dx, ax
        mov     ax, word[PacketCommand + 8]
        out     dx, ax
        mov     ax, word[PacketCommand + 10]
        out     dx, ax
;       sti
        cmp     [ignore_CD_eject_wait], 1
        je      .clear_DEC
        ; wait for command receive confirmation
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; port 1x7h

  .WaitDevice1_1:
        call    change_task
        ; check command execution duration
        mov     eax, dword[timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, MaxCDWaitTime
        ja      .Err1_3 ; timeout error
        ; wait for device to become ready
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitDevice1_1
        test    al, 0x01 ; ERR signal state
        jnz     .Err6_1
        test    al, 0x40 ; DRDY signal state
        jz      .WaitDevice1_1

  .clear_DEC:
        and     [DevErrorCode], 0
        popad
        ret

  .Err1_3:
        ; save error code
        xor     eax, eax
        inc     eax
        jmp     .End_9

  .Err6_1:
        mov     eax, 6

  .End_9:
        mov     [DevErrorCode], eax
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SendCommandToHDD_1 ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Send command to specified drive
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number (0 or 1)
;> ATAFeatures = "capabilities"
;> ATASectorCount = sectors count
;> ATASectorNumber = start sector number
;> ATACylinder = start cylinder number
;> ATAHead = start head number
;> ATAAddressMode = addressing mode (0 - CHS, 1 - LBA)
;> ATACommand = command code
;-----------------------------------------------------------------------------------------------------------------------
;< eax = DevErrorCode
;< ATABasePortAddr = base HDD port (on success)
;-----------------------------------------------------------------------------------------------------------------------
;       pushad
;       mov     [DevErrorCode], 0 ; not need
        ; check if addressing mode is valid
        cmp     [ATAAddressMode], 1
        ja      .Err2_4
        ; check if channel number is valid
        movzx   ebx, [ChannelNumber]
        cmp     ebx, 1
        ja      .Err3_4
        ; set base address
        mov     ax, [StandardATABases + ebx * 2]
        mov     [ATABasePortAddr], ax
        ; wait for HDD being ready to receive command
        ; select needed drive
        mov     dx, [ATABasePortAddr]
        add     dx, 6 ; heads register address
        mov     al, [DiskNumber]
        cmp     al, 1 ; check if drive number is valid
        ja      .Err4_4
        shl     al, 4
        or      al, 10100000b
        out     dx, al
        ; wait until drive is ready
        inc     dx
        mov     eax, dword[timer_ticks]
        mov     [TickCounter_1], eax
        mov     ecx, NoTickWaitTime

  .WaitHDReady_2:
        cmp     [timer_ticks_enable], 0
        jne     @f
        dec     ecx
;       test    ecx, ecx
        jz      .Err1_4
        jmp     .test

    @@: call    change_task
        ; check command execution duration
        mov     eax, dword[timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, BSYWaitTime ; 300 ; wait for 3 sec
        ja      .Err1_4 ; timeout error
        ; read status register

  .test:
        in      al, dx
        test    al, 0x80 ; BSY signal state
        jnz     .WaitHDReady_2
        test    al, 0x08 ; DRQ signal state
        jnz     .WaitHDReady_2

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
        ja      .Err5_4
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
;       mov     [DevErrorCode], 0

  .End_10:
        xor     eax, eax
        ret

  .Err1_4:
        ; save error code
        xor     eax, eax
        inc     eax
;       mov     [DevErrorCode], 1
        ret

  .Err2_4:
        mov     eax, 2
;       mov     [DevErrorCode], 2
        ret

  .Err3_4:
        mov     eax, 3
;       mov     [DevErrorCode], 3
        ret

  .Err4_4:
        mov     eax, 4
;       mov     [DevErrorCode], 4
        ret

  .Err5_4:
        mov     eax, 5
;       mov     [DevErrorCode], 5
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc WaitUnitReady ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Wait for device to become ready
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; save operation start time
        mov     eax, dword[timer_ticks]
        mov     [WURStartTime], eax
        ; clear packet command buffer
        call    clear_packet_buffer
        ; create TEST UNIT READY command
        mov     word[PacketCommand], 0
        ; cycle waiting for device to become ready
        mov     ecx, NoTickWaitTime

  .SendCommand:
        ; send ready check command
        call    SendPacketNoDatCommand
        cmp     [timer_ticks_enable], 0
        jne     @f
        cmp     [DevErrorCode], 0
        je      .End_11
;       cmp     ecx, 0
        dec     ecx
        jz      .Error
        jmp     .SendCommand

    @@: call    change_task
        ; check for error
        cmp     [DevErrorCode], 0
        je      .End_11
        ; check execution duration
        mov     eax, dword[timer_ticks]
        sub     eax, [WURStartTime]
        cmp     eax, MaxCDWaitTime
        jb      .SendCommand

  .Error:
        ; timeout error
        mov     [DevErrorCode], 1

  .End_11:
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc prevent_medium_removal ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Lock drive
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; clear packet command buffer
        call    clear_packet_buffer
        ; set command code
        mov     [PacketCommand], 0x1e
        ; set lock code
        mov     [PacketCommand + 4], 011b
        ; send command
        call    SendPacketNoDatCommand
        mov     eax, ATAPI_IDE0_lock
        add     eax, [cdpos]
        dec     eax
        mov     byte[eax], 1
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc allow_medium_removal ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Unlock drive
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; clear packet command buffer
        call    clear_packet_buffer
        ; set command code
        mov     [PacketCommand], 0x1e
        ; set unlock code
        mov     [PacketCommand + 4], 0
        ; send command
        call    SendPacketNoDatCommand
        mov     eax, ATAPI_IDE0_lock
        add     eax, [cdpos]
        dec     eax
        mov     byte[eax], 0
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc LoadMedium ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Load medium into drive
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; clear packet command buffer
        call    clear_packet_buffer
        ; create START/STOP UNIT command
        ; set command code
        mov     word[PacketCommand], 0x1b
        ; set medium load operation
        mov     word[PacketCommand + 4], 00000011b
        ; send command
        call    SendPacketNoDatCommand
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc EjectMedium ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Eject medium from drive
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; clear packet commadnd buffer
        call    clear_packet_buffer
        ; create START/STOP UNIT command
        ; set command code
        mov     word[PacketCommand], 0x1b
        ; set eject medium operation
        mov     word[PacketCommand + 4], 00000010b
        ; send command
        call    SendPacketNoDatCommand
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc check_ATAPI_device_event ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Check if eject button has been pressed
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     eax, dword[timer_ticks]
        sub     eax, [timer_ATAPI_check]
        cmp     eax, 1 * KCONFIG_SYS_TIMER_FREQ
        jb      .end_1

        mov     al, [DRIVE_DATA + 1]
        and     al, 011b
        cmp     al, 010b
        jz      .ide3

  .ide2_1:
        mov     al, [DRIVE_DATA + 1]
        and     al, 01100b
        cmp     al, 01000b
        jz      .ide2

  .ide1_1:
        mov     al, [DRIVE_DATA + 1]
        and     al, 0110000b
        cmp     al, 0100000b
        jz      .ide1

  .ide0_1:
        mov     al, [DRIVE_DATA + 1]
        and     al, 11000000b
        cmp     al, 10000000b
        jz      .ide0

  .end:
        sti
        mov     eax, dword[timer_ticks]
        mov     [timer_ATAPI_check], eax

  .end_1:
        popa
        ret

  .ide3:
        cli
        cmp     [ATAPI_IDE3_lock], 1
        jne     .ide2_1
        cmp     [IDE_Channel_2], 0
        jne     .ide1_1
        cmp     [cd_status], 0
        jne     .end
        mov     [IDE_Channel_2], 1
        call    reserve_ok2
        mov     [ChannelNumber], 1
        mov     [DiskNumber], 1
        mov     [cdpos], 4
        call    GetEvent_StatusNotification
        cmp     byte[CDDataBuf + 4], 1
        je      .eject_ide3
        call    sysfn.cd_audio_ctl._.free
        jmp     .ide2_1

  .eject_ide3:
        call    .eject
        call    sysfn.cd_audio_ctl._.free
        jmp     .ide2_1

  .ide2:
        cli
        cmp     [ATAPI_IDE2_lock], 1
        jne     .ide1_1
        cmp     [IDE_Channel_2], 0
        jne     .ide1_1
        cmp     [cd_status], 0
        jne     .end
        mov     [IDE_Channel_2], 1
        call     reserve_ok2
        mov     [ChannelNumber], 1
        mov     [DiskNumber], 0
        mov     [cdpos], 3
        call    GetEvent_StatusNotification
        cmp     byte[CDDataBuf + 4], 1
        je      .eject_ide2
        call    sysfn.cd_audio_ctl._.free
        jmp     .ide1_1

  .eject_ide2:
        call    .eject
        call    sysfn.cd_audio_ctl._.free
        jmp     .ide1_1

  .ide1:
        cli
        cmp     [ATAPI_IDE1_lock], 1
        jne     .ide0_1
        cmp     [IDE_Channel_1], 0
        jne     .end
        cmp     [cd_status], 0
        jne     .end
        mov     [IDE_Channel_1], 1
        call    reserve_ok2
        mov     [ChannelNumber], 0
        mov     [DiskNumber], 1
        mov     [cdpos], 2
        call    GetEvent_StatusNotification
        cmp     byte[CDDataBuf + 4], 1
        je      .eject_ide1
        call    sysfn.cd_audio_ctl._.free
        jmp     .ide0_1

  .eject_ide1:
        call    .eject
        call    sysfn.cd_audio_ctl._.free
        jmp     .ide0_1

  .ide0:
        cli
        cmp     [ATAPI_IDE0_lock], 1
        jne     .end
        cmp     [IDE_Channel_1], 0
        jne     .end
        cmp     [cd_status], 0
        jne     .end
        mov     [IDE_Channel_1], 1
        call    reserve_ok2
        mov     [ChannelNumber], 0
        mov     [DiskNumber], 0
        mov     [cdpos], 1
        call    GetEvent_StatusNotification
        cmp     byte[CDDataBuf + 4], 1
        je      .eject_ide0
        call    sysfn.cd_audio_ctl._.free
        jmp     .end

  .eject_ide0:
        call    .eject
        call    sysfn.cd_audio_ctl._.free
        jmp     .end

  .eject:
        call    clear_CD_cache
        call    allow_medium_removal
        mov     [ignore_CD_eject_wait], 1
        call    EjectMedium
        mov     [ignore_CD_eject_wait], 0
        ret
kendp

uglobal
  timer_ATAPI_check    dd ?
  ATAPI_IDE0_lock      db ?
  ATAPI_IDE1_lock      db ?
  ATAPI_IDE2_lock      db ?
  ATAPI_IDE3_lock      db ?
  ignore_CD_eject_wait db ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc GetEvent_StatusNotification ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get drive state/event notification
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     [CDDataBuf_pointer], CDDataBuf
        ; clear packet command buffer
        call    clear_packet_buffer
        ; set command code
        mov     [PacketCommand], 0x4a
        mov     [PacketCommand + 1], 00000001b
        ; set message class request
        mov     [PacketCommand + 4], 00010000b
        ; set buffer size
        mov     [PacketCommand + 7], 8
        mov     [PacketCommand + 8], 0
        ; send command
        call    SendPacketDatCommand
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Read_TOC ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Rad TOC information
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     [CDDataBuf_pointer], CDDataBuf
        ; clear packet command buffer
        call    clear_packet_buffer
        ; create packet command to read data sector
        mov     [PacketCommand], 0x43
        ; set format
        mov     [PacketCommand + 2], 1
        ; set buffer size
        mov     [PacketCommand + 7], 0xff
        mov     [PacketCommand + 8], 0
        ; send command
        call    SendPacketDatCommand
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
;kproc ReadCapacity ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Determine total disk sectors
;-----------------------------------------------------------------------------------------------------------------------
;; Arguments are in global variables:
;> ChannelNumber = channel number
;> DiskNumber = drive number on channel
;-----------------------------------------------------------------------------------------------------------------------
;       pusha
;       ; clear packet command buffer
;       call    clear_packet_buffer
;       ; set buffer size, in bytes
;       mov     [CDBlockSize], 8
;       ; create READ CAPACITY command
;       mov     word[PacketCommand], 0x25
;       ; send command
;       call    SendPacketDatCommand
;       popa
;       ret
;kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc clear_packet_buffer ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Clear packet command buffer
;-----------------------------------------------------------------------------------------------------------------------
        and     dword[PacketCommand], 0
        and     dword[PacketCommand + 4], 0
        and     dword[PacketCommand + 8], 0
        ret
kendp
