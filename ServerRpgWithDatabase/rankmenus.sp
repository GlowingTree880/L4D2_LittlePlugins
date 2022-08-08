#pragma semicolon 1
#pragma newdecls required

#define SHOW_DELAY 0.15
// 基本于 70-100 ms 之间执行完成，先执行 SQL 语句获得结果，延迟 SHOW_DELAY 这么多时间后绘制菜单
#define DQL_PLAYER_TOTAL_PLAYTIME "SELECT INFO.Player_Name, INFO.Total_Play_Time FROM %s AS INFO ORDER BY INFO.Total_Play_Time DESC LIMIT %d;"
#define DQL_MAX_PLAYTIME "SELECT INFO.Player_Name, INFO.Max_Pre_Play_Time FROM %s AS INFO ORDER BY INFO.Max_Pre_Play_Time DESC LIMIT %d;"
// 加入限制数据需要大于 0
#define DQL_PLAYER_LEVEL "SELECT POINTS.Player_Name, POINTS.Level FROM %s AS POINTS WHERE POINTS.Level > 0 ORDER BY POINTS.Level DESC LIMIT %d;"
#define DQL_PLAYER_BPOINTS "SELECT POINTS.Player_Name, POINTS.BPoints FROM %s AS POINTS WHERE POINTS.BPoints > 0 ORDER BY POINTS.BPoints DESC LIMIT %d;"
#define DQL_PLAYER_EXPS "SELECT POINTS.Player_Name, POINTS.Exps FROM %s AS POINTS WHERE POINTS.Exps > 0 ORDER BY POINTS.Exps DESC LIMIT %d;"
#define DQL_SI_KILLED "SELECT INFO.Player_Name, INFO.Total_SI_Killed FROM %s AS INFO WHERE INFO.Total_SI_Killed > 0 ORDER BY INFO.Total_SI_Killed DESC LIMIT %d;"
#define DQL_CI_KILLED "SELECT INFO.Player_Name, INFO.Total_CI_Killed FROM %s AS INFO WHERE INFO.Total_CI_Killed > 0 ORDER BY INFO.Total_CI_Killed DESC LIMIT %d;"
#define DQL_FF "SELECT INFO.Player_Name, INFO.FF_Count, INFO.FF_Damage FROM %s AS INFO WHERE INFO.FF_Damage > 0 ORDER BY INFO.FF_Damage DESC LIMIT %d;"
// 玩家进入，至少记录一张地图
#define DQL_MAP_PLAYED "SELECT CP.Player_Name, CP.Total_Played_Maps FROM %s AS CP ORDER BY CP.Total_Played_Maps DESC LIMIT %d;"
//
#define DQL_HEADSHOT_RATE "SELECT INFO.Player_Name, INFO.Total_SI_Killed + INFO.Total_CI_Killed AS Total_Killed,INFO.HeadShot_Count, INFO.HeadShot_Rate FROM %s AS INFO WHERE INFO.HeadShot_Rate > 0.0 ORDER BY INFO.HeadShot_Rate DESC LIMIT %d;"
#define DQL_MINUTE_BPOINTS "SELECT POINTS.Player_Name, POINTS.Minutes_BPoints FROM %s AS POINTS WHERE POINTS.Minutes_BPoints > 0.0 ORDER BY POINTS.Minutes_BPoints DESC LIMIT %d;"
#define DQL_MINUTE_EXPS "SELECT POINTS.Player_Name, POINTS.Minutes_Exps FROM %s AS POINTS WHERE POINTS.Minutes_Exps > 0.0 ORDER BY POINTS.Minutes_Exps DESC LIMIT %d;"
// 需要 MySQL 8.0 以上版本，使用 row_number() over() 分组排序，低版本可使用临时表获得排序
#define DQL_PLAYER_ALLRANK "SELECT merge.no FROM ( SELECT info.STEAM_ID, info.%s, row_number() OVER (ORDER BY info.%s DESC) AS no FROM %s AS info ) \
AS merge WHERE merge.STEAM_ID = '%s' UNION ALL SELECT count(1) FROM %s;"

