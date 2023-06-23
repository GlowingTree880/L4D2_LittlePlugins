#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
// #include <readyup>
#include <builtinvotes>
#include "treeutil/treeutil.sp"
#include <logger>

#define CVAR_FLAGS FCVAR_NOTIFY
#define MAP_INFO_PATH "../../cfg/cfgogl/mapinfo.txt"
#define SPAWN_ATTEMPT 15
#define MENU_DISPLAY_TIME 20
#define DEBUG_ALL 1
#define PLUGIN_PREFIX "[BossController]"

public Plugin myinfo = 
{
	name 			= "Boss Controller",
	author 			= "CanadaRox, Sir, devilesk, Derpduck, Forgetest, Spoon, 夜羽真白",
	description 	= "整合 witch_and_tankifier 与 boss_percent 与 boss_vote 的插件，战役或对抗 / 有无 mapInfo.txt 文件都允许在固定路程刷新 boss",
	version 		= "1.0.1.2 - SNAPSHOT",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

Handle
	bossTimer;
ConVar
	g_hVsBossBuffer,
	g_hVsBossFlowMin,
	g_hVsBossFlowMax,
	g_hTankCanSpawn,
	g_hWitchCanSpawn,
	g_hWitchAvoidTank,
	g_hVersusConsist,
	g_hPromptDist,
	g_hCanVoteBoss,
	g_hEnablePrompt,
	g_hEnableDirector,
	g_hProhibitNonPluginBoss,
	g_hDisableInFinale,
	g_hEnableLog;
int
	/* now xxx flow 为插件设置好的 boss 刷新位置 */
	nowTankFlow = 0,
	nowWitchFlow = 0,
	survivorPrompDist = 0,
	/* readyUpIndex = -1 */
	versusFirstTankFlow = 0,
	versusFirstWitchFlow = 0,
	// dkrFirstTankFlow = 0,
	// dkrFirstWitchFlow = 0,
	/* xxx act flow 为投票通过后设置的 boss 刷新位置 */
	tankActFlow = -1,
	witchActFlow = -1,
	minFlow = -1,
	maxFlow = -1,
	/* xxx index 为战役模式下插件刷出的 boss 的索引 */
	tankIndex = -1,
	witchIndex = -1;
bool
	// isReadyUpExist,
	isDKR,
	// isReadyUpAdded,
	canSetTank,
	canSetWitch,
	isLeftSafeArea,
	spawnedTank,
	spawnedWitch,
	isFinale;
char
	curMapName[64],
	mapInfoPath[PLATFORM_MAX_PATH];
float
	tankSpawnPos[3],
	witchSpawnPos[3];
// 复杂数据类型
StringMap
	mStaticTankMaps,
	mStaticWitchMaps;
ArrayList
	lTankFlows,
	lWitchFlows;
KeyValues
	mapInfo;
// 其他
GlobalForward
	fUpdateBoss;

Logger
	log;

// 输出 boss 信息类型
enum
{
	TYPE_PLAYER,
	TYPE_ALL
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "该插件仅支持 L4D2");
		return APLRes_SilentFailure;
	}
	// 注册 witch_and_tankifier 插件的 Native
	CreateNative("IsStaticTankMap", Native_IsStaticTankMap);
	CreateNative("IsStaticWitchMap", Native_IsStaticWitchMap);
	CreateNative("IsTankPercentValid", Native_IsTankPercentValid);
	CreateNative("IsWitchPercentValid", Native_IsWitchPercentValid);
	CreateNative("IsWitchPercentBlockedForTank", Native_IsWitchPercentBlockedForTank);
	CreateNative("SetTankPercent", Native_SetTankPercent);
	CreateNative("SetWitchPercent", Native_SetWitchPercent);
	// 注册 boss_percent 插件的 Native
	CreateNative("SetTankDisabled", Native_SetTankDisabled);
	CreateNative("SetWitchDisabled", Native_SetWitchDisabled);
	/* CreateNative("UpdateBossPercents", Native_UpdateBossPercents); */
	CreateNative("GetStoredTankPercent", Native_GetStoredTankPercent);
	CreateNative("GetStoredWitchPercent", Native_GetStoredWitchPercent);
	/* CreateNative("GetReadyUpFooterIndex", Native_GetReadyUpFooterIndex); */
	CreateNative("IsDarkCarniRemix", Native_IsDarkCarniRemix);
	// 注册插件支持
	RegPluginLibrary("witch_and_tankifier");
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hTankCanSpawn = CreateConVar("boss_tank_can_spawn", "1", "是否允许插件生成坦克", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hWitchCanSpawn = CreateConVar("boss_witch_can_spawn", "1", "是否允许插件生成女巫", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hWitchAvoidTank = CreateConVar("boss_witch_avoid_tank", "20", "女巫应该距离坦克刷新位置多远的路程刷新 \
	（将会以坦克刷新位置为中点，左右 / 2 距离，比如坦克在 76 刷，女巫则不能设置在 66 - 86 的路程）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hVersusConsist = CreateConVar("boss_versus_consist", "1", "是否保持在对抗的两局中坦克女巫刷新在同一路程", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCanVoteBoss = CreateConVar("boss_enable_vote", "1", "是否允许通过 !voteboss 等指令投票坦克女巫刷新位置", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hEnablePrompt = CreateConVar("boss_enable_prompt", "1", "在距离 boss 刷新位置前 PROMPT_DIST 开始提示生还者准备刷 boss", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hPromptDist = CreateConVar("boss_prompt_dist", "5", "在距离 Boss 刷新路程之前多少路程开始提示即将刷新", CVAR_FLAGS, true, 0.0);
	g_hEnableDirector = CreateConVar("boss_enable_director", "0", "通过调整 director_no_bosses 决定是否允许导演系统刷新 boss", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hProhibitNonPluginBoss = CreateConVar("boss_prohibit_non_plugin", "1", "战役模式下是否不允许其他插件刷新 boss", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hDisableInFinale = CreateConVar("boss_disable_in_finale", "0", "是否在救援关禁止本插件刷新 boss", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hEnableLog = CreateConVar("boss_enable_log", "1", "是否开启日志信息记录", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	g_hVsBossFlowMax = FindConVar("versus_boss_flow_max");
	g_hVsBossFlowMin = FindConVar("versus_boss_flow_min");
	// 初始化 KV 表，集合与字典
	fUpdateBoss = new GlobalForward("OnUpdateBosses", ET_Ignore, Param_Cell, Param_Cell);
	mStaticTankMaps = new StringMap();
	mStaticWitchMaps = new StringMap();
	lTankFlows = new ArrayList(2);
	lWitchFlows = new ArrayList(2);
	mapInfo = new KeyValues("MapInfo");

	log = new Logger(g_hEnableLog.BoolValue);  

	BuildPath(Path_SM, mapInfoPath, sizeof(mapInfoPath), MAP_INFO_PATH);
	if (!FileExists(mapInfoPath) || !FileToKeyValues(mapInfo, mapInfoPath)) {
		log.info("%s: mapInfo 文件: %s 不存在", PLUGIN_PREFIX, mapInfoPath);
		delete mapInfo;
		mapInfo = null;
	} else {
		log.info("%s: 已找到 mapInfo 文件: %s, 导入成功", PLUGIN_PREFIX, mapInfoPath);
		mapInfo.ImportFromFile(MAP_INFO_PATH);
	}
	// HookEvents
	HookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", evt_TankSpawn);
	HookEvent("witch_spawn", evt_WitchSpawn);
	// ServerCommand
	RegServerCmd("static_tank_map", Cmd_StaticTankMap);
	RegServerCmd("static_witch_map", Cmd_StaticWitchMap);
	RegServerCmd("reset_static_maps", Cmd_ResetStaticBossMap);
	// PlayerCommand
	RegConsoleCmd("sm_boss", Cmd_PrintBossPercent);
	RegConsoleCmd("sm_tank", Cmd_PrintBossPercent);
	RegConsoleCmd("sm_witch", Cmd_PrintBossPercent);
	RegConsoleCmd("sm_cur", Cmd_PrintBossPercent);
	RegConsoleCmd("sm_current", Cmd_PrintBossPercent);
	RegConsoleCmd("sm_voteboss", Cmd_BossVote);
	RegConsoleCmd("sm_bossvote", Cmd_BossVote);
	// AdminCmd
	RegAdminCmd("sm_ftank", Cmd_ForceTank, ADMFLAG_BAN);
	RegAdminCmd("sm_fwitch", Cmd_ForceWitch, ADMFLAG_BAN);
	// ChangeHook
	g_hEnableDirector.AddChangeHook(ConVarChanged_Cvars);
}
public void OnPluginEnd()
{
	UnhookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
	UnhookEvent("tank_spawn", evt_TankSpawn);
	UnhookEvent("witch_spawn", evt_WitchSpawn);
	delete mStaticTankMaps;
	delete mStaticWitchMaps;
	delete lTankFlows;
	delete lWitchFlows;
	delete mapInfo;
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (L4D_IsVersusMode()) { return; }
	if (g_hEnableDirector.BoolValue) { setDirectorNoBossesCvar(false); }
	else { setDirectorNoBossesCvar(true); }
}

void setDirectorNoBossesCvar(bool set)
{
	int flag = GetCommandFlags("director_no_bosses");
	SetCommandFlags("director_no_bosses", flag & ~FCVAR_CHEAT);
	if (set) { ServerCommand("director_no_bosses 1"); }
	else { ServerCommand("director_no_bosses 0"); }
	SetCommandFlags("director_no_bosses", flag);
}

// 检查 readyUp 插件是否存在
// public void OnAllPluginsLoaded()
// {
// 	isReadyUpExist = LibraryExists("readyup");
// }
// public void OnLibraryRemoved(const char[] name)
// {
// 	if (strcmp(name, "readyup") == 0) { isReadyUpExist = false; }
// }
// public void OnLibraryAdded(const char[] name)
// {
// 	if (strcmp(name, "readyup") == 0) { isReadyUpExist = true; }
// }

// 指令
public Action Cmd_StaticTankMap(int args)
{
	char mapName[64] = {'\0'};
	GetCmdArg(1, mapName, sizeof(mapName));
	mStaticTankMaps.SetValue(mapName, true);
	#if (DEBUG_ALL)
	{
		LogMessage("[Boss-Controller]：已成功添加新的静态坦克地图：%s", mapName);
	}
	#endif
	return Plugin_Handled;
}
public Action Cmd_StaticWitchMap(int args)
{
	char mapName[64] = {'\0'};
	GetCmdArg(1, mapName, sizeof(mapName));
	mStaticWitchMaps.SetValue(mapName, true);
	#if (DEBUG_ALL)
	{
		LogMessage("[Boss-Controller]：已成功添加新的静态女巫地图：%s", mapName);
	}
	#endif
	return Plugin_Handled;
}
public Action Cmd_ResetStaticBossMap(int args)
{
	mStaticTankMaps.Clear();
	mStaticWitchMaps.Clear();
	return Plugin_Handled;
}
public Action Cmd_PrintBossPercent(int client, int args)
{
	if (client == 0) { PrintToServer("[Boss-Controller]：Boss 位置查询不能用于服务器控制台"); }
	if (IsValidClient(client)) { PrintBossPercent(TYPE_PLAYER, client); }
	return Plugin_Handled;
}
public Action Cmd_BossVote(int client, int args)
{
	if (!g_hCanVoteBoss.BoolValue || !IsValidClient(client) || !CheckCanVoteBoss(client)) { return Plugin_Handled; }
	if (args != 2)
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}使用 !bossvote {G}<Tank> <Witch> {W}更改 Boss 刷新路程");
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}参数为 0 则禁止刷新 Boss，-1 则插件不接管 Boss 刷新");
		return Plugin_Handled;
	}
	char tankFlow[8] = {'\0'}, witchFlow[8] = {'\0'}, bossVoteTitle[64] = {'\0'};
	GetCmdArg(1, tankFlow, sizeof(tankFlow));
	GetCmdArg(2, witchFlow, sizeof(witchFlow));
	if (!IsInteger(tankFlow) || !IsInteger(witchFlow))
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}请保证 Boss 刷新路程为整数路程");
		return Plugin_Handled;
	}
	tankActFlow = StringToInt(tankFlow);
	witchActFlow = StringToInt(witchFlow);
	#if (DEBUG_ALL)
	{
		LogMessage("[Boss-Controller]：路程是否有效：%b %b，是否允许更改 boss 位置：%b %b", IsValidTankFlow(tankActFlow), IsValidWitchFlow(witchActFlow), canSetTank, canSetWitch);
	}
	#endif
	if (IsStaticTankMap(curMapName))
	{
		canSetTank = false;
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：%s 为静态坦克地图，坦克刷新路程将不会更改", curMapName);
	}
	else
	{
		canSetTank = tankActFlow > 0 ? true : false;
	}
	if (IsStaticWitchMap(curMapName))
	{
		canSetWitch = false;
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：%s 为静态女巫地图，女巫刷新路程将不会更改", curMapName);
	}
	else
	{
		canSetWitch = witchActFlow > 0 ? true : false;
	}
	if ((!IsStaticTankMap(curMapName) && tankActFlow > 0 && !IsValidTankFlow(tankActFlow)) || (!IsStaticWitchMap(curMapName) && witchActFlow > 0 && !IsValidWitchFlow(witchActFlow)))
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}请保证 Tank 或 Witch 刷新路程有效");
		return Plugin_Handled;
	}
	// 设置投票标题
	if (canSetTank && canSetWitch)
	{
		if (tankActFlow > 0 && witchActFlow > 0)
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否将 Tank 刷新在：%s%%，Witch 刷新在：%s%%", tankFlow, witchFlow);
		}
		else
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否禁用本轮 TanK 与 Witch 刷新");
		}
	}
	else if (canSetTank)
	{
		if (witchActFlow == 0)
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否将 Tank 刷新在：%s%% 并禁用本轮 Witch 刷新", tankFlow);
		}
		else
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否将 Tank 刷新在：%s%%", tankFlow);
		}
	}
	else if (canSetWitch)
	{
		if (tankActFlow == 0)
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否禁用本轮 Tank 刷新并将 Witch 刷新在：%s%%", witchFlow);
		}
		else
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否将 Witch 刷新在：%s%%", witchFlow);
		}
	}
	else
	{
		if (tankActFlow == 0 && witchActFlow == 0)
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否禁用本轮 Tank 和 Witch 刷新");
		}
		else if (tankActFlow == 0)
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否禁用本轮 Tank 刷新");
		}
		else if (witchActFlow == 0)
		{
			FormatEx(bossVoteTitle, sizeof(bossVoteTitle), "是否禁用本轮 Witch 刷新");
		}
		else
		{
			return Plugin_Handled;
		}
	}
	// 设置投票句柄
	if (!IsBuiltinVoteInProgress())
	{
		int playerNum = 0;
		int[] players = new int[MaxClients];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsFakeClient(i))
			{
				players[playerNum++] = i;
			}
		}
		Handle bossVoteHandler = CreateBuiltinVote(BossVote_Handler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(bossVoteHandler, bossVoteTitle);
		SetBuiltinVoteInitiator(bossVoteHandler, client);
		DisplayBuiltinVote(bossVoteHandler, players, playerNum, MENU_DISPLAY_TIME);
		FakeClientCommand(client, "Vote Yes");
		CPrintToChatAll("{B}<{G}BossVote{B}>：{G}玩家 {O}%N {G}发起了一个设置 Boss 刷新路程的投票", client);
	}
	else
	{
		CPrintToChatAll("{B}<{G}BossVote{B}>：{G}当前有一个投票正在进行，无法进行新的投票");
	}
	return Plugin_Continue;
}
public int BossVote_Handler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		/* 投票通过 */
		case BuiltinVoteAction_VoteEnd:
		{
			if (param1 == BUILTINVOTES_VOTE_YES)
			{
				char buffer[64] = {'\0'};
				/* 设置投票通过结果 */
				/* if (!IsInReady())
				{
					FormatEx(buffer, sizeof(buffer), "只允许在准备期间更改 Boss 刷新位置");
					DisplayBuiltinVoteFail(vote, buffer);
					return 0;
				} */
				if (canSetTank && canSetWitch)
				{
					FormatEx(buffer, sizeof(buffer), "正在更改 Boss 刷新路程...");
					DisplayBuiltinVotePass(vote, buffer);
				}
				else if (canSetTank)
				{
					FormatEx(buffer, sizeof(buffer), "正在更改 Tank 刷新路程...");
					DisplayBuiltinVotePass(vote, buffer);
				}
				else if (canSetWitch)
				{
					FormatEx(buffer, sizeof(buffer), "正在更改 Witch 刷新路程...");
					DisplayBuiltinVotePass(vote, buffer);
				}
				else
				{
					FormatEx(buffer, sizeof(buffer), "正在禁用本轮 Boss 刷新...");
					DisplayBuiltinVotePass(vote, buffer);
				}
				/* 更改 Boss 刷新路程 */
				SetTankPercent(tankActFlow);
				SetWitchPercent(witchActFlow);
				nowTankFlow = tankActFlow;
				nowWitchFlow = witchActFlow;
				if (tankActFlow == 0) { g_hTankCanSpawn.BoolValue = false; }
				if (witchActFlow == 0) { g_hWitchCanSpawn.BoolValue = false; }
				/* UpdateBossPercents(); */
				Call_StartForward(fUpdateBoss);
				Call_PushCell(tankActFlow);
				Call_PushCell(witchActFlow);
				Call_Finish();
			}
			else if (param1 == BUILTINVOTES_VOTE_NO)
			{
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
			}
			else
			{
				DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
			}
		}
		/* 投票被取消 */
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
		/* 投票结束，删除 vote 句柄 */
		case BuiltinVoteAction_End:
		{
			delete vote;
			vote = null;
		}
	}
	return 0;
}
// 管理员更改坦克女巫刷新位置
public Action Cmd_ForceTank(int client, int args)
{
	if (!g_hCanVoteBoss.BoolValue)
	{
		return Plugin_Handled;
	}
	else if (isDKR)
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：{O}%s {W}不允许投票更改 Boss 刷新路程", curMapName);
		return Plugin_Handled;
	}
	else if (IsStaticTankMap(curMapName))
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：%s 为静态坦克地图，插件不接管坦克刷新，无法投票更改坦克刷新路程", curMapName);
		return Plugin_Handled;
	}
	else if (spawnedTank)
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}本轮坦克已经刷新完成，无法再次更改坦克刷新路程");
		return Plugin_Handled;
	}
	/* else if (!IsInReady())
	{
		CPrintToChatAll("{B}<{G}BossVote{B}>：{W}只能在准备期间投票更改 Boss 位置");
		return Plugin_Handled;
	} */
	char tankFlow[32] = {'\0'};
	GetCmdArg(1, tankFlow, sizeof(tankFlow));
	if (!IsInteger(tankFlow))
	{
		return Plugin_Handled;
	}
	int tankNewFlow = StringToInt(tankFlow);
	if (tankNewFlow < 0)
	{
		CPrintToChatAll("{B}<{G}BossVote{B}>：{W}新的坦克刷新路程必须大于等于 0");
		return Plugin_Handled;
	}
	else if (!IsValidTankFlow(tankNewFlow))
	{
		CPrintToChatAll("{B}<{G}BossVote{B}>：{W}当前坦克刷新路程：{O}%d {B}已被禁止", tankNewFlow);
		return Plugin_Handled;
	}
	SetTankPercent(tankNewFlow);
	tankActFlow = nowTankFlow = tankNewFlow;
	CPrintToChatAll("{B}<{G}BossVote{B}>：{G}管理员：{O}%N {W}更改本轮坦克刷新路程为：{O}%d", client, tankNewFlow);
	/* UpdateBossPercents(); */
	Call_StartForward(fUpdateBoss);
	Call_PushCell(tankNewFlow);
	Call_PushCell(-1);
	Call_Finish();
	return Plugin_Continue;
}
public Action Cmd_ForceWitch(int client, int args)
{
	if (!g_hCanVoteBoss.BoolValue)
	{
		return Plugin_Handled;
	}
	else if (isDKR)
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：{O}%s {W}不允许投票更改 Boss 刷新路程", curMapName);
		return Plugin_Handled;
	}
	else if (IsStaticWitchMap(curMapName))
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：%s 为静态女巫地图，插件不接管女巫刷新，无法投票更改女巫刷新路程", curMapName);
		return Plugin_Handled;
	}
	else if (spawnedWitch)
	{
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}本轮女巫已经刷新完成，无法再次更改女巫刷新路程");
		return Plugin_Handled;
	}
	/* else if (!IsInReady())
	{
		CPrintToChatAll("{B}<{G}BossVote{B}>：{W}只能在准备期间投票更改 Boss 位置");
		return Plugin_Handled;
	} */
	char witchFlow[32] = {'\0'};
	GetCmdArg(1, witchFlow, sizeof(witchFlow));
	if (!IsInteger(witchFlow))
	{
		return Plugin_Handled;
	}
	int witchNewFlow = StringToInt(witchFlow);
	if (witchNewFlow < 0)
	{
		CPrintToChatAll("{B}<{G}BossVote{B}>：{W}新的女巫刷新路程必须大于等于 0");
		return Plugin_Handled;
	}
	else if (!IsValidWitchFlow(witchNewFlow))
	{
		CPrintToChatAll("{B}<{G}BossVote{B}>：{W}当前女巫刷新路程：{O}%d {B}已被禁止", witchNewFlow);
		return Plugin_Handled;
	}
	SetWitchPercent(witchNewFlow);
	witchActFlow = nowWitchFlow = witchNewFlow;
	CPrintToChatAll("{B}<{G}BossVote{B}>：{G}管理员：{O}%N {W}更改本轮女巫刷新路程为：{O}%d", client, witchNewFlow);
	/* UpdateBossPercents(); */
	Call_StartForward(fUpdateBoss);
	Call_PushCell(-1);
	Call_PushCell(witchNewFlow);
	Call_Finish();
	return Plugin_Continue;
}

public void OnMapStart()
{
	// delete 会先进行是否为 null 检测，可直接使用 delete 删除时钟句柄
	delete bossTimer;
	GetCurrentMap(curMapName, sizeof(curMapName));
	isDKR = IsDKR(); isFinale = isFinaleMap();
	isLeftSafeArea = spawnedTank = spawnedWitch = false;
	tankIndex = witchIndex = -1;
	ZeroVector(tankSpawnPos);
	ZeroVector(witchSpawnPos);
	if (L4D_IsVersusMode())
	{
		setDirectorNoBossesCvar(false);
		return;
	}
	// 非对抗模式下，且非静态 Boss 地图，接管 director_no_bosses
	if (!g_hEnableDirector.BoolValue && !IsStaticTankMap(curMapName) && !IsStaticWitchMap(curMapName)
		&& ((!g_hDisableInFinale.BoolValue && isFinale) || !isFinale))
	{
		log.info("%s: 非对抗模式, 非终局, 非静态地图, 接管导演模式", PLUGIN_PREFIX);
		setDirectorNoBossesCvar(true);
	}
	// 非对抗模式下，是静态坦克地图或女巫地图，设置 director_no_bosses 为 0，允许刷新 boss，不允许刷新的则刷出来处死
	if (IsStaticTankMap(curMapName) || IsStaticWitchMap(curMapName) || (g_hDisableInFinale.BoolValue && isFinale))
	{
		log.info("%s: 非对抗模式, 非终局, 是静态地图, 不接管导演模式", PLUGIN_PREFIX);
		setDirectorNoBossesCvar(false);
	}
}
public void OnMapEnd()
{
	versusFirstTankFlow = versusFirstWitchFlow = nowTankFlow = nowWitchFlow = 0;
	// dkrFirstTankFlow = dkrFirstWitchFlow = 0;
	// 每局结束，设置插件允许 boss 刷新
	g_hTankCanSpawn.BoolValue = g_hWitchCanSpawn.BoolValue = true;
}
public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	// isReadyUpAdded = false;
	// readyUpIndex = -1;
	delete bossTimer;
	isLeftSafeArea = spawnedTank = spawnedWitch = false;
	nowTankFlow = nowWitchFlow = survivorPrompDist = 0;
	ZeroVector(tankSpawnPos);
	ZeroVector(witchSpawnPos);
	tankIndex = witchIndex = -1;
	isFinale = isFinaleMap();
	
	/* 如果是终局，开启插件不接管，则不接管刷新 boss */
	if (g_hDisableInFinale.BoolValue && isFinale) { return; }
	
	CreateTimer(0.5, Timer_GetBossFlow);
	
	/* 更新 RedyUp 面板 */
	// UpdateReadyUpFooter(6.0);
}
public void evt_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_hProhibitNonPluginBoss.BoolValue) { return; }
	if (IsStaticTankMap(curMapName)) { return; }
	if (L4D_IsVersusMode()) { return; }
	int tank = event.GetInt("userid");
	if (!IsFakeClient(GetClientOfUserId(tank))) {
		return;
	}
	CreateTimer(0.5, checkKickTank, tank, _);
}
public void evt_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_hProhibitNonPluginBoss.BoolValue) { return; }
	if (IsStaticWitchMap(curMapName)) { return; }
	if (L4D_IsVersusMode()) { return; }
	int witch = event.GetInt("witchid");
	CreateTimer(0.5, checkKickWitch, witch, _);
}
public Action checkKickTank(Handle timer, int tank)
{
	int client = GetClientOfUserId(tank);
	if (GetInfectedClass(client) != ZC_TANK || !IsPlayerAlive(client)) { return Plugin_Continue; }
	if ((tankIndex == -1 || tank != tankIndex) && !IsClientInKickQueue(client)) {
		log.info("%s: 非插件刷出的 AI Tank: %N (%d), 插件 TankIndex: %d, 已踢出", PLUGIN_PREFIX, client, tank, tankIndex);
		KickClientEx(client);
	}
	return Plugin_Continue;
}
public Action checkKickWitch(Handle timer, int witch)
{
	if (!IsValidEntity(witch) || !IsValidEdict(witch)) { return Plugin_Continue; }
	if (witchIndex == -1 || EntIndexToEntRef(witch) != witchIndex)
	{
		AcceptEntityInput(witch, "kill");
		RemoveEdict(witch);
	}
	return Plugin_Continue;
}

public Action Timer_GetBossFlow(Handle timer)
{
	// 对抗第二轮，不允许获取新的 Boss 刷新路程
	if (InVersusSecondRound()) {
		return Plugin_Stop;
	}
	int i, interval[2];
	bool canSpawnTank, canSpawnWitch;

	lTankFlows.Clear();
	lWitchFlows.Clear();
	// 获取设定 Boss 刷新范围
	minFlow = RoundToCeil(g_hVsBossFlowMin.FloatValue * 100.0);
	maxFlow = RoundToFloor(g_hVsBossFlowMax.FloatValue * 100.0);

	// 检查是否有 mapinfo 文件，没有则使用 Cvar min 和 max 设定值
	if (mapInfo != null)
	{
		// 具有 mapinfo 文件，使用 mapinfo 中的信息覆盖 Boss 刷新范围
		minFlow = KvGetNum(mapInfo, "versus_boss_flow_min", minFlow);
		maxFlow = KvGetNum(mapInfo, "versus_boss_flow_max", maxFlow);
		// 统一设置 minFlow 和 maxFlow
		for (i = minFlow; i <= maxFlow; i++) {
			lTankFlows.Push(i);
			lWitchFlows.Push(i);
		}
		log.info("%s: 调整 Boss 刷新范围 [%d%% - %d%%]", PLUGIN_PREFIX, minFlow, maxFlow);
		log.info("%s: Tank 位置集合长度 %d, Witch 位置集合长度 %d", PLUGIN_PREFIX, lTankFlows.Length, lWitchFlows.Length);

		// 有 mapinfo 文件且允许刷新坦克，且不是静态坦克地图，可以随机一个坦克位置
		if (g_hTankCanSpawn.BoolValue && !IsStaticTankMap(curMapName)) {
			// 可以投票设置坦克位置
			canSetTank = true;
			// 如果当前 mapinfo 文件存在当前地图的文件，则跳转到当前地图，读取 tankBanFlow
			if (mapInfo.JumpToKey(curMapName)) {
				// 读取 mapinfo 文件中的 tank ban flow 路程，MapInfo -> currentMap -> tankBanFlow -> 遍历下面的所有 min 和 max
				if (mapInfo.JumpToKey("tank_ban_flow") && mapInfo.GotoFirstSubKey()) {
					do {
						interval[0] = mapInfo.GetNum("min", -1);
						interval[1] = mapInfo.GetNum("max", -1);
						log.info("%s: 禁止刷新 Tank 路程 [%d - %d]", PLUGIN_PREFIX, interval[0], interval[1]);
						// 禁止刷新距离有效，则将这个距离加入到集合中
						if (IsValidInterval(interval)) {
							deleteInterval(lTankFlows, interval);
						}
					} while (mapInfo.GotoNextKey());
				}
				// -> mapInfo
				mapInfo.Rewind();
			}
			// 检查允许刷新集合中所有元素是否都为 -1 禁止刷新标识
			if (lTankFlows.Length >= 1) {
				canSpawnTank = true;
			}
			if (!canSpawnTank) {
				nowTankFlow = 0;
				SetTankPercent(0);
				log.info("%s: Tank 位置集合长度 %d, 不允许随机 Tank 位置", PLUGIN_PREFIX, lTankFlows.Length);
			} else {
				// 允许刷克，随机一个坦克刷新位置
				nowTankFlow = GetRandomSpawnPos(lTankFlows);
				log.info("%s: 随机 Tank 位置 %d%%", PLUGIN_PREFIX, nowTankFlow);
				// 开启对抗模式刷新对齐，则记录第一轮刷新位置，第二轮时将更改为第一轮刷新位置
				if (g_hVersusConsist.BoolValue) {
					if (!InVersusSecondRound()) {
						versusFirstTankFlow = nowTankFlow;
						SetTankPercent(nowTankFlow);
					} else {
						nowTankFlow = versusFirstTankFlow;
						SetTankPercent(versusFirstTankFlow);
						log.info("%s: 对抗模式第二轮, 设置 Tank 刷新位置与第一轮相同 %d%%", PLUGIN_PREFIX, versusFirstTankFlow);
					}
				} else {
					SetTankPercent(nowTankFlow);
				}
			}
		} else {
			// 是静态坦克地图，插件不接管刷克
			nowTankFlow = 0;
			SetTankPercent(0);
			log.info("%s: 当前地图 %s 是静态 Tank 地图, 不允许随机 Tank 位置", PLUGIN_PREFIX, curMapName);
		}
		// 检查当前地图是否为静态女巫地图，不是，则随机一个女巫刷新位置
		if (g_hWitchCanSpawn.BoolValue && !IsStaticWitchMap(curMapName))
		{
			// 可以投票设置女巫位置
			canSetWitch = true;
			if (mapInfo.JumpToKey(curMapName)) {
				if (mapInfo.JumpToKey("witch_ban_flow") && mapInfo.GotoFirstSubKey()) {
					do {
						interval[0] = mapInfo.GetNum("min", -1);
						interval[1] = mapInfo.GetNum("max", -1);
						log.info("%s: 禁止刷新 Witch 路程 [%d - %d]", PLUGIN_PREFIX, interval[0], interval[1]);
						if (IsValidInterval(interval)) {
							deleteInterval(lWitchFlows, interval);
						}
					} while (mapInfo.GotoNextKey());
				}
				mapInfo.Rewind();
			}
			// Witch 间隔 Tank 一定路程刷新
			if (g_hWitchAvoidTank.IntValue > 0 && GetTankAvoidInterval(interval)) {
				deleteInterval(lWitchFlows, interval);
			}
			if (lWitchFlows.Length >= 1) {
				canSpawnWitch = true;
			}
			// 此时女巫集合长度为 100，未删除 -1 元素，无需判断长度是否小于 g_hWitchAvoidTank.IntValue
			if (!canSpawnWitch) {
				nowWitchFlow = 0;
				SetWitchPercent(0);
				log.info("%s: Witch 位置集合长度 %d, 不允许随机 Witch 位置", PLUGIN_PREFIX, lWitchFlows.Length);
			} else {
				nowWitchFlow = GetRandomSpawnPos(lWitchFlows);
				log.info("%s: 随机 Witch 位置 %d%%", PLUGIN_PREFIX, nowWitchFlow);
				// 非对抗第二轮，且开启 g_hVersusConsist 情况，记录第一轮刷新位置
				if (g_hVersusConsist.BoolValue) {
					if (!InVersusSecondRound()) {
						versusFirstWitchFlow = nowWitchFlow;
						SetWitchPercent(nowWitchFlow);
					} else {
						nowWitchFlow = versusFirstWitchFlow;
						SetWitchPercent(versusFirstWitchFlow);
						log.info("%s: 对抗模式第二轮, 设置 Witch 刷新位置与第一轮相同 %d%%", PLUGIN_PREFIX, versusFirstWitchFlow);
					}
				} else {
					SetWitchPercent(nowWitchFlow);
				}
			}
		} else {
			nowWitchFlow = 0;
			SetWitchPercent(0);
			log.info("%s: 当前地图 %s 是静态 Witch 地图, 不允许随机 Witch 位置", PLUGIN_PREFIX, curMapName);
		}
		return Plugin_Stop;
	}

	// 没有 mapInfo 文件，设置坦克女巫允许调整为 true
	canSetTank = canSetWitch = true;
	for (i = minFlow; i <= maxFlow; i++) {
		lTankFlows.Push(i);
		lWitchFlows.Push(i);
	}
	nowTankFlow = GetRandomSpawnPos(lTankFlows);
	if (g_hWitchAvoidTank.IntValue > 0 && GetTankAvoidInterval(interval)) {
		deleteInterval(lWitchFlows, interval);
	}
	nowWitchFlow = GetRandomSpawnPos(lWitchFlows);
	if (g_hTankCanSpawn.BoolValue && !IsStaticTankMap(curMapName)) {
		if (lTankFlows.Length >= 1) {
			canSpawnTank = true;
		}
		if (!canSpawnTank) {
			nowTankFlow = 0;
			lTankFlows.Clear();
			log.info("%s: Tank 位置集合长度 %d, 不允许随机 Tank 位置", PLUGIN_PREFIX, lTankFlows.Length);
		} else {
			if (L4D_IsVersusMode()) {
				if (g_hVersusConsist.BoolValue) {
					if (!InVersusSecondRound()) {
						versusFirstTankFlow = nowTankFlow;
						SetTankPercent(nowTankFlow);
						log.info("%s: 当前没有 mapinfo 文件, 随机 Tank 位置: %d%%", PLUGIN_PREFIX, nowTankFlow);
					} else {
						nowTankFlow = versusFirstTankFlow;
						SetTankPercent(versusFirstTankFlow);
						log.info("%s: 对抗模式第二轮, 设置 Tank 刷新位置与第一轮相同 %d%%, %d%%", versusFirstTankFlow);
					}
				} else {
					SetTankPercent(nowTankFlow);
				}
			}
		}
	} else {
		nowTankFlow = 0;
		lTankFlows.Clear();
		log.info("%s: 当前地图 %s 是静态 Tank 地图, 不允许随机 Tank 位置", PLUGIN_PREFIX, curMapName);
	}
	if (g_hWitchCanSpawn.BoolValue && !IsStaticWitchMap(curMapName)) {
		if (lWitchFlows.Length >= 1) {
			canSpawnWitch = true;
		}
		if (!canSpawnWitch) {
			nowWitchFlow = 0;
			lWitchFlows.Clear();
			log.info("%s: Witch 位置集合长度 %d, 不允许随机 Witch 位置", PLUGIN_PREFIX, lWitchFlows.Length);
		} else {
			if (L4D_IsVersusMode()) {
				if (g_hVersusConsist.BoolValue) {
					if (!InVersusSecondRound()) {
						versusFirstWitchFlow = nowWitchFlow;
						SetTankPercent(nowWitchFlow);
						log.info("%s: 当前没有 mapinfo 文件, 随机 Witch 位置: %d%%", PLUGIN_PREFIX, nowWitchFlow);
					} else {
						nowWitchFlow = versusFirstWitchFlow;
						SetTankPercent(versusFirstWitchFlow);
						log.info("%s: 对抗模式第二轮, 设置 Witch 刷新位置与第一轮相同 %d%%, %d%%", PLUGIN_PREFIX, versusFirstWitchFlow);
					}
				} else {
					SetTankPercent(nowWitchFlow);
				}
			}
		}
	} else {
		nowWitchFlow = 0;
		lWitchFlows.Clear();
		log.info("%s: 当前地图 %s 是静态 Witch 地图, 不允许随机 Witch 位置", PLUGIN_PREFIX, curMapName);
	}
	return Plugin_Continue;
}

void deleteInterval(ArrayList list, int interval[2]) {
	if (list == null) {
		return;
	}
	int index;
	for (int i = interval[0]; i <= interval[1]; i++) {
		if ((index = list.FindValue(i)) <= 0) {
			continue;
		}
		list.Erase(index);
	}
}

// 在坦克刷新位置发生变化的时候，此时 tankFlow 有效，动态调整女巫刷新位置
void DynamicAdjustWtichPercent(int tankFlow)
{
	if (!g_hWitchCanSpawn.BoolValue) {
		return;
	}

	int i, interval[2], witchFlow;
	if (!GetTankAvoidInterval(interval)) {
		return;
	}
	if (!IsValidInterval(interval)) {
		return;
	}
	// 恢复之前的禁止 Witch 刷新路程
	for (i = interval[0]; i <= interval[1]; i++) {
		lWitchFlows.Push(i);
	}
	lWitchFlows.Sort(Sort_Ascending, Sort_Integer);
	// 计算新的 Witch 禁止刷新路程
	interval[0] = RoundToFloor(tankFlow - (g_hWitchAvoidTank.FloatValue / 2.0));
	interval[1] = RoundToCeil(tankFlow + (g_hWitchAvoidTank.FloatValue / 2.0));
	log.info("%s: Tank 刷新调整为 %d%%, 新的禁止 Witch 刷新范围 [%d%% - %d%%]", PLUGIN_PREFIX, interval[0], interval[1]);
	deleteInterval(lWitchFlows, interval);
	
	if (lWitchFlows.Length <= 1) {
		nowWitchFlow = 0;
		SetWitchPercent(0);
		log.info("%s: 动态调整 Witch 刷新范围后 Witch 位置集合长度 %d, 禁止刷新 Witch", PLUGIN_PREFIX, lWitchFlows.Length);
	} else {
		witchFlow = nowWitchFlow;
		if (L4D_IsVersusMode()) {
			witchFlow = RoundFloat(L4D2Direct_GetVSWitchFlowPercent(0) * 100.0);
		}
		if (witchFlow >= interval[0] && witchFlow <= interval[1]) {
			if (!IsValidWitchFlow((witchFlow = interval[1] + 1)) && !IsValidWitchFlow((witchFlow = interval[0] - 1))) {
				witchFlow = GetRandomSpawnPos(lWitchFlows);
			}
		}
		log.info("%s: 动态调整 Witch 刷新路程 %d%%, Witch 位置路程集合长度 %d", PLUGIN_PREFIX, witchFlow, lWitchFlows.Length);
		nowWitchFlow = witchFlow;
		SetWitchPercent(witchFlow);
	}
}

// 生还者离开安全区域后，如果不是对抗模式，则创建时钟检测生还者路程
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	delete bossTimer;
	bossTimer = CreateTimer(0.5, Timer_SpawnBoss, _, TIMER_REPEAT);
	PrintBossPercent(TYPE_ALL);
	isLeftSafeArea = true;
	// if (!isReadyUpExist && !InVersusSecondRound())
	// {
	// 	dkrFirstTankFlow = nowTankFlow;
	// 	dkrFirstWitchFlow = nowWitchFlow;
	// }
	return Plugin_Continue;
}
// 战役模式下刷新 boss
public Action Timer_SpawnBoss(Handle timer) {
	int flow = GetSurvivorFlowZone();
	// 对抗模式，超过路程就算已经刷新
	if (L4D_GetGameModeType() == GAMEMODE_VERSUS) {
		if (flow >= nowTankFlow) {
			spawnedTank = true;
		}
		if (flow >= nowWitchFlow) {
			spawnedWitch = true;
		}
	}
	// 开启提示
	if (g_hEnablePrompt.BoolValue) {
		int tankPrompt = nowTankFlow - g_hPromptDist.IntValue,
			witchPrompt = nowWitchFlow - g_hPromptDist.IntValue;
		if (flow >= tankPrompt && flow < nowTankFlow && flow >= survivorPrompDist) {
			CPrintToChatAll("{R}<Boss>: {W}当前 {G}%d%%, {R}Tank {W}将于 {R}%d%% {W}刷新", flow, nowTankFlow);
			survivorPrompDist = flow + 1;
		}
		if (flow >= witchPrompt && flow < nowWitchFlow && flow >= survivorPrompDist) {
			CPrintToChatAll("{R}<Boss>: {W}当前 {G}%d%%, {R}Witch {W}将于 {R}%d%% {W}刷新", flow, nowWitchFlow);
			survivorPrompDist = flow + 1;
		}
	}
	// 不是战役，不接管刷新
	if (L4D_GetGameModeType() != GAMEMODE_COOP) {
		return Plugin_Continue;
	}
	// log.debugAll("%s: 战役模式, Tank: %d%%, Witch: %d%%, Current: %d%%", PLUGIN_PREFIX, nowTankFlow, nowWitchFlow, flow);
	// 战役模式下刷新 boss
	if (flow >= nowTankFlow && !spawnedTank) {
		SpawnBoss(ZC_TANK);
	}
	if (flow >= nowWitchFlow && !spawnedWitch) {
		SpawnBoss(ZC_WITCH);
	}
	return Plugin_Continue;
}
void SpawnBoss(int class)
{
	if (class != ZC_TANK && class != ZC_WITCH) {
		return;
	}

	int i, target;
	float pos[3];
	bool success;
	for (i = 0; i < SPAWN_ATTEMPT; i++)
	{
		target = L4D_GetHighestFlowSurvivor();
		if (!IsValidSurvivor(target) || !IsPlayerAlive(target)) {
			continue;
		}
		// log.info("%s: 最高路程玩家: %N, 已刷新: %s", PLUGIN_PREFIX, target, class == ZC_TANK ? "Tank" : "Witch");
		if (L4D_GetRandomPZSpawnPosition(target, class, SPAWN_ATTEMPT, pos)) {
			success = true;
			break;
		}
	}
	if (!success) {
		log.info("%s: 无法在 %d 次内找到有效 %s 刷新位置", PLUGIN_PREFIX, SPAWN_ATTEMPT, class == ZC_TANK ? "Tank" : "Witch");
		return;
	}

	if (class == ZC_TANK)
	{
		int tankId = L4D2_SpawnTank(pos, NULL_VECTOR);
		if (!IsValidEntity(tankId) || !IsValidEdict(tankId)) {
			return;
		}
		spawnedTank = true;
		tankIndex = GetClientUserId(tankId);
		survivorPrompDist = nowTankFlow;
		log.info("%s: 已在 [%.2f, %.2f, %.2f] 处刷新 Tank: %d", PLUGIN_PREFIX, pos[0], pos[1], pos[2], tankId);
	}
	if (class == ZC_WITCH) {
		int witchId = L4D2_SpawnWitch(pos, NULL_VECTOR);
		if (!IsValidEntity(witchId) || !IsValidEdict(witchId)) {
			return;
		}
		spawnedWitch = true;
		witchIndex = EntIndexToEntRef(witchId);
		survivorPrompDist = nowWitchFlow;
		log.info("%s: 已在 [%.2f, %.2f, %.2f] 处刷新 Witch: %d", PLUGIN_PREFIX, pos[0], pos[1], pos[2], witchId);
	}
}

void PrintBossPercent(int type, int client = -1)
{
	char tankStr[64], witchStr[64];
	// 固定地图
	if (IsStaticTankMap(curMapName) || (g_hDisableInFinale.BoolValue && isFinale)) {
		FormatEx(tankStr, sizeof(tankStr), "{R}<Tank>: {O}Static");
	}
	if (IsStaticWitchMap(curMapName) || (g_hDisableInFinale.BoolValue && isFinale)) {
		FormatEx(witchStr, sizeof(witchStr), "{R}Witch: {O}Static");
	}
	// 禁止刷新
	if (!g_hTankCanSpawn.BoolValue || nowTankFlow <= 0) {
		FormatEx(tankStr, sizeof(tankStr), "{R}<Tank>: {O}None");
	}
	if (!g_hWitchCanSpawn.BoolValue || nowWitchFlow <= 0) {
		FormatEx(witchStr, sizeof(witchStr), "{R}<Witch>: {O}None");
	}
	// 正常刷新
	FormatEx(tankStr, sizeof(tankStr), "{R}<Tank>: {O}%d%% {W}(%s)", nowTankFlow, spawnedTank ? "✓" : "✕");
	FormatEx(witchStr, sizeof(witchStr), "{R}<Witch>: {O}%d%% {W}(%s)", nowWitchFlow, spawnedWitch ? "✓" : "✕");

	// 整合字符串
	if (g_hTankCanSpawn.BoolValue && !g_hWitchCanSpawn.BoolValue) {
		if (type == TYPE_PLAYER && IsValidClient(client)) {
			CPrintToChat(client, "{O}Current: {W}%d%%", GetSurvivorFlowZone());
			CPrintToChat(client, "%s", tankStr);
		} else {
			CPrintToChatAll("{O}Current: {W}%d%%", GetSurvivorFlowZone());
			CPrintToChatAll("%s", tankStr);
		}
	} else if (!g_hTankCanSpawn.BoolValue && g_hWitchCanSpawn.BoolValue) {
		if (type == TYPE_PLAYER && IsValidClient(client)) {
			CPrintToChat(client, "{O}Current: {W}%d%%", GetSurvivorFlowZone());
			CPrintToChat(client, "%s", witchStr);
		} else {
			CPrintToChatAll("{O}Current: {W}%d%%", GetSurvivorFlowZone());
			CPrintToChatAll("%s", witchStr);
		}
	} else {
		if (type == TYPE_PLAYER && IsValidClient(client)) {
			CPrintToChat(client, "{O}Current: {W}%d%%", GetSurvivorFlowZone());
			CPrintToChat(client, "%s", tankStr);
			CPrintToChat(client, "%s", witchStr);
		} else {
			CPrintToChatAll("{O}Current: {W}%d%%", GetSurvivorFlowZone());
			CPrintToChatAll("%s", tankStr);
			CPrintToChatAll("%s", witchStr);
		}
	}
}
// 判断是否可以进行 boss 投票
bool CheckCanVoteBoss(int client)
{
	if (!IsValidClient(client)) {
		return false;
	}
	if (isDKR) {
		CPrintToChat(client, "{B}<{G}BossVote{B}>: {W}当前地图 {O}%s {W}不允许投票更改 Boss 刷新路程", curMapName);
		return false;
	}
	if (isLeftSafeArea) {
		CPrintToChat(client, "{B}<{G}BossVote{B}>: {W}只允许在安全区域内投票更改 Boss 刷新路程");
		return false;
	}
	if (g_hDisableInFinale.BoolValue && isFinale) {
		CPrintToChat(client, "{B}<{G}BossVote{B}>: {W}当前是终局且插件不接管 Boss 刷新, 无法投票");
		return false;
	}
	// if (isReadyUpExist && !IsInReady()) {
	// 	CPrintToChat(client, "{B}<{G}BossVote{B}>: {W}只能在准备期间投票更改 Boss 刷新路程");
	// 	return false;
	// }
	if (InVersusSecondRound()) {
		CPrintToChat(client, "{B}<{G}BossVote{B}>: {W}当前是对抗第二轮，不允许投票更改 Boss 刷新路程");
		return false;
	}
	if (GetClientTeam(client) == TEAM_SPECTATOR) {
		CPrintToChat(client, "{B}<{G}BossVote{B}>: {W}旁观者不允许投票更改 Boss 刷新路程");
		return false;
	}
	if (!IsNewBuiltinVoteAllowed()) {
		CPrintToChat(client, "{B}<{G}BossVote{B}>: {W}当前不允许发起新的投票更改 Boss 刷新路程");
		return false;
	}
	return true;
}

// 方法
bool IsStaticTankMap(const char[] mapName)
{
	return mStaticTankMaps.ContainsKey(mapName);
}
bool IsStaticWitchMap(const char[] mapName)
{
	return mStaticWitchMaps.ContainsKey(mapName);
}
// 是否有效禁止刷新路程，最小路程要大于 -1 且最大路程大于等于最小路程，则有效
bool IsValidInterval(int interval[2])
{
	return interval[0] > -1 && interval[0] <= 100 && interval[1] >= interval[0] && interval[1] <= 100;
}
// 设置坦克刷新位置
void SetTankPercent(int percent)
{
	if (percent == 0)
	{
		L4D2Direct_SetVSTankFlowPercent(0, 0.0);
		L4D2Direct_SetVSTankFlowPercent(1, 0.0);
		L4D2Direct_SetVSTankToSpawnThisRound(0, false);
		L4D2Direct_SetVSTankToSpawnThisRound(1, false);
	}
	else
	{
		float newPercent = (float(percent) / 100.0);
		L4D2Direct_SetVSTankFlowPercent(0, newPercent);
		L4D2Direct_SetVSTankFlowPercent(1, newPercent);
		L4D2Direct_SetVSTankToSpawnThisRound(0, true);
		L4D2Direct_SetVSTankToSpawnThisRound(1, true);
	}
}
// 设置女巫刷新位置
void SetWitchPercent(int percent) {
	if (percent == 0)
	{
		L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
		L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	}
	else
	{
		float newPercent = (float(percent) / 100);
		L4D2Direct_SetVSWitchFlowPercent(0, newPercent);
		L4D2Direct_SetVSWitchFlowPercent(1, newPercent);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	}
}
bool GetTankAvoidInterval(int interval[2])
{
	if (g_hWitchAvoidTank.IntValue == 0.0){
		return false;
	}
	float flow = L4D2Direct_GetVSTankFlowPercent(0);
	if (flow == 0.0) {
		return false;
	}

	interval[0] = RoundToFloor((flow * 100.0) - (g_hWitchAvoidTank.FloatValue / 2.0));
	interval[1] = RoundToCeil((flow * 100.0) + (g_hWitchAvoidTank.FloatValue / 2.0));
	return true;
}
// 随机刷新位置
int GetRandomSpawnPos(ArrayList arr)
{
	return arr.Get(GetURandomIntInRange(0, arr.Length - 1));
}
// GetRandomInt 会有约 4% 误差，不是等概率随机数发生器，这种方法可以将误差降低到 2% 左右
int GetURandomIntInRange(int min, int max)
{
	int random = GetURandomInt();
	if (random == 0) {
		random++;
	}
	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}
bool IsValidTankFlow(int flow)
{
	if (flow == 0) {
		return true;
	}
	if (lTankFlows.Length < 1) {
		return false;
	}
	return lTankFlows.FindValue(flow) >= 0;
}
bool IsValidWitchFlow(int flow)
{
	if (flow == 0) {
		return true;
	}
	if (lWitchFlows.Length < 1) {
		return false;
	}
	return lWitchFlows.FindValue(flow) >= 0;
}

// Boss 刷新控制
public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
	return g_hTankCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}
public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3])
{
	return g_hWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}
public Action L4D2_OnSpawnWitchBride(const float vecPos[3], const float vecAng[3])
{
	return g_hWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

// 提供 Native
public int Native_IsStaticTankMap(Handle plugins, int numParams)
{
	char mapName[64] = {'\0'};
	GetNativeString(1, mapName, sizeof(mapName));
	return IsStaticTankMap(mapName);
}
public int Native_IsStaticWitchMap(Handle plugins, int numParams)
{
	char mapName[64] = {'\0'};
	GetNativeString(1, mapName, sizeof(mapName));
	return IsStaticWitchMap(mapName);
}
public int Native_SetTankPercent(Handle plugin, int numParams)
{
	int flow = GetNativeCell(1);
	if (flow >= 0 && lTankFlows.Length > 0 && flow >= lTankFlows.Get(0) && flow <= lTankFlows.Get(lTankFlows.Length - 1))
	{
		DynamicAdjustWtichPercent(flow);
		SetTankPercent(flow);
		return true;
	}
	return false;
}
public int Native_SetWitchPercent(Handle plugin, int numParams)
{
	int flow = GetNativeCell(1);
	if (flow >= 0 && lWitchFlows.Length > 0 && flow >= lWitchFlows.Get(0) && flow <= lWitchFlows.Get(lWitchFlows.Length - 1))
	{
		SetWitchPercent(flow);
		return true;
	}
	return false;
}
public int Native_IsWitchPercentBlockedForTank(Handle plugin, int numParams)
{
	int interval[2] = {0};
	if (GetTankAvoidInterval(interval) && IsValidInterval(interval))
	{
		int flow = GetNativeCell(1);
		return (interval[0] <= flow <= interval[1]);
	}
	return false;
}
public int Native_IsTankPercentValid(Handle plugin, int numParams)
{
	int flow = GetNativeCell(1);
	return IsValidTankFlow(flow);
}
public int Native_IsWitchPercentValid(Handle plugin, int numParams)
{
	int flow = GetNativeCell(1);
	bool ignoreBlock = GetNativeCell(2);
	
	if (!ignoreBlock) {
		return IsValidWitchFlow(flow);
	}
	ArrayList pValidFlow = lWitchFlows.Clone(), pTempWitchFlow = lWitchFlows;
	int i, interval[2];
	if (GetTankAvoidInterval(interval) && IsValidInterval(interval)) {
		for (i = interval[0]; i <= interval[1]; i++) {
			pValidFlow.Push(i);
		}
		pValidFlow.Sort(Sort_Ascending, Sort_Integer);
		lWitchFlows = pValidFlow;
	}
	bool result = IsValidWitchFlow(flow);
	// 更改 lWitchFlows 的引用
	lWitchFlows = pTempWitchFlow;
	delete pValidFlow;
	return result;
}
// boss_percent 的 Native
/* public int Native_UpdateBossPercents(Handle plugin, int numParams)
{
	UpdateReadyUpFooter(0.2);
	return 0;
} */
public int Native_SetTankDisabled(Handle plugin, int numParams)
{
	g_hTankCanSpawn.BoolValue = view_as<bool>(GetNativeCell(1));
	/* UpdateReadyUpFooter(); */
	return 0;
}
public int Native_SetWitchDisabled(Handle plugin, int numParams)
{
	g_hWitchCanSpawn.BoolValue = view_as<bool>(GetNativeCell(1));
	/* UpdateReadyUpFooter(); */
	return 0;
}
public int Native_IsDarkCarniRemix(Handle plugin, int numParams)
{
	return isDKR;
}
public int Native_GetStoredTankPercent(Handle plugin, int numParams)
{
	return nowTankFlow;
}
public int Native_GetStoredWitchPercent(Handle plugin, int numParams)
{
	return nowWitchFlow;
}
/* public int Native_GetReadyUpFooterIndex(Handle plugin, int numParams)
{
	if (isReadyUpExist)
	{
		return readyUpIndex;
	}
	return -1;
}
public int Native_RefreshReadyUp(Handle plugin, int numParams)
{
	if (isReadyUpExist)
	{
		UpdateReadyUpFooter();
		return true;
	}
	return false;
} */

stock int GetSurvivorFlow()
{
	static float survivorDistance;
	static int furthestSurvivor;
	furthestSurvivor = L4D_GetHighestFlowSurvivor();
	if (!IsValidSurvivor(furthestSurvivor)) { survivorDistance = L4D2_GetFurthestSurvivorFlow(); }
	else { survivorDistance = L4D2Direct_GetFlowDistance(furthestSurvivor); }
	return RoundToNearest(survivorDistance / L4D2Direct_GetMapMaxFlowDistance() * 100.0);
}
stock int GetSurvivorFlowZone()
{
	static int i;
	float pos[3];
	float flow, temp;
	Address nav;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i)) { continue; }
		GetClientAbsOrigin(i, pos);
		nav = L4D2Direct_GetTerrorNavArea(pos);
		if (nav == Address_Null) { continue; }
		temp = L4D2Direct_GetTerrorNavAreaFlow(nav);
		flow = (flow > temp) ? flow : temp;
	}
	flow /= L4D2Direct_GetMapMaxFlowDistance();
	flow += (g_hVsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance());
	flow = flow > 1.0 ? 1.0 : flow;
	return RoundToNearest(flow * 100.0);
}

// 判断是否黑色狂欢节 remix 地图
bool IsDKR()
{
	if (strcmp(curMapName, "dkr_m1_motel") == 0 || strcmp(curMapName, "dkr_m2_carnival") == 0 || strcmp(curMapName, "dkr_m3_tunneloflove") == 0 || strcmp(curMapName, "dkr_m4_ferris") == 0 || strcmp(curMapName, "dkr_m5_stadium") == 0)
	{
		return true;
	}
	return false;
}
bool IsInteger(const char[] buffer)
{
	if (!IsCharNumeric(buffer[0]) && buffer[0] != '-')
	{
		return false;
	}
	for (int i = 1; i < strlen(buffer); i++)
	{
		if (!IsCharNumeric(buffer[i]))
		{
			return false;
		}
	}
	return true;
}

// 其他功能
stock float GetTankFlow(int round)
{
	return L4D2Direct_GetVSTankFlowPercent(round);
}
stock float GetWitchFlow(int round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round);
}
stock float GetTankProgressFlow(int round)
{
	return L4D2Direct_GetVSTankFlowPercent(round) - GetBossBuffer();
}
stock float GetWitchProgressFlow(int round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) - GetBossBuffer();
}
stock float GetBossBuffer()
{
	return g_hVsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();
}

// 其他插件支持
// readyUp 插件面板显示坦克女巫位置
/* public void OnRoundIsLive()
{
	PrintBossPercent(TYPE_ALL);
	if (isDKR && !InVersusSecondRound())
	{
		dkrFirstTankFlow = nowTankFlow;
		dkrFirstWitchFlow = nowWitchFlow;
	}
}
void UpdateReadyUpFooter(float interval = 0.1)
{
	float prevTime = 0.0;
	if (prevTime == 0.0)
	{
		prevTime = GetEngineTime();
	}
	float time = GetEngineTime() + interval;
	if (time < prevTime)
	{
		return;
	}
	prevTime = time;
	CreateTimer(interval, Timer_UpdateReadyUpFooter);
}
public Action Timer_UpdateReadyUpFooter(Handle timer)
{
	if (isReadyUpExist)
	{
		char tankStr[32] = {'\0'}, witchStr[32] = {'\0'}, mergeStr[65] = {'\0'};
		if (nowTankFlow > 0 && !IsStaticTankMap(curMapName))
		{
			FormatEx(tankStr, sizeof(tankStr), "Tank：%d%%", nowTankFlow);
		}
		else if (!g_hTankCanSpawn.BoolValue)
		{
			FormatEx(tankStr, sizeof(tankStr), "Tank：禁止刷新");
		}
		else if (IsStaticTankMap(curMapName))
		{
			FormatEx(tankStr, sizeof(tankStr), "Tank：固定");
		}
		else
		{
			FormatEx(tankStr, sizeof(tankStr), "Tank：默认");
		}
		// Witch
		if (nowWitchFlow > 0 && !IsStaticWitchMap(curMapName))
		{
			FormatEx(witchStr, sizeof(witchStr), "Witch：%d%%", nowWitchFlow);
		}
		else if (!g_hWitchCanSpawn.BoolValue)
		{
			FormatEx(witchStr, sizeof(witchStr), "Witch：禁止刷新");
		}
		else if (IsStaticWitchMap(curMapName))
		{
			FormatEx(witchStr, sizeof(witchStr), "Witch：固定");
		}
		else
		{
			FormatEx(witchStr, sizeof(witchStr), "Witch：默认");
		}
		// 整合两个字符串
		if (g_hTankCanSpawn.BoolValue && g_hWitchCanSpawn.BoolValue)
		{
			FormatEx(mergeStr, sizeof(mergeStr), "%s，%s", tankStr, witchStr);
		}
		else if (g_hTankCanSpawn.BoolValue)
		{
			FormatEx(mergeStr, sizeof(mergeStr), "%s", tankStr);
		}
		else if (g_hWitchCanSpawn.BoolValue)
		{
			FormatEx(mergeStr, sizeof(mergeStr), "%s", witchStr);
		}
		// 添加到 readyUp 面板中
		if (isReadyUpAdded)
		{
			EditFooterStringAtIndex(readyUpIndex, mergeStr);
		}
		else
		{
			readyUpIndex = AddStringToReadyFooter(mergeStr);
			isReadyUpAdded = true;
		}
	}
	return Plugin_Continue;
} */

bool isFinaleMap()
{
	static int i;
	static char name[128];
	for (i = 0; i < GetEntityCount(); i++)
	{
		if (!IsValidEntity(i) || !IsValidEdict(i)) { continue; }
		GetEntityClassname(i, name, sizeof(name));
		if (strcmp(name, "trigger_finale", false) == 0)
		{
			#if DEBUG_ALL
				LogMessage("当前地图: %s, 已找到救援实体: %s, 索引: %d", curMapName, name, i);
			#endif
			return true;
		}
	}
	return false;
}