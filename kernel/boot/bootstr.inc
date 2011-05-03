;;======================================================================================================================
;;///// bootstr.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

; boot data: common strings (for all languages)
macro line_full_top {
          db       '╔'
          times    78 db '═'
          db       '╗'
}
macro line_full_bottom {
          db       '╚'
          times    78 db '═'
          db       '╝'
}
macro line_half {
          db      '║ '
          times    76   db '─'
          db      ' ║'
}
macro line_space {
          db      '║'
          times   78 db ' '
          db      '║'
}
d80x25_top:
		line_full_top

space_msg:	line_space
verstr:
;		line_space
; version string
	db '║ '
	repeat 78
		load a byte from version+%-1
		if a = 13
			break
		end if
		db a
	end repeat
	repeat 78 - ($-verstr)
		db	' '
	end repeat
	db ' ║'
		line_half
d80x25_top_num = 4
