;;======================================================================================================================
;;///// socket.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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

; socket data structure
struct socket_t linked_list_t
  number            dd ? ; socket number (unique within single process)
  pid               dd ? ; application process id
  local_ip          dd ? ; local IP address
  local_port        dw ? ; local port
  remote_ip         dd ? ; remote IP address
  remote_port       dw ? ; remote port
  orig_remote_ip    dd ? ; original remote IP address (used to reset to LISTEN state)
  orig_remote_port  dw ? ; original remote port (used to reset to LISTEN state)
  rx_data_cnt       dd ? ; rx data count
  tcb_state         dd ? ; TCB state
  tcb_timer         dd ? ; TCB timer (seconds)
  init_send_seq     dd ? ; initial send sequence
  init_recv_seq     dd ? ; initial receive sequence
  send_unack_seq    dd ? ; sequence number of unack'ed sent packets
  send_next_seq     dd ? ; next send sequence number to use
  send_window       dd ? ; send window
  recv_next_seq     dd ? ; next receive sequence number to use
  recv_window       dd ? ; receive window
  seg_length        dd ? ; segment length
  seg_window        dd ? ; segment window
  window_size_timer dd ? ; window size timer
  lock              mutex_t ; lock mutex
  rx_data           dd ? ; receive data buffer here
ends

; TCP opening modes
SOCKET_PASSIVE = 0
SOCKET_ACTIVE  = 1

; socket types
SOCK_STREAM = 1
SOCK_DGRAM  = 2

; pointer to bitmap of free ports (1=free, 0=used)
uglobal
  network_free_ports dd ?
endg

iglobal
  network_free_hint dd 1024 / 8
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.socket ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 53
;-----------------------------------------------------------------------------------------------------------------------
        call    app_socket_handler

        ; enable these for zero delay between sent packet
;       mov     [check_idle_semaphore], 5
;       call    change_task

        mov     [esp + 8 + regs_context32_t.eax], eax
        mov     [esp + 8 + regs_context32_t.ebx], ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
proc net_socket_alloc stdcall uses ebx ecx edx edi ;////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Allocate memory for socket data and put new socket into the list.
;? Newly created socket is initialized with calling PID and number and
;? put into beginning of list (which is a fastest way).
;-----------------------------------------------------------------------------------------------------------------------
;< eax = socket_t structure address
;-----------------------------------------------------------------------------------------------------------------------
        stdcall kernel_alloc, SOCKETBUFFSIZE
        KLog    LOG_DEBUG, "net_socket_alloc (0x%x)\n", eax
        ; check if we can allocate needed amount of memory
        or      eax, eax
        jz      .exit

        ; zero-initialize allocated memory
        push    eax
        mov     edi, eax
        mov     ecx, SOCKETBUFFSIZE / 4
        xor     eax, eax
        rep
        stosd
        pop     eax

        mov     ebx, eax
        lea     ecx, [eax + socket_t.lock]
        call    mutex_init
        mov     eax, ebx

        ; add socket to the list by changing pointers
        mov     ebx, net_sockets
        push    [ebx + socket_t.next_ptr]
        mov     [ebx + socket_t.next_ptr], eax
        mov     [eax + socket_t.prev_ptr], ebx
        pop     ebx
        mov     [eax + socket_t.next_ptr], ebx
        or      ebx, ebx
        jz      @f
        mov     [ebx + socket_t.prev_ptr], eax

    @@: ; set socket owner PID to the one of calling process
        mov     ebx, [current_slot_ptr]
        mov     ebx, [ebx + legacy.slot_t.task.pid]
        mov     [eax + socket_t.pid], ebx

        ; find first free socket number and use it
;       mov     edx, ebx
        mov     ebx, net_sockets
        xor     ecx, ecx

  .next_socket_number:
        inc     ecx

  .next_socket:
        mov     ebx, [ebx + socket_t.next_ptr]
        or      ebx, ebx
        jz      .last_socket_number
        cmp     [ebx + socket_t.number], ecx
        jne     .next_socket
