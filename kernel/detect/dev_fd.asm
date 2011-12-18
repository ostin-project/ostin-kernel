;;======================================================================================================================
;;///// dev_fd.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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
;? Find and save FDDs in table
;;======================================================================================================================

        mov     al, 0x10
        out     0x70, al
        mov     cx, 0x00ff

wait_cmos:
        dec     cx
        test    cx, cx
        jnz     wait_cmos
        in      al, 0x71
        mov     [DRIVE_DATA], al

        or      al, al
        jz      @f

        stdcall enable_irq, 6

    @@:
