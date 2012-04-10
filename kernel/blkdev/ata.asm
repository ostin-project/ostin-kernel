;;======================================================================================================================
;;///// ata.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

struct blk.ata.device_t blk.device_t
  ctl          dd ? ; ^= blk.ata.ctl.device_t
  drive_number db ?
  ident        rb 512
ends

iglobal
  blk.ata.last_index  dd 0
  blk.ata.name_prefix db 'ata', 0

  jump_table blk.ata, vftbl, blk.not_implemented, \
    destroy, \
    read, \
    write
endg

include "ata_ctl.asm"

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.create ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Create ATA device.
;-----------------------------------------------------------------------------------------------------------------------
;> eax ^= blk.ata.ctl.device_t
;> cl #= drive number
;> edx ^= ident buffer
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= blk.ata.device_t (0 on error)
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    eax ecx edx

        mov     eax, sizeof.blk.ata.device_t
        call    malloc
        test    eax, eax
        jz      .exit

        xchg    eax, ebx

        mov     [ebx + blk.ata.device_t._.vftbl], blk.ata.vftbl

        mov     eax, [esp + 8]
        mov     [ebx + blk.ata.device_t.ctl], eax
        mov     al, [esp + 4]
        mov     [eax + blk.ata.device_t.drive_number], al

        mov     esi, [esp]
        lea     edi, [ebx + blk.ata.device_t.ident]
        mov     ecx, 512 / 4
        rep
        movsd

        mov     eax, blk.ata.name_prefix
        mov     ecx, [blk.ata.last_index]
        call    blk.set_device_name

        inc     [blk.ata.last_index]

        ; --------------------------------------------------------------------------------------------------------------
        pushad
        xor     eax, eax
        cdq
        mov     edi, Sector512
        mov     ecx, 1
        call    blk.ata.read
        test    eax, eax
        jnz     @f

        mov     ecx, 32
        mov     edi, Sector512

        klog_   LOG_DEBUG, "-------------------------------------\n"

  .next_line:
        klog_   LOG_DEBUG, "%x%x%x%x %x%x%x%x - %x%x%x%x %x%x%x%x\n", [edi]:2, [edi + 1]:2, [edi + 2]:2, [edi + 3]:2, \
                [edi + 4]:2, [edi + 5]:2, [edi + 6]:2, [edi + 7]:2, [edi + 8]:2, [edi + 9]:2, [edi + 10]:2, \
                [edi + 11]:2, [edi + 12]:2, [edi + 13]:2, [edi + 14]:2, [edi + 15]:2
        add     edi, 16
        dec     ecx
        jnz    .next_line

        klog_   LOG_DEBUG, "-------------------------------------\n"

    @@: popad
        ; --------------------------------------------------------------------------------------------------------------

        xchg    eax, ebx

  .exit:
        add     esp, 12
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.destroy ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Destroy ATA device.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.ata.device_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, ebx
        call    free
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.read ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read from ATA device.
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of blocks to read)
;> edx:eax #= offset (in blocks)
;> ebx ^= blk.ata.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        ; TODO: sanity checks, PIO/DMA mode selection
        push    ebx
        mov     ebx, [ebx + blk.ata.device_t.ctl]
        call    blk.ata.ctl.read_pio
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blk.ata.write ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write to ATA device.
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of blocks to write)
;> edx:eax #= offset (in blocks)
;> ebx ^= blk.ata.device_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_NOT_IMPLEMENTED
        ret
kendp
