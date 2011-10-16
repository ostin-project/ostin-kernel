;;======================================================================================================================
;;///// pcnet32.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
;; (c) 2004 MenuetOS <http://menuetos.net/>
;; (c) 2004 Jarek Pelczar <jpelczar@interia.pl>
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
;# * PCNet32 driver - etherboot 5.0.6 project
;;======================================================================================================================

PCNET32_PORT_AUI     = 0x00
PCNET32_PORT_10BT    = 0x01
PCNET32_PORT_GPSI    = 0x02
PCNET32_PORT_MII     = 0x03
PCNET32_PORT_PORTSEL = 0x03
PCNET32_PORT_ASEL    = 0x04
PCNET32_PORT_100     = 0x40
PCNET32_PORT_FD      = 0x80
PCNET32_DMA_MASK     = 0xffffffff

PCNET32_LOG_TX_BUFFERS = 1
PCNET32_LOG_RX_BUFFERS = 2

PCNET32_TX_RING_SIZE     = 1 shl PCNET32_LOG_TX_BUFFERS
PCNET32_TX_RING_MOD_MASK = PCNET32_TX_RING_SIZE - 1
PCNET32_TX_RING_LEN_BITS = 0
PCNET32_RX_RING_SIZE     = 1 shl PCNET32_LOG_RX_BUFFERS
PCNET32_RX_RING_MOD_MASK = PCNET32_RX_RING_SIZE - 1
PCNET32_RX_RING_LEN_BITS = PCNET32_LOG_RX_BUFFERS shl 4
PCNET32_PKT_BUF_SZ       = 1544
PCNET32_PKT_BUF_SZ_NEG   = 0xf9f8

pcnet32_txb     = eth_data_start
pcnet32_rxb     = (pcnet32_txb + PCNET32_PKT_BUF_SZ * PCNET32_TX_RING_SIZE + 0xf) and 0xfffffff0
pcnet32_tx_ring = (pcnet32_rxb + PCNET32_PKT_BUF_SZ * PCNET32_RX_RING_SIZE + 0xf) and 0xfffffff0
pcnet32_rx_ring = (pcnet32_tx_ring + 16 * PCNET32_TX_RING_SIZE + 0xf) and 0xfffffff0

virtual at (pcnet32_rx_ring + 16 * PCNET32_RX_RING_SIZE + 0xf) and 0xfffffff0
  pcnet32_private:
    .mode         dw ?
    .tlen_rlen    dw ?
    .phys_addr    rb 6
    .reserved     dw ?
    .filter       rd 2
    .rx_ring      dd ?
    .tx_ring      dd ?
    .cur_rx       dd ?
    .cur_tx       dd ?
    .dirty_rx     dd ?
    .dirty_tx     dd ?
    .tx_full      db ?
    .options      dd ?
    .full_duplex  db ?
    .chip_version dd ?
    .mii          db ?
    .ltint        db ?
    .dxsuflo      db ?
    .fset         db ?
    .fdx          db ?
end virtual

struct pcnet32_rx_head
  base       dd ?
  buf_length dw ?
  status     dw ?
  msg_length dd ?
  reserved   dd ?
ends

struct pcnet32_tx_head
  base     dd ?
  length   dw ?
  status   dw ?
  misc     dd ?
  reserved dd ?
ends

uglobal
  pcnet32_access:
    .read_csr  dd ?
    .write_csr dd ?
    .read_bcr  dd ?
    .write_bcr dd ?
    .read_rap  dd ?
    .write_rap dd ?
    .reset     dd ?
endg

iglobal
  pcnet32_options_mapping:
    dd PCNET32_PORT_ASEL ; 0 Auto-select
    dd PCNET32_PORT_AUI ; 1 BNC/AUI
    dd PCNET32_PORT_AUI ; 2 AUI/BNC
    dd PCNET32_PORT_ASEL ; 3 not supported
    dd PCNET32_PORT_10BT or PCNET32_PORT_FD ; 4 10baseT-FD
    dd PCNET32_PORT_ASEL ; 5 not supported
    dd PCNET32_PORT_ASEL ; 6 not supported
    dd PCNET32_PORT_ASEL ; 7 not supported
    dd PCNET32_PORT_ASEL ; 8 not supported
    dd PCNET32_PORT_MII ; 9 MII 10baseT
    dd PCNET32_PORT_MII or PCNET32_PORT_FD ; 10 MII 10baseT-FD
    dd PCNET32_PORT_MII ; 11 MII (autosel)
    dd PCNET32_PORT_10BT ; 12 10BaseT
    dd PCNET32_PORT_MII or PCNET32_PORT_100 ; 13 MII 100BaseTx
    dd PCNET32_PORT_MII or PCNET32_PORT_100 or PCNET32_PORT_FD ; 14 MII 100BaseTx-FD
    dd PCNET32_PORT_ASEL ; 15 not supported
