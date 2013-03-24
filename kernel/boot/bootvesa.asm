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

virtual at 0xa000
  vi vbe_vga_info_t
  mi vbe_mode_info_t

  modes_table:
end virtual

boot.data.vmodes_count dw ?

;-----------------------------------------------------------------------------------------------------------------------
kproc int2str ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        dec     bl
        jz      @f
        xor     edx, edx
        div     ecx
        push    edx
        call    int2str
        pop     eax

    @@: or      al, 0x30
        mov     [di], al
        inc     di
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc int2strnz ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, ecx
        jb      @f
        xor     edx, edx
        div     ecx
        push    edx
        call    int2strnz
        pop     eax

    @@: or      al, 0x30
        mov     [di], al
        inc     di
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.print_vmode_menu_item ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si ^= pointer to item title
;> cx #= item index
;> dx #= value index
;-----------------------------------------------------------------------------------------------------------------------
        cmp     cx, [boot.data.vmodes_count]
        jae     .exit

        push    es
        MovStk  es, 0

        mov     si, modes_table
        mov     ax, sizeof.boot_vmode_t
        mul     cx
        add     si, ax

        mov     di, boot.data.s_invalid_bootloader_data
        movzx   eax, [es:si + boot_vmode_t.resolution.width]
        mov     ecx, 10
        call    int2strnz
        mov     byte[di], 'x'
        inc     di
        movzx   eax, [es:si + boot_vmode_t.resolution.height]
        call    int2strnz
        mov     word[di], ', '
        add     di, 2
        movzx   eax, [es:si + boot_vmode_t.bits_per_pixel]
        call    int2strnz

        mov     cx, [es:si + boot_vmode_t.number]

        mov     byte[di], 0
        mov     si, boot.data.s_invalid_bootloader_data
        call    boot.print_string

        mov     si, boot.data.s_vmode_bpp
        call    boot.print_string

        mov     si, boot.data.s_vmode_vga_suffix
        cmp     cx, 0x12
        je      .print_suffix

        mov     si, boot.data.s_vmode_ega_suffix
        cmp     cx, 0x13
        je      .print_suffix

        mov     si, boot.data.s_vmode_vesa_suffix

  .print_suffix:
        call    boot.print_string

        pop     es

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.init_vesa_info ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        MovStk  es, 0

        mov     [es:vi.vesa_signature], 'VBE2'
        mov     ax, 0x4f00
        mov     di, vi ; 0xa000
        int     0x10
        or      ah, ah
        jz      @f

        mov     [es:vi.vesa_signature], 'VESA'
        mov     ax, 0x4f00
        mov     di, vi
        int     0x10
        or      ah, ah
        jnz     .error

    @@: cmp     [es:vi.vesa_signature], 'VESA'
        jne     .error
        cmp     [es:vi.vesa_version], 0x0100
        jae     .exit

  .error:
        mov     [es:vi.vesa_version], 0

  .exit:
        pop     es
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.init_vmodes_table ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        MovStk  es, 0

        mov     bx, modes_table

        mov     [es:bx + boot_vmode_t.resolution.width], 320
        mov     [es:bx + boot_vmode_t.resolution.height], 200
        mov     [es:bx + boot_vmode_t.number], 0x13
        mov     [es:bx + boot_vmode_t.bits_per_pixel], 8
        add     bx, sizeof.boot_vmode_t

        mov     [es:bx + boot_vmode_t.resolution.width], 640
        mov     [es:bx + boot_vmode_t.resolution.height], 480
        mov     [es:bx + boot_vmode_t.number], 0x12
        mov     [es:bx + boot_vmode_t.bits_per_pixel], 4
        add     bx, sizeof.boot_vmode_t

        lfs     si, [es:vi.video_mode_ptr]
        mov     [boot.data.vmodes_count], 2

  .check_mode:
        mov     cx, [fs:si] ; mode number
        cmp     cx, -1
        je      .finalize_modes_list

        mov     ax, 0x4f01
        mov     di, mi
        int     0x10

        or      ah, ah
        jnz     .finalize_modes_list

        test    [es:mi.mode_attributes], 00000001b ; videomode support?
        jz      .next_mode
        test    [es:mi.mode_attributes], 00010000b ; picture?
        jz      .next_mode
        test    [es:mi.mode_attributes], 10000000b ; LFB?
        jz      .next_mode
        cmp     [es:mi.bits_per_pixel], 24 ; show modes with 24 and 32 bpp only
        jb      .next_mode

