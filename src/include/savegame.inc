includeonce
;
;	* * * * * * *       SAVE GAMES       * * * * * * *   (see savegame.asm)
;
	RAMIMAGEEND = $71ACC0	; (this port) the level RAM image ($71:0000) ends below the wall band
				;  buffer and the walls' colour maps (_RLBandBuffer, RAMWALLCMAPS, rlram7.asm)
	RAMWALLCMAPS = $71AF00	; 33 colour maps for the walls, copied from ROM at level start
	SAVEBASE = $71D000	; save area: top of GSU RAM bank $71 (battery backed; 12 KB: saves
				;  store only what changed since the level started, 1-3 KB)
	SAVEDATA = SAVEBASE+$40
	SAVEEND = $720000
	SAVESLOTS = 3
	SaveHash = $7E6000	; WRAM work areas (free while a level runs)
	SaveRaw = $7E8000	; (8 KB hash, 28 KB state)
	SaveText = $7EF000
	SaveRawMax = SaveText-SaveRaw
	SaveComp = $7FD600	; packed state: bank $7F above RAM3 (long addressing)
	SaveCompMax = $7FFD00-SaveComp	; ($7F:FD00 = monitor)
