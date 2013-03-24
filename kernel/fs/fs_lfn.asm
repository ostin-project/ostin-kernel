;;======================================================================================================================
;;///// fs_lfn.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011-2012 Ostin project <http://ostin.googlecode.com/>
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

iglobal
  ; in this table names must be in lowercase
  rootdirs:

if KCONFIG_BLK_MEMORY

    db 2, 'rd'
    dd fs_OnGenericQuery ; fs_OnRamdisk
    dd fs_NextRamdisk
    db 7, 'ramdisk'
    dd fs_OnGenericQuery ; fs_OnRamdisk
    dd fs_NextRamdisk

end if ; KCONFIG_BLK_MEMORY

if KCONFIG_BLK_FLOPPY

    db 2, 'fd'
    dd fs_OnGenericQuery2 ; fs_OnFloppy
    dd fs_NextFloppy
    db 10, 'floppydisk'
    dd fs_OnGenericQuery2 ; fs_OnFloppy
    dd fs_NextFloppy

end if ; KCONFIG_BLK_FLOPPY

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

if KCONFIG_BLK_ATAPI

    db 3, 'cd0'
    dd fs_OnGenericQuery4 ; fs_OnCd0
    dd fs_NextCd
    db 3, 'cd1'
    dd fs_OnGenericQuery4 ; fs_OnCd1
    dd fs_NextCd
    db 3, 'cd2'
    dd fs_OnGenericQuery4 ; fs_OnCd2
    dd fs_NextCd
    db 3, 'cd3'
    dd fs_OnGenericQuery4 ; fs_OnCd3
    dd fs_NextCd

end if ; KCONFIG_BLK_ATAPI

    db 0

  virtual_root_query:

if KCONFIG_BLK_MEMORY

    dd fs_HasRamdisk
    db 'rd', 0

end if ; KCONFIG_BLK_MEMORY

if KCONFIG_BLK_FLOPPY

    dd fs_HasFloppy
    db 'fd', 0

end if ; KCONFIG_BLK_FLOPPY

    dd fs_HasHd0
    db 'hd0', 0
    dd fs_HasHd1
    db 'hd1', 0
    dd fs_HasHd2
    db 'hd2', 0
    dd fs_HasHd3
    db 'hd3', 0

if KCONFIG_BLK_ATAPI

    dd fs_HasCd0
    db 'cd0', 0
    dd fs_HasCd1
    db 'cd1', 0
    dd fs_HasCd2
    db 'cd2', 0
    dd fs_HasCd3
    db 'cd3', 0

end if ; KCONFIG_BLK_ATAPI

    dd 0

  fs_additional_handlers:
    dd biosdisk_handler, biosdisk_enum_root
    dd blkdev_handler, blkdev_enum_root
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
endg

uglobal
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
        lea     esi, [ebx + fs.query_t.path]
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

    @@: mov     esi, [current_slot_ptr]
        mov     esi, [esi + legacy.slot_t.app.cur_dir]
        jmp     .parse_normal

  .notcurdir:
        cmp     byte[esi], 0
        jz      .rootdir
        call    process_replace_file_name

  .parse_normal:
        cmp     [ebx + fs.query_t.function], FS_FUNC_EXECUTE
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
        cmp     [ebx + fs.query_t.function], FS_FUNC_READ_DIR
        jnz     .access_denied
        xor     eax, eax
        mov     ebp, [ebx + fs.query_t.read_directory.count] ; blocks to read
        mov     edx, [ebx + fs.query_t.read_directory.buffer_ptr] ; result buffer ptr
