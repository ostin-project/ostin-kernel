;;======================================================================================================================
;;///// ntfs.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2012 Ostin project <http://ostin.googlecode.com/>
;; (c) 2006-2010 KolibriOS team <http://kolibrios.org/>
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

struct fs.ntfs.partition_data_t
  sectors_per_cluster dd ?
  mft_cluster         dd ?
  mftmirr_cluster     dd ?
  frs_size            dd ? ; FRS size in bytes
  iab_size            dd ? ; IndexAllocationBuffer size in bytes
  frs_buffer          dd ?
  iab_buffer          dd ?
  mft_retrieval       dd ?
  mft_retrieval_size  dd ?
  mft_retrieval_alloc dd ?
  mft_retrieval_end   dd ?
  cur_index_size      dd ?
  cur_index_buf       dd ?
ends

iglobal
  JumpTable fs.ntfs, vftbl, 0, \
    read_file, \
    read_directory, \
    -, \
    -, \
    -, \
    get_file_info, \
    -, \
    -, \
    -, \
    -
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.ntfs.create_from_base ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (base)
;> ecx @= BPB version, pack[16(0), 8(major), 8(minor)]
;> edi ^= BPB
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "fs.ntfs.create_from_base\n"

        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_test_bootsec ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to buffer
;> edx = size of partition
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 0 (valid) or 1 (invalid)
;-----------------------------------------------------------------------------------------------------------------------
        ; 1. Name=='NTFS    '
        cmp     dword[ebx + 3], 'NTFS'
        jnz     .no
        cmp     dword[ebx + 7], '    '
        jnz     .no
        ; 2. Number of bytes per sector is the same as for physical device
        ; (that is, 0x200 for hard disk)
        cmp     [ebx + bpb_v8_0_t.sector_size], 0x200
        jnz     .no
        ; 3. Number of sectors per cluster must be power of 2
        movzx   eax, [ebx + bpb_v8_0_t.cluster_size]
        dec     eax
        js      .no
        test    al, [ebx + bpb_v8_0_t.cluster_size]
        jnz     .no
        ; 4. FAT parameters must be zero
        cmp     [ebx + bpb_v8_0_t.resvd_sector_count], 0
        jnz     .no
        cmp     dword[ebx + bpb_v8_0_t.fat_count], 0
        jnz     .no
        cmp     byte[ebx + bpb_v8_0_t.volume_size_16 + 1], 0
        jnz     .no
        cmp     [ebx + bpb_v8_0_t.fat_size_16], 0
        jnz     .no
        cmp     [ebx + bpb_v8_0_t.volume_size_32], 0
        jnz     .no
        ; 5. Number of sectors <= partition size
        cmp     dword[ebx + bpb_v8_0_t.volume_size_64 + 4], 0
        ja      .no
        cmp     dword[ebx + bpb_v8_0_t.volume_size_64], edx
        ja      .no
        ; 6. $MFT and $MFTMirr clusters must be within partition
        cmp     dword[ebx + bpb_v8_0_t.mft_first_cluster + 4], 0
        ja      .no
        push    edx
        movzx   eax, [ebx + bpb_v8_0_t.cluster_size]
        mul     dword[ebx + bpb_v8_0_t.mft_first_cluster]
        test    edx, edx
        pop     edx
        jnz     .no
        cmp     eax, edx
        ja      .no
        cmp     dword[ebx + bpb_v8_0_t.mft_mirror_first_cluster + 4], 0
        ja      .no
        push    edx
        movzx   eax, byte[ebx + bpb_v8_0_t.cluster_size]
        mul     dword[ebx + bpb_v8_0_t.mft_mirror_first_cluster]
        test    edx, edx
        pop     edx
        jnz     .no
        cmp     eax, edx
        ja      .no
        ; 7. Clusters per FRS must be either negative and in [-31,-9] or positive and power of 2
        movsx   eax, byte[ebx + bpb_v8_0_t.mft_record_size]
        cmp     al, -31
        jl      .no
        cmp     al, -9
        jle     @f
        dec     eax
        js      .no
        test    byte[ebx + bpb_v8_0_t.mft_record_size], al
        jnz     .no

    @@: ; 8. Same for clusters per IndexAllocationBuffer
        movsx   eax, byte[ebx + bpb_v8_0_t.index_block_size]
        cmp     al, -31
        jl      .no
        cmp     al, -9
        jle     @f
        dec     eax
        js      .no
        test    byte[ebx + bpb_v8_0_t.index_block_size], al
        jnz     .no

    @@: ; OK, this is correct NTFS bootsector
        clc
        ret

  .no:
        ; No, this bootsector isn't NTFS
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_setup ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? By given bootsector, initialize some NTFS variables
;-----------------------------------------------------------------------------------------------------------------------
;# CODE XREF: part_set.inc
;-----------------------------------------------------------------------------------------------------------------------
;       call    ntfs_test_bootsec ; checking boot sector was already
;       jc      problem_fat_dec_count
        movzx   eax, [ebx + bpb_v8_0_t.cluster_size]
        mov     [ntfs_data.sectors_per_cluster], eax
        mov     eax, dword[ebx + bpb_v8_0_t.volume_size_64]
        mov     dword[current_partition._.range.length], eax
        mov     [current_partition._.vftbl], fs.ntfs.vftbl
        mov     eax, dword[ebx + bpb_v8_0_t.mft_first_cluster]
        mov     [ntfs_data.mft_cluster], eax
        mov     eax, dword[ebx + bpb_v8_0_t.mft_mirror_first_cluster]
        mov     [ntfs_data.mftmirr_cluster], eax
        movsx   eax, byte[ebx + bpb_v8_0_t.mft_record_size]
        test    eax, eax
        js      .1
        mul     [ntfs_data.sectors_per_cluster]
        shl     eax, 9
        jmp     .2

  .1:
        neg     eax
        mov     ecx, eax
        mov     eax, 1
        shl     eax, cl

  .2:
        mov     [ntfs_data.frs_size], eax
        movsx   eax, byte[ebx + bpb_v8_0_t.index_block_size]
        test    eax, eax
        js      .3
        mul     [ntfs_data.sectors_per_cluster]
        shl     eax, 9
        jmp     .4

  .3:
        neg     eax
        mov     ecx, eax
        mov     eax, 1
        shl     eax, cl

  .4:
        mov     [ntfs_data.iab_size], eax
        ; allocate space for buffers
        add     eax, [ntfs_data.frs_size]
        push    eax
        call    kernel_alloc
        test    eax, eax
        jz      problem_fat_dec_count
        mov     [ntfs_data.frs_buffer], eax
        add     eax, [ntfs_data.frs_size]
        mov     [ntfs_data.iab_buffer], eax
        ; read $MFT disposition
        mov     eax, [ntfs_data.mft_cluster]
        mul     [ntfs_data.sectors_per_cluster]
        call    ntfs_read_frs_sector
        cmp     [hd_error], 0
        jnz     .usemirr
        cmp     dword[ebx], 'FILE'
        jnz     .usemirr
        call    ntfs_restore_usa_frs
        jnc     .mftok

  .usemirr:
        and     [hd_error], 0
        mov     eax, [ntfs_data.mftmirr_cluster]
        mul     [ntfs_data.sectors_per_cluster]
        call    ntfs_read_frs_sector
        cmp     [hd_error], 0
        jnz     @f
        cmp     dword[ebx], 'FILE'
        jnz     @f
        call    ntfs_restore_usa_frs
        jnc     .mftok

    @@: ; $MFT and $MFTMirr invalid!

  .fail_free_frs:
        push    [ntfs_data.frs_buffer]
        call    kernel_free
        jmp     problem_fat_dec_count

  .fail_free_mft:
        push    [ntfs_data.mft_retrieval]
        call    kernel_free
        jmp     .fail_free_frs

  .mftok:
        ; read $MFT table retrieval information
        ; start with one page, increase if not enough (when MFT too fragmented)
        push    ebx
        push    0x1000
        call    kernel_alloc
        pop     ebx
        test    eax, eax
        jz      .fail_free_frs
        mov     [ntfs_data.mft_retrieval], eax
        and     [ntfs_data.mft_retrieval_size], 0
        mov     [ntfs_data.mft_retrieval_alloc], 0x1000 / 8
        ; $MFT base record must contain unnamed non-resident $DATA attribute
        movzx   eax, word[ebx + 0x14]
        add     eax, ebx

  .scandata:
        cmp     dword[eax], -1
        jz      .fail_free_mft
        cmp     dword[eax], 0x80
        jnz     @f
        cmp     byte[eax + 9], 0
        jz      .founddata

  @@:
        add     eax, [eax + 4]
        jmp     .scandata

  .founddata:
        cmp     byte[eax + 8], 0
        jz      .fail_free_mft
        ; load first portion of $DATA attribute retrieval information
        mov     edx, [eax + 0x18]
        mov     [ntfs_data.mft_retrieval_end], edx
        mov     esi, eax
        movzx   eax, word[eax + 0x20]
        add     esi, eax
        sub     esp, 0x10

  .scanmcb:
        call    ntfs_decode_mcb_entry
        jnc     .scanmcbend
        call    .get_mft_retrieval_ptr
        mov     edx, [esp] ; block length
        mov     [eax], edx
        mov     edx, [esp + 8] ; block addr (relative)
        mov     [eax + 4], edx
        inc     [ntfs_data.mft_retrieval_size]
        jmp     .scanmcb

  .scanmcbend:
        add     esp, 0x10
        ; there may be other portions of $DATA attribute in auxiliary records;
        ; if they will be needed, they will be loaded later

        mov     [ntfs_data.cur_index_size], 0x1000 / 0x200
        push    0x1000
        call    kernel_alloc
        test    eax, eax
        jz      .fail_free_mft
        mov     [ntfs_data.cur_index_buf], eax

        popad
        call    free_hd_channel
        and     [hd1_status], 0
        ret

  .get_mft_retrieval_ptr:
        pushad
        mov     eax, [ntfs_data.mft_retrieval_size]
        cmp     eax, [ntfs_data.mft_retrieval_alloc]
        jnz     .ok
        add     eax, 0x1000 / 8
        mov     [ntfs_data.mft_retrieval_alloc], eax
        shl     eax, 3
        push    eax
        call    kernel_alloc
        test    eax, eax
        jnz     @f
        popad
        add     esp, 0x14
        jmp     .fail_free_mft

    @@: mov     esi, [ntfs_data.mft_retrieval]
        mov     edi, eax
        mov     ecx, [ntfs_data.mft_retrieval_size]
        add     ecx, ecx
        rep
        movsd
        push    [ntfs_data.mft_retrieval]
        mov     [ntfs_data.mft_retrieval], eax
        call    kernel_free
        mov     eax, [ntfs_data.mft_retrieval_size]

  .ok:
        shl     eax, 3
        add     eax, [ntfs_data.mft_retrieval]
        mov     [esp + regs_context32_t.eax], eax
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_read_frs_sector ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx
        add     eax, dword[current_partition._.range.offset]
        mov     ecx, [ntfs_data.frs_size]
        shr     ecx, 9
        mov     ebx, [ntfs_data.frs_buffer]
        push    ebx

    @@: call    hd_read
        cmp     [hd_error], 0
        jnz     .fail
        add     ebx, 0x200
        inc     eax
        loop    @b

  .fail:
        pop     ebx
        pop     ecx eax
        ret
