	arch 65816
;**********************************************************************
;*                                                                    *
;*                   P R O J E C T :   REALITY_ENGINE                 *
;*                                                                    *
;*                         ENGINE SEGS MODULE 1                       *
;*                                                                    *
;**********************************************************************

	incsrc "src/include/rage.inc"
	incsrc "src/include/rle.inc"
	incsrc "src/include/gsumac.inc"

	; public _RLBuildSegList1


	%section(ENGINE_GSUCODE)
	arch superfx


;	******************************************************************
;	******************************************************************
;	**								**
;	**  BUILD SEGMENT LIST 1      INIT RLENGINE DISPLAY PROCESSING  **
;	**								**
;	******************************************************************
;	******************************************************************

;
;	* * * * * * *       INITIALIZE ROTATED VERTEXES ARRAY       * * * * * * *
;
	%align_pad(13, 16, (_RLBuildSegList1-_BS1L2000)&$0F)	; align 16,(_RLBuildSegList1-_BS1L2000)&$0f
_RLBuildSegList1:
	iwt r1,#lo16(_RLVertexes-4+1)	; Point to Start of Vertexes
	ibt r2,#4	; #Bytes between Rotated Vertexes
	lms r12,(EMNUMVERTEXES&$FFFF)	; Get Number of Vertexes
	iwt r13,#lo16(_BS1L2200)
	ibt r0,#$80	; $80XX = Vertex NOT Rotated Yet
	%CACHEB(_RLBuildSegList1)
_BS1L2000:
	with r1	; Next Vertex
_BS1L2200:
	add r2
;	from	r0				; Mark Vertex NOT Rotated
	stb (r1)
	loop
	with r1	; Next Vertex
	%CACHEE(_RLBuildSegList1)

;
;	* * * * * * *       BEGIN RLENGINE DISPLAY PROCESSING       * * * * * * *
;
	iwt r0,#lo16(_RLBuildSegList2)	; BUILD SEGMENT LIST 2
	ibt r8,#bank(_RLBuildSegList2)
	if !PROFILE == 0
	ljmp r8
	endif
	if !PROFILE != 0
	stop
	endif
	nop
