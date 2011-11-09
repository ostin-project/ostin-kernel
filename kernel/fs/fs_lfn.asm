;;======================================================================================================================
;;///// fs_lfn.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2006-2010 KolibriOS team <http://kolibrios.org/>
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

; System function 70 - files with long names (LFN)
; diamond, 2006

iglobal
  ; in this table names must be in lowercase
  rootdirs:

if KCONFIG_BLKDEV_MEMORY

    db 2, 'rd'
    dd fs_OnGenericQuery ; fs_OnRamdisk
    dd fs_NextRamdisk
    db 7, 'ramdisk'
    dd fs_OnGenericQuery ; fs_OnRamdisk
    dd fs_NextRamdisk

end if ; KCONFIG_BLKDEV_MEMORY

if KCONFIG_BLKDEV_FLOPPY

    db 2, 'fd'
    dd fs_OnGenericQuery2 ; fs_OnFloppy
    dd fs_NextFloppy
    db 10, 'floppydisk'
    dd fs_OnGenericQuery2 ; fs_OnFloppy
    dd fs_NextFloppy

end if ; KCONFIG_BLKDEV_FLOPPY

    db 3, 'hd0'
    dd fs_OnHd0
    dd fs_NextHd0
    db 3, 'hd1'
    dd fs_OnHd1
    dd fs_NextHd1
    db 3, 'hd2'
    dd fs_OnHd2
    dd fs_NextHd2
    db 3, 'hd3'
    dd fs_OnHd3
    dd fs_NextHd3
    db 3, 'cd0'
    dd fs_OnCd0
    dd fs_NextCd
    db 3, 'cd1'
    dd fs_OnCd1
    dd fs_NextCd
    db 3, 'cd2'
    dd fs_OnCd2
    dd fs_NextCd
    db 3, 'cd3'
    dd fs_OnCd3
    dd fs_NextCd
    db 0

  virtual_root_query:

if KCONFIG_BLKDEV_MEMORY

    dd fs_HasRamdisk
    db 'rd', 0

end if ; KCONFIG_BLKDEV_MEMORY

if KCONFIG_BLKDEV_FLOPPY

    dd fs_HasFloppy
    db 'fd', 0

end if ; KCONFIG_BLKDEV_FLOPPY

    dd fs_HasHd0
    db 'hd0', 0
    dd fs_HasHd1
    db 'hd1', 0
    dd fs_HasHd2
    db 'hd2', 0
    dd fs_HasHd3
    db 'hd3', 0
    dd fs_HasCd0
    db 'cd0', 0
    dd fs_HasCd1
    db 'cd1', 0
    dd fs_HasCd2
    db 'cd2', 0
    dd fs_HasCd3
    db 'cd3', 0
    dd 0

  fs_additional_handlers:
    dd biosdisk_handler, biosdisk_enum_root
    ; add new handlers here
    dd 0

  fs_HdServices:
    dd fs_HdRead
    dd fs_HdReadFolder
    dd fs_HdRewrite
    dd fs_HdWrite
    dd fs_HdSetFileEnd
    dd fs_HdGetFileInfo
    dd fs_HdSetFileInfo
    dd 0
    dd fs_HdDelete
    dd fs_HdCreateFolder
  fs_NumHdServices = ($ - fs_HdServices) / 4

  fs_CdServices:
    dd fs_CdRead
    dd fs_CdReadFolder
    dd fs.error.not_implemented
    dd fs.error.not_implemented
    dd fs.error.not_implemented
    dd fs_CdGetFileInfo
    dd fs.error.not_implemented
    dd 0
    dd fs.error.not_implemented
    dd fs.error.not_implemented
  fs_NumCdServices = ($ - fs_CdServices) / 4
endg