;       cmp     [ebx + socket_t.pid], edx
;       jne     .next_socket
        mov     ebx, net_sockets
        jmp     .next_socket_number

  .last_socket_number:
        mov     [eax + socket_t.number], ecx

  .exit:
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc net_socket_free stdcall uses ebx ecx edx, sockAddr:DWORD ;/////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Free socket data memory and pop socket off the list.
;-----------------------------------------------------------------------------------------------------------------------
;> [sockAddr] = socket_t structure address
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [sockAddr]
        KLog    LOG_DEBUG, "net_socket_free (0x%x)\n", eax
        ; check if we got something similar to socket structure address
        or      eax, eax
        jz      .error

        ; make sure sockAddr is one of the socket addresses in the list
        mov     ebx, net_sockets
;       mov     ecx, [current_slot_ptr]
;       mov     ecx, [ecx + legacy.slot_t.task.pid]

  .next_socket:
        mov     ebx, [ebx + socket_t.next_ptr]
        or      ebx, ebx
        jz      .error
        cmp     ebx, eax
        jne     .next_socket
;       cmp     [ebx + socket_t.pid], ecx
;       jne     .next_socket

        ; okay, we found the correct one
        ; mark local port as unused
        movzx   ebx, [eax + socket_t.local_port]
        push    eax
        mov     eax, [network_free_ports]
        xchg    bl, bh
        lock
        bts     [eax], ebx
        pop     eax
        ; remove it from the list first, changing pointers
        mov     ebx, [eax + socket_t.next_ptr]
        mov     eax, [eax + socket_t.prev_ptr]
        mov     [eax + socket_t.next_ptr], ebx
        or      ebx, ebx
        jz      @f
        mov     [ebx + socket_t.prev_ptr], eax

    @@: ; and finally free the memory structure used
        stdcall kernel_free, [sockAddr]
        ret

  .error:
        KLog    LOG_ERROR, "net_socket_free (fail)\n"
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc net_socket_num_to_addr stdcall uses ebx ecx, sockNum:DWORD ;///////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get socket structure address by its number.
;? Scan through sockets list to find the socket with specified number.
;? This proc uses socket_t.pid indirectly to check if socket is owned by
;? calling process.
;-----------------------------------------------------------------------------------------------------------------------
;> [sockNum] = socket number
;-----------------------------------------------------------------------------------------------------------------------
;< eax = socket_t structure address or 0 (not found)
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [sockNum]
        ; check if we got something similar to socket number
        or      eax, eax
        jz      .error

        ; scan through sockets list
        mov     ebx, net_sockets
;       mov     ecx, [current_slot_ptr]
;       mov     ecx, [ecx + legacy.slot_t.task.pid]

  .next_socket:
        mov     ebx, [ebx + socket_t.next_ptr]
        or      ebx, ebx
        jz      .error
        cmp     [ebx + socket_t.number], eax
        jne     .next_socket
;       cmp     [ebx + socket_t.pid], ecx
;       jne     .next_socket

        ; okay, we found the correct one
        mov     eax, ebx
        ret

  .error:
        xor     eax, eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc net_socket_addr_to_num stdcall uses ebx ecx, sockAddr:DWORD ;//////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get socket number by its structure address.
;? Scan through sockets list to find the socket with specified address.
;? This proc uses socket_t.pid indirectly to check if socket is owned by
;? calling process.
;-----------------------------------------------------------------------------------------------------------------------
;> [sockAddr] = socket_t structure address
;-----------------------------------------------------------------------------------------------------------------------
;< eax = socket number (socket_t.number) or 0 (not found)
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [sockAddr]
        ; check if we got something similar to socket structure address
        or      eax, eax
        jz      .error

        ; scan through sockets list
        mov     ebx, net_sockets
;       mov     ecx, [current_slot_ptr]
;       mov     ecx, [ecx + legacy.slot_t.task.pid]

  .next_socket:
        mov     ebx, [ebx + socket_t.next_ptr]
        or      ebx, ebx
        jz      .error
        cmp     ebx, eax
        jne     .next_socket
;       cmp     [ebx + socket_t.pid], ecx
;       jne     .next_socket

        ; okay, we found the correct one
        mov     eax, [ebx + socket_t.number]
        ret

  .error:
        xor     eax, eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc is_localport_unused stdcall ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.9] Check if local port is used by any socket in the system.
