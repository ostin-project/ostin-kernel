;;======================================================================================================================
;;///// ide_cache.asm ////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
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

;**************************************************************************
;
;   [cache_ideX.pointer]
;   or [cache_ideX.data_pointer]  first entry in cache list
;
;            +0   - lba sector
;            +4   - state of cache sector
;                   0 = empty
;                   1 = used for read  ( same as in hd )
;                   2 = used for write ( differs from hd )
;
;  [cache_ideX.system_data]
;  or [cache_ideX.appl_data] - cache entries
;
;**************************************************************************

cache_max equ 1919 ; max. is 1919*512+0x610000=0x6ffe00

uglobal
  align 4
  cache_search_start dd 0 ; used by find_empty_slot
  ide_drives_cache:
    .0 drive_cache_t
    .1 drive_cache_t
    .2 drive_cache_t
    .3 drive_cache_t
  BiosDiskCaches     rb 0x80 * sizeof.drive_cache_t
  BiosDisksData      rb 0x200
  hdd_appl_data      rb 1 ; 0 = system cache, 1 - application cache
  cd_appl_data       rb 1 ; 0 = system cache, 1 - application cache
endg

iglobal
  align 4
  fat_in_cache       dd -1
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc write_cache ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? write all changed sectors to disk
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx esi edi

        ; write difference ( 2 ) from cache to hd
        call    calculate_cache
        add     esi, 8
        mov     edi, 1

  .write_cache_more:
        cmp     dword[esi + 4], 2 ; if cache slot is not different
        jne     .write_chain
        mov     dword[esi + 4], 1 ; same as in hd
        mov     eax, [esi] ; eax = sector to write
        cmp     eax, [PARTITION_START]
        jb      .danger
        cmp     eax, [PARTITION_END]
        ja      .danger
        cmp     [hdpos], 0x80
        jae     @f
        ; DMA write is permitted only if [allow_dma_access]=1
        cmp     [allow_dma_access], 2
        jae     .nodma
        cmp     [dma_hdd], 1
        jnz     .nodma

    @@: ; combining consecutive sectors write into one disk operation
        cmp     ecx, 1
        jz      .nonext
        cmp     dword[esi + 8 + 4], 2
        jnz     .nonext
        push    eax
        inc     eax
        cmp     eax, [esi + 8]
        pop     eax
        jnz     .nonext
        cmp     [cache_chain_started], 1
        jz      @f
        mov     [cache_chain_started], 1
        mov     [cache_chain_size], 0
        mov     [cache_chain_pos], edi
        mov     [cache_chain_ptr], esi

    @@: inc     [cache_chain_size]
        cmp     [cache_chain_size], 16
        jnz     .continue
        jmp     .write_chain

  .nonext:
        call    .flush_cache_chain
        mov     [cache_chain_size], 1
        mov     [cache_chain_ptr], esi
        call    write_cache_sector
        jmp     .continue

  .nodma:
        call    cache_write_pio

  .write_chain:
        call    .flush_cache_chain

  .continue:
  .danger:
        add     esi, 8
        inc     edi
        dec     ecx
        jnz     .write_cache_more
        call    .flush_cache_chain

  .return_02:
        pop     edi esi edx ecx eax
        ret

  .flush_cache_chain:
        cmp     [cache_chain_started], 0
        jz      @f
        call    write_cache_chain
        mov     [cache_chain_started], 0

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc find_empty_slot ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? find empty or read slot, flush cache if next 10% is used by write
;-----------------------------------------------------------------------------------------------------------------------
;< edi = cache slot
;-----------------------------------------------------------------------------------------------------------------------
;       push    ecx esi

  .search_again:
        call    calculate_cache_3
        shr     ecx, 3

  .search_for_empty:
        inc     edi
        call    calculate_cache_4
        jbe     .inside_cache
        mov     edi, 1

  .inside_cache:
        push    esi
        call    calculate_cache_1
        cmp     dword[edi * 8 + esi + 4], 2
        pop     esi
        jb      .found_slot ; it's empty or read
        dec     ecx
        jnz     .search_for_empty
        call    write_cache ; no empty slots found, write all
        cmp     [hd_error], 0
        jne     .found_slot_access_denied
        jmp     .search_again ; and start again

  .found_slot:
        call    calculate_cache_5

  .found_slot_access_denied:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc clear_hd_cache ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [fat_in_cache], -1
        mov     [fat_change], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_cache ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, [hdpos]
        dec     esi
        cmp     esi, 4
        jae     .not_ide

        imul    esi, sizeof.drive_cache_t
        add     esi, ide_drives_cache

        cmp     [hdd_appl_data], 0
        jne     .ide_app_data

        mov     ecx, [esi + drive_cache_t.sys_sad_size]
        mov     esi, [esi + drive_cache_t.ptr]
        ret

  .ide_app_data:
        mov     ecx, [esi + drive_cache_t.app_sad_size]
        mov     esi, [esi + drive_cache_t.data_ptr]
        ret

  .not_ide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache
        jmp     .get

    @@: imul    eax, sizeof.drive_cache_t
        add     eax, BiosDiskCaches

  .get:
        cmp     [hdd_appl_data], 0
        jne     .bd_appl_data
        mov     ecx, [eax + drive_cache_t.sys_sad_size]
        mov     esi, [eax + drive_cache_t.ptr]
        pop     eax
        ret

  .bd_appl_data:
        mov     ecx, [eax + drive_cache_t.app_sad_size]
        mov     esi, [eax + drive_cache_t.data_ptr]
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_cache_1 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, [hdpos]
        dec     esi
        cmp     esi, 4
        jae     .not_ide

        imul    esi, sizeof.drive_cache_t
        add     esi, ide_drives_cache

        cmp     [hdd_appl_data], 0
        jne     .ide_app_data

        mov     esi, [esi + drive_cache_t.ptr]
        ret

  .ide_app_data:
        mov     esi, [esi + drive_cache_t.data_ptr]
        ret

  .not_ide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache
        jmp     .get

    @@: imul    eax, sizeof.drive_cache_t
        add     eax, BiosDiskCaches

  .get:
        cmp     [hdd_appl_data], 0
        jne     .bd_appl_data
        mov     esi, [eax + drive_cache_t.ptr]
        pop     eax
        ret

  .bd_appl_data:
        mov     esi, [eax + drive_cache_t.data_ptr]
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_cache_2 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [hdpos]
        dec     eax
        cmp     eax, 4
        jae     .not_ide

        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache

        cmp     [hdd_appl_data], 0
        jne     .ide_app_data

        mov     eax, [eax + drive_cache_t.sys_data]
        ret

  .ide_app_data:
        mov     eax, [eax + drive_cache_t.app_data]
        ret

  .not_ide:
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache
        jmp     .get

    @@: imul    eax, sizeof.drive_cache_t
        add     eax, BiosDiskCaches

  .get:
        cmp     [hdd_appl_data], 0
        jne     .bd_appl_data
        mov     eax, [eax + drive_cache_t.sys_data]
        ret

  .bd_appl_data:
        mov     eax, [eax + drive_cache_t.app_data]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_cache_3 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [hdpos]
        dec     edi
        cmp     edi, 4
        jae     .not_ide

        imul    edi, sizeof.drive_cache_t
        add     edi, ide_drives_cache

        cmp     [hdd_appl_data], 0
        jne     .ide_app_data

        mov     ecx, [edi + drive_cache_t.sys_sad_size]
        mov     edi, [edi + drive_cache_t.sys_search_start]
        ret

  .ide_app_data:
        mov     ecx, [edi + drive_cache_t.app_sad_size]
        mov     edi, [edi + drive_cache_t.app_search_start]
        ret

  .not_ide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache
        jmp     .get

    @@: imul    eax, sizeof.drive_cache_t
        add     eax, BiosDiskCaches

  .get:
        cmp     [hdd_appl_data], 0
        jne     .bd_appl_data
        mov     ecx, [eax + drive_cache_t.sys_sad_size]
        mov     edi, [eax + drive_cache_t.sys_search_start]
        pop     eax
        ret

  .bd_appl_data:
        mov     ecx, [eax + drive_cache_t.app_sad_size]
        mov     edi, [eax + drive_cache_t.app_search_start]
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_cache_4 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [hdpos]
        dec     edi
        cmp     edi, 4
        jae     .not_ide

        imul    edi, sizeof.drive_cache_t
        add     edi, ide_drives_cache

        cmp     [hdd_appl_data], 0
        jne     .ide_app_data

        cmp     edi, [edi + drive_cache_t.sys_sad_size]
        ret

  .ide_app_data:
        cmp     edi, [edi + drive_cache_t.app_sad_size]
        ret

  .not_ide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache
        jmp     .get

    @@: imul    eax, sizeof.drive_cache_t
        add     eax, BiosDiskCaches

  .get:
        cmp     [hdd_appl_data], 0
        jne     .bd_appl_data
        cmp     edi, [eax + drive_cache_t.sys_sad_size]
        pop     eax
        ret

  .bd_appl_data:
        cmp     edi, [eax + drive_cache_t.app_sad_size]
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_cache_5 ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        mov     eax, [hdpos]
        dec     eax
        cmp     eax, 4
        jae     .not_ide

        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache

        cmp     [hdd_appl_data], 0
        jne     .ide_app_data

        mov     [eax + drive_cache_t.sys_search_start], edi
        pop     eax
        ret

  .ide_app_data:
        mov     [eax + drive_cache_t.app_search_start], edi
        pop     eax
        ret

  .not_ide:
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache
        jmp     .get

    @@: imul    eax, sizeof.drive_cache_t
        add     eax, BiosDiskCaches

  .get:
        cmp     [hdd_appl_data], 0
        jne     .bd_appl_data
        mov     [eax + drive_cache_t.sys_search_start], edi
        pop     eax
        ret

  .bd_appl_data:
        mov     [eax + drive_cache_t.app_search_start], edi
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc find_empty_slot_CD_cache ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? find empty or read slot, flush cache if next 10% is used by write
;-----------------------------------------------------------------------------------------------------------------------
;< edi = cache slot
;-----------------------------------------------------------------------------------------------------------------------
  .search_again:
        call    cd_calculate_cache_3

  .search_for_empty:
        inc     edi
        call    cd_calculate_cache_4
        jbe     .inside_cache
        mov     edi, 1

  .inside_cache:
        call    cd_calculate_cache_5
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc clear_CD_cache ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha

        mov     esi, [cdpos]
        dec     esi
        cmp     esi, 4
        jae     .exit

        imul    esi, sizeof.drive_cache_t
        add     esi, ide_drives_cache
        xor     eax, eax

        mov     [esi + drive_cache_t.sys_search_start], eax
        mov     ecx, [esi + drive_cache_t.sys_sad_size]
        mov     edi, [esi + drive_cache_t.ptr]
        call    .clear

        mov     [esi + drive_cache_t.app_search_start], eax
        mov     ecx, [esi + drive_cache_t.app_sad_size]
        mov     edi, [esi + drive_cache_t.data_ptr]
        call    .clear

  .exit:
        popa
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .clear: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        shl     ecx, 1
        rep
        stosd
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_calculate_cache ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, [cdpos]
        dec     esi
        cmp     esi, 4
        jae     .exit

        imul    esi, sizeof.drive_cache_t
        add     esi, ide_drives_cache

        cmp     [cd_appl_data], 0
        jne     .ide_app_data

        mov     ecx, [esi + drive_cache_t.sys_sad_size]
        mov     esi, [esi + drive_cache_t.ptr]
        ret

  .ide_app_data:
        mov     ecx, [esi + drive_cache_t.app_sad_size]
        mov     esi, [esi + drive_cache_t.data_ptr]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_calculate_cache_1 ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, [cdpos]
        dec     esi
        cmp     esi, 4
        jae     .exit

        imul    esi, sizeof.drive_cache_t
        add     esi, ide_drives_cache

        cmp     [cd_appl_data], 0
        jne     .ide_app_data

        mov     esi, [esi + drive_cache_t.ptr]
        ret

  .ide_app_data:
        mov     esi, [esi + drive_cache_t.data_ptr]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_calculate_cache_2 ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [cdpos]
        dec     eax
        cmp     eax, 4
        jae     .exit

        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache

        cmp     [cd_appl_data], 0
        jne     .ide_app_data

        mov     eax, [eax + drive_cache_t.sys_data]
        ret

  .ide_app_data:
        mov     eax, [eax + drive_cache_t.app_data]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_calculate_cache_3 ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [cdpos]
        dec     edi
        cmp     edi, 4
        jae     .exit

        imul    edi, sizeof.drive_cache_t
        add     edi, ide_drives_cache

        cmp     [cd_appl_data], 0
        jne     .ide_app_data

        mov     edi, [edi + drive_cache_t.sys_search_start]
        ret

  .ide_app_data:
        mov     edi, [edi + drive_cache_t.app_search_start]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_calculate_cache_4 ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [cdpos]
        dec     edi
        cmp     edi, 4
        jae     .exit

        imul    edi, sizeof.drive_cache_t
        add     edi, ide_drives_cache

        cmp     [cd_appl_data], 0
        jne     .ide_app_data

        cmp     edi, [edi + drive_cache_t.sys_sad_size]
        ret

  .ide_app_data:
        cmp     edi, [edi + drive_cache_t.app_sad_size]

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cd_calculate_cache_5 ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        mov     eax, [cdpos]
        dec     eax
        cmp     eax, 4
        jae     .exit

        imul    eax, sizeof.drive_cache_t
        add     eax, ide_drives_cache

        cmp     [cd_appl_data], 0
        jne     .ide_app_data

        mov     [eax + drive_cache_t.sys_search_start], edi
        pop     eax
        ret

  .ide_app_data:
        mov     [eax + drive_cache_t.app_search_start], edi

  .exit:
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
;kproc calculate_linear_to_real ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       shr     eax, 12
;       mov     eax, [page_tabs + eax * 4]
;       and     eax, 0xfffff000
;       ret
;kendp
