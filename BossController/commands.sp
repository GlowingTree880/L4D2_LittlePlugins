#pragma semicolon 1
#pragma newdecls required

ConVar
	g_hGlobalPercent,
	g_hShowTankPercent,
	g_hShowWitchPercent,
	g_hShowCurrent;

int
	// 投票更改 Boss 刷新路程时新的 Tank 路程
	newTankPercent,
	// 投票更改 Boss 刷新路程时新的 Witch 路程
	newWitchPercent;

bool
	// 是否可以投票更改 Tank 刷新路程
	canChangeTank,
	// 是否可以投票更改 Witch 刷新路程
	canChangeWitch;

void commandsOnModuleStart() {

	LoadTranslations("l4d_boss_percent.phrases");
	LoadTranslations("l4d_boss_vote.phrases");

	g_hGlobalPercent = CreateConVar("boss_global_percent", "0", "是否在使用显示 Boss 刷新路程指令时将结果显示给整个团队", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hShowTankPercent = CreateConVar("boss_tank_percent", "1", "使用显示 Boss 路程指令时是否显示 Tank 刷新路程", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hShowWitchPercent = CreateConVar("boss_witch_percent", "1", "使用显示 Boss 路程指令时是否显示 Witch 刷新路程", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hShowCurrent = CreateConVar("boss_current", "1", "使用显示 Boss 路程指令时是否显示当前路程", CVAR_FLAG, true, 0.0, true, 1.0);

	// 静态地图相关指令
	RegServerCmd("static_tank_map", cmdStaticTankMapHandler);
	RegServerCmd("static_witch_map", cmdStaticWitchMapHandler);
	RegServerCmd("reset_static_maps", cmdResetStaticMapHandler);
	// 玩家指令
	RegConsoleCmd("sm_boss", cmdPrintBossHandler);
	RegConsoleCmd("sm_tank", cmdPrintBossHandler);
	RegConsoleCmd("sm_witch", cmdPrintBossHandler);
	RegConsoleCmd("sm_cur", cmdPrintBossHandler);
	RegConsoleCmd("sm_current", cmdPrintBossHandler);
	// 玩家投票更改 Boss 刷新路程指令
	RegConsoleCmd("sm_bv", cmdBossVoteHandler, "投票更改 Boss 刷新路程");
	RegConsoleCmd("sm_voteboss", cmdBossVoteHandler, "投票更改 Boss 刷新路程");
	RegConsoleCmd("sm_bossvote", cmdBossVoteHandler, "投票更改 Boss 刷新路程");
	// 管理员指令
	RegAdminCmd("sm_ftank", cmdForceTankHandler, ADMFLAG_BAN, "管理员强制更改本局 Tank 刷新路程 [刷新之前]");
	RegAdminCmd("sm_fwitch", cmdForceWitchHandler, ADMFLAG_BAN, "管理员强制更改本局 Witch 刷新路程 [刷新之前]");
	RegAdminCmd("sm_checkflow", cmdDebugCheckFlowHandler, ADMFLAG_BAN, "显示本局 Tank 与 Witch 刷新路程");
	// 测试指令
	RegAdminCmd("sm_staticmap", cmdStaticMapDisplayHandler, ADMFLAG_BAN, "展示当前已经注册的静态地图");
}

/**
* static_tank_map 指令回调
* @param 
* @return Action
**/
public Action cmdStaticTankMapHandler(int args) {
	char mapName[64];
	GetCmdArg(1, mapName, sizeof(mapName));
	staticTankMap.SetValue(mapName, true);
	log.debugAndInfo("%s: 添加静态 Tank 地图: %s", PLUGIN_PREFIX, mapName);

	return Plugin_Handled;
}

/**
* static_witch_map 指令回调
* @param 
* @return Action
**/
public Action cmdStaticWitchMapHandler(int args) {
	char mapName[64];
	GetCmdArg(1, mapName, sizeof(mapName));
	staticWitchMap.SetValue(mapName, true);
	log.debugAndInfo("%s: 添加静态 Witch 地图: %s", PLUGIN_PREFIX, mapName);

	return Plugin_Handled;
}

/**
* reset_static_map 指令回调
* @param 
* @return Action
**/
public Action cmdResetStaticMapHandler(int args) {
	staticTankMap.Clear();
	staticWitchMap.Clear();
	log.debugAndInfo("%s: 已重置所有静态 Tank 与静态 Witch 地图", PLUGIN_PREFIX);

	return Plugin_Handled;
}

/**
* sm_tank, sm_cur, sm_witch 等 Boss 路程显示指令回调
* @param 
* @return Action
**/
public Action cmdPrintBossHandler(int client, int args) {
	if (!IsValidClient(client)) {
		return Plugin_Handled;
	}
	printBossPercents(client);
	RequestFrame(nextFramePritnCurrent, GetClientUserId(client));

	return Plugin_Handled;
}

void nextFramePritnCurrent(int userId) {
	int client = GetClientOfUserId(userId);
	if (!IsValidClient(client)) {
		return;
	}
	printCurrent(client);
}

/**
* 显示当前路程
* @param client 执行此指令的客户端索引
* @return void
**/
void printCurrent(int client) {
	if (!IsValidClient(client) || !g_hShowCurrent.BoolValue) {
		return;
	}

	static char buffer[64];
	FormatEx(buffer, sizeof(buffer), "%t", "Current", getSurvivorFlowZone());
	static int i, teamFlag;
	teamFlag = GetClientTeam(client);
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || IsFakeClient(i)) {
			continue;
		}
		if (g_hGlobalPercent.BoolValue || (!g_hGlobalPercent.BoolValue && i == client)) {
			if (GetClientTeam(i) != teamFlag) {
				continue;
			}
			CPrintToChat(i, buffer);
		}
	}
}

// HACK: 有效 Tank 或 Witch 时 translation 字符串修改
// <Tank> 50% (✓ / ✕)
/**
* 获取 Tank 刷新位置字符串
* @param tankStr 源字符串
* @param isReadyUpFormat 是否为格式化需要添加到 ReadyUpFooter 的字符串
* @return void
**/
public void getTankPercentString(char[] tankStr, int len, bool isReadyUpFormat) {
	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	bool isStaticTank;
	if (L4D_IsVersusMode()) {
		if (isFinaleMap() && g_hDisableInFinale.BoolValue) {
			isStaticTank = true;
		} else if (!isDarkCarnivalRemix()) {
			isStaticTank = isStaticTankMap(mapName);
		}
	} else {
		if (isFinaleMap() && g_hDisableInFinale.BoolValue) {
			isStaticTank = true;
		} else {
			isStaticTank = isStaticTankMap(mapName);
		}
	}

	if (tankFlow > 0) {
		if (isReadyUpFormat) {
			FormatEx(tankStr, len, "%T", "TankOn", LANG_SERVER, tankFlow);
		} else {
			FormatEx(tankStr, len, "%t %t %t", "TagTank", "TankPercent", tankFlow, isTankSpawned ? "Spawned" : "NotSpawned");
		}
	} else if (!g_hTankCanSpawn.BoolValue) {
		if (isReadyUpFormat) {
			FormatEx(tankStr, len, "%T", "TankDisabled", LANG_SERVER);
		} else {
			FormatEx(tankStr, len, "%t {R}%t", "TagTank", "Disabled");
		}
	} else if (isStaticTank) {
		if (isReadyUpFormat) {
			FormatEx(tankStr, len, "%T", "TankStatic", LANG_SERVER);
		} else {
			FormatEx(tankStr, len, "%t {R}%t", "TagTank", "StaticSpawn");
		}
	} else {
		if (isReadyUpFormat) {
			FormatEx(tankStr, len, "%T", "TankNone", LANG_SERVER);
		} else {
			FormatEx(tankStr, len, "%t {R}%t", "TagTank", "None");
		}
	}
}

/**
* 获取 Witch 刷新位置字符串
* @param witchStr 源字符串
* @param isReadyUpFormat 是否为格式化需要添加到 ReadyUpFooter 的字符串
* @return void
**/
public void getWitchPercentString(char[] witchStr, int len, bool isReadyUpFormat) {
	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	bool isStaticWitch;
	if (L4D_IsVersusMode()) {
		if (isFinaleMap() && g_hDisableInFinale.BoolValue) {
			isStaticWitch = true;
		} else if (!isDarkCarnivalRemix()) {
			isStaticWitch = isStaticWitchMap(mapName);
		}
	} else {
		if (isFinaleMap() && g_hDisableInFinale.BoolValue) {
			isStaticWitch = true;
		} else {
			isStaticWitch = isStaticWitchMap(mapName);
		}
	}

	if (witchFlow > 0) {
		if (isReadyUpFormat) {
			FormatEx(witchStr, len, "%T", "WitchOn", LANG_SERVER, witchFlow);
		} else {
			FormatEx(witchStr, len, "%t %t %t", "TagWitch", "WitchPercent", witchFlow, isWitchSpawned ? "Spawned" : "NotSpawned");
		}
	} else if (!g_hWitchCanSpawn.BoolValue) {
		if (isReadyUpFormat) {
			FormatEx(witchStr, len, "%T", "WitchDisabled", LANG_SERVER);
		} else {
			FormatEx(witchStr, len, "%t {R}%t", "TagWitch", "Disabled");
		}
	} else if (isStaticWitch) {
		if (isReadyUpFormat) {
			FormatEx(witchStr, len, "%T", "WitchStatic", LANG_SERVER);
		} else {
			FormatEx(witchStr, len, "%t {R}%t", "TagWitch", "StaticSpawn");
		}
	} else {
		if (isReadyUpFormat) {
			FormatEx(witchStr, len, "%T", "WitchNone", LANG_SERVER);
		} else {
			FormatEx(witchStr, len, "%t {R}%t", "TagWitch", "None");
		}
	}
}

/**
* 显示本局 Boss 刷新路程
* @param client 执行此指令的客户端索引
* @return void
**/
void printBossPercents(int client) {

	if (!IsValidClient(client)) {
		return;
	}

	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	static char tankStr[128], witchStr[128];
	getTankPercentString(tankStr, sizeof(tankStr), false);
	getWitchPercentString(witchStr, sizeof(witchStr), false);
	
	static int i, teamFlag;
	teamFlag = GetClientTeam(client);
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || IsFakeClient(i)) {
			continue;
		}
		if (g_hGlobalPercent.BoolValue || (!g_hGlobalPercent.BoolValue && i == client)) {
			if (GetClientTeam(i) != teamFlag) {
				continue;
			}
			if (g_hShowTankPercent.BoolValue) {
				CPrintToChat(i, tankStr);
			}
			if (g_hShowWitchPercent.BoolValue) {
				CPrintToChat(i, witchStr);
			}
		}
	}

	return;
}

