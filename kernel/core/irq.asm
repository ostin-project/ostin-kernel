;;======================================================================================================================
;;///// irq.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2006-2011 KolibriOS team <http://kolibrios.org/>
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
;? IRQ handling functions
;;======================================================================================================================

IRQ_RESERVED  = 24
IRQ_POOL_SIZE = 48

uglobal
  align 16
  irqh_tab:      rb sizeof.linked_list_t * IRQ_RESERVED

  irqh_pool:     rb sizeof.irq_handler_t * IRQ_POOL_SIZE
  next_irqh      dd ?

  irq_active_set dd ?
  irq_failed     rd IRQ_RESERVED
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc init_irqs ;///////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     ecx, IRQ_RESERVED
        mov     edi, irqh_tab

    @@: mov     eax, edi
        stosd
        stosd
        loop    @b

        mov     ecx, IRQ_POOL_SIZE - 1
        mov     eax, irqh_pool + sizeof.irq_handler_t
        mov     [next_irqh], irqh_pool

    @@: mov     [eax - sizeof.irq_handler_t + irq_handler_t.next_ptr], eax
        add     eax, sizeof.irq_handler_t
        loop    @b

        mov     [eax - sizeof.irq_handler_t + irq_handler_t.next_ptr], 0
        ret
kendp

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc attach_int_handler stdcall, irq:dword, handler:dword, user_data:dword ;////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
locals
  irq_handler dd ?
endl
;-----------------------------------------------------------------------------------------------------------------------
        and     [irq_handler], 0

        push    ebx

        mov     ebx, [irq] ; irq num
        test    ebx, ebx
        jz      .err

        cmp     ebx, IRQ_RESERVED
        jae     .err

        mov     edx, [handler]
        test    edx, edx
        jz      .err

        pushfd
        cli

        ; allocate handler
        mov     ecx, [next_irqh]
        test    ecx, ecx
        jz      .fail

        mov     eax, [ecx + irq_handler_t.next_ptr]
        mov     [next_irqh], eax

        mov     [irq_handler], ecx

        mov     [irq_failed + ebx * 4], 0 ; clear counter

        mov     eax, [user_data]
        mov     [ecx + irq_handler_t.handler_ptr], edx
        mov     [ecx + irq_handler_t.user_data_ptr], eax

        lea     edx, [irqh_tab + ebx * sizeof.linked_list_t]
        ListAppend ecx, edx ; clobber eax

        stdcall enable_irq, ebx

  .fail:
        popfd

  .err:
        pop     ebx
        mov     eax, [irq_handler]
        ret
endp

if 0

;-----------------------------------------------------------------------------------------------------------------------
proc get_int_handler stdcall, irq:dword ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        mov     eax, [irq]
        cmp     eax, 15
        ja      .fail

        mov     eax, [irq_tab + eax * 4]
        ret

  .fail:
        xor     eax, eax
        ret
endp

end if ; 0

align 4
;-----------------------------------------------------------------------------------------------------------------------
proc detach_int_handler ;///////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ret
endp

;-----------------------------------------------------------------------------------------------------------------------
kproc irq_serv ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------

macro IrqServeHandler [num]
{
align 4
 .irq_#num:
        push    num
        jmp     .main
}

IrqServeHandler 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15
IrqServeHandler 16, 17, 18, 19, 20, 21, 22, 23

purge IrqServeHandler

align 16
  .main:
        SaveRing3Context

        mov     ebp, [esp + sizeof.regs_context32_t]
        mov     bx, app_data ; os_data
        mov     ds, bx
        mov     es, bx

        cmp     [v86_irqhooks + ebp * 8], 0
        jne     v86_irq

if KCONFIG_BLK_FLOPPY

        cmp     ebp, 6
        jne     @f

        push    ebp
        call    [blk.floppy.ctl.irq_func]
        pop     ebp

end if ; KCONFIG_BLK_FLOPPY

    @@: cmp     ebp, 14
        jne     @f

        push    ebp
        call    [irq14_func]
        pop     ebp

    @@: cmp     ebp, 15
        jne     @f

        push    ebp
        call    [irq15_func]
        pop     ebp

    @@: bts     [irq_active_set], ebp

        lea     esi, [irqh_tab + ebp * sizeof.linked_list_t] ; esi = list head
        mov     ebx, esi

  .next:
        mov     ebx, [ebx + irq_handler_t.next_ptr] ; ebx = irqh pointer
        cmp     ebx, esi
        je      .done
 
        push    ebx edi esi ; FIX THIS
 
        push    [ebx + irq_handler_t.user_data_ptr]
        call    [ebx + irq_handler_t.handler_ptr]
        add     esp, 4
 
        pop     esi edi ebx
 
        test    eax, eax
        jz      .next
 
        btr     [irq_active_set], ebp
        jmp     .next
 
  .done:
        btr     [irq_active_set], ebp
        jnc     .exit
 
        inc     [irq_failed + ebp * 4]

  .exit:
        mov     [check_idle_semaphore], 5

        mov     ecx, ebp
        call    irq_eoi

        RestoreRing3Context
        add     esp, 4
        iret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc irqD ;////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    eax
        xor     eax, eax
        out     0xf0, al
        mov     al, 0x20
        out     0xa0, al
        out     0x20, al
        pop     eax
        iret
kendp
