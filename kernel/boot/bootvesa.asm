;;======================================================================================================================
;;///// bootvesa.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2008 KolibriOS team <http://kolibrios.org/>
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

struct vbe_vga_info_t
  vesa_signature       dd ?   ; char
  vesa_version         dw ?   ; short
  oem_string_ptr       dd ?   ; char *
  capabilities         dd ?   ; ulong
  video_mode_ptr       dd ?   ; ulong
  total_memory         dw ?   ; short
  ; VBE 2.0+
  oem_software_rev     db ?   ; short
  oem_vendor_name_ptr  dw ?   ; char *
  oem_product_name_ptr dw ?   ; char *
  oem_product_rev_ptr  dw ?   ; char *
                       rb 222 ; char
  oem_data             rb 256 ; char
ends

struct vbe_mode_info_t
  mode_attributes            dw ?   ; short
  win_a_attributes           db ?   ; char
  win_b_attributes           db ?   ; char
  win_granularity            dw ?   ; short
  win_size                   dw ?   ; short
  win_a_segment              dw ?   ; ushort
  win_b_segment              dw ?   ; ushort
  win_func_ptr               dd ?   ; void *
  bytes_per_scanline         dw ?   ; short
  x_res                      dw ?   ; short
  y_res                      dw ?   ; short
  x_char_size                db ?   ; char
  y_char_size                db ?   ; char
  number_of_planes           db ?   ; char
  bits_per_pixel             db ?   ; char
  number_of_banks            db ?   ; char
  memory_model               db ?   ; char
  bank_size                  db ?   ; char
  number_of_image_pages      db ?   ; char
                             db ?   ; char
  red_mask_size              db ?   ; char
  red_field_position         db ?   ; char
  green_mask_size            db ?   ; char
  green_field_position       db ?   ; char
  blue_mask_size             db ?   ; char
  blue_field_position        db ?   ; char
  rsved_mask_size            db ?   ; char
  rsved_field_position       db ?   ; char
  direct_color_mode_info     db ?   ; char
  ; VBE 2.0+
  phys_base_ptr              dd ?   ; ulong
  offscreen_mem_offset       dd ?   ; ulong
  offscreen_mem_size         dw ?   ; short
  ; VBE 3.0+
  lin_bytes_per_scanline     dw ?   ; short
  bank_number_of_image_pages db ?   ; char
  lin_number_of_image_pages  db ?   ; char
  lin_red_mask_size          db ?   ; char
  lin_red_field_position     db ?   ; char
  lin_green_mask_size        db ?   ; char
  lin_green_field_position   db ?   ; char
  lin_blue_mask_size         db ?   ; char
  lin_blue_field_position    db ?   ; char
  lin_rsvd_mask_size         db ?   ; char
  lin_rsvd_field_position    db ?   ; char
  max_pixel_clock            dd ?   ; ulong
                             rb 190 ; char
ends

virtual at 0xa000
  vi vbe_vga_info_t
  mi vbe_mode_info_t

  modes_table:
end virtual

cursor_pos   dw 0 ; temporary cursor storage.
home_cursor  dw 0 ; current shows rows a table
end_cursor   dw 0 ; end of position current shows rows a table
scroll_start dw 0 ; start position of scroll bar
scroll_end   dw 0 ; end position of scroll bar

long_v_table     equ 9 ; long of visible video table
size_of_step     equ 10
scroll_area_size equ (long_v_table - 2)

;-----------------------------------------------------------------------------------------------------------------------
int2str: ;//////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        dec     bl
        jz      @f
        xor     edx, edx
        div     ecx
        push    edx
        call    int2str
        pop     eax

    @@: or      al, 0x30
        mov     [ds:di], al
        inc     di
        ret

;-----------------------------------------------------------------------------------------------------------------------
int2strnz: ;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, ecx
        jb      @f
        xor     edx, edx
        div     ecx
        push    edx
        call    int2strnz
        pop     eax

    @@: or      al, 0x30
        mov     [es:di], al
        inc     di
        ret

;-----------------------------------------------------------------------------------------------------------------------
v_mode_error: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Write message about incorrect v_mode and write message about jmp on swith v_mode
;-----------------------------------------------------------------------------------------------------------------------
;///        mov     dx, 2 * 256 + 19
;///        call    setcursor
        mov     si, fatalsel
        call    boot.print_string
