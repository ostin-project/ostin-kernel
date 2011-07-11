;;======================================================================================================================
;;///// preboot.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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

; video mode
boot.params.vmode          boot_vmode_t
; use VRR_M (0 - no, 1 - yes)
boot.params.use_vrr        db 0
; use DMA for access to HDD (1 - always, 2 - only for read, 3 - never)
boot.params.use_dma        db 1
; use V86 to access disks through BIOS (0 - no, 1 - yes)
boot.params.use_bios_disks db 1
; boot device (-1 - autodetect, 0 - floppy, 1 - harddisk, 2 - kernel restart, 3 - format ram disk)
boot.params.boot_source    db 0

static_assert_ $ <= 0x200, "prebooting parameters must fit in first sector"

store dword -1 at boot.params.vmode.resolution

hdsysimage db 'KOLIBRI IMG' ; load from
image_save db 'KOLIBRI IMG' ; save to