kendp

uglobal
  ntfs_cur_attr         dd ?
  ntfs_cur_iRecord      dd ?
  ntfs_cur_offs         dd ? ; in sectors
  ntfs_cur_size         dd ? ; in sectors
  ntfs_cur_buf          dd ?
  ntfs_cur_read         dd ? ; [output]
  ntfs_bCanContinue     db ?
                        rb 3

  ntfs_attrlist_buf     rb 0x400
  ntfs_attrlist_mft_buf rb 0x400
  ntfs_bitmap_buf       rb 0x400

  ntfs_attr_iRecord     dd ?
  ntfs_attr_iBaseRecord dd ?
  ntfs_attr_offs        dd ?
  ntfs_attr_list        dd ?
  ntfs_attr_size        dq ?
  ntfs_cur_tail         dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_read_attr ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> global variables
;-----------------------------------------------------------------------------------------------------------------------
;< [ntfs_cur_read]
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        and     [ntfs_cur_read], 0
        cmp     [ntfs_cur_iRecord], 0
        jnz     .nomft
        cmp     [ntfs_cur_attr], 0x80
        jnz     .nomft
        mov     eax, [ntfs_data.mft_retrieval_end]
        inc     eax
        mul     [ntfs_data.sectors_per_cluster]
        cmp     eax, [ntfs_cur_offs]
        jbe     .nomft
        ; precalculated part of $Mft $DATA
        mov     esi, [ntfs_data.mft_retrieval]
        mov     eax, [ntfs_cur_offs]
        xor     edx, edx
        div     [ntfs_data.sectors_per_cluster]
        ; eax = VCN, edx = offset in sectors from beginning of cluster
        xor     ecx, ecx        ; ecx will contain LCN

  .mftscan:
        add     ecx, [esi + 4]
        sub     eax, [esi]
        jb      @f
        add     esi, 8
        push    eax
        mov     eax, [ntfs_data.mft_retrieval_end]
        shl     eax, 3
        add     eax, [ntfs_data.mft_retrieval]
        cmp     eax, esi
        pop     eax
        jnz     .mftscan
        jmp     .nomft

    @@: push    ecx
        add     ecx, eax
        add     ecx, [esi]
        push    eax
        push    edx
        mov     eax, [ntfs_data.sectors_per_cluster]
        mul     ecx
        ; eax = sector on partition
        add     eax, dword[current_partition._.range.offset]
        pop     edx
        add     eax, edx
        mov     ebx, [ntfs_cur_buf]
        pop     ecx
        neg     ecx
        imul    ecx, [ntfs_data.sectors_per_cluster]
        sub     ecx, edx
        cmp     ecx, [ntfs_cur_size]
        jb      @f
        mov     ecx, [ntfs_cur_size]

    @@: ; ecx = number of sequential sectors to read
        call    hd_read
        cmp     [hd_error], 0
        jnz     .errread
        add     [ntfs_cur_read], 0x200
        dec     [ntfs_cur_size]
        inc     [ntfs_cur_offs]
        add     ebx, 0x200
        mov     [ntfs_cur_buf], ebx
        inc     eax
        loop    @b
        pop     ecx
        xor     eax, eax
        xor     edx, edx
        cmp     [ntfs_cur_size], eax
        jz      @f
        add     esi, 8
        push    eax
        mov     eax, [ntfs_data.mft_retrieval_end]
        shl     eax, 3
        add     eax, [ntfs_data.mft_retrieval]
        cmp     eax, esi
        pop     eax
        jz      .nomft
        jmp     .mftscan

    @@: popad
        ret

  .errread:
        pop     ecx

  .errret:
        stc
        popad
        ret

  .nomft:
        ; 1. Read file record.
        ; N.B. This will do recursive call of read_attr for $MFT::$Data.
        mov     eax, [ntfs_cur_iRecord]
        mov     [ntfs_attr_iRecord], eax
        and     [ntfs_attr_list], 0
        or      dword[ntfs_attr_size], -1
        or      dword[ntfs_attr_size + 4], -1
        or      [ntfs_attr_iBaseRecord], -1
        call    ntfs_read_file_record
        test    eax, eax
        jz      .errret
        ; 2. Find required attribute.
        mov     eax, [ntfs_data.frs_buffer]
        ; a) For auxiliary records, read base record
        ; N.B. If base record is present, base iRecord may be 0 (for $Mft), but SequenceNumber is nonzero
        cmp     dword[eax + 0x24], 0
        jz      @f
        mov     eax, [eax + 0x20]
