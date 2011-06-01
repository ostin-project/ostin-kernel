;;======================================================================================================================
;;///// sys32.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
;; (c) 2003 MenuetOS <http://menuetos.net/>
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

align 4 ; 3A08
build_interrupt_table:
        mov     edi, idts
        mov     esi, sys_int
        mov     ecx, 0x40
        mov     eax, (10001110b shl 24) + os_code

    @@: movsw   ; low word of code-entry
        stosd   ; interrupt gate type : os_code selector
        movsw   ; high word of code-entry
        loop    @b
        movsd   ; copy low  dword of trap gate for int 0x40
        movsd   ; copy high dword of trap gate for int 0x40
        lidt    [esi]
        ret

iglobal
  align 4
  sys_int:
    ; exception handlers addresses (for interrupt gate construction)
    dd e0, e1, e2, e3, e4, e5, e6, except_7 ; SEE: core/fpu.inc
    dd e8, e9, e10, e11, e12, e13, page_fault_exc, e15
    dd e16, e17, e18, e19
    times 12 dd unknown_interrupt ; int_20..int_31

    ; interrupt handlers addresses (for interrupt gate construction)
    dd irq0, irq_serv.irq_1, irq_serv.irq_2

if KCONFIG_USE_COM_IRQ

    dd irq_serv.irq_3, irq_serv.irq_4

else

    dd p_irq3, p_irq4 ; ??? нестыковка

end if

    dd irq_serv.irq_5, p_irq6, irq_serv.irq_7
    dd irq_serv.irq_8, irq_serv.irq_9, irq_serv.irq_10
    dd irq_serv.irq_11, irq_serv.irq_12, irqD, p_irq14, p_irq15
    times 16 dd unknown_interrupt ; int_0x30..int_0x3F

    ; int_0x40 gate trap (for directly copied)
    dw i40 and 0x0ffff, os_code, 11101111b shl 8, i40 shr 16

  idtreg: ; data for LIDT instruction (!!! must be immediately below sys_int data)
    dw 2 * ($ - sys_int - 4) - 1
    dd idts ; 0x8000B100
    dw 0 ; просто выравнивание

  msg_fault_sel dd msg_exc_8, msg_exc_u, msg_exc_a, msg_exc_b, msg_exc_c, msg_exc_d, msg_exc_e

  msg_exc_8   db "Double fault", 0
  msg_exc_u   db "Undefined Exception", 0
  msg_exc_a   db "Invalid TSS", 0
  msg_exc_b   db "Segment not present", 0
  msg_exc_c   db "Stack fault", 0
  msg_exc_d   db "General protection fault", 0
  msg_exc_e   db "Page fault", 0
  msg_sel_ker db "kernel", 0
  msg_sel_app db "application", 0
endg

macro exc_wo_code [num]
{
  e#num:
        save_ring3_context
        mov     bl, num
        jmp     exc_c
}

exc_wo_code 0, 1, 2, 3, 4, 5, 6, 15, 16, 19

macro exc_w_code [num]
{
  e#num:
        add     esp, 4
        save_ring3_context
        mov     bl, num
        jmp     exc_c
}

exc_w_code 8, 9, 10, 11, 12, 13, 17, 18

uglobal
  pf_err_code dd ?
endg

page_fault_exc: ; дуракоусточивость: селекторы испорчены...
        pop     [ss:pf_err_code] ; действительно до следующего #PF
        save_ring3_context
        mov     bl, 14

