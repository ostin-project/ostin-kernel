;;======================================================================================================================
;;///// cd_drv.inc ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;**********************************************************
;  Непосредственная работа с устройством СD (ATAPI)
;**********************************************************
; Автор части исходного текста Кулаков Владимир Геннадьевич
; Адаптация, доработка и разработка Mario79,<Lrz>

MaxRetr        equ 10       ; Максимальное количество повторений операции чтения
BSYWaitTime    equ 1000     ; Предельное время ожидания готовности к приему команды (в тиках)
NoTickWaitTime equ 0x0fffff
CDBlockSize    equ 2048

;********************************************
;*        ЧТЕНИЕ СЕКТОРА С ПОВТОРАМИ        *
;* Многократное повторение чтения при сбоях *
;********************************************
ReadCDWRetr:
;-----------------------------------------------------------
; input  : eax = block to read
;          ebx = destination
;-----------------------------------------------------------
        pushad
        mov     eax, [CDSectorAddress]
        mov     ebx, [CDDataBuf_pointer]
        call    cd_calculate_cache
        xor     edi, edi
        add     esi, 8
        inc     edi

  .hdreadcache:
;       cmp     dword[esi + 4],0 ; empty
;       je      .nohdcache
        cmp     [esi], eax ; correct sector
        je      .yeshdcache

  .nohdcache:
        add     esi, 8
        inc     edi
        dec     ecx
        jnz     .hdreadcache
        call    find_empty_slot_CD_cache       ; ret in edi

        push    edi
        push    eax
        call    cd_calculate_cache_2
        shl     edi, 11
        add     edi, eax
        mov     [CDDataBuf_pointer], edi
        pop     eax
        pop     edi

        call    ReadCDWRetr_1
        cmp     [DevErrorCode], 0
        jne     .exit

        mov     [CDDataBuf_pointer], ebx
        call    cd_calculate_cache_1
        lea     esi,[edi * 8 + esi]
        mov     [esi], eax ; sector number
;       mov     dword[esi + 4], 1 ; hd read - mark as same as in hd

  .yeshdcache:
        mov     esi, edi
        shl     esi, 11 ; 9
        push    eax
        call    cd_calculate_cache_2
        add     esi, eax
        pop     eax
        mov     edi, ebx ; [CDDataBuf_pointer]
        mov     ecx, 512 ; /4
        cld
        rep     movsd ; move data

  .exit:
        popad
        ret

ReadCDWRetr_1:
        pushad

        ; Цикл, пока команда не выполнена успешно или не
        ; исчерпано количество попыток
        mov     ecx, MaxRetr

  .NextRetr:
; Подать команду
;*************************************************
;*      ПОЛНОЕ ЧТЕНИЕ СЕКТОРА КОМПАКТ-ДИСКА      *
;* Считываются данные пользователя, информация   *
;* субканала и контрольная информация            *
;* Входные параметры передаются через глобальные *
;* перменные:                                    *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале;           *
;* CDSectorAddress - адрес считываемого сектора. *
;* Данные считывается в массив CDDataBuf.        *
;*************************************************
        push    ecx
;       pusha
        ; Задать размер сектора
;       mov     [CDBlockSize], 2048 ; 2352
        ; Очистить буфер пакетной команды
        call    clear_packet_buffer
        ; Сформировать пакетную команду для считывания сектора данных
        ; Задать код команды Read CD
        mov     byte[PacketCommand], 0x28  ; 0x0be
        ; Задать адрес сектора
        mov     ax, word[CDSectorAddress + 2]
        xchg    al, ah
        mov     word[PacketCommand + 2], ax
        mov     ax, word[CDSectorAddress]
        xchg    al, ah
        mov     word[PacketCommand + 4], ax
;       mov     eax, [CDSectorAddress]
;       mov     [PacketCommand + 2], eax
        ; Задать количество считываемых секторов
        mov     byte[PacketCommand + 8], 1
        ; Задать считывание данных в полном объеме
;       mov     byte[PacketCommand + 9], 0x0f8
        ; Подать команду
        call    SendPacketDatCommand
        pop     ecx
;       ret

;       cmp     [DevErrorCode], 0
        test    eax, eax
        jz      .End_4

        or      ecx, ecx ; for cd load
        jz      .End_4
        dec     ecx

        cmp     [timer_ticks_enable], 0
        jne     @f
        mov     eax, NoTickWaitTime

  .wait:
;       test    eax, eax
        dec     eax
        jz      .NextRetr
        jmp     .wait

    @@:
; Задержка на 2,5 секунды
;       mov     eax, [timer_ticks]
;       add     eax, 50 ; 250
;@@Wait:
;       call    change_task
;       cmp     eax, [timer_ticks]
;       ja      .Wait
        loop    .NextRetr

  .End_4:
        mov     dword [DevErrorCode],eax
        popad
        ret


; Универсальные процедуры, обеспечивающие выполнение пакетных команд в режиме PIO

; Максимально допустимое время ожидания реакции устройства на пакетную команду (в тиках)
MaxCDWaitTime equ 1000 ; 200 ; 10 секунд

uglobal
  PacketCommand     rb 12   ; Область памяти для формирования пакетной команды
; CDDataBuf         rb 4096 ; Область памяти для приема данных от дисковода
; CDBlockSize       dw ?    ; Размер принимаемого блока данных в байтах
  CDSectorAddress   dd ?    ; Адрес считываемого сектора данных
  TickCounter_1     dd ?    ; Время начала очередной операции с диском
  WURStartTime      dd ?    ; Время начала ожидания готовности устройства
  CDDataBuf_pointer dd ?    ; указатель буфера для считывания
endg

;****************************************************
;*    ПОСЛАТЬ УСТРОЙСТВУ ATAPI ПАКЕТНУЮ КОМАНДУ,    *
;* ПРЕДУСМАТРИВАЮЩУЮ ПЕРЕДАЧУ ОДНОГО СЕКТОРА ДАННЫХ *
;*     РАЗМЕРОМ 2048 БАЙТ ОТ УСТРОЙСТВА К ХОСТУ     *
;* Входные параметры передаются через глобальные    *
;* перменные:                                       *
;* ChannelNumber - номер канала;                    *
;* DiskNumber - номер диска на канале;              *
;* PacketCommand - 12-байтный командный пакет;      *
;* CDBlockSize - размер принимаемого блока данных.  *
; return eax DevErrorCode
;****************************************************
SendPacketDatCommand:
        xor     eax, eax
;       mov     [DevErrorCode], al
        ; Задать режим CHS
        mov     [ATAAddressMode], al
        ; Послать ATA-команду передачи пакетной команды
        mov     [ATAFeatures], al
        mov     [ATASectorCount], al
        mov     [ATASectorNumber], al
        ; Загрузить размер передаваемого блока
        mov     [ATAHead], al
;       mov     ax, [CDBlockSize]
        mov     [ATACylinder], CDBlockSize
        mov     [ATACommand], 0x0a0
        call    SendCommandToHDD_1
        test    eax, eax
;       cmp     [DevErrorCode], 0 ; проверить код ошибки
        jnz     .End_8 ; закончить, сохранив код ошибки

        ; Ожидание готовности дисковода к приему пакетной команды
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; порт 1х7h
        mov     ecx, NoTickWaitTime

  .WaitDevice0:
        cmp     [timer_ticks_enable], 0
        jne     @f
        dec     ecx
;       test    ecx, ecx
        jz      .Err1_1
        jmp     .test

    @@: call    change_task
        ; Проверить время выполнения команды
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, BSYWaitTime
        ja      .Err1_1 ; ошибка тайм-аута

  .test:
        ; Проверить готовность
        in      al, dx
        test    al, 0x080 ; состояние сигнала BSY
        jnz     .WaitDevice0
        test    al, 0x01 ; состояние сигнала ERR
        jnz     .Err6
        test    al, 0x08 ; состояние сигнала DRQ
        jz      .WaitDevice0

        ; Послать пакетную команду
        cli
        mov     dx, [ATABasePortAddr]
        mov     ax, word[PacketCommand]
        out     dx, ax
        mov     ax, word[PacketCommand + 2]
        out     dx, ax
        mov     ax, word[PacketCommand + 4]
        out     dx, ax
        mov     ax, word[PacketCommand + 6]
        out     dx, ax
        mov     ax, word[PacketCommand + 8]
        out     dx, ax
        mov     ax, word[PacketCommand + 10]
        out     dx, ax
        sti

        ; Ожидание готовности данных
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; порт 1х7h
        mov     ecx, NoTickWaitTime

  .WaitDevice1:
        cmp     [timer_ticks_enable], 0
        jne     @f
        dec     ecx
;       test    ecx, ecx
        jz      .Err1_1
        jmp     .test_1

    @@: call    change_task
        ; Проверить время выполнения команды
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, MaxCDWaitTime
        ja      .Err1_1 ; ошибка тайм-аута

  .test_1:
        ; Проверить готовность
        in      al, dx
        test    al, 0x080 ; состояние сигнала BSY
        jnz     .WaitDevice1
        test    al, 0x01 ; состояние сигнала ERR
        jnz     .Err6_temp
        test    al, 0x08 ; состояние сигнала DRQ
        jz      .WaitDevice1
        ; Принять блок данных от контроллера
        mov     edi, [CDDataBuf_pointer] ; 0x7000 ; CDDataBuf
        ; Загрузить адрес регистра данных контроллера
        mov     dx, [ATABasePortAddr] ; порт 1x0h
        ; Загрузить в счетчик размер блока в байтах
        xor     ecx, ecx
        mov     cx, CDBlockSize
        ; Вычислить размер блока в 16-разрядных словах
        shr     cx, 1 ; разделить размер блока на 2
        ; Принять блок данных
        cli
        cld
        rep     insw
        sti

  .End_8:
        ; Успешное завершение приема данных
        xor     eax, eax
        ret

  .Err1_1:
        ; Записать код ошибки
        xor     eax, eax
        inc     eax
        ret
;       mov     [DevErrorCode], 1
;       ret

  .Err6_temp:
        mov     eax, 7
        ret
;       mov     [DevErrorCode], 7
;       ret

  .Err6:
        mov     eax, 6
        ret
;       mov     [DevErrorCode], 6

; .End_8:
;       ret

;***********************************************
;*  ПОСЛАТЬ УСТРОЙСТВУ ATAPI ПАКЕТНУЮ КОМАНДУ, *
;*     НЕ ПРЕДУСМАТРИВАЮЩУЮ ПЕРЕДАЧИ ДАННЫХ    *
;* Входные параметры передаются через          *
;* глобальные перменные:                       *
;* ChannelNumber - номер канала;               *
;* DiskNumber - номер диска на канале;         *
;* PacketCommand - 12-байтный командный пакет. *
;***********************************************
SendPacketNoDatCommand:
        pushad
        xor     eax, eax
;       mov     [DevErrorCode], al
        ; Задать режим CHS
        mov     [ATAAddressMode],al
        ; Послать ATA-команду передачи пакетной команды
        mov     [ATAFeatures], al
        mov     [ATASectorCount], al
        mov     [ATASectorNumber], al
        mov     [ATACylinder], ax
        mov     [ATAHead], al
        mov     [ATACommand], 0x0a0
        call    SendCommandToHDD_1
;       cmp     [DevErrorCode], 0 ; проверить код ошибки
        test    eax, eax
        jnz     .End_9  ; закончить, сохранив код ошибки
        ; Ожидание готовности дисковода к приему пакетной команды
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; порт 1х7h

  .WaitDevice0_1:
        call    change_task
        ; Проверить время ожидания
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, BSYWaitTime
        ja      .Err1_3 ; ошибка тайм-аута
        ; Проверить готовность
        in      al, dx
        test    al, 0x080 ; состояние сигнала BSY
        jnz     .WaitDevice0_1
        test    al, 0x01 ; состояние сигнала ERR
        jnz     .Err6_1
        test    al, 0x08 ; состояние сигнала DRQ
        jz      .WaitDevice0_1

        ; Послать пакетную команду
;       cli
        mov     dx, [ATABasePortAddr]
        mov     ax, word[PacketCommand]
        out     dx, ax
        mov     ax, word[PacketCommand + 2]
        out     dx, ax
        mov     ax, word[PacketCommand + 4]
        out     dx, ax
        mov     ax, word[PacketCommand + 6]
        out     dx, ax
        mov     ax, word[PacketCommand + 8]
        out     dx, ax
        mov     ax, word[PacketCommand + 10]
        out     dx, ax
;       sti
        cmp     [ignore_CD_eject_wait], 1
        je      .clear_DEC
        ; Ожидание подтверждения приема команды
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; порт 1х7h

  .WaitDevice1_1:
        call    change_task
        ; Проверить время выполнения команды
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, MaxCDWaitTime
        ja      .Err1_3 ; ошибка тайм-аута
        ; Ожидать освобождения устройства
        in      al,dx
        test    al, 0x080 ; состояние сигнала BSY
        jnz     .WaitDevice1_1
        test    al, 0x01 ; состояние сигнала ERR
        jnz     .Err6_1
        test    al, 0x40 ; состояние сигнала DRDY
        jz      .WaitDevice1_1

  .clear_DEC:
        and     [DevErrorCode], 0
        popad
        ret

  .Err1_3:
        ; Записать код ошибки
        xor     eax, eax
        inc     eax
        jmp     .End_9

  .Err6_1:
        mov     eax, 6

  .End_9:
        mov     [DevErrorCode], eax
        popad
        ret

;****************************************************
;*          ПОСЛАТЬ КОМАНДУ ЗАДАННОМУ ДИСКУ         *
;* Входные параметры передаются через глобальные    *
;* переменные:                                      *
;* ChannelNumber - номер канала (1 или 2);          *
;* DiskNumber - номер диска (0 или 1);              *
;* ATAFeatures - "особенности";                     *
;* ATASectorCount - количество секторов;            *
;* ATASectorNumber - номер начального сектора;      *
;* ATACylinder - номер начального цилиндра;         *
;* ATAHead - номер начальной головки;               *
;* ATAAddressMode - режим адресации (0-CHS, 1-LBA); *
;* ATACommand - код команды.                        *
;* После успешного выполнения функции:              *
;* в ATABasePortAddr - базовый адрес HDD;           *
;* в DevErrorCode - ноль.                           *
;* При возникновении ошибки в DevErrorCode будет    *
;* возвращен код ошибки в eax                       *
;****************************************************
SendCommandToHDD_1:
;       pushad
;       mov     [DevErrorCode], 0 ; not need
        ; Проверить значение кода режима
        cmp     [ATAAddressMode], 1
        ja      .Err2_4
        ; Проверить корректность номера канала
        mov     bx, [ChannelNumber]
        cmp     bx, 1
        jb      .Err3_4
        cmp     bx, 2
        ja      .Err3_4
        ; Установить базовый адрес
        dec     bx
        shl     bx, 1
        movzx   ebx, bx
        mov     ax, [ebx + StandardATABases]
        mov     [ATABasePortAddr], ax
        ; Ожидание готовности HDD к приему команды
        ; Выбрать нужный диск
        mov     dx, [ATABasePortAddr]
        add     dx, 6 ; адрес регистра головок
        mov     al, [DiskNumber]
        cmp     al, 1 ; проверить номера диска
        ja      .Err4_4
        shl     al, 4
        or      al, 10100000b
        out     dx, al
        ; Ожидать, пока диск не будет готов
        inc     dx
        mov     eax, [timer_ticks]
        mov     [TickCounter_1], eax
        mov     ecx, NoTickWaitTime

  .WaitHDReady_2:
        cmp    [timer_ticks_enable], 0
        jne    @f
        dec    ecx