uglobal
  align 4
  NumBiosDisks       rd 1
  BiosDiskPartitions rd 0x80
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.file_system_lfn ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 70
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = pointer to fileinfo block
;-----------------------------------------------------------------------------------------------------------------------
;# operation codes:
;#   0 - read file
;#   1 - read folder
;#   2 - create/rewrite file
;#   3 - write/append to file
;#   4 - set end of file
;#   5 - get file/directory attributes structure
;#   6 - set file/directory attributes structure
;#   7 - start application
;#   8 - delete file
;#   9 - create directory
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [ebx + fs.query_t.function], fs_NumHdServices
        jae     sysfn.not_implemented

        ; parse file name
        lea     esi, [ebx + fs.query_t.file_path]
        lodsb
        test    al, al
        jnz     @f
        mov     esi, [esi]
        lodsb

    @@: cmp     al, '/'
        jz      .notcurdir
        dec     esi
        mov     ebp, esi
        test    al, al
        jnz     @f
        xor     ebp, ebp

    @@: mov     esi, [current_slot]
        mov     esi, [esi + app_data_t.cur_dir]
        jmp     .parse_normal

  .notcurdir:
        cmp     byte[esi], 0
        jz      .rootdir
        call    process_replace_file_name

  .parse_normal:
        cmp     dword[ebx], 7
        jne     @f
        mov     edx, [ebx + fs.query_t.start_program.flags]
        mov     ebx, [ebx + fs.query_t.start_program.arguments_ptr]
        call    fs_execute ; esi+ebp, ebx, edx
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

    @@: mov     edi, rootdirs - 8
        xor     ecx, ecx
        push    esi

  .scan1:
        pop     esi
        add     edi, ecx
        scasd
        scasd
        mov     cl, byte[edi]
        test    cl, cl
        jz      .notfound_try
        inc     edi
        push    esi

    @@: lodsb
        or      al, 0x20
        scasb
        loopz   @b
        jnz     .scan1
        lodsb
        cmp     al, '/'
        jz      .found1
        test    al, al
        jnz     .scan1
        pop     eax

  .maindir:
        ; directory /xxx
        mov     esi, [edi + 4]

  .maindir_noesi:
        cmp     dword[ebx], 1
        jnz     .access_denied
        xor     eax, eax
        mov     ebp, [ebx + fs.query_t.read_directory.count] ; blocks to read
        mov     edx, [ebx + fs.query_t.read_directory.buffer_ptr] ; result buffer ptr
;       add     edx, std_application_base_address
        push    [ebx + fs.query_t.read_directory.start_block] ; first block
        mov     ebx, [ebx + fs.query_t.read_directory.flags] ; flags
        ; ebx=flags, [esp]=first block, ebp=number of blocks, edx=return area, esi='Next' handler
        mov     edi, edx
        push    ecx
        mov     ecx, 32 / 4
        rep
        stosd
        pop     ecx
        mov     byte[edx], 1 ; version

  .maindir_loop:
        call    esi
        jc      .maindir_done
        inc     dword[edx + 8]
        dec     dword[esp]
        jns     .maindir_loop
        dec     ebp
        js      .maindir_loop
        inc     dword[edx + 4]
        mov     dword[edi], 0x10 ; attributes: folder
        mov     dword[edi + 4], 1 ; name type: UNICODE
        push    eax
        xor     eax, eax
        add     edi, 8
        push    ecx
        mov     ecx, 40 / 4 - 2
        rep
        stosd
        pop     ecx
        pop     eax
        push    eax edx
        ; convert number in eax to decimal UNICODE string
        push    edi
        push    ecx
        push    -'0'
        mov     ecx, 10

    @@: xor     edx, edx
        div     ecx
        push    edx
        test    eax, eax
        jnz     @b

    @@: pop     eax
        add     al, '0'
        stosb
        test    bl, 1 ; UNICODE name?
        jz      .ansi2
        mov     byte[edi], 0
        inc     edi

  .ansi2:
        test    al, al
        jnz     @b
        mov     byte[edi - 1], 0
        pop     ecx
        pop     edi
        ; UNICODE name length is 520 bytes, ANSI - 264
        add     edi, 520
        test    bl, 1
        jnz     @f
        sub     edi, 520 - 264

    @@: pop     edx eax
        jmp     .maindir_loop

  .maindir_done:
        pop     eax
        mov     ebx, [edx + 4]
        xor     eax, eax
        dec     ebp
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], ebx
        ret

  .rootdir:
        ; directory /
        cmp     dword[ebx], 1 ; read folder?
        jz      .readroot

  .access_denied:
        mov     [esp + 4 + regs_context32_t.eax], ERROR_ACCESS_DENIED ; access denied
        ret

  .readroot:
        ; virtual root folder - special handler
        mov     esi, virtual_root_query
        mov     ebp, [ebx + fs.query_t.read_directory.count]
        mov     edx, [ebx + fs.query_t.read_directory.buffer_ptr]
