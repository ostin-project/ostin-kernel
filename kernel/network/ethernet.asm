;;======================================================================================================================
;;///// ethernet.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
;; (c) 2000-2004 MenuetOS <http://menuetos.net/>
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
;# * PCI bus scanning code - etherboot 5.0.6 project
;;======================================================================================================================

ETHER_IP   = 0x0008 ; Reversed from 0800 for intel
ETHER_ARP  = 0x0608 ; Reversed from 0806 for intel
ETHER_RARP = 0x3580

struct eth_frame_t
  dst_mac dp ? ; destination MAC-address [6 bytes]
  src_mac dp ? ; source MAC-address [6 bytes]
  type    dw ? ; type of the upper-layer protocol [2 bytes]
  data    db ? ; data [46-1500 bytes]
ends

virtual at Ether_buffer
  ETH_FRAME eth_frame_t
end virtual

; Some useful information on data structures

; Ethernet Packet - ARP Request example
;
; 0                   1                   2                   3
; 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
;
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |       Dest   H/W Address                                      |
; |                    ( 14 byte header )                         |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |                               |     Source     H/W Address    |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |                                                               |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |    Protocol - ARP 08  06      |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |  H/W Type  00           01    |  Protocol Type   08 00        |
; |                   ( ARP Request packet )                      |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; | HLen    0x06  | PLen    0x04  |    OpCode        00   01      |
; |               ( 0001 for request, 0002 for reply )            |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; | Source Hardware Address ( MAC Address )                       |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |                               |  Source IP Address            |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |                               | Destination Hardware Address  |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |                                                               |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; | Destination IP Address                                        |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

; Include individual drivers source files at this point.
; If you create a new driver, include it below.

match =1, KCONFIG_NET_DRIVER_E3C59X
{
include "drivers/3c59x.asm"
}
match =1, KCONFIG_NET_DRIVER_FORCEDETH
{
include "drivers/forcedeth.asm"
}
match =1, KCONFIG_NET_DRIVER_I8255X
{
include "drivers/i8255x.asm"
}
match =1, KCONFIG_NET_DRIVER_PCNET32
{
include "drivers/pcnet32.asm"
}
match =1, KCONFIG_NET_DRIVER_R6040
{
include "drivers/r6040.asm"
}
match =1, KCONFIG_NET_DRIVER_RTL8029
{
include "drivers/rtl8029.asm"
}
match =1, KCONFIG_NET_DRIVER_RTL8139
{
include "drivers/rtl8139.asm"
}
match =1, KCONFIG_NET_DRIVER_RTL8169
{
include "drivers/rtl8169.asm"
}
match =1, KCONFIG_NET_DRIVER_SIS900
{
include "drivers/sis900.asm"
}

; PCICards
; ========
; PCI vendor and hardware types for hardware supported by the above drivers
; If you add a driver, ensure you update this datastructure, otherwise the
; card will not be probed.
; Each driver is defined by 4 double words. These are
;   PCIVendorDevice  probeFunction ResetFunction PollFunction transmitFunction
; The last entry must be kept at all zeros, to indicate the end of the list
; As a PCI driver may support more than one hardware implementation, there may
; be several lines which refer to the same functions.
; The first driver found on the PCI bus will be the one used.

struct net.driver.vftbl_t
  probe       dd ?
  reset       dd ?
  poll        dd ?
  transmit    dd ?
  check_cable dd ?
ends

struct net.device_t
  id    dd ?
  vftbl dd ?
ends

iglobal
  PCICards:

if KCONFIG_NET_DRIVER_I8255X
    dd 0x12098086, net.i8255x.vftbl
    dd 0x10298086, net.i8255x.vftbl
    dd 0x12298086, net.i8255x.vftbl
    dd 0x10308086, net.i8255x.vftbl
    dd 0x24498086, net.i8255x.vftbl
end if

if KCONFIG_NET_DRIVER_RTL8029
    dd 0x802910ec, net.rtl8029.vftbl
end if

if KCONFIG_NET_DRIVER_RTL8139
    dd 0x813910ec, net.rtl8139.vftbl
    dd 0x813810ec, net.rtl8139.vftbl
    dd 0x12111113, net.rtl8139.vftbl
    dd 0x13601500, net.rtl8139.vftbl
    dd 0x13604033, net.rtl8139.vftbl
    dd 0x13001186, net.rtl8139.vftbl
    dd 0x13401186, net.rtl8139.vftbl
    dd 0xab0613d1, net.rtl8139.vftbl
    dd 0xa1171259, net.rtl8139.vftbl
    dd 0xa11e1259, net.rtl8139.vftbl
    dd 0xab0614ea, net.rtl8139.vftbl
    dd 0xab0714ea, net.rtl8139.vftbl
    dd 0x123411db, net.rtl8139.vftbl
    dd 0x91301432, net.rtl8139.vftbl
    dd 0x101202ac, net.rtl8139.vftbl
    dd 0x0106018a, net.rtl8139.vftbl
    dd 0x1211126c, net.rtl8139.vftbl
    dd 0x81391743, net.rtl8139.vftbl
    dd 0x8139021b, net.rtl8139.vftbl
