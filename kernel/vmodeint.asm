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
        mov_s_  [old_screen_height], [Screen_Max_Pos.y]
        mov_s_  [old_screen_width], [Screen_Max_Pos.x]

        or      eax, -1 ; If driver is absent then eax does not change

        call    (VMODE_BASE + 0x100) ; Entry point of video driver

        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], ebx
        mov     [esp + 4 + regs_context32_t.ecx], ecx
;       mov     [esp + 4 + regs_context32_t.edx], edx

        mov     eax, [old_screen_width]
        mov     ebx, [old_screen_height]
        sub     eax, [Screen_Max_Pos.x]
        jnz     @f
        sub     ebx, [Screen_Max_Pos.y]
        jz      .resolution_wasnt_changed
        jmp     .lp1

    @@: sub     ebx, [Screen_Max_Pos.y]

  .lp1:
        sub     [screen_workarea.right], eax
        sub     [screen_workarea.bottom], ebx

        call    repos_windows
        xor     eax, eax
        xor     ebx, ebx
        mov     ecx, [Screen_Max_Pos.x]
        mov     edx, [Screen_Max_Pos.y]
        call    calculatescreen

  .resolution_wasnt_changed:
        ret
kendp
