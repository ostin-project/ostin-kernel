;;======================================================================================================================
;;///// blitter.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 KolibriOS team <http://kolibrios.org/>
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

struct blitter_t
  dc     rect32_t
  sc     rect32_t
  dst    point32_t
  src    point32_t
  size   size32_t
  bitmap dd ?
  stride dd ?
ends

;-----------------------------------------------------------------------------------------------------------------------
kproc __L1OutCode ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebx
        mov     ebx, 8
        cmp     edx, [eax]
        jl      .L2
        xor     ebx, ebx
        cmp     edx, [eax + 8]
        setg    bl
        sal     ebx, 2

  .L2:
        cmp     ecx, [eax + 4]
        jge     .L3
        or      ebx, 1
        jmp     .L4

  .L3:
        cmp     ecx, [eax + 12]
        jle     .L4
        or      ebx, 2

  .L4:
        mov     eax, ebx
        pop     ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc block_clip ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp
        push    edi
        push    esi
        push    ebx
        sub     esp, 4

        mov     ebx, eax
        mov     [esp], edx
        mov     ebp, ecx
        mov     ecx, [ecx]
        mov     edx, [edx]
        mov     eax, ebx
        call    __L1OutCode

        mov     esi, eax
        mov     edx, [esp + 28]
        mov     ecx, [edx]

  .L21:
        mov     eax, [esp + 24]
        mov     edx, [eax]
        mov     eax, ebx
        call    __L1OutCode

        mov     edi, eax

  .L20:
        mov     eax, edi
        and     eax, esi
        jne     .L9
        cmp     esi, edi
        je      .L9
        test    esi, esi
        jne     .L10
        test    edi, 1
        je      .L11
        mov     eax, [ebx + 4]
        jmp     .L25

  .L11:
        test    edi, 2
        je      .L13
        mov     eax, [ebx + 12]

  .L25:
        mov     edx, [esp + 28]
        jmp     .L22

  .L13:
        test    edi, 4
        je      .L14
        mov     eax, [ebx + 8]
        jmp     .L26

  .L14:
        and     edi, 8
        je      .L12
        mov     eax, [ebx]

  .L26:
        mov     edx, [esp + 24]

  .L22:
        mov     [edx], eax

  .L12:
        mov     eax, [esp + 28]
        mov     ecx, [eax]
        jmp     .L21

  .L10:
        test    esi, 1
        je      .L16
        mov     eax, [ebx + 4]
        jmp     .L23

  .L16:
        test    esi, 2
        je      .L18
        mov     eax, [ebx + 12]

  .L23:
        mov     [ebp + 0], eax
        jmp     .L17

  .L18:
        test    esi, 4
        je      .L19
        mov     eax, [ebx + 8]
        jmp     .L24

  .L19:
        and     esi, 8
        je      .L17
        mov     eax, [ebx]

  .L24:
        mov     edx, [esp]
        mov     [edx], eax

  .L17:
        mov     ecx, [ebp + 0]
        mov     eax, [esp]
        mov     edx, [eax]
        mov     eax, ebx
        call    __L1OutCode
        mov     esi, eax
        jmp     .L20

  .L9:
        add     esp, 4
        pop     ebx
        pop     esi
        pop     edi
        pop     ebp
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blit_clip ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
.sx0 = 36
.sy0 = 32
.sx1 = 28
.sy1 = 24
.dx0 = 20
.dy0 = 16
.dx1 = 12
.dy1 = 8
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        push    esi
        push    ebx
        sub     esp, 40

        mov     ebx, ecx
        mov     edx, [ecx + blitter_t.src.x]
        mov     [esp + .sx0], edx
        mov     eax, [ecx + blitter_t.src.y]
        mov     [esp + .sy0], eax
        add     edx, [ecx + blitter_t.size.width]
        dec     edx
        mov     [esp + .sx1], edx
        add     eax, [ecx + blitter_t.size.height]
        dec     eax
        mov     [esp + .sy1], eax

        lea     ecx, [esp + .sy0]
        lea     edx, [esp + .sx0]
        lea     eax, [ebx + blitter_t.sc]
        lea     esi, [esp + .sy1]

        mov     [esp + 4], esi
        lea     esi, [esp + .sx1]
        mov     [esp], esi
        call    block_clip

        mov     esi, 1
        test    eax, eax
        jne     .L28

        mov     edi, [esp + .sx0]
        mov     edx, [ebx + blitter_t.dst.x]
        add     edx, edi
        sub     edx, [ebx + blitter_t.src.x]
        mov     [esp + .dx0], edx

        mov     ecx, [esp + .sy0]
        mov     eax, [ebx + blitter_t.dst.y]
        add     eax, ecx
        sub     eax, [ebx + blitter_t.src.y]
        mov     [esp + .dy0], eax
        sub     edx, edi
        add     edx, [esp + .sx1]
        mov     [esp + .dx1], edx

        sub     eax, ecx
        add     eax, [esp + .sy1]
        mov     [esp + .dy1], eax

        lea     ecx, [esp + .dy0]
        lea     edx, [esp + .dx0]
        lea     eax, [esp + .dy1]
        mov     [esp + 4], eax
        lea     eax, [esp + .dx1]
        mov     [esp], eax
        mov     eax, ebx
        call    block_clip
        test    eax, eax
        jne     .L28

        mov     edx, [esp + .dx0]
        mov     eax, [esp + .dx1]
        inc     eax
        sub     eax, edx
        mov     [ebx + blitter_t.size.width], eax

        mov     eax, [esp + .dy0]
        mov     ecx, [esp + .dy1]
        inc     ecx
        sub     ecx, eax
        mov     [ebx + blitter_t.size.height], ecx

        mov     ecx, [ebx + blitter_t.src.x]
        add     ecx, edx
        sub     ecx, [ebx + blitter_t.dst.x]
        mov     [ebx + blitter_t.src.x], ecx

        mov     ecx, [ebx + blitter_t.src.y]
        add     ecx, eax
        sub     ecx, [ebx + blitter_t.dst.y]
        mov     [ebx + blitter_t.src.y], ecx
        mov     [ebx + blitter_t.dst.x], edx
        mov     [ebx + blitter_t.dst.y], eax
        xor     esi, esi
