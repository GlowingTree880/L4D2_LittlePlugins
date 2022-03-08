/*
 * @Author:             夜羽真白
 * @Last Modified by:   夜羽真白
 * @Create Date:        2022-02-27
 * @Last Modified time: 2022-02-27
 * @Github:            https://github.com/GlowingTree880/L4D2_LittlePlugins
 */

#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo = 
{
	name 			= "Replace",
	author 			= "Anne, Caibiii, 夜羽真白",
	description 	= "Replace",
	version 		= "2022.2.27",
	url 			= "https://github.com/Caibiii/AnneServer"
}

public void OnPluginStart()
{
	HookEvent("round_start", evt_RoundStart);
}

public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(5.0, Timer_RoundStart);
}

public Action Timer_RoundStart(Handle timer)
{
	ReplaceKits();
	return Plugin_Continue;
}

public Action ReplaceKits()
{
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
					ReplaceItem(entity);
				}
			}
			else
			{
				if (strcmp(entityname, "weapon_first_aid_kit_spawn") == 0)
				{
					ReplaceItem(entity);
				}
			}
		}
	}
}

void ReplaceItem(int entity)
{
	float fPos[3], fAngles[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", fPos);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", fAngles);
	// 获取原来位置医疗包的位置与角度，先清除原来位置的医疗包
	RemoveEdict(entity);
	int iPills = CreateEntityByName("weapon_spawn");
	SetEntProp(iPills, Prop_Data, "m_weaponID", 15);
	DispatchKeyValue(iPills, "count", "1");
	TeleportEntity(iPills, fPos, fAngles, NULL_VECTOR);
	DispatchSpawn(iPills);
	SetEntityMoveType(iPills, MOVETYPE_NONE);
}