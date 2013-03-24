;;======================================================================================================================
;;///// fat16.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2012 Ostin project <http://ostin.googlecode.com/>
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

struct fs.fat.fat16.partition_t fs.fat.partition_t
  root_dir_size        dd ? ; in sectors
  max_cluster          dd ?
  sectors_cache        rb 3 * 512
  cached_sector_number dd ?
  cached_sectors_count dd ?
  dirty_sectors        rb 3
ends

iglobal
  JumpTable fs.fat.fat16, vftbl, , \
    allocate_cluster, \
    get_next_cluster, \
    get_or_allocate_next_cluster, \
    check_for_enough_clusters, \
    delete_chain, \
    flush
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16.create_from_base ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (base)
;> ecx @= BPB version, pack[16(0), 8(major), 8(minor)]
;> edi ^= BPB
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "fs.fat.fat16.create_from_base\n"

        ; support only BPB v4.0
        cmp     ecx, 0x0400
        jne     .error

        ; support only 512 bytes per sector, 1 sector per cluster
;       KLog    LOG_DEBUG, "  sector_size = %u\n", [edi + bpb_v4_0_t.sector_size]:2
        cmp     [edi + bpb_v4_0_t.sector_size], 512
        jne     .error
;       KLog    LOG_DEBUG, "  cluster_size = %u\n", [edi + bpb_v4_0_t.cluster_size]:1
        cmp     [edi + bpb_v4_0_t.cluster_size], 1
        jne     .error

        mov     eax, sizeof.fs.fat.fat16.partition_t
        call    fs.create_from_base
        test    eax, eax
        jz      .error

        mov     [eax + fs.fat.fat16.partition_t._.vftbl], fs.fat.vftbl
        mov     [eax + fs.fat.fat16.partition_t.fat_vftbl], fs.fat.fat16.vftbl

        movzx   ecx, [edi + bpb_v4_0_t.resvd_sector_count]
        mov     [eax + fs.fat.fat16.partition_t.fat_sector], ecx
;       KLog    LOG_DEBUG, "  fat_sector = %u\n", ecx

        movzx   edx, [edi + bpb_v4_0_t.fat_size_16]
        mov     [eax + fs.fat.fat16.partition_t.fat_size], edx
;       KLog    LOG_DEBUG, "  fat_size = %u\n", edx

        lea     ecx, [ecx + edx * 2]
        mov     [eax + fs.fat.fat16.partition_t.root_dir_sector], ecx
;       KLog    LOG_DEBUG, "  root_dir_sector = %u\n", ecx

        shl     edx, 9 - 1 ; * 512 / 2
        add     edx, 2
        mov     [eax + fs.fat.fat16.partition_t.max_cluster], edx
;       KLog    LOG_DEBUG, "  max_cluster = %u\n", edx

        movzx   edx, [edi + bpb_v4_0_t.fat_root_dir_entry_count]
        shl     edx, 5 ; * sizeof.fs.fat.dir_entry_t
        add     edx, 512 - 1
        shr     edx, 9
        mov     [eax + fs.fat.fat16.partition_t.root_dir_size], edx
;       KLog    LOG_DEBUG, "  root_dir_size = %u\n", edx

        add     ecx, edx
        mov     [eax + fs.fat.fat16.partition_t.data_area_sector], ecx
;       KLog    LOG_DEBUG, "  data_area_sector = %u\n", ecx

        movzx   ecx, [edi + bpb_v4_0_t.cluster_size]
        mov     [eax + fs.fat.fat16.partition_t.cluster_size], ecx

        ret

  .error:
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16.allocate_cluster ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Finds free cluster in FAT and marks it as EOF.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= allocated cluster sector number (ok) or FS error code (fail)
;< ecx #= number of sectors per cluster
;< edx #= allocated cluster number
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.fat16.allocate_cluster()\n"

        mov     ecx, [ebx + fs.fat.fat16.partition_t.fat_size]
        shl     ecx, 9 - 1 ; * 512 (sector size) / 2 (FAT entry size) = number of FAT entries

        push    edi
        push    ecx
        push    [ebx + fs.fat.fat16.partition_t.fat_sector]

  .fetch:
        push    ecx
        mov     ecx, 2
        mov     eax, [esp + 4]
        call    fs.fat.fat16._.fetch_sectors
        pop     ecx
        jc      .device_error

        mov     edx, 512 / 2 * 2 + 1 ; sector size / FAT entry size * sectors count + 1
        add     dword[esp], 3

  .next_cluster:
        dec     edx
        jz      .fetch

        cmp     word[edi], 0
        je      .free

        add     edi, 2
        dec     ecx
        jz      .disk_full_error
        jmp     .next_cluster

  .free:
        or      word[edi], 0x0ffff
        call    fs.fat.fat16._.mark_cluster_sectors_dirty

        add     esp, 4
        pop     edx edi

        sub     edx, ecx
        mov     eax, edx
        call    fs.fat.util.cluster_to_sector
        mov     ecx, [ebx + fs.fat.fat16.partition_t.cluster_size]
