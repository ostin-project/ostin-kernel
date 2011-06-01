;;======================================================================================================================
;;///// vmodeint.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

; Call of videomode driver's functions
;
; (Add in System function 21 (and/or 26) as a subfunction 13)
;
; Author: Trans
; Date:  19.07.2003
;
; Include in MeOS kernel and compile with FASM

uglobal
  old_screen_width  dd ?
  old_screen_height dd ?
endg

;       cmp     eax, 13 ; CALL VIDEOMODE DRIVER FUNCTIONS
        dec     ebx
        jnz     .no_vmode_drv_access
        pushd   [Screen_Max_X] [Screen_Max_Y]
        popd    [old_screen_height] [old_screen_width]
        or      eax, -1 ; If driver is absent then eax does not change
        call    (VMODE_BASE + 0x100) ; Entry point of video driver
        mov     [esp + 36 - 4], eax
        mov     [esp + 24 - 4], ebx
        mov     [esp + 32 - 4], ecx
;       mov     [esp + 28], edx
        mov     eax, [old_screen_width]
        mov     ebx, [old_screen_height]
        sub     eax, [Screen_Max_X]
        jnz     @f
        sub     ebx, [Screen_Max_Y]
        jz      .resolution_wasnt_changed
        jmp     .lp1

    @@: sub     ebx, [Screen_Max_Y]

  .lp1:
        sub     [screen_workarea.right], eax
        sub     [screen_workarea.bottom], ebx

        call    repos_windows
        xor     eax, eax
        xor     ebx, ebx
        mov     ecx, [Screen_Max_X]
        mov     edx, [Screen_Max_Y]
        call    calculatescreen

  .resolution_wasnt_changed:
        ret

  .no_vmode_drv_access:
