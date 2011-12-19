;;======================================================================================================================
;;///// globals.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;------------------------------------------------------------------
; use "iglobal" for inserting initialized global data definitions.
;------------------------------------------------------------------
macro iglobal
{
  IGlobals equ IGlobals,
  macro __IGlobalBlock
  \{
}

;-------------------------------------------------------------
; use 'uglobal' for inserting uninitialized global definitions.
; even when you define some data values, these variables
; will be stored as uninitialized data.
;-------------------------------------------------------------
macro uglobal
{
  UGlobals equ UGlobals,
  macro __UGlobalBlock
  \{
}

endg fix } ; Use endg for ending iglobal and uglobal blocks.

macro IncludeIGlobals
{
  macro IGlobals dummy, [n]
  \{
    __IGlobalBlock
    purge __IGlobalBlock
  \}
  match I, IGlobals
  \{
    I
  \}
}

macro IncludeUGlobals
{
  macro UGlobals dummy, [n]
  \{
    \common
      \local begin, size
      begin = $
      virtual at $
    \forward
      __UGlobalBlock
      purge __UGlobalBlock
    \common
      size = $ - begin
    end virtual
    rb size
  \}
  match U, UGlobals
  \{
    U
  \}
}

macro IncludeAllGlobals
{
  IncludeIGlobals
  IncludeUGlobals
}
 
iglobal
endg

uglobal
endg
