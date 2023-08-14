/**
* @Author 夜羽真白
* @Date 2023-08-10 14:26:28
* @Description BossController 时钟回调部分
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

enum {
	SPAWN_TYPE_NONE,
	SPAWN_TYPE_TANK,
	SPAWN_TYPE_WITCH,
	SPAWN_TYPE_SIZE
};

Handle
	delaySpawnTankTimer,
	delaySpawnWitchTimer;

float
	delaySpawnTankTime,
	delaySpawnWitchTime;

bool
	isTankSpawnFailed,
	isWitchSpawnFailed;

// TODO: 获取随机 Boss 刷新路程算法, 可更改为 ZoneMod witch_and_tankifier GetRandomIntervalNum()
// 1. 对抗第二局, 不随机获取 Boss 路程
// 2. 静态地图, 不随机获取 Boss 路程
// 3. 救援关, 且开启救援关禁止插件接管 Boss 刷新, 不随机获取 Boss 路程
/**
* 回合开始, 获取 Boss 允许刷新路程时钟回调
* @param timer 时钟句柄
* @return Action
**/
public Action timerGetBossFlow(Handle timer) {

	// 检查 MapInfo 文件是否存在, 存在则从文件导入 KeyValue
	checkMapInfoExist();
	if (isMapInfoExist) {
		kvMapInfo = new KeyValues("MapInfo");
		if (!kvMapInfo.ImportFromFile(mapInfoPath)) {
			log.error("%s: 无法将文件 %s 转换为 KeyValue, 请确认文件内容是否正确", PLUGIN_PREFIX, mapInfoPath);
			SetFailState("%s: 无法将文件 %s 转换为 KeyValue, 请确认文件内容是否正确", PLUGIN_PREFIX, mapInfoPath);
		}
	}

	// 对抗第二局, 不重新获取 Boss 刷新路程
	if (InVersusSecondRound()) {
		return Plugin_Stop;
	}

	// 获取 Boss 刷新上下限路程
	static int i, cvarFlowMin, cvarFlowMax;
	cvarFlowMin = RoundToCeil(game_bossFlowMin.FloatValue * 100.0);
	cvarFlowMax = RoundToFloor(game_bossFlowMax.FloatValue * 100.0);
	log.debugAndInfo("%s: Cvar 配置 Boss 刷新路程为 %d ~ %d", PLUGIN_PREFIX, cvarFlowMin, cvarFlowMax);
	if (isMapInfoExist) {
		// 获取 MapInfo 中配置的 Boss 刷新上下限路程
		if (kvMapInfo.JumpToKey("versus_boss_flow_min", false)) {
			cvarFlowMin = kvMapInfo.GetNum("versus_boss_flow_min", cvarFlowMin);
			log.debugAndInfo("%s: MapInfo 文件中配置的 Boss 刷新路程下限为 %d, 使用 MapInfo 的值", PLUGIN_PREFIX, cvarFlowMin);
		}
		if (kvMapInfo.JumpToKey("versus_boss_flow_max", false)) {
			cvarFlowMax = kvMapInfo.GetNum("versus_boss_flow_max", cvarFlowMax);
			log.debugAndInfo("%s: MapInfo 文件中配置的 Boss 刷新路程上限为 %d, 使用 MapInfo 的值", PLUGIN_PREFIX, cvarFlowMax);
		}
	}

	tankPercentList.Clear();
	witchPercentList.Clear();

	// 初始化 Tank 与 Witch 刷新路程, 假设 Boss 刷新上下限为 20-80, 则向 Tank 与 Witch 路程集合中填充 20-80
	for (i = cvarFlowMin; i <= cvarFlowMax; i++) {
		tankPercentList.Push(i);
		witchPercentList.Push(i);
	}

	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	log.debugAndInfo("%s: MapInfo 是否存在 %b, 是否找到当前地图 %s 的 MapInfo 配置 %b, 是否是静态 Tank 地图 %b, 是否是静态 Witch 地图 %b", PLUGIN_PREFIX, isMapInfoExist, mapName, kvMapInfo == null ? false : kvMapInfo.JumpToKey(mapName, false), isStaticTankMap(mapName), isStaticWitchMap(mapName));
	if (isMapInfoExist) {
		kvMapInfo.Rewind();
	}

	// MapInfo 不存在或未配置本章节 MapInfo 信息
	if (!isMapInfoExist || !kvMapInfo.JumpToKey(mapName, false)) {
		// 允许刷新 Boss 且不是静态地图 或 当前是救援关非静态地图且允许插件刷新 Boss, 随机 Boss 路程
		if (allowSpawnTankInNormal() || allowSpawnBossInFinale()) {
			tankFlow = getRandomIntervalNum(tankPercentList);
		}
		if (allowSpawnWitchInNormal() || allowSpawnBossInFinale()) {
			removeWitchAvoidTankPercent();
			witchFlow = getRandomIntervalNum(witchPercentList);
		}

		setTankPercent(tankFlow);
		setWitchPercent(witchFlow);

		log.debugAndInfo("%s: MapInfo 文件不存在或当前未配置本地图 %s 的 MapInfo 信息, 不会读取 Tank 与 Witch Ban Flow 路程\n随机 Tank 路程为 %d, 随机 Witch 路程为 %d", PLUGIN_PREFIX, mapName, tankFlow, witchFlow);
		return Plugin_Stop;
	}

	// 获取 Tank Ban Flow 路程
	if (allowSpawnTankInNormal() || allowSpawnBossInFinale()) {
		getAndDeleteBanFlow("tank_ban_flow");
		if (tankPercentList.Length < 1) {
			tankFlow = 0;
			setTankPercent(0);
			log.debugAndInfo("%s: 当前 Tank Ban Flow 覆盖了 %d ~ %d 路程, 因此不会刷新路程 Tank", PLUGIN_PREFIX, cvarFlowMin, cvarFlowMax);
		} else {
			tankFlow = getRandomIntervalNum(tankPercentList);
			setTankPercent(tankFlow);
			log.debugAndInfo("%s: MapInfo 文件存在, 随机 Tank 路程 %d", PLUGIN_PREFIX, tankFlow);
		}
	} else {
		tankFlow = 0;
		setTankPercent(0);
		log.debugAndInfo("%s: 当前是否允许刷新 Tank: %b, 是否是静态 Tank 地图: %b, 是否终局 %b, 终局是否禁止插件接管 Boss 刷新 %b, 不会刷新路程 Tank", PLUGIN_PREFIX, g_hTankCanSpawn.BoolValue, isStaticTankMap(mapName), isFinaleMap(), g_hDisableInFinale.BoolValue);
	}

	// 获取 Witch Ban Flow 路程
	if (allowSpawnWitchInNormal() || allowSpawnBossInFinale()) {
		getAndDeleteBanFlow("witch_ban_flow");
		if (witchPercentList.Length < 1) {
			witchFlow = 0;
			setWitchPercent(0);
			log.debugAndInfo("%s: 当前 Witch Ban Flow 覆盖了 %d ~ %d 路程, 因此不会刷新路程 Witch", PLUGIN_PREFIX, cvarFlowMin, cvarFlowMax);
		} else {
			// 设置 Witch Avoid Tank 路程
			removeWitchAvoidTankPercent();

			// 第二次检查, 获取 Witch Ban Flow 后是否 Witch 路程集合为空
			if (witchPercentList.Length < 1) {
				witchFlow = 0;
				setWitchPercent(0);
				log.debugAndInfo("%s: Witch Avoid Tank 路程设置完毕, 覆盖了所有 Witch 可以刷新的路程, 因此不会刷新路程 Witch", PLUGIN_PREFIX);
				return Plugin_Stop;
			}

			witchFlow = getRandomIntervalNum(witchPercentList);
			setWitchPercent(witchFlow);
			log.debugAndInfo("%s: MapInfo 文件存在, 随机 Witch 路程 %d", PLUGIN_PREFIX, witchFlow);
		}
	} else {
		witchFlow = 0;
		setWitchPercent(0);
		log.debugAndInfo("%s: 当前是否允许刷新 Witch: %b, 是否是静态 Witch 地图: %b, 是否终局 %b, 终局是否禁止插件接管 Boss 刷新 %b, 不会刷新路程 Witch", PLUGIN_PREFIX, g_hWitchCanSpawn.BoolValue, isStaticWitchMap(mapName), isFinaleMap(), g_hDisableInFinale.BoolValue);
	}

	return Plugin_Stop;
}

