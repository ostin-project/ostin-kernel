;;======================================================================================================================
;;///// dev_hdcd.inc /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;******************************************************
; поиск приводов HDD и CD
; автор исходного текста Кулаков Владимир Геннадьевич.
; адаптация и доработка Mario79
;******************************************************

FindHDD:
        ;*                 ПОИСК HDD и CD                   *

        mov     [ChannelNumber], 1
        mov     [DiskNumber], 0
        call    .FindHDD_3
;       mov     ax, [Sector512 + 176]
;       mov     [DRIVE_DATA + 6], ax
;       mov     ax, [Sector512 + 126]
;       mov     [DRIVE_DATA + 8], ax
;       mov     ax, [Sector512 + 128]
;       mov     [DRIVE_DATA + 8], ax
        mov     [DiskNumber], 1
        call    .FindHDD_3
;       mov     al, [Sector512 + 176]
;       mov     [DRIVE_DATA + 7], al
        inc     [ChannelNumber]
        mov     [DiskNumber], 0
        call    .FindHDD_3
;       mov     al, [Sector512 + 176]
;       mov     [DRIVE_DATA + 8], al
        mov     [DiskNumber], 1
        call    .FindHDD_1
;       mov     al, [Sector512 + 176]
;       mov     [DRIVE_DATA + 9], al

        jmp     EndFindHDD

  .FindHDD_1:
        call    ReadHDD_ID
        cmp     [DevErrorCode], 0
        jne     .FindHDD_2
        cmp     word[Sector512 + 6], 16
        ja      .FindHDD_2
        cmp     word[Sector512 + 12], 255
        ja      .FindHDD_2
        inc     byte[DRIVE_DATA + 1]
        jmp     .FindHDD_2_2

  .FindHDD_2:
        call    DeviceReset
        cmp     [DevErrorCode], 0
        jne     .FindHDD_2_2
        call    ReadCD_ID
        cmp     [DevErrorCode], 0
        jne     .FindHDD_2_2
        inc     byte[DRIVE_DATA + 1]
        inc     byte[DRIVE_DATA + 1]

  .FindHDD_2_2:
        ret

  .FindHDD_3:
        call    .FindHDD_1
        shl     byte[DRIVE_DATA + 1], 2
        ret

uglobal
  SectorAddress dd ? ; Адрес считываемого сектора в режиме LBA
endg

ReadHDD_ID:
        ;*     ЧТЕНИЕ ИДЕНТИФИКАТОРА ЖЕСТКОГО ДИСКА      *
        ;* Входные параметры передаются через глобальные *
        ;* переменные:                                   *
        ;* ChannelNumber - номер канала (1 или 2);       *
        ;* DiskNumber - номер диска на канале (0 или 1). *
        ;* Идентификационный блок данных считывается     *
        ;* в массив Sector512.                           *

        ; Задать режим CHS
        mov     [ATAAddressMode], 0
        ; Послать команду идентификации устройства
        mov     [ATAFeatures], 0
        mov     [ATAHead], 0
        mov     [ATACommand], 0x0ec
        call    SendCommandToHDD
        cmp     [DevErrorCode], 0 ; проверить код ошибки
        jne     .End  ; закончить, сохранив код ошибки
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; адрес регистра состояни
        mov     ecx, 0x0ffff

  .WaitCompleet:
        ; Проверить время выполнения команды
        dec     ecx
;       cmp     ecx,0
        jz      .Error1 ; ошибка тайм-аута
        ; Проверить готовность
        in      al,dx
        test    al, 0x080 ; состояние сигнала BSY
        jnz     .WaitCompleet
        test    al, 1 ; состояние сигнала ERR
        jnz     .Error6
        test    al, 0x08 ; состояние сигнала DRQ
        jz      .WaitCompleet
        ; Принять блок данных от контроллера
;       mov     ax, ds
;       mov     es, ax
        mov     edi, Sector512 ; offset Sector512
        mov     dx, [ATABasePortAddr] ; регистр данных
        mov     cx, 256 ; число считываемых слов
        rep     insw ; принять блок данных
	ret

  .Error1:
        ; Записать код ошибки
        mov     [DevErrorCode], 1
	ret

  .Error6:
        mov     [DevErrorCode], 6

  .End:
        ret


iglobal
  StandardATABases dw 0x1f0, 0x170 ; Стандартные базовые адреса каналов 1 и 2
endg

uglobal
  ChannelNumber   dw ? ; Номер канала
  DiskNumber      db ? ; Номер диска
  ATABasePortAddr dw ? ; Базовый адрес группы портов контроллера ATA

  ; Параметры ATA-команды
  ATAFeatures     db ? ; особенности
  ATASectorCount  db ? ; количество обрабатываемых секторов
  ATASectorNumber db ? ; номер начального сектора
  ATACylinder     dw ? ; номер начального цилиндра
  ATAHead         db ? ; номер начальной головки
  ATAAddressMode  db ? ; режим адресации (0 - CHS, 1 - LBA)
  ATACommand      db ? ; код команды, подлежащей выполнению

  ; Код ошибки (0 - нет ошибок, 1 - превышен допустимый интервал ожидания, 2 - неверный код режима адресации,
  ; 3 - неверный номер канала, 4 - неверный номер диска, 5 - неверный номер головки, 6 - ошибка при выполнении команды)
  DevErrorCode    dd ?
endg

SendCommandToHDD:
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
        ;* возвращен код ошибки.                            *

        ; Проверить значение кода режима
        cmp     [ATAAddressMode], 1
        ja      .Err2
        ; Проверить корректность номера канала
        mov     bx, [ChannelNumber]
        cmp     bx, 1
        jb      .Err3
        cmp     bx, 2
        ja      .Err3
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
        ja      .Err4
        shl     al, 4
        or      al, 010100000b
        out     dx, al
        ; Ожидать, пока диск не будет готов
        inc     dx
        mov     ecx, 0x0fff
;       mov     eax, [timer_ticks]
;       mov     [TickCounter_1], eax

  .WaitHDReady:
        ; Проверить время ожидани
        dec     ecx
;       cmp     ecx, 0
        jz     .Err1
;       mov     eax, [timer_ticks]
;       sub     eax, [TickCounter_1]
;       cmp     eax, 300 ; ожидать 300 тиков
;       ja      .Err1 ; ошибка тайм-аута
        ; Прочитать регистр состояни
        in      al, dx
        ; Проверить состояние сигнала BSY
        test    al, 0x080
        jnz     .WaitHDReady
        ; Проверить состояние сигнала DRQ
        test    al, 0x08
        jnz     .WaitHDReady
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
        ja      .Err5
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
        mov     [DevErrorCode], 0
        ret

  .Err1:
        ; Записать код ошибки
        mov     [DevErrorCode], 1
        ret

  .Err2:
        mov     [DevErrorCode], 2
        ret

  .Err3:
        mov     [DevErrorCode], 3
        ret

  .Err4:
        mov     [DevErrorCode], 4
        ret

  .Err5:
        mov     [DevErrorCode], 5
        ; Завершение работы программы
        ret

ReadCD_ID:
        ;*     ЧТЕНИЕ ИДЕНТИФИКАТОРА УСТРОЙСТВА ATAPI    *
        ;* Входные параметры передаются через глобальные *
        ;* перменные:                                    *
        ;* ChannelNumber - номер канала;                 *
        ;* DiskNumber - номер диска на канале.           *
        ;* Идентификационный блок данных считывается     *
        ;* в массив Sector512.                           *

        ; Задать режим CHS
        mov     [ATAAddressMode], 0
        ; Послать команду идентификации устройства
        mov     [ATAFeatures], 0
        mov     [ATASectorCount], 0
        mov     [ATASectorNumber], 0
        mov     [ATACylinder], 0
        mov     [ATAHead], 0
        mov     [ATACommand], 0x0a1
        call    SendCommandToHDD
        cmp     [DevErrorCode], 0 ; проверить код ошибки
        jne     .End_1 ; закончить, сохранив код ошибки
        ; Ожидать готовность данных HDD
        mov     dx, [ATABasePortAddr]
        add     dx, 7 ; порт 1х7h
        mov  	ecx, 0x0ffff

  .WaitCompleet_1:
        ; Проверить врем
        dec  	ecx
;       cmp  	ecx, 0
        jz      .Error1_1 ; ошибка тайм-аута
        ; Проверить готовность
        in      al, dx
        test    al, 0x080 ; состояние сигнала BSY
        jnz     .WaitCompleet_1
        test    al, 1 ; состояние сигнала ERR
        jnz     .Error6_1
        test    al, 0x08 ; состояние сигнала DRQ
        jz      .WaitCompleet_1
        ; Принять блок данных от контроллера
;       mov     ax, ds
;       mov     es, ax
        mov     edi, Sector512  ; offset Sector512
        mov     dx, [ATABasePortAddr] ; порт 1x0h
        mov     cx, 256 ; число считываемых слов
        rep     insw
        ret

  .Error1_1:
        ; Записать код ошибки
        mov     [DevErrorCode],1
        ret

  .Error6_1:
        mov     [DevErrorCode],6

  .End_1:
        ret

;*************************************************
;*                СБРОС УСТРОЙСТВА               *
;* Входные параметры передаются через глобальные *
;* переменные:                                   *
;* ChannelNumber - номер канала (1 или 2);       *
;* DiskNumber - номер диска (0 или 1).           *
;*************************************************
DeviceReset:
        ; Проверить корректность номера канала
        mov     bx, [ChannelNumber]
        cmp     bx, 1
        jb      .Err3_2
        cmp     bx, 2
        ja      .Err3_2
        ; Установить базовый адрес
        dec     bx
        shl     bx, 1
        movzx   ebx, bx
        mov     dx, [ebx + StandardATABases]
        mov     [ATABasePortAddr], dx
        ; Выбрать нужный диск
        add     dx, 6 ; адрес регистра головок
        mov     al, [DiskNumber]
        cmp     al, 1 ; проверить номера диска
        ja      .Err4_2
        shl     al, 4
        or      al, 010100000b
        out     dx, al
        ; Послать команду "Сброс"
        mov     al, 0x08
        inc     dx ; регистр команд
        out     dx, al
        mov     ecx, 0x080000

  .WaitHDReady_1:
        ; Проверить время ожидани
        dec     ecx
;       cmp     ecx, 0
        je      .Err1_2 ;ошибка тайм-аута
        ; Прочитать регистр состояни
        in      al,dx
        ; Проверить состояние сигнала BSY
        test    al, 0x080
        jnz     .WaitHDReady_1
        ; Сбросить признак ошибки
        mov     [DevErrorCode], 0
        ret

  .Err1_2:
        ; Обработка ошибок
        mov     [DevErrorCode], 1
        ret

  .Err3_2:
        mov     [DevErrorCode], 3
        ret

  .Err4_2:
        mov     [DevErrorCode], 4
        ; Записать код ошибки
        ret

EndFindHDD:
