;;======================================================================================================================
;;///// blkdev.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.read ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of blocks to read)
;> edx:eax #= offset (in blocks)
;> ebx ^= blkdev.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx esi

        mov     esi, [ebx + blkdev.device_t.vftbl]
        mov     ebx, [ebx + blkdev.device_t.user_data]
        call    [esi + blkdev.vftbl_t.read]

        pop     esi ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev.write ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of blocks to write)
;> edx:eax #= offset (in blocks)
;> ebx ^= blkdev.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx edi

        mov     edi, [ebx + blkdev.device_t.vftbl]
        mov     ebx, [ebx + blkdev.device_t.user_data]
        call    [edi + blkdev.vftbl_t.write]

        pop     edi ebx
        ret
kendp
