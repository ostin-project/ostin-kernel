;;======================================================================================================================
;;///// fdo.inc //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2007-2010 KolibriOS team <http://kolibrios.org/>
;; (c) 2005-2006 mike.dld <mike.dld@gmail.com>
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

; Available format specifiers are: %s, %d, %u, %x (with partial width support)

LOG_TRACE   = 1
LOG_DEBUG   = 2
LOG_LOG     = 3
LOG_WARNING = 4
LOG_ERROR   = 5
LOG_INFO    = 6
LOG_NONE    = 7

macro KLog.PrintString _sign, [_str]
{
  common
    local tp
    tp equ 0
    match _arg:_num, _str
    \{
      KLog.PrintStringWithWidth _sign, _num, _arg
      tp equ 1
    \}
    match =0 _arg, tp _str
    \{
      KLog.PrintStringWithWidth _sign, , _arg
    \}
}

macro KLog.PrintStringWithWidth _sign, _num, [_str]
{
  common
    pushad
    local ..str, ..label, is_str
    is_str = 0
  forward
    if _str eqtype ''
      is_str = 1
    end if
  common
    if is_str = 1
      jmp ..label
      ..str db _str, 0
      ..label:
      mov  edx, ..str
    else
      esp equ esp + 4 * 8 + add_esp@KLog
      mov  edx, _str
      restore esp
    end if
    if ~_num eq
      if _num eqtype eax
        if _num in <eax, ebx, ecx, edx, edi, ebp, esp>
          mov esi, _num
        else if ~_num eq esi
          movzx esi, _num
        end if
      else if _num eqtype 0
        mov esi, _num
      else
        local tp
        tp equ 0
        match [_arg], _num
        \{
          mov esi, dword[_arg]
          tp equ 1
        \}
        match =0 =dword[_arg], tp _num
        \{
          mov esi, dword[_arg]
          tp equ 1
        \}
        match =0 =word[_arg], tp _num
        \{
          movzx esi, word[_arg]
          tp equ 1
        \}
        match =0 =byte[_arg], tp _num
        \{
          movzx esi, byte[_arg]
          tp equ 1
        \}
        match =0, tp
        \{
          err 'Error: specified string width is incorrect'
        \}
      end if
    else
      mov esi, 0x7fffffff
    end if
    call fdo.debug_outstr
    popad
}

macro KLog.PrintDecNumber _sign, _dec
{
  local tp
  tp equ 0
  match _arg:_num, _dec
  \{
    KLog.PrintDecNumberWithWidth _sign, _num, _arg
    tp equ 1
  \}
  match =0 _arg, tp _dec
  \{
    KLog.PrintDecNumberWithWidth _sign, , _arg
  \}
}

macro KLog.PrintDecNumberWithWidth _sign, _num, _dec
{
  pushad
  if (~_num eq)
    if (_dec eqtype eax | _dec eqtype 0)
      err 'Error: precision allowed only for in-memory variables'
    end if
    if (~_num in <1, 2, 4>)
      err 'Error: 1, 2 and 4 are only allowed for precision in %d and %u'
    end if
  end if
  if _dec eqtype eax
    if _dec in <ebx, ecx, edx, esi, edi, ebp, esp>
      mov eax, _dec
    else if ~_dec eq eax
      if _sign = 1
        movsx eax, _dec
      else
        movzx eax, _dec
      end if
    end if
  else if _dec eqtype 0
    mov eax, _dec
  else
    esp equ esp + 4 * 8 + add_esp@KLog
    if _num eq
      mov eax, dword _dec
    else if _num = 1
      if _sign = 1
        movsx eax, byte _dec
      else
        movzx eax, byte _dec
      end if
    else if _num = 2
      if _sign = 1
        movsx eax, word _dec
      else
        movzx eax, word _dec
      end if
    else
      mov eax, dword _dec
    end if
    restore esp
  end if
  mov cl, _sign
  call fdo.debug_outdec
  popad
}

macro KLog.PrintHexNumber _sign, _hex
{
  local tp
  tp equ 0
  match _arg:_num, _hex
  \{
    KLog.PrintHexNumberWithWidth _sign, _num, _arg
    tp equ 1
  \}
  match =0 _arg, tp _hex
  \{
    KLog.PrintHexNumberWithWidth _sign, , _arg
  \}
}

macro KLog.PrintHexNumberWithWidth _sign, _num, _hex
{
  pushad
  if (~_num eq) & (~_num in <1, 2, 3, 4, 5, 6, 7, 8>)
    err 'Error: 1..8 are only allowed for precision in %x'
  end if
  if _hex eqtype eax
    if _hex in <eax, ebx, ecx, edx, esi, edi, ebp, esp>
      if ~_hex eq eax
        mov eax, _hex
      end if
      mov edx, 8
    else if _hex in <ax, bx, cx, dx, si, di, bp, sp>
      if ~_hex eq ax
        movzx eax, _hex
      end if
      if (_num eq)
        mov edx, 4
      end if
    else if _hex in <al, ah, bl, bh, cl, ch, dl, dh>
      if ~_hex eq al
        movzx eax, _hex
      end if
      if (_num eq)
        mov edx, 2
      end if
    end if
  else if _hex eqtype 0
    mov eax, _hex
  else
    esp equ esp + 4 * 8 + add_esp@KLog
    mov eax, dword _hex
    restore esp
  end if
  if ~_num eq
    mov edx, _num
  else
    if ~_hex eqtype eax
      mov edx, 8
    end if
  end if
  call fdo.debug_outhex
  popad
}

