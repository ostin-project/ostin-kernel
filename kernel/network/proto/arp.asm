;;======================================================================================================================
;;///// arp.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

ARP_NO_ENTRY          = 0
ARP_VALID_MAPPING     = 1
ARP_AWAITING_RESPONSE = 2
ARP_RESPONSE_TIMEOUT  = 3

struct arp_entry_t ; =14 bytes
  ip       dd ? ; +00
  mac      dp ? ; +04
  status   dw ? ; +10
  ttl_secs dw ? ; +12 : (in seconds)
ends

; The TTL field is decremented every second, and is deleted when it
; reaches 0. It is refreshed every time a packet is received
; If the TTL field is 0xFFFF it is a static entry and is never deleted
; The status field can be the following values:
; 0x0000  entry not used
; 0x0001  entry holds a valid mapping
; 0x0002  entry contains an IP address, awaiting ARP response
; 0x0003  No response received to ARP request.
; The last status value is provided to allow the network layer to delete
; a packet that is queued awaiting an ARP response

; The follow is the ARP Table.
; This table must be manually updated and the kernel recompilied if
; changes are made to it.
; Empty entries are filled with zeros

ARP_TABLE_SIZE    = 20 ; Size of table
ARP_TABLE_ENTRIES = 0  ; Number of static entries in the table

; TO ADD A STATIC ENTRY, DONT FORGET, PUT "ARPTable" from "uglobal" to "iglobal"!!!
; AND ALSO - IP and MAC have net byte-order, BUT STATUS AND TTL HAVE A MIRROR BYTE-ORDER!!!
uglobal
  ARPTable:
  ; example, static entry ->  db  11,22,33,44, 0x11,0x22,0x33,0x44,0x55,0x66, 0x01,0x00, 0xFF,0xFF
  times ( ARP_TABLE_SIZE - ARP_TABLE_ENTRIES ) * sizeof.arp_entry_t  db 0
endg

iglobal
  NumARP:      dd ARP_TABLE_ENTRIES
  ARPTable_ptr dd ARPTable ; pointer to ARPTable
endg

ARP_REQ_OPCODE = 0x0100 ; request
ARP_REP_OPCODE = 0x0200 ; reply

struct arp_packet_t
  hardware_type dw ? ; +00
  protocol_type dw ? ; +02
  hardware_size db ? ; +04
  protocol_size db ? ; +05
  opcode        dw ? ; +06
  sender_mac    dp ? ; +08
  sender_ip     dd ? ; +14
  target_mac    dp ? ; +18
  target_ip     dd ? ; +24
ends

; Opcode's constants
ARP_TABLE_ADD                = 1
ARP_TABLE_DEL                = 2
ARP_TABLE_GET                = 3
ARP_TABLE_GET_ENTRIES_NUMBER = 4
ARP_TABLE_IP_TO_MAC          = 5
ARP_TABLE_TIMER              = 6

; Index's constants
EXTRA_IS_ARP_PACKET_PTR      = 0  ; if Extra contain pointer to ARP_PACKET
EXTRA_IS_ARP_ENTRY_PTR       = -1 ; if Extra contain pointer to ARP_ENTRY

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc arp_table_manager stdcall uses ebx esi edi ecx edx, Opcode:DWORD, Index:DWORD, Extra:DWORD ;///////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Does a most required operations with ARP-table
;-----------------------------------------------------------------------------------------------------------------------
;> [Opcode] = see Opcode's constants below
;> [Index] = Index of entry in the ARP-table
;> [Extra] = Extra parameter for some Opcodes
;-----------------------------------------------------------------------------------------------------------------------
;< eax = Returned value depends on opcodes, more detailed see below
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, dword[ARPTable_ptr] ; ARPTable base
        mov     ecx, dword[NumARP] ; ARP-entries counter

        mov     eax, dword[Opcode]
        cmp     eax, ARP_TABLE_TIMER
        je      .timer
        cmp     eax, ARP_TABLE_ADD
        je      .add
        cmp     eax, ARP_TABLE_DEL
        je      .del
        cmp     eax, ARP_TABLE_GET
        je      .get
        cmp     eax, ARP_TABLE_IP_TO_MAC
        je      .ip_to_mac
        cmp     eax, ARP_TABLE_GET_ENTRIES_NUMBER
        je      .get_entries_number
        jmp     .exit ; if unknown opcode

;-----------------------------------------------------------------------------------------------------------------------
;? TIMER
;? it must be callback every second. It is responsible for removing expired routes.
;-----------------------------------------------------------------------------------------------------------------------
;> [Opcode] = ARP_TABLE_TIMER
;> [Index] = must be zero
;> [Extra] = must be zero
;-----------------------------------------------------------------------------------------------------------------------
;< eax = not defined
;-----------------------------------------------------------------------------------------------------------------------

  .timer:
        test    ecx, ecx
        jz      .exit ; if NumARP=0 nothing to do
        sub     ecx, ARP_TABLE_ENTRIES ; ecx=dynamic entries number
        jz      .exit ; if NumARP=number of static entries then exit

        add     ebx, ARP_TABLE_ENTRIES * sizeof.arp_entry_t ; ebx=dynamic entries base

  .timer_loop:
        movsx   esi, word[ebx + arp_entry_t.ttl_secs]
        cmp     esi, 0xffffffff
        je      .timer_loop_end ; if TTL==0xFFFF then it's static entry

        test    esi, esi
        jnz     .timer_loop_end_with_dec ; if TTL!=0

        ; Ok, TTL is 0
        ; if Status==AWAITING_RESPONSE and TTL==0
        ; then we have to change it to ARP_RESPONSE_TIMEOUT
        cmp     word[ebx + arp_entry_t.status], ARP_AWAITING_RESPONSE
        jne     @f

        mov     word[ebx + arp_entry_t.status], ARP_RESPONSE_TIMEOUT
        mov     word[ebx + arp_entry_t.ttl_secs], 0x000a ; 10 sec
        jmp     .timer_loop_end

    @@: ; if TTL==0 and Status==VALID_MAPPING, we have to delete it
        ; if TTL==0 and Status==RESPONSE_TIMEOUT, delete too
        mov     esi, dword[NumARP]
        sub     esi, ecx ; esi=index of entry, will be deleted
        stdcall arp_table_manager, ARP_TABLE_DEL, esi, 0 ; opcode, index, extra
        jmp     .timer_loop_end

  .timer_loop_end_with_dec:
        dec     word[ebx + arp_entry_t.ttl_secs] ; decrease TTL

  .timer_loop_end:
        add     ebx, sizeof.arp_entry_t
        loop    .timer_loop

        jmp     .exit

;-----------------------------------------------------------------------------------------------------------------------
;? ADD
;? it adds an entry in the table. If ARP-table already contains same IP, it will be updated.
;-----------------------------------------------------------------------------------------------------------------------
;> [Opcode] = ARP_TABLE_ADD
;> [Index] = specifies what contains Extra-parameter
;> [Extra] = if Index==EXTRA_IS_ARP_PACKET_PTR,
;>           then Extra contains pointer to ARP_PACKET,
;>           otherwise Extra contains pointer to arp_packet_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax = index of entry, that has been added
;-----------------------------------------------------------------------------------------------------------------------

  .add:
        sub     esp, sizeof.arp_entry_t ; Allocate ARP_ENTRY_SIZE byte in stack

        mov     esi, [Extra] ; pointer
        mov     edi, [Index] ; opcode

        ; if Extra contain ptr to arp_packet_t and we have to form arp-entry
        ; else it contain ptr to arp-entry
        cmp     edi, EXTRA_IS_ARP_PACKET_PTR
        je      .arp_packet_to_entry

        ; esi already has been loaded
        mov     edi, esp ; ebx + eax=ARPTable_base + ARP-entry_base(where we will add)
        mov     ecx, sizeof.arp_entry_t / 2 ; ARP_ENTRY_SIZE must be even number!!!
        rep
        movsw   ; copy
        jmp     .search

  .arp_packet_to_entry:
        mov     edx, dword[esi + arp_packet_t.sender_ip] ; esi=base of ARP_PACKET
        mov     [esp + arp_entry_t.ip], edx

        lea     esi, [esi + arp_packet_t.sender_mac]
        lea     edi, [esp + arp_entry_t.mac]
        movsd
        movsw
        mov     word[esp + arp_entry_t.status], ARP_VALID_MAPPING ; specify the type - a valid entry
        mov     word[esp + arp_entry_t.ttl_secs], 0x0e10 ; = 1 hour

  .search:
        mov     edx, dword[esp + arp_entry_t.ip] ; edx=IP-address, which we'll search
        mov     ecx, dword[NumARP] ; ecx=ARP-entries counter
        jecxz   .add_to_end ; if ARP-entries number == 0
        imul    eax, ecx, sizeof.arp_entry_t ; eax=current table size(in bytes)

    @@: sub     eax, sizeof.arp_entry_t
        cmp     dword[ebx + eax + arp_entry_t.ip], edx
        loopnz  @b
        jz      .replace ; found, replace existing entry, ptr to it is in eax

  .add_to_end:
        ; else add to end
        or      eax, -1 ; set eax=0xFFFFFFFF if adding is impossible
        mov     ecx, dword[NumARP]
        cmp     ecx, ARP_TABLE_SIZE
        je      .add_exit ; if arp-entries number is equal to arp-table maxsize

        imul    eax, dword[NumARP], sizeof.arp_entry_t ; eax=ptr to end of ARPTable
        inc     dword[NumARP] ; increase ARP-entries counter

  .replace:
        mov     esi, esp ; esp=base of ARP-entry, that will be added
        lea     edi, [ebx + eax] ; ebx + eax=ARPTable_base + ARP-entry_base(where we will add)
        mov     ecx, sizeof.arp_entry_t / 2 ; ARP_ENTRY_SIZE must be even number!!!
        rep
        movsw

        mov     ecx, sizeof.arp_entry_t
        xor     edx, edx ; "div" takes operand from EDX:EAX
        div     ecx ; eax=index of entry, which has been added

  .add_exit:
        add     esp, sizeof.arp_entry_t ; free stack
        jmp     .exit

;-----------------------------------------------------------------------------------------------------------------------
;? DEL
;? it deletes an entry in the table.
;-----------------------------------------------------------------------------------------------------------------------
;> [Opcode] = ARP_TABLE_DEL
;> [Index] = index of entry, that should be deleted
;> [Extra] = must be zero
;-----------------------------------------------------------------------------------------------------------------------
;< eax = not defined
;-----------------------------------------------------------------------------------------------------------------------

  .del:
        mov     esi, [Index]
        imul    esi, sizeof.arp_entry_t

        mov     ecx, (ARP_TABLE_SIZE - 1) * sizeof.arp_entry_t
        sub     ecx, esi

        lea     edi, [ebx + esi] ; edi=ptr to entry that should be deleted
        lea     esi, [edi + sizeof.arp_entry_t] ; esi=ptr to next entry

        shr     ecx, 1 ; ecx/2 => sizeof.arp_entry_t MUST BE EVEN NUMBER!
        rep
        movsw

        dec     dword[NumARP] ; decrease arp-entries counter
        jmp     .exit

;-----------------------------------------------------------------------------------------------------------------------
;? GET
;? it reads an entry of table into buffer.
;-----------------------------------------------------------------------------------------------------------------------
;> [Opcode] = ARP_TABLE_GET
;> [Index] = index of entry, that should be read
;> [Extra] = pointer to buffer for reading(size must be equal to sizeof.arp_entry_t)
;----------------------------------------------------------------------------------------------------------------------
;< eax = not defined
;-----------------------------------------------------------------------------------------------------------------------

  .get:
        mov     esi, [Index]
        imul    esi, sizeof.arp_entry_t ; esi=ptr to required ARP_ENTRY
        mov     edi, [Extra] ; edi=buffer for reading
        mov     ecx, sizeof.arp_entry_t / 2 ; must be even number!!!
        rep
        movsw
        jmp     .exit

