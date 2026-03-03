#if defined _state_bait_included_
    #endinput
#endif
#define _state_bait_included_

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#include "../setup.inc"
#include "../stocks.inc"
#include "./state.inc"

#define STATE_BAIT_NAME         "STATE_BAIT"
#define TARGET_PURSUIT_FACTOR   1.2       // 面对手持近战目标 Charger 后跳时, 此时目标若朝着 Charger 移动, Charger 后跳速度的加速倍数
#define TARGET_RETREAT_FACTOR   0.5       // 面对手持近战目标 Charger 后跳时, 此时目标若远离 Charger 移动, Charger 后跳速度的减速倍数

// =========================================================================
// State Bait 接近目标时的博弈状态 (dist < g_cvBhopMinDist.FloatValue 时进入 BAIT_STATE)
// 注册状态函数
// =========================================================================
stock void RegisterState_Bait() {
    ChargerState stateBait;
    strcopy(stateBait.name, sizeof(stateBait.name), "State_Bait");
    stateBait.OnEnter = StateBait_OnEnter;
    stateBait.OnUpdate = StateBait_OnUpdate;
    stateBait.OnExit = StateBait_OnExit;
    g_ChargerStates.PushArray(stateBait);
}

// ============================================================
// OnEnter 函数
// ============================================================
stock void StateBait_OnEnter(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Bait On Enter ===========", client);
}

// ============================================================
// OnUpdate 函数
// ============================================================
stock Action StateBait_OnUpdate(int client, int& buttons, float vel[3], float ang[3]) {
    if (!isAiCharger(client))
        return Plugin_Continue;
    if (IsPinningSurvivor(client))
        return Plugin_Continue;
    
    static int target;
    target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
        stateLog.error("(%s) Charger (%N)'s target %d is invalid", STATE_BAIT_NAME, client, target);
        return Plugin_Continue;
    }

    // 计算 charger 当前到目标的距离
    static float pos[3], targetPos[3], targetEyePos[3], dist;
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);
    GetClientEyePosition(target, targetEyePos);
    dist = getVectorDistance2D(pos, targetPos);
    // 是否可视目标
    static bool visible;
    visible = L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos);
    // 目标是否正在看着 charger
    // 除了目标之外还有多少生还者正在看着 charger
    static bool isWatching, isOnGround;
    static int watchers;
    isOnGround = IsClientOnGround(client);
    isWatching = isTargetWatchingCharger(client, target, g_cvTargetWatchMaxDeg.FloatValue);
    watchers = isAnySurvivorWatchingCharger(client, target, g_cvTargetWatchMaxDeg.FloatValue);
    // 目标威胁类型
    static TargetThreatType threatType;
    threatType = getTargetThreatType(client, target);

    // ============================================================
    // 进入博弈状态, 说明距离正常威胁目标距离小于 g_cvBhopMinDist.FloatValue
    // 距离手持近战目标距离小于 melee_range + g_cvMeleeBaitZoneMaxRange.FloatValue
    // 这时候先阻止冲锋, 并尝试右键挥拳, 若后续满足冲锋条件, 转换到冲锋状态
    // ============================================================
    buttons |= IN_ATTACK2;
    setChargerAbilityCooldown(client, 1.0);

    // ============================================================
    // 优先行动检查, 检测是否有更好的可以直接冲锋的目标, 如果有, 直接转换为冲锋状态
    // 这避免了如果在与手持近战的目标博弈时, 另一个生还者在 charger 身后疯狂输出的行为
    // 若 charger 身后突然出现另一个生还者, 且 charger 此时距离到他更近且他无法躲避冲锋, 直接向他冲锋, 否则, 继续朝着原目标冲锋
    // ============================================================
    if (isOnGround) {
        static int betterTarget;
        betterTarget = getChargeUnavoidableTarget(client, target, pos, dist, g_cvBhopMinDist.FloatValue);
        if (IsValidSurvivor(betterTarget) && IsPlayerAlive(betterTarget) &&
            isChargeAbilityReady(client) && !isChargePathBlocked(client, betterTarget))
        {
            stateLog.debugAll("Charger (%N) find a better charge target %N, transition to LOCKED STATE", client, betterTarget);
            g_AiChargers[client].m_iBetterTarget = GetClientUserId(betterTarget);
            g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
            return Plugin_Changed;
        }
    }

    // ============================================================
    // 检查是否需要退出博弈状态, 转移到接近状态
    // 1. 不可见目标时, 转换为接近状态
    // 2. 目标非手持近战, 且到目标距离大于 bhopMinDist + 容差距离, 转换为接近状态
    // 3. 目标手持近战, 且到目标距离大于 meleeRange + baitZoneMax, 出了博弈区, 转换为接近状态
    // ============================================================
    if (shouldExitBaitState(client, target, dist, visible, threatType)) {
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    // ============================================================
    // 如果当前目标已经被其他强控特感控制, hunter, charger
    // 中止转换到 CHARGING STATE, 停留在 BAIT 状态, 持续对目标挥拳
    // ============================================================
    if (isSurvivorPinned(target)) {
        // stateLog.debugAll("Charger (%N)'s target (%N) is pinned! Suspending charge, melee to it", client, target);
        return Plugin_Continue;
    }

    // ============================================================
    // 根据威胁类型分别处理
    // ============================================================
    static Action resAction;
    if (threatType == Threat_Melee) {
        resAction = handleMeleeThreat(client, target, dist, visible, isWatching, watchers, buttons);
    } else if (threatType == Threat_Shotgun) {
        resAction = handleShotgunThreat(client, target, dist, visible);
    } else {
        resAction = handleNonMeleeThreat(client, target, dist, visible);
    }
    return resAction;
}

/**
* 是否应该退出博弈状态, 转换为 APPROACH State
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param visible 是否可见
* @param threatType 目标威胁类型
* @return bool
**/
bool shouldExitBaitState(int client, int target, float dist, bool visible, TargetThreatType threatType) {
    if (!isAiCharger(client) || !IsValidSurvivor(target) || !IsPlayerAlive(target))
        return true;

    static float minDist;
    minDist = g_cvBhopMinDist.FloatValue + STATE_TOLERANCE_DIST;
    // 失去目标视野, 转换为 APPROACH STATE
    if (!visible) {
        stateLog.debugAll("Charger (%N) lost the sight of target (%N), transition to APPROACH STATE", client, target);
        return true;
    }
    // 目标非手持近战, 且到目标距离大于 g_cvBhopMinDist.FloatValue + 容差距离, 转换为 APPROACH STATE
    if (threatType != Threat_Melee && dist > minDist) {
        stateLog.debugAll("Charger (%N), target (%N), distance %.2f > min dist %.2f, transition to APPROACH STATE", client, target, dist, minDist);
        return true;
    }
    // 目标手持近战, 且到目标距离大于 meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue, 转换为 APPROACH STATE
    static float meleeRange;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    minDist = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue + STATE_TOLERANCE_DIST;
    if (threatType == Threat_Melee && dist > minDist) {
        stateLog.debugAll("Charger (%N), target (%N) holding melee, dist %.2f > baitZoneMax %.2f, transition to APPROACH STATE", client, target, dist, minDist);
        return true;
    }
    return false;
}

