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

if defined COMPATIBILITY_MENUET_SYSFN58

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

  .rdfs1:
        repne
        scasw
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

end if ; COMPATIBILITY_MENUET_SYSFN58

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
        ja      fs.error.file_not_found
        cmp     ecx, 14
        ja      fs.error.file_not_found

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
        rep
        movsd
        popf
        pop     edx
        jae     .fr_do2
        xor     eax, eax ; ok read
        xor     ebx, ebx
        ret

  .fr_do2: ; if last cluster
        mov     eax, ERROR_END_OF_FILE ; end of file
        xor     ebx, ebx
        ret

  .fr_noroot:
        sub     esp, 32
        call    fs.fat12.expand_filename

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
        mov     eax, ERROR_END_OF_FILE ; end of file
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

  .rd_newsearch:
        mov     esi, eax
        mov     ecx, 11
        rep
        cmpsb
        je      .rd_ff
        add     cl, 21
        add     edi, ecx
        cmp     edi, RAMDISK + 512 * 33
        jb      .rd_newsearch
        mov     eax, ERROR_FILE_NOT_FOUND ; if file not found - eax=5
        xor     ebx, ebx
        dec     ebx ; ebx=0xffffffff and zf=0

  .rd_ff:
        ret
kendp
