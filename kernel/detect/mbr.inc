;;======================================================================================================================
;;///// mbr.inc //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2012 Ostin project <http://ostin.googlecode.com/>
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

MBR_SIGNATURE = 0xaa55

MBR_PART_STATUS_BOOTABLE = 0x80

MBR_PART_TYPE_EMPTY          = 0x00
MBR_PART_TYPE_FAT12          = 0x01
MBR_PART_TYPE_FAT16_1        = 0x04 ; up to 32 MiB
MBR_PART_TYPE_EXTENDED       = 0x05
MBR_PART_TYPE_FAT16_2        = 0x06 ; over 32 MiB
MBR_PART_TYPE_NTFS           = 0x07
MBR_PART_TYPE_EXFAT          = 0x07
MBR_PART_TYPE_FAT32          = 0x0b
MBR_PART_TYPE_FAT32_LBA      = 0x0c
MBR_PART_TYPE_FAT16_LBA      = 0x0e
MBR_PART_TYPE_EXTENDED_LBA   = 0x0f
MBR_PART_TYPE_WIN2K_LDM      = 0x42
MBR_PART_TYPE_LINUX_NATIVE   = 0x83
MBR_PART_TYPE_LINUX_EXTENDED = 0x85
MBR_PART_TYPE_LINUX_LVM      = 0x8e

struct mbr_part_entry_t
  status    db ? ; one of MBR_PART_STATUS_*
  start_chs rb 3 ; pack[10(cylinder), 6(sector), 8(head)]
  type      db ? ; one of MBR_PART_TYPE_*
  end_chs   rb 3 ; pack[10(cylinder), 6(sector), 8(head)]
  start_lba dd ?
  size_lba  dd ?
ends

struct mbr_part_entries_t
  0 mbr_part_entry_t
  1 mbr_part_entry_t
  2 mbr_part_entry_t
  3 mbr_part_entry_t
ends

struct mbr_t
  code           rb 440
  disk_signature dd ?
                 rb 2
  partitions     mbr_part_entries_t
  mbr_signature  dw ? ; #= MBR_SIGNATURE
ends

assert sizeof.mbr_t = 512
