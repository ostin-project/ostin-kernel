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

BLKDEV_MAX_NAME_LEN = 32

struct blkdev.vftbl_t
  destroy dd ?
  read    dd ?
  write   dd ?
ends

struct blkdev.device_t
  vftbl     dd ? ; ^= blkdev.vftbl_t
  name      rb BLKDEV_MAX_NAME_LEN
  user_data dd ? ; ^= blkdev.?.device_data_t
ends

match =1, KCONFIG_BLKDEV_FLOPPY
{
include "floppy.asm"
}
match =1, KCONFIG_BLKDEV_MEMORY
{
include "memory.asm"
}
