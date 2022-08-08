#pragma semicolon 1
#pragma newdecls required

#define MENU_SHOW_TIME 30
#define MENU_PAGE_ITEM 7
#define MAX_HEALTH 100

#define GAMEDATA "l4d2_gift_rewards"

#define INFO_SURVIVOR_BUY_ONLY "{O}[B数商店]：{LG}本指令仅限生还者购买物品"
#define INFO_DB_NULL "{O}[B数商店]：{LG}未连接到数据库，无法读取商店所需信息"
#define INFO_BUY_AMMO "{O}%N{LG}免费补充了子弹"
#define INFO_FIRST_BUY "{O}%N{LG}第一次白嫖了一把%s，还剩%dB数"
#define INFO_NOT_ENOUGH_BPOINTS "{LG}当前B数%d点，无法购买{O}%s"
#define INFO_BUY_GUN "{O}%N{LG}花%dB数购买了一把%s，还剩%dB数"
#define INFO_BUY_MEDICAL "{O}%N{LG}花%dB数购买了%s，还剩%dB数"
#define INFO_CANT_LEARN_SKILL "{LG}当前B数%d点，无法升级{O}%s"
#define INFO_CHANGE_MELEE "{LG}成功将出门近战类型更改为{O}%s"
#define INFO_MAX_SKILL "{LG}当前{O}%s{LG}已是最高等级"
#define INFO_RESET_SKILL "{LG}重置所有技能完成"
#define INFO_LEVEL2BPONT_ERROR "{LG}当前等级{O}%d级，{LG}未达到限制等级{O}20级，{LG}无法进行B数转换"
#define INFO_BPOINT2LEVEL_ERROR "{LG}当前B数{O}%d点，{LG}无法进行等级转换"
#define INFO_GIVE_BPOINST "{O}%N{LG}打开了礼包获得了%d点B数"
#define INFO_GIVE_EXP "{O}%N{LG}打开了礼包获得了%d点经验"
#define INFO_CANT_UST_CUSTOM_TAGS "{O}[提示]：{LG}当前服务器未开启允许自定义称号功能"
#define INFO_CUSTOM_TASG_NOLEVEL "{O}[提示]：{LG}当前等级{O}%d，{LG}未达到允许自定义称号最低等级{O}%d"
#define INFO_CUSTOM_TAGS_USAGE "{O}[提示]：{LG}自定义称号方法：{O}!tags + `称号`"
#define INFO_ILLEGAL_CHAR "{O}[提示]：{LG}称号中只允许使用中英文字符"
#define INFO_CHAR_OUTLENGHT "{O}[提示]：{LG}当前称号长度{O}%d，{LG}超过限制{O}%d"
#define INFO_CUSTOM_TAGS_SET_SUCCESS "{LG}成功将自定义称号设置为：{O}%s"

#define BUTTON_SOUND "buttons/button14.wav"
#define ERROR_SOUND "ui/beep_error01.wav"
#define INFO_SOUND "ui/beepclear.wav"

#define DML_UPDATE_EFFICIENCY "UPDATE %s AS INFO, %s AS POINTS SET INFO.`HeadShot_Count` = %d, INFO.`HeadShot_Rate` = %f, POINTS.`Minutes_BPoints` = %.f, \
POINTS.`Minutes_Exps` = %f WHERE INFO.`STEAM_ID` = '%s' AND POINTS.`STEAM_ID` = '%s';"
#define DML_UPDATE_CUSTOM_TAGS "UPDATE %s AS POINTS SET points.`Custom_Designation` = '%s' WHERE points.`STEAM_ID` = '%s';"
#define DQL_DEFAULT_TAGS "SELECT TAGS.`Player_Designation` FROM %s AS POINTS, %s AS TAGS WHERE POINTS.`Level` BETWEEN TAGS.`Min_Level` AND TAGS.`Max_Level` AND POINTS.`STEAM_ID` = '%s';"

static const char PLAYER_TEAM[4][] =
{
	"NoTeam",
	"旁观者",
	"生还者",
	"感染者"
};
enum EFFICIENCY_TYPE
{
	HeadShot_Rate,
	Minutes_BPoints,
	Minutes_Exps
}

static char WeaponMenu[][][] = 
{
	{"none",			"None",				"0"},
	{"ammo",			"子弹堆",			"0"},
	{"pistol_magnum",	"马格南手枪", 		"50"},
	{"smg",				"UZI冲锋枪", 		"20"},
	{"smg_silenced", 	"SMG冲锋枪", 		"20"},
	{"pumpshotgun",		"一代单发霰弹枪", 	"20"},
	{"shotgun_chrome",	"二代单发霰弹枪", 	"20"},
	{"autoshotgun", 	"一代连发霰弹枪", 	"100"},
	{"shotgun_spas",	"二代连发霰弹枪", 	"100"},
	{"hunting_rifle", 	"一代狙击枪", 		"150"},
	{"sniper_military", "二代狙击枪", 		"150"},
	{"smg_mp5",			"MP5冲锋枪", 		"100"},
	{"rifle", 			"M16步枪", 			"100"},
	{"rifle_ak47", 		"AK47步枪", 		"100"},
	{"rifle_desert",	"SCAR步枪", 		"100"},
	{"rifle_sg552", 	"SG552步枪", 		"100"},
	{"sniper_awp", 		"AWP狙击枪",		"500"},
	{"grenade_launcher","榴弹发射器",		"500"},
	{"sniper_scout", 	"鸟狙", 			"300"},
	{"rifle_m60", 		"M60重机枪", 		"500"}
};
static char MedicalsMenu[][][] =
{
	{"none",			"None",				"0"},
	{"pain_pills", 		"止痛药", 			"50"},
	{"first_aid_kit",	"急救包", 			"100"},
	{"adrenaline",	 	"肾上腺素", 		"25"}
};
static char MeleesMenu[][][] = 
{
	{"none",			"未选择",			"0"},
	{"knife", 			"小刀", 			"50"},
	{"baseball_bat",	"棒球棒", 			"50"},
	{"cricket_bat", 	"板球拍", 			"50"},
	{"crowbar", 		"撬棍", 			"50"},
	{"electric_guitar", "电吉他", 			"50"},
	{"fireaxe", 		"消防斧", 			"50"},
	{"frying_pan", 		"平底锅", 			"50"},
	{"katana", 			"武士刀", 			"50"},
	{"machete", 		"砍刀", 			"50"},
	{"tonfa", 			"警棍", 			"50"},
	{"golfclub", 		"高尔夫球杆", 		"50"},
	{"pitchfork", 		"草叉", 			"50"},
	{"shovel", 			"铁铲", 			"50"}
};
static char OthersMenu[][][] =
{
	{"none",			"None",				"0"},
	{"propanetank", 	"煤气罐", 			"50"},
	{"oxygentank",	 	"氧气瓶", 			"50"},
	{"fireworkcrate",	"烟花盒", 			"50"},
	{"gascan",  		"汽油桶",			"100"},
	{"gnome",			"侏儒", 			"200"}
};

// ConVars
ConVar g_hAllowDropGift, g_hAllowRestoreHealth, g_hAllowCustomTags, g_hCustomTagsMinLevel, g_hAllowIgnoreLevel, g_hCustomTagsLength, g_hDropChance, g_hBPointsChance, g_hExpChance, 
g_hMinBPoints, g_hMaxBPoints, g_hMinExp, g_hMaxExp, g_hDefaultChance;
// Handles
Handle hCreateGift = INVALID_HANDLE;
// Bools
bool g_bBuckShot[MAXPLAYERS + 1] = {false};

public void Menus_OnModuleStart()
{
	char file_path[PLATFORM_MAX_PATH] = {'\0'};
	BuildPath(Path_SM, file_path, sizeof(file_path), "gamedata/%s.txt", GAMEDATA);
	if (FileExists(file_path))
	{
		Handle hGameData = LoadGameConfigFile(GAMEDATA);
		if (hGameData != INVALID_HANDLE)
		{
			StartPrepSDKCall(SDKCall_Static);
			if (PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CHolidayGift::Create"))
			{
				PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
				PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
				PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
				PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
				PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
				hCreateGift = EndPrepSDKCall();
				if (hCreateGift == INVALID_HANDLE)
				{
					SetFailState("请检查 CHolidayGift::Create 签名是否损坏或已更新");
				}
			}
			else
			{
				SetFailState("无法加载 CHolidayGift::Create 签名");
			}
		}
		else
		{
			SetFailState("无法加载 GameData 文件：%s", GAMEDATA);
		}
		delete hGameData;
	}
	else
	{
		SetFailState("无法找到 GameData 文件：%s 于 gamedata 文件夹中", GAMEDATA);
	}
	g_hAllowDropGift = CreateConVar("rpg_allow_drop_gift", "1", "杀死特感是否允许掉落礼物盒", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hDropChance = CreateConVar("rpg_gift_drop_chance", "50", "杀死特感掉落礼物盒的概率：0% ~ 100%（0 则使用 'z_holiday_gift_drop_chance' 默认值）", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hBPointsChance = CreateConVar("rpg_gift_bpoints_chance", "50", "礼物盒打开获得 B 数的概率：0% ~ 100%", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hExpChance = CreateConVar("rpg_gift_exps_chance", "50", "礼物盒打开获得经验的概率：0% ~ 100%", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hMaxBPoints = CreateConVar("rpg_gift_max_bpoints", "20", "礼物盒打开获得的最大 B 数值", CVAR_FLAGS, true, 0.0);
	g_hMinBPoints = CreateConVar("rpg_gift_min_bpoints", "1", "礼物盒打开获得的最小 B 数值", CVAR_FLAGS, true, 0.0);
	g_hMaxExp = CreateConVar("rpg_gift_max_exp", "100", "礼物盒打开获得的最大经验值", CVAR_FLAGS, true, 0.0);
	g_hMinExp = CreateConVar("rpg_gift_min_exp", "10", "礼物盒打开获得的最小经验值", CVAR_FLAGS, true, 0.0);
	g_hAllowRestoreHealth = CreateConVar("rpg_allow_kill_restore_health", "0", "是否开启杀特回血", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hAllowCustomTags = CreateConVar("rpg_allow_custom_tags", "1", "是否允许使用自定义称号", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCustomTagsMinLevel = CreateConVar("rpg_custom_tags_min_level", "50", "多少等级以上允许自定义称号", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hAllowIgnoreLevel = CreateConVar("rpg_custags_ignore_minlevel", "1", "玩家自定义称号后是否允许无视最低等级使用", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hCustomTagsLength = CreateConVar("rpg_custom_tags_length", "10", "自定义称号最多不能超过多少个字符", CVAR_FLAGS, true, 1.0, true, 10.0);
	g_hDefaultChance = FindConVar("z_holiday_gift_drop_chance");
	HookEvent("round_start", evt_RoundStart, EventHookMode_Post);
	HookEvent("player_hurt", evt_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", evt_PlayerDeath, EventHookMode_Pre);
	HookEvent("infected_death", evt_InfectedDeath, EventHookMode_Pre);
	HookEvent("christmas_gift_grab", evt_GiftGrab, EventHookMode_Post);
	HookEvent("witch_killed", evt_WitchKilled, EventHookMode_Post);
	AddCommandListener(Say_CallBack, "say");
	AddCommandListener(Say_CallBack, "say_team");
	RegConsoleCmd("sm_buy", Cmd_Buy, "显示商店菜单");
	RegConsoleCmd("sm_rpg", Cmd_Buy, "显示商店菜单");
	RegConsoleCmd("sm_lv", Cmd_ShowLevel, "显示当前玩家等级B数信息");
	RegConsoleCmd("sm_tags", Cmd_PlayerCustomTags, "玩家自定义称号");
}
public void Menus_OnMapStart()
{
	PrecacheSound(BUTTON_SOUND, true);
	PrecacheSound(ERROR_SOUND, true);
	PrecacheSound(INFO_SOUND, true);
}
public Action Cmd_Buy(int client, int args)
{
	if (IsValidSurvivor(client) && IsPlayerAlive(client))
	{
		if (db_TreeServer != null)
		{
			Draw_MainMenu(client);
		}
		else
		{
			CPrintToChat(client, INFO_DB_NULL);
		}
	}
	else if (client == 0)
	{
		PrintToServer("【TreeServer】：商店指令：!buy 无法于服务端控制台使用");
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(client, INFO_SURVIVOR_BUY_ONLY);
	}
	return Plugin_Continue;
}
public Action Cmd_ShowLevel(int client, int args)
{
	if (IsValidClient(client))
	{
		CPrintToChat(client, "{B}等级:{O}%d  {B}B数:{O}%d  {B}经验:{O}%d", player_data[client].Player_Level, player_data[client].Player_BPoints, player_data[client].Player_Exp);
	}
	else if (client == 0)
	{
		PrintToServer("【TreeServer】：等级指令：!lv 无法于服务端控制台使用");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public Action Cmd_PlayerCustomTags(int client, int args)
{
	if (IsValidClient(client) && g_hAllowCustomTags.BoolValue)
	{
		if (player_data[client].Player_Level >= g_hCustomTagsMinLevel.IntValue)
		{
			if (args < 1)
			{
				CPrintToChat(client, INFO_CUSTOM_TAGS_USAGE);
			}
			char cmd_text[64] = {'\0'};
			GetCmdArgString(cmd_text, sizeof(cmd_text));
			if (IsLegalTag(client, cmd_text))
			{
				strcopy(player_data[client].Player_Custom_Designation, 64, cmd_text);
				CPrintToChat(client, INFO_CUSTOM_TAGS_SET_SUCCESS, cmd_text);
				// 上传称号
				char steamID[32] = {'\0'}, sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
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
					return Plugin_Handled;
				}
				FormatEx(sql_statement, sizeof(sql_statement), DML_UPDATE_CUSTOM_TAGS, TABLENAME_BPOINTS_AND_SKILL, cmd_text, steamID);
				DML_ManageData(sql_statement);
			}
		}
		else
		{
			CPrintToChat(client, INFO_CUSTOM_TASG_NOLEVEL, player_data[client].Player_Level, g_hCustomTagsMinLevel.IntValue);
		}
	}
	else if (IsValidClient(client))
	{
		CPrintToChat(client, INFO_CANT_UST_CUSTOM_TAGS);
	}
	else if (client == 0)
	{
		PrintToServer("【TreeServer】：自定义称号指令：!tags 无法于服务端控制台使用");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
public Action Say_CallBack(int client, char[] command, int args)
{
    if (IsValidClient(client))
    {
		char chat_text[256] = {'\0'}, new_text[256] = {'\0'}, steamID[32] = {'\0'}, player_ip[32] = {'\0'};
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
			return Plugin_Handled;
		}
		GetCmdArgString(chat_text, sizeof(chat_text));
		// 先记录玩家说的话
		if (g_hRecordMessage.BoolValue)
		{
			if (g_hRecordSteamID.BoolValue)
			{
				GetClientIP(client, player_ip, sizeof(player_ip));
				FormatEx(new_text, sizeof(new_text), "[%s]%N (STEAMID：%s，IP：%s)：%s [%s]", PLAYER_TEAM[GetClientTeam(client)], client, steamID, player_ip, chat_text, GetCurrentDate(true));
			}
			else
			{
				FormatEx(new_text, sizeof(new_text), "[%s]%N：%s [%s]", PLAYER_TEAM[GetClientTeam(client)], client, chat_text, GetCurrentDate(true));
			}
			SavePlayerMessage(new_text);
		}
		// 玩家是否在投票
		if (strncmp(chat_text[1], "vote", 4) == 0)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				UpdatePlayerData(client, steamID);
			}
			return Plugin_Handled;
		}
		else
		{
			char real_text[64] = {'\0'};
			BreakString(chat_text, real_text, sizeof(real_text));
			if ((IsCharNumeric(real_text[1]) && real_text[2] == 'h' && real_text[3] == 't') || (IsCharNumeric(real_text[1]) && IsCharNumeric(real_text[2]) && real_text[3] == 'h' && real_text[4] == 't') || 
				(IsCharNumeric(real_text[1]) && real_text[2] == 's') || (IsCharNumeric(real_text[1]) && IsCharNumeric(real_text[2]) && real_text[3] == 's'))
			{
				FakeClientCommand(client, "sm_%s", real_text[1]);
				return Plugin_Handled;
			}
			// 说类似 !2ht !0s 之类的，隐藏，使用 FakeClientCommand 实现功能
			else if (real_text[0] == '!' || real_text[0] == '/')
			{
				return Plugin_Handled;
			}
		}
		// 称号显示，玩家拥有自定义称号
		if (g_hAllowCustomTags.BoolValue && strcmp(player_data[client].Player_Custom_Designation, "NO_DESIGNATION") != 0)
		{
			// 玩家等级大于等于最低等级 或 小于最低等级时，设置允许，则可以使用自定义称号
			if (player_data[client].Player_Level >= g_hCustomTagsMinLevel.IntValue || (player_data[client].Player_Level < g_hCustomTagsMinLevel.IntValue && g_hAllowIgnoreLevel.BoolValue))
			{
				FormatEx(new_text, sizeof(new_text), "{LG}<%s>{O}%N：{G}%s", player_data[client].Player_Custom_Designation, client, chat_text);
			}
			else
			{
				FormatEx(new_text, sizeof(new_text), "{LG}<%s>{O}%N：{G}%s", player_data[client].Player_Default_Designation, client, chat_text);
			}
		}
		else
		{
			FormatEx(new_text, sizeof(new_text), "{LG}<%s>{O}%N：{G}%s", player_data[client].Player_Default_Designation, client, chat_text);
		}
		CPrintToChatAll(new_text);
		return Plugin_Handled;
    }
    return Plugin_Continue;
}

// 出门近战
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i) && !IsFakeClient(i) && IsPlayerAlive(i) && player_data[i].Player_First_Skill > 0 && player_data[i].Player_Melee > 0)
		{
			GiveFunction(i, MeleesMenu[player_data[i].Player_Melee][0]);
		}
	}
	return Plugin_Continue;
}
// 事件
public void evt_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid")), attacker = GetClientOfUserId(event.GetInt("attacker")), damage = event.GetInt("dmg_health"), type = event.GetInt("type");
	if (IsValidSurvivor(victim) && IsValidSurvivor(attacker) && IsPlayerAlive(victim) && IsPlayerAlive(attacker) && attacker != victim)
	{
		// 使用 g_bBuckShot 记录是否为散弹枪造成的伤害，散弹枪为每个弹丸造成伤害，一次开枪可以造成多次伤害，判断伤害类型为散弹枪且 g_bBuckShot 为假时，设置为真，记录每个弹丸的伤害
		// 下一帧所有伤害造成完毕时，记录一次开枪次数
		if (g_bBuckShot[attacker])
		{
			player_data[attacker].FF_Damage += damage;
		}
		else
		{
			player_data[attacker].FF_Count += 1;
			player_data[attacker].FF_Damage += damage;
		}
		if (type & DMG_BUCKSHOT && !g_bBuckShot[attacker])
		{
			RequestFrame(NextFrame_Unmark, attacker);
			g_bBuckShot[attacker] = true;
		}
	}
}
void NextFrame_Unmark(int client)
{
	g_bBuckShot[client] = false;
}
public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid")), client = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = event.GetBool("headshot");
	if (headshot)
	{
		player_data[client].HeadShot_Count += 1;
	}
	// 判断杀死的感染者是否有效，有效，杀死的感染者数量 +1，继续判断是否杀特回血
	int zombie_class = GetInfectedClass(victim);
	if (IsValidSurvivor(client) && IsPlayerAlive(client) && zombie_class >= ZC_SMOKER && zombie_class < ZC_WITCH)
	{
		player_data[client].SI_Killed += 1;
		switch (zombie_class)
		{
			case ZC_SMOKER:		player_data[client].Smoker_Killed += 1;
			case ZC_BOOMER:		player_data[client].Boomer_Killed += 1;
			case ZC_HUNTER:		player_data[client].Hunter_Killed += 1;
			case ZC_SPITTER:	player_data[client].Spitter_Killed += 1;
			case ZC_JOCKEY:		player_data[client].Jockey_Killed += 1;
			case ZC_CHARGER:	player_data[client].Charger_Killed += 1;
		}
		if (g_hAllowRestoreHealth.BoolValue && player_data[client].Player_Second_Skill > 0)
		{
			int health = GetClientHealth(client), target_health = health;
			switch (player_data[client].Player_Second_Skill)
			{
				case 1:	target_health = health + 1;
				case 2:	target_health = health + 2;
			}
			if (target_health <= MAX_HEALTH)
			{
				SetEntProp(client, Prop_Data, "m_iHealth", target_health);
			}
		}
		// 是否掉落礼物盒
		if (g_hAllowDropGift.BoolValue)
		{
			if ((g_hDropChance.IntValue > 0 && GetURandomIntInRange(1, 100) <= g_hDropChance.IntValue) || (g_hDropChance.IntValue == 0 && GetURandomIntInRange(1, 100) <= g_hDefaultChance.IntValue))
			{
				float si_pos[3] = {0.0};
				GetClientAbsOrigin(victim, si_pos);
				SDKCall(hCreateGift, si_pos, view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), 0);
			}
		}
	}
}
public void evt_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSurvivor(client) && IsPlayerAlive(client))
	{
		player_data[client].Witch_Killed += 1;
	}
}
public void evt_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	bool headshot = event.GetBool("headshot");
	if (IsValidSurvivor(client) && IsPlayerAlive(client))
	{
		player_data[client].CI_Killed += 1;
		if (headshot)
		{
			player_data[client].HeadShot_Count += 1;
		}
	}
}
public void evt_GiftGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSurvivor(client) && IsPlayerAlive(client))
	{
		GiveClientAward(client);
	}
}
public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		player_data[client].Round_Max_BPoints = player_data[client].Round_Max_Exp = 0;
	}
}
void GiveClientAward(int client)
{
	int bpoints_chance = g_hBPointsChance.IntValue, exps_chance = g_hExpChance.IntValue;
	int total_chance = bpoints_chance + exps_chance;
	if (total_chance > 100)
	{
		total_chance = 100;
		bpoints_chance = exps_chance = 50;
	}
	int random_int = GetURandomIntInRange(1, 100);
	if (random_int <= bpoints_chance)
	{
		int bpoints = GetURandomIntInRange(g_hMinBPoints.IntValue, g_hMaxBPoints.IntValue);
		player_data[client].Player_BPoints += bpoints;
		player_data[client].Round_Max_BPoints += bpoints;
		CPrintToChatAll(INFO_GIVE_BPOINST, client, bpoints);
	}
	else if (random_int > bpoints_chance && random_int <= total_chance)
	{
		int exp = GetURandomIntInRange(g_hMinExp.IntValue, g_hMaxExp.IntValue);
		player_data[client].Player_Exp += exp;
		player_data[client].Round_Max_Exp += exp;
		CPrintToChatAll(INFO_GIVE_EXP, client, exp);
		CheckPlayerLevel(client);
	}
}
void CheckPlayerLevel(int client)
{
	int target_exp = CalculateLevelExp(player_data[client].Player_Level + 1);
	if (player_data[client].Player_Exp - target_exp > 0)
	{
		player_data[client].Player_Level += 1;
		// 重新获取玩家基本称号
		char steamID[32] = {'\0'}, sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'};
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
			return;
		}
		FormatEx(sql_statement, sizeof(sql_statement), DQL_DEFAULT_TAGS, TABLENAME_BPOINTS_AND_SKILL, TABLENAME_PLAYER_TAGS, steamID);
		DQL_QueryData(client, PLAYER_TAGS, sql_statement);
	}
}

// 绘制商店面板
public Action Draw_MainMenu(int client)
{
	Menu MainMenu = new Menu(MainMenuHandler);
	MainMenu.SetTitle("这里是B数商店('ω')");
	MainMenu.AddItem("BuyShop", " 购物商店");
	MainMenu.AddItem("SkillShop", "技能商店");
	MainMenu.AddItem("OtherShop", "其他玩意");
	MainMenu.AddItem("Infomation", "个人信息");
	MainMenu.ExitButton = true;
	MainMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public Action Draw_BuyShopMenu(int client)
{
	Menu BuyShopMenu = new Menu(BuyShopMenuHandler);
	BuyShopMenu.SetTitle("B数：%d", player_data[client].Player_BPoints);
	BuyShopMenu.AddItem("BuyGun", " 购物武器");
	BuyShopMenu.AddItem("BuyMedical", "购买药品");
	BuyShopMenu.AddItem("BuyMelee", "购买近战");
	BuyShopMenu.AddItem("BuyOther", "购买其他");
	BuyShopMenu.ExitBackButton = true;
	BuyShopMenu.ExitButton = true;
	BuyShopMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}
public Action Draw_GunMenu(int client)
{
	Menu GunSHopMenu = new Menu(GunShopMenuHandler);
	GunSHopMenu.SetTitle("B数：%d", player_data[client].Player_BPoints);
	DisplayShopMenuItem(client, GunSHopMenu, WeaponMenu, sizeof(WeaponMenu), 2, 8, 3);
	GunSHopMenu.ExitBackButton = true;
	GunSHopMenu.ExitButton = true;
	GunSHopMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Continue;
}
public Action Draw_MedicalMenu(int client)
{
	Menu MedicalMenu = new Menu(MedicalMenuHandler);
	MedicalMenu.SetTitle("B数：%d", player_data[client].Player_BPoints);
	DisplayShopMenuItem(client, MedicalMenu, MedicalsMenu, sizeof(MedicalsMenu));
	MedicalMenu.ExitBackButton = true;
	MedicalMenu.ExitButton = true;
	MedicalMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Continue;
}
public Action Draw_MeleeMenu(int client)
{
	Menu MeleeMenu = new Menu(MeleeMenuHandler);
	MeleeMenu.SetTitle("B数：%d", player_data[client].Player_BPoints);
	DisplayShopMenuItem(client, MeleeMenu, MeleesMenu, sizeof(MeleesMenu));
	MeleeMenu.ExitBackButton = true;
	MeleeMenu.ExitButton = true;
	MeleeMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Continue;
}
public Action Draw_OthersMenu(int client)
{
	Menu OtherMenu = new Menu(OthersMenuHandler);
	OtherMenu.SetTitle("B数：%d", player_data[client].Player_BPoints);
	DisplayShopMenuItem(client, OtherMenu, OthersMenu, sizeof(OthersMenu));
	OtherMenu.ExitBackButton = true;
	OtherMenu.ExitButton = true;
	OtherMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Continue;
}
public Action Draw_SkillMenu(int client)
{
	char info[64] = {'\0'};
	Panel SkillMenu = new Panel();
	FormatEx(info, sizeof(info), "B数：%d", player_data[client].Player_BPoints);
	SkillMenu.DrawText(info);
	switch (player_data[client].Player_First_Skill)
	{
		case 0:
		{
			SkillMenu.DrawItem(" 出门近战(0/1)需100点B数", ITEMDRAW_DEFAULT);
			FormatEx(info, sizeof(info), "    ※出门不会获得近战武器");
			SkillMenu.DrawText(info);
		}
		case 1:
		{
			SkillMenu.DrawItem(" 出门近战(1/1)", ITEMDRAW_DEFAULT);
			if (player_data[client].Player_Melee == 0)
			{
				FormatEx(info, sizeof(info), "    ※未选择出门获得的近战武器");
			}
			else
			{
				FormatEx(info, sizeof(info), "    ※出门将会拥有：%s", MeleesMenu[player_data[client].Player_Melee][1]);
			}
			SkillMenu.DrawText(info);
		}
	}
	if (player_data[client].Player_First_Skill == 1)
	{
		SkillMenu.DrawItem("出门近战选择", ITEMDRAW_DEFAULT);
		FormatEx(info, sizeof(info), "    ※选择出门获得的近战武器");
		SkillMenu.DrawText(info);
	}
	switch (player_data[client].Player_Second_Skill)
	{
		case 0:
		{
			SkillMenu.DrawItem("杀特回血(0/2)需100点B数", ITEMDRAW_DEFAULT);
			FormatEx(info, sizeof(info), "    ※击杀特感无法回复血量");
			SkillMenu.DrawText(info);
		}
		case 1:
		{
			SkillMenu.DrawItem("杀特回血(1/2)需200B点数", ITEMDRAW_DEFAULT);
			FormatEx(info, sizeof(info), "    ※每击杀一只特感回复1点血量");
			SkillMenu.DrawText(info);
		}
		case 2:
		{
			SkillMenu.DrawItem("杀特回血(2/2)", ITEMDRAW_DEFAULT);
			FormatEx(info, sizeof(info), "    ※每击杀一只特感回复2点血量");
			SkillMenu.DrawText(info);
		}
	}
	SkillMenu.DrawItem("重置技能(返还所有B数)", ITEMDRAW_DEFAULT);
	SkillMenu.DrawText(" \n");
	SkillMenu.DrawItem("返回", ITEMDRAW_CONTROL);
	SkillMenu.DrawItem("退出", ITEMDRAW_CONTROL);
	SkillMenu.Send(client, SkillMenuHandler, MENU_TIME_FOREVER);
	return Plugin_Continue;
}
public Action Draw_MeleeSwitchMenu(int client)
{
	Menu MeleeSwitchMenu = new Menu(MeleeSwitchMenuHandler);
	MeleeSwitchMenu.SetTitle("出门近战选择：");
	char item_name[32] = {'\0'}, display_name[64] = {'\0'};
	for (int item = 0; item < sizeof(MeleesMenu); item++)
	{
		IntToString(item, item_name, sizeof(item_name));
		if (item == player_data[client].Player_Melee)
		{
			FormatEx(display_name, sizeof(display_name), "%s ☑", MeleesMenu[item][1]);
		}
		else
		{
			FormatEx(display_name, sizeof(display_name), "%s", MeleesMenu[item][1]);
		}
		MeleeSwitchMenu.AddItem(item_name, display_name);
	}
	MeleeSwitchMenu.ExitBackButton = true;
	MeleeSwitchMenu.ExitButton = true;
	MeleeSwitchMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Continue;
}
public Action Draw_OtherMenu(int client)
{
	char info[64] = {'\0'};
	Panel OtherMenu = new Panel();
	FormatEx(info, sizeof(info), "玩家：%N", client);
	OtherMenu.DrawText(info);
	FormatEx(info, sizeof(info), "B数：%d", player_data[client].Player_BPoints);
	OtherMenu.DrawText(info);
	FormatEx(info, sizeof(info), "等级：%d -> %d", player_data[client].Player_Level, player_data[client].Player_Level + 1);
	OtherMenu.DrawText(info);
	FormatEx(info, sizeof(info), "经验：%d / %d", player_data[client].Player_Exp, CalculateLevelExp(player_data[client].Player_Level + 1));
	OtherMenu.DrawText(info);
	OtherMenu.DrawItem("等级转B数 \n   ※等级下降一级，增加(等级-20)B数", ITEMDRAW_DEFAULT);
	OtherMenu.DrawItem("B数转等级 \n   ※等级增加一级，扣除(等级+1)B数", ITEMDRAW_DEFAULT);
	OtherMenu.DrawText(" \n");
	OtherMenu.DrawItem("返回", ITEMDRAW_CONTROL);
	OtherMenu.DrawItem("离开", ITEMDRAW_CONTROL);
	OtherMenu.Send(client, OtherMenuHandler, MENU_TIME_FOREVER);
	return Plugin_Continue;
}
public Action Draw_InformationMenu(int client)
{
	char info[64] = {'\0'}, sql_statement[SQL_STATEMENT_MAX_LENGTH] = {'\0'}, steamID[32] = {'\0'};
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
		return Plugin_Handled;
	}
	Panel InfoMenu = new Panel();
	FormatEx(info, sizeof(info), "玩家：%N", client);
	InfoMenu.DrawText(info);
	// 实时计算玩家爆头率，每分钟获取的 B 数及经验
	InfoMenu.DrawText("----------");
	int now_time = (GetTime() - player_information[client].Last_Login_Time) + player_data[client].Play_Time;
	int max_time = GetTime() - player_information[client].Last_Login_Time;
	max_time = (max_time > player_data[client].Max_Play_Time) ? max_time : player_data[client].Max_Play_Time;
	float headshot_rate = CalculateEfficiency(client, HeadShot_Rate), minute_bpoints = (GetClientTeam(client) > TEAM_SPECTATOR) ? CalculateEfficiency(client, Minutes_BPoints, now_time) : player_data[client].Minutes_BPoints, minute_exps = (GetClientTeam(client) > TEAM_SPECTATOR) ? CalculateEfficiency(client, Minutes_Exps, now_time) : player_data[client].Minutes_Exps;
	FormatEx(info, sizeof(info), "爆头率：%.2f%", headshot_rate * 100.0);
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "每分钟获取B数：%.2f", minute_bpoints);
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "每分钟获取经验：%.2f", minute_exps);
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "总游玩地图数量：%d", player_data[client].Total_Played_Maps);
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "总游玩时间：%s", FormatDuration(now_time, true));
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "最长游玩时间：%s", FormatDuration(max_time, true));
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "黑枪次数：%d  总伤害：%d", player_data[client].FF_Count, player_data[client].FF_Damage);
	InfoMenu.DrawText(info);
	InfoMenu.DrawText("----------");
	InfoMenu.DrawText("特感击杀：");
	FormatEx(info, sizeof(info), "Smoker：%d  Boomer：%d", player_data[client].Smoker_Killed, player_data[client].Boomer_Killed);
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "Hunter：%d  Spitter：%d", player_data[client].Hunter_Killed, player_data[client].Spitter_Killed);
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "Jockey：%d  Charger：%d", player_data[client].Jockey_Killed, player_data[client].Charger_Killed);
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "Witch：%d", player_data[client].Witch_Killed);
	InfoMenu.DrawText(info);
	FormatEx(info, sizeof(info), "总SI：%d  总CI：%d", player_data[client].SI_Killed, player_data[client].CI_Killed);
	InfoMenu.DrawText(info);
	InfoMenu.DrawText("----------");
	InfoMenu.DrawItem("返回", ITEMDRAW_CONTROL);
	InfoMenu.DrawItem("离开", ITEMDRAW_CONTROL);
	InfoMenu.Send(client, InfoMenuHandler, MENU_TIME_FOREVER);
	// 上传一次数据
	player_data[client].HeadShot_Rate = headshot_rate;
	player_data[client].Minutes_BPoints = minute_bpoints;
	player_data[client].Minutes_Exps = minute_exps;
	FormatEx(sql_statement, sizeof(sql_statement), DML_UPDATE_EFFICIENCY, TABLENAME_PLAYER_INFORMATION, TABLENAME_BPOINTS_AND_SKILL, player_data[client].HeadShot_Count, 
	headshot_rate, minute_bpoints, minute_exps, steamID, steamID);
	DML_ManageData(sql_statement);
	return Plugin_Continue;
}

// 菜单句柄
public int MainMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32] = {'\0'};
		menu.GetItem(item, info, sizeof(info));
		if (strcmp(info, "BuyShop") == 0)
		{
			Draw_BuyShopMenu(client);
		}
		else if (strcmp(info, "SkillShop") == 0)
		{
			Draw_SkillMenu(client);
		}
		else if (strcmp(info, "OtherShop") == 0)
		{
			Draw_OtherMenu(client);
		}
		else if (strcmp(info, "Infomation") == 0)
		{
			Draw_InformationMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
public int BuyShopMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32] = {'\0'};
		menu.GetItem(item, info, sizeof(info));
		if (strcmp(info, "BuyGun") == 0)
		{
			Draw_GunMenu(client);
		}
		else if (strcmp(info, "BuyMedical") == 0)
		{
			Draw_MedicalMenu(client);
		}
		else if (strcmp(info, "BuyMelee") == 0)
		{
			Draw_MeleeMenu(client);
		}
		else if (strcmp(info, "BuyOther") == 0)
		{
			Draw_OthersMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Draw_MainMenu(client);
		EmitSoundToClient(client, BUTTON_SOUND, _);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
public int GunShopMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32] = {'\0'};
		menu.GetItem(item, info, sizeof(info));
		int index = StringToInt(info), cost = StringToInt(WeaponMenu[index][2]);
		if (index == 1)
		{
			GiveFunction(client, WeaponMenu[index][0]);
			CPrintToChatAll(INFO_BUY_AMMO, client);
		}
		else if (!player_data[client].Not_First_Buy && ((index >= 1 && index < 2) || (index > 2 && index < 8)))
		{
			player_data[client].Not_First_Buy = true;
			GiveFunction(client, WeaponMenu[index][0]);
			CPrintToChatAll(INFO_FIRST_BUY, client, WeaponMenu[index][1], player_data[client].Player_BPoints);
		}
		else if (player_data[client].Player_BPoints - cost < 0)
		{
			EmitSoundToClient(client, ERROR_SOUND, _);
			CPrintToChat(client, INFO_NOT_ENOUGH_BPOINTS, player_data[client].Player_BPoints, WeaponMenu[index][1]);
			Draw_GunMenu(client);
		}
		else
		{
			player_data[client].Player_BPoints -= cost;
			GiveFunction(client, WeaponMenu[index][0]);
			CPrintToChatAll(INFO_BUY_GUN, client, WeaponMenu[index][2], WeaponMenu[index][1], player_data[client].Player_BPoints);
		}
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Draw_BuyShopMenu(client);
		EmitSoundToClient(client, BUTTON_SOUND, _);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
public int MedicalMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32] = {'\0'};
		menu.GetItem(item, info, sizeof(info));
		int index = StringToInt(info), cost = StringToInt(MedicalsMenu[index][2]);
		if (player_data[client].Player_BPoints - cost < 0)
		{
			EmitSoundToClient(client, ERROR_SOUND, _);
			CPrintToChat(client, INFO_NOT_ENOUGH_BPOINTS, player_data[client].Player_BPoints, MedicalsMenu[index][1]);
			Draw_MedicalMenu(client);
		}
		else
		{
			player_data[client].Player_BPoints -= cost;
			GiveFunction(client, MedicalsMenu[index][0]);
			CPrintToChatAll(INFO_BUY_MEDICAL, client, MedicalsMenu[index][2], player_data[client].Player_BPoints);
		}
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Draw_BuyShopMenu(client);
		EmitSoundToClient(client, BUTTON_SOUND, _);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
public int MeleeMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32] = {'\0'};
		menu.GetItem(item, info, sizeof(info));
		int index = StringToInt(info), cost = StringToInt(MeleesMenu[index][2]);
		if (player_data[client].Player_BPoints - cost < 0)
		{
			EmitSoundToClient(client, ERROR_SOUND, _);
			CPrintToChat(client, INFO_NOT_ENOUGH_BPOINTS, player_data[client].Player_BPoints, MeleesMenu[index][1]);
			Draw_MeleeMenu(client);
		}
		else
		{
			player_data[client].Player_BPoints -= cost;
			GiveFunction(client, MeleesMenu[index][0]);
			CPrintToChatAll(INFO_BUY_GUN, client, MeleesMenu[index][2], MeleesMenu[index][1], player_data[client].Player_BPoints);
		}
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Draw_BuyShopMenu(client);
		EmitSoundToClient(client, BUTTON_SOUND, _);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
public int OthersMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32] = {'\0'};
		menu.GetItem(item, info, sizeof(info));
		int index = StringToInt(info), cost = StringToInt(OthersMenu[index][2]);
		if (player_data[client].Player_BPoints - cost < 0)
		{
			EmitSoundToClient(client, ERROR_SOUND, _);
			CPrintToChat(client, INFO_NOT_ENOUGH_BPOINTS, player_data[client].Player_BPoints, OthersMenu[index][1]);
			Draw_OthersMenu(client);
		}
		else
		{
			player_data[client].Player_BPoints -= cost;
			GiveFunction(client, OthersMenu[index][0]);
			CPrintToChatAll(INFO_BUY_MEDICAL, client, OthersMenu[index][2], OthersMenu[index][1], player_data[client].Player_BPoints);
		}
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Draw_BuyShopMenu(client);
		EmitSoundToClient(client, BUTTON_SOUND, _);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
public int SkillMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		if (item == 1)
		{
			if (player_data[client].Player_First_Skill < 1)
			{
				// 玩家当前 B 数 - 100 之后是否大于 0，大于则可以学习技能
				if (player_data[client].Player_BPoints - 100 > 0)
				{
					player_data[client].Player_BPoints -= 100;
					player_data[client].Player_First_Skill += 1;
					EmitSoundToClient(client, BUTTON_SOUND, _);
				}
				else
				{
					EmitSoundToClient(client, ERROR_SOUND, _);
					CPrintToChat(client, INFO_CANT_LEARN_SKILL, player_data[client].Player_BPoints, "出门近战技能");
				}
			}
			else if (player_data[client].Player_First_Skill == 1)
			{
				EmitSoundToClient(client, INFO_SOUND, _);
				CPrintToChat(client, INFO_MAX_SKILL, "出门近战技能");
			}
		}
		// 玩家一技能大于 0 说明可以使用出门近战，进入近战选择
		else if (item == 2 && player_data[client].Player_First_Skill > 0)
		{
			Draw_MeleeSwitchMenu(client);
			EmitSoundToClient(client, BUTTON_SOUND, _);
			return 0;
		}
		// 玩家一技能小于 0，或选择的是第三选项且一技能大于 0，此时出现近战选择第二选项，说明进入二技能选择
		else if ((item == 2 && player_data[client].Player_First_Skill < 1) || (item == 3 && player_data[client].Player_First_Skill > 0))
		{
			if (player_data[client].Player_Second_Skill < 1 && player_data[client].Player_BPoints - 100 > 0)
			{
				player_data[client].Player_BPoints -= 100;
				player_data[client].Player_Second_Skill += 1;
				EmitSoundToClient(client, BUTTON_SOUND, _);
			}
			else if (player_data[client].Player_Second_Skill < 2 && player_data[client].Player_BPoints - 200 > 0)
			{
				player_data[client].Player_BPoints -= 200;
				player_data[client].Player_Second_Skill += 1;
				EmitSoundToClient(client, BUTTON_SOUND, _);
			}
			else if (player_data[client].Player_Second_Skill == 2)
			{
				EmitSoundToClient(client, INFO_SOUND, _);
				CPrintToChat(client, INFO_MAX_SKILL, "杀特回血技能");
			}
			else
			{
				EmitSoundToClient(client, ERROR_SOUND, _);
				CPrintToChat(client, INFO_CANT_LEARN_SKILL, player_data[client].Player_BPoints, "杀特回血技能");
			}
		}
		// 玩家一技能小于 0，或选择的是第四选项且一技能大于 0，此时出现近战选择第二选项，说明进入重置技能
		else if ((item == 3 && player_data[client].Player_First_Skill < 1) || (item == 4 && player_data[client].Player_First_Skill > 0))
		{
			int total_bpoints = 0;
			if (player_data[client].Player_First_Skill == 1)
			{
				total_bpoints += 100;
			}
			switch (player_data[client].Player_Second_Skill)
			{
				case 1:	total_bpoints += 100;
				case 2: total_bpoints += 200;
			}
			if (total_bpoints > 0)
			{
				player_data[client].Player_BPoints += total_bpoints;
				player_data[client].Player_First_Skill = player_data[client].Player_Second_Skill = player_data[client].Player_Melee = 0;
				EmitSoundToClient(client, INFO_SOUND, _);
				CPrintToChat(client, INFO_RESET_SKILL);
			}
		}
		else if ((item == 4 && player_data[client].Player_First_Skill < 1) || (item == 5 && player_data[client].Player_First_Skill > 0))
		{
			Draw_MainMenu(client);
			EmitSoundToClient(client, BUTTON_SOUND, _);
			return 0;
		}
		else if ((player_data[client].Player_First_Skill < 1 && (item == 5 || item > 5)) || (player_data[client].Player_First_Skill > 0 && (item == 6 || item > 6)))
		{
			delete menu;
			return 0;
		}
		Draw_SkillMenu(client);
	}
	return 0;
}
public int MeleeSwitchMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32] = {'\0'};
		menu.GetItem(item, info, sizeof(info));
		int index = StringToInt(info);
		if (index != player_data[client].Player_Melee)
		{
			player_data[client].Player_Melee = index;
			CPrintToChat(client, INFO_CHANGE_MELEE, MeleesMenu[index][1]);
			Draw_MeleeSwitchMenu(client);
		}
	}
	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		Draw_SkillMenu(client);
		EmitSoundToClient(client, BUTTON_SOUND, _);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
public int OtherMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 1:
			{
				// 需要限制大于 20 级才可使用，否则等级 - 20 后加上的 B 数为负值
				if (player_data[client].Player_Level > 20)
				{
					player_data[client].Player_BPoints += player_data[client].Player_Level - 20;
					player_data[client].Player_Exp -= CalculateLevelExp(player_data[client].Player_Level);
					player_data[client].Player_Level -= 1;
					Draw_OtherMenu(client);
					EmitSoundToClient(client, BUTTON_SOUND, _);
					return 0;
				}
				EmitSoundToClient(client, ERROR_SOUND, _);
				CPrintToChat(client, INFO_LEVEL2BPONT_ERROR, player_data[client].Player_Level);
				Draw_OtherMenu(client);
			}
			case 2:
			{
				if (player_data[client].Player_BPoints - (player_data[client].Player_Level + 1) >= 0)
				{
					player_data[client].Player_BPoints -= player_data[client].Player_Level + 1;
					player_data[client].Player_Exp += CalculateLevelExp(player_data[client].Player_Level + 1);
					player_data[client].Player_Level += 1;
					Draw_OtherMenu(client);
					EmitSoundToClient(client, BUTTON_SOUND, _);
					return 0;
				}
				EmitSoundToClient(client, ERROR_SOUND, _);
				CPrintToChat(client, INFO_BPOINT2LEVEL_ERROR, player_data[client].Player_BPoints);
				Draw_OtherMenu(client);
			}
			case 3:
			{
				Draw_MainMenu(client);
				EmitSoundToClient(client, BUTTON_SOUND, _);
			}
			case 4:
			{
				delete menu;
			}
		}
	}
	return 0;
}
public int InfoMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		if (item == 1)
		{
			Draw_MainMenu(client);
			EmitSoundToClient(client, BUTTON_SOUND, _);
		}
		else if (item == 2)
		{
			delete menu;
		}
	}
	return 0;
}

void DisplayShopMenuItem(int client, Menu menu, const char[][][] array, const int size, int free_min = -1, int free_max = -1, int free_except = -1)
{
	int page = size / MENU_PAGE_ITEM, page_count = 0;
	char item_name[32] = {'\0'}, display_name[64] = {'\0'};
	if (!player_data[client].Not_First_Buy)
	{
		for (int item = 1; item < size; item++)
		{
			IntToString(item, item_name, sizeof(item_name));
			if (item == page_count * MENU_PAGE_ITEM + 1 && item >= free_min - 1 && item <= free_max - 1 && item != free_except - 1 && page_count <= page)
			{
				FormatEx(display_name, sizeof(display_name), " %s(0点B数)", array[item][1]);
				page_count += 1;
			}
			else if (item == page_count * MENU_PAGE_ITEM + 1 && page_count <= page)
			{
				FormatEx(display_name, sizeof(display_name), " %s(%s点B数)", array[item][1], array[item][2]);
				page_count += 1;
			}
			else if (item >= free_min - 1 && item <= free_max - 1 && item != free_except - 1)
			{
				FormatEx(display_name, sizeof(display_name), "%s(0点B数)", array[item][1]);
			}
			else
			{
				FormatEx(display_name, sizeof(display_name), "%s(%s点B数)", array[item][1], array[item][2]);
			}
			menu.AddItem(item_name, display_name);
		}
	}
	else
	{
		for (int item = 1; item < size; item++)
		{
			IntToString(item, item_name, sizeof(item_name));
			if (item == page_count * MENU_PAGE_ITEM + 1 && page_count <= page)
			{
				FormatEx(display_name, sizeof(display_name), " %s(%s点B数)", array[item][1], array[item][2]);
				page_count += 1;
			}
			else
			{
				FormatEx(display_name, sizeof(display_name), "%s(%s点B数)", array[item][1], array[item][2]);
			}
			menu.AddItem(item_name, display_name);
		}
	}
}
void GiveFunction(int client, char[] name)
{
	int flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", name);
	SetCommandFlags("give", flags);
}
int CalculateLevelExp(int level)
{
	int sum = 0;
	for (int i = 1; i <= level; i++)
	{
		sum += i * 100;
	}
	return sum;
}
float CalculateEfficiency(int client, EFFICIENCY_TYPE type, int now_time = 0)
{
	switch (type)
	{
		case HeadShot_Rate:
		{
			float total_kill = float(player_data[client].SI_Killed + player_data[client].CI_Killed);
			return (total_kill == 0.0) ? 0.00 : float(player_data[client].HeadShot_Count) / total_kill;
		}
		case Minutes_BPoints:
		{
			float minute_bpoints = (now_time < 60) ? 0.00 : float(player_data[client].Player_BPoints) / float(now_time / 60);
			return minute_bpoints;
		}
		case Minutes_Exps:
		{
			float minute_exps = (now_time < 60) ? 0.00 : float(player_data[client].Player_Exp) / float(now_time / 60);
			return minute_exps;
		}
	}
	return -1.0;
}
int GetURandomIntInRange(int min, int max)
{
	return (GetURandomInt() % (max - min + 1)) + min;
}
bool IsLegalTag(int client, const char[] string)
{
	int pos = 0, length = 0;
	while (string[pos] != '\0')
	{
		// 判断是否大小写英文字母或数字
		if (IsCharNumeric(string[pos]) || (string[pos] >= 65 && string[pos] <= 90) || (string[pos] >= 97 && string[pos] <= 122))
		{
			pos += 1;
			length += 1;
		}
		// 如果当前字符为 multiple char，向后跳过3个字符
		else if (IsCharMB(string[pos]))
		{
			pos += 3;
			length += 1;
		}
		// 检查到一个非法字符，返回假
		else
		{
			CPrintToChat(client, INFO_ILLEGAL_CHAR);
			return false;
		}
	}
	// 判断长度是否超出限制
	if (length > g_hCustomTagsLength.IntValue)
	{
		CPrintToChat(client, INFO_CHAR_OUTLENGHT, length, g_hCustomTagsLength.IntValue);
		return false;
	}
	return true;
}