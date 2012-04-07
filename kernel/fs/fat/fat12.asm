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

        mov     ecx, 9 * 512 * 2 / 3
        push    edi
        push    1

  .fetch:
        push    ecx
        mov     ecx, 3
        mov     eax, [esp + 4]
        call    fs.fat.fat12._.fetch_sectors
        pop     ecx
        jc      .device_error

        mov     edx, 512 + 1
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
;       klog_   LOG_DEBUG, "  low free, 0x%x (%u)\n", edx, edx
;       klog_   LOG_DEBUG, "  dump1 %x %x %x (%x %x) %x %x %x\n", [edi - 3]:2, [edi - 2]:2, [edi - 1]:2, [edi]:2, [edi + 1]:2, [edi + 2]:2, [edi + 3]:2, [edi + 4]:2
        or      word[edi], 0x0fff
;       klog_   LOG_DEBUG, "  dump2 %x %x %x (%x %x) %x %x %x\n", [edi - 3]:2, [edi - 2]:2, [edi - 1]:2, [edi]:2, [edi + 1]:2, [edi + 2]:2, [edi + 3]:2, [edi + 4]:2
        jmp     .mark_modified

  .high_free:
;       klog_   LOG_DEBUG, "  high free, 0x%x (%u)\n", edx, edx
        inc     edi
;       klog_   LOG_DEBUG, "  dump1 %x %x %x (%x %x) %x %x %x\n", [edi - 3]:2, [edi - 2]:2, [edi - 1]:2, [edi]:2, [edi + 1]:2, [edi + 2]:2, [edi + 3]:2, [edi + 4]:2
        or      word[edi], 0xfff0
;       klog_   LOG_DEBUG, "  dump2 %x %x %x (%x %x) %x %x %x\n", [edi - 3]:2, [edi - 2]:2, [edi - 1]:2, [edi]:2, [edi + 1]:2, [edi + 2]:2, [edi + 3]:2, [edi + 4]:2

  .mark_modified:
        call    fs.fat.fat12._.mark_cluster_sectors_dirty

        add     esp, 4
        pop     edi

        neg     ecx
        lea     edx, [ecx + 9 * 512 * 2 / 3]
        lea     eax, [edx + 31]
        xor     ecx, ecx
        inc     ecx
        clc
;       klog_   LOG_DEBUG, "  allocated, 0x%x : %u : 0x%x\n", eax, ecx, edx
        ret

  .disk_full_error:
;       klog_   LOG_DEBUG, "  disk full\n"
        add     esp, 4
        pop     edi
        mov     eax, ERROR_DISK_FULL
        stc
        ret

  .device_error:
;       klog_   LOG_DEBUG, "  device error\n"
        add     esp, 4
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
;       klog_   LOG_DEBUG, "fs.fat.fat12.get_next_cluster(0x%x)\n", eax

        ; TODO: don't use hard-coded values
        cmp     eax, 19
        jb      .access_denied_error
        cmp     eax, 32
        ja      .not_root_dir
        je      .end_of_chain_error

        ; current sector is within root directory, next sector is right after this one
        add     eax, 1
        xor     ecx, ecx ; cF = 0
        inc     ecx
;       klog_   LOG_DEBUG, "  root area, 0x%x : %u\n", eax, ecx
        ret

  .not_root_dir:
        push    edi

        ; for now, we assume one cluster = one sector, sector size = 512 bytes
        add     eax, -31 ; index in FAT
        push    eax

        shr     eax, 1 ; * 1.5
        add     eax, [esp]

        mov     ecx, eax
        and     ecx, (1 shl 9) - 1 ; % 512, FAT entry offset
        push    ecx

        shr     eax, 9 ; / 512, FAT sector
        add     eax, 1 ; + FAT start sector

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

        add     eax, 31
        xor     ecx, ecx ; cF = 0
        inc     ecx
;       klog_   LOG_DEBUG, "  data area, 0x%x : %u\n", eax, ecx
        ret

  .access_denied_error:
;       klog_   LOG_DEBUG, "  access denied\n"
        mov     eax, ERROR_ACCESS_DENIED
        stc
        ret

  .end_of_chain_error:
;       klog_   LOG_DEBUG, "  end of chain, 0x%x\n", eax
        mov     eax, ERROR_END_OF_FILE
        stc
        ret

  .device_error_2:
        add     esp, 8
        pop     edi

  .device_error:
;       klog_   LOG_DEBUG, "  device error, 0x%x\n", eax
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
;       klog_   LOG_DEBUG, "fs.fat.fat12.get_or_allocate_next_cluster(0x%x)\n", eax

        ; TODO: don't use hard-coded values
        cmp     eax, 19
        jb      .access_denied_error
        cmp     eax, 32
        ja      .not_root_dir
        je      .disk_full_error

        ; current sector is within root directory, next sector is right after this one
        add     eax, 1
        xor     ecx, ecx ; cF = 0
        inc     ecx
        ret

  .not_root_dir:
        push    eax
        call    fs.fat.fat12.get_next_cluster
        jnc     .exit

        cmp     eax, ERROR_END_OF_FILE
        jne     .other_error

        call    fs.fat.fat12.allocate_cluster
        jc      .other_error

        push    eax
        mov     eax, [esp + 4]
        add     eax, -31
        call    fs.fat.fat12._.set_cluster
        jc      .other_error_2

        pop     eax
        xor     ecx, ecx
        inc     ecx

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

        ; FIXME: not implemented

        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12.delete_chain ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= start cluster number
;> edx ~= 0 (mark first cluster free) or not 0 (mark first cluster EOF)
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "fs.fat.fat12.delete_chain(0x%x, 0x%x)\n", eax:3, edx:3

        test    edx, edx
        jz      .next_cluster

        mov     edx, 0x0fff

  .next_cluster:
        push    eax edx

        add     eax, 31
        call    fs.fat.fat12.get_next_cluster
        jnc     .set_cluster

        cmp     eax, ERROR_END_OF_FILE
        jne     .error_3
        jmp     .set_last_cluster

  .set_cluster:
        pop     edx
        xchg    eax, [esp]

;       klog_   LOG_DEBUG, "  set(0x%x, 0x%x)\n", eax:3, edx:3
        call    fs.fat.fat12._.set_cluster
        jc      .error_2

        pop     eax
        add     eax, -31
        xor     edx, edx
        jmp     .next_cluster

  .set_last_cluster:
        pop     edx eax
;       klog_   LOG_DEBUG, "  set(0x%x, 0x%x) [last]\n", eax:3, edx:3
        call    fs.fat.fat12._.set_cluster
        jc      .error

        clc
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
;       klog_   LOG_DEBUG, "    read\n"
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
;       klog_   LOG_DEBUG, "    write %u: 0x%x (%u) : 0x%x\n", [esp + 12], eax, eax, esi
        call    fs.write
        pop     esi edx ecx eax
        jc      @f

        and     [ebx + fs.fat.fat12.partition_t.dirty_sectors + eax], 0 ; cF = 0

;       klog_   LOG_DEBUG, "    ok\n"

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
;       klog_   LOG_DEBUG, "    offset 0x%x (%u)\n", edi, edi
        mov     eax, edi
        shr     eax, 9
;       klog_   LOG_DEBUG, "    mark %u\n", eax
        or      [ebx + fs.fat.fat12.partition_t.dirty_sectors + eax], 1
        cmp     edi, 512 - 1
        je      @f
        cmp     edi, 1024 - 2
        jne     .exit

    @@: inc     eax
;       klog_   LOG_DEBUG, "    mark %u\n", eax
        or      [ebx + fs.fat.fat12.partition_t.dirty_sectors + eax], 1

  .exit:
        pop     edi eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.fat.fat12._.set_cluster ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= cluster number
;> edx #= value
;> ebx ^= fs.fat.fat12.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< cF ~= 0 (ok) or 1 (fail)
;< eax #= FS error code (fail)
;-----------------------------------------------------------------------------------------------------------------------
;       klog_   LOG_DEBUG, "  fs.fat.fat12._.set_cluster(0x%x, 0x%x)\n", eax, edx

        ; validate cluster number
        cmp     eax, 2
        jb      .access_denied_error
        cmp     eax, 9 * 512 * 2 / 3
        jae     .access_denied_error

        ; validate value
        test    edx, edx
        jz      @f
        cmp     edx, 2
        jb      .access_denied_error
        cmp     edx, 9 * 512 * 2 / 3
        jb      @f
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
        add     eax, 1 ; + FAT start sector

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
;       klog_   LOG_DEBUG, "    done\n"
        ret

  .access_denied_error:
;       klog_   LOG_DEBUG, "    access denied\n"
        mov     eax, ERROR_ACCESS_DENIED
        stc
        ret

  .device_error:
;       klog_   LOG_DEBUG, "    device error\n"
        pop     edi ecx eax
        mov     eax, ERROR_DEVICE_FAIL
        stc
        ret
kendp