;? Scan through sockets list, checking socket_t.local_port.
;? Useful when you want a to generate a unique local port number.
;? This proc doesn't guarantee that after calling it and trying to use
;? the port reported being free in calls to socket_open/socket_open_tcp it'll
;? still be free or otherwise it'll still be used if reported being in use.
;-----------------------------------------------------------------------------------------------------------------------
;> bx = port number
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 1 (port is free) or 0 (port is in use)
;-----------------------------------------------------------------------------------------------------------------------
        movzx   ebx, bx
        mov     eax, [network_free_ports]
        bt      [eax], ebx
        setc    al
        movzx   eax, al
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc set_local_port ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Set local port in socket structure.
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pointer to struct socket_t
;> bx = local port, or 0 if the kernel must select it itself
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 0 (ok) or 1 (error)
;< [eax + socket_t.local_port] = filled port (on success)
;-----------------------------------------------------------------------------------------------------------------------
        ; 0. Prepare: save registers, make eax point to ports table, expand port to ebx.
        push    eax ecx
        mov     eax, [network_free_ports]
        movzx   ebx, bx
        ; 1. Test, whether the kernel should choose port itself. If no, proceed to 5.
        test    ebx, ebx
        jnz     .given
        ; 2. Yes, it should. Set ecx = limit of table, eax = start value
        lea     ecx, [eax + 0x10000 / 8]
        add     eax, [network_free_hint]
        ; 3. First scan loop: from free hint to end of table.

  .scan1:
        ; 3a. For each dword, find bit set to 1
        bsf     ebx, [eax]
        jz      .next1
        ; 3b. If such bit has been found, atomically test again and clear it.
        lock
        btr     [eax], ebx
        ; 3c. If the bit was still set (usual case), we have found and reserved one port.
        ; Proceed to 6.
        jc      .found
        ; 3d. Otherwise, someone has reserved it between bsf and btr, so retry search.
        jmp     .scan1

  .next1:
        ; 3e. All bits are cleared, so advance to next dword.
        add     eax, 4
        ; 3f. Check limit and continue loop.
        cmp     eax, ecx
        jb      .scan1
        ; 4. Second scan loop: from port 1024 (start of non-system ports) to free hint.
        mov     eax, [network_free_ports]
        mov     ecx, eax
        add     ecx, [network_free_hint]
        add     eax, 1024 / 8
        ; 4a. Test whether there is something to scan.
        cmp     eax, ecx
        jae     .fail
        ; 4b. Enter the loop, the process is same as for 3.

  .scan2:
        bsf     ebx, [eax]
        jz      .next2
        lock
        btr     [eax], ebx
        jc      .found
        jmp     .scan2

  .next2:
        add     eax, 4
        cmp     eax, ecx
        jb      .scan2
        ; 4c. None found. Fail.

  .fail:
        pop     ecx eax
        stc
        ret

        ; 5. No, the kernel should reserve selected port.
  .given:
        ; 5a. Atomically test old value and clear bit.
        lock
        btr     [eax], ebx
        ; 5b. If the bit was set, reservation is successful. Proceed to 8.
        jc      .set
        ; 5c. Otherwise, fail.
        jmp     .fail

  .found:
        ; 6. We have found the bit set to 1, convert the position to port number.
        sub     eax, [network_free_ports]
        lea     ebx, [ebx + eax * 8]
        ; 7. Update free hint.
        add     eax, 4
        cmp     eax, 65536 / 8
        jb      @f
        mov     eax, 1024 / 8

    @@: mov     [network_free_hint], eax

  .set:
        ; 8. Restore eax, set socket_t.local_port and return.
        pop     ecx eax
        xchg    bl, bh  ; Intel -> network byte order
        mov     [eax + socket_t.local_port], bx
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_open stdcall ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> [53.0] Open DGRAM socket (connectionless, unreliable).
;-----------------------------------------------------------------------------------------------------------------------
;> bx = local port number
;> cx = remote port number
;> edx = remote IP address
;-----------------------------------------------------------------------------------------------------------------------
;< eax = socket number or -1 (error)
;-----------------------------------------------------------------------------------------------------------------------
        call    net_socket_alloc
        or      eax, eax
        jz      .error

        KLog    LOG_DEBUG, "socket_open (0x%x)\n", eax

        push    eax

        call    set_local_port
        jc      .error.free
        xchg    ch, cl
        mov     [eax + socket_t.remote_port], cx
        mov     ebx, [stack_ip]
        mov     [eax + socket_t.local_ip], ebx
        mov     [eax + socket_t.remote_ip], edx

