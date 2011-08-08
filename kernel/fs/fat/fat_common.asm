;;======================================================================================================================
;;///// fat_common.asm ///////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
;; (c) 2004 MenuetOS <http://menuetos.net/>
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

;;======================================================================================================================
;;///// public functions ///////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.get_name ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= FAT entry
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 1
;<   no valid entry
;< CF = 0
;<   ebp = ASCIIZ-name
;-----------------------------------------------------------------------------------------------------------------------
;# maximum length of filename is 255 (wide) symbols without trailing 0, but implementation requires buffer 261 words
;# destroys eax
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[edi], 0
        jz      .no
        cmp     byte[edi], 0xe5
        jnz     @f

  .no:
        stc
        ret

    @@: cmp     byte[edi + 11], 0x0f
        jz      .longname
        test    byte[edi + 11], 8
        jnz     .no
        push    ecx
        push    edi ebp
        test    byte[ebp - 4], 1
        jnz     .unicode_short

        mov     eax, [edi]
        mov     ecx, [edi + 4]
        mov     [ebp], eax
        mov     [ebp + 4], ecx

        mov     ecx, 8

    @@: cmp     byte[ebp + ecx - 1], ' '
        loope   @b

        mov     eax, [edi + 8]
        cmp     al, ' '
        je      .done
        shl     eax, 8
        mov     al, '.'

        lea     ebp, [ebp + ecx + 1]
        mov     [ebp], eax
        mov     ecx, 3

    @@: rol     eax, 8
        cmp     al, ' '
        jne     .done
        loop    @b
        dec     ebp

  .done:
        and     byte[ebp + ecx + 1], 0 ; CF=0
        pop     ebp edi ecx
        ret

  .unicode_short:
        mov     ecx, 8
        push    ecx

    @@: mov     al, [edi]
        inc     edi
        call    ansi2uni_char
        mov     [ebp], ax
        inc     ebp
        inc     ebp
        loop    @b
        pop     ecx

    @@: cmp     word[ebp - 2], ' '
        jnz     @f
        dec     ebp
        dec     ebp
        loop    @b

    @@: mov     word[ebp], '.'
        inc     ebp
        inc     ebp
        mov     ecx, 3
        push    ecx

    @@: mov     al, [edi]
        inc     edi
        call    ansi2uni_char
        mov     [ebp], ax
        inc     ebp
        inc     ebp
        loop    @b
        pop     ecx

    @@: cmp     word[ebp - 2], ' '
        jnz     @f
        dec     ebp
        dec     ebp
        loop    @b
        dec     ebp
        dec     ebp

    @@: and     word[ebp], 0 ; CF=0
        pop     ebp edi ecx
        ret

  .longname:
        ; LFN
        mov     al, [edi]
        and     eax, 0x3f
        dec     eax
        cmp     al, 20
        jae     .no ; ignore invalid entries
        mov     word[ebp + 260 * 2], 0 ; force null-terminating for orphans
        imul    eax, 13 * 2
        add     ebp, eax
        test    byte[edi], 0x40
        jz      @f
        mov     word[ebp + 13 * 2], 0

    @@: push    eax
        ; now copy name from edi to ebp ...
        mov     eax, [edi + 1]
        mov     [ebp], eax ; symbols 1,2
        mov     eax, [edi + 5]
        mov     [ebp + 4], eax ; 3,4
        mov     eax, [edi + 9]
        mov     [ebp + 8], ax ; 5
        mov     eax, [edi + 14]
        mov     [ebp + 10], eax ; 6,7
        mov     eax, [edi + 18]
        mov     [ebp + 14], eax ; 8,9
        mov     eax, [edi + 22]
        mov     [ebp + 18], eax ; 10,11
        mov     eax, [edi + 28]
        mov     [ebp + 22], eax ; 12,13
        ; ... done
        pop     eax
        sub     ebp, eax
        test    eax, eax
        jz      @f
        ; if this is not first entry, more processing required
        stc
        ret

    @@: ; if this is first entry:
        test    byte[ebp - 4], 1
        jnz     .ret
        ; buffer at ebp contains UNICODE name, convert it to ANSI
        push    esi edi
        mov     esi, ebp
        mov     edi, ebp
        call    uni2ansi_str
        pop     edi esi

  .ret:
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat_entry_to_bdfe ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert FAT entry to BDFE (block of data of folder entry), advancing esi
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= FAT entry
;> esi ^= BDFE
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [ebp - 4]
        mov     [esi + 4], eax  ; ASCII/UNICODE name

  .direct:
        movzx   eax, byte[edi + 11]
        mov     [esi], eax ; attributes
        movzx   eax, word[edi + 14]
        call    fs.fat._.fat_time_to_bdfe_time
        mov     [esi + 8], eax ; creation time
        movzx   eax, word[edi + 16]
        call    fs.fat._.fat_date_to_bdfe_date
        mov     [esi + 12], eax ; creation date
        and     dword[esi + 16], 0 ; last access time is not supported on FAT
        movzx   eax, word[edi + 18]
        call    fs.fat._.fat_date_to_bdfe_date
        mov     [esi + 20], eax ; last access date
        movzx   eax, word[edi + 22]
        call    fs.fat._.fat_time_to_bdfe_time
        mov     [esi + 24], eax ; last write time
        movzx   eax, word[edi + 24]
        call    fs.fat._.fat_date_to_bdfe_date
        mov     [esi + 28], eax ; last write date
        mov     eax, [edi + 28]
        mov     [esi + 32], eax ; file size (low dword)
        xor     eax, eax
        mov     [esi + 36], eax ; file size (high dword)
        test    ebp, ebp
        jz      .ret
        push    ecx edi
        lea     edi, [esi + 40]
        mov     esi, ebp
        test    byte[esi - 4], 1
        jz      .ansi
        mov     ecx, 260 / 2
        rep     movsd
        mov     [edi - 2], ax

    @@: mov     esi, edi
        pop     edi ecx

  .ret:
        ret

  .ansi:
        mov     ecx, 264 / 4
        rep     movsd
        mov     [edi - 1], al
        jmp     @b
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.bdfe_to_fat_entry ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert BDFE to FAT entry
;-----------------------------------------------------------------------------------------------------------------------
;> edx ^= BDFE
;> edi ^= FAT entry
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;# attributes byte
;-----------------------------------------------------------------------------------------------------------------------
        test    byte[edi + 11], 8 ; volume label?
        jnz     @f
        mov     al, [edx]
        and     al, 0x27
        and     byte[edi + 11], 0x10
        or      byte[edi + 11], al

    @@: mov     eax, [edx + 8]
        call    fs.fat._.bdfe_time_to_fat_time
        mov     [edi + 14], ax ; creation time
        mov     eax, [edx + 12]
        call    fs.fat._.bdfe_date_to_fat_date
        mov     [edi + 16], ax ; creation date
        mov     eax, [edx + 20]
        call    fs.fat._.bdfe_date_to_fat_date
        mov     [edi + 18], ax ; last access date
        mov     eax, [edx + 24]
        call    fs.fat._.bdfe_time_to_fat_time
        mov     [edi + 22], ax ; last write time
        mov     eax, [edx + 28]
        call    fs.fat._.bdfe_date_to_fat_date
        mov     [edi + 24], ax ; last write date
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.name_is_legal ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= [long] name
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 0 (legal) or 1 (illegal)
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;-----------------------------------------------------------------------------------------------------------------------
        push    esi
        xor     eax, eax

    @@: lodsb
        test    al, al
        jz      .done
        cmp     al, 0x80
        jae     .big
        test    [fs.fat._.legal_chars + eax], 1
        jnz     @b

  .err:
        pop     esi
        clc
        ret

  .big:
        ; 0x80-0xAF, 0xE0-0xEF
        cmp     al, 0xb0
        jb      @b
        cmp     al, 0xe0
        jb      .err
        cmp     al, 0xf0
        jb      @b
        jmp     .err

  .done:
        sub     esi, [esp]
        cmp     esi, 257
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.next_short_name ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= 8+3 name
;-----------------------------------------------------------------------------------------------------------------------
;< name corrected and
;< CF = 0 (ok) or 1 (error)
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        mov     ecx, 8
        mov     al, '~'
        std
        push    edi
        add     edi, 7
        repnz   scasb
        pop     edi
        cld
        jz      .tilde
        ; tilde is not found, insert "~1" at end
        add     edi, 6
        cmp     word[edi], '  '
        jnz     .insert_tilde

    @@: dec     edi
        cmp     byte[edi], ' '
        jz      @b
        inc     edi

  .insert_tilde:
        mov     word[edi], '~1'
        popad
        clc
        ret

  .tilde:
        push    edi
        add     edi, 7
        xor     ecx, ecx

    @@: ; after tilde may be only digits and trailing spaces
        cmp     byte[edi], '~'
        jz      .break
        cmp     byte[edi], ' '
        jz      .space
        cmp     byte[edi], '9'
        jnz     .found
        dec     edi
        jmp     @b

  .space:
        dec     edi
        inc     ecx
        jmp     @b

  .found:
        inc     byte[edi]
        add     dword[esp], 8
        jmp     .zerorest

  .break:
        jecxz   .noplace
        inc     edi
        mov     al, '1'

    @@: xchg    al, [edi]
        inc     edi
        cmp     al, ' '
        mov     al, '0'
        jnz     @b

  .succ:
        pop     edi
        popad
        clc
        ret

  .noplace:
        dec     edi
        cmp     edi, [esp]
        jz      .err
        add     dword[esp], 8
        mov     word[edi], '~1'
        inc     edi
        inc     edi

    @@: mov     byte[edi], '0'

  .zerorest:
        inc     edi
        cmp     edi, [esp]
        jb      @b
        pop     edi
        popad
