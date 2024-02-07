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

	// 特感玩家离开游戏, 检查是否已经存在于 Map 中, 存在则移除
	int ref = EntIndexToEntRef(client);
	if (infEntRefMapOperation.containsKey(ref))
		infEntRefMapOperation.remove(ref);
}

/**
* 玩家倒地开始事件
* @param 
* @return void
**/
public void eventPlayerIncapStartHandler(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	// 生还者没有离开安全屋, 不增时
	if (!isLeftSafeArea)
		return;
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
	static int client, class;
	client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client) || GetClientTeam(client) != TEAM_INFECTED || !IsFakeClient(client)) {
		return;
	}
	class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (class < ZC_SMOKER || class > ZC_CHARGER)
		return;

	// 获取特感实体引用
	static int ref, classListIndex;
	ref = EntIndexToEntRef(client);

	// 6 特以下, 且需要进行特感轮换 或 分散刷新模式下需要检查死亡特感是否合法, 不合法 (非插件刷的特感) 则不处理
	if (isNeedToAlternate() || g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
		
		// 存在则更改为击杀顺序与特感类型, 否则抛出异常
		if (infEntRefMapOperation.containsKey(ref)) {
			// 在实体 Map 中存在, 删除
			log.debugAndInfo("%s: 当前特感数量 %d, 是否为分散刷新 %b, 特感 %N 死亡, 实体索引 %d, 合法特感, 从实体引用 Map 中移除",
				PLUGIN_PREFIX, infectedCount, g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE, client, ref);
			
			infEntRefMapOperation.remove(ref);
		} else {
			log.error("%s: 当前特感数量 %d, 是否为分散刷新 %b, 特感 %N 死亡, 于特感实体引用 Map 中不存在, 非法特感",
				PLUGIN_PREFIX, infectedCount, g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE, client);
			return;
		}

	}

	// 开启特感轮换, 且死亡的特感合法
	if (isNeedToAlternate()) {
		// 在轮换类型集合中找到一个对应的特感类型, 放到队尾
		classListIndex = infClassList.FindValue(class);
		if (classListIndex >= 0) {
			infClassList.Erase(classListIndex);
			infClassList.Push(class);
			log.debugAndInfo("%s: 已开启特感轮换, 将特感 %N 放置到轮换类型集合队尾", PLUGIN_PREFIX, client);
		}

		// 打印特感状态与特感轮换类型集合
		printInfectedStateList();
		printInfectedClassList();
	}

	if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE && infStateList.Length < g_hInfectedLimit.IntValue) {
		// 重生完成特感数量减少 1
		respawnFinishedCount = respawnFinishedCount > 0 ? respawnFinishedCount - 1 : 0;

		// 分散刷新方式下, 记录特感死亡状态
		InfectedState state;
		getInfectedState(client, state);

		// 设置重生时钟, 传递在状态集合中的索引
		switch (g_hSpawnStrategy.IntValue) {
			case SPS_REGULAR:
				state.timer = CreateTimer(regularTimerInterval, timerRespawnFinishHandler, ref, _);
			case SPS_AUTO:
				state.timer = CreateTimer(autoTimerInterval, timerRespawnFinishHandler, ref, _);
		}

		infStateList.PushArray(state);
		log.debugAndInfo("%s: 当前为分散刷新模式, 特感 %N 死亡, 状态类获取成功, 加入到状态集合中", PLUGIN_PREFIX, client);
	}

	// 不踢出 Spitter
	if (class == ZC_SPITTER)
		return;

	// 踢出死亡特感, 非 Spitter
	if (FloatCompare(g_hDeadKickTime.FloatValue, 0.0) > 0)
		CreateTimer(g_hDeadKickTime.FloatValue, timerKickDeadInfectedHandler, client, _);
}

void printInfectedStateList() {
	int i;
	InfectedState state;
	log.debugAndInfo("\n ===== %s: 当前特感状态集合 ====\n", PLUGIN_PREFIX);
	for (i = 0; i < infStateList.Length; i++) {
		infStateList.GetArray(i, state);
		log.debugAndInfo("\t\t索引 %d, 实体索引 %d, 名称 %s, 类型 %s, 死亡时间 %.2f, 是否重生完成 %b, 时钟 0x%x",
			i,
			state.entRef,
			state.name,
			INFECTED_NAME[state.class],
			state.deathTime,
			state.isRespawnFinished,
			state.timer);
	}
}

void printInfectedClassList() {
	int i;
	log.debugAndInfo("\n ===== %s: 当前特感轮换集合 =====\n", PLUGIN_PREFIX);
	for (i = 0; i < infClassList.Length; i++) {
		log.debugAndInfo("\t\t索引 %d, 类型 %s",
			i,
			INFECTED_NAME[infClassList.Get(i)]);
	}
}

/**
* 获取特感状态类
* @param client 需要获取特感状态类的客户端索引
* @param state 状态类
* @return void
**/
void getInfectedState(int client, InfectedState state) {
	if (!IsValidInfected(client))
		return;

	state.init();
	// 设置特感类型, 设置时钟在加入到状态集合之后
	state.class = GetEntProp(client, Prop_Send, "m_zombieClass");
	state.entRef = EntIndexToEntRef(client);
	// 设置名称
	static char name[64];
	GetClientName(client, name, sizeof(name));
	strcopy(state.name, 64, name);
	// 设置死亡时间
	state.deathTime = GetGameTime();
	// 设置是否重生完毕
	state.isRespawnFinished = false;
}