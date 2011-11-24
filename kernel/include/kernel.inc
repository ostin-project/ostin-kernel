;;======================================================================================================================
;;///// kernel.inc ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;;----------------------------------------------------------------------------------------------------------------------
;;///// point //////////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct point8_t
  x db ?
  y db ?
ends

struct point16_t
  x dw ?
  y dw ?
ends

struct point32_t
  x dd ?
  y dd ?
ends

struct point64_t
  x dq ?
  y dq ?
ends

;;----------------------------------------------------------------------------------------------------------------------
;;///// size ///////////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct size8_t
  width  db ?
  height db ?
ends

struct size16_t
  width  dw ?
  height dw ?
ends

struct size32_t
  width  dd ?
  height dd ?
ends

struct size64_t
  width  dq ?
  height dq ?
ends

;;----------------------------------------------------------------------------------------------------------------------
;;///// range //////////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct range8_t
  offset db ?
  length db ?
ends

struct range16_t
  offset dw ?
  length dw ?
ends

struct range16x8_t
  offset dw ?
  length db ?
ends

struct range32_t
  offset dd ?
  length dd ?
ends

struct range32x16_t
  offset dd ?
  length dw ?
ends

struct range64_t
  offset dq ?
  length dq ?
ends

struct range64x32_t
  offset dq ?
  length dd ?
ends

;;----------------------------------------------------------------------------------------------------------------------
;;///// memory range ///////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct memory_range16_t
  address dw ?
  size    dw ?
ends

struct memory_range16x8_t
  address dw ?
  size    db ?
ends

struct memory_range32_t
  address dd ?
  size    dd ?
ends

struct memory_range32x16_t
  address dd ?
  size    dw ?
ends

struct memory_range64_t
  address dq ?
  size    dq ?
ends

struct memory_range64x32_t
  address dq ?
  size    dd ?
ends

;;----------------------------------------------------------------------------------------------------------------------
;;///// rect //////////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct rect8_t
  union
    struct
      left   db ?
      top    db ?
      right  db ?
      bottom db ?
    ends
    struct
      top_left     point8_t
      bottom_right point8_t
    ends
  ends
ends

struct rect16_t
  union
    struct
      left   dw ?
      top    dw ?
      right  dw ?
      bottom dw ?
    ends
    struct
      top_left     point16_t
      bottom_right point16_t
    ends
  ends
ends

struct rect32_t
  union
    struct
      left   dd ?
      top    dd ?
      right  dd ?
      bottom dd ?
    ends
    struct
      top_left     point32_t
      bottom_right point32_t
    ends
  ends
ends

struct rect64_t
  union
    struct
      left   dq ?
      top    dq ?
      right  dq ?
      bottom dq ?
    ends
    struct
      top_left     point64_t
      bottom_right point64_t
    ends
  ends
ends

;;----------------------------------------------------------------------------------------------------------------------
;;///// box ////////////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct box8_t
  union
    struct
      left   db ?
      top    db ?
      width  db ?
      height db ?
    ends
    struct
      origin point8_t
      size   size8_t
    ends
  ends
ends

struct box16_t
  union
    struct
      left   dw ?
      top    dw ?
      width  dw ?
      height dw ?
    ends
    struct
      origin point16_t
      size   size16_t
    ends
  ends
ends

struct box32_t
  union
    struct
      left   dd ?
      top    dd ?
      width  dd ?
      height dd ?
    ends
    struct
      origin point32_t
      size   size32_t
    ends
  ends
ends

struct box64_t
  union
    struct
      left   dq ?
      top    dq ?
      width  dq ?
      height dq ?
    ends
    struct
      origin point64_t
      size   size64_t
    ends
  ends
ends

;;----------------------------------------------------------------------------------------------------------------------
;;///// linked list ////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct linked_list_t
  prev_ptr  dd ?
  next_ptr  dd ?
  list_data rb 0
ends

;;----------------------------------------------------------------------------------------------------------------------
;;///// binary tree ////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct b_tree_node_t
  _.parent_ptr dd ?
  _.left_ptr   dd ?
  _.right_ptr  dd ?
ends

struct rb_tree_node_t b_tree_node_t
  _.color db ?
          rb 3
ends

;;----------------------------------------------------------------------------------------------------------------------

; unused
;struct display_mode_t
;  size size16_t
;  bpp  dw ?
;  freq dw ?
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

struct task_stats_t
  counter_sum dd ?
  counter_add dd ?
  cpu_usage   dd ?
ends

struct task_data_t
  pid        dd ?
  mem_start  dd ?
  state      db ?
  wnd_number db ?
             dw ?
  event_mask dd ? ; -> core.thread_t.events.event_mask
  stats      task_stats_t ; -> core.thread_t.stats
  new_pid    dd ?
ends

static_assert sizeof.task_data_t = 32

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
  ev              linked_list_t
  obj             linked_list_t
  saved_esp       dd ?
  io_map          rd 2
  dbg_state       dd ?
  cur_dir         dd ?
  saved_esp0      dd ?
  wait_timeout    dq ?
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
  ipc             memory_range32_t
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
                  rb 24
ends

static_assert sizeof.app_data_t = 256

struct app_io_ports_range_t
  pid        dd ?
  start_port dd ?
  end_port   dd ?
             rd 1
ends

struct regs_context16_t
  di dw ?
  si dw ?
  bp dw ?
  sp dw ?
  union
    bx  dw ?
    struct
      bl db ?
      bh db ?
    ends
  ends
  union
    dx  dw ?
    struct
      dl db ?
      dh db ?
    ends
  ends
  union
    cx  dw ?
    struct
      cl db ?
      ch db ?
    ends
  ends
  union
    ax  dw ?
    struct
      al db ?
      ah db ?
    ends
  ends
ends

struct regs_context32_t
  union
    edi dd ?
    di  dw ?
  ends
  union
    esi dd ?
    si  dw ?
  ends
  union
    ebp dd ?
    bp  dw ?
  ends
  union
    esp dd ?
    sp  dw ?
  ends
  union
    ebx dd ?
    bx  dw ?
    struct
      bl db ?
      bh db ?
    ends
  ends
  union
    edx dd ?
    dx  dw ?
    struct
      dl db ?
      dh db ?
    ends
  ends
  union
    ecx dd ?
    cx  dw ?
    struct
      cl db ?
      ch db ?
    ends
  ends
  union
    eax dd ?
    ax  dw ?
    struct
      al db ?
      ah db ?
    ends
  ends
ends
