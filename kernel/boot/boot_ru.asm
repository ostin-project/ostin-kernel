;;======================================================================================================================
;;///// boot_ru.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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
;? Boot data (Russian)
;;======================================================================================================================

boot.data.s_copyright_1             utf8 "(c) 2011 Проект Ostin", 0
boot.data.s_copyright_2             utf8 "(c) 2004-2011 Команда KolibriOS", 0
boot.data.s_copyright_3             utf8 "(c) 2000-2004 Вилле Микаэль Турьянмаа", 0
boot.data.s_version                 utf8 "версия ", 0
boot.data.s_license                 utf8 ", под GNU GPL v2, без каких-либо гарантий", 0

boot.data.s_keys_notice             utf8 "Вверх/Вниз/Ввод/Esc - навигация, F10 - продолжить загрузку", 0

boot.data.s_your_choice             utf8 "Ваш выбор: ", 0

boot.data.s_current_settings        utf8 "Текущие настройки", 0
boot.data.s_video_mode              utf8 "Видеорежим", 0
boot.data.s_use_bios_disks          utf8 "Добавить диски, видимые через BIOS", 0
boot.data.s_use_vrr                 utf8 "Использование VRR", 0
boot.data.s_boot_source             utf8 "Образ дискеты", 0

boot.data.s_video_mode_0            utf8 "320x200, EGA/CGA 256 цветов", 0
boot.data.s_video_mode_9            utf8 "640x480, VGA 16 цветов", 0
boot.data.s_video_mode_vesa         utf8 "????x????@??, SVGA VESA", 0

boot.data.s_on                      utf8 "вкл", 0
boot.data.s_off                     utf8 "выкл", 0

boot.data.s_boot_source_1           utf8 "настоящая дискета", 0
boot.data.s_boot_source_2           utf8 "C:\kolibri.img (FAT32)", 0
boot.data.s_boot_source_3           utf8 "использовать уже загруженный образ", 0
boot.data.s_boot_source_4           utf8 "создать чистый образ", 0

boot.data.s_error                   utf8 "ОШИБКА: ", 0
boot.data.s_bad_sector              utf8 "Дискета повреждена. Попробуйте другую.", 0
boot.data.s_incompatible_cpu        utf8 "Требуется процессор 386+.", 0
boot.data.s_invalid_bootloader_data utf8 "Некорректные данные начального загрузчика.", 0
boot.data.s_mem_move_failed         utf8 "Int 0x15 move failed.", 0

msg_apm             utf8 " APM x.x ", 0
s_vesa              utf8 "Версия VESA: "
  .ver              utf8 "?.?", 13, 10, 0
gr_mode             utf8 "Выберите видеорежим: ", 13, 10, 0
vrrmprint           utf8 "Использовать VRR? (частота кадров выше 60 Гц только для переходов:", 13, 10, \
                         "║ 1024*768>800*600 и 800*600>640*480) [1-да, 2-нет]: ", 0
ask_bd              utf8 "Добавить диски, видимые через BIOS в режиме V86? [1-да, 2-нет]: ",0
bdev                utf8 "Загрузить образ из [1-дискета; 2-C:\kolibri.img (FAT32);", 13, 10, \
                         "║                    3-использовать уже загруженный образ;", 13, 10, \
                         "║                    4-создать чистый образ]: ", 0
fatalsel            utf8 "Выбранный видеорежим не поддерживается", 0
pres_key            utf8 "Нажимите любую клавишу, для перехода в выбор режимов.", 0
okt                 utf8 " ... OK", 13, 10, 0
diskload            utf8 "Загрузка дискеты: 00 %", 8, 8, 8, 8, 0
pros                utf8 "00"
backspace2          utf8 8, 8, 0
boot_dev            utf8 0
loading_msg         utf8 "Идёт загрузка KolibriOS...", 0
save_quest          utf8 "Запомнить текущие настройки? [y/n]: ", 0
_st                 utf8 "║                   ┌───────────────────────────────┬─┐  ", 13, 10, 0
_r1                 utf8 "║                   │  320x200  EGA/CGA 256 цветов  │ │  ", 13, 10, 0
_r2                 utf8 "║                   │  640x480  VGA 16 цветов       │ │  ", 13, 10, 0
_rs                 utf8 "║                   │  ????x????@??  SVGA VESA      │ │  ", 13, 10, 0
_bt                 utf8 "║                   └───────────────────────────────┴─┘  ", 13, 10, 0

include "boot/ru.inc"

;-----------------------------------------------------------------------------------------------------------------------
boot.init_l10n: ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     bp, RU_FNT1 ; RU_FNT1 - First part
        mov     bx, 0x1000 ; 768 bytes
        mov     cx, 0x30 ; 48 symbols
        mov     dx, 0x80 ; 128 - position of first symbol
        mov     ax, 0x1100
        int     0x10
        mov     bp, RU_FNT2 ; RU_FNT2 - Second part
        mov     bx, 0x1000 ; 512 bytes
        mov     cx, 0x20 ; 32 symbols
        mov     dx, 0xe0 ; 224 - position of first symbol
        mov     ax, 0x1100
        int     0x10
        ret