void removeWitchAvoidTankPercent() {
	if (g_hWitchAvoidTank.BoolValue && tankFlow > 0) {
		static int i, index, left, right, half;
		static int cvarFlowMin, cvarFlowMax;
		cvarFlowMin = RoundToCeil(game_bossFlowMin.FloatValue * 100.0);
		cvarFlowMax = RoundToFloor(game_bossFlowMax.FloatValue * 100.0);

		half = RoundToNearest(g_hWitchAvoidTank.FloatValue / 2.0);
		left = (tankFlow - half) < cvarFlowMin ? cvarFlowMin : (tankFlow - half);
		right = (tankFlow + half) > cvarFlowMax ? cvarFlowMax : (tankFlow + half);

		log.debugAndInfo("%s: 当前 Tank 路程 %d%%, Witch Avoid Tank 路程 %d, half %d, Witch 禁止刷新路程 [%d - %d]", PLUGIN_PREFIX, tankFlow, g_hWitchAvoidTank.IntValue, half, left, right);

		for (i = left; i <= right; i++) {
			if ((index = witchPercentList.FindValue(i)) < 0) {
				continue;
			}
			witchPercentList.Erase(index);
		}
	}
}

/**
* 根据 keyName 获取 Tank 或 Witch 的 Ban Flow 并从刷新集合中删除相应的 Ban Flow
* @param kayName 指定键名, 需要处理 Tank 或 Witch 的 Ban Flow
* @return void
**/
void getAndDeleteBanFlow(const char[] keyName) {
	static char mapName[64], sectionName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	static int i, index, minBanFlow, maxBanFlow;

	if (!isMapInfoExist) {
		return;
	}

	kvMapInfo.Rewind();
	if (!kvMapInfo.JumpToKey(mapName)) {
		log.error("%s: 尝试获取 %s 是找不到对应地图 %s 的 Ban Flow 设置", PLUGIN_PREFIX, keyName, mapName);
		return;
	}

	KeyValues kvBanFlow = new KeyValues(keyName);
	// 存在 相应的 Ban Flow 的 key
	if (kvMapInfo.JumpToKey(keyName)) {
		KvCopySubkeys(kvMapInfo, kvBanFlow);
	}
	if (kvBanFlow.GotoFirstSubKey()) {
		log.debugAndInfo("%s: 当前地图 %s, %s:", PLUGIN_PREFIX, mapName, keyName);
		do {
			kvBanFlow.GetSectionName(sectionName, sizeof(sectionName));

			minBanFlow = kvBanFlow.GetNum("min", -1);
			maxBanFlow = kvBanFlow.GetNum("max", -1);

			if (!isValidInterval(minBanFlow, maxBanFlow)) {
				continue;
			}
			log.debugAndInfo("\tSection Name: %s, Ban Flow: [%d - %d]", sectionName, minBanFlow, maxBanFlow);

			if (strcmp(keyName, "tank_ban_flow", false) == 0) {
				// 从 Tank 刷新集合中删除这一段 Ban Flow
				for (i = minBanFlow; i <= maxBanFlow; i++) {
					if ((index = tankPercentList.FindValue(i)) >= 0) {
						tankPercentList.Erase(index);
					}
				}
			} else if (strcmp(keyName, "witch_ban_flow", false) == 0) {
				// 从 Witch 刷新集合中删除这一段 Ban Flow
				for (i = minBanFlow; i <= maxBanFlow; i++) {
					if ((index = witchPercentList.FindValue(i)) >= 0) {
						witchPercentList.Erase(index);
					}
				}
			}
		} while(kvBanFlow.GotoNextKey());
	}
	delete kvBanFlow;
}

/**
* 使用 ZoneMod witch_and_tankifier 的 GetRandomIntervalNum 方式获取一个随机 Boss 刷新路程
* @param list Boss 刷新路程集合
* @return int
**/
int getRandomIntervalNum(ArrayList list) {
	if (list.Length < 1) {
		return 0;
	}

	// 一段的下限, 上限, 本段长度
	ArrayList interval = new ArrayList(3);

	int i, index, intervalIndex, totalLength = 0, left = -1;
	int start = list.Get(0), end = list.Get(list.Length - 1);
	log.debugAndInfo("%s: Get Random Interval Num, Start %d, End %d", PLUGIN_PREFIX, start, end);
	for (i = start; i <= end; i++) {
		index = list.FindValue(i);

		if (index >= 0 && left == -1) {
			left = i;
		}
		if ((index < 0 && left > -1)) {
			totalLength += (i - left);

			intervalIndex = interval.Push(left);
			interval.Set(intervalIndex, i - 1, 1);
			interval.Set(intervalIndex, i - left, 2);
			log.debugAndInfo("%s: \tSegment [%d - %d], Segment Length %d, Total Length %d", PLUGIN_PREFIX, left, i - 1, (i - left), totalLength);
			
			left = -1;
		}
		// 遍历到右边界
		if (left > -1 && index >= 0 && i == end) {
			totalLength += (i - left + 1);

			intervalIndex = interval.Push(left);
			interval.Set(intervalIndex, i, 1);
			interval.Set(intervalIndex, i - left + 1, 2);
			log.debugAndInfo("%s: \tSegment [%d - %d], Segment Length %d, Total Length %d", PLUGIN_PREFIX, left, i, (i - left + 1), totalLength);

			left = -1;
		}
	}
	
	int ret, random = GetRandomIntInRange(0, totalLength - 1);
	log.debugAndInfo("%s: \tRandom: %d, Total Length: %d", PLUGIN_PREFIX, random, totalLength);
	for (i = 0; i < interval.Length; i++) {
		if (random < interval.Get(i, 2)) {
			ret = interval.Get(i, 0) + random - 1;
			delete interval;
			return ret;
		} else {
			random -= interval.Get(i, 2);
		}
	}
	delete interval;
	return 0;
}

