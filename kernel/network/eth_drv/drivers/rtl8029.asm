;;======================================================================================================================
;;///// rtl8029.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2007 KolibriOS team <http://kolibrios.org/>
;; (c) 2002-2004 MenuetOS <http://menuetos.net/>
;; (c) 2002 Mike Hibbett <mikeh@oceanfree.net>
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
;# * ns8390 driver - etherboot 5.0.6 project
;;======================================================================================================================

;**************************************************************************
; 8390 Register Definitions
;**************************************************************************
D8390_P0_COMMAND              = 0x00
D8390_P0_PSTART               = 0x01
D8390_P0_PSTOP                = 0x02
D8390_P0_BOUND                = 0x03
D8390_P0_TSR                  = 0x04
D8390_P0_TPSR                 = 0x04
D8390_P0_TBCR0                = 0x05
D8390_P0_TBCR1                = 0x06
D8390_P0_ISR                  = 0x07
D8390_P0_RSAR0                = 0x08
D8390_P0_RSAR1                = 0x09
D8390_P0_RBCR0                = 0x0a
D8390_P0_RBCR1                = 0x0b
D8390_P0_RSR                  = 0x0c
D8390_P0_RCR                  = 0x0c
D8390_P0_TCR                  = 0x0d
D8390_P0_DCR                  = 0x0e
D8390_P0_IMR                  = 0x0f
D8390_P1_COMMAND              = 0x00
D8390_P1_PAR0                 = 0x01
D8390_P1_PAR1                 = 0x02
D8390_P1_PAR2                 = 0x03
D8390_P1_PAR3                 = 0x04
D8390_P1_PAR4                 = 0x05
D8390_P1_PAR5                 = 0x06
D8390_P1_CURR                 = 0x07
D8390_P1_MAR0                 = 0x08

D8390_COMMAND_PS0             = 0x0  ; Page 0 select
D8390_COMMAND_PS1             = 0x40 ; Page 1 select
D8390_COMMAND_PS2             = 0x80 ; Page 2 select
D8390_COMMAND_RD2             = 0x20 ; Remote DMA control
D8390_COMMAND_RD1             = 0x10
D8390_COMMAND_RD0             = 0x08
D8390_COMMAND_TXP             = 0x04 ; transmit packet
D8390_COMMAND_STA             = 0x02 ; start
D8390_COMMAND_STP             = 0x01 ; stop

D8390_COMMAND_RD2_STA         = 0x22
D8390_COMMAND_RD2_STP         = 0x21
D8390_COMMAND_RD1_STA         = 0x12
D8390_COMMAND_RD0_STA         = 0x0a
D8390_COMMAND_PS0_RD2_STP     = 0x21
D8390_COMMAND_PS1_RD2_STP     = 0x61
D8390_COMMAND_PS0_RD2_STA     = 0x22
D8390_COMMAND_PS0_TXP_RD2_STA = 0x26

D8390_RCR_MON                 = 0x20 ;  monitor mode

D8390_DCR_FT1                 = 0x40
D8390_DCR_LS                  = 0x08 ;  Loopback select
D8390_DCR_WTS                 = 0x01 ;  Word transfer select

D8390_DCR_FT1_LS              = 0x48
D8390_DCR_WTS_FT1_LS          = 0x49

D8390_ISR_PRX                 = 0x01 ;  successful recv
D8390_ISR_PTX                 = 0x02 ;  successful xmit
D8390_ISR_RXE                 = 0x04 ;  receive error
D8390_ISR_TXE                 = 0x08 ;  transmit error
D8390_ISR_OVW                 = 0x10 ;  Overflow
D8390_ISR_CNT                 = 0x20 ;  Counter overflow
D8390_ISR_RDC                 = 0x40 ;  Remote DMA complete
D8390_ISR_RST                 = 0x80 ;  reset

D8390_RSTAT_PRX               = 0x01 ;  successful recv
D8390_RSTAT_CRC               = 0x02 ;  CRC error
D8390_RSTAT_FAE               = 0x04 ;  Frame alignment error
D8390_RSTAT_OVER              = 0x08 ;  FIFO overrun

D8390_TXBUF_SIZE              = 6
D8390_RXBUF_END               = 32
D8390_PAGE_SIZE               = 256

ETH_ALEN                      = 6
ETH_HLEN                      = 14
ETH_ZLEN                      = 60
ETH_FRAME_LEN                 = 1514

