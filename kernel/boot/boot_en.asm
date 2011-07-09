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

boot.data.s_copyright_1             utf8 "(c) 2011 Ostin project", 0
boot.data.s_copyright_2             utf8 "(c) 2004-2011 KolibriOS team", 0
boot.data.s_copyright_3             utf8 "(c) 2000-2004 Ville Mikael Turjanmaa", 0
boot.data.s_version                 utf8 "version ", 0
boot.data.s_license                 utf8 ", under GNU GPL v2, with absolutely no warranty", 0

boot.data.s_keys_notice             utf8 "Up/Down/Enter/Esc - navigation, F10 - continue boot", 0

boot.data.s_your_choice             utf8 "Your choice: ", 0

boot.data.s_current_settings        utf8 "Current settings", 0
boot.data.s_video_mode              utf8 "Videomode", 0
boot.data.s_use_bios_disks          utf8 "Add disks visible by BIOS", 0
boot.data.s_use_vrr                 utf8 "Use VRR", 0
boot.data.s_boot_source             utf8 "Floppy image", 0

boot.data.s_video_mode_0            utf8 "320x200@8, EGA/CGA", 0
boot.data.s_video_mode_9            utf8 "640x480@4, VGA", 0
boot.data.s_video_mode_vesa         utf8 "????x????@??, SVGA VESA", 0

boot.data.s_on                      utf8 "on", 0
boot.data.s_off                     utf8 "off", 0

boot.data.s_boot_source_1           utf8 "real floppy", 0
boot.data.s_boot_source_2           utf8 "C:\kolibri.img (FAT32)", 0
boot.data.s_boot_source_3           utf8 "use already loaded image", 0
boot.data.s_boot_source_4           utf8 "create blank image", 0

boot.data.s_error                   utf8 "ERROR: ", 0
boot.data.s_bad_sector              utf8 "Bad sector. Replace floppy.", 0
boot.data.s_incompatible_cpu        utf8 "CPU 386+ required.", 0
boot.data.s_invalid_bootloader_data utf8 "Bootloader data is invalid.", 0
boot.data.s_mem_move_failed         utf8 "Int 0x15 move failed.", 0

msg_apm             utf8 " APM x.x ", 0
s_vesa              utf8 "Version of VESA: "
  .ver              utf8 "?.?", 13, 10, 0
gr_mode             utf8 "Select a videomode: ", 13, 10, 0
vrrmprint           utf8 "Apply VRR? (picture frequency greater than 60Hz only for transfers:", 13, 10, \
                         "║ 1024*768->800*600 and 800*600->640*480) [1-yes,2-no]:", 0
ask_bd              utf8 "Add disks visible by BIOS emulated in V86-mode? [1-yes, 2-no]: ", 0
bdev                utf8 "Load ramdisk from [1-floppy; 2-C:\kolibri.img (FAT32);", 13, 10, \
                         "║                    3-use preloaded ram-image from kernel restart;", 13, 10, \
                         "║                    4-create blank image]: ", 0
fatalsel            utf8 "Fatal - Graphics mode not supported by hardware.", 0
pres_key            utf8 "Press any key to choose a new videomode.", 0
okt                 utf8 " ... OK", 13, 10, 0
diskload            utf8 "Loading diskette: 00 %", 8, 8, 8, 8, 0
pros                utf8 "00"
backspace2          utf8 8, 8, 0
boot_dev            utf8 0 ; 0 = floppy, 1 = hd
loading_msg         utf8 "Loading KolibriOS...", 0
save_quest          utf8 "Remember current settings? [y/n]: ", 0
_st                 utf8 "║                   ┌───────────────────────────────┬─┐", 13, 10, 0
_r1                 utf8 "║                   │  320x200  EGA/CGA 256 colors  │ │", 13, 10, 0
_r2                 utf8 "║                   │  640x480  VGA 16 colors       │ │", 13, 10, 0
_rs                 utf8 "║                   │  ????x????@??  SVGA VESA      │ │", 13, 10, 0
_bt                 utf8 "║                   └───────────────────────────────┴─┘", 13, 10, 0
