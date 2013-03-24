;;======================================================================================================================
;;///// rtl8169.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2007-2008 KolibriOS team <http://kolibrios.org/>
;; (c) 2007 mike.dld <mike.dld@gmail.com>
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
;# * r8169.c - linux driver (etherboot project)
;;======================================================================================================================

ETH_ALEN                       = 6
ETH_HLEN                       = 2 * ETH_ALEN + 2
ETH_ZLEN                       = 60 ; 60 + 4bytes auto payload for minimum 64bytes frame length

RTL8169_REG_MAC0               = 0x0 ; Ethernet hardware address
RTL8169_REG_MAR0               = 0x8 ; Multicast filter
RTL8169_REG_TxDescStartAddr    = 0x20
RTL8169_REG_TxHDescStartAddr   = 0x28
RTL8169_REG_FLASH              = 0x30
RTL8169_REG_ERSR               = 0x36
RTL8169_REG_ChipCmd            = 0x37
RTL8169_REG_TxPoll             = 0x38
RTL8169_REG_IntrMask           = 0x3c
RTL8169_REG_IntrStatus         = 0x3e
RTL8169_REG_TxConfig           = 0x40
RTL8169_REG_RxConfig           = 0x44
RTL8169_REG_RxMissed           = 0x4c
RTL8169_REG_Cfg9346            = 0x50
RTL8169_REG_Config0            = 0x51
RTL8169_REG_Config1            = 0x52
RTL8169_REG_Config2            = 0x53
RTL8169_REG_Config3            = 0x54
RTL8169_REG_Config4            = 0x55
RTL8169_REG_Config5            = 0x56
RTL8169_REG_MultiIntr          = 0x5c
RTL8169_REG_PHYAR              = 0x60
RTL8169_REG_TBICSR             = 0x64
RTL8169_REG_TBI_ANAR           = 0x68
RTL8169_REG_TBI_LPAR           = 0x6a
RTL8169_REG_PHYstatus          = 0x6c
RTL8169_REG_RxMaxSize          = 0xda
RTL8169_REG_CPlusCmd           = 0xe0
RTL8169_REG_RxDescStartAddr    = 0xe4
RTL8169_REG_ETThReg            = 0xec
RTL8169_REG_FuncEvent          = 0xf0
RTL8169_REG_FuncEventMask      = 0xf4
RTL8169_REG_FuncPresetState    = 0xf8
RTL8169_REG_FuncForceEvent     = 0xfc

; InterruptStatusBits
RTL8169_ISB_SYSErr             = 0x8000
RTL8169_ISB_PCSTimeout         = 0x4000
RTL8169_ISB_SWInt              = 0x0100
RTL8169_ISB_TxDescUnavail      = 0x80
RTL8169_ISB_RxFIFOOver         = 0x40
RTL8169_ISB_LinkChg            = 0x20
RTL8169_ISB_RxOverflow         = 0x10
RTL8169_ISB_TxErr              = 0x08
RTL8169_ISB_TxOK               = 0x04
RTL8169_ISB_RxErr              = 0x02
RTL8169_ISB_RxOK               = 0x01

; RxStatusDesc
RTL8169_SD_RxRES               = 0x00200000
RTL8169_SD_RxCRC               = 0x00080000
RTL8169_SD_RxRUNT              = 0x00100000
RTL8169_SD_RxRWT               = 0x00400000

; ChipCmdBits
RTL8169_CMD_Reset              = 0x10
RTL8169_CMD_RxEnb              = 0x08
RTL8169_CMD_TxEnb              = 0x04
RTL8169_CMD_RxBufEmpty         = 0x01

; Cfg9346Bits
RTL8169_CFG_9346_Lock          = 0x00
RTL8169_CFG_9346_Unlock        = 0xc0

; rx_mode_bits
RTL8169_RXM_AcceptErr          = 0x20
RTL8169_RXM_AcceptRunt         = 0x10
RTL8169_RXM_AcceptBroadcast    = 0x08
RTL8169_RXM_AcceptMulticast    = 0x04
RTL8169_RXM_AcceptMyPhys       = 0x02
RTL8169_RXM_AcceptAllPhys      = 0x01

; RxConfigBits
RTL8169_RXC_FIFOShift          = 13
RTL8169_RXC_DMAShift           = 8

; TxConfigBits
RTL8169_TXC_InterFrameGapShift = 24
RTL8169_TXC_DMAShift           = 8    ; DMA burst value (0-7) is shift this many bits

; rtl8169_PHYstatus
RTL8169_PHYS_TBI_Enable        = 0x80
RTL8169_PHYS_TxFlowCtrl        = 0x40
RTL8169_PHYS_RxFlowCtrl        = 0x20
RTL8169_PHYS_1000bpsF          = 0x10
RTL8169_PHYS_100bps            = 0x08
RTL8169_PHYS_10bps             = 0x04
RTL8169_PHYS_LinkStatus        = 0x02
RTL8169_PHYS_FullDup           = 0x01

; GIGABIT_PHY_registers
RTL8169_PHY_CTRL_REG           = 0
RTL8169_PHY_STAT_REG           = 1
RTL8169_PHY_AUTO_NEGO_REG      = 4
RTL8169_PHY_1000_CTRL_REG      = 9

; GIGABIT_PHY_REG_BIT
RTL8169_PHY_Restart_Auto_Nego  = 0x0200
RTL8169_PHY_Enable_Auto_Nego   = 0x1000

; PHY_STAT_REG = 1;
RTL8169_PHY_Auto_Neco_Comp     = 0x0020

