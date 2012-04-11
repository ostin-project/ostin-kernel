;;======================================================================================================================
;;///// gpt.inc //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

GPT_PART_FLAG_SYSTEM         = 1 shl 0
GPT_PART_FLAG_BOOTABLE       = 1 shl 2
GLT_PART_FLAG_READ_ONLY      = 1 shl 60
GLT_PART_FLAG_HIDDEN         = 1 shl 62
GLT_PART_FLAG_DONT_AUTOMOUNT = 1 shl 63

GPT_PART_TYPE_GUID_WINDOWS_BDP          equ 'ebd0a0a2-b9e5-4433-87c0-68b6b72699c7' ; basic data partition
GPT_PART_TYPE_GUID_WINDOWS_LDM_METADATA equ '5808c8aa-7e8f-42e0-85d2-e1e90434cfb3'
GPT_PART_TYPE_GUID_WINDOWS_LDM_DATA     equ 'af9b60a0-1431-4f62-bc68-3311714a69ad'
GPT_PART_TYPE_GUID_LINUX_FS_DATA        equ '0fc63daf-8483-4772-8e79-3d69d8477de4'
GPT_PART_TYPE_GUID_LINUX_LVM            equ 'e6d6d379-f507-44c2-a23c-238f2a3df928'

struct uuid_t
  data1 dd ?
  data2 dw ?
  data3 dw ?
  data4 dq ?
ends

struct gpt_part_entry_t
  type_guid uuid_t
  part_guid uuid_t
  start_lba dq ?
  end_lba   dq ?
  flags     dq ? ; combination of GPT_PART_FLAG_*
  name      rw 36
ends

struct gpt_header_t
  signature       rb 8 ; "EFI PART"
  revision        dd ? ; 00 00 01 00
  header_size     dd ? ; #= sizeof.gpt_header_t
  header_crc32    dd ?
                  rb 4
  current_lba     dq ?
  backup_lba      dq ?
  start_lba       dq ?
  end_lba         dq ?
  disk_guid       uuid_t
  parts_lba       dq ? ; ^= array of gpt_part_entry_t
  parts_count     dd ?
  part_entry_size dd ? ; #= sizeof.gpt_part_entry_t
  parts_crc32     dd ?
ends
