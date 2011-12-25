;;======================================================================================================================
;;///// iso9660.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

FS_ISO9660_VOL_TYPE_BOOT_RECORD    = 0
FS_ISO9660_VOL_TYPE_PRI_VOL_DESCR  = 1
FS_ISO9660_VOL_TYPE_SUP_VOL_DESCR  = 2
FS_ISO9660_VOL_TYPE_VOL_PART_DESCR = 3
FS_ISO9660_VOL_TYPE_SET_TERM       = 255

FS_ISO9660_ATTR_EXISTENCE = 00000001b
FS_ISO9660_ATTR_DIRECTORY = 00000010b
FS_ISO9660_ATTR_ASSOC     = 00000100b
FS_ISO9660_ATTR_RECORD    = 00001000b
FS_ISO9660_ATTR_PROTECT   = 00010000b
FS_ISO9660_ATTR_MULTIEXT  = 10000000b

FS_ISO9660_PERM_SYS_OWNER_READ = 0000000000000001b
FS_ISO9660_PERM_SYS_OWNER_EXEC = 0000000000000100b
FS_ISO9660_PERM_OWNER_READ     = 0000000000010000b
FS_ISO9660_PERM_OWNER_EXEC     = 0000000001000000b
FS_ISO9660_PERM_GRP_OWNER_READ = 0000000100000000b
FS_ISO9660_PERM_GRP_OWNER_EXEC = 0000010000000000b
FS_ISO9660_PERM_GROUP_READ     = 0001000000000000b
FS_ISO9660_PERM_GROUP_EXEC     = 0100000000000000b

struct fs.iso9660.long_date_time_t
  year   dd ?
  month  dw ?
  day    dw ?
  hour   dw ?
  minute dw ?
  second dw ?
  hsec   dw ?
  tz     db ?
ends

struct fs.iso9660.short_date_time_t
  year   db ?
  month  db ?
  day    db ?
  hour   db ?
  minute db ?
  second db ?
  tz     db ?
ends

struct fs.iso9660.vol_descr_t
  descr_type    db ? ; one of FS_ISO9660_VOL_TYPE_*
  std_ident     rb 5
  descr_version db ?
ends

struct fs.iso9660.boot_record_t fs.iso9660.vol_descr_t
  boot_system_ident rb 32
  boot_ident        rb 32
ends

struct fs.iso9660.vol_descr_set_term_t fs.iso9660.vol_descr_t
ends

struct fs.iso9660.pri_vol_descr_t fs.iso9660.vol_descr_t
                         db ?
  system_ident           rb 32
  ident                  rb 32
                         rb 8
  size                   dq ?
                         rb 32
  set_size               dd ?
  seq_number             dd ?
  logical_block_size     dd ?
  path_tbl_size          dq ?
  lsb_path_table_loc     dd ?
  lsb_path_table_opt_loc dd ?
  msb_path_table_loc     dd ?
  msb_path_table_opt_loc dd ?
  root_dir_entry         rb 34
  set_ident              rb 128
  publisher_ident        rb 128
  data_preparer_ident    rb 128
  application_ident      rb 128
  copyright_file_ident   rb 37
  abstract_file_ident    rb 37
  biblio_file_ident      rb 37
  created_at             fs.iso9660.long_date_time_t
  modified_at            fs.iso9660.long_date_time_t
  expires_at             fs.iso9660.long_date_time_t
  effective_at           fs.iso9660.long_date_time_t
  file_struct_version    db ?
                         db ?
  app_use                rb 512
                         rb 653
ends

struct fs.iso9660.sup_vol_descr_t fs.iso9660.vol_descr_t
  flags                  db ?
  system_ident           rb 32
  ident                  rb 32
                         rb 8
  size                   dq ?
  escape_sequences       rb 32
  set_size               dd ?
  seq_number             dd ?
  logical_block_size     dd ?
  path_tbl_size          dq ?
  lsb_path_table_loc     dd ?
  lsb_path_table_opt_loc dd ?
  msb_path_table_loc     dd ?
  msb_path_table_opt_loc dd ?
  root_dir_entry         rb 34
  set_ident              rb 128
  publisher_ident        rb 128
  data_preparer_ident    rb 128
  application_ident      rb 128
  copyright_file_ident   rb 37
  abstract_file_ident    rb 37
  biblio_file_ident      rb 37
  created_at             fs.iso9660.long_date_time_t
  modified_at            fs.iso9660.long_date_time_t
  expires_at             fs.iso9660.long_date_time_t
  effective_at           fs.iso9660.long_date_time_t
  file_struct_version    db ?
                         db ?
  app_use                rb 512
                         rb 653
ends

struct fs.iso9660.vol_part_descr_t fs.iso9660.vol_descr_t
               db ?
  system_ident rb 32
  ident        rb 32
  loc          dq ?
  size         dq ?
  sys_use      rb 1960
ends

struct fs.iso9660.dir_entry_t
  entry_size          db ?
  ext_attr_entry_size db ?
  extent_loc          dq ?
  size                dq ?
  recorded_at         fs.iso9660.short_date_time_t
  attributes          db ? ; combination of FS_ISO9660_ATTR_*
  unit_size           db ?
  il_gap_size         db ?
  vol_seq_number      dd ?
  name_size           db ?
  name                rb 0
ends

struct fs.iso9660.path_tbl_entry_t
  name_size           db ?
  ext_attr_entry_size db ?
  extent_loc          dd ?
  parent_dir_number   dw ?
  name                rb 0
ends

struct fs.iso9660.ext_attr_entry_t
  owner_id        dd ?
  group_id        dd ?
  permissions     dw ? ; combination of FS_ISO9660_PERM_*
  created_at      fs.iso9660.long_date_time_t
  modified_at     fs.iso9660.long_date_time_t
  expires_at      fs.iso9660.long_date_time_t
  effective_at    fs.iso9660.long_date_time_t
  format          db ?
  attributes      db ?
  size            dd ?
  system_ident    rb 32
                  rb 64
  version         db ?
  escape_seq_size db ?
                  rb 64
  app_use_size    dd ?
  app_use         rb 0
ends