;       KLog    LOG_DEBUG, "FAT16 alloc: %u 0x%x\n", eax, edx
        clc
        ret

  .disk_full_error:
        add     esp, 8
        pop     edi
        mov     eax, ERROR_DISK_FULL
        stc
        ret

  .device_error:
        add     esp, 8
        pop     edi
        mov     eax, ERROR_DEVICE_FAIL
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16.get_next_cluster ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Finds next cluster sector in FAT chain. Takes fat16 root directory special case into account.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= current cluster sector number
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= next cluster sector number (ok) or FS error code (fail)
;< ecx #= number of sectors per cluster (for sectors in data area) or 1 (for sectors in root directory)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.fat16.get_next_cluster(%u 0x%x)\n", eax, eax

        mov     ecx, [ebx + fs.fat.fat16.partition_t.root_dir_sector]
        sub     eax, ecx
        jb      .access_denied_error
        cmp     eax, [ebx + fs.fat.fat16.partition_t.root_dir_size]
        jae     .not_root_dir

        ; current sector is within root directory, next sector is right after this one
        inc     eax
        cmp     eax, [ebx + fs.fat.fat16.partition_t.root_dir_size]
        je      .end_of_chain_error

        add     eax, ecx
        xor     ecx, ecx ; cF = 0
        inc     ecx
        ret

  .not_root_dir:
        push    edi

        add     eax, ecx
        sub     eax, [ebx + fs.fat.fat16.partition_t.data_area_sector]
        jb      .access_denied_error

        push    edx
        xor     edx, edx
        div     [ebx + fs.fat.fat16.partition_t.cluster_size]
        pop     edx
        add     eax, 2

        shl     eax, 1 ; * 2

        mov     ecx, eax
        and     ecx, (1 shl 9) - 1 ; % 512, FAT entry offset
        push    ecx

        shr     eax, 9 ; / 512, FAT sector
        add     eax, [ebx + fs.fat.fat16.partition_t.fat_sector] ; + FAT start sector

        MovStk  ecx, 1
        call    fs.fat.fat16._.fetch_sectors
        jc      .device_error_2

        pop     eax
        movzx   eax, word[edi + eax]

  .exit:
        pop     edi

        cmp     eax, 0x0fff8
        jae     .end_of_chain_error
        cmp     eax, 0x0fff0
        jae     .device_error
        cmp     eax, 2
        jb      .device_error

        call    fs.fat.util.cluster_to_sector
        mov     ecx, [ebx + fs.fat.fat16.partition_t.cluster_size]
