;;======================================================================================================================
;;///// rd.asm ///////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
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

;-----------------------------------------------------------------------------------------------------------------------
kproc calculatefatchain ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= ... (buffer)
;> edi ^= ... (fat)
;> eflags[df] ~= 0
;-----------------------------------------------------------------------------------------------------------------------
        pushad

        lea     ebp, [edi + 2856 * 2] ; 2849 clusters

  .fcnew:
        lodsd
        xchg    eax, ecx
        lodsd
        xchg    eax, ebx
        lodsd
        xchg    eax, ecx
        mov     edx, ecx

        shr     edx, 4 ; 8 ok
        shr     dx, 4 ; 7 ok
        xor     ch, ch
        shld    ecx, ebx, 20 ; 6 ok
        shr     cx, 4 ; 5 ok
        shld    ebx, eax, 12
        and     ebx, 0x0fffffff ; 4 ok
        shr     bx, 4 ; 3 ok
        shl     eax, 4
        and     eax, 0x0fffffff ; 2 ok
        shr     ax, 4 ; 1 ok

        stosd
        xchg    eax, ebx
        stosd
        xchg    eax, ecx
        stosd
        xchg    eax, edx
        stosd

        cmp     edi, ebp
        jb      .fcnew

        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc restorefatchain ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= ... (fat)
;> edi ^= ... (buffer)
;> eflags[df] ~= 0
;-----------------------------------------------------------------------------------------------------------------------
        pushad

        lea     ebp, [edi + 0x1200] ; 4274 bytes - all used FAT
        push    edi

  .fcnew:
        lodsd
        xchg    eax, ebx
        lodsw
        xchg    eax, ebx

        shl     ax, 4
        shl     eax, 4
        shl     bx, 4
        shr     ebx, 4
        shrd    eax, ebx, 8
        shr     ebx, 8

        stosd
        xchg    eax, ebx
        stosw

        cmp     edi, ebp
        jb      .fcnew

        ; duplicate fat chain
        pop     esi
        mov     edi, ebp
        mov     ecx, 0x1200 / 4
        rep     movsd

        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_free_space ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;< edi = free space
;-----------------------------------------------------------------------------------------------------------------------

        push    eax ebx ecx

        mov     edi, RAMDISK_FAT ; start of FAT
        xor     ax, ax ; Free cluster = 0x0000 in FAT
        xor     ebx, ebx ; counter
        mov     ecx, 2849 ; 2849 clusters
        cld

  .rdfs1:
        repne   scasw
        jnz     .rdfs2 ; if last cluster not 0
        inc     ebx
        test    ecx, ecx
        jnz     .rdfs1

  .rdfs2:
        shl     ebx, 9 ; free clusters*512
        mov     edi, ebx

        pop     ecx ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc expand_filename ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? exapand filename with '.' to 11 character
;-----------------------------------------------------------------------------------------------------------------------
;> eax - pointer to filename
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi ebx

        mov     edi, esp ; check for '.' in the name
        add     edi, 12 + 8

        mov     esi, eax

        mov     eax, edi
        mov     dword[eax + 0], '    '
        mov     dword[eax + 4], '    '
        mov     dword[eax + 8], '    '

  .flr1:
        cmp     byte[esi], '.'
        jne     .flr2
        mov     edi, eax
        add     edi, 7
        jmp     .flr3

  .flr2:
        mov     bl, [esi]
        mov     [edi], bl

  .flr3:
        inc     esi
        inc     edi

        mov     ebx, eax
        add     ebx, 11

        cmp     edi, ebx
        jbe     .flr1

        pop     ebx edi esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fileread ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? fileread - sys floppy
;-----------------------------------------------------------------------------------------------------------------------
;> eax = points to filename 11 chars
;> ebx = first wanted block       ; 1+ ; if 0 then set to 1
;> ecx = number of blocks to read ; 1+ ; if 0 then set to 1
;> edx = mem location to return data
;> esi = length of filename 12*X 0=root
;-----------------------------------------------------------------------------------------------------------------------
;< ebx = size or 0xffffffff file not found
;< eax = 0 ok read or other = errormsg
;-----------------------------------------------------------------------------------------------------------------------
        test    ebx, ebx ; if ebx=0 - set to 1
        jnz     .frfl5
        inc     ebx

  .frfl5:
        test    ecx, ecx ; if ecx=0 - set to 1
        jnz     .frfl6
        inc     ecx

  .frfl6:
        test    esi, esi ; return ramdisk root
        jnz     .fr_noroot ; if not root
        cmp     ebx, 14 ; 14 clusters=root dir
        ja      .oorr
        cmp     ecx, 14
        ja      .oorr
        jmp     .fr_do

  .oorr:
        mov     eax, 5 ; out of root range (fnf)
        xor     ebx, ebx
        dec     ebx ; 0xffffffff
        ret

  .fr_do:
        ; reading rootdir
        mov     edi, edx
        dec     ebx
        push    edx
        mov     edx, ecx
        add     edx, ebx
        cmp     edx, 15 ; ebx+ecx=14+1
        pushf
        jbe     .fr_do1
        sub     edx, 14
        sub     ecx, edx

  .fr_do1:
        shl     ebx, 9
        mov     esi, RAMDISK + 512 * 19
        add     esi, ebx
        shl     ecx, 7
        cld
        rep     movsd
        popf
        pop     edx
        jae     .fr_do2
        xor     eax, eax ; ok read
        xor     ebx, ebx
        ret

  .fr_do2: ; if last cluster
        mov     eax, 6 ; end of file
        xor     ebx, ebx
        ret

  .fr_noroot:
        sub     esp, 32
        call    expand_filename

        dec     ebx

        push    eax

        push    eax ebx ecx edx esi edi
        call    rd_findfile
        je      .fifound
        add     esp, 32 + 28 ; if file not found
        ret

  .fifound:
        mov     ebx, [edi - 11 + 28] ; file size
        mov     [esp + 20], ebx
        mov     [esp + 24], ebx
        add     edi, 0x0f
        movzx   eax, word[edi]
        mov     edi, eax ; edi=cluster

  .frnew:
        add     eax, 31 ; bootsector+2*fat+filenames
        shl     eax, 9 ; *512
        add     eax, RAMDISK ; image base
        mov     ebx, [esp + 8]
        mov     ecx, 512 ; [esp + 4]

        cmp     dword[esp + 16], 0 ; wanted cluster ?
        jne     .frfl7
        call    memmove
        add     dword[esp + 8], 512
        dec     dword[esp + 12] ; last wanted cluster ?
        je      .frnoread
        jmp     .frfl8

  .frfl7:
        dec     dword[esp + 16]

  .frfl8:
        movzx   eax, word[edi * 2 + RAMDISK_FAT] ; find next cluster from FAT
        mov     edi, eax
        cmp     edi, 4095 ; eof  - cluster
        jz      .frnoread2

        cmp     dword[esp + 24], 512 ; eof - size
        jb      .frnoread
        sub     dword[esp + 24], 512

        jmp     .frnew

  .frnoread2:
        cmp     dword[esp + 16], 0 ; eof without read ?
        je      .frnoread

        pop     edi  esi edx ecx
        add     esp, 4
        pop     ebx ; ebx <- eax : size of file
        add     esp, 36
        mov     eax, 6 ; end of file
        ret

  .frnoread:
        pop     edi esi edx ecx
        add     esp, 4
        pop     ebx ; ebx <- eax : size of file
        add     esp, 36
        xor     eax, eax ; read ok
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rd_findfile ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pointer to filename
;-----------------------------------------------------------------------------------------------------------------------
;< ZF = 0
;<   eax, ebx = fnf
;< ZF = 1
;<   edi = filestring + 11
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, RAMDISK + 512 * 18 + 512 ; Point at directory
        cld

  .rd_newsearch:
        mov     esi, eax
        mov     ecx, 11
        rep     cmpsb
        je      .rd_ff
        add     cl, 21
        add     edi, ecx
        cmp     edi, RAMDISK + 512 * 33
        jb      .rd_newsearch
        mov     eax, 5 ; if file not found - eax=5
        xor     ebx, ebx
        dec     ebx ; ebx=0xffffffff and zf=0

  .rd_ff:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fat_compare_name ;////////////////////////////////////////////////////////////////////////////////////////////////
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

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_root_first ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, RAMDISK + 512 * 19
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_root_next ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        add     edi, 0x20
        cmp     edi, RAMDISK + 512 * 33
        cmc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_root_extend_dir ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        stc
        ret
kendp

uglobal
  ; this is for delete support
  rd_prev_sector      dd ?
  rd_prev_prev_sector dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_notroot_next ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        add     edi, 0x20
        test    edi, 0x1ff
        jz      ramdisk_notroot_next_sector
        ret     ; CF=0
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_notroot_next_sector ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     ecx, [eax]
        push    [rd_prev_sector]
        pop     [rd_prev_prev_sector]
        mov     [rd_prev_sector], ecx
        mov     ecx, [ecx * 2 + RAMDISK_FAT]
        and     ecx, 0x0fff
        cmp     ecx, 2849
        jae     ramdisk_notroot_first.err2
        mov     [eax], ecx
        pop     ecx
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_notroot_first ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [eax]
        cmp     eax, 2
        jb      .err
        cmp     eax, 2849
        jae     .err
        shl     eax, 9
        lea     edi, [eax + (31 shl 9) + RAMDISK]
        clc
        ret

  .err2:
        pop     ecx

  .err:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_notroot_next_write ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        test    edi, 0x1ff
        jz      ramdisk_notroot_next_sector
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_root_next_write ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_notroot_extend_dir ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        xor     eax, eax
        mov     edi, RAMDISK_FAT
        mov     ecx, 2849
        repnz   scasw
        jnz     .notfound
        mov     word[edi - 2], 0x0fff
        sub     edi, RAMDISK_FAT
        shr     edi, 1
        dec     edi
        mov     eax, [esp + 28]
        mov     ecx, [eax]
        mov     [RAMDISK_FAT + ecx * 2], di
        mov     [eax], edi
        shl     edi, 9
        add     edi, (31 shl 9) + RAMDISK
        mov     [esp], edi
        xor     eax, eax
        mov     ecx, 128
        rep     stosd
        popa
        clc
        ret

  .notfound:
        popa
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rd_find_lfn ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi + ebp = name
;-----------------------------------------------------------------------------------------------------------------------
;; file not found:
;<   CF = 1
;; else:
;<   CF = 0
;<   edi = direntry
;-----------------------------------------------------------------------------------------------------------------------
        push    esi edi
        push    0
        push    ramdisk_root_first
        push    ramdisk_root_next

  .loop:
        call    fat_find_lfn
        jc      .notfound
        cmp     byte[esi], 0
        jz      .found

  .continue:
        test    byte[edi + 11], 0x10
        jz      .notfound
        movzx   eax, word[edi + 26]
        mov     [esp + 8], eax
        mov     dword[esp + 4], ramdisk_notroot_first
        mov     dword[esp], ramdisk_notroot_next
        test    eax, eax
        jnz     .loop
        mov     dword[esp + 4], ramdisk_root_first
        mov     dword[esp], ramdisk_notroot_next
        jmp     .loop

  .notfound:
        add     esp, 12
        pop     edi esi
        stc
        ret

  .found:
        test    ebp, ebp
        jz      @f
        mov     esi, ebp
        xor     ebp, ebp
        jmp     .continue

    @@: mov     eax, [esp + 8]
        add     esp, 16 ; CF=0
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskRead ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for reading sys floppy
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to 64-bit number = first wanted byte, 0+
;> ecx = number of bytes to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;; file found and successfully read:
;<   eax = 0
;<   ebx = bytes read
;; else:
;<   eax = error code
;<   ebx = -1
;-----------------------------------------------------------------------------------------------------------------------
;# if ebx = NULL, start from first byte
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f
        or      ebx, -1
        mov     eax, 10 ; access denied
        ret

    @@: push    edi
        call    rd_find_lfn
        jnc     .found
        pop     edi
        or      ebx, -1
        mov     eax, 5 ; file not found
        ret

  .found:
        test    ebx, ebx
        jz      .l1
        cmp     dword[ebx + 4], 0
        jz      @f
        xor     ebx, ebx

  .reteof:
        mov     eax, 6 ; EOF
        pop     edi
        ret

    @@: mov     ebx, [ebx]

  .l1:
        push    ecx edx
        push    0
        mov     eax, [edi + 28]
        sub     eax, ebx
        jb      .eof
        cmp     eax, ecx
        jae     @f
        mov     ecx, eax
        mov     byte[esp], 6 ; EOF

    @@: movzx   edi, word[edi + 26] ; cluster

  .new:
        jecxz   .done
        test    edi, edi
        jz      .eof
        cmp     edi, 0x0ff8
        jae     .eof
        lea     eax, [edi + 31] ; bootsector+2*fat+filenames
        shl     eax, 9 ; *512
        add     eax, RAMDISK ; image base
        ; now eax points to data of cluster
        sub     ebx, 512
        jae     .skip
        lea     eax, [eax + ebx + 512]
        neg     ebx
        push    ecx
        cmp     ecx, ebx
        jbe     @f
        mov     ecx, ebx

    @@: mov     ebx, edx
        call    memmove
        add     edx, ecx
        sub     [esp], ecx
        pop     ecx
        xor     ebx, ebx

  .skip:
        movzx   edi, word[edi * 2 + RAMDISK_FAT] ; find next cluster from FAT
        jmp     .new

  .eof:
        mov     ebx, edx
        pop     eax edx ecx
        sub     ebx, edx
        jmp     .reteof

  .done:
        mov     ebx, edx
        pop     eax edx ecx edi
        sub     ebx, edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskReadFolder ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for reading sys floppy folder
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename; only root is folder on ramdisk
;> ebx = pointer to structure 32-bit number = first wanted block & flags (bitfields)
;> ecx = number of blocks to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;; directory found and successfully read:
;<   eax = 0
;<   ebx = bytes read
;; else:
;<   eax = error code
;<   ebx = -1
;-----------------------------------------------------------------------------------------------------------------------
;# flags: bit 0: 0=ANSI names, 1=UNICODE names
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        cmp     byte[esi], 0
        jz      .root
        call    rd_find_lfn
        jnc     .found
        pop     edi
        or      ebx, -1
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

  .found:
        test    byte[edi + 11], 0x10
        jnz     .found_dir
        pop     edi
        or      ebx, -1
        mov     eax, ERROR_ACCESS_DENIED
        ret

  .found_dir:
        movzx   eax, word[edi + 26]
        add     eax, 31
        push    0
        jmp     .doit

  .root:
        mov     eax, 19
        push    14

  .doit:
        push    esi ecx ebp
        sub     esp, 262 * 2 ; reserve space for LFN
        mov     ebp, esp
        push    dword[ebx + 4] ; for fs.fat.get_name: read ANSI/UNICODE names
        mov     ebx, [ebx]
        ; init header
        push    eax ecx
        mov     edi, edx
        mov     ecx, 32 / 4
        xor     eax, eax
        rep     stosd
        mov     byte[edx], 1 ; version
        pop     ecx eax
        mov     esi, edi ; esi points to block of data of folder entry (BDFE)

  .main_loop:
        mov     edi, eax
        shl     edi, 9
        add     edi, RAMDISK
        push    eax

  .l1:
        call    fs.fat.get_name
        jc      .l2
        cmp     byte[edi + 11], 0x0f
        jnz     .do_bdfe
        add     edi, 0x20
        test    edi, 0x1ff
        jnz     .do_bdfe
        pop     eax
        inc     eax
        dec     byte[esp + 262 * 2 + 16]
        jz      .done
        jns     @f
        ; read next sector from FAT
        mov     eax, [(eax - 31 - 1) * 2 + RAMDISK_FAT]
        and     eax, 0x0fff
        cmp     eax, 0x0ff8
        jae     .done
        add     eax, 31
        mov     byte[esp + 262 * 2 + 16], 0

    @@: mov     edi, eax
        shl     edi, 9
        add     edi, RAMDISK
        push    eax

  .do_bdfe:
        inc     dword[edx + 8] ; new file found
        dec     ebx
        jns     .l2
        dec     ecx
        js      .l2
        inc     dword[edx + 4] ; new file block copied
        call    fs.fat.fat_entry_to_bdfe

  .l2:
        add     edi, 0x20
        test    edi, 0x1ff
        jnz     .l1
        pop     eax
        inc     eax
        dec     byte[esp + 262 * 2 + 16]
        jz      .done
        jns     @f
        ; read next sector from FAT
        mov     eax, [(eax - 31 - 1) * 2 + RAMDISK_FAT]
        and     eax, 0x0fff
        cmp     eax, 0x0ff8
        jae     .done
        add     eax, 31
        mov     byte[esp + 262 * 2 + 16], 0

    @@: jmp     .main_loop

  .done:
        add     esp, 262 * 2 + 4
        pop     ebp
        mov     ebx, [edx + 4]
        xor     eax, eax
        dec     ecx
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: pop     ecx esi edi edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskCreateFolder ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? create folder on ramdisk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to folder name
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 1 ; create folder
        jmp     fs_RamdiskRewrite.common
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskRewrite ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for writing ramdisk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to file name
;> ecx = number of bytes to write, 0+
;> edx = mem location to data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = number of written bytes
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax ; create file

  .common:
        cmp     byte[esi], 0
        jz      @b
        pushad
        xor     edi, edi
        push    esi
        test    ebp, ebp
        jz      @f
        mov     esi, ebp

    @@: lodsb
        test    al, al
        jz      @f
        cmp     al, '/'
        jnz     @b
        lea     edi, [esi - 1]
        jmp     @b

    @@: pop     esi
        test    edi, edi
        jnz     .noroot
        test    ebp, ebp
        jnz     .hasebp
        push    ramdisk_root_extend_dir
        push    ramdisk_root_next_write
        push    edi
        push    ramdisk_root_first
        push    ramdisk_root_next
        jmp     .common1

  .hasebp:
        mov     eax, ERROR_ACCESS_DENIED
        cmp     byte[ebp], 0
        jz      .ret1
        push    ebp
        xor     ebp, ebp
        call    rd_find_lfn
        pop     esi
        jc      .notfound0
        jmp     .common0

  .noroot:
        mov     eax, ERROR_ACCESS_DENIED
        cmp     byte[edi + 1], 0
        jz      .ret1
        ; check existence
        mov     byte[edi], 0
        push    edi
        call    rd_find_lfn
        pop     esi
        mov     byte[esi], '/'
        jnc     @f

  .notfound0:
        mov     eax, ERROR_FILE_NOT_FOUND

  .ret1:
        mov     [esp + 28], eax
        popad
        xor     ebx, ebx
        ret

    @@: inc     esi

  .common0:
        test    byte[edi + 11], 0x10 ; must be directory
        mov     eax, ERROR_ACCESS_DENIED
        jz      .ret1
        movzx   ebp, word[edi + 26] ; ebp=cluster
        mov     eax, ERROR_FAT_TABLE
        cmp     ebp, 2
        jb      .ret1
        cmp     ebp, 2849
        jae     .ret1
        push    ramdisk_notroot_extend_dir
        push    ramdisk_notroot_next_write
        push    ebp
        push    ramdisk_notroot_first
        push    ramdisk_notroot_next

  .common1:
        call    fat_find_lfn
        jc      .notfound
        ; found
        test    byte[edi + 11], 0x10
        jz      .exists_file
        ; found directory; if we are creating directory, return OK,
        ;                  if we are creating file, say "access denied"
        add     esp, 20
        popad
        test    al, al
        mov     eax, ERROR_ACCESS_DENIED
        jz      @f
        mov     al, 0

    @@: xor     ebx, ebx
        ret

  .exists_file:
        ; found file; if we are creating directory, return "access denied",
        ;             if we are creating file, delete existing file and continue
        cmp     byte[esp + 20 + 28], 0
        jz      @f
        add     esp, 20
        popad
        mov     eax, ERROR_ACCESS_DENIED
        xor     ebx, ebx
        ret

    @@: ; delete FAT chain
        push    edi
        xor     eax, eax
        mov     dword[edi + 28], eax ; zero size
        xchg    ax, word[edi + 26] ; start cluster
        test    eax, eax
        jz      .done1

    @@: cmp     eax, 0x0ff8
        jae     .done1
        lea     edi, [RAMDISK_FAT + eax * 2] ; position in FAT
        xor     eax, eax
        xchg    ax, [edi]
        jmp     @b

  .done1:
        pop     edi
        call    fs.fat.get_time_for_file
        mov     [edi + 22], ax
        call    fs.fat.get_date_for_file
        mov     [edi + 24], ax
        mov     [edi + 18], ax
        or      byte[edi + 11], 0x20 ; set 'archive' attribute
        jmp     .doit

  .notfound:
        ; file is not found; generate short name
        call    fs.fat.name_is_legal
        jc      @f
        add     esp, 20
        popad
        mov     eax, ERROR_FILE_NOT_FOUND
        xor     ebx, ebx
        ret

    @@: sub     esp, 12
        mov     edi, esp
        call    fs.fat.gen_short_name

  .test_short_name_loop:
        push    esi edi ecx
        mov     esi, edi
        lea     eax, [esp + 12 + 12 + 8]
        mov     [eax], ebp
        call    dword[eax - 4]
        jc      .found

  .test_short_name_entry:
        cmp     byte[edi + 11], 0x0f
        jz      .test_short_name_cont
        mov     ecx, 11
        push    esi edi
        repz    cmpsb
        pop     edi esi
        jz      .short_name_found

  .test_short_name_cont:
        lea     eax, [esp + 12 + 12 + 8]
        call    dword[eax - 8]
        jnc     .test_short_name_entry
        jmp     .found

  .short_name_found:
        pop     ecx edi esi
        call    fs.fat.next_short_name
        jnc     .test_short_name_loop

  .disk_full:
        add     esp, 12 + 20
        popad
        mov     eax, ERROR_DISK_FULL
        xor     ebx, ebx
        ret

  .found:
        pop     ecx edi esi
        ; now find space in directory
        ; we need to save LFN <=> LFN is not equal to short name <=> generated name contains '~'
        mov     al, '~'
        push    ecx edi
        mov     ecx, 8
        repnz   scasb
        push    1
        pop     eax ; 1 entry
        jnz     .notilde
        ; we need ceil(strlen(esi)/13) additional entries = floor((strlen(esi)+12+13)/13) total
        xor     eax, eax

    @@: cmp     byte[esi], 0
        jz      @f
        inc     esi
        inc     eax
        jmp     @b

    @@: sub     esi, eax
        add     eax, 12 + 13
        mov     ecx, 13
        push    edx
        cdq
        div     ecx
        pop     edx

  .notilde:
        push    -1
        push    -1
        ; find <eax> successive entries in directory
        xor     ecx, ecx
        push    eax
        lea     eax, [esp + 12 + 8 + 12 + 8]
        mov     [eax], ebp
        call    dword[eax - 4]
        pop     eax

  .scan_dir:
        cmp     byte[edi], 0
        jz      .free
        cmp     byte[edi], 0xe5
        jz      .free
        xor     ecx, ecx

  .scan_cont:
        push    eax
        lea     eax, [esp + 12 + 8 + 12 + 8]
        call    dword[eax - 8]
        pop     eax
        jnc     .scan_dir
        push    eax
        lea     eax, [esp + 12 + 8 + 12 + 8]
        call    dword[eax + 8] ; extend directory
        pop     eax
        jnc     .scan_dir
        add     esp, 8 + 8 + 12 + 20
        popad
        mov     eax, ERROR_DISK_FULL
        xor     ebx, ebx
        ret

  .free:
        test    ecx, ecx
        jnz     @f
        mov     [esp], edi
        mov     ecx, [esp + 8 + 8 + 12 + 8]
        mov     [esp + 4], ecx
        xor     ecx, ecx

    @@: inc     ecx
        cmp     ecx, eax
        jb      .scan_cont
        ; found!
        ; calculate name checksum
        push    esi ecx
        mov     esi, [esp + 8 + 8]
        mov     ecx, 11
        xor     eax, eax

    @@: ror     al, 1
        add     al, [esi]
        inc     esi
        loop    @b
        pop     ecx esi
        pop     edi
        pop     dword[esp + 8 + 12 + 8]
        ; edi points to last entry in free chunk
        dec     ecx
        jz      .nolfn
        push    esi
        push    eax
        mov     al, 0x40

  .writelfn:
        or      al, cl
        mov     esi, [esp + 4]
        push    ecx
        dec     ecx
        imul    ecx, 13
        add     esi, ecx
        stosb
        mov     cl, 5
        call    fs.fat.read_symbols
        mov     ax, 0x0f
        stosw
        mov     al, [esp + 4]
        stosb
        mov     cl, 6
        call    fs.fat.read_symbols
        xor     eax, eax
        stosw
        mov     cl, 2
        call    fs.fat.read_symbols
        pop     ecx
        lea     eax, [esp + 8 + 8 + 12 + 8]
        call    dword[eax + 4] ; next write
        xor     eax, eax
        loop    .writelfn
        pop     eax
        pop     esi

  .nolfn:
        xchg    esi, [esp]
        mov     ecx, 11
        rep     movsb
        mov     word[edi], 0x20 ; attributes
        sub     edi, 11
        pop     esi ecx
        add     esp, 12
        mov     byte[edi + 13], 0 ; tenths of a second at file creation time
        call    fs.fat.get_time_for_file
        mov     [edi + 14], ax ; creation time
        mov     [edi + 22], ax ; last write time
        call    fs.fat.get_date_for_file
        mov     [edi + 16], ax ; creation date
        mov     [edi + 24], ax ; last write date
        mov     [edi + 18], ax ; last access date
        and     word[edi + 20], 0 ; high word of cluster
        and     word[edi + 26], 0 ; low word of cluster - to be filled
        and     dword[edi + 28], 0 ; file size - to be filled
        cmp     byte[esp + 20 + 28], 0
        jz      .doit
        ; create directory
        mov     byte[edi + 11], 0x10 ; attributes: folder
        mov     ecx, 32 * 2
        mov     edx, edi

  .doit:
        push    edx
        push    ecx
        push    edi
        add     edi, 26 ; edi points to low word of cluster
        push    edi
        jecxz   .done
        mov     ecx, 2849
        mov     edi, RAMDISK_FAT

  .write_loop:
        ; allocate new cluster
        xor     eax, eax
        repnz   scasw
        jnz     .disk_full2
        dec     edi
        dec     edi

