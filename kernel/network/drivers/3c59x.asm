;;======================================================================================================================
;;///// 3c59x.asm //////////////////////////////////////////////////////////////////////////////////// BSD License /////
;;======================================================================================================================
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
;; (c) 2004 Endre Kozma <endre.kozma@axelero.hu>
;;======================================================================================================================
;; Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
;; following conditions are met:
;;
;; 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
;;    disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
;;    following disclaimer in the documentation and/or other materials provided with the distribution.
;; 3. The name of the author may not be used to endorse or promote products derived from this software without specific
;;    prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
;; THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
;; AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
;; NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
;; OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;======================================================================================================================
;# References:
;# * www.3Com.com - data sheets
;# * DP83840A.pdf - ethernet physical layer
;# * 3c59x.c - linux driver
;;======================================================================================================================

; forcing full duplex mode makes sense at some cards and link types
E3C59X_FORCE_FD = 1

macro VirtToDma _reg
{
        sub     _reg, OS_BASE
}

macro DmaToVirt _reg
{
        add     _reg, OS_BASE
}

macro ZeroToVirt reg
{
}

macro VirtToZero _reg
{
}

macro ZeroToDma _reg
{
        sub     _reg, OS_BASE
}

macro DmaToZero _reg
{
        add     _reg, OS_BASE
}

macro StringTable _name, [_string]
{
  common
    label _name dword
  forward
    local label
    dd label
  forward
    label db _string, 0
}

; Ethernet frame symbols
ETH_ALEN                            = 6
ETH_HLEN                            = 2 * ETH_ALEN + 2
ETH_ZLEN                            = 60 ; 60 + 4bytes auto payload for mininmum 64bytes frame length

; PCI programming                   =
PCI_REG_COMMAND                     = 0x04 ; command register
PCI_REG_STATUS                      = 0x06 ; status register
PCI_REG_LATENCY                     = 0x0d ; latency timer register
PCI_REG_CAP_PTR                     = 0x34 ; capabilities pointer
PCI_REG_CAPABILITY_ID               = 0x00 ; capapility ID in pm register block
PCI_REG_PM_STATUS                   = 0x04 ; power management status register
PCI_REG_PM_CTRL                     = 0x04 ; power management control register
PCI_BIT_PIO                         = 0 ; bit0: io space control
PCI_BIT_MMIO                        = 1 ; bit1: memory space control
PCI_BIT_MASTER                      = 2 ; bit2: device acts as a PCI master

; Registers                         =
E3C59X_REG_POWER_MGMT_CTRL          = 0x7c
E3C59X_REG_UP_LIST_PTR              = 0x38
E3C59X_REG_UP_PKT_STATUS            = 0x30
E3C59X_REG_TX_FREE_THRESH           = 0x2f
E3C59X_REG_DN_LIST_PTR              = 0x24
E3C59X_REG_DMA_CTRL                 = 0x20
E3C59X_REG_TX_STATUS                = 0x1b
E3C59X_REG_RX_STATUS                = 0x18
E3C59X_REG_TX_DATA                  = 0x10

; Common window registers           =
E3C59X_REG_INT_STATUS               = 0x0e
E3C59X_REG_COMMAND                  = 0x0e

; Register window 7                 =
E3C59X_REG_MASTER_STATUS            = 0x0c
E3C59X_REG_POWER_MGMT_EVENT         = 0x0c
E3C59X_REG_MASTER_LEN               = 0x06
E3C59X_REG_VLAN_ETHER_TYPE          = 0x04
E3C59X_REG_VLAN_MASK                = 0x00
E3C59X_REG_MASTER_ADDRESS           = 0x00

; Register window 6                 =
E3C59X_REG_BYTES_XMITTED_OK         = 0x0c
E3C59X_REG_BYTES_RCVD_OK            = 0x0a
E3C59X_REG_UPPER_FRAMES_OK          = 0x09
E3C59X_REG_FRAMES_DEFERRED          = 0x08
E3C59X_REG_FRAMES_RCVD_OK           = 0x07
E3C59X_REG_FRAMES_XMITTED_OK        = 0x06
E3C59X_REG_RX_OVERRUNS              = 0x05
E3C59X_REG_LATE_COLLISIONS          = 0x04
E3C59X_REG_SINGLE_COLLISIONS        = 0x03
E3C59X_REG_MULTIPLE_COLLISIONS      = 0x02
E3C59X_REG_SQE_ERRORS               = 0x01
E3C59X_REG_CARRIER_LOST             = 0x00

; Register window 5                 =
E3C59X_REG_INDICATION_ENABLE        = 0x0c
E3C59X_REG_INTERRUPT_ENABLE         = 0x0a
E3C59X_REG_TX_RECLAIM_THRESH        = 0x09
E3C59X_REG_RX_FILTER                = 0x08
E3C59X_REG_RX_EARLY_THRESH          = 0x06
E3C59X_REG_TX_START_THRESH          = 0x00

; Register window 4                 =
E3C59X_REG_UPPER_BYTES_OK           = 0x0e
E3C59X_REG_BAD_SSD                  = 0x0c
E3C59X_REG_MEDIA_STATUS             = 0x0a
E3C59X_REG_PHYSICAL_MGMT            = 0x08
E3C59X_REG_NETWORK_DIAGNOSTIC       = 0x06
E3C59X_REG_FIFO_DIAGNOSTIC          = 0x04
E3C59X_REG_VCO_DIAGNOSTIC           = 0x02 ; may not supported

; Bits in register window 4         =
E3C59X_BIT_AUTOSELECT               = 24

; Register window 3                 =
E3C59X_REG_TX_FREE                  = 0x0c
E3C59X_REG_RX_FREE                  = 0x0a
E3C59X_REG_MEDIA_OPTIONS            = 0x08
E3C59X_REG_MAC_CONTROL              = 0x06
E3C59X_REG_MAX_PKT_SIZE             = 0x04
E3C59X_REG_INTERNAL_CONFIG          = 0x00

; Register window 2                 =
E3C59X_REG_RESET_OPTIONS            = 0x0c
E3C59X_REG_STATION_MASK_HI          = 0x0a
E3C59X_REG_STATION_MASK_MID         = 0x08
E3C59X_REG_STATION_MASK_LO          = 0x06
E3C59X_REG_STATION_ADDRESS_HI       = 0x04
E3C59X_REG_STATION_ADDRESS_MID      = 0x02
E3C59X_REG_STATION_ADDRESS_LO       = 0x00

; Register window 1                 =
E3C59X_REG_TRIGGER_BITS             = 0x0c
E3C59X_REG_SOS_BITS                 = 0x0a
E3C59X_REG_WAKE_ON_TIMER            = 0x08
E3C59X_REG_SMB_RXBYTES              = 0x07
E3C59X_REG_SMB_DIAG                 = 0x05
E3C59X_REG_SMB_ARB                  = 0x04
E3C59X_REG_SMB_STATUS               = 0x02
E3C59X_REG_SMB_ADDRESS              = 0x01
E3C59X_REG_SMB_FIFO_DATA            = 0x00

; Register window 0                 =
E3C59X_REG_EEPROM_DATA              = 0x0c
E3C59X_REG_EEPROM_COMMAND           = 0x0a
E3C59X_REG_BIOS_ROM_DATA            = 0x08
E3C59X_REG_BIOS_ROM_ADDR            = 0x04

; Physical management bits          =
E3C59X_BIT_MGMT_DIR                 = 2 ; drive with the data written in mgmtData
E3C59X_BIT_MGMT_DATA                = 1 ; MII management data bit
E3C59X_BIT_MGMT_CLK                 = 0 ; MII management clock

; MII commands                      =
E3C59X_MII_CMD_MASK                 = 1111b shl 10
E3C59X_MII_CMD_READ                 = 0110b shl 10
E3C59X_MII_CMD_WRITE                = 0101b shl 10

; MII registers                     =
E3C59X_REG_MII_BMCR                 = 0 ; basic mode control register
E3C59X_REG_MII_BMSR                 = 1 ; basic mode status register
E3C59X_REG_MII_ANAR                 = 4 ; auto negotiation advertisement register
E3C59X_REG_MII_ANLPAR               = 5 ; auto negotiation link partner ability register
E3C59X_REG_MII_ANER                 = 6 ; auto negotiation expansion register

; MII bits                          =
E3C59X_BIT_MII_AUTONEG_COMPLETE     = 5 ; auto-negotiation complete
E3C59X_BIT_MII_PREAMBLE_SUPPRESSION = 6

; eeprom bits and commands          =
E3C59X_EEPROM_CMD_READ              = 0x80
E3C59X_EEPROM_BIT_BUSY              = 15

; eeprom registers                  =
E3C59X_EEPROM_REG_OEM_NODE_ADDR     = 0x0a
E3C59X_EEPROM_REG_CAPABILITIES      = 0x10

; Commands for command register     =
E3C59X_SELECT_REGISTER_WINDOW       = 1 shl 11

