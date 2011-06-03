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

align 4
;-----------------------------------------------------------------------------------------------------------------------
write_cache: ;//////////////////////////////////////////////////////////////////////////////////////////////////////////
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

    @@: ; Объединяем запись цепочки последовательных секторов в одно обращение к диску
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
find_empty_slot: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
clear_hd_cache: ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [fat_in_cache], -1
        mov     [fat_change], 0
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
calculate_cache: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     ecx, cache_max ; entries in cache
;       mov     esi, HD_CACHE+8

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [hdpos], 1
        jne     .ide1
        cmp     [hdd_appl_data], 0
        jne     .ide0_appl_data
        mov     ecx, [cache_ide0.sys_sad_size]
        mov     esi, [cache_ide0.ptr]
        ret

  .ide0_appl_data:
        mov     ecx, [cache_ide0.app_sad_size]
        mov     esi, [cache_ide0.data_ptr]
        ret

  .ide1:
        cmp     [hdpos], 2
        jne     .ide2
        cmp     [hdd_appl_data], 0
        jne     .ide1_appl_data
        mov     ecx, [cache_ide1.sys_sad_size]
        mov     esi, [cache_ide1.ptr]
        ret

  .ide1_appl_data:
        mov     ecx, [cache_ide1.app_sad_size]
        mov     esi, [cache_ide1.data_ptr]
        ret

  .ide2:
        cmp     [hdpos], 3
        jne     .ide3
        cmp     [hdd_appl_data], 0
        jne     .ide2_appl_data
        mov     ecx, [cache_ide2.sys_sad_size]
        mov     esi, [cache_ide2.ptr]
        ret

  .ide2_appl_data:
        mov     ecx, [cache_ide2.app_sad_size]
        mov     esi, [cache_ide2.data_ptr]
        ret

  .ide3:
        cmp     [hdpos], 4
        jne     .noide
        cmp     [hdd_appl_data], 0
        jne     .ide3_appl_data
        mov     ecx, [cache_ide3.sys_sad_size]
        mov     esi, [cache_ide3.ptr]
        ret

  .ide3_appl_data:
        mov     ecx, [cache_ide3.app_sad_size]
        mov     esi, [cache_ide3.data_ptr]
        ret

  .noide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, cache_ide0
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
calculate_cache_1: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       lea     esi, [edi * 8 + HD_CACHE]

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [hdpos], 1
        jne     .ide1
        cmp     [hdd_appl_data], 0
        jne     .ide0_appl_data
        mov     esi, [cache_ide0.ptr]
        ret

  .ide0_appl_data:
        mov     esi, [cache_ide0.data_ptr]
        ret

  .ide1:
        cmp     [hdpos], 2
        jne     .ide2
        cmp     [hdd_appl_data], 0
        jne     .ide1_appl_data
        mov     esi, [cache_ide1.ptr]
        ret

  .ide1_appl_data:
        mov     esi, [cache_ide1.data_ptr]
        ret

  .ide2:
        cmp     [hdpos], 3
        jne     .ide3
        cmp     [hdd_appl_data], 0
        jne     .ide2_appl_data
        mov     esi, [cache_ide2.ptr]
        ret

  .ide2_appl_data:
        mov     esi, [cache_ide2.data_ptr]
        ret

  .ide3:
        cmp     [hdpos], 4
        jne     .noide
        cmp     [hdd_appl_data], 0
        jne     .ide3_appl_data
        mov     esi, [cache_ide3.ptr]
        ret

  .ide3_appl_data:
        mov     esi, [cache_ide3.data_ptr]
        ret

  .noide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, cache_ide0
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
calculate_cache_2: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       add     esi, HD_CACHE + 65536

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [hdpos], 1
        jne     .ide1
        cmp     [hdd_appl_data], 0
        jne     .ide0_appl_data
        mov     eax, [cache_ide0.sys_data]
        ret

  .ide0_appl_data:
        mov     eax, [cache_ide0.app_data]
        ret

  .ide1:
        cmp     [hdpos], 2
        jne     .ide2
        cmp     [hdd_appl_data], 0
        jne     .ide1_appl_data
        mov     eax, [cache_ide1.sys_data]
        ret

  .ide1_appl_data:
        mov     eax, [cache_ide1.app_data]
        ret

  .ide2:
        cmp     [hdpos], 3
        jne     .ide3
        cmp     [hdd_appl_data], 0
        jne     .ide2_appl_data
        mov     eax, [cache_ide2.sys_data]
        ret

  .ide2_appl_data:
        mov     eax, [cache_ide2.app_data]
        ret

  .ide3:
        cmp     [hdpos], 4
        jne     .noide
        cmp     [hdd_appl_data], 0
        jne     .ide3_appl_data
        mov     eax, [cache_ide3.sys_data]
        ret

  .ide3_appl_data:
        mov     eax, [cache_ide3.app_data]
        ret

  .noide:
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, cache_ide0
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
calculate_cache_3: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     ecx, cache_max * 10 / 100
;       mov     edi, [cache_search_start]

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [hdpos], 1
        jne     .ide1
        cmp     [hdd_appl_data], 0
        jne     .ide0_appl_data
        mov     ecx, [cache_ide0.sys_sad_size]
        mov     edi, [cache_ide0.sys_search_start]
        ret

  .ide0_appl_data:
        mov     ecx, [cache_ide0.app_sad_size]
        mov     edi, [cache_ide0.app_search_start]
        ret

  .ide1:
        cmp     [hdpos], 2
        jne     .ide2
        cmp     [hdd_appl_data], 0
        jne     .ide1_appl_data
        mov     ecx, [cache_ide1.sys_sad_size]
        mov     edi, [cache_ide1.sys_search_start]
        ret

  .ide1_appl_data:
        mov     ecx, [cache_ide1.app_sad_size]
        mov     edi, [cache_ide1.app_search_start]
        ret

  .ide2:
        cmp     [hdpos], 3
        jne     .ide3
        cmp     [hdd_appl_data], 0
        jne     .ide2_appl_data
        mov     ecx, [cache_ide2.sys_sad_size]
        mov     edi, [cache_ide2.sys_search_start]
        ret

  .ide2_appl_data:
        mov     ecx, [cache_ide2.app_sad_size]
        mov     edi, [cache_ide2.app_search_start]
        ret

  .ide3:
        cmp     [hdpos], 4
        jne     .noide
        cmp     [hdd_appl_data], 0
        jne     .ide3_appl_data
        mov     ecx, [cache_ide3.sys_sad_size]
        mov     edi, [cache_ide3.sys_search_start]
        ret

  .ide3_appl_data:
        mov     ecx, [cache_ide3.app_sad_size]
        mov     edi, [cache_ide3.app_search_start]
        ret

  .noide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, cache_ide0
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
calculate_cache_4: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       cmp     edi, cache_max

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [hdpos], 1
        jne     .ide1
        cmp     [hdd_appl_data], 0
        jne     .ide0_appl_data
        cmp     edi, [cache_ide0.sys_sad_size]
        ret

  .ide0_appl_data:
        cmp     edi, [cache_ide0.app_sad_size]
        ret

  .ide1:
        cmp     [hdpos], 2
        jne     .ide2
        cmp     [hdd_appl_data], 0
        jne     .ide1_appl_data
        cmp     edi, [cache_ide1.sys_sad_size]
        ret

  .ide1_appl_data:
        cmp     edi, [cache_ide1.app_sad_size]
        ret

  .ide2:
        cmp     [hdpos], 3
        jne     .ide3
        cmp     [hdd_appl_data], 0
        jne     .ide2_appl_data
        cmp     edi, [cache_ide2.sys_sad_size]
        ret

  .ide2_appl_data:
        cmp     edi, [cache_ide2.app_sad_size]
        ret

  .ide3:
        cmp     [hdpos], 4
        jne     .noide
        cmp     [hdd_appl_data], 0
        jne     .ide3_appl_data
        cmp     edi, [cache_ide3.sys_sad_size]
        ret

  .ide3_appl_data:
        cmp     edi, [cache_ide3.app_sad_size]
        ret

  .noide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, cache_ide0
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
calculate_cache_5: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     [cache_search_start], edi

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [hdpos], 1
        jne     .ide1
        cmp     [hdd_appl_data], 0
        jne     .ide0_appl_data
        mov     [cache_ide0.sys_search_start], edi
        ret

  .ide0_appl_data:
        mov     [cache_ide0.app_search_start], edi
        ret

  .ide1:
        cmp     [hdpos], 2
        jne     .ide2
        cmp     [hdd_appl_data], 0
        jne     .ide1_appl_data
        mov     [cache_ide1.sys_search_start], edi
        ret

  .ide1_appl_data:
        mov     [cache_ide1.app_search_start], edi
        ret

  .ide2:
        cmp     [hdpos], 3
        jne     .ide3
        cmp     [hdd_appl_data], 0
        jne     .ide2_appl_data
        mov     [cache_ide2.sys_search_start], edi
        ret

  .ide2_appl_data:
        mov     [cache_ide2.app_search_start], edi
        ret

  .ide3:
        cmp     [hdpos], 4
        jne     .noide
        cmp     [hdd_appl_data], 0
        jne     .ide3_appl_data
        mov     [cache_ide3.sys_search_start], edi
        ret

  .ide3_appl_data:
        mov     [cache_ide3.app_search_start], edi
        ret

  .noide:
        push    eax
        mov     eax, [hdpos]
        sub     eax, 0x80
        cmp     byte[BiosDisksData + eax * 4 + 2], -1
        jz      @f
        movzx   eax, byte[BiosDisksData + eax * 4 + 2]
        imul    eax, sizeof.drive_cache_t
        add     eax, cache_ide0
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
find_empty_slot_CD_cache: ;/////////////////////////////////////////////////////////////////////////////////////////////
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