;       add     edx, std_application_base_address
        push    [ebx + fs.query_t.read_directory.start_block] ; first block
        mov     ebx, [ebx + fs.query_t.read_directory.flags] ; flags
        xor     eax, eax
        ; eax=0, [esp]=first block, ebx=flags, ebp=number of blocks, edx=return area
        mov     edi, edx
        mov     ecx, 32 / 4
        rep
        stosd
        mov     byte[edx], 1 ; version

  .readroot_loop:
        cmp     dword[esi], eax
        jz      .readroot_done_static
        call    dword[esi]
        add     esi, 4
        test    eax, eax
        jnz     @f

  .readroot_next:
        or      ecx, -1
        xchg    esi, edi
        repnz
        scasb
        xchg    esi, edi
        jmp     .readroot_loop

    @@: xor     eax, eax
        inc     dword[edx + 8]
        dec     dword[esp]
        jns     .readroot_next
        dec     ebp
        js      .readroot_next
        inc     dword[edx + 4]
        mov     dword[edi], 0x10 ; attributes: folder
        mov     dword[edi + 4], ebx ; name type: UNICODE
        add     edi, 8
        mov     ecx, 40 / 4 - 2
        rep
        stosd
        push    edi

    @@: lodsb
        stosb
        test    bl, 1
        jz      .ansi
        mov     byte[edi], 0
        inc     edi

  .ansi:
        test    eax, eax
        jnz     @b
        pop     edi
        add     edi, 520
        test    bl, 1
        jnz     .readroot_loop
        sub     edi, 520 - 264
        jmp     .readroot_loop

  .readroot_done_static:
        mov     esi, fs_additional_handlers - 8
        sub     esp, 16

  .readroot_ah_loop:
        add     esi, 8
        cmp     dword[esi], 0
        jz      .readroot_done
        xor     eax, eax

  .readroot_ah_loop2:
        push    edi
        lea     edi, [esp + 4]
        call    dword[esi + 4]
        pop     edi
        test    eax, eax
        jz      .readroot_ah_loop
        inc     dword[edx + 8]
        dec     dword[esp + 16]
        jns     .readroot_ah_loop2
        dec     ebp
        js      .readroot_ah_loop2
        push    eax
        xor     eax, eax
        inc     dword[edx + 4]
        mov     dword[edi], 0x10 ; attributes: folder
        mov     dword[edi + 4], ebx
        add     edi, 8
        mov     ecx, 40 / 4 - 2
        rep
        stosd
        push    esi edi
        lea     esi, [esp + 12]

    @@: lodsb
        stosb
        test    bl, 1
        jz      .ansi3
        mov     byte[edi], 0
        inc     edi

  .ansi3:
        test    al, al
        jnz     @b
        pop     edi esi eax
        add     edi, 520
        test    bl, 1
        jnz     .readroot_ah_loop2
        sub     edi, 520 - 264
        jmp     .readroot_ah_loop2

  .readroot_done:
        add     esp, 16
        pop     eax
        mov     ebx, [edx + 4]
        xor     eax, eax
        dec     ebp
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], ebx
        ret

  .notfound_try:
        mov     edi, fs_additional_handlers

    @@: cmp     dword[edi], 0
        jz      .notfound
        call    dword[edi]
        scasd
        scasd
        jmp     @b

  .notfound:
        mov     [esp + 4 + regs_context32_t.eax], ERROR_FILE_NOT_FOUND
        and     [esp + 4 + regs_context32_t.ebx], 0
        ret

  .notfounda:
        cmp     edi, esp
        jnz     .notfound
        add     esp, 8
        jmp     .notfound

  .found1:
        pop     eax
        cmp     byte[esi], 0
        jz      .maindir

  .found2:
        ; read partition number
        xor     ecx, ecx
        xor     eax, eax

    @@: lodsb
        cmp     al, '/'
        jz      .done1
        test    al, al
        jz      .done1
        sub     al, '0'
        cmp     al, 9
        ja      .notfounda
        lea     ecx, [ecx * 5]
        lea     ecx, [ecx * 2 + eax]
        jmp     @b

  .done1:
        jecxz   .notfounda
        test    al, al
        jnz     @f
        dec     esi

    @@: cmp     byte[esi], 0
        jnz     @f
        test    ebp, ebp
        jz      @f
        mov     esi, ebp
        xor     ebp, ebp

    @@: ; now [edi] contains handler address, ecx - partition number,
        ; esi points to ASCIIZ string - rest of name
        jmp     dword[edi]
kendp

;-----------------------------------------------------------------------------------------------------------------------
;? handlers for devices
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = 0 (query virtual directory /xxx) or partition number
;> esi = pointer to relative (for device) name
;> ebx = pointer to fileinfo
;> ebp = 0 or pointer to rest of name from folder addressed by esi
;-----------------------------------------------------------------------------------------------------------------------
;< [image_of_eax] = image of eax
;< [image_of_ebx] = image of ebx
;-----------------------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.generic_query_handler ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.query_t
;> edx ^= fs.partition_t
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [ebx + fs.query_t.function]
        shl     eax, 2
        add     eax, [edx + fs.partition_t.vftbl]
        mov     eax, [eax]
        test    eax, eax
        jz      sysfn.not_implemented

        xchg    ebx, edx
        add     edx, fs.query_t.generic ; ^= fs.?_query_params_t
        call    eax
        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], ebx
        ret
kendp

iglobal
  if KCONFIG_BLKDEV_MEMORY

  align 4
  ; blkdev.memory.device_data_t
  static_test_ram_device_data:
    ; data
    dd RAMDISK ; offset
    dd 2 * 80 * 18 * 512 ; length
    ; needs_free
    db 0

  align 4
  ; blkdev.device_t
  static_test_ram_device:
    ; vftbl
    dd blkdev.memory.vftbl
    ; name
    db 'rd', 30 dup(0)
    ; user_data
    dd static_test_ram_device_data

  align 4
  ; fs.partition_t
  static_test_ram_partition:
    ; vftbl
    dd fs.fat12.vftbl
    ; device
    dd static_test_ram_device
    ; range
    dq 0 ; offset
    dq 2 * 80 * 18 * 512 ; length
    ; type
    db FS_PARTITION_TYPE_FAT12
    ; number
    db 1
    ; user_data
    dd static_test_ram_partition_data

  end if ; KCONFIG_BLKDEV_MEMORY
endg

uglobal
  if KCONFIG_BLKDEV_MEMORY

  align 4
  ; fs.fat12.partition_data_t
  static_test_ram_partition_data:
    rb sizeof.fs.fat12.partition_data_t

  end if ; KCONFIG_BLKDEV_MEMORY
endg

if KCONFIG_BLKDEV_MEMORY

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnGenericQuery ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, static_test_ram_partition
        jmp     fs.generic_query_handler
kendp

end if ; KCONFIG_BLKDEV_MEMORY

iglobal
  if KCONFIG_BLKDEV_FLOPPY

  align 4
  ; blkdev.floppy.device_data_t
  static_test_floppy_device_data:
    ; position
    db sizeof.blkdev.floppy.chs_t dup(0)
    ; status
    db sizeof.blkdev.floppy.status_t dup(0)
    ; drive_number
    db 0
    ; motor_timer
    dd 0

  align 4
  ; blkdev.device_t
  static_test_floppy_device:
    ; vftbl
    dd blkdev.floppy.vftbl
    ; name
    db 'fd', 30 dup(0)
    ; user_data
    dd static_test_floppy_device_data

  align 4
  ; fs.partition_t
  static_test_floppy_partition:
    ; vftbl
    dd fs.fat12.vftbl
    ; device
    dd static_test_floppy_device
    ; range
    dq 0 ; offset
    dq 2 * 80 * 18 * 512 ; length
    ; type
    db FS_PARTITION_TYPE_FAT12
    ; number
    db 1
    ; user_data
    dd static_test_floppy_partition_data

  end if ; KCONFIG_BLKDEV_FLOPPY
endg

uglobal
  if KCONFIG_BLKDEV_FLOPPY

  align 4
  ; fs.fat12.partition_data_t
  static_test_floppy_partition_data:
    rb sizeof.fs.fat12.partition_data_t

  end if ; KCONFIG_BLKDEV_FLOPPY
endg

if KCONFIG_BLKDEV_FLOPPY

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnGenericQuery2 ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, static_test_floppy_partition
        jmp     fs.generic_query_handler
kendp

end if ; KCONFIG_BLKDEV_FLOPPY

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnHd0 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_hd1
        mov     [hdbase], 0x1f0
        mov     [hdid], 0
        push    1
        jmp     fs_OnHd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnHd1 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_hd1
        mov     [hdbase], 0x1f0
        mov     [hdid], 0x10
        push    2
        jmp     fs_OnHd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnHd2 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_hd1
        mov     [hdbase], 0x170
        mov     [hdid], 0
        push    3
        jmp     fs_OnHd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnHd3 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_hd1
        mov     [hdbase], 0x170
        mov     [hdid], 0x10
        push    4
kendp

kproc fs_OnHd
        call    reserve_hd_channel
        pop     eax
        mov     [hdpos], eax
        cmp     ecx, 0x100
        jae     fs_OnHdAndBd.nf
        cmp     cl, [DRIVE_DATA + 1 + eax]
kendp

