#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <treeutil>

stock bool isAiTank(int client) {
    return IsValidInfected(client) && GetInfectedClass(client) == ZC_TANK && IsFakeClient(client)
            && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsInGhostState(client);
}

stock bool isAiCharger(int client) {
    return IsValidInfected(client) && GetInfectedClass(client) == ZC_CHARGER && IsFakeClient(client)
            && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsInGhostState(client);
}

stock bool isAiSmoker(int client) {
    return IsValidInfected(client) && GetInfectedClass(client) == ZC_SMOKER && IsFakeClient(client)
            && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsInGhostState(client);
}

stock bool isAiSpitter(int client) {
    return IsValidInfected(client) && GetInfectedClass(client) == ZC_SPITTER && IsFakeClient(client)
            && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsInGhostState(client);
}

stock bool isAiHunter(int client) {
    return IsValidInfected(client) && GetInfectedClass(client) == ZC_HUNTER && IsFakeClient(client)
            && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsInGhostState(client);
}

stock bool isAiJockey(int client) {
    return IsValidInfected(client) && GetInfectedClass(client) == ZC_JOCKEY && IsFakeClient(client)
            && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsInGhostState(client);
}

stock bool isAiBoomer(int client) {
    return IsValidInfected(client) && GetInfectedClass(client) == ZC_BOOMER && IsFakeClient(client)
            && IsPlayerAlive(client) && !IsClientIncapped(client) && !IsInGhostState(client);
}

/**
* 获取当前被控的生还者数量
* @param void
* @return int
**/
stock int getPinnedSurvivorCount() {
    static int count;
    count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidSurvivor(i) || !IsPlayerAlive(i) || IsClientIncapped(i) || IsClientHanging(i))
            continue;
        if (!IsClientPinned(i))
            continue;
        count += 1;
    }
    return count;
}

/**
* 生还者是否处于胆汁状态
* @param client 客户端索引
* @return bool
**/
stock bool isClientBiled(int client) {
    if (!IsValidClient(client))
        return false;
    
    static int glowColor;
    glowColor = GetEntProp(client, Prop_Send, "m_glowColorOverride");
    if (glowColor == -4713783)
        return true;
    
    static float bileTime;
    bileTime = GetEntPropFloat(client, Prop_Send, "m_vomitFadeStart");
    if (bileTime != 0.0 && bileTime + FindConVar("z_vomit_fade_duration").FloatValue > GetGameTime())
        return true;
    return false;
}

stock bool clientPush(int client, float fwdAng[3], float scale) {
    if (!isAiTank(client))
        return false;

    static float velVec[3];
    GetEntPropVector(client, Prop_Send, "m_vecAbsVelocity", velVec);

    NormalizeVector(fwdAng, fwdAng);
    ScaleVector(fwdAng, scale);
    AddVectors(velVec, fwdAng, velVec);
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velVec);
    return true;
}

/**
* 返回客户端是否看到生还者
* @param client 客户端索引
* @return bool
**/
stock bool hasSightOfSurvivor(int client) {
    return view_as<bool>(HasEntProp(client, Prop_Send, "m_hasVisibleThreats"));
}

/**
* 获取距离某个客户端最近的生还者
* @param client 客户端索引
* @param exluceIncap 是否排除倒地的生还者
* @error 无法找到有效的生还者时返回 -1
* @return int 目标客户端索引
**/
stock int getClosestSurvivor(int client, bool excludeIncap = false) {
    static ArrayList targets;
    targets = new ArrayList(2);

    static float pos[3], targetPos[3];
    GetClientAbsOrigin(client, pos);
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidSurvivor(i) || !IsPlayerAlive(i))
            continue;
        if (excludeIncap && IsClientIncapped(i))
            continue;
        
        GetClientAbsOrigin(i, targetPos)
        targets.Set(targets.Push(GetVectorDistance(targetPos, pos)), i, 1);
    }

    SortADTArray(targets, Sort_Ascending, Sort_Float);
    if (targets.Length < 1) {
        delete targets;
        return -1;
    }
    static int target;
    target = targets.Get(0, 1);
    delete targets;
    return target;
}

stock bool clientIsVisibleToClient(int client, int target) {
    if (!isAiTank(client))
        return false;
    if (!IsValidClient(target) || !IsPlayerAlive(target))
        return false;
    
    static float pos[3], targetPos[3];
    GetClientEyePosition(client, pos);
    GetClientEyePosition(target, targetPos);
    static Handle hTrace;
    static bool visible;
    hTrace = TR_TraceRayFilterEx(pos, targetPos, MASK_SHOT, RayType_EndPoint, _CIsVisible2C_traceRayFilter, client);
    visible = !TR_DidHit(hTrace);
    delete hTrace;
    return visible;
}

stock bool _CIsVisible2C_traceRayFilter(int entity, int contentsMask, any data) {
    // 忽略自身与无效实体
    if (entity == data || !IsValidEntity(entity))
        return false;
    // 忽略客户端
    if (entity > 0 && entity <= MaxClients)
        return false;

    static char className[64];
    GetEntityClassname(entity, className, sizeof(className));
    if (StrContains(className, "trigger_", false) >= 0)
        return false;
    if (strcmp(className, "func_illusionary", false) == 0)
        return false;
    // 忽略玻璃
    static int solidType, effects;
    solidType = GetEntProp(entity, Prop_Data, "m_nSolidType");
    if (strcmp(className, "func_breakable", false) == 0 && solidType == 1)
        return false;
    // 忽略阻挡玩家或特感的空气墙
    if (strcmp(className, "func_playerclip", false) == 0 ||
        strcmp(className, "player_infected_clip", false) == 0 ||
        strcmp(className, "func_playerinfected_clip", false) == 0)
        return false;
    // 忽略效果包含 EF_NODRAW 的实体
    effects = GetEntProp(entity, Prop_Send, "m_fEffects");
    if (effects & 32)
        return false;

    return true;
}

stock bool _TraceWallFilter(int entity, int contentsMask, any data) {
    if (!IsValidEntity(entity))
        return false;

    if (entity != data) {
        static char className[32];
        GetEntityClassname(entity, className, sizeof(className));
        if (strcmp(className, "infected", false) == 0 || strcmp(className, "player", false) == 0)
            return false;
        return true;
    }

    return false;
}

stock bool floatIsNan(float val) {
    return (view_as<int>(val) & 0x7FFFFFFF) > 0x7F800000;
}

/**
* 给定函数起始内存地址, 输出 numBytes 个字节数据
* @param funcAddr 函数起始内存地址
* @param numBytes 输出的字节数
* @return void
**/
stock void dumpSigPattern(Address funcAddr, int numBytes) {
	char buffer[512];
	char tmp[8];
	buffer[0] = '\0';

	for (int i = 0; i < numBytes; i++) {
		int b = LoadFromAddress(funcAddr + view_as<Address>(i), NumberType_Int8) & 0xFF;

		if (i + 4 < numBytes) {
			// MOV reg, [absolute address]
			if ((b == 0x8B || b == 0xA1) && (LoadFromAddress(funcAddr + view_as<Address>(i + 1), NumberType_Int8) & 0xFF) == 0x0D) {
				// 输出 8B 0D ?? ?? ?? ??
				Format(tmp, sizeof(tmp), "%02X ", b);
				StrCat(buffer, sizeof(buffer), tmp);

				Format(tmp, sizeof(tmp), "%02X ", 0x0D);
				StrCat(buffer, sizeof(buffer), tmp);

				StrCat(buffer, sizeof(buffer), "? ? ? ? ");
				i += 5;	   // 跳过后面四个字节
				continue;
			}
			// PUSH imm32
			else if (b == 0x68 || (b >= 0xB8 && b <= 0xBF)) {
				Format(tmp, sizeof(tmp), "%02X ", b);
				StrCat(buffer, sizeof(buffer), tmp);
				StrCat(buffer, sizeof(buffer), "? ? ? ? ");
				i += 4;
				continue;
			}
			// CALL rel32
			else if (b == 0xE8) {
				Format(tmp, sizeof(tmp), "%02X ", b);
				StrCat(buffer, sizeof(buffer), tmp);
				StrCat(buffer, sizeof(buffer), "? ? ? ? ");
				i += 4;
				continue;
			}
		}

		// 正常字节
		Format(tmp, sizeof(tmp), "%02X ", b);
		StrCat(buffer, sizeof(buffer), tmp);
	}

	PrintToServer("Address %X sig pattern: %s", funcAddr, buffer);
}

/**
* 获取对象虚函数表指定索引的函数地址
* @param pObj 对象虚函数表指针
* @param index 索引
* @return Address 函数地址
**/
stock Address getVTableEntry(Address pObj, int index) {
	Address pVTable = LoadFromAddress(pObj, NumberType_Int32);
	return view_as<Address>(
        LoadFromAddress(pVTable + view_as<Address>(index * 4), NumberType_Int32)
    );
}

stock bool vectorsEqual(const float vec1[3], const float vec2[3]) {
    return (vec1[0] == vec2[0] &&
            vec1[1] == vec2[1] &&
            vec1[2] == vec2[2]);
}

/**
* 角度归一化
* @param angle 角度
* @return float 归一化后的角度
**/
stock float angleNormalize(float angle) {
    if (angle > 180)
        angle -= 360;
    else if (angle < -180)
        angle += 360;
    return angle;
}