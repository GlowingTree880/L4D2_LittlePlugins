/**
* @Author 夜羽真白
* @Date 2023-07-24 15:58:31
* @Description 特感找位控制
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

#define RAY_Z_HEIGHT 800.0
#define RAY_Z_OFFSET 20.0
#define PLAYER_HEIGHT 72.0
#define TRACE_RAY_ANGLE view_as<float>({90.0, 0.0, 0.0})
#define TRACE_RAY_TYPE RayType_Infinite
// 使用 L4D_GetNearestNavArea() 时 Nav 搜索范围
#define NEAREST_NAV_SEARCH_RANGE 120.0
// 最大找位次数
#define POS_FIND_MAX_ATTEMP 10

// NOTE: MASK SHOT + MASK NPCSOLID BRUSHONLY 多出来的两个 MASK (MASK_SHOT | CONTENTS_MONSTERCLIP | CONTENTS_GRATE)
#define TRACE_RAY_FLAG 					MASK_SHOT | CONTENTS_MONSTERCLIP | CONTENTS_GRATE

ConVar
	g_hMinDistance,
	g_hMinNavDistance,
	g_hDefaultGridMinDistance,
	g_hDefaultGridMaxDistance,
	g_hMaxDistance,
	g_hInitialNavDistance,
	g_hMaxNavDistance,
	g_hAllowSpawnInSafeArea,
	g_hPosShouldAheadSurvivor,
	g_hRunnerCheckDistance,
	g_hFindPosMethod;

ConVar
	g_hStartExpandTime,
	g_hFindPosMaxTime,
	g_hFailedFindPosNextDelay,
	g_hExpandUnit,
	g_hNaxExpandUnit;

int
	expandCount;

enum {
	BLOCK_TYPE_EVERYONE,
	BLOCK_TYPE_SURVIVORS,
	BLOCK_TYPE_PLAYER_INFECTED,
	BLOCK_TYPE_ALL_INFECTED,
	BLOCK_TYPE_ALL_PLAYERS_AND_PHYSICS_OBJECTS
};

// 找位方式 FindPosMethod
enum {
	FPM_NONE,
	FPM_USING_API,
	FPM_USING_ENHANCED_API,
	FPM_USING_RAY,
	FPM_SIZE
};

stock const char validEntityName[][] = {
	"prop_dynamic",
	"prop_physics",
	"prop_physics_multiplayer",
	"func_rotating",
	"infected",
	"tank_rock",
	"witch"
};

void infectedPosFindOnModuleStart() {
	g_hFindPosMethod = CreateConVar("inf_pos_find_method", "3", "特感找位方式 [1: 使用 L4D_GetRandomPZSpawnPosition API, 2: 使用增强 L4D_GetRandomPZSpawnPosition API, 3: 使用射线找位]", CVAR_FLAG, true, float(FPM_NONE + 1), true, float(FPM_SIZE - 1));
	g_hMinDistance = CreateConVar("inf_pos_min_distance", "150", "特感刷新位置距离目标的最小直线距离", CVAR_FLAG, true, 0.0);
	g_hMinNavDistance = CreateConVar("inf_pos_min_nav_distance", "100", "特感刷新位置距离目标的最小 Nav 距离", CVAR_FLAG, true, 0.0);
	g_hMaxDistance = CreateConVar("inf_pos_max_distance", "1000", "特感刷新位置距离目标的最大直线距离", CVAR_FLAG, true, 0.0);
	g_hInitialNavDistance = CreateConVar("inf_pos_init_nav_distance", "1500", "特感刷新位置距离目标初始 Nav 距离", CVAR_FLAG, true, 0.0);
	g_hMaxNavDistance = CreateConVar("inf_pos_max_nav_distance", "2800", "特感刷新位置距离目标的最大 Nav 距离 [从初始 Nav 距离开始, 网格开始拓展时拓展, 直到最大 Nav 距离停止拓展]", CVAR_FLAG, true, 0.0);
	g_hAllowSpawnInSafeArea = CreateConVar("inf_pos_allow_in_safearea", "0", "特感是否允许在安全区域刷新", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hPosShouldAheadSurvivor = CreateConVar("inf_pos_should_ahead", "0", "特感找位是否需要在目标生还者前方", CVAR_FLAG, true, 0.0, true, 1.0);
	// 找位网格大小
	g_hDefaultGridMinDistance = CreateConVar("inf_pos_default_grid_min", "600", "找位时网格初始大小", CVAR_FLAG, true, g_hMinDistance.FloatValue);
	g_hDefaultGridMaxDistance = CreateConVar("inf_pos_default_grid_max", "1500", "找位时网格可拓展的最大大小", CVAR_FLAG, true, g_hMinDistance.FloatValue);
	// 找位刷新时间
	g_hStartExpandTime = CreateConVar("inf_pos_start_expand_time", "1.25", "从开始找位刷新的时间算起, 超过这个时间没有刷新完成一波特感, 开始逐帧进行找位网格拓展", CVAR_FLAG, true, 0.0);
	g_hFindPosMaxTime = CreateConVar("inf_pos_find_max_time", "8.0", "允许一次找位刷新的最大时间, 超过这个时间则暂停 g_hFailedFindPosNextDelay 时间后继续启动找位 (0: 无上限)", CVAR_FLAG, true, 0.0);
	g_hFailedFindPosNextDelay = CreateConVar("inf_pos_fail_delay", "2.5", "一次找位刷新失败找位的暂停时间", CVAR_FLAG, true, 0.0);
	g_hExpandUnit = CreateConVar("inf_pos_expand_unit", "3", "逐帧进行找位网格拓展时每帧网格拓展多少单位", CVAR_FLAG, true, 0.0);
	g_hNaxExpandUnit = CreateConVar("inf_pos_nav_expand_unit", "3", "逐帧进行 Nav 距离拓展时每帧拓展多少单位", CVAR_FLAG, true, 0.0);
	// 跑男检测
	g_hRunnerCheckDistance = CreateConVar("inf_pos_runner_check_distance", "1500.0", "跑男检测距离 (0: 不检测跑男, 否则某个生还者在这个范围内的生还者密度小于 [2 个生还者的生还者密度] 则视为跑男, 特感优先以其进行找位)", CVAR_FLAG, true, 0.0);

	g_hMinDistance.AddChangeHook(changeHookSpawnDistance);
	g_hMinNavDistance.AddChangeHook(changeHookSpawnDistance);
}

void changeHookSpawnDistance(ConVar convar, const char[] oldValue, const char[] newValue) {
	CreateTimer(ROUND_START_DELAY, timerSetSpawnDistanceHandler, _, _);
}

// NOTE: 射线找位相关函数
#define POS_UP 0
#define POS_DOWN 1

#define X 0
#define Y 1
#define Z 2

// 高位补偿, 来自东哥, From: https://github.com/fantasylidong/CompetitiveWithAnne/blob/master/addons/sourcemod/scripting/AnneHappy/infected_control.sp
#define HIGH_POS_HEIGHT 300.0
#define HIGH_POS_COMP_DISTANCE 400.0

/**
* 根据传入的特感类型使用 L4D_GetRandomPZSpawnPosition 进行找位
* @param client 针对某个客户端为中心进行找位
* @param class 特感类型
* @param spawnPos 刷新位置
* @return void
**/
void getSpawnPosByAPI(const int client, const int class, float spawnPos[3]) {
	if (!IsValidSurvivor(client) || !IsPlayerAlive(client))
		return;
	
	if (!L4D_GetRandomPZSpawnPosition(client, class, POS_FIND_MAX_ATTEMP, spawnPos))
		log.error("%s: 无法在 %d 次内找到一个适合的 %s 生成位置", PLUGIN_PREFIX, POS_FIND_MAX_ATTEMP, INFECTED_NAME[class]);
	
	static float pos[3];
	static int nearestSurvivor;
	if (!IsValidClient(nearestSurvivor))
		return;
	// 获取最近生还者的位置
	GetClientAbsOrigin(nearestSurvivor, pos);
	
	static Address nav, targetNav;
	nav = isOnValidNavArea(spawnPos);
	if (nav == Address_Null)
		return;
	targetNav = L4D_GetNearestNavArea(pos, NEAREST_NAV_SEARCH_RANGE, false, false, false, TEAM_INFECTED);
	
	// 检查是否启用位置必须在目标前方
	if (g_hPosShouldAheadSurvivor.BoolValue && !navIsAheadAnotherNav(nav, targetNav))
		return;
}

