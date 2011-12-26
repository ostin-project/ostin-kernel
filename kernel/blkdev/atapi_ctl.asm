;;======================================================================================================================
;;///// atapi_ctl.asm ////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

BLK_ATAPI_CTL_CMD_TEST_UNIT_READY               = 0x00
BLK_ATAPI_CTL_CMD_START_STOP_UNIT               = 0x1b
BLK_ATAPI_CTL_CMD_PREVENT_ALLOW_MEDIUM_REMOVAL  = 0x1e
BLK_ATAPI_CTL_CMD_READ_CDROM_CAPACITY           = 0x25
BLK_ATAPI_CTL_CMD_READ_10                       = 0x28
BLK_ATAPI_CTL_CMD_READ_TOC                      = 0x43
BLK_ATAPI_CTL_CMD_PLAY_AUDIO_MSF                = 0x47
BLK_ATAPI_CTL_CMD_GET_EVENT_STATUS_NOTIFICATION = 0x4a
BLK_ATAPI_CTL_CMD_PAUSE_RESUME                  = 0x4b
BLK_ATAPI_CTL_CMD_READ_12                       = 0xa8

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl.read ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_data_t
;> eax #= offset (in blocks)
;> ecx #= size (in blocks)
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx

        push    .fill_command_buffer_10

        test    eax, 0xffff0000
        jz      @f

        mov     dword[esp], .fill_command_buffer_12

    @@: call    blk.atapi.ctl._.send_dat_command

        add     esp, 8
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .fill_command_buffer_10: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> edx ^= params
;> esi ^= empty command buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     byte[esi], BLK_ATAPI_CTL_CMD_READ_10
        mov     ecx, [edx]
        xchg    cl, ch
        mov     [esi + 7], cx
        jmp     .fill_command_buffer_common

;-----------------------------------------------------------------------------------------------------------------------
  .fill_command_buffer_12: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> edx ^= params
;> esi ^= empty command buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     byte[esi], BLK_ATAPI_CTL_CMD_READ_12
        mov     ecx, [edx]
        bswap   ecx
        mov     [esi + 6], ecx

  .fill_command_buffer_common:
        mov     ecx, [edx + 4]
        bswap   ecx
        mov     [esi + 2], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl.test_unit_ready ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    .fill_command_buffer
        call    blk.atapi.ctl._.send_no_dat_command
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .fill_command_buffer: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= params
;> esi ^= empty command buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     byte[esi], BLK_ATAPI_CTL_CMD_TEST_UNIT_READY
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl.load_medium ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Eject medium from drive
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    .fill_command_buffer
        call    blk.atapi.ctl._.send_no_dat_command
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .fill_command_buffer: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= params
;> esi ^= empty command buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     byte[esi], BLK_ATAPI_CTL_CMD_START_STOP_UNIT
        mov     byte[esi + 4], 00000011b ; load medium
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl.eject_medium ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Eject medium from drive
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_data_t
;-----------------------------------------------------------------------------------------------------------------------
        push    .fill_command_buffer
        call    blk.atapi.ctl._.send_no_dat_command
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .fill_command_buffer: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= params
;> esi ^= empty command buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     byte[esi], BLK_ATAPI_CTL_CMD_START_STOP_UNIT
        mov     byte[esi + 4], 00000010b ; eject medium
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl.get_event_status_notification ;/////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get drive state/event notification
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_data_t
;> edi ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
        push    .fill_command_buffer
        call    blk.atapi.ctl._.send_dat_command
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .fill_command_buffer: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= params
;> esi ^= empty command buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     byte[esi], BLK_ATAPI_CTL_CMD_GET_EVENT_STATUS_NOTIFICATION
        mov     byte[esi + 1], 00000001b
        mov     byte[esi + 4], 00010000b ; message class request
        mov     word[esi + 7], 0x0800 ; buffer size (8 bytes)
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl.read_toc ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read TOC information
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_data_t
;> edi ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
        push    .fill_command_buffer
        call    blk.atapi.ctl._.send_dat_command
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .fill_command_buffer: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= params
;> esi ^= empty command buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     byte[esi], BLK_ATAPI_CTL_CMD_READ_TOC
        mov     byte[esi + 2], 001b ; format
        mov     word[esi + 7], 0x00ff ; buffer size (65280 bytes)
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl._.send_no_dat_command ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.device_data_t
;> [esp + 4] ^= command buffer callback, f(esi)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx

        xor     ecx, ecx
        lea     eax, [esp + 4 + 4]
        call    blk.atapi.ctl._.send_packet_command
        test    eax, eax
        jnz     .exit

        call    blk.ata.ctl._.wait_for_drdy

  .exit:
        pop     ecx
        ret     4
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl._.send_dat_command ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.ctl.device_data_t
;> edi ^= buffer
;> ecx #= buffer size
;> [esp + 4] ^= command buffer callback, f(esi)
;-----------------------------------------------------------------------------------------------------------------------
        lea     eax, [esp + 4]
        call    blk.atapi.ctl._.send_packet_command
        test    eax, eax
        jnz     .exit

        call    blk.ata.ctl._.wait_for_drq
        test    eax, eax
        jnz     .exit

        push    ecx edx

        mov     dx, [ebx + blk.atapi.device_data_t.base_reg]
        shl     ecx, 11 - 1
        rep
        insw

        pop     edx ecx

  .exit:
        ret     4
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.atapi.ctl._.send_packet_command ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.atapi.ctl.device_data_t
;> eax ^= command buffer callback address, f(esi)
;> ecx #= buffer size
;-----------------------------------------------------------------------------------------------------------------------
        push    edx

        push    eax
        call    blk.ata.ctl.packet
        test    eax, eax
        pop     edx
        jnz     .exit

        push    esi
        push    eax eax eax
        mov     esi, esp

        pusha
        add     edx, 4
        call    dword[edx - 4]
        popa

        push    ecx

        mov     dx, [ebx + blk.atapi.device_data_t.base_reg]
        mov     ecx, 12 / 2
        rep
        outsw

        pop     ecx

        add     esp, 12
        pop     esi

        xor     eax, eax

  .exit:
        pop     edx
        ret
kendp
