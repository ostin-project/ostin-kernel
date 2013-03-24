;;======================================================================================================================
;;///// sis900.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
;; (c) 2004 MenuetOS <http://menuetos.net/>
;; (c) 2004 Jason Delozier <cordata51@hotmail.com>
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
;# * SIS900 driver - etherboot 5.0.6 project
;;======================================================================================================================

;********************************************************************
; ToDo:
;   * Enable MII interface for reading speed and duplex settings
;   * Update Poll routine to support packet fragmentation
;   * Add additional support for other sis900 based cards
;********************************************************************

;* buffers and descriptors
cur_rx db 0

NUM_RX_DESC            = 4               ; Number of RX descriptors
NUM_TX_DESC            = 1               ; Number of TX descriptors
RX_BUFF_SZ             = 1520            ; Buffer size for each Rx buffer
TX_BUFF_SZ             = 1516            ; Buffer size for each Tx buffer

uglobal
  txd rd 3 * NUM_TX_DESC
  rxd rd 3 * NUM_RX_DESC
endg

iglobal
  net.sis900.vftbl dd \
    SIS900_probe, \
    SIS900_reset, \
    SIS900_poll, \
    SIS900_transmit, \
    0
endg

txb                    = eth_data_start
rxb                    = txb + NUM_TX_DESC * TX_BUFF_SZ
SIS900_ETH_ALEN        = 6          ; Size of Ethernet address
SIS900_ETH_HLEN        = 14         ; Size of ethernet header
SIS900_ETH_ZLEN        = 60         ; Minimum packet length
SIS900_DSIZE           = 0x00000fff
SIS900_CRC_SIZE        = 4
SIS900_RFADDR_shift    = 16
;SIS900 Symbolic offsets to registers.
SIS900_cr              = 0x0        ; Command Register
SIS900_cfg             = 0x4        ; Configuration Register
SIS900_mear            = 0x8        ; EEPROM Access Register
SIS900_ptscr           = 0xc        ; PCI Test Control Register
SIS900_isr             = 0x10       ; Interrupt Status Register
SIS900_imr             = 0x14       ; Interrupt Mask Register
SIS900_ier             = 0x18       ; Interrupt Enable Register
SIS900_epar            = 0x18       ; Enhanced PHY Access Register
SIS900_txdp            = 0x20       ; Transmit Descriptor Pointer Register
SIS900_txcfg           = 0x24       ; Transmit Configuration Register
SIS900_rxdp            = 0x30       ; Receive Descriptor Pointer Register
SIS900_rxcfg           = 0x34       ; Receive Configuration Register
SIS900_flctrl          = 0x38       ; Flow Control Register
SIS900_rxlen           = 0x3c       ; Receive Packet Length Register
SIS900_rfcr            = 0x48       ; Receive Filter Control Register
SIS900_rfdr            = 0x4c       ; Receive Filter Data Register
SIS900_pmctrl          = 0xb0       ; Power Management Control Register
SIS900_pmer            = 0xb4       ; Power Management Wake-up Event Register
;SIS900 Command Register Bits
SIS900_RELOAD          = 0x00000400
SIS900_ACCESSMODE      = 0x00000200
SIS900_RESET           = 0x00000100
SIS900_SWI             = 0x00000080
SIS900_RxRESET         = 0x00000020
SIS900_TxRESET         = 0x00000010
SIS900_RxDIS           = 0x00000008
SIS900_RxENA           = 0x00000004
SIS900_TxDIS           = 0x00000002
SIS900_TxENA           = 0x00000001
;SIS900 Configuration Register Bits
SIS900_DESCRFMT        = 0x00000100 ; 7016 specific
SIS900_REQALG          = 0x00000080
SIS900_SB              = 0x00000040
SIS900_POW             = 0x00000020
SIS900_EXD             = 0x00000010
SIS900_PESEL           = 0x00000008
SIS900_LPM             = 0x00000004
SIS900_BEM             = 0x00000001
SIS900_RND_CNT         = 0x00000400
SIS900_FAIR_BACKOFF    = 0x00000200
SIS900_EDB_MASTER_EN   = 0x00002000
;SIS900 Eeprom Access Reigster Bits
SIS900_MDC             = 0x00000040
SIS900_MDDIR           = 0x00000020
SIS900_MDIO            = 0x00000010 ; 7016 specific
SIS900_EECS            = 0x00000008
SIS900_EECLK           = 0x00000004
SIS900_EEDO            = 0x00000002
SIS900_EEDI            = 0x00000001
;SIS900 TX Configuration Register Bits
SIS900_ATP             = 0x10000000 ; Automatic Transmit Padding
SIS900_MLB             = 0x20000000 ; Mac Loopback Enable
SIS900_HBI             = 0x40000000 ; HeartBeat Ignore (Req for full-dup)
SIS900_CSI             = 0x80000000 ; CarrierSenseIgnore (Req for full-du
;SIS900 RX Configuration Register Bits
SIS900_AJAB            = 0x08000000
SIS900_ATX             = 0x10000000 ; Accept Transmit Packets
SIS900_ARP             = 0x40000000 ; accept runt packets (<64bytes)
SIS900_AEP             = 0x80000000 ; accept error packets
;SIS900 Interrupt Reigster Bits
SIS900_WKEVT           = 0x10000000
SIS900_TxPAUSEEND      = 0x08000000
SIS900_TxPAUSE         = 0x04000000
SIS900_TxRCMP          = 0x02000000
SIS900_RxRCMP          = 0x01000000
SIS900_DPERR           = 0x00800000
SIS900_SSERR           = 0x00400000
SIS900_RMABT           = 0x00200000
SIS900_RTABT           = 0x00100000
SIS900_RxSOVR          = 0x00010000
SIS900_HIBERR          = 0x00008000
SIS900_SWINT           = 0x00001000
SIS900_MIBINT          = 0x00000800
SIS900_TxURN           = 0x00000400
SIS900_TxIDLE          = 0x00000200
SIS900_TxERR           = 0x00000100
SIS900_TxDESC          = 0x00000080
SIS900_TxOK            = 0x00000040
SIS900_RxORN           = 0x00000020
SIS900_RxIDLE          = 0x00000010
SIS900_RxEARLY         = 0x00000008
SIS900_RxERR           = 0x00000004
SIS900_RxDESC          = 0x00000002
SIS900_RxOK            = 0x00000001
;SIS900 Interrupt Enable Reigster Bits
SIS900_IE              = 0x00000001
;SIS900 Revision ID
SIS900B_900_REV        = 0x03
SIS630A_900_REV        = 0x80
SIS630E_900_REV        = 0x81
SIS630S_900_REV        = 0x82
SIS630EA1_900_REV      = 0x83
SIS630ET_900_REV       = 0x84
SIS635A_900_REV        = 0x90
SIS900_960_REV         = 0x91
;SIS900 Receive Filter Control Register Bits
SIS900_RFEN            = 0x80000000
SIS900_RFAAB           = 0x40000000
SIS900_RFAAM           = 0x20000000
SIS900_RFAAP           = 0x10000000
SIS900_RFPromiscuous   = 0x70000000
;SIS900 Reveive Filter Data Mask
SIS900_RFDAT           = 0x0000ffff
;SIS900 Eeprom Address
SIS900_EEPROMSignature = 0x00
SIS900_EEPROMVendorID  = 0x02
SIS900_EEPROMDeviceID  = 0x03
SIS900_EEPROMMACAddr   = 0x08
SIS900_EEPROMChecksum  = 0x0b
;The EEPROM commands include the alway-set leading bit.
;SIS900 Eeprom Command
SIS900_EEread          = 0x0180
SIS900_EEwrite         = 0x0140
SIS900_EEerase         = 0x01c0
SIS900_EEwriteEnable   = 0x0130
SIS900_EEwriteDisable  = 0x0100
SIS900_EEeraseAll      = 0x0120
SIS900_EEwriteAll      = 0x0110
SIS900_EEaddrMask      = 0x013f
SIS900_EEcmdShift      = 16
;For SiS962 or SiS963, request the eeprom software access
SIS900_EEREQ           = 0x00000400
SIS900_EEDONE          = 0x00000200
SIS900_EEGNT           = 0x00000100

;General Varibles
SIS900_pci_revision db 0
SIS900_Status       dd 0x03000000

sis900_specific_table:
; dd SIS630A_900_REV, Get_Mac_SIS630A_900_REV, 0
; dd SIS630E_900_REV, Get_Mac_SIS630E_900_REV, 0
  dd SIS630S_900_REV, Get_Mac_SIS635_900_REV, 0
  dd SIS630EA1_900_REV, Get_Mac_SIS635_900_REV, 0
  dd SIS630ET_900_REV, Get_Mac_SIS635_900_REV, 0;SIS630ET_900_REV_SpecialFN
  dd SIS635A_900_REV, Get_Mac_SIS635_900_REV, 0
  dd SIS900_960_REV, SIS960_get_mac_addr, 0
  dd SIS900B_900_REV, SIS900_get_mac_addr, 0
  dd 0, 0, 0, 0 ; end of list

sis900_get_mac_func  dd 0
sis900_special_func  dd 0
sis900_table_entries db 8

ConditionalKLogBegin KLogC, KCONFIG_NET_DRIVER_SIS900_DEBUG

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_probe ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Searches for an ethernet card, enables it and clears the rx buffer
;? If a card was found, it enables the ethernet -> TCPIP link
;-----------------------------------------------------------------------------------------------------------------------
;# TODO: still need to probe mii transcievers
;-----------------------------------------------------------------------------------------------------------------------
        ; Wake Up Chip
        mov     al, 4
        mov     bh, [pci_dev]
        mov     ecx, 0
        mov     ah, [pci_bus]
        mov     bl, 0x40
        call    pci_write_reg
        ; Set some PCI Settings
        call    SIS900_adjust_pci_device
        ; Get Card Revision
        mov     al, 1 ; one byte to read
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, 0x08 ; Revision Register
        call    pci_read_reg
        mov     [SIS900_pci_revision], al ; save the revision for later use
        ; Look up through the sis900_specific_table
        mov     esi, sis900_specific_table

  .probe_loop:
        cmp     dword[esi], 0 ; Check if we reached end of the list
        je      .probe_loop_failed
        cmp     al, [esi] ; Check if revision is OK
        je      .probe_loop_ok
        add     esi, 12 ; Advance to next entry
        jmp     .probe_loop

  .probe_loop_failed:
        jmp     .unsupported
        ; Find Get Mac Function

  .probe_loop_ok:
        mov     eax, [esi + 4] ; Get pointer to "get MAC" function
        mov     [sis900_get_mac_func], eax
        mov     eax, [esi + 8] ; Get pointer to special initialization fn
        mov     [sis900_special_func], eax
        ; Get MAC
        call    [sis900_get_mac_func]
        ; Call special initialization fn if requested
        cmp     [sis900_special_func], 0
        je      .no_special_init
        call    [sis900_special_func]

  .no_special_init:
        ; Set table entries
        mov     al, [SIS900_pci_revision]
        cmp     al, SIS635A_900_REV
        jae     .ent16
        cmp     al, SIS900B_900_REV
        je      .ent16
        jmp     .ent8

  .ent16:
        mov     [sis900_table_entries], 16

  .ent8:
        ; Probe for mii transceiver
        ; TODO!!
        ; Initialize Device
        call    sis900_init
        ret

  .unsupported:
        KLogC   LOG_DEBUG, "Sorry your card is unsupported\n"

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sis900_init ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? resets the ethernet controller chip and various data structures required for sending and receiving packets.
;-----------------------------------------------------------------------------------------------------------------------
;# not done
;-----------------------------------------------------------------------------------------------------------------------
        call    SIS900_reset ; Done
        call    SIS900_init_rxfilter ; Done
        call    SIS900_init_txd ; Done
        call    SIS900_init_rxd ; Done
        call    SIS900_set_rx_mode ; done
        call    SIS900_set_tx_mode
;       call    SIS900_check_mode
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_reset ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? disables interrupts and soft resets the controller chip
;-----------------------------------------------------------------------------------------------------------------------
        ; Disable Interrupts and reset Receive Filter
        mov     ebp, [io_addr] ; base address
        xor     eax, eax ; 0 to initialize
        lea     edx, [ebp + SIS900_ier]
        out     dx, eax ; Write 0 to location
        lea     edx, [ebp + SIS900_imr]
        out     dx, eax ; Write 0 to location
        lea     edx, [ebp + SIS900_rfcr]
        out     dx, eax ; Write 0 to location
        ; Reset Card
        lea     edx, [ebp + SIS900_cr]
        in      eax, dx ; Get current Command Register
        or      eax, SIS900_RESET ; set flags
        or      eax, SIS900_RxRESET
        or      eax, SIS900_TxRESET
        out     dx, eax ; Write new Command Register
        ; Wait Loop
        lea     edx, [ebp + SIS900_isr]
        mov     ecx, [SIS900_Status] ; Status we would like to see from card
        mov     ebx, 2001 ; only loop 1000 times

  .wait:
        dec     ebx ; 1 less loop
        jz      .doneWait_e ; 1000 times yet?
        in      eax, dx ; move interrup status to eax
        and     eax, ecx
        xor     ecx, eax
        jz      .doneWait
        jmp     .wait

  .doneWait_e:
        KLogC   LOG_DEBUG, "Reset Failed\n"

  .doneWait:
        ; Set Configuration Register depending on Card Revision
        lea     edx, [ebp + SIS900_cfg]
        mov     eax, SIS900_PESEL ; Configuration Register Bit
        mov     bl, [SIS900_pci_revision] ; card revision
        mov     cl, SIS635A_900_REV ; Check card revision
        cmp     bl, cl
        je      .revMatch
        mov     cl, SIS900B_900_REV ; Check card revision
        cmp     bl, cl
        je      .revMatch
        out     dx, eax ; no revision match
        jmp     .reset_Complete

  .revMatch:
        ; Revision match
        or      eax, SIS900_RND_CNT ; Configuration Register Bit
        out     dx, eax

  .reset_Complete:
        mov     eax, [pci_data]
        mov     [eth_status], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_init_rxfilter ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? sets receive filter address to our MAC address
;-----------------------------------------------------------------------------------------------------------------------
        ; Get Receive Filter Control Register
        mov     ebp, [io_addr] ; base address
        lea     edx, [ebp + SIS900_rfcr]
        in      eax, dx ; get register
        push    eax
        ; disable packet filtering before setting filter
        mov     eax, SIS900_RFEN ; move receive filter enable flag
        not     eax ; 1s complement
        pop     ebx ; and with our saved register
        and     eax, ebx ; disable receiver
        push    ebx ; save filter for another use
        out     dx, eax ; set receive disabled
        ; load MAC addr to filter data register
        xor     ecx, ecx

  .RXINT_Mac_Write:
        ; high word of eax tells card which mac byte to write
        mov     eax, ecx
        lea     edx, [ebp + SIS900_rfcr]
        shl     eax, 16
        out     dx, eax
        lea     edx, [ebp + SIS900_rfdr]
        mov     ax,  [node_addr + ecx * 2] ; Get Mac ID word
        out     dx, ax ; Send Mac ID
        inc     cl ; send next word
        cmp     cl, 3 ; more to send?
        jne     .RXINT_Mac_Write
        ; enable packet filitering
        pop     eax ; old register value
        lea     edx, [ebp + SIS900_rfcr]
        or      eax, SIS900_RFEN ; enable filtering
        out     dx, eax ; set register
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_init_txd ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? initializes the Tx descriptor
;-----------------------------------------------------------------------------------------------------------------------
        ; initialize TX descriptor
        mov     [txd], 0 ; put link to next descriptor in link field
        mov     [txd + 4], 0 ; clear status field
        mov     [txd + 8], txb - OS_BASE ; save address to buffer ptr field
        ; load Transmit Descriptor Register
        mov     dx, [io_addr] ; base address
        add     dx, SIS900_txdp ; TX Descriptor Pointer
        mov     eax, txd - OS_BASE ; First Descriptor
        out     dx, eax ; move the pointer
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_init_rxd ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? initializes the Rx descriptor ring
;-----------------------------------------------------------------------------------------------------------------------
        xor     ecx, ecx
        mov     [cur_rx], cl ; Set cuurent rx discriptor to 0
        ; init RX descriptors

  .init_rxd_Loop:
        mov     eax, ecx ; current descriptor
        imul    eax, 12
        mov     ebx, ecx ; determine next link descriptor
        inc     ebx
        cmp     ebx, NUM_RX_DESC
        jne     .init_rxd_Loop_0
        xor     ebx, ebx

  .init_rxd_Loop_0:
        imul    ebx, 12
        add     ebx, rxd - OS_BASE
        mov     [rxd + eax], ebx ; save link to next descriptor
        mov     [rxd + eax + 4], RX_BUFF_SZ ; status bits init to buf size
        mov     ebx, ecx ; find where the buf is located
        imul    ebx, RX_BUFF_SZ
        add     ebx, rxb - OS_BASE
        mov     [rxd + eax + 8], ebx ; save buffer pointer
        inc     ecx ; next descriptor
        cmp     ecx, NUM_RX_DESC
        jne     .init_rxd_Loop
        ; load Receive Descriptor Register with address of first descriptor
        mov     dx, [io_addr]
        add     dx, SIS900_rxdp
        mov     eax, rxd - OS_BASE
        out     dx, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_set_tx_mode ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? sets the transmit mode to allow for full duplex
;-----------------------------------------------------------------------------------------------------------------------
;# If you are having problems transmitting packet try changing the Max DMA Burst.
;# Possible settings are as follows:
;#   0x00000000 = 512 bytes
;#   0x00100000 = 4 bytes
;#   0x00200000 = 8 bytes
;#   0x00300000 = 16 bytes
;#   0x00400000 = 32 bytes
;#   0x00500000 = 64 bytes
;#   0x00600000 = 128 bytes
;#   0x00700000 = 256 bytes
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, [io_addr]
        lea     edx, [ebp + SIS900_cr]
        in      eax, dx ; Get current Command Register
        or      eax, SIS900_TxENA ; Enable Receive
        out     dx, eax
        lea     edx, [ebp + SIS900_txcfg] ; Transmit config Register offset
        mov     eax, SIS900_ATP ; allow automatic padding
        or      eax, SIS900_HBI ; allow heartbeat ignore
        or      eax, SIS900_CSI ; allow carrier sense ignore
        or      eax, 0x00600000 ; Max DMA Burst
        or      eax, 0x00000100 ; TX Fill Threshold
        or      eax, 0x00000020 ; TX Drain Threshold
        out     dx, eax
        ret
kendp

SIS900_mc_filter: times 16 dw 0

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_set_rx_mode ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? sets the receive mode to accept all broadcast packets and packets with our MAC address, and reject all multicast
;? packets. Also allows full-duplex
;-----------------------------------------------------------------------------------------------------------------------
;# If you are having problems receiving packet try changing the Max DMA Burst.
;# Possible settings are as follows:
;#   0x00000000 = 512 bytes
;#   0x00100000 = 4 bytes
;#   0x00200000 = 8 bytes
;#   0x00300000 = 16 bytes
;#   0x00400000 = 32 bytes
;#   0x00500000 = 64 bytes
;#   0x00600000 = 128 bytes
;#   0x00700000 = 256 bytes
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, [io_addr]
        ; update Multicast Hash Table in Receive Filter
        mov     ebx, 0xffff
        xor     cl, cl

  .set_rx_mode_Loop:
        mov     eax, ecx
        shl     eax, 1
        mov     [SIS900_mc_filter + eax], bx
        lea     edx, [ebp + SIS900_rfcr] ; Receive Filter Control Reg offset
        mov     eax, 4 ; determine table entry
        add     al, cl
        shl     eax, 16
        out     dx, eax ; tell card which entry to modify
        lea     edx, [ebp + SIS900_rfdr] ; Receive Filter Control Reg offset
        mov     eax, ebx ; entry value
        out     dx, ax ; write value to table in card
        inc     cl ; next entry
        cmp     cl, [sis900_table_entries]
        jl      .set_rx_mode_Loop
        ; Set Receive Filter Control Register
        lea     edx, [ebp + SIS900_rfcr] ; Receive Filter Control Register offset
        mov     eax, SIS900_RFAAB ; accecpt all broadcast packets
        or      eax, SIS900_RFAAM ; accept all multicast packets
        or      eax, SIS900_RFAAP ; Accept all packets
        or      eax, SIS900_RFEN ; enable receiver filter
        out     dx, eax
        ; Enable Receiver
        lea     edx, [ebp + SIS900_cr] ; Command Register offset
        in      eax, dx ; Get current Command Register
        or      eax, SIS900_RxENA ; Enable Receive
        out     dx, eax
        ; Set
        lea     edx, [ebp + SIS900_rxcfg] ; Receive Config Register offset
        mov     eax, SIS900_ATX ; Accept Transmit Packets (Req for full-duplex and PMD Loopback)
        or      eax, 0x00600000 ; Max DMA Burst
        or      eax, 0x00000002 ; RX Drain Threshold, 8X8 bytes or 64bytes
        out     dx, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS960_get_mac_addr ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get MAC address for SiS962 or SiS963 model
;-----------------------------------------------------------------------------------------------------------------------
;> @pci_dev: the sis900 pci device
;> @net_dev: the net device to get address for
;-----------------------------------------------------------------------------------------------------------------------
;< MAC address is read into @net_dev->dev_addr.
;-----------------------------------------------------------------------------------------------------------------------
;# SiS962 or SiS963 model, use EEPROM to store MAC address. And EEPROM is shared by LAN and 1394. When access EEPROM,
;# send EEREQ signal to hardware first and wait for EEGNT. If EEGNT is ON, EEPROM is permitted to be access by LAN,
;# otherwise is not. After MAC address is read from EEPROM, send EEDONE signal to refuse EEPROM access by LAN.
;# The EEPROM map of SiS962 or SiS963 is different to SiS900.
;# The signature field in SiS962 or SiS963 spec is meaningless.
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, [io_addr]
        ; Send Request for eeprom access
        lea     edx, [ebp + SIS900_mear] ; Eeprom access register
        mov     eax, SIS900_EEREQ ; Request access to eeprom
        out     dx, eax ; Send request
        xor     ebx, ebx
        ; Loop 4000 times and if access not granted error out

  .Get_Mac_Wait:
        in      eax, dx ; get eeprom status
        and     eax, SIS900_EEGNT ; see if eeprom access granted flag is set
        jnz     .Got_EEP_Access ; if it is, go access the eeprom
        inc     ebx ; else keep waiting
        cmp     ebx, 4000 ; have we tried 4000 times yet?
        jl      .Get_Mac_Wait ; if not ask again
        xor     eax, eax ; return zero in eax indicating failure

        KLogC   LOG_DEBUG, "Access to EEprom Failed\n"

        jmp     .get_mac_addr_done

        ; EEprom access granted, read MAC from card

  .Got_EEP_Access:
        ; zero based so 3-16 bit reads will take place
        mov     ecx, 2

  .mac_read_loop:
        mov     eax, SIS900_EEPROMMACAddr ; Base Mac Address
        add     eax, ecx ; Current Mac Byte Offset
        push    ecx
        call    sis900_read_eeprom ; try to read 16 bits
        pop     ecx
        mov     [node_addr + ecx * 2], ax ; save 16 bits to the MAC ID varible
        dec     ecx ; one less word to read
        jns     .mac_read_loop ; if more read more
        mov     eax, 1 ; return non-zero indicating success

        KLogC   LOG_DEBUG, "Your SIS96x Mac ID is: %x:%x:%x:%x:%x:%x\n", [node_addr]:2, [node_addr + 1]:2, \
                [node_addr + 2]:2, [node_addr + 3]:2, [node_addr + 4]:2, [node_addr + 5]:2

        ; Tell EEPROM We are Done Accessing It

  .get_mac_addr_done:
        lea      edx, [ebp + SIS900_mear] ; Eeprom access register
        mov      eax, SIS900_EEDONE ; tell eeprom we are done
        out      dx, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_get_mac_addr ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get MAC address for stand alone SiS900 model
;-----------------------------------------------------------------------------------------------------------------------
;> @pci_dev: the sis900 pci device
;> @net_dev: the net device to get address for
;-----------------------------------------------------------------------------------------------------------------------
;< MAC address is read from read_eeprom() into @net_dev->dev_addr.
;-----------------------------------------------------------------------------------------------------------------------
;# Older SiS900 and friends, use EEPROM to store MAC address.
;-----------------------------------------------------------------------------------------------------------------------
        KLogC   LOG_DEBUG, "Attempting to get SIS900 Mac ID\n"

        ; check to see if we have sane EEPROM
        mov     eax, SIS900_EEPROMSignature ; Base Eeprom Signature
        call    sis900_read_eeprom ; try to read 16 bits
        cmp     ax, 0xffff
        je      .Bad_Eeprom
        cmp     ax, 0
        je      .Bad_Eeprom

        ; Read MacID
        ; zero based so 3-16 bit reads will take place
        mov     ecx, 2

  .mac_read_loop:
        mov     eax, SIS900_EEPROMMACAddr ; Base Mac Address
        add     eax, ecx ; Current Mac Byte Offset
        push    ecx
        call    sis900_read_eeprom ; try to read 16 bits
        pop     ecx
        mov     [node_addr + ecx * 2], ax ; save 16 bits to the MAC ID storage
        dec     ecx ; one less word to read
        jns     .mac_read_loop ; if more read more
        mov     eax, 1 ; return non-zero indicating success

        KLogC   LOG_DEBUG, "Your Mac ID is: %x:%x:%x:%x:%x:%x\n", [node_addr]:2, [node_addr + 1]:2, [node_addr + 2]:2, \
                [node_addr + 3]:2, [node_addr + 4]:2, [node_addr + 5]:2

        ret

  .Bad_Eeprom:
        xor     eax, eax

        KLogC    LOG_DEBUG, "Access to EEprom Failed\n"

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc Get_Mac_SIS635_900_REV ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get MAC address for model 635
;-----------------------------------------------------------------------------------------------------------------------
        KLogC   LOG_DEBUG, "Attempting to get SIS900 Mac ID\n"

        mov     ebp, [io_addr]
        lea     edx, [ebp + SIS900_rfcr]
        in      eax, dx
        mov     edi, eax ; EDI=rfcrSave
        lea     edx, [ebp + SIS900_cr]
        or      eax, SIS900_RELOAD
        out     dx, eax
        xor     eax, eax
        out     dx, eax
        ; Disable packet filtering before setting filter
        lea     edx, [ebp + SIS900_rfcr]
        mov     eax, edi
        and     edi, not SIS900_RFEN
        out     dx, eax
        ; Load MAC to filter data register
        xor     ecx, ecx
        mov     esi, node_addr

  .get_mac_loop:
        lea     edx, [ebp + SIS900_rfcr]
        mov     eax, ecx
        shl     eax, SIS900_RFADDR_shift
        out     dx, eax
        lea     edx, [ebp + SIS900_rfdr]
        in      eax, dx
        mov     [esi], ax
        add     esi, 2
        inc     ecx
        cmp     ecx, 3
        jne     .get_mac_loop
        ; Enable packet filtering
;       lea     edx, [ebp + SIS900_rfcr]
;       mov     eax, edi
;       or      eax, SIS900_RFEN
;       out     dx, eax

        KLogC   LOG_DEBUG, "Your Mac ID is: %x:%x:%x:%x:%x:%x\n", [node_addr]:2, [node_addr + 1]:2, [node_addr + 2]:2, \
                [node_addr + 3]:2, [node_addr + 4]:2, [node_addr + 5]:2

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sis900_read_eeprom ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? reads and returns a given location from EEPROM
;-----------------------------------------------------------------------------------------------------------------------
;> eax = requested EEPROM location
;-----------------------------------------------------------------------------------------------------------------------
;< eax = contents of requested EEPROM location
;-----------------------------------------------------------------------------------------------------------------------
;# Read Serial EEPROM through EEPROM Access Register
;# Note that location is in word (16 bits) unit
;-----------------------------------------------------------------------------------------------------------------------
        push    esi
        push    edx
        push    ecx
        push    ebx
        mov     ebp, [io_addr]
        mov     ebx, eax ; location of Mac byte to read
        or      ebx, SIS900_EEread
        lea     edx, [ebp + SIS900_mear] ; Eeprom access register
        xor     eax, eax ; start send
        out     dx, eax
        call    SIS900_Eeprom_Delay_1
        mov     eax, SIS900_EECLK
        out     dx, eax
        call    SIS900_Eeprom_Delay_1
        ; Shift the read command (9) bits out
        mov     cl, 8

  .Send:
        mov     eax, 1
        shl     eax, cl
        and     eax, ebx
        jz      .8
        mov     eax, 9
        jmp     .9

  .8:
        mov     eax, 8

  .9:
        out     dx, eax
        call    SIS900_Eeprom_Delay_1
        or      eax, SIS900_EECLK
        out     dx, eax
        call    SIS900_Eeprom_Delay_1
        cmp     cl, 0
        je      .Send_Done
        dec     cl
        jmp     .Send

  .Send_Done:
        mov     eax, SIS900_EECS
        out     dx, eax
        call    SIS900_Eeprom_Delay_1
        ; Read 16-bits of data in
        mov     cx, 16 ; 16 bits to read

  .Send2:
        mov     eax, SIS900_EECS
        out     dx, eax
        call    SIS900_Eeprom_Delay_1
        or      eax, SIS900_EECLK
        out     dx, eax
        call    SIS900_Eeprom_Delay_1
        in      eax, dx
        shl     ebx, 1
        and     eax, SIS900_EEDO
        jz      .0
        or      ebx, 1

  .0:
        dec     cx
        jnz     .Send2
        ; Terminate the EEPROM access
        xor     eax, eax
        out     dx, eax
        call    SIS900_Eeprom_Delay_1
        mov     eax, SIS900_EECLK
        out     dx, eax
        mov     eax, ebx
        and     eax, 0x0000ffff ; return only 16 bits
        pop     ebx
        pop     ecx
        pop     edx
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_Eeprom_Delay_1 ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        in      eax, dx
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_poll ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? polls card to see if there is a packet waiting
;-----------------------------------------------------------------------------------------------------------------------
;# Currently only supports one descriptor per packet, if packet is fragmented
;# between multiple descriptors you will lose part of the packet
;-----------------------------------------------------------------------------------------------------------------------
        ; Get Status
        xor     eax, eax ; get RX_Status
        mov     [eth_rx_data_len], ax
        mov     al, [cur_rx] ; find current discriptor
        imul    eax, 12
        mov     ecx, [rxd + eax + 4] ; get receive status
        ; Check Status
        mov     ebx, ecx ; move status
        ; Check RX_Status to see if packet is waiting
        and     ebx, 0x80000000
        jnz     .IS_packet
        ret
        ; There is a packet waiting check it for errors

  .IS_packet:
        mov     ebx, ecx ; move status
        and     ebx, 0x67c0000 ; see if there are any errors
        jnz     .Error_Status
        ; Check size of packet
        and     ecx, SIS900_DSIZE ; get packet size minus CRC
        cmp     cx, SIS900_CRC_SIZE
        ; make sure packet contains data
        jle     .Error_Size
        ; Copy Good Packet to receive buffer
        sub     cx, SIS900_CRC_SIZE ; dont want crc
        mov     [eth_rx_data_len], cx ; save size of packet
        ; Continue copying packet
        push    ecx
        ; first copy dword-wise, divide size by 4
        shr     ecx, 2
        mov     esi, [rxd + eax + 8] ; set source
        add     esi, OS_BASE ; get linear address
        mov     edi, Ether_buffer ; set destination
        rep
        movsd   ; copy the dwords
        pop     ecx
        and     ecx, 3
        rep
        movsb

        KLogC   LOG_DEBUG, "Good Packet Waiting\n"

        jmp     .Cnt

  .Error_Status:
        ; Error occured let user know through debug window

        KLogC   LOG_DEBUG, "Bad Packet Waiting: Status\n"

        jmp     .Cnt

  .Error_Size:

        KLogC   LOG_DEBUG, "Bad Packet Waiting: Size\n"

        ; Increment to next available descriptor
  .Cnt:
        ;Reset status, allow ethernet card access to descriptor
        mov     ecx, RX_BUFF_SZ
        mov     [rxd + eax + 4], ecx
        inc     [cur_rx] ; get next descriptor
        and     [cur_rx], 3 ; only 4 descriptors 0-3
        ; Enable Receiver
        mov     ebp, [io_addr] ; Base Address
        lea     edx, [ebp + SIS900_cr] ; Command Register offset
        in      eax, dx ; Get current Command Register
        or      eax, SIS900_RxENA ; Enable Receive
        out     dx, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_transmit ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Transmits a packet of data via the ethernet card
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to 48 bit destination address
;> bx = type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;-----------------------------------------------------------------------------------------------------------------------
;# only one transmit descriptor is used
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, [io_addr] ; Base Address
        ; Stop the transmitter
        lea     edx, [ebp + SIS900_cr] ; Command Register offset
        in      eax, dx ; Get current Command Register
        or      eax, SIS900_TxDIS ; Disable Transmitter
        out     dx, eax
        ; load Transmit Descriptor Register
        lea     edx, [ebp + SIS900_txdp]
        mov     eax, txd - OS_BASE
        out     dx, eax
        ; copy packet to descriptor
        push    esi
        mov     esi, edi ; copy destination addess
        mov     edi, txb
        movsd
        movsw
        mov     esi, node_addr ; copy my mac address
        movsd
        movsw
        mov     [edi], bx ; copy packet type
        add     edi, 2
        pop     esi ; restore pointer to source of packet
        push    ecx ; save packet size
        shr     ecx, 2 ; divide by 4, size in bytes send in dwords
        rep
        movsd   ; copy data to decriptor
        pop     ecx ; restore packet size
        push    ecx ; save packet size
        and     ecx, 3 ; last three bytes if not a multiple of 4
        rep
        movsb
        ; set length tag
        pop     ecx ; restore packet size
        add     ecx, SIS900_ETH_HLEN ; add header to length
        and     ecx, SIS900_DSIZE
        ; pad to minimum packet size // not needed
;       cmp     ecx, SIS900_ETH_ZLEN
;       jge     .Size_Ok
;       push    ecx
;       mov     ebx, SIS900_ETH_ZLEN
;       sub     ebx, ecx
;       mov     ecx, ebx
;       rep
;       movsb
;       pop     ecx

  .Size_Ok:
        mov     [txd + 4], 0x80000000 ; card owns descriptor
        or      [txd + 4], ecx ; set size of packet

        KLogC   LOG_DEBUG, "Transmitting Packet\n"

        ; restart the transmitter
        lea     edx, [ebp + SIS900_cr]
        in      eax, dx ; Get current Command Register
        or      eax, SIS900_TxENA ; Enable Transmitter
        out     dx, eax
        ; make sure packet transmitted successfully
;       mov     esi, 10
;       call    delay_ms
        mov     eax, [txd + 4]
        and     eax, 0x6200000
        jz      .OK
        ; Tell user there was an error through debug window

        KLogC   LOG_DEBUG, "Transmitting Packet Error\n"

  .OK:
        ; Disable interrupts by clearing the interrupt mask
        lea     edx, [ebp + SIS900_imr] ; Interupt Mask Register
        xor     eax, eax
        out     dx, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc SIS900_adjust_pci_device ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Set device to be a busmaster in case BIOS neglected to do so.
;? Also adjust PCI latency timer to a reasonable value, 64.
;-----------------------------------------------------------------------------------------------------------------------
        ; Get current setting
        mov     al, 2 ; read a word
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, 0x04 ; from command Register
        call    pci_read_reg
        ; see if its already set as bus master
        mov     bx, ax
        and     bx, 5
        cmp     bx, 5
        je      .Latency
        ; Make card a bus master
        mov     cx, ax ; value to write
        mov     bh, [pci_dev]
        mov     al, 2 ; write a word
        or      cx, 5
        mov     ah, [pci_bus]
        mov     bl, 0x04 ; to command register
        call    pci_write_reg
        ; Check latency setting

  .Latency:
        ; Get current latency setting
        mov     al, 1 ; read a byte
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, 0x0d ; from Lantency Timer Register
        call    pci_read_reg
        ; see if its aat least 64 clocks
        cmp     ax, 64
        jge     .Done
        ; Set latency to 32 clocks
        mov     cx, 64 ; value to write
        mov     bh, [pci_dev]
        mov     al, 1 ; write a byte
        mov     ah, [pci_bus]
        mov     bl, 0x0d ; to Lantency Timer Register
        call    pci_write_reg
        ; Check latency setting

  .Done:
        ret
kendp

ConditionalKLogEnd klogc
