;;======================================================================================================================
;;///// fs.asm ///////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
;; (c) 2000-2004 MenuetOS <http://menuetos.net/>
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

uglobal
  align 4
  hd_entries       rd 1 ; unused? 1 write, 0 reads
  lba_read_enabled rd 1 ; 0 = disabled , 1 = enabled
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.create_from_base ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (original)
;> eax #= new size (>= sizeof.fs.partition_t)
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= fs.partition_t (copy)
;-----------------------------------------------------------------------------------------------------------------------
        call    malloc
        test    eax, eax
        jz      .exit

        push    eax ebx ecx

        xchg    eax, ebx
        mov     ecx, sizeof.fs.partition_t
        call    memmove

        lea     ecx, [ebx + fs.partition_t._.mutex]
        call    mutex_init

        pop     ecx ebx eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.lock ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx
        lea     ecx, [ebx + fs.partition_t._.mutex]
        call    mutex_lock
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.unlock ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx
        lea     ecx, [ebx + fs.partition_t._.mutex]
        call    mutex_unlock
        pop     edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.read ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of blocks to read)
;> edx:eax #= offset (in blocks)
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx
        add     eax, ecx
        adc     edx, 0
        push    dword[ebx + fs.partition_t._.range.length + 4]
        push    dword[ebx + fs.partition_t._.range.length]
        call    util.64bit.compare
        pop     edx eax
        ja      .overflow_error

        push    ebx edx
        add     eax, dword[ebx + fs.partition_t._.range.offset]
        adc     edx, dword[ebx + fs.partition_t._.range.offset + 4]
        mov     ebx, [ebx + fs.partition_t._.device]
        call    blk.read
        pop     edx ebx

        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.write ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of blocks to write)
;> edx:eax #= offset (in blocks)
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx
        add     eax, ecx
        adc     edx, 0
        push    dword[ebx + fs.partition_t._.range.length + 4]
        push    dword[ebx + fs.partition_t._.range.length]
        call    util.64bit.compare
        pop     edx eax
        ja      .overflow_error

        push    ebx edx
        add     eax, dword[ebx + fs.partition_t._.range.offset]
        adc     edx, dword[ebx + fs.partition_t._.range.offset + 4]
        mov     ebx, [ebx + fs.partition_t._.device]
        call    blk.write
        pop     edx ebx

        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.flush_floppy_cache ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 16: save ramdisk to floppy
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_ERROR, "FIXME: not implemented: sysfn.flush_floppy_cache\n"
        mov     eax, ERROR_NOT_IMPLEMENTED
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc choice_necessity_partition_1 ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [hdpos]
        xor     eax, eax
        mov     [hd_entries], eax ; entries in hd cache
        mov     edx, DRIVE_DATA + 2
        cmp     ecx, 0x80
        jb      .search_partition_array
        mov     ecx, 4

  .search_partition_array:
        mov     bl, [edx]
        movzx   ebx, bl
        add     eax, ebx
        inc     edx
        loop    .search_partition_array
        mov     ecx, [hdpos]
        mov     edx, BiosDiskPartitions
        sub     ecx, 0x80
        jb      .s
        je      .f

    @@: mov     ebx, [edx]
        add     edx, 4
        add     eax, ebx
        loop    @b
        jmp     .f

  .s:
        sub     eax, ebx

  .f:
        add     eax, [known_part]
        dec     eax
        xor     edx, edx
        imul    eax, 100
        add     eax, DRIVE_DATA + 0x0a
        mov     [transfer_address], eax
        call    partition_data_transfer_1
        ret
kendp

iglobal
  partition_string:
    dd 0
    db 32
endg
