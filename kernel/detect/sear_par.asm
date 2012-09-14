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
;? Find and save partitions on detected HDD in table
;;======================================================================================================================

include "detect/gpt.inc"
include "detect/mbr.inc"

uglobal
  align 4
  known_part dd ? ; for boot 0x1
endg

        call    scan_for_blkdev_partitions

        mov     [transfer_address], DRIVE_DATA + 0x0a

search_partitions_ide0:
        test    byte[DRIVE_DATA + 1], 0x40
        jz      search_partitions_ide1
        mov     [hdbase], 0x1f0
        mov     [hdid], 0
        mov     [hdpos], 1
        mov     [known_part], 1

search_partitions_ide0_1:
        call    set_partition_variables
        test    [problem_partition], 2
        jnz     search_partitions_ide1 ; not found part
        test    [problem_partition], 1
        jnz     @f ; not found known_part
        inc     byte[DRIVE_DATA + 2]
        call    partition_data_transfer
        add     [transfer_address], 100

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
        call    set_partition_variables
        test    [problem_partition], 2
        jnz     search_partitions_ide2
        test    [problem_partition], 1
        jnz     @f
        inc     byte[DRIVE_DATA + 3]
        call    partition_data_transfer
        add     [transfer_address], 100

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
        call    set_partition_variables
        test    [problem_partition], 2
        jnz     search_partitions_ide3
        test    [problem_partition], 1
        jnz     @f
        inc     byte[DRIVE_DATA + 4]
        call    partition_data_transfer
        add     [transfer_address], 100

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
        call    set_partition_variables
        test    [problem_partition], 2
        jnz     end_search_partitions_ide
        test    [problem_partition], 1
        jnz     @f
        inc     byte[DRIVE_DATA + 5]
        call    partition_data_transfer
        add     [transfer_address], 100

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
        call    set_partition_variables
        test    [problem_partition], 2
        jnz     end_search_partitions_bd
        test    [problem_partition], 1
        jnz     @f
        mov     eax, [hdpos]
        inc     [BiosDiskPartitions + (eax - 0x80) * 4]
        call    partition_data_transfer
        add     [transfer_address], 100

    @@: inc     [known_part]
        jmp     search_partitions_bd

end_search_partitions_bd:
        pop     ecx
        inc     [hdpos]
        loop    start_search_partitions_bd
        jmp     end_search_partitions

include  "fs/part_set.asm"

uglobal
  transfer_address dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc scan_for_blkdev_partitions ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, blkdev_list

  .next_device:
        mov     ebx, [ebx + blk.device_t.next_ptr]
        cmp     ebx, blkdev_list
        je      .done

        call    detect_device_partitions
        jmp     .next_device

  .done:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc detect_device_partitions ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.device_t
