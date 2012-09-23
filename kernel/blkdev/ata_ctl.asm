;;======================================================================================================================
;;///// ata_ctl.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011-2012 Ostin project <http://ostin.googlecode.com/>
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
BLK_ATA_CTL_CMD_READ_SECTORS           = 0x20
BLK_ATA_CTL_CMD_WRITE_SECTORS          = 0x30
BLK_ATA_CTL_CMD_PACKET                 = 0xa0
BLK_ATA_CTL_CMD_IDENTIFY_PACKET_DEVICE = 0xa1
BLK_ATA_CTL_CMD_READ_DMA               = 0xc8
BLK_ATA_CTL_CMD_WRITE_DMA              = 0xca
BLK_ATA_CTL_CMD_FLUSH_CACHE            = 0xe7
BLK_ATA_CTL_CMD_IDENTIFY_DEVICE        = 0xec

struct blk.ata.ctl.device_t
  base_reg          dw ?
  dev_ctl_reg       dw ?
  last_drive_number db ?
ends

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.create ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= I/O base register
;> ecx #= control base register
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx

        mov     eax, sizeof.blk.ata.ctl.device_t
        call    malloc
        test    eax, eax
        jz      .exit

        mov     ecx, [esp + 4]
        mov     [eax + blk.ata.ctl.device_t.base_reg], cx
        mov     ecx, [esp]
        mov     [eax + blk.ata.ctl.device_t.dev_ctl_reg], cx

        or      [eax + blk.ata.ctl.device_t.last_drive_number], -1

  .exit:
        add     esp, 8
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.destroy ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, ebx
        call    free
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.reset_device ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
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
;> ebx ^= blk.ata.ctl.device_t
;> edi ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
        push    BLK_ATA_CTL_CMD_IDENTIFY_DEVICE
        jmp     blk.ata.ctl._.identify
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.packet ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;> cx #= data size (in blocks)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
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
;> ebx ^= blk.ata.ctl.device_t
;> edi ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
        push    BLK_ATA_CTL_CMD_IDENTIFY_PACKET_DEVICE
        jmp     blk.ata.ctl._.identify
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.select_drive ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> al #= drive number
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        cmp     al, [ebx + blk.ata.ctl.device_t.last_drive_number]
        je      .exit

        push    eax edx

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_DEVICE
        shl     al, 4
        or      al, 10100000b
        out     dx, al

        mov     dx, [ebx + blk.ata.ctl.device_t.dev_ctl_reg]
        add     dx, 2
        in      al, dx
        in      al, dx
        in      al, dx
        in      al, dx

        pop     edx eax

        mov     [ebx + blk.ata.ctl.device_t.last_drive_number], al

  .exit:
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.read_pio ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;> eax #= offset (in blocks)
;> ecx #= size (in blocks)
;> edi ^= destination buffer
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "blk.ata.ctl.read_pio(0x%x, %u, %u)\n", ebx, eax, ecx
        push    edi

  .next_sectors_block:
        push    eax ecx

        cmp     eax, 0x0fffffff
        ja      .error_2

        cmp     ecx, 128
        jbe     @f

        mov     ecx, 128

    @@: mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_SECTOR_COUNT
        xchg    eax, ecx
        out     dx, al
        xchg    eax, ecx
        inc     dx ; BLK_ATA_CTL_REG_LBA_LOW
        out     dx, al
        shr     eax, 8
        inc     dx ; BLK_ATA_CTL_REG_LBA_MID
        out     dx, al
        shr     eax, 8
        inc     dx ; BLK_ATA_CTL_REG_LBA_HIGH
        out     dx, al
        shr     eax, 8
        inc     dx ; BLK_ATA_CTL_REG_DEVICE
        rol     al, 4
        or      al, [ebx + blk.ata.ctl.device_t.last_drive_number]
        rol     al, 4
        or      al, 11100000b
        out     dx, al
        inc     dx ; BLK_ATA_CTL_REG_COMMAND
        mov     al, BLK_ATA_CTL_CMD_READ_SECTORS
        out     dx, al

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        sub     [esp], ecx

  .next_sector:
        call    blk.ata.ctl._.wait_for_drq
        test    eax, eax
        jnz     .error

        push    ecx
        mov     ecx, 512 / 2
        rep
        insw
        pop     ecx

        inc     dword[esp + 4]
        loop    .next_sector

        pop     ecx eax
        test    ecx, ecx
        jnz     .next_sectors_block

        pop     edi
        xor     eax, eax
        ret

  .error_2:
        ; TODO: add error code
        mov_s_  eax, 8

  .error:
        add     esp, 8
        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.read_dma ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;> eax #= offset (in blocks)
;> ecx #= size (in blocks)
;> edi ^= destination buffer
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        inc     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.write_pio ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;> eax #= offset (in blocks)
;> ecx #= size (in blocks)
;> esi ^= source buffer
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "blk.ata.ctl.write_pio(0x%x, %u, %u)\n", ebx, eax, ecx
        push    esi

  .next_sectors_block:
        push    eax ecx

        cmp     eax, 0x0fffffff
        ja      .error_2

        cmp     ecx, 128
        jbe     @f

        mov     ecx, 128

    @@: mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_SECTOR_COUNT
        xchg    eax, ecx
        out     dx, al
        xchg    eax, ecx
        inc     dx ; BLK_ATA_CTL_REG_LBA_LOW
        out     dx, al
        shr     eax, 8
        inc     dx ; BLK_ATA_CTL_REG_LBA_MID
        out     dx, al
        shr     eax, 8
        inc     dx ; BLK_ATA_CTL_REG_LBA_HIGH
        out     dx, al
        shr     eax, 8
        inc     dx ; BLK_ATA_CTL_REG_DEVICE
        rol     al, 4
        or      al, [ebx + blk.ata.ctl.device_t.last_drive_number]
        rol     al, 4
        or      al, 11100000b
        out     dx, al
        inc     dx ; BLK_ATA_CTL_REG_COMMAND
        mov     al, BLK_ATA_CTL_CMD_WRITE_SECTORS
        out     dx, al

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        sub     [esp], ecx

  .next_sector:
        call    blk.ata.ctl._.poll_bsy
        test    eax, eax
        jnz     .error

        push    ecx
        mov     ecx, 512 / 2

    @@: outsw
        jmp     $ + 2
        loop    @b

        pop     ecx

        inc     dword[esp + 4]
        loop    .next_sector

        pop     ecx eax
        test    ecx, ecx
        jnz     .next_sectors_block

        add     dx, BLK_ATA_CTL_REG_COMMAND
        mov     al, BLK_ATA_CTL_CMD_FLUSH_CACHE
        out     dx, al

        call    blk.ata.ctl._.poll_bsy
        test    eax, eax
        jnz     .error

        pop     esi
        xor     eax, eax
        ret

  .error_2:
        ; TODO: add error code
        mov_s_  eax, 8

  .error:
        add     esp, 8
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl.write_dma ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;> eax #= offset (in blocks)
;> ecx #= size (in blocks)
;> esi ^= source buffer
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        inc     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.identify ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;> edi ^= buffer
;> [esp] #= command
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_COMMAND
        mov     al, [esp + 8]
        out     dx, al

        call    blk.ata.ctl._.wait_for_drq
        test    eax, eax
        jnz     .exit

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        mov     ecx, 512 / 2
        rep
        insw

  .exit:
        pop     edx ecx
        add     esp, 4
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.poll_bsy ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        mov     dx, [ebx + blk.ata.ctl.device_t.dev_ctl_reg]
        add     dx, 2
        in      al, dx
        in      al, dx
        in      al, dx
        in      al, dx

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_COMMAND
        mov     ecx, 0x00ffffff

        in      al, dx
        test    al, al
        jz      .no_device_error

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
        jmp     .exit

  .no_device_error:
        ; TODO: add error code
        mov_s_  eax, 7

  .exit:
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.check_for_drq ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     ah, BLK_ATA_CTL_STATUS_DRQ

  .direct:
        push    edx
        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_COMMAND
        in      al, dx
        pop     edx

        test    al, al
        jz      .error
        test    al, BLK_ATA_CTL_STATUS_ERR
        jnz     .error
        test    al, BLK_ATA_CTL_STATUS_DF
        jnz     .error
        test    al, ah
        jz      .error

        xor     eax, eax
        ret

  .error:
        xor     eax, eax
        inc     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.check_for_drdy ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     ah, BLK_ATA_CTL_STATUS_DRDY
        jmp     blk.ata.ctl._.check_for_drq.direct
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.wait_for_drq ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "blk.ata.ctl._.wait_for_drq(0x%x)\n", ebx

        call    blk.ata.ctl._.poll_bsy
        test    eax, eax
        jnz     .exit

        call    blk.ata.ctl._.check_for_drq

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.ctl._.wait_for_drdy ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "blk.ata.ctl._.wait_for_drdy(0x%x)\n", ebx

        call    blk.ata.ctl._.poll_bsy
        test    eax, eax
        jnz     .exit

        call    blk.ata.ctl._.check_for_drdy

  .exit:
        ret
kendp
