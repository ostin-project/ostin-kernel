;;======================================================================================================================
;;///// fat_common.asm ///////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011-2012 Ostin project <http://ostin.googlecode.com/>
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

FS_FAT_ATTR_READ_ONLY = 00000001b ; 0x01
FS_FAT_ATTR_HIDDEN    = 00000010b ; 0x02
FS_FAT_ATTR_SYSTEM    = 00000100b ; 0x04
FS_FAT_ATTR_VOLUME_ID = 00001000b ; 0x08
FS_FAT_ATTR_DIRECTORY = 00010000b ; 0x10
FS_FAT_ATTR_ARCHIVE   = 00100000b ; 0x20
FS_FAT_ATTR_LONG_NAME = 00001111b ; 0x0f

FS_FAT_ATTR_LONG_NAME_MASK = 00111111b ; 0x3f

struct fs.fat.dir_entry_t
  name               db 11 dup(?)
  attributes         db ?
                     rb 1
  created_at.time_ms db ?
  created_at.time    dw ?
  created_at.date    dw ?
  accessed_at.date   dw ?
  start_cluster.high dw ?
  modified_at.time   dw ?
  modified_at.date   dw ?
  start_cluster.low  dw ?
  size               dd ?
ends

assert sizeof.fs.fat.dir_entry_t = 32

struct fs.fat.lfn_dir_entry_t
  sequence_number db ?
  name.part_1     du 5 dup(?)
  attributes      db ?
                  rb 1
  checksum        db ?
  name.part_2     du 6 dup(?)
  start_cluster   dw ?
  name.part_3     du 2 dup(?)
ends

