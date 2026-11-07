	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                      RL MSGS        BY PLAY134                     *
;*                                                                    *
;**********************************************************************

;	include	rage.i
;	include	rle.i
;	include	gsumac.i

	; public _RLMsgs


	%section(ENGINE_GSUCODE)
	arch superfx

;
;	* * * * * * *       RL MSGs        * * * * * * *
;
;	A message is three 0-terminated lines (MSGA/B/C) of at most 9 characters each.
;	Shared lines are reused through the cached constants (asserted against their labels).
;
_RLMsgs:

PICKEDUP:	db "PICKED UP"	; (terminated by NULL)
NULL:	db 0
YOUGOTA:	db "YOU GOT A",0
;
RADSUITMSGA:	db "RADIATION",0
RADSUITMSGB:	db " SHIELDIN",0
RADSUITMSGC:	db "G SUIT",0
;
BERSERKMSGA:	db "BERSERK!",0
	BERSERKMSGB = $EFF9
	assert (BERSERKMSGB&$FFFFFF) == ((NULL)&$FFFFFF), "cached constant BERSERKMSGB is stale (tools/fixup.py)"
	BERSERKMSGC = $EFF9
	assert (BERSERKMSGC&$FFFFFF) == ((NULL)&$FFFFFF), "cached constant BERSERKMSGC is stale (tools/fixup.py)"
;
INVULNERABLEMSGA:	db "INVULNERA",0
INVULNERABLEMSGB:	db "BILITY!",0
	INVULNERABLEMSGC = $EFF9
	assert (INVULNERABLEMSGC&$FFFFFF) == ((NULL)&$FFFFFF), "cached constant INVULNERABLEMSGC is stale (tools/fixup.py)"
;
INVISIBLEMSGA:	db "PARTIAL I",0
INVISIBLEMSGB:	db "NVISIBILI",0
INVISIBLEMSGC:	db "TY",0
;
COMPUTERMAPMSGA:	db "COMPUTER ",0
COMPUTERMAPMSGB:	db "AREA MAP",0
	COMPUTERMAPMSGC = $EFF9
	assert (COMPUTERMAPMSGC&$FFFFFF) == ((NULL)&$FFFFFF), "cached constant COMPUTERMAPMSGC is stale (tools/fixup.py)"
;
LIGHTGOGGLESMSGA:	db "LIGHT AMP",0
LIGHTGOGGLESMSGB:	db "LIFICATIO",0
LIGHTGOGGLESMSGC:	db "N VISOR",0
;
DOORREDLOCKEDMSGA:	db "YOU NEED ",0
DOORREDLOCKEDMSGB:	db "A RED KEY",0
DOORREDLOCKEDMSGC:	db $21,0
;
DOORBLUELOCKEDMSGA:	db "YOU NEED ",0
DOORBLUELOCKEDMSGB:	db "A BLUE KE",0
DOORBLUELOCKEDMSGC:	db "Y!",0
;
DOORYELLOWLOCKEDMSGA:	db "YOU NEED ",0
DOORYELLOWLOCKEDMSGB:	db "A YELLOW ",0
DOORYELLOWLOCKEDMSGC:	db "KEY!",0
;
	ARMORMSGA = $EFF0
	assert (ARMORMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant ARMORMSGA is stale (tools/fixup.py)"
ARMORMSGB:	db " THE ARMO",0
ARMORMSGC:	db 'R',0
;
	MEGAARMORMSGA = $EFF0
	assert (MEGAARMORMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant MEGAARMORMSGA is stale (tools/fixup.py)"
MEGAARMORMSGB:	db " THE MEGA",0
MEGAARMORMSGC:	db "ARMOR",0
;
	HEALTHBONUSMSGA = $EFF0
	assert (HEALTHBONUSMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant HEALTHBONUSMSGA is stale (tools/fixup.py)"
HEALTHBONUSMSGB:	db " A HEALTH",0
BONUS:	db " BONUS",0
	HEALTHBONUSMSGC = $F0EC
	assert (HEALTHBONUSMSGC&$FFFFFF) == ((BONUS)&$FFFFFF), "cached constant HEALTHBONUSMSGC is stale (tools/fixup.py)"
;
	ARMORBONUSMSGA = $EFF0
	assert (ARMORBONUSMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant ARMORBONUSMSGA is stale (tools/fixup.py)"
ARMORBONUSMSGB:	db " AN ARMOR",0
	ARMORBONUSMSGC = $F0EC
	assert (ARMORBONUSMSGC&$FFFFFF) == ((BONUS)&$FFFFFF), "cached constant ARMORBONUSMSGC is stale (tools/fixup.py)"
;
SUPERCHARGEMSGA:	db "SUPERCHAR",0
SUPERCHARGEMSGB:	db "GE!",0
	SUPERCHARGEMSGC = $EFF9
	assert (SUPERCHARGEMSGC&$FFFFFF) == ((NULL)&$FFFFFF), "cached constant SUPERCHARGEMSGC is stale (tools/fixup.py)"
;
	REDKEYMSGA = $EFF0
	assert (REDKEYMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant REDKEYMSGA is stale (tools/fixup.py)"
REDKEYMSGB:	db " A RED KE",0
REDKEYMSGC:	db 'Y',0
;
	REDKEYCARDMSGA = REDKEYMSGA
	REDKEYCARDMSGB = $F10B
	assert (REDKEYCARDMSGB&$FFFFFF) == ((REDKEYMSGB)&$FFFFFF), "cached constant REDKEYCARDMSGB is stale (tools/fixup.py)"
	REDKEYCARDMSGC = $F115
	assert (REDKEYCARDMSGC&$FFFFFF) == ((REDKEYMSGC)&$FFFFFF), "cached constant REDKEYCARDMSGC is stale (tools/fixup.py)"
;
	BLUEKEYMSGA = $EFF0
	assert (BLUEKEYMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant BLUEKEYMSGA is stale (tools/fixup.py)"
BLUEKEYMSGB:	db " A BLUE K",0
BLUEKEYMSGC:	db "EY",0
;
	BLUEKEYCARDMSGA = BLUEKEYMSGA
	BLUEKEYCARDMSGB = $F117
	assert (BLUEKEYCARDMSGB&$FFFFFF) == ((BLUEKEYMSGB)&$FFFFFF), "cached constant BLUEKEYCARDMSGB is stale (tools/fixup.py)"
	BLUEKEYCARDMSGC = $F121
	assert (BLUEKEYCARDMSGC&$FFFFFF) == ((BLUEKEYMSGC)&$FFFFFF), "cached constant BLUEKEYCARDMSGC is stale (tools/fixup.py)"
;
	YELLOWKEYMSGA = $EFF0
	assert (YELLOWKEYMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant YELLOWKEYMSGA is stale (tools/fixup.py)"
YELLOWKEYMSGB:	db " A YELLOW",0
YELLOWKEYMSGC:	db " KEY",0
;
	YELLOWKEYCARDMSGA = YELLOWKEYMSGA
	YELLOWKEYCARDMSGB = $F124
	assert (YELLOWKEYCARDMSGB&$FFFFFF) == ((YELLOWKEYMSGB)&$FFFFFF), "cached constant YELLOWKEYCARDMSGB is stale (tools/fixup.py)"
	YELLOWKEYCARDMSGC = $F12E
	assert (YELLOWKEYCARDMSGC&$FFFFFF) == ((YELLOWKEYMSGC)&$FFFFFF), "cached constant YELLOWKEYCARDMSGC is stale (tools/fixup.py)"
;
	STIMPACKMSGA = $EFF0
	assert (STIMPACKMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant STIMPACKMSGA is stale (tools/fixup.py)"
STIMPACKMSGB:	db " A STIMPA",0
STIMPACKMSGC:	db "CK",0
;
	MEDIKITMSGA = $EFF0
	assert (MEDIKITMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant MEDIKITMSGA is stale (tools/fixup.py)"
MEDIKITMSGB:	db " A MEDIKI",0
MEDIKITMSGC:	db 'T',0
;
	CLIPMSGA = $EFF0
	assert (CLIPMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant CLIPMSGA is stale (tools/fixup.py)"
CLIPMSGB:	db " A CLIP",0
	CLIPMSGC = $EFF9
	assert (CLIPMSGC&$FFFFFF) == ((NULL)&$FFFFFF), "cached constant CLIPMSGC is stale (tools/fixup.py)"
;
	BULLETSBOXMSGA = $EFF0
	assert (BULLETSBOXMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant BULLETSBOXMSGA is stale (tools/fixup.py)"
ABOXOF:	db " A BOX OF",0
	BULLETSBOXMSGB = $F154
	assert (BULLETSBOXMSGB&$FFFFFF) == ((ABOXOF)&$FFFFFF), "cached constant BULLETSBOXMSGB is stale (tools/fixup.py)"
BULLETSBOXMSGC:	db " BULLETS",0
;
	ROCKETMSGA = $EFF0
	assert (ROCKETMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant ROCKETMSGA is stale (tools/fixup.py)"
ROCKETMSGB:	db " A ROCKET",0
	ROCKETMSGC = $EFF9
	assert (ROCKETMSGC&$FFFFFF) == ((NULL)&$FFFFFF), "cached constant ROCKETMSGC is stale (tools/fixup.py)"
;
	ROCKETSBOXMSGA = $EFF0
	assert (ROCKETSBOXMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant ROCKETSBOXMSGA is stale (tools/fixup.py)"
	ROCKETSBOXMSGB = $F154
	assert (ROCKETSBOXMSGB&$FFFFFF) == ((ABOXOF)&$FFFFFF), "cached constant ROCKETSBOXMSGB is stale (tools/fixup.py)"
ROCKETSBOXMSGC:	db " ROCKETS",0
;
	CELLMSGA = $EFF0
	assert (CELLMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant CELLMSGA is stale (tools/fixup.py)"
CELLMSGB:	db " AN ENERG",0
CELLMSGC:	db "Y CELL",0
;
	CELLPACKMSGA = $EFF0
	assert (CELLPACKMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant CELLPACKMSGA is stale (tools/fixup.py)"
CELLPACKMSGB:	db " A CELL P",0
CELLPACKMSGC:	db "ACK",0
;
	SHELLSMSGA = $EFF0
	assert (SHELLSMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant SHELLSMSGA is stale (tools/fixup.py)"
SHELLSMSGB:	db " 4 SHOTGU",0
SHELLSMSGC:	db "N SHELLS",0
;
	SHELLSBOXMSGA = $EFF0
	assert (SHELLSBOXMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant SHELLSBOXMSGA is stale (tools/fixup.py)"
SHELLSBOXMSGB:	db " A BOX OF",0
SHELLSBOXMSGC:	db " SHELLS",0
;
	BACKPACKMSGA = $EFF0
	assert (BACKPACKMSGA&$FFFFFF) == ((PICKEDUP)&$FFFFFF), "cached constant BACKPACKMSGA is stale (tools/fixup.py)"
BACKPACKMSGB:	db " A BACKPA",0
BACKPACKMSGC:	db "CK",0
;
BFGMSGA:	db "THE BFG90",0
BFGMSGB:	db "00!  OH Y",0
BFGMSGC:	db "ES...",0
;
	if !RLDOOM2MONSTERS != 0
SUPERSHOTGUNMSGB:	db " SUPER SH",0
SUPERSHOTGUNMSGC:	db "OTGUN!",0
	endif
;
	CHAINGUNMSGA = $EFFA
	assert (CHAINGUNMSGA&$FFFFFF) == ((YOUGOTA)&$FFFFFF), "cached constant CHAINGUNMSGA is stale (tools/fixup.py)"
CHAINGUNMSGB:	db " CHAINGUN",0
CHAINGUNMSGC:	db $21,0
;
	ROCKETGUNMSGA = $EFFA
	assert (ROCKETGUNMSGA&$FFFFFF) == ((YOUGOTA)&$FFFFFF), "cached constant ROCKETGUNMSGA is stale (tools/fixup.py)"
ROCKETGUNMSGB:	db " ROCKET L",0
ROCKETGUNMSGC:	db "AUNCHER!",0
;
	PLASMAGUNMSGA = $EFFA
	assert (PLASMAGUNMSGA&$FFFFFF) == ((YOUGOTA)&$FFFFFF), "cached constant PLASMAGUNMSGA is stale (tools/fixup.py)"
PLASMAGUNMSGB:	db " PLASMA G",0
PLASMAGUNMSGC:	db "UN!",0
;
	SHOTGUNMSGA = $EFFA
	assert (SHOTGUNMSGA&$FFFFFF) == ((YOUGOTA)&$FFFFFF), "cached constant SHOTGUNMSGA is stale (tools/fixup.py)"
SHOTGUNMSGB:	db " SHOTGUN!",0
	SHOTGUNMSGC = $EFF9
	assert (SHOTGUNMSGC&$FFFFFF) == ((NULL)&$FFFFFF), "cached constant SHOTGUNMSGC is stale (tools/fixup.py)"
;
CHAINSAWMSGA:	db "A CHAINSA",0
CHAINSAWMSGB:	db "W! FIND S",0
CHAINSAWMSGC:	db "OME MEAT!",0
;
;	>>>   SAVE GAMES   <<<	(this port)
;
GAMESAVEDMSGA:	db "GAME SAVE",0
GAMESAVEDMSGB:	db "D.",0
NOROOMMSGA:	db "NOT ENOUG",0
NOROOMMSGB:	db "H ROOM TO",0
NOROOMMSGC:	db " SAVE.",0
