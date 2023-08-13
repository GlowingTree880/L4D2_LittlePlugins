#pragma semicolon 1
#pragma newdecls required

#define ROUND_START_DELAY 0.5
#define GET_BOSS_FLOW_WITH_DKR_DELAY 5.0
// 从 round_start 到更新 ReadyUp Footer 延迟
#define UPDATE_READYUP_FOOTER_DELAY 6.0
// 非插件刷出的 Boss 踢出延迟
#define NON_PLUGIN_BOSSES_KICK_DELAY 0.5

bool
	// 是否是插件生成的 Tank
	tankSpawnByPlugin,
	// 是否是插件生成的 Witch
	witchSpawnByPlugin;

void eventsOnModuleStart() {
	HookEvent("round_start", eventRoundStartHandler);
	HookEvent("tank_spawn", eventTankSpawnHandler);
	HookEvent("witch_spawn", eventWitchSpawnHandler);
	HookEvent("player_say", eventDarkCarnivalRemixGetScriptBossFlow);
}

/**
* 回合开始事件
* @param 
* @return void
**/
public void eventRoundStartHandler(Event event, const char[] name, bool dontBroadcast) {
	onRoundEndResetState();
	CreateTimer(ROUND_START_DELAY, timerGetBossFlow, _, _);
	CreateTimer(ROUND_START_DELAY, timerSetGameDirector, _, _);
	CreateTimer(GET_BOSS_FLOW_WITH_DKR_DELAY, timerGetBossFlowWithDkrInclude, _, _);
	updateReadyUpFooter(UPDATE_READYUP_FOOTER_DELAY);
}

void eventTankSpawnHandler(Event event, const char[] name, bool dontBroadcast) {
	if (L4D_IsVersusMode()) {
		return;
	}

	int tank = GetClientOfUserId(event.GetInt("userid")), tankEntId = event.GetInt("tankid");
	if (!IsValidClient(tank)) {
		return;
	}
	if (!IsValidEntity(tankEntId) || !IsValidEdict(tankEntId)) {
		return;
	}
	if (!tankSpawnByPlugin && g_hProhibitNonPluginBoss.BoolValue) {
		CreateTimer(NON_PLUGIN_BOSSES_KICK_DELAY, timerKickNonPluginTank, tank, _);
	}
}

void eventWitchSpawnHandler(Event event, const char[] name, bool dontBroadcast) {
	if (L4D_IsVersusMode()) {
		return;
	}

	int witchEntId = event.GetInt("witchid");
	if (!IsValidEntity(witchEntId) || !IsValidEdict(witchEntId)) {
		return;
	}
	if (!witchSpawnByPlugin && g_hProhibitNonPluginBoss.BoolValue) {
		AcceptEntityInput(witchEntId, "Kill");

		log.debugAndInfo("%s: 产生了一个非插件刷新的 Witch, 实体 ID %d, 已删除", PLUGIN_PREFIX, witchEntId);
	}
}

/**
* 玩家发言事件, 判断是否是 Dark Carnival Remix 中由脚本在聊天框中输出的 Tank 与 Witch 刷新路程, 是则截取路程保存, 以便显示 Boss 路程与更新 ReadyUp 面板 Footer
* @param 
* @return void
**/
void eventDarkCarnivalRemixGetScriptBossFlow(Event event, const char[] name, bool dontBroadcast) {
	if (!isDarkCarnivalRemix()) {
		return;
	}
	static int userId, percent;
	userId = event.GetInt("userid", userId);
	if (IsValidClient(userId)) {
		return;
	}

	char sayText[512];
	event.GetString("text", sayText, sizeof(sayText));
	if (StrContains(sayText, "The Tank", false) >= 0) {
		percent = getPercentageFromText(sayText, sizeof(sayText));
		dkrFirstRoundTankPercent = tankFlow = percent > -1 ? percent : 0;
	}
	if (StrContains(sayText, "The Witch", false) >= 0) {
		percent = getPercentageFromText(sayText, sizeof(sayText));
		dkrFirstRoundWitchPercent = witchFlow = percent > -1 ? percent : 0;
		log.debugAndInfo("The Witch: %d %d", percent, witchFlow);
	}

	updateReadyUpFooter();
}