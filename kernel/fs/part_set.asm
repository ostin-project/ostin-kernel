;;======================================================================================================================
;;///// part_set.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2012 Ostin project <http://ostin.googlecode.com/>
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
;? Find all partitions with supported file systems
;;======================================================================================================================
;;# References:
;;#  * "How to determine the filesystem type of a volume" by Jonathan de Boyne Pollard
;;#    http://homepage.ntlworld.com/jonathan.deboynepollard/FGA/determining-filesystem-type.html
;;======================================================================================================================

include "detect/bpb.inc"

fs_dependent_data_size max_of \
  sizeof.fs.fat16x.partition_data_t, \
  sizeof.fs.ntfs.partition_data_t, \
  sizeof.fs.ext2.partition_data_t

uglobal
  align 4
  current_partition fs.partition_t
  hd_setup          dd 0
  problem_partition db 0 ; used for partitions search

  align 4
  fs_dependent_data_start rb fs_dependent_data_size
  file_system_data_size = $ - current_partition

  if KCONFIG_FS_FAT16 or KCONFIG_FS_FAT32
    virtual at fs_dependent_data_start
      fat16x_data fs.fat16x.partition_data_t
    end virtual
  end if
  if KCONFIG_FS_NTFS
    virtual at fs_dependent_data_start
      ntfs_data fs.ntfs.partition_data_t
    end virtual
  end if
  if KCONFIG_FS_EXT2
    virtual at fs_dependent_data_start
      ext2_data fs.ext2.partition_data_t
    end virtual
  end if
endg

iglobal
  partition_types: ; list of fat16/32 partitions
    db 0x04 ; DOS: fat16 <32M
    db 0x06 ; DOS: fat16 >32M
    db 0x0b ; WIN95: fat32
    db 0x0c ; WIN95: fat32, LBA-mapped
    db 0x0e ; WIN95: fat16, LBA-mapped
    db 0x14 ; Hidden DOS: fat16 <32M
    db 0x16 ; Hidden DOS: fat16 >32M
    db 0x1b ; Hidden WIN95: fat32
    db 0x1c ; Hidden WIN95: fat32, LBA-mapped
    db 0x1e ; Hidden WIN95: fat16, LBA-mapped
    db 0xc4 ; DRDOS/secured: fat16 <32M
    db 0xc6 ; DRDOS/secured: fat16 >32M
    db 0xcb ; DRDOS/secured: fat32
    db 0xcc ; DRDOS/secured: fat32, LBA-mapped
    db 0xce ; DRDOS/secured: fat16, LBA-mapped
    db 0xd4 ; Old Multiuser DOS secured: fat16 <32M
    db 0xd6 ; Old Multiuser DOS secured: fat16 >32M
    db 0x07 ; NTFS
    db 0x27 ; NTFS, hidden
    db 0x83 ; Linux native file system (ext2fs)
  partition_types_end:

  extended_types: ; list of extended partitions
    db 0x05 ; DOS: extended partition
    db 0x0f ; WIN95: extended partition, LBA-mapped
    db 0xc5 ; DRDOS/secured: extended partition
    db 0xd5 ; Old Multiuser DOS secured: extended partition
  extended_types_end:
endg

; Partition chain used:
; MBR <-------------------+
; |                       |
; +-> PARTITION1          |
; +-> EXTENDED PARTITION -+ ; not need be second partition
; +-> PARTITION3
; +-> PARTITION4

;-----------------------------------------------------------------------------------------------------------------------
kproc set_partition_variables ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        or      [problem_partition], 2
        ret