/**
* Charger 面对手持近战目标时的处理逻辑
* 1. 若目标没有看着 Charger, 且没有其他人看着 Charger, 处在博弈区内, 概率冲锋
* 2. 目标处于易受攻击状态, 直接冲锋
* 3. 目标不处于易受攻击状态, Charger 血量大于近战斩杀线时, 概率冲锋
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param visible 是否可见目标
* @param isWatching 目标是否正在看着 Charger
* @param watchers 正在看着 Charger 的人数
* @return void
**/
Action handleMeleeThreat(int client, int target, float dist, bool visible, bool isWatching, int watchers, int& buttons) {
    static int health;
    health = GetEntProp(client, Prop_Data, "m_iHealth");

    static float meleeRange, baitZoneMin, baitZoneMax;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    baitZoneMin = meleeRange + g_cvMeleeBaitZoneMinRange.FloatValue;
    baitZoneMax = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue;

    static Action resAction;
    // 在博弈区内, 根据条件决定冲锋或者后退
    if (dist <= baitZoneMax) {
        static bool shouldCharge;
        shouldCharge = shouldChargeInMeleeBait(client, target, health, visible, isWatching, watchers);
        // Charger 距离目标距离小于 baitZoneMax 博弈区最大范围, 决定是否冲锋
        if (shouldCharge && isChargeAbilityReady(client)) {
            stateLog.debugAll("Charger (%N) melee bait: charging holding melee target (%N), dist %.2f, transition to LOCKED STATE", client, target, dist);
            g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
            resAction = Plugin_Continue;
        } else if (!shouldCharge && dist <= baitZoneMin && isChargeAbilityReady(client)) {
            // 进入危险区内, 若此时不应冲锋, 且能力已准备就绪, 则执行向后跳的逻辑
            // 若能力未准备就绪, 则不执行后跳逻辑, 继续接近尝试打拳
            resAction = performBackwardBhop(client, target, visible, buttons);
        }
    }
    return resAction;
}

/**
* Charger 在面对手持近战的目标时, 且距离处于博弈区内 (baitZoneMin, baitZoneMax], 判断是否冲锋
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param health Charger 生命值
* @param isWatching 目标是否正在看着 Charger
* @param watchers 正在看着 Charger 的人数
* @return bool
**/
bool shouldChargeInMeleeBait(int client, int target, int health, bool visible, bool isWatching, int watchers) {
    // 能力未就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return false;
    // 0. 无目标视野, 不允许冲锋
    if (!visible)
        return false;
    // 1. 目标手持近战, 但是没有看着自己, 且没有其他生还者看着自己, 概率冲锋
    if (!isWatching && watchers <= 0 && isChargerProbCharge(client))
        return true;
    // 2. 目标手持近战, 且处于易受攻击状态, 直接冲锋
    if (isTargetVulnerable(client, target))
        return true;
    // 3. 目标手持近战, 且不处于易受攻击状态, Charger 血量大于近战斩杀线时, 概率冲锋
    static int meleeDamageCharger;
    meleeDamageCharger = !cvMeleeDamageCharger ? DEFAULT_MELEE_DMG_CHARGER : cvMeleeDamageCharger.IntValue;
    if (health > meleeDamageCharger && isChargerProbCharge(client))
        return true;
    return false;
}

/**
* Charger 在面对手持近战目标时, 执行向后连跳操作
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param visible 是否可见目标
* @return Action
**/
Action performBackwardBhop(int client, int target, bool visible, int& buttons) {
    // 计算后退方向
    static float eyeAng[3], vFwd[3], vBack[3];
    GetClientEyeAngles(client, eyeAng);
    GetAngleVectors(eyeAng, vFwd, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(vFwd, vFwd);
    NegateVector(vFwd);
    vBack = vFwd;
    vBack[2] = 0.0;

    // 获取 runTopSpeed 作为基础速度
    static float baseSpeed;
    baseSpeed = SDKCall(g_hSdkGetRunTopSpeed, client);

    // 计算目标速度在 charger 后退方向上的投影, dot > 0 表示目标在追 charger, dot < 0 表示目标远离 charger
    static float targetAbsVel[3], approachSpeed;
    GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", targetAbsVel);
    targetAbsVel[2] = 0.0;
    approachSpeed = GetVectorDotProduct(targetAbsVel, vBack);
    
    // 计算 charger 需要的后退速度
    static float backSpeed;
    // backSpeed = baseSpeed + g_cvBhopImpulse.FloatValue;
    backSpeed = baseSpeed;
    if (approachSpeed > 0.0) {
        // approachSpeed > 0, 目标在追 charger, 在 backSpeed 速度上叠加目标的速度, 保持相对距离
        // 如果想要后跳的更远, 可以改成 += approachSpeed * TARGET_PURSUIT_FACTOR;
        backSpeed += TARGET_PURSUIT_FACTOR;
    } else {
        // approachSpeed < 0, 目标远离 charger, 在 backSpeed 速度上叠加目标速度 (approachSpeed 是负数, 因此是减速), 减少距离
        // 控制减速大小, 0.5 表示在 backSpeed 基础上减速目标速度的 50%
        backSpeed += approachSpeed * TARGET_RETREAT_FACTOR;
    }
    // 应用缩放
    ScaleVector(vBack, backSpeed);

    // 连跳后退的落点不安全的时候, 则转为冲锋状态
    if (!nextTickPosCheck(client, vBack, visible) &&
        !isChargePathBlocked(client, target) &&
        isChargeAbilityReady(client)
    ) {
        stateLog.debugAll("Charger (%N) bait to holding melee target (%N), backward jump unsafe, transition to LOCKED STATE", client, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
        return Plugin_Continue;
    }

    // 连跳落点安全, 继续向后连跳
    if (IsClientOnGround(client) && allowToBhop(client)) {
        stateLog.debugAll("Charger (%N) bait to holding melee target (%N), performing backward bunnyhop, speed %.2f", client, target, backSpeed);
        buttons |= IN_DUCK;
        buttons |= IN_JUMP;
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vBack);
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

/**
* Charger 面对手持霰弹枪的目标的处理逻辑
* 1. 若目标手持霰弹枪, Charger 到目标距离小于 bhopMinDist, 直接冲锋
* @param client 玩家索引
* @param target 目标索引
* @param dist 距离
* @param visible 是否可见目标
* @return Action
**/
Action handleShotgunThreat(int client, int target, float dist, bool visible) {
    // 能力未就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return Plugin_Continue;
    // 无目标视野, 或者距离大于 bhopMinDist, 不允许冲锋
    if (!visible || dist > g_cvBhopMinDist.FloatValue)
        return Plugin_Continue;
    // 能力未就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return Plugin_Continue;

    stateLog.debugAll("Charger (%N) handling shotgun threat, charging to target (%N), transition to LOCKED STATE", client, target);
    g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
    return Plugin_Continue;
}

/**
* Charger 面对手持非近战, 非霰弹枪的目标的处理逻辑
* 1. 目标没有看着 Charger, 且没有其他人看着 Charger, 继续接近挥拳, 同时概率冲锋
* 2. 目标处于易受攻击状态, 直接冲锋
* 3. 无论目标有没有看着 Charger, 若血量大于近战斩杀线, 概率冲锋, 小于则直接冲锋
* @param client 客户端索引
* @param target 目标索引
* @param dist 距离
* @param health Charger 生命值
* @param visible 是否可见目标
* @param meleeDamage Charger 近战斩杀线
* @param watchers 正在看着 Charger 的人数
* @return Action
**/
Action handleNonMeleeThreat(int client, int target, float dist, bool visible) {
    // 能力未准备就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return Plugin_Continue;
    // 无目标视野, 或距离大于最小连跳允许距离, 不允许冲锋
    if (!visible || dist > g_cvBhopMinDist.FloatValue)
        return Plugin_Continue;
    // 能力未就绪, 不允许冲锋
    if (!isChargeAbilityReady(client))
        return Plugin_Continue;

    // 如果目标处于易受攻击状态, 直接冲锋
    if (isTargetVulnerable(client, target)) {
        stateLog.debugAll("Charger (%N) handling non-melee threat: target (%N) vulnerable, charging", client, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
        return Plugin_Continue;
    }
    // 血量条件
    static int health, meleeDamageCharger;
    health = GetEntProp(client, Prop_Data, "m_iHealth");
    meleeDamageCharger = !cvMeleeDamageCharger ? DEFAULT_MELEE_DMG_CHARGER : cvMeleeDamageCharger.IntValue;
    if (health > meleeDamageCharger && isChargerProbCharge(client)) {
        stateLog.debugAll("Charger (%N) handling non-melee: health %d > melee damage charger %d, probabilistic charge to (%N)", client, health, meleeDamageCharger, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
    } else if (health <= meleeDamageCharger) {
        stateLog.debugAll("Charger (%N) handling non-melee: health %d <= melee damage charger %d, instant charge to (%N)", client, health, meleeDamageCharger, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
    }
    return Plugin_Continue;
}

// ============================================================
// OnExit 函数
// ============================================================
stock void StateBait_OnExit(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Bait On Exit ===========", client);
}