; PHY_AUTO_NEGO_REG = 4;
RTL8169_PHY_Cap_10_Half        = 0x0020
RTL8169_PHY_Cap_10_Full        = 0x0040
RTL8169_PHY_Cap_100_Half       = 0x0080
RTL8169_PHY_Cap_100_Full       = 0x0100

; PHY_1000_CTRL_REG = 9;
RTL8169_PHY_Cap_1000_Full      = 0x0200
RTL8169_PHY_Cap_1000_Half      = 0x0100

RTL8169_PHY_Cap_PAUSE          = 0x0400
RTL8169_PHY_Cap_ASYM_PAUSE     = 0x0800

RTL8169_PHY_Cap_Null           = 0x0

; _MediaType
RTL8169_MT_10_Half             = 0x01
RTL8169_MT_10_Full             = 0x02
RTL8169_MT_100_Half            = 0x04
RTL8169_MT_100_Full            = 0x08
RTL8169_MT_1000_Full           = 0x10

; _TBICSRBit
RTL8169_TBI_LinkOK             = 0x02000000

; _DescStatusBit
RTL8169_DSB_OWNbit             = 0x80000000
RTL8169_DSB_EORbit             = 0x40000000
RTL8169_DSB_FSbit              = 0x20000000
RTL8169_DSB_LSbit              = 0x10000000

; MAC address length
MAC_ADDR_LEN                   = 6

; max supported gigabit ethernet frame size -- must be at least (dev->mtu+14+4)
MAX_ETH_FRAME_SIZE             = 1536

TX_FIFO_THRESH                 = 256     ; In bytes

RX_FIFO_THRESH                 = 7       ; 7 means NO threshold, Rx buffer level before first PCI xfer
RX_DMA_BURST                   = 7       ; Maximum PCI burst, '6' is 1024
TX_DMA_BURST                   = 7       ; Maximum PCI burst, '6' is 1024
ETTh                           = 0x3f    ; 0x3f means NO threshold

EarlyTxThld                    = 0x3f    ; 0x3f means NO early transmit
RxPacketMaxSize                = 0x0800  ; Maximum size supported is 16K-1
InterFrameGap                  = 0x03    ; 3 means InterFrameGap = the shortest one

NUM_TX_DESC                    = 1       ; Number of Tx descriptor registers
NUM_RX_DESC                    = 4       ; Number of Rx descriptor registers
RX_BUF_SIZE                    = 1536    ; Rx Buffer size

HZ                             = 1000

RTL_MIN_IO_SIZE                = 0x80
TX_TIMEOUT                     = 6 * HZ

RTL8169_TIMER_EXPIRE_TIME      = 100

ETH_HDR_LEN                    = 14
DEFAULT_MTU                    = 1500
DEFAULT_RX_BUF_LEN             = 1536


;#ifdef RTL8169_JUMBO_FRAME_SUPPORT
;#define MAX_JUMBO_FRAME_MTU    ( 10000 )
;#define MAX_RX_SKBDATA_SIZE    ( MAX_JUMBO_FRAME_MTU + ETH_HDR_LEN )
;#else
MAX_RX_SKBDATA_SIZE            = 1600
;#endif

;#ifdef RTL8169_USE_IO

;!!!#define RTL_W8(reg, val8)   outb ((val8), ioaddr + (reg))
macro RTL_W8 reg, val8
{
  if ~reg eq dx
    mov dx, word[rtl8169_tpc.mmio_addr]
    add dx, reg
  end if
  if ~val8 eq al
    mov al, val8
  end if
  out dx, al
}

;!!!#define RTL_W16(reg, val16) outw ((val16), ioaddr + (reg))
macro RTL_W16 reg, val16
{
  if ~reg eq dx
    mov dx, word[rtl8169_tpc.mmio_addr]
    add dx, reg
  end if
  if ~val16 eq ax
    mov ax, val16
  end if
  out dx, ax
}

;!!!#define RTL_W32(reg, val32) outl ((val32), ioaddr + (reg))
macro RTL_W32 reg, val32
{
  if ~reg eq dx
    mov dx, word[rtl8169_tpc.mmio_addr]
    add dx, reg
  end if
  if ~val32 eq eax
    mov eax, val32
  end if
  out dx, eax
}

;!!!#define RTL_R8(reg)         inb (ioaddr + (reg))
macro RTL_R8 reg
{
  if ~reg eq dx
    mov dx, word[rtl8169_tpc.mmio_addr]
    add dx, reg
  end if
  in  al, dx
}

;!!!#define RTL_R16(reg)        inw (ioaddr + (reg))
macro RTL_R16 reg
{
  if ~reg eq dx
    mov dx, word[rtl8169_tpc.mmio_addr]
    add dx, reg
  end if
  in  ax, dx
}

;!!!#define RTL_R32(reg)        ((unsigned long) inl (ioaddr + (reg)))
macro RTL_R32 reg
{
  if ~reg eq dx
    mov dx, word[rtl8169_tpc.mmio_addr]
    add dx, reg
  end if
  in  eax, dx
}

;#else

; write/read MMIO register
;#define RTL_W8(reg, val8)      writeb ((val8), ioaddr + (reg))
;#define RTL_W16(reg, val16)    writew ((val16), ioaddr + (reg))
;#define RTL_W32(reg, val32)    writel ((val32), ioaddr + (reg))
;#define RTL_R8(reg)            readb (ioaddr + (reg))
;#define RTL_R16(reg)           readw (ioaddr + (reg))
;#define RTL_R32(reg)           ((unsigned long) readl (ioaddr + (reg)))