;       test    eax, eax
;       jz      @f

  .beginfindattr:
        mov     [ntfs_attr_iRecord], eax
        call    ntfs_read_file_record
        test    eax, eax
        jz      .errret

    @@: ; b) Scan for required attribute and for $ATTR_LIST
        mov     eax, [ntfs_data.frs_buffer]
        movzx   ecx, word[eax + 0x14]
        add     eax, ecx
        mov     ecx, [ntfs_cur_attr]
        and     [ntfs_attr_offs], 0

  .scanattr:
        cmp     dword[eax], -1
        jz      .scandone
        cmp     dword[eax], ecx
        jz      .okattr
        cmp     [ntfs_attr_iBaseRecord], -1
        jnz     .scancont
        cmp     dword[eax], 0x20 ; $ATTR_LIST
        jnz     .scancont
        mov     [ntfs_attr_list], eax
        jmp     .scancont

  .okattr:
        ; ignore named $DATA attributes (aka NTFS streams)
        cmp     ecx, 0x80
        jnz     @f
        cmp     byte[eax + 9], 0
        jnz     .scancont

    @@: mov     [ntfs_attr_offs], eax

  .scancont:
        add     eax, [eax + 4]
        jmp     .scanattr

  .continue:
        pushad
        and     [ntfs_cur_read], 0

  .scandone:
        ; c) Check for required offset and length
        mov     ecx, [ntfs_attr_offs]
        jecxz   .noattr
        push    [ntfs_cur_size]
        push    [ntfs_cur_read]
        call    .doreadattr
        pop     edx
        pop     eax
        jc      @f
        cmp     [ntfs_bCanContinue], 0
        jz      @f
        sub     edx, [ntfs_cur_read]
        neg     edx
        shr     edx, 9
        sub     eax, edx
        mov     [ntfs_cur_size], eax
        jnz     .not_in_cur

    @@: popad
        ret

  .noattr:
  .not_in_cur:
        cmp     [ntfs_cur_attr], 0x20
        jz      @f
        mov     ecx, [ntfs_attr_list]
        test    ecx, ecx
        jnz     .lookattr

  .ret_is_attr:
        cmp     [ntfs_attr_offs], 1 ; CF set <=> ntfs_attr_offs == 0
        popad
        ret

  .lookattr:
        ; required attribute or required offset was not found in base record;
        ; it may be present in auxiliary records;
        ; scan $ATTR_LIST
        mov     eax, [ntfs_attr_iBaseRecord]
        cmp     eax, -1
        jz      @f
        call    ntfs_read_file_record
        test    eax, eax
        jz      .errret
        or      [ntfs_attr_iBaseRecord], -1

    @@: push    [ntfs_cur_offs]
        push    [ntfs_cur_size]
        push    [ntfs_cur_read]
        push    [ntfs_cur_buf]
        push    dword[ntfs_attr_size]
        push    dword[ntfs_attr_size + 4]
        or      dword[ntfs_attr_size], -1
        or      dword[ntfs_attr_size + 4], -1
        and     [ntfs_cur_offs], 0
        mov     [ntfs_cur_size], 2
        and     [ntfs_cur_read], 0
        mov     eax, ntfs_attrlist_buf
        cmp     [ntfs_cur_iRecord], 0
        jnz     @f
        mov     eax, ntfs_attrlist_mft_buf

    @@: mov     [ntfs_cur_buf], eax
        push    eax
        call    .doreadattr
        pop     esi
        mov     edx, 1
        pop     dword[ntfs_attr_size + 4]
        pop     dword[ntfs_attr_size]
        mov     ebp, [ntfs_cur_read]
        pop     [ntfs_cur_buf]
        pop     [ntfs_cur_read]
        pop     [ntfs_cur_size]
        pop     [ntfs_cur_offs]
        jc      .errret
        or      edi, -1
        lea     ebp, [ebp + esi - 0x1a]

  .scanliststart:
        mov     eax, [ntfs_cur_attr]

  .scanlist:
        cmp     esi, ebp
        jae     .scanlistdone
        cmp     eax, [esi]
        jz      @f

  .scanlistcont:
        movzx   ecx, word[esi + 4]
        add     esi, ecx
        jmp     .scanlist

    @@: ; ignore named $DATA attributes (aka NTFS streams)
        cmp     eax, 0x80
        jnz     @f
        cmp     byte[esi + 6], 0
        jnz     .scanlistcont

    @@: push    eax
        mov     eax, [esi + 8]
        test    eax, eax
        jnz     .testf
        mov     eax, dword[ntfs_attr_size]
        and     eax, dword[ntfs_attr_size + 4]
        cmp     eax, -1
        jnz     .testfz
        ; if attribute is in auxiliary records, its size is defined only in first
        mov     eax, [esi + 0x10]
        call    ntfs_read_file_record
        test    eax, eax
        jnz     @f

  .errret_pop:
        pop     eax
        jmp     .errret

    @@: mov     eax, [ntfs_data.frs_buffer]
        movzx   ecx, word[eax + 0x14]
        add     eax, ecx
        mov     ecx, [ntfs_cur_attr]

    @@: cmp     dword[eax], -1
        jz      .errret_pop
        cmp     dword[eax], ecx
        jz      @f

  .l1:
        add     eax, [eax + 4]
        jmp     @b

    @@: cmp     eax, 0x80
        jnz     @f
        cmp     byte[eax + 9], 0
        jnz     .l1

    @@: cmp     byte[eax + 8], 0
        jnz     .sdnores
        mov     eax, [eax + 0x10]
        mov     dword[ntfs_attr_size], eax
        and     dword[ntfs_attr_size + 4], 0
        jmp     .testfz

  .sdnores:
        mov     ecx, [eax + 0x30]
        mov     dword[ntfs_attr_size], ecx
        mov     ecx, [eax + 0x34]
        mov     dword[ntfs_attr_size + 4], ecx

  .testfz:
        xor     eax, eax

  .testf:
        imul    eax, [ntfs_data.sectors_per_cluster]
        cmp     eax, [ntfs_cur_offs]
        pop     eax
        ja      @f
        mov     edi, [esi + 0x10] ; keep previous iRecord
        jmp     .scanlistcont

    @@:

  .scanlistfound:
        cmp     edi, -1
        jnz     @f
        popad
        ret

    @@: mov     eax, [ntfs_cur_iRecord]
        mov     [ntfs_attr_iBaseRecord], eax
        mov     eax, edi
        jmp     .beginfindattr

  .sde:
        popad
        stc
        ret

  .scanlistdone:
        sub     ebp, ntfs_attrlist_buf - 0x1a
        cmp     [ntfs_cur_iRecord], 0
        jnz     @f
        sub     ebp, ntfs_attrlist_mft_buf - ntfs_attrlist_buf

    @@: cmp     ebp, 0x400
        jnz     .scanlistfound
        inc     edx
        push    esi edi
        mov     esi, ntfs_attrlist_buf + 0x200
        mov     edi, ntfs_attrlist_buf
        cmp     [ntfs_cur_iRecord], 0
        jnz     @f
        mov     esi, ntfs_attrlist_mft_buf + 0x200
        mov     edi, ntfs_attrlist_mft_buf

    @@: mov     ecx, 0x200 / 4
        rep
        movsd
        mov     eax, edi
        pop     edi esi
        sub     esi, 0x200
        push    [ntfs_cur_offs]
        push    [ntfs_cur_size]
        push    [ntfs_cur_read]
        push    [ntfs_cur_buf]
        push    dword[ntfs_attr_size]
        push    dword[ntfs_attr_size + 4]
        or      dword[ntfs_attr_size], -1
        or      dword[ntfs_attr_size + 4], -1
        mov     [ntfs_cur_offs], edx
        mov     [ntfs_cur_size], 1
        and     [ntfs_cur_read], 0
        mov     [ntfs_cur_buf], eax
        mov     ecx, [ntfs_attr_list]
        push    esi edx
        call    .doreadattr
        pop     edx esi
        mov     ebp, [ntfs_cur_read]
        pop     dword[ntfs_attr_size + 4]
        pop     dword[ntfs_attr_size]
        pop     [ntfs_cur_buf]
        pop     [ntfs_cur_read]
        pop     [ntfs_cur_size]
        pop     [ntfs_cur_offs]
        jc      .errret
        add     ebp, ntfs_attrlist_buf + 0x200 - 0x1a
        cmp     [ntfs_cur_iRecord], 0
        jnz     .scanliststart
        add     ebp, ntfs_attrlist_mft_buf - ntfs_attrlist_buf
        jmp     .scanliststart

  .doreadattr:
        mov     [ntfs_bCanContinue], 0
        cmp     byte[ecx + 8], 0
        jnz     .nonresident
        mov     eax, [ecx + 0x10] ; length
        mov     esi, eax
        mov     edx, [ntfs_cur_offs]
        shr     eax, 9
        cmp     eax, edx
        jb      .okret
        shl     edx, 9
        sub     esi, edx
        movzx   eax, word[ecx + 0x14]
        add     edx, eax
        add     edx, ecx ; edx -> data
        mov     eax, [ntfs_cur_size]
        cmp     eax, (0xffffffff shr 9) + 1
        jbe     @f
        mov     eax, (0xffffffff shr 9) + 1

    @@: shl     eax, 9
        cmp     eax, esi
        jbe     @f
        mov     eax, esi

    @@: ; eax = length, edx -> data
        mov     [ntfs_cur_read], eax
        mov     ecx, eax
        mov     eax, edx
        mov     ebx, [ntfs_cur_buf]
        call    memmove
        and     [ntfs_cur_size], 0 ; CF=0
        ret

  .nonresident:
        ; Not all auxiliary records contain correct FileSize info
        mov     eax, dword[ntfs_attr_size]
        mov     edx, dword[ntfs_attr_size + 4]
        push    eax
        and     eax, edx
        cmp     eax, -1
        pop     eax
        jnz     @f
        mov     eax, [ecx + 0x30] ; FileSize
        mov     edx, [ecx + 0x34]
        mov     dword[ntfs_attr_size], eax
        mov     dword[ntfs_attr_size + 4], edx

    @@: add     eax, 0x1ff
        adc     edx, 0
        shrd    eax, edx, 9
        sub     eax, [ntfs_cur_offs]
        ja      @f
        ; return with nothing read
        and     [ntfs_cur_size], 0

  .okret:
        clc
        ret

    @@: ; reduce read length
        and     [ntfs_cur_tail], 0
        cmp     [ntfs_cur_size], eax
        jb      @f
        mov     [ntfs_cur_size], eax
        mov     eax, dword[ntfs_attr_size]
        and     eax, 0x1ff
        mov     [ntfs_cur_tail], eax

    @@: cmp     [ntfs_cur_size], 0
        jz      .okret
        mov     eax, [ntfs_cur_offs]
        xor     edx, edx
        div     [ntfs_data.sectors_per_cluster]
        sub     eax, [ecx + 0x10] ; first_vbo
        jb      .okret
        ; eax = cluster, edx = starting sector
        sub     esp, 0x10
        movzx   esi, word[ecx + 0x20] ; mcb_info_ofs
        add     esi, ecx
        xor     ebp, ebp

  .readloop:
        call    ntfs_decode_mcb_entry
        jnc     .break
        add     ebp, [esp + 8]
        sub     eax, [esp]
        jae     .readloop
        push    ecx
        push    eax
        add     eax, [esp + 8]
        add     eax, ebp
        imul    eax, [ntfs_data.sectors_per_cluster]
        add     eax, edx
        add     eax, dword[current_partition._.range.offset]
        pop     ecx
        neg     ecx
        imul    ecx, [ntfs_data.sectors_per_cluster]
        sub     ecx, edx
        cmp     ecx, [ntfs_cur_size]
        jb      @f
        mov     ecx, [ntfs_cur_size]

    @@: mov     ebx, [ntfs_cur_buf]

    @@: call    hd_read
        cmp     [hd_error], 0
        jnz     .errread2
        add     ebx, 0x200
        mov     [ntfs_cur_buf], ebx
        inc     eax
        add     [ntfs_cur_read], 0x200
        dec     [ntfs_cur_size]
        inc     [ntfs_cur_offs]
        loop    @b
        pop     ecx
        xor     eax, eax
        xor     edx, edx
        cmp     [ntfs_cur_size], 0
        jnz     .readloop
        add     esp, 0x10
        mov     eax, [ntfs_cur_tail]
        test    eax, eax
        jz      @f
        sub     eax, 0x200
        add     [ntfs_cur_read], eax

    @@: clc
        ret

  .errread2:
        pop     ecx
        add     esp, 0x10
        stc
        ret

  .break:
        add     esp, 0x10 ; CF=0
        mov     [ntfs_bCanContinue], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_read_file_record ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Read attr $DATA of $Mft, starting from eax*[ntfs_data.frs_size]
