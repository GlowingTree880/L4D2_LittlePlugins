#if defined _state_charging_included_
    #endinput
#endif
#define _state_charging_included_

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#include "../setup.inc"
#include "../stocks.inc"
#include "./state.inc"

#define STATE_CHARGING_NAME                     "STATE_CHARGING"
#define PREDICT_MAX_LATERAL_OFFSET              45.0    // 冲锋位置横向预测最大值
#define PREDICT_MAX_TIME                        0.5     // charger 冲锋时预测目标位置的最大预测时间
#define CHARGE_DIST_TOLERANCE                   10.0    // 开始冲锋距离容差, 500 速度冲锋目标无法躲避距离大概是 36 左右, 有点小, 导致 charger 一直连跳无法冲锋, 增加一点容差

// =========================================================================
// State Charging 冲锋状态, Charger 以 500 速度冲锋目标无法躲避的距离大概在 36.0 左右
// 但是连跳到这个距离之内再冲撞是十分困难的, 大多时候都是在空中达到这个距离, 由于目标
// 持续的移动, Charger 落地时可能已经大于这个距离, 因此无法 100% 冲锋命中, 建议安装 air_ability patch
// 注册状态函数
// =========================================================================
stock void RegisterState_Charging() {
    ChargerState stateCharging;
    strcopy(stateCharging.name, sizeof(stateCharging.name), "State_Charging");
    stateCharging.OnEnter = StateCharging_OnEnter;
    stateCharging.OnUpdate = StateCharging_OnUpdate;
    stateCharging.OnExit = StateCharging_OnExit;
    g_ChargerStates.PushArray(stateCharging);
}

// ============================================================
// OnEnter 函数
// ============================================================
stock void StateCharging_OnEnter(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Charging On Enter ===========", client);
    // 确保每次进入冲锋决策逻辑时, 都有机会执行一次最后的连跳
    g_AiChargers[client].m_bBhopBeforeCharge = false;
}

// ============================================================
// OnUpdate 函数
// ============================================================
stock Action StateCharging_OnUpdate(int client, int& buttons, float vel[3], float ang[3]) {
    if (!isAiCharger(client))
        return Plugin_Continue;
    
    static int target, betterTarget;
    target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
    betterTarget = GetClientOfUserId(g_AiChargers[client].m_iBetterTarget);
    // 检查更好的目标是否有效
    target = (IsValidSurvivor(betterTarget) && IsPlayerAlive(betterTarget)) ? betterTarget : target;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
        stateLog.debugAll("(%s) Charger (%N)'s target %d is invalid, transition to APPROACH STATE", STATE_CHARGING_NAME, client, target);
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    // 获取当前速度
    static float vVel[3], speed;
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
    speed = getVectorLength2D(vVel);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
    // 是否在地上
    static bool isOnGround;
    isOnGround = IsClientOnGround(client);
    // 计算 charger 当前到目标的距离
    static float pos[3], eyePos[3], targetPos[3], targetEyePos[3], dist;
    L4D_GetEntityWorldSpaceCenter(client, pos);
    L4D_GetEntityWorldSpaceCenter(target, targetPos);
    GetClientEyePosition(client, eyePos);
    GetClientEyePosition(target, targetEyePos);
    dist = getVectorDistance2D(pos, targetPos);
    // 是否可视目标
    static bool visible;
    visible = L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos);
    // 目标威胁类型
    static TargetThreatType threatType;
    threatType = getTargetThreatType(client, target);
    // 是否正在冲锋
    static bool isCharging, isPinning;
    isCharging = isChargerCharging(client);
    isPinning = (IsValidSurvivor(L4D2_GetQueuedPummelVictim(client)) || IsValidSurvivor(L4D_GetVictimCharger(client)) || IsValidSurvivor(L4D_GetVictimCarry(client)));

    // ============================================================
    // 冲锋中或者正在控人, 不处理后续逻辑
    // ============================================================
    if (isCharging || isPinning)
        return Plugin_Continue;

    // ============================================================
    // 检查是否需要切换到其他状态
    // ============================================================
    if (shouldExitChargingState(client, target, dist, visible, threatType)) {
        g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        return Plugin_Continue;
    }

    // ============================================================
    // 如果当前位置距离生还者 z 轴高度大于 CHARGE_THRESHOLD, 不允许冲锋
    // ============================================================
    if (FloatAbs(pos[2] - targetPos[2]) > CHARGE_Z_THRESHOLD)
        return Plugin_Continue;

    // 处理冲锋结束或控人结束时的能力未就绪的情况, 切换到其他状态
    if (!isChargeAbilityReady(client)) {
        handleAbilityNotReady(client, target, dist, threatType);
        return Plugin_Continue;
    }

    // ============================================================
    // 能力准备就绪, 发起冲锋
    // ============================================================

    // 获取目标当前速度
    static float chargeSpeed, targetAbsVel[3];
    chargeSpeed = !cvChargeSpeed ? DEFAULT_CHARGE_SPEED : cvChargeSpeed.FloatValue;
    GetEntPropVector(target, Prop_Data, "m_vecAbsVelocity", targetAbsVel);

    // 计算 CHARGING 状态下连跳停止的距离阈值 (目标无法躲避冲锋的距离) Mins[0] * chargeSpeed / targetSpeed
    // (dist / chargeSpeed) * targetSpeed <= Mins[0]
    static float lastBhopDist, targetSpeed;
    targetSpeed = getVectorLength2D(targetAbsVel);
    lastBhopDist = (16.0 * chargeSpeed) / (targetSpeed > 0.0 ? targetSpeed : DEFAULT_SURVIVOR_SPEED);
    lastBhopDist += CHARGE_DIST_TOLERANCE;

    // 预测冲锋方向
    static float predictPos[3];
    calculatePredictedPosition(pos, targetPos, targetAbsVel, dist, chargeSpeed, predictPos);

    // For debug print target predict position
    /* float eyePos[3];
    GetClientEyePosition(client, eyePos);
    ShowDir(COLOR_GREEN, eyePos, predictPos); */

    if (isOnGround) {
        // 在地上时, 判断是否需要再次进行连跳接近生还者, 以到达生还者无法躲避的距离
        if (shouldBhopBeforeCharge(client, target, dist, visible, lastBhopDist))
            return performBhopBeforeCharge(client, pos, targetPos, targetAbsVel, dist, speed, visible, buttons);
    } else {
        // 在空中, 持续修正速度方向指向目标, 不急停
        adjustAirVelocity(client, pos, targetPos, dist, lastBhopDist, speed, vVel);
        return Plugin_Continue;
    }

    if (!isCharging && !isPinning && isOnGround) {
        stateLog.debugAll("Charger (%N) initiated charge towards target (%N), dist %.2f", client, target, dist);
        // 设置立即冲锋
        setChargerAbilityCooldown(client, -1.0);
        // 设置视角方向
        static float dir[3];
        MakeVectorFromPoints(pos, predictPos, dir);
        GetVectorAngles(dir, dir);
        TeleportEntity(client, NULL_VECTOR, dir, NULL_VECTOR);
        // 发起冲锋
        buttons &= ~IN_ATTACK2;
        buttons |= IN_ATTACK;
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

bool shouldExitChargingState(int client, int target, float dist, bool visible, TargetThreatType threatType) {
    if (!isAiCharger(client) || !IsValidSurvivor(target) || !IsPlayerAlive(target))
        return true;

    /*
        增加自身位置到目标位置的 GAP 检测, 避免在大平地上 Charger 进入冲锋状态后, 目标继续向后走位, 导致 Charger 与目标的距离频繁在 minDist 之间变化, Charger 的状态频繁在 APPROACH 和 CHARGING 之间切换，无法专心连跳到距离目标无法躲避冲锋的位置, 因此 CHARGING 状态要切换到其他状态必须满足距离条件和 GAP 条件 (自身到目标的连线之间有超过 MaxJumpHeight 的落差)
    */
    static Address pLocomotion;
    pLocomotion = clientGetLocomotionInterface(client);
    if (!pLocomotion) {
        stateLog.debugAll("Charger (%N) failed to get locomotion interface, transition to APPROACH STATE", client);
        return true;
    }

    static float pos[3], targetPos[3];
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);

    static bool hasGap;
    hasGap = hasPotentialGap(pLocomotion, pos, targetPos);

    static float minDist;
    minDist = g_cvBhopMinDist.FloatValue + STATE_TOLERANCE_DIST;
    // 失去目标视野, 转换为 APPROACH STATE
    if (!visible) {
        stateLog.debugAll("Charger (%N) lost the sight of target (%N), transition to APPROACH STATE", client, target);
        return true;
    }
    // 目标非手持近战, 且到目标距离大于 g_cvBhopMinDist.FloatValue + 容差距离, 转换为 APPROACH STATE
    if (
        threatType != Threat_Melee &&
        dist > minDist &&
        hasGap
    ) {
        stateLog.debugAll("Charger (%N), target (%N), distance %.2f > min dist %.2f, transition to APPROACH STATE", client, target, dist, minDist);
        return true;
    }
    // 目标手持近战, 且到目标距离大于 meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue, 转换为 APPROACH STATE
    static float meleeRange;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    minDist = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue + STATE_TOLERANCE_DIST;
    if (
        threatType == Threat_Melee &&
        dist > minDist &&
        hasGap
    ) {
        stateLog.debugAll("Charger (%N), target (%N) holding melee, dist %.2f > baitZoneMax %.2f, transition to APPROACH STATE", client, target, dist, minDist);
        return true;
    }
    return false;
}

