;;======================================================================================================================
;;///// forcedeth.asm ////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2008-2009 KolibriOS team <http://kolibrios.org/>
;; (c) 2008 shurf <cit.utc@gmail.com>
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
;# * forcedeth.c - linux driver (etherboot project)
;;======================================================================================================================

;**************************************************************************
; forcedeth Register Definitions
;**************************************************************************

PCI_REG_COMMAND                  = 0x04 ; command register

PCI_COMMAND_IO                   = 0x01 ; Enable response in I/O space
PCI_COMMAND_MASTER               = 0x04 ; Enable bus mastering
PCI_LATENCY_TIMER                = 0x0d ; 8 bits

PCI_VENDOR_ID                    = 0x00 ; 16 bit
PCI_REVISION_ID                  = 0x08 ; 8 bits

PCI_BASE_ADDRESS_0               = 0x10 ; 32 bits
PCI_BASE_ADDRESS_1               = 0x14 ; 32 bits
PCI_BASE_ADDRESS_2               = 0x18 ; 32 bits
PCI_BASE_ADDRESS_3               = 0x1c ; 32 bits
PCI_BASE_ADDRESS_4               = 0x20 ; 32 bits
PCI_BASE_ADDRESS_5               = 0x24 ; 32 bits

PCI_BASE_ADDRESS_SPACE_IO        = 0x01
PCI_BASE_ADDRESS_IO_MASK         = not 0x03
PCI_BASE_ADDRESS_MEM_MASK        = not 0x0f

PCI_BASE_ADDRESS_MEM_TYPE_MASK   = 0x06
PCI_BASE_ADDRESS_MEM_TYPE_32     = 0x00 ; 32 bit address
PCI_BASE_ADDRESS_MEM_TYPE_1M     = 0x02 ; Below 1M [obsolete]
PCI_BASE_ADDRESS_MEM_TYPE_64     = 0x04 ; 64 bit address

; NIC specific static variables go here
PCI_DEVICE_ID_NVIDIA_NVENET_1    = 0x01c3
PCI_DEVICE_ID_NVIDIA_NVENET_2    = 0x0066
PCI_DEVICE_ID_NVIDIA_NVENET_4    = 0x0086
PCI_DEVICE_ID_NVIDIA_NVENET_5    = 0x008c
PCI_DEVICE_ID_NVIDIA_NVENET_3    = 0x00d6
PCI_DEVICE_ID_NVIDIA_NVENET_7    = 0x00df
PCI_DEVICE_ID_NVIDIA_NVENET_6    = 0x00e6
PCI_DEVICE_ID_NVIDIA_NVENET_8    = 0x0056
PCI_DEVICE_ID_NVIDIA_NVENET_9    = 0x0057
PCI_DEVICE_ID_NVIDIA_NVENET_10   = 0x0037
PCI_DEVICE_ID_NVIDIA_NVENET_11   = 0x0038
PCI_DEVICE_ID_NVIDIA_NVENET_12   = 0x0268
PCI_DEVICE_ID_NVIDIA_NVENET_13   = 0x0269
PCI_DEVICE_ID_NVIDIA_NVENET_14   = 0x0372
PCI_DEVICE_ID_NVIDIA_NVENET_15   = 0x0373

ETH_DATA_LEN                     = 1500

; rx/tx mac addr + type + vlan + align + slack
RX_NIC_BUFSIZE                   = ETH_DATA_LEN + 64
; even more slack
RX_ALLOC_BUFSIZE                 = ETH_DATA_LEN + 128

NvRegIrqStatus                   = 0x0000
NvRegIrqMask                     = 0x0004
NvRegUnknownSetupReg6            = 0x0008
NvRegPollingInterval             = 0x000c
NvRegMacReset                    = 0x003c
NvRegMisc1                       = 0x0080
NvRegTransmitterControl          = 0x0084
NvRegTransmitterStatus           = 0x0088
NvRegPacketFilterFlags           = 0x008c
NvRegOffloadConfig               = 0x0090
NvRegReceiverControl             = 0x0094
NvRegReceiverStatus              = 0x0098
NvRegRandomSeed                  = 0x009c
NvRegUnknownSetupReg1            = 0x00a0
NvRegUnknownSetupReg2            = 0x00a4
NvRegMacAddrA                    = 0x00a8 ; MAC address low
NvRegMacAddrB                    = 0x00ac ; MAC address high
NvRegMulticastAddrA              = 0x00b0
NvRegMulticastAddrB              = 0x00b4
NvRegMulticastMaskA              = 0x00b8
NvRegMulticastMaskB              = 0x00bc
NvRegPhyInterface                = 0x00c0
NvRegTxRingPhysAddr              = 0x0100
NvRegRxRingPhysAddr              = 0x0104
NvRegRingSizes                   = 0x0108
NvRegUnknownTransmitterReg       = 0x010c
NvRegLinkSpeed                   = 0x0110
NvRegUnknownSetupReg5            = 0x0130
NvRegUnknownSetupReg3            = 0x013c
NvRegTxRxControl                 = 0x0144
NvRegMIIStatus                   = 0x0180
NvRegUnknownSetupReg4            = 0x0184
NvRegAdapterControl              = 0x0188
NvRegMIISpeed                    = 0x018c
NvRegMIIControl                  = 0x0190
NvRegMIIData                     = 0x0194
NvRegWakeUpFlags                 = 0x0200
NvRegPowerState                  = 0x026c
NvRegPowerState2                 = 0x0600

NVREG_UNKSETUP1_VAL              = 0x16070f
NVREG_UNKSETUP2_VAL              = 0x16
NVREG_UNKSETUP3_VAL1             = 0x200010
NVREG_UNKSETUP4_VAL              = 8
NVREG_UNKSETUP5_BIT31            = (1 shl 31)
NVREG_UNKSETUP6_VAL              = 3

NVREG_TXRXCTL_RXCHECK            = 0x0400
NVREG_MIISTAT_ERROR              = 0x0001
NVREG_MIISTAT_MASK               = 0x000f
NVREG_MIISTAT_MASK2              = 0x000f
NVREG_MIICTL_INUSE               = 0x08000
NVREG_MIICTL_WRITE               = 0x00400
NVREG_MIICTL_ADDRSHIFT           = 5

NVREG_MIISPEED_BIT8              = 1 shl 8
NVREG_MIIDELAY                   = 5

NVREG_IRQ_RX_ERROR               = 0x0001
NVREG_IRQ_RX                     = 0x0002
NVREG_IRQ_RX_NOBUF               = 0x0004
NVREG_IRQ_LINK                   = 0x0040
NVREG_IRQ_TIMER                  = 0x0020
NVREG_IRQMASK_WANTED_2           = 0x0147

NVREG_IRQ_RX_ALL                 = NVREG_IRQ_RX_ERROR or NVREG_IRQ_RX or NVREG_IRQ_RX_NOBUF
NVREG_IRQ_TX_ALL                 = 0 ; ???????????
NVREG_IRQ_OTHER_ALL              = NVREG_IRQ_LINK or NVREG_IRQ_TIMER

NVREG_IRQSTAT_MASK               = 0x01ff

NVREG_TXRXCTL_KICK               = 0x0001
NVREG_TXRXCTL_BIT1               = 0x0002
NVREG_TXRXCTL_BIT2               = 0x0004
NVREG_TXRXCTL_IDLE               = 0x0008
NVREG_TXRXCTL_RESET              = 0x0010
NVREG_TXRXCTL_RXCHECK            = 0x0400

NVREG_MCASTADDRA_FORCE           = 0x01

NVREG_MAC_RESET_ASSERT           = 0x0f3

NVREG_MISC1_HD                   = 0x02
NVREG_MISC1_FORCE                = 0x3b0f3c

NVREG_PFF_ALWAYS                 = 0x7f0008
NVREG_PFF_PROMISC                = 0x80
NVREG_PFF_MYADDR                 = 0x20

NVREG_OFFLOAD_HOMEPHY            = 0x601
NVREG_OFFLOAD_NORMAL             = RX_NIC_BUFSIZE

NVREG_RNDSEED_MASK               = 0x00ff
NVREG_RNDSEED_FORCE              = 0x7f00
NVREG_RNDSEED_FORCE2             = 0x2d00
NVREG_RNDSEED_FORCE3             = 0x7400

; NVREG_POLL_DEFAULT is the interval length of the timer source on the nic
; NVREG_POLL_DEFAULT=97 would result in an interval length of 1 ms
NVREG_POLL_DEFAULT               = 970

NVREG_ADAPTCTL_START             = 0x02
NVREG_ADAPTCTL_LINKUP            = 0x04
NVREG_ADAPTCTL_PHYVALID          = 0x40000
NVREG_ADAPTCTL_RUNNING           = 0x100000
NVREG_ADAPTCTL_PHYSHIFT          = 24

NVREG_WAKEUPFLAGS_VAL            = 0x7770

NVREG_POWERSTATE_POWEREDUP       = 0x8000
NVREG_POWERSTATE_VALID           = 0x0100
NVREG_POWERSTATE_MASK            = 0x0003
NVREG_POWERSTATE_D0              = 0x0000
NVREG_POWERSTATE_D1              = 0x0001
NVREG_POWERSTATE_D2              = 0x0002
NVREG_POWERSTATE_D3              = 0x0003

NVREG_POWERSTATE2_POWERUP_MASK   = 0x0f11
NVREG_POWERSTATE2_POWERUP_REV_A3 = 0x0001

NVREG_RCVCTL_START               = 0x01
NVREG_RCVSTAT_BUSY               = 0x01

NVREG_XMITCTL_START              = 0x01

NVREG_LINKSPEED_FORCE            = 0x10000
NVREG_LINKSPEED_10               = 1000
NVREG_LINKSPEED_100              = 100
NVREG_LINKSPEED_1000             = 50

NVREG_RINGSZ_TXSHIFT             = 0
NVREG_RINGSZ_RXSHIFT             = 16

LPA_1000FULL                     = 0x0800

; Link partner ability register.
LPA_SLCT                         = 0x001f ; Same as advertise selector
LPA_10HALF                       = 0x0020 ; Can do 10mbps half-duplex
LPA_10FULL                       = 0x0040 ; Can do 10mbps full-duplex
LPA_100HALF                      = 0x0080 ; Can do 100mbps half-duplex
LPA_100FULL                      = 0x0100 ; Can do 100mbps full-duplex
LPA_100BASE4                     = 0x0200 ; Can do 100mbps 4k packets
LPA_RESV                         = 0x1c00 ; Unused...
LPA_RFAULT                       = 0x2000 ; Link partner faulted
LPA_LPACK                        = 0x4000 ; Link partner acked us
LPA_NPAGE                        = 0x8000 ; Next page bit

MII_READ                         = -1
MII_PHYSID1                      = 0x02 ; PHYS ID 1
MII_PHYSID2                      = 0x03 ; PHYS ID 2
MII_BMCR                         = 0x00 ; Basic mode control register
MII_BMSR                         = 0x01 ; Basic mode status register
MII_ADVERTISE                    = 0x04 ; Advertisement control reg
MII_LPA                          = 0x05 ; Link partner ability reg
MII_SREVISION                    = 0x16 ; Silicon revision
MII_RESV1                        = 0x17 ; Reserved...
MII_NCONFIG                      = 0x1c ; Network interface config

; PHY defines
PHY_OUI_MARVELL                  = 0x5043
PHY_OUI_CICADA                   = 0x03f1
PHYID1_OUI_MASK                  = 0x03ff
PHYID1_OUI_SHFT                  = 6
PHYID2_OUI_MASK                  = 0xfc00
PHYID2_OUI_SHFT                  = 10
PHY_INIT1                        = 0x0f000
PHY_INIT2                        = 0x0e00
PHY_INIT3                        = 0x01000
PHY_INIT4                        = 0x0200
PHY_INIT5                        = 0x0004
PHY_INIT6                        = 0x02000
PHY_GIGABIT                      = 0x0100

PHY_TIMEOUT                      = 0x1
PHY_ERROR                        = 0x2

PHY_100                          = 0x1
PHY_1000                         = 0x2
PHY_HALF                         = 0x100

PHY_RGMII                        = 0x10000000

; desc_ver values:
; This field has two purposes:
; - Newer nics uses a different ring layout. The layout is selected by
;   comparing np->desc_ver with DESC_VER_xy.
; - It contains bits that are forced on when writing to NvRegTxRxControl.
DESC_VER_1                       = 0x0
DESC_VER_2                       = 0x02100 or NVREG_TXRXCTL_RXCHECK

MAC_ADDR_LEN                     = 6

NV_TX_LASTPACKET                 = 1 shl 16
NV_TX_RETRYERROR                 = 1 shl 19
NV_TX_LASTPACKET1                = 1 shl 24
NV_TX_DEFERRED                   = 1 shl 26
NV_TX_CARRIERLOST                = 1 shl 27
NV_TX_LATECOLLISION              = 1 shl 28
NV_TX_UNDERFLOW                  = 1 shl 29
NV_TX_ERROR                      = 1 shl 30
NV_TX_VALID                      = 1 shl 31

