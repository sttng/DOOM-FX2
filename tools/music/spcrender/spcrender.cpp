// spcrender -- play a Sculptured SPC700 music driver song into a WAV file
//
// usage: spcrender RAM.bin OUT.wav SECONDS [CMD:PARAM ...]
//   RAM.bin   64 KB sound RAM image: driver at $0700, the common module and the
//             song module already in place (tools/music/spcrender.py builds it)
//   CMD:PARAM driver commands (hex), sent in order through the APU ports as the
//             65816 does (musicdrv.asm _SendDriverCommand): parameter word to
//             ports 0/1, serial# to port 2, command to port 3, acknowledged by
//             the driver echoing the serial# in port 2.
// The SPC700 starts at $0700, as after the game's upload (_APUUploadRun).
// Emulation: blargg's snes_spc as in libgme (Snes_Spc, Spc_Cpu, Spc_Dsp).
#define private public            // (spc.dsp and spc.m for SPCRENDER_WATCH / SPCRENDER_DUMP)
#include "Snes_Spc.h"
#undef private
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>

static const unsigned char ipl[64] = {
	0xCD,0xEF,0xBD,0xE8,0x00,0xC6,0x1D,0xD0,0xFC,0x8F,0xAA,0xF4,0x8F,0xBB,0xF5,0x78,
	0xCC,0xF4,0xD0,0xFB,0x2F,0x19,0xEB,0xF4,0xD0,0xFC,0x7E,0xF4,0xD0,0x0B,0xE4,0xF5,
	0xCB,0xF4,0xD7,0x00,0xFC,0xD0,0xF3,0xAB,0x01,0x10,0xEF,0x7E,0xF4,0x10,0xEB,0xBA,
	0xF6,0xDA,0x00,0xBA,0xF4,0xC4,0xF4,0xDD,0x5D,0xD0,0xDB,0x1F,0x00,0x00,0xC0,0xFF };

static Snes_Spc spc;
static std::vector<short> out;
static const int CHUNK = 64;            // clocks per step while handshaking

static void run(int clocks) {           // emulate CLOCKS and collect the samples
	static short buf[8192];
	while (clocks > 0) {
		int n = clocks > 4096 * 32 ? 4096 * 32 : clocks;
		spc.set_output(buf, 8192);
		spc.end_frame(n);
		int c = spc.sample_count();
		out.insert(out.end(), buf, buf + c);
		clocks -= n;
	}
}

static int serial = 1;
static bool send(int cmd, int param) {
	// wait for the driver to show the current serial# in port 2 (max 2 s)
	for (int t = 0; spc.read_port(0, 2) != serial; t += CHUNK) {
		if (t > 2 * Snes_Spc::clock_rate) return false;
		run(CHUNK);
	}
	if (++serial == 256) serial = 1;
	spc.write_port(0, 0, param & 0xFF);
	spc.write_port(0, 1, param >> 8);
	spc.write_port(0, 2, serial);
	spc.write_port(0, 3, cmd);
	return true;
}

static void put32(FILE* f, unsigned v) { fwrite(&v, 4, 1, f); }
static void put16(FILE* f, unsigned v) { unsigned short s = v; fwrite(&s, 2, 1, f); }

int main(int argc, char** argv) {
	if (argc < 4) { fprintf(stderr, "usage: spcrender RAM.bin OUT.wav SECONDS [CMD:PARAM ...]\n"); return 2; }
	std::vector<unsigned char> file(Snes_Spc::spc_file_size, 0);
	memcpy(&file[0], "SNES-SPC700 Sound File Data v0.30", 33);
	file[0x21] = 26; file[0x22] = 26; file[0x23] = 27; file[0x24] = 30;
	file[0x25] = 0x00; file[0x26] = 0x07;          // PC = $0700
	file[0x2A] = 0x02; file[0x2B] = 0xEF;          // PSW, SP
	FILE* f = fopen(argv[1], "rb");
	if (!f || fread(&file[0x100], 1, 0x10000, f) != 0x10000) { fprintf(stderr, "%s: need a 64 KB RAM image\n", argv[1]); return 1; }
	fclose(f);
	unsigned char* ram = &file[0x100];
	ram[0xF1] = 0x00;                              // control: timers off, IPL ROM off
	for (int r = 0xF4; r < 0xF8; r++) ram[r] = 0;  // ports
	memset(&file[0x10100], 0, 128);                // DSP registers
	file[0x10100 + 0x6C] = 0x3F;                   // FLG as after DCOM_RELOAD (driver $0798)
	if (spc.init()) return 1;
	spc.init_rom(ipl);
	if (const char* e = spc.load_spc(&file[0], file.size())) { fprintf(stderr, "%s\n", e); return 1; }
	run(Snes_Spc::clock_rate / 50);                // let the driver start
	for (int i = 4; i < argc; i++) {
		unsigned cmd, param = 0;
		if (sscanf(argv[i], "%x:%x", &cmd, &param) < 1) continue;
		if (!send(cmd, param)) { fprintf(stderr, "command %02X: no acknowledge\n", cmd); return 1; }
		run(Snes_Spc::clock_rate / 50);
	}
	double secs = atof(argv[3]);
	out.clear();                                   // the song from here
	if (const char* w = getenv("SPCRENDER_WATCH")) {   // debugging: report when DSP register W changes
		int reg = strtol(w, 0, 16), last = spc.dsp.read(reg), step = Snes_Spc::clock_rate / 1000;
		for (int t = 0; t < (int)(secs * 1000); t++) {
			run(step);
			int v = spc.dsp.read(reg);
			if (v != last) {
				fprintf(stderr, "%.3f s: DSP $%02X %02X -> %02X, SPC PC $%04X\n", t / 1000.0, reg, last, v, spc.m.cpu_regs.pc);
				last = v;
			}
		}
	} else
	run((int)(secs * Snes_Spc::clock_rate));
	FILE* w = fopen(argv[2], "wb");
	unsigned bytes = out.size() * 2;
	fwrite("RIFF", 1, 4, w); put32(w, 36 + bytes); fwrite("WAVEfmt ", 1, 8, w);
	put32(w, 16); put16(w, 1); put16(w, 2); put32(w, 32000); put32(w, 32000 * 4); put16(w, 4); put16(w, 16);
	fwrite("data", 1, 4, w); put32(w, bytes); fwrite(&out[0], 2, out.size(), w);
	fclose(w);
	if (const char* d = getenv("SPCRENDER_DUMP")) {   // debugging: sound RAM + DSP registers
		FILE* o = fopen(d, "wb"); fwrite(spc.smp_ram(), 1, 0x10000, o);
		for (int r = 0; r < 128; r++) { unsigned char v = spc.dsp.read(r); fwrite(&v, 1, 1, o); }
		fclose(o);
	}
	return 0;
}
