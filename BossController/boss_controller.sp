#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
/* #include <readyup> */
#include <builtinvotes>
#include "treeutil\treeutil.sp"

#define CVAR_FLAGS FCVAR_NOTIFY
#define MAP_INFO_PATH "../../cfg/cfgogl/mapinfo.txt"
#define PROMPT_DIST 5
#define SPAWN_ATTEMPT 15
#define MENU_DISPLAY_TIME 20
#define DEBUG_ALL 0

public Plugin myinfo = 
{
	name 			= "Boss Controller",
	author 			= "CanadaRox，Sir，devilesk，Derpduck，Forgetest，Spoon，夜羽真白",
	description 	= "整合 witch_and_tankifier 与 boss_percent 与 boss_vote 的插件，战役或对抗 / 有无 mapInfo.txt 文件都允许在固定路程刷新 boss",
	version 		= "1.0.1.0 - SNAPSHOT",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

Handle tankTimer = INVALID_HANDLE, witchTimer = INVALID_HANDLE;
ConVar g_hVsBossBuffer, g_hVsBossFlowMin, g_hVsBossFlowMax, g_hTankCanSpawn, g_hWitchCanSpawn, g_hWitchAvoidTank, g_hVersusConsist, g_hCanVoteBoss, g_hEnablePrompt, g_hStopDirector;
int nowTankFlow = 0, nowWitchFlow = 0, survivorPrompDist = 0, /* readyUpIndex = -1, */ versusFirstTankFlow = 0, versusFirstWitchFlow = 0, dkrFirstTankFlow = 0, dkrFirstWitchFlow = 0,
tankActFlow = -1, witchActFlow = -1, minFlow = -1, maxFlow = -1;
bool isReadyUpExist = false, isDKR = false /* , isReadyUpAdded = false */, canSetTank = false, canSetWitch = false, isLeftSafeArea = false, spawnedTank = false, spawnedWitch = false;
char curMapName[64] = {'\0'}, mapInfoPath[PLATFORM_MAX_PATH] = {'\0'};
// 复杂数据类型
StringMap mStaticTankMaps, mStaticWitchMaps;
ArrayList lTankFlows, lWitchFlows;
KeyValues mapInfo = null;
// 其他
GlobalForward fUpdateBoss;

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
	g_hStopDirector = CreateConVar("boss_enable_director", "0", "通过调整 director_no_bosses 决定是否允许导演系统刷新 boss", CVAR_FLAGS, true, 0.0, true, 1.0);
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
	BuildPath(Path_SM, mapInfoPath, sizeof(mapInfoPath), MAP_INFO_PATH);
	if (!FileToKeyValues(mapInfo, mapInfoPath))
	{
		delete mapInfo;
		mapInfo = null;
	}
	else
	{
		mapInfo.ImportFromFile(MAP_INFO_PATH);
	}
	// HookEvents
	HookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
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
	g_hStopDirector.AddChangeHook(ConVarChanged_Cvars);
}
public void OnPluginEnd()
{
	UnhookEvent("round_start", evt_RoundStart, EventHookMode_PostNoCopy);
	delete mStaticTankMaps;
	delete mStaticWitchMaps;
	delete lTankFlows;
	delete lWitchFlows;
	delete mapInfo;
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!L4D_IsVersusMode())
	{
		if (g_hStopDirector.BoolValue)
		{
			SetConVarInt(FindConVar("director_no_bosses"), 0);
		}
		else
		{
			SetConVarInt(FindConVar("director_no_bosses"), 1);
		}
	}
}

// 检查 readyUp 插件是否存在
public void OnAllPluginsLoaded()
{
	isReadyUpExist = LibraryExists("readyup");
}
public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "readyup") == 0)
	{
		isReadyUpExist = false;
	}
}
public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "readyup") == 0)
	{
		isReadyUpExist = true;
	}
}

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
	if (IsValidClient(client))
	{
		PrintBossPercent(TYPE_PLAYER, client);
	}
	else if (client == 0)
	{
		PrintToServer("[Boss-Controller]：Boss 位置查询不能用于服务器控制台");
	}
	return Plugin_Handled;
}
public Action Cmd_BossVote(int client, int args)
{
	if (!g_hCanVoteBoss.BoolValue || !IsValidClient(client) || !CheckCanVoteBoss(client))
	{
		return Plugin_Handled;
	}
	else if (args != 2)
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
		LogMessage("[Boss-Controller]：路程是否有效：%b %b", IsValidTankFlow(tankActFlow), IsValidWitchFlow(witchActFlow, false));
	}
	#endif
	if (IsStaticTankMap(curMapName))
	{
		canSetTank = false;
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：%s 为静态坦克地图，坦克刷新路程将不会更改", curMapName);
	}
	if (IsStaticWitchMap(curMapName))
	{
		canSetWitch = false;
		CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：%s 为静态女巫地图，女巫刷新路程将不会更改", curMapName);
	}
	if ((!IsStaticTankMap(curMapName) && tankActFlow > 0 && !IsValidTankFlow(tankActFlow)) || (!IsStaticWitchMap(curMapName) && witchActFlow > 0 && !IsValidWitchFlow(witchActFlow, false)))
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
		SetBuiltinVoteResultCallback(bossVoteHandler, BossVoteResult_Handler);
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
		case BuiltinVoteAction_End:
		{
			delete vote;
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
	return 0;
}
public int BossVoteResult_Handler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				/* if (!IsInReady())
				{
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
					CPrintToChatAll("{B}<{G}BossVote{B}>：{W}只能在准备期间投票更改 Boss 位置");
					return;
				} */
				if (canSetTank && canSetWitch)
				{
					DisplayBuiltinVotePass(vote, "正在更改 Boss 刷新路程...");
				}
				else if (canSetTank)
				{
					DisplayBuiltinVotePass(vote, "正在更改 Tank 刷新路程...");
				}
				else if (canSetWitch)
				{
					DisplayBuiltinVotePass(vote, "正在更改 Witch 刷新路程...");
				}
				else
				{
					DisplayBuiltinVotePass(vote, "正在禁用本轮 Boss 刷新...");
				}
				// 投票通过，设置坦克女巫刷新位置
				SetTankPercent(tankActFlow);
				SetWitchPercent(witchActFlow);
				nowTankFlow = tankActFlow;
				nowWitchFlow = witchActFlow;
				if (tankActFlow == 0)
				{
					g_hTankCanSpawn.BoolValue = false;
				}
				if (witchActFlow == 0)
				{
					g_hWitchCanSpawn.BoolValue = false;
				}
				/* UpdateBossPercents(); */
				Call_StartForward(fUpdateBoss);
				Call_PushCell(tankActFlow);
				Call_PushCell(witchActFlow);
				Call_Finish();
				return 0;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
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
	else if (!IsValidWitchFlow(witchNewFlow, false))
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
	// 出了安全屋，没有刷克，且坦克时钟不为空，表示存在时钟，不能直接删除时钟，如果上一把先刷克，刷出来后 return Plugin_Stop 时钟已经停止，tankTimer 不为 INVALID_HANDLE 且记录的为无效句柄，删除报错
	// 刷了克，spawnedTank 或 spawnedWitch 记录为 true，已经返回 Plugin_Stop，可直接置空
	if (isLeftSafeArea && !spawnedTank && tankTimer != INVALID_HANDLE)
	{
		delete tankTimer;
	}
	if (isLeftSafeArea && !spawnedWitch && witchTimer != INVALID_HANDLE)
	{
		delete witchTimer;
	}
	tankTimer = witchTimer = INVALID_HANDLE;
	GetCurrentMap(curMapName, sizeof(curMapName));
	isDKR = IsDKR();
	isLeftSafeArea = spawnedTank = spawnedWitch = false;
	// 非对抗模式下，且非静态 Boss 地图，接管 director_no_bosses
	if (!L4D_IsVersusMode() && !g_hStopDirector.BoolValue && !IsStaticTankMap(curMapName) && !IsStaticWitchMap(curMapName))
	{
		#if (DEBUG_ALL)
		{
			LogMessage("[Boss-Controller]：当前非对抗模式，且不允许 boss 刷新，更改 boss 刷新 Cvar 为 0");
		}
		#endif
		SetConVarInt(FindConVar("director_no_bosses"), 1);
	}
}
public void OnMapEnd()
{
	versusFirstTankFlow = versusFirstWitchFlow = dkrFirstTankFlow = dkrFirstWitchFlow = nowTankFlow = nowWitchFlow = 0;
	// 每局结束，设置插件允许 boss 刷新
	g_hTankCanSpawn.BoolValue = g_hWitchCanSpawn.BoolValue = true;
}
public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	/* isReadyUpAdded = false;
	readyUpIndex = -1; */
	if (isLeftSafeArea && !spawnedTank && tankTimer != INVALID_HANDLE)
	{
		delete tankTimer;
	}
	if (isLeftSafeArea && !spawnedWitch && witchTimer != INVALID_HANDLE)
	{
		delete witchTimer;
	}
	tankTimer = witchTimer = INVALID_HANDLE;
	isLeftSafeArea = spawnedTank = spawnedWitch = false;
	nowTankFlow = nowWitchFlow = survivorPrompDist = 0;
	CreateTimer(0.5, Timer_GetBossFlow, TIMER_FLAG_NO_MAPCHANGE);
	// 更新 readyUp 面板
	/* UpdateReadyUpFooter(6.0); */
}
public Action Timer_GetBossFlow(Handle timer)
{
	// 清除集合中保存的的坦克与女巫刷新位置
	lTankFlows.Clear();
	lWitchFlows.Clear();
	// 获取设定 Boss 刷新范围
	minFlow = RoundToCeil(g_hVsBossFlowMin.FloatValue * 100.0);
	maxFlow = RoundToFloor(g_hVsBossFlowMax.FloatValue * 100.0);
	// 统一设置 minFlow 和 maxFlow
	for (int i = 1; i <= 100; i++)
	{
		lTankFlows.Push(i);
		lWitchFlows.Push(i);
		if (i < minFlow - 1 || i > maxFlow + 1)
		{
			lTankFlows.Set(i - 1, -1);
			lWitchFlows.Set(i - 1, -1);
		}
	}
	// 检查是否有 mapinfo 文件，没有则使用 Cvar min 和 max 设定值
	if (mapInfo != null)
	{
		// 如果是黑色狂欢节 remix 地图
		if (isDKR && L4D_IsVersusMode())
		{
			// 是对抗第二轮，设置第二轮坦克刷新位置为第一轮坦克刷新位置
			if (InVersusSecondRound())
			{
				nowTankFlow = dkrFirstTankFlow;
				nowWitchFlow = dkrFirstWitchFlow;
			}
			else
			{
				// 不能设置 boss 位置在黑色狂欢节 remix 这个地图，除非 boss 生成被禁用，检测 boss 生成是否被禁用
				if (!L4D2Direct_GetVSTankToSpawnThisRound(0))
				{
					if (GetTankFlow(0) * 100.0 < 1.0)
					{
						if (!g_hTankCanSpawn.BoolValue)
						{
							nowTankFlow = 0;
						}
					}
					else
					{
						nowTankFlow = dkrFirstTankFlow;
					}
				}
				if (!L4D2Direct_GetVSWitchToSpawnThisRound(0))
				{
					if (GetWitchFlow(0) * 100.0 < 1.0)
					{
						if (!g_hWitchCanSpawn.BoolValue)
						{
							nowWitchFlow = 0;
						}
					}
				}
				else
				{
					nowWitchFlow = dkrFirstWitchFlow;
				}
			}
			return Plugin_Stop;
		}
		int mapInfoMin = 0, mapInfoMax = 0;
		// 具有 mapinfo 文件，使用 mapinfo 中的信息覆盖 Boss 刷新范围
		mapInfoMin = KvGetNum(mapInfo, "versus_boss_flow_min", minFlow);
		mapInfoMax = KvGetNum(mapInfo, "versus_boss_flow_max", maxFlow);
		if (mapInfoMin != minFlow || mapInfoMax != maxFlow)
		{
			minFlow = mapInfoMin;
			maxFlow = mapInfoMax;
			lTankFlows.Clear();
			lWitchFlows.Clear();
			for (int i = 1; i <= 100; i++)
			{
				lTankFlows.Push(i);
				lWitchFlows.Push(i);
				if (i < minFlow - 1 || i > maxFlow + 1)
				{
					lTankFlows.Set(i - 1, -1);
					lWitchFlows.Set(i - 1, -1);
				}
			}
		}
		#if (DEBUG_ALL)
		{
			LogMessage("[Boss-Controller]：调整 Boss 刷新范围为：%d%% - %d%%，坦克集合长度：%d，女巫集合长度：%d", minFlow, maxFlow, lTankFlows.Length, lWitchFlows.Length);
		}
		#endif
		// 有 mapinfo 文件且允许刷新坦克，且不是静态坦克地图，可以随机一个坦克位置，设置kv 位置为当前地图
		if (g_hTankCanSpawn.BoolValue && !IsStaticTankMap(curMapName) && mapInfo.JumpToKey(curMapName))
		{
			#if (DEBUG_ALL)
			{
				LogMessage("[Boss-Controller]：当前地图：%s，非静态坦克地图，可以随机坦克位置", curMapName);
			}
			#endif
			// 可以投票设置坦克位置
			canSetTank = true;
			// 读取 mapinfo 文件中的 tank ban flow 路程，MapInfo -> currentMap -> tankBanFlow -> 遍历下面的所有 min 和 max
			int interval[2] = {0};
			if (mapInfo.JumpToKey("tank_ban_flow") && mapInfo.GotoFirstSubKey())
			{
				do
				{
					interval[0] = mapInfo.GetNum("min", -1);
					interval[1] = mapInfo.GetNum("max", -1);
					#if (DEBUG_ALL)
					{
						LogMessage("[Boss-Controller]：找到了一个坦克禁止刷新路程：min %d，max %d", interval[0], interval[1]);
					}
					#endif
					// 禁止刷新距离有效，则将这个距离加入到集合中
					if (IsValidInterval(interval))
					{
						// 找到有效的禁止刷新距离，更改原集合中禁止刷新距离为 -1
						for (int i = (interval[0] - 1 < 0 ? 0 : interval[0] - 1); i < (interval[1] + 1 > 100 ? 100 : interval[1] + 1); i++)
						{
							lTankFlows.Set(i, -1);
						}
					}
				}
				while (mapInfo.GotoNextKey());
			}
			// -> mapInfo
			mapInfo.Rewind();
			// 检查允许刷新集合中所有元素是否都为 -1 禁止刷新标识
			bool canSpawnTank = false;
			for (int i = 0; i < lTankFlows.Length; i++)
			{
				if (lTankFlows.Get(i) != -1)
				{
					canSpawnTank = true;
					break;
				}
			}
			if (!canSpawnTank)
			{
				// 不允许刷克时
				if (L4D_IsVersusMode()) { SetTankPercent(0); }
 				else { nowTankFlow = 0; }
				#if (DEBUG_ALL)
				{
					LogMessage("[Boss-Controller]：当前禁止刷新的路程涵盖了所有允许坦克刷新的路程，坦克将不会刷新");
				}
				#endif
			}
			else
			{
				// 允许刷克，随机一个坦克刷新位置
				nowTankFlow = GetRandomSpawnPos(lTankFlows);
				#if (DEBUG_ALL)
				{
					LogMessage("[Boss-Controller]：当前允许坦克刷新，随机一个坦克刷新位置：%d 路程", nowTankFlow);
				}
				#endif
				if (!InVersusSecondRound() || (!g_hVersusConsist.BoolValue && InVersusSecondRound()))
				{
					versusFirstTankFlow = nowTankFlow;
					SetTankPercent(nowTankFlow);
				}
				else
				{
					#if (DEBUG_ALL)
					{
						LogMessage("[Boss-Controller]：当前是对抗第二局，把坦克刷新位置更改为与第一局相同：%d", versusFirstTankFlow);
					}
					#endif
					nowTankFlow = versusFirstTankFlow;
					SetTankPercent(versusFirstTankFlow);
				}
			}
		}
		else
		{
			// 是静态坦克地图，插件不接管刷克
			if (L4D_IsVersusMode()) { SetTankPercent(0); }
			else { nowTankFlow = 0; }
			#if (DEBUG_ALL)
			{
				LogMessage("[Boss-Controller]：当前地图：%s 是静态坦克地图，不允许坦克刷新", curMapName);
			}
			#endif
		}
		// 检查当前地图是否为静态女巫地图，不是，则随机一个女巫刷新位置
		if (g_hWitchCanSpawn.BoolValue && !IsStaticWitchMap(curMapName) && mapInfo.JumpToKey(curMapName))
		{
			#if (DEBUG_ALL)
			{
				LogMessage("[Boss-Controller]：当前地图：%s，非静态女巫地图，可以随机女巫刷新位置", curMapName);
			}
			#endif
			// 可以投票设置女巫位置
			canSetWitch = true;
			int interval[2] = {0};
			if (mapInfo.JumpToKey("witch_ban_flow") && mapInfo.GotoFirstSubKey())
			{
				do
				{
					interval[0] = mapInfo.GetNum("min", -1);
					interval[1] = mapInfo.GetNum("max", -1);
					#if (DEBUG_ALL)
					{
						LogMessage("[Boss-Controller]：找到了一个禁止女巫刷新的路程：min %d，max %d", interval[0], interval[1]);
					}
					#endif
					if (IsValidInterval(interval))
					{
						for (int i = (interval[0] - 1 < 0 ? 0 : interval[0] - 1); i < (interval[1] == 100 ? 100 : interval[1] + 1); i++)
						{
							lWitchFlows.Set(i, -1);
						}
					}
				}
				while (mapInfo.GotoNextKey());
			}
			mapInfo.Rewind();
			// 如果开了女巫需要距离坦克一定距离刷新，则继续判断
			if (g_hWitchAvoidTank.IntValue > 0)
			{
				for (int i = nowTankFlow - (g_hWitchAvoidTank.IntValue / 2); i <= nowTankFlow + (g_hWitchAvoidTank.IntValue / 2); i++)
				{
					if (lWitchFlows.FindValue(i)) lWitchFlows.Set(i, -1);
				}
			}
			// 检查允许刷新集合中所有元素是否都为 -1 禁止刷新标识
			bool canSpawnWitch = false;
			for (int i = 0; i < lWitchFlows.Length; i++)
			{
				if (lWitchFlows.Get(i) != -1)
				{
					canSpawnWitch = true;
					break;
				}
			}
			// 此时女巫集合长度为 100，未删除 -1 元素，无需判断长度是否小于 g_hWitchAvoidTank.IntValue
			if (!canSpawnWitch)
			{
				if (L4D_IsVersusMode()) { SetWitchPercent(0); }
				else { nowWitchFlow = 0; }
				#if (DEBUG_ALL)
				{
					LogMessage("[Boss-Controller]：当前禁止刷新的路程涵盖了所有允许女巫刷新的路程，女巫将不会刷新");
				}
				#endif
			}
			else
			{
				nowWitchFlow = GetRandomSpawnPos(lWitchFlows);
				#if (DEBUG_ALL)
				{
					LogMessage("[Boss-Controller]：当前允许女巫刷新，随机一个女巫刷新位置：%d 路程", nowWitchFlow);
				}
				#endif
				if (!InVersusSecondRound() || (!g_hVersusConsist.BoolValue && InVersusSecondRound()))
				{
					versusFirstWitchFlow = nowWitchFlow;
					SetWitchPercent(nowWitchFlow);
				}
				else
				{
					#if (DEBUG_ALL)
					{
						LogMessage("[Boss-Controller]：当前是对抗第二局，把女巫刷新位置更改为与第一局相同：%d", versusFirstWitchFlow);
					}
					#endif
					nowWitchFlow = versusFirstWitchFlow;
					SetWitchPercent(versusFirstWitchFlow);
				}
			}
		}
		else
		{
			if (L4D_IsVersusMode()) { SetWitchPercent(0); }
			else { nowWitchFlow = 0; }
			#if (DEBUG_ALL)
			{
				LogMessage("[Boss-Controller]：当前地图：%s 是静态女巫地图，不允许女巫刷新", curMapName);
			}
			#endif
		}
	}
	else
	{
		// 没有 mapinfo，直接随机一个在 minFlow 和 maxFlow 之间的位置
		nowTankFlow = GetRandomSpawnPos(lTankFlows);
		if (g_hWitchAvoidTank.IntValue > 0)
		{
			for (int i = nowTankFlow - (g_hWitchAvoidTank.IntValue / 2); i <= nowTankFlow + (g_hWitchAvoidTank.IntValue / 2); i++)
			{
				lWitchFlows.Set(i, -1);
			}
		}
		nowWitchFlow = GetRandomSpawnPos(lWitchFlows);
		#if (DEBUG_ALL)
		{
			LogMessage("[Boss-Controller]：当前地图：%s 不是静态坦克女巫地图，并且没有 mapinfo 文件，随机坦克位置：%d，随机女巫位置：%d", curMapName, nowTankFlow, nowWitchFlow);
		}
		#endif
		if (L4D_IsVersusMode())
		{
			SetTankPercent(nowTankFlow);
			SetWitchPercent(nowWitchFlow);
		}
	}
	return Plugin_Stop;
}
// 在坦克刷新位置发生变化的时候，此时 tankFlow 有效，动态调整女巫刷新位置
void DynamicAdjustWtichPercent(int tankFlow)
{
	if (g_hWitchCanSpawn.BoolValue)
	{
		// 全路段禁止刷新女巫，则直接设置为 0
		if (lWitchFlows.Length == 0)
		{
			#if (DEBUG_ALL)
			{
				LogMessage("[Boss-Controller]：坦克位置即将发生变化，新位置：%d，且禁止刷新的路程涵盖了所有允许女巫刷新的路程，女巫将不会刷新", tankFlow);
			}
			#endif
			if (L4D_IsVersusMode()) { SetWitchPercent(0); }
			else { nowWitchFlow = 0; }
			return;
		}
		int newWitchFlow = -1;
		if (L4D_IsVersusMode()) { newWitchFlow = RoundFloat(L4D2Direct_GetVSWitchFlowPercent(0) * 100); }
		else { newWitchFlow = nowWitchFlow; }
		if (g_hWitchAvoidTank.IntValue > 0)
		{
			// 找到新的被坦克位置阻挡的女巫范围，如果在集合中能找到索引，设置为 -1，否则跳出
			for (int i = tankFlow + (g_hWitchAvoidTank.IntValue / 2); i >= tankFlow - (g_hWitchAvoidTank.IntValue / 2); i--)
			{
				if (lWitchFlows.FindValue(i))
				{
					lWitchFlows.Set(i, -1);
				}
				break;
			}
			// 找到原来被坦克范围阻挡的不能刷女巫的范围重新调整为可以刷女巫，此时集合已经处理完毕，需要在 minFlow 和 maxFlow 之间进行添加，而不是 0 - 100
			int interval[2] = {0};
			if (GetTankAvoidInterval(interval) && IsValidInterval(interval))
			{
				interval[0] = interval[0] - 1 < minFlow ? minFlow : interval[0] - 1;
				interval[1] = interval[1] + 1 > maxFlow ? maxFlow : interval[1] + 1;
				for (int i = interval[0]; i < interval[1]; i++)
				{
					lWitchFlows.Push(i);
				}
			}
			lWitchFlows.Sort(Sort_Descending, Sort_Integer);
		}
		bool canSpawnWitch = false;
		for (int i = 0; i < lWitchFlows.Length; i++)
		{
			if (lWitchFlows.Get(i) > -1)
			{
				canSpawnWitch = true;
				break;
			}
		}
		if (!canSpawnWitch)
		{
			#if (DEBUG_ALL)
			{
				LogMessage("[Boss-Controller]：坦克位置即将发生变化，新位置：%d，且禁止刷新的路程涵盖了所有允许女巫刷新的路程，女巫将不会刷新", tankFlow);
			}
			#endif
			if (L4D_IsVersusMode()) { SetWitchPercent(0); }
			else { newWitchFlow = nowWitchFlow = 0; }
			return;
		}
		newWitchFlow = GetRandomSpawnPos(lWitchFlows);
		if (L4D_IsVersusMode()) { SetWitchPercent(newWitchFlow); }
		else { nowWitchFlow = newWitchFlow; }
	}
}
// 生还者离开安全区域后，如果不是对抗模式，则创建时钟检测生还者路程
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (g_hTankCanSpawn.BoolValue && !IsStaticTankMap(curMapName) && nowTankFlow > 0)
	{
		if (tankTimer != INVALID_HANDLE || tankTimer != null)
		{
			delete tankTimer;
			tankTimer = INVALID_HANDLE;
		}
		tankTimer = CreateTimer(0.5, Timer_SpawnTank, _, TIMER_REPEAT);
	}
	if (g_hWitchCanSpawn.BoolValue && !IsStaticWitchMap(curMapName) && nowWitchFlow > 0)
	{
		if (witchTimer != INVALID_HANDLE || witchTimer != null)
		{
			delete witchTimer;
			witchTimer = INVALID_HANDLE;
		}
		witchTimer = CreateTimer(0.5, Timer_SpawnWitch, _, TIMER_REPEAT);
	}
	PrintBossPercent(TYPE_ALL);
	if (!isReadyUpExist)
	{
		dkrFirstTankFlow = nowTankFlow;
		dkrFirstWitchFlow = nowWitchFlow;
	}
	isLeftSafeArea = true;
	return Plugin_Continue;
}
public Action Timer_SpawnTank(Handle timer)
{
	if (g_hTankCanSpawn.BoolValue && !IsStaticTankMap(curMapName))
	{
		int survivorDist = GetSurvivorFlow();
		if (!L4D_IsVersusMode() && survivorDist >= nowTankFlow && !spawnedTank)
		{
			SpawnBoss(view_as<int>(ZC_TANK));
			return Plugin_Stop;
		}
		else if (g_hEnablePrompt.BoolValue && (nowTankFlow - PROMPT_DIST <= survivorDist < nowTankFlow) && survivorDist >= survivorPrompDist)
		{
			CPrintToChatAll("{LG}当前：{O}%d%%，{LG}Tank 将于：{O}%d%% {LG}位置刷新", survivorDist, nowTankFlow);
			survivorPrompDist = survivorDist + 1;
		}
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}
public Action Timer_SpawnWitch(Handle timer)
{
	if (g_hWitchCanSpawn.BoolValue && !IsStaticWitchMap(curMapName))
	{
		int survivorDist = GetSurvivorFlow();
		if (!L4D_IsVersusMode() && survivorDist >= nowWitchFlow && !spawnedWitch)
		{
			SpawnBoss(view_as<int>(ZC_WITCH));
			return Plugin_Stop;
		}
		else if (g_hEnablePrompt.BoolValue && (nowWitchFlow - PROMPT_DIST <= survivorDist < nowWitchFlow) && survivorDist >= survivorPrompDist)
		{
			CPrintToChatAll("{LG}当前：{O}%d%%，{LG}Witch 将于：{O}%d%% {LG}位置刷新", survivorDist, nowWitchFlow);
			survivorPrompDist = survivorDist + 1;
		}
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}
void SpawnBoss(int class)
{
	float spawnPos[3] = {0.0};
	int count = 0;
	for (int i = 0; i < SPAWN_ATTEMPT; i++)
	{
		count++;
		int target = L4D_GetHighestFlowSurvivor();
		if (IsValidSurvivor(target))
		{
			if (L4D_GetRandomPZSpawnPosition(target, class, SPAWN_ATTEMPT, spawnPos))
			{
				break;
			}
		}
	}
	if (count >= SPAWN_ATTEMPT)
	{
		#if (DEBUG_ALL)
		{
			LogMessage("[Boss-Controller]：找位：%d 次，无法找到刷新 boss 序号：%d 的位置，停止刷新", SPAWN_ATTEMPT, class);
		}
		#endif
		return;
	}
	if (class == view_as<int>(ZC_TANK))
	{
		L4D2_SpawnTank(spawnPos, NULL_VECTOR);
		spawnedTank = true;
	}
	else if (class == view_as<int>(ZC_WITCH))
	{
		L4D2_SpawnWitch(spawnPos, NULL_VECTOR);
		spawnedWitch = true;
	}
}
void PrintBossPercent(int type, int client = -1)
{
	char tankStr[64] = {'\0'}, witchStr[64] = {'\0'};
	char hasSpawnedTank[32] = {'\0'}, hasSpawnedWitch[32] = {'\0'};
	spawnedTank ? FormatEx(hasSpawnedTank, sizeof(hasSpawnedTank), "已刷新") : FormatEx(hasSpawnedTank, sizeof(hasSpawnedTank), "未刷新");
	spawnedWitch ? FormatEx(hasSpawnedWitch, sizeof(hasSpawnedWitch), "已刷新") : FormatEx(hasSpawnedWitch, sizeof(hasSpawnedWitch), "未刷新");
	if (nowTankFlow > 0)
	{
		FormatEx(tankStr, sizeof(tankStr), "{G}Tank 刷新：{O}%d%%（%s）", nowTankFlow, hasSpawnedTank);
	}
	else if (!g_hTankCanSpawn.BoolValue)
	{
		FormatEx(tankStr, sizeof(tankStr), "{G}Tank：{O}禁止刷新");
	}
	else if (IsStaticTankMap(curMapName))
	{
		FormatEx(tankStr, sizeof(tankStr), "{G}Tank：{O}固定");
	}
	else
	{
		FormatEx(tankStr, sizeof(tankStr), "{G}Tank：{O}无");
	}
	// Witch
	if (nowWitchFlow > 0)
	{
		FormatEx(witchStr, sizeof(witchStr), "{G}Witch 刷新：{O}%d%%（%s）", nowWitchFlow, hasSpawnedWitch);
	}
	else if (!g_hWitchCanSpawn.BoolValue)
	{
		FormatEx(witchStr, sizeof(witchStr), "{G}Witch：{O}禁止刷新");
	}
	else if (IsStaticWitchMap(curMapName))
	{
		FormatEx(witchStr, sizeof(witchStr), "{G}Witch：{O}固定");
	}
	else
	{
		FormatEx(witchStr, sizeof(witchStr), "{G}Witch：{O}无");
	}
	// 整合两个字符串
	if (g_hTankCanSpawn.BoolValue && g_hWitchCanSpawn.BoolValue)
	{
		if (type == TYPE_PLAYER && IsValidClient(client))
		{
			CPrintToChat(client, "{G}当前：{O}%d%%", GetSurvivorFlow());
			CPrintToChat(client, "%s", tankStr);
			CPrintToChat(client, "%s", witchStr);
		}
		else
		{
			CPrintToChatAll("{G}当前：{O}%d%%", GetSurvivorFlow());
			CPrintToChatAll("%s", tankStr);
			CPrintToChatAll("%s", witchStr);
		}
	}
	else if (g_hTankCanSpawn.BoolValue)
	{
		if (type == TYPE_PLAYER && IsValidClient(client))
		{
			CPrintToChat(client, "{G}当前：{O}%d%%", GetSurvivorFlow());
			CPrintToChat(client, "%s", tankStr);
		}
		else
		{
			CPrintToChatAll("{G}当前：{O}%d%%", GetSurvivorFlow());
			CPrintToChatAll("%s", tankStr);
		}
	}
	else if (g_hWitchCanSpawn.BoolValue)
	{
		if (type == TYPE_PLAYER && IsValidClient(client))
		{
			CPrintToChat(client, "{G}当前：{O}%d%%", GetSurvivorFlow());
			CPrintToChat(client, "%s", witchStr);
		}
		else
		{
			CPrintToChatAll("{G}当前：{O}%d%%", GetSurvivorFlow());
			CPrintToChatAll("%s", witchStr);
		}
	}
}
// 判断是否可以进行 boss 投票
bool CheckCanVoteBoss(int client)
{
	if (IsValidClient(client))
	{
		if (isDKR)
		{
			CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前地图：{O}%s {W}不允许投票更改 Boss 刷新路程", curMapName);
			return false;
		}
		if (isLeftSafeArea)
		{
			CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前已离开本地图起始安全区域，不允许投票更改 Boss 刷新路程");
			return false;
		}
		/* if (isReadyUpExist && !IsInReady())
		{
			CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}只能在准备期间投票更改 Boss 位置");
			return false;
		} */
		if (InVersusSecondRound())
		{
			CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前是对抗第二轮，不允许更改 Boss 刷新路程");
			return false;
		}
		if (GetClientTeam(client) == view_as<int>(TEAM_SPECTATOR))
		{
			CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}旁观者不允许更改 Boss 刷新路程");
			return false;
		}
		if (!IsNewBuiltinVoteAllowed())
		{
			CPrintToChat(client, "{B}<{G}BossVote{B}>：{W}当前暂时不允许发起新的投票更改 Boss 刷新路程");
			return false;
		}
		return true;
	}
	return false;
}

// 方法
bool IsStaticTankMap(const char[] mapName)
{
	bool result = false;
	if (mStaticTankMaps.GetValue(mapName, result))
	{
		return result;
	}
	return false;
}
bool IsStaticWitchMap(const char[] mapName)
{
	bool result = false;
	if (mStaticWitchMaps.GetValue(mapName, result))
	{
		return result;
	}
	return false;
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
	if (g_hWitchAvoidTank.FloatValue != 0.0)
	{
		float flow = L4D2Direct_GetVSTankFlowPercent(0);
		if (flow != 0.0)
		{
			interval[0] = RoundToFloor((flow * 100.0) - (g_hWitchAvoidTank.FloatValue / 2.0));
			interval[1] = RoundToCeil((flow * 100.0) + (g_hWitchAvoidTank.FloatValue / 2.0));
			return true;
		}
		return false;
	}
	return false;
}
// 随机刷新位置
int GetRandomSpawnPos(ArrayList arr)
{
	// 对集合进行降序排序，如果有 -1 禁止刷新标识，则会排在后前面，遍历集合获取有效长度，截断
	int validLen = 0;
	arr.Sort(Sort_Descending, Sort_Integer);
	for (int i = 0; i < arr.Length; i++)
	{
		// 如果有禁止刷新标识，则去除这一元素
		if (arr.Get(i) != -1)
		{
			validLen += 1;
		}
	}
	arr.Resize(validLen);
	return arr.Get(GetURandomIntInRange(0, arr.Length - 1));
}
// GetRandomInt 会有约 4% 误差，不是等概率随机数发生器，这种方法可以将误差降低到 2% 左右
int GetURandomIntInRange(int min, int max)
{
	return (GetURandomInt() % (max - min + 1)) + min;
}
bool IsValidTankFlow(int flow)
{
	return (flow >= 0 && lTankFlows.Length > 0 && flow <= lTankFlows.Get(0) && flow >=lTankFlows.Get(lTankFlows.Length - 1));
}
bool IsValidWitchFlow(int flow, bool ignoreBlock)
{
	if (ignoreBlock)
	{
		return (flow >= 0 && lWitchFlows.Length > 0 && flow <= lWitchFlows.Get(0) && flow >= lWitchFlows.Get(lWitchFlows.Length - 1));
	}
	else
	{
		int interval[2] = {0};
		if (GetTankAvoidInterval(interval) && IsValidInterval(interval))
		{
			return (flow >= 0 && lWitchFlows.Length > 0 && flow <= lWitchFlows.Get(0) && flow >= lWitchFlows.Get(lWitchFlows.Length - 1) && (flow <= interval[0] - 1 || flow >= interval[1] + 1));
		}
		return (flow >= 0 && lWitchFlows.Length > 0 && flow <= lWitchFlows.Get(0) && flow >= lWitchFlows.Get(lWitchFlows.Length - 1));
	}
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
	return IsValidWitchFlow(flow, ignoreBlock);
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

int GetSurvivorFlow()
{
	float flow = 0.0, tempFlow = 0.0, nearestNav[3] = {0.0};
	Address pNav = Address_Null;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client))
		{
			GetClientAbsOrigin(client, nearestNav);
			pNav = L4D2Direct_GetTerrorNavArea(nearestNav);
			if (pNav != Address_Null)
			{
				tempFlow = L4D2Direct_GetTerrorNavAreaFlow(pNav);
				flow = (flow > tempFlow) ? flow : tempFlow;
			}
		}
	}
	flow /= L4D2Direct_GetMapMaxFlowDistance();
	float tempProxy = flow + g_hVsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();
	return RoundToNearest((tempProxy > 1.0 ? 1.0 : tempProxy) * 100.0);
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
			FormatEx(tankStr, sizeof(tankStr), "Tank：无");
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
			FormatEx(witchStr, sizeof(witchStr), "Witch：无");
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