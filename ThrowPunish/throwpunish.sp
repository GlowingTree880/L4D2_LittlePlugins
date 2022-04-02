#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define GAMEDATA "throw_punish"
#define PROPANEMODEL "models/props_junk/propanecanister001a.mdl"
#define GASCANMODEL "models/props_junk/gascan001a.mdl"
#define NAVMESH_CHECKPOINT 2048

public Plugin myinfo = 
{
	name 			= "Throw Punish",
	author 			= "夜羽真白",
	description 	= "投掷物使用上限及安全区域扔燃烧瓶惩罚",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hThrowPunishEnable, g_hThrowTimes, g_hThrowType, g_hPunishType, g_hSaferoomFirePunish, g_hPrintTimes;
// Ints
int g_iThrowTimes, g_iThrowType, g_iPunishType, g_iFireTimes[MAXPLAYERS + 1] = {0}, g_iVomitjarTimes[MAXPLAYERS + 1] = {0}, g_iGrenadeTimes[MAXPLAYERS + 1] = {0}, g_iAllTimes[MAXPLAYERS + 1] = {0}, iAllTimes[MAXPLAYERS + 1] = {0},
g_iSpawnAttributeOffset = 0, g_iNavAreaCount = 0;
// Bools
bool g_bThrowPunishEnable, g_bSaferoomFirePunish, g_bPrintTimes,
g_bBlockSound = false, g_bBlockFire = false;
// Addresses
Address g_pNavAddress = Address_Null;

public void OnPluginStart()
{
	// CreateConVars
	g_hThrowPunishEnable = CreateConVar("throw_punish_enable", "1", "是否开启投掷物使用次数上限", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hThrowTimes = CreateConVar("throw_times", "10", "投掷物一关最多只能扔多少次", FCVAR_NOTIFY, true, 1.0);
	g_hThrowType = CreateConVar("throw_type", "1", "哪种投掷物会受到限制：1=火瓶，2=土雷，=3胆汁，4=所有", FCVAR_NOTIFY, true, 1.0, true, 4.0);
	g_hPunishType = CreateConVar("throw_punish_type", "1", "扔超过限制会触发哪种惩罚：1=在扔的人位置刷新 witch，2=删除扔出的投掷物", FCVAR_NOTIFY, true, 1.0, true, 2.0);
	g_hSaferoomFirePunish = CreateConVar("throw_saferoomfire_punish_enable", "1", "扔出去的火如果落在安全区域内是否惩罚使用者", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hPrintTimes = CreateConVar("throw_times_announce", "1", "是否提示本关剩余投掷次数", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// AddChangeHook
	g_hThrowPunishEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hThrowTimes.AddChangeHook(ConVarChanged_Cvars);
	g_hThrowType.AddChangeHook(ConVarChanged_Cvars);
	g_hPunishType.AddChangeHook(ConVarChanged_Cvars);
	g_hSaferoomFirePunish.AddChangeHook(ConVarChanged_Cvars);
	g_hPrintTimes.AddChangeHook(ConVarChanged_Cvars);
	// HookEvents
	HookEvent("round_start", evt_RoundStart);
	HookEvent("round_end", evt_RoundEnd);
	HookEvent("map_transition", evt_MapTransistion);
	// GetCvars
	GetCvars();
	// AddSoundHook
	AddNormalSoundHook(GrenadeSoundHook);
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bThrowPunishEnable = g_hThrowPunishEnable.BoolValue;
	g_bSaferoomFirePunish = g_hSaferoomFirePunish.BoolValue;
	g_iThrowTimes = g_hThrowTimes.IntValue;
	g_iThrowType = g_hThrowType.IntValue;
	g_iPunishType = g_hPunishType.IntValue;
	g_bPrintTimes = g_hPrintTimes.BoolValue;
}

methodmap Address
{
	property int SpawnAttributes
	{
		public get()
		{
			return LoadFromAddress(this + view_as<Address>(g_iSpawnAttributeOffset), NumberType_Int32);
		}
	}
}

// ********************
// 		   事件
// ********************
public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(2.0, Timer_GetNavMesh, _, TIMER_FLAG_NO_MAPCHANGE);
	ResetTimes();
}

public void evt_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetTimes();
}

public void evt_MapTransistion(Event event, const char[] name, bool dontBroadcast)
{
	ResetTimes();
}

public Action Timer_GetNavMesh(Handle timer)
{
	GetMapNavAreaData();
}

void GetMapNavAreaData()
{
	GameData hGameData = new GameData(GAMEDATA);
	if (hGameData != null)
	{
		g_iSpawnAttributeOffset = hGameData.GetOffset("TerrorNavArea::ScriptGetSpawnAttributes");
		if (g_iSpawnAttributeOffset == -1)
		{
			SetFailState("无法加载偏移：TerrorNavArea::ScriptGetSpawnAttributes");
		}
		Address pNavCount = hGameData.GetAddress("TheCount");
		if (pNavCount != Address_Null)
		{
			g_pNavAddress = view_as<Address>(LoadFromAddress(pNavCount + view_as<Address>(4), NumberType_Int32));
			if (g_pNavAddress != Address_Null)
			{
				g_iNavAreaCount = LoadFromAddress(pNavCount, NumberType_Int32);
				if (g_iNavAreaCount <= 0)
				{
					LogError("当前地区 Nav 区域数量为：0，可能是某些测试地图");
				}
				delete hGameData;
			}
			else
			{
				SetFailState("无法加载地址：TheNavAreas");
			}
		}
		else
		{
			SetFailState("无法加载地址：TheCount");
		}
	}
	else
	{
		SetFailState("无法加载 gamedata 文件：%s.txt", GAMEDATA);
	}
}

// ********************
// 		   主要
// ********************
public void OnMapStart()
{
	PrecacheModel(PROPANEMODEL, true);
	PrecacheModel(GASCANMODEL, true);
	PrecacheParticle("gas_explosion_pump");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_bThrowPunishEnable)
	{
		if (strcmp(classname, "molotov_projectile") == 0)
		{
			SDKHook(entity, SDKHook_SpawnPost, SDKHook_Molotov);
			if (g_bSaferoomFirePunish)
			{
				SDKHook(entity, SDKHook_Touch, SDKHook_GrenadeTouch);
			}
		}
		if (strcmp(classname, "vomitjar_projectile") == 0)
		{
			SDKHook(entity, SDKHook_SpawnPost, SDKHook_Vomitjar);
		}
		if (strcmp(classname, "pipe_bomb_projectile") == 0)
		{
			SDKHook(entity, SDKHook_SpawnPost, SDKHook_Pipebomb);
		}
		if (strcmp(classname, "inferno") == 0)
		{
			SDKHook(entity, SDKHook_ThinkPost, SDKHook_MolotovFire);
		}
	}
}

public void SDKHook_Molotov(int entity)
{
	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(client) && IsPlayerAlive(client))
		{
			if (g_iThrowType == 1)
			{
				g_iFireTimes[client] += 1;
				if (g_bPrintTimes && g_iThrowTimes - g_iFireTimes[client] > 0)
				{
					PrintToChat(client, "\x04【提示】：\x05您在本关还可投掷 \x04%d \x05次\x03燃烧瓶", g_iThrowTimes - g_iFireTimes[client]);
				}
				else if (g_bPrintTimes && g_iThrowTimes - g_iFireTimes[client] < 0)
				{
					// 先阻止完声音再删除燃烧瓶实体，否则直接删除实体会导致声音无限循环
					g_bBlockSound = true;
					RequestFrame(Sound_NextFrame);
					int iMolotovReference = EntIndexToEntRef(entity);
					GetPunish(client, iMolotovReference);
					PrintToChat(client, "\x04【提示】：\x05您在本关已无法继续投掷\x03燃烧瓶");
				}
			}
			else if (g_iThrowType == 4)
			{
				iAllTimes[client] += 1;
				int All = g_iFireTimes[client] + g_iGrenadeTimes[client] + g_iVomitjarTimes[client];
				g_iAllTimes[client] = All + iAllTimes[client];
				if (g_bPrintTimes && g_iThrowTimes - g_iAllTimes[client] > 0)
				{
					PrintToChat(client, "\x04【提示】：\x05您在本关还可投掷 \x04%d \x05次\x03投掷物", g_iThrowTimes - g_iAllTimes[client]);
				}
				else if (g_bPrintTimes && g_iThrowTimes - g_iAllTimes[client] < 0)
				{
					g_bBlockSound = true;
					RequestFrame(Sound_NextFrame);
					int iMolotovReference = EntIndexToEntRef(entity);
					GetPunish(client, iMolotovReference);
					PrintToChat(client, "\x04【提示】：\x05您在本关已无法继续投掷\x03任何投掷物");
				}
			}
		}
		SDKUnhook(entity, SDKHook_SpawnPost, SDKHook_Vomitjar);
	}
}

public void SDKHook_MolotovFire(int entity)
{
	// PrintToChatAll("阻止火焰：%b", g_bBlockFire);
	if (IsValidEntity(entity) && IsValidEdict(entity) && g_bBlockFire)
	{
		g_bBlockSound = true;
		RequestFrame(Sound_NextFrame);
		AcceptEntityInput(entity, "kill");
		StopSound(entity, SNDCHAN_AUTO, "weapons/molotov/fire_loop_1.wav");
	}
	g_bBlockFire = false;
}

public void SDKHook_Vomitjar(int entity)
{
	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(client) && IsPlayerAlive(client))
		{
			if (g_iThrowType == 3)
			{
				g_iVomitjarTimes[client] += 1;
				if (g_bPrintTimes && g_iThrowTimes - g_iVomitjarTimes[client] > 0)
				{
					PrintToChat(client, "\x04【提示】：\x05您在本关还可投掷 \x04%d \x05次\x03胆汁", g_iThrowTimes - g_iVomitjarTimes[client]);
				}
				else if (g_bPrintTimes && g_iThrowTimes - g_iVomitjarTimes[client] < 0)
				{
					int iVomitReference = EntIndexToEntRef(entity);
					GetPunish(client, iVomitReference);
					PrintToChat(client, "\x04【提示】：\x05您在本关已无法继续投掷\x03胆汁");
				}
			}
			else if (g_iThrowType == 4)
			{
				iAllTimes[client] += 1;
				int All = g_iFireTimes[client] + g_iGrenadeTimes[client] + g_iVomitjarTimes[client];
				g_iAllTimes[client] = All + iAllTimes[client];
				if (g_bPrintTimes && g_iThrowTimes - g_iAllTimes[client] > 0)
				{
					PrintToChat(client, "\x04【提示】：\x05您在本关还可投掷 \x04%d \x05次\x03投掷物", g_iThrowTimes - g_iAllTimes[client]);
				}
				else if (g_bPrintTimes && g_iThrowTimes - g_iAllTimes[client] < 0)
				{
					int iVomitReference = EntIndexToEntRef(entity);
					GetPunish(client, iVomitReference);
					PrintToChat(client, "\x04【提示】：\x05您在本关已无法继续投掷\x03任何投掷物");
				}
			}
		}
		SDKUnhook(entity, SDKHook_SpawnPost, SDKHook_Vomitjar);
	}
}