// TODO: 增加 AvailableOnlyInSafeArea 的 translation
/**
* 检查是否可以发起更改 Boss 刷新路程的投票
* @param client 发起投票的客户端索引
* @return bool
**/
bool checkCanVoteBoss(int client) {
	if (GetClientTeam(client) == TEAM_SPECTATOR) {
		CPrintToChat(client, "%t %t", "Tag", "NotAvailableForSpec");
		return false;
	}
	if (isDarkCarnivalRemix()) {
		CPrintToChat(client, "%t %t", "Tag", "NotAvailable");
		return false;
	}
	if (InVersusSecondRound()) {
		CPrintToChat(client, "%t %t", "Tag", "FirstRound");
		return false;
	}
	if (isReadyUpExist && !IsInReady() || isReadyUpExist && isLeftSafeArea) {
		CPrintToChat(client, "%t %t", "Tag", "Available");
		return false;
	}
	if (!isReadyUpExist && isLeftSafeArea) {
		CPrintToChat(client, "%t %t", "Tag", "AvailableOnlyInSafeArea");
		return false;
	}
	if (!IsNewBuiltinVoteAllowed()) {
		CPrintToChat(client, "%t %t", "Tag", "CannotBeCalled");
		return false;
	}
	return true;
}

// TODO: 新增 BossVoteDisable 的 translation
public Action cmdBossVoteHandler(int client, int args) {
	if (!IsValidClient(client)) {
		return Plugin_Handled;
	}

	if (!g_hCanVoteBoss.BoolValue) {
		CReplyToCommand(client, "%t", "BossVoteDisable");
		return Plugin_Handled;
	}

	if (!checkCanVoteBoss(client)) {
		return Plugin_Handled;
	}

	if (args != 2) {
		CReplyToCommand(client, "%t", "Usage");
		CReplyToCommand(client, "%t", "Usage2");
		return Plugin_Handled;
	}

	static int i, index;
	int[] players = new int[MaxClients];
	for (i = 1, index = 0; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) < TEAM_SURVIVOR || IsFakeClient(i)) {
			continue;
		}
		players[index++] = i;
	}

	newTankPercent, newWitchPercent;
	static char tankStr[8], witchStr[8], mapName[64];
	GetCmdArg(1, tankStr, sizeof(tankStr));
	GetCmdArg(2, witchStr, sizeof(witchStr));
	GetCurrentMap(mapName, sizeof(mapName));

	if (!IsInteger(tankStr) || !IsInteger(witchStr)) {
		CReplyToCommand(client, "%t %t", "Tag", "Invalid");
		return Plugin_Handled;
	}

	newTankPercent = StringToInt(tankStr);
	newWitchPercent = StringToInt(witchStr);

	if (newTankPercent > 0 && isTankSpawned) {
		CReplyToCommand(client, "%t", "TankAlreadySpawned");
		return Plugin_Handled;
	} else if (!isStaticTankMap(mapName)) {
		canChangeTank = newTankPercent > 0;
	} else {
		canChangeTank = false;
		CReplyToCommand(client, "%t %t", "Tag", "TankStatic");
	}

	if (newWitchPercent > 0 && isWitchSpawned) {
		CReplyToCommand(client, "%t", "WitchAlreadySpawned");
		return Plugin_Handled;
	} if (!isStaticWitchMap(mapName)) {
		canChangeWitch = newWitchPercent > 0;
	} else {
		canChangeWitch = false;
		CReplyToCommand(client, "%t %t", "Tag", "WitchStatic");
	}

	// 检查新的 Boss 路程是否有效
	if (canChangeTank && !isTankPercentValid(newTankPercent)) {
		canChangeTank = false;
		CReplyToCommand(client, "%t %t", "Tag", "TankBanned");
	}
	// NOTE: 检查新的 Witch 路程是否有效, 首先忽略 Witch Avoid Tank 的路程判断
	if (canChangeWitch && !isWitchPercentValidWithBlock(newWitchPercent, true)) {
		canChangeWitch = false;
		CReplyToCommand(client, "%t %t", "Tag", "WitchBanned");
	}
	// 检查新的 Witch 路程是否处在新的 Witch Ban Flow 中
	if (canChangeWitch && newWitchPercent >= (newTankPercent - RoundToNearest(g_hWitchAvoidTank.FloatValue / 2.0)) && newWitchPercent <= (newTankPercent + RoundToNearest(g_hWitchAvoidTank.FloatValue / 2.0))) {
		canChangeWitch = false;
		CReplyToCommand(client, "%t %t", "Tag", "WitchBanned");
	}

	// 设置投票标题
	static char title[64], name[MAX_NAME_LENGTH];
	if (canChangeTank && canChangeWitch) {
		FormatEx(title, sizeof(title), "%T", "SetBosses", LANG_SERVER, tankStr, witchStr);
	} else if (canChangeTank) {
		// Witch Banned
		if (newWitchPercent == 0) {
			FormatEx(title, sizeof(title), "%T", "SetTank", LANG_SERVER, tankStr);
		} else {
			FormatEx(title, sizeof(title), "%T", "SetOnlyTank", LANG_SERVER, tankStr);
		}
	} else if (canChangeWitch) {
		// Tank Banned
		if (newTankPercent == 0) {
			FormatEx(title, sizeof(title), "%T", "SetWitch", LANG_SERVER, witchStr);
		}
		else {
			FormatEx(title, sizeof(title), "%T", "SetOnlyWitch", LANG_SERVER, witchStr);
		}
	} else {
		if (newTankPercent == 0 && newWitchPercent == 0) {
			FormatEx(title, sizeof(title), "%T", "SetBossesDisabled", LANG_SERVER);
		} else if (newTankPercent == 0) {
			FormatEx(title, sizeof(title), "%T", "SetTankDisabled", LANG_SERVER);
		} else if (newWitchPercent == 0) {
			FormatEx(title, sizeof(title), "%T", "SetWitchDisabled", LANG_SERVER);
		} else {
			return Plugin_Handled;
		}
	}

	Handle hVote = CreateBuiltinVote(bossVoteHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(hVote, title);
	SetBuiltinVoteInitiator(hVote, client);
	DisplayBuiltinVote(hVote, players, index, 20);
	FakeClientCommand(client, "Vote Yes");

	// TODO: 增加 VoteBoss 的 Translation
	GetClientName(client, name, sizeof(name));
	CPrintToChatAll("%t %t", "Tag", "VoteBoss", name);

	return Plugin_Handled;
}

public int bossVoteHandler(Handle vote, BuiltinVoteAction action, int param1, int param2) {
	switch (action) {
		case BuiltinVoteAction_End: {
			delete vote;
		} case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		} case BuiltinVoteAction_VoteEnd: {
			if (param1 == BUILTINVOTES_VOTE_YES) {
				if (param1 == BUILTINVOTES_VOTE_YES) {
					static char voteResult[64];

					if ((isReadyUpExist && !IsInReady()) || (isReadyUpExist && isLeftSafeArea)) {
						DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
						CPrintToChatAll("%t", "OnlyReadyUp");
						return -1;
					}
					if (!isReadyUpExist && isLeftSafeArea) {
						DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
						CPrintToChatAll("%t", "AvailableOnlyInSafeArea");
						return -1;
					}
					if (canChangeTank && canChangeWitch) {
						FormatEx(voteResult, sizeof(voteResult), "%T", "SettingBoss", LANG_SERVER);
						DisplayBuiltinVotePass(vote, voteResult);
					} else if (canChangeTank) {
						FormatEx(voteResult, sizeof(voteResult), "%T", "SettingTank", LANG_SERVER);
						DisplayBuiltinVotePass(vote, voteResult);
					} else if (canChangeWitch) {
						FormatEx(voteResult, sizeof(voteResult), "%T", "SettingWitch", LANG_SERVER);
						DisplayBuiltinVotePass(vote, voteResult);
					} else {
						FormatEx(voteResult, sizeof(voteResult), "%T", "SettingBossDisabled", LANG_SERVER);
						DisplayBuiltinVotePass(vote, voteResult);
					}

					// NOTE: 由于开局设置 Witch 路程时考虑了 Witch Avoid Tank, 因此设置新的 Witch 路程时, 需要先设置 Tank 的路程, 恢复之前的 Witch Avoid Tank 路程, 获取并设置新的 Witch Avoid Tank 路程, 合并 Witch Ban Flow, 最后再设置新的 Witch 的路程
					setTankPercentWitchWitchAvoidance(newTankPercent);
					setWitchPercentWithValid(newWitchPercent);

					// Call Native, boss_percent::UpdateBossPercents()
					updateBossPercents();

					// 发布自定义事件 UpdateBosses
					Call_StartForward(forwardUpdateBosses);
					Call_PushCell(newTankPercent);
					Call_PushCell(newWitchPercent);
					Call_Finish();
				} else if (param1 == BUILTINVOTES_VOTE_NO) {
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
				} else {
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
				}
			} else if (param1 == BUILTINVOTES_VOTE_NO) {
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
			}
		}
	}
	return 0;
}

