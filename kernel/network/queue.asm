;;======================================================================================================================
;;///// queue.asm ////////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2004-2008 KolibriOS team <http://kolibrios.org/>
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

;*******************************************************************
; The various defines for queue names can be found in stack.inc
;*******************************************************************


;uglobal
;  freeBuff_cnt dd ?
;endg
freeBuff:
        ; Description
        ;   buffer number in eax  ( ms word zeroed )
        ;   all other registers preserved
        ; This always works, so no error returned

;       inc     [freeBuff_cnt]
;       DEBUGF  1, "K : freeBuff (%u)\n", [freeBuff_cnt]
        push    ebx
        push    ecx
        mov     ebx, queues + EMPTY_QUEUE * 2
        cli     ; Ensure that another process does not interfer
        mov     cx, [ebx]
        mov     [ebx], ax
        mov     [queueList + eax * 2], cx
        sti
        pop     ecx
        pop     ebx

        ret

queueSize:
        ; Description
        ;   Counts the number of entries in a queue
        ;   queue number in ebx ( ms word zeroed )
        ;   Queue size returned in eax
        ; This always works, so no error returned

        xor     eax, eax
        shl     ebx, 1
        add     ebx, queues
        movzx   ecx, word[ebx]
        cmp     cx, NO_BUFFER
        je      .qs_exit

  .qs_001:
        inc     eax
        shl     ecx, 1
        add     ecx, queueList
        movzx   ecx, word[ecx]
        cmp     cx, NO_BUFFER
        je      .qs_exit
        jmp     .qs_001

  .qs_exit:
    ret

;uglobal
;  queue_cnt dd ?
;endg
queue:
        ; Description
        ;   Adds a buffer number to the *end* of a queue
        ;   This is quite quick because these queues will be short
        ;   queue number in eax ( ms word zeroed )
        ;   buffer number in ebx  ( ms word zeroed )
        ;   all other registers preserved
        ; This always works, so no error returned

;       inc     [queue_cnt]
;       DEBUGF  1, "K : queue (%u)\n", [queue_cnt]
        push    ebx
        shl     ebx, 1
        add     ebx, queueList ; eax now holds address of queue entry
        mov     word[ebx], NO_BUFFER ; This buffer will be the last

        cli
        shl     eax, 1
        add     eax, queues ; eax now holds address of queue
        movzx   ebx, word[eax]

        cmp     bx, NO_BUFFER
        jne     .qu_001

        pop     ebx
        ; The list is empty, so add this to the head
        mov     [eax], bx
        jmp     .qu_exit

  .qu_001:
        ; Find the last entry
        shl     ebx, 1
        add     ebx, queueList
        mov     eax, ebx
        movzx   ebx, word[ebx]
        cmp     bx, NO_BUFFER
        jne     .qu_001

        mov     ebx, eax
        pop     eax
        mov     [ebx], ax

  .qu_exit:
        sti
        ret


;uglobal
;  dequeue_cnt dd ?
;endg
dequeue:
        ; Description
        ;   removes a buffer number from the head of a queue
        ;   This is fast, as it unlinks the first entry in the list
        ;   queue number in eax ( ms word zeroed )
        ;   buffer number returned in eax ( ms word zeroed )
        ;   all other registers preserved

        push    ebx
        shl     eax, 1
        add     eax, queues ; eax now holds address of queue
        mov     ebx, eax
        cli
        movzx   eax, word[eax]
        cmp     ax, NO_BUFFER
        je      .dq_exit
;       inc     [dequeue_cnt]
;       DEBUGF  1, "K : dequeue (%u)\n", [dequeue_cnt]
        push    eax
        shl     eax, 1
        add     eax, queueList ; eax now holds address of queue entry
        mov     ax, [eax]
        mov     [ebx], ax
        pop     eax

  .dq_exit:
        sti
        pop     ebx
        ret

queueInit:
        ; Description
        ;   Initialises the queues to empty, and creates the free queue
        ;   list.

        mov     esi, queues
        mov     ecx, NUMQUEUES
        mov     ax, NO_BUFFER

  .qi001:
        mov     [esi], ax
        inc     esi
        inc     esi
        loop    .qi001

        mov     esi, queues + (2 * EMPTY_QUEUE)

        ; Initialise empty queue list

        xor     ax, ax
        mov     [esi], ax

        mov     ecx, NUMQUEUEENTRIES - 1
        mov     esi, queueList

  .qi002:
        inc     ax
        mov     [esi], ax
        inc     esi
        inc     esi
        loop    .qi002

        mov     ax, NO_BUFFER
        mov     [esi], ax

        ret
