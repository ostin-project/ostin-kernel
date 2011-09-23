;;======================================================================================================================
;;///// debug.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69
;-----------------------------------------------------------------------------------------------------------------------
iglobal
  jump_table sysfn.debug_ctl, subfn, sysfn.not_implemented, \
    set_event_data, \ ; 0
    get_context, \ ; 1
    set_context, \ ; 2
    detach, \ ; 3
    suspend, \ ; 4
    resume, \ ; 5
    read_process_memory, \ ; 6
    write_process_memory, \ ; 7
    terminate, \ ; 8
    set_drx ; 9
endg
;-----------------------------------------------------------------------------------------------------------------------
        cmp     ebx, .countof.subfn
        jae     sysfn.not_implemented

        jmp     [.subfn + ebx * 4]
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.set_event_data ;//////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.0
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = pointer
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [current_slot]
        mov     [eax + app_data_t.dbg_event_mem], ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc get_debuggee_slot ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;-----------------------------------------------------------------------------------------------------------------------
;< CF = 0 (ok) or 1 (error)
;< eax = slot * 0x20 (ok)
;< IF = 0
;-----------------------------------------------------------------------------------------------------------------------
        cli
        mov     eax, ecx
        call    pid_to_slot
        test    eax, eax
        jz      .ret_bad
        shl     eax, 5
        push    ebx
        mov     ebx, [CURRENT_TASK]
        cmp     [SLOT_BASE + eax * 8 + app_data_t.debugger_slot], ebx
        pop     ebx
        jnz     .ret_bad
;       clc     ; automatically
        ret

  .ret_bad:
        stc
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.detach ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.3
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax,ebx
;-----------------------------------------------------------------------------------------------------------------------
        call    get_debuggee_slot
        jc      .ret
        and     [SLOT_BASE + eax * 8 + app_data_t.debugger_slot], 0
        call    do_resume

  .ret:
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.terminate ;///////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.8
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;-----------------------------------------------------------------------------------------------------------------------
        call    get_debuggee_slot
        jc      sysfn.debug_ctl.detach.ret
        mov     ecx, eax
        shr     ecx, 5
;       push    2
;       pop     ebx
        mov     edx, esi
        jmp     sysfn.system_ctl.kill_process_by_slot
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.suspend ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.4
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax, ecx
;-----------------------------------------------------------------------------------------------------------------------
        cli
        mov     eax, ecx
        call    pid_to_slot
        shl     eax, 5
        jz      .ret
        mov     cl, [TASK_DATA + eax - sizeof.task_data_t + task_data_t.state] ; process state
        test    cl, cl ; TSTATE_RUNNING
        jz      .1
        cmp     cl, TSTATE_WAITING
        jnz     .ret
        mov     cl, TSTATE_WAIT_SUSPENDED

  .2:
        mov     [TASK_DATA + eax - sizeof.task_data_t + task_data_t.state], cl

  .ret:
        sti
        ret

  .1:
        inc     ecx
        jmp     .2
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc do_resume ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     cl, [TASK_DATA + eax - sizeof.task_data_t + task_data_t.state]
        cmp     cl, TSTATE_RUN_SUSPENDED
        jz      .1
        cmp     cl, TSTATE_WAIT_SUSPENDED
        jnz     .ret
        mov     cl, TSTATE_WAITING

  .2:
        mov     [TASK_DATA + eax - sizeof.task_data_t + task_data_t.state], cl

  .ret:
        ret

  .1:
        dec     ecx
        jmp     .2
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.resume ;//////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.5
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax, ebx
;-----------------------------------------------------------------------------------------------------------------------
        cli
        mov     eax, ecx
        call    pid_to_slot
        shl     eax, 5
        jz      .ret
        call    do_resume

  .ret:
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.get_context ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.1
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;> edx = sizeof(CONTEXT)
;> esi = CONTEXT
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax, ecx, edx, esi, edi
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edx, 0x28
        jnz     .ret
;       push    ecx
;       mov     ecx, esi
        call    check_region
;       pop     ecx
        dec     eax
        jnz     .ret
        call    get_debuggee_slot
        jc      .ret
        mov     edi, esi
        mov     eax, [SLOT_BASE + eax * 8 + app_data_t.pl0_stack]
        lea     esi, [eax + RING0_STACK_SIZE]

  .ring0:
        ; note that following code assumes that all interrupt/exception handlers
        ; saves ring-3 context by pushad in this order
        ; top of ring0 stack: ring3 stack ptr (ss+esp), iret data (cs+eip+eflags), pushad
        sub     esi, 8 + 12 + 0x20
        lodsd   ; edi
        mov     [edi + 0x24], eax
        lodsd   ; esi
        mov     [edi + 0x20], eax
        lodsd   ; ebp
        mov     [edi + 0x1c], eax
        lodsd   ; esp
        lodsd   ; ebx
        mov     [edi + 0x14], eax
        lodsd   ; edx
        mov     [edi + 0x10], eax
        lodsd   ; ecx
        mov     [edi + 0x0c], eax
        lodsd   ; eax
        mov     [edi + 8], eax
        lodsd   ; eip
        mov     [edi], eax
        lodsd   ; cs
        lodsd   ; eflags
        mov     [edi + 4], eax
        lodsd   ; esp
        mov     [edi + 0x18], eax

  .ret:
        sti
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.set_context ;/////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.2
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;> edx = sizeof(CONTEXT)
;> esi = CONTEXT
;-----------------------------------------------------------------------------------------------------------------------
;# destroys eax, ecx, edx, esi, edi
;-----------------------------------------------------------------------------------------------------------------------
        cmp     edx, 0x28
        jnz     .ret
;       push    ebx
;       mov     ebx, edx
        call    check_region
;       pop     ebx
        dec     eax
        jnz     .ret
        call    get_debuggee_slot
        jc      .stiret
;       mov     esi, edx
        mov     eax, [SLOT_BASE + eax * 8 + app_data_t.pl0_stack]
        lea     edi, [eax + RING0_STACK_SIZE]

  .ring0:
        sub     edi, 8 + 12 + 0x20
        mov     eax, [esi + 0x24] ; edi
        stosd
        mov     eax, [esi + 0x20] ; esi
        stosd
        mov     eax, [esi + 0x1c] ; ebp
        stosd
        scasd
        mov     eax, [esi + 0x14] ; ebx
        stosd
        mov     eax, [esi + 0x10] ; edx
        stosd
        mov     eax, [esi + 0x0c] ; ecx
        stosd
        mov     eax, [esi + 8] ; eax
        stosd
        mov     eax, [esi] ; eip
        stosd
        scasd
        mov     eax, [esi + 4] ; eflags
        stosd
        mov     eax, [esi + 0x18] ; esp
        stosd

  .stiret:
        sti

  .ret:
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.set_drx ;/////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.9
;-----------------------------------------------------------------------------------------------------------------------
        call    get_debuggee_slot
        jc      .errret
        mov     ebp, eax
        lea     eax, [SLOT_BASE + eax * 8 + app_data_t.dbg_regs]
        ; [eax]=dr0, [eax+4]=dr1, [eax+8]=dr2, [eax+C]=dr3
        ; [eax+10]=dr7
        cmp     esi, OS_BASE
        jae     .errret
        cmp     dl, 3
        ja      .errret
        mov     ecx, dr7
        ; fix me
        xchg    ecx, edx
        shr     edx, cl
        shr     edx, cl
        xchg    ecx, edx

        test    ecx, 2 ; bit 1+2*index = G0..G3, global break enable
        jnz     .errret2
        test    dh, dh
        jns     .new
        ; clear breakpoint
        movzx   edx, dl
        add     edx, edx
        and     dword[eax + edx * 2], 0 ; clear DR<i>
        btr     [eax + 0x10], edx ; clear L<i> bit
        test    byte[eax + 0x10], 0x55
        jnz     .okret
;       imul    eax, ebp, tss_step/32
;       and     byte[eax + tss_data + tss_t._trap], not 1
        and     [SLOT_BASE + ebp * 8 + app_data_t.dbg_state], not 1

  .okret:
        and     [esp + 4 + regs_context32_t.eax], 0
        sti
        ret

  .errret:
        sti
        mov     [esp + 4 + regs_context32_t.eax], 1
        ret

  .errret2:
        sti
        mov     [esp + 4 + regs_context32_t.eax], 2
        ret

  .new:
        ; add new breakpoint
        ; dl=index; dh=flags; esi=address
        test    dh, 0xf0
        jnz     .errret
        mov     cl, dh
        and     cl, 3
        cmp     cl, 2
        jz      .errret
        mov     cl, dh
        shr     cl, 2
        cmp     cl, 2
        jz      .errret

        mov     ebx, esi
        test    bl, dl

        jnz     .errret
        or      byte[eax + 0x10 + 1], 3 ; set GE and LE flags

        movzx   edx, dh
        movzx   ecx, dl
        add     ecx, ecx
        bts     [eax + 0x10], ecx ; set L<i> flag
        add     ecx, ecx
        mov     [eax + ecx], ebx ; esi; set DR<i>
        shl     edx, cl
        mov     ebx, 0x0f
        shl     ebx, cl
        not     ebx
        and     [eax + 0x10 + 2], bx
        or      [eax + 0x10 + 2], dx ; set R/W and LEN fields
;       imul    eax, ebp, tss_step / 32
;       or      byte[eax + tss_data + tss_t._trap], 1
        or      [SLOT_BASE + ebp * 8 + app_data_t.dbg_state], 1
        jmp     .okret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.read_process_memory ;/////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.6
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;> edx = length
;> edi = pointer to buffer in debugger
;> esi = address in debuggee
;-----------------------------------------------------------------------------------------------------------------------
;< [esp + 4 + regs_context32_t.eax] = sizeof(read)
;-----------------------------------------------------------------------------------------------------------------------
;# destroys all
;-----------------------------------------------------------------------------------------------------------------------
;       push    ebx
;       mov     ebx, esi
        call    check_region
;       pop     ebx
        dec     eax
        jnz     .err
        call    get_debuggee_slot
        jc      .err
        shr     eax, 5
        mov     ecx, edi
        call    read_process_memory
        sti
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret

  .err:
        or      [esp + 4 + regs_context32_t.eax], -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.debug_ctl.write_process_memory ;////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? System function 69.7
;-----------------------------------------------------------------------------------------------------------------------
;> ecx = PID
;> edx = length
;> edi = pointer to buffer in debugger
;> esi = address in debuggee
;-----------------------------------------------------------------------------------------------------------------------
;< [esp + 4 + regs_context32_t.eax] = sizeof(write)
;-----------------------------------------------------------------------------------------------------------------------
;# destroys all
;-----------------------------------------------------------------------------------------------------------------------
;       push    ebx
;       mov     ebx, esi
        call    check_region
;       pop     ebx
        dec     eax
        jnz     sysfn.debug_ctl.read_process_memory.err
        call    get_debuggee_slot
        jc      sysfn.debug_ctl.read_process_memory.err
        shr     eax, 5
        mov     ecx, edi
        call    write_process_memory
        sti
        mov     [esp + 4 + regs_context32_t.eax], eax
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc debugger_notify ;/////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;> eax = debugger slot
;> ecx = size of debug message
;> [esp + 4] .. [esp + 4 + ecx] = message
;-----------------------------------------------------------------------------------------------------------------------
;# interrupts must be disabled!
;# destroys all general registers
;# interrupts remain disabled
;-----------------------------------------------------------------------------------------------------------------------
        xchg    ebp, eax
        mov     edi, [timer_ticks]
        add     edi, 500 ; 5 sec timeout

  .1:
        mov     eax, ebp
        shl     eax, 8
        mov     esi, [SLOT_BASE + eax + app_data_t.dbg_event_mem]
        test    esi, esi
        jz      .ret
        ; read buffer header
        push    ecx
        push    eax
        push    eax
        mov     eax, ebp
        mov     ecx, esp
        mov     edx, 8
        call    read_process_memory
        cmp     eax, edx
        jz      @f
        add     esp, 12
        jmp     .ret

    @@: cmp     dword[ecx], 0
        jg      @f

  .2:
        pop     ecx
        pop     ecx
        pop     ecx
        cmp     [CURRENT_TASK], 1
        jnz     .notos
        cmp     [timer_ticks], edi
        jae     .ret

  .notos:
        sti
        call    change_task
        cli
        jmp     .1

    @@: mov     edx, [ecx + 8]
        add     edx, [ecx + 4]
        cmp     edx, [ecx]
        ja      .2
        ; advance buffer position
        push    edx
        mov     edx, 4
        sub     ecx, edx
        mov     eax, ebp
        add     esi, edx
        call    write_process_memory
        pop     eax
        ; write message
        mov     eax, ebp
        add     esi, edx
        add     esi, [ecx + 8]
        add     ecx, 20
        pop     edx
        pop     edx
        pop     edx
        call    write_process_memory
        ; new debug event
        mov     eax, ebp
        shl     eax, 8
        or      byte[SLOT_BASE + eax + app_data_t.event_mask + 1], 1 ; set flag 0x100

  .ret:
        ret
kendp
