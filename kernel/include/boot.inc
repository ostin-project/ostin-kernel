;;======================================================================================================================
;;///// boot.inc /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2008 KolibriOS team <http://kolibrios.org/>
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

struct vbe_vga_info_t
  vesa_signature       dd ?   ; char
  vesa_version         dw ?   ; short
  oem_string_ptr       dd ?   ; char *
  capabilities         dd ?   ; ulong
  video_mode_ptr       dd ?   ; ulong
  total_memory         dw ?   ; short
  ; VBE 2.0+
  oem_software_rev     db ?   ; short
  oem_vendor_name_ptr  dw ?   ; char *
  oem_product_name_ptr dw ?   ; char *
  oem_product_rev_ptr  dw ?   ; char *
                       rb 222 ; char
  oem_data             rb 256 ; char
ends

struct vbe_mode_info_t
  mode_attributes            dw ?   ; short
  win_a_attributes           db ?   ; char
  win_b_attributes           db ?   ; char
  win_granularity            dw ?   ; short
  win_size                   dw ?   ; short
  win_a_segment              dw ?   ; ushort
  win_b_segment              dw ?   ; ushort
  win_func_ptr               dd ?   ; void *
  bytes_per_scanline         dw ?   ; short
  x_res                      dw ?   ; short
  y_res                      dw ?   ; short
  x_char_size                db ?   ; char
  y_char_size                db ?   ; char
  number_of_planes           db ?   ; char
  bits_per_pixel             db ?   ; char
  number_of_banks            db ?   ; char
  memory_model               db ?   ; char
  bank_size                  db ?   ; char
  number_of_image_pages      db ?   ; char
                             db ?   ; char
  red_mask_size              db ?   ; char
  red_field_position         db ?   ; char
  green_mask_size            db ?   ; char
  green_field_position       db ?   ; char
  blue_mask_size             db ?   ; char
  blue_field_position        db ?   ; char
  rsved_mask_size            db ?   ; char
  rsved_field_position       db ?   ; char
  direct_color_mode_info     db ?   ; char
  ; VBE 2.0+
  phys_base_ptr              dd ?   ; ulong
  offscreen_mem_offset       dd ?   ; ulong
  offscreen_mem_size         dw ?   ; short
  ; VBE 3.0+
  lin_bytes_per_scanline     dw ?   ; short
  bank_number_of_image_pages db ?   ; char
  lin_number_of_image_pages  db ?   ; char
  lin_red_mask_size          db ?   ; char
  lin_red_field_position     db ?   ; char
  lin_green_mask_size        db ?   ; char
  lin_green_field_position   db ?   ; char
  lin_blue_mask_size         db ?   ; char
  lin_blue_field_position    db ?   ; char
  lin_rsvd_mask_size         db ?   ; char
  lin_rsvd_field_position    db ?   ; char
  max_pixel_clock            dd ?   ; ulong
                             rb 190 ; char
ends

struct boot_vmode_t
  resolution     size16_t
  attributes     dw ?
  number         dw ?
  bits_per_pixel dw ?
ends

static_assert_ sizeof.boot_vmode_t mod 2 = 0

struct phoenix_smap_addr_range_t range64_t
  type   dd ?
ends

PHOENIX_SMAP_TYPE_AVAILABLE    = 0x01
PHOENIX_SMAP_TYPE_RESERVED     = 0x02
PHOENIX_SMAP_TYPE_ACPI_RECLAIM = 0x03
PHOENIX_SMAP_TYPE_ACPI_NVS     = 0x04
