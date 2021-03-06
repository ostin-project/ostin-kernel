;;======================================================================================================================
;;///// i8255x.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
;; (c) 2002-2004 MenuetOS <http://menuetos.net/>
;; (c) 2002 Mike Hibbett <mikeh@oceanfree.net>
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
;# References:
;# * eepro100 driver - etherboot 5.0.6 project
;;======================================================================================================================

rxfd_status      = eth_data_start
rxfd_command     = eth_data_start + 2
rxfd_link        = eth_data_start + 4
rxfd_rx_buf_addr = eth_data_start + 8
rxfd_count       = eth_data_start + 12
rxfd_size        = eth_data_start + 14
rxfd_packet      = eth_data_start + 16

uglobal
  eeprom_data:       times 16 dd 0

  lstats:
  tx_good_frames:    dd 0
  tx_coll16_errs:    dd 0
  tx_late_colls:     dd 0
  tx_underruns:      dd 0
  tx_lost_carrier:   dd 0
  tx_deferred:       dd 0
  tx_one_colls:      dd 0
  tx_multi_colls:    dd 0
  tx_total_colls:    dd 0
  rx_good_frames:    dd 0
  rx_crc_errs:       dd 0
  rx_align_errs:     dd 0
  rx_resource_errs:  dd 0
  rx_overrun_errs:   dd 0
  rx_colls_errs:     dd 0
  rx_runt_errs:      dd 0
  done_marker:       dd 0

  confcmd:
  confcmd_status:    dw 0
  confcmd_command:   dw 0
  confcmd_link:      dd 0
endg

iglobal
  net.i8255x.vftbl dd \
    I8255x_probe, \
    I8255x_reset, \
    I8255x_poll, \
    I8255x_transmit, \
    0

  confcmd_data:
    db 22, 0x08, 0, 0, 0, 0x80, 0x32, 0x03, 1
    db 0, 0x2e, 0, 0x60, 0, 0xf2, 0x48, 0, 0x40, 0xf2
    db 0x80, 0x3f, 0x05
endg

uglobal
  txfd:
  txfd_status:       dw 0
  txfd_command:      dw 0
  txfd_link:         dd 0
  txfd_tx_desc_addr: dd 0
  txfd_count:        dd 0
  txfd_tx_buf_addr0: dd 0
  txfd_tx_buf_size0: dd 0
  txfd_tx_buf_addr1: dd 0
  txfd_tx_buf_size1: dd 0

  align 4
  hdr:
  hdr_dst_addr:      times 6 db 0
  hdr_src_addr:      times 6 db 0
  hdr_type:          dw 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc delay_us ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? delays for 30 to 60 us
;-----------------------------------------------------------------------------------------------------------------------
;# I would prefer this routine to be able to delay for
;# a selectable number of microseconds, but this works for now.
;# If you know a better way to do 2us delay, pleae tell me!
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    ecx

        mov     ecx, 2

        in      al, 0x61
        and     al, 0x10
        mov     ah, al

  .dcnt1:
        in      al, 0x61
        and     al, 0x10
        cmp     al, ah
        jz      .dcnt1

        mov     ah, al
        loop    .dcnt1

        pop     ecx
        pop     eax

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc wait_for_cmd_done ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? waits for the hardware to complete a command
;-----------------------------------------------------------------------------------------------------------------------
;> edx = port address
;-----------------------------------------------------------------------------------------------------------------------
;# al destroyed
;-----------------------------------------------------------------------------------------------------------------------
        in      al, dx
        cmp     al, 0
        jne     wait_for_cmd_done
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc mdio_read ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? This probably reads a register in the "physical media interface chip"
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = phy_id
;> ecx = location
;-----------------------------------------------------------------------------------------------------------------------
;< eax = data
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, [io_addr]
        add     edx, 16 ; SCBCtrlMDI

        mov     eax, 0x08000000
        shl     ecx, 16
        or      eax, ecx
        shl     ebx, 21
        or      eax, ebx

        out     dx, eax

  .mrlp:
        call    delay_us
        in      eax, dx
        mov     ecx, eax
        and     ecx, 0x10000000
        jz      .mrlp

        and     eax, 0xffff
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc mdio_write ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? This probably writes a register in the "physical media interface chip"
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = phy_id
;> ecx = location
;> edx = data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = data
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, 0x04000000
        shl     ecx, 16
        or      eax, ecx
        shl     ebx, 21
        or      eax, ebx
        or      eax, edx

        mov     edx, [io_addr]
        add     edx, 16 ; SCBCtrlMDI
        out     dx, eax

  .mwlp:
        call    delay_us
        in      eax, dx
        mov     ecx, eax
        and     ecx, 0x10000000
        jz      .mwlp

        and     eax, 0xffff
        ret
kendp

;/***********************************************************************/
;/*                       I82557 related defines                        */
;/***********************************************************************/

; Serial EEPROM section.
;   A "bit" grungy, but we work our way through bit-by-bit :->.
;  EEPROM_Ctrl bits.
EE_SHIFT_CLK  = 0x01 ; EEPROM shift clock.
EE_CS         = 0x02 ; EEPROM chip select.
EE_DATA_WRITE = 0x04 ; EEPROM chip data in.
EE_DATA_READ  = 0x08 ; EEPROM chip data out.
EE_WRITE_0    = 0x4802
EE_WRITE_1    = 0x4806
EE_ENB        = 0x4802

; The EEPROM commands include the alway-set leading bit.
EE_READ_CMD   = 6

; The SCB accepts the following controls for the Tx and Rx units:
CU_START      = 0x0010
CU_RESUME     = 0x0020
CU_STATSADDR  = 0x0040
CU_SHOWSTATS  = 0x0050 ; Dump statistics counters.
CU_CMD_BASE   = 0x0060 ; Base address to add to add CU commands.
CU_DUMPSTATS  = 0x0070 ; Dump then reset stats counters.

RX_START      = 0x0001
RX_RESUME     = 0x0002
RX_ABORT      = 0x0004
RX_ADDR_LOAD  = 0x0006
RX_RESUMENR   = 0x0007
INT_MASK      = 0x0100
DRVR_INT      = 0x0200   ; Driver generated interrupt.