;       pop     eax ; Get the socket number back, so we can return it
        stdcall net_socket_addr_to_num
        ret

  .error.free:
        stdcall net_socket_free;, eax

  .error:
        KLog    LOG_ERROR, "socket_open (fail)\n"
        or      eax, -1
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_open_tcp stdcall ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.5] Open STREAM socket (connection-based, sequenced, reliable, two-way).
;-----------------------------------------------------------------------------------------------------------------------
;> bx = local port number
;> cx = remote port number
;> edx = remote IP address
;> esi = open mode (SOCKET_ACTIVE, SOCKET_PASSIVE)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = socket number or -1 (error)
;-----------------------------------------------------------------------------------------------------------------------
local sockAddr dd ?
;-----------------------------------------------------------------------------------------------------------------------
        cmp     esi, SOCKET_PASSIVE
        jne     .skip_port_check

        push    ebx
        mov     eax, ebx
        xchg    al, ah
        mov     ebx, net_sockets

  .next_socket:
        mov     ebx, [ebx + socket_t.next_ptr]
        or      ebx, ebx
        jz      .last_socket
        cmp     [ebx + socket_t.tcb_state], TCB_LISTEN
        jne     .next_socket
        cmp     [ebx + socket_t.local_port], ax
        jne     .next_socket

        xchg    al, ah
        KLog    LOG_ERROR, "port %u is listened by 0x%x\n", ax, ebx
        pop     ebx
        jmp     .error

  .last_socket:
        pop     ebx

  .skip_port_check:
        call    net_socket_alloc
        or      eax, eax
        jz      .error

        KLog    LOG_DEBUG, "socket_open_tcp (0x%x)\n", eax

        mov     [sockAddr], eax

        ; TODO - check this works!
