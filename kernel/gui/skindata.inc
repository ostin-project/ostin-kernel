;;======================================================================================================================
;;///// skindata.inc /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2007 KolibriOS team <http://kolibrios.org/>
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
;? Window skin data
;;======================================================================================================================

iglobal
  _skin_file_default db '/sys/DEFAULT.SKN', 0
endg

struct skin_data_colors_t
  inner dd ?
  outer dd ?
  frame dd ?
ends

struct skin_data_bitmap_t
  data  dd ?
  left  dd ?
  width dd ?
ends

struct skin_data_t
  colors skin_data_colors_t
  left   skin_data_bitmap_t
  oper   skin_data_bitmap_t
  base   skin_data_bitmap_t
ends

struct skin_button_t box32_t
ends

struct skin_margins_t
  right  dw ?
  left   dw ?
  bottom dw ?
  top    dw ?
ends

uglobal
  align 4
  skin_udata:
    _skinh          dd ?
    _skinmargins    skin_margins_t

  skin_btn_close    skin_button_t
  skin_btn_minimize skin_button_t

  skin_active       skin_data_t
  skin_inactive     skin_data_t

  align 4
  skin_udata.end:
endg