;       add     edx, new_app_base
        push    [ebx + fs.query_t.read_directory.start_block] ; first block
        mov     ebx, [ebx + fs.query_t.read_directory.flags] ; flags
        ; ebx=flags, [esp]=first block, ebp=number of blocks, edx=return area, esi='Next' handler
        mov     edi, edx
        push    ecx
        mov     ecx, sizeof.fs.file_info_header_t / 4
        rep
        stosd
        pop     ecx
        mov     byte[edx + fs.file_info_header_t.version], 1 ; version

  .maindir_loop:
        call    esi
        jc      .maindir_done
        inc     [edx + fs.file_info_header_t.files_count]
        dec     dword[esp]
        jns     .maindir_loop
        dec     ebp
        js      .maindir_loop
        inc     [edx + fs.file_info_header_t.files_read]
        mov     [edi + fs.file_info_t.attributes], FS_INFO_ATTR_DIR ; attributes: folder
        mov     [edi + fs.file_info_t.flags], FS_INFO_FLAG_UNICODE ; name type: UNICODE
        push    eax
        xor     eax, eax
        add     edi, 8
        push    ecx
        mov     ecx, (sizeof.fs.file_info_t - 8) / 4
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
        test    bl, FS_INFO_FLAG_UNICODE ; UNICODE name?
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
        test    bl, FS_INFO_FLAG_UNICODE
        jnz     @f
        sub     edi, 520 - 264

    @@: pop     edx eax
        jmp     .maindir_loop

  .maindir_done:
        pop     eax
        mov     ebx, [edx + fs.file_info_header_t.files_read]
        xor     eax, eax
        dec     ebp
        js      @f
        mov     al, ERROR_END_OF_FILE

    @@: mov     [esp + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + regs_context32_t.ebx], ebx
        ret

  .rootdir:
        ; directory /
        cmp     [ebx + fs.query_t.function], FS_FUNC_READ_DIR ; read folder?
        jz      .readroot

  .access_denied:
        mov     [esp + 4 + regs_context32_t.eax], ERROR_ACCESS_DENIED ; access denied
        ret

  .readroot:
        ; virtual root folder - special handler
        mov     esi, virtual_root_query
        mov     ebp, [ebx + fs.query_t.read_directory.count]
        mov     edx, [ebx + fs.query_t.read_directory.buffer_ptr]
;       add     edx, new_app_base
        push    [ebx + fs.query_t.read_directory.start_block] ; first block
        mov     ebx, [ebx + fs.query_t.read_directory.flags] ; flags
        xor     eax, eax
        ; eax=0, [esp]=first block, ebx=flags, ebp=number of blocks, edx=return area
        mov     edi, edx
        mov     ecx, sizeof.fs.file_info_header_t / 4
        rep
        stosd
        mov     byte[edx + fs.file_info_header_t.version], 1 ; version

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
        inc     [edx + fs.file_info_header_t.files_count]
        dec     dword[esp]
        jns     .readroot_next
        dec     ebp
        js      .readroot_next
        inc     [edx + fs.file_info_header_t.files_read]
        mov     [edi + fs.file_info_t.attributes], FS_INFO_ATTR_DIR ; attributes: folder
        mov     [edi + fs.file_info_t.flags], ebx ; name type: UNICODE
        add     edi, 8
        mov     ecx, (sizeof.fs.file_info_t - 8) / 4
        rep
        stosd
        push    edi

    @@: lodsb
        stosb
        test    bl, FS_INFO_FLAG_UNICODE
        jz      .ansi
        mov     byte[edi], 0
        inc     edi

  .ansi:
        test    eax, eax
        jnz     @b
        pop     edi
        add     edi, 520
        test    bl, FS_INFO_FLAG_UNICODE
        jnz     .readroot_loop
        sub     edi, 520 - 264
        jmp     .readroot_loop

  .readroot_done_static:
        mov     esi, fs_additional_handlers - 8
        sub     esp, BLK_MAX_DEVICE_NAME_LEN

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
        inc     [edx + fs.file_info_header_t.files_count]
        dec     dword[esp + BLK_MAX_DEVICE_NAME_LEN]
        jns     .readroot_ah_loop2
        dec     ebp
        js      .readroot_ah_loop2
        push    eax
        xor     eax, eax
        inc     [edx + fs.file_info_header_t.files_read]
        mov     [edi + fs.file_info_t.attributes], FS_INFO_ATTR_DIR ; attributes: folder
        mov     [edi + fs.file_info_t.flags], ebx
        add     edi, 8
        mov     ecx, (sizeof.fs.file_info_t - 8) / 4
        rep
        stosd
        push    esi edi
        lea     esi, [esp + 12]

    @@: lodsb
        stosb
        test    bl, FS_INFO_FLAG_UNICODE
        jz      .ansi3
        mov     byte[edi], 0
        inc     edi

  .ansi3:
        test    al, al
        jnz     @b
        pop     edi esi eax
        add     edi, 520
        test    bl, FS_INFO_FLAG_UNICODE
        jnz     .readroot_ah_loop2
        sub     edi, 520 - 264
        jmp     .readroot_ah_loop2

  .readroot_done:
        add     esp, BLK_MAX_DEVICE_NAME_LEN
        pop     eax
        mov     ebx, [edx + fs.file_info_header_t.files_read]
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
        add     eax, [edx + fs.partition_t._.vftbl]
        mov     eax, [eax]
        test    eax, eax
        jz      sysfn.not_implemented

        xchg    ebx, edx
        add     edx, fs.query_t.generic ; ^= fs.?_query_params_t

        call    fs.lock
        push    ebx

        call    eax
        mov     [esp + 4 + 4 + regs_context32_t.eax], eax
        mov     [esp + 4 + 4 + regs_context32_t.ebx], ebx

        pop     ebx
        call    fs.unlock

        ret
kendp

iglobal
  if KCONFIG_BLK_MEMORY

  align 4
  ; blk.memory.device_t
  static_test_ram_device:
    ; linked_list_t
    dd 0, 0
    ; _.vftbl
    dd blk.memory.vftbl
    ; _.name
    db 'rd', BLK_MAX_DEVICE_NAME_LEN - 2 dup(0)
    ; _.partitions
    dd $, $ - 4
    ; data
    dd RAMDISK ; address
    dd 2 * 80 * 18 ; size
    ; needs_free
    db 0

  assert $ - static_test_ram_device = sizeof.blk.memory.device_t

  align 4
  ; fs.fat.fat12.partition_t
  static_test_ram_partition:
    ; linked_list_t
    dd 2 dup(static_test_ram_partition + blk.device_t._.partitions)
    ; _.vftbl
    dd fs.fat.vftbl
    ; _.mutex
    rb sizeof.mutex_t
    ; _.device
    dd static_test_ram_device
    ; _.range
    dq 0 ; offset
    dq 2 * 80 * 18 ; length
    ; _.number
    db 1
    ; fat_vftbl
    dd fs.fat.fat12.vftbl
    ; fat_sector
    dd 1
    ; fat_size
    dd 9
    ; root_dir_sector
    dd 19
    ; data_area_sector
    dd 33
    ; cluster_size
    dd 1
    ; buffer
    rb 2 * 512
    ; FATx partition-specific data
    rb sizeof.fs.fat.fat12.partition_t - sizeof.fs.fat.partition_t

  assert $ - static_test_ram_partition = sizeof.fs.fat.fat12.partition_t

  end if ; KCONFIG_BLK_MEMORY
endg

if KCONFIG_BLK_MEMORY

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnGenericQuery ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, static_test_ram_partition
        mov     [edx + fs.fat.fat12.partition_t.root_dir_size], 14
        mov     [edx + fs.fat.fat12.partition_t.max_cluster], 9 * 512 * 2 / 3
        jmp     fs.generic_query_handler
kendp

end if ; KCONFIG_BLK_MEMORY

iglobal
  if KCONFIG_BLK_FLOPPY

  align 4
  ; blk.floppy.ctl.device_t
  static_test_floppy_ctl_device_data:
    ; base_reg
    dw 0x03f0
    ; position
    db sizeof.chs8x8x8_t dup(0)
    ; status
    db sizeof.blk.floppy.ctl.status_t dup(0)
    ; motor_timer
    dd 4 dup(0)
    ; drive_number
    db -1

  assert $ - static_test_floppy_ctl_device_data = sizeof.blk.floppy.ctl.device_t

  align 4
  ; blk.floppy.device_t
  static_test_floppy_device:
    ; linked_list_t
    dd 0, 0
    ; _.vftbl
    dd blk.floppy.vftbl
    ; _.name
    db 'fd', BLK_MAX_DEVICE_NAME_LEN - 2 dup(0)
    ; _.partitions
    dd $, $ - 4
    ; ctl
    dd static_test_floppy_ctl_device_data
    ; drive_number
    db 0

  assert $ - static_test_floppy_device = sizeof.blk.floppy.device_t

  align 4
  ; fs.fat.fat12.partition_t
  static_test_floppy_partition:
    ; linked_list_t
    dd 2 dup(static_test_floppy_device + blk.device_t._.partitions)
    ; _.vftbl
    dd fs.fat.vftbl
    ; _.mutex
    rb sizeof.mutex_t
    ; _.device
    dd static_test_floppy_device
    ; _.range
    dq 0 ; offset
    dq 2 * 80 * 18 ; length
    ; _.number
    db 1
    ; fat_vftbl
    dd fs.fat.fat12.vftbl
    ; fat_sector
    dd 1
    ; fat_size
    dd 9
    ; root_dir_sector
    dd 19
    ; data_area_sector
    dd 33
    ; cluster_size
    dd 1
    ; buffer
    rb 2 * 512
    ; FATx partition-specific data
    rb sizeof.fs.fat.fat12.partition_t - sizeof.fs.fat.partition_t

  assert $ - static_test_floppy_partition = sizeof.fs.fat.fat12.partition_t

  end if ; KCONFIG_BLK_FLOPPY
endg

if KCONFIG_BLK_FLOPPY

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnGenericQuery2 ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, static_test_floppy_partition
        mov     [edx + fs.fat.fat12.partition_t.root_dir_size], 14
        mov     [edx + fs.fat.fat12.partition_t.max_cluster], 9 * 512 * 2 / 3
        jmp     fs.generic_query_handler
kendp

end if ; KCONFIG_BLK_FLOPPY

iglobal
  if KCONFIG_BLK_ATAPI

  align 4
  ; blk.atapi.ctl.device_t
  static_test_atapi_ctl_device_data:
    ; base_reg
    dw 0x01f0
    ; dev_ctl_reg
    dw 0x03f4
    ; last_drive_number
    db -1

  assert $ - static_test_atapi_ctl_device_data = sizeof.blk.atapi.ctl.device_t

  align 4
  ; blk.atapi.device_t
  static_test_atapi_device:
    ; linked_list_t
    dd 0, 0
    ; _.vftbl
    dd blk.atapi.vftbl
    ; _.name
    db 'cd', BLK_MAX_DEVICE_NAME_LEN - 2 dup(0)
    ; _.partitions
    dd $, $ - 4
    ; ctl
    dd static_test_atapi_ctl_device_data
    ; drive_number
    db 0
    ; ident
    rb 512

  assert $ - static_test_atapi_device = sizeof.blk.atapi.device_t

  align 4
  ; fs.cdfs.partition_t
  static_test_atapi_partition:
    ; linked_list_t
    dd 2 dup(static_test_atapi_device + blk.device_t._.partitions)
    ; _.vftbl
    dd fs.cdfs.vftbl
    ; _.mutex
    rb sizeof.mutex_t
    ; _.device
    dd static_test_atapi_device
    ; _.range
    dq 0 ; offset
    dq 360000 * 4 ; length
    ; _.number
    db 1
    ; partition-specific data
    rb sizeof.fs.cdfs.partition_t - sizeof.fs.partition_t

  assert $ - static_test_atapi_partition = sizeof.fs.cdfs.partition_t

  end if ; KCONFIG_BLK_ATAPI
endg

if KCONFIG_BLK_ATAPI

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnGenericQuery4 ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edx, static_test_atapi_partition
        jmp     fs.generic_query_handler
kendp