;-----------------------------------------------------------------------------------------------------------------------
kproc do_eeprom_cmd ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? writes a cmd to the ethernet cards eeprom, by bit bashing
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = cmd
;> ecx = cmd length
;-----------------------------------------------------------------------------------------------------------------------
;< eax = ...
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, [io_addr] ; We only require the value in dx
        add     dx, 14 ; the value SCBeeprom

        mov     ax, EE_ENB
        out     dx, ax
        call    delay_us

        mov     ax, 0x4803 ; EE_ENB | EE_SHIFT_CLK
        out     dx, ax
        call    delay_us

        ; dx holds ee_addr
        ; ecx holds count
        ; eax holds cmd
        xor     edi, edi ; this will be the receive data

  .dec_001:
        mov     esi, 1

        dec     ecx
        shl     esi, cl
        inc     ecx
        and     esi, ebx
        mov     eax, EE_WRITE_0 ; I am assuming this doesnt affect the flags..
        cmp     esi, 0
        jz      .dec_002
        mov     eax, EE_WRITE_1

  .dec_002:
        out     dx, ax
        call    delay_us

        or      ax, EE_SHIFT_CLK
        out     dx, ax
        call    delay_us

        shl     edi, 1

        in      ax, dx
        and     ax, EE_DATA_READ
        cmp     ax, 0
        jz      .dec_003
        inc     edi

  .dec_003:
        loop    .dec_001

        mov     ax, EE_ENB
        out     dx, ax
        call    delay_us

        mov     ax, 0x4800
        out     dx, ax
        call    delay_us

        mov     eax, edi

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc I8255x_probe ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Searches for an ethernet card, enables it and clears the rx buffer
;? If a card was found, it enables the ethernet -> TCPIP link
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "Probing i8255x device\n"
        mov     eax, [io_addr]

        stdcall pci_read_config_word, dword[pci_bus], dword[pci_dev], PCI_COMMAND_MASTER
        or      al, 0x05
        stdcall pci_write_config_word, dword[pci_bus], dword[pci_dev], PCI_COMMAND_MASTER, eax

        mov     ebx, 0x6000000
        mov     ecx, 27
        call    do_eeprom_cmd
        and     eax, 0xffe0000
        cmp     eax, 0xffe0000
        je      .bige

        mov     ebx, 0x1800000
        mov     ecx, 0x40
        jmp     .doread

  .bige:
        mov     ebx, 0x6000000
        mov     ecx, 0x100

  .doread:
        ; do-eeprom-cmd will destroy all registers
        ; we have eesize in ecx
        ; read_cmd in ebx

        ; Ignore full eeprom - just load the mac address
        mov     ecx, 0

  .drlp:
        push    ecx ; save count
        push    ebx
        mov     eax, ecx
        shl     eax, 16
        or      ebx, eax
        mov     ecx, 27
        call    do_eeprom_cmd

        pop     ebx
        pop     ecx

        mov     edx, ecx
        shl     edx, 2
        mov     esi, eeprom_data
        add     esi, edx
        mov     [esi], eax

        inc     ecx
        cmp     ecx, 16
        jne     .drlp

        ; OK, we have the MAC address.
        ; Now reset the card

        mov     edx, [io_addr]
        add     dx, 8 ; SCBPort
        xor     eax, eax ; The reset cmd == 0
        out     dx, eax

        mov     esi, 10
        call    delay_ms ; Give the card time to warm up.

        mov     eax, lstats
        mov     edx, [io_addr]
        add     edx, 4 ; SCBPointer
        out     dx, eax

        mov     eax, 0x0140 ; INT_MASK | CU_STATSADDR
        mov     edx, [io_addr]
        add     edx, 2 ; SCBCmd
        out     dx, ax

        call    wait_for_cmd_done

        mov     eax, 0
        mov     edx, [io_addr]
        add     edx, 4 ; SCBPointer
        out     dx, eax

        mov     eax, 0x0106 ; INT_MASK | RX_ADDR_LOAD
        mov     edx, [io_addr]
        add     edx, 2 ; SCBCmd
        out     dx, ax

        call    wait_for_cmd_done

        ; build rxrd structure
        mov     ax, 0x0001
        mov     [rxfd_status], ax
        mov     ax, 0x0000
        mov     [rxfd_command], ax

        mov     eax, rxfd_status
        sub     eax, OS_BASE
        mov     [rxfd_link], eax

        mov     eax, Ether_buffer
        sub     eax, OS_BASE
        mov     [rxfd_rx_buf_addr], eax

        mov     ax, 0
        mov     [rxfd_count], ax

        mov     ax, 1528
        mov     [rxfd_size], ax

        mov     edx, [io_addr]
        add     edx, 4 ; SCBPointer

        mov     eax, rxfd_status
        sub     eax, OS_BASE
        out     dx, eax

        mov     edx, [io_addr]
        add     edx, 2 ; SCBCmd

        mov     ax, 0x0101 ; INT_MASK | RX_START
        out     dx, ax

        call    wait_for_cmd_done

        ; start the reciver

        mov     ax, 0
        mov     [rxfd_status], ax

        mov     ax, 0xc000
        mov     [rxfd_command], ax

        mov     edx, [io_addr]
        add     edx, 4 ; SCBPointer

        mov     eax, rxfd_status
        sub     eax, OS_BASE
        out     dx, eax

        mov     edx, [io_addr]
        add     edx, 2 ; SCBCmd

        mov     ax, 0x0101 ; INT_MASK | RX_START
        out     dx, ax

        ; Init TX Stuff

        mov     edx, [io_addr]
        add     edx, 4 ; SCBPointer

        mov     eax, 0
        out     dx, eax

        mov     edx, [io_addr]
        add     edx, 2 ; SCBCmd

        mov     ax, 0x0160 ; INT_MASK | CU_CMD_BASE
        out     dx, ax

        call    wait_for_cmd_done

        ; Set TX Base address

        ; First, set up confcmd values

        mov     ax, 2
        mov     [confcmd_command], ax
        mov     eax, txfd
        sub     eax, OS_BASE
        mov     [confcmd_link], eax

        mov     ax, 1
        mov     [txfd_command], ax ; CmdIASetup

        mov     ax, 0
        mov     [txfd_status], ax

        mov     eax, confcmd
        sub     eax, OS_BASE
        mov     [txfd_link], eax

        ; ETH_ALEN is 6 bytes

        mov     esi, eeprom_data
        mov     edi, node_addr
        mov     ecx, 3

  .drp000:
        mov     eax, [esi]
        mov     [edi], al
        shr     eax, 8
        inc     edi
        mov     [edi], al
        inc     edi
        add     esi, 4
        loop    .drp000

        ; Hard code your MAC address into node_addr at this point,
        ; If you cannot read the MAC address from the eeprom in the previous step.
        ; You also have to write the mac address into txfd_tx_desc_addr, rather
        ; than taking data from eeprom_data

        mov     esi, eeprom_data
        mov     edi, txfd_tx_desc_addr
        mov     ecx, 3

  .drp001:
        mov     eax, [esi]
        mov     [edi], al
        shr     eax, 8
        inc     edi
        mov     [edi], al
        inc     edi
        add     esi, 4
        loop    .drp001


        mov     esi, eeprom_data + 6 * 4
        mov     eax, [esi]
        shr     eax, 8
        and     eax, 0x3f
        cmp     eax, 4 ; DP83840
        je      .drp002
        cmp     eax, 10 ; DP83840A
        je      .drp002
        jmp     .drp003

  .drp002:
        mov     ebx, [esi]
        and     ebx, 0x1f
        push    ebx
        mov     ecx, 23
        call    mdio_read
        pop     ebx
        or      eax, 0x0422
        mov     ecx, 23
        mov     edx, eax
        call    mdio_write

  .drp003:
        mov     ax, 0x4002 ; Cmdsuspend | CmdConfigure
        mov     [confcmd_command], ax
        mov     ax, 0
        mov     [confcmd_status], ax
        mov     eax, txfd
        mov     [confcmd_link], eax
        mov     ebx, confcmd_data
        mov     al, 0x88 ; fifo of 8 each
        mov     [ebx + 1], al
        mov     al, 0
        mov     [ebx + 4], al
        mov     al, 0x80
        mov     [ebx + 5], al
        mov     al, 0x48
        mov     [ebx + 15], al
        mov     al, 0x80
        mov     [ebx + 19], al
        mov     al, 0x05
        mov     [ebx + 21], al

        mov     eax, txfd
        sub     eax, OS_BASE
        mov     edx, [io_addr]
        add     edx, 4 ; SCBPointer
        out     dx, eax

        mov     eax, 0x0110 ; INT_MASK | CU_START
        mov     edx, [io_addr]
        add     edx, 2 ; SCBCmd
        out     dx, ax

        call    wait_for_cmd_done
        jmp     .skip

  .drp004:
        ; wait for thing to start
        mov     ax, [txfd_status]
        cmp     ax, 0
        je      .drp004

  .skip:
        ; Indicate that we have successfully reset the card
        mov     eax, [pci_data]
        mov     [eth_status], eax

  .I8255x_exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc I8255x_reset ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Place the chip (ie, the ethernet card) into a virgin state
