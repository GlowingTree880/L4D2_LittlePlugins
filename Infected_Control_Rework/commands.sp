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
			ReplyToCommand(client, "%s: 当前非第一波特感刷新, 不可使用本指令", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
		// 第一波刷新
		if (g_hFirstWaveDelay.BoolValue) {
			CreateTimer(g_hFirstWaveDelay.FloatValue, timerFirstWaveDelaySpawnHandler, _, _);
		} else {
			canSpawnNewInfected = true;
		}
	} else {
		ReplyToCommand(client, "%s: 当前已经为自动刷新控制模式, 不可使用指令刷新", PLUGIN_PREFIX);
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
		ReplyToCommand(client, "%s: 请使用 !limit <num> 来修改特感数量", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	char argStr[16];
	GetCmdArgString(argStr, sizeof(argStr));
	
	int newLimit = StringToInt(argStr);
	if (newLimit < 0 || newLimit > MaxClients) {
		ReplyToCommand(client, "%s: 新的数量 %d 无效, 请确认输入有效性", PLUGIN_PREFIX, newLimit);
		return Plugin_Handled;
	}
	g_hInfectedLimit.SetInt(newLimit);
	ReplyToCommand(client, "%s: 已调整特感刷新为 %d 特 %d 秒", PLUGIN_PREFIX, g_hInfectedLimit.IntValue, g_hSpawnDuration.IntValue);
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
		ReplyToCommand(client, "%s: 请使用 !duration <sec> 来修改特感刷新时间", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	char argStr[16];
	GetCmdArgString(argStr, sizeof(argStr));

	int newTime = StringToInt(argStr);
	if (newTime < 0) {
		ReplyToCommand(client, "%s: 新的特感刷新时间 %d 秒无效, 请确认输入有效性", PLUGIN_PREFIX, newTime);
		return Plugin_Handled;
	}
	g_hSpawnDuration.SetInt(newTime);
	ReplyToCommand(client, "%s: 已调整特感刷新为 %d 特 %d 秒", PLUGIN_PREFIX, g_hInfectedLimit.IntValue, g_hSpawnDuration.IntValue);
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
		ReplyToCommand(client, "%s: 请使用 !type <num> 来指定使用哪种特感的单一特感模式, 0 为关闭", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	char argStr[16];
	GetCmdArgString(argStr, sizeof(argStr));

	int newType = StringToInt(argStr);
	if (newType < 0 || newType > 6) {
		ReplyToCommand(client, "%s: 新的单一特感模式值 %d 秒无效, 请输入介于 0-6 之间的值", PLUGIN_PREFIX, newType);
		return Plugin_Handled;
	}
	g_hSingleInfectedMode.SetInt(newType);
	if (newType == 0) {
		ReplyToCommand(client, "%s: 已关闭单一特感模式", PLUGIN_PREFIX);
	} else {
		ReplyToCommand(client, "%s: 已调整为单一特感 %s 模式", PLUGIN_PREFIX, INFECTED_NAME[newType]);
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
	if (client == 0) {
		PrintToServer("\n========== 特感状态数组 ==========\n");
		for (i = 0; i <= MaxClients; i++) {
			PrintToServer("\t索引 %d, 类型 %s, 有效 %b, 重生完成 %b, 上次死亡时间 %.2f, 距离当前 %.2f", i, INFECTED_NAME[infectedStates[i].infectedType], infectedStates[i].valid, infectedStates[i].isRespawnFinished, infectedStates[i].deathTime, GetGameTime() - infectedStates[i].deathTime);
		}
		PrintToServer("\n================================\n");
	} else {
		PrintToConsoleAll("\n========== 特感状态数组 ==========\n");
		for (i = 0; i <= MaxClients; i++) {
			PrintToConsoleAll("\t索引 %d, 类型 %s, 有效 %b, 重生完成 %b, 上次死亡时间 %.2f, 距离当前 %.2f", i, INFECTED_NAME[infectedStates[i].infectedType], infectedStates[i].valid, infectedStates[i].isRespawnFinished, infectedStates[i].deathTime, GetGameTime() - infectedStates[i].deathTime);
		}
		PrintToConsoleAll("\n================================\n");
	}
	return Plugin_Handled;
}