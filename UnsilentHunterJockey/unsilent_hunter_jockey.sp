#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <logger>
#include <treeutil>

#define CVAR_FLAGS FCVAR_NOTIFY
#define HUNTER_SOUND_SIZE 5
#define JOCKEY_SOUND_SIZE 16
#define PLUGIN_PREFIX "[UnsilentHunterJockey]"

public Plugin myinfo = 
{
	name 			= "Unsilent Hunter Jockey",
	author 			= "Tabun, robex, Sir, A1m, Spoon, 夜羽真白",
	description 	= "令 Hunter 和 Jockey 固定间隔发声",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar
	g_hHunterSoundInterval,
	g_hJockeySoundInterval,
	g_hLogLevel;
// Handles
Handle
	hSoundTimer[MAXPLAYERS + 1];
// Bools
bool
	g_bIsPouncing[MAXPLAYERS + 1],
	bLate;

Logger
	log;

static const char HunterSounds[][] =
{
	"player/hunter/voice/alert/hunter_alert_01.wav",
	"player/hunter/voice/alert/hunter_alert_02.wav",
	"player/hunter/voice/alert/hunter_alert_03.wav",
	"player/hunter/voice/alert/hunter_alert_04.wav",
	"player/hunter/voice/alert/hunter_alert_05.wav"
};
static const char JockeySounds[][] =
{
	"player/jockey/voice/idle/jockey_recognize02.wav",
	"player/jockey/voice/idle/jockey_recognize06.wav",
	"player/jockey/voice/idle/jockey_recognize07.wav",
	"player/jockey/voice/idle/jockey_recognize08.wav",
	"player/jockey/voice/idle/jockey_recognize09.wav",
	"player/jockey/voice/idle/jockey_recognize10.wav",
	"player/jockey/voice/idle/jockey_recognize11.wav",
	"player/jockey/voice/idle/jockey_recognize12.wav",
	"player/jockey/voice/idle/jockey_recognize13.wav",
	"player/jockey/voice/idle/jockey_recognize15.wav",
	"player/jockey/voice/idle/jockey_recognize16.wav",
	"player/jockey/voice/idle/jockey_recognize17.wav",
	"player/jockey/voice/idle/jockey_recognize18.wav",
	"player/jockey/voice/idle/jockey_recognize19.wav",
	"player/jockey/voice/idle/jockey_recognize20.wav",
	"player/jockey/voice/idle/jockey_recognize24.wav"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion version = GetEngineVersion();
	if (version != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[不支持的游戏]：此插件仅支持 Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	// CreateConVars
	g_hHunterSoundInterval = CreateConVar("unsilent_hunter_interval", "2.0", "Hunter 多少秒放一次声", CVAR_FLAGS, true, 0.1);
	g_hJockeySoundInterval = CreateConVar("unsilent_jockey_interval", "2.0", "Jockey 多少秒放一次声", CVAR_FLAGS, true, 0.1);
	g_hLogLevel = CreateConVar("unsilent_hunter_jockey_log_level", "38", "插件日志记录级别 (1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR) 数字相加", CVAR_FLAGS, true, 0.0);
	// HookEvents
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("player_death", evt_PlayerDeath);
	HookEvent("player_team", evt_PlayerTeam);
	HookEvent("player_shoved", evt_PlayerShoved);
	HookEvent("ability_use", evt_AbilityUse);
	// Jockey 骑乘事件
	HookEvent("jockey_ride", Event_JockeyRide);
	HookEvent("jockey_ride_end", Event_JockeyRideEnd);

	log = new Logger(g_hLogLevel.IntValue);

	g_hHunterSoundInterval.AddChangeHook(changeHookHunterSound);
	g_hJockeySoundInterval.AddChangeHook(changeHookJockeySound);

	if (bLate) {
		int i;
		for (i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i) || IsInGhostState(i))
				continue;
			if (IsHunter(i))
				hSoundTimer[i] = CreateTimer(g_hHunterSoundInterval.FloatValue, soundTimerHandler, i, TIMER_REPEAT);
			else if (IsJockey(i))
				hSoundTimer[i] = CreateTimer(g_hJockeySoundInterval.FloatValue, soundTimerHandler, i, TIMER_REPEAT);
		}
	}	
}

void changeHookHunterSound(ConVar convar, const char[] oldValue, const char[] newValue) {
	int i;
	for (i = 1; i <= MaxClients; i++) {
		if (IsHunter(i) && IsPlayerAlive(i) && !IsInGhostState(i)) {
			delete hSoundTimer[i];
			hSoundTimer[i] = CreateTimer(g_hHunterSoundInterval.FloatValue, soundTimerHandler, i, TIMER_REPEAT);
		}
	}
	log.debugAndInfo("%s: Hunter 发声间隔发生变化 (%.2f -> %.2f), 重新为在场所有 Hunter 创建发声时钟", PLUGIN_PREFIX, StringToFloat(oldValue), StringToFloat(newValue));
}

void changeHookJockeySound(ConVar convar, const char[] oldValue, const char[] newValue) {
	int i;
	for (i = 1; i <= MaxClients; i++) {
		if (IsJockey(i) && IsPlayerAlive(i) && !IsInGhostState(i)) {
			delete hSoundTimer[i];
			hSoundTimer[i] = CreateTimer(g_hJockeySoundInterval.FloatValue, soundTimerHandler, i, TIMER_REPEAT);
		}
	}
	log.debugAndInfo("%s: Jockey 发声间隔发生变化 (%.2f -> %.2f), 重新为在场所有 Jockey 创建发声时钟", PLUGIN_PREFIX, StringToFloat(oldValue), StringToFloat(newValue));
}

