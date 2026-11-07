	arch 65816
	; plist OFF
;**********************************************************************
;*                                                                    *
;*                       P R O J E C T :   R A G E                    *
;*                                                                    *
;*                                          MONITOR/BOOT MEMORY       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"

	arch 65816
	; mmu snessfx
	; cpudata

	if (WIRE*!DEBUG) != 0
	%section(MONITOR)
	endif

	if (WIRE*GSUREV1) != 0
	%section(MEMORYERROR00)
	%section(MEMORYERROR01)
	%section(MEMORYERROR02)
	%section(MEMORYERROR03)
	%section(MEMORYERROR04)
	%section(MEMORYERROR05)
	%section(MEMORYERROR06)
	%section(MEMORYERROR07)
	%section(MEMORYERROR08)
	%section(MEMORYERROR09)
	endif
