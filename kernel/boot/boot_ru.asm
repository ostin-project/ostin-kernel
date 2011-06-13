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
;=======================================================================================================================

d80x25_bottom_num   = 3
num_remarks         = 3

d80x25_bottom       utf8 "║ Kolibri OS основана на Menuet OS и не предоставляет никаких гарaнтий.        ║", \
                         "║ Подробнее смотрите в файле COPYING.TXT                                       ║"
;///                         line_full_bottom
msg_apm             utf8 " APM x.x ", 0
novesa              utf8 "Видеокарта: EGA/CGA", 13, 10, 0
s_vesa              utf8 "Версия VESA: "
  .ver              utf8 "?.?", 13, 10, 0
gr_mode             utf8 "Выберите видеорежим: ", 13, 10, 0
vrrmprint           utf8 "Использовать VRR? (частота кадров выше 60 Гц только для переходов:", 13, 10, \
                         "║ 1024*768>800*600 и 800*600>640*480) [1-да, 2-нет]: ", 0
;ask_dma            utf8 "Использовать DMA для доступа к HDD? [1-да, 2-только чтение, 3-нет]: ", 0
ask_bd              utf8 "Добавить диски, видимые через BIOS в режиме V86? [1-да, 2-нет]: ",0
bdev                utf8 "Загрузить образ из [1-дискета; 2-C:\kolibri.img (FAT32);", 13, 10, \
                         "║                    3-использовать уже загруженный образ;", 13, 10, \
                         "║                    4-создать чистый образ]: ", 0
prnotfnd            utf8 "Ошибка - Видеорежим не найден.", 0
not386              utf8 "Ошибка - Требуется процессор 386+.", 0
fatalsel            utf8 "Ошибка - Выбранный видеорежим не поддерживается.", 0
pres_key            utf8 "Нажимите любую клавишу, для перехода в выбор режимов.", 0
badsect             utf8 13, 10, "║ Ошибка - Дискета повреждена. Попробуйте другую.", 0
memmovefailed       utf8 13, 10, "║ Ошибка - Int 0x15 move failed.", 0
okt                 utf8 " ... OK"
linef               utf8 13, 10, 0
diskload            utf8 "Загрузка дискеты: 00 %", 8, 8, 8, 8, 0
pros                utf8 "00"
backspace2          utf8 8, 8, 0
boot_dev            utf8 0
start_msg           utf8 "Нажмите [abcd] для изменения настроек, [Enter] для продолжения загрузки", 13, 10, 0
time_msg            utf8 "или подождите "
time_str            utf8 "(5) до автоматического продолжения", 13, 10, 0
current_cfg_msg     utf8 "Текущие настройки:", 13, 10, 0
curvideo_msg        utf8 " [a] Видеорежим: ", 0
mode0               utf8 "320x200, EGA/CGA 256 цветов", 13, 10, 0
mode9               utf8 "640x480, VGA 16 цветов", 13, 10, 0
usebd_msg           utf8 " [b] Добавить диски, видимые через BIOS:", 0
on_msg              utf8 " вкл", 13, 10, 0
off_msg             utf8 " выкл", 13, 10, 0
readonly_msg        utf8 " только чтение", 13, 10, 0
vrrm_msg            utf8 " [c] Использование VRR:", 0
preboot_device_msg  utf8 " [d] Образ дискеты: ", 0
pdm1                utf8 "настоящая дискета", 13, 10, 0
pdm2                utf8 "C:\kolibri.img (FAT32)", 13, 10, 0
pdm3                utf8 "использовать уже загруженный образ", 13, 10, 0
pdm4                utf8 "создать чистый образ", 13, 10, 0
loading_msg         utf8 "Идёт загрузка KolibriOS...", 0
save_quest          utf8 "Запомнить текущие настройки? [y/n]: ", 0
loader_block_error  utf8 "Ошибка в данных начального загрузчика, продолжение невозможно.", 0
_st                 utf8 "║                   ┌───────────────────────────────┬─┐  ", 13, 10, 0
_r1                 utf8 "║                   │  320x200  EGA/CGA 256 цветов  │ │  ", 13, 10, 0
_r2                 utf8 "║                   │  640x480  VGA 16 цветов       │ │  ", 13, 10, 0
_rs                 utf8 "║                   │  ????x????@??  SVGA VESA      │ │  ", 13, 10, 0
_bt                 utf8 "║                   └───────────────────────────────┴─┘  ", 13, 10, 0
remark1             utf8 "Значения по умолчанию выбраны для удобства большинства, но не всех.", 0
remark2             utf8 "Если у Вас ЭЛТ-монитор, включите VRR в пункте [c].", 0
remark3             utf8 "Если у Вас не грузится система, попробуйте отключить пункт [b].", 0

preboot_device_msgs dw 0, pdm1, pdm2, pdm3, pdm4
remarks             dw remark1, remark2, remark3

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