IS_VORTEX           = 0x0001
IS_BOOMERANG        = 0x0002
IS_CYCLONE          = 0x0004
IS_TORNADO          = 0x0008
EEPROM_8BIT         = 0x0010
HAS_PWR_CTRL        = 0x0020
HAS_MII             = 0x0040
HAS_NWAY            = 0x0080
HAS_CB_FNS          = 0x0100
INVERT_MII_PWR      = 0x0200
INVERT_LED_PWR      = 0x0400
MAX_COLLISION_RESET = 0x0800
EEPROM_OFFSET       = 0x1000
HAS_HWCKSM          = 0x2000
EXTRA_PREAMBLE      = 0x4000

iglobal
  net.3c59x.vftbl dd \
    e3c59x_probe, \
    e3c59x_reset, \
    e3c59x_poll, \
    e3c59x_transmit, \
    0

  e3c59x_hw_versions:
    dw 0x5900, IS_VORTEX ; 3c590 Vortex 10Mbps
    dw 0x5920, IS_VORTEX ; 3c592 EISA 10Mbps Demon/Vortex
    dw 0x5970, IS_VORTEX ; 3c597 EISA Fast Demon/Vortex
    dw 0x5950, IS_VORTEX ; 3c595 Vortex 100baseTx
    dw 0x5951, IS_VORTEX ; 3c595 Vortex 100baseT4
    dw 0x5952, IS_VORTEX ; 3c595 Vortex 100base-MII
    dw 0x9000, IS_BOOMERANG ; 3c900 Boomerang 10baseT
    dw 0x9001, IS_BOOMERANG ; 3c900 Boomerang 10Mbps Combo
    dw 0x9004, IS_CYCLONE or HAS_NWAY or HAS_HWCKSM ; 3c900 Cyclone 10Mbps TPO
    dw 0x9005, IS_CYCLONE or HAS_HWCKSM ; 3c900 Cyclone 10Mbps Combo
    dw 0x9006, IS_CYCLONE or HAS_HWCKSM ; 3c900 Cyclone 10Mbps TPC
    dw 0x900a, IS_CYCLONE or HAS_HWCKSM ; 3c900B-FL Cyclone 10base-FL
    dw 0x9050, IS_BOOMERANG or HAS_MII ; 3c905 Boomerang 100baseTx
    dw 0x9051, IS_BOOMERANG or HAS_MII ; 3c905 Boomerang 100baseT4
    dw 0x9055, IS_CYCLONE or HAS_NWAY or HAS_HWCKSM or EXTRA_PREAMBLE ; 3c905B Cyclone 100baseTx
    dw 0x9058, IS_CYCLONE or HAS_NWAY or HAS_HWCKSM ; 3c905B Cyclone 10/100/BNC
    dw 0x905a, IS_CYCLONE or HAS_HWCKSM ; 3c905B-FX Cyclone 100baseFx
    dw 0x9200, IS_TORNADO or HAS_NWAY or HAS_HWCKSM ; 3c905C Tornado
    dw 0x9800, IS_CYCLONE or HAS_NWAY or HAS_HWCKSM ; 3c980 Cyclone
    dw 0x9805, IS_TORNADO or HAS_NWAY or HAS_HWCKSM ; 3c982 Dual Port Server Cyclone
    dw 0x7646, IS_CYCLONE or HAS_NWAY or HAS_HWCKSM ; 3cSOHO100-TX Hurricane
    dw 0x5055, IS_CYCLONE or EEPROM_8BIT or HAS_HWCKSM ; 3c555 Laptop Hurricane
    dw 0x6055, IS_TORNADO or HAS_NWAY or EEPROM_8BIT or HAS_CB_FNS or INVERT_MII_PWR or HAS_HWCKSM ; 3c556 Laptop Tornado
    dw 0x6056, IS_TORNADO or HAS_NWAY or EEPROM_OFFSET or HAS_CB_FNS or INVERT_MII_PWR or HAS_HWCKSM ; 3c556B Laptop Hurricane
    dw 0x5b57, IS_BOOMERANG or HAS_MII or EEPROM_8BIT ; 3c575 [Megahertz] 10/100 LAN CardBus
    dw 0x5057, IS_BOOMERANG or HAS_MII or EEPROM_8BIT ; 3c575 Boomerang CardBus
    dw 0x5157, IS_CYCLONE or HAS_NWAY or HAS_CB_FNS or EEPROM_8BIT or INVERT_LED_PWR or HAS_HWCKSM ; 3CCFE575BT Cyclone CardBus
    dw 0x5257, IS_TORNADO or HAS_NWAY or HAS_CB_FNS or EEPROM_8BIT or INVERT_MII_PWR or MAX_COLLISION_RESET or HAS_HWCKSM ; 3CCFE575CT Tornado CardBus
    dw 0x6560, IS_CYCLONE or HAS_NWAY or HAS_CB_FNS or EEPROM_8BIT or INVERT_MII_PWR or INVERT_LED_PWR or HAS_HWCKSM ; 3CCFE656 Cyclone CardBus
    dw 0x6562, IS_CYCLONE or HAS_NWAY or HAS_CB_FNS or EEPROM_8BIT or INVERT_MII_PWR or INVERT_LED_PWR or HAS_HWCKSM ; 3CCFEM656B Cyclone+Winmodem CardBus
    dw 0x6564, IS_TORNADO or HAS_NWAY or HAS_CB_FNS or EEPROM_8BIT or INVERT_MII_PWR or MAX_COLLISION_RESET or HAS_HWCKSM ; 3CXFEM656C Tornado+Winmodem CardBus
    dw 0x4500, IS_TORNADO or HAS_NWAY or HAS_HWCKSM ; 3c450 HomePNA Tornado
    dw 0x9201, IS_TORNADO or HAS_NWAY or HAS_HWCKSM ; 3c920 Tornado
    dw 0x1201, IS_TORNADO or HAS_HWCKSM or HAS_NWAY ; 3c982 Hydra Dual Port A
    dw 0x1202, IS_TORNADO or HAS_HWCKSM or HAS_NWAY ; 3c982 Hydra Dual Port B
    dw 0x9056, IS_CYCLONE or HAS_NWAY or HAS_HWCKSM or EXTRA_PREAMBLE ; 3c905B-T4
    dw 0x9210, IS_TORNADO or HAS_NWAY or HAS_HWCKSM ; 3c920B-EMB-WNM Tornado
  E3C59X_HW_VERSIONS_SIZE= $ - e3c59x_hw_versions
endg

; RX/TX buffers sizes
E3C59X_MAX_ETH_PKT_SIZE    = 1536 ; max packet size
E3C59X_NUM_RX_DESC         = 4 ; a power of 2 number
E3C59X_NUM_TX_DESC         = 4 ; a power of 2 number
E3C59X_RX_BUFFER_SIZE      = E3C59X_MAX_ETH_FRAME_SIZE * E3C59X_NUM_RX_DESC
E3C59X_TX_BUFFER_SIZE      = E3C59X_MAX_ETH_FRAME_SIZE * E3C59X_NUM_TX_DESC
; Download Packet Descriptor
E3C59X_DPD_DN_NEXT_PTR     = 0
E3C59X_DPD_FRAME_START_HDR = 4
E3C59X_DPD_DN_FRAG_ADDR    = 8 ; for packet data
E3C59X_DPD_DN_FRAG_LEN     = 12 ; for packet data
E3C59X_DPD_SIZE            = 16 ; a power of 2 number
; Upload Packet Descriptor
E3C59X_UPD_UP_NEXT_PTR     = 0
E3C59X_UPD_PKT_STATUS      = 4
E3C59X_UPD_UP_FRAG_ADDR    = 8 ; for packet data
E3C59X_UPD_UP_FRAG_LEN     = 12 ; for packet data
E3C59X_UPD_SIZE            = 16

; RX/TX buffers
if defined E3C59X_LINUX

E3C59X_MAX_ETH_FRAME_SIZE  = 160 ; size of ethernet frame + bytes alignment
e3c59x_rx_buff             = 0

else

E3C59X_MAX_ETH_FRAME_SIZE  = 1520 ; size of ethernet frame + bytes alignment
e3c59x_rx_buff             = eth_data_start

end if

e3c59x_tx_buff             = e3c59x_rx_buff + E3C59X_RX_BUFFER_SIZE
e3c59x_dpd_buff            = e3c59x_tx_buff + E3C59X_TX_BUFFER_SIZE
e3c59x_upd_buff            = e3c59x_dpd_buff + E3C59X_DPD_SIZE * E3C59X_NUM_TX_DESC

uglobal
  e3c59x_curr_upd:          dd 0
  e3c59x_prev_dpd:          dd 0
  e3c59x_prev_tx_frame:     dd 0
  e3c59x_transmit_function: dd 0
  e3c59x_receive_function:  dd 0
endg

iglobal
  e3c59x_ver_id: db 17
endg

uglobal
  e3c59x_full_bus_master:      db 0
  e3c59x_has_hwcksm:           db 0
  e3c59x_preamble:             db 0
  e3c59x_dn_list_ptr_cleared:  db 0
  e3c59x_self_directed_packet: rb 6
endg

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

