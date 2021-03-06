;;======================================================================================================================
;;///// hd_drv.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2011 KolibriOS team <http://kolibrios.org/>
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
;? Low-level driver for HDD access
;;======================================================================================================================

uglobal
  hd_error        dd 0 ; set by wait_for_sector_buffer
  hd_wait_timeout dd 0
  hd1_status      rd 1 ; 0 - free : other - pid
  hdbase          rd 1 ; for boot 0x1f0
  hdpos           rd 1 ; for boot 0x1
  hdid            rb 1
  hd_in_cache     db ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc reserve_hd1 ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cli
        cmp     [hd1_status], 0
        je      .reserve_ok1

        sti
        call    change_task
        jmp     reserve_hd1

  .reserve_ok1:
        push    eax
        mov     eax, [current_slot]
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + eax + legacy.slot_t.task.pid]
        mov     [hd1_status], eax
        pop     eax
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc reserve_hd_channel ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# BIOS disk accesses are protected with common mutex hd1_status
;# This must be modified when hd1_status will not be valid!
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [hdpos], 0x80
        jae     .exit
        cmp     [hdbase], 0x1f0
        jne     .secondary_channel

  .primary_channel:
        cli
        cmp     [IDE_Channel_1], 0
        je      @f
        sti
        call    change_task
        jmp     .primary_channel

    @@: mov     [IDE_Channel_1], 1
        push    eax
        mov     al, 1
        jmp     .clear_cache

  .secondary_channel:
        cli
        cmp     [IDE_Channel_2], 0
        je      @f
        sti
        call    change_task
        jmp     .secondary_channel

    @@: mov     [IDE_Channel_2], 1
        push    eax
        mov     al, 3

  .clear_cache:
        cmp     [hdid], 1
        sbb     al, -1
        cmp     al, [hd_in_cache]
        jz      @f
        mov     [hd_in_cache], al
        call    clear_hd_cache

    @@: pop     eax
        sti

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc free_hd_channel ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# see comment at reserve_hd_channel
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [hdpos], 0x80
        jae     .exit
        cmp     [hdbase], 0x1f0
        jne     .secondary_channel

  .primary_channel:
        and     [IDE_Channel_1], 0
        ret

  .secondary_channel:
        and     [IDE_Channel_2], 0

  .exit:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_read ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = block to read
;> ebx = destination
;-----------------------------------------------------------------------------------------------------------------------
        and     [hd_error], 0
        push    ecx esi edi ; scan cache

;       mov     ecx, cache_max ; entries in cache
;       mov     esi, HD_CACHE + 8
        call    calculate_cache
        add     esi, 8

        mov     edi, 1

  .hdreadcache:
        cmp     dword[esi + 4], 0 ; empty
        je      .nohdcache

        cmp     [esi], eax ; correct sector
        je      .yeshdcache

  .nohdcache:
        add     esi, 8
        inc     edi
        dec     ecx
        jnz     .hdreadcache

        call    find_empty_slot ; ret in edi
        cmp     [hd_error], 0
        jne     .return_01
        ; Read through BIOS?
        cmp     [hdpos], 0x80
        jae     .bios
        ; hd_read_{dma,pio} use old ATA with 28 bit for sector number
        cmp     eax, 0x10000000
        jb      @f
        inc     [hd_error]
        jmp     .return_01

    @@: ; DMA read is permitted if [allow_dma_access]=1 or 2
        cmp     [allow_dma_access], 2
        ja      .nodma
        cmp     [dma_hdd], 1
        jnz     .nodma
        call    hd_read_dma
        jmp     @f

  .nodma:
        call    hd_read_pio
        jmp     @f

  .bios:
        call    bd_read

    @@: cmp     [hd_error], 0
        jne     .return_01
;       lea     esi, [edi * 8 + HD_CACHE]
;       push    eax
        call    calculate_cache_1
        lea     esi, [edi * 8 + esi]
;       pop     eax

        mov     [esi], eax ; sector number
        mov     dword[esi + 4], 1 ; hd read - mark as same as in hd

  .yeshdcache:
        mov     esi, edi
        shl     esi, 9