public void SDKHook_Pipebomb(int entity)
{
	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(client) && IsPlayerAlive(client))
		{
			// 取玩家投掷物武器槽的物品，需要判断模型，否则打爆煤气罐也算次数
			int iSlots = GetPlayerWeaponSlot(client, 2);
			if (IsValidEntity(iSlots) && IsValidEdict(iSlots))
			{
				char modelname[128];
				GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
				if (strcmp(modelname, "models/w_models/weapons/w_eq_pipebomb.mdl") == 0)
				{
					if (g_iThrowType == 2)
					{
						g_iGrenadeTimes[client] += 1;
						if (g_bPrintTimes && g_iThrowTimes - g_iGrenadeTimes[client] > 0)
						{
							PrintToChat(client, "\x04【提示】：\x05您在本关还可投掷 \x04%d \x05次\x03土制炸药", g_iThrowTimes - g_iGrenadeTimes[client]);
						}
						else if (g_bPrintTimes && g_iThrowTimes - g_iGrenadeTimes[client] < 0)
						{
							int iGrenadeReference = EntIndexToEntRef(entity);
							GetPunish(client, iGrenadeReference);
							PrintToChat(client, "\x04【提示】：\x05您在本关已无法继续投掷\x03土制炸药");
						}
					}
					else if (g_iThrowType == 4)
					{
						iAllTimes[client] += 1;
						int All = g_iFireTimes[client] + g_iGrenadeTimes[client] + g_iVomitjarTimes[client];
						g_iAllTimes[client] = All + iAllTimes[client];
						if (g_bPrintTimes && g_iThrowTimes - g_iAllTimes[client] > 0)
						{
							PrintToChat(client, "\x04【提示】：\x05您在本关还可投掷 \x04%d \x05次\x03投掷物", g_iThrowTimes - g_iAllTimes[client]);
						}
						else if (g_bPrintTimes && g_iThrowTimes - g_iAllTimes[client] < 0)
						{
							int iGrenadeReference = EntIndexToEntRef(entity);
							GetPunish(client, iGrenadeReference);
							PrintToChat(client, "\x04【提示】：\x05您在本关已无法继续投掷\x03任何投掷物");
						}
					}
				}
			}
		}
		SDKUnhook(entity, SDKHook_SpawnPost, SDKHook_Pipebomb);
	}
}

