;;======================================================================================================================
;;///// const.inc ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

dpl0           equ 10010000b ; data read       dpl0
drw0           equ 10010010b ; data read/write dpl0
drw3           equ 11110010b ; data read/write dpl3
cpl0           equ 10011010b ; code read dpl0
cpl3           equ 11111010b ; code read dpl3

D32            equ 01000000b ; 32bit segment
G32            equ 10000000b ; page gran

;;----------------------------------------------------------------------------------------------------------------------
;;///// cpu_caps flags /////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

CPU_386        equ 3
CPU_486        equ 4
CPU_PENTIUM    equ 5
CPU_P6         equ 6
CPU_PENTIUM4   equ 0x0f

CAPS_FPU       equ 00 ; on-chip x87 floating point unit
CAPS_VME       equ 01 ; virtual-mode enhancements
CAPS_DE        equ 02 ; debugging extensions
CAPS_PSE       equ 03 ; page-size extensions
CAPS_TSC       equ 04 ; time stamp counter
CAPS_MSR       equ 05 ; model-specific registers
CAPS_PAE       equ 06 ; physical-address extensions
CAPS_MCE       equ 07 ; machine check exception
CAPS_CX8       equ 08 ; CMPXCHG8B instruction
CAPS_APIC      equ 09 ; on-chip advanced programmable interrupt controller
;                  10 ; unused
CAPS_SEP       equ 11 ; SYSENTER and SYSEXIT instructions
CAPS_MTRR      equ 12 ; memory-type range registers
CAPS_PGE       equ 13 ; page global extension
CAPS_MCA       equ 14 ; machine check architecture
CAPS_CMOV      equ 15 ; conditional move instructions
CAPS_PAT       equ 16 ; page attribute table

CAPS_PSE36     equ 17 ; page-size extensions
CAPS_PSN       equ 18 ; processor serial number
CAPS_CLFLUSH   equ 19 ; CLFUSH instruction

CAPS_DS        equ 21 ; debug store
CAPS_ACPI      equ 22 ; thermal monitor and software controlled clock supported
CAPS_MMX       equ 23 ; MMX instructions
CAPS_FXSR      equ 24 ; FXSAVE and FXRSTOR instructions
CAPS_SSE       equ 25 ; SSE instructions
CAPS_SSE2      equ 26 ; SSE2 instructions
CAPS_SS        equ 27 ; self-snoop
CAPS_HTT       equ 28 ; hyper-threading technology
CAPS_TM        equ 29 ; thermal monitor supported
CAPS_IA64      equ 30 ; IA64 capabilities
CAPS_PBE       equ 31 ; pending break enable

; ecx
CAPS_SSE3      equ 32 ; SSE3 instructions
;                  33
;                  34
CAPS_MONITOR   equ 35 ; MONITOR/MWAIT instructions
CAPS_DS_CPL    equ 36 ;
CAPS_VMX       equ 37 ; virtual mode extensions
;                  38 ;
CAPS_EST       equ 39 ; enhansed speed step
CAPS_TM2       equ 40 ; thermal monitor2 supported
;                  41
CAPS_CID       equ 42 ;
;                  43
;                  44
CAPS_CX16      equ 45 ; CMPXCHG16B instruction
CAPS_xTPR      equ 46 ;
;
; reserved
;
; ext edx /ecx
CAPS_SYSCAL    equ 64 ;
CAPS_XD        equ 65 ; execution disable
CAPS_FFXSR     equ 66 ;
CAPS_RDTSCP    equ 67 ;
CAPS_X64       equ 68 ;
CAPS_3DNOW     equ 69 ;
CAPS_3DNOWEXT  equ 70 ;
CAPS_LAHF      equ 71 ;
CAPS_CMP_LEG   equ 72 ;
CAPS_SVM       equ 73 ; secure virual machine
CAPS_ALTMOVCR8 equ 74 ;

;;----------------------------------------------------------------------------------------------------------------------
;;///// CPU MSR names //////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

MSR_SYSENTER_CS  equ 0x174
MSR_SYSENTER_ESP equ 0x175
MSR_SYSENTER_EIP equ 0x176
MSR_AMD_EFER     equ 0x0c0000080 ; Extended Feature Enable Register
MSR_AMD_STAR     equ 0x0c0000081 ; SYSCALL/SYSRET Target Address Register

;;----------------------------------------------------------------------------------------------------------------------

CR0_PE         equ 0x00000001 ; protected mode
CR0_MP         equ 0x00000002 ; monitor fpu
CR0_EM         equ 0x00000004 ; fpu emulation
CR0_TS         equ 0x00000008 ; task switch
CR0_ET         equ 0x00000010 ; extension type hardcoded to 1
CR0_NE         equ 0x00000020 ; numeric error
CR0_WP         equ 0x00010000 ; write protect
CR0_AM         equ 0x00040000 ; alignment check
CR0_NW         equ 0x20000000 ; not write-through
CR0_CD         equ 0x40000000 ; cache disable
CR0_PG         equ 0x80000000 ; paging

CR4_VME        equ 0x0001
CR4_PVI        equ 0x0002
CR4_TSD        equ 0x0004
CR4_DE         equ 0x0008
CR4_PSE        equ 0x0010
CR4_PAE        equ 0x0020
CR4_MCE        equ 0x0040
CR4_PGE        equ 0x0080
CR4_PCE        equ 0x0100
CR4_OSFXSR     equ 0x0200
CR4_OSXMMEXPT  equ 0x0400

SSE_IE         equ 0x0001
SSE_DE         equ 0x0002
SSE_ZE         equ 0x0004
SSE_OE         equ 0x0008
SSE_UE         equ 0x0010
SSE_PE         equ 0x0020
SSE_DAZ        equ 0x0040
SSE_IM         equ 0x0080
SSE_DM         equ 0x0100
SSE_ZM         equ 0x0200
SSE_OM         equ 0x0400
SSE_UM         equ 0x0800
SSE_PM         equ 0x1000
SSE_FZ         equ 0x08000

SSE_INIT       equ (SSE_IM + SSE_DM + SSE_ZM + SSE_OM + SSE_UM + SSE_PM)

struct TSS
  _back     rw 2
  _esp0     dd ?
  _ss0      rw 2
  _esp1     dd ?
  _ss1      rw 2
  _esp2     dd ?
  _ss2      rw 2
  _cr3      dd ?
  _eip      dd ?
  _eflags   dd ?
  _eax      dd ?
  _ecx      dd ?
  _edx      dd ?
  _ebx      dd ?
  _esp      dd ?
  _ebp      dd ?
  _esi      dd ?
  _edi      dd ?
  _es       rw 2
  _cs       rw 2
  _ss       rw 2
  _ds       rw 2
  _fs       rw 2
  _gs       rw 2
  _ldt      rw 2
  _trap     dw ?
  _io       dw ?
            rb 24
  _io_map_0 rb 4096
  _io_map_1 rb 4096
ends

OS_BASE             equ 0x080000000

window_data         equ (OS_BASE + 0x0001000)

CURRENT_TASK        equ (OS_BASE + 0x0003000)
TASK_COUNT          equ (OS_BASE + 0x0003004)
TASK_BASE           equ (OS_BASE + 0x0003010)
TASK_DATA           equ (OS_BASE + 0x0003020)
TASK_EVENT          equ (OS_BASE + 0x0003020)

mouseunder          equ (OS_BASE + 0x0006900)
CDDataBuf           equ (OS_BASE + 0x0007000)
FLOPPY_BUFF         equ (OS_BASE + 0x0008000)
ACTIVE_PROC_STACK   equ (OS_BASE + 0x000a400) ; unused
idts                equ (OS_BASE + 0x000b100)
WIN_STACK           equ (OS_BASE + 0x000c000)
WIN_POS             equ (OS_BASE + 0x000c400)
FDD_BUFF            equ (OS_BASE + 0x000d000)

; unused ? only one reference
ENABLE_TASKSWITCH   equ (OS_BASE + 0x000e000)

PUTPIXEL            equ (OS_BASE + 0x000e020)
GETPIXEL            equ (OS_BASE + 0x000e024)

; unused ? only one reference
BANK_SWITCH         equ (OS_BASE + 0x000e030)

; unused ? store mousepointer
MOUSE_PICTURE       equ (OS_BASE + 0x000f200)

MOUSE_VISIBLE       equ (OS_BASE + 0x000f204)
WIN_TEMP_XY         equ (OS_BASE + 0x000f300)
KEY_COUNT           equ (OS_BASE + 0x000f400)
KEY_BUFF            equ (OS_BASE + 0x000f401)

BTN_COUNT           equ (OS_BASE + 0x000f500)
BTN_BUFF            equ (OS_BASE + 0x000f501)

CPU_FREQ            equ (OS_BASE + 0x000f600)

; unused ? no active references
MOUSE_PORT          equ (OS_BASE + 0x000f604)

; unused
PS2_CHUNK           equ (OS_BASE + 0x000fb00)

MOUSE_SCROLL_H      equ (OS_BASE + 0x000fb08)
MOUSE_X             equ (OS_BASE + 0x000fb0a)
MOUSE_Y             equ (OS_BASE + 0x000fb0c)
MOUSE_SCROLL_V      equ (OS_BASE + 0x000fb0e)

MOUSE_COLOR_MEM     equ (OS_BASE + 0x000fb10)
COLOR_TEMP          equ (OS_BASE + 0x000fb30)
BTN_DOWN            equ (OS_BASE + 0x000fb40)
MOUSE_DOWN          equ (OS_BASE + 0x000fb44)
X_UNDER             equ (OS_BASE + 0x000fb4a)
Y_UNDER             equ (OS_BASE + 0x000fb4c)
ScreenBPP           equ (OS_BASE + 0x000fbf1)

; unused ? only one reference
MOUSE_BUFF_COUNT    equ (OS_BASE + 0x000fcff)

Screen_Max_X        equ (OS_BASE + 0x000fe00)
Screen_Max_Y        equ (OS_BASE + 0x000fe04)
BytesPerScanLine    equ (OS_BASE + 0x000fe08)
SCR_MODE            equ (OS_BASE + 0x000fe0c)

LFBAddress          equ (OS_BASE + 0x000fe80)
BTN_ADDR            equ (OS_BASE + 0x000fe88)
MEM_AMOUNT          equ (OS_BASE + 0x000fe8c)

SYS_SHUTDOWN        equ (OS_BASE + 0x000ff00)
TASK_ACTIVATE       equ (OS_BASE + 0x000ff01)

REDRAW_BACKGROUND   equ (OS_BASE + 0x000fff0)
BACKGROUND_CHANGED  equ (OS_BASE + 0x000fff1)
BANK_RW             equ (OS_BASE + 0x000fff2)
MOUSE_BACKGROUND    equ (OS_BASE + 0x000fff4)
DONT_DRAW_MOUSE     equ (OS_BASE + 0x000fff5)
DONT_SWITCH         equ (OS_BASE + 0x000ffff)

TMP_STACK_TOP       equ 0x006cc00

FONT_II             equ (OS_BASE + 0x006dc00)
FONT_I              equ (OS_BASE + 0x006e600)

sys_pgdir           equ (OS_BASE + 0x006f000)

DRIVE_DATA          equ (OS_BASE + 0x0070000)

SLOT_BASE           equ (OS_BASE + 0x0080000)

; unused
TMP_BUFF            equ (OS_BASE + 0x0090000)

VGABasePtr          equ (OS_BASE + 0x00a0000)

RAMDISK             equ (OS_BASE + 0x0100000)
RAMDISK_FAT         equ (OS_BASE + 0x0280000)
FLOPPY_FAT          equ (OS_BASE + 0x0282000)

IDE_DMA             equ 0x284000

BgrAuxTable         equ (OS_BASE + 0x0298000)
; unused?
SB16Buffer          equ (OS_BASE + 0x02a0000)
SB16_Status         equ (OS_BASE + 0x02b0000)

BUTTON_INFO         equ (OS_BASE + 0x02c0000)
RESERVED_PORTS      equ (OS_BASE + 0x02d0000)
IRQ_SAVE            equ (OS_BASE + 0x02e0000)
BOOT_VAR            equ (OS_BASE + 0x02f0000)

stack_data_start    equ (OS_BASE + 0x0300000)
eth_data_start      equ (OS_BASE + 0x0300000)
stack_data          equ (OS_BASE + 0x0304000)

; 32 bit word
stack_config        equ   stack_data
; 32 bit word - IP Address in network format
stack_ip            equ   stack_data + 4
; 1 byte. 0 == inactive, 1 = active
ethernet_active     equ   stack_data + 9
; Address of selected socket
;sktAddr            equ   stack_data + 32
; Parameter to checksum routine - data ptr
checkAdd1           equ   stack_data + 36
; Parameter to checksum routine - 2nd data ptr
checkAdd2           equ   stack_data + 40
; Parameter to checksum routine - data size
checkSize1          equ   stack_data + 44
; Parameter to checksum routine - 2nd data size
checkSize2          equ   stack_data + 46
; result of checksum routine
checkResult         equ   stack_data + 48
; holds the TCP/UDP pseudo header. SA|DA|0|prot|UDP len|
pseudoHeader        equ   stack_data + 50

stack_data_end      equ (OS_BASE + 0x031ffff)
resendQ             equ (OS_BASE + 0x0320000)
VMODE_BASE          equ (OS_BASE + 0x0328000)
skin_data           equ (OS_BASE + 0x0330000)
draw_data           equ (OS_BASE + 0x0338000);

BgrDrawMode         equ (OS_BASE + 0x033bff4)
BgrDataWidth        equ (OS_BASE + 0x033bff8)
BgrDataHeight       equ (OS_BASE + 0x033bffc)

sys_pgmap           equ (OS_BASE + 0x033c000)

UPPER_KERNEL_PAGES  equ (OS_BASE + 0x0400000)

virtual at              (OS_BASE + 0x05fff80)
  tss  TSS
end virtual

HEAP_BASE           equ (OS_BASE + 0x0800000)
HEAP_MIN_SIZE       equ 0x01000000

page_tabs           equ 0x0fdc00000
app_page_tabs       equ 0x0fdc00000
kernel_tabs         equ (page_tabs + (OS_BASE shr 10))   ; 0x0fde00000
master_tab          equ (page_tabs + (page_tabs shr 10)) ; 0x0fdff7000

LFB_BASE            equ 0x0fe000000

new_app_base        equ 0

twdw                equ 0x2000 ; (CURRENT_TASK - window_data)

std_application_base_address   equ new_app_base
RING0_STACK_SIZE    equ (0x2000 - 512) ; 512 байт для контекста FPU

REG_SS              equ (RING0_STACK_SIZE - 4)
REG_APP_ESP         equ (RING0_STACK_SIZE - 8)
REG_EFLAGS          equ (RING0_STACK_SIZE - 12)
REG_CS              equ (RING0_STACK_SIZE - 16)
REG_EIP             equ (RING0_STACK_SIZE - 20)
REG_EAX             equ (RING0_STACK_SIZE - 24)
REG_ECX             equ (RING0_STACK_SIZE - 28)
REG_EDX             equ (RING0_STACK_SIZE - 32)
REG_EBX             equ (RING0_STACK_SIZE - 36)
REG_ESP             equ (RING0_STACK_SIZE - 40) ; RING0_STACK_SIZE - 20
REG_EBP             equ (RING0_STACK_SIZE - 44)
REG_ESI             equ (RING0_STACK_SIZE - 48)
REG_EDI             equ (RING0_STACK_SIZE - 52)
REG_RET             equ (RING0_STACK_SIZE - 56) ; irq0.return

PG_UNMAP            equ 0x000
PG_MAP              equ 0x001
PG_WRITE            equ 0x002
PG_SW               equ 0x003
PG_USER             equ 0x005
PG_UW               equ 0x007
PG_NOCACHE          equ 0x018
PG_LARGE            equ 0x080
PG_GLOBAL           equ 0x100

PG_SHARED           equ 0x200

FREE_BLOCK          equ  0x04
USED_BLOCK          equ  0x08
DONT_FREE_BLOCK     equ  0x10

;;----------------------------------------------------------------------------------------------------------------------
;;///// boot time variables ////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

;BOOT_BPP           equ 0x09000 ; byte    bits per pixel
BOOT_SCANLINE       equ 0x09001 ; word    scanline length
BOOT_VESA_MODE      equ 0x09008 ; word    vesa video mode
;;BOOT_X_RES        equ 0x0900a ; word    X res
;;BOOT_Y_RES        equ 0x0900c ; word    Y res
;;BOOT_MOUSE_PORT   equ 0x09010 ; byte    mouse port  - not used
BOOT_BANK_SW        equ 0x09014 ; dword   Vesa 1.2 pm bank switch
BOOT_LFB            equ 0x09018 ; dword   Vesa 2.0 LFB address
BOOT_MTRR           equ 0x0901c ; byte    0 or 1 : enable MTRR graphics acceleration
BOOT_LOG            equ 0x0901d ; byte    not used anymore (0 or 1 : enable system log display)
BOOT_DIRECT_LFB     equ 0x0901e ; byte    0 or 1 : enable direct lfb write, paging disabled
BOOT_PCI_DATA       equ 0x09020 ; 8 bytes pci data
BOOT_VRR            equ 0x09030 ; byte    VRR start enabled 1, 2-no
BOOT_IDE_BASE_ADDR  equ 0x09031 ; word    IDEContrRegsBaseAddr
BOOT_MEM_AMOUNT     equ 0x09034 ; dword   memory amount

;;----------------------------------------------------------------------------------------------------------------------

TMP_FILE_NAME       equ     0
TMP_CMD_LINE        equ  1024
TMP_ICON_OFFS       equ  1280

EVENT_REDRAW        equ 0x00000001
EVENT_KEY           equ 0x00000002
EVENT_BUTTON        equ 0x00000004
EVENT_BACKGROUND    equ 0x00000010
EVENT_MOUSE         equ 0x00000020
EVENT_IPC           equ 0x00000040
EVENT_NETWORK       equ 0x00000080
EVENT_DEBUG         equ 0x00000100
EVENT_EXTENDED      equ 0x00000200

EV_INTR             equ 1

struct APPOBJ  ; common object header
  magic   dd ?
  destroy dd ? ; internal destructor
  fd      dd ? ; next object in list
  bk      dd ? ; prev object in list
  pid     dd ? ; owner id
ends

APP_OBJ_OFFSET  equ 48
APP_EV_OFFSET   equ 40

struct CURSOR APPOBJ ; magic = 'CURS'
  base      dd ?     ; allocated memory
  hot_x     dd ?     ; hotspot coords
  hot_y     dd ?

  list_next dd ?     ; next cursor in cursor list
  list_prev dd ?     ; prev cursor in cursor list
  dev_obj   dd ?     ; device-specific data
ends

struct EVENT_CODE
  data rd 6
ends

struct EVENT APPOBJ ; magic = 'EVNT'
  id    dd ?        ; event uid
  state dd ?        ; internal flags
  code  EVENT_CODE
ends

struct SMEM
  bk       dd ?
  fd       dd ?
  base     dd ?
  size     dd ?
  access   dd ?
  refcount dd ?
  name     rb 32
ends

struct SMAP APPOBJ ; magic = 'SMAP'
  base    dd ?     ; mapped base
  parent  dd ?     ; SMEM
ends

struct DLLDESCR
  bk          dd ?
  fd          dd ?
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

struct HDLL
  fd       dd ? ; next object in list
  bk       dd ? ; prev object in list
  pid      dd ? ; owner id

  base     dd ? ; mapped base
  size     dd ? ; mapped size
  refcount dd ? ; reference counter for this process and this lib
  parent   dd ? ; DLLDESCR
ends

struct display_t
  x              dd ?
  y              dd ?
  width          dd ?
  height         dd ?
  bpp            dd ?
  vrefresh       dd ?
  pitch          dd ?
  lfb            dd ?

  modes          dd ?
  ddev           dd ?
  connector      dd ?
  crtc           dd ?

  cr_list.next   dd ?
  cr_list.prev   dd ?

  cursor         dd ?

  init_cursor    dd ?
  select_cursor  dd ?
  show_cursor    dd ?
  move_cursor    dd ?
  restore_cursor dd ?
  disable_mouse  dd ?
ends

struct HEAP_DATA
  mutex     dd ?
  refcount  dd ?
  heap_base dd ?
  heap_top  dd ?
  app_mem   dd ?
ends

struct BOOT_DATA
  bpp           dd ?
  scanline      dd ?
  vesa_mode     dd ?
  x_res         dd ?
  y_res         dd ?
  mouse_port    dd ?
  bank_switch   dd ?
  lfb           dd ?
  vesa_mem      dd ?
  log           dd ?
  direct_lfb    dd ?
  pci_data      dd ?
;               dd ?
  vrr           dd ?
  ide_base      dd ?
  mem_amount    dd ?
  pages_count   dd ?
  pagemap_size  dd ?
  kernel_max    dd ?
  kernel_pages  dd ?
  kernel_tables dd ?

  cpu_vendor    dd ?
                dd ?
                dd ?
  cpu_sign      dd ?
  cpu_info      dd ?
  cpu_caps      dd ?
                dd ?
                dd ?
ends

struct MEM_STATE
  mutex     dd ?
  smallmap  dd ?
  treemap   dd ?
  topsize   dd ?
  top       dd ?
  smallbins rd 4 * 32
  treebins  rd 32
ends

struct PG_DATA
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

;struct LIB
;  lib_name  rb 16
;  lib_base  dd ?
;  lib_start dd ?
;  export    dd ?
;  import    dd ?
;ends

struct SRV
  srv_name    rb 16 ; ASCIIZ string
  magic       dd ?  ; ' SRV'
  size        dd ?  ; size of structure SRV
  fd          dd ?  ; next SRV descriptor
  bk          dd ?  ; prev SRV descriptor
  base        dd ?  ; service base address
  entry       dd ?  ; service START function
  srv_proc    dd ?  ; user mode service handler
  srv_proc_ex dd ?  ; kernel mode service handler
ends

SRV_FD_OFFSET  equ 0x18

DRV_ENTRY    equ  1
DRV_EXIT     equ -1

struct COFF_HEADER
  machine   dw ?
  nSections dw ?
  DataTime  dd ?
  pSymTable dd ?
  nSymbols  dd ?
  optHeader dw ?
  flags     dw ?
ends

struct COFF_SECTION
  Name            rb 8
  VirtualSize     dd ?
  VirtualAddress  dd ?
  SizeOfRawData   dd ?
  PtrRawData      dd ?
  PtrReloc        dd ?
  PtrLinenumbers  dd ?
  NumReloc        dw ?
  NumLinenum      dw ?
  Characteristics dd ?
ends

struct COFF_RELOC
  VirtualAddress dd ?
  SymIndex       dd ?
  Type           dw ?
ends

struct COFF_SYM
  Name          rb 8
  Value         dd ?
  SectionNumber dw ?
  Type          dw ?
  StorageClass  db ?
  NumAuxSymbols db ?
ends

struct IOCTL
  handle   dd ?
  io_code  dd ?
  input    dd ?
  inp_size dd ?
  output   dd ?
  out_size dd ?
ends

struct DRIVE_CACHE
  pointer           dd ?
  size              dd ? ; not use
  data_pointer      dd ?
  system_data_size  dd ? ; not use
  appl_data_size    dd ? ; not use
  system_data       dd ?
  appl_data         dd ?
  system_sad_size   dd ?
  appl_sad_size     dd ?
  search_start      dd ?
  appl_search_start dd ?
ends