;       clc     ; automatically
        ret

  .err:
        pop     edi
        popad
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.gen_short_name ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= long name
;> edi ^= buffer (8+3=11 chars)
;-----------------------------------------------------------------------------------------------------------------------
;< buffer filled
;-----------------------------------------------------------------------------------------------------------------------

        pushad
        mov     eax, '    '
        push    edi
        stosd
        stosd
        stosd
        pop     edi
        xor     eax, eax
        push    8
        pop     ebx
        lea     ecx, [edi + 8]

  .loop:
        lodsb
        test    al, al
        jz      .done
        call    char_toupper
        cmp     al, ' '
        jz      .space
        cmp     al, 0x80
        ja      .big
        test    [fs.fat._.legal_chars + eax], 2
        jnz     .symbol

  .inv_symbol:
        mov     al, '_'
        or      bh, 1

  .symbol:
        cmp     al, '.'
        jz      .dot

  .normal_symbol:
        dec     bl
        jns     .store
        mov     bl, 0

  .space:
        or      bh, 1
        jmp     .loop

  .store:
        stosb
        jmp     .loop

  .big:
        cmp     al, 0xb0
        jb      .normal_symbol
        cmp     al, 0xe0
        jb      .inv_symbol
        cmp     al, 0xf0
        jb      .normal_symbol
        jmp     .inv_symbol

  .dot:
        test    bh, 2
        jz      .firstdot
        pop     ebx
        add     ebx, edi
        sub     ebx, ecx
        push    ebx
        cmp     ebx, ecx
        jb      @f
        pop     ebx
        push    ecx

    @@: cmp     edi, ecx
        jbe     .skip

    @@: dec     edi
        mov     al, [edi]
        dec     ebx
        mov     [ebx], al
        mov     byte[edi], ' '
        cmp     edi, ecx
        ja      @b

  .skip:
        mov     bh, 3
        jmp     @f

  .firstdot:
        cmp     bl, 8
        jz      .space
        push    edi
        or      bh, 2

    @@: mov     edi, ecx
        mov     bl, 3
        jmp     .loop

  .done:
        test    bh, 2
        jz      @f
        pop     edi

    @@: lea     edi, [ecx - 8]
        test    bh, 1
        jz      @f
        call    fs.fat.next_short_name

    @@: popad
        ret

    @@: mov     eax, ERROR_ACCESS_DENIED
        xor     ebx, ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.update_datetime ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    fs.fat.get_time_for_file
        mov     [edi + 22], ax ; last write time
        call    fs.fat.get_date_for_file
        mov     [edi + 24], ax ; last write date
        mov     [edi + 18], ax ; last access date
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.get_date_for_file ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get date from CMOS
;-----------------------------------------------------------------------------------------------------------------------
;< ax = pack[7(year since 1980), 4(month, 1..12), 5(day, 0..31)]
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x7 ; day
        out     0x70, al
        in      al, 0x71
        call    bcd2bin
        ror     eax, 5

        mov     al, 0x08 ; month
        out     0x70, al
        in      al, 0x71
        call    bcd2bin
        ror     eax, 4

        mov     al, 0x09 ; year
        out     0x70, al
        in      al, 0x71
        call    bcd2bin

        ; because CMOS return only the two last digit (eg. 2000 -> 00 , 2001 -> 01) and we
        ; need the difference with 1980 (eg. 2001-1980)
        add     ax, 20

        rol     eax, 9
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.get_time_for_file ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get time from CMOS
;-----------------------------------------------------------------------------------------------------------------------
;< ax = pack[5(hours, 0..23), 6(minutes, 0..59), 5(seconds, low bit lost)]
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x0 ; second
        out     0x70, al
        in      al, 0x71
        call    bcd2bin
        ror     eax, 6

        mov     al, 0x2 ; minute
        out     0x70, al
        in      al, 0x71
        call    bcd2bin
        ror     eax, 6

        mov     al, 0x4 ; hour
        out     0x70, al
        in      al, 0x71
        call    bcd2bin
        rol     eax, 11
        ret