e3c59x_boomerang_str: db "boomerang", 0
e3c59x_vortex_str:    db "vortex", 0
e3c59x_link_type:     dd 0

StringTable e3c59x_link_str, \
  "No valid link type detected", \
  "10BASE-T half duplex", \
  "10BASE-T full-duplex", \
  "100BASE-TX half duplex", \
  "100BASE-TX full duplex", \
  "100BASE-T4", \
  "100BASE-FX", \
  "10Mbps AUI", \
  "10Mbps COAX (BNC)", \
  "miiDevice - not supported"

StringTable e3c59x_hw_str, \
  "3c590 Vortex 10Mbps", \
  "3c592 EISA 10Mbps Demon/Vortex", \
  "3c597 EISA Fast Demon/Vortex", \
  "3c595 Vortex 100baseTx", \
  "3c595 Vortex 100baseT4", \
  "3c595 Vortex 100base-MII", \
  "3c900 Boomerang 10baseT", \
  "3c900 Boomerang 10Mbps Combo", \
  "3c900 Cyclone 10Mbps TPO", \
  "3c900 Cyclone 10Mbps Combo", \
  "3c900 Cyclone 10Mbps TPC", \
  "3c900B-FL Cyclone 10base-FL", \
  "3c905 Boomerang 100baseTx", \
  "3c905 Boomerang 100baseT4", \
  "3c905B Cyclone 100baseTx", \
  "3c905B Cyclone 10/100/BNC", \
  "3c905B-FX Cyclone 100baseFx", \
  "3c905C Tornado", \
  "3c980 Cyclone", \
  "3c982 Dual Port Server Cyclone", \
  "3cSOHO100-TX Hurricane", \
  "3c555 Laptop Hurricane", \
  "3c556 Laptop Tornado", \
  "3c556B Laptop Hurricane", \
  "3c575 [Megahertz] 10/100 LAN CardBus", \
  "3c575 Boomerang CardBus", \
  "3CCFE575BT Cyclone CardBus", \
  "3CCFE575CT Tornado CardBus", \
  "3CCFE656 Cyclone CardBus", \
  "3CCFEM656B Cyclone+Winmodem CardBus", \
  "3CXFEM656C Tornado+Winmodem CardBus", \
  "3c450 HomePNA Tornado", \
  "3c920 Tornado", \
  "3c982 Hydra Dual Port A", \
  "3c982 Hydra Dual Port B", \
  "3c905B-T4", \
  "3c920B-EMB-WNM Tornado"

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_debug ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? prints debug info to the debug board
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        pushad

        ; print device type
        movzx   ecx, byte[e3c59x_ver_id]
        mov     esi, e3c59x_boomerang_str
        cmp     dword[e3c59x_transmit_function], e3c59x_boomerang_transmit
        jz      @f
        mov     esi, e3c59x_vortex_str

    @@: KLog    LOG_DEBUG, "Detected hardware type: %s (%s)\n", [e3c59x_hw_str + ecx * 4], esi

        ; print device/vendor
        KLog    LOG_DEBUG, "Device ID: 0x%x\n", [pci_data + 2]:4
        KLog    LOG_DEBUG, "Vendor ID: 0x%x\n", [pci_data]:4

        ; print io address
        KLog    LOG_DEBUG, "IO address: 0x%x\n", [io_addr]:4

        ; print MAC address
        KLog    LOG_DEBUG, "MAC address: %x:%x:%x:%x:%x:%x\n", [node_addr]:2, [node_addr + 1]:2, [node_addr + 2]:2, \
                [node_addr + 3]:2, [node_addr + 4]:2, [node_addr + 5]:2

        ; print link type
        xor     eax, eax
        bsr     ax, word[e3c59x_link_type]
        jz      @f
        sub     ax, 4

    @@: KLog    LOG_DEBUG, "Established link type: %s\n", [e3c59x_link_str + eax * 4]

        popad
        ret
kendp

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_try_link_detect ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? checks if link exists
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0, no link detected
;< al = 1, link detected
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        ; download self-directed packet
        mov     edi, node_addr
        mov     bx, 0x0608 ; packet type
        mov     esi, e3c59x_self_directed_packet
        mov     ecx, 6 ; 6 + 6 + 2 + 6 = 20 bytes
        call    dword[e3c59x_transmit_function]
        ; switch to register window 5
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 5
        out     dx, ax
        ; program RxFilter for promiscuous operation
        mov     ax, 10000b shl 11
        lea     edx, [ebp + E3C59X_REG_RX_FILTER]
        in      al, dx
        or      al, 1111b
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        out     dx, ax
        ; switch to register window 4
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 4
        out     dx, ax
        ; check loop
        xor     ebx, ebx
        mov     ecx, 0xffff ; 65535 tries

  .loop:
        push    ecx ebx
        call    dword[e3c59x_receive_function]
        pop     ebx ecx
        test    al, al
        jnz     .finish

  .no_packet_received:
        ; switch to register window 4
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 4
        out     dx, ax
        ; read linkbeatdetect
        lea     edx, [ebp + E3C59X_REG_MEDIA_STATUS]
        in      ax, dx
        test    ah, 1000b ; test linkBeatDetect
        jnz     .link_detected
        xor     al, al
        jmp     .finish

  .link_detected:
        ; test carrierSense
        test    al, 100000b
        jz      .no_carrier_sense
        inc     ebx

  .no_carrier_sense:
        dec     ecx
        jns     .loop
        ; assume the link is good if 0 < ebx < 25 %
        test    ebx, ebx
        setnz   al
        jz      .finish
        cmp     ebx, 16384 ; 25%
        setb    al

  .finish:

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        test    al, al
        jz      @f
        or      byte[e3c59x_link_type + 1], 100b

    @@:

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_try_phy ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? checks the auto-negotiation function in the PHY at PHY index. It can also be extended to include link detection for
;? non-IEEE 802.3u auto-negotiation devices, for instance the BCM5000.
;-----------------------------------------------------------------------------------------------------------------------
;> ah = PHY index
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0, link is auto-negotiated
;< al = 1, no link is auto-negotiated
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, esi
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, E3C59X_REG_MII_BMCR
        push    eax
        call    e3c59x_mdio_read ; returns with window #4
        or      ah, 0x80 ; software reset
        mov     ebx, eax
        pop     eax
        push    eax
        call    e3c59x_mdio_write ; returns with window #4
        ; wait for reset to complete
        mov     esi, 2000 ; 2000ms = 2s
        call    delay_ms
        pop     eax
        push    eax
        call    e3c59x_mdio_read ; returns with window #4
        test    ah, 0x80
        jnz     .fail_finish
        pop     eax
        push    eax
        ; wait for a while after reset
        mov     esi, 20 ; 20ms
        call    delay_ms
        pop     eax
        push    eax
        mov     al, E3C59X_REG_MII_BMSR
        call    e3c59x_mdio_read ; returns with window #4
        test    al, 1 ; extended capability supported?
        jz      .no_ext_cap
        ; auto-neg capable?
        test    al, 1000b
        jz      .fail_finish ; not auto-negotiation capable
        ; auto-neg complete?
        test    al, 100000b
        jnz     .auto_neg_ok
        ; restart auto-negotiation
        pop     eax
        push    eax
        mov     al, E3C59X_REG_MII_ANAR
        push    eax
        call    e3c59x_mdio_read ; returns with window #4
        or      ax, 1111b shl 5 ; advertise only 10base-T and 100base-TX
        mov     ebx, eax
        pop     eax
        call    e3c59x_mdio_write ; returns with window #4
        pop     eax
        push    eax
        call    e3c59x_mdio_read ; returns with window #4
        mov     ebx, eax
        or      bh, 10010b ; restart auto-negotiation
        pop     eax
        push    eax
        call    e3c59x_mdio_write ; returns with window #4
        mov     esi, 4000 ; 4000ms = 4 seconds
        call    delay_ms
        pop     eax
        push    eax
        mov     al, E3C59X_REG_MII_BMSR
        call    e3c59x_mdio_read ; returns with window #4
        test    al, 100000b ; auto-neg complete?
        jnz     .auto_neg_ok
        jmp     .fail_finish

  .auto_neg_ok:
        ; compare advertisement and link partner ability registers
        pop     eax
        push    eax
        mov     al, E3C59X_REG_MII_ANAR
        call    e3c59x_mdio_read ; returns with window #4
        xchg    eax, [esp]
        mov     al, E3C59X_REG_MII_ANLPAR
        call    e3c59x_mdio_read ; returns with window #4
        pop     ebx
        and     eax, ebx
        and     eax, 1111100000b
        push    eax

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        mov     word[e3c59x_link_type], ax

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        ; set full-duplex mode
        lea     edx, [ebp + E3C59X_REG_MAC_CONTROL]
        in      ax, dx
        and     ax, not 0x120 ; clear full duplex and flow control
        pop     ebx
        test    ebx, 1010b shl 5 ; check for full-duplex
        jz      .half_duplex
        or      ax, 0x120 ; set full duplex and flow control

  .half_duplex:
        out     dx, ax
        mov     al, 1
        ret

  .no_ext_cap:
        ; not yet implemented BCM5000

  .fail_finish:
        pop     eax
        xor     al, al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_try_mii ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? checks the on-chip auto-negotiation logic or an off-chip MII PHY, depending upon what is set in xcvrSelect by the
