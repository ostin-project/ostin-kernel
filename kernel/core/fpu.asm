;;======================================================================================================================
;;///// fpu.asm //////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2009 KolibriOS team <http://kolibrios.org/>
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
init_fpu: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        clts
        fninit

        bt      [cpu_caps], CAPS_SSE
        jnc     .no_SSE

        mov     ebx, cr4
        mov     ecx, cr0
        or      ebx, CR4_OSFXSR + CR4_OSXMMEXPT
        mov     cr4, ebx

        and     ecx, not (CR0_MP + CR0_EM)
        or      ecx, CR0_NE
        mov     cr0, ecx

        mov     dword[esp - 4], SSE_INIT
        ldmxcsr [esp - 4]

        xorps   xmm0, xmm0
        xorps   xmm1, xmm1
        xorps   xmm2, xmm2
        xorps   xmm3, xmm3
        xorps   xmm4, xmm4
        xorps   xmm5, xmm5
        xorps   xmm6, xmm6
        xorps   xmm7, xmm7
        fxsave  [fpu_data] ; [eax]
        ret

  .no_SSE:
        mov     ecx, cr0
        and     ecx, not CR0_EM
        or      ecx, CR0_MP + CR0_NE
        mov     cr0, ecx
        fnsave  [fpu_data]
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
fpu_save: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; param
        ;  eax= 512 bytes memory area

        push    ecx
        push    esi
        push    edi

        pushfd
        cli

        clts
        mov     edi, eax

        mov     ecx, [fpu_owner]
        mov     esi, [CURRENT_TASK]
        cmp     ecx, esi
        jne     .save

        call    save_context
        jmp     .exit

  .save:
        mov     [fpu_owner], esi

        shl     ecx, 8
        mov     eax, [ecx + SLOT_BASE + app_data_t.fpu_state]

        call    save_context

        shl     esi, 8
        mov     esi, [esi + SLOT_BASE + app_data_t.fpu_state]
        mov     ecx, 512 / 4
        cld
        rep     movsd
        fninit

  .exit:
        popfd
        pop     edi
        pop     esi
        pop     ecx
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
save_context: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        bt      [cpu_caps], CAPS_SSE
        jnc     .no_SSE

        fxsave  [eax]
        ret

  .no_SSE:
        fnsave  [eax]
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
fpu_restore: ;//////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        push    esi

        mov     esi, eax

        pushfd
        cli

        mov     ecx, [fpu_owner]
        mov     eax, [CURRENT_TASK]
        cmp     ecx, eax
        jne     .copy

        clts
        bt      [cpu_caps], CAPS_SSE
        jnc     .no_SSE

        fxrstor [esi]
        popfd
        pop     esi
        pop     ecx
        ret

  .no_SSE:
        fnclex  ; fix possible problems
        frstor  [esi]
        popfd
        pop     esi
        pop     ecx
        ret

  .copy:
        shl     eax, 8
        mov     edi, [eax + SLOT_BASE + app_data_t.fpu_state]
        mov     ecx, 512 / 4
        cld
        rep     movsd
        popfd
        pop     esi
        pop     ecx
        ret

align 4
;-----------------------------------------------------------------------------------------------------------------------
except_7: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? #NM exception handler
;-----------------------------------------------------------------------------------------------------------------------
        save_ring3_context
        clts
        mov     ax, app_data
        mov     ds, ax
        mov     es, ax

        mov     ebx, [fpu_owner]
        cmp     ebx, [CURRENT_TASK]
        je      .exit

        shl     ebx, 8
        mov     eax, [ebx + SLOT_BASE + app_data_t.fpu_state]
        bt      [cpu_caps], CAPS_SSE
        jnc     .no_SSE

        fxsave  [eax]
        mov     ebx, [CURRENT_TASK]
        mov     [fpu_owner], ebx
        shl     ebx, 8
        mov     eax, [ebx + SLOT_BASE + app_data_t.fpu_state]
        fxrstor [eax]

  .exit:
        restore_ring3_context
        iret

  .no_SSE:
        fnsave  [eax]
        mov     ebx, [CURRENT_TASK]
        mov     [fpu_owner], ebx
        shl     ebx, 8
        mov     eax, [ebx + SLOT_BASE + app_data_t.fpu_state]
        frstor  [eax]
        restore_ring3_context
        iret

iglobal
  fpu_owner dd 0
endg
