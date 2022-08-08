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
#define DBCHARSET "utf8mb4"
// 表名称
#define TABLENAME_PLAYER_INFOMATION "Player_Infomation_Table"
#define TABLENAME_BPOINTS_AND_SKILL "Bpoints_Level_Skill_Table"
// 建表语句
#define CREATE_TABLE_PLAYER_INFOMATION \
"CREATE TABLE IF NOT EXISTS Player_Infomation_Table \
(\
	'STEAM_ID' varchar(32), PRIMARY KEY UNIQUE NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '储存进入服务器每一位玩家的 SteamID',\
	'Player_Name' varchar(128), DEFAULT NULL COMMENT '储存进入服务器每一位玩家的名称',\
	'Total_Play_Time' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家总计在服务器中的时长',\
	'Max_Pre_Play_Time' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家单次在服务器中最大时长',\
	'Total_SI_Killed' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家击杀特感总数量',\
	'Total_CI_Killed' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家击杀丧尸总数量',\
	'Smoker_Killed' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家击杀 Smoker 总数量',\
	'Boomer_Killed' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家击杀 Boomer 总数量',\
	'Hunter_Killed' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家击杀 Hunter 总数量',\
	'Spitter_Killed' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家击杀 Spitter 总数量',\
	'Jockey_Killed' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家击杀 Jockey 总数量',\
	'Charger_Killed' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家击杀 Charger 总数量',\
	'Total_Played_Maps' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家总计游玩地图数量',\
	'Dead_Center' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C1 死亡中心地图游玩次数',\
	'Dark_Carnival' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C2 黑色狂欢节地图游玩次数',\
	'Swamp_Fever' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C3 沼泽激战地图游玩次数',\
	'Hard_Rain' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C4 暴风骤雨地图游玩次数',\
	'The_Parish' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C5 教区地图游玩次数',\
	'The_Passing' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C6 短暂时刻地图游玩次数',\
	'The_Sacrifice' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C7 牺牲地图游玩次数',\
	'No_Mercy' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C8 毫不留情地图游玩次数',\
	'Crash_Course' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C9 坠机险途地图游玩次数',\
	'Death_Toll' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C10 死亡丧钟地图游玩次数',\
	'Dead_Air' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C11 寂静时分地图游玩次数',\
	'Blood_Harvest' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C12 血腥收获地图游玩次数',\
	'Cold_Stream' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C13 刺骨寒溪地图游玩次数',\
	'The_Last_Stand' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT 'C14 临死一搏地图游玩次数',\
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT '玩家信息表'"
#define CREATE_TABLE_PLAYER_BPOINTS_AND_SKILL \
"CREATE TABLE IF NOT EXISTS Bpoints_Level_Skill_Table \
(\
	'STEAM_ID' varchar(32) PRIMARY KEY UNIQUE NOT NULL DEFAULT 'NO_STEAM_ID_RECORD' COMMENT '储存进入服务器每一位玩家的 SteamID',\
	'BPoints' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '储存玩家的 B 数',\
	'Exps' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '储存玩家的经验值',\
	'Round_Max_BPoints' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家每局游戏获得的最大 B 数值',\
	'Round_Max_Exps' bigint(20) unsigned NOT NULL DEFAULT '0' COMMENT '玩家每局游戏获得的最大经验值',\
	'First_Skill' tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '玩家出门近战技能的等级',\
	'Second_Skill' tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '玩家杀特回血技能的等级',\
	'Melee_Type' tinyint(2) unsigned NOT NULL DEFAULT '0' COMMENT '玩家出门近战武器 ID',\
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT '玩家 B 数，经验，技能信息表"
// 连接成功失败报错提示
#define DB_CONNECT_SUCCESS "【TreeServer】：连接数据库：%s 成功"
#define DB_CONNECT_FAIL "【TreeServer】：连接数据库：%s 失败，错误信息：%s"
#define DB_CONNECT_INVALID_HANDLE "【TreeServer】：数据库句柄为空，无法连接到数据库：%s"
#define DB_MANAGE_ERROR "【TreeServer】：对数据库：%s 进行操作时发生错误，错误信息：%s"
#define DB_CREATE_TABLE_SUCCESS "【TreeServer】：成功于数据库：%s 中创建数据表：%s，%s"
#define DB_QUERY_CLIENT_INFO_FAIL "【TreeServer】：查询玩家：%N 的相关信息失败，错误信息：%s"
#define DB_STEAMID_ERROR_KICK "【TreeServer】：无法获取您的 SteamID，请重新连接好友网络或重试"
// 插件日志保存位置
#define LOG_PLAYERMESSAGE_PATH "/ServerLog/%sChatLog.log"
#define LOG_FILE_PATH "/ServerLog/TreeServer_Database.log"

// 查询类型
enum DQL_DATATYPE
{
	HAS_TABLES,
	PLAYER_PLAYTIME,
	LEVELS_AND_BPOINTS,
	PLAYER_KILL,
	PLAYER_SKILL,
	PLAYER_CAMPAIGN,
	MAX_BPOINTS_AND_EXP
}
// 玩家基本信息结构体，顺序存储，并非按照客户端 ID 进行存储
enum struct Player_Info
{
	int Last_Login_Time;
	char Player_SteamID[32];
}
Player_Info player_infomation[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name 			= "",
	author 			= "夜羽真白",
	description 	= "",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// 数据库全局句柄
Database db_TreeServer = null;
// Handles
Handle h_LogFileHandle = INVALID_HANDLE, h_MessageHandle = INVALID_HANDLE;
// ConVars
ConVar g_hRecordLog, g_hRecordMessage, g_hRecordSteamID;
// Chars
char log_file_path[PLATFORM_MAX_PATH] = {'\0'}, message_file_path[PLATFORM_MAX_PATH] = {'\0'}, sql_statement[1024] = {'\0'};

public void OnPluginStart()
{
	char current_date[32] = {'\0'}, file_name[64] = {'\0'};
	g_hRecordLog = CreateConVar("Database_RecordLog", "1", "数据库连接时或操作时是否记录日志", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hRecordMessage = CreateConVar("Database_RecordMessage", "1", "玩家说话或加入退出时是否记录信息", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hRecordSteamID = CreateConVar("Database_RecordSteamID", "1", "玩家说话或加入退出时记录玩家的 STEAMID 与 IP 地址", CVAR_FLAGS, true, 0.0, true, 1.0);
	HookEvent("player_disconnect", evt_PlayerDisconnect, EventHookMode_Pre);
	// 重置玩家基本信息
	ResetAllLoginInfos();
	// 插件启动时，首次连接数据库
	if (db_TreeServer != null)
	{
		delete db_TreeServer;
		db_TreeServer = null;
	}
	ConnectDatabase();
	// 插件启动时，检查数据库中是否有数据表，没有则创建新的数据表
	DQL_QueryData(-1, HAS_TABLES, "SHOW TABLES LIKE '%s'", TABLENAME_PLAYER_INFOMATION);
	DQL_QueryData(-1, HAS_TABLES, "SHOW TABLES LIKE '%s'", TABLENAME_BPOINTS_AND_SKILL);
	// 记录玩家日志与插件运行日志
	FormatTime(current_date, sizeof(current_date), "%Y-%m-%d(%H:%M:%S%p)", -1);
	FormatEx(file_name, sizeof(file_name), LOG_PLAYERMESSAGE_PATH, current_date);
	BuildPath(Path_SM, message_file_path, sizeof(message_file_path), file_name);
	BuildPath(Path_SM, log_file_path, sizeof(log_file_path), LOG_FILE_PATH);
}
// 每次换关时，重新连接一次数据库
public void OnMapStart()
{
	if (db_TreeServer != null)
	{
		delete db_TreeServer;
		db_TreeServer = null;
	}
	ConnectDatabase();
}

// *********************
// 		 玩家相关
// *********************
// 重置玩家登录信息
void ResetAllLoginInfos()
{
	for (int client = 0; client < MAXPLAYERS + 1; client++)
	{
		player_infomation[client].Last_Login_Time = -1;
		strcopy(player_infomation[client].Player_SteamID, 32, NULL_STRING);
	}
}
// 根据玩家 STEAMID 获取在玩家信息数组中的玩家索引
int GetSteamIDIndex(const char[] steamID)
{
	for (int client = 0; client < MAXPLAYERS + 1; client++)
	{
		// 最后一次登录时间不等于无效时间
		if (player_infomation[client].Last_Login_Time != -1 && strcmp(player_infomation[client].Player_SteamID, steamID) == 0)
		{
			return client;
		}
	}
	return -1;
}
// 玩家完全进入服务器时，加入玩家信息条目
void InsertPlayerInfo(const char[] steamID)
{
	int client_index = GetSteamIDIndex(steamID);
	if (client_index != -1)
	{
		player_infomation[client_index].Last_Login_Time = GetTime();
		strcopy(player_infomation[client_index].Player_SteamID, 32, steamID);
		return;
	}
	for (int client = 0; client < MAXPLAYERS + 1; client++)
	{
		if (player_infomation[client].Last_Login_Time == -1)
		{
			player_infomation[client].Last_Login_Time = GetTime();
			strcopy(player_infomation[client].Player_SteamID, 32, steamID);
			return;
		}
	}
}
// 获取玩家此次游玩时间
int GetPlayTime(const char[] steamID)
{
	for (int client = 0; client < MAXPLAYERS + 1; client++)
	{
		if (player_infomation[client].Last_Login_Time != -1 && strcmp(player_infomation[client].Player_SteamID, steamID) == 0)
		{
			return player_infomation[client].Last_Login_Time;
		}
	}
	return -1;
}
// 玩家进入服务器
public void OnClientAuthorized(int client, const char[] auth)
{
	if (!IsFakeClient(client))
	{
		char steamID[32] = {'\0'}, player_ip[32] = {'\0'}, current_date[32] = {'\0'};
		FormatTime(current_date, sizeof(current_date), "%Y-%m-%d(%H:%M:%S%p)", -1);
		if (GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID)))
		{
			GetClientIP(client, player_ip, sizeof(player_ip));
			if (g_hRecordLog.BoolValue)
			{
				sql_statement = "";
				if (g_hRecordSteamID.BoolValue)
				{
					FormatEx(sql_statement, sizeof(sql_statement), "【TreeServer】：玩家：%N (STEAMID：%s，IP：%s) 加入服务器，时间：%s", client, steamID, player_ip, current_date);
					SaveDatabaseLogMessage(sql_statement);
				}
				else
				{
					FormatEx(sql_statement, sizeof(sql_statement), "【TreeServer】：玩家：%N 加入服务器，时间：%s", client, current_date);
					SaveDatabaseLogMessage(sql_statement);
				}
			}
			// 根据当前加入的玩家的 STEAMID 将当前玩家加入到顺序玩家数组中
			InsertPlayerInfo(steamID);
			sql_statement = "";
			FormatEx(sql_statement, sizeof(sql_statement), 
			"INSERT INTO %s (STEAM_ID, Player_Name) VALUES ('%s', '%N'), ON DUPLICATE KEY UPDATE Player_Name = VALUES(Player_Name)"
			, TABLENAME_PLAYER_INFOMATION, steamID, client);
			DML_ManageData(sql_statement);
		}
		else
		{
			KickClient(client, DB_STEAMID_ERROR_KICK);
		}
	}
}
// 玩家退出服务器
public void evt_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		char steamID[32] = {'\0'};
		if (GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID)))
		{
			int last_login_time = GetPlayTime(steamID);
			if (last_login_time != -1)
			{
				int login_duration = GetTime() - last_login_time;
				sql_statement = "";
				FormatEx(sql_statement, sizeof(sql_statement), 
				"INSERT INTO %s (STEAM_ID, Total_Play_Time) VALUES ('%s', '%d') ON DUPLICATE KEY UPDATE Total_Play_Time = Total_Play_Time + %d"
				, TABLENAME_PLAYER_INFOMATION, steamID, login_duration, login_duration);
				DML_ManageData(sql_statement);
				sql_statement = "";
				FormatEx(sql_statement, sizeof(sql_statement), 
				"UPDATE %s SET Max_Pre_Play_Time = %d WHERE STEAM_ID = '%s' AND Max_Pre_Play_Time < %d"
				, TABLENAME_PLAYER_INFOMATION, login_duration, steamID, login_duration);
				DML_ManageData(sql_statement);
			}
		}
		else
		{
			KickClient(client, DB_STEAMID_ERROR_KICK);
		}
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
void ConnectDatabase()
{
	if (SQL_CheckConfig(DBNAME))
	{
		char connect_error[128] = {'\0'};
		db_TreeServer = SQL_Connect(DBNAME, true, connect_error, sizeof(connect_error));
		if (db_TreeServer != null)
		{
			db_TreeServer.SetCharset(DBCHARSET);
			PrintToServer(DB_CONNECT_SUCCESS, DBNAME);
		}
		else
		{
			PrintToServer(DB_CONNECT_FAIL, DBNAME, connect_error);
		}
	}
}
// 使用 DML 语句向数据库进行操作，使用句柄返回操作的结果
void DML_ManageData(const char[] infomation)
{
	if (db_TreeServer != null)
	{
		db_TreeServer.Query(SQL_DML_QueryCallback, infomation);
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
void DQL_QueryData(int client = -1, DQL_DATATYPE DataType, const char[] infomation, any ...)
{
	if (db_TreeServer != null && IsValidClient(client))
	{
		DataPack dp_ClientPack = new DataPack();
		dp_ClientPack.WriteCell(client);
		dp_ClientPack.WriteCell(DataType);
		dp_ClientPack.WriteString(infomation);
		db_TreeServer.Query(SQL_DQL_QueryCallback, infomation, dp_ClientPack);
	}
	else if (db_TreeServer != null)
	{
		db_TreeServer.Query(SQL_DQL_QueryCallback, infomation);
	}
}
void SQL_DQL_QueryCallback(Database db, DBResultSet results, const char[] error, DataPack client_pack = null)
{
	if (client_pack != null)
	{
		client_pack.Reset();
		int client = client_pack.ReadCell();
		int data_type = client_pack.ReadCell();
		delete client_pack;
		if (db != null && results != null && strcmp(error, NULL_STRING) == 0)
		{
			switch (data_type)
			{
				
			}
			// 查询完毕，删除复制的数据库与结果句柄
			if (db != null || results != null)
			{
				delete db;
				delete results;
				db = null;
				results = null;
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
			DQL_QueryHasTables(results);
		}
		else
		{
			PrintToServer(DB_MANAGE_ERROR, error);
		}
	}
}
// 查询数据库中是否已经创建任何需要的数据表
void DQL_QueryHasTables(DBResultSet results)
{
	if (results.RowCount == 0)
	{
		DML_ManageData(CREATE_TABLE_PLAYER_BPOINTS_AND_SKILL);
		DML_ManageData(CREATE_TABLE_PLAYER_INFOMATION);
		PrintToServer(DB_CREATE_TABLE_SUCCESS);
	}
}