kproc fs_OnHdAndBd
        jbe     @f

  .nf:
        mov     [esp + 4 + regs_context32_t.eax], ERROR_FILE_NOT_FOUND ; not found
        jmp     .free

    @@: mov     [known_part], ecx
        push    ebx esi
        call    choice_necessity_partition_1
        pop     esi ebx

        mov     eax, [ebx + fs.query_t.function]
        mov     ecx, [ebx + fs.query_t.generic.param3]
        mov     edx, [ebx + fs.query_t.generic.param4]
        add     ebx, fs.query_t.generic

        call    dword[fs_HdServices + eax * 4]

        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], ebx

  .free:
        call    free_hd_channel
        and     [hd1_status], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.not_implemented ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_NOT_IMPLEMENTED
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.unknown_filesystem ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_UNKNOWN_FS
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.file_not_found ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_FILE_NOT_FOUND
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.disk_full ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_DISK_FULL
        xor     ebx, ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.access_denied ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov_s_  eax, ERROR_ACCESS_DENIED
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdRead ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

        cmp     [fs_type], 1
        je      ntfs_HdRead
        cmp     [fs_type], 2
        je      ext2_HdRead
        cmp     [fs_type], 16
        je      fat32_HdRead
        cmp     [fs_type], 32
        je      fat32_HdRead

        jmp     fs.error.unknown_filesystem
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdReadFolder ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [fs_type], 1
        je      ntfs_HdReadFolder
        cmp     [fs_type], 2
        je      ext2_HdReadFolder
        cmp     [fs_type], 16
        je      fat32_HdReadFolder
        cmp     [fs_type], 32
        je      fat32_HdReadFolder

        jmp     fs.error.unknown_filesystem
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdRewrite ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax

  .direct:
        cmp     byte[esi], 0
        je      fs.error.access_denied

;       cmp     [fs_type], 1
;       je      ntfs_HdRewrite
;       cmp     [fs_type], 2
;       je      ext2_HdRewrite
        cmp     [fs_type], 16
        je      fat32_HdRewrite
        cmp     [fs_type], 32
        je      fat32_HdRewrite

        jmp     fs.error.unknown_filesystem
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdWrite ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

;       cmp     [fs_type], 1
;       je      ntfs_HdWrite
;       cmp     [fs_type], 2
;       je      ext2_HdWrite
        cmp     [fs_type], 16
        je      fat32_HdWrite
        cmp     [fs_type], 32
        je      fat32_HdWrite

        jmp     fs.error.unknown_filesystem
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdSetFileEnd ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

;       cmp     [fs_type], 1
;       je      ntfs_HdSetFileEnd
;       cmp     [fs_type], 2
;       je      ext2_HdSetFileEnd
        cmp     [fs_type], 16
        je      fat32_HdSetFileEnd
        cmp     [fs_type], 32
        je      fat32_HdSetFileEnd

        jmp     fs.error.unknown_filesystem
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdGetFileInfo ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [fs_type], 1
        je      ntfs_HdGetFileInfo
        cmp     [fs_type], 2
        je      ext2_HdGetFileInfo
        cmp     [fs_type], 16
        je      fat32_HdGetFileInfo
        cmp     [fs_type], 32
        je      fat32_HdGetFileInfo

        jmp     fs.error.unknown_filesystem
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdSetFileInfo ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       cmp     [fs_type], 1
;       je      ntfs_HdSetFileInfo
;       cmp     [fs_type], 2
;       je      ext2_HdSetFileInfo
        cmp     [fs_type], 16
        je      fat32_HdSetFileInfo
        cmp     [fs_type], 32
        je      fat32_HdSetFileInfo

        jmp     fs.error.unknown_filesystem
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdDelete ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

;       cmp     [fs_type], 1
;       je      ntfs_HdDelete
;       cmp     [fs_type], 2
;       je      ext2_HdDelete
        cmp     [fs_type], 16
        je      fat32_HdDelete
        cmp     [fs_type], 32
        je      fat32_HdDelete

        jmp     fs.error.unknown_filesystem
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdCreateFolder ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 1
        jmp     fs_HdRewrite.direct
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnCd0 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_cd
        mov     [ChannelNumber], 0
        mov     [DiskNumber], 0
        push    6
        push    1
        jmp     fs_OnCd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnCd1 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_cd
        mov     [ChannelNumber], 0
        mov     [DiskNumber], 1
        push    4
        push    2
        jmp     fs_OnCd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnCd2 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_cd
        mov     [ChannelNumber], 1
        mov     [DiskNumber], 0
        push    2
        push    3
        jmp     fs_OnCd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnCd3 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        call    reserve_cd
        mov     [ChannelNumber], 1
        mov     [DiskNumber], 1
        push    0
        push    4
kendp