;       add     esi, HD_CACHE + 65536
        push    eax
        call    calculate_cache_2
        add     esi, eax
        pop     eax

        mov     edi, ebx
        mov     ecx, 512 / 4
        rep
        movsd   ; move data

  .return_01:
        pop     edi esi ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_read_pio ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx

        call    wait_for_hd_idle
        cmp     [hd_error], 0
        jne     hd_read_error

        cli
        xor     eax, eax
        mov     edx, [hdbase]
        inc     edx
        out     dx, al ; ATAFeatures "capabilities" register
        inc     edx
        inc     eax
        out     dx, al ; ATASectorCount sectors counter
        inc     edx
        mov     eax, [esp + 4]
        out     dx, al ; ATASectorNumber sector number register
        shr     eax, 8
        inc     edx
        out     dx, al ; ATACylinder cylinder number (low byte)
        shr     eax, 8
        inc     edx
        out     dx, al ; cylinder number (high byte)
        shr     eax, 8
        inc     edx
        and     al, 00001111b
        add     al, [hdid]
        add     al, 11100000b
        out     dx, al ; head/disk number
        inc     edx
        mov     al, 0x20
        out     dx, al ; ATACommand command register
        sti

        call    wait_for_sector_buffer

        cmp     [hd_error], 0
        jne     hd_read_error

        cli
        push    edi
        shl     edi, 9
;       add     edi, HD_CACHE + 65536
        push    eax
        call    calculate_cache_2
        add     edi, eax
        pop     eax

        mov     ecx, 512 / 2
        mov     edx, [hdbase]
        rep
        insw
        pop     edi
        sti

        pop     edx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc disable_ide_int ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     edx, [hdbase]
;       add     edx, 0x206
;       mov     al, 2
;       out     dx, al
        cli
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc enable_ide_int ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       mov     edx, [hdbase]
;       add     edx, 0x206
;       mov     al, 0
;       out     dx, al
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_write ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = block
;> ebx = pointer to memory
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx esi edi

        ; check if the cache already has the sector and overwrite it

;       mov     ecx, cache_max
;       mov     esi, HD_CACHE + 8
        call    calculate_cache
        add     esi, 8

        mov     edi, 1

  .hdwritecache:
        cmp     dword[esi + 4], 0 ; if cache slot is empty
        je      .not_in_cache_write

        cmp     [esi], eax ; if the slot has the sector
        je      .yes_in_cache_write

  .not_in_cache_write:
        add     esi, 8
        inc     edi
        dec     ecx
        jnz     .hdwritecache

        ; sector not found in cache
        ; write the block to a new location

        call    find_empty_slot ; ret in edi
        cmp     [hd_error], 0
        jne     .hd_write_access_denied

;       lea     esi, [edi * 8 + HD_CACHE]
;       push    eax
        call    calculate_cache_1
        lea     esi, [edi * 8 + esi]
;       pop     eax

        mov     [esi], eax ; sector number

  .yes_in_cache_write:
        mov     dword[esi + 4], 2 ; write - differs from hd

        shl     edi, 9
;       add     edi, HD_CACHE + 65536
        push    eax
        call    calculate_cache_2
        add     edi, eax
        pop     eax

        mov     esi, ebx
        mov     ecx, 512 / 4
        rep
        movsd   ; move data

  .hd_write_access_denied:
        pop     edi esi ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc cache_write_pio ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     dword[esi], 0x10000000
        jae     .bad
;       call    disable_ide_int

        call    wait_for_hd_idle
        cmp     [hd_error], 0
        jne     hd_write_error

        cli
        xor     eax, eax
        mov     edx, [hdbase]
        inc     edx
        out     dx, al
        inc     edx
        inc     eax
        out     dx, al
        inc     edx
        mov     eax, [esi] ; eax = sector to write
        out     dx, al
        shr     eax, 8
        inc     edx
        out     dx, al
        shr     eax, 8
        inc     edx
        out     dx, al
        shr     eax, 8
        inc     edx
        and     al, 00001111b
        add     al, [hdid]
        add     al, 11100000b
        out     dx, al
        inc     edx
        mov     al, 0x30
        out     dx, al
        sti

        call    wait_for_sector_buffer

        cmp     [hd_error], 0
        jne     hd_write_error

        push    ecx esi

        cli
        mov     esi, edi
        shl     esi, 9
