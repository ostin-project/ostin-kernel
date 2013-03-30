;;======================================================================================================================
;;///// data.inc /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
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

keymap:
  db '6', 27
  db '1234567890-=', 8, 9
  db 'qwertyuiop[]', 13
  db '~asdfghjkl;', 39, 96, 0, '\zxcvbnm,./', 0, '45 '
  db '@234567890123', 180, 178, 184, '6', 176, '7'
  db 179, '8', 181, 177, 183, 185, 182
  db 'AB<D', 255, 'FGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

keymap_shift:
  db '6', 27
  db '!@#$%^&*()_+', 8, 9
  db 'QWERTYUIOP{}', 13
  db '~ASDFGHJKL:"~', 0, '|ZXCVBNM<>?', 0, '45 '
  db '@234567890123', 180, 178, 184, '6', 176, '7'
  db 179, '8', 181, 177, 183, 185, 182
  db 'AB>D', 255, 'FGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

keymap_alt:
  db ' ', 27
  db ' @ $  {[]}\ ', 8, 9
  db '            ', 13
  db '             ', 0, '           ', 0, '4', 0, ' '
  db '             ', 180, 178, 184, '6', 176, '7'
  db 179, '8', 181, 177, 183, 185, 182
  db 'ABCD', 255, 'FGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

boot_memdetect   db 'Determining amount of memory', 0
boot_tss         db 'Setting TSSs', 0
boot_cpuid       db 'Reading CPUIDs', 0
boot_devices     db 'Detecting devices', 0
boot_windefs     db 'Setting window defaults', 0
boot_bgr         db 'Calculating background', 0
boot_resirqports db 'Reserving IRQs & ports', 0
boot_setostask   db 'Setting OS task', 0
boot_allirqs     db 'Unmasking IRQs', 0
boot_tsc         db 'Reading TSC', 0
boot_cpufreq     db 'CPU frequency is ', '    ', ' MHz', 0
boot_pal_ega     db 'Setting EGA/CGA 320x200 palette', 0
boot_pal_vga     db 'Setting VGA 640x480 palette', 0
boot_failed      db 'Failed to start first app', 0
boot_mtrr        db 'Setting MTRR', 0

boot_apic_found db 'APIC enabled', 0
boot_apic_not_found db 'APIC not found', 0

if KCONFIG_BOOT_LOG_ESC

boot_tasking     db 'All set - press ESC to start', 0

end if

aSis             db 'SIS', 0

intel_str        db "GenuineIntel", 0
AMD_str          db "AuthenticAMD", 0

;szSound         db 'SOUND', 0
;szInfinity      db 'INFINITY', 0
szHwMouse        db 'ATI2D', 0
szPS2MDriver     db 'PS2MOUSE', 0
;szCOM_MDriver   db 'COM_MOUSE', 0
szUSB            db 'USB', 0
szAtiHW          db '/rd/1/drivers/ati2d.drv', 0

szSTART          db 'START', 0
szEXPORTS        db 'EXPORTS', 0
sz_EXPORTS       db '_EXPORTS', 0

szIMPORTS        db 'IMPORTS', 0

read_firstapp    db '/sys/'
firstapp         db 'LAUNCHER', 0

bootpath         db '/KOLIBRI    '
bootpath2        db 0
kernel_file      db 'KERNEL  MNT'

dev_data_path    db '/RD/1/DRIVERS/DEVICES.DAT',0

align 4
draw_line       dd __sys_draw_line
draw_pointer    dd __sys_draw_pointer
drawbar         dd __sys_drawbar
putpixel        dd __sys_putpixel

boot_y          dd 10
syslang         dd 1
keyboard        dw 1

KLog.IncludeDebugStrings

IncludeIGlobals

GdtBegin gdts
  ; Attention! Do not change the order of the first four selectors. They are used in Fast System Call
  ; must be: os_code, os_data, app_code, app_data, ....
  GdtEntry os_code, 0, 0xfffff, cpl0, GDT_FLAG_A + GDT_FLAG_D + GDT_FLAG_G
  GdtEntry os_data, 0, 0xfffff, drw0, GDT_FLAG_A + GDT_FLAG_D + GDT_FLAG_G
  GdtEntry app_code, 0, 0xfffff, cpl3, GDT_FLAG_D + GDT_FLAG_G
  GdtEntry app_data, 0, 0xfffff, drw3, GDT_FLAG_D + GDT_FLAG_G
  ; PCI BIOS
  GdtEntry pci_code_32, 0, 0, cpl0, GDT_FLAG_D
  GdtEntry pci_data_32, 0, 0, dpl0, GDT_FLAG_D
  ; APM (limit 64 KB)
  GdtEntry apm_code_32, 0, 0xf, cpl0, GDT_FLAG_A + GDT_FLAG_D + GDT_FLAG_G
  GdtEntry apm_code_16, 0, 0xf, cpl0, GDT_FLAG_A + GDT_FLAG_G
  GdtEntry apm_data_16, 0, 0xf, drw0, GDT_FLAG_A + GDT_FLAG_G
  ; ...
  GdtEntry graph_data, 0, 0x7ff, drw3, GDT_FLAG_A + GDT_FLAG_D + GDT_FLAG_G
  GdtEntry tss0, tss, sizeof.tss_t - 1, GDT_ACCESS_AC + GDT_ACCESS_EX + GDT_ACCESS_PR, 0
  GdtEntry tls_data, 0, 0xfff, drw3, GDT_FLAG_D
GdtEnd

endofcode:

align 16
fpu_data:         rb 512

;sys_page_map     rd 1
os_stack_seg      rd 1

align 16

_display          display_t

_WinMapRange      memory_range32_t

default_io_map    rd 1

stall_mcs         rd 1

; CPUID information
cpu_vendor        rd 3
cpu_sign          rd 1
cpu_info          rd 1
cpu_caps          rd 4

legacy_slots.last_valid_slot dd ?

pslot_to_wnd_pos  rw MAX_TASK_COUNT ; formely WIN_STACK
wnd_pos_to_pslot  rw MAX_TASK_COUNT ; formely WIN_POS

CPU_FREQ          dd ?

ScreenBPP         db ?
                  rb 3
Screen_Max_Pos    point32_t
BytesPerScanLine  dd ?
SCR_MODE          dw ?
                  rb 2
LFBRange          memory_range32_t
MEM_AMOUNT        dd ?
SYS_SHUTDOWN      db ?

IncludeUGlobals
