"""Minimal 65816 disassembler with M/X tracking (rep/sep).
usage: dis65816.py fileoff snesaddr len mx ROM  (hex numbers; mx = M and X flags, 11 = 8-bit A and X)"""
import sys
OPS = {}
modes = """
00 brk imm8|01 ora dpxi|02 cop imm8|03 ora sr|04 tsb dp|05 ora dp|06 asl dp|07 ora dpil|08 php imp|09 ora immm|0a asl acc|0b phd imp|0c tsb abs|0d ora abs|0e asl abs|0f ora long
10 bpl rel|11 ora dpiy|12 ora dpi|13 ora sriy|14 trb dp|15 ora dpx|16 asl dpx|17 ora dpily|18 clc imp|19 ora absy|1a inc acc|1b tcs imp|1c trb abs|1d ora absx|1e asl absx|1f ora longx
20 jsr abs|21 and dpxi|22 jsl long|23 and sr|24 bit dp|25 and dp|26 rol dp|27 and dpil|28 plp imp|29 and immm|2a rol acc|2b pld imp|2c bit abs|2d and abs|2e rol abs|2f and long
30 bmi rel|31 and dpiy|32 and dpi|33 and sriy|34 bit dpx|35 and dpx|36 rol dpx|37 and dpily|38 sec imp|39 and absy|3a dec acc|3b tsc imp|3c bit absx|3d and absx|3e rol absx|3f and longx
40 rti imp|41 eor dpxi|42 wdm imm8|43 eor sr|44 mvp mv|45 eor dp|46 lsr dp|47 eor dpil|48 pha imp|49 eor immm|4a lsr acc|4b phk imp|4c jmp abs|4d eor abs|4e lsr abs|4f eor long
50 bvc rel|51 eor dpiy|52 eor dpi|53 eor sriy|54 mvn mv|55 eor dpx|56 lsr dpx|57 eor dpily|58 cli imp|59 eor absy|5a phy imp|5b tcd imp|5c jml long|5d eor absx|5e lsr absx|5f eor longx
60 rts imp|61 adc dpxi|62 per rell|63 adc sr|64 stz dp|65 adc dp|66 ror dp|67 adc dpil|68 pla imp|69 adc immm|6a ror acc|6b rtl imp|6c jmp absi|6d adc abs|6e ror abs|6f adc long
70 bvs rel|71 adc dpiy|72 adc dpi|73 adc sriy|74 stz dpx|75 adc dpx|76 ror dpx|77 adc dpily|78 sei imp|79 adc absy|7a ply imp|7b tdc imp|7c jmp absxi|7d adc absx|7e ror absx|7f adc longx
80 bra rel|81 sta dpxi|82 brl rell|83 sta sr|84 sty dp|85 sta dp|86 stx dp|87 sta dpil|88 dey imp|89 bit immm|8a txa imp|8b phb imp|8c sty abs|8d sta abs|8e stx abs|8f sta long
90 bcc rel|91 sta dpiy|92 sta dpi|93 sta sriy|94 sty dpx|95 sta dpx|96 stx dpy|97 sta dpily|98 tya imp|99 sta absy|9a txs imp|9b txy imp|9c stz abs|9d sta absx|9e stz absx|9f sta longx
a0 ldy immx|a1 lda dpxi|a2 ldx immx|a3 lda sr|a4 ldy dp|a5 lda dp|a6 ldx dp|a7 lda dpil|a8 tay imp|a9 lda immm|aa tax imp|ab plb imp|ac ldy abs|ad lda abs|ae ldx abs|af lda long
b0 bcs rel|b1 lda dpiy|b2 lda dpi|b3 lda sriy|b4 ldy dpx|b5 lda dpx|b6 ldx dpy|b7 lda dpily|b8 clv imp|b9 lda absy|ba tsx imp|bb tyx imp|bc ldy absx|bd lda absx|be ldx absy|bf lda longx
c0 cpy immx|c1 cmp dpxi|c2 rep imm8|c3 cmp sr|c4 cpy dp|c5 cmp dp|c6 dec dp|c7 cmp dpil|c8 iny imp|c9 cmp immm|ca dex imp|cb wai imp|cc cpy abs|cd cmp abs|ce dec abs|cf cmp long
d0 bne rel|d1 cmp dpiy|d2 cmp dpi|d3 cmp sriy|d4 pei dp|d5 cmp dpx|d6 dec dpx|d7 cmp dpily|d8 cld imp|d9 cmp absy|da phx imp|db stp imp|dc jml absil|dd cmp absx|de dec absx|df cmp longx
e0 cpx immx|e1 sbc dpxi|e2 sep imm8|e3 sbc sr|e4 cpx dp|e5 sbc dp|e6 inc dp|e7 sbc dpil|e8 inx imp|e9 sbc immm|ea nop imp|eb xba imp|ec cpx abs|ed sbc abs|ee inc abs|ef sbc long
f0 beq rel|f1 sbc dpiy|f2 sbc dpi|f3 sbc sriy|f4 pea abs|f5 sbc dpx|f6 inc dpx|f7 sbc dpily|f8 sed imp|f9 sbc absy|fa plx imp|fb xce imp|fc jsr absxi|fd sbc absx|fe inc absx|ff sbc longx
"""
for ent in modes.replace('\n','|').split('|'):
    ent=ent.strip()
    if not ent: continue
    o,m,a=ent.split(); OPS[int(o,16)]=(m,a)