NV_TX2_LASTPACKET                = 1 shl 29
NV_TX2_RETRYERROR                = 1 shl 18
NV_TX2_LASTPACKET1               = 1 shl 23
NV_TX2_DEFERRED                  = 1 shl 25
NV_TX2_CARRIERLOST               = 1 shl 26
NV_TX2_LATECOLLISION             = 1 shl 27
NV_TX2_UNDERFLOW                 = 1 shl 28
; error and valid are the same for both
NV_TX2_ERROR                     = 1 shl 30
NV_TX2_VALID                     = 1 shl 31

NV_RX_DESCRIPTORVALID            = 1 shl 16
NV_RX_AVAIL                      = 1 shl 31

NV_RX2_DESCRIPTORVALID           = 1 shl 29

RX_RING                          = 4
TX_RING                          = 2

FLAG_MASK_V1                     = 0xffff0000
FLAG_MASK_V2                     = 0xffffc000
LEN_MASK_V1                      = 0xffffffff xor FLAG_MASK_V1
LEN_MASK_V2                      = 0xffffffff xor FLAG_MASK_V2

; Miscelaneous hardware related defines:
NV_PCI_REGSZ_VER1                = 0x270
NV_PCI_REGSZ_VER2                = 0x604
; various timeout delays: all in usec
NV_TXRX_RESET_DELAY              = 4
NV_TXSTOP_DELAY1                 = 10
NV_TXSTOP_DELAY1MAX              = 500000
NV_TXSTOP_DELAY2                 = 100
NV_RXSTOP_DELAY1                 = 10
NV_RXSTOP_DELAY1MAX              = 500000
NV_RXSTOP_DELAY2                 = 100
NV_SETUP5_DELAY                  = 5
NV_SETUP5_DELAYMAX               = 50000
NV_POWERUP_DELAY                 = 5
NV_POWERUP_DELAYMAX              = 5000
NV_MIIBUSY_DELAY                 = 50
NV_MIIPHY_DELAY                  = 10
NV_MIIPHY_DELAYMAX               = 10000
NV_MAC_RESET_DELAY               = 64
NV_WAKEUPPATTERNS                = 5
NV_WAKEUPMASKENTRIES             = 4

; Advertisement control register.
ADVERTISE_SLCT                   = 0x001f ; Selector bits
ADVERTISE_CSMA                   = 0x0001 ; Only selector supported
ADVERTISE_10HALF                 = 0x0020 ; Try for 10mbps half-duplex
ADVERTISE_10FULL                 = 0x0040 ; Try for 10mbps full-duplex
ADVERTISE_100HALF                = 0x0080 ; Try for 100mbps half-duplex
ADVERTISE_100FULL                = 0x0100 ; Try for 100mbps full-duplex
ADVERTISE_100BASE4               = 0x0200 ; Try for 100mbps 4k packets
ADVERTISE_RESV                   = 0x1c00 ; Unused...
ADVERTISE_RFAULT                 = 0x2000 ; Say we can detect faults
ADVERTISE_LPACK                  = 0x4000 ; Ack link partners response
ADVERTISE_NPAGE                  = 0x8000 ; Next page bit

ADVERTISE_FULL                   = ADVERTISE_100FULL or ADVERTISE_10FULL or ADVERTISE_CSMA
ADVERTISE_ALL                    = ADVERTISE_10HALF or ADVERTISE_10FULL or ADVERTISE_100HALF or ADVERTISE_100FULL

MII_1000BT_CR                    = 0x09
MII_1000BT_SR                    = 0x0a
ADVERTISE_1000FULL               = 0x0200
ADVERTISE_1000HALF               = 0x0100

BMCR_ANRESTART                   = 0x0200 ; Auto negotiation restart
BMCR_ANENABLE                    = 0x1000 ; Enable auto negotiation
BMCR_SPEED100                    = 0x2000 ; Select 100Mbps
BMCR_LOOPBACK                    = 0x4000 ; TXD loopback bits
BMCR_RESET                       = 0x8000 ; Reset the DP83840

; Basic mode status register.
BMSR_ERCAP                       = 0x0001 ; Ext-reg capability
BMSR_JCD                         = 0x0002 ; Jabber detected
BMSR_LSTATUS                     = 0x0004 ; Link status
BMSR_ANEGCAPABLE                 = 0x0008 ; Able to do auto-negotiation
BMSR_RFAULT                      = 0x0010 ; Remote fault detected
BMSR_ANEGCOMPLETE                = 0x0020 ; Auto-negotiation complete
BMSR_RESV                        = 0x07c0 ; Unused...
BMSR_10HALF                      = 0x0800 ; Can do 10mbps, half-duplex
BMSR_10FULL                      = 0x1000 ; Can do 10mbps, full-duplex
BMSR_100HALF                     = 0x2000 ; Can do 100mbps, half-duplex
BMSR_100FULL                     = 0x4000 ; Can do 100mbps, full-duplex
BMSR_100BASE4                    = 0x8000 ; Can do 100mbps, 4k packets

ETH_ALEN                         = 6
ETH_HLEN                         = 2 * ETH_ALEN + 2
ETH_ZLEN                         = 60 ; 60 + 4bytes auto payload for minimum 64bytes frame length

uglobal
  forcedeth_mmio_addr       dd 0 ; memory map physical address
  forcedeth_mmio_size       dd 0 ; size of memory bar
  forcedeth_vendor_id       dw 0 ; Vendor ID
  forcedeth_device_id       dw 0 ; Device ID
  forcedeth_orig_mac0       dd 0 ; MAC
  forcedeth_orig_mac1       dd 0 ; MAC
  forcedeth_mapio_addr      dd 0 ; mapped IO address
  forcedeth_txflags         dd 0
  forcedeth_desc_ver        dd 0
  forcedeth_irqmask         dd 0 ; IRQ-mask
  forcedeth_wolenabled      dd 0 ; WOL
  forcedeth_in_shutdown     dd 0
  forcedeth_cur_rx          dd 0
  forcedeth_refill_rx       dd 0
  forcedeth_phyaddr         dd 0
  forcedeth_phy_oui         dd 0
  forcedeth_gigabit         dd 0
  forcedeth_needs_mac_reset dd 0
  forcedeth_linkspeed       dd 0
  forcedeth_duplex          dd 0
  forcedeth_next_tx         dd 0 ; next TX descriptor number
  forcedeth_nic_tx          dd 0 ; ??? d'nt used ???
  forcedeth_packetlen       dd 0
  forcedeth_nocable         dd 0 ; no cable present
endg

iglobal
  net.forcedeth.vfbtl dd \
    forcedeth_probe, \
    forcedeth_reset, \
    forcedeth_poll, \
    forcedeth_transmit, \
    forcedeth_cable
endg

struct forcedeth_TxDesc
  PacketBuffer dd ?
  FlagLen      dd ?
ends

struct forcedeth_RxDesc
  PacketBuffer dd ?
  FlagLen      dd ?
ends

virtual at eth_data_start
  ; Define the TX Descriptor
  align 256
  forcedeth_tx_ring rb TX_RING * sizeof.forcedeth_TxDesc
  ; Create a static buffer of size RX_BUF_SZ for each
  ; TX Descriptor.  All descriptors point to a
  ; part of this buffer
  align 256
  forcedeth_txb     rb TX_RING * RX_NIC_BUFSIZE

  ; Define the RX Descriptor
  align 256
  forcedeth_rx_ring rb RX_RING * sizeof.forcedeth_RxDesc
  ; Create a static buffer of size RX_BUF_SZ for each
  ; RX Descriptor.  All descriptors point to a
  ; part of this buffer
  align 256
  forcedeth_rxb     rb RX_RING * RX_NIC_BUFSIZE
end virtual

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_reset ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Place the chip (ie, the ethernet card) into a virgin state
;-----------------------------------------------------------------------------------------------------------------------
;# All registers destroyed
;-----------------------------------------------------------------------------------------------------------------------
        ; 1) erase previous misconfiguration
        ; 4.1-1: stop adapter: ignored, 4.3 seems to be overkill

        ; writel(NVREG_MCASTADDRA_FORCE, base + NvRegMulticastAddrA)
        mov     edi, dword[forcedeth_mapio_addr]
        mov     dword[edi + NvRegMulticastAddrA], NVREG_MCASTADDRA_FORCE

        ; writel(0, base + NvRegMulticastAddrB)
        mov     dword[edi + NvRegMulticastAddrB], 0

        ; writel(0, base + NvRegMulticastMaskA)
        mov     dword[edi + NvRegMulticastMaskA], 0

        ; writel(0, base + NvRegMulticastMaskB)
        mov     dword[edi + NvRegMulticastMaskB], 0

        ; writel(0, base + NvRegPacketFilterFlags)
        mov     dword[edi + NvRegPacketFilterFlags], 0

        ; writel(0, base + NvRegTransmitterControl)
        mov     dword[edi + NvRegTransmitterControl], 0

        ; writel(0, base + NvRegReceiverControl)
        mov     dword[edi + NvRegReceiverControl], 0

        ; writel(0, base + NvRegAdapterControl)
        mov     dword[edi + NvRegAdapterControl], 0


        ; 2) initialize descriptor rings
        ; init_ring(nic)
        call    forcedeth_init_ring

        ; writel(0, base + NvRegLinkSpeed)
        mov     dword[edi + NvRegLinkSpeed], 0

        ; writel(0, base + NvRegUnknownTransmitterReg)
        mov     dword[edi + NvRegUnknownTransmitterReg], 0

        ; txrx_reset(nic)
        call    forcedeth_txrx_reset

        ; writel(0, base + NvRegUnknownSetupReg6)
        mov     dword[edi + NvRegUnknownSetupReg6], 0

        ; np->in_shutdown = 0
        mov     dword[forcedeth_in_shutdown], 0


        ; 3) set mac address
        ; writel(mac[0], base + NvRegMacAddrA)
        mov     eax, dword[forcedeth_orig_mac0]
        mov     dword[edi + NvRegMacAddrA], eax

        ; writel(mac[1], base + NvRegMacAddrB)
        mov     eax, dword[forcedeth_orig_mac1]
        mov     dword[edi + NvRegMacAddrB], eax


        ; 4) give hw rings
        ; writel((u32) virt_to_le32desc(&rx_ring[0]), base + NvRegRxRingPhysAddr)
        mov     eax, forcedeth_rx_ring

;       KLog    LOG_DEBUG, "FORCEDETH: rx_ring at 0x%x\n", eax

        sub     eax, OS_BASE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        mov     dword[edi + NvRegRxRingPhysAddr], eax

        ; writel((u32) virt_to_le32desc(&tx_ring[0]), base + NvRegTxRingPhysAddr)
        mov     eax, forcedeth_tx_ring
        sub     eax, OS_BASE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        mov     dword[edi + NvRegTxRingPhysAddr], eax

        ; writel(((RX_RING - 1) << NVREG_RINGSZ_RXSHIFT) + ((TX_RING - 1) << NVREG_RINGSZ_TXSHIFT), base + NvRegRingSizes)
        mov     dword[edi + NvRegRingSizes], ((RX_RING - 1) shl NVREG_RINGSZ_RXSHIFT) + ((TX_RING - 1) shl NVREG_RINGSZ_TXSHIFT)

        ; 5) continue setup
        ; np->linkspeed = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_10
        mov     dword[forcedeth_linkspeed], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_10

        ; np->duplex = 0
        mov     dword[forcedeth_duplex], 0

        ; writel(np->linkspeed, base + NvRegLinkSpeed)
        mov     dword[edi + NvRegLinkSpeed], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_10

        ; writel(NVREG_UNKSETUP3_VAL1, base + NvRegUnknownSetupReg3)
        mov     dword[edi + NvRegUnknownSetupReg3], NVREG_UNKSETUP3_VAL1

        ; writel(np->desc_ver, base + NvRegTxRxControl)
        mov     eax, dword[forcedeth_desc_ver]
        mov     dword[edi + NvRegTxRxControl], eax

        ; pci_push(base)
        call    forcedeth_pci_push

        ; writel(NVREG_TXRXCTL_BIT1 | np->desc_ver, base + NvRegTxRxControl)
        or      eax, NVREG_TXRXCTL_BIT1
        mov     dword[edi + NvRegTxRxControl], eax

        ; reg_delay(NvRegUnknownSetupReg5, NVREG_UNKSETUP5_BIT31, NVREG_UNKSETUP5_BIT31, NV_SETUP5_DELAY, NV_SETUP5_DELAYMAX, "open: SetupReg5, Bit 31 remained off\n")
        push    ebx edx edi ;;;;;;;;;;;;;;;;;;;;;;
        stdcall forcedeth_reg_delay, NvRegUnknownSetupReg5, NVREG_UNKSETUP5_BIT31, NVREG_UNKSETUP5_BIT31, NV_SETUP5_DELAY, NV_SETUP5_DELAYMAX, 0
        pop     edi edx ebx ;;;;;;;;;;;;;;;;;;;;;;

        ; writel(0, base + NvRegUnknownSetupReg4)
        mov     dword[edi + NvRegUnknownSetupReg4], 0

        ; writel(NVREG_MIISTAT_MASK2, base + NvRegMIIStatus)
        mov     dword[edi + NvRegMIIStatus], NVREG_MIISTAT_MASK2


        ; printf("%d-Mbs Link, %s-Duplex\n", np->linkspeed & NVREG_LINKSPEED_10 ? 10 : 100, np->duplex ? "Full" : "Half")

        ; 6) continue setup

        ; writel(NVREG_MISC1_FORCE | NVREG_MISC1_HD, base + NvRegMisc1)
        mov     dword[edi + NvRegMisc1], NVREG_MISC1_FORCE or NVREG_MISC1_HD

        ; writel(readl(base + NvRegTransmitterStatus), base + NvRegTransmitterStatus)
        mov     eax, dword[edi + NvRegTransmitterStatus]
        mov     dword[edi + NvRegTransmitterStatus], eax

        ; writel(NVREG_PFF_ALWAYS, base + NvRegPacketFilterFlags)
        mov     dword[edi + NvRegPacketFilterFlags], NVREG_PFF_ALWAYS

        ; writel(NVREG_OFFLOAD_NORMAL, base + NvRegOffloadConfig)
        mov     dword[edi + NvRegOffloadConfig], NVREG_OFFLOAD_NORMAL

        ; writel(readl(base + NvRegReceiverStatus), base + NvRegReceiverStatus)
        mov     eax, dword[edi + NvRegReceiverStatus]
        mov     dword[edi + NvRegReceiverStatus], eax

        ; Get a random number
        ; i = random()
        push    edi
        stdcall sysfn.get_time ; eax = 0x00SSMMHH (current system time)
        pop     edi

        ; writel(NVREG_RNDSEED_FORCE | (i & NVREG_RNDSEED_MASK), base + NvRegRandomSeed)
        and     eax, NVREG_RNDSEED_MASK
        or      eax, NVREG_RNDSEED_FORCE
        mov     dword[edi + NvRegRandomSeed], eax

        ; writel(NVREG_UNKSETUP1_VAL, base + NvRegUnknownSetupReg1)
        mov     dword[edi + NvRegUnknownSetupReg1], NVREG_UNKSETUP1_VAL

        ; writel(NVREG_UNKSETUP2_VAL, base + NvRegUnknownSetupReg2)
        mov     dword[edi + NvRegUnknownSetupReg2], NVREG_UNKSETUP2_VAL

        ; writel(NVREG_POLL_DEFAULT, base + NvRegPollingInterval)
        mov     dword[edi + NvRegPollingInterval], NVREG_POLL_DEFAULT

        ; writel(NVREG_UNKSETUP6_VAL, base + NvRegUnknownSetupReg6)
        mov     dword[edi + NvRegUnknownSetupReg6], NVREG_UNKSETUP6_VAL

        ; writel((np->phyaddr << NVREG_ADAPTCTL_PHYSHIFT) | NVREG_ADAPTCTL_PHYVALID | NVREG_ADAPTCTL_RUNNING,
        ; base + NvRegAdapterControl)
        mov     eax, [forcedeth_phyaddr]
        shl     eax, NVREG_ADAPTCTL_PHYSHIFT
        or      eax, NVREG_ADAPTCTL_PHYVALID or NVREG_ADAPTCTL_RUNNING
        mov     dword[edi + NvRegAdapterControl], eax

        ; writel(NVREG_MIISPEED_BIT8 | NVREG_MIIDELAY, base + NvRegMIISpeed)
        mov     dword[edi + NvRegMIISpeed], NVREG_MIISPEED_BIT8 or NVREG_MIIDELAY

        ; writel(NVREG_UNKSETUP4_VAL, base + NvRegUnknownSetupReg4)
        mov     dword[edi + NvRegUnknownSetupReg4], NVREG_UNKSETUP4_VAL

        ; writel(NVREG_WAKEUPFLAGS_VAL, base + NvRegWakeUpFlags)
        mov     dword[edi + NvRegWakeUpFlags], NVREG_WAKEUPFLAGS_VAL

        ; i = readl(base + NvRegPowerState)
        mov     eax, dword[edi + NvRegPowerState]

        ; if ((i & NVREG_POWERSTATE_POWEREDUP) == 0)
        test    eax, NVREG_POWERSTATE_POWEREDUP
        jnz     @f
        ; writel(NVREG_POWERSTATE_POWEREDUP | i, base + NvRegPowerState)
        or      eax, NVREG_POWERSTATE_POWEREDUP
        mov     dword[edi + NvRegPowerState], eax

    @@: ; pci_push(base)
        call    forcedeth_pci_push

        ; nv_udelay(10)
        mov     esi, 10
        call    forcedeth_nv_udelay

        ; writel(readl(base + NvRegPowerState) | NVREG_POWERSTATE_VALID, base + NvRegPowerState)
        mov     eax, dword[edi + NvRegPowerState]
        or      eax, NVREG_POWERSTATE_VALID
        mov     dword[edi + NvRegPowerState], eax

        ; ??? disable all interrupts ???
        ; writel(0, base + NvRegIrqMask)
        mov     dword[edi + NvRegIrqMask], 0

;       ; ??? Mask RX interrupts
;       mov     dword[edi + NvRegIrqMask], NVREG_IRQ_RX_ALL
;       ; ??? Mask TX interrupts
;;      mov     dword[edi + NvRegIrqMask], NVREG_IRQ_TX_ALL
;       ; ??? Mask OTHER interrupts
;       mov     dword[edi + NvRegIrqMask], NVREG_IRQ_OTHER_ALL

        ; pci_push(base)
        call    forcedeth_pci_push

        ; writel(NVREG_MIISTAT_MASK2, base + NvRegMIIStatus)
        mov     dword[edi + NvRegMIIStatus], NVREG_MIISTAT_MASK2

        ; writel(NVREG_IRQSTAT_MASK, base + NvRegIrqStatus)
        mov     dword[edi + NvRegIrqStatus], NVREG_IRQSTAT_MASK

        ; pci_push(base)
        call    forcedeth_pci_push


        ; writel(NVREG_MCASTADDRA_FORCE, base + NvRegMulticastAddrA)
        mov     dword[edi + NvRegMulticastAddrA], NVREG_MCASTADDRA_FORCE

        ; writel(0, base + NvRegMulticastAddrB)
        mov     dword[edi + NvRegMulticastAddrB], 0

        ; writel(0, base + NvRegMulticastMaskA)
        mov     dword[edi + NvRegMulticastMaskA], 0

        ; writel(0, base + NvRegMulticastMaskB)
        mov     dword[edi + NvRegMulticastMaskB], 0

        ; writel(NVREG_PFF_ALWAYS | NVREG_PFF_MYADDR, base + NvRegPacketFilterFlags)
        mov     dword[edi + NvRegPacketFilterFlags], NVREG_PFF_ALWAYS or NVREG_PFF_MYADDR

        ; set_multicast(nic)
        call    forcedeth_set_multicast

        ; One manual link speed update: Interrupts are enabled, future link
        ; speed changes cause interrupts and are handled by nv_link_irq().

        ; miistat = readl(base + NvRegMIIStatus)
        mov     eax, dword[edi + NvRegMIIStatus]

        ; writel(NVREG_MIISTAT_MASK, base + NvRegMIIStatus);
        mov     dword[edi + NvRegMIIStatus], NVREG_MIISTAT_MASK

        ; dprintf(("startup: got 0x%hX.\n", miistat));
;;;     KLog    LOG_DEBUG, "FORCEDETH: startup: got 0x%x\n", eax


        ; ret = update_linkspeed(nic)
        call    forcedeth_update_linkspeed
        push    eax

        ; start_tx(nic)
        call    forcedeth_start_tx

        pop     eax

;        if (ret) {
;                //Start Connection netif_carrier_on(dev);
;        } else {
;                printf("no link during initialization.\n");
;        }

        mov     dword[forcedeth_nocable], 0

        test    eax, eax
        jnz     .return
        KLog    LOG_DEBUG, "FORCEDETH: no link during initialization.\n"

        mov     dword[forcedeth_nocable], 1

  .return:
        ; Indicate that we have successfully reset the card
        mov     eax, dword[pci_data]
        mov     dword[eth_status], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_probe ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Searches for an ethernet card, enables it and clears the rx buffer
;? If a card was found, it enables the ethernet -> TCPIP link
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "FORCEDETH: 0x%x 0x%x, 0x%x\n", [io_addr]:8, [pci_bus]:2, [pci_dev]:2

        mov     dword[forcedeth_needs_mac_reset], 0

        ; BEGIN of adjust_pci_device()
        ; read word from PCI-device
        mov     al, 1 ;;;;;;;;;;;;;;2
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_REG_COMMAND
        call    pci_read_reg
        mov     bx, ax ; new command
        or      bx, PCI_COMMAND_MASTER
        or      bx, PCI_COMMAND_IO
        cmp     bx, ax
        je      @f
        ; Enabling PCI-device (make card as bus master)
        KLog    LOG_DEBUG, "FORCEDETH: Updating PCI command 0x%x->0x%x\n", ax, bx
        mov     cx, bx
        mov     al, 1 ;;;;;;;;;;;; 2
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_REG_COMMAND
        call    pci_write_reg

        ; Check latency settings

    @@: ; Get current latency settings from Latency timer register (byte)
        mov     al, 0 ;;;;;;;;;1
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_LATENCY_TIMER
        call    pci_read_reg

        ; see if its at least 32
        cmp     al, 32
        jge     @f
        ; set latency to 32
        KLog    LOG_WARNING, "FORCEDETH: PCI latency timer (CFLT) is unreasonably low at %d.\n", al
        KLog    LOG_WARNING, "FORCEDETH: Setting to 32 clocks.\n"
        mov     cl, 32
        mov     al, 0 ;;;;;;;1
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_LATENCY_TIMER
        call    pci_write_reg
        ; END of adjust_pci_device()

    @@: ; BEGIN of pci_bar_start (addr = pci_bar_start(pci, PCI_BASE_ADDRESS_0))
        mov     al, 2 ; dword
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_BASE_ADDRESS_0
        call    pci_read_reg
        test    eax, PCI_BASE_ADDRESS_SPACE_IO
        jz      @f
        and     eax, PCI_BASE_ADDRESS_IO_MASK
        jmp     .next

    @@: push    eax
        and     eax, PCI_BASE_ADDRESS_MEM_TYPE_MASK
        cmp     eax, PCI_BASE_ADDRESS_MEM_TYPE_64
        jne     .not64
        mov     al, 2 ; dword
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_BASE_ADDRESS_0 + 4
        call    pci_read_reg
        or      eax, eax
        jz      .not64
        KLog    LOG_ERROR, "FORCEDETH: pci_bar_start: Unhandled 64bit BAR\n"
        or      eax, -1
        jmp     .next

  .not64:
        pop     eax
        and     eax, PCI_BASE_ADDRESS_MEM_MASK

  .next:
        ; END of pci_bar_start

        ; addr = eax
        mov     dword[forcedeth_mmio_addr], eax

        ; BEGIN of pci_bar_size (sz = pci_bar_size(pci, PCI_BASE_ADDRESS_0))
        ; Save original bar
        mov     al, 2 ; dword
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_BASE_ADDRESS_0
        call    pci_read_reg
        mov     dword[forcedeth_tmp_start], eax
        ; Compute which bits can be set
        ; (ecx - value to write)
        mov     al, 2 ; dword
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_BASE_ADDRESS_0
        mov     ecx, not 0
        call    pci_write_reg
        mov     al, 2 ; dword
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_BASE_ADDRESS_0
        call    pci_read_reg
        push    eax
        ; Restore the original size
        mov     al, 2 ; dword
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_BASE_ADDRESS_0
        mov     ecx, dword[forcedeth_tmp_start]
        call    pci_write_reg
        ; Find the significant bits
        pop     eax
        test    dword[forcedeth_tmp_start], PCI_BASE_ADDRESS_SPACE_IO
        jz      @f
        and     eax, PCI_BASE_ADDRESS_IO_MASK
        jmp     .next2

    @@: and     eax, PCI_BASE_ADDRESS_MEM_MASK

  .next2:
        ; Find the lowest bit set
        mov     ecx, eax
        sub     eax, 1
        not     eax
        and     ecx, eax
        ; END of pci_bar_start

        mov     dword[forcedeth_mmio_size], ecx

        KLog    LOG_DEBUG, "FORCEDETH: mmio_addr= 0x%x [mmio_size= 0x%x]\n", [forcedeth_mmio_addr]:8, \
                [forcedeth_mmio_size]:8

        ; Get Vendor and Device ID
        mov     al, 2
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_VENDOR_ID
        call    pci_read_reg
        mov     word[forcedeth_vendor_id], ax
        shr     eax, 16
        mov     word[forcedeth_device_id], ax

        KLog    LOG_DEBUG, "FORCEDETH: vendor_id= 0x%x device_id= 0x%x\n", [forcedeth_vendor_id]:4, \
                [forcedeth_device_id]:4

        ; handle different descriptor versions
        mov     eax, dword[forcedeth_device_id]
        cmp     eax, PCI_DEVICE_ID_NVIDIA_NVENET_1
        je      .ver1
        cmp     eax, PCI_DEVICE_ID_NVIDIA_NVENET_2
        je      .ver1
        cmp     eax, PCI_DEVICE_ID_NVIDIA_NVENET_3
        je      .ver1
        mov     dword[forcedeth_desc_ver], DESC_VER_2
        jmp     @f

  .ver1:
        mov     dword[forcedeth_desc_ver], DESC_VER_1

    @@: ; read the mac address
        ; map memory
        stdcall map_io_mem, [forcedeth_mmio_addr], [forcedeth_mmio_size], PG_SW + PG_NOCACHE
        test    eax, eax
        jz      .fail

        mov     dword[forcedeth_mapio_addr], eax
        mov     edi, eax
        mov     eax, dword[edi + NvRegMacAddrA]
        mov     dword[forcedeth_orig_mac0], eax
        mov     edx, dword[edi + NvRegMacAddrB]
        mov     dword[forcedeth_orig_mac1], edx

        ; save MAC-address to global variable node_addr
        mov     dword[node_addr], eax
        mov     word[node_addr + 4], dx

        ; reverse if desired
        cmp     word[forcedeth_device_id], 0x03e5
        jae     .no_reverse_mac
        mov     al, byte[node_addr]
        xchg    al, byte[node_addr + 5]
        mov     byte[node_addr], al
        mov     al, byte[node_addr + 1]
        xchg    al, byte[node_addr + 4]
        mov     byte[node_addr + 4], al
        mov     al, byte[node_addr + 2]
        xchg    al, byte[node_addr + 3]
        mov     byte[node_addr + 3], al

  .no_reverse_mac:
;       KLog    LOG_DEBUG, "FORCEDETH: orig_mac0= 0x%x\n", [forcedeth_orig_mac0]:8
;       KLog    LOG_DEBUG, "FORCEDETH: orig_mac1= 0x%x\n", [forcedeth_orig_mac1]:8
        KLog    LOG_DEBUG, "FORCEDETH: MAC = %x-%x-%x-%x-%x-%x\n", [node_addr + 0]:2, [node_addr + 1]:2, \
                [node_addr + 2]:2, [node_addr + 3]:2, [node_addr + 4]:2, [node_addr + 5]:2

        ; disable WOL
        mov     edi, dword[forcedeth_mapio_addr]
        mov     dword[edi + NvRegWakeUpFlags], 0
        mov     dword[forcedeth_wolenabled], 0

        mov     dword[forcedeth_txflags], NV_TX2_LASTPACKET or NV_TX2_VALID
        cmp     dword[forcedeth_desc_ver], DESC_VER_1
        jne     @f
        mov     dword[forcedeth_txflags], NV_TX_LASTPACKET or NV_TX_VALID

    @@: ; BEGIN of switch (pci->dev_id)
        cmp     word[forcedeth_device_id], 0x01c3
        jne     .next_0x0066
        ; nforce
        mov     dword[forcedeth_irqmask], 0 ;;;;;;;;;;;;;;; (NVREG_IRQMASK_WANTED_2 or NVREG_IRQ_TIMER)
        jmp     .end_switch

  .next_0x0066:
        cmp     word[forcedeth_device_id], 0x0066
        je      @f
        cmp     word[forcedeth_device_id], 0x00d6
        je      @f
        jmp     .next_0x0086

    @@: mov     dword[forcedeth_irqmask], 0 ;;;;;;;;;;;;;;;; (NVREG_IRQMASK_WANTED_2 or NVREG_IRQ_TIMER)
        cmp     dword[forcedeth_desc_ver], DESC_VER_1
        jne     @f
        or      dword[forcedeth_txflags], NV_TX_LASTPACKET1
        jmp     .end_switch

    @@: or      dword[forcedeth_txflags], NV_TX2_LASTPACKET1
        jmp     .end_switch

  .next_0x0086:
        cmp     word[forcedeth_device_id], 0x0086
        je      @f
        cmp     word[forcedeth_device_id], 0x008c
        je      @f
        cmp     word[forcedeth_device_id], 0x00e6
        je      @f
        cmp     word[forcedeth_device_id], 0x00df
        je      @f
        cmp     word[forcedeth_device_id], 0x0056
        je      @f
        cmp     word[forcedeth_device_id], 0x0057
        je      @f
        cmp     word[forcedeth_device_id], 0x0037
        je      @f
        cmp     word[forcedeth_device_id], 0x0038
        je      @f
        jmp     .next_0x0268

    @@: ; np->irqmask = NVREG_IRQMASK_WANTED_2;
        ; np->irqmask |= NVREG_IRQ_TIMER;
        mov     dword[forcedeth_irqmask], 0 ;;;;;;;;;;;;;;;; (NVREG_IRQMASK_WANTED_2 or NVREG_IRQ_TIMER)

        ; if (np->desc_ver == DESC_VER_1)
        cmp     dword[forcedeth_desc_ver], DESC_VER_1
        jne     @f
        ;  np->tx_flags |= NV_TX_LASTPACKET1;
        or      dword[forcedeth_txflags], NV_TX_LASTPACKET1
        jmp     .end_switch

    @@: ; else
        ;  np->tx_flags |= NV_TX2_LASTPACKET1;
        or      dword[forcedeth_txflags], NV_TX2_LASTPACKET1

        ; break;
        jmp     .end_switch

  .next_0x0268:
;       cmp     word[forcedeth_device_id], 0x0268
;       je      @f
;       cmp     word[forcedeth_device_id], 0x0269
;       je      @f
;       cmp     word[forcedeth_device_id], 0x0372
;       je      @f
;       cmp     word[forcedeth_device_id], 0x0373
;       je      @f
;       jmp     .default_switch

;   @@:
        cmp     word[forcedeth_device_id], 0x0268
        jb      .default_switch
        ; pci_read_config_byte(pci, PCI_REVISION_ID, &revision_id);
        mov     al, 0 ; byte
        mov     bh, [pci_dev]
        mov     ah, [pci_bus]
        mov     bl, PCI_REVISION_ID
        call    pci_read_reg
        mov     ecx, eax ; cl = revision_id

        ; take phy and nic out of low power mode
        ; powerstate = readl(base + NvRegPowerState2);
        mov     edi, dword[forcedeth_mapio_addr]
        mov     eax, dword[edi + NvRegPowerState2] ; eax = powerstate

        ; powerstate &= ~NVREG_POWERSTATE2_POWERUP_MASK;
        and     eax, not NVREG_POWERSTATE2_POWERUP_MASK

        ; if ((pci->dev_id==PCI_DEVICE_ID_NVIDIA_NVENET_12||pci->dev_id==PCI_DEVICE_ID_NVIDIA_NVENET_13)&&revision_id>=0xA3)
        cmp     dword[forcedeth_device_id], PCI_DEVICE_ID_NVIDIA_NVENET_12
        je      @f
        cmp     dword[forcedeth_device_id], PCI_DEVICE_ID_NVIDIA_NVENET_13
        je      @f
        jmp     .end_if

    @@: cmp     cl, 0xa3
        jl      .end_if
        ;     powerstate |= NVREG_POWERSTATE2_POWERUP_REV_A3;
        or      eax, NVREG_POWERSTATE2_POWERUP_REV_A3

  .end_if:
        ; writel(powerstate, base + NvRegPowerState2);
        mov     dword[edi + NvRegPowerState2], eax

        ; //DEV_NEED_LASTPACKET1|DEV_IRQMASK_2|DEV_NEED_TIMERIRQ
        ; np->irqmask = NVREG_IRQMASK_WANTED_2;
        ; np->irqmask |= NVREG_IRQ_TIMER;
        mov     dword[forcedeth_irqmask], 0 ;;;;;;;;;;;;;;;; (NVREG_IRQMASK_WANTED_2 or NVREG_IRQ_TIMER)

        ; needs_mac_reset = 1;
        mov     dword[forcedeth_needs_mac_reset], 1

        ; if (np->desc_ver == DESC_VER_1)
        cmp     dword[forcedeth_desc_ver], DESC_VER_1
        jne     @f
        ;   np->tx_flags |= NV_TX_LASTPACKET1;
        or      dword[forcedeth_txflags], NV_TX_LASTPACKET1
        jmp     .end_if2

    @@: ; else
        ;   np->tx_flags |= NV_TX2_LASTPACKET1;
        or      dword[forcedeth_txflags], NV_TX2_LASTPACKET1

  .end_if2:
        ; break;
        jmp     .end_switch

  .default_switch:
        KLog    LOG_WARNING, "FORCEDETH: Your card was undefined in this driver.\n"
        KLog    LOG_WARNING, "FORCEDETH: Review driver_data in Kolibri driver and send a patch\n"

  .end_switch:
        ; END of switch (pci->dev_id)

        ; Find a suitable phy
        mov     dword[forcedeth_tmp_i], 1

  .for_loop:
        ; for (i = 1; i <= 32; i++)
        ; phyaddr = i & 0x1f
        mov     ebx, dword[forcedeth_tmp_i]
        and     ebx, 0x1f

        ; id1 = mii_rw(phyaddr, MII_PHYSID1, MII_READ)
        ;EBX - addr, EAX - miireg, ECX - value
        mov     eax, MII_PHYSID1
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; id1 = eax

        ; if (id1 < 0 || id1 == 0xffff)
        cmp     eax, 0xffffffff
        je      .continue_for
        test    eax, 0x80000000
        jnz     .continue_for
        mov     dword[forcedeth_tmp_id1], eax

        ; id2 = mii_rw(nic, phyaddr, MII_PHYSID2, MII_READ)
        mov     eax, MII_PHYSID2
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; id2 = eax

        ; if (id2 < 0 || id2 == 0xffff)
        cmp     eax, 0xffffffff
        je      .continue_for
        test    eax, 0x80000000
        jnz     .continue_for
        mov     dword[forcedeth_tmp_id2], eax

        jmp     .break_for

  .continue_for:
        inc     dword[forcedeth_tmp_i]
        cmp     dword[forcedeth_tmp_i], 32
        jle     .for_loop
        jmp     .end_for

  .break_for:
;;;;    KLog    LOG_DEBUG, "FORCEDETH: id1=0x%x id2=0x%x\n", [forcedeth_tmp_id1]:8, [forcedeth_tmp_id2]:8

        ; id1 = (id1 & PHYID1_OUI_MASK) << PHYID1_OUI_SHFT
        mov     eax, dword[forcedeth_tmp_id1]
        and     eax, PHYID1_OUI_MASK
        shl     eax, PHYID1_OUI_SHFT
        mov     dword[forcedeth_tmp_id1], eax

        ; id2 = (id2 & PHYID2_OUI_MASK) >> PHYID2_OUI_SHFT
        mov     eax, dword[forcedeth_tmp_id2]
        and     eax, PHYID2_OUI_MASK
        shr     eax, PHYID2_OUI_SHFT
        mov     dword[forcedeth_tmp_id2], eax

        KLog    LOG_DEBUG, "FORCEDETH: Found PHY  0x%x:0x%x at address 0x%x\n", [forcedeth_tmp_id1]:8, \
                [forcedeth_tmp_id2]:8, ebx

        ; np->phyaddr = phyaddr;
        mov     [forcedeth_phyaddr], ebx

        ; np->phy_oui = id1 | id2;
        mov     eax, dword[forcedeth_tmp_id1]
        or      eax, dword[forcedeth_tmp_id2]
        mov     dword[forcedeth_phy_oui], eax

  .end_for:
        ; if (i == 33)
        cmp     dword[forcedeth_tmp_i], 33
        jne     @f
        ; PHY in isolate mode? No phy attached and user wants to
        ; test loopback? Very odd, but can be correct.

        KLog    LOG_WARNING, "FORCEDETH: Could not find a valid PHY.\n"

        jmp     .next3

    @@: ; if (i != 33)
        ; reset it
        call    forcedeth_phy_init

  .next3:
;        dprintf(("%s: forcedeth.c: subsystem: %hX:%hX bound to %s\n",
;                 pci->name, pci->vendor, pci->dev_id, pci->name));
        KLog    LOG_DEBUG, "FORCEDETH: subsystem: 0x%x:0x%x bound to forcedeth\n", [forcedeth_vendor_id]:4, \
                [forcedeth_device_id]:4

;        if(needs_mac_reset) mac_reset(nic);
        cmp     dword[forcedeth_needs_mac_reset], 0
        je      @f
        call    forcedeth_mac_reset

    @@: ; if(!forcedeth_reset(nic)) return 0; // no valid link
        call    forcedeth_reset
        test    eax, eax
        jnz     @f
        mov     eax, 0
        jmp     .return

    @@: ; point to NIC specific routines
        ; dev->disable = forcedeth_disable;
        ; nic->poll = forcedeth_poll;
        ; nic->transmit = forcedeth_transmit;
        ; nic->irq = forcedeth_irq;
        ;;;;;;;;;stdcall attach_int_handler, 11, forcedeth_int_handler, 0

        ; return 1
        mov     eax, 1
        jmp     .return

  .fail:
        mov     eax, 0

  .return:
        ret
kendp

uglobal
  forcedeth_tmp_start        dd ?
  forcedeth_tmp_reg          dd ?
  forcedeth_tmp_i            dd ?
  forcedeth_tmp_id1          dd ?
  forcedeth_tmp_id2          dd ?
  forcedeth_tmp_phyinterface dd ?
  forcedeth_tmp_newls        dd ?
  forcedeth_tmp_newdup       dd ?
  forcedeth_tmp_retval       dd ?
  forcedeth_tmp_control_1000 dd ?
  forcedeth_tmp_lpa          dd ?
  forcedeth_tmp_adv          dd ?
  forcedeth_tmp_len          dd ?
  forcedeth_tmp_valid        dd ?
  forcedeth_tmp_nr           dd ?
  forcedeth_tmp_ptxb         dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_poll ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Polls the ethernet card for a received packet
;? Received data, if any, ends up in Ether_buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     [eth_rx_data_len], 0

        ; ????????????????????????????
        ; ??? Clear events? ???
        mov     edi, dword[forcedeth_mapio_addr]
        mov     dword[edi + NvRegIrqStatus], NVREG_IRQSTAT_MASK
        ; ????????????????????????????

  .top:
        ; i = np->cur_rx % RX_RING
        mov     eax, dword[forcedeth_cur_rx]
        and     eax, (RX_RING - 1)
        mov     dword[forcedeth_tmp_i], eax

        ; Flags = le32_to_cpu(rx_ring[i].FlagLen)
        ; Flags = rx_ring[i].FlagLen
        mov     cl, sizeof.forcedeth_RxDesc
        mul     cl
        add     eax, forcedeth_rx_ring
        mov     ebx, eax
        mov     eax, [ebx + forcedeth_RxDesc.FlagLen]


        ; if (Flags & NV_RX_AVAIL)
        test    eax, NV_RX_AVAIL
        ;   return 0;       /* still owned by hardware, */
        ; still owned by hardware
        jnz     .return0

;;;;;   KLog    LOG_DEBUG, "poll: FlagLen = %x\n", eax

        ; if (np->desc_ver == DESC_VER_1) {
        cmp     dword[forcedeth_desc_ver], DESC_VER_1
        jne     @f
        ;   if (!(Flags & NV_RX_DESCRIPTORVALID))
        test    eax, NV_RX_DESCRIPTORVALID
        ;     return 0;
        jz      .return0
        jmp     .next
        ; } else {

    @@: ;   if (!(Flags & NV_RX2_DESCRIPTORVALID))
        test    eax, NV_RX2_DESCRIPTORVALID
        ;     return 0;
        jz      .return0
        ; }

  .next:
        ; len = nv_descr_getlength(&rx_ring[i], np->desc_ver)
        ; len = rx_ring[i].FlagLen & ((np->desc_ver == DESC_VER_1) ? LEN_MASK_V1 : LEN_MASK_V2);
        ; eax = FlagLen
        cmp     dword[forcedeth_desc_ver], DESC_VER_1
        jne     @f
        and     eax, LEN_MASK_V1
        jmp     .next2

    @@: and     eax, LEN_MASK_V2

  .next2:
;       mov     dword[forcedeth_tmp_len], eax

        ; valid = 1
        mov     dword[forcedeth_tmp_valid], 1

        ; got a valid packet - forward it to the network core
        ; nic->packetlen = len;
        mov     dword[forcedeth_packetlen], eax
        ;
        mov     [eth_rx_data_len], ax
;;;     KLog    LOG_DEBUG, "poll: packet len = 0x%x\n", [forcedeth_packetlen]


        ; memcpy(nic->packet, rxb + (i * RX_NIC_BUFSIZE), nic->packetlen);
        ; Copy packet to system buffer (Ether_buffer)
        ;???? ecx = (len-4)
        mov     ecx, eax
        push    ecx
        shr     ecx, 2

        ; rxb + (i * RX_NIC_BUFSIZE)
        mov     eax, dword[forcedeth_tmp_i]
        mov     bx, RX_NIC_BUFSIZE
        mul     bx
        add     eax, forcedeth_rxb

        mov     esi, eax
        mov     edi, Ether_buffer
        rep
        movsd   ; mov dword from [esi++] to [edi++]
        pop     ecx
        and     ecx, 3 ; copy rest 1-3 bytes
        rep
        movsb

        ; wmb();
        ; ???

        ; np->cur_rx++;
        inc     dword[forcedeth_cur_rx]

        ; if (!valid)
        cmp     dword[forcedeth_tmp_valid], 0
        jne     @f
        ;   goto top;
        jmp     .top

    @@: ; alloc_rx(nic);
        call    forcedeth_alloc_rx

        ; return 1;
        jmp     .return1

;;;;;   KLog    LOG_DEBUG, "FORCEDETH: poll: ...\n"

  .return0:
        mov     eax, 0
        jmp     .return

  .return1:
        mov     eax, 1

  .return:
;;      push  eax

        ; ????????????????????????????????????????????????
        ; ????? clear interrupt mask/status
        ; read IRQ status
;;      mov   edi, dword[forcedeth_mapio_addr]
;;      mov   eax, dword[edi + NvRegIrqStatus]

        ; clear events
;;      and   eax, not (NVREG_IRQ_RX_ERROR or NVREG_IRQ_RX or NVREG_IRQ_RX_NOBUF or NVREG_IRQ_LINK or NVREG_IRQ_TIMER)

        ; write IRQ status
;;      mov   dword[edi + NvRegIrqStatus], eax
        ; ????????????????????????????????????????????????

;;      pop   eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_transmit ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Transmits a packet of data via the ethernet card
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to 48 bit destination address
;> bx = type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;-----------------------------------------------------------------------------------------------------------------------
        ; send the packet to destination
;       pusha
;       KLog    LOG_DEBUG, "FORCEDETH: transmit: packet type = 0x%x\n", ebx
;       KLog    LOG_DEBUG, "FORCEDETH: transmit: packet len  = 0x%x\n", ecx
;       mov     eax, dword[edi]
;       KLog    LOG_DEBUG, "FORCEDETH: transmit: dest adr    = 0x%x\n", eax
;       mov     eax, dword[edi + 4]
;       KLog    LOG_DEBUG, "FORCEDETH: transmit: dest adr2   = 0x%x\n", eax
;       mov     eax, dword[node_addr]
;       KLog    LOG_DEBUG, "FORCEDETH: transmit: src  adr    = 0x%x\n", eax
;       mov     eax, dword[node_addr + 4]
;       KLog    LOG_DEBUG, "FORCEDETH: transmit: src adr2    = 0x%x\n", eax
;       popa

        ; int nr = np->next_tx % TX_RING
        mov     eax, dword[forcedeth_next_tx]
        and     eax, TX_RING - 1
        mov     dword[forcedeth_tmp_nr], eax

        ; point to the current txb incase multiple tx_rings are used
        ; ptxb = txb + (nr * RX_NIC_BUFSIZE)
        push    ecx
        mov     cx, RX_NIC_BUFSIZE
        mul     cx ; AX*CX, result to DX:AX
        add     eax, forcedeth_txb
        mov     dword[forcedeth_tmp_ptxb], eax
        push    esi
        mov     esi, edi ; dst MAC
        mov     edi, eax ; packet buffer

        ; copy the packet to ring buffer
        ; memcpy(ptxb, d, ETH_ALEN);      /* dst */
        movsd
        movsw

        ; memcpy(ptxb + ETH_ALEN, nic->node_addr, ETH_ALEN);      /* src */
        mov     esi, node_addr
        movsd
        movsw

        ; nstype = htons((u16) t);        /* type */
        ; memcpy(ptxb + 2 * ETH_ALEN, (u8 *) & nstype, 2);        /* type */
        mov     word[edi], bx
        add     edi, 2

        ; memcpy(ptxb + ETH_HLEN, p, s);
        pop     esi
        pop     ecx
        push    ecx
        shr     ecx, 2 ; count in dwords
        rep
        movsd   ; copy dwords from [esi+=4] to [edi+=4]
        pop     ecx
        push    ecx
        and     ecx, 3 ; copy rest 1-3 bytes
        rep
        movsb   ; copy bytess from [esi++] to [edi++]


        ; s += ETH_HLEN;
        ; while (s < ETH_ZLEN)    /* pad to min length */
        ;  ptxb[s++] = '\0';
        ; pad to min length
        pop     ecx
        add     ecx, ETH_HLEN
        push    ecx ; header length + data length
        cmp     ecx, ETH_ZLEN
        jge     @f
        mov     eax, ETH_ZLEN
        sub     eax, ecx
        xchg    eax, ecx
        mov     al, 0
        rep
        stosb   ; copy byte from al to [edi++]

    @@: ; tx_ring[nr].PacketBuffer = (u32) virt_to_le32desc(ptxb);
        mov     eax, dword[forcedeth_tmp_nr]
        mov     cl, sizeof.forcedeth_TxDesc
        mul     cl
        add     eax, forcedeth_tx_ring
        mov     ebx, eax
        mov     eax, dword[forcedeth_tmp_ptxb]
        sub     eax, OS_BASE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        mov     [ebx + forcedeth_TxDesc.PacketBuffer], eax

;       KLog    LOG_DEBUG, "FORCEDETH: transmit: PacketBuffer = 0x%x\n", eax
;       KLog    LOG_DEBUG, "FORCEDETH: transmit: txflags = 0x%x\n", [forcedeth_txflags]:8

        ; wmb();
        ; tx_ring[nr].FlagLen = cpu_to_le32((s - 1) | np->tx_flags);
        pop     eax ; header length + data length
        mov     ecx, dword[forcedeth_txflags]
        or      eax, ecx
        mov     [ebx + forcedeth_TxDesc.FlagLen], eax

        ; writel(NVREG_TXRXCTL_KICK | np->desc_ver, base + NvRegTxRxControl);
        mov     edi, dword[forcedeth_mapio_addr]
        mov     eax, dword[forcedeth_desc_ver]
        or      eax, NVREG_TXRXCTL_KICK
        mov     dword[edi + NvRegTxRxControl], eax

        ; pci_push(base);
        call    forcedeth_pci_push

        ; np->next_tx++
        inc     dword[forcedeth_next_tx] ; may be need to reset? Overflow?

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_cable ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0, cable is not connected
;< al = 1, cable is connected
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 1
        cmp     dword[forcedeth_nocable], 1
        jne     .return
        mov     al, 0

  .return:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_mii_rw ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? read/write a register on the PHY.
;? Caller must guarantee serialization
;-----------------------------------------------------------------------------------------------------------------------
;> eax = miireg
;> ebx = addr
;> ecx = value
;-----------------------------------------------------------------------------------------------------------------------
;< eax = retval
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    eax ; save miireg
        ; writel(NVREG_MIISTAT_MASK, base + NvRegMIIStatus)
        mov     edi, dword[forcedeth_mapio_addr]
        mov     dword[edi + NvRegMIIStatus], NVREG_MIISTAT_MASK

        ; reg = readl(base + NvRegMIIControl)
        mov     eax, dword[edi + NvRegMIIControl]
        test    eax, NVREG_MIICTL_INUSE
        jz      @f
        ; writel(NVREG_MIICTL_INUSE, base + NvRegMIIControl)
        mov     dword[edi + NvRegMIIControl], NVREG_MIICTL_INUSE
        ; nv_udelay(NV_MIIBUSY_DELAY)
        mov     esi, NV_MIIBUSY_DELAY
        call    forcedeth_nv_udelay

    @@: ; reg = (addr << NVREG_MIICTL_ADDRSHIFT) | miireg
        pop     edx ; restore miireg
        mov     eax, ebx
        shl     eax, NVREG_MIICTL_ADDRSHIFT
        or      eax, edx
        mov     dword[forcedeth_tmp_reg], eax

        cmp     ecx, MII_READ
        je      @f
        ; writel(value, base + NvRegMIIData)
        mov     dword[edi + NvRegMIIData], ecx
        ; reg |= NVREG_MIICTL_WRITE
        or      dword[forcedeth_tmp_reg], NVREG_MIICTL_WRITE

    @@: ; writel(reg, base + NvRegMIIControl)
        mov     eax, dword[forcedeth_tmp_reg]
        mov     dword[edi + NvRegMIIControl], eax

        push    ebx edx edi ;;;;;;;;;;;;;;;;;;;;;;

        ; reg_delay(NvRegMIIControl, NVREG_MIICTL_INUSE, 0, NV_MIIPHY_DELAY, NV_MIIPHY_DELAYMAX, NULL)
        stdcall forcedeth_reg_delay, NvRegMIIControl, NVREG_MIICTL_INUSE, 0, NV_MIIPHY_DELAY, NV_MIIPHY_DELAYMAX, 0

        pop     edi edx ebx ;;;;;;;;;;;;;;;;;;;;;;

        test    eax, eax
        jz      @f
;;;     KLog    LOG_DEBUG, "FORCEDETH: mii_rw of reg %d at PHY %d timed out.\n", edx, ebx
        mov     eax, 0xffffffff
        jmp     .return

    @@: cmp     ecx, MII_READ
        je      @f
        ; it was a write operation - fewer failures are detectable
;;;     KLog    LOG_DEBUG, "FORCEDETH: mii_rw wrote 0x%x to reg %d at PHY %d\n", ecx, edx, ebx
        mov     eax, 0
        jmp     .return

    @@: ; readl(base + NvRegMIIStatus)
        mov     eax, dword[edi + NvRegMIIStatus]
        test    eax, NVREG_MIISTAT_ERROR
        jz      @f
;;;     KLog    LOG_DEBUG, "FORCEDETH: mii_rw of reg %d at PHY %d failed.\n", edx, ebx
        mov     eax, 0xffffffff
        jmp     .return

    @@: ; retval = readl(base + NvRegMIIData)
        mov     eax, dword[edi + NvRegMIIData]
;;;     KLog    LOG_DEBUG, "FORCEDETH: mii_rw read from reg %d at PHY %d: 0x%x.\n", edx, ebx, eax

  .return:
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_nv_udelay ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi = delay
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        cmp     dword[forcedeth_in_shutdown], 0
        jne     @f
        call    forcedeth_udelay ; delay on ESI
        jmp     .return

    @@:

  .loop:
        cmp     esi, 0
        je      .return
        ; Don't allow an rx_ring overflow to happen
        ; while shutting down the NIC it will
        ; kill the receive function.

        call    forcedeth_drop_rx
        mov     ebx, 3 ; sleep = 3
        cmp     ebx, esi ; if(sleep > delay)
        jle     @f
        mov     ebx, esi ; sleep = delay

    @@: push    esi
        mov     esi, ebx
        ; udelay(sleep)
        call    forcedeth_udelay ; delay on ESI
        pop     esi
        sub     esi, ebx ; delay -= sleep
        jmp     .loop

  .return:
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_drop_rx ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx edi

        ; events = readl(base + NvRegIrqStatus)
        mov     edi, dword[forcedeth_mapio_addr]
        mov     eax, dword[edi + NvRegIrqStatus]

        test    eax, eax
        jz      @f
        ; writel(events, base + NvRegIrqStatus)
        mov     dword[edi + NvRegIrqStatus], eax

    @@: ; if (!(events & (NVREG_IRQ_RX_ERROR|NVREG_IRQ_RX|NVREG_IRQ_RX_NOBUF)))
        test    eax, NVREG_IRQ_RX_ERROR or NVREG_IRQ_RX or NVREG_IRQ_RX_NOBUF
        jz      .return

  .loop:
        ; i = np->cur_rx % RX_RING
        mov     eax, dword[forcedeth_cur_rx]
        and     eax, RX_RING - 1
        ; //Flags = le32_to_cpu(rx_ring[i].FlagLen)
        ; Flags = rx_ring[i].FlagLen
        mov     cl, sizeof.forcedeth_RxDesc
        mul     cl
        add     eax, forcedeth_rx_ring
        mov     ebx, eax
        mov     eax, [ebx + forcedeth_RxDesc.FlagLen]
        ; len = nv_descr_getlength(&rx_ring[i], np->desc_ver)
        ; > len = Flags & ((np->desc_ver == DESC_VER_1) ? LEN_MASK_V1 : LEN_MASK_V2)
        ; ??? len don't used later !!! ???
        ; ...
        test    eax, NV_RX_AVAIL
        jnz     .return ; still owned by hardware,
        ; wmb()
        ; ??? may be empty function ???
        ; np->cur_rx++
        inc     dword[forcedeth_cur_rx]
        ; alloc_rx(NULL)
        call    forcedeth_alloc_rx

  .return:
        pop     edi ecx ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_alloc_rx ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Fill rx ring entries.
;? Return 1 if the allocations for the skbs failed and the rx engine is without available descriptors
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx edx
        ; refill_rx = np->refill_rx
        mov     ecx, [forcedeth_refill_rx]

  .loop:
        cmp     [forcedeth_cur_rx], ecx
        je      .loop_end
        ; nr = refill_rx % RX_RING
        mov     eax, ecx
        and     eax, (RX_RING-1) ; nr
        ; rx_ring[nr].PacketBuffer = &rxb[nr * RX_NIC_BUFSIZE]
        push    ecx
        push    eax
        mov     cl, sizeof.forcedeth_RxDesc
        mul     cl
        add     eax, forcedeth_rx_ring
        mov     ebx, eax
        pop     eax
        mov     cx, RX_NIC_BUFSIZE
        mul     cx
        pop     ecx
        add     eax, forcedeth_rxb
        sub     eax, OS_BASE  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        mov     [ebx + forcedeth_RxDesc.PacketBuffer], eax
        ; wmb()
        ; ...
        ; rx_ring[nr].FlagLen = RX_NIC_BUFSIZE | NV_RX_AVAIL
        mov     [ebx + forcedeth_RxDesc.FlagLen], (RX_NIC_BUFSIZE or NV_RX_AVAIL)
        inc     ecx
        jmp     .loop

  .loop_end:
        ; np->refill_rx = refill_rx
        mov     [forcedeth_refill_rx], ecx

  .return:
        pop     edx ecx ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_udelay ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Delay in millisec
;-----------------------------------------------------------------------------------------------------------------------
;> esi = delay in ms
;-----------------------------------------------------------------------------------------------------------------------
        call    delay_ms
        ret
kendp

