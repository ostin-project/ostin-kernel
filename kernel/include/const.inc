;;======================================================================================================================
;;///// const.inc ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2006-2011 KolibriOS team <http://kolibrios.org/>
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

dpl0           = 10010000b ; data read       dpl0
drw0           = 10010010b ; data read/write dpl0
drw3           = 11110010b ; data read/write dpl3
cpl0           = 10011010b ; code read dpl0
cpl3           = 11111010b ; code read dpl3

D32            = 01000000b ; 32bit segment
G32            = 10000000b ; page gran

;;----------------------------------------------------------------------------------------------------------------------
;;///// cpu_caps flags /////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

CPU_386        = 3
CPU_486        = 4
CPU_PENTIUM    = 5
CPU_P6         = 6
CPU_PENTIUM4   = 0x0f

CAPS_FPU       = 0  ; on-chip x87 floating point unit
CAPS_VME       = 1  ; virtual-mode enhancements
CAPS_DE        = 2  ; debugging extensions
CAPS_PSE       = 3  ; page-size extensions
CAPS_TSC       = 4  ; time stamp counter
CAPS_MSR       = 5  ; model-specific registers
CAPS_PAE       = 6  ; physical-address extensions
CAPS_MCE       = 7  ; machine check exception
CAPS_CX8       = 8  ; CMPXCHG8B instruction
CAPS_APIC      = 9  ; on-chip advanced programmable interrupt controller
;                10 ; unused
CAPS_SEP       = 11 ; SYSENTER and SYSEXIT instructions
CAPS_MTRR      = 12 ; memory-type range registers
CAPS_PGE       = 13 ; page global extension
CAPS_MCA       = 14 ; machine check architecture
CAPS_CMOV      = 15 ; conditional move instructions
CAPS_PAT       = 16 ; page attribute table

CAPS_PSE36     = 17 ; page-size extensions
CAPS_PSN       = 18 ; processor serial number
CAPS_CLFLUSH   = 19 ; CLFUSH instruction

CAPS_DS        = 21 ; debug store
CAPS_ACPI      = 22 ; thermal monitor and software controlled clock supported
CAPS_MMX       = 23 ; MMX instructions
CAPS_FXSR      = 24 ; FXSAVE and FXRSTOR instructions
CAPS_SSE       = 25 ; SSE instructions
CAPS_SSE2      = 26 ; SSE2 instructions
CAPS_SS        = 27 ; self-snoop
CAPS_HTT       = 28 ; hyper-threading technology
CAPS_TM        = 29 ; thermal monitor supported
CAPS_IA64      = 30 ; IA64 capabilities
CAPS_PBE       = 31 ; pending break enable

; ecx
CAPS_SSE3      = 32 ; SSE3 instructions
;                33
;                34
CAPS_MONITOR   = 35 ; MONITOR/MWAIT instructions
CAPS_DS_CPL    = 36 ;
CAPS_VMX       = 37 ; virtual mode extensions
;                38 ;
CAPS_EST       = 39 ; enhansed speed step
CAPS_TM2       = 40 ; thermal monitor2 supported
;                41
CAPS_CID       = 42 ;
;                43
;                44
CAPS_CX16      = 45 ; CMPXCHG16B instruction
CAPS_xTPR      = 46 ;
;
; reserved
;
; ext edx /ecx
CAPS_SYSCAL    = 64 ;
CAPS_XD        = 65 ; execution disable
CAPS_FFXSR     = 66 ;
CAPS_RDTSCP    = 67 ;
CAPS_X64       = 68 ;
CAPS_3DNOW     = 69 ;
CAPS_3DNOWEXT  = 70 ;
CAPS_LAHF      = 71 ;
CAPS_CMP_LEG   = 72 ;
CAPS_SVM       = 73 ; secure virual machine
CAPS_ALTMOVCR8 = 74 ;

;;----------------------------------------------------------------------------------------------------------------------
;;///// CPU MSR names //////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

MSR_SYSENTER_CS  = 0x174
MSR_SYSENTER_ESP = 0x175
MSR_SYSENTER_EIP = 0x176
MSR_AMD_EFER     = 0xc0000080 ; Extended Feature Enable Register
MSR_AMD_STAR     = 0xc0000081 ; SYSCALL/SYSRET Target Address Register

;;----------------------------------------------------------------------------------------------------------------------

CR0_PE        = 0x00000001 ; protected mode
CR0_MP        = 0x00000002 ; monitor fpu
CR0_EM        = 0x00000004 ; fpu emulation
CR0_TS        = 0x00000008 ; task switch
CR0_ET        = 0x00000010 ; extension type hardcoded to 1
CR0_NE        = 0x00000020 ; numeric error
CR0_WP        = 0x00010000 ; write protect
CR0_AM        = 0x00040000 ; alignment check
CR0_NW        = 0x20000000 ; not write-through
CR0_CD        = 0x40000000 ; cache disable
CR0_PG        = 0x80000000 ; paging

CR4_VME       = 0x0001
CR4_PVI       = 0x0002
CR4_TSD       = 0x0004
CR4_DE        = 0x0008
CR4_PSE       = 0x0010
CR4_PAE       = 0x0020
CR4_MCE       = 0x0040
CR4_PGE       = 0x0080
CR4_PCE       = 0x0100
CR4_OSFXSR    = 0x0200
CR4_OSXMMEXPT = 0x0400

SSE_IE        = 0x0001
SSE_DE        = 0x0002
SSE_ZE        = 0x0004
SSE_OE        = 0x0008
SSE_UE        = 0x0010
SSE_PE        = 0x0020
SSE_DAZ       = 0x0040
SSE_IM        = 0x0080
SSE_DM        = 0x0100
SSE_ZM        = 0x0200
SSE_OM        = 0x0400
SSE_UM        = 0x0800
SSE_PM        = 0x1000
SSE_FZ        = 0x8000

SSE_INIT      = SSE_IM + SSE_DM + SSE_ZM + SSE_OM + SSE_UM + SSE_PM

struct tss_t
  back     rw 2
  esp0     dd ?
  ss0      rw 2
  esp1     dd ?
  ss1      rw 2
  esp2     dd ?
  ss2      rw 2
  cr3      dd ?
  eip      dd ?
  eflags   dd ?
  eax      dd ?
  ecx      dd ?
  edx      dd ?
  ebx      dd ?
  esp      dd ?
  ebp      dd ?
  esi      dd ?
  edi      dd ?
  es       rw 2
  cs       rw 2
  ss       rw 2
  ds       rw 2
  fs       rw 2
  gs       rw 2
  ldt      rw 2
  trap     dw ?
  io       dw ?
           rb 24
  io_map_0 rb 4096
  io_map_1 rb 4096
ends

OS_BASE             = 0x80000000

window_data         = OS_BASE + 0x0001000

CURRENT_TASK        = OS_BASE + 0x0003000
TASK_COUNT          = OS_BASE + 0x0003004
TASK_BASE           = OS_BASE + 0x0003010
TASK_DATA           = OS_BASE + 0x0003020
;TASK_EVENT         = OS_BASE + 0x0003020 ; unused

mouseunder          = OS_BASE + 0x0006900
CDDataBuf           = OS_BASE + 0x0007000
FLOPPY_BUFF         = OS_BASE + 0x0008000
;ACTIVE_PROC_STACK  = OS_BASE + 0x000a400 ; unused
idts                = OS_BASE + 0x000b100
WIN_STACK           = OS_BASE + 0x000c000
WIN_POS             = OS_BASE + 0x000c400
FDD_BUFF            = OS_BASE + 0x000d000

ENABLE_TASKSWITCH   = OS_BASE + 0x000e000 ; unused? 1 write, 0 reads

PUTPIXEL            = OS_BASE + 0x000e020
GETPIXEL            = OS_BASE + 0x000e024

BANK_SWITCH         = OS_BASE + 0x000e030 ; unused? 1 write, 0 reads

; store mousepointer
MOUSE_PICTURE       = OS_BASE + 0x000f200

MOUSE_VISIBLE       = OS_BASE + 0x000f204
;WIN_TEMP_XY        = OS_BASE + 0x000f300 ; unused
KEY_COUNT           = OS_BASE + 0x000f400
KEY_BUFF            = OS_BASE + 0x000f401

BTN_COUNT           = OS_BASE + 0x000f500
BTN_BUFF            = OS_BASE + 0x000f501

CPU_FREQ            = OS_BASE + 0x000f600

;MOUSE_PORT         = OS_BASE + 0x000f604 ; unused

;PS2_CHUNK          = OS_BASE + 0x000fb00 ; unused

MOUSE_SCROLL_H      = OS_BASE + 0x000fb08
MOUSE_X             = OS_BASE + 0x000fb0a
MOUSE_Y             = OS_BASE + 0x000fb0c
MOUSE_SCROLL_V      = OS_BASE + 0x000fb0e

MOUSE_COLOR_MEM     = OS_BASE + 0x000fb10
COLOR_TEMP          = OS_BASE + 0x000fb30
BTN_DOWN            = OS_BASE + 0x000fb40
MOUSE_DOWN          = OS_BASE + 0x000fb44 ; unused? 3 writes, 0 reads
X_UNDER             = OS_BASE + 0x000fb4a
Y_UNDER             = OS_BASE + 0x000fb4c
ScreenBPP           = OS_BASE + 0x000fbf1

MOUSE_BUFF_COUNT    = OS_BASE + 0x000fcff ; unused? 1 write, 0 reads

Screen_Max_X        = OS_BASE + 0x000fe00
Screen_Max_Y        = OS_BASE + 0x000fe04
BytesPerScanLine    = OS_BASE + 0x000fe08
SCR_MODE            = OS_BASE + 0x000fe0c

LFBAddress          = OS_BASE + 0x000fe80
BTN_ADDR            = OS_BASE + 0x000fe88
MEM_AMOUNT          = OS_BASE + 0x000fe8c

SYS_SHUTDOWN        = OS_BASE + 0x000ff00
;TASK_ACTIVATE      = OS_BASE + 0x000ff01 ; unused

REDRAW_BACKGROUND   = OS_BASE + 0x000fff0
BACKGROUND_CHANGED  = OS_BASE + 0x000fff1
BANK_RW             = OS_BASE + 0x000fff2
MOUSE_BACKGROUND    = OS_BASE + 0x000fff4 ; unused? 6 writes, 0 reads
DONT_DRAW_MOUSE     = OS_BASE + 0x000fff5 ; unused? 4 writes, 0 reads
DONT_SWITCH         = OS_BASE + 0x000ffff

;TMP_STACK_TOP      = 0x006cc00           ; unused

FONT_II             = OS_BASE + 0x006dc00
FONT_I              = OS_BASE + 0x006e600

sys_pgdir           = OS_BASE + 0x006f000

DRIVE_DATA          = OS_BASE + 0x0070000

SLOT_BASE           = OS_BASE + 0x0080000

;TMP_BUFF           = OS_BASE + 0x0090000 ; unused

VGABasePtr          = OS_BASE + 0x00a0000

RAMDISK             = OS_BASE + 0x0100000
RAMDISK_FAT         = OS_BASE + 0x0280000
FLOPPY_FAT          = OS_BASE + 0x0282000

CLEAN_ZONE          = 0x284000
IDE_DMA             = 0x284000

BgrAuxTable         = OS_BASE + 0x0298000
;SB16Buffer         = OS_BASE + 0x02a0000 ; unused
;SB16_Status        = OS_BASE + 0x02b0000 ; unused

BUTTON_INFO         = OS_BASE + 0x02c0000
RESERVED_PORTS      = OS_BASE + 0x02d0000
IRQ_SAVE            = OS_BASE + 0x02e0000
BOOT_VAR            = OS_BASE + 0x02f0000

stack_data_start    = OS_BASE + 0x0300000
eth_data_start      = OS_BASE + 0x0300000
stack_data          = OS_BASE + 0x0304000

; 32 bit word
stack_config        = stack_data
; 32 bit word - IP Address in network format
stack_ip            = stack_data + 4
; 1 byte. 0 == inactive, 1 = active
ethernet_active     = stack_data + 9
; Address of selected socket
;sktAddr            = stack_data + 32
; Parameter to checksum routine - data ptr
checkAdd1           = stack_data + 36
; Parameter to checksum routine - 2nd data ptr
checkAdd2           = stack_data + 40
; Parameter to checksum routine - data size
checkSize1          = stack_data + 44
; Parameter to checksum routine - 2nd data size
checkSize2          = stack_data + 46
; result of checksum routine
checkResult         = stack_data + 48
; holds the TCP/UDP pseudo header. SA|DA|0|prot|UDP len|
pseudoHeader        = stack_data + 50

;stack_data_end     = OS_BASE + 0x031ffff ; unused
resendQ             = OS_BASE + 0x0320000
VMODE_BASE          = OS_BASE + 0x0328000
skin_data           = OS_BASE + 0x0330000
draw_data           = OS_BASE + 0x0338000

BgrDrawMode         = OS_BASE + 0x033bff4
BgrDataWidth        = OS_BASE + 0x033bff8
BgrDataHeight       = OS_BASE + 0x033bffc

BOOT_VAR            = OS_BASE + 0x0340000

sys_pgmap           = OS_BASE + 0x0350000

;UPPER_KERNEL_PAGES = OS_BASE + 0x0400000 ; unused

virtual at            OS_BASE + 0x05fff80
  tss tss_t
end virtual

HEAP_BASE           = OS_BASE + 0x0800000
HEAP_MIN_SIZE       = 0x01000000

page_tabs           = 0xfdc00000
app_page_tabs       = 0xfdc00000
kernel_tabs         = page_tabs + (OS_BASE shr 10)   ; 0xfde00000
master_tab          = page_tabs + (page_tabs shr 10) ; 0xfdff7000

LFB_BASE            = 0xfe000000

new_app_base        = 0

twdw                = 0x2000 ; CURRENT_TASK - window_data

std_application_base_address   equ new_app_base
RING0_STACK_SIZE    = 0x2000 - 512 ; 512 bytes for FPU context

REG_SS              = RING0_STACK_SIZE - 4
REG_APP_ESP         = RING0_STACK_SIZE - 8
REG_EFLAGS          = RING0_STACK_SIZE - 12
REG_CS              = RING0_STACK_SIZE - 16
REG_EIP             = RING0_STACK_SIZE - 20
REG_EAX             = RING0_STACK_SIZE - 24
REG_ECX             = RING0_STACK_SIZE - 28
REG_EDX             = RING0_STACK_SIZE - 32
REG_EBX             = RING0_STACK_SIZE - 36
REG_ESP             = RING0_STACK_SIZE - 40 ; RING0_STACK_SIZE - 20
REG_EBP             = RING0_STACK_SIZE - 44
REG_ESI             = RING0_STACK_SIZE - 48
REG_EDI             = RING0_STACK_SIZE - 52
REG_RET             = RING0_STACK_SIZE - 56 ; irq0.return

PG_UNMAP            = 0x000
PG_MAP              = 0x001
PG_WRITE            = 0x002
PG_SW               = 0x003
PG_USER             = 0x005
PG_UW               = 0x007
PG_NOCACHE          = 0x018
PG_LARGE            = 0x080
PG_GLOBAL           = 0x100

PG_SHARED           = 0x200

FREE_BLOCK          = 0x04
USED_BLOCK          = 0x08
DONT_FREE_BLOCK     = 0x10

;;----------------------------------------------------------------------------------------------------------------------
;;///// boot time variables ////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

virtual at 0x9000
  BOOT_BPP              db ?  ; 0x09000 - bits per pixel
  BOOT_SCANLINE         dw ?  ; 0x09001 - scanline length
                        rb 5  ;
  BOOT_VESA_MODE        dw ?  ; 0x09008 - vesa video mode
  BOOT_X_RES            dw ?  ; 0x0900a - X res
  BOOT_Y_RES            dw ?  ; 0x0900c - Y res
                        rb 2  ;
; BOOT_MOUSE_PORT       db ?  ; 0x09010 - mouse port (unused)
                        rb 4  ;
  BOOT_BANK_SW          dd ?  ; 0x09014 - Vesa 1.2 pm bank switch
  BOOT_LFB              dd ?  ; 0x09018 - Vesa 2.0 LFB address
  BOOT_MTRR             db ?  ; 0x0901c - 0 or 1: enable MTRR graphics acceleration
; BOOT_LOG              db ?  ; 0x0901d - 0 or 1: enable system log display (unused)
                        rb 1  ;
  BOOT_DIRECT_LFB       db ?  ; 0x0901e - 0 or 1: enable direct lfb write, paging disabled
  BOOT_DMA              db ?  ; 0x0901f - 0 or 1: enable DMA
  BOOT_PCI_DATA         rb 8  ; 0x09020 - pci data
                        rb 8
  BOOT_VRR              db ?  ; 0x09030 - VRR start enabled 1, 2-no
  BOOT_IDE_BASE_ADDR    dw ?  ; 0x09031 - IDEContrRegsBaseAddr
                        rb 1  ;         -
; BOOT_MEM_AMOUNT       dd ?  ; 0x09034 - memory amount (unused)
                        rb 12
  BOOT_APM_ENTRY_OFS    dd ?  ; 0x09040 - APM entry point offset
  BOOT_APM_VERSION      dw ?  ; 0x09044 - APM version
  BOOT_APM_FLAGS        dw ?  ; 0x09046 - APM flags
                        rb 8
  BOOT_APM_CODE32_SEG   dw ?  ; 0x09050 - APM RM segment base address of PM 32-bit code segment
  BOOT_APM_CODE16_SEG   dw ?  ; 0x09052 - APM RM segment base address of PM 16-bit code segment
  BOOT_APM_DATA16_SEG   dw ?  ; 0x09054 - APM RM segment base address of PM 16-bit data segment
                        rb 41
  BOOT_BIOS_DISKS_CNT   db ?  ; 0x0907f - BIOS disks count
  BOOT_BIOS_DISKS       rd 32 ; 0x09080 - BIOS disks data
  BOOT_PHOENIX_SMAP_CNT dd ?  ; 0x09100
  BOOT_PHOENIX_SMAP     rb 32 * sizeof.phoenix_smap_addr_range_t ; 0x09104
end virtual

;;----------------------------------------------------------------------------------------------------------------------

TMP_FILE_NAME       = 0
TMP_CMD_LINE        = 1024
TMP_ICON_OFFS       = 1280

EVENT_REDRAW        = 0x00000001
EVENT_KEY           = 0x00000002
EVENT_BUTTON        = 0x00000004
EVENT_BACKGROUND    = 0x00000010
EVENT_MOUSE         = 0x00000020
EVENT_IPC           = 0x00000040
EVENT_NETWORK       = 0x00000080
EVENT_DEBUG         = 0x00000100
EVENT_EXTENDED      = 0x00000200

EV_INTR             = 1

struct app_object_t ; common object header
  magic    dd ?
  destroy  dd ? ; internal destructor
  next_ptr dd ? ; next object in list
  prev_ptr dd ? ; prev object in list
  pid      dd ? ; owner id
ends

APP_OBJ_OFFSET  = 48
APP_EV_OFFSET   = 40

struct cursor_t app_object_t ; magic = 'CURS'
  base    dd ?          ; allocated memory
  hot     point32_t     ; hotspot coords

  list    linked_list_t ; next/prev cursor in cursor list
  dev_obj dd ?          ; device-specific data
ends

struct event_code_t
  data rd 6
ends

struct event_t app_object_t ; magic = 'EVNT'
  id    dd ?        ; event uid
  state dd ?        ; internal flags
  code  event_code_t
ends

struct smem_t linked_list_t
  base     dd ?
  size     dd ?
  access   dd ?
  refcount dd ?
  name     rb 32
ends

struct smap_t app_object_t ; magic = 'SMAP'
  base    dd ?     ; mapped base
  parent  dd ?     ; smem_t
ends

struct dll_descriptor_t linked_list_t
  data        dd ?
  size        dd ?
  timestamp   dq ?
  refcount    dd ?
  defaultbase dd ?
  coff_hdr    dd ?
  symbols_ptr dd ?
  symbols_num dd ?
  symbols_lim dd ?
  exports     dd ? ; export table
  name        rb 0
ends

struct dll_handle_t linked_list_t
  pid      dd ? ; owner id

  base     dd ? ; mapped base
  size     dd ? ; mapped size
  refcount dd ? ; reference counter for this process and this lib
  parent   dd ? ; dll_descriptor_t
ends

struct display_t
  box            box32_t
  bpp            dd ?
  vrefresh       dd ?
  pitch          dd ?
  lfb            dd ?

  modes          dd ?
  ddev           dd ?
  connector      dd ?
  crtc           dd ?

  cr_list        linked_list_t

  cursor         dd ?

  init_cursor    dd ?
  select_cursor  dd ?
  show_cursor    dd ?
  move_cursor    dd ?
  restore_cursor dd ?
  disable_mouse  dd ?
ends

; unused
;struct heap_data_t
;  mutex     dd ?
;  refcount  dd ?
;  heap_base dd ?
;  heap_top  dd ?
;  app_mem   dd ?
;ends

; unused
;struct boot_data_t
;  bpp           dd ?
;  scanline      dd ?
;  vesa_mode     dd ?
;  x_res         dd ?
;  y_res         dd ?
;  mouse_port    dd ?
;  bank_switch   dd ?
;  lfb           dd ?
;  vesa_mem      dd ?
;  log           dd ?
;  direct_lfb    dd ?
;  pci_data      dd ?
;;               dd ?
;  vrr           dd ?
;  ide_base      dd ?
;  mem_amount    dd ?
;  pages_count   dd ?
;  pagemap_size  dd ?
;  kernel_max    dd ?
;  kernel_pages  dd ?
;  kernel_tables dd ?
;
;  cpu_vendor    dd ?
;                dd ?
;                dd ?
;  cpu_sign      dd ?
;  cpu_info      dd ?
;  cpu_caps      dd ?
;                dd ?
;                dd ?
;ends

struct memory_state_t
  mutex     dd ?
  smallmap  dd ?
  treemap   dd ?
  topsize   dd ?
  top       dd ?
  smallbins rd 4 * 32
  treebins  rd 32
ends

struct pages_data_t
  mem_amount    dd ?
  vesa_mem      dd ?
  pages_count   dd ?
  pages_free    dd ?
  pages_faults  dd ?
  pagemap_size  dd ?
  kernel_pages  dd ?
  kernel_tables dd ?
  sys_page_dir  dd ?
  pg_mutex      dd ?
ends

;struct library_t
;  lib_name  rb 16
;  lib_base  dd ?
;  lib_start dd ?
;  export    dd ?
;  import    dd ?
;ends

struct service_t
  srv_name    rb 16 ; ASCIIZ string
  magic       dd ?  ; ' SRV'
  size        dd ?  ; size of structure Service
  next_ptr    dd ?  ; next Service descriptor
  prev_ptr    dd ?  ; prev Service descriptor
  base        dd ?  ; service base address
  entry       dd ?  ; service START function
  srv_proc    dd ?  ; user mode service handler
  srv_proc_ex dd ?  ; kernel mode service handler
ends

SRV_FD_OFFSET = 0x18

DRV_ENTRY = 1
DRV_EXIT  = -1

struct coff_header_t
  machine      dw ?
  sections_cnt dw ?
  data_time    dd ?
  syms_ptr     dd ?
  syms_cnt     dd ?
  opt_header   dw ?
  flags        dw ?
ends

struct coff_section_t
  name             rb 8
  virtual_size     dd ?
  virtual_addr     dd ?
  raw_data_size    dd ?
  raw_data_ptr     dd ?
  relocs_ptr       dd ?
  line_numbers_ptr dd ?
  relocs_cnt       dw ?
  line_numbers_cnt dw ?
  characteristics  dd ?
ends

struct coff_reloc_t
  virtual_addr dd ?
  sym_index    dd ?
  type         dw ?
ends

struct coff_sym_t
  name            rb 8
  value           dd ?
  section_number  dw ?
  type            dw ?
  storage_class   db ?
  aux_symbols_cnt db ?
ends

struct ioctl_t
  handle   dd ?
  io_code  dd ?
  input    dd ?
  inp_size dd ?
  output   dd ?
  out_size dd ?
ends

struct drive_cache_t
  ptr              dd ?
  size             dd ? ; not use
  data_ptr         dd ?
  sys_data_size    dd ? ; not use
  app_data_size    dd ? ; not use
  sys_data         dd ?
  app_data         dd ?
  sys_sad_size     dd ?
  app_sad_size     dd ?
  sys_search_start dd ?
  app_search_start dd ?
ends
