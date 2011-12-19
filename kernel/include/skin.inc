;;======================================================================================================================
;;///// skin.inc /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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

struct skin_header_t
  ident   dd ?
  version dd ?
  params  dd ?
  buttons dd ?
  bitmaps dd ?
ends

struct skin_data_colors_t
  inner dd ?
  outer dd ?
  frame dd ?
ends

struct skin_margins_t
  right  dw ?
  left   dw ?
  bottom dw ?
  top    dw ?
ends

struct skin_params_t
  skin_height dd ?
  margin      skin_margins_t
  colors      skin_data_colors_t
  colors_1    skin_data_colors_t
  dtp.size    dd ?
  dtp.data    db 40 dup (?)
ends

struct skin_buttons_t
  type dd ?
  box  box16_t
ends

struct skin_bitmaps_t
  kind dw ?
  type dw ?
  data dd ?
ends