;#endif

MCFG_METHOD_01          = 0x01
MCFG_METHOD_02          = 0x02
MCFG_METHOD_03          = 0x03
MCFG_METHOD_04          = 0x04
MCFG_METHOD_05          = 0x05
MCFG_METHOD_11          = 0x0b
MCFG_METHOD_12          = 0x0c
MCFG_METHOD_13          = 0x0d
MCFG_METHOD_14          = 0x0e
MCFG_METHOD_15          = 0x0f

PCFG_METHOD_1           = 0x01 ; PHY Reg 0x03 bit0-3 == 0x0000
PCFG_METHOD_2           = 0x02 ; PHY Reg 0x03 bit0-3 == 0x0001
PCFG_METHOD_3           = 0x03 ; PHY Reg 0x03 bit0-3 == 0x0002

PCI_COMMAND_IO          = 0x1   ; Enable response in I/O space
PCI_COMMAND_MEM         = 0x2   ; Enable response in mem space
PCI_COMMAND_MASTER      = 0x4   ; Enable bus mastering
PCI_LATENCY_TIMER       = 0x0d  ; 8 bits
PCI_COMMAND_SPECIAL     = 0x8   ; Enable response to special cycles
PCI_COMMAND_INVALIDATE  = 0x10  ; Use memory write and invalidate
PCI_COMMAND_VGA_PALETTE = 0x20  ; Enable palette snooping
PCI_COMMAND_PARITY      = 0x40  ; Enable parity checking
PCI_COMMAND_WAIT        = 0x80  ; Enable address/data stepping
PCI_COMMAND_SERR        = 0x100 ; Enable SERR
PCI_COMMAND_FAST_BACK   = 0x200 ; Enable back-to-back writes

struct rtl8169_TxDesc
  status    dd ?
  vlan_tag  dd ?
  buf_addr  dd ?
  buf_Haddr dd ?
ends

struct rtl8169_RxDesc
  status    dd ?
  vlan_tag  dd ?
  buf_addr  dd ?
  buf_Haddr dd ?
ends

virtual at eth_data_start
  ; Define the TX Descriptor
  align 256
  rtl8169_tx_ring rb NUM_TX_DESC * sizeof.rtl8169_TxDesc

  ; Create a static buffer of size RX_BUF_SZ for each
  ; TX Descriptor.  All descriptors point to a
  ; part of this buffer
  align 256
  rtl8169_txb     rb NUM_TX_DESC * RX_BUF_SIZE

  ; Define the RX Descriptor
  align 256
  rtl8169_rx_ring rb NUM_RX_DESC * sizeof.rtl8169_RxDesc

  ; Create a static buffer of size RX_BUF_SZ for each
  ; RX Descriptor   All descriptors point to a
  ; part of this buffer
  align 256
  rtl8169_rxb     rb NUM_RX_DESC * RX_BUF_SIZE

  rtl8169_tpc:
    .mmio_addr    dd ? ; memory map physical address
    .chipset      dd ?
    .pcfg         dd ?
    .mcfg         dd ?
    .cur_rx       dd ? ; Index into the Rx descriptor buffer of next Rx pkt
    .cur_tx       dd ? ; Index into the Tx descriptor buffer of next Rx pkt
    .TxDescArrays dd ? ; Index of Tx Descriptor buffer
    .RxDescArrays dd ? ; Index of Rx Descriptor buffer
    .TxDescArray  dd ? ; Index of 256-alignment Tx Descriptor buffer
    .RxDescArray  dd ? ; Index of 256-alignment Rx Descriptor buffer
    .RxBufferRing rd NUM_RX_DESC ; Index of Rx Buffer array
    .Tx_skbuff    rd NUM_TX_DESC
end virtual

rtl8169_intr_mask = RTL8169_ISB_LinkChg or RTL8169_ISB_RxOverflow or RTL8169_ISB_RxFIFOOver or RTL8169_ISB_TxErr or RTL8169_ISB_TxOK or RTL8169_ISB_RxErr or RTL8169_ISB_RxOK
rtl8169_rx_config = (RX_FIFO_THRESH shl RTL8169_RXC_FIFOShift) or (RX_DMA_BURST shl RTL8169_RXC_DMAShift) or 0x0000000e

iglobal
  net.rtl8169.vftbl dd \
    rtl8169_probe, \
    rtl8169_reset, \
    rtl8169_poll, \
    rtl8169_transmit, \
    0

  ;static struct {
  ;       const char *name;
  ;       u8 mcfg;                /* depend on RTL8169 docs */
  ;       u32 RxConfigMask;       /* should clear the bits supported by this chip */
  ;}
  rtl_chip_info dd \
    MCFG_METHOD_01, 0xff7e1880, \ ; RTL8169
    MCFG_METHOD_02, 0xff7e1880, \ ; RTL8169s/8110s
    MCFG_METHOD_03, 0xff7e1880, \ ; RTL8169s/8110s
    MCFG_METHOD_04, 0xff7e1880, \ ; RTL8169sb/8110sb
    MCFG_METHOD_05, 0xff7e1880, \ ; RTL8169sc/8110sc
    MCFG_METHOD_11, 0xff7e1880, \ ; RTL8168b/8111b   // PCI-E
    MCFG_METHOD_12, 0xff7e1880, \ ; RTL8168b/8111b   // PCI-E
    MCFG_METHOD_13, 0xff7e1880, \ ; RTL8101e         // PCI-E 8139
    MCFG_METHOD_14, 0xff7e1880, \ ; RTL8100e         // PCI-E 8139
    MCFG_METHOD_15, 0xff7e1880    ; RTL8100e         // PCI-E 8139

  mac_info dd \
    0x38800000, MCFG_METHOD_15, \
    0x38000000, MCFG_METHOD_12, \
    0x34000000, MCFG_METHOD_13, \
    0x30800000, MCFG_METHOD_14, \
    0x30000000, MCFG_METHOD_11, \
    0x18000000, MCFG_METHOD_05, \
    0x10000000, MCFG_METHOD_04, \
    0x04000000, MCFG_METHOD_03, \
    0x00800000, MCFG_METHOD_02, \
    0x00000000, MCFG_METHOD_01    ; catch-all
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_init_board ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_init_board\n"

        stdcall adjust_pci_device, dword[pci_bus], dword[pci_dev]

        stdcall pci_bar_start, dword[pci_bus], dword[pci_dev], PCI_BASE_ADDRESS_0
        mov     [rtl8169_tpc.mmio_addr], eax
        ; Soft reset the chip
        RTL_W8  RTL8169_REG_ChipCmd, RTL8169_CMD_Reset

        ; Check that the chip has finished the reset
        mov     ecx, 1000

    @@: RTL_R8  RTL8169_REG_ChipCmd
        test    al, RTL8169_CMD_Reset
        jz      @f
        stdcall udelay, 10
        loop    @b

    @@: ; identify config method
        RTL_R32 RTL8169_REG_TxConfig
        and     eax, 0x7c800000
;       KLog    LOG_DEBUG, "rtl8169_init_board: TxConfig & 0x7c800000 = 0x%x\n", eax
        mov     esi, mac_info - 8

    @@: add     esi, 8
        mov     ecx, eax
        and     ecx, [esi]
        cmp     ecx, [esi]
        jne     @b
        mov     eax, [esi + 4]
        mov     [rtl8169_tpc.mcfg], eax

        mov     [rtl8169_tpc.pcfg], PCFG_METHOD_3
        stdcall RTL8169_READ_GMII_REG, 3
        and     al, 0x0f
        or      al, al
        jnz     @f
        mov     [rtl8169_tpc.pcfg], PCFG_METHOD_1
        jmp     .pconf

    @@: dec     al
        jnz     .pconf
        mov     [rtl8169_tpc.pcfg], PCFG_METHOD_2

  .pconf:
        ; identify chip attached to board
        mov     ecx, 10
        mov     eax, [rtl8169_tpc.mcfg]

    @@: dec     ecx
        js      @f
        cmp     eax, [rtl_chip_info + ecx * 8]
        jne     @b
        mov     [rtl8169_tpc.chipset], ecx
        jmp     .match

    @@: ; if unknown chip, assume array element #0, original RTL-8169 in this case
;       KLog    LOG_WARNING, "rtl8169_init_board: PCI device: unknown chip version, assuming RTL-8169\n"
        RTL_R32 RTL8169_REG_TxConfig
;       KLog    LOG_DEBUG, "rtl8169_init_board: PCI device: TxConfig = 0x%x\n", eax

        mov     [rtl8169_tpc.chipset], 0

        xor     eax, eax
        inc     eax
        ret

  .match:
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_hw_PHY_config ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_hw_PHY_config: priv.mcfg=%d, priv.pcfg=%d\n", [rtl8169_tpc.mcfg], [rtl8169_tpc.pcfg]

;       DBG_PRINT("priv->mcfg=%d, priv->pcfg=%d\n", tpc->mcfg, tpc->pcfg);

        cmp     [rtl8169_tpc.mcfg], MCFG_METHOD_04
        jne     .not_4
;       stdcall RTL8169_WRITE_GMII_REG, 0x1f, 0x0001
;       stdcall RTL8169_WRITE_GMII_REG, 0x1b, 0x841e
;       stdcall RTL8169_WRITE_GMII_REG, 0x0e, 0x7bfb
;       stdcall RTL8169_WRITE_GMII_REG, 0x09, 0x273a
        stdcall RTL8169_WRITE_GMII_REG, 0x1f, 0x0002
        stdcall RTL8169_WRITE_GMII_REG, 0x01, 0x90d0
        stdcall RTL8169_WRITE_GMII_REG, 0x1f, 0x0000
        jmp     .exit

  .not_4:
        cmp     [rtl8169_tpc.mcfg], MCFG_METHOD_02
        je      @f
        cmp     [rtl8169_tpc.mcfg], MCFG_METHOD_03
        jne     .not_2_or_3

    @@: stdcall RTL8169_WRITE_GMII_REG, 0x1f, 0x0001
        stdcall RTL8169_WRITE_GMII_REG, 0x15, 0x1000
        stdcall RTL8169_WRITE_GMII_REG, 0x18, 0x65c7
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0x0000
        stdcall RTL8169_WRITE_GMII_REG, 0x03, 0x00a1
        stdcall RTL8169_WRITE_GMII_REG, 0x02, 0x0008
        stdcall RTL8169_WRITE_GMII_REG, 0x01, 0x1020
        stdcall RTL8169_WRITE_GMII_REG, 0x00, 0x1000
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0x0800
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0x0000
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0x7000
        stdcall RTL8169_WRITE_GMII_REG, 0x03, 0xff41
        stdcall RTL8169_WRITE_GMII_REG, 0x02, 0xde60
        stdcall RTL8169_WRITE_GMII_REG, 0x01, 0x0140
        stdcall RTL8169_WRITE_GMII_REG, 0x00, 0x0077
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0x7800
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0x7000
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xa000
        stdcall RTL8169_WRITE_GMII_REG, 0x03, 0xdf01
        stdcall RTL8169_WRITE_GMII_REG, 0x02, 0xdf20
        stdcall RTL8169_WRITE_GMII_REG, 0x01, 0xff95
        stdcall RTL8169_WRITE_GMII_REG, 0x00, 0xfa00
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xa800
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xa000
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xb000
        stdcall RTL8169_WRITE_GMII_REG, 0x03, 0xff41
        stdcall RTL8169_WRITE_GMII_REG, 0x02, 0xde20
        stdcall RTL8169_WRITE_GMII_REG, 0x01, 0x0140
        stdcall RTL8169_WRITE_GMII_REG, 0x00, 0x00bb
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xb800
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xb000
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xf000
        stdcall RTL8169_WRITE_GMII_REG, 0x03, 0xdf01
        stdcall RTL8169_WRITE_GMII_REG, 0x02, 0xdf20
        stdcall RTL8169_WRITE_GMII_REG, 0x01, 0xff95
        stdcall RTL8169_WRITE_GMII_REG, 0x00, 0xbf00
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xf800
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0xf000
        stdcall RTL8169_WRITE_GMII_REG, 0x04, 0x0000
        stdcall RTL8169_WRITE_GMII_REG, 0x1f, 0x0000
        stdcall RTL8169_WRITE_GMII_REG, 0x0b, 0x0000
        jmp     .exit

  .not_2_or_3:
;       DBG_PRINT("tpc->mcfg=%d. Discard hw PHY config.\n", tpc->mcfg);
;       KLog    LOG_DEBUG, "  tpc.mcfg=%d, discard hw PHY config\n", [rtl8169_tpc.mcfg]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
;kproc pci_write_config_byte ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       ret
;kendp

;-----------------------------------------------------------------------------------------------------------------------
proc RTL8169_WRITE_GMII_REG, RegAddr:byte, value:dword ;////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;;;     KLog    LOG_DEBUG, "RTL8169_WRITE_GMII_REG: 0x%x 0x%x\n", [RegAddr]:2, [value]

        movzx   eax, [RegAddr]
        shl     eax, 16
        or      eax, [value]
        or      eax, 0x80000000
        RTL_W32 RTL8169_REG_PHYAR, eax
        stdcall udelay, 1 ;;; 1000

        mov     ecx, 2000
        ; Check if the RTL8169 has completed writing to the specified MII register

    @@: RTL_R32 RTL8169_REG_PHYAR
        test    eax, 0x80000000
        jz      .exit
        stdcall udelay, 1 ;;; 100
        loop    @b

  .exit:
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc RTL8169_READ_GMII_REG, RegAddr:byte ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;;;     KLog    LOG_DEBUG, "RTL8169_READ_GMII_REG: 0x%x\n", [RegAddr]:2

        push    ecx
        movzx   eax, [RegAddr]
        shl     eax, 16
