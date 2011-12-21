;;======================================================================================================================
;;///// syscall.asm //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

align 32
;-----------------------------------------------------------------------------------------------------------------------
kproc sysenter_entry ;//////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? SYSENTER ENTRY
;-----------------------------------------------------------------------------------------------------------------------
        ; setting up stack
        mov     esp, [ss:tss.esp0]
        sti
        push    ebp ; save app esp + 4
        mov     ebp, [ebp] ; ebp - original ebp
        ;------------------
        pushad
        cld

        movzx   eax, al
        call    [sysfn._.serve_table + eax * 4]

        popad
        ;------------------
        xchg    ecx, [ss:esp] ; on stack top - app ecx, ecx - app esp + 4
        sub     ecx, 4
        xchg    edx, [ecx] ; edx - return point, & save original edx
        push    edx
        mov     edx, [ss:esp + 4]
        mov     [ecx + 4], edx ; save original ecx
        pop     edx
        sysexit
kendp

align 16
;-----------------------------------------------------------------------------------------------------------------------
kproc i40 ;/////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? SYSTEM CALL ENTRY
;-----------------------------------------------------------------------------------------------------------------------
        pushad
        cld
        movzx   eax, al
        call    [sysfn._.serve_table + eax * 4]
        popad
        iretd
kendp

align 32
;-----------------------------------------------------------------------------------------------------------------------
kproc syscall_entry ;///////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? SYSCALL ENTRY
;-----------------------------------------------------------------------------------------------------------------------
;       cli     ; syscall clear IF
        xchg    esp, [ss:tss.esp0]
        push    ecx
        lea     ecx, [esp + 4]
        xchg    ecx, [ss:tss.esp0]
        sti
        push    ecx
        mov     ecx, [ecx]
        ;------------------
        pushad
        cld

        movzx   eax, al
        call    [sysfn._.serve_table + eax * 4]

        popad
        ;------------------
        mov     ecx, [ss:esp + 4]
        pop     esp
        sysret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.not_implemented ;///////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; TODO: kill offensive process
        klog_   LOG_ERROR, "unknown sysfn: %u:%u:%u\n", [esp + 4 + regs_context32_t.eax], \
                [esp + 4 + regs_context32_t.ebx], [esp + 4 + regs_context32_t.ecx]
        or      [esp + 4 + regs_context32_t.eax], -1
        ret
kendp

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn.not_implemented_cross_order ;///////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; TODO: kill offensive process
        klog_   LOG_ERROR, "unknown sysfn (xo): %u:%u:%u\n", [esp + 8 + regs_context32_t.eax], \
                [esp + 8 + regs_context32_t.ebx], [esp + 8 + regs_context32_t.ecx]
        or      [esp + 8 + regs_context32_t.eax], -1
        ret
kendp

iglobal
  align 4
  sysfn._.serve_table label dword
    dd sysfn.draw_window ; 0
    dd sysfn.set_pixel ; 1
    dd sysfn.get_key ; 2
    dd sysfn.get_time ; 3
    dd sysfn.draw_text ; 4
    dd sysfn.delay_hs ; 5
    dd sysfn.not_implemented ; 6
    dd sysfn.put_image ; 7
    dd sysfn.define_button ; 8
    dd sysfn.get_process_info ; 9
    dd sysfn.wait_for_event ; 10
    dd sysfn.check_for_event ; 11
    dd sysfn.set_draw_state ; 12
    dd sysfn.draw_rect ; 13
    dd sysfn.get_screen_size ; 14
    dd sysfn.set_background_ctl ; 15

if KCONFIG_BLK_FLOPPY

    dd sysfn.flush_floppy_cache ; 16

else

    dd sysfn.not_implemented

end if ; KCONFIG_BLK_FLOPPY

    dd sysfn.get_clicked_button_id ; 17
    dd sysfn.system_ctl ; 18
    dd sysfn.not_implemented ; 19
    dd sysfn.midi_ctl ; 20
    dd sysfn.set_config ; 21
    dd sysfn.dtc_ctl ; 22
    dd sysfn.wait_for_event_with_timeout ; 23
    dd sysfn.cd_audio_ctl ; 24
    dd sysfn.not_implemented ; 25
    dd sysfn.get_config ; 26
    dd sysfn.not_implemented ; 27
    dd sysfn.not_implemented ; 28
    dd sysfn.get_date ; 29
    dd sysfn.current_directory_ctl ; 30
    dd sysfn.not_implemented ; 31
    dd sysfn.not_implemented ; 32
    dd sysfn.not_implemented ; 33
    dd sysfn.not_implemented ; 34
    dd sysfn.get_pixel ; 35
    dd sysfn.grab_screen_area ; 36
    dd sysfn.mouse_ctl ; 37
    dd sysfn.draw_line ; 38
    dd sysfn.get_background_ctl ; 39
    dd sysfn.set_process_event_mask ; 40
    dd sysfn.get_irq_owner ; 41
    dd sysfn.get_irq_data ; 42
    dd sysfn.write_to_port ; 43
    dd sysfn.program_irq ; 44
    dd sysfn.reserve_irq ; 45
    dd sysfn.reserve_port_area ; 46
    dd sysfn.draw_number ; 47
    dd sysfn.display_settings_ctl ; 48
    dd sysfn.apm_ctl ; 49
    dd sysfn.set_window_shape ; 50
    dd sysfn.thread_ctl ; 51
    dd sysfn.get_network_driver_status ; 52
    dd sysfn._.cross_order ; 53
    dd sysfn.not_implemented ; 54
    dd sysfn.sound_ctl ; 55
    dd sysfn.not_implemented ; 56
    dd sysfn.pci_bios32_ctl ; 57
    dd sysfn._.cross_order ; 58
    dd sysfn.not_implemented ; 59
    dd sysfn.ipc_ctl ; 60
    dd sysfs.direct_screen_access ; 61
    dd sysfn.pci_ctl ; 62
    dd sysfn._.cross_order ; 63
    dd sysfn.resize_app_memory ; 64
    dd sysfn.put_image_with_palette ; 65
    dd sysfn.keyboard_ctl ; 66
    dd sysfn.move_window ; 67
    dd sysfn.system_service ; 68
    dd sysfn.debug_ctl ; 69
    dd sysfn.file_system_lfn ; 70
    dd sysfn.window_settings ; 71
    dd sysfn.send_window_message ; 72
    dd sysfn.blit_32 ; 73
    times 255 - ($ - sysfn._.serve_table) / 4 dd sysfn.not_implemented
    dd sysfn.exit_process ; -1 (255)

  align 4
  sysfn._.cross_order_serve_table label dword
    dd sysfn.socket ; 53
    dd 0
    dd 0
    dd 0
    dd 0
    dd 0
    dd 0
    dd 0
    dd 0
    dd 0
    dd sysfn.debug_board ; 63
endg

;-----------------------------------------------------------------------------------------------------------------------
kproc sysfn._.cross_order ;/////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;? Old style system call converter
;-----------------------------------------------------------------------------------------------------------------------
        ; load all registers in crossed order
        mov     eax, ebx
        mov     ebx, ecx
        mov     ecx, edx
        mov     edx, esi
        mov     esi, edi
        movzx   edi, [esp + 4 + regs_context32_t.al]
        call    [sysfn._.cross_order_serve_table + (edi - 53) * 4]
        ret
kendp
