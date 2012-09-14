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

struct fs.vftbl_t
  read_file        dd ?
  read_directory   dd ?
  create_file      dd ?
  write_file       dd ?
  truncate_file    dd ?
  get_file_info    dd ?
  set_file_info    dd ?
                   dd ?
  delete_file      dd ?
  create_directory dd ?
ends

struct fs.partition_t linked_list_t
  _.vftbl     dd ? ; ^= fs.vftbl_t
  _.mutex     mutex_t
  _.device    dd ? ; ^= blk.device_t
  _.range     range64_t
  _.number    db ?
ends

include "fs.asm"
include "fs_lfn.asm"

match =1, KCONFIG_FS_FAT
{
include "fat/fat.inc"
}
match =1, KCONFIG_FS_CDFS
{
include "cdfs/cdfs.inc"
}
match =1, KCONFIG_FS_EXT2
{
include "ext2.asm"
}
match =1, KCONFIG_FS_NTFS
{
include "ntfs.asm"
}
