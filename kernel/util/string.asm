;;======================================================================================================================
;;///// string.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011-2012 Ostin project <http://ostin.googlecode.com/>
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
kproc util.string.length ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= string
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= length
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx esi
        xor     ecx, ecx
        xchg    eax, esi

    @@: lodsd

        test    al, al
        jz      .exit
        test    ah, ah
        jz      .add_1
        shr     eax, 16
        test    al, al
        jz      .add_2
        test    ah, ah
        jz      .add_3

        add     ecx, 4
        jmp     @b

  .add_3:
        inc     ecx

  .add_2:
        inc     ecx

  .add_1:
        inc     ecx

  .exit:
        xchg    eax, ecx
        pop     esi ecx
        ret
kendp