/**
* 使用射线并配合 L4D_GetRandomPZSpawnPosition 进行找位, 思路来自鹅国人 (鹅佬)
* @param client 以这个客户端为中心进行找位
* @param class 需要刷新的特感类型
* @param gridIncrement 网格增量
* @param spawnPos 刷新位置
* @return void
**/
void getSpanPosByAPIEnhance(const int client, const int class,
							const float gridIncrement = 0.0, float spawnPos[3]) {
	// 首先使用射线检测, 看不到的位置增加 OBSCURED Nav 属性, 最后使用 L4D_GetRandomPZSpawnPosition 决定是否允许在这种地块上刷新
	spawnPos = NULL_VECTOR;
	if (!IsValidSurvivor(client) || !IsPlayerAlive(client))
		return;

	static int i;
	// 客户端位置, 找位网格左边界, 找位网格右边界, 射线坐标, 射线撞击位置坐标, 射线撞击位置与最近生还者位置的 Nav 距离
	static float pos[3], expandLeftPos[2][3], expandRightPos[2][3], rayPos[3], rayEndPos[3], visiblePos[3];
	static float tempPos[3];

	GetClientAbsOrigin(client, pos);
	CopyVectors(pos, expandLeftPos[POS_UP]);	CopyVectors(pos, expandLeftPos[POS_DOWN]);
	CopyVectors(pos, expandRightPos[POS_UP]);	CopyVectors(pos, expandRightPos[POS_DOWN]);
	// 缩放网格
	// 左上角
	expandLeftPos[POS_UP][X] -= g_hDefaultGridMinDistance.FloatValue;
	expandLeftPos[POS_UP][Y] += g_hDefaultGridMinDistance.FloatValue;
	// 左下角
	expandLeftPos[POS_DOWN][X] -= g_hDefaultGridMinDistance.FloatValue;
	expandLeftPos[POS_DOWN][Y] -= g_hDefaultGridMinDistance.FloatValue;
	// 右上角
	expandRightPos[POS_UP][X] += g_hDefaultGridMinDistance.FloatValue;
	expandRightPos[POS_UP][Y] += g_hDefaultGridMinDistance.FloatValue;
	// 右下角
	expandRightPos[POS_DOWN][X] += g_hDefaultGridMinDistance.FloatValue;
	expandRightPos[POS_DOWN][Y] -= g_hDefaultGridMinDistance.FloatValue;
	
	// 是否需要拓展网格, 且 expandCount 拓展次数 * gridIncrement 每次拓展的距离在网格最大范围与初始范围内
	static float offset;
	if (FloatCompare(gridIncrement, 0.0) > 0 &&
		(expandCount * gridIncrement <= g_hDefaultGridMaxDistance.FloatValue - g_hDefaultGridMinDistance.FloatValue)) {

		offset = expandCount * gridIncrement;
		
		// 左上角
		expandLeftPos[POS_UP][X] -= offset;
		expandLeftPos[POS_UP][Y] += offset;
		// 左下角
		expandLeftPos[POS_DOWN][X] -= offset;
		expandLeftPos[POS_DOWN][Y] -= offset;
		// 右上角
		expandRightPos[POS_UP][X] += offset;
		expandRightPos[POS_UP][Y] += offset;
		// 右下角
		expandRightPos[POS_DOWN][X] += offset;
		expandRightPos[POS_DOWN][Y] -= offset;
		
		expandCount++;
	}

	static Handle traceRay;
	for (i = 0; i < posFindAttemp; i++) {
		// 确定射线初始位置
		rayPos[X] = GetRandomFloatInRange(expandLeftPos[POS_UP][X], expandRightPos[POS_UP][X]);
		rayPos[Y] = GetRandomFloatInRange(expandLeftPos[POS_UP][Y], expandRightPos[POS_DOWN][Y]);
		rayPos[Z] = GetRandomFloatInRange(pos[Z], pos[Z] + RAY_Z_HEIGHT);

		// 进行射线初始位置到目标生还者的直线距离的判断, 不符合直接跳过
		CopyVectors(rayPos, tempPos);
		tempPos[Z] = pos[Z];
		if (GetVectorDistance(pos, tempPos) < g_hMinDistance.FloatValue)
			continue;

		traceRay = TR_TraceRayFilterEx(rayPos, TRACE_RAY_ANGLE, TRACE_RAY_FLAG, TRACE_RAY_TYPE, traceRayFilter, client);
		if (traceRay == null)
			continue;
		
		TR_GetEndPosition(rayEndPos, traceRay);
		CopyVectors(rayEndPos, visiblePos);
		delete traceRay;

		rayEndPos[2] += RAY_Z_OFFSET;
		visiblePos[2] += PLAYER_HEIGHT;

		static Address rayEndPosNav, nearestSurvivorNav;
		rayEndPosNav = isOnValidNavArea(rayEndPos);

		// 检测射线撞击位置是否在无效 Nav 上
		if (rayEndPosNav == Address_Null || posWillStuckClient(rayEndPos))
			continue;
		// 位置是否可以被任何生还者看见, 无需检测直线距离, 由 z_spawn_safety_range 决定
		if (isVisibleToSurvivor(visiblePos, rayEndPosNav))
			continue;

		// 是否启用位置必须在目标前方
		if (g_hPosShouldAheadSurvivor.BoolValue && !navIsAheadAnotherNav(rayEndPosNav, nearestSurvivorNav))
			continue;

		// 为位置添加 OBSCURED 属性
		static int flag;
		flag = L4D_GetNavArea_AttributeFlags(rayEndPosNav);
		flag |= NAV_SPAWN_OBSCURED;
		L4D_SetNavArea_AttributeFlags(rayEndPosNav, flag);
	}

	// 选择一个刷新位置
	if (!L4D_GetRandomPZSpawnPosition(client, class, POS_FIND_MAX_ATTEMP, spawnPos))
		log.error("%s: 无法在 %d 次内找到一个适合的 %s 生成位置", PLUGIN_PREFIX, POS_FIND_MAX_ATTEMP, INFECTED_NAME[class]);
}

/**
* 根据客户端位置使用射线找位并返回找到的一个有效位置
* @param client 需要找位的客户端索引
* @param gridIncrement 网格增量
* @param navIncrement Nav 增量
* @param spawnPos 刷新位置
* @return void
**/
void getSpawnPos(const int client, const float gridIncrement = 0.0, const float navIncrement = 0.0, float spawnPos[3]) {
	spawnPos = NULL_VECTOR;
	if (!IsValidSurvivor(client) || !IsPlayerAlive(client))
		return;

	static int i;
	// 客户端位置, 找位网格左边界, 找位网格右边界, 射线坐标, 射线撞击位置坐标, 射线撞击位置与最近生还者位置的 Nav 距离
	static float pos[3], expandLeftPos[2][3], expandRightPos[2][3], rayPos[3], rayEndPos[3], visiblePos[3];
	static float tempPos[3];

	GetClientAbsOrigin(client, pos);
	CopyVectors(pos, expandLeftPos[POS_UP]);	CopyVectors(pos, expandLeftPos[POS_DOWN]);
	CopyVectors(pos, expandRightPos[POS_UP]);	CopyVectors(pos, expandRightPos[POS_DOWN]);
	// 缩放网格
	// 左上角
	expandLeftPos[POS_UP][X] -= g_hDefaultGridMinDistance.FloatValue;
	expandLeftPos[POS_UP][Y] += g_hDefaultGridMinDistance.FloatValue;
	// 左下角
	expandLeftPos[POS_DOWN][X] -= g_hDefaultGridMinDistance.FloatValue;
	expandLeftPos[POS_DOWN][Y] -= g_hDefaultGridMinDistance.FloatValue;
	// 右上角
	expandRightPos[POS_UP][X] += g_hDefaultGridMinDistance.FloatValue;
	expandRightPos[POS_UP][Y] += g_hDefaultGridMinDistance.FloatValue;
	// 右下角
	expandRightPos[POS_DOWN][X] += g_hDefaultGridMinDistance.FloatValue;
	expandRightPos[POS_DOWN][Y] -= g_hDefaultGridMinDistance.FloatValue;
	
	// expandCount 是否需要增加, 拓展网格 或 拓展 Nav 任意一个场景开启 expandCount 都需要增加
	// 1 为允许拓展, 2 为网格拓展完成
	static int shouldIncreaseExpandCount;
	shouldIncreaseExpandCount = FloatCompare(gridIncrement, 0.0) > 0 || FloatCompare(navIncrement, 0.0) > 0;
	// 是否需要拓展网格, 且 expandCount 拓展次数 * gridIncrement 每次拓展的距离在网格最大范围与初始范围内
	static float offset, maxNavDistance;
	maxNavDistance = g_hInitialNavDistance.FloatValue;
	if (FloatCompare(gridIncrement, 0.0) > 0 &&
		(expandCount * gridIncrement <= g_hDefaultGridMaxDistance.FloatValue - g_hDefaultGridMinDistance.FloatValue)) {

		offset = expandCount * gridIncrement;
		
		// 左上角
		expandLeftPos[POS_UP][X] -= offset;
		expandLeftPos[POS_UP][Y] += offset;
		// 左下角
		expandLeftPos[POS_DOWN][X] -= offset;
		expandLeftPos[POS_DOWN][Y] -= offset;
		// 右上角
		expandRightPos[POS_UP][X] += offset;
		expandRightPos[POS_UP][Y] += offset;
		// 右下角
		expandRightPos[POS_DOWN][X] += offset;
		expandRightPos[POS_DOWN][Y] -= offset;
		
		if ((shouldIncreaseExpandCount & 0x01) == 1) {
			expandCount++;
			// 修改为 2, 表示已经完成网格拓展
			shouldIncreaseExpandCount <<= 1;
		}
	}
	// 是否需要拓展 Nav 距离
	if (FloatCompare(navIncrement, 0.0) > 0 &&
		expandCount * navIncrement <= g_hMaxNavDistance.FloatValue - g_hInitialNavDistance.FloatValue) {
		
		// 已经被网格拓展过, expandCount 先修改为原来的值, 接着进行 Nav 拓展, 保证完成网格和 Nav 拓展 expandCount 只增加一次
		if ((shouldIncreaseExpandCount & 0x02) == 2)
			offset = (expandCount - 1) * navIncrement;
		maxNavDistance += offset;

		if ((shouldIncreaseExpandCount & 0x01) == 1)
			expandCount++;
	}

	static Handle traceRay;
	for (i = 0; i < posFindAttemp; i++) {
		// 确定射线初始位置
		rayPos[X] = GetRandomFloatInRange(expandLeftPos[POS_UP][X], expandRightPos[POS_UP][X]);
		rayPos[Y] = GetRandomFloatInRange(expandLeftPos[POS_UP][Y], expandRightPos[POS_DOWN][Y]);
		rayPos[Z] = GetRandomFloatInRange(pos[Z], pos[Z] + RAY_Z_HEIGHT);

		// 进行射线初始位置到目标生还者的直线距离的判断, 不符合直接跳过
		CopyVectors(rayPos, tempPos);
		tempPos[Z] = pos[Z];
		if (GetVectorDistance(pos, tempPos) < g_hMinDistance.FloatValue)
			continue;

		traceRay = TR_TraceRayFilterEx(rayPos, TRACE_RAY_ANGLE, TRACE_RAY_FLAG, TRACE_RAY_TYPE, traceRayFilter, client);
		if (traceRay == null)
			continue;
		
		TR_GetEndPosition(rayEndPos, traceRay);
		delete traceRay;
		CopyVectors(rayEndPos, visiblePos);

		rayEndPos[2] += RAY_Z_OFFSET;
		visiblePos[2] += PLAYER_HEIGHT;

		// HACK: 位置有效性检测, 性能测试, Bug 排除
		static Address rayEndPosNav, nearestSurvivorNav;
		rayEndPosNav = isOnValidNavArea(rayEndPos);

		// 检测射线撞击位置是否在无效 Nav 上
		if (rayEndPosNav == Address_Null || posWillStuckClient(rayEndPos))
			continue;
		// 位置是否可以被任何生还者看见
		if (isVisibleToSurvivor(visiblePos, rayEndPosNav))
			continue;

		static int nearestSurvivor;
		nearestSurvivor = getNearestSurvivorFromPos(rayEndPos);
		if (!IsValidClient(nearestSurvivor))
			continue;
		// 射线撞击位置与距离射线撞击位置最近的生还者 是否满足直线距离
		static float distance, targetPos[3];
		GetClientAbsOrigin(nearestSurvivor, targetPos);
		distance = GetVectorDistance(rayEndPos, targetPos);
		if (distance < g_hMinDistance.FloatValue || distance > g_hMaxDistance.FloatValue)
			continue;

		// NOTE: 高位 Nav 距离补偿, Nav 最大距离已经确定
		if (FloatAbs(rayEndPos[2] - pos[2]) >= HIGH_POS_HEIGHT)
			maxNavDistance += HIGH_POS_COMP_DISTANCE;

		// 从射线撞击位置到最近生还者 Nav 处无路可走, 跳过
		nearestSurvivorNav = L4D_GetNearestNavArea(targetPos, NEAREST_NAV_SEARCH_RANGE, false, false, false, TEAM_INFECTED);
		if (!L4D2_NavAreaBuildPath(rayEndPosNav, nearestSurvivorNav, maxNavDistance, TEAM_INFECTED, false))
			continue;

		// 获取 Nav 距离, 判断射线撞击位置 Nav 与最近生还所在的 Nav 距离是否在有效 Nav 距离之间
		distance = L4D2_NavAreaTravelDistance(rayEndPos, pos, false);
		if (distance < g_hMinNavDistance.FloatValue || distance > maxNavDistance)
			continue;

		// 是否启用位置必须在目标前方
		if (g_hPosShouldAheadSurvivor.BoolValue && !navIsAheadAnotherNav(rayEndPosNav, nearestSurvivorNav))
			continue;

		// 是否启用安全区域刷新
		if (!g_hAllowSpawnInSafeArea.BoolValue && (L4D_GetNavArea_SpawnAttributes(rayEndPosNav) & NAV_SPAWN_CHECKPOINT))
			continue;

		// 位置有效, 返回坐标, 跳出
		CopyVectors(rayEndPos, spawnPos);
		break;
	}
}

static bool traceRayFilter(int entity, int contentsMask, any data) {
	// 射线撞击到自身或客户端实体，不允许穿过
	if (entity == data || (entity >= 1 && entity <= MaxClients)) { return false; }
	// 撞击到其他实体，检测类型
	static char className[64];
	GetEntityClassname(entity, className, sizeof(className));
	if (checkRayImpactEntityValid(className)) { return false; }
	// blocker 类型的，获取是否阻塞与阻塞类型
	if (strcmp(className, "env_physics_blocker") == 0 || strcmp(className, "env_player_blocker") == 0)
	{
		if (!HasEntProp(entity, Prop_Send, "m_bBlocked")) { return false; }
		if (GetEntProp(entity, Prop_Send, "m_bBlocked") != 1) { return true; }
		static int blockType;
		blockType = GetEntProp(entity, Prop_Send, "m_nBlockType");
		return (blockType == BLOCK_TYPE_SURVIVORS || blockType == BLOCK_TYPE_PLAYER_INFECTED);
	}
	return true;
}

static bool traceRayNoPlayerFilter(int entity, int contentsMask, any data) {
    if (entity == data || (entity >= 1 && entity <= MaxClients)) {
        return false;
    }
    return true;
}

/**
* 获取距离给定位置最近的生还者
* @param pos 给定位置坐标
* @return int
**/
static int getNearestSurvivorFromPos(const float pos[3]) {
	static int i;
	static ArrayList list;
	list = new ArrayList(2);
	float targetPos[3];
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
			continue;
		GetClientAbsOrigin(i, targetPos);
		list.Set(list.Push(GetVectorDistance(pos, targetPos)), i, 1);
	}
	if (list.Length < 1) {
		delete list;
		return INVALID_CLIENT_INDEX;
	}
	list.Sort(Sort_Ascending, Sort_Float);
	i = list.Get(0, 1);
	delete list;
	return i;
}

/**
* 判断给定坐标是否在有效 Nav Area 上
* @param pos 给定坐标
* @return Address, 有效返回 Nav Address, 无效返回 Address_Null
**/
static Address isOnValidNavArea(float pos[3]) {
	return L4D2Direct_GetTerrorNavArea(pos);
}

/*
 * @Description: 检查射线撞击的实体是否在 validEntityName 中
 * @param: {className} 实体名称
 * @return: {bool} 在返回 true，否则返回 false
 */
static bool checkRayImpactEntityValid(const char[] className)
{
	static int i;
	for (i = 0; i < sizeof(validEntityName); i++) {
		if (strcmp(className, validEntityName[i]) == 0) {
			return false;
		}
	}
	return true;
}

/**
* 判断某个位置是否能被任意一个生还者看见
* @param pos 需要检测的位置坐标
* @param navArea 这个位置所在的 navArea, 默认 Address_Null
* @return bool
**/
static bool isVisibleToSurvivor(float pos[3], Address navArea = Address_Null) {
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		if (L4D2_IsVisibleToPlayer(i, TEAM_SURVIVOR, TEAM_INFECTED, view_as<int>(navArea), pos)) {
			return true;
		}
	}
	return false;
}

/**
* 检测某 Nav Area 是否在另一块 Nav Area 路程之前
* @param source 需要检测的 Nav Area 地址
* @param target 作为目标的 Nav Area 地址
* @return bool
**/
static bool navIsAheadAnotherNav(Address source, Address target) {
	if (source == Address_Null || target == Address_Null) {
		return false;
	}
	return FloatCompare(L4D2Direct_GetTerrorNavAreaFlow(source), L4D2Direct_GetTerrorNavAreaFlow(target)) > 0;
}