;       test   ecx, ecx
        jz     .Err1_4
        jmp    .test

    @@: call    change_task
        ; Проверить время ожидания
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter_1]
        cmp     eax, BSYWaitTime ; 300 ; ожидать 3 сек.
        ja      .Err1_4 ; ошибка тайм-аута
        ; Прочитать регистр состояния

  .test:
        in      al,dx
        ; Проверить состояние сигнала BSY
        test    al, 0x080
        jnz     .WaitHDReady_2
        ; Проверить состояние сигнала DRQ
        test    al, 0x08
        jnz     .WaitHDReady_2

        ; Загрузить команду в регистры контроллера
        cli
        mov     dx, [ATABasePortAddr]
        inc     dx ; регистр "особенностей"
        mov     al, [ATAFeatures]
        out     dx, al
        inc     dx ; счетчик секторов
        mov     al, [ATASectorCount]
        out     dx, al
        inc     dx ; регистр номера сектора
        mov     al, [ATASectorNumber]
        out     dx, al
        inc     dx ; номер цилиндра (младший байт)
        mov     ax, [ATACylinder]
        out     dx, al
        inc     dx ; номер цилиндра (старший байт)
        mov     al, ah
        out     dx, al
        inc     dx ; номер головки/номер диска
        mov     al, [DiskNumber]
        shl     al, 4
        cmp     [ATAHead], 0x0f ; проверить номер головки
        ja      .Err5_4
        or      al, [ATAHead]
        or      al, 010100000b
        mov     ah, [ATAAddressMode]
        shl     ah, 6
        or      al, ah
        out     dx, al
        ; Послать команду
        mov     al, [ATACommand]
        inc     dx ; регистр команд
        out     dx, al
        sti
        ; Сбросить признак ошибки
;       mov     [DevErrorCode], 0

  .End_10:
        xor     eax, eax
        ret

  .Err1_4:
        ; Записать код ошибки
        xor     eax, eax
        inc     eax
;       mov     [DevErrorCode], 1
        ret

  .Err2_4:
        mov     eax, 2
;       mov     [DevErrorCode], 2
        ret

  .Err3_4:
        mov     eax, 3
;       mov     [DevErrorCode], 3
        ret

  .Err4_4:
        mov     eax, 4
;       mov     [DevErrorCode], 4
        ret

  .Err5_4:
        mov     eax, 5
;       mov     [DevErrorCode], 5
        ; Завершение работы программы
        ret

;*************************************************
;*    ОЖИДАНИЕ ГОТОВНОСТИ УСТРОЙСТВА К РАБОТЕ    *
;* Входные параметры передаются через глобальные *
;* перменные:                                    *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
WaitUnitReady:
        pusha
        ; Запомнить время начала операции
        mov     eax, [timer_ticks]
        mov     [WURStartTime], eax
        ; Очистить буфер пакетной команды
        call    clear_packet_buffer
        ; Сформировать команду TEST UNIT READY
        mov     word[PacketCommand], 0
        ; ЦИКЛ ОЖИДАНИЯ ГОТОВНОСТИ УСТРОЙСТВА
        mov     ecx, NoTickWaitTime

  .SendCommand:
        ; Подать команду проверки готовности
        call    SendPacketNoDatCommand
        cmp     [timer_ticks_enable], 0
        jne     @f
        cmp     [DevErrorCode], 0
        je      .End_11
;       cmp     ecx, 0
        dec     ecx
        jz      .Error
        jmp     .SendCommand

    @@: call    change_task
        ; Проверить код ошибки
        cmp     [DevErrorCode], 0
        je      .End_11
        ; Проверить время ожидания готовности
        mov     eax,[timer_ticks]
        sub     eax,[WURStartTime]
        cmp     eax,MaxCDWaitTime
        jb      .SendCommand

  .Error:
        ; Ошибка тайм-аута
        mov     [DevErrorCode], 1

  .End_11:
        popa
        ret

;*************************************************
;*            ЗАПРЕТИТЬ СМЕНУ ДИСКА              *
;* Входные параметры передаются через глобальные *
;* перменные:                                    *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
prevent_medium_removal:
        pusha
        ; Очистить буфер пакетной команды
        call    clear_packet_buffer
        ; Задать код команды
        mov     [PacketCommand], 0x1e
        ; Задать код запрета
        mov     [PacketCommand + 4], 011b
        ; Подать команду
        call    SendPacketNoDatCommand
        mov     eax, ATAPI_IDE0_lock
        add     eax, [cdpos]
        dec     eax
        mov     byte[eax], 1
        popa
        ret

;*************************************************
;*            РАЗРЕШИТЬ СМЕНУ ДИСКА              *
;* Входные параметры передаются через глобальные *
;* перменные:                                    *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
allow_medium_removal:
        pusha
        ; Очистить буфер пакетной команды
        call    clear_packet_buffer
        ; Задать код команды
        mov     [PacketCommand], 0x1e
        ; Задать код запрета
        mov     [PacketCommand + 4], 0
        ; Подать команду
        call    SendPacketNoDatCommand
        mov     eax, ATAPI_IDE0_lock
        add     eax, [cdpos]
        dec     eax
        mov     byte[eax], 0
        popa
        ret

;*************************************************
;*         ЗАГРУЗИТЬ НОСИТЕЛЬ В ДИСКОВОД         *
;* Входные параметры передаются через глобальные *
;* перменные:                                    *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
LoadMedium:
        pusha
        ; Очистить буфер пакетной команды
        call    clear_packet_buffer
        ; Сформировать команду START/STOP UNIT
        ; Задать код команды
        mov     word[PacketCommand], 0x1b
        ; Задать операцию загрузки носителя
        mov     word[PacketCommand + 4], 00000011b
        ; Подать команду
        call    SendPacketNoDatCommand
        popa
        ret

;*************************************************
;*         ИЗВЛЕЧЬ НОСИТЕЛЬ ИЗ ДИСКОВОДА         *
;* Входные параметры передаются через глобальные *
;* перменные:                                    *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
EjectMedium:
        pusha
        ; Очистить буфер пакетной команды
        call    clear_packet_buffer
        ; Сформировать команду START/STOP UNIT
        ; Задать код команды
        mov     word[PacketCommand], 0x1b
        ; Задать операцию извлечения носителя
        mov     word[PacketCommand + 4], 00000010b
        ; Подать команду
        call    SendPacketNoDatCommand
        popa
        ret

;*************************************************
;* Проверить событие нажатия кнопки извлечения   *
;*                     диска                     *
;* Входные параметры передаются через глобальные *
;* переменные:                                   *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
align 4
check_ATAPI_device_event:
        pusha
        mov     eax, [timer_ticks]
        sub     eax, [timer_ATAPI_check]
        cmp     eax, 100
        jb      .end_1

        mov     al, [DRIVE_DATA + 1]
        and     al, 011b
        cmp     al, 010b
        jz      .ide3

  .ide2_1:
        mov     al, [DRIVE_DATA + 1]
        and     al, 01100b
        cmp     al, 01000b
        jz      .ide2

  .ide1_1:
        mov     al, [DRIVE_DATA + 1]
        and     al, 0110000b
        cmp     al, 0100000b
        jz      .ide1

  .ide0_1:
        mov     al, [DRIVE_DATA + 1]
        and     al, 011000000b
        cmp     al, 010000000b
        jz      .ide0

  .end:
        sti
        mov     eax, [timer_ticks]
        mov     [timer_ATAPI_check], eax

  .end_1:
        popa
        ret

  .ide3:
        cli
        cmp     [ATAPI_IDE3_lock], 1
        jne     .ide2_1
        cmp     [IDE_Channel_2], 0
        jne     .ide1_1
        cmp     [cd_status], 0
        jne     .end
        mov     [IDE_Channel_2], 1
        call    reserve_ok2
        mov     [ChannelNumber], 2
        mov     [DiskNumber], 1
        mov     [cdpos], 4
        call    GetEvent_StatusNotification
        cmp     byte[CDDataBuf + 4], 1
        je      .eject_ide3
        call    syscall_cdaudio.free
        jmp     .ide2_1

  .eject_ide3:
        call    .eject
        call    syscall_cdaudio.free
        jmp     .ide2_1

  .ide2:
        cli
        cmp     [ATAPI_IDE2_lock], 1
        jne     .ide1_1
        cmp     [IDE_Channel_2], 0
        jne     .ide1_1
        cmp     [cd_status], 0
        jne     .end
        mov     [IDE_Channel_2], 1
        call     reserve_ok2
        mov     [ChannelNumber], 2
        mov     [DiskNumber], 0
        mov     [cdpos], 3
        call    GetEvent_StatusNotification
        cmp     byte[CDDataBuf + 4], 1
        je      .eject_ide2
        call    syscall_cdaudio.free
        jmp     .ide1_1

  .eject_ide2:
        call    .eject
        call    syscall_cdaudio.free
        jmp     .ide1_1

  .ide1:
        cli
        cmp     [ATAPI_IDE1_lock], 1
        jne     .ide0_1
        cmp     [IDE_Channel_1], 0
        jne     .end
        cmp     [cd_status], 0
        jne     .end
        mov     [IDE_Channel_1], 1
        call    reserve_ok2
        mov     [ChannelNumber], 1
        mov     [DiskNumber], 1
        mov     [cdpos], 2
        call    GetEvent_StatusNotification
        cmp     byte[CDDataBuf + 4], 1
        je      .eject_ide1
        call    syscall_cdaudio.free
        jmp     .ide0_1

  .eject_ide1:
        call    .eject
        call    syscall_cdaudio.free
        jmp     .ide0_1

  .ide0:
        cli
        cmp     [ATAPI_IDE0_lock], 1
        jne     .end
        cmp     [IDE_Channel_1], 0
        jne     .end
        cmp     [cd_status], 0
        jne     .end
        mov     [IDE_Channel_1], 1
        call    reserve_ok2
        mov     [ChannelNumber], 1
        mov     [DiskNumber], 0
        mov     [cdpos], 1
        call    GetEvent_StatusNotification
        cmp     byte[CDDataBuf + 4], 1
        je      .eject_ide0
        call    syscall_cdaudio.free
        jmp     .end

  .eject_ide0:
        call    .eject
        call    syscall_cdaudio.free
        jmp     .end

  .eject:
        call    clear_CD_cache
        call    allow_medium_removal
        mov     [ignore_CD_eject_wait], 1
        call    EjectMedium
        mov     [ignore_CD_eject_wait], 0
        ret

uglobal
  timer_ATAPI_check    dd ?
  ATAPI_IDE0_lock      db ?
  ATAPI_IDE1_lock      db ?
  ATAPI_IDE2_lock      db ?
  ATAPI_IDE3_lock      db ?
  ignore_CD_eject_wait db ?
endg

;*************************************************
;* Получить сообщение о событии или состоянии    *
;*                  устройства                   *
;* Входные параметры передаются через глобальные *
;* переменные:                                   *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
GetEvent_StatusNotification:
        pusha
        mov     [CDDataBuf_pointer], CDDataBuf
        ; Очистить буфер пакетной команды
        call  clear_packet_buffer
        ; Задать код команды
        mov     [PacketCommand], 0x4a
        mov     [PacketCommand + 1], 00000001b
        ; Задать запрос класса сообщений
        mov     [PacketCommand + 4], 00010000b
        ; Размер выделенной области
        mov     [PacketCommand + 7], 8
        mov     [PacketCommand + 8], 0
        ; Подать команду
        call    SendPacketDatCommand
        popa
        ret

;*************************************************
; прочитать информацию из TOC
;* Входные параметры передаются через глобальные *
;* переменные:                                   *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
Read_TOC:
        pusha
        mov     [CDDataBuf_pointer], CDDataBuf
        ; Очистить буфер пакетной команды
        call    clear_packet_buffer
        ; Сформировать пакетную команду для считывания сектора данных
        mov     [PacketCommand], 0x43
        ; Задать формат
        mov     [PacketCommand + 2], 1
        ; Размер выделенной области
        mov     [PacketCommand + 7], 0x0ff
        mov     [PacketCommand + 8], 0
        ; Подать команду
        call    SendPacketDatCommand
        popa
        ret

;*************************************************
;* ОПРЕДЕЛИТЬ ОБЩЕЕ КОЛИЧЕСТВО СЕКТОРОВ НА ДИСКЕ *
;* Входные параметры передаются через глобальные *
;* переменные:                                   *
;* ChannelNumber - номер канала;                 *
;* DiskNumber - номер диска на канале.           *
;*************************************************
;ReadCapacity:
;       pusha
;       ; Очистить буфер пакетной команды
;       call    clear_packet_buffer
;       ; Задать размер буфера в байтах
;       mov     [CDBlockSize], 8
;       ; Сформировать команду READ CAPACITY
;       mov     word[PacketCommand], 0x25
;       ; Подать команду
;       call    SendPacketDatCommand
;       popa
;       ret

clear_packet_buffer:
        ; Очистить буфер пакетной команды
        and     dword[PacketCommand], 0
        and     dword[PacketCommand + 4], 0
        and     dword[PacketCommand + 8], 0
        ret
