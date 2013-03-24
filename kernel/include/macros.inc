;;======================================================================================================================
;;///// macros.inc ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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
;? Various convenience macros
;=======================================================================================================================

macro Diff16 title, l1, l2
{
  local s, d
  s = l2 - l1
  display title, ': 0x'
  repeat 16
    d = '0' + s shr ((16 - %) shl 2) and 0x0f
    if d > '9'
      d = d + 'a' - '9' - 1
    end if
    display d
  end repeat
  display 13, 10
}

macro Diff10 title, l1, l2
{
  local s, d, z, m
  s = l2 - l1
  z = 0
  m = 1000000000
  display title, ': '
  if l2 - l1 = 0
   display '0'
  else
   repeat 10
    d = '0' + s / m
    s = s - (s / m) * m
    m = m / 10
    if d <> '0'
     z = 1
    end if
    if z <> 0
      display d
    end if
   end repeat
  end if
  display 13, 10
}

macro MovStk _dst, _src
{
  if (_src eqtype 0) & (_src > 255) & ~(_dst in <cs, ds, es, fs, gs, ss>)
    display "note: using `MovStk` with `", `_src, "` (which is >255) doesn't make much sense", 13, 10
  end if
        push    _src
        pop     _dst
}

macro XchgStk _a, _b
{
        push    _a _b
        pop     _a _b
}

macro Mov3 _dst1, _dst2, _src ; op1 = op2 = op3
{
        mov     _dst2, _src
        mov     _dst1, _dst2
}

macro ListInsertImpl _new, _prev, _next
{
        mov     [_next + linked_list_t.prev_ptr], _new
        mov     [_new + linked_list_t.next_ptr], _next
        mov     [_new + linked_list_t.prev_ptr], _prev
        mov     [_prev + linked_list_t.next_ptr], _new
}

macro ListPrepend _new, _head
{
        mov     eax, [_head + linked_list_t.next_ptr]
        ListInsertImpl _new, _head, eax
}

macro ListAppend _new, _head
{
        mov     eax, [_head + linked_list_t.prev_ptr]
        ListInsertImpl _new, eax, _head
}

macro ListDelete _entry
{
        mov     edx, [_entry + linked_list_t.next_ptr]
        mov     ecx, [_entry + linked_list_t.prev_ptr]
        mov     [edx + linked_list_t.prev_ptr], ecx
        mov     [ecx + linked_list_t.next_ptr], edx
}

macro SaveRing3Context
{
        pushad
}

macro RestoreRing3Context
{
        popad
}

struc utf8 [_string_data]
{
common
  local str_size, str_length, i, x
  if used .
    . db _string_data
    str_size = $ - .
    str_length = 0
    i = 0
    while i < str_size
      load x byte from . + i
      if ~ x and 0x80
        i = i + 1
      else
        while x and 0x80
          x = (x shl 1) and 0xff
          i = i + 1
        end while
      end if
      if x
        str_length = str_length + 1
      end if
    end while
    . # \.size = str_size
    . # \.length = str_length
  else
    display 'unused string: ', `., 13, 10
  end if
}

struc max_of [_value]
{
common
  local max
  max = -0x8000000000000000
forward
  if defined _value
    if _value > max
      max = _value
    end if
  end if
common
  . = max
}

struc min_of [_value]
{
common
  local min
  min = 0x7fffffffffffffff
forward
  if _value < min
    min = _value
  end if
common
  . = min
}

macro kproc _name
{
  if ~used _name
    display "unused proc: ", `_name, ' [k]', 13, 10
  end if
  align 4
  _name:
}

kendp fix

macro JumpTable.DeclareElement _name, _element, _dash_element
{
  local is_dash
  is_dash equ 0
  match =-, _element
  \{
    dd _dash_element
    is_dash equ 1
  \}
  match =0, is_dash
  \{
    dd _name#.#_element
  \}
  restore is_dash
}

macro JumpTable _name, _table_name, _dash_element, [_element]
{
  common
    if used _name#.#_table_name
      local is_expr
      align 4
      label _name#.#_table_name dword
  forward
      is_expr equ 0
      match a =? b =: c, _element
      \{
        if (a)
          JumpTable.DeclareElement _name, b, _dash_element
        else
          JumpTable.DeclareElement _name, c, _dash_element
        end if
        is_expr equ 1
      \}
      match =0 a =? b, is_expr _element
      \{
        if (a)
          JumpTable.DeclareElement _name, b, _dash_element
        end if
        is_expr equ 1
      \}
      match =0 a, is_expr _element
      \{
        JumpTable.DeclareElement _name, a, _dash_element
      \}
  common
      _name#.sizeof.#_table_name = $ - _name#.#_table_name
      _name#.countof.#_table_name = ($ - _name#.#_table_name) / 4
    else
      display "unused jump table: ", `_name, '.', `_table_name, 13, 10
    end if
    restore is_expr
}
