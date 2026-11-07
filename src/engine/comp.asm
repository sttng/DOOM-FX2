	arch 65816
;**********************************************************************
;*                                                                    *
;*                      P R O J E C T :   R A G E                     *
;*                                                                    *
;*     C O M P R E S S I O N / D E C O M P R E S S I O N   MODULE     *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"

	; public DeCompress
	; public UnPackRL


	%section(COMP)

;
;	* * * * * * *       DECOMPRESS DATA BLOCK       * * * * * * *
;
;	.X = Compressed Data Stream
;	.A = Compressed Data Bank
;	.Y = DeCompressed Data Buffer
;	.B = DeCompressed Data Bank
;
;	.Y = Size of DeCompressedData
;	.D = Compressed Data Bank
;	[TEMP]  = DeCompressedData
;	[TEMP2] = DeCompressedDataSize
;	[TEMP2+2] = Compression Format
;
;
;
;	(DEFAULT) AND (RL) SPECIFIC VARIABLES
;
	DDPtr = 0	; DeCompressedData Pointer
	assert (DDPtr&$FFFFFF) == ((Temp)&$FFFFFF), "cached constant DDPtr is stale (tools/fixup.py)"
	DDPtr2 = 3	; DeCompressedData Pointer 2
	assert (DDPtr2&$FFFFFF) == ((Temp+3)&$FFFFFF), "cached constant DDPtr2 is stale (tools/fixup.py)"
	CDTemp = 6	; Temporary Variable
	assert (CDTemp&$FFFFFF) == ((Temp+6)&$FFFFFF), "cached constant CDTemp is stale (tools/fixup.py)"
	CDPtr = 8	; CompressedData Pointer
	assert (CDPtr&$FFFFFF) == ((Temp2)&$FFFFFF), "cached constant CDPtr is stale (tools/fixup.py)"
	DDPtr0 = 11	; DeCompressedData START Pointer
	assert (DDPtr0&$FFFFFF) == ((Temp2+3)&$FFFFFF), "cached constant DDPtr0 is stale (tools/fixup.py)"
	CDData = 13	; CompressedData StreamByte/Word
	assert (CDData&$FFFFFF) == ((Temp2+5)&$FFFFFF), "cached constant CDData is stale (tools/fixup.py)"


;
;	(ECLIPSE) SPECIFIC VARIABLES
;

	UneclipseSource = CDPtr
	UneclipseDest = DDPtr

	UneclipseLength = $10
	assert (UneclipseLength&$FFFFFF) == ((Temp3)&$FFFFFF), "cached constant UneclipseLength is stale (tools/fixup.py)"
	UneclipseHalfWay = $12
	assert (UneclipseHalfWay&$FFFFFF) == ((Temp3+2)&$FFFFFF), "cached constant UneclipseHalfWay is stale (tools/fixup.py)"
	UneclipseTop = $14
	assert (UneclipseTop&$FFFFFF) == ((Temp3+4)&$FFFFFF), "cached constant UneclipseTop is stale (tools/fixup.py)"

	UneclipseBack = $16
	assert (UneclipseBack&$FFFFFF) == ((Temp3+6)&$FFFFFF), "cached constant UneclipseBack is stale (tools/fixup.py)"
	UneclipseGo = $18
	assert (UneclipseGo&$FFFFFF) == ((Temp4)&$FFFFFF), "cached constant UneclipseGo is stale (tools/fixup.py)"

	Temp01 = $1A
	assert (Temp01&$FFFFFF) == ((Temp4+2)&$FFFFFF), "cached constant Temp01 is stale (tools/fixup.py)"
	Temp02 = $1C
	assert (Temp02&$FFFFFF) == ((Temp4+4)&$FFFFFF), "cached constant Temp02 is stale (tools/fixup.py)"
	Temp03 = $1E
	assert (Temp03&$FFFFFF) == ((Temp4+6)&$FFFFFF), "cached constant Temp03 is stale (tools/fixup.py)"



	; dbr ?
	; dpr 0
	; mode 'AX'
DeCompress:
	stx.b CDPtr	; .X/.A = CompressedData
	sta.b CDPtr+2
	sta.b DDPtr+1	; Remember BANK of DeCompressed Data
	sty.b DDPtr	; .Y/.B = DeCompressedData
	pha
	plb	; DBR = Compressed data
	lda.b (CDPtr)	; Get TYPE of Compression
	plb	; DBR = DeCompressed Data
	inx	; Move to next Compressed Word
	inx
	stx.b CDPtr
	tax
	phx