endg

PCNET32_WIO_RDP    = 0x10
PCNET32_WIO_RAP    = 0x12
PCNET32_WIO_RESET  = 0x14
PCNET32_WIO_BDP    = 0x16
PCNET32_DWIO_RDP   = 0x10
PCNET32_DWIO_RAP   = 0x14
PCNET32_DWIO_RESET = 0x18
PCNET32_DWIO_BDP   = 0x1c
PCNET32_TOTAL_SIZE = 0x20

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_wio_read_csr ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = index
;-----------------------------------------------------------------------------------------------------------------------
;< eax = data
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_WIO_RAP]
        mov     ax, bx
        out     dx, ax
        lea     edx, [ebp + PCNET32_WIO_RDP]
        in      ax, dx
        and     eax, 0xffff
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_wio_write_csr ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = data
;> ebx = index
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_WIO_RAP]
        xchg    eax, ebx
        out     dx, ax
        xchg    eax, ebx
        lea     edx, [ebp + PCNET32_WIO_RDP]
        out     dx, ax
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_wio_read_bcr ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = index
;-----------------------------------------------------------------------------------------------------------------------
;< eax = data
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_WIO_RAP]
        mov     ax, bx
        out     dx, ax
        lea     edx, [ebp + PCNET32_WIO_BDP]
        in      ax, dx
        and     eax, 0xffff
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_wio_write_bcr ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = data
;> ebx = index
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_WIO_RAP]
        xchg    eax, ebx
        out     dx, ax
        xchg    eax, ebx
        lea     edx, [ebp + PCNET32_WIO_BDP]
        out     dx, ax
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_wio_read_rap ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_WIO_RAP]
        in      ax, dx
        and     eax, 0xffff
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_wio_write_rap ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = val
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_WIO_RAP]
        out     dx, ax
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_wio_reset ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        push    eax
        lea     edx, [ebp + PCNET32_WIO_RESET]
        in      ax, dx
        pop     eax
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_wio_check ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        mov     ax, 88
        lea     edx, [ebp + PCNET32_WIO_RAP]
        out     dx, ax
        nop
        nop
        in      ax, dx
        cmp     ax, 88
        sete    al
        pop     edx
        ret
kendp

iglobal
  pcnet32_wio:
    dd pcnet32_wio_read_csr
    dd pcnet32_wio_write_csr
    dd pcnet32_wio_read_bcr
    dd pcnet32_wio_write_bcr
    dd pcnet32_wio_read_rap
    dd pcnet32_wio_write_rap
    dd pcnet32_wio_reset
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_dwio_read_csr ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = index
;-----------------------------------------------------------------------------------------------------------------------
;< eax = data
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_DWIO_RAP]
        mov     ebx, eax
        out     dx, eax
        lea     edx, [ebp + PCNET32_DWIO_RDP]
        in      eax, dx
        and     eax, 0xffff
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_dwio_write_csr ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = index
;> eax = data
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_DWIO_RAP]
        xchg    eax, ebx
        out     dx, eax
        lea     edx, [ebp + PCNET32_DWIO_RDP]
        xchg    eax, ebx
        out     dx, eax
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_dwio_read_bcr ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = index
;-----------------------------------------------------------------------------------------------------------------------
;< eax = data
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_DWIO_RAP]
        mov     ebx, eax
        out     dx, eax
        lea     edx, [ebp + PCNET32_DWIO_BDP]
        in      eax, dx
        and     eax, 0xffff
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_dwio_write_bcr ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = index
;> eax = data
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_DWIO_RAP]
        xchg    eax, ebx
        out     dx, eax
        lea     edx, [ebp + PCNET32_DWIO_BDP]
        xchg    eax, ebx
        out     dx, eax
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_dwio_read_rap ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_DWIO_RAP]
        in      eax, dx
        and     eax, 0xffff
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_dwio_write_rap ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = val
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [ebp + PCNET32_DWIO_RAP]
        out     dx, eax
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_dwio_reset ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        push    eax
        lea     edx, [ebp + PCNET32_DWIO_RESET]
        in      eax, dx
        pop     eax
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_dwio_check ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        lea     edx, [PCNET32_DWIO_RAP]
        mov     eax, 88
        out     dx, eax
        nop
        nop
        in      eax, dx
        and     eax, 0xffff
        cmp     eax, 88
        sete    al
        pop     edx
        ret
