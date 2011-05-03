;;======================================================================================================================
;;///// biosmem.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2009 KolibriOS team <http://kolibrios.org/>
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

; Query physical memory map from BIOS.
; diamond, 2009

        push    ds
; first call to fn E820
        mov     eax, 0xE820
        xor     ebx, ebx
        mov     es, bx
        mov     ds, bx
        mov     di, 0x9104
        mov     [di-4], ebx ; no blocks yet
        mov     ecx, 20
        mov     edx, 0x534D4150
        int     15h
        jc      no_E820
        cmp     eax, 0x534D4150
        jnz     no_E820
e820_mem_loop:
        cmp     byte [di+16], 1 ; ignore non-free areas
        jnz     e820_mem_next
        inc     byte [0x9100]
        add     di, 20
e820_mem_next:
; consequent calls to fn E820
        test    ebx, ebx
        jz      e820_test_done
        cmp     byte [0x9100], 32
        jae     e820_test_done
        mov     eax, 0xE820
        int     15h
        jc      e820_test_done
        jmp     e820_mem_loop
no_E820:
; let's hope for mem_test from init.inc
e820_test_done:
        pop     ds
