;;======================================================================================================================
;;///// pcie.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2010 KolibriOS team <http://kolibrios.org/>
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

PCIe_CONFIG_SPACE equ 0xf0000000 ; to be moved to const.inc

mmio_pcie_cfg_addr dd 0 ; intel pcie space may be defined here
mmio_pcie_cfg_lim  dd 0 ; upper pcie space address

align 4
;-----------------------------------------------------------------------------------------------------------------------
pci_ext_config: ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? PCIe extended (memory-mapped) config space detection
;? WARNINGs:
;?   1) Very Experimental!
;?   2) direct HT-detection (no ACPI or BIOS service used)
;?   3) Only AMD/HT processors currently supported
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [mmio_pcie_cfg_addr]
        or      ebx, ebx
        jz      @f
        or      ebx, 0x7fffffff ; required by PCI-SIG standards
        jnz     .pcie_failed
        add     ebx, 0x000ffffc
        cmp     ebx, [mmio_pcie_cfg_lim] ; is the space limit correct?
        ja      .pcie_failed
        jmp     .pcie_cfg_mapped

    @@: mov     ebx, [cpu_vendor]
        cmp     ebx, dword[AMD_str]
        jne     .pcie_failed
        mov     bx, 0xc184 ; dev = 24, fn = 01, reg = 84h

  .check_HT_mmio:
        mov     cx, bx
        mov     ax, 0x0002 ; bus = 0, 1dword to read
        call    pci_read_reg
        mov     bx, cx
        sub     bl, 4
        and     al, 0x80 ; check the NP bit
        jz      .no_pcie_cfg
        shl     eax, 8 ; bus:[27..20], dev:[19:15]
        or      eax, 0x00007ffc ; fun:[14..12], reg:[11:2]
        mov     [mmio_pcie_cfg_lim], eax
        mov     cl, bl
        mov     ax, 0x0002 ; bus = 0, 1dword to read
        call    pci_read_reg
        mov     bx, cx
        test    al, 0x03 ; MMIO Base RW enabled?
        jz      .no_pcie_cfg
        test    al, 0x0c ; MMIO Base locked?
        jnz     .no_pcie_cfg
        xor     al, al
        shl     eax, 8
        test    eax, 0x000f0000 ; MMIO Base must be bus0-aligned
        jnz     .no_pcie_cfg
        mov     [mmio_pcie_cfg_addr], eax
        add     eax, 0x000ffffc
        sub     eax, [mmio_pcie_cfg_lim] ; MMIO must cover at least one bus
        ja      .no_pcie_cfg

        ; -- it looks like a true PCIe config space;
        mov     eax, [mmio_pcie_cfg_addr] ; physical address
        or      eax, (PG_SHARED + PG_LARGE + PG_USER)
        mov     ebx, PCIe_CONFIG_SPACE ; linear address
        mov     ecx, ebx
        shr     ebx, 20
        add     ebx, sys_pgdir ; PgDir entry @

    @@: mov     dword[ebx], eax ; map 4 buses
        invlpg  [ecx]
        cmp     bl, 4
        jz      .pcie_cfg_mapped ; fix it later
        add     bl, 4 ; next PgDir entry
        add     eax, 0x400000 ; eax += 4M
        add     ecx, 0x400000
        jmp     @b

  .pcie_cfg_mapped:
        ; -- glad to have the extended PCIe config field found
;       mov     esi, boot_pcie_ok
;       call    boot_log
        ret     ; <<<<<<<<<<< OK >>>>>>>>>>>

  .no_pcie_cfg:
        xor     eax, eax
        mov     [mmio_pcie_cfg_addr], eax
        mov     [mmio_pcie_cfg_lim], eax
        add     bl, 12
        cmp     bl, 0xc0 ; MMIO regs lay below this offset
        jb      .check_HT_mmio

  .pcie_failed:
;       mov     esi, boot_pcie_fail
;       call    boot_log
        ret     ; <<<<<<<<< FAILURE >>>>>>>>>
