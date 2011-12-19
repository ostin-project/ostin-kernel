;;======================================================================================================================
;;///// types.inc ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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
;;///// rect ///////////////////////////////////////////////////////////////////////////////////////////////////////////
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
;;///// regs context ///////////////////////////////////////////////////////////////////////////////////////////////////
;;----------------------------------------------------------------------------------------------------------------------

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