;       or      eax, 0x0
        RTL_W32 RTL8169_REG_PHYAR, eax
        stdcall udelay, 1 ;;; 1000

        mov     ecx, 2000
        ; Check if the RTL8169 has completed retrieving data from the specified MII register

    @@: RTL_R32 RTL8169_REG_PHYAR
        test    eax, 0x80000000
        jnz     .exit
        stdcall udelay, 1 ;;; 100
        loop    @b

        or      eax, -1
        pop     ecx
        ret

  .exit:
        RTL_R32 RTL8169_REG_PHYAR
        and     eax, 0xffff
        pop     ecx
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_set_rx_mode ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_set_rx_mode\n"

        ; IFF_ALLMULTI
        ; Too many to filter perfectly -- accept all multicasts
        RTL_R32 RTL8169_REG_RxConfig
        mov     ecx, [rtl8169_tpc.chipset]
        and     eax, [rtl_chip_info + ecx * 8 + 4] ; RxConfigMask
        or      eax, rtl8169_rx_config or (RTL8169_RXM_AcceptBroadcast or RTL8169_RXM_AcceptMulticast or RTL8169_RXM_AcceptMyPhys)
        RTL_W32 RTL8169_REG_RxConfig, eax

        ; Multicast hash filter
        RTL_W32 RTL8169_REG_MAR0 + 0, 0xffffffff
        RTL_W32 RTL8169_REG_MAR0 + 4, 0xffffffff
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_init_ring ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_init_ring\n"

        xor     eax, eax
        mov     [rtl8169_tpc.cur_rx], eax
        mov     [rtl8169_tpc.cur_tx], eax

        mov     edi, [rtl8169_tpc.TxDescArray]
        mov     ecx, (NUM_TX_DESC * sizeof.rtl8169_TxDesc) / 4
        rep
        stosd
        mov     edi, [rtl8169_tpc.RxDescArray]
        mov     ecx, (NUM_RX_DESC * sizeof.rtl8169_RxDesc) / 4
        rep
        stosd

        mov     edi, rtl8169_tpc.Tx_skbuff
        mov     eax, rtl8169_txb
        mov     ecx, NUM_TX_DESC

    @@: stosd
        inc     eax ; add eax, RX_BUF_SIZE ???
        loop    @b

        ;!!!    for (i = 0; i < NUM_RX_DESC; i++) {
        ;!!!            if (i == (NUM_RX_DESC - 1))
        ;!!!                    tpc->RxDescArray[i].status = (OWNbit | EORbit) | RX_BUF_SIZE;
        ;!!!            else
        ;!!!                    tpc->RxDescArray[i].status = OWNbit | RX_BUF_SIZE;
        ;!!!            tpc->RxBufferRing[i] = &rxb[i * RX_BUF_SIZE];
        ;!!!            tpc->RxDescArray[i].buf_addr = virt_to_bus(tpc->RxBufferRing[i]);
        ;!!!    }
        mov     esi, rtl8169_tpc.RxBufferRing
        mov     edi, [rtl8169_tpc.RxDescArray]
        mov     eax, rtl8169_rxb
        mov     ecx, NUM_RX_DESC

    @@: mov     [esi], eax
        mov     [edi + rtl8169_RxDesc.buf_addr], eax
        sub     [edi + rtl8169_RxDesc.buf_addr], OS_BASE
        mov     [edi + rtl8169_RxDesc.status], RTL8169_DSB_OWNbit or RX_BUF_SIZE
        add     esi, 4
        add     edi, sizeof.rtl8169_RxDesc
        add     eax, RX_BUF_SIZE
        loop    @b

        or      [edi - sizeof.rtl8169_RxDesc + rtl8169_RxDesc.status], RTL8169_DSB_EORbit

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_hw_start ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_hw_start\n"

        ; Soft reset the chip
        RTL_W8  RTL8169_REG_ChipCmd, RTL8169_CMD_Reset
        ; Check that the chip has finished the reset
        mov     ecx, 1000

    @@: RTL_R8  RTL8169_REG_ChipCmd
        and     al, RTL8169_CMD_Reset
        jz      @f
        stdcall udelay, 10
        loop    @b

    @@: RTL_W8  RTL8169_REG_Cfg9346, RTL8169_CFG_9346_Unlock
        RTL_W8  RTL8169_REG_ChipCmd, RTL8169_CMD_TxEnb or RTL8169_CMD_RxEnb
        RTL_W8  RTL8169_REG_ETThReg, ETTh
        ; For gigabit rtl8169
        RTL_W16 RTL8169_REG_RxMaxSize, RxPacketMaxSize
        ; Set Rx Config register
        RTL_R32 RTL8169_REG_RxConfig
        mov     ecx, [rtl8169_tpc.chipset]
        and     eax, [rtl_chip_info + ecx * 8 + 4] ; RxConfigMask
        or      eax, rtl8169_rx_config
        RTL_W32 RTL8169_REG_RxConfig, eax
        ; Set DMA burst size and Interframe Gap Time
        RTL_W32 RTL8169_REG_TxConfig, (TX_DMA_BURST shl RTL8169_TXC_DMAShift) or (InterFrameGap shl RTL8169_TXC_InterFrameGapShift)
        RTL_R16 RTL8169_REG_CPlusCmd
        RTL_W16 RTL8169_REG_CPlusCmd, ax

        RTL_R16 RTL8169_REG_CPlusCmd
        or      ax, 1 shl 3
        cmp     [rtl8169_tpc.mcfg], MCFG_METHOD_02
        jne     @f
        cmp     [rtl8169_tpc.mcfg], MCFG_METHOD_03
        jne     @f
        or      ax, 1 shl 14
;       KLog    LOG_DEBUG, "  Set MAC Reg C+CR Offset 0xE0: bit-3 and bit-14\n"
        jmp     .set

    @@:
;       KLog    LOG_DEBUG, "  Set MAC Reg C+CR Offset 0xE0: bit-3\n"

  .set:
        RTL_W16 RTL8169_REG_CPlusCmd, ax

;       RTL_W16 0xe2, 0x1517
;       RTL_W16 0xe2, 0x152a
;       RTL_W16 0xe2, 0x282a
        RTL_W16 0xe2, 0x0000

        MOV     [rtl8169_tpc.cur_rx], 0
        push    eax
        mov     eax, [rtl8169_tpc.TxDescArray]
        sub     eax, OS_BASE
        RTL_W32 RTL8169_REG_TxDescStartAddr, eax ; [rtl8169_tpc.TxDescArray]
        mov     eax, [rtl8169_tpc.RxDescArray]
        sub     eax, OS_BASE
        RTL_W32 RTL8169_REG_RxDescStartAddr, eax ; [rtl8169_tpc.RxDescArray]
        pop     eax
        RTL_W8  RTL8169_REG_Cfg9346, RTL8169_CFG_9346_Lock
        stdcall udelay, 10
        RTL_W32 RTL8169_REG_RxMissed, 0
        call    rtl8169_set_rx_mode
        ; no early-rx interrupts
        RTL_R16 RTL8169_REG_MultiIntr
        and     ax, 0xf000
        RTL_W16 RTL8169_REG_MultiIntr, ax
        RTL_W16 RTL8169_REG_IntrMask, 0 ; rtl8169_intr_mask
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
proc udelay, msec:dword ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    esi
        mov     esi, [msec]
        call    delay_ms
        pop     esi
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_probe ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Searches for an ethernet card, enables it and clears the rx buffer
;? If a card was found, it enables the ethernet -> TCPIP link
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_probe: 0x%x : 0x%x 0x%x\n", [io_addr]:8, [pci_bus]:2, [pci_dev]:2

        call    rtl8169_init_board

        mov     ecx, MAC_ADDR_LEN
        mov     edx, [rtl8169_tpc.mmio_addr]
        add     edx, RTL8169_REG_MAC0
        xor     ebx, ebx
        ; Get MAC address. FIXME: read EEPROM

    @@: RTL_R8  dx
        mov     [node_addr + ebx], al
        inc     edx
        inc     ebx
        loop    @b

