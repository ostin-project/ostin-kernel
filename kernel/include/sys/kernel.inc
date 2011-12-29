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

struct chs8x8x8_t
  cylinder db ?
  head     db ?
  sector   db ?
ends

;;----------------------------------------------------------------------------------------------------------------------
;;///// linked list ////////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

struct linked_list_t
  prev_ptr  dd ?
  next_ptr  dd ?
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
  app_name        rb PROCESS_MAX_NAME_LEN
                  rb 16 - PROCESS_MAX_NAME_LEN
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
                  rb 256 - $
ends

static_assert sizeof.app_data_t = 256

struct app_io_ports_range_t
  pid        dd ?
  start_port dd ?
  end_port   dd ?
             rd 1
ends