;///        mov     dx, 2 * 256 + 20
;///        call    setcursor
        mov     si, pres_key
        call    boot.print_string
        xor     eax, eax
        int     0x16
;///        jmp     cfgmanager.print_menu

;///;-----------------------------------------------------------------------------------------------------------------------
;///print_vesa_info: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;///;-----------------------------------------------------------------------------------------------------------------------
;///        mov     dx, 2 * 256 + 5
;///        call    setcursor
;///
;///        mov     [es:vi.vesa_signature], 'VBE2'
;///        mov     ax, 0x4f00
;///        mov     di, vi ;0xa000
;///        int     0x10
;///        or      ah, ah
;///        jz      @f
;///        mov     [es:vi.vesa_signature], 'VESA'
;///        mov     ax, 0x4f00
;///        mov     di, vi
;///        int     0x10
;///        or      ah, ah
;///        jnz     .exit
;///
;///    @@: cmp     [es:vi.vesa_signature], 'VESA'
;///        jne     .exit
;///        cmp     [es:vi.vesa_version], 0x0100
;///        jb      .exit
;///        jmp     .vesaok2
;///
;///  .exit:
;///        mov     si, novesa
;///        call    boot.print_string
;///        ret
;///
;///  .vesaok2:
;///        mov     ax, [es:vi.vesa_version]
;///        add     ax, '00'
;///
;///        mov     [s_vesa.ver], ah
;///        mov     [s_vesa.ver + 2], al
;///        mov     si, s_vesa
;///        call    boot.print_string
;///
;///        mov     dx, 2 * 256 + 4
;///        call    setcursor
;///        mov     si, word[es:vi.oem_string_ptr]
;///        mov     di, si
;///
;///        push    ds
;///        mov     ds, word[es:vi.oem_string_ptr + 2]
;///        call    boot.print_string
;///        pop     ds
;///
;///        ret

;-----------------------------------------------------------------------------------------------------------------------
calc_vmodes_table: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushad

;       push    0
;       pop     es

        lfs     si, [es:vi.video_mode_ptr]

        mov     bx, modes_table
        ; save no vesa mode of work 320x200, EGA/CGA 256 colors and 640x480, VGA 16 colors
        mov     word[es:bx], 640
        mov     word[es:bx + 2], 480
        mov     word[es:bx + 6], 0x13

        mov     word[es:bx + 10], 640
        mov     word[es:bx + 12], 480
        mov     word[es:bx + 16], 0x12
        add     bx, 20

  .next_mode:
        mov     cx, word[fs:si] ; mode number
        cmp     cx, -1
        je      .modes_ok.2

        mov     ax, 0x4f01
        mov     di, mi
        int     0x10

        or      ah, ah
        jnz     .modes_ok.2 ; vesa_info.exit

        test    [es:mi.mode_attributes], 00000001b ; videomode support?
        jz      @f
        test    [es:mi.mode_attributes], 00010000b ; picture?
        jz      @f
        test    [es:mi.mode_attributes], 10000000b ; LFB?
        jz      @f

        cmp     [es:mi.bits_per_pixel], 24 ; It show only videomodes to have support 24 and 32 bpp
        jb      @f

;       cmp     [es:mi.bits_per_pixel], 16
;       jne     .l0
;       cmp     [es:mi.green_mask_size], 5
;       jne     .l0
;       mov     [es:mi.bits_per_pixel], 15


  .l0:
        cmp     [es:mi.x_res], 640
        jb      @f
        cmp     [es:mi.y_res], 480
        jb      @f
;       cmp     [es:mi.bits_per_pixel],8
;       jb      @f

        mov     ax, [es:mi.x_res]
        mov     [es:bx + 0], ax ; +0[2] : resolution X
        mov     ax, [es:mi.y_res]
        mov     [es:bx + 2], ax ; +2[2] : resolution Y
        mov     ax, [es:mi.mode_attributes]
        mov     [es:bx + 4], ax ; +4[2] : attributes

        cmp     [s_vesa.ver], '2'
        jb      .lp1

        or      cx, 0x4000 ; use LFB

  .lp1:
        mov     [es:bx + 6], cx ; +6 : mode number
        movzx   ax, [es:mi.bits_per_pixel]
        mov     word[es:bx + 8], ax ; +8 : bits per pixel
        add     bx, size_of_step ; size of record

    @@: add     si, 2
        jmp     .next_mode

  .modes_ok.2:
        mov     word[es:bx], -1 ; end video table
        mov     word[end_cursor], bx ; save end cursor position

        ; Sort array
