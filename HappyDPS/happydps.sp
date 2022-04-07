#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_BOOMER 2
#define ZC_SPITTER 4
#define ZC_TANK 8

public Plugin myinfo = 
{
	name 			= "HappyDPS",
	author 			= "夜羽真白",
	description 	= "令人快乐的口水和胖子",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hDamageType, g_hSpitterDamagePer, g_hBoomerDamagerPer, g_hSpitterDamage, g_hBoomerDamage, g_hTankCloseDoor, g_hBoomerNoDamage, g_hSpitterNoDamage;
// Ints
int g_iDamageType = 0, g_iSpitterDamagePer = 0, g_iBoomerDamagePer = 0, g_iSpitterDamage = 0, g_iBoomerDamage = 0, g_iBoomerNoDamage = 0, g_iSpitterNoDamage = 0, g_iCheckPointDoor = -1;
// Bools
bool g_bTankCloseDoor = false,
g_bMeleeFire[MAXPLAYERS + 1][MAXPLAYERS + 1], g_bHasRecordDamage[MAXPLAYERS + 1] = false;
// Floats
float g_fDamage[MAXPLAYERS + 1] = {0.0};

public void OnPluginStart()
{
	g_hDamageType = CreateConVar("dps_damage_type", "1", "DPS特感受到伤害的类型：0=关闭插件，1=概率受到近战伤害，2=受到固定数值近战伤害，3=概率免伤", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_hSpitterDamagePer = CreateConVar("spitter_damage_percent", "50", "Spitter每次只会受到第一次近战伤害 * 此数值的伤害", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hBoomerDamagerPer = CreateConVar("boomer_damage_percent", "50", "Boomer每次只会受到第一次近战伤害 * 此数值的伤害", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hSpitterDamage = CreateConVar("spitter_damage", "10", "Spitter每次受到近战击打只会受到这么多伤害", FCVAR_NOTIFY, true, 0.0);
	g_hBoomerDamage = CreateConVar("boomer_damage", "10", "Boomer每次受到近战击打只会受到这么多伤害", FCVAR_NOTIFY, true, 0.0);
	g_hBoomerNoDamage = CreateConVar("boomer_no_damageper", "50", "Boomer每次受到近战伤害免伤的概率", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hSpitterNoDamage = CreateConVar("spitter_no_damageper", "50", "Spitter每次受到近战伤害免伤的概率", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hTankCloseDoor = CreateConVar("tank_close_door", "1", "是否在坦克在场时关闭安全门", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// AddChangeHook
	g_hDamageType.AddChangeHook(ConVarChanged_Cvars);
	g_hSpitterDamagePer.AddChangeHook(ConVarChanged_Cvars);
	g_hBoomerDamagerPer.AddChangeHook(ConVarChanged_Cvars);
	g_hSpitterDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hBoomerDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hBoomerNoDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hSpitterNoDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hTankCloseDoor.AddChangeHook(ConVarChanged_Cvars);
	// Events
	HookEvent("weapon_fire", evt_WeaponFire);
	HookEvent("player_death", evt_PlayerDeath);
	HookEvent("tank_spawn", evt_TankSpawn);
	HookEvent("player_use", evt_PlayerUse, EventHookMode_Pre);
	HookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
	// GetCvars
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iDamageType = g_hDamageType.IntValue;
	g_iSpitterDamagePer = g_hSpitterDamagePer.IntValue;
	g_iBoomerDamagePer = g_hBoomerDamagerPer.IntValue;
	g_iSpitterDamage = g_hSpitterDamage.IntValue;
	g_iBoomerDamage = g_hBoomerDamage.IntValue;
	g_iBoomerNoDamage = g_hBoomerNoDamage.IntValue;
	g_iSpitterNoDamage = g_hSpitterNoDamage.IntValue;
	g_bTankCloseDoor = g_hTankCloseDoor.BoolValue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDKHook_TakeDamage);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, SDKHook_TakeDamage);
}

public void evt_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	// 清除所有客户端的攻击次数
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bMeleeFire[i][client] = false;
	}
}

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK)
	{
		if (!HasAnyTank())
		{
			PrintToChatAll("\x04【提示】：\x05当前所有 \x03Tank \x05已死亡，安全门可打开");
			LockDoor(false);
		}
	}
	g_bHasRecordDamage[client] = false;
	g_fDamage[client] = 0.0;
}

public void evt_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsBuggedMap())
	{
		LockDoor(true);
	}
}

public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, InitDoor);
}

public void evt_PlayerUse(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bTankCloseDoor)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		int target = event.GetInt("targetid");
		if (IsValidEntity(target) && IsValidEdict(target))
		{
			char classname[64];
			GetEdictClassname(target, classname, sizeof(classname));
			if (strcmp(classname, "prop_door_rotating_checkpoint") == 0 && EntIndexToEntRef(target) == g_iCheckPointDoor)
			{
				if (HasAnyTank())
				{
					PrintToChat(client, "\x04【提示】：\x05您必须杀死当前 \x03Tank \x05才可打开\x03终点安全门");
				}
			}
		}
	}
}

