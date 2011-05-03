;;======================================================================================================================
;;///// biosdisk.inc /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2008-2010 KolibriOS team <http://kolibrios.org/>
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

; Detect all BIOS hard drives.
; diamond, 2008

        xor     cx, cx
        mov     es, cx
        mov     di, 0x9080
        mov     byte [es:di-1], cl
        cmp     [preboot_biosdisk], 1
        jnz     bdde
        mov     dl, 80h
bdds:
        mov     ah, 15h
        push    cx dx di
        int     13h
        pop     di dx cx
        jc      bddc
        test    ah, ah
        jz      bddc
        inc     cx
        mov     ah, 48h
        push    ds
        push    es
        pop     ds
        mov     si, 0xA000
        mov     word [si], 1Eh
        mov     ah, 48h
        int     13h
        pop     ds
        jc      bddc2
        inc     byte [es:0x907F]
        cmp     word [es:si], 1Eh
        jb      bddl
        cmp     word [es:si+1Ah], 0xFFFF
        jz      bddl
        mov     al, dl
        stosb
        push    ds
        lds     si, [es:si+1Ah]
        mov     al, [si+6]
        and     al, 0xF
        stosb
        mov     al, byte [si+4]
        shr     al, 4
        and     ax, 1
        cmp     word [si], 1F0h
        jz      @f
        inc     ax
        inc     ax
        cmp     word [si], 170h
        jz      @f
	or	ax,-1
;        mov     ax, -1
@@:
        stosw
        pop     ds
        jmp     bddc2
bddl:
        mov     al, dl
        stosb
	xor	ax,ax
	stosb
	dec	ax
	stosw
;        mov     al, 0
;        stosb
;        mov     ax, -1
;        stosw
bddc2:
        cmp     cl, [es:0x475]
        jae     bdde
bddc:
        inc     dl
        jnz     bdds
bdde:
