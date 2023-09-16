#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <logger>
#include <treeutil>

#define CVAR_FLAG FCVAR_NOTIFY
#define INVALID_CLIENT -1
/* 检测吃铁的时间间隔需要少于伤害统计输出时间间隔，否则 round_end 无法检测最后吃铁 */
#define IRON_CHECK_INTERVAL 0.5
// 从 Tank 死亡到开始输出伤害的延迟时间, 如果有插件在这个时间前踢出 Tank 会无法打印伤害
#define DAMAGE_DISPLAY_DELAY 0.3

#define SOUND_PATH "ui/pickup_secret01.wav"
#define PLUGIN_PREFIX "[TankDamage]"

public Plugin myinfo = 
{
	name 			= "Tank Damage Announce 2.0",
	author 			= "夜羽真白",
	description 	= "Tank 伤害统计 2.0 版本",
	version 		= "2023/1/16",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar
	g_hAllowAnnounce,
	g_hAllowForceKillAnnounce,
	g_hAllowPrintLiveTime,
	g_hMissionFailedAnnounce,
	g_hAllowPrintZeroDamage,
	g_hAllowSound;
ConVar
	g_hLogLevel;

/* Tank 受到来自玩家的伤害，tankId，clientId */
int
	tankHurt[MAXPLAYERS + 1][MAXPLAYERS + 1],
	// Tank 血量记录
	tankHealth[MAXPLAYERS + 1],
	// Tank 死亡前血量记录
	tankLastHelath[MAXPLAYERS + 1];

float
	// 这个 Tank 的存活时间
	tankLiveTime[MAXPLAYERS + 1];

bool
	// 插件是否延迟加载
	lateLoad,
	// 是否已经打印过这个 Tank 的伤害统计
	hasPrintDamage[MAXPLAYERS + 1];

Handle
	ironCheckTimer[MAXPLAYERS + 1][2];

Logger
	log;

/* 玩家受到来自 Tank 伤害结构体，tankId，clientId */
enum struct PlayerHurt
{
	int punch;
	int rock;
	int iron;
	int gotDamage;
	void init() {
		this.punch = this.rock = this.iron = this.gotDamage = 0;
	}
}
PlayerHurt playerHurts[MAXPLAYERS + 1][MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {

	EngineVersion version = GetEngineVersion();
	if (version != Engine_Left4Dead2) {
		strcopy(error, err_max, "本插件仅适用于 Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	lateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hAllowAnnounce = CreateConVar("tank_damage_enable", "1", "是否允许在 Tank 死亡后输出生还者对 Tank 的伤害统计", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowForceKillAnnounce = CreateConVar("tank_damage_force_kill_announce", "0", "Tank 被强制处死或自杀时是否输出生还者对 Tank 的伤害统计", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowPrintLiveTime = CreateConVar("tank_damage_print_livetime", "1", "是否显示 Tank 存活时间", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hMissionFailedAnnounce = CreateConVar("tank_damage_failed_announce", "1", "生还者团灭时在场还有 Tank 是否显示生还者对 Tank 的伤害统计", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowPrintZeroDamage = CreateConVar("tank_damage_print_zero", "1", "是否允许显示对 Tank 零伤的玩家", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hAllowSound = CreateConVar("tank_damage_allow_sound", "1", "Tank 生成时是否播放声音", CVAR_FLAG, true, 0.0, true, 1.0);
	// 日志记录
	g_hLogLevel = CreateConVar("tank_damage_log_level", "38", "插件日志记录级别 (1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR) 数字相加", CVAR_FLAG, true, 1.0);
	
	log = new Logger(g_hLogLevel.IntValue);

	// HookEvents
	HookEvent("round_start", roundStartHandler);
	HookEvent("player_spawn", playerSpawnHandler);
	HookEvent("player_death", playerDeathHandler);
	HookEvent("round_end", roundEndHandler);
	HookEvent("player_hurt", playerHurtHandler);

	// 插件延迟加载
	if (lateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i))
				continue;
			SDKHook(i, SDKHook_OnTakeDamage, onTakeDamageHandler);
		}
	}
}

public void OnAllPluginsLoaded() {
	if (!LibraryExists("left4dhooks")) {
		LogMessage	("\n==========\n本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行\n==========\n");
		SetFailState("\n==========\n本插件需要前置插件 \"[L4D & L4D2] Left 4 DHooks Direct\" 方可运行\n==========\n");
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamage, onTakeDamageHandler);
}

public void OnMapStart() {
	PrecacheSound(SOUND_PATH);
}

/* 检测生还者是否吃铁 */
public Action onTakeDamageHandler(int victim, int& attacker, int& inflictor, float& damage, int& damagetype) {
	// 无效攻击者或受害者
	if (!IsValidSurvivor(victim) || !isTank(victim))
		return Plugin_Continue;
	// 检查令目标受到伤害的实体是否有效
	if (!IsValidEntity(inflictor) || !IsValidEdict(inflictor))
		return Plugin_Continue;
	// 检查实体是否具有 Tank 可打物体的发光特性
	if (!HasEntProp(inflictor, Prop_Send, "m_hasTankGlow") || GetEntProp(inflictor, Prop_Send, "m_hasTankGlow", 1) != 1)
		return Plugin_Continue;
	/* 生还者吃到的是铁 */
	/* 第一次未创建时钟，需要删除重新创建，后续吃到多次伤害也需要删除重新创建，因此无需判断时钟是否为 null */
	delete ironCheckTimer[victim][0];
	delete ironCheckTimer[victim][1];
	DataPack pack = new DataPack();
	pack.Reset();
	pack.WriteCell(attacker);
	pack.WriteCell(victim);
	ironCheckTimer[victim][0] = CreateTimer(IRON_CHECK_INTERVAL, checkIronHandler, pack);
	ironCheckTimer[victim][1] = pack;
	return Plugin_Continue;
}

public Action checkIronHandler(Handle timer, DataPack pack)
{
	if (pack == null)
		return Plugin_Continue;
	pack.Reset();
	int attacker = pack.ReadCell(), victim = pack.ReadCell();
	delete pack;
	ironCheckTimer[victim][1] = null;
	if (!isTank(attacker) || !IsValidSurvivor(victim))
	{
		ironCheckTimer[victim][0] = null;
		return Plugin_Stop;
	}
	playerHurts[attacker][victim].iron++;
	ironCheckTimer[victim][0] = null;
	return Plugin_Stop;
}

public void playerHurtHandler(Event event, const char[] name, bool dontBroadcast) {

	int attacker,
		victim,
		damage,
		remainHealth;
	attacker = GetClientOfUserId(event.GetInt("attacker"));
	victim = GetClientOfUserId(event.GetInt("userid"));
	damage = event.GetInt("dmg_health");
	remainHealth = event.GetInt("health");

	static char weapon[64],
				playerName[MAX_NAME_LENGTH];
	event.GetString("weapon", weapon, sizeof(weapon));

	if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker))
		return;
	if (victim < 1 || victim > MaxClients || !IsClientInGame(victim))
		return;
	if (!IsPlayerAlive(attacker) || !IsPlayerAlive(victim))
		return;

	// Tank 对玩家造成伤害
	if (isTank(attacker) && IsValidSurvivor(victim)) {
		playerHurts[attacker][victim].gotDamage += damage;
		// 判断玩家是吃拳还是吃石
		if (strcmp(weapon, "tank_claw") == 0)
			playerHurts[attacker][victim].punch++;
		else if (strcmp(weapon, "tank_rock") == 0)
			playerHurts[attacker][victim].rock++;
	} else if (IsValidSurvivor(attacker) && isTank(victim) && !IsClientIncapped(victim)) {
		GetClientName(attacker, playerName, sizeof(playerName));
		// 玩家对 Tank 造成伤害
		tankHurt[victim][attacker] += damage;
		// Tank 有死亡动画，最后一次伤害不会算入 playerHurt 中，因此需要记录最后一次剩余血量，Tank 死亡时加入到生还者伤害中
		tankLastHelath[victim] = remainHealth;
	}
}

