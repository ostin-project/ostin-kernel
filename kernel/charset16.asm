;;======================================================================================================================
;;///// charset16.asm ////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

align 4

if used charset.utf8_d0_cp866_map

charset.utf8_d0_cp866_map:
  db 0x00, 0xf0, 0x00, 0x00, 0xf2, 0x00, 0x00, 0xf4, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf6, 0x00 ; ЀЁЂЃЄЅІЇЈЉЊЋЌЍЎЏ
  db 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f ; АБВГДЕЖЗИЙКЛМНОП
  db 0x90, 0x01, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f ; РСТУФХЦЧШЩЪЫЬЭЮЯ
  db 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf ; абвгдежзийклмноп

end if

if used charset.utf8_d1_cp866_map

charset.utf8_d1_cp866_map:
  db 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xeb, 0xec, 0xed, 0xee, 0xef ; рстуфхцчшщъыьэюя
  db 0x00, 0xf1, 0x00, 0x00, 0xf3, 0x00, 0x00, 0xf5, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf7, 0x00 ; ѐёђѓєѕіїјљњћќѝўџ

end if

;-----------------------------------------------------------------------------------------------------------------------
kproc charset16.utf8_char_to_ansi ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Convert UTF-8 char to ANSI char
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si = pointer to UTF-8 char
;-----------------------------------------------------------------------------------------------------------------------
;< al = 255 (error) or ANSI char code
;< ds:si = pointer to next UTF-8 char
;-----------------------------------------------------------------------------------------------------------------------
        lodsb

        test    al, 0x80
        jz      .noop_exit

        push    bx

if KCONFIG_LANGUAGE eq ru

  .prefix_d0:
        cmp     al, 0xd0
        jne     .prefix_d1
        lodsb
        mov     bx, charset.utf8_d0_cp866_map
        add     al, 0x80
        jmp     .exit

  .prefix_d1:
        cmp     al, 0xd1
        jne     .error
        lodsb
        cmp     al, 0xc0
        jae     .error
        mov     bx, charset.utf8_d1_cp866_map
        add     al, 0x80
        jmp     .exit

end if

  .error:
        lodsb
        and     al, 0xc0
        cmp     al, 0x80
        je      .error
        dec     si
        or      al, -1
        jmp     .error_exit

  .exit:
        add     bl, al
        adc     bh, 0
        mov     al, [bx]

  .error_exit:
        pop     bx

  .noop_exit:
        ret
kendp
