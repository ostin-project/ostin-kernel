;;======================================================================================================================
;;///// kernel.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011-2012 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
;; (c) 2000-2004 MenuetOS <http://menuetos.net/>
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

format binary as "mnt"

include "include/proc32.inc"
include "include/struct.inc"
include "include/macros.inc"

include "config.inc"

include "include/types.inc"

include "include/sys/kernel.inc"
include "include/sys/boot.inc"
include "include/sys/const.inc"

include "include/globals.inc"
include "include/fs.inc"
include "include/syscall.inc"

os_stack        = offsetof.gdts.os_data ; GDTs
os_code         = offsetof.gdts.os_code
graph_data      = offsetof.gdts.graph_data + 3
tss0            = offsetof.gdts.tss0
app_code        = offsetof.gdts.app_code + 3
app_data        = offsetof.gdts.app_data + 3
app_tls         = offsetof.gdts.tls_data + 3
pci_code_sel    = offsetof.gdts.pci_code_32
pci_data_sel    = offsetof.gdts.pci_data_32

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;   Included files:
;;
;;   Kernel16.inc
;;    - Booteng.inc   English text for bootup
;;    - Bootcode.inc  Hardware setup
;;    - Pci16.inc     PCI functions
;;
;;   Kernel.inc
;;    - Sys.inc       Process management
;;    - Shutdown.inc  Shutdown and restart
;;    - Fat32.inc     Read / write hd
;;    - Vesa12.inc    Vesa 1.2 driver
;;    - Vesa20.inc    Vesa 2.0 driver
;;    - Vga.inc       VGA driver
;;    - Stack.inc     Network interface
;;    - Mouse.inc     Mouse pointer
;;    - Scincode.inc  Window skinning
;;    - Pci.inc       PCI functions
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;----------------------------------------------------------------------------------------------------------------------
;;///// 16 BIT ENTRY FROM BOOTSECTOR ///////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

use16
org 0

        jmp     boot.start

include "boot/preboot.inc"

include "boot/bootcode.asm"
include "bus/pci/pci16.asm"
include "detect/biosdisk.asm"

;;----------------------------------------------------------------------------------------------------------------------
;;///// SWITCH TO 32 BIT PROTECTED MODE ////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

        ; CR0 Flags - Protected mode and Paging
        mov     ecx, CR0_PE

        ; Enabling 32 bit protected mode
        sidt    [cs:old_ints_h]

        cli     ; disable all irqs

        mov     al, 0xff ; mask all irqs
        out     0xa1, al
        out     0x21, al

    @@: in      al, 0x64 ; Enable A20
        test    al, 2
        jnz     @b

        mov     al, 0xd1
        out     0x64, al

    @@: in      al, 0x64
        test    al, 2
        jnz     @b

        mov     al, 0xdf
        out     0x60, al

    @@: in      al, 0x64
        test    al, 2
        jnz     @b

        mov     al, 0xff
        out     0x64, al

        lgdt    [cs:tmp_gdts] ; Load GDT
        mov     eax, cr0 ; protected mode
        or      eax, ecx
        and     eax, not (CR0_NW + CR0_CD) ; caching enabled
        mov     cr0, eax
        jmp     pword os_code:B32 ; jmp to enable 32 bit mode

GdtBegin tmp_gdts, KERNEL_CODE - OS_BASE
  GdtEntry os_code, 0, 0xfffff, cpl0, GDT_FLAG_A + GDT_FLAG_D + GDT_FLAG_G
  GdtEntry os_data, 0, 0xfffff, drw0, GDT_FLAG_A + GDT_FLAG_D + GDT_FLAG_G
GdtEnd

include "data16.inc"

use32
org $ + (KERNEL_CODE - OS_BASE)

align 4
B32:
        mov     ax, os_stack ; Selector for os
        mov     ds, ax
        mov     es, ax
        mov     fs, ax
        mov     gs, ax
        mov     ss, ax
        mov     esp, KERNEL_STACK_TOP - OS_BASE ; Set stack
        cld

        ; CLEAR 0x280000 - HEAP_BASE
        xor     eax, eax
        mov     edi, CLEAN_ZONE
        mov     ecx, (HEAP_BASE - OS_BASE - CLEAN_ZONE) / 4
        rep
        stosd

;///        mov     edi, 0x40000
;///        mov     ecx, (0x90000 - 0x40000) / 4
;///        rep
;///        stosd

        ; CLEAR KERNEL UNDEFINED GLOBALS
        mov     edi, endofcode - OS_BASE
;///        mov     ecx, (uglobals_size / 4) + 4
        mov     ecx, (0xa0000 - (endofcode - OS_BASE)) / 4
        rep
        stosd

        ; SAVE & CLEAR 0-0xffff
        xor     esi, esi
        mov     edi, boot_data_area - OS_BASE
        mov     ecx, 0x10000 / 4
        rep
        movsd
        mov     edi, 0x1000
        mov     ecx, 0xf000 / 4
        rep
        stosd

        call    test_cpu
        bts     [cpu_caps - OS_BASE], CAPS_TSC ; force use rdtsc

        call    init_BIOS32

        ; MEMORY MODEL
        call    mem_test
        call    init_mem
        call    init_page_map

        ; ENABLE PAGING
        mov     eax, sys_pgdir - OS_BASE
        mov     cr3, eax

        mov     eax, cr0
        or      eax, CR0_PG + CR0_WP
        mov     cr0, eax

        lgdt    [gdts]
        jmp     pword os_code:high_code

align 4
bios32_entry  dd ?
tmp_page_tabs dd ?

use16
org $ - (KERNEL_CODE - OS_BASE)

include "boot/shutdown.asm"

use32
org $ + (KERNEL_CODE - OS_BASE)

include "init.asm"

org $ + OS_BASE

include "include/fdo.inc"

align 4
high_code:
        mov     ax, os_stack
        mov     bx, app_data
        mov     cx, app_tls
        mov     ss, ax
        add     esp, OS_BASE

        mov     ds, bx
        mov     es, bx
        mov     fs, cx
        mov     gs, bx
        cld

        bt      [cpu_caps], CAPS_PGE
        jnc     @f

        or      dword[sys_pgdir + (OS_BASE shr 20)], PG_GLOBAL

        mov     ebx, cr4
        or      ebx, CR4_PGE
        mov     cr4, ebx

    @@: xor     eax, eax
        mov     dword[sys_pgdir], eax
        mov     dword[sys_pgdir + 4], eax

        mov     eax, cr3
        mov     cr3, eax           ; flush TLB

        ; SAVE REAL MODE VARIABLES
        mov     ax, [boot_var.ide_base_addr]
        mov     [IDEContrRegsBaseAddr], ax

        ; --------------- APM ---------------------

        ; init selectors
        mov     ebx, [boot_var.apm_entry_ofs] ; offset of APM entry point
        movzx   eax, [boot_var.apm_code32_seg] ; real-mode segment base address of protected-mode 32-bit code segment
        movzx   ecx, [boot_var.apm_code16_seg] ; real-mode segment base address of protected-mode 16-bit code segment
        movzx   edx, [boot_var.apm_data16_seg] ; real-mode segment base address of protected-mode 16-bit data segment

        shl     eax, 4
        mov     [gdts.apm_code_32.base_low], ax
        shr     eax, 16
        mov     [gdts.apm_code_32.base_mid], al

        shl     ecx, 4
        mov     [gdts.apm_code_16.base_low], cx
        shr     ecx, 16
        mov     [gdts.apm_code_16.base_mid], cl

        shl     edx, 4
        mov     [gdts.apm_data_16.base_low], dx
        shr     edx, 16
        mov     [gdts.apm_data_16.base_mid], dl

        mov     dword[apm_entry], ebx
        mov     word[apm_entry + 4], offsetof.gdts.apm_code_32

        mov     eax, dword[boot_var.apm_version] ; version & flags
        mov     [apm_vf], eax

        ; -----------------------------------------

;       movzx   eax, [boot_var.mouse_port] ; mouse port
;       mov     byte[0xf604], 1 ; al
        mov     al, [boot_var.enable_dma] ; DMA access
        mov     [allow_dma_access], al
        movzx   eax, [boot_var.bpp] ; bpp
        mov     [ScreenBPP], al

        mov     [_display.bpp], eax
        mov     [_display.vrefresh], 60
        mov     [_display.disable_mouse], __sys_disable_mouse

        movzx   eax, [boot_var.screen_res.width] ; X max
        mov     [_display.box.width], eax
        dec     eax
        mov     [Screen_Max_Pos.x], eax
        mov     [screen_workarea.right], eax
        movzx   eax, [boot_var.screen_res.height] ; Y max
        mov     [_display.box.height], eax
        dec     eax
        mov     [Screen_Max_Pos.y], eax
        mov     [screen_workarea.bottom], eax
        mov     ax, [boot_var.vesa_mode] ; screen mode
        mov     [SCR_MODE], ax
;       mov     eax, [boot_var.vesa_12_bank_sw]; Vesa 1.2 bnk sw add
;       mov     [BANK_SWITCH], eax
        mov     [BytesPerScanLine], 640 * 4 ; Bytes PerScanLine
        cmp     [SCR_MODE], 0x13 ; 320x200
        je      @f
        cmp     [SCR_MODE], 0x12 ; VGA 640x480
        je      @f
        movzx   eax, [boot_var.scanline_len] ; for other modes
        mov     [BytesPerScanLine], eax
        mov     [_display.pitch], eax

    @@: mov     eax, [_display.box.width]
        mul     [_display.box.height]
        mov     [_WinMapRange.size], eax

        mov     esi, boot_var.bios_disks
        movzx   ecx, byte[esi - 1]
        mov     [NumBiosDisks], ecx
        mov     edi, BiosDisksData
        rep
        movsd

        ; GRAPHICS ADDRESSES
        and     [boot_var.enable_direct_lfb], 0
        mov     eax, [boot_var.vesa_20_lfb_addr]
        mov     [LFBRange.address], eax

        cmp     [SCR_MODE], 0100000000000000b
        jge     .setvesa20
        cmp     [SCR_MODE], 0x13
        je      .v20ga32
        mov     [PUTPIXEL], Vesa12_putpixel24 ; Vesa 1.2
        mov     [GETPIXEL], Vesa12_getpixel24
        cmp     [ScreenBPP], 24
        jz      .ga24
        mov     [PUTPIXEL], Vesa12_putpixel32
        mov     [GETPIXEL], Vesa12_getpixel32

  .ga24:
        jmp     .v20ga24

  .setvesa20:
        mov     [PUTPIXEL], Vesa20_putpixel24 ; Vesa 2.0
        mov     [GETPIXEL], Vesa20_getpixel24
        cmp     [ScreenBPP], 24
        jz      .v20ga24

  .v20ga32:
        mov     [PUTPIXEL], Vesa20_putpixel32
        mov     [GETPIXEL], Vesa20_getpixel32

  .v20ga24:
        cmp     [SCR_MODE], 0x12 ; 16 C VGA 640x480
        jne     .no_mode_0x12
        mov     [PUTPIXEL], VGA_putpixel
        mov     [GETPIXEL], Vesa20_getpixel32

  .no_mode_0x12:

        ; -------- Fast System Call init ----------

        ; Intel SYSENTER/SYSEXIT (AMD CPU support it too)
        bt      [cpu_caps], CAPS_SEP
        jnc     .SEnP ; SysEnter not Present
        xor     edx, edx
        mov     ecx, MSR_SYSENTER_CS
        mov     eax, os_code
        wrmsr
        mov     ecx, MSR_SYSENTER_ESP
;       mov     eax, sysenter_stack ; Check it
        xor     eax, eax
        wrmsr
        mov     ecx, MSR_SYSENTER_EIP
        mov     eax, sysenter_entry
        wrmsr

  .SEnP:
        ; AMD SYSCALL/SYSRET
        cmp     byte[cpu_vendor], 'A'
        jne     .noSYSCALL
        mov     eax, 0x80000001
        cpuid
        test    edx, 0x0800 ; bit_11 - SYSCALL/SYSRET support
        jz      .noSYSCALL
        mov     ecx, MSR_AMD_EFER
        rdmsr
        or      eax, 1 ; bit_0 - System Call Extension (SCE)
        wrmsr

        ; FIXME: dirty hack
        ; Bits of EDX :
        ; Bit 31-16 During the SYSRET instruction, this field is copied into the CS register
        ;  and the contents of this field, plus 8, are copied into the SS register.
        ; Bit 15-0 During the SYSCALL instruction, this field is copied into the CS register
        ;  and the contents of this field, plus 8, are copied into the SS register.

