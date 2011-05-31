;;======================================================================================================================
;;///// kernel32.inc /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
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

;struc db [a] { common . db a
;  if ~used .
;    display 'not used db: ',`.,13,10
;  end if }
;struc dw [a] { common . dw a
;  if ~used .
;    display 'not used dw: ',`.,13,10
;  end if }
;struc dd [a] { common . dd a
;  if ~used .
;    display 'not used dd: ',`.,13,10
;  end if }
;struc dp [a] { common . dp a
;  if ~used .
;    display 'not used dp: ',`.,13,10
;  end if }
;struc dq [a] { common . dq a
;  if ~used .
;    display 'not used dq: ',`.,13,10
;  end if }
;struc dt [a] { common . dt a
;  if ~used .
;    display 'not used dt: ',`.,13,10
;  end if }

struct point16_t
  x dw ?
  y dw ?
ends

struct point32_t
  x dd ?
  y dd ?
ends

struct rect16_t
  left   dw ?
  top    dw ?
  right  dw ?
  bottom dw ?
ends

struct rect32_t
  left   dd ?
  top    dd ?
  right  dd ?
  bottom dd ?
ends

struct box16_t
  left   dw ?
  top    dw ?
  width  dw ?
  height dw ?
ends

struct box32_t
  left   dd ?
  top    dd ?
  width  dd ?
  height dd ?
ends

; unused
;struct display_mode_t
;  width  dw ?
;  height dw ?
;  bpp    dw ?
;  freq   dw ?
;ends

; constants definition
WSTATE_NORMAL    = 00000000b
WSTATE_MAXIMIZED = 00000001b
WSTATE_MINIMIZED = 00000010b
WSTATE_ROLLEDUP  = 00000100b

WSTATE_REDRAW    = 00000001b
WSTATE_WNDDRAWN  = 00000010b

WSTYLE_HASCAPTION     = 00010000b
WSTYLE_CLIENTRELATIVE = 00100000b

struct task_data_t
  event_mask  dd ?
  pid         dd ?
              dw ?
  state       db ?
              db ?
              dw ?
  wnd_number  db ?
              db ?
  mem_start   dd ?
  counter_sum dd ?
  counter_add dd ?
  cpu_usage   dd ?
ends

TSTATE_RUNNING        = 0
TSTATE_RUN_SUSPENDED  = 1
TSTATE_WAIT_SUSPENDED = 2
TSTATE_ZOMBIE         = 3
TSTATE_TERMINATING    = 4
TSTATE_WAITING        = 5
TSTATE_FREE           = 9

struct window_data_t
  box           box32_t
  union
    cl_workarea dd ?
    struct
                rb 3
      fl_wstyle db ?
    ends
  ends
  cl_titlebar   dd ?
  cl_frames     dd ?
  reserved      db ?
  fl_wstate     db ?
  fl_wdrawn     db ?
  fl_redraw     db ?
ends

struct app_data_debug_regs_t
  dr0 dd ?
  dr1 dd ?
  dr2 dd ?
  dr3 dd ?
  dr7 dd ?
ends

struct app_data_t
  app_name        rb 11
                  rb 5
  fpu_state       dd ?
  ev_count_       dd ? ; unused
  exc_handler     dd ?
  except_mask     dd ?
  pl0_stack       dd ?
  heap_base       dd ?
  heap_top        dd ?
  cursor          dd ?
  fd_ev           dd ?
  bk_ev           dd ?
  fd_obj          dd ?
  bk_obj          dd ?
  saved_esp       dd ?
  io_map          rd 2
  dbg_state       dd ?
  cur_dir         dd ?
  wait_timeout    dd ?
  saved_esp0      dd ?
  wait_begin      dd ?
  wait_test       dd ?
  wait_param      dd ?
  tls_base        dd ?
  dlls_list_ptr   dd ?
                  rb 16
  wnd_shape       dd ?
  wnd_shape_scale dd ?
                  dd ?
  mem_size        dd ?
  saved_box       box32_t
  ipc_start       dd ?
  ipc_size        dd ?
  event_mask      dd ?
  debugger_slot   dd ?
                  dd ?
  keyboard_mode   db ?
                  rb 3
  dir_table       dd ?
  dbg_event_mem   dd ?
  dbg_regs        app_data_debug_regs_t
  wnd_caption     dd ?
  wnd_clientbox   box32_t
ends

struct mutex_t
  count dd ?
  next  dd ?
  prev  dd ?
ends

include "blkdev/cd_drv.inc"
include "blkdev/cdrom.inc"
include "blkdev/fdc.inc"
include "blkdev/flp_drv.inc"
include "blkdev/hd_drv.inc"
include "blkdev/ide_cache.inc"
include "blkdev/rd.inc"

include "bus/pci/pci32.inc"

include "core/conf_lib.inc"
include "core/dll.inc"
include "core/exports.inc"
include "core/ext_lib.inc"
include "core/fpu.inc"
include "core/heap.inc"
include "core/malloc.inc"
include "core/memory.inc"
include "core/peload.inc"
include "core/sched.inc"
include "core/string.inc"
include "core/sync.inc"
include "core/sys32.inc"
include "core/syscall.inc"
include "core/taskman.inc"
include "core/v86.inc"

include "fs/ext2.inc"
include "fs/fat12.inc"
include "fs/fat32.inc"
include "fs/fs.inc"
include "fs/fs_lfn.inc"
include "fs/iso9660.inc"
include "fs/ntfs.inc"
include "fs/parse_fn.inc"

include "gui/button.inc"
include "gui/event.inc"
include "gui/font.inc"
include "gui/mouse.inc"
include "gui/skincode.inc"
include "gui/window.inc"

include "hid/keyboard.inc"
include "hid/mousedrv.inc"
include "hid/set_dtc.inc"

include "imports.inc"

include "network/stack.inc"

include "sound/playnote.inc"

include "video/blitter.inc"
include "video/cursors.inc"
include "video/vesa12.inc"
include "video/vesa20.inc"
include "video/vga.inc"