/**
* 将本局 Tank 与 Witch 位置信息更新到 ReadyUp 面板 Footer 中
* @param timer 时钟句柄
* @return Action
**/
public Action timerUpdateReadyUpFooter(Handle timer) {
	if (!isReadyUpExist) {
		return Plugin_Stop;
	}

	static char tankStr[128], witchStr[128], newFooter[128];
	getTankPercentString(tankStr, sizeof(tankStr), true);
	getWitchPercentString(witchStr, sizeof(witchStr), true);

	if (g_hShowTankPercent.BoolValue && g_hShowWitchPercent.BoolValue) {
		FormatEx(newFooter, sizeof(newFooter), "%s, %s", tankStr, witchStr);
	} else if (g_hShowTankPercent.BoolValue) {
		FormatEx(newFooter, sizeof(newFooter), "%s", tankStr);
	} else if (g_hShowWitchPercent.BoolValue) {
		FormatEx(newFooter, sizeof(newFooter), "%s", witchStr);
	}

	// 如果 ReadyUp 面板 Footer 位置已经被添加过, 直接编辑 Footer 即可
	if (isReadyUpFooterAdded) {
		EditFooterStringAtIndex(readyUpFooterIndex, newFooter);
	} else {
		// 没有被添加过, 直接添加 newFooter 到 Footer 位置即可, 接着更新 Footer 字符串索引
		readyUpFooterIndex = AddStringToReadyFooter(newFooter);
		isReadyUpFooterAdded = true;
	}

	return Plugin_Stop;
}