;
	jsr.w (DeCompJumps,x)	; DeCompress the data!
;
	plx	; TEMP2+2 = Compression Format Used
	stx.b Temp2+2
	sty.b Temp2	; TEMP2 = DeCompressed Data Size
	phk
	plb	; DBR = ROM somewhere always!
	rtl

;
;	* * * * * * *       DECOMPRESSION TYPES       * * * * * * *
;
DeCompJumps:
	dd DeCompNone	; DEFAULT (NO) Compression
	dd UnPackRL	; RLC Compression
	dd UnPackEclipse	; ECLIPSE Compression XSize1
	dd UnPackEclipse	; ECLIPSE Compression XSize2


;
;	* * * * * * *       NO COMPRESSION       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'AX'
DeCompNone:
	lda.b [CDPtr]	; Get SIZE of DeCompressed Data
	tay
	inc.b CDPtr	; Move to next Word
	inc.b CDPtr
	lda.b CDPtr	; Dest = Source
	sta.b DDPtr
	lda.b CDPtr+2
	sta.b DDPtr+2
	rts


;
;	* * * * * * *       UNPACK RLC DATA       * * * * * * *
;
	; dbr ?
	; dpr 0
	; mode 'aX'
UnPackRL0:
	phb	; Save Bank
	jsr.w UnPackRL0A
	plb	; Restore Bank
	rtl
;
UnPackRL0A:
	rep #$20		; mode 'A!'
	lda.b [_MDChunkPtr]	; Save DeCompressed Size
	pha
	txa	; Save Compressed Size
	and.w #$7FFF
	tax
	phx
;
	txy	; Copy Compressed Data to DeCompBuffer
	iny
	sep #$20		; mode 'a!'
UnPackRL0E:
	lda.b [_MDChunkPtr],y
	sta.l _MDDeCompBuffer2-1,x
	dey
	dex
	bne UnPackRL0E
;
	ldx.w #lo16(_MDDeCompBuffer2)	; CompressedData
	stx.b CDPtr
	ldx.w #lo16(_MDDeCompBuffer)	; DeCompressedData
	stx.b DDPtr0	; (DDPTR0) = START of DeCompressedData
	stx.b _MDChunkPtr
	lda.b #bank(_MDDeCompBuffer)
	sta.b CDPtr+2
	sta.b DDPtr+2
	sta.b _MDChunkPtr+2
	pha
	plb	; DBR = DeCompressed Data
;
	rep #$20		; mode 'A!'
	pla	; [CDPtr] = END of CompressedData
	clc
	adc.b CDPtr
	dec a
	dec a
	sta.b CDPtr
	lda.b 1,s	; (DDPTR) = END of DeCompressedData
	clc
	adc.b DDPtr0
	sta.b DDPtr
	jmp.w UnPackRL2
;
UnPackRL:
	lda.b DDPtr	; (DDPTR0) = START of DeCompressedData
	sta.b DDPtr0
	clc
	adc.b [CDPtr]	; DeCompressed Size
	sta.b DDPtr	; (DDPTR) = END of DeCompressedData
	lda.b [CDPtr]	; Save SIZE of DeCompressedData
	pha
	ldy.w #2
	lda.b [CDPtr],y	; (Compressed Size-2)
	clc
	adc.b CDPtr
	sta.b CDPtr	; [CDPtr] = END of CompressedData
;
;	>>>   GET FIRST WORD   <<<
;
UnPackRL2:
	lda.b [CDPtr]
	jmp.w UPK200	; Start Decompressing!

;
;	>>>   GET NEXT WORD   <<<
;
UPK100:
	dec.b CDPtr	; Move to next Word
	dec.b CDPtr
	lda.b [CDPtr]	; Get next Word
	sec
	ror a
	jmp.w UPK210
;
;	>>>   MAIN LOOP   <<<
;
UPK200:
	lsr a
	beq UPK100	; Finished this word
UPK210:
	bcs UPK500	; Special
	lsr a	; Regular
	bne UPK250	; Need another word?
	dec.b CDPtr
	dec.b CDPtr
	lda.b [CDPtr]
	sec
	ror a
;
;	>>>   %0.1 = 2 byte SIZE to read from OFFSET of 8-bits   <<<
;
UPK250:
	ldy.w #2-1	; 2-byte Copy
	ldx.w #8-1	; 8-bit Size
	bcc UPK280
	jmp.w UPK600
;
;	>>>   %0.0 = 3-bit SIZE (-1) to read from STREAM   <<<
;
UPK280:
	ldy.w #0
	ldx.w #3-1	; 3-bit Size (-1)
UPK300:
	jsr.w RDBits	; Read .X Bits
	tax
	tya	; .Y = BaseCount-1
	clc
	adc.b CDData	; BitStream Value
	tay	; .Y = (#Bytes-1) to Read from Stream
	txa
UPK320:
	ldx.w #8-1	; Get a byte
	jsr.w RDBits
	tax
	dec.b DDPtr
	sep #$20		; mode 'a!'
	lda.b CDData
	sta.b (DDPtr)
	rep #$20		; mode 'A!'
	txa
	dey	; One less byte to do
	bpl UPK320
;
;	>>>   CHECK IF COMPLETE   <<<
;
UPK800:
	ldy.b DDPtr	; Finished yet?
	cpy.b DDPtr0
	bcc UPK900	; Yes!
	bne UPK200	; No, keep decompressing!
;
;	>>>   FINISHED   <<<
;
UPK900:
	ply	; .Y = Size of DeCompressed Data
	rts

;
;	>>>   %1.11 = 8-bit SIZE (+9) to read from STREAM   <<<
;
UPK400:
	ldy.w #9-1	; 9-byte Minimum
	ldx.w #8-1	; 8-bit Size
	jmp.w UPK300

;
;	>>>   OFFSET-COPIES   <<<
;
UPK500:
	ldx.w #2-1	; Get 2 Bits
	jsr.w RDBits
	ldy.b CDData
	cpy.w #2
	bcc UPK550	; MidJumps #0/#1 (Offset9Or10)
	cpy.w #3
	beq UPK400	; BigJump (Loop900)
;
;	>>>   %1.10 = 8-bit SIZE (-5) to read from OFFSET of 12-bits   <<<
;	(Special300)
;
	ldx.w #8-1
	jsr.w RDBits
	ldy.b CDData	; #Bytes
	iny
	iny
	iny
	iny
	ldx.w #12-1	; Offset of 12 bits
	jmp.w UPK600

;
;	>>>   %1.00 = 3 byte SIZE to read from OFFSET of 9-bits   <<<
;	>>>   %1.01 = 4 byte SIZE to read from OFFSET of 10-bits   <<<
;	(Offset9Or10)
;
UPK550:
	sta.b CDTemp
	lda.b CDData	; Offset is 9/10 bits
;	clc
	adc.w #9-1
	tax
	lda.b CDData	; #Bytes = 3/4
	clc
	adc.w #3-1
	tay
	lda.b CDTemp
;
;	>>>   GET OFFSET AND COPY FROM MEMORY   <<<
;
;	.X = #Bits to read from stream as OFFSET
;	.Y = #Bytes to COPY -1 from MEMORY at offset
;
UPK600:
	jsr.w RDBits	; Read Offset Size
	tax
	lda.b DDPtr	; (DDPTR2) = OffsettedDataPtr
	clc
	adc.b CDData
	sta.b DDPtr2
UPK650:
	dec.b DDPtr	; Move to next byte
	dec.b DDPtr2
	sep #$20		; mode 'a!'
	lda.b (DDPtr2)	; Get Previously UnPacked Byte
	sta.b (DDPtr)
	rep #$20		; mode 'A!'
	dey	; One less byte to copy
	bpl UPK650	; Not finished yet
	txa
	jmp.w UPK800
;
;	>>>   READ BITS FROM BITSTREAM   <<<
;
;	.X = #Bits to read
;
;	(CDDATA) = Byte/Word read from BitStream
;
RDBits:
	stz.b CDData	; Clear (CDDATA)
RDBits1:
	lsr a	; Any more data?
	bne RDBits5	; Yes
	dec.b CDPtr	; No, get next word
	dec.b CDPtr
	lda.b [CDPtr]
	sec
	ror a
RDBits5:
	rol.b CDData	; Add data to BYTE/WORD
	dex
	bpl RDBits1
	rts



;
;	* * * * * * *       ECLIPSE COMPRESSION       * * * * * * *
;
;*****************************************************************************
;
;  Uneclipse:
;
; 	This program unpacks data packed by ECLIPSE.
;
;	Entry format:  
;				A, X, and Y are 16 bit.
;			      	DP should be set to $0000.	
;				DB - Set to destination bank
;
;	To uneclipse, setup these variables and jsl Uneclipse.
;
;				UneclipseSource
;				UneclipseDest
;
;      		Upon exit, the length of the decompressed data is in A, 
;       UneclipseSource points to the last byte of the source data,
;	and UneclipseDest remains unchanged.  All other variables must
;	be considered UNKNOWN.
;
;
;		Uneclipsing time is on the average 45% of unchisling time. 
;
;*****************************************************************************

;*****************************************************************************
;
; Uneclipse code
;
; 		The packed data has the following header:
;
;	Word - Total unpacked length
;         	Byte - Stagger (1 or 2)
;
;		A stagger of one means that the data is packed in a normal
;	sequence.  
;		A stagger of two means that the data was re-arranged
;	before it was packed.  The arrangement is such that all the
;	odd offset bytes get packed first, then all the even offset bytes
;	get packed second.  Unpacking a stagger of two requires two passes
;	through the destination buffer.  The first unpacks the odd bytes,
;	the second unpacks the even.
;
;		For speed reasons the data is compressed from the end to the
;	beginning.  Thus, data is decompressed from the end to the
;	beginning.
;
;		The packed data itself is a series of packets.  Each packet is
;  	identified in the first byte in the packet.  Assume that the
;	first byte in a packet is the HIGH BYTE.  Then the packets are:
;
;
;	1LLLLOOOOOOOOOOO - Pattern of length L+3 at offset O (forward)
;
;	01LLLLLL BBBBBBBB ... BBBBBBBBB - Unique byte run of length L+1
;
;	000LLLLLBBBBBBBB - Run of byte BBBBBBBB for length of L+2
;
;	00000000 - End of data
;
;	If stagger = 1
;
;	001OOOOO - Copy the single byte at offset OOOOOO+1
;
;	If stagger = 2,
;
;	001LLLLLBBBBBBBB - Incrementing series L+3 long ending in BBBBBBBB
;
;*****************************************************************************

	; mode 'AX'
	; dpr 0
	; dbr ?

UnPackEclipse:
ECL:
	lda.b [UneclipseSource]
	sta.b UneclipseLength	; Get unpacked size
	tay
	inc.b UneclipseSource	; Advance past unpacked size
	lda.b [UneclipseSource]	; Get stagger (xsize) value
	inc.b UneclipseSource
	inc.b UneclipseSource	; Advance past stagger value
	cmp.w #$200
	bcc .StartUneclipse1	; XSize = 1, Go do all bytes in order
	jmp.w .StartUneclipse2	; XSize = 2, First do odd bytes, then even

.StartUneclipse1:
	tya	; Point Y to the end of the
	adc.b UneclipseDest	;   destination buffer (data unpacks
	tay	;   from the end)
	lda.w #lo16(.Uneclipse1)
	sta.b UneclipseBack	; Point to unpack loop

.Uneclipse1:	; Get and identify next packet
	lda.b [UneclipseSource]
	bit.w #$0080
	bne .Pattern1	; Copy a prev. unpacked pattern
	bit.w #$0040
	bne .Unique1	; Move in unique bytes
	bit.w #$0020
	bne .SingleUnique	; Move in a single unique byte
	jmp.w .RunLength1	; Copy in a run of a byte

.SingleUnique:
	and.w #$1F	; Identify offset of single byte
	sta.b Temp01
	tya
	clc
	adc.b Temp01	; Form index to single byte
	tax
	dey	; Advance destination
	sep #$20
	lda.w 0,x	; Copy down a single byte
	sta.w 0,y
	rep #$20
	inc.b UneclipseSource	; Advance source
	jmp.w (UneclipseBack)	; Loop to do next packet

.Pattern1:
	tax
	xba
	and.w #$7FF	; Identify pattern offset
	sta.b Temp01
	txa
	and.w #$0078
	lsr a	; Get pattern length (3-18)
	lsr a
	tax
	lsr a
	sta.b Temp02
	lda.l .Pattern1Table,x	; Use length to set jump point
	sta.b UneclipseGo	;   into unrolled code
	tya
	sbc.w #2	; (carry clear) Advance
	sbc.b Temp02	;   destination index
	tay
	adc.b Temp01	; (carry set) Set up offset to
	tax	;   source as an index
	lda.b UneclipseSource
	inc a
	inc a	; Advance source
	sta.b UneclipseSource
	jmp.w (UneclipseGo)	; Go copy pattern

.Unique1:
	tyx	; Switch indexes
	and.w #$003F
	tay	; Form a length index (1 - 65)
	sta.b Temp03
	lsr a	; Odd or even length?
	bcs .DoUnique1
	iny	; Odd, so copy one unique byte
	dex	; Advance destination
	sep #$20
	lda.b [UneclipseSource],y	; Get unique byte
	sta.w 0,x	; Store it to destination
	rep #$20
	dey	; Adjust length
	dey
	bmi .DoneUnique1	; Exit if length < 0
	cpy.w #6
	bcc .UniqueSmall1	; If less than 8 left, branch
.UniqueGroup1:
	txa
	sbc.w #8
	tax	; Advance destination by 8
	lda.b [UneclipseSource],y
	sta.w 6,x	; Move in a unique word
	dey
	dey	; Decrement length
	lda.b [UneclipseSource],y
	sta.w 4,x	; Again and again and again
	dey
	dey
	lda.b [UneclipseSource],y
	sta.w 2,x
	dey
	dey
	lda.b [UneclipseSource],y
	sta.w 0,x
	dey
	dey
	bmi .DoneUnique1	; Exit if length < 0
.DoUnique1:
	cpy.w #6	; If there are at least 4 more
	bcs .UniqueGroup1	;   words, do them as a group
.UniqueSmall1:
	lda.b [UneclipseSource],y	; Get a single unique word
	dex
	dex	; Advance destination
	sta.w 0,x	; Store it
	dey
	dey	; Decrement length
	bpl .UniqueSmall1	; Loop until all done
.DoneUnique1:
	txy	; Put destination back in Y
	lda.b UneclipseSource
	clc	; Advance source by length+1
	adc.w #2
	adc.b Temp03
	sta.b UneclipseSource
	jmp.w (UneclipseBack)	; Loop to do next packet

.RunLength1:
	tax
	and.w #$FF00	; Take repeated byte and make
	sta.b Temp01	;   it into a repeated word
	xba
	tsb.b Temp01
	txa
	and.w #$001F	; Get length (3-33)
	beq .DoneUneclipse1	; Zero indicates end of data, exit
	sta.b Temp03
	asl a
	tax	; Use length to get jump point
	lda.l .Run1Table-2,x	;   into unrolled code
	sta.b UneclipseGo
	tya
	sbc.w #1	; (carry clear) Advance
	sbc.b Temp03	;   destination
	tay
	lda.b UneclipseSource	; Advance source
	inc a
	inc a
	sta.b UneclipseSource
	lda.b Temp01	; Get repeated word
	jmp.w (UneclipseGo)	; Go repeat it

.DoneUneclipse1:
	ldy.b UneclipseLength	; Return length of data
	rts

.StartUneclipse2:
	tya
	clc
	adc.b UneclipseDest	; Calculate the end of destination
	sta.b UneclipseTop	;   buffer address
	tya
	eor.w #1	; Odd or even data length?
	lsr a
	tya
	adc.b UneclipseDest	; Set pointer to do odd bytes
	tay	;   beginning from end of dest.
	lda.b UneclipseDest
	inc a
	sta.b UneclipseHalfWay	; Address marks end of odd bytes
	lda.w #lo16(.Uneclipse2)
	sta.b UneclipseBack	; Point to unpack loop

.Uneclipse2:
	rep #$20	; Must force long acc.
	cpy.b UneclipseHalfWay	; Done with the odd bytes?
	bne .DoUneclipse2
	lda.b UneclipseLength	; If so, reset destination index
	lsr a	; to do the even bytes
	lda.b UneclipseLength
	adc.b UneclipseDest
	tay
	stz.b UneclipseHalfWay	; Just a precaution
.DoUneclipse2:
	lda.b [UneclipseSource]	; Get and identify next packet
	bit.w #$0080
	bne .Pattern2	; Copy a prev. unpacked pattern
	bit.w #$0040
	bne .Unique2	; Move in unique bytes
	bit.w #$0020
	bne .Delta2	; Make an incrementing series
	jmp.w .RunLength2	; Copy in a run of a byte

.Delta2:
	and.w #$1F	; Calculate a delta length (3-34)
	clc
	adc.w #3
	tax
	inc.b UneclipseSource
	lda.b [UneclipseSource]	; Get ending delta value
	inc.b UneclipseSource
	sep #$20	; Must be in byte mode
.Delta2Loop:
	dey
	dey	; Advance destination (stagger=2)
	sta.w 0,y	; Store byte
	dec a	; Advance byte
	dex
	bne .Delta2Loop	; Until length = 0
	jmp.w (UneclipseBack)	; Go do next packet

.Pattern2:
	tax
	xba
	and.w #$7FF	; Calculate offset of pattern
	sec
	rol a	; Multiply by 2 (stagger=2)
	sta.b Temp01
	txa
	and.w #$0078	; Calculate pattern length (3-18)
	lsr a
	lsr a
	tax
	sta.b Temp03	; Use length to set jump point
	lda.l .Pattern2Table,x	;   into unrolled code
	sta.b UneclipseGo
	tya
	sbc.w #5	; (carry clear) Advance
	sbc.b Temp03	;   destination index
	tay
	adc.b Temp01	; (carry set) Check to see if
	bcs .OverflowPattern2	;   pattern is in prev. stagger
	cmp.b UneclipseTop	;   while calculating its index
	bcc .DoPattern2
.OverflowPattern2:	; Pattern is in prev. stagger
	tax
	lda.b UneclipseLength	; Adjust pattern index to be
	eor.w #$0001	;   in odd stagger
	lsr a
	txa
	adc.w #0
	sec
	sbc.b UneclipseLength
.DoPattern2:
	tax	; X is pattern source index
	lda.b UneclipseSource
	inc a
	inc a
	sta.b UneclipseSource	; Advance source
	sep #$20	; Must be in byte mode
	jmp.w (UneclipseGo)	; Go copy pattern

.Unique2:
	tyx	; Swap indexes
	and.w #$003F	; Get length of unique string
	inc a	;   (1 - 65)
	tay
	sta.b Temp03
	sep #$20	; Must be in byte mode
	cpy.w #5	; If length < 5, skip group mode
	bcc .UniqueSmall2
.UniqueGroup2:
	rep #$20
	txa
	sbc.w #10
	tax	; Adjust destination index
	sep #$20
	lda.b [UneclipseSource],y	; Copy byte of unique string
	sta.w 8,x
	dey	; Advance source
	lda.b [UneclipseSource],y
	sta.w 6,x	; Do it 4 more times
	dey
	lda.b [UneclipseSource],y
	sta.w 4,x
	dey
	lda.b [UneclipseSource],y
	sta.w 2,x
	dey
	lda.b [UneclipseSource],y
	sta.w 0,x
	dey
	beq .DoneUnique2	; If length = 0, end
	cpy.w #5
	bcs .UniqueGroup2	; If more than 4, do as a group
.UniqueSmall2:
	lda.b [UneclipseSource],y	; Copy one byte of unique string
	dex
	dex	; Advance destination
	sta.w 0,x
	dey
	bne .UniqueSmall2
.DoneUnique2:
	rep #$20
	txy	; Put dest. back into Y
	lda.b UneclipseSource
	inc a	; Advance source by length+1
	clc
	adc.b Temp03
	sta.b UneclipseSource
	jmp.w (UneclipseBack)	; Go do next packet

.RunLength2:
	sta.b Temp01	; Save byte to repeat
	and.w #$001F	; Get length of run (3 - 34)
	beq .DoneUneclipse2	; Zero indicates end of data
	asl a
	sta.b Temp03
	tax	; Use length to get jump point
	lda.l .Run2Table-2,x	;   into unrolled code
	sta.b UneclipseGo
	tya
	sbc.w #3	; (carry clear) Adjust destination
	sbc.b Temp03	;   index
	tay
	lda.b UneclipseSource	; Adjust source
	inc a
	inc a
	sta.b UneclipseSource
	sep #$20	; Must be in byte mode
	lda.b Temp01+1	; Get byte to repeat
	jmp.w (UneclipseGo)	; Go repeat byte

.DoneUneclipse2:
	ldy.b UneclipseLength	; Return unpacked data length
	rts

.PatternOddCode:
	lda.w 15,x	; Offset 00
	sta.w 15,y
	lda.w 13,x	; Offset 06
	sta.w 13,y
	lda.w 11,x	; Offset 12
	sta.w 11,y
	lda.w 9,x	; Offset 18
	sta.w 9,y
	lda.w 7,x	; Offset 24
	sta.w 7,y
	lda.w 5,x	; Offset 30
	sta.w 5,y
	lda.w 3,x	; Offset 36
	sta.w 3,y
	lda.w 1,x	; Offset 42
	sta.w 1,y
	lda.w 0,x
	sta.w 0,y
	jmp.w (UneclipseBack)

.PatternCode:
	lda.w 34,x	; Offset 00
	sta.w 34,y
	lda.w 32,x	; Offset 06
	sta.w 32,y
	lda.w 30,x	; Offset 12
	sta.w 30,y
	lda.w 28,x	; Offset 18
	sta.w 28,y
	lda.w 26,x	; Offset 24
	sta.w 26,y
	lda.w 24,x	; Offset 30
	sta.w 24,y
	lda.w 22,x	; Offset 36
	sta.w 22,y
	lda.w 20,x	; Offset 42
	sta.w 20,y
	lda.w 18,x	; Offset 48
	sta.w 18,y
	lda.w 16,x	; Offset 54
	sta.w 16,y
	lda.w 14,x	; Offset 60
	sta.w 14,y
	lda.w 12,x	; Offset 66
	sta.w 12,y
	lda.w 10,x	; Offset 72
	sta.w 10,y
	lda.w 8,x	; Offset 78
	sta.w 8,y
	lda.w 6,x	; Offset 84
	sta.w 6,y
	lda.w 4,x	; Offset 90
	sta.w 4,y
	lda.w 2,x	; Offset 96
	sta.w 2,y
	lda.w 0,x	; Offset 102
	sta.w 0,y
	jmp.w (UneclipseBack)

.RunOddCode:
	sta.w 31,y	; Offset 00
	sta.w 29,y	; Offset 03
	sta.w 27,y	; Offset 06
	sta.w 25,y	; Offset 09
	sta.w 23,y	; Offset 12
	sta.w 21,y	; Offset 15
	sta.w 19,y	; Offset 18
	sta.w 17,y	; Offset 21
	sta.w 15,y	; Offset 24
	sta.w 13,y	; Offset 27
	sta.w 11,y	; Offset 30
	sta.w 9,y	; Offset 33
	sta.w 7,y	; Offset 36
	sta.w 5,y	; Offset 39
	sta.w 3,y	; Offset 42
	sta.w 1,y	; Offset 45
	sta.w 0,y
	jmp.w (UneclipseBack)

.RunCode:
	sta.w 64,y	; Offset 00
	sta.w 62,y	; Offset 03
	sta.w 60,y	; Offset 06
	sta.w 58,y	; Offset 09
	sta.w 56,y	; Offset 12
	sta.w 54,y	; Offset 15
	sta.w 52,y	; Offset 18
	sta.w 50,y	; Offset 21
	sta.w 48,y	; Offset 24
	sta.w 46,y	; Offset 27
	sta.w 44,y	; Offset 30
	sta.w 42,y	; Offset 33
	sta.w 40,y	; Offset 36
	sta.w 38,y	; Offset 39
	sta.w 36,y	; Offset 42
	sta.w 34,y	; Offset 45
	sta.w 32,y	; Offset 48
	sta.w 30,y	; Offset 51
	sta.w 28,y	; Offset 54
	sta.w 26,y	; Offset 57
	sta.w 24,y	; Offset 60
	sta.w 22,y	; Offset 63
	sta.w 20,y	; Offset 66
	sta.w 18,y	; Offset 69
	sta.w 16,y	; Offset 72
	sta.w 14,y	; Offset 75
	sta.w 12,y	; Offset 78
	sta.w 10,y	; Offset 81
	sta.w 8,y	; Offset 84
	sta.w 6,y	; Offset 87
	sta.w 4,y	; Offset 90
	sta.w 2,y	; Offset 93
	sta.w 0,y
	jmp.w (UneclipseBack)

.Pattern1Table:
	dw lo16(.PatternOddCode)+42	; Length = 03
	dw lo16(.PatternCode)+96	; Length = 04
	dw lo16(.PatternOddCode)+36	; Length = 05
	dw lo16(.PatternCode)+90	; Length = 06
	dw lo16(.PatternOddCode)+30	; Length = 07
	dw lo16(.PatternCode)+84	; Length = 08
	dw lo16(.PatternOddCode)+24	; Length = 09
	dw lo16(.PatternCode)+78	; Length = 10
	dw lo16(.PatternOddCode)+18	; Length = 11
	dw lo16(.PatternCode)+72	; Length = 12
	dw lo16(.PatternOddCode)+12	; Length = 13
	dw lo16(.PatternCode)+66	; Length = 14
	dw lo16(.PatternOddCode)+6	; Length = 15
	dw lo16(.PatternCode)+60	; Length = 16
	dw lo16(.PatternOddCode)+0	; Length = 17
	dw lo16(.PatternCode)+54	; Length = 18

.Pattern2Table:
	dw lo16(.PatternCode)+90	; Length = 03
	dw lo16(.PatternCode)+84	; Length = 04
	dw lo16(.PatternCode)+78	; Length = 05
	dw lo16(.PatternCode)+72	; Length = 06
	dw lo16(.PatternCode)+66	; Length = 07
	dw lo16(.PatternCode)+60	; Length = 08
	dw lo16(.PatternCode)+54	; Length = 09
	dw lo16(.PatternCode)+48	; Length = 10
	dw lo16(.PatternCode)+42	; Length = 11
	dw lo16(.PatternCode)+36	; Length = 12
	dw lo16(.PatternCode)+30	; Length = 13
	dw lo16(.PatternCode)+24	; Length = 14
	dw lo16(.PatternCode)+18	; Length = 15
	dw lo16(.PatternCode)+12	; Length = 16
	dw lo16(.PatternCode)+6	; Length = 17
	dw lo16(.PatternCode)+0	; Length = 18

.Run1Table:
	dw lo16(.RunOddCode)+45	; Length = 03
	dw lo16(.RunCode)+93	; Length = 04
	dw lo16(.RunOddCode)+42	; Length = 05
	dw lo16(.RunCode)+90	; Length = 06
	dw lo16(.RunOddCode)+39	; Length = 07
	dw lo16(.RunCode)+87	; Length = 08
	dw lo16(.RunOddCode)+36	; Length = 09
	dw lo16(.RunCode)+84	; Length = 10
	dw lo16(.RunOddCode)+33	; Length = 11
	dw lo16(.RunCode)+81	; Length = 12
	dw lo16(.RunOddCode)+30	; Length = 13
	dw lo16(.RunCode)+78	; Length = 14
	dw lo16(.RunOddCode)+27	; Length = 15
	dw lo16(.RunCode)+75	; Length = 16
	dw lo16(.RunOddCode)+24	; Length = 17
	dw lo16(.RunCode)+72	; Length = 18
	dw lo16(.RunOddCode)+21	; Length = 19
	dw lo16(.RunCode)+69	; Length = 20
	dw lo16(.RunOddCode)+18	; Length = 21
	dw lo16(.RunCode)+66	; Length = 22
	dw lo16(.RunOddCode)+15	; Length = 23
	dw lo16(.RunCode)+63	; Length = 24
	dw lo16(.RunOddCode)+12	; Length = 25
	dw lo16(.RunCode)+60	; Length = 26
	dw lo16(.RunOddCode)+9	; Length = 27
	dw lo16(.RunCode)+57	; Length = 28
	dw lo16(.RunOddCode)+6	; Length = 29
	dw lo16(.RunCode)+54	; Length = 30
	dw lo16(.RunOddCode)+3	; Length = 31
	dw lo16(.RunCode)+51	; Length = 32
	dw lo16(.RunOddCode)+0	; Length = 33

.Run2Table:
	dw lo16(.RunCode)+90	; Length = 03
	dw lo16(.RunCode)+87	; Length = 04
	dw lo16(.RunCode)+84	; Length = 05
	dw lo16(.RunCode)+81	; Length = 06
	dw lo16(.RunCode)+78	; Length = 07
	dw lo16(.RunCode)+75	; Length = 08
	dw lo16(.RunCode)+72	; Length = 09
	dw lo16(.RunCode)+69	; Length = 10
	dw lo16(.RunCode)+66	; Length = 11
	dw lo16(.RunCode)+63	; Length = 12
	dw lo16(.RunCode)+60	; Length = 13
	dw lo16(.RunCode)+57	; Length = 14
	dw lo16(.RunCode)+54	; Length = 15
	dw lo16(.RunCode)+51	; Length = 16
	dw lo16(.RunCode)+48	; Length = 17
	dw lo16(.RunCode)+45	; Length = 18
	dw lo16(.RunCode)+42	; Length = 19
	dw lo16(.RunCode)+39	; Length = 20
	dw lo16(.RunCode)+36	; Length = 21
	dw lo16(.RunCode)+33	; Length = 22
	dw lo16(.RunCode)+30	; Length = 23
	dw lo16(.RunCode)+27	; Length = 24
	dw lo16(.RunCode)+24	; Length = 25
	dw lo16(.RunCode)+21	; Length = 26
	dw lo16(.RunCode)+18	; Length = 27
	dw lo16(.RunCode)+15	; Length = 28
	dw lo16(.RunCode)+12	; Length = 29
	dw lo16(.RunCode)+9	; Length = 30
	dw lo16(.RunCode)+6	; Length = 31
	dw lo16(.RunCode)+3	; Length = 32
	dw lo16(.RunCode)+0	; Length = 33
