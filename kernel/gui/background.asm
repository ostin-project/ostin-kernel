;;======================================================================================================================
;;///// background.asm ///////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

uglobal
  img_background         rd 1
  mem_BACKGROUND         rd 1
  static_background_data rd 1
  BgrDrawMode            dd ?
  BgrDataSize            size32_t
  bgrlockpid             dd ?
  bgrlock                db ?
  REDRAW_BACKGROUND      db ?
  BACKGROUND_CHANGED     db ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_background_ctl ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 39
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.get_background_ctl, subfn, sysfn.not_implemented, \
    get_size, \ ; 1
    get_pixel, \ ; 2
    -, \
    get_mode ; 4
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_background_ctl.get_size ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 39.1
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [BgrDataSize.width]
        shl     eax, 16
        mov     ax, word[BgrDataSize.height]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_background_ctl.get_pixel ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 39.2
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [img_background]
        test    ecx, ecx
        jz      @f
        cmp     eax, static_background_data
        jz      .exit

    @@: mov     ebx, [mem_BACKGROUND]
        add     ebx, 4095
        and     ebx, -4096
        sub     ebx, 4
        cmp     ecx, ebx
        ja      .exit

        mov     eax, [ecx + eax]

        and     eax, 0x00ffffff
        mov     [esp + 4 + regs_context32_t.eax], eax

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.get_background_ctl.get_mode ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 39.4
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [BgrDrawMode]
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_background_ctl ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 15
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.set_background_ctl, subfn, sysfn.not_implemented, \
    set_size, \ ; 1
    set_pixel, \ ; 2
    redraw, \ ; 3
    set_mode, \ ; 4
    put_pixel_block, \ ; 5
    map, \ ; 6
    unmap ; 7
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_background_ctl.set_size ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 15.1: set background image size
;-----------------------------------------------------------------------------------------------------------------------
        test    ecx, ecx
;       cmp     ecx, 0
        jz      .sbgrr
        test    edx, edx
;       cmp     edx, 0
        jz      .sbgrr

    @@: bts     dword[bgrlock], 0
        jnc     @f
        call    change_task
        jmp     @b

    @@: mov     [BgrDataSize.width], ecx
        mov     [BgrDataSize.height], edx
