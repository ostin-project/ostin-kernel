;;======================================================================================================================
;;///// fs.inc ///////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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

FS_PARTITION_TYPE_FAT12   = 1
FS_PARTITION_TYPE_FAT16   = 2
FS_PARTITION_TYPE_FAT32   = 3
FS_PARTITION_TYPE_NTFS    = 4
FS_PARTITION_TYPE_EXT2    = 5
FS_PARTITION_TYPE_ISO9660 = 6

struct fs.partition_t
  device    dd ? ; ^= blkdev.device_t
  range     range64_t
  type      db ? ; #= one of FS_PARTITION_TYPE_*
  number    db ?
  user_data dd ? ; ^= fs.?.partition_data_t
ends

include "fs.asm"

match =1, KCONFIG_FS_FAT
{
include "fat/fat.inc"
}