;-----------------------------------------------------------------------------------------------------------------------
clear_CD_cache: ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha

  .ide0:
        xor     eax, eax
        cmp     [cdpos], 1
        jne     .ide1
        mov     [cache_ide0.sys_search_start], eax
        mov     ecx, [cache_ide0.sys_sad_size]
        mov     edi, [cache_ide0.ptr]
        call    .clear
        mov     [cache_ide0.app_search_start], eax
        mov     ecx, [cache_ide0.app_sad_size]
        mov     edi, [cache_ide0.data_ptr]
        jmp     .continue

  .ide1:
        cmp     [cdpos], 2
        jne     .ide2
        mov     [cache_ide1.sys_search_start], eax
        mov     ecx, [cache_ide1.sys_sad_size]
        mov     edi, [cache_ide1.ptr]
        call    .clear
        mov     [cache_ide1.app_search_start], eax
        mov     ecx, [cache_ide1.app_sad_size]
        mov     edi, [cache_ide1.data_ptr]
        jmp     .continue

  .ide2:
        cmp     [cdpos], 3
        jne     .ide3
        mov     [cache_ide2.sys_search_start], eax
        mov     ecx, [cache_ide2.sys_sad_size]
        mov     edi, [cache_ide2.ptr]
        call    .clear
        mov     [cache_ide2.app_search_start], eax
        mov     ecx, [cache_ide2.app_sad_size]
        mov     edi, [cache_ide2.data_ptr]
        jmp     .continue

  .ide3:
        mov     [cache_ide3.sys_search_start], eax
        mov     ecx, [cache_ide3.sys_sad_size]
        mov     edi, [cache_ide3.ptr]
        call    .clear
        mov     [cache_ide3.app_search_start], eax
        mov     ecx, [cache_ide3.app_sad_size]
        mov     edi, [cache_ide3.data_ptr]

  .continue:
        call    .clear
        popa
        ret

  .clear:
        shl     ecx, 1
        cld
        rep     stosd
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
cd_calculate_cache: ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     ecx, cache_max ; entries in cache
;       mov     esi, HD_CACHE + 8

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [cdpos], 1
        jne     .ide1
        cmp     [cd_appl_data], 0
        jne     .ide0_appl_data
        mov     ecx, [cache_ide0.sys_sad_size]
        mov     esi, [cache_ide0.ptr]
        ret

  .ide0_appl_data:
        mov     ecx, [cache_ide0.app_sad_size]
        mov     esi, [cache_ide0.data_ptr]
        ret

  .ide1:
        cmp     [cdpos], 2
        jne     .ide2
        cmp     [cd_appl_data], 0
        jne     .ide1_appl_data
        mov     ecx, [cache_ide1.sys_sad_size]
        mov     esi, [cache_ide1.ptr]
        ret

  .ide1_appl_data:
        mov     ecx, [cache_ide1.app_sad_size]
        mov     esi, [cache_ide1.data_ptr]
        ret

  .ide2:
        cmp     [cdpos], 3
        jne     .ide3
        cmp     [cd_appl_data], 0
        jne     .ide2_appl_data
        mov     ecx, [cache_ide2.sys_sad_size]
        mov     esi, [cache_ide2.ptr]
        ret

  .ide2_appl_data:
        mov     ecx, [cache_ide2.app_sad_size]
        mov     esi, [cache_ide2.data_ptr]
        ret

  .ide3:
        cmp     [cd_appl_data], 0
        jne     .ide3_appl_data
        mov     ecx, [cache_ide3.sys_sad_size]
        mov     esi, [cache_ide3.ptr]
        ret

  .ide3_appl_data:
        mov     ecx, [cache_ide3.app_sad_size]
        mov     esi, [cache_ide3.data_ptr]
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
cd_calculate_cache_1: ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       lea     esi, [edi * 8 + HD_CACHE]

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [cdpos], 1
        jne     .ide1
        cmp     [cd_appl_data], 0
        jne     .ide0_appl_data
        mov     esi, [cache_ide0.ptr]
        ret

  .ide0_appl_data:
        mov     esi, [cache_ide0.data_ptr]
        ret

  .ide1:
        cmp     [cdpos], 2
        jne     .ide2
        cmp     [cd_appl_data], 0
        jne     .ide1_appl_data
        mov     esi, [cache_ide1.ptr]
        ret

  .ide1_appl_data:
        mov     esi, [cache_ide1.data_ptr]
        ret

  .ide2:
        cmp     [cdpos], 3
        jne     .ide3
        cmp     [cd_appl_data], 0
        jne     .ide2_appl_data
        mov     esi, [cache_ide2.ptr]
        ret

  .ide2_appl_data:
        mov     esi, [cache_ide2.data_ptr]
        ret

  .ide3:
        cmp     [cd_appl_data], 0
        jne     .ide3_appl_data
        mov     esi, [cache_ide3.ptr]
        ret

  .ide3_appl_data:
        mov     esi, [cache_ide3.data_ptr]
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
cd_calculate_cache_2: ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       add     esi, HD_CACHE + 65536

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [cdpos], 1
        jne     .ide1
        cmp     [cd_appl_data], 0
        jne     .ide0_appl_data
        mov     eax, [cache_ide0.sys_data]
        ret

  .ide0_appl_data:
        mov     eax, [cache_ide0.app_data]
        ret

  .ide1:
        cmp     [cdpos], 2
        jne     .ide2
        cmp     [cd_appl_data], 0
        jne     .ide1_appl_data
        mov     eax, [cache_ide1.sys_data]
        ret

  .ide1_appl_data:
        mov     eax, [cache_ide1.app_data]
        ret

  .ide2:
        cmp     [cdpos], 3
        jne     .ide3
        cmp     [cd_appl_data], 0
        jne     .ide2_appl_data
        mov     eax, [cache_ide2.sys_data]
        ret

  .ide2_appl_data:
        mov     eax, [cache_ide2.app_data]
        ret

  .ide3:
        cmp     [cd_appl_data], 0
        jne     .ide3_appl_data
        mov     eax, [cache_ide3.sys_data]
        ret

  .ide3_appl_data:
        mov     eax, [cache_ide3.app_data]
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
cd_calculate_cache_3: ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     ecx, cache_max * 10 / 100
;       mov     edi, [cache_search_start]

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [cdpos], 1
        jne     .ide1
        cmp     [cd_appl_data], 0
        jne     .ide0_appl_data
        mov     edi, [cache_ide0.sys_search_start]
        ret

  .ide0_appl_data:
        mov     edi, [cache_ide0.app_search_start]
        ret

  .ide1:
        cmp     [cdpos], 2
        jne     .ide2
        cmp     [cd_appl_data], 0
        jne     .ide1_appl_data
        mov     edi, [cache_ide1.sys_search_start]
        ret

  .ide1_appl_data:
        mov     edi, [cache_ide1.app_search_start]
        ret

  .ide2:
        cmp     [cdpos], 3
        jne     .ide3
        cmp     [cd_appl_data], 0
        jne     .ide2_appl_data
        mov     edi, [cache_ide2.sys_search_start]
        ret

  .ide2_appl_data:
        mov     edi, [cache_ide2.app_search_start]
        ret

  .ide3:
        cmp     [cd_appl_data], 0
        jne     .ide3_appl_data
        mov     edi, [cache_ide3.sys_search_start]
        ret

  .ide3_appl_data:
        mov     edi, [cache_ide3.app_search_start]
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
cd_calculate_cache_4: ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       cmp     edi, cache_max

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [cdpos], 1
        jne     .ide1
        cmp     [cd_appl_data], 0
        jne     .ide0_appl_data
        cmp     edi, [cache_ide0.sys_sad_size]
        ret

  .ide0_appl_data:
        cmp     edi, [cache_ide0.app_sad_size]
        ret

  .ide1:
        cmp     [cdpos], 2
        jne     .ide2
        cmp     [cd_appl_data], 0
        jne     .ide1_appl_data
        cmp     edi, [cache_ide1.sys_sad_size]
        ret

  .ide1_appl_data:
        cmp     edi, [cache_ide1.app_sad_size]
        ret

  .ide2:
        cmp     [cdpos], 3
        jne     .ide3
        cmp     [cd_appl_data], 0
        jne     .ide2_appl_data
        cmp     edi, [cache_ide2.sys_sad_size]
        ret

  .ide2_appl_data:
        cmp     edi, [cache_ide2.app_sad_size]
        ret

  .ide3:
        cmp     [cd_appl_data], 0
        jne     .ide3_appl_data
        cmp     edi, [cache_ide3.sys_sad_size]
        ret

  .ide3_appl_data:
        cmp     edi, [cache_ide3.app_sad_size]
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
cd_calculate_cache_5: ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     [cache_search_start], edi

        ; 1 - IDE0 ... 4 - IDE3

  .ide0:
        cmp     [cdpos], 1
        jne     .ide1
        cmp     [cd_appl_data], 0
        jne     .ide0_appl_data
        mov     [cache_ide0.sys_search_start], edi
        ret

  .ide0_appl_data:
        mov     [cache_ide0.app_search_start], edi
        ret

  .ide1:
        cmp     [cdpos], 2
        jne     .ide2
        cmp     [cd_appl_data], 0
        jne     .ide1_appl_data
        mov     [cache_ide1.sys_search_start], edi
        ret

  .ide1_appl_data:
        mov     [cache_ide1.app_search_start], edi
        ret

  .ide2:
        cmp     [cdpos], 3
        jne     .ide3
        cmp     [cd_appl_data], 0
        jne     .ide2_appl_data
        mov     [cache_ide2.sys_search_start], edi
        ret

  .ide2_appl_data:
        mov     [cache_ide2.app_search_start], edi
        ret

  .ide3:
        cmp     [cd_appl_data], 0
        jne     .ide3_appl_data
        mov     [cache_ide3.sys_search_start], edi
        ret

  .ide3_appl_data:
        mov     [cache_ide3.app_search_start], edi
        ret

;align 4
;-----------------------------------------------------------------------------------------------------------------------
;calculate_linear_to_real: ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       shr     eax, 12
;       mov     eax, [page_tabs + eax * 4]
;       and     eax, 0xfffff000
;       ret