static const char SerialNum[][] = 
{
	"None",
	"第一",
	"前二名",
	"前三名",
	"前四名",
	"前五名",
	"前六名",
	"前七名",
	"前八名",
	"前九名",
	"前十名",
	"前十一名",
	"前十二名",
	"前十三名",
	"前十四名",
	"前十五名",
	"前十六名",
	"前十七名",
	"前十八名",
	"前十九名",
	"前二十名"
};
enum RANK_TYPE
{
	RANK_TOTAL_PLAYTIME,
	RANK_MAX_PLAYTIME,
	RANK_PLAYER_LEVEL,
	RANK_PLAYER_BPOINTS,
	RANK_PLAYER_EXPS,
	RANK_SI_KILLED,
	RANK_CI_KILLED,
	RANK_HEADSHOT_RATE,
	RANK_MINUTE_BPOINTS,
	RANK_MINUTE_EXPS,
	RANK_FF,
	RANK_MAP_PLAYED, 
	RANK_PLAYER_ALLRANK
}

// ConVars
ConVar g_hRankLimit;
// DataPacks
DataPack Rank_Packs[MAXPLAYERS + 1] = {null}, All_Rank_Packs[MAXPLAYERS + 1] = {null};

public void RankMenus_OnModuleStart()
{
	g_hRankLimit = CreateConVar("rank_ranklimit", "10", "默认一个 rankmenu 菜单显示多少条玩家排名信息", CVAR_FLAGS, true, 0.0);
	RegConsoleCmd("sm_rankmenu", Cmd_RankMenu, "打开玩家排行榜菜单");
}
public Action Cmd_RankMenu(int client, int args)
{
	if (IsValidClient(client))
	{
		if (db_TreeServer != null)
		{
			Draw_RankMenu(client);
		}
		else
		{
			CPrintToChat(client, INFO_DB_NULL);
		}
	}
	else if (client == 0)
	{
		PrintToServer("【TreeServer】：玩家排行榜指令：!rankmenu 无法于服务端控制台使用");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
// 绘制玩家排行榜菜单
public Action Draw_RankMenu(int client)
{
	Menu RankMenu = new Menu(RankMenuHandler);
	RankMenu.SetTitle("玩家信息排行榜");
	RankMenu.AddItem("Total_PlayTime", " 游玩总时长排行榜");
	RankMenu.AddItem("Max_PlayTime", "单次最长游玩时长排行榜");
	RankMenu.AddItem("Player_Level", "玩家等级排行榜");
	RankMenu.AddItem("Player_BPoints", "玩家B数排行榜");
	RankMenu.AddItem("Player_Exps", "玩家经验排行榜");
	RankMenu.AddItem("SI_Killed", "特感击杀排行榜");
	RankMenu.AddItem("CI_Killed", "丧尸击杀排行榜");
	RankMenu.AddItem("HeadShot_Rate", " 玩家爆头率排行榜");
	RankMenu.AddItem("Minute_BPoints", "玩家每分钟获取B数排行榜");
	RankMenu.AddItem("Minute_Exps", "玩家每分钟获取经验排行榜");
	RankMenu.AddItem("Player_FF", "玩家黑枪排行榜");
	RankMenu.AddItem("Player_Map_Played", "玩家地图游玩数量排行榜");
	RankMenu.ExitButton = true;
	RankMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Continue;
}
public Action Draw_SubRankMenu(int client, RANK_TYPE Type)
{
	if (Rank_Packs[client] != null && All_Rank_Packs[client] != null)
	{
		Rank_Packs[client].Reset();
		int row_count = Rank_Packs[client].ReadCell();
		row_count = (row_count < g_hRankLimit.IntValue) ? row_count : g_hRankLimit.IntValue;
		All_Rank_Packs[client].Reset();
		int my_rank = All_Rank_Packs[client].ReadCell(), total_rank = All_Rank_Packs[client].ReadCell();
		char info[128] = {'\0'}, player_name[MAX_NAME_LENGTH] = {'\0'};
		Panel SubRankMenu = new Panel();
		switch (Type)
		{
			case RANK_TOTAL_PLAYTIME, RANK_MAX_PLAYTIME:
			{
				(Type == RANK_TOTAL_PLAYTIME) ? SubRankMenu.SetTitle("玩家游玩总时长排行：") : SubRankMenu.SetTitle("单次最长游玩时间排行：");
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "我的排名：%d / %d", my_rank, total_rank);
				SubRankMenu.DrawText(info);
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "全服%s", SerialNum[g_hRankLimit.IntValue]);
				SubRankMenu.DrawText(info);
				char play_time[64] = {'\0'};
				for (int i = 0; i < row_count; i++)
				{
					Rank_Packs[client].ReadString(player_name, sizeof(player_name));
					Rank_Packs[client].ReadString(play_time, sizeof(play_time));
					FormatEx(info, sizeof(info), "NO%d：%s(%s)", i + 1, player_name, play_time);
					SubRankMenu.DrawText(info);
				}
			}
			case RANK_PLAYER_LEVEL, RANK_PLAYER_BPOINTS, RANK_PLAYER_EXPS, RANK_SI_KILLED, RANK_CI_KILLED, RANK_MAP_PLAYED:
			{
				switch (Type)
				{
					case RANK_PLAYER_LEVEL: SubRankMenu.SetTitle("玩家等级排行：");
					case RANK_PLAYER_BPOINTS: SubRankMenu.SetTitle("玩家B数排行：");
					case RANK_PLAYER_EXPS: SubRankMenu.SetTitle("玩家经验排行：");
					case RANK_SI_KILLED: SubRankMenu.SetTitle("特感击杀排行：");
					case RANK_CI_KILLED: SubRankMenu.SetTitle("丧尸击杀排行：");
					case RANK_MAP_PLAYED: SubRankMenu.SetTitle("玩家地图游玩数量排行：");
				}
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "我的排名：%d / %d", my_rank, total_rank);
				SubRankMenu.DrawText(info);
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "全服%s", SerialNum[g_hRankLimit.IntValue]);
				SubRankMenu.DrawText(info);
				for (int i = 0; i < row_count; i++)
				{
					Rank_Packs[client].ReadString(player_name, sizeof(player_name));
					int level_bpoints_exp = Rank_Packs[client].ReadCell();
					switch (Type)
					{
						case RANK_PLAYER_LEVEL: FormatEx(info, sizeof(info), "NO%d：%s(%d级)", i + 1, player_name, level_bpoints_exp);
						case RANK_PLAYER_BPOINTS, RANK_PLAYER_EXPS: FormatEx(info, sizeof(info), "NO%d：%s(%d点)", i + 1, player_name, level_bpoints_exp);
						case RANK_SI_KILLED, RANK_CI_KILLED: FormatEx(info, sizeof(info), "NO%d：%s(%d只)", i + 1, player_name, level_bpoints_exp);
						case RANK_MAP_PLAYED: FormatEx(info, sizeof(info), "NO%d：%s(%d张)", i + 1, player_name, level_bpoints_exp);
					}
					SubRankMenu.DrawText(info);
				}
			}
			case RANK_FF:
			{
				SubRankMenu.SetTitle("玩家黑枪排行：");
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "我的排名：%d / %d", my_rank, total_rank);
				SubRankMenu.DrawText(info);
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "全服%s", SerialNum[g_hRankLimit.IntValue]);
				SubRankMenu.DrawText(info);
				for (int i = 0; i < row_count; i++)
				{
					Rank_Packs[client].ReadString(player_name, sizeof(player_name));
					int player_ff_count = Rank_Packs[client].ReadCell();
					int player_ff_damage = Rank_Packs[client].ReadCell();
					FormatEx(info, sizeof(info), "NO%d：%s(%d次%d伤害)", i + 1, player_name, player_ff_count, player_ff_damage);
					SubRankMenu.DrawText(info);
				}
			}
			case RANK_HEADSHOT_RATE:
			{
				SubRankMenu.SetTitle("玩家爆头率排行：");
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "我的排名：%d / %d", my_rank, total_rank);
				SubRankMenu.DrawText(info);
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "全服%s", SerialNum[g_hRankLimit.IntValue]);
				SubRankMenu.DrawText(info);
				for (int i = 0; i < row_count; i++)
				{
					Rank_Packs[client].ReadString(player_name, sizeof(player_name));
					int total_killed = Rank_Packs[client].ReadCell();
					int headshot_count = Rank_Packs[client].ReadCell();
					float headshot_rate = Rank_Packs[client].ReadFloat();
					FormatEx(info, sizeof(info), "NO%d：%s(%dHs/%dKills - %.2f%%)", i + 1, player_name, headshot_count, total_killed, headshot_rate * 100.0);
					SubRankMenu.DrawText(info);
				}
			}
			case RANK_MINUTE_BPOINTS, RANK_MINUTE_EXPS:
			{
				switch (Type)
				{
					case RANK_MINUTE_BPOINTS: SubRankMenu.SetTitle("每分钟获取B数排行：");
					case RANK_MINUTE_EXPS: SubRankMenu.SetTitle("每分钟获取经验排行：");
				}
				FormatEx(info, sizeof(info), "我的排名：%d / %d", my_rank, total_rank);
				SubRankMenu.DrawText(info);
				SubRankMenu.DrawText("----------");
				FormatEx(info, sizeof(info), "全服%s", SerialNum[g_hRankLimit.IntValue]);
				SubRankMenu.DrawText(info);
				for (int i = 0; i < row_count; i++)
				{
					Rank_Packs[client].ReadString(player_name, sizeof(player_name));
					float minute_bpoints_exp = Rank_Packs[client].ReadFloat();
					FormatEx(info, sizeof(info), "NO%d：%s(%.2f点)", i + 1, player_name, minute_bpoints_exp);
					SubRankMenu.DrawText(info);
				}
			}
		}
		delete Rank_Packs[client];
		Rank_Packs[client] = null;
		delete All_Rank_Packs[client];
		All_Rank_Packs[client] = null;
		SubRankMenu.DrawText("----------");
		SubRankMenu.DrawItem("返回", ITEMDRAW_CONTROL);
		SubRankMenu.DrawItem("离开", ITEMDRAW_CONTROL);
		SubRankMenu.Send(client, RankMenu_SubHandler, MENU_TIME_FOREVER);
	}
	return Plugin_Continue;
}