;       cmp     [es:mi.bits_per_pixel], 16
;       jne     .l0
;       cmp     [es:mi.green_mask_size], 5
;       jne     .l0
;       mov     [es:mi.bits_per_pixel], 15
;
; .l0:
        mov     ax, [es:mi.x_res]
        cmp     ax, 640
        jb      .next_mode
        mov     dx, [es:mi.y_res]
        cmp     dx, 480
        jb      .next_mode

        cmp     [es:vi.vesa_version + 1], 2
        jb      .add_mode_to_list

        or      cx, 0x4000 ; use LFB

  .add_mode_to_list:
        mov     [es:bx + boot_vmode_t.resolution.width], ax
        mov     [es:bx + boot_vmode_t.resolution.height], dx
        MovStk  [es:bx + boot_vmode_t.attributes], [es:mi.mode_attributes]
        mov     [es:bx + boot_vmode_t.number], cx
        movzx   ax, [es:mi.bits_per_pixel]
        mov     [es:bx + boot_vmode_t.bits_per_pixel], ax

        add     bx, sizeof.boot_vmode_t ; size of record
        inc     [boot.data.vmodes_count]

  .next_mode:
        add     si, 2
        jmp     .check_mode

  .finalize_modes_list:
        mov     [es:bx + boot_vmode_t.resolution.width], -1 ; end video table

        ; Sort array
        mov     si, modes_table

  .calc_outer_mode:
        mov     ax, [es:si + boot_vmode_t.resolution.width]
        inc     ax
        jz      .exit
        add     ax, [es:si + boot_vmode_t.resolution.height]
        add     ax, [es:si + boot_vmode_t.bits_per_pixel]
        mov     di, si

  .next_inner_mode:
        add     di, sizeof.boot_vmode_t
        mov     bx, [es:di + boot_vmode_t.resolution.width]
        inc     bx
        jz      .next_outer_mode
        add     bx, [es:di + boot_vmode_t.resolution.height]
        add     bx, [es:di + boot_vmode_t.bits_per_pixel]

        cmp     ax, bx
        ja      .exchange_modes
        jmp     .next_inner_mode

  .exchange_modes:

repeat sizeof.boot_vmode_t / 4

        XchgStk dword[es:si + (% - 1) * 4], \
                dword[es:di + (% - 1) * 4]

end repeat

repeat (sizeof.boot_vmode_t mod 4) / 2

        XchgStk word[es:si + sizeof.boot_vmode_t / 4 * 4 + (% - 1) * 2], \
                word[es:di + sizeof.boot_vmode_t / 4 * 4 + (% - 1) * 2]

end repeat

        jmp     .calc_outer_mode

  .next_outer_mode:
        add     si, sizeof.boot_vmode_t
        jmp     .calc_outer_mode

  .exit:
        pop     es
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.load_vmode_to_menu ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        MovStk  es, 0

        cmp     [boot.params.vmode.resolution.width], -1
        jne     .check_saved_mode

        ; SET default video of mode first probe will fined a move of work 1024x768@32
        mov     ax, 1024
        mov     bx, 768
        or      cx, -1
        call    .find_mode
        jnc     .saved_mode_found
        mov     ax, 800
        mov     bx, 600
        call    .find_mode
        jnc     .saved_mode_found
        mov     ax, 640
        mov     bx, 480
        call    .find_mode
        jnc     .saved_mode_found

        jmp     .saved_mode_not_found

  .check_saved_mode:
        mov     ax, [boot.params.vmode.resolution.width]
        mov     bx, [boot.params.vmode.resolution.height]
        mov     cx, [boot.params.vmode.bits_per_pixel]
        call    .find_mode
        jnc     .saved_mode_found

  .saved_mode_not_found:
        mov     si, modes_table

  .saved_mode_found:
        mov     ax, si
        sub     ax, modes_table
        xor     dx, dx
        mov     cx, sizeof.boot_vmode_t
        div     cx
        mov     [boot.data.video_mode_menu + boot_menu_data_t.current_index], ax

        mov     di, boot.params.vmode
        XchgStk es, ds
        mov     cx, sizeof.boot_vmode_t / 2
        rep
        movsw
        MovStk  ds, es

        pop     es
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .find_mode: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
;> ax #= width
;> bx #= height
;> cx #= bpp or -1 (any)
;-----------------------------------------------------------------------------------------------------------------------
        mov     si, modes_table

  .check_mode:
        cmp     [es:si + boot_vmode_t.resolution.width], -1
        je      .mode_not_found

        cmp     ax, [es:si + boot_vmode_t.resolution.width]
        jne     .next_mode
        cmp     bx, [es:si + boot_vmode_t.resolution.height]
        jne     .next_mode
        or      cx, cx
        js      .mode_found
        cmp     cx, [es:si + boot_vmode_t.bits_per_pixel]
        je      .mode_found

  .next_mode:
        add     si, sizeof.boot_vmode_t
        jmp     .check_mode

  .mode_found:
        clc
        ret

  .mode_not_found:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.save_vmode_from_menu ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        MovStk  es, 0

        mov     si, modes_table
        mov     ax, sizeof.boot_vmode_t
        mul     [boot.data.video_mode_menu + boot_menu_data_t.current_index]
        add     si, ax

        mov     di, boot.params.vmode
        XchgStk es, ds
        mov     cx, sizeof.boot_vmode_t / 2
        rep
        movsw
        MovStk  ds, es

        pop     es
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.set_vmode_boot_vars ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        MovStk  es, 0 ; 0x1000

        mov     cx, [boot.params.vmode.number]
        mov     [es:boot_var.low.vesa_mode], cx

        cmp     cx, 0x12
        je      .mode_x12_x13
        cmp     cx, 0x13
        je      .mode_x12_x13

        MovStk  [es:boot_var.low.screen_res.width], [boot.params.vmode.resolution.width]
        MovStk  [es:boot_var.low.screen_res.height], [boot.params.vmode.resolution.height]

        cmp     byte[es:vi.vesa_version + 1], 2
        jb      .vesa12

        ; VESA 2+
        mov     ax, 0x4f01
        and     cx, 0x0fff
        mov     di, mi ; 0xa000
        int     0x10
        MovStk  [es:boot_var.low.vesa_20_lfb_addr], [es:mi.phys_base_ptr]
        MovStk  [es:boot_var.low.scanline_len], [es:mi.bytes_per_scanline]
        mov     al, [es:mi.bits_per_pixel]
;       cmp     al, 16
;       jne     @f
;       cmp     [es:mi.green_mask_size], 5
;       jne     @f
;       mov     al, 15
;
;   @@:
        mov     [es:boot_var.low.bpp], al
        jmp     .exit

  .mode_x12_x13:
        mov     [es:boot_var.low.screen_res.width], 640
        mov     [es:boot_var.low.screen_res.height], 480
        mov     [es:boot_var.low.bpp], 32
        or      [es:boot_var.low.vesa_20_lfb_addr], -1

  .vesa12:
        ;  VESA 1.2 PM BANK SWITCH ADDRESS
        mov     ax, 0x4f0a
        xor     bx, bx
        int     0x10
        xor     eax, eax
        mov     ax, es
        shl     eax, 4
        movzx   ebx, di
        add     eax, ebx
        movzx   ebx, word[es:di]
        add     eax, ebx
        mov     [es:boot_var.low.vesa_12_bank_sw], eax

  .exit:
        pop     es
        ret
kendp
