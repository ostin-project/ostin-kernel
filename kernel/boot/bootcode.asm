;;======================================================================================================================
;;///// bootcode.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
;; (c) 2000-2004 MenuetOS <http://menuetos.net/>
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

include "bootcode.inc"

match =en, KCONFIG_LANGUAGE
{
  include "boot_en.asm"
}
match =ru, KCONFIG_LANGUAGE
{
  include "boot_ru.asm"
}
match =et, KCONFIG_LANGUAGE
{
  include "boot_et.asm"
}
match =ge, KCONFIG_LANGUAGE
{
  include "boot_ge.asm"
}

include "bootmenu.asm"
include "bootvesa.asm"
include "charset16.asm"

;-----------------------------------------------------------------------------------------------------------------------
boot.print_char: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> al = character
;-----------------------------------------------------------------------------------------------------------------------
        push    ax bx
        mov     ah, 0x0e
        mov     bh, 0
        int     0x10
        pop     bx ax
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.print_string: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si = string
;-----------------------------------------------------------------------------------------------------------------------
;< al = 0
;-----------------------------------------------------------------------------------------------------------------------
        pusha

    @@: call    charset16.utf8_char_to_ansi
        test    al, al
        jz      @f
        call    boot.print_char
        jmp     @b

    @@: popa
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.print_crlf: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ax
        mov     al, 13
        call    boot.print_char
        mov     al, 10
        call    boot.print_char
        pop     ax
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.print_horz_line: ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, '-'
        mov     cx, 80

    @@: call    boot.print_char
        loop    @b

        ret

;-----------------------------------------------------------------------------------------------------------------------
getkey: ;///////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? get number in range [bl,bh] (bl,bh in ['0'..'9'])
;-----------------------------------------------------------------------------------------------------------------------
;> bx = range
;-----------------------------------------------------------------------------------------------------------------------
;< ax = digit (1..9, 10 for 0)
;-----------------------------------------------------------------------------------------------------------------------
        mov     ah, 0
        int     0x16
        cmp     al, bl
        jb      getkey
        cmp     al, bh
        ja      getkey
        push    ax
        call    boot.print_char
        pop     ax
        and     ax, 0x0f
        jnz     @f
        mov     al, 10

    @@: ret

;-----------------------------------------------------------------------------------------------------------------------
setcursor: ;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> dl = row
;> dh = column
;-----------------------------------------------------------------------------------------------------------------------
        push    ax bx
        mov     ah, 2
        mov     bh, 0
        xchg    dl, dh
        int     0x10
        pop     bx ax
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot_read_floppy: ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    si
        xor     si, si
        mov     ah, 2 ; read

    @@: push    ax
        int     0x13
        pop     ax
        jnc     @f
        inc     si
        cmp     si, 10
        jb      @b
        mov     si, boot.data.s_bad_sector
        jmp     boot.error

    @@: pop     si
        ret

;-----------------------------------------------------------------------------------------------------------------------
conv_abs_to_THS: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert abs. sector number to BIOS T:H:S
;-----------------------------------------------------------------------------------------------------------------------
;> ax = sector number
;-----------------------------------------------------------------------------------------------------------------------
;< cl = sector number
;< ch = track number
;< dl = drive number (0 = a:)
;< dh = head number
;-----------------------------------------------------------------------------------------------------------------------
;# sector number = (abs.sector % BPB_SecPerTrk) + 1
;# pre.track number = abs.sector / BPB_SecPerTrk
;# head number = pre.track number % BPB_NumHeads
;# track number = pre.track number / BPB_NumHeads
;-----------------------------------------------------------------------------------------------------------------------
        push    bx
        mov     bx, word[BPB_SecPerTrk]
        xor     dx, dx
        div     bx
        inc     dx
        mov     cl, dl ; cl = sector number
        mov     bx, word[BPB_NumHeads]
        xor     dx, dx
        div     bx
        ; !!!!!!! ax = track number, dx = head number
        mov     ch, al ; ch = track number
        xchg    dh, dl ; dh = head number
        mov     dl, 0 ; dl = 0 (drive 0 (a:))
        pop     bx
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.error: ;///////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si = pointer to error message
;-----------------------------------------------------------------------------------------------------------------------
        push    si
        call    boot.print_crlf
        mov     si, boot.data.s_error
        call    boot.print_string
        pop     si
        call    boot.print_string
        mov     dx, 0 * 256 + 25
        call    setcursor
        jmp     $

