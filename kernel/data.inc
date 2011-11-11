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
boot_fonts       db 'Fonts loaded', 0
boot_tss         db 'Setting TSSs', 0
boot_cpuid       db 'Reading CPUIDs', 0
boot_devices     db 'Detecting devices', 0
boot_timer       db 'Setting timer', 0
boot_irqs        db 'Reprogramming IRQs', 0
boot_setmouse    db 'Setting mouse', 0
boot_windefs     db 'Setting window defaults', 0
boot_bgr         db 'Calculating background', 0
boot_resirqports db 'Reserving IRQs & ports', 0
boot_setrports   db 'Setting addresses for IRQs', 0
boot_setostask   db 'Setting OS task', 0
boot_allirqs     db 'Unmasking all IRQs', 0
boot_tsc         db 'Reading TSC', 0
boot_cpufreq     db 'CPU frequency is ', '    ', ' MHz', 0
boot_pal_ega     db 'Setting EGA/CGA 320x200 palette', 0
boot_pal_vga     db 'Setting VGA 640x480 palette', 0
boot_failed      db 'Failed to start first app', 0
boot_mtrr        db 'Setting MTRR', 0

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

char             db '/sys/FONTS/CHAR.MT', 0
char2            db '/sys/FONTS/CHAR2.MT', 0

bootpath         db '/KOLIBRI    '
bootpath2        db 0
vmode            db '/sys/drivers/VMODE.MDR', 0
vrr_m            db 'VRR_M', 0
kernel_file      db 'KERNEL  MNT'

align 4
draw_line       dd __sys_draw_line
draw_pointer    dd __sys_draw_pointer
drawbar         dd __sys_drawbar
putpixel        dd __sys_putpixel

boot_y          dd 10
syslang         dd 1
keyboard        dw 1

if KCONFIG_DEBUG

include_debug_strings

end if

IncludeIGlobals

align 16
gdts:
  dw gdte - $ - 1
  dd gdts
  dw 0

; Attention! Do not change the order of the first four selectors. They are used in Fast System Call
; must be : os_code, os_data, app_code, app_data, ....

int_code_l:
os_code_l:
  dw 0xffff
  dw 0x0000
  db 0x00
  dw 11011111b * 256 + 10011010b
  db 0x00

int_data_l:
os_data_l:
  dw 0xffff
  dw 0x0000
  db 0x00
  dw 11011111b * 256 + 10010010b
  db 0x00

app_code_l:
  dw 0xffff
  dw 0
  db 0
  db cpl3
  dw G32 + D32 + 0xf;

app_data_l:
  dw 0xffff
  dw 0
  db 0
  db drw3
  dw G32 + D32 + 0xf;

;;----------------------------------------------------------------------------------------------------------------------
;;///// PCI BIOS ///////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

pci_code_32:
  dw 0       ; lim  0-15
  dw 0       ; base 0-15
  db 0       ; base 16-23
  db cpl0    ; type
  db D32     ; lim 16-19 + props
  db 0       ; base 24-31

pci_data_32:
  dw 0       ; lim  0-15
  dw 0       ; base 0-15
  db 0       ; base 16-23
  db dpl0    ; type
  db D32     ; lim 16-19 + props
  db 0       ; base 24-31

;;----------------------------------------------------------------------------------------------------------------------
;;///// APM ////////////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

apm_code_32:
  dw 0x0f                        ; limit 64kb
  db 0, 0, 0
  dw 11010000b * 256 + 10011010b
  db 0x00

apm_code_16:
  dw 0x0f
  db 0, 0, 0
  dw 10010000b * 256 + 10011010b
  db 0x00

apm_data_16:
  dw 0x0f
  db 0, 0, 0
  dw 10010000b * 256 + 10010010b
  db 0x00

;-----------------------------------------------------------------------------------------------------------------------

graph_data_l:
  dw 0x7ff
  dw 0x0000
  db 0x00
  dw 11010000b * 256 + 11110010b
  db 0x00

tss0_l:
  dw sizeof.tss_t - 1
  dw tss and 0xffff
  db (tss shr 16) and 0xff
  db 10001001b
  dw (tss shr 16) and 0xff00

tls_data_l:
  dw 0x0fff
  dw 0
  db 0
  db drw3
  dw D32

gdte:

endofcode:

align 16
fpu_data:         rb 512

; device irq owners
irq_owner         rd 16 ; process id

; on irq read ports
irq00read         rd 16
irq01read         rd 16
irq02read         rd 16
irq03read         rd 16
irq04read         rd 16
irq05read         rd 16
irq06read         rd 16
irq07read         rd 16
irq08read         rd 16
irq09read         rd 16
irq10read         rd 16
irq11read         rd 16
irq12read         rd 16
irq13read         rd 16
irq14read         rd 16
irq15read         rd 16

irq_tab           rd 16

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

WIN_STACK         rw 512
WIN_POS           rw 512

KEY_COUNT         db ?
KEY_BUFF          rb 255
BTN_COUNT         db ?
                  rb 3
BTN_BUFF          dd ?

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