;       mov     si, modes_table
;
; .new_mode:
;       mov     ax, word[es:si]
;       cmp     ax, -1
;       je      .exxit
;       add     ax, word[es:si + 2]
;       add     ax, word[es:si + 8]
;       mov     bp, si
;
; .again:
;       add     bp, 12
;       mov     bx, word[es:bp]
;       cmp     bx, -1
;       je      .exit
;       add     bx, word[es:bp + 2]
;       add     bx, word[es:bp + 8]
;
;       cmp     ax, bx
;       ja      .loops
;       jmp     .again
;
; .loops:
;       push    dword[es:si]
;       push    dword[es:si + 4]
;       push    dword[es:si + 8]
;       push    dword[es:bp]
;       push    dword[es:bp + 4]
;       push    dword[es:bp + 8]
;
;       pop     dword[es:si + 8]
;       pop     dword[es:si + 4]
;       pop     dword[es:si]
;       pop     dword[es:bp + 8]
;       pop     dword[es:bp + 4]
;       pop     dword[es:bp]
;       jmp     .new_mode
;
; .exit:
;       add     si, 12
;       jmp     .new_mode
;
; .exxit:

        popad
        ret

;-----------------------------------------------------------------------------------------------------------------------
draw_current_vmode: ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    0
        pop     es

        mov     si, word[cursor_pos]

        cmp     word[es:si + 6], 0x12
        je      .no_vesa_0x12

        cmp     word[es:si + 6], 0x13
        je      .no_vesa_0x13

;///        mov     di, loader_block_error
;///        movzx   eax, word[es:si + 0]
;///        mov     ecx, 10
;///        call    int2strnz
;///        mov     byte[es:di], 'x'
;///        inc     di
;///        movzx   eax, word[es:si + 2]
;///        call    int2strnz
;///        mov     byte[es:di], 'x'
;///        inc     di
;///        movzx   eax, word[es:si + 8]
;///        call    int2strnz
;///        mov     dword[es:di], 0x00000d0a
;///        mov     si, loader_block_error
;///        push    ds
;///        push    es
;///        pop     ds
;///        call    boot.print_string
;///        pop     ds
        ret

  .no_vesa_0x13:
        mov     si, boot.data.s_video_mode_0
        jmp     .print

  .no_vesa_0x12:
        mov     si, boot.data.s_video_mode_9

  .print:
        call    boot.print_string
        ret

;-----------------------------------------------------------------------------------------------------------------------
check_first_parm: ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     si, word[preboot_graph]
        test    si, si
        jnz     .no_zero ; if no zero

  .zerro:
;       mov     ax, modes_table
;       mov     word[cursor_pos], ax
;       mov     word[home_cursor], ax
;       mov     word[preboot_graph], ax

        ; SET default video of mode first probe will fined a move of work 1024x768@32
        mov     ax, 1024
        mov     bx, 768
        mov     si, modes_table
        call    .loops
        test    ax, ax
        jz     .ok_found_mode
        mov     ax, 800
        mov     bx, 600
        mov     si, modes_table
        call    .loops
        test    ax, ax
        jz     .ok_found_mode
        mov     ax, 640
        mov     bx, 480
        mov     si, modes_table
        call    .loops
        test    ax, ax
        jz     .ok_found_mode

        mov     si, modes_table
        jmp     .ok_found_mode

  .no_zero:
        mov     bp, word[number_vm]
        cmp     bp, word[es:si + 6]
        jz      .ok_found_mode
        mov     ax, word[x_save]
        mov     bx, word[y_save]
        mov     si, modes_table
        call    .loops
        test    ax, ax
        jz     .ok_found_mode

        mov     si, modes_table
;       cmp     ax, modes_table
;       jb      .zerro ; check on correct if bellow
;       cmp     ax, word[end_cursor]
;       ja      .zerro ; check on correct if anymore

  .ok_found_mode:
        mov     word[home_cursor], si
