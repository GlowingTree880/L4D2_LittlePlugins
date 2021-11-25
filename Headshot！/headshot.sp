#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo = 
{
	name 			= "headshot!",
	author 			= "夜羽真白",
	description 	= "低仿 Mutation2 模式，丧尸只有爆头才会死",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// Convar
ConVar g_hEnable;
int g_iEnable;

public void OnPluginStart()
{
	// CreateConVar
	g_hEnable = CreateConVar("headshot_enable", "0", "是否启用只有爆头击杀才能击杀丧尸：0 = 关闭， 1 = 启用", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hEnable.AddChangeHook(ConVarChanged_Cvars);
	g_iEnable = g_hEnable.IntValue;
	// HookEvent
	HookEvent("infected_hurt", evt_InfectedHurt);
}

public Action evt_InfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	// int hitter = GetClientOfUserId(event.GetInt("attacker"));
	int entityId = event.GetInt("entityid");
	int hitgroup = event.GetInt("hitgroup");
	int amount = event.GetInt("amount");
	// int type = event.GetInt("type");
	char classname[32]; 
	GetEntityClassname(entityId, classname, sizeof(classname));
	// PrintToChatAll("[Debug] hitter: %d, entityId: %d, entityName:%s, hitgroup: %d, amount: %d, type: %d", hitter, entityId, classname, hitgroup, amount, type);
	// hitgroup: 1：头，2：颈， 3：右手，4：左手，5：身体，6：左腿，7：右腿
	// classname：小ss：infected，Witch：witch
	if (g_iEnable == 1)
	{
		if (entityId != 0 && strcmp(classname, "witch") != 0 && hitgroup != 1)
		{
			// 判断不是witch，获取小ss受伤后的血量
			int m_Health = GetEntProp(entityId, Prop_Data, "m_iHealth");
			// 进行血量计算再设置小ss的血量为原来未受伤的血量
			int Health = m_Health + amount;
			SetEntProp(entityId, Prop_Data, "m_iHealth", Health);
		}
	}
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iEnable = g_hEnable.IntValue;
}