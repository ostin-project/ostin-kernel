;;======================================================================================================================
;;///// kernel.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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

include "include/kernel.inc"

include "include/boot.inc"
include "include/const.inc"
include "include/kglobals.inc"
include "include/fs.inc"

max_processes   equ 255
tss_step        equ (128 + 8192) ; tss & i/o - 65535 ports, * 256 = 557056 * 4

os_stack        equ (os_data_l - gdts) ; GDTs
os_code         equ (os_code_l - gdts)
graph_data      equ (3 + graph_data_l - gdts)
tss0            equ (tss0_l - gdts)
app_code        equ (3 + app_code_l - gdts)
app_data        equ (3 + app_data_l - gdts)
app_tls         equ (3 + tls_data_l - gdts)
pci_code_sel    equ (pci_code_32 - gdts)
pci_data_sel    equ (pci_data_32 - gdts)

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
org 0x0

        jmp   boot.start

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
        cld

        mov     al, 255 ; mask all irqs
        out     0xa1, al
        out     0x21, al

l.5:
        in      al, 0x64 ; Enable A20
        test    al, 2
        jnz     l.5

        mov     al, 0xd1
        out     0x64, al

l.6:
        in      al, 0x64
        test    al, 2
        jnz     l.6

        mov     al, 0xdf
        out     0x60, al

l.7:
        in      al, 0x64
        test    al, 2
        jnz     l.7

        mov     al, 0xff
        out     0x64, al

        lgdt    [cs:tmp_gdt] ; Load GDT
        mov     eax, cr0 ; protected mode
        or      eax, ecx
        and     eax, (10011111b shl 24) + 0x00ffffff ; caching enabled
        mov     cr0, eax
        jmp     pword os_code:B32 ; jmp to enable 32 bit mode

align 8
tmp_gdt:
  dw 23
  dd tmp_gdt + 0x10000
  dw 0

  dw 0xffff
  dw 0x0000
  db 0x00
  dw 11011111b * 256 + 10011010b
  db 0x00

  dw 0xffff
  dw 0x0000
  db 0x00
  dw 11011111b * 256 + 10010010b
  db 0x00

include "data16.inc"

use32
org $ + 0x10000

align 4
B32:
        mov     ax, os_stack ; Selector for os
        mov     ds, ax
        mov     es, ax
        mov     fs, ax
        mov     gs, ax
        mov     ss, ax
        mov     esp, KERNEL_STACK_TOP - OS_BASE ; Set stack

        ; CLEAR 0x280000 - HEAP_BASE
        xor     eax, eax
        mov     edi, CLEAN_ZONE
        mov     ecx, (HEAP_BASE - OS_BASE - CLEAN_ZONE) / 4
        cld
        rep     stosd

;///        mov     edi, 0x40000
;///        mov     ecx, (0x90000 - 0x40000) / 4
;///        rep     stosd

        ; CLEAR KERNEL UNDEFINED GLOBALS
        mov     edi, endofcode - OS_BASE
;///        mov     ecx, (uglobals_size / 4) + 4
        mov     ecx, (0xa0000 - (endofcode - OS_BASE)) / 4
        rep     stosd

        ; SAVE & CLEAR 0-0xffff
        xor     esi, esi
        mov     edi, BOOT_VAR - OS_BASE
        mov     ecx, 0x10000 / 4
        rep     movsd
        mov     edi, 0x1000
        mov     ecx, 0xf000 / 4
        rep     stosd

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
org $ - 0x10000

include "boot/shutdown.asm"

use32
org $ + 0x10000

__DEBUG__ equ KCONFIG_DEBUG
__DEBUG_LEVEL__ equ KCONFIG_DEBUG_LEVEL

include "init.asm"

org OS_BASE + $

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
        mov     ax, [BOOT_VAR + BOOT_IDE_BASE_ADDR]
        mov     [IDEContrRegsBaseAddr], ax

        ; --------------- APM ---------------------

        ; init selectors
        mov     ebx, [BOOT_VAR + BOOT_APM_ENTRY_OFS] ; offset of APM entry point
        movzx   eax, [BOOT_VAR + BOOT_APM_CODE32_SEG] ; real-mode segment base address of protected-mode 32-bit code segment
        movzx   ecx, [BOOT_VAR + BOOT_APM_CODE16_SEG] ; real-mode segment base address of protected-mode 16-bit code segment
        movzx   edx, [BOOT_VAR + BOOT_APM_DATA16_SEG] ; real-mode segment base address of protected-mode 16-bit data segment

        shl     eax, 4
        mov     [apm_code_32 + 2], ax
        shr     eax, 16
        mov     [apm_code_32 + 4], al

        shl     ecx, 4
        mov     [apm_code_16 + 2], cx
        shr     ecx, 16
        mov     [apm_code_16 + 4], cl

        shl     edx, 4
        mov     [apm_data_16 + 2], dx
        shr     edx, 16
        mov     [apm_data_16 + 4], dl

        mov     dword[apm_entry], ebx
        mov     word[apm_entry + 4], apm_code_32 - gdts

        mov     eax, dword[BOOT_VAR + BOOT_APM_VERSION] ; version & flags
        mov     [apm_vf], eax

        ; -----------------------------------------

;       movzx   eax, [BOOT_VAR + BOOT_MOUSE_PORT] ; mouse port
;       mov     byte[0xf604], 1 ; al
        mov     al, [BOOT_VAR + BOOT_DMA] ; DMA access
        mov     [allow_dma_access], al
        movzx   eax, [BOOT_VAR + BOOT_BPP] ; bpp
        mov     [ScreenBPP], al

        mov     [_display.bpp], eax
        mov     [_display.vrefresh], 60
        mov     [_display.disable_mouse], __sys_disable_mouse

        movzx   eax, [BOOT_VAR + BOOT_X_RES] ; X max
        mov     [_display.box.width], eax
        dec     eax
        mov     [Screen_Max_X], eax
        mov     [screen_workarea.right], eax
        movzx   eax, [BOOT_VAR + BOOT_Y_RES] ; Y max
        mov     [_display.box.height], eax
        dec     eax
        mov     [Screen_Max_Y], eax
        mov     [screen_workarea.bottom], eax
        mov     ax, [BOOT_VAR + BOOT_VESA_MODE] ; screen mode
        mov     [SCR_MODE], ax
;       mov     eax, [BOOT_VAR + BOOT_BANK_SW]; Vesa 1.2 bnk sw add
;       mov     [BANK_SWITCH], eax
        mov     [BytesPerScanLine], 640 * 4 ; Bytes PerScanLine
        cmp     [SCR_MODE], 0x13 ; 320x200
        je      @f
        cmp     [SCR_MODE], 0x12 ; VGA 640x480
        je      @f
        movzx   eax, [BOOT_VAR + BOOT_SCANLINE] ; for other modes
        mov     [BytesPerScanLine], eax
        mov     [_display.pitch], eax

    @@: mov     eax, [_display.box.width]
        mul     [_display.box.height]
        mov     [_WinMapSize], eax

        mov     esi, BOOT_VAR + BOOT_BIOS_DISKS
        movzx   ecx, byte[esi - 1]
        mov     [NumBiosDisks], ecx
        mov     edi, BiosDisksData
        rep     movsd

        ; GRAPHICS ADDRESSES
        and     [BOOT_VAR + BOOT_DIRECT_LFB], 0
        mov     eax, [BOOT_VAR + BOOT_LFB]
        mov     [LFBAddress], eax

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
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.io_map], eax
        stdcall map_page, tss + 0x080, eax, PG_SW
        stdcall alloc_page
        inc     eax
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.io_map + 4], eax
        stdcall map_page, tss + 0x1080, eax, PG_SW

        ; LOAD IDT
        call    build_interrupt_table ; lidt is executed
        lidt    [idtreg]

        call    init_kernel_heap
        stdcall kernel_alloc, RING0_STACK_SIZE + 512
        mov     [os_stack_seg], eax

        lea     esp, [eax + RING0_STACK_SIZE]

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
        rep     stosd ; access to 4096*8=65536 ports

        mov     ax, tss0
        ltr     ax

        mov     [LFBSize], 0x00800000
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
        rep     stosd

        ; Set base of graphic segment to linear address of LFB
        mov     eax, [LFBAddress] ; set for gs
        mov     [graph_data_l + 2], ax
        shr     eax, 16
        mov     [graph_data_l + 4], al
        mov     [graph_data_l + 7], ah

        stdcall kernel_alloc, [_WinMapSize]
        mov     [_WinMapAddress], eax

        xor     eax, eax
        inc     eax
        mov     [CURRENT_TASK], eax ; 1
        mov     [TASK_COUNT], eax ; 1
        mov     dword[TASK_BASE], TASK_DATA
        mov     [current_slot], SLOT_BASE + sizeof.app_data_t

        ; set background
        mov     [BgrDrawMode], eax
        mov     [BgrDataWidth], eax
        mov     [BgrDataHeight], eax
        mov     [mem_BACKGROUND], 4
        mov     [img_background], static_background_data

        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.dir_table], sys_pgdir - OS_BASE

        stdcall kernel_alloc, 0x10000 / 8
        mov     edi, eax
        mov     [network_free_ports], eax
        or      eax, -1
        mov     ecx, 0x10000 / 32
        rep     stosd

        ; REDIRECT ALL IRQ'S TO INT'S 0x20-0x2f
        call    rerouteirqs

        ; Initialize system V86 machine
        call    init_sys_v86

        ; TIMER SET TO 1/100 S
        mov     al, 0x34 ; set to 100Hz
        out     0x43, al
        mov     al, 0x9b ; lsb 1193180 / 1193
        out     0x40, al
        mov     al, 0x2e ; msb
        out     0x40, al

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

include "detect/disks.inc"

        call    Parser_params

; READ RAMDISK IMAGE FROM HD
include "boot/rdload.asm"

;       mov     [dma_hdd], 1

        ; CALCULATE FAT CHAIN FOR RAMDISK
        mov     esi, RAMDISK + 512
        mov     edi, RAMDISK_FAT
        call    fs.fat12.calculate_fat_chain

; LOAD VMODE DRIVER
include "vmodeld.asm"

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

        ; LOAD FONTS I and II
        stdcall read_file, char, FONT_I, 0, 2304
        stdcall read_file, char2, FONT_II, 0, 2560

        mov     esi, boot_fonts
        call    boot_log

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

        ; BUILD SCHEDULER
        call    build_scheduler ; sys.inc

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
        mov     [SLOT_BASE + app_data_t.fpu_state], fpu_data
        mov     [SLOT_BASE + app_data_t.exc_handler], eax
        mov     [SLOT_BASE + app_data_t.except_mask], eax

        ; name for OS/IDLE process
        mov     dword[SLOT_BASE + sizeof.app_data_t + app_data_t.app_name], 'OS/I'
        mov     dword[SLOT_BASE + sizeof.app_data_t + app_data_t.app_name + 4], 'DLE '

        mov     edi, [os_stack_seg]
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.pl0_stack], edi
        add     edi, 0x2000 - 512
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.fpu_state], edi
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.saved_esp0], edi ; just in case
        ; [SLOT_BASE + sizeof.app_data_t + app_data_t.io_map] was set earlier

        mov     esi, fpu_data
        mov     ecx, 512 / 4
        cld
        rep     movsd

        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.exc_handler], eax
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.except_mask], eax

        mov     ebx, SLOT_BASE + sizeof.app_data_t + app_data_t.obj
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.obj.next_ptr], ebx
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.obj.prev_ptr], ebx

        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.cur_dir], sysdir_path
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.tls_base], eax

        ; task list
        mov     [TASK_DATA + task_data_t.mem_start], eax ; process base address
        inc     eax
        mov     [CURRENT_TASK], eax
        mov     [TASK_COUNT], eax
        mov     [current_slot], SLOT_BASE + sizeof.app_data_t
        mov     dword[TASK_BASE], TASK_DATA
        mov     [TASK_DATA + task_data_t.wnd_number], al ; on screen number
        mov     [TASK_DATA + task_data_t.pid], eax ; process id number

        call    init_display
        mov     eax, [def_cursor]
        mov     [SLOT_BASE + app_data_t.cursor], eax
        mov     [SLOT_BASE + sizeof.app_data_t + app_data_t.cursor], eax

        ; READ TSC / SECOND
        mov     esi, boot_tsc
        call    boot_log
        cli
;       call    _rdtsc
        rdtsc
        mov     ecx, eax
        mov     esi, 250 ; wait 1/4 a second
        call    delay_ms
;       call    _rdtsc
        rdtsc
        sti
        sub     eax, ecx
        shl     eax, 2
        mov     [CPU_FREQ], eax ; save tsc / sec

        ; actually, performance in this particular place is not critical, but just to shut optimizing HLL compiler
        ; fans up...
;       mov     ebx, 1000000
;       div     ebx
        mov     edx, 2251799814
        mul     edx
        shr     edx, 19
        mov     [stall_mcs], edx

        ; PRINT CPU FREQUENCY
        mov     esi, boot_cpufreq
        call    boot_log

        mov     ebx, edx
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

        mov     esi, boot_setmouse
        call    boot_log
        call    setmouse

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
        stdcall map_page, esi, [SLOT_BASE + sizeof.app_data_t + app_data_t.io_map], PG_MAP
        add     esi, 0x1000
        stdcall map_page, esi, [SLOT_BASE + sizeof.app_data_t + app_data_t.io_map + 4], PG_MAP

        stdcall map_page, tss.io_map_0, [SLOT_BASE + sizeof.app_data_t + app_data_t.io_map], PG_MAP
        stdcall map_page, tss.io_map_1, [SLOT_BASE + sizeof.app_data_t + app_data_t.io_map + 4], PG_MAP

        mov     ax, [OS_BASE + 0x10000 + bx_from_load]
        cmp     ax, 'r1' ; if not rused ram disk - load network configuration from files
        je      no_st_network
        call    set_network_conf

no_st_network:

        ; LOAD FIRST APPLICATION
        cli

        cmp     [BOOT_VAR + BOOT_VRR], 1
        jne     no_load_vrr_m

        mov     ebp, vrr_m
        call    fs_execute_from_sysdir

;       cmp     eax, 2 ; if vrr_m app found (PID = 2)
        sub     eax, 2
        jz      first_app_found

no_load_vrr_m:
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

;       mov     [TASK_COUNT], 2
        push    1
        pop     [CURRENT_TASK] ; set OS task fisrt

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

        ; clear +  enable fifo (64 bits)
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
        call    fdc_init

        jmp     osloop

;       jmp     $ ; wait here for timer to take control

        ; Fly :)

include "unpacker.asm"
include "include/fdo.inc"

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

if KCONFIG_BLKDEV_FLOPPY

        call    blkdev.floppy.ctl.process_events

end if ; KCONFIG_BLKDEV_FLOPPY

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
        mov     eax, [timer_ticks] ; eax = [timer_ticks]
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
        pop     eax

        ; RESERVE PORTS
        mov_s_  dword[RESERVED_PORTS], 4

        mov_s_  [RESERVED_PORTS + 16 + app_io_ports_range_t.pid], 1
        and     [RESERVED_PORTS + 16 + app_io_ports_range_t.start_port], 0
        mov_s_  [RESERVED_PORTS + 16 + app_io_ports_range_t.end_port], 0x2d

        mov_s_  [RESERVED_PORTS + 32 + app_io_ports_range_t.pid], 1
        mov_s_  [RESERVED_PORTS + 32 + app_io_ports_range_t.start_port], 0x30
        mov_s_  [RESERVED_PORTS + 32 + app_io_ports_range_t.end_port], 0x4d

        mov_s_  [RESERVED_PORTS + 48 + app_io_ports_range_t.pid], 1
        mov_s_  [RESERVED_PORTS + 48 + app_io_ports_range_t.start_port], 0x50
        mov_s_  [RESERVED_PORTS + 48 + app_io_ports_range_t.end_port], 0xdf

        mov_s_  [RESERVED_PORTS + 64 + app_io_ports_range_t.pid], 1
        mov_s_  [RESERVED_PORTS + 64 + app_io_ports_range_t.start_port], 0xe5
        mov_s_  [RESERVED_PORTS + 64 + app_io_ports_range_t.end_port], 0xff

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
        mov     ax, [BOOT_VAR + BOOT_Y_RES]
        shr     ax, 1
        shl     eax, 16
        mov     ax, [BOOT_VAR + BOOT_X_RES]
        shr     ax, 1
        mov     dword[MOUSE_X], eax

        xor     eax, eax
        mov     [BTN_ADDR], BUTTON_INFO ; address of button list

;       mov     [MOUSE_BUFF_COUNT], al ; mouse buffer
        mov     [KEY_COUNT], al ; keyboard buffer
        mov     [BTN_COUNT], al ; button buffer
;       mov     dword[MOUSE_X], 100 * 65536 + 100 ; mouse x/y

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

        mov     eax, [RESERVED_PORTS]
        test    eax, eax
        jnz     .sopl8
        inc     eax
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .sopl8:
        mov     edx, [TASK_BASE]
        mov     edx, [edx + task_data_t.pid]
;       and     ecx,65535
;       cld     ; set on interrupt 0x40

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
kproc sysfn.draw_number ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 47
;-----------------------------------------------------------------------------------------------------------------------
;> eax = pack[10(reserved), 6(number of digits to display), 8(number base), 8(number type)]
;>   al = 0 -> ebx is number
;>   al = 1 -> ebx is pointer
;>   ah = 0 -> display decimal
;>   ah = 1 -> display hexadecimal
;>   ah = 2 -> display binary
;> ebx = number or pointer
;> ecx = pack[16(x), 16(y)]
;> edx = color
;-----------------------------------------------------------------------------------------------------------------------
;# arguments are being shifted to match the description
;-----------------------------------------------------------------------------------------------------------------------
        ; It is not optimization
        mov     eax, ebx
        mov     ebx, ecx
        mov     ecx, edx
        mov     edx, esi
        mov     esi, edi

        xor     edi, edi

  .force:
        push    eax
        and     eax, 0x3fffffff
        cmp     eax, 0x0000ffff ; length > 0 ?
        pop     eax
        jge     .cont_displ
        ret

  .cont_displ:
        push    eax
        and     eax, 0x3fffffff
        cmp     eax, 61 shl 16 ; length <= 60 ?
        pop     eax
        jb      .cont_displ2
        ret

  .cont_displ2:
        pushad

        cmp     al, 1 ; ecx is a pointer ?
        jne     .displnl1
        mov     ebp, ebx
        add     ebp, 4
        mov     ebp, [ebp + std_application_base_address]
        mov     ebx, [ebx + std_application_base_address]

  .displnl1:
        sub     esp, 64

        test    ah, ah ; DECIMAL
        jnz     .no_display_desnum
        shr     eax, 16
        and     eax, 0xc03f
;       and     eax, 0x3f
        push    eax
        and     eax, 0x3f
        mov     edi, esp
        add     edi, 4 + 64 - 1
        mov     ecx, eax
        mov     eax, ebx
        mov     ebx, 10

  .d_desnum:
        xor     edx, edx
        call    division_64_bits
        div     ebx
        add     dl, 48
        mov     [edi], dl
        dec     edi
        loop    .d_desnum

        pop     eax
        call    normalize_number
        call    draw_num_text
        add     esp, 64
        popad
        ret

  .no_display_desnum:
        cmp     ah, 0x01 ; HEXADECIMAL
        jne     .no_display_hexnum
        shr     eax, 16
        and     eax, 0xc03f
;       and     eax, 0x3f
        push    eax
        and     eax, 0x3f
        mov     edi, esp
        add     edi, 4 + 64 - 1
        mov     ecx, eax
        mov     eax, ebx
        mov     ebx, 16

  .d_hexnum:
        xor     edx, edx
        call    division_64_bits
        div     ebx

hexletters = __fdo_hexdigits

        add     edx, hexletters
        mov     dl, [edx]
        mov     [edi], dl
        dec     edi
        loop    .d_hexnum

        pop     eax
        call    normalize_number
        call    draw_num_text
        add     esp, 64
        popad
        ret

  .no_display_hexnum:
        cmp     ah, 0x02 ; BINARY
        jne     .no_display_binnum
        shr     eax, 16
        and     eax, 0xc03f
;       and     eax, 0x3f
        push    eax
        and     eax, 0x3f
        mov     edi, esp
        add     edi, 4 + 64 - 1
        mov     ecx, eax
        mov     eax, ebx
        mov     ebx, 2

  .d_binnum:
        xor     edx, edx
        call    division_64_bits
        div     ebx
        add     dl, 48
        mov     [edi], dl
        dec     edi
        loop    .d_binnum

        pop     eax
        call    normalize_number
        call    draw_num_text
        add     esp, 64
        popad
        ret

  .no_display_binnum:
        add     esp, 64
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc normalize_number ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        test    ah, 0x080
        jz      .continue
        mov     ecx, 48
        and     eax, 0x3f

    @@: inc     edi
        cmp     [edi], cl
        jne     .continue
        dec     eax
        cmp     eax, 1
        ja      @b

        mov     al, 1

  .continue:
        and   eax, 0x3f
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc division_64_bits ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        test    byte[esp + 1 + 4], 0x40
        jz      .continue
        push    eax
        mov     eax, ebp
        div     ebx
        mov     ebp, eax
        pop     eax

  .continue:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc draw_num_text ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     esi, eax
        mov     edx, 64 + 4
        sub     edx, eax
        add     edx, esp
        mov     ebx, [esp + 64 + 32 - 8 + 4]

        ; add window start x & y
        mov     ecx, [TASK_BASE]

        mov     edi, [CURRENT_TASK]
        shl     edi, 8

        mov     eax, [ecx - twdw + window_data_t.box.left]
        add     eax, [SLOT_BASE + edi + app_data_t.wnd_clientbox.left]
        shl     eax, 16
        add     eax, [ecx - twdw + window_data_t.box.top]
        add     eax, [SLOT_BASE + edi + app_data_t.wnd_clientbox.top]
        add     ebx, eax
        mov     ecx, [esp + 64 + 32 - 12 + 4]
        and     ecx, not 0x80000000 ; force counted string
        mov     eax, [esp + 64 + 8] ; background color (if given)
        mov     edi, [esp + 64 + 4]
        jmp     dtext
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_config ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 21
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.set_config, subfn, sysfn.not_implemented, \
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
    video_ctl ; 13
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
        mov     edi, [TASK_BASE]
        mov     eax, [edi + task_data_t.mem_start]
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
;       call    set_FAT32_variables

  .noprmahd:
        cmp     ecx, 2
        jnz     .noprslhd

        mov     [hdbase], 0x1f0
        mov     [hdid], 0x10
        mov     [hdpos], ecx
;       call    set_FAT32_variables

  .noprslhd:
        cmp     ecx, 3
        jnz     .nosemahd

        mov     [hdbase], 0x170
        and     [hdid], 0
        mov     [hdpos], ecx
;       call    set_FAT32_variables

  .nosemahd:
        cmp     ecx, 4
        jnz     .noseslhd

        mov     [hdbase], 0x170
        mov     [hdid], 0x10
        mov     [hdpos], ecx
;       call    set_FAT32_variables

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
        mov     [fat32part], ecx
;       call    set_FAT32_variables
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

include "vmodeint.asm"

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.get_config, subfn, sysfn.not_implemented, \
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
        mov     edi, [TASK_BASE]
        mov     ebx, [edi + task_data_t.mem_start]
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
        mov     eax, [fat32part]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_config.tick_count ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 26.9
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [timer_ticks] ; [0xfdf0]
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
kproc get_timer_ticks ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [timer_ticks]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.mouse_ctl, subfn, sysfn.not_implemented, \
    get_screen_coordinates, \ ; 0
    get_window_coordinates, \ ; 1
    get_buttons_state, \ ; 2
    -, \ ; 3
    load_cursor, \ ; 4
    set_cursor, \ ; 5
    delete_cursor, \ ; 6
    get_scroll_info ; 7
endg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.get_screen_coordinates ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.0: get screen-relative cursor coordinates
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, dword[MOUSE_X]
        shl     eax, 16
        mov     ax, [MOUSE_Y]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.get_window_coordinates ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.1: get window-relative cursor coordinates
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, dword[MOUSE_X]
        shl     eax, 16
        mov     ax, [MOUSE_Y]
        mov     esi, [TASK_BASE]
        mov     bx, word[esi - twdw + window_data_t.box.left]
        shl     ebx, 16
        mov     bx, word[esi - twdw + window_data_t.box.top]
        sub     eax, ebx

        mov     edi, [CURRENT_TASK]
        shl     edi, 8
        sub     ax, word[SLOT_BASE + edi + app_data_t.wnd_clientbox.top]
        rol     eax, 16
        sub     ax, word[SLOT_BASE + edi + app_data_t.wnd_clientbox.left]
        rol     eax, 16
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.get_buttons_state ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.2: get mouse buttons state
;-----------------------------------------------------------------------------------------------------------------------
        movzx   eax, [BTN_DOWN]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.get_scroll_info ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.7: get mouse wheel changes from last query
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [TASK_COUNT]
        movzx   edi, [WIN_POS + edi * 2]
        cmp     edi, [CURRENT_TASK]
        jne     @f
        mov     ax, [MOUSE_SCROLL_H]
        shl     eax, 16
        mov     ax, [MOUSE_SCROLL_V]
        mov     [esp + 4 + regs_context32_t.eax], eax
        and     [MOUSE_SCROLL_H], 0
        and     [MOUSE_SCROLL_V], 0
        ret

    @@: and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.load_cursor ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.4: load cursor
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, OS_BASE
        jae     .exit

        stdcall load_cursor, ecx, edx
        mov     [esp + 4 + regs_context32_t.eax], eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.set_cursor ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.5: set cursor
;-----------------------------------------------------------------------------------------------------------------------
        stdcall set_cursor, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.mouse_ctl.delete_cursor ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 37.6: delete cursor
;-----------------------------------------------------------------------------------------------------------------------
        stdcall delete_cursor, ecx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc is_input ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        mov     dx, word[midisp]
        in      al, dx
        and     al, 0x80
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc is_output ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        mov     dx, word[midisp]
        in      al, dx
        and     al, 0x40
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_mpu_in ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        mov     dx, word[mididp]
        in      al, dx
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc put_mpu_out ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edx
        mov     dx, word[mididp]
        out     dx, al
        pop     edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.midi_ctl ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 20
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.midi_ctl, subfn, sysfn.not_implemented, \
    reset, \ ; 1
    output_byte ; 2
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        cmp     [mididp], 0
        je      .error

        jmp     [.subfn + ebx * 4]

  .error:
        mov     [esp + 4 + regs_context32_t.eax], 1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.midi_ctl.reset ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 20.1
;-----------------------------------------------------------------------------------------------------------------------
    @@: call    is_output
        test    al, al
        jnz     @b

        mov     dx, word[midisp]
        mov     al, 0xff
        out     dx, al

    @@: mov     dx, word[midisp]
        mov     al, 0xff
        out     dx, al
        call    is_input
        test    al, al
        jnz     @b
        call    get_mpu_in
        cmp     al, 0xfe
        jnz     @b

    @@: call    is_output
        test    al, al
        jnz     @b

        mov     dx, word[midisp]
        mov     al, 0x3f
        out     dx, al

        and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.midi_ctl.output_byte ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 20.2
;-----------------------------------------------------------------------------------------------------------------------
    @@: call    get_mpu_in
        call    is_output
        test    al, al
        jnz     @b

        mov     al, cl
        call    put_mpu_out

        and     [esp + 4 + regs_context32_t.eax], 0
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
        mov     ecx, [current_slot]
        mov     eax, [ecx + app_data_t.tls_base]
        test    eax, eax
        jz      @f

        stdcall user_free, eax

    @@: mov     eax, [TASK_BASE]
        mov     [eax + task_data_t.state], TSTATE_ZOMBIE ; terminate this program

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
  jump_table sysfn.system_ctl, subfn, sysfn.not_implemented, \
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
        mov     [BOOT_VAR + BOOT_VRR], cl

        mov     eax, [TASK_COUNT]
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
        jb      noprocessterminate
        mov     edx, [TASK_COUNT]
        cmp     ecx, edx
        ja      noprocessterminate
        mov     eax, [TASK_COUNT]
        shl     ecx, 5
        mov     edx, [TASK_DATA + ecx - sizeof.task_data_t + task_data_t.pid]
        add     ecx, TASK_DATA - sizeof.task_data_t + task_data_t.state
        cmp     byte[ecx], TSTATE_FREE
        jz      noprocessterminate

;       call    MEM_Heap_Lock ; guarantee that process isn't working with heap
        mov     byte[ecx], TSTATE_ZOMBIE ; clear possible i40's
;       call    MEM_Heap_UnLock

        cmp     edx, [application_table_status] ; clear app table stat
        jne     noatsc
        and     [application_table_status], 0

  noatsc:
  noprocessterminate:
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
        cmp     ecx, [TASK_COUNT]
        ja      .nowindowactivate

        mov     [window_minimize], 2 ; restore window if minimized

        movzx   esi, [WIN_STACK + ecx * 2]
        cmp     esi, [TASK_COUNT]
        je      .nowindowactivate ; already active

        mov     edi, ecx
        shl     edi, 5
        add     edi, window_data
        movzx   esi, [WIN_STACK + ecx * 2]
        lea     esi, [WIN_POS + esi * 2]
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
        mov     eax, [TASK_COUNT]
        movzx   eax, [WIN_POS + eax * 2]
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
        cld
        rep     movsb
        ret

  .full_table:
;       cmp     ecx, 2
        dec     ecx
        jnz     exit_for_anyone
        call    .for_all_tables
        mov     ecx, 16384
        cld
        rep     movsd
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
        rep     movsb
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
        mov     eax, [Screen_Max_X]
        shr     eax, 1
        mov     [MOUSE_X], ax
        mov     eax, [Screen_Max_Y]
        shr     eax, 1
        mov     [MOUSE_Y], ax
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
  jump_table sysfn.system_ctl.mouse_ctl, subfn, sysfn.not_implemented, \
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
        cmp     dx, word[Screen_Max_Y]
        ja      .exit

        rol     edx, 16
        cmp     dx, word[Screen_Max_X]
        ja      .exit

        mov     dword[MOUSE_X], edx

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
        cmp     eax, 255 ; varify maximal slot number
        ja      .error
        movzx   eax, [WIN_STACK + eax * 2]
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
kproc sysfn.flush_floppy_cache ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 16: save ramdisk to floppy
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ebx, 1
        jne     .no_floppy_a_save
        mov     [flp_number], 1
        jmp     .save_image_on_floppy

  .no_floppy_a_save:
        cmp     ebx, 2
        jne     .no_floppy_b_save
        mov     [flp_number], 2

  .save_image_on_floppy:
        call    save_image
        mov     [esp + 4 + regs_context32_t.eax],  0
        cmp     [FDC_Status], 0
        je      .yes_floppy_save

  .no_floppy_b_save:
        mov     [esp + 4 + regs_context32_t.eax], 1

  .yes_floppy_save:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_key ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 2
;-----------------------------------------------------------------------------------------------------------------------
        mov     [esp + 4 + regs_context32_t.eax], 1
        ; test main buffer
        mov     ebx, [CURRENT_TASK] ; TOP OF WINDOW STACK
        movzx   ecx, [WIN_STACK + ebx * 2]
        mov     edx, [TASK_COUNT]
        cmp     ecx, edx
        jne     .finish
        cmp     [KEY_COUNT], 0
        je      .finish
        movzx   eax, [KEY_BUFF]
        shl     eax, 8
        push    eax
        dec     [KEY_COUNT]
        and     [KEY_COUNT], 127
        movzx   ecx, [KEY_COUNT]
        add     ecx, 2
        mov     eax, KEY_BUFF + 1
        mov     ebx, KEY_BUFF
        call    memmove
        pop     eax

  .ret_eax:
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .finish:
        ; test hotkeys buffer
        mov     ecx, hotkey_buffer

    @@: cmp     [ecx], ebx
        jz      .found
        add     ecx, 8
        cmp     ecx, hotkey_buffer + 120 * 8
        jb      @b
        ret

  .found:
        mov     ax, [ecx + 6]
        shl     eax, 16
        mov     ah, [ecx + 4]
        mov     al, 2
        and     dword[ecx + 4], 0
        and     dword[ecx], 0
        jmp     .ret_eax
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_clicked_button_id ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 17: get clicked button identifier
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, [CURRENT_TASK] ; TOP OF WINDOW STACK
        mov     [esp + 4 + regs_context32_t.eax], 1
        movzx   ecx, [WIN_STACK + ebx * 2]
        mov     edx, [TASK_COUNT] ; less than 256 processes
        cmp     ecx, edx
        jne     .exit
        movzx   eax, [BTN_COUNT]
        test    eax, eax
        jz      .exit
        mov     eax, [BTN_BUFF]
        and     al, 0xfe ; delete left button bit
        mov     [BTN_COUNT], 0
        mov     [esp + 4 + regs_context32_t.eax], eax

  .exit:
        ret
kendp

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
        mov     ecx, [CURRENT_TASK]

  .no_who_am_i:
        cmp     ecx, max_processes
        ja      .nofillbuf

        ; +4: word: position of the window of thread in the window stack
        mov     ax, [WIN_STACK + ecx * 2]
        mov     [ebx + 4], ax
        ; +6: word: number of the thread slot, which window has in the window stack
        ;           position ecx (has no relation to the specific thread)
        mov     ax, [WIN_POS + ecx * 2]
        mov     [ebx + 6], ax

        shl     ecx, 5

        ; +0: dword: memory usage
        mov     eax, [TASK_DATA + ecx - sizeof.task_data_t + task_data_t.cpu_usage]
        mov     [ebx], eax
        ; +10: 11 bytes: name of the process
        push    ecx
        lea     eax, [SLOT_BASE + ecx * 8 + app_data_t.app_name]
        add     ebx, 10
        mov     ecx, 11
        call    memmove
        pop     ecx

        ; +22: address of the process in memory
        ; +26: size of used memory - 1
        push    edi
        lea     edi, [ebx + 12]
        xor     eax, eax
        mov     edx, 0x100000 * 16
        cmp     ecx, 1 shl 5
        je      .os_mem
        mov     edx, [SLOT_BASE + ecx * 8 + app_data_t.mem_size]
        mov     eax, std_application_base_address

  .os_mem:
        stosd
        lea     eax, [edx - 1]
        stosd

        ; +30: PID/TID
        mov     eax, [TASK_DATA + ecx - sizeof.task_data_t + task_data_t.pid]
        stosd

        ; window position and size
        push    esi
        lea     esi, [window_data + ecx + window_data_t.box]
        movsd
        movsd
        movsd
        movsd

        ; Process state (+50)
        movzx   eax, [TASK_DATA + ecx - sizeof.task_data_t + task_data_t.state]
        stosd

        ; Window client area box
        lea     esi, [SLOT_BASE + ecx * 8 + app_data_t.wnd_clientbox]
        movsd
        movsd
        movsd
        movsd

        ; Window state
        mov     al, [window_data + ecx + window_data_t.fl_wstate]
        stosb

        ; Event mask (+71)
        mov     eax, [TASK_DATA + ecx - sizeof.task_data_t + task_data_t.event_mask]
        stosd

        pop     esi
        pop     edi

  .nofillbuf:
        ; return number of processes
        mov     eax, [TASK_COUNT]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_time ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 3
;-----------------------------------------------------------------------------------------------------------------------
        cli

    @@: mov     al, 10
        out     0x70, al
        in      al, 0x71
        test    al, al
        jns     @f
        mov     esi, 1
        call    delay_ms
        jmp     @b

    @@: xor     al, al ; seconds
        out     0x70, al
        in      al, 0x71
        movzx   ecx, al
        mov     al, 2 ; minutes
        shl     ecx, 16
        out     0x70, al
        in      al, 0x71
        movzx   edx, al
        mov     al, 4 ; hours
        shl     edx, 8
        out     0x70, al
        in      al, 0x71
        add     ecx, edx
        movzx   edx, al
        add     ecx, edx
        sti
        mov     [esp + 4 + regs_context32_t.eax], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_date ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 29
;-----------------------------------------------------------------------------------------------------------------------
        cli

    @@: mov   al, 10
        out   0x70, al
        in    al, 0x71
        test  al, al
        jns   @f
        mov   esi, 1
        call  delay_ms
        jmp   @b

    @@: mov     ch, 0
        mov     al, 7 ; date
        out     0x70, al
        in      al, 0x71
        mov     cl, al
        mov     al, 8 ; month
        shl     ecx, 16
        out     0x70, al
        in      al, 0x71
        mov     ch, al
        mov     al, 9 ; year
        out     0x70, al
        in      al, 0x71
        mov     cl, al

        sti
        mov     [esp + 4 + regs_context32_t.eax], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_draw_state ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 12
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.set_draw_state, subfn, sysfn.not_implemented, \
    begin_drawing, \ ; 1
    end_drawing ; 2
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_draw_state.begin_drawing ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 12.1
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [CURRENT_TASK]

  .sys_newba2:
        mov     edi, [BTN_ADDR]
        cmp     dword[edi], 0 ; empty button list?
        je      .exit
        movzx   ebx, word[edi]
        inc     ebx
        mov     eax, edi

  .sys_newba:
        dec     ebx
        jz      .exit

        add     eax, 0x10
        cmp     cx, [eax]
        jnz     .sys_newba

        push    eax ebx ecx
        mov     ecx, ebx
        inc     ecx
        shl     ecx, 4
        mov     ebx, eax
        add     eax, 0x10
        call    memmove
        dec     dword[edi]
        pop     ecx ebx eax

        jmp     .sys_newba2

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_draw_state.end_drawing ;////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 12.2
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, [TASK_BASE]
        add     edx, draw_data - CURRENT_TASK
        mov     [edx + rect32_t.left], 0
        mov     [edx + rect32_t.top], 0
        mov     eax, [Screen_Max_X]
        mov     [edx + rect32_t.right], eax
        mov     eax, [Screen_Max_Y]
        mov     [edx + rect32_t.bottom], eax
        ret
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
        or      eax, 01100000000000000000000000000000b
        mov     cr0, eax
        wbinvd  ; set MESI
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cache_enable ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, cr0
        and     eax, 010011111111111111111111111111111b
        mov     cr0, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc is_cache_enabled ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, cr0
        mov     ebx, eax
        and     eax, 01100000000000000000000000000000b
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
        bts     eax, 8 ; pce=cr4[8]
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
        mov     ecx, [TASK_COUNT]

  .set_mouse_event:
        add     edi, sizeof.app_data_t
        or      [SLOT_BASE + edi + app_data_t.event_mask], 0100000b
        loop    .set_mouse_event

  .mouse_not_active:
        cmp     [BACKGROUND_CHANGED], 0
        jz      .no_set_bgr_event
        xor     edi, edi
        mov     ecx, [TASK_COUNT]

  .set_bgr_event:
        add     edi, sizeof.app_data_t
        or      [SLOT_BASE + edi + app_data_t.event_mask], 16
        loop    .set_bgr_event
        mov     [BACKGROUND_CHANGED], 0

  .no_set_bgr_event:
        cmp     [REDRAW_BACKGROUND], 0 ; background update?
        jz      .nobackgr
        cmp     [background_defined], 0
        jz      .nobackgr
;       mov     [draw_data + sizeof.rect32_t + rect32_t.left], 0
;       mov     [draw_data + sizeof.rect32_t + rect32_t.top], 0
;       mov     eax, [Screen_Max_X]
;       mov     ebx, [Screen_Max_Y]
;       mov     [draw_data + sizeof.rect32_t + rect32_t.right], eax
;       mov     [draw_data + sizeof.rect32_t + rect32_t.bottom], ebx

    @@: call    drawbackground
        xor     eax, eax
        xchg    al, [REDRAW_BACKGROUND]
        test    al, al ; got new update request?
        jnz     @b
        mov     [draw_data + 2 * sizeof.rect32_t + rect32_t.left], eax
        mov     [draw_data + 2 * sizeof.rect32_t + rect32_t.top], eax
        mov     [draw_data + 2 * sizeof.rect32_t + rect32_t.right], eax
        mov     [draw_data + 2 * sizeof.rect32_t + rect32_t.bottom], eax
;       mov     [MOUSE_BACKGROUND], 0

  .nobackgr:
        ; system shutdown request
        cmp     [SYS_SHUTDOWN], 0
        je      .noshutdown

        mov     edx, [shutdown_processes]

        cmp     [SYS_SHUTDOWN], dl
        jne     .no_mark_system_shutdown

        lea     ecx, [edx - 1]
        mov     edx, OS_BASE + 0x3040
        jecxz   @f

  .markz:
        mov     byte[edx + task_data_t.state], TSTATE_ZOMBIE
        add     edx, sizeof.task_data_t
        loop    .markz

  .no_mark_system_shutdown:
    @@: call    [_display.disable_mouse]

        dec     [SYS_SHUTDOWN]
        je      system_shutdown

  .noshutdown:
        ; termination
        mov     eax, [TASK_COUNT]
        mov     ebx, TASK_DATA + task_data_t.state
        mov     esi, 1

  .newct:
        mov     cl, [ebx]
        cmp     cl, TSTATE_ZOMBIE
        jz      terminate
        cmp     cl, TSTATE_TERMINATING
        jz      terminate

        add     ebx, sizeof.task_data_t
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
        shl     eax, 5
        add     eax, window_data

        cmp     eax, [esp + 4]
        je      .not_this_task

        ; check if window in redraw area
        mov     edi, eax

        cmp     ecx, 1 ; limit for background
        jz      .bgli

        mov     eax, [edi + window_data_t.box.left]
        mov     ebx, [edi + window_data_t.box.top]
        mov     ecx, [edi + window_data_t.box.width]
        mov     edx, [edi + window_data_t.box.height]
        add     ecx, eax
        add     edx, ebx

        mov     ecx, [draw_limits.bottom] ; ecx = area y end, ebx == window y start
        cmp     ecx, ebx
        jb      .ricino

        mov     ecx, [draw_limits.right] ; ecx = area x end, eax == window x start
        cmp     ecx, eax
        jb      .ricino

        mov     eax, [edi + window_data_t.box.left]
        mov     ebx, [edi + window_data_t.box.top]
        mov     ecx, [edi + window_data_t.box.width]
        mov     edx, [edi + window_data_t.box.height]
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
        lea     eax, [edi + draw_data - window_data]
        mov     ebx, [draw_limits.left]
        cmp     ebx, [eax + rect32_t.left]
        jae     @f
        mov     [eax + rect32_t.left], ebx
        mov     dl, 1

    @@: mov     ebx, [draw_limits.top]
        cmp     ebx, [eax + rect32_t.top]
        jae     @f
        mov     [eax + rect32_t.top], ebx
        mov     dl, 1

    @@: mov     ebx, [draw_limits.right]
        cmp     ebx, [eax + rect32_t.right]
        jbe     @f
        mov     [eax + rect32_t.right], ebx
        mov     dl, 1

    @@: mov     ebx, [draw_limits.bottom]
        cmp     ebx, [eax + rect32_t.bottom]
        jbe     @f
        mov     [eax + rect32_t.bottom], ebx
        mov     dl, 1

    @@: add     [REDRAW_BACKGROUND], dl
        jmp     .newdw8

  .az:
        mov     eax, edi
        add     eax, draw_data - window_data

        ; set limits
        mov     ebx, [draw_limits.left]
        mov     [eax + rect32_t.left], ebx
        mov     ebx, [draw_limits.top]
        mov     [eax + rect32_t.top], ebx
        mov     ebx, [draw_limits.right]
        mov     [eax + rect32_t.right], ebx
        mov     ebx, [draw_limits.bottom]
        mov     [eax + rect32_t.bottom], ebx

        sub     eax, draw_data - window_data

        cmp     dword[esp], 1
        jne     .nobgrd
        inc     [REDRAW_BACKGROUND]

  .newdw8:
  .nobgrd:
        mov     [eax + window_data_t.fl_redraw], 1 ; mark as redraw

  .ricino:
  .not_this_task:
        pop     ecx

        cmp     ecx, [TASK_COUNT]
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
        cld

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
        mov     edi, [TASK_BASE]
        mov     eax, [edi + task_data_t.event_mask]
        mov     [edi + task_data_t.event_mask], ebx
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
        push    ecx
        push    edx

        mov     edx, [timer_ticks]

  .newtic:
        mov     ecx, [timer_ticks]
        sub     ecx, edx
        cmp     ecx, ebx
        jae     .zerodelay

        call    change_task

        jmp     .newtic

  .zerodelay:
        pop     edx
        pop     ecx

        ret
kendp

align 16 ; very often call this subrutine
;-----------------------------------------------------------------------------------------------------------------------
kproc memmove ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? memory move in bytes
;-----------------------------------------------------------------------------------------------------------------------
;> eax = from
;> ebx = to
;> ecx = no of bytes
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
        jle     .ret

        push    esi edi ecx

        mov     edi, ebx
        mov     esi, eax

        test    ecx, not 011b
        jz      @f

        push    ecx
        shr     ecx, 2
        rep     movsd
        pop     ecx
        and     ecx, 011b
        jz      .finish

    @@: rep     movsb

  .finish:
        pop     ecx edi esi

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.program_irq ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 44
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [TASK_BASE]
        add     ebx, [eax + task_data_t.mem_start]

        cmp     ecx, 16
        jae     .not_owner
        mov     edi, [eax + task_data_t.pid]
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

        cld
        rep     movsd

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

        mov     eax, [TASK_BASE]

        cmp     edx, [eax + task_data_t.pid]
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
        cld
        cmp     esi, ecx ; if greater than the buffer size, begin cycle again
        jbe     @f

        sub     ecx, ebx
        sub     edx, ecx

        lea     esi, [eax + ebx + 0x10]
        rep     movsb

        xor     ebx, ebx

    @@: lea     esi, [eax + ebx + 0x10]
        mov     ecx, edx
        add     ebx, edx

        rep     movsb
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
        mov     eax, [RESERVED_PORTS]
        test    eax, eax ; no reserved areas ?
        je      .rpal2
        cmp     eax, 255 ; max reserved
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

        mov     eax, [RESERVED_PORTS]
        add     eax, 1
        mov     [RESERVED_PORTS], eax
        shl     eax, 4
        add     eax, RESERVED_PORTS
        mov     ebx, [TASK_BASE]
        mov     ebx, [ebx + task_data_t.pid]
        mov     [eax + app_io_ports_range_t.pid], ebx
        mov     [eax + app_io_ports_range_t.start_port], ecx
        mov     [eax + app_io_ports_range_t.end_port], edx

        xor     eax, eax
        ret

  .free_port_area:
;       pushad
        mov     eax, [RESERVED_PORTS] ; no reserved areas?
        test    eax, eax
        jz      .frpal2
        mov     ebx, [TASK_BASE]
        mov     ebx, [ebx + task_data_t.pid]

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
        cld
        rep     movsb

        dec     dword[RESERVED_PORTS]
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
        mov     eax, [TASK_BASE]
        mov     edi, [eax + task_data_t.pid]
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
kproc sysfn.put_image ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 7
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, 0x80008000
        jnz     .exit
        test    ecx, 0x0000ffff
        jz      .exit
        test    ecx, 0xffff0000
        jnz     @f

  .exit:
        ret

    @@: mov     edi, [current_slot]
        add     dx, word[edi + app_data_t.wnd_clientbox.top]
        rol     edx, 16
        add     dx, word[edi + app_data_t.wnd_clientbox.left]
        rol     edx, 16

  .forced:
        push    ebp esi 0
        mov     ebp, putimage_get24bpp
        mov     esi, putimage_init24bpp
kendp

kproc sys_putimage_bpp
;       call    [disable_mouse] ; this will be done in xxx_putimage
;       mov     eax, vga_putimage
        cmp     [SCR_MODE], 0x12
        jz      @f
        mov     eax, vesa12_putimage
        cmp     [SCR_MODE], 0100000000000000b
        jae     @f
        cmp     [SCR_MODE], 0x13
        jnz     .doit

    @@: mov     eax, vesa20_putimage

  .doit:
        inc     [mouse_pause]
        call    eax
        dec     [mouse_pause]
        pop     ebp esi ebp
        jmp     [draw_pointer]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.put_image_with_palette ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 65
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to image
;> ecx = pack[16(xsize), 16(ysize)]
;> edx = pack[16(xstart), 16(ystart)]
;> esi = number of bits per pixel, must be 8, 24 or 32
;> edi = pointer to palette
;> ebp = row delta
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [CURRENT_TASK]
        shl     eax, 8
        add     dx, word[SLOT_BASE + eax + app_data_t.wnd_clientbox.top]
        rol     edx, 16
        add     dx, word[SLOT_BASE + eax + app_data_t.wnd_clientbox.left]
        rol     edx, 16

  .forced:
        cmp     esi, 1
        jnz     @f
        push    edi
        mov     eax, [edi + 4]
        sub     eax, [edi]
        push    eax
        push    dword[edi]
        push    0xffffff80
        mov     edi, esp
        call    .put_mono_image
        add     esp, 12
        pop     edi
        ret

    @@: cmp     esi, 2
        jnz     @f
        push    edi
        push    0xffffff80
        mov     edi, esp
        call    .put_2bit_image
        pop     eax
        pop     edi
        ret

    @@: cmp     esi, 4
        jnz     @f
        push    edi
        push    0xffffff80
        mov     edi, esp
        call    .put_4bit_image
        pop     eax
        pop     edi
        ret

    @@: push    ebp esi ebp
        cmp     esi, 8
        jnz     @f
        mov     ebp, putimage_get8bpp
        mov     esi, putimage_init8bpp
        jmp     sys_putimage_bpp

    @@: cmp     esi, 15
        jnz     @f
        mov     ebp, putimage_get15bpp
        mov     esi, putimage_init15bpp
        jmp     sys_putimage_bpp

    @@: cmp     esi, 16
        jnz     @f
        mov     ebp, putimage_get16bpp
        mov     esi, putimage_init16bpp
        jmp     sys_putimage_bpp

    @@: cmp     esi, 24
        jnz     @f
        mov     ebp, putimage_get24bpp
        mov     esi, putimage_init24bpp
        jmp     sys_putimage_bpp

    @@: cmp     esi, 32
        jnz     @f
        mov     ebp, putimage_get32bpp
        mov     esi, putimage_init32bpp
        jmp     sys_putimage_bpp

    @@: pop     ebp esi ebp
        ret

  .put_mono_image:
        push    ebp esi ebp
        mov     ebp, putimage_get1bpp
        mov     esi, putimage_init1bpp
        jmp     sys_putimage_bpp

  .put_2bit_image:
        push    ebp esi ebp
        mov     ebp, putimage_get2bpp
        mov     esi, putimage_init2bpp
        jmp     sys_putimage_bpp

  .put_4bit_image:
        push    ebp esi ebp
        mov     ebp, putimage_get4bpp
        mov     esi, putimage_init4bpp
        jmp     sys_putimage_bpp
kendp

kproc putimage_init24bpp
        lea     eax, [eax * 3]
kendp

kproc putimage_init8bpp
        ret
kendp

align 16
kproc putimage_get24bpp
        movzx   eax, byte[esi + 2]
        shl     eax, 16
        mov     ax, [esi]
        add     esi, 3
        ret     4
kendp

align 16
kproc putimage_get8bpp
        movzx   eax, byte[esi]
        push    edx
        mov     edx, [esp + 8]
        mov     eax, [edx + eax * 4]
        pop     edx
        inc     esi
        ret     4
kendp

kproc putimage_init1bpp
        add     eax, ecx
        push    ecx
        add     eax, 7
        add     ecx, 7
        shr     eax, 3
        shr     ecx, 3
        sub     eax, ecx
        pop     ecx
        ret
kendp

align 16
kproc putimage_get1bpp
        push    edx
        mov     edx, [esp + 8]
        mov     al, [edx]
        add     al, al
        jnz     @f
        lodsb
        adc     al, al

    @@: mov     [edx], al
        sbb     eax, eax
        and     eax, [edx + 8]
        add     eax, [edx + 4]
        pop     edx
        ret     4
kendp

kproc putimage_init2bpp
        add     eax, ecx
        push    ecx
        add     ecx, 3
        add     eax, 3
        shr     ecx, 2
        shr     eax, 2
        sub     eax, ecx
        pop     ecx
        ret
kendp

align 16
kproc putimage_get2bpp
        push    edx
        mov     edx, [esp + 8]
        mov     al, [edx]
        mov     ah, al
        shr     al, 6
        shl     ah, 2
        jnz     .nonewbyte
        lodsb
        mov     ah, al
        shr     al, 6
        shl     ah, 2
        add     ah, 1

  .nonewbyte:
        mov     [edx], ah
        mov     edx, [edx + 4]
        movzx   eax, al
        mov     eax, [edx + eax * 4]
        pop     edx
        ret     4
kendp

kproc putimage_init4bpp
        add     eax, ecx
        push    ecx
        add     ecx, 1
        add     eax, 1
        shr     ecx, 1
        shr     eax, 1
        sub     eax, ecx
        pop     ecx
        ret
kendp

align 16
kproc putimage_get4bpp
        push    edx
        mov     edx, [esp + 8]
        add     byte[edx], 0x80
        jc      @f
        movzx   eax, byte[edx + 1]
        mov     edx, [edx + 4]
        and     eax, 0x0f
        mov     eax, [edx + eax * 4]
        pop     edx
        ret     4

    @@: movzx   eax, byte[esi]
        add     esi, 1
        mov     [edx + 1], al
        shr     eax, 4
        mov     edx, [edx + 4]
        mov     eax, [edx + eax * 4]
        pop     edx
        ret     4
kendp

kproc putimage_init32bpp
        shl     eax, 2
        ret
kendp

align 16
kproc putimage_get32bpp
        lodsd
        ret     4
kendp

kproc putimage_init15bpp
kendp

kproc putimage_init16bpp
        add     eax, eax
        ret
kendp

align 16
kproc putimage_get15bpp
; 0RRRRRGGGGGBBBBB -> 00000000RRRRR000GGGGG000BBBBB000
        push    ecx edx
        movzx   eax, word[esi]
        add     esi, 2
        mov     ecx, eax
        mov     edx, eax
        and     eax, 0x1f
        and     ecx, 0x1f shl 5
        and     edx, 0x1f shl 10
        shl     eax, 3
        shl     ecx, 6
        shl     edx, 9
        or      eax, ecx
        or      eax, edx
        pop     edx ecx
        ret     4
kendp

align 16
kproc putimage_get16bpp
; RRRRRGGGGGGBBBBB -> 00000000RRRRR000GGGGGG00BBBBB000
        push    ecx edx
        movzx   eax, word[esi]
        add     esi, 2
        mov     ecx, eax
        mov     edx, eax
        and     eax, 0x1f
        and     ecx, 0x3f shl 5
        and     edx, 0x1f shl 11
        shl     eax, 3
        shl     ecx, 5
        shl     edx, 8
        or      eax, ecx
        or      eax, edx
        pop     edx ecx
        ret     4
kendp

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

;-----------------------------------------------------------------------------------------------------------------------
kproc kb_read ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .kr_loop:
        in      al, 0x64
        test    al, 1
        jnz     .kr_ready
        loop    .kr_loop
        mov     ah, 1
        jmp     .kr_exit

  .kr_ready:
        push    ecx
        mov     ecx, 32

  .kr_delay:
        loop    .kr_delay
        pop     ecx
        in      al, 0x60
        xor     ah, ah

  .kr_exit:
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc kb_write ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx

        mov     dl, al
;       mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's
;
; .kw_loop1:
;       in      al, 0x64
;       test    al, 0x20
;       jz      .kw_ok1
;       loop    .kw_loop1
;       mov     ah, 1
;       jmp     .kw_exit
;
; .kw_ok1:
        in      al, 0x60
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .kw_loop:
        in      al, 0x64
        test    al, 2
        jz      .kw_ok
        loop    .kw_loop
        mov     ah, 1
        jmp     .kw_exit

  .kw_ok:
        mov     al, dl
        out     0x60, al
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .kw_loop3:
        in      al, 0x64
        test    al, 2
        jz      .kw_ok3
        loop    .kw_loop3
        mov     ah, 1
        jmp     .kw_exit

  .kw_ok3:
        mov     ah, 8

  .kw_loop4:
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .kw_loop5:
        in      al, 0x64
        test    al, 1
        jnz     .kw_ok4
        loop    .kw_loop5
        dec     ah
        jnz     .kw_loop4

  .kw_ok4:
        xor     ah, ah

  .kw_exit:
        pop     edx ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc kb_cmd ;//////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .c_wait:
        in      al, 0x64
        test    al, 2
        jz      .c_send
        loop    .c_wait
        jmp     .c_error

  .c_send:
        mov     al, bl
        out     0x64, al
        mov     ecx, 0x1ffff ; last 0xffff, new value in view of fast CPU's

  .c_accept:
        in      al, 0x64
        test    al, 2
        jz      .c_ok
        loop    .c_accept

  .c_error:
        mov     ah, 1
        jmp     .c_exit

  .c_ok:
        xor     ah, ah

  .c_exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc setmouse ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? set mousepicture -pointer
;-----------------------------------------------------------------------------------------------------------------------
        ; ps2 mouse enable
        mov     [MOUSE_PICTURE], mousepointer
        cli
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

        mov     al, 255 ; mask all irq's
        out     0xa1, al
        call    .pic_delay
        out     0x21, al
        call    .pic_delay

        mov     ecx, 0x1000
        cld

  .picl1:
        call    .pic_delay
        loop    .picl1

        mov     al, 255 ; mask all irq's
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
  jump_table sysfn.debug_board, subfn, sysfn.not_implemented_cross_order, \
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
kproc sysfn.keyboard_ctl ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.keyboard_ctl, subfn, sysfn.not_implemented, \
    set_input_mode, \ ; 1
    get_input_mode, \ ; 2
    get_modifiers_state, \ ; 3
    register_hotkey, \ ; 4
    unregister_hotkey ; 5
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        mov     edi, [CURRENT_TASK]
        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.set_input_mode ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.1: set keyboard mode
;-----------------------------------------------------------------------------------------------------------------------
        shl     edi, 8
        mov     [SLOT_BASE + edi + app_data_t.keyboard_mode], cl
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.get_input_mode ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.2: get keyboard mode
;-----------------------------------------------------------------------------------------------------------------------
        shl     edi, 8
        movzx   eax, [SLOT_BASE + edi + app_data_t.keyboard_mode]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.get_modifiers_state ;//////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.3: get keyboard ctrl, alt, shift
;-----------------------------------------------------------------------------------------------------------------------
;       xor     eax, eax
;       movzx   eax, byte[shift]
;       movzx   ebx, byte[ctrl]
;       shl     ebx, 2
;       add     eax, ebx
;       movzx   ebx, byte[alt]
;       shl     ebx, 3
;       add     eax, ebx
        mov     eax, [kb_state]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.register_hotkey ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.4
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, hotkey_list

    @@: cmp     dword[eax + 8], 0
        jz      .found_free
        add     eax, 16
        cmp     eax, hotkey_list + 16 * 256
        jb      @b
        mov     [esp + 4 + regs_context32_t.eax], 1
        ret

  .found_free:
        mov     [eax + 8], edi
        mov     [eax + 4], edx
        movzx   ecx, cl
        lea     ecx, [hotkey_scancodes + ecx * 4]
        mov     edx, [ecx]
        mov     [eax], edx
        mov     [ecx], eax
        mov     [eax + 12], ecx
        jecxz   @f
        mov     [edx + 12], eax

    @@: and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.keyboard_ctl.unregister_hotkey ;////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 66.5
;-----------------------------------------------------------------------------------------------------------------------
        movzx   ebx, cl
        lea     ebx, [hotkey_scancodes + ebx * 4]
        mov     eax, [ebx]

  .scan:
        test    eax, eax
        jz      .notfound
        cmp     [eax + 8], edi
        jnz     .next
        cmp     [eax + 4], edx
        jz      .found

  .next:
        mov     eax, [eax]
        jmp     .scan

  .notfound:
        mov     [esp + 4 + regs_context32_t.eax], 1
        ret

  .found:
        mov     ecx, [eax]
        jecxz   @f
        mov     edx, [eax + 12]
        mov     [ecx + 12], edx

    @@: mov     ecx, [eax + 12]
        mov     edx, [eax]
        mov     [ecx], edx
        xor     edx, edx
        mov     [eax + 4], edx
        mov     [eax + 8], edx
        mov     [eax + 12], edx
        mov     [eax], edx
        mov     [esp + 4 + regs_context32_t.eax], edx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfs.direct_screen_access ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 61: direct screen access
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfs.direct_screen_access, subfn, sysfn.not_implemented, \
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
        mov     eax, [Screen_Max_X]
        shl     eax, 16
        mov     ax, word[Screen_Max_Y]
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
        mov     edx, [TASK_BASE]
        add     eax, [edx - twdw + window_data_t.box.left]
        add     ebx, [edx - twdw + window_data_t.box.top]
        mov     edi, [current_slot]
        add     eax, [edi + app_data_t.wnd_clientbox.left]
        add     ebx, [edi + app_data_t.wnd_clientbox.top]
        xor     edi, edi ; no force
;       mov     edi, 1
        call    [_display.disable_mouse]
        jmp     [putpixel]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.draw_text ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 4
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [TASK_BASE]
        mov     ebp, [eax - twdw + window_data_t.box.left]
        push    esi
        mov     esi, [current_slot]
        add     ebp, [esi + app_data_t.wnd_clientbox.left]
        shl     ebp, 16
        add     ebp, [eax - twdw + window_data_t.box.top]
        add     bp, word[esi + app_data_t.wnd_clientbox.top]
        pop     esi
        add     ebx, ebp
        mov     eax, edi
        xor     edi, edi
        jmp     dtext
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.read_rd_file ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 6
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, ebx
        mov     ebx, ecx
        mov     ecx, edx
        mov     edx, esi
        mov     esi, 12
        call    fileread
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
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
        mov     esi, [current_slot]

        add     eax, [esi + app_data_t.wnd_clientbox.left]
        add     ebx, [esi + app_data_t.wnd_clientbox.top]
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
        mov     ax, word[Screen_Max_X]
        shl     eax, 16
        mov     ax, word[Screen_Max_Y]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.cd_audio_ctl, subfn, sysfn.not_implemented, \
    play, \ ; 1
    get_tracks_info, \ ; 2
    stop, \ ; 3
    eject_tray, \ ; 4
    load_tray ; 5
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]

;-----------------------------------------------------------------------------------------------------------------------
  ._.reserve: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_cd
        mov     eax, ecx
        shr     eax, 1
        and     eax, 1
        mov     [ChannelNumber], ax
        mov     eax, ecx
        and     eax, 1
        mov     [DiskNumber], al
        call    reserve_cd_channel
        and     ebx, 3
        inc     ebx
        mov     [cdpos], ebx
        add     ebx, ebx
        mov     cl, 8
        sub     cl, bl
        mov     al, [DRIVE_DATA + 1]
        shr     al, cl
        test    al, 2
        jz      ._.free
        ret

;-----------------------------------------------------------------------------------------------------------------------
  ._.free: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        call    free_cd_channel
        and     [cd_status], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.load_tray ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.5
;-----------------------------------------------------------------------------------------------------------------------
        call    sysfn.cd_audio_ctl._.reserve
        call    LoadMedium
        jmp     sysfn.cd_audio_ctl._.free
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.eject_tray ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.4
;-----------------------------------------------------------------------------------------------------------------------
        call    sysfn.cd_audio_ctl._.reserve
        call    clear_CD_cache
        call    allow_medium_removal
        call    EjectMedium
        jmp     sysfn.cd_audio_ctl._.free
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.play ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.1: start playing audio CD
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = start position, 0x00FFSSMM
;-----------------------------------------------------------------------------------------------------------------------
        call    sys_cdplay
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.get_tracks_info ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.2: get CD audio tracks information
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= buffer
;> ecx #= buffer size
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [TASK_BASE]
        add     edi, task_data_t.mem_start
        add     ebx, [edi]
        call    sys_cdtracklist
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.cd_audio_ctl.stop ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 24.3: stop/pause playing audio CD
;-----------------------------------------------------------------------------------------------------------------------
        call    sys_cdpause
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_pixel ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 35
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [Screen_Max_X]
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
        mov     edi, [TASK_BASE]
        movzx   eax, word[edi - twdw + window_data_t.box.left]
        mov     ebp, eax
        mov     esi, [current_slot]
        add     ebp, [esi + app_data_t.wnd_clientbox.left]
        add     ax, word[esi + app_data_t.wnd_clientbox.left]
        add     ebp, ebx
        shl     eax, 16
        movzx   ebx, word[edi - twdw + window_data_t.box.top]
        add     eax, ebp
        mov     ebp, ebx
        add     ebp, [esi + app_data_t.wnd_clientbox.top]
        add     bx, word[esi + app_data_t.wnd_clientbox.top]
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
kproc sysfn.thread_ctl ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 51
;-----------------------------------------------------------------------------------------------------------------------
;> eax = 1 - create thread
;>   ebx = thread start
;>   ecx = thread stack value
;-----------------------------------------------------------------------------------------------------------------------
;< eax = pid
;-----------------------------------------------------------------------------------------------------------------------
        call    new_sys_threads
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_network_driver_status ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 52
;-----------------------------------------------------------------------------------------------------------------------
        call    app_stack_handler ; Stack status

        ; enable these for zero delay between sent packet
;       mov     [check_idle_semaphore], 5
;       call    change_task

        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.socket ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 53
;-----------------------------------------------------------------------------------------------------------------------
        call    app_socket_handler

        ; enable these for zero delay between sent packet
;       mov     [check_idle_semaphore], 5
;       call    change_task

        mov     [esp + 8 + regs_context32_t.eax], eax
        mov     [esp + 8 + regs_context32_t.ebx], ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc set_screen ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, [Screen_Max_X]
        jne     .set

        cmp     edx, [Screen_Max_Y]
        jne     .set
        ret

  .set:
        pushfd
        cli

        mov     [Screen_Max_X], eax
        mov     [Screen_Max_Y], edx
        mov     [BytesPerScanLine], ecx

        mov     [screen_workarea.right], eax
        mov     [screen_workarea.bottom], edx

        push    ebx
        push    esi
        push    edi

        pushad

        stdcall kernel_free, [_WinMapAddress]

        mov     eax, [_display.box.width]
        mul     [_display.box.height]
        mov     [_WinMapSize], eax

        stdcall kernel_alloc, eax
        mov     [_WinMapAddress], eax
        test    eax, eax
        jz      .epic_fail

        popad

        call    repos_windows
        xor     eax, eax
        xor     ebx, ebx
        mov     ecx, [Screen_Max_X]
        mov     edx, [Screen_Max_Y]
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
        cmp     [BOOT_VAR + BOOT_VRR], 1
        jne     @f
        ret

    @@: call    stop_all_services
        call    sys_cdpause ; stop playing cd

; .yes_shutdown_param:
        cli

        mov     eax, kernel_file ; load kernel.mnt to 0x7000:0
        push    12
        pop     esi
        xor     ebx, ebx
        or      ecx, -1
        mov     edx, OS_BASE + 0x70000
        call    fileread

        mov     esi, restart_kernel_4000 + OS_BASE + 0x10000 ; move kernel re-starter to 0x4000:0
        mov     edi, OS_BASE + 0x40000
        mov     ecx, 1000
        rep     movsb

        mov     esi, BOOT_VAR ; restore 0x0 - 0xffff
        mov     edi, OS_BASE
        mov     ecx, 0x10000 / 4
        cld
        rep     movsd

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

        cmp     [OS_BASE + BOOT_VRR], 1
        je      no_acpi_power_off

        ; scan for RSDP
        ; 1) The first 1 Kb of the Extended BIOS Data Area (EBDA).
        movzx   eax, word[OS_BASE + 0x40e]
        shl     eax, 4
        jz      @f
        mov     ecx, 1024 / 16
        call    scan_rsdp
        jnc     .rsdp_found

    @@: ; 2) The BIOS read-only memory space between 0E0000h and 0FFFFFh.
        mov     eax, 0xe0000
        mov     ecx, 0x2000
        call    scan_rsdp
        jc      no_acpi_power_off

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
        jnz     no_acpi_power_off
        mov     ecx, [esi + 4]
        sub     ecx, 0x24
        jbe     no_acpi_power_off
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
        jmp     no_acpi_power_off

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
        jnz     no_acpi_power_off
        mov     eax, [esi + ebp + 0x4004] ; DSDT length
        sub     eax, 36 + 4
        jbe     no_acpi_power_off
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
        jnz     no_acpi_power_off
        inc     esi
        mov     cl, [esi]

    @@: inc     esi
        cmp     dl, 2
        jb      @f
        cmp     byte[esi], 0
        jz      @f
        cmp     byte[esi], 0x0a
        jnz     no_acpi_power_off
        inc     esi
        mov     ch, [esi]

    @@: jmp     do_acpi_power_off

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
        jmp     no_acpi_power_off

do_acpi_power_off:
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

no_acpi_power_off:
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

scan_rsdp:
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
diff16 "end of kernel code", 0, $
