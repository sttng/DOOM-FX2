includeonce
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*            SCULPTURED SOFTWARE MUSIC DRIVER INCLUDE MODULE         *
;*                                                                    *
;**********************************************************************


	incsrc "src/rlmus/dcom.inc"
	incsrc "src/rlmus/doommus.inc"
;
;	(this port) The demon death sample (sgtdth) is never played (the demon dies
;	with the imp's sound); tools/wad2soundfx.py puts DOOM II's super shotgun
;	(DSDSHTGN) into its slot.
	dshtgn_eff = sgtdth_eff
;	Its two quieter variants (also never played) are the chainsaw's raising and
;	hitting sounds (DSSAWUP, DSSAWHIT); sawful_eff plays the
;	cutting sound (DSSAWFUL).
	sawup_eff = sgtdth2_eff
	sawhit_eff = sgtdth3_eff
;	The imp's "active" sound (DSBGACT, effects $1C, $36, $50) is never played
;	either: its slot holds DOOM II's arch-vile fire (DSFLAMST, DSFLAME).
	vilefire_eff = $1C
	vilefire2_eff = $36
	vilefire3_eff = $50
;	The player death's quieter variants (never played: the player dies at full
;	volume) are DOOM II's corpse rising (DSSLOP: the arch-vile's resurrection).
	vileraise_eff = $43
	vileraise2_eff = $5D
