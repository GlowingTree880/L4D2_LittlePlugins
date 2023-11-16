/**
* @Author 夜羽真白
* @Date 2023-07-29 15:30:09
* @Description 事件处理
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

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
	if (canSpawnNewInfected || g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE)
		return;
	// 倒地的不是有效生还者, 不增时
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
		return;

	log.debugAndInfo("%s: 生还者 %N 倒地, 攻击者 %N, 增加一波中倒地生还者的数量, 当前时间 %.2f", PLUGIN_PREFIX, client, attacker, GetEngineTime());

	// 增加一波中倒地生还者数量
	waveIncapCount++;

	// 开始增时
	doDelayInfectedSpawnTimerNextTriggerTime();
}

/**
* 玩家倒地后延迟刷特时钟
* @param timer 刷特时钟父类
* @param type 时钟类型
* @param nextTriggerTime 新的时钟周期
* @return void
**/
static void delayAndSetSpawnTimer(BaseTimer baseTimer, int type, float nextTriggerTime) {
	if (baseTimer.timer == null)
		return;
	delete baseTimer.timer;

	switch (type) {
		case TIMER_STANDARD: {
			baseTimer.timer = CreateTimer(nextTriggerTime, timerStandardInfectedSpawnHandler, _, SPAN_INFECTED_TIMER_FLAG);

			log.debugAndInfo("%s: 当前存在基准时钟, 开始增时 %.2f 秒, 时钟周期 %.2f, 下次触发在 %.2f (%.2f 秒后)", PLUGIN_PREFIX, g_hIncapExtraTime.FloatValue, nextTriggerTime, GetGameTime() + nextTriggerTime, g_hIncapExtraTime.FloatValue);
		} case TIMER_REGULAR: {
			baseTimer.timer = CreateTimer(nextTriggerTime, timerRegularInfectedSpawnHandler, _, SPAN_INFECTED_TIMER_FLAG);

			log.debugAndInfo("%s: 当前存在固定时钟, 开始增时 %.2f 秒, 时钟周期 %.2f, 下次触发在 %.2f (%.2f 秒后)", PLUGIN_PREFIX, g_hIncapExtraTime.FloatValue, nextTriggerTime, GetGameTime() + nextTriggerTime, g_hIncapExtraTime.FloatValue);
		} case TIMER_AUTO: {
			baseTimer.timer = CreateTimer(nextTriggerTime, timerAutoInfectedSpawnHandler, _, SPAN_INFECTED_TIMER_FLAG);

			log.debugAndInfo("%s: 当前存在动态时钟, 开始增时 %.2f 秒, 时钟周期 %.2f, 下次触发在 %.2f (%.2f 秒后)", PLUGIN_PREFIX, g_hIncapExtraTime.FloatValue, nextTriggerTime, GetGameTime() + nextTriggerTime, g_hIncapExtraTime.FloatValue);
		}
	}
	// 设置下次触发时间, nextTriggerTime 是时钟周期, 需要加上当前时间
	baseTimer.nextTriggerTime = GetGameTime() + nextTriggerTime;
}

static void doDelayInfectedSpawnTimerNextTriggerTime() {
	static float nextTriggerTime;
	// 时钟周期等于原本记录的下次触发时间加上倒地延时减去当前时间
	if (standardInfectedSpawnTimer.timer != null) {
		nextTriggerTime = (standardInfectedSpawnTimer.nextTriggerTime + g_hIncapExtraTime.FloatValue) - GetGameTime();
		delayAndSetSpawnTimer(standardInfectedSpawnTimer, TIMER_STANDARD, nextTriggerTime);
	}
	if (regularInfectedSpawnTimer.timer != null) {
		nextTriggerTime = (regularInfectedSpawnTimer.nextTriggerTime + g_hIncapExtraTime.FloatValue) - GetGameTime();
		delayAndSetSpawnTimer(regularInfectedSpawnTimer, TIMER_REGULAR, nextTriggerTime);
	}
	if (autoInfectedSpawnTimer.timer != null) {
		nextTriggerTime = (autoInfectedSpawnTimer.nextTriggerTime + g_hIncapExtraTime.FloatValue) - GetGameTime();
		delayAndSetSpawnTimer(autoInfectedSpawnTimer, TIMER_AUTO, nextTriggerTime);
	}

	// 增时提示
	log.debugAndInfo("%s: 当前存在 %d 名倒地玩家, 已经刷新完成 %d 波特感, 下一波特感延迟 %.2f 秒刷新", PLUGIN_PREFIX, waveIncapCount, currentSpawnWaveCount, waveIncapCount * g_hIncapExtraTime.FloatValue);
	CPrintToChatAll("{B}[{W}自动增时{B}]: 本波次中存在{O}%d{W}个{G}倒地生还者, {W}下一波特感刷新将延迟{O}%d{W}秒刷新", waveIncapCount, RoundToNearest(waveIncapCount * g_hIncapExtraTime.FloatValue));
}

/**
* 玩家死亡事件
* @param 
* @return void
**/
public void eventPlayerDeathHandler(Event event, const char[] name, bool dontBroadcast) {
	static int i, client, class;
	client = GetClientOfUserId(event.GetInt("userid"));
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