;       KLog    LOG_DEBUG, "FAT16 next: %u\n", eax
        clc
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        stc
        ret

  .end_of_chain_error:
        mov     eax, ERROR_END_OF_FILE
        stc
        ret

  .device_error_2:
        add     esp, 4
        pop     edi

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16.get_or_allocate_next_cluster ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Finds next cluster sector in FAT chain. If current cluster is EOF, allocates new cluster and adds it to the chain.
;? Takes fat16 root directory special case into account.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= current cluster sector number
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= next (or newly allocated) cluster sector number (ok) or FS error code (fail)
;< ecx #= number of sectors per cluster (for sectors in data area) or 1 (for sectors in root directory)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.fat16.get_or_allocate_next_cluster(0x%x)\n", eax

        mov     ecx, [ebx + fs.fat.fat16.partition_t.root_dir_sector]
        sub     eax, ecx
        jb      .access_denied_error
        cmp     eax, [ebx + fs.fat.fat16.partition_t.root_dir_size]
        jae     .not_root_dir
 
        ; current sector is within root directory, next sector is right after this one
        inc     eax
        cmp     eax, [ebx + fs.fat.fat16.partition_t.root_dir_size]
        je      .disk_full_error
 
        add     eax, ecx
        xor     ecx, ecx ; cF = 0
        inc     ecx
        ret
 
  .not_root_dir:
        add     eax, ecx
        cmp     eax, [ebx + fs.fat.fat16.partition_t.data_area_sector]
        jb      .access_denied_error

        push    eax
        call    fs.fat.fat16.get_next_cluster
        jnc     .exit

        cmp     eax, ERROR_END_OF_FILE
        jne     .other_error

        call    fs.fat.fat16.allocate_cluster
        jc      .other_error

        push    eax
        mov     eax, [esp + 4]
        call    fs.fat.fat16._.set_cluster
        jc      .other_error_2

        pop     eax
        mov     ecx, [ebx + fs.fat.fat16.partition_t.cluster_size]

  .exit:
        add     esp, 4 ; cF = 0
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        stc
        ret
 
  .disk_full_error:
        mov     eax, ERROR_DISK_FULL
        stc
        ret

  .other_error_2:
        add     esp, 4

  .other_error:
        add     esp, 4
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16.check_for_enough_clusters ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= needed free clusters count
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.fat16.check_for_enough_clusters(%u)\n", eax

        KLog    LOG_ERROR, "FIXME: not implemented: fs.fat.fat16.check_for_enough_clusters\n"
        mov     eax, ERROR_NOT_IMPLEMENTED
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16.delete_chain ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= start cluster sector number
;> edx ~= 0 (mark first cluster free) or not 0 (mark first cluster EOF)
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.fat16.delete_chain(0x%x, 0x%x)\n", eax:3, edx:3

        cmp     eax, [ebx + fs.fat.fat16.partition_t.data_area_sector]
        jb      .access_denied_error

        test    edx, edx
        jz      .next_cluster

        mov     edx, 0x0ffff

  .next_cluster:
        push    eax edx

        call    fs.fat.fat16.get_next_cluster
        jnc     .set_cluster

        cmp     eax, ERROR_END_OF_FILE
        jne     .error_3
        jmp     .set_last_cluster

  .set_cluster:
        pop     edx
        xchg    eax, [esp]

;       KLog    LOG_DEBUG, "FAT16 free: %u 0x%x\n", eax, edx
        call    fs.fat.fat16._.set_cluster
        jc      .error_2

        pop     eax
        xor     edx, edx
        jmp     .next_cluster

  .set_last_cluster:
        pop     edx eax
;       KLog    LOG_DEBUG, "FAT16 free: %u 0x%x (last)\n", eax, edx
        call    fs.fat.fat16._.set_cluster
        jc      .error

        clc
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        stc
        ret

  .error_3:
        add     esp, 4

  .error_2:
        add     esp, 4

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16.flush ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "fs.fat.fat16.flush()\n"

        call    fs.fat.fat16._.flush_dirty_sectors
        jc      .device_error

        ret

  .device_error:
;       KLog    LOG_DEBUG, "  device error\n"
        mov     eax, ERROR_DEVICE_FAIL
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16._.fetch_sectors ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Fetches sector(s) to internal buffer (if not already there). Flushes existing sector(s) if they are modified.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= sector number
;> ecx #= sectors count (1..3)
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< edi ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "  fs.fat.fat16._.fetch_sectors(0x%x, %u)\n", eax, ecx

        mov     edi, ebx
        cmp     eax, [ebx + fs.fat.fat16.partition_t.cached_sector_number]
        jne     .fetch
        cmp     ecx, [ebx + fs.fat.fat16.partition_t.cached_sectors_count]
        ja      .fetch

        jmp     .exit

  .fetch:
        call    fs.fat.fat16._.flush_dirty_sectors
        jc      .error

        push    eax ecx edx
        xor     edx, edx
        add     edi, fs.fat.fat16.partition_t.sectors_cache
        call    fs.read
        test    eax, eax
        pop     edx ecx eax
        jnz     .error

        add     edi, -fs.fat.fat16.partition_t.sectors_cache

        mov     [edi + fs.fat.fat16.partition_t.cached_sector_number], eax
        mov     [edi + fs.fat.fat16.partition_t.cached_sectors_count], ecx

  .exit:
        add     edi, fs.fat.fat16.partition_t.sectors_cache
        clc
        ret

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16._.flush_dirty_sectors ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx esi

