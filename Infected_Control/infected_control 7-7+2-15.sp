#pragma semicolon 1
#pragma newdecls required

// 头文件：2022-4-21 新增 l4d2_saferoom_detect 检测是否在终点安全屋刷特
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2_saferoom_detect>

#define CVAR_FLAG FCVAR_NOTIFY
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
// 特感种类
#define ZC_HUNTER 3
#define ZC_SPITTER 4
#define ZC_TANK 8
// 数据
#define NAV_MESH_HEIGHT 20.0
#define PLAYER_HEIGHT 72.0
#define PLAYER_CHEST 45.0
#define INFECTED_COURCH_TIME 1.5
#define INFECTED_TELE_INTERVAL 3
#define RAY_DIRECTION view_as<float>({90.0, 0.0, 0.0})

// 插件基本信息，根据 GPL 许可证条款，需要修改插件请勿修改此信息！
public Plugin myinfo = 
{
	name 			= "Direct InfectedSpawn",
	author 			= "Caibiii, 夜羽真白",
	description 	= "特感刷新控制，传送落后特感",
	version 		= "2022.04.20",
	url 			= "https://github.com/GlowingTree880/L4D2_LittlePlugins"
}

// Cvars
ConVar g_hSpawnDistanceMin, g_hSpawnDistanceMax, g_hTeleportSi, g_hTeleportDistance, g_hSiLimit, g_hSiInterval, g_hMaxPlayerZombies, g_hSbEscort, g_hSpawnMax, g_hEnableWaveSpawn, g_hWaveSpawnFrame, g_hSpawnMode;
// Ints
int g_iSiLimit, g_iSbEscort, iUnRechedLimitCount = 0, g_iWaveSpawnFrame, g_iSpawnMode,
g_iTeleCount[MAXPLAYERS + 1] = {0}, g_iTargetSurvivor = -1, g_iSpawnMaxCount = 0, g_iSurvivorNum = 0, g_iSurvivors[MAXPLAYERS + 1] = {0}, g_iWaveCount = 0, g_iWaveSiLimit[6][1], g_iQueueIndex = 0;
// Floats
float g_fSpawnDistanceMin, g_fSpawnDistanceMax, g_fTeleportDistance, g_fSiInterval;
// Bools
bool g_bTeleportSi, g_bEnableWaveSpawn
, g_bIsLate = false;
// Handle
Handle g_hTeleHandle = INVALID_HANDLE;
// ArrayList
ArrayList aThreadHandle, aSpawnQueue;

stock const char InfectedName[10][] =
{
	"common",
	"smoker",
	"boomer",
	"hunter",
	"spitter",
	"jockey",
	"charger",
	"witch",
	"tank",
	"survivor"
};

stock const char VisibleName[5][] =
{
	"无效可见性",
	"完全不可见",
	"可见至胸部",
	"可见至眼部",
	"完全可见"
};

enum VisibleType
{
	Visible_None = 0,
	Cant_Visible,
	Visible_Chest,
	Visible_Eye,
	Can_Visible,
};

// 玩家蹲下检测结构体，结构体数组，结构体成员：当前玩家是否可以蹲下，可以蹲下时的时间戳
enum struct DuckCheck
{
	bool CanDuck;
	float DuckTime;
}
DuckCheck g_CanDuck[MAXPLAYERS + 1];

public void OnPluginStart()
{
	// CreateConVar
	g_hSpawnDistanceMin = CreateConVar("inf_SpawnDistanceMin", "0.0", "特感复活离生还者最近的距离限制", CVAR_FLAG, true, 0.0);
	g_hSpawnDistanceMax = CreateConVar("inf_SpawnDistanceMax", "500.0", "特感复活离生还者最远的距离限制", CVAR_FLAG, true, g_hSpawnDistanceMin.FloatValue);
	g_hTeleportSi = CreateConVar("inf_TeleportSi", "1", "是否开启特感距离生还者一定距离将其传送至生还者周围", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hTeleportDistance = CreateConVar("inf_TeleportDistance", "650.0", "特感落后于最近的生还者超过这个距离则将它们传送", CVAR_FLAG, true, 0.0);
	g_hSiLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0);
	g_hSiInterval = CreateConVar("versus_special_respawn_interval", "16.0", "对抗模式下刷特时间控制", CVAR_FLAG, true, 0.0);
	g_hEnableWaveSpawn = CreateConVar("inf_EnableWaveSpawn", "0", "是否开启限制特感刷新必须在 x 帧内完成", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hWaveSpawnFrame = CreateConVar("inf_WaveSpawnFrame", "120", "一波的刷特必须要在这么多帧内完成找位与刷新", CVAR_FLAG, true, 0.0);
	g_hSpawnMode = CreateConVar("inf_SpawnMode", "2", "刷特方式选择：1=阳间，2=阴间，3=随机阳间阴间", CVAR_FLAG, true, 1.0, true, 3.0);
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
	aSpawnQueue = new ArrayList();
	// GetCvars
	GetCvars();
	GetSiLimit();
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
	g_iWaveCount = 0;
	for (int hTimerHandle = aThreadHandle.Length - 1; hTimerHandle >= 0; hTimerHandle--)
	{
		KillTimer(aThreadHandle.Get(hTimerHandle));
		aThreadHandle.Erase(hTimerHandle);
	}
	aThreadHandle.Clear();
	aSpawnQueue.Resize(1);
	g_iQueueIndex = 0;
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
	aSpawnQueue.Resize(1);
	g_iQueueIndex = 0;
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
	g_CanDuck[client].CanDuck = false;
	g_CanDuck[client].DuckTime = 0.0;
}

public Action Timer_KickBot(Handle timer, int client)
{
	if (IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
	{
		KickClient(client, "[Infected-Spawn]：You are worthless and was kicked by console");
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
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_HUNTER && g_CanDuck[client].CanDuck == true)
	{
		if (GetGameTime() - g_CanDuck[client].DuckTime < INFECTED_COURCH_TIME)
		{
			buttons = 0;
			buttons |= IN_DUCK;
			if ((buttons & IN_DUCK) && GetEntityFlags(client) & FL_DUCKING)
			{
				bool bHasSight = view_as<bool>(GetEntProp(client, Prop_Send, "m_hasVisibleThreats"));
				if (bHasSight)
				{
					g_CanDuck[client].CanDuck = false;
					g_CanDuck[client].DuckTime = 0.0;
				}
			}
		}
		else
		{
			g_CanDuck[client].CanDuck = false;
			g_CanDuck[client].DuckTime = 0.0;
		}
	}
	return Plugin_Continue;
}

public void OnGameFrame()
{
	// 根据情况动态调整 z_maxplayers_zombie 数值
	if (g_iSiLimit > g_hMaxPlayerZombies.IntValue)
	{
		CreateTimer(0.1, MaxSpecialsSet);
	}
	// 构建刷特队列，相对于以前刷特时才随机特感种类，此方法在 OnGameFrame 时（空闲时）执行，减少性能使用，使用 ArrayList 动态数组实现，队列索引：g_iQueueIndex 于开局与终局设置为 0，同时将队列 Resize 为 1
	//，当队列索引小于刷特限制时，随机 1-6 的元素（少于 Cvar 限制且少于在场特感种类限制）入队，同时队列索引增加，刷特时，队列索引减少，当队列索引等于 g_iSiLimit + 1 时，队满，不再执行以下入队代码
	//，时间与空间复杂度为 O(1)
	if (g_iQueueIndex < g_iSiLimit)
	{
		int zombieclass = 0;
		if (aSpawnQueue.Length < g_iSiLimit)
		{
			zombieclass = GetRandomInt(1, 6);
		}
		if (zombieclass != 0 && g_iWaveSiLimit[zombieclass - 1][0] > 0 && !HasReachedLimit(zombieclass) && g_iQueueIndex < g_iSiLimit)
		{
			aSpawnQueue.Push(g_iQueueIndex);
			aSpawnQueue.Set(g_iQueueIndex, zombieclass, 0, false);
			g_iWaveSiLimit[zombieclass - 1][0] -= 1;
			g_iQueueIndex += 1;
			PrintToConsoleAll("[Infected-Spawn]：当前入队元素：%d，当前队列长度：%d，当前队列索引位置：%d", zombieclass, aSpawnQueue.Length, g_iQueueIndex);
		}
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
									// 先判断刷特上限是否大于 0 再刷出特感，否则先刷出特感再减少刷特上限，会多刷一个特感
									if (!HasReachedLimit(aSpawnQueue.Get(0)) && g_iSpawnMaxCount > 0)
									{
										int entityindex = L4D2_SpawnSpecial(aSpawnQueue.Get(0), fPos, view_as<float>({0.0, 0.0, 0.0}));
										if (IsValidEntity(entityindex) && IsValidEdict(entityindex))
										{
											g_iSpawnMaxCount -= 1;
											if (aSpawnQueue.Length > 0 && g_iQueueIndex > 0)
											{
												aSpawnQueue.Erase(0);
												g_iQueueIndex -= 1;
											}
										}
									}
									else if (HasReachedLimit(aSpawnQueue.Get(0)))
									{
										ReachedLimit();
									}
									if (g_iSpawnMaxCount <= 0)
									{
										g_iSpawnMaxCount = 0;
										aSpawnQueue.Resize(1);
										g_iQueueIndex = 0;
										GetSiLimit();
									}
								}
								iUnRechedLimitCount = 0;
							}
						}
					}
				}
			}
			// 检测完特感团队，如无在场特感，则继续检测能否刷新，选择刷特方式，阳间阴间
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
	if (IsValidSurvivor(g_iTargetSurvivor))
	{
		char classname[16] = '\0';
		int iVisible = IsPlayerVisibleTo(fSpawnPos), entityindex = -1;
		L4D_GetRandomPZSpawnPosition(g_iTargetSurvivor, aSpawnQueue.Get(0), 1, fSpawnPos);
		if (iVisible == view_as<int>(Cant_Visible) || iVisible == view_as<int>(Visible_Chest))
		{
			GetClientAbsOrigin(g_iTargetSurvivor, fSurvivorPos);
			// 当生还者不在有效的 Nav Area 时，也允许刷特感，只需计算距离
			if (!IsOnValidMesh(fSurvivorPos) && (200 < GetSurvivorDistance(fSpawnPos) < RoundToNearest(fSpawnDistanceMax)))
			{
				if (!HasReachedLimit(aSpawnQueue.Get(0)) && g_iSpawnMaxCount > 0)
				{
					entityindex = L4D2_SpawnSpecial(aSpawnQueue.Get(0), fSpawnPos, view_as<float>({0.0, 0.0, 0.0}));
				}
				else if (HasReachedLimit(aSpawnQueue.Get(0)))
				{
					ReachedLimit();
				}
			}
			// 当生还者在有效 Nav Area 时，则需计算两块 Nav Area 之间的可达距离，距离在 250.0 - 750.0 内，则允许刷特
			fDistance = L4D2_NavAreaTravelDistance(fSpawnPos, fSurvivorPos, false);
			if (250.0 < fDistance < fSpawnDistanceMax + 500.0)
			{
				if (!HasReachedLimit(aSpawnQueue.Get(0)) && g_iSpawnMaxCount > 0)
				{
					entityindex = L4D2_SpawnSpecial(aSpawnQueue.Get(0), fSpawnPos, view_as<float>({0.0, 0.0, 0.0}));
				}
				else if (HasReachedLimit(aSpawnQueue.Get(0)))
				{
					ReachedLimit();
				}
			}
			if (IsValidEntity(entityindex) && IsValidEdict(entityindex))
			{
				GetEntityNetClass(entityindex, classname, sizeof(classname));
				// 检测特感是否刷在终点安全屋内
				if (SAFEDETECT_IsEntityInEndSaferoom(entityindex))
				{
					ForcePlayerSuicide(entityindex);
					PrintToConsoleAll("[Infected-Spawn]：阳间模式：特感：%s，位置：%.2f，%.2f，%.2f，刷新在终点安全屋内，强制处死", classname, fSpawnPos[0], fSpawnPos[1], fSpawnPos[2]);
					return;
				}
				if (g_iSpawnMaxCount > 0)
				{
					g_iSpawnMaxCount -= 1;
					if (aSpawnQueue.Length > 0 && g_iQueueIndex > 0)
					{
						aSpawnQueue.Erase(0);
						g_iQueueIndex -= 1;
					}
				}
				if (g_iSpawnMaxCount <= 0)
				{
					g_iSpawnMaxCount = 0;
					aSpawnQueue.Resize(1);
					g_iQueueIndex = 0;
					GetSiLimit();
				}
				if (g_hSpawnMax.IntValue < 100)
				{
					g_hSpawnMax.IntValue = 0;
				}
				PrintToConsoleAll("[Infected-Spawn]：阳间模式：当前位置可见性：%s，刷新特感：%s，位置：%.2f，%.2f，%.2f，剩余刷新特感数量：%d"
				, VisibleName[iVisible], classname, fSpawnPos[0], fSpawnPos[1], fSpawnPos[2], g_iSpawnMaxCount);
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
	float fSpawnPos[3] = {0.0}, fSurvivorPos[3] = {0.0}, fEndPos[3] = {0.0}, fMins[3] = {0.0}, fMaxs[3] = {0.0};
	if (IsValidSurvivor(g_iTargetSurvivor))
	{
		// 根据指定生还者坐标，拓展刷新范围
		GetClientEyePosition(g_iTargetSurvivor, fSurvivorPos);
		fMins[0] = fSurvivorPos[0] - g_fSpawnDistanceMax;
		fMaxs[0] = fSurvivorPos[0] + g_fSpawnDistanceMax;
		fMins[1] = fSurvivorPos[1] - g_fSpawnDistanceMax;
		fMaxs[1] = fSurvivorPos[1] + g_fSpawnDistanceMax;
		fMaxs[2] = fSurvivorPos[2] + g_fSpawnDistanceMax;
		// 随机刷新位置
		fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
		fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
		fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
		// 找位条件，可视，是否在有效 NavMesh，是否卡住，否则先会判断是否在有效 Mesh 与是否卡住导致某些位置刷不出特感
		TR_TraceRay(fSpawnPos, RAY_DIRECTION, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
		if (TR_DidHit())
		{
			TR_GetEndPosition(fEndPos);
			fSpawnPos = fEndPos;
			fSpawnPos[2] += NAV_MESH_HEIGHT;
		}
		int iVisible = IsPlayerVisibleTo(fSpawnPos);
		if ((iVisible == view_as<int>(Visible_Eye) || iVisible == view_as<int>(Cant_Visible)) && IsOnValidMesh(fSpawnPos) && !IsPlayerStuck(fSpawnPos) && 
			L4D2_VScriptWrapper_NavAreaBuildPath(fSpawnPos, fSurvivorPos, g_fSpawnDistanceMax * 2, false, false, TEAM_INFECTED, false) && GetVectorDistance(fSpawnPos, fSurvivorPos) > g_fSpawnDistanceMin)
		{
			// 生还数量为 4，循环 4 次，检测此位置到生还的距离是否小于 750 是则刷特，此处一个位置可以刷新 1 - 4 只特感，如果此处刷完，则上面的 SpawnSpecial 将不再刷特
			for (int count = 0; count < g_iSurvivorNum; count++)
			{
				char classname[16] = '\0';
				int index = g_iSurvivors[count], entityindex = -1;
				if (IsValidSurvivor(index))
				{
					GetClientAbsOrigin(index, fSurvivorPos);
					if (!HasReachedLimit(aSpawnQueue.Get(0)) && g_iSpawnMaxCount > 0)
					{
						entityindex = L4D2_SpawnSpecial(aSpawnQueue.Get(0), fSpawnPos, view_as<float>({0.0, 0.0, 0.0}));
						if (IsValidEntity(entityindex) && IsValidEdict(entityindex))
						{
							GetEntityNetClass(entityindex, classname, sizeof(classname));
							// 检测生成的特感是否处于终点安全屋内，是，则处死当前生成在安全屋内的特感，跳出循环，这个位置作废，重新找下一个刷特位置
							if (SAFEDETECT_IsEntityInEndSaferoom(entityindex))
							{
								ForcePlayerSuicide(entityindex);
								PrintToConsoleAll("[Infected-Spawn]：正常模式：特感：%s，位置：%.2f，%.2f，%.2f，刷新在终点安全屋内，强制处死，跳出当前位置循环", classname, fSpawnPos[0], fSpawnPos[1], fSpawnPos[2]);
								break;
							}
							if (g_iSpawnMaxCount > 0)
							{
								g_iSpawnMaxCount -= 1;
								if (aSpawnQueue.Length > 0 && g_iQueueIndex > 0)
								{
									aSpawnQueue.Erase(0);
									g_iQueueIndex -= 1;
								}
							}
							if (g_iSpawnMaxCount <= 0)
							{
								g_iSpawnMaxCount = 0;
								// 不可直接 Clear，Clear 相当于 Resize(0)，则索引 0 的位置会无效化，如果再次执行 Get(0) 会报错，所以 Resize(1)，留出一个索引位置
								aSpawnQueue.Resize(1);
								g_iQueueIndex = 0;
								GetSiLimit();
							}
							if (iVisible == view_as<int>(Visible_Eye))
							{
								g_CanDuck[entityindex].CanDuck = true;
								g_CanDuck[entityindex].DuckTime = GetGameTime();
							}
							if (g_hSpawnMax.IntValue < 100)
							{
								g_hSpawnMax.IntValue = 0;
							}
							PrintToConsoleAll("[Infected-Spawn]：正常模式，当前位置可见性：%s，刷新特感：%s，位置：%.2f，%.2f，%.2f，剩余刷新特感数量：%d，队列索引：%d"
							, VisibleName[iVisible], classname, fSpawnPos[0], fSpawnPos[1], fSpawnPos[2], g_iSpawnMaxCount, g_iQueueIndex);
						}
					}
					else if (HasReachedLimit(aSpawnQueue.Get(0)))
					{
						ReachedLimit();
					}
				}
			}
		}
	}
}

// 当前在场的某种特感种类数量达到 Cvar 限制，但因为刷新一个特感，出队此元素，之后再入队相同特感元素，则会刷不出来，需要处理重复情况，如果队列长度大于 1 且索引大于 0，说明队列存在
// 首非零元，直接擦除队首元素并令队列索引 -1 即可，时间复杂度为 O(1)，如果队列中只有一个元素，则循环 1-6 的特感种类替换此元素（一般不会出现），时间复杂度为 O(n)
// 如：当前存在 2 个 Smoker 未死亡，Smoker 的 Cvar 限制为 2 ，这时入队一个 Smoker 元素，则会导致无法刷出特感
void ReachedLimit()
{
	if (aSpawnQueue.Length > 1 && g_iQueueIndex > 0)
	{
		aSpawnQueue.Erase(0);
		g_iQueueIndex -= 1;
	}
	else
	{
		for (int i = 1; i <= 6; i++)
		{
			if (!HasReachedLimit(i))
			{
				aSpawnQueue.Set(0, i, 0, false);
			}
		}
	}
}

// 禁推口水
/* public Action L4D_OnShovedBySurvivor(int client, int victim, const float vecDir[3])
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
} */

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
		// 创建间隔为 1.0 秒的循环时钟，检测特感是否可以传送，总共检测 6 次
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
		// 当一定时间内刷不出特感，触发时钟使 g_iSpawnMaxCount 超过 g_iSiLimit 值时，使 g_iSpawnMaxCount = g_iSiLimit 不多刷
		if (g_iSpawnMaxCount > g_iSiLimit)
		{
			g_iSpawnMaxCount = g_iSiLimit;
			g_hSbEscort.IntValue =  1;
		}
		else if (g_iSpawnMaxCount == g_iSiLimit)
		{
			PrintToConsoleAll("[Infected-Spawn]：开始第：%d 波特感刷新", g_iWaveCount += 1);
			PrintToConsoleAll("当前数量：%d", g_iSpawnMaxCount);
		}
	}
	return Plugin_Continue;
}

// 开局重置特感特感传送次数为 0，并复活死亡玩家
public Action SafeRoomReset(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsInfectedBot(client) && IsPlayerAlive(client))
		{
			g_iTeleCount[client] = 0;
		}
		if (IsValidSurvivor(client) && !IsPlayerAlive(client))
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

// 检测某个坐标是否对玩家可视，定义 fChestSpawnPos，令其 z 高度为 40，胸口位置，定义 fEyeSpawnPos，令其 z 高度为 67，总共使用三条射线
// 当三条射线均撞到物体，则为完全不可见，当 20 和 40 的高度射线撞到物体，而 67 高度的射线未撞到物体，则返回可见至眼部，这时令刷出的特感蹲下
// 当 20 的射线撞到物体，40 和 67 高度的射线未撞到物体，返回可见至胸部，当三条射线均未撞到物体，则返回完全可见，不允许在完全可见的状态下刷特
int IsPlayerVisibleTo(float fSpawnPos[3])
{
	int iVisible = view_as<int>(Visible_None);	bool bVisible = false;
	float fChestSpawnPos[3] = {0.0}, fEyeSpawnPos[3] = {0.0};
	CopyVectors(fSpawnPos, fChestSpawnPos);
	CopyVectors(fSpawnPos, fEyeSpawnPos);
	fChestSpawnPos[2] += 20.0;
	fEyeSpawnPos[2] += 47.0;
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
		{
			float fEyePos[3] = {0.0};
			GetClientEyePosition(client, fEyePos);
			Handle hTrace = TR_TraceRayFilterEx(fSpawnPos, fEyePos, MASK_SHOT, RayType_EndPoint, TraceFilter, client);
			Handle hChestTrace = TR_TraceRayFilterEx(fChestSpawnPos, fEyePos, MASK_SHOT, RayType_EndPoint, TraceFilter, client);
			Handle hEyeTrace = TR_TraceRayFilterEx(fEyeSpawnPos, fEyePos, MASK_SHOT, RayType_EndPoint, TraceFilter, client);
			if (TR_DidHit(hTrace) && TR_DidHit(hChestTrace) && TR_DidHit(hEyeTrace))
			{
				iVisible = view_as<int>(Cant_Visible);
				delete hTrace; delete hChestTrace; delete hEyeTrace;
			}
			else if (TR_DidHit(hTrace) && TR_DidHit(hChestTrace) && !TR_DidHit(hEyeTrace))
			{
				iVisible = view_as<int>(Visible_Eye);
				delete hTrace; delete hChestTrace; delete hEyeTrace;
			}
			else if (TR_DidHit(hTrace) && !TR_DidHit(hChestTrace) && !TR_DidHit(hEyeTrace))
			{
				iVisible = view_as<int>(Visible_Chest);
				delete hTrace; delete hChestTrace; delete hEyeTrace;
			}
			else if (!TR_DidHit(hTrace) && !TR_DidHit(hChestTrace) && !TR_DidHit(hEyeTrace))
			{
				bVisible = true;
				iVisible = view_as<int>(Can_Visible);
				delete hTrace; delete hChestTrace; delete hEyeTrace;
			}
			delete hTrace; delete hChestTrace; delete hEyeTrace;
		}
	}
	if (bVisible)
	{
		iVisible = view_as<int>(Can_Visible);
	}
	return iVisible;
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
	if (entity <= MaxClients)
	{
		return false;
	}
	else
	{
		static char classname[9];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (classname[0] == 'i' || classname[0] == 'w' || classname[0] == 'p')
		{
			if (strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0 || strcmp(classname, "prop_physics") == 0)
			{
				return false;
			}
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

// 检测特感是否可以传送，特感不是 Tank 且特感未控到人，如果 g_iTeleCount[client] 大于 6 次，如果当前位置不可直视生还，则传送至有效位置
public Action Timer_PositionSi(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (CanBeTeleport(client))
		{
			if (g_iTeleCount[client] > INFECTED_TELE_INTERVAL)
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

/* bool IsSpitter(int client)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_SPITTER)
	{
		return true;
	}
	else
	{
		return false;
	}
} */

// 检测在场特感数量
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

// 当前某种特感数量是否达到 Convar 值限制
bool HasReachedLimit(int zombieclass)
{
	int count = 0;	char convar[16] = '\0';
	for (int infected = 1; infected <= MaxClients; infected++)
	{
		if (IsClientConnected(infected) && IsClientInGame(infected) && GetEntProp(infected, Prop_Send, "m_zombieClass") == zombieclass)
		{
			count += 1;
		}
	}
	FormatEx(convar, sizeof(convar), "z_%s_limit", InfectedName[zombieclass]);
	if (count == GetConVarInt(FindConVar(convar)))
	{
		return true;
	}
	else
	{
		return false;
	}
}

// 传送落后特感
public void SDK_UpdateThink(int client)
{
	if (IsInfectedBot(client) && IsPlayerAlive(client))
	{
		g_iTeleCount[client] = 0;
		switch (g_iSpawnMode)
		{
			case 1:
			{
				EasyTeleMode(client);
			}
			case 2:
			{
				HardTeleMode(client);
			}
			case 3:
			{
				int anne = GetRandomInt(1, 2);
				switch (anne)
				{
					case 1:
					{
						EasyTeleMode(client);
					}
					case 2:
					{
						HardTeleMode(client);
					}
				}
			}
		}
	}
}

void EasyTeleMode(int client)
{
	float SpawnPos[3] = {0.0}, Distance = 0.0, TargetPos[3] = {0.0}, SelfPos[3] = {0.0};
	GetClientAbsOrigin(client, SelfPos);
	if (IsValidSurvivor(g_iTargetSurvivor))
	{
		int ZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		L4D_GetRandomPZSpawnPosition(g_iTargetSurvivor, ZombieClass, 1, SpawnPos);
		if (!IsPlayerVisibleTo(SelfPos))
		{
			if (!IsPlayerVisibleTo(SpawnPos) && !IsPinningSomeone(client))
			{
				GetClientAbsOrigin(g_iTargetSurvivor, TargetPos);
				if (!IsOnValidMesh(TargetPos))
				{
					if (200 < GetSurvivorDistance(SpawnPos) < RoundToNearest(g_fSpawnDistanceMax))
					{
						TeleportEntity(client, SpawnPos, NULL_VECTOR, NULL_VECTOR);
						g_iTeleCount[client] = 0;
						SDKUnhook(client, SDKHook_PostThinkPost, SDK_UpdateThink);
					}
				}
				Distance = L4D2_NavAreaTravelDistance(SpawnPos, TargetPos, false);
				if (Distance < RoundToNearest(g_fSpawnDistanceMax) + 500)
				{
					TeleportEntity(client, SpawnPos, NULL_VECTOR, NULL_VECTOR);
					g_iTeleCount[client] = 0;
					SDKUnhook(client, SDKHook_PostThinkPost, SDK_UpdateThink);
				}
			}
		}
	}
}

void HardTeleMode(int client)
{
	static float fEyePos[3] = {0.0}, fSelfEyePos[3] = {0.0};
	GetClientEyePosition(client, fEyePos);
	if (!IsPlayerVisibleTo(fEyePos) && !IsPinningSomeone(client))
	{
		float fSpawnPos[3] = {0.0}, fSurvivorPos[3] = {0.0}, fEndPos[3] = {0.0}, fMins[3] = {0.0}, fMaxs[3] = {0.0};
		if (IsValidSurvivor(g_iTargetSurvivor))
		{
			GetClientEyePosition(g_iTargetSurvivor, fSurvivorPos);
			GetClientEyePosition(client, fSelfEyePos);
			fMins[0] = fSurvivorPos[0] - g_fSpawnDistanceMax;
			fMaxs[0] = fSurvivorPos[0] + g_fSpawnDistanceMax;
			fMins[1] = fSurvivorPos[1] - g_fSpawnDistanceMax;
			fMaxs[1] = fSurvivorPos[1] + g_fSpawnDistanceMax;
			fMaxs[2] = fSurvivorPos[2] + g_fSpawnDistanceMax;
			fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
			fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
			fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
			TR_TraceRay(fSpawnPos, RAY_DIRECTION, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
			if (TR_DidHit())
			{
				TR_GetEndPosition(fEndPos);
				fSpawnPos = fEndPos;
				fSpawnPos[2] += NAV_MESH_HEIGHT;
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

// 复制向量
float CopyVectors(float origin[3], float result[3])
{
	result[0] = origin[0];
	result[1] = origin[1];
	result[2] = origin[2];
}

// 特感种类限制数组，刷完一波特感时重新读取 Cvar 数值，重置特感种类限制数量
void GetSiLimit()
{
	g_iWaveSiLimit[0][0] = GetConVarInt(FindConVar("z_smoker_limit"));
	g_iWaveSiLimit[1][0] = GetConVarInt(FindConVar("z_boomer_limit"));
	g_iWaveSiLimit[2][0] = GetConVarInt(FindConVar("z_hunter_limit"));
	g_iWaveSiLimit[3][0] = GetConVarInt(FindConVar("z_spitter_limit"));
	g_iWaveSiLimit[4][0] = GetConVarInt(FindConVar("z_jockey_limit"));
	g_iWaveSiLimit[5][0] = GetConVarInt(FindConVar("z_charger_limit"));
}