;-----------------------------------------------------------------------------------------------------------------------
;? IP_TO_MAC
;? it gets an IP from Index, scans each entry in the table and writes
;? MAC, that relates to specified IP, into buffer specified in Extra.
;? And if it cannot find an IP-address in the table, it does an ARP-request of that.
;-----------------------------------------------------------------------------------------------------------------------
;> [Opcode] = ARP_TABLE_IP_TO_MAC
;> [Index] = IP that should be transformed into MAC
;> [Extra] = pointer to buffer where will be written the MAC-address.
;-----------------------------------------------------------------------------------------------------------------------
;< eax = ARP table entry status code.
;<   If EAX==ARP_NO_ENTRY, IP isn't found in the table and we have sent the request.
;<   If EAX==ARP_AWAITING_RESPONSE, we wait the response from remote system.
;<   If EAX==ARP_RESPONSE_TIMEOUT, remote system not responds too long.
;<   If EAX==ARP_VALID_MAPPING, all is ok, we've got a true MAC.
;-----------------------------------------------------------------------------------------------------------------------
;# If MAC will equal to a zero, in the buffer. It means, that IP-address was not yet
;# resolved, or that doesn't exist. I recommend you, to do at most 3-5 calls of this
;# function with 1sec delay. sure, only if it not return a valid MAC after a first call.
;-----------------------------------------------------------------------------------------------------------------------

  .ip_to_mac:
        xor     eax, eax
        mov     edi, [Extra]
        stosd
        stosw

        ; first, check destination IP to see if it is on 'this' network.
        ; The test is:
        ; if ( destIP & subnet_mask == stack_ip & subnet_mask )
        ;   destination is local
        ; else
        ;  destination is remote, so pass to gateway

        mov     eax, [Index] ; eax=required IP
        mov     esi, eax
        and     esi, [subnet_mask]
        mov     ecx, [stack_ip]
        and     ecx, [subnet_mask]
        cmp     esi, ecx
        je      @f ; if we and target IP are located in the same network
        mov     eax, [gateway_ip]
        mov     [Index], eax

    @@: ; if ARP-table not contain an entries, we have to request IP.
        ; EAX will be containing a zero, it's equal to ARP_NO_ENTRY
        cmp     dword[NumARP], 0
        je      .ip_to_mac_send_request

        mov     ecx, dword[NumARP]
        imul    esi, ecx, sizeof.arp_entry_t ; esi=current ARP-table size

    @@: sub     esi, sizeof.arp_entry_t
        cmp     [ebx + esi], eax ; ebx=ARPTable base
        loopnz  @b ; Return back if non match
        jnz     .ip_to_mac_send_request ; and request IP->MAC if none found in the table

        ; Return the entry status in eax
        movzx   eax, word[ebx + esi + arp_entry_t.status]

        ; esi holds index
        lea     esi, [ebx + esi + arp_entry_t.mac]
        mov     edi, [Extra] ; edi=ptr to buffer for write MAC
        movsd
        movsw
        jmp     .exit

  .ip_to_mac_send_request:
        stdcall arp_request, [Index], stack_ip, node_addr ; TargetIP, SenderIP_ptr, SenderMAC_ptr
        mov     eax, ARP_NO_ENTRY
        jmp     .exit

