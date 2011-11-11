;;======================================================================================================================
;;///// init.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
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

MEM_WB = 6 ; write-back memory
MEM_WC = 1 ; write combined memory
MEM_UC = 0 ; uncached memory

;-----------------------------------------------------------------------------------------------------------------------
kproc mem_test ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; if we have BIOS with fn E820, skip the test
        cmp     [BOOT_VAR - OS_BASE + BOOT_PHOENIX_SMAP_CNT], 0
        jnz     .ret

        mov     eax, cr0
        and     eax, not (CR0_CD + CR0_NW)
        or      eax, CR0_CD ; disable caching
        mov     cr0, eax
        wbinvd  ; invalidate cache

        xor     edi, edi
        mov     ebx, 'TEST'

    @@: add     edi, 0x100000
        xchg    ebx, [edi]
        cmp     dword[edi], 'TEST'
        xchg    ebx, [edi]
        je      @b

        and     eax, not (CR0_CD + CR0_NW) ; enable caching
        mov     cr0, eax
        inc     [BOOT_VAR - OS_BASE + BOOT_PHOENIX_SMAP_CNT]
        xor     eax, eax
        mov     dword[BOOT_VAR - OS_BASE + BOOT_PHOENIX_SMAP + phoenix_smap_addr_range_t.address], eax
        mov     dword[BOOT_VAR - OS_BASE + BOOT_PHOENIX_SMAP + phoenix_smap_addr_range_t.address + 4], eax
        mov     dword[BOOT_VAR - OS_BASE + BOOT_PHOENIX_SMAP + phoenix_smap_addr_range_t.size], edi
        mov     dword[BOOT_VAR - OS_BASE + BOOT_PHOENIX_SMAP + phoenix_smap_addr_range_t.size + 4], eax

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc init_mem ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; calculate maximum allocatable address and number of allocatable pages
        mov     edi, BOOT_VAR - OS_BASE + BOOT_PHOENIX_SMAP
        mov     ecx, [edi - 4]
        xor     esi, esi ; esi will hold total amount of memory
        xor     edx, edx ; edx will hold maximum allocatable address

  .calcmax:
        ; round all to pages
        mov     eax, [edi]
        test    eax, 0x0fff
        jz      @f
        neg     eax
        and     eax, 0x0fff
        add     dword[edi + phoenix_smap_addr_range_t.address], eax
        adc     dword[edi + phoenix_smap_addr_range_t.address + 4], 0
        sub     dword[edi + phoenix_smap_addr_range_t.size], eax
        sbb     dword[edi + phoenix_smap_addr_range_t.size + 4], 0
        jc      .unusable

    @@: and     dword[edi + phoenix_smap_addr_range_t.size], not 0x0fff
        jz      .unusable
        ; ignore memory after 4 Gb
        cmp     dword[edi + phoenix_smap_addr_range_t.address + 4], 0
        jnz     .unusable
        mov     eax, dword[edi + phoenix_smap_addr_range_t.address]
        cmp     dword[edi + phoenix_smap_addr_range_t.size + 4], 0
        jnz     .overflow
        add     eax, dword[edi + phoenix_smap_addr_range_t.size]
        jnc     @f

  .overflow:
        mov     eax, 0xfffff000

    @@: cmp     edx, eax
        jae     @f
        mov     edx, eax

    @@: sub     eax, [edi]
        mov     dword[edi + phoenix_smap_addr_range_t.size], eax
        add     esi, eax
        jmp     .usable

  .unusable:
        and     dword[edi + phoenix_smap_addr_range_t.size], 0

  .usable:
        add     edi, sizeof.phoenix_smap_addr_range_t
        loop    .calcmax

  .calculated:
        mov     [MEM_AMOUNT - OS_BASE], esi
        mov     [pg_data.mem_amount - OS_BASE], esi
        shr     esi, 12
        mov     [pg_data.pages_count - OS_BASE], esi

        shr     edx, 12
        add     edx, 31
        and     edx, not 31
        shr     edx, 3
        mov     [pg_data.pagemap_size - OS_BASE], edx

        add     edx, sys_pgmap - OS_BASE + 4095
        and     edx, not 4095
        mov     [tmp_page_tabs], edx

        mov     edx, esi
        and     edx, -1024
        cmp     edx, OS_BASE / 4096
        jbe     @f
        mov     edx, OS_BASE / 4096
        jmp     .set

    @@: cmp     edx, (HEAP_BASE - OS_BASE + HEAP_MIN_SIZE) / 4096
        jae     .set
        mov     edx, (HEAP_BASE - OS_BASE + HEAP_MIN_SIZE) / 4096

  .set:
        mov     [pg_data.kernel_pages - OS_BASE], edx
        shr     edx, 10
        mov     [pg_data.kernel_tables - OS_BASE], edx

        xor     eax, eax
        mov     edi, sys_pgdir - OS_BASE
        mov     ecx, 4096 / 4
        rep
        stosd

        mov     edx, (sys_pgdir - OS_BASE) + 0x0800 ; (OS_BASE shr 20)
        bt      [cpu_caps - OS_BASE], CAPS_PSE
        jnc     .no_PSE

        mov     ebx, cr4
        or      ebx, CR4_PSE
        mov     eax, PG_LARGE + PG_SW
        mov     cr4, ebx
        dec     [pg_data.kernel_tables - OS_BASE]

        mov     [edx], eax
        add     edx, 4

        mov     edi, [tmp_page_tabs]
        jmp     .map_kernel_heap ; new kernel fits to the first 4Mb - nothing to do with ".map_low"

  .no_PSE:
        mov     eax, PG_SW
        mov     ecx, [tmp_page_tabs]
        shr     ecx, 12

  .map_low:
        mov     edi, [tmp_page_tabs]

    @@: stosd
        add     eax, 0x1000
        dec     ecx
        jnz     @b

  .map_kernel_heap:
        mov     ecx, [pg_data.kernel_tables - OS_BASE]
        shl     ecx, 10
        xor     eax, eax
        rep
        stosd

        mov     ecx, [pg_data.kernel_tables - OS_BASE]
        mov     eax, [tmp_page_tabs]
        or      eax, PG_SW
        mov     edi, edx

  .map_kernel_tabs:
        stosd
        add     eax, 0x1000
        dec     ecx
        jnz     .map_kernel_tabs

        mov     dword[sys_pgdir - OS_BASE + (page_tabs shr 20)], sys_pgdir + PG_SW - OS_BASE

        mov     edi, sys_pgdir - OS_BASE
        lea     esi, [edi + (OS_BASE shr 20)]
        movsd
        movsd
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc init_page_map ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; mark all memory as unavailable
        mov     edi, sys_pgmap - OS_BASE
        mov     ecx, [pg_data.pagemap_size - OS_BASE]
        shr     ecx, 2
        xor     eax, eax
        rep
        stosd

        ; scan through memory map and mark free areas as available
        mov     ebx, BOOT_VAR - OS_BASE + BOOT_PHOENIX_SMAP
        mov     edx, [ebx - 4]

  .scanmap:
        mov     ecx, dword[ebx + phoenix_smap_addr_range_t.size]
        shr     ecx, 12 ; ecx = number of pages
        jz      .next
        mov     edi, dword[ebx + phoenix_smap_addr_range_t.address]
        shr     edi, 12 ; edi = first page
        mov     eax, edi
        shr     edi, 5
        shl     edi, 2
        add     edi, sys_pgmap - OS_BASE
        and     eax, 31
        jz      .startok
        add     ecx, eax
        sub     ecx, 32
        jbe     .onedword
        push    ecx
        mov     ecx, eax
        or      eax, -1
        shl     eax, cl
        or      [edi], eax
        add     edi, 4
        pop     ecx

  .startok:
        push    ecx
        shr     ecx, 5
        or      eax, -1
        rep
        stosd
        pop     ecx
        and     ecx, 31
        neg     eax
        shl     eax, cl
        dec     eax
        or      [edi], eax
        jmp     .next

  .onedword:
        add     ecx, 32
        sub     ecx, eax

    @@: bts     [edi], eax
        inc     eax
        loop    @b

  .next:
        add     ebx, sizeof.phoenix_smap_addr_range_t
        dec     edx
        jnz     .scanmap

        ; mark kernel memory as allocated (unavailable)
        mov     ecx, [tmp_page_tabs]
        mov     edx, [pg_data.pages_count - OS_BASE]
        shr     ecx, 12
        add     ecx, [pg_data.kernel_tables - OS_BASE]
        sub     edx, ecx
        mov     [pg_data.pages_free - OS_BASE], edx

        mov     edi, sys_pgmap - OS_BASE
        mov     ebx, ecx
        shr     ecx, 5
        xor     eax, eax
        rep
        stosd

        not     eax
        mov     ecx, ebx
        and     ecx, 31
        shl     eax, cl
        and     [edi], eax
        add     edi, OS_BASE
        mov     [page_start - OS_BASE], edi

        mov     ebx, sys_pgmap
        add     ebx, [pg_data.pagemap_size - OS_BASE]
        mov     [page_end - OS_BASE], ebx

        mov     [pg_data.pg_mutex - OS_BASE], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc init_BIOS32 ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, 0xe0000

  .pcibios_nxt:
        cmp     dword[edi], '_32_' ; "magic" word
        je      .BIOS32_found

  .pcibios_nxt2:
        add     edi, 0x10
        cmp     edi, 0x000ffff0
        je      .BIOS32_not_found
        jmp     .pcibios_nxt

  .BIOS32_found:
        ; magic word found, check control sum
        movzx   ecx, byte[edi + 9]
        shl     ecx, 4
        mov     esi, edi
        xor     eax, eax

    @@: lodsb
        add     ah, al
        loop    @b
        jnz     .pcibios_nxt2 ; control sum must be zero

        ; BIOS32 service found!
        mov     ebp, [edi + 4]
        mov     [bios32_entry], ebp

        ; check PCI BIOS present
        mov     eax, '$PCI'
        xor     ebx, ebx
        push    cs ; special for 'ret far' from BIOS
        call    ebp
        test    al, al
        jnz     .PCI_BIOS32_not_found

        ; create descriptors for PCI BIOS
        add     ebx, OS_BASE
        dec     ecx
        mov     [pci_code_32 - OS_BASE], cx ; limit 0-15
        mov     [pci_data_32 - OS_BASE], cx ; limit 0-15

        mov     [pci_code_32 - OS_BASE + 2], bx ; base 0-15
        mov     [pci_data_32 - OS_BASE + 2], bx ; base 0-15

        shr     ebx, 16
        mov     [pci_code_32 - OS_BASE + 4], bl ; base 16-23
        mov     [pci_data_32 - OS_BASE + 4], bl ; base 16-23

        shr     ecx, 16
        and     cl, 0x0f
        mov     ch, bh
        add     cx, D32
        mov     [pci_code_32 - OS_BASE + 6], cx ; lim 16-19
        mov     [pci_data_32 - OS_BASE + 6], cx ; base 24-31

        mov     [pci_bios_entry - OS_BASE], edx
