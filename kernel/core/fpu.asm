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
kproc init_fpu ;////////////////////////////////////////////////////////////////////////////////////////////////////////
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
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fpu_save ;////////////////////////////////////////////////////////////////////////////////////////////////////////
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
        mov     esi, [current_slot]
        cmp     ecx, esi
        jne     .save

        call    save_context
        jmp     .exit

  .save:
        mov     [fpu_owner], esi

        shl     ecx, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + ecx + legacy.slot_t.app.fpu_state]

        call    save_context

        shl     esi, 9 ; * sizeof.legacy.slot_t
        mov     esi, [legacy_slots + esi + legacy.slot_t.app.fpu_state]
        mov     ecx, 512 / 4
        rep
        movsd
        fninit

  .exit:
        popfd
        pop     edi
        pop     esi
        pop     ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc save_context ;////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        bt      [cpu_caps], CAPS_SSE
        jnc     .no_SSE

        fxsave  [eax]
        ret

  .no_SSE:
        fnsave  [eax]
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc fpu_restore ;/////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        push    ecx
        push    esi

        mov     esi, eax

        pushfd
        cli

        mov     ecx, [fpu_owner]
        mov     eax, [current_slot]
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
        shl     eax, 9 ; * sizeof.legacy.slot_t
        mov     edi, [legacy_slots + eax + legacy.slot_t.app.fpu_state]
        mov     ecx, 512 / 4
        rep
        movsd
        popfd
        pop     esi
        pop     ecx
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc except_7 ;////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? #NM exception handler
;-----------------------------------------------------------------------------------------------------------------------
        SaveRing3Context
        clts
        mov     ax, app_data
        mov     ds, ax
        mov     es, ax
        cld

        mov     ebx, [fpu_owner]
        cmp     ebx, [current_slot]
        je      .exit

        shl     ebx, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + ebx + legacy.slot_t.app.fpu_state]
        bt      [cpu_caps], CAPS_SSE
        jnc     .no_SSE

        fxsave  [eax]
        mov     ebx, [current_slot]
        mov     [fpu_owner], ebx
        shl     ebx, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + ebx + legacy.slot_t.app.fpu_state]
        fxrstor [eax]

  .exit:
        RestoreRing3Context
        iret

  .no_SSE:
        fnsave  [eax]
        mov     ebx, [current_slot]
        mov     [fpu_owner], ebx
        shl     ebx, 9 ; * sizeof.legacy.slot_t
        mov     eax, [legacy_slots + ebx + legacy.slot_t.app.fpu_state]
        frstor  [eax]
        RestoreRing3Context
        iret
kendp

iglobal
  fpu_owner dd 0
endg