public Action SDKHook_TakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsValidClient(attacker) && IsPlayerAlive(attacker) && GetClientTeam(attacker) == TEAM_SURVIVOR && IsDPS(victim))
	{
		if (IsMelee(inflictor) || damagetype & DMG_SLOWBURN && damage > 0.0)
		{
			// 设置伤害值
			if (!g_bMeleeFire[victim][attacker])
			{
				switch (g_iDamageType)
				{
					case 1:
					{
						// 以后每次都以第一次近战伤害为基准，防止砍不死特感
						if (!g_bHasRecordDamage[victim])
						{
							g_fDamage[victim] = damage;
							g_bHasRecordDamage[victim] = true;
						}
						float health = float(GetClientHealth(victim));
						float fdamage = g_fDamage[victim];
						fdamage *= GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_BOOMER ? (float(g_iBoomerDamagePer) / 100.0) : (float(g_iSpitterDamagePer) / 100.0);
						damage = (health < fdamage) ? health : fdamage;
						// PrintToChatAll("受到的伤害：%.2f", fdamage);
						// 将一次近战的判断放在 return 前执行，一次近战攻击会执行多次 OnTakeDamage，先 return 则无法修改近战伤害
						g_bMeleeFire[victim][attacker] = true;
						return Plugin_Changed;
					}
					case 2:
					{
						damage = GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_BOOMER ? float(g_iBoomerDamage) : float(g_iSpitterDamage);
						// PrintToChatAll("受到的伤害：%.2f", damage);
						g_bMeleeFire[victim][attacker] = true;
						return Plugin_Changed;
					}
					case 3:
					{
						int percent = RoundToNearest(GetRandomFloat(0.0, 100.0));
						if (percent < (GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_BOOMER ? g_iBoomerNoDamage : g_iSpitterNoDamage))
						{
							damage = 0.0;
							g_bMeleeFire[victim][attacker] = true;
							return Plugin_Continue;
						}
					}
				}
			}
			else
			{
				damage = 0.0;
				return Plugin_Changed;
			}
		}
		else
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action InitDoor(Handle timer)
{
	if (!IsBuggedMap())
	{
		GetDoor();
	}
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsBotInfected(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsDPS(int client)
{
	if (IsBotInfected(client))
	{
		if (GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_BOOMER || GetEntProp(client, Prop_Send, "m_zombieClass") == 4)
		{
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

bool IsMelee(int entity)
{
	if (entity > MaxClients && IsValidEntity(entity))
	{
		char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (strncmp(classname[7], "melee", 5, true) == 0)
		{
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

void GetDoor()
{
	char name[20];
	int found = 0, entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != -1)
	{
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
		if (strcmp(name, "checkpoint_entrance") == 0)
		{
			g_iCheckPointDoor = EntIndexToEntRef(entity);
			found = 1;
			break;
		}
	}
	char modelname[64];
	if (found == 0)
	{
		while ((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) > -1)
		{
			if (IsValidEntity(entity))
			{
				GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
				if (StrContains(modelname, "checkpoint_door") > -1 && StrContains(modelname, "02") > -1)
				{
					g_iCheckPointDoor = EntIndexToEntRef(entity);
					break;
				}
			}
		}
	}
}

void LockDoor(bool lock)
{
	int entity = EntRefToEntIndex(g_iCheckPointDoor);
	if (entity != INVALID_ENT_REFERENCE)
	{
		if (lock)
		{
			AcceptEntityInput(entity, "Close");
			AcceptEntityInput(entity, "Lock");
			AcceptEntityInput(entity, "ForceClosed");
			if (HasEntProp(entity, Prop_Data, "m_hasUnlockSequence"))
			{
				SetEntProp(entity, Prop_Data, "m_hasUnlockSequence", 1);
			}
		}
		else
		{
			AcceptEntityInput(entity, "Unlock");
			AcceptEntityInput(entity, "ForceClosed");
			AcceptEntityInput(entity, "Open");
			if (HasEntProp(entity, Prop_Data, "m_hasUnlockSequence"))
			{
				SetEntProp(entity, Prop_Data, "m_hasUnlockSequence", 0);
			}
		}
	}
}

bool IsBuggedMap()
{
	char mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	if (strcmp(mapname, "c10m3_ranchhouse") == 0 || strcmp(mapname, "l4d_smalltown03_ranchhouse") == 0 || strcmp(mapname, "tutorial_standards") == 0 || strcmp(mapname, "l4d_vs_smalltown03_ranchhouse") == 0)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool HasAnyTank()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_isGhost") != 1 && (GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK) && (GetEntProp(client, Prop_Send, "m_isIncapacitated") != 1))
		{
			return true;
		}
		else
		{
			continue;
		}
	}
	return false;
}