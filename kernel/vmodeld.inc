;;======================================================================================================================
;;///// vmodeld.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2007 KolibriOS team <http://kolibrios.org/>
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
; Load of videomode driver in memory
;
; (driver is located at VMODE_BASE  - 32kb) // if this area not occuped anything
;
; Author: Trans
; Date:  19.07.2003
;
; Include in MeOS kernel and compile with FASM
;


; LOAD VIDEOMODE DRIVER
                                       ; If vmode.mdr file not found
        or    eax,-1                   ; Driver ID = -1 (not present in system)
        mov   [VMODE_BASE],eax   ;
        mov   [VMODE_BASE+0x100],byte 0xC3     ; Instruction RETN - driver loop
        
        stdcall read_file, vmode, VMODE_BASE, 0, 0x8000			;{SPraid.simba}
;        mov     esi, vmode
;        xor     ebx, ebx
;        mov     ecx, 0x8000            ; size of memory area for driver
;        mov     edx, VMODE_BASE        ; Memory position of driver
;        xor     ebp, ebp
;        call    fs_RamdiskRead