// 菜单句柄
public int RankMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char steamID[32] = {'\0'}, info[32] = {'\0'}, sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
		bool have_steamID = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
		if (!have_steamID && strcmp(player_information[client].Player_SteamID, NULL_STRING) != 0)
		{
			strcopy(steamID, sizeof(steamID), player_information[client].Player_SteamID);
		}
		else if (!have_steamID)
		{
			KickClient(client, DB_STEAMID_ERROR_KICK);
			CPrintToChatAll(INFO_STEAMID_KICK, client);
			ResetLogInfos(false, client);
			return 0;
		}
		menu.GetItem(item, info, sizeof(info));
		DataPack pack = new DataPack();
		pack.WriteCell(client);
		if (strcmp(info, "Total_PlayTime") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Total_Play_Time", "Total_Play_Time", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_TOTAL_PLAYTIME, TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_TOTAL_PLAYTIME, sql_statement);
			pack.WriteCell(RANK_TOTAL_PLAYTIME);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Max_PlayTime") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Max_Pre_Play_Time", "Max_Pre_Play_Time", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_MAX_PLAYTIME, TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_MAX_PLAYTIME, sql_statement);
			pack.WriteCell(RANK_MAX_PLAYTIME);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_Level") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Level", "Level", TABLENAME_BPOINTS_AND_SKILL, steamID, TABLENAME_BPOINTS_AND_SKILL);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_LEVEL, TABLENAME_BPOINTS_AND_SKILL, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_PLAYER_LEVEL, sql_statement);
			pack.WriteCell(RANK_PLAYER_LEVEL);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_BPoints") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "BPoints", "BPoints", TABLENAME_BPOINTS_AND_SKILL, steamID, TABLENAME_BPOINTS_AND_SKILL);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_BPOINTS, TABLENAME_BPOINTS_AND_SKILL, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_PLAYER_BPOINTS, sql_statement);
			pack.WriteCell(RANK_PLAYER_BPOINTS);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_Exps") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Exps", "Exps", TABLENAME_BPOINTS_AND_SKILL, steamID, TABLENAME_BPOINTS_AND_SKILL);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_EXPS, TABLENAME_BPOINTS_AND_SKILL, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_PLAYER_EXPS, sql_statement);
			pack.WriteCell(RANK_PLAYER_EXPS);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "SI_Killed") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Total_Play_Time", "Total_Play_Time", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_SI_KILLED, TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_SI_KILLED, sql_statement);
			pack.WriteCell(RANK_SI_KILLED);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "CI_Killed") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Total_CI_Killed", "Total_CI_Killed", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_CI_KILLED, TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_CI_KILLED, sql_statement);
			pack.WriteCell(RANK_CI_KILLED);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_Map_Played") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Total_Played_Maps", "Total_Played_Maps", TABLENAME_PLAYER_MAPS, steamID, TABLENAME_PLAYER_MAPS);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_MAP_PLAYED, TABLENAME_PLAYER_MAPS, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_MAP_PLAYED, sql_statement);
			pack.WriteCell(RANK_MAP_PLAYED);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Player_FF") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "FF_Damage", "FF_Damage", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_FF, TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_FF, sql_statement);
			pack.WriteCell(RANK_FF);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "HeadShot_Rate") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "HeadShot_Rate", "HeadShot_Rate", TABLENAME_PLAYER_INFORMATION, steamID, TABLENAME_PLAYER_INFORMATION);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_HEADSHOT_RATE, TABLENAME_PLAYER_INFORMATION, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_HEADSHOT_RATE, sql_statement);
			pack.WriteCell(RANK_HEADSHOT_RATE);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Minute_BPoints") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Minutes_BPoints", "Minutes_BPoints", TABLENAME_BPOINTS_AND_SKILL, steamID, TABLENAME_BPOINTS_AND_SKILL);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_MINUTE_BPOINTS, TABLENAME_BPOINTS_AND_SKILL, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_MINUTE_BPOINTS, sql_statement);
			pack.WriteCell(RANK_MINUTE_BPOINTS);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
		else if (strcmp(info, "Minute_Exps") == 0)
		{
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYER_ALLRANK, "Minutes_Exps", "Minutes_Exps", TABLENAME_BPOINTS_AND_SKILL, steamID, TABLENAME_BPOINTS_AND_SKILL);
			DQL_PlayerRank(client, RANK_PLAYER_ALLRANK, sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DQL_MINUTE_EXPS, TABLENAME_BPOINTS_AND_SKILL, g_hRankLimit.IntValue);
			DQL_PlayerRank(client, RANK_MINUTE_EXPS, sql_statement);
			pack.WriteCell(RANK_MINUTE_EXPS);
			CreateTimer(SHOW_DELAY, Timer_DrawRankMenu, pack);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
public int RankMenu_SubHandler(Menu menu, MenuAction action, int client, int item)
{
	if (item == 1)
	{
		Draw_RankMenu(client);
		EmitSoundToClient(client, BUTTON_SOUND, _);
	}
	else if (item == 2)
	{
		delete menu;
	}
	return 0;
}
public Action Timer_DrawRankMenu(Handle timer, DataPack pack)
{
	if (pack != null)
	{
		pack.Reset();
		int client = pack.ReadCell();
		RANK_TYPE type = pack.ReadCell();
		Draw_SubRankMenu(client, type);
		delete pack;
	}
	return Plugin_Continue;
}

void DQL_PlayerRank(int client, RANK_TYPE Type, const char[] information)
{
	if (db_TreeServer != null)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(client);
		pack.WriteCell(Type);
		switch (Type)
		{
			case RANK_PLAYER_ALLRANK: db_TreeServer.Query(DQL_PlayerAllRankCallBack, information, pack);
			default: db_TreeServer.Query(DQL_PlayerRankCallBack, information, pack);
		}
	}
}
void DQL_PlayerAllRankCallBack(Database db, DBResultSet results, const char[] error, DataPack pack = null)
{
	if (db != null && results != null && strcmp(error, NULL_STRING) == 0)
	{
		if (pack != null)
		{
			pack.Reset();
			int client = pack.ReadCell();
			delete pack;
			DataPack client_pack = new DataPack();
			while (results.FetchRow())
			{
				int my_rank = results.FetchInt(0);
				client_pack.WriteCell(my_rank);
			}
			All_Rank_Packs[client] = client_pack;
		}
	}
	else if (db == null)
	{
		PrintToServer(DB_CONNECT_INVALID_HANDLE);
	}
	else
	{
		PrintToServer(DB_MANAGE_ERROR, DBNAME, error);
	}
}
void DQL_PlayerRankCallBack(Database db, DBResultSet results, const char[] error, DataPack pack = null)
{
	if (db != null && results != null && strcmp(error, NULL_STRING) == 0)
	{
		if (pack != null)
		{
			pack.Reset();
			int client = pack.ReadCell();
			RANK_TYPE type = pack.ReadCell();
			delete pack;
			DataPack client_pack = new DataPack();
			char player_name[MAX_NAME_LENGTH] = {'\0'};
			client_pack.WriteCell(results.RowCount);
			switch (type)
			{
				case RANK_TOTAL_PLAYTIME, RANK_MAX_PLAYTIME:
				{
					while (results.FetchRow())
					{
						results.FetchString(0, player_name, sizeof(player_name));
						GetClientFixedName(player_name, sizeof(player_name));
						client_pack.WriteString(player_name);
						int play_time = results.FetchInt(1);
						client_pack.WriteString(FormatDuration(play_time, true));
					}
					Rank_Packs[client] = client_pack;
				}
				case RANK_PLAYER_LEVEL, RANK_PLAYER_BPOINTS, RANK_PLAYER_EXPS, RANK_SI_KILLED, RANK_CI_KILLED, RANK_MAP_PLAYED:
				{
					while (results.FetchRow())
					{
						results.FetchString(0, player_name, sizeof(player_name));
						GetClientFixedName(player_name, sizeof(player_name));
						client_pack.WriteString(player_name);
						int level_bpoints_exp = results.FetchInt(1);
						client_pack.WriteCell(level_bpoints_exp);
					}
					Rank_Packs[client] = client_pack;
				}
				case RANK_FF:
				{
					while (results.FetchRow())
					{
						results.FetchString(0, player_name, sizeof(player_name));
						GetClientFixedName(player_name, sizeof(player_name));
						client_pack.WriteString(player_name);
						int player_ff_count = results.FetchInt(1);
						client_pack.WriteCell(player_ff_count);
						int player_ff_damage = results.FetchInt(2);
						client_pack.WriteCell(player_ff_damage);
					}
					Rank_Packs[client] = client_pack;
				}
				case RANK_HEADSHOT_RATE:
				{
					while (results.FetchRow())
					{
						results.FetchString(0, player_name, sizeof(player_name));
						GetClientFixedName(player_name, sizeof(player_name));
						client_pack.WriteString(player_name);
						int total_killed = results.FetchInt(1);
						client_pack.WriteCell(total_killed);
						int headshot_count = results.FetchInt(2);
						client_pack.WriteCell(headshot_count);
						float headshot_rate = results.FetchFloat(3);
						client_pack.WriteFloat(headshot_rate);
					}
					Rank_Packs[client] = client_pack;
				}
				case RANK_MINUTE_BPOINTS, RANK_MINUTE_EXPS:
				{
					while (results.FetchRow())
					{
						results.FetchString(0, player_name, sizeof(player_name));
						GetClientFixedName(player_name, sizeof(player_name));
						client_pack.WriteString(player_name);
						float minute_bpoints_exp = results.FetchFloat(1);
						client_pack.WriteFloat(minute_bpoints_exp);
					}
					Rank_Packs[client] = client_pack;
				}
			}
		}
	}
	else if (db == null)
	{
		PrintToServer(DB_CONNECT_INVALID_HANDLE);
	}
	else
	{
		PrintToServer(DB_MANAGE_ERROR, DBNAME, error);
	}
}
void GetClientFixedName(char[] name, int length)
{
	if (name[0] == '[')
	{
		char temp[MAX_NAME_LENGTH] = {'\0'};
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp)-2] = 0;
		strcopy(name[1], length-1, temp);
		name[0] = ' ';
	}
	if (strlen(name) > 18)
	{
		name[15] = name[16] = name[17] = '.';
		name[18] = 0;
	}
}