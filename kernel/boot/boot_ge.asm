;;======================================================================================================================
;;///// boot_ge.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
;? Boot data (German)
;;======================================================================================================================

d80x25_bottom_num   = 3
num_remarks         = 3
vervesa_off         = 22

d80x25_bottom       db "║ KolibriOS basiert auf MenuetOS und wird ohne jegliche  Garantie vertrieben   ║"
                    db "║ Details stehen in der Datei COPYING                                          ║"
                    line_full_bottom
novesa              db "Anzeige: EGA/CGA ", 13, 10, 0
vervesa             db "Vesa-Version:    Vesa        ", 13, 10, 0
msg_apm             db " APM x.x ", 0
gr_mode             db "║ Vesa 2.0+ 16 M LFB:  [1] 640x480, [2] 800x600, [3] 1024x768, [4] 1280x1024", 13, 10
                    db "║ Vesa 1.2  16 M Bnk:  [5] 640x480, [6] 800x600, [7] 1024x768, [8] 1280x1024", 13, 10
                    db "║ EGA/CGA   256 Farben:  [9] 320x200, VGA 16 Farben: [0]  640x480", 13, 10
                    db "║ Waehle Modus: ", 0
bt24                db "Bits Per Pixel: 24", 13, 10, 0
bt32                db "Bits Per Pixel: 32", 13, 10, 0
vrrmprint           db "VRR verwenden? (Monitorfrequenz groesser als 60Hz only for transfers:", 13, 10
                    db "║ 1024*768->800*600 und 800*600->640*480) [1-ja,2-nein]:", 0
;askmouse           db " Maus angeschlossen an: [1] PS/2 (USB), [2] Com1, [3] Com2. Waehle Port [1-3]: ", 0
;no_com1            db 13, 10, "║ Keine COM1 Maus", 0
;no_com2            db 13, 10, "║ Keine COM2 Maus", 0
;ask_dma            db "Nutze DMA zum HDD Zugriff? [1-ja, 2-allein fur Lesen, 3-nein]: ", 0
ask_bd              db "Add disks visible by BIOS emulated in V86-mode? [1-yes, 2-no]: ", 0
;gr_direct          db "║ Benutze direct LFB? [1-ja/2-nein] ? ", 0
;mem_model          db 13, 10, "║ Hauptspeicher [1-16 Mb / 2-32 Mb / 3-64Mb / 4-128 Mb / 5-256 Mb] ? ", 0
;bootlog            db 13, 10, "║ After bootlog display [1-continue/2-pause] ? ", 0
bdev                db "Lade die Ramdisk von [1-Diskette; 2-C:\kolibri.img (FAT32);", 13, 10
                    db "║                    3-benutze ein bereits geladenes Kernel image;", 13, 10
                    db "║                    4-create blank image]: ", 0
probetext           db 13, 10, 13, 10
                    db "║ Nutze Standardgrafikmodi? [1-ja, 2-BIOS Test (Vesa 3.0)]: ", 0
;memokz256          db 13, 10, "║ RAM 256 Mb", 0
;memokz128          db 13, 10, "║ RAM 128 Mb", 0
;memokz64           db 13, 10, "║ RAM 64 Mb", 0
;memokz32           db 13, 10, "║ RAM 32 Mb", 0
;memokz16           db 13, 10, "║ RAM 16 Mb", 0
prnotfnd            db "Fatal - Videomodus nicht gefunden.", 0
;modena             db "Fatal - VBE 0x112+ required.", 0
not386              db "Fatal - CPU 386+ benoetigt.", 0
btns                db "Fatal - konnte Farbtiefe nicht erkennen.", 0
fatalsel            db "Fatal - Grafikmodus nicht unterstuetzt.", 0
badsect             db 13, 10, "║ Fatal - Sektorfehler, Andere Diskette neutzen.", 0
memmovefailed       db 13, 10, "║ Fatal - Int 0x15 Fehler.", 0
okt                 db " ... OK"
linef               db 13, 10, 0
diskload            db "Lade Diskette: 00 %", 8, 8, 8, 8, 0
pros                db "00"
backspace2          db 8, 8, 0
start_msg           db "Druecke [abcd], um die Einstellungen zu aendern , druecke [Enter] zum starten", 13, 10, 0
time_msg            db " oder warte "
time_str            db " 5 Sekunden bis zum automatischen Start", 13, 10, 0
current_cfg_msg     db "Aktuelle Einstellungen:", 13, 10, 0
curvideo_msg        db " [a] Videomodus: ", 0
mode1               db "640x480", 0
mode2               db "800x600", 0
mode3               db "1024x768", 0
mode4               db "1280x1024", 0
modevesa20          db " mit LFB", 0
modevesa12          db ", VESA 1.2 Bnk", 0
mode9               db "320x200, EGA/CGA 256 colors", 0
mode10              db "640x480, VGA 16 colors", 0
probeno_msg         db " (Standard Modus)", 0
probeok_msg         db " (teste nicht-standard Modi)", 0
;dma_msg            db " [b] Nutze DMA zum HDD Aufschreiben:", 0
usebd_msg           db " [b] Add disks visible by BIOS:", 0
on_msg              db " an", 13, 10, 0
off_msg             db " aus", 13, 10, 0
;readonly_msg       db " fur Lesen", 13, 10, 0
vrrm_msg            db " [c] Nutze VRR:", 0
preboot_device_msg  db " [d] Diskettenimage: ", 0
pdm1                db "Echte Diskette", 13, 10, 0
pdm2                db "C:\kolibri.img (FAT32)", 13, 10, 0
pdm3                db "Nutze bereits geladenes Image", 13, 10, 0
pdm4                db "create blank image", 13, 10, 0
loading_msg         db "Lade KolibriOS...", 0
save_quest          db "Aktuelle Einstellungen speichern? [y/n]: ", 0
loader_block_error  db "Bootloader Daten ungueltig, Kann nicht fortfahren. Angehalten.", 0
remark1             db "Default values were selected to match most of configurations, but not all.", 0
remark2             db "If you have CRT-monitor, enable VRR in the item [c].", 0
remark3             db "If the system does not boot, try to disable the item [b].", 0

modes_msg           dw mode4, mode1, mode2, mode3
preboot_device_msgs dw 0, pdm1, pdm2, pdm3
remarks             dw remark1, remark2, remark3
