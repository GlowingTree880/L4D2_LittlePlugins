#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <builtinvotes>
#include "treeutil\treeutil.sp"

#define CVAR_FLAG FCVAR_NOTIFY
#define MENU_SHOW_TIME 20
#define VOTE_SHOW_TIME 30

public Plugin myinfo = 
{
	name 			= "VoteSpec",
	author 			= "夜羽真白",
	description 	= "投票将某个玩家移到旁观",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hVoteTeam, g_hVoteDisplayToSpec, g_hVotePercent, g_hBanJoinSur;
// Ints
int g_iTargetClient = 0;
// Bools
bool g_bHasBanJoin[MAXPLAYERS + 1] = false;
// Floats
float g_fBanJoinTime[MAXPLAYERS + 1] = {0.0};

public void OnPluginStart()
{
	// CreateConVars
	g_hVoteTeam = CreateConVar("SpecVote_Team", "4", "允许发起投票的团队：1=旁观者团队，2=生还者团队，3=感染者团队，4=所有团队", CVAR_FLAG, true, 1.0, true, 4.0);
	g_hVoteDisplayToSpec = CreateConVar("SpecVote_DisplayToSpec", "1", "旁观者是否允许投票", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hVotePercent = CreateConVar("SpecVote_PassPercent", "50", "需要达到这么多比率的通过票数投票才会通过", CVAR_FLAG, true, 0.0, true, 100.0);
	g_hBanJoinSur = CreateConVar("SpecVote_BanJoinSurvivorTime", "10", "被投票至旁观的玩家将会在这个时间（单位：分钟）内不得加入生还者与特感方", CVAR_FLAG, true, 0.0);
	// HookEvents
	HookEvent("player_team", evt_TeamChange, EventHookMode_Pre);
	// Commands
	RegConsoleCmd("sm_votespec", Cmd_CallSpecVote);
	RegAdminCmd("sm_forcespec", Cmd_AdminCallSpec, ADMFLAG_BAN, "sm_forceban <client id>");
}

public Action Cmd_CallSpecVote(int client, int args)
{
	if (Client_VotePermissionCheck(client))
	{
		Menu menu = new Menu(VoteSpecMenuHandler);
		menu.SetTitle("请选择需要移到旁观的玩家：");
		char player_name[MAX_NAME_LENGTH] = '\0', client_userid[32] = '\0';
		// 投票列表，旁观者除外
		for (int index = 1; index <= MaxClients; index++)
		{
			if (IsValidClient(index) && !IsFakeClient(index) && GetClientTeam(index) > view_as<int>(TEAM_SPECTATOR))
			{
				FormatEx(player_name, sizeof(player_name), "%N", index);
				FormatEx(client_userid, sizeof(client_userid), "%i", GetClientUserId(index));
				menu.AddItem(client_userid, player_name);
			}
		}
		menu.ExitButton = true;
		menu.Display(client, MENU_SHOW_TIME);
	}
	else if (client == 0)
	{
		PrintToServer("[提示]：投票旁观的指令不允许在服务器控制台使用");
	}
}

public Action Cmd_AdminCallSpec(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[提示]：用法：sm_forcespec [客户端id]");
		return Plugin_Handled;
	}
	char argument[50] = '\0';
	GetCmdArgString(argument, sizeof(argument));
	if (IsCharNumeric(argument[0]))
	{
		int target_client = StringToInt(argument);
		ChangeClientTeam(target_client, view_as<int>(TEAM_SPECTATOR));
		g_fBanJoinTime[target_client] = GetGameTime();
		g_bHasBanJoin[target_client] = true;
		g_iTargetClient = 0;
		CPrintToChatAll("{O}[提示]：{LG}管理员 {O}%N {LG}将玩家 {O}%N {LG}移到旁观", client, target_client);
	}
	else
	{
		ReplyToCommand(client, "[提示]：给出的参数不是客户端id，请于服务器使用users命令查看客户端id");
	}
	return Plugin_Handled;
}

public int VoteSpecMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char item_id[16] = '\0';
		int target_user_id = 0, target_client = 0;
		menu.GetItem(item, item_id, sizeof(item_id));
		target_user_id = StringToInt(item_id);
		target_client = GetClientOfUserId(target_user_id);
		if (IsValidClient(target_client) && !IsFakeClient(target_client))
		{
			if (!IsNewBuiltinVoteAllowed())
			{
				CPrintToChat(client, "{O}[错误]：{LG}现在无法进行新的投票");
				return;
			}
			if (IsBuiltinVoteInProgress())
			{
				CPrintToChat(client, "{O}[错误]：{LG}现在已经有一个投票正在进行，无法进行新的投票");
				return;
			}
			// 统计参与投票的人数
			int player_num = 0;
			int[] vote_players = new int[MaxClients];
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && !g_hVoteDisplayToSpec.BoolValue && GetClientTeam(i) > view_as<int>(TEAM_SPECTATOR))
				{
					vote_players[player_num++] = i;
				}
				else if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && g_hVoteDisplayToSpec.BoolValue)
				{
					vote_players[player_num++] = i;
				}
			}
			// 发起投票
			char vote_title[64] = '\0';
			g_iTargetClient = target_client;
			FormatEx(vote_title, sizeof(vote_title), "将玩家：%N 移动到旁观位置?", target_client);
			Handle hVoteSpec = CreateBuiltinVote(VoteSpecHandler_Action, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
			SetBuiltinVoteArgument(hVoteSpec, vote_title);
			SetBuiltinVoteInitiator(hVoteSpec, client);
			SetBuiltinVoteResultCallback(hVoteSpec, VoteSpecHandler_Result);
			DisplayBuiltinVote(hVoteSpec, vote_players, player_num, VOTE_SHOW_TIME);
			FakeClientCommand(client, "Vote Yes");
			CPrintToChatAll("{O}[提示]：{LG}玩家 {O}%N {LG}发起了一个将玩家 {O}%N {G}移动到旁观的投票", client, target_client);
		}
		else
		{
			g_iTargetClient = 0;
			CPrintToChat(client, "{O}[错误]：{LG}选择的玩家 {O}%N 不是有效的玩家", target_client);
		}
	}
}
public int VoteSpecHandler_Action(Handle vote, BuiltinVoteAction action, int client, int item)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			vote = INVALID_HANDLE;
			delete vote;
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(client));
		}
	}
}
public int VoteSpecHandler_Result(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int index = 0; index < num_items; index++)
	{
		// 统计赞成票数
		if (item_info[index][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[index][BUILTINVOTEINFO_ITEM_VOTES] > num_votes * RoundToNearest(g_hVotePercent.FloatValue * 0.01))
			{
				char pass_title[64] = '\0';
				FormatEx(pass_title, sizeof(pass_title), "正在将玩家：%N 移动到旁观位置", g_iTargetClient);
				DisplayBuiltinVotePass(vote, pass_title);
				ChangeClientTeam(g_iTargetClient, view_as<int>(TEAM_SPECTATOR));
				g_fBanJoinTime[g_iTargetClient] = GetGameTime();
				g_bHasBanJoin[g_iTargetClient] = true;
				g_iTargetClient = 0;
				CPrintToChatAll("{O}[提示]：{LG}已将玩家 {O}%N {LG}移到旁观", g_iTargetClient);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action evt_TeamChange(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid")), old_team = event.GetInt("oldteam"), new_team = event.GetInt("team");
	if (g_bHasBanJoin[client] && GetGameTime() - g_fBanJoinTime[client] > (g_hBanJoinSur.FloatValue * 60.0))
	{
		g_bHasBanJoin[client] = false;
	}
	if (IsValidClient(client) && old_team == view_as<int>(TEAM_SPECTATOR) && new_team != view_as<int>(TEAM_SPECTATOR) && g_bHasBanJoin[client] && GetGameTime() - g_fBanJoinTime[client] < (g_hBanJoinSur.FloatValue * 60.0))
	{
		CPrintToChat(client, "{O}[提示]：{LG}你在 {O}%d {LG}分钟不允许加入任何团队，剩余 {O}%d 分钟 %d 秒", g_hBanJoinSur.IntValue, RoundToNearest(g_fBanJoinTime[client] + g_hBanJoinSur.FloatValue * 60.0 - GetGameTime()) / 60, RoundToNearest(g_fBanJoinTime[client] + g_hBanJoinSur.FloatValue * 60.0 - GetGameTime()) % 60);
		CreateTimer(0.3, Timer_ToSpec, client);
	}
	return Plugin_Continue;
}

public Action Timer_ToSpec(Handle timer, int client)
{
	if (IsValidClient(client))
	{
		ChangeClientTeam(client, view_as<int>(TEAM_SPECTATOR));
	}
	return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		g_fBanJoinTime[client] = 0.0;
		g_bHasBanJoin[client] = false;
	}
}

bool Client_VotePermissionCheck(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		if (GetClientTeam(client) == view_as<int>(TEAM_SPECTATOR) && g_hVoteTeam.IntValue != 1 || g_hVoteTeam.IntValue != 4)
		{
			CPrintToChat(client, "{O}[提示]：{LG}当前不允许旁观者发起旁观投票");
			return false;
		}
		if (GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR) && g_hVoteTeam.IntValue != 2 || g_hVoteTeam.IntValue != 4)
		{
			CPrintToChat(client, "{O}[提示]：{LG}当前不允许生还者发起旁观投票");
			return false;
		}
		if (GetClientTeam(client) == view_as<int>(TEAM_INFECTED) && g_hVoteTeam.IntValue != 3 || g_hVoteTeam.IntValue != 4)
		{
			CPrintToChat(client, "{O}[提示]：{LG}当前不允许感染者发起旁观投票");
			return false;
		}
		return true;
	}
	return false;
}