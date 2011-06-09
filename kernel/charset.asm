;;======================================================================================================================
;;///// charset.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2006-2010 KolibriOS team <http://kolibrios.org/>
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

;-----------------------------------------------------------------------------------------------------------------------
utf8toansi_str: ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert UTF-8 string to ASCII-string (codepage 866)
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = length source
;> esi = source
;> edi = buffer
;-----------------------------------------------------------------------------------------------------------------------
;# destroys: eax,esi,edi
;-----------------------------------------------------------------------------------------------------------------------
        jecxz   .ret

  .start:
        lodsw
        cmp     al, 0x80
        jb      .ascii

        xchg    al, ah ; big-endian
        cmp     ax, 0xd080
        jz      .yo1
        cmp     ax, 0xd191
        jz      .yo2
        cmp     ax, 0xd090
        jb      .unk
        cmp     ax, 0xd180
        jb      .rus1
        cmp     ax, 0xd190
        jb      .rus2

  .unk:
        mov     al, '_'
        jmp     .doit

  .yo1:
        mov     al, 0xf0 ; Ё capital
        jmp     .doit

  .yo2:
        mov     al, 0xf1 ; ё small
        jmp     .doit

  .rus1:
        sub     ax, 0xd090 - 0x80
        jmp     .doit

  .rus2:
        sub     ax, 0xd18f - 0xef

  .doit:
        stosb
        sub     ecx, 2
        ja      .start
        ret

  .ascii:
        stosb
        dec     esi
        dec     ecx
        jnz     .start

  .ret:
        ret

;-----------------------------------------------------------------------------------------------------------------------
uni2ansi_char: ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert UNICODE character to ANSI character, using cp866 encoding
;-----------------------------------------------------------------------------------------------------------------------
;> ax = UNICODE character
;-----------------------------------------------------------------------------------------------------------------------
;< al = converted ANSI character
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ax, 0x80
        jb      .ascii
        cmp     ax, 0x401
        jz      .yo1
        cmp     ax, 0x451
        jz      .yo2
        cmp     ax, 0x410
        jb      .unk
        cmp     ax, 0x440
        jb      .rus1
        cmp     ax, 0x450
        jb      .rus2

  .unk:
        mov     al, '_'
        jmp     .doit

  .yo1:
        mov     al, 240 ; 'Ё'
        jmp     .doit

  .yo2:
        mov     al, 241 ; 'ё'
        jmp     .doit

  .rus1:
        ; 0x410-0x43F -> 0x80-0xAF
        add     al, 0x70
        jmp     .doit

  .rus2:
        ; 0x440-0x44F -> 0xE0-0xEF
        add     al, 0xa0

  .ascii:
  .doit:
        ret

;-----------------------------------------------------------------------------------------------------------------------
char_todown: ;//////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert character to uppercase, using cp866 encoding
;-----------------------------------------------------------------------------------------------------------------------
;> al = symbol
;-----------------------------------------------------------------------------------------------------------------------
;< al = converted symbol
;-----------------------------------------------------------------------------------------------------------------------
        cmp     al, 'A'
        jb      .ret
        cmp     al, 'Z'
        jbe     .az
        cmp     al, 128 ; 'А'
        jb      .ret
        cmp     al, 144 ; 'Р'
        jb      .rus1
        cmp     al, 159 ; 'Я'
        ja      .ret
        ; 0x90-0x9F -> 0xE0-0xEF
        add     al, 224 - 144 ; 'р'-'Р'

  .ret:
        ret

  .rus1:
        ; 0x80-0x8F -> 0xA0-0xAF

  .az:
        add     al, 0x20
        ret

;-----------------------------------------------------------------------------------------------------------------------
unichar_toupper: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        call    uni2ansi_char
        cmp     al, '_'
        jz      .unk
        add     esp, 4
        call    char_toupper
        jmp     ansi2uni_char

  .unk:
        pop     eax
        ret

;-----------------------------------------------------------------------------------------------------------------------
uni2ansi_str: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert UNICODE zero-terminated string to ASCII-string (codepage 866)
;-----------------------------------------------------------------------------------------------------------------------
;> esi = source
;> edi = buffer (may be esi=edi)
;-----------------------------------------------------------------------------------------------------------------------
;# destroys: eax,esi,edi
;-----------------------------------------------------------------------------------------------------------------------
        lodsw
        test    ax, ax
        jz      .done
        cmp     ax, 0x80
        jb      .ascii
        cmp     ax, 0x401
        jz      .yo1
        cmp     ax, 0x451
        jz      .yo2
        cmp     ax, 0x410
        jb      .unk
        cmp     ax, 0x440
        jb      .rus1
        cmp     ax, 0x450
        jb      .rus2

  .unk:
        mov     al, '_'
        jmp     .doit

  .yo1:
        mov     al, 240 ; 'Ё'
        jmp     .doit

  .yo2:
        mov     al, 241 ; 'ё'
        jmp     .doit

  .rus1:
        ; 0x410-0x43F -> 0x80-0xAF
        add     al, 0x70
        jmp     .doit

  .rus2:
        ; 0x440-0x44F -> 0xE0-0xEF
        add     al, 0xa0

  .ascii:
  .doit:
        stosb
        jmp     uni2ansi_str

  .done:
        mov     byte[edi], 0
        ret

;-----------------------------------------------------------------------------------------------------------------------
ansi2uni_char: ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
; convert ANSI character to UNICODE character, using cp866 encoding
;-----------------------------------------------------------------------------------------------------------------------
;> al = ANSI char
;-----------------------------------------------------------------------------------------------------------------------
;< ax = UNICODE char
;-----------------------------------------------------------------------------------------------------------------------

        mov     ah, 0
        ; 0x00-0x7F - trivial map
        cmp     al, 0x80
        jb      .ret
        ; 0x80-0xAF -> 0x410-0x43F
        cmp     al, 0xb0
        jae     @f
        add     ax, 0x410 - 0x80

  .ret:
        ret

    @@: ; 0xE0-0xEF -> 0x440-0x44F
        cmp     al, 0xe0
        jb      .unk
        cmp     al, 0xf0
        jae     @f
        add     ax, 0x440 - 0xe0
        ret

    @@: ; 0xF0 -> 0x401
        ; 0xF1 -> 0x451
        cmp     al, 240 ; 'Ё'
        jz      .yo1
        cmp     al, 241 ; 'ё'
        jz      .yo2

  .unk:
        mov     al, '_'         ; ah=0
        ret

  .yo1:
        mov     ax, 0x401
        ret

  .yo2:
        mov     ax, 0x451
        ret

;-----------------------------------------------------------------------------------------------------------------------
char_toupper: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert character to uppercase, using cp866 encoding
;----------------------------------------------------------------------------------------------------------------------
;> al = symbol
;-----------------------------------------------------------------------------------------------------------------------
;< al = converted symbol
;-----------------------------------------------------------------------------------------------------------------------

        cmp     al, 'a'
        jb      .ret
        cmp     al, 'z'
        jbe     .az
        cmp     al, 241 ; 'ё'
        jz      .yo1
        cmp     al, 160 ; 'а'
        jb      .ret
        cmp     al, 224 ; 'р'
        jb      .rus1
        cmp     al, 239 ; 'я'
        ja      .ret
        ; 0xE0-0xEF -> 0x90-0x9F
        sub     al, 224 - 144 ; 'р'-'Р'

  .ret:
        ret

  .rus1:
        ; 0xA0-0xAF -> 0x80-0x8F

  .az:
        and     al, not 0x20
        ret

  .yo1:
        ; 0xF1 -> 0xF0
        dec     ax
        ret