public void playerSpawnHandler(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!isTank(client) || !IsPlayerAlive(client))
		return;
	
	/* 延迟一帧获取 Tank 血量，否则可能获取不到 */
	RequestFrame(nextFrameGetTankHealthHandler, client);
	tankLiveTime[client] = GetGameTime();
	/* 清空这个 Tank 的伤害统计 */
	clearTankDamage(client);
	hasPrintDamage[client] = false;
	/* 显示 Tank 生成 */
	if (!IsFakeClient(client))
		CPrintToChatAll("[{G}!{W}] {G}Tank {W}({G}%N{W}) {B}已经生成", client);
	else
		CPrintToChatAll("[{G}!{W}] {G}Tank {W}({G}AI{W}) {B}已经生成");
	// 播放声音
	if (g_hAllowSound.BoolValue)
		EmitSoundToAll(SOUND_PATH);
}

public void nextFrameGetTankHealthHandler(int client)
{
	if (!isTank(client) || !IsPlayerAlive(client))
		return;
	tankHealth[client] = GetEntProp(client, Prop_Data, "m_iHealth");
	log.debugAndInfo("%s: Tank(%N), 索引 %d, 当前血量 %d", PLUGIN_PREFIX, client, client, tankHealth[client]);
}

public void playerDeathHandler(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker")), victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidSurvivor(attacker) || !IsPlayerAlive(attacker) || !isTank(victim))
		return;
	/* 谁杀死了克，加 Tank 最后剩余的血量 */
	tankHurt[victim][attacker] += tankLastHelath[victim];
	/* 计算 Tank 存活时间 */
	tankLiveTime[victim] = GetGameTime() - tankLiveTime[victim];
	/* 是否是强制杀死或自杀 */
	if ((!IsValidClient(attacker) || attacker == victim) && !g_hAllowForceKillAnnounce.BoolValue)
		return;
	/* 如果已经显示过了 Tank 伤害，则不再显示 */
	if (hasPrintDamage[victim])
		return;
	
	// 否则创建时钟准备显示 Tank 的伤害报告
	CreateTimer(DAMAGE_DISPLAY_DELAY, printTankDamageHandler, victim);
	hasPrintDamage[victim] = true;
}

/* 回合开始，清空所有人的 Tank 伤害统计 */
public void roundStartHandler(Event event, const char[] name, bool dontBroadcast)
{
	clearTankDamage(INVALID_CLIENT);
}

public void roundEndHandler(Event event, const char[] name, bool dontBroadcast) {
	int i;
	if (!g_hMissionFailedAnnounce.BoolValue)
		return;
	
	// 检测生还者是否全部死亡，如果全部死亡且场上存在 Tank，显示 Tank 伤害统计
	if (isSurvivorFailed()) {
		for (i = 1; i <= MaxClients; i++) {
			if (!isTank(i) || !IsPlayerAlive(i))
				continue;
			// 计算 Tank 存活时长
			tankLiveTime[i] = GetGameTime() - tankLiveTime[i];
			if (tankLiveTime[i] < 0)
				break;
			
			int health = GetEntProp(i, Prop_Data, "m_iHealth");
			if (health < 0)
				break;
			int percent = RoundToNearest(float(GetClientHealth(i)) / float(tankHealth[i]) * 100.0);

			CPrintToChatAll("[{G}!{W}] {G}%N {W}剩余 {G}%d{W}({G}%d%%{W}) {B}血量", i, health, percent);

			// 如果已经显示过了 Tank 伤害，则不再显示
			if (hasPrintDamage[i])
				return;
			
			// 否则创建时钟延迟显示 Tank 伤害
			CreateTimer(DAMAGE_DISPLAY_DELAY, printTankDamageHandler, i);
			hasPrintDamage[i] = true;
		}
	}
}

public Action printTankDamageHandler(Handle timer, int client) {
	if (!IsValidClient(client))
		return Plugin_Stop;
	
	doPrintTankDamage(client);
	return Plugin_Stop;
}

/**
* 给克
* @param oldTank 当前 Tank 玩家客户端索引
* @param newTank 新的 Tank 玩家索引
* @return void
**/
public void TP_OnTankPass(int oldTank, int newTank) {
	if (!IsValidClient(oldTank) || !IsValidClient(newTank))
		return;
	log.debugAndInfo("%s: Tank 控制权转换, 由 %N 转到 %N", PLUGIN_PREFIX, oldTank, newTank);
	// 旧的 Tank 的玩家伤害数据转移到新的 Tank 上
	int i;
	for (i = 1; i <= MaxClients; i++) {
		// 转移当前在场的生还者的数据
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;
		log.debugAndInfo("%s: 开始转移生还者 %N 的数据, 在 Tank(%N) 下伤害: 拳 %d, 石 %d, 铁 %d, 承伤 %d", PLUGIN_PREFIX, i,
		oldTank, playerHurts[oldTank][i].punch, playerHurts[newTank][i].rock, playerHurts[newTank][i].iron,
		playerHurts[newTank][i].gotDamage);

		playerHurts[newTank][i].punch = playerHurts[oldTank][i].punch;
		playerHurts[newTank][i].rock = playerHurts[oldTank][i].rock;
		playerHurts[newTank][i].iron = playerHurts[oldTank][i].iron;
		playerHurts[newTank][i].gotDamage = playerHurts[oldTank][i].gotDamage;
		// 初始化旧 Tank 对玩家的伤害数据
		playerHurts[oldTank][i].init();
	}
}

/**
* 打印 Tank 伤害报告
* @param client 需要打印的 Tank 客户端索引
* @return void
**/
void doPrintTankDamage(int client) {
	if (!g_hAllowAnnounce.BoolValue)
		return;
	// 不是有效客户端索引, 返回, 必须要在 DAMAGE_DISPLAY_DELAY 时间后再踢出 Tank
	if (!IsValidClient(client))
		return;
	// 无效的 Tank 血量
	if (tankHealth[client] < 1)
		return;
	
	// 显示标题
	if (!IsFakeClient(client))
		CPrintToChatAll("[{G}!{W}] {B}生还者对 {G}Tank {W}({G}%N{W}) {B}的伤害统计", client);
	else
		CPrintToChatAll("[{G}!{W}] {B}生还者对 {G}Tank {W}({G}AI{W}) {B}的伤害统计");

	// 显示 Tank 存活时间
	if (g_hAllowPrintLiveTime.BoolValue) {
		if (!IsFakeClient(client))
			CPrintToChatAll("[{G}!{W}] {G}%N {B}存活时间：{G}%s", client, getTime(tankLiveTime[client]));
		else
			CPrintToChatAll("[{G}!{W}] {G}Tank {B}存活时间：{G}%s", getTime(tankLiveTime[client]));
	}

	// 统计在场玩家数量
	static int i, count, index;
	count = 0;
	index = 0;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;
		count++;
	}

	static int totalDamge, totalGotDamage, damagePercent;

	int[][] survivorDamage = new int[count][2];

	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;
		
		totalDamge += tankHurt[client][i];
		totalGotDamage += playerHurts[client][i].gotDamage;
		damagePercent += getDamageAsPercent(tankHurt[client][i], tankHealth[client]);

		survivorDamage[index][0] = i;
		survivorDamage[index++][1] = tankHurt[client][i];

		log.debugAndInfo("%s: %N 对 Tank(%N) 的伤害报告: 总伤害 %d, 拳 %d, 石 %d, 铁 %d, 承伤 %d", PLUGIN_PREFIX, i, client, tankHurt[client][i], playerHurts[client][i].punch, playerHurts[client][i].rock, playerHurts[client][i].iron, playerHurts[client][i].gotDamage);
	}

	// 按照玩家对 Tank 的伤害降序排序
	SortCustom2D(survivorDamage, index, sortByDamageDesc);
	// 如果使用 getDamageAsPercent 获得的总伤害加起来小于 100 而大于 99.5，调整伤害百分比显示 
	static int percentAdjust,
				lastPercent,
				exactDamagePercent,
				survivor,
				damage;

	percentAdjust = 0, lastPercent = 100;
	if (damagePercent < 100 && float(totalDamge) > (tankHealth[client] - (tankHealth[client] / 200.0)))
		percentAdjust = 100 - damagePercent;

	char playerName[MAX_NAME_LENGTH];
	// 打印生还者对 Tank 的伤害：[666(%66)][拳:6(%6)][石:6(%6)][铁:6(%6)][承伤:666(%66)] 测试哥
	for (i = 0; i < index; i++) {
		// 获取到生还者索引和他对 Tank 的伤害
		survivor = survivorDamage[i][0];
		damage = survivorDamage[i][1];

		// 当前生还者无效, 跳过
		if (!IsClientInGame(survivor) || GetClientTeam(survivor) != TEAM_SURVIVOR)
			continue;

		damagePercent = getDamageAsPercent(damage, tankHealth[client]);
		if (percentAdjust != 0 && damage > 0 && !isExactPercent(damage, tankHealth[client])) {
			exactDamagePercent = damagePercent + percentAdjust;
			
			if (exactDamagePercent <= lastPercent) {
				damagePercent = exactDamagePercent;
				percentAdjust = 0;
			}
		}
		
		// 允许显示零伤人员或不允许显示零伤人员但这个人的伤害大于 0，允许输出
		if (g_hAllowPrintZeroDamage.BoolValue || (!g_hAllowPrintZeroDamage.BoolValue && damage > 0)) {
			if (!IsValidClient(survivor))
				continue;
			GetClientName(survivor, playerName, sizeof(playerName));
			
			// 如果这个生还者不在游戏中则显示无效
			if (!IsClientInGame(survivor))
				FormatEx(playerName, sizeof(playerName), "%s(无效)", playerName);

			log.debugAndInfo("%s: Tank %d, 生还索引: %d, 伤害 %d, 百分比 %d%%, 名字 %s", PLUGIN_PREFIX, client, survivor, damage, damagePercent, playerName);

			CPrintToChatAll("{B}[{W}%d{B}({W}%d%%{B})]\
			 [{G}拳:{W}%d]\
			  [{G}石:{W}%d]\
			   [{G}铁:{W}%d]\
			    [{G}承伤:{W}%d{B}({W}%d%%{B})]\
				 {G}%s",
			damage, damagePercent,
			playerHurts[client][survivor].punch,
			playerHurts[client][survivor].rock,
			playerHurts[client][survivor].iron,
			playerHurts[client][survivor].gotDamage, totalGotDamage == 0 ? 0 : RoundToNearest(float(playerHurts[client][survivor].gotDamage) / float(totalGotDamage) * 100.0),
			playerName);
		}	
	}
}


