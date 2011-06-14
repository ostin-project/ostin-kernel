;;======================================================================================================================
;;///// boot_en.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
;? Boot data (English)
;;======================================================================================================================

;d80x25_bottom_num   = 3
;num_remarks         = 3

boot.data:
  .s_copyright_1             utf8 "(c) 2011 Ostin project", 0
  .s_copyright_2             utf8 "(c) 2004-2011 KolibriOS team", 0
  .s_copyright_3             utf8 "(c) 2000-2004 Ville Mikael Turjanmaa", 0
  .s_version                 utf8 " version ", 0
  .s_license                 utf8 ", under GNU GPL v2, with absolutely no warranty", 0

  .s_video_mode              utf8 " (1) Videomode: ", 0
  .s_use_bios_disks          utf8 " (2) Add disks visible by BIOS: ", 0
  .s_use_vrr                 utf8 " (3) Use VRR: ", 0
  .s_boot_source             utf8 " (4) Floppy image: ", 0

  .s_on                      utf8 "on", 0
  .s_off                     utf8 "off", 0

  .s_boot_source_1           utf8 " (1) "
  .s_boot_source_1.name      utf8 "real floppy", 0
  .s_boot_source_2           utf8 " (2) "
  .s_boot_source_2.name      utf8 "C:\kolibri.img (FAT32)", 0
  .s_boot_source_3           utf8 " (3) "
  .s_boot_source_3.name      utf8 "use already loaded image", 0
  .s_boot_source_4           utf8 " (4) "
  .s_boot_source_4.name      utf8 "create blank image", 0

  .s_error                   utf8 "ERROR: ", 0
  .s_bad_sector              utf8 "Bad sector. Replace floppy.", 0
  .s_incompatible_cpu        utf8 "CPU 386+ required.", 0
  .s_invalid_bootloader_data utf8 "Bootloader data is invalid.", 0
  .s_mem_move_failed         utf8 "Int 0x15 move failed.", 0

d80x25_bottom       utf8 "║ KolibriOS is based on MenuetOS and comes with ABSOLUTELY NO WARRANTY         ║", \
                         "║ See file COPYING for details                                                 ║"
;///                         line_full_bottom
msg_apm             utf8 " APM x.x ", 0
vervesa             utf8 "Version of Vesa: Vesa x.x", 13, 10, 0
novesa              utf8 "Display: EGA/CGA", 13, 10, 0
s_vesa              utf8 "Version of VESA: "
  .ver              utf8 "?.?", 13, 10, 0
gr_mode             utf8 "Select a videomode: ", 13, 10, 0
;s_bpp              utf8 13, 10, "║ Глубина цвета: "
;  .bpp             utf8 "??"
;                   utf8 13, 10, 0
vrrmprint           utf8 "Apply VRR? (picture frequency greater than 60Hz only for transfers:", 13, 10, \
                         "║ 1024*768->800*600 and 800*600->640*480) [1-yes,2-no]:", 0
ask_bd              utf8 "Add disks visible by BIOS emulated in V86-mode? [1-yes, 2-no]: ", 0
bdev                utf8 "Load ramdisk from [1-floppy; 2-C:\kolibri.img (FAT32);", 13, 10, \
                         "║                    3-use preloaded ram-image from kernel restart;", 13, 10, \
                         "║                    4-create blank image]: ", 0
probetext           utf8 13, 10, 13, 10, \
                         "║ Use standart graphics mode? [1-yes, 2-probe bios (Vesa 3.0)]: ", 0
;memokz256          utf8 13, 10, "║ RAM 256 Mb", 0
;memokz128          utf8 13, 10, "║ RAM 128 Mb", 0
;memokz64           utf8 13, 10, "║ RAM 64 Mb", 0
;memokz32           utf8 13, 10, "║ RAM 32 Mb", 0
;memokz16           utf8 13, 10, "║ RAM 16 Mb", 0
prnotfnd            utf8 "Fatal - Videomode not found.", 0
;modena             utf8 "Fatal - VBE 0x112+ required.", 0
btns                utf8 "Fatal - Can't determine color depth.", 0
fatalsel            utf8 "Fatal - Graphics mode not supported by hardware.", 0
pres_key            utf8 "Press any key to choose a new videomode.", 0
okt                 utf8 " ... OK"
linef               utf8 13, 10, 0
diskload            utf8 "Loading diskette: 00 %", 8, 8, 8, 8, 0
pros                utf8 "00"
backspace2          utf8 8, 8, 0
boot_dev            utf8 0 ; 0 = floppy, 1 = hd
start_msg           utf8 "Press [abcd] to change settings, press [Enter] to continue booting", 13, 10, 0
time_msg            utf8 " or wait "
time_str            utf8 "(5) before automatical continuation", 13, 10, 0
current_cfg_msg     utf8 "Current settings:", 13, 10, 0
curvideo_msg        utf8 " [a] Videomode: ", 0
;modevesa20         utf8 " with LFB", 0
;modevesa12         utf8 ", VESA 1.2 Bnk", 0
mode0               utf8 "320x200, EGA/CGA 256 colors", 13, 10, 0
mode9               utf8 "640x480, VGA 16 colors", 13, 10, 0
;probeno_msg        utf8 " (standard mode)", 0
;probeok_msg        utf8 " (check nonstandard modes)", 0
;dma_msg            utf8 " [b] Use DMA for HDD access:", 0
usebd_msg           utf8 " [b] Add disks visible by BIOS:", 0
on_msg              utf8 " on", 13, 10, 0
off_msg             utf8 " off", 13, 10, 0
;readonly_msg       utf8 " only for reading", 13, 10, 0
vrrm_msg            utf8 " [c] Use VRR:", 0
preboot_device_msg  utf8 " [d] Floppy image: ", 0
pdm1                utf8 "real floppy", 13, 10, 0
pdm2                utf8 "C:\kolibri.img (FAT32)", 13, 10, 0
pdm3                utf8 "use already loaded image", 13, 10, 0
pdm4                utf8 "create blank image", 13, 10, 0
loading_msg         utf8 "Loading KolibriOS...", 0
save_quest          utf8 "Remember current settings? [y/n]: ", 0
_st                 utf8 "║                   ┌───────────────────────────────┬─┐", 13, 10, 0
_r1                 utf8 "║                   │  320x200  EGA/CGA 256 colors  │ │", 13, 10, 0
_r2                 utf8 "║                   │  640x480  VGA 16 colors       │ │", 13, 10, 0
_rs                 utf8 "║                   │  ????x????@??  SVGA VESA      │ │", 13, 10, 0
_bt                 utf8 "║                   └───────────────────────────────┴─┘", 13, 10, 0
remark1             utf8 "Default values were selected to match most of configurations, but not all.", 0
remark2             utf8 "If you have CRT-monitor, enable VRR in the item [c].", 0
remark3             utf8 "If the system does not boot, try to disable the item [b].", 0

;modes_msg          dw mode4, mode1, mode2, mode3
;preboot_device_msgs dw 0, pdm1, pdm2, pdm3
;remarks             dw remark1, remark2, remark3
