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

;
;   WINDOW SKIN DATA
;

iglobal
  _skin_file_default db '/sys/DEFAULT.SKN', 0
endg

struct SKIN_DATA
  colors.inner dd ?
  colors.outer dd ?
  colors.frame dd ?
  left.data    dd ?
  left.left    dd ?
  left.width   dd ?
  oper.data    dd ?
  oper.left    dd ?
  oper.width   dd ?
  base.data    dd ?
  base.left    dd ?
  base.width   dd ?
ends

struct SKIN_BUTTON
  left   dd ?
  top    dd ?
  width  dd ?
  height dd ?
ends

uglobal
  align 4
  skin_udata:
    _skinh    dd ?
    _skinmargins: ;   rw 4
      .right  dw ?
      .left   dw ?
      .bottom dw ?
      .top    dw ?

  skin_btn_close    SKIN_BUTTON
  skin_btn_minimize SKIN_BUTTON

  skin_active       SKIN_DATA
  skin_inactive     SKIN_DATA

  align 4
  skin_udata.end:
endg