;       and     [problem_partition], 0
;       call    reserve_hd1
;       call    reserve_hd_channel
;
;       pushad
;
;       cmp     dword[hdpos], 0
;       je      .problem_hd
;
;       xor     ecx, ecx ; partition count
;       xor     eax, eax ; address MBR
;       xor     ebp, ebp ; extended partition start
;
; .new_mbr:
;       test    ebp, ebp ; is there extended partition? (MBR or EMBR)
;       jnz     .extended_already_set ; yes
;       xchg    ebp, eax ; no. set it now
;
; .extended_already_set:
;       add     eax, ebp ; mbr=mbr+0, ext_part=ext_start+relat_start
;       mov     ebx, buffer
;       call    hd_read
;       cmp     [hd_error], 0
;       jne     .problem_hd
;
;       cmp     [ebx + mbr_t.mbr_signature], MBR_SIGNATURE ; is it valid boot sector?
;       jnz     .end_partition_chain
;       push    eax ; push only one time
;       cmp     [ebx + mbr_t.partitions.0.size_lba], 0 ; skip over empty partition
;       jnz     .test_primary_partition_0
;       cmp     [ebx + mbr_t.partitions.1.size_lba], 0
;       jnz     .test_primary_partition_1
;       cmp     [ebx + mbr_t.partitions.2.size_lba], 0
;       jnz     .test_primary_partition_2
;       cmp     [ebx + mbr_t.partitions.3.size_lba], 0
;       jnz     .test_primary_partition_3
;       pop     eax
;       jmp     .end_partition_chain
;
; .test_primary_partition_0:
;       mov     al, [ebx + mbr_t.partitions.0.type] ; get primary partition type
;       call    scan_partition_types
;       jnz     .test_primary_partition_1 ; no. skip over
;
;       inc     ecx
;       cmp     ecx, [known_part] ; is it wanted partition?
;       jnz     .test_primary_partition_1 ; no
;
;       pop     eax
;       add     eax, [ebx + mbr_t.partitions.0.start_lba] ; add relative start
;       mov     edx, [ebx + mbr_t.partitions.0.size_lba] ; length
;       mov     cl, [ebx + mbr_t.partitions.0.type] ; current_partition.type
;       jmp     .hd_and_partition_ok
;
; .test_primary_partition_1:
;       mov     al, [ebx + mbr_t.partitions.1.type] ; get primary partition type
;       call    scan_partition_types
;       jnz     .test_primary_partition_2 ; no. skip over
;
;       inc     ecx
;       cmp     ecx, [known_part] ; is it wanted partition?
;       jnz     .test_primary_partition_2 ; no
;
;       pop     eax
;       add     eax, [ebx + mbr_t.partitions.1.start_lba]
;       mov     edx, [ebx + mbr_t.partitions.1.size_lba]
;       mov     cl, [ebx + mbr_t.partitions.1.type]
;       jmp     .hd_and_partition_ok
;
; .test_primary_partition_2:
;       mov     al, [ebx + mbr_t.partitions.2.type] ; get primary partition type
;       call    scan_partition_types
;       jnz     .test_primary_partition_3 ; no. skip over
;
;       inc     ecx
;       cmp     ecx, [known_part] ; is it wanted partition?
;       jnz     .test_primary_partition_3 ; no
;
;       pop     eax
;       add     eax, [ebx + mbr_t.partitions.2.start_lba]
;       mov     edx, [ebx + mbr_t.partitions.2.size_lba]
;       mov     cl, [ebx + mbr_t.partitions.2.type]
;       jmp     .hd_and_partition_ok
;
; .test_primary_partition_3:
;       mov     al, [ebx + mbr_t.partitions.3.type] ; get primary partition type
;       call    scan_partition_types
;       jnz     .test_ext_partition_0 ; no. skip over
;
;       inc     ecx
;       cmp     ecx, [known_part] ; is it wanted partition?
;       jnz     .test_ext_partition_0 ; no
;
;       pop     eax
;       add     eax, [ebx + mbr_t.partitions.3.start_lba]
;       mov     edx, [ebx + mbr_t.partitions.3.size_lba]
;       mov     cl, [ebx + mbr_t.partitions.3.type]
;       jmp     .hd_and_partition_ok
;
; .test_ext_partition_0:
;       pop     eax ; just throwing out of stack
;       mov     al, [ebx + mbr_t.partitions.0.type] ; get extended partition type
;       call    scan_extended_types
;       jnz     .test_ext_partition_1
;
;       mov     eax, [ebx + mbr_t.partitions.0.start_lba] ; add relative start
;       test    eax, eax ; is there extended partition?
;       jnz     .new_mbr ; yes. read it
;
; .test_ext_partition_1:
;       mov     al, [ebx + mbr_t.partitions.1.type] ; get extended partition type
;       call    scan_extended_types
;       jnz     .test_ext_partition_2
;
;       mov     eax, [ebx + mbr_t.partitions.1.start_lba] ; add relative start
;       test    eax, eax ; is there extended partition?
;       jnz     .new_mbr ; yes. read it
;
; .test_ext_partition_2:
;       mov     al, [ebx + mbr_t.partitions.2.type] ; get extended partition type
;       call    scan_extended_types
;       jnz     .test_ext_partition_3
;
;       mov     eax, [ebx + mbr_t.partitions.2.start_lba] ; add relative start
;       test    eax, eax ; is there extended partition?
;       jnz     .new_mbr ; yes. read it
;
; .test_ext_partition_3:
;       mov     al, [ebx + mbr_t.partitions.3.type] ; get extended partition type
;       call    scan_extended_types
;       jnz     .end_partition_chain ; no. end chain
;
;       mov     eax, [ebx + mbr_t.partitions.3.start_lba] ; get start of extended partition
;       test    eax, eax ; is there extended partition?
;       jnz     .new_mbr ; yes. read it
;
; .end_partition_chain:
; .problem_hd:
;       or      [problem_partition], 2
;       jmp     .return_from_part_set
;
  .problem_fat_dec_count:
        ; bootsector is missing or another problem

  .problem_partition_or_fat:
        or      [problem_partition], 1

  .return_from_part_set:
        popad
        call    free_hd_channel
        mov     [hd1_status], 0 ; free
        ret
