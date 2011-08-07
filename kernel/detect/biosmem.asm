;;======================================================================================================================
;;///// biosmem.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2009 KolibriOS team <http://kolibrios.org/>
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
;? Query physical memory map from BIOS
;;======================================================================================================================

;-----------------------------------------------------------------------------------------------------------------------
kproc get_memory_map_from_bios ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ds
        ; first call to fn E820
        mov     eax, 0xe820
        xor     ebx, ebx
        mov     es, bx
        mov     ds, bx
        mov     di, BOOT_PHOENIX_SMAP
        mov     [di - 4], ebx ; no blocks yet
        mov     ecx, sizeof.phoenix_smap_addr_range_t
        mov     edx, 0x534d4150
        int     0x15
        jc      .no_e820
        cmp     eax, 0x534d4150
        jnz     .no_e820

  .e820_mem_loop:
        cmp     byte[di + phoenix_smap_addr_range_t.type], PHOENIX_SMAP_TYPE_AVAILABLE ; ignore non-free areas
        jnz     .e820_mem_next
        inc     byte[BOOT_PHOENIX_SMAP_CNT]
        add     di, sizeof.phoenix_smap_addr_range_t

  .e820_mem_next:
        ; consequent calls to fn E820
        test    ebx, ebx
        jz      .e820_test_done
        cmp     byte[BOOT_PHOENIX_SMAP_CNT], 32
        jae     .e820_test_done
        mov     eax, 0xe820
        int     0x15
        jc      .e820_test_done
        jmp     .e820_mem_loop

  .no_e820:
        ; let's hope for mem_test from init.inc

  .e820_test_done:
        pop     ds
        ret
kendp