/**
* 检测当前位置是否会卡住客户端
* @param pos 需要检测的位置坐标
* @return bool
**/
static bool posWillStuckClient(float pos[3])
{
	static Handle traceRay;
	traceRay = TR_TraceHullFilterEx(pos, pos, view_as<float>({-30.0, -30.0, 0.0}), view_as<float>({30.0, 30.0, PLAYER_HEIGHT}), MASK_PLAYERSOLID, traceRayNoPlayerFilter);
	if (traceRay != null) {
		if (TR_DidHit(traceRay)) {
			delete traceRay;
			return true;
		}
	}
	delete traceRay;
	return false;
}

/**
* 生还者密度计算 (以 client 为中心 g_hRunnerCheckDistance 范围内除去自身的生还者数量与总生还者数量占比)
* @param client 需要计算生还者密度的客户端索引
* @return float
**/
stock float getSurvivorDensity(int client) {
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) {
		return -1.0;
	}
	static int i;
	int survivorCount, rangeCount;
	static float pos[3], targetPos[3];
	GetClientAbsOrigin(client, pos);
	for (i = 1; i <= MaxClients; i++) {
		if (i == client || !IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		survivorCount++;
		GetClientAbsOrigin(i, targetPos);
		if (GetVectorDistance(pos, targetPos) <= g_hRunnerCheckDistance.FloatValue) {
			rangeCount++;
		}
	}
	return view_as<float>(rangeCount) / view_as<float>(survivorCount);
}