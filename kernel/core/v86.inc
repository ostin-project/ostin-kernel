;;======================================================================================================================
;;///// v86.inc //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2008-2010 KolibriOS team <http://kolibrios.org/>
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

; Virtual-8086 mode manager
; diamond, 2007, 2008

DEBUG_SHOW_IO = 0

struct V86_machine
  pagedir dd ? ; page directory
  pages   dd ? ; translation table: V86 address -> flat linear address
  mutex   dd ? ; mutex to protect all data from writing by multiple threads at one time
  iopm    dd ? ; i/o permission map
ends

v86_create:
        ; Create V86 machine
        ; in: nothing
        ; out: eax = handle (pointer to struc V86_machine)
        ;      eax = NULL => failure
        ; destroys: ebx, ecx, edx (due to malloc)

        ; allocate V86_machine structure
        mov     eax, sizeof.V86_machine
        call    malloc
        test    eax, eax
        jz      .fail
        ; initialize mutex
        and     [eax + V86_machine.mutex], 0
        ; allocate tables
        mov     ebx, eax
        ; We allocate 4 pages.
        ; First is main page directory for V86 mode.
        ; Second page:
        ; first half (0x800 bytes) is page table for addresses 0 - 0x100000,
        ; second half is for V86-to-linear translation.
        ; Third and fourth are for I/O permission map.
        push    0x08000 ; blocks less than 8 pages are discontinuous
        call    kernel_alloc
        test    eax, eax
        jz      .fail2
        mov     [ebx + V86_machine.pagedir], eax
        push    edi eax
        mov     edi, eax
        add     eax, 0x1800
        mov     [ebx + V86_machine.pages], eax
        ; initialize tables
        mov     ecx, 0x2000 / 4
        xor     eax, eax
        rep     stosd
        mov     [ebx + V86_machine.iopm], edi
        dec     eax
        mov     ecx, 0x2000 / 4
        rep     stosd
        pop     eax
        ; page directory: first entry is page table...
        mov     edi, eax
        add     eax, 0x1000
        push    eax
        call    get_pg_addr
        or      al, PG_UW
        stosd
        ; ...and also copy system page tables
        ; thx to Serge, system is located at high addresses
        add     edi, (OS_BASE shr 20) - 4
        push    esi
        mov     esi, (OS_BASE shr 20) + sys_pgdir
        mov     ecx, 0x080000000 shr 22
        rep     movsd

        mov     eax, [ebx + V86_machine.pagedir] ;root dir also is
        call    get_pg_addr ; used as page table
        or      al, PG_SW
        mov     [edi - 4096 + (page_tabs shr 20)], eax

        pop     esi
        ; now V86 specific: initialize known addresses in first Mb
        pop     eax
        ; first page - BIOS data (shared between all machines!)
        ; physical address = 0
        ; linear address = OS_BASE
        mov     dword[eax], 0111b
        mov     dword[eax + 0x0800], OS_BASE
        ; page before 0xA0000 - Extended BIOS Data Area (shared between all machines!)
        ; physical address = 0x9C000
        ; linear address = 0x8009C000
        ; (I have seen one computer with EBDA segment = 0x9D80,
        ; all other computers use less memory)
        mov     ecx, 4
        mov     edx, 0x09C000
        push    eax
        lea     edi, [eax + 0x09c * 4]

    @@: lea     eax, [edx + OS_BASE]
        mov     [edi + 0x0800], eax
        lea     eax, [edx + 0111b]
        stosd
        add     edx, 0x1000
        loop    @b
        pop     eax
        pop     edi
        ; addresses 0xC0000 - 0xFFFFF - BIOS code (shared between all machines!)
        ; physical address = 0xC0000
        ; linear address = 0x800C0000
        mov     ecx, 0x0c0

    @@: mov     edx, ecx
        shl     edx, 12
        push    edx
        or      edx, 0111b
        mov     [eax + ecx * 4], edx
        pop     edx
        add     edx, OS_BASE
        mov     [eax + ecx * 4 + 0x0800], edx
        inc     cl
        jnz     @b
        mov     eax, ebx
        ret

  .fail2:
        mov     eax, ebx
        call    free

  .fail:
        xor     eax, eax
        ret

v86_destroy:
        ; Destroy V86 machine
        ; in: eax = handle
        ; out: nothing
        ; destroys: eax, ebx, ecx, edx (due to free)

        push    eax
        stdcall kernel_free, [eax + V86_machine.pagedir]
        pop     eax
        jmp     free

v86_get_lin_addr:
        ; Translate V86-address to linear address
        ; in: eax=V86 address
        ;     esi=handle
        ; out: eax=linear address
        ; destroys: nothing

        push    ecx edx
        mov     ecx, eax
        mov     edx, [esi + V86_machine.pages]
        shr     ecx, 12
        and     eax, 0x0fff
        add     eax, [edx + ecx * 4] ; atomic operation, no mutex needed
        pop     edx ecx
        ret

v86_set_page:
        ; Sets linear address for V86-page
        ; in: eax=linear address (must be page-aligned)
        ;     ecx=V86 page (NOT address!)
        ;     esi=handle
        ; out: nothing
        ; destroys: nothing

        push    eax ebx
        mov     ebx, [esi + V86_machine.pagedir]
        mov     [ebx + ecx * 4 + 0x1800], eax
        call    get_pg_addr
        or      al, 0111b
        mov     [ebx + ecx * 4 + 0x1000], eax
        pop     ebx eax
        ret

;v86_alloc:
        ; Allocate memory in V86 machine
        ; in: eax=size (in bytes)
        ;     esi=handle
        ; out: eax=V86 address, para-aligned (0x10 multiple)
        ; destroys: nothing
        ; недописана!!!

;       push    ebx ecx edx edi
;       lea     ebx, [esi + V86_machine.mutex]
;       call    wait_mutex
;       add     eax, 0x1f
;       shr     eax, 4
;       mov     ebx, 0x1000 ; start with address 0x1000 (second page)
;       mov     edi, [esi + V86_machine.tables]
;
; .l:
;       mov     ecx, ebx
;       shr     ecx, 12
;       mov     edx, [edi + 0x1000 + ecx * 4] ; get linear address
;       test    edx, edx ; page allocated?
;       jz      .unalloc
;       mov     ecx, ebx
;       and     ecx, 0x0fff
;       add     edx, ecx
;       cmp     dword[edx], 0 ; free block?
;       jnz     .n
;       cmp     dword[edx + 4],
;       and     [esi + V86_machine.mutex], 0
;       pop     edi edx ecx ebx
;       ret

uglobal
  sys_v86_machine dd ?
endg

init_sys_v86:
        ; Called from kernel.asm at first stages of loading
        ; Initialize system V86 machine (used to simulate BIOS int 13h)

        call    v86_create
        mov     [sys_v86_machine], eax
        test    eax, eax
        jz      .ret
        mov     byte[OS_BASE + 0x500], 0x0cd
        mov     byte[OS_BASE + 0x501], 0x13
        mov     byte[OS_BASE + 0x502], 0x0f4
        mov     byte[OS_BASE + 0x503], 0x0cd
        mov     byte[OS_BASE + 0x504], 0x10
        mov     byte[OS_BASE + 0x505], 0x0f4
        mov     esi, eax
        mov     ebx, [eax + V86_machine.pagedir]
        ; one page for stack, two pages for results (0x2000 bytes = 16 sectors)
        mov     dword[ebx + 0x099 * 4 + 0x1000], 0x099000 or 0111b
        mov     dword[ebx + 0x099 * 4 + 0x1800], OS_BASE + 0x099000
        mov     dword[ebx + 0x09a * 4 + 0x1000], 0x09a000 or 0111b
        mov     dword[ebx + 0x09a * 4 + 0x1800], OS_BASE + 0x09a000
        mov     dword[ebx + 0x09b * 4 + 0x1000], 0x09b000 or 0111b
        mov     dword[ebx + 0x09b * 4 + 0x1800], OS_BASE + 0x09b000

if ~DEBUG_SHOW_IO

        ; allow access to all ports
        mov     ecx, [esi + V86_machine.iopm]
        xor     eax, eax
        mov     edi, ecx
        mov     ecx, 0x10000 / 8 / 4
        rep     stosd

end if

  .ret:
        ret

struct v86_regs
  ; don't change the order, it is important
  edi    dd ?
  esi    dd ?
  ebp    dd ?
         dd ? ; ignored
  ebx    dd ?
  edx    dd ?
  ecx    dd ?
  eax    dd ?
  eip    dd ?
  cs     dd ?
  eflags dd ? ; VM flag must be set!
  esp    dd ?
  ss     dd ?
  es     dd ?
  ds     dd ?
  fs     dd ?
  gs     dd ?
ends

v86_start:
        ; Run V86 machine
        ; in: ebx -> registers for V86 (two structures: in and out)
        ;     esi = handle
        ;     ecx = expected end address (CS:IP)
        ;     edx = IRQ to hook or -1 if not required
        ; out: structure pointed to by ebx is filled with new values
        ;     eax = 1 - exception has occured, cl contains code
        ;     eax = 2 - access to disabled i/o port, ecx contains port address
        ;     eax = 3 - IRQ is already hooked by another VM
        ; destroys: nothing

        pushad

        cli

        mov     ecx, [CURRENT_TASK]
        shl     ecx, 8
        add     ecx, SLOT_BASE

        mov     eax, [esi + V86_machine.iopm]
        call    get_pg_addr
        inc     eax
        push    dword[ecx + APPDATA.io_map]
        push    dword[ecx + APPDATA.io_map + 4]
        mov     dword[ecx + APPDATA.io_map], eax
        mov     dword[page_tabs + (tss._io_map_0 shr 10)], eax
        add     eax, 0x1000
        mov     dword[ecx + APPDATA.io_map + 4], eax
        mov     dword[page_tabs + (tss._io_map_1 shr 10)], eax

        push    [ecx + APPDATA.dir_table]
        push    [ecx + APPDATA.saved_esp0]
        mov     [ecx + APPDATA.saved_esp0], esp
        mov     [tss._esp0], esp

        mov     eax, [esi + V86_machine.pagedir]
        call    get_pg_addr
        mov     [ecx + APPDATA.dir_table], eax
        mov     cr3, eax

;       mov     [irq_tab + 5 * 4], my05

        ; We do not enable interrupts, because V86 IRQ redirector assumes that
        ; machine is running
        ; They will be enabled by IRET.
;       sti

        mov     eax, esi
        sub     esp, sizeof.v86_regs
        mov     esi, ebx
        mov     edi, esp
        mov     ecx, sizeof.v86_regs / 4
        rep     movsd

        cmp     edx, -1
        jz      .noirqhook

uglobal
  v86_irqhooks rd 16 * 2
endg

        cmp     [v86_irqhooks + edx * 8], 0
        jz      @f
        cmp     [v86_irqhooks + edx * 8], eax
        jz      @f
        mov     esi, v86_irqerr
        call    sys_msg_board_str
        inc     [v86_irqhooks + edx * 8 + 4]
        mov     eax, 3
        jmp     v86_exc_c.exit

    @@: mov     [v86_irqhooks + edx * 8], eax
        inc     [v86_irqhooks + edx * 8 + 4]

  .noirqhook:
        popad
        iretd

; It is only possible to leave virtual-8086 mode by faulting to
; a protected-mode interrupt handler (typically the general-protection
; exception handler, which in turn calls the virtual 8086-mode monitor).

iglobal
  v86_exc_str1 db 'V86 : unexpected exception ', 0
  v86_exc_str2 db ' at ', 0
  v86_exc_str3 db ':', 0
  v86_exc_str4 db 13, 10, 'V86 : faulted code:', 0
  v86_exc_str5 db ' (unavailable)', 0
  v86_newline  db 13, 10, 0
  v86_io_str1  db 'V86 : access to disabled i/o port ', 0
  v86_io_byte  db ' (byte)', 13, 10, 0
  v86_io_word  db ' (word)', 13, 10, 0
  v86_io_dword db ' (dword)', 13, 10, 0
  v86_irqerr   db 'V86 : IRQ already hooked', 13, 10, 0
endg

v86_exc_c:
        ; Did we all that we have wanted to do?
        cmp     bl, 1
        jne     @f
        xor     eax, eax
        mov     dr6, eax

    @@: mov     eax, [esp + sizeof.v86_regs + 0x10 + 0x18]
        cmp     word[esp + v86_regs.eip], ax
        jnz     @f
        shr     eax, 16
        cmp     word[esp + v86_regs.cs], ax
        jz      .done

    @@: ; Various system events, which must be handled, result in #GP
        cmp     bl, 13
        jnz     .nogp
        ; If faulted EIP exceeds 0xFFFF, we have #GP and it is an error
        cmp     word[esp + v86_regs.eip + 2], 0
        jnz     .nogp
        ; Otherwise we can safely access byte at CS:IP
        ; (because it is #GP, not #PF handler)
        ; Если бы мы могли схлопотать исключение только из-за чтения байтов кода,
        ; мы бы его уже схлопотали и это было бы не #GP
        movzx   esi, word[esp + v86_regs.cs]
        shl     esi, 4
        add     esi, [esp + v86_regs.eip]
        lodsb
        cmp     al, 0x0cd ; int xx command = CD xx
        jz      .handle_int
        cmp     al, 0x0cf
        jz      .handle_iret
        cmp     al, 0x0f3
        jz      .handle_rep
        cmp     al, 0x0ec
        jz      .handle_in
        cmp     al, 0x0ed
        jz      .handle_in_word
        cmp     al, 0x0ee
        jz      .handle_out
        cmp     al, 0x0ef
        jz      .handle_out_word
        cmp     al, 0x0e4
        jz      .handle_in_imm
        cmp     al, 0x0e6
        jz      .handle_out_imm
        cmp     al, 0x09c
        jz      .handle_pushf
        cmp     al, 0x09d
        jz      .handle_popf
        cmp     al, 0x0fa
        jz      .handle_cli
        cmp     al, 0x0fb
        jz      .handle_sti
        cmp     al, 0x66
        jz      .handle_66
        jmp     .nogp

  .handle_int:
        cmp     word[esp + v86_regs.eip], 0x0ffff
        jae     .nogp
        xor     eax, eax
        lodsb
;       call    sys_msg_board_byte
        ; simulate INT command
        ; N.B. It is possible that some checks need to be corrected,
        ;      but at least in case of normal execution the code works.

  .simulate_int:
        cmp     word[esp + v86_regs.esp], 6
        jae     @f
        mov     bl, 12 ; #SS exception
        jmp     .nogp

    @@: movzx   edx, word[esp + v86_regs.ss]
        shl     edx, 4
        push    eax
        movzx   eax, word[esp + 4 + v86_regs.esp]
        sub     eax, 6
        add     edx, eax
        mov     eax, edx
        mov     esi, [esp + 4 + sizeof.v86_regs + 0x10 + 4]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14 ; #PF exception
        jmp     .nogp

    @@: lea     eax, [edx + 5]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14 ; #PF exception
        jmp     .nogp

    @@: sub     word[esp + 4 + v86_regs.esp], 6
        mov     eax, [esp + 4 + v86_regs.eip]
        cmp     byte[esp + 1], 0
        jnz     @f
        inc     eax
        inc     eax

    @@: mov     word[edx], ax
        mov     eax, [esp + 4 + v86_regs.cs]
        mov     word[edx + 2], ax
        mov     eax, [esp + 4 + v86_regs.eflags]
        mov     word[edx + 4], ax
        pop     eax
        mov     ah, 0
        mov     cx, [eax * 4]
        mov     word[esp + v86_regs.eip], cx
        mov     cx, [eax * 4 + 2]
        mov     word[esp + v86_regs.cs], cx
        ; note that interrupts will be disabled globally at IRET
        and     byte[esp + v86_regs.eflags + 1], not 3 ; clear IF and TF flags
        ; continue V86 execution
        popad
        iretd

  .handle_iret:
        cmp     word[esp + v86_regs.esp], 0x10000 - 6
        jbe     @f
        mov     bl, 12
        jmp     .nogp

    @@: movzx   edx, word[esp + v86_regs.ss]
        shl     edx, 4
        movzx   eax, word[esp + v86_regs.esp]
        add     edx, eax
        mov     eax, edx
        mov     esi, [esp + sizeof.v86_regs + 0x10 + 4]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14
        jmp     .nogp

    @@: lea     eax, [edx + 5]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14
        jmp     .nogp

    @@: mov     ax, [edx]
        mov     word[esp + v86_regs.eip], ax
        mov     ax, [edx + 2]
        mov     word[esp + v86_regs.cs], ax
        mov     ax, [edx + 4]
        mov     word[esp + v86_regs.eflags], ax
        add     word[esp + v86_regs.esp], 6
        popad
        iretd

  .handle_pushf:
        cmp     word[esp + v86_regs.esp], 1
        jnz     @f
        mov     bl, 12
        jmp     .nogp

    @@: movzx   edx, word[esp + v86_regs.ss]
        shl     edx, 4
        mov     eax, [esp + v86_regs.esp]
        sub     eax, 2
        movzx   eax, ax
        add     edx, eax
        mov     eax, edx
        mov     esi, [esp + sizeof.v86_regs + 0x10 + 4]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14 ; #PF exception
        jmp     .nogp

    @@: lea     eax, [edx + 1]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14
        jmp     .nogp

    @@: sub     word[esp + v86_regs.esp], 2
        mov     eax, [esp + v86_regs.eflags]
        mov     [edx], ax
        inc     word[esp + v86_regs.eip]
        popad
        iretd

  .handle_pushfd:
        cmp     word[esp + v86_regs.esp], 4
        jae     @f
        mov     bl, 12 ; #SS exception
        jmp     .nogp

    @@: movzx   edx, word[esp + v86_regs.ss]
        shl     edx, 4
        movzx   eax, word[esp + v86_regs.esp]
        sub     eax, 4
        add     edx, eax
        mov     eax, edx
        mov     esi, [esp + sizeof.v86_regs + 0x10 + 4]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14 ; #PF exception
        jmp     .nogp

    @@: lea     eax, [edx + 3]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14 ; #PF exception
        jmp     .nogp

    @@: sub     word[esp + v86_regs.esp], 4
        movzx   eax, word[esp + v86_regs.eflags]
        mov     [edx], eax
        add     word[esp + v86_regs.eip], 2
        popad
        iretd

  .handle_popf:
        cmp     word[esp + v86_regs.esp], 0x0ffff
        jnz     @f
        mov     bl, 12
        jmp     .nogp

    @@: movzx   edx, word[esp + v86_regs.ss]
        shl     edx, 4
        movzx   eax, word[esp + v86_regs.esp]
        add     edx, eax
        mov     eax, edx
        mov     esi, [esp + sizeof.v86_regs + 0x10 + 4]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14 ; #PF exception
        jmp     .nogp

    @@: lea     eax, [edx + 1]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14
        jmp     .nogp

    @@: mov     ax, [edx]
        mov     word[esp + v86_regs.eflags], ax
        add     word[esp + v86_regs.esp], 2
        inc     word[esp + v86_regs.eip]
        popad
        iretd

  .handle_popfd:
        cmp     word[esp + v86_regs.esp], 0x10000 - 4
        jbe     @f
        mov     bl, 12
        jmp     .nogp

    @@: movzx   edx, word[esp + v86_regs.ss]
        shl     edx, 4
        movzx   eax, word[esp + v86_regs.esp]
        add     edx, eax
        mov     eax, edx
        mov     esi, [esp + sizeof.v86_regs + 0x10 + 4]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14
        jmp     .nogp

    @@: lea     eax, [edx + 3]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jae     @f
        mov     bl, 14
        jmp     .nogp

    @@: mov     eax, [edx]
        mov     word[esp + v86_regs.eflags], ax
        add     word[esp + v86_regs.esp], 4
        add     word[esp + v86_regs.eip], 2
        popad
        iretd

  .handle_cli:
        and     byte[esp + v86_regs.eflags + 1], not 2
        inc     word[esp + v86_regs.eip]
        popad
        iretd

  .handle_sti:
        or      byte[esp + v86_regs.eflags + 1], 2
        inc     word[esp + v86_regs.eip]
        popad
        iretd

  .handle_rep:
        cmp     word[esp + v86_regs.eip], 0x0ffff
        jae     .nogp
        lodsb
        cmp     al, 0x6e
        jz      .handle_rep_outsb
        jmp     .nogp

  .handle_rep_outsb:
  .handle_in:
  .handle_out:
  .invalid_io_byte:
        movzx   ebx, word[esp + v86_regs.edx]
        mov     ecx, 1
        jmp     .invalid_io

  .handle_in_imm:
  .handle_out_imm:
        cmp     word[esp + v86_regs.eip], 0x0ffff
        jae     .nogp
        lodsb
        movzx   ebx, al
        mov     ecx, 1
        jmp     .invalid_io

  .handle_66:
        cmp     word[esp + v86_regs.eip], 0x0ffff
        jae     .nogp
        lodsb
        cmp     al, 0x09c
        jz      .handle_pushfd
        cmp     al, 0x09d
        jz      .handle_popfd
        cmp     al, 0x0ef
        jz      .handle_out_dword
        cmp     al, 0x0ed
        jz      .handle_in_dword
        jmp     .nogp

  .handle_in_word:
  .handle_out_word:
        movzx   ebx, word[esp + v86_regs.edx]
        mov     ecx, 2
        jmp     .invalid_io

  .handle_in_dword:
  .handle_out_dword:
  .invalid_io_dword:
        movzx   ebx, word[esp + v86_regs.edx]
        mov     ecx, 4

  .invalid_io:
        mov     esi, v86_io_str1
        call    sys_msg_board_str
        mov     eax, ebx
        call    sys_msg_board_dword
        mov     esi, v86_io_byte
        cmp     ecx, 1
        jz      @f
        mov     esi, v86_io_word
        cmp     ecx, 2
        jz      @f
        mov     esi, v86_io_dword

    @@: call    sys_msg_board_str

if DEBUG_SHOW_IO

        mov     edx, ebx
        mov     ebx, 200
        call    delay_hs
        mov     esi, [esp + sizeof.v86_regs + 0x10 + 4]
        mov     eax, [esi + V86_machine.iopm]

    @@: btr     [eax], edx
        inc     edx
        loop    @b
        popad
        iretd

else

        mov     eax, 2
        jmp     .exit

end if

  .nogp:
        mov     esi, v86_exc_str1
        call    sys_msg_board_str
        mov     al, bl
        call    sys_msg_board_byte
        mov     esi, v86_exc_str2
        call    sys_msg_board_str
        mov     ax, [esp + 32 + 4]
        call    sys_msg_board_word
        mov     esi, v86_exc_str3
        call    sys_msg_board_str
        mov     ax, [esp + 32]
        call    sys_msg_board_word
        mov     esi, v86_exc_str4
        call    sys_msg_board_str
        mov     ecx, 8
        movzx   edx, word[esp + 32 + 4]
        shl     edx, 4
        add     edx, [esp + 32]

    @@: mov     esi, [esp + sizeof.v86_regs + 0x10 + 4]
        mov     eax, edx
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jb      .nopage
        mov     esi, v86_exc_str3 - 2
        call    sys_msg_board_str
        mov     al, [edx]
        call    sys_msg_board_byte
        inc     edx
        loop    @b
        jmp     @f

  .nopage:
        mov     esi, v86_exc_str5
        call    sys_msg_board_str

    @@: mov     esi, v86_newline
        call    sys_msg_board_str
        mov     eax, 1
        jmp     .exit

  .done:
        xor     eax, eax

  .exit:
        mov     [esp + sizeof.v86_regs + 0x10 + 0x1C], eax
        mov     [esp + sizeof.v86_regs + 0x10 + 0x18], ebx

        mov     edx, [esp + sizeof.v86_regs + 0x10 + 0x14]
        cmp     edx, -1
        jz      @f
        dec     [v86_irqhooks + edx * 8 + 4]
        jnz     @f
        and     [v86_irqhooks + edx * 8], 0

    @@: mov     esi, esp
        mov     edi, [esi + sizeof.v86_regs + 0x10 + 0x10]
        add     edi, sizeof.v86_regs
        mov     ecx, sizeof.v86_regs / 4
        rep     movsd
        mov     esp, esi

        cli
        mov     ecx, [CURRENT_TASK]
        shl     ecx, 8
        pop     eax
        mov     [SLOT_BASE + ecx + APPDATA.saved_esp0], eax
        mov     [tss._esp0], eax
        pop     eax
        mov     [SLOT_BASE + ecx + APPDATA.dir_table], eax
        pop     ebx
        mov     dword[SLOT_BASE + ecx + APPDATA.io_map + 4], ebx
        mov     dword[page_tabs + (tss._io_map_1 shr 10)], ebx
        pop     ebx
        mov     dword[SLOT_BASE + ecx + APPDATA.io_map], ebx
        mov     dword[page_tabs + (tss._io_map_0 shr 10)], ebx
        mov     cr3, eax
;       mov     [irq_tab + 5 * 4], 0
        sti

        popad
        ret

;my05:
;       mov     dx, 0x30C2
;       mov     cx, 4
;
; .0:
;       in      al, dx
;       cmp     al, 00ff
;       jz      @f
;       test    al, 4
;       jnz     .1
;
;   @@: add     dx, 8
;       in      al, dx
;       cmp     al, 0x0ff
;       jz      @f
;       test    al, 4
;       jnz     .1
;
;   @@: loop    .0
;       ret
;
; .1:
;       or      al, 0x084
;       out     dx, al
;
; .2:
;       mov     dx, 0x30f7
;       in      al, dx
;       mov     byte[BOOT_VAR + 0x48e], 0x0ff
;       ret

v86_irq:
        ; push irq/pushad/jmp v86_irq
        ; eax = irq

        lea     esi, [esp + 0x1c]
        lea     edi, [esi + 4]
        mov     ecx, 8
        std
        rep     movsd
        cld
        mov     edi, eax
        pop     eax

v86_irq2:
        mov     esi, [v86_irqhooks + edi * 8] ; get VM handle
        mov     eax, [esi + V86_machine.pagedir]
        call    get_pg_addr
        mov     ecx, [CURRENT_TASK]
        shl     ecx, 8
        cmp     [SLOT_BASE + ecx + APPDATA.dir_table], eax
        jnz     .notcurrent
        lea     eax, [edi + 8]
        cmp     al, 0x10
        mov     ah, 1
        jb      @f
        add     al, 0x60

    @@: jmp     v86_exc_c.simulate_int

  .notcurrent:
        mov     ebx, SLOT_BASE + 0x100
        mov     ecx, [TASK_COUNT]

  .scan:
        cmp     [ebx + APPDATA.dir_table], eax
        jnz     .cont
        push    ecx
        mov     ecx, [ebx + APPDATA.saved_esp0]
        cmp     word[ecx - sizeof.v86_regs + v86_regs.esp], 6
        jb      .cont2
        movzx   edx, word[ecx - sizeof.v86_regs + v86_regs.ss]
        shl     edx, 4
        push    eax
        movzx   eax, word[ecx - sizeof.v86_regs + v86_regs.esp]
        sub     eax, 6
        add     edx, eax
        mov     eax, edx
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jb      .cont3
        lea     eax, [edx + 5]
        call    v86_get_lin_addr
        cmp     eax, 0x1000
        jb      .cont3
        pop     eax
        pop     ecx
        jmp     .found

  .cont3:
        pop     eax

  .cont2:
        pop     ecx

  .cont:
        loop    .scan
        mov     al, 0x20
        out     0x20, al
        cmp     edi, 8
        jb      @f
        out     0x0a0, al

    @@: popad
        iretd

  .found:
        mov     cr3, eax
        sub     word[esi - sizeof.v86_regs + v86_regs.esp], 6
        mov     ecx, [esi - sizeof.v86_regs + v86_regs.eip]
        mov     word[edx], cx
        mov     ecx, [esi - sizeof.v86_regs + v86_regs.cs]
        mov     word[edx + 2], cx
        mov     ecx, [esi - sizeof.v86_regs + v86_regs.eflags]
        mov     word[edx + 4], cx
        lea     eax, [edi + 8]
        cmp     al, 0x10
        jb      @f
        add     al, 0x60

    @@: mov     cx, [eax * 4]
        mov     word[esi - sizeof.v86_regs + v86_regs.eip], cx
        mov     cx, [eax * 4 + 2]
        mov     word[esi - sizeof.v86_regs + v86_regs.cs], cx
        and     byte[esi - sizeof.v86_regs + v86_regs.eflags + 1], not 3
        call    update_counters
        lea     edi, [ebx + 0x100000000 - SLOT_BASE]
        shr     edi, 3
        add     edi, TASK_DATA
        call    find_next_task.found
        call    do_change_task
        popad
        iretd
