#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <treeutil>
#include <logger2>
#include <actions>

// For debug print vector direction, positon
// #include <vector_show>

#include "./setup.inc"
#include "./stocks.inc"
#include "./state/state.inc"

// 将插件日志前缀改成自己插件的日志前缀
#define PLUGIN_PREFIX "AI-Charger3"

#define ACT_NAME_CHARGER_EVADE		"ChargerEvade"
#define ACT_NAME_CHARGE_AT_VICTIM 	"ChargerChargeAtVictim"

ConVar
	g_cvPluginName,
	g_cvLogLevel;

Logger
	log;

public Plugin myinfo = 
{
	name 			= "Ai-Charger 3.0",
	author 			= "夜羽真白",
	description 	= "Ai Charger 增强 3.0 版本",
	version 		= "1.0.0.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

public void OnPluginStart() {
	// allow charger to bhop?
	g_cvBhop = CreateConVar("ai_charger3_bhop", "1", "是否允许 Charger 进行在接近状态时连跳操作, 0=禁止, 1=允许", CVAR_FLAGS, true, 0.0, true, 1.0);
	// charger is allowed to bhop when its distance from the target is between [ai_charger3_bhop_min_dist, ai_charger3_bhop_max_dist], if the distance is less than this value, charger will transition to bait state
	g_cvBhopMinDist = CreateConVar("ai_charger3_bhop_min_dist", "75.0", "禁止连跳的最小距离, 小于这个距离转换为博弈状态", CVAR_FLAGS, true, 0.0);
	g_cvBhopMaxDist = CreateConVar("ai_charger3_bhop_max_dist", "9999.0", "允许连跳的最大距离", CVAR_FLAGS, true, 0.0);
	// the bhop impulse, when charger is allowed to bhop, each time it jumps up from the ground, it will gain a speed impulse with the value of ai_charger3_bhop_impulse
	g_cvBhopImpulse = CreateConVar("ai_charger3_bhop_impulse", "100.0", "连跳的加速度", CVAR_FLAGS, true, 0.0);
	// when charger's speed is greater than 'ai_charger3_bhop_min_speed', it is allowed to bhop, and its max bhop speed will not greater than 'ai_charger3_bhop_max_speed'
	g_cvBhopMinSpeed = CreateConVar("ai_charger3_bhop_min_speed", "200", "允许连跳的最小速度", CVAR_FLAGS, true, 0.0);
	g_cvBhopMaxSpeed = CreateConVar("ai_charger3_bhop_max_speed", "1000", "连跳的最大限制速度", CVAR_FLAGS, true, 0.0);
	// Whether charger is allowed to perform bhop before charging. 0=Disabled, 1=Enabled
	g_cvBhopBeforeCharge = CreateConVar("ai_charger3_bhop_before_charge", "1", "是否允许在冲锋前进行连跳, 0=禁止, 1=允许", CVAR_FLAGS, true, 0.0, true, 1.0);
	// when charger has no vision of the target survivor, allow it to bhop?
	g_cvBhopNoVision = CreateConVar("ai_charger3_bhop_no_vision", "1", "是否允许Charger无目标视野时进行连跳, 0=禁止, 1=允许", CVAR_FLAGS, true, 0.0, true, 1.0);
	// when charger has no sight of target, it is allowed to bhop when its speed vector and eye angle forward vector within this degree
	g_cvBhopNoVisionMaxAng = CreateConVar("ai_charger3_bhop_nvis_maxang", "90.0", "无生还者视野时速度向量与视角前向向量在这个角度范围内, 允许连跳", CVAR_FLAGS, true, 0.0);
	// when the vector of charger to target and charger's eye angle forward vector within this degree, consider the target is looking at charger
	g_cvTargetWatchMaxDeg = CreateConVar("ai_charger3_target_watch_maxdeg", "22.5", "目标视角与到 Charger 位置向量夹角小于这个值时, 认为目标正在看着 Charger", CVAR_FLAGS, true, 0.0, true, 180.0);
	// when the distance between charger and target is less than this value, disable left/right strafing offset of charger's bhop direction
	g_cvBhopStrafeMinDist = CreateConVar("ai_charger3_bhop_strafe_mindist", "400.0", "与目标小于这个距离时, 禁止连跳方向左右偏移", CVAR_FLAGS, true, 0.0);
	// the minimum angle of random left/right strafing offset for charger's bhop direction. Enable if greater than 0.0, disable this feature if set to -1.0
	g_cvBhopStrafeMinDeg = CreateConVar("ai_charger3_bhop_strafe_mindeg", "30.0", "Charger 连跳方向左右随机偏移 (侧向连跳) 的最小偏移角度, 大于 0.0 启用, -1.0 禁用此功能", CVAR_FLAGS, true, -1.0);
	// the maximum angle of random left/right strafing offset for charger's bhop direction
	g_cvBhopStrafeMaxDeg = CreateConVar("ai_charger3_bhop_strafe_maxdeg", "55.0", "Charger 侧向连跳的最大角度", CVAR_FLAGS, true, 0.0, true, 89.0);
	// The minimum distance from target required for charger to perform single strafe bhop (bhopping is disabled when closer than this distance)
	g_cvBhopStrafeOnceDist = CreateConVar("ai_charger3_bhop_strafe_once_dist", "200.0", "允许 Charger 侧向连跳一次的最小距离 (距离目标点小于这个距离不允许侧向连跳)", CVAR_FLAGS);
	// The minimum distance from target required for charger to perform double strafe bhop (bhopping is disabled when closer than this distance)
	g_cvBhopStrafeTwiceDist = CreateConVar("ai_charger3_bhop_strafe_twice_dist", "400.0", "允许 Charger 侧向连跳两次的最小距离 (距离目标点大于这个距离才允许侧向连跳两次)", CVAR_FLAGS);
	// when the target is holding a melee weapon, the minimum range of the melee bait zone (calculated as melee_range plus this value)
	g_cvMeleeBaitZoneMinRange = CreateConVar("_ai_charger3_melee_bait_minrange", "15.0", "目标拿着近战时, 近战博弈区的最小范围, melee_range + 这个值", CVAR_FLAGS, true, 0.0);
	// when the target is holding a melee weapon, the maximum range of the melee bait zone (calculated as melee_range plus this value)
	g_cvMeleeBaitZoneMaxRange = CreateConVar("_ai_charger3_melee_bait_maxrange", "50.0", "目标拿着近战时, 近战博弈区的最大范围, melee_range + 这个值", CVAR_FLAGS, true, 0.0);
	// when the angle between charger's air velocity direction and the direction from charger to target exceeds this value, perform air velocity modification (air modification: set charger's current velocity direction to the target direction)
	g_cvAirVecModifyMinDegree = CreateConVar("ai_charger3_airvec_modify_min_deg", "45.0", "在空中速度方向与自身到目标方向角度超过这个值进行速度修正", CVAR_FLAGS, true, 0.0);
	// When the angle between charger's air velocity direction and the direction from charger to target exceeds this value, abandon air velocity modification
	g_cvAirVecModifyMaxDegree = CreateConVar("ai_charger3_airvec_modify_max_deg", "180.0", "在空中速度方向与自身到目标方向角度超过这个值放弃速度修正", CVAR_FLAGS, true, 0.0);
	// the interval (in seconds) between consecutive air velocity vector modifications for charger
	g_cvAirVecModifyInterval = CreateConVar("ai_charger3_airvec_modify_interval", "0.3", "空中速度修正间隔", CVAR_FLAGS, true, 0.0);
	// The interpolation factor for charger's air velocity direction modification. Min: 0.0, Max: 1.0. Lower values result in smoother air turning, higher values result in sharper air turning
	g_cvAirVecModifyLerp = CreateConVar("_ai_charger3_airvec_modify_lerp", "0.3", "空中速度方向修正的修正插值因子, 0.1~1.0, 越小转向越平滑, 但是需要更多的帧数, 越大转向越锐利, 需要较少的帧数就可以完成空中转向", CVAR_FLAGS, true, 0.0, true, 1.0);
	// the maximum allowed duration (in seconds) for charger to stay in the bait state
	g_cvBaitMaxDuration = CreateConVar("ai_charger3_bait_max_duration", "7.0", "Charger 进入博弈状态的最大允许时间", CVAR_FLAGS, true, 0.0);
	// the detection interval (in seconds) for charger's probabilistic charge when in the bait state
	g_cvProbChargeChkDur = CreateConVar("ai_charger3_prob_charge_chk_dur", "1.0", "Charger 进入博弈状态概率冲锋的检测间隔", CVAR_FLAGS, true, 0.0);
	// the probability (0.0 to 1.0) of charger performing a probabilistic charge when in the bait state
	g_cvProbChargeProb = CreateConVar("ai_charger3_prob_charge_prob", "0.5", "Charger 进入博弈状态概率冲锋的概率", CVAR_FLAGS, true, 0.0);
	// whether to prohibit charger from retreating: 0=Disabled (allow retreat), 1=Enabled (forbid retreat)
	g_cvAntiRetreat = CreateConVar("ai_charger3_anti_retreat", "1", "是否禁止 Charger 逃跑, 0=禁止, 1=允许", CVAR_FLAGS, true, 0.0, true, 1.0);
	// The maximum depth of path segments that charger will look ahead when it is on ground and preparing to bhop (0 = disabled). Controls how far ahead charger scans the current PATH to find suitable landing spots before hopping from ground
	g_cvPathLookAheadMaxDepth = CreateConVar("ai_charger3_path_lookahead_maxdepth", "10", "Charger 向前搜索以当前速度可以一步到达的 PathSegment 的最大深度", CVAR_FLAGS, true, 0.0);

	// 将插件名称改成自己插件名称
	g_cvPluginName = CreateConVar("ai_charger3_plugin_name", "ai_charger3");

	char cvName[64];
	g_cvPluginName.GetString(cvName, sizeof(cvName));
	FormatEx(cvName, sizeof(cvName), "%s_log_level", cvName);
	// log recording level: 1=Disabled, 2=Console output, 4=Log file output, 8=Chat box output, 16=Server console output, 32=Error file output. Values can be added together for multiple outputs
	g_cvLogLevel = CreateConVar(cvName, "38", "日志记录级别, 1=关闭, 2=控制台输出, 4=log文件输出, 8=聊天框输出, 16=服务器控制台输出, 32=error文件输出, 数字相加", CVAR_FLAGS);

	HookEvent("round_start", evtRoundStart);
	HookEvent("round_end", evtRoundEnd);
	HookEvent("player_spawn", evtPlayerSpawn, EventHookMode_Pre);

	log = new Logger(PLUGIN_PREFIX, g_cvLogLevel.IntValue);

	// 子模块初始化
	SetUp_OnModuleStart();
	State_OnModuleStart(g_cvPluginName);
	Stock_OnModuleStart(g_cvPluginName);
}

public void OnPluginEnd() {
	SetUp_OnModuleEnd();
	State_OnModuleEnd();
	Stock_OnModuleEnd();
	delete log;
}

public void OnAllPluginsLoaded() {
	SetUp_OnAllPluginsLoaded();
}

public void OnConfigsExecuted() {
	SetUp_OnConfigsExecuted();
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon) {
	if (!isAiCharger(client))
		return Plugin_Continue;

	if (GetEntityMoveType(client) == MOVETYPE_LADDER) {
		buttons &= ~IN_JUMP;
		buttons &= ~IN_DUCK;
	}

	static int ability;
	ability = getChargeAbilityEnt(client);
	if (!IsValidEdict(ability))
		return Plugin_Continue;
	static bool isCharging;
	isCharging = view_as<bool>(GetEntProp(ability, Prop_Send, "m_isCharging"));
	if (isCharging && g_AiChargers[client].m_bChargeDelayed)
		g_AiChargers[client].m_bChargeDelayed = false;
	
	static int target;
	target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
	if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
		return Plugin_Continue;

	if (g_ChargerStateContext[client].userId != GetClientUserId(client)) {
		g_AiChargers[client].init();
		// 目标变化, 重置状态
		g_ChargerStateContext[client].init(client);
		g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
	}

	// 执行当前状态的每帧行为更新操作
	return g_ChargerStateContext[client].update(buttons, vel, angles);
}

void evtRoundStart(Event event, const char[] name, bool dontBroadcast) {

}

void evtRoundEnd(Event event, const char[] name, bool dontBroadcast) {

}

void evtPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	static int client;
	client = GetClientOfUserId(event.GetInt("userid"));
	if (!isAiCharger(client))
		return;
	
	// 新的 charger, 重置状态
	g_AiChargers[client].init();
	g_ChargerStateContext[client].init(client);
	g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
}