;       mov     [eax + socket_t.window_size_timer], 0 ; Reset the window timer.

        call    set_local_port
        jc      .error.free
        xchg    ch, cl
        mov     [eax + socket_t.remote_port], cx
        mov     [eax + socket_t.orig_remote_port], cx
        mov     ebx, [stack_ip]
        mov     [eax + socket_t.local_ip], ebx
        mov     [eax + socket_t.remote_ip], edx
        mov     [eax + socket_t.orig_remote_ip], edx

        mov     ebx, TCB_LISTEN
        cmp     esi, SOCKET_PASSIVE
        je      @f
        mov     ebx, TCB_SYN_SENT

    @@: mov     [eax + socket_t.tcb_state], ebx ; Indicate the state of the TCB

        cmp     ebx, TCB_LISTEN
        je      .exit

        ; Now, if we are in active mode, then we have to send a SYN to the specified remote port
        mov     eax, EMPTY_QUEUE
        call    dequeue
        cmp     ax, NO_BUFFER
        je      .exit

        push    eax

        mov     bl, TH_SYN
        xor     ecx, ecx
        stdcall build_tcp_packet, [sockAddr]

        mov     eax, NET1OUT_QUEUE
        mov     edx, [stack_ip]
        mov     ecx, [sockAddr]
        cmp     edx, [ecx + socket_t.remote_ip]
        jne     .not_local
        mov     eax, IPIN_QUEUE

  .not_local:
        ; Send it.
        pop     ebx
        call    queue

        mov     esi, [sockAddr]

        ; increment SND.NXT in socket
        add     esi, socket_t.send_next_seq
        call    inc_inet_esi

  .exit:
        ; Get the socket number back, so we can return it
        stdcall net_socket_addr_to_num, [sockAddr]
        ret

  .error.free:
        stdcall net_socket_free, eax

  .error:
        KLog    LOG_ERROR, "socket_open_tcp (fail)\n"
        or      eax, -1
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_close stdcall ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.1] Close DGRAM socket.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = socket number
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (closed successfully) or -1 (error)
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "socket_close (0x%x)\n", ebx
        stdcall net_socket_num_to_addr, ebx
        or      eax, eax
        jz      .error

        stdcall net_socket_free, eax

        xor     eax, eax
        ret

  .error:
        KLog    LOG_ERROR, "socket_close (fail)\n"
        or      eax, -1
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_close_tcp stdcall ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.8] Close STREAM socket.
;? Closing TCP sockets takes time, so when you get successful return code
;? from this function doesn't always mean that socket is actually closed.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = socket number
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (closed successfully) or -1 (error)
;-----------------------------------------------------------------------------------------------------------------------
local sockAddr dd ?
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "socket_close_tcp (0x%x)\n", ebx
        ; first, remove any resend entries
        pusha

        mov     esi, resendQ
        mov     ecx, 0

  .next_resendq:
        cmp     ecx, NUMRESENDENTRIES
        je      .last_resendq ; None left
        cmp     [esi + 4], ebx
        je      @f ; found one
        inc     ecx
        add     esi, 8
        jmp     .next_resendq

    @@: mov     dword[esi + 4], 0
        inc     ecx
        add     esi, 8
        jmp     .next_resendq

  .last_resendq:
        popa

        stdcall net_socket_num_to_addr, ebx
        or      eax, eax
        jz      .error

        mov     ebx, eax
        mov     [sockAddr], eax

        cmp     [ebx + socket_t.tcb_state], TCB_LISTEN
        je      .destroy_tcb
        cmp     [ebx + socket_t.tcb_state], TCB_SYN_SENT
        je      .destroy_tcb
        cmp     [ebx + socket_t.tcb_state], TCB_CLOSED
        je      .destroy_tcb

        ; Now construct the response, and queue for sending by IP
        mov     eax, EMPTY_QUEUE
        call    dequeue
        cmp     ax, NO_BUFFER
        je      .error

        push    eax

        mov     bl, TH_FIN + TH_ACK
        xor     ecx, ecx
        xor     esi, esi
        stdcall build_tcp_packet, [sockAddr]

        mov      ebx, [sockAddr]
        ; increament SND.NXT in socket
        lea     esi, [ebx + socket_t.send_next_seq]
        call    inc_inet_esi

        ; Get the socket state
        mov     eax, [ebx + socket_t.tcb_state]
        cmp     eax, TCB_SYN_RECEIVED
        je      .fin_wait_1
        cmp     eax, TCB_ESTABLISHED
        je      .fin_wait_1

        ; assume CLOSE WAIT
        ; Send a fin, then enter last-ack state
        mov     [ebx + socket_t.tcb_state], TCB_LAST_ACK
        jmp     .send

  .fin_wait_1:
        ; Send a fin, then enter finwait2 state
        mov     [ebx + socket_t.tcb_state], TCB_FIN_WAIT_1

  .send:
        mov     eax, NET1OUT_QUEUE
        mov     edx, [stack_ip]
        mov     ecx, [sockAddr]
        cmp     edx, [ecx + socket_t.remote_ip]
        jne     .not_local
        mov     eax, IPIN_QUEUE

  .not_local:
        ; Send it.
        pop     ebx
        call    queue
        jmp     .exit

  .destroy_tcb:

        ; Clear the socket variables
        stdcall net_socket_free, ebx

  .exit:
        xor     eax, eax
        ret

  .error:
        KLog    LOG_ERROR, "socket_close_tcp (fail)\n"
        or      eax, -1
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_poll stdcall ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.2] Poll socket.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = socket number
;-----------------------------------------------------------------------------------------------------------------------
;< eax = count or bytes in rx buffer or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "socket_poll(0x%x)\n", ebx
        stdcall net_socket_num_to_addr, ebx
        or      eax, eax
        jz      .error

        mov     eax, [eax + socket_t.rx_data_cnt]
        ret

  .error:
        xor     eax, eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_status stdcall ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.6] Get socket TCB state.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = socket number
;-----------------------------------------------------------------------------------------------------------------------
;< eax = socket TCB state or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "socket_status(0x%x)\n", ebx
        stdcall net_socket_num_to_addr, ebx
        or      eax, eax
        jz      .error

        mov     eax, [eax + socket_t.tcb_state]
        ret

  .error:
        xor     eax, eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_read stdcall ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.3] Get one byte from rx buffer.
