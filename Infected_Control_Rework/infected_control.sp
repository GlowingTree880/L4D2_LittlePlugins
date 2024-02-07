/**
* @Author 夜羽真白
* @Date 2023-07-23 13:43:35
* @Description 特感刷新控制
* @Version 1.1.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <profiler>
#include <logger>
#include <treeutil>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define CVAR_FLAG FCVAR_NOTIFY

#define PLUGIN_PREFIX "[Infected-Control]"

#define INVALID_CLIENT_INDEX -1

#define SPAN_INFECTED_TIMER_FLAG TIMER_REPEAT

// 场上特感数量检测时钟周期 (默认 1 秒检测一次场上特感数量, 分散刷新模式下不检测)
#define SPAWN_CHECK_TIMER_INTERVAL 1.0
// 生还者数量检测时钟周期 (默认 1 秒检测所有生还者选取目标)
#define SURVIVOR_COUNT_CHECK_INTERVAL 1.0
// 复活完成特感数量检测时钟周期
#define RESPAWN_FINISHED_CHECK_INTERVAL 1.0
// 分散刷新特感复活完毕请求刷新时钟周期
#define DISPERSE_START_SPAWN_INTERVAL 0.1
// 特感实体引用 Map 集合清脏时钟周期
#define ENT_REF_MAP_CLEAN_INTERVAL 5.0
// round_start 事件触发多少秒后获取第一波刷特队列
#define ROUND_START_DELAY 0.5
// 每局开始设置 z_max_player_zombie 延迟
#define MAX_SPECIAL_SET_DELAY 1.0
// 分散刷新模式时, 新增的特感复活延迟
#define NEW_INFECTED_RESPAWN_DELAY 0.5
// 刷新特感最小尝试次数
#define MIN_SPAWN_ATTEMPT 5
// 刷新特感最大尝试次数
#define MAX_SPAWN_ATTEMPT 15
// 允许开启特感轮换的最大特感数量
#define INF_ALTERNATIVE_MAX 5
// 特感刷新时钟在特感刷新时间超过这个值时使用 二阶增时, 否则使用一阶增时
#define SPAWN_TIME_INCREASE_FIRST_THRESHOLD 5.0
// 特感刷新时钟在特感刷新时间超过这个值时使用 三阶增时, 否则使用二阶增时
#define SPAWN_TIME_INCREASE_SECOND_THRESHOLD 10.0
// 一阶增时
#define SPAWN_TIME_INCREASE_FIRST_ORDER 0.5
// 二阶增时
#define SPAWN_TIME_INCREASE_SECOND_ORDER 2.0
// 三阶增时
#define SPAWN_TIME_INCREASE_THIRD_ORDER 4.0

ConVar
	g_hInfectedLimit,
	g_hSpawnDuration,
	g_hSpawnStrategy,
	g_hSpawnMethodStrategy,
	g_hCenteralizeSpawnStrategy,
	g_hDisperseSpawnPercent,
	g_hEachPosInfectedCount,
	g_hFirstWaveDelay,
	g_hDeadKickTime,
	g_hIncapExtraTime,
	g_hStartSpawnControl;

ConVar
	g_hLoggingLevel;

// 游戏自带 Cvar
ConVar
	game_zMaxPlayerZombie,
	game_directorNoSpecials,
	game_directorNoInfectedBots,
	game_zSpawnSafetyRange,
	game_zSafeSpawnRange;

ArrayList
	// 特感刷新队列
	infectedQueue;

StringMap
	// 特感实体索引 Map 集合
	infEntRefMap;

Logger
	log;

Handle
	infectedCountCheckTimer,
	survivorCountCheckTimer,
	respawnFinishedCheckTimer,
	disperseStartSpawnTimer;

float
	// 基准时钟时钟周期
	standardTimerInterval,
	// 固定时钟时钟周期
	regularTimerInterval,
	// 动态时钟时钟周期
	autoTimerInterval,
	// 一波刷特从开始找位到刷完所耗费的时间
	findPosSpawnTimeCost,
	// 距离上一波刷特完成间隔时间, For Debug
	spawnInterval,
	// 固定刷特时钟创建时间, For Debug
	regularTimerCreatedTime,
	// 动态刷特时钟创建时间, For Debug
	autoTimerCreatedTime;

bool
	isLeftSafeArea,
	// 是否可以生成新的特感
	canSpawnNewInfected,
	// 是否在一波刷新完成后的等待时间中
	isInSpawnFinishedTime,
	// 是否在找位失败后的延迟时间中
	isInFindPosFailedDelay;
stock bool
	// 插件是否延迟加载
	isLateLoad,
	// ReadyUp 插件是否存在
	isReadyUpExist;

int
	// 针对一个人找位模式下目标生还者索引
	targetIndex,
	// 跑男客户端索引
	runnerIndex,
	// 当前刷新特感的波数
	currentSpawnWaveCount = 1,
	// 分散刷新方式下, 当前重生完成的特感数量
	respawnFinishedCount,
	// 分散刷新方式下, 允许开始刷新时的特感数量
	targetCount,
	// 在场特感数量
	infectedCount;
int
	// 每次刷新一波时前统计这波强控特感的数量, 用于触发动态时钟
	waveDominativeCount;
int
	// 每一波刷新特感失败的次数, 用于调整每一次失败后新的特感重试刷新次数
	waveSpawnFailedCount,
	// 每一波倒地的生还者数量, 用于特感刷新时钟创建时延时
	waveIncapCount;
int
	// 一次找位的循环次数
	posFindAttemp;

// 时钟类型枚举类 TimerType
enum {
	TIMER_NONE,
	TIMER_STANDARD,
	TIMER_REGULAR,
	TIMER_AUTO
}

// 刷新时间策略 SpawnStrategy
enum {
	SPS_NONE,
	SPS_REGULAR,
	SPS_AUTO,
	SPS_SIZE
};

// 刷新方式策略 SpawnMethodStrategy
enum {
	SMS_NONE,
	SMS_CENTERALIZE,
	SMS_DISPERSE,
	SMS_SIZE
};

// 集中刷新方式找位策略 CenteralizeSpawnStrategy
enum {
	CSS_NONE,
	CSS_RANDOM,
	CSS_ONE,
	CSS_MAX_FLOW,
	CSS_MIN_FLOW,
	CSS_SIZE
};

enum {
	SSC_NONE,
	SSC_AUTO,
	SSC_MANUAL,
	SSC_SIZE
};

// 基本时钟类
enum struct BaseTimer {
	// 基础时钟句柄
	Handle timer;

	// 本时钟内记录的特感刷新波数
	int recordSpawnWaveCount;

	// 时钟 Flag
	int flag;
	// 时钟周期
	float interval;
	// 是否被触发
	bool isTriggered;
	// 触发次数
	int triggerCount;
	// 上次触发时间
	float lastTriggerTime;
	// 下次触发时间
	float nextTriggerTime;
	// 初始化函数
	void init() {
		delete this.timer;
		this.recordSpawnWaveCount = 0;
		this.flag = 0;
		this.interval = 0.0;
		this.isTriggered = false;
		this.triggerCount = 0;
		this.lastTriggerTime = 0.0;
		this.nextTriggerTime = 0.0;
	}
}

// 特感状态类
enum struct InfectedState {
	// 客户端实体索引
	int entRef;
	// 重生时钟句柄
	Handle timer;
	// 客户端名称
	char name[64];
	// 客户端特感类型
	int class;
	// 客户端死亡时间
	float deathTime;
	// 客户端是否重生完毕
	bool isRespawnFinished;
	// 初始化函数
	void init() {
		this.entRef = INVALID_ENT_REFERENCE;
		delete this.timer;
		this.class = 0;
		this.deathTime = 0.0;
		this.isRespawnFinished = false;
	}
}

ArrayList
	// 特感分散刷新时用于储存特感复活时钟集合
	infStateList,
	// 开启特感轮换时特感类型集合
	infClassList,
	// 目标集合
	targetList;

// 基准时钟, 固定时钟, 动态时钟
BaseTimer
	standardInfectedSpawnTimer,
	regularInfectedSpawnTimer,
	autoInfectedSpawnTimer;

public Plugin myinfo = 
{
	name 			= "[Infected-Control] 特感刷新控制",
	author 			= "夜羽真白",
	description 	= "特感刷新控制",
	version 		= "1.1.0.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// 变量引入
#include "setup.sp"
// Natives 和 Forwards
#include "natives_and_forwards.sp"
// 特感刷新队列
#include "inf_queue.sp"
// 特感找位控制
#include "inf_pos_find.sp"
// 时钟控制
#include "timers.sp"
// 事件处理
#include "events.sp"
// 指令处理
#include "commands.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {

	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead2) {
		strcopy(error, err_max, "本插件仅支持 Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	setUpNatives();
	RegPluginLibrary("infected_control");

	isLateLoad = late;

	return APLRes_Success;
}

public void OnAllPluginsLoaded() {
	if (!LibraryExists("left4dhooks")) {
		LogMessage("\n==========\n 本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行 \n==========\n");
		SetFailState("\n==========\n 本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行 \n==========\n");
	}
	isReadyUpExist = LibraryExists("readyup");
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "readyup") == 0)
		isReadyUpExist = false;
}
 
public void OnLibraryAdded(const char[] name)
{
    if (strcmp(name, "readyup") == 0)
		isReadyUpExist = true;
}

public void OnPluginStart() {
	
	g_hInfectedLimit = CreateConVar("inf_limit", "6", "特感刷新数量", CVAR_FLAG, true, 0.0, true, float(MaxClients));
	g_hSpawnDuration = CreateConVar("inf_spawn_duration", "16", "两次刷新之间基本间隔", CVAR_FLAG, true, 0.0);
	// 刷新及找位控制
	g_hSpawnStrategy = CreateConVar("inf_spawn_strategy", "2", "特感刷新策略 (1: 每波之间间隔固定 [击杀特感数量达到设置数量 / 2 开始计时], 2: 每波之间间隔根据击杀情况自动调整 [击杀特感数量达到设置数量 / 2 或 击杀强控特感数量达到强控总数 / 2 + 1 特时开始计时])", CVAR_FLAG, true, float(SPS_NONE + 1), true, float(SPS_SIZE - 1));
	g_hSpawnMethodStrategy = CreateConVar("inf_spawn_method_strategy", "1", "特感刷新方式 (1: 集中刷新 [到时间一起刷新一波], 2: 分散刷新 [每个特感单独按 g_hSpawnDuration 计时, 到时间不会一起刷新一波])", CVAR_FLAG, true, float(SMS_NONE + 1), true, float(SMS_SIZE - 1));
	g_hCenteralizeSpawnStrategy = CreateConVar("inf_centeralize_spawn_strategy", "1", "特感找位策略 (1: 每刷新一只特感时随机一个生还者找位, 2: 在一个刷新队列刷新完毕前都以一个生还者找位, 3: 总是以路程最大的生还者找位, 4: 总是以路程最小的生还者找位)", CVAR_FLAG, true, float(CSS_NONE + 1), true, float(CSS_SIZE - 1));
	g_hDisperseSpawnPercent = CreateConVar("inf_disperse_spawn_per", "0.5", "采用分散刷新方式时, 先死亡的特感需要等待至少 [g_hDisperseSpawnPercent * g_hInfectedLimit] 取下整个特感复活时间完成或在场才允许复活, [如配置 5 特感, 本值为 0.5, 则先死亡的特感需要等待至少 3 只特感复活完成或在场至少 3 只特感才可复活]", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hEachPosInfectedCount = CreateConVar("inf_each_pos_count", "1", "每个刷新位置允许刷新多少只特感", CVAR_FLAG, true, 1.0, true, float(MaxClients));
	g_hFirstWaveDelay = CreateConVar("inf_firstwave_delay", "0.0", "每局第一波特感刷新在首个生还者离开安全区域后延迟多少秒 (0: 不延迟)", CVAR_FLAG, true, 0.0);
	g_hIncapExtraTime = CreateConVar("inf_incap_extra_time", "5.0", "有一个生还者倒地则下一波刷特向后延迟多少秒 (0: 不延迟) [仅集中刷新模式可用]", CVAR_FLAG, true, 0.0);
	g_hDeadKickTime = CreateConVar("inf_dead_kick_time", "0.5", "多少秒后踢出死亡的特感 [除 Spitter]", CVAR_FLAG, true, 0.1);
	g_hStartSpawnControl = CreateConVar("inf_start_spawn_control", "1", "以何种方式开启特感刷新 (1: 自动控制 [首个生还者离开安全区域自动刷新], 2: 手动控制 [需要输入 !startspawn 指令])", CVAR_FLAG, true, float(SSC_NONE + 1), true, float(SSC_SIZE - 1));
	// 日志记录
	g_hLoggingLevel = CreateConVar("inf_log_level", "38", "插件日志级别 (1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR) 数字相加", CVAR_FLAG, true, 0.0, true, 64.0);

	game_zMaxPlayerZombie = FindConVar("z_max_player_zombies");
	game_directorNoSpecials = FindConVar("director_no_specials");
	game_directorNoInfectedBots = FindConVar("director_allow_infected_bots");
	game_zSpawnSafetyRange = FindConVar("z_spawn_safety_range");
	game_zSafeSpawnRange = FindConVar("z_safe_spawn_range");
	if (game_zMaxPlayerZombie != null) {
		int flags = game_zMaxPlayerZombie.Flags;
		game_zMaxPlayerZombie.SetBounds(ConVarBound_Upper, false);
		game_zMaxPlayerZombie.Flags = flags & ~FCVAR_CHEAT;
	}

	RegAdminCmd("sm_startspawn", cmdStartSpawn, ADMFLAG_BAN, "开始特感刷新");
	RegAdminCmd("sm_limit", cmdInfectedLimit, ADMFLAG_BAN, "更改特感数量");
	RegAdminCmd("sm_duration", cmdSpawnDuration, ADMFLAG_BAN, "更改特感刷新时间");
	RegAdminCmd("sm_type", cmdSingleInfectedMode, ADMFLAG_BAN, "启用单一特感模式");

	RegAdminCmd("sm_statelist", cmdStateList, ADMFLAG_BAN, "展示特感状态数组情况");
	RegAdminCmd("sm_state", cmdState, ADMFLAG_BAN, "展示当前特感刷新状态");
	RegAdminCmd("sm_entmap", cmdEntMap, ADMFLAG_BAN, "展示特感实体索引 Map 情况");

	g_hInfectedLimit.AddChangeHook(changeHookInfectedLimit);
	g_hSpawnDuration.AddChangeHook(changeHookSpawnDuration);
	g_hLoggingLevel.AddChangeHook(changeHookLoggingLevel);
	g_hSpawnStrategy.AddChangeHook(changeHookSpawnStrategy);
	g_hSpawnMethodStrategy.AddChangeHook(changeHookSpawnMethodStrategy);

	// 事件挂钩
	HookEvent("round_start", eventRoundStartHandler);
	HookEvent("mission_lost", eventRoundEndHandler);
	HookEvent("round_end", eventRoundEndHandler);
	HookEvent("player_death", eventPlayerDeathHandler);
	HookEvent("player_incapacitated", eventPlayerIncapStartHandler);
	HookEvent("player_disconnect", eventPlayerDisconnectHandler, EventHookMode_Pre);

	infStateList = new ArrayList(sizeof(InfectedState));
	infClassList = new ArrayList();
	infEntRefMap = new StringMap();
	targetList = new ArrayList(2);
	log = new Logger(g_hLoggingLevel.IntValue);
	
	// 其他模块
	// 特感刷新队列模块
	infectedQueueOnModulStart();
	// 特感找位模块
	infectedPosFindOnModuleStart();
	// Natives And Forwards
	nativesAndForwardsOnModuleStart();

	getInfectedSpawnTimerInterval();
	getDisperseTargetInfectedCount();

	// 设置最大特感数量
	CreateTimer(MAX_SPECIAL_SET_DELAY, timerSetMaxSpecialHandler, _, _);
	// 设置特感刷新距离
	CreateTimer(ROUND_START_DELAY, timerSetSpawnDistanceHandler, _, _);
	// 设置特感实体索引 Map 集合后台清脏时钟
	CreateTimer(ENT_REF_MAP_CLEAN_INTERVAL, timerEntRefMapCleanHandler, _, TIMER_REPEAT);
}

public void OnPluginEnd() {

	delete infectedQueue;
	resetGameConVar();

	// 其他模块
	// 特感刷新队列模块
	infectedQueueOnModuleEnd();
}

/**
* 重置 Cvar
* @param void
* @return void
**/
void resetGameConVar() {
	// 设置导演系统允许特感 Bot
	setAllowInfectedBots(true);
	game_zSpawnSafetyRange.RestoreDefault(true, true);
	game_zSafeSpawnRange.RestoreDefault(true, true);
}