;-----------------------------------------------------------------------------------------------------------------------
boot.clear_screen: ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> di = offset (in chars)
;> cx = count (in chars)
;-----------------------------------------------------------------------------------------------------------------------
        push    es ax cx
        push    0xb800
        pop     es

        mov     ax, 0x0720 ; pack[4(bg color), 4(fg color), 8(char)]
        shl     di, 1
        rep     stosw

        pop     cx ax es
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.get_time: ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ah, 0
        int     0x1a
        xchg    ax, cx
        shl     eax, 16
        xchg    ax, dx
        ret

;-----------------------------------------------------------------------------------------------------------------------
boot.start: ;///////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cld
        ; if bootloader sets ax = 'KL', then ds:si points to loader block
        cmp     ax, 'KL'
        jnz     @f
        mov     word[cs:boot.data.loader_block], si
        mov     word[cs:boot.data.loader_block + 2], ds

    @@: ; if bootloader sets cx = 'HA' and dx = 'RD', then bx contains identifier of source hard disk
        ; (see comment to bx_from_load)
        cmp     cx, 'HA'
        jnz     .no_hd_load
        cmp     dx, 'RD'
        jnz     .no_hd_load
        mov     word[cs:bx_from_load], bx

  .no_hd_load:
        ; set up stack
        mov     ax, 0x3000
        mov     ss, ax
        mov     sp, 0xec00
        ; set up segment registers
        push    cs
        pop     ds
        push    cs
        pop     es

        ; set videomode
        mov     ax, 3
        int     0x10

if defined boot.init_l10n

        call    boot.init_l10n

end if

        ; hide cursor
        mov     ah, 1
        mov     ch, 0x20
        int     0x10

        ; clear screen
        push    es
        push    0xb800
        pop     es
        mov     ax, 0x0a20 ; pack[4(bg color), 4(fg color), 8(char)]
        mov     cx, 80 * (boot.data.s_logo.height + 2)
        xor     di, di
        rep     stosw
        mov     ax, 0x8b20
        mov     cx, 80 * 1
        rep     stosw
        mov     ax, 0x0720
        mov     cx, 80 * (25 - boot.data.s_logo.height - 4)
        rep     stosw
        mov     ax, 0x8020
        mov     cx, 80 * 1
        rep     stosw
        pop     es

        ; print header
;///        mov     dx, 0 * 256 + 0
        mov     dx, 0 * 256 + 1
        call    setcursor
;///        call    boot.print_horz_line

        mov     si, boot.data.s_logo
        call    boot.print_string

;///        call    boot.print_crlf
;///        call    boot.print_horz_line

        mov     dx, (boot.data.s_logo.width + 1) * 256 + 1
        call    setcursor
        mov     si, boot.data.s_copyright_1
        call    boot.print_string
        mov     dx, (boot.data.s_logo.width + 1) * 256 + 2
        call    setcursor
        mov     si, boot.data.s_copyright_2
        call    boot.print_string
        mov     dx, (boot.data.s_logo.width + 1) * 256 + 3
        call    setcursor
        mov     si, boot.data.s_copyright_3
        call    boot.print_string

;///        mov     dx, 0 * 256 + 4
        mov     dx, 1 * 256 + boot.data.s_logo.height + 2
        call    setcursor
;///        call    boot.print_horz_line

        mov     si, boot.data.s_version
        call    boot.print_string
        mov     si, boot.data.s_version_number
        call    boot.print_string
        mov     si, boot.data.s_license
        call    boot.print_string

        mov     dx, 1 * 256 + 24
        call    setcursor
        mov     si, boot.data.s_keys_notice
        call    boot.print_string