FLAG_PIO                      = 0x01
FLAG_16BIT                    = 0x02
ASIC_PIO                      = 0

VENDOR_NONE                   = 0
VENDOR_WD                     = 1
VENDOR_NOVELL                 = 2
VENDOR_3COM                   = 3

NE_ASIC_OFFSET                = 0x10
NE_RESET                      = 0x0f ; Used to reset card
NE_DATA                       = 0x00 ; Used to read/write NIC mem

MEM_8192                      = 32
MEM_16384                     = 64
MEM_32768                     = 128

ISA_MAX_ADDR                  = 0x400

uglobal
  eth_flags:     db 0
  eth_vendor:    db 0
  eth_nic_base:  dw 0
  eth_asic_base: dw 0
  eth_memsize:   db 0
  eth_rx_start:  db 0
  eth_tx_start:  db 0
  eth_bmem:      dd 0
  eth_rmem:      dd 0
  romdata:       rb 16
endg

iglobal
  test_data:   db 'NE*000 memory', 0
  test_buffer: db '             ', 0
endg

uglobal
  eth_type:        dw 0
  pkthdr:          rb 4 ; status, next, (short) len
  pktoff:          dw 0
  eth_rx_data_ptr: dd 0
  eth_tmp_len:     dw 0
endg

;-----------------------------------------------------------------------------------------------------------------------
eth_pio_read: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read a frame from the ethernet card via Programmed I/O
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = src
;> ecx = cnt
;> edi = dst
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [eth_flags]
        and     al, FLAG_16BIT
        cmp     al, 0
        je      .epr_001

        inc     ecx
        and     ecx, 0xfffffffe

  .epr_001:
        mov     al, D8390_COMMAND_RD2_STA
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_COMMAND
        out     dx, al

        mov     al, cl
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_RBCR0
        out     dx, al

        mov     al, ch
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_RBCR1
        out     dx, al

        mov     al, bl
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_RSAR0
        out     dx, al

        mov     al, bh
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_RSAR1
        out     dx, al

        mov     al, D8390_COMMAND_RD0_STA
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_COMMAND
        out     dx, al

        mov     dx, [eth_asic_base]
        add     dx, ASIC_PIO

        mov     al, [eth_flags]
        and     al, FLAG_16BIT
        cmp     al, 0
        je      .epr_003

        shr     ecx, 1

  .epr_002:
        ; 2 bytes at a time
        in      ax, dx
        mov     [edi], ax
        add     edi, 2
        loop    .epr_002
        ret

  .epr_003:
        ; 1 byte at a time
        in      al, dx
        mov     [edi], al
        inc     edi
        loop    .epr_003
        ret

;-----------------------------------------------------------------------------------------------------------------------
eth_pio_write: ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? writes a frame to the ethernet card via Programmed I/O
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = dst
;> ecx = cnt
;> esi = src
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [eth_flags]
        and     al, FLAG_16BIT
        cmp     al, 0
        je      .epw_001

        inc     ecx
        and     ecx, 0xfffffffe

  .epw_001:
        mov     al, D8390_COMMAND_RD2_STA
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_COMMAND
        out     dx, al

        mov     al, D8390_ISR_RDC
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_ISR
        out     dx, al


        mov     al, cl
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_RBCR0
        out     dx, al

        mov     al, ch
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_RBCR1
        out     dx, al

        mov     al, bl
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_RSAR0
        out     dx, al

        mov     al, bh
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_RSAR1
        out     dx, al

        mov     al, D8390_COMMAND_RD1_STA
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_COMMAND
        out     dx, al

        mov     dx, [eth_asic_base]
        add     dx, ASIC_PIO

        mov     al, [eth_flags]
        and     al, FLAG_16BIT
        cmp     al, 0
        je      .epw_003

        shr      ecx, 1

  .epw_002:
        ; 2 bytes at a time
        mov     ax, [esi]
        add     esi, 2
        out     dx, ax

        loop    .epw_002
        jmp     .epw_004

  .epw_003:
        ; 1 byte at a time
        mov     al, [esi]
        inc     esi
        out     dx, al
        loop    .epw_003

  .epw_004:
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_ISR

  .epw_005:
        in      al, dx
        and     al, D8390_ISR_RDC
        cmp     al, D8390_ISR_RDC
        jne     .epw_005

        ret