;? caller. It exits when it finds the first device with a good link.
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0
;< al = 1
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, esi
;-----------------------------------------------------------------------------------------------------------------------
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        in      eax, dx
        and     eax, 1111b shl 20
        cmp     eax, 1000b shl 20 ; is auto-negotiation set?
        jne     .mii_device
        ; auto-negotiation is set
        ; switch to register window 4
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 4
        out     dx, ax
        ; PHY==24 is the on-chip auto-negotiation logic
        ; it supports only 10base-T and 100base-TX
        mov     ah, 24
        call    e3c59x_try_phy
        test    al, al
        jz      .fail_finish
        mov     cl, 24
        jmp     .check_preamble

  .mii_device:
        cmp     eax, 0110b shl 20
        jne     .fail_finish
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 4
        out     dx, ax
        lea     edx, [ebp + E3C59X_REG_PHYSICAL_MGMT]
        in      ax, dx
        and     al, (1 shl E3C59X_BIT_MGMT_DIR) or (1 shl E3C59X_BIT_MGMT_DATA)
        cmp     al, (1 shl E3C59X_BIT_MGMT_DATA)
        je      .serch_for_phy
        xor     al, al
        ret

  .serch_for_phy:
        ; search for PHY
        mov     cl, 31

  .search_phy_loop:
        cmp     cl, 24
        je      .next_phy
        mov     ah, cl ; ah = phy
        mov     al, E3C59X_REG_MII_BMCR ; al = Basic Mode Status Register
        push    ecx
        call    e3c59x_mdio_read
        pop     ecx
        test    ax, ax
        jz      .next_phy
        cmp     ax, 0xffff
        je      .next_phy
        mov     ah, cl ; ah = phy
        push    ecx
        call    e3c59x_try_phy
        pop     ecx
        test    al, al
        jnz     .check_preamble

  .next_phy:
        dec     cl
        jns     .search_phy_loop

  .fail_finish:
        xor     al, al
        ret

        ; epilog

  .check_preamble:
        push    eax ; eax contains the return value of e3c59x_try_phy
        ; check hard coded preamble forcing
        movzx   eax, byte[e3c59x_ver_id]
        test    word[eax * 4 + e3c59x_hw_versions + 2], EXTRA_PREAMBLE
        setnz   [e3c59x_preamble] ; force preamble
        jnz     .finish
        ; check mii for preamble suppression
        mov     ah, cl
        mov     al, E3C59X_REG_MII_BMSR
        call    e3c59x_mdio_read
        test    al, 1000000b ; preamble suppression?
        setz    [e3c59x_preamble] ; no

  .finish:
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_test_packet ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? try a loopback packet for 10BASE2 or AUI port
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0
;< al = 1
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        ; set fullDuplexEnable in MacControl register
        lea     edx, [ebp + E3C59X_REG_MAC_CONTROL]
        in      ax, dx
        or      ax, 0x120
        out     dx, ax
        ; switch to register window 5
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 5
        out     dx, ax
        ; set RxFilter to enable individual address matches
        mov     ax, 10000b shl 11
        lea     edx, [ebp + E3C59X_REG_RX_FILTER]
        in      al, dx
        or      al, 1
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        out     dx, ax
        ; issue RxEnable and TxEnable
        call    e3c59x_rx_reset
        call    e3c59x_tx_reset
        ; download a self-directed test packet
        mov     edi, node_addr
        mov     bx, 0x0608 ; packet type
        mov     esi, e3c59x_self_directed_packet
        mov     ecx, 6 ; 6 + 6 + 2 + 6 = 20 bytes
        call    dword[e3c59x_transmit_function]
        ; wait for 2s
        mov     esi, 2000 ; 2000ms = 2s
        call    delay_ms
        ; check if self-directed packet is received
        call    dword[e3c59x_receive_function]
        test    al, al
        jnz     .finish
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        ; clear fullDuplexEnable in MacControl register
        lea     edx, [ebp + E3C59X_REG_MAC_CONTROL]
        in      ax, dx
        and     ax, not 0x120
        out     dx, ax
        xor     al, al

  .finish:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_try_loopback ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? tries a loopback packet for 10BASE2 or AUI port
;-----------------------------------------------------------------------------------------------------------------------
;> al = 0: 10Mbps AUI connector
;>      1: 10BASE-2
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0
;< al = 1
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        pop     eax
        push    eax

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        mov     bl, al
        inc     bl
        shl     bl, 3
        or      byte[e3c59x_link_type + 1], bl

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

        test    al, al ; aui or coax?
        jz      .complete_loopback
        ; enable 100BASE-2 DC-DC converter
        mov     ax, 10b shl 11 ; EnableDcConverter
        out     dx, ax

  .complete_loopback:
        mov     cl, 2 ; give a port 3 chances to complete a loopback

  .next_try:
        push    ecx
        call    e3c59x_test_packet
        pop     ecx
        test    al, al
        jnz     .finish
        dec     cl
        jns     .next_try

  .finish:
        xchg    eax, [esp]
        test    al, al
        jz      .aui_finish
        ; issue DisableDcConverter command
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, 10111b shl 11
        out     dx, ax

  .aui_finish:
        pop     eax ; al contains the result of operation

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        test    al, al
        jnz     @f
        and     byte[e3c59x_link_type + 1], not 11000b

    @@:

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_set_available_media ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? sets the first available media
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0
;< al = 1
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, edx
;-----------------------------------------------------------------------------------------------------------------------
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        in      eax, dx
        push    eax
        lea     edx, [ebp + E3C59X_REG_MEDIA_OPTIONS]
        in      ax, dx
        test    al, 10b
        jz      @f
        ; baseTXAvailable
        pop     eax
        and     eax, not (1111b shl 20)
        or      eax, 100b shl 20

if KCONFIG_NET_DRIVER_E3C59X_DEBUG & defined E3C59X_FORCE_FD

        mov     word[e3c59x_link_type], 1 shl 8

else if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        mov     word[e3c59x_link_type], 1 shl 7

end if

        jmp     .set_media

    @@: test    al, 100b
        jz      @f
        ; baseFXAvailable
        pop     eax
        and     eax, not (1111b shl 20)
        or      eax, 101b shl 20

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        mov     word[e3c59x_link_type], 1 shl 10

end if

        jmp     .set_media

    @@: test    al, 1000000b
        jz      @f
        ; miiDevice
        pop     eax
        and     eax, not (1111b shl 20)
        or      eax, 0110b shl 20

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        mov     word[e3c59x_link_type], 1 shl 13

end if

        jmp     .set_media

    @@: test    al, 1000b
        jz      @f

  .set_default:
        ; 10bTAvailable
        pop     eax
        and     eax, not (1111b shl 20)

if KCONFIG_NET_DRIVER_E3C59X_DEBUG & defined E3C59X_FORCE_FD

        mov     word[e3c59x_link_type], 1 shl 6

else if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        mov     word[e3c59x_link_type], 1 shl 5

end if ; E3C59X_FORCE_FD

        jmp     .set_media

    @@: test    al, 10000b
        jz      @f
        ; coaxAvailable
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, 10b shl 11 ; EnableDcConverter
        out     dx, ax
        pop     eax
        and     eax, not (1111b shl 20)
        or      eax, 11b shl 20

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        mov     word[e3c59x_link_type], 1 shl 12

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

        jmp     .set_media

    @@: test    al, 10000b
        jz      .set_default
        ; auiAvailable
        pop     eax
        and     eax, not (1111b shl 20)
        or      eax, 1 shl 20

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        mov     word[e3c59x_link_type], 1 shl 11

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

  .set_media:
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        out     dx, eax

if defined E3C59X_FORCE_FD

        ; set fullDuplexEnable in MacControl register
        lea     edx, [ebp + E3C59X_REG_MAC_CONTROL]
        in      ax, dx
        or      ax, 0x120
        out     dx, ax

end if ; E3C59X_FORCE_FD

        mov     al, 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_set_active_port ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? It selects the media port (transceiver) to be used
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        in      eax, dx
        test    eax, 1 shl 24 ; check if autoselect enable
        jz      .set_first_available_media
        ; check 100BASE-TX and 10BASE-T
        lea     edx, [ebp + E3C59X_REG_MEDIA_OPTIONS]
        in      ax, dx
        test    al, 1010b ; check whether 100BASE-TX or 10BASE-T available
        jz      .mii_device ; they are not available
        ; set auto-negotiation
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        in      eax, dx
        and     eax, not (1111b shl 20)
        or      eax, 1000b shl 20
        out     dx, eax
        call    e3c59x_try_mii
        test    al, al
        jz      .mii_device
        ret

  .mii_device:
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        ; check for off-chip mii device
        lea     edx, [ebp + E3C59X_REG_MEDIA_OPTIONS]
        in      ax, dx
        test    al, 1000000b ; check miiDevice
        jz      .base_fx
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        in      eax, dx
        and     eax, not (1111b shl 20)
        or      eax, 0110b shl 20 ; set MIIDevice
        out     dx, eax
        call    e3c59x_try_mii
        test    al, al
        jz      .base_fx
        ret

  .base_fx:
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        ; check for 100BASE-FX
        lea     edx, [ebp + E3C59X_REG_MEDIA_OPTIONS]
        in      ax, dx ; read media option register
        test    al, 100b ; check 100BASE-FX
        jz      .aui_enable
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        in      eax, dx
        and     eax, not (1111b shl 20)
        or      eax, 0101b shl 20 ; set 100base-FX
        out     dx, eax
        call    e3c59x_try_link_detect
        test    al, al
        jz      .aui_enable
        ret

  .aui_enable:
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        ; check for 10Mbps AUI connector
        lea     edx, [ebp + E3C59X_REG_MEDIA_OPTIONS]
        in      ax, dx ; read media option register
        test    al, 100000b ; check 10Mbps AUI connector
        jz      .coax_available
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        in      eax, dx
        and     eax, not (1111b shl 20)
        or      eax, 0001b shl 20 ; set 10Mbps AUI connector
        out     dx, eax
        xor     al, al ; try 10Mbps AUI connector
        call    e3c59x_try_loopback
        test    al, al
        jz      .coax_available
        ret

  .coax_available:
        ; switch to register window 3
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 3
        out     dx, ax
        ; check for coaxial 10BASE-2 port
        lea     edx, [ebp + E3C59X_REG_MEDIA_OPTIONS]
        in      ax, dx ; read media option register
        test    al, 10000b ; check 10BASE-2
        jz      .set_first_available_media
        lea     edx, [ebp + E3C59X_REG_INTERNAL_CONFIG]
        in      eax, dx
        and     eax, not (1111b shl 20)
        or      eax, 0011b shl 20 ; set 10BASE-2
        out     dx, eax
        mov     al, 1
        call    e3c59x_try_loopback
        test    al, al
        jz      .set_first_available_media
        ret

  .set_first_available_media:
        jmp     e3c59x_set_available_media
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_wake_up ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? set the power state to D0
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        ; wake up - we directly do it by programming PCI
        ; check if the device is power management capable
        mov     al, 2
        mov     ah, [pci_bus]
        mov     bl, PCI_REG_STATUS
        mov     bh, [pci_dev]
        push    eax ebx
        call    pci_read_reg
        test    al, 10000b ; is there "new capabilities" linked list?
        pop     ebx eax
        jz      .device_awake
        ; search for power management register
        mov     al, 1
        mov     bl, PCI_REG_CAP_PTR
        push    eax ebx
        call    pci_read_reg
        mov     cl, al
        cmp     cl, 0x3f
        pop     ebx eax
        jbe     .device_awake
        ; traverse the list
        mov     al, 2

  .pm_loop:
        mov     bl, cl
        push    eax ebx
        call    pci_read_reg
        cmp     al, 1
        je      .set_pm_state
        test    ah, ah
        mov     cl, ah
        pop     ebx eax
        jnz     .pm_loop
        jmp     .device_awake

        ; wake up the device if necessary

  .set_pm_state:
        pop     ebx eax
        add     bl, PCI_REG_PM_CTRL
        push    eax ebx
        call    pci_read_reg
        mov     cx, ax
        test    cl, 3
        pop     ebx eax
        jz      .device_awake
        and     cl, not 11b ; set state to D0
        call    pci_write_reg

  .device_awake:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_probe ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Searches for an ethernet card, enables it and clears the rx buffer
;? If a card was found, it enables the ethernet -> TCPIP link
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        movzx   ebp, word[io_addr]
        mov     al, 2
        mov     ah, [pci_bus]
        mov     bh, [pci_dev]
        mov     bl, PCI_REG_COMMAND
        push    ebp eax ebx
        call    pci_read_reg
        mov     cx, ax
        or      cl, (1 shl PCI_BIT_MASTER) or (1 shl PCI_BIT_PIO)
        and     cl, not (1 shl PCI_BIT_MMIO)
        pop     ebx eax
        call    pci_write_reg
        ; wake up the card
        call    e3c59x_wake_up
        pop     ebp
        ; get chip version
        mov     ax, [pci_data + 2]
        mov     ecx, E3C59X_HW_VERSIONS_SIZE / 4 - 1

  .chip_ver_loop:
        cmp     ax, [e3c59x_hw_versions + ecx * 4]
        jz      .chip_ver_found
        dec     ecx
        jns     .chip_ver_loop
        xor     ecx, ecx

  .chip_ver_found:
        mov     [e3c59x_ver_id], cl
        test    word[e3c59x_hw_versions + 2 + ecx * 4], HAS_HWCKSM
        setnz   [e3c59x_has_hwcksm]
        ; set pci latency for vortex cards
        test    word[e3c59x_hw_versions + 2 + ecx * 4], IS_VORTEX
        jz      .not_vortex
        mov     cx, 11111000b ; 248 = max latency
        mov     al, 1
        mov     ah, [pci_bus]
        mov     bl, PCI_REG_LATENCY
        mov     bh, [pci_dev]
        call    pci_write_reg

  .not_vortex:
        ; set RX/TX functions
        mov     ax, E3C59X_EEPROM_REG_CAPABILITIES
        call    e3c59x_read_eeprom
        test    al, 100000b ; full bus master?
        setnz   [e3c59x_full_bus_master]
        jnz     .boomerang_func
        mov     dword[e3c59x_transmit_function], e3c59x_vortex_transmit
        mov     dword[e3c59x_receive_function], e3c59x_vortex_poll
        jmp     @f

  .boomerang_func:
        ; full bus master, so use boomerang functions
        mov     dword[e3c59x_transmit_function], e3c59x_boomerang_transmit
        mov     dword[e3c59x_receive_function], e3c59x_boomerang_poll

    @@: ; read MAC from eeprom
        mov     ecx, 2

  .mac_loop:
        lea     ax, [E3C59X_EEPROM_REG_OEM_NODE_ADDR + ecx]
        call    e3c59x_read_eeprom
        xchg    ah, al ; htons
        mov     [node_addr + ecx * 2], ax
        dec     ecx
        jns     .mac_loop
        test    byte[e3c59x_full_bus_master], 0xff
        jz      .set_preamble
; switch to register window 2
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 2
        out     dx, ax
; activate xcvr by setting some magic bits
        lea     edx, [ebp + E3C59X_REG_RESET_OPTIONS]
        in      ax, dx
        and     ax, not 0x4010
        movzx   ebx, byte[e3c59x_ver_id]
        test    word[ebx * 4 + e3c59x_hw_versions + 2], INVERT_LED_PWR
        jz      @f
        or      al, 0x10

    @@: test    word[ebx * 4 + e3c59x_hw_versions + 2], INVERT_MII_PWR
        jz      @f
        or      ah, 0x40

    @@: out     dx, ax

  .set_preamble:
        ; use preamble as default
        mov     byte[e3c59x_preamble], 1 ; enable preamble
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_reset ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Place the chip (ie, the ethernet card) into a virgin state
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        ; issue global reset
        call    e3c59x_global_reset
        ; disable interrupts
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, 1110b shl 11
        out     dx, ax
        ; enable Statistics
        mov     ax, 10101b shl 11
        out     dx, ax
        ; set indication
        mov     ax, (1111b shl 11) or 0x6c6
        out     dx, ax
        ; acknowledge (clear) every interrupt indicator
        mov     ax, (1101b shl 11) or 0x661
        out     dx, ax
        ; switch to register window 2
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 2
        out     dx, ax
        ; write MAC addres back into the station address registers
        lea     edx, [ebp + E3C59X_REG_STATION_ADDRESS_LO]
        mov     esi, node_addr
        outsw
        add     edx, 2
        outsw
        add     edx, 2
        outsw
        add     edx, 2
        ; clear station mask
        xor     eax, eax
        out     dx, ax
        add     edx, 2
        out     dx, ax
        add     edx, 2
        out     dx, ax
        ; switch to register window 6
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 6
        out     dx, ax
        ; clear all statistics by reading
        lea     edx, [ebp + E3C59X_REG_CARRIER_LOST]
        mov     cl, 9

  .stat_clearing_loop:
        in      al, dx
        inc     edx
        dec     cl
        jns     .stat_clearing_loop
        in      ax, dx
        add     dx, 2
        in      ax, dx
        ; switch to register window 4
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 4
        out     dx, ax
        ; clear BadSSD
        lea     edx, [ebp + E3C59X_REG_BAD_SSD]
        in      al, dx
        ; clear extra statistics bit in NetworkDiagnostic
        lea     edx, [ebp + E3C59X_REG_NETWORK_DIAGNOSTIC]
        in      ax, dx
        or      ax,  0x0040
        out     dx, ax
        ; SetRxEarlyThreshold
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, (10001b shl 11) + (E3C59X_MAX_ETH_PKT_SIZE shr 2)
        out     dx, ax
        test    byte[e3c59x_full_bus_master], 0xff
        jz      .skip_boomerang_setting
        ; set upRxEarlyEnable
        lea     edx, [ebp + E3C59X_REG_DMA_CTRL]
        in      eax, dx
        or      eax, 0x20
        out     dx, eax
        ; TxFreeThreshold
        lea     edx, [ebp + E3C59X_REG_TX_FREE_THRESH]
        mov     al, E3C59X_MAX_ETH_PKT_SIZE / 256
        out     dx, al
        ; program DnListPtr
        lea     edx, [ebp + E3C59X_REG_DN_LIST_PTR]
        xor     eax, eax
        out     dx, eax

  .skip_boomerang_setting:
        ; initialization
        call    e3c59x_rx_reset
        call    e3c59x_tx_reset
        call    e3c59x_set_active_port
        call    e3c59x_rx_reset
        call    e3c59x_tx_reset
        ; switch to register window 5
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 5
        out     dx, ax
        ; program RxFilter for promiscuous operation
        mov     ax, 10000b shl 11
        lea     edx, [ebp + E3C59X_REG_RX_FILTER]
        in      al, dx
        or      al, 1111b
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        out     dx, ax
        ; switch to register window 4
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 4
        out     dx, ax
        ; wait for linkDetect
        lea     edx, [ebp + E3C59X_REG_MEDIA_STATUS]
        mov     cl, 20 ; wait for max 2s
        mov     esi, 100 ; 100ms

  .link_detect_loop:
        call    delay_ms
        in      ax, dx
        test    ah, 1000b ; linkDetect
        jnz     @f
        dec     cl
        jnz     .link_detect_loop

    @@: ; Indicate that we have successfully reset the card
        mov     eax, [pci_data]
        mov     [eth_status], eax

if KCONFIG_NET_DRIVER_E3C59X_DEBUG

        call    e3c59x_debug

end if ; KCONFIG_NET_DRIVER_E3C59X_DEBUG

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_global_reset ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? resets the device
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: ax, ecx, edx, esi
;-----------------------------------------------------------------------------------------------------------------------
        ; GlobalReset
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        xor     eax, eax
;       or      al, 0x14
        out     dx, ax
        ; wait for GlobalReset to complete
        mov     ecx, 64000

  .global_reset_loop:
        in      ax, dx
        test    ah, 10000b ; check CmdInProgress
        jz      .finish
        dec     ecx
        jnz     .global_reset_loop

  .finish:
        ; wait for 2 seconds for NIC to boot
        mov     esi, 2000 ; 2000ms = 2s
        push    ebp
        call    delay_ms
        pop     ebp
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_tx_reset ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? resets and enables transmitter engine
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: ax, ecx, edx
;-----------------------------------------------------------------------------------------------------------------------
        ; TxReset
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, 01011b shl 11
        out     dx, ax
        ; Wait for TxReset to complete
        mov     ecx, 200000

  .tx_reset_loop:
        in      ax, dx
        test    ah, 10000b ; check CmdInProgress
        jz      .tx_set_prev
        dec     ecx
        jns     .tx_reset_loop

  .tx_set_prev:
        test    byte[e3c59x_full_bus_master], 0xff
        jz      .tx_enable
        ; init last_dpd
        mov     dword[e3c59x_prev_dpd], e3c59x_dpd_buff + (E3C59X_NUM_TX_DESC - 1) * E3C59X_DPD_SIZE
        mov     dword[e3c59x_prev_tx_frame], e3c59x_tx_buff + (E3C59X_NUM_TX_DESC - 1) * E3C59X_MAX_ETH_FRAME_SIZE

  .tx_enable:
        mov     ax, 01001b shl 11 ; TxEnable
        out     dx, ax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_rx_reset ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? resets and enables receiver engine
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, edi, esi
;-----------------------------------------------------------------------------------------------------------------------
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, (0101b shl 11) or 0x4 ; RxReset
        out     dx, ax
        ; wait for RxReset to complete
        mov     ecx, 200000

  .rx_reset_loop:
        in      ax, dx
        test    ah, 10000b ; check CmdInProgress
        jz      .setup_upd
        dec     ecx
        jns     .rx_reset_loop

  .setup_upd:
        ; check if full bus mastering
        test    byte[e3c59x_full_bus_master], 0xff
        jz      .rx_enable
        ; create upd ring
        mov     eax, e3c59x_upd_buff
        ZeroToVirt eax
        mov     [e3c59x_curr_upd], eax
        mov     esi, eax
        VirtToDma esi
        mov     edi, e3c59x_rx_buff
        ZeroToDma edi
        mov     ebx, e3c59x_upd_buff + (E3C59X_NUM_RX_DESC - 1) * E3C59X_UPD_SIZE
        ZeroToVirt ebx
        mov     cl, E3C59X_NUM_RX_DESC - 1

  .upd_loop:
        mov     [ebx + E3C59X_UPD_UP_NEXT_PTR], esi
        and     dword[eax + E3C59X_UPD_PKT_STATUS], 0
        mov     [eax + E3C59X_UPD_UP_FRAG_ADDR], edi
        mov     dword[eax + E3C59X_UPD_UP_FRAG_LEN], E3C59X_MAX_ETH_FRAME_SIZE or (1 shl 31)
        add     edi, E3C59X_MAX_ETH_FRAME_SIZE
        add     esi, E3C59X_UPD_SIZE
        mov     ebx, eax
        add     eax, E3C59X_UPD_SIZE
        dec     cl
        jns     .upd_loop
        mov     eax, e3c59x_upd_buff
        ZeroToDma eax
        lea     edx, [ebp + E3C59X_REG_UP_LIST_PTR]
        out     dx, eax ; write E3C59X_REG_UP_LIST_PTR
        lea     edx, [ebp + E3C59X_REG_COMMAND]

  .rx_enable:
        mov     ax, 00100b shl 11 ; RxEnable
        out     dx, ax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
;kproc e3c59x_write_eeprom ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? reads eeprom
;-----------------------------------------------------------------------------------------------------------------------
;> ax = register to be read (only the first 63 words can be read)
;> cx = value to be read into the register
;-----------------------------------------------------------------------------------------------------------------------
;< ax = word read
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: ax, ebx, edx
;# Note: the caller must switch to the register window 0 before calling this function
;-----------------------------------------------------------------------------------------------------------------------
;       mov     edx, [io_addr]
;       add     edx, E3C59X_REG_EEPROM_COMMAND
;       cmp     ah, 11b
;       ja      .finish ; address may have a value of maximal 1023
;       shl     ax, 2
;       shr     al, 2
;       push    eax
;       ; wait for busy
;       mov     ebx, 0xffff
;
;   @@: in      ax, dx
;       test    ah, 0x80
;       jz      .write_enable
;       dec     ebx
;       jns     @r
;       ; write enable
;
; .write_enable:
;       xor     eax, eax
;       mov     eax, 11b shl 4
;       out     dx, ax
;       ; wait for busy
;       mov     ebx, 0xffff
;
;   @@: in      ax, dx
;       test    ah, 0x80
;       jz      .erase_loop
;       dec     ebx
;       jns     @r
;
; .erase_loop:
;       pop     eax
;       push    eax
;       or      ax, 11b shl 6 ; erase register
;       out     dx, ax
;       mov     ebx, 0xffff
;
;   @@: in      ax, dx
;       test    ah, 0x80
;       jz      .write_reg
;       dec     ebx
;       jns     @r
;
; .write_reg:
;       add     edx, E3C59X_REG_EEPROM_DATA - E3C59X_REG_EEPROM_COMMAND
;       mov     eax, ecx
;       out     dx, ax
;       ; write enable
;       add     edx, E3C59X_REG_EEPROM_COMMAND - E3C59X_REG_EEPROM_DATA
;       xor     eax, eax
;       mov     eax, 11b shl 4
;       out     dx, ax
;       ; wait for busy
;       mov     ebx, 0xffff
;
;   @@: in      ax, dx
;       test    ah, 0x80
;       jz      .issue_write_reg
;       dec     ebx
;       jns     @r
;
; .issue_write_reg:
;       pop     eax
;       or      ax, 01b shl 6
;       out     dx, ax
;
; .finish:
;       ret
;kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_read_eeprom ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? reads eeprom
;-----------------------------------------------------------------------------------------------------------------------
;> ax = register to be read (only the first 63 words can be read)
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< ax = word read
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: ax, ebx, edx, ebp
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        ; switch to register window 0
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 0
        out     dx, ax
        pop     eax
        and     ax, 111111b ; take only the first 6 bits into account
        movzx   ebx, byte[e3c59x_ver_id]
        test    word[ebx * 4 + e3c59x_hw_versions + 2], EEPROM_8BIT
        jz      @f
        add     ax, 0x230 ; hardware constant
        jmp     .read

    @@: add     ax, E3C59X_EEPROM_CMD_READ
        test    word[ebx * 4 + e3c59x_hw_versions + 2], EEPROM_OFFSET
        jz      .read
        add     ax, 0x30

  .read:
        lea     edx, [ebp + E3C59X_REG_EEPROM_COMMAND]
        out     dx, ax
        mov     ebx, 0xffff ; duration of about 162 us ;-)

  .wait_for_reading:
        in      ax, dx
        test    ah, 0x80 ; check bit eepromBusy
        jz      .read_data
        dec     ebx
        jns     .wait_for_reading

  .read_data:
        lea     edx, [ebp + E3C59X_REG_EEPROM_DATA]
        in      ax, dx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_mdio_sync ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? initial synchronization