public Action timerGetBossFlowWithDkrInclude(Handle timer) {
	if (isDarkCarnivalRemix()) {
		if (InVersusSecondRound()) {
			tankFlow = dkrFirstRoundTankPercent;
			witchFlow = dkrFirstRoundWitchPercent;
		} else {
			if (L4D_IsVersusMode()) {
				if (!L4D2Direct_GetVSTankToSpawnThisRound(0)) {
					if (FloatCompare(L4D2Direct_GetVSTankFlowPercent(0) * 100.0, 1.0) < 0) {
						if (!g_hTankCanSpawn.BoolValue) {
							tankFlow = 0;
						}
					}
				} else {
					tankFlow = dkrFirstRoundTankPercent;
				}
			} else {
				if (tankFlow > 0) {
					tankFlow = dkrFirstRoundTankPercent;
				}
			}

			if (L4D_IsVersusMode()) {
				if (!L4D2Direct_GetVSWitchToSpawnThisRound(0)) {
					if (FloatCompare(L4D2Direct_GetVSWitchFlowPercent(0) * 100.0, 1.0) < 0) {
						if (!g_hWitchCanSpawn.BoolValue) {
							witchFlow = 0;
						}
					}
				} else {
					witchFlow = dkrFirstRoundWitchPercent;
				}
			} else {
				if (witchFlow > 0) {
					witchFlow = dkrFirstRoundWitchPercent;
				}
			}
		}
	}
	// NOTE:
	// 省略 else 部分, else 部分原先为 boss_percent 使用 L4D2Direct_GetVSTankFlowPercent() 获取 Boss 路程给 boss_percent 插件打印
	// 可改为直接使用 tankFlow 与 witchFlow

	return Plugin_Stop;
}

// HACK: 添加生还者路程提示 translation
// "#format" "{1:d},{2:d}"
// {B}[{W}Boss{B}]: {W}当前路程{G}{1}, Tank {W}将在{G}{2}位置刷新
/**
* 生还者完成路程检测时钟回调
* @param timer 时钟句柄
* @return Action
**/
public Action timerSurvivorDistanceCheckHandler(Handle timer) {
	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	static int completion, startTankPromptComp, startWitchPromptComp;
	completion = getSurvivorFlowZone();
	if (completion < 0 || completion > 100) {
		return Plugin_Continue;
	}

	// 生还者完成路程提示
	if (!isTankSpawned && tankFlow > 0 && tankFlow <= 100 && allowSpawnTankInNormal() || allowSpawnBossInFinale()) {
		startTankPromptComp = tankFlow - g_hPromptDist.IntValue;
		// 完成的路程大于已经提示过的路程 且 完成过的路程处在开始提示路程到刷新路程间, 进行提示
		if (completion > promptedDistance && completion >= startTankPromptComp && completion < tankFlow) {
			CPrintToChatAll("%t", "TankPrompt", completion, tankFlow);
			promptedDistance = completion;
		}
		if (L4D_IsVersusMode() && completion > tankFlow) {
			isTankSpawned = true;
		}
	}
	if (!isWitchSpawned && witchFlow > 0 && witchFlow <= 100 && allowSpawnWitchInNormal() || allowSpawnBossInFinale()) {
		startWitchPromptComp = witchFlow - g_hPromptDist.IntValue;
		if (completion > promptedDistance && completion >= startWitchPromptComp && completion < witchFlow) {
			CPrintToChatAll("%t", "WitchPrompt", completion, witchFlow);
			promptedDistance = completion;
		}
		if (L4D_IsVersusMode() && completion > witchFlow) {
			isWitchSpawned = true;
		}
	}

	return Plugin_Continue;
}

public Action timerKickNonPluginTank(Handle timer, int tank) {
	if (!IsValidClient(tank) || IsClientInKickQueue(tank) || !IsFakeClient(tank)) {
		return Plugin_Stop;
	}

	log.debugAndInfo("%s: 产生了一个非插件刷新的 AI Tank, 索引 %d, 已踢出", PLUGIN_PREFIX, tank);
	KickClient(tank, "踢出非插件刷新的 Tank");

	return Plugin_Stop;
}

public Action timerSetGameDirector(Handle timer) {
	if (!L4D_IsVersusMode()) {
		static char mapName[64];
		GetCurrentMap(mapName, sizeof(mapName));

		if (!isStaticTankMap(mapName) && !isStaticWitchMap(mapName) || allowSpawnBossInFinale()) {
			setGameDirectorNoBossesCvar(true);
		} else {
			setGameDirectorNoBossesCvar(false);
		}
	}
	return Plugin_Stop;
}

static bool checkBossPosValid(float bossPos[3], float targetPos[3]) {
	static float vecDistance, navDistance;

	vecDistance = GetVectorDistance(bossPos, targetPos);
	if (vecDistance < g_hBossMinDistance.FloatValue) {
		return false;
	}
	navDistance = L4D2_NavAreaTravelDistance(bossPos, targetPos, false);
	if (navDistance < g_hBossMinNavDistance.FloatValue) {
		return false;
	}
	return true;
}

