;;======================================================================================================================
;;///// rdload.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2007 KolibriOS team <http://kolibrios.org/>
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

        ; READ RAMDISK IMAGE FROM HD
        cmp     [boot_dev + OS_BASE + 0x10000], 1
        jne     no_sys_on_hd

        test    byte[DRIVE_DATA + 1], 0x40
        jz      position_2
        mov     [hdbase], 0x1f0
        mov     [hdid], 0
        mov     [hdpos], 1
        mov     [known_part], 0

position_1_1:
        inc     [known_part]
        call    search_and_read_image
        cmp     [image_retrieved], 1
        je      yes_sys_on_hd
        movzx   eax, byte[DRIVE_DATA + 2]
        cmp     [known_part], eax
        jle     position_1_1

position_2:
        test    byte[DRIVE_DATA + 1], 0x10
        jz      position_3
        mov     [hdbase], 0x1f0
        mov     [hdid], 0x10
        mov     [hdpos], 2
        mov     [known_part], 0

position_2_1:
        inc     [known_part]
        call    search_and_read_image
        cmp     [image_retrieved], 1
        je      yes_sys_on_hd
        movzx   eax, byte[DRIVE_DATA + 3]
        cmp     eax, [known_part]
        jle     position_2_1

position_3:
        test    byte[DRIVE_DATA + 1], 0x4
        jz      position_4
        mov     [hdbase], 0x170
        mov     [hdid], 0
        mov     [hdpos], 3
        mov     [known_part], 0

position_3_1:
        inc     [known_part]
        call    search_and_read_image
        cmp     [image_retrieved], 1
        je      yes_sys_on_hd
        movzx   eax, byte[DRIVE_DATA + 4]
        cmp     eax, [known_part]
        jle     position_3_1

position_4:
        test    byte[DRIVE_DATA + 1], 0x1
        jz      no_sys_on_hd
        mov     [hdbase], 0x170
        mov     [hdid], 0x10
        mov     [hdpos], 4
        mov     [known_part], 0

position_4_1:
        inc     [known_part]
        call    search_and_read_image
        cmp     [image_retrieved], 1
        je      yes_sys_on_hd
        movzx   eax, byte[DRIVE_DATA + 5]
        cmp     eax, [known_part]
        jle     position_4_1
        jmp     yes_sys_on_hd

search_and_read_image:
        call    set_partition_variables
        mov     edx, bootpath
        call    read_image
        test    eax, eax
        jz      .image_present
        mov     edx, bootpath2
        call    read_image
        test    eax, eax
        jz      .image_present
        ret

  .image_present:
        mov     [image_retrieved], 1
        ret

read_image:
        mov     eax, hdsysimage + OS_BASE + 0x10000
        mov     ebx, 1440 * 1024 / 512
        mov     ecx, RAMDISK
        mov     esi, 0
        mov     edi, 12
        call    file_read
        ret

image_retrieved       db 0
counter_of_partitions db 0

no_sys_on_hd:
        ; test_to_format_ram_disk (need if not using ram disk)
        cmp     [boot_dev + OS_BASE + 0x10000], 3
        jne     not_format_ram_disk
        ; format_ram_disk
        mov     edi, RAMDISK
        mov     ecx, 33 * 512 / 4
        xor     eax, eax
        rep
        stosd

        mov     ecx, (1440 * 1024 / 512 - 33) * 512 / 4
        mov     eax, 0xf6f6f6f6
        rep
        stosd

        mov     dword[RAMDISK + 0x200], 0x00fffff0 ; fat table
        mov     dword[RAMDISK + 0x4200], 0x00fffff0

not_format_ram_disk:
yes_sys_on_hd:
