#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include "treeutil\treeutil.sp"

#define CVAR_FLAGS FCVAR_NOTIFY
#define DBNAME "treeserver"
#define DBCHARSET "UTF8MB4"
#define SQL_STATEMENT_MAX_LENGTH 512
// 表名称
#define TABLENAME_PLAYER_INFORMATION "Player_Information_Table"
#define TABLENAME_BPOINTS_AND_SKILL "Bpoints_Level_Skill_Table"
#define TABLENAME_PLAYER_MAPS "Player_Campaign_Table"
#define TABLENAME_PLAYER_TAGS "Player_Tags_Table"
// 建表语句
#define CREATE_TABLE_PLAYER_INFORMATION \
"CREATE TABLE IF NOT EXISTS Player_Information_Table\
(\
	STEAM_ID VARCHAR(32) PRIMARY KEY NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '玩家 SteamID',\
	Player_Name VARCHAR(64) NOT NULL DEFAULT 'NO_NAME_RECORD' COMMENT '玩家 ID',\
	Last_Play_Time DATETIME DEFAULT NULL COMMENT '玩家最后一次退出服务器时间',\
	Total_Play_Time BIGINT UNSIGNED	NOT NULL DEFAULT 0 COMMENT '玩家总游玩时长',\
	Max_Pre_Play_Time BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家单次最大游玩时长',\
	Total_SI_Killed BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '特感总击杀数量',\
	Total_CI_Killed BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '丧尸总击杀数量',\
	HeadShot_Count BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家爆头总数量',\
	HeadShot_Rate FLOAT NOT NULL DEFAULT 0.0 COMMENT '玩家爆头率',\
	Smoker_Killed BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Smoker 总击杀数量',\
	Boomer_Killed BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Boomer 总击杀数量',\
	Hunter_Killed BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Hunter 总击杀数量',\
	Spitter_Killed BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Spitter 总击杀数量',\
	Jockey_Killed BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Jockey 总击杀数量',\
	Charger_Killed BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Charger 总击杀数量',\
	Witch_Killed BIGINT UNSIGNED NOT NULL DEFAULT '0' COMMENT 'Witch 总击杀数量',\
	FF_Count BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '黑枪次数',\
	FF_Damage BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '黑枪总伤害'\
) ENGINE = INNODB DEFAULT CHARSET = UTF8MB4 COMMENT '玩家信息表';"
#define CREATE_TABLE_PLAYER_BPOINTS_AND_SKILL \
"CREATE TABLE IF NOT EXISTS Bpoints_Level_Skill_Table\
(\
	STEAM_ID VARCHAR(32) PRIMARY KEY NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '玩家 SteamID',\
	Player_Name VARCHAR(64) NOT NULL DEFAULT 'NO_NAME_RECORD' COMMENT '玩家 ID',\
	Level BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家等级',\
	BPoints BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家 B 数',\
	Exps BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家经验值',\
	Round_Max_BPoints BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家每局游戏获得的最大 B 数值',\
	Round_Max_Exps BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家每局游戏获得的最大经验值',\
	Minutes_BPoints FLOAT NOT NULL DEFAULT 0.0 COMMENT '玩家每分钟获取的 B 数值',\
	Minutes_Exps FLOAT NOT NULL DEFAULT 0.0 COMMENT '玩家每分钟获取的经验值',\
	First_Skill TINYINT UNSIGNED NOT NULL DEFAULT 0 CHECK (First_Skill >= 0 AND First_Skill <= 1) COMMENT '玩家出门近战技能的等级',\
	Second_Skill TINYINT UNSIGNED NOT NULL DEFAULT 0 CHECK (Second_Skill >= 0 AND Second_Skill <= 2) COMMENT '玩家杀特回血技能的等级',\
	Melee_Type TINYINT UNSIGNED NOT NULL DEFAULT 0 CHECK (Melee_Type >= 0 AND Melee_Type <= 13) COMMENT '玩家出门近战武器 ID',\
	Custom_Designation varchar(16) NOT NULL DEFAULT 'NO_DESIGNATION' COMMENT '玩家自定义称号'\
) ENGINE = INNODB DEFAULT CHARSET = UTF8MB4 COMMENT '玩家 B 数，经验，技能信息表';"
#define CREATE_TABLE_PLAYER_MAPS \
"CREATE TABLE IF NOT EXISTS Player_Campaign_Table\
(\
	STEAM_ID VARCHAR(32) PRIMARY KEY NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '玩家 SteamID',\
	Player_Name VARCHAR(64) NOT NULL DEFAULT 'NO_NAME_RECORD' COMMENT '玩家 ID',\
	Total_Played_Maps BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家游玩总地图数量'\
) ENGINE = INNODB DEFAULT CHARSET = UTF8MB4 COMMENT '玩家游玩地图数量表';"
#define CREATE_TABLE_PLAYER_TAGS \
"CREATE TABLE IF NOT EXISTS Player_Tags_Table\
(\
	Player_Designation varchar(32) NOT NULL DEFAULT 'No_Designation' COMMENT '称号名称',\
	Min_Level BIGINT UNSIGNED PRIMARY KEY NOT NULL DEFAULT 0 COMMENT '该称号需要的最小等级',\
	Max_Level BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '该称号需要的最大等级'\
) ENGINE = INNODB DEFAULT CHARSET = UTF8MB4 COMMENT '玩家称号表';"
#define INSERT_INFO_DEFAULT_TAGS \
"INSERT INTO player_tags_table VALUES ('初入修仙','0','10'), ('炼气初期','11','30'), ('炼气中期','31','60'), ('炼气后期','61','100'), ('筑基初期','101','130'), ('筑基中期','131','160'), \
('筑基后期','161','200'), ('金丹初期','201','230'), ('金丹中期','231','260'), ('金丹后期','261','300'), ('元婴初期','301','330'), ('元婴中期','331','360'), ('元婴后期','361','400'), \
('出窍初期','401','430'), ('出窍中期','431','460'), ('出窍后期','461','500'), ('分神初期','501','530'), ('分神中期','531','560'), ('分神后期','561','600'), ('渡劫初期','601','630'), \
('渡劫中期','631','660'), ('渡劫后期','661','700'), ('真仙初期','701','730'), ('真仙中期','731','760'), ('真仙后期','761','800'), ('天仙初期','801','830'), ('天仙中期','831','860'), \
('天仙后期','861','900'), ('金仙初期','901','930'), ('金仙中期','931','960'), ('金仙后期','961','1000'), ('玄仙初期','1001','1030'), ('玄仙中期','1031','1060'), ('玄仙后期','1061','1100'), \
('仙君初期','1101','1130'), ('仙君中期','1131','1160'), ('仙君后期','1161','1200'), ('仙帝初期','1201','1230'), ('仙帝中期','1231','1260'), ('仙帝后期','1261','1300'), ('仙尊初期','1301','1330'), \
('仙尊中期','1331','1360'), ('仙尊后期','1361','1400'), ('神人初期','1401','1430'), ('神人中期','1431','1460'), ('神人后期','1461','1500'), ('真神初期','1501','1530'), ('真神中期','1531','1560'), \
('真神后期','1561','1600'), ('天神初期','1601','1630'), ('天神中期','1631','1660'), ('天神后期','1661','1700'), ('神君初期','1701','1730'), ('神君中期','1731','1760'), ('神君后期','1761','1800'), \
('神帝初期','1801','1830'), ('神帝中期','1831','1860'), ('神帝后期','1861','1900'), ('神尊初期','1901','1930'), ('神尊中期','1931','1960'), ('神尊后期','1961','2000'), ('天尊初期','2001','2030'), \
('天尊中期','2031','2060'), ('天尊后期','2061','2100'), ('至尊初期','2101','2130'), ('至尊中期','2131','2160'), ('至尊后期','2161','2200'), ('至高之境','2201','999999999');"
// 连接成功失败报错提示
#define DB_CONNECT_SUCCESS "【TreeServer】：连接数据库：%s 成功"
#define DB_CONNECT_FAIL "【TreeServer】：连接数据库：%s 失败，错误信息：%s"
#define DB_CONNECT_INVALID_HANDLE "【TreeServer】：数据库句柄为空，无法连接到数据库：%s"
#define DB_MANAGE_ERROR "【TreeServer】：对数据库：%s 进行操作时发生错误，错误信息：%s"
#define DB_QUERY_CLIENT_INFO_FAIL "【TreeServer】：查询玩家：%N 的相关信息失败，错误信息：%s"
#define DB_STEAMID_ERROR_KICK "【TreeServer】：无法获取您的 SteamID，请重新连接好友网络或重试"
#define DB_CREATE_TABLE_SUCCESS "【TreeServer】：成功于数据库：%s 中创建数据表：%s %s %s %s [%s]"
#define DB_ADD_COLUMN_SUCCESS "【TreeServer】：成功于数据表：%s 中添加字段：%s [%s]"
#define INFO_PLAYERINFO "※成功获取到玩家：%N 的基本信息：总游玩时长：%s，最大游玩时长：%s，特感总击杀：%d，丧尸总击杀：%d，等级：%d，B数：%d，经验：%d [%s]"
#define INFO_PLAYERDEFTAGS "※成功获取到玩家：%N 的基本称号：%s"
#define INFO_STEAMID_KICK "{O}[提示]：{LG}无法获取玩家：{O}%N {LG}的SteamID，已将其踢出"
// 插件日志保存位置
#define LOG_PLAYERMESSAGE_PATH "/ServerLog/%s_ChatLog.log"
#define LOG_FILE_PATH "/ServerLog/TreeServer_Database.log"
// SQL 语句
#define DQL_HAS_TABLES "SHOW TABLES LIKE '%s';"
#define DML_UPDATE_PLAYER_INFO "INSERT INTO %s (STEAM_ID, Player_Name) VALUES ('%s', '%s') AS NEW ON DUPLICATE KEY UPDATE Player_Name = %s.`Player_Name`;"
#define DML_ADD_MAPS "ALTER TABLE %s ADD %s BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '玩家游玩地图：%s 次数';"
#define DML_ADD_MAP_PLAYTIMES "INSERT INTO %s (STEAM_ID, Player_Name, Total_Played_Maps, %s) VALUES ('%s', '%s', 1, 1) AS NEW ON DUPLICATE KEY UPDATE Total_Played_Maps = %s.Total_Played_Maps + 1, %s = %s.%s + 1;"
#define DQL_PLAYERINFO "SELECT INFO.`Total_Play_Time`, INFO.`Max_Pre_Play_Time`, INFO.`Total_SI_Killed`, INFO.`Total_CI_Killed`, INFO.`HeadShot_Count`, INFO.`HeadShot_Rate`, \
INFO.`Smoker_Killed`, INFO.`Boomer_Killed`, INFO.`Hunter_Killed`, INFO.`Spitter_Killed`, INFO.`Jockey_Killed`, INFO.`Charger_Killed`, INFO.`Witch_Killed`, INFO.`FF_Count`, INFO.`FF_Damage`, Points.`Level`, POINTS.`BPoints`, POINTS.`Exps`, \
POINTS.`Round_Max_BPoints`, POINTS.`Round_Max_Exps`, POINTS.`Minutes_BPoints`, POINTS.`Minutes_Exps`, POINTS.`First_Skill`, POINTS.`Second_Skill`, POINTS.`Melee_Type`, \
CP.`Total_Played_Maps`, POINTS.`Custom_Designation`, TAGS.`Player_Designation` FROM %s AS INFO, %s AS POINTS, %s AS CP, %s AS TAGS \
WHERE INFO.`STEAM_ID` = '%s' AND POINTS.`STEAM_ID` = '%s' AND CP.`STEAM_ID` = '%s' AND POINTS.`Level` BETWEEN TAGS.`Min_Level` AND TAGS.`Max_Level`;"
#define DML_UPDATE_ALL_DATA "UPDATE %s AS INFO, %s AS POINTS SET INFO.`Total_Play_Time` = INFO.`Total_Play_Time` + %d, INFO.`Last_Play_Time` = NOW(), INFO.`Max_Pre_Play_Time` = \
IF(INFO.`Max_Pre_Play_Time` < %d, %d, INFO.`Max_Pre_Play_Time`), INFO.`Total_SI_Killed` = %d, INFO.`Total_CI_Killed` = %d, INFO.`HeadShot_Count` = %d, INFO.`HeadShot_Rate` = %f, \
INFO.`Smoker_Killed` = %d, INFO.`Boomer_Killed` = %d, INFO.`Hunter_Killed` = %d, INFO.`Spitter_Killed` = %d, INFO.`Jockey_Killed` = %d, INFO.`Charger_Killed` = %d, INFO.`Witch_Killed` = %d, INFO.`FF_Count` = %d, \
INFO.`FF_Damage` = %d, Points.`Level` = %d, POINTS.`BPoints` = %d, POINTS.`Exps` = %d, POINTS.`Round_Max_BPoints` = IF(POINTS.Round_Max_BPoints < %d, %d, POINTS.Round_Max_BPoints), POINTS.`Round_Max_Exps` = IF(POINTS.Round_Max_Exps < %d, %d, POINTS.Round_Max_Exps), POINTS.`Minutes_BPoints` = %f, \
POINTS.`Minutes_Exps` = %f, POINTS.`First_Skill` = %d, POINTS.`Second_Skill` = %d, POINTS.`Melee_Type` = %d, POINTS.`Custom_Designation` = '%s' WHERE INFO.`STEAM_ID` = '%s' AND POINTS.`STEAM_ID` = '%s';"

// 查询类型
enum DQL_DATATYPE
{
	PLAYER_INFORMATION,
	PLAYER_CAMPAIGN,
	PLAYER_TAGS,
	QUERY_HAS_TABLES,
	QUERY_HAS_MAPS
}
// 玩家基本信息结构体
enum struct Player_Info
{
	int Last_Login_Time;
	char Player_SteamID[32];
	void InitInfo()
	{
		this.Last_Login_Time = -1;
		strcopy(this.Player_SteamID, 32, NULL_STRING);
	}
}
Player_Info player_information[MAXPLAYERS + 1];
enum struct Player_Data
{
	int Play_Time;
	int Max_Play_Time;
	int Player_Level;
	int Player_BPoints;
	int Player_Exp;
	int Player_First_Skill;
	int Player_Second_Skill;
	int Player_Melee;
	int Round_Max_BPoints;
	int Round_Max_Exp;
	int SI_Killed;
	int CI_Killed;
	int Smoker_Killed;
	int Boomer_Killed;
	int Hunter_Killed;
	int Spitter_Killed;
	int Jockey_Killed;
	int Charger_Killed;
	int Witch_Killed;
	int FF_Count;
	int FF_Damage;
	int Total_Played_Maps;
	int HeadShot_Count;
	float HeadShot_Rate;
	float Minutes_BPoints;
	float Minutes_Exps;
	bool Require_Success;
	bool Not_First_Buy;
	char Player_Custom_Designation[64];
	char Player_Default_Designation[64];
	void InitStatus()
	{
		this.Play_Time = this.Max_Play_Time = this.Player_Level = this.Player_Exp = this.Player_First_Skill = this.Player_Second_Skill = this.Player_Melee = this.Round_Max_BPoints
		= this.Round_Max_Exp = this.SI_Killed = this.CI_Killed = this.Smoker_Killed = this.Boomer_Killed = this.Hunter_Killed = this.Spitter_Killed = this.Jockey_Killed
		= this.Charger_Killed = this.Witch_Killed = this.HeadShot_Count = this.Total_Played_Maps = this.FF_Count = this.FF_Damage = 0;
		this.HeadShot_Rate = this.Minutes_BPoints = this.Minutes_Exps = 0.0;
		this.Require_Success = this.Not_First_Buy = false;
		strcopy(this.Player_Custom_Designation, 64, NULL_STRING);
		strcopy(this.Player_Default_Designation, 64, NULL_STRING);
	}
}
Player_Data player_data[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name 			= "TreeServer RPG",
	author 			= "夜羽真白",
	description 	= "配合使用 MySQL 数据库记录玩家修仙信息插件",
	version 		= "2.0.0.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// 数据库全局句柄
Database db_TreeServer = null;
// Handles
Handle h_LogFileHandle = INVALID_HANDLE, h_MessageHandle = INVALID_HANDLE;
// ConVars
ConVar g_hRecordLog, g_hRecordMessage, g_hRecordSteamID, g_hAnnounceConnect;
// Chars
char log_file_path[PLATFORM_MAX_PATH] = {'\0'}, message_file_path[PLATFORM_MAX_PATH] = {'\0'};

// 加载其他文件
#include "rpgdatabases\menus.sp"
#include "rpgdatabases\rankmenus.sp"

public void OnPluginStart()
{
	char file_name[64] = {'\0'}, query_database[64] = {'\0'};
	g_hRecordLog = CreateConVar("Database_RecordLog", "1", "数据库连接时或操作时是否记录日志", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hRecordMessage = CreateConVar("Database_RecordMessage", "1", "玩家说话或加入退出时是否记录信息", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hRecordSteamID = CreateConVar("Database_RecordSteamID", "1", "玩家说话或加入退出时记录玩家的 STEAMID 与 IP 地址", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hAnnounceConnect = CreateConVar("Database_RecordConnection", "1", "玩家加入退出时是否为其他玩家显示加入退出信息", CVAR_FLAGS, true, 0.0, true, 1.0);
	HookEvent("round_end", evt_UpdateAllData, EventHookMode_PostNoCopy);
	// 战役过图，不会触发 round_end，使用 map_transition 上传数据
	HookEvent("map_transition", evt_UpdateAllData, EventHookMode_PostNoCopy);
	// 救援载具离开，不会触发 round_end，使用 finale_vehicle_leaving 上传数据
	HookEvent("finale_vehicle_leaving", evt_UpdateAllData, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", evt_PlayerDisconnect, EventHookMode_Pre);
	// 重置玩家基本信息
	ResetLogInfos(true);
	// 插件启动时，首次连接数据库
	if (db_TreeServer != null)
	{
		delete db_TreeServer;
		db_TreeServer = null;
	}
	if (ConnectDatabase())
	{
		// 插件启动时，检查数据库中是否有数据表，没有则创建新的数据表
		FormatEx(query_database, sizeof(query_database), DQL_HAS_TABLES, TABLENAME_PLAYER_INFORMATION);
		DQL_QueryData(-1, QUERY_HAS_TABLES, query_database);
		FormatEx(query_database, sizeof(query_database), DQL_HAS_TABLES, TABLENAME_BPOINTS_AND_SKILL);
		DQL_QueryData(-1, QUERY_HAS_TABLES, query_database);
		FormatEx(query_database, sizeof(query_database), DQL_HAS_TABLES, TABLENAME_PLAYER_MAPS);
		DQL_QueryData(-1, QUERY_HAS_TABLES, query_database);
		FormatEx(query_database, sizeof(query_database), DQL_HAS_TABLES, TABLENAME_PLAYER_TAGS);
		DQL_QueryData(-1, QUERY_HAS_TABLES, query_database);
	}
	// 记录玩家日志与插件运行日志
	FormatEx(file_name, sizeof(file_name), LOG_PLAYERMESSAGE_PATH, GetCurrentDate(false));
	BuildPath(Path_SM, message_file_path, sizeof(message_file_path), file_name);
	BuildPath(Path_SM, log_file_path, sizeof(log_file_path), LOG_FILE_PATH);
	// 加载其他文件
	Menus_OnModuleStart();
	RankMenus_OnModuleStart();
}
// sm plugins unload_all 不会触发每个插件的 OnPluginEnd 函数，需要手动卸载
public void OnPluginEnd()
{
	UpdateAllPlayerData();
}

public void OnMapStart()
{
	// 更换新地图时，重新连接一次数据库
	if (db_TreeServer != null)
	{
		delete db_TreeServer;
		db_TreeServer = null;
	}
	if (ConnectDatabase())
	{
		// 识别当前地图名称
		char map_name[32] = {'\0'}, file_name[64] = {'\0'}, sql_statement[128] = {'\0'};
		GetCurrentMap(map_name, sizeof(map_name));
		// 玩家游玩地图表中是否有此地图名称，无则添加新列
		FormatEx(sql_statement, sizeof(sql_statement), "SELECT %s FROM %s;", map_name, TABLENAME_PLAYER_MAPS);
		DQL_QueryData(-1, QUERY_HAS_MAPS, sql_statement);
		FormatEx(file_name, sizeof(file_name), LOG_PLAYERMESSAGE_PATH, GetCurrentDate(false));
		BuildPath(Path_SM, message_file_path, sizeof(message_file_path), file_name);
		if (g_hRecordLog.BoolValue)
		{
			FormatEx(sql_statement, sizeof(sql_statement), "【TreeServer】：当前地图：%s 开始，连接数据库：%s 成功 [%s]", map_name, DBNAME, GetCurrentDate(true));
			SaveDatabaseLogMessage(sql_statement);
		}
	}
	// 加载其他文件
	Menus_OnMapStart();
}

// *********************
// 		 玩家相关
// *********************
// 重置玩家登录信息
void ResetLogInfos(bool reset_all, int client = -1)
{
	if (reset_all && client == -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			player_information[i].InitInfo();
			player_data[i].InitStatus();
		}
	}
	else if (!reset_all && IsValidClient(client))
	{
		player_information[client].InitInfo();
		player_data[client].InitStatus();
	}
}
// 玩家完全进入服务器时，加入玩家信息条目
void InsertPlayerInfo(int client, const char[] steamID)
{
	player_information[client].Last_Login_Time = GetTime();
	strcopy(player_information[client].Player_SteamID, 32, steamID);
}
// 获取玩家此次游玩时间
int GetPlayTime(int client, const char[] steamID)
{
	if (player_information[client].Last_Login_Time != -1 && strcmp(player_information[client].Player_SteamID, steamID) == 0)
	{
		return player_information[client].Last_Login_Time;
	}
	return -1;
}
// 玩家进入服务器
public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		char map_name[32] = {'\0'}, steamID[32] = {'\0'}, player_name[MAX_NAME_LENGTH] = {'\0'}, player_ip[32] = {'\0'}, sql_statement[2 * SQL_STATEMENT_MAX_LENGTH] = {'\0'};
		GetCurrentMap(map_name, sizeof(map_name));
		if (GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID)))
		{
			GetClientIP(client, player_ip, sizeof(player_ip));
			GetClientName(client, player_name, sizeof(player_name));
			if (g_hRecordLog.BoolValue && g_hRecordSteamID.BoolValue)
			{
				FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%N (STEAMID：%s，IP：%s) 加入服务器 [%s]", client, steamID, player_ip, GetCurrentDate(true));
				SaveDatabaseLogMessage(sql_statement);
			}
			else if (g_hRecordLog.BoolValue)
			{
				FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%N 加入服务器 [%s]", client, GetCurrentDate(true));
				SaveDatabaseLogMessage(sql_statement);
			}
			// 根据当前加入的玩家的 STEAMID 将当前玩家信息加入到数组与数据库中
			InsertPlayerInfo(client, steamID);
			FormatEx(sql_statement, sizeof(sql_statement), DML_UPDATE_PLAYER_INFO, TABLENAME_PLAYER_INFORMATION, steamID, player_name, TABLENAME_PLAYER_INFORMATION);
			DML_ManageData(sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DML_UPDATE_PLAYER_INFO, TABLENAME_BPOINTS_AND_SKILL, steamID, player_name, TABLENAME_BPOINTS_AND_SKILL);
			DML_ManageData(sql_statement);
			FormatEx(sql_statement, sizeof(sql_statement), DML_UPDATE_PLAYER_INFO, TABLENAME_PLAYER_MAPS, steamID, player_name, TABLENAME_PLAYER_MAPS);
			DML_ManageData(sql_statement);
			// 增加玩家游玩的地图数量
			FormatEx(sql_statement, sizeof(sql_statement), DML_ADD_MAP_PLAYTIMES, TABLENAME_PLAYER_MAPS, map_name, steamID, player_name, TABLENAME_PLAYER_MAPS, map_name, TABLENAME_PLAYER_MAPS, map_name);
			DML_ManageData(sql_statement);
			// 查询当前玩家的所有信息
			FormatEx(sql_statement, sizeof(sql_statement), DQL_PLAYERINFO, TABLENAME_PLAYER_INFORMATION, TABLENAME_BPOINTS_AND_SKILL, TABLENAME_PLAYER_MAPS, TABLENAME_PLAYER_TAGS, steamID, steamID, steamID);
			DQL_QueryData(client, PLAYER_INFORMATION, sql_statement);
			player_data[client].Require_Success = true;
			if (g_hAnnounceConnect.BoolValue)
			{
				DataPack pack = new DataPack();
				pack.WriteCell(client);
				pack.WriteString(steamID);
				pack.WriteString(player_ip);
				CreateTimer(SHOW_DELAY, Timer_AnnounceJoin, pack);
			}
		}
		else
		{
			KickClient(client, DB_STEAMID_ERROR_KICK);
			CPrintToChatAll(INFO_STEAMID_KICK, client);
			ResetLogInfos(false, client);
		}
	}
}
public Action Timer_AnnounceJoin(Handle timer, DataPack pack)
{
	if (pack != null)
	{
		pack.Reset();
		int client = pack.ReadCell();
		char steamID[32] = {'\0'}, player_ip[32] = {'\0'};
		pack.ReadString(steamID, sizeof(steamID));
		pack.ReadString(player_ip, sizeof(player_ip));
		if (g_hRecordSteamID.BoolValue)
		{
			if (player_data[client].Require_Success && player_data[client].Play_Time != 0)
			{
				CPrintToChatAll("{O}%N {LG}<%s> {W}正在进入服务器\n本服务器内游玩时间：{O}%s", client, steamID, FormatDuration(player_data[client].Play_Time));
			}
			else
			{
				CPrintToChatAll("{O}%N {LG}<%s> {W}正在进入服务器", client, steamID);
			}
		}
		else if (g_hAnnounceConnect.BoolValue)
		{
			if (player_data[client].Require_Success && player_data[client].Play_Time != 0)
			{
				CPrintToChatAll("{O}%N {W}正在进入服务器\n本服务器内游玩时间：{O}%s", client, FormatDuration(player_data[client].Play_Time));
			}
			else
			{
				CPrintToChatAll("{O}%N {W}正在进入服务器", client);
			}
		}
		delete pack;
	}
	return Plugin_Stop;
}
// 玩家退出服务器
public void evt_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	SetEventBroadcast(event, true);
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		char steamID[32] = {'\0'}, player_ip[32] = {'\0'}, reason[64] = {'\0'}, sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
		event.GetString("reason", reason, sizeof(reason));
		// 验证退出的玩家是否可以获取 STEAMID 同时与玩家信息数组中对应玩家的 STEAMID 是否相同同时是否已经读取信息
		bool have_steamID = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
		if (!have_steamID && player_data[client].Require_Success && strcmp(player_information[client].Player_SteamID, NULL_STRING) != 0)
		{
			strcopy(steamID, sizeof(steamID), player_information[client].Player_SteamID);
		}
		else if (!have_steamID)
		{
			KickClient(client, DB_STEAMID_ERROR_KICK);
			CPrintToChatAll(INFO_STEAMID_KICK, client);
			ResetLogInfos(false, client);
			return;
		}
		GetClientIP(client, player_ip, sizeof(player_ip));
		// 更新玩家其他信息
		UpdatePlayerData(client, steamID);
		if (g_hRecordLog.BoolValue && g_hRecordSteamID.BoolValue)
		{
			if (g_hAnnounceConnect.BoolValue)
			{
				CPrintToChatAll("{O}%N {LG}<%s> {W}已退出，原因：{O}%s", client, steamID, reason);
			}
			FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%N （STEAMID：%s，IP：%s） 退出服务器，原因：%s，所有信息上传成功 [%s]", client, steamID, player_ip, reason, GetCurrentDate(true));
			SaveDatabaseLogMessage(sql_statement);
		}
		else if (g_hRecordLog.BoolValue)
		{
			if (g_hAnnounceConnect.BoolValue)
			{
				CPrintToChatAll("{O}%N {W}已退出，原因：{O}%s", client, reason);
			}
			FormatEx(sql_statement, sizeof(sql_statement), "※玩家：%N 退出服务器，原因：%s，所有信息上传成功 [%s]", client, reason, GetCurrentDate(true));
			SaveDatabaseLogMessage(sql_statement);
		}
		g_bBuckShot[client] = false;
		ResetLogInfos(false, client);
	}
}
public void evt_UpdateAllData(Event event, const char[] name, bool dontBroadcast)
{
	UpdateAllPlayerData();
}
void UpdateAllPlayerData()
{
	char steamID[32] = {'\0'};
	for (int client = 1; client <= MaxClients; client++)
	{
		player_data[client].Not_First_Buy = false;
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
		{
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
				continue;
			}
			UpdatePlayerData(client, steamID);
		}
	}
}
void UpdatePlayerData(int client, const char[] steamID)
{
	char sql_statement[3 * SQL_STATEMENT_MAX_LENGTH] = {'\0'};
	int last_login_time = GetPlayTime(client, steamID);
	if (last_login_time != -1)
	{
		int round_duration = GetTime() - last_login_time;
		float headshot_rate = CalculateEfficiency(client, HeadShot_Rate), minute_bpoints = CalculateEfficiency(client, Minutes_BPoints, player_data[client].Play_Time + round_duration), minute_exps = CalculateEfficiency(client, Minutes_Exps, player_data[client].Play_Time + round_duration);
		FormatEx(sql_statement, sizeof(sql_statement), DML_UPDATE_ALL_DATA
		, TABLENAME_PLAYER_INFORMATION, TABLENAME_BPOINTS_AND_SKILL, round_duration, round_duration, round_duration, player_data[client].SI_Killed, player_data[client].CI_Killed, player_data[client].HeadShot_Count, headshot_rate, 
		player_data[client].Smoker_Killed, player_data[client].Boomer_Killed, player_data[client].Hunter_Killed, player_data[client].Spitter_Killed, player_data[client].Jockey_Killed, 
		player_data[client].Charger_Killed, player_data[client].Witch_Killed, player_data[client].FF_Count, player_data[client].FF_Damage, player_data[client].Player_Level, player_data[client].Player_BPoints, 
		player_data[client].Player_Exp, player_data[client].Round_Max_BPoints, player_data[client].Round_Max_BPoints, player_data[client].Round_Max_Exp, player_data[client].Round_Max_Exp, minute_bpoints, minute_exps, player_data[client].Player_First_Skill, 
		player_data[client].Player_Second_Skill, player_data[client].Player_Melee, player_data[client].Player_Custom_Designation, steamID, steamID);
		DML_ManageData(sql_statement);
	}
}
// 保存数据库日志信息到文件中
void SaveDatabaseLogMessage(const char[] message)
{
	if (h_LogFileHandle == INVALID_HANDLE)
	{
		h_LogFileHandle = OpenFile(log_file_path, "a");
	}
	WriteFileLine(h_LogFileHandle, message);
	delete h_LogFileHandle;
	h_LogFileHandle = INVALID_HANDLE;
}
// 保存玩家说话或加入离开信息到日志文件中
void SavePlayerMessage(const char[] message)
{
	if (h_MessageHandle == INVALID_HANDLE)
	{
		h_MessageHandle = OpenFile(message_file_path, "a");
	}
	WriteFileLine(h_MessageHandle, message);
	delete h_MessageHandle;
	h_MessageHandle = INVALID_HANDLE;
}

// *********************
// 		数据库相关
// *********************
// 插件连接数据库
bool ConnectDatabase()
{
	if (SQL_CheckConfig(DBNAME))
	{
		char connect_error[128] = {'\0'};
		db_TreeServer = SQL_Connect(DBNAME, true, connect_error, sizeof(connect_error));
		if (db_TreeServer != null)
		{
			db_TreeServer.SetCharset(DBCHARSET);
			PrintToServer(DB_CONNECT_SUCCESS, DBNAME);
			return true;
		}
		else
		{
			PrintToServer(DB_CONNECT_FAIL, DBNAME, connect_error);
		}
	}
	return false;
}
// 使用 DML 语句向数据库进行操作，使用句柄返回操作的结果
void DML_ManageData(const char[] information)
{
	if (db_TreeServer != null)
	{
		db_TreeServer.Query(SQL_DML_QueryCallback, information);
	}
	else
	{
		PrintToServer(DB_CONNECT_INVALID_HANDLE, DBNAME);
	}
}
void SQL_DML_QueryCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (db != null)
	{
		delete db;
		db = null;
	}
	else if (db == null)
	{
		return;
	}
	else if (strcmp(error, NULL_STRING) != 0)
	{
		PrintToServer(DB_MANAGE_ERROR, DBNAME, error);
	}
}
// 使用 DQL 语句向数据库进行信息查询，使用句柄返回查询的结果
void DQL_QueryData(int client = -1, DQL_DATATYPE DataType, const char[] information)
{
	DataPack dp_ClientPack = new DataPack();
	if (db_TreeServer != null && IsValidClient(client))
	{
		dp_ClientPack.WriteCell(client);
		dp_ClientPack.WriteCell(DataType);
		db_TreeServer.Query(SQL_DQL_QueryCallback, information, dp_ClientPack);
	}
	else if (db_TreeServer != null)
	{
		dp_ClientPack.WriteCell(-1);
		dp_ClientPack.WriteCell(DataType);
		db_TreeServer.Query(SQL_DQL_QueryCallback, information, dp_ClientPack);
	}
}
void SQL_DQL_QueryCallback(Database db, DBResultSet results, const char[] error, DataPack client_pack = null)
{
	// 读取数据包信息
	client_pack.Reset();
	int client = client_pack.ReadCell();
	DQL_DATATYPE data_type = client_pack.ReadCell();
	delete client_pack;
	if (IsValidClient(client))
	{
		if (db != null && results != null && strcmp(error, NULL_STRING) == 0)
		{
			switch (data_type)
			{
				case PLAYER_INFORMATION:
				{
					DQL_QueryPlayerInformation(client, results, PLAYER_INFORMATION);
				}
			}
		}
		else
		{
			PrintToServer(DB_QUERY_CLIENT_INFO_FAIL, client, error);
		}
	}
	else
	{
		if (db != null && results != null && strcmp(error, NULL_STRING) == 0)
		{
			switch (data_type)
			{
				case QUERY_HAS_TABLES:
				{
					DQL_QueryOtherInformation(results, QUERY_HAS_TABLES);
				}
			}
		}
		else
		{
			char map_name[32] = {'\0'};
			GetCurrentMap(map_name, sizeof(map_name));
			if (strncmp(error[16], map_name, strlen(map_name)) == 0 && data_type == QUERY_HAS_MAPS)
			{
				DQL_QueryOtherInformation(results, QUERY_HAS_MAPS);
			}
			else
			{
				PrintToServer(DB_MANAGE_ERROR, DBNAME, error);
			}
		}
	}
	delete db;
	delete results;
	db = null;
	results = null;
}
// 查询玩家信息
void DQL_QueryPlayerInformation(int client, DBResultSet results, DQL_DATATYPE DataType)
{
	bool has_value = false;
	char sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
	if (results.RowCount > 0 && DataType == PLAYER_INFORMATION)
	{
		while (results.FetchRow())
		{
			has_value = true;
			player_data[client].Play_Time = results.FetchInt(0);
			player_data[client].Max_Play_Time = results.FetchInt(1);
			player_data[client].SI_Killed = results.FetchInt(2);
			player_data[client].CI_Killed = results.FetchInt(3);
			player_data[client].HeadShot_Count = results.FetchInt(4);
			player_data[client].HeadShot_Rate = results.FetchFloat(5);
			player_data[client].Smoker_Killed = results.FetchInt(6);
			player_data[client].Boomer_Killed = results.FetchInt(7);
			player_data[client].Hunter_Killed = results.FetchInt(8);
			player_data[client].Spitter_Killed = results.FetchInt(9);
			player_data[client].Jockey_Killed = results.FetchInt(10);
			player_data[client].Charger_Killed = results.FetchInt(11);
			player_data[client].Witch_Killed = results.FetchInt(12);
			player_data[client].FF_Count = results.FetchInt(13);
			player_data[client].FF_Damage = results.FetchInt(14);
			player_data[client].Player_Level = results.FetchInt(15);
			player_data[client].Player_BPoints = results.FetchInt(16);
			player_data[client].Player_Exp = results.FetchInt(17);
			player_data[client].Round_Max_BPoints = results.FetchInt(18);
			player_data[client].Round_Max_Exp = results.FetchInt(19);
			player_data[client].Minutes_BPoints = results.FetchFloat(20);
			player_data[client].Minutes_Exps = results.FetchFloat(21);
			player_data[client].Player_First_Skill = results.FetchInt(22);
			player_data[client].Player_Second_Skill = results.FetchInt(23);
			player_data[client].Player_Melee = results.FetchInt(24);
			player_data[client].Total_Played_Maps = results.FetchInt(25);
			results.FetchString(26, player_data[client].Player_Custom_Designation, 64);
			results.FetchString(27, player_data[client].Player_Default_Designation, 64);
		}
		if (has_value && g_hRecordLog.BoolValue)
		{
			FormatEx(sql_statement, sizeof(sql_statement), INFO_PLAYERINFO, client, FormatDuration(player_data[client].Play_Time), FormatDuration(player_data[client].Max_Play_Time), player_data[client].SI_Killed, player_data[client].CI_Killed, player_data[client].Player_Level, player_data[client].Player_BPoints, player_data[client].Player_Exp, GetCurrentDate(true));
			SaveDatabaseLogMessage(sql_statement);
		}
	}
	else if (results.RowCount > 0 && DataType == PLAYER_TAGS)
	{
		while (results.FetchRow())
		{	
			has_value = true;
			results.FetchString(0, player_data[client].Player_Default_Designation, 64);
		}
		if (has_value && g_hRecordLog.BoolValue)
		{
			FormatEx(sql_statement, sizeof(sql_statement), INFO_PLAYERDEFTAGS, client, player_data[client].Player_Default_Designation);
			SaveDatabaseLogMessage(sql_statement);
		}
	}
}
// 查询其他信息：数据库中是否有表，地图数据库中是否有需要自动添加的字段
void DQL_QueryOtherInformation(DBResultSet results, DQL_DATATYPE DataType)
{
	char sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
	if (DataType == QUERY_HAS_TABLES && results.RowCount == 0)
	{
		DML_ManageData(CREATE_TABLE_PLAYER_INFORMATION);
		DML_ManageData(CREATE_TABLE_PLAYER_BPOINTS_AND_SKILL);
		DML_ManageData(CREATE_TABLE_PLAYER_MAPS);
		DML_ManageData(CREATE_TABLE_PLAYER_TAGS);
		DML_ManageData(INSERT_INFO_DEFAULT_TAGS);
		FormatEx(sql_statement, sizeof(sql_statement), DB_CREATE_TABLE_SUCCESS, DBNAME, TABLENAME_PLAYER_INFORMATION, TABLENAME_BPOINTS_AND_SKILL, TABLENAME_PLAYER_MAPS, TABLENAME_PLAYER_TAGS, GetCurrentDate(true));
		if (g_hRecordLog.BoolValue)
		{
			SaveDatabaseLogMessage(sql_statement);
		}
		PrintToServer(sql_statement);
	}
	else if (DataType == QUERY_HAS_MAPS)
	{
		char map_name[32] = {'\0'};
		GetCurrentMap(map_name, sizeof(map_name));
		FormatEx(sql_statement, sizeof(sql_statement), DML_ADD_MAPS, TABLENAME_PLAYER_MAPS, map_name, map_name);
		DML_ManageData(sql_statement);
		FormatEx(sql_statement, sizeof(sql_statement), DB_ADD_COLUMN_SUCCESS, TABLENAME_PLAYER_MAPS, map_name, GetCurrentDate(true));
		if (g_hRecordLog.BoolValue)
		{
			SaveDatabaseLogMessage(sql_statement);
		}
		PrintToServer(sql_statement);
	}
}
// 时长计算
char[] FormatDuration(int duration, bool english = false)
{
	char play_time[32] = {'\0'};
	if (duration < 60)
	{
		if (english)
		{
			FormatEx(play_time, sizeof(play_time), "%ds", duration);
		}
		else
		{
			FormatEx(play_time, sizeof(play_time), "%d秒", duration);
		}
	}
	else if (duration < 3600)
	{
		int minute = duration / 60;
		if (english)
		{
			FormatEx(play_time, sizeof(play_time), "%dmin%ds", minute, duration - (minute * 60));
		}
		else
		{
			FormatEx(play_time, sizeof(play_time), "%d分钟%d秒", minute, duration - (minute * 60));
		}
	}
	else
	{
		int hour = duration / 3600;
		int minute = (duration - (hour * 3600)) / 60;
		int second = duration - ((minute * 60) + (hour * 3600));
		if (english)
		{
			FormatEx(play_time, sizeof(play_time), "%dh%dmin%ds", hour, minute, second);
		}
		else
		{
			FormatEx(play_time, sizeof(play_time), "%d小时%d分钟%d秒", hour, minute, second);
		}
	}
	return play_time;
}
// 输出当前时间
char[] GetCurrentDate(bool time = false)
{
	char current_date[32] = {'\0'};
	if (time)
	{
		FormatTime(current_date, sizeof(current_date), "%Y-%m-%d(%Hh%Mmin%Ss%p)", -1);
	}
	else
	{
		FormatTime(current_date, sizeof(current_date), "%Y-%m-%d", -1);
	}
	return current_date;
}