kproc fs_OnCd
        call    reserve_cd_channel
        pop     eax
        mov     [cdpos], eax
        pop     eax
        cmp     ecx, 0x100
        jae     .nf
        push    ecx ebx
        mov     cl, al
        mov     bl, [DRIVE_DATA + 1]
        shr     bl, cl
        test    bl, 2
        pop     ebx ecx

        jnz     @f

  .nf:
        mov     [esp + 4 + regs_context32_t.eax], ERROR_FILE_NOT_FOUND ; not found
        jmp     .free

    @@: mov     eax, [ebx + fs.query_t.function]
        mov     ecx, [ebx + fs.query_t.generic.param3]
        mov     edx, [ebx + fs.query_t.generic.param4]
        add     ebx, fs.query_t.generic

        call    dword[fs_CdServices + eax * 4]

        mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], ebx

  .free:
        call    free_cd_channel
        and     [cd_status], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasRamdisk ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 1   ; we always have ramdisk
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasFloppy ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[DRIVE_DATA], 0
        setnz   al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasHd0 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [DRIVE_DATA + 1]
        and     al, 11000000b
        cmp     al, 01000000b
        setz    al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasHd1 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [DRIVE_DATA + 1]
        and     al, 00110000b
        cmp     al, 00010000b
        setz    al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasHd2 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [DRIVE_DATA + 1]
        and     al, 00001100b
        cmp     al, 00000100b
        setz    al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasHd3 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [DRIVE_DATA + 1]
        and     al, 00000011b
        cmp     al, 00000001b
        setz    al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasCd0 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [DRIVE_DATA + 1]
        and     al, 11000000b
        cmp     al, 10000000b
        setz    al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasCd1 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [DRIVE_DATA + 1]
        and     al, 00110000b
        cmp     al, 00100000b
        setz    al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasCd2 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [DRIVE_DATA + 1]
        and     al, 00001100b
        cmp     al, 00001000b
        setz    al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HasCd3 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, [DRIVE_DATA + 1]
        and     al, 00000011b
        cmp     al, 00000010b
        setz    al
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
;? fs_NextXXX functions
;-----------------------------------------------------------------------------------------------------------------------
;> eax = partition number, from which start to scan
;-----------------------------------------------------------------------------------------------------------------------
;< if CF = 1, no more partitions
;< if CF = 0,
;<   eax = next partition number
;-----------------------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_NextRamdisk ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; we always have /rd/1
        test    eax, eax
        stc
        jnz     @f
        mov     al, 1
        clc

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_NextFloppy ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; we have /fd/1 iff (([DRIVE_DATA] and 0xF0) != 0) and /fd/2 iff (([DRIVE_DATA] and 0x0F) != 0)
        test    byte[DRIVE_DATA], 0xf0
        jz      .no1
        test    eax, eax
        jnz     .no1
        inc     eax
        ret     ; CF cleared

  .no1:
        test    byte[DRIVE_DATA], 0x0f
        jz      .no2
        cmp     al, 2
        jae     .no2
        mov     al, 2
        clc
        ret

  .no2:
        stc
        ret
kendp

; on hdx, we have partitions from 1 to [0x40002+x]
;-----------------------------------------------------------------------------------------------------------------------
kproc fs_NextHd0 ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    0
        jmp     fs_NextHd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_NextHd1 ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    1
        jmp     fs_NextHd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_NextHd2 ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    2
        jmp     fs_NextHd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_NextHd3 ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    3
kendp

kproc fs_NextHd
        pop     ecx
        movzx   ecx, byte[DRIVE_DATA + 2 + ecx]
        cmp     eax, ecx
        jae     fs_NextFloppy.no2
        inc     eax
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_NextCd ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
; we always have /cdX/1
        test    eax, eax
        stc
        jnz     @f
        mov     al, 1
        clc

    @@: ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
