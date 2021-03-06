;;======================================================================================================================
;;///// fs.inc ///////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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

ERROR_SUCCESS         = 0
ERROR_DISK_BASE       = 1
ERROR_NOT_IMPLEMENTED = 2
ERROR_UNKNOWN_FS      = 3
;ERROR_PARTITION      = 4
ERROR_FILE_NOT_FOUND  = 5
ERROR_END_OF_FILE     = 6
ERROR_MEMORY_POINTER  = 7
ERROR_DISK_FULL       = 8
ERROR_FAT_TABLE       = 9
ERROR_ACCESS_DENIED   = 10
ERROR_DEVICE_FAIL     = 11
ERROR_ALLOC           = 12

FS_FUNC_READ_FILE     = 0
FS_FUNC_READ_DIR      = 1
FS_FUNC_CREATE_FILE   = 2
FS_FUNC_WRITE_FILE    = 3
FS_FUNC_TRUNCATE_FILE = 4
FS_FUNC_GET_INFO      = 5
FS_FUNC_SET_INFO      = 6
FS_FUNC_EXECUTE       = 7
FS_FUNC_DELETE_FILE   = 8
FS_FUNC_CREATE_DIR    = 9

FS_INFO_ATTR_READONLY = 00000001b
FS_INFO_ATTR_HIDDEN   = 00000010b
FS_INFO_ATTR_SYSTEM   = 00000100b
FS_INFO_ATTR_LABEL    = 00001000b
FS_INFO_ATTR_DIR      = 00010000b
FS_INFO_ATTR_ARCHIVED = 00100000b
FS_INFO_ATTR_ANY      = 00111111b

FS_INFO_FLAG_UNICODE = 1

struct fs.generic_query_params_t
  param1 dd ?
  param2 dd ?
  param3 dd ?
  param4 dd ?
ends

struct fs.read_file_query_params_t
  range      range64x32_t
  buffer_ptr dd ?
ends

struct fs.read_directory_query_params_t
  start_block dd ?
  flags       dd ?
  count       dd ?
  buffer_ptr  dd ?
ends

struct fs.create_file_query_params_t
             dd ?
             dd ?
  length     dd ?
  buffer_ptr dd ?
ends

struct fs.write_file_query_params_t
  range      range64x32_t
  buffer_ptr dd ?
ends

struct fs.truncate_file_query_params_t
  new_size dq ?
           dd ?
           dd ?
ends

struct fs.get_file_info_query_params_t
             dd ?
             dd ?
             dd ?
  buffer_ptr dd ?
ends

struct fs.set_file_info_query_params_t
             dd ?
             dd ?
             dd ?
  buffer_ptr dd ?
ends

struct fs.start_program_query_params_t
  flags         dd ?
  arguments_ptr dd ?
                dd ?
                dd ?
ends

struct fs.query_t
  function         dd ? ; one of FS_FUNC_*
  union
    generic        fs.generic_query_params_t
    read_file      fs.read_file_query_params_t
    read_directory fs.read_directory_query_params_t
    create_file    fs.create_file_query_params_t
    write_file     fs.write_file_query_params_t
    truncate_file  fs.truncate_file_query_params_t
    get_file_info  fs.get_file_info_query_params_t
    set_file_info  fs.set_file_info_query_params_t
    start_program  fs.start_program_query_params_t
  ends
  union
    path           rb 0
    struct
                   db ?
      path_ptr     dd ?
    ends
  ends
ends

struct fs.file_date_time_t
  union
    time    dd ?
    struct
      sec   db ?
      min   db ?
      hour  db ?
    ends
  ends
  union
    date    dd ?
    struct
      day   db ?
      month db ?
      year  dw ?
    ends
  ends
ends

struct fs.file_info_header_t
  version     dd ?
  files_read  dd ?
  files_count dd ?
              rd 5
ends

struct fs.file_info_t
  attributes    dd ? ; combination of FS_INFO_ATTR_*
  flags         dd ? ; combination of FS_INFO_FLAG_*
  created_at    fs.file_date_time_t
  accessed_at   fs.file_date_time_t
  modified_at   fs.file_date_time_t
  union
    size        dq ?
    struct
      size.low  dd ?
      size.high dd ?
    ends
  ends
  name          rb 0
ends