;       KLog    LOG_DEBUG, "  fs.fat.fat16._.flush_dirty_sectors(0x%x, %u)\n", \
;               [ebx + fs.fat.fat16.partition_t.cached_sector_number], \
;               [ebx + fs.fat.fat16.partition_t.cached_sectors_count]

        xor     eax, eax
        call    .flush_sector_if_dirty
        jc      .exit

        inc     eax
        call    .flush_sector_if_dirty
        jc      .exit

        inc     eax
        call    .flush_sector_if_dirty

  .exit:
        pop     esi ecx eax
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .flush_sector_if_dirty: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        test    [ebx + fs.fat.fat16.partition_t.dirty_sectors + eax], 1
        jz      @f

        push    eax ecx edx esi
        shl     eax, 9
        lea     ecx, [ebx + fs.fat.fat16.partition_t.sectors_cache + eax]
        shr     eax, 9
        add     eax, [ebx + fs.fat.fat16.partition_t.cached_sector_number]
        xor     edx, edx
        mov     esi, ecx
        MovStk  ecx, 1
        call    fs.write
        pop     esi edx ecx eax
        jc      @f

        and     [ebx + fs.fat.fat16.partition_t.dirty_sectors + eax], 0 ; cF = 0

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16._.mark_cluster_sectors_dirty ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? ...
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.fat16.partition_t
;> edi ^= cluster inside cached sector
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        sub     edi, ebx
        add     edi, -fs.fat.fat16.partition_t.sectors_cache
        shr     edi, 9

;       KLog    LOG_DEBUG, "  fs.fat.fat16._.mark_cluster_sectors_dirty(0x%x)\n", edi

        or      [ebx + fs.fat.fat16.partition_t.dirty_sectors + edi], 1
        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat16._.set_cluster ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= cluster sector number
;> edx #= value
;> ebx ^= fs.fat.fat16.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       KLog    LOG_DEBUG, "  fs.fat.fat16._.set_cluster(0x%x, 0x%x)\n", eax, edx

        ; validate cluster sector number
        sub     eax, [ebx + fs.fat.fat16.partition_t.data_area_sector]
        jb      .access_denied_error

        push    edx
        xor     edx, edx
        div     [ebx + fs.fat.fat16.partition_t.cluster_size]
        pop     edx

        cmp     eax, [ebx + fs.fat.fat16.partition_t.max_cluster]
        ja      .access_denied_error

        add     eax, 2

        ; validate value
        test    edx, edx
        jz      @f
        cmp     edx, 2
        jb      .access_denied_error
        cmp     edx, [ebx + fs.fat.fat16.partition_t.max_cluster]
        jbe     @f
        cmp     edx, 0x0fff7
        jb      .access_denied_error
        cmp     edx, 0x0ffff
        ja      .access_denied_error
        cmp     edx, eax
        je      .access_denied_error

    @@: push    eax ecx edi
        push    eax

        shl     eax, 1 ; * 2

        mov     ecx, eax
        and     ecx, (1 shl 9) - 1 ; % 512, FAT entry offset
        push    ecx

        shr     eax, 9 ; / 512, FAT sector
        add     eax, [ebx + fs.fat.fat16.partition_t.fat_sector] ; + FAT start sector

        MovStk  ecx, 1
        call    fs.fat.fat16._.fetch_sectors
        jc      .device_error

        pop     eax ecx
        add     edi, eax
        mov     [edi], dx

        call    fs.fat.fat16._.mark_cluster_sectors_dirty
        pop     edi ecx eax
        clc
        ret

  .access_denied_error:
        mov     eax, ERROR_ACCESS_DENIED
        stc
        ret

  .device_error:
        pop     edi ecx eax
        mov     eax, ERROR_DEVICE_FAIL
        stc
        ret
kendp
