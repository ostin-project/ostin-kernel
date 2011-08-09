;;======================================================================================================================
;;///// rdsave.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
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

iglobal
  saverd_fileinfo:
    dd 2           ; subfunction: write
    dd 0           ; (reserved)
    dd 0           ; (reserved)
    dd 1440 * 1024 ; size 1440 Kb
    dd RAMDISK
    db 0
    .name dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn_saveramdisk ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? 18.6 = SAVE FLOPPY IMAGE (HD version only)
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, RAMDISK_FAT
        mov     edi, RAMDISK + 512
        call    fs.fat12.restore_fat_chain
        mov     ebx, saverd_fileinfo
        mov     [saverd_fileinfo.name], ecx
        pushad
        call    file_system_lfn ; in ebx
        popad
        mov     [esp + 32], eax
        ret
kendp