// TODO: 增加 BossVoteDisable, ForceTankUseage, TankAlreadySpawned 的 translation
public Action cmdForceTankHandler(int client, int args) {
	if (!IsValidClient(client)) {
		return Plugin_Handled;
	}

	if (!g_hCanVoteBoss.BoolValue) {
		CReplyToCommand(client, "%t", "BossVoteDisable");
		return Plugin_Handled;
	}

	if (args != 1) {
		CPrintToChat(client, "%t", "ForceTankUseage");
		return Plugin_Handled;
	}

	if (isDarkCarnivalRemix())
	{
		CPrintToChat(client, "%t", "CommandNotAvailable");
		return Plugin_Handled;
	}
	
	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	if (isStaticTankMap(mapName))
	{
		CPrintToChat(client, "%t", "TankSpawnStatic");
		return Plugin_Handled;
	}
	
	if (isReadyUpExist && !IsInReady())
	{
		CPrintToChat(client, "%t", "OnlyReadyUp");
		return Plugin_Handled;
	}

	if (isTankSpawned) {
		CPrintToChat(client, "%t", "TankAlreadySpawned");
		return Plugin_Handled;
	}

	static char tankStr[16];
	GetCmdArg(1, tankStr, sizeof(tankStr));

	if (!IsInteger(tankStr)) {
		CReplyToCommand(client, "%t %t", "Tag", "Invalid");
		return Plugin_Handled;
	}

	static int reqPercent;
	reqPercent = StringToInt(tankStr);
	if (reqPercent < 0) {
		CPrintToChat(client, "%t", "PercentageInvalid");
		return Plugin_Handled;
	}

	if (!isTankPercentValid(reqPercent)) {
		CPrintToChat(client, "%t", "Percentagebanned");
		return Plugin_Handled;
	}

	setTankPercentWitchWitchAvoidance(reqPercent);

	static char clientName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));
	CPrintToChatAll("%t", "TankSpawnAdmin", reqPercent, clientName);

	// Call Native, boss_percent::UpdateBossPercents()
	updateBossPercents();

	// 发布自定义事件 UpdateBosses
	Call_StartForward(forwardUpdateBosses);
	Call_PushCell(reqPercent);
	Call_PushCell(-1);
	Call_Finish();

	return Plugin_Handled;
}

