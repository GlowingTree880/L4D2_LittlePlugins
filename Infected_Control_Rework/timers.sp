/**
* @Author 夜羽真白
* @Date 2023-07-28 13:25:47
* @Description 时钟回调部分
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

// HACK: 基准时钟回调, 固定时钟回调, 动态时钟回调完善, Bug 发现处理
/**
* 基准刷特时钟回调
* @param timer 时钟句柄
* @return Action
**/
public Action timerStandardInfectedSpawnHandler(Handle timer) {
	if (!isLeftSafeArea) {
		standardInfectedSpawnTimer.timer = null;
		return Plugin_Stop;
	}

	log.debugAndInfo("\n%s: 基准时钟触发, 当前记录波次 %d, 距离上一波刷特完成经过 %.3f s\n", PLUGIN_PREFIX, standardInfectedSpawnTimer.recordSpawnWaveCount, GetEngineTime() - spawnInterval);

	// 如果在一次找位刷新失败后的延迟时间, 触发了任何刷新时钟, 或 正在刷特中 都不允许刷新下一波
	if (isInFindPosFailedDelay || canSpawnNewInfected) {
		log.debugAndInfo("%s: 当前正在一次找位失败后延迟时间或正在刷新特感, 不处理基准时钟逻辑", PLUGIN_PREFIX);

		standardInfectedSpawnTimer.timer = null;
		return Plugin_Stop;
	}
	if (regularInfectedSpawnTimer.timer != null) {
		log.debugAndInfo("%s: 当前固定时钟不为 null, 固定时钟下次触发慢于基准时钟, 删除固定时钟", PLUGIN_PREFIX);
		delete regularInfectedSpawnTimer.timer;
	}
	if (autoInfectedSpawnTimer.timer != null) {
		log.debugAndInfo("%s: 当前动态时钟不为 null, 动态时钟下次触发慢于基准时钟, 删除动态时钟", PLUGIN_PREFIX);
		delete autoInfectedSpawnTimer.timer;
	}

	// 如果基准时钟还没有被触发, 则设置触发状态为 true 已触发
	if (!standardInfectedSpawnTimer.isTriggered)
		standardInfectedSpawnTimer.isTriggered = true;
	// 基准时钟触发次数自增
	standardInfectedSpawnTimer.lastTriggerTime = GetGameTime();
	standardInfectedSpawnTimer.recordSpawnWaveCount++;
	standardInfectedSpawnTimer.triggerCount++;
	// 可以使用基准时钟刷新新一波特感
	canSpawnNewInfected = true;
	isInSpawnFinishedTime = false;

	log.debugAndInfo("%s: 基准时钟允许刷新新一波特感, 当前基准时钟记录波次 %d", PLUGIN_PREFIX, standardInfectedSpawnTimer.recordSpawnWaveCount);
	// 基准时钟本次触发结束, 置 null 返回
	standardInfectedSpawnTimer.timer = null;
	return Plugin_Stop;
}

/**
* 固定刷特时钟回调
* @param timer 时钟句柄
* @return Action
**/
public Action timerRegularInfectedSpawnHandler(Handle timer) {
	if (!isLeftSafeArea) {
		regularInfectedSpawnTimer.timer = null;
		return Plugin_Stop;
	}
	log.debugAndInfo("\n%s: 固定时钟触发, 当前记录波次 %d, 距离上一波刷特完成经过 %.3f s, 距离上次创建固定时钟经过 %.3f s\n", PLUGIN_PREFIX, regularInfectedSpawnTimer.recordSpawnWaveCount, GetEngineTime() - spawnInterval, GetEngineTime() - regularTimerCreatedTime);

	if (isInFindPosFailedDelay || canSpawnNewInfected) {
		log.debugAndInfo("%s: 当前正在一次找位失败后延迟时间或正在刷新特感, 不处理固定时钟逻辑", PLUGIN_PREFIX);

		regularInfectedSpawnTimer.timer = null;
		return Plugin_Stop;
	}
	// 基准时钟只可能与固定时钟或动态时钟的一种并存, 因此固定时钟中不需要判断动态时钟, 只需要判断基准时钟即可
	if (standardInfectedSpawnTimer.timer != null) {
		log.debugAndInfo("%s: 当前基准时钟不为 null, 基准时钟下次触发慢于固定时钟, 删除基准时钟", PLUGIN_PREFIX);
		delete standardInfectedSpawnTimer.timer;
	}

	if (!regularInfectedSpawnTimer.isTriggered)
		regularInfectedSpawnTimer.isTriggered = true;

	regularInfectedSpawnTimer.lastTriggerTime = GetGameTime();
	regularInfectedSpawnTimer.recordSpawnWaveCount++;
	regularInfectedSpawnTimer.triggerCount++;

	canSpawnNewInfected = true;
	isInSpawnFinishedTime = false;

	log.debugAndInfo("%s: 固定时钟允许刷新新一波特感, 当前固定时钟记录波次 %d", PLUGIN_PREFIX, regularInfectedSpawnTimer.recordSpawnWaveCount);

	regularInfectedSpawnTimer.timer = null;
	return Plugin_Stop;
}

/**
* 动态刷特时钟回调
* @param timer 时钟句柄
* @return Action
**/
public Action timerAutoInfectedSpawnHandler(Handle timer) {
	if (!isLeftSafeArea) {
		autoInfectedSpawnTimer.timer = null;
		return Plugin_Stop;
	}
	log.debugAndInfo("\n%s: 动态时钟触发, 当前记录波次 %d, 距离上一波刷特完成经过 %.3f s, 距离上次创建动态时钟经过 %.3f s\n", PLUGIN_PREFIX, autoInfectedSpawnTimer.recordSpawnWaveCount, GetEngineTime() - spawnInterval, GetEngineTime() - autoTimerCreatedTime);

	if (isInFindPosFailedDelay || canSpawnNewInfected) {
		log.debugAndInfo("%s: 当前正在一次找位失败后延迟时间或正在刷新特感, 不处理动态时钟逻辑", PLUGIN_PREFIX);

		autoInfectedSpawnTimer.timer = null;
		return Plugin_Stop;
	}
	if (standardInfectedSpawnTimer.timer != null) {
		log.debugAndInfo("%s: 当前基准时钟不为 null, 基准时钟下次触发慢于动态时钟, 删除基准时钟", PLUGIN_PREFIX);
		delete standardInfectedSpawnTimer.timer;
	}

	// 如果动态时钟没有触发过, 则设置触发位为 true
	if (!autoInfectedSpawnTimer.isTriggered)
		autoInfectedSpawnTimer.isTriggered = true;

	autoInfectedSpawnTimer.lastTriggerTime = GetGameTime();
	autoInfectedSpawnTimer.recordSpawnWaveCount++;
	autoInfectedSpawnTimer.triggerCount++;

	canSpawnNewInfected = true;
	isInSpawnFinishedTime = false;

	log.debugAndInfo("%s: 动态时钟允许刷新新一波特感, 当前动态时钟记录波次 %d", PLUGIN_PREFIX, autoInfectedSpawnTimer.recordSpawnWaveCount);
	
	autoInfectedSpawnTimer.timer = null;
	return Plugin_Stop;
}

/**
* 第一波特感刷新队列生成完成时钟回调
* @param timer 当前时钟句柄
* @return Action
**/
public Action timerGetFirstWaveInfectedQueue(Handle timer) {
	delete infectedQueue;
	infectedQueue = getInfectedQueue();
	
	// 获取队列时出错, 返回 null 或 设定特感数量不为 0 队列长度却小于 1
	if (infectedQueue == null || (g_hInfectedLimit.IntValue > 0 && infectedQueue.Length < 1)) {
		log.error("%s: 获取第一波特感刷新队列时发生错误, 当前队列是否为 null, 当前队列长度: %d", PLUGIN_PREFIX, infectedQueue == null, infectedQueue == null ? 0 : infectedQueue.Length);
		return Plugin_Stop;
	}

	// FIXED: 没办法传 ArrayList 引用 (2023-08-30)
	Call_StartForward(onFirstWaveInfectedQueueGenerated);
	Call_PushCell(infectedQueue);
	Call_Finish();

	return Plugin_Continue;
}

/**
* 设置 z_max_player_zombie 时钟回调
* @param timer 当前时钟句柄
* @return Action
**/
public Action timerSetMaxSpecialHandler(Handle timer) {
	if (game_zMaxPlayerZombie) {
		game_zMaxPlayerZombie.SetInt(g_hInfectedLimit.IntValue);
		
		log.debugAndInfo("%s: 将 z_max_player_zombie 数量设置为 %d", PLUGIN_PREFIX, g_hInfectedLimit.IntValue);
	}

	return Plugin_Continue;
}

/**
* 设置 z_spawn_safety_range 时钟回调
* @param timer 当前时钟句柄
* @return Action
**/
public Action timerSetSpawnDistanceHandler(Handle timer) {
	// 设置 z_spawn_safety_range
	if (game_zSpawnSafetyRange) {
		SetConVarBounds(game_zSpawnSafetyRange, ConVarBound_Upper, false);
		SetConVarFlags(game_zSpawnSafetyRange, game_zSpawnSafetyRange.Flags & ~FCVAR_NOTIFY);
		SetConVarInt(game_zSpawnSafetyRange, g_hMinDistance.IntValue > g_hMinNavDistance.IntValue ? g_hMinNavDistance.IntValue : g_hMinDistance.IntValue);
	}
	// 设置 z_safe_spawn_range
	if (game_zSafeSpawnRange) {
		SetConVarBounds(game_zSafeSpawnRange, ConVarBound_Upper, false);
		SetConVarFlags(game_zSafeSpawnRange, game_zSafeSpawnRange.Flags & ~FCVAR_NOTIFY);
		SetConVarInt(game_zSafeSpawnRange, g_hMinDistance.IntValue > g_hMinNavDistance.IntValue ? g_hMinNavDistance.IntValue : g_hMinDistance.IntValue);
	}
	log.debugAndInfo("%s: 将 z_spawn_safety_range 与 z_safe_spawn_range 值设置为 %d",
		PLUGIN_PREFIX, game_zSpawnSafetyRange.IntValue);

	return Plugin_Continue;
}

/**
* 一次找位刷新失败且等待完暂停时间后重启这一波刷特时钟回调
* @param timer 当前时钟句柄
* @return Action
**/
public Action timerFindPosFailedHandler(Handle timer) {
	if (isInFindPosFailedDelay) {
		isInFindPosFailedDelay = false;
		canSpawnNewInfected = true;
	}
	return Plugin_Continue;
}

/**
* 第一波特感需要延迟刷新时钟回调
* @param timer 当前时钟句柄
* @return Action
**/
public Action timerFirstWaveDelaySpawnHandler(Handle timer) {
	canSpawnNewInfected = true;
	isInFindPosFailedDelay = false;
	return Plugin_Continue;
}

public Action timerKickDeadInfectedHandler(Handle timer, int client) {
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_INFECTED || !IsFakeClient(client) || IsClientInKickQueue(client)) {
		return Plugin_Stop;
	}
	KickClient(client, "%s: 踢出死亡 Bot 特感", PLUGIN_PREFIX);
	return Plugin_Continue;
}

/**
* 分散刷新模式下某特感重生完成时钟回调
* @param timer 当前时钟句柄
* @param entRef 当前重生完成的特感的实体索引
* @return Action
**/
public Action timerRespawnFinishHandler(Handle timer, int entRef) {
	if (entRef == INVALID_ENT_REFERENCE) {
		return Plugin_Stop;
	}
	if (!isLeftSafeArea) {
		infStateList.Clear();
		return Plugin_Stop;
	}

	static int index;
	index = infStateList.FindValue(entRef, 0);
	if (index < 0)
		return Plugin_Stop;

	// 复活完成的特感准备刷新前, 删除原有特感队列, 防止一个复活完成的特感占用原有特感队列刷新, 导致第一波少特感情况
	delete infectedQueue;

	// 获取特感状态类
	InfectedState state;
	infStateList.GetArray(index, state, sizeof(state));

	// 设置复活已完成
	state.isRespawnFinished = true;
	infStateList.SetArray(index, state, sizeof(state));
	// 增加复活完成特感数量	
	respawnFinishedCount += 1;

	log.debugAndInfo("\n%s: 索引 %d, 名称 %s, 类型 %s, 重生完毕 %b, 死亡时间 %.2f, 距离上次死亡经过 %.3f s, 当前是否允许刷新特感 %b\n", PLUGIN_PREFIX, index, state.name, INFECTED_NAME[state.class], state.isRespawnFinished, state.deathTime, GetGameTime() - state.deathTime, canSpawnNewInfected);

	// 循环将 canSpawnNewInfected 设置为 true, 以免刷完一只即将设置为 false 前刚好复活, 无视时钟设置为 true, 最坏等待时间 1.0s
	CreateTimer(1.0, timerSetAllowSpawnFlagHandler, entRef, TIMER_REPEAT);

	state.timer = null;
	infStateList.SetArray(index, state, sizeof(state));

	// 对状态集合进行排序, 将已经复活完成的特感排在队首
	infStateList.SortCustom(sortInfStateList);

	return Plugin_Stop;
}

int sortInfStateList(int x, int y, Handle array, Handle hndl) {
	static ArrayList list;
	list = view_as<ArrayList>(array);
	InfectedState x1, y1;
	list.GetArray(x, x1, sizeof(x1));
	list.GetArray(y, y1, sizeof(y1));

	// 按照是否复活完成与死亡时间排序
	return x1.isRespawnFinished > y1.isRespawnFinished ? -1 : x1.isRespawnFinished == y1.isRespawnFinished ? FloatCompare(x1.deathTime, y1.deathTime) > 0 ? -1 : 1 : 1;
}

Action timerSetAllowSpawnFlagHandler(Handle timer, int entRef) {
	// 未离开安全屋 或 允许正常刷新特感情况下, 返回
	if (!isLeftSafeArea || (canSpawnNewInfected && !isInFindPosFailedDelay && !isInSpawnFinishedTime))
		return Plugin_Continue;
	if (isInFindPosFailedDelay)
		return Plugin_Continue;

	// 无效的实体索引, 时钟停止
	if (entRef == INVALID_ENT_REFERENCE)
		return Plugin_Stop;
	// 在特感状态集合中找不到, 说明已经被刷新, 停止
	static int index;
	index = infStateList.FindValue(entRef, 0);
	if (index < 0)
		return Plugin_Stop;
	// 如果当前在场特感与状态集合中待刷新特感数量超过限制, 则自身销毁
	if (infectedCount + infStateList.Length > g_hInfectedLimit.IntValue) {
		static InfectedState state;
		if (infStateList.Length > 1) {
			infStateList.GetArray(0, state, sizeof(state));
			state.init();
		}
		return Plugin_Stop;
	}

	canSpawnNewInfected = true;
	isInSpawnFinishedTime = false;
	// 开始刷新前, 重置找位消耗时间
	findPosSpawnTimeCost = 0.0;
	
	return Plugin_Continue;
}