;? Additional FS handlers.
;? This handler gets the control each time when fn 70 is called with unknown item of root subdirectory.
;-----------------------------------------------------------------------------------------------------------------------
;> esi = pointer to name
;> ebp = 0 or rest of name relative to esi
;-----------------------------------------------------------------------------------------------------------------------
;# if the handler processes path, he must not return in sysfn.file_system_lfn, but instead pop return address and return
;# directly to the caller; otherwise simply return
;-----------------------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
kproc biosdisk_handler ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; here we test for /bd<N>/... - BIOS disks

        cmp     [NumBiosDisks], 0
        jz      .ret
        mov     al, [esi]
        or      al, 0x20
        cmp     al, 'b'
        jnz     .ret
        mov     al, [esi + 1]
        or      al, 0x20
        cmp     al, 'd'
        jnz     .ret
        push    esi
        inc     esi
        inc     esi
        cmp     byte[esi], '0'
        jb      .ret2
        cmp     byte[esi], '9'
        ja      .ret2
        xor     edx, edx

    @@: lodsb
        test    al, al
        jz      .ok
        cmp     al, '/'
        jz      .ok
        sub     al, '0'
        cmp     al, 9
        ja      .ret2
        lea     edx, [edx * 5]
        lea     edx, [edx * 2 + eax]
        jmp     @b

  .ret2:
        pop     esi

  .ret:
        ret

  .ok:
        cmp     al, '/'
        jz      @f
        dec     esi

    @@: add     dl, 0x80
        xor     ecx, ecx

    @@: cmp     dl, [BiosDisksData + ecx * 4]
        jz      .ok2
        inc     ecx
        cmp     ecx, [NumBiosDisks]
        jb      @b
        jmp     .ret2

  .ok2:
        add     esp, 8
        test    al, al
        jnz     @f
        mov     esi, fs_BdNext
        jmp     sysfn.file_system_lfn.maindir_noesi

  @@:
        push    ecx
        push    fs_OnBd
        mov     edi, esp
        jmp     sysfn.file_system_lfn.found2
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_BdNext ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, [BiosDiskPartitions + ecx * 4]
        inc     eax
        cmc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnBd ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pop     edx edx
        ; edx = disk number, ecx = partition number
        ; esi+ebp = name
        call    reserve_hd1
        add     edx, 0x80
        mov     [hdpos], edx
        cmp     ecx, [BiosDiskPartitions + (edx - 0x80) * 4]
        jmp     fs_OnHdAndBd
kendp

;-----------------------------------------------------------------------------------------------------------------------
;? This handler is called when virtual root is enumerated and must return all items which can be handled by this.
;-----------------------------------------------------------------------------------------------------------------------
;> eax = 0 for first call, previously returned value for subsequent calls
;-----------------------------------------------------------------------------------------------------------------------
;< if eax = 0, no more items
;< if eax != 0,
;<   edi = pointer to name of item
;-----------------------------------------------------------------------------------------------------------------------
;# It is called several times
;-----------------------------------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------------------------------
kproc biosdisk_enum_root ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; here we enumerate existing BIOS disks /bd<N>

        cmp     eax, [NumBiosDisks]
        jae     .end
        push    eax
        movzx   eax, byte[BiosDisksData + eax * 4]
        sub     al, 0x80
        push    eax
        mov     al, 'b'
        stosb
        mov     al, 'd'
        stosb
        pop     eax
        cmp     al, 10
        jae     .big
        add     al, '0'
        stosb
        mov     byte[edi], 0
        pop     eax
        inc     eax
        ret

  .end:
        xor     eax, eax
        ret

  .big:
        push    ecx edx
        push    -'0'
        mov     ecx, 10

    @@: xor     edx, edx
        div     ecx
        push    edx
        test    eax, eax
        jnz     @b
        xchg    eax, edx

    @@: pop     eax
        add     al, '0'
        stosb
        jnz     @b
        pop     edx ecx
        pop     eax
        inc     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc process_replace_file_name ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, [full_file_name_table]
        mov     edi, [full_file_name_table.size]
        dec     edi
        shl     edi, 7
        add     edi, ebp

  .loop:
        cmp     edi, ebp
        jb      .notfound
        push    esi edi

    @@: cmp     byte[edi], 0
        jz      .dest_done
        lodsb
        test    al, al
        jz      .cont
        or      al, 0x20
        scasb
        jz      @b
        jmp     .cont

  .dest_done:
        cmp     byte[esi], 0
        jz      .found
        cmp     byte[esi], '/'
        jnz     .cont
        inc     esi
        jmp     .found

  .cont:
        pop     edi esi
        sub     edi, 128
        jmp     .loop

  .found:
        pop     edi eax
        mov     ebp, esi
        cmp     byte[esi], 0
        lea     esi, [edi + 64]
        jnz     .ret

  .notfound:
        xor     ebp, ebp

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.current_directory_ctl ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 30
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.current_directory_ctl, subfn, sysfn.not_implemented, \
    set, \ ; 1
    get ; 2
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        ; get length string of appdata.cur_dir
        mov     eax, [current_slot]
        mov     edi, [eax + app_data_t.cur_dir]

        jmp     [.subfn + ebx * 4]
kendp

