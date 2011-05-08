;;======================================================================================================================
;;///// imports.inc //////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2007-2010 KolibriOS team <http://kolibrios.org/>
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

macro kernel_export [name]{
forward
  if used name
	if DEBUG
	display 'uses: ',`name,#13,#10
	end if
    extrn name
  end if
}
; all exported kernel functions and data


kernel_export \
	      RegService,\
	      GetService,\
	      ServiceHandler,\
	      AttachIntHandler,\
	      GetIntHandler,\
	      FpuSave,\
	      FpuRestore,\
	      ReservePortArea,\
	      Boot_Log,\
\
          MutexInit,\
          MutexLock,\
          MutexUnlock,\
\
	      PciApi,\
	      PciRead32,\
	      PciRead16,\
	      PciRead8,\
	      PciWrite8,\
	      PciWrite16,\
	      PciWrite32,\
\
	      AllocPage,\
	      AllocPages,\
	      FreePage,\
	      MapPage,\
	      MapSpace,\
	      MapIoMem,\
	      GetPgAddr,\
	      CommitPages,\
	      ReleasePages,\
\
	      AllocKernelSpace,\
	      FreeKernelSpace,\
	      KernelAlloc,\
	      KernelFree,\
	      UserAlloc,\
	      UserFree,\
	      Kmalloc,\
	      Kfree,\
	      CreateRingBuffer,\
\
	      GetPid,\
	      CreateObject,\
	      DestroyObject,\
	      CreateEvent,\
	      RaiseEvent,\
	      WaitEvent,\
	      DestroyEvent,\
	      ClearEvent,\
\
	      LoadCursor,\
	      SelectHwCursor,\
	      SetHwCursor,\
	      HwCursorRestore,\
	      HwCursorCreate,\
\
	      SysMsgBoardStr,\
	      SysMsgBoardChar,\
	      GetCurrentTask,\
	      LoadFile,\
	      SendEvent,\
	      SetMouseData,\
	      Sleep,\
	      GetTimerTicks,\
\
	      strncat,\
	      strncpy,\
	      strncmp,\
	      strnlen,\
	      strchr,\
	      strrchr,\
\
	      LFBAddress,\
	      GetDisplay,\
	      SetScreen
