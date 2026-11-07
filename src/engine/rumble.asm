	arch 65816
;**********************************************************************
;*                                                                    *
;*                 P R O J E C T :   REALITY_ENGINE                   *
;*                                                                    *
;*                   RUMBLE MODULE (this port)                        *
;*                                                                    *
;**********************************************************************
;
;	The LRG rumble controller in port 1, as the FX3 cartridge uses it
;	(rumble.inc).  The GSU queues requests (_RLAddRumble, rlplayer2.asm);
;	_RLSwapRLXVars passes them on (RumbleQueue).  Up to MaxRumbles effects
;	play at once, each a wave of motor strengths per frame (high nibble)
;	for the left and the right motor, summed and limited to 15.
;	In a level RumbleFrame (RAM code: the GSU may have the ROM) runs every
;	frame from the top IRQ and sends the strengths after the joypad read;
;	elsewhere the NMI sends "motors off" (RumbleOffL, ROM).  Off with the
;	menu's Rumble switch (_RumbleOn), silent in the pause menu, stopped
;	after each level.

	incsrc "src/include/rage.inc"
	incsrc "src/include/snes.inc"
	incsrc "src/include/rumble.inc"

;
;	>>>   SEND .A (MOTOR STRENGTHS: RIGHT.4 LEFT.4)   <<<
;
;	A joypad in port 1 and no mouse in port 2 (as FX3), after the joypad
;	read.  mode 'AX' in and out, dbr 0; A, Y.
;
macro rumble_send()
	tay
	sep #$20		; mode 'a!'
	lda.w JOY1Stat	; $00 = joypad
	bne +++
	lda.w JOY2Stat
	cmp.b #$01	; Mouse in port 2?
	beq +++
	rep #$20		; mode 'A!'
	tya
	and.w #$00FF
	ora.w #($72<<8)	; Sentry %01110010, then the strengths
	sta.w RumbleBits
	ldy.w #16
-
	rep #$20		; mode 'A!'
	asl.w RumbleBits	; Next bit (first the highest) -> C
	sep #$20		; mode 'a!'
	lda.b #$80	; (WRIO bit 7, port 2's IO bit, stays 1:
	bcc +	;  it also latches the PPU counters)
	lda.b #$C0	; Bit 6 = port 1's IO bit
+
	sta.w WRIO
	lda.w $4016	; Clock it in
	dey
	bne -
	lda.b #$FF
	sta.w WRIO
+++
	rep #$30		; mode 'AX!'
endmacro


	%section(RUMBLE)	; (ROM: the NMI, rage.asm)

;
;	* * * * * * *       MOTORS OFF (NMI, OUTSIDE THE LEVELS)       * * * * * * *
;
	; dbr 0
	; dpr 0
RumbleOffL:
	php
	rep #$30		; mode 'AX!'
	pha
	phx
	phy
	lda.w #0
	%rumble_send()
	ply
	plx
	pla
	plp
	rtl

;
;	* * * * * * *       RESET: NO EFFECTS       * * * * * * *
;
	; dbr ?
	; dpr 0
RumbleResetL:
	php
	phb
	rep #$30		; mode 'AX!'
	pea.w $0000	; DBR 0
	plb
	plb
	ldx.w #(MaxRumbles*4)-2
.pos:
	stz.w RumblePos,x
	dex
	dex
	bpl .pos
	ldx.w #(MaxRumbles*2)-2
.fx:
	stz.w RumbleFx,x
	dex
	dex
	bpl .fx
	stz.w RumbleOut
	plb
	plp
	rtl


	%section(ENGINE_RAMCODE)


;
;	* * * * * * *       ADD A REQUEST       * * * * * * *
;
;	.A = effect# | recAddLoop / recRemLoop
;
	; dbr 0
	; dpr 0
	; mode 'AX'
RumbleQueue:	; the GSU's requests of this frame (RLSNESRumbles)
	ldy.w #0
.next:
	phy
	lda.w RLSNESRumbles,y
	jsr.w RumbleAdd
	ply
	iny
	cpy.w RLSNESRumbleN
	bcc .next
	rts

RumbleAdd:
	and.w #$00FF
	bit.w #recRemLoop	; Stop a loop?
	bne .remove
	bit.w #recAddLoop	; Start a loop?
	beq .add
	and.w #reMask
	jsr.w RumbleFind	; Already playing?
	beq .done	; Yes
.add:
	and.w #reMask
	cmp.w #reNum
	bcs .done
	sta.w RumbleTemp
	lda.w #0	; A free slot
	jsr.w RumbleFind
	bne .done	; None: dropped
	lda.w RumbleTemp
	sta.w RumbleFx,x
	txa
	asl a
	tay	; .Y = slot*4
	lda.w RumbleTemp
	asl a
	asl a
	tax	; .X = effect*4
	lda.l RumbleWaveIndex,x	; Left wave
	sta.w RumblePos,y
	lda.l RumbleWaveIndex+2,x	; Right wave
	sta.w RumblePos+2,y
.done:
	rts
.remove:
	and.w #reMask
	jsr.w RumbleFind
	bne .done
	stz.w RumbleFx,x
	txa
	asl a
	tax
	stz.w RumblePos,x
	stz.w RumblePos+2,x
	rts

;
;	.A = effect# (0 = a free slot)  ->  .X = slot*2, Z = 1 if found
;
RumbleFind:
	ldx.w #(MaxRumbles*2)-2
.slot:
	cmp.w RumbleFx,x
	beq .found
	dex
	dex
	bpl .slot	; (not found: Z = 0 from dex)
.found:
	rts


;
;	* * * * * * *       EVERY FRAME: MIX AND SEND       * * * * * * *
;
	; dbr 0
	; dpr 0
RumbleFrame:
	php
	rep #$30		; mode 'AX!'
	pha
	phx
	phy
	ldy.w #2	; Right motor (low frequency)
	jsr.w RumbleMix
	and.w #$00F0
	sta.w RumbleOut
	ldy.w #0	; Left motor (high frequency)
	jsr.w RumbleMix
	lsr a
	lsr a
	lsr a
	lsr a
	ora.w RumbleOut
	sta.w RumbleOut
;
;	>>>   A SLOT WHOSE TWO WAVES ENDED IS FREE   <<<
;
	ldx.w #(MaxRumbles*2)-2
.free:
	txa
	asl a
	tay
	lda.w RumblePos,y
	ora.w RumblePos+2,y
	bne .used
	stz.w RumbleFx,x
.used:
	dex
	dex
	bpl .free
;
;	>>>   SEND (MUTED: SWITCHED OFF, PAUSE MENU)   <<<
;
	lda.w RumbleOut
	ldx.w _RumbleOn	; Switched off in the menu?
	beq .off
	ldx.b IRQTPhase	; Pause menu (IRQ phase 4)?
	cpx.w #(4*2)
	bne .on
.off:
	lda.w #0
.on:
	%rumble_send()
	ply
	plx
	pla
	plp
	rts

;
;	.Y = 0 (left) / 2 (right)  ->  .A = the slots' strengths summed (max $FF);
;	each wave moves on by one entry
;
	; mode 'AX'
RumbleMix:
	stz.w RumbleSum
.slot:
	ldx.w RumblePos,y	; Wave offset (0 = none)
	beq .next
.get:
	lda.l RumbleWaves,x
	and.w #$00FF
	beq .end	; 0 = end of the wave
	cmp.w #$00FF	; $FF, dw offset = loop
	beq .loop
	clc
	adc.w RumbleSum
	sta.w RumbleSum
	inx
	txa
	sta.w RumblePos,y
	bra .next
.loop:
	lda.l RumbleWaves+1,x
	tax
	bra .get
.end:
	sta.w RumblePos,y	; (.A = 0)
.next:
	iny
	iny
	iny
	iny
	cpy.w #(MaxRumbles*4)
	bcc .slot
	lda.w RumbleSum
	cmp.w #$0100
	bcc .max
	lda.w #$00FF
.max:
	rts


;
;	* * * * * * *       EFFECT WAVES (THE FX3 CARTRIDGE'S)       * * * * * * *
;
;	A strength per frame in the high nibble ($01: on, strength 0), 0 = end,
;	$FF + dw offset = continue there (loop)
;
RumbleWaves:
	db $52	; (offset 0 = no wave)
RumbleWDamage1:
	db $40,$40,$40,0
RumbleWDamage2:
	db $80,$80,$80,0
RumbleWDamage3:
	db $C0,$C0,$C0,0
RumbleWFist:
	db $30,$30,$20,$10,0
RumbleWPistol:
	db $70,$60,$50,$40,0
RumbleWShotGunL:
	db $80,$80,$60,$60,$40,$30,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$20,$40,$01,$01,$01,$01,$01,$01,$01,$01,$10,$30,0
RumbleWShotGunR:
	db $80,$80,$60,$60,$40,$30,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$50,$60,$01,$01,$01,$01,$01,$01,$01,$01,$40,$50,0
RumbleWChainSawL:
	db $20,$20,$20,$20,$20,$20,0
RumbleWChainSawR:
	db $90,$90,$90,$90,$90,$90,0
RumbleWChainGunL:
	db $50,$A0,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,0
RumbleWChainGunR:
	db $01,$01,$01,$01,$01,$01,$50,$A0,$01,$01,$01,$01,0
RumbleWRocket:
	db $80,$80,$80,$80,$80,0
RumbleWPlasma:
	db $80,$80,$80,0
RumbleWBFG:
	db $A0,$A0,$A0,$A0,$A0,$A0,$A0,0
RumbleWIdleChainSawL:
	db $01,$01,$FF
	dw RumbleWIdleChainSawL-RumbleWaves
RumbleWIdleChainSawR:
	db $20,$10,$FF
	dw RumbleWIdleChainSawR-RumbleWaves

;
;	>>>   PER EFFECT: LEFT, RIGHT WAVE (OFFSETS IN RUMBLEWAVES)   <<<
;
RumbleWaveIndex:
	dw 0,0	; (0: none)
	dw RumbleWDamage1-RumbleWaves,RumbleWDamage1-RumbleWaves	; reDamage1
	dw RumbleWDamage2-RumbleWaves,RumbleWDamage2-RumbleWaves	; reDamage2
	dw RumbleWDamage3-RumbleWaves,RumbleWDamage3-RumbleWaves	; reDamage3
	dw RumbleWFist-RumbleWaves,RumbleWFist-RumbleWaves	; reFireFist
	dw RumbleWPistol-RumbleWaves,RumbleWPistol-RumbleWaves	; reFirePistol
	dw RumbleWShotGunL-RumbleWaves,RumbleWShotGunR-RumbleWaves	; reFireShotGun
	dw RumbleWChainSawL-RumbleWaves,RumbleWChainSawR-RumbleWaves	; reFireChainSaw
	dw RumbleWChainGunL-RumbleWaves,RumbleWChainGunR-RumbleWaves	; reFireChainGun
	dw RumbleWRocket-RumbleWaves,RumbleWRocket-RumbleWaves	; reFireRocket
	dw RumbleWPlasma-RumbleWaves,RumbleWPlasma-RumbleWaves	; reFirePlasma
	dw RumbleWBFG-RumbleWaves,RumbleWBFG-RumbleWaves	; reFireBFG
	dw RumbleWShotGunL-RumbleWaves,RumbleWShotGunR-RumbleWaves	; reFireSuperShotGun
	dw RumbleWIdleChainSawL-RumbleWaves,RumbleWIdleChainSawR-RumbleWaves	; reIdleChainSaw
	assert (pc()-RumbleWaveIndex) == reNum*4, "RumbleWaveIndex: one entry per effect"