;       mov     word[cursor_pos], si
        mov     word[preboot_graph], si
        mov     ax, si

        mov     ecx, long_v_table

  .loop:
        add     ax, size_of_step
        cmp     ax, word[end_cursor]
        jae     .next_step
        loop    .loop

  .next_step:
        sub     ax, size_of_step * long_v_table
        cmp     ax, modes_table
        jae     @f
        mov     ax, modes_table

    @@: mov     word[home_cursor], ax
        mov     si, [preboot_graph]
        mov     word[cursor_pos], si

        push    word[es:si]
        pop     word[x_save]
        push    word[es:si + 2]
        pop     word[y_save]
        push    word[es:si + 6]
        pop     word[number_vm]

        ret

  .loops:
        cmp     ax, word[es:si]
        jne     .next
        cmp     bx, word[es:si + 2]
        jne     .next
        cmp     word[es:si + 8], 32
        je      .ok
        cmp     word[es:si + 8], 24
        je      .ok

  .next:
        add     si, size_of_step
        cmp     word[es:si], -1
        je      .exit
        jmp     .loops

  .ok:
        xor     ax, ax
        ret

  .exit:
        or      ax, -1
        ret

;-----------------------------------------------------------------------------------------------------------------------
draw_vmodes_table: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;///        mov     dx, 2 * 256 + 9
;///        call    setcursor
        mov     si, gr_mode
        call    boot.print_string

        mov     si, _st
        call    boot.print_string

        push    word[cursor_pos]
        pop     ax
        push    word[home_cursor]
        pop     si
        mov     cx, si

        cmp     ax, si
        je      .ok
        jb      .low


        add     cx, size_of_step * long_v_table

        cmp     ax, cx
        jb      .ok

        sub     cx, size_of_step * long_v_table
        add     cx, size_of_step
        cmp     cx, word[end_cursor]
        jae     .ok
        add     si, size_of_step
        push    si
        pop     word[home_cursor]
        jmp     .ok

  .low:
        sub     cx, size_of_step
        cmp     cx, modes_table
        jb      .ok
        push    cx
        push    cx
        pop     word[home_cursor]
        pop     si

  .ok:
        ; calculate scroll position
        push    si
        mov     ax, [end_cursor]
        sub     ax, modes_table
        mov     bx, size_of_step
        cwd
        div     bx
        mov     si, ax ; si = size of list
        mov     ax, [home_cursor]
        sub     ax, modes_table
        cwd
        div     bx
        mov     di, ax
        mov     ax, scroll_area_size * long_v_table
        cwd
        div     si
        test    ax, ax
        jnz     @f
        inc     ax

    @@: cmp     al, scroll_area_size
        jb      @f
        mov     al, scroll_area_size

    @@: mov     cx, ax
        ; cx = scroll height
        ; calculate scroll pos
        xor     bx, bx ; initialize scroll pos
        sub     al, scroll_area_size + 1
        neg     al
        sub     si, long_v_table - 1
        jbe     @f
        mul     di
        div     si
        mov     bx, ax

    @@: inc     bx
        imul    ax, bx, size_of_step
        add     ax, [home_cursor]
        mov     [scroll_start], ax
        imul    cx, size_of_step
        add     ax, cx
        mov     [scroll_end], ax
        pop     si
        mov     bp, long_v_table ; show rows

  ._next_bit:
        ; clear cursor
        mov     ax, '  '
        mov     word[ds:_r1 + 21], ax
        mov     word[ds:_r1 + 50], ax

        mov     word[ds:_r2 + 21], ax
        mov     word[ds:_r2 + 45], ax

        mov     word[ds:_rs + 21], ax
        mov     word[ds:_rs + 46], ax

        ; draw string
        cmp     word[es:si + 6], 0x12
        je      .show_0x12
        cmp     word[es:si + 6], 0x13
        je      .show_0x13

        movzx   eax, word[es:si]
        cmp     ax, -1
        je      ._end
        mov     di, _rs + 23
        mov     ecx, 10
        mov     bl, 4
        call    int2str
        movzx   eax, word[es:si + 2]
        inc     di
        mov     bl, 4
        call    int2str

        movzx   eax, word[es:si + 8]
        inc     di
        mov     bl, 2
        call    int2str

        cmp     si, word[cursor_pos]
        jne     .next

        ; draw cursor
        mov     word[ds:_rs + 21], '>>'
        mov     word[ds:_rs + 46], '<<'

  .next:
        push    si
        mov     si, _rs

  ._sh:
        ; add to the string pseudographics for scrollbar
        pop     bx
        push    bx
        mov     byte[si + 53], ' '
        cmp     bx, [scroll_start]
        jb      @f
        cmp     bx, [scroll_end]
        jae     @f
        mov     byte[si + 53], 0xdb ; filled bar

    @@: push    bx
        add     bx, size_of_step
        cmp     bx, [end_cursor]
        jnz     @f
        mov     byte[si + 53], 31 ; 'down arrow' symbol

    @@: sub     bx, [home_cursor]
        cmp     bx, size_of_step * long_v_table
        jnz     @f
        mov     byte[si + 53], 31 ; 'down arrow' symbol

    @@: pop     bx
        cmp     bx, [home_cursor]
        jnz     @f
        mov     byte[si + 53], 30 ; 'up arrow' symbol

    @@: call    boot.print_string
        pop     si
        add     si, size_of_step

        dec     bp
        jnz     ._next_bit

  ._end:
        mov     si, _bt
        call    boot.print_string
        ret

  .show_0x13:
        push    si

        cmp     si, word[cursor_pos]
        jne     @f
        mov     word[ds:_r1 + 21], '>>'
        mov     word[ds:_r1 + 50], '<<'

    @@: mov     si, _r1
        jmp     ._sh

  .show_0x12:
        push    si
        cmp     si, word[cursor_pos]
        jne     @f

        mov     word[ds:_r2 + 21], '>>'
        mov     word[ds:_r2 + 45], '<<'

    @@: mov     si, _r2
        jmp     ._sh

