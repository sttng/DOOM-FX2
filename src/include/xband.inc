includeonce
;**********************************************************************
;*                                                                    *
;*                      P R O J E C T :   R A G E                     *
;*                                                                    *
;*                              XBAND HARDWARE EQUATES/DEFINITIONS    *
;*                                                                    *
;**********************************************************************


;
;	* * * * * * *       GAME FEATURES       * * * * * * *
;
	usePOCKY = 0	; 1=Enable POCKY Board Version

;
;	* * * * * * *       XBAND HARDWARE       * * * * * * *
;
	XBANDROM = $D00000
	XBANDRAM = $E00000

;
;	* * * * * * *       "FRED" HARDWARE       * * * * * * *
;
	FRED = $FBC001
	KILL = FRED+$3C00
	CONTROL = FRED+$3C02
	RANDY = $524E4C

	translation_address0 = FRED+($00<<1)
	translation_address1 = FRED+($04<<1)
	translation_address2 = FRED+($08<<1)
	translation_address3 = FRED+($0C<<1)
	translation_address4 = FRED+($10<<1)
	translation_address5 = FRED+($14<<1)
	translation_address6 = FRED+($18<<1)
	translation_address7 = FRED+($1C<<1)
	translation_address8 = FRED+($20<<1)
	translation_address9 = FRED+($24<<1)
	translation_address10 = FRED+($28<<1)
	range0start = FRED+($2C<<1)
	range1start = FRED+($30<<1)

	magic_address = FRED+($38<<1)

	range0end = FRED+($40<<1)
	range1end = FRED+($44<<1)

	range0destination = FRED+($50<<1)
	range0mask = FRED+($52<<1)

	range1destination = FRED+($54<<1)
	range1mask = FRED+($56<<1)

	ram_base = FRED+($60<<1)
	ram_bound = FRED+($64<<1)
	vector_table_base = FRED+($68<<1)
	hit_enables = FRED+($6C<<1)
	rom_bound = FRED+($70<<1)
	rom_base = FRED+($74<<1)
	snes_control = FRED+($78<<1)
	sram_protect = FRED+($79<<1)
	address_status = FRED+($7C<<1)

	smart_control = FRED+($80<<1)
	smart_status = FRED+($84<<1)
	vsync_count = FRED+($88<<1)
	modem_control_1 = FRED+($8C<<1)
	modem_transmit_buffer = FRED+($90<<1)
	modem_receive_buffer = FRED+($94<<1)
	modem_status_2 = FRED+($98<<1)
	serial_vertical_count = FRED+($9C<<1)
	modem_status_1 = FRED+($A0<<1)
	guard_count = FRED+($A4<<1)
	baud_count_divisor = FRED+($A8<<1)
	modem_control_2 = FRED+($AC<<1)
	write_vsync = FRED+($B0<<1)
	led_data = FRED+($B4<<1)
	enable_led = FRED+($B5<<1)
;
	ring_check = FRED+($CF<<1)

	mdTop_LED_Mask = $02
	mdMiddle_LED_Mask = $08
	mdBottom_LED_Mask = $20


;
;	* * * * * * *       ROCKWELL MODEM HARDWARE       * * * * * * *
;
;	MODEM CONTROL REGISTER 1 BITS
;
	mc1b_BREAK = $80
	mc1b_ODDPARITY = $40
	mc1b_ENABLEPARITY = $20
	mc1b_ONESTOP = $10
	mc1b_ENABLESTOP = $08
	mc1b_BIT8 = $04
	mc1b_RESETSERIAL = $02
	mc1b_ENABLESERIAL = $01


;
;	* * * * * * *       "POCKY" BOARD HARDWARE       * * * * * * *
;
	rxd_A = $21C0
	txd_A = $21C0
	ier_A = $21C1	; int enable reg
	dll_A = $21C0	; divisor latch lo
	dlh_A = $21C1	; divisor latch hi
	iir_A = $21C2	; int id reg
	fcr_A = $21C2	; fifo ctl reg
	lcr_A = $21C3	; line ctl reg
	mcr_A = $21C4	; modem ctl reg
	lsr_A = $21C5	; line status reg
	msr_A = $21C6	; modem status reg
	scr_A = $21C7	; scratch pad reg

	rxd_B = $21D0
	txd_B = $21D0
	ier_B = $21D1	; int enable reg
	dll_B = $21D0	; divisor latch lo
	dlh_B = $21D1	; divisor latch hi
	iir_B = $21D2	; int id reg
	fcr_B = $21D2	; fifo ctl reg
	lcr_B = $21D3	; line ctl reg
	mcr_B = $21D4	; modem ctl reg
	lsr_B = $21D5	; line status reg
	msr_B = $21D6	; modem status reg
	scr_B = $21D7	; scratch pad reg

	port_A_baud = 57600
	port_B_baud = 4800
	port_B_baud_SGP = 57600

	port_A_baud_val = (115200/port_A_baud)
	port_B_baud_val = (115200/port_B_baud)
	port_B_baud_SGP_val = (115200/port_B_baud_SGP)


;
;	* * * * * * *       OS AND HARDWARE DEFINES       * * * * * * *
;
	kGPInitGamePatch = 0
	kGPStartGamePatch = 1
	kGPDisplayMessage = 2
	kGPStopGame = 3
	kGPKillGame = 4
	kGPReportError = 5
	kGPPlaySinglePlayerGame = 6

	!kGameTimeout = (-426)
	!kCallWaitingErr = (-427)
	!kRemoteCallWaitingErr = (-428)
	!kSinglePlayerGameOver = (-709)
	!kNetRegisterTimeout = (-710)

	!kOverrunError = (-425)	; $fe57
	!kTimeout = (-426)	; $fe56
	!kGibbledPacket = (-601)	; $fda7
	!kNoData = (-602)	; $fda6
	!kOutOfSync = (-901)	; $fc76

	gRegisterBase = $C0	; where Fred is (required if you move Fred)

	kOSHandleGameError = 0
	kOSGameOver = 1
	kOSCheckLine = 24

	kResetCPU = 14


;
;	* * * * * * *       XBAND GLOBAL VARIABLES       * * * * * * *
;
	gTicks = $E00020	; TimerTicks
	gSessionIsMaster = $E02C44	; 0 = Slave, !=0 = Master
;
	_XBOSDispatcher = $E000CC
;
	kHWKeyboardBitTimeConst = 7	; BitDelay between BitPairs
	kHardwareKeyboardIDConst = $78	; Hardware ID Code


;
;	* * * * * * *       RICHARD KISS'S JML MACRO       * * * * * * *
;
;	Call with:	Address of Code to Call that ends in RTS
;			Address of RTL in same Bank as Code
;
; macro RICHJML: not translated (never used)


;
;	* * * * * * *       COMMUNICATIONS       * * * * * * *
;
	XBFrameLatency = 1	; Frame Latency
;Packet_Prefill		equ	2		; 2 frames Pre Latency (Local->Global Data)
	Packet_Size = 8	; #Bytes per Packet
	XBModemBufferSize = 256
	XBModemBufferMask = XBModemBufferSize-1