.L28:
        mov     eax, esi
        add     esp, 40
        pop     ebx
        pop     esi
        pop     edi


purge .sx0
purge .sy0
purge .sx1
purge .sy1
purge .dx0
purge .dy0
purge .dx1
purge .dy1

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.blit_32 ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 73
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp
        push    edi
        push    esi
        push    ebx
        sub     esp, 72

        mov     eax, [TASK_BASE]
        mov     ebx, [eax - twdw + window_data_t.box.width]
        mov     edx, [eax - twdw + window_data_t.box.height]

        xor     eax, eax

        mov     [esp + blitter_t.dc.left], eax
        mov     [esp + blitter_t.dc.top], eax
        mov     [esp + blitter_t.dc.right], ebx
        mov     [esp + blitter_t.dc.bottom], edx

        mov     [esp + blitter_t.sc.left], eax
        mov     [esp + blitter_t.sc.top], eax
        mov     eax, [ecx + 24]
        dec     eax
        mov     [esp + blitter_t.sc.right], eax
        mov     eax, [ecx + 28]
        dec     eax
        mov     [esp + blitter_t.sc.bottom], eax

        mov     eax, [ecx]
        mov     [esp + blitter_t.dst.x], eax
        mov     eax, [ecx + 4]
        mov     [esp + blitter_t.dst.y], eax

        mov     eax, [ecx + 16]
        mov     [esp + blitter_t.src.x], eax
        mov     eax, [ecx + 20]
        mov     [esp + blitter_t.src.y], eax
        mov     eax, [ecx + 8]
        mov     [esp + blitter_t.size.width], eax
        mov     eax, [ecx + 12]
        mov     [esp + blitter_t.size.height], eax


        mov     eax, [ecx + 32]
        mov     [esp + 56], eax
        mov     eax, [ecx + 36]
        mov     [esp + 60], eax

        mov     ecx, esp
        call    blit_clip
        test    eax, eax
        jne     .L57

        inc     [mouse_pause]
        call    [_display.disable_mouse]

        mov     eax, [TASK_BASE]

        mov     ebx, [esp + blitter_t.dst.x]
        mov     ebp, [esp + blitter_t.dst.y]
        add     ebx, [eax - twdw + window_data_t.box.left]
        add     ebp, [eax - twdw + window_data_t.box.top]
        mov     edi, ebp

        imul    edi, [_display.pitch]
        imul    ebp, [_display.box.width]
        add     ebp, ebx
        add     ebp, [_WinMapAddress]

        mov     eax, [esp + blitter_t.src.y]
        imul    eax, [esp + blitter_t.stride]
        mov     esi, [esp + blitter_t.src.x]
        lea     esi, [eax + esi * 4]
        add     esi, [esp + blitter_t.bitmap]

        mov     ecx, [esp + blitter_t.size.height]
        mov     edx, [esp + blitter_t.size.width]

        test    ecx, ecx ; FIXME check clipping
        jz      .L57

        test    edx, edx
        jz      .L57

        cmp     [_display.bpp], 32
        jne     .core_24

        lea     edi, [edi + ebx * 4]

        mov     ebx, [CURRENT_TASK]

align 4
  .outer32:
        xor     ecx, ecx

align 4
  .inner32:
        cmp     [ebp + ecx], bl
        jne     @f

        mov     eax, [esi + ecx * 4]
        mov     [LFB_BASE + edi + ecx * 4], eax

    @@: inc     ecx
        dec     edx
        jnz     .inner32

        add     esi, [esp + blitter_t.stride]
        add     edi, [_display.pitch]
        add     ebp, [_display.box.width]

        mov     edx, [esp + blitter_t.size.width]
        dec     [esp + blitter_t.size.height]
        jnz     .outer32

  .done:
        dec     [mouse_pause]
        call    [draw_pointer]

  .L57:
        add     esp, 72
        pop     ebx
        pop     esi
        pop     edi
        pop     ebp
        ret

  .core_24:
        lea     ebx, [ebx + ebx * 2]
        lea     edi, [LFB_BASE + edi + ebx]
        mov     ebx, [CURRENT_TASK]

align 4
  .outer24:
        mov     [esp + 64], edi
        xor     ecx, ecx

align 4
  .inner24:
        cmp     [ebp + ecx], bl
        jne     @f

        mov     eax, [esi + ecx * 4]

        lea     edi, [edi + ecx * 2]
        mov     [edi + ecx], ax
        shr     eax, 16
        mov     [edi + ecx + 2], al

    @@: mov     edi, [esp + 64]
        inc     ecx
        dec     edx
        jnz     .inner24

        add     esi, [esp + blitter_t.stride]
        add     edi, [_display.pitch]
        add     ebp, [_display.box.width]

        mov     edx, [esp + blitter_t.size.width]
        dec     [esp + blitter_t.size.height]
        jnz     .outer24

        jmp     .done
kendp
