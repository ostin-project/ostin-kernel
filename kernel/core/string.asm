;;======================================================================================================================
;;///// string.asm ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2007 KolibriOS team <http://kolibrios.org/>
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
;; References:
;; * http://code.google.com/p/minix-ipc/source/browse/trunk/lib/i386/string/
;;======================================================================================================================

; size_t strncat(char *s1, const char *s2, size_t n)
; Append string s2 to s1.
proc strncat stdcall, s1:dword, s2:dword, n:dword
        push    esi
        push    edi
        mov     edi, [s1] ; String s1
        mov     edx, [n] ; Maximum length

        mov     ecx, -1
        xor     al, al ; Null byte
        cld
        repne   scasb ; Look for the zero byte in s1
        dec     edi ; Back one up (and clear 'Z' flag)
        push    edi ; Save end of s1
        mov     edi, [s2] ; edi = string s2
        mov     ecx, edx ; Maximum count
        repne   scasb ; Look for the end of s2
        jne     @f
        inc     ecx ; Exclude null byte

    @@: sub     edx, ecx ; Number of bytes in s2
        mov     ecx, edx
        mov     esi, [s2] ; esi = string s2
        pop     edi ; edi = end of string s1
        rep     movsb ; Copy bytes
        stosb   ; Add a terminating null
        mov     eax, [s1] ; Return s1
        pop     edi
        pop     esi
        ret
endp

; int strncmp(const char *s1, const char *s2, size_t n)
; Compare two strings.
align 4
proc strncmp stdcall, s1:dword, s2:dword, n:dword
        push    esi
        push    edi
        mov     ecx, [n]
        test    ecx, ecx ; Max length is zero?
        je      .done

        mov     esi, [s1] ; esi = string s1
        mov     edi, [s2] ; edi = string s2
        cld

  .compare:
        cmpsb   ; Compare two bytes
        jne     .done
        cmp     byte[esi - 1], 0 ; End of string?
        je      .done
        dec     ecx ; Length limit reached?
        jne     .compare

  .done:
        seta    al ; al = (s1 > s2)
        setb    ah ; ah = (s1 < s2)
        sub     al, ah
        movsx   eax, al ; eax = (s1 > s2) - (s1 < s2), i.e. -1, 0, 1
        pop     edi
        pop     esi
        ret
endp

; char *strncpy(char *s1, const char *s2, size_t n)
; Copy string s2 to s1.
align 4
proc strncpy stdcall, s1:dword, s2:dword, n:dword
        push    esi
        push    edi

        mov     ecx, [n] ; Maximum length
        mov     edi, [s2] ; edi = string s2
        xor     al, al ; Look for a zero byte
        mov     edx, ecx ; Save maximum count
        cld
        repne   scasb ; Look for end of s2
        sub     edx, ecx ; Number of bytes in s2 including null
        xchg    ecx, edx
        mov     esi, [s2] ; esi = string s2
        mov     edi, [s1] ; edi = string s1
        rep     movsb ; Copy bytes

        mov     ecx, edx ; Number of bytes not copied
        rep     stosb ; strncpy always copies n bytes by null padding
        mov     eax, [s1] ; Return s1
        pop     edi
        pop     esi
        ret
endp

; size_t strnlen(const char *s, size_t n)
; Return the length of a string.
align 4
proc strnlen stdcall, s:dword, n:dword
        push    edi
        mov     edi, [s] ; edi = string
        xor     al, al ; Look for a zero byte
        mov     edx, ecx ; Save maximum count
        cmp     cl, 1 ; 'Z' bit must be clear if ecx = 0
        cld
        repne   scasb ; Look for zero
        jne     @f
        inc     ecx ; Don't count zero byte

    @@: mov     eax, edx
        sub     eax, ecx ; Compute bytes scanned
        pop     edi
        ret
endp

; char *strchr(const char *s, int c)
align 4
proc strchr stdcall, s:dword, c:dword
        push    edi
        cld
        mov     edi, [s] ; edi = string
        mov     edx, 16 ; Look at small chunks of the string

  .next:
        shl     edx, 1 ; Chunks become bigger each time
        mov     ecx, edx
        xor     al, al ; Look for the zero at the end
        repne   scasb
        pushf   ; Remember the flags
        sub     ecx, edx
        neg     ecx ; Some or all of the chunk
        sub     edi, ecx ; Step back
        mov     eax, [c] ; The character to look for
        repne   scasb
        je      .found
        popf    ; Did we find the end of string earlier?
        jne     .next ; No, try again
        xor     eax, eax ; Return NULL
        pop     edi
        ret

  .found:
        pop     eax ; Get rid of those flags
        lea     eax, [edi - 1] ; Address of byte found
        pop     edi
        ret
endp

; proc strrchr stdcall, s:dword, c:dword
; Look for the last occurrence a character in a string.
proc strrchr stdcall, s:dword, c:dword
        push    edi
        mov     edi, [s] ; edi = string
        mov     ecx, -1
        xor     al, al
        cld
        repne   scasb ; Look for the end of the string
        not     ecx ; -1 - ecx = Length of the string + null
        dec     edi ; Put edi back on the zero byte
        mov     eax, [c] ; The character to look for
        std     ; Downwards search
        repne   scasb
        cld     ; Direction bit back to default
        jne     .fail
        lea     eax, [edi + 1] ; Found it
        pop     edi
        ret
.fail:
        xor     eax, eax ; Not there
        pop     edi
        ret
endp