public void OnMapStart() {
	// 声音预加载
	int i;
	for (i = 0; i < HUNTER_SOUND_SIZE; i++)
		PrefetchSound(HunterSounds[i]);
	for (i = 0; i < JOCKEY_SOUND_SIZE; i++)
		PrefetchSound(JockeySounds[i]);
}

public void L4D_OnEnterGhostState(int client) {
	delete hSoundTimer[client];
}

// 猴子或 ht 复活时，开始时钟循环，正在控人时，停止放声，死亡时，停止时钟
public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	// 无效客户端
	if (client < 1 || client > MaxClients || !IsClientInGame(client) ||
		GetClientTeam(client) != TEAM_INFECTED || !IsPlayerAlive(client))
		return;
	// 不是 Hunter 或 Jockey
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (class != ZC_HUNTER && class != ZC_JOCKEY)
		return;

	delete hSoundTimer[client];

	if (class == ZC_HUNTER)
		hSoundTimer[client] = CreateTimer(g_hHunterSoundInterval.FloatValue, soundTimerHandler, client, TIMER_REPEAT);
	else if (class == ZC_JOCKEY)
		hSoundTimer[client] = CreateTimer(g_hJockeySoundInterval.FloatValue, soundTimerHandler, client, TIMER_REPEAT);
}

public Action soundTimerHandler(Handle timer, int client) {
	if (client < 1 || client > MaxClients || !IsClientInGame(client) ||
		GetClientTeam(client) != TEAM_INFECTED || !IsPlayerAlive(client)) {
		hSoundTimer[client] = null;
		return Plugin_Stop;
	}
		
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (class != ZC_HUNTER && class != ZC_JOCKEY) {
		hSoundTimer[client] = null;
		return Plugin_Stop;
	}

	int victim, sound;
	if (class == ZC_HUNTER)
		victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	else if (class == ZC_JOCKEY)
		victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
	
	// 如果特感正在控人, 则不强制发声
	if (IsValidSurvivor(victim) && IsPlayerAlive(victim)) {
		return Plugin_Continue;
	} else {
		// 特感没有正在控人
		// Hunter 正在飞扑, 则不强制放声
		if (class == ZC_HUNTER && g_bIsPouncing[client])
			return Plugin_Continue;

		switch (class) {
			case ZC_HUNTER:
				sound = GetRandomIntInRange(0, HUNTER_SOUND_SIZE - 1);
			case ZC_JOCKEY:
				sound = GetRandomIntInRange(0, JOCKEY_SOUND_SIZE - 1);
		}

		EmitSoundToAll(class == ZC_HUNTER ? HunterSounds[sound] : JockeySounds[sound], client, SNDCHAN_VOICE);
	}
	return Plugin_Continue;
}


// 猴子或 ht 死亡或者更换队伍或者进入灵魂状态时，删除时钟，禁止放声
public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client < 1 || client > MaxClients)
		return;
	delete hSoundTimer[client];
}

public void evt_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client < 1 || client > MaxClients)
		return;
	delete hSoundTimer[client];
}

public void evt_PlayerShoved(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userId"));
    if (IsHunter(client))
		g_bIsPouncing[client] = false;
}

public void evt_AbilityUse(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userId"));
	if (!IsHunter(client) || !IsPlayerAlive(client))
		return;

	char ability[64];
	event.GetString("ability", ability, sizeof(ability));
	if (!g_bIsPouncing[client] && strcmp(ability, "ability_lunge") == 0) {
		g_bIsPouncing[client] = true;
		CreateTimer(0.1, Timer_GroundTouch, client, TIMER_REPEAT);
	}
}

public void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	// Jockey 正在骑乘生还者, 暂时禁止发声
	if (client < 1 || client > MaxClients)
		return;
	delete hSoundTimer[client];
}

public void Event_JockeyRideEnd(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client < 1 || client > MaxClients)
		return;
	RequestFrame(nextFrameJockeyRideEnd, GetClientUserId(client));
}

public void nextFrameJockeyRideEnd(int userId) {
	int client = GetClientOfUserId(userId);
	if (client < 1 || client > MaxClients || !IsClientInGame(client) ||
	 	GetClientTeam(client) != TEAM_INFECTED || !IsPlayerAlive(client))
		return;
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_JOCKEY)
		return;
	if (GetEntProp(client, Prop_Send, "m_isGhost") != 0)
		return;
	CreateTimer(g_hJockeySoundInterval.FloatValue, soundTimerHandler, client, TIMER_REPEAT);
}

public Action Timer_GroundTouch(Handle timer, int client) {
    if (IsHunter(client) && ((GetEntityFlags(client) & FL_ONGROUND) || !IsPlayerAlive(client) || (GetEntityMoveType(client) & MOVETYPE_LADDER))) {
        g_bIsPouncing[client] = false;
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

// 方法
stock bool IsHunter(int client) {
	return view_as<bool>(GetInfectedClass(client) == view_as<int>(ZC_HUNTER));
}

stock bool IsJockey(int client) {
	return view_as<bool>(GetInfectedClass(client) == view_as<int>(ZC_JOCKEY));
}