;-----------------------------------------------------------------------------

kproc fdo.debug_outchar
        pushad
        mov     bl, al
        mov     ecx, sysfn.debug_board.push_back
        call    ecx ; sysfn.debug_board
        popad
        ret
kendp

kproc fdo.debug_outstr
  .l1:
        dec     esi
        js      .l2
        mov     bl, [edx]
        or      bl, bl
        jz      .l2
        mov     ecx, sysfn.debug_board.push_back
        call    ecx ; sysfn.debug_board
        inc     edx
        jmp     .l1

  .l2:
        ret
kendp

kproc fdo.debug_outdec
        or      cl, cl
        jz      @f
        or      eax, eax
        jns     @f
        neg     eax
        push    eax
        mov     al, '-'
        call    fdo.debug_outchar
        pop     eax

    @@: push    10
        pop     ecx
        push    -'0'

  .l1:
        xor     edx, edx
        div     ecx
        push    edx
        test    eax, eax
        jnz     .l1

  .l2:
        pop     eax
        add     al, '0'
        jz      .l3
        call    fdo.debug_outchar
        jmp     .l2

  .l3:
        ret
kendp

if used __fdo_hexdigits
__fdo_hexdigits db '0123456789ABCDEF'
end if

kproc fdo.debug_outhex
        mov     cl, dl
        neg     cl
        add     cl, 8
        shl     cl, 2
        rol     eax, cl

  .l1:
        rol     eax, 4
        push    eax
        and     eax, 0x0f
        mov     al, [__fdo_hexdigits + eax]
        call    fdo.debug_outchar
        pop     eax
        dec     edx
        jnz     .l1
        ret
kendp

;-----------------------------------------------------------------------------

macro KLog.PrintNextPlainPart
{
  local p1, p2, c
  fmt_char@KLog = 0
  str_id@KLog equ str_id@KLog # c
  p1 = pos@KLog
  virtual at 0
    db fmt_str@KLog
    while pos@KLog < len@KLog
      load c from pos@KLog
      if c = '%'
        load c from pos@KLog + 1
        if c <> '%'
          fmt_char@KLog = c
          break
        end if
        pos@KLog = pos@KLog + 1
      end if
      pos@KLog = pos@KLog + 1
    end while
  end virtual
  p2 = pos@KLog
  if p2 - p1 > 0
    all_strs@KLog equ all_strs@KLog, str_id@KLog, <fmt_str@KLog>, p1, p2 - p1
    KLog.PrintString 0, str_id@KLog : p2 - p1
  end if
}

macro KLog.Print _format, [_arg]
{
  common
    fmt_str@KLog equ _format
    pos@KLog = 0
    virtual at 0
      db _format
      len@KLog = $
    end virtual
  forward
    KLog.PrintNextPlainPart
    if fmt_char@KLog
      if _arg eq
        err 'Error: less arguments than expected'
      end if
      pos@KLog = pos@KLog + 2
      if fmt_char@KLog = 's'
        KLog.PrintString 0, _arg
      else if fmt_char@KLog = 'x'
        KLog.PrintHexNumber 0, _arg
      else if fmt_char@KLog = 'd'
        KLog.PrintDecNumber 1, _arg
      else if fmt_char@KLog = 'u'
        KLog.PrintDecNumber 0, _arg
      else
        err 'Error: invalid format string'
      end if
    else
      if ~ _arg eq
        err 'Error: more arguments than expected'
      end if
    end if
  common
    KLog.PrintNextPlainPart
}

macro KLog.IncludeDebugStringsImpl _dummy, [_id, _fmt, _pos, _len] {
  common
    local p, l, c
  forward
    if defined _pos
      p = _pos
      l = _pos + _len
      _id:
      while p < l
        virtual at 0
          db _fmt, 0
          load c word from p
        end virtual
        if c = '\n'
          dw 0x0a0d
          p = p + 1
        else
          db c and 0xff
        end if
        p = p + 1
      end while
    end if
}

macro KLog.IncludeDebugStrings {
  match =1 _dbg_str, KCONFIG_DEBUG all_strs@KLog \{
    KLog.IncludeDebugStringsImpl _dbg_str
  \}
}

macro KLog _level, _format, [_args]
{
  common
    match =1, KCONFIG_DEBUG
    \{
      if _level >= KCONFIG_DEBUG_LEVEL
        pushfd
        cli
        add_esp@KLog equ 4
        KLog.Print <"K : ", _format>, _args
        restore add_esp@KLog
        popfd
      end if
   \}
}

macro KLog2 _level, _format, [_args]
{
  common
    match =1, KCONFIG_DEBUG
    \{
      if _level >= KCONFIG_DEBUG_LEVEL
        pushfd
        cli
        add_esp@KLog equ 4
        KLog.Print _format, _args
        restore add_esp@KLog
        popfd
      end if
    \}
}

macro ConditionalKLogBegin _name, _cond_var
{
  macro _name _level, _format, [_args]
  \{
    common
      match =1, _cond_var
      \\{
        KLog _level, _format, _args
      \\}
  \}
  macro _name#2 _level, _format, [_args]
  \{
    common
      match =1, _cond_var
      \\{
        KLog2 _level, _format, _args
      \\}
  \}
}

macro ConditionalKLogEnd _name
{
  purge _name#
  purge _name#2
}
