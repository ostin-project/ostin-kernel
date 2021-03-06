;;======================================================================================================================
;;///// boot_et.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
;? Boot data (Estonian)
;;======================================================================================================================

d80x25_bottom_num   = 3
num_remarks         = 3
vervesa_off         = 20

d80x25_bottom       db "║ KolibriOS based on MenuetOS and comes with ABSOLUTELY NO WARRANTY            ║"
                    db "║ See file COPYING for details                                                 ║"
                    line_full_bottom
novesa              db "Ekraan: EGA/CGA", 13, 10, 0
vervesa             db "Vesa versioon: Vesa x.x", 13, 10, 0
msg_apm             db " APM x.x ", 0
gr_mode             db "║ Vesa 2.0+ 16 M LFB:  [1] 640x480, [2] 800x600, [3] 1024x768, [4] 1280x1024", 13, 10
                    db "║ Vesa 1.2  16 M Bnk:  [5] 640x480, [6] 800x600, [7] 1024x768, [8] 1280x1024", 13, 10
                    db "║ EGA/CGA   256 värvi:  [9] 320x200, VGA 16 värvi: [0]  640x480", 13, 10
                    db "║ Vali reziim: ", 0
bt24                db "Bitti pikseli kohta: 24", 13, 10, 0
bt32                db "Bitti pikseli kohta: 32", 13, 10, 0
vrrmprint           db "Kinnita VRR? (ekraani sagedus suurem kui 60Hz ainult:", 13, 10
                    db "║ 1024*768->800*600 ja 800*600->640*480) [1-jah,2-ei]:", 0
;askmouse           db " Hiir: [1] PS/2 (USB), [2] Com1, [3] Com2. Vali port [1-3]: ", 0
;no_com1            db 13, 10, "║ No COM1 mouse", 0
;no_com2            db 13, 10, "║ No COM2 mouse", 0
;ask_dma            db "Use DMA for HDD access? [1-yes, 2-only for reading, 3-no]: ", 0
ask_bd              db "Add disks visible by BIOS emulated in V86-mode? [1-yes, 2-no]: ", 0
;gr_direct          db "║ Use direct LFB writing? [1-yes/2-no] ? ", 0
;mem_model          db 13, 10, "║ Motherboard memory [1-16 Mb / 2-32 Mb / 3-64Mb / 4-128 Mb / 5-256 Mb] ? ", 0
;bootlog            db 13,10,"║ After bootlog display [1-continue/2-pause] ? ", 0
bdev                db "Paigalda mäluketas [1-diskett; 2-C:\kolibri.img (FAT32);", 13, 10
                    db "║                    3-kasuta eellaaditud mäluketast kerneli restardist;", 13, 10
                    db "║                    4-loo tühi pilt]: ", 0
probetext           db 13, 10, 13, 10
                    db "║ Kasuta standartset graafika reziimi? [1-jah, 2-leia biosist (Vesa 3.0)]: ", 0
;memokz256          db 13, 10, "║ RAM 256 Mb", 0
;memokz128          db 13, 10, "║ RAM 128 Mb", 0
;memokz64           db 13, 10, "║ RAM 64 Mb", 0
;memokz32           db 13, 10, "║ RAM 32 Mb", 0
;memokz16           db 13, 10, "║ RAM 16 Mb", 0
prnotfnd            db "Fataalne - Videoreziimi ei leitud.", 0
;modena             db "Fataalne - VBE 0x112+ on vajalik.", 0
not386              db "Fataalne - CPU 386+ on vajalik.", 0
btns                db "Fataalne - Ei suuda värvisügavust määratleda.", 0
fatalsel            db "Fataalne - Graafilist reziimi riistvara ei toeta.", 0
badsect             db 13, 10, "║ Fataalne - Vigane sektor. Asenda diskett.", 0
memmovefailed       db 13, 10, "║ Fataalne - Int 0x15 liigutamine ebaõnnestus.", 0
okt                 db " ... OK"
linef               db 13, 10, 0
diskload            db "Loen disketti: 00 %", 8, 8, 8, 8, 0
pros                db "00"
backspace2          db 8, 8, 0
start_msg           db "Vajuta [abcd] seadete muutmiseks, vajuta [Enter] laadimise jätkamiseks", 13, 10, 0
time_msg            db " või oota "
time_str            db " 5 sekundit automaatseks jätkamiseks", 13, 10, 0
current_cfg_msg     db "Praegused seaded:", 13, 10, 0
curvideo_msg        db " [a] Videoreziim: ", 0
mode1               db "640x480", 0
mode2               db "800x600", 0
mode3               db "1024x768", 0
mode4               db "1280x1024", 0
modevesa20          db " koos LFB", 0
modevesa12          db ", VESA 1.2 Bnk", 0
mode9               db "320x200, EGA/CGA 256 värvi", 0
mode10              db "640x480, VGA 16 värvi", 0
probeno_msg         db " (standard reziim)", 0
probeok_msg         db " (kontrolli ebastandardseid reziime)", 0
;dma_msg            db " [b] Kasuta DMA'd HDD juurdepääsuks:", 0
usebd_msg           db " [b] Add disks visible by BIOS:", 0
on_msg              db " sees", 13, 10, 0
off_msg             db " väljas", 13, 10, 0
;readonly_msg       db " ainult lugemiseks", 13, 10, 0
vrrm_msg            db " [c] Kasuta VRR:", 0
preboot_device_msg  db " [d] Disketi kujutis: ", 0
pdm1                db "reaalne diskett", 13, 10, 0
pdm2                db "C:\kolibri.img (FAT32)", 13, 10, 0
pdm3                db "kasuta juba laaditud kujutist", 13, 10, 0
pdm4                db "loo tühi pilt", 13, 10, 0
loading_msg         db "Laadin KolibriOS...", 0
save_quest          db "Jäta meelde praegused seaded? [y/n]: ", 0
loader_block_error  db "Alglaaduri andmed vigased, ei saa jätkata. Peatatud.", 0
remark1             db "Default values were selected to match most of configurations, but not all.", 0
remark2             db "If you have CRT-monitor, enable VRR in the item [c].", 0
remark3             db "If the system does not boot, try to disable the item [b].", 0

modes_msg           dw mode4, mode1, mode2, mode3
preboot_device_msgs dw 0, pdm1, pdm2, pdm3
remarks             dw remark1, remark2, remark3

include "boot/et.inc"

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.init_l10n ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     bp, ET_FNT ; ET_FNT1
        mov     bx, 0x1000
        mov     cx, 255 ; 256 symbols
        xor     dx, dx ; 0 - position of first symbol
        mov     ax, 0x1100
        int     0x10
        ret
kendp
