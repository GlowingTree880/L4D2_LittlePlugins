/**
* @Author 夜羽真白
* @Date 2023-07-29 15:30:09
* @Description 事件处理
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

bool playerIncapRecord[MAXPLAYERS + 1];

/**
* 回合开始事件处理
* @param 
* @return void
**/
public void eventRoundStartHandler(Event event, const char[] name, bool dontBroadcast) {
	resetTimersAndStates();
	// 重新获取时钟周期
	getInfectedSpawnTimerInterval();
	getDisperseTargetInfectedCount();
	// 获取第一波特感刷新队列
	CreateTimer(ROUND_START_DELAY, timerGetFirstWaveInfectedQueue, _, _);
}

/**
* 回合结束事件
* @param 
* @return void
**/
public void eventRoundEndHandler(Event event, const char[] name, bool dontBroadcast) {
	resetTimersAndStates();
}

/**
* 玩家救起成功事件
* @param 
* @return void
**/
public void eventReviveSucessHandler(Event event, const char[] name, bool dontBroadcast) {
	// person who was revived
	int client = GetClientOfUserId(event.GetInt("subject"));
	playerIncapRecord[client] = false;
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR) {
		return;
	}
}

/**
* 玩家断开连接事件, 仅检测特感 (由插件踢出或管理员踢出)
* @param 
* @return void
**/
public void eventPlayerDisconnectHandler(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED)
		return;
	
	int class = GetInfectedClass(client);
	if (class < ZC_SMOKER || class > ZC_CHARGER)
		return;
	
	char reason[64];
	event.GetString("reason", reason, sizeof(reason));

	// 特感玩家离开游戏, 检查是否已经存在于 Map 中, 存在则替换为击杀顺序
	int ref = EntIndexToEntRef(client);
	if (infEntRefMapOperation.containsKey(client)) {
		waveKillIndex++;
		infEntRefMapOperation.replaceByIndex(ref, waveKillIndex, class);
		log.debugAndInfo("%s: 特感 %N(类型 %s/ 实体索引 %d) 断开连接, 原因 %s, 已在实体 Map 中找到, 更改为击杀顺序 %d", PLUGIN_PREFIX, client, INFECTED_NAME[class], ref, reason, waveKillIndex);
	}
}

