;;======================================================================================================================
;;///// sear_par.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
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

;****************************************************
; find and save partitions on detected HDD in table
; Author - Mario79
;****************************************************

        mov     [transfer_adress], DRIVE_DATA + 0x0a

search_partitions_ide0:
        test    byte[DRIVE_DATA + 1], 0x40
        jz      search_partitions_ide1
        mov     [hdbase], 0x1f0
        mov     [hdid], 0
        mov     [hdpos], 1
        mov     [known_part], 1

search_partitions_ide0_1:
        call    set_PARTITION_variables
        test    [problem_partition], 2
        jnz     search_partitions_ide1 ; not found part
        test    [problem_partition], 1
        jnz     @f ; not found known_part
;       cmp     [problem_partition], 0
;       jne     search_partitions_ide1
        inc     byte[DRIVE_DATA + 2]
        call    partition_data_transfer
        add     [transfer_adress], 100

    @@: inc     [known_part]
        jmp     search_partitions_ide0_1

search_partitions_ide1:
        test    byte[DRIVE_DATA + 1], 0x10
        jz      search_partitions_ide2
        mov     [hdbase], 0x1f0
        mov     [hdid], 0x10
        mov     [hdpos], 2
        mov     [known_part], 1

search_partitions_ide1_1:
        call    set_PARTITION_variables
        test    [problem_partition], 2
        jnz     search_partitions_ide2
        test    [problem_partition], 1
        jnz     @f
;       cmp     [problem_partition], 0
;       jne     search_partitions_ide2
        inc     byte[DRIVE_DATA + 3]
        call    partition_data_transfer
        add     [transfer_adress], 100

    @@: inc     [known_part]
        jmp     search_partitions_ide1_1

search_partitions_ide2:
        test    byte[DRIVE_DATA + 1], 0x4
        jz      search_partitions_ide3
        mov     [hdbase], 0x170
        mov     [hdid], 0
        mov     [hdpos], 3
        mov     [known_part], 1

search_partitions_ide2_1:
        call    set_PARTITION_variables
        test    [problem_partition], 2
        jnz     search_partitions_ide3
        test    [problem_partition], 1
        jnz     @f
;       cmp     [problem_partition], 0
;       jne     search_partitions_ide3
        inc     byte[DRIVE_DATA + 4]
        call    partition_data_transfer
        add     [transfer_adress], 100

    @@: inc     [known_part]
        jmp     search_partitions_ide2_1

search_partitions_ide3:
        test    byte[DRIVE_DATA + 1], 0x1
        jz      end_search_partitions_ide
        mov     [hdbase], 0x170
        mov     [hdid], 0x10
        mov     [hdpos], 4
        mov     [known_part], 1

search_partitions_ide3_1:
        call    set_PARTITION_variables
        test    [problem_partition], 2
        jnz     end_search_partitions_ide
        test    [problem_partition], 1
        jnz     @f
;       cmp     [problem_partition], 0
;       jne     end_search_partitions_ide
        inc     byte[DRIVE_DATA + 5]
        call    partition_data_transfer
        add     [transfer_adress], 100

    @@: inc     [known_part]
        jmp     search_partitions_ide3_1

end_search_partitions_ide:
        mov     [hdpos], 0x80
        mov     ecx, [NumBiosDisks]
        test    ecx, ecx
        jz      end_search_partitions

start_search_partitions_bd:
        push    ecx
        mov     eax, [hdpos]
        and     [BiosDiskPartitions + (eax - 0x80) * 4], 0
        mov     [known_part], 1

search_partitions_bd:
        call    set_PARTITION_variables
        test    [problem_partition], 2
        jnz     end_search_partitions_bd
        test    [problem_partition], 1
        jnz     @f
;       cmp     [problem_partition], 0
;       jne     end_search_partitions_bd
        mov     eax, [hdpos]
        inc     [BiosDiskPartitions + (eax - 0x80) * 4]
        call    partition_data_transfer
        add     [transfer_adress], 100

    @@: inc     [known_part]
        jmp     search_partitions_bd

end_search_partitions_bd:
        pop     ecx
        inc     [hdpos]
        loop    start_search_partitions_bd
        jmp     end_search_partitions


;-----------------------------------------------------------------------------------------------------------------------
partition_data_transfer: ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [transfer_adress]
        mov     esi, PARTITION_START ; start of file_system_data
        mov     ecx, (file_system_data_size + 3) / 4
        rep     movsd
        ret

uglobal
  transfer_adress dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
partition_data_transfer_1: ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       cli
        push    edi
        mov     edi, PARTITION_START
        mov     esi, [transfer_adress]
        mov     ecx, (file_system_data_size + 3) / 4
        rep     movsd
        pop     edi
;       sti
        ret

end_search_partitions:
