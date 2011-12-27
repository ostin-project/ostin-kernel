;;======================================================================================================================
;;///// blkdev.inc ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

BLK_MAX_DEVICE_NAME_LEN = 32

struct blk.device_vftbl_t
  destroy dd ?
  read    dd ?
  write   dd ?
ends

struct blk.device_t
  vftbl     dd ? ; ^= blk.device_vftbl_t
  name      rb BLK_MAX_DEVICE_NAME_LEN
  user_data dd ? ; ^= blk.?.device_data_t
ends

include "blkdev.asm"

match =1, KCONFIG_BLK_ATA
{
include "ata.asm"
}

match =1, KCONFIG_BLK_ATAPI
{
include "atapi.asm"
}

match =1, KCONFIG_BLK_FLOPPY
{
include "floppy.asm"
}

match =1, KCONFIG_BLK_MEMORY
{
include "memory.asm"
}

include "cd_drv.asm"
include "cdrom.asm"
include "hd_drv.asm"
include "ide_cache.asm"
