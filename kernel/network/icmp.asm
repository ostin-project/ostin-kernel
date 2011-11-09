;;======================================================================================================================
;;///// icmp.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2007 KolibriOS team <http://kolibrios.org/>
;; (c) 2003 MenuetOS <http://menuetos.net/>
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
;# * RFC 792 "Internet Control Message Protocol"
;;======================================================================================================================

struct icmp_packet_t
  type            db ? ; +00
  code            db ? ; +01
  checksum        dw ? ; +02
  identifier      dw ? ; +04
  sequence_number dw ? ; +06
  data            db ? ; +08
ends

; Example:
;   ECHO message format
;
;           0               1               2               3
;    0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
;   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;   |     Type      |     Code      |          Checksum             |
;   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;   |           Identifier          |        Sequence Number        |
;   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;   |     Data ...
;   +-+-+-+-+-
;

;
; ICMP types & codes, RFC 792 and FreeBSD's ICMP sources
;

ICMP_ECHOREPLY                   = 0  ; echo reply message

ICMP_UNREACH                     = 3
ICMP_UNREACH_NET                 = 0  ; bad net
ICMP_UNREACH_HOST                = 1  ; bad host
ICMP_UNREACH_PROTOCOL            = 2  ; bad protocol
ICMP_UNREACH_PORT                = 3  ; bad port
ICMP_UNREACH_NEEDFRAG            = 4  ; IP_DF caused drop
ICMP_UNREACH_SRCFAIL             = 5  ; src route failed
ICMP_UNREACH_NET_UNKNOWN         = 6  ; unknown net
ICMP_UNREACH_HOST_UNKNOWN        = 7  ; unknown host
ICMP_UNREACH_ISOLATED            = 8  ; src host isolated
ICMP_UNREACH_NET_PROHIB          = 9  ; prohibited access
ICMP_UNREACH_HOST_PROHIB         = 10 ; ditto
ICMP_UNREACH_TOSNET              = 11 ; bad tos for net
ICMP_UNREACH_TOSHOST             = 12 ; bad tos for host
ICMP_UNREACH_FILTER_PROHIB       = 13 ; admin prohib
ICMP_UNREACH_HOST_PRECEDENCE     = 14 ; host prec vio.
ICMP_UNREACH_PRECEDENCE_CUTOFF   = 15 ; prec cutoff

ICMP_SOURCEQUENCH                = 4  ; packet lost, slow down

ICMP_REDIRECT                    = 5  ; shorter route, codes:
ICMP_REDIRECT_NET                = 0  ; for network
ICMP_REDIRECT_HOST               = 1  ; for host
ICMP_REDIRECT_TOSNET             = 2  ; for tos and net
ICMP_REDIRECT_TOSHOST            = 3  ; for tos and host

ICMP_ALTHOSTADDR                 = 6  ; alternate host address
ICMP_ECHO                        = 8  ; echo service
ICMP_ROUTERADVERT                = 9  ; router advertisement
ICMP_ROUTERADVERT_NORMAL         = 0  ; normal advertisement
ICMP_ROUTERADVERT_NOROUTE_COMMON = 16 ; selective routing

ICMP_ROUTERSOLICIT               = 10 ; router solicitation
ICMP_TIMXCEED                    = 11 ; time exceeded, code:
ICMP_TIMXCEED_INTRANS            = 0  ; ttl==0 in transit
ICMP_TIMXCEED_REASS              = 1  ; ttl==0 in reass

ICMP_PARAMPROB                   = 12 ; ip header bad
ICMP_PARAMPROB_ERRATPTR          = 0  ; error at param ptr
ICMP_PARAMPROB_OPTABSENT         = 1  ; req. opt. absent
ICMP_PARAMPROB_LENGTH            = 2  ; bad length

ICMP_TSTAMP                      = 13 ; timestamp request
ICMP_TSTAMPREPLY                 = 14 ; timestamp reply
ICMP_IREQ                        = 15 ; information request
ICMP_IREQREPLY                   = 16 ; information reply
ICMP_MASKREQ                     = 17 ; address mask request
ICMP_MASKREPLY                   = 18 ; address mask reply
ICMP_TRACEROUTE                  = 30 ; traceroute
ICMP_DATACONVERR                 = 31 ; data conversion error
ICMP_MOBILE_REDIRECT             = 32 ; mobile host redirect
ICMP_IPV6_WHEREAREYOU            = 33 ; IPv6 where-are-you
ICMP_IPV6_IAMHERE                = 34 ; IPv6 i-am-here
ICMP_MOBILE_REGREQUEST           = 35 ; mobile registration req
ICMP_MOBILE_REGREPLY             = 36 ; mobile registreation reply
ICMP_SKIP                        = 39 ; SKIP

ICMP_PHOTURIS                    = 40 ; Photuris
ICMP_PHOTURIS_UNKNOWN_INDEX      = 1  ; unknown sec index
ICMP_PHOTURIS_AUTH_FAILED        = 2  ; auth failed
ICMP_PHOTURIS_DECRYPT_FAILED     = 3  ; decrypt failed

;-----------------------------------------------------------------------------------------------------------------------
proc icmp_rx stdcall uses ebx esi edi, buffer_number:DWORD, IPPacketBase:DWORD, IPHeaderLength:DWORD ;//////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? ICMP protocol handler
;-----------------------------------------------------------------------------------------------------------------------
;> [buffer_number] = # of IP-buffer. This buffer must be reused or marked as empty afterwards
;> [IPPacketBase] = ip_packet_t base address
;> [IPHeaderLength] = Header length of ip_packet_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax = not defined
;-----------------------------------------------------------------------------------------------------------------------
;# This is a kernel function, called by ip_rx
;# All used registers will be saved
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, [IPPacketBase] ; esi=ip_packet_t base address
        mov     edi, esi
        add     edi, [IPHeaderLength] ; edi=icmp_packet_t base address

        cmp     byte[edi + icmp_packet_t.type], ICMP_ECHO ; Is this an echo request? discard if not
        jz      .icmp_echo

        mov     eax, [buffer_number]
        call    freeBuff
        jmp     .exit

  .icmp_echo:
        ; swap the source and destination addresses
        mov     ecx, [esi + ip_packet_t.dst_ip]
        mov     ebx, [esi + ip_packet_t.src_ip]
        mov     [esi + ip_packet_t.dst_ip], ebx
        mov     [esi + ip_packet_t.src_ip], ecx

        ; recalculate the IP header checksum
        mov     eax, [IPHeaderLength]
        stdcall checksum_jb, esi, eax ; buf_ptr, buf_size

        mov     byte[esi + ip_packet_t.header_checksum], ah
        mov     byte[esi + ip_packet_t.header_checksum + 1], al ; ?? correct byte order?

        mov     byte[edi + icmp_packet_t.type], ICMP_ECHOREPLY ; change the request to a response
        mov     word[edi + icmp_packet_t.checksum], 0 ; clear ICMP checksum prior to re-calc

        ; Calculate the length of the ICMP data (IP payload)
        xor     eax, eax
        mov     ah, byte[esi + ip_packet_t.total_length]
        mov     al, byte[esi + ip_packet_t.total_length + 1]
        sub     ax, word[IPHeaderLength] ; ax=ICMP-packet length

        stdcall checksum_jb, edi, eax ; buf_ptr, buf_size

        mov     byte[edi + icmp_packet_t.checksum], ah
        mov     byte[edi + icmp_packet_t.checksum + 1], al

        ; Queue packet for transmission
        mov     ebx, [buffer_number]
        mov     eax, NET1OUT_QUEUE
        call    queue

  .exit:
        ret
endp
