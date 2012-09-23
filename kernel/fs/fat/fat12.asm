;;======================================================================================================================
;;///// fat12.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

struct fs.fat.fat12.partition_t fs.fat.partition_t
  root_dir_size        dd ? ; in sectors
  max_cluster          dd ?
  sectors_cache        rb 3 * 512
  cached_sector_number dd ?
  cached_sectors_count dd ?
  dirty_sectors        rb 3
ends

iglobal
  jump_table fs.fat.fat12, vftbl, , \
    allocate_cluster, \
    get_next_cluster, \
    get_or_allocate_next_cluster, \
    check_for_enough_clusters, \
    delete_chain, \
    flush
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12.create_from_base ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (base)
;> ecx @= BPB version, pack[16(0), 8(major), 8(minor)]
;> edi ^= BPB
;-----------------------------------------------------------------------------------------------------------------------
        klog_   LOG_DEBUG, "fs.fat.fat12.create_from_base\n"

        mov     eax, sizeof.fs.fat.fat12.partition_t
        call    fs.create_from_base
        test    eax, eax
        jz      .error

        mov     [eax + fs.fat.partition_t._.vftbl], fs.fat.vftbl
        mov     [eax + fs.fat.fat12.partition_t.fat_vftbl], fs.fat.fat12.vftbl

  .error:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12.allocate_cluster ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Finds free cluster in FAT and marks it as EOF.
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= allocated cluster sector number (ok) or FS error code (fail)
;< ecx #= number of sectors per cluster
;< edx #= allocated cluster number
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "fs.fat.fat12.allocate_cluster()\n"

        mov     eax, [ebx + fs.fat.fat12.partition_t.fat_size]
        shl     eax, 9 + 1
        xor     edx, edx
        mov     ecx, 3
        div     ecx
        mov     ecx, eax

        push    edi
        push    ecx
        push    [ebx + fs.fat.fat12.partition_t.fat_sector]

  .fetch:
        push    ecx
        mov     ecx, 3
        mov     eax, [esp + 4]
        call    fs.fat.fat12._.fetch_sectors
        pop     ecx
        jc      .device_error

        mov     edx, 512 + 1 ; sector size / FAT entry size * sectors count / clusters per cycle + 1
        add     dword[esp], 3

  .next_triplet:
        dec     edx
        jz      .fetch

        mov     eax, [edi]

        test    eax, 0x00000fff
        jz      .low_free

        dec     ecx
        jz      .disk_full_error

        test    eax, 0x00fff000
        jz      .high_free

        add     edi, 3
        dec     ecx
        jz      .disk_full_error
        jmp     .next_triplet

  .low_free:
        or      word[edi], 0x0fff
        jmp     .mark_modified

  .high_free:
        inc     edi
        or      word[edi], 0xfff0

  .mark_modified:
        call    fs.fat.fat12._.mark_cluster_sectors_dirty

        add     esp, 4
        pop     edx edi

        sub     edx, ecx
        mov     eax, edx
        call    fs.fat.util.cluster_to_sector
        mov     ecx, [ebx + fs.fat.fat12.partition_t.cluster_size]
;       klog_   LOG_DEBUG, "FAT12 alloc: %u 0x%x\n", eax, edx
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
kproc fs.fat.fat12.get_next_cluster ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Finds next cluster sector in FAT chain. Takes FAT12 root directory special case into account.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= current cluster sector number
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= next cluster sector number (ok) or FS error code (fail)
;< ecx #= number of sectors per cluster (for sectors in data area) or 1 (for sectors in root directory)
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "fs.fat.fat12.get_next_cluster(%u 0x%x)\n", eax, eax

        mov     ecx, [ebx + fs.fat.fat12.partition_t.root_dir_sector]
        sub     eax, ecx
        jb      .access_denied_error
        cmp     eax, [ebx + fs.fat.fat12.partition_t.root_dir_size]
        jae     .not_root_dir

        ; current sector is within root directory, next sector is right after this one
        inc     eax
        cmp     eax, [ebx + fs.fat.fat12.partition_t.root_dir_size]
        je      .end_of_chain_error

        add     eax, ecx
        xor     ecx, ecx ; cF = 0
        inc     ecx
        ret

  .not_root_dir:
        push    edi

        add     eax, ecx
        sub     eax, [ebx + fs.fat.fat12.partition_t.data_area_sector]
        jb      .access_denied_error

        push    edx
        xor     edx, edx
        div     [ebx + fs.fat.fat12.partition_t.cluster_size]
        pop     edx
        add     eax, 2

        push    eax
        shr     eax, 1 ; * 1.5
        add     eax, [esp]

        mov     ecx, eax
        and     ecx, (1 shl 9) - 1 ; % 512, FAT entry offset
        push    ecx

        shr     eax, 9 ; / 512, FAT sector
        add     eax, [ebx + fs.fat.fat12.partition_t.fat_sector] ; + FAT start sector

        cmp     ecx, 512 - 1
        mov_s_  ecx, 1
        jb      @f

        inc     ecx

    @@: call    fs.fat.fat12._.fetch_sectors
        jc      .device_error_2

        pop     eax ecx
        movzx   eax, word[edi + eax]
        test    cl, 1
        jz      .even

        shr     eax, 4
        jmp     .exit

  .even:
        and     eax, 0x0fff

  .exit:
        pop     edi

        cmp     eax, 0x0ff8
        jae     .end_of_chain_error
        cmp     eax, 0x0ff0
        jae     .device_error
        cmp     eax, 2
        jb      .device_error

        call    fs.fat.util.cluster_to_sector
        mov     ecx, [ebx + fs.fat.fat12.partition_t.cluster_size]