;       add     esi, HD_CACHE + 65536 ; esi = from memory position
        push    eax
        call    calculate_cache_2
        add     esi, eax
        pop     eax

        mov     ecx, 512 / 2
        mov     edx, [hdbase]
        rep
        outsw
        sti

;       call    enable_ide_int
        pop     esi ecx

        ret

  .bad:
        inc     [hd_error]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc save_hd_wait_timeout ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, dword[timer_ticks]
        add     eax, 3 * KCONFIG_SYS_TIMER_FREQ ; 3 sec timeout
        mov     [hd_wait_timeout], eax
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc check_hd_wait_timeout ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        mov     eax, [hd_wait_timeout]
        cmp     dword[timer_ticks], eax
        jg      hd_timeout_error
        pop     eax
        mov     [hd_error], 0
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_timeout_error ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_ERROR, "FS - HD timeout\n"
        mov     [hd_error], 1
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_read_error ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_ERROR, "FS - HD read error\n"
        pop     edx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_write_error ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_ERROR, "FS - HD write error\n"
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_write_error_dma ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        KLog    LOG_ERROR, "FS - HD read error\n"
        pop     esi
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc wait_for_hd_idle ;////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx

        call    save_hd_wait_timeout

        mov     edx, [hdbase]
        add     edx, 0x7

  .wfhil1:
        call    check_hd_wait_timeout
        cmp     [hd_error], 0
        jne     @f

        in      al, dx
        test    al, 128
        jnz     .wfhil1

    @@: pop     edx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc wait_for_sector_buffer ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax edx

        mov     edx, [hdbase]
        add     edx, 0x7

        call    save_hd_wait_timeout

  .hdwait_sbuf:
        ; wait for sector buffer to be ready
        call    check_hd_wait_timeout
        cmp     [hd_error], 0
        jne     @f

        in      al, dx
        test    al, 8
        jz      .hdwait_sbuf

        mov     [hd_error], 0

        cmp     [hd_setup], 1 ; do not mark error for setup request
        je      .buf_wait_ok

        test    al, 1 ; previous command ended up with an error
        jz      .buf_wait_ok

    @@: mov     [hd_error], 1

  .buf_wait_ok:
        pop     edx eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc wait_for_sector_dma_ide0 ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    edx
        call    save_hd_wait_timeout

  .wait:
        call    change_task
        cmp     [irq14_func], hdd_irq14
        jnz     .done
        call    check_hd_wait_timeout
        cmp     [hd_error], 0
        jz      .wait
        mov     [irq14_func], hdd_irq_null
        mov     dx, [IDEContrRegsBaseAddr]
        mov     al, 0
        out     dx, al

  .done:
        pop     edx
        pop     eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc wait_for_sector_dma_ide1 ;////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    edx
        call    save_hd_wait_timeout

  .wait:
        call    change_task
        cmp     [irq15_func], hdd_irq15
        jnz     .done
        call    check_hd_wait_timeout
        cmp     [hd_error], 0
        jz      .wait
        mov     [irq15_func], hdd_irq_null
        mov     dx, [IDEContrRegsBaseAddr]
        add     dx, 8
        mov     al, 0
        out     dx, al

  .done:
        pop     edx
        pop     eax
        ret
kendp

iglobal
  ; note that IDE descriptor table must be 4-byte aligned and do not cross 4K boundary
  IDE_descriptor_table:
    dd IDE_DMA - OS_BASE
    dw 0x2000
    dw 0x8000

  dma_cur_sector dd not 0x40
  dma_hdpos      dd 0
  irq14_func     dd hdd_irq_null
  irq15_func     dd hdd_irq_null
endg

uglobal
  dma_process         dd ?
  dma_slot_ptr        dd ?
  cache_chain_pos     dd ?
  cache_chain_ptr     dd ?
  cache_chain_size    db ?
  cache_chain_started db ?
  dma_task_switched   db ?
  dma_hdd             db ?
  allow_dma_access    db ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc hdd_irq14 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli
        pushad
        mov     [irq14_func], hdd_irq_null
        mov     dx, [IDEContrRegsBaseAddr]
        mov     al, 0
        out     dx, al
;       call    update_counters
;       mov     ebx, [dma_process]
;       cmp     [current_slot], ebx
;       jz      .noswitch
;       mov     [dma_task_switched], 1
;       mov     edi, [dma_slot_ptr]
;       mov     eax, [current_slot]
;       mov     [dma_process], eax
;       mov     eax, [current_slot_ptr]
;       mov     [dma_slot_ptr], eax
;       mov     [current_slot], ebx
;       mov     [current_slot_ptr], edi
;       mov     [DONT_SWITCH], 1
;       call    do_change_task

  .noswitch:
        popad
        popfd
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hdd_irq_null ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hdd_irq15 ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pushfd
        cli
        pushad
        mov     [irq15_func], hdd_irq_null
        mov     dx, [IDEContrRegsBaseAddr]
        add     dx, 8
        mov     al, 0
        out     dx, al
;       call    update_counters
;       mov     ebx, [dma_process]
;       cmp     [current_slot], ebx
;       jz      .noswitch
;       mov     [dma_task_switched], 1
;       mov     edi, [dma_slot_ptr]
;       mov     eax, [current_slot]
;       mov     [dma_process], eax
;       mov     eax, [current_slot_ptr]
;       mov     [dma_slot_ptr], eax
;       mov     [current_slot], ebx
;       mov     [current_slot_ptr], edi
;       mov     [DONT_SWITCH], 1
;       call    do_change_task

  .noswitch:
        popad
        popfd
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc hd_read_dma ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    edx
        mov     edx, [dma_hdpos]
        cmp     edx, [hdpos]
        jne     .notread
        mov     edx, [dma_cur_sector]
        cmp     eax, edx
        jb      .notread
        add     edx, 15
        cmp     [esp + 4], edx
        ja      .notread
        mov     eax, [esp + 4]
        sub     eax, [dma_cur_sector]
        shl     eax, 9
        add     eax, IDE_DMA
        push    ecx esi edi
        mov     esi, eax
        shl     edi, 9
