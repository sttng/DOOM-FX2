	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       RGB PALETTE BLOCKS MODULE                    *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"


	%section(ENGINE_RAMCODE)
;
;	* * * * * * *       RGB PALETTE DATA BLOCKS       * * * * * * *
;
;_RLRGBs	equ	((**&$00ff8000)<<1)+(**&$7fff)+$8000
	_RLRGBs = $5C1878
	assert (_RLRGBs&$FFFFFF) == ((((snestopc(realbase())&$00FFFFFF)+$400000))&$FFFFFF), "cached constant _RLRGBs is stale (tools/fixup.py)"

RLRGBs:
	incbin "data/RLDATA/COLOUR/BASERGB.RGB"


;
;	* * * * * * *       TABLE OF RGB PALETTE ANIMATIONS       * * * * * * *
;
RLRGBAnimTable:
	dw lo16(RLRGBNormalAnim-RLRGBAnims)	; Normal
	dw lo16(RLRGBRadAnim-RLRGBAnims)	; Radiation Suit
	dw lo16(RLRGBBerserkAnim-RLRGBAnims)	; Berserk PowerUp
RLRGBBaseAnimTable:
	dw lo16(RLRGBNormalBaseAnim-RLRGBAnims)	; Normal Base
	dw lo16(RLRGBRadBaseAnim-RLRGBAnims)	; Radiation Suit Base
	dw lo16(RLRGBBerserkBaseAnim-RLRGBAnims)	; Berserk PowerUp Base
RLRGBPickAnimTable:
	dw lo16(RLRGBPickAnim1-RLRGBAnims)	; Pick Up 1
	dw lo16(RLRGBPickAnim2-RLRGBAnims)	; Pick Up 2
	dw lo16(RLRGBPickAnim3-RLRGBAnims)	; Pick Up 3
	dw lo16(RLRGBPickAnim4-RLRGBAnims)	; Pick Up 4
RLRGBHitAnimTable:
	dw lo16(RLRGBHitAnim1-RLRGBAnims)	; Hit 1
	dw lo16(RLRGBHitAnim2-RLRGBAnims)	; Hit 2
	dw lo16(RLRGBHitAnim3-RLRGBAnims)	; Hit 3
	dw lo16(RLRGBHitAnim4-RLRGBAnims)	; Hit 4
	dw lo16(RLRGBHitAnim5-RLRGBAnims)	; Hit 5
	dw lo16(RLRGBHitAnim6-RLRGBAnims)	; Hit 6
	dw lo16(RLRGBHitAnim7-RLRGBAnims)	; Hit 7
	dw lo16(RLRGBHitAnim8-RLRGBAnims)	; Hit 8


;
;	* * * * * * *       LIST OF RGB PALETTE ANIMATIONS       * * * * * * *
;
RLRGBAnims:
;
RLRGBNormalAnim:
RLRGBNormalBaseAnim:
	dw lo16(RLRGBs+(0*512)),$7FFF	; Normal Palette Base
	dw 0	; Restart Animation
;
RLRGBRadAnim:
RLRGBRadBaseAnim:
	dw lo16(RLRGBs+(13*512)),$7FFF	; Radiation Suit Base
	dw 0
;
RLRGBBerserkAnim:
	dw lo16(RLRGBs+(4*512)),5	; Berserk PowerUp
	dw lo16(RLRGBs+(3*512)),5
RLRGBBerserkBaseAnim:
	dw lo16(RLRGBs+(2*512)),$7FFF	; Berserk PowerUp Base
	dw 0
;
RLRGBPickAnim1:
	dw lo16(RLRGBs+(9*512)),15	; Pick Up 1
	dw 0
RLRGBPickAnim2:
	dw lo16(RLRGBs+(10*512)),8	; Pick Up 2
	dw lo16(RLRGBs+(9*512)),7
	dw 0
RLRGBPickAnim3:
	dw lo16(RLRGBs+(11*512)),6	; Pick Up 3
	dw lo16(RLRGBs+(10*512)),6
	dw lo16(RLRGBs+(9*512)),3
	dw 0
RLRGBPickAnim4:
	dw lo16(RLRGBs+(12*512)),5	; Pick Up 4
	dw lo16(RLRGBs+(11*512)),3
	dw lo16(RLRGBs+(10*512)),3
	dw lo16(RLRGBs+(9*512)),3
	dw 0
;
RLRGBHitAnim1:
	dw lo16(RLRGBs+(1*512)),15	; Hit 1
	dw 0
RLRGBHitAnim2:
	dw lo16(RLRGBs+(2*512)),8	; Hit 2
	dw lo16(RLRGBs+(1*512)),7
	dw 0
RLRGBHitAnim3:
	dw lo16(RLRGBs+(3*512)),6	; Hit 3
	dw lo16(RLRGBs+(2*512)),6
	dw lo16(RLRGBs+(1*512)),3
	dw 0
RLRGBHitAnim4:
	dw lo16(RLRGBs+(4*512)),5	; Hit 4
	dw lo16(RLRGBs+(3*512)),3
	dw lo16(RLRGBs+(2*512)),3
	dw lo16(RLRGBs+(1*512)),3
	dw 0
RLRGBHitAnim5:
	dw lo16(RLRGBs+(5*512)),4	; Hit 5
	dw lo16(RLRGBs+(4*512)),3
	dw lo16(RLRGBs+(3*512)),3
	dw lo16(RLRGBs+(2*512)),3
	dw lo16(RLRGBs+(1*512)),2
	dw 0
RLRGBHitAnim6:
	dw lo16(RLRGBs+(6*512)),4	; Hit 6
	dw lo16(RLRGBs+(5*512)),3
	dw lo16(RLRGBs+(4*512)),3
	dw lo16(RLRGBs+(3*512)),2
	dw lo16(RLRGBs+(2*512)),2
	dw lo16(RLRGBs+(1*512)),2
	dw 0
RLRGBHitAnim7:
	dw lo16(RLRGBs+(7*512)),4	; Hit 7
	dw lo16(RLRGBs+(6*512)),3
	dw lo16(RLRGBs+(5*512)),2
	dw lo16(RLRGBs+(4*512)),2
	dw lo16(RLRGBs+(3*512)),2
	dw lo16(RLRGBs+(2*512)),2
	dw lo16(RLRGBs+(1*512)),2
	dw 0
RLRGBHitAnim8:
	dw lo16(RLRGBs+(8*512)),3	; Hit 8
	dw lo16(RLRGBs+(7*512)),2
	dw lo16(RLRGBs+(6*512)),2
	dw lo16(RLRGBs+(5*512)),2
	dw lo16(RLRGBs+(4*512)),2
	dw lo16(RLRGBs+(3*512)),2
	dw lo16(RLRGBs+(2*512)),2
	dw lo16(RLRGBs+(1*512)),2
	dw 0