exc_c: ; исключения (все, кроме 7-го - #NM)

; Фрэйм стека при исключении/прерывании из 3-го кольца + pushad (т.е., именно здесь)
reg_ss     equ esp + 0x30
reg_esp3   equ esp + 0x2c
reg_eflags equ esp + 0x28
reg_cs3    equ esp + 0x24
reg_eip    equ esp + 0x20

; это фрэйм от pushad
reg_eax    equ esp + 0x1c
reg_ecx    equ esp + 0x18
reg_edx    equ esp + 0x14
reg_ebx    equ esp + 0x10
reg_esp0   equ esp + 0x0c
reg_ebp    equ esp + 0x08
reg_esi    equ esp + 0x04
reg_edi    equ esp + 0x00

        Mov     ds, ax, app_data ; загрузим правильные значения
        mov     es, ax ; в сегментные регистры
        cld     ; и приводим DF к стандарту
        movzx   ebx, bl
        ; redirect to V86 manager? (EFLAGS & 0x20000) != 0?
        test    byte[reg_eflags + 2], 2
        jnz     v86_exc_c
        cmp     bl, 14 ; #PF
        jne     @f
        call    page_fault_handler ; SEE: core/memory.inc

    @@: mov     esi, [current_slot]
        btr     [esi + app_data_t.except_mask], ebx
        jnc     @f
        mov     eax, [esi + app_data_t.exc_handler]
        test    eax, eax
        jnz     IRetToUserHook

    @@: cli
        mov     eax, [esi + app_data_t.debugger_slot]
        test    eax, eax
        jnz     .debug
        sti
        ; not debuggee => say error and terminate
        call    show_error_parameters ;; only ONE using, inline ???
;       mov     edx, [TASK_BASE]
        mov     [edx + task_data_t.state], 4 ; terminate
        jmp     change_task ; stack - here it does not matter at all, SEE: core/shed.inc

  .debug:
        ; we are debugged process, notify debugger and suspend ourself
        ; eax=debugger PID
        mov     ecx, 1 ; debug_message code=other_exception
        cmp     bl, 1 ; #DB
        jne     .notify ; notify debugger and suspend ourself
        mov     ebx, dr6 ; debug_message data=DR6_image
        xor     edx, edx
        mov     dr6, edx
        mov     edx, dr7
        mov     cl, not 8

  .l1:
        shl     dl, 2
        jc      @f
        and     bl, cl

    @@: sar     cl, 1
        jc      .l1
        mov     cl, 3 ; debug_message code=debug_exception

  .notify:
        push    ebx ; debug_message data
        mov     ebx, [TASK_BASE]
        push    [ebx + task_data_t.pid] ; PID
        push    ecx ; debug_message code ((here: ecx==1/3))
        mov     cl, 12 ; debug_message size
        call    debugger_notify ;; only ONE using, inline ??? SEE: core/debug.inc
        add     esp, 12
        mov     edx, [TASK_BASE]
        mov     [edx + task_data_t.state], 1 ; suspended
        call    change_task ; SEE: core/shed.inc
        restore_ring3_context
        iretd

IRetToUserHook:
        xchg    eax, [reg_eip]
        sub     dword[reg_esp3], 8
        mov     edi, [reg_esp3]
        stosd
        mov     [edi], ebx
        restore_ring3_context

unknown_interrupt:
        iretd

;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
show_error_parameters:
        mov     edx, [TASK_BASE] ; not scratched below
        DEBUGF  1, "K : Process - forced terminate PID: %x\n", [edx + task_data_t.pid]
        cmp     bl, 0x08
        jb      .l0
        cmp     bl, 0x0e
        jbe     .l1

  .l0:
        mov     bl, 0x09

  .l1:
        mov     eax, [msg_fault_sel + ebx * 4 - 0x08 * 4]
        DEBUGF  1, "K : %s\n", eax
        mov     eax, [reg_cs3 + 4]
        mov     edi, msg_sel_app
        mov     ebx, [reg_esp3 + 4]
        cmp     eax, app_code
        je      @f
        mov     edi, msg_sel_ker
        mov     ebx, [reg_esp0 + 4]

    @@: DEBUGF  1, "K : EAX : %x EBX : %x ECX : %x\n", [reg_eax + 4], [reg_ebx + 4], [reg_ecx + 4]
        DEBUGF  1, "K : EDX : %x ESI : %x EDI : %x\n", [reg_edx + 4], [reg_esi + 4], [reg_edi + 4]
        DEBUGF  1, "K : EBP : %x EIP : %x ESP : %x\n", [reg_ebp + 4], [reg_eip + 4], ebx
        DEBUGF  1, "K : Flags : %x CS : %x (%s)\n", [reg_eflags + 4], eax, edi
        ret
;-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

restore reg_ss
restore reg_esp3
restore reg_eflags
restore reg_cs
restore reg_eip
restore reg_eax
restore reg_ecx
restore reg_edx
restore reg_ebx
restore reg_esp0
restore reg_ebp
restore reg_esi
restore reg_edi

; irq1  ->  hid/keyboard.inc
macro irqh [num]
{
  p_irq#num:
        mov     edi, num
        jmp     irqhandler
}

p_irq6:
        save_ring3_context
        mov     ax, app_data ; os_data
        mov     ds, ax
        mov     es, ax
        mov     edi, 6
        cmp     [v86_irqhooks + edi * 8], 0
        jnz     v86_irq2
        call    fdc_irq
        call    ready_for_next_irq
        restore_ring3_context
        iret

p_irq14:
        save_ring3_context
        mov     ax, app_data ; os_data
        mov     ds, ax
        mov     es, ax
        mov     edi, 14
        cmp     [v86_irqhooks + edi * 8], 0
        jnz     v86_irq2
;       mov     byte[BOOT_VAR + 0x48e], 0xff
        call    [irq14_func]
        call    ready_for_next_irq_1
        restore_ring3_context
        iret

p_irq15:
        save_ring3_context
        mov     ax, app_data ; os_data
        mov     ds, ax
        mov     es, ax
        mov     edi, 15
        cmp     [v86_irqhooks + edi * 8], 0
        jnz     v86_irq2
;       mov     byte[BOOT_VAR + 0x48e], 0xff
        call    [irq15_func]
        call    ready_for_next_irq_1
        restore_ring3_context
        iret

ready_for_next_irq:
        mov     eax, 5
        mov     [check_idle_semaphore], eax
;       mov     al, 0x20
        add     eax, 0x20 - 0x5
        out     0x20, al
        ret

; destroy eax
ready_for_next_irq_1:
        mov     eax, 5
        mov     [check_idle_semaphore], eax
;       mov     al, 0x20
        add     eax, 0x20 - 0x5
        out     0xa0, al
        out     0x20, al
        ret

irqD:
        push    eax
        xor     eax, eax
        out     0xf0, al
        mov     al, 0x20
        out     0xa0, al
        out     0x20, al
        pop     eax
        iret

irqh 2, 3, 4, 5, 7, 8, 9, 10, 11

irqhandler:
        mov     esi, edi ; 1
        shl     esi, 6 ; 1
        add     esi, irq00read ; 1
        shl     edi, 12 ; 1
        add     edi, IRQ_SAVE
        mov     ecx, 16

  .irqnewread:
        dec     ecx
        js      .irqover

        movzx   edx, word[esi] ; 2+

        test    edx, edx ; 1
        jz      .irqover


        mov     ebx, [edi]  ; address of begin of buffer in edi; +0x0 dword - data size, +0x4 dword - data begin offset
        mov     eax, 4000
        cmp     ebx, eax
        je      .irqfull
        add     ebx, [edi + 0x4] ; add data size to data begin offset
        cmp     ebx, eax ; if end of buffer, begin cycle again
        jb      @f

        xor     ebx, ebx

    @@: add     ebx, edi
        movzx   eax, byte[esi + 3] ; get type of data being received 1 - byte, 2 - word
        dec     eax
        jz      .irqbyte
        dec     eax
        jnz     .noirqword

        in      ax, dx
        cmp     ebx, 3999 ; check for address odd in the end of buffer
        jne     .odd
        mov     [ebx + 0x10], ax
        jmp     .add_size

  .odd:
        mov     [ebx + 0x10], al ; I could make mistake here :)
        mov     [edi + 0x10], ah

  .add_size:
        add     dword[edi], 2
        jmp     .nextport

  .irqbyte:
        in      al, dx
        mov     [ebx + 0x10], al
        inc     dword[edi]

  .nextport:
        add     esi, 4
        jmp     .irqnewread

  .noirqword:
  .irqfull:
  .irqover:
     ret

set_application_table_status:
        push    eax

        mov     eax, [CURRENT_TASK]
        shl     eax, 5
        add     eax, CURRENT_TASK + task_data_t.pid
        mov     eax, [eax]

        mov     [application_table_status], eax

        pop     eax

        ret


clear_application_table_status:
        push    eax

        mov     eax, [CURRENT_TASK]
        shl     eax, 5
        add     eax, CURRENT_TASK + task_data_t.pid
        mov     eax, [eax]

        cmp     eax, [application_table_status]
        jne     .apptsl1
        xor     eax, eax
        mov     [application_table_status], eax

  .apptsl1:
        pop  eax

        ret

;  * eax = 64 - номер функции
;  * ebx = 1 - единственная подфункция
;  * ecx = новый размер памяти
; Возвращаемое значение:
;  * eax = 0 - успешно
;  * eax = 1 - недостаточно памяти
sys_resize_app_memory:
        ; ebx = 1 - resize
        ; ecx = new amount of memory

;       cmp     eax, 1
        dec     ebx
        jnz     .no_application_mem_resize
        stdcall new_mem_resize, ecx
        mov     [esp + 32], eax

  .no_application_mem_resize:
        ret

iglobal
; process_terminating db 'K : Process - terminating', 13, 10, 0
; process_terminated  db 'K : Process - done', 13, 10, 0
  msg_obj_destroy     db 'K : destroy app object', 13, 10, 0