SZ={'imp':0,'acc':0,'imm8':1,'dp':1,'dpx':1,'dpy':1,'dpi':1,'dpxi':1,'dpiy':1,'dpil':1,'dpily':1,'sr':1,'sriy':1,'rel':1,
    'abs':2,'absx':2,'absy':2,'absi':2,'absxi':2,'absil':2,'rell':2,'mv':2,'long':3,'longx':3}
FMT={'imp':'','acc':'a','imm8':'#$%02x','dp':'$%02x','dpx':'$%02x,x','dpy':'$%02x,y','dpi':'($%02x)','dpxi':'($%02x,x)','dpiy':'($%02x),y',
     'dpil':'[$%02x]','dpily':'[$%02x],y','sr':'$%02x,s','sriy':'($%02x,s),y','abs':'$%04x','absx':'$%04x,x','absy':'$%04x,y','absi':'($%04x)',
     'absxi':'($%04x,x)','absil':'[$%04x]','long':'$%06x','longx':'$%06x,x'}
def dis(rom, off, pc, n, m=1, x=1, out=print):
    end=off+n
    while off<end:
        op=rom[off]; mn,am=OPS[op]
        if am=='immm': size=1 if m else 2; fmt='#$%02x' if m else '#$%04x'
        elif am=='immx': size=1 if x else 2; fmt='#$%02x' if x else '#$%04x'
        else: size=SZ[am]; fmt=FMT.get(am,'')
        b=rom[off+1:off+1+size]; v=int.from_bytes(b,'little')
        if am=='rel': s='$%04x'%((pc+2+(v-256 if v>127 else v))&0xffff)
        elif am=='rell': s='$%04x'%((pc+3+(v-65536 if v>32767 else v))&0xffff)
        elif am=='mv': s='$%02x,$%02x'%(b[1],b[0])
        else: s=fmt%v if '%' in fmt else fmt
        out('%06x %06x  %-12s %s %s%s'%(off,pc,rom[off:off+1+size].hex(),mn,s,'' ))
        if mn=='rep':
            if v&0x20: m=0
            if v&0x10: x=0
        if mn=='sep':
            if v&0x20: m=1
            if v&0x10: x=1
        off+=1+size; pc=(pc&0xff0000)|((pc+1+size)&0xffff)
    return m,x
if __name__=='__main__':
    rom=open(sys.argv[5],'rb').read()
    a=sys.argv[1:]
    m=int(a[3][0]) if len(a)>3 else 1; x=int(a[3][1]) if len(a)>3 else 1
    dis(rom,int(a[0],16),int(a[1],16),int(a[2],16),m,x)