;       lea     eax, [edi - RAMDISK_FAT]
        mov eax, edi
        sub eax, RAMDISK_FAT

        shr     eax, 1 ; eax = cluster
        mov     word[edi], 0x0fff ; mark as last cluster
        xchg    edi, [esp]
        stosw
        pop     edi
        push    edi
        inc     ecx
        ; write data
        cmp     byte[esp + 16 + 20 + 28], 0
        jnz     .writedir
        shl     eax, 9
        add     eax, RAMDISK + 31 * 512

  .writefile:
        mov     ebx, edx
        xchg    eax, ebx
        push    ecx
        mov     ecx, 512
        cmp     dword[esp + 12], ecx
        jae     @f
        mov     ecx, [esp + 12]

    @@: call    memmove
        add     edx, ecx
        sub     [esp + 12], ecx
        pop     ecx
        jnz     .write_loop

  .done:
        mov     ebx, edx
        pop     edi edi ecx edx
        sub     ebx, edx
        mov     [edi + 28], ebx
        add     esp, 20
        mov     [esp + 16], ebx
        popad
        xor     eax, eax
        ret

  .disk_full2:
        mov     ebx, edx
        pop     edi edi ecx edx
        sub     ebx, edx
        mov     [edi + 28], ebx
        add     esp, 20
        mov     [esp + 16], ebx
        popad
        push    ERROR_DISK_FULL
        pop     eax
        ret

  .writedir:
        mov     edi, eax
        shl     edi, 9
        add     edi, RAMDISK + 31 * 512
        mov     esi, edx
        mov     ecx, 32 / 4
        push    ecx
        rep     movsd
        mov     dword[edi - 32], '.   '
        mov     dword[edi - 32 + 4], '    '
        mov     dword[edi - 32 + 8], '    '
        mov     byte[edi - 32 + 11], 0x10
        mov     word[edi - 32 + 26], ax
        mov     esi, edx
        pop     ecx
        rep     movsd
        mov     dword[edi - 32], '..  '
        mov     dword[edi - 32 + 4], '    '
        mov     dword[edi - 32 + 8], '    '
        mov     byte[edi - 32 + 11], 0x10
        mov     eax, [esp + 16 + 8]
        mov     word[edi - 32 + 26], ax
        xor     eax, eax
        mov     ecx, (512 - 32 * 2) / 4
        rep     stosd
        pop     edi edi ecx edx
        add     esp, 20
        popad
        xor     eax, eax
        xor     ebx, ebx
        ret
