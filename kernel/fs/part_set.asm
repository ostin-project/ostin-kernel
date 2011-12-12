;;======================================================================================================================
;;///// part_set.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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
;? Find all partitions with supported file systems
;;======================================================================================================================

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

  virtual at fs_dependent_data_start
    fat16x_data fs.fat16x.partition_data_t
  end virtual
  virtual at fs_dependent_data_start
    ntfs_data fs.ntfs.partition_data_t
  end virtual
  virtual at fs_dependent_data_start
    ext2_data fs.ext2.partition_data_t
  end virtual
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
        and     [problem_partition], 0
        call    reserve_hd1
        call    reserve_hd_channel

        pushad

        cmp     dword[hdpos], 0
        je      .problem_hd

        xor     ecx, ecx ; partition count
        xor     eax, eax ; address MBR
        xor     ebp, ebp ; extended partition start

  .new_mbr:
        test    ebp, ebp ; is there extended partition? (MBR or EMBR)
        jnz     .extended_already_set ; yes
        xchg    ebp, eax ; no. set it now

  .extended_already_set:
        add     eax, ebp ; mbr=mbr+0, ext_part=ext_start+relat_start
        mov     ebx, buffer
        call    hd_read
        cmp     [hd_error], 0
        jne     .problem_hd

        cmp     word[ebx + 0x1fe], 0xaa55 ; is it valid boot sector?
        jnz     .end_partition_chain
        push    eax ; push only one time
        cmp     dword[ebx + 0x1be + 0x0c], 0 ; skip over empty partition
        jnz     .test_primary_partition_0
        cmp     dword[ebx + 0x1be + 0x0c + 16], 0
        jnz     .test_primary_partition_1
        cmp     dword[ebx + 0x1be + 0x0c + 16 + 16], 0
        jnz     .test_primary_partition_2
        cmp     dword[ebx + 0x1be + 0x0c + 16 + 16 + 16], 0
        jnz     .test_primary_partition_3
        pop     eax
        jmp     .end_partition_chain

  .test_primary_partition_0:
        mov     al, [ebx + 0x1be + 4] ; get primary partition type
        call    scan_partition_types
        jnz     .test_primary_partition_1 ; no. skip over

        inc     ecx
        cmp     ecx, [known_part] ; is it wanted partition?
        jnz     .test_primary_partition_1 ; no

        pop     eax
        add     eax, [ebx + 0x1be + 8] ; add relative start
        mov     edx, [ebx + 0x1be + 12] ; length
        mov     cl, [ebx + 0x1be + 4] ; current_partition.type
        jmp     .hd_and_partition_ok

  .test_primary_partition_1:
        mov     al, [ebx + 0x1be + 4 + 16] ; get primary partition type
        call    scan_partition_types
        jnz     .test_primary_partition_2 ; no. skip over

        inc     ecx
        cmp     ecx, [known_part] ; is it wanted partition?
        jnz     .test_primary_partition_2 ; no

        pop     eax
        add     eax, [ebx + 0x1be + 8 + 16]
        mov     edx, [ebx + 0x1be + 12 + 16]
        mov     cl, [ebx + 0x1be + 4 + 16]
        jmp     .hd_and_partition_ok

  .test_primary_partition_2:
        mov     al, [ebx + 0x1be + 4 + 16 + 16] ; get primary partition type
        call    scan_partition_types
        jnz     .test_primary_partition_3 ; no. skip over

        inc     ecx
        cmp     ecx, [known_part] ; is it wanted partition?
        jnz     .test_primary_partition_3 ; no

        pop     eax
        add     eax, [ebx + 0x1be + 8 + 16 + 16]
        mov     edx, [ebx + 0x1be + 12 + 16 + 16]
        mov     cl, [ebx + 0x1be + 4 + 16 + 16]
        jmp     .hd_and_partition_ok

  .test_primary_partition_3:
        mov     al, [ebx + 0x1be + 4 + 16 + 16 + 16] ; get primary partition type
        call    scan_partition_types
        jnz     .test_ext_partition_0 ; no. skip over

        inc     ecx
        cmp     ecx, [known_part] ; is it wanted partition?
        jnz     .test_ext_partition_0 ; no

        pop     eax
        add     eax, [ebx + 0x1be + 8 + 16 + 16 + 16]
        mov     edx, [ebx + 0x1be + 12 + 16 + 16 + 16]
        mov     cl, [ebx + 0x1be + 4 + 16 + 16 + 16]
        jmp     .hd_and_partition_ok

  .test_ext_partition_0:
        pop     eax ; just throwing out of stack
        mov     al, [ebx + 0x1be + 4] ; get extended partition type
        call    scan_extended_types
        jnz     .test_ext_partition_1

        mov     eax, [ebx + 0x1be + 8] ; add relative start
        test    eax, eax ; is there extended partition?
        jnz     .new_mbr ; yes. read it

  .test_ext_partition_1:
        mov     al, [ebx + 0x1be + 4 + 16] ; get extended partition type
        call    scan_extended_types
        jnz     .test_ext_partition_2

        mov     eax, [ebx + 0x1be + 8 + 16] ; add relative start
        test    eax, eax ; is there extended partition?
        jnz     .new_mbr ; yes. read it

  .test_ext_partition_2:
        mov     al, [ebx + 0x1be + 4 + 16 + 16] ; get extended partition type
        call    scan_extended_types
        jnz     .test_ext_partition_3

        mov     eax, [ebx + 0x1be + 8 + 16 + 16] ; add relative start
        test    eax, eax ; is there extended partition?
        jnz     .new_mbr ; yes. read it

  .test_ext_partition_3:
        mov     al, [ebx + 0x1be + 4 + 16 + 16 + 16] ; get extended partition type
        call    scan_extended_types
        jnz     .end_partition_chain ; no. end chain

        mov     eax, [ebx + 0x1be + 8 + 16 + 16 + 16] ; get start of extended partition
        test    eax, eax ; is there extended partition?
        jnz     .new_mbr ; yes. read it

  .end_partition_chain:
  .problem_hd:
        or      [problem_partition], 2
        jmp     .return_from_part_set

  .problem_fat_dec_count:
        ; bootsector is missing or another problem

  .problem_partition_or_fat:
        or      [problem_partition], 1

  .return_from_part_set:
        popad
        call    free_hd_channel
        mov     [hd1_status], 0 ; free
        ret

  .hd_and_partition_ok:
        ; eax = PARTITION_START edx=PARTITION_LENGTH cl=current_partition.type
        mov     [current_partition.type], cl
        mov     dword[current_partition.range.offset], eax
        mov     dword[current_partition.range.length], edx

        mov     ebx, buffer
        call    hd_read ; read boot sector of partition
        cmp     [hd_error], 0
        jz      .boot_read_ok
        cmp     [current_partition.type], 7
        jnz     .problem_fat_dec_count
        ; NTFS duplicates bootsector:
        ;   NT4/2k/XP+ saves bootsector copy in the end of disk
        ;   NT 3.51 saves bootsector copy in the middle of disk
        and     [hd_error], 0
        mov     eax, dword[current_partition.range.offset]
        add     eax, dword[current_partition.range.length]
        dec     eax
        call    hd_read
        cmp     [hd_error], 0
        jnz     @f
        call    ntfs_test_bootsec
        jnc     .boot_read_ok

    @@: and     [hd_error], 0
        mov     eax, edx
        shr     eax, 1
        add     eax, dword[current_partition.range.offset]
        call    hd_read
        cmp     [hd_error], 0
        jnz     .problem_fat_dec_count ; no chance...

  .boot_read_ok:
        ; if we are running on NTFS, check bootsector

        call    ntfs_test_bootsec ; test ntfs
        jnc     ntfs_setup

        call    ext2_test_superblock ; test ext2fs
        jnc     ext2_setup

        mov     eax, dword[current_partition.range.offset] ; ext2 test changes [buffer]
        call    hd_read
        cmp     [hd_error], 0
        jnz     .problem_fat_dec_count

        cmp     word[ebx + 0x1fe], 0xaa55 ; is it valid boot sector?
        jnz     .problem_fat_dec_count

        movzx   eax, word[ebx + 0x0e] ; sectors reserved
        add     eax, dword[current_partition.range.offset]
        mov     [fat16x_data.fat_start], eax ; fat_start = partition_start + reserved

        movzx   eax, byte[ebx + 0x0d] ; sectors per cluster
        test    eax, eax
        jz      .problem_fat_dec_count
        mov     [fat16x_data.sectors_per_cluster], eax

        movzx   ecx, word[ebx + 0x0b] ; bytes per sector
        cmp     ecx, 0x200
        jnz     .problem_fat_dec_count
        mov     [fat16x_data.bytes_per_sector], ecx

        movzx   eax, word[ebx + 0x11] ; count of rootdir entries (=0 fat32)
        mov     edx, 32
        mul     edx
        dec     ecx
        add     eax, ecx ; round up if not equal count
        inc     ecx ; bytes per sector
        div     ecx
        mov     [fat16x_data.root_sectors], eax ; count of rootdir sectors

        movzx   eax, word[ebx + 0x16] ; sectors per fat <65536
        test    eax, eax
        jnz     .fat16_fatsize
        mov     eax, [ebx + 0x24] ; sectors per fat

  .fat16_fatsize:
        mov     [fat16x_data.sectors_per_fat], eax

        movzx   eax, byte[ebx + 0x10] ; number of fats
        test    eax, eax ; if 0 it's not fat partition
        jz      .problem_fat_dec_count
        mov     [fat16x_data.number_of_fats], eax
        imul    eax, [fat16x_data.sectors_per_fat]
        add     eax, [fat16x_data.fat_start]
        mov     [fat16x_data.root_start], eax ; rootdir = fat_start + fat_size * fat_count
        add     eax, [fat16x_data.root_sectors] ; rootdir sectors should be 0 on fat32
        mov     [fat16x_data.data_start], eax ; data area = rootdir + rootdir_size

        movzx   eax, word[ebx + 0x13] ; total sector count <65536
        test    eax, eax
        jnz     .fat16_total
        mov     eax, [ebx + 0x20] ; total sector count

  .fat16_total:
        mov     dword[current_partition.range.length], eax
        add     eax, dword[current_partition.range.offset]
        sub     eax, [fat16x_data.data_start] ; eax = count of data sectors
        xor     edx, edx
        div     dword[fat16x_data.sectors_per_cluster]
        inc     eax
        mov     [fat16x_data.last_cluster], eax
        dec     eax ; cluster count
        mov     [fat16x_data.fatStartScan], 2

        ; limits by Microsoft Hardware White Paper v1.03
        cmp     eax, 4085 ; 0x0ff5
        jb      .problem_fat_dec_count ; fat12 not supported
        cmp     eax, 65525 ; 0xfff5
        jb      .fat16_partition

  .fat32_partition:
        mov     eax, [ebx + 0x2c] ; rootdir cluster
        mov     [fat16x_data.root_cluster], eax
        movzx   eax, word[ebx + 0x30] ; fs info sector
        add     eax, dword[current_partition.range.offset]
        mov     [fat16x_data.adr_fsinfo], eax
        call    hd_read
        mov     eax, [ebx + 0x1ec]
        cmp     eax, -1
        jz      @f
        mov     [fat16x_data.fatStartScan], eax

    @@: popad

        mov     [fat16x_data.fatRESERVED], 0x0ffffff6
        mov     [fat16x_data.fatBAD], 0x0ffffff7
        mov     [fat16x_data.fatEND], 0x0ffffff8
        mov     [fat16x_data.fatMASK], 0x0fffffff
        mov     [current_partition.type], FS_PARTITION_TYPE_FAT32 ; Fat32
        call    free_hd_channel
        mov     [hd1_status], 0 ; free
        ret

  .fat16_partition:
        xor     eax, eax
        mov     [fat16x_data.root_cluster], eax

        popad

        mov     [fat16x_data.fatRESERVED], 0x0000fff6
        mov     [fat16x_data.fatBAD], 0x0000fff7
        mov     [fat16x_data.fatEND], 0x0000fff8
        mov     [fat16x_data.fatMASK], 0x0000ffff
        mov     [current_partition.type], FS_PARTITION_TYPE_FAT16 ; Fat16
        call    free_hd_channel
        mov     [hd1_status], 0 ; free
        ret
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