;       jmp     .end

  .PCI_BIOS32_not_found:
        ; TODO: fill pci_emu_dat here

  .BIOS32_not_found:
  .end:
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc test_cpu ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  cpu_type  dd ?
  cpu_id    dd ?
  cpu_Intel dd ?
  cpu_AMD   dd ?
endl
        xor     eax, eax
        mov     [cpu_type], eax
        mov     [cpu_caps - OS_BASE], eax
        mov     [cpu_caps + 4 - OS_BASE], eax

        pushfd
        pop     eax
        mov     ecx, eax
        xor     eax, 0x40000
        push    eax
        popfd
        pushfd
        pop     eax
        xor     eax, ecx
        mov     [cpu_type], CPU_386
        jz      .end_cpuid
        push    ecx
        popfd

        mov     [cpu_type], CPU_486
        mov     eax, ecx
        xor     eax, 0x200000
        push    eax
        popfd
        pushfd
        pop     eax
        xor     eax, ecx
        je      .end_cpuid
        mov     [cpu_id], 1

        xor     eax, eax
        cpuid

        mov     [cpu_vendor - OS_BASE], ebx
        mov     [cpu_vendor + 4 - OS_BASE], edx
        mov     [cpu_vendor + 8 - OS_BASE], ecx
        cmp     ebx, dword[intel_str - OS_BASE]
        jne     .check_AMD
        cmp     edx, dword[intel_str + 4 - OS_BASE]
        jne     .check_AMD
        cmp     ecx, dword[intel_str + 8 - OS_BASE]
        jne     .check_AMD
        mov     [cpu_Intel], 1
        cmp     eax, 1
        jl      .end_cpuid
        mov     eax, 1
        cpuid
        mov     [cpu_sign - OS_BASE], eax
        mov     [cpu_info - OS_BASE], ebx
        mov     [cpu_caps - OS_BASE], edx
        mov     [cpu_caps + 4 - OS_BASE], ecx

        shr     eax, 8
        and     eax, 0x0f
        ret

  .end_cpuid:
        mov     eax, [cpu_type]
        ret

  .check_AMD:
        cmp     ebx, dword[AMD_str - OS_BASE]
        jne     .unknown
        cmp     edx, dword[AMD_str + 4 - OS_BASE]
        jne     .unknown
        cmp     ecx, dword[AMD_str + 8 - OS_BASE]
        jne     .unknown
        mov     [cpu_AMD], 1
        cmp     eax, 1
        jl      .unknown
        mov     eax, 1
        cpuid
        mov     [cpu_sign - OS_BASE], eax
        mov     [cpu_info - OS_BASE], ebx
        mov     [cpu_caps - OS_BASE], edx
        mov     [cpu_caps + 4 - OS_BASE], ecx
        shr     eax, 8
        and     eax, 0x0f
        ret

  .unknown:
        mov     eax, 1
        cpuid
        mov     [cpu_sign - OS_BASE], eax
        mov     [cpu_info - OS_BASE], ebx
        mov     [cpu_caps - OS_BASE], edx
        mov     [cpu_caps + 4 - OS_BASE], ecx
        shr     eax, 8
        and     eax, 0x0f
        ret
endp
