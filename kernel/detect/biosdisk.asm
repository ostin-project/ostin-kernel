;;======================================================================================================================
;;///// biosdisk.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
;? Detect all BIOS hard drives.
;;======================================================================================================================

        xor     cx, cx
        mov     es, cx
        mov     di, boot_var.low.bios_disks
        mov     byte[es:di - 1], cl
        cmp     [boot.params.use_bios_disks], 1
        jnz     bdde
        mov     dl, 0x80

bdds:
        mov     ah, 0x15
        push    cx dx di
        int     0x13
        pop     di dx cx
        jc      bddc
        test    ah, ah
        jz      bddc
        inc     cx
        mov     ah, 0x48
        push    ds
        mov_s_  ds, es
        mov     si, 0xa000
        mov     word[si], 0x1e
        mov     ah, 0x48
        int     0x13
        pop     ds
        jc      bddc2
        inc     [es:boot_var.low.bios_disks_cnt]
        cmp     word[es:si], 0x1e
        jb      bddl
        cmp     word[es:si + 0x1a], 0xffff
        jz      bddl
        mov     al, dl
        stosb
        push    ds
        lds     si, [es:si + 0x1a]
        mov     al, [si + 6]
        and     al, 0x0f
        stosb
        mov     al, byte[si + 4]
        shr     al, 4
        and     ax, 1
        cmp     word[si], 0x1f0
        jz      @f
        inc     ax
        inc     ax
        cmp     word[si], 0x170
        jz      @f
        or      ax, -1
;       mov     ax, -1

    @@: stosw
        pop     ds
        jmp     bddc2

bddl:
        mov     al, dl
        stosb
        xor     ax, ax
        stosb
        dec     ax
        stosw
;       mov     al, 0
;       stosb
;       mov     ax, -1
;       stosw

bddc2:
        cmp     cl, [es:0x475]
        jae     bdde

bddc:
        inc     dl
        jnz     bdds

bdde:
