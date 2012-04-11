;;======================================================================================================================
;;///// dev_hdcd.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2012 Ostin project <http://ostin.googlecode.com/>
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

uglobal
  ide_ctl:
    .pri dd ?
    .sec dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
FindHDD: ;//////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Find HDDs and CDs
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, 0x01f0
        mov     ecx, 0x03f4
        call    blk.ata.ctl.create
        mov     [ide_ctl.pri], eax
        test    eax, eax
        jz      .try_sec_ctl

        xchg    eax, ebx

        xor     eax, eax
        call    .identify_device

        xor     eax, eax
        inc     al
        call    .identify_device

  .try_sec_ctl:
        mov     eax, 0x0170
        mov     ecx, 0x0374
        call    blk.ata.ctl.create
        mov     [ide_ctl.sec], eax
        test    eax, eax
        jz      EndFindHDD

        xchg    eax, ebx

        xor     eax, eax
        call    .identify_device

        xor     eax, eax
        inc     al
        call    .identify_device

        jmp     EndFindHDD

;-----------------------------------------------------------------------------------------------------------------------
  .identify_device: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> al #= drive number
;> ebx ^= blk.ata.ctl.device_t
;-----------------------------------------------------------------------------------------------------------------------
        shl     byte[DRIVE_DATA + 1], 2

        push    eax
        call    blk.ata.ctl.reset_device
        test    eax, eax
        pop     eax
        jnz     .error

        call    blk.ata.ctl.select_drive
        test    eax, eax
        jnz     .error

        mov     edi, Sector512
        call    blk.ata.ctl.identify_device
        test    eax, eax
        jnz     .check_for_packet_device

        mov     eax, ebx
        mov     cl, [ebx + blk.ata.ctl.device_t.last_drive_number]
        mov     edx, Sector512
        call    blk.ata.create
        test    eax, eax
        jz      .error

        inc     byte[DRIVE_DATA + 1]
        jmp     .exit

  .check_for_packet_device:
        cmp     eax, 6
        jne     .error

        mov     dx, [ebx + blk.ata.ctl.device_t.base_reg]
        add     dx, BLK_ATA_CTL_REG_LBA_MID
        in      al, dx
        xchg    al, ah
        inc     dx ; BLK_ATA_CTL_REG_LBA_HIGH
        in      al, dx

        cmp     ax, 0x14eb
        je      .identify_packet_device
        cmp     ax, 0x6996
        jne     .error

  .identify_packet_device:
        mov     edi, Sector512
        call    blk.ata.ctl.identify_packet_device
        test    eax, eax
        jnz     .error

        mov     eax, ebx
        mov     cl, [ebx + blk.ata.ctl.device_t.last_drive_number]
        mov     edx, Sector512
        call    blk.atapi.create
        test    eax, eax
        jz      .error

        inc     byte[DRIVE_DATA + 1]
        inc     byte[DRIVE_DATA + 1]

  .exit:
        mov     edx, eax
        mov     ecx, blkdev_list
        list_add edx, ecx

  .error:
        ret

;-----------------------------------------------------------------------------------------------------------------------
kproc check_for_ide_controller ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax @= pack[16(vendor ID), 16(device ID)]
;> bl #= bus
;> cl #= device/function
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        stdcall pci_read_config_byte, ebx, ecx, PCI_HEADER_TYPE
        test    al, 0x7f ; header type #0?
        jnz     .exit

        stdcall pci_read_config_dword, ebx, ecx, PCI_REV_ID
        rol     eax, 16
        cmp     ax, 0x0101 ; Mass Storage Controller / IDE Controller
        jne     .exit

        klog_   LOG_DEBUG, "Mass Storage Controller / IDE Controller found\n"

        ; ...

  .exit:
        pop     eax
        xor     eax, eax
        ret
kendp

EndFindHDD:
;       mov     eax, check_for_ide_controller
;       call    scan_bus
