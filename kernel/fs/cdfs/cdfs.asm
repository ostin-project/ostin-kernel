;;======================================================================================================================
;;///// cdfs.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

struct fs.cdfs.partition_data_t
  buffer rb 4096
ends

iglobal
  jump_table fs.cdfs, vftbl, 0, \
    read_file, \
    read_directory, \
    -, \
    -, \
    -, \
    get_file_info, \
    -, \
    -, \
    -, \
    -
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs.read_file ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file
;> edx ^= fs.read_file_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= bytes read (on success)
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_NOT_IMPLEMENTED
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs.read_directory ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to directory
;> edx ^= fs.read_directory_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;< ebx #= directory entries read (on success)
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_NOT_IMPLEMENTED
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.cdfs.get_file_info ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= path to file or directory
;> edx ^= fs.get_file_info_query_params_t
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_NOT_IMPLEMENTED
        ret
kendp
