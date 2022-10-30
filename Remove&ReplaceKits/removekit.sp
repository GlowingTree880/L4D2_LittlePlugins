#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo = 
{
	name 			= "Remove Kits",
	author 			= "Caibiii, 夜羽真白",
	description 	= "开局删除已经缓存在地图上的急救包",
	version 		= "2022.02.25",
	url 			= "https://github.com/GlowingTree880/L4D2_LittlePlugins"
}

public void OnPluginStart()
{
	HookEvent("round_start", evt_RoundStart, EventHookMode_Pre);
}

public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, RoundStartTimer);
}

public Action RoundStartTimer(Handle timer)
{
	RemoveKits();
	return Plugin_Continue;
}

public Action RemoveKits()
{
	char mapname[16];
	GetCurrentMap(mapname, sizeof(mapname));
	/*
	if (strcmp(mapname, "c5m5_bridge") == 0 || strcmp(mapname, "c13m4_cutthroatcreek") == 0)
	{
		ServerCommand("sm_cvar z_common_limit 0");
	}
	*/
	for (int entity = 1; entity <= GetEntityCount(); entity++)
	{
		if (IsValidEntity(entity) && IsValidEdict(entity))
		{
			char entityname[128];
			GetEdictClassname(entity, entityname, sizeof(entityname));
			if (strcmp(entityname, "weapon_spawn") == 0)
			{
				if (GetEntProp(entity, Prop_Data, "m_weaponID") == 12)
				{
					RemoveItem(entity);
				}
			}
			else
			{
				if (strcmp(entityname, "weapon_first_aid_kit_spawn") == 0)
				{
					RemoveItem(entity);
				}
			}
		}
	}
	return Plugin_Continue;
}

void RemoveItem(int entity)
{
	RemoveEdict(entity);
}