;       add     edi, HD_CACHE + 0x10000
        push    eax
        call    calculate_cache_2
        add     edi, eax
        pop     eax

        mov     ecx, 512 / 4
        rep
        movsd
        pop     edi esi ecx
        pop     edx
        pop     eax
        ret

  .notread:
        mov     eax, IDE_descriptor_table
        mov     dword[eax], IDE_DMA - OS_BASE
        mov     word[eax + 4], 0x2000
        sub     eax, OS_BASE
        mov     dx, [IDEContrRegsBaseAddr]
        cmp     [hdbase], 0x1f0
        jz      @f
        add     edx, 8

    @@: push    edx
        add     edx, 4
        out     dx, eax
        pop     edx
        mov     al, 0
        out     dx, al
        add     edx, 2
        mov     al, 6
        out     dx, al
        call    wait_for_hd_idle
        cmp     [hd_error], 0
        jnz     hd_read_error
        call    disable_ide_int
        xor     eax, eax
        mov     edx, [hdbase]
        inc     edx
        out     dx, al
        inc     edx
        mov     eax, 0x10
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
        and     al, 0x0f
        add     al, [hdid]
        add     al, 11100000b
        out     dx, al
        inc     edx
        mov     al, 0xc8
        out     dx, al
        mov     dx, [IDEContrRegsBaseAddr]
        cmp     [hdbase], 0x1f0
        jz      @f
        add     dx, 8

    @@: mov     al, 9
        out     dx, al
        mov     eax, [current_slot]
        mov     [dma_process], eax
        mov     eax, [current_slot_ptr]
        mov     [dma_slot_ptr], eax
        cmp     [hdbase], 0x1f0
        jnz     .ide1
        mov     [irq14_func], hdd_irq14
        jmp     @f

  .ide1:
        mov     [irq15_func], hdd_irq15

    @@: call    enable_ide_int
        cmp     [hdbase], 0x1f0
        jnz     .wait_ide1
        call    wait_for_sector_dma_ide0
        jmp     @f

  .wait_ide1:
        call    wait_for_sector_dma_ide1

    @@: cmp     [hd_error], 0
        jnz     hd_read_error
        mov     eax, [hdpos]
        mov     [dma_hdpos], eax
        pop     edx
        pop     eax
        mov     [dma_cur_sector], eax
        jmp     hd_read_dma
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc write_cache_sector ;//////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     [cache_chain_size], 1
        mov     [cache_chain_pos], edi
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc write_cache_chain ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     [hdpos], 0x80
        jae     bd_write_cache_chain
        mov     eax, [cache_chain_ptr]
        cmp     dword[eax], 0x10000000
        jae     .bad
        push    esi
        mov     eax, IDE_descriptor_table
        mov     edx, eax
        pusha
        mov     esi, [cache_chain_pos]
        shl     esi, 9
        call    calculate_cache_2
        add     esi, eax
        mov     edi, IDE_DMA
        mov     dword[edx], IDE_DMA - OS_BASE
        movzx   ecx, [cache_chain_size]
        shl     ecx, 9
        mov     word[edx + 4], cx
        shr     ecx, 2
        rep
        movsd
        popa
        sub     eax, OS_BASE
        mov     dx, [IDEContrRegsBaseAddr]
        cmp     [hdbase], 0x1f0
        jz      @f
        add     edx, 8

    @@: push    edx
        add     edx, 4
        out     dx, eax
        pop     edx
        mov     al, 0
        out     dx, al
        add     edx, 2
        mov     al, 6
        out     dx, al
        call    wait_for_hd_idle
        cmp     [hd_error], 0
        jnz     hd_write_error_dma
        call    disable_ide_int
        xor     eax, eax
        mov     edx, [hdbase]
        inc     edx
        out     dx, al
        inc     edx
        mov     al, [cache_chain_size]
        out     dx, al
        inc     edx
        mov     esi, [cache_chain_ptr]
        mov     eax, [esi]
        out     dx, al
        shr     eax, 8
        inc     edx
        out     dx, al
        shr     eax, 8
        inc     edx
        out     dx, al
        shr     eax, 8
        inc     edx
        and     al, 0x0f
        add     al, [hdid]
        add     al, 11100000b
        out     dx, al
        inc     edx
        mov     al, 0xca
        out     dx, al
        mov     dx, [IDEContrRegsBaseAddr]
        cmp     [hdbase], 0x1f0
        jz      @f
        add     dx, 8

    @@: mov     al, 1
        out     dx, al
        mov     eax, [current_slot]
        mov     [dma_process], eax
        mov     eax, [current_slot_ptr]
        mov     [dma_slot_ptr], eax
        cmp     [hdbase], 0x1f0
        jnz     .ide1
        mov     [irq14_func], hdd_irq14
        jmp     @f

  .ide1:
        mov     [irq15_func], hdd_irq15

    @@: call    enable_ide_int
        mov     [dma_cur_sector], not 0x40
        cmp     [hdbase], 0x1f0
        jnz     .wait_ide1
        call    wait_for_sector_dma_ide0
        jmp     @f

  .wait_ide1:
        call    wait_for_sector_dma_ide1

    @@: cmp     [hd_error], 0
        jnz     hd_write_error_dma
        pop     esi
        ret

  .bad:
        inc     [hd_error]
        ret
kendp

uglobal
  IDEContrRegsBaseAddr dw ?

  bios_hdpos           dd ? ; 0 is invalid value for [hdpos]
  bios_cur_sector      dd ?
  bios_read_len        dd ?
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc bd_read ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        push    edx
        mov     edx, [bios_hdpos]
        cmp     edx, [hdpos]
        jne     .notread
        mov     edx, [bios_cur_sector]
        cmp     eax, edx
        jb      .notread
        add     edx, [bios_read_len]
        dec     edx
        cmp     eax, edx
        ja      .notread
        sub     eax, [bios_cur_sector]
        shl     eax, 9
        add     eax, OS_BASE + 0x9a000
        push    ecx esi edi
        mov     esi, eax
        shl     edi, 9
;       add     edi, HD_CACHE + 0x10000
        push    eax
        call    calculate_cache_2
        add     edi, eax
        pop     eax

        mov     ecx, 512 / 4
        rep
        movsd
        pop     edi esi ecx
        pop     edx
        pop     eax
        ret

  .notread:
        push    ecx
        mov     dl, 0x42
        mov     ecx, 16
        call    int13_call
        pop     ecx
        test    eax, eax
        jnz     .v86err
        test    edx, edx
        jz      .readerr
        mov     [bios_read_len], edx
        mov     edx, [hdpos]
        mov     [bios_hdpos], edx
        pop     edx
        pop     eax
        mov     [bios_cur_sector], eax
        jmp     bd_read

  .readerr:
  .v86err:
        mov     [hd_error], 1
        jmp     hd_read_error
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc bd_write_cache_chain ;////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        pusha
        mov     esi, [cache_chain_pos]
        shl     esi, 9
        call    calculate_cache_2
        add     esi, eax
        mov     edi, OS_BASE + 0x9a000
        movzx   ecx, [cache_chain_size]
        push    ecx
        shl     ecx, 9 - 2
        rep
        movsd
        pop     ecx
        mov     dl, 0x43
        mov     eax, [cache_chain_ptr]
        mov     eax, [eax]
        call    int13_call
        test    eax, eax
        jnz     .v86err
        cmp     edx, ecx
        jnz     .writeerr
        popa
        ret

  .v86err:
  .writeerr:
        popa
        mov     [hd_error], 1
        jmp     hd_write_error
kendp

uglobal
  int13_regs_in  rb sizeof.v86_regs_t
  int13_regs_out rb sizeof.v86_regs_t
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc int13_call ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;# Because this code uses fixed addresses, it can not be run simultaniously by many threads.
;# In current implementation it is protected by common mutex 'hd1_status'
;-----------------------------------------------------------------------------------------------------------------------
        mov     word[OS_BASE + 0x510], 0x10 ; packet length
        mov     word[OS_BASE + 0x512], cx ; number of sectors
        mov     dword[OS_BASE + 0x514], 0x9a000000 ; buffer 9A00:0000
        mov     dword[OS_BASE + 0x518], eax
        and     dword[OS_BASE + 0x51c], 0
        push    ebx ecx esi edi
        mov     ebx, int13_regs_in
        mov     edi, ebx
        mov     ecx, sizeof.v86_regs_t / 4
        xor     eax, eax
        rep
        stosd
        mov     byte[ebx + v86_regs_t.eax + 1], dl
        mov     eax, [hdpos]
        lea     eax, [BiosDisksData + (eax - 0x80) * 4]
        mov     dl, [eax]
        mov     byte[ebx + v86_regs_t.edx], dl
        movzx   edx, byte[eax + 1]
;       mov     dl, 5
        test    edx, edx
        jnz     .hasirq
        dec     edx
        jmp     @f

  .hasirq:
        pushad
        stdcall enable_irq, edx
        popad

    @@: mov     word[ebx + v86_regs_t.esi], 0x510
        mov     word[ebx + v86_regs_t.ss], 0x9000
        mov     word[ebx + v86_regs_t.esp], 0xa000
        mov     word[ebx + v86_regs_t.eip], 0x500
        mov     [ebx + v86_regs_t.eflags], 0x20200
        mov     esi, [sys_v86_machine]
        mov     ecx, 0x502
        push    fs
        call    v86_start
        pop     fs
        and     [bios_hdpos], 0
        pop     edi esi ecx ebx
        movzx   edx, byte[OS_BASE + 0x512]
        test    byte[int13_regs_out + v86_regs_t.eflags], 1
        jnz     @f
        mov     edx, ecx

    @@: ret
kendp
