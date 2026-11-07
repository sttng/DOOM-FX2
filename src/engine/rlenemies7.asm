	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                       ENEMIES HANDLING MODULE 7                    *
;*                                                                    *
;*                    ENEMIES DATA TABLES/STRUCTURES                  *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"


	%section(ENGINE_GSUCODE)
	arch superfx


;
;	* * * * * * *       VELOCITY TABLES FOR MOVEMENT       * * * * * * *
;
_RLMoveVelocities:

; macro mvMAC -> see src/macros.inc

;
;	>>>   SOLDIER, SERGEANT, CACODEMON   <<<
;
_RLMVSoldier:
_RLMVSergeant:
_RLMVCacoDemon:
	%mvMAC(8)	; EASY->HARD
	%mvMAC(16)	; NIGHTMARE

;
;	>>>   TROOPER, DEMON (useID2 = 0), BARONOFHELL, CYBERDEMON, SPIDERDEMON   <<<
;
_RLMVTrooper:
	if useID2 == 0
_RLMVDemon:
	endif
_RLMVBaronOfHell:
_RLMVCyberDemon:
_RLMVSpiderDemon:
	%mvMAC(10)	; EASY->HARD
	%mvMAC(20)	; NIGHTMARE

;
;	>>>   DEMON   <<<
;
	if useID2 != 0
_RLMVDemon:
	%mvMAC(16)	; EASY->HARD
	%mvMAC(32)	; NIGHTMARE
	endif

;
;	>>>   LOST SOUL   <<<
;
_RLMVLostSoul:
	%mvMAC(20)	; EASY->HARD
	%mvMAC(40)	; NIGHTMARE
