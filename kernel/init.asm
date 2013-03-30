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

ACPI_HI_RSDP_WINDOW_START = 0x000E0000
ACPI_HI_RSDP_WINDOW_END   = 0x00100000
ACPI_RSDP_CHECKSUM_LENGTH = 20
ACPI_MADT_SIGN            = 0x43495041

iglobal
  acpi_lapic_base dd 0xfee00000 ; default local apic base
endg

uglobal
  acpi_rsdp dd ?
  acpi_rsdt dd ?
  acpi_madt dd ?

  acpi_dev_data dd ?
  acpi_dev_size dd ?

  acpi_rsdt_base dd ?
  acpi_madt_base dd ?
  acpi_ioapic_base dd ?

  cpu_count dd ?
  smpt rd 16
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc mem_test ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; if we have BIOS with fn E820, skip the test
        cmp     [boot_var.phoenix_smap_cnt - OS_BASE], 0
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
        inc     [boot_var.phoenix_smap_cnt - OS_BASE]
        xor     eax, eax
        mov     dword[boot_var.phoenix_smap - OS_BASE + phoenix_smap_addr_range_t.address], eax
        mov     dword[boot_var.phoenix_smap - OS_BASE + phoenix_smap_addr_range_t.address + 4], eax
        mov     dword[boot_var.phoenix_smap - OS_BASE + phoenix_smap_addr_range_t.size], edi
        mov     dword[boot_var.phoenix_smap - OS_BASE + phoenix_smap_addr_range_t.size + 4], eax

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc init_mem ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; calculate maximum allocatable address and number of allocatable pages
        mov     edi, boot_var.phoenix_smap - OS_BASE
        mov     ecx, [edi - 4]
        xor     esi, esi ; esi will hold total amount of memory
        xor     edx, edx ; edx will hold maximum allocatable address

  .calcmax:
        ; round all to pages
        mov     eax, [edi]
        cmp     byte[edi + phoenix_smap_addr_range_t.type], PHOENIX_SMAP_TYPE_AVAILABLE
        jne     .unusable

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
;       and     dword[edi + phoenix_smap_addr_range_t.size], 0

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
        mov     ebx, boot_var.phoenix_smap - OS_BASE
        mov     edx, [ebx - 4]

  .scanmap:
        cmp     byte[ebx + phoenix_smap_addr_range_t.type], PHOENIX_SMAP_TYPE_AVAILABLE
        jne     .next

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
        mov     [gdts.pci_code_32.limit_low - OS_BASE], cx ; limit 0-15
        mov     [gdts.pci_data_32.limit_low - OS_BASE], cx ; limit 0-15

        mov     [gdts.pci_code_32.base_low - OS_BASE], bx ; base 0-15
        mov     [gdts.pci_data_32.base_low - OS_BASE], bx ; base 0-15

        shr     ebx, 16
        mov     [gdts.pci_code_32.base_mid - OS_BASE], bl ; base 16-23
        mov     [gdts.pci_data_32.base_mid - OS_BASE], bl ; base 16-23

        shr     ecx, 16
        and     cl, 0x0f
        mov     ch, bh
        or      cl, GDT_FLAG_D shl 4
        mov     word[gdts.pci_code_32.limit_high - OS_BASE], cx ; lim 16-19
        mov     word[gdts.pci_data_32.limit_high - OS_BASE], cx ; base 24-31

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

;-----------------------------------------------------------------------------------------------------------------------
kproc acpi_locate ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        mov     ebx, ACPI_HI_RSDP_WINDOW_START

  .check:
        cmp     dword[ebx], 0x20445352
        jne     .next
        cmp     dword[ebx + 4], 0x20525450
        jne     .next

        mov     edx, ebx
        mov     ecx, ACPI_RSDP_CHECKSUM_LENGTH
        xor     eax, eax

  .sum:
        add     al, [edx]
        inc     edx
        loop    .sum

        test    al, al
        jnz     .next

        mov     eax, ebx
        pop     ebx
        ret

  .next:
        add     ebx, 16
        cmp     ebx, ACPI_HI_RSDP_WINDOW_END
        jb      .check

        pop     ebx
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc rsdt_find ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx ^= rsdt
;> edx ^= SIG
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        push    esi

        lea     ebx, [ecx + 36]
        mov     esi, [ecx + 4]
        add     esi, ecx

  .next:
        mov     eax, [ebx]
        cmp     [eax], edx
        je      .done

        add     ebx, 4
        cmp     ebx, esi
        jb      .next

        xor     eax, eax
        pop     esi
        pop     ebx
        ret

  .done:
        mov     eax, [ebx]
        pop     esi
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc check_acpi ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    acpi_locate
        test    eax, eax
        jz      .done

        mov     ecx, [eax + 16]
        mov     edx, ACPI_MADT_SIGN
        mov     [acpi_rsdt_base - OS_BASE], ecx
        call    rsdt_find
        test    eax, eax
        jz      .done

        mov     [acpi_madt_base - OS_BASE], eax
        mov     ecx, [eax + 36]
        mov     [acpi_lapic_base - OS_BASE], ecx

        mov     edi, smpt - OS_BASE
        mov     ebx, [ecx + 0x20]
        shr     ebx, 24 ; read APIC ID
 
        mov     [edi], ebx ; bootstrap always first
        inc     [cpu_count - OS_BASE]
        add     edi, 4

        lea     edx, [eax + 44]
        mov     ecx, [eax + 4]
        add     ecx, eax

  .check:
        mov     eax, [edx]
        cmp     al, 0
        jne     .io_apic

        shr     eax, 24 ; get APIC ID
        cmp     eax, ebx ; skip self
        je      .next
 
        test    [edx + 4], byte 1 ; is enabled ?
        jz      .next
 
        cmp     [cpu_count - OS_BASE], 16
        jae     .next
 
        stosd ; store APIC ID
        inc     [cpu_count - OS_BASE]

  .next:
        mov     eax, [edx]
        movzx   eax, ah
        add     edx, eax
        cmp     edx, ecx
        jb      .check

  .done:
        ret

  .io_apic:
        cmp     al, 1
        jne     .next

        mov     eax, [edx + 4]
        mov     [acpi_ioapic_base - OS_BASE], eax
        jmp     .next
kendp
