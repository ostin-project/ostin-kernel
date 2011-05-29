
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
