#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include "treeutil\treeutil.sp"

#define CVAR_FLAGS FCVAR_NOTIFY

public Plugin myinfo = 
{
	name 			= "Unsilent Hunter Jockey",
	author 			= "Tabun，robex，Sir，A1m，Spoon，夜羽真白",
	description 	= "令 Hunter 和 Jockey 固定间隔发声",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hHunterSoundInterval, g_hJockeySoundInterval;
// Handles
Handle g_hHunterSoundTimer[MAXPLAYERS + 1] = INVALID_HANDLE, g_hJockeySoundTimer[MAXPLAYERS + 1] = INVALID_HANDLE;
// Bools
bool g_bIsPouncing[MAXPLAYERS + 1] = false;

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

public void OnPluginStart()
{
	// CreateConVars
	g_hHunterSoundInterval = CreateConVar("Unsilent_HunterSoundInterval", "2.0", "Hunter 多少秒放一次声", CVAR_FLAGS, true, 0.0);
	g_hJockeySoundInterval = CreateConVar("Unsilent_JockeySoundInterval", "2.0", "Jockey 多少秒放一次声", CVAR_FLAGS, true, 0.0);
	// HookEvents
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("player_death", evt_PlayerDeath);
	HookEvent("player_team", evt_PlayerTeam);
	HookEvent("player_shoved", evt_PlayerShoved);
	HookEvent("ability_use", evt_AbilityUse);
}

public void OnMapStart()
{
	for (int i = 0; i < sizeof(JockeySounds); i++)
	{
		if (i < sizeof(HunterSounds))
		{
			PrecacheSound(HunterSounds[i], true);
		}
		PrecacheSound(JockeySounds[i], true);
	}
}

public void L4D_OnEnterGhostState(int client)
{
	if (IsHunter(client))
	{
		ResetTimer(client, view_as<int>(ZC_HUNTER), false);
	}
	else if (IsJockey(client))
	{
		ResetTimer(client, view_as<int>(ZC_JOCKEY), false);
	}
}
// 猴子或 ht 复活时，开始时钟循环，正在控人时，停止放声，死亡时，停止时钟
public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsHunter(client) && IsPlayerAlive(client))
	{
		int hunter_sound = GetRandomInt(1, sizeof(HunterSounds) - 1);
		EmitSoundToAll(HunterSounds[hunter_sound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
		ResetTimer(client, view_as<int>(ZC_HUNTER), true);
	}
	else if (IsJockey(client) && IsPlayerAlive(client))
	{
		ResetTimer(client, view_as<int>(ZC_JOCKEY), true);
	}
}
// 猴子或 ht 死亡或者更换队伍或者进入灵魂状态时，删除时钟，禁止放声
public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsHunter(client))
	{
		ResetTimer(client, view_as<int>(ZC_HUNTER), false);
	}
	else if (IsJockey(client))
	{
		ResetTimer(client, view_as<int>(ZC_JOCKEY), false);
	}
}
public void evt_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsHunter(client))
	{
		ResetTimer(client, view_as<int>(ZC_HUNTER), false);
	}
	else if (IsJockey(client))
	{
		ResetTimer(client, view_as<int>(ZC_JOCKEY), false);
	}
}
public void evt_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userId"));
    if (IsHunter(client))
	{
		g_bIsPouncing[client] = false;
	}
}
public void evt_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userId"));
	if (IsHunter(client))
	{
		char ability[64] = '\0';
		event.GetString("ability", ability, sizeof(ability));
		if (!g_bIsPouncing[client] && strcmp(ability, "ability_lunge") == 0)
		{
			g_bIsPouncing[client] = true;
			CreateTimer(0.1, Timer_GroundTouch, client, TIMER_REPEAT);
		}
	}
}
public Action Timer_GroundTouch(Handle timer, int client)
{
    if (IsHunter(client) && ((GetEntityFlags(client) & FL_ONGROUND) || !IsPlayerAlive(client) || (GetEntityMoveType(client) & MOVETYPE_LADDER)))
    {
        g_bIsPouncing[client] = false;
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

// 方法
bool IsHunter(int client)
{
	return view_as<bool>(GetInfectedClass(client) == view_as<int>(ZC_HUNTER));
}
bool IsJockey(int client)
{
	return view_as<bool>(GetInfectedClass(client) == view_as<int>(ZC_JOCKEY));
}

void ResetTimer(int client, int class, bool enable)
{
	if (class == view_as<int>(ZC_HUNTER))
	{
		if (g_hHunterSoundTimer[client] != INVALID_HANDLE)
		{
			delete g_hHunterSoundTimer[client];
			g_hHunterSoundTimer[client] = INVALID_HANDLE;
		}
		if (enable)
		{
			g_hHunterSoundTimer[client] = CreateTimer(g_hHunterSoundInterval.FloatValue, Timer_CreateHunterSound, client, TIMER_REPEAT);
		}
	}
	else if (class == view_as<int>(ZC_JOCKEY))
	{
		if (g_hJockeySoundTimer[client] != INVALID_HANDLE)
		{
			delete g_hJockeySoundTimer[client];
			g_hJockeySoundTimer[client] = INVALID_HANDLE;
		}
		if (enable)
		{
			g_hJockeySoundTimer[client] = CreateTimer(g_hJockeySoundInterval.FloatValue, Timer_CreateJockeySound, client, TIMER_REPEAT);
		}
	}
}
public Action Timer_CreateHunterSound(Handle timer, int client)
{
	// 客户端无效，停止时钟循环
	if (IsHunter(client) && IsPlayerAlive(client))
	{
		// 不在控人且不在飞扑时，固定时间放一次声，正在控人或正在飞扑时，返回 continue，时钟继续循环，直到无效或者死亡，停止循环
		if (GetEntPropEnt(client, Prop_Send, "m_pounceVictim") <= 0 && !g_bIsPouncing[client])
		{
			int hunter_sound = GetRandomInt(1, sizeof(HunterSounds) - 1);
			EmitSoundToAll(HunterSounds[hunter_sound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}
public Action Timer_CreateJockeySound(Handle timer, int client)
{
	if (IsJockey(client) && IsPlayerAlive(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") <= 0)
		{
			int jockey_sound = GetRandomInt(1, sizeof(JockeySounds) - 1);
			EmitSoundToAll(JockeySounds[jockey_sound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}