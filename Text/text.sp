#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define PLUGIN_DATE "2022-2-25"

// ConVars
ConVar g_hInfectedTime, g_hInfectedLimit, g_hTankBhop, g_hWeapon, g_hCvarCoop;
// Ints
int g_iInfectedTime, g_iInfectedLimit, g_iMaxPlayers;
// Bools
bool g_bTankBhop, g_bWeapon, g_bCvarCoop;

public Plugin myinfo = 
{
	name 			= "Function Text",
	author 			= "Anne, Caibiii, 夜羽真白",
	description 	= "更改游戏模式，显示游戏基本数据",
	version 		= "2022-02-25",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

public void OnPluginStart()
{
	g_hInfectedTime = FindConVar("versus_special_respawn_interval");
	g_hInfectedLimit = FindConVar("l4d_infected_limit");
	g_hTankBhop = FindConVar("ai_Tank_Bhop");
	// CreateConVar
	g_hWeapon = CreateConVar("ZonemodWeapon", "0", "是否使用Zonemod武器参数", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarCoop = CreateConVar("coopmode", "0", "游戏模式设定", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// HookEvents
	HookEvent("player_incapacitated_start", evt_IncapEvent, EventHookMode_Post);
	HookEvent("player_incapacitated", evt_IncapEvent, EventHookMode_Post);
	HookEvent("round_start", evt_RoundStart, EventHookMode_Post);
	HookEvent("player_death", evt_PlayerDeath, EventHookMode_Post);
	// RegConsoleCmd
	RegConsoleCmd("sm_xx", Cmd_InfectedStatus);
	RegConsoleCmd("sm_zs", Cmd_Suicide);
	RegConsoleCmd("sm_kill", Cmd_Suicide);
	// AddCnahgeHook
	g_hInfectedTime.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedLimit.AddChangeHook(ConVarChanged_Cvars);
	g_hTankBhop.AddChangeHook(ConVarChanged_Cvars);
	g_hWeapon.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCoop.AddChangeHook(ConVarChanged_Cvars);
	// GetCvars
	GetCvars();
}

// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iInfectedLimit = g_hInfectedLimit.IntValue;
	g_iInfectedTime = g_hInfectedTime.IntValue;
	g_bTankBhop = g_hTankBhop.BoolValue;
	g_bWeapon = g_hWeapon.BoolValue;
	g_bCvarCoop = g_hCvarCoop.BoolValue;
}

// *********************
//		    事件
// *********************
public Action evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
	return Plugin_Continue;
}

public void evt_IncapEvent(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (g_bCvarCoop)
	{
		ForcePlayerSuicide(client);
	}
	if (IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
}

public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	PrintStatus();
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	ReloadPlugins();
	PrintStatus();
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	if (IsValidPlayer(client, false, true))
	{
		g_iMaxPlayers += 1;
		if (g_iMaxPlayers >= 3)
		{
			L4D_LobbyUnreserve();
			ServerCommand("sm_cvar sv_allow_lobby_connect_only 0");
		}
		PrintStatus();
	}
}

// *********************
//		    指令
// *********************
public Action Cmd_Suicide(int client, int args)
{
	ForcePlayerSuicide(client);
	if (IsTeamImmobilised())
	{
		SetConVarString(FindConVar("mp_gamemode"), "realism");
	}
	return Plugin_Handled;
}

public Action Cmd_InfectedStatus(int client, int args)
{
	PrintStatus();
}

// *********************
//		    方法
// *********************
void PrintStatus()
{
	if (g_bTankBhop)
	{
		if (g_bWeapon)
		{
			CPrintToChatAll("{LG}武器{G}[{O}Zone{G}] {LG}Tank连跳{G}[{O}开启{G}] {LG}特感{G}[{O}%d特%d秒{G}] {LG}插件版本{G}[{O}%s{G}]", g_iInfectedLimit, g_iInfectedTime, PLUGIN_DATE);
		}
		else
		{
			CPrintToChatAll("{LG}武器{G}[{O}Anne{G}] {LG}Tank连跳{G}[{O}开启{G}] {LG}特感{G}[{O}%d特%d秒{G}] {LG}插件版本{G}[{O}%s{G}]", g_iInfectedLimit, g_iInfectedTime, PLUGIN_DATE);
		}
	}
	else
	{
		if (g_bWeapon)
		{
			CPrintToChatAll("{LG}武器{G}[{O}Zone{G}] {LG}Tank连跳{G}[{O}关闭{G}] {LG}特感{G}[{O}%d特%d秒{G}] {LG}插件版本{G}[{O}%s{G}]", g_iInfectedLimit, g_iInfectedTime, PLUGIN_DATE);
		}
		else
		{
			CPrintToChatAll("{LG}武器{G}[{O}Anne{G}] {LG}Tank连跳{G}[{O}关闭{G}] {LG}特感{G}[{O}%d特%d秒{G}] {LG}插件版本{G}[{O}%s{G}]", g_iInfectedLimit, g_iInfectedTime, PLUGIN_DATE);
		}
	}
}

bool IsValidPlayer(int client, bool allowbot, bool allowdeath)
{
	if (client && client <= MaxClients)
	{
		if (IsClientConnected(client) && IsClientInGame(client))
		{
			if (!allowbot)
			{
				if (IsFakeClient(client))
				{
					return false;
				}
			}
			if (!allowdeath)
			{
				if (!IsPlayerAlive(client))
				{
					return false;
				}
			}
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
}

bool IsValidSurvivor(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsIncapped(int client)
{
	bool bIsIncapped;
	if (IsValidSurvivor(client))
	{
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0)
		{
			bIsIncapped = true;
		}
		if (!IsPlayerAlive(client))
		{
			bIsIncapped = true;
		}
	}
	return bIsIncapped;
}

void ReloadPlugins()
{
	ServerCommand("sm plugins load_unlock");
	ServerCommand("sm plugins reload optional/hunters.smx");
	ServerCommand("sm plugins reload optional/Alone.smx");
	ServerCommand("sm plugins reload optional/infected_control.smx");
	ServerCommand("sm plugins load_lock");
	ServerCommand("sm_startspawn");
}

bool IsTeamImmobilised()
{
	bool bIsTeamImmobilised = true;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			if (!IsIncapped(client))
			{
				bIsTeamImmobilised = false;
			}
		}
	}
	return bIsTeamImmobilised;
}