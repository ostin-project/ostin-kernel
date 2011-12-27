;;======================================================================================================================
;;///// ata_ctl.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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

BLK_ATA_CTL_REG_DATA         = 0
BLK_ATA_CTL_REG_FEATURES     = 1
BLK_ATA_CTL_REG_SECTOR_COUNT = 2
BLK_ATA_CTL_REG_LBA_LOW      = 3
BLK_ATA_CTL_REG_LBA_MID      = 4
BLK_ATA_CTL_REG_LBA_HIGH     = 5
BLK_ATA_CTL_REG_DEVICE       = 6
BLK_ATA_CTL_REG_COMMAND      = 7

BLK_ATA_CTL_STATUS_ERR  = 00000001b
BLK_ATA_CTL_STATUS_CHK  = BLK_ATA_CTL_STATUS_ERR
BLK_ATA_CTL_STATUS_DRQ  = 00001000b
BLK_ATA_CTL_STATUS_SERV = 00010000b
BLK_ATA_CTL_STATUS_DF   = 00100000b
BLK_ATA_CTL_STATUS_DMRD = BLK_ATA_CTL_STATUS_DF
BLK_ATA_CTL_STATUS_DRDY = 01000000b
BLK_ATA_CTL_STATUS_BSY  = 10000000b

BLK_ATA_CTL_CMD_DEVICE_RESET           = 0x08
BLK_ATA_CTL_CMD_PACKET                 = 0xa0
BLK_ATA_CTL_CMD_IDENTIFY_PACKET_DEVICE = 0xa1
BLK_ATA_CTL_CMD_IDENTIFY_DEVICE        = 0xec

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.initialize ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        or      [blk.ata.ctl._.data.last_drive_number], -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.reset_device ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        call    blk.ata.ctl._.select_drive

        mov     dx, [ebx + blk.ata.device_data_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_COMMAND
        mov     al, BLK_ATA_CTL_CMD_DEVICE_RESET
        out     dx, al

        mov     ecx, 0x00080000

  .wait_loop:
        dec     ecx
        jz      .timeout_error

        in      al, dx
        test    al, BLK_ATA_CTL_STATUS_BSY
        jnz     .wait_loop

        xor     eax, eax
        jmp     .exit

  .timeout_error:
        xor     eax, eax
        inc     eax

  .exit:
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.identify_device ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_data_t
;> edi ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
        push    BLK_ATA_CTL_CMD_IDENTIFY_DEVICE
        jmp     blk.ata.ctl._.identify
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.packet ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_data_t
;> cx #= data size (in blocks)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        call    blk.ata.ctl._.select_drive

        mov     dx, [ebx + blk.ata.device_data_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_LBA_MID
        mov     al, cl
        out     dx, al

        inc     dx ; BLK_ATA_CTL_REG_LBA_HIGH
        mov     al, ch
        out     dx, al

        add     dx, 2 ; BLK_ATA_CTL_REG_COMMAND
        mov     al, BLK_ATA_CTL_CMD_PACKET
        out     dx, al

        call    blk.ata.ctl._.wait_for_drq

        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.identify_packet_device ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_data_t
;> edi ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
        push    BLK_ATA_CTL_CMD_IDENTIFY_PACKET_DEVICE
        jmp     blk.ata.ctl._.identify
kendp

uglobal
  blk.ata.ctl._.data:
    .last_drive_number dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.select_drive ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        mov     eax, dword[ebx + blk.ata.device_data_t.base_reg - 2]
        mov     al, [ebx + blk.ata.device_data_t.drive_number]
        cmp     eax, [blk.ata.ctl._.data.last_drive_number]
        je      .exit

        push    eax edx

        mov     dx, [ebx + blk.ata.device_data_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_DEVICE
        shl     al, 4
        out     dx, al

        mov     dx, [ebx + blk.ata.device_data_t.dev_ctl_reg]
        in      al, dx
        in      al, dx
        in      al, dx
        in      al, dx

        pop     edx eax

        mov     [blk.ata.ctl._.data.last_drive_number], eax

  .exit:
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.identify ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_data_t
;> [esp] #= command
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        call    blk.ata.ctl._.select_drive

        mov     dx, [ebx + blk.ata.device_data_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_COMMAND
        mov     al, [esp + 8]
        out     dx, al

        call    blk.ata.ctl._.wait_for_drq
        test    eax, eax
        jnz     .exit

        mov     dx, [ebx + blk.ata.device_data_t.base_reg]
        mov     ecx, 512 / 2
        rep
        insw

  .exit:
        pop     edx ecx
        add     esp, 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.wait_for_drq ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     ah, BLK_ATA_CTL_STATUS_DRQ

  .direct:
        push    ecx edx

        mov     dx, [ebx + blk.ata.device_data_t.dev_ctl_reg]
        mov     ecx, 4

  .dummy_loop:
        dec     ecx
        js      .wait

        in      al, dx
        test    al, BLK_ATA_CTL_STATUS_BSY
        jnz     .dummy_loop
        test    al, ah
        jz      .dummy_loop

  .wait:
        mov     dx, [ebx + blk.ata.device_data_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_COMMAND
        mov     ecx, 0x00ffffff

  .wait_loop:
        dec     ecx
        jz      .timeout_error

        in      al, dx
        test    al, BLK_ATA_CTL_STATUS_BSY
        jnz     .wait_loop
        test    al, BLK_ATA_CTL_STATUS_ERR
        jnz     .device_error
        test    al, ah
        jz      .wait_loop

        xor     eax, eax
        jmp     .exit

  .timeout_error:
        xor     eax, eax
        inc     eax
        jmp     .exit

  .device_error:
        mov_s_  eax, 6

  .exit:
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.wait_for_drdy ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     ah, BLK_ATA_CTL_STATUS_DRDY
        jmp     blk.ata.ctl._.wait_for_drq.direct
kendp
