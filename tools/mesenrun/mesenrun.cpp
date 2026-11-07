// mesenrun - headless MesenCE runner: loads a ROM and a Lua script, runs at
// maximum speed until the script calls emu.stop(code) or the timeout expires.
// usage: mesenrun <rom> <script.lua> [timeout_seconds]   (default 120; exit code = the
// script's stop code, -1 (255) on timeout).  Mesen's home (battery saves) is $MESEN_HOME, default /tmp/mesenhome.
// Environment: see build.sh; the MESEN_GSU_STATS, _IDLE and _PROF files are written when
// the run ends.
#include "pch.h"
#include <thread>
#include <chrono>
#include <fstream>
#include <sstream>
#include <iostream>
#include "Shared/Emulator.h"
#include "Shared/EmuSettings.h"
#include "Shared/SettingTypes.h"
#include "Shared/DebuggerRequest.h"
#include "Debugger/Debugger.h"
#include "Debugger/ScriptManager.h"
#include "Shared/Interfaces/IKeyManager.h"
#include "Shared/KeyManager.h"
#include "Utilities/VirtualFile.h"
#include "Utilities/FolderUtilities.h"

extern uint64_t g_gsuStat[8];
extern uint32_t* g_gsuProf;
extern uint64_t* g_gsuIdle;
#include <unordered_map>
extern std::unordered_map<uint32_t, uint64_t> g_gsuIdlePc;
extern uint32_t g_gsuIdleFrom;
extern FILE* g_gsuTrace;
extern uint32_t g_gsuTraceFrames;
extern bool g_gsuTraceOpen;
extern uint64_t g_gsuTraceStart, g_gsuTraceEnd;
extern int g_gsuTraceWhy;
extern uint32_t g_gsuTracePc;
int main(int argc, char** argv)
{
	if(argc < 3) { std::cerr << "usage: mesenrun rom script.lua [timeout]\n"; return 2; }
	int timeout = argc > 3 ? atoi(argv[3]) : 120;
	if(getenv("MESEN_GSU_PROF")) g_gsuProf = (uint32_t*)calloc(1 << 24, 4);
	if(getenv("MESEN_GSU_IDLE")) g_gsuIdle = (uint64_t*)calloc(4 * 65537, 8);
	if(getenv("MESEN_GSU_TRACE_FRAMES")) g_gsuTraceFrames = (uint32_t)atoi(getenv("MESEN_GSU_TRACE_FRAMES"));
	if(getenv("MESEN_GSU_TRACE")) g_gsuTrace = fopen(getenv("MESEN_GSU_TRACE"), "w");
	if(getenv("MESEN_GSU_IDLE_FROM")) g_gsuIdleFrom = (uint32_t)atoi(getenv("MESEN_GSU_IDLE_FROM"));
	FolderUtilities::SetHomeFolder(getenv("MESEN_HOME") ? getenv("MESEN_HOME") : "/tmp/mesenhome");
	std::unique_ptr<Emulator> emu(new Emulator());
	emu->Initialize(false);
	EmuSettings* s = emu->GetSettings();
	s->GetDebugConfig().ScriptAllowIoOsAccess = true;
	s->GetDebugConfig().ScriptTimeout = 100;
	s->SetFlag(EmulationFlags::ConsoleMode);
	SnesConfig& snesCfg = s->GetSnesConfig();
	snesCfg.Port1.Type = ControllerType::SnesController;
	if(getenv("MESEN_PORT1_MOUSE")) snesCfg.Port1.Type = ControllerType::SnesMouse;
	if(getenv("MESEN_PORT2_MOUSE")) snesCfg.Port2.Type = ControllerType::SnesMouse;
	if(getenv("MESEN_PORT2_PAD")) snesCfg.Port2.Type = ControllerType::SnesController;
	snesCfg.RamPowerOnState = RamState::AllZeros;
	if(const char* h = getenv("MESEN_HIDE")) {	// layers not drawn: 1-4 = BG1-BG4, s = sprites (screenshots of single layers)
		std::string x = h;
		snesCfg.HideBgLayer1 = x.find('1') != std::string::npos; snesCfg.HideBgLayer2 = x.find('2') != std::string::npos;
		snesCfg.HideBgLayer3 = x.find('3') != std::string::npos; snesCfg.HideBgLayer4 = x.find('4') != std::string::npos;
		snesCfg.HideSprites = x.find('s') != std::string::npos;
	}
	if(getenv("MESEN_RAM")) {	// power-on RAM: random / ones (hardware is not cleared)
		std::string r = getenv("MESEN_RAM");
		snesCfg.RamPowerOnState = r == "random" ? RamState::Random : r == "ones" ? RamState::AllOnes : RamState::AllZeros;
	}
	if(getenv("MESEN_GSU_CLOCK")) snesCfg.GsuClockSpeed = atoi(getenv("MESEN_GSU_CLOCK"));
	if(!emu->LoadRom(VirtualFile(argv[1]), VirtualFile())) { std::cerr << "load failed\n"; return 3; }
	std::ifstream f(argv[2]); std::stringstream ss; ss << f.rdbuf();
	{
		auto dbg = emu->GetDebugger(true);
		dbg.GetDebugger()->GetScriptManager()->LoadScript(argv[2], ".", ss.str(), -1);
	}
	s->SetFlag(EmulationFlags::MaximumSpeed);
	auto start = std::chrono::steady_clock::now();
	int result = -1;
	while(true) {
		std::this_thread::sleep_for(std::chrono::milliseconds(50));
		if(!emu->IsRunning()) { result = emu->GetStopCode(); break; }
		if(std::chrono::steady_clock::now() - start > std::chrono::seconds(timeout)) { std::cerr << "timeout\n"; break; }
	}
	if(getenv("MESEN_GSU_STATS")) {
		FILE* sf = fopen(getenv("MESEN_GSU_STATS"), "w");
		if(sf) { fprintf(sf, "{\"cycles\": %llu, \"partial_flushes\": %llu, \"partial_cycles\": %llu, \"full_flushes\": %llu, \"full_cycles\": %llu}\n",
			(unsigned long long)g_gsuStat[0], (unsigned long long)g_gsuStat[1], (unsigned long long)g_gsuStat[2], (unsigned long long)g_gsuStat[3], (unsigned long long)g_gsuStat[4]); fclose(sf); }
	}
	if(g_gsuTrace) {	// the interval still open at the end
		if(g_gsuTraceOpen) fprintf(g_gsuTrace, "%llu %llu %d %06X\n", (unsigned long long)g_gsuTraceStart, (unsigned long long)(g_gsuTraceEnd - g_gsuTraceStart), g_gsuTraceWhy, g_gsuTracePc);
		fclose(g_gsuTrace);
	}
	if(g_gsuIdle) {	// GSU time in master clocks: total, per frame (master clock / 357368), then per reason and GSU address
		FILE* f = fopen(getenv("MESEN_GSU_IDLE"), "w");
		if(f) {
			fprintf(f, "# frame running stopped rom_wait ram_wait (master clocks)\ntotal %llu %llu %llu %llu\n",
				(unsigned long long)g_gsuIdle[0], (unsigned long long)g_gsuIdle[1], (unsigned long long)g_gsuIdle[2], (unsigned long long)g_gsuIdle[3]);
			for(uint32_t i = 0; i < 65536; i++) {
				uint64_t* e = g_gsuIdle + 4 * (i + 1);
				if(e[0] | e[1] | e[2] | e[3]) fprintf(f, "%u %llu %llu %llu %llu\n", i, (unsigned long long)e[0], (unsigned long long)e[1], (unsigned long long)e[2], (unsigned long long)e[3]);
			}
			for(auto& kv : g_gsuIdlePc) fprintf(f, "pc %u %06X %llu\n", kv.first >> 24, kv.first & 0xFFFFFF, (unsigned long long)kv.second);
			fclose(f);
		}
	}
	if(g_gsuProf) {
		FILE* pf = fopen(getenv("MESEN_GSU_PROF"), "w");
		if(pf) { for(uint32_t a = 0; a < (1 << 24); a++) if(g_gsuProf[a]) fprintf(pf, "%06X %u\n", a, g_gsuProf[a]); fclose(pf); }
	}
	emu->Stop(false);
	emu->Release();
	return result;
}