;-----------------------------------------------------------------------------------------------------------------------
        lea     eax, [ebx + blk.device_t._.name]
        klog_   LOG_DEBUG, "detect_device_partitions: %s\n", eax

        mov     eax, 512
        call    malloc
        test    eax, eax
        jz      .exit

        push    eax

        mov     edi, eax
        xor     eax, eax
        cdq
        mov_s_  ecx, 1
        call    blk.read
        test    eax, eax
        jnz     .done

        mov     esi, [esp]
        cmp     [esi + mbr_t.mbr_signature], MBR_SIGNATURE
        jne     .done

        cmp     [esi + mbr_t.partitions.0.type], 0xee
        je      .gpt_scheme

        call    detect_device_partitions_mbr
        jmp     .done

  .gpt_scheme:
        call    detect_device_partitions_gpt

  .done:
        pop     eax
        call    free

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc detect_device_partitions_mbr ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.device_t
;> esi ^= mbr_t
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        cdq

        push    1 ; current partition number

  .next_mbr:
        push    edx eax ; current MBR offset
        push    0 0 ; next (extended) MBR offset
        push    esi

        cmp     [esi + mbr_t.mbr_signature], MBR_SIGNATURE
        jne     .done

        add     esi, mbr_t.partitions
        mov_s_  ecx, 4

  .next_partition:
        push    ebx ecx esi

        mov     eax, [esp + (3 + 1 + 2) * 4] ; current MBR offset (low)
        mov     edx, [esp + (3 + 1 + 2 + 1) * 4] ; current MBR offset (high)
        mov     ecx, [esp + (3 + 1 + 2 + 2) * 4] ; current partition number
        add     esp, -sizeof.fs.partition_t
        mov     edi, esp
        call    .init_partition
        mov     ebx, esp

        mov     al, [esi + mbr_part_entry_t.type]
        cmp     al, 0
        je      .skip_partition

        mov     edi, extended_types
        mov_s_  ecx, extended_types_end - extended_types
        repne
        scasb
        je      .skip_extended_partition

        mov     ecx, esi
        call    fs.detect_by_mbr_part_entry
        test    eax, eax
        jz      .skip_partition

        klog_   LOG_DEBUG, "  detected\n"

        mov     edx, eax
        mov     ecx, [ebx + fs.partition_t._.device]
        add     ecx, blk.device_t._.partitions
        list_add_tail edx, ecx

        inc     dword[esp + sizeof.fs.partition_t + (3 + 1 + 2 + 2) * 4] ; current partition number

        jmp     .skip_partition

  .skip_extended_partition:
        mov     eax, dword[ebx + fs.partition_t._.range.offset]
        mov     [esp + sizeof.fs.partition_t + (3 + 1) * 4], eax ; next (extended) MBR offset (low)
        mov     eax, dword[ebx + fs.partition_t._.range.offset + 4]
        mov     [esp + sizeof.fs.partition_t + (3 + 1 + 1) * 4], eax ; next (extended) MBR offset (high)

  .skip_partition:
        add     esp, sizeof.fs.partition_t

        pop     esi ecx ebx
        add     esi, sizeof.mbr_part_entry_t
        dec     ecx
        jnz     .next_partition

  .done:
        pop     edi ; ^= mbr_t
        pop     eax edx ; next (extended) MBR offset
        add     esp, 8

        test    eax, eax
        jnz     .extended_mbr
        test    edx, edx
        jz      .exit

  .extended_mbr:
        mov_s_  ecx, 1
        push    eax edx edi
        call    blk.read
        test    eax, eax
        pop     esi edx eax
        jz      .next_mbr

  .exit:
        add     esp, 4
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .init_partition: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> edx:eax #= current MBR offset
;> ebx ^= blk.device_t
;> ecx #= current partition number
;> esi ^= mbr_part_entry_t
;> edi ^= fs.partition_t (base)
;-----------------------------------------------------------------------------------------------------------------------
        mov     [edi + fs.partition_t._.number], cl

        lea     ecx, [edi + fs.partition_t._.mutex]
        call    mutex_init

        mov     [edi + fs.partition_t._.device], ebx

        push    0 [esi + mbr_part_entry_t.start_lba]
        pop     dword[edi + fs.partition_t._.range.offset] dword[edi + fs.partition_t._.range.offset + 4]
        add     dword[edi + fs.partition_t._.range.offset], eax
        adc     dword[edi + fs.partition_t._.range.offset + 4], edx

        push    0 [esi + mbr_part_entry_t.size_lba]
        pop     dword[edi + fs.partition_t._.range.length] dword[edi + fs.partition_t._.range.length + 4]

        ; TODO: get range from CHS values if LBA ones are zero

        and     [edi + fs.partition_t._.vftbl], 0

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc detect_device_partitions_gpt ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= blk.device_t
;> esi ^= mbr_t (protective)
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc partition_data_transfer ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [transfer_address]
        mov     esi, current_partition ; start of file_system_data
        mov     ecx, (file_system_data_size + 3) / 4
        rep
        movsd
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc partition_data_transfer_1 ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       cli
        push    edi
        mov     edi, current_partition
        mov     esi, [transfer_address]
        mov     ecx, (file_system_data_size + 3) / 4
        rep
        movsd
        pop     edi
;       sti
        ret
kendp

end_search_partitions:
