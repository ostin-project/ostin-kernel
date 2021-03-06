;;======================================================================================================================
;;///// ext2.asm /////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2012 Ostin project <http://ostin.googlecode.com/>
;; (c) 2010 KolibriOS team <http://kolibrios.org/>
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

struct fs.ext2.partition_data_t
  log_block_size                dd ?
  block_size                    dd ?
  count_block_in_block          dd ?
  blocks_per_group              dd ?
  inodes_per_group              dd ?
  global_desc_table             dd ?
  root_inode                    dd ? ; pointer to root inode in memory
  inode_size                    dd ?
  count_pointer_in_block        dd ? ; block_size / 4
  count_pointer_in_block_square dd ? ; (block_size / 4)**2
  ext2_save_block               dd ? ; block for 1 global procedure
  ext2_temp_block               dd ? ; block for small procedures
  ext2_save_inode               dd ? ; inode for global procedure
  ext2_temp_inode               dd ? ; inode for small procedures
  sb                            dd ? ; superblock
  groups_count                  dd ?
ends

iglobal
  JumpTable fs.ext2, vftbl, 0, \
    read_file, \
    read_directory, \
    -, \
    -, \
    -, \
    get_file_info, \
    -, \
    -, \
    -, \
    -
endg

EXT2_BAD_INO         = 1
EXT2_ROOT_INO        = 2
EXT2_ACL_IDX_INO     = 3
EXT2_ACL_DATA_INO    = 4
EXT2_BOOT_LOADER_INO = 5
EXT2_UNDEL_DIR_INO   = 6

; type inode
EXT2_S_IFREG         = 0x8000
EXT2_S_IFDIR         = 0x4000
; user inode right's
EXT2_S_IRUSR         = 0x0100
EXT2_S_IWUSR         = 0x0080
EXT2_S_IXUSR         = 0x0040
; group inode right's
EXT2_S_IRGRP         = 0x0020
EXT2_S_IWGRP         = 0x0010
EXT2_S_IXGRP         = 0x0008
; other inode right's
EXT2_S_IROTH         = 0x0004
EXT2_S_IWOTH         = 0x0002
EXT2_S_IXOTH         = 0x0001
EXT2_777_MODE        = EXT2_S_IROTH or EXT2_S_IWOTH or EXT2_S_IXOTH or \
                       EXT2_S_IRGRP or EXT2_S_IWGRP or EXT2_S_IXGRP or \
                       EXT2_S_IRUSR or EXT2_S_IWUSR or EXT2_S_IXUSR

EXT2_FT_REG_FILE     = 1    ; it's a file, record in parent directory
EXT2_FT_DIR          = 2    ; it's a directory

EXT2_FEATURE_INCOMPAT_FILETYPE = 0x0002

uglobal
  EXT2_files_in_folder dd ? ; number of files in directory
  EXT2_read_in_folder  dd ? ; how many file did we read
  EXT2_end_block       dd ? ; end of next directory block
  EXT2_counter_blocks  dd ?
  EXT2_filename        db 256 dup(?)
  EXT2_parent_name     db 256 dup(?)
  EXT2_name_len        dd ?
endg

struct ext2_inode_t
  i_mode        dw ?
  i_uid         dw ?
  i_size        dd ?
  i_atime       dd ?
  i_ctime       dd ?
  i_mtime       dd ?
  i_dtime       dd ?
  i_gid         dw ?
  i_links_count dw ?
  i_blocks      dd ?
  i_flags       dd ?
  i_osd1        dd ?
  i_block       dd 15 dup(?)
  i_generation  dd ?
  i_file_acl    dd ?
  i_dir_acl     dd ?
  i_faddr       dd ?
  i_osd2        dd ? ; 1..12
ends

struct ext2_dir_t
  inode     dd ?
  rec_len   dw ?
  name_len  db ?
  file_type db ?
  name      db ? ; 0..255
ends

struct ext2_block_group_descriptor_t
  block_bitmap      dd ?
  inode_bitmap      dd ?
  inode_table       dd ?
  free_blocks_count dw ?
  free_inodes_count dw ?
  used_dirs_count   dw ?
ends

struct ext2_sb_t
  inodes_count          dd ? ; +0
  blocks_count          dd ? ; +4
  r_block_count         dd ? ; +8
  free_block_count      dd ? ; +12
  free_inodes_count     dd ? ; +16
  first_data_block      dd ? ; +20
  log_block_size        dd ? ; +24
  log_frag_size         dd ? ; +28
  blocks_per_group      dd ? ; +32
  frags_per_group       dd ? ; +36
  inodes_per_group      dd ? ; +40
  mtime                 dd ? ; +44
  wtime                 dd ? ; +48
  mnt_count             dw ? ; +52
  max_mnt_count         dw ? ; +54
  magic                 dw ? ; +56
  state                 dw ? ; +58
  errors                dw ? ; +60
  minor_rev_level       dw ? ; +62
  lastcheck             dd ? ; +64
  check_intervals       dd ? ; +68
  creator_os            dd ? ; +72
  rev_level             dd ? ; +76
  def_resuid            dw ? ; +80
  def_resgid            dw ? ; +82
  first_ino             dd ? ; +84
  inode_size            dw ? ; +88
  block_group_nr        dw ? ; +90
  feature_compat        dd ? ; +92
  feature_incompat      dd ? ; +96
  feature_ro_compat     dd ? ; +100
  uuid                  uuid_t ; +104
  volume_name           db 16 dup(?) ; +120
  last_mounted          db 64 dup(?) ; +136
  algo_bitmap           dd ? ; +200
  prealloc_blocks       db ? ; +204
  preallock_dir_blocks  db ? ; +205
                        dw ? ; +206 alignment
  journal_uuid          uuid_t ; +208
  journal_inum          dd ? ; +224
  journal_dev           dd ? ; +228
  last_orphan           dd ? ; +232
  hash_seed             dd 4 dup(?) ; +236
  def_hash_version      db ? ; +252
                        db 3 dup(?) ; +253 reserved
  default_mount_options dd ? ; +256
  first_meta_bg         dd ? ; +260
ends

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.ext2.create_from_base ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ebx ^= fs.partition_t (base)
;> edi ^= ext2_sb_t
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_DEBUG, "fs.ext2.create_from_base\n"

        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_test_superblock ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       cmp     [current_partition._.type], MBR_PART_TYPE_LINUX_NATIVE
;       jne     .no

        mov     eax, dword[current_partition._.range.offset]
        add     eax, 2 ; superblock start at 1024b
        call    hd_read

        cmp     [ebx + ext2_sb_t.log_block_size], 3 ; s_block_size 0,1,2,3
        ja      .no
        cmp     [ebx + ext2_sb_t.magic], 0xef53 ; s_magic
        jne     .no
        cmp     [ebx + ext2_sb_t.state], 1 ; s_state (EXT_VALID_FS=1)
        jne     .no
        mov     eax, [ebx + ext2_sb_t.feature_incompat]
        test    eax, EXT2_FEATURE_INCOMPAT_FILETYPE
        jz      .no
        test    eax, not EXT2_FEATURE_INCOMPAT_FILETYPE
        jnz     .no

        ; OK, this is correct EXT2 superblock
        clc
        ret

  .no:
        ; No, this superblock isn't EXT2
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_setup ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [current_partition._.vftbl], fs.ext2.vftbl

        push    512
        call    kernel_alloc ; mem for superblock
        mov     esi, ebx
        mov     edi, eax
        mov     ecx, 512 / 4
        rep
        movsd   ; copy sb to reserved mem
        mov     ebx, eax
        mov     [ext2_data.sb], eax

        mov     eax, [ebx + ext2_sb_t.blocks_count]
        sub     eax, [ebx + ext2_sb_t.first_data_block]
        dec     eax
        xor     edx, edx
        div     [ebx + ext2_sb_t.blocks_per_group]
        inc     eax
        mov     [ext2_data.groups_count], eax

        mov     ecx, [ebx + ext2_sb_t.log_block_size]
        inc     ecx
        mov     [ext2_data.log_block_size], ecx ; 1, 2, 3, 4   equ 1kb, 2kb, 4kb, 8kb

        mov     eax, 1
        shl     eax, cl
        mov     [ext2_data.count_block_in_block], eax

        shl     eax, 7
        mov     [ext2_data.count_pointer_in_block], eax
        mov     edx, eax ; we'll find a square later

        shl     eax, 2
        mov     [ext2_data.block_size], eax

        push    eax eax ; 2 kernel_alloc

        mov     eax, edx
        mul     edx
        mov     [ext2_data.count_pointer_in_block_square], eax

        call    kernel_alloc
        mov     [ext2_data.ext2_save_block], eax ; and for temp block
        call    kernel_alloc
        mov     [ext2_data.ext2_temp_block], eax ; and for get_inode proc

        movzx   ebp, word[ebx + ext2_sb_t.inode_size]
        mov     ecx, [ebx + ext2_sb_t.blocks_per_group]
        mov     edx, [ebx + ext2_sb_t.inodes_per_group]

        mov     [ext2_data.inode_size], ebp
        mov     [ext2_data.blocks_per_group], ecx
        mov     [ext2_data.inodes_per_group], edx

        push    ebp ebp ebp ; 3 kernel_alloc
        call    kernel_alloc
        mov     [ext2_data.ext2_save_inode], eax
        call    kernel_alloc
        mov     [ext2_data.ext2_temp_inode], eax
        call    kernel_alloc
        mov     [ext2_data.root_inode], eax

        mov     ebx, eax
        mov     eax, EXT2_ROOT_INO
        call    ext2_get_inode ; read root inode

        jmp     return_from_part_set
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_get_block ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = i_block
;> ebx = pointer to return memory
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx
        mov     ecx, [ext2_data.log_block_size]
        shl     eax, cl
        add     eax, dword[current_partition._.range.offset]
        mov     ecx, [ext2_data.count_block_in_block]

    @@: call    hd_read
        inc     eax
        add     ebx, 512
        loop    @b
        pop     ecx ebx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_get_inode_block ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = number of block in inode (0..)
;> ebp = inode address
;-----------------------------------------------------------------------------------------------------------------------
;< ecx = next block address
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ecx, 12 ; 0..11 - direct block address
        jb      .get_direct_block

        sub     ecx, 12
        cmp     ecx, [ext2_data.count_pointer_in_block] ; 12.. - indirect block
        jb      .get_indirect_block

        sub     ecx, [ext2_data.count_pointer_in_block]
        cmp     ecx, [ext2_data.count_pointer_in_block_square]
        jb      .get_double_indirect_block

        sub     ecx, [ext2_data.count_pointer_in_block_square]

; .get_triple_indirect_block:
        push    eax edx ebx

        mov     eax, [ebx + ext2_inode_t.i_block + 14 * 4]
        mov     ebx, [ext2_data.ext2_temp_block]
        call    ext2_get_block

        xor     edx, edx
        mov     eax, ecx
        div     [ext2_data.count_pointer_in_block_square]

        ; eax - current block number, edx - next block number
        mov     eax, [ebx + eax * 4]
        call    ext2_get_block

        mov     eax, edx
        jmp     @f

  .get_double_indirect_block:
        push    eax edx ebx

        mov     eax, [ebp + ext2_inode_t.i_block + 13 * 4]
        mov     ebx, [ext2_data.ext2_temp_block]
        call    ext2_get_block

        mov     eax, ecx

    @@: xor     edx, edx
        div     [ext2_data.count_pointer_in_block]

        mov     eax, [ebx + eax * 4]
        call    ext2_get_block
        mov     ecx, [ebx + edx * 4]

        pop     ebx edx eax
        ret

  .get_indirect_block:
        push    eax ebx
        mov     eax, [ebp + ext2_inode_t.i_block + 12 * 4]
        mov     ebx, [ext2_data.ext2_temp_block]
        call    ext2_get_block

        mov     ecx, [ebx + ecx * 4]
        pop     ebx eax
        ret

  .get_direct_block:
        mov     ecx, [ebp + ext2_inode_t.i_block + ecx * 4]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_get_inode ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? get content inode by num
;-----------------------------------------------------------------------------------------------------------------------
;> eax = inode_num
;> ebx = address of inode content
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        mov     edi, ebx ; saving inode address
        dec     eax
        xor     edx, edx
        div     [ext2_data.inodes_per_group]

        push    edx ; locale num in group

        mov     edx, 32
        mul     edx ; address block_group in global_desc_table

        ; in eax - inode group offset relative to global descriptor table start
        ; lets find block this inode is in

        div     [ext2_data.block_size]
        mov     ecx, [ext2_data.sb]
        add     eax, [ecx + ext2_sb_t.first_data_block]
        inc     eax
        mov     ebx, [ext2_data.ext2_temp_block]
        call    ext2_get_block

        add     ebx, edx ; local number inside block
        mov     eax, [ebx + 8] ; block number - in terms of ext2

        mov     ecx, [ext2_data.log_block_size]
        shl     eax, cl
        add     eax, dword[current_partition._.range.offset] ; partition start - in terms of hdd (512)

        ; eax - points to inode table on hdd
        mov     esi, eax ; lets save it in esi for now

        ; add local address of inode
        pop     eax ; index
        mov     ecx, [ext2_data.inode_size]
        mul     ecx ; (index * inode_size)
        mov     ebp, 512
        div     ebp ; divide by block size

        add     eax, esi ; found block address to read
        mov     ebx, [ext2_data.ext2_temp_block]
        call    hd_read

        mov     esi, edx ; add the "remainder"
        add     esi, ebx ; to the address
;       mov     ecx, [ext2_data.inode_size]
        rep
        movsb   ; copy inode
        popad
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_test_block_by_name ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi = children
;> ebx = pointer to dir block
;-----------------------------------------------------------------------------------------------------------------------
;< esi = name without parent or not_changed
;< ebx = dir_rec of inode children or trash
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ecx edx edi

        mov     edx, ebx
        add     edx, [ext2_data.block_size] ; save block end

  .start_rec:
        cmp     [ebx + ext2_dir_t.inode], 0
        jz      .next_rec

        push    esi
        movzx   ecx, [ebx + ext2_dir_t.name_len]
        mov     edi, EXT2_filename
        lea     esi, [ebx + ext2_dir_t.name]

        call    utf8toansi_str
        mov     ecx, edi
        sub     ecx, EXT2_filename ; number of bytes in resulting string

        mov     edi, EXT2_filename
        mov     esi, [esp]

    @@: jecxz   .test_find
        dec     ecx

        lodsb
        call    char_toupper

        mov     ah, [edi]
        inc     edi
        xchg    al, ah
        call    char_toupper
        cmp     al, ah
        je      @B

    @@: ; didn't fit
        pop     esi

  .next_rec:
        movzx   eax, [ebx + ext2_dir_t.rec_len]
        add     ebx, eax ; go to next record
        cmp     ebx, edx ; check if this is the end
        jb      .start_rec
        jmp     .ret

  .test_find:
        cmp     byte[esi], 0
        je      .find ; end reached
        cmp     byte[esi], '/'
        jne     @b
        inc     esi

  .find:
        pop     eax ; removing saved value from stack

  .ret:
        pop     edi edx ecx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.ext2.read_directory ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? read disk folder
;-----------------------------------------------------------------------------------------------------------------------
;> esi  points to filename
;> ebx  pointer to structure 32-bit number = first wanted block (0+) & flags (bitfields)
;> ecx  number of blocks to read, 0+
;> edx  mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< ebx = blocks read or 0xffffffff folder not found
;< eax = 0 ok read or other = errormsg
;-----------------------------------------------------------------------------------------------------------------------
; flags: bit 0: 0=ANSI names, 1=UNICODE names
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jz      .doit

        push    ecx ebx
        call    ext2_find_lfn
        jnc     .doit2
        pop     ebx

  .not_found:
        pop     ecx
        jmp     fs.error.file_not_found

  .doit:
        mov     ebp, [ext2_data.root_inode]
        push    ecx
        jmp     @f

  .doit2:
        pop     ebx
        test    [ebp + ext2_inode_t.i_mode], EXT2_S_IFDIR
        jz      .not_found

    @@: xor     eax, eax
        mov     edi, edx
        mov     ecx, sizeof.fs.file_info_header_t / 4
        rep
        stosd   ; fill header zero
        pop     edi ; edi = number of blocks to read
        push    edx ebx

        ;--------------------------------------------- final step
        and     [EXT2_read_in_folder], 0
        and     [EXT2_files_in_folder], 0

        mov     eax, [ebp + ext2_inode_t.i_blocks]
        mov     [EXT2_counter_blocks], eax

        add     edx, 32 ; (header pointer in stack) edx = current mem for return
        xor     esi, esi ; esi = consecutive block number

  .new_block_folder: ; reserved label
        mov     ecx, esi ; getting block number
        call    ext2_get_inode_block

        mov     eax, ecx
        mov     ebx, [ext2_data.ext2_save_block]
        call    ext2_get_block ; and reading block from hdd

        mov     eax, ebx ; eax = current dir record
        add     ebx, [ext2_data.block_size]
        mov     [EXT2_end_block], ebx ; saving next block end

        pop     ecx
        mov     ecx, [ecx] ; ecx = first wanted (flags ommited)

  .find_wanted_start:
        jecxz   .find_wanted_end

  .find_wanted_cycle:
        cmp     [eax + ext2_dir_t.inode], 0 ; if (inode = 0) => not used
        jz      @f
        inc     [EXT2_files_in_folder]
        dec     ecx

    @@: movzx   ebx, [eax + ext2_dir_t.rec_len]

        cmp     ebx, 12 ; minimum record size
        jb      .end_error
        test    ebx, 0x3 ; record size should be a multiple of 4
        jnz     .end_error

        add     eax, ebx ; go to next record
        cmp     eax, [EXT2_end_block] ; check if it is the "end"
        jb      .find_wanted_start

        push    .find_wanted_start

  .end_block: ; got out of cycle
        mov     ebx, [ext2_data.count_block_in_block]
        sub     [EXT2_counter_blocks], ebx
        jbe     .end_dir

        inc     esi ; getting new block
        push    ecx
        mov     ecx, esi
        call    ext2_get_inode_block
        mov     eax, ecx
        mov     ebx, [ext2_data.ext2_save_block]
        call    ext2_get_block
        pop     ecx
        mov     eax, ebx
        add     ebx, [ext2_data.block_size]
        mov     [EXT2_end_block], ebx
        ret     ; into the cycle again

  .wanted_end:
        loop    .find_wanted_cycle ; ecx = -1

  .find_wanted_end:
        mov     ecx, edi

  .wanted_start: ; searching for first_wanted + count
        jecxz   .wanted_end
        cmp     [eax + ext2_dir_t.inode], 0 ; if (inode = 0) => not used
        jz      .empty_rec
        inc     [EXT2_files_in_folder]
        inc     [EXT2_read_in_folder]

        mov     edi, edx
        push    eax ecx
        xor     eax, eax
        mov     ecx, sizeof.fs.file_info_t / 4
        rep
        stosd
        pop     ecx eax

        push    eax esi edx ; get the inode
        mov     eax, [eax + ext2_dir_t.inode]
        mov     ebx, [ext2_data.ext2_temp_inode]
        call    ext2_get_inode

        lea     edi, [edx + fs.file_info_t.created_at]

        mov     eax, [ebx + ext2_inode_t.i_ctime] ; convert time into ntfs format
        xor     edx, edx
        add     eax, 3054539008 ; (369 * 365 + 89) * 24 * 3600
        adc     edx, 2
        call    ntfs_datetime_to_bdfe.sec

        mov     eax, [ebx + ext2_inode_t.i_atime]
        xor     edx, edx
        add     eax, 3054539008
        adc     edx, 2
        call    ntfs_datetime_to_bdfe.sec

        mov     eax, [ebx + ext2_inode_t.i_mtime]
        xor     edx, edx
        add     eax, 3054539008
        adc     edx, 2
        call    ntfs_datetime_to_bdfe.sec

        pop     edx ; getting buffer only for now
        test    [ebx + ext2_inode_t.i_mode], EXT2_S_IFDIR ; size for directory
        jnz     @f ; not returning

        mov     eax, [ebx + ext2_inode_t.i_size] ; low size
        stosd
        mov     eax, [ebx + ext2_inode_t.i_dir_acl] ; high size
        stosd
        xor     [edx + fs.file_info_t.attributes], FS_INFO_ATTR_DIR

    @@: xor     [edx + fs.file_info_t.attributes], FS_INFO_ATTR_DIR
        pop     esi eax

        ; now copying the name, converting it from UTF-8 to CP866
        push    eax ecx esi
        movzx   ecx, [eax + ext2_dir_t.name_len]
        lea     edi, [edx + fs.file_info_t.name]
        lea     esi, [eax + ext2_dir_t.name]
        call    utf8toansi_str
        pop     esi ecx eax
        and     byte[edi], 0

        cmp     byte[edx + fs.file_info_t.name], '.'
        jne     @f
        or      [edx + fs.file_info_t.attributes], FS_INFO_ATTR_HIDDEN

    @@: add     edx, fs.file_info_t.name + 264 ; go to next record
        dec     ecx ; if record is empty, ecx should not be decreased

  .empty_rec:
        movzx   ebx, [eax + ext2_dir_t.rec_len]
        cmp     ebx, 12 ; minimum record size
        jb      .end_error
        test    ebx, 0x3 ; record size should be a multiple of 4
        jnz     .end_error

        add     eax, ebx
        cmp     eax, [EXT2_end_block]
        jb      .wanted_start

        push    .wanted_start ; got to the end of next block
        jmp     .end_block

  .end_dir:
        pop     eax ; garbage (address of return-to-cycle label)

  .end_error:
        pop     edx
        mov     ebx, [EXT2_read_in_folder]
        mov     ecx, [EXT2_files_in_folder]
        mov     [edx + fs.file_info_header_t.version], 1 ; version
        xor     eax, eax
        mov     [edx + fs.file_info_header_t.files_read], ebx
        mov     [edx + fs.file_info_header_t.files_count], ecx
        lea     edi, [edx + fs.file_info_header_t.files_count + 4]
        mov     ecx, (sizeof.fs.file_info_header_t - fs.file_info_header_t.files_count - 4) / 4
        rep
        stosd
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.ext2.read_file ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? read hard disk
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;> ebx = pointer to 64-bit number = first wanted byte, 0+
;> ecx = number of bytes to read, 0+
;> edx = mem location to return data
;-----------------------------------------------------------------------------------------------------------------------
;< ebx = bytes read or 0xffffffff file not found
;< eax = 0 ok read or other = errormsg
;-----------------------------------------------------------------------------------------------------------------------
;# if ebx = 0, start from first byte
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx ebx
        call    ext2_find_lfn
        pop     ebx ecx
        jc      fs.error.file_not_found

        test    [ebp + ext2_inode_t.i_mode], EXT2_S_IFREG
        jz      fs.error.access_denied

        ;-----------------------------------------------------------------------------final step
        mov     edi, edx ; edi = pointer to return mem
        mov     esi, ebx ; esi = pointer to first_wanted

        ;///// check if file is big enough for us
        mov     ebx, [esi + 4]
        mov     eax, [esi] ; ebx : eax - start byte number

        cmp     [ebp + ext2_inode_t.i_dir_acl], ebx
        ja      .size_great
        jb      .size_less

        cmp     [ebp + ext2_inode_t.i_size], eax
        ja      .size_great

  .size_less:
        xor     ebx, ebx
        mov     eax, ERROR_END_OF_FILE
        ret

  .size_great:
        add     eax, ecx ; add to first_wanted number of bytes to read
        adc     ebx, 0

        cmp     [ebp + ext2_inode_t.i_dir_acl], ebx
        ja      .size_great_great
        jb      .size_great_less
        cmp     [ebp + ext2_inode_t.i_size], eax
        jae     .size_great_great ; and if it's equal, no matter where we jump

  .size_great_less:
        or      [EXT2_files_in_folder], 1 ; reading till the end of file
        mov     ecx, [ebp + ext2_inode_t.i_size]
        sub     ecx, [esi] ; (size - start)
        jmp     @f

  .size_great_great:
        and     [EXT2_files_in_folder], 0 ; reading as much as requested

    @@: push    ecx ; save for return
        test    esi, esi
        jz      .zero_start

        ; doing f** askew for now =)
        mov     edx, [esi + 4]
        mov     eax, [esi]
        div     [ext2_data.block_size]

        mov     [EXT2_counter_blocks], eax ; saving block number

        push    ecx
        mov     ecx, eax
        call    ext2_get_inode_block
        mov     ebx, [ext2_data.ext2_save_block]
        mov     eax, ecx
        call    ext2_get_block
        pop     ecx
        add     ebx, edx

        neg     edx
        add     edx, [ext2_data.block_size] ; block_size - start byte = number of byte in 1st block
        cmp     ecx, edx
        jbe     .only_one_block

        mov     eax, ecx
        sub     eax, edx
        mov     ecx, edx

        mov     esi, ebx
        rep
        movsb   ; 1st block part
        jmp     @f

  .zero_start:
        mov     eax, ecx
        ; now eax contains number of bytes left to read

    @@: mov     ebx, edi ; reading block right into ->ebx
        xor     edx, edx
        div     [ext2_data.block_size] ; edx = number of bytes in last block (remainder)
        mov     edi, eax ; edi = number of whole blocks

    @@: test    edi, edi
        jz      .finish_block
        inc     [EXT2_counter_blocks]
        mov     ecx, [EXT2_counter_blocks]
        call    ext2_get_inode_block

        mov     eax, ecx ; and ebx already contains correct value
        call    ext2_get_block
        add     ebx, [ext2_data.block_size]

        dec     edi
        jmp     @b

  .finish_block:
        ; in edx - number of bytes in last block
        test    edx, edx
        jz      .end_read

        mov     ecx, [EXT2_counter_blocks]
        inc     ecx
        call    ext2_get_inode_block

        mov     edi, ebx
        mov     eax, ecx
        mov     ebx, [ext2_data.ext2_save_block]
        call    ext2_get_block

        mov     ecx, edx

  .only_one_block:
        mov     esi, ebx
        rep
        movsb   ; part of last block

  .end_read:
        pop     ebx
        cmp     [EXT2_files_in_folder], 0
        jz      @f

        mov     eax, ERROR_END_OF_FILE
        ret

    @@: xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_find_lfn ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> esi = name
;-----------------------------------------------------------------------------------------------------------------------
;< ebp = inode, CF = 0
;< ebp = trash, CF = 1
;-----------------------------------------------------------------------------------------------------------------------
;# not save: eax ebx ecx
;-----------------------------------------------------------------------------------------------------------------------
        mov     ebp, [ext2_data.root_inode]

  .next_folder:
        or      [EXT2_counter_blocks], -1 ; directory blocks counter    cur block of inode
        mov     eax, [ebp + ext2_inode_t.i_blocks] ; decreasing blocks counter
        add     eax, [ext2_data.count_block_in_block]
        mov     [EXT2_end_block], eax

  .next_block_folder:
        mov     eax, [ext2_data.count_block_in_block]
        sub     [EXT2_end_block], eax
        jz      .not_found
        inc     [EXT2_counter_blocks]
        mov     ecx, [EXT2_counter_blocks]
        call    ext2_get_inode_block

        mov     eax, ecx
        mov     ebx, [ext2_data.ext2_save_block] ; ebx = cur dir record
        call    ext2_get_block

        mov     eax, esi
        call    ext2_test_block_by_name
        cmp     eax, esi ; found the name?
        jz      .next_block_folder

        cmp     byte[esi], 0
        jz      .get_inode_ret

        cmp     [ebx + ext2_dir_t.file_type], EXT2_FT_DIR
        jne     .not_found ; found, but it's not a directory
        mov     eax, [ebx + ext2_dir_t.inode]
        mov     ebx, [ext2_data.ext2_save_inode] ; it's a directory
        call    ext2_get_inode
        mov     ebp, ebx
        jmp     .next_folder

  .not_found:
        stc
        ret

  .get_inode_ret:
        mov     [EXT2_end_block], ebx ; saving pointer to dir_rec
        mov     eax, [ebx + ext2_dir_t.inode]
        mov     ebx, [ext2_data.ext2_save_inode]
        call    ext2_get_inode
        mov     ebp, ebx
        clc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fs.ext2.get_file_info ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jz      .doit

        call    ext2_find_lfn
        jnc     .doit2

        jmp     fs.error.file_not_found

  .doit:
        mov     ebp, [ext2_data.root_inode]
        mov     ebx, .doit ; address doesn't matter as long as it doesn't point to '.'
        jmp     @f

  .doit2:
        mov     ebx, [EXT2_end_block]
        add     ebx, ext2_dir_t.name

    @@: xor     eax, eax
        mov     edi, edx
        mov     ecx, sizeof.fs.file_info_t / 4
        rep
        stosd   ; fill zero

        cmp     byte[ebx], '.'
        jnz     @f
        or      [edx + fs.file_info_t.attributes], FS_INFO_ATTR_HIDDEN

    @@: test    [ebp + ext2_inode_t.i_mode], EXT2_S_IFDIR
        jnz     @f
        mov     eax, [ebp + ext2_inode_t.i_size] ; low size
        mov     ebx, [ebp + ext2_inode_t.i_dir_acl] ; high size
        mov     [edx + fs.file_info_t.size.low], eax
        mov     [edx + fs.file_info_t.size.high], ebx
        xor     [edx + fs.file_info_t.attributes], FS_INFO_ATTR_DIR

    @@: xor     [edx + fs.file_info_t.attributes], FS_INFO_ATTR_DIR

        lea     edi, [edx + fs.file_info_t.created_at]
        mov     eax, [ebx + ext2_inode_t.i_ctime]
        xor     edx, edx
        add     eax, 3054539008
        adc     edx, 2
        call    ntfs_datetime_to_bdfe.sec

        mov     eax, [ebx + ext2_inode_t.i_atime]
        xor     edx, edx
        add     eax, 3054539008
        adc     edx, 2
        call    ntfs_datetime_to_bdfe.sec

        mov     eax, [ebx + ext2_inode_t.i_mtime]
        xor     edx, edx
        add     eax, 3054539008
        adc     edx, 2
        call    ntfs_datetime_to_bdfe.sec

        xor     eax, eax
        ret
kendp

if defined DEAD_CODE_UNTIL_EXT2_WRITE_SUPPORT_IS_IMPLEMENTED

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_HdCreateFolder ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? create new folder
;-----------------------------------------------------------------------------------------------------------------------
;> esi = points to filename
;-----------------------------------------------------------------------------------------------------------------------
;< eax = 0 ok read or other = errormsg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     byte[esi], 0
        jz      .not_found
        cmp     byte[esi], '/'
        jz      .not_found

        mov     ebx, esi ; save source pointer
        xor     edi, edi ; slah pointer

    @@: lodsb
        cmp     al, 0
        jz      .zero
        cmp     al, '/'
        jz      .slash
        jmp     @b

  .slash:
        lodsb
        cmp     al, 0
        jz      .zero ; remove slash from the name
        cmp     al, '/'
        jz      .not_found
        mov     edi, esi ; edi -> next symbol after '/'
        dec     edi
        jmp     @b

  .zero:
        dec     esi
        test    edi, edi
        jz      .doit

        ; there was a slash
        mov     eax, esi
        sub     eax, edi
        mov     [EXT2_name_len], eax

        mov     ecx, edi
        sub     ecx, ebx
        dec     ecx ; threw out '/' from parent name
        mov     esi, ebx
        mov     edi, EXT2_parent_name
        rep
        movsb
        ; esi - pointer to last slash

        mov     edx, esi
        mov     esi, EXT2_parent_name
        call    ext2_find_lfn
        jnc     .doit2

  .not_found:
        or      ebx, -1
        mov     eax, ERROR_FILE_NOT_FOUND
        ret

  .doit:
        mov     ebp, [ext2_data.root_inode]
        mov     edx, ebx ; name of directory being created
        sub     esi, ebx
        mov     [EXT2_name_len], esi

  .doit2:
        ; ebp -> parent_inode    ebx->name_new_folder   [EXT2_name_len]=length of name

        ; strategy for selecting a group for new inode: (as Linux does it)
        ; 1) selecting a group with least of directories, having free space
        ; 2) if there's no such group, selecting a group with most of free space

        call    ext2_balloc
        jmp     ext2_HdDelete

        push    ebx
        push    ebp

        mov     ecx, [ext2_data.sb]
        cmp     [ecx + ext2_sb_t.free_inodes_count], 0 ; is there a space for inode
        jz      .no_space
        mov     eax, [ecx + ext2_sb_t.free_block_count]
        sub     eax, [ecx + ext2_sb_t.r_block_count]
        cmp     eax, 2 ; and for 2 blocks, at least
        jb      .no_space

        mov     ecx, [ext2_data.groups_count]
        mov     esi, [ext2_data.global_desc_table]
        mov     edi, -1 ; pointer to the best group
        mov     edx, 0

  .find_group_dir:
        jecxz   .end_find_group_dir
        movzx   eax, [esi + ext2_block_group_descriptor_t.free_inodes_count]
        cmp     eax, edx
        jbe     @f
        cmp     [esi + ext2_block_group_descriptor_t.free_blocks_count], 0
        jz      @f
        mov     edi, esi
        movzx   edx, [esi + ext2_block_group_descriptor_t.free_inodes_count]

    @@: dec     ecx
        add     esi, 32 ; structure size
        jmp     .find_group_dir

  .end_find_group_dir:
        cmp     edx, 0
        jz      .no_space

        ; got the group, now get the bit map of inodes (find local number)
        mov     eax, [edi + ext2_block_group_descriptor_t.inode_bitmap]
        mov     ebx, [ext2_data.ext2_save_block]
        call    ext2_get_block

        ; now cycle through all the bits
        mov     esi, ebx
        mov     ecx, [ext2_data.inodes_per_group]
        shr     ecx, 5 ; dividing by 32
        mov     ebp, ecx ; saving total in ebp
        or      eax, -1 ; searching for first free inode (!= -1)
        repne
        scasd
        jnz     .test_last_dword ; found or not
        mov     eax, [esi - 4]

        sub     ebp, ecx
        dec     ebp
        shl     ebp, 5 ; global number for local number

        mov     ecx, 32

    @@: test    eax, 1
        jz      @f
        shr     eax, 1
        loop    @b

    @@: mov     eax, 32
        sub     eax, ecx

        add     ebp, eax ; locale num of inode

        mov     eax, [esi - 4]
        ; setting first zero lsb of eax to 1
        mov     ecx, eax
        inc     ecx
        or      eax, ecx ; x | (x + 1)
        mov     [esi - 4], eax
        mov     ebx, [ext2_data.ext2_save_block]
        mov     eax, [edi + ext2_block_group_descriptor_t.inode_bitmap]
        call    ext2_set_block
        ; calculating inode table
        sub     edi, [ext2_data.global_desc_table]
        shr     edi, 5

        mov     eax, edi
        mul     [ext2_data.inodes_per_group]
        add     eax, ebp
        inc     eax ; now eax (ebp) stores an inode number
        mov     ebp, eax
;       call    ext2_get_inode_address

        mov     ebx, [ext2_data.ext2_save_block]
        call    hd_read
        add     edx, ebx ; edx = inode address

        ; fill with 0 for the start
        mov     edi, edx
        mov     ecx, [ext2_data.inode_size]
        shr     ecx, 2
        xor     eax, eax
        rep
        stosd

        mov     edi, edx
        mov     eax, EXT2_S_IFDIR or EXT2_777_MODE
        stosd   ; i_mode
        xor     eax, eax
        stosd   ; i_uid
        mov     eax, [ext2_data.block_size]
        stosd   ; i_size
        xor     eax, eax
        stosd   ; i_atime
        stosd   ; i_ctime
        stosd   ; i_mtime
        stosd   ; i_dtime
        stosd   ; i_gid
        inc     eax
        stosd   ; i_links_count
        mov     eax, [ext2_data.count_block_in_block]
        stosd   ; i_blocks

  .test_last_dword:
        xor     ebx, ebx
        mov     eax, ERROR_NOT_IMPLEMENTED
        ret

  .no_space:
        or      ebx, -1
        mov     eax, ERROR_DISK_FULL
        ret
kendp

end if ; DEAD_CODE_UNTIL_EXT2_WRITE_SUPPORT_IS_IMPLEMENTED

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_balloc ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? allocates new block, if possible
;? otherwise, returns eax = 0
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, [ext2_data.sb]
        mov     eax, [ecx + ext2_sb_t.free_block_count]
        sub     eax, [ecx + ext2_sb_t.r_block_count]
        jbe     .no_space

        mov     ecx, [ext2_data.groups_count]
        mov     edi, [ext2_data.global_desc_table]