/**
* 处理冲锋后能力未就绪时的状态转换
* @param client 客户端索引
* @param target 目标索引
* @param dist 到目标距离
* @param threatType 目标威胁类型
* @return void
**/
void handleAbilityNotReady(int client, int target, float dist, TargetThreatType threatType) {
    static float meleeRange, baitZoneMax;
    meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
    baitZoneMax = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue;

    if (threatType == Threat_Melee) {
        if (dist <= baitZoneMax) {
            stateLog.debugAll("Charger (%N) ability not ready, melee threat (%N), dist %.2f < baitZoneMax %.2f, transition to BAIT STATE", client, target, dist, baitZoneMax);
            g_ChargerStateContext[client].transitionTo(CH_STATE_BAIT);
        } else if (dist > baitZoneMax + STATE_TOLERANCE_DIST) {
            stateLog.debugAll("Charger (%N) ability not ready, melee threat (%N), dist %.2f > baitZoneMax + tolerance, transition to APPROACH STATE", client, target, dist);
            g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        }
    } else {
        if (dist <= g_cvBhopMinDist.FloatValue) {
            stateLog.debugAll("Charger (%N) ability not ready, non melee threat (%N), dist %.2f < bhopMinDist, transition to BAIT STATE", client, target, dist);
            g_ChargerStateContext[client].transitionTo(CH_STATE_BAIT);
        } else if (dist > g_cvBhopMinDist.FloatValue + STATE_TOLERANCE_DIST) {
            stateLog.debugAll("Charger (%N) ability not ready, non melee threat (%N), dist %.2f > bhopMinDist + tolerance, transition to APPROACH STATE", client, target, dist);
            g_ChargerStateContext[client].transitionTo(CH_STATE_APPROACH);
        }
    }
}

/**
* 计算目标的预测位置 (混合当前位置和预测位置)
* @param targetPos 目标位置
* @param targetVel 目标的速度
* @param dist 到目标距离
* @param chargeSpeed 冲锋速度
* @param predictPos 预测位置
* @return void
**/
static void calculatePredictedPosition(const float pos[3], const float targetPos[3], const float targetVel[3], float dist, float chargeSpeed, float predictPos[3]) {
    static float predictTime;
    predictTime = (dist / chargeSpeed) + 0.25;
    if (predictTime > PREDICT_MAX_TIME) predictTime = PREDICT_MAX_TIME;

    // 计算平行于冲锋方向的向量
    static float fwdDir[3];
    MakeVectorFromPoints(pos, targetPos, fwdDir);
    fwdDir[2] = 0.0;
    NormalizeVector(fwdDir, fwdDir);

    // 计算垂直于冲锋方向的横向位移向量
    static float sideDir[3];
    GetVectorCrossProduct(fwdDir, {0.0, 0.0, 1.0}, sideDir);
    NormalizeVector(sideDir, sideDir);

    // 将生还者速度进行正交分解
    static float velFwd, velSide;
    velFwd = GetVectorDotProduct(fwdDir, targetVel);
    velSide = GetVectorDotProduct(sideDir, targetVel);

    // 分别计算两个轴向的预测偏移量
    static float offsetFwd, offsetSide;
    offsetFwd = velFwd * predictTime;
    offsetSide = velSide * predictTime;

    // 如果预测时间是 MAX_PREDICT_TIME, 生还者横向速度很大, offsetSide 会很大
    // 如果生还者此时反向走位, Charger 会偏离很远, 因此将横向预测位移限制在 MAX_PREDICT_LATERAL_OFFSET 内
    if (offsetSide > PREDICT_MAX_LATERAL_OFFSET) offsetSide = PREDICT_MAX_LATERAL_OFFSET;
    else if (offsetSide < -PREDICT_MAX_LATERAL_OFFSET) offsetSide = -PREDICT_MAX_LATERAL_OFFSET;

    // 合成最终预测坐标
    predictPos[0] = targetPos[0] + (fwdDir[0] * offsetFwd) + (sideDir[0] * offsetSide);
    predictPos[1] = targetPos[1] + (fwdDir[1] * offsetFwd) + (sideDir[1] * offsetSide);
    predictPos[2] = targetPos[2];
}

/**
* 判断在冲锋之前是否需要最后进行一次连跳
* @param client 客户端索引
* @param dist 到目标距离
* @param chargeSpeed 冲锋速度
* @param targetSpeed 目标速度
* @param visible 是否可见目标
* @return bool
**/
stock bool shouldBhopBeforeCharge(int client, int target, float dist, bool visible, float lastBhopDist) {
    // 0. 未满足基本连跳条件, 不允许连跳
    if (!allowToBhop(client))
        return false;
    // 1. 无目标视野, 不允许连跳
    if (!visible)
        return false;
    // 2. 如果已经在目标无法躲避的范围内, 不允许连跳
    if (dist <= lastBhopDist) {
        stateLog.debugAll("Charger (%N) dist %.2f <= lastBhopDist + tolerance %.2f, performing bhop before charge to (%N)", client, dist, lastBhopDist, target);
        return false;
    }
    return true;
}

/**
* 冲锋前进行最后一次到目标方向的连跳
* @param client 客户端索引
* @param pos Charger 当前位置
* @param targetPos 目标当前位置
* @param dist 到目标的距离
* @param targetVel 目标当前速度向量
* @param visible 是否可见目标
* @return Action
**/
stock Action performBhopBeforeCharge(
    int client, const float pos[3], const float targetPos[3], const float targetVel[3],
    float dist, float speed, bool visible, int& buttons
) {
    // 计算目标下一帧的位置作为连跳落点
    static float predictPos[3];
    AddVectors(targetPos, targetVel, predictPos);

    // 计算到目标的方向向量
    static float dir[3], baseSpeed;
    MakeVectorFromPoints(pos, predictPos, dir);
    dir[2] = 0.0;
    NormalizeVector(dir, dir);
    baseSpeed = SDKCall(g_hSdkGetRunTopSpeed, client);
    ScaleVector(dir, (baseSpeed > speed ? baseSpeed : speed) + g_cvBhopImpulse.FloatValue);

    // 连跳最大速度限制, 缩放水平方向上的速度向量, 垂直方向保持不变
    static float vecLen;
    vecLen = getVectorLength2D(dir);
    if (vecLen > g_cvBhopMaxSpeed.FloatValue) {
        static float scale;
        scale = g_cvBhopMaxSpeed.FloatValue / vecLen;
        ScaleVector(dir, scale);
    }

    // 下一跳落点不安全, 放弃连跳
    if (!nextTickPosCheck(client, dir, visible))
        return Plugin_Continue;

    buttons |= IN_DUCK;
    buttons |= IN_JUMP;
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, dir);
    g_AiChargers[client].m_bBhopBeforeCharge = true;
    stateLog.debugAll("Charger (%N) performed bunnyhop before charge, dist %.2f, speed %.2f", client, dist, getVectorLength2D(dir));
    return Plugin_Changed;
}

/**
* 在空中时持续调整速度方向指向目标, 确保落地时尽可能靠近目标
* 不再进行空中急停: 急停会导致生还者在 charger 落地前跑出 100+ units, 落地后冲锋距离过远
* @param client 客户端索引
* @param pos Charger 当前位置
* @param targetPos 目标当前位置
* @param vVel Charger 当前的速度向量
* @param speed Charger 当前速度
* @return void
**/
void adjustAirVelocity(int client, const float pos[3], const float targetPos[3], float dist, float lastBhopDist, float speed, const float vVel[3]) {
    // 当前 Charger 位置距离目标的垂直夹角大于 45 度, 不进行速度方向修正
    static float dx, dz, pitch;
    dx = SquareRoot(Pow(targetPos[0] - pos[0], 2.0) + Pow(targetPos[1] - pos[1], 2.0));
    dz = targetPos[2] - pos[2];
    pitch = RadToDeg(ArcTangent2(dz, dx));
    if (pitch > 45.0)
        return;

    // Charger 比目标高太多 (目标走到低处地形), 不进行水平速度修正
    // 避免 charger 追着目标落到其头顶, 而是让 charger 自然落到当前位置的地面再接近
    if (pos[2] - targetPos[2] > CHARGE_Z_THRESHOLD)
        return;

    // 距离已经小于目标无法躲避距离, 停止进行修正
    if (dist <= lastBhopDist)
        return;

    static float dir[3];
    MakeVectorFromPoints(pos, targetPos, dir);
    dir[2] = 0.0;
    NormalizeVector(dir, dir);
    // 缩放空中速度向量, 使其不小于 runTopSpeed + bhopImpulse, 理论上, 这个速度越快 charger 贴脸的时间越短, 越容易撞中
    static float baseSpeed;
    baseSpeed = SDKCall(g_hSdkGetRunTopSpeed, client);
    ScaleVector(dir, (baseSpeed > speed ? baseSpeed : speed) + g_cvBhopImpulse.FloatValue);
    dir[2] = vVel[2];
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, dir);
    // stateLog.debugAll("Charger (%N) adjusted air velocity, dist %.2f, speed %.2f", client, dist, getVectorLength2D(dir));
}

// ============================================================
// OnExit 函数
// ============================================================
stock void StateCharging_OnExit(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Charging On Exit ===========", client);
    // 再次重置人为冲锋延迟标记
    g_AiChargers[client].m_bChargeDelayed = false;
}