kendp

    @@: push    ERROR_ACCESS_DENIED

fs_RamdiskWrite.ret0:
        pop     eax
        xor     ebx, ebx
        ret

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskWrite ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? LFN variant for writing to sys floppy
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to 64-bit number = first wanted byte, 0+
;> ecx = number of bytes to write, 0+
;> edx = mem location to data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = bytes written (maybe 0)
;-----------------------------------------------------------------------------------------------------------------------
;# if ebx = 0, start from first byte
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jz      @b
        pushad
        call    rd_find_lfn
        jnc     .found
        popad
        push    ERROR_FILE_NOT_FOUND
        jmp     .ret0

  .found:
        ; must not be directory
        test    byte[edi + 11], 0x10
        jz      @f
        popad
        push    ERROR_ACCESS_DENIED
        jmp     .ret0

        ; FAT does not support files larger than 4GB
    @@: test    ebx, ebx
        jz      .l1
        cmp     dword[ebx + 4], 0
        jz      @f

  .eof:
        popad
        push    ERROR_END_OF_FILE
        jmp     .ret0

    @@: mov     ebx, [ebx]

  .l1:
        ; now edi points to direntry, ebx=start byte to write,
        ; ecx=number of bytes to write, edx=data pointer
        call    fs.fat.update_datetime

        ; extend file if needed
        add     ecx, ebx
        jc      .eof ; FAT does not support files larger than 4GB
        push    0 ; return value=0
        cmp     ecx, [edi + 28]
        jbe     .length_ok
        cmp     ecx, ebx
        jz      .length_ok
        call    ramdisk_extend_file
        jnc     .length_ok
        ; ramdisk_extend_file can return two error codes: FAT table error or disk full.
        ; First case is fatal error, in second case we may write some data
        mov     [esp], eax
        cmp     al, ERROR_DISK_FULL
        jz      .disk_full
        pop     eax
        mov     [esp + 28], eax
        popad
        xor     ebx, ebx
        ret

  .disk_full:
        ; correct number of bytes to write
        mov     ecx, [edi + 28]
        cmp     ecx, ebx
        ja      .length_ok

  .ret:
        pop     eax
        mov     [esp + 28], eax ; eax=return value
        sub     edx, [esp + 20]
        mov     [esp + 16], edx ; ebx=number of written bytes
        popad
        ret

  .length_ok:
        ; now ebx=start pos, ecx=end pos, both lie inside file
        sub     ecx, ebx
        jz      .ret
        movzx   edi, word[edi + 26]     ; starting cluster

  .write_loop:
        sub     ebx, 0x200
        jae     .next_cluster
        push    ecx
        neg     ebx
        cmp     ecx, ebx
        jbe     @f
        mov     ecx, ebx

    @@: mov     eax, edi
        shl     eax, 9
        add     eax, RAMDISK + 31 * 512 + 0x200
        sub     eax, ebx
        mov     ebx, eax
        mov     eax, edx
        call    memmove
        xor     ebx, ebx
        add     edx, ecx
        sub     [esp], ecx
        pop     ecx
        jz      .ret

  .next_cluster:
        movzx   edi, word[edi * 2 + RAMDISK_FAT]
        jmp     .write_loop