;-----------------------------------------------------------------------------------------------------------------------
;> eax = iRecord
;-----------------------------------------------------------------------------------------------------------------------
;< [ntfs_data.frs_buffer] contains information
;< eax = 0 (failed) or 1 (success)
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx
        mov     ecx, [ntfs_data.frs_size]
        mul     ecx
        shrd    eax, edx, 9
        shr     edx, 9
        jnz     .err
        push    [ntfs_attr_iRecord]
        push    [ntfs_attr_iBaseRecord]
        push    [ntfs_attr_offs]
        push    [ntfs_attr_list]
        push    dword[ntfs_attr_size + 4]
        push    dword[ntfs_attr_size]
        push    [ntfs_cur_iRecord]
        push    [ntfs_cur_attr]
        push    [ntfs_cur_offs]
        push    [ntfs_cur_size]
        push    [ntfs_cur_buf]
        push    [ntfs_cur_read]
        mov     [ntfs_cur_attr], 0x80 ; $DATA
        and     [ntfs_cur_iRecord], 0 ; $Mft
        mov     [ntfs_cur_offs], eax
        shr     ecx, 9
        mov     [ntfs_cur_size], ecx
        mov     eax, [ntfs_data.frs_buffer]
        mov     [ntfs_cur_buf], eax
        call    ntfs_read_attr
        mov     eax, [ntfs_cur_read]
        pop     [ntfs_cur_read]
        pop     [ntfs_cur_buf]
        pop     [ntfs_cur_size]
        pop     [ntfs_cur_offs]
        pop     [ntfs_cur_attr]
        pop     [ntfs_cur_iRecord]
        pop     dword[ntfs_attr_size]
        pop     dword[ntfs_attr_size + 4]
        pop     [ntfs_attr_list]
        pop     [ntfs_attr_offs]
        pop     [ntfs_attr_iBaseRecord]
        pop     [ntfs_attr_iRecord]
        pop     edx ecx
        jc      .errret
        cmp     eax, [ntfs_data.frs_size]
        jnz     .errret
        mov     eax, [ntfs_data.frs_buffer]
        cmp     dword[eax], 'FILE'
        jnz     .errret
        push    ebx
        mov     ebx, eax
        call    ntfs_restore_usa_frs
        pop     ebx
        setnc   al
        movzx   eax, al

  .ret:
        ret

  .err:
        pop     edx ecx

  .errret:
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_restore_usa_frs ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [ntfs_data.frs_size]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_restore_usa ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        shr     eax, 9
        mov     ecx, eax
        inc     eax
        cmp     [ebx + 6], ax
        jnz     .err
        movzx   eax, word[ebx + 4]
        lea     esi, [eax + ebx]
        lodsw
        mov     edx, eax
        lea     edi, [ebx + 0x1fe]

    @@: cmp     [edi], dx
        jnz     .err
        lodsw
        stosw
        add     edi, 0x1fe
        loop    @b
        popad
        clc
        ret

  .err:
        popad
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_decode_mcb_entry ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edi
        lea     edi, [esp + 16]
        xor     eax, eax
        lodsb
        test    al, al
        jz      .end
        mov     ecx, eax
        and     ecx, 0x0f
        cmp     ecx, 8
        ja      .end
        push    ecx
        rep
        movsb
        pop     ecx
        sub     ecx, 8
        neg     ecx
        cmp     byte[esi - 1], 0x80
        jae     .end
        push    eax
        xor     eax, eax
        rep
        stosb
        pop     ecx
        shr     ecx, 4
        cmp     ecx, 8
        ja      .end
        push    ecx
        rep
        movsb
        pop     ecx
        sub     ecx, 8
        neg     ecx
        cmp     byte[esi - 1], 0x80
        cmc
        sbb     eax, eax
        rep
        stosb
        stc

  .end:
        pop     edi ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_find_lfn ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi + ebp = pointer to name
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 1, file not found
;< if CF = 0,
;<   [ntfs_cur_iRecord] valid
;<   eax = pointer to record in parent directory
;-----------------------------------------------------------------------------------------------------------------------
        mov     [ntfs_cur_iRecord], 5   ; start parse from root cluster

  .doit2:
        mov     [ntfs_cur_attr], 0x90 ; $INDEX_ROOT
        and     [ntfs_cur_offs], 0
        mov     eax, [ntfs_data.cur_index_size]
        mov     [ntfs_cur_size], eax
        mov     eax, [ntfs_data.cur_index_buf]
        mov     [ntfs_cur_buf], eax
        call    ntfs_read_attr
        jnc     @f

  .ret:
        ret

    @@: cmp     [ntfs_cur_read], 0x20
        jc      .ret
        pushad
        mov     esi, [ntfs_data.cur_index_buf]
        mov     eax, [esi + 0x14]
        add     eax, 0x10
        cmp     [ntfs_cur_read], eax
        jae     .readok1
        add     eax, 0x1ff
        shr     eax, 9
        cmp     eax, [ntfs_data.cur_index_size]
        ja      @f

  .stc_ret:
        popad
        stc
        ret

    @@: ; reallocate
        push    eax
        push    [ntfs_data.cur_index_buf]
        call    kernel_free
        pop     eax
        mov     [ntfs_data.cur_index_size], eax
        push    eax
        call    kernel_alloc
        test    eax, eax
        jnz     @f
        and     [ntfs_data.cur_index_size], 0
        and     [ntfs_data.cur_index_buf], 0
        jmp     .stc_ret

    @@: mov     [ntfs_data.cur_index_buf], eax
        popad
        jmp     .doit2

  .readok1:
        mov     ebp, [esi + 8] ; subnode_size
        shr     ebp, 9
        cmp     ebp, [ntfs_data.cur_index_size]
        jbe     .ok2
        push    esi ebp
        push    ebp
        call    kernel_alloc
        pop     ebp esi
        test    eax, eax
        jz      .stc_ret
        mov     edi, eax
        mov     ecx, [ntfs_data.cur_index_size]
        shl     ecx, 9 - 2
        rep
        movsd
        mov     esi, eax
        mov     [ntfs_data.cur_index_size], ebp
        push    esi ebp
        push    [ntfs_data.cur_index_buf]
        call    kernel_free
        pop     ebp esi
        mov     [ntfs_data.cur_index_buf], esi

  .ok2:
        add     esi, 0x10
        mov     edi, [esp + 4]
        ; edi -> name, esi -> current index data, ebp = subnode size

  .scanloop:
        add     esi, [esi]

  .scanloopint:
        test    byte[esi + 0x0c], 2
        jnz     .subnode
        push    esi
        add     esi, 0x52
        movzx   ecx, byte[esi - 2]
        push    edi

    @@: lodsw
        call    unichar_toupper
        push    eax
        mov     al, [edi]
        inc     edi
        cmp     al, '/'
        jz      .slash
        call    char_toupper
        call    ansi2uni_char
        cmp     ax, [esp]
        pop     eax
        loopz   @b
        jz      .found
        pop     edi
        pop     esi
        jb      .subnode

  .scanloopcont:
        movzx   eax, word[esi + 8]
        add     esi, eax
        jmp     .scanloopint

  .slash:
        pop     eax
        pop     edi
        pop     esi

  .subnode:
        test    byte[esi + 0x0c], 1
        jz      .notfound
        movzx   eax, word[esi + 8]
        mov     eax, [esi + eax - 8]
        mul     [ntfs_data.sectors_per_cluster]
        mov     [ntfs_cur_offs], eax
        mov     [ntfs_cur_attr], 0xa0 ; $INDEX_ALLOCATION
        mov     [ntfs_cur_size], ebp
        mov     eax, [ntfs_data.cur_index_buf]
        mov     esi, eax
        mov     [ntfs_cur_buf], eax
        call    ntfs_read_attr
        mov     eax, ebp
        shl     eax, 9
        cmp     [ntfs_cur_read], eax
        jnz     .notfound
        cmp     dword[esi], 'INDX'
        jnz     .notfound
        mov     ebx, esi
        call    ntfs_restore_usa
        jc      .notfound
        add     esi, 0x18
        jmp     .scanloop

  .notfound:
        popad
        stc
        ret

  .found:
        cmp     byte[edi], 0
        jz      .done
        cmp     byte[edi], '/'
        jz      .next
        pop     edi
        pop     esi
        jmp     .scanloopcont

  .done:
  .next:
        pop     esi
        pop     esi
        mov     eax, [esi]
        mov     [ntfs_cur_iRecord], eax
        mov     [esp + regs_context32_t.eax], esi
        mov     [esp + regs_context32_t.esi], edi
        popad
        inc     esi
        cmp     byte[esi - 1], 0
        jnz     .doit2
        test    ebp, ebp
        jz      @f
        mov     esi, ebp
        xor     ebp, ebp
        jmp     .doit2

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.ntfs.read_file ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? read NTFS hard disk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to 64-bit number = first wanted byte, 0+
;> ecx = number of bytes to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = bytes read or -1 (file not found)
;-----------------------------------------------------------------------------------------------------------------------
;# if ebx = 0, start from first byte
;-----------------------------------------------------------------------------------------------------------------------
        call    ntfs_find_lfn
        jc      fs.error.file_not_found

        mov     [ntfs_cur_attr], 0x80 ; $DATA
        and     [ntfs_cur_offs], 0
        and     [ntfs_cur_size], 0
        call    ntfs_read_attr
        jc      fs.error.access_denied

        pushad
        and     [esp + regs_context32_t.ebx], 0
        xor     eax, eax
        test    ebx, ebx
        jz      .zero1
        cmp     dword[ebx + 4], 0x200
        jb      @f

  .eof0:
        popad
        xor     ebx, ebx

  .eof:
        push    ERROR_END_OF_FILE
        pop     eax
        ret

    @@: mov     eax, [ebx]
        test    eax, 0x1ff
        jz      .alignedstart
        push    edx
        mov     edx, [ebx + 4]
        shrd    eax, edx, 9
        pop     edx
        mov     [ntfs_cur_offs], eax
        mov     [ntfs_cur_size], 1
        mov     [ntfs_cur_buf], ntfs_bitmap_buf
        call    ntfs_read_attr.continue
        mov     eax, [ebx]
        and     eax, 0x1ff
        lea     esi, [ntfs_bitmap_buf + eax]
        sub     eax, [ntfs_cur_read]
        jae     .eof0
        neg     eax
        push    ecx
        cmp     ecx, eax
        jb      @f
        mov     ecx, eax

    @@: mov     [esp + 4 + regs_context32_t.ebx], ecx
        mov     edi, edx
        rep
        movsb
        mov     edx, edi
        pop     ecx
        sub     ecx, [esp + regs_context32_t.ebx]
        jnz     @f

  .retok:
        popad
        xor     eax, eax
        ret

    @@: cmp     [ntfs_cur_read], 0x200
        jz      .alignedstart

  .eof_ebx:
        popad
        jmp     .eof

  .alignedstart:
        mov     eax, [ebx]
        push    edx
        mov     edx, [ebx + 4]
        add     eax, 511
        adc     edx, 0
        shrd    eax, edx, 9
        pop     edx

  .zero1:
        mov     [ntfs_cur_offs], eax
        mov     [ntfs_cur_buf], edx
        mov     eax, ecx
        shr     eax, 9
        mov     [ntfs_cur_size], eax
        add     eax, [ntfs_cur_offs]
        push    eax
        call    ntfs_read_attr.continue
        pop     [ntfs_cur_offs]
        mov     eax, [ntfs_cur_read]
        add     [esp + regs_context32_t.ebx], eax
        mov     eax, ecx
        and     eax, not 0x1ff
        cmp     [ntfs_cur_read], eax
        jnz     .eof_ebx
        and     ecx, 0x1ff
        jz      .retok
        add     edx, [ntfs_cur_read]
        mov     [ntfs_cur_size], 1
        mov     [ntfs_cur_buf], ntfs_bitmap_buf
        call    ntfs_read_attr.continue
        cmp     [ntfs_cur_read], ecx
        jb      @f
        mov     [ntfs_cur_read], ecx

    @@: xchg    ecx, [ntfs_cur_read]
        push    ecx
        mov     edi, edx
        mov     esi, ntfs_bitmap_buf
        add     [esp + 4 + regs_context32_t.ebx], ecx
        rep
        movsb
        pop     ecx
        xor     eax, eax
        cmp     ecx, [ntfs_cur_read]
        jz      @f
        mov     al, ERROR_END_OF_FILE

    @@: mov     [esp + regs_context32_t.eax], eax
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.ntfs.read_directory ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? read NTFS hard disk folder
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to structure 32-bit number = first wanted block, 0+ & flags (bitfields)
;> ecx = number of blocks to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = blocks read or -1 (folder not found)
;-----------------------------------------------------------------------------------------------------------------------
;# flags:
;#   bit 0: 0 (ANSI names) or 1 (UNICODE names)
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, 5 ; root cluster
        cmp     byte[esi], 0
        jz      .doit
        call    ntfs_find_lfn
        jnc     .doit2

        jmp     fs.error.file_not_found

  .pop_ret:
        pop     eax
        ret

  .doit:
        mov     [ntfs_cur_iRecord], eax

  .doit2:
        mov     [ntfs_cur_attr], 0x10 ; $STANDARD_INFORMATION
        and     [ntfs_cur_offs], 0
        mov     [ntfs_cur_size], 1
        mov     [ntfs_cur_buf], ntfs_bitmap_buf
        call    ntfs_read_attr
        jc      fs.error.file_not_found

        mov     [ntfs_cur_attr], 0x90 ; $INDEX_ROOT
        and     [ntfs_cur_offs], 0
        mov     eax, [ntfs_data.cur_index_size]
        mov     [ntfs_cur_size], eax
        mov     eax, [ntfs_data.cur_index_buf]
        mov     [ntfs_cur_buf], eax
        call    ntfs_read_attr
        jnc     .ok
        cmp     [hd_error], 0
        jz      fs.error.file_not_found
        or      ebx, -1
        push    ERROR_DEVICE_FAIL
        jmp     .pop_ret

  .ok:
        cmp     [ntfs_cur_read], 0x20
        jae     @f
        or      ebx, -1

  .fserr:
        push    ERROR_FAT_TABLE
        jmp     .pop_ret

    @@: pushad
        mov     esi, [ntfs_data.cur_index_buf]
        mov     eax, [esi + 0x14]
        add     eax, 0x10
        cmp     [ntfs_cur_read], eax
        jae     .readok1
        add     eax, 0x1ff
        shr     eax, 9
        cmp     eax, [ntfs_data.cur_index_size]
        ja      @f
        popad
        jmp     .fserr

    @@: ; reallocate
        push    eax
        push    [ntfs_data.cur_index_buf]
        call    kernel_free
        pop     eax
        mov     [ntfs_data.cur_index_size], eax
        push    eax
        call    kernel_alloc
        test    eax, eax
        jnz     @f
        and     [ntfs_data.cur_index_size], 0
        and     [ntfs_data.cur_index_buf], 0

  .nomem:
        popad
        or      ebx, -1
        push    ERROR_ALLOC
        pop     eax
        ret

    @@: mov     [ntfs_data.cur_index_buf], eax
        popad
        jmp     .doit2

  .readok1:
        mov     ebp, [esi + 8] ; subnode_size
        shr     ebp, 9
        cmp     ebp, [ntfs_data.cur_index_size]
        jbe     .ok2
        push    esi ebp
        push    ebp
        call    kernel_alloc
        pop     ebp esi
        test    eax, eax
        jz      .nomem
        mov     edi, eax
        mov     ecx, [ntfs_data.cur_index_size]
        shl     ecx, 9 - 2
        rep
        movsd
        mov     esi, eax
        mov     [ntfs_data.cur_index_size], ebp
        push    esi ebp
        push    [ntfs_data.cur_index_buf]
        call    kernel_free
        pop     ebp esi
        mov     [ntfs_data.cur_index_buf], esi

  .ok2:
        add     esi, 0x10
        mov     ebx, [esp + regs_context32_t.ebx]
        mov     edx, [esp + regs_context32_t.edx]
        push    dword[ebx + 4] ; read ANSI/UNICODE name
        mov     ebx, [ebx]
        ; init header
        mov     edi, edx
        mov     ecx, sizeof.fs.file_info_header_t / 4
        xor     eax, eax
        rep
        stosd
        mov     byte[edx + fs.file_info_header_t.version], 1 ; version
        mov     ecx, [esp + 4 + regs_context32_t.ecx]
        push    edx
        mov     edx, esp
        ; edi -> BDFE, esi -> current index data, ebp = subnode size, ebx = first wanted block,
        ; ecx = number of blocks to read
        ; edx -> parameters block: dd <output>, dd <flags>
        cmp     [ntfs_cur_iRecord], 5
        jz      .skip_specials
        ; dot and dotdot entries
        push    esi
        xor     esi, esi
        call    .add_special_entry
        inc     esi
        call    .add_special_entry
        pop     esi

  .skip_specials:
        ; at first, dump index root
        add     esi, [esi]

  .dump_root:
        test    byte[esi + 0x0c], 2
        jnz     .dump_root_done
        call    .add_entry
        movzx   eax, word[esi + 8]
        add     esi, eax
        jmp     .dump_root

  .dump_root_done:
        ; now dump all subnodes
        push    ecx edi
        mov     edi, ntfs_bitmap_buf
        mov     [ntfs_cur_buf], edi
        mov     ecx, 0x400 / 4
        xor     eax, eax
        rep
        stosd
        mov     [ntfs_cur_attr], 0xb0 ; $BITMAP
        and     [ntfs_cur_offs], 0
        mov     [ntfs_cur_size], 2
        call    ntfs_read_attr
        pop     edi ecx
        push    0 ; save offset in $BITMAP attribute
        and     [ntfs_cur_offs], 0

  .dumploop:
        mov     [ntfs_cur_attr], 0xa0
        mov     [ntfs_cur_size], ebp
        mov     eax, [ntfs_data.cur_index_buf]
        mov     esi, eax
        mov     [ntfs_cur_buf], eax
        push    [ntfs_cur_offs]
        mov     eax, [ntfs_cur_offs]
        imul    eax, ebp
        mov     [ntfs_cur_offs], eax
        call    ntfs_read_attr
        pop     [ntfs_cur_offs]
        mov     eax, ebp
        shl     eax, 9
        cmp     [ntfs_cur_read], eax
        jnz     .done
        push    eax
        mov     eax, [ntfs_cur_offs]
        and     eax, 0x400 * 8 - 1
        bt      dword[ntfs_bitmap_buf], eax
        pop     eax
        jnc     .dump_subnode_done
        cmp     dword[esi], 'INDX'
        jnz     .dump_subnode_done
        push    ebx
        mov     ebx, esi
        call    ntfs_restore_usa
        pop     ebx
        jc      .dump_subnode_done
        add     esi, 0x18
        add     esi, [esi]

  .dump_subnode:
        test    byte[esi + 0x0c], 2
        jnz     .dump_subnode_done
        call    .add_entry
        movzx   eax, word[esi + 8]
        add     esi, eax
        jmp     .dump_subnode

  .dump_subnode_done:
        inc     [ntfs_cur_offs]
        test    [ntfs_cur_offs], 0x400 * 8 - 1
        jnz     .dumploop
        mov     [ntfs_cur_attr], 0xb0
        push    ecx edi
        mov     edi, ntfs_bitmap_buf
        mov     [ntfs_cur_buf], edi
        mov     ecx, 0x400 / 4
        xor     eax, eax
        rep
        stosd
        pop     edi ecx
        pop     eax
        push    [ntfs_cur_offs]
        inc     eax
        mov     [ntfs_cur_offs], eax
        mov     [ntfs_cur_size], 2
        push    eax
        call    ntfs_read_attr
        pop     eax
        pop     [ntfs_cur_offs]
        push    eax
        jmp     .dumploop

  .done:
        pop     eax
        pop     edx
        mov     ebx, [edx + 4]
        pop     edx
        xor     eax, eax
        dec     ecx
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: mov     [esp + regs_context32_t.eax], eax
        mov     [esp + regs_context32_t.ebx], ebx
        popad
        ret

  .add_special_entry:
        mov     eax, [edx]
        inc     [eax + fs.file_info_header_t.files_count] ; new file found
        dec     ebx
        jns     .ret
        dec     ecx
        js      .ret
        inc     [eax + fs.file_info_header_t.files_read] ; new file block copied
        mov     eax, [edx + 4]
        mov     [edi + fs.file_info_t.flags], eax
