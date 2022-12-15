#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>

#define CVAR_FLAG FCVAR_NOTIFY

public Plugin myinfo = 
{
	name 			= "Error-File-Deleter",
	author 			= "夜羽真白",
	description 	= "自动删除 Logs 文件夹下的无用 Error Log",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

static char logPath[PLATFORM_MAX_PATH], pluginLogPath[PLATFORM_MAX_PATH], fileName[PLATFORM_MAX_PATH];
static DirectoryListing listing;
static FileType fileType;
static File pluginLogFile;
static int monthDay[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

ConVar
	g_hAllowFileDelete,
	g_hDeleteTimeDiff,
	g_hAllowLog,
	g_hDeleteLogPath;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	BuildPath(Path_SM, logPath, sizeof(logPath), "logs");
	if (!DirExists(logPath, false, NULL_STRING))
	{
		strcopy(error, err_max, "[错误文件删除]：无法打开 sourcemod/logs 文件夹，文件夹不存在");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hAllowFileDelete = CreateConVar("file_deleter_allow_delete", "1", "是否允许删除文件", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hDeleteTimeDiff = CreateConVar("file_deleter_time_different", "3", "距离当前日期超过多少天的 Error log 会被删除", CVAR_FLAG, true, 0.0);
	g_hAllowLog = CreateConVar("file_deleter_allow_log", "1", "是否允许记录日志", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hDeleteLogPath = CreateConVar("file_deleter_log_path", "logs\\file_deleter_log.txt", "日志文件目录，根文件夹为 sourcemod\\", CVAR_FLAG, true, 0.0);
	// AddChangeHook
	g_hAllowFileDelete.AddChangeHook(allowFileDeleteChanged);
	// AdminCommand
	RegAdminCmd("sm_filedelete", cmdDeleteFile, ADMFLAG_BAN);
}
public void OnPluginEnd()
{
	delete listing;
	delete pluginLogFile;
}

void allowFileDeleteChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_hAllowFileDelete.BoolValue) { prepareDeleteFile(); }
}

public Action cmdDeleteFile(int client, int args)
{
	ReplyToCommand(client, "[错误文件删除]：已删除：%d 个超过：%d 天的错误日志文件", prepareDeleteFile(), g_hDeleteTimeDiff.IntValue);
	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	prepareDeleteFile();
}

int prepareDeleteFile()
{
	// 建立日志文件
	char cvarStr[64] = {'\0'};
	g_hDeleteLogPath.GetString(cvarStr, sizeof(cvarStr));
	BuildPath(Path_SM, pluginLogPath, sizeof(pluginLogPath), cvarStr);
	if (!FileExists(pluginLogPath))
	{
		LogMessage("[错误文件删除]：%s 文件不存在，即将创建新日志文件", pluginLogPath);
		pluginLogFile = OpenFile(pluginLogPath, "wt");
	}
	else { pluginLogFile = OpenFile(pluginLogPath, "at"); }
	// 列出 logs 文件夹下所有文件
	int deleteCount = 0;
	listing = OpenDirectory(logPath, false, NULL_STRING);
	while (listing.GetNext(fileName, sizeof(fileName), fileType))
	{
		// 是文件，查询文件名
		if (!(fileType & FileType_File)) { continue; }
		TrimString(fileName);
		char timeStr[32] = {'\0'}, nowTimeStr[32] = {'\0'};
		FormatTime(nowTimeStr, sizeof(nowTimeStr), "%Y%m%d");
		if (fileName[0] == 'e' && strcmp(fileName[16], "log") == 0) { strcopy(timeStr, sizeof(timeStr), subString(fileName, 8, 8)); }
		else if (fileName[0] == 'L' && strcmp(fileName[10], "log") == 0) { strcopy(timeStr, sizeof(timeStr), subString(fileName, 2, 8)); }
		else { continue; }
		int year = getYear(timeStr), month = getMonth(timeStr), day = getDay(timeStr), sumYearDay = sumDay(month, day);
		int nowYear = getYear(nowTimeStr), nowMonth = getMonth(nowTimeStr), nowDay = getDay(nowTimeStr), sumNowYearDay = sumDay(nowMonth, nowDay), yearInterval = yearDayDiff(year, nowYear);
		if (isLeapYear(year) && month >= 3) { sumYearDay += 1; }
		if (isLeapYear(nowYear) && nowMonth >= 3) { sumNowYearDay += 1; }
		if (sumNowYearDay - sumYearDay + yearInterval > g_hDeleteTimeDiff.IntValue)
		{
			// 记录日志，删除文件
			char msg[PLATFORM_MAX_PATH] = {'\0'};
			if (g_hAllowLog.BoolValue && pluginLogFile != null)
			{
				FormatEx(msg, sizeof(msg), "[错误文件删除]：已删除文件：%s 【%s】", fileName, getCurrentDate(true));
				WriteFileLine(pluginLogFile, msg);
			}
			FormatEx(msg, sizeof(msg), "%s\\%s", logPath, fileName);
			DeleteFile(msg);
			deleteCount++;
		}
	}
	if (deleteCount > 0) { WriteFileLine(pluginLogFile, "[错误文件删除]：本次共删除：%d 个超过：%d 天的错误日志文件\n", deleteCount, g_hDeleteTimeDiff.IntValue); }
	delete listing;
	// 关闭日志文件句柄
	delete pluginLogFile;
	return deleteCount;
}

char[] subString(const char[] str, int start, int end)
{
	int index = 0;
	char resultStr[32] = {'\0'};
	for (int i = 0; i < end; i++) { resultStr[index++] = str[start - 1 + i]; }
	return resultStr;
}

int getYear(const char[] str)
{
	return StringToInt(subString(str, 1, 4));
}

int getMonth(const char[] str)
{
	return StringToInt(subString(str, 5, 2));
}

int getDay(const char[] str)
{
	return StringToInt(subString(str, 7, 2));
}

int yearDayDiff(int year1, int year2)
{
	int day = (year2 - year1) * 365;
	for (int i = year1; i < year2; i++) { if (isLeapYear(i)) { day += 1; } }
	return day;
}

int sumDay(int month, int day)
{
	for (int i = 0; i < month - 1; i++) { day += monthDay[i]; }
	return day;
}

bool isLeapYear(int year)
{
	return ((year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0));
}

char[] getCurrentDate(bool time = false)
{
	char current_date[32] = {'\0'};
	if (time) { FormatTime(current_date, sizeof(current_date), "%Y-%m-%d(%Hh%Mmin%Ss%p)", -1); }
	else { FormatTime(current_date, sizeof(current_date), "%Y-%m-%d", -1); }
	return current_date;
}