public void OnMapStart() {
	resetTimersAndStates();
	// 重新获取时钟周期
	getInfectedSpawnTimerInterval();
	getDisperseTargetInfectedCount();
	// 设置最大特感数量上限
	CreateTimer(MAX_SPECIAL_SET_DELAY, timerSetMaxSpecialHandler, _, _);
	// 设置特感刷新距离
	CreateTimer(ROUND_START_DELAY, timerSetSpawnDistanceHandler, _, _);
}

/**
* 第一个生还者离开起始安全区域
* @param client 离开安全区域的客户端索引
* @return Action
**/
public Action L4D_OnFirstSurvivorLeftSafeArea(int client) {
	if (isReadyUpExist) {
		if (IsInReady())
			return Plugin_Handled;
	}

	// 客户端索引无效或不是有效生还者, 不允许触发事件
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) {
		return Plugin_Handled;
	}

	// 创建特感数量检测时钟, 开始刷新特感
	delete infectedCountCheckTimer;
	infectedCountCheckTimer = CreateTimer(SPAWN_CHECK_TIMER_INTERVAL, timerInfectedCountCheckHandler, _, TIMER_REPEAT);
	// 创建生还者数量检测时钟
	delete survivorCountCheckTimer;
	survivorCountCheckTimer = CreateTimer(SURVIVOR_COUNT_CHECK_INTERVAL, timerCheckSurvivorCountHandler, _, TIMER_REPEAT);
	// 创建复活完成特感数量检测时钟
	delete respawnFinishedCheckTimer;
	respawnFinishedCheckTimer = CreateTimer(RESPAWN_FINISHED_CHECK_INTERVAL, timerRespawnFinishedCheckHandler, _, TIMER_REPEAT);

	// 唤起一次生还者数量检测时钟, 保证出门能刷新特感
	TriggerTimer(survivorCountCheckTimer);

	// 自动控制模式, 允许刷新特感, 判断是否需要延迟刷新第一波特感, 否则手动控制模式需要输入指令才允许刷新第一波特感
	if (g_hStartSpawnControl.IntValue == SSC_AUTO) {
		if (g_hFirstWaveDelay.BoolValue)
			CreateTimer(g_hFirstWaveDelay.FloatValue, timerFirstWaveDelaySpawnHandler, _, _);
		else
			canSpawnNewInfected = true;
	}

	log.debugAndInfo("%s: 第一个玩家 %N 出安全区域, 当前刷新控制模式 %d, 是否允许刷新第 1 波特感 %b, 延迟 %.2f s",
		PLUGIN_PREFIX, client, g_hStartSpawnControl.IntValue, canSpawnNewInfected, g_hFirstWaveDelay.FloatValue);

	isLeftSafeArea = true;
	return Plugin_Continue;
}

