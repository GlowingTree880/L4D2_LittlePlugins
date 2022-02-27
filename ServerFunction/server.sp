#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

// ConVars
ConVar g_hMotdTitle, g_hMotdUrl, g_hIpUrl, g_hMaxSurvivors, g_hWitchKillReturn;
// Ints
int g_iMaxSurvivors, g_iWitchKillReturn;
// Floats
float g_fLastDisconnectTime = 0.0;
// Chars
char sClientIP[36], sSteamID[21];
// Bools
bool g_bGameStart = false;

public Plugin myinfo = 
{
	name 			= "Server",
	author 			= "夜羽真白",
	description 	= "服务器管理功能",
	version 		= "2022.2.26",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

public void OnPluginStart()
{
	// Commands
	RegConsoleCmd("sm_away", Cmd_Away);
	RegConsoleCmd("sm_s", Cmd_Away);
	RegConsoleCmd("sm_ammo", Cmd_GiveAmmo);
	// JoinTeam
	RegConsoleCmd("sm_join", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_jg", Cmd_JoinSurvivor);
	RegConsoleCmd("sm_ip", Cmd_ShowServerIp);
	// AdminCommand
	RegAdminCmd("sm_restartmap", Cmd_RestartMap, ADMFLAG_ROOT, "重启当前地图");
	RegAdminCmd("sm_restart", Cmd_RestartServer, ADMFLAG_ROOT, "服务器重启");
	// HookEvents
	HookEvent("player_team", evt_ChangeTeam, EventHookMode_Post);
	HookEvent("witch_killed", evt_WitchKilled, EventHookMode_Post);
	HookEvent("map_transition", evt_ResetSurvivors, EventHookMode_Post);
	HookEvent("finale_win", evt_ResetSurvivors, EventHookMode_Post);
	HookEvent("round_start", evt_RoundStart, EventHookMode_Post);
	HookEvent("player_disconnect", evt_PlayerDisconnect);
	// CommandListener
	AddCommandListener(Command_JoinTeam, "jointeam");
	AddCommandListener(Command_ChooseTeam, "chooseteam");
	// SoundHook
	AddNormalSoundHook(OnNormalSound);
	AddAmbientSoundHook(OnAmbientSound);
	// CreateConVar
	g_hMotdTitle = CreateConVar("sm_cfgmotd_title", "坐牢开心！", "显示在 motd 上面的服务器标题", FCVAR_NOTIFY);
	g_hMotdUrl = CreateConVar("sm_cfgmotd_url", "http://47.115.132.92/aliyun/rank.php", "显示给 motd 的 URL", FCVAR_NOTIFY);
	g_hIpUrl = CreateConVar("sm_cfgip_url", "http://47.115.132.92/aliyun/serverip.php", "显示 IP 的 URL", FCVAR_NOTIFY);
	g_hWitchKillReturn = CreateConVar("sm_witchkill_health", "15", "生还者秒妹恢复多少实血", FCVAR_CHEAT, true, 0.0);
	g_hMaxSurvivors = FindConVar("survivor_limit");
	// AddChangeHook
	g_hMaxSurvivors.AddChangeHook(ConVarChanged_Cvars);
	g_hWitchKillReturn.AddChangeHook(ConVarChanged_Cvars);
	// MaxSurvivors
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
	g_iMaxSurvivors = g_hMaxSurvivors.IntValue;
	g_iWitchKillReturn = g_hWitchKillReturn.IntValue;
	if (g_iMaxSurvivors == 4)
	{
		CreateTimer(5.0, Timer_Unload, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	int iSurvivors = GetHumanCount();
	if (iSurvivors > g_iMaxSurvivors)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR)
			{
				KickClient(client, "Kicked By Console");
			}
		}
		ServerCommand("sm_addbot");
	}
}

public Action Timer_Unload(Handle timer, int client)
{
	ServerCommand("sm plugins unload optional/l4d2_multislots.smx");
	return Plugin_Continue;
}

public Action IsNobodyConnected(Handle timer, float disconnecttime)
{
	if (g_fLastDisconnectTime != disconnecttime)
	{
		return Plugin_Stop;
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && !IsFakeClient(client))
		{
			return Plugin_Stop;
		}
	}
	RestartServer();
	return Plugin_Stop;
}

// *********************
//		   指令
// *********************
public Action Cmd_RestartServer(int client, int args)
{
	RestartServer();
	return Plugin_Continue;
}

public Action Cmd_ShowServerIp(int client, int args)
{
	CPrintToChat(client, "{LG}[树树子の服务器IP列表(*/ω＼*)]");
	CPrintToChat(client, "{LG}纯狱风(21-7-7)：{O}106.52.55.117:27020");
	CPrintToChat(client, "{LG}1vht内卷现状(21-10-10)：{O}119.91.150.248:27025");
	CPrintToChat(client, "{LG}峰回路转，仍是坐牢(22-2-7)：{O}139.155.89.192:27025");
	// 显示面板
	char sTitle[16], sURL[48];
	GetConVarString(g_hMotdTitle, sTitle, sizeof(sTitle));
	GetConVarString(g_hIpUrl, sURL, sizeof(sURL));
	ShowMOTDPanel(client, sTitle, sURL, MOTDPANEL_TYPE_URL);
	return Plugin_Continue;
}

public Action Cmd_JoinSurvivor(int client, int args)
{
	if (client && client <= MaxClients && IsClientInGame(client))
	{
		// 生还者团队未满的情况
		if (!IsSurvivorTeamFull())
		{
			// 想换人物了
			if (GetClientTeam(client) == TEAM_SURVIVOR)
			{
				DrawSwitchCharacterMenu(client);
			}
			else
			{
				FakeClientCommand(client, "jointeam survivor");
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Cmd_Away(int client, int args)
{
	if (!IsPinned(client))
	{
		CreateTimer(3.0, MoveClientToSpec, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Handled;
}

public Action Cmd_GiveAmmo(int client, int args)
{
	if (IsValidSurvivor(client))
	{
		BypassAndExecuteCommand(client, "give", "ammo");
	}
	return Plugin_Handled;
}

public Action Cmd_RestartMap(int client, int args)
{
	RestartMap();
	return Plugin_Continue;
}

// *********************
//		   事件
// *********************
public void OnMapStart()
{
	g_bGameStart = false;
	SetGodMode(true);
}

public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bGameStart = false;
	// 开启无敌模式
	SetGodMode(true);
	CreateTimer(3.0, Timer_RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action evt_ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
	RestoreHealth();
	ResetInventory();
	return Plugin_Continue;
}

public Action evt_ChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int newteam = event.GetInt("team");
	bool disconnect = event.GetBool("disconnect");
	if (IsValidPlayer(client, true, true) && !disconnect && newteam == TEAM_INFECTED)
	{
		if (!IsFakeClient(client))
		{
			CreateTimer(0.5, MoveClientToSpec, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

// 秒妹回血
public void evt_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSurvivor(client) && IsPlayerAlive(client) && !IsIncapped(client))
	{
		int iMaxHp = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		int iTargetHealth = GetSurvivorPermHealth(client) + g_iWitchKillReturn;
		if (iTargetHealth > iMaxHp)
		{
			iTargetHealth = iMaxHp;
		}
		SetSurvivorPermHealth(client, iTargetHealth);
	}
}

// 对抗计分面板出现前，切换游戏模式为写实，realism based on coop，实际为战役，不会出现计分板
public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarString(FindConVar("mp_gamemode"), "realism");
	return Plugin_Handled;
}

// 开局，切换游戏模式为战役，coop based on versus，实际为对抗
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	CreateTimer(0.5, Timer_AutoGive, _, TIMER_FLAG_NO_MAPCHANGE);
	// 关闭上帝模式
	SetGodMode(false);
	g_bGameStart = true;
	return Plugin_Stop;
}

public Action Timer_AutoGive(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client))
		{
			BypassAndExecuteCommand(client, "give", "health");
			BypassAndExecuteCommand(client, "give", "pain_pills");
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
			// 多人运动时，先清除 Bot 身上物品到包的 slot，再给予 Bot 物品
			if (IsFakeClient(client))
			{
				for (int slot = 0; slot < 4; slot++)
				{
					DeleteInventoryItem(client, slot);
				}
				BypassAndExecuteCommand(client, "give", "smg_silenced");
				BypassAndExecuteCommand(client, "give", "pistol_magnum");
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_RoundStartDelay(Handle timer)
{
	SetConVarString(FindConVar("mp_gamemode"), "coop");
	char sMapConfig[32];
	GetCurrentMap(sMapConfig, sizeof(sMapConfig));
	Format(sMapConfig, sizeof(sMapConfig), "cfg/sourcemod/map_cvars/%s.cfg", sMapConfig);
	if (FileExists(sMapConfig, true, "GAME"))
	{
		strcopy(sMapConfig, sizeof(sMapConfig), sMapConfig[1]);
		ServerCommand("exec \"%s\"", sMapConfig);
	}
	return Plugin_Continue;
}

public Action Timer_FirstMoveToSpec(Handle timer, int client)
{
	if (IsValidPlayerInTeam(client, TEAM_INFECTED))
	{
		ChangeClientTeam(client, TEAM_SPECTATOR);
	}
	return Plugin_Continue;
}

public Action MoveClientToSpec(Handle timer, int client)
{
	ChangeClientTeam(client, TEAM_SPECTATOR);
	return Plugin_Continue;
}

public Action Command_JoinTeam(int client, const char[] command, int args)
{
	char sTeam[16], sName[16];
	GetCmdArg(1, sTeam, sizeof(sTeam));
	GetCmdArg(2, sName, sizeof(sName));
	if (!(strcmp(sTeam, "survivor") == 0) || IsSurvivorTeamFull())
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Command_ChooseTeam(int client, const char[] command, int args)
{
	return Plugin_Handled;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	GetClientIP(client, sClientIP, sizeof(sClientIP), true);
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	if (!IsFakeClient(client))
	{
		CPrintToChatAll("{LG}[(*･ω< )]：新的牢友 {O}%N {LG}[{O}%s{LG}] 正在进入牢房...", client, sSteamID);
	}
}

public void OnClientPutInServer(int client)
{
	ShowMotdToPlayer(client);
	if (client && IsClientConnected(client) && !IsFakeClient(client))
	{
		CreateTimer(3.0, Timer_FirstMoveToSpec, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void evt_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	SetEventBroadcast(event, true);
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && client <= MaxClients)
	{
		char steamid[64];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		if (!(strcmp(steamid, "BOT") == 0))
		{
			char sReason[128], sTimedOut[256];
			GetEventString(event, "reason", sReason, sizeof(sReason));
			Format(sTimedOut, sizeof(sTimedOut), "%N timed out", client);
			CPrintToChatAll("{G}[(；へ：)]：牢友 {O}%N {G}[{O}%s{G}] 承受不住，选择了越狱...\n这究竟是为什么呢：{O}%s", client, steamid, sReason);
			if (strcmp(sReason, sTimedOut) == 0 || strcmp(sReason, "No Steam logon") == 0)
			{
				CPrintToChatAll("{G}[(；へ：)]：牢友 {O}%N {G}[{O}%s{G}] 的设备出了点故障...\n这究竟是为什么呢：{O}crashed", client, steamid, sReason);
			}
		}
	}
}

// *********************
//		   功能
// *********************
public void OnAutoConfigsBuffered()
{
	char sMapConfig[32];
	GetCurrentMap(sMapConfig, sizeof(sMapConfig));
	Format(sMapConfig, sizeof(sMapConfig), "cfg/sourcemod/map_cvars/%s.cfg", sMapConfig);
	if (FileExists(sMapConfig, true, "GAME"))
	{
		strcopy(sMapConfig, sizeof(sMapConfig), sMapConfig[1]);
		ServerCommand("exec \"%s\"", sMapConfig);
	}
}

void ShowMotdToPlayer(int client)
{
	char sTitle[16], sURL[48];
	GetConVarString(g_hMotdTitle, sTitle, sizeof(sTitle));
	GetConVarString(g_hMotdUrl, sURL, sizeof(sURL));
	ShowMOTDPanel(client, sTitle, sURL, MOTDPANEL_TYPE_URL);
}

// 清除物品
void ResetInventory()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client))
		{
			for (int slot = 0; slot < 5; slot++)
			{
				DeleteInventoryItem(client, slot);
			}
			BypassAndExecuteCommand(client, "give", "pistol");
		}
	}
}

void DeleteInventoryItem(int client, int slot)
{
	int item = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(item) && IsValidEdict(item))
	{
		RemovePlayerItem(client, item);
	}
}

// 禁用烟花爆炸声音
public Action OnNormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}

public Action OnAmbientSound(char sample[PLATFORM_MAX_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
	return (StrContains(sample, "firewerks", true) > -1) ? Plugin_Stop : Plugin_Continue;
}

// 回血
void RestoreHealth()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client))
		{
			BypassAndExecuteCommand(client, "give", "health");
			SetEntPropFloat(client, Prop_Data, "m_healthBuffer", 0.0);
			SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
		}
	}
}

// 重启服务器
void RestartServer()
{
	SetCommandFlags("crash", GetCommandFlags("crash") & ~ FCVAR_CHEAT);
	SetCommandFlags("sv_crash", GetCommandFlags("sv_crash") & ~ FCVAR_CHEAT);
	ServerCommand("crash");
	ServerCommand("sv_crash");
}

void RestartMap()
{
	char sMapName[16];
	GetCurrentMap(sMapName, sizeof(sMapName));
	ServerCommand("changelevel %s", sMapName);
}

int GetHumanCount()
{
	int iSurvivors = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
		{
			iSurvivors++;
		}
	}
	return iSurvivors;
}

bool IsSurvivorTeamFull()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && IsFakeClient(client))
		{
			return false;
		}
	}
	return true;
}

bool IsValidSurvivor(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) ==TEAM_SURVIVOR)
	{
		return true;
	}
	else
	{
		return false;
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

bool IsValidPlayerInTeam(int client, int team)
{
	if (IsValidPlayer(client, true, true))
	{
		if (team == GetClientTeam(client))
		{
			return true;
		}
	}
	return false;
}

bool IsPinned(int client)
{
	bool bIsPinned = false;
	if (IsValidSurvivor(client) && IsPlayerAlive(client))
	{
		if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true;
	}		
	return bIsPinned;
}

int GetSurvivorPermHealth(int client)
{
	return GetEntProp(client, Prop_Data, "m_iHealth");
}

void SetSurvivorPermHealth(int client, int health)
{
	SetEntProp(client, Prop_Data, "m_iHealth", health);
}

bool IsIncapped(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

public void BypassAndExecuteCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~ FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

void SetGodMode(bool canset)
{
	int flags = GetCommandFlags("god");
	SetCommandFlags("god", flags & ~ FCVAR_NOTIFY);
	SetConVarInt(FindConVar("god"), canset);
	SetCommandFlags("god", flags);
	SetConVarInt(FindConVar("sv_infinite_ammo"), canset);
}

public void DrawSwitchCharacterMenu(int client)
{
	Menu menu = new Menu(SwitchCharacterMenuHandler);
	menu.SetTitle("请选择喜欢的人物：");
	// 添加 Bot 到菜单中
	int menuindex = 0;
	for (int bot = 1; bot <= MaxClients; bot++)
	{
		if (IsClientInGame(bot))
		{
			char botid[32], botname[32], menuitem[8];
			GetClientName(bot, botname, sizeof(botname));
			GetClientAuthId(bot, AuthId_Steam2, botid, sizeof(botid));
			if (strcmp(botid, "BOT") == 0 && GetClientTeam(bot) == TEAM_SURVIVOR)
			{
				GetClientName(bot, botname, sizeof(botname));
				IntToString(menuindex, menuitem, sizeof(menuitem));
				menu.AddItem(menuitem, botname);
				menuindex++;
			}
		}
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int SwitchCharacterMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (!g_bGameStart && action == MenuAction_Select)
	{
		char botname[32];
		GetMenuItem(menu, param2, botname, sizeof(botname), _, botname, sizeof(botname));
		ChangeClientTeam(param1, TEAM_SPECTATOR);
		ClientCommand(param1, "jointeam survivor %s", botname);
	}
	else if (action == MenuAction_Cancel)
	{
		delete menu;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}