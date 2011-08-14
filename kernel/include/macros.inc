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

macro diff16 title, l1, l2
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

macro diff10 title, l1, l2
{
  local s, d, z, m
  s = l2 - l1
  z = 0
  m = 1000000000
  display title, ': '
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
  display 13, 10
}

macro mov_s_ a, b
{
  if (b eqtype 0) & (b > 255) & ~(a in <cs, ds, es, fs, gs, ss>)
    display "note: using `mov_s_` with `", `b, "` (which is >255) doesn't make much sense", 13, 10
  end if
        push    b
        pop     a
}

macro xchg_s_ a, b
{
        push    a b
        pop     a b
}

macro static_assert cond, message
{
  if ~ (cond)
    if ~ message eq
      display "Assertion failed: ", message, 13, 10
    end if
    __assert_failed__
  end if
}

macro Mov op1, op2, op3 ; op1 = op2 = op3
{
        mov     op2, op3
        mov     op1, op2
}

macro save_ring3_context
{
        pushad
}

macro restore_ring3_context
{
        popad
}

struc utf8 [string_data]
{
common
  local str_size, str_length, i, x
  if used .
    . db string_data
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

struc max_of [value]
{
common
  local max
  max = -0x8000000000000000
forward
  if value > max
    max = value
  end if
common
  . = max
}

struc min_of [value]
{
common
  local min
  min = 0x7fffffffffffffff
forward
  if value < min
    min = value
  end if
common
  . = min
}

macro kproc name
{
  if ~used name
    display "unused proc: ", `name, 13, 10
  end if
  align 4
  name:
}

kendp fix

macro jump_table_element name, element, dash_element
{
  local is_dash
  is_dash equ 0
  match =-, element
  \{
    dd dash_element
    is_dash equ 1
  \}
  match =0, is_dash
  \{
    dd name#.#element
  \}
}

macro jump_table name, table_name, dash_element, [element]
{
  common
    local is_expr
    align 4
    \label name#.#table_name dword
  forward
    is_expr equ 0
    match a =? b =: c, element
    \{
      if (a)
        jump_table_element name, b, dash_element
      else
        jump_table_element name, c, dash_element
      end if
      is_expr equ 1
    \}
    match =0 a =? b, is_expr element
    \{
      if (a)
        jump_table_element name, b, dash_element
      end if
      is_expr equ 1
    \}
    match =0 a, is_expr element
    \{
      jump_table_element name, a, dash_element
    \}
  common
    name#.sizeof.#table_name = $ - name#.#table_name
    name#.countof.#table_name = ($ - name#.#table_name) / 4
}
