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
;? Call of videomode driver's functions
;;======================================================================================================================

uglobal
  old_screen_width  dd ?
  old_screen_height dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.video_ctl ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.13: call videomode driver functions
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  [old_screen_height], dword[Screen_Max_Y]
        mov_s_  [old_screen_width], dword[Screen_Max_X]

        or      eax, -1 ; If driver is absent then eax does not change

        call    (VMODE_BASE + 0x100) ; Entry point of video driver

        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], ebx
        mov     [esp + 4 + regs_context32_t.ecx], ecx
;       mov     [esp + 4 + regs_context32_t.edx], edx

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
kendp