;-----------------------------------------------------------------------------------------------------------------------
rtl8029_reset: ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Place the chip (ie, the ethernet card) into a virgin state
;-----------------------------------------------------------------------------------------------------------------------
;# All registers destroyed
;-----------------------------------------------------------------------------------------------------------------------
        mov     bx, [eth_nic_base]

        mov     dx, bx
        add     dx, D8390_P0_COMMAND
        mov     al, D8390_COMMAND_PS0_RD2_STP
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_DCR
        mov     al, [eth_flags]
        and     al, FLAG_16BIT
        cmp     al, FLAG_16BIT
        jne     .nsr_001

        mov     al, 0x49
        jmp     .nsr_002

  .nsr_001:
        mov     al, 0x48

  .nsr_002:
        out     dx, al

        xor     al, al

        mov     dx, bx
        add     dx, D8390_P0_RBCR0
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_RBCR1
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_RCR
        mov     al, 0x20
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_TCR
        mov     al, 2
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_TPSR
        mov     al, [eth_tx_start]
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_PSTART
        mov     al, [eth_rx_start]
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_PSTOP
        mov     al, [eth_memsize]
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_BOUND
        mov     al, [eth_memsize]
        dec     al
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_ISR
        mov     al, 0xff
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_IMR
        xor     al, al
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_COMMAND
        mov     al, D8390_COMMAND_PS1_RD2_STP
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P1_PAR0
        mov     esi, node_addr
        mov     ecx, ETH_ALEN

  .nsr_003:
        mov     al, [esi]
        out     dx, al

        inc     esi
        inc     dx
        loop    .nsr_003

        mov     dx, bx
        add     dx, D8390_P1_MAR0
        mov     ecx, ETH_ALEN

        mov     al, 0xff

  .nsr_004:
        out     dx, al
        inc     dx
        loop    .nsr_004

        mov     dx, bx
        add     dx, D8390_P1_CURR
        mov     al, [eth_rx_start]
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_COMMAND
        mov     al, D8390_COMMAND_PS0_RD2_STA
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_ISR
        mov     al, 0xff
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_TCR
        mov     al, 0
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_RCR
        mov     al, 4
        out     dx, al

        ret

;-----------------------------------------------------------------------------------------------------------------------
rtl8029_probe: ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Searches for an ethernet card, enables it and clears the rx buffer
;? If a card was found, it enables the ethernet -> TCPIP link
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [io_addr]
        mov     [eth_nic_base], ax ; The IO address space is 16 bit only

        mov     al, VENDOR_NONE
        mov     [eth_vendor], al

        mov     al, [eth_vendor]
        cmp     al, VENDOR_NONE

        jne     .ep_check_have_vendor
        xor     eax, eax
        mov     [eth_bmem], eax

        mov     al, FLAG_PIO
        mov     [eth_flags], al

        mov     ax, [eth_nic_base]
        add     ax, NE_ASIC_OFFSET
        mov     [eth_asic_base], ax

        mov     al, MEM_16384
        mov     [eth_memsize], al

        mov     al, 32
        mov     [eth_tx_start], al

        add     al, D8390_TXBUF_SIZE
        mov     [eth_rx_start], al

        mov     dx, [eth_asic_base]
        add     dx, NE_RESET

        in      al, dx
        out     dx, al

        in      al, 0x84

        mov     bx, [eth_nic_base]

        mov     dx, bx
        add     dx, D8390_P0_COMMAND
        mov     al, D8390_COMMAND_RD2_STP
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_RCR
        mov     al, D8390_RCR_MON
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_DCR
        mov     al, D8390_DCR_FT1_LS
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_PSTART
        mov     al, MEM_8192
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_PSTOP
        mov     al, MEM_16384
        out     dx, al

        mov     esi, test_data
        mov     ebx, 8192
        mov     ecx, 14
        call    eth_pio_write

        mov     ebx, 8192
        mov     ecx, 14
        mov     edi, test_buffer
        call    eth_pio_read

        mov     esi, test_buffer
        mov     edi, test_data
        mov     ecx, 13
        cld
        rep     cmpsb

        je      .ep_set_vendor

        mov     al, [eth_flags]
        or      al, FLAG_16BIT
        mov     [eth_flags], al

        mov     al, MEM_32768
        mov     [eth_memsize], al

        mov     al, 64
        mov     [eth_tx_start], al

        add     al, D8390_TXBUF_SIZE
        mov     [eth_rx_start], al

        mov     bx, [eth_nic_base]

        mov     dx, bx
        add     dx, D8390_P0_DCR
        mov     al, D8390_DCR_WTS_FT1_LS
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_PSTART
        mov     al, MEM_16384
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_PSTOP
        mov     al, MEM_32768
        out     dx, al

        mov     esi, test_data
        mov     ebx, 16384
        mov     ecx, 14
        call    eth_pio_write

        mov     ebx, 16384
        mov     ecx, 14
        mov     edi, test_buffer
        call    eth_pio_read

        mov     esi, test_buffer
        mov     edi, test_data
        mov     ecx, 13
        cld
        rep     cmpsb

  .ep_set_vendor:
        ; this bit is odd - probably left over from my hacking
        mov     ax, [eth_nic_base]
        cmp     ax, 0
        je      .rtl8029_exit
        cmp     ax, ISA_MAX_ADDR
        jbe     .ep_001
        mov     al, [eth_flags]
        or      al, FLAG_16BIT
        mov     [eth_flags], al

  .ep_001:
        mov     al, VENDOR_NOVELL
        mov     [eth_vendor], al

        mov     ebx, 0
        mov     ecx, 16
        mov     edi, romdata
        call    eth_pio_read


        mov     ecx, ETH_ALEN
        mov     esi, romdata
        mov     edi, node_addr

        mov     bl, [eth_flags]
        and     bl, FLAG_16BIT

  .ep_002:
        mov     al, [esi]
        mov     [edi], al

        inc     edi
        inc     esi
        cmp     bl, FLAG_16BIT
        jne     .ep_003

        inc     esi

  .ep_003:
        loop    .ep_002

  .ep_check_have_vendor:
        mov     al, [eth_vendor]
        cmp     al, VENDOR_NONE
        je      .rtl8029_exit

        cmp     al, VENDOR_3COM
        je      .ep_reset_card

        mov     eax, [eth_bmem]
        mov     [eth_rmem], eax

  .ep_reset_card:
        ; Reset the card
        call    rtl8029_reset

        ; Indicate that we have successfully reset the card
        mov     eax, [pci_data]
        mov     [eth_status], eax

  .rtl8029_exit:
        ret

