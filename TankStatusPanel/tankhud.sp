#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

public Plugin myinfo = 
{
	name 			= "Spectator And InfectedTeam Tank Hud",
	author 			= "夜羽真白",
	description 	= "旁观者与特感团队的坦克面板",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar tankburnduration;
// Ints
int tankclient = -1;
// Bools
bool istankactive = false, hiddenpanel[MAXPLAYERS + 1] = false, invomit[MAXPLAYERS + 1] = false;

public void OnPluginStart()
{
	// ConVars
	tankburnduration = FindConVar("tank_burn_duration");
	// Commands
	RegConsoleCmd("sm_tankhud", Cmd_TankHud, "开启关闭坦克面板");
	// Events
	HookEvent("round_start", evt_RoundEvent, EventHookMode_PostNoCopy);
	HookEvent("round_end", evt_RoundEvent, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", evt_TankSpawn);
	HookEvent("player_death", evt_PlayerDeath);
	HookEvent("player_now_it", evt_PlayerNowIt);
}

// *********************
//		   指令
// *********************
public Action Cmd_TankHud(int client, int args)
{
	if (!hiddenpanel[client])
	{
		hiddenpanel[client] = true;
		CPrintToChat(client, "{G}<TankHUD>：{W}Tank HUD now is {LG}disabled");
	}
	else
	{
		hiddenpanel[client] = false;
		CPrintToChat(client, "{G}<TankHUD>：{W}Tank HUD now is {LG}enabled");
	}
}

// *********************
//		   事件
// *********************
public void evt_RoundEvent(Event event, const char[] name, bool dontBroadcast)
{
	istankactive = false;
	tankclient = -1;
}

public void evt_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	tankclient = GetClientOfUserId(event.GetInt("userid"));
	if (!istankactive)
	{
		istankactive = true;
		CreateTimer(0.5, Timer_RefreshPanel, _, TIMER_REPEAT);
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) != 2 && hiddenpanel[client])
		{
			CPrintToChat(client, "{G}<TankHUD>：{W}TankHUD now is {LG}disabled\nType {O}!tankhud {W}into chat to toggle the {LG}tankhud");
		}
	}
}

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{
		UpdateTank(client);
	}
}

public void evt_PlayerNowIt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{
		invomit[client] = true;
		float blindtime = GetConVarFloat(FindConVar("z_vomit_fade_start"));
		float fadetime = GetConVarFloat(FindConVar("z_vomit_fade_duration"));
		CreateTimer(blindtime + fadetime, Timer_DisableBlind, client);
	}
}

public Action Timer_DisableBlind(Handle timer, int client)
{
	invomit[client] = false;
}

public void OnClientDisconnect(int client)
{
	if (client > 0 && client <= MaxClients && GetClientTeam(client) == 2 && !IsFakeClient(client))
	{
		hiddenpanel[client] = false;
	}
}

void UpdateTank(int oldtankclient)
{
	int newtank = -1;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client != oldtankclient && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
		{
			newtank = client;
			break;
		}
	}
	if (newtank <= 0)
	{
		istankactive = false;
	}
}

// 部分代码来自 Zonemod spechud.sp（Hyper-V HUD Manager） by Visor, Forgetest，link：https://github.com/Target5150/MoYu_Server_Stupid_Plugins
public Action Timer_RefreshPanel(Handle timer)
{
	Panel menupanel = new Panel();
	if (istankactive)
	{
		static char info[64], name[64], rage[64];
		if (menupanel != INVALID_HANDLE)
		{
			delete menupanel;
		}
		menupanel = new Panel();
		DrawPanelText(menupanel, "Tank HUD：");
		DrawPanelText(menupanel, " \n");
		if (!IsFakeClient(tankclient))
		{
			GetClientFixedName(tankclient, name, sizeof(name));
			FormatEx(info, sizeof(info), "◆ 控制：%s", name, info);
		}
		else
		{
			info = "◆ 控制：AI";
		}
		DrawPanelText(menupanel, info);
		// 生命显示
		int health = GetClientHealth(tankclient);
		int tankmaxhealth = GetEntProp(tankclient, Prop_Send, "m_iMaxHealth");
		if (health > 0 && !IsIncapped(tankclient))
		{
			FormatEx(info, sizeof(info), "◆ 当前生命值：%d / %.1f%%", health, 100.0 * health / tankmaxhealth);
		}
		else
		{
			FormatEx(info, sizeof(info), "◆ 当前：已死亡");
		}
		DrawPanelText(menupanel, info);
		// 控制权显示
		int passcount = L4D2Direct_GetTankPassedCount();
		switch (passcount)
		{
			case 0:
			{
				FormatEx(info, sizeof(info), "Native");
			}
			case 1:
			{
				FormatEx(info, sizeof(info), "%dst", passcount);
			}
			case 2:
			{
				FormatEx(info, sizeof(info), "%dnd", passcount);
			}
			case 3:
			{
				FormatEx(info, sizeof(info), "%drd", passcount);
			}
			default:
			{
				FormatEx(info, sizeof(info), "%dth", passcount);
			}
		}
		FormatEx(rage, sizeof(rage), "◆ 控制权：%d%%（%s）", GetTankFrustration(tankclient), info);
		DrawPanelText(menupanel, rage);
		// 是否着火
		if (GetEntityFlags(tankclient) & FL_ONFIRE)
		{
			if (!IsIncapped(tankclient))
			{
				FormatEx(info, sizeof(info), "◆ 着火状态：%.1f 秒后死亡", health / float(GetConVarInt(tankburnduration)));
			}
			else
			{
				FormatEx(info, sizeof(info), "◆ 着火状态：无（已死亡）", health / float(GetConVarInt(tankburnduration)));
			}
		}
		else
		{
			FormatEx(info, sizeof(info), "◆ 着火状态：未着火", health / float(GetConVarInt(tankburnduration)));
		}
		DrawPanelText(menupanel, info);
		// 是否被胆汁
		if (invomit[tankclient])
		{
			FormatEx(info, sizeof(info), "◆ 胆汁状态：正在胆汁效果中");
		}
		else
		{
			FormatEx(info, sizeof(info), "◆ 胆汁状态：无");
		}
		DrawPanelText(menupanel, info);
		// 网络状态
		if (!IsFakeClient(tankclient))
		{
			FormatEx(info, sizeof(info), "◆ 网络：%dms", RoundToNearest(GetClientAvgLatency(tankclient, NetFlow_Both) * 100.0));
		}
		else
		{
			FormatEx(info, sizeof(info), "◆ 网络：AI");
		}
		DrawPanelText(menupanel, info);
		// 将面板发送至旁观者与感染者团队
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) != 2 && !hiddenpanel[client])
			{
				menupanel.Send(client, PanelHandler, 3);
				if (client == tankclient && !IsFakeClient(tankclient))
				{
					menupanel.Send(tankclient, PanelHandler, 3);
				}
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public int PanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

bool IsValidTank(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3)
	{
		return true;
	}
	else
	{
		return false;
	}
}

int GetTankFrustration(int client)
{
	int frustration = 0;
	if (IsValidTank(client))
	{
		frustration = 100 - GetEntProp(client, Prop_Send, "m_frustration");
	}
	return frustration;
}

bool IsIncapped(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

void GetClientFixedName(int client, char[] name, int len)
{
	GetClientName(client, name, len);
	if (name[0] == '[')
	{
		char temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp) - 2] = 0;
		strcopy(name[1], len - 1, temp);
		name[0] = ' ';
	}
	if (strlen(name) > 18)
	{
		name[15] = name[16] = name[17] = '.';
		name[18] = 0;
	}
}