// ********** Timer Handles Start **********

/**
* 检测特感数量时钟回调函数（周期 1.0s）
* @param timer 时钟句柄
* @return Aciton
**/
public Action timerInfectedCountCheckHandler(Handle timer) {
	// 总特感数量, 强控特感数量, DPS 特感数量
	static int count, dominativeCount, dpsCount;

	count = getTeamClientCount(TEAM_INFECTED, true, false),
	infectedCount = count,
	dominativeCount = getDominativeInfectedCount(),
	dpsCount = count - dominativeCount > 0 ? count - dominativeCount : 0;

	// 如果正在刷新特感, 则停止检测
	if (canSpawnNewInfected) {
		return Plugin_Continue;
	}

	// 如果是分散刷新, 停止检测
	if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
		return Plugin_Continue;
	}

	// 触发固定刷特时钟
	if (g_hSpawnStrategy.IntValue == SPS_REGULAR &&
	 	isInSpawnFinishedTime && 
		canTriggerRegularInfectedSpawnTimer(count, dominativeCount, dpsCount)) {

		// 未创建固定刷特时钟则创建
		if (regularInfectedSpawnTimer.timer == null) {
			
			if (waveIncapCount > 0) {
				log.debugAndInfo("\n%s: 检测到当前在刷特间隔内, 且满足固定时钟触发条件且当前固定时钟为 null, 创建固定时钟, 本波次内共有 %d 名生还者倒地, 周期 %.2f, 距离上次创建固定时钟经过 %.3f s\n", PLUGIN_PREFIX, waveIncapCount, g_hSpawnDuration.FloatValue + (waveIncapCount * g_hIncapExtraTime.FloatValue), GetEngineTime() - regularTimerCreatedTime);
			} else {
				log.debugAndInfo("\n%s: 检测到当前在刷特间隔内, 满足固定时钟触发条件且当前固定时钟为 null, 创建固定时钟, 周期 %.2f, 距离上次创建固定时钟经过 %.3f s\n", PLUGIN_PREFIX, regularTimerInterval, GetEngineTime() - regularTimerCreatedTime);
			}
			
			regularTimerCreatedTime = GetEngineTime();

			// 固定时钟因为生还者倒地而增时, 周期是固定时钟周期 + (本波次倒地人数 * 一个倒地生还者的增时)
			if (waveIncapCount > 0)
				regularInfectedSpawnTimer.timer = CreateTimer(regularTimerInterval + (waveIncapCount * g_hIncapExtraTime.FloatValue), timerRegularInfectedSpawnHandler, _, SPAN_INFECTED_TIMER_FLAG);
			else
				regularInfectedSpawnTimer.timer = CreateTimer(regularTimerInterval, timerRegularInfectedSpawnHandler, _, SPAN_INFECTED_TIMER_FLAG);
			// 设置固定刷特时钟参数
			regularInfectedSpawnTimer.nextTriggerTime = GetGameTime() + regularTimerInterval;
		}
	} else if (g_hSpawnStrategy.IntValue == SPS_AUTO && 
		isInSpawnFinishedTime && 
		canTriggerAutoInfectedSpawnTimer(count, dominativeCount, dpsCount)) {

		// 触发自动刷特时钟, 未创建自动刷特时钟则创建
		if (autoInfectedSpawnTimer.timer == null) {
			
			if (waveIncapCount > 0) {
				log.debugAndInfo("\n%s: 检测到当前在刷特间隔内, 且满足动态时钟触发条件且当前动态时钟为 null, 创建动态时钟, 本波次内共有 %d 名生还者倒地, 周期 %.2f, 距离上次创建动态时钟经过 %.3f s\n", PLUGIN_PREFIX, waveIncapCount, autoTimerInterval + (waveIncapCount * g_hIncapExtraTime.FloatValue), GetEngineTime() - autoTimerCreatedTime);
			} else {
				log.debugAndInfo("\n%s: 检测到当前在刷特间隔内, 且满足动态时钟触发条件且当前动态时钟为 null, 创建动态时钟, 周期 %.2f, 距离上次创建动态时钟经过 %.3f s\n", PLUGIN_PREFIX, autoTimerInterval, GetEngineTime() - autoTimerCreatedTime);
			}
			
			autoTimerCreatedTime = GetEngineTime();

			// 动态时钟因为生还者倒地而增时
			if (waveIncapCount > 0)
				autoInfectedSpawnTimer.timer = CreateTimer(autoTimerInterval + (waveIncapCount * g_hIncapExtraTime.FloatValue), timerAutoInfectedSpawnHandler, _, SPAN_INFECTED_TIMER_FLAG);
			else
				autoInfectedSpawnTimer.timer = CreateTimer(autoTimerInterval, timerAutoInfectedSpawnHandler, _, SPAN_INFECTED_TIMER_FLAG);
			// 设置动态时钟参数
			autoInfectedSpawnTimer.nextTriggerTime = GetGameTime() + autoTimerInterval;
		}
	}

	return Plugin_Continue;
}

public Action timerCheckSurvivorCountHandler(Handle timer) {
	static int i;
	static float flow;

	targetList.Clear();
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidSurvivor(i) || !IsPlayerAlive(i))
			continue;
		flow = L4D2Direct_GetFlowDistance(i);
		if (flow <= 0.0)
			continue;

		targetList.Set(targetList.Push(flow), i, 1);
	}

	// 时钟周期内检测跑男是否存在
	runnerIndex = doCheckRunnerExist();
	
	// 设置当前 Tickrate 下最大找位次数
	posFindAttemp = targetList.Length < 1 ? POS_FIND_MAX_ATTEMP : GetServerTickRate() / targetList.Length;
	posFindAttemp = posFindAttemp > POS_FIND_MAX_ATTEMP ? POS_FIND_MAX_ATTEMP : posFindAttemp;

	return Plugin_Continue;
}

public Action timerRespawnFinishedCheckHandler(Handle timer) {
	if (infStateList == null)
		return Plugin_Continue;
	static int i, count;
	count = 0;

	static InfectedState state;
	for (i = 0; i < infStateList.Length; i++) {
		infStateList.GetArray(i, state, sizeof(state));
		if (state.isRespawnFinished)
			count += 1;
	}
	respawnFinishedCount = count;

	return Plugin_Continue;
}

public Action timerEntRefMapCleanHandler(Handle timer) {
	if (infEntRefMap == null)
		return Plugin_Stop;
	if (infEntRefMap.Size < 1)
		return Plugin_Continue;
	static StringMapSnapshot sn;
	sn = infEntRefMap.Snapshot();
	static int i, entIndex;
	static char key[64];
	for (i = 0; i < sn.Length; i++) {
		sn.GetKey(i, key, sizeof(key));
		if (strlen(key) <= 0)
			continue;

		entIndex = EntRefToEntIndex(StringToInt(key));
		if (!IsValidEntity(entIndex)) {
			infEntRefMap.Remove(key);
			continue;
		}
	}

	return Plugin_Continue;
}

// ********** Timer Handles End **********

/**
* 每波刷特前选择目标生还者, 查找是否存在跑男
* @param void
* @return void
**/
int prevTarget = INVALID_CLIENT_INDEX;
void findRunnerAndTargetSurvivor() {
	if (targetList.Length < 1)
		return;

	switch (g_hCenteralizeSpawnStrategy.IntValue) {
		case CSS_RANDOM: {
			for (;;) {
				targetIndex = targetList.Get(GetRandomIntInRange(0, targetList.Length - 1), 1);
				if (prevTarget < 1) {
					break;
				} else {
					if (targetIndex == prevTarget && targetList.Length > 1)
						continue;
					break;
				}
			}
		} case CSS_ONE: {
			for (;;) {
				targetIndex = targetList.Get(GetRandomIntInRange(0, targetList.Length - 1), 1);
				if (targetIndex == prevTarget && targetList.Length > 1)
					continue;
				break;
			}
		} case CSS_MAX_FLOW: {
			targetList.Sort(Sort_Descending, Sort_Float);
			targetIndex = targetList.Get(0, 1);
		} case CSS_MIN_FLOW: {
			targetList.Sort(Sort_Ascending, Sort_Float);
			targetIndex = targetList.Get(0, 1);
		}
	}

	prevTarget = targetIndex;
}

/**
* 跑男检测
* @param void
* @return int 跑男玩家客户端索引
**/
stock int doCheckRunnerExist() {
	static int targetClient, survivorCount;
	survivorCount = getTeamClientCount(TEAM_SURVIVOR, true, false);
	static float targetDensity, limitDensity;
	if (g_hRunnerCheckDistance.BoolValue && survivorCount > 1) {
		targetClient = L4D_GetHighestFlowSurvivor();
 		if (!IsValidClient(targetClient) || !IsPlayerAlive(targetClient)) {
			return INVALID_CLIENT_INDEX;
		}
		targetDensity = getSurvivorDensity(targetClient);
		limitDensity = 1.0 / float(survivorCount);
		if (FloatCompare(targetDensity, limitDensity) < 0) {
			log.debugAndInfo("%s: 找到跑男玩家: %N, 该玩家的生还者密度为 %.2f, 小于限制密度 %.2f", PLUGIN_PREFIX, targetClient, targetDensity, limitDensity);

			return targetClient;
		}
	}
	return INVALID_CLIENT_INDEX;
}

