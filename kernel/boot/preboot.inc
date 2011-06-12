;;======================================================================================================================
;;///// preboot.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
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

display_modechg  db 0 ; display mode change for text, yes/no (0 or 2)
                      ; Note: Must be set to 2, to avoid two screenmode changes within a very short period of time.

display_atboot   db 0 ; show boot screen messages ( 2-no )

preboot_graph    dw 0 ; graph mode
x_save           dw 0 ; x
y_save           dw 0 ; y
number_vm        dw 0 ;
;pixel_save      dw 0 ; per to pixel
preboot_gprobe   db 0 ; probe vesa3 videomodes (1-no, 2-yes)
preboot_vrrm     db 0 ; use VRR_M (1-yes, 2- no)
preboot_dma      db 0 ; use DMA for access to HDD (1-always, 2-only for read, 3-never)
preboot_device   db 0 ; boot device (0 - autodetect, 1 - floppy, 2 - harddisk, 3 - kernel restart, 4 - format ram disk)
preboot_biosdisk db 0 ; use V86 to access disks through BIOS (1-yes, 2-no)

if $ > 0x200

ERROR: prebooting parameters must fit in first sector!!!

end if

hdsysimage db 'KOLIBRI IMG' ; load from
image_save db 'KOLIBRI IMG' ; save to