;-----------------------------------------------------------------------------------------------------------------------
;> ebp - io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: ax, edx, cl
;-----------------------------------------------------------------------------------------------------------------------
        ; switch to register window 4
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 4
        out     dx, ax
        cmp     byte[e3c59x_preamble], 0
        je      .no_preamble
        ; send 32 logic ones
        lea     edx, [ebp + E3C59X_REG_PHYSICAL_MGMT]
        mov     cl, 31

  .loop:
        mov     ax, (1 shl E3C59X_BIT_MGMT_DATA) or (1 shl E3C59X_BIT_MGMT_DIR)
        out     dx, ax
        in      ax, dx ; delay
        mov     ax, (1 shl E3C59X_BIT_MGMT_DATA) or (1 shl E3C59X_BIT_MGMT_DIR) or (1 shl E3C59X_BIT_MGMT_CLK)
        out     dx, ax
        in      ax, dx ; delay
        dec     cl
        jns     .loop

  .no_preamble:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_mdio_read ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? read MII register
;? see page 16 in D83840A.pdf
;-----------------------------------------------------------------------------------------------------------------------
;> ah = PHY addr
;> al = register addr
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< ax = register read
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, cx, edx
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        call    e3c59x_mdio_sync ; returns with window #4
        pop     eax
        lea     edx, [ebp + E3C59X_REG_PHYSICAL_MGMT]
        shl     al, 3
        shr     ax, 3
        and     ax, not E3C59X_MII_CMD_MASK
        or      ax, E3C59X_MII_CMD_READ
        mov     ebx, eax
        xor     ecx, ecx
        mov     cl, 13

  .cmd_loop:
        mov     ax, (1 shl E3C59X_BIT_MGMT_DIR) ; write mii
        bt      ebx, ecx
        jnc     .zero_bit
        or      al, (1 shl E3C59X_BIT_MGMT_DATA)

  .zero_bit:
        out     dx, ax
        push    eax
        in      ax, dx ; delay
        pop     eax
        or      al, (1 shl E3C59X_BIT_MGMT_CLK) ; write
        out     dx, ax
        in      ax, dx ; delay
        dec     cl
        jns     .cmd_loop
        ; read data (18 bits with the two transition bits)
        mov     cl, 17
        xor     ebx, ebx

  .read_loop:
        shl     ebx, 1
        xor     eax, eax ; read comand
        out     dx, ax
        in      ax, dx ; delay
        in      ax, dx
        test    al, (1 shl E3C59X_BIT_MGMT_DATA)
        jz      .dont_set
        inc     ebx

  .dont_set:
        mov     ax, (1 shl E3C59X_BIT_MGMT_CLK)
        out     dx, ax
        in      ax, dx ; delay
        dec     cl
        jns     .read_loop
        mov     eax, ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_mdio_write ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? write MII register
;? see page 16 in D83840A.pdf
;-----------------------------------------------------------------------------------------------------------------------
;> ah = PHY addr
;> al = register addr
;> bx = word to be written
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< ax = register read
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, cx, edx
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        call    e3c59x_mdio_sync
        pop     eax
        lea     edx, [ebp + E3C59X_REG_PHYSICAL_MGMT]
        shl     al, 3
        shr     ax, 3
        and     ax, not E3C59X_MII_CMD_MASK
        or      ax, E3C59X_MII_CMD_WRITE
        shl     eax, 2
        or      eax, 10b ; transition bits
        shl     eax, 16
        mov     ax, bx
        mov     ebx, eax
        mov     ecx, 31

  .cmd_loop:
        mov     ax, 1 shl E3C59X_BIT_MGMT_DIR ; write mii
        bt      ebx, ecx
        jnc     .zero_bit
        or      al, 1 shl E3C59X_BIT_MGMT_DATA

  .zero_bit:
        out     dx, ax
        push    eax
        in      ax, dx ; delay
        pop     eax
        or      al, 1 shl E3C59X_BIT_MGMT_CLK ; write
        out     dx, ax
        in      ax, dx ; delay
        dec     ecx
        jns     .cmd_loop
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_transmit ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Transmits a packet of data via the ethernet card
;-----------------------------------------------------------------------------------------------------------------------
;> edi = Pointer to 48 bit destination address
;> bx = Type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ecx, edx, ebp
;-----------------------------------------------------------------------------------------------------------------------
        jmp     dword[e3c59x_transmit_function]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_check_tx_status ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Checks TxStatus queue.
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0, no error was found
;< al = 1, error was found TxReset is needed
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ecx, edx, ebp
;-----------------------------------------------------------------------------------------------------------------------
        movzx   ebp, word[io_addr] ; to be implemented in ETHERNET.INC
        ; clear TxStatus queue
        lea     edx, [ebp + E3C59X_REG_TX_STATUS]
        mov     cl, 31 ; max number of queue entries

  .tx_status_loop:
        in      al, dx
        test    al, al
        jz      .finish ; no error
        test    al, 0x3f
        jnz     .finish ; error

  .no_error_found:
        ; clear current TxStatus entry which advances the next one
        xor     al, al
        out     dx, al
        dec     cl
        jns     .tx_status_loop

  .finish:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_vortex_transmit ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Transmits a packet of data via the ethernet card
;-----------------------------------------------------------------------------------------------------------------------
;> edi = Pointer to 48 bit destination address
;> bx = Type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, edx, ecx, edi, esi, ebp
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        call    e3c59x_check_tx_status
        pop     ecx
        test    al, al
        jz      .no_error_found
        jmp     e3c59x_tx_reset

  .no_error_found:
        ; switch to register window 7
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 7
        out     dx, ax
        ; check for master operation in progress
        lea     edx, [ebp + E3C59X_REG_MASTER_STATUS]
        in      ax, dx
        test    ah, 0x80
        jnz     .finish ; no DMA for sending
        ; dword boundary correction
        cmp     ecx, E3C59X_MAX_ETH_FRAME_SIZE
        ja      .finish ; packet is too long
        ; write Frame Start Header
        mov     eax, ecx
        ; add header length and extend the complete length to dword boundary
        add     eax, ETH_HLEN + 3
        and     eax, not 3
        lea     edx, [ebp + E3C59X_REG_TX_DATA]
        out     dx, eax
        ; prepare the complete frame
        push    esi
        mov     esi, edi
        mov     edi, e3c59x_tx_buff
        ZeroToVirt edi
        ; copy destination address
        movsd
        movsw
        ; copy source address
        mov     esi, node_addr
        movsd
        movsw
        ; copy packet type
        mov     [edi], bx
        add     edi, 2
        ; copy packet data
        pop     esi
        push    ecx
        shr     ecx, 2
        rep
        movsd
        pop     ecx
        and     ecx, 3
        rep
        movsb
        mov     ecx, eax
        ; program frame address to be sent
        lea     edx, [ebp + E3C59X_REG_MASTER_ADDRESS]
        mov     eax, e3c59x_tx_buff
        ZeroToDma eax
        out     dx, eax
        ; program frame length
        lea     edx, [ebp + E3C59X_REG_MASTER_LEN]
        mov     eax, ecx
        out     dx, ax
        ; start DMA Down
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, (10100b shl 11) + 1 ; StartDMADown
        out     dx, ax

  .finish:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_boomerang_transmit ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Transmits a packet of data via the ethernet card
;-----------------------------------------------------------------------------------------------------------------------
;> edi = Pointer to 48 bit destination address
;> bx = Type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx, esi, edi, ebp
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        call    e3c59x_check_tx_status
        pop     ecx
        test    al, al
        jz      .no_error_found
        jmp     e3c59x_tx_reset

  .no_error_found:
        cmp     ecx, E3C59X_MAX_ETH_FRAME_SIZE
        ja      .finish ; packet is too long
        ; calculate descriptor address
        mov     eax, [e3c59x_prev_dpd]
        cmp     eax, e3c59x_dpd_buff + (E3C59X_NUM_TX_DESC - 1) * E3C59X_DPD_SIZE
        jb      @f
        ; wrap around
        mov     eax, e3c59x_dpd_buff - E3C59X_DPD_SIZE

    @@: add     eax, E3C59X_DPD_SIZE
        ZeroToVirt eax
        push    eax
        ; check DnListPtr
        lea     edx, [ebp + E3C59X_REG_DN_LIST_PTR]
        in      eax, dx
        ; mark if Dn_List_Ptr is cleared
        test    eax, eax
        setz    [e3c59x_dn_list_ptr_cleared]
        ; finish if no more free descriptor is available - FIXME!
        cmp     eax, [esp]
        pop     eax
        jz      .finish
        push    eax esi
        mov     esi, edi
        ; calculate tx_buffer address
        mov     edi, [e3c59x_prev_tx_frame]
        cmp     edi, e3c59x_tx_buff + (E3C59X_NUM_TX_DESC - 1) * E3C59X_MAX_ETH_FRAME_SIZE
        jb      @f
        ; wrap around
        mov     edi, e3c59x_tx_buff - E3C59X_MAX_ETH_FRAME_SIZE

    @@: add     edi, E3C59X_MAX_ETH_FRAME_SIZE
        ZeroToVirt edi
        mov     eax, edi
        ; copy destination address
        movsd
        movsw
        ; copy source address
        mov     esi, node_addr
        movsd
        movsw
        ; copy packet type
        mov     [edi], bx
        add     edi, 2
        ; copy packet data
        pop     esi
        push    ecx
        shr     ecx, 2
        rep
        movsd
        pop     ecx
        push    ecx
        and     ecx, 3
        rep
        movsb
        ; padding, do we really need it?
        pop     ecx
        add     ecx, ETH_HLEN
        cmp     ecx, ETH_ZLEN
        jae     @f
        mov     ecx, ETH_ZLEN

    @@: ; calculate
        mov     ebx, ecx