end if ; KCONFIG_BLK_ATAPI

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
        MovStk  eax, ERROR_NOT_IMPLEMENTED
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.unknown_filesystem ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        MovStk  eax, ERROR_UNKNOWN_FS
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.file_not_found ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        MovStk  eax, ERROR_FILE_NOT_FOUND
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.disk_full ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        MovStk  eax, ERROR_DISK_FULL
        xor     ebx, ebx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.error.access_denied ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        MovStk  eax, ERROR_ACCESS_DENIED
        or      ebx, -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_OnGenericQuery3 ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        add     esp, 4
        add     edi, [current_partition._.vftbl]
        cmp     edi, [esp - 4]
        je      fs.error.unknown_filesystem

        cmp     dword[edi], 0
        je      fs.error.not_implemented

        jmp     dword[edi]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdRead ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

        mov     edi, fs.vftbl_t.read_file
        jmp     fs_OnGenericQuery3
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdReadFolder ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, fs.vftbl_t.read_directory
        jmp     fs_OnGenericQuery3
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdRewrite ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        xor     eax, eax
        mov     edi, fs.vftbl_t.create_file

  .direct:
        cmp     byte[esi], 0
        je      fs.error.access_denied

        jmp     fs_OnGenericQuery3
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdWrite ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

        mov     edi, fs.vftbl_t.write_file
        jmp     fs_OnGenericQuery3
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdSetFileEnd ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

        mov     edi, fs.vftbl_t.truncate_file
        jmp     fs_OnGenericQuery3
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdGetFileInfo ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, fs.vftbl_t.get_file_info
        jmp     fs_OnGenericQuery3
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdSetFileInfo ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     edi, fs.vftbl_t.set_file_info
        jmp     fs_OnGenericQuery3
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdDelete ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        je      fs.error.access_denied

        mov     edi, fs.vftbl_t.delete_file
        jmp     fs_OnGenericQuery3
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs_HdCreateFolder ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     al, 1
        mov     edi, fs.vftbl_t.create_directory
        jmp     fs_HdRewrite.direct
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
kproc blkdev_handler ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    edi
        mov     ecx, blkdev_list

  .next_device:
        mov     ecx, [ecx + blk.device_t.next_ptr]
        cmp     ecx, blkdev_list
        je      .not_found

        lea     edi, [ecx + blk.device_t._.name]
        push    esi

    @@: lodsb
        or      al, 0x20
        scasb
        je      @b

        cmp     byte[esi - 1], '/'
        jne     @f

        cmp     byte[esi], 0
        jne     .handle_partition

        inc     esi

    @@: cmp     byte[esi - 1], 0
        pop     esi
        jne     .next_device
        cmp     byte[edi - 1], 0
        jne     .next_device

        pop     edi
        add     esp, 4
        mov     esi, blkdev_next_partition
        jmp     sysfn.file_system_lfn.maindir_noesi

  .handle_partition:
        add     esp, 3 * 4
        push    ecx
        push    blkdev_partition_handler
        mov     edi, esp
        jmp     sysfn.file_system_lfn.found2

  .not_found:
        pop     edi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev_partition_handler ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pop     edx edx ; edx ^= blk.device_t, ecx #= partition number

        add     edx, blk.device_t._.partitions
        mov     eax, edx

  .next_partition:
        mov     edx, [edx + fs.partition_t.next_ptr]
        cmp     edx, eax
        je      fs.error.file_not_found

        cmp     [edx + fs.partition_t._.number], cl
        jne     .next_partition

        jmp     fs.generic_query_handler
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc blkdev_next_partition ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax #= partition number
;> ecx ^= blk.device_t
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx edx
        add     ecx, blk.device_t._.partitions
        mov     edx, ecx

  .next_partition:
        mov     edx, [edx + fs.partition_t.next_ptr]
        cmp     edx, ecx
        je      .error

        test    eax, eax
        jz      .exit

        cmp     al, [edx + fs.partition_t._.number]
        jne     .next_partition

        mov     edx, [edx + fs.partition_t.next_ptr]
        cmp     edx, ecx
        je      .error

  .exit:
        movzx   eax, [edx + fs.partition_t._.number]
        pop     edx ecx
        clc
        ret

  .error:
        pop     edx ecx
        stc
        ret
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
kproc blkdev_enum_root ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        test    eax, eax
        jnz     @f

        mov     eax, blkdev_list

    @@: mov     eax, [eax + blk.device_t.next_ptr]
        cmp     eax, blkdev_list
        je      .end

        push    eax esi
        lea     esi, [eax + blk.device_t._.name]

    @@: lodsb
        stosb
        test    al, al
        jz      .exit
        jmp     @b

  .exit:
        pop     esi eax
        ret

  .end:
        xor     eax, eax
        ret
kendp

iglobal
  ; pointer to memory for path replace table,
  ; size of one record is 128 bytes: 64 bytes for search pattern + 64 bytes for replace string

  ; start with one entry: sys -> <sysdir>
  full_file_name_table dd syslibdir_name
    .size              dd 2

  syslibdir_name db 'sys/lib', 0
                 rb 64 - ($ - syslibdir_name)
  syslibdir_path db 'rd/1/dll', 0
                 rb 64 - ($ - syslibdir_path)
  sysdir_name    db 'sys', 0
                 rb 64 - ($ - sysdir_name)
  sysdir_path    db 'rd/1', 0
                 rb 64 - ($ - sysdir_path)
endg

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
  JumpTable sysfn.current_directory_ctl, subfn, sysfn.not_implemented, \
    set, \ ; 1
    get ; 2
endg
;-----------------------------------------------------------------------------------------------------------------------
        dec     ebx
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        ; get length string of appdata.cur_dir
        mov     eax, [current_slot_ptr]
        mov     edi, [eax + legacy.slot_t.app.cur_dir]

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
        or      [esp + 4 + regs_context32_t.eax], -1 ; 0-terminator not found
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.current_directory_ctl.set ;/////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 30.1
;-----------------------------------------------------------------------------------------------------------------------
;> ecx ^= directory path string
;-----------------------------------------------------------------------------------------------------------------------
        ; use generic resolver with legacy.slot_t.app.cur_dir as destination
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
        mov     esi, [current_slot_ptr]
        mov     esi, [esi + legacy.slot_t.app.cur_dir]
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
        cmp     edx, edi ; is destination equal to legacy.slot_t.app.cur_dir?
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