public void OnGameFrame() {

	static int i, class, entIndex, entRef;
	static float findPosTime, spawnPos[3];
	static char entRefStr[64];
	static InfectedState state;

	// 不允许刷新新的特感, 返回
	if (!isLeftSafeArea || !canSpawnNewInfected || isInFindPosFailedDelay || isInSpawnFinishedTime)
		return;

	// 特感刷新队列为 null, 重新获取一个
	if (infectedQueue == null || (!isTankPresence() && infectedQueue.Length < infStateList.Length)) {
		delete infectedQueue;

		// 需要进行特感轮换
		if (isNeedToAlternate())
			infectedQueue = getInfectedQueue(infClassList);
		else
			infectedQueue = getInfectedQueue();
	}
	if (infectedQueue == null)
		return;

	// 寻找跑男与目标生还者
	switch (g_hCenteralizeSpawnStrategy.IntValue) {
		case CSS_ONE: {
			// 每波只针对一个目标刷新情况, 如果目标无效则获取一个目标, 否则在这一波刷新完之前不会更换目标
			if (targetIndex < 1)
				findRunnerAndTargetSurvivor();
		} default: {
			findRunnerAndTargetSurvivor();
		}
	}

	// 开始一波特感刷新
	if (findPosSpawnTimeCost == 0.0) {
		spawnInterval = GetEngineTime();
		findPosSpawnTimeCost = GetEngineTime();
		isInSpawnFinishedTime = false;

		// 第一波刷特, 需要进行特感轮换时, 记录特感类型, 补齐缺失的特感类型
		if (isNeedToAlternate() && currentSpawnWaveCount <= 1) {
			infClassList = infectedQueue.Clone();
			bool existClass[INFECTED_ARRAY_SIZE];
			for (i = 0; i < infectedQueue.Length; i++) {
				if (!existClass[infectedQueue.Get(i)])
					existClass[infectedQueue.Get(i)] = true;
			}
			for (i = 1; i < INFECTED_ARRAY_SIZE; i++) {
				if (!existClass[i]) {
					infClassList.Push(i);
					log.debugAndInfo("%s: 当前为第一波刷特, 开启特感轮换, 找到缺失特感类型 %s, 加入到轮换类型集合中",
						PLUGIN_PREFIX, INFECTED_NAME[i]);
				}
			}
			// 打印轮换集合
			printInfectedClassList();
		}

		Call_StartForward(onOnceSpawnStarted);
		Call_Finish();

		if (g_hSpawnMethodStrategy.IntValue == SMS_CENTERALIZE)
			log.debugAndInfo("\n%s: 集中刷新模式, 开始第 %d 波特感刷新\n", PLUGIN_PREFIX, currentSpawnWaveCount);
	}
	// 一波特感刷新完成, 进行后处理
	if (infectedQueue.Length < 1) {

		log.debugAndInfo("\n%s: 第 %d 波特感全部刷新完成, 耗时 %.2f s, 距离上一波刷特完成经过 %.2f s\n",
			PLUGIN_PREFIX, currentSpawnWaveCount, GetEngineTime() - findPosSpawnTimeCost, GetEngineTime() - spawnInterval);

		// 重置特感刷新状态
		spawnInterval = GetEngineTime();
		canSpawnNewInfected = false;
		isInSpawnFinishedTime = true;
		expandCount = 0;
		findPosSpawnTimeCost = 0.0;
		targetIndex = runnerIndex = INVALID_CLIENT_INDEX;

		// 删除旧的特感刷新队列
		delete infectedQueue;

		// 调用后处理
		postProcessOnOnceSpawnFinished();

		// 发布刷新完成事件
		Call_StartForward(onOnceSpawnFinished);
		Call_Finish();

		// 刷新完成, 当前波次加一
		currentSpawnWaveCount += 1;

		return;
	}

	// 找位刷新逻辑
	if (!IsValidSurvivor(targetIndex) || !IsPlayerAlive(targetIndex))
		return;

	findPosTime = GetEngineTime() - findPosSpawnTimeCost;
	// 检查是否有跑男, 如果有跑男则优先以跑男为中心找位, 否则选择目标生还者
	targetIndex = runnerIndex > 0 ? runnerIndex : targetIndex;

	// 从刷新队列头部获取一个特感类型
	class = infectedQueue.Get(0);

	if (findPosTime <= g_hStartExpandTime.FloatValue) {
		// 不需要进行网格拓展
		switch (g_hFindPosMethod.IntValue) {
			case FPM_USING_API:
				getSpawnPosByAPI(targetIndex, class, spawnPos);
			case FPM_USING_ENHANCED_API:
				getSpanPosByAPIEnhance(targetIndex, class, _, spawnPos);
			case FPM_USING_RAY:
				getSpawnPos(targetIndex, _, _, spawnPos);
		}
	} else if (g_hFindPosMaxTime.FloatValue > 0.0 && findPosTime >= g_hFindPosMaxTime.FloatValue) {
		// 超出限制时间, 停止刷特
		findPosSpawnTimeCost = 0.0;
		canSpawnNewInfected = false;
		isInFindPosFailedDelay = true;
		CreateTimer(g_hFailedFindPosNextDelay.FloatValue, timerFindPosFailedHandler, _, _);

		log.debugAndInfo("\n%s: 第 %d 波特感刷新找位超出限制 %.2f 秒, 将于 %.2f 秒后重新启动找位\n",
			PLUGIN_PREFIX, currentSpawnWaveCount, g_hFindPosMaxTime.FloatValue, g_hFailedFindPosNextDelay.FloatValue);
	} else {
		// 进行网格拓展
		switch (g_hFindPosMethod.IntValue) {
			case FPM_USING_ENHANCED_API:
				getSpanPosByAPIEnhance(targetIndex, class, g_hExpandUnit.FloatValue, spawnPos);
			case FPM_USING_RAY:
				getSpawnPos(targetIndex, g_hExpandUnit.FloatValue, g_hNaxExpandUnit.FloatValue, spawnPos);
		}
	}

	// 无效刷新位置
	if (IsZeroVector(spawnPos))
		return;

	// 刷新特感
	for (i = 0; i < g_hEachPosInfectedCount.IntValue; i++) {
		// 集中刷新方式
		if (g_hSpawnMethodStrategy.IntValue == SMS_CENTERALIZE) {
			// 允许刷新, 从刷新队列头部去除这个特感类型
			infectedQueue.Erase(0);
			entIndex = doSpawnInfected(class, spawnPos, view_as<float>({0.0, 0.0, 0.0}));
			if (!IsValidEntity(entIndex)) {
				waveSpawnFailedCount += 1;
				continue;
			}
		} else if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
			if (currentSpawnWaveCount > 1) {
				// 状态集合中没有任何特感, 刷新完毕
				if (infStateList.Length < 1) {
					canSpawnNewInfected = false;
					isInSpawnFinishedTime = true;
					return;
				}

				// 检查是否有复活完成的特感 或 分散刷新下设置了特感复活阈值, 检查复活完成的特感数量是否达到这个阈值 不允许继续刷新
				infStateList.GetArray(0, state, sizeof(state));
				if (!state.isRespawnFinished || (infectedCount + respawnFinishedCount < targetCount)) {
					canSpawnNewInfected = false;
					isInSpawnFinishedTime = true;
					return;
				}
			}

			infectedQueue.Erase(0);
			entIndex = doSpawnInfected(class, spawnPos, view_as<float>({0.0, 0.0, 0.0}));
			if (!IsValidEntity(entIndex)) {
				waveSpawnFailedCount += 1;
				return;
			}

			respawnFinishedCount = respawnFinishedCount > 0 ? respawnFinishedCount - 1 : 0;

			// 非第一波刷新, 从状态集合中删除一个元素, 表示一只特感已经复活完成并刷新, 不判断是否第一波刷新会导致第一波刷新时特感死亡, 另外刷新的特感将死亡的特感状态类删除, 导致特感数量错误
			if (currentSpawnWaveCount > 1 && infStateList.Length >= 1) {
				infStateList.GetArray(0, state, sizeof(state));

				log.debugAndInfo("%s: 分散刷新模式刷新一只特感, 删除状态集合头部元素, 名称 %s, 类型 %s, 是否复活完毕 %b, 死亡时间 %.2f, 时钟 0x%x", PLUGIN_PREFIX, state.name, INFECTED_NAME[state.class], state.isRespawnFinished, state.deathTime, state.timer);
				
				infStateList.Erase(0);
			}
		}

		if (g_hSpawnMethodStrategy.IntValue == SMS_CENTERALIZE) {
			log.debugAndInfo("%s: 集中刷新模式, 耗时 %.2fs 在 [%.2f,%.2f,%.2f] 处刷新一只 %s, 当前 %s 在场数量 %d, 剩余 %d 只特感待刷新",
				PLUGIN_PREFIX, GetEngineTime() - findPosSpawnTimeCost, spawnPos[0], spawnPos[1], spawnPos[2], INFECTED_NAME[class], INFECTED_NAME[class], getSpecificInfectedCount(class), infectedQueue.Length);
		} else if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
			log.debugAndInfo("%s: 分散刷新模式, 耗时 %.2fs 在 [%.2f,%.2f,%.2f] 处刷新一只 %s, 当前 %s 在场数量 %d, 当前复活完成特感数量 %d 只",
				PLUGIN_PREFIX, GetEngineTime() - findPosSpawnTimeCost, spawnPos[0], spawnPos[1], spawnPos[2], INFECTED_NAME[class], INFECTED_NAME[class], getSpecificInfectedCount(class), respawnFinishedCount);
		}

		// 开启 6 特以下特感轮换 或 分散刷新方式下 记录刷新的特感的实体引用, 存入 infEntRefMap
		if (isNeedToAlternate() || g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
			// 将 entIndex 转为 entRef 放入 map 中
			entRef = EntIndexToEntRef(entIndex);
			if (entRef != INVALID_ENT_REFERENCE) {
				IntToString(entRef, entRefStr, sizeof(entRefStr));
				infEntRefMap.SetValue(entRefStr, true);

				log.debugAndInfo("%s: 已将特感类型 %s, 实体索引 %d(引用 %d) 加入到特感实体引用 Map 中",
					PLUGIN_PREFIX, INFECTED_NAME[class], entIndex, entRef);
			}
		}
	}

}