end if

if KCONFIG_NET_DRIVER_RTL8169
    dd 0x816810ec, net.rtl8169.vftbl
    dd 0x816910ec, net.rtl8169.vftbl
    dd 0x011616ec, net.rtl8169.vftbl
    dd 0x43001186, net.rtl8169.vftbl
    dd 0x816710ec, net.rtl8169.vftbl
end if

if KCONFIG_NET_DRIVER_E3C59X
    dd 0x590010b7, net.3c59x.vftbl
    dd 0x592010b7, net.3c59x.vftbl
    dd 0x597010b7, net.3c59x.vftbl
    dd 0x595010b7, net.3c59x.vftbl
    dd 0x595110b7, net.3c59x.vftbl
    dd 0x595210b7, net.3c59x.vftbl
    dd 0x900010b7, net.3c59x.vftbl
    dd 0x900110b7, net.3c59x.vftbl
    dd 0x900410b7, net.3c59x.vftbl
    dd 0x900510b7, net.3c59x.vftbl
    dd 0x900610b7, net.3c59x.vftbl
    dd 0x900a10b7, net.3c59x.vftbl
    dd 0x905010b7, net.3c59x.vftbl
    dd 0x905110b7, net.3c59x.vftbl
    dd 0x905510b7, net.3c59x.vftbl
    dd 0x905810b7, net.3c59x.vftbl
    dd 0x905a10b7, net.3c59x.vftbl
    dd 0x920010b7, net.3c59x.vftbl
    dd 0x980010b7, net.3c59x.vftbl
    dd 0x980510b7, net.3c59x.vftbl
    dd 0x764610b7, net.3c59x.vftbl
    dd 0x505510b7, net.3c59x.vftbl
    dd 0x605510b7, net.3c59x.vftbl
    dd 0x605610b7, net.3c59x.vftbl
    dd 0x5b5710b7, net.3c59x.vftbl
    dd 0x505710b7, net.3c59x.vftbl
    dd 0x515710b7, net.3c59x.vftbl
    dd 0x525710b7, net.3c59x.vftbl
    dd 0x656010b7, net.3c59x.vftbl
    dd 0x656210b7, net.3c59x.vftbl
    dd 0x656410b7, net.3c59x.vftbl
    dd 0x450010b7, net.3c59x.vftbl
end if

if KCONFIG_NET_DRIVER_SIS900
    dd 0x09001039, net.sis900.vftbl
    dd 0x70161039, net.sis900.vftbl
end if

if KCONFIG_NET_DRIVER_PCNET32
    dd 0x20001022, net.pcnet32.vftbl
    dd 0x26251022, net.pcnet32.vftbl
    dd 0x20011022, net.pcnet32.vftbl
end if

if KCONFIG_NET_DRIVER_FORCEDETH
    dd 0x006610de, net.forcedeth.vfbtl ; nVidia Corporation nForce2 Ethernet Controller
    dd 0x01c310de, net.forcedeth.vfbtl ; not tested
    dd 0x00d610de, net.forcedeth.vfbtl ; not tested
    dd 0x008610de, net.forcedeth.vfbtl ; not tested
    dd 0x008c10de, net.forcedeth.vfbtl ; not tested
    dd 0x00e610de, net.forcedeth.vfbtl ; not tested
    dd 0x00df10de, net.forcedeth.vfbtl ; not tested
    dd 0x005610de, net.forcedeth.vfbtl ; not tested
    dd 0x005710de, net.forcedeth.vfbtl ; not tested
    dd 0x003710de, net.forcedeth.vfbtl ; not tested
    dd 0x003810de, net.forcedeth.vfbtl ; not tested
    dd 0x026810de, net.forcedeth.vfbtl ; not tested
    dd 0x026910de, net.forcedeth.vfbtl ; not tested
    dd 0x037210de, net.forcedeth.vfbtl ; not tested
    dd 0x037310de, net.forcedeth.vfbtl ; not tested
    dd 0x03e510de, net.forcedeth.vfbtl ; not tested
    dd 0x03e610de, net.forcedeth.vfbtl ; not tested
    dd 0x03ee10de, net.forcedeth.vfbtl ; not tested
    dd 0x03ef10de, net.forcedeth.vfbtl ; not tested
    dd 0x045010de, net.forcedeth.vfbtl ; not tested
    dd 0x045110de, net.forcedeth.vfbtl ; not tested
    dd 0x045210de, net.forcedeth.vfbtl ; not tested
    dd 0x045310de, net.forcedeth.vfbtl ; not tested
    dd 0x054c10de, net.forcedeth.vfbtl ; not tested
    dd 0x054d10de, net.forcedeth.vfbtl ; not tested
    dd 0x054e10de, net.forcedeth.vfbtl ; not tested
    dd 0x054f10de, net.forcedeth.vfbtl ; not tested
    dd 0x07dc10de, net.forcedeth.vfbtl ; not tested
    dd 0x07dd10de, net.forcedeth.vfbtl ; not tested
    dd 0x07de10de, net.forcedeth.vfbtl ; not tested
    dd 0x07df10de, net.forcedeth.vfbtl ; not tested
    dd 0x076010de, net.forcedeth.vfbtl ; MCP77 Ethernet Controller
    dd 0x076110de, net.forcedeth.vfbtl ; not tested
    dd 0x076210de, net.forcedeth.vfbtl ; not tested
    dd 0x076310de, net.forcedeth.vfbtl ; not tested
    dd 0x0ab010de, net.forcedeth.vfbtl ; not tested
    dd 0x0ab110de, net.forcedeth.vfbtl ; not tested
    dd 0x0ab210de, net.forcedeth.vfbtl ; not tested
    dd 0x0ab310de, net.forcedeth.vfbtl ; not tested
    dd 0x0d7d10de, net.forcedeth.vfbtl ; not tested
end if

if KCONFIG_NET_DRIVER_R6040
    dd 0x604017f3, net.r6040.vfbtl
end if

  rb sizeof.net.device_t ; end of list marker, do not remove
endg

uglobal
  ; Net-stack's interface's settings
  node_addr:       db 0, 0, 0, 0, 0, 0
  gateway_ip:      dd 0
  dns_ip:          dd 0

  eth_rx_data_len  dw 0
  eth_status:      dd 0
  io_addr:         dd 0
  hdrtype:         db 0
  vendor_device:   dd 0
  pci_data:        dd 0
  pci_dev          db 0
  pci_bus          db 0

  ; These will hold pointers to the selected driver functions
  drvr_probe:      dd 0
  drvr_reset:      dd 0
  drvr_poll:       dd 0
  drvr_transmit:   dd 0
  drvr_cable:      dd 0
endg

iglobal
  broadcast_add: db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
  subnet_mask:   dd 0x00ffffff ; 255.255.255.0
endg

include "proto/arp.asm" ; arp-protocol functions

;-----------------------------------------------------------------------------------------------------------------------
proc eth_tx stdcall uses ebx esi edi ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Looks at the NET1OUT_QUEUE for data to send.
;? Stores that destination IP in a location used by the tx routine
;? Looks up the MAC address in the ARP table; stores that where
;? the tx routine can get it
;? Get the length of the data. Store that where the tx routine wants it
;? Call tx
;? Places buffer on empty queue when the tx routine finished
;-----------------------------------------------------------------------------------------------------------------------
local MACAddress dp ? ; allocate 6 bytes in the stack
;-----------------------------------------------------------------------------------------------------------------------
        ; Look for a buffer to tx
        mov     eax, NET1OUT_QUEUE
        call    dequeue
        cmp     ax, NO_BUFFER
        je      .exit ; Exit if no buffer available

        push    eax ; save buffer number

        ; convert buffer pointer eax to the absolute address
        imul    eax, IPBUFFSIZE
        add     eax, IPbuffs

        ; Extract the destination IP
        ; find the destination IP in the ARP table, get MAC
        ; store this MAC in 'MACAddress'
        mov     ebx, eax ; Save buffer address
        mov     edx, [ebx + 16] ; get destination address

        ; If the destination address is 255.255.255.255,
        ; set the MACAddress to all ones ( broadcast )
        mov     esi, broadcast_add
        lea     edi, [MACAddress]
        movsd
        movsw
        cmp     edx, 0xffffffff
        je      .send ; If it is broadcast, just send

        lea     eax, [MACAddress] ; cause this is local variable
        stdcall arp_table_manager, ARP_TABLE_IP_TO_MAC, edx, eax ; opcode, IP, MAC_ptr - Get the MAC address.

        cmp     eax, ARP_VALID_MAPPING
        je      .send

        ; No valid entry. Has the request been sent, but timed out?
        cmp     eax, ARP_RESPONSE_TIMEOUT
        je      .freebuf

  .wait_response:
        ; we wait arp-response
        ; Re-queue the packet, and exit
        pop     ebx
        mov     eax, NET1OUT_QUEUE
        call    queue ; Get the buffer back
        jmp     .exit

  .send:
        ; if ARP_VALID_MAPPING then send the packet
        lea     edi, [MACAddress] ; Pointer to 48 bit destination address
        movzx   ecx, word[ebx + 2] ; Size of IP packet to send
        xchg    ch, cl ; because mirror byte-order
        mov     esi, ebx ; Pointer to packet data
        mov     bx, ETHER_IP ; Type of packet
        push    ebp
        call    dword[drvr_transmit] ; Call the drivers transmit function
        pop     ebp

        ; OK, we have sent a packet, so increment the count
        inc     dword[ip_tx_count]

  .freebuf:
        ; And finally, return the buffer to the free queue
        pop     eax
        call    freeBuff

  .exit:
        ret
endp

;uglobal
;  ether_IP_handler_cnt dd ?
;endg

;-----------------------------------------------------------------------------------------------------------------------
kproc ether_IP_handler ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Called when an IP ethernet packet is received on the ethernet
;? Header + Data is in Ether_buffer[]
;? We just need to get a buffer from the 'free' queue, and
;? store the packet in it, then insert the packet number into the
;? IPRX queue.
;? If no queue entry is available, the packet is silently discarded
;-----------------------------------------------------------------------------------------------------------------------
;# All registers may be destroyed
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, EMPTY_QUEUE
        call    dequeue
        cmp     ax, NO_BUFFER
        je      .eiph00x

        ; convert buffer pointer eax to the absolute address
        push    eax
        mov     ecx, IPBUFFSIZE
        mul     ecx
        add     eax, IPbuffs

        mov     edi, eax

        ; get a pointer to the start of the DATA
        mov     esi, ETH_FRAME.data

        ; Now store it all away
        mov     ecx, IPBUFFSIZE / 4 ; Copy all of the available data across - worse case
        rep
        movsd

;       inc     [ether_IP_handler_cnt]
;       klog_   LOG_DEBUG, "ether_IP_handler (%u)\n", [ether_IP_handler_cnt]

        ; And finally, place the buffer in the IPRX queue
        pop     ebx
        mov     eax, IPIN_QUEUE
        call    queue

  .eiph00x:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc eth_probe ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Searches for an ethernet card. If found, the card is enabled and
;? the ethernet -> IP link established
;? This function scans the PCI bus looking for a supported device.
;? ISA bus is currently not supported.
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (no hardware found) or I/O address
;-----------------------------------------------------------------------------------------------------------------------
        ; Find a card on the PCI bus, and get it's address
        call    scan_bus ; Find the ethernet cards PIC address
        xor     eax, eax
        cmp     [io_addr], eax
        je      .ep_00x ; Return 0 in eax if no cards found

        call    dword[drvr_probe] ; Call the drivers probe function

        mov     eax, [io_addr] ; return a non zero value

  .ep_00x:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ethernet_driver ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? The ethernet RX and TX handler
;-----------------------------------------------------------------------------------------------------------------------
;# This is a kernel function, called by stack_handler
;-----------------------------------------------------------------------------------------------------------------------
        ; Do nothing if the driver is inactive
        cmp     [ethernet_active], 0
        je      .eth_exit

        call    eth_rx
        call    eth_tx

  .eth_exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc eth_rx ;//////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Polls the ethernet card for received data. Extracts if present
;? Depending on the Protocol within the packet:
;?   ARP: Pass to ARP_handler. This may result in an ARP reply being tx'ed
;?   IP: Store in an IP buffer
;-----------------------------------------------------------------------------------------------------------------------
        xor     ax, ax
        mov     [eth_rx_data_len], ax
        call    dword[drvr_poll] ; Call the drivers poll function

        mov     ax, [eth_rx_data_len]
        cmp     ax, 0
        je      .exit

        ; Check the protocol. Call appropriate handler

        mov     ax, [ETH_FRAME.type] ; The address of the protocol word

        cmp     ax, ETHER_IP
        je      .is_ip ; It's IP

        cmp     ax, ETHER_ARP
        je      .is_arp ; It is ARP

        klog_   LOG_WARNING, "eth_rx - dumped (%u)\n", ax
        inc     [dumped_rx_count]
        jmp     .exit ; If not IP or ARP, ignore

  .is_ip:
;       klog_   LOG_DEBUG, "eth_rx - IP packet\n"
        inc     dword[ip_rx_count]
        call    ether_IP_handler
        jmp     .exit

  .is_arp:
;       klog_   LOG_DEBUG, "eth_rx - ARP packet\n"
        ; At this point, the packet is still in the Ether_buffer
        call    arp_handler

  .exit:
        ret
kendp