;       klog_   LOG_DEBUG, "FAT12 next: %u\n", eax
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
        add     esp, 8
        pop     edi

  .device_error:
        mov     eax, ERROR_DEVICE_FAIL
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12.get_or_allocate_next_cluster ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Finds next cluster sector in FAT chain. If current cluster is EOF, allocates new cluster and adds it to the chain.
;? Takes FAT12 root directory special case into account.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= current cluster sector number
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= next (or newly allocated) cluster sector number (ok) or FS error code (fail)
;< ecx #= number of sectors per cluster (for sectors in data area) or 1 (for sectors in root directory)
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "fs.fat.fat12.get_or_allocate_next_cluster(%u 0x%x)\n", eax, eax

        mov     ecx, [ebx + fs.fat.fat12.partition_t.root_dir_sector]
        sub     eax, ecx
        jb      .access_denied_error
        cmp     eax, [ebx + fs.fat.fat12.partition_t.root_dir_size]
        jae     .not_root_dir

        ; current sector is within root directory, next sector is right after this one
        inc     eax
        cmp     eax, [ebx + fs.fat.fat12.partition_t.root_dir_size]
        je      .disk_full_error

        add     eax, ecx
        xor     ecx, ecx ; cF = 0
        inc     ecx
        ret

  .not_root_dir:
        add     eax, ecx
        cmp     eax, [ebx + fs.fat.fat12.partition_t.data_area_sector]
        jb      .access_denied_error

        push    eax
        call    fs.fat.fat12.get_next_cluster
        jnc     .exit

        cmp     eax, ERROR_END_OF_FILE
        jne     .other_error

        call    fs.fat.fat12.allocate_cluster
        jc      .other_error

        push    eax
        mov     eax, [esp + 4]
        call    fs.fat.fat12._.set_cluster
        jc      .other_error_2

        pop     eax
        mov     ecx, [ebx + fs.fat.fat12.partition_t.cluster_size]

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
kproc fs.fat.fat12.check_for_enough_clusters ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= needed free clusters count
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "fs.fat.fat12.check_for_enough_clusters(%u)\n", eax

        klog_   LOG_ERROR, "FIXME: not implemented: fs.fat.fat12.check_for_enough_clusters\n"
        mov     eax, ERROR_NOT_IMPLEMENTED
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12.delete_chain ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= start cluster sector number
;> edx ~= 0 (mark first cluster free) or not 0 (mark first cluster EOF)
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "fs.fat.fat12.delete_chain(%u 0x%x, %u 0x%x)\n", eax, eax:3, edx, edx:3

        cmp     eax, [ebx + fs.fat.fat12.partition_t.data_area_sector]
        jb      .access_denied_error

        test    edx, edx
        jz      .next_cluster

        mov     edx, 0x0fff

  .next_cluster:
        push    eax edx

        call    fs.fat.fat12.get_next_cluster
        jnc     .set_cluster

        cmp     eax, ERROR_END_OF_FILE
        jne     .error_3
        jmp     .set_last_cluster

  .set_cluster:
        pop     edx
        xchg    eax, [esp]

;       klog_   LOG_DEBUG, "FAT12 free: %u 0x%x\n", eax, edx
        call    fs.fat.fat12._.set_cluster
        jc      .error_2

        pop     eax
        xor     edx, edx
        jmp     .next_cluster

  .set_last_cluster:
        pop     edx eax
;       klog_   LOG_DEBUG, "FAT12 free: %u 0x%x (last)\n", eax, edx
        call    fs.fat.fat12._.set_cluster
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
kproc fs.fat.fat12.flush ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "fs.fat.fat12.flush()\n"

        call    fs.fat.fat12._.flush_dirty_sectors
        jc      .device_error

        ret

  .device_error:
;       klog_   LOG_DEBUG, "  device error\n"
        mov     eax, ERROR_DEVICE_FAIL
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12._.fetch_sectors ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Fetches sector(s) to internal buffer (if not already there). Flushes existing sector(s) if they are modified.
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= sector number
;> ecx #= sectors count (1..2)
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< edi ^= buffer
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "  fs.fat.fat12._.fetch_sectors(0x%x, %u)\n", eax, ecx

        mov     edi, ebx
        cmp     eax, [ebx + fs.fat.fat12.partition_t.cached_sector_number]
        jne     .fetch
        cmp     ecx, [ebx + fs.fat.fat12.partition_t.cached_sectors_count]
        ja      .fetch

        jmp     .exit

  .fetch:
        call    fs.fat.fat12._.flush_dirty_sectors
        jc      .error

        push    eax ecx edx
        xor     edx, edx
        add     edi, fs.fat.fat12.partition_t.sectors_cache
        call    fs.read
        test    eax, eax
        pop     edx ecx eax
        jnz     .error

        add     edi, -fs.fat.fat12.partition_t.sectors_cache

        mov     [edi + fs.fat.fat12.partition_t.cached_sector_number], eax
        mov     [edi + fs.fat.fat12.partition_t.cached_sectors_count], ecx

  .exit:
        add     edi, fs.fat.fat12.partition_t.sectors_cache
        clc
        ret

  .error:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12._.flush_dirty_sectors ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx esi

;       klog_   LOG_DEBUG, "  fs.fat.fat12._.flush_dirty_sectors(0x%x, %u)\n", \
;               [ebx + fs.fat.fat12.partition_t.cached_sector_number], \
;               [ebx + fs.fat.fat12.partition_t.cached_sectors_count]

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
        test    [ebx + fs.fat.fat12.partition_t.dirty_sectors + eax], 1
        jz      @f

        push    eax ecx edx esi
        shl     eax, 9
        lea     ecx, [ebx + fs.fat.fat12.partition_t.sectors_cache + eax]
        shr     eax, 9
        add     eax, [ebx + fs.fat.fat12.partition_t.cached_sector_number]
        xor     edx, edx
        mov     esi, ecx
        mov_s_  ecx, 1
        call    fs.write
        pop     esi edx ecx eax
        jc      @f

        and     [ebx + fs.fat.fat12.partition_t.dirty_sectors + eax], 0 ; cF = 0

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12._.mark_cluster_sectors_dirty ;///////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? ...
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.fat.fat12.partition_t
;> edi ^= cluster inside cached sector
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "  fs.fat.fat12._.mark_cluster_sectors_dirty()\n"

        push    eax edi
        sub     edi, ebx
        add     edi, -fs.fat.fat12.partition_t.sectors_cache
        mov     eax, edi
        shr     eax, 9
        or      [ebx + fs.fat.fat12.partition_t.dirty_sectors + eax], 1
        cmp     edi, 512 - 1
        je      @f
        cmp     edi, 1024 - 1
        jne     .exit

    @@: inc     eax
        or      [ebx + fs.fat.fat12.partition_t.dirty_sectors + eax], 1

  .exit:
        pop     edi eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12._.set_cluster ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= cluster sector number
;> edx #= value
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "  fs.fat.fat12._.set_cluster(0x%x, 0x%x)\n", eax, edx

        ; validate cluster number
        sub     eax, [ebx + fs.fat.fat12.partition_t.data_area_sector]
        jb      .access_denied_error

        push    edx
        xor     edx, edx
        div     [ebx + fs.fat.fat12.partition_t.cluster_size]
        pop     edx

        cmp     eax, [ebx + fs.fat.fat12.partition_t.max_cluster]
        ja      .access_denied_error

        add     eax, 2

        ; validate value
        test    edx, edx
        jz      @f
        cmp     edx, 2
        jb      .access_denied_error
        cmp     edx, [ebx + fs.fat.fat12.partition_t.max_cluster]
        jbe     @f
        cmp     edx, 0x0ff7
        jb      .access_denied_error
        cmp     edx, 0x0fff
        ja      .access_denied_error
        cmp     edx, eax
        je      .access_denied_error

    @@: push    eax ecx edi
        push    eax

        shr     eax, 1 ; * 1.5
        add     eax, [esp]

        mov     ecx, eax
        and     ecx, (1 shl 9) - 1 ; % 512, FAT entry offset
        push    ecx

        shr     eax, 9 ; / 512, FAT sector
        add     eax, [ebx + fs.fat.fat12.partition_t.fat_sector]

        cmp     ecx, 512 - 1
        mov_s_  ecx, 1
        jb      @f

        inc     ecx

    @@: call    fs.fat.fat12._.fetch_sectors
        jc      .device_error

        pop     eax ecx
        add     edi, eax
        test    cl, 1
        jz      .even

        shl     edx, 4
        and     word[edi], not 0xfff0
        or      [edi], dx
        jmp     .exit

  .even:
        and     word[edi], not 0x0fff
        or      [edi], dx

  .exit:
        call    fs.fat.fat12._.mark_cluster_sectors_dirty
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
