;;======================================================================================================================
;;///// pci16.inc ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2007 KolibriOS team <http://kolibrios.org/>
;; (c) 2002 MenuetOS <http://menuetos.net/>
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

init_pci_16:
        pushad

        xor     ax, ax
        mov     es, ax
        mov     byte[es:0x09020], 1 ; default mechanism:1
        mov     ax, 0x0b101
        int     0x1a
        or      ah, ah
        jnz     .pci16skip

        mov     [es:0x09021], cl ; last PCI bus in system
        mov     [es:0x09022], bx
        mov     [es:0x09024], edi

        ; we have a PCI BIOS, so check which configuration mechanism(s)
        ; it supports
        ; AL = PCI hardware characteristics (bit0 => mechanism1, bit1 => mechanism2)
        test    al, 1
        jnz     .pci16skip
        test    al, 2
        jz      .pci16skip
        mov     byte[es:0x09020], 2 ; if (al&3)==2 => mechanism 2

  .pci16skip:
        mov     ax, 0x1000
        mov     es, ax

        popad