;       KLog    LOG_DEBUG, "rtl8169_probe: MAC = %x-%x-%x-%x-%x-%x\n", [node_addr+0]:2, [node_addr+1]:2, \
;               [node_addr+2]:2, [node_addr+3]:2, [node_addr+4]:2, [node_addr+5]:2

        ; Config PHY
        stdcall rtl8169_hw_PHY_config
;       KLog    LOG_DEBUG, "  Set MAC Reg C+CR Offset 0x82h = 0x01h\n"
        RTL_W8  0x82, 0x01
        cmp     [rtl8169_tpc.mcfg], MCFG_METHOD_03
        jae     @f
;       KLog    LOG_DEBUG, "  Set PCI Latency=0x40\n"
;       stdcall pci_write_config_byte, dword[pci_bus], dword[pci_dev], PCI_LATENCY_TIMER, 0x40

    @@: cmp     [rtl8169_tpc.mcfg], MCFG_METHOD_02
        jne     @f
;       KLog    LOG_DEBUG, "  Set MAC Reg C+CR Offset 0x82h = 0x01h\n"
        RTL_W8  0x82, 0x01
;       KLog    LOG_DEBUG, "  Set PHY Reg 0x0bh = 0x00h\n"
        stdcall RTL8169_WRITE_GMII_REG, 0x0b, 0x0000 ; w 0x0b 15 0 0

    @@: ; if TBI is not enabled
        RTL_R8  RTL8169_REG_PHYstatus
        test    al, RTL8169_PHYS_TBI_Enable
        jz      .tbi_dis
        stdcall RTL8169_READ_GMII_REG, RTL8169_PHY_AUTO_NEGO_REG
        ; enable 10/100 Full/Half Mode, leave PHY_AUTO_NEGO_REG bit4:0 unchanged
        and     eax, 0x0c1f
        or      eax, RTL8169_PHY_Cap_10_Half or RTL8169_PHY_Cap_10_Full or RTL8169_PHY_Cap_100_Half or RTL8169_PHY_Cap_100_Full
        stdcall RTL8169_WRITE_GMII_REG, RTL8169_PHY_AUTO_NEGO_REG, eax
        ; enable 1000 Full Mode
        stdcall RTL8169_WRITE_GMII_REG, RTL8169_PHY_1000_CTRL_REG, RTL8169_PHY_Cap_1000_Full or RTL8169_PHY_Cap_1000_Half ; rtl8168
        ; Enable auto-negotiation and restart auto-nigotiation
        stdcall RTL8169_WRITE_GMII_REG, RTL8169_PHY_CTRL_REG, RTL8169_PHY_Enable_Auto_Nego or RTL8169_PHY_Restart_Auto_Nego
        stdcall udelay, 100
        mov     ecx, 10000
        ; wait for auto-negotiation process

    @@: dec     ecx
        jz      @f
        stdcall RTL8169_READ_GMII_REG, RTL8169_PHY_STAT_REG
        stdcall udelay, 100
        test    eax, RTL8169_PHY_Auto_Neco_Comp
        jz      @b
        RTL_R8  RTL8169_REG_PHYstatus
        jmp     @f

  .tbi_dis:
        stdcall udelay, 100

    @@: call    rtl8169_reset
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_reset ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Place the chip (ie, the ethernet card) into a virgin state
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, ebx, ecx, edx
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_reset: 0x%x : 0x%x 0x%x\n", [io_addr]:8, [pci_bus]:2, [pci_dev]:2

        mov     [rtl8169_tpc.TxDescArrays], rtl8169_tx_ring
        ; Tx Desscriptor needs 256 bytes alignment
        mov     [rtl8169_tpc.TxDescArray], rtl8169_tx_ring

        mov     [rtl8169_tpc.RxDescArrays], rtl8169_rx_ring
        ; Rx Desscriptor needs 256 bytes alignment
        mov     [rtl8169_tpc.RxDescArray], rtl8169_rx_ring

        call    rtl8169_init_ring
        call    rtl8169_hw_start
        ; Construct a perfect filter frame with the mac address as first match
        ; and broadcast for all others
        mov     edi, rtl8169_txb
        or      al, -1
        mov     ecx, 192
        rep
        stosb

        mov     esi, node_addr
        mov     edi, rtl8169_txb
        movsd
        movsw

        mov     eax, [pci_data]
        mov     [eth_status], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_transmit ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Transmits a packet of data via the ethernet card
