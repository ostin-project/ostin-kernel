;;======================================================================================================================
;;///// config.inc ///////////////////////////////////////////////////////////////////////////////////////// GPLv2 /////
;;======================================================================================================================
;; (c) 2011 Ostin project <http://ostin.googlecode.com/>
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

KCONFIG_LANGUAGE fix en

KCONFIG_DEBUG fix 1
KCONFIG_DEBUG_LEVEL fix 1

KCONFIG_DEBUG_SHOW_IO fix 0

; make irq 3 and irq 4 available for PCI devices
KCONFIG_USE_COM_IRQ fix 1

; enable serial output console
; 0x3f8 is com1, 0x2f8 is com2, 0x3e8 is com3, 0x2e8 is com4, no irq's are used
KCONFIG_DEBUG_COM_BASE fix 0

KCONFIG_GREEDY_KERNEL fix 0

; don't start immediately after bootlog
KCONFIG_BOOT_LOG_ESC fix 0
