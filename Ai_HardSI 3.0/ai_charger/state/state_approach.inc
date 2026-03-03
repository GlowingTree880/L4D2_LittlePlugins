#if defined _state_approach_included_
    #endinput
#endif
#define _state_approach_included_

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#include "../setup.inc"
#include "../stocks.inc"
#include "./state.inc"

#define STATE_APPROACH_NAME             "STATE_APPROACH"
#define PATH_LOOKAHEAD_MIN_DIST         150.0           // 在地面时连跳前瞻目标点的最小距离
#define GOAL_POS_TOLERANCE_DIST         25.0            // Charger 与目标 Goal Pos 距离小于这个值时, 放弃速度修正
#define DEFAULT_PATH_LOOKAHEAD_DIST     300.0           // 默认的触发节点前向遍历距离

// =========================================================================
// State Approach 接近目标状态 (连跳等)
// 注册状态函数
// =========================================================================
stock void RegisterState_Approach() {
    ChargerState stateApproach;
    strcopy(stateApproach.name, sizeof(stateApproach.name), "State_Approach");
    stateApproach.OnEnter = StateApproach_OnEnter;
    stateApproach.OnUpdate = StateApproach_OnUpdate;
    stateApproach.OnExit = StateApproach_OnExit;
    g_ChargerStates.PushArray(stateApproach);
}

// ============================================================
// OnEnter 函数
// ============================================================
stock void StateApproach_OnEnter(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Approach On Enter ===========", client);
}

// ============================================================
// OnUpdate 函数
// ============================================================
stock Action StateApproach_OnUpdate(int client, int& buttons, float vel[3], float ang[3]) {
    if (!isAiCharger(client) || IsPinningSurvivor(client))
        return Plugin_Continue;

    // ============================================================
    // 数据收集 (Data Collection)
    // ============================================================
    static int target;
    target = GetClientOfUserId(g_AiChargers[client].m_iTarget);
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
        stateLog.debugAll("(%s) Charger (%N)'s target %d is invalid", STATE_APPROACH_NAME, client, target);
        return Plugin_Continue;
    }
    
    // 计算 charger 当前速度
    static float vVel[3], speed;
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
    speed = getVectorLength2D(vVel);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
    // 计算 charger 当前到目标的距离
    static float pos[3], targetPos[3], targetEyePos[3], dist;
    GetClientAbsOrigin(client, pos);
    GetClientAbsOrigin(target, targetPos);
    GetClientEyePosition(target, targetEyePos);
    dist = getVectorDistance2D(pos, targetPos);
    // 是否可视目标
    static bool visible;
    visible = L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos);
    // 是否在地上
    static bool isOnGround;
    isOnGround = IsClientOnGround(client);

    // ============================================================
    // 状态决策 (State Decision)
    // ============================================================

    // 1. 优先行动检查, 检测是否有更好的可以直接冲锋的目标, 如果有, 直接转换为冲锋状态
    if (isOnGround) {
        static int betterTarget;
        betterTarget = getChargeUnavoidableTarget(client, target, pos, dist, g_cvBhopMinDist.FloatValue);
        if (IsValidSurvivor(betterTarget) && IsPlayerAlive(betterTarget) &&
            isChargeAbilityReady(client) && !isChargePathBlocked(client, betterTarget))
        {
            stateLog.debugAll("Charger (%N) find a better charge target %N, transition to LOCKED STATE", client, betterTarget);
            // 设置新目标, 转换为冲锋状态
            g_AiChargers[client].m_iBetterTarget = GetClientUserId(betterTarget);
            g_ChargerStateContext[client].transitionTo(CH_STATE_LOCKED);
            return Plugin_Changed;
        }
    }
    // 2. 面对近战威胁的博弈 (切换到 BAIT 博弈逻辑)
    // 若 charger 目标手持近战武器, 设置一个博弈区为 melee_range + g_cvMeleeBaitZoneMaxRange.FloatValue
    // charger 在空中进入该区域时, 急停, 进入博弈状态, 若在地上, 直接进入博弈状态, 避免 g_cvBhopMinDist.FloatValue 设置的太小, 连跳到目标脸上被砍
    static TargetThreatType threatType;
    threatType = getTargetThreatType(client, target);
    if (threatType == Threat_Melee) {
        static float meleeRange, baitZoneMax;
        meleeRange = !cvMeleeRange ? DEFAULT_MELEE_RANGE : cvMeleeRange.FloatValue;
        baitZoneMax = meleeRange + g_cvMeleeBaitZoneMaxRange.FloatValue;

        if (visible && dist < baitZoneMax && visible) {
            if (!isOnGround && !g_AiChargers[client].m_bHasAirBreaked) {
                // 如果 charger 此时在空中, 将水平方向上的速度设置为 0, 仅保留垂直方向的速度
                vVel[0] = vVel[1] = 0.0;
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
                g_AiChargers[client].m_bHasAirBreaked = true;
            }
            // 转换为博弈状态
            stateLog.debugAll("Charger (%N) melee threat (%N) dist %.2f < %.2f, transition to BAIT", client, target, dist, baitZoneMax);
            g_ChargerStateContext[client].transitionTo(CH_STATE_BAIT);
            return Plugin_Continue;
        }
    }
    // 3. 常规距离达标后的博弈 or 准备冲锋 (转换到 BAIT 博弈逻辑)
    if (visible && dist <= g_cvBhopMinDist.FloatValue && visible) {
        /**
         * charger 面对持枪生还者, 连跳到 g_cvBhopMinDist.FloatValue 时空中急停
         * 急停可能会出现的问题: charger 下落时间内, 目标又跑出去一段路, 此时 charger 冲锋无法准确命中目标
         * if (!isOnGround && !g_AiChargers[client].m_bHasAirBreaked) {
                // 如果 charger 此时在空中, 将水平方向上的速度设置为 0, 仅保留垂直方向的速度
                vVel[0] = vVel[1] = 0.0;
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
                g_AiChargers[client].m_bHasAirBreaked = true;
            }
         */
        // 到目标距离小于允许连跳的最小距离, 转换为博弈状态
        stateLog.debugAll("Charger (%N) to target (%N) dist %.2f <= %.2f, transition to BAIT", client, target, dist, g_cvBhopMinDist.FloatValue);
        g_ChargerStateContext[client].transitionTo(CH_STATE_BAIT);
        return Plugin_Continue;
    }

    // ============================================================
    // 动作干预 (Default Actions)
    // ============================================================

    // 移除原生攻击键, 特别是 IN_ATTACK2, 避免多个 Charger 生成在远处互相打拳
    buttons &= ~IN_ATTACK;
    buttons &= ~IN_ATTACK2;
    setChargerAbilityCooldown(client, 1.0);

    // ============================================================
    // 连跳行为 (Bhop Execution)
    // ============================================================
    static Action bhopRes;
    bhopRes = checkShouldBhop(client, buttons, target, vVel, speed, dist, visible, pos, targetPos);
    if (bhopRes != Plugin_Continue)
        return bhopRes;

    return Plugin_Continue;
}

stock Action checkShouldBhop(
    int client, int& buttons, int target, float vVel[3], float speed,
    float dist, bool visible, float pos[3], float targetPos[3]
) {
    if (!isAiCharger(client))
        return Plugin_Continue;
    if (!IsValidSurvivor(target) || !IsPlayerAlive(target))
        return Plugin_Continue;
    if (!allowToBhop(client))
        return Plugin_Continue;

    // 是否在地上
    static bool isOnGround;
    isOnGround = IsClientOnGround(client);
    if (isOnGround) {
        g_AiChargers[client].m_bHasAirBreaked = false;
    }

    // 连跳距离限制
    if (dist > g_cvBhopMaxDist.FloatValue)
        return Plugin_Continue;

    // 连跳空速限制
    if (speed < g_cvBhopMinSpeed.FloatValue)
        return Plugin_Continue;

    if (isOnGround)
        return executeGroundBhop(client, dist, speed, visible, pos, targetPos, vVel, buttons);
    else
        return executeAirCorrection(client, dist, speed, visible, pos, targetPos, vVel, buttons);
}

/**
* 处理地面连跳逻辑
* @param client 客户端索引
* @param target 目标索引
* @param dist 与目标距离
* @param speed 当前速度
* @param visible 是否有视野
* @param nextSeg 下一个 PathSegment
* @param pos 当前位置
* @param targetPos 目标位置
* @param vVel 当前速度
* @return Action
**/
stock Action executeGroundBhop(
    int client, float dist, float speed, bool visible,
    const float pos[3], const float targetPos[3], const float vVel[3], int& buttons
) {
    // 如果无视野, 且不允许连跳, 返回
    if (!visible && !g_cvBhopNoVision.BoolValue)
        return Plugin_Continue;

    /*
        使用 Next PathSegment 的 Goal Pos 作为连跳加速度与空中速度方向修正的方向
        因为在一块 Nav 之内, Current PathSegment 的 Goal Pos 可能会根据当前 bot 位置被多次改变, 没有激活 PathSegment 之前, Goal Pos (不变)
        进入当前 PathSegmeng 并激活当前 PathSegment 后, 会根据当前 bot 位置改变 Goal Pos, Goal Pos 频繁被改变则会影响空中速度方向修正
    */
    static float vFwd[3], vDir[3], vLandPos[3], d2Goal;
    static bool close2Tar, pathValid;
    // 当前 PATH 有效, 且 PathFollower 更新, 允许沿着 PATH 连跳加速
    pathValid = (
        (g_AiChargers[client].m_LastPathSegment.m_pPathSegment != Address_Null) &&
        (g_AiChargers[client].m_PathSegment.m_pPathSegment != g_AiChargers[client].m_LastPathSegment.m_pPathSegment)
    );
    /*
        接近目标的判断条件
        1. 当前 PATH 无效 (已经到达最后一个 PathSegment 或者当前没有有效 PATH)
        2. 有目标视野且距离小于 g_cvBhopStrafeMinDist.FloatValue, 且距离目标 z 轴高度不超过 CHARGE_Z_THRESHOLD, 且到目标方向没有向下超过 MaxJumpHeight 的高差
    */
    static Address pLocomotion;
    pLocomotion = clientGetLocomotionInterface(client);

    /*
        增加 HasPotentialGap 判断, 之前的 close2Tar 只有 visible, dist, 高差判断, 导致 Charger 在某些自身位置到目标位置中间有 GAP 的地形 (c4m2 的下电梯那栋楼上楼梯接近目标, 准备与目标处于同一层但还在楼梯上时, 满足 close2Tar 条件, 空中速度修正方向转换为指向目标方向, 导致从楼梯上掉下来而不是继续连跳上楼梯)
        TODO: 是否需要检测当前 NAV 是否具有 STAIR 属性, 停止楼梯上连跳加速, 因为类似 c4m2 电梯楼的楼梯 Charger 继续连跳加速, 概率因为在空中无法 PathFollower::CheckProgress 导致当前目标点一直在楼梯一侧, 空中速度方向修正时也会被推向楼梯一侧的目标点, 导致无法过去楼梯另一侧继续上楼梯
    */
    static bool hasGap;
    hasGap = true;
    if (pLocomotion) {
        hasGap = hasPotentialGap(pLocomotion, pos, targetPos);
    }
    g_AiChargers[client].m_bHasPotentialGap = hasGap;

    close2Tar = (
        !pathValid ||
        (visible && dist <= g_cvBhopStrafeMinDist.FloatValue && (targetPos[2] - pos[2] <= JUMP_HEIGHT) && !hasGap)
    );

    if (pathValid && !close2Tar) {
        /*
            设置连跳类型, 空中速度修正基于该连跳类型进行修正
            之前的空中速度修正 Charger 在空中也会每帧检查 pathValid 和 close2Tar 条件, 决定使用 PATH 目标点还是到目标的方向向量作为修正方向, close2Tar 的 dist 和高差条件可能在某些场景 (比如 c2m2 的小下坡一会满足一会不满足, 或者生还者在空中一下靠近一下远离 charger, 导致 dist 条件一下满足一下不满足) 导致空中速度修正类型频繁在 PATH 和到目标方向之间切换, 若 Charger 此时正在执行指向目标方向的速度修正, close2Tar 条件下一帧不满足, 会导致 Charger 切换为基于 PATH 的速度修正, 空中速度方向强行从指向目标变成指向目标点, 导致空中抽搐
        */
        g_AiChargers[client].m_BhopType = BhopType_Path;

        static float vLookAheadPos[3];
        static float maxEstimateDist;
        maxEstimateDist = speed * getJumpAirTime();

        // 最小向前检查距离不能小于 PATH_LOOKAHEAD_MIN_DIST
        if (maxEstimateDist < PATH_LOOKAHEAD_MIN_DIST)
            maxEstimateDist = PATH_LOOKAHEAD_MIN_DIST;

        if (getLookAheadGoalPos(client, pos, maxEstimateDist, vLookAheadPos, g_cvPathLookAheadMaxDepth.IntValue)) {
            // Debug print, if current PathSegment is not the last, print charger pos and look ahead goal pos, color: cyan
            /* DrawBeamPoint(vLookAheadPos, NULL_VECTOR, {0, 255, 255, 255}, 0.1); */
            MakeVectorFromPoints(pos, vLookAheadPos, vFwd);
            g_AiChargers[client].m_vecAirCorrGoal = vLookAheadPos;
        } else {
            // 如果没有任何一个可用的前向节点, 不允许连跳
            return Plugin_Continue;
        }

        vFwd[2] = 0.0;
        NormalizeVector(vFwd, vFwd);
        ScaleVector(vFwd, speed + g_cvBhopImpulse.FloatValue);
        // 获取落地位置, 计算 Charger 当前位置到落地位置的距离, 用于侧向连跳
        vLandPos = vLookAheadPos;
        d2Goal = getVectorDistance2D(pos, vLandPos);
    } else {
        // 设置连跳类型
        g_AiChargers[client].m_BhopType = BhopType_Normal;

        /*
            若当前已经到达本 PATH 的最后一个 Segment, 且无新的 PATH, 或者无法寻路, 此时若 Charger 还可连跳
            1. 若有目标视野, 那么朝着自身到目标的方向加速
            2. 若无目标视野, 朝着当前速度方向加速
        */
        // 指向目标的方向向量
        MakeVectorFromPoints(pos, targetPos, vDir);
        vDir[2] = 0.0;
        NormalizeVector(vDir, vDir);

        // Debug print, if current PathSegment is the last, print charger pos, color: red
        /* DrawBeamPoint(pos, NULL_VECTOR, {255, 0, 0, 255}, 0.1); */
        g_AiChargers[client].m_vecAirCorrGoal = NULL_VECTOR;

        static bool fwdOnly, leftOnly, rightOnly;
        fwdOnly = ((buttons & IN_FORWARD) && !(buttons & IN_BACK));
        leftOnly = ((buttons & IN_LEFT) && !(buttons & IN_RIGHT));
        rightOnly = ((buttons & IN_RIGHT) && !(buttons & IN_LEFT));

        if (visible) {
            if (fwdOnly) {
                // 有视野, 且按住 IN_FORWARD, 连跳朝着目标方向加速
                MakeVectorFromPoints(pos, targetPos, vFwd);
                vFwd[2] = 0.0;
                NormalizeVector(vFwd, vFwd);
                ScaleVector(vFwd, speed + g_cvBhopImpulse.FloatValue);
            }
            if (leftOnly || rightOnly) {
                static float vVel_cpy[3], vBase[3];
                vVel_cpy = vVel;
                vBase = vVel;
                NormalizeVector(vBase, vBase);
                GetVectorCrossProduct({0.0, 0.0, 1.0}, vBase, vFwd);
                NormalizeVector(vFwd, vFwd);
                // 如果左右键同时按下 IN_LEFT xor IN_RIGHT = 0, 按照前向加速逻辑处理
                if (leftOnly ^ rightOnly) {
                    vFwd[2] = 0.0;
                    ScaleVector(vFwd, speed + g_cvBhopImpulse.FloatValue * (rightOnly ? 1.0 : -1.0));
                    AddVectors(vVel_cpy, vFwd, vFwd);
                } else {
                    vFwd = vDir;
                    vFwd[2] = 0.0;
                    NormalizeVector(vFwd, vFwd);
                    ScaleVector(vFwd, speed + g_cvBhopImpulse.FloatValue);
                }
            }
        } else {
            // 无目标视野, 以当前速度方向作为加速度方向, vFwd 大小等于 vVel 大小
            vFwd = vVel;
            vFwd[2] = 0.0;
            NormalizeVector(vFwd, vFwd);
            ScaleVector(vFwd, speed + g_cvBhopImpulse.FloatValue);
        }

        // 根据滞空时间计算落地位置, 接着计算 Charger 当前位置到落地位置的距离, 用于侧向连跳
        static float vFwd_cpy[3];
        vFwd_cpy = vFwd;
        ScaleVector(vFwd_cpy, getJumpAirTime());
        AddVectors(pos, vFwd_cpy, vLandPos);
        d2Goal = getVectorDistance2D(pos, vLandPos);
    }

    // Debug print bhop forward vector
    /* static float vPos[3];
    vPos = pos;
    ShowDir(COLOR_BLUE, vPos, vFwd); */

    /*
        检测连跳落点是否安全, vFwd 是包含了本次跳跃所有计算后的最终速度向量
        该检查是否必要有待测试考量, 因为基于 PATH 的连跳策略理论上不会让 Charger 走到危险的地方
    */
    if (!nextTickPosCheck(client, vFwd, visible))
        return Plugin_Continue;

    // 落点安全, 进行连跳操作
    buttons |= IN_DUCK;
    buttons |= IN_JUMP;

    // 连跳速度限制, 限制 vFwd 水平速度大小
    static float vecLen;
    vecLen = getVectorLength2D(vFwd);
    if (vecLen > g_cvBhopMaxSpeed.FloatValue) {
        static float scale;
        scale = g_cvBhopMaxSpeed.FloatValue / vecLen;
        ScaleVector(vFwd, scale);
    }

    // 记录起跳时的速度, 防止空中速度衰减
    stateLog.debugAll("Charger (%N) jump from ground, current speed: %f", client, getVectorLength2D(vFwd));
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vFwd);
    g_AiChargers[client].m_flLastHopSpeed = getVectorLength2D(vFwd);

    // 侧向连跳设置
    g_AiChargers[client].m_AirStrafe.m_flStrafeStartDist = d2Goal;
    // 第一次侧向连跳, 概率选择向左还是向右
    if (g_AiChargers[client].m_AirStrafe.m_StrafeDir == StrafeDir_None) {
        g_AiChargers[client].m_AirStrafe.m_StrafeDir = (GetRandomFloatInRange(0.0, 1.0) > 0.5) ? StrafeDir_Left : StrafeDir_Right;
    } else {
        // 不是第一次侧向连跳, 侧向连跳方向与上一次相反
        static StrafeDir dir;
        dir = g_AiChargers[client].m_AirStrafe.m_StrafeDir;
        if (dir == StrafeDir_Left) dir = StrafeDir_Right;
        else if (dir == StrafeDir_Right) dir = StrafeDir_Left;
        g_AiChargers[client].m_AirStrafe.m_StrafeDir = dir;
    }

    if (d2Goal < g_cvBhopStrafeOnceDist.FloatValue) g_AiChargers[client].m_AirStrafe.m_StrafeType = StrafeType_None;
    else if (d2Goal > g_cvBhopStrafeOnceDist.FloatValue && d2Goal < g_cvBhopStrafeTwiceDist.FloatValue) g_AiChargers[client].m_AirStrafe.m_StrafeType = StrafeType_Once;
    else g_AiChargers[client].m_AirStrafe.m_StrafeType = StrafeType_Twice;

    // 计算一个随机的侧向连跳幅度
    if (g_cvBhopStrafeMinDeg.FloatValue > 0.0)
        g_AiChargers[client].m_AirStrafe.m_flStrafeAmp = Tangent(DegToRad(GetRandomFloatInRange(g_cvBhopStrafeMinDeg.FloatValue, g_cvBhopStrafeMaxDeg.FloatValue)));
    
    return Plugin_Changed;
}

/**
* 处理空中速度方向修正逻辑
* @param client 客户端索引
* @param dist 到目标距离
* @param speed 当前速度
* @param visible 是否有目标视野
* @param nextSeg 下一个 PathSegment
* @param pos 当前位置
* @param target 目标位置
* @param vVel 当前速度向量
* @return Action
**/
stock Action executeAirCorrection(
    int client, float dist, float speed, bool visible,
    const float pos[3], const float targetPos[3], const float vVel[3], int& buttons
) {

    static float vFwd[3], vVel_cpy[3], vDir[3], dot, d2Goal, h2Goal;
    vVel_cpy = vVel;
    vVel_cpy[2] = 0.0;

    // ============================================================
    // 1. 当前连跳模式为基于 PATH 的连跳, 进行基于 PATH 的空中速度方向修正
    // ============================================================
    if (g_AiChargers[client].m_BhopType == BhopType_Path) {

        /*
            当前连跳模式是基于 PATH 的连跳, 那么可以尝试在空中进行前向寻路, 获取落地前以当前速度可以达到的的最远的目标点
            在一些场景 (c4m2 电梯楼, Charger 需要走楼梯上来, 在楼梯上连跳时, 连跳前在地上前向寻找的目标点可能在楼梯扶手的一侧, 然后 Charger 在楼梯上连跳, 以这个目标点进行修正时就会被向后推, 导致 Charger 无法到达楼梯扶手的另一侧, 导致无法上楼梯或需要重新寻路, 因此增加空中前向寻找目标点的逻辑)
        */
        static bool needLookAhead;
        needLookAhead = false;

        // 获取 Charger 当前的连跳前前向寻找的目标点
        static float curGoal[3];
        curGoal = g_AiChargers[client].m_vecAirCorrGoal;
        
        if (IsNullVector(curGoal)) {
            // 如果当前空中速度修正目标为空, 则需要计算一个目标
            needLookAhead = true;
        } else {
            // 在空中时, 判断当前目标点是否在 Charger 背后, 若在 Charger 背后, 则需要重新前向找到一个新的目标点
            MakeVectorFromPoints(pos, curGoal, vDir);
            vDir[2] = 0.0;

            d2Goal = getVectorDistance2D(pos, curGoal);

            /*
                首先获取引擎的 NextBot 最小前向寻找距离, 没有特殊情况一般是 -1.0, 于是自己设定最小前向寻找距离
                minLookAheadDist 的含义为: 当 Charger 距离当前目标点的距离小于这个距离, 开始进行前向寻找新的以当前速度可达的最远目标点
            */
            static float minLookAheadDist;
            minLookAheadDist = getMinLookAheadDist(g_AiChargers[client].m_pPathFollower);
            if (minLookAheadDist <= GOAL_POS_TOLERANCE_DIST) {
                minLookAheadDist = DEFAULT_PATH_LOOKAHEAD_DIST;
            }

            if (d2Goal < minLookAheadDist) {
                needLookAhead = true;
            } else {
                /*
                    计算当前目标点到 Charger 位置的向量与 Charger 的速度向量夹角, 若夹角大于 90 度, 则说明当前目标点在 Charger 背后, Charger 飞过头了
                    此时直接触发前向寻找新的目标点, 以调整空中速度修正方向
                */
                NormalizeVector(vDir, vDir);
                NormalizeVector(vVel_cpy, vVel_cpy);
                dot = RadToDeg(ArcCosine(GetVectorDotProduct(vDir, vVel_cpy)));
                if (dot > 90.0) {
                    needLookAhead = true;
                }
            }

            static float curTime;
            curTime = GetEngineTime();

            // 0.1 秒触发一次, 避免每帧都触发, 减少性能消耗
            if (needLookAhead && (curTime - g_AiChargers[client].m_flLastLookAheadTime > 0.1)) {
                // 获取当前 Charger z 轴高度, 计算剩余落地的时间
                static float estimateAirTime;
                estimateAirTime = calcRemainingAirTime(pos, vVel);

                static float maxEstimateDist;
                maxEstimateDist = getVectorLength2D(vVel) * estimateAirTime;
                if (maxEstimateDist < PATH_LOOKAHEAD_MIN_DIST) {
                    maxEstimateDist = PATH_LOOKAHEAD_MIN_DIST;
                }
                
                float vNewGoal[3];
                if (getLookAheadGoalPos(client, pos, maxEstimateDist, vNewGoal, g_cvPathLookAheadMaxDepth.IntValue)) {
                    // Debug draw new in ari goal pos, color: light blue
                    /* stateLog.debugAll("Charger (%N) in air found new ahead goal pos (%f %f %f)", client, vNewGoal[0], vNewGoal[1], vNewGoal[2]);
                    DrawBeamPoint(vNewGoal, NULL_VECTOR, {30, 90, 143, 255}, 1.0); */
                    g_AiChargers[client].m_vecAirCorrGoal = vNewGoal;
                }

                g_AiChargers[client].m_flLastLookAheadTime = curTime;
            }
        }

        MakeVectorFromPoints(pos, g_AiChargers[client].m_vecAirCorrGoal, vDir);
        dot = calcVectorAngle(vVel, vDir, true);

        // 空中前向遍历目标点完毕, 获取到当前最新目标点的距离和高度差
        d2Goal = getVectorDistance2D(pos, g_AiChargers[client].m_vecAirCorrGoal);
        h2Goal = g_AiChargers[client].m_vecAirCorrGoal[2] - pos[2];

        // ============================================================
        // 处理主动侧向连跳
        // ============================================================
        static float vDesired[3];
        vDesired = vDir;

        static StrafeType strafeType;
        strafeType = g_AiChargers[client].m_AirStrafe.m_StrafeType;

        static bool isStrafing;
        isStrafing = (strafeType != StrafeType_None && g_cvBhopStrafeMinDeg.FloatValue > 0.0 && d2Goal > GOAL_POS_TOLERANCE_DIST);
        /*
            desiredPos = vDir + (M * vRight)
        */
        if (isStrafing) {
            static float startDist, progress;
            startDist = g_AiChargers[client].m_AirStrafe.m_flStrafeStartDist;
            progress = 0.0;
            if (startDist > 10.0) {
                // progress 从 1 或者 -1 到 0
                progress = d2Goal / startDist;
                if (progress > 1.0) progress = 1.0;
                else if (progress < 0.0) progress = 0.0;
            }

            // 获取当前侧向连跳的方向
            static StrafeDir strafeDir;
            strafeDir = g_AiChargers[client].m_AirStrafe.m_StrafeDir;

            // 获取之前起跳时设置的振幅
            static float amp;
            amp = g_AiChargers[client].m_AirStrafe.m_flStrafeAmp;

            // M 是由余弦函数生成的侧向偏移幅度, M 越大侧向连跳时横向位移越大
            static float M;
            M = 0.0;
            if (strafeType == StrafeType_Once) {
                // 只做 (0~π/2) 的余弦曲线或 (π~3/2π) 的余弦曲线
                M = Cosine(progress * PI) * float(view_as<int>(strafeDir)) * amp;
            } else if (strafeType == StrafeType_Twice) {
                // 做一个完整的余弦曲线偏移
                M = Cosine(progress * PI * 2.0) * float(view_as<int>(strafeDir)) * amp;
            }

            // 计算与 vDir 方向正交的方向向量
            static float vRight[3];
            GetVectorCrossProduct(vDir, {0.0, 0.0, 1.0}, vRight);
            NormalizeVector(vRight, vRight);

            // 算出包含了偏移曲线在内的最终方向
            vDesired[0] = vDir[0] + vRight[0] * M;
            vDesired[1] = vDir[1] + vRight[1] * M;
            vDesired[2] = 0.0;
            NormalizeVector(vDesired, vDesired);

            // 可视化黄色 desired 位置曲线, 绿色 vRight 方向向量曲线, 橙色 air correction goal 坐标点
            /* static float vPos[3];
            vPos = pos;
            ShowDir(COLOR_GREEN, vPos, vRight, 5.0, 50.0);
            ShowDir(COLOR_YELLOW, vPos, vDesired, 5.0, 50.0);
            DrawBeamPoint(g_AiChargers[client].m_vecAirCorrGoal, NULL_VECTOR, {251, 164, 20, 255}, 10.0); */
        }

        // ============================================================
        // 正常连跳, 判断是否需要空中速度修正
        // ============================================================
        static bool shouldCorrect;
        shouldCorrect = false;
        
        static float airCorrLerp;
        airCorrLerp = g_cvAirVecModifyLerp.FloatValue;
        if (isStrafing && d2Goal > GOAL_POS_TOLERANCE_DIST) {
            shouldCorrect = true;
            airCorrLerp = 0.50;
        } else {
            if (
                dot >= g_cvAirVecModifyMinDegree.FloatValue &&
                dot <= g_cvAirVecModifyMaxDegree.FloatValue &&
                d2Goal > GOAL_POS_TOLERANCE_DIST
                /*
                    TODO: 确认是否要增加有 PATH 时速度修正的高度限制, 无高度限制比如 charger 跌落楼梯在空中还是一直会触发速度方向修正
                    && h2Goal < CHARGE_Z_THRESHOLD or h2Goal < JUMP_HEIGHT
                */
            ) {
                shouldCorrect = true;
            }
        }

        if (shouldCorrect) {
            // 对 vFwd 进行线性插值
            vFwd[0] = vVel_cpy[0] + (vDesired[0] - vVel_cpy[0]) * airCorrLerp;
            vFwd[1] = vVel_cpy[1] + (vDesired[1] - vVel_cpy[1]) * airCorrLerp;
            vFwd[2] = 0.0;
            NormalizeVector(vFwd, vFwd);

            // 避免空中速度衰减
            if (speed < g_AiChargers[client].m_flLastHopSpeed)
                speed = g_AiChargers[client].m_flLastHopSpeed;

            // 缩放空中速度修正的速度向量
            ScaleVector(vFwd, speed);
            vFwd[2] = vVel[2];
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vFwd);

            // 记录空中速度方向修正时间
            g_AiChargers[client].m_flLastAirVecModifyTime = GetEngineTime();
            return Plugin_Changed;
        }
    }

    // ============================================================
    // 寻路结束, 或路径无效, 进行选择性空中速度方向修正
    // ============================================================

    // 防止目标在上方频繁触发速度修正
    static float dx, dz, pitch;
    dx = SquareRoot(Pow(targetPos[0] - pos[0], 2.0) + Pow(targetPos[1] - pos[1], 2.0));
    dz = targetPos[2] - pos[2];
    pitch = RadToDeg(ArcTangent2(dz, dx));
    if (pitch > 45.0)
        return Plugin_Continue;

    // 计算当前方向与到目标方向的夹角
    MakeVectorFromPoints(pos, targetPos, vDir);
    dot = calcVectorAngle(vVel, vDir, true);

    static bool inAngleRange, notPressBack, delayExpired;
    inAngleRange = (dot >= g_cvAirVecModifyMinDegree.FloatValue && dot <= g_cvAirVecModifyMaxDegree.FloatValue);
    notPressBack = !(buttons & IN_BACK);
    delayExpired = (GetEngineTime() - g_AiChargers[client].m_flLastAirVecModifyTime) > g_cvAirVecModifyInterval.FloatValue;

    if (visible &&
        inAngleRange &&
        notPressBack &&
        dist <= g_cvBhopStrafeMinDist.FloatValue
        // && delayExpired
    ) {
        stateLog.debugAll("Charger: %N triggered air speed modify, current vector angle: %.2f", client, dot);
        vFwd[0] = vVel[0] + (vDir[0] - vVel[0]) * g_cvAirVecModifyLerp.FloatValue;
        vFwd[1] = vVel[1] + (vDir[1] - vVel[1]) * g_cvAirVecModifyLerp.FloatValue;
        vFwd[2] = 0.0;
        NormalizeVector(vFwd, vFwd);
        
        // 将方向向量缩放成原速度大小, 刚起跳时加速度可能没有应用, 缩放使用的速度为起跳前的速度, 导致连跳无法加速, 因此这里保存加速度并取最大速度缩放
		if (speed < g_AiChargers[client].m_flLastHopSpeed)
			speed = g_AiChargers[client].m_flLastHopSpeed;
        
		ScaleVector(vFwd, speed);
		vFwd[2] = vVel[2];
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vFwd);
		// 记录空中速度方向修正时间
		g_AiChargers[client].m_flLastAirVecModifyTime = GetEngineTime();
    }
    return Plugin_Changed;
}

/**
* 2026-01-13
* Charger 在连跳接近目标的时候, 如果落地, 可以检测周围是否有距离原目标更近的目标, 如果有, 且新目标无法在 Charger 朝他冲锋的时间内躲开冲锋, 直接更换目标冲锋,
* 这样可以一定程度上减少原目标距离 Charger 较远时, 一味地追击原目标而在追击过程中被其他生还者打掉很多血量, 条件:
* 1. 新目标是有效生还者, 且没有倒地挂边和被 hunter 控制 (其他特感 smoker, jockey 等控制可以抢控)
* 2. 新目标必须可视, 而且距离新目标的距离比原目标更近
* @param client 客户端索引
* @param curTarDist 当前目标距离
* @param unavoidableDist 新目标在冲锋路径上无法躲避冲锋的距离
* @return int 如果找到了更好的新目标, 返回新目标的客户端索引, 若没有, 返回 -1
**/
stock int getChargeUnavoidableTarget(int client, int curTarget, float pos[3], float curTarDist, float unavoidableDist = 150.0) {
    if (!isAiCharger(client))
        return -1;
    if (!IsValidSurvivor(curTarget) || !IsPlayerAlive(curTarget))
        return -1;

    // 获取冲锋时的冲锋速度
    static float chargeSpeed;
    chargeSpeed = !cvChargeSpeed ? DEFAULT_CHARGE_SPEED : cvChargeSpeed.FloatValue;

    // 遍历所有生还者, 寻找更近的目标
    static float dist, targetPos[3], targetEyePos[3];
    for (int i = 1; i <= MaxClients; i++) {
        if (i == client || i == curTarget || !IsValidSurvivor(i) || !IsPlayerAlive(i))
            continue;
        if (IsClientIncapped(i) || IsClientHanging(i))
            continue;
        // 跳过被 hunter 控制的生还者, 无法抢控
        if (isSurvivorPinned(i))
            continue;

        GetClientAbsOrigin(i, targetPos);
        GetClientEyePosition(i, targetEyePos);
        // 跳过不可直视的玩家
        if (!L4D2_IsVisibleToPlayer(client, TEAM_INFECTED, TEAM_SURVIVOR, 0, targetEyePos))
            continue;
        
        dist = getVectorDistance2D(pos, targetPos);
        // 跳过距离比当前目标还远的玩家
        if (dist > unavoidableDist || dist > curTarDist)
            continue;
        
        // 计算冲锋无法躲避的条件
        static float timeToImpact;
        static float vTarVelVec[3], vPredict[3], predictDist;
        timeToImpact = dist / chargeSpeed;
        GetEntPropVector(i, Prop_Data, "m_vecVelocity", vTarVelVec);
        vTarVelVec[2] = 0.0;
        // 计算玩家在 charger 冲锋到此处的时间后的位置 (线性计算)
        ScaleVector(vTarVelVec, timeToImpact);
        AddVectors(targetPos, vTarVelVec, vPredict);
        predictDist = GetVectorLength(vTarVelVec);

        // 获取冲锋方向 (直接使用自身位置到当前玩家位置的方向向量作为冲锋方向)
        static float chargeDir[3];
        MakeVectorFromPoints(pos, targetPos, chargeDir);
        NormalizeVector(chargeDir, chargeDir);

        // 计算玩家速度在冲锋方向上的投影长度
        // prj = |A| * cosθ, |A| * cosθ = dot(A,B) / |B|, B 已经归一化, 因此 |A| * cosθ = dot(A,B)
        static float dot;
        dot = GetVectorDotProduct(vTarVelVec, chargeDir);
        if (dot > 1.0) dot = 1.0;
        else if (dot < -1.0) dot = -1.0;
        // 根据勾股定理计算垂直于冲锋方向上的躲避距离
        static float effDodgeDistSqr, effDodgeDist;
        effDodgeDistSqr = Pow(predictDist, 2.0) - Pow(dot, 2.0);
        if (effDodgeDistSqr < 0.0) {
            effDodgeDistSqr = 0.0;
        }
        effDodgeDist = SquareRoot(effDodgeDistSqr);
        if (effDodgeDist < unavoidableDist) {
            stateLog.debugAll("Charger (%N) find a unavoidable target (%N), distance: %.2f", client, i, dist);
            return i;
        }
    }
    return -1;
}

// ============================================================
// OnExit 函数
// ============================================================
stock void StateApproach_OnExit(int client) {
    stateLog.debugAll("\n========== Charger (%N) State Approach On Exit ===========", client);
    // 重置空中急停标记
    g_AiChargers[client].m_bHasAirBreaked = false;
}