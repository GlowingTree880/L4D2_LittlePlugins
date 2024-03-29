#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include "treeutil/treeutil.sp"

#define DEBUG_ALL 0
#define CVAR_FLAG FCVAR_NOTIFY
// NAV 高度和检测可视的高度
#define NAV_HEIGHT 20.0
#define VISIBLE_HEIGHT 72.0
// 每种特感刷新一只的阈值
#define ALL_SPAWN_ONE_THERSHOLD 6
// 函数找位每次找位次数
#define DEFAULT_FIND_POS_ATTEMPT 15
// 一次找位最高位置超过生还者高度这么多的位置才会被认为是找到高位
#define HEIG_POS_HEIGHT 200.0
// 特感传送和检测被控的间隔
#define CHECK_PINNED_AND_TELEPORT_INTERVAL 1.0
// 角度
#define TRACE_RAY_ANGLE view_as<float>({90.0, 0.0, 0.0})
#define STUCK_SIZE_MIN view_as<float>({-16.0, -16.0, 0.0})
#define STUCK_SIZE_MAX view_as<float>({16.0, 16.0, 72.0})
#define INFECTED_SPAWN_EYE_ANGLE view_as<float>({0.0, 0.0, 0.0})
#define INTEGER_MAX_VALUE 2147483647

static const char infectedName[9][] =
{
	"",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank"
};

// 刷新策略：1.按照距离升序刷新，2.按照高度降序刷新
enum
{
	SPAWN_BY_DISTANCE = 1,
	SPAWN_BY_HEIGHT,
	SPAWN_STRATERGY_COUNT
};

public Plugin myinfo = 
{
	name 			= "Direct-Infected-Control",
	author 			= "夜羽真白",
	description 	= "特感刷新，传送落后特感",
	version 		= "2022-12-12",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar
	g_hInfectedLimit,
	g_hInfectedSpawnInterval,
	g_hGt9AddTime,
	g_hLt9AddTime,
	g_hFindPosLimit,
	g_hMinSpawnDist,
	g_hMaxSpawnDist,
	g_hSpawnStratergy,
	g_hOnePosInfectedLimit,
	g_hAllowPosRadomInfectedLimit,
	g_hAllowDelaySpawn,
	g_hDelaySpawnInfected,
	g_hDelaySpawnTime,
	g_hEveryTargetFrame,
	g_hExpandFrame,
	g_hMaxFindPosTime,
	g_hAllowAllSpawnOne,
	g_hTeleportDist,
	g_hPreTeleportCount,
	g_hAheadTargetDist,
	g_hAllowSpawnInSafeArea,
	g_hAllowEasyMode,
	g_hEnableLog;
// 感染者在队列中的位置 Cvar
ConVar g_hInfectedInQueuePos[6];
// 感染者数量 Cvar
ConVar
	g_hSmokerCount,
	g_hBoomerCount,
	g_hHunterCount,
	g_hSpitterCount,
	g_hJockeyCount,
	g_hChargerCount,
	g_hPlayerInfectedLimit;
int
	infectedCountArray[7] = { 0 },
	infectedOnSoptArray[7] = { 0 },
	infectedInQueuePos[6][2],
	preTeleportCount[MAXPLAYERS + 1] = { 0 },
	targetFrame = 0,
	expandFrame = 0, 
	targetSurvivor = -1,
	pinnedTarget = -1,
	aheadTarget = -1,
	preferredSpawnDirection = 0,
	spawnCount = 0;
bool
	g_bCanFindPos = false,
	g_bCanTeleportFindPos = false,
	g_bHasLeftSafeArea = false,
	g_bCanSpawn = false,
	g_bIsFirstWave = false,
	g_bGeneratedFirstWave = false,
	g_bPosHasSorted = false,
	g_bExceedFindPosTime = false,
	g_bHasRecordTime = false,
	g_bHasRecordTeleportFindPosTime = false,
	g_bCanEasyModeSpawn = false,
	g_bDelaySpawnInfected[7] = { false };
float
	g_fFindPosStartTime = 0.0,
	g_fTeleportFindPosStartTime = 0.0;

Handle
	g_hFindPosTimer = null,
	g_hPinnedAndTeleportTimer = null,
	g_hDelaySpawnTimer = null;
ArrayList
	spawnPosList = null,
	spawnList = null,
	delaySpawnList = null,
	teleportList = null;

public void OnPluginStart()
{
	char cvarString[4] = {'\0'};
	g_hInfectedLimit = CreateConVar("l4d_infected_limit", "6", "一次刷出多少特感", CVAR_FLAG, true, 0.0, true, 26.0);
	g_hInfectedSpawnInterval = CreateConVar("versus_special_respawn_interval", "16.0", "特感刷新间隔", CVAR_FLAG, true, 0.0);
	// 找位设置
	g_hInfectedLimit.GetString(cvarString, sizeof(cvarString));
	g_hFindPosLimit = CreateConVar("inf_find_pos_limit", cvarString, "进行一次找位最多允许找多少个位置", CVAR_FLAG, true, 0.0);
	g_hMinSpawnDist = CreateConVar("inf_min_spawn_dist", "250", "特感找位与生还者最小距离", CVAR_FLAG, true, 0.0);
	g_hMaxSpawnDist = CreateConVar("inf_max_spawn_dist", "500", "特感找位与生还者最大距离", CVAR_FLAG, true, 0.0);
	g_hEveryTargetFrame = CreateConVar("inf_evert_target_frame", "15", "以每个生还者为目标进行找位的帧数", CVAR_FLAG, true, 0.0);
	g_hExpandFrame = CreateConVar("inf_expand_frame", "50", "找了多少次位置之后每帧扩大 1 单位找位距离", CVAR_FLAG, true, 0.0);
	g_hMaxFindPosTime = CreateConVar("inf_max_find_pos_time", "2", "每次找位最大找位时间，超过这个时间会强制刷新", CVAR_FLAG, true, 0.0);
	g_hGt9AddTime = CreateConVar("inf_gt9_add_time", "6", "特感刷新间隔超过 9 秒时的加时", CVAR_FLAG, true, 0.0);
	g_hLt9AddTime = CreateConVar("inf_lt9_add_time", "1", "特感刷新间隔未超过 9 秒时的加时", CVAR_FLAG, true, 0.0);
	g_hAllowEasyMode = CreateConVar("inf_allow_easy_mode", "0", "是否开启简单模式（不会使用射线找位，适合三方图开黑）", CVAR_FLAG, true, 0.0, true, 1.0);
	// 特感传送
	g_hPreTeleportCount = CreateConVar("inf_pre_teleport_count", "3", "特感无视野且满足传送条件多少秒后踢出重新刷新", CVAR_FLAG, true, 0.0);
	g_hTeleportDist = CreateConVar("inf_teleport_distance", "250", "特感无视野且距离生还者多远将会踢出重新刷新", CVAR_FLAG, true, 0.0);
	g_hAheadTargetDist = CreateConVar("inf_ahead_target_distance", "1500", "某个生还者离其他生还者多远将会被视为跑男", CVAR_FLAG, true, 0.0);
	// 刷新队列设置
	g_hInfectedInQueuePos[0] = CreateConVar("inf_in_queue_pos_smoker", "40,80", "Smoker 将会允许在队列的什么百分比刷新（队列长度 100%）", CVAR_FLAG);
	g_hInfectedInQueuePos[1] = CreateConVar("inf_in_queue_pos_boomer", "90,100", "Boomer 将会允许在队列的什么百分比刷新", CVAR_FLAG);
	g_hInfectedInQueuePos[2] = CreateConVar("inf_in_queue_pos_hunter", "0,40", "Hunter 将会允许在队列的什么百分比刷新", CVAR_FLAG);
	g_hInfectedInQueuePos[3] = CreateConVar("inf_in_queue_pos_spitter", "90,100", "Spitter 将会允许在队列的什么百分比刷新", CVAR_FLAG);
	g_hInfectedInQueuePos[4] = CreateConVar("inf_in_queue_pos_jockey", "40,80", "Jockey 将会允许在队列的什么百分比刷新", CVAR_FLAG);
	g_hInfectedInQueuePos[5] = CreateConVar("inf_in_queue_pos_charger", "50,80", "Charger 将会允许在队列的什么百分比刷新", CVAR_FLAG);
	// 找位策略
	g_hSpawnStratergy = CreateConVar("inf_spawn_stratergy", "2", "特感刷新策略", CVAR_FLAG, true, (SPAWN_BY_DISTANCE * 1.0), true, (SPAWN_STRATERGY_COUNT - 1) * 1.0);
	g_hOnePosInfectedLimit = CreateConVar("inf_one_pos_limit", "2", "找到一个位置允许刷新多少个特感", CVAR_FLAG, true, 0.0);
	g_hAllowPosRadomInfectedLimit = CreateConVar("inf_allow_one_pos_random_limit", "0", "是否允许一个位置刷新随机只特感（开启此功能 g_hOnePosInfectedLimit 失效）", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowSpawnInSafeArea = CreateConVar("inf_allow_in_safe_area", "1", "是否允许特感在安全屋内刷新", CVAR_FLAG, true, 0.0, true, 1.0);
	// 延迟刷新
	g_hAllowDelaySpawn = CreateConVar("inf_allow_delay_spawn", "1", "是否允许特感延迟刷新", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hDelaySpawnInfected = CreateConVar("inf_delay_spawn_infected", "4", "哪些特感会延迟刷新（特感编号，逗号分隔）", CVAR_FLAG);
	g_hDelaySpawnTime = CreateConVar("inf_delay_spawn_time", "2.0", "特感延迟刷新的时间，超过这个时间会直接刷新", CVAR_FLAG, true, 0.0);
	// 6 特以上是否每种特感都会产生一只
	g_hAllowAllSpawnOne = CreateConVar("inf_allow_all_spawn_one", "1", "是否开启 6 特以上每种特感均产生一只", CVAR_FLAG, true, 0.0, true, 1.0);
	// 日志记录
	g_hEnableLog = CreateConVar("inf_enable_log", "1", "是否开启插件日志记录功能", CVAR_FLAG, true, 0.0, true, 1.0);
	// 其他 Cvar
	g_hPlayerInfectedLimit = FindConVar("z_max_player_zombies");
	// Hook 事件
	HookEvent("round_start", roundStartHandler);
	HookEvent("round_end", roundEndHandler);
	HookEvent("player_death", playerDeathHandler);
	// 获取感染者设置数量
	g_hSmokerCount = FindConVar("z_smoker_limit");
	g_hBoomerCount = FindConVar("z_boomer_limit");
	g_hHunterCount = FindConVar("z_hunter_limit");
	g_hSpitterCount = FindConVar("z_spitter_limit");
	g_hJockeyCount = FindConVar("z_jockey_limit");
	g_hChargerCount = FindConVar("z_charger_limit");
	// Hook 感染者数量 Cvar 变更
	g_hInfectedLimit.AddChangeHook(infectedLimitCvarChanged);
	g_hSmokerCount.AddChangeHook(infectedCountCvarChanged);
	g_hBoomerCount.AddChangeHook(infectedCountCvarChanged);
	g_hHunterCount.AddChangeHook(infectedCountCvarChanged);
	g_hSpitterCount.AddChangeHook(infectedCountCvarChanged);
	g_hJockeyCount.AddChangeHook(infectedCountCvarChanged);
	g_hChargerCount.AddChangeHook(infectedCountCvarChanged);
	g_hAllowEasyMode.AddChangeHook(easyModeCvarChanged);
	getInfectedCountArray();
	// 获取特感在队列中的设置位置
	getInfectedInQueuePos();
	// 构建刷新位置集合
	spawnPosList = new ArrayList(5);
	spawnList = new ArrayList(2);
	delaySpawnList = new ArrayList();
	teleportList = new ArrayList();
	// 获取延迟刷新的特感集合
	getDelaySpawnInfected();
	int flags = g_hPlayerInfectedLimit.Flags;
	g_hPlayerInfectedLimit.SetBounds(ConVarBound_Upper, false);
	SetConVarFlags(g_hPlayerInfectedLimit, flags & ~FCVAR_NOTIFY);
	// 调整导演系统 Cvar
	setDirectorCvars(true);
}
public void OnPluginEnd()
{
	delete spawnPosList;
	delete spawnList;
	delete delaySpawnList;
	delete teleportList;
	delete g_hFindPosTimer;
	delete g_hPinnedAndTeleportTimer;
	delete g_hDelaySpawnTimer;
	setDirectorCvars(false);
}

public void OnMapStart()
{
	clearAllStuff();
	CreateTimer(0.5, setDirectorCvarsHandler, _);
	CreateTimer(0.5, setMaxPlayerInfectedHandler, _);
}

// **********
//	  事件
// **********
public void roundStartHandler(Event event, const char[] name, bool dontBroadcast)
{
	clearAllStuff();
	CreateTimer(0.5, setDirectorCvarsHandler, _);
	CreateTimer(0.5, setMaxPlayerInfectedHandler, _);
}
public void roundEndHandler(Event event, const char[] name, bool dontBroadcast)
{
	clearAllStuff();
}
void clearAllStuff()
{
	g_bCanFindPos = g_bCanTeleportFindPos = g_bHasLeftSafeArea = g_bCanSpawn = g_bCanEasyModeSpawn = g_bIsFirstWave = g_bGeneratedFirstWave = g_bPosHasSorted = g_bExceedFindPosTime
	= g_bHasRecordTime = g_bHasRecordTeleportFindPosTime = false;
	g_fFindPosStartTime = g_fTeleportFindPosStartTime = 0.0;
	preferredSpawnDirection = SPAWN_ANYWHERE;
	spawnCount = 0;
	spawnPosList.Clear();
	spawnList.Clear();
	delaySpawnList.Clear();
	teleportList.Clear();
	clearPreTeleportCount();
	clearInfectedOnSpotArray();
	delete g_hFindPosTimer;
	delete g_hDelaySpawnTimer;
}
public void playerDeathHandler(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidInfected(client) || !IsFakeClient(client) || IsClientInKickQueue(client)) { return; }
	int infectedType = GetEntProp(client, Prop_Send, "m_zombieClass");
	--infectedOnSoptArray[infectedType];
	if (infectedType == ZC_SPITTER) { return; }
	CreateTimer(0.5, kickBotHandler, client);
}
public Action kickBotHandler(Handle timer, int client)
{
	if (!IsValidInfected(client) || !IsFakeClient(client) || IsClientInKickQueue(client)) { return Plugin_Continue; }
	KickClientEx(client, "踢出死亡感染者");
	preTeleportCount[client] = 0;
	return Plugin_Continue;
}
public Action setMaxPlayerInfectedHandler(Handle timer)
{
	g_hPlayerInfectedLimit.SetInt(g_hInfectedLimit.IntValue);
	return Plugin_Continue;
}
public Action setDirectorCvarsHandler(Handle timer)
{
	if (g_hAllowEasyMode.BoolValue) { setDirectorCvars(false); }
	else { setDirectorCvars(true); }
	return Plugin_Continue;
}

public void OnGameFrame()
{
	if (!g_bHasLeftSafeArea) { return; }
	static Handle trace;
	static int posIndex, posInfectedLimit, infectedType, nowInfectedCount;
	static float rayMinPos[3], rayMaxPos[3], rayStartPos[3], rayEndPos[3], visiblePos[3], targetSurvivorPos[3], spawnPos[3];
	// 目标生还者选择
	getTargetSurvivor(targetSurvivor);
	if (!IsValidSurvivor(targetSurvivor) || !IsPlayerAlive(targetSurvivor)) { return; }
	// 刷特射线找位
	if (!g_hAllowEasyMode.BoolValue && spawnPosList.Length < g_hFindPosLimit.IntValue && (g_bCanFindPos || g_bCanTeleportFindPos))
	{
		// 统计非传送找位和传送找位的时间
		if (!g_bCanTeleportFindPos && calculateFindPosTime() > g_hMaxFindPosTime.FloatValue)
		{
			#if DEBUG_ALL
				PrintToConsoleAll("---------- [INF]：本次找位超过了最大找位时间，当前找位时间：%.2f 秒，停止找位 ----------", calculateFindPosTime());
			#endif
			g_bExceedFindPosTime = true;
			g_bCanFindPos = false;
			return;
		}
		if (g_bCanTeleportFindPos && calculateTeleportFindPosTime() > g_hMaxFindPosTime.FloatValue)
		{
			#if DEBUG_ALL
				PrintToConsoleAll("[INF]：本次传送找位超过了最大找位时间，当前找位时间：%.2f 秒", calculateTeleportFindPosTime());
			#endif
			g_bExceedFindPosTime = true;
			g_bCanTeleportFindPos = false;
			return;
		}
		// 生成第一波将要刷新的特感
		if (g_bIsFirstWave && !g_bGeneratedFirstWave && spawnList.Length < g_hInfectedLimit.IntValue)
		{
			#if DEBUG_ALL
				PrintToConsoleAll("[INF]：开始第：%d 波特感刷新找位", ++spawnCount);
			#endif
			generateAWaveInfected();
			g_bGeneratedFirstWave = true;
			return;
		}
		GetClientAbsOrigin(targetSurvivor, targetSurvivorPos);
		generateRayMinAndMaxPos(rayMinPos, rayMaxPos, targetSurvivorPos);
		rayStartPos[0] = getRandomFloatInRange(rayMinPos[0], rayMaxPos[0]);
		rayStartPos[1] = getRandomFloatInRange(rayMinPos[1], rayMaxPos[1]);
		rayStartPos[2] = getRandomFloatInRange(targetSurvivorPos[2], rayMaxPos[2]);
		trace = TR_TraceRayFilterEx(rayStartPos, TRACE_RAY_ANGLE, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite, findSpawnPosRayFilter, _);
		expandFrame++;
		if (!TR_DidHit(trace))
		{
			delete trace;
			return;
		}
		TR_GetEndPosition(rayEndPos, trace);
		delete trace;
		visiblePos = rayEndPos; visiblePos[2] += VISIBLE_HEIGHT; rayEndPos[2] += NAV_HEIGHT;
		if (!checkIfSpawnPosValid(rayEndPos, visiblePos, targetSurvivorPos)) { return; }
		// 刷新第一波特感
		if (g_bIsFirstWave && g_bGeneratedFirstWave)
		{
			posInfectedLimit = getOnePosInfecetdLimit();
			while (spawnList.Length > 0 && posInfectedLimit-- > 0)
			{
				#if DEBUG_ALL
					PrintToConsoleAll("[INF]：目前是第一波特感刷新，使用射线找到位置，刷新一只 %s，当前 %s 数量 %d", infectedName[spawnList.Get(0)], infectedName[spawnList.Get(0)], ++infectedOnSoptArray[spawnList.Get(0)]);
				#endif
				L4D2_SpawnSpecial(spawnList.Get(0), rayEndPos, INFECTED_SPAWN_EYE_ANGLE);
				spawnList.Erase(0);
			}
			if (spawnList.Length <= 0) { g_bIsFirstWave = g_bCanFindPos = false; }
			return;
		}
		// 刷新落后特感
		if (g_bCanTeleportFindPos)
		{
			nowInfectedCount = getNowInfectedCount();
			if (teleportList.Length > 0 && nowInfectedCount < g_hInfectedLimit.IntValue)
			{
				#if DEBUG_ALL
					PrintToConsoleAll("[INF]：使用射线找到位置，刷新一只落后特感 %s，当前 %s 数量 %d", infectedName[teleportList.Get(0)], infectedName[teleportList.Get(0)], ++infectedOnSoptArray[teleportList.Get(0)]);
				#endif
				L4D2_SpawnSpecial(teleportList.Get(0), rayEndPos, INFECTED_SPAWN_EYE_ANGLE);
				teleportList.Erase(0);
			}
			else if (nowInfectedCount >= g_hInfectedLimit.IntValue || teleportList.Length <= 0)
			{
				teleportList.Clear();
				g_bCanTeleportFindPos = false;
			}
			return;
		}
		// 找到了有效位置，加入到位置集合中
		#if DEBUG_ALL
			PrintToConsoleAll("[INF]：位置有效，将找到的位置：%.2f %.2f %.2f 加入到位置集合中", rayEndPos[0], rayEndPos[1], rayEndPos[2]);
		#endif
		posIndex = spawnPosList.PushArray(rayEndPos);
		switch (g_hSpawnStratergy.IntValue)
		{
			case SPAWN_BY_DISTANCE: { spawnPosList.Set(posIndex, GetVectorDistance(rayEndPos, targetSurvivorPos), 3); }
			case SPAWN_BY_HEIGHT:
			{
				spawnPosList.Set(posIndex, rayEndPos[2] - targetSurvivorPos[2], 3);
				spawnPosList.Set(posIndex, GetVectorDistance(rayEndPos, targetSurvivorPos), 4);
			}
		}
		return;
	}
	// 超过了最大找位时间，仍有待传送的特感未刷出，使用函数刷出
	if ((!g_bCanTeleportFindPos || g_hAllowEasyMode.BoolValue) && teleportList.Length > 0)
	{
		if (getNowInfectedCount() < g_hInfectedLimit.IntValue)
		{
			preferredSpawnDirection = SPAWN_IN_FRONT_OF_SURVIVORS;
			infectedType = teleportList.Get(0);
			getInfectedSpawnPosUsingFunction(infectedType, targetSurvivor, spawnPos);
			L4D2_SpawnSpecial(infectedType, spawnPos, INFECTED_SPAWN_EYE_ANGLE);
			teleportList.Erase(0);
		} else { teleportList.Clear(); }
		return;
	} 
	else if (teleportList.Length <= 0)
	{
		g_bHasRecordTeleportFindPosTime = false;
		preferredSpawnDirection = SPAWN_ANYWHERE;
	}
	// 有生还者被控，则立即刷新需要延迟刷新的特感
	if (delaySpawnList.Length > 0 && IsValidSurvivor(pinnedTarget))
	{
		if (getNowInfectedCount() >= g_hInfectedLimit.IntValue)
		{
			delete g_hDelaySpawnTimer;
			delaySpawnList.Clear();
			return;
		}
		infectedType = delaySpawnList.Get(0);
		if (spawnPosList.Length > 0)
		{
			posIndex = getRandomIntInRange(0, spawnPosList.Length - 1);
			spawnPosList.GetArray(posIndex, spawnPos, 3);
			spawnPos[2] += (VISIBLE_HEIGHT - NAV_HEIGHT);
			if (canBeVisibleBySurvivor(spawnPos)) { spawnPosList.Erase(posIndex); }
			else
			{
				#if DEBUG_ALL
					PrintToConsoleAll("[INF]：有生还者被控并使用射线找到位置，刷新一只延迟刷新的特感 %s，当前 %s 数量 %d", infectedName[infectedType], infectedName[infectedType], ++infectedOnSoptArray[infectedType]);
				#endif
				L4D2_SpawnSpecial(infectedType, spawnPos, INFECTED_SPAWN_EYE_ANGLE);
				spawnPosList.Erase(posIndex);
				delaySpawnList.Erase(0);
			}
		}
		else
		{
			#if DEBUG_ALL
				PrintToConsoleAll("[INF]：有生还者被控并使用函数找到位置，刷新一只延迟刷新的特感 %s，当前 %s 数量 %d", infectedName[infectedType], infectedName[infectedType], ++infectedOnSoptArray[infectedType]);
			#endif
			getInfectedSpawnPosUsingFunction(infectedType, pinnedTarget, spawnPos);
			L4D2_SpawnSpecial(infectedType, spawnPos, INFECTED_SPAWN_EYE_ANGLE);
			delaySpawnList.Erase(0);
		}
		return;
	}
	// 找位完成，对位置进行排序
	if ((spawnPosList.Length >= g_hFindPosLimit.IntValue || g_bExceedFindPosTime || (g_hAllowEasyMode.BoolValue && g_bCanEasyModeSpawn)) && !g_bPosHasSorted)
	{
		if (!g_bIsFirstWave && g_bGeneratedFirstWave || g_hAllowEasyMode.BoolValue) { generateAWaveInfected(); }
		customSortPos();
		g_bCanFindPos = false;
		g_bPosHasSorted = g_bCanSpawn = true;
		#if DEBUG_ALL
			PrintToConsoleAll("---------- [INF]：第：%d 波刷特找位完成，共：%d 个位置，用时：%.2f 秒 ----------", spawnCount, spawnPosList.Length, calculateFindPosTime());
		#endif
	}
	// 正常刷新特感
	if (g_bHasLeftSafeArea && g_bCanSpawn && g_bPosHasSorted && spawnList.Length > 0)
	{
		posInfectedLimit = getOnePosInfecetdLimit();
		infectedType = spawnList.Get(0, 0);
		// 当前特感需要延迟刷新
		if (g_hAllowDelaySpawn.BoolValue && g_hDelaySpawnTime.FloatValue < g_hInfectedSpawnInterval.FloatValue && g_bDelaySpawnInfected[infectedType])
		{
			#if DEBUG_ALL
				PrintToConsoleAll("[INF]：将特感：%s 加入到延迟刷新集合中", infectedName[infectedType]);
			#endif
			delaySpawnList.Push(infectedType);
			spawnList.Erase(0);
			return;
		}
		// 当前特感不需要延迟刷新
		if (spawnPosList.Length > 0)
		{
			spawnPosList.GetArray(0, spawnPos, 3);
			spawnPos[2] += (VISIBLE_HEIGHT - NAV_HEIGHT);
			if (canBeVisibleBySurvivor(spawnPos)) { spawnPosList.Erase(0); }
			else
			{
				while (spawnList.Length > 0 && posInfectedLimit-- > 0)
				{
					#if DEBUG_ALL
						PrintToConsoleAll("[INF]：目前非第一波特感刷新且位置集合中有位置，刷新一只 %s，当前 %s 数量 %d", infectedName[spawnList.Get(0, 0)], infectedName[spawnList.Get(0, 0)], ++infectedOnSoptArray[spawnList.Get(0, 0)]);
					#endif
					L4D2_SpawnSpecial(spawnList.Get(0, 0), spawnPos, INFECTED_SPAWN_EYE_ANGLE);
					spawnList.Erase(0);
				}
				spawnPosList.Erase(0);
			}
		}
		else
		{
			while (spawnList.Length > 0 && posInfectedLimit-- > 0)
			{
				infectedType = spawnList.Get(0);
				#if DEBUG_ALL
					PrintToConsoleAll("[INF]：目前非第一波特感刷新且使用函数找到位置，刷新一只 %s，当前 %s 数量 %d", infectedName[infectedType], infectedName[infectedType], ++infectedOnSoptArray[infectedType]);
				#endif
				getInfectedSpawnPosUsingFunction(infectedType, targetSurvivor, spawnPos);
				L4D2_SpawnSpecial(infectedType, spawnPos, INFECTED_SPAWN_EYE_ANGLE);
				spawnList.Erase(0);
			}
		}
		return;
	}
	// 一波特感刷新完成，重置状态
	if (g_bHasLeftSafeArea && spawnList.Length <= 0)
	{
		expandFrame = 0;
		g_bCanSpawn = g_bCanEasyModeSpawn = g_bIsFirstWave = g_bPosHasSorted = g_bExceedFindPosTime = g_bHasRecordTime = false;
		if (delaySpawnList.Length <= 0 && spawnPosList.Length > 0)
		{
			delete g_hDelaySpawnTimer;
			spawnPosList.Clear();
		}
		if (delaySpawnList.Length > 0 && g_hDelaySpawnTimer == null)
		{
			delete g_hDelaySpawnTimer;
			g_hDelaySpawnTimer = CreateTimer(g_hDelaySpawnTime.FloatValue, delaySpawnHandler, _);
		}
	}
}

bool findSpawnPosRayFilter(int entity, int mask, any self)
{
	// Filter self and players
	if (entity == self || entity >= 1 && entity <= MaxClients) { return false; }
	// Filter infected，witch，prop_physics，tank_rock
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) { return false; }
	char className[64] = {'\0'};
	GetEntityClassname(entity, className, sizeof(className));
	if ((className[0] == 'i' && strcmp(className, "infected") == 0) || 
		(className[0] == 'w' && strcmp(className, "witch") == 0) || 
		(className[0] == 'p' && strcmp(className, "prop_physics") == 0) || 
		(className[0] == 't' && strcmp(className, "tank_rock") == 0)) { return false; }
	if ((className[0] == 'e' && strcmp(className, "env_physics_blocker") == 0) && GetEntProp(entity, Prop_Send, "m_nBlockType") == 1) { return false; }
	return true;
}

// 对位置集合进行自定义排序，高度小于 HEIG_POS_HEIGHT 则按距离降序排序
void customSortPos()
{
	static float spawnPos[3];
	if (spawnPosList.Length <= 1) { return; }
	switch(g_hSpawnStratergy.IntValue)
	{
		case SPAWN_BY_DISTANCE: { spawnPosList.SortCustom(spawnPosSortByDist); }
		case SPAWN_BY_HEIGHT:
		{
			spawnPosList.SortCustom(spawnPosSortByHeight);
			spawnPosList.GetArray(0, spawnPos, 3);
			if (spawnPos[2] < 0.0) { return; }
			if (spawnPos[2] < HEIG_POS_HEIGHT) {
			spawnPosList.SortCustom(spawnPosSortByHeightAfterByDist); }
		}
	}
}
// typedef SortFuncADTArray = function int(int index1, int index2, Handle array, Handle hndl)
// 自定义比较规则，ArrayList 继承于 Handle，强转，否则无法使用 Get 方法，降序排序 o1 > o2 ? -1 : o1 == o2 : 0 ? 1
int spawnPosSortByHeight(int index1, int index2, ArrayList array, Handle hndl)
{
	if (array == null) { return -1; }
	return array.Get(index1, 3) > array.Get(index2, 3) ? -1 : array.Get(index1, 3) == array.Get(index2, 3) ? 0 : 1;
}
int spawnPosSortByDist(int index1, int index2, ArrayList array, Handle hndl)
{
	if (array == null) { return -1; }
	return FloatCompare(array.Get(index1, 3), array.Get(index2, 3));
}
int spawnPosSortByHeightAfterByDist(int index1, int index2, ArrayList array, Handle hndl)
{
	if (array == null) { return -1; }
	return FloatCompare(array.Get(index1, 4), array.Get(index2, 4));
}

// 查询是否有需要处死传送的特感与跑男玩家
public Action checkPinnedAndTeleportHandler(Handle timer)
{
	static int i, j, infectedType;
	static float nowFlow, targetPos[3], infectedEyePos[3];
	static ArrayList survivorFlow;
	survivorFlow = new ArrayList(2);
	bool hasPinned = false, canBeTeleport = false;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsClientIncapped(i)) { continue; }
		if (GetClientTeam(i) == TEAM_SURVIVOR)
		{
			// 被控目标检测
			if (IsClientPinned(i))
			{
				hasPinned = true;
				pinnedTarget = i;
			}
			nowFlow = L4D2Direct_GetFlowDistance(i);
			if (nowFlow && nowFlow != -9999.0) { survivorFlow.Set(survivorFlow.Push(nowFlow), i, 1); }
		}
		else if (GetClientTeam(i) == TEAM_INFECTED && !IsPinningSurvivor(i))
		{
			infectedType = GetEntProp(i, Prop_Send, "m_zombieClass");
			if (infectedType < ZC_SMOKER || infectedType > ZC_CHARGER) { continue; }
			// 可视检测，若当前特感可视，则不可传送
			if (GetEntProp(i, Prop_Send, "m_hasVisibleThreats"))
			{
				if (preTeleportCount[i] > 0) { preTeleportCount[i] = 0; }
				continue;
			}
			canBeTeleport = false;
			GetClientEyePosition(i, infectedEyePos);
			for (j = 1; j <= MaxClients; j++)
			{
				if (i == j || !IsClientInGame(j) || !IsFakeClient(i) || !IsPlayerAlive(j)) { continue; }
				// 与某一生还距离大于规定距离，允许传送
				GetClientEyePosition(j, targetPos);
				if (GetVectorDistance(infectedEyePos, targetPos) > g_hTeleportDist.FloatValue)
				{
					canBeTeleport = true;
					break;
				}
			}
			if (canBeTeleport)
			{
				if (preTeleportCount[i] <= g_hPreTeleportCount.IntValue) { preTeleportCount[i]++; }
				else if (!IsClientInKickQueue(i))
				{
					#if DEBUG_ALL
						PrintToConsoleAll("[INF]：踢出落后感染者：%N", i);
					#endif
					preTeleportCount[i] = 0;
					--infectedOnSoptArray[infectedType];
					KickClientEx(i, "踢出落后感染者并重新刷新");
					teleportList.Push(GetEntProp(i, Prop_Send, "m_zombieClass"));
					g_bCanTeleportFindPos = true;
				}
			}
			else { preTeleportCount[i] = 0; }
		}
	}
	// 跑男检测，最前方生还者距离超过最后方生还者距离 g_hAheadTargetDist 视为跑男
	if (survivorFlow.Length <= 0) { aheadTarget = -1; }
	else
	{
		survivorFlow.Sort(Sort_Descending, Sort_Float);
		if (survivorFlow.Length >= 2)
		{
			nowFlow = survivorFlow.Get(0, 0);
			static float lastFlow;
			lastFlow = survivorFlow.Get(survivorFlow.Length - 1, 0);
			if (nowFlow - lastFlow > g_hAheadTargetDist.FloatValue) { aheadTarget = survivorFlow.Get(0, 1); }
			else { aheadTarget = -1; }
		}
	}
	delete survivorFlow;
	pinnedTarget = hasPinned ? pinnedTarget : -1;
	return Plugin_Continue;
}

public Action delaySpawnHandler(Handle timer)
{
	if (delaySpawnList.Length <= 0)
	{
		g_hDelaySpawnTimer = null;
		return Plugin_Stop;
	}
	// 规定时间后，如特感延迟刷新队列中仍有特感未刷出，则使用函数找位并刷出
	static int posIndex, posInfectedLimit;
	static float spawnPos[3];
	while (delaySpawnList.Length > 0)
	{
		posInfectedLimit = getOnePosInfecetdLimit();
		if (spawnPosList.Length > 0)
		{
			posIndex = getRandomIntInRange(0, spawnPosList.Length - 1);
			spawnPosList.GetArray(posIndex, spawnPos, 3);
			spawnPos[2] += (VISIBLE_HEIGHT - NAV_HEIGHT);
			if (canBeVisibleBySurvivor(spawnPos)) { spawnPosList.Erase(posIndex); }
			else
			{
				#if DEBUG_ALL
					PrintToConsoleAll("[INF]：使用位置集合中的位置刷新一只延迟刷新的特感 %s，当前 %s 数量 %d", infectedName[delaySpawnList.Get(0)], infectedName[delaySpawnList.Get(0)], ++infectedOnSoptArray[delaySpawnList.Get(0)]);
				#endif
				L4D2_SpawnSpecial(delaySpawnList.Get(0), spawnPos, INFECTED_SPAWN_EYE_ANGLE);
				delaySpawnList.Erase(0);
				spawnPosList.Erase(posIndex);
			}
		}
		else
		{
			getInfectedSpawnPosUsingFunction(delaySpawnList.Get(0), targetSurvivor, spawnPos);
			while (delaySpawnList.Length > 0 && posInfectedLimit-- > 0)
			{
				#if DEBUG_ALL
					PrintToConsoleAll("[INF]：使用函数刷新一只需要延迟刷新的特感 %s，当前 %s 数量 %d", infectedName[delaySpawnList.Get(0)], infectedName[delaySpawnList.Get(0)], ++infectedOnSoptArray[delaySpawnList.Get(0)]);
				#endif
				L4D2_SpawnSpecial(delaySpawnList.Get(0), spawnPos, INFECTED_SPAWN_EYE_ANGLE);
				delaySpawnList.Erase(0);
			}
		}
	}
	if (spawnPosList.Length > 0) { spawnPosList.Clear(); }
	g_hDelaySpawnTimer = null;
	return Plugin_Stop;
}

// **********
//	  Stuff
// **********
public Action spawnInfectedHandler(Handle timer)
{
	#if DEBUG_ALL
		PrintToConsoleAll("[INF]：开始第：%d 波特感刷新找位", ++spawnCount);
	#endif
	g_bCanFindPos = g_bCanEasyModeSpawn = true;
	return Plugin_Continue;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (!IsValidSurvivor(client)) { return Plugin_Continue; }
	// 刷新第一波特感
	#if DEBUG_ALL
		PrintToConsoleAll("[INF]：第一个生还者：%N 离开安全区域，开始刷新第一波特感", client);
	#endif
	g_bHasLeftSafeArea = g_bCanFindPos = g_bIsFirstWave = true;
	g_bGeneratedFirstWave = false;
	delete g_hFindPosTimer;
	delete g_hPinnedAndTeleportTimer;
	float interval = g_hInfectedSpawnInterval.FloatValue > 9.0 ? g_hInfectedSpawnInterval.FloatValue + g_hGt9AddTime.FloatValue : g_hInfectedSpawnInterval.FloatValue + g_hLt9AddTime.FloatValue;
	g_hFindPosTimer = CreateTimer(interval, spawnInfectedHandler, _, TIMER_REPEAT);
	g_hPinnedAndTeleportTimer = CreateTimer(CHECK_PINNED_AND_TELEPORT_INTERVAL, checkPinnedAndTeleportHandler, _, TIMER_REPEAT);
	return Plugin_Continue;
}

// **********
//	  方法
// **********

// 记录找位时间
float calculateFindPosTime()
{
	if (g_bCanFindPos && !g_bHasRecordTime)
	{
		g_fFindPosStartTime = GetGameTime();
		g_bHasRecordTime = true;
	}
	return GetGameTime() - g_fFindPosStartTime;
}

// 记录传送找位时间
float calculateTeleportFindPosTime()
{
	if (!g_bHasRecordTeleportFindPosTime && teleportList.Length > 0)
	{
		g_fTeleportFindPosStartTime = GetGameTime();
		g_bHasRecordTeleportFindPosTime = true;
	}
	return GetGameTime() - g_fTeleportFindPosStartTime;
}

void setDirectorCvars(bool set)
{
	if (set)
	{
		FindConVar("director_no_specials").SetInt(1);
		FindConVar("z_safe_spawn_range").SetInt(1);
		FindConVar("z_spawn_safety_range").SetInt(1);
		FindConVar("z_finale_spawn_safety_range").SetInt(1);
		FindConVar("z_finale_spawn_tank_safety_range").SetInt(1);
		return;
	}
	FindConVar("director_no_specials").RestoreDefault();
	FindConVar("z_safe_spawn_range").RestoreDefault();
	FindConVar("z_spawn_safety_range").RestoreDefault();
	FindConVar("z_finale_spawn_safety_range").RestoreDefault();
	FindConVar("z_finale_spawn_tank_safety_range").RestoreDefault();
}

// 为感染者数量数组赋值
// @ infectedCountArray：感染者数组
void getInfectedCountArray()
{
	infectedCountArray[ZC_SMOKER] = g_hSmokerCount.IntValue;
	infectedCountArray[ZC_BOOMER] = g_hBoomerCount.IntValue;
	infectedCountArray[ZC_HUNTER] = g_hHunterCount.IntValue;
	infectedCountArray[ZC_SPITTER] = g_hSpitterCount.IntValue;
	infectedCountArray[ZC_JOCKEY] = g_hJockeyCount.IntValue;
	infectedCountArray[ZC_CHARGER] = g_hChargerCount.IntValue;
}

stock void clearInfectedOnSpotArray()
{
	for (int i = 0; i < 7; i++) { infectedOnSoptArray[i] = 0; }
}

// 感染者限制 Cvar 发生变动，重新调整感染者限制 Cvar
public void infectedLimitCvarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	CreateTimer(0.1, setMaxPlayerInfectedHandler, _);
}

// 感染者数量 Cvar 发生变动，重新获取感染者数组
public void infectedCountCvarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	getInfectedCountArray();
}

// 简单模式 Cvar 发生变动，设置导演系统刷出特感 Cvar
public void easyModeCvarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue)) { setDirectorCvars(false); }
	else
	{
		if (g_bHasLeftSafeArea)
		{
			g_bGeneratedFirstWave = true;
			g_bIsFirstWave = g_bCanTeleportFindPos = false;
		}
		setDirectorCvars(true);
	}
}

// 返回特感数量数组中对应特感的数量
// @ infectedCount：要获取数量的感染者编号
stock int getInfectedCount(int infectedCount)
{
	return isValidInfectedCount(infectedCount) ? infectedCountArray[infectedCount] : -1;
}

// 是否是有效的感染者编号
// @ infectedCount：要判断是否有效的感染者编号
bool isValidInfectedCount(int infectedCount)
{
	if (infectedCount >= ZC_SMOKER && infectedCount <= ZC_CHARGER) { return true; }
	if (g_hEnableLog.BoolValue) { LogMessage("[Infected-Control]：特感编号：%d 无效", infectedCount); }
	return false;
}

// 检查是否有效的刷新位置
// @ rayEndPos：找位射线撞击的位置
// @ targetSurvivorPos：需要检测是否可见的目标生还者位置
bool checkIfSpawnPosValid(float rayEndPos[3], float visiblePos[3], float targetSurvivorPos[3])
{
	static float navDist;
	navDist = L4D2_NavAreaTravelDistance(rayEndPos, targetSurvivorPos, false);
	if (!g_hAllowSpawnInSafeArea.BoolValue)
	{
		static Address rayEndNav;
		rayEndNav = L4D2Direct_GetTerrorNavArea(rayEndPos);
		rayEndNav = rayEndNav == Address_Null ? L4D_GetNearestNavArea(rayEndPos) : rayEndNav;
		return
			!canBeVisibleBySurvivor(visiblePos) &&
			isOnValidMesh(rayEndPos) &&
			GetVectorDistance(rayEndPos, targetSurvivorPos) >= g_hMinSpawnDist.FloatValue &&
			navDist <= g_hMaxSpawnDist.FloatValue * 2.0 &&
			!isPlayerWillStuck(rayEndPos) &&
			L4D_GetNavArea_SpawnAttributes(rayEndNav) % CHECKPOINT != 0;
	}
	return
		!canBeVisibleBySurvivor(visiblePos) &&
		isOnValidMesh(rayEndPos) &&
		GetVectorDistance(rayEndPos, targetSurvivorPos) >= g_hMinSpawnDist.FloatValue &&
		navDist <= g_hMaxSpawnDist.FloatValue * 2.0 &&
		!isPlayerWillStuck(rayEndPos);
}

// 通过 Cvar 获取感染者在队列中刷新位置到数组中
void getInfectedInQueuePos()
{
	char cvarString[64] = {'\0'}, minAndMaxString[2][16];
	for (int i = 0; i < ZC_CHARGER; i++)
	{
		g_hInfectedInQueuePos[i].GetString(cvarString, sizeof(cvarString));
		ExplodeString(cvarString, ",", minAndMaxString, 2, 16);
		for (int j = 0; j < 2; j++)
		{
			infectedInQueuePos[i][0] = isStringInRange(minAndMaxString[0], 0, 100) ? StringToInt(minAndMaxString[0]) : 0;
			infectedInQueuePos[i][1] = isStringInRange(minAndMaxString[1], 0, 100) ? StringToInt(minAndMaxString[1]) : 100;
		}
	}
}

// 清空所有客户端的 preTeleportCount 次数
void clearPreTeleportCount()
{
	for (int i = 1; i < MaxClients; i++) { preTeleportCount[i] = 0; }
}

// 获取目标生还者
// @excludeClient 需要排除的生还者客户端索引
void getTargetSurvivor(int &target)
{
	if (!IsValidSurvivor(target)) { target = GetRandomMobileSurvivor(); }
	else if (IsValidSurvivor(aheadTarget)) { target = aheadTarget; }
	else if (targetFrame++ > g_hEveryTargetFrame.IntValue)
	{
		target = GetRandomMobileSurvivor(target);
		targetFrame = 0;
	}
}

// 判断整数字符串是否包含在 min - max 范围中
// @str 需要判断的整数字符串
// @min 最小值
// @max 最大值
bool isStringInRange(const char[] str, int min, int max)
{
	int strInt = StringToInt(str);
	return strInt >= min && strInt <= max;
}

// 判断给定整数是否包含在 min - max 范围中
// @digit 需要判断的整数
// @min 最小值
// @max 最大值
bool isIntegerInRange(int digit, int min, int max)
{
	return digit >= min && digit <= max;
}

// 获取每个刷新位置配置的最多能刷新的特感数量
int getOnePosInfecetdLimit()
{
	if (g_hAllowPosRadomInfectedLimit.BoolValue) { return getRandomIntInRange(1, spawnList.Length); }
	else { return g_hOnePosInfectedLimit.IntValue; }
}

// 获取目前在场的特感数量
int getNowInfectedCount()
{
	static int i, infectedType, count;
	count = 0;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || IsClientInKickQueue(i)) { continue; }
		if (IsPlayerAlive(i))
		{
			infectedType = GetEntProp(i, Prop_Send, "m_zombieClass");
			if (infectedType < ZC_SMOKER || infectedType > ZC_CHARGER) { continue; }
			count++;
		}
		else if (IsFakeClient(i)) { KickClientEx(i, "踢出死亡感染者"); }
	}
	return count;
}

// 获取一个特感队列
static void generateAWaveInfected()
{
	static int i, j, min, max, infectedType, infectedIndex;
	static ArrayList allowInfectedList;
	allowInfectedList = new ArrayList(2);
	getInfectedCountArray();
	for (i = 0; i < g_hInfectedLimit.IntValue; i++)
	{
		// 每个刷新位置循环 6 种特感，允许刷新加入 allowInfectedList 中，随机一个填充刷新位置，无配置任何特感则随机选择
		for (j = 0; j < ZC_CHARGER; j++)
		{
			min = RoundToFloor(g_hInfectedLimit.FloatValue * (float(infectedInQueuePos[j][0]) * 0.01)), 
			max = RoundToFloor(g_hInfectedLimit.FloatValue * (float(infectedInQueuePos[j][1]) * 0.01));
			if (isIntegerInRange(spawnList.Length + 1, min, max) && infectedCountArray[j + 1] > 0) { 
			allowInfectedList.Set(allowInfectedList.Push(j + 1), 0, 1); }
		}
		if (allowInfectedList.Length > 0)
		{
			infectedType = allowInfectedList.Get(getRandomIntInRange(0, allowInfectedList.Length - 1), 0);
			spawnList.Set(spawnList.Push(infectedType), 0, 1);
			infectedCountArray[infectedType]--;
			allowInfectedList.Clear();
		}
		else { spawnList.Set(spawnList.Push(getRandomIntInRange(ZC_SMOKER, ZC_CHARGER)), 0, 1); }
	}
	// 特感刷新队列生成完毕，如当前最大特感数量在 ALL_SPAWN_ONE_THERSHOLD 以上，检查是否每种特感有一只，如无则获取对应特感设置位置，使用线性探查法找到其位置
	if (g_hInfectedLimit.IntValue > ALL_SPAWN_ONE_THERSHOLD && g_hAllowAllSpawnOne.BoolValue)
	{
		for (i = ZC_SMOKER; i <= ZC_CHARGER; i++)
		{
			if (spawnList.FindValue(i)) { continue; }
			infectedIndex = RoundToFloor(g_hInfectedLimit.IntValue * (infectedInQueuePos[i][0] * 0.01));
			while (spawnList.Get(infectedIndex, 1) > 0)
			{
				if (infectedIndex >= spawnList.Length) { infectedIndex = infectedIndex % spawnList.Length; }
				infectedIndex++;
			}
			spawnList.Set(infectedIndex, i);
		}
	}
	delete allowInfectedList;
	// 循环在场的特感，刷新集合或传送集合中有同种类型的，移除，没有则判断是否强控或 DPS，刷新集合中移除对应类型特感
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsValidInfected(i) || !IsPlayerAlive(i)) { continue; }
		infectedType = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (infectedType < ZC_SMOKER || infectedType > ZC_CHARGER) { continue; }
		infectedIndex = spawnList.FindValue(infectedType);
		findAndEraseInfected(infectedType, infectedIndex);
	}
	// 在传送集合中找到了这个特感，将刷新集合中的特感移除，没有则判断类型移除刷新集合中对应的特感
	for (i = 0; i < teleportList.Length; i++)
	{
		infectedType = teleportList.Get(i, 0);
		infectedIndex = spawnList.FindValue(infectedType);
		findAndEraseInfected(infectedType, infectedIndex);
	}
	#if DEBUG_ALL
		for (i = 0; i < spawnList.Length; i++) { PrintToConsoleAll("[INF]：向刷新队列中加入一只：%s，当前刷新位置：%d", infectedName[spawnList.Get(i, 0)], i + 1); }
	#endif
}

void findAndEraseInfected(int infectedType, int infectedIndex)
{
	static int i;
	if (infectedIndex > -1)
	{
		spawnList.Erase(infectedIndex);
		return;
	}
	switch (infectedType)
	{
		case ZC_SMOKER, ZC_HUNTER, ZC_JOCKEY, ZC_CHARGER:
		{
			for (i = ZC_SMOKER; i <= ZC_CHARGER; i++)
			{
				if (i == ZC_BOOMER || i == ZC_SPITTER) { continue; }
				infectedIndex = spawnList.FindValue(i);
				if (infectedIndex > -1)
				{
					spawnList.Erase(infectedIndex);
					break;
				}
			}
		}
		case ZC_BOOMER, ZC_SPITTER:
		{
			for (i = ZC_BOOMER; i <= ZC_SPITTER; i++)
			{
				if (i == ZC_HUNTER) { continue; }
				infectedIndex = spawnList.FindValue(i);
				if (infectedIndex > -1)
				{
					spawnList.Erase(infectedIndex);
					break;
				}
			}
		}
	}
}

// 调整 PreferredSpecialDirection
// @key：需要调整的 key 值
// @retVal：原 value 值，使用 return Plugin_Handled 覆盖
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if (strcmp(key, "MaxSpecials", false) == 0 && retVal != g_hInfectedLimit.IntValue)
	{
		retVal = g_hInfectedLimit.IntValue;
		return Plugin_Handled;
	}
	if ((strcmp(key, "cm_ShouldHurry", false) == 0) || (strcmp(key, "cm_AggressiveSpecials", false) == 0) || (strcmp(key, "ActiveChallenge", false) == 0) && retVal != 1)
	{
		retVal == 1;
		return Plugin_Handled;
	}
	if (strcmp(key, "PreferredSpecialDirection", false) == 0 && retVal != preferredSpawnDirection)
	{
		retVal = preferredSpawnDirection;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// 判断某个坐标是否在有效 NavArea 上
// @pos 需要判断的坐标
bool isOnValidMesh(float pos[3])
{
	return L4D2Direct_GetTerrorNavArea(pos) != Address_Null;
}

// 当前位置是否对生还者可见
// @pos：需要判断的坐标
bool canBeVisibleBySurvivor(float pos[3])
{
	static int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
		if (L4D2_IsVisibleToPlayer(i, TEAM_SURVIVOR, TEAM_INFECTED, 0, pos)) { return true; }
	}
	return false;
}

// 使用找位函数获取一个特感刷新位置
// @infectedType 需要找位的特感类型
// @target 目标生还者
// @spawnPos 刷新位置
void getInfectedSpawnPosUsingFunction(int infectedType, int target, float spawnPos[3])
{
	if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) { return; }
	static int i;
	static float targetPos[3];
	static ArrayList posList;
	posList = new ArrayList(4);
	GetClientAbsOrigin(target, targetPos);
	for (i = 0; i < DEFAULT_FIND_POS_ATTEMPT; i++)
	{
		L4D_GetRandomPZSpawnPosition(target, infectedType, DEFAULT_FIND_POS_ATTEMPT, spawnPos);
		posList.Set(posList.PushArray(spawnPos), RoundToNearest(GetVectorDistance(spawnPos, targetPos)), 3);
	}
	if (posList.Length > 0)
	{
		posList.SortCustom(spawnPosSortByDist);
		posList.GetArray(0, spawnPos);
	}
	delete posList;
}

// 检测某种特感是否会在某个坐标卡住
// @pos：需要检测的坐标
bool isPlayerWillStuck(float pos[3])
{
	Handle trace = TR_TraceHullFilterEx(pos, pos, STUCK_SIZE_MIN, STUCK_SIZE_MAX, MASK_NPCSOLID_BRUSHONLY, isPlayerWillStuckRayFilter, _);
	if (TR_DidHit(trace))
	{
		delete trace;
		return true;
	}
	delete trace;
	return false;
}
bool isPlayerWillStuckRayFilter(int entity, int contentMask, any self)
{
	// Filter self and players
	if (entity == self || (entity >= 1 && entity <= MaxClients)) { return false; }
	// Filter infected，witch，prop_physics，tank_rock
	char className[64] = {'\0'};
	GetEntityClassname(entity, className, sizeof(className));
	if ((className[0] == 'i' && strcmp(className, "infected") == 0) || 
		(className[0] == 'w' && strcmp(className, "witch") == 0) || 
		(className[0] == 'p' && strcmp(className, "prop_physics") == 0) || 
		(className[0] == 't' && strcmp(className, "tank_rock") == 0)) { return false; }
	// 过滤 SolidType 为 1 的空气墙
	if ((className[0] == 'e' && strcmp(className, "env_physics_blocker") == 0) && GetEntProp(entity, Prop_Send, "m_nBlockType") == 1) { return false; }
	if (GetEntProp(entity, Prop_Send, "m_nSolidType") == 1) { return false; }
	return true;
}

// 计算可以发射找位射线的范围
// @minPos 最小范围坐标
// @maxPos 最大范围坐标
// @targetSurvivorPos 目标生还者坐标
void generateRayMinAndMaxPos(float minPos[3], float maxPos[3], float targetSurvivorPos[3])
{
	if (expandFrame > g_hExpandFrame.IntValue)
	{
		static float offset, different;
		offset = float(expandFrame - g_hExpandFrame.IntValue);
		different = offset > (g_hMaxSpawnDist.FloatValue * 3.0) ? g_hMaxSpawnDist.FloatValue * 3.0 : offset;
		minPos[0] = targetSurvivorPos[0] - g_hMaxSpawnDist.FloatValue - different;
		maxPos[0] = targetSurvivorPos[0] + g_hMaxSpawnDist.FloatValue + different;
		minPos[1] = targetSurvivorPos[1] - g_hMaxSpawnDist.FloatValue - different;
		maxPos[1] = targetSurvivorPos[1] + g_hMaxSpawnDist.FloatValue + different;
		maxPos[2] = targetSurvivorPos[2] + g_hMaxSpawnDist.FloatValue;
		return;
	}
	minPos[0] = targetSurvivorPos[0] - g_hMaxSpawnDist.FloatValue;
	maxPos[0] = targetSurvivorPos[0] + g_hMaxSpawnDist.FloatValue;
	minPos[1] = targetSurvivorPos[1] - g_hMaxSpawnDist.FloatValue;
	maxPos[1] = targetSurvivorPos[1] + g_hMaxSpawnDist.FloatValue;
	maxPos[2] = targetSurvivorPos[2] + g_hMaxSpawnDist.FloatValue;
}

// 获取需要延迟刷新的特感的数组
void getDelaySpawnInfected()
{
	char cvarString[64] = {'\0'}, delaySpawnArray[6][4];
	g_hDelaySpawnInfected.GetString(cvarString, sizeof(cvarString));
	ExplodeString(cvarString, ",", delaySpawnArray, 6, 4);
	for (int i = 0; i < ZC_CHARGER; i++)
	{
		if (delaySpawnArray[i][0] != '\0') { g_bDelaySpawnInfected[StringToInt(delaySpawnArray[i])] = true; }
	}
}

// 获取 min - max 的随机整数
// @min 最小范围
// @max 最大范围
int getRandomIntInRange(int min, int max)
{
	int random = GetURandomInt();
	if (random == 0) { random++; }
	return RoundToCeil(float(random) / (float(INTEGER_MAX_VALUE) / float(max - min + 1))) + min - 1;
}

// 获取 min - max 的随机浮点数
// @min 最小范围
// @max 最大范围
float getRandomFloatInRange(float min, float max)
{
	return GetURandomFloat() * (max - min) + min;
}