public void OnMapStart() {
	// vectorShowOnMapStart();
}

public void OnMapEnd() {

}

public Action L4D2_OnChooseVictim(int client, int &curTarget) {
	if (!isAiCharger(client))
		return Plugin_Continue;
	if (!IsValidSurvivor(curTarget) || !IsPlayerAlive(curTarget))
		return Plugin_Continue;
	
	// 记录目标 userId
	g_AiChargers[client].m_iTarget = GetClientUserId(curTarget);
	return Plugin_Continue;
}

// PathFollower::Update(long double a1@<st0>, PathFollower *this, INextBot *a3)
// PathFollower::Update 首次执行晚于 OnPlayerRunCmd, 并且频率大概是 OnPlayerRunCmd 的 1/3
MRESReturn Detour_PathFollower_Update(Address pThis, Handle hParams) {
	if (!pThis) {
		stateLog.error("Detour for signature: %s got null this pointer", SIG_PATH_FOLLOWER_UPDATE);
		return MRES_Ignored;
	}
	if (!hParams) {
		stateLog.error("Detour for signature: %s got null params handle", SIG_PATH_FOLLOWER_UPDATE);
		return MRES_Ignored;
	}

	// 首先获取 client index
	static Address pNextBot;
	pNextBot = view_as<Address>(DHookGetParam(hParams, 1));
	if (!pNextBot) {
		stateLog.error("Detour for signature: %s got null parameter 1: nextbot pointer", SIG_PATH_FOLLOWER_UPDATE);
		return MRES_Ignored;
	}
	static int client;
	client = SDKCall(g_hSdkNextBotGetCombatCharacter, pNextBot);
	if (!isAiCharger(client))
		return MRES_Ignored;

	// 保存 IPathFollower 与 NextBot 指针, 用于手动触发 PathFollower::Update
	g_AiChargers[client].m_pPathFollower = pThis;
	g_AiChargers[client].m_pNextBot = pNextBot;

	// v37 = *((_DWORD *)this + 4566); 因为 this 被转成了 DWORD 类型, 因此后面的偏移量 4566 也是基于 4 字节的
	static Address pPathSeg, pNextSeg, pLastSeg;
	static PathSegment curSegment, nextSegment, lastSegment;
	// Current Segment struct
	pPathSeg = view_as<Address>(SDKCall(g_hSdkPathGetCurGoal, pThis));
	if (!pPathSeg) {
		g_AiChargers[client].m_PathSegment.init();
		return MRES_Ignored;
	} else {
		constructPathSegment(pPathSeg, curSegment);
		g_AiChargers[client].m_PathSegment = curSegment;
	}

	// Next Segment struct
	pNextSeg = view_as<Address>(SDKCall(g_hSdkPathNextSegment, pThis, pPathSeg));
	if (!pNextSeg) {
		g_AiChargers[client].m_NextPathSegment.init();
	} else {
		constructPathSegment(pNextSeg, nextSegment);
		g_AiChargers[client].m_NextPathSegment = nextSegment;
	}

	// Last Segment struct
	// class PathFollower : public Path; PathFollower 继承自 Path, 可以使用 Path 类中的虚函数 Path::LastSegment
	pLastSeg = view_as<Address>(SDKCall(g_hSdkPathLastSegment, pThis));
	if (!pLastSeg) {
		g_AiChargers[client].m_LastPathSegment.init();
	} else {
		constructPathSegment(pLastSeg, lastSegment);
		g_AiChargers[client].m_LastPathSegment = lastSegment;
	}

	return MRES_Ignored;
}

// ============================================================
// Action Extension
// ============================================================
public void OnActionCreated(BehaviorAction action, int actor, const char[] name) {
	if (action == INVALID_ACTION || !isAiCharger(actor))
		return;

	if (g_cvAntiRetreat.BoolValue) {
		if (strcmp(name, ACT_NAME_CHARGER_EVADE, false) == 0) {
			action.OnUpdate = chargerEvade_OnUpdate;
		}
	}
	// 防止 charger 刷新距离生还者很近时, 游戏强制冲撞, 但是 APPROACH STATE 同时将 Charger 能力就绪时间设置为 1 秒后, 导致 Charger 原地卡住
	if (strcmp(name, ACT_NAME_CHARGE_AT_VICTIM, false) == 0) {
		action.OnUpdate = chargerChargeAtVictim_OnUpdate;
	}
}

Action chargerEvade_OnUpdate(BehaviorAction action, int actor, float interval, ActionResult result) {
	if (!isAiCharger(actor))
		return Plugin_Continue;
	if (isChargerCharging(actor))
		return Plugin_Continue;
	// 撞停准备控人的时候有时候会触发 Evade 行为
	if (IsValidSurvivor(L4D2_GetQueuedPummelVictim(actor)) || IsValidSurvivor(L4D_GetVictimCharger(actor)) || IsValidSurvivor(L4D_GetVictimCarry(actor)))
		return Plugin_Continue;

	static int target;
	target = GetClientOfUserId(g_AiChargers[actor].m_iTarget);
	if (!IsValidSurvivor(target)) {
		g_AiChargers[actor].m_bMove2NewTarget = false;
		return Plugin_Continue;
	}
	
	static float targetPos[3];
	GetClientAbsOrigin(target, targetPos);
	
	/*
		不知道什么原因, Hook ChargerEvade 行为的 OnUpdate 函数, 并从中创建 BehaviorMoveTo 行为, OnActionCreated 不会感知到 BehaviorMoveTo 被创建, 但通过 nb_debug BEHAVIOR 可以看到 BehaviorMoveTo 行为节点已经被创建, 但是下一帧立刻被销毁, 无法通过 Smoker 那种通过 BehaviorMoveTo 直接控制 Charger 移动, 因此强行接管 ChargerEvade 行为, 使用 SdkCall 获取 INextBot 指针, 进而获取 ILocomotion 指针, 调用 Locomotion 的 Approach 和 FaceTowards 函数实现强制移动

		Charger 继承自 CBaseEntity, Charger 类的指针可以向上转型成 CBaseEntity, 为了防止有时候寻路未触发, g_AiChargers[actor] 中的 pNextBot 指针无效影响该功能, 因此直接通过 SdkCall 调用 CBaseEntity::MyNextBotPointer 获取 INextBot 指针
		执行 CBaseEntity::MyNextBotPointer() 实际上是调用实现类 NextBotCombatCharacter 的 NextBotCombatCharacter::MyNextBotPointer(NextBotCombatCharacter *this)
	*/
	static Address pNextBot;
	pNextBot = view_as<Address>(SDKCall(g_hSdkMyNextBotPointer, GetEntityAddress(actor)));
	if (!pNextBot)
		return Plugin_Continue;

	// 获取 Locomotion 行动组件的指针
	static Address pLocomotion;
	pLocomotion = view_as<Address>(SDKCall(g_hSdkGetLocomotionInterface, pNextBot));
	if (!pLocomotion)
		return Plugin_Continue;
	
	// Approach & FaceTowards
	SDKCall(g_hSdkLocomotionApproach, pLocomotion, targetPos, 1.0);
	/*
		FaceTowards 的参数并不是一个单位方向向量, 而是一个需要看向的坐标点
		传入一个坐标点 target, NextBot 的实现代码:
			Vector look( target.x, target.y, GetBot()->GetEntity()->EyePosition().z );
			GetBot()->GetBodyInterface()->AimHeadTowards( look, IBody::BORING, 0.1f, NULL, "Body facing" );
		可以用 TeleportEntity 设置视角, 单纯想玩 FaceTowards
	*/
	SDKCall(g_hSdkLocomotionFaceTo, pLocomotion, targetPos);
	return Plugin_Handled;
}

Action chargerChargeAtVictim_OnUpdate(BehaviorAction action, int actor, float interval, ActionResult result) {
	if (!isAiCharger(actor))
		return Plugin_Continue;

	/*
		防止 Charger 刷新后满足冲锋条件, 引擎立即让其冲锋, 但插件进入 APPROACH STATE 会设置能力延时, 导致其无法进行冲锋而在原地罚站
		既然插件接管了, 就必须在 CHARGING STATE 中手动冲锋, 其他不在 CHARGING STATE 中的冲锋都视为非法, 直接停止
	*/
	static int curState;
	curState = g_ChargerStateContext[actor].currentStateId;
	if (curState != CH_STATE_CHARGING) {
		log.debugAll("Charger (%N) try to charge, but in approach state, force stop charge", actor);
		action.Done();
		return Plugin_Changed;
	}
	return Plugin_Continue;
}