max_cur_dir = 0x1000

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.current_directory_ctl.get ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 30.2
;-----------------------------------------------------------------------------------------------------------------------
;> ecx ^= buffer
;> edx #= buffer size
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebx, edi

        push    ecx
        push    edi

        xor     eax, eax
        mov     ecx, max_cur_dir

        repne
        scasb   ; find zerro at and string
        jnz     .error ; no zero in cur_dir: internal error, should not happen

        sub     edi, ebx ; lenght for copy
        inc     edi
        mov     [esp + 4 + 8 + regs_context32_t.eax], edi ; return in eax

        cmp     edx, edi
        jbe     @f
        mov     edx, edi

    @@: ; source string
        pop     esi
        ; destination string
        pop     edi
        cmp     edx, 1
        jbe     .ret

        mov     al, '/' ; start string with '/'
        stosb
        mov     ecx, edx
        rep
        movsb   ; copy string

  .ret:
        ret

  .error:
        add     esp, 8
        or      [esp + 4 + regs_context32_t.eax], -1 ; error not found zerro at string ->[eax+app_data_t.cur_dir]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.current_directory_ctl.set ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 30.1
;-----------------------------------------------------------------------------------------------------------------------
;> ecx ^= directory path string
;-----------------------------------------------------------------------------------------------------------------------
        ; use generic resolver with app_data_t.cur_dir as destination
        push    max_cur_dir ; 0x1000
        push    edi ; destination
        mov     ebx, ecx
        call    get_full_file_name
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_full_file_name ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx = file name
;> [esp + 4] = destination
;> [esp + 8] = sizeof destination
;-----------------------------------------------------------------------------------------------------------------------
;# destroys all registers except ebp,esp
;-----------------------------------------------------------------------------------------------------------------------
        push    ebp
        mov     esi, [current_slot]
        mov     esi, [esi + app_data_t.cur_dir]
        mov     edx, esi

    @@: inc     esi
        cmp     byte[esi - 1], 0
        jnz     @b
        dec     esi
        cmp     byte[ebx], '/'
        jz      .set_absolute
        ; string gives relative path
        mov     edi, [esp + 8] ; destination

  .relative:
        cmp     byte[ebx], 0
        jz      .set_ok
        cmp     word[ebx], '.'
        jz      .set_ok
        cmp     word[ebx], './'
        jnz     @f
        add     ebx, 2
        jmp     .relative

    @@: cmp     word[ebx], '..'
        jnz     .doset_relative
        cmp     byte[ebx + 2], 0
        jz      @f
        cmp     byte[ebx + 2], '/'
        jnz     .doset_relative

    @@: dec     esi
        cmp     byte[esi], '/'
        jnz     @b
        add     ebx, 3
        jmp     .relative

  .set_ok:
        cmp     edx, edi ; is destination equal to app_data_t.cur_dir?
        jz      .set_ok.cur_dir
        sub     esi, edx
        cmp     esi, [esp + 12]
        jb      .set_ok.copy

  .fail:
        mov     byte[edi], 0
        xor     eax, eax ; fail
        pop     ebp
        ret     8

  .set_ok.copy:
        mov     ecx, esi
        mov     esi, edx
        rep
        movsb
        mov     byte[edi], 0

  .ret.ok:
        mov     al, 1 ; ok
        pop     ebp
        ret     8

  .set_ok.cur_dir:
        mov     byte[esi], 0
        jmp     .ret.ok

  .doset_relative:
        cmp     edx, edi
        jz      .doset_relative.cur_dir
        sub     esi, edx
        cmp     esi, [esp + 12]
        jae     .fail
        mov     ecx, esi
        mov     esi, edx
        mov     edx, edi
        rep
        movsb
        jmp     .doset_relative.copy

  .doset_relative.cur_dir:
        mov     edi, esi

  .doset_relative.copy:
        add     edx, [esp + 12]
        mov     byte[edi], '/'
        inc     edi
        cmp     edi, edx
        jae     .overflow

    @@: mov     al, [ebx]
        inc     ebx
        stosb
        test    al, al
        jz      .ret.ok
        cmp     edi, edx
        jb      @b

  .overflow:
        dec     edi
        jmp     .fail

  .set_absolute:
        lea     esi, [ebx + 1]
        call    process_replace_file_name
        mov     edi, [esp + 8]
        mov     edx, [esp + 12]
        add     edx, edi

  .set_copy:
        lodsb
        stosb
        test    al, al
        jz      .set_part2

  .set_copy_cont:
        cmp     edi, edx
        jb      .set_copy
        jmp     .overflow

  .set_part2:
        mov     esi, ebp
        xor     ebp, ebp
        test    esi, esi
        jz      .ret.ok
        mov     byte[edi - 1], '/'
        jmp     .set_copy_cont
kendp