assert sizeof.fs.fat.lfn_dir_entry_t = sizeof.fs.fat.dir_entry_t

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.get_name ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= fs.fat.dir_entry_t or fs.fat.lfn_dir_entry_t
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
        je      .no
        cmp     byte[edi], 0xe5
        jne     @f

  .no:
        stc
        ret

    @@: cmp     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_LONG_NAME
        je      .longname
        test    [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_VOLUME_ID
        jnz     .no
        push    ecx
        push    edi ebp
        test    byte[ebp - 4], 1
        jnz     .unicode_short

        mov     eax, dword[edi + fs.fat.dir_entry_t.name]
        mov     ecx, dword[edi + fs.fat.dir_entry_t.name + 4]
        mov     [ebp], eax
        mov     [ebp + 4], ecx

        mov     ecx, 8

    @@: cmp     byte[ebp + ecx - 1], ' '
        loope   @b

        mov     eax, dword[edi + fs.fat.dir_entry_t.name + 8]
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

    @@: mov     al, [edi + fs.fat.dir_entry_t.name]
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

    @@: mov     al, [edi + fs.fat.dir_entry_t.name]
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
        mov     al, [edi + fs.fat.lfn_dir_entry_t.sequence_number]
        and     eax, 0x3f
        dec     eax
        cmp     al, 20
        jae     .no ; ignore invalid entries
        mov     word[ebp + 260 * 2], 0 ; force null-terminating for orphans
        imul    eax, 13 * 2
        add     ebp, eax
        test    [edi + fs.fat.lfn_dir_entry_t.sequence_number], 0x40
        jz      @f
        mov     word[ebp + 13 * 2], 0

    @@: push    eax
        ; now copy name from edi to ebp ...
        mov     eax, dword[edi + fs.fat.lfn_dir_entry_t.name.part_1]
        mov     [ebp], eax ; symbols 1,2
        mov     eax, dword[edi + fs.fat.lfn_dir_entry_t.name.part_1 + 2 * 2]
        mov     [ebp + 4], eax ; 3,4
        mov     eax, dword[edi + fs.fat.lfn_dir_entry_t.name.part_1 + 2 * 4]
        mov     [ebp + 8], ax ; 5
        mov     eax, dword[edi + fs.fat.lfn_dir_entry_t.name.part_2]
        mov     [ebp + 10], eax ; 6,7
        mov     eax, dword[edi + fs.fat.lfn_dir_entry_t.name.part_2 + 2 * 2]
        mov     [ebp + 14], eax ; 8,9
        mov     eax, dword[edi + fs.fat.lfn_dir_entry_t.name.part_2 + 2 * 4]
        mov     [ebp + 18], eax ; 10,11
        mov     eax, dword[edi + fs.fat.lfn_dir_entry_t.name.part_3]
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
kproc fs.fat.util.fat_entry_to_bdfe ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert FAT entry to BDFE (block of data of folder entry), advancing esi
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= fs.fat.dir_entry_t
;> esi ^= fs.file_info_t
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [ebp - 4]
        mov     [esi + fs.file_info_t.flags], eax  ; ASCII/UNICODE name

  .direct:
        movzx   eax, [edi + fs.fat.dir_entry_t.attributes]
        mov     [esi + fs.file_info_t.attributes], eax

        movzx   eax, [edi + fs.fat.dir_entry_t.created_at.time]
        call    fs.fat.util._.fat_time_to_bdfe_time
        mov     [esi + fs.file_info_t.created_at.time], eax

        movzx   eax, [edi + fs.fat.dir_entry_t.created_at.date]
        call    fs.fat.util._.fat_date_to_bdfe_date
        mov     [esi + fs.file_info_t.created_at.date], eax

        ; last access time is not supported on FAT
        and     [esi + fs.file_info_t.accessed_at.time], 0

        movzx   eax, [edi + fs.fat.dir_entry_t.accessed_at.date]
        call    fs.fat.util._.fat_date_to_bdfe_date
        mov     [esi + fs.file_info_t.accessed_at.date], eax

        movzx   eax, [edi + fs.fat.dir_entry_t.modified_at.time]
        call    fs.fat.util._.fat_time_to_bdfe_time
        mov     [esi + fs.file_info_t.modified_at.time], eax

        movzx   eax, [edi + fs.fat.dir_entry_t.modified_at.date]
        call    fs.fat.util._.fat_date_to_bdfe_date
        mov     [esi + fs.file_info_t.modified_at.date], eax

        mov     eax, [edi + fs.fat.dir_entry_t.size]
        mov     [esi + fs.file_info_t.size.low], eax
        and     [esi + fs.file_info_t.size.high], 0

        test    ebp, ebp
        jz      .exit

        push    ecx edi
        lea     edi, [esi + fs.file_info_t.name]
        mov     esi, ebp
        test    byte[esi - 4], 1
        jz      .ansi

        mov     ecx, 260 / 2
        rep
        movsd
        mov     [edi - 2], ax
        jmp     @f

  .ansi:
        mov     ecx, 264 / 4
        rep
        movsd
        mov     [edi - 1], al

    @@: mov     esi, edi
        pop     edi ecx

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.bdfe_to_fat_entry ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert BDFE to FAT entry
;-----------------------------------------------------------------------------------------------------------------------
;> edx ^= fs.file_info_t
;> edi ^= fs.fat.dir_entry_t
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;# attributes byte
;-----------------------------------------------------------------------------------------------------------------------
        test    byte[edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_VOLUME_ID
        jnz     @f
        mov     al, [edx]
        and     al, 0x27
        and     [edi + fs.fat.dir_entry_t.attributes], FS_FAT_ATTR_DIRECTORY
        or      [edi + fs.fat.dir_entry_t.attributes], al

    @@: mov     eax, [edx + fs.file_info_t.created_at.time]
        call    fs.fat.util._.bdfe_time_to_fat_time
        mov     [edi + fs.fat.dir_entry_t.created_at.time], ax

        mov     eax, [edx + fs.file_info_t.created_at.date]
        call    fs.fat.util._.bdfe_date_to_fat_date
        mov     [edi + fs.fat.dir_entry_t.created_at.date], ax

        mov     eax, [edx + fs.file_info_t.accessed_at.date]
        call    fs.fat.util._.bdfe_date_to_fat_date
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax

        mov     eax, [edx + fs.file_info_t.modified_at.time]
        call    fs.fat.util._.bdfe_time_to_fat_time
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax

        mov     eax, [edx + fs.file_info_t.modified_at.date]
        call    fs.fat.util._.bdfe_date_to_fat_date
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.read_symbols ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
    @@: call    .read_symbol
        stosw
        loop    @b
        ret

  .read_symbol:
        or      ax, -1
        test    esi, esi
        jz      @f
        lodsb
        test    al, al
        jnz     ansi2uni_char
        xor     eax, eax
        xor     esi, esi

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.name_is_legal ;///////////////////////////////////////////////////////////////////////////////////////
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
kproc fs.fat.util.next_short_name ;/////////////////////////////////////////////////////////////////////////////////////
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
        repnz
        scasb
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
kproc fs.fat.util.gen_short_name ;//////////////////////////////////////////////////////////////////////////////////////
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
        mov_s_  ebx, 8
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
        call    fs.fat.util.next_short_name

    @@: popad
        ret

    @@: mov     eax, ERROR_ACCESS_DENIED
        xor     ebx, ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.update_datetime ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    fs.fat.util.get_time_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.time], ax
        call    fs.fat.util.get_date_for_file
        mov     [edi + fs.fat.dir_entry_t.modified_at.date], ax
        mov     [edi + fs.fat.dir_entry_t.accessed_at.date], ax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.get_date_for_file ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get date from CMOS
;-----------------------------------------------------------------------------------------------------------------------
;< ax = pack[7(year since 1980), 4(month, 1..12), 5(day, 0..31)]
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x7 ; day
        out     0x70, al
        in      al, 0x71
        call    fs.fat.util._.bcd2bin
        ror     eax, 5

        mov     al, 0x08 ; month
        out     0x70, al
        in      al, 0x71
        call    fs.fat.util._.bcd2bin
        ror     eax, 4

        mov     al, 0x09 ; year
        out     0x70, al
        in      al, 0x71
        call    fs.fat.util._.bcd2bin

        ; because CMOS return only the two last digit (eg. 2000 -> 00 , 2001 -> 01) and we
        ; need the difference with 1980 (eg. 2001-1980)
        add     ax, 20

        rol     eax, 9
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.get_time_for_file ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Get time from CMOS
;-----------------------------------------------------------------------------------------------------------------------
;< ax = pack[5(hours, 0..23), 6(minutes, 0..59), 5(seconds, low bit lost)]
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 0x0 ; second
        out     0x70, al
        in      al, 0x71
        call    fs.fat.util._.bcd2bin
        ror     eax, 6

        mov     al, 0x2 ; minute
        out     0x70, al
        in      al, 0x71
        call    fs.fat.util._.bcd2bin
        ror     eax, 6

        mov     al, 0x4 ; hour
        out     0x70, al
        in      al, 0x71
        call    fs.fat.util._.bcd2bin
        rol     eax, 11
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.calculate_name_checksum ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= name in 8+3 format
;-----------------------------------------------------------------------------------------------------------------------
;< al = checksum
;-----------------------------------------------------------------------------------------------------------------------
        push    esi ecx
        mov     esi, eax
        mov     ecx, 11
        xor     eax, eax

    @@: ror     al, 1
        add     al, [esi]
        inc     esi
        loop    @b

        pop     ecx esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.find_long_name ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= name
;> [esp + 4]... = possibly parameters for first and next
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 1 - file not found
;< CF = 0,
;<   esi = pointer to next name component
;<   edi pointer to direntry
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        lea     eax, [esp + sizeof.regs_context32_t + 4]
        call    fs.fat._.first_dir_entry
        jc      .reterr
        sub     esp, 262 * 2 ; reserve place for LFN
        mov     ebp, esp
        push    0 ; for fs.fat.get_name: read ASCII name

  .l1:
        call    fs.fat.util.get_name
        jc      .l2
        call    fs.fat.util._.compare_name
        jz      .found

  .l2:
        lea     eax, [esp + sizeof.regs_context32_t + 4 + 262 * 2 + 4]
        call    fs.fat._.next_dir_entry
        jnc     .l1
        add     esp, 262 * 2 + 4

  .reterr:
        stc
        popa
        ret

  .found:
        add     esp, 262 * 2 + 4
        ; if this is LFN entry, advance to true entry
        cmp     [edi + fs.fat.dir_entry_t.attributes], 0x0f
        jne     @f
        lea     eax, [esp + sizeof.regs_context32_t + 4]
        call    fs.fat._.next_dir_entry
        jc      .reterr

    @@: add     esp, 8 ; CF=0
        push    esi
        push    edi
        popa
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util.cluster_to_sector ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= cluster number
;> ebx ^= fs.fat.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= sector number
;-----------------------------------------------------------------------------------------------------------------------
        add     eax, -2
        imul    eax, [ebx + fs.fat.partition_t.cluster_size]
        add     eax, [ebx + fs.fat.partition_t.data_area_sector]
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
kproc fs.fat.util._.bcd2bin ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> al = BCD number (eg. 0x11)
;-----------------------------------------------------------------------------------------------------------------------
;< ah = 0
;< al = decimal number (eg. 11)
;-----------------------------------------------------------------------------------------------------------------------
        xor     ah, ah
        shl     ax, 4
        shr     al, 4
        aad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util._.fat_time_to_bdfe_time ;/////////////////////////////////////////////////////////////////////////////
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
kproc fs.fat.util._.fat_date_to_bdfe_date ;/////////////////////////////////////////////////////////////////////////////
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
kproc fs.fat.util._.bdfe_time_to_fat_time ;/////////////////////////////////////////////////////////////////////////////
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
kproc fs.fat.util._.bdfe_date_to_fat_date ;/////////////////////////////////////////////////////////////////////////////
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

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.util._.compare_name ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? compares ASCIIZ-names, case-insensitive (cp866 encoding)
;-----------------------------------------------------------------------------------------------------------------------
;> esi = name
;> ebp = name
;-----------------------------------------------------------------------------------------------------------------------
;; if names match:
;<   ZF = 1
;<   esi = next component of name
;; else:
;<   ZF = 0
;<   esi = not changed
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp esi

  .loop:
        mov     al, [ebp]
        inc     ebp
        call    char_toupper
        push    eax
        lodsb
        call    char_toupper
        cmp     al, [esp]
        jnz     .done
        pop     eax
        test    al, al
        jnz     .loop
        dec     esi
        pop     eax
        pop     ebp
        xor     eax, eax ; set ZF flag
        ret

  .done:
        cmp     al, '/'
        jnz     @f
        cmp     byte[esp], 0
        jnz     @f
        mov     [esp + 4], esi

    @@: pop     eax
        pop     esi ebp
        ret
kendp