#define SPAWN_BOSS_DELAY 0.1

public Action timerSpawnBoss(Handle timer) {
	// 对抗模式, 不创建 Boss 刷新时钟
	if (L4D_IsVersusMode()) {
		log.debugAndInfo("%s: 当前为对抗模式, 不创建 Boss 刷新时钟", PLUGIN_PREFIX);
		bossSpawnTimer = null;
		return Plugin_Stop;
	}

	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	static int completion, targetSurvivor;
	completion = getSurvivorFlowZone();
	if (completion < 0 || completion > 100) {
		return Plugin_Continue;
	}

	float targetPos[3], bossPos[3];

	// 非对抗模式, 生还者超过了 Tank 路程, 还没有刷新过 Tank, 刷新一只 Tank
	if ((allowSpawnTankInNormal() || allowSpawnBossInFinale()) && tankFlow > 0 && completion >= tankFlow && !isTankSpawned && !isTankSpawnFailed) {
		targetSurvivor = L4D_GetHighestFlowSurvivor();
		GetClientAbsOrigin(targetSurvivor, targetPos);

		if (!IsValidSurvivor(targetSurvivor)) {
			log.error("%s: 未找到最高路程有效生还者, 不会刷新 Tank", PLUGIN_PREFIX);
		} else {
			L4D_GetRandomPZSpawnPosition(targetSurvivor, ZC_TANK, SPAWN_ATTEMPT, bossPos);
			if (!checkBossPosValid(bossPos, targetPos)) {
				ZeroVector(bossPos);

				if (delaySpawnTankTimer == null) {
					delaySpawnTankTime = GetEngineTime();
					delaySpawnTankTimer = CreateTimer(SPAWN_BOSS_DELAY, timerDelaySpawnTankHandler, targetSurvivor, TIMER_REPEAT);
				}
			} else {
				tankSpawnByPlugin = isTankSpawned = true;
				L4D2_SpawnTank(bossPos, view_as<float>({0.0, 0.0, 0.0}));
				tankSpawnByPlugin = false;

				log.debugAndInfo("%s: 非对抗模式, 当前生还者完成路程 %d, Tank 路程 %d, 在 [%.2f, %.2f, %.2f] 位置刷新一只 Tank", PLUGIN_PREFIX, completion, tankFlow, bossPos[0], bossPos[1], bossPos[2]);
			}
		}
	}

	if ((allowSpawnWitchInNormal() || allowSpawnBossInFinale()) && witchFlow > 0 && completion >= witchFlow && !isWitchSpawned && !isWitchSpawnFailed) {
		targetSurvivor = L4D_GetHighestFlowSurvivor();
		GetClientAbsOrigin(targetSurvivor, targetPos);
		
		if (!IsValidSurvivor(targetSurvivor)) {
			log.error("%s: 未找到最高路程有效生还者, 不会刷新 Witch", PLUGIN_PREFIX);
		} else {
			L4D_GetRandomPZSpawnPosition(targetSurvivor, ZC_WITCH, SPAWN_ATTEMPT, bossPos);
			if (!checkBossPosValid(bossPos, targetPos)) {
				ZeroVector(bossPos);

				if (delaySpawnWitchTimer == null) {
					delaySpawnWitchTime = GetEngineTime();
					delaySpawnWitchTimer = CreateTimer(SPAWN_BOSS_DELAY, timerDelaySpawnWitchHandler, targetSurvivor, TIMER_REPEAT);
				}
			} else {
				witchSpawnByPlugin = isWitchSpawned = true;
				L4D2_SpawnWitch(bossPos, view_as<float>({0.0, 0.0, 0.0}));
				witchSpawnByPlugin = false;

				log.debugAndInfo("%s: 非对抗模式, 当前生还者完成路程 %d, Witch 路程 %d, 在 [%.2f, %.2f, %.2f] 位置刷新一只 Witch", PLUGIN_PREFIX, completion, witchFlow, bossPos[0], bossPos[1], bossPos[2]);
			}
		}
	}

	return Plugin_Continue;
}

public Action timerDelaySpawnTankHandler(Handle timer, int client) {
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client) || isTankSpawned) {
		isTankSpawnFailed = true;
		delaySpawnTankTimer = null;
		return Plugin_Stop;
	}
	if (delaySpawnTankTime > 0.0 && FloatCompare(GetEngineTime() - delaySpawnTankTime, g_hBossFindPosMaxTime.FloatValue) > 0) {
		CPrintToChatAll("{B}<{O}Boss{B}> {W}尝试刷新一只 {G}Tank {W}时找位超过了限制时长{O}%.1f{W}秒, 将不会尝试刷新 {G}Tank", g_hBossFindPosMaxTime.FloatValue);
		log.debugAndInfo("%s: 尝试使用射线刷新一只 Tank 找位超过了限制时长 %.2f 秒, 因此不会刷新 Tank", PLUGIN_PREFIX, g_hBossFindPosMaxTime.FloatValue);
		isTankSpawnFailed = true;
		delaySpawnTankTimer = null;
		return Plugin_Stop;
	}

	static float bossPos[3];
	static int i;
	for (i = 0; i < GetServerTickRate(); i++) {
		getBossSpawnPosByTraceRay(client, bossPos);
		if (!IsZeroVector(bossPos)) {
			break;
		}
	}

	if (!IsZeroVector(bossPos)) {
		tankSpawnByPlugin = isTankSpawned = true;
		L4D2_SpawnTank(bossPos, view_as<float>({0.0, 0.0, 0.0}));
		tankSpawnByPlugin = false;

		log.debugAndInfo("%s: 非对抗模式, 使用 L4D_GetRandomPZSpawnPosition 函数未能找到刷新位置, 延迟使用射线刷新一只 Tank 在 [%.2f, %.2f, %.2f]", PLUGIN_PREFIX, bossPos[0], bossPos[1], bossPos[2]);

		delaySpawnTankTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action timerDelaySpawnWitchHandler(Handle timer, int client) {
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client) || isWitchSpawned) {
		isWitchSpawnFailed = true;
		delaySpawnWitchTimer = null;
		return Plugin_Stop;
	}
	if (delaySpawnWitchTime > 0.0 && FloatCompare(GetEngineTime() - delaySpawnWitchTime, g_hBossFindPosMaxTime.FloatValue) > 0) {
		CPrintToChatAll("{B}<{O}Boss{B}> {W}尝试刷新一只 {G}Witch {W}时找位超过了限制时长{O}%.1f{W}秒, 将不会尝试刷新 {G}Witch", g_hBossFindPosMaxTime.FloatValue);
		log.debugAndInfo("%s: 尝试使用射线刷新一只 Witch 找位超过了限制时长 %.2f 秒, 将不会刷新 Witch", PLUGIN_PREFIX, g_hBossFindPosMaxTime.FloatValue);
		isWitchSpawnFailed = true;
		delaySpawnWitchTimer = null;
		return Plugin_Stop;
	}

	static float bossPos[3];
	static int i;
	for (i = 0; i < GetServerTickRate(); i++) {
		getBossSpawnPosByTraceRay(client, bossPos);
		if (!IsZeroVector(bossPos)) {
			break;
		}
	}

	if (!IsZeroVector(bossPos)) {
		witchSpawnByPlugin = isWitchSpawned = true;
		L4D2_SpawnWitch(bossPos, view_as<float>({0.0, 0.0, 0.0}));
		witchSpawnByPlugin = false;

		log.debugAndInfo("%s: 非对抗模式, 使用 L4D_GetRandomPZSpawnPosition 函数未能找到刷新位置, 延迟使用射线刷新一只 Tank 在 [%.2f, %.2f, %.2f]", PLUGIN_PREFIX, bossPos[0], bossPos[1], bossPos[2]);

		delaySpawnWitchTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

#define GRID_RAIDUS 1500.0
#define GRID_HEIGHT 800.0
#define NAV_HEIGHT 20.0
#define MAX_NAV_PATH_LENGTH 1500.0
#define PLAYER_HEIGHT 72.0

void getBossSpawnPosByTraceRay(int target, float bossPos[3]) {
	ZeroVector(bossPos);
	if (!IsValidClient(target) || GetClientTeam(target) != TEAM_SURVIVOR || !IsPlayerAlive(target)) {
		return;
	}

	static float pos[3];
	GetClientAbsOrigin(target, pos);
	static float left[2][3], right[2][3];
	static int i;
	
	for (i = 0; i < 2; i++) {
		CopyVectors(pos, left[i]);
		CopyVectors(pos, right[i]);
	}

	left[0][0] -= GRID_RAIDUS;	left[0][1] -= GRID_RAIDUS;
	left[1][0] -= GRID_RAIDUS;	left[1][1] += GRID_RAIDUS;

	right[0][0] += GRID_RAIDUS;	right[0][1] -= GRID_RAIDUS;
	right[1][0]	+= GRID_RAIDUS;	right[1][1] += GRID_RAIDUS;

	static float rayPos[3], rayEndPos[3], rayVisiblePos[3], navDistance;
	rayPos[0] = GetRandomFloatInRange(left[0][0], right[0][0]);
	rayPos[1] = GetRandomFloatInRange(left[0][1], left[1][1]);
	rayPos[2] = GetRandomFloat(pos[2], pos[2] + GRID_HEIGHT);

	TR_TraceRay(rayPos, view_as<float>({90.0, 0.0, 0.0}), MASK_PLAYERSOLID, RayType_Infinite);
	if (!TR_DidHit()) {
		return;
	}
	TR_GetEndPosition(rayEndPos);
	CopyVectors(rayEndPos, rayVisiblePos);

	rayEndPos[2] += NAV_HEIGHT;
	rayVisiblePos[2] += PLAYER_HEIGHT;

	Address bossNav = L4D2Direct_GetTerrorNavArea(rayEndPos),
		 targetNav = L4D2Direct_GetTerrorNavArea(pos);

	if (bossNav == Address_Null || targetNav == Address_Null) {
		return;
	}
	if (GetVectorDistance(rayEndPos, pos) <= g_hBossMinDistance.FloatValue) {
		return;
	}
	if (posIsVisibleToAnySurvivor(rayVisiblePos, bossNav)) {
		return;
	}
	if (isClientStuck(rayEndPos)) {
		return;
	}
	if (!L4D2_NavAreaBuildPath(bossNav, targetNav, MAX_NAV_PATH_LENGTH, TEAM_INFECTED, false)) {
		return;
	}
	navDistance = L4D2_NavAreaTravelDistance(rayEndPos, pos, false);
	if (navDistance == -1 || navDistance <= g_hBossMinNavDistance.FloatValue) {
		return;
	}
	if (L4D_GetNavArea_SpawnAttributes(bossNav) & NAV_SPAWN_CHECKPOINT) {
		return;
	}
	rayEndPos[2] -= 15.0;
	CopyVectors(rayEndPos, bossPos);
}

stock bool navIsAhead(Address source, Address dest) {
	if (source == Address_Null || dest == Address_Null) {
		return false;
	}
	return FloatCompare(L4D2Direct_GetTerrorNavAreaFlow(source), L4D2Direct_GetTerrorNavAreaFlow(dest)) > 0;
}

static bool posIsVisibleToAnySurvivor(float pos[3], Address navArea = Address_Null) {
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		if (L4D2_IsVisibleToPlayer(i, TEAM_SURVIVOR, TEAM_INFECTED, view_as<int>(navArea), pos)) {
			return true;
		}
	}
	return false;
}

static bool isClientStuck(const float pos[3]) {
	static Handle traceRay;
	traceRay = TR_TraceHullFilterEx(pos, pos, view_as<float>({-16.0, 16.0, 0.0}), view_as<float>({16.0, 16.0, PLAYER_HEIGHT}), MASK_PLAYERSOLID, traceRayFilterNoPlayer, _);
	if (traceRay == null) {
		return false;
	}
	bool hit = TR_DidHit(traceRay);
	delete traceRay;
	return hit;
}

static bool traceRayFilterNoPlayer(int entity, int mask, any data) {
    return entity != data && entity > MaxClients;
}