// 判断燃烧瓶是否落在安全屋内
public void SDKHook_GrenadeTouch(int entity)
{
	if (IsValidEntity(entity) && IsValidEdict(entity))
	{
		float fGrenadePos[3] = {0.0};
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", fGrenadePos);
		// PrintToChatAll("落点坐标：%.2f %.2f %.2f", fGrenadePos[0], fGrenadePos[1], fGrenadePos[2]);
		// 判断投掷物是否处在安全区内
		int iPosNavArea = L4D_GetNearestNavArea(fGrenadePos);
		Address pPosNavArea = view_as<Address>(iPosNavArea);
		if (pPosNavArea != Address_Null)
		{
			int iSpawnAttributes = pPosNavArea.SpawnAttributes;
			// PrintToChatAll("落点Nav区域类型：%d", iSpawnAttributes & NAVMESH_CHECKPOINT);
			if (iSpawnAttributes & NAVMESH_CHECKPOINT)
			{
				g_bBlockSound = true;
				g_bBlockFire = true;
				RequestFrame(Sound_NextFrame);
				int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
				if (IsValidClient(client) && IsPlayerAlive(client))
				{
					float fSpeed[3] = {0.0};
					GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", fSpeed);
					if (fSpeed[0] > -1.0 && fSpeed[0] < 1.0 && fSpeed[1] > -1.0 && fSpeed[1] < 1.0 && fSpeed[2] > -1.0 && fSpeed[2] < 1.0)
					{
						SetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", view_as<float>({0.0, 0.0, 0.0}));
						SetEntityMoveType(entity, MOVETYPE_NONE);
						SetEntProp(entity, Prop_Send, "m_nSolidType", 6);
					}
					SetEntPropFloat(entity, Prop_Data, "m_flCreateTime", GetGameTime());
					int iOffset = FindDataMapInfo(entity, "m_flCreateTime");
					ChangeEdictState(entity, iOffset);
					int iSlots = GetPlayerWeaponSlot(client, 2);
					if (iSlots > -1)
					{
						char classname[64];
						GetEdictClassname(iSlots, classname, sizeof(classname));
						if (strcmp(classname, "weapon_molotov") == 0)
						{
							RemovePlayerItem(client, iSlots);
						}
					}
					int iMolotovReference = EntIndexToEntRef(entity);
					GetPunish(client, iMolotovReference);
					PrintToChat(client, "\x04【提示】：\x05对不起，您无法向安全区域内投掷燃烧瓶");
				}
			}
		}
		SDKUnhook(entity, SDKHook_Touch, SDKHook_GrenadeTouch);
	}
}

public void Sound_NextFrame()
{
	g_bBlockSound = false;
}

// 阻止燃烧瓶的声音
public Action GrenadeSoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if (g_bBlockSound)
	{
		if(strcmp(sample, "weapons/molotov/fire_loop_1.wav") == 0)
		{
			volume = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

// ********************
// 		   方法
// ********************
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

void GetPunish(int client, int iEntityReference)
{
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		switch (g_iPunishType)
		{
			// 刷妹子
			case 1:
			{
				// 删除投掷物
				int entity = EntRefToEntIndex(iEntityReference);
				if (IsValidEntity(entity) && IsValidEdict(entity))
				{
					AcceptEntityInput(entity, "kill");
				}
				float fSelfPos[3] = {0.0};
				GetClientAbsOrigin(client, fSelfPos);
				// 锁定投掷者视角垂直向下
				float fEyeAngles[3] = {0.0};
				GetClientEyeAngles(client, fEyeAngles);
				fEyeAngles[0] = 90.0;
				TeleportEntity(client, NULL_VECTOR, fEyeAngles, NULL_VECTOR);
				// 冰冻投掷者并设置渲染颜色
				SetEntityMoveType(client, MOVETYPE_NONE);
				SetEntityRenderMode(client, RENDER_GLOW);
				SetEntityRenderColor(client, 255, 0, 0, 200);
				CreateTimer(5.0, Timer_ResetMove, client, TIMER_FLAG_NO_MAPCHANGE);
				// 特效
				int tempentity = 0;
				tempentity = CreateEntityByName("prop_physics");
				DispatchKeyValue(tempentity, "model", PROPANEMODEL);
				DispatchSpawn(tempentity);
				TeleportEntity(tempentity, fSelfPos, NULL_VECTOR, NULL_VECTOR);
				ActivateEntity(tempentity);
				SetEntityRenderMode(tempentity, RENDER_GLOW);
				SetEntityRenderColor(tempentity, 0, 0, 0, 0);
				AcceptEntityInput(tempentity, "Ignite", -1, -1);
				if (tempentity > 0 && IsValidEntity(tempentity))
				{
					AcceptEntityInput(tempentity, "break", -1);
					RemoveEdict(tempentity);
				}
				ShowParticle(fSelfPos, "gas_explosion_pump", 3.0);
				// 掉落玩家武器
				int iSlots = GetPlayerWeaponSlot(client, 0);
				if (IsValidEntity(iSlots) && IsValidEdict(iSlots))
				{
					int iAmmo = GetPlayerReserveAmmo(client, iSlots);
					SDKHooks_DropWeapon(client, iSlots);
					float fSelfAngles[3] = {0.0};
					GetClientEyeAngles(client, fSelfAngles);
					GetAngleVectors(fSelfAngles, fSelfAngles, NULL_VECTOR, NULL_VECTOR);
					NormalizeVector(fSelfAngles, fSelfAngles);
					fSelfAngles[0] += 300.0;
					TeleportEntity(iSlots, NULL_VECTOR, NULL_VECTOR, fSelfAngles);
					SetPlayerReserveAmmo(client, iSlots, 0);
					SetEntProp(iSlots, Prop_Send, "m_iExtraPrimaryAmmo", iAmmo);
				}
				// 刷妹子
				L4D2_SpawnWitch(fSelfPos, view_as<float>({0.0, 0.0, 0.0}));
			}
			// 删除投掷物
			case 2:
			{
				int entity = EntRefToEntIndex(iEntityReference);
				if (IsValidEntity(entity) && IsValidEdict(entity))
				{
					AcceptEntityInput(entity, "kill");
					PrintToChat(client, "\x04【提示】：\x05已销毁投掷物");
				}
			}
		}
	}
}

void ResetTimes()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		g_iFireTimes[client] = 0;
		g_iGrenadeTimes[client] = 0;
		g_iVomitjarTimes[client] = 0;
		g_iAllTimes[client] = 0;
		iAllTimes[client] = 0;
	}
}

void ShowParticle(float pos[3], char[] particlename, float time)
{
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, Timer_DeleteParticles, particle);
	}
}

public Action Timer_DeleteParticles(Handle timer, int particle)
{
	if (IsValidEntity(particle))
	{
		char classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (strcmp(classname, "info_particle_system") == 0)
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "kill");
			RemoveEdict(particle);
		}
	}
}

public void PrecacheParticle(char[] particlename)
{
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, Timer_DeleteParticles, particle);
	}
}

public Action Timer_ResetMove(Handle timer, int client)
{
	if (IsValidClient(client))
	{
		SetEntityMoveType(client, MOVETYPE_CUSTOM);
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

int GetPlayerReserveAmmo(int client, int weapon)
{
	int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (ammotype >= 0)
	{
		return GetEntProp(client, Prop_Send, "m_iAmmo", _, ammotype);
	}
	return 0;
}

void SetPlayerReserveAmmo(int client, int weapon, int ammo)
{
	int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (ammotype >= 0 )
	{
		SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammotype);
		ChangeEdictState(client, FindDataMapInfo(client, "m_iAmmo"));
	}
}