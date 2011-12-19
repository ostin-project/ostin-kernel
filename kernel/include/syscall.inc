;;======================================================================================================================
;;///// syscall.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
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

WINDOW_STATE_NORMAL    = 00000000b
WINDOW_STATE_MAXIMIZED = 00000001b
WINDOW_STATE_MINIMIZED = 00000010b
WINDOW_STATE_ROLLEDUP  = 00000100b

THREAD_STATE_RUNNING        = 0
THREAD_STATE_RUN_SUSPENDED  = 1
THREAD_STATE_WAIT_SUSPENDED = 2
THREAD_STATE_ZOMBIE         = 3
THREAD_STATE_TERMINATING    = 4
THREAD_STATE_WAITING        = 5
THREAD_STATE_FREE           = 9

struct process_info_t
  thread_cpu_usage      dd ?
  window_stack_position dw ?
  window_stack_value    dw ?
                        dw ?
  process_name          rb PROCESS_MAX_NAME_LEN
                        rb 12 - PROCESS_MAX_NAME_LEN
  process_memory_range  memory_range32_t
  thread_id             dd ?
  window_box            box32_t
  thread_state          dw ? ; one of THREAD_STATE_*
                        dw ?
  window_client_box     box32_t
  window_state          db ? ; combination of WINDOW_STATE_*
  thread_event_mask     dd ?
                        rb 1024 - $
ends

struct system_colors_t
  frame            dd ?
  grab             dd ?
  grab_button      dd ?
  grab_button_text dd ?
  grab_text        dd ?
  work             dd ?
  work_button      dd ?
  work_button_text dd ?
  work_text        dd ?
  work_graph       dd ?
ends