;-----------------------------------------------------------------------------------------------------------------------
;> edi = Pointer to 48 bit destination address
;> bx = Type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, edx, esi, edi
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_transmit\n" ; : 0x%x : 0x%x 0x%x 0x%x 0x%x\n", [io_addr]:8, edi, bx, ecx, esi

        push    ecx edx esi
        mov     eax, MAX_ETH_FRAME_SIZE
        mul     [rtl8169_tpc.cur_tx]
        mov     esi, edi
        ; point to the current txb incase multiple tx_rings are used
        mov     edi, [rtl8169_tpc.Tx_skbuff + eax * 4]
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
        ; copy the packet data
        pop     esi edx ecx
        push    ecx
        shr     ecx, 2
        rep
        movsd
        pop     ecx
        push    ecx
        and     ecx, 3
        rep
        movsb

        ;!!!    s += ETH_HLEN;
        ;!!!    s &= 0x0FFF;
        ;!!!    while (s < ETH_ZLEN)
        ;!!!            ptxb[s++] = '\0';
        mov     edi, eax
        pop     ecx
        push    eax
        add     ecx, ETH_HLEN
        and     ecx, 0x0fff
        xor     al, al
        add     edi, ecx

    @@: cmp     ecx, ETH_ZLEN
        jae     @f
        stosb
        inc     ecx
        jmp     @b

    @@: pop     eax

        mov     ebx, eax
        mov     eax, sizeof.rtl8169_TxDesc
        mul     [rtl8169_tpc.cur_tx]
        add     eax, [rtl8169_tpc.TxDescArray]
        xchg    eax, ebx
        mov     [ebx + rtl8169_TxDesc.buf_addr], eax
        sub     [ebx + rtl8169_TxDesc.buf_addr], OS_BASE

        mov     eax, ecx
        cmp     eax, ETH_ZLEN
        jae     @f
        mov     eax, ETH_ZLEN

    @@: or      eax, RTL8169_DSB_OWNbit or RTL8169_DSB_FSbit or RTL8169_DSB_LSbit
        cmp     [rtl8169_tpc.cur_tx], NUM_TX_DESC - 1
        jne     @f
        or      eax, RTL8169_DSB_EORbit

    @@: mov     [ebx + rtl8169_TxDesc.status], eax

        RTL_W8  RTL8169_REG_TxPoll, 0x40 ; set polling bit

        inc     [rtl8169_tpc.cur_tx]
        and     [rtl8169_tpc.cur_tx], NUM_TX_DESC - 1

        ;!!!    to = currticks() + TX_TIMEOUT;
        ;!!!    while ((tpc->TxDescArray[entry].status & OWNbit) && (currticks() < to));        /* wait */
        mov     ecx, TX_TIMEOUT / 10

    @@: test    [ebx + rtl8169_TxDesc.status], RTL8169_DSB_OWNbit
        jnz     @f
        stdcall udelay, 10
        loop    @b
;       KLog    LOG_ERROR, "rtl8169_transmit: TX Time Out\n"

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_poll ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Polls the ethernet card for a received packet
;-----------------------------------------------------------------------------------------------------------------------
;< Received data, if any, ends up in Ether_buffer
;-----------------------------------------------------------------------------------------------------------------------
;# Destroyed registers: eax, edx, ecx
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "rtl8169_poll\n" ; : 0x%x : none\n", [io_addr]:8

        mov     [eth_rx_data_len], 0

        mov     eax, sizeof.rtl8169_RxDesc
        mul     [rtl8169_tpc.cur_rx]
        add     eax, [rtl8169_tpc.RxDescArray]
        mov     ebx, eax

;       KLog    LOG_DEBUG, "  rtl8169_RxDesc.status = 0x%x\n", [ebx + rtl8169_RxDesc.status]

        test    [ebx + rtl8169_RxDesc.status], RTL8169_DSB_OWNbit ; 0x80000600
        jnz     .exit

;       KLog    LOG_DEBUG, "  rtl8169_tpc.cur_rx = %u\n", [rtl8169_tpc.cur_rx]

        ; h/w no longer present (hotplug?) or major error, bail
        RTL_R16 RTL8169_REG_IntrStatus

;       KLog    LOG_DEBUG, "  IntrStatus = 0x%x\n", ax

        cmp     ax, 0xffff
        je      .exit

        push    eax
        and     ax, not (RTL8169_ISB_RxFIFOOver or RTL8169_ISB_RxOverflow or RTL8169_ISB_RxOK)
        RTL_W16 RTL8169_REG_IntrStatus, ax

        mov     eax, [ebx + rtl8169_RxDesc.status]

;       KLog    LOG_DEBUG, "  RxDesc.status = 0x%x\n", eax

        test    eax, RTL8169_SD_RxRES
        jnz     .else
        and     eax, 0x00001fff
;       jz      .exit.pop
        add     eax, -4
        mov     [eth_rx_data_len], ax

;       KLog    LOG_DEBUG, "rtl8169_poll: data length = %u\n", ax

        push    eax
        mov     ecx, eax
        shr     ecx, 2
        mov     eax, [rtl8169_tpc.cur_rx]
        mov     edx, [rtl8169_tpc.RxBufferRing + eax * 4]
        mov     esi, edx
        mov     edi, Ether_buffer
        rep
        movsd
        pop     ecx
        and     ecx, 3
        rep
        movsb

        mov     eax, RTL8169_DSB_OWNbit or RX_BUF_SIZE
        cmp     [rtl8169_tpc.cur_rx], NUM_RX_DESC - 1
        jne     @f
        or      eax, RTL8169_DSB_EORbit

    @@: mov     [ebx + rtl8169_RxDesc.status], eax

        mov     [ebx + rtl8169_RxDesc.buf_addr], edx
        sub     [ebx + rtl8169_RxDesc.buf_addr], OS_BASE
        jmp     @f

  .else:
;       KLog    LOG_ERROR, "rtl8169_poll: Rx Error\n"
        ; FIXME: shouldn't I reset the status on an error

    @@: inc     [rtl8169_tpc.cur_rx]
        and     [rtl8169_tpc.cur_rx], NUM_RX_DESC - 1

  .exit.pop:
        pop     eax
        and     ax, RTL8169_ISB_RxFIFOOver or RTL8169_ISB_RxOverflow or RTL8169_ISB_RxOK
        RTL_W16 RTL8169_REG_IntrStatus, ax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rtl8169_cable ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp
