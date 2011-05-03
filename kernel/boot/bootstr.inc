;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                              ;;
;; Copyright (C) KolibriOS team 2004-2007. All rights reserved. ;;
;; Distributed under terms of the GNU General Public License    ;;
;;                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
