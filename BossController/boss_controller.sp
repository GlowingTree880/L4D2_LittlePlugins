#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <builtinvotes>

#include <treeutil>
#include <logger>

#undef REQUIRE_PLUGIN
#include <readyup>

#define CVAR_FLAG FCVAR_NOTIFY
// 非对抗模式下使用 L4D_GetRandomPZSpawnPosition() 函数刷新 Boss 的找位次数
#define SPAWN_ATTEMPT 15
// 生还者完成路程检测时钟周期
#define SURVIVOR_DIST_CHECK_INTERVAL 0.5
// 投票展示时间
#define VOTE_DISPLAY_TIME 20
// 插件前缀
#define PLUGIN_PREFIX "[BossController]"

public Plugin myinfo = 
{
	name 			= "Boss Controller",
	author 			= "CanadaRox, Sir, devilesk, Derpduck, Forgetest, Spoon, 夜羽真白",
	description 	= "整合 witch_and_tankifier 与 boss_percent 与 boss_vote 的插件，战役或对抗 / 有无 mapInfo.txt 文件都允许在固定路程刷新 boss",
	version 		= "2023-08-10",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar
	g_hTankCanSpawn,
	g_hWitchCanSpawn,
	g_hWitchAvoidTank,
	g_hPromptDist,
	g_hCanVoteBoss,
	g_hProhibitNonPluginBoss,
	g_hDisableInFinale,
	g_hMapInfoPath,
	g_hLogLevel;

ConVar
	game_directorNoBosses,
	game_vsBossBuffer,
	game_bossFlowMin,
	game_bossFlowMax;

ConVar
	// 非对抗模式下刷新 Boss 距离目标生还者最小直线距离
	g_hBossMinDistance,
	// 非对抗模式下刷新 Boss 距离目标生还者最小 Nav 距离
	g_hBossMinNavDistance,
	// 使用射线找位获取 Boss 刷新位置时最大用时
	g_hBossFindPosMaxTime;

int
	// Tank 刷新路程
	tankFlow,
	// Witch 刷新路程
	witchFlow;
int
	// Dark Carnival Remix 地图第一局 Tank 刷新路程
	dkrFirstRoundTankPercent,
	// Dark Carnival Remix 地图第一局 Witch 刷新路程
	dkrFirstRoundWitchPercent,
	// ReadyUp 面板 Footer 字符串索引位置
	readyUpFooterIndex,
	// 已经提示过 Boss 刷新位置的路程, 如 57 路程提示过 Boss 刷新位置, 本值为 57
	promptedDistance;

bool
	// MapInfo 文件是否存在
	isMapInfoExist,
	// ReadyUp 插件是否存在
	isReadyUpExist,
	// ReadyUp 面板 Footer 是否已经被添加过
	isReadyUpFooterAdded,
	// Tank 是否在本局已经刷新
	isTankSpawned,
	// Witch 是否在本局已经刷新
	isWitchSpawned,
	// 第一个生还者是否离开安全区域
	isLeftSafeArea;

char
	// MapInfo 文件位置
	mapInfoPath[PLATFORM_MAX_PATH];

Handle
	// 生还者完成路程检测时钟, 用于提示 Boss 即将刷新
	survivorDistCheckTimer,
	// 非对抗模式下实际刷新 Boss 时钟
	bossSpawnTimer;

StringMap
	// 静态 Tank 地图 Map
	staticTankMap,
	// 静态 Witch 地图 Map
	staticWitchMap;

ArrayList
	// Tank 刷新路程集合
	tankPercentList,
	// Witch 刷新路程集合
	witchPercentList;

KeyValues
	// MapInfo 文件 KeyValue
	kvMapInfo;

Logger
	log;

// 其他模块
#include "natives_and_forwards.sp"
#include "commands.sp"
#include "events.sp"
#include "timers.sp"

public void OnPluginStart()
{
	g_hMapInfoPath = CreateConVar("boss_map_info_path", "../../cfg/cfgogl/mapinfo.txt", "MapInfo 文件路径, 相对于 sourcemod 文件夹", CVAR_FLAG);
	g_hTankCanSpawn = CreateConVar("boss_tank_can_spawn", "1", "插件接管 Boss 刷新时是否允许插件生成 Tank [0: 禁止]", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hWitchCanSpawn = CreateConVar("boss_witch_can_spawn", "1", "插件接管 Boss 刷新时是否允许插件生成 Witch [0: 禁止]", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hWitchAvoidTank = CreateConVar("boss_witch_avoid_tank", "20", "Witch 应该距离 Tank 刷新位置多远的路程刷新 [将会以 Tank 刷新位置为中点，左右 / 2 距离，比如 Tank 在 76 路程, Witch 则不能设置在 66-86 的路程]", CVAR_FLAG, true, 0.0, true, 1.0);
	
	g_hPromptDist = CreateConVar("boss_prompt_dist", "5", "在距离 Boss 刷新路程之前多少路程开始提示即将刷新 [0: 不提示]", CVAR_FLAG, true, 0.0);
	g_hProhibitNonPluginBoss = CreateConVar("boss_prohibit_non_plugin", "1", "非对抗模式下是否踢出非本插件刷新的 Boss", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hDisableInFinale = CreateConVar("boss_disable_in_finale", "0", "救援关时是否禁止本插件接管 Boss 刷新 [如 c2m5 等救援关, 本 Cvar 开启则插件不会接管 Boss 刷新]", CVAR_FLAG, true, 0.0, true, 1.0);

	g_hCanVoteBoss = CreateConVar("boss_enable_vote", "1", "是否允许通过 !voteboss 指令投票更改 Tank 和 Witch 刷新位置", CVAR_FLAG, true, 0.0, true, 1.0);

	g_hBossMinDistance = CreateConVar("boss_min_distance", "1000", "非对抗模式下插件刷新 Boss 距离目标生还者的最小直线距离", CVAR_FLAG, true, 0.0);
	g_hBossMinNavDistance = CreateConVar("boss_min_nav_distance", "1000", "非对抗模式下插件刷新 Boss 距离目标生还者的最小 Nav 距离", CVAR_FLAG, true, 0.0);
	g_hBossFindPosMaxTime = CreateConVar("boss_find_pos_max_time", "8.0", "非对抗模式下, 使用函数找位无法获取有效 Boss 刷新位置转为使用射线找位, 射线找位的最大用时", CVAR_FLAG, true, 0.0);

	// 日志记录
	g_hLogLevel = CreateConVar("boss_log_level", "38", "插件日志级别 (1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR) 数字相加 [38 = 2 + 4 + 32]", CVAR_FLAG, true, 1.0);

	// 其他 Cvar
	game_directorNoBosses = FindConVar("director_no_bosses");
	game_vsBossBuffer = FindConVar("versus_boss_buffer");
	game_bossFlowMin = FindConVar("versus_boss_flow_min");
	game_bossFlowMax = FindConVar("versus_boss_flow_max");

	// 静态地图 Map 集合
	staticTankMap = new StringMap();
	staticWitchMap = new StringMap();
	// Boss 刷新路程 List 集合
	tankPercentList = new ArrayList();
	witchPercentList = new ArrayList();

	log = new Logger(g_hLogLevel.IntValue);

	// 其他模块
	// Natives And Forwards
	nativesAndForwardsOnModuleStart();
	// 指令处理模块
	commandsOnModuleStart();
	// 事件处理模块
	eventsOnModuleStart();
}

public void OnAllPluginsLoaded() {
	if (!LibraryExists("left4dhooks")) {
		LogMessage("\n==========\n 本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行 \n==========\n");
		SetFailState("\n==========\n 本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行 \n==========\n");
	}

	isReadyUpExist = LibraryExists("readyup");
}

public void OnLibraryRemoved(const char[] name) {
	if (strcmp(name, "readyup", false) == 0) {
		isReadyUpExist = false;
	}
}

public void OnLibraryAdded(const char[] name) {
	if (strcmp(name, "readyup", false) == 0) {
		isReadyUpExist = true;
	}
}

public void OnMapStart() {
	onMapEndResetState();
}

public void OnMapEnd() {
	onMapEndResetState();
}

/**
* 第一个生还者离开安全区域事件
* @param client 客户端索引
* @return Action
**/
public Action L4D_OnFirstSurvivorLeftSafeArea(int client) {
	// ReadyUp 插件不存在, 直接打印 Boss 刷新路程
	static int i;
	if (!isReadyUpExist) {
		for (i = 1; i <= MaxClients; i++) {
			if (!IsValidClient(i)) {
				continue;
			}
			printBossPercents(i);
		}
		RequestFrame(nextFramePritnCurrent, GetClientUserId(client));
		if (isDarkCarnivalRemix() && !InVersusSecondRound()) {
			dkrFirstRoundTankPercent = tankFlow;
			dkrFirstRoundWitchPercent = witchFlow;
		}
	}

	// 创建生还者完成路程检测时钟
	delete survivorDistCheckTimer;
	if (g_hPromptDist.BoolValue) {
		survivorDistCheckTimer = CreateTimer(SURVIVOR_DIST_CHECK_INTERVAL, timerSurvivorDistanceCheckHandler, _, TIMER_REPEAT);
	}
	delete bossSpawnTimer;
	bossSpawnTimer = CreateTimer(SURVIVOR_DIST_CHECK_INTERVAL, timerSpawnBoss, _, TIMER_REPEAT);

	isLeftSafeArea = true;
	return Plugin_Continue;
}

/**
* 设置 director_no_bosses Cvar
* @param set 新数值
* @return void
**/
void setGameDirectorNoBossesCvar(bool set) {
	if ((!game_directorNoBosses.BoolValue && set) || (game_directorNoBosses.BoolValue && !set)) {
		game_directorNoBosses.SetBool(set);
		log.debugAndInfo("%s: 设置 director_no_bosses 值为 %b", PLUGIN_PREFIX, set);
	}
}

/**
* 在 Tank 位置发生改变时, 动态调整 Witch 位置, 必须先于 Tank 位置改变前调用
* @param newTankFlow 新的 Tank 路程
* @return void
**/
void dynamicAdjustWtichPercent(int newTankFlow) {
	// Witch 不能刷新, 返回
	if (!g_hWitchCanSpawn.BoolValue) {
		return;
	}

	int interval[2];
	static int i, index;
	if (!getTankAvoidInterval(interval)) {
		return;
	}
	if (!isValidInterval(interval[0], interval[1])) {
		return;
	}
	log.debugAndInfo("%s: 旧的 Witch Avoid Tank 路程是 [%d - %d]", PLUGIN_PREFIX, interval[0], interval[1]);
	// 恢复之前的禁止 Witch 刷新路程, 并升序排序
	for (i = interval[0]; i <= interval[1]; i++) {
		// 在当前 Witch 刷新路程集合中没有找到这个路程, 则加入这个路程
		if (witchPercentList.FindValue(i) >= 0) {
			continue;
		}
		witchPercentList.Push(i);
	}
	witchPercentList.Sort(Sort_Ascending, Sort_Integer);
	
	// 计算并应用新的 Witch 禁止刷新路程
	interval[0] = RoundToFloor(newTankFlow - (g_hWitchAvoidTank.FloatValue / 2.0));
	interval[1] = RoundToCeil(newTankFlow + (g_hWitchAvoidTank.FloatValue / 2.0));
	log.debugAndInfo("\n%s: Tank 刷新路程调整至 %d%%, 新的 Witch Avoid Tank 路程是 [%d%% - %d%%]\n", PLUGIN_PREFIX, newTankFlow, interval[0], interval[1]);
	
	for (i = interval[0]; i <= interval[1]; i++) {
		if ((index = witchPercentList.FindValue(i)) < 0) {
			continue;
		}
		witchPercentList.Erase(index);
	}

	// 恢复之前的 Witch Avoid Tank 路程后可能会将 MapInfo 中的 Ban Flow 恢复, 重新获取 MapInfo 中的 Ban Flow
	getAndDeleteBanFlow("witch_ban_flow");
	
	if (witchPercentList.Length <= 1) {
		witchFlow = 0;
		setWitchPercent(0);
		log.info("%s: 动态调整 Witch 刷新范围后 Witch 路程集合长度为 %d, 因此禁止刷新 Witch", PLUGIN_PREFIX, witchPercentList.Length);
	} else {
		if (L4D_IsVersusMode()) {
			witchFlow = RoundFloat(L4D2Direct_GetVSWitchFlowPercent(0) * 100.0);
		}
		// 非对抗模式, witchFlow 不变
		if (witchFlow >= interval[0] && witchFlow <= interval[1]) {
			if (!isWitchPercentValid((witchFlow = interval[1] + 1)) && !isWitchPercentValid((witchFlow = interval[0] - 1))) {
				witchFlow = getRandomIntervalNum(witchPercentList);
				CPrintToChatAll("%t", "MoveToRandomValidWitchFlow", witchFlow);

				log.debugAndInfo("%s: 当前 Witch 刷新路程 %d, 处在 Witch Avoid Tank 路程 [%d - %d] 中, 随机选择一个新的 Witch 路程 %d", PLUGIN_PREFIX, witchFlow, interval[0], interval[1], witchFlow);
			}
		}
		log.info("%s: 动态调整 Witch 刷新路程 %d%%, Witch 路程集合长度 %d", PLUGIN_PREFIX, witchFlow, witchPercentList.Length);
		setWitchPercent(witchFlow);
	}
}

/**
* 根据当前 Tank 路程与 g_hWitchAvoidTank 值得到 Witch 禁止刷新路程 
* @param interval Witch 禁止刷新路程数组
* @return bool
**/
bool getTankAvoidInterval(int interval[2]) {
	if (!g_hWitchAvoidTank.BoolValue){
		return false;
	}

	static float flow;
	if (L4D_IsVersusMode()) {
		flow = L4D2Direct_GetVSTankFlowPercent(0);
	} else {
		flow = tankFlow / 100.0;
	}
	if (flow == 0.0) {
		return false;
	}

	interval[0] = RoundToFloor((flow * 100.0) - (g_hWitchAvoidTank.FloatValue / 2.0));
	interval[1] = RoundToCeil((flow * 100.0) + (g_hWitchAvoidTank.FloatValue / 2.0));
	return true;
}

// Boss 刷新控制
public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3]) {
	return g_hTankCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}
public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3]) {
	return g_hWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}
public Action L4D2_OnSpawnWitchBride(const float vecPos[3], const float vecAng[3]) {
	return g_hWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

/**
* 不额外添加 versus_boss_buffer 计算当前生还者路程
* @param void
* @return int
**/
stock int getSurvivorFlow(){
	static float survivorDistance;
	static int furthestSurvivor;
	furthestSurvivor = L4D_GetHighestFlowSurvivor();
	if (!IsValidSurvivor(furthestSurvivor)) { survivorDistance = L4D2_GetFurthestSurvivorFlow(); }
	else { survivorDistance = L4D2Direct_GetFlowDistance(furthestSurvivor); }
	return RoundToNearest(survivorDistance / L4D2Direct_GetMapMaxFlowDistance() * 100.0);
}

/**
* 使用 ZoneMod 路程计算方法计算当前生还者路程
* @param void
* @return void
**/
stock int getSurvivorFlowZone() {
	static int i;
	float pos[3];
	float flow, temp;
	Address nav;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		GetClientAbsOrigin(i, pos);
		nav = L4D2Direct_GetTerrorNavArea(pos);
		if (nav == Address_Null) {
			continue;
		}
		temp = L4D2Direct_GetTerrorNavAreaFlow(nav);
		flow = (flow > temp) ? flow : temp;
	}
	flow /= L4D2Direct_GetMapMaxFlowDistance();
	flow += (game_vsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance());
	flow = flow > 1.0 ? 1.0 : flow;
	return RoundToNearest(flow * 100.0);
}

// ========== Methods Start ==========
/**
* 检查 MapInfo 文件是否存在
* @param void
* @return void
**/
void checkMapInfoExist() {
	char cvarStr[64];
	g_hMapInfoPath.GetString(cvarStr, sizeof(cvarStr));
	if (strlen(cvarStr) > 0) {
		BuildPath(Path_SM, mapInfoPath, sizeof(mapInfoPath), "%s", cvarStr);
		if (FileExists(mapInfoPath)) {
			isMapInfoExist = true;
			log.debugAndInfo("%s: 已找到 MapInfo 文件, 路径 %s", PLUGIN_PREFIX, mapInfoPath);
			return;
		} else {
			log.debugAndInfo("%s: 未找到 MapInfo 文件, 路径 %s", PLUGIN_PREFIX, mapInfoPath);
		}
	}
	isMapInfoExist = false;
}

// FIXME: 部分地图无法找到 trigger_finale 实体, 如 c5m5
/**
* 判断当前地图是否是救援关, 通过查询是否存在 trigger_finale 实体
* @param void
* @return bool
**/
bool isFinaleMap() {
	static int i;
	static char name[64];
	for (i = MaxClients + 1; i < GetEntityCount(); i++) {
		if (!IsValidEntity(i) || !IsValidEdict(i)) { continue; }
		GetEntityClassname(i, name, sizeof(name));
		if (strcmp(name, "trigger_finale", false) == 0) {
			return true;
		}
	}
	return false;
}

/**
* 判断救援关时是否允许插件接管 Boss 刷新, 条件: 救援关, 非静态地图, Cvar 允许接管 Boss 刷新
* @param void
* @return bool
**/
bool allowSpawnBossInFinale() {
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	return isFinaleMap() && !g_hDisableInFinale.BoolValue && !isStaticTankMap(mapName) && !isStaticWitchMap(mapName);
}

bool allowSpawnTankInNormal() {
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	return !isFinaleMap() && g_hTankCanSpawn.BoolValue && !isStaticTankMap(mapName);
}

bool allowSpawnWitchInNormal() {
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	return !isFinaleMap() && g_hWitchCanSpawn.BoolValue && !isStaticWitchMap(mapName);
}

/**
* 检查一段正常 Flow 或 Ban Flow 是否有效
* @param min 最低路程
* @param max 最高路程
* @return bool
**/
bool isValidInterval(int min, int max) {
	return min > -1 && max >= min;
}

/**
* 创建时钟, 将本局 Tank 与 Witch 路程信息更新到 ReadyUp 面板中
* @param interval 时钟周期
* @return void
**/
void updateReadyUpFooter(float interval = 0.1) {
	static float prevTime = 0.0;
	if (FloatCompare(prevTime, 0.0) == 0) {
		prevTime = GetEngineTime();
	}
	static float newTime;
	newTime = GetEngineTime() + interval;
	if (FloatCompare(newTime, prevTime) < 0) {
		return;
	}

	CreateTimer(interval, timerUpdateReadyUpFooter, _, _);
}

/**
* ReadyUp 插件存在时, 倒计时结束时事件
* @param void
* @return void
**/
public void OnRoundIsLive() {
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i)) {
			continue;
		}
		printBossPercents(i);
	}
	if (isDarkCarnivalRemix() && !InVersusSecondRound()) {
		dkrFirstRoundTankPercent = tankFlow;
		dkrFirstRoundWitchPercent = witchFlow;
	}
}

/**
* 判断当前地图是否是静态 Tank 地图
* @param mapName 当前地图名称
* @return bool
**/
bool isStaticTankMap(const char[] mapName) {
	return staticTankMap.ContainsKey(mapName);
}

/**
* 判断当前地图是否是静态 Witch 地图
* @param mapName 当前地图名称
* @return bool
**/
bool isStaticWitchMap(const char[] mapName) {
	return staticWitchMap.ContainsKey(mapName);
}

/**
* 判断当前地图是否是 Dark Carnival Remix 地图任意一章节
* @param void
* @return bool
**/
bool isDarkCarnivalRemix() {
	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	return strcmp(mapName, "dkr_m1_motel", true) == 0 ||
		strcmp(mapName, "dkr_m2_carnival", true) == 0 ||
		strcmp(mapName, "dkr_m3_tunneloflove", true) == 0 ||
		strcmp(mapName, "dkr_m4_ferris", true) == 0 ||
		strcmp(mapName, "dkr_m5_stadium", true) == 0;
}

/**
* 从一段字符串中找到 % 前的数值并以整数形式返回
* @param input 输入字符串
* @param len 字符串长度
* @return int
**/
int getPercentageFromText(const char[] input, int len) {
	static int index;
	if (len < 1 || (index = StrContains(input, "%", false)) < 0) {
		return -1;
	}

	char buffer[16];
	// 如果在 % 前面 -3 的位置字符是数字, 则这个数字一定是 100%
	if (IsCharNumeric(input[index - 3])) {
		return 100;
	}
	// 否则截取前面两位转换为 int
	if (IsCharNumeric(input[index - 2]) && IsCharNumeric(input[index - 1])) {
		FormatEx(buffer, sizeof(buffer), "%c%c", input[index - 2], input[index - 1]);
		return StringToInt(buffer);
	}
	return -1;
}

/**
* 检查给定路程是否在 Tank 刷新集合中
* @param flow 给定路程
* @return bool
**/
bool isTankPercentValid(int flow)
{
	if (flow == 0) {
		return true;
	}
	if (tankPercentList.Length < 1) {
		return false;
	}
	// 超出范围
	if (flow < tankPercentList.Get(0) || flow > tankPercentList.Get(tankPercentList.Length - 1)) {
		return false;
	}
	// 在 Tank 刷新路程集合中找到了该路程, 返回 true
	return tankPercentList.FindValue(flow) >= 0;
}

/**
* 检查给定路程是否在 Witch 刷新集合中
* @param flow 给定路程
* @return bool
**/
bool isWitchPercentValid(int flow)
{
	if (flow == 0) {
		return true;
	}
	if (witchPercentList.Length < 1) {
		return false;
	}
	// 超出范围
	if (flow < witchPercentList.Get(0) || flow > witchPercentList.Get(witchPercentList.Length - 1)) {
		return false;
	}
	// 在 Witch 刷新路程集合中找到了该路程, 返回 true
	return witchPercentList.FindValue(flow) >= 0;
}

/**
* 设置对抗模式下 Tank 刷新路程
* @param percent 新的路程
* @return void
**/
void setTankPercent(int percent) {
	if (percent == 0) {
		L4D2Direct_SetVSTankFlowPercent(0, 0.0);
		L4D2Direct_SetVSTankFlowPercent(1, 0.0);
		L4D2Direct_SetVSTankToSpawnThisRound(0, false);
		L4D2Direct_SetVSTankToSpawnThisRound(1, false);
	} else {
		float newPercent = (float(percent) / 100.0);
		L4D2Direct_SetVSTankFlowPercent(0, newPercent);
		L4D2Direct_SetVSTankFlowPercent(1, newPercent);
		L4D2Direct_SetVSTankToSpawnThisRound(0, true);
		L4D2Direct_SetVSTankToSpawnThisRound(1, true);
	}
}

/**
* 设置对抗模式下 Witch 刷新路程
* @param percent 新的路程
* @return void
**/
void setWitchPercent(int percent) {
	if (percent == 0) {
		L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
		L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	} else {
		float newPercent = (float(percent) / 100.0);
		L4D2Direct_SetVSWitchFlowPercent(0, newPercent);
		L4D2Direct_SetVSWitchFlowPercent(1, newPercent);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	}
}

void onRoundEndResetState() {
	delete survivorDistCheckTimer;
	delete bossSpawnTimer;

	delete delaySpawnTankTimer;
	delete delaySpawnWitchTimer;

	newTankPercent = 0;
	newWitchPercent = 0;
	promptedDistance = -1;

	isTankSpawned = false;
	isWitchSpawned = false;
	isLeftSafeArea = false;

	delaySpawnTankTime = 0.0;
	delaySpawnWitchTime = 0.0;

	isTankSpawnFailed = false;
	isWitchSpawnFailed = false;

	readyUpFooterIndex = -1;
	isReadyUpFooterAdded = false;
}

void onMapEndResetState() {
	dkrFirstRoundTankPercent = 0;
	dkrFirstRoundWitchPercent = 0;

	tankFlow = 0;
	witchFlow = 0;
}

// ========== Methods End ==========