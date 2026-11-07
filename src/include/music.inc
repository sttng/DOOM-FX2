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