;       mov     esi, -1 ; pointer to the best group
        mov     edx, 0

  .find_group:
        jecxz   .end_find_group
        movzx   eax, [edi + ext2_block_group_descriptor_t.free_blocks_count]
        cmp     eax, edx
        jbe     @f
        mov     esi, edi
        mov     edx, eax

    @@: dec     ecx
        add     edi, 32 ; structure size
        jmp     .find_group

  .end_find_group:
        cmp     edx, 0
        jz      .no_space

        ; got the group, now get the bit map of block
        mov     eax, [esi + ext2_block_group_descriptor_t.block_bitmap]
        mov     ebx, [ext2_data.ext2_save_block]
        call    ext2_get_block

        ; now cycle through all the bits
        mov     edi, ebx
        mov     ecx, [ext2_data.blocks_per_group]
        shr     ecx, 5 ; dividing by 32
        mov     ebp, ecx ; saving total in ebp
        or      eax, -1 ; searching for first free inode (!= -1)
        repe
        scasd
        jz      .test_last_dword ; found or not

        mov     eax, [edi - 4]
        sub     ebp, ecx
        dec     ebp
        shl     ebp, 5 ; ebp = 32*(number div 32). now getting (number mod 32)

        mov     ecx, 32

    @@: test    eax, 1
        jz      @f
        shr     eax, 1
        loop    @b

    @@: mov     eax, 32
        sub     eax, ecx

        add     ebp, eax ; ebp = block number in group

        mov     eax, [edi - 4]
        mov     ecx, eax
        inc     ecx
        or      eax, ecx ; x | (x+1) - sets first zero lsb to 1 (block used)
        mov     [edi - 4], eax

        mov     ebx, [ext2_data.ext2_save_block]
        mov     eax, [esi + ext2_block_group_descriptor_t.inode_bitmap]
;       call    ext2_set_block ; writing new bit mask down to hdd

        ;============== getting block number here
        mov     eax, [ext2_data.blocks_per_group]
        sub     esi, [ext2_data.global_desc_table]
        shr     esi, 5 ; esi - group number
        mul     esi
        add     ebp, eax ; (group number) * (blocks_per_group) + local number in group
        mov     eax, [ext2_data.sb]
        add     ebp, [eax + ext2_sb_t.first_data_block]

        ; now fixing global descriptor table and superblock
        mov     ebx, [ext2_data.sb]
        dec     [ebx + ext2_sb_t.free_block_count]
        mov     eax, 2
        add     eax, dword[current_partition._.range.offset]
        call    hd_write
        mov     eax, [ebx + ext2_sb_t.first_data_block]
        inc     eax
        dec     [esi + ext2_block_group_descriptor_t.free_blocks_count] ; edi still points to group we allocated block in
        call    ext2_set_block

        mov     eax, ebx
        ret

  .test_last_dword:
        lodsd
        mov     ecx, [ext2_data.blocks_per_group]
        and     ecx, not 011111b ; zeroing all but 5 least significant bits
        mov     edx, ecx
        mov     ebx, 1

    @@: jecxz   .no_space
        mov     edx, ebx
        or      edx, eax ; testint next bit
        shl     ebx, 1
        jmp     @b

    @@: sub     edx, ecx
        dec     edx ; number in last block


  .no_space:
        xor     eax, eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc ext2_set_block ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = i_block
;> ebx = pointer to memory
;-----------------------------------------------------------------------------------------------------------------------
        push    eax ebx ecx
        mov     ecx, [ext2_data.log_block_size]
        shl     eax, cl
        add     eax, dword[current_partition._.range.offset]
        mov     ecx, [ext2_data.count_block_in_block]

    @@: call    hd_write
        inc     eax
        add     ebx, 512
        loop    @b
        pop     ecx ebx eax
        ret
kendp