/* 按照伤害对 survivorDamage[][] 进行降序排序，伤害相同则按照玩家索引降序排序 */
int sortByDamageDesc(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	return elem1[1] > elem2[1] ? -1 : elem1[1] == elem2[1] ? elem1[0] > elem2[0] ? -1 : elem1[0] == elem2[0] ? 0 : 1 : 1;
}

bool isTank(int client) {
	return IsValidInfected(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK;
}

int getDamageAsPercent(int damage, int health) {
	if (damage < 1)
		return 0;
	return RoundToNearest((float(damage) / float(health)) * 100.0);
}

bool isExactPercent(int damage, int health) {
	float percent = (damage / health) * 100.0, difference = (getDamageAsPercent(damage, health)) - percent;
	return FloatAbs(difference) < 0.001 ? true : false;
}

bool isSurvivorFailed() {
	int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;
		if (IsPlayerAlive(i) && !IsClientIncapped(i))
			return false;
	}
	return true;
}

stock int getSurvivorCount()
{
	static int i, count;
	count = 0;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR) { continue; }
		count++;
	}
	return count;
}

void clearTankDamage(int client) {
	int i, j;
	/* Tank 生成时，这是个克，清除这个克的伤害统计 */
	if (client != INVALID_CLIENT)
	{
		for (i = 1; i <= MaxClients; i++)
		{
			tankHurt[client][i] = 0;
			playerHurts[client][i].init();
		}
	}
	else
	{
		/* 清空所有人的 Tank 伤害统计 */
		for (i = 1; i <= MaxClients; i++)
		{
			hasPrintDamage[i] = false;
			for (j = 1; j <= MaxClients; j++)
			{
				tankHurt[i][j] = 0;
				playerHurts[i][j].init();
			}
		}
	}
}

char[] getTime(float time)
{
	char result[64] = {'\0'};
	int exacTime = RoundToNearest(time);
	if (exacTime < 60) { FormatEx(result, sizeof(result), "%d秒", exacTime); }
	else if (exacTime > 60 && exacTime < 3600)
	{
		int minute = exacTime / 60, second = exacTime % 60;
		FormatEx(result, sizeof(result), "%d分钟%d秒", minute, second);
	}
	else
	{
		int hour = exacTime / 3600, minute = (exacTime % 3600) / 60, second = (exacTime % 3600) % 60;
		FormatEx(result, sizeof(result), "%d小时%d分钟%d秒", hour, minute, second);
	}
	return result;
}