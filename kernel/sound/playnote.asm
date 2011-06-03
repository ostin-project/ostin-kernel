;;======================================================================================================================
;;///// playnote.asm /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2010 KolibriOS team <http://kolibrios.org/>
;; (c) 2000-2004 MenuetOS <http://menuetos.net/>
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

align 4
;-----------------------------------------------------------------------------------------------------------------------
sound_interface: ;//////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        cmp     eax, ebx ; this is subfunction #55 ?
        jne     .retFunc55 ; if no then return.

        cmp     byte[sound_flag], 0
        jne     .retFunc55

        movzx   eax, byte[countDelayNote]
        or      al, al ; player is busy ?
        jnz     .retFunc55 ; return counter delay Note

        mov     [memAdrNote], esi ; edx
        call    get_pid
        mov     [pidProcessNote], eax
        xor     eax, eax ; Ok!  EAX = 0

  .retFunc55:
        mov     [esp + 32], eax ; return value EAX for application
        ret

iglobal
  align 4
  kontrOctave      dw 0x4742, 0x4342, 0x3f7c, 0x3bec, 0x388f, 0x3562
                   dw 0x3264, 0x2f8f, 0x2ce4, 0x2a5f, 0x2802, 0x25bf
  memAdrNote       dd 0
  pidProcessNote   dd 0
  slotProcessNote  dd 0
  count_timer_Note dd 1
  mem8253r42       dw 0
  countDelayNote   db 0
endg

;-----------------------------------------------------------------------------------------------------------------------
playNote: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
;       jmp     NotPlayNotes
        mov     esi, [memAdrNote]
        or      esi, esi ; ESI = 0 ?  - OFF Notes Play ?
        jz      .NotPlayNotes ; if ESI = 0   -> ignore play pocedure
        cmp     eax, [count_timer_Note]
        jb      .NotPlayNotes
        push    eax
        inc     eax
        mov     [count_timer_Note], eax
        mov     al, [countDelayNote]
        dec     al ; decrement counter Delay for Playing Note
        jz      .NewLoadNote@Delay
        cmp     al, 0xff ; this is first Note Play ?
        jne     .NextDelayNote
        ; This is FIRST Note, save counter channel 2 chip 8253
        mov     al, 0xb6 ; control byte to timer chip 8253
        out     0x43, al ; Send it to the control port chip 8253
        in      al, 0x42 ; Read Lower byte counter channel 2 chip 8253
        mov     ah, al ; AH = Lower byte counter channel 2
        in      al, 0x42 ; Read Upper byte counter channel 2 chip 8253
        mov     [mem8253r42], ax ; Save counter channel 2 timer chip 8253

  .NewLoadNote@Delay:
        cld
;       lodsb   ; load AL - counter Delay
        call    ReadNoteByte
        or      al, al ; THE END ?
        jz      .EndPlayNote
        cmp     al, 0x81
        jnc     .NoteforOctave
        mov     [countDelayNote], al
;       lodsw   ; load AX - counter for Note!
        call    ReadNoteByte
        mov     ah, al
        call    ReadNoteByte
        xchg    al, ah
        jmp     .pokeNote

  .EndPlayNote: ; THE END Play Notes!
        in      al, 0x61 ; Get contents of system port B chip 8255
        and     al, 0xfc ; Turn OFF timer and speaker
        out     0x61, al ; Send out new values to port B chip 8255
        mov     ax, [mem8253r42] ; memorize counter channel 2 timer chip 8253
        xchg    al, ah ; reverse byte in word
        out     0x42, al ; restore Lower byte counter channel 2
        mov     al, ah ; AL = Upper byte counter channel 2
        out     0x42, al ; restore Upper byte channel 2
        xor     eax, eax ; EAX = 0
        mov     [memAdrNote], eax ; clear header control Delay-Note string

  .NextDelayNote:
        mov     [countDelayNote], al ; save new counter delay Note
        pop     eax

  .NotPlayNotes:
        ret

  .NoteforOctave:
        sub     al, 0x81 ; correction value for delay Note
        mov     [countDelayNote], al ; save counter delay this new Note
;       lodsb   ; load pack control code
        call    ReadNoteByte
        cmp     al, 0x0ff ; this is PAUSE ?
        jne     .packCode ; no, this is PACK CODE
        in      al, 0x61 ; Get contents of system port B chip 8255
        and     al, 0xfc ; Turn OFF timer and speaker
        out     0x61, al ; Send out new values to port B chip 8255
        jmp     .saveESI

  .packCode:
        mov     cl, al ; save code
        and     al, 0x0f ; clear upper bits
        dec     al ; correction
        add     al, al ; transform number to offset constant
        movsx   eax, al ; EAX - offset
        add     eax, kontrOctave ; EAX - address from constant
        mov     ax, [eax] ; read constant
        shr     cl, 4 ; transform for number Octave
        shr     ax, cl ; calculate from Note this Octave!

  .pokeNote:
        out     0x42, al ; Lower byte Out to channel 2 timer chip 8253
        mov     al, ah
        out     0x42, al ; Upper byte Out to channel 2 timer chip 8253
        in      al, 0x61 ; Get contents of system port B chip 8255
        or      al, 3 ; Turn ON timer and speaker
        out     0x61, al ; Send out new values to port B chip 8255

  .saveESI:
;       mov     [memAdrNote], esi ; save new header control Delay-Note string
        pop     eax
        ret

;-----------------------------------------------------------------------------------------------------------------------
ReadNoteByte: ;/////////////////////////////////////////////////////////////////////////////////////////////////////////
;-----------------------------------------------------------------------------------------------------------------------
        ; result:
        ;  al - note

        push    eax
        push    ecx
        push    edx
        push    esi

        mov     eax, [pidProcessNote]
        call    pid_to_slot
        test    eax, eax
        jz      .failed
        lea     ecx, [esp + 12]
        mov     edx, 1
        mov     esi, [memAdrNote]
        inc     [memAdrNote]

        call    read_process_memory

  .failed:
        pop     esi
        pop     edx
        pop     ecx
        pop     eax
        ret