;-----------------------------------------------------------------------------------------------------------------------
clear_vmodes_table: ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Clear area of current video page (0xb800)
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        ; draw frames
        push    es
        push    0xb800
        pop     es
        mov     di, 1444
        xor     ax, ax
        mov     ah, 1 * 16 + 15
        mov     cx, 70
        mov     bp, 12

  .loop_start:
        rep     stosw
        mov     cx, 70
        add     di, 20
        dec     bp
        jns     .loop_start
        pop     es
        popa
        ret

;-----------------------------------------------------------------------------------------------------------------------
set_vmode: ;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    0 ; 0 ; x1000
        pop     es

        mov     si, word[preboot_graph] ; [preboot_graph]
        mov     cx, word[es:si + 6] ; number of mode


        mov     ax, word[es:si + 0] ; resolution X
        mov     bx, word[es:si + 2] ; resolution Y


        mov     [es:BOOT_X_RES], ax ; resolution X
        mov     [es:BOOT_Y_RES], bx ; resolution Y
        mov     [es:BOOT_VESA_MODE], cx ; number of mode

        cmp     cx, 0x12
        je      .mode0x12_0x13
        cmp     cx, 0x13
        je      .mode0x12_0x13

        cmp     byte[s_vesa.ver], '2'
        jb      .vesa12

        ; VESA 2 and Vesa 3
        mov     ax, 0x4f01
        and     cx, 0x0fff
        mov     di, mi ; 0xa000
        int     0x10
        ; LFB
        mov     eax, [es:mi.phys_base_ptr] ; di + 0x28]
        mov     [es:BOOT_LFB], eax
        ; ---- vbe voodoo
        BytesPerLine equ 0x10
        mov     ax, [es:di + BytesPerLine]
        mov     [es:BOOT_SCANLINE], ax
        ; BPP
        cmp     [es:mi.bits_per_pixel], 16
        jne     .l0
        cmp     [es:mi.green_mask_size], 5
        jne     .l0
        mov     [es:mi.bits_per_pixel], 15

  .l0:
        mov     al, byte[es:di + 0x19]
        mov     [es:BOOT_BPP], al
        jmp     .exit

  .mode0x12_0x13:
        mov     [es:BOOT_BPP], 32
        or      [es:BOOT_LFB], -1 ; 0x800000

  .vesa12:
        ;  VESA 1.2 PM BANK SWITCH ADDRESS
        mov     ax, 0x4f0a
        xor     bx, bx
        int     0x10
        xor     eax, eax
        xor     ebx, ebx
        mov     ax, es
        shl     eax, 4
        mov     bx, di
        add     eax, ebx
        movzx   ebx, word[es:di]
        add     eax, ebx
        push    0
        pop     es
        mov     [es:BOOT_BANK_SW], eax

  .exit:
        ret

;       mov     [es:BOOT_LFB], 0xa0000
;       ret