;-----------------------------------------------------------------------------------------------------------------------
rtl8029_poll: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Polls the ethernet card for a received packet
;-----------------------------------------------------------------------------------------------------------------------
;< Received data, if any, ends up in Ether_buffer
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, Ether_buffer
        mov     [eth_rx_data_ptr], eax

        mov     bx, [eth_nic_base]

        mov     dx, bx
        add     dx, D8390_P0_RSR
        in      al, dx

        and     al, D8390_RSTAT_PRX
        cmp     al, D8390_RSTAT_PRX
        jne     .nsp_exit

        mov     dx, bx
        add     dx, D8390_P0_BOUND
        in      al, dx
        inc     al

        cmp     al, [eth_memsize]
        jb      .nsp_001

        mov     al, [eth_rx_start]

  .nsp_001:
        mov     ch, al

        mov     dx, bx
        add     dx, D8390_P0_COMMAND
        mov     al, D8390_COMMAND_PS1
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P1_CURR
        in      al, dx ; get current page
        mov     cl, al

        mov     dx, bx
        add     dx, D8390_P0_COMMAND
        mov     al, D8390_COMMAND_PS0
        out     dx, al

        cmp     cl, [eth_memsize]
        jb      .nsp_002

        mov     cl, [eth_rx_start]

  .nsp_002:
        cmp     cl, ch
        je      .nsp_exit

        xor     ax, ax
        mov     ah, ch

        mov     [pktoff], ax

        mov     al, [eth_flags]
        and     al, FLAG_PIO
        cmp     al, FLAG_PIO
        jne     .nsp_003

        movzx   ebx, word[pktoff]
        mov     edi, pkthdr
        mov     ecx, 4
        call    eth_pio_read
        jmp     .nsp_004

  .nsp_003:
        mov     edi, [eth_rmem]
        movzx   eax, word[pktoff]
        add     edi, eax
        mov     eax, [edi]
        mov     [pkthdr], eax

  .nsp_004:
        mov     ax, [pktoff]
        add     ax, 4
        mov     [pktoff], ax

        mov     ax, [pkthdr + 2]
        sub     ax, 4

        mov     [eth_tmp_len], ax

        cmp     ax, ETH_ZLEN
        jb      .nsp_exit

        cmp     ax, ETH_FRAME_LEN
        ja      .nsp_exit

        mov     al, [pkthdr]
        and     al, D8390_RSTAT_PRX
        cmp     al, D8390_RSTAT_PRX
        jne     .nsp_exit

        ; Right, we can now get the data

        mov     ax, [eth_tmp_len]
        mov     [eth_rx_data_len], ax

        xor     ebx, ebx
        mov     bh, [eth_memsize]
        sub     bx, [pktoff]

        cmp     [eth_tmp_len], bx
        jbe     .nsp_005

        mov     al, [eth_flags]
        and     al, FLAG_PIO
        cmp     al, FLAG_PIO
        jne     .nsp_006

        push    ebx
        mov     ecx, ebx
        xor     ebx, ebx
        mov     bx, [pktoff]
        mov     edi, [eth_rx_data_ptr]
        call    eth_pio_read
        pop     ebx
        jmp     .nsp_007

  .nsp_006:
        ; Not implemented, as we are using PIO mode on this card

  .nsp_007:
        xor     ax, ax
        mov     ah, [eth_rx_start]
        mov     [pktoff], ax

        mov     eax, [eth_rx_data_ptr]
        add     eax, ebx
        mov     [eth_rx_data_ptr], eax

        mov     ax, [eth_tmp_len]
        sub     ax, bx
        mov     [eth_tmp_len], ax

  .nsp_005:
        mov     al, [eth_flags]
        and     al, FLAG_PIO
        cmp     al, FLAG_PIO
        jne     .nsp_008

        xor     ebx, ebx
        mov     bx, [pktoff]
        xor     ecx, ecx
        mov     cx, [eth_tmp_len]
        mov     edi, [eth_rx_data_ptr]
        call    eth_pio_read
        jmp     .nsp_009

  .nsp_008:
        ; Not implemented, as we are using PIO mode on this card

  .nsp_009:
        mov     al, [pkthdr+1]
        cmp     al, [eth_rx_start]
        jne     .nsp_010

        mov     al, [eth_memsize]

  .nsp_010:
        mov     dx, [eth_nic_base]
        add     dx, D8390_P0_BOUND
        dec     al
        out     dx, al

  .nsp_exit:
        ret

;-----------------------------------------------------------------------------------------------------------------------
rtl8029_transmit: ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Transmits a packet of data via the ethernet card
;-----------------------------------------------------------------------------------------------------------------------
;> edi = Pointer to 48 bit destination address
;> bx = Type of packet
;> ecx = size of packet
;> esi = pointer to packet data
;-----------------------------------------------------------------------------------------------------------------------
        mov     [eth_type], bx

        pusha

        mov     esi, edi
        xor     bx, bx
        mov     bh, [eth_tx_start]
        mov     ecx, ETH_ALEN
        call    eth_pio_write

        mov     esi, node_addr
        xor     bx, bx
        mov     bh, [eth_tx_start]
        add     bx, ETH_ALEN
        mov     ecx, ETH_ALEN
        call    eth_pio_write

        mov     esi, eth_type
        xor     bx, bx
        mov     bh, [eth_tx_start]
        add     bx, ETH_ALEN
        add     bx, ETH_ALEN
        mov     ecx, 2
        call    eth_pio_write

        popa

        xor     bx, bx
        mov     bh, [eth_tx_start]
        add     bx, ETH_HLEN
        push    ecx
        call    eth_pio_write
        pop     ecx

        add     ecx, ETH_HLEN
        cmp     ecx, ETH_ZLEN
        jae     .nst_001

        mov     ecx, ETH_ZLEN

  .nst_001:
        push    ecx

        mov     bx, [eth_nic_base]

        mov     dx, bx
        add     dx, D8390_P0_COMMAND
        mov     al, D8390_COMMAND_PS0_RD2_STA
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_TPSR
        mov     al, [eth_tx_start]
        out     dx, al

        pop     ecx

        mov     dx, bx
        add     dx, D8390_P0_TBCR0
        mov     al, cl
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_TBCR1
        mov     al, ch
        out     dx, al

        mov     dx, bx
        add     dx, D8390_P0_COMMAND
        mov     al, D8390_COMMAND_PS0_TXP_RD2_STA
        out     dx, al

        ret