;///        call    boot.print_crlf
;///        call    boot.print_horz_line

        ; TEST FOR 386+
        mov     bx, 0x4000
        pushf
        pop     ax
        mov     dx, ax
        xor     ax, bx
        push    ax
        popf
        pushf
        pop     ax
        and     ax, bx
        and     dx, bx
        cmp     ax, dx
        jnz     .cpugood

        mov     si, boot.data.s_incompatible_cpu
        jmp     boot.error

  .cpugood:
        push    0
        popf
        sti

        ; set up esp
        movzx   esp, sp

        push    0
        pop     es
        and     [es:BOOT_IDE_BASE_ADDR], 0

        ; find HDD IDE DMA PCI device
        ; check for PCI BIOS
        mov     ax, 0xb101
        int     0x1a
        jc      .nopci
        cmp     edx, 'PCI '
        jnz     .nopci
        ; find PCI class code
        ; class 1 = mass storage
        ; subclass 1 = IDE controller
        ; a) class 1, subclass 1, programming interface 0x80
        mov     ax, 0xb103
        mov     ecx, 1 * 0x10000 + 1 * 0x100 + 0x80
        xor     si, si ; device index = 0
        int     0x1a
        jnc     .found
        ; b) class 1, subclass 1, programming interface 0x8A
        mov     ax, 0xb103
        mov     ecx, 1 * 0x10000 + 1 * 0x100 + 0x8a
        xor     si, si ; device index = 0
        int     0x1a
        jnc     .found
        ; c) class 1, subclass 1, programming interface 0x85
        mov     ax, 0xb103
        mov     ecx, 1 * 0x10000 + 1 * 0x100 + 0x85
        xor     si, si
        int     0x1a
        jc      .nopci

  .found:
        ; get memory base
        mov     ax, 0xb10a
        mov     di, 0x20 ; memory base is config register at 0x20
        int     0x1a
        jc      .nopci
        and     cx, 0xfff0 ; clear address decode type
        mov     [es:BOOT_IDE_BASE_ADDR], cx

  .nopci:
        mov     al, 0xf6 ; reset keyboard, allow scanning
        out     0x60, al
        xor     cx, cx

  .wait_loop: ; variant 2
        ; reading state of port of 8042 controller
        in      al, 0x64
        and     al, 00000010b ; ready flag
        ; wait until 8042 controller is ready
        loopnz  .wait_loop

        ; set keyboard typematic rate & delay
        mov     al, 0xf3
        out     0x60, al
        xor     cx, cx

    @@: in      al, 0x64
        test    al, 2
        loopnz  @b
        mov     al, 0
        out     0x60, al
        xor     cx, cx

    @@: in      al, 0x64
        test    al, 2
        loopnz  @b

        ; --------------- APM ---------------------
        and     [es:BOOT_APM_VERSION], 0 ; ver = 0.0 (APM not found)
        mov     ax, 0x5300
        xor     bx, bx
        int     0x15
        jc      .apm_end ; APM not found
        test    cx, 2
        jz      .apm_end ; APM 32-bit protected-mode interface not supported
        mov     [es:BOOT_APM_VERSION], ax ; Save APM Version
        mov     [es:BOOT_APM_FLAGS], cx ; Save APM flags

;///        ; Write APM ver ----
;///        and     ax, 0x0f0f
;///        add     ax, '00'
;///        mov     si, msg_apm
;///        mov     [si + 5], ah
;///        mov     [si + 7], al
;///        mov     dx, 3 * 256 + 0
;///        call    setcursor
;///        call    printplain
;///        ; ------------------

        mov     ax, 0x5304 ; Disconnect interface
        xor     bx, bx
        int     0x15
        mov     ax, 0x5303 ; Connect 32 bit mode interface
        xor     bx, bx
        int     0x15

        mov     [es:BOOT_APM_ENTRY_OFS], ebx
        mov     [es:BOOT_APM_CODE32_SEG], ax
        mov     [es:BOOT_APM_CODE16_SEG], cx
        mov     [es:BOOT_APM_DATA16_SEG], dx

  .apm_end:
;///        mov     dx, 0 * 256 + d80x25_top_num
;///        call    setcursor

        ; CHECK current of code
        cmp     [boot.data.loader_block], -1
        jz      .noloaderblock
        les     bx, [boot.data.loader_block]
        cmp     byte[es:bx], 1
        mov     si, boot.data.s_invalid_bootloader_data
        jnz     boot.error
        push    0
        pop     es

  .noloaderblock:
        ; DISPLAY VESA INFORMATION
;///        call    print_vesa_info
        call    calc_vmodes_table
        call    check_first_parm ; check and enable cursor_pos

cfgmanager:
        ; settings:
        ; a) preboot_graph = graphical mode
        ;    preboot_gprobe = probe this mode?
        ; b) preboot_dma  = use DMA access?
        ; c) preboot_vrrm = use VRR?
        ; d) preboot_device = from what boot?

        ; determine default settings
        mov     [boot.data.settings_changed], 0

; .preboot_gr_end:
        mov     di, preboot_device
        ; if image in memory is present and [preboot_device] is uninitialized,
        ; set it to use this preloaded image
        cmp     byte[di], -1
        jne     .preboot_device_inited
        cmp     [boot.data.loader_block], -1
        jz      @f
        les     bx, [boot.data.loader_block]
        test    byte[es:bx + 1], 1
        jz      @f
        mov     byte[di], 2
        jmp     .preboot_device_inited

    @@: ; otherwise, set [preboot_device] to 1 (default value - boot from floppy)
        mov     byte[di], 0

  .preboot_device_inited:
        ; following 4 lines set variables to 1 if its current value is 0
        cmp     byte[di + preboot_dma - preboot_device], 1
        adc     byte[di + preboot_dma - preboot_device], 0
        cmp     byte[di + preboot_biosdisk - preboot_device], 1
        adc     byte[di + preboot_biosdisk - preboot_device], 0
        ; default value for VRR is OFF
        cmp     byte[di + preboot_vrrm - preboot_device], 0
        jnz     @f
        mov     byte[di + preboot_vrrm - preboot_device], 2

    @@: ; enable timeout for the first time
        or      al, 1

  .run_main_menu:
        mov     bx, boot.data.main_menu
        call    boot.run_menu

        ; cancel? not possible with main menu
        cmp     al, 1
        xchg    al, ah ; disable timeout
        je      .run_main_menu

;///;///        mov     ax, boot.data.main_menu_options
;///;///        mov     bx, boot.print_settings_value
;///;///        mov     cx, boot.data.s_current_settings
;///;///        call    boot.print_options
;///
;///        ; wait for keypressed
;///        xor     ax, ax
;///        int     0x16
;///
;///        push    ax
;///        mov     ax, 0x0a20
;///        mov     bx, 0x0007
;///        mov     cx, 1
;///        int     0x10
;///        pop     ax
;///
;///        jmp     .first_key
;///
;///  .print_menu:
;///        mov     [boot.data.settings_changed], 1
;///
;///;///        mov     ax, boot.data.main_menu_options
;///;///        mov     bx, boot.print_settings_value
;///;///        mov     cx, boot.data.s_current_settings
;///;///        call    boot.print_options
;///
;///  .read_key:
;///        ; wait for keypressed
;///        xor     ax, ax
;///        int     0x16
;///
;///  .first_key:
;///        ; switch on key
;///        cmp     al, 13
;///        jz      .continue
;///        cmp     al, '1'
;///        jz      .change_video_mode
;///        cmp     al, '2'
;///        jz      .change_use_bios_disks
;///        cmp     al, '3'
;///        jz      .change_use_vrr
;///        cmp     al, '4'
;///        jz      .change_boot_source
;///        jmp     .read_key
;///
;///  .change_video_mode:
;///;///  .loops:
;///;///        call    draw_vmodes_table
;///;///        xor     ax, ax
;///;///        int     0x16
;///;///
;///;///        mov     si, word[cursor_pos]
;///;///
;///;///        cmp     ah, 0x48 ; x, 0x48e0 ; up
;///;///        jne     .down
;///;///        cmp     si, modes_table
;///;///        jbe     .loops
;///;///        sub     word[cursor_pos], size_of_step
;///;///        jmp     .loops
;///;///
;///;///  .down:
;///;///        cmp     ah, 0x50 ; x, 0x50e0 ; down
;///;///        jne     .pgup
;///;///        cmp     word[es:si + 10], -1
;///;///        je      .loops
;///;///        add     word[cursor_pos], size_of_step
;///;///        jmp     .loops
;///;///
;///;///  .pgup:
;///;///        cmp     ah, 0x49 ; page up
;///;///        jne     .pgdn
;///;///        sub     si, size_of_step * long_v_table
;///;///        cmp     si, modes_table
;///;///        jae     @f
;///;///        mov     si, modes_table
;///;///
;///;///    @@: mov     word[cursor_pos], si
;///;///        mov     si, word[home_cursor]
;///;///        sub     si, size_of_step * long_v_table
;///;///        cmp     si, modes_table
;///;///        jae     @f
;///;///        mov     si, modes_table
;///;///
;///;///    @@: mov     word[home_cursor], si
;///;///        jmp     .loops
;///;///
;///;///  .pgdn:
;///;///        cmp     ah, 0x51 ; page down
;///;///        jne     .enter
;///;///        mov     ax, [end_cursor]
;///;///        add     si, size_of_step * long_v_table
;///;///        cmp     si, ax
;///;///        jb      @f
;///;///        mov     si, ax
;///;///        sub     si, size_of_step
;///;///
;///;///    @@: mov     word[cursor_pos], si
;///;///        mov     si, word[home_cursor]
;///;///        sub     ax, size_of_step * long_v_table
;///;///        add     si, size_of_step * long_v_table
;///;///        cmp     si, ax
;///;///        jb      @f
;///;///        mov     si, ax
;///;///
;///;///    @@: mov     word[home_cursor], si
;///;///        jmp     .loops
;///;///
;///;///  .enter:
;///;///        cmp     al, 0x0d ; x, 0x1C0D ; enter
;///;///        jne     .loops
;///;///        push    word[cursor_pos]
;///;///        pop     bp
;///;///        push    word[es:bp]
;///;///        pop     word[x_save]
;///;///        push    word[es:bp + 2]
;///;///        pop     word[y_save]
;///;///        push    word[es:bp + 6]
;///;///        pop     word[number_vm]
;///;///        mov     word[preboot_graph], bp ; save choose
;///        jmp    .print_menu
;///
;///  .change_use_bios_disks:
;///        call    boot.print_char
;///        call    boot.print_crlf
;///        call    boot.print_crlf
;///
;///;///        mov     ax, boot.data.bool_menu_options
;///;///        xor     bx, bx
;///;///        mov     cx, boot.data.s_use_bios_disks
;///;///        call    boot.print_options
;///
;///        mov     bx, '12'
;///        call    getkey
;///        mov     [preboot_biosdisk], al
;///
;///        jmp     .print_menu
;///
;///  .change_use_vrr:
;///        call    boot.print_char
;///        call    boot.print_crlf
;///        call    boot.print_crlf
;///
;///;///        mov     ax, boot.data.bool_menu_options
;///;///        xor     bx, bx
;///;///        mov     cx, boot.data.s_use_vrr
;///;///        call    boot.print_options
;///
;///        mov     bx, '12'
;///        call    getkey
;///        mov     [preboot_vrrm], al
;///
;///        jmp     .print_menu
;///
;///  .change_boot_source:
;///        call    boot.print_char
;///        call    boot.print_crlf
;///        call    boot.print_crlf
;///
;///;///        mov     ax, boot.data.boot_source_menu_options
;///;///        xor     bx, bx
;///;///        mov     cx, boot.data.s_boot_source
;///;///        call    boot.print_options
;///
;///        mov     bx, '14'
;///        call    getkey
;///        mov     [preboot_device], al
;///
;///        jmp     .print_menu

  .continue:
        call    boot.print_crlf
        call    boot.print_crlf

        mov     si, loading_msg
        call    boot.print_string
        cmp     [boot.data.settings_changed], 0
        jz      .load
        cmp     [boot.data.loader_block], -1
        jz      .load
        les     bx, [boot.data.loader_block]
        mov     eax, [es:bx + 3]
        push    ds
        pop     es
        test    eax, eax
        jz      .load
        push    eax
        mov     si, save_quest
        call    boot.print_string

  .waityn:
        mov     ah, 0
        int     0x16
        or      al, 0x20
        cmp     al, 'n'
        jz      .loadc
        cmp     al, 'y'
        jnz     .waityn
        call    boot.print_char
;///        mov     byte[space_msg + 80], 186

        pop     eax
        push    cs
        push    .cont
        push    eax
        retf    ; call back

  .loadc:
        pop     eax

  .cont:
        push    cs
        pop     ds
;///        mov     si, space_msg
        mov     byte[si + 80], 0
;///        mov     dx, 0 * 256 + 15
;///        call    setcursor
        call    boot.print_string
;///        mov     dx, 0 * 256 + 15
;///        call    setcursor

  .load:

        ; ASK GRAPHICS MODE
        call    set_vmode

        ; GRAPHICS ACCELERATION
        ; force yes
        mov     [es:BOOT_MTRR], 1

        ; DMA ACCESS TO HD
        mov     al, [preboot_dma]
        mov     [es:BOOT_DMA], al

        ; VRR_M USE
        mov     al, [preboot_vrrm]
        mov     [es:BOOT_VRR], al
        mov     [es:BOOT_DIRECT_LFB], 1

        ; BOOT DEVICE
        mov     al, [preboot_device]
;///        dec     al
        mov     [boot_dev], al

; GET MEMORY MAP
include "detect/biosmem.asm"

        ; READ DISKETTE TO MEMORY
        cmp     [boot_dev], 0
        jne     .no_sys_on_floppy
        mov     si, diskload
;///        call    print
        call    boot.print_string
        xor     ax, ax ; reset drive
        xor     dx, dx
        int     0x13
        ; do we boot from CD-ROM?
        mov     ah, 0x41
        mov     bx, 0x55aa
        xor     dx, dx
        int     0x13
        jc      .nocd
        cmp     bx, 0xaa55
        jnz     .nocd
        mov     ah, 0x48
        push    ds
        push    es
        pop     ds
        mov     si, 0xa000
        mov     word[si], 30
        int     0x13
        pop     ds
        jc      .nocd
        push    ds
        lds     si, [es:si + 26]
        test    byte[ds:si + 10], 0x40
        pop     ds
        jz      .nocd
        ; yes - read all floppy by 18 sectors

        ; TODO: !!!! read only first sector and set variables !!!!!
        ; ...
        ; TODO: !!! then read flippy image track by track

        mov     cx, 0x0001 ; startcyl,startsector

  .a1:
        push    cx dx
        mov     al, 18
        mov     bx, 0xa000
        call    boot_read_floppy
        mov     si, movedesc
        push    es
        push    ds
        pop     es
        mov     cx, 256 * 18
        mov     ah, 0x87
        int     0x15
        pop     es
        pop     dx cx
        test    ah, ah
        jnz     .sayerr_floppy
        add     dword[si + 8 * 3 + 2], 512 * 18
        inc     dh
        cmp     dh, 2
        jnz     .a1
        mov     dh, 0
        inc     ch
        cmp     ch, 80
        jae     .ok_sys_on_floppy
        pusha
        mov     al, ch
        shr     ch, 2
        add     al, ch
        aam
        xchg    al, ah
        add     ax, '00'
        mov     si, pros
        mov     [si], ax
        call    boot.print_string
        popa
        jmp     .a1

  .nocd:
        ; no - read only used sectors from floppy
        ; now load floppy image to memory
        ; at first load boot sector and first FAT table

        ; read only first sector and fill variables
        mov     cx, 0x0001 ; first logical sector
        xor     dx, dx ; head = 0, drive = 0 (a:)
        mov     al, 1 ; read one sector
        mov     bx, 0xb000 ; es:bx -> data area
        call    boot_read_floppy
        ; fill the necessary parameters to work with a floppy
        mov     ax, word[es:bx + 24]
        mov     [BPB_SecPerTrk], ax
        mov     ax, word[es:bx + 26]
        mov     [BPB_NumHeads], ax
        mov     ax, word[es:bx + 17]
        mov     [BPB_RootEntCnt], ax
        mov     ax, word[es:bx + 14]
        mov     [BPB_RsvdSecCnt], ax
        mov     ax, word[es:bx + 19]
        mov     [BPB_TotSec16], ax
        mov     al, byte[es:bx + 13]
        mov     [BPB_SecPerClus], al
        mov     al, byte[es:bx + 16]
        mov     [BPB_NumFATs], al

        mov     ax, word[es:bx + 22]
        mov     [BPB_FATSz16], ax
        mov     cx, word[es:bx + 11]
        mov     [BPB_BytsPerSec], cx

        ; count of clusters in FAT12 ((size_of_FAT * 2) / 3)
;       mov     ax, [BPB_FATSz16]
;       mov     cx, [BPB_BytsPerSec]

        xor     dx, dx
        mul     cx
        shl     ax, 1
        mov     cx, 3
        div     cx ; now ax - number of clusters in FAT12
        mov     [end_of_FAT], ax

        ; load first FAT table
        mov     cx, 0x0002 ; startcyl, startsector ; TODO!!!!!
        xor     dx, dx ; starthead, drive
        mov     al, byte[BPB_FATSz16] ; no of sectors to read
        add     bx, [BPB_BytsPerSec] ; es:bx -> data area
        call    boot_read_floppy
        mov     bx, 0xb000

        ; and copy them to extended memory
        mov     si, movedesc
        mov     [si + 8 * 2 + 3], bh ; from

        mov     ax, [BPB_BytsPerSec]
        shr     ax, 1 ; words per sector
        mov     cx, [BPB_RsvdSecCnt]
        add     cx, [BPB_FATSz16]
        mul     cx
        push    ax ; save to stack count of words in boot+FAT
        xchg    ax, cx

        push    es
        push    ds
        pop     es
        mov     ah, 0x87
        int     0x15
        pop     es
        test    ah, ah
        jz      @f

  .sayerr_floppy:
        mov     dx, 0x3f2
        mov     al, 0
        out     dx, al
        mov     si, boot.data.s_mem_move_failed
        jmp     boot.error

    @@: pop     ax ; restore from stack count of words in boot+FAT
        shl     ax, 1 ; make bytes count from count of words
        and     eax, 0x0ffff
        add     [si + 8 * 3 + 2], eax

        ; copy first FAT to second copy
        ; TODO: BPB_NumFATs !!!!!
        add     bx, [BPB_BytsPerSec] ; !!! TODO: may be need multiply by BPB_RsvdSecCnt !!!
        mov     [si + 8 * 2 + 3], bh ; bx - begin of FAT

        mov     ax, [BPB_BytsPerSec]
        shr     ax, 1 ; words per sector
        mov     cx, [BPB_FATSz16]
        mul     cx
        mov     cx, ax ; cx - count of words in FAT

        push    es
        push    ds
        pop     es
        mov     ah, 0x87
        int     0x15
        pop     es
        test    ah, ah
        jnz     .sayerr_floppy

        mov     ax, cx
        shl     ax, 1
        and     eax, 0x0ffff ; ax - count of bytes in FAT
        add     [si + 8 * 3 + 2], eax

        ; reading RootDir
        ; TODO: BPB_NumFATs
        add     bx, ax
        add     bx, 0x100
        and     bx, 0x0ff00 ; bx - place in buffer to write RootDir
        push    bx

        mov     bx, [BPB_BytsPerSec]
        shr     bx, 5 ; divide bx by 32
        mov     ax, [BPB_RootEntCnt]
        xor     dx, dx
        div     bx
        push    ax ; ax - count of RootDir sectors

        mov     ax, [BPB_FATSz16]
        xor     cx, cx
        mov     cl, [BPB_NumFATs]
        mul     cx
        add     ax, [BPB_RsvdSecCnt] ; ax - first sector of RootDir

        mov     [FirstDataSector], ax
        pop     bx
        push    bx
        add     [FirstDataSector], bx ; Begin of data region of floppy

        ; read RootDir
        call    conv_abs_to_THS
        pop     ax
        pop     bx; place in buffer to write
        push    ax
        call    boot_read_floppy ; read RootDir into buffer

        ; copy RootDir
        mov     [si + 8 * 2 + 3], bh ; from buffer
        pop     ax ; ax = count of RootDir sectors
        mov     cx, [BPB_BytsPerSec]
        mul     cx
        shr     ax, 1
        mov     cx, ax ; count of words to copy
        push    es
        push    ds
        pop     es
        mov     ah, 0x87
        int     0x15
        pop     es

        mov     ax, cx
        shl     ax, 1
        and     eax, 0x0ffff ; ax - count of bytes in RootDir
        add     [si + 8 * 3 + 2], eax ; add count of bytes copied

        ; Reading data clusters from floppy
        mov     [si + 8 * 2 + 3], bh
        push    bx

        mov     di, 2 ; First data cluster

  .read_loop:
        mov     bx, di
        shr     bx, 1 ; bx+di = di*1.5
        jnc     .even
        test    word[es:bx + di + 0x0b200], 0xfff0 ; TODO: may not be 0xB200 !!!
        jmp     @f

  .even:
        test    word[es:bx + di + 0x0b200], 0x0fff ; TODO: may not be 0xB200 !!!

    @@: jz      .skip

; .read:
        ; read cluster di
        ; conv cluster di to abs. sector ax
        ; ax = (N-2) * BPB_SecPerClus + FirstDataSector
        mov     ax, di
        sub     ax, 2
        xor     bx, bx
        mov     bl, [BPB_SecPerClus]
        mul     bx
        add     ax, [FirstDataSector]
        call    conv_abs_to_THS
        pop     bx
        push    bx
        mov     al, [BPB_SecPerClus] ; number of sectors in cluster
        call    boot_read_floppy
        push    es
        push    ds
        pop     es
        pusha
;
        mov     ax, [BPB_BytsPerSec]
        xor     cx, cx
        mov     cl, [BPB_SecPerClus]
        mul     cx
        shr     ax, 1 ; ax = (BPB_BytsPerSec * BPB_SecPerClus)/2
        mov     cx, ax ; number of words to copy (count words in cluster)
;
        mov     ah, 0x87
        int     0x15 ; copy data
        test    ah, ah
        popa
        pop     es
        jnz     .sayerr_floppy

  .skip:
        ; skip cluster di
        mov     ax, [BPB_BytsPerSec]
        xor     cx, cx
        mov     cl, [BPB_SecPerClus]
        mul     cx
        and     eax, 0x0ffff ; ax - count of bytes in cluster
        add     [si + 8 * 3 + 2], eax

        mov     ax, [end_of_FAT] ; max cluster number
        pusha
        ; draw percentage
        ; total clusters: ax
        ; read clusters: di
        xchg    ax, di
        mov     cx, 100
        mul     cx
        div     di
        aam
        xchg    al, ah
        add     ax, '00'
        mov     si, pros
        cmp     [si], ax
        jz      @f
        mov     [si], ax
        call    boot.print_string

    @@: popa
        inc     di
        cmp     di, [end_of_FAT] ; max number of cluster
        jnz     .read_loop
        pop     bx ; clear stack

  .ok_sys_on_floppy:
        mov     si, backspace2
        call    boot.print_string
        mov     si, okt
        call    boot.print_string

  .no_sys_on_floppy:
        xor     ax, ax ; reset drive
        xor     dx, dx
        int     0x13
        mov     dx, 0x3f2 ; floppy motor off
        mov     al, 0
        out     dx, al

        ; SET GRAPHICS
        xor     ax, ax
        mov     es, ax

        mov     ax, [es:BOOT_VESA_MODE] ; vga & 320x200
        mov     bx, ax
        cmp     ax, 0x13
        je      .setgr
        cmp     ax, 0x12
        je      .setgr
        mov     ax, 0x4f02 ; Vesa

  .setgr:
        int     0x10
        test    ah, ah
        mov     si, fatalsel
        jnz     v_mode_error

        ; set mode 0x12 graphics registers:
        cmp     bx, 0x12
        jne     .gmok2

        mov     al, 0x05
        mov     dx, 0x3ce
        push    dx
        out     dx, al ; select GDC mode register
        mov     al, 0x02
        inc     dx
        out     dx, al ; set write mode 2

        mov     al, 0x02
        mov     dx, 0x3c4
        out     dx, al ; select VGA sequencer map mask register
        mov     al, 0x0f
        inc     dx
        out     dx, al ; set mask for all planes 0-3

        mov     al, 0x08
        pop     dx
        out     dx, al ; select GDC bit mask register for writes to 0x3cf

  .gmok2:
        push    ds
        pop     es