;-----------------------------------------------------------------------------------------------------------------------
;? BEGIN GET_ENTRIES_NUMBER
;? returns an ARP-entries number in the ARPTable
;-----------------------------------------------------------------------------------------------------------------------
;> [Opcode] = ARP_TABLE_GET_ENTRIES_NUMBER
;> [Index] = must be zero
;> [Extra] = must be zero
;-----------------------------------------------------------------------------------------------------------------------
;< eax = ARP-entries number in the ARPTable
;-----------------------------------------------------------------------------------------------------------------------

  .get_entries_number:
        mov     eax, dword[NumARP]
        jmp     .exit

  .exit:
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc arp_handler ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Called when an ARP packet is received on the ethernet
;? It looks to see if the packet is a request to resolve this Hosts IP address. If it is, send the ARP reply packet.
;-----------------------------------------------------------------------------------------------------------------------
;> [Ether_buffer] = Header + Data
;> [stack_ip] = this Hosts IP address (in network format)
;> [node_addr] = this Hosts MAC address
;-----------------------------------------------------------------------------------------------------------------------
;# All registers may be destroyed
;-----------------------------------------------------------------------------------------------------------------------
        ; Is this a REQUEST?
        ; Is this a request for My Host IP
        ; Yes - So construct a response message.
        ; Send this message to the ethernet card for transmission

        stdcall arp_table_manager, ARP_TABLE_ADD, EXTRA_IS_ARP_PACKET_PTR, ETH_FRAME.data

        inc     dword[arp_rx_count] ; increase ARP-packets counter

        cmp     word[ETH_FRAME.data + arp_packet_t.opcode], ARP_REQ_OPCODE ; Is this a request packet?
        jne     .exit ; No - so exit

        mov     eax, [stack_ip]
        cmp     eax, dword[ETH_FRAME.data + arp_packet_t.target_ip] ; Is it looking for my IP address?
        jne     .exit ; No - so quit now

        ; OK, it is a request for my MAC address. Build the frame and send it
        ; We can reuse the packet.

        mov     word[ETH_FRAME.data + arp_packet_t.opcode], ARP_REP_OPCODE

        mov     esi, ETH_FRAME.data + arp_packet_t.sender_mac
        mov     edi, ETH_FRAME.data + arp_packet_t.target_mac
        movsd
        movsw

        mov     esi, ETH_FRAME.data + arp_packet_t.sender_ip
        mov     edi, ETH_FRAME.data + arp_packet_t.target_ip
        movsd

        mov     esi, node_addr
        mov     edi, ETH_FRAME.data + arp_packet_t.sender_mac
        movsd
        movsw

        mov     esi, stack_ip
        mov     edi, ETH_FRAME.data + arp_packet_t.sender_ip
        movsd

        ; Now, send it!
        mov     edi, ETH_FRAME.data + arp_packet_t.target_mac ; ptr to destination MAC address
        mov     bx, ETHER_ARP ; type of protocol
        mov     ecx, 28 ; data size
        mov     esi, ETH_FRAME.data ; ptr to data
        push    ebp
        call    [net_drvr_funcs.transmit] ; transmit packet
        pop     ebp

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
proc arp_request stdcall uses ebx esi edi, TargetIP:DWORD, SenderIP_ptr:DWORD, SenderMAC_ptr:DWORD ;////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Sends an ARP request on the ethernet
;-----------------------------------------------------------------------------------------------------------------------
;> [TargetIP] = requested IP address
;> [SenderIP_ptr] = POINTER to sender's IP address(our system's address)
;> [SenderMAC_ptr] = POINTER to sender's MAC address(our system's address)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok), not defined otherwise
;-----------------------------------------------------------------------------------------------------------------------
        inc     dword[arp_tx_count] ; increase counter

        sub     esp, 28 ; allocate memory for arp_packet_t

        mov     word[esp + arp_packet_t.hardware_type], 0x0100 ; Ethernet
        mov     word[esp + arp_packet_t.protocol_type], 0x0008 ; IP
        mov     byte[esp + arp_packet_t.hardware_size], 0x06 ; MAC-addr length
        mov     byte[esp + arp_packet_t.protocol_size], 0x04 ; IP-addr length
        mov     word[esp + arp_packet_t.opcode], 0x0100 ; Request

        mov     esi, [SenderMAC_ptr]
        lea     edi, [esp + arp_packet_t.sender_mac] ; Our MAC-addr
        movsd
        movsw

        mov     esi, [SenderIP_ptr]
        lea     edi, [esp + arp_packet_t.sender_ip] ; Our IP-addr
        movsd

        xor     eax, eax
        lea     edi, [esp + arp_packet_t.target_mac] ; Required MAC-addr(zeroed)
        stosd
        stosw

        mov     esi, dword[TargetIP]
        mov     dword[esp + arp_packet_t.target_ip], esi ; Required IP-addr(we get it as function parameter)

        ; Now, send it!
        mov     edi, broadcast_add ; Pointer to 48 bit destination address
        mov     bx, ETHER_ARP ; Type of packet
        mov     ecx, 28 ; size of packet
        lea     esi, [esp] ; pointer to packet data
        push    ebp
        call    [net_drvr_funcs.transmit] ; Call the drivers transmit function
        pop     ebp

        add     esp, 28 ; free memory, allocated before for arp_packet_t

        ; Add an entry in the ARP table, awaiting response
        sub     esp, sizeof.arp_entry_t ; allocate memory for ARP-entry

        mov     esi, dword[TargetIP]
        mov     dword[esp + arp_entry_t.ip], esi

        lea     edi, [esp + arp_entry_t.mac]
        xor     eax, eax
        stosd
        stosw

        mov     word[esp + arp_entry_t.status], ARP_AWAITING_RESPONSE
        mov     word[esp + arp_entry_t.ttl_secs], 0x000a ; 10 seconds

        stdcall arp_table_manager, ARP_TABLE_ADD, EXTRA_IS_ARP_ENTRY_PTR, esp
        add     esp, sizeof.arp_entry_t ; free memory

  .exit:
        ret
endp
