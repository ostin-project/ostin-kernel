;;======================================================================================================================
;;///// ip.asm ///////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
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

; IP underlying protocols numbers
PROTOCOL_ICMP = 1
PROTOCOL_TCP  = 6
PROTOCOL_UDP  = 17

struct ip_packet_t
  version_and_ihl           db ? ; +00 - Version[0-3 bits] and IHL(header length)[4-7 bits]
  type_of_service           db ? ; +01
  total_length              dw ? ; +02
  identification            dw ? ; +04
  flags_and_fragment_offset dw ? ; +06 - Flags[0-2] and FragmentOffset[3-15]
  ttl_secs                  db ? ; +08
  protocol                  db ? ; +09
  header_checksum           dw ? ; +10
  src_ip                    dd ? ; +12
  dst_ip                    dd ? ; +16
  data_or_optional          dd ? ; +20
ends

;
;   IP Packet after reception - Normal IP packet format
;
;            0               1               2               3
;     0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
;
;    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; 0  |Version|  IHL  |Type of Service|       Total Length            |
;    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; 4  |         Identification        |Flags|      Fragment Offset    |
;    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; 8  |  Time to Live |    Protocol   |         Header Checksum       |
;    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; 12 |                       Source Address                          |
;    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; 16 |                    Destination Address                        |
;    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; 20 |      Data                                                     |
;    +-+-+-..........                                               -+
;
;
; attention! according to RFC 791 IP packet may have 'options' sections,
; so we can't simply think, that data have offset 20. We must calculate offset from
; IHL field
;
macro GET_IHL reg, header_addr
{
        movzx   reg, byte[header_addr]

        ; we need 4-7 bits, so....
        and     reg, 0x0000000f

        ; IHL keeps number of octets, so we need to << 2 'reg'
        shl     reg, 2
}

include "tcp.asm"
include "udp.asm"
include "icmp.asm"

;-----------------------------------------------------------------------------------------------------------------------
proc ip_rx stdcall ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Processes all IP-packets received by the network layer
;? It calls the appropriate protocol handler
;-----------------------------------------------------------------------------------------------------------------------
;# This is a kernel function, called by stack_handler
;-----------------------------------------------------------------------------------------------------------------------
local buffer_number dd ?
;-----------------------------------------------------------------------------------------------------------------------
        ; Look for a buffer to tx
        mov     eax, IPIN_QUEUE
        call    dequeue
        cmp     ax, NO_BUFFER
        je      .exit ; Exit if no buffer available

        mov     [buffer_number], eax ; save buffer number

        ; convert buffer pointer eax to the absolute address
        imul    eax, IPBUFFSIZE
        add     eax, IPbuffs

        mov     ebx, eax ; ebx=pointer to ip_packet_t

;       KLog    LOG_DEBUG, "ip_rx - proto: %u\n", [ebx + ip_packet_t.Protocol]:1

        ; Validate the IP checksum
        mov     dx, word[ebx + ip_packet_t.header_checksum]
        xchg    dh, dl ; Get the checksum in intel format

        mov     [ebx + ip_packet_t.header_checksum], 0 ; clear checksum field - need to when recalculating checksum
        ;  this needs two data pointers and two size #.
        ;  2nd pointer can be of length 0

        GET_IHL ecx, ebx + ip_packet_t.version_and_ihl ; get packet length in ecx
        stdcall checksum_jb, ebx, ecx ; buf_ptr, buf_size
        cmp     dx, ax

;       KLog    LOG_DEBUG, "ip_rx - checksums: %x - %x\n", dx, ax

        jnz     .dump.1 ; if CHECKSUM isn't valid then dump packet
        mov     edx, ebx ; EDX (IP-BUFFER POINTER) WILL BE USED FOR *_rx HANDLERS BELOW!!!

;       KLog    LOG_DEBUG, "ip_rx - dest: %x - %x\n", [ebx + ip_packet_t.DestinationAddress], [stack_ip]

        ; Validate the IP address, if it isn't broadcast
        mov     eax, [stack_ip]
        cmp     dword[ebx + ip_packet_t.dst_ip], eax
        je      @f

        ; If the IP address is 255.255.255.255, accept it
        ; - it is a broadcast packet, which we need for dhcp

        mov     eax, [ebx + ip_packet_t.dst_ip]
        cmp     eax, 0xffffffff
        je      @f
        mov     ecx, [stack_ip]
        and     eax, [subnet_mask]
        and     ecx, [subnet_mask]
        cmp     eax, ecx
        jne     .dump.2
        mov     eax, [ebx + ip_packet_t.dst_ip]
        or      eax, [subnet_mask]
        cmp     eax, 0xffffffff
        jne     .dump.2

    @@: mov     al, [ebx + ip_packet_t.version_and_ihl]
        and     al, 0x0f ; get IHL(header length)
        cmp     al, 0x05 ; if IHL!= 5*4(20 bytes)
;       KLog    LOG_DEBUG, "ip_rx - ihl: %x - 05\n", al
        jnz     .dump.3 ; then dump it

;       KLog    LOG_DEBUG, "ip_rx - ttl: %x - 00\n", [ebx + ip_packet_t.TimeToLive]:2

        cmp     [ebx + ip_packet_t.ttl_secs], 0
        je      .dump.4 ; if TTL==0 then dump it

        mov     ax, [ebx + ip_packet_t.flags_and_fragment_offset]
        and     ax, 0xffbf ; get flags
;       KLog    LOG_DEBUG, "ip_rx - flags: %x - 0000\n", ax
        cmp     ax, 0 ; if some flags was set then we dump this packet
        jnz     .dump.5 ; the flags should be used for fragmented packets

        ; Check the protocol, and call the appropriate handler
        ; Each handler will re-use or free the queue buffer as appropriate

        mov     al, [ebx + ip_packet_t.protocol]

        cmp     al , PROTOCOL_TCP
        jne     .not_tcp
;       KLog    LOG_DEBUG, "ip_rx - TCP packet\n"
        mov     eax, dword[buffer_number]
        call    tcp_rx
        jmp     .exit

  .not_tcp:
        cmp     al, PROTOCOL_UDP
        jne     .not_udp
;       KLog    LOG_DEBUG, "ip_rx - UDP packet\n"
        mov     eax, dword[buffer_number]
        call    udp_rx
        jmp     .exit

  .not_udp:
        cmp     al, PROTOCOL_ICMP
        jne     .dump.6 ; protocol ain't supported

;       KLog    LOG_DEBUG, "ip_rx - ICMP packet\n"
;       GET_IHL ecx, ebx + ip_packet_t.VersionAndIHL ; get packet length in ecx
        mov     eax, dword[buffer_number]
        stdcall icmp_rx, eax, ebx, ecx ; buffer_number, IPPacketBase, IPHeaderLength
        jmp     .exit

  .dump.1:
        KLog    LOG_WARNING, "ip_rx - dumped (checksum: 0x%x-0x%x)\n", dx, ax
        jmp     .dump.x

  .dump.2:
        KLog    LOG_WARNING, "ip_rx - dumped (ip: %u.%u.%u.%u)\n", [ebx + ip_packet_t.dst_ip + 0]:1, \
                [ebx + ip_packet_t.dst_ip + 1]:1, [ebx + ip_packet_t.dst_ip + 2]:1, [ebx + ip_packet_t.dst_ip + 3]:1
        jmp     .dump.x

  .dump.3:
        KLog    LOG_WARNING, "ip_rx - dumped (ihl: %u)\n", al
        jmp     .dump.x

  .dump.4:
        KLog    LOG_WARNING, "ip_rx - dumped (ttl: %u)\n", [ebx + ip_packet_t.ttl_secs]
        jmp     .dump.x

  .dump.5:
        KLog    LOG_WARNING, "ip_rx - dumped (flags: 0x%x)\n", ax
        jmp     .dump.x

  .dump.6:
        KLog    LOG_WARNING, "ip_rx - dumped (proto: %u)\n", [ebx + ip_packet_t.protocol]:1

  .dump.x:
        inc     dword[dumped_rx_count]
        mov     eax, [buffer_number]
        call    freeBuff

  .exit:
        ret
endp