/**
* 在指定位置刷新特感
* @param class 特感类型
* @param pos 位置坐标
* @param ang 角度坐标
* @return int
**/
static int doSpawnInfected(int class, const float pos[3], const float angle[3] = {0.0, 0.0, 0.0}) {
	if (class < ZC_SMOKER || class > ZC_CHARGER)
		return false;
	
	// 计算尝试次数, 失败了一次从最大尝试次数开始 / 2 得到新的尝试次数, 快速失败
	static int i, attempt, infEntIndex;
	attempt = MAX_SPAWN_ATTEMPT;
	for (i = waveSpawnFailedCount; i > 0; i--) {
		attempt /= 2;
		if (attempt <= MIN_SPAWN_ATTEMPT) {
			attempt = MIN_SPAWN_ATTEMPT;
			break;
		}
	}

	for (i = 0; i < attempt; i++) {
		infEntIndex = L4D2_SpawnSpecial(class, pos, angle);
		if (IsValidEntity(infEntIndex)) {
			SetEntProp(infEntIndex, Prop_Send, "m_bDucked", 1);
			if (!IsValidSurvivor(targetIndex) || !IsPlayerAlive(targetIndex))
				return infEntIndex;
			SetEntityFlags(infEntIndex, GetEntityFlags(targetIndex) | FL_DUCKING);
			return infEntIndex;
		}
	}
	log.error("%s: 无法于指定位置 [%.2f, %.2f, %.2f], 角度 [%.2f, %.2f, %.2f], 刷新特感 %s, 尝试 %d 次", PLUGIN_PREFIX, pos[0], pos[1], pos[2], angle[0], angle[1], angle[2], INFECTED_NAME[class], attempt);
	return CLIENT_INVALID;
}

// ********** Interface Start **********

/**
* 一波特感刷新完成后处理接口
* @param 
* @return void
**/
stock void postProcessOnOnceSpawnFinished() {

	log.debugAndInfo("\n ===== %s: 开始第 %d 波特感刷新完成后处理 ===== \n", PLUGIN_PREFIX, currentSpawnWaveCount);

	// ***** Timer Sync Start *****
	// 当前为集中刷新模式, 每一波刷新完成后重新创建基准时钟
	if (g_hSpawnMethodStrategy.IntValue == SMS_CENTERALIZE) {
		delete standardInfectedSpawnTimer.timer;
		standardInfectedSpawnTimer.recordSpawnWaveCount += 1;
		standardInfectedSpawnTimer.nextTriggerTime = GetGameTime() + standardTimerInterval;
		standardInfectedSpawnTimer.timer = CreateTimer(standardTimerInterval, timerStandardInfectedSpawnHandler, _, SPAN_INFECTED_TIMER_FLAG);

		log.debugAndInfo("\n%s: 当前是第 %d 波特感刷新, 创建基准时钟, 周期 %.2fs, 下次触发在 %.2f s\n",
			PLUGIN_PREFIX, currentSpawnWaveCount, standardTimerInterval, standardInfectedSpawnTimer.nextTriggerTime);
	}
	// ***** Timer Sync End *****

	// 重置波次特感刷新失败次数
	waveSpawnFailedCount = 0;
	waveIncapCount = 0;
}

// ********** Interface End **********

// ********** Methods Start **********

/**
* 获取强控特感（SMOKER, HUNTER, JOCKEY, CHARGER）在场总数
* @param 
* @return int
**/
stock int getDominativeInfectedCount() {
	static int i;
	int class, count = 0;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i) || IsClientIncapped(i) || IsInGhostState(i)) {
			continue;
		}
		class = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (class == ZC_SMOKER || class == ZC_HUNTER || class == ZC_JOCKEY || class == ZC_CHARGER) {
			count++;
		}
	}
	return count;
}

/**
* 获取 Cvar 设置中强控特感（SMOKER, HUNTER, JOCKEY, CHARGER）总数
* @param 
* @return int 
**/
stock static int getCvarDominativeInfectedCount() {
	static int i;
	int count = 0;
	for (i = 0; i < INFECTED_ARRAY_SIZE - 1; i++) {
		if (i == ZC_BOOMER || i == ZC_SPITTER) {
			continue;
		}
		count += g_hInfectedCvarLimit[i].IntValue;
	}
	return count;
}

/**
* 随机获取一个有效生还者 (优先获取未被控, 未倒地的生还者, 如无则随机获取一个未死亡的生还者)
* @param excludeClient 排除的生还者
* @return int
**/
stock int getRandomSurvivor(int excludeClient = INVALID_CLIENT_INDEX) {
	static int i, ret;
	ret = INVALID_CLIENT_INDEX;

	static ArrayList list;
	list = new ArrayList();

	// 优先寻找未倒地, 未被控的生还者
	for (i = 1; i <= MaxClients; i++) {
		if (i == excludeClient || !IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i) || IsClientPinned(i) || IsClientIncapped(i)) {
			continue;
		}
		list.Push(i);
	}
	if (list.Length >= 1) {
		ret = list.Get(GetRandomIntInRange(0, list.Length - 1));
		delete list;
		return ret;
	}
	// 如果没有, 则随机选取一个活着的生还者
	for (i = 1; i <= MaxClients; i++) {
		if (i == excludeClient || !IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		list.Push(i);
	}
	if (list.Length < 1) {
		delete list;
		return ret;
	}
	ret = list.Get(GetRandomIntInRange(0, list.Length - 1));
	delete list;
	return ret;
}