endg

terminate: ; terminate application
        ; param
        ;  esi= slot

.slot equ esp ; locals

        push    esi ; save .slot

        shl     esi, 8
        cmp     [SLOT_BASE + esi + app_data_t.dir_table], 0
        jne     @f
        pop     esi
        shl     esi, 5
        mov     [CURRENT_TASK + esi + task_data_t.state], 9
        ret

;   @@: mov     esi, process_terminating
;       call    sys_msg_board_str

    @@: cli
        cmp     [application_table_status], 0
        je      .term9
        sti
        call    change_task
        jmp     @b

  .term9:
        call    set_application_table_status

        ; if the process is in V86 mode...
        mov     eax, [.slot]
        shl     eax, 8
        mov     esi, [eax + SLOT_BASE + app_data_t.pl0_stack]
        add     esi, RING0_STACK_SIZE
        cmp     [eax + SLOT_BASE + app_data_t.saved_esp0], esi
        jz      .nov86
        ; ...it has page directory for V86 mode
        mov     esi, [eax + SLOT_BASE + app_data_t.saved_esp0]
        mov     ecx, [esi + 4]
        mov     [eax + SLOT_BASE + app_data_t.dir_table], ecx
        ; ...and I/O permission map for V86 mode
        mov     ecx, [esi + 12]
        mov     [eax + SLOT_BASE + app_data_t.io_map], ecx
        mov     ecx, [esi + 8]
        mov     [eax + SLOT_BASE + app_data_t.io_map + 4], ecx

  .nov86:
        mov     esi, [.slot]
        shl     esi, 8
        add     esi, SLOT_BASE + APP_OBJ_OFFSET

    @@: mov     eax, [esi + app_object_t.next_ptr]
        test    eax, eax
        jz      @f

        cmp     eax, esi
        je      @f

        push    esi
        call    [eax + app_object_t.destroy]
        DEBUGF  1, "%s", msg_obj_destroy
        pop     esi
        jmp     @b

    @@: mov     eax, [.slot]
        shl     eax, 8
        stdcall destroy_app_space, [SLOT_BASE + eax + app_data_t.dir_table], [SLOT_BASE + eax + app_data_t.dlls_list_ptr]

        mov     esi, [.slot]
        cmp     [fpu_owner], esi ; if user fpu last -> fpu user = 1
        jne     @f

        mov     [fpu_owner], 1
        mov     eax, [256 + SLOT_BASE + app_data_t.fpu_state]
        clts
        bt      [cpu_caps], CAPS_SSE
        jnc     .no_SSE
        fxrstor [eax]
        jmp     @f

  .no_SSE:
        fnclex
        frstor  [eax]

    @@: mov     byte[KEY_COUNT], 0 ; empty keyboard buffer
        mov     byte[BTN_COUNT], 0 ; empty button buffer

        ; remove defined hotkeys
        mov     eax, hotkey_list

  .loop:
        cmp     [eax + 8], esi
        jnz     .cont
        mov     ecx, [eax]
        jecxz   @f
        push    dword[eax + 12]
        pop     dword[ecx + 12]

    @@: mov     ecx, [eax + 12]
        push    dword[eax]
        pop     dword[ecx]
        xor     ecx, ecx
        mov     [eax], ecx
        mov     [eax + 4], ecx
        mov     [eax + 8], ecx
        mov     [eax + 12], ecx

  .cont:
        add     eax, 16
        cmp     eax, hotkey_list + 256 * 16
        jb      .loop
        ; remove hotkeys in buffer
        mov     eax, hotkey_buffer

  .loop2:
        cmp     [eax], esi
        jnz     .cont2
        and     dword[eax + 4], 0
        and     dword[eax], 0

  .cont2:
        add     eax, 8
        cmp     eax, hotkey_buffer + 120 * 8
        jb      .loop2

        mov     ecx, esi ; remove buttons

  bnewba2:
        mov     edi, [BTN_ADDR]
        mov     eax, edi
        cld
        movzx   ebx, word[edi]
        inc     bx

  bnewba:
        dec     bx
        jz      bnmba
        add     eax, 0x10
        cmp     cx, [eax]
        jnz     bnewba
        pusha
        mov     ecx, ebx
        inc     ecx
        shl     ecx, 4
        mov     ebx, eax
        add     eax, 0x10
        call    memmove
        dec     dword[edi]
        popa
        jmp     bnewba2

  bnmba:
        pusha   ; save window coordinates for window restoring
        cld
        shl     esi, 5
        add     esi, window_data
        mov     eax, [esi + window_data_t.box.left]
        mov     [draw_limits.left], eax
        add     eax, [esi + window_data_t.box.width]
        mov     [draw_limits.right], eax
        mov     eax, [esi + window_data_t.box.top]
        mov     [draw_limits.top], eax
        add     eax, [esi + window_data_t.box.height]
        mov     [draw_limits.bottom], eax

        xor     eax, eax
        mov     [esi + window_data_t.box.left], eax
        mov     [esi + window_data_t.box.width], eax
        mov     [esi + window_data_t.box.top], eax
        mov     [esi + window_data_t.box.height], eax
        mov     [esi + window_data_t.cl_workarea], eax
        mov     [esi + window_data_t.cl_titlebar], eax
        mov     [esi + window_data_t.cl_frames], eax
        mov     dword[esi + window_data_t.reserved], eax ; clear all flags: wstate, redraw, wdrawn
        lea     edi, [esi - window_data + draw_data]
        mov     ecx, 32 / 4
        rep     stosd
        popa

        ; debuggee test
        pushad
        mov     edi, esi
        shl     edi, 5
        mov     eax, [SLOT_BASE + edi * 8 + app_data_t.debugger_slot]
        test    eax, eax
        jz      .nodebug
        push    8
        pop     ecx
        push    dword[CURRENT_TASK + edi + task_data_t.pid] ; PID
        push    2
        call    debugger_notify
        pop     ecx
        pop     ecx

  .nodebug:
        popad

        mov     ebx, [.slot]
        shl     ebx, 8
        push    ebx
        mov     ebx, [SLOT_BASE + ebx + app_data_t.pl0_stack]

        stdcall kernel_free, ebx

        pop     ebx
        mov     ebx, [SLOT_BASE + ebx + app_data_t.cur_dir]
        stdcall kernel_free, ebx

        mov     edi, [.slot]
        shl     edi, 8
        add     edi, SLOT_BASE

        mov     eax, [edi + app_data_t.io_map]
        cmp     eax, [SLOT_BASE + 256 + app_data_t.io_map]
        je      @f
        call    free_page

    @@: mov     eax, [edi + app_data_t.io_map + 4]
        cmp     eax, [SLOT_BASE + 256 + app_data_t.io_map + 4]
        je      @f
        call    free_page

    @@: mov     eax, 0x20202020
        stosd
        stosd
        stosd
        mov     ecx, 244 / 4
        xor     eax, eax
        rep     stosd

        ; activate window
        movzx   eax, word[WIN_STACK + esi * 2]
        cmp     eax, [TASK_COUNT]
        jne     .dont_activate
        pushad

  .check_next_window:
        dec     eax
        cmp     eax, 1
        jbe     .nothing_to_activate
        lea     esi, [WIN_POS + eax * 2]
        movzx   edi, word[esi] ; edi = process
        shl     edi, 5
        cmp     [CURRENT_TASK + edi + task_data_t.state], 9 ; skip dead slots
        je      .check_next_window
        add     edi, window_data

        ; skip minimized windows
        test   [edi + window_data_t.fl_wstate], WSTATE_MINIMIZED
        jnz    .check_next_window

        call   waredraw

  .nothing_to_activate:
        popad

  .dont_activate:
        push    esi ; remove hd1 & cd & flp reservation
        shl     esi, 5
        mov     esi, [esi + CURRENT_TASK + task_data_t.pid]
        cmp     [hd1_status], esi
        jnz     @f
        call    free_hd_channel
        and     [hd1_status], 0

    @@: cmp     [cd_status], esi
        jnz     @f
        call    free_cd_channel
        and     [cd_status], 0

    @@: cmp     [flp_status], esi
        jnz     @f
        and     [flp_status], 0

    @@: pop     esi
        cmp     [bgrlockpid], esi
        jnz     @f
        and     [bgrlockpid], 0
        and     [bgrlock], 0

    @@: pusha   ; remove all irq reservations
        mov     eax, esi
        shl     eax, 5
        mov     eax, [eax + CURRENT_TASK + task_data_t.pid]
        mov     edi, irq_owner
        xor     ebx, ebx
        xor     edx, edx

  newirqfree:
        cmp     [edi + ebx * 4], eax
        jne     nofreeirq
        mov     [edi + ebx * 4], edx ; remove irq reservation
        mov     [irq_tab + ebx * 4], edx ; remove irq handler
        mov     [irq_rights + ebx * 4], edx ; set access rights to full access

  nofreeirq:
        inc     ebx
        cmp     ebx, 16
        jb      newirqfree
        popa

        pusha   ; remove all port reservations
        mov     edx, esi
        shl     edx, 5
        add     edx, CURRENT_TASK
        mov     edx, [edx + task_data_t.pid]

  rmpr0:
        mov     esi, [RESERVED_PORTS]

        test    esi, esi
        jz      rmpr9

  rmpr3:
        mov     edi, esi
        shl     edi, 4
        add     edi, RESERVED_PORTS

        cmp     edx, [edi]
        je      rmpr4

        dec     esi
        jnz     rmpr3

        jmp     rmpr9

  rmpr4:
        mov     ecx, 256
        sub     ecx, esi
        shl     ecx, 4

        mov     esi, edi
        add     esi, 16
        cld
        rep     movsb

        dec     dword[RESERVED_PORTS]

        jmp     rmpr0

  rmpr9:
        popa
        mov     edi, esi ; do not run this process slot
        shl     edi, 5
        mov     [edi + CURRENT_TASK + task_data_t.state], 9
        ; debugger test - terminate all debuggees
        mov     eax, 2
        mov     ecx, SLOT_BASE + 2 * 0x100 + app_data_t.debugger_slot

  .xd0:
        cmp     eax, [TASK_COUNT]
        ja      .xd1
        cmp     [ecx], esi
        jnz     @f
        and     dword[ecx], 0
        pushad
        xchg    eax, ecx
        mov     ebx, 2
        call    sys_system
        popad

    @@: inc     eax
        add     ecx, 0x100
        jmp     .xd0

  .xd1:
;       call    systest
        sti     ; .. and life goes on

        mov     eax, [draw_limits.left]
        mov     ebx, [draw_limits.top]
        mov     ecx, [draw_limits.right]
        mov     edx, [draw_limits.bottom]
        call    calculatescreen
        xor     eax, eax
        xor     esi, esi
        call    redrawscreen

        mov     byte[MOUSE_BACKGROUND], 0 ; no mouse background
        mov     byte[DONT_DRAW_MOUSE], 0 ; draw mouse

        and     [application_table_status], 0
;       mov     esi,process_terminated
;       call    sys_msg_board_str
        add     esp, 4
        ret

restore .slot

iglobal
  boot_sched_1 db 'Building gdt tss pointer', 0
  boot_sched_2 db 'Building IDT table', 0
endg

build_scheduler:
        mov     esi, boot_sched_1
        call    boot_log
;       call    build_process_gdt_tss_pointer

;       mov     esi, boot_sched_2
;       call    boot_log

        ret