kendp

ramdisk_extend_file.zero_size:
        xor     eax, eax
        jmp     ramdisk_extend_file.start_extend

;-----------------------------------------------------------------------------------------------------------------------
kproc ramdisk_extend_file ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? extends file on ramdisk to given size, new data area is filled by 0
;-----------------------------------------------------------------------------------------------------------------------
;> edi = direntry
;> ecx = new size
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 0 (ok) or 1 (error)
;< eax = 0 (ok) or error code (ERROR_FAT_TABLE or ERROR_DISK_FULL)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        ; find the last cluster of file
        movzx   eax, word[edi + 26] ; first cluster
        mov     ecx, [edi + 28]
        jecxz   .zero_size

    @@: sub     ecx, 0x200
        jbe     @f
        mov     eax, [eax * 2 + RAMDISK_FAT]
        and     eax, 0x0fff
        jz      .fat_err
        cmp     eax, 0x0ff8
        jb      @b

  .fat_err:
        pop     ecx
        push    ERROR_FAT_TABLE
        pop     eax
        stc
        ret

    @@: push    eax
        mov     eax, [eax * 2 + RAMDISK_FAT]
        and     eax, 0x0fff
        cmp     eax, 0x0ff8
        pop     eax
        jb      .fat_err
        ; set length to full number of sectors and make sure that last sector is zero-padded
        sub     [edi + 28], ecx
        push    eax edi
        mov     edi, eax
        shl     edi, 9
        lea     edi, [edi + RAMDISK + 31 * 512 + 0x200 + ecx]
        neg     ecx
        xor     eax, eax
        rep     stosb
        pop     edi eax

  .start_extend:
        pop     ecx
        ; now do extend
        push    edx esi
        mov     esi, RAMDISK_FAT + 2 * 2 ; start scan from cluster 2
        mov     edx, 2847 ; number of clusters to scan

  .extend_loop:
        cmp     [edi + 28], ecx
        jae     .extend_done
        ; add new sector
        push    ecx
        mov     ecx, edx
        push    edi
        mov     edi, esi
        jecxz   .disk_full
        push    eax
        xor     eax, eax
        repnz   scasw
        pop     eax
        jnz     .disk_full
        mov     word[edi - 2], 0x0fff
        mov     esi, edi
        mov     edx, ecx
        sub     edi, RAMDISK_FAT
        shr     edi, 1
        dec     edi ; now edi=new cluster
        test    eax, eax
        jz      .first_cluster
        mov     [RAMDISK_FAT + eax * 2], di
        jmp     @f

  .first_cluster:
        pop     eax ; eax->direntry
        push    eax
        mov     [eax + 26], di

    @@: push    edi
        shl     edi, 9
        add     edi, RAMDISK + 31 * 512
        xor     eax, eax
        mov     ecx, 512 / 4
        rep     stosd
        pop     eax ; eax=new cluster
        pop     edi ; edi->direntry
        pop     ecx ; ecx=required size
        add     dword[edi + 28], 0x200
        jmp     .extend_loop

  .extend_done:
        mov     [edi + 28], ecx
        pop     esi edx
        xor     eax, eax ; CF=0
        ret

  .disk_full:
        pop     edi ecx
        pop     esi edx
        stc
        push    ERROR_DISK_FULL
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskSetFileEnd ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? set end of file on ramdisk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = points to 64-bit number = new file size
;> ecx = ignored (reserved)
;> edx = ignored (reserved)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f

  .access_denied:
        push    ERROR_ACCESS_DENIED
        jmp     .ret

    @@: push    edi
        call    rd_find_lfn
        jnc     @f
        pop     edi
        push    ERROR_FILE_NOT_FOUND

  .ret:
        pop     eax
        ret

    @@: ; must not be directory
        test    byte[edi + 11], 0x10
        jz      @f
        pop     edi
        jmp     .access_denied

    @@: ; file size must not exceed 4Gb
        cmp     dword[ebx + 4], 0
        jz      @f
        pop     edi
        push    ERROR_END_OF_FILE
        jmp     .ret

    @@: ; set file modification date/time to current
        call    fs.fat.update_datetime
        mov     eax, [ebx]
        cmp     eax, [edi + 28]
        jb      .truncate
        ja      .expand
        pop     edi
        xor     eax, eax
        ret

  .expand:
        push    ecx
        mov     ecx, eax
        call    ramdisk_extend_file
        pop     ecx
        pop     edi
        ret

  .truncate:
        mov     [edi + 28], eax
        push    ecx
        movzx   ecx, word[edi + 26]
        test    eax, eax
        jz      .zero_size

    @@: ; find new last sector
        sub     eax, 0x200
        jbe     @f
        movzx   ecx, word[RAMDISK_FAT + ecx * 2]
        jmp     @b

    @@: ; zero data at the end of last sector
        push    ecx
        mov     edi, ecx
        shl     edi, 9
        lea     edi, [edi + RAMDISK + 31 * 512 + eax + 0x200]
        mov     ecx, eax
        neg     ecx
        xor     eax, eax
        rep     stosb
        pop     ecx
        ; terminate FAT chain
        lea     ecx, [RAMDISK_FAT + ecx + ecx]
        push    dword[ecx]
        mov     word[ecx], 0x0fff
        pop     ecx
        and     ecx, 0x0fff
        jmp     .delete

  .zero_size:
        and     word[edi + 26], 0

  .delete:
        ; delete FAT chain starting with ecx
        ; mark all clusters as free
        cmp     ecx, 0x0ff8
        jae     .deleted
        lea     ecx, [RAMDISK_FAT + ecx + ecx]
        push    dword[ecx]
        and     word[ecx], 0
        pop     ecx
        and     ecx, 0x0fff
        jmp     .delete

  .deleted:
        pop     ecx
        pop     edi
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskGetFileInfo ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f
        mov     eax, 2 ; unsupported
        ret

    @@: push    edi
        call    rd_find_lfn

  .finish:
        jnc     @f
        pop     edi
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

    @@: push    esi ebp
        xor     ebp, ebp
        mov     esi, edx
        and     dword[esi + 4], 0
        call    fs.fat.fat_entry_to_bdfe.direct
        pop     ebp esi
        pop     edi
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskSetFileInfo ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f
        mov     eax, 2 ; unsupported
        ret

    @@: push    edi
        call    rd_find_lfn
        jnc     @f
        pop     edi
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

    @@: call    fs.fat.bdfe_to_fat_entry
        pop     edi
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_RamdiskDelete ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;?- delete file or empty folder from ramdisk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f
        ; cannot delete root!

  .access_denied:
        push    ERROR_ACCESS_DENIED

  .pop_ret:
        pop     eax
        ret

    @@: and     [rd_prev_sector], 0
        and     [rd_prev_prev_sector], 0
        push    edi
        call    rd_find_lfn
        jnc     .found
        pop     edi
        push    ERROR_FILE_NOT_FOUND
        jmp     .pop_ret

  .found:
        cmp     dword[edi], '.   '
        jz      .access_denied2
        cmp     dword[edi], '..  '
        jz      .access_denied2
        test    byte[edi + 11], 0x10
        jz      .dodel
        ; we can delete only empty folders!
        movzx   eax, word[edi + 26]
        push    ebx
        mov     ebx, eax
        shl     ebx, 9
        add     ebx, RAMDISK + 31 * 0x200 + 2 * 0x20

  .checkempty:
        cmp     byte[ebx], 0
        jz      .empty
        cmp     byte[ebx], 0xe5
        jnz     .notempty
        add     ebx, 0x20
        test    ebx, 0x1ff
        jnz     .checkempty
        movzx   eax, word[RAMDISK_FAT + eax * 2]
        test    eax, eax
        jz      .empty
        mov     ebx, eax
        shl     ebx, 9
        add     ebx, RAMDISK + 31 * 0x200
        jmp     .checkempty

  .notempty:
        pop     ebx

  .access_denied2:
        pop     edi
        jmp     .access_denied

  .empty:
        pop     ebx

  .dodel:
        movzx   eax, word[edi + 26]
        ; delete folder entry
        mov     byte[edi], 0xe5

  .lfndel:
        ; delete LFN (if present)
        test    edi, 0x1ff
        jnz     @f
        cmp     [rd_prev_sector], 0
        jz      @f
        cmp     [rd_prev_sector], -1
        jz      .lfndone
        mov     edi, [rd_prev_sector]
        push    [rd_prev_prev_sector]
        pop     [rd_prev_sector]
        or      [rd_prev_prev_sector], -1
        shl     edi, 9
        add     edi, RAMDISK + 31 * 0x200 + 0x200

    @@: sub     edi, 0x20
        cmp     byte[edi], 0xe5
        jz      .lfndone
        cmp     byte[edi + 11], 0x0f
        jnz     .lfndone
        mov     byte[edi], 0xe5
        jmp     .lfndel

  .lfndone:
        ; delete FAT chain
        test    eax, eax
        jz      .done
        lea     eax, [RAMDISK_FAT + eax * 2]
        push    dword[eax]
        and     word[eax], 0
        pop     eax
        and     eax, 0x0fff
        jmp     .lfndone

  .done:
        pop     edi
        xor     eax, eax
        ret
kendp
