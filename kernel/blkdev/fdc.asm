;;======================================================================================================================
;;///// fdc.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
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

iglobal
  ; function pointers.
  fdc_irq_func dd \
    fdc_null
endg

uglobal
  dmasize db ?
  dmamode db ?
endg

;-----------------------------------------------------------------------------------------------------------------------
fdc_init: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? start with clean tracks.
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, OS_BASE + 0xd201
        mov     al, 0
        mov     ecx, 160
        rep     stosb
        ret

;-----------------------------------------------------------------------------------------------------------------------
fdc_irq: ;//////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    [fdc_irq_func]

fdc_null:
        ret

;-----------------------------------------------------------------------------------------------------------------------
save_image: ;///////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_flp
        call    restorefatchain
        pusha
        call    check_label
        cmp     [FDC_Status], 0
        jne     .unnecessary_save_image

        mov     [FDD_Track], 0 ; Цилиндр
        mov     [FDD_Head], 0 ; Сторона
        mov     [FDD_Sector], 1 ; Сектор
        mov     esi, RAMDISK
        call    SeekTrack

  .save_image_1:
        push    esi
        call    take_data_from_application_1
        pop     esi
        add     esi, 512
;       call    WriteSector
        call    WriteSectWithRetr
        cmp     [FDC_Status], 0
        jne     .unnecessary_save_image
        inc     [FDD_Sector]
        cmp     [FDD_Sector], 19
        jne     .save_image_1
        mov     [FDD_Sector], 1
        inc     [FDD_Head]
        cmp     [FDD_Head], 2
        jne     .save_image_1
        mov     [FDD_Head], 0
        inc     [FDD_Track]
        call    SeekTrack
        cmp     [FDD_Track], 80
        jne     .save_image_1

  .unnecessary_save_image:
        mov     [fdc_irq_func], fdc_null
        popa
        mov     [flp_status], 0
        ret