;       mov     edx, (os_code + 16) * 65536 + os_code
        mov     edx, 0x1b0008

        mov     eax, syscall_entry
        mov     ecx, MSR_AMD_STAR
        wrmsr

  .noSYSCALL:

        ; -----------------------------------------

        stdcall alloc_page
        stdcall map_page, tss - 0x0f80, eax, PG_SW
        stdcall alloc_page
        inc     eax
        mov     [legacy_os_idle_slot.app.io_map], eax
        stdcall map_page, tss + 0x080, eax, PG_SW
        stdcall alloc_page
        inc     eax
        mov     [legacy_os_idle_slot.app.io_map + 4], eax
        stdcall map_page, tss + 0x1080, eax, PG_SW

        ; LOAD IDT
        call    build_interrupt_table ; lidt is executed
        lidt    [idtreg]

        call    init_kernel_heap
        stdcall kernel_alloc, sizeof.ring0_stack_data_t + 512
        mov     [os_stack_seg], eax

        lea     esp, [eax + sizeof.ring0_stack_data_t]

        mov     [tss.ss0], os_stack
        mov     [tss.esp0], esp
        mov     [tss.esp], esp
        mov     [tss.cs], os_code
        mov     [tss.ss], os_stack
        mov     [tss.ds], app_data
        mov     [tss.es], app_data
        mov     [tss.fs], app_data
        mov     [tss.gs], app_data
        mov     [tss.io], 128

        ; Add IO access table - bit array of permitted ports
        mov     edi, tss.io_map_0
        xor     eax, eax
        not     eax
        mov     ecx, 8192 / 4
        rep
        stosd   ; access to 4096*8=65536 ports

        mov     ax, tss0
        ltr     ax

        mov     [LFBRange.size], 0x00800000
        call    init_LFB
        call    init_fpu
        call    init_malloc

        stdcall alloc_kernel_space, 0x51000
        mov     [default_io_map], eax

        add     eax, 0x2000
        mov     [ipc_tmp], eax
        mov     ebx, 0x1000

        add     eax, 0x40000
        mov     [proc_mem_map], eax

        add     eax, 0x8000
        mov     [proc_mem_pdir], eax

        add     eax, ebx
        mov     [proc_mem_tab], eax

        add     eax, ebx
        mov     [tmp_task_pdir], eax

        add     eax, ebx
        mov     [tmp_task_ptab], eax

        add     eax, ebx
        mov     [ipc_pdir], eax

        add     eax, ebx
        mov     [ipc_ptab], eax

        stdcall kernel_alloc, (unpack.LZMA_BASE_SIZE + (unpack.LZMA_LIT_SIZE shl (unpack.lc + unpack.lp))) * 4

        mov     [unpack.p], eax

        call    init_events

        mov     eax, srv
        mov     [srv.next_ptr], eax
        mov     [srv.prev_ptr], eax
        mov     eax, shmem_list
        mov     [shmem_list.next_ptr], eax
        mov     [shmem_list.prev_ptr], eax
        mov     eax, dll_list
        mov     [dll_list.next_ptr], eax
        mov     [dll_list.prev_ptr], eax

        mov     edi, irq_tab
        xor     eax, eax
        mov     ecx, 16
        rep
        stosd

        ; Set base of graphic segment to linear address of LFB
        mov     eax, [LFBRange.address] ; set for gs
        mov     [gdts.graph_data.base_low], ax
        shr     eax, 16
        mov     [gdts.graph_data.base_mid], al
        mov     [gdts.graph_data.base_high], ah

        stdcall kernel_alloc, [_WinMapRange.size]
        mov     [_WinMapRange.address], eax

        mov     ecx, core.process._.tree_mutex
        call    mutex_init
        mov     ecx, core.thread._.tree_mutex
        call    mutex_init

if KCONFIG_BLK_MEMORY

        mov     ecx, static_test_ram_partition + fs.partition_t._.mutex
        call    mutex_init

end if ; KCONFIG_BLK_MEMORY

if KCONFIG_BLK_FLOPPY

        mov     ecx, static_test_floppy_partition + fs.partition_t._.mutex
        call    mutex_init

end if ; KCONFIG_BLK_FLOPPY

if KCONFIG_BLK_ATAPI

        mov     ecx, static_test_atapi_partition + fs.partition_t._.mutex
        call    mutex_init