;       mov     eax, dword[ntfs_bitmap_buf+0x20]
;       or      al, 0x10
        mov     eax, FS_INFO_ATTR_DIR
        stosd
        scasd
        push    edx
        mov     eax, dword[ntfs_bitmap_buf]
        mov     edx, dword[ntfs_bitmap_buf + 4]
        call    ntfs_datetime_to_bdfe
        mov     eax, dword[ntfs_bitmap_buf + 0x18]
        mov     edx, dword[ntfs_bitmap_buf + 0x1c]
        call    ntfs_datetime_to_bdfe
        mov     eax, dword[ntfs_bitmap_buf + 8]
        mov     edx, dword[ntfs_bitmap_buf + 0x0c]
        call    ntfs_datetime_to_bdfe
        pop     edx
        xor     eax, eax
        stosd
        stosd
        mov     al, '.'
        push    edi ecx
        lea     ecx, [esi + 1]
        test    byte[edi - fs.file_info_t.name + fs.file_info_t.flags], 1
        jz      @f
        rep
        stosw
        pop     ecx
        xor     eax, eax
        stosw
        pop     edi
        add     edi, 520
        ret

    @@: rep
        stosb
        pop     ecx
        xor     eax, eax
        stosb
        pop     edi
        add     edi, 264

  .ret:
        ret

  .add_entry:
        ; do not return DOS 8.3 names
        cmp     byte[esi + 0x51], 2
        jz      .ret
        ; do not return system files
        ; ... note that there will be no bad effects if system files also were reported ...
        cmp     dword[esi], 0x10
        jb      .ret
        mov     eax, [edx]
        inc     [eax + fs.file_info_header_t.files_count] ; new file found
        dec     ebx
        jns     .ret
        dec     ecx
        js      .ret
        inc     [eax + fs.file_info_header_t.files_read] ; new file block copied
        mov     eax, [edx + 4] ; flags
        call    ntfs_direntry_to_bdfe
        push    ecx esi edi
        movzx   ecx, byte[esi + 0x50]
        add     esi, 0x52
        test    byte[edi - fs.file_info_t.name + fs.file_info_t.flags], 1
        jz      .ansi
        shr     ecx, 1
        rep
        movsd
        adc     ecx, ecx
        rep
        movsw
        and     word[edi], 0
        pop     edi
        add     edi, 520
        pop     esi ecx
        ret

  .ansi:
        jecxz   .skip

    @@: lodsw
        call    uni2ansi_char
        stosb
        loop    @b

  .skip:
        xor     al, al
        stosb
        pop     edi
        add     edi, 264
        pop     esi ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_direntry_to_bdfe ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [edi + 4], eax    ; ANSI/UNICODE name
        mov     eax, [esi + 0x48]
        test    eax, 0x10000000
        jz      @f
        and     eax, not 0x10000000
        or      al, 0x10

    @@: stosd
        scasd
        push    edx
        mov     eax, [esi + 0x18]
        mov     edx, [esi + 0x1c]
        call    ntfs_datetime_to_bdfe
        mov     eax, [esi + 0x30]
        mov     edx, [esi + 0x34]
        call    ntfs_datetime_to_bdfe
        mov     eax, [esi + 0x20]
        mov     edx, [esi + 0x24]
        call    ntfs_datetime_to_bdfe
        pop     edx
        mov     eax, [esi + 0x40]
        stosd
        mov     eax, [esi + 0x44]
        stosd
        ret
kendp

iglobal
  _24         dd 24
  _60         dd 60
  _10000000   dd 10000000
  days400year dd 365 * 400 + 100 - 4 + 1
  days100year dd 365 * 100 + 25 - 1
  days4year   dd 365 * 4 + 1
  days1year   dd 365
  months      dd 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
  months2     dd 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
  _400        dd 400
  _100        dd 100
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc ntfs_datetime_to_bdfe ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edx:eax = number of 100-nanosecond intervals since January 1, 1601, in UTC
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, edx
        xor     edx, edx
        div     [_10000000]
        xchg    eax, [esp]
        div     [_10000000]
        pop     edx

  .sec:
        ; edx:eax = number of seconds since January 1, 1601
        push    eax
        mov     eax, edx
        xor     edx, edx
        div     [_60]
        xchg    eax, [esp]
        div     [_60]
        mov     [edi + fs.file_date_time_t.sec], dl
        pop     edx
        ; edx:eax = number of minutes
        div     [_60]
        mov     [edi + fs.file_date_time_t.min], dl
        ; eax = number of hours (note that 2^64/(10^7*60*60) < 2^32)
        xor     edx, edx
        div     [_24]
        mov     [edi + fs.file_date_time_t.hour], dl
        mov     byte[edi + fs.file_date_time_t.time + 3], 0
        ; eax = number of days since January 1, 1601
        xor     edx, edx
        div     [days400year]
        imul    eax, 400
        add     eax, 1601
        mov     [edi + fs.file_date_time_t.year], ax
        mov     eax, edx
        xor     edx, edx
        div     [days100year]
        cmp     al, 4
        jnz     @f
        dec     eax
        add     edx, [days100year]

    @@: imul    eax, 100
        add     [edi + fs.file_date_time_t.year], ax
        mov     eax, edx
        xor     edx, edx
        div     [days4year]
        shl     eax, 2
        add     [edi + fs.file_date_time_t.year], ax
        mov     eax, edx
        xor     edx, edx
        div     [days1year]
        cmp     al, 4
        jnz     @f
        dec     eax
        add     edx, [days1year]

    @@: add     [edi + fs.file_date_time_t.year], ax
        push    esi edx
        mov     esi, months
        movzx   eax, [edi + fs.file_date_time_t.year]
        test    al, 3
        jnz     .noleap
        xor     edx, edx
        push    eax
        div     [_400]
        pop     eax
        test    edx, edx
        jz      .leap
        xor     edx, edx
        div     [_100]
        test    edx, edx
        jz      .noleap

  .leap:
        mov     esi, months2

  .noleap:
        pop     edx
        xor     eax, eax
        inc     eax

    @@: sub     edx, [esi]
        jb      @f
        add     esi, 4
        inc     eax
        jmp     @b

    @@: add     edx, [esi]
        pop     esi
        inc     edx
        mov     [edi + fs.file_date_time_t.day], dl
        mov     [edi + fs.file_date_time_t.month], al
        add     edi, sizeof.fs.file_date_time_t
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.ntfs.get_file_info ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jnz     @f

        push    ERROR_NOT_IMPLEMENTED
        pop     eax
        ret

    @@: call    ntfs_find_lfn
        jnc     .doit
        cmp     [hd_error], 0
        jz      fs.error.file_not_found

        push    ERROR_DEVICE_FAIL
        pop     eax
        ret

  .doit:
        push    esi edi
        mov     esi, eax
        mov     edi, edx
        xor     eax, eax
        call    ntfs_direntry_to_bdfe
        pop     edi esi
        xor     eax, eax
        ret
kendp
