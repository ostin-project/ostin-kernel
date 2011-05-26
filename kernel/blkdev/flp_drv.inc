;;======================================================================================================================
;;///// flp_drv.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

;**********************************************************
;  Непосредственная работа с контроллером гибкого диска
;**********************************************************
; Автор исходного текста  Кулаков Владимир Геннадьевич.
; Адаптация и доработка Mario79

;give_back_application_data: ; переслать приложению
;       mov     edi, [TASK_BASE]
;       mov     edi, [edi + TASKDATA.mem_start]
;       add     edi, ecx
give_back_application_data_1:
        mov     esi, FDD_BUFF ; FDD_DataBuffer ; 0x40000
        xor     ecx, ecx
        mov     cx, 128
        cld
        rep     movsd
        ret

;take_data_from_application:   ; взять из приложени
;       mov     esi, [TASK_BASE]
;       mov     esi, [esi + TASKDATA.mem_start]
;       add     esi, ecx
take_data_from_application_1:
        mov     edi, FDD_BUFF ; FDD_DataBuffer ; 0x40000
        xor     ecx, ecx
        mov     cx, 128
        cld
        rep     movsd
        ret

; Коды завершения операции с контроллером (FDC_Status)
FDC_Normal         equ 0 ; нормальное завершение
FDC_TimeOut        equ 1 ; ошибка тайм-аута
FDC_DiskNotFound   equ 2 ; в дисководе нет диска
FDC_TrackNotFound  equ 3 ; дорожка не найдена
FDC_SectorNotFound equ 4 ; сектор не найден

; Максимальные значения координат сектора (заданные
; значения соответствуют параметрам стандартного
; трехдюймового гибкого диска объемом 1,44 Мб)
MAX_Track   equ 79
MAX_Head    equ 1
MAX_Sector  equ 18

uglobal
  TickCounter      dd ?   ; Счетчик тиков таймера
  FDC_Status       db ?   ; Код завершения операции с контроллером НГМД
  FDD_IntFlag      db ?   ; Флаг прерывания от НГМД
  FDD_Time         dd ?   ; Момент начала последней операции с НГМД
  FDD_Type         db ?   ; Номер дисковода

  ; Координаты сектора
  FDD_Track        db ?
  FDD_Head         db ?
  FDD_Sector       db ?

  ; Блок результата операции
  FDC_ST0          db ?
  FDC_ST1          db ?
  FDC_ST2          db ?
  FDC_C            db ?
  FDC_H            db ?
  FDC_R            db ?
  FDC_N            db ?

  ReadRepCounter   db ?   ; Счетчик повторения операции чтени
  RecalRepCounter  db ?   ; Счетчик повторения операции рекалибровки
; FDD_DataBuffer   rb 512 ; Область памяти для хранения прочитанного сектора
  fdd_motor_status db ?
  timer_fdd_motor  dd ?
endg

;*************************************
;* ИНИЦИАЛИЗАЦИЯ РЕЖИМА ПДП ДЛЯ НГМД *
;*************************************
Init_FDC_DMA:
        pushad
        mov     al, 0
        out     0x0c, al ; reset the flip-flop to a known state.
        mov     al, 6 ; mask channel 2 so we can reprogram it.
        out     0x0a, al
        mov     al, [dmamode] ; 0x46 -> Read from floppy - 0x4a Write to floppy
        out     0x0b, al
        mov     al, 0
        out     0x0c, al ; reset the flip-flop to a known state.
        mov     eax, 0x0d000
        out     0x04, al ; set the channel 2 starting address to 0
        shr     eax, 8
        out     0x04, al
        shr     eax, 8
        out     0x81, al
        mov     al, 0
        out     0x0c, al ; reset flip-flop
        mov     al, 0xff ; set count (actual size -1)
        out     0x5, al
        mov     al, 0x1 ; [dmasize] ; (0x1ff = 511 / 0x23ff = 9215)
        out     0x5, al
        mov     al, 2
        out     0xa, al
        popad
        ret

;***********************************
;* ЗАПИСАТЬ БАЙТ В ПОРТ ДАННЫХ FDC *
;* Параметры:                      *
;* AL - выводимый байт.            *
;***********************************
FDCDataOutput:
;       pusha
        push    eax ecx edx
        mov     ah, al ; запомнить байт в AH
        ; Сбросить переменную состояния контроллера
        mov     [FDC_Status], FDC_Normal
        ; Проверить готовность контроллера к приему данных
        mov     dx, 0x3F4 ; (порт состояния FDC)
        mov     ecx, 0x10000 ; установить счетчик тайм-аута

  .TestRS:
        in      al, dx ; прочитать регистр RS
        and     al, 0x0c0 ; выделить разряды 6 и 7
        cmp     al, 0x080 ; проверить разряды 6 и 7
        je      .OutByteToFDC
        loop    .TestRS
        ; Ошибка тайм-аута
        mov     [FDC_Status], FDC_TimeOut
        jmp     .End_5

  .OutByteToFDC:
        ; Вывести байт в порт данных
        inc     dx
        mov     al, ah
        out     dx, al

  .End_5:
;       popa
        pop     edx ecx eax
        ret

;******************************************
;*   ПРОЧИТАТЬ БАЙТ ИЗ ПОРТА ДАННЫХ FDC   *
;* Процедура не имеет входных параметров. *
;* Выходные данные:                       *
;* AL - считанный байт.                   *
;******************************************
FDCDataInput:
        push    ecx
        push    dx
        ; Сбросить переменную состояния контроллера
        mov     [FDC_Status], FDC_Normal
        ; Проверить готовность контроллера к передаче данных
        mov     dx, 0x3f4 ; (порт состояния FDC)
        xor     cx, cx ; установить счетчик тайм-аута

  .TestRS_1:
        in      al, dx ; прочитать регистр RS
        and     al, 0x0c0 ; выдлить разряды 6 и 7
        cmp     al, 0x0c0 ; проверить разряды 6 и 7
        je      .GetByteFromFDC
        loop    .TestRS_1
        ; Ошибка тайм-аута
        mov     [FDC_Status],FDC_TimeOut
        jmp     .End_6

  .GetByteFromFDC:
        ; Ввести байт из порта данных
        inc     dx
        in      al,dx

  .End_6:
        pop     dx
        pop     ecx
        ret

;*********************************************
;* ОБРАБОТЧИК ПРЕРЫВАНИЯ ОТ КОНТРОЛЛЕРА НГМД *
;*********************************************
FDCInterrupt:
        ; Установить флаг прерывани
        mov     [FDD_IntFlag], 1
        ret

;******************************************
;* УСТАНОВИТЬ НОВЫЙ ОБРАБОТЧИК ПРЕРЫВАНИЙ *
;*             НГМД                       *
;******************************************
SetUserInterrupts:
        mov     [fdc_irq_func], FDCInterrupt
        ret

;*******************************************
;* ОЖИДАНИЕ ПРЕРЫВАНИЯ ОТ КОНТРОЛЛЕРА НГМД *
;*******************************************
WaitFDCInterrupt:
        pusha
        ; Сбросить байт состояния операции
        mov     [FDC_Status], FDC_Normal
        ; Сбросить флаг прерывани
        mov     [FDD_IntFlag], 0
        ; Обнулить счетчик тиков
        mov     eax, [timer_ticks]
        mov     [TickCounter], eax

  .TestRS_2:
        ; Ожидать установки флага прерывания НГМД
        cmp     [FDD_IntFlag], 0
        jnz     .End_7           ;прерывание произошло
        call    change_task
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter]
        cmp     eax, 50 ; 25 ;5 ; ожидать 5 тиков
;       jl      .TestRS_2
        jb      .TestRS_2
        ; Ошибка тайм-аута
;       mov     [flp_status], 0
        mov     [FDC_Status], FDC_TimeOut

  .End_7:
        popa
        ret

;*********************************
;* ВКЛЮЧИТЬ МОТОР ДИСКОВОДА "A:" *
;*********************************
FDDMotorON:
        pusha
;       cmp     [fdd_motor_status], 1
;       je      fdd_motor_on
        mov     al, [flp_number]
        cmp     [fdd_motor_status], al
        je      .fdd_motor_on
        ; Произвести сброс контроллера НГМД
        mov     dx, 0x3f2 ; порт управления двигателями
        mov     al, 0
        out     dx, al
        ; Выбрать и включить мотор дисковода
        cmp     [flp_number], 1
        jne     .FDDMotorON_B
;       call    FDDMotorOFF_B
        mov     al, 0x1c ; Floppy A
        jmp     .FDDMotorON_1

  .FDDMotorON_B:
;       call    FDDMotorOFF_A
        mov     al, 2dh    ; Floppy B

  .FDDMotorON_1:
        out     dx, al
        ; Обнулить счетчик тиков
        mov     eax, [timer_ticks]
        mov     [TickCounter], eax

  .dT:
        ; Ожидать 0,5 с
        call    change_task
        mov     eax, [timer_ticks]
        sub     eax, [TickCounter]
        cmp     eax, 50 ; 10
        jb      .dT
        cmp     [flp_number], 1
        jne     .fdd_motor_on_B
        mov     [fdd_motor_status], 1
        jmp     .fdd_motor_on

  .fdd_motor_on_B:
        mov     [fdd_motor_status], 2

  .fdd_motor_on:
        call    save_timer_fdd_motor
        popa
        ret

;*****************************************
;*  СОХРАНЕНИЕ УКАЗАТЕЛЯ ВРЕМЕНИ         *
;*****************************************
save_timer_fdd_motor:
        mov     eax, [timer_ticks]
        mov     [timer_fdd_motor], eax
        ret

;*****************************************
;*  ПРОВЕРКА ЗАДЕРЖКИ ВЫКЛЮЧЕНИЯ МОТОРА  *
;*****************************************
align 4
check_fdd_motor_status:
        cmp     [fdd_motor_status], 0
        je      .end_check_fdd_motor_status_1
        mov     eax, [timer_ticks]
        sub     eax, [timer_fdd_motor]
        cmp     eax, 500
        jb      .end_check_fdd_motor_status
        call    FDDMotorOFF
        mov     [fdd_motor_status], 0

  .end_check_fdd_motor_status_1:
        mov     [flp_status], 0

  .end_check_fdd_motor_status:
        ret

;**********************************
;* ВЫКЛЮЧИТЬ МОТОР ДИСКОВОДА      *
;**********************************
FDDMotorOFF:
        push    ax
        push    dx
        cmp     [flp_number], 1
        jne     .FDDMotorOFF_1
        call    .FDDMotorOFF_A
        jmp     .FDDMotorOFF_2

  .FDDMotorOFF_1:
        call    .FDDMotorOFF_B

  .FDDMotorOFF_2:
        pop     dx
        pop     ax
        ; сброс флагов кеширования в связи с устареванием информации
        mov     [root_read], 0
        mov     [flp_fat], 0
        ret

  .FDDMotorOFF_A:
        mov     dx, 0x3f2 ; порт управления двигателями
        mov     al, 0x0c ; Floppy A
        out     dx, al
        ret

  .FDDMotorOFF_B:
        mov     dx, 0x3f2 ; порт управления двигателями
        mov     al, 0x5 ; Floppy B
        out     dx, al
        ret

;*******************************
;* РЕКАЛИБРОВКА ДИСКОВОДА "A:" *
;*******************************
RecalibrateFDD:
        pusha
        call    save_timer_fdd_motor
        ; Подать команду "Рекалибровка"
        mov     al, 0x07
        call    FDCDataOutput
        mov     al, 0
        call    FDCDataOutput
        ; Ожидать завершения операции
        call    WaitFDCInterrupt
;       cmp     [FDC_Status], 0
;       je      .no_fdc_status_error
;       mov     [flp_status], 0

; .no_fdc_status_error:
        call    save_timer_fdd_motor
        popa
        ret

;*****************************************************
;*                    ПОИСК ДОРОЖКИ                  *
;* Параметры передаются через глобальные переменные: *
;* FDD_Track - номер дорожки (0-79);                 *
;* FDD_Head - номер головки (0-1).                   *
;* Результат операции заносится в FDC_Status.        *
;*****************************************************
SeekTrack:
        pusha
        call    save_timer_fdd_motor
        ; Подать команду "Поиск"
        mov     al, 0x0f
        call    FDCDataOutput
        ; Передать байт номера головки/накопител
        mov     al, [FDD_Head]
        shl     al, 2
        call    FDCDataOutput
        ; Передать байт номера дорожки
        mov     al, [FDD_Track]
        call    FDCDataOutput
        ; Ожидать завершения операции
        call    WaitFDCInterrupt
        cmp     [FDC_Status], FDC_Normal
        jne     .Exit
        ; Сохранить результат поиска
        mov     al, 0x08
        call    FDCDataOutput
        call    FDCDataInput
        mov     [FDC_ST0], al
        call    FDCDataInput
        mov     [FDC_C], al
        ; Проверить результат поиска
        ; Поиск завершен?
        test    [FDC_ST0], 0100000b
        je      .Err
        ; Заданный трек найден?
        mov     al, [FDC_C]
        cmp     al, [FDD_Track]
        jne     .Err
        ; Номер головки совпадает с заданным?
        mov     al, [FDC_ST0]
        and     al, 0100b
        shr     al, 2
        cmp     al, [FDD_Head]
        jne     .Err
        ; Операция завершена успешно
        mov     [FDC_Status], FDC_Normal
        jmp     .Exit

  .Err:
        ; Трек не найден
;       mov     [flp_status], 0
        mov     [FDC_Status], FDC_TrackNotFound

  .Exit:
        call    save_timer_fdd_motor
        popa
        ret

;*******************************************************
;*               ЧТЕНИЕ СЕКТОРА ДАННЫХ                 *
;* Параметры передаются через глобальные переменные:   *
;* FDD_Track - номер дорожки (0-79);                   *
;* FDD_Head - номер головки (0-1);                     *
;* FDD_Sector - номер сектора (1-18).                  *
;* Результат операции заносится в FDC_Status.          *
;* В случае успешного выполнения операции чтения       *
;* содержимое сектора будет занесено в FDD_DataBuffer. *
;*******************************************************
ReadSector:
        pushad
        call    save_timer_fdd_motor
        ; Установить скорость передачи 500 Кбайт/с
        mov     ax, 0
        mov     dx, 0x3f7
        out     dx, al
        ; Инициализировать канал прямого доступа к памяти
        mov     [dmamode], 0x46
        call    Init_FDC_DMA
        ; Подать команду "Чтение данных"
        mov     al, 0x0e6 ; чтение в мультитрековом режиме
        call    FDCDataOutput
        mov     al, [FDD_Head]
        shl     al, 2
        call    FDCDataOutput
        mov     al, [FDD_Track]
        call    FDCDataOutput
        mov     al, [FDD_Head]
        call    FDCDataOutput
        mov     al, [FDD_Sector]
        call    FDCDataOutput
        mov     al, 2 ; код размера сектора (512 байт)
        call    FDCDataOutput
        mov     al, 18 ; +1 ; 0x3f ; число секторов на дорожке
        call    FDCDataOutput
        mov     al, 0x1b ; значение GPL
        call    FDCDataOutput
        mov     al, 0x0ff ; значение DTL
        call    FDCDataOutput
        ; Ожидаем прерывание по завершении операции
        call    WaitFDCInterrupt
        cmp     [FDC_Status], FDC_Normal
        jne     .Exit_1
        ; Считываем статус завершения операции
        call    GetStatusInfo
        test    [FDC_ST0], 011011000b
        jnz     .Err_1
        mov     [FDC_Status], FDC_Normal
        jmp     .Exit_1

  .Err_1:
;       mov     [flp_status], 0
        mov     [FDC_Status], FDC_SectorNotFound

  .Exit_1:
        call    save_timer_fdd_motor
        popad
        ret

;*******************************************************
;*   ЧТЕНИЕ СЕКТОРА (С ПОВТОРЕНИЕМ ОПЕРАЦИИ ПРИ СБОЕ)  *
;* Параметры передаются через глобальные переменные:   *
;* FDD_Track - номер дорожки (0-79);                   *
;* FDD_Head - номер головки (0-1);                     *
;* FDD_Sector - номер сектора (1-18).                  *
;* Результат операции заносится в FDC_Status.          *
;* В случае успешного выполнения операции чтения       *
;* содержимое сектора будет занесено в FDD_DataBuffer. *
;*******************************************************
ReadSectWithRetr:
        pusha
        ; Обнулить счетчик повторения операции рекалибровки
        mov     [RecalRepCounter], 0

  .TryAgain:
        ; Обнулить счетчик повторения операции чтени
        mov     [ReadRepCounter], 0

  .ReadSector_1:
        call    ReadSector
        cmp     [FDC_Status], 0
        je      .Exit_2
        cmp     [FDC_Status], 1
        je      .Err_3
        ; Троекратное повторение чтени
        inc     [ReadRepCounter]
        cmp     [ReadRepCounter], 3
        jb      .ReadSector_1
        ; Троекратное повторение рекалибровки
        call    RecalibrateFDD
        call    SeekTrack
        inc     [RecalRepCounter]
        cmp     [RecalRepCounter], 3
        jb      .TryAgain
;       mov     [flp_status],0

  .Exit_2:
        popa
        ret

  .Err_3:
        mov     [flp_status], 0
        popa
        ret

;*******************************************************
;*               ЗАПИСЬ СЕКТОРА ДАННЫХ                 *
;* Параметры передаются через глобальные переменные:   *
;* FDD_Track - номер дорожки (0-79);                   *
;* FDD_Head - номер головки (0-1);                     *
;* FDD_Sector - номер сектора (1-18).                  *
;* Результат операции заносится в FDC_Status.          *
;* В случае успешного выполнения операции записи       *
;* содержимое FDD_DataBuffer будет занесено в сектор.  *
;*******************************************************
WriteSector:
        pushad
        call    save_timer_fdd_motor
        ; Установить скорость передачи 500 Кбайт/с
        mov     ax, 0
        mov     dx, 0x3F7
        out     dx, al
        ; Инициализировать канал прямого доступа к памяти
        mov     [dmamode], 0x4a
        call    Init_FDC_DMA
        ; Подать команду "Запись данных"
        mov     al, 0x0c5 ; 0x45 ; запись в мультитрековом режиме
        call    FDCDataOutput
        mov     al, [FDD_Head]
        shl     al, 2
        call    FDCDataOutput
        mov     al, [FDD_Track]
        call    FDCDataOutput
        mov     al, [FDD_Head]
        call    FDCDataOutput
        mov     al, [FDD_Sector]
        call    FDCDataOutput
        mov     al, 2 ; код размера сектора (512 байт)
        call    FDCDataOutput
        mov     al, 18 ; 0x3f ; число секторов на дорожке
        call    FDCDataOutput
        mov     al, 0x1b ; значение GPL
        call    FDCDataOutput
        mov     al, 0x0ff ; значение DTL
        call    FDCDataOutput
        ; Ожидаем прерывание по завершении операции
        call    WaitFDCInterrupt
        cmp     [FDC_Status], FDC_Normal
        jne     .Exit_3
        ; Считываем статус завершения операции
        call    GetStatusInfo
        test    [FDC_ST0], 011000000b  ;11011000b
        jnz     .Err_2
        mov     [FDC_Status], FDC_Normal
        jmp     .Exit_3

  .Err_2:
        mov     [FDC_Status], FDC_SectorNotFound

  .Exit_3:
        call    save_timer_fdd_motor
        popad
        ret

;*******************************************************
;*   ЗАПИСЬ СЕКТОРА (С ПОВТОРЕНИЕМ ОПЕРАЦИИ ПРИ СБОЕ)  *
;* Параметры передаются через глобальные переменные:   *
;* FDD_Track - номер дорожки (0-79);                   *
;* FDD_Head - номер головки (0-1);                     *
;* FDD_Sector - номер сектора (1-18).                  *
;* Результат операции заносится в FDC_Status.          *
;* В случае успешного выполнения операции записи       *
;* содержимое FDD_DataBuffer будет занесено в сектор.  *
;*******************************************************
WriteSectWithRetr:
        pusha
        ; Обнулить счетчик повторения операции рекалибровки
        mov     [RecalRepCounter], 0

  .TryAgain_1:
        ; Обнулить счетчик повторения операции чтени
        mov     [ReadRepCounter], 0

  .WriteSector_1:
        call    WriteSector
        cmp     [FDC_Status], 0
        je      .Exit_4
        cmp     [FDC_Status], 1
        je      .Err_4
        ; Троекратное повторение чтени
        inc     [ReadRepCounter]
        cmp     [ReadRepCounter], 3
        jb      .WriteSector_1
        ; Троекратное повторение рекалибровки
        call    RecalibrateFDD
        call    SeekTrack
        inc     [RecalRepCounter]
        cmp     [RecalRepCounter], 3
        jb      .TryAgain_1

  .Exit_4:
        popa
        ret

  .Err_4:
        mov     [flp_status], 0
        popa
        ret

;*********************************************
;* ПОЛУЧИТЬ ИНФОРМАЦИЮ О РЕЗУЛЬТАТЕ ОПЕРАЦИИ *
;*********************************************
GetStatusInfo:
        push    ax
        call    FDCDataInput
        mov     [FDC_ST0], al
        call    FDCDataInput
        mov     [FDC_ST1], al
        call    FDCDataInput
        mov     [FDC_ST2], al
        call    FDCDataInput
        mov     [FDC_C], al
        call    FDCDataInput
        mov     [FDC_H], al
        call    FDCDataInput
        mov     [FDC_R], al
        call    FDCDataInput
        mov     [FDC_N], al
        pop     ax
        ret
