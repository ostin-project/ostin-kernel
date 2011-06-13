;;======================================================================================================================
;;///// kernel32.inc /////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
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

include "include/sync.inc"

include "blkdev/cd_drv.asm"
include "blkdev/cdrom.asm"
include "blkdev/fdc.asm"
include "blkdev/flp_drv.asm"
include "blkdev/hd_drv.asm"
include "blkdev/ide_cache.asm"
include "blkdev/rd.asm"

include "bus/pci/pci32.asm"

include "charset.asm"

include "core/conf_lib.asm"
include "core/dll.asm"
include "core/exports.inc"
include "core/ext_lib.asm"
include "core/fpu.asm"
include "core/heap.asm"
include "core/malloc.asm"
include "core/memory.asm"
include "core/peload.asm"
include "core/sched.asm"
include "core/string.asm"
include "core/sys32.asm"
include "core/syscall.asm"
include "core/taskman.asm"
include "core/v86.asm"

include "fs/ext2.asm"
include "fs/fat12.asm"
include "fs/fat32.asm"
include "fs/fs.asm"
include "fs/fs_lfn.asm"
include "fs/iso9660.asm"
include "fs/ntfs.asm"
include "fs/parse_fn.asm"

include "gui/button.asm"
include "gui/event.asm"
include "gui/font.asm"
include "gui/mouse.asm"
include "gui/skincode.asm"
include "gui/window.asm"

include "hid/keyboard.asm"
include "hid/mousedrv.asm"
include "hid/set_dtc.asm"

include "imports.inc"

include "network/stack.asm"

include "sound/playnote.asm"

include "video/blitter.asm"
include "video/cursors.asm"
include "video/vesa12.asm"
include "video/vesa20.asm"
include "video/vga.asm"
