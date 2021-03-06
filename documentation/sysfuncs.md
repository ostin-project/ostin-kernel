# Ostin System Functions Reference

Number of the function is located in the register eax. The call of the system function is executed by "int 0x40" command. All registers except explicitly declared in the returned value, including eflags, are preserved.

## Function 0: Define and Draw the Window

Defines an application window. Draws a frame of the window, header and working area. For skinned windows defines standard close and minimize buttons.

Parameters:

  * eax = 0 - function number
  * ebx = [coordinate on axis x]*65536 + [size on axis x]
  * ecx = [coordinate on axis y]*65536 + [size on axis y]
  * edx = 0xXYRRGGBB, where:
    * Y = style of the window:
      * Y=0 - type I - fixed-size window
      * Y=1 - only define window area, draw nothing
      * Y=2 - type II - variable-size window
      * Y=3 - skinned window
      * Y=4 - skinned fixed-size window
      * other possible values (from 5 up to 15) are reserved, function call with such Y is ignored
    * RR, GG, BB = accordingly red, green, blue components of a color of the working area of the window (are ignored for style Y=2)
    * X = DCBA (bits)
      * A = 1 - window has caption; for styles Y=3,4 caption string must be passed in edi, for other styles use function 71.1
      * B = 1 - coordinates of all graphics primitives are relative to window client area
      * C = 1 - don't fill working area on window draw
      * D = 0 - normal filling of the working area, 1 - gradient

The following parameters are intended for windows of a type I and II, and ignored for styles Y=1,3:

  * esi = 0xXYRRGGBB - color of the header
    * RR, GG, BB define color
    * Y=0 - usual window, Y=1 - unmovable window
    * X defines a gradient of header: X=0 - no gradient, X=8 - usual gradient, for windows of a type II X=4 - negative gradient
    * other values of X and Y are reserved
  * edi = 0x00RRGGBB - color of the frame

Returned value:

  * function does not return value

Remarks:

  * Position and sizes of the window are installed by the first call of this function and are ignored at subsequent; to change position and/or sizes of already created window use function 67.
  * For windows with styles Y=3,4 and caption (A=1) caption string is set by the first call of this function and is ignored at subsequent (strictly speaking, is ignored after a call to function 12.2 - end redraw); to change caption of already created window use function 71.1.
  * If the window has appropriate styles, position and/or sizes can be changed by user. Current position and sizes can be obtained by function 9.
  * The window must fit on the screen. If the transferred coordinates and sizes do not satisfy to this condition, appropriate coordinate (or, probably, both) is considered as zero, and if it does not help too, the appropriate size (or, probably, both) is installed in a size of the screen.

    Further let us designate xpos,ypos,xsize,ysize - values passed in ebx,ecx. The coordinates are resulted concerning the left upper corner of the window, which, thus, is set as (0,0), coordinates of the right lower corner essence (xsize,ysize).

  * The sizes of the window are understood in sence of coordinates of the right lower corner. This concerns all other functions too. It means, that the real sizes are on 1 pixel more.
  * The window of type I looks as follows:
    * draw external frame of color indicated in edi, 1 pixel in width
    * draw header - rectangle with the left upper corner (1,1) and right lower (xsize-1,min(25,ysize)) color indicated in esi (taking a gradient into account)
    * if ysize>=26, fill the working area of the window - rectangle with the left upper corner (1,21) and right lower (xsize-1,ysize-1) (sizes (xsize-1)*(ysize-21)) with color indicated in edx (taking a gradient into account)
    * if A=1 and caption has been already set by function 71.1, it is drawn in the corresponding place of header
  * The window of style Y=1 looks as follows:
    * completely defined by the application
  * The window of type II looks as follows:
    * draw external frame of width 1 pixel with the "shaded" color edi (all components of the color decrease twice)
    * draw intermediate frame of width 3 pixels with color edi
    * draw internal frame of width 1 pixel with the "shaded" color edi
    * draw header - rectangle with the left upper corner (4,4) and right lower (xsize-4,min(20,ysize)) color, indicated in esi (taking a gradient into account)
    * if ysize>=26, fill the working area of the window - rectangle with the left upper corner (5,20) and right lower (xsize-5,ysize-5) with color indicated in edx (taking a gradient into account)
    * if A=1 and caption has been already set by function 71.1, it is drawn in the corresponding place of header
  * The skinned window looks as follows:
    * draw external frame of width 1 pixel with color 'outer' from the skin
    * draw intermediate frame of width 3 pixel with color 'frame' from the skin
    * draw internal frame of width 1 pixel with color 'inner' from the skin
    * draw header (on bitmaps from the skin) in a rectangle (0,0) - (xsize,_skinh-1)
    * if ysize>=26, fill the working area of the window - rectangle with the left upper corner (5,_skinh) and right lower (xsize-5,ysize-5) with color indicated in edx (taking a gradient into account)
    * define two standard buttons: close and minimize (see function 8)
    * if A=1 and edi contains (nonzero) pointer to caption string, it is drawn in place in header defined in the skin
    * value _skinh is accessible as the result of call function 48.4

## Function 1: Put Pixel in the Window

Parameters:

  * eax = 1 - function number
  * ebx = x-coordinate (relative to the window)
  * ecx = y-coordinate (relative to the window)
  * edx = 0x00RRGGBB - color of a pixel
    edx = 0x01xxxxxx - invert color of a pixel (low 24 bits are ignored)

Returned value:

  * function does not return value

## Function 2: Get the Code of the Pressed Key

Takes away the code of the pressed key from the buffer.

Parameters:

  * eax = 2 - function number

Returned value:

  * if the buffer is empty, function returns eax=1
  * if the buffer is not empty, function returns al=0, ah=code of the pressed key, high word of eax is zero
  * if there is "hotkey", function returns al=2, ah=scancode of the pressed key (0 for control keys), high word of eax contains a status of control keys at the moment of pressing a hotkey

Remarks:

  * There is a common system buffer of the pressed keys by a size of 120 bytes, organized as queue.
  * There is one more common system buffer on 120 "hotkeys".
  * If the application with the inactive window calls this function, the buffer of the pressed keys is considered to be empty.
  * By default this function returns ASCII-codes; to switch to the scancodes mode (and back) use function 66. However, hotkeys are always notificated as scancodes.
  * To find out, what keys correspond to what codes, start the application keyascii and scancode.
  * Scancodes come directly from keyboard and are fixed; ASCII-codes turn out with usage of the conversion tables, which can be set by function 21.2 and get by function 26.2.
  * As a consequence, ASCII-codes take into account current keyboard layout (rus/en) as opposed to scancodes.
  * This function notifies only about those hotkeys, which were defined by this thread by function 66.4.


## Function 3: Get System Time

Parameters:

  * eax = 3 - function number

Returned value:

  * eax = 0x00SSMMHH, where HH:MM:SS = Hours:Minutes:Seconds
  * each item is BCD-number, for example, for time 23:59:59 function returns 0x00595923

Remarks:

  * See also function 26.9 - get time from the moment of start of the system; it is more convenient, because returns simply DWORD-value of the time counter.
  * System time can be set by function 22.

## Function 4: Draw Text String in the Window

Parameters:

  * eax = 4 - function number
  * ebx = [coordinate on axis x]*65536 + [coordinate on axis y]
  * ecx = 0xX0RRGGBB, where
    * RR, GG, BB specify text color
    * X=ABnn (bits):
    * nn specifies the used font: 0=system monospaced, 1=system font of variable width
    * A=0 - output esi characters, A=1 - output ASCIIZ-string
    * B=1 - fill background with the color edi
  * edx = pointer to the beginning of the string
  * esi = for A=0 length of the string, must not exceed 255; for A=1 is ignored

Returned value:

  * function does not return value

Remarks:

  * First system font is read out at loading from the file char.mt, second - from char2.mt.
  * Both fonts have height 9 pixels, width of the monospaced font is equal to 6 pixels.

## Function 5: Delay

Delays execution of the program on the given time.

Parameters:

  * eax = 5 - function number
  * ebx = time in the 1/100 of second

Returned value:

  * function does not return value

Remarks:

  * Passing ebx=0 does not transfer control to the next process and does not make any operations at all. If it is really required to transfer control to the next process (to complete a current time slice), use function 68.1.

## Function 6: Read the File from Ramdisk

Parameters:

  * eax = 6 - function number
  * ebx = pointer to the filename
  * ecx = number of start block, beginning from 1; ecx=0 - read from the beginning of the file (same as ecx=1)
  * edx = number of blocks to read; edx=0 - read one block (same as edx=1)
  * esi = pointer to memory area for the data

Returned value:

  * eax = file size in bytes, if the file was successfully read
  * eax = -1, if the file was not found

Remarks:

  * This function is out-of-date; function 70 allows to fulfil the same operations with the extended possibilities.
  * Block = 512 bytes.
  * For reading all file you can specify the certainly large value in edx, for example, edx = -1; but in this case be ready that the program will "fall", if the file will appear too large and can not be placed in the program memory.
  * The filename must be either in the format 8+3 characters (first 8 characters - name itself, last 3 - extension, the short names and extensions are supplemented with spaces), or in the format 8.3 characters "FILE.EXT"/"FILE.EX " (name no more than 8 characters, dot, extension 3 characters supplemented if necessary by spaces). The filename must be written with capital letters. The terminating character with code 0 is not necessary (not ASCIIZ-string).
  * This function does not support folders on the ramdisk.

## Function 7: Draw Image in the Window

Parameters:

  * eax = 7 - function number
  * ebx = pointer to the image in the format BBGGRRBBGGRR...
  * ecx = [size on axis x]*65536 + [size on axis y]
  * edx = [coordinate on axis x]*65536 + [coordinate on axis y]

Returned value:

  * function does not return value

Remarks:

  * Coordinates of the image are coordinates of the upper left corner of the image relative to the window.
  * Size of the image in bytes is 3*xsize*ysize.

## Function 8: Define/Delete the Button

Parameters for button definition:

  * eax = 8 - function number
  * ebx = [coordinate on axis x]*65536 + [size on axis x]
  * ecx = [coordinate on axis y]*65536 + [size on axis y]
  * edx = 0xXYnnnnnn, where:
    * nnnnnn = identifier of the button
    * high (31st) bit of edx is cleared
    * if 30th bit of edx is set - do not draw the button
    * if 29th bit of edx is set - do not draw a frame at pressing the button
  * esi = 0x00RRGGBB - color of the button

Parameters for button deleting:

  * eax = 8 - function number
  * edx = 0x80nnnnnn, where nnnnnn - identifier of the button

Returned value:

  * function does not return value

Remarks:

  * Sizes of the button must be more than 0 and less than 0x8000.
  * For skinned windows definition of the window (call of 0th function) creates two standard buttons - for close of the window with identifier 1 and for minimize of the window with identifier 0xffff.
  * The creation of two buttons with same identifiers is admitted.
  * The button with the identifier 0xffff at pressing is interpreted by the system as the button of minimization, the system handles such pressing independently, not accessing to the application. In rest it is usual button.
  * Total number of buttons for all applications is limited to 4095.

## Function 9: Information on Execution Thread

Parameters:

  * eax = 9 - function number
  * ebx = pointer to 1-Kb buffer
  * ecx = number of the slot of the thread; ecx = -1 - get information on the current thread

Returned value:

  * eax = maximum number of the slot of a thread
  * buffer pointed to by ebx contains the following information:
    * +0: dword: usage of the processor (how many time units per second leaves on execution of this thread)
    * +4: word: position of the window of thread in the window stack
    * +6: word: (has no relation to the specified thread) number of the thread slot, which window has in the window stack position ecx
    * +8: word: reserved
    * +10 = +0xA: 11 bytes: name of the process (name of corresponding executable file in the format 8+3)
    * +21 = +0x15: byte: reserved, this byte is not changed
    * +22 = +0x16: dword: address of the process in memory
    * +26 = +0x1A: dword: size of used memory - 1
    * +30 = +0x1E: dword: identifier (PID/TID)
    * +34 = +0x22: dword: coordinate of the thread window on axis x
    * +38 = +0x26: dword: coordinate of the thread window on axis y
    * +42 = +0x2A: dword: size of the thread window on axis x
    * +46 = +0x2E: dword: size of the thread window on axis y
    * +50 = +0x32: word: status of the thread slot:
      * 0 = thread is running
      * 1 = thread is suspended
      * 2 = thread is suspended while waiting for event
      * 3 = thread is terminating as a result of call to function -1 or under duress as a result of call to function 18.2 or termination of the system
      * 4 = thread is terminating as a result of exception
      * 5 = thread waits for event
      * 9 = requested slot is free, all other information on the slot is not meaningful
    * +52 = +0x34: word: reserved, this word is not changed
    * +54 = +0x36: dword: coordinate of the client area on axis x
    * +58 = +0x3A: dword: coordinate of the client area on axis y
    * +62 = +0x3E: dword: width of the client area
    * +66 = +0x42: dword: height of the client area
    * +70 = +0x46: byte: state of the window - bitfield
      * bit 0 (mask 1): window is maximized
      * bit 1 (mask 2): window is minimized to panel
      * bit 2 (mask 4): window is rolled up
    * +71 = +0x47: dword: event mask

Remarks:

  * Slots are numbered starting from 1.
  * Returned value is not a total number of threads, because there can be free slots.
  * When process is starting, system automatically creates execution thread.
  * Function gives information on the thread. Each process has at least one thread. One process can create many threads, in this case each thread has its own slot and the fields +10, +22, +26 in these slots coincide. Applications have no common way to define whether two threads belong to one process.
  * The active window - window on top of the window stack - receives the messages on a keyboard input. For such window the position in the window stack coincides with returned value.
  * Slot 1 corresponds to special system thread, for which:
    * the window is in the bottom of the window stack, the fields +4 and +6 contain value 1
    * name of the process - "OS/IDLE" (supplemented by spaces)
    * address of the process in memory is 0, size of used memory is 16 Mb (0x1000000)
    * PID=1
    * coordinates and sizes of the window and the client area are by convention set to 0
    * status of the slot is always 0 (running)
    * the execution time adds of time leaving on operations itself and idle time in waiting for interrupt (which can be got by call to function 18.4).
  * Beginning from slot 2, the normal applications are placed.
  * The normal applications are placed in memory at the address 0 (kernel constant 'std_application_base_address'). There is no intersection, as each process has its own page table.
  * At creation of the thread it is assigned the slot in the system table and identifier (Process/Thread IDentifier = PID/TID), which do not vary with time for given thread. After completion of the thread its slot can be anew used for another thread. The thread identifier can not be assigned to other thread even after completion of this thread. Identifiers, assigned to new threads, grow monotonously.
  * If the thread has not yet defined the window by call to function 0, the position and the sizes of its window are considered to be zero.
  * Coordinates of the client area are relative to the window.
  * At the moment only the part of the buffer by a size 71 = 0x37 bytes is used. Nevertheless it is recommended to use 1-Kb buffer for the future compatibility, in the future some fields can be added.

## Function 10: Wait for Event

If the message queue is empty, waits for appearance of the message in queue. In this state thread does not consume CPU time. Then reads out the message from queue.

Parameters:

  * eax = 10 - function number

Returned value:

  * eax = event (see the list of events)

Remarks:

  * Those events are taken into account only which enter into a mask set by function 40. By default it is redraw, key and button events.
  * To check, whether there is a message in queue, use function 11. To wait for no more than given time, use function 23.

## Function 11: Check for Event, No Wait

If the message queue contains event, function reads out and return it. If the queue is empty, function returns 0.

Parameters:

  * eax = 11 - function number

Returned value:

  * eax = 0 - message queue is empty
  * else eax = event (see the list of events)

Remarks:

  * Those events are taken into account only, which enter into a mask set by function 40. By default it is redraw, key and button events.
  * To wait for event, use function 10. To wait for no more than given time, use function 23.

## Function Group 12: Begin/End Window Redraw

### Function 12.1: Begin Window Redraw

Parameters:

  * eax = 12 - function number
  * ebx = 1 - subfunction number

Returned value:

  * function does not return value

### Function 12.2: End Window Redraw

Parameters:

  * eax = 12 - function number
  * ebx = 2 - subfunction number

Returned value:

  * function does not return value

Remarks:

  * Function 12.1 deletes all buttons defined with function 8, they must be defined again.

## Function 13: Draw a Rectangle in the Window

Parameters:

  * eax = 13 - function number
  * ebx = [coordinate on axis x]*65536 + [size on axis x]
  * ecx = [coordinate on axis y]*65536 + [size on axis y]
  * edx = color 0xRRGGBB or 0x80RRGGBB for gradient fill

Returned value:

  * function does not return value

Remarks:

  * Coordinates are understood as coordinates of the left upper corner of a rectangle relative to the window.

## Function 14: Get Screen Size

Parameters:

  * eax = 14 - function number

Returned value:

  * eax = [xsize]*65536 + [ysize], where
    * xsize = x-coordinate of the right lower corner of the screen = horizontal size - 1
    * ysize = y-coordinate of the right lower corner of the screen = vertical size - 1

Remarks:

  * See also function 48.5 - get sizes of working area of the screen.

## Function Group 15: Set Background Image

### Function 15.1: Set a Size of the Background Image

Parameters:

  * eax = 15 - function number
  * ebx = 1 - subfunction number
  * ecx = width of the image
  * edx = height of the image

Returned value:

  * function does not return value

Remarks:

  * Before calling functions 15.2 and 15.5 you should call this function to set image size!
  * For update of the screen (after completion of a series of commands working with a background) call function 15.3.
  * There is a pair function for get size of the background image - function 39.1.

### Function 15.2: Put Pixel on the Background Image

Parameters:

  * eax = 15 - function number
  * ebx = 2 - subfunction number
  * ecx = offset
  * edx = color of a pixel 0xRRGGBB

Returned value:

  * function does not return value

Remarks:

  * Offset for a pixel with coordinates (x,y) is calculated as (x+y*xsize)*3.
  * If the given offset exceeds size set by function 15.1, the call is ignored.
  * For update of the screen (after completion of a series of commands working with a background) call function 15.3.
  * There is a pair function for get pixel on the background image - function 39.2.

### Function 15.3: Redraw Background

Parameters:

  * eax = 15 - function number
  * ebx = 3 - subfunction number

Returned value:

  * function does not return value

### Function 15.4: Set Drawing Mode for the Background

Parameters:

  * eax = 15 - function number
  * ebx = 4 - subfunction number
  * ecx = drawing mode:
    * 1 = tile
    * 2 = stretch

Returned value:

  * function does not return value

Remarks:

  * For update of the screen (after completion of a series of commands working with a background) call function 15.3.
  * There is a pair function for get drawing mode of the background - function 39.4.


### Function 15.5: Put Block of Pixels on the Background Image

Parameters:

  * eax = 15 - function number
  * ebx = 5 - subfunction number
  * ecx = pointer to the data in the format BBGGRRBBGGRR...
  * edx = offset in data of the background image
  * esi = size of data in bytes = 3 * number of pixels

Returned value:

  * function does not return value

Remarks:

  * Offset and size are not checked for correctness.
  * Color of each pixel is stored as 3-bytes value BBGGRR.
  * Pixels of the background image are written sequentially from left to right, from up to down.
  * Offset of pixel with coordinates (x,y) is (x+y*xsize)*3.
  * For update of the screen (after completion of a series of commands working with a background) call function 15.3.

### Function 15.6: Map Background Data to the Address Space of Process

Parameters:

  * eax = 15 - function number
  * ebx = 6 - subfunction number

Returned value:

  * eax = pointer to background data, 0 if error

Remarks:

  * Mapped data are available for read and write.
  * Size of background data is 3*xsize*ysize. The system blocks changes of background sizes while process works with mapped data.
  * Color of each pixel is stored as 3-bytes value BBGGRR.
  * Pixels of the background image are written sequentially from left to right, from up to down.

### Function 15.7: Close Mapped Background Data

Parameters:

  * eax = 15 - function number
  * ebx = 7 - subfunction number
  * ecx = pointer to mapped data

Returned value:

  * eax = 1 - success, 0 - error

## Function 16: Save Ramdisk on a Floppy

Parameters:

  * eax = 16 - function number
  * ebx = 1 or ebx = 2 - on which floppy save

Returned value:

  * eax = 0 - success
  * eax = 1 - error

## Function 17: Get the Identifier of the Pressed Button

Takes away the code of the pressed button from the buffer.

Parameters:

  * eax = 17 - function number

Returned value:

  * if the buffer is empty, function returns eax=1
  * if the buffer is not empty:
    * high 24 bits of eax contain button identifier (in particular, ah contains low byte of the identifier; if all buttons have the identifier less than 256, ah is enough to distinguish)
    * al = 0 - the button was pressed with left mouse button
    * al = bit corresponding to used mouse button otherwise

Remarks:

  * "Buffer" keeps only one button, at pressing the new button the information about old is lost.
  * The call of this function by an application with inactive window will return answer "buffer is empty".
  * Returned value for al corresponds to the state of mouse buttons as in function 37.2 at the beginning of button press, excluding lower bit, which is cleared.

## Function Group 18: System Control

### Function 18.2: Terminate Process/Thread by the Slot

Parameters:

  * eax = 18 - function number
  * ebx = 2 - subfunction number
  * ecx = number of the slot of process/thread

Returned value:

  * function does not return value

Remarks:

  * It is impossible to terminate system thread OS/IDLE (with number of the slot 1), it is possible to terminate any normal process/thread.
  * See also function 18.18 - terminate process/thread by the identifier.

### Function 18.3: Make Active the Window of the Given Thread

Parameters:

  * eax = 18 - function number
  * ebx = 3 - subfunction number
  * ecx = number of the thread slot

Returned value:

  * function does not return value

Remarks:

  * If correct, but nonexistent slot is given, some window is made active.
  * To find out, which window is active, use function 18.7.

### Function 18.4: Get Counter of Idle Time Units per One Second

Idle time units are units, in which the processor stands idle in waiting for interrupt (in the command 'hlt').

Parameters:

  * eax = 18 - function number
  * ebx = 4 - subfunction number

Returned value:

  * eax = value of the counter of idle time units per one second

### Function 18.5: Get CPU Clock Rate

Parameters:

  * eax = 18 - function number
  * ebx = 5 - subfunction number

Returned value:

  * eax = clock rate (modulo 2^32 clock ticks = 4GHz)

### Function 18.6: Save Ramdisk to the File on Hard Drive

Parameters:

  * eax = 18 - function number
  * ebx = 6 - subfunction number
  * ecx = pointer to the full path to file (for example, "/hd0/1/kolibri/kolibri.img")

Returned value:

  * eax = 0 - success
  * else eax = error code of the file system

Remarks:

  * All folders in the given path must exist, otherwise function returns value 5, "file not found".

### Function 18.7: Get Active Window

Parameters:

  * eax = 18 - function number
  * ebx = 7 - subfunction number

Returned value:

  * eax = number of the active window (number of the slot of the thread with active window)

Remarks:

  * Active window is at the top of the window stack and receives messages on all keyboard input.
  * To make a window active, use function 18.3.

### Function Group 18.8: Disable/Enable the Internal Speaker

If speaker sound is disabled, all calls to function 55.55 are ignored. If speaker sound is enabled, they are routed on builtin speaker.

#### Function 18.1.1: Get Status

Parameters:

  * eax = 18 - function number
  * ebx = 8 - subfunction number
  * ecx = 1 - number of the subsubfunction

Returned value:

  * eax = 0 - speaker sound is enabled; 1 - disabled

#### Function 18.1.2: Toggle Status

Toggles states of disable/enable.

Parameters:

  * eax = 18 - function number
  * ebx = 8 - subfunction number
  * ecx = 2 - number of the subsubfunction

Returned value:

  * function does not return value

### Function 18.9: System Shutdown With the Parameter

Parameters:

  * eax = 18 - function number
  * ebx = 9 - subfunction number
  * ecx = parameter:
    * 2 = turn off computer
    * 3 = reboot computer
    * 4 = restart the kernel from the file 'kernel.mnt' on ramdisk

Returned value:

  * at incorrect ecx the registers do not change (i.e. eax=18)
  * by correct call function always returns eax=0 as the tag of success

Remarks:

  * Do not rely on returned value by incorrect call, it can be changed in future versions of the kernel.

### Function 18.10: Minimize Application Window

Minimizes the own window.

Parameters:

  * eax = 18 - function number
  * ebx = 10 - subfunction number

Returned value:

  * function does not return value

Remarks:

  * The minimized window from the point of view of function 9 keeps position and sizes.
  * Restoring of an application window occurs at its activation by function 18.3.
  * Usually there is no necessity to minimize/restire a window obviously: minimization of a window is carried out by the system at pressing the minimization button (for skinned windows it is defined automatically by function 0, for other windows it can be defined manually by function 8), restore of a window is done by the application '@panel'.

### Function 18.11: Get Information on the Disk Subsystem

Parameters:

  * eax = 18 - function number
  * ebx = 11 - subfunction number
  * ecx = type of the table:
    * 1 = short version, 10 bytes
    * 2 = full version, 65536 bytes
  * edx = pointer to the buffer (in the application) for the table

Returned value:

  * function does not return value

Format of the table: short version:

  * +0: byte: information about FDD's (drives for floppies), AAAABBBB, where AAAA gives type of the first drive, BBBB - of the second regarding to the following list:
    * 0 = there is no drive
    * 1 = 360Kb, 5.25''
    * 2 = 1.2Mb, 5.25''
    * 3 = 720Kb, 3.5''
    * 4 = 1.44Mb, 3.5''
    * 5 = 2.88Mb, 3.5'' (such drives are not used anymore)

    For example, for the standard configuration from one 1.44-drive here will be 40h, and for the case 1.2Mb on A: and 1.44Mb on B: the value is 24h.

  * +1: byte: information about hard disks and CD-drives, AABBCCDD, where AA corresponds to the controller IDE0, ..., DD - IDE3:
    * 0 = device is absent
    * 1 = hard drive
    * 2 = CD-drive

    For example, in the case HD on IDE0 and CD on IDE2 this field contains 48h.

  * +2: 4 db: number of the retrieved partitions on hard disks at accordingly IDE0,...,IDE3. If the hard disk on IDEx is absent, appropriate byte is zero, otherwise it shows number of the recognized partitions, which can be not presented (if the drive is not formatted or if the file system is not supported). Current version of the kernel supports only FAT16, FAT32 and NTFS for hard disks.
  * +6: 4 db: reserved

Format of the table: full version:

  * +0: 10 db: same as for the short version
  * +10: 100 db: data for the first partition
  * +110: 100 db: data for the second partition
  * ...
  * +10+100*(n-1): 100 db: data for the last partition

The partitions are located as follows: at first sequentially all recoginzed partitions on HD on IDE0 (if present), then on HD on IDE1 (if present) and so on up to IDE3.

Format of the information about partition (at moment only FAT is supported):

  * +0: dword: first physical sector of the partition
  * +4: dword: last physical sector of the partition (belongs to the partition)
  * +8: byte: file system type: 16=FAT16, 32=FAT32, 1=NTFS
  * other data are dependent on file system, are modified with kernel modifications and therefore are not described

Remarks:

  * The short table can be used for obtaining the information about available devices.

### Function 18.13: Get Kernel Version

Parameters:

  * eax = 18 - function number
  * ebx = 13 - subfunction number
  * ecx = pointer to the buffer (not less than 16 bytes), where the information will be placed

Returned value:

  * function does not return value

Structure of the buffer:

    db a,b,c,d for version a.b.c.d
    db 0: reserved
    dd REV - kernel SVN revision number

For Kolibri 0.7.7.0+ kernel:

    db 0,7,7,0
    db 0
    dd 1675

### Function 18.14: Wait for Screen Retrace

Waits for the beginning of retrace of the scanning ray of the screen monitor.

Parameters:

  * eax = 18 - function number
  * ebx = 14 - subfunction number

Returned value:

  * eax = 0 as the tag of success

Remarks:

  * Function is intended only for active high-efficiency graphics applications; is used for smooth output of a graphics.

### Function 18.15: Center Mouse Cursor on the Screen

Parameters:

  * eax = 18 - function number
  * ebx = 15 - subfunction number

Returned value:

  * eax = 0 as the tag of success

### Function 18.16: Get Size of Free RAM

Parameters:

  * eax = 18 - function number
  * ebx = 16 - subfunction number

Returned value:

  * eax = size of free memory in kilobytes

### Function 18.17: Get Full Amount of RAM

Parameters:

  * eax = 18 - function number
  * ebx = 17 - subfunction number

Returned value:

  * eax = total size of existing memory in kilobytes


### Function 18.18: Terminate Process/Thread by the Identifier

Parameters:

  * eax = 18 - function number
  * ebx = 18 - subfunction number
  * ecx = identifer of process/thread (PID/TID)

Returned value:

  * eax = 0 - success
  * eax = -1 - error (process is not found or is system)

Remarks:

  * It is impossible to terminate system thread OS/IDLE (identifier 1), it is possible to terminate any normal process/thread.
  * See also function 18.2 - terminate process/thread by given slot.

### Function Group 18.19: Get/Set Mouse Features

#### Function 18.19.0: Get Mouse Speed

Parameters:

  * eax = 18 - function number
  * ebx = 19 - subfunction number
  * ecx = 0 - subsubfunction number

Returned value:

  * eax = current mouse speed

#### Function 18.19.1: Set Mouse Speed

Parameters:

  * eax = 18 - function number
  * ebx = 19 - subfunction number
  * ecx = 1 - subsubfunction number
  * edx = new value for speed

Returned value:

  * function does not return value

#### Function 18.19.2: Get Mouse Delay

Parameters:

  * eax = 18 - function number
  * ebx = 19 - subfunction number
  * ecx = 2 - subsubfunction number

Returned value:

  * eax = current mouse delay

#### Function 18.19.3: Set Mouse Delay

Parameters:

  * eax = 18 - function number
  * ebx = 19 - subfunction number
  * ecx = 3 - subsubfunction number
  * edx = new value for mouse delay

Returned value:

  * function does not return value

#### Function 18.19.4: Set Mouse Pointer Position

Parameters:

  * eax = 18 - function number
  * ebx = 19 - subfunction number
  * ecx = 4 - subsubfunction number
  * edx = [coordinate on axis x]*65536 + [coordinate on axis y]

Returned value:

  * function does not return value

#### Function 18.19.5: Simulate State of Mouse Buttons

Parameters:

  * eax = 18 - function number
  * ebx = 19 - subfunction number
  * ecx = 5 - subsubfunction number
  * edx = information about emulated state of mouse buttons (same as return value in function 37.2):
    * bit 0 is set = left button is pressed
    * bit 1 is set = right button is pressed
    * bit 2 is set = middle button is pressed
    * bit 3 is set = 4th button is pressed
    * bit 4 is set = 5th button is pressed

Returned value:

  * function does not return value

Remarks:

  * It is recommended to set speed of the mouse (in function 18.19.1) from 1 up to 9. The installed value is not inspected by the kernel code, so set it carefully, at incorrect value the cursor can "freeze". Speed of the mouse can be regulated through the application SETUP.
  * Recommended delay of the mouse (in function 18.19.3) = 10. Lower value is not handled by COM mice. At the very large values the movement of the mouse on 1 pixel is impossible and the cursor will jump on the value of installed speed (function 18.19.1). The installed value is not inspected by the kernel code. Mouse delay can be regulated through the application SETUP.
  * The function 18.19.4 does not check the passed value. Before its call find out current screen resolution (with function 14) and check that the value of position is inside the limits of the screen.

### Function 18.20: Get Information on RAM

Parameters:

  * eax = 18 - function number
  * ebx = 20 - subfunction number
  * ecx = pointer to the buffer for information (36 bytes)

Returned value:

  * eax = total size of existing RAM in pages or -1 if error has occured
  * buffer pointed to by ecx contains the following information:
    * +0:  dword: total size of existing RAM in pages
    * +4:  dword: size of free RAM in pages
    * +8:  dword: number of page faults (exceptions #PF) in applications
    * +12: dword: size of kernel heap in bytes
    * +16: dword: free in kernel heap in bytes
    * +20: dword: total number of memory blocks in kernel heap
    * +24: dword: number of free memory blocks in kernel heap
    * +28: dword: size of maximum free block in kernel heap (reserved)
    * +32: dword: size of maximum allocated block in kernel heap (reserved)

### Function 18.21: Get Slot Number of Process/Thread by the Identifier

Parameters:

  * eax = 18 - function number
  * ebx = 21 - subfunction number
  * ecx = identifer of process/thread (PID/TID)

Returned value:

  * eax = 0 - error (invalid identifier)
  * otherwise eax = slot number

### Function 18.22: Operations With Window of Another Thread

Parameters:

  * eax = 18 - function number
  * ebx = 22 - subfunction number
  * ecx = operation type:
    * 0 = minimize window of the thread with given slot number
    * 1 = minimize window of the thread with given identifier
    * 2 = restore window of the thread with given slot number
    * 3 = restore window of the thread with given identifier
  * edx = parameter (slot number or PID/TID)

Returned value:

  * eax = 0 - success
  * eax = -1 - error (invalid identifier)

Remarks:

  * The thread can minimize its window with function 18.10.
  * One can restore and activate window simultaneously with function 18.3 (which requires slot number).

## Function Group 20: MIDI Interface

### Function 20.1: Reset

Parameters:

  * eax = 20 - function number
  * ebx = 1 - subfunction number

### Function 20.2: Output Byte

Parameters:

  * eax = 20 - function number
  * ebx = 2 - subfunction number
  * cl = byte for output

Returned value (is the same for both subfunctions):

  * eax = 0 - success
  * eax = 1 - base port is not defined

Remarks:

  * Previously the base port must be defined by function 21.1.

## Function Group 21: Set Configuration

### Function 21.1: Set MPU MIDI Base Port

Parameters:

  * eax = 21 - function number
  * ebx = 1 - subfunction number
  * ecx = number of base port

Returned value

  * eax = 0 - success
  * eax = -1 - erratic number of a port

Remarks:

  * Number of a port must satisfy to conditions 0x100<=ecx<=0xFFFF.
  * The installation of base is necessary for function 20.
  * To get base port use function 26.1.

### Function 21.2: Set Keyboard Layout

Keyboard layout is used to convert keyboard scancodes to ASCII-codes, which will be read by function 2.

Parameters:

  * eax = 21 - function number
  * ebx = 2 - subfunction number
  * ecx = which layout to set:
    * 1 = normal layout
    * 2 = layout at pressed Shift
    * 3 = layout at pressed Alt
  * edx = pointer to layout - table of length 128 bytes

Or:

  * ecx = 9
  * dx = country identifier (1=eng, 2=fi, 3=ger, 4=rus)

Returned value:

  * eax = 0 - success
  * eax = 1 - incorrect parameter

Remarks:

  * If Alt is pressed, the layout with Alt is used; if Alt is not pressed, but Shift is pressed, the layout with Shift is used; if Alt and Shift are not pressed, but Ctrl is pressed, the normal layout is used and then from the code is subtracted 0x60; if no control key is pressed, the normal layout is used.
  * To get layout and country identifier use function 26.2.
  * Country identifier is global system variable, which is not used by the kernel itself; however the application '@panel' displays the corresponding icon.
  * The application @panel switches layouts on user request.

### Function 21.3: Set CD Base

Parameters:

  * eax = 21 - function number
  * ebx = 3 - subfunction number
  * ecx = CD base: 1=IDE0, 2=IDE1, 3=IDE2, 4=IDE3

Returned value:

  * eax = 0

Remarks:

  * CD base is used by function 24.
  * To get CD base use function 26.3.

### Function 21.5: Set System Language

Parameters:

  * eax = 21 - function number
  * ebx = 5 - subfunction number
  * ecx = system language (1=eng, 2=fi, 3=ger, 4=rus)

Returned value:

  * eax = 0

Remarks:

  * System language is global system variable and is not used by the kernel itself, however application @panel draws the appropriate icon.
  * Function does not check for correctness, as the kernel does not use this variable.
  * To get system language use function 26.5.

### Function 21.7: Set HD Base

The HD base defines hard disk to write with usage of obsolete syntax /HD in obsolete function 58; at usage of modern syntax /HD0,/HD1,/HD2,/HD3 base is set automatically.

Parameters:

  * eax = 21 - function number
  * ebx = 7 - subfunction number
  * ecx = HD base: 1=IDE0, 2=IDE1, 3=IDE2, 4=IDE3

Returned value:

  * eax = 0

Remarks:

  * Any application at any time can change the base.
  * Do not change base, when any application works with hard disk. If you do not want system bugs.
  * To get HD base use function 26.7.
  * It is also necessary to define used partition of hard disk by function 21.8.

### Function 21.8: Set Used HD Partition

The HD partition defines partition of the hard disk to write with usage of obsolete syntax /HD and obsolete function 58; at usage of functions 58 and 70 and modern syntax /HD0,/HD1,/HD2,/HD3 base and partition are set automatically.

Parameters:

  * eax = 21 - function number
  * ebx = 8 - subfunction number
  * ecx = HD partition (beginning from 1)

Return value:

  * eax = 0

Remarks:

  * Any application at any time can change partition.
  * Do not change partition when any application works with hard disk. If you do not want system bugs.
  * To get used partition use function 26.8.
  * There is no correctness checks.
  * To get the number of partitions of a hard disk use function 18.11.
  * It is also necessary to define used HD base by function 21.7.

### Function 21.11: Enable/Disable Low-Level Access to HD

Parameters:

  * eax = 21 - function number
  * ebx = 11 - subfunction number
  * ecx = 0/1 - disable/enable

Returned value:

  * eax = 0

Remarks:

  * Is used in LBA-read (function 58.8).
  * The current implementation uses only low bit of ecx.
  * To get current status use function 26.11.

### Function 21.12: Enable/Disable Low-Level Access to PCI

Parameters:

  * eax = 21 - function number
  * ebx = 12 - subfunction number
  * ecx = 0/1 - disable/enable

Returned value:

  * eax = 0

Remarks:

  * Is used in operations with PCI bus (function 62).
  * The current implementation uses only low bit of ecx.
  * To get current status use function 26.12.

### Function Group 21.13: Video Driver Control

#### Function 21.13.1: Initialize + Get Information on the Driver VMODE.MDR

Parameters:

  * eax = 21 - function number
  * ebx = 13 - subfunction number
  * ecx = 1 - number of the driver function
  * edx = pointer to 512-bytes buffer

Returned value:

  * if driver is not loaded (never happens in the current implementation):
    * eax = -1
    * ebx, ecx destroyed
  * if driver is loaded:
    * eax = 'MDAZ' (in fasm style, that is 'M' - low byte, 'Z' - high) - signature
    * ebx = current frequency of the scanning (in Hz)
    * ecx destroyed
    * buffer pointed to by edx is filled

Format of the buffer:

  * +0: 32*byte: driver name, "Trans VideoDriver" (without quotes, supplemented by spaces)
  * +32 = +0x20: dword: driver version (version x.y is encoded as y*65536+x), for the current implementation is 1 (1.0)
  * +36 = +0x24: 7*dword: reserved (0 in the current implementation)
  * +64 = +0x40: 32*word: list of supported videomodes (each word is number of a videomode, after list itself there are zeroes)
  * +128 = +0x80: 32*(5*word): list of supported frequences of the scannings for videomodes: for each videomode listed in the previous field up to 5 supported frequences are given (unused positions contain zeroes)

Remarks:

  * Function initializes the driver (if it is not initialized yet) and must be called first, before others (otherwise they will do nothing and return -1).
  * The current implementation supports only one frequency of the scanning on videomode.

#### Function 21.13.2: Get Information on Current Videomode

Parameters:

  * eax = 21 - function number
  * ebx = 13 - subfunction number
  * ecx = 2 - number of the driver function

Returned value:

  * eax = -1 - driver is not loaded or not initialized; ebx,ecx are destroyed
  * eax = [width]*65536 + [height]
  * ebx = frequency of the vertical scanning (in Hz)
  * ecx = number of current videomode

Remarks:

  * Driver must be initialized by call to driver function 1.
  * If only screen sizes are required, it is more expedient to use function 14 taking into account that it returns sizes on 1 less.

#### Function 21.13.3: Set Videomode

Parameters:

  * eax = 21 - function number
  * ebx = 13 - subfunction number
  * ecx = 3 - number of the driver function
  * edx = [scanning frequency]*65536 + [videomode number]

Returned value:

  * eax = -1 - driver is not loaded, not initialized or an error has occured
  * eax = 0 - success
  * ebx, ecx destroyed

Remarks:

  * Driver must be initialized by driver function 1.
  * The videomode number and frequency must be in the table returned by driver function 1.

#### Function 21.13.4: Return to the Initial Videomode

Returns the screen to the videomode set at system boot.

Parameters:

  * eax = 21 - function number
  * ebx = 13 - subfunction number
  * ecx = 4 - number of the driver function

Returned value:

  * eax = -1 - driver is not loaded or not initialized
  * eax = 0 - success
  * ebx, ecx destroyed

Remarks:

  * Driver must be initialized by call to driver function 1.

#### Function 21.13.5: Increase/Decrease the Size of the Visible Area of Monitor

Parameters:

  * eax = 21 - function number
  * ebx = 13 - subfunction number
  * ecx = 5 - number of the driver function
  * edx = 0/1 - decrease/increase horizontal size on 1 position
  * edx = 2/3 - is not supported in the current implementation; is planned as decrease/increase vertical size on 1 position

Returned value:

  * eax = -1 - driver is not loaded or not initialized
  * eax = 0 - success
  * ebx, ecx destroyed

Remarks:

  * Driver must be initialized by call to driver function 1.
  * Function influences only the physical size of the screen image; the logical size (number of pixels) does not change.

## Function 22: Set System Date/Time

Parameters:

  * eax = 22 - function number
  * ebx = 0 - set time
    * ecx = 0x00SSMMHH - time in the binary-decimal code (BCD):
    * HH=hour 00..23
    * MM=minute 00..59
    * SS=second 00..59
  * ebx = 1 - set date
    * ecx = 0x00DDMMYY - date in the binary-decimal code (BCD):
    * DD=day 01..31
    * MM=month 01..12
    * YY=year 00..99
  * ebx = 2 - set day of week
    * ecx = 1 for Sunday, ..., 7 for Saturday
  * ebx = 3 - set alarm clock
    * ecx = 0x00SSMMHH

Returned value:

  * eax = 0 - success
  * eax = 1 - incorrect parameter
  * eax = 2 - CMOS-battery was unloaded

Remarks:

  * Value of installation of day of week seems to be doubtful, as it a little where is used (day of week can be calculated by date).
  * Alarm clock can be set on operation in the given time every day. But there is no existing system function to disable it.
  * Operation of alarm clock consists in generation IRQ8.
  * Generally CMOS supports for alarm clock set of value 0xFF as one of parameters and it means that the appropriate parameter is ignored. But current implementation does not allow this (will return 1).
  * Alarm clock is a global system resource; the set of an alarm clock cancels automatically the previous set. However, at moment no program uses it.

## Function 23: Wait for Event With Timeout

If the message queue is empty, waits for new message in the queue, but no more than given time. Then reads out a message from the queue.

Parameters:

  * eax = 23 - function number
  * ebx = timeout (in 1/100 of second)

Returned value:

  * eax = 0 - the message queue is empty
  * otherwise eax = event (see the list of events)

Remarks:

  * Only those events are taken into account, which enter into the mask set by function 40. By default it is redraw, key and button events.
  * To check for presence of a message in the queue use function 11. To wait without timeout use function 10.
  * Transmission ebx=0 results in immediate returning eax=0.
  * Current implementation returns immediately with eax=0, if the addition of ebx with the current value of time counter makes 32-bit overflow.

## Function Group 24: CD-Audio Control

### Function 24.1: Begin to Play CD-Audio

Parameters:

  * eax = 24 - function number
  * ebx = 1 - subfunction number
  * ecx = 0x00FRSSMM, where
    * MM = starting minute
    * SS = starting second
    * FR = starting frame

Returned value:

  * eax = 0 - success
  * eax = 1 - CD base is not defined

Remarks:

  * Previously CD base must be defined by the call to function 21.3.
  * One second includes 75 frames, one minute includes 60 seconds.
  * The function is asynchronous (returns control, when play begins).

### Function 24.2: Get Information on Tracks

Parameters:

  * eax = 24 - function number
  * ebx = 2 - subfunction number
  * ecx = pointer to the buffer for the table (maximum 8*64h+4 bytes=100 tracks)

Returned value:

  * eax = 0 - success
  * eax = 1 - CD base is not defined

Remarks:

  * The format of the table with tracks information is the same as for ATAPI-CD command 43h (READ TOC), usual table (subcommand 00h). Function returns addresses in MSF.
  * Previously CD base port must be set by call to function 21.3.
  * Function returns information only about no more than 100 first tracks. In most cases it is enough.

### Function 24.3: Stop Play CD-Audio

Parameters:

  * eax = 24 - function number
  * ebx = 1 - subfunction number

Returned value:

  * eax = 0 - success
  * eax = 1 - CD base is not defined

Remarks:

  * Previously CD base port must be defined by call to function 21.3.

### Function 24.4: Eject Tray of Disk Drive

Parameters:

  * eax = 24 - function number
  * ebx = 4 - subfunction number
  * ecx = position of CD/DVD-drive (from 0=Primary Master to 3=Secondary Slave)

Returned value:

  * function does not return value

Remarks:

  * The function is supported only for ATAPI devices (CD and DVD).
  * When the tray is being ejected, manual control of tray is unlocked.
  * When the tray is being ejected, the code clears the cache for corresponding device.
  * An example of usage of the function is the application CD_tray.

### Function 24.5: Load Tray of Disk Drive

Parameters:

  * eax = 24 - function number
  * ebx = 5 - subfunction number
  * ecx = position of CD/DVD-drive (from 0=Primary Master to 3=Secondary Slave)

Returned value:

  * function does not return value

Remarks:

  * The function is supported only for ATAPI devices (CD and DVD).
  * An example of usage of the function is the application CD_tray.

## Function Group 26: Get Configuration

### Function 26.1: Get MPU MIDI Base Port

Parameters:

  * eax = 26 - function number
  * ebx = 1 - subfunction number

Returned value:

  * eax = port number

Parameters:

  * To set base port use function 21.1.

### Function 26.2: Get Keyboard Layout

The keyboard layout is used to convert keyboard scancodes to ASCII-codes for function 2.

Parameters:

  * eax = 26 - function number
  * ebx = 2 - subfunction number
  * ecx = what layout to get:
    * 1 = normal layout
    * 2 = layout with pressed Shift
    * 3 = layout with pressed Alt
  * edx = pointer to the 128-bytes buffer, where the layout will be copied

Returned value:

  * function does not return value

Or:

  * eax = 26 - function number
  * ebx = 2 - subfunction number
  * ecx = 9

Returned value:

  * eax = country identifier (1=eng, 2=fi, 3=ger, 4=rus)

Remarks:

  * If Alt is pressed, the layout with Alt is used; if Alt is not pressed, but Shift is pressed, the layout with Shift is used; if Alt and Shift are not pressed, but Ctrl is pressed, the normal layout is used and then from the code is subtracted 0x60; if no control key is pressed, the normal layout is used.
  * To set layout and country identifier use function 21.2.
  * Country identifier is global system variable, which is not used by the kernel itself; however the application '@panel' displays the corresponding icon (using this function).
  * The application @panel switches layouts on user request.

### Function 26.3: Get CD Base

Parameters:

  * eax = 26 - function number
  * ebx = 3 - subfunction number

Returned value:

  * eax = CD base: 1=IDE0, 2=IDE1, 3=IDE2, 4=IDE3

Remarks:

  * CD base is used by function 24.
  * To set CD base use function 21.3.

### Function 26.5: Get System Language

Parameters:

  * eax = 26 - function number
  * ebx = 5 - subfunction number

Returned value:

  * eax = system language (1=eng, 2=fi, 3=ger, 4=rus)

Remarks:

  * System language is global system variable and is not used by the kernel itself, however application @panel draws the appropriate icon (using this function).
  * To set system language use function 21.5.

### Function 26.7: Get HD Base

The HD base defines hard disk to write with usage of obsolete syntax /HD in obsolete function 58; at usage of modern syntax /HD0,/HD1,/HD2,/HD3 base is set automatically.

Parameters:

  * eax = 26 - function number
  * ebx = 7 - subfunction number

Returned value:

  * eax = HD base: 1=IDE0, 2=IDE1, 3=IDE2, 4=IDE3

Remarks:

  * Any application in any time can change HD base.
  * To set base use function 21.7.
  * To get used partition of hard disk use function 26.8.

### Function 26.8: Get Used HD Partition

The HD partition defines partition of the hard disk to write with usage of obsolete syntax /HD in obsolete function 58; at usage of functions 58 and 70 and modern syntax /HD0,/HD1,/HD2,/HD3 base and partition are set automatically.

Parameters:

  * eax = 26 - function number
  * ebx = 8 - subfunction number

Returned value:

  * eax = HD partition (beginning from 1)

Remarks:

  * Any application in any time can change partition.
  * To set partition use function 21.8.
  * To get number of partitions on a hard disk use function 18.11.
  * To get base of used hard disk, use function 26.7.


### Function 26.9: Get the Value of the Time Counter

Parameters:

  * eax = 26 - function number
  * ebx = 9 - subfunction number

Returned value:

  * eax = number of 1/100s of second, past from the system boot time

Remarks:

  * Counter takes modulo 2^32, that correspond to a little more than 497 days.
  * To get system time use function 3.

### Function 26.11: Find Out Whether Low-Level HD Access is Enabled

Parameters:

  * eax = 26 - function number
  * ebx = 11 - subfunction number

Returned value:

  * eax = 0/1 - disabled/enabled

Remarks:

  * Is used in LBA read (function 58.8).
  * To set current state use function 21.11.

### Function 26.12: Find Out Whether Low-Level PCI Access is Enabled

Parameters:

  * eax = 26 - function number
  * ebx = 12 - subfunction number

Returned value:

  * eax = 0/1 - disabled/enabled

Remarks:

  * Is used by operations with PCI bus (function 62).
  * The current implementation uses only low bit of ecx.
  * To set the current state use function 21.12.

## Function 29: Get System Date

Parameters:

  * eax = 29 - function number

Returned value:

  * eax = 0x00DDMMYY, where (binary-decimal coding, BCD, is used)
  * YY = two low digits of year (00..99)
  * MM = month (01..12)
  * DD = day (01..31)

Remarks:

  * To set system date use function 22.

## Function Group 30: Work With the Current Folder

### Function 30.1: Set Current Folder for the Thread

Parameters:

  * eax = 30 - function number
  * ebx = 1 - subfunction number
  * ecx = pointer to ASCIIZ-string with the path to new current folder

Returned value:

  * function does not return value

### Function 30.2: Get Current Folder for the Thread

Parameters:

  * eax = 30 - function number
  * ebx = 2 - subfunction number
  * ecx = pointer to buffer
  * edx = size of buffer

Returned value:

  * eax = size of the current folder's name (including terminating 0)

Remarks:

  * If the buffer is too small to hold all data, only first (edx-1) bytes are copied and than terminating 0 is inserted.
  * By default, current folder for the thread is "/rd/1".
  * At process/thread creation the current folder will be inherited from the parent.

## Function 35: Read the Color of a Pixel on the Screen

Parameters:

  * eax = 35
  * ebx = y*xsize+x, where
  * (x,y) = coordinates of a pixel (beginning from 0)
  * xsize = horizontal screen size

Returned value:

  * eax = color 0x00RRGGBB

Remarks:

  * To get screen sizes use function 14. Pay attention, that it subtracts 1 from both sizes.
  * There is also direct access (without any system calls) to videomemory through the selector gs. To get parameters of the current videomode, use function 61.

## Function 36: Read Screen Area

Parameters:

  * eax = 36 - function number
  * ebx = pointer to the previously allocated memory area, where will be placed the image in the format BBGGRRBBGGRR...
  * ecx = [size on axis x]*65536 + [size on axis y]
  * edx = [coordinate on axis x]*65536 + [coordinate on axis y]

Returned value:

  * function does not return value

Remarks:

  * Coordinates of the image are coordinates of the upper left corner of the image relative to the screen.
  * Size of the image in bytes is 3*xsize*ysize.

## Function Group 37: Work With Mouse

### Function 37.0: Screen Coordinates of the Mouse

Parameters:

  * eax = 37 - function number
  * ebx = 0 - subfunction number

Returned value:

  * eax = x*65536 + y, (x,y)=coordinates of the mouse pointer (beginning from 0)

### Function 37.1: Coordinates of the Mouse Relative to the Window

Parameters:

  * eax = 37 - function number
  * ebx = 1 - subfunction number

Returned value:

  * eax = x*65536 + y, (x,y)=coordinates of the mouse pointer relative to the application window (beginning from 0)

Remarks:

  * The value is calculated by formula (x-xwnd)*65536 + (y-ywnd). If y>=ywnd, the low word is non-negative and contains relative y-coordinate, and the high word - relative x-coordinate (with correct sign). Otherwise the low word is negative and still contains relative y-coordinate, and to the high word 1 should be added.

### Function 37.2: Pressed Buttons of the Mouse

Parameters:

  * eax = 37 - function number
  * ebx = 2 - subfunction number

Returned value:

  * eax contains information on the pressed mouse buttons:
    * bit 0 is set = left button is pressed
    * bit 1 is set = right button is pressed
    * bit 2 is set = middle button is pressed
    * bit 3 is set = 4th button is pressed
    * bit 4 is set = 5th button is pressed
    * other bits are cleared

### Function 37.4: Load Cursor

Parameters:

  * eax = 37 - function number
  * ebx = 4 - subfunction number
  * dx = data source:
  * dx = LOAD_FROM_FILE = 0 - data in a file
    * ecx = pointer to full path to the cursor file
    * the file must be in the format .cur, which is standard for MS Windows, at that of the size 32*32 pixels
  * dx = LOAD_FROM_MEM = 1 - data of file are already loaded in memory
    * ecx = pointer to data of the cursor file
    * the data format is the same as in the previous case
  * dx = LOAD_INDIRECT = 2 - data in memory
    * ecx = pointer to cursor image in the format ARGB 32*32 pixels
    * edx = 0xXXYY0002, where
      * XX = x-coordinate of cursor hotspot
      * YY = y-coordinate
      * 0 <= XX, YY <= 31

Returned value:

  * eax = 0 - failed
  * otherwise eax = cursor handle

### Function 37.5: Set Cursor

Sets new cursor for the window of the current thread.

Parameters:

  * eax = 37 - function number
  * ebx = 5 - subfunction number
  * ecx = cursor handle

Returned value:

  * eax = handle of previous cursor

Remarks:

  * If the handle is incorrect, the function restores the default cursor (standard arrow). In particular, ecx=0 restores it.

### Function 37.6: Delete Cursor

Parameters:

  * eax = 37 - function number
  * ebx = 6 - subfunction number
  * ecx = cursor handle

Returned value:

  * eax destroyed

Remarks:

  * The cursor must be loaded previously by the current thread (with the call to function 37.4). The function does not delete system cursors and cursors, loaded by another applications.
  * If the active cursor (set by function 37.5) is deleted, the system restores the default cursor (standard arrow).

### Function 37.7: Get Scroll Data

Parameters:

  * eax = 37 - function number
  * ebx = 7 - subfunction number

Returned value:

  * eax = [horizontal offset]*65536 + [vertical offset]

Remarks:

  * Scroll data is available for active window only.
  * Values are zeroed after reading.
  * Values are signed.

## Function 38: Draw Line

Parameters:

  * eax = 38 - function number
  * ebx = [start coordinate on axis x]*65536 + [end coordinate on axis x]
  * ecx = [start coordinate on axis y]*65536 + [end coordinate on axis y]
  * edx = 0x00RRGGBB - color; edx = 0x01xxxxxx - draw inversed line (low 24 bits are ignored)

Returned value:

  * function does not return value

Remarks:

  * Coordinates are relative to the window.
  * End point is also drawn.

## Function Group 39: Get Background Image

### Function 39.1: Get a Size of the Background Image

Parameters:

  * eax = 39 - function number
  * ebx = 1 - subfunction number

Returned value:

  * eax = [width]*65536 + [height]

Remarks:

  * There is a pair function to set sizes of background image - function 15.1. After which it is necessary, of course, anew to define image.

### Function 39.2: Get Pixel from the Background Image

Parameters:

  * eax = 39 - function number
  * ebx = 2 - subfunction number
  * ecx = offset

Returned value:

  * eax = 0x00RRGGBB - pixel color, if offset is valid (less than 0x160000-16)
  * eax = 2 otherwise

Remarks:

  * Do not rely on returned value for invalid offsets, it may be changed in future kernel versions.
  * Offset for pixel with coordinates (x,y) is calculated as (x+y*xsize)*3.
  * There is a pair function to set pixel on the background image - function 15.2.

### Function 39.4: Get Drawing Mode for the Background

Parameters:

  * eax = 39 - function number
  * ebx = 4 - subfunction number

Returned value:

  * eax = 1 - tile
  * eax = 2 - stretch

Remarks:

  * There is a pair function to set drawing mode - function 15.4.

## Function 40: Set the Mask for Expected Events

The mask for expected events affects function working with events 10, 11, 23 - they notify only about events allowed by this mask.

Parameters:

  * eax = 40 - function number
  * ebx = mask: bit i corresponds to event i+1 (see list of events) (set bit permits notice on event)

Returned value:

  * eax = previous value of mask

Remarks:

  * Default mask (7=111b) enables nofices about redraw, keys and buttons. This is enough for many applications.
  * Events prohibited in the mask are saved anyway, when come; they are simply not informed with event functions.
  * Event functions take into account the mask on moment of function call, not on moment of event arrival.

## Function Group 43: Input/Output to a Port

### Output Data to Port

Parameters:

  * eax = 43 - function number
  * bl = byte for output
  * ecx = port number 0xnnnn (from 0 to 0xFFFF)

Returned value:

  * eax = 0 - success
  * eax = 1 - the thread has not reserved the selected port

### Input Data from Port

Parameters:

  * eax = 43 - function number
  * ebx is ignored
  * ecx = 0x8000nnnn, where nnnn = port number (from 0 to 0xFFFF)

Returned value:

  * eax = 0 - success, thus ebx = entered byte
  * eax = 1 - the thread has not reserved the selected port

Remarks:

  * Previously the thread must reserve the selected port for itself by function 46.
  * Instead of call to this function it is better to use processor instructions in/out - this is much faster and a bit shorter and easier.

## Function 46: Reserve/Free a Group of Input/Output Ports

To work with reserved ports an application can access directly by commands in/out (recommended way) and can use function 43 (not recommended way).

Parameters:

  * eax = 46 - function number
  * ebx = 0 - reserve, 1 - free
  * ecx = start port number
  * edx = end port number (inclusive)

Returned value:

  * eax = 0 - success
  * eax = 1 - error

Remarks:

  * For ports reservation: an error occurs if and only if
    one from the following condition satisfies:
    * start port is more than end port;
    * the selected range contains incorrect port number (correct are from 0 to 0xFFFF);
    * limit for the total number of reserved areas is exceeded (maximum 255 are allowed);
    * the selected range intersects with any of earlier reserved
  * For ports free: an error is an attempt to free range, that was not earlier reserved by this function (with same ecx,edx).
  * If an error occurs (for both cases) function performs no action.
  * At booting the system reserves for itself ports 0..0x2d, 0x30..0x4d, 0x50..0xdf, 0xe5..0xff (inclusively).
  * When a thread terminates, all reserved by it ports are freed automatically.

## Function 47: Draw a Number in the Window

Parameters:

  * eax = 47 - function number
  * ebx = parameters of conversion number to text:
    * bl = 0 - ecx contains number
    * bl = 1 - ecx contains pointer to dword/qword-number
    * bh = 0 - display in decimal number system
    * bh = 1 - display in hexadecimal system
    * bh = 2 - display in binary system
    * bits 16-21 = how many digits to display
    * bits 22-29 reserved and must be set to 0
    * bit 30 set = display qword (64-bit) number (must be bl=1)
    * bit 31 set = do not display leading zeroes of the number
  * ecx = number (if bl=0) or pointer (if bl=1)
  * edx = [coordinate on axis x]*65536 + [coordinate on axis y]
  * esi = 0xX0RRGGBB:
    * RR, GG, BB specify the color
    * X = ABnn (bits)
      * nn = font (0/1)
      * A is ignored
      * B=1 - fill background with the color edi

Returned value:

  * function does not return value

Remarks:

  * The given length must not exceed 60.
  * The exactly given amount of digits is output. If number is small and can be written by smaller amount of digits, it is supplemented by leading zeroes; if the number is big and can not be written by given amount of digits, extra digits are not drawn.
  * Parameters of fonts are shown in the description of function 4 (text output).

## Function Group 48: Display Settings

### Function 48.0: Apply Screen Settings

Parameters:

  * eax = 48 - function number
  * ebx = 0 - subfunction number
  * ecx = 0 - reserved

Returned value:

  * function does not return value

Remarks:

  * Function redraws the screen after parameters change by functions 48.1 and 48.2.
  * Function call without prior call to one of indicated functions is ignored.
  * Function call with nonzero ecx is ignored.

### Function 48.1: Set Button Style

Parameters:

  * eax = 48 - function number
  * ebx = 1 - subfunction number
  * ecx = button style:
    * 0 = flat
    * 1 = 3d

Returned value:

  * function does not return value

Remarks:

  * After call to this function one should redraw the screen by function 48.0.
  * Button style influences only to their draw of function 8.

### Function 48.2: Set Standard Window Colors

Parameters:

  * eax = 48 - function number
  * ebx = 2 - subfunction number
  * ecx = pointer to the color table
  * edx = size of the color table (must be 40 bytes for future compatibility)

Format of the color table is shown in description of function 48.3.

Returned value:

  * function does not return value

Remarks:

  * After call to this function one should redraw the screen by function 48.0.
  * Table of standard colors influences only to applications, which receive this table obviously (by function 48.3) and use it (specifying colors from it to drawing functions).
  * Table of standard colors is included in skin and is installed anew with skin installation (by function 48.8).
  * Color table can be viewed/changed interactively with the application 'desktop'.

### Function 48.3: Get Standard Window Colors

Parameters:

  * eax = 48 - function number
  * ebx = 3 - subfunction number
  * ecx = pointer to the buffer with size edx bytes, where table will be written
  * edx = size of color table (must be 40 bytes for future compatibility)

Returned value:

  * function does not return value

Format of the color table (each item is dword-value for color 0x00RRGGBB):

  * +0: dword: frames - color of frame
  * +4: dword: grab - color of header
  * +8: dword: grab_button - color of button on header bar
  * +12 = +0xC: dword: grab_button_text - color of text on button on header bar
  * +16 = +0x10: dword: grab_text - color of text on header
  * +20 = +0x14: dword: work - color of working area
  * +24 = +0x18: dword: work_button - color of button in working area
  * +28 = +0x1C: dword: work_button_text - color of text on button in working area
  * +32 = +0x20: dword: work_text - color of text in working area
  * +36 = +0x24: dword: work_graph - color of graphics in working area

Remarks:

  * Structure of the color table is described in the standard
    include file 'macros.inc' as 'system_colors'; for example,
    it is possible to write:

        sc system_colors ; variable declaration
        ... ; somewhere one must call this function with ecx=sc
        mov ecx, [sc.work_button_text] ; read text color on button in working area

  * A program itself desides to use or not to use color table. For usage program must simply at calls to drawing functions select color taken from the table.
  * At change of the table of standard colors (by function 48.2 with the subsequent application of changes by function 48.0 or at skin set by function 48.8) the system sends to all windows redraw message (the event with code 1).
  * Color table can be viewed/changed interactively with the application 'desktop'.

### Function 48.4: Get Skin Height

Parameters:

  * eax = 48 - function number
  * ebx = 4 - subfunction number

Returned value:

  * eax = skin height

Remarks:

  * Skin height is defined as the height of a header of skinned windows.
  * See also general structure of window in the description of function 0.

### Function 48.5: Get Screen Working Area

Parameters:

  * eax = 48 - function number
  * ebx = 5 - subfunction number

Returned value:

  * eax = [left]*65536 + [right]
  * ebx = [top]*65536 + [bottom]

Remarks:

  * The screen working area defines position and coordinates of a maximized window.
  * The screen working area in view of normal work is all screen without system panel (the application '@panel').
  * (left,top) are coordinates of the left upper corner, (right,bottom) are coordinates of the right lower one. Thus the size of working area on x axis can be calculated by formula right-left+1, on y axis - by formula bottom-right+1.
  * See also function 14, to get sizes of all screen.
  * There is a pair function to set working area - function 48.6.


### Function 48.6: Set Screen Working Area

Parameters:

  * eax = 48 - function number
  * ebx = 6 - subfunction number
  * ecx = [left]*65536 + [right]
  * edx = [top]*65536 + [bottom]

Returned value:

  * function does not return value

Remarks:

  * The screen working area defines position and coordinates of a maximized window.
  * This function is used only by the application '@panel', which set working area to all screen without system panel.
  * (left,top) are coordinates of the left upper corner, (right,bottom) are coordinates of the right lower one. Thus the size of working area on x axis can be calculated by formula right-left+1, on y axis - by formula bottom-right+1.
  * If 'left'>='right', x-coordinate of working area is not changed. If 'left'<0, 'left' will not be set. If 'right' is greater than or equal to screen width, 'right' will not be set. Similarly on y axis.
  * See also function 14, to get sizes of all screen.
  * There is a pair function to get working area - function 48.5.
  * This function redraws the screen automatically, updating coordinates and sizes of maximized windows. The system sends to all windows redraw message (the event 1).

### Function 48.7: Get Skin Margins

Returns the area of a header of a skinned window, intended for a text of a header.

Parameters:

  * eax = 48 - function number
  * ebx = 7 - subfunction number

Returned value:

  * eax = [left]*65536 + [right]
  * ebx = [top]*65536 + [bottom]

Remarks:

  * An application decides itself to use or not to use this function.
  * It is recommended to take into account returned value of this function for choice of a place for drawing header text (by function 4) or a substitute of header text (at the discretion of an application).

### Function 48.8: Set Used Skin

Parameters:

  * eax = 48 - function number
  * ebx = 8 - subfunction number
  * ecx = pointer to a block for function 58, in which the fields of intermediate buffer and file name are filled

Returned value:

  * eax = 0 - success
  * otherwise eax = file system error code; if file does not contain valid skin, function returns error 3 (unknown file system).

Remarks:

  * After successful skin loading the system sends to all windows redraw message (the event 1).
  * At booting the system reads skin from file 'default.skn' on ramdisk.
  * User can change the skin statically by creating hisself 'default.skn' or dynamically with the application 'desktop'.

## Function 49: Advanced Power Management (APM)

Parameters:

  * eax = 49 - function number
  * dx = number of the APM function (analogue of ax in APM specification)
  * bx, cx = parameters of the APM function

Returned value:

  * 16-bit registers ax, bx, cx, dx, si, di and carry flag CF are set according to the APM specification
  * high halves of 32-bit registers eax, ebx, ecx, edx, esi, edi are destroyed

Remarks:

  * APM 1.2 specification is described in the document [Advanced Power Management (APM) BIOS Specification](http://www.microsoft.com/whdc/archive/amp_12.mspx) (Revision 1.2); besides it is included in famous [Interrupt List](http://www.cs.cmu.edu/~ralf/files.html) by Ralf Brown.

## Function Group 50: Set Window Shape

Normal windows have rectangular shape. This function can give to a window any shape. The shape is given by a set of points inside the base rectangle belonging to a window. Position and coordinates of the base rectangle are set by function 0 and changed by function 67.

### Function 50.0: Set Shape Data

Parameters:

  * eax = 50 - function number
  * ebx = 0 - subfunction number
  * ecx = pointer to shape data (array of bytes 0/1)

Returned value:

  * function does not return value

### Function 50.1: Set Shape Scale

Parameters:

  * eax = 50 - function number
  * ebx = 1 - subfunction number
  * ecx sets a scale: each byte of data defines (2^scale)*(2^scale) pixels

Returned value:

  * function does not return value

Remarks:

  * Default scale is 0 (scale factor is 1). If in the shape data one byte corresponds to one pixel, there is no necessity to set scale.
  * Let's designate xsize = window width (in pixels), ysize = height; pay attention, that they are one pixel more than defined by functions 0, 67.
  * On definition of scale xsize and ysize must be divisible on 2^scale.
  * Byte of data on offset 'a' must be 0/1 and defines belonging to a window of square with the side 2^scale (if scale=0, this is one pixel) and coordinates of the left upper corner (a mod (xsize shr scale), a div (xsize shr scale))
  * Data size: (xsize shr scale)*(ysize shr scale).
  * Data must be presented in the memory and not change after set of shape.
  * The system views the shape data at every window redraw by function 0.
  * The call of function 50.0 with NULL pointer results in return to the rectangular shape.

## Function 51: Create Thread

Parameters:

  * eax = 51 - function number
  * ebx = 1 - unique subfunction
  * ecx = address of thread entry point (starting eip)
  * edx = pointer to thread stack (starting esp)

Returned value:

  * eax = -1 - error (there is too many threads)
  * otherwise eax = TID - thread identifier

## Function Group 52: Network Driver Status

### Function 52.0: Get Network Driver Configuration

Parameters:

  * eax = 52 - function number
  * ebx = 0 - subfunction number

Returned value:

  * eax = configuration dword

Remarks:

  * Configuration dword can be set by function 52.2.
  * The kernel does not use this variable. The value of this variable and working with it functions 52.0 and 52.2 is represented doubtful.

### Function 52.1: Get Local IP Address

Parameters:

  * eax = 52 - function number
  * ebx = 1 - subfunction number

Returned value:

  * eax = IP-address (4 bytes)

Remarks:

  * Local IP-address is set by function 52.3.

### Function 52.2: Set Network Driver Configuration

Parameters:

  * eax = 52 - function number
  * ebx = 2 - subfunction number
  * ecx = configuration dword; if low 7 bits derivate the number 3, function [re-]initializes Ethernet-card, otherwise Ethernet turns off

Returned value:

  * if Ethernet-interface is not requested, function returns eax=2, but this can be changed in future kernel versions
  * if Ethernet-interface is requested, eax=0 means error (absence of Ethernet-card), and nonzero value - success

Remarks:

  * Configuration dword can be read by function 52.0.
  * The kernel does not use this variable. The value of this variable, function 52.0 and part of function 52.2, which set it, is represented doubtful.

### Function 52.3: Set Local IP Address

Parameters:

  * eax = 52 - function number
  * ebx = 3 - subfunction number
  * ecx = IP-address (4 bytes)

Returned value:

  * the current implementation returns eax=3, but this can be changed in future versions

Remarks:

  * Local IP-address can be get by function 52.1.

### Function 52.6: Add Data to the Stack of Input Queue

Parameters:

  * eax = 52 - function number
  * ebx = 6 - subfunction number
  * edx = data size
  * esi = data pointer

Returned value:

  * eax = -1 - error
  * eax = 0 - success

Remarks:

  * This function is intended only for slow network drivers (PPP, SLIP).
  * Data size must not exceed 1500 bytes, though function performs no checks on correctness.

### Function 52.8: Read Data from the Network Output Queue

Parameters:

  * eax = 52 - function number
  * ebx = 8 - subfunction number
  * esi = pointer to 1500-byte buffer

Returned value:

  * eax = number of read bytes (in the current implementation either 0 = no data or 1500)
  * data was copied in buffer

Remarks:

  * This function is intended only for slow network drivers (PPP, SLIP).

### Function 52.9: Get Gateway IP

Parameters:

  * eax = 52 - function number
  * ebx = 9 - subfunction number

Returned value:

  * eax = gateway IP (4 bytes)

### Function 52.10: Get Subnet Mask

Parameters:

  * eax = 52 - function number
  * ebx = 10 - subfunction number

Returned value:

  * eax = subnet mask

### Function 52.11: Set Gateway IP

Parameters:

  * eax = 52 - function number
  * ebx = 11 - subfunction number
  * ecx = gateway IP (4 bytes)

Returned value:

  * the current implementation returns eax=11, but this can be changed in future versions

### Function 52.12: Set Subnet Mask

Parameters:

  * eax = 52 - function number
  * ebx = 12 - subfunction number
  * ecx = subnet mask

Returned value:

  * the current implementation returns eax=12, but this can be changed in future versions

### Function 52.13: Get DNS IP

Parameters:

  * eax = 52 - function number
  * ebx = 13 - subfunction number

Returned value:

  * eax = DNS IP (4 bytes)

### Function 52.14: Set DNS IP

Parameters:

  * eax = 52 - function number
  * ebx = 14 - subfunction number
  * ecx = DNS IP (4 bytes)

Returned value:

  * the current implementation returns eax=14, but this can be changed in future versions

### Function 52.15: Get Local MAC Address

Parameters:

  * eax = 52 - function number
  * ebx = 15 - subfunction number
  * ecx = 0 - read first 4 bytes, ecx = 4 - read last 2 bytes

Returned value:

  * for ecx=0: eax = first 4 bytes of MAC address
  * for ecx=4: ax = last 2 bytes of MAC address, high half of eax is destroyed
  * for other ecx: eax = -1 indicates an error

## Function Group 53: Network Sockets

### Function 53.0: Open UDP Socket

Parameters:

  * eax = 53 - function number
  * ebx = 0 - subfunction number
  * ecx = local port (only low word is taken into account), ecx = 0 - let the system choose a port
  * edx = remote port (only low word is taken into account)
  * esi = remote IP

Returned value:

  * eax = -1 = 0xFFFFFFFF - error; ebx destroyed
  * eax = socket handle (some number which unambiguously identifies socket and have sense only for the system) - success; ebx destroyed

### Function 53.1: Close UDP Socket

Parameters:

  * eax = 53 - function number
  * ebx = 1 - subfunction number
  * ecx = socket handle

Returned value:

  * eax = -1 - incorrect handle
  * eax = 0 - success
  * ebx destroyed

Remarks:

  * The current implementation does not close automatically all sockets of a thread at termination. In particular, one should not kill a thread with many opened sockets - there will be an outflow of resources.

### Function 53.2: Poll Socket

Parameters:

  * eax = 53 - function number
  * ebx = 2 - subfunction number
  * ecx = socket handle

Returned value:

  * eax = number of read bytes, 0 for incorrect handle
  * ebx destroyed

### Function 53.3: Read Byte from Socket

Parameters:

  * eax = 53 - function number
  * ebx = 3 - subfunction number
  * ecx = socket handle

Returned value:

  * if there is no read data or handle is incorrect: eax=0, bl=0, other bytes of ebx are destroyed
  * if there are read data: eax=number of rest bytes (possibly 0), bl=read byte, other bytes of ebx are destroyed

### Function 53.4: Write to UDP Socket

Parameters:

  * eax = 53 - function number
  * ebx = 4 - subfunction number
  * ecx = socket handle
  * edx = number of bytes to write
  * esi = pointer to data to write

Returned value:

  * eax = 0xffffffff - error (invalid handle or not enough memory)
  * eax = 0 - success
  * ebx destroyed

Remarks:

  * Number of bytes to write must not exceed 1500-28, though the appropriate check is not made.

### Function 53.5: Open TCP Socket

Parameters:

  * eax = 53 - function number
  * ebx = 5 - subfunction number
  * ecx = local port (only low word is taken into account), ecx = 0 - let the system choose a port
  * edx = remote port (only low word is taken into account)
  * esi = remote IP
  * edi = open mode: SOCKET_PASSIVE=0 or SOCKET_ACTIVE=1

Returned value:

  * eax = -1 = 0xFFFFFFFF - error; ebx destroys
  * eax = socket handle (some number which unambiguously identifies socket and have sense only for the system) - success; ebx destroyed

### Function 53.6: Get TCP Socket Status

Parameters:

  * eax = 53 - function number
  * ebx = 6 - subfunction number
  * ecx = socket handle

Returned value:

  * eax = 0 for incorrect handle or socket status: one of
    * TCB_LISTEN = 1
    * TCB_SYN_SENT = 2
    * TCB_SYN_RECEIVED = 3
    * TCB_ESTABLISHED = 4
    * TCB_FIN_WAIT_1 = 5
    * TCB_FIN_WAIT_2 = 6
    * TCB_CLOSE_WAIT = 7
    * TCB_CLOSING = 8
    * TCB_LAST_ASK = 9
    * TCB_TIME_WAIT = 10
    * TCB_CLOSED = 11
  * ebx destroyed

### Function 53.7: Write to TCP Socket

Parameters:

  * eax = 53 - function number
  * ebx = 7 - subfunction number
  * ecx = socket handle
  * edx = number of bytes to write
  * esi = pointer to data to write

Returned value:

  * eax = 0xffffffff - error (invalid handle or not enough memory)
  * eax = 0 - success
  * ebx destroyed

Remarks:

  * Number of bytes to write must not exceed 1500-40, though the appropriate check is not made.

### Function 53.8: Close TCP Socket

Parameters:

  * eax = 53 - function number
  * ebx = 8 - subfunction number
  * ecx = socket handle

Returned value:

  * eax = -1 - error (invalid handle or not enough memory for socket close packet)
  * eax = 0 - success
  * ebx destroyed

Remarks:

  * The current implementation does not close automatically all sockets of a thread at termination. In particular, one should not kill a thread with many opened sockets - there will be an outflow of resources.

### Function 53.9: Check Whether Local Port is Free

Parameters:

  * eax = 53 - function number
  * ebx = 9 - subfunction number
  * ecx = local port number (low 16 bits are used only)

Returned value:

  * eax = 0 - port is used
  * eax = 1 - port is free
  * ebx destroyed

### Function 53.10: Query Ethernet Cable Status

Parameters:

  * eax = 53 - function number
  * ebx = 10 - subfunction number

Returned value:

  * al = -1 - a network driver is not loaded or does not support this function
  * al = 0 - Ethernet cable is unplugged
  * al = 1 - Ethernet cable is plugged
  * ebx destroyed

Remarks:

  * The current kernel implementation supports this function only for RTL8139 network cards.

### Function 53.11: Read Network Stack Data

Parameters:

  * eax = 53 - function number
  * ebx = 11 - subfunction number
  * ecx = socket handle
  * edx = pointer to buffer
  * esi = number of bytes to read;
  * esi = 0 - read all data (maximum 4096 bytes)

Returned value:

  * eax = number of bytes read (0 for incorrect handle)
  * ebx destroyed


### Function 53.255: Debug Information of Network Driver

Parameters:

  * eax = 53 - function number
  * ebx = 255 - subfunction number
  * ecx = type of requested information (see below)

Returned value:

  * eax = requested information
  * ebx destroyed

Possible values for ecx:

  * 100: length of queue 0 (empty queue)
  * 101: length of queue 1 (ip-out queue)
  * 102: length of queue 2 (ip-in queue)
  * 103: length of queue 3 (net1out queue)
  * 200: number of items in the ARP table
  * 201: size of the ARP table (in items) (20 for current version)
  * 202: read item at edx of the ARP table to the temporary buffer, whence 5 following types take information; in this case eax is not defined
  * 203: IP-address saved by type 202
  * 204: high dword of MAC-address saved by type 202
  * 205: low word of MAC-address saved by type 202
  * 206: status word saved by type 202
  * 207: ttl word saved by type 202
  * 2: total number of received IP-packets
  * 3: total number of transferred IP-packets
  * 4: total number of dumped received packets
  * 5: total number of received ARP-packets
  * 6: status of packet driver, 0=inactive, nonzero=active

## Function Group 55: Sound Control

### Function 55.55: Begin to Play Data on Built-In Speaker

Parameters:

  * eax = 55 - function number
  * ebx = 55 - subfunction number
  * esi = pointer to data

Returned value:

  * eax = 0 - success
  * eax = 55 - error (speaker is off or busy)

Data is an array of items with variable length.

Format of each item is defined by first byte:

  * 0 = end of data
  * 1..0x80 = sets sound duration on 1/100 of second; sound note is defined by immediate value of frequency; following word (2 bytes) contains frequency divider; frequency is defined as 1193180/divider
  * 0x81 = invalid
  * 0x82..0xFF = note is defined by octave and number:
    * duration in 1/100 of second = (first byte)-0x81
    * there is one more byte;
    * (second byte)=0xFF - delay
    * otherwise it looks like a*0x10+b, where b=number of the note in an octave from 1 to 12, a=number of octave (beginning from 0)

Remarks:

  * Speaker play can be disabled/enabled by function 18.8.
  * Function returns control, having informed the system an information on request. Play itself goes independently from the program.
  * The data must be kept in the memory at least up to the end of play.

## Function 57: PCI BIOS

Parameters:

  * eax = 57 - function number
  * ebp corresponds to al in PCI BIOS specification
  * other registers are set according to PCI BIOS specification

Returned value:

  * CF is undefined
  * other registers are set according to PCI BIOS specification

Remarks:

  * Many effects of this function can be also achieved with corresponding functions of function group 62.
  * The function calls PCI32 BIOS extension, documented e.g. in http://alpha1.dyns.net/files/PCI/bios21.pdf.
  * If BIOS does not support this extension, its behavior is emulated (through kernel-mode analogues of functions of function group 62).

## Function Group 58: Work With File System

Parameters:

  * eax = 58
  * ebx = pointer to the information structure

Returned value:

  * eax = 0 - success; otherwise file system error code
  * some subfunctions return value in other registers too

General format of the information structure:

  * +0: dword: subfunction number
  * +4: dword: number of block
  * +8: dword: size
  * +12 = +0xC: dword: pointer to data
  * +16 = +0x10: dword: pointer to a memory for system operations (4096 bytes)
  * +20 = +0x14: n db: ASCIIZ-string with the file name

Specifications - in documentation on the appropriate subfunction. Filename is case-insensitive for latin letters, russian letters must be capital.

Format of filename:

    /base/number/dir1/dir2/.../dirn/file,

where /base/number identifies device on which file is located one of:

  * /RD/1 = /RAMDISK/1 to access ramdisk
  * /FD/1 = /FLOPPYDISK/1 to access first floppy drive, /FD/2 = /FLOPPYDISK/2 to access second one
  * /HD/x = /HARDDISK/x - obsolete variant of access to hard disk (in this case base is defined by function 21.7), x - partition number (beginning from 1)
  * /HD0/x, /HD1/x, /HD2/x, /HD3/x to access accordingly to devices IDE0 (Primary Master), IDE1 (Primary Slave), IDE2 (Secondary Master), IDE3 (Secondary Slave); x - partition number on the selected hard drive, varies from 1 to 255 (on each hard drive the indexing starts from 1)

Remarks:

  * In the first two cases it is also possible to use FIRST instead of 1, SECOND instead of 2, but it is not recommended for convenience of transition to the future extensions.
  * Limitation n<=39 is imposed.
  * Names of folders and file dir1,...,dirn,file must have the format 8.3: name no more than 8 characters, dot, extension no more than 3 characters. Trailing spaces are ignored, no other spaces is allowed. If name occupies equally 8 characters, dot may be omitted (though it is not recommended to use this feature for convenience of transition to the future extensions).
  * This function does not support folders on ramdisk.

Examples:

  * '/RAMDISK/FIRST/KERNEL.ASM',0
  * '/rd/1/kernel.asm',0
  * '/HD0/1/kernel.asm',0
  * '/hd0/1/menuet/pics/tanzania.bmp',0

### Function 58.0: Read File/Folder

Parameters:

  * eax = 58
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 0 = subfunction number
  * +4: dword: first block to read (beginning from 0)
  * +8: dword: amount of blocks to read
  * +12 = +0xC: dword: pointer to buffer for data
  * +16 = +0x10: dword: pointer to buffer for system operations (4096 bytes)
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx = file size (in bytes) or -1=0xffffffff, if file was not found

Remarks:

  * Block size is 512 bytes.
  * This function is obsolete, for reading files use function 70.0, for reading folders - function 70.1.
  * Function can read contents of a folder. Only FAT file system is supported. The format of FAT-folder is described in any FAT documentation.
  * Size of a folder is determined by size of FAT clusters chain.
  * If file was ended before last requested block was read, the function will read as many as it can, and after that return eax=6 (EOF).
  * Function can read root folders /rd/1,/fd/x,/hd[n]/x, but in the first two cases the current implementation does not follow to the declared rules:

    For /rd/1:

    * if one want to read 0 blocks, function considers, that he requested 1;
    * if one requests more than 14 blocks or starting block is not less than 14, function returns eax=5 (not found) and ebx=-1;
    * size of ramdisk root folder is 14 blocks, 0x1C00=7168 bytes; but function returns ebx=0 (except of the case of previous item);
    * strangely enough, it is possible to read 14th block (which generally contains a garbage - I remind, the indexing begins from 0);
    * if some block with the number not less than 14 was requested, function returns eax=6(EOF); otherwise eax=0.

    For /fd/x:

    * if the start block is not less than 14, function returns eax=5 (not found) and ebx=0;
    * note that format of FAT12 allows floppies with the root size more or less than 14 blocks;
    * check for length is not performed;
    * if data was successful read, function returns eax=0,ebx=0; otherwise eax=10 (access denied), ebx=-1.

  * The function handles reading of special folders /,/rd,/fd,/hd[n]; but the result does not correspond to expected (on operations with normal files/folders), does not follow the declared rules, may be changed in future versions of the kernel and consequently is not described. To obtain the information about the equipment use function 18.11 or read corresponding folder with function 70.1.

### Function 58.8: LBA-Read from Device

Parameters:

  * eax = 58 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 8 = subfunction number
  * +4: dword: number of block to read (beginning from 0)
  * +8: dword: ignored (set to 1)
  * +12 = +0xC: dword: pointer to buffer for data (512 bytes)
  * +16 = +0x10: dword: pointer to buffer for system operations (4096 bytes)
  * +20 = +0x14: ASCIIZ-name of device: case-insensitive, one of /rd/1 = /RamDisk/1, /hd/n = /HardDisk/n, 1<=n<=4 - number of device: 1=IDE0, ..., 4=IDE3. Instead of digits it is allowed, though not recommended for convenience of transition to future extensions, to use 'first','second','third','fourth'.

Returned value:

  * for device name /hd/xxx, where xxx is not in the list above:
    * eax = ebx = 1
  * for invalid device name (except for the previous case):
    * eax = 5
    * ebx does not change
  * if LBA-access is disabled by function 21.11:
    * eax = 2
    * ebx destroyed
  * for ramdisk: attempt to read block outside ramdisk (18*2*80 blocks) results in
    * eax = 3
    * ebx = 0
  * for successful read:
    * eax = ebx = 0

Remarks:

  * Block size is 512 bytes; function reads one block.
  * Do not depend on returned value, it can be changed in future versions.
  * Function requires that LBA-access to devices is enabled by function 21.11. To check this one can use function 26.11.
  * LBA-read of floppy is not supported.
  * Function reads data on physical hard drive; if for any reason data of the concrete partition are required, application must define starting sector of this partition (either directly through MBR, or from the full structure returned by function 18.11).
  * Function does not check error code of hard disk, so request of nonexisting sector reads something (most probably it will be zeroes, but this is defined by device) and this is considered as success (eax=0).

### Function 58.15: Get Information on File System

Parameters:

  * eax = 58 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 15 = subfunction number
  * +4: dword: ignored
  * +8: dword: ignored
  * +12 = +0xC: dword: ignored
  * +16 = +0x10: dword: ignored
  * +20 = +0x14: (only second character is checked) /rd=/RAMDISK or /hd=/HARDDISK

Returned value:

  * if the second character does not belong to set {'r','R','h','H'}:
    * eax = 3
    * ebx = ecx = dword [fileinfo] = 0
  * for ramdisk:
    * eax = 0 (success)
    * ebx = total number of clusters = 2847
    * ecx = number of free clusters
    * dword [fileinfo] = cluster size = 512
  * for hard disk: base and partition are defined by functions 21.7 and 21.8:
    * eax = 0 (success)
    * ebx = total number of clusters
    * ecx = number of free clusters
    * dword [fileinfo] = cluster size (in bytes)

Remarks:

  * Be not surprised to strange layout of 4th returned parameter - when this code was writing, at system calls application got only registers eax,ebx,ecx (from pushad-structure transmitted as argument to the system function). Now it is corrected, so, probably, it is meaningful to return cluster size in edx, while this function is not used yet.
  * There exists also function 18.11, which returns information on file system. From the full table of disk subsystem it is possible to deduce cluster size (there it is stored in sectors) and total number of clusters for hard disks.

## Function Group 60: Interprocess Communication (IPC)

IPC is used for message dispatching from one process/thread to another. Previously it is necessary to agree how to interpret the concrete message.

### Function 60.1: Set the Area for IPC Receiving

Is called by process-receiver.

Parameters:

  * eax = 60 - function number
  * ebx = 1 - subfunction number
  * ecx = pointer to the buffer
  * edx = size of the buffer

Returned value:

  * eax = 0 - always success

Format of IPC-buffer:

  * +0: dword: if nonzero, buffer is considered locked; lock/unlock the buffer, when you work with it and need that buffer data are not changed from outside (no new messages)
  * +4: dword: occupied place in the buffer (in bytes)
  * +8: first message
  * +8+n: second message
  * ...

Format of a message:

  * +0: dword: PID of sender
  * +4: dword: message length (not including this header)
  * +8: n*byte: message data

### Function 60.2: Send IPC Message

Is called by process-sender.

Parameters:

  * eax = 60 - function number
  * ebx = 2 - subfunction number
  * ecx = PID of receiver
  * edx = pointer to the message data
  * esi = message length (in bytes)

Returned value:

  * eax = 0 - success
  * eax = 1 - the receiver has not defined buffer for IPC messages (can be, still have no time, and can be, this is not right process)
  * eax = 2 - the receiver has blocked IPC-buffer; try to wait a bit
  * eax = 3 - overflow of IPC-buffer of the receiver
  * eax = 4 - process/thread with such PID does not exist

Remarks:

  * Immediately after writing of IPC-message to the buffer the system sends to the receiver the event with code 7 (see event codes).

## Function Group 61: Get Parameters for the Direct Graphics Access

The data of the graphics screen (the memory area which displays screen contents) are accessible to a program directly, without any system calls, through the selector gs:

    mov eax, [gs:0]

places in eax the first dword of the buffer, which contains information on color of the left upper point (and, possibly, colors of several following).

    mov [gs:0], eax

by work in VESA modes with LFB sets color of the left upper point (and, possibly, colors of several following). To interpret the data of graphics screen program needs to know some parameters, returning by this function.

Remarks:

  * Graphics parameters changes very seldom at work, namely, only in cases, when user works with the application VRR.
  * At videomode change the system redraws all windows (event with code 1) and redraws the background (event 5). Same events occur in other cases too, which meet much more often, than videomode change.
  * By operation in videomodes with LFB the selector gs points to LFB itself, so reading/writing on gs result directly in change of screen contents. By operation in videomodes without LFB gs points to some data area in the kernel, and all functions of screen output fulfil honesty double operation on writing directly to the screen and writing to this buffer. In result at reading contents of this buffer the results correspond to screen contents (with, generally speaking, large color resolution), and writing is ignored. One exception is the mode 320*200, for which main loop of the system thread updates the screen according to mouse movements.

### Function 61.1: Screen Resolution

Parameters:

  * eax = 61 - function number
  * ebx = 1 - subfunction number

Returned value:

  * eax = [resolution on x axis]*65536 + [resolution on y axis]

Remarks:

  * One can use function 14 paying attention that it returns sizes on 1 pixel less. It is fully equivalent way.

### Function 61.2: Number of Bits per Pixel

Parameters:

  * eax = 61 - function number
  * ebx = 2 - subfunction number

Returned value:

  * eax = number of bits per pixel (24 or 32)

### Function 61.3: Number of Bytes per Scanline

Parameters:

  * eax = 61 - function number
  * ebx = 3 - subfunction number

Returned value:

  * eax = number of bytes occupied by one scanline (horizontal line on the screen)

## Function Group 62: PCI Control

### Function 62.0: Get Version of PCI Interface

Parameters:

  * eax = 62 - function number
  * bl = 0 - subfunction number

Returned value:

  * eax = -1 - PCI access is disabled; otherwise
  * ah.al = version of PCI-interface (ah=version, al=subversion)
  * high word of eax is zeroed

Remarks:

  * Previously low-level access to PCI for applications must be enabled by function 21.12.
  * If PCI BIOS is not supported, the value of ax is undefined.

### Function 62.1: Get Number of the Last PCI Bus

Parameters:

  * eax = 62 - function number
  * bl = 1 - subfunction number

Returned value:

  * eax = -1 - access to PCI is disabled; otherwise
  * al = number of the last PCI-bus; other bytes of eax are destroyed

Remarks:

  * Previously low-level access to PCI for applications must be enabled by function 21.12.
  * If PCI BIOS is not supported, the value of ax is undefined.

### Function 62.2: Get Mechanism of Addressing to the PCI Configuration Space

Parameters:

  * eax = 62 - function number
  * bl = 2 - subfunction number

Returned value:

  * eax = -1 - access to PCI is disabled; otherwise
  * al = mechanism (1 or 2); other bytes of eax are destroyed

Remarks:

  * Previously low-level access to PCI for applications must be enabled by function 21.12.
  * Addressing mechanism is selected depending on equipment characteristics.
  * Subfunctions of read and write work automatically with the selected mechanism.

### Functions 62.4-62.6: Read PCI Register

Parameters:

  * eax = 62 - function number
  * bl = 4 - read byte
  * bl = 5 - read word
  * bl = 6 - read dword
  * bh = number of PCI-bus
  * ch = dddddfff, where ddddd = number of the device on the bus, fff = function number of device
  * cl = number of register (must be even for bl=5, divisible by 4 for bl=6)

Returned value:

  * eax = -1 - error (access to PCI is disabled or parameters are not supported); otherwise
  * al/ax/eax (depending on requested size) contains the data; the other part of register eax is destroyed

Remarks:

  * Previously low-level access to PCI for applications must be enabled by function 21.12.
  * Access mechanism 2 supports only 16 devices on a bus and ignores function number. To get access mechanism use function 62.2.
  * Some registers are standard and exist for all devices, some are defined by the concrete device. The list of registers of the first type can be found e.g. in famous [Interrupt List](http://www.cs.cmu.edu/~ralf/files.html) by Ralf Brown; registers of the second type must be listed in the device documentation.

### Functions 62.8-62.10: Write to PCI Register

Parameters:

  * eax = 62 - function number
  * bl = 8 - write byte
  * bl = 9 - write word
  * bl = 10 - write dword
  * bh = number of PCI-bus
  * ch = dddddfff, where ddddd = number of the device on the bus, fff = function number of device
  * cl = number of register (must be even for bl=9, divisible by 4 for bl=10)
  * dl/dx/edx (depending on requested size) contatins the data to write

Returned value:

  * eax = -1 - error (access to PCI is disabled or parameters are not supported)
  * eax = 0 - success

Remarks:

  * Previously low-level access to PCI for applications must be enabled by function 21.12.
  * Access mechanism 2 supports only 16 devices on a bus and ignores function number. To get access mechanism use subfunction 62.2.
  * Some registers are standard and exist for all devices, some are defined by the concrete device. The list of registers of the first type can be found e.g. in famous [Interrupt List](http://www.cs.cmu.edu/~ralf/files.html) by Ralf Brown; registers of the second type must be listed in the device documentation.

## Function Group 63: Work With the Debug Board

The debug board is the global system buffer (with the size 1024 bytes), to which any program can write (generally speaking, arbitrary) data and from which other program can read these data. By the agreement written data are text strings interpreted as debug messages on a course of program execution. The kernel in some situations also writes to the debug board information on execution of some functions; by the agreement kernel messages begins from the prefix "K : ".

For view of the debug board the application 'board' was created, which reads data from the buffer and displays them in its window. 'board' interpretes the sequence of codes 13,10 as newline. A character with null code in an end of line is not necessary, but also does not prevent.

Because debugger has been written, the value of the debug board has decreased, as debugger allows to inspect completely a course of program execution without any efforts from the direction of program itself. Nevertheless in some cases the debug board is still useful.

### Function 63.1: Write Byte

Parameters:

  * eax = 63 - function number
  * ebx = 1 - subfunction number
  * cl = data byte

Returned value:

  * function does not return value

Remarks:

  * Byte is written to the buffer. Buffer size is 512 bytes. At buffer overflow all obtained data are lost.
  * For output to the debug board of more complicated objects (strings, numbers) it is enough to call this function in cycle. It is possible not to write the appropriate code manually and use file 'debug.inc', which is included into the distributive.

### Function 63.2: Read Byte

Takes away byte from the buffer.

Parameters:

  * eax = 63 - function number
  * ebx = 2 - subfunction number

Returned value:

  * eax = ebx = 0 - the buffer is empty
  * eax = byte, ebx = 1 - byte was successfully read

## Function 64: Resize Application Memory

Parameters:

  * eax = 64 - function number
  * ebx = 1 - unique subfunction
  * ecx = new memory size

Returned value:

  * eax = 0 - success
  * eax = 1 - not enough memory

Remarks:

  * There is another way to dynamically allocate/free memory - functions 68.11, 68.12, 68.13.
  * The function cannot be used together with 68.11, 68.12, 68.13. The function call will be ignored after creation of process heap with function 68.11.

## Function 65: Draw Image With Palette in the Window

Parameters:

  * eax = 65 - function number
  * ebx = pointer to the image
  * ecx = [size on axis x]*65536 + [size on axis y]
  * edx = [coordinate on axis x]*65536 + [coordinate on axis y]
  * esi = number of bits per pixel, must be 1,2,4,8,15,16,24 or 32
  * edi = pointer to palette (2 to the power esi colors 0x00RRGGBB);
          ignored when esi > 8
  * ebp = offset of next row data relative to previous row data

Returned value:

  * function does not return value

Remarks:

  * Coordinates of the image are coordinates of the upper left corner of the image relative to the window.
  * Format of image with 1 bit per pixel: each byte of image (possibly excluding last bytes in rows), contains information on the color of 8 pixels, MSB corresponds to first pixel.
  * Format of image with 2 bits per pixel: each byte of image (possibly excluding last bytes in rows), contains information on the color of 4 pixels, two MSBs correspond to first pixel.
  * Format of image with 4 bits per pixel: each byte of image excluding last bytes in rows (if width is odd) contains information on the color of 2 pixels, high-order tetrad corresponds to first pixel.
  * Format of image with 8 bits per pixel: each byte of image is index in the palette.
  * Format of image with 15 bits per pixel: the color of each pixel is coded as (bit representation) 0RRRRRGGGGGBBBBB - 5 bits per each color.
  * Format of image with 16 bits per pixel: the color of each pixel is coded as RRRRRGGGGGGBBBBB (5+6+5).
  * Format of image with 24 bits per pixel: the color of each pixel is coded as 3 bytes - sequentially blue, green, red components.
  * Format of image with 32 bits per pixel: similar to 24, but one additional ignored byte is present.
  * The call to function 7 is equivalent to call to this function with esi=24, ebp=0.

## Function Group 66: Work With Keyboard

The input mode influences results of reading keys by function 2. When a program loads, ASCII input mode is set for it.

### Function 66.1: Set Keyboard Input Mode

Parameters:

  * eax = 66 - function number
  * ebx = 1 - subfunction number
  * ecx = mode:
    * 0 = normal (ASCII-characters)
    * 1 = scancodes

Returned value:

  * function does not return value

### Function 66.2: Get Keyboard Input Mode

Parameters:

  * eax = 66 - function number
  * ebx = 2 - subfunction number

Returned value:

  * eax = current mode

### Function 66.3: Get Status of Control Keys

Parameters:

  * eax = 66 - function number
  * ebx = 3 - subfunction number

Returned value:

  * eax = bit mask:
    * bit 0 (mask 1): left Shift is pressed
    * bit 1 (mask 2): right Shift is pressed
    * bit 2 (mask 4): left Ctrl is pressed
    * bit 3 (mask 8): right Ctrl is pressed
    * bit 4 (mask 0x10): left Alt is pressed
    * bit 5 (mask 0x20): right Alt is pressed
    * bit 6 (mask 0x40): CapsLock is on
    * bit 7 (mask 0x80): NumLock is on
    * bit 8 (mask 0x100): ScrollLock is on
    * other bits are cleared

### Function 66.4: Set System-Wide Hotkey

When hotkey is pressed, the system notifies only those applications, which have installed it; the active application (which receives all normal input) does not receive such keys. The notification consists in sending event with the code 2. Reading hotkey is the same as reading normal key - by function 2.

Parameters:

  * eax = 66 - function number
  * ebx = 4 - subfunction number
  * cl determines key scancode; use cl=0 to give combinations such as Ctrl+Shift
  * edx = 0xXYZ determines possible states of control keys:
    * Z (low 4 bits) determines state of LShift and RShift:
      * 0 = no key must be pressed;
      * 1 = exactly one key must be pressed;
      * 2 = both keys must be pressed;
      * 3 = must be pressed LShift, but not RShift;
      * 4 = must be pressed RShift, but not LShift
    * Y - similar for LCtrl and RCtrl;
    * X - similar for LAlt and RAlt

Returned value:

  * eax=0 - success
  * eax=1 - too mant hotkeys (maximum 256 are allowed)

Remarks:

  * Hotkey can work either at pressing or at release. Release scancode of a key is more on 128 than pressing scancode (i.e. high bit is set).
  * Several applications can set the same combination; all such applications will be informed on pressing such combination.

### Function 66.5: Delete Installed Hotkey

Parameters:

  * eax = 66 - function number
  * ebx = 5 - subfunction number
  * cl = scancode of key and edx = 0xXYZ the same as in function 66.4

Returned value:

  * eax = 0 - success
  * eax = 1 - there is no such hotkey

Remarks:

  * When a process/thread terminates, all hotkey installed by it are deleted.
  * The call to this function does not affect other applications. If other application has defined the same combination, it will still receive notices.

## Function 67: Change Position/Size of the Window

Parameters:

  * eax = 67 - function number
  * ebx = new x-coordinate of the window
  * ecx = new y-coordinate of the window
  * edx = new x-size of the window
  * esi = new y-size of the window

Returned value:

  * function does not return value

Remarks:

  * The value -1 for a parameter means "do not change"; e.g. to move the window without resizing it is possible to specify edx=esi=-1.
  * Previously the window must be defined by function 0. It sets initial coordinates and sizes of the window.
  * Sizes of the window are understood in sense of function 0, that is one pixel less than real sizes.
  * The function call for maximized windows is simply ignored.
  * For windows of appropriate styles position and/or sizes can be changed by user; current position and sizes can be obtained by call to function 9.
  * The function sends to the window redraw event (with the code 1).

## Function Group 68: System Services

### Function 68.0: Get the Task Switch Counter

Parameters:

  * eax = 68 - function number
  * ebx = 0 - subfunction number

Returned value:

  * eax = number of task switches from the system booting (modulo 2^32)

### Function 68.1: Switch to the Next Thread

The function completes the current time slice allocated to the thread and switches to the next. (Which thread in which process will be next, is unpredictable). Later, when execution queue will reach the current thread, execution will be continued.

Parameters:

  * eax = 68 - function number
  * ebx = 1 - subfunction number

Returned value:

  * function does not return value

### Function 68.2: Cache & RDPMC

Parameters:

  * eax = 68 - function number
  * ebx = 2 - subfunction number
  * ecx = required action:
    * ecx = 0 - enable instruction 'rdpmc' (ReaD Performance-Monitoring Counters) for applications
    * ecx = 1 - find out whether cache is disabled/enabled
    * ecx = 2 - enable cache
    * ecx = 3 - disable cache

Returned value:

  * for ecx=0:
    * eax = the value of cr4
  * for ecx=1:
    * eax = (cr0 and 0x60000000):
    * eax = 0 - cache is on
    * eax <> 0 - cache is off
  * for ecx=2 and ecx=3:
    * function does not return value

### Function 68.3: Read MSR Register

MSR = Model Specific Register; the complete list of MSR-registers of a processor is included to the documentation on it (for example, IA-32 Intel Architecture Software Developer's Manual, Volume 3, Appendix B); each processor family has its own subset of the MSR-registers.

Parameters:

  * eax = 68 - function number
  * ebx = 3 - subfunction number
  * ecx is ignored
  * edx = MSR address

Returned value:

  * ebx:eax = high:low dword of the result

Remarks:

  * If ecx contains nonexistent or not implemented for this processor MSR, processor will generate an exception in the kernel, which will kill the thread.
  * Previously it is necessary to check, whether MSRs are supported as a whole, with the instruction 'cpuid'. Otherwise processor will generate other exception in the kernel, which will anyway kill the thread.

### Function 68.4: Write to MSR Register

MSR = Model Specific Register; the complete list of MSR-registers of a processor is included to the documentation on it (for example, IA-32 Intel Architecture Software Developer's Manual, Volume 3, Appendix B); each processor family has its own subset of the MSR-registers.

Parameters:

  * eax = 68 - function number
  * ebx = 4 - subfunction number
  * ecx is ignored
  * edx = MSR address
  * esi:edi = high:low dword

Returned value:

  * function does not return value

Remarks:

  * If ecx contains nonexistent or not implemented for this processor MSR, processor will generate an exception in the kernel, which will kill the thread.
  * Previously it is necessary to check, whether MSRs are supported as a whole, with the instruction 'cpuid'. Otherwise processor will generate other exception in the kernel, which will anyway kill the thread.

### Function 68.11: Initialize Process Heap

Parameters:

  * eax = 68 - function number
  * ebx = 11 - subfunction number

Returned value:

  * eax = 0 - failed
  * otherwise size of created heap

Remarks:

  * The function call initializes heap, from which one can in future allocate and free memory blocks with functions 68.12 and 68.13. Heap size is equal to total amount of free application memory.
  * The second function call from the same process results in returning the size of the existing heap.
  * After creation of the heap calls to function 64 will be ignored.

### Function 68.12: Allocate Memory Block

Parameters:

  * eax = 68 - function number
  * ebx = 12 - subfunction number
  * ecx = required size in bytes

Returned value:

  * eax = pointer to the allocated block

Remarks:

  * Before this call one must initialize process heap by call to function 68.11.
  * The function allocates an integer number of pages (4 Kb) in such way that the real size of allocated block is more than or equal to requested size.

### Function 68.13: Free Memory Block

Parameters:

  * eax = 68 - function number
  * ebx = 13 - subfunction number
  * ecx = pointer to the memory block

Returned value:

  * eax = 1 - success
  * eax = 0 - failed

Remarks:

  * The memory block must have been allocated by function 68.12 or function 68.20.

### Function 68.14: Wait for Signal from Another Program/Driver

Parameters:

  * eax = 68 - function number
  * ebx = 14 - subfunction number
  * ecx = pointer to the buffer for information (24 bytes)

Returned value:

  * buffer pointed to by ecx contains the following information:
    * +0: dword: identifier for following data of signal
    * +4: dword: data of signal (20 bytes), format of which is defined by the first dword

### Function 68.16: Load Driver

Parameters:

  * eax = 68 - function number
  * ebx = 16 - subfunction number
  * ecx = pointer to ASCIIZ-string with driver name

Returned value:

  * eax = 0 - failed
  * otherwise eax = driver handle

Remarks:

  * If the driver was not loaded yet, it is loaded; if the driver was loaded yet, nothing happens.
  * Driver name is case-sensitive. Maximum length of the name is 16 characters, including terminating null character, the rest is ignored.
  * Driver ABC is loaded from file /rd/1/drivers/ABC.obj.

### Function 68.17: Driver Control

Parameters:

  * eax = 68 - function number
  * ebx = 17 - subfunction number
  * ecx = pointer to the control structure:
    * +0: dword: handle of driver
    * +4: dword: code of driver function
    * +8: dword: pointer to input data
    * +12 = +0xC: dword: size of input data
    * +16 = +0x10: dword: pointer to output data
    * +20 = +0x14: dword: size of output data

Returned value:

  * eax = determined by driver

Remarks:

  * Function codes and the structure of input/output data are defined by driver.
  * Previously one must obtain driver handle by function 68.16.

### Function 68.19: Load DLL

Parameters:

  * eax = 68 - function number
  * ebx = 19 - subfunction number
  * ecx = pointer to ASCIIZ-string with the full path to DLL

Returned value:

  * eax = 0 - failed
  * otherwise eax = pointer to DLL export table

Remarks:

  * Export table is an array of structures of 2 dword's, terminated by zero. The first dword in structure points to function name, the second dword contains address of function.

### Function 68.20: Reallocate Memory Block

Parameters:

  * eax = 68 - function number
  * ebx = 20 - subfunction number
  * ecx = new size in bytes
  * edx = pointer to already allocated block

Returned value:

  * eax = pointer to the reallocated block, 0 = error

Remarks:

  * Before this call one must initialize process heap by call to function 68.11.
  * The function allocates an integer number of pages (4 Kb) in such way that the real size of allocated block is more than or equal to requested size.
  * If edx=0, the function call is equivalent to memory allocation with function 68.12. Otherwise the block at edx must be allocated earlier with function 68.12 or this function.
  * If ecx=0, the function frees memory block at edx and returns 0.
  * The contents of the block are unchanged up to the shorter of the new and old sizes.

### Function 68.22: Open Named Memory Area

Parameters:

  * eax = 68 - function number
  * ebx = 22 - subfunction number
  * ecx = area name. Maximum of 31 characters with terminating zero
  * edx = area size in bytes for SHM_CREATE and SHM_OPEN_ALWAYS
  * esi = flags for open and access:
    * SHM_OPEN        = 0x00 - open existing memory area. If an area with such name does not exist, the function will return error code 5.
    * SHM_OPEN_ALWAYS = 0x04 - open existing or create new memory area.
    * SHM_CREATE      = 0x08 - create new memory area. If an area with such name already exists, the function will return error code 10.
    * SHM_READ        = 0x00 - only read access
    * SHM_WRITE       = 0x01 - read and write access

Returned value:

  * eax = pointer to memory area, 0 if error has occured
  * if new area is created (SHM_CREATE or SHM_OPEN_ALWAYS): edx = 0 - success, otherwise - error code
  * if existing area is opened (SHM_OPEN or SHM_OPEN_ALWAYS): edx = error code (if eax=0) or area size in bytes

Error codes:

  * E_NOTFOUND = 5
  * E_ACCESS = 10
  * E_NOMEM = 30
  * E_PARAM = 33

Remarks:

  * Before this call one must initialize process heap by call to function 68.11.
  * If a new area is created, access flags set maximal rights for other processes. An attempt from other process to open with denied rights will fail with error code E_ACCESS.
  * The process which has created an area always has write access.

### Function 68.23: Close Named Memory Area

Parameters:

  * eax = 68 - function number
  * ebx = 23 - subfunction number
  * ecx = area name. Maximum of 31 characters with terminating zero

Returned value:

  * eax destroyed

Remarks:

  * A memory area is physically freed (with deleting all data and freeing physical memory), when all threads which have opened this area will close it.
  * When thread is terminating, all opened by it areas are closed.

### Function 68.24: Set Exception Handler

Parameters:

  * eax = 68 - function number
  * ebx = 24 - subfunction number
  * ecx = address of the new exception handler
  * edx = the mask of handled exceptions

Returned value:

  * eax = address of the old exception handler (0, if it was not set)
  * ebx = the old mask of handled exceptions

Remarks:

  * Bit number in mask of exceptions corresponds to exception number in CPU-specification (Intel-PC). For example, FPU exceptions have number 16 (#MF), and SSE exceptions - 19 (#XF).
  * The current implementation ignores the inquiry for hook of 7 exception - the system handles #NM by its own.
  * The exception handler is called with exception number as first (and only) stack parameter. So, correct exit from the handler is RET 4. It returns to the instruction, that caused the exception, for faults, and to the next instruction for traps (see classification of exceptions in CPU specification).
  * When user handler receives control, the corresponding bit in the exception mask is cleared. Raising this exception in consequence leads to default handling, that is, terminating the application in absence of debugger or suspend with notification of debugger otherwise.
  * After user handler completes critical operations, it can set the corresponding bit in the exception mask with function 68.25. Also user handler is responsible for clearing exceptions flags in FPU and/or SSE.

### Function 68.25: Set FPU Exception Handler

Parameters:

  * eax = 68 - function number
  * ebx = 25 - subfunction number
  * ecx = signal number
  * edx = value of activity (0/1)

Returned value:

  * eax = -1 - invalid signal number
  * otherwise eax = old value of activity for this signal (0/1)

Remarks:

  * In current implementation only mask for user excepton handler, which has been previously set by function 68.24, is changed. Signal number corresponds to exception number.

## Function Group 69: Gebugging

A process can load other process as debugged by set of corresponding bit by call to function 70.7. A process can have only one debugger; one process can debug some others. The system notifies debugger on events occuring with debugged process. Messages are written to the buffer defined by function 69.0.

Format of a message:

  * +0: dword: message code
  * +4: dword: PID of debugged process
  * +8: there can be additional data depending on message code

Message codes:

  * 1 = exception
    * in addition dword-number of the exception is given
    * process is suspended
  * 2 = process has terminated
    * comes at any termination: both through the system function -1, and at "murder" by any other process (including debugger itself)
  * 3 = debug exception int 1 = #DB
    * in addition dword-image of the register DR6 is given:
      * bits 0-3: condition of the corresponding breakpoint (set by function 69.9) is satisfied
      * bit 14: exception has occured because of the trace mode (flag TF is set TF)
    * process is suspended

When debugger terminates, all debugged processes are killed. If debugger does not want this, it must previously detach by function 69.3.

All functions are applicable only to processes/threads started from the current by function 70 with set debugging flag. Debugging of multithreaded programs is not supported yet.

### Function 69.0: Define Data Area Fror Debug Messages

Parameters:

  * eax = 69 - function number
  * ebx = 0 - subfunction number
  * ecx = pointer

Format of data area:

  * +0: dword: N = buffer size (not including this header)
  * +4: dword: occupied place
  * +8: N*byte: buffer

Returned value:

  * function does not return value

Remarks:

  * If the size field is negative, the buffer is considered locked and at arrival of new message the system will wait. For synchronization frame all work with the buffer by operations lock/unlock

        neg [bufsize]

  * Data in the buffer are considered as array of items with variable length - messages. Format of a message is explained in general description.

### Function 69.1: Get Contents of Registers of Debugged Thread

Parameters:

  * eax = 69 - function number
  * ebx = 1 - subfunction number
  * ecx = thread identifier
  * edx = size of context structure, must be 0x28=40 bytes
  * esi = pointer to context structure

Returned value:

  * function does not return value

Format of context structure: (FPU is not supported yet)

  * +0: dword: eip
  * +4: dword: eflags
  * +8: dword: eax
  * +12 = +0xC: dword: ecx
  * +16 = +0x10: dword: edx
  * +20 = +0x14: dword: ebx
  * +24 = +0x18: dword: esp
  * +28 = +0x1C: dword: ebp
  * +32 = +0x20: dword: esi
  * +36 = +0x24: dword: edi

Remarks:

  * If the thread executes code of ring-0, the function returns contents of registers of ring-3.
  * Process must be loaded for debugging (as is shown in general description).

### Function 69.2: Set Contents of Registers of Debugged Thread

Parameters:

  * eax = 69 - function number
  * ebx = 2 - subfunction number
  * ecx = thread identifier
  * edx = size of context structure, must be 0x28=40 bytes

Returned value:

  * function does not return value

Format of context structure is shown in the description of function 69.1.

Remarks:

  * If the thread executes code of ring-0, the function returns contents of registers of ring-3.
  * Process must be loaded for debugging (as is shown in general description).

### Function 69.3: Detach from Debugged Process

Parameters:

  * eax = 69 - function number
  * ebx = 3 - subfunction number
  * ecx = identifier

Returned value:

  * function does not return value

Remarks:

  * If the process was suspended, it resumes execution.

### Function 69.4: Suspend Debugged Thread

Parameters:

  * eax = 69 - function number
  * ebx = 4 - subfunction number
  * ecx = thread identifier

Returned value:

  * function does not return value

Remarks:

  * Process must be loaded for debugging (as is shown in general description).

### Function 69.5: Resume Debugged Thread

Parameters:

  * eax = 69 - function number
  * ebx = 5 - subfunction number
  * ecx = thread identifier

Returned value:

  * function does not return value

Remarks:

  * Process must be loaded for debugging (as is shown in general description).

### Function 69.6: Read from Memory of Debugged Process

Parameters:

  * eax = 69 - function number
  * ebx = 6 - subfunction number
  * ecx = identifier
  * edx = number of bytes to read
  * esi = address in the memory of debugged process
  * edi = pointer to buffer for data

Returned value:

  * eax = -1 at an error (invalid PID or buffer)
  * otherwise eax = number of read bytes (possibly, 0, if esi is too large)

Remarks:

  * Process must be loaded for debugging (as is shown in general description).

### Function 69.7: Write to Memory of Debugged Process

Parameters:

  * eax = 69 - function number
  * ebx = 7 - subfunction number
  * ecx = identifier
  * edx = number of bytes to write
  * esi = address of memory in debugged process
  * edi = pointer to data

Returned value:

  * eax = -1 at an error (invalid PID or buffer)
  * otherwise eax = number of written bytes (possibly, 0, if esi is too large)

Remarks:

  * Process must be loaded for debugging (as is shown in general description).

### Function 69.8: Terminate Debugged Thread

Parameters:

  * eax = 69 - function number
  * ebx = 8 - subfunction number
  * ecx = identifier

Returned value:

  * function does not return value

Remarks:

  * Process must be loaded for debugging (as is shown in general description).
  * The function is similar to function 18.2 with two differences: it requires first remark and accepts PID rather than slot number.

### Function 69.9: Set/Clear Hardware Breakpoint

Parameters:

  * eax = 69 - function number
  * ebx = 9 - subfunction number
  * ecx = thread identifier
  * dl = index of breakpoint, from 0 to 3 inclusively
  * dh = flags:
    * if high bit is cleared - set breakpoint:
      * bits 0-1 - condition:
        * 00 = breakpoint on execution
        * 01 = breakpoint on read
        * 11 = breakpoint on read/write
      * bits 2-3 - length; for breakpoints on exception it must be 00, otherwise one of
        * 00 = byte
        * 01 = word
        * 11 = dword
      * esi = breakpoint address; must be aligned according to the length (i.e. must be even for word breakpoints, divisible by 4 for dword)
    * if high bit is set - clear breakpoint

Returned value:

  * eax = 0 - success
  * eax = 1 - error in the input data
  * eax = 2 - (reserved, is never returned in the current implementation) a global breakpoint with that index is already set

Remarks:

  * Process must be loaded for debugging (as is shown in general description).
  * Hardware breakpoints are implemented through DRx-registers of the processor, all limitations results from this.
  * The function can reinstall the breakpoint, previously set by it (and it does not inform on this). Carry on the list of set breakpoints in the debugger.
  * Breakpoints generate debug exception #DB, on which the system notifies debugger.
  * Breakpoints on write and read/write act after execution of the caused it instruction.

## Function Group 70: Work With File System With Long Names Support

Parameters:

  * eax = 70
  * ebx = pointer to the information structure

Returned value:

  * eax = 0 - success; otherwise file system error code
  * some subfunctions return value in other registers too

General format of the information structure:

  * +0: dword: subfunction number
  * +4: dword: file offset
  * +8: dword: high dword of offset (must be 0) or flags field
  * +12 = +0xC: dword: size
  * +16 = +0x10: dword: pointer to data
  * +20 = +0x14: n db: ASCIIZ-string with the filename

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with the filename

Specifications - in documentation on the appropriate subfunction. Filename is case-insensitive. Russian letters must be written in the encoding cp866 (DOS).

Format of filename:

    /base/number/dir1/dir2/.../dirn/file

where /base/number identifies device, on which file is located one of:

  * /RD/1 = /RAMDISK/1 to access ramdisk
  * /FD/1 = /FLOPPYDISK/1 to access first floppy drive, /FD/2 = /FLOPPYDISK/2 to access second one
  * /HD0/x, /HD1/x, /HD2/x, /HD3/x to access accordingly to devices IDE0 (Primary Master), IDE1 (Primary Slave), IDE2 (Secondary Master), IDE3 (Secondary Slave); x - partition number on the selected hard drive, varies from 1 to 255 (on each hard drive the indexing starts from 1)
  * /CD0/1, /CD1/1, /CD2/1, /CD3/1 to access accordingly to CD on IDE0 (Primary Master), IDE1 (Primary Slave), IDE2 (Secondary Master), IDE3 (Secondary Slave)
  * /SYS means system folder; with the usual boot (from floppy) is equivalent to /RD/1

Examples:

  * '/rd/1/kernel.asm',0
  * '/HD0/1/kernel.asm',0
  * '/hd0/2/menuet/pics/tanzania.bmp',0
  * '/hd0/1/Program files/NameOfProgram/SomeFile.SomeExtension',0
  * '/sys/MySuperApp.ini',0

Also function supports relative names. If the path begins not with '/', it is considered relative to a current folder. To get or set a current folder, use the function 30.

For CD-drives due to hardware limitations only subfunctions 0, 1, 5 and 7 are available, other subfunctions return error with code 2.

At the first call of subfunctions 0, 1, 5, 7 to ATAPI devices (CD and DVD) the manual control of tray is locked due to caching drive data. Unlocking is made when function 24.4 is called for corresponding device.

### Function 70.0: Read File With Long Names Support

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 0 = subfunction number
  * +4: dword: file offset (in bytes)
  * +8: dword: 0 (reserved for high dword of offset)
  * +12 = +0xC: dword: number of bytes to read
  * +16 = +0x10: dword: pointer to buffer for data
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx = number of read bytes or -1=0xffffffff if file was not found

Remarks:

  * If file was ended before last requested block was read, the function will read as many as it can, and after that return eax=6 (EOF).
  * The function does not allow to read folder (returns eax=10, access denied).

### Function 70.1: Read Folder With Long Names Support

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 1 = subfunction number
  * +4: dword: index of starting block (beginning from 0)
  * +8: dword: flags field:
    * bit 0 (mask 1): in what format to return names, 0=ANSI, 1=UNICODE
    * other bits are reserved and must be set to 0 for the future compatibility
  * +12 = +0xC: dword: number of blocks to read
  * +16 = +0x10: dword: pointer to buffer for data, buffer size must be not less than 32 + [+12]*560 bytes
  * +20 = +0x14: ASCIIZ-name of folder, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx = number of files, information on which was written to the buffer, or -1=0xffffffff, if folder was not found

Structure of the buffer:

  * +0: 32*byte: header
  * +32 = +0x20: n1*byte: block with information on file 1
  * +32+n1: n2*byte: block with information on file 2
  * ...

Structure of header:

  * +0: dword: version of structure (current is 1)
  * +4: dword: number of placed blocks; is not greater than requested in the field +12 of information structure; can be less, if there are no more files in folder (the same as in ebx)
  * +8: dword: total number of files in folder
  * +12 = +0xC: 20*byte: reserved (zeroed)

Structure of block of data for folder entry (BDFE):

  * +0: dword: attributes of file:
    * bit 0 (mask 1): file is read-only
    * bit 1 (mask 2): file is hidden
    * bit 2 (mask 4): file is system
    * bit 3 (mask 8): this is not a file but volume label (for one partition meets no more than once and only in root folder)
    * bit 4 (mask 0x10): this is a folder
    * bit 5 (mask 0x20): file was not archived - many archivation programs have an option to archive only files with this bit set, and after archiving this bit is cleared - it can be useful for automatically creating of backup-archives as at writing this bit is usually set
  * +4: byte: type of name data (coincides with bit 0 of flags in the information structure):
    * 0 = ASCII = 1-byte representation of each character
    * 1 = UNICODE = 2-byte representation of each character
  * +5: 3*byte: reserved (zero)
  * +8: 4*byte: time of file creation
  * +12 = +0xC: 4*byte: date of file creation
  * +16 = +0x10: 4*byte: time of last access (read or write)
  * +20 = +0x14: 4*byte: date of last access
  * +24 = +0x18: 4*byte: time of last modification
  * +28 = +0x1C: 4*byte: date of last modification
  * +32 = +0x20: qword: file size in bytes (up to 16777216 Tb)
  * +40 = +0x28: name
    * for ASCII format: maximum length is 263 characters (263 bytes), byte after the name has value 0
    * for UNICODE format: maximum length is 259 characters (518 bytes), 2 bytes after the name have value 0

Time format:

  * +0: byte: seconds
  * +1: byte: minutes
  * +2: byte: hours
  * +3: byte: reserved (0)
  * for example, 23.59.59 is written as (in hex) 3B 3B 17 00

Date format:

  * +0: byte: day
  * +1: byte: month
  * +2: word: year
  * for example, 25.11.1979 is written as (in hex) 19 0B BB 07

Remarks:

  * If BDFE contains ASCII name, the length of BDFE is 304 bytes, if UNICODE name - 560 bytes. Value of length is aligned on 16-byte bound (to accelerate processing in CPU cache).
  * First character after a name is zero (ASCIIZ-string). The further data contain garbage.
  * If files in folder were ended before requested number was read, the function will read as many as it can, and after that return eax=6 (EOF).
  * Any folder on the disk, except for root, contains two special entries "." and "..", identifying accordingly the folder itself and the parent folder.
  * The function allows also to read virtual folders "/", "/rd", "/fd", "/hd[n]", thus attributes of subfolders are set to 0x10, and times and dates are zeroed. An alternative way to get the equipment information - function 18.11.

### Function 70.2: Create/Rewrite File With Long Names Support

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 2 = subfunction number
  * +4: dword: 0 (reserved)
  * +8: dword: 0 (reserved)
  * +12 = +0xC: dword: number of bytes to read
  * +16 = +0x10: dword: pointer to data
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx = number of written bytes (possibly 0)

Remarks:

  * If a file with given name did not exist, it is created; if it existed, it is rewritten.
  * If there is not enough free space on disk, the function will write as many as can and then return error code 8.
  * The function is not supported for CD (returns error code 2).

### Function 70.3: Write to Existing File With Long Names Support

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 3 = subfunction number
  * +4: dword: file offset (in bytes)
  * +8: dword: high dword of offset (must be 0 for FAT)
  * +12 = +0xC: dword: number of bytes to write
  * +16 = +0x10: dword: pointer to data
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx = number of written bytes (possibly 0)

Remarks:

  * The file must already exist, otherwise function returns eax=5.
  * The only result of write 0 bytes is update in the file attributes date/time of modification and access to the current date/time.
  * If beginning and/or ending position is greater than file size (except for the previous case), the file is expanded to needed size with zero characters.
  * The function is not supported for CD (returns error code 2).

### Function 70.4: Set End of File

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 4 = subfunction number
  * +4: dword: low dword of new file size
  * +8: dword: high dword of new file size (must be 0 for FAT)
  * +12 = +0xC: dword: 0 (reserved)
  * +16 = +0x10: dword: 0 (reserved)
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx destroyed

Remarks:

  * If the new file size is less than old one, file is truncated. If the new size is greater than old one, file is expanded with characters with code 0. If the new size is equal to old one, the only result of call is set date/time of modification and access to the current date/time.
  * If there is not enough free space on disk for expansion, the function will expand to maximum possible size and then return error code 8.
  * The function is not supported for CD (returns error code 2).

### Function 70.5: Get Information on File/Folder

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 5 = subfunction number
  * +4: dword: 0 (reserved)
  * +8: dword: 0 (reserved)
  * +12 = +0xC: dword: 0 (reserved)
  * +16 = +0x10: dword: pointer to buffer for data (40 bytes)
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx destroyed

Information on file is returned in the BDFE format (block of data for folder entry), explained in the description of function 70.1, but without filename (i.e. only first 40 = 0x28 bytes).

Remarks:

  * The function does not support virtual folders such as /, /rd and root folders like /rd/1.

### Function 70.6: Set Attributes of File/Folder

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 6 = subfunction number
  * +4: dword: 0 (reserved)
  * +8: dword: 0 (reserved)
  * +12 = +0xC: dword: 0 (reserved)
  * +16 = +0x10: dword: pointer to buffer with attributes (32 bytes)
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx destroyed

File attributes are first 32 bytes in BDFE (block of data for folder entry), explained in the description of function 70.1 (that is, without name and size of file). Attribute file/folder/volume label (bits 3,4 in dword +0) is not changed. Byte +4 (name format) is ignored.

Remarks:

  * The function does not support virtual folders such as /, /rd and root folders like /rd/1.
  * The function is not supported for CD (returns error code 2).

### Function 70.7: Start Application

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 7 = subfunction number
  * +4: dword: flags field:
    * bit 0: start process as debugged
    * other bits are reserved and must be set to 0
  * +8: dword: 0 or pointer to ASCIIZ-string with parameters
  * +12 = +0xC: dword: 0 (reserved)
  * +16 = +0x10: dword: 0 (reserved)
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax > 0 - program is loaded, eax contains PID
  * eax < 0 - an error has occured, -eax contains file system error code
  * ebx destroyed

Remarks:

  * Command line must be terminated by the character with the code 0 (ASCIIZ-string); function takes into account either all characters up to terminating zero inclusively or first 256 character regarding what is less.
  * If the process is started as debugged, it is created in the suspended state; to run use function 69.5.

### Function 70.8: Delete File/Folder

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 8 = subfunction number
  * +4: dword: 0 (reserved)
  * +8: dword: 0 (reserved)
  * +12 = +0xC: dword: 0 (reserved)
  * +16 = +0x10: dword: 0 (reserved)
  * +20 = +0x14: ASCIIZ-name of file, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with file name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx destroyed

Remarks:

  * The function is not supported for CD (returns error code 2).
  * The function can delete only empty folders (attempt to delete nonempty folder results in error with code 10, "access denied").

### Function 70.9: Create Folder

Parameters:

  * eax = 70 - function number
  * ebx = pointer to the information structure

Format of the information structure:

  * +0: dword: 9 = subfunction number
  * +4: dword: 0 (reserved)
  * +8: dword: 0 (reserved)
  * +12 = +0xC: dword: 0 (reserved)
  * +16 = +0x10: dword: 0 (reserved)
  * +20 = +0x14: ASCIIZ-name of folder, the rules of names forming are given in the general description

or

  * +20 = +0x14: db 0
  * +21 = +0x15: dd pointer to ASCIIZ-string with folder name

Returned value:

  * eax = 0 - success, otherwise file system error code
  * ebx destroyed

Remarks:

  * The function is not supported for CD (returns error code 2).
  * The parent folder must already exist.
  * If target folder already exists, function returns success (eax=0).

## Function Group 71: Window Settings

### Function 71.1: Set Window Caption

Parameters:

  * eax = 71 - function number
  * ebx = 1 - subfunction number
  * ecx = pointer to caption string

Returned value:

  * function does not return value

Remarks:

  * String must be in the ASCIIZ-format. Disregarding real string length, no more than 255 characters are drawn.
  * Pass NULL in ecx to remove caption.

## Function Group 72: Send Message to a Window

### Function 72.1: Send Message With Parameter to the Active Window

Parameters:

  * eax = 72 - function number
  * ebx = 1 - subfunction number
  * ecx = event code: 2 or 3
  * edx = parameter: key code for ecx=2, button identifier for ecx=3

Returned value:

  * eax = 0 - success
  * eax = 1 - buffer is full

## Function -1: Terminate Thread/Process

Parameters:

  * eax = -1 - function number

Returned value:

  * function does not return neither value nor control

Remarks:

  * If the process did not create threads obviously, it has only one thread, which termination results in process termination.
  * If the current thread is last in the process, its termination also results in process terminates.
  * This function terminates the current thread. Other thread can be killed by call to function 18.2.

# List of Events

Next event can be retrieved by the call of one from functions 10 (to wait for event), 11 (to check without waiting), 23 (to wait during the given time). These functions return only those events, which enter into a mask set by function 40. By default it is first three, there is enough for most applications.

Codes of events:

  * 1 = redraw event (is reset by call to function 0)
  * 2 = key on keyboard is pressed (acts, only when the window is active) or hotkey is pressed; is reset, when all keys from the buffer are read out by function 2
  * 3 = button is pressed, defined earlier by function 8 (or close button, created implicitly by function 0; minimize button is handled by the system and sends no message; acts, only when the window is active; is reset when all buttons from the buffer are read out by function 17)
  * 4 = reserved (in current implementation never comes even after unmasking by function 40)
  * 5 = the desktop background is redrawed (is reset automatically after redraw, so if in redraw time program does not wait and does not check events, it will not remark this event)
  * 6 = mouse event (something happened - button pressing or moving; is reset at reading)
  * 7 = IPC event (see function 60 - Inter Process Communication; is reset at reading)
  * 8 = network event (is reset at reading)
  * 9 = debug event (is reset at reading; see debug subsystem)
  * 16..31 = event with appropriate IRQ (16=IRQ0, 31=IRQ15) (is reset after reading all IRQ data)

# Error Codes of the File System

  * 0 = success
  * 1 = base and/or partition of a hard disk is not defined (by functions 21.7, 21.8)
  * 2 = function is not supported for the given file system
  * 3 = unknown file system
  * 4 = reserved, is never returned in the current implementation
  * 5 = file not found
  * 6 = end of file, EOF
  * 7 = pointer lies outside of application memory
  * 8 = disk is full
  * 9 = FAT table is destroyed
  * 10 = access denied
  * 11 = device error

Application start functions can return also following errors:

  * 30 = 0x1E = not enough memory
  * 31 = 0x1F = file is not executable
  * 32 = 0x20 = too many processes