// TODO: 增加 BossVoteDisabled, ForceWitchUseage, WitchAlreadySpawned 的 translation
public Action cmdForceWitchHandler(int client, int args) {
	if (!IsValidClient(client)) {
		return Plugin_Handled;
	}

	if (!g_hCanVoteBoss.BoolValue) {
		CReplyToCommand(client, "%t", "BossVoteDisable");
		return Plugin_Handled;
	}

	if (args != 1) {
		CPrintToChat(client, "%t", "ForceWitchUseage");
		return Plugin_Handled;
	}

	if (isDarkCarnivalRemix())
	{
		CPrintToChat(client, "%t", "CommandNotAvailable");
		return Plugin_Handled;
	}
	
	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	if (isStaticWitchMap(mapName))
	{
		CPrintToChat(client, "%t", "WitchSpawnStatic");
		return Plugin_Handled;
	}
	
	if (isReadyUpExist && !IsInReady())
	{
		CPrintToChat(client, "%t", "OnlyReadyUp");
		return Plugin_Handled;
	}

	if (isWitchSpawned) {
		CPrintToChat(client, "%t", "WitchAlreadySpawned");
		return Plugin_Handled;
	}

	static char witchStr[16];
	GetCmdArg(1, witchStr, sizeof(witchStr));

	if (!IsInteger(witchStr)) {
		CReplyToCommand(client, "%t %t", "Tag", "Invalid");
		return Plugin_Handled;
	}

	static int reqPercent;
	reqPercent = StringToInt(witchStr);
	if (reqPercent < 0) {
		CPrintToChat(client, "%t", "PercentageInvalid");
		return Plugin_Handled;
	}

	if (!isWitchPercentValid(reqPercent)) {
		CPrintToChat(client, "%t", "Percentagebanned");
		return Plugin_Handled;
	}

	setWitchPercentWithValid(reqPercent);
	
	static char clientName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));
	CPrintToChatAll("%t", "WitchSpawnAdmin", reqPercent, clientName);

	// Call Native, boss_percent::UpdateBossPercents()
	updateBossPercents();

	// 发布自定义事件 UpdateBosses
	Call_StartForward(forwardUpdateBosses);
	Call_PushCell(-1);
	Call_PushCell(reqPercent);
	Call_Finish();

	return Plugin_Handled;
}

public Action cmdDebugCheckFlowHandler(int client, int args) {
	static char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));

	CReplyToCommand(client, "\n========== Check Flow ==========\n");
	if (isStaticTankMap(mapName)) {
		CReplyToCommand(client, "当前地图 {O}%s {W}是静态 Tank 地图, 插件不会接管 Tank 刷新", mapName);
	}
	if (isStaticWitchMap(mapName)) {
		CReplyToCommand(client, "当前地图 {O}%s {W}是静态 Witch 地图, 插件不会接管 Witch 刷新", mapName);
	}

	if (!L4D_IsVersusMode()) {
		CReplyToCommand(client, "当前非对抗模式, 本局 {G}Tank 路程 {O}%d%%, {W}本局 {G}Witch 路程 {O}%d%%", tankFlow, witchFlow);
	} else {
		CReplyToCommand(client, "当前为{O}对抗模式, {W}是否是{G}第一局 {O}%b", !InVersusSecondRound());
		CReplyToCommand(client, "第一局是否允许刷新 {G}Tank: {O}%b, {W}是否允许刷新 {G}Witch: {O}%b", L4D2Direct_GetVSTankToSpawnThisRound(0), L4D2Direct_GetVSWitchToSpawnThisRound(0));
		CReplyToCommand(client, "第一局 {G}Tank 路程 {O}%.2f, {W}第一局 {G}Witch 路程 {O}%.2f", L4D2Direct_GetVSTankFlowPercent(0), L4D2Direct_GetVSWitchFlowPercent(0));
		CReplyToCommand(client, "第二局是否允许刷新 {G}Tank: {O}%b, {W}是否允许刷新 {G}Witch: {O}%b", L4D2Direct_GetVSTankToSpawnThisRound(1), L4D2Direct_GetVSWitchToSpawnThisRound(1));
		CReplyToCommand(client, "第二局 {G}Tank 路程 {O}%.2f, 第二局 {G}Witch 路程 {O}%.2f", L4D2Direct_GetVSTankFlowPercent(1), L4D2Direct_GetVSWitchFlowPercent(1));
	}
	CReplyToCommand(client, "\n");
	return Plugin_Handled;
}

public Action cmdStaticMapDisplayHandler(int client, int args) {
	static int i;
	static char key[64];
	if (staticTankMap != null) {
		CReplyToCommand(client, "{G}\n========== Static Tank Map ==========\n");
		StringMapSnapshot tankMapKeySet = staticTankMap.Snapshot();
		
		for (i = 0; i < tankMapKeySet.Length; i++) {
			tankMapKeySet.GetKey(i, key, sizeof(key));
			CReplyToCommand(client, "\t{G}%s", key);
		}
	}
	if (staticWitchMap != null) {
		CReplyToCommand(client, "{G}\n========== Static Witch Map ==========\n");
		StringMapSnapshot witchMapKeySet = staticWitchMap.Snapshot();
		
		for (i = 0; i < witchMapKeySet.Length; i++) {
			witchMapKeySet.GetKey(i, key, sizeof(key));
			CReplyToCommand(client, "\t{G}%s", key);
		}
	}

	return Plugin_Handled;
}