;;;;proc forcedeth_reg_delay, offset:word, mask:dword, target:dword, delay:word, delaymax:word, msg:dword
;-----------------------------------------------------------------------------------------------------------------------
proc forcedeth_reg_delay, offset:dword, mask:dword, target:dword, delay:dword, delaymax:dword, msg:dword ;//////////////
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0|1
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx esi edi
        ; pci_push(base)
        call    forcedeth_pci_push

  .loop:
        ; nv_udelay(delay)
        mov     esi, dword[delay]
        call    forcedeth_nv_udelay ; delay in esi
        mov     eax, dword[delaymax]
        sub     eax, dword[delay]
        mov     dword[delaymax], eax
        ; if (delaymax < 0)
        test    dword[delaymax], 0x80000000
        jz      @f
        ; return 1
        mov     eax, 1
        jmp     .return

    @@: ; while ((readl(base + offset) & mask) != target)
        mov     edi, dword[forcedeth_mapio_addr]
        mov     ebx, dword[offset]
        mov     eax, dword[edi + ebx]
        and     eax, dword[mask]
        cmp     eax, dword[target]
        jne     .loop
        xor     eax, eax

  .return:
        pop     edi esi ebx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_pci_push ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edi
        ;force out pending posted writes
        mov     edi, [forcedeth_mapio_addr]
        mov     eax, [edi]
        pop     edi eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_phy_init ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx

        ; set advertise register
        ; reg = mii_rw(nic, np->phyaddr, MII_ADVERTISE, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_ADVERTISE
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; reg = eax

        ; reg |=
        ; (ADVERTISE_10HALF | ADVERTISE_10FULL | ADVERTISE_100HALF |
        ;  ADVERTISE_100FULL | 0x800 | 0x400);
        or      eax, ADVERTISE_10HALF or ADVERTISE_10FULL or ADVERTISE_100HALF or ADVERTISE_100FULL or 0x800 or 0x400

        ; if (mii_rw(nic, np->phyaddr, MII_ADVERTISE, reg))
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ecx, eax ; reg
        mov     eax, MII_ADVERTISE
        call    forcedeth_mii_rw ; eax -> return

        test    eax, eax
        jz      @f
        ; printf("phy write to advertise failed.\n");
        KLog    LOG_ERROR, "FORCEDETH: phy write to advertise failed.\n"

        ; return PHY_ERROR;
        mov     eax, PHY_ERROR
        jmp     .return

    @@: ; get phy interface type
        ; phyinterface = readl(base + NvRegPhyInterface);
        mov     edi, dword[forcedeth_mapio_addr]
        mov     eax, dword[edi + NvRegPhyInterface] ; phyinterface = eax
        mov     dword[forcedeth_tmp_phyinterface], eax

        ;;;;;;;;;;;;;;;;;;;;;;;;;
        KLog    LOG_DEBUG, "FORCEDETH: phy interface type = 0x%x\n", [forcedeth_tmp_phyinterface]:8
        ;;;;;;;;;;;;;;;;;;;;;;;;;

        ; see if gigabit phy
        ; mii_status = mii_rw(nic, np->phyaddr, MII_BMSR, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
        mov     eax, MII_BMSR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; mii_status = eax

        ; if (mii_status & PHY_GIGABIT)
        test    eax, PHY_GIGABIT
        jnz     .gigabit
        ; np->gigabit = 0;
        mov     dword[forcedeth_gigabit], 0
        jmp     .next_if

  .gigabit:
        ; np->gigabit = PHY_GIGABIT;
        mov     dword[forcedeth_gigabit], PHY_GIGABIT

        ; mii_control_1000 =  mii_rw(nic, np->phyaddr, MII_1000BT_CR, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
        mov     eax, MII_1000BT_CR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; mii_control_1000 = eax

        ; mii_control_1000 &= ~ADVERTISE_1000HALF;
        and     eax, not ADVERTISE_1000HALF

        ; if (phyinterface & PHY_RGMII)
        test    dword[forcedeth_tmp_phyinterface], PHY_RGMII
        jz      @f
        ; mii_control_1000 |= ADVERTISE_1000FULL
        or      eax, ADVERTISE_1000FULL
        jmp     .next

    @@: ; mii_control_1000 &= ~ADVERTISE_1000FULL
        and     eax, not ADVERTISE_1000FULL

  .next:
        ; if (mii_rw(nic, np->phyaddr, MII_1000BT_CR, mii_control_1000))
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ecx, eax
        mov     eax, MII_1000BT_CR
        call    forcedeth_mii_rw ; eax -> return

        test    eax, eax
        jz      .next_if

        ; printf("phy init failed.\n");
        KLog    LOG_ERROR, "FORCEDETH: phy init failed.\n"

        ; return PHY_ERROR;
        mov     eax, PHY_ERROR
        jmp     .return

  .next_if:
        ; reset the phy
        ; if (phy_reset(nic))
        call    forcedeth_phy_reset
        test    eax, eax
        jz      @f
        ; printf("phy reset failed\n")
        KLog    LOG_ERROR, "FORCEDETH: phy reset failed.\n"
        ; return PHY_ERROR
        mov     eax, PHY_ERROR
        jmp     .return

    @@: ; phy vendor specific configuration
        ; if ((np->phy_oui == PHY_OUI_CICADA) && (phyinterface & PHY_RGMII))
        cmp     dword[forcedeth_phy_oui], PHY_OUI_CICADA
        jne     .next_if2
        test    dword[forcedeth_tmp_phyinterface], PHY_RGMII
        jz      .next_if2

        ; phy_reserved = mii_rw(nic, np->phyaddr, MII_RESV1, MII_READ)
        ; EBX - addr, EAX - miireg, ECX - value
        mov     eax, MII_RESV1
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; phy_reserved = eax

        ; phy_reserved &= ~(PHY_INIT1 | PHY_INIT2)
        and     eax, not (PHY_INIT1 or PHY_INIT2)
        ; phy_reserved |= (PHY_INIT3 | PHY_INIT4)
        or      eax, PHY_INIT3 or PHY_INIT4

        ; if (mii_rw(nic, np->phyaddr, MII_RESV1, phy_reserved))
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ecx, eax
        mov     eax, MII_RESV1
        call    forcedeth_mii_rw ; eax -> return
        test    eax, eax
        jz      @f
        ; printf("phy init failed.\n")
        KLog    LOG_ERROR, "FORCEDETH: phy init failed.\n"
        ; return PHY_ERROR
        mov     eax, PHY_ERROR
        jmp     .return

    @@: ; phy_reserved = mii_rw(nic, np->phyaddr, MII_NCONFIG, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
        mov     eax, MII_NCONFIG
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; phy_reserved = eax

        ; phy_reserved |= PHY_INIT5
        or      eax, PHY_INIT5

        ; if (mii_rw(nic, np->phyaddr, MII_NCONFIG, phy_reserved))
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ecx, eax
        mov     eax, MII_NCONFIG
        call    forcedeth_mii_rw ; eax -> return
        test    eax, eax
        jz      .next_if2
        ; printf("phy init failed.\n")
        KLog    LOG_ERROR, "FORCEDETH: phy init failed.\n"
        ; return PHY_ERROR
        mov     eax, PHY_ERROR
        jmp     .return

  .next_if2:
        ; if (np->phy_oui == PHY_OUI_CICADA)
        cmp     dword[forcedeth_phy_oui], PHY_OUI_CICADA
        jne     .restart

        ; phy_reserved = mii_rw(nic, np->phyaddr, MII_SREVISION, MII_READ)
        ; EBX - addr, EAX - miireg, ECX - value
        mov     eax, MII_SREVISION
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; phy_reserved = eax

        ; phy_reserved |= PHY_INIT6
        or      eax, PHY_INIT6

        ; if (mii_rw(nic, np->phyaddr, MII_SREVISION, phy_reserved))
        mov     ecx, eax
        mov     eax, MII_SREVISION
        call    forcedeth_mii_rw ; eax -> return
        test    eax, eax
        jz      .restart
        ; printf("phy init failed.\n");
        KLog    LOG_ERROR, "FORCEDETH: phy init failed.\n"
        ; return PHY_ERROR;
        jmp     .return

  .restart:
        ; restart auto negotiation
        ; mii_control = mii_rw(nic, np->phyaddr, MII_BMCR, MII_READ)
        ; EBX - addr, EAX - miireg, ECX - value
        mov     eax, MII_BMCR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; mii_control = eax

        ; mii_control |= (BMCR_ANRESTART | BMCR_ANENABLE)
        or      eax, BMCR_ANRESTART or BMCR_ANENABLE

        ; if (mii_rw(nic, np->phyaddr, MII_BMCR, mii_control))
        mov     ecx, eax
        mov     eax, MII_BMCR
        call    forcedeth_mii_rw ; eax -> return
        test    eax, eax
        jz      .ok

        ; return PHY_ERROR;
        mov     eax, PHY_ERROR
        jmp     .return

  .ok:
        mov     eax, 0

  .return:
        pop     ecx ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_phy_reset ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx edx

        ; miicontrol = mii_rw(nic, np->phyaddr, MII_BMCR, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_BMCR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; miicontrol = eax

        ; miicontrol |= BMCR_RESET;
        or      eax, BMCR_RESET
        push    eax

        ; if (mii_rw(nic, np->phyaddr, MII_BMCR, miicontrol))
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ecx, eax
        mov     eax, MII_BMCR
        call    forcedeth_mii_rw ; miicontrol = eax

        test    eax, eax
        jz      @f
        pop     eax
        mov     eax, 0xffffffff
        jmp     .return

    @@: pop     eax

        ; wait for 500ms
        ; mdelay(500)
        mov     esi, 500
        call    forcedeth_udelay

        ; must wait till reset is deasserted
        ; while (miicontrol & BMCR_RESET) {
        mov     edx, 100

  .while_loop:
        test    eax, BMCR_RESET
        jz      .while_loop_exit

        ; mdelay(10);
        mov     esi, 10
        call    forcedeth_udelay

        ; miicontrol = mii_rw(nic, np->phyaddr, MII_BMCR, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
        mov     eax, MII_BMCR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; miicontrol = eax

        ; FIXME: 100 tries seem excessive
        ; if (tries++ > 100)
        dec     edx
        jnz     .while_loop
        ; return -1;
        mov     eax, -1
        jmp     .return

  .while_loop_exit:
        ; return 0
        mov     eax, 0

  .return:
        pop     edx ecx ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_mac_reset ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi

        ; dprintf("mac_reset\n")
        KLog    LOG_DEBUG, "FORCEDETH: mac_reset.\n"

        ; writel(NVREG_TXRXCTL_BIT2 | NVREG_TXRXCTL_RESET | np->desc_ver, base + NvRegTxRxControl)
        mov     edi, dword[forcedeth_mapio_addr]
        mov     eax, dword[forcedeth_desc_ver]
        or      eax, NVREG_TXRXCTL_BIT2 or NVREG_TXRXCTL_RESET
        mov     dword[edi + NvRegTxRxControl], eax

        ; pci_push(base)
        call    forcedeth_pci_push

        ; writel(NVREG_MAC_RESET_ASSERT, base + NvRegMacReset)
        mov     dword[edi + NvRegMacReset], NVREG_MAC_RESET_ASSERT

        ; pci_push(base)
        call    forcedeth_pci_push

        ; udelay(NV_MAC_RESET_DELAY)
        mov     esi, NV_MAC_RESET_DELAY
        call    forcedeth_nv_udelay

        ; writel(0, base + NvRegMacReset)
        mov     dword[edi + NvRegMacReset], 0

        ; pci_push(base)
        call    forcedeth_pci_push

        ; udelay(NV_MAC_RESET_DELAY)
        mov     esi, NV_MAC_RESET_DELAY
        call    forcedeth_nv_udelay

        ; writel(NVREG_TXRXCTL_BIT2 | np->desc_ver, base + NvRegTxRxControl)
        mov     eax, dword[forcedeth_desc_ver]
        or      eax, NVREG_TXRXCTL_BIT2
        mov     dword[edi + NvRegTxRxControl], eax

        ; pci_push(base)
        call    forcedeth_pci_push

        pop     edi esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_init_ring ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx

        ; np->next_tx = np->nic_tx = 0
        mov     dword[forcedeth_next_tx], 0
        mov     dword[forcedeth_nic_tx], 0

        ; for (i = 0; i < TX_RING; i++)
        mov     ecx, TX_RING

  .for_loop:
        ;        tx_ring[i].FlagLen = 0;
        mov     eax, ecx
        dec     eax
        mov     bl, sizeof.forcedeth_TxDesc
        mul     bl
        add     eax, forcedeth_tx_ring
        mov     ebx, eax
        mov     dword[ebx + forcedeth_TxDesc.FlagLen], 0
        loop    .for_loop

        ; np->cur_rx = RX_RING;
        mov     dword[forcedeth_cur_rx], RX_RING
        ; np->refill_rx = 0;
        mov     dword[forcedeth_refill_rx], 0

        ;for (i = 0; i < RX_RING; i++)
        mov     ecx, RX_RING

  .for_loop2:
        ;        rx_ring[i].FlagLen = 0;
        mov     eax, ecx
        dec     eax
        mov     bl, sizeof.forcedeth_RxDesc
        mul     bl
        add     eax, forcedeth_rx_ring
        mov     ebx, eax
        mov     dword[ebx + forcedeth_RxDesc.FlagLen], 0
        loop    .for_loop2

        ; alloc_rx(nic);
        call    forcedeth_alloc_rx

  .return:
        pop     ecx ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_txrx_reset ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax esi edi

        ; dprintf(("txrx_reset\n"))
        KLog    LOG_DEBUG, "FORCEDETH: txrx_reset.\n"

        ; writel(NVREG_TXRXCTL_BIT2 | NVREG_TXRXCTL_RESET | np->desc_ver, base + NvRegTxRxControl)
        mov     edi, dword[forcedeth_mapio_addr]
        mov     eax, dword[forcedeth_desc_ver]
        or      eax, NVREG_TXRXCTL_BIT2 or NVREG_TXRXCTL_RESET
        mov     dword[edi + NvRegTxRxControl], eax

        ; pci_push(base)
        call    forcedeth_pci_push

        ; nv_udelay(NV_TXRX_RESET_DELAY)
        mov     esi, NV_TXRX_RESET_DELAY
        call    forcedeth_nv_udelay

        ; writel(NVREG_TXRXCTL_BIT2 | np->desc_ver, base + NvRegTxRxControl)
        mov     eax, dword[forcedeth_desc_ver]
        or      eax, NVREG_TXRXCTL_BIT2
        mov     dword[edi + NvRegTxRxControl], eax

        ; pci_push(base)
        call    forcedeth_pci_push

  .return:
        pop     edi esi eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_set_multicast ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edi

        ; u32 addr[2];
        ; u32 mask[2];
        ; u32 pff;
        ; u32 alwaysOff[2];
        ; u32 alwaysOn[2];
        ;
        ; memset(addr, 0, sizeof(addr));
        ; memset(mask, 0, sizeof(mask));
        ;
        ; pff = NVREG_PFF_MYADDR;
        ;
        ; alwaysOn[0] = alwaysOn[1] = alwaysOff[0] = alwaysOff[1] = 0;
        ;
        ; addr[0] = alwaysOn[0];
        ; addr[1] = alwaysOn[1];
        ; mask[0] = alwaysOn[0] | alwaysOff[0];
        ; mask[1] = alwaysOn[1] | alwaysOff[1];
        ;
        ; addr[0] |= NVREG_MCASTADDRA_FORCE;
        ; pff |= NVREG_PFF_ALWAYS;
        ; stop_rx();
        call    forcedeth_stop_rx
        ; writel(addr[0], base + NvRegMulticastAddrA);
        mov     edi, dword[forcedeth_mapio_addr]
        mov     dword[edi + NvRegMulticastAddrA], NVREG_MCASTADDRA_FORCE
        ; writel(addr[1], base + NvRegMulticastAddrB);
        mov     dword[edi + NvRegMulticastAddrB], 0
        ; writel(mask[0], base + NvRegMulticastMaskA);
        mov     dword[edi + NvRegMulticastMaskA], 0
        ; writel(mask[1], base + NvRegMulticastMaskB);
        mov     dword[edi + NvRegMulticastMaskB], 0
        ; writel(pff, base + NvRegPacketFilterFlags);
        mov     dword[edi + NvRegPacketFilterFlags], NVREG_PFF_MYADDR or NVREG_PFF_ALWAYS
        ; start_rx(nic);
        call    forcedeth_start_rx

  .return:
        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_start_rx ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edi

        ; dprintf(("start_rx\n"))
        KLog    LOG_DEBUG, "FORCEDETH: start_rx.\n"

        ; Already running? Stop it.
        ; if (readl(base + NvRegReceiverControl) & NVREG_RCVCTL_START) {
        mov     edi, dword[forcedeth_mapio_addr]
        mov     eax, dword[edi + NvRegReceiverControl]
        test    eax, NVREG_RCVCTL_START
        jz      @f
        ; writel(0, base + NvRegReceiverControl)
        mov     dword[edi + NvRegReceiverControl], 0
        ; pci_push(base)
        call    forcedeth_pci_push

    @@: ; writel(np->linkspeed, base + NvRegLinkSpeed);
        mov     eax, dword[forcedeth_linkspeed]
        mov     dword[edi + NvRegLinkSpeed], eax
        ; pci_push(base);
        call    forcedeth_pci_push
        ; writel(NVREG_RCVCTL_START, base + NvRegReceiverControl);
        mov     dword[edi + NvRegReceiverControl], NVREG_RCVCTL_START
        ; pci_push(base);
        call    forcedeth_pci_push

  .return:
        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_stop_rx ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi

        ; dprintf(("stop_rx\n"))
        KLog    LOG_DEBUG, "FORCEDETH: stop_rx.\n"

        ; writel(0, base + NvRegReceiverControl)
        mov     edi, dword[forcedeth_mapio_addr]
        mov     dword[edi + NvRegReceiverControl], 0

        push    ebx edx edi ;;;;;;;;;;;;;;;;;;;;;;
        ; reg_delay(NvRegReceiverStatus, NVREG_RCVSTAT_BUSY, 0, NV_RXSTOP_DELAY1, NV_RXSTOP_DELAY1MAX, "stop_rx: ReceiverStatus remained busy");
        stdcall forcedeth_reg_delay, NvRegReceiverStatus, NVREG_RCVSTAT_BUSY, 0, NV_RXSTOP_DELAY1, NV_RXSTOP_DELAY1MAX, 0
        pop     edi edx ebx ;;;;;;;;;;;;;;;;;;;;;;


        ; nv_udelay(NV_RXSTOP_DELAY2)
        mov     esi, NV_RXSTOP_DELAY2
        call    forcedeth_nv_udelay

        ; writel(0, base + NvRegLinkSpeed)
        mov     dword[edi + NvRegLinkSpeed], 0

  .return:
        pop     edi esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_update_linkspeed ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< eax
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx ecx esi edi

        ; BMSR_LSTATUS is latched, read it twice:
        ; we want the current value.

        ; mii_rw(nic, np->phyaddr, MII_BMSR, MII_READ)
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_BMSR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw

        ; mii_status = mii_rw(nic, np->phyaddr, MII_BMSR, MII_READ)
        ; EBX - addr, EAX - miireg, ECX - value
        mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_BMSR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; mii_status = eax

        ; yhlu

        ; for(i=0;i<30;i++) {
        mov     ecx, 30

  .for_loop:
        push    ecx

        ;  mii_status = mii_rw(nic, np->phyaddr, MII_BMSR, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
;       mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_BMSR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; mii_status = eax

        ;  if((mii_status & BMSR_LSTATUS) && (mii_status & BMSR_ANEGCOMPLETE)) break;
        test    eax, BMSR_LSTATUS
        jz      @f
        test    eax, BMSR_ANEGCOMPLETE
        jz      @f
        ; break
        pop     ecx
        jmp     .break

    @@: ; mdelay(100);
        push    eax ; ???
        mov     esi, 100
        call    forcedeth_udelay
        pop     eax ; ???

        pop     ecx
        loop    .for_loop

  .break:
        ; if (!(mii_status & BMSR_LSTATUS)) {
        test    eax, BMSR_LSTATUS
        jnz     @f

        ; printf("no link detected by phy - falling back to 10HD.\n")
        KLog    LOG_WARNING, "FORCEDETH: update_linkspeed: no link detected by phy - falling back to 10HD.\n"

        ; newls = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_10
        mov     dword[forcedeth_tmp_newls], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_10

        ; newdup = 0;
        mov     dword[forcedeth_tmp_newdup], 0
        ; retval = 0;
        mov     dword[forcedeth_tmp_retval], 0

        ; goto set_speed;
        jmp     .set_speed

    @@: ; check auto negotiation is complete
        ; if (!(mii_status & BMSR_ANEGCOMPLETE)) {
        test    eax, BMSR_ANEGCOMPLETE
        jnz     @f

        ; still in autonegotiation - configure nic for 10 MBit HD and wait.
        ; newls = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_10
        mov     dword[forcedeth_tmp_newls], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_10

        ; newdup = 0
        mov     dword[forcedeth_tmp_newdup], 0

        ; retval = 0
        mov     dword[forcedeth_tmp_retval], 0

        ; printf("autoneg not completed - falling back to 10HD.\n")
        KLog    LOG_WARNING, "FORCEDETH: update_linkspeed: autoneg not completed - falling back to 10HD.\n"

        ; goto set_speed
        jmp     .set_speed

    @@: ; retval = 1
        mov     dword[forcedeth_tmp_retval], 1

        ; if (np->gigabit == PHY_GIGABIT) {
        cmp     dword[forcedeth_gigabit], PHY_GIGABIT
        jne     .end_if
        ; control_1000 = mii_rw(nic, np->phyaddr, MII_1000BT_CR, MII_READ)
        ; EBX - addr, EAX - miireg, ECX - value
;       mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_1000BT_CR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; control_1000 = eax
        mov     dword[forcedeth_tmp_control_1000], eax

        ; status_1000 = mii_rw(nic, np->phyaddr, MII_1000BT_SR, MII_READ)
        ; EBX - addr, EAX - miireg, ECX - value
;       mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_1000BT_SR
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; status_1000 = eax
;       mov     dword[forcedeth_tmp_status_1000], eax

        ; if ((control_1000 & ADVERTISE_1000FULL) &&
        ;     (status_1000 & LPA_1000FULL)) {
        test    eax, LPA_1000FULL
        jz      .end_if
        test    dword[forcedeth_tmp_control_1000], ADVERTISE_1000FULL
        jz      .end_if

        ; printf ("update_linkspeed: GBit ethernet detected.\n")
        KLog    LOG_DEBUG, "FORCEDETH: update_linkspeed: GBit ethernet detected.\n"

        ; newls = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_1000
        mov     dword[forcedeth_tmp_newls], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_1000

        ; newdup = 1
        mov     dword[forcedeth_tmp_newdup], 1

        ; goto set_speed
        jmp     .set_speed

  .end_if:
        ; adv = mii_rw(nic, np->phyaddr, MII_ADVERTISE, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
;       mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_ADVERTISE
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; adv = eax
        mov     dword[forcedeth_tmp_adv], eax

        ; lpa = mii_rw(nic, np->phyaddr, MII_LPA, MII_READ);
        ; EBX - addr, EAX - miireg, ECX - value
;       mov     ebx, [forcedeth_phyaddr]
        mov     eax, MII_LPA
        mov     ecx, MII_READ
        call    forcedeth_mii_rw ; lpa = eax
        mov     dword[forcedeth_tmp_lpa], eax

        ; dprintf(("update_linkspeed: PHY advertises 0x%hX, lpa 0x%hX.\n", adv, lpa));
        KLog    LOG_DEBUG, "FORCEDETH: update_linkspeed: PHY advertises 0x%x, lpa 0x%x.\n", [forcedeth_tmp_adv]:8, \
                [forcedeth_tmp_lpa]:8

        ; FIXME: handle parallel detection properly, handle gigabit ethernet
        ; lpa = lpa & adv
        mov     eax, dword[forcedeth_tmp_adv]
        and     dword[forcedeth_tmp_lpa], eax

        mov     eax, dword[forcedeth_tmp_lpa]

        ; if (lpa & LPA_100FULL) {
        test    eax, LPA_100FULL
        jz      @f
        ; newls = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_100
        mov     dword[forcedeth_tmp_newls], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_100
        ; newdup = 1
        mov     dword[forcedeth_tmp_newdup], 1
        jmp     .set_speed

    @@: ; } else if (lpa & LPA_100HALF) {
        test    eax, LPA_100HALF
        jz      @f
        ; newls = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_100
        mov     dword[forcedeth_tmp_newls], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_100
        ; newdup = 0
        mov     dword[forcedeth_tmp_newdup], 0
        jmp     .set_speed

    @@: ; } else if (lpa & LPA_10FULL) {
        test    eax, LPA_10FULL
        jz      @f
        ; newls = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_10
        mov     dword[forcedeth_tmp_newls], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_10
        ; newdup = 1
        mov     dword[forcedeth_tmp_newdup], 1
        jmp     .set_speed

    @@: ; } else if (lpa & LPA_10HALF) {
        test    eax, LPA_10HALF
        ;    newls = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_10;
        mov     dword[forcedeth_tmp_newls], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_10
        ;    newdup = 0;
        mov     dword[forcedeth_tmp_newdup], 0
        jmp     .set_speed

    @@: ; } else {
        ; printf("bad ability %hX - falling back to 10HD.\n", lpa)
        KLog    LOG_WARNING, "FORCEDETH: update_linkspeed: bad ability 0x%x - falling back to 10HD.\n", eax

        ; newls = NVREG_LINKSPEED_FORCE | NVREG_LINKSPEED_10
        mov     dword[forcedeth_tmp_newls], NVREG_LINKSPEED_FORCE or NVREG_LINKSPEED_10
        ; newdup = 0
        mov     dword[forcedeth_tmp_newdup], 0
        ; }

  .set_speed:
        ; if (np->duplex == newdup && np->linkspeed == newls)
        mov     eax, dword[forcedeth_tmp_newdup]
        cmp     eax, dword[forcedeth_duplex]
        jne     .end_if2
        mov     eax, dword[forcedeth_tmp_newls]
        cmp     eax, dword[forcedeth_linkspeed]
        jne     .end_if2
        ;    return retval;
        jmp     .return

  .end_if2:
        ; dprintf(("changing link setting from %d/%s to %d/%s.\n",
        ;    np->linkspeed, np->duplex ? "Full-Duplex": "Half-Duplex", newls, newdup ? "Full-Duplex": "Half-Duplex"))
        KLog    LOG_DEBUG, "FORCEDETH: update_linkspeed: changing link from %x/XD to %x/XD.\n", \
                [forcedeth_linkspeed]:8, [forcedeth_tmp_newls]:8 ; !!!!!!!!!!!!!!!!!!!!!!!!!!!!

        ; np->duplex = newdup
        mov     eax, dword[forcedeth_tmp_newdup]
        mov     dword[forcedeth_duplex], eax

        ; np->linkspeed = newls
        mov     eax, [forcedeth_tmp_newls]
        mov     dword[forcedeth_linkspeed], eax

        ; if (np->gigabit == PHY_GIGABIT) {
        cmp     dword[forcedeth_gigabit], PHY_GIGABIT
        jne     .end_if3

        ; phyreg = readl(base + NvRegRandomSeed);
        mov     edi, dword[forcedeth_mapio_addr]
        mov     eax, dword[edi+NvRegRandomSeed]

        ; phyreg &= ~(0x3FF00);
        and     eax, not 0x3ff00
        mov     ecx, eax ; phyreg = ecx

        ; if ((np->linkspeed & 0xFFF) == NVREG_LINKSPEED_10)
        mov     eax, dword[forcedeth_linkspeed]
        and     eax, 0xfff
        cmp     eax, NVREG_LINKSPEED_10
        jne     @f
        ; phyreg |= NVREG_RNDSEED_FORCE3
        or      ecx, NVREG_RNDSEED_FORCE3
        jmp     .end_if4

    @@: ; else if ((np->linkspeed & 0xFFF) == NVREG_LINKSPEED_100)
        cmp     eax, NVREG_LINKSPEED_100
        jne     @f
        ; phyreg |= NVREG_RNDSEED_FORCE2
        or      ecx, NVREG_RNDSEED_FORCE2
        jmp     .end_if4

    @@: ; else if ((np->linkspeed & 0xFFF) == NVREG_LINKSPEED_1000)
        cmp     eax, NVREG_LINKSPEED_1000
        jne     .end_if4
        ; phyreg |= NVREG_RNDSEED_FORCE
        or      ecx, NVREG_RNDSEED_FORCE

  .end_if4:
        ; writel(phyreg, base + NvRegRandomSeed)
        mov     dword[edi + NvRegRandomSeed], ecx

  .end_if3:
        ; phyreg = readl(base + NvRegPhyInterface)
        mov     ecx, dword[edi + NvRegPhyInterface]

        ; phyreg &= ~(PHY_HALF | PHY_100 | PHY_1000)
        and     ecx, not (PHY_HALF or PHY_100 or PHY_1000)

        ; if (np->duplex == 0)
        cmp     dword[forcedeth_duplex], 0
        jne     @f
        ; phyreg |= PHY_HALF
        or      ecx, PHY_HALF

    @@: ; if ((np->linkspeed & 0xFFF) == NVREG_LINKSPEED_100)
        mov     eax, dword[forcedeth_linkspeed]
        and     eax, 0xfff
        cmp     eax, NVREG_LINKSPEED_100
        jne     @f
        ; phyreg |= PHY_100
        or      ecx, PHY_100
        jmp     .end_if5

    @@: ; else if ((np->linkspeed & 0xFFF) == NVREG_LINKSPEED_1000)
        cmp     eax, NVREG_LINKSPEED_1000
        jne     .end_if5
        ; phyreg |= PHY_1000
        or      ecx, PHY_1000

  .end_if5:
        ; writel(phyreg, base + NvRegPhyInterface)
        mov     dword[edi + NvRegPhyInterface], ecx

        ; writel(NVREG_MISC1_FORCE | (np->duplex ? 0 : NVREG_MISC1_HD), base + NvRegMisc1);
        cmp     dword[forcedeth_duplex], 0
        je      @f
        mov     ecx, 0
        jmp     .next

    @@: mov     ecx, NVREG_MISC1_HD

  .next:
        or      ecx, NVREG_MISC1_FORCE
        mov     dword[edi + NvRegMisc1], ecx

        ; pci_push(base)
        call    forcedeth_pci_push

        ; writel(np->linkspeed, base + NvRegLinkSpeed)
        mov     eax, dword[forcedeth_linkspeed]
        mov     dword[edi + NvRegLinkSpeed], eax

        ; pci_push(base)
        call    forcedeth_pci_push

  .return:
        ; return retval
        mov     eax, dword[forcedeth_tmp_retval]
        pop     edi esi ecx ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_start_tx ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        ; dprintf(("start_tx\n"))
        KLog    LOG_DEBUG, "FORCEDETH: start_tx.\n"

        ; writel(NVREG_XMITCTL_START, base + NvRegTransmitterControl)
        mov     edi, dword[forcedeth_mapio_addr]
        mov     dword[edi + NvRegTransmitterControl], NVREG_XMITCTL_START

        ; pci_push(base)
        call    forcedeth_pci_push

  .return:
        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc forcedeth_int_handler ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Interrupt handler
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "FORCEDETH: interrupt handler.\n"

        ret
kendp