kendp

iglobal
  pcnet32_dwio:
    dd pcnet32_dwio_read_csr
    dd pcnet32_dwio_write_csr
    dd pcnet32_dwio_read_bcr
    dd pcnet32_dwio_write_bcr
    dd pcnet32_dwio_read_rap
    dd pcnet32_dwio_write_rap
    dd pcnet32_dwio_reset
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_init_ring ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [pcnet32_private.tx_full], 0
        mov     [pcnet32_private.cur_rx], 0
        mov     [pcnet32_private.cur_tx], 0
        mov     [pcnet32_private.dirty_rx], 0
        mov     [pcnet32_private.dirty_tx], 0
        mov     edi, pcnet32_rx_ring
        mov     ecx, PCNET32_RX_RING_SIZE
        mov     ebx, pcnet32_rxb
        sub     ebx, OS_BASE

  .rx_init:
        mov     [edi + pcnet32_rx_head.base], ebx
        mov     [edi + pcnet32_rx_head.buf_length], PCNET32_PKT_BUF_SZ_NEG
        mov     [edi + pcnet32_rx_head.status], 0x8000
        add     ebx, PCNET32_PKT_BUF_SZ
;       inc     ebx
        add     edi, 16
        loop    .rx_init
        mov     edi, pcnet32_tx_ring
        mov     ecx, PCNET32_TX_RING_SIZE

  .tx_init:
        mov     [edi + pcnet32_tx_head.base], 0
        mov     [edi + pcnet32_tx_head.status], 0
        add     edi, 16
        loop    .tx_init
        mov     [pcnet32_private.tlen_rlen], PCNET32_TX_RING_LEN_BITS or PCNET32_RX_RING_LEN_BITS
        mov     esi, node_addr
        mov     edi, pcnet32_private.phys_addr
        cld
        movsd
        movsw
        mov     eax, pcnet32_rx_ring
        sub     eax, OS_BASE
        mov     [pcnet32_private.rx_ring], eax

        mov     eax, pcnet32_tx_ring
        sub     eax, OS_BASE
        mov     [pcnet32_private.tx_ring], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_reset ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; Reset PCNET32
        mov     ebp, [io_addr]
        call    [pcnet32_access.reset]
        ; set 32bit mode
        mov     ebx, 20
        mov     eax, 2
        call    [pcnet32_access.write_bcr]
        ; set/reset autoselect bit
        mov     ebx, 2
        call    [pcnet32_access.read_bcr]
        and     eax, not 2
        test    [pcnet32_private.options], PCNET32_PORT_ASEL
        jz      .L1
        or      eax, 2

  .L1:
        call    [pcnet32_access.write_bcr]
        ; Handle full duplex setting
        cmp     [pcnet32_private.full_duplex], 0
        je      .L2
        mov     ebx, 9
        call    [pcnet32_access.read_bcr]
        and     eax, not 3
        test    [pcnet32_private.options], PCNET32_PORT_FD
        jz      .L3
        or      eax, 1
        cmp     [pcnet32_private.options], PCNET32_PORT_FD or PCNET32_PORT_AUI
        jne     .L4
        or      eax, 2
        jmp     .L4

  .L3:
        test    [pcnet32_private.options], PCNET32_PORT_ASEL
        jz      .L4
        cmp     [pcnet32_private.chip_version], 0x2627
        jne     .L4
        or      eax, 3

  .L4:
        mov     ebx, 9
        call    [pcnet32_access.write_bcr]

  .L2:
        ; set/reset GPSI bit
        mov     ebx, 124
        call    [pcnet32_access.read_csr]
        mov     ecx, [pcnet32_private.options]
        and     ecx, PCNET32_PORT_PORTSEL
        cmp     ecx, PCNET32_PORT_GPSI
        jne     .L5
        or      eax, 0x10

  .L5:
        call    [pcnet32_access.write_csr]
        cmp     [pcnet32_private.mii], 0
        je      .L6
        test    [pcnet32_private.options], PCNET32_PORT_ASEL
        jnz     .L6
        mov     ebx, 32
        call    [pcnet32_access.read_bcr]
        and     eax, not 0x38
        test    [pcnet32_private.options], PCNET32_PORT_FD
        jz      .L7
        or      eax, 0x10

  .L7:
        test    [pcnet32_private.options], PCNET32_PORT_100
        jz      .L8
        or      eax, 0x08

  .L8:
        call    [pcnet32_access.write_bcr]
        jmp     .L9

  .L6:
        test    [pcnet32_private.options], PCNET32_PORT_ASEL
        jz      .L9
        mov     ebx, 32
