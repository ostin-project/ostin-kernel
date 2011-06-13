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
    d = 48 + s shr ((16 - %) shl 2) and 0x0f
    if d > 57
      d = d + 65 - 57 - 1
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
  local size, i, length, x
  if used .
    . db string_data
    size = $ - .
    length = 0
    i = 0
    while i < size
      load x byte from . + i
      if ~ x and 0x80
        i = i + 1
      else
        while x and 0x80
          x = (x shl 1) and 0xff
          i = i + 1
        end while
      end if
      length = length + 1
    end while
    sizeof.#. = size
    lengthof.#. = length
  else
    display 'unused string: ', `., 13, 10
  end if
}