;-----------------------------------------------------------------------------------------------------------------------
;# All registers destroyed
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc I8255x_poll ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Polls the ethernet card for a received packet
;-----------------------------------------------------------------------------------------------------------------------
;< Received data, if any, ends up in Ether_buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     ax, 0 ; assume no data
        mov     [eth_rx_data_len], ax

        mov     ax, [rxfd_status]
        cmp     ax, 0
        je      .i8p_exit

        mov     ax, 0
        mov     [rxfd_status], ax

        mov     ax, 0xc000
        mov     [rxfd_command], ax

        mov     edx, [io_addr]
        add     edx, 4 ; SCBPointer

        mov     eax, rxfd_status
        sub     eax, OS_BASE
        out     dx, eax

        mov     edx, [io_addr]
        add     edx, 2 ; SCBCmd

        mov     ax, 0x0101 ; INT_MASK | RX_START
        out     dx, ax

        call    wait_for_cmd_done

        mov     esi, rxfd_packet
        mov     edi, Ether_buffer
        mov     ecx, 1518
        rep
        movsb

        mov     ax, [rxfd_count]
        and     ax, 0x3fff
        mov     [eth_rx_data_len], ax

  .i8p_exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc I8255x_transmit ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Transmits a packet of data via the ethernet card
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to 48 bit destination address
;> bx = type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;-----------------------------------------------------------------------------------------------------------------------
        mov     [hdr_type], bx

        mov     eax, [edi]
        mov     [hdr_dst_addr], eax
        mov     ax, [edi + 4]
        mov     [hdr_dst_addr + 4], ax

        mov     eax, [node_addr]
        mov     [hdr_src_addr], eax
        mov     ax, [node_addr + 4]
        mov     [hdr_src_addr + 4], ax

        mov     edx, [io_addr]
        in      ax, dx
        and     ax, 0xfc00
        out     dx, ax

        xor     ax, ax
        mov     [txfd_status], ax
        mov     ax, 0x400c ; Cmdsuspend | CmdTx | CmdTxFlex
        mov     [txfd_command], ax
        mov     eax, txfd
        mov     [txfd_link], eax
        mov     eax, 0x02208000
        mov     [txfd_count], eax
        mov     eax, txfd_tx_buf_addr0
        sub     eax, OS_BASE
        mov     [txfd_tx_desc_addr], eax
        mov     eax, hdr
        sub     eax, OS_BASE
        mov     [txfd_tx_buf_addr0], eax
        mov     eax, 14 ; sizeof hdr
        mov     [txfd_tx_buf_size0], eax

        ; Copy the buffer address and size in
        mov     eax, esi
        sub     eax, OS_BASE
        mov     [txfd_tx_buf_addr1], eax
        mov     eax, ecx
        mov     [txfd_tx_buf_size1], eax

        mov     eax, txfd
        sub     eax, OS_BASE
        mov     edx, [io_addr]
        add     edx, 4 ; SCBPointer
        out     dx, eax

        mov     ax, 0x0110 ; INT_MASK | CU_START
        mov     edx, [io_addr]
        add     edx, 2 ; SCBCmd
        out     dx, ax

        call    wait_for_cmd_done

        mov     edx, [io_addr]
        in      ax, dx

  .I8t_001:
        mov     ax, [txfd_status]
        cmp     ax, 0
        je      .I8t_001

        mov     edx, [io_addr]
        in      ax, dx

        ret
kendp
