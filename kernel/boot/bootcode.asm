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

include "bootcode.inc"
include "bootmenu.asm"
include "bootvesa.asm"
include "charset16.asm"

include "detect/biosmem.asm"

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.print_char ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> al = character
;-----------------------------------------------------------------------------------------------------------------------
        push    ax bx
        mov     ah, 0x0e
        mov     bh, 0
        int     0x10
        pop     bx ax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.print_string ;///////////////////////////////////////////////////////////////////////////////////////////////
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
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.print_crlf ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ax
        mov     al, 13
        call    boot.print_char
        mov     al, 10
        call    boot.print_char
        pop     ax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc setcursor ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> dx = pack[8(column), 8(row)]
;-----------------------------------------------------------------------------------------------------------------------
        push    ax bx
        mov     ah, 2
        mov     bh, 0
        xchg    dl, dh
        int     0x10
        pop     bx ax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.error ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ds:si = pointer to error message
;-----------------------------------------------------------------------------------------------------------------------
        push    si
        mov     si, boot.data.s_error
        mov     ax, 0x4020 ; pack[4(bg color), 4(fg color), 8(char)]
        call    boot.set_status_line.with_color
        pop     si
        call    boot.print_string
        jmp     $
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.clear_screen ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> di = offset (in chars)
;> cx = count (in chars)
;-----------------------------------------------------------------------------------------------------------------------
        push    es ax cx
        mov_s_  es, 0xb800

        mov     ax, 0x0720 ; pack[4(bg color), 4(fg color), 8(char)]
        shl     di, 1
        rep     stosw

        pop     cx ax es
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.get_time ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ah, 0
        int     0x1a
        xchg    ax, cx
        shl     eax, 16
        xchg    ax, dx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.set_status_line ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ax, 0x7020 ; pack[4(bg color), 4(fg color), 8(char)]

  .with_color:
        ; clear status area
        push    cx di es
        mov_s_  es, 0xb800
        mov     cx, 80 * 1
        mov     di, 80 * 24 * 2
        rep     stosw
        pop     es di cx

        or      si, si
        jz      .exit

        ; print status string
        push    dx
        mov     dx, 1 * 256 + 24
        call    setcursor
        call    boot.print_string
        pop     dx

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.read_ramdisk_from_floppy ;///////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        mov_s_  es, 0

        xor     ax, ax ; reset drive
        xor     dx, dx
        int     0x13

        ; do we boot from CD-ROM?
        mov     ah, 0x41
        mov     bx, 0x55aa
        xor     dx, dx
        int     0x13
        jc      .read_from_real_floppy

        cmp     bx, 0xaa55
        jnz     .read_from_real_floppy

        mov     ah, 0x48
        push    ds
        mov_s_  ds, es
        mov     si, 0xa000
        mov     word[si], 30
        int     0x13
        pop     ds
        jc      .read_from_real_floppy

        push    ds
        lds     si, [es:si + 26]
        test    byte[ds:si + 10], 0x40
        pop     ds
        jz      .read_from_real_floppy

        ; yes - read all floppy by 18 sectors

        ; TODO: read only first sector and set variables
        ; ...
        ; TODO: then read floppy image track by track

        mov     cx, 0x0001 ; pack[10(startcyl), 6(startsector)]

  .next_cd_sectors:
        push    cx dx
        mov     al, 18
        mov     bx, 0xa000
        call    .read_floppy
        mov     si, movedesc
        mov     cx, 256 * 18
        call    .mem_move
        pop     dx cx

        add     dword[si + 8 * 3 + 2], 512 * 18
        inc     dh
        cmp     dh, 2
        jnz     .next_cd_sectors

        mov     dh, 0
        inc     ch
        cmp     ch, 80
        jae     .exit

        pusha
        mov     al, ch
        shr     ch, 2
        add     al, ch
        call    .update_percents
        popa

        jmp     .next_cd_sectors

  .read_from_real_floppy:
        ; no - read only used sectors from floppy
        ; now load floppy image to memory
        ; at first load boot sector and first FAT table

        ; read only first sector and fill variables
        mov     cx, 0x0001 ; first logical sector
        xor     dx, dx ; head = 0, drive = 0 (a:)
        mov     al, 1 ; read one sector
        mov     bx, 0xb000 ; es:bx -> data area
        call    .read_floppy
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
        call    .read_floppy
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
        call    .mem_move

        pop     ax ; restore from stack count of words in boot+FAT
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
        call    .mem_move

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
        call    .conv_abs_to_THS
        pop     ax
        pop     bx; place in buffer to write
        push    ax
        call    .read_floppy ; read RootDir into buffer

        ; copy RootDir
        mov     [si + 8 * 2 + 3], bh ; from buffer
        pop     ax ; ax = count of RootDir sectors
        mov     cx, [BPB_BytsPerSec]
        mul     cx
        shr     ax, 1
        mov     cx, ax ; count of words to copy
        call    .mem_move

        mov     ax, cx
        shl     ax, 1
        and     eax, 0x0ffff ; ax - count of bytes in RootDir
        add     [si + 8 * 3 + 2], eax ; add count of bytes copied

        ; Reading data clusters from floppy
        mov     [si + 8 * 2 + 3], bh
        push    bx

        mov     di, 2 ; First data cluster

  .next_fd_sectors:
        mov     ax, 0x0fff
        mov     bx, di
        shr     bx, 1 ; bx+di = di*1.5
        jnc     @f
        shl     ax, 4

    @@: test    [es:bx + di + 0x0b200], ax ; TODO: may not be 0xB200 !!!
        jz      .skip_fd_sectors

        ; read cluster di
        ; conv cluster di to abs. sector ax
        ; ax = (N-2) * BPB_SecPerClus + FirstDataSector
        mov     ax, di
        sub     ax, 2
        xor     bx, bx
        mov     bl, [BPB_SecPerClus]
        mul     bx
        add     ax, [FirstDataSector]
        call    .conv_abs_to_THS
        pop     bx
        push    bx
        mov     al, [BPB_SecPerClus] ; number of sectors in cluster
        call    .read_floppy

        pusha
        mov     ax, [BPB_BytsPerSec]
        xor     cx, cx
        mov     cl, [BPB_SecPerClus]
        mul     cx
        shr     ax, 1 ; ax = (BPB_BytsPerSec * BPB_SecPerClus)/2
        mov     cx, ax ; number of words to copy (count words in cluster)
        call    .mem_move
        popa

  .skip_fd_sectors:
        ; skip cluster di
        mov     ax, [BPB_BytsPerSec]
        xor     cx, cx
        mov     cl, [BPB_SecPerClus]
        mul     cx
        and     eax, 0x0ffff ; ax - count of bytes in cluster
        add     [si + 8 * 3 + 2], eax

        mov     ax, [end_of_FAT]

        ; draw percentage
        pusha
        xchg    ax, di ; ax = read clusters, di = total clusters
        mov     cx, 100
        mul     cx
        div     di
        call    .update_percents
        popa

        inc     di
        cmp     di, ax ; max number of cluster
        jne     .next_fd_sectors

        pop     bx ; clear stack

  .exit:
        pop     es
        ret

;-----------------------------------------------------------------------------------------------------------------------
  .update_percents: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        aam
        xchg    al, ah
        add     ax, '00'
        mov     si, boot.data.s_loading_floppy_percent
        cmp     [si], ax
        jz      @f
        mov     [si], ax
        call    boot.print_string
    @@: ret

;-----------------------------------------------------------------------------------------------------------------------
  .mem_move: ;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;-----------------------------------------------------------------------------------------------------------------------
        push    es
        mov_s_  es, ds
        mov     ah, 0x87
        int     0x15
        pop     es
        jnc     @f

        mov     dx, 0x3f2
        mov     al, 0
        out     dx, al
        mov     si, boot.data.s_mem_move_failed
        jmp     boot.error

    @@: ret

;-----------------------------------------------------------------------------------------------------------------------
  .read_floppy: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
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
  .conv_abs_to_THS: ;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
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
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc boot.start ;//////////////////////////////////////////////////////////////////////////////////////////////////////
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
        mov     [cs:bx_from_load], bx

  .no_hd_load:
        ; set up stack
        mov     ax, 0x3000
        mov     ss, ax
        mov     sp, 0xec00

        ; set up segment registers
        mov_s_  ds, cs
        mov_s_  es, cs

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
        mov_s_  es, 0xb800
        mov     ax, 0x0220 ; pack[4(bg color), 4(fg color), 8(char)]
        mov     cx, 80 * (boot.data.s_logo.height + 2)
        xor     di, di
        rep     stosw
        mov     ax, 0x2020
        mov     cx, 80 * 1
        rep     stosw
        mov     ax, 0x0720
        mov     cx, 80 * (25 - boot.data.s_logo.height - 3)
        rep     stosw
        pop     es

        ; print header
        mov     dx, 0 * 256 + 1
        call    setcursor

        mov     si, boot.data.s_logo
        call    boot.print_string

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

        mov     dx, 1 * 256 + boot.data.s_logo.height + 2
        call    setcursor

        mov     si, boot.data.s_version
        call    boot.print_string
        mov     si, boot.data.s_version_number
        call    boot.print_string
        mov     si, boot.data.s_license
        call    boot.print_string

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

        mov_s_  es, 0
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
        ; CHECK current of code
        cmp     [boot.data.loader_block], -1
        jz      .noloaderblock
        les     bx, [boot.data.loader_block]
        cmp     byte[es:bx], 1
        mov     si, boot.data.s_invalid_bootloader_data
        jnz     boot.error

  .noloaderblock:
        ; INIT VIDEO MODES INFORMATION
        call    boot.init_vesa_info
        call    boot.init_vmodes_table

        ; determine default settings
        ; if image in memory is present and [boot.params.boot_source] is not initialized,
        ; set it to use this preloaded image
        cmp     [boot.params.boot_source], -1
        jne     .load_settings
        cmp     [boot.data.loader_block], -1
        jz      @f
        les     bx, [boot.data.loader_block]
        test    byte[es:bx + 1], 1
        jz      @f
        mov     [boot.params.boot_source], 2
        jmp     .load_settings

    @@: ; otherwise, set [boot.params.boot_source] to 0 (boot from floppy)
        mov     [boot.params.boot_source], 0

  .load_settings:
        ; load preboot params to menu
        call    boot.load_vmode_to_menu
        movzx   ax, [boot.params.use_bios_disks]
        mov     [boot.data.use_bios_disks_menu + boot_menu_data_t.current_index], ax
        movzx   ax, [boot.params.use_vrr]
        mov     [boot.data.use_vrr_menu + boot_menu_data_t.current_index], ax
        movzx   ax, [boot.params.boot_source]
        mov     [boot.data.boot_source_menu + boot_menu_data_t.current_index], ax

        mov     si, boot.data.s_keys_notice
        call    boot.set_status_line

        ; enable timeout for the first time
        or      al, 1

  .run_main_menu:
        mov     bx, boot.data.main_menu
        call    boot.run_menu

        ; cancelled by [Esc]? not possible with main menu
        cmp     al, boot.MENU_RESULT_CANCEL
        xchg    al, ah ; disable timeout
        je      .run_main_menu

        ; save preboot params from menu
        push    ax cx
        call    boot.save_vmode_from_menu
        mov     ax, [boot.data.use_bios_disks_menu + boot_menu_data_t.current_index]
        mov     [boot.params.use_bios_disks], al
        mov     ax, [boot.data.use_vrr_menu + boot_menu_data_t.current_index]
        mov     [boot.params.use_vrr], al
        mov     ax, [boot.data.boot_source_menu + boot_menu_data_t.current_index]
        mov     [boot.params.boot_source], al
        pop     cx ax

        ; was it [F10]/[F11] keys which caused the exit?
        cmp     ah, boot.MENU_RESULT_SAVEBOOT
        je      .save_settings
        cmp     ah, boot.MENU_RESULT_BOOT
        je      .continue_boot_non_interactive

        ; some item has been selected by [Enter]
        ; this could only happen with last two items: 5 (save and continue boot) and 6 (continue without saving)
        cmp     cl, 5 ; save and boot
        jne     .continue_boot_non_interactive

  .save_settings:
        cmp     [boot.data.loader_block], -1
        je      .continue_boot_non_interactive

        les     bx, [boot.data.loader_block]
        mov     eax, [es:bx + 3]
        mov_s_  es, ds
        test    eax, eax
        jz      .continue_boot_non_interactive

        push    cs
        push    .return_from_save_settings
        push    eax

        mov     si, boot.data.s_saving_settings
        call    boot.set_status_line

        retf    ; call back

  .return_from_save_settings:
        mov_s_  ds, cs

  .continue_boot_non_interactive:
        xor     si, si
        call    boot.set_status_line

        ; ASK GRAPHICS MODE
        call    boot.set_vmode_boot_vars

        ; GRAPHICS ACCELERATION
        ; force yes
        mov     [es:BOOT_MTRR], 1

        ; DMA ACCESS TO HD
        mov     al, [boot.params.use_dma]
        mov     [es:BOOT_DMA], al

        ; VRR_M USE
        mov     al, [boot.params.use_vrr]
        mov     [es:BOOT_VRR], al
        mov     [es:BOOT_DIRECT_LFB], 1

        ; GET MEMORY MAP
        call    get_memory_map_from_bios

        ; BOOT DEVICE
        mov     al, [boot.params.boot_source]
        mov     [boot_dev], al

        ; READ DISKETTE TO MEMORY
        or      al, al
        jnz     .no_sys_on_floppy

        mov     si, boot.data.s_loading_floppy
        call    boot.set_status_line

        call    boot.read_ramdisk_from_floppy

        xor     si, si
        call    boot.set_status_line

  .no_sys_on_floppy:
        xor     ax, ax ; reset drive
        xor     dx, dx
        int     0x13

        mov     dx, 0x3f2 ; floppy motor off
        mov     al, 0
        out     dx, al

        ; SET GRAPHICS
        mov_s_  es, 0

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
        mov     si, boot.data.s_invalid_vmode
        jnz     boot.error

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
        mov_s_  es, ds
kendp
