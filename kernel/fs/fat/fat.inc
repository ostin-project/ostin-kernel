;;======================================================================================================================
;;///// fat.inc //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011-2012 Ostin project <http://ostin.googlecode.com/>
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

include "fat.asm"
include "fat_util.asm"

match =1, KCONFIG_FS_FAT12
{
include "fat12.asm"
}
match =1, KCONFIG_FS_FAT16
{
include "fat16.asm"
}
match =1, KCONFIG_FS_FAT32
{
include "fat32.asm"
}
