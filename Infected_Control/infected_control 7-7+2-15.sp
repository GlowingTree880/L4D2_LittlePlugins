#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define CVAR_FLAG FCVAR_NOTIFY
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
// 特感种类
#define ZC_SPITTER 4
#define ZC_TANK 8
// 数据
#define NAV_MESH_HEIGHT 20.0
#define PLAYER_HEIGHT 72.0
#define PLAYER_CHEST 45.0

// 插件基本信息，根据 GPL 许可证条款，需要修改插件请勿修改此信息！
public Plugin myinfo = 
{
	name 			= "Direct InfectedSpawn",
	author 			= "Caibiii, 夜羽真白",
	description 	= "特感刷新控制，传送落后特感",
	version 		= "2022.03.20",
	url 			= "https://github.com/GlowingTree880/L4D2_LittlePlugins"
}

// Cvars
ConVar g_hSpawnDistanceMin, g_hSpawnDistanceMax, g_hTeleportSi, g_hTeleportDistance, g_hSiLimit, g_hSiInterval, g_hMaxPlayerZombies, g_hSbEscort, g_hSpawnMax, g_hEnableWaveSpawn, g_hWaveSpawnFrame, g_hSpawnMode;
// Ints
int g_iSiLimit, g_iSbEscort, iUnRechedLimitCount = 0, g_iWaveSpawnFrame, g_iSpawnMode,
g_iTeleCount[MAXPLAYERS + 1] = {0}, g_iTargetSurvivor = -1, g_iSpawnMaxCount = 0, g_iSurvivorNum = 0, g_iSurvivors[MAXPLAYERS + 1] = {0};
// ArraySpecial[6] = {0};
// Floats
float g_fSpawnDistanceMin, g_fSpawnDistanceMax, g_fTeleportDistance, g_fSiInterval;
// Bools
bool g_bTeleportSi, g_bEnableWaveSpawn
, g_bIsLate = false;
// Handle
Handle g_hTeleHandle = INVALID_HANDLE;
// ArrayList
ArrayList aThreadHandle;

/* static char InfectedName[7][] =
{
	"none",
	"smoker",
	"boomer",
	"hunter",
	"spitter",
	"jockey",
	"charger"
}; */

public void OnPluginStart()
{
	// CreateConVar
	g_hSpawnDistanceMin = CreateConVar("inf_SpawnDistanceMin", "0.0", "特感复活离生还者最近的距离限制", CVAR_FLAG, true, 0.0);
	g_hSpawnDistanceMax = CreateConVar("inf_SpawnDistanceMax", "500.0", "特感复活离生还者最远的距离限制", CVAR_FLAG, true, g_hSpawnDistanceMin.FloatValue);
	g_hTeleportSi = CreateConVar("inf_TeleportSi", "1", "是否开启特感距离生还者一定距离将其传送至生还者周围", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hTeleportDistance = CreateConVar("inf_TeleportDistance", "800.0", "特感落后于最近的生还者超过这个距离则将它们传送", CVAR_FLAG, true, 0.0);
	g_hSiLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0);
	g_hSiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "对抗模式下刷特时间控制", CVAR_FLAG, true, 0.0);
	g_hEnableWaveSpawn = CreateConVar("inf_EnableWaveSpawn", "0", "是否开启限制特感刷新必须在 x 帧内完成", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hWaveSpawnFrame = CreateConVar("inf_WaveSpawnFrame", "20", "一波的刷特必须要在这么多帧内完成找位与刷新", CVAR_FLAG, true, 0.0);
	g_hSpawnMode = CreateConVar("inf_SpawnMode", "1", "刷特方式选择：1=阳间，2=阴间，3=随机阳间阴间", CVAR_FLAG, true, 1.0, true, 3.0);
	g_hSbEscort = CreateConVar("sb_escort", "1", "保持 Aibot 紧跟在生还者身边", ~ CVAR_FLAG, true, 0.0, true, 1.0);
	g_hSpawnMax = CreateConVar("spawn_count_max", "0", "此值记录特感找位次数，根据此值动态改变刷新距离", ~ CVAR_FLAG, true, 0.0);
	g_hMaxPlayerZombies = FindConVar("z_max_player_zombies");
	SetConVarInt(FindConVar("director_no_specials"), 1);
	// HookEvents
	HookEvent("player_death", evt_PlayerDeath, EventHookMode_PostNoCopy);
	HookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_win", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", evt_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", evt_RoundEnd, EventHookMode_PostNoCopy);
	// AddChangeHook
	g_hSpawnDistanceMax.AddChangeHook(ConVarChanged_Cvars);
	g_hSpawnDistanceMin.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleportSi.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleportDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hSiInterval.AddChangeHook(ConVarChanged_Cvars);
	g_hSbEscort.AddChangeHook(ConVarChanged_Cvars);
	g_hEnableWaveSpawn.AddChangeHook(ConVarChanged_Cvars);
	g_hWaveSpawnFrame.AddChangeHook(ConVarChanged_Cvars);
	g_hSpawnMode.AddChangeHook(ConVarChanged_Cvars);
	g_hSiLimit.AddChangeHook(MaxPlayerZombiesChanged_Cvars);
	// ArrayList
	aThreadHandle = new ArrayList();
	// GetCvars
	GetCvars();
	// SetConVarBonus
	SetConVarBounds(g_hMaxPlayerZombies, ConVarBound_Upper, true, g_hSiLimit.FloatValue);
	// Debug
	RegAdminCmd("sm_startspawn", Cmd_StartSpawn, ADMFLAG_ROOT, "管理员重置刷特时钟");
}

