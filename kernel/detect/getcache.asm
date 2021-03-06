;;======================================================================================================================
;;///// getcache.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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

        pusha

        mov     eax, [pg_data.pages_free]
        ; 1/32
        shr     eax, 5
        ; round off up to 8 pages
        shr     eax, 3
        shl     eax, 3
        ; translate pages in butes *4096
        shl     eax, 12
        ; check a upper size of the cache, no more than 1 Mb on the physical device
        cmp     eax, 1024 * 1024
        jbe     @f
        mov     eax, 1024 * 1024
        jmp     .continue

    @@: ; check a lower size of the cache, not less than 128 Kb on the physical device
        cmp     eax, 128 * 1024
        jae     @f
        mov     eax, 128 * 1024

    @@:

  .continue:
        mov     [ide_drives_cache.0.size], eax
        mov     [ide_drives_cache.1.size], eax
        mov     [ide_drives_cache.2.size], eax
        mov     [ide_drives_cache.3.size], eax
        xor     eax, eax
        mov     [hdd_appl_data], 1 ; al
        mov     [cd_appl_data], 1

        mov     ch, [DRIVE_DATA + 1]
        mov     cl, ch
        and     cl, 011b
        je      .ide2
        mov     esi, ide_drives_cache.3
        call    get_cache_ide

  .ide2:
        mov     cl, ch
        shr     cl, 2
        and     cl, 011b
        je      .ide1
        mov     esi, ide_drives_cache.2
        call    get_cache_ide

  .ide1:
        mov     cl, ch
        shr     cl, 4
        and     cl, 011b
        je      .ide0
        mov     esi, ide_drives_cache.1
        call    get_cache_ide

  .ide0:
        mov     cl, ch
        shr     cl, 6
        and     cl, 011b
        je      @f
        mov     esi, ide_drives_cache.0
        call    get_cache_ide

    @@: xor     ecx, ecx
        cmp     [NumBiosDisks], ecx
        jz      .endbd
        mov     esi, BiosDiskCaches

  .loopbd:
        push    ecx
        movsx   ecx, byte[BiosDisksData + ecx * 4 + 2]
        inc     ecx
        jz      .getbd
        add     ecx, ecx
        movzx   eax, byte[DRIVE_DATA + 1]
        shl     eax, cl
        and     ah, 3
        cmp     ah, 1
        jz      .contbd
        pop     ecx
        mov     byte[BiosDisksData + ecx * 4 + 2], -1
        push    ecx

  .getbd:
        mov     eax, [ide_drives_cache.0.size]
        mov     [esi + drive_cache_t.size], eax
        mov     cl, 1
        call    get_cache_ide

  .contbd:
        pop     ecx
        add     esi, sizeof.drive_cache_t
        inc     ecx
        cmp     ecx, [NumBiosDisks]
        jb      .loopbd

  .endbd:
        jmp     end_get_cache

;-----------------------------------------------------------------------------------------------------------------------
kproc get_cache_ide ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= drive_cache_t
;-----------------------------------------------------------------------------------------------------------------------
        and     [esi + drive_cache_t.sys.search_start], 0
        and     [esi + drive_cache_t.app.search_start], 0
        push    ecx
        stdcall kernel_alloc, [esi + drive_cache_t.size]
        mov     [esi + drive_cache_t.sys.ptr], eax
        pop     ecx
        mov     edx, eax
        mov     eax, [esi + drive_cache_t.size]
        shr     eax, 3
        mov     [esi + drive_cache_t.sys.data.size], eax
        mov     ebx, eax
        imul    eax, 7
        mov     [esi + drive_cache_t.app.data.size], eax
        add     ebx, edx
        mov     [esi + drive_cache_t.app.ptr], ebx

        cmp     cl, 010b
        je      .cd
        push    ecx
        mov     eax, [esi + drive_cache_t.sys.data.size]
        call    calculate_for_hd
        add     eax, [esi + drive_cache_t.sys.ptr]
        mov     [esi + drive_cache_t.sys.data.address], eax
        mov     [esi + drive_cache_t.sys.sad_size], ecx

        push    edi
        mov     edi, [esi + drive_cache_t.app.ptr]
        call    clear_ide_cache
        pop     edi

        mov     eax, [esi + drive_cache_t.app.data.size]
        call    calculate_for_hd
        add     eax, [esi + drive_cache_t.app.ptr]
        mov     [esi + drive_cache_t.app.data.address], eax
        mov     [esi + drive_cache_t.app.sad_size], ecx

        push    edi
        mov     edi, [esi + drive_cache_t.app.ptr]
        call    clear_ide_cache
        pop     edi

        pop     ecx
        ret

  .cd:
        push    ecx
        mov     eax, [esi + drive_cache_t.sys.data.size]
        call    calculate_for_cd
        add     eax, [esi + drive_cache_t.sys.ptr]
        mov     [esi + drive_cache_t.sys.data.address], eax
        mov     [esi + drive_cache_t.sys.sad_size], ecx

        push    edi
        mov     edi, [esi + drive_cache_t.sys.ptr]
        call    clear_ide_cache
        pop     edi

        mov     eax, [esi + drive_cache_t.app.data.size]
        call    calculate_for_cd
        add     eax, [esi + drive_cache_t.app.ptr]
        mov     [esi + drive_cache_t.app.data.address], eax
        mov     [esi + drive_cache_t.app.sad_size], ecx

        push    edi
        mov     edi, [esi + drive_cache_t.app.ptr]
        call    clear_ide_cache
        pop     edi

        pop     ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_for_hd ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     ebx, eax
        shr     eax, 9
        shl     eax, 3
        sub     ebx, eax
        shr     ebx, 9
        mov     ecx, ebx
        shl     ebx, 9
        pop     eax
        sub     eax, ebx
        dec     ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculate_for_cd ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     ebx, eax
        shr     eax, 11
        shl     eax, 3
        sub     ebx, eax
        shr     ebx, 11
        mov     ecx, ebx
        shl     ebx, 11
        pop     eax
        sub     eax, ebx
        dec     ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc clear_ide_cache ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        shl     ecx, 1
        xor     eax, eax
        rep
        stosd
        pop     eax
        ret
kendp

end_get_cache:
;       mov     [cache_ide0.pointer], HD_CACHE
;       mov     [cache_ide0.system_data], HD_CACHE + 65536
;       mov     [cache_ide0.system_sad_size], 1919
        popa