;? This function can return 0 in two cases: if there's one byte read and
;? non left, and if an error occured. Behavior should be changed and function
;? shouldn't be used for now. Consider using [53.11] instead.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = socket number
;-----------------------------------------------------------------------------------------------------------------------
;< eax = number of bytes left in rx buffer or 0 (error)
;< bl = byte read
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "socket_read(0x%x)\n", ebx
        stdcall net_socket_num_to_addr, ebx
        or      eax, eax
        jz      .error

        mov     ebx, eax

        push    ecx edx
        lea     ecx, [eax + socket_t.lock]
        call    mutex_lock
        pop     edx ecx

        mov     eax, [ebx + socket_t.rx_data_cnt] ; get count of bytes
        test    eax, eax
        jz      .error_release

        dec     eax
        mov     esi, ebx ; esi is address of socket
        mov     [ebx + socket_t.rx_data_cnt], eax ; store new count
        movzx   eax, byte[ebx + socket_t.rx_data] ; get the byte

        mov     ecx, SOCKETBUFFSIZE - socket_t.rx_data - 1
        lea     edi, [esi + socket_t.rx_data]
        lea     esi, [edi + 1]
        push    ecx
        shr     ecx, 2
        rep
        movsd
        pop     ecx
        and     ecx, 3
        rep
        movsb

        lea     ecx, [ebx + socket_t.lock]
        mov     ebx, eax
        call    mutex_unlock
        mov     eax, ebx

        ret

  .error_release:
        lea     ecx, [ebx + socket_t.lock]
        call    mutex_unlock

  .error:
        xor     ebx, ebx
        xor     eax, eax
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_read_packet stdcall ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.11] Get specified number of bytes from rx buffer.
;? Number of bytes in rx buffer can be less than requested size. In this case,
;? only available number of bytes is read.
;? This function can return 0 in two cases: if there's no data to read, and if
;? an error occured. Behavior should be changed.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = socket number
;> ecx = pointer to application buffer
;> edx = application buffer size (number of bytes to read)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = number of bytes read or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "socket_read_packet(0x%x)\n", ebx
        stdcall net_socket_num_to_addr, ebx ; get real socket address
        or      eax, eax
        jz      .error

        mov     ebx, eax
        lea     ecx, [eax + socket_t.lock]
        call    mutex_lock

        mov     eax, [ebx + socket_t.rx_data_cnt] ; get count of bytes
        test    eax, eax ; if count of bytes is zero..
        jz      .exit ; exit function (eax will be zero)

        test    edx, edx ; if buffer size is zero, copy all data
        jz      .copy_all_bytes
        cmp     edx, eax ; if buffer size is larger then the bytes of data, copy all data
        jge     .copy_all_bytes

        sub     eax, edx ; store new count (data bytes in buffer - bytes we're about to copy)
        mov     [ebx + socket_t.rx_data_cnt], eax ;
        push    eax
        mov     eax, edx ; number of bytes we want to copy must be in eax
        call    .start_copy ; copy to the application

        mov     esi, ebx ; now we're going to copy the remaining bytes to the beginning
        add     esi, socket_t.rx_data ; we dont need to copy the header
        mov     edi, esi ; edi is where we're going to copy to
        add     esi, edx ; esi is from where we copy
        pop     ecx ; count of bytes we have left
        push    ecx ; push it again so we can re-use it later
        shr     ecx, 2 ; divide eax by 4
        rep
        movsd   ; copy all full dwords
        pop     ecx
        and     ecx, 3
        rep
        movsb   ; copy remaining bytes

  .exit:
        lea     ecx, [ebx + socket_t.lock]
        mov     ebx, eax
        call    mutex_unlock
        mov     eax, ebx
        ret     ; at last, exit

  .error:
        xor     eax, eax
        ret

  .copy_all_bytes:
        xor     esi, esi
        mov     [ebx + socket_t.rx_data_cnt], esi ; store new count (zero)
        call    .start_copy

        lea     ecx, [ebx + socket_t.lock]
        mov     ebx, eax
        call    mutex_unlock
        mov     eax, ebx
        ret

  .start_copy:
        mov     edi, ecx
        mov     esi, ebx
        add     esi, socket_t.rx_data ; we dont need to copy the header
        mov     ecx, eax ; eax is count of bytes
        push    ecx
        shr     ecx, 2 ; divide eax by 4
        rep
        movsd   ; copy all full dwords
        pop     ecx
        and     ecx, 3
        rep
        movsb   ; copy the rest bytes
        retn    ; exit, or go back to shift remaining bytes if any
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_write stdcall ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.4] Send data through DGRAM socket.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = socket number
;> ecx = application data size (number of bytes to send)
;> edx = pointer to application data buffer
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (sent successfully) or -1 (error)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "socket_write(0x%x)\n", ebx
        stdcall net_socket_num_to_addr, ebx ; get real socket address
        or      eax, eax
        jz      .error

        mov     ebx, eax

        mov     eax, EMPTY_QUEUE
        call    dequeue
        cmp     ax, NO_BUFFER
        je      .error

        ; Save the queue entry number
        push    eax

        ; save the pointers to the data buffer & size
        push    edx
        push    ecx

        ; convert buffer pointer eax to the absolute address
        mov     ecx, IPBUFFSIZE
        mul     ecx
        add     eax, IPbuffs

        mov     edx, eax

        ; So, ebx holds the socket ptr, edx holds the IPbuffer ptr

        ; Fill in the IP header (some data is in the socket descriptor)
        mov     eax, [ebx + socket_t.local_ip]
        mov     [edx + ip_packet_t.src_ip], eax
        mov     eax, [ebx + socket_t.remote_ip]
        mov     [edx + ip_packet_t.dst_ip], eax

        mov     [edx + ip_packet_t.version_and_ihl], 0x45
        mov     [edx + ip_packet_t.type_of_service], 0

        pop     eax ; Get the UDP data length
        push    eax

        add     eax, 20 + 8 ; add IP header and UDP header lengths
        xchg    al, ah
        mov     [edx + ip_packet_t.total_length], ax
        xor     eax, eax
        mov     [edx + ip_packet_t.identification], ax
        mov     [edx + ip_packet_t.flags_and_fragment_offset], 0x0040
        mov     [edx + ip_packet_t.ttl_secs], 0x20
        mov     [edx + ip_packet_t.protocol], PROTOCOL_UDP

        ; Checksum left unfilled
        mov     [edx + ip_packet_t.header_checksum], ax

        ; Fill in the UDP header (some data is in the socket descriptor)
        mov     ax, [ebx + socket_t.local_port]
        mov     [edx + 20 + udp_packet_t.src_port], ax

        mov     ax, [ebx + socket_t.remote_port]
        mov     [edx + 20 + udp_packet_t.dst_port], ax

        pop     eax
        push    eax

        add     eax, 8
        xchg    al, ah
        mov     [edx + 20 + udp_packet_t.length], ax

        ; Checksum left unfilled
        xor     eax, eax
        mov     [edx + 20 + udp_packet_t.checksum], ax

        pop     ecx ; count of bytes to send
        mov     ebx, ecx ; need the length later
        pop     eax ; get callers ptr to data to send

        ; Get the address of the callers data
        mov     edi, [current_slot_ptr]
        add     eax, [edi + legacy.slot_t.task.mem_start]
        mov     esi, eax

        mov     edi, edx
        add     edi, 28
        rep
        movsb   ; copy the data across

        ; we have edx as IPbuffer ptr.
        ; Fill in the UDP checksum
        ; First, fill in pseudoheader
        mov     eax, [edx + ip_packet_t.src_ip]
        mov     [pseudoHeader], eax
        mov     eax, [edx + ip_packet_t.dst_ip]
        mov     [pseudoHeader + 4], eax
        mov     word[pseudoHeader + 8], PROTOCOL_UDP shl 8 + 0 ; 0 + protocol
        add     ebx, 8
        mov     eax, ebx
        xchg    al, ah
        mov     [pseudoHeader + 10], ax

        mov     eax, pseudoHeader
        mov     [checkAdd1], eax
        mov     [checkSize1], 12
        mov     eax, edx
        add     eax, 20
        mov     [checkAdd2], eax
        mov     eax, ebx
        mov     [checkSize2], ax ; was eax!! mjh 8/7/02

        call    checksum

        ; store it in the UDP checksum ( in the correct order! )
        mov     ax, [checkResult]

        ; If the UDP checksum computes to 0, we must make it 0xffff
        ; (0 is reserved for 'not used')
        test    ax, ax
        jnz     @f
        mov     ax, 0xffff

    @@: xchg    al, ah
        mov     [edx + 20 + udp_packet_t.checksum], ax

        ; Fill in the IP header checksum
        GET_IHL ecx, edx ; get IP-Header length
        stdcall checksum_jb, edx, ecx ; buf_ptr, buf_size
        xchg    al, ah
        mov     [edx + ip_packet_t.header_checksum], ax

        ; Check destination IP address.
        ; If it is the local host IP, route it back to IP_RX

        pop     ebx

        mov     eax, NET1OUT_QUEUE
        mov     ecx, [edx + socket_t.remote_ip]
        mov     edx, [stack_ip]
        cmp     edx, ecx
        jne     .not_local
        mov     eax, IPIN_QUEUE

  .not_local:
        ; Send it.
        call    queue

        xor     eax, eax
        ret

  .error:
        or      eax, -1
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
proc socket_write_tcp stdcall ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? [53.7] Send data through STREAM socket
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = socket number
;> ecx = application data size (number of bytes to send)
;> edx = pointer to application data buffer
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (sent successfully) or -1 (error)
;-----------------------------------------------------------------------------------------------------------------------
local sockAddr dd ?
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "socket_write_tcp(0x%x)\n", ebx
        stdcall net_socket_num_to_addr, ebx
        or      eax, eax
        jz      .error

        mov     ebx, eax
        mov     [sockAddr], ebx

        ; If the sockets window timer is nonzero, do not queue packet
        cmp     [ebx + socket_t.window_size_timer], 0
        jne     .error

        mov     eax, EMPTY_QUEUE
        call    dequeue
        cmp     ax, NO_BUFFER
        je      .error

        push    eax

        ; Get the address of the callers data
        mov     edi, [current_slot_ptr]
        add     edx, [edi + legacy.slot_t.task.mem_start]
        mov     esi, edx

        pop     eax
        push    eax

        push    ecx
        mov     bl, TH_ACK
        stdcall build_tcp_packet, [sockAddr]
        pop     ecx

        ; Check destination IP address.
        ; If it is the local host IP, route it back to IP_RX

        pop     ebx
        push    ecx

        mov     eax, NET1OUT_QUEUE
        mov     edx, [stack_ip]
        mov     ecx, [sockAddr]
        cmp     edx, [ecx + socket_t.remote_ip]
        jne     .not_local
        mov     eax, IPIN_QUEUE

  .not_local:
        pop     ecx
        push    ebx ; save ipbuffer number

        call    queue

        mov     esi, [sockAddr]

        ; increament SND.NXT in socket
        ; Amount to increment by is in ecx
        add     esi, socket_t.send_next_seq
        call    add_inet_esi

        pop     ebx

        ; Copy the IP buffer to a resend queue
        ; If there isn't one, dont worry about it for now
        mov     esi, resendQ
        mov     ecx, 0

  .next_resendq:
        cmp     ecx, NUMRESENDENTRIES
        je      .exit ; None found
        cmp     dword[esi + 4], 0
        je      @f ; found one
        inc     ecx
        add     esi, 8
        jmp     .next_resendq

    @@: push    ebx

        ; OK, we have a buffer descriptor ptr in esi.
        ; resend entry # in ecx
        ;  Populate it
        ;  socket #
        ;  retries count
        ;  retry time
        ;  fill IP buffer associated with this descriptor

        stdcall net_socket_addr_to_num, [sockAddr]
        mov     [esi + 4], eax
        mov     byte[esi + 1], TCP_RETRIES
        mov     word[esi + 2], TCP_TIMEOUT

        inc     ecx
        ; Now get buffer location, and copy buffer across. argh! more copying,,
        mov     edi, resendBuffer - IPBUFFSIZE

    @@: add     edi, IPBUFFSIZE
        loop    @b

        ; we have dest buffer location in edi
        pop     eax
        ; convert source buffer pointer eax to the absolute address
        mov     ecx, IPBUFFSIZE
        mul     ecx
        add     eax, IPbuffs
        mov     esi, eax

        ; do copy
        mov     ecx, IPBUFFSIZE
        rep
        movsb

  .exit:
        xor     eax, eax
        ret

  .error:
        or      eax, -1
        ret
endp
