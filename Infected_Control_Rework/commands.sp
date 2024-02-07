#pragma semicolon 1
#pragma newdecls required

/**
* sm_startspawn 指令回调
* @param client 执行指令的客户端索引
* @param args 指令参数
* @return Action
**/
public Action cmdStartSpawn(int client, int args) {
	if (client < 0 || client > MaxClients) {
		return Plugin_Handled;
	}

	// 手动刷新控制模式, 允许刷新特感
	if (g_hStartSpawnControl.IntValue == SSC_MANUAL) {
		if (currentSpawnWaveCount > 1) {
			CReplyToCommand(client, "{O}%s: {W}当前非第一波特感刷新, 不可使用本指令", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
		// 第一波刷新
		if (g_hFirstWaveDelay.BoolValue) {
			CreateTimer(g_hFirstWaveDelay.FloatValue, timerFirstWaveDelaySpawnHandler, _, _);
		} else {
			canSpawnNewInfected = true;
		}
	} else {
		CReplyToCommand(client, "{O}%s: {W}当前已经为自动刷新控制模式, 不可使用指令刷新", PLUGIN_PREFIX);
	}

	return Plugin_Handled;
}

/**
* sm_limit 指令回调
* @param client 执行指令的客户端索引
* @param args 指令参数
* @return Action
**/
public Action cmdInfectedLimit(int client, int args) {
	if (args != 1) {
		CReplyToCommand(client, "{O}%s: {W}请使用 {O}!limit <num> {W}来修改{G}特感数量", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	char argStr[16];
	GetCmdArgString(argStr, sizeof(argStr));
	
	int newLimit = StringToInt(argStr);
	if (newLimit < 0 || newLimit > MaxClients) {
		CReplyToCommand(client, "{O}%s: {W}新的数量 {O}%d {G}无效, {W}请确认输入有效性", PLUGIN_PREFIX, newLimit);
		return Plugin_Handled;
	}
	g_hInfectedLimit.SetInt(newLimit);
	CReplyToCommand(client, "{O}%s: {W}已调整特感刷新为 {O}%d特%d秒", PLUGIN_PREFIX, g_hInfectedLimit.IntValue, g_hSpawnDuration.IntValue);
	return Plugin_Handled;
}

/**
* sm_duration 指令回调
* @param client 执行指令的客户端索引
* @param args 指令参数
* @return Action
**/
public Action cmdSpawnDuration(int client, int args) {
	if (args != 1) {
		CReplyToCommand(client, "{O}%s: {W}请使用 {O}!duration <sec> {W}来修改{G}特感刷新时间", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	char argStr[16];
	GetCmdArgString(argStr, sizeof(argStr));

	int newTime = StringToInt(argStr);
	if (newTime < 0) {
		CReplyToCommand(client, "{O}%s: {W}新的特感刷新时间 {O}%d {W}秒无效, 请确认输入有效性", PLUGIN_PREFIX, newTime);
		return Plugin_Handled;
	}
	g_hSpawnDuration.SetInt(newTime);
	CReplyToCommand(client, "{O}%s: {W}已调整特感刷新为 {O}%d特%d秒", PLUGIN_PREFIX, g_hInfectedLimit.IntValue, g_hSpawnDuration.IntValue);
	return Plugin_Handled;
}

/**
* sm_type 单一特感模式指令回调
* @param client 执行指令的客户端索引
* @param args 指令参数
* @return Action
**/
public Action cmdSingleInfectedMode(int client, int args) {
	if (args != 1) {
		CReplyToCommand(client, "{O}%s: {W}请使用 {O}!type <num> {W}来指定使用哪种特感的单一特感模式, 0 为关闭", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	char argStr[16];
	GetCmdArgString(argStr, sizeof(argStr));

	int newType = StringToInt(argStr);
	if (newType < 0 || newType > 6) {
		CReplyToCommand(client, "{O}%s: {W}新的单一特感模式值 {O}%d {W}秒无效, 请输入{G}介于 0-6 之间的值", PLUGIN_PREFIX, newType);
		return Plugin_Handled;
	}
	g_hSingleInfectedMode.SetInt(newType);
	if (newType == 0) {
		CReplyToCommand(client, "{O}%s: {W}已{O}关闭{W}单一特感模式", PLUGIN_PREFIX);
	} else {
		CReplyToCommand(client, "{O}%s: {W}已调整为单一特感 {O}%s {W}模式", PLUGIN_PREFIX, INFECTED_NAME[newType]);
	}
	return Plugin_Handled;
}

/**
* sm_statelist 指令回调
* @param client 执行指令的客户端索引
* @param args 指令参数
* @return Action
**/
public Action cmdStateList(int client, int args) {
	static int i;
	InfectedState state;
	ReplyToCommand(client, "\n========== 特感状态集合 ==========\n");
	for (i = 0; i < infStateList.Length; i++) {
		infStateList.GetArray(i, state, sizeof(state));
		ReplyToCommand(client, "\t索引 %d, 实体索引 %d, 类型 %s, 重生完成 %b, 上次死亡时间 %.2f, 距离当前 %.2f, 时钟 0x%x",
			i, state.entRef, INFECTED_NAME[state.class], state.isRespawnFinished,
			state.deathTime, GetGameTime() - state.deathTime, state.timer);
	}
	ReplyToCommand(client, "\n================================\n");
	return Plugin_Handled;
}

public Action cmdState(int client, int args) {
	static int i, target;
	static char name[64];

	ReplyToCommand(client, "\n========== 特感刷新状态 ===========\n");
	ReplyToCommand(client, "canSpawn: %b, isLeftSafeArea: %b, isInFindPosFailedDelay: %b, isInSpawnFinishTime: %b, respawnFinishedCount: %d, infectedCount: %d, target: %d", canSpawnNewInfected, isLeftSafeArea, isInFindPosFailedDelay, isInSpawnFinishedTime, respawnFinishedCount, infectedCount, targetIndex);

	ReplyToCommand(client, "====== Target List =====");
	for (i = 0; i < targetList.Length; i++) {
		target = targetList.Get(i, 1);
		if (IsValidSurvivor(target))
			GetClientName(target, name, sizeof(name));
		else
			strcopy(name, sizeof(name), "Invalid");
		ReplyToCommand(client, "index: %d, target: %d (%s)", i, target, name);
	}

	ReplyToCommand(client, "\n================================\n");
	return Plugin_Handled;
}

/**
* sm_entmap 指令回调
* @param client 执行指令的客户端索引
* @param args 指令参数
* @return Action
**/
public Action cmdEntMap(int client, int args) {
	if (infEntRefMap == null) {
		ReplyToCommand(client, "当前特感实体 Map 为 null");
		return Plugin_Handled;
	}

	static int i, value;
	static char key[64];
	ReplyToCommand(client, "\n========== 特感实体 Map ==========\n");
	StringMapSnapshot snapShot = infEntRefMap.Snapshot();
	for (i = 0; i < snapShot.Length; i++) {
		snapShot.GetKey(i, key, sizeof(key));
		if (!infEntRefMap.GetValue(key, value))
			value = -1;
		ReplyToCommand(client, "\t索引 %d, key %s, value %d", i, key, value);
	}
	
	ReplyToCommand(client, "\n================================\n");
	return Plugin_Handled;
}