;       test    byte[e3c59x_has_hwcksm], 0xff
;       jz      @f
;       or      ebx, 1 shl 26 ; set AddTcpChecksum
;
;   @@:

        or      ebx, 0x8000 ; transmission complete notification
        or      ecx, 0x80000000 ; last fragment
        ; program DPD
        mov     edi, eax
        pop     eax
        and     dword[eax + E3C59X_DPD_DN_NEXT_PTR], 0
        mov     dword[eax + E3C59X_DPD_FRAME_START_HDR], ebx
        VirtToDma edi
        mov     dword[eax + E3C59X_DPD_DN_FRAG_ADDR], edi
        mov     [eax + E3C59X_DPD_DN_FRAG_LEN], ecx
        ; calculate physical address
        VirtToDma eax
        push    eax
        cmp     byte[e3c59x_dn_list_ptr_cleared], 0
        jz      .add_to_list
        ; write Dn_List_Ptr
        out     dx, eax
        jmp     .finish

  .add_to_list:
        ; DnStall
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, (110b shl 11) + 2
        out     dx, ax
        ; wait for DnStall to complete
        mov     ecx, 6000

  .wait_for_stall:
        in      ax, dx ; read E3C59X_REG_INT_STATUS
        test    ah, 10000b
        jz      .dnstall_ok
        dec     ecx
        jnz     .wait_for_stall

  .dnstall_ok:
        pop     eax
        push    eax
        mov     ebx, [e3c59x_prev_dpd]
        ZeroToVirt ebx
        mov     [ebx], eax
        lea     edx, [ebp + E3C59X_REG_DN_LIST_PTR]
        in      eax, dx
        test    eax, eax
        jnz     .dnunstall
        ; if Dn_List_Ptr has been cleared fill it up
        pop     eax
        push    eax
        out     dx, eax

  .dnunstall:
        ; DnUnStall
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, (110b shl 11) + 3
        out     dx, ax

  .finish:
        pop     eax
        DmaToZero eax
        mov     [e3c59x_prev_dpd], eax
        DmaToZero edi
        mov     [e3c59x_prev_tx_frame], edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_poll ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Polls the ethernet card for a received packet
;? Received data, if any, ends up in Ether_buffer
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, edx, ecx, edi, esi, ebp
;-----------------------------------------------------------------------------------------------------------------------
        jmp     dword[e3c59x_receive_function]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_vortex_poll ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Polls the ethernet card for a received packet
;? Received data, if any, ends up in Ether_buffer
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0 ; no packet received
;< al = 1 ; packet received
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, edx, ecx, edi, esi, ebp
;-----------------------------------------------------------------------------------------------------------------------
        and     [eth_rx_data_len], 0 ; assume no packet received
        movzx   ebp, word[io_addr] ; to be implemented in ETHERNET.INC

  .rx_status_loop:
        ; examine RxStatus
        lea     edx, [ebp + E3C59X_REG_RX_STATUS]
        in      ax, dx
        test    ax, ax
        jz      .finish
        test    ah, 0x80 ; rxIncomplete
        jz      .check_error
        jmp     .finish

  .check_error:
        test    ah, 0x40
        jz      .check_length
        ; discard the top frame received advancing the next one
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, 01000b shl 11
        out     dx, ax
        jmp     .rx_status_loop

  .check_length:
        and     eax, 0x1fff
        cmp     eax, E3C59X_MAX_ETH_PKT_SIZE
        ja      .discard_frame ; frame is too long discard it

  .check_dma:
        push    eax
        ; switch to register window 7
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, E3C59X_SELECT_REGISTER_WINDOW + 7
        out     dx, ax
        ; check for master operation in progress
        lea     edx, [ebp + E3C59X_REG_MASTER_STATUS]
        in      ax, dx
        test    ah, 0x80
        jz      .read_frame ; no DMA for receiving
        pop     eax
        jmp     .finish

  .read_frame:
        ; program buffer address to read in
        lea     edx, [ebp+E3C59X_REG_MASTER_ADDRESS]

if defined E3C59X_LINUX

        mov     eax, e3c59x_rx_buff
        ZeroToDma eax

else

        mov     eax, Ether_buffer

end if

        out     dx, eax
        ; program frame length
        lea     edx, [ebp + E3C59X_REG_MASTER_LEN]
        mov     ax, 1560
        out     dx, ax
        ; start DMA Up
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, 10100b shl 11 ; StartDMAUp
        out     dx, ax

        ; check for master operation in progress

  .dma_loop:
        lea     edx, [ebp + E3C59X_REG_MASTER_STATUS]
        in      ax, dx
        test    ah, 0x80
        jnz     .dma_loop
        ; registrate the received packet length
        pop     eax
        mov     [eth_rx_data_len], ax

        ; discard the top frame received

  .discard_frame:
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, 01000b shl 11
        out     dx, ax

  .finish:
        ; set return value
        cmp     [eth_rx_data_len], 0
        setne   al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc e3c59x_boomerang_poll ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Polls the ethernet card for a received packet
;? Received data, if any, ends up in Ether_buffer
;-----------------------------------------------------------------------------------------------------------------------
;> ebp = io_addr
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0 ; no packet received
;< al = 1 ; packet received
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, edx, ecx, edi, esi, ebp
;-----------------------------------------------------------------------------------------------------------------------
        and     [eth_rx_data_len], 0 ; assume no packet received
        movzx   ebp, word[io_addr] ; to be implemented in ETHERNET.INC
        ; check if packet is uploaded
        mov     eax, [e3c59x_curr_upd]
        test    byte[eax + E3C59X_UPD_PKT_STATUS + 1], 0x80 ; upPktComplete
        jnz     .check_error
        jmp     .finish

        ; packet is uploaded check for any error

  .check_error:
        test    byte[eax + E3C59X_UPD_PKT_STATUS + 1], 0x40 ; upError
        jz      .copy_packet_length
        and     dword[eax + E3C59X_UPD_PKT_STATUS], 0
        jmp     .finish

  .copy_packet_length:
        mov     ecx, [eax + E3C59X_UPD_PKT_STATUS]
        and     ecx, 0x1fff
        cmp     ecx, E3C59X_MAX_ETH_PKT_SIZE
        jbe     .copy_packet
        and     dword[eax + E3C59X_UPD_PKT_STATUS], 0
        jmp     .finish

  .copy_packet:
        push    ecx
        mov     [eth_rx_data_len], cx
        mov     esi, [eax + E3C59X_UPD_UP_FRAG_ADDR]
        DmaToVirt esi
        mov     edi, Ether_buffer
        shr     ecx, 2 ; first copy dword-wise
        rep
        movsd   ; copy the dwords
        pop     ecx
        and     ecx, 3
        rep
        movsb   ; copy the rest bytes
        mov     eax, [e3c59x_curr_upd]
        and     dword[eax + E3C59X_UPD_PKT_STATUS], 0
        VirtToZero eax
        cmp     eax, e3c59x_upd_buff + (E3C59X_NUM_RX_DESC - 1) * E3C59X_UPD_SIZE
        jb      .no_wrap
        ; wrap around
        mov     eax, e3c59x_upd_buff - E3C59X_UPD_SIZE

  .no_wrap:
        add     eax, E3C59X_UPD_SIZE
        ZeroToVirt eax
        mov     [e3c59x_curr_upd], eax

  .finish:
        ; check if the NIC is in the upStall state
        lea     edx, [ebp + E3C59X_REG_UP_PKT_STATUS]
        in      eax, dx
        test    ah, 0x20 ; UpStalled
        jz      .noUpUnStall
        ; issue upUnStall command
        lea     edx, [ebp + E3C59X_REG_COMMAND]
        mov     ax, (110b shl 11) + 1 ; upUnStall
        out     dx, ax

  .noUpUnStall:
        ; set return value
        cmp     [eth_rx_data_len], 0
        setnz   al
        ret
kendp

purge VirtToDma, DmaToVirt, ZeroToVirt, VirtToZero, ZeroToDma, DmaToZero, StringTable
