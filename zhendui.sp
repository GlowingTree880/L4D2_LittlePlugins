#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_SCRIPTLOGIC "plugin_scripting_logic_entity"
#define COMMANDABOT_ATTACK	"CommandABot({cmd = 0, bot = GetPlayerFromUserID(%i), target = GetPlayerFromUserID(%i)})"
#define COMMANDABOT_RESET	"CommandABot({cmd = 3, bot = GetPlayerFromUserID(%i)})"

int g_iZhenduiClient = -1;
bool g_bIsInZhenduiMode = false;

public Plugin myinfo = 
{
	name 			= "ZhenduiMode",
	author 			= "夜羽真白",
	description 	= "使用脚本命令，使特感以被针对的玩家为目标，直至这名玩家被控",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_zhendui", Cmd_Zhendui, ADMFLAG_ROOT);
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("player_death", evt_PlayerDeath);
}

public Action Cmd_Zhendui(int client, int args)
{
	if (client && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		DrawZhenduiMenu(client);
	}
	return Plugin_Continue;
}

public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInfectedBot(client))
	{
		if (g_bIsInZhenduiMode)
		{
			if (g_iZhenduiClient > 0)
			{
				if (IsValidPlayer(g_iZhenduiClient))
				{
					SDKHook(client, SDKHook_PostThinkPost, SDK_UpdateThink);
				}
			}
		}
	}
}

public void SDK_UpdateThink(int client)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client))
	{
		Logic_RunScript(COMMANDABOT_ATTACK, GetClientUserId(client), GetClientUserId(g_iZhenduiClient));
	}
}

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInfectedBot(client))
	{
		SDKUnhook(client, SDKHook_PostThinkPost, SDK_UpdateThink);
	}
}

public void DrawZhenduiMenu(int client)
{
	Menu menu = new Menu(StartZhenduiHandler);
	menu.SetTitle("请选择需要针对的操作：");
	menu.AddItem("change", "更改针对目标");
	menu.AddItem("stop", "停止针对");
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int StartZhenduiHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char item[16];
		menu.GetItem(param2, item, sizeof(item));
		if (strcmp(item, "change") == 0)
		{
			ShowZhenduiMenu(param1);
		}
		else if (strcmp(item, "stop") == 0)
		{
			g_bIsInZhenduiMode = false;
			for (int infected = 1; infected <= MaxClients; infected++)
			{
				if (IsInfectedBot(infected))
				{
					Logic_RunScript(COMMANDABOT_RESET, GetClientUserId(infected));
				}
			}
			PrintToChat(param1, "\x04【提示】：\x03针对模式 \x05已关闭");
		}
	}
	return 1;
}

public void ShowZhenduiMenu(int client)
{
	Menu menu = new Menu(ZhenduiMenuHandler);
	char name[MAX_NAME_LENGTH], playerid[32];
	menu.SetTitle("请选择一位需要针对的玩家：");
	for (int index = 1; index <= MaxClients; index++)
	{
		if (IsValidPlayer(index) && IsPlayerAlive(index))
		{
			FormatEx(name, sizeof(name), "%N", index);
			FormatEx(playerid, sizeof(playerid), "%i", GetClientUserId(index));
			menu.AddItem(playerid, name);
		}
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int ZhenduiMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char id[16];
		menu.GetItem(param2, id, sizeof(id));
		int userid = StringToInt(id);
		int target = GetClientOfUserId(userid);
		if (IsValidPlayer(target))
		{
			g_bIsInZhenduiMode = true;
			g_iZhenduiClient = target;
			for (int infected = 1; infected <= MaxClients; infected++)
			{
				if (IsInfectedBot(infected))
				{
					Logic_RunScript(COMMANDABOT_ATTACK, GetClientUserId(infected), GetClientUserId(g_iZhenduiClient));
				}
			}
			PrintToChat(param1, "\x04【提示】：\x03针对模式 \x05已开启");
			PrintToChat(param1, "\04【提示】：\x03已针对玩家：\x05%N", g_iZhenduiClient);
		}
		else
		{
			PrintToChat(param1, "\x04【提示】：\x03针对失败，该玩家已死亡或无效");
		}
	}
	else if (action == MenuAction_Cancel)
	{
		DrawZhenduiMenu(param1);
	}
	return 1;
}

bool IsValidPlayer(int client)
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

bool IsInfectedBot(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3)
	{
		return true;
	}
	else
	{
		return false;
	}
}

void Logic_RunScript(const char[] sCode, any ...) 
{
	int iScriptLogic = FindEntityByTargetname(-1, PLUGIN_SCRIPTLOGIC);
	if (!iScriptLogic || !IsValidEntity(iScriptLogic))
	{
		iScriptLogic = CreateEntityByName("logic_script");
		DispatchKeyValue(iScriptLogic, "targetname", PLUGIN_SCRIPTLOGIC);
		DispatchSpawn(iScriptLogic);
	}
	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

int FindEntityByTargetname(int index, const char[] findname)
{
	for (int i = index; i < GetMaxEntities(); i++)
	{
		if (IsValidEntity(i))
		{
			char name[128];
			GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
			if (StrEqual(name, findname, false))
			{
				return i;
			}
		}
	}
	return -1;
}