kendp

;;======================================================================================================================
;;///// private functions //////////////////////////////////////////////////////////////////////////////////////////////
;;======================================================================================================================

iglobal
  ; 0 = not allowed
  ; 1 = allowed only in long names
  ; 3 = allowed
  fs.fat._.legal_chars \
    db 32 dup(0)
    ;  !  "  #  $  %  &  '  (  )  *  +  ,  -  .  /
    db 1, 3, 0, 3, 3, 3, 3, 3, 3, 3, 0, 1, 1, 3, 3, 0
    ;  0  1  2  3  4  5  6  7  8  9  :  ;  <  =  >  ?
    db 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 1, 0, 1, 0, 0
    ;  @  A  B  C  D  E  F  G  H  I  J  K  L  M  N  O
    db 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
    ;  P  Q  R  S  T  U  V  W  X  Y  Z  [  \  ]  ^  _
    db 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 1, 0, 1, 3, 3
    ;  `  a  b  c  d  e  f  g  h  i  j  k  l  m  n  o
    db 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
    ;  p  q  r  s  t  u  v  w  x  y  z  {  |  }  ~
    db 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 3, 3, 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.fat_time_to_bdfe_time ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = FAT time
;-----------------------------------------------------------------------------------------------------------------------
;< eax = BDFE time
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx
        mov     ecx, eax
        mov     edx, eax
        shr     eax, 11
        shl     eax, 16 ; hours
        and     edx, 0x1f
        add     edx, edx
        mov     al, dl ; seconds
        shr     ecx, 5
        and     ecx, 0x3f
        mov     ah, cl ; minutes
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.fat_date_to_bdfe_date ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx
        mov     ecx, eax
        mov     edx, eax
        shr     eax, 9
        add     ax, 1980
        shl     eax, 16 ; year
        and     edx, 0x1f
        mov     al, dl ; day
        shr     ecx, 5
        and     ecx, 0x0f
        mov     ah, cl ; month
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.bdfe_time_to_fat_time ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        mov     edx, eax
        shr     eax, 16
        and     dh, 0x3f
        shl     eax, 6
        or      al, dh
        shr     dl, 1
        and     dl, 0x1f
        shl     eax, 5
        or      al, dl
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat._.bdfe_date_to_fat_date ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        mov     edx, eax
        shr     eax, 16
        sub     ax, 1980
        and     dh, 0x0f
        shl     eax, 4
        or      al, dh
        and     dl, 0x1f
        shl     eax, 5
        or      al, dl
        pop     edx
        ret
kendp
