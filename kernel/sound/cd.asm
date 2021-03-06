;;======================================================================================================================
;;///// cd.asm ///////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2012 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
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

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.cd_audio_ctl, subfn, sysfn.not_implemented, \
    play, \ ; 1
    get_tracks_info, \ ; 2
    stop, \ ; 3
    eject_tray, \ ; 4
    load_tray ; 5
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]

;-----------------------------------------------------------------------------------------------------------------------
  ._.reserve: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_cd
        mov     eax, ecx
        shr     eax, 1
        and     eax, 1
        mov     [ChannelNumber], ax
        mov     eax, ecx
        and     eax, 1
        mov     [DiskNumber], al
        call    reserve_cd_channel
        and     ebx, 3
        inc     ebx
        mov     [cdpos], ebx
        add     ebx, ebx
        mov     cl, 8
        sub     cl, bl
        mov     al, [DRIVE_DATA + 1]
        shr     al, cl
        test    al, 2
        jz      ._.free
        ret

;-----------------------------------------------------------------------------------------------------------------------
  ._.free: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        call    free_cd_channel
        and     [cd_status], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.load_tray ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.5
;-----------------------------------------------------------------------------------------------------------------------
        call    sysfn.cd_audio_ctl._.reserve
        call    LoadMedium
        jmp     sysfn.cd_audio_ctl._.free
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.eject_tray ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.4
;-----------------------------------------------------------------------------------------------------------------------
        call    sysfn.cd_audio_ctl._.reserve
        call    clear_CD_cache
        call    allow_medium_removal
        call    EjectMedium
        jmp     sysfn.cd_audio_ctl._.free
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.play ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.1: start playing audio CD
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = start position, 0x00FFSSMM
;-----------------------------------------------------------------------------------------------------------------------
        call    sys_cdplay
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.get_tracks_info ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.2: get CD audio tracks information
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= buffer
;> ecx #= buffer size
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [current_slot_ptr]
        add     ebx, [edi + legacy.slot_t.task.mem_start]
        call    sys_cdtracklist
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.stop ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.3: stop/pause playing audio CD
;-----------------------------------------------------------------------------------------------------------------------
        call    sys_cdpause
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp
