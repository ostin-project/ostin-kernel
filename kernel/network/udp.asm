;;======================================================================================================================
;;///// udp.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;
; UDP Payload ( Data field in IP datagram )
;
;  0                   1                   2                   3
;  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
;
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |       Source Port             |      Destination Port         |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; | Length ( UDP Header + Data )  |           Checksum            |
; +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
; |       UDP Data                                                |
; +-+-+-..........                                               -+
;

struct udp_packet_t
  src_port dw ? ; +00
  dst_port dw ? ; +02
  length   dw ? ; +04 - Length of (UDP Header + Data)
  checksum dw ? ; +06
  data     db ? ; +08
ends

;-----------------------------------------------------------------------------------------------------------------------
proc udp_rx stdcall ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? UDP protocol handler
;? This is a kernel function, called by ip_rx
;-----------------------------------------------------------------------------------------------------------------------
;> eax = IP buffer number
;> edx = IP buffer address
;-----------------------------------------------------------------------------------------------------------------------
;# Free up (or re-use) IP buffer when finished
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        ; First validate the header & checksum. Discard buffer if error

        ; Look for a socket where
        ; IP Packet UDP Destination Port = local Port
        ; IP Packet SA = Remote IP

        mov     ax, [edx + 20 + udp_packet_t.dst_port] ; get the local port from the IP packet's UDP header
        mov     ebx, net_sockets

  .next_socket:
        mov     ebx, [ebx + socket_t.next_ptr]
        or      ebx, ebx
        jz      .exit ; No match, so exit
        cmp     [ebx + socket_t.local_port], ax ; ax will hold the 'wrong' value, but the comparision is correct
        jne     .next_socket ; Return back if no match

        ; For dhcp, we must allow any remote server to respond.
        ; I will accept the first incoming response to be the one
        ; I bind to, if the socket is opened with a destination IP address of
        ; 255.255.255.255
        cmp     [ebx + socket_t.remote_ip], 0xffffffff
        je      @f

        mov     eax, [edx + ip_packet_t.src_ip] ; get the Source address from the IP packet
        cmp     [ebx + socket_t.remote_ip], eax
        jne     .exit ; Quit if the source IP is not valid

    @@: ; OK - we have a valid UDP packet for this socket.
        ; First, update the sockets remote port number with the incoming msg
        ; - it will have changed
        ; from the original ( 69 normally ) to allow further connects
        mov     ax, [edx + 20 + udp_packet_t.src_port] ; get the UDP source port (was 69, now new)
        mov     [ebx + socket_t.remote_port], ax

        ; Now, copy data to socket. We have socket address as [eax + sockets].
        ; We have IP packet in edx

        ; get # of bytes in ecx
        movzx   ecx, [edx + ip_packet_t.total_length] ; total length of IP packet. Subtract
        xchg    cl, ch ; 20 + 8 gives data length
        sub     ecx, 28

        mov     eax, [ebx + socket_t.rx_data_cnt] ; get # of bytes already in buffer
        add     [ebx + socket_t.rx_data_cnt], ecx ; increment the count of bytes in buffer

        ; ecx has count, edx points to data

        add     edx, 28 ; edx now points to the data
        lea     edi, [ebx + eax + SOCKETHEADERSIZE]
        mov     esi, edx

        cld
        rep     movsb ; copy the data across

        ; flag an event to the application
        mov     eax, [ebx + socket_t.pid] ; get socket owner PID
        mov     ecx, 1
        mov     esi, TASK_DATA + task_data_t.pid

  .next_pid:
        cmp     [esi], eax
        je      .found_pid
        inc     ecx
        add     esi, sizeof.task_data_t
        cmp     ecx, [TASK_COUNT]
        jbe     .next_pid

        jmp     .exit

  .found_pid:
        shl     ecx, 8
        or      [SLOT_BASE + ecx + app_data_t.event_mask], EVENT_NETWORK ; stack event

        mov     [check_idle_semaphore], 200

  .exit:
        pop     eax
        call    freeBuff ; Discard the packet
        ret
endp