// 向量绘制
// #include "vector/vector_show.sp"

public Action Cmd_StartSpawn(int client, int args)
{
	if (L4D_HasAnySurvivorLeftSafeArea())
	{
		CreateTimer(0.1, SpawnFirstInfected);
	}
	return Plugin_Continue;
}

// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void MaxPlayerZombiesChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iSiLimit = g_hSiLimit.IntValue;
	CreateTimer(0.1, MaxSpecialsSet);
}

void GetCvars()
{
	g_fSpawnDistanceMax = g_hSpawnDistanceMax.FloatValue;
	g_fSpawnDistanceMin = g_hSpawnDistanceMin.FloatValue;
	g_bTeleportSi = g_hTeleportSi.BoolValue;
	g_fTeleportDistance = g_hTeleportDistance.FloatValue;
	g_fSiInterval = g_hSiInterval.FloatValue;
	g_iSiLimit = g_hSiLimit.IntValue;
	g_iSbEscort = g_hSbEscort.IntValue;
	g_bEnableWaveSpawn = g_hEnableWaveSpawn.BoolValue;
	g_iWaveSpawnFrame = g_hWaveSpawnFrame.IntValue;
	g_iSpawnMode = g_hSpawnMode.IntValue;
}

public Action MaxSpecialsSet(Handle timer)
{
	SetConVarBounds(g_hMaxPlayerZombies, ConVarBound_Upper, true, g_hSiLimit.FloatValue);
	g_hMaxPlayerZombies.IntValue = g_iSiLimit;
	return Plugin_Continue;
}

// *********************
//		    事件
// *********************
public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hTeleHandle != INVALID_HANDLE)
	{
		delete g_hTeleHandle;
		g_hTeleHandle = INVALID_HANDLE;
	}
	g_bIsLate = false;
	g_iSpawnMaxCount = 0;
	for (int hTimerHandle = aThreadHandle.Length - 1; hTimerHandle >= 0; hTimerHandle--)
	{
		KillTimer(aThreadHandle.Get(hTimerHandle));
		aThreadHandle.Erase(hTimerHandle);
	}
	aThreadHandle.Clear();
	CreateTimer(0.1, MaxSpecialsSet);
	CreateTimer(3.0, SafeRoomReset, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void evt_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hTeleHandle != INVALID_HANDLE)
	{
		delete g_hTeleHandle;
		g_hTeleHandle = INVALID_HANDLE;
	}
	g_bIsLate = false;
	g_iSpawnMaxCount = 0;
	// 从 ArrayList 末端往前判断删除时钟，如果从前往后，因为 ArrayList 会通过前移后面的索引来填补前面擦除的空位，导致有时钟句柄无法擦除
	for (int hTimerHandle = aThreadHandle.Length - 1; hTimerHandle >= 0; hTimerHandle--)
	{
		KillTimer(aThreadHandle.Get(hTimerHandle));
		aThreadHandle.Erase(hTimerHandle);
	}
	aThreadHandle.Clear();
}

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInfectedBot(client))
	{
		if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_SPITTER)
		{
			CreateTimer(0.5, Timer_KickBot, client);
		}
	}
	g_iTeleCount[client] = 0;
}

public Action Timer_KickBot(Handle timer, int client)
{
	if (IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
	{
		KickClient(client, "You are worthless and was kicked by console");
	}
	return Plugin_Continue;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	// bot 跟随设定，默认为 0，需要设成 1
	if (g_hSbEscort.IntValue == 0)
	{
		g_hSbEscort.IntValue = 1;
	}
	return Plugin_Continue;
}

// *********************
//		  功能部分
// *********************
public void OnGameFrame()
{
	// 根据情况动态调整 z_maxplayers_zombie 数值
	if (g_iSiLimit > g_hMaxPlayerZombies.IntValue)
	{
		CreateTimer(0.1, MaxSpecialsSet);
	}
	if (g_bIsLate && g_iSbEscort > 0 && g_iSpawnMaxCount > 0)
	{
		if (g_iSiLimit > HasAnyCountFull())
		{
			if (g_bEnableWaveSpawn)
			{
				// 使用一个计数变量，如果可以刷特，且小于 200 帧特感未活全
				iUnRechedLimitCount++;
				if (iUnRechedLimitCount > g_iWaveSpawnFrame)
				{
					int iInfectedCount = 0;
					// 帧操作，获取在场特感数量
					for (int infected = 1; infected <= MaxClients; infected++)
					{
						if (IsInfectedBot(infected) && IsPlayerAlive(infected) && GetEntProp(infected, Prop_Send, "m_zombieClass") != ZC_TANK)
						{
							iInfectedCount++;
							if (iInfectedCount > 0)
							{
								float fPos[3];
								GetClientAbsOrigin(infected, fPos);
								// 如果在场特感数量小于设置数量
								for (int count = iInfectedCount; count <= g_iSiLimit; count++)
								{
									int iZombieClass = IsBotTypeNeeded();
									if (iZombieClass > 0)
									{
										// 先判断刷特上限是否大于 0 再刷出特感，否则先刷出特感再减少刷特上限，会多刷一个特感
										if (g_iSpawnMaxCount > 0)
										{
											int entityindex = L4D2_SpawnSpecial(iZombieClass, fPos, view_as<float>({0.0, 0.0, 0.0}));
											if (IsValidEntity(entityindex) && IsValidEdict(entityindex))
											{
												g_iSpawnMaxCount -= 1;
											}
										}
									}
								}
								iUnRechedLimitCount = 0;
							}
						}
					}
					// 检测完特感团队，如无在场特感，则继续检测能否刷新
				}
			}
			// 选择刷特方式，阳间阴间
			switch (g_iSpawnMode)
			{
				case 1:
				{
					EasyMode();
				}
				case 2:
				{
					HardMode();
				}
				case 3:
				{
					int anne = GetRandomInt(1, 2);
					switch (anne)
					{
						case 1:
						{
							EasyMode();
						}
						case 2:
						{
							HardMode();
						}
					}
				}
			}
		}
	}
}

// 刷阳特：7-7
void EasyMode()
{
	float fSpawnDistanceMax = g_fSpawnDistanceMax;
	g_hSpawnMax.IntValue = g_hSpawnMax.IntValue + 1;
	if (0 <= g_hSpawnMax.IntValue <= 75)
	{
		fSpawnDistanceMax = fSpawnDistanceMax + 500.0;
	}
	else if (75 < g_hSpawnMax.IntValue <= 150)
	{
		fSpawnDistanceMax = fSpawnDistanceMax +750.0;
	}
	else if (150 < g_hSpawnMax.IntValue <= 250)
	{
		fSpawnDistanceMax = fSpawnDistanceMax + 1250.0;
	}
	else
	{
		fSpawnDistanceMax = fSpawnDistanceMax + 2500.0;
	}
	float fSpawnPos[3] = {0.0}, fSurvivorPos[3] = {0.0}, fDistance = 0.0;
	int iZombieClass = IsBotTypeNeeded();
	if (IsValidSurvivor(g_iTargetSurvivor) && iZombieClass > 0)
	{
		L4D_GetRandomPZSpawnPosition(g_iTargetSurvivor, iZombieClass, 1, fSpawnPos);
		if (!IsPlayerVisibleTo(fSpawnPos))
		{
			GetClientAbsOrigin(g_iTargetSurvivor, fSurvivorPos);
			// 当生还者不在有效的 Nav Area 时，也允许刷特感，只需计算距离
			if (!IsOnValidMesh(fSurvivorPos))
			{
				if (200 < GetSurvivorDistance(fSpawnPos) < RoundToNearest(fSpawnDistanceMax))
				{
					int entityindex = L4D2_SpawnSpecial(iZombieClass, fSpawnPos, view_as<float>({0.0, 0.0, 0.0}));
					if (IsValidEntity(entityindex) && IsValidEdict(entityindex))
					{
						if (g_iSpawnMaxCount > 0)
						{
							g_iSpawnMaxCount -= 1;
						}
						if (g_hSpawnMax.IntValue < 100)
						{
							g_hSpawnMax.IntValue = 0;
						}
					}
				}
			}
			// 当生还者在有效 Nav Area 时，则需计算两块 Nav Area 之间的可达距离
			fDistance = L4D2_NavAreaTravelDistance(fSpawnPos, fSurvivorPos, false);
			if (250.0 < fDistance < fSpawnDistanceMax + 500.0)
			{
				int entityindex = L4D2_SpawnSpecial(iZombieClass, fSpawnPos, view_as<float>({0.0, 0.0, 0.0}));
				if (IsValidEntity(entityindex) && IsValidEdict(entityindex))
				{
					if (g_iSpawnMaxCount > 0)
					{
						g_iSpawnMaxCount -= 1;
					}
					if (g_hSpawnMax.IntValue < 100)
					{
						g_hSpawnMax.IntValue = 0;
					}
				}
			}
		}
	}
}

// 刷阴特：2-15
void HardMode()
{
	// 游戏帧内使用这个 Cvar 记录特感找位次数，如果指定次数下没找到位，则扩大刷特范围
	g_hSpawnMax.IntValue = (g_hSpawnMax, g_hSpawnMax.IntValue + 1);
	switch (g_hSpawnMax.IntValue)
	{
		case 50:
		{
			g_fSpawnDistanceMax = 650.0;
		}
		case 100:
		{
			g_fSpawnDistanceMax = 800.0;
		}
		case 150:
		{
			g_fSpawnDistanceMax = 950.0;
		}
		case 200:
		{
			g_fSpawnDistanceMax = 1100.0;
		}
		case 250:
		{
			g_fSpawnDistanceMax = 1500.0;
		}
	}
	float fSpawnPos[3] = {0.0}, fSurvivorPos[3] = {0.0}, fDirection[3] = {0.0}, fEndPos[3] = {0.0}, fMins[3] = {0.0}, fMaxs[3] = {0.0};
	// float fVisiblePos[3] = {0.0};
	if (IsValidSurvivor(g_iTargetSurvivor))
	{
		// 根据指定生还者坐标，拓展刷新范围
		GetClientEyePosition(g_iTargetSurvivor, fSurvivorPos);
		fMins[0] = fSurvivorPos[0] - g_fSpawnDistanceMax;
		fMaxs[0] = fSurvivorPos[0] + g_fSpawnDistanceMax;
		fMins[1] = fSurvivorPos[1] - g_fSpawnDistanceMax;
		fMaxs[1] = fSurvivorPos[1] + g_fSpawnDistanceMax;
		fMaxs[2] = fSurvivorPos[2] + g_fSpawnDistanceMax;
		// 规定射线方向
		fDirection[0] = 90.0;
		fDirection[1] = fDirection[2] = 0.0;
		// 随机刷新位置
		fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
		fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
		fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
		// 找位条件，可视，是否在有效 NavMesh，是否卡住，否则先会判断是否在有效 Mesh 与是否卡住导致某些位置刷不出特感
		while (IsPlayerVisibleTo(fSpawnPos) || !IsOnValidMesh(fSpawnPos) || IsPlayerStuck(fSpawnPos))
		{
			fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
			fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
			fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
			if (!IsOnValidMesh(fSpawnPos))
			{
				TR_TraceRay(fSpawnPos, fDirection, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
				if (TR_DidHit())
				{
					TR_GetEndPosition(fEndPos);
					fSpawnPos = fEndPos;
					fSpawnPos[2] += NAV_MESH_HEIGHT;
					// 如果不想刷新的那么阴间，比如 c5m2 台球桌后复活，可以增加 fVisiblePos，使用特感眼睛位置检测是否可见，否则只会使用离地面 + 20 高度的地方检测可见性
					// fVisiblePos = fEndPos;
					// fVisiblePos[2] += PLAYER_HEIGHT;
					break;
				}
			}
		}
		if (!IsPlayerVisibleTo(fSpawnPos) && IsOnValidMesh(fSpawnPos) && !IsPlayerStuck(fSpawnPos))
		{
			// 生还数量为 4，循环 4 次，检测此位置到生还的距离是否小于 750 是则刷特，此处可以刷新 1 ~ g_iSiLimit 只特感，如果此处刷完，则上面的 SpawnSpecial 将不再刷特
			for (int count = 0; count < g_iSurvivorNum; count++)
			{
				int index = g_iSurvivors[count];
				GetClientEyePosition(index, fSurvivorPos);
				fSurvivorPos[2] -= 60.0;
				if (L4D2_VScriptWrapper_NavAreaBuildPath(fSpawnPos, fSurvivorPos, g_fSpawnDistanceMax + 250.0, false, false, TEAM_INFECTED, false) && GetVectorDistance(fSurvivorPos, fSpawnPos) > g_fSpawnDistanceMin)
				{
					int iZombieClass = IsBotTypeNeeded();
					if (iZombieClass > 0)
					{
						int entityindex = L4D2_SpawnSpecial(iZombieClass, fSpawnPos, view_as<float>({0.0, 0.0, 0.0}));
						if (IsValidEntity(entityindex) && IsValidEdict(entityindex))
						{
							if (g_iSpawnMaxCount > 0)
							{
								g_iSpawnMaxCount -= 1;
							}
							if (g_hSpawnMax.IntValue < 100)
							{
								g_hSpawnMax.IntValue = 0;
							}
						}
					}
				}
			}
		}
	}
}

// 禁推口水
public Action L4D_OnShovedBySurvivor(int client, int victim, const float vecDir[3])
{
	if (IsSpitter(victim))
	{
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action L4D2_OnEntityShoved(int client, int entity, int weapon, float vecDir[3], bool bIsHighPounce)
{
	if (IsSpitter(entity))
	{
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

// 初始 & 动态刷特时钟
public Action SpawnFirstInfected(Handle timer)
{
	if (!g_bIsLate)
	{
		g_bIsLate = true;
		if (g_hSiInterval.FloatValue > 9.0)
		{
			Handle aSpawnTimer = CreateTimer(g_fSiInterval + 8.0, SpawnNewInfected, _, TIMER_REPEAT);
			aThreadHandle.Push(aSpawnTimer);
			TriggerTimer(aSpawnTimer, true);
		}
		else
		{
			Handle aSpawnTimer = CreateTimer(g_fSiInterval + 4.0, SpawnNewInfected, _, TIMER_REPEAT);
			aThreadHandle.Push(aSpawnTimer);
			TriggerTimer(aSpawnTimer, true);
		}
		if (g_bTeleportSi)
		{
			g_hTeleHandle = CreateTimer(1.0, Timer_PositionSi, _, TIMER_REPEAT);
		}
	}
	return Plugin_Continue;
}


public Action SpawnNewInfected(Handle timer)
{
	g_iSurvivorNum = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			g_iSurvivors[g_iSurvivorNum] = client;
			g_iSurvivorNum += 1;
		}
	}
	if (g_bIsLate)
	{
		if (g_iSiLimit > aThreadHandle.Length)
		{
			if (g_hSiInterval.FloatValue > 9.0)
			{
				Handle aSpawnTimer = CreateTimer(g_fSiInterval + 8.0, SpawnNewInfected, _, TIMER_REPEAT);
				aThreadHandle.Push(aSpawnTimer);
				TriggerTimer(aSpawnTimer, true);
			}
			else
			{
				Handle aSpawnTimer = CreateTimer(g_fSiInterval + 4.0, SpawnNewInfected, _, TIMER_REPEAT);
				aThreadHandle.Push(aSpawnTimer);
				TriggerTimer(aSpawnTimer, true);
			}
		}
		// 其实这个删除没什么用，因为当 aThreadHandle.Length = g_iSiLimit 时，多出来的句柄将不会存入数组
		else if (g_iSiLimit < aThreadHandle.Length)
		{
			for (int iTimerIndex = 0; iTimerIndex < aThreadHandle.Length; iTimerIndex++)
			{
				if (timer == aThreadHandle.Get(iTimerIndex))
				{
					aThreadHandle.Erase(iTimerIndex);
					return Plugin_Stop;
				}
			}
		}
		g_hSpawnMax.IntValue = 0;
		g_hSpawnDistanceMax.FloatValue = 500.0;
		g_iSpawnMaxCount += 1;
		// 当一定时间内刷不出特感，触发时钟使 g_iSpawnMaxCount 超过 g_iSiLimit 值时，最多允许刷出 g_iSiLimit + 2 只特感，防止连续刷 2-3 波的情况
		if (g_iSiLimit < g_iSpawnMaxCount)
		{
			int iNewInfectedLimit = g_iSiLimit + 2;
			if (g_iSpawnMaxCount > iNewInfectedLimit)
			{
				g_iSpawnMaxCount = iNewInfectedLimit;
			}
			g_hSbEscort.IntValue =  1;
		}
	}
	return Plugin_Continue;
}

// 开局重置特感状态
public Action SafeRoomReset(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client))
		{
			g_iTeleCount[client] = 0;
		}
		if (IsInfectedBot(client) && !IsPlayerAlive(client))
		{
			L4D_RespawnPlayer(client);
		}
	}
	return Plugin_Continue;
}

// *********************
//		   方法
// *********************
bool IsInfectedBot(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsValidSurvivor(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsOnValidMesh(float fReferencePos[3])
{
	Address pNavArea = L4D2Direct_GetTerrorNavArea(fReferencePos);
	if (pNavArea != Address_Null)
	{
		return true;
	}
	else
	{
		return false;
	}
}	

bool IsPlayerVisibleTo(float fSpawnPos[3])
{
	bool bIsVisibleTo = false;
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client))
		{
			float fEyePos[3];
			GetClientEyePosition(client, fEyePos);
			Handle hTrace = TR_TraceRayFilterEx(fSpawnPos, fEyePos, MASK_VISIBLE_AND_NPCS, RayType_EndPoint, TraceFilter, client);
			if (!TR_DidHit(hTrace))
			{
				bIsVisibleTo = true;
				delete hTrace;
				break;
			}
			delete hTrace;
		}
	}
	return bIsVisibleTo;
}

bool IsPlayerStuck(float fSpawnPos[3])
{
	bool IsStuck = true;
	float fMins[3] = {0.0}, fMaxs[3] = {0.0}, fNewPos[3] = {0.0};
	fNewPos = fSpawnPos;
	fNewPos[2] += 35.0;
	fMins[0] = fMins[1] = -16.0;
	fMins[2] = 0.0;
	fMaxs[0] = fMaxs[1] = 16.0;
	fMaxs[2] = 35.0;
	TR_TraceHullFilter(fSpawnPos, fNewPos, fMins, fMaxs, MASK_NPCSOLID_BRUSHONLY, TraceFilter, _);
	IsStuck = TR_DidHit();
	return IsStuck;
}

bool TraceFilter(int entity, int contentsMask)
{
	if (entity || entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	else
	{
		static char sClassName[9];
		GetEntityClassname(entity, sClassName, sizeof(sClassName));
		if (strcmp(sClassName, "infected") == 0 || strcmp(sClassName, "witch") == 0 || strcmp(sClassName, "prop_physics") == 0)
		{
			return false;
		}
	}
	return true;
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

bool IsPinningSomeone(int client)
{
	bool bIsPinning = false;
	if (IsInfectedBot(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0) bIsPinning = true;
		if (GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0) bIsPinning = true;
	}
	return bIsPinning;
}

bool CanBeTeleport(int client)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_TANK)
	{
		return true;
	}
	else
	{
		return false;
	}
}

public Action Timer_PositionSi(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (CanBeTeleport(client))
		{
			if (g_iTeleCount[client] > 6)
			{
				float fSelfPos[3] = {0.0};
				GetClientEyePosition(client, fSelfPos);
				if (!IsPlayerVisibleTo(fSelfPos) && !IsPinningSomeone(client))
				{
					SDKHook(client, SDKHook_PostThinkPost, SDK_UpdateThink);
					g_iTeleCount[client] = 0;
				}
			}
			g_iTeleCount[client] += 1;
		}
	}
	return Plugin_Continue;
}

bool IsSpitter(int client)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_SPITTER)
	{
		return true;
	}
	else
	{
		return false;
	}
}

// 不知道有什么作用，配合 HasAnyCountFull 不能做到限制每种特感的数量，ArraySpecial 中的值始终是0
/* stock bool IsSpecialInArray(int aArray[6], int iZombieClass)
{
	for (int i = 0; i < 6; i++)
	{
		if (aArray[i] == iZombieClass)
		{
			return true;
		}
	}
	return false;
} */

int HasAnyCountFull()
{
	int iInfectedCount = 0, iSurvivors[4] = {0}, iSurvivorIndex = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client))
		{
			int iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
			if (iZombieClass <= 6)
			{
				iInfectedCount += 1;
			}
		}
		if (IsValidSurvivor(client) && IsPlayerAlive(client) && !IsPinned(client))
		{
			g_bIsLate = true;
			if (iSurvivorIndex < 4)
			{
				iSurvivors[iSurvivorIndex] = client;
				iSurvivorIndex += 1;
			}
		}
	}
	if (iSurvivorIndex > 0)
	{
		g_iTargetSurvivor = iSurvivors[GetRandomInt(0, iSurvivorIndex - 1)];
	}
	else
	{
		g_iTargetSurvivor = L4D_GetHighestFlowSurvivor();
	}
	return iInfectedCount;
}

// 获取生还距离
int GetSurvivorDistance(const float refpos[3], int SpecificSur = -1)
{
	int TargetSur;
	float TargetSurPos[3], RefSurPos[3];
	RefSurPos[0] = refpos[0];	RefSurPos[1] = refpos[1];	RefSurPos[2] = refpos[2];
	if (SpecificSur > 0 && IsValidSurvivor(SpecificSur))
	{
		TargetSur = SpecificSur;
	}
	else
	{
		TargetSur = GetClosestSurvivor(RefSurPos);
	}
	GetEntPropVector(TargetSur, Prop_Send, "m_vecOrigin", TargetSurPos);
	return RoundToNearest(GetVectorDistance(RefSurPos, TargetSurPos));
}

// 有目的性选择最近生还
int GetClosestSurvivor(float refpos[3], int excludeSur = -1)
{
	float surPos[3];	int closetSur = GetRandomSurvivor();
	if (closetSur == 0)
	{
		return 0;
	}
	GetClientAbsOrigin(closetSur, surPos);
	int iClosetAbsDisplacement = RoundToNearest(GetVectorDistance(refpos, surPos));
	for (int client = 1; client < MaxClients; client++)
	{
		if (IsValidSurvivor(client) && IsPlayerAlive(client) && client != excludeSur)
		{
			GetClientAbsOrigin(client, surPos);
			int iAbsDisplacement = RoundToNearest(GetVectorDistance(refpos, surPos));
			if (iClosetAbsDisplacement < 0)
			{
				iClosetAbsDisplacement = iAbsDisplacement;
				closetSur = client;
			}
			else if (iAbsDisplacement < iClosetAbsDisplacement)
			{
				iClosetAbsDisplacement = iAbsDisplacement;
				closetSur = client;
			}
		}
	}
	return closetSur;
}

// 返回在场特感数量，当强控特感种类等于 z_%s_limit 时，清空这种特感在 ArraySpecial 中的储存
/* int HasAnyCountFull()
{
	int iZombieClass1 = 0, iZombieClass3 = 0, iZombieClass5 = 0, iZombieClass6 = 0, iCount = 0, iSurvivors[4] = {0}, iSurvivorIndex = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client))
		{
			int iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
			if (iZombieClass <= 6)
			{
				iCount += 1;
			}
			switch (iZombieClass)
			{
				case 1:
				{
					iZombieClass1 += 1;
					char sCvar[16];
					Format(sCvar, sizeof(sCvar), "z_%s_limit", InfectedName[iZombieClass1]);
					if (GetConVarInt(FindConVar(sCvar)) <= iZombieClass1)
					{
						ArraySpecial[0] = 0;
					}
				}
				case 2:
				{
					ArraySpecial[1] = 0;
				}
				case 3:
				{
					iZombieClass3 += 1;
					char sCvar[16];
					Format(sCvar, sizeof(sCvar), "z_%s_limit", InfectedName[iZombieClass3]);
					if (GetConVarInt(FindConVar(sCvar)) <= iZombieClass3)
					{
						ArraySpecial[2] = 0;
					}
				}
				case 4:
				{
					ArraySpecial[3] = 0;
				}
				case 5:
				{
					iZombieClass5 += 1;
					char sCvar[16];
					Format(sCvar, sizeof(sCvar), "z_%s_limit", InfectedName[iZombieClass5]);
					if (GetConVarInt(FindConVar(sCvar)) <= iZombieClass5)
					{
						ArraySpecial[4] = 0;
					}
				}
				case 6:
				{
					iZombieClass6 += 1;
					char sCvar[16];
					Format(sCvar, sizeof(sCvar), "z_%s_limit", InfectedName[iZombieClass6]);
					if (GetConVarInt(FindConVar(sCvar)) <= iZombieClass6)
					{
						ArraySpecial[5] = 0;
					}
				}
			}
		}
		if (IsValidSurvivor(client) && IsPlayerAlive(client) && !IsPinned(client))
		{
			g_bIsLate = true;
			if (iSurvivorIndex < 4)
			{
				iSurvivors[iSurvivorIndex] = client;
				iSurvivorIndex += 1;
			}
		}
	}
	if (iSurvivorIndex < 0)
	{
		g_iTargetSurvivor = iSurvivors[GetRandomInt(0, iSurvivorIndex - 1)];
	}
	else
	{
		g_iTargetSurvivor = L4D_GetHighestFlowSurvivor();
	}
	return iCount;
} */

// 传送落后特感
public void SDK_UpdateThink(int client)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client))
	{
		g_iTeleCount[client] = 0;
		static float fEyePos[3] = {0.0}, fSelfEyePos[3] = {0.0};
		GetClientEyePosition(client, fEyePos);
		if (!IsPlayerVisibleTo(fEyePos) && !IsPinningSomeone(client))
		{
			float fSpawnPos[3] = {0.0}, fSurvivorPos[3] = {0.0}, fDirection[3] = {0.0}, fEndPos[3] = {0.0}, fMins[3] = {0.0}, fMaxs[3] = {0.0};
			if (IsValidSurvivor(g_iTargetSurvivor))
			{
				GetClientEyePosition(g_iTargetSurvivor, fSurvivorPos);
				GetClientEyePosition(client, fSelfEyePos);
				fMins[0] = fSurvivorPos[0] - g_fSpawnDistanceMax;
				fMaxs[0] = fSurvivorPos[0] + g_fSpawnDistanceMax;
				fMins[1] = fSurvivorPos[1] - g_fSpawnDistanceMax;
				fMaxs[1] = fSurvivorPos[1] + g_fSpawnDistanceMax;
				fMaxs[2] = fSurvivorPos[2] + g_fSpawnDistanceMax;
				fDirection[0] = 90.0;
				fDirection[1] = fDirection[2] = 0.0;
				fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
				fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
				fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
				while (IsPlayerVisibleTo(fSpawnPos) || !IsOnValidMesh(fSpawnPos) || IsPlayerStuck(fSpawnPos))
				{
					fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
					fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
					fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
					TR_TraceRay(fSpawnPos, fDirection, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
					if (TR_DidHit())
					{
						TR_GetEndPosition(fEndPos);
						fSpawnPos = fEndPos;
						fSpawnPos[2] += NAV_MESH_HEIGHT;
						break;
					}
				}
				if (IsOnValidMesh(fSpawnPos) && !IsPlayerStuck(fSpawnPos) && !IsPlayerVisibleTo(fSpawnPos))
				{
					for (int count = 0; count < g_iSurvivorNum; count++)
					{
						int index = g_iSurvivors[count];
						if (IsClientInGame(index))
						{
							GetClientEyePosition(index, fSurvivorPos);
							fSurvivorPos[2] -= 60.0;
							if (L4D2_VScriptWrapper_NavAreaBuildPath(fSpawnPos, fSurvivorPos, g_fTeleportDistance, false, false, TEAM_INFECTED, false) && GetVectorDistance(fSelfEyePos, fSpawnPos) > g_fTeleportDistance && GetVectorDistance(fSelfEyePos, fSpawnPos) > g_fSpawnDistanceMin)
							{
								TeleportEntity(client, fSpawnPos, NULL_VECTOR, NULL_VECTOR);
								SDKUnhook(client, SDKHook_PostThinkPost, SDK_UpdateThink);
							}
						}
					}
				}
			}
		}
	}
}

// 返回在场特感数量，根据 z_%s_limit 限制每种特感上限
int IsBotTypeNeeded()
{
	int iBoomers = 0, iSmokers = 0, iHunters = 0, iSpitters = 0, iJockeys = 0, iChargers = 0;
	for (int infected = 0; infected < MaxClients; infected++)
	{
		if (IsInfectedBot(infected) && IsPlayerAlive(infected))
		{
			int iZombieClass = GetEntProp(infected, Prop_Send, "m_zombieClass");
			switch (iZombieClass)
			{
				case 1:
				{
					iSmokers++;
				}
				case 2:
				{
					iBoomers++;
				}
				case 3:
				{
					iHunters++;
				}
				case 4:
				{
					iSpitters++;
				}
				case 5:
				{
					iJockeys++;
				}
				case 6:
				{
					iChargers++;
				}
			}
		}
	}
	int iType = GetURandomIntRange(1, 7);
	if (iType == 1)
	{
		if ((iSmokers < GetConVarInt(FindConVar("z_smoker_limit"))))
		{
			return 1;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 2)
	{
		if ((iBoomers < GetConVarInt(FindConVar("z_boomer_limit"))))
		{
			return 2;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 3)
	{
		if ((iHunters < GetConVarInt(FindConVar("z_hunter_limit"))))
		{
			return 3;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 4)
	{
		if ((iSpitters < GetConVarInt(FindConVar("z_spitter_limit"))))
		{
			return 4;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 5)
	{
		if ((iJockeys < GetConVarInt(FindConVar("z_jockey_limit"))))
		{
			return 5;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	else if (iType == 6)
	{
		if ((iChargers < GetConVarInt(FindConVar("z_charger_limit"))))
		{
			return 6;
		}
		else
		{
			IsBotTypeNeeded();
		}
	}
	return 0;
}

int GetURandomIntRange(int min, int max)
{
	return (GetURandomInt() & (max - min + 1)) + min;
}