/**
* 一局开始或地图开始重置状态
* @param 
* @return void
**/
void resetTimersAndStates() {
	delete infectedCountCheckTimer;
	delete survivorCountCheckTimer;
	delete respawnFinishedCheckTimer;
	delete disperseStartSpawnTimer;
	delete infectedQueue;

	standardInfectedSpawnTimer.init();
	regularInfectedSpawnTimer.init();
	autoInfectedSpawnTimer.init();

	isLeftSafeArea = false;
	canSpawnNewInfected = false;
	isInSpawnFinishedTime = false;
	isInFindPosFailedDelay = false;

	findPosSpawnTimeCost = 0.0;
	spawnInterval = 0.0;
	regularTimerCreatedTime = 0.0;
	autoTimerCreatedTime = 0.0;
	currentSpawnWaveCount = 1;
	expandCount = 0;
	runnerIndex = INVALID_CLIENT_INDEX;

	respawnFinishedCount = 0;
	targetCount = 0;

	setAllowInfectedBots(false);
	
	waveDominativeCount = 0;

	infEntRefMap.Clear();
	waveSpawnFailedCount = 0;
	waveIncapCount = 0;

	// 重置特感状态集合
	infStateList.Clear();
	infClassList.Clear();
	targetList.Clear();
}

/**
* 是否可以触发固定刷特时钟
* @param infCount 当前在场特感总数
* @param dominativeCount 当前在场强控特感总数
* @param dpsCount 当前在场的 DPS 特感总数
* @return bool
**/
static bool canTriggerRegularInfectedSpawnTimer(int infCount, int dominativeCount, int dpsCount) {
	// 触发条件 1: 当前特感小于等于 (设定数量 / 2) + 1 特
	static int threshold;
	threshold = g_hInfectedLimit.IntValue / 2 + 1;
	if (infCount <= threshold) {
		return true;
	}
	return false;
}

/**
* 是否可以触发动态刷特时钟
* @param infCount 当前在场特感总数
* @param dominativeCount 当前在场强控特感总数
* @param dpsCount 当前在场的 DPS 特感总数
* @return bool
**/
static bool canTriggerAutoInfectedSpawnTimer(int infCount, int dominativeCount, int dpsCount) {
	// 触发条件 1: 基准时钟被触发
	if (canTriggerRegularInfectedSpawnTimer(infCount, dominativeCount, dpsCount)) {
		return true;
	}
	// 触发条件 2: 当前强控数量 <= (这波的强控总数 / 2) + 1 特
	// 如 6 特下 smoker, ht, ht, jockey, spitter, boomer, 强控总数 4 只, 在场强控小于等于 4 / 2 + 1 = 3 特即可触发动态时钟
	static int threshold;
	threshold = waveDominativeCount / 2 + 1;
	if (dominativeCount <= threshold) {
		return true;
	}
	return false;
}

/**
* 当前是否有任何生还者处于倒地状态
* @param void
* @return bool
**/
stock bool hasAnySurvivorIncap() {
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		if (IsClientIncapped(i)) {
			return true;
		}
	}
	return false;
}

void getInfectedSpawnTimerInterval() {
	static int half;
	half = g_hInfectedLimit.IntValue / 2;
	// 基准时钟间隔: SpawnDuration + (Limit / 2 == 0 ? 1 : Limit / 2) * 增时 (保底 0.5 s)
	standardTimerInterval = g_hSpawnDuration.FloatValue + (half > 0 ? half : 1) * getTimeIncreaseByOrder(g_hSpawnDuration.FloatValue);
	// 固定时钟间隔: SpawnDuration + 增时 (保底 0.5 s)
	regularTimerInterval = getTimeIncreaseByOrder(g_hSpawnDuration.FloatValue);
	// 动态时钟间隔: SpawnDuration + (Limit / 2 - 1 == 0 ? 1 : Limit / 2 - 1) * 增时 (保底 0.5 s)
	autoTimerInterval = g_hSpawnDuration.FloatValue + (half - 1 > 0 ? half - 1 : 1) * getTimeIncreaseByOrder(g_hSpawnDuration.FloatValue);

	standardInfectedSpawnTimer.interval = standardTimerInterval;
	regularInfectedSpawnTimer.interval = regularTimerInterval;
	autoInfectedSpawnTimer.interval = autoTimerInterval;
}

float getTimeIncreaseByOrder(const float time) {
	if (time <= SPAWN_TIME_INCREASE_FIRST_THRESHOLD)
		return SPAWN_TIME_INCREASE_FIRST_ORDER;
	else if (time > SPAWN_TIME_INCREASE_FIRST_THRESHOLD && time <= SPAWN_TIME_INCREASE_SECOND_THRESHOLD)
		return SPAWN_TIME_INCREASE_SECOND_ORDER;
	else
		return SPAWN_TIME_INCREASE_THIRD_ORDER;
}

void getDisperseTargetInfectedCount() {
	targetCount = RoundToCeil(g_hDisperseSpawnPercent.FloatValue * g_hInfectedLimit.FloatValue);
}

// ********** Methods End **********

// HACK: 需要增加与减少特感数量的情况, Bug 发现, 排除, 修复
void changeHookInfectedLimit(ConVar convar, const char[] oldValue, const char[] newValue) {
	log.debugAndInfo("%s: 特感数量 Cvar 变动, 旧值 %s, 新值 %s", PLUGIN_PREFIX, oldValue, newValue);

	// 重新获取特感等待队列
	getInfectedQueuePositionList();
	// 延迟获取特感队列, 防止特感数量 Cvar 没有完全设置完毕就开始读取特感队列, 导致特感队列生成错误
	DataPack dp = new DataPack();
	dp.Reset();
	dp.WriteCell(StringToInt(oldValue));
	dp.WriteCell(StringToInt(newValue));
	CreateTimer(ROUND_START_DELAY, timerChangeInfectedLimit, dp, TIMER_REPEAT);
}

Action timerChangeInfectedLimit(Handle timer, DataPack dp) {
	if (dp == null)
		return Plugin_Stop;
	// 如果还在刷新特感, 等待特感刷新完
	if (canSpawnNewInfected)
		return Plugin_Continue;

	dp.Reset();
	static int oldV, newV;
	oldV = dp.ReadCell(),
	newV = dp.ReadCell();
	delete dp;

	// 生还者还没有离开安全区域, 重新获取特感刷新队列
	if (!isLeftSafeArea) {
		delete infectedQueue;
		infectedQueue = getInfectedQueue();
	} else {
		// 离开了安全区域调整特感数量, 当前是分散刷新方式
		if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
			// 重新获取可刷新时已重生完成的特感上限
			getDisperseTargetInfectedCount();

			static int i, offset, count;
			static ArrayList newInfectedQueue;

			if (newV < oldV) {
				// offset 表示需要删除的特感状态数量
				offset = oldV - newV;

				InfectedState state;
				// 当前状态集合中的特感数量多于限制, 需要减少特感数量
				count = infStateList.Length;
				if (count > g_hInfectedLimit.IntValue && count > offset) {
					for (i = 0; i < offset; i++) {
						if (infStateList.Length < 1)
							break;
						infStateList.GetArray(infStateList.Length - 1, state, sizeof(state));

						log.debugAndInfo("%s: 分散刷新模式, 状态集合长度 %d, 允许直接从状态集合中删除 %d 个特感, 删除尾部特感 %s", PLUGIN_PREFIX, infStateList.Length, offset, INFECTED_NAME[state.class]);

						state.init();
						infStateList.Erase(infStateList.Length - 1);
					}
				}
				
				// 如果开启了特感轮换则需要设置轮换类型集合
				if (oldV > INF_ALTERNATIVE_MAX && isNeedToAlternate())
					getInfectedClassList();

				log.debugAndInfo("\n%s: 分散刷新模式, 减少特感数量 %d -> %d, 当前在场特感 %d 只, 特感实体引用 Map 大小 %d, 当前状态集合长度 %d\n", PLUGIN_PREFIX, oldV, newV, infectedCount, infEntRefMap.Size, infStateList.Length);
			
			} else {
				offset = newV - oldV;

				// 不需要进行特感轮换, 清空特感轮换集合
				if (oldV <= INF_ALTERNATIVE_MAX && !isNeedToAlternate())
					infClassList.Clear();

				// 获取一个新的特感队列, 从里面取出对应数量的特感
				newInfectedQueue = getInfectedQueue();

				// 向状态集合中加入对应数量的特感, 并开启刷新
				static char name[64];
				for (i = 0; i < offset; i++) {
					InfectedState state;
					// 设置特感类型
					state.class = newInfectedQueue.Get(newInfectedQueue.Length - 1);
					// 设置死亡时间
					state.deathTime = GetGameTime();
					// 设置名称
					Format(name, sizeof(name), "NewInfected %d", i + 1);
					strcopy(state.name, sizeof(name), name);
					// 设置复活完成
					state.isRespawnFinished = true;
					// 加入到状态集合中, 并移除新刷新队列尾部特感, 删除新刷新队列
					infStateList.PushArray(state, sizeof(state));
					if (newInfectedQueue.Length > 0)
						newInfectedQueue.Erase(newInfectedQueue.Length - 1);

					log.debugAndInfo("%s: 当前为分散刷新模式, 增加特感数量 %d -> %d, 向状态集合中新增一只 %s",
						PLUGIN_PREFIX, oldV, newV, INFECTED_NAME[state.class]);
				}
				delete newInfectedQueue;
				// 对状态集合进行排序
				infStateList.SortCustom(sortInfStateList);
				// 排序完成开始刷新新特感
				CreateTimer(0.5, timerSetAllowSpawnFlagHandler, _, TIMER_REPEAT);
			}
		}
	}

	CreateTimer(0.1, timerSetMaxSpecialHandler, _, _);

	return Plugin_Stop;
}

void changeHookLoggingLevel(ConVar convar, const char[] oldValue, const char[] newValue) {
	log = new Logger(g_hLoggingLevel.IntValue);
}

void changeHookSpawnDuration(ConVar convar, const char[] oldValue, const char[] newValue) {
	getInfectedSpawnTimerInterval();
}

void changeHookSpawnStrategy(ConVar convar, const char[] oldValue, const char[] newValue) {
	int newV = StringToInt(newValue);
	switch (newV) {
		case SPS_REGULAR:
			log.debugAndInfo("%s: 当前特感刷新策略更改为固定时间间隔刷新", PLUGIN_PREFIX);
		case SPS_AUTO:
			log.debugAndInfo("%s: 当前特感刷新策略跟改为动态时间间隔刷新", PLUGIN_PREFIX);
	}
}

void changeHookSpawnMethodStrategy(ConVar convar, const char[] oldValue, const char[] newValue) {
	int newV = StringToInt(newValue);
	switch (newV) {
		case SMS_CENTERALIZE:
			log.debugAndInfo("%s: 当前特感刷新方式更改为集中刷新方式", PLUGIN_PREFIX);
		case SMS_DISPERSE:
			log.debugAndInfo("%s: 当前特感刷新方式更改为分散刷新方式", PLUGIN_PREFIX);
	}
}

/**
* 脚本读取 MaxSpecials 时设置最大特感数量, 战役模式解锁特感上限
* @param key 脚本 key 名称
* @param retVal 返回值
* @return Action
**/
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	if (strcmp(key, "MaxSpecials", false) == 0 && retVal != g_hInfectedLimit.IntValue) {
		retVal = g_hInfectedLimit.IntValue;
		return Plugin_Handled;
	}
	if (strcmp(key, "cm_AggressiveSpecials", false) == 0 && retVal != 1) {
		retVal = 1;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/**
* director_allow_infected_bots & game_directorNoSpecials 设置
* @param set 是否关闭, 允许特感 Bot 为 1, 否则为 0
* @return void
**/
void setAllowInfectedBots(bool set) {
	if (set) {
		game_directorNoInfectedBots.SetBool(true);
		game_directorNoSpecials.SetBool(false);
		log.debugAndInfo("%s: 开启导演系统特感 Bot 刷新, 当前 director_allow_infected_bots 值为 %b, director_no_specials 值为 %b",
			PLUGIN_PREFIX, game_directorNoInfectedBots.BoolValue, game_directorNoSpecials.BoolValue);
	} else {
		game_directorNoInfectedBots.SetBool(false);
		game_directorNoSpecials.SetBool(true);
		log.debugAndInfo("%s: 关闭导演系统特感 Bot 刷新, 当前 director_allow_infected_bots 值为 %b, director_no_specials 值为 %b",
			PLUGIN_PREFIX, game_directorNoInfectedBots.BoolValue, game_directorNoSpecials.BoolValue);
	}
}

/**
* 检查是否需要进行特感轮换
* @param void
* @return bool
**/
bool isNeedToAlternate() {
	return g_hInfectedLimit.IntValue <= INF_ALTERNATIVE_MAX && !g_hSingleInfectedMode.BoolValue &&
			g_hUnreachSixAlternate.BoolValue;
}

/**
* 获取特感轮换类型集合
* @param void
* @return void
**/
void getInfectedClassList() {
	static int i, class, index;
	static InfectedState state;
	bool existClass[INFECTED_ARRAY_SIZE];

	infClassList.Clear();
	// 循环场上的特感类型, 放到 classList 中
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidInfected(i) || !IsPlayerAlive(i))
			continue;
		class = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (class < ZC_SMOKER || class > ZC_CHARGER)
			continue;
		index = infClassList.FindValue(class);
		if (index >= 0)
			continue;
		infClassList.Push(class);
	}
	// 循环状态集合中的特感
	for (i = 0; i < infStateList.Length; i++) {
		infStateList.GetArray(i, state, sizeof(state));
		class = state.class;
		index = infClassList.FindValue(class);
		if (index >= 0)
			continue;
		infClassList.Push(class);
	}
	// 补全特感类型
	for (i = 0; i < infClassList.Length; i++) {
		class = infClassList.Get(i);
		if (!existClass[class])
			existClass[class] = true;
	}
	for (i = 1; i < INFECTED_ARRAY_SIZE; i++) {
		if (!existClass[i])
			infClassList.Push(i);
	}
}