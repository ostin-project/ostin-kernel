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

boot.data.s_keys_notice             utf8 "Up/Down/Enter/Esc - navigation, [F10] F11 - [save and] boot", 0

boot.data.s_current_settings        utf8 "Current settings", 0
boot.data.s_video_mode              utf8 "Videomode", 0
boot.data.s_use_bios_disks          utf8 "Add disks visible by BIOS", 0
boot.data.s_use_vrr                 utf8 "Use VRR", 0
boot.data.s_boot_source             utf8 "Floppy image", 0

boot.data.s_save_and_boot           utf8 "Save and continue boot", 0
boot.data.s_just_boot               utf8 "Continue without saving", 0

boot.data.s_video_mode_title        utf8 "Select a videomode", 0
boot.data.s_use_bios_disks_title    utf8 "Add disks visible by BIOS emulated in V86-mode", 0
boot.data.s_use_vrr_title           utf8 "Apply VRR (refresh rate >60Hz, only for 1024x768->800x600 and", 13, 10, \
                                         " 800x600->640x480 transitions)", 0
boot.data.s_boot_source_title       utf8 "Load ramdisk from", 0

boot.data.s_vmode_bpp               utf8 " bpp, ", 0
boot.data.s_vmode_ega_suffix        utf8 "EGA/CGA", 0
boot.data.s_vmode_vga_suffix        utf8 "VGA", 0
boot.data.s_vmode_vesa_suffix       utf8 "SVGA VESA", 0

boot.data.s_on                      utf8 "on", 0
boot.data.s_off                     utf8 "off", 0

boot.data.s_boot_source_1           utf8 "real floppy", 0
boot.data.s_boot_source_2           utf8 "C:\kolibri.img (FAT32)", 0
boot.data.s_boot_source_3           utf8 "use already loaded image", 0
boot.data.s_boot_source_4           utf8 "create blank image", 0

boot.data.s_saving_settings         utf8 "Saving settings...", 0

boot.data.s_loading_floppy          utf8 "Loading diskette: "
boot.data.s_loading_floppy_percent  utf8 "00 %", 8, 8, 8, 8, 0

boot.data.s_error                   utf8 "ERROR: ", 0
boot.data.s_bad_sector              utf8 "Bad sector. Replace floppy.", 0
boot.data.s_incompatible_cpu        utf8 "CPU 386+ required.", 0
boot.data.s_invalid_bootloader_data utf8 "Bootloader data is invalid.", 0
boot.data.s_mem_move_failed         utf8 "Int 0x15 move failed.", 0
boot.data.s_invalid_vmode           utf8 "Graphics mode not supported by hardware", 0
