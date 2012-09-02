;;======================================================================================================================
;;///// math.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
kproc util.64bit.mul_div ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edx:eax = number
;> ecx = multiplier
;> esi = divider
;-----------------------------------------------------------------------------------------------------------------------
;> edx:eax = result
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        mul     ecx
        xchg    eax, [esp]
        push    edx
        mul     ecx
        add     edx, [esp]
        add     esp, 4

        xor     eax, eax
        xchg    eax, edx
        div     esi
        xchg    eax, [esp]
        div     esi
        pop     edx

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc util.64bit.compare ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edx:eax #= first number
;> [esp + 8]:[esp + 4] #= second number
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edx, [esp + 8]
        jne     @f

        cmp     eax, [esp + 4]

    @@: ret     8
kendp