;       klog_   LOG_DEBUG, "ASEL, enable auto-negotiation\n"
        call    [pcnet32_access.read_bcr]
        and     eax, not 0x98
        or      eax, 0x20
        call    [pcnet32_access.write_bcr]

  .L9:
        cmp     [pcnet32_private.ltint], 0
        je      .L10
        mov     ebx, 5
        call    [pcnet32_access.read_csr]
        or      eax, 1 shl 14
        call    [pcnet32_access.write_csr]

  .L10:
        mov     eax, [pcnet32_private.options]
        and     eax, PCNET32_PORT_PORTSEL
        shl     eax, 7
        mov     [pcnet32_private.mode], ax
        mov     [pcnet32_private.filter], 0xffffffff
        mov     [pcnet32_private.filter + 4], 0xffffffff
        call    pcnet32_init_ring
        mov     ebx, 1
        mov     eax, pcnet32_private
        sub     eax, OS_BASE
        and     eax, 0xffff
        call    [pcnet32_access.write_csr]
        mov     eax, pcnet32_private
        sub     eax, OS_BASE
        mov     ebx, 2
        shr     eax, 16
        call    [pcnet32_access.write_csr]
        mov     ebx, 4
        mov     eax, 0x0915
        call    [pcnet32_access.write_csr]
        mov     ebx, 0
        mov     eax, 1
        call    [pcnet32_access.write_csr]
        mov     ecx, 100

  .L11:
        xor     ebx, ebx
        call    [pcnet32_access.read_csr]
        test    ax, 0x100
        jnz     .L12
        loop    .L11

  .L12:
;       klog_   LOG_DEBUG, "hardware reset\n"
        xor     ebx, ebx
        mov     eax, 0x0002
        call    [pcnet32_access.write_csr]
        xor     ebx, ebx
        call    [pcnet32_access.read_csr]
;       klog_   LOG_DEBUG, "PCNET reset complete\n"
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_adjust_pci_device ;///////////////////////////////////////////////////////////////////////////////////////
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
;       mov     al, 1 ; read a byte
;       mov     bh, [pci_dev]
;       mov     ah, [pci_bus]
;       mov     bl, 0x0d ; from Lantency Timer Register
;       call    pci_read_reg
        ; see if its aat least 64 clocks
;       cmp     ax, 64
;       jge     .Done
        ; Set latency to 32 clocks
;       mov     cx, 64 ; value to write
;       mov     bh, [pci_dev]
;       mov     al, 1 ; write a byte
;       mov     ah, [pci_bus]
;       mov     bl, 0x0d ; to Lantency Timer Register
;       call    pci_write_reg

  .Done:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_probe ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, [io_addr]
        call    pcnet32_wio_reset
        xor     ebx, ebx
        call    pcnet32_wio_read_csr
        cmp     eax, 4
        jne     .try_dwio
        call    pcnet32_wio_check
        and     al, al
        jz      .try_dwio
;       klog_   LOG_DEBUG, "Using WIO\n"
        mov     esi, pcnet32_wio
        jmp     .L1

  .try_dwio:
        call    pcnet32_dwio_reset
        xor     ebx, ebx
        call    pcnet32_dwio_read_csr
        cmp     eax, 4
        jne     .no_dev
        call    pcnet32_dwio_check
        and     al, al
        jz      .no_dev
;       klog_   LOG_DEBUG, "Using DWIO\n"
        mov     esi, pcnet32_dwio
        jmp     .L1

  .no_dev:
        klog_   LOG_DEBUG, "PCNET32 not found\n"
        ret

  .L1:
        mov     edi, pcnet32_access
        mov     ecx, 7
        cld
        rep     movsd
        mov     ebx, 88
        call    [pcnet32_access.read_csr]
        mov     ecx, eax
        mov     ebx, 89
        call    [pcnet32_access.read_csr]
        shl     eax, 16
        or      eax, ecx
        mov     ecx, eax
        and     ecx, 0xfff
        cmp     ecx, 3
        jne     .no_dev
        shr     eax, 12
        and     eax, 0xffff
        mov     [pcnet32_private.chip_version], eax
;       klog_   LOG_DEBUG, "PCNET32 chip version OK\n"
        mov     [pcnet32_private.fdx], 0
        mov     [pcnet32_private.mii], 0
        mov     [pcnet32_private.fset], 0
        mov     [pcnet32_private.dxsuflo], 0
        mov     [pcnet32_private.ltint], 0
        mov     eax, [pcnet32_private.chip_version]
        cmp     eax, 0x2420
        je      .L2
        cmp     eax, 0x2430
        je      .L3
        cmp     eax, 0x2621
        je      .L4
        cmp     eax, 0x2623
        je      .L5
        cmp     eax, 0x2624
        je      .L6
        cmp     eax, 0x2625
        je      .L7
        cmp     eax, 0x2626
        je      .L8
        cmp     eax, 0x2627
        je      .L9
        klog_   LOG_ERROR, "Invalid chip rev\n"
        jmp     .no_dev

  .L2:
;       klog_   LOG_DEBUG, "PCnet/PCI 79C970\n"
        jmp     .L10

  .L3:
;       klog_   LOG_DEBUG, "PCnet/PCI 79C970\n"
        jmp     .L10

  .L4:
;       klog_   LOG_DEBUG, "PCnet/PCI II 79C970A\n"
        mov     [pcnet32_private.fdx], 1
        jmp     .L10

  .L5:
;       klog_   LOG_DEBUG, "PCnet/FAST 79C971\n"
        mov     [pcnet32_private.fdx], 1
        mov     [pcnet32_private.mii], 1
        mov     [pcnet32_private.fset], 1
        mov     [pcnet32_private.ltint], 1
        jmp     .L10

  .L6:
;       klog_   LOG_DEBUG, "PCnet/FAST+ 79C972\n"
        mov     [pcnet32_private.fdx], 1
        mov     [pcnet32_private.mii], 1
        mov     [pcnet32_private.fset], 1
        jmp     .L10

  .L7:
;       klog_   LOG_DEBUG, "PCnet/FAST III 79C973\n"
        mov     [pcnet32_private.fdx], 1
        mov     [pcnet32_private.mii], 1
        jmp     .L10

  .L8:
;       klog_   LOG_DEBUG, "PCnet/Home 79C978\n"
        mov     [pcnet32_private.fdx], 1
        mov     ebx, 49
        call    [pcnet32_access.read_bcr]
        call    [pcnet32_access.write_bcr]
        jmp     .L10

  .L9:
;       klog_   LOG_DEBUG, "PCnet/FAST III 79C975\n"
        mov     [pcnet32_private.fdx], 1
        mov     [pcnet32_private.mii], 1

  .L10:
        cmp     [pcnet32_private.fset], 1
        jne     .L11
        mov     ebx, 18
        call    [pcnet32_access.read_bcr]
        or      eax, 0x800
        call    [pcnet32_access.write_bcr]
        mov     ebx, 80
        call    [pcnet32_access.read_csr]
        and     eax, 0xc00
        or      eax, 0xc00
        call    [pcnet32_access.write_csr]
        mov     [pcnet32_private.dxsuflo], 1
        mov     [pcnet32_private.ltint], 1

  .L11:
        ; read MAC
        mov     edi, node_addr
        mov     edx, ebp
        mov     ecx, 6

  .Lmac:
        in      al, dx
        stosb
        inc     edx
        loop    .Lmac
;       klog_   LOG_DEBUG, "MAC read\n"
        call    pcnet32_adjust_pci_device
;       klog_   LOG_DEBUG, "PCI done\n"
        mov     eax, PCNET32_PORT_ASEL
        mov     [pcnet32_private.options], eax
        mov     [pcnet32_private.mode], 0x0003
        mov     [pcnet32_private.tlen_rlen], PCNET32_TX_RING_LEN_BITS or PCNET32_RX_RING_LEN_BITS
        mov     esi, node_addr
        mov     edi, pcnet32_private.phys_addr
        cld
        movsd
        movsw
        mov     [pcnet32_private.filter], 0
        mov     [pcnet32_private.filter + 4], 0
        mov     eax, pcnet32_rx_ring
        sub     eax, OS_BASE
        mov     [pcnet32_private.rx_ring], eax

        mov     eax, pcnet32_tx_ring
        sub     eax, OS_BASE
        mov     [pcnet32_private.tx_ring], eax
;       klog_   LOG_DEBUG, "Switching to 32\n"
        mov     ebx, 20
        mov     eax, 2
        call    [pcnet32_access.write_bcr]
        mov     ebx, 1
        mov     eax, pcnet32_private and 0xffff
        call    [pcnet32_access.write_csr]
        mov     ebx, 2
        mov     eax, (pcnet32_private shr 16) and 0xffff
        call    [pcnet32_access.write_csr]
        mov     ebx, 0
        mov     eax, 1
        call    [pcnet32_access.write_csr]
        mov     esi, 1
        call    delay_ms
        call    pcnet32_reset
        mov     eax, [pci_data]
        mov     [eth_status], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_poll ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        xor     ax, ax
        mov     [eth_rx_data_len], ax
        mov     eax, [pcnet32_private.cur_rx]
        and     eax, PCNET32_RX_RING_MOD_MASK
        mov     ebx, eax
        imul    esi, eax, PCNET32_PKT_BUF_SZ
        add     esi, pcnet32_rxb
        shl     ebx, 4
        add     ebx, pcnet32_rx_ring
        mov     cx, [ebx + pcnet32_rx_head.status]
        test    cx, 0x8000
        jnz     .L1
        cmp     ch, 3
        jne     .L1
        mov     ecx, [ebx + pcnet32_rx_head.msg_length]
        and     ecx, 0xfff
        sub     ecx, 4
        mov     [eth_rx_data_len], cx
;       klog_   LOG_DEBUG, "PCNETRX: %ub\n", cx
        push    ecx
        shr     ecx, 2
        mov     edi, Ether_buffer
        cld
        rep     movsd
        pop     ecx
        and     ecx, 3
        rep     movsb
        mov     [ebx + pcnet32_rx_head.buf_length], PCNET32_PKT_BUF_SZ_NEG
        or      [ebx + pcnet32_rx_head.status], 0x8000
        inc     [pcnet32_private.cur_rx]

  .L1:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc pcnet32_xmit ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi = Pointer to 48 bit destination address
;> bx = Type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        push    esi
        push    ebx
        push    ecx
;       klog_   LOG_DEBUG, "PCNETTX\n"
        mov     esi, edi
        mov     edi, [pcnet32_private.cur_tx]
        imul    edi, PCNET32_PKT_BUF_SZ
        add     edi, pcnet32_txb ; edi=ptxb
        mov     eax, edi
        cld     ; copy MAC
        movsd
        movsw
        mov     esi, node_addr
        cld
        movsd
        movsw
        mov     [edi], bx
        add     edi, 2
        mov     esi, [esp + 8]
        mov     ecx, [esp]
        push    ecx
        shr     ecx, 2
        cld
        rep     movsd
        pop     ecx
        and     ecx, 3
        rep     movsb
;       mov     ecx, [esp]
;       add     ecx, 14 ; ETH_HLEN
;       xor     eax, eax
        ; pad to min length (60=ETH_ZLEN)
;       cmp     ecx, 60
;       jae     .L1
;       sub     ecx, 60
;       cld
;       rep     stosb

; .L1:
        mov     edi, pcnet32_tx_ring + 0 ; entry=0
        mov     ecx, [esp]
        add     ecx, 14
        cmp     cx, 60
        jae     .L1
        mov     cx, 60

  .L1:
        neg     cx
        mov     [edi + pcnet32_tx_head.length], cx
        mov     [edi + pcnet32_tx_head.misc], 0
        sub     eax, OS_BASE
        mov     [edi + pcnet32_tx_head.base], eax
        mov     [edi + pcnet32_tx_head.status], 0x8300
        ; trigger an immediate send poll
        mov     ebx, 0
        mov     eax, 0x0008 ; 0x0048
        mov     ebp, [io_addr]
        call    [pcnet32_access.write_csr]
        mov     [pcnet32_private.cur_tx], 0
        ; wait for TX to complete
        mov     ecx, [timer_ticks] ; [0xfdf0]
        add     ecx, 1 * KCONFIG_SYS_TIMER_FREQ

  .L2:
        mov     ax, [edi + pcnet32_tx_head.status]
        test    ax, 0x8000
        jz      .L3
        cmp     ecx, [timer_ticks] ; [0xfdf0]
        jb      .L4
        mov     esi, 10
        call    delay_ms
        jnz     .L2

  .L4:
        klog_   LOG_ERROR, "PCNET: Send timeout\n"

  .L3:
        mov     [edi + pcnet32_tx_head.base], 0
        pop     ecx
        pop     ebx
        pop     esi
        pop     edi
        ret
kendp