;       mov     [bgrchanged], 1

        pushad

        ; return memory for old background
        mov     eax, [img_background]
        cmp     eax, static_background_data
        jz      @f
        stdcall kernel_free, eax

    @@: ; calculate RAW size
        xor     eax, eax
        inc     eax
        cmp     [BgrDataSize.width], eax
        jae     @f
        mov     [BgrDataSize.width], eax

    @@: cmp     [BgrDataSize.height], eax
        jae     @f
        mov     [BgrDataSize.height], eax

    @@: mov     eax, [BgrDataSize.width]
        imul    eax, [BgrDataSize.height]
        lea     eax, [eax * 3]
        mov     [mem_BACKGROUND], eax
        ; get memory for new background
        stdcall kernel_alloc, eax
        test    eax, eax
        jz      .memfailed
        mov     [img_background], eax
        jmp     .exit

  .memfailed:
        ; revert to static monotone data
        mov     [img_background], static_background_data
        xor     eax, eax
        inc     eax
        mov     [BgrDataSize.width], eax
        mov     [BgrDataSize.height], eax
        mov     [mem_BACKGROUND], 4

  .exit:
        popad
        mov     [bgrlock], 0

  .sbgrr:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_background_ctl.set_pixel ;//////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 15.2: set background image pixel
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [img_background]
        test    ecx, ecx
        jz      @f
        cmp     eax, static_background_data
        jz      .exit

    @@: mov     ebx, [mem_BACKGROUND]
        add     ebx, 4095
        and     ebx, -4096
        sub     ebx, 4
        cmp     ecx, ebx
        ja      .exit

        mov     ebx, [eax + ecx]
        and     ebx, 0xff000000
        and     edx, 0x00ffffff
        add     edx, ebx
        mov     [eax + ecx], edx

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_background_ctl.redraw ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 15.3: redraw background
;-----------------------------------------------------------------------------------------------------------------------
        mov     [background_defined], 1
        mov     [BACKGROUND_CHANGED], 1
        call    force_redraw_background
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_background_ctl.set_mode ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 15.4: set background drawing mode
;-----------------------------------------------------------------------------------------------------------------------
        mov     [BgrDrawMode], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_background_ctl.put_pixel_block ;////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 15.5: copy pixel block to background image
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [img_background], static_background_data
        jnz     @f
        test    edx, edx
        jnz     .exit
        cmp     esi, 4
        ja      .exit

    @@: ; FIXME: bughere
        mov     eax, ecx
        mov     ebx, edx
        add     ebx, [img_background] ; IMG_BACKGROUND
        mov     ecx, esi
        call    memmove

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_background_ctl.map ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 15.6: map background data to process address space
;-----------------------------------------------------------------------------------------------------------------------
    @@: bts     dword[bgrlock], 0
        jnc     @f
        call    change_task
        jmp     @b

    @@: mov     eax, [CURRENT_TASK]
        mov     [bgrlockpid], eax
        cmp     [img_background], static_background_data
        jz      .nomem
        stdcall user_alloc, [mem_BACKGROUND]
        mov     [esp + 4 + regs_context32_t.eax], eax
        test    eax, eax
        jz      .nomem
        mov     ebx, eax
        shr     ebx, 12
        or      dword[page_tabs + (ebx - 1) * 4], DONT_FREE_BLOCK
        mov     esi, [img_background]
        shr     esi, 12
        mov     ecx, [mem_BACKGROUND]
        add     ecx, 0x0fff
        shr     ecx, 12

  .z:
        mov     eax, [page_tabs + ebx * 4]
        test    al, 1
        jz      @f
        call    free_page

    @@: mov     eax, [page_tabs + esi * 4]
        or      al, PG_UW
        mov     [page_tabs + ebx * 4], eax
        mov     eax, ebx
        shl     eax, 12
        invlpg  [eax]
        inc     ebx
        inc     esi
        loop    .z
        ret

  .nomem:
        and     [bgrlockpid], 0
        mov     [bgrlock], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.set_background_ctl.unmap ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 15.7: unmap background data from process address space
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [bgrlock], 0
        jz      .err
        mov     eax, [CURRENT_TASK]
        cmp     [bgrlockpid], eax
        jnz     .err
        mov     eax, ecx
        mov     ebx, ecx
        shr     eax, 12
        mov     ecx, [page_tabs + (eax - 1) * 4]
        test    cl, USED_BLOCK + DONT_FREE_BLOCK
        jz      .err
        jnp     .err
        push    eax
        shr     ecx, 12
        dec     ecx

    @@: and     dword[page_tabs + eax * 4], 0
        mov     edx, eax
        shl     edx, 12
        push    eax
        invlpg  [edx]
        pop     eax
        inc     eax
        loop    @b
        pop     eax
        and     dword[page_tabs + (eax - 1) * 4], not DONT_FREE_BLOCK
        stdcall user_free, ebx
        mov     [esp + 4 + regs_context32_t.eax], eax
        and     [bgrlockpid], 0
        mov     [bgrlock], 0
        ret

  .err:
        and     [esp + 4 + regs_context32_t.eax], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc calculatebackground ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, [_WinMapRange.address] ; set os to use all pixels
        mov     eax, 0x01010101
        mov     ecx, [_WinMapRange.size]
        shr     ecx, 2
        rep
        stosd

        mov     [REDRAW_BACKGROUND], 0 ; do not draw background!
        mov     [BACKGROUND_CHANGED], 0

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc drawbackground ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        inc     [mouse_pause]
        cmp     [SCR_MODE], 0x12
        je      .dbrv20

  .dbrv12:
        cmp     [SCR_MODE], 0100000000000000b
        jge     .dbrv20
        cmp     [SCR_MODE], 0x13
        je      .dbrv20
        call    vesa12_drawbackground
        dec     [mouse_pause]
        call    [draw_pointer]
        ret

  .dbrv20:
        cmp     [BgrDrawMode], 1
        jne     .bgrstr
        call    vesa20_drawbackground_tiled
        dec     [mouse_pause]
        call    [draw_pointer]
        ret

  .bgrstr:
        call    vesa20_drawbackground_stretch
        dec     [mouse_pause]
        call    [draw_pointer]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc force_redraw_background ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        and     [draw_data + sizeof.draw_data_t + draw_data_t.left], 0
        and     [draw_data + sizeof.draw_data_t + draw_data_t.top], 0
        push    eax ebx
        mov     eax, [Screen_Max_Pos.x]
        mov     ebx, [Screen_Max_Pos.y]
        mov     [draw_data + sizeof.draw_data_t + draw_data_t.right], eax
        mov     [draw_data + sizeof.draw_data_t + draw_data_t.bottom], ebx
        pop     ebx eax
        inc     [REDRAW_BACKGROUND]
        ret
kendp