end if ; KCONFIG_BLK_ATAPI

        xor     eax, eax
        inc     eax
        mov     [current_slot], eax ; 1
        mov     [legacy_slots.last_valid_slot], eax ; 1
        mov     [current_slot_ptr], legacy_os_idle_slot

        ; set background
        mov     [BgrDrawMode], eax
        mov     [BgrDataSize.width], eax
        mov     [BgrDataSize.height], eax
        mov     [mem_BACKGROUND], 4
        mov     [img_background], static_background_data

        mov     [legacy_os_idle_slot.app.dir_table], sys_pgdir - OS_BASE

        stdcall kernel_alloc, 0x10000 / 8
        mov     edi, eax
        mov     [network_free_ports], eax
        or      eax, -1
        mov     ecx, 0x10000 / 8 / 4
        rep
        stosd

        ; REDIRECT ALL IRQ'S TO INT'S 0x20-0x2f
        call    rerouteirqs

        ; Initialize system V86 machine
        call    init_sys_v86

        ; TIMER SETUP
        mov     al, 0x34 ; pack[2(counter #0), 2(2 reads/writes), 3(rate generator), 1(binary value)]
        out     0x43, al
        mov     ax, 1193180 / KCONFIG_SYS_TIMER_FREQ ; should fit in word
        out     0x40, al ; lsb (bits 0..7)
        xchg    al, ah
        out     0x40, al ; msb (bits 8..15)

        and     dword[timer_ticks], 0
        and     dword[timer_ticks + 4], 0

        ; Enable timer IRQ (IRQ0) and hard drives IRQs (IRQ14, IRQ15)
        ; they are used: when partitions are scanned, hd_read relies on timer
        ; Also enable IRQ2, because in some configurations
        ; IRQs from slave controller are not delivered until IRQ2 on master is enabled
        mov     al, 0xfa
        out     0x21, al
        mov     al, 0x3f
        out     0xa1, al

        ; Enable interrupts in IDE controller
        mov     al, 0
        mov     dx, 0x3f6
        out     dx, al
        mov     dl, 0x76
        out     dx, al

        ; clear table area
        xor     eax, eax
        mov     edi, DRIVE_DATA
        mov     ecx, 16384
        rep
        stosd

include "detect/disks.inc"

; READ RAMDISK IMAGE FROM HD
include "boot/rdload.asm"

;       mov     [dma_hdd], 1

        ; CALCULATE FAT CHAIN FOR RAMDISK
        mov     esi, RAMDISK + 512
        mov     edi, RAMDISK_FAT
        call    fs.fat12.calculate_fat_chain

if 0

        mov     ax, [OS_BASE + 0x10000 + bx_from_load]
        cmp     ax, 'r1' ; if using not ram disk, then load librares and parameters
        je      no_lib_load

        ; LOADING LIBRARES
        stdcall dll.Load, @IMPORT ; loading librares for kernel (.obj files)
        call    load_file_parse_table ; prepare file parse table
        call    set_kernel_conf ; configure devices and gui

no_lib_load:

end if

        ; PRINT AMOUNT OF MEMORY
        mov     esi, boot_memdetect
        call    boot_log

        mov     ecx, [boot_y]
        or      ecx, (10 + 29 * 6) shl 16 ; "Determining amount of memory"
        sub     ecx, 10
        mov     edx, 0x00ffffff
        mov     ebx, [MEM_AMOUNT]
        shr     ebx, 20
        xor     edi, edi
        mov     eax, 0x00040000
        inc     edi
        call    sysfn.draw_number.force

        mov     esi, boot_devices
        call    boot_log

        mov     [pci_access_enabled], 1

        ; SET PRELIMINARY WINDOW STACK AND POSITIONS
        mov     esi, boot_windefs
        call    boot_log
        call    set_window_defaults

        ; SET BACKGROUND DEFAULTS
        mov     esi, boot_bgr
        call    boot_log
        call    init_background
        call    calculatebackground

        ; RESERVE SYSTEM IRQ'S JA PORT'S
        mov     esi, boot_resirqports
        call    boot_log
        call    reserve_irqs_ports

        ; SET PORTS FOR IRQ HANDLERS
;       mov     esi, boot_setrports
;       call    boot_log
;       call    setirqreadports

        ; SET UP OS TASK
        mov     esi, boot_setostask
        call    boot_log

        xor     eax, eax
        mov     [legacy_slots + legacy.slot_t.app.fpu_state], fpu_data
        mov     [legacy_slots + legacy.slot_t.app.exc_handler], eax
        mov     [legacy_slots + legacy.slot_t.app.except_mask], eax

        ; name for OS/IDLE process
        mov     dword[legacy_os_idle_slot.app.app_name], 'OS/I'
        mov     dword[legacy_os_idle_slot.app.app_name + 4], 'DLE'

        mov     edi, [os_stack_seg]
        mov     [legacy_os_idle_slot.app.pl0_stack], edi
        add     edi, sizeof.ring0_stack_data_t
        mov     [legacy_os_idle_slot.app.fpu_state], edi
        mov     [legacy_os_idle_slot.app.saved_esp0], edi ; just in case
        ; [legacy_os_idle_slot.app.io_map] was set earlier

        mov     esi, fpu_data
        mov     ecx, 512 / 4
        rep
        movsd

        mov     [legacy_os_idle_slot.app.exc_handler], eax
        mov     [legacy_os_idle_slot.app.except_mask], eax

        mov     ebx, legacy_os_idle_slot.app.obj
        mov     [legacy_os_idle_slot.app.obj.next_ptr], ebx
        mov     [legacy_os_idle_slot.app.obj.prev_ptr], ebx

        mov     [legacy_os_idle_slot.app.cur_dir], sysdir_path
        mov     [legacy_os_idle_slot.app.tls_base], eax

        ; task list
        mov     [legacy_os_idle_slot.task.mem_start], eax  ; process base address
        inc     eax
        mov     [current_slot], eax
        mov     [legacy_slots.last_valid_slot], eax
        mov     [current_slot_ptr], legacy_os_idle_slot
        mov     [legacy_os_idle_slot.task.wnd_number], al ; on screen number
        mov     [legacy_os_idle_slot.task.pid], eax ; process id number

        call    init_display
        mov     eax, [def_cursor]
        mov     [legacy_slots + legacy.slot_t.app.cursor], eax
        mov     [legacy_os_idle_slot.app.cursor], eax

        call    core.process.alloc
        mov     [current_process_ptr], eax
        mov     ebx, legacy_os_idle_slot
        call    core.process.compat.init_with_slot
        or      [eax + core.process_t.flags], PROCESS_FLAG_VALID

        call    core.thread.alloc
        mov     [current_thread_ptr], eax
        mov     ebx, legacy_os_idle_slot
        call    core.thread.compat.init_with_slot
        or      [eax + core.thread_t.flags], THREAD_FLAG_VALID

        ; READ TSC / SECOND
        mov     esi, boot_tsc
        call    boot_log
        cli
;       call    _rdtsc
        rdtsc
        mov     ecx, eax
        mov     ebx, edx
        mov     esi, 250 ; wait 1/4 a second
        call    delay_ms
;       call    _rdtsc
        rdtsc
        sti
        sub     eax, ecx
        sbb     edx, ebx
        shld    eax, edx, 2
        mov     [CPU_FREQ], eax ; save tsc / sec

        mov     ebx, 1000000
        div     ebx
        mov     [stall_mcs], eax

        ; PRINT CPU FREQUENCY
        mov     esi, boot_cpufreq
        call    boot_log

        mov     ebx, eax
        mov     ecx, [boot_y]
        add     ecx, (10 + 17 * 6) shl 16 - 10 ; 'CPU frequency is '
        mov     edx, 0x00ffffff
        xor     edi, edi
        mov     eax, 0x00040000
        inc     edi
        call    sysfn.draw_number.force

        ; SET VARIABLES
        call    set_variables

        ; SET MOUSE
;       call    detect_devices
        stdcall load_driver, szPS2MDriver
;       stdcall load_driver, szCOM_MDriver

        ; PALETTE FOR 320x200 and 640x480 16 col
        cmp     [SCR_MODE], 0x12
        jne     no_pal_vga
        mov     esi, boot_pal_vga
        call    boot_log
        call    paletteVGA

no_pal_vga:

        cmp     [SCR_MODE], 0x13
        jne     no_pal_ega
        mov     esi, boot_pal_ega
        call    boot_log
        call    palette320x200

no_pal_ega:

        ; LOAD DEFAULT SKIN
        call    load_default_skin

        ; protect io permission map
        mov     esi, [default_io_map]
        stdcall map_page, esi, [legacy_os_idle_slot.app.io_map], PG_MAP
        add     esi, 0x1000
        stdcall map_page, esi, [legacy_os_idle_slot.app.io_map + 4], PG_MAP

        stdcall map_page, tss.io_map_0, [legacy_os_idle_slot.app.io_map], PG_MAP
        stdcall map_page, tss.io_map_1, [legacy_os_idle_slot.app.io_map + 4], PG_MAP

        ; LOAD FIRST APPLICATION
        cli

        mov     ebp, firstapp
        call    fs_execute_from_sysdir

;       cmp     eax, 2 ; continue if a process has been loaded
        sub     eax, 2
        jz      first_app_found

        mov     esi, boot_failed
        call    boot_log

        mov     eax, 0xdeadbeef ; otherwise halt
        hlt

first_app_found:
        cli

;       mov     [legacy_slots.last_valid_slot], 2
        push    1
        pop     [current_slot] ; set OS task fisrt

        ; SET KEYBOARD PARAMETERS
        mov     al, 0xf6 ; reset keyboard, scan enabled
        call    kb_write

        ; wait until 8042 is ready
        xor     ecx, ecx

    @@: in      al, 0x64
        and     al, 00000010b
        loopnz  @b

;       mov     al, 0xed ; svetodiody - only for testing!
;       call    kb_write
;       call    kb_read
;       mov     al, 0111b
;       call    kb_write
;       call    kb_read

        mov     al, 0xf3 ; set repeat rate & delay
        call    kb_write
;       call    kb_read
        mov     al, 0 ; 30 250 ; 00100010b ; 24 500 ; 00100100b ; 20 500
        call    kb_write
;       call    kb_read
        call    set_lights

        ; Setup serial output console (if enabled)

if KCONFIG_DEBUG_COM_BASE

        ; enable Divisor latch
        mov     dx, KCONFIG_DEBUG_COM_BASE + 3
        mov     al, 1 shl 7
        out     dx, al

        ; Set speed to 115200 baud (max speed)
        mov     dx, KCONFIG_DEBUG_COM_BASE
        mov     al, 0x01
        out     dx, al

        mov     dx, KCONFIG_DEBUG_COM_BASE + 1
        mov     al, 0x00
        out     dx, al

        ; No parity, 8bits words, one stop bit, dlab bit back to 0
        mov     dx, KCONFIG_DEBUG_COM_BASE + 3
        mov     al, 3
        out     dx, al

        ; disable interrupts
        mov     dx, KCONFIG_DEBUG_COM_BASE + 1
        mov     al, 0
        out     dx, al

        ; clear + enable fifo (64 bits)
        mov     dx, KCONFIG_DEBUG_COM_BASE + 2
        mov     al, 0x7 + (1 shl 5)
        out     dx, al

end if

        ; START MULTITASKING

if KCONFIG_BOOT_LOG_ESC

        mov     esi, boot_tasking
        call    boot_log

  .bll1:
        in      al, 0x60 ; wait for ESC key press
        cmp     al, 129
        jne     .bll1

end if

;       mov     [ENABLE_TASKSWITCH], 1 ; multitasking enabled

        ; UNMASK ALL IRQ'S

;       mov     esi,boot_allirqs
;       call    boot_log
;
;       cli     ; guarantee forbidance of interrupts.
;       mov     al, 0 ; unmask all irq's
;       out     0xa1, al
;       out     0x21, al
;
;       mov     ecx, 32
;
;ready_for_irqs:
;
;       mov     al, 0x20 ; ready for irqs
;       out     0x20, al
;       out     0xa0, al
;
;       loop    ready_for_irqs ; flush the queue

        stdcall attach_int_handler, 1, irq1, 0

;       mov     [dma_hdd], 1
        cmp     [IDEContrRegsBaseAddr], 0
        setnz   [dma_hdd]
        mov     [timer_ticks_enable], 1 ; for cd driver

        sti
        call    change_task

        ; STACK AND FDC
        call    stack_init

if KCONFIG_BLK_FLOPPY

        call    blk.floppy.ctl.initialize

end if ; KCONFIG_BLK_FLOPPY

        jmp     osloop

;       jmp     $ ; wait here for timer to take control

        ; Fly :)

include "unpacker.asm"

;-----------------------------------------------------------------------------------------------------------------------
kproc boot_log ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushad

        mov     ebx, 10 * 65536
        mov     bx, word[boot_y]
        add     [boot_y], 10
        mov     ecx, 0x80ffffff ; ASCIIZ string with white color
        xor     edi, edi
        mov     edx, esi
        inc     edi
        call    dtext

        mov     [novesachecksum], 1000
        call    checkVga_N13

        popad

        ret
kendp

;;----------------------------------------------------------------------------------------------------------------------
;;///// MAIN OS LOOP START /////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

align 32
osloop:
        call    [draw_pointer]
        call    window_check_events
        call    mouse_check_events
        call    checkmisc
        call    checkVga_N13
        call    stack_handler
        call    checkidle

if KCONFIG_BLK_FLOPPY

        call    blk.floppy.ctl.process_events

end if ; KCONFIG_BLK_FLOPPY

        call    check_ATAPI_device_event
        jmp     osloop

;;----------------------------------------------------------------------------------------------------------------------
;;///// MAIN OS LOOP END ///////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
kproc checkidle ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        call    change_task
        jmp     .idle_loop_entry

  .idle_loop:
        cmp     eax, [idlemem] ; eax == [timer_ticks]
        jne     .idle_exit
;       call    _rdtsc
        rdtsc
        mov     ecx, eax
        hlt
;       call    _rdtsc
        rdtsc
        sub     eax, ecx
        add     [idleuse], eax

  .idle_loop_entry:
        mov     eax, dword[timer_ticks] ; eax = [timer_ticks]
        cmp     [check_idle_semaphore], 0
        je      .idle_loop
        dec     [check_idle_semaphore]

  .idle_exit:
        mov     [idlemem], eax ; eax == [timer_ticks]
        popad
        ret
kendp

uglobal
  idlemem               dd   0x0
  idleuse               dd   0x0
  idleusesec            dd   0x0
  check_idle_semaphore  dd   0x0
endg

;;----------------------------------------------------------------------------------------------------------------------
;;///// INCLUDED SYSTEM FILES //////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

include "kernel.inc"

;;----------------------------------------------------------------------------------------------------------------------
;;///// KERNEL FUNCTIONS ///////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
kproc ticks_to_hs ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edx:eax = ticks
;-----------------------------------------------------------------------------------------------------------------------
;< edx:eax = hs
;-----------------------------------------------------------------------------------------------------------------------

if KCONFIG_SYS_TIMER_FREQ <> 100

        push    ecx esi

        mov     ecx, 100
        mov     esi, KCONFIG_SYS_TIMER_FREQ
        call    util.64bit.mul_div

        pop     esi ecx

end if ; KCONFIG_SYS_TIMER_FREQ <> 100

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hs_to_ticks ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edx:eax = hs
;-----------------------------------------------------------------------------------------------------------------------
;< edx:eax = ticks
;-----------------------------------------------------------------------------------------------------------------------

if KCONFIG_SYS_TIMER_FREQ <> 100

        push    ecx esi

        mov     ecx, KCONFIG_SYS_TIMER_FREQ
        mov     esi, 100
        call    util.64bit.mul_div

        pop     esi ecx

end if ; KCONFIG_SYS_TIMER_FREQ <> 100

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc reserve_irqs_ports ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax

        xor     eax, eax
        inc     eax
        mov     byte[irq_owner + 4 * 0], al ; timer
;       mov     byte[irq_owner + 4 * 1], al ; keyboard
        mov     byte[irq_owner + 4 * 6], al ; floppy diskette
        mov     byte[irq_owner + 4 * 13], al ; math co-pros
        mov     byte[irq_owner + 4 * 14], al ; ide I
        mov     byte[irq_owner + 4 * 15], al ; ide II

        ; RESERVE PORTS
        MovStk  [RESERVED_PORTS.count], 4

        mov     eax, RESERVED_PORTS + sizeof.app_io_ports_header_t
        MovStk  [eax + app_io_ports_range_t.pid], 1
        and     [eax + app_io_ports_range_t.start_port], 0
        MovStk  [eax + app_io_ports_range_t.end_port], 0x2d

        add     eax, sizeof.app_io_ports_range_t
        MovStk  [eax + app_io_ports_range_t.pid], 1
        MovStk  [eax + app_io_ports_range_t.start_port], 0x30
        MovStk  [eax + app_io_ports_range_t.end_port], 0x4d

        add     eax, sizeof.app_io_ports_range_t
        MovStk  [eax + app_io_ports_range_t.pid], 1
        MovStk  [eax + app_io_ports_range_t.start_port], 0x50
        MovStk  [eax + app_io_ports_range_t.end_port], 0xdf

        add     eax, sizeof.app_io_ports_range_t
        MovStk  [eax + app_io_ports_range_t.pid], 1
        MovStk  [eax + app_io_ports_range_t.start_port], 0xe5
        MovStk  [eax + app_io_ports_range_t.end_port], 0xff

        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc setirqreadports ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     dword[irq12read + 0], 0x60 + 0x01000000 ; read port 0x60 , byte
;       mov     dword[irq12read + 4], 0 ; end of port list
        and     dword[irq12read + 4], 0 ; end of port list
;       mov     dword[irq04read + 0], 0x3f8 + 0x01000000 ; read port 0x3f8 , byte
;       mov     dword[irq04read + 4], 0 ; end of port list
;       mov     dword[irq03read + 0], 0x2f8 + 0x01000000 ; read port 0x2f8 , byte
;       mov     dword[irq03read + 4], 0 ; end of port list

        ret
kendp

iglobal
  process_number dd 0x1
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc set_variables ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, 0x100 ; flush port 0x60

  .fl60:
        in      al, 0x60
        loop    .fl60

        push    eax
        movzx   eax, [boot_var.screen_res.width]
        shr     eax, 1
        mov     [MOUSE_CURSOR_POS.x], eax
        movzx   eax, [boot_var.screen_res.height]
        shr     eax, 1
        mov     [MOUSE_CURSOR_POS.y], eax

        xor     eax, eax
        mov     [BTN_ADDR], BUTTON_INFO ; address of button list

;       mov     [MOUSE_BUFF_COUNT], al ; mouse buffer
        mov     [key_buffer.count], al ; keyboard buffer
        mov     [button_buffer.count], al ; button buffer

        mov     [DONT_SWITCH], al ; change task if possible
        pop     eax

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.write_to_port ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 43
;-----------------------------------------------------------------------------------------------------------------------
;> eax = 43
;> bl = byte of output
;> ecx = number of port
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, ecx ; separate flag for read / write
        and     ecx, 65535

        mov     eax, [RESERVED_PORTS.count]
        test    eax, eax
        jnz     .sopl8
        inc     eax
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .sopl8:
        mov     edx, [current_slot_ptr]
        mov     edx, [edx + legacy.slot_t.task.pid]
;       and     ecx,65535

  .sopl1:
        mov     esi, eax
        shl     esi, 4
        add     esi, RESERVED_PORTS
        cmp     edx, [esi + app_io_ports_range_t.pid]
        jne     .sopl2
        cmp     ecx, [esi + app_io_ports_range_t.start_port]
        jb      .sopl2
        cmp     ecx, [esi + app_io_ports_range_t.end_port]
        jg      .sopl2

  .sopl3:
        test    edi, 0x80000000 ; read ?
        jnz     .sopl4

        mov     eax, ebx
        mov     dx, cx ; write
        out     dx, al
        and     [esp + 4 + regs_context32_t.eax], 0
        ret

  .sopl2:
        dec     eax
        jnz     .sopl1
        inc     eax
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .sopl4:
        mov     dx, cx ; read
        in      al, dx
        and     eax, 0x00ff
        and     [esp + 4 + regs_context32_t.eax], 0
        mov     [esp + 4 + regs_context32_t.ebx], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.set_config, subfn, sysfn.not_implemented, \
    midi_base_port, \ ; 1
    keyboard_layout, \ ; 2
    cd_base, \ ; 3
    -, \
    system_language, \ ; 5
    -, \
    hd_base, \ ; 7
    hd_partition, \ ; 8
    -, \
    -, \
    low_level_hd_access, \ ; 11
    low_level_pci_access, \ ; 12
    - ; 13
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]

  .exit:
        and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.midi_base_port ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.1
;? roland mpu midi base , base io address
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, 0x0100
        jb      .error
        cmp     ecx, 0xffff
        ja      .error

        mov     [midi_base], cx
        mov     word[mididp], cx
        inc     cx
        mov     word[midisp], cx
        jmp     sysfn.set_config.exit

  .error:
        or      [esp + 4 + regs_context32_t.eax], -1
        ret
kendp

iglobal
  midi_base dw 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.keyboard_layout ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.2
;? 1, base keymap 2, shift keymap, 9 country 1eng 2fi 3ger 4rus
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [current_slot_ptr]
        mov     eax, [edi + legacy.slot_t.task.mem_start]
        add     eax, edx

        dec     ecx
        jnz     .kbnobase

        mov     ebx, keymap
        mov     ecx, 128
        call    memmove
        jmp     sysfn.set_config.exit

  .kbnobase:
        dec     ecx
        jnz     .kbnoshift

        mov     ebx, keymap_shift
        mov     ecx, 128
        call    memmove
        jmp     sysfn.set_config.exit

  .kbnoshift:
        dec     ecx
        jnz     .kbnoalt

        mov     ebx, keymap_alt
        mov     ecx, 128
        call    memmove
        jmp     sysfn.set_config.exit

  .kbnoalt:
        sub     ecx, 6
        jnz     .kbnocountry

        mov     [keyboard], dx
        jmp     sysfn.set_config.exit

  .kbnocountry:
        mov     [esp + 4 + regs_context32_t.eax], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.cd_base ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.3
;? 1, pri.master 2, pri slave 3 sec master, 4 sec slave
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jz      .nosesl

        cmp     ecx, 4
        ja      .nosesl

        mov     [cd_base], cl

        dec     ecx
        jnz     .noprma

        mov     [cdbase], 0x1f0
        mov     [cdid], 0xa0

  .noprma:
        dec     ecx
        jnz     .noprsl

        mov     [cdbase], 0x1f0
        mov     [cdid], 0xb0

  .noprsl:
        dec     ecx
        jnz     .nosema

        mov     [cdbase], 0x170
        mov     [cdid], 0xa0

  .nosema:
        dec     ecx
        jnz     .nosesl

        mov     [cdbase], 0x170
        mov     [cdid], 0xb0

  .nosesl:
        jmp     sysfn.set_config.exit
kendp

iglobal
  cd_base db 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.system_language ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.5
;? 1eng 2fi 3ger 4rus
;-----------------------------------------------------------------------------------------------------------------------
        mov     [syslang], ecx
        jmp     sysfn.set_config.exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.hd_base ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.7
;? 1, pri.master 2, pri slave 3 sec master, 4 sec slave
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jz      .nosethd

        cmp     ecx, 4
        ja      .nosethd

        mov     [hd_base], cl

        cmp     ecx, 1
        jnz     .noprmahd

        mov     [hdbase], 0x1f0
        and     [hdid], 0
        mov     [hdpos], ecx

  .noprmahd:
        cmp     ecx, 2
        jnz     .noprslhd

        mov     [hdbase], 0x1f0
        mov     [hdid], 0x10
        mov     [hdpos], ecx

  .noprslhd:
        cmp     ecx, 3
        jnz     .nosemahd

        mov     [hdbase], 0x170
        and     [hdid], 0
        mov     [hdpos], ecx

  .nosemahd:
        cmp     ecx, 4
        jnz     .noseslhd

        mov     [hdbase], 0x170
        mov     [hdid], 0x10
        mov     [hdpos], ecx

  .noseslhd:
        call    reserve_hd1
        call    reserve_hd_channel
        call    free_hd_channel
        and     [hd1_status], 0 ; free

  .nosethd:
        jmp     sysfn.set_config.exit
kendp

iglobal
  hd_base db 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.hd_partition ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.8
;? fat32 partition in hd
;-----------------------------------------------------------------------------------------------------------------------
        mov     [known_part], ecx
        call    reserve_hd1
        call    reserve_hd_channel
        call    free_hd_channel
;       pusha
        call    choice_necessity_partition_1
;       popa
        and     [hd1_status], 0 ; free
        jmp     sysfn.set_config.exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.low_level_hd_access ;////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.11
;-----------------------------------------------------------------------------------------------------------------------
        and     ecx, 1
        mov     [lba_read_enabled], ecx
        jmp     sysfn.set_config.exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config.low_level_pci_access ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21.12
;-----------------------------------------------------------------------------------------------------------------------
        and     ecx, 1
        mov     [pci_access_enabled], ecx
        jmp     sysfn.set_config.exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.get_config, subfn, sysfn.not_implemented, \
    midi_base_port, \ ; 1
    keyboard_layout, \ ; 2
    cd_base, \ ; 3
    -, \
    system_language, \ ; 5
    -, \
    hd_base, \ ; 7
    hd_partition, \ ; 8
    tick_count, \ ; 9
    -, \
    low_level_hd_access, \ ; 11
    low_level_pci_access ; 12
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.midi_base_port ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.1
;? roland mpu midi base , base io address
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, [midi_base]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.keyboard_layout ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.2
;? 1, base keymap 2, shift keymap, 9 country 1eng 2fi 3ger 4rus
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [current_slot_ptr]
        mov     ebx, [edi + legacy.slot_t.task.mem_start]
        add     ebx, edx

;       cmp     ebx, 1
        dec     ecx
        jnz     .kbnobaseret

        mov     eax, keymap
        mov     ecx, 128
        call    memmove
        ret

  .kbnobaseret:
;       cmp     ebx, 2
        dec     ecx
        jnz     .kbnoshiftret

        mov     eax, keymap_shift
        mov     ecx, 128
        call    memmove
        ret

  .kbnoshiftret:
;       cmp     ebx, 3
        dec     ecx
        jne     .kbnoaltret

        mov     eax, keymap_alt
        mov     ecx, 128
        call    memmove
        ret

  .kbnoaltret:
;       cmp     ebx, 9
        sub     ecx, 6
        jnz     .exit

        movzx   eax, [keyboard]
        mov     [esp + 4 + regs_context32_t.eax], eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.cd_base ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.3
;? 1, pri.master 2, pri slave 3 sec master, 4 sec slave
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, [cd_base]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.system_language ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.5
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [syslang]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.hd_base ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.7
;? 1, pri.master 2, pri slave 3 sec master, 4 sec slave
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, [hd_base]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.hd_partition ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.8
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [known_part]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.tick_count ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.9
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, dword[timer_ticks] ; [0xfdf0]
        mov     edx, dword[timer_ticks + 4]
        call    ticks_to_hs
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.low_level_hd_access ;////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.11
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [lba_read_enabled]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.low_level_pci_access ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.12
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [pci_access_enabled]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc detect_devices ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;include 'detect/commouse.inc'
;include 'detect/ps2mouse.inc'
;include 'detect/dev_fd.inc'
;include 'detect/dev_hdcd.inc'
;include 'detect/sear_par.inc'
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.exit_process ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function -1
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [current_slot_ptr]
        mov     eax, [ecx + legacy.slot_t.app.tls_base]
        test    eax, eax
        jz      @f

        stdcall user_free, eax

    @@: mov     eax, [current_slot_ptr]
        mov     [eax + legacy.slot_t.task.state], THREAD_STATE_ZOMBIE ; terminate this program

  .waitterm:
        ; wait here for termination
        mov     ebx, 100
        call    sysfn.delay_hs
        jmp     .waitterm
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.system_ctl, subfn, sysfn.not_implemented, \
    -, \
    kill_process_by_slot, \ ; 2
    activate_window, \ ; 3
    get_cpu_idle_counter, \ ; 4
    get_cpu_frequency, \ ; 5
    save_ram_disk, \ ; 6
    get_active_window_slot, \ ; 7
    pc_speaker_ctl, \ ; 8
    shutdown, \ ; 9
    minimize_active_window, \ ; 10
    get_disks_info, \ ; 11
    -, \
    get_kernel_version, \ ; 13
    wait_retrace, \ ; 14
    move_mouse_cursor_to_center, \ ; 15
    get_free_memory_size, \ ; 16
    get_total_memory_size, \ ; 17
    kill_process_by_id, \ ; 18
    mouse_ctl, \ ; 19
    get_memory_info, \ ; 20
    get_process_slot_by_process_id, \ ; 21
    alien_window_ctl ; 22
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.shutdown ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.9: system shutdown
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, 1
        jl      exit_for_anyone
        cmp     ecx, 4
        jg      exit_for_anyone
        mov     [boot_var.shutdown_param], cl

        mov     eax, [legacy_slots.last_valid_slot]
        mov     [SYS_SHUTDOWN], al
        mov     [shutdown_processes], eax
        and     [esp + 4 + regs_context32_t.eax], 0

exit_for_anyone:
        ret
kendp

uglobal
  shutdown_processes dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.kill_process_by_slot ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.2: terminate process by its slot number
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, 2
        jb      .noprocessterminate
        mov     edx, [legacy_slots.last_valid_slot]
        cmp     ecx, edx
        ja      .noprocessterminate
        mov     eax, [legacy_slots.last_valid_slot]
        shl     ecx, 9 ; * sizeof.legacy.slot_t
        mov     edx, [legacy_slots + ecx + legacy.slot_t.task.pid]
        add     ecx, legacy_slots + legacy.slot_t.task.state
        cmp     byte[ecx], THREAD_STATE_FREE
        jz      .noprocessterminate

;       call    MEM_Heap_Lock ; guarantee that process isn't working with heap
        mov     byte[ecx], THREAD_STATE_ZOMBIE ; clear possible i40's
;       call    MEM_Heap_UnLock

        cmp     edx, [application_table_status] ; clear app table stat
        jne     .noatsc
        and     [application_table_status], 0

  .noatsc:
  .noprocessterminate:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.kill_process_by_id ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.18: terminate process by its identifier
;-----------------------------------------------------------------------------------------------------------------------
        ; lock application_table_status mutex
  .table_status:
        cli
        cmp     [application_table_status], 0
        je      .stf
        sti
        call    change_task
        jmp     .table_status

  .stf:
        call    set_application_table_status
        mov     eax, ecx
        call    pid_to_slot
        test    eax, eax
        jz      .not_found
        mov     ecx, eax
        cli
        call    sysfn.system_ctl.kill_process_by_slot
        and     [application_table_status], 0
        sti
        and     [esp + 4 + regs_context32_t.eax], 0
        ret

  .not_found:
        mov     [application_table_status], 0
        or      [esp + 4 + regs_context32_t.eax], -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.activate_window ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.3: activate window by process slot number
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, 2
        jb      .nowindowactivate
        cmp     ecx, [legacy_slots.last_valid_slot]
        ja      .nowindowactivate

        mov     [window_minimize], 2 ; restore window if minimized

        movzx   esi, [pslot_to_wnd_pos + ecx * 2]
        cmp     esi, [legacy_slots.last_valid_slot]
        je      .nowindowactivate ; already active

        mov     edi, ecx
        shl     edi, 9 ; * sizeof.legacy.slot_t
        add     edi, legacy_slots
        movzx   esi, [pslot_to_wnd_pos + ecx * 2]
        lea     esi, [wnd_pos_to_pslot + esi * 2]
        call    waredraw

  .nowindowactivate:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_cpu_idle_counter ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.4: get CPU idle counter
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [idleusesec]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_cpu_frequency ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.5: get CPU clock rate
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [CPU_FREQ]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;  SAVE ramdisk to /hd/1/menuet.img
include "blkdev/rdsave.asm"

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_active_window_slot ;/////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.7: get process slot number of active window
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [legacy_slots.last_valid_slot]
        movzx   eax, [wnd_pos_to_pslot + eax * 2]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.pc_speaker_ctl ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.8: PC speaker control
;-----------------------------------------------------------------------------------------------------------------------
;       cmp     ecx, 1
        dec     ecx
        jnz     .nogetsoundflag
        movzx   eax, byte[sound_flag] ; get sound_flag
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .nogetsoundflag:
;       cmp     ecx, 2
        dec     ecx
        jnz     .nosoundflag
        xor     byte[sound_flag], 1

  .nosoundflag:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.minimize_active_window ;/////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.10: minimize active window
;-----------------------------------------------------------------------------------------------------------------------
        mov     [window_minimize], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_disks_info ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.11: get disk info table
;-----------------------------------------------------------------------------------------------------------------------
;       cmp     ecx, 1
        dec     ecx
        jnz     .full_table

  .small_table:
        call    .for_all_tables
        mov     ecx, 10
        rep
        movsb
        ret

  .full_table:
;       cmp     ecx, 2
        dec     ecx
        jnz     exit_for_anyone
        call    .for_all_tables
        mov     ecx, 16384
        rep
        movsd
        ret

  .for_all_tables:
        mov     edi, edx
        mov     esi, DRIVE_DATA
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_kernel_version ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.13: get kernel ID and version
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, ecx
        mov     esi, version_inf
        mov     ecx, version_end - version_inf
        rep
        movsb
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.wait_retrace ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.14: wait for vertical retrace
;-----------------------------------------------------------------------------------------------------------------------
        ; wait retrace functions
        mov     edx, 0x3da

  .WaitRetrace_loop:
        in      al, dx
        test    al, 01000b
        jz      .WaitRetrace_loop

        and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.move_mouse_cursor_to_center ;////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.15: set mouse cursor position to screen center
;-----------------------------------------------------------------------------------------------------------------------
;       push    eax
        mov     eax, [Screen_Max_Pos.x]
        shr     eax, 1
        mov     [MOUSE_CURSOR_POS.x], eax
        mov     eax, [Screen_Max_Pos.y]
        shr     eax, 1
        mov     [MOUSE_CURSOR_POS.y], eax
        xor     eax, eax
        and     [esp + 4 + regs_context32_t.eax], eax
;       pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.mouse_ctl ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.19: mouse control
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.system_ctl.mouse_ctl, subfn, sysfn.not_implemented, \
    get_cursor_acceleration, \ ; 0
    set_cursor_acceleration, \ ; 1
    get_cursor_delay, \ ; 2
    set_cursor_delay, \ ; 3
    set_cursor_position, \ ; 4
    set_buttons_state ; 5
endg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ecx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.mouse_ctl.get_cursor_acceleration ;//////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.19.0
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, word[mouse_speed_factor]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.mouse_ctl.set_cursor_acceleration ;//////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.19.1
;-----------------------------------------------------------------------------------------------------------------------
        mov     [mouse_speed_factor], dx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.mouse_ctl.get_cursor_delay ;/////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.19.2
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [mouse_delay]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.mouse_ctl.set_cursor_delay ;/////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.19.3
;-----------------------------------------------------------------------------------------------------------------------
        mov     [mouse_delay], edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.mouse_ctl.set_cursor_position ;//////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.19.4
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, dx
        cmp     eax, [Screen_Max_Pos.y]
        ja      .exit

        shr     edx, 16
        cmp     edx, [Screen_Max_Pos.x]
        ja      .exit

        mov     [MOUSE_CURSOR_POS.x], edx
        mov     [MOUSE_CURSOR_POS.x], eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.mouse_ctl.set_buttons_state ;////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.19.5
;-----------------------------------------------------------------------------------------------------------------------
        mov     [BTN_DOWN], dl
        mov     [mouse_active], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_free_memory_size ;///////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.16
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [pg_data.pages_free]
        shl     eax, 2
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_total_memory_size ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.17
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [MEM_AMOUNT]
        shr     eax, 10
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.get_process_slot_by_process_id ;/////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.21
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, ecx
        call    pid_to_slot
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_ctl.alien_window_ctl ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 18.22
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        mov     eax, edx ; ebx - operating
        shr     ecx, 1
        jnc     @f
        call    pid_to_slot

    @@: or      eax, eax ; eax - number of slot
        jz      .error
        cmp     eax, MAX_TASK_COUNT ; varify maximal slot number
        jae     .error
        movzx   eax, [pslot_to_wnd_pos + eax * 2]
        shr     ecx, 1
        jc      .restore

        call    minimize_window
        jmp     .exit

  .restore:
        call    restore_minimized_window

  .exit:
        popad
        xor     eax, eax
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .error:
        popad
        xor     eax, eax
        dec     eax
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

uglobal
  screen_workarea rect32_t
  window_minimize db ?
  sound_flag      db ?
endg

iglobal
  version_inf:
    db 0, 7, 7, 0 ; version 0.7.7.0
    db 0 ; reserved
    dd 0
  version_end:
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_process_info ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 9
;-----------------------------------------------------------------------------------------------------------------------
; RETURN:
;   +00 dword     process cpu usage
;   +04 word      position in windowing stack
;   +06 word      windowing stack value at current position (cpu nro)
;   +10 12 bytes  name
;   +22 dword     start in mem
;   +26 dword     used mem
;   +30 dword     PID , process idenfification number
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, -1 ; who am I ?
        jne     .no_who_am_i
        mov     ecx, [current_slot]

  .no_who_am_i:
        cmp     ecx, MAX_TASK_COUNT
        jae     .nofillbuf

        ; +4: word: position of the window of thread in the window stack
        mov     ax, [pslot_to_wnd_pos + ecx * 2]
        mov     [ebx + process_info_t.window_stack_position], ax
        ; +6: word: number of the thread slot, which window has in the window stack
        ;           position ecx (has no relation to the specific thread)
        mov     ax, [wnd_pos_to_pslot + ecx * 2]
        mov     [ebx + process_info_t.window_stack_value], ax

        shl     ecx, 9 ; * sizeof.legacy.slot_t

        lea     eax, [legacy_slots + ecx]
        call    core.thread.compat.find_by_slot
        test    eax, eax
        jz      .nofillbuf

        mov     ebp, eax

        ; +0: dword: cpu usage
        mov     eax, [ebp + core.thread_t.stats.cpu_usage]
        mov     [ebx + process_info_t.thread_cpu_usage], eax

        ; +10: 11 bytes: name of the process
        push    ecx
        mov     eax, [ebp + core.thread_t.process_ptr]
        add     eax, core.process_t.name
        add     ebx, process_info_t.process_name
        mov     ecx, PROCESS_MAX_NAME_LEN
        call    memmove
        pop     ecx

        ; +22: address of the process in memory
        ; +26: size of used memory - 1
        push    edi
        lea     edi, [ebx - process_info_t.process_name + process_info_t.process_memory_range]
        xor     eax, eax
        mov     edx, 0x100000 * 16
        cmp     ecx, 1 shl 9 ; sizeof.legacy.slot_t
        je      .os_mem
        mov     edx, [legacy_slots + ecx + legacy.slot_t.app.mem_size]
        mov     eax, new_app_base

  .os_mem:
        stosd
        lea     eax, [edx - 1]
        stosd

assert process_info_t.thread_id = 30

        ; +30: PID/TID
        mov     eax, [legacy_slots + ecx + legacy.slot_t.task.pid]
        stosd

assert process_info_t.window_box = 34

        ; window position and size
        push    esi
        lea     esi, [legacy_slots + ecx + legacy.slot_t.window.box]
        movsd
        movsd
        movsd
        movsd

assert process_info_t.thread_state = 50

        ; Process state (+50)
        movzx   eax, [legacy_slots + ecx + legacy.slot_t.task.state]
        stosd

assert process_info_t.window_client_box = 54

        ; Window client area box
        lea     esi, [legacy_slots + ecx + legacy.slot_t.app.wnd_clientbox]
        movsd
        movsd
        movsd
        movsd

assert process_info_t.window_state = 70

        ; Window state
        mov     al, [legacy_slots + ecx + legacy.slot_t.window.fl_wstate]
        stosb

assert process_info_t.thread_event_mask = 71

        ; Event mask (+71)
        mov     eax, [ebp + core.thread_t.events.event_mask]
        stosd

        pop     esi
        pop     edi

  .exit:
        ; return number of processes
        mov     eax, [legacy_slots.last_valid_slot]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .nofillbuf:
        mov     edi, ebx
        mov     ecx, sizeof.process_info_t / 4
        xor     eax, eax
        rep
        stosd
        mov     dword[ebx + process_info_t.thread_state], THREAD_STATE_FREE
        jmp     .exit
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.get_task_switch_counter ;////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.0: get task switch counter value
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 0
;-----------------------------------------------------------------------------------------------------------------------
;< eax = switch counter
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [context_counter]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.change_task ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.1: change task
;-----------------------------------------------------------------------------------------------------------------------
        call    change_task
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.performance_ctl ;////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.2: performance control
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = 2
;> ecx = 0 - enable or disable (inversion) PCE flag on CR4 for rdmpc in user mode.
;>           returned new cr4 in eax. Ret cr4 in eax. Block.
;>       1 - is cache enabled. Ret cr0 in eax if enabled else zero in eax. Block.
;>       2 - enable cache. Ret 1 in eax. Ret nothing. Block.
;>       3 - disable cache. Ret 0 in eax. Ret nothing. Block.
;-----------------------------------------------------------------------------------------------------------------------
        inc     ebx ; ebx = 3
        cmp     ebx, ecx ; if ecx == 3
        jz      cache_disable

        dec     ebx ; ebx = 2
        cmp     ebx, ecx ; if ecx == 2
        jz      cache_enable

        dec     ebx ; ebx = 1
        cmp     ebx, ecx ; if ecx == 1
        jz      is_cache_enabled

        dec     ebx ; ebx = 0
        test    ebx, ecx ; if ecx == 0
        jz      modify_pce

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.read_msr_register ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.3: rdmsr
;-----------------------------------------------------------------------------------------------------------------------
;> edx = counter
;-----------------------------------------------------------------------------------------------------------------------
;# (edx:eax) [esi:edi, edx] => [edx:esi, ecx]. Ret in ebx:eax. Block.
;-----------------------------------------------------------------------------------------------------------------------
        ; now counter in ecx
        ; (edx:eax) esi:edi => edx:esi
        mov     eax, esi
        mov     ecx, edx
        rdmsr
        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], edx ; ret in ebx?
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.system_service.write_msr_register ;/////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 68.4: wrmsr
;-----------------------------------------------------------------------------------------------------------------------
;> edx = counter
;-----------------------------------------------------------------------------------------------------------------------
;# (edx:eax) [esi:edi, edx] => [edx:esi, ecx]. Ret in ebx:eax. Block.
;-----------------------------------------------------------------------------------------------------------------------
        ; now counter in ecx
        ; (edx:eax) esi:edi => edx:esi
        ; Fast Call MSR can't be destroy
        ; But MSR_AMD_EFER could be changed since this register only
        ; turns on/off extended capabilities
        cmp     edx, MSR_SYSENTER_CS
        je      @f
        cmp     edx, MSR_SYSENTER_ESP
        je      @f
        cmp     edx, MSR_SYSENTER_EIP
        je      @f
        cmp     edx, MSR_AMD_STAR
        je      @f

        mov     eax, esi
        mov     ecx, edx
        wrmsr
;       mov     [esp + 4 + regs_context32_t.eax], eax
;       mov     [esp + 4 + regs_context32_t.ebx], edx ; ret in ebx?

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cache_disable ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, cr0
        or      eax, CR0_NW + CR0_CD
        mov     cr0, eax
        wbinvd  ; set MESI
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cache_enable ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, cr0
        and     eax, not (CR0_NW + CR0_CD)
        mov     cr0, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc is_cache_enabled ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, cr0
        mov     ebx, eax
        and     eax, CR0_NW + CR0_CD
        jz      .cache_disabled
        mov     [esp + 4 + regs_context32_t.eax], ebx

  .cache_disabled:
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc modify_pce ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, cr4
;       mov     ebx, 0
;       or      bx, 0100000000b ; pce
;       xor     eax, ebx ; invert pce
        or      eax, CR4_PCE
        mov     cr4, eax
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

iglobal
  cpustring db 'CPU', 0
endg

uglobal
  background_defined db 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc checkmisc ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [ctrl_alt_del], 1
        jne     .nocpustart

        mov     ebp, cpustring
        call    fs_execute_from_sysdir

        mov     [ctrl_alt_del], 0

  .nocpustart:
        cmp     [mouse_active], 1
        jne     .mouse_not_active
        mov     [mouse_active], 0
        xor     edi, edi
        mov     ecx, [legacy_slots.last_valid_slot]

  .set_mouse_event:
        add     edi, sizeof.legacy.slot_t
        or      [legacy_slots + edi + legacy.slot_t.app.event_mask], EVENT_MOUSE
        loop    .set_mouse_event

  .mouse_not_active:
        cmp     [BACKGROUND_CHANGED], 0
        jz      .no_set_bgr_event
        xor     edi, edi
        mov     ecx, [legacy_slots.last_valid_slot]

  .set_bgr_event:
        add     edi, sizeof.legacy.slot_t
        or      [legacy_slots + edi + legacy.slot_t.app.event_mask], EVENT_BACKGROUND
        loop    .set_bgr_event
        mov     [BACKGROUND_CHANGED], 0

  .no_set_bgr_event:
        cmp     [REDRAW_BACKGROUND], 0 ; background update?
        jz      .nobackgr
        cmp     [background_defined], 0
        jz      .nobackgr
;       mov     [legacy_os_idle_slot.draw.left], 0
;       mov     [legacy_os_idle_slot.draw.top], 0
;       mov     eax, [Screen_Max_Pos.x]
;       mov     ebx, [Screen_Max_Pos.y]
;       mov     [legacy_os_idle_slot.draw.right], eax
;       mov     [legacy_os_idle_slot.draw.bottom], ebx

    @@: call    drawbackground
        xor     eax, eax
        xchg    al, [REDRAW_BACKGROUND]
        test    al, al ; got new update request?
        jnz     @b
        mov     [legacy_os_idle_slot.draw.left], eax
        mov     [legacy_os_idle_slot.draw.top], eax
        mov     [legacy_os_idle_slot.draw.right], eax
        mov     [legacy_os_idle_slot.draw.bottom], eax
;       mov     [MOUSE_BACKGROUND], 0

  .nobackgr:
        ; system shutdown request
        cmp     [SYS_SHUTDOWN], 0
        je      .noshutdown

        mov     edx, [shutdown_processes]

        cmp     [SYS_SHUTDOWN], dl
        jne     .no_mark_system_shutdown

        lea     ecx, [edx - 1]
        mov     edx, legacy_slots + 2 * sizeof.legacy.slot_t
        jecxz   @f

  .markz:
        mov     byte[edx + legacy.slot_t.task.state], THREAD_STATE_ZOMBIE
        add     edx, sizeof.legacy.slot_t
        loop    .markz

  .no_mark_system_shutdown:
    @@: call    [_display.disable_mouse]

        dec     [SYS_SHUTDOWN]
        je      system_shutdown

  .noshutdown:
        ; termination
        mov     eax, [legacy_slots.last_valid_slot]
        mov     ebx, legacy_slots + sizeof.legacy.slot_t + legacy.slot_t.task.state
        mov     esi, 1

  .newct:
        mov     cl, [ebx]
        cmp     cl, THREAD_STATE_ZOMBIE
        jz      terminate
        cmp     cl, THREAD_STATE_TERMINATING
        jz      terminate

        add     ebx, sizeof.legacy.slot_t
        inc     esi
        dec     eax
        jnz     .newct
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc redrawscreen ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; eax, if process window_data base is eax, do not set flag/limits

        pushad
        push    eax

;;;     mov     ebx, 2
;;;     call    sysfn.delay_hs

;       mov     ecx, 0 ; redraw flags for apps
        xor     ecx, ecx

  .newdw2:
        inc     ecx
        push    ecx

        mov     eax, ecx
        shl     eax, 9 ; * sizeof.legacy.slot_t
        add     eax, legacy_slots

        cmp     eax, [esp + 4]
        je      .not_this_task

        ; check if window in redraw area
        mov     edi, eax

        cmp     ecx, 1 ; limit for background
        jz      .bgli

        mov     eax, [edi + legacy.slot_t.window.box.left]
        mov     ebx, [edi + legacy.slot_t.window.box.top]
        mov     ecx, [edi + legacy.slot_t.window.box.width]
        mov     edx, [edi + legacy.slot_t.window.box.height]
        add     ecx, eax
        add     edx, ebx

        mov     ecx, [draw_limits.bottom] ; ecx = area y end, ebx == window y start
        cmp     ecx, ebx
        jb      .ricino

        mov     ecx, [draw_limits.right] ; ecx = area x end, eax == window x start
        cmp     ecx, eax
        jb      .ricino

        mov     eax, [edi + legacy.slot_t.window.box.left]
        mov     ebx, [edi + legacy.slot_t.window.box.top]
        mov     ecx, [edi + legacy.slot_t.window.box.width]
        mov     edx, [edi + legacy.slot_t.window.box.height]
        add     ecx, eax
        add     edx, ebx

        mov     eax, [draw_limits.top] ; eax = area y start, edx == window y end
        cmp     edx, eax
        jb      .ricino

        mov     eax, [draw_limits.left] ; eax = area x start, ecx == window x end
        cmp     ecx, eax
        jb      .ricino

  .bgli:
        cmp     dword[esp], 1
        jnz     .az
;       cmp     [BACKGROUND_CHANGED], 0
;       jnz     .newdw8
        cmp     [REDRAW_BACKGROUND], 0
        jz      .az
        mov     dl, 0
        mov     eax, edi
        mov     ebx, [draw_limits.left]
        cmp     ebx, [eax + legacy.slot_t.draw.left]
        jae     @f
        mov     [eax + legacy.slot_t.draw.left], ebx
        mov     dl, 1

    @@: mov     ebx, [draw_limits.top]
        cmp     ebx, [eax + legacy.slot_t.draw.top]
        jae     @f
        mov     [eax + legacy.slot_t.draw.top], ebx
        mov     dl, 1

    @@: mov     ebx, [draw_limits.right]
        cmp     ebx, [eax + legacy.slot_t.draw.right]
        jbe     @f
        mov     [eax + legacy.slot_t.draw.right], ebx
        mov     dl, 1

    @@: mov     ebx, [draw_limits.bottom]
        cmp     ebx, [eax + legacy.slot_t.draw.bottom]
        jbe     @f
        mov     [eax + legacy.slot_t.draw.bottom], ebx
        mov     dl, 1

    @@: add     [REDRAW_BACKGROUND], dl
        jmp     .newdw8

  .az:
        mov     eax, edi

        ; set limits
        mov     ebx, [draw_limits.left]
        mov     [eax + legacy.slot_t.draw.left], ebx
        mov     ebx, [draw_limits.top]
        mov     [eax + legacy.slot_t.draw.top], ebx
        mov     ebx, [draw_limits.right]
        mov     [eax + legacy.slot_t.draw.right], ebx
        mov     ebx, [draw_limits.bottom]
        mov     [eax + legacy.slot_t.draw.bottom], ebx

        cmp     dword[esp], 1
        jne     .nobgrd
        inc     [REDRAW_BACKGROUND]

  .newdw8:
  .nobgrd:
        mov     [eax + legacy.slot_t.window.fl_redraw], 1 ; mark as redraw

  .ricino:
  .not_this_task:
        pop     ecx

        cmp     ecx, [legacy_slots.last_valid_slot]
        jle     .newdw2

        pop     eax
        popad

        ret
kendp

uglobal
  imax dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc delay_ms ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? delay in 1/1000 sec
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    ecx

        mov     ecx, esi
        ; <CPU clock fix by Sergey Kuzmin aka Wildwest>
        imul    ecx, 33941
        shr     ecx, 9
        ; </CPU clock fix>

        in      al, 0x61
        and     al, 0x10
        mov     ah, al

  .cnt1:
        in      al, 0x61
        and     al, 0x10
        cmp     al, ah
        jz      .cnt1

        mov     ah, al
        loop    .cnt1

        pop     ecx
        pop     eax

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_process_event_mask ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 40
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [current_thread_ptr]
        mov     eax, [edi + core.thread_t.events.event_mask]
        mov     [edi + core.thread_t.events.event_mask], ebx

        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.delay_hs ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 5: delay in 1/100 secs
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = delay time
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx

        mov     eax, ebx
        xor     edx, edx
        call    hs_to_ticks
        add     eax, dword[timer_ticks]
        adc     edx, dword[timer_ticks + 4]

  .check_for_timeout:
        cmp     edx, dword[timer_ticks + 4]
        jne     @f
        cmp     eax, dword[timer_ticks]

    @@: jbe     .exit

        call    change_task
        jmp     .check_for_timeout

  .exit:
        pop     edx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.program_irq ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 44
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [current_slot_ptr]
        add     ebx, [eax + legacy.slot_t.task.mem_start]

        cmp     ecx, 16
        jae     .not_owner
        mov     edi, [eax + legacy.slot_t.task.pid]
        cmp     edi, [irq_owner + ecx * 4]
        je      .spril1

  .not_owner:
        xor     ecx, ecx
        inc     ecx
        jmp     .end

  .spril1:
        shl     ecx, 6
        mov     esi, ebx
        lea     edi, [irq00read + ecx]
        push    16
        pop     ecx

        rep
        movsd

  .end:
        mov     [esp + 4 + regs_context32_t.eax], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_irq_data ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 42
;-----------------------------------------------------------------------------------------------------------------------
        movzx   esi, bh ; save number of subfunction, if bh = 1, return data size, otherwise, read data
        xor     bh, bh
        cmp     ebx, 16
        jae     .not_owner
        mov     edx, [irq_owner + ebx * 4] ; check for irq owner

        mov     eax, [current_slot_ptr]

        cmp     edx, [eax + legacy.slot_t.task.pid]
        je      .gidril1

  .not_owner:
        xor     edx, edx
        dec     edx
        jmp     .gid1

  .gidril1:
        shl     ebx, 12
        lea     eax, [IRQ_SAVE + ebx] ; eax = address of the beginning of buffer: +0x0 - data size, +0x4 - data offset
        mov     edx, [eax]
        dec     esi
        jz      .gid1
        test    edx, edx ; check if buffer is empty
        jz      .gid1

        mov     ebx, [eax + 0x4]
        mov     edi, ecx

        mov     ecx, 4000 ; buffer size, used frequently

        cmp     ebx, ecx ; check for the end of buffer, if end of buffer, begin cycle again
        jb      @f

        xor     ebx, ebx

    @@: lea     esi, [ebx + edx] ; calculate data size and offset
        cmp     esi, ecx ; if greater than the buffer size, begin cycle again
        jbe     @f

        sub     ecx, ebx
        sub     edx, ecx

        lea     esi, [eax + ebx + 0x10]
        rep
        movsb

        xor     ebx, ebx

    @@: lea     esi, [eax + ebx + 0x10]
        mov     ecx, edx
        add     ebx, edx

        rep
        movsb
        mov     edx, [eax]
        mov     [eax], ecx ; set data size to zero
        mov     [eax + 0x4], ebx ; set data offset

  .gid1:
        mov     [esp + 4 + regs_context32_t.eax], edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc set_io_access_rights ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edi eax
        mov     edi, tss.io_map_0
;       mov     ecx, eax
;       and     ecx, 7 ; offset in byte
;       shr     eax, 3 ; number of byte
;       add     edi, eax
;       mov     ebx, 1
;       shl     ebx, cl
        test    ebp, ebp
;       cmp     ebp, 0 ; enable access - ebp = 0
        jnz     .siar1
;       not     ebx
;       and     [edi], bl
        btr     [edi], eax
        pop     eax edi
        ret

  .siar1:
        bts     [edi], eax
;       or      [edi], bl ; disable access - ebp = 1
        pop     eax edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc r_f_port_area ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? reserve/free group of ports
;-----------------------------------------------------------------------------------------------------------------------
;> eax = 46 - number function
;> ebx = 0 - reserve, 1 - free
;> ecx = number start arrea of ports
;> edx = number end arrea of ports (include last number of port)
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 - succesful
;< eax = 1 - error
;-----------------------------------------------------------------------------------------------------------------------
;# The system reserves these ports: 0..0x2d, 0x30..0x4d, 0x50..0xdf, 0xe5..0xff (inclusively).
;# Destroys eax, ebx, ebp.
;-----------------------------------------------------------------------------------------------------------------------
        test    ebx, ebx
;       je      .r_port_area
;       jmp     .free_port_area
        jnz     .free_port_area

; .r_port_area:
;       pushad

        cmp     ecx, edx ; beginning > end ?
        ja      .rpal1
        cmp     edx, 65536
        jae     .rpal1
        mov     eax, [RESERVED_PORTS.count]
        test    eax, eax ; no reserved areas ?
        je      .rpal2
        cmp     eax, RESERVED_PORTS_MAX_COUNT ; max reserved
        jae     .rpal1

  .rpal3:
        mov     ebx, eax
        shl     ebx, 4
        add     ebx, RESERVED_PORTS
        cmp     ecx, [ebx + app_io_ports_range_t.end_port]
        ja      .rpal4
        cmp     edx, [ebx + app_io_ports_range_t.start_port]
;       jb      .rpal4
;       jmp     .rpal1
        jae     .rpal1

  .rpal4:
        dec     eax
        jnz     .rpal3
        jmp     .rpal2

  .rpal1:
;       popad
;       mov     eax, 1
        xor     eax, eax
        inc     eax
        ret

  .rpal2:
;       popad
        ; enable port access at port IO map
        cli
        pushad  ; start enable io map

        cmp     edx, 65536 ; 16384
        jae     .no_unmask_io ; jge
        mov     eax, ecx
;       push    ebp
        xor     ebp, ebp ; enable - eax = port

  .new_port_access:
;       pushad
        call    set_io_access_rights
;       popad
        inc     eax
        cmp     eax, edx
        jbe     .new_port_access
;       pop     ebp

  .no_unmask_io:
        popad ; end enable io map
        sti

        mov     eax, [RESERVED_PORTS.count]
        add     eax, 1
        mov     [RESERVED_PORTS.count], eax
        shl     eax, 4
        add     eax, RESERVED_PORTS
        mov     ebx, [current_slot_ptr]
        mov     ebx, [ebx + legacy.slot_t.task.pid]
        mov     [eax + app_io_ports_range_t.pid], ebx
        mov     [eax + app_io_ports_range_t.start_port], ecx
        mov     [eax + app_io_ports_range_t.end_port], edx

        xor     eax, eax
        ret

  .free_port_area:
;       pushad
        mov     eax, [RESERVED_PORTS.count] ; no reserved areas?
        test    eax, eax
        jz      .frpal2
        mov     ebx, [current_slot_ptr]
        mov     ebx, [ebx + legacy.slot_t.task.pid]

  .frpal3:
        mov     edi, eax
        shl     edi, 4
        add     edi, RESERVED_PORTS
        cmp     ebx, [edi + app_io_ports_range_t.pid]
        jne     .frpal4
        cmp     ecx, [edi + app_io_ports_range_t.start_port]
        jne     .frpal4
        cmp     edx, [edi + app_io_ports_range_t.end_port]
        jne     .frpal4
        jmp     .frpal1

  .frpal4:
        dec     eax
        jnz     .frpal3

  .frpal2:
;       popad
        inc     eax
        ret

  .frpal1:
        push    ecx
        mov     ecx, 256
        sub     ecx, eax
        shl     ecx, 4
        mov     esi, edi
        add     esi, 16
        movsb

        dec     [RESERVED_PORTS.count]
;       popad

        ; disable port access at port IO map
;       pushad  ; start disable io map
        pop     eax ; start port
        cmp     edx, 65536 ; 16384
        jge     .no_mask_io

;       mov     eax, ecx
        xor     ebp, ebp
        inc     ebp

  .new_port_access_disable:
;       pushad
;       mov     ebp, 1 ; disable - eax = port
        call    set_io_access_rights
;       popad
        inc     eax
        cmp     eax, edx
        jbe     .new_port_access_disable

  .no_mask_io:
;       popad   ; end disable io map
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.reserve_irq ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 45
;-----------------------------------------------------------------------------------------------------------------------
        xor     esi, esi
        inc     esi
        cmp     ecx, 16
        jae     .ril1

        push    ecx
        lea     ecx, [irq_owner + ecx * 4]
        mov     edx, [ecx]
        mov     eax, [current_slot_ptr]
        mov     edi, [eax + legacy.slot_t.task.pid]
        pop     eax
        dec     ebx
        jnz     .reserve_irq

        cmp     edx, edi
        jne     .ril1
        dec     esi
        mov     [ecx], esi

        jmp     .ril1

  .reserve_irq:
        cmp     dword[ecx], 0
        jne     .ril1

        mov     ebx, [f_irqs + eax * 4]

        stdcall attach_int_handler, eax, ebx, 0

        mov     [ecx], edi

        dec     esi

  .ril1:
        mov     [esp + 4 + regs_context32_t.eax], esi ; return in eax
        ret
kendp

iglobal
  f_irqs:
    dd 0
    dd 0
    dd p_irq2
    dd p_irq3
    dd p_irq4
    dd p_irq5
    dd p_irq6
    dd p_irq7
    dd p_irq8
    dd p_irq9
    dd p_irq10
    dd p_irq11
    dd 0
    dd 0
    dd 0
    dd 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc __sys_drawbar ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = x beginning
;> ebx = y beginning
;> ecx = x end
;> edx = y end
;> edi = color
;-----------------------------------------------------------------------------------------------------------------------
        inc     [mouse_pause]
;       call    [disable_mouse]
        cmp     [SCR_MODE], 0x12
        je      .dbv20

  .sdbv20:
        cmp     [SCR_MODE], 0100000000000000b
        jge     .dbv20
        cmp     [SCR_MODE], 0x13
        je      .dbv20

        call    vesa12_drawbar
        dec     [mouse_pause]
        call    [draw_pointer]
        ret

  .dbv20:
        call    vesa20_drawbar
        dec     [mouse_pause]
        call    [draw_pointer]
        ret
kendp

if used _rdtsc

;-----------------------------------------------------------------------------------------------------------------------
kproc _rdtsc ;//////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        bt      [cpu_caps], CAPS_TSC
        jnc     .ret_rdtsc
        rdtsc
        ret

  .ret_rdtsc:
        mov     edx, 0xffffffff
        mov     eax, 0xffffffff
        ret
kendp

end if

;-----------------------------------------------------------------------------------------------------------------------
kproc rerouteirqs ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cli

        mov     al, 0x11 ; icw4, edge triggered
        out     0x20, al
        call    .pic_delay
        out     0xa0, al
        call    .pic_delay

        mov     al, 0x20 ; generate 0x20 +
        out     0x21, al
        call    .pic_delay
        mov     al, 0x28 ; generate 0x28 +
        out     0xa1, al
        call    .pic_delay

        mov     al, 0x04 ; slave at irq2
        out     0x21, al
        call    .pic_delay
        mov     al, 0x02 ; at irq9
        out     0xa1, al
        call    .pic_delay

        mov     al, 0x01 ; 8086 mode
        out     0x21, al
        call    .pic_delay
        out     0xa1, al
        call    .pic_delay

        mov     al, 0xff ; mask all irq's
        out     0xa1, al
        call    .pic_delay
        out     0x21, al
        call    .pic_delay

        mov     ecx, 0x1000

  .picl1:
        call    .pic_delay
        loop    .picl1

        mov     al, 0xff ; mask all irq's
        out     0x0a1, al
        call    .pic_delay
        out     0x21, al
        call    .pic_delay

        cli
        ret

  .pic_delay:
        jmp     .pdl1

  .pdl1:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sys_msg_board_str ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushad

    @@: mov     bl, [esi]
        or      bl, bl
        jz      @f
        call    sysfn.debug_board.push_back
        inc     esi
        jmp     @b

    @@: popad
        ret
kendp

uglobal
  msg_board_data  db 4096 dup(?)
  msg_board_count dd 0
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_board ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 63
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfn.debug_board, subfn, sysfn.not_implemented_cross_order, \
    push_back, \ ; 1
    pop_front ; 2
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     eax
        cmp     eax, .countof.subfn
        jae     sysfn.not_implemented_cross_order

        jmp     [.subfn + eax * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_board.push_back ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 63.1
;-----------------------------------------------------------------------------------------------------------------------
; eax=1 : write :  bl byte to write
;-----------------------------------------------------------------------------------------------------------------------

if KCONFIG_DEBUG_COM_BASE

        push    eax edx

    @@: ; Wait for empty transmit register  (yes, this slows down system)
        mov     dx, KCONFIG_DEBUG_COM_BASE + 5
        in      al, dx
        test    al, 1 shl 5
        jz      @b

        mov     dx, KCONFIG_DEBUG_COM_BASE      ; Output the byte
        mov     al, bl
        out     dx, al

        pop     edx eax

end if

        mov     ecx, [msg_board_count]
        mov     [msg_board_data + ecx], bl
        inc     ecx
        and     ecx, 4095
        mov     [msg_board_count], ecx
        mov     [check_idle_semaphore], 5
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_board.pop_front ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 63.2
;-----------------------------------------------------------------------------------------------------------------------
; eax=2 :  read :  ebx=0 -> no data, ebx=1 -> data in al
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [msg_board_count]
        test    ecx, ecx
        jz      .smbl21

        mov     eax, msg_board_data + 1
        mov     ebx, msg_board_data
        movzx   edx, byte[ebx]
        call    memmove

        dec     ecx
        mov     [msg_board_count], ecx
        mov     [esp + 8 + regs_context32_t.eax], edx
        mov     [esp + 8 + regs_context32_t.ebx], 1
        ret

  .smbl21:
        mov     [esp + 8 + regs_context32_t.eax], ecx
        mov     [esp + 8 + regs_context32_t.ebx], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfs.direct_screen_access ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 61: direct screen access
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  JumpTable sysfs.direct_screen_access, subfn, sysfn.not_implemented, \
    get_screen_resolution, \ ; 1
    get_bits_per_pixel, \ ; 2
    get_bytes_per_scanline ; 3
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfs.direct_screen_access.get_screen_resolution ;////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 61.1: get screen resolution
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [Screen_Max_Pos.x]
        shl     eax, 16
        mov     ax, word[Screen_Max_Pos.y]
        add     eax, 0x00010001
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfs.direct_screen_access.get_bits_per_pixel ;///////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 61.2: get bits per pixel
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, [ScreenBPP]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfs.direct_screen_access.get_bytes_per_scanline ;///////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 61.3: get bytes per scanline
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [BytesPerScanLine]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_pixel ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 1
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, ebx
        mov     ebx, ecx
        mov     ecx, edx
        mov     edx, [current_slot_ptr]
        add     eax, [edx + legacy.slot_t.window.box.left]
        add     ebx, [edx + legacy.slot_t.window.box.top]
        mov     edi, [current_slot_ptr]
        add     eax, [edi + legacy.slot_t.app.wnd_clientbox.left]
        add     ebx, [edi + legacy.slot_t.app.wnd_clientbox.top]
        xor     edi, edi ; no force
;       mov     edi, 1
        call    [_display.disable_mouse]
        jmp     [putpixel]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.draw_rect ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 13
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, edx ; color + gradient
        and     edi, 0x80ffffff
        test    bx, bx ; x.size
        je      .drectr
        test    cx, cx ; y.size
        je      .drectr

        mov     eax, ebx ; bad idea
        mov     ebx, ecx

        movzx   ecx, ax ; ecx - x.size
        shr     eax, 16 ; eax - x.coord
        movzx   edx, bx ; edx - y.size
        shr     ebx, 16 ; ebx - y.coord
        mov     esi, [current_slot_ptr]

        add     eax, [esi + legacy.slot_t.app.wnd_clientbox.left]
        add     ebx, [esi + legacy.slot_t.app.wnd_clientbox.top]
        add     ecx, eax
        add     edx, ebx
        jmp     [drawbar]

  .drectr:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_screen_size ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 14
;-----------------------------------------------------------------------------------------------------------------------
        mov     ax, word[Screen_Max_Pos.x]
        shl     eax, 16
        mov     ax, word[Screen_Max_Pos.y]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_pixel ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 35
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [Screen_Max_Pos.x]
        inc     ecx
        xor     edx, edx
        mov     eax, ebx
        div     ecx
        mov     ebx, edx
        xchg    eax, ebx
        call    [GETPIXEL] ; eax - x, ebx - y
        mov     [esp + 4 + regs_context32_t.eax], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.grab_screen_area ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 36
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= 36
;> ebx ^= buffer for image, BBGGRRBBGGRR...
;> ecx @= pack[16(width), 16(height)]
;> edx @= pack[16(x), 16(y)]
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        inc     [mouse_pause]

        ; Check of use of the hardware cursor.
        cmp     [_display.disable_mouse], __sys_disable_mouse
        jne     @f

        ; Since the test for the coordinates of the mouse should not be used,
        ; then use the call [disable_mouse] is not possible!
        cmp     [MOUSE_VISIBLE], 0
        jne     @f
        pushf
        cli
        call    draw_mouse_under
        popf
        mov     [MOUSE_VISIBLE], 1

    @@: mov     edi, ebx
        mov     eax, edx
        shr     eax, 16
        mov     ebx, edx
        and     ebx, 0x0000ffff
        dec     eax
        dec     ebx
        ; eax - x, ebx - y

        mov     edx, ecx
        shr     ecx, 16
        and     edx, 0x0000ffff
        mov     esi, ecx
        ; ecx - size x, edx - size y

        mov     ebp, edx
        dec     ebp
        lea     ebp, [ebp * 3]

        imul    ebp, esi

        mov     esi, ecx
        dec     esi
        lea     esi, [esi * 3]

        add     ebp, esi
        add     ebp, edi

        add     ebx, edx

  .start_y:
        push    ecx edx

  .start_x:
        push    eax ebx ecx
        add     eax, ecx

        call    [GETPIXEL] ; eax - x, ebx - y

        mov     [ebp], cx
        shr     ecx, 16
        mov     [ebp + 2], cl

        pop     ecx ebx eax
        sub     ebp, 3
        dec     ecx
        jnz     .start_x
        pop     edx ecx
        dec     ebx
        dec     edx
        jnz     .start_y
        dec     [mouse_pause]

        ; Check of use of the hardware cursor.
        cmp     [_display.disable_mouse], __sys_disable_mouse
        jne     @f
        call    [draw_pointer]

    @@: popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.draw_line ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 38
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [current_slot_ptr]
        movzx   eax, word[edi + legacy.slot_t.window.box.left]
        mov     ebp, eax
        mov     esi, [current_slot_ptr]
        add     ebp, [esi + legacy.slot_t.app.wnd_clientbox.left]
        add     ax, word[esi + legacy.slot_t.app.wnd_clientbox.left]
        add     ebp, ebx
        shl     eax, 16
        movzx   ebx, word[edi + legacy.slot_t.window.box.top]
        add     eax, ebp
        mov     ebp, ebx
        add     ebp, [esi + legacy.slot_t.app.wnd_clientbox.top]
        add     bx, word[esi + legacy.slot_t.app.wnd_clientbox.top]
        add     ebp, ecx
        shl     ebx, 16
        xor     edi, edi
        add     ebx, ebp
        mov     ecx, edx
        jmp     [draw_line]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_irq_owner ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 41
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ebx, 16
        jae     .err

        cmp     dword[irq_rights + ebx * 4], 2
        je      .err

        mov     eax, [irq_owner + ebx * 4]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .err:
        or      [esp + 4 + regs_context32_t.eax], -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.reserve_port_area ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 46
;-----------------------------------------------------------------------------------------------------------------------
        call    r_f_port_area
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc set_screen ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, [Screen_Max_Pos.x]
        jne     .set

        cmp     edx, [Screen_Max_Pos.y]
        jne     .set
        ret

  .set:
        pushfd
        cli

        mov     [Screen_Max_Pos.x], eax
        mov     [Screen_Max_Pos.y], edx
        mov     [BytesPerScanLine], ecx

        mov     [screen_workarea.right], eax
        mov     [screen_workarea.bottom], edx

        push    ebx
        push    esi
        push    edi

        pushad

        stdcall kernel_free, [_WinMapRange.address]

        mov     eax, [_display.box.width]
        mul     [_display.box.height]
        mov     [_WinMapRange.size], eax

        stdcall kernel_alloc, eax
        mov     [_WinMapRange.address], eax
        test    eax, eax
        jz      .epic_fail

        popad

        call    repos_windows
        xor     eax, eax
        xor     ebx, ebx
        mov     ecx, [Screen_Max_Pos.x]
        mov     edx, [Screen_Max_Pos.y]
        call    calculatescreen
        pop     edi
        pop     esi
        pop     ebx

        popfd
        ret

  .epic_fail:
        hlt                     ; Houston, we've had a problem
kendp

        ; --------------- APM ---------------------

uglobal
  apm_entry dp ?
  apm_vf    dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.apm_ctl ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 49
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        cmp     word[apm_vf], ax ; Check APM BIOS enable
        jne     @f
        inc     eax
        or      dword[esp + 44], eax ; error
        add     eax, 7
        mov     dword[esp + 4 + regs_context32_t.eax], eax ; 32-bit protected-mode interface not supported
        ret

    @@:
;       xchg    eax, ecx
;       xchg    ebx, ecx

        cmp     dx, 3
        ja      @f
        and     byte[esp + 44], 0xfe ; emulate func 0..3 as func 0
        mov     eax, [apm_vf]
        mov     [esp + 4 + regs_context32_t.eax], eax
        shr     eax, 16
        mov     [esp + 4 + regs_context32_t.ecx], eax
        ret

    @@: mov     esi, [master_tab + (OS_BASE shr 20)]
        xchg    [master_tab], esi
        push    esi
        mov     edi, cr3
        mov     cr3, edi ; flush TLB

        call    [apm_entry] ; call APM BIOS

        xchg    eax, [esp]
        mov     [master_tab], eax
        mov     eax, cr3
        mov     cr3, eax
        pop     eax

        mov     [esp + 4 + regs_context32_t.edi], edi
        mov     [esp + 4 + regs_context32_t.esi], esi
        mov     [esp + 4 + regs_context32_t.ebx], ebx
        mov     [esp + 4 + regs_context32_t.edx], edx
        mov     [esp + 4 + regs_context32_t.ecx], ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        setc    al
        and     byte[esp + 44], 0xfe
        or      [esp + 44], al
        ret
kendp

        ; -----------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
kproc system_shutdown ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [boot_var.shutdown_param], 1
        jne     @f
        ret

    @@: call    stop_all_services
        call    sys_cdpause ; stop playing cd

; .yes_shutdown_param:
        cli

if 0

        mov     eax, kernel_file ; load kernel.mnt to 0x7000:0
        push    12
        pop     esi
        xor     ebx, ebx
        or      ecx, -1
        mov     edx, OS_BASE + 0x70000
        call    fileread

else

        mov     esi, KERNEL_CODE
        mov     edi, OS_BASE + 0x70000
        mov     ecx, 371 * 1024 / 4
        rep
        movsd

end if

        mov     esi, restart_kernel_4000 + OS_BASE + 0x10000 ; move kernel re-starter to 0x4000:0
        mov     edi, OS_BASE + 0x40000
        mov     ecx, 1000
        rep
        movsb

        mov     esi, boot_data_area ; restore 0x0 - 0xffff
        mov     edi, OS_BASE
        mov     ecx, 0x10000 / 4
        rep
        movsd

        mov     esi, RAMDISK_FAT
        mov     edi, RAMDISK + 512
        call    fs.fat12.restore_fat_chain

        mov     al, 0xff
        out     0x21, al
        out     0xa1, al

if 0

        mov     word[OS_BASE + 0x467 + 0], pr_mode_exit
        mov     word[OS_BASE + 0x467 + 2], 0x1000

        mov     al, 0x0f
        out     0x70, al
        mov     al, 0x05
        out     0x71, al

        mov     al, 0xfe
        out     0x64, al

        hlt
        jmp     $ - 1

else

        cmp     [OS_BASE + boot_var.low.shutdown_param], 1
        je      .no_acpi_power_off

        ; scan for RSDP
        ; 1) The first 1 Kb of the Extended BIOS Data Area (EBDA).
        movzx   eax, word[OS_BASE + 0x40e]
        shl     eax, 4
        jz      @f
        mov     ecx, 1024 / 16
        call    .scan_rsdp
        jnc     .rsdp_found

    @@: ; 2) The BIOS read-only memory space between 0E0000h and 0FFFFFh.
        mov     eax, 0xe0000
        mov     ecx, 0x2000
        call    .scan_rsdp
        jc      .no_acpi_power_off

  .rsdp_found:
        mov     esi, [eax + 16] ; esi contains physical address of the RSDT
        mov     ebp, [ipc_tmp]
        stdcall map_page, ebp, esi, PG_MAP
        lea     eax, [esi + 0x1000]
        lea     edx, [ebp + 0x1000]
        stdcall map_page, edx, eax, PG_MAP
        and     esi, 0x0fff
        add     esi, ebp
        cmp     dword[esi], 'RSDT'
        jnz     .no_acpi_power_off
        mov     ecx, [esi + 4]
        sub     ecx, 0x24
        jbe     .no_acpi_power_off
        shr     ecx, 2
        add     esi, 0x24

  .scan_fadt:
        lodsd
        mov     ebx, eax
        lea     eax, [ebp + 0x2000]
        stdcall map_page, eax, ebx, PG_MAP
        lea     eax, [ebp + 0x3000]
        add     ebx, 0x1000
        stdcall map_page, eax, ebx, PG_MAP
        and     ebx, 0x0fff
        lea     ebx, [ebx + ebp + 0x2000]
        cmp     dword[ebx], 'FACP'
        jz      .fadt_found
        loop    .scan_fadt
        jmp     .no_acpi_power_off

  .fadt_found:
        ; ebx is linear address of FADT
        mov     edi, [ebx + 40] ; physical address of the DSDT
        lea     eax, [ebp + 0x4000]
        stdcall map_page, eax, edi, PG_MAP
        lea     eax, [ebp + 0x5000]
        lea     esi, [edi + 0x1000]
        stdcall map_page, eax, esi, PG_MAP
        and     esi, 0x0fff
        sub     edi, esi
        cmp     dword[esi + ebp + 0x4000], 'DSDT'
        jnz     .no_acpi_power_off
        mov     eax, [esi + ebp + 0x4004] ; DSDT length
        sub     eax, 36 + 4
        jbe     .no_acpi_power_off
        add     esi, 36

  .scan_dsdt:
        cmp     dword[esi + ebp + 0x4000], '_S5_'
        jnz     .scan_dsdt_cont
        cmp     byte[esi + ebp + 0x4000 + 4], 0x12 ; DefPackage opcode
        jnz     .scan_dsdt_cont
        mov     dl, [esi + ebp + 0x4000 + 6]
        cmp     dl, 4 ; _S5_ package must contain 4 bytes... in theory; in practice, VirtualBox has 2 bytes
        ja      .scan_dsdt_cont
        cmp     dl, 1
        jb      .scan_dsdt_cont
        lea     esi, [esi + ebp + 0x4000 + 7]
        xor     ecx, ecx
        cmp     byte[esi], 0 ; 0 means zero byte, 0Ah xx means byte xx
        jz      @f
        cmp     byte[esi], 0x0a
        jnz     .no_acpi_power_off
        inc     esi
        mov     cl, [esi]

    @@: inc     esi
        cmp     dl, 2
        jb      @f
        cmp     byte[esi], 0
        jz      @f
        cmp     byte[esi], 0x0a
        jnz     .no_acpi_power_off
        inc     esi
        mov     ch, [esi]

    @@: jmp     .do_acpi_power_off

  .scan_dsdt_cont:
        inc     esi
        cmp     esi, 0x1000
        jb      @f
        sub     esi, 0x1000
        add     edi, 0x1000
        push    eax
        lea     eax, [ebp + 0x4000]
        stdcall map_page, eax, edi, PG_MAP
        push    PG_MAP
        lea     eax, [edi + 0x1000]
        push    eax
        lea     eax, [ebp + 0x5000]
        push    eax
        stdcall map_page
        pop     eax

    @@: dec     eax
        jnz     .scan_dsdt
        jmp     .no_acpi_power_off

  .do_acpi_power_off:
        mov     edx, [ebx + 48]
        test    edx, edx
        jz      .nosmi
        mov     al, [ebx + 52]
        out     dx, al
        mov     edx, [ebx + 64]

    @@: in      ax, dx
        test    al, 1
        jz      @b

  .nosmi:
        and     cx, 0x0707
        shl     cx, 2
        or      cx, 0x2020
        mov     edx, [ebx + 64]
        in      ax, dx
        and     ax, 0x203
        or      ah, cl
        out     dx, ax
        mov     edx, [ebx + 68]
        test    edx, edx
        jz      @f
        in      ax, dx
        and     ax, 0x203
        or      ah, ch
        out     dx, ax

    @@: jmp     $

  .no_acpi_power_off:
        mov     word[OS_BASE + 0x467 + 0], pr_mode_exit
        mov     word[OS_BASE + 0x467 + 2], 0x1000

        mov     al, 0x0f
        out     0x70, al
        mov     al, 0x05
        out     0x71, al

        mov     al, 0xfe
        out     0x64, al

        hlt
        jmp     $ - 1

  .scan_rsdp:
        add     eax, OS_BASE

  .s:
        cmp     dword[eax], 'RSD '
        jnz     .n
        cmp     dword[eax + 4], 'PTR '
        jnz     .n
        xor     edx, edx
        xor     esi, esi

    @@: add     dl, [eax + esi]
        inc     esi
        cmp     esi, 20
        jnz     @b
        test    dl, dl
        jz      .ok

  .n:
        add     eax, 0x10
        loop    .s
        stc

  .ok:
        ret
kendp

end if

include "data.inc"

uglobals_size = $ - endofcode

Diff16 "end of kernel code", 0, $
