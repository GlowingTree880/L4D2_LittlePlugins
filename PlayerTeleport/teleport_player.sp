/*
 * @Author: 夜羽真白
 * @Date: 2023-04-25 12:27 周二
 * @Type: Left 4 Dead 2 Plugin
 * @Description: Player Teleport 玩家传送
 * @URL: https://github.com/GlowingTree880/L4D2_LittlePlugins
 */

#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include "treeutil/treeutil.sp"

#define MENU_DISPLAY_TIME 20
#define CVAR_FLAG FCVAR_NOTIFY
#define TELEPORT_ME_FLAG "@s"
#define TELEPORT_ALL_CLIENT_FLAG "@a"

#define TELEPORT_TYPE 0
#define TELEPORT_TARGET 1
// 提示信息
#define MSG_NO_ACCESS "{O}[提示]：{G}您没有权限使用传送玩家指令"
#define MSG_INVALID_SURVIVOR_TARGET "{O}[提示]：{G}需要传送到的目标生还者：{O}%N {G}无效，无法传送"
#define MSG_DEAD_SURVIVOR_TARGET "{O}[提示]：{G}需要传送到的目标生还者：{O}%N {G}已死亡，无法传送"
#define MSG_INVALID_INFECTED_TARGET "{O}[提示]：{G}需要传送到的目标特感：{O}%N {G}无效，无法传送"
#define MSG_DEAD_INFECTED_TARGET "{O}[提示]：{G}需要传送到的目标特感：{O}%N {G}已死亡，无法传送"
#define MSG_GHOST_INFECTED_TARGET "{O}[提示]：{G}需要传送到的目标特感：{O}%N {G}处于灵魂状态，无法传送"
#define MSG_CMD_USAGE "{O}[提示]：{G}请使用 {O}!tp A B {G}传送玩家 A 到玩家 B\n{G}或使用 {O}!tp %s %s {G}传送所有玩家"
#define MSG_CMD_FAILED "{O}[提示]：{G}源目标或目标无效，无法传送"
#define MSG_REACH_COUNT "{O}[提示]：{G}本局你已使用 {O}%d {G}次传送，已达到上限，无法使用"
// 传送完成
#define MSG_CMD_TELEPORT_DONE "{O}[提示]:{G}已将：{O}%N {G}传送到目标：{O}%N {G}处"
#define MSG_TELEPORT_DONE "{O}[提示]：{G}已将您传送到目标：{O}%N {G}处"
#define MSG_TELEPORT_SURVIVOR_ME_DONE "{O}[提示]：{G}已将目标生还者：{O}%N {G}传送到您的位置"
#define MSG_TELEPORT_INFECTED_ME_DONE "{O}[提示]：{G}已将目标特感：{O}%N {G}传送到您的位置"
#define MSG_TELEPORT_ALL_SURVIVOR_DONE "{O}[提示]：{G}已将所有生还者传送到您的位置"
#define MSG_TELEPORT_ALL_INFECTED_DONE "{O}[提示]：{G}已将所有特感传送到您的位置"

public Plugin myinfo = 
{
	name 			= "Player Teleport - 玩家传送",
	author 			= "夜羽真白",
	description 	= "玩家传送",
	version 		= "2023/4/15",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar
	g_hEnable,
	g_hAccessLevel,
	g_hRoundUseCount;

bool
	teleportOption[MAXPLAYERS + 1][2];

int
	teleportUseCount[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_hEnable = CreateConVar("teleport_player_enable", "1", "是否开启插件", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAccessLevel = CreateConVar("teleport_player_access_level", "1", "指令可以被哪些人使用：1=管理员，2=所有玩家", CVAR_FLAG, true, 1.0, true, 2.0);
	g_hRoundUseCount = CreateConVar("teleport_round_count", "5", "每局可以使用多少次传送次数：0=无限制", CVAR_FLAG, true, 0.0);
	// 注册传送指令
	RegConsoleCmd("sm_tp", teleportPlayerHandler);
	HookEvent("round_start", roundEventHandler);
	HookEvent("round_end", roundEventHandler);
}

public void OnMapStart()
{
	clearTeleportCount();
}

public void roundEventHandler(Event event, const char[] name, bool dontBroadcast)
{
	clearTeleportCount();
}

void clearTeleportCount()
{
	static int i;
	for (i = 1; i <= MaxClients; i++) { teleportUseCount[i] = 0; }
}

public Action teleportPlayerHandler(int client, int args)
{
	if (!g_hEnable.BoolValue && !IsValidClient(client) || IsFakeClient(client)) { return Plugin_Handled; }
	// 玩家无权限使用指令
	if (!checkPlayerAccessLevel(client))
	{
		CPrintToChat(client, MSG_NO_ACCESS);
		return Plugin_Handled;
	}
	// 玩家传送次数到达上限
	if (g_hRoundUseCount.BoolValue && teleportUseCount[client] >= g_hRoundUseCount.IntValue)
	{
		CPrintToChat(client, MSG_REACH_COUNT, teleportUseCount[client]);
		return Plugin_Handled;
	}
	// 没有参数，给玩家显示传送菜单
	if (args == 0)
	{
		drawMainTeleportMenu(client);
		return Plugin_Handled;
	}
	// 获取指令参数
	if (args < 2)
	{
		CPrintToChat(client, MSG_CMD_USAGE, TELEPORT_ALL_CLIENT_FLAG, TELEPORT_ME_FLAG);
		return Plugin_Handled;
	}
	char source[MAX_NAME_LENGTH], dest[MAX_NAME_LENGTH];
	GetCmdArg(1, source, sizeof(source));
	GetCmdArg(2, dest, sizeof(dest));
	if (strcmp(source, TELEPORT_ALL_CLIENT_FLAG, false) == 0 && strcmp(dest, TELEPORT_ME_FLAG, false) == 0)
	{
		teleportAllToMe(client, TEAM_SURVIVOR);
		return Plugin_Continue;
	}
	// 如果是数字，则判断是否是玩家 userId，不是玩家 userId 则为姓名
	if (isStringInteger(source, sizeof(source)) && isStringInteger(dest, sizeof(dest)))
	{
		teleportTargetByUserId(client, StringToInt(source), StringToInt(dest));
		return Plugin_Continue;
	}
	teleportTargetByName(client, source, dest);
	return Plugin_Continue;
}

bool checkPlayerAccessLevel(int client)
{
	if (!IsValidClient(client)) { return false; }
	AdminId admin = GetUserAdmin(client);
	if (g_hAccessLevel.IntValue == 1 && !admin.HasFlag(Admin_Ban, Access_Effective)) { return false; }
	return true;
}

void drawMainTeleportMenu(int client)
{
	if (!IsValidClient(client) || IsFakeClient(client)) { return; }
	Menu mainMenu = new Menu(mainMenuHandler);
	mainMenu.SetTitle("传送菜单");
	mainMenu.AddItem("0", "传送生还者", ITEMDRAW_DEFAULT);
	mainMenu.AddItem("1", "传送特感", ITEMDRAW_DEFAULT);
	mainMenu.ExitButton = true;
	mainMenu.Display(client, MENU_DISPLAY_TIME);
}

/*
 * @Description: 传送主菜单回调函数
 * @param: {menu} 菜单句柄
 * @param: {action} 按键事件
 * @param: {client} 操作此菜单的玩家
 * @param: {item} 选中的选项
 * @return: {int} 
 */
public int mainMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		static char
					itemInfo[32],
					itemName[32];
		menu.GetItem(item, itemInfo, sizeof(itemInfo), _, itemName, sizeof(itemName));
		if (StringToInt(itemInfo) == 0)
		{
			// teleportType 为 true 表示传送生还者
			teleportOption[client][TELEPORT_TYPE] = true;
			drawOptionalTeleportMenu(client);
		}
		else
		{
			teleportOption[client][TELEPORT_TYPE] = false;
			drawOptionalTeleportMenu(client);
		}
	}
	return 0;
}

void drawOptionalTeleportMenu(int client)
{
	if (!IsValidClient(client) || IsFakeClient(client)) { return; }
	Menu optionMenu = new Menu(optionMenuHandler);
	optionMenu.SetTitle("传送选项菜单");
	optionMenu.AddItem("0", "传送我到目标", ITEMDRAW_DEFAULT);
	optionMenu.AddItem("1", "传送目标到我", ITEMDRAW_DEFAULT);
	optionMenu.ExitBackButton = true;
	optionMenu.ExitButton = true;
	optionMenu.Display(client, MENU_DISPLAY_TIME);
}

public int optionMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		static char
					itemInfo[32],
					itemName[32];
		menu.GetItem(item, itemInfo, sizeof(itemInfo), _, itemName, sizeof(itemName));
		if (StringToInt(itemInfo) == 0)
		{
			// teleportTarget 为 true 表示传送我到目标
			teleportOption[client][TELEPORT_TARGET] = true;
			drawTeleportDetailMenu(client);
		}
		else
		{
			teleportOption[client][TELEPORT_TARGET] = false;
			drawTeleportDetailMenu(client);
		}
	}
	else if (action == MenuAction_Cancel) { drawMainTeleportMenu(client); }
	return 0;
}

void drawTeleportDetailMenu(int client)
{
	if (!IsValidClient(client) || IsFakeClient(client))
	{
		teleportOption[client][TELEPORT_TYPE] = teleportOption[client][TELEPORT_TARGET] = false;
		return;
	}
	Menu teleportMenu = new Menu(teleportDetailHandler);
	// 判断传送方式
	if (teleportOption[client][TELEPORT_TARGET]) { teleportMenu.SetTitle("传送我到目标"); }
	else { teleportMenu.SetTitle("传送目标到我"); }
	// 判断传送类型
	static int i;
	static char
				itemIndex[16],
				targetName[MAX_NAME_LENGTH];
	
	if (!teleportOption[client][TELEPORT_TARGET])
	{
		if (teleportOption[client][TELEPORT_TYPE]) { teleportMenu.AddItem("0", "所有生还者", ITEMDRAW_DEFAULT); }
		else { teleportMenu.AddItem("0", "所有特感", ITEMDRAW_DEFAULT); }
	}
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || i == client) { continue; }
		if (teleportOption[client][TELEPORT_TYPE] && GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
		else if (!teleportOption[client][TELEPORT_TYPE] && GetClientTeam(i) != TEAM_INFECTED) { continue; }
		IntToString(GetClientUserId(i), itemIndex, sizeof(itemIndex));
		FormatEx(targetName, sizeof(targetName), "%N", i);
		teleportMenu.AddItem(itemIndex, targetName, ITEMDRAW_DEFAULT);
	}
	teleportMenu.ExitBackButton = true;
	teleportMenu.ExitButton = true;
	teleportMenu.Display(client, MENU_DISPLAY_TIME);
}

public int teleportDetailHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		static char
					itemInfo[32],
					itemName[32];
		menu.GetItem(item, itemInfo, sizeof(itemInfo), _, itemName, sizeof(itemName));
		static int
					userId;
		userId = StringToInt(itemInfo);
		doTeleportTarget(client, userId);
	}
	else if (action == MenuAction_Cancel)
	{
		delete menu;
		drawOptionalTeleportMenu(client);
	}
	return 0;
}

/*
 * @Description: 判断需要传送的目标是否有效，有效则传送，无效则提示
 * @param: {initiator} 传送发起者
 * @return: {userId} 需要传送的目标，所有人为 0
 */
void doTeleportTarget(int initiator, int userId)
{
	if (!IsValidClient(initiator)) { return; }
	static int
				target;
	// 传送生还者
	if (teleportOption[initiator][TELEPORT_TYPE])
	{
		// 传送所有玩家
		if (userId == 0) { determineTeleportTarget(initiator, userId); }
		else
		{
			target = GetClientOfUserId(userId);
			// 传送到生还者，目标无效或死亡，无法传送
			if (!IsValidClient(target))
			{
				CPrintToChat(initiator, MSG_INVALID_SURVIVOR_TARGET, target);
				return;
			}
			if (!IsPlayerAlive(target))
			{
				CPrintToChat(initiator, MSG_DEAD_SURVIVOR_TARGET, target);
				return;
			}
			// 判断传送方式
			determineTeleportTarget(initiator, target);
		}
		return;
	}
	// 传送特感
	if (userId == 0) { determineTeleportTarget(initiator, userId); }
	else
	{
		target = GetClientOfUserId(userId);
		if (!IsValidInfected(target))
		{
			CPrintToChat(initiator, MSG_INVALID_INFECTED_TARGET, target);
			return;
		}
		if (!IsPlayerAlive(target))
		{
			CPrintToChat(initiator,MSG_DEAD_INFECTED_TARGET, target);
			return;
		}
		if (IsInGhostState(target))
		{
			CPrintToChat(initiator, MSG_GHOST_INFECTED_TARGET, target);
			return;
		}
		determineTeleportTarget(initiator, target);
	}
}

/*
 * @Description: 根据传送类型和传送方式传送生还者或特感
 * @param: {initiator} 传送发起者
 * @return: {target} 需要传送的目标，所有人为 0
 */
void determineTeleportTarget(int initiator, int target)
{
	if (!IsValidClient(initiator)) { return; }
	static float
				selfPos[3];
	// 传送生还者
	if (teleportOption[initiator][TELEPORT_TYPE])
	{
		// 传送目标生还者到我
		if (!teleportOption[initiator][TELEPORT_TARGET])
		{
			// 传送所有目标生还者到我
			if (!IsValidSurvivor(target))
			{
				teleportAllToMe(initiator, TEAM_SURVIVOR);
				return;
			}
			// 传送指定目标生还者到我
			if (IsClientHanging(target)) { L4D_ReviveSurvivor(target); }
			GetClientAbsOrigin(initiator, selfPos);
			TeleportEntity(target, selfPos);
			if (g_hRoundUseCount.BoolValue) { teleportUseCount[initiator]++; }
			CPrintToChat(target, MSG_TELEPORT_DONE, initiator);
			CPrintToChat(initiator, MSG_TELEPORT_SURVIVOR_ME_DONE, target);
			return;
		}
		// 传送我到目标生还者
		GetClientAbsOrigin(target, selfPos);
		TeleportEntity(initiator, selfPos);
		if (g_hRoundUseCount.BoolValue) { teleportUseCount[initiator]++; }
		CPrintToChat(initiator, MSG_TELEPORT_DONE, target);
		return;
	}
	// 传送特感
	if (!teleportOption[initiator][TELEPORT_TYPE])
	{
		// 传送目标特感到我
		if (!teleportOption[initiator][TELEPORT_TARGET])
		{
			GetClientAbsOrigin(initiator, selfPos);
			// 传送所有特感到我
			if (!IsValidInfected(target))
			{
				teleportAllToMe(initiator, TEAM_INFECTED);
				return;
			}
			// 传送指定特感到我
			TeleportEntity(target, selfPos);
			if (g_hRoundUseCount.BoolValue) { teleportUseCount[initiator]++; }
			CPrintToChat(target, MSG_TELEPORT_DONE, initiator);
			CPrintToChat(initiator, MSG_TELEPORT_INFECTED_ME_DONE, target);
			return;
		}
		// 传送我到指定特感
		GetClientAbsOrigin(target, selfPos);
		TeleportEntity(initiator, selfPos, NULL_VECTOR, NULL_VECTOR);
		if (g_hRoundUseCount.BoolValue) { teleportUseCount[initiator]++; }
		CPrintToChat(initiator, MSG_TELEPORT_DONE, target);
		return;
	}
}

void teleportAllToMe(int client, int team)
{
	if (!IsValidClient(client)) { return; }
	static int i;
	static float selfPos[3];
	GetClientAbsOrigin(client, selfPos);
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != team || !IsPlayerAlive(i) || i == client) { continue; }
		// 如果生还者挂边，则将其救起
		if (team == TEAM_SURVIVOR && IsClientHanging(i)) { L4D_ReviveSurvivor(i); }
		// 如果感染者处于灵魂状态，无法传送
		if (team == TEAM_INFECTED && IsInGhostState(i)) { continue; }
		TeleportEntity(i, selfPos, NULL_VECTOR, NULL_VECTOR);
		CPrintToChat(i, MSG_TELEPORT_DONE, client);
	}
	CPrintToChat(client, MSG_TELEPORT_ALL_SURVIVOR_DONE);
	if (g_hRoundUseCount.BoolValue) { teleportUseCount[client]++; }
}

/*
 * @Description: 判断字符串是否为纯数字
 * @param: {str} 需要判断的字符串
 * @param: {len} 字符串长度
 * @return: {bool} 
 */
static bool isStringInteger(char[] str, int len)
{
	TrimString(str);
	static int i;
	if (IsNullString(str) || len < 0) { return false; }
	if (str[0] == '-')
	{
		for (i = 1; i < len; i++) { if (str[i] != 0 && !IsCharNumeric(str[i])) { return false; } }
		return true;
	}
	for (i = 0; i < len; i++) { if (str[i] != 0 && !IsCharNumeric(str[i])) { return false; } }
	return true;
}

/*
 * @Description: 按照 userId 匹配并传送指定玩家
 * @param: {initiator} 发起人
 * @param: {source} 源目标
 * @param: {dest} 目标
 * @return: {void} 
 */
void teleportTargetByUserId(int initiator, int source, int dest)
{
	source = GetClientOfUserId(source);
	dest = GetClientOfUserId(dest);
	if (!IsValidClient(source) || !IsValidClient(dest) || !IsPlayerAlive(source) || !IsPlayerAlive(dest) || 
	((IsValidInfected(source) && IsInGhostState(source)) || (IsValidInfected(dest) && IsInGhostState(dest))))
	{
		CPrintToChat(initiator, MSG_CMD_FAILED);
		return;
	}
	float selfPos[3];
	GetClientAbsOrigin(dest, selfPos);
	TeleportEntity(source, selfPos, NULL_VECTOR, NULL_VECTOR);
	if (g_hRoundUseCount.BoolValue) { teleportUseCount[initiator]++; }
	CPrintToChat(source, MSG_TELEPORT_DONE, dest);
	CPrintToChat(initiator, MSG_CMD_TELEPORT_DONE, source, dest);
}

/*
 * @Description: 按照名字匹配并传送指定玩家
 * @param: {initiator} 发起人
 * @param: {source} 源目标
 * @param: {dest} 目标
 * @return: {void} 
 */
void teleportTargetByName(int initiator, char[] source, char[] dest)
{
	TrimString(source);
	TrimString(dest);
	// 是否是传送所有玩家
	if ((strcmp(source, TELEPORT_ALL_CLIENT_FLAG, false) == 0) && (strcmp(dest, TELEPORT_ME_FLAG, false) == 0))
	{
		// 传送所有玩家到我：!tp @a @s
		teleportOption[initiator][TELEPORT_TYPE] = true;
		teleportOption[initiator][TELEPORT_TARGET] = false;
		determineTeleportTarget(initiator, 0);
		return;
	}
	// 否则传送特定生还者
	int self, target;
	static int i;
	static char name[MAX_NAME_LENGTH];
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i)) { continue; }
		if (IsInGhostState(i)) { continue; }
		// 匹配玩家名字
		GetClientName(i, name, sizeof(name));
		TrimString(name);
		if (strcmp(name, source, false) == 0) { self = i; }
		if (strcmp(name, dest, false) == 0) { target = i; }
	}
	if (!IsValidClient(self) || !IsValidClient(target) || !IsPlayerAlive(self) || !IsPlayerAlive(target) || 
	((IsValidInfected(self) && IsInGhostState(self)) || (IsValidInfected(target) && IsInGhostState(target))))
	{
		CPrintToChat(initiator, MSG_CMD_FAILED);
		return;
	}
	float selfPos[3];
	GetClientAbsOrigin(target, selfPos);
	TeleportEntity(self, selfPos, NULL_VECTOR, NULL_VECTOR);
	if (g_hRoundUseCount.BoolValue) { teleportUseCount[initiator]++; }
	CPrintToChat(self, MSG_TELEPORT_DONE, target);
	CPrintToChat(initiator, MSG_CMD_TELEPORT_DONE, self, target);
}