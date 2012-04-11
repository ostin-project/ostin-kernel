;;======================================================================================================================
;;///// bpb.inc //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
;; * "Frequently Given Answers written by JdeBP" / "Volumes and filesystem formats"
;;   http://homepage.ntlworld.com/jonathan.deboynepollard/FGA/
;;======================================================================================================================

struct bpb_v2_0_t
                           rb 11
  sector_size              dw ?
  cluster_size             db ? ; in sectors
  resvd_sector_count       dw ?
  fat_count                db ?
  fat_root_dir_entry_count dw ?
  volume_size_16           dw ? ; in sectors
  media_descr              db ?
  fat_size_16              dw ? ; in sectors
ends

struct bpb_v3_0_t bpb_v2_0_t
  track_size          dw ? ; in sectors
  head_count          dw ?
  hidden_sector_count dw ?
ends

struct bpb_v3_2_t bpb_v3_0_t
  partition_size dw ? ; in sectors
ends

struct bpb_v3_4_t bpb_v2_0_t
  track_size          dw ? ; in sectors
  head_count          dw ?
  hidden_sector_count dd ?
  volume_size_32      dd ? ; in sectors
ends

struct bpb_v4_0_t bpb_v3_4_t
  disk_unit_number     db ?
  chkdsk_flags         db ?
  signature            db ? ; #= 0x28 or 0x29
  volume_serial_number dd ?
  volume_label         rb 11
  fs_type              rb 8
                       rb 8
ends

struct bpb_v7_0_t bpb_v3_4_t
  fat_size_32              dd ? ; in sectors
  fat_flags                dw ?
  fs_version               dw ?
  root_dir_cluster         dd ?
  superblock_sector        dw ?
  boot_block_backup_sector dw ?
                           rb 12
  disk_unit_number         db ?
  chkdsk_flags             db ?
  signature                db ? ; #= 0x28 or 0x29
  volume_serial_number     dd ?
  volume_label             rb 11
  fs_type                  rb 8
ends

struct bpb_v8_0_t bpb_v3_4_t
  disk_unit_number         db ?
  chkdsk_flags             db ?
  signature                db ? ; #= 0x80
                           db ?
  volume_size_64           dq ?
  mft_first_cluster        dq ?
  mft_mirror_first_cluster dq ?
  mft_record_size          dd ?
  index_block_size         dd ?
  volume_serial_number     dq ?
  checksum                 dd ?
ends