;
; .hd_and_partition_ok:
;       ; eax = PARTITION_START edx=PARTITION_LENGTH cl=current_partition.type
;       push    ecx
;       mov     dword[current_partition._.range.offset], eax
;       mov     dword[current_partition._.range.length], edx
;
;       mov     ebx, buffer
;       call    hd_read ; read boot sector of partition
;       cmp     [hd_error], 0
;       pop     ecx
;       jz      .boot_read_ok
;       cmp     cl, MBR_PART_TYPE_NTFS
;       jnz     .problem_fat_dec_count
;       ; NTFS duplicates bootsector:
;       ;   NT4/2k/XP+ saves bootsector copy in the end of disk
;       ;   NT 3.51 saves bootsector copy in the middle of disk
;       and     [hd_error], 0
;       mov     eax, dword[current_partition._.range.offset]
;       add     eax, dword[current_partition._.range.length]
;       dec     eax
;       call    hd_read
;       cmp     [hd_error], 0
;       jnz     @f
;       call    ntfs_test_bootsec
;       jnc     .boot_read_ok
;
;   @@: and     [hd_error], 0
;       mov     eax, edx
;       shr     eax, 1
;       add     eax, dword[current_partition._.range.offset]
;       call    hd_read
;       cmp     [hd_error], 0
;       jnz     .problem_fat_dec_count ; no chance...
;
; .boot_read_ok:
;       ; if we are running on NTFS, check bootsector
;
;       call    ntfs_test_bootsec ; test ntfs
;       jnc     ntfs_setup
;
;       call    ext2_test_superblock ; test ext2fs
;       jnc     ext2_setup
;
;       jmp     fat16x_setup
kendp

; XREF: fs/ext2.asm (ext2_setup)
return_from_part_set = set_partition_variables.return_from_part_set
; XREF: fs/ntfs.asm (ntfs_setup)
problem_fat_dec_count = set_partition_variables.problem_fat_dec_count

;-----------------------------------------------------------------------------------------------------------------------
kproc scan_partition_types ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     edi, partition_types
        mov     ecx, partition_types_end - partition_types
        repne
        scasb   ; is partition type ok?
        pop     ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc scan_extended_types ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        mov     edi, extended_types
        mov     ecx, extended_types_end - extended_types
        repne
        scasb   ; is it extended partition?
        pop     ecx
        ret
kendp

iglobal
  mbr_part_handlers dd \
    fs.detect_by_mbr_part_entry.ext2, \
    fs.detect_by_mbr_part_entry.bpb_based, \
    0

  bpb_based_creators:
    if KCONFIG_FS_FAT12
      dq 'FAT12   '
      dd fs.fat.fat12.create_from_base
    end if
    if KCONFIG_FS_FAT16
      dq 'FAT16   '
      dd fs.fat.fat16.create_from_base
    end if
    if KCONFIG_FS_FAT32
      dq 'FAT32   '
      dd fs.fat.fat32.create_from_base
    end if
    if KCONFIG_FS_NTFS
      dq 'NTFS    '
      dd fs.ntfs.create_from_base
    end if
    dd 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.detect_by_mbr_part_entry ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (base)
;> ecx ^= mbr_part_entry_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= fs.partition_t (ok; newly allocated) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_DEBUG, "* MBR entry type = %x\n", [ecx + mbr_part_entry_t.type]:2
        mov     esi, mbr_part_handlers

  .next_handler:
        lodsd
        test    eax, eax
        jz      .exit

        push    ebx ecx esi
        call    eax
        pop     esi ecx ebx
        test    eax, eax
        jz      .next_handler

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.detect_by_mbr_part_entry.ext2 ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (base)
;> ecx ^= mbr_part_entry_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= fs.partition_t (ok; newly allocated) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [ecx + mbr_part_entry_t.type]

        cmp     al, 0x83
        jne     .error

        add     esp, -512
        mov     edi, esp
        mov_s_  eax, 2
        cdq
        mov_s_  ecx, 1
        push    edi
        call    fs.read
        pop     edi
        test    eax, eax
        jnz     .error_2

        cmp     [edi + ext2_sb_t.log_block_size], 3 ; s_block_size 0,1,2,3
        ja      .error_2
        cmp     [edi + ext2_sb_t.magic], 0xef53 ; s_magic
        jne     .error_2
        cmp     [edi + ext2_sb_t.state], 1 ; s_state (EXT_VALID_FS=1)
        jne     .error_2
        mov     eax, [edi + ext2_sb_t.feature_incompat]
        test    eax, EXT2_FEATURE_INCOMPAT_FILETYPE
        jz      .error_2
        test    eax, not EXT2_FEATURE_INCOMPAT_FILETYPE
        jnz     .error_2

        klog_   LOG_DEBUG, "* ext2 found\n"

        call    fs.ext2.create_from_base

        add     esp, 512
        ret

  .error_2:
        add   esp, 512

  .error:
        xor   eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.detect_by_mbr_part_entry.bpb_based ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (base)
;> ecx ^= mbr_part_entry_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= fs.partition_t (ok; newly allocated) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [ecx + mbr_part_entry_t.type]

        ; in case EXT partition was not found, there is still a possibility we have valid BPB in place
        cmp     al, 0x83
        je      .check_for_bpb

        cmp     al, 0xef
        je      .check_for_bpb

        test    al, 0x20
        jnz     .error

        and     al, 0x0f
        cmp     al, 0x01
        je      .check_for_bpb
        cmp     al, 0x04
        je      .check_for_bpb
        cmp     al, 0x06
        je      .check_for_bpb
        cmp     al, 0x07
        je      .check_for_bpb
        cmp     al, 0x0b
        je      .check_for_bpb
        cmp     al, 0x0c
        je      .check_for_bpb
        cmp     al, 0x0e
        jne     .error

  .check_for_bpb:
        add     esp, -512
        mov     edi, esp
        xor     eax, eax
        cdq
        mov_s_  ecx, 1
        push    edi
        call    fs.read
        pop     edi
        test    eax, eax
        jnz     .error_2

        mov     al, [edi + bpb_v7_0_t.signature]
        cmp     al, 0x28
        je      .could_be_v7_0_bpb
        cmp     al, 0x29
        jne     .check_for_v4_0_bpb

  .could_be_v7_0_bpb:
        lea     edx, [edi + bpb_v7_0_t.fs_type]
        call    .validate_bpb_fs_type
        jc      .check_for_v4_0_bpb

        ; v7.0 BPB found
        mov     ecx, 0x0700
        jmp     .find_creator

  .check_for_v4_0_bpb:
        mov     al, [edi + bpb_v4_0_t.signature]
        cmp     al, 0x28
        je      .could_be_v4_0_bpb
        cmp     al, 0x29
        jne     .check_for_v8_0_bpb

  .could_be_v4_0_bpb:
        lea     edx, [edi + bpb_v4_0_t.fs_type]
        call    .validate_bpb_fs_type
        jc      .check_for_v8_0_bpb

        ; v4.0 BPB found
        mov     ecx, 0x0400
        jmp     .find_creator

  .check_for_v8_0_bpb:
        cmp     [edi + bpb_v8_0_t.signature], 0x80
        jne     .error_2

        ; v8.0 BPB found
        mov     ecx, 0x0800
        lea     edx, [edi + 3]
;       jmp     .find_creator

  .find_creator:
        klog_   LOG_DEBUG, "* v%u.%u BPB found\n", ch, cl

        mov     esi, bpb_based_creators

  .next_creator:
        mov     eax, [esi]
        test    al, al
        jz      .error_2

        cmp     eax, [edx]
        jne     .skip_creator

        mov     eax, [esi + 4]
        cmp     eax, [edx + 4]
        jne     .skip_creator

        call    dword[esi + 8]

        add     esp, 512
        ret

  .skip_creator:
        add     esi, 8 + 4
        jmp     .next_creator

  .error_2:
        add     esp, 512

  .error:
        xor     eax, eax
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .validate_bpb_fs_type: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_DEBUG, "* validating FS type: '%s'\n", edx:8
        mov     ecx, 8
        push    edx

  .next_char:
        mov     al, [edx]
        cmp     al, ' '
        jb      .invalid
        je      @f
        cmp     al, '0'
        jb      .invalid
        cmp     al, '9'
        jbe     @f
        cmp     al, 'A'
        jb      .invalid
        cmp     al, 'Z'
        ja      .invalid

    @@: inc     edx
        dec     ecx
        jnz     .next_char

        klog_   LOG_DEBUG, "  valid\n"
        pop     edx
        clc
        ret

  .invalid:
        klog_   LOG_DEBUG, "  invalid\n"
        pop     edx
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.detect_by_gpt_part_entry ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (base)
;> ecx ^= gpt_part_entry_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax ^= fs.partition_t (ok; newly allocated) or 0 (error)
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        ret
kendp