/**
* 玩家倒地开始事件
* @param 
* @return void
**/
public void eventPlayerIncapStartHandler(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	// 正在刷新一波特感, 或 分散刷新时 不增时
	if (canSpawnNewInfected || g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
		return;
	}
	// 倒地的不是有效生还者且击倒生还的不是感染者, 不增时
	if (!IsValidClient(client) || !IsValidClient(attacker) || GetClientTeam(client) != TEAM_SURVIVOR || GetClientTeam(attacker) != TEAM_INFECTED || !IsPlayerAlive(client)) {
		return;
	}

	log.debugAndInfo("%s: 生还者 %N 倒地, 攻击者 %N", PLUGIN_PREFIX, client, attacker);

	// 检查当前有多少个倒地生还者
	static int i;
	int count = 0, recordCount = 0;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) {
			continue;
		}
		if (IsClientIncapped(i)) {
			count++;
		}
	}
	// 统计已经记录过的倒地玩家
	for (i = 1; i <= MaxClients; i++) {
		if (playerIncapRecord[i]) {
			recordCount++;
		}
	}

	playerIncapRecord[client] = true;

	static float extraTime, newInterval, offset;
	extraTime = (count - recordCount) * g_hIncapExtraTime.FloatValue;

	// 存在基准时钟, 基准时钟开始增时
	if (standardInfectedSpawnTimer.timer != null) {
		delete standardInfectedSpawnTimer.timer;
		newInterval = extraTime + (standardInfectedSpawnTimer.nextTriggerTime - GetGameTime());
		standardInfectedSpawnTimer.timer = CreateTimer(newInterval, timerStandardInfectedSpawnHandler, _, _);
		standardInfectedSpawnTimer.nextTriggerTime = GetGameTime() + newInterval;
		log.debugAndInfo("%s: 当前基准时钟不为 null, 基准时钟开始增时, 下次触发在 %.2f", PLUGIN_PREFIX, newInterval);
	}
	// 存在固定时钟, 固定时钟开始增时
	if (regularInfectedSpawnTimer.timer != null) {
		delete regularInfectedSpawnTimer.timer;
		newInterval = extraTime + (regularInfectedSpawnTimer.nextTriggerTime - GetGameTime());
		regularInfectedSpawnTimer.timer = CreateTimer(newInterval, timerRegularInfectedSpawnHandler, _, _);
		regularInfectedSpawnTimer.nextTriggerTime = GetGameTime() + newInterval;
		log.debugAndInfo("%s: 当前固定时钟不为 null, 固定时钟开始增时, 下次触发在 %.2f", PLUGIN_PREFIX, newInterval);
		if (FloatCompare(standardInfectedSpawnTimer.nextTriggerTime, regularInfectedSpawnTimer.nextTriggerTime) > 0) {
			// 基准时钟下次触发时间晚于固定时钟
			offset = regularInfectedSpawnTimer.nextTriggerTime - GetGameTime();
		} else {
			offset = standardInfectedSpawnTimer.nextTriggerTime - GetGameTime();
		}
	}
	// 存在动态时钟, 动态时钟开始增时
	if (autoInfectedSpawnTimer.timer != null) {
		delete autoInfectedSpawnTimer.timer;
		newInterval = extraTime + (autoInfectedSpawnTimer.nextTriggerTime - GetGameTime());
		autoInfectedSpawnTimer.timer = CreateTimer(newInterval, timerAutoInfectedSpawnHandler, _, _);
		autoInfectedSpawnTimer.nextTriggerTime = GetGameTime() + newInterval;
		log.debugAndInfo("%s: 当前动态时钟不为 null, 动态时钟开始增时, 下次触发在 %.2f", PLUGIN_PREFIX, newInterval);
		if (FloatCompare(standardInfectedSpawnTimer.nextTriggerTime, autoInfectedSpawnTimer.nextTriggerTime) > 0) {
			// 基准时钟下次触发时间晚于动态时钟
			offset = autoInfectedSpawnTimer.nextTriggerTime - GetGameTime();
		} else {
			offset = standardInfectedSpawnTimer.nextTriggerTime - GetGameTime();
		}
	}
	// 只存在基准时钟
	if (FloatCompare(offset, 0.0) == 0) {
		offset = standardInfectedSpawnTimer.nextTriggerTime - GetGameTime();
	}
	log.debugAndInfo("%s: 当前有 %d 个倒地生还者, 当前已经刷新完成 %d 波特感, 下一波特感刷新将延迟 %.2f 秒, 在 %.2f 秒后", PLUGIN_PREFIX, count, currentSpawnWaveCount, extraTime, offset);
	CPrintToChatAll("{B}[{W}自动增时{B}]: 当前存在{O}%d{W}个{G}倒地生还者, {W}下一波特感刷新将被延迟{O}%d{W}秒, 在{O}%d{W}秒后", count, RoundToNearest(extraTime), RoundToNearest(offset));
}

/**
* 玩家死亡事件
* @param 
* @return void
**/
public void eventPlayerDeathHandler(Event event, const char[] name, bool dontBroadcast) {
	static int i, client, class;
	client = GetClientOfUserId(event.GetInt("userid"));
	playerIncapRecord[client] = false;
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_INFECTED || !IsFakeClient(client)) {
		return;
	}
	class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (class == ZC_TANK) {
		return;
	}

	// 需要进行特感轮换, 将记录的特感实体索引更改为击杀顺序
	if (g_hInfectedLimit.IntValue < 6 && g_hUnreachSixAlternate.BoolValue && !g_hSingleInfectedMode.BoolValue) {
		static int ref;
		ref = EntIndexToEntRef(client);
		// 击杀顺序自增
		waveKillIndex++;

		log.debugAndInfo("%s: 特感 %s(%d/ EntRef: %d) 死亡, 当前开启特感轮换, 在实体 Map 中是否存在 %b, 击杀顺序 %d", PLUGIN_PREFIX, INFECTED_NAME[class], client, ref, infEntRefMapOperation.containsKey(ref), waveKillIndex);
		// 存在则更改为击杀顺序与特感类型
		if (infEntRefMapOperation.containsKey(ref))
			infEntRefMapOperation.replaceByIndex(ref, waveKillIndex, class);
	}

	// 分散刷新方式
	if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
		// 重生完成特感数量减少 1
		respawnFinishedCount = respawnFinishedCount > 0 ? respawnFinishedCount - 1 : 0;

		static int count;
		count = getTeamClientCount(TEAM_INFECTED, true, false);
		for (i = 1; i <= MaxClients; i++) {
			if (!infectedStates[i].valid) {
				continue;
			}
			count++;
		}
		if (count >= g_hInfectedLimit.IntValue) {
			log.debugAndInfo("%s: 当前在场特感与重生中特感数量 %d, 大于等于设置数量 %d 只, 特感 %N 死亡, 不加入状态数组中", PLUGIN_PREFIX, count, g_hInfectedLimit.IntValue, client);
			return;
		}

		// 记录死亡特感状态
		InfectedState state;
		state.infectedType = class;
		// 复制名称
		char clientName[64];
		GetClientName(client, clientName, sizeof(clientName));
		strcopy(state.name, sizeof(state.name), clientName);

		state.deathTime = GetGameTime();
		state.nextRespawnTime = GetGameTime() + g_hSpawnDuration.FloatValue;
		state.isRespawnFinished = false;

		static int index;
		index = -1;
		// 该位置已经被别的特感注册有效, 寻找一个未被注册的位置
		if (infectedStates[client].valid) {
			for (i = 1; i <= MaxClients; i++) {
				if (infectedStates[i].valid) {
					continue;
				}
				index = i;
				break;
			}
		}

		if (index > -1) {
			state.valid = true;
			state.timer = CreateTimer(g_hSpawnDuration.FloatValue, timerRespawnFinishHandler, index, _);
			infectedStates[index] = state;
			log.debugAndInfo("%s: 当前特感 %s, 索引 %d, 在状态数组中的位置已经被占用, 新位置索引 %d", PLUGIN_PREFIX, client, client, index);
		} else {
			state.valid = true;
			state.timer = CreateTimer(g_hSpawnDuration.FloatValue, timerRespawnFinishHandler, client, _);
			infectedStates[client] = state;
		}

		log.debugAndInfo("\n%s: 当前为分散刷新方式, 特感 %N 死亡, 加入状态数组中, 索引 %d", PLUGIN_PREFIX, client, index > -1 ? index : client);
		log.debugAndInfo("%s: 当前状态数组", PLUGIN_PREFIX);
		for (i = 1; i <= MaxClients; i++) {
			if (!infectedStates[i].valid) {
				continue;
			}
			log.debugAndInfo("\t\t%索引 %d, %s 类型 %s, 有效 %b, 重生完成 %b", i, infectedStates[i].name, INFECTED_NAME[infectedStates[i].infectedType], infectedStates[i].valid, infectedStates[i].isRespawnFinished);
		}
	}

	if (class == ZC_SPITTER) {
		return;
	}

	// 踢出死亡特感, 非 Spitter
	if (FloatCompare(g_hDeadKickTime.FloatValue, 0.0) > 0) {
		CreateTimer(g_hDeadKickTime.FloatValue, timerKickDeadInfectedHandler, client, _);
    }
}