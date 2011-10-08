;;======================================================================================================================
;;///// fs.asm ///////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
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

iglobal
  dir0:
    db 'HARDDISK   '
    db 'RAMDISK    '
    db 'FLOPPYDISK '
    db 0

  dir1:
    db 'FIRST      '
    db 'SECOND     '
    db 'THIRD      '
    db 'FOURTH     '
    db 0

  not_select_IDE db 0

  hd_address_table:
    dd 0x1f0, 0x00, 0x1f0, 0x10
    dd 0x170, 0x00, 0x170, 0x10
endg

uglobal
  align 4
  hd_entries       rd 1 ; unused? 1 write, 0 reads
  lba_read_enabled rd 1 ; 0 = disabled , 1 = enabled
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc util.64bit.compare ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edx:eax #= first number
;> [esp + 8]:[esp + 4] #= second number
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edx, [esp + 8]
        jne     @f

        cmp     eax, [esp + 4]

    @@: ret     8
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.read ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> edi ^= buffer
;> ecx #= buffer size (number of bytes to read)
;> edx:eax #= offset
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx
        add     eax, ecx
        adc     edx, 0
        push    dword[ebx + fs.partition_t.range.length + 4]
        push    dword[ebx + fs.partition_t.range.length]
        call    util.64bit.compare
        pop     edx eax
        ja      .overflow_error

        push    ebx edx esi
        add     eax, dword[ebx + fs.partition_t.range.offset]
        adc     edx, dword[ebx + fs.partition_t.range.offset + 4]
        mov     esi, [ebx + fs.partition_t.device]
        mov     ebx, [esi + blkdev.device_t.user_data]
        mov     esi, [esi + blkdev.device_t.vftbl]
        call    [esi + blkdev.vftbl_t.read]
        pop     esi edx ebx

        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.write ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi ^= buffer
;> ecx #= buffer size (number of bytes to write)
;> edx:eax #= offset
;> ebx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
;< eax #= error code
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx
        add     eax, ecx
        adc     edx, 0
        push    dword[ebx + fs.partition_t.range.length + 4]
        push    dword[ebx + fs.partition_t.range.length]
        call    util.64bit.compare
        pop     edx eax
        ja      .overflow_error

        push    ebx edx edi
        add     eax, dword[ebx + fs.partition_t.range.offset]
        adc     edx, dword[ebx + fs.partition_t.range.offset + 4]
        mov     edi, [ebx + fs.partition_t.device]
        mov     ebx, [edi + blkdev.device_t.user_data]
        mov     edi, [edi + blkdev.device_t.vftbl]
        call    [edi + blkdev.vftbl_t.write]
        pop     edi edx ebx

        ret

  .overflow_error:
        mov     eax, -123 ; TODO: add error code
        ret
kendp

if defined COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.file_system ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 58
;-----------------------------------------------------------------------------------------------------------------------
;> eax = 0 - read file          /RamDisk/First  6
;>       8 - lba read
;>       15 - get_disk_info
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 (ok) or error code
;< ebx = size
;-----------------------------------------------------------------------------------------------------------------------
;# Error codes:
;#   1 - no hd base and/or partition defined
;#   2 - function is unsupported for this FS
;#   3 - unknown FS
;#   4 - partition not defined at hd
;#   5 - file not found
;#   6 - end of file
;#   7 - memory pointer not in application area
;#   8 - disk full
;#   9 - fat table corrupted
;#   10 - access denied
;#   11 - disk error
;-----------------------------------------------------------------------------------------------------------------------
;# for subfunction 16 (start application) error codes must be negative because positive values are valid PIDs
;# so possible return values are:
;#   eax = PID (1+) - process created
;#     filesystem error code:
;#       -1 - no hd base and/or partition defined
;#       -3 - unknown FS
;#       -5 - file not found
;#       -6 - unexpected end of file (probably not executable file)
;#       -9 - fat table corrupted
;#       -10 - access denied
;#     process creation error code:
;#       -0x20 - too many processes
;#       -0x1F - not Menuet/Kolibri executable
;#       -0x1E - no memory
;#   ebx is not changed
;-----------------------------------------------------------------------------------------------------------------------
        ; Extract parameters
;       add     eax, std_application_base_address ; abs start of info block

        cmp     dword[eax + 0], 15 ; GET_DISK_INFO
        je      fs_info

        cmp     [CURRENT_TASK], 1 ; no memory checks for kernel requests
        jz      no_checks_for_kernel
        mov     edx, eax
        cmp     dword[eax + 0], 1
        jnz     .usual_check
        mov     ebx, [eax + 12]
;       add     ebx, std_application_base_address
        mov     ecx, [eax + 8]
        call    check_region
        test    eax, eax
        jnz     area_in_app_mem

  .error_output:
        klog_   LOG_ERROR, "Buffer check failed\n"
;       mov     eax, 7
        mov     [esp + 8 + regs_context32_t.eax], ERROR_MEMORY_POINTER
        ret

  .usual_check:
        cmp     dword[eax + 0], 0
        mov     ecx, 512
        jnz     .small_size
        mov     ecx, [eax + 8]
        shl     ecx, 9

  .small_size:
        mov     ebx, [eax + 12]
;       add     ebx, std_application_base_address
        call    check_region
        test    eax, eax
        jz      .error_output

  area_in_app_mem:
        mov     eax, edx

  no_checks_for_kernel:
  fs_read:
        mov   ebx, [eax + 20] ; program wants root directory ?
        test  bl, bl
        je    fs_getroot
        test  bh, bh
        jne   fs_noroot

  fs_getroot:
        ; root - only read is allowed
        ; other operations return "access denied", eax=10
        ; (execute operation returns eax=-10)
        cmp    dword[eax], 0
        jz    .read_root
        mov    [esp + 8 + regs_context32_t.eax], ERROR_ACCESS_DENIED
        ret

  .read_root:
        mov     esi, dir0
        mov     edi, [eax + 12]
;       add     edi, std_application_base_address
        mov     ecx, 11
        push    ecx
;       cld     ; already is
        rep     movsb
        mov     al, 0x10
        stosb
        add     edi, 32 - 11 - 1
        pop     ecx
        rep     movsb
        stosb
        and     [esp + 8 + regs_context32_t.eax], 0 ; ok read
        mov     [esp + 8 + regs_context32_t.ebx], 32 * 2 ; size of root
        ret

  fs_info:
        push    eax
        cmp     byte[eax + 21], 'h'
        je      fs_info_h
        cmp     byte[eax + 21], 'H'
        je      fs_info_h
        cmp     byte[eax + 21], 'r'
        je      fs_info_r
        cmp     byte[eax + 21], 'R'
        je      fs_info_r
        mov     eax, 3 ; if unknown disk
        xor     ebx, ebx
        xor     ecx, ecx
        xor     edx, edx
        jmp     fs_info1

  fs_info_r:
        call    ramdisk_free_space ; if ramdisk
        mov     ecx, edi ; free space in ecx
        shr     ecx, 9 ; free clusters
        mov     ebx, 2847 ; total clusters
        mov     edx, 512 ; cluster size
        xor     eax, eax ; always 0
        jmp     fs_info1

  fs_info_h: ; if harddisk
        call    get_hd_info

  fs_info1:
        pop     edi
        mov     [esp + 8 + regs_context32_t.eax], eax
        mov     [esp + 8 + regs_context32_t.ebx], ebx ; total clusters on disk
        mov     [esp + 8 + regs_context32_t.ecx], ecx ; free clusters on disk
        mov     [edi], edx ; cluster size in bytes
        ret

  fs_noroot:
        push    dword[eax + 0] ; read/write/delete/.../makedir/rename/lba/run
        push    dword[eax + 4] ; 512 block number to read
        push    dword[eax + 8] ; bytes to write/append or 512 blocks to read
        mov     ebx, [eax + 12]
;       add     ebx, std_application_base_address
        push    ebx ; abs start of return/save area

        lea     esi, [eax + 20] ; abs start of dir + filename
        mov     edi, [eax + 16]
;       add     edi, std_application_base_address ; abs start of work area

        call    expand_pathz

        push    edi ; dir start
        push    ebx ; name of file start

        mov     eax, [edi + 1]
        cmp     eax, 'RD  '
        je      fs_yesramdisk
        cmp     eax, 'RAMD'
        jne     fs_noramdisk

  fs_yesramdisk:
        cmp     byte[edi + 1 + 11], 0
        je      fs_give_dir1

        mov     eax, [edi + 1 + 12]
        cmp     eax, '1   '
        je      fs_yesramdisk_first
        cmp     eax, 'FIRS'
        jne     fs_noramdisk

  fs_yesramdisk_first:
        cmp     dword[esp + 20], 8 ; LBA read ramdisk
        jne     fs_no_LBA_read_ramdisk

        mov     eax, [esp + 16] ; LBA block to read
        mov     ecx, [esp + 8] ; abs pointer to return area

        call    LBA_read_ramdisk
        jmp     file_system_return


  fs_no_LBA_read_ramdisk:
        cmp     dword[esp + 20], 0 ; READ
        jne     fs_noramdisk_read

        mov     eax, [esp + 4] ; fname
        add     eax, 2 * 12 + 1
        mov     ebx, [esp + 16] ; block start
        inc     ebx
        mov     ecx, [esp + 12] ; block count
        mov     edx, [esp + 8] ; return
        mov     esi, [esp + 0]
        sub     esi, eax
        add     esi, 12 + 1     ; file name length
        call    fileread

        jmp     file_system_return

  fs_noramdisk_read:
  fs_noramdisk:
        mov     eax, [edi + 1]
        cmp     eax, 'FD  '
        je      fs_yesflpdisk
        cmp     eax, 'FLOP'
        jne     fs_noflpdisk

  fs_yesflpdisk:
        call    reserve_flp

        cmp     byte[edi + 1 + 11], 0
        je      fs_give_dir1

        mov     eax, [edi + 1 + 12]
        cmp     eax, '1   '
        je      fs_yesflpdisk_first
        cmp     eax, 'FIRS'
        je      fs_yesflpdisk_first
        cmp     eax, '2   '
        je      fs_yesflpdisk_second
        cmp     eax, 'SECO'
        jne     fs_noflpdisk
        jmp     fs_yesflpdisk_second

  fs_yesflpdisk_first:
        mov     [flp_number], 1
        jmp     fs_yesflpdisk_start

  fs_yesflpdisk_second:
        mov     [flp_number], 2

  fs_yesflpdisk_start:
        cmp     dword[esp + 20], 0 ; READ
        jne     fs_noflpdisk_read

        mov     eax, [esp + 4] ; fname
        add     eax, 2 * 12 + 1
        mov     ebx, [esp + 16] ; block start
        inc     ebx
        mov     ecx, [esp + 12] ; block count
        mov     edx, [esp + 8] ; return
        mov     esi, [esp + 0]
        sub     esi, eax
        add     esi, 12 + 1 ; file name length
        call    floppy_fileread

        jmp     file_system_return

  fs_noflpdisk_read:
  fs_noflpdisk:
        mov     eax, [edi + 1]
        cmp     eax, 'HD0 '
        je      fs_yesharddisk_IDE0
        cmp     eax, 'HD1 '
        je      fs_yesharddisk_IDE1
        cmp     eax, 'HD2 '
        je      fs_yesharddisk_IDE2
        cmp     eax, 'HD3 '
        je      fs_yesharddisk_IDE3
        jmp     old_path_harddisk

  fs_yesharddisk_IDE0:
        call    reserve_hd1
        mov     [hdbase], 0x1f0
        mov     [hdid], 0
        mov     [hdpos], 1
        jmp     fs_yesharddisk_partition

  fs_yesharddisk_IDE1:
        call    reserve_hd1
        mov     [hdbase], 0x1f0
        mov     [hdid], 0x10
        mov     [hdpos], 2
        jmp     fs_yesharddisk_partition

  fs_yesharddisk_IDE2:
        call    reserve_hd1
        mov     [hdbase], 0x170
        mov     [hdid], 0
        mov     [hdpos], 3
        jmp     fs_yesharddisk_partition

  fs_yesharddisk_IDE3:
        call    reserve_hd1
        mov     [hdbase], 0x170
        mov     [hdid], 0x10
        mov     [hdpos], 4

  fs_yesharddisk_partition:
        call    reserve_hd_channel
;       call    choice_necessity_partition
;       jmp     fs_yesharddisk_all
        jmp     fs_for_new_semantic
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc choice_necessity_partition ;//////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [edi + 1 + 12]
        call    StringToNumber
        mov     [fat32part], eax
kendp

end if ; COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
kproc choice_necessity_partition_1 ;////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [hdpos]
        xor     eax, eax
        mov     [hd_entries], eax ; entries in hd cache
        mov     edx, DRIVE_DATA + 2
        cmp     ecx, 0x80
        jb      search_partition_array
        mov     ecx, 4

  search_partition_array:
        mov     bl, [edx]
        movzx   ebx, bl
        add     eax, ebx
        inc     edx
        loop    search_partition_array
        mov     ecx, [hdpos]
        mov     edx, BiosDiskPartitions
        sub     ecx, 0x80
        jb      .s
        je      .f

    @@: mov     ebx, [edx]
        add     edx, 4
        add     eax, ebx
        loop    @b
        jmp     .f

  .s:
        sub     eax, ebx

  .f:
;       add     eax, [fat32part]
        add     eax, [known_part]
        dec     eax
        xor     edx, edx
        imul    eax, 100
        add     eax, DRIVE_DATA + 0x0a
        mov     [transfer_adress], eax
        call    partition_data_transfer_1
        ret
kendp

if defined COMPATIBILITY_MENUET_SYSFN58

;-----------------------------------------------------------------------------------------------------------------------
kproc old_path_harddisk ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [edi + 1]
        cmp     eax, 'HD  '
        je      fs_yesharddisk
        cmp     eax, 'HARD'
        jne     fs_noharddisk

  fs_yesharddisk:
        cmp     dword[esp + 20], 8 ; LBA read
        jne     fs_no_LBA_read
        mov     eax, [esp + 16] ; LBA block to read
        lea     ebx, [edi + 1 + 12] ; pointer to FIRST/SECOND/THIRD/FOURTH
        mov     ecx, [esp + 8] ; abs pointer to return area
        call    LBA_read
        jmp     file_system_return

  fs_no_LBA_read:
        cmp     byte[edi + 1 + 11], 0 ; directory read
        je      fs_give_dir1
        call    reserve_hd1

  fs_for_new_semantic:
        call    choice_necessity_partition

  fs_yesharddisk_all:
        mov     eax, 1
        mov     ebx, [esp + 24 + 8 + regs_context32_t.ebx]
        cmp     [hdpos], 0 ; is hd base set?
        jz      hd_err_return
        cmp     [fat32part], 0 ; is partition set?
        jnz     @f

  hd_err_return:
        call    free_hd_channel
        and     [hd1_status], 0
        jmp     file_system_return

    @@: cmp     dword[esp + 20], 0 ; READ
        jne     fs_noharddisk_read

        mov     eax, [esp + 0] ; /fname
        lea     edi, [eax + 12]
        mov     byte[eax], 0 ; path to asciiz
        inc     eax ; filename start

        mov     ebx, [esp + 12] ; count to read
        mov     ecx, [esp + 8] ; buffer
        mov     edx, [esp + 4]
        add     edx, 12 * 2 ; dir start
        sub     edi, edx ; path length
        mov     esi, [esp + 16] ; blocks to read

        call    file_read

        mov     edi, [esp + 0]
        mov     byte[edi], '/'

        call    free_hd_channel
        and     [hd1_status], 0
        jmp     file_system_return

  fs_noharddisk_read:
        call    free_hd_channel
        and     [hd1_status], 0

  fs_noharddisk:
        mov     eax, 5 ; file not found
        ; should it be some other error code?
        mov     ebx, [esp + 24 + 8 + regs_context32_t.ebx] ; do not change ebx in application

  file_system_return:
        add     esp, 24

        mov     [esp + 8 + regs_context32_t.eax], eax
        mov     [esp + 8 + regs_context32_t.ebx], ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_give_dir1 ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# /RD,/FD,/HD - only read is allowed
;# other operations return "access denied", eax = 10 (execute operation returns eax = -10)
;-----------------------------------------------------------------------------------------------------------------------
        cmp     dword[esp + 20], 0
        jz      .read
        add     esp, 20
        pop     ecx
        mov     [esp + 8 + regs_context32_t.eax], ERROR_ACCESS_DENIED
        ret

  .read:
        mov     al, 0x10
        mov     ebx, 1
        mov     edi, [esp + 8]
        mov     esi, dir1

  .fs_d1_new:
        mov     ecx, 11
;       cld
        rep     movsb
        stosb
        add     edi, 32 - 11 - 1
        dec     ebx
        jne     .fs_d1_new

        add     esp, 24

        and     [esp + 8 + regs_context32_t.eax], 0 ; ok read
        mov     [esp + 8 + regs_context32_t.ebx], 32 * 1 ; dir/data size
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc LBA_read_ramdisk ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [lba_read_enabled], 1
        je      .lbarrl1

        xor     ebx, ebx
        mov     eax, 2
        ret

  .lbarrl1:
        cmp     eax, 18 * 2 * 80
        jb      .lbarrl2
        xor     ebx, ebx
        mov     eax, 3
        ret

  .lbarrl2:
        pushad

        mov     esi, RAMDISK_FAT
        mov     edi, RAMDISK + 512
        call    fs.fat12.restore_fat_chain

        mov     edi, ecx
        mov     esi, eax

        shl     esi, 9
        add     esi, RAMDISK
        mov     ecx, 512 / 4
;       cld
        rep     movsd

        popad

        xor     ebx, ebx
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc LBA_read ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = LBA block to read
;> ebx = pointer to FIRST/SECOND/THIRD/FOURTH
;> ecx = abs pointer to return area
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [lba_read_enabled], 1
        je      .lbarl1
        mov     eax, 2
        ret

  .lbarl1:
        call    reserve_hd1

        push    eax
        push    ecx

        mov     edi, hd_address_table
        mov     esi, dir1
        mov     eax, [ebx]
        mov     edx, '1   '
        mov     ecx, 4

  .blar0:
        cmp     eax, [esi]
        je      .blar2
        cmp     eax, edx
        je      .blar2
        inc     edx
        add     edi, 8
        add     esi, 11
        dec     ecx
        jnz     .blar0

        mov     eax, 1
        mov     ebx, 1
        jmp     LBA_read_ret

  .blar2:
        mov     eax, [edi + 0]
        mov     ebx, [edi + 4]

        mov     [hdbase], eax
        mov     [hdid], bl

        call    wait_for_hd_idle
        cmp     [hd_error], 0
        jne     hd_lba_error

        ; eax = hd port
        ; ebx = set for primary (0x00) or slave (0x10)

        cli

        mov     edx, eax
        inc     edx
        xor     eax, eax
        out     dx, al
        inc     edx
        inc     eax
        out     dx, al
        inc     edx
        mov     eax, [esp + 4]
        out     dx, al
        shr     eax, 8
        inc     edx
        out     dx, al
        shr     eax, 8
        inc     edx
        out     dx, al
        shr     eax, 8
        inc     edx
        and     al, 1 + 2 + 4 + 8
        add     al, bl
        add     al, 128 + 64 + 32
        out     dx, al

        inc     edx
        mov     al, 0x20
        out     dx, al

        sti

        call    wait_for_sector_buffer
        cmp     [hd_error], 0
        jne     hd_lba_error

        cli

        mov     edi, [esp + 0]
        mov     ecx, 256
        sub     edx, 7
        cld
        rep     insw

        sti

        xor     eax, eax
        xor     ebx, ebx

  LBA_read_ret:
        mov     [hd_error], 0
        mov     [hd1_status], 0
        add     esp, 2 * 4

        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc expand_pathz ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi = asciiz path & file
;> edi = buffer for path & file name
;-----------------------------------------------------------------------------------------------------------------------
;< edi = directory & file : / 11 + / 11 + / 11 - zero terminated
;< ebx = /file name - zero terminated
;< esi = pointer after source
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    ecx
        push    edi ; [esp+0]

  pathz_start:
        mov     byte[edi], '/'
        inc     edi
        mov     al, 32
        mov     ecx, 11
        cld
        rep     stosb ; clear filename area
        sub     edi, 11
        mov     ebx, edi ; start of dir/file name

  pathz_new_char:
        mov     al, [esi]
        inc     esi
        cmp     al, 0
        je      pathz_end

        cmp     al, '/'
        jne     pathz_not_path
        cmp     edi, ebx ; skip first '/'
        jz      pathz_new_char
        lea     edi, [ebx + 11] ; start of next directory
        jmp     pathz_start

  pathz_not_path:
        cmp     al, '.'
        jne     pathz_not_ext
        lea     edi, [ebx + 8] ; start of extension
        jmp     pathz_new_char

  pathz_not_ext:
        cmp     al, 'a'
        jb      pathz_not_low
        cmp     al, 'z'
        ja      pathz_not_low
        sub     al, 0x20 ; char to uppercase

  pathz_not_low:
        mov     [edi], al
        inc     edi
        mov     eax, [esp + 0] ; start_of_dest_path
        add     eax, 512 ; keep maximum path under 512 bytes
        cmp     edi, eax
        jb      pathz_new_char

  pathz_end:
        cmp     ebx, edi ; if path end with '/'
        jnz     pathz_put_zero ; go back 1 level
        sub     ebx, 12

  pathz_put_zero:
        mov     byte[ebx + 11], 0
        dec     ebx ; include '/' char into file name
        pop     edi
        pop     ecx
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc StringToNumber ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? convert numeric string to number
;-----------------------------------------------------------------------------------------------------------------------
;> edi = pointer to numeric string, terminated with 0x0d
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 0 (ok), ax = number
;< if CF = 1 (error), ax is undefined
;-----------------------------------------------------------------------------------------------------------------------
        push    bx
        push    cx
        push    dx
        push    edi
        mov     [partition_string], eax
        mov     edi, partition_string
        xor     cx, cx

  .i1:
        mov     al, [edi]
        cmp     al, 32 ; 13
        je      .i_exit
;       cmp     al, '0'
;       jb      .err
;       cmp     al, '9'
;       ja      .err
        sub     al, 48
        shl     cx, 1
        jc      .error
        mov     bx, cx
        shl     cx, 1
        jc      .error
        shl     cx, 1
        jc      .error
        add     cx, bx
        jc      .error
        cbw
        add     cx, ax
        jc      .error

  .i3:
        inc     edi
        jmp     .i1

  .i_exit:
        mov     ax, cx
        clc

  .i4:
        movzx   eax, ax
        pop     edi
        pop     dx
        pop     cx
        pop     bx
        ret

  .error:
        stc
        jmp    .i4
kendp

end if ; COMPATIBILITY_MENUET_SYSFN58

iglobal
  partition_string:
    dd 0
    db 32
endg
