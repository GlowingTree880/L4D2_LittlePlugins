/**
* @Author 夜羽真白
* @Date 2023-07-19 11:33:03
* @Description 特感刷新队列控制
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

#define INFECTED_ARRAY_SIZE 7
#define KV_ROOT_ELEMENT "InfectedQueue"

#define DEFAULT_TEST_COUNT 10

ConVar
	// 特感队列 kv 文件位置
	g_hKvFileName,
	// 单一特感模式
	g_hSingleInfectedMode,
	// 是否禁止某种特感在 Tank 在场时刷新
	g_hBanSpawnClassDuringTank,
	// 禁止某种特感在 Tank 在场时禁止刷新策略
	g_hBanSpawnClassDuringTankStrategy,
	// 是否开启 6 特以上没种特感都产生一只
	g_hOverSixEveryClassOne,
	// 是否开启 6 特以下特感轮换, 1,5 特轮换最后一只, 2,3,4 特轮换最后 2 只
	g_hUnreachSixAlternate;
	
ConVar
	g_hInfectedCvarLimit[6];

bool
	isInfectedQueueKvFileExist,
	// Tank 在场时禁止刷新的特感类型记录, 如禁止刷新 Spitter 则 4 号位置为 true
	banSpawnClassDurintTank[INFECTED_ARRAY_SIZE];

int
	// 上一波刷新过, 且在轮换位上的特感类型记录, 如 5 特轮换最后一个位置的 Boomer, 则索引 0 位置为 2, 4 特轮换最后两个 Boomer, Spitter, 则索引 0 位置为 2, 1 位置为 4, 最多只会轮换 2 个特感, 如有其他需求需要自行增加数组大小
	alternateInfecteds[2];

char
	kvFilePath[PLATFORM_MAX_PATH];

KeyValues
	infectedQueueKv;

ArrayList
	infectedQueuePosition[31];

stock const char INFECTED_NAME[9][] = {
	"None",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank"
};

// Tank 在场时特感的禁止刷新策略 BanSpawnDuringTank
enum {
	BSDT_NONE,
	BSDT_BAN,
	BSDT_REPLACE,
	BSDT_SIZE
};

public void infectedQueueOnModulStart()
{
	g_hKvFileName = CreateConVar("inf_queue_kvfile_path", "data/infected_queue.cfg", "特感刷新队列文件位置", CVAR_FLAG);
	g_hSingleInfectedMode = CreateConVar("inf_single_infected", "0", "启用哪种特感的单特感模式 (只会刷新这一种特感, 0: 禁用此功能, [1 - 6] 启用 Smoker, Boomer, Hunter, Spitter, Jockey, Charger 的单特感模式)", CVAR_FLAG, true, 0.0, true, 6.0);
	g_hBanSpawnClassDuringTank = CreateConVar("inf_ban_spawn_class_tank", "4", "Tank 在场时禁用哪种特感的刷新 (0: 禁用此功能, 英文逗号隔开, 例 [4,5] 则 Tank 在场时禁用 Spitter 与 Jockey 刷新)", CVAR_FLAG);
	g_hBanSpawnClassDuringTankStrategy = CreateConVar("inf_ban_spawn_tank_strategy", "2", "Tank 在场时对禁用刷新特感测策略 (1: 禁止刷新, 2: 替换为可以刷新的其他特感)", CVAR_FLAG, true, float(BSDT_NONE + 1), true, float(BSDT_SIZE - 1));
	g_hOverSixEveryClassOne = CreateConVar("inf_over_six_every_class_one", "1", "超过 6 特以上是否更改刷新队列使得每种类型特感产生一只", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hUnreachSixAlternate = CreateConVar("inf_unreach_six_alternative", "1", "是否开启 6 特以下特感轮换 (0: 不开启, 1: 开启)", CVAR_FLAG, true, 0.0, true, 1.0);

	g_hBanSpawnClassDuringTank.AddChangeHook(changeHookBanSpawnClassDuringTank);
	g_hSingleInfectedMode.AddChangeHook(changeHookSingleInfectedMode);
	// 获取 Cvar 每种特感允许刷新的数量
	getCvarLimit();
	for (int i = 0; i < INFECTED_ARRAY_SIZE - 1; i++) {
		g_hInfectedCvarLimit[i].AddChangeHook(changeHookInfectedCvarLimit);
	}
	// 获取 Tank 在场时禁止刷新的特感种类
	getBanSpawnClassDuringTank();
	// 根据特感刷新队列 kv 文件获取特感等待队列
	getInfectedQueuePositionList();

	// 测试指令
	RegAdminCmd("sm_infqueue", cmdGetInfectedQueue, ADMFLAG_BAN, "测试获取一个特感刷新队列");
}

public void infectedQueueOnModuleEnd() {
	int i;
	ArrayList list;
	for (i = 0; i < MaxClients; i++) {
		list = infectedQueuePosition[i];
		if (list == null) {
			continue;
		}
		delete list;
		list = null;
	}
}

/**
* 测试获取一个特感刷新队列
* @param client 使用此命令的客户端
* @param args 命令参数数量
* @return Action
**/
public Action cmdGetInfectedQueue(int client, int args) {
	if (!IsValidClient(client) || IsFakeClient(client)) {
		return Plugin_Handled;
	}

	int testCount;
	if (args == 1) {
		char strCount[32];
		GetCmdArg(1, strCount, sizeof(strCount));
		testCount = StringToInt(strCount);
	} else {
		testCount = DEFAULT_TEST_COUNT;
	}

	static int i, j, infectedType;

	Profiler profiler = new Profiler();
	profiler.Start();

	log.debugAndInfo("\n%s: 开始测试指令: sm_infqueue, 将测试: %d 轮\n", PLUGIN_PREFIX, testCount);
	for (i = 1; i <= testCount; i++) {
		log.debugAndInfo("%s: 当前是第: %d 轮测试", PLUGIN_PREFIX, i);

		for (j = 1; j <= MaxClients; j++) {
			if (!IsValidClient(j) || GetClientTeam(j) != TEAM_INFECTED) {
				continue;
			}
			infectedType = GetEntProp(j, Prop_Send, "m_zombieClass");
			log.debugAndInfo("%s: 当前有一只: %s 在场, %s 在场总数 %d 只", PLUGIN_PREFIX, INFECTED_NAME[infectedType], INFECTED_NAME[infectedType], getSpecificInfectedCount(infectedType));
		}
		log.debugAndInfo("%s: 获取在场特感数量完成", PLUGIN_PREFIX);

		ArrayList queue = getInfectedQueue();
		delete queue;

		log.debugAndInfo("%s: 第: %d 轮测试完成\n", PLUGIN_PREFIX, i);
	}

	profiler.Stop();
	log.debugAndInfo("\n%s: 对指令: sm_infqueue 测试: %d 轮完成, 共耗时 %.3f s\n", PLUGIN_PREFIX, testCount, profiler.Time);
	delete profiler;

	return Plugin_Handled;
} 

/**
* 获取一个特感队列, 获取到的 ArrayList 句柄需要关闭, 无特感刷新队列 kv 文件则随机配置, 有则按照 kv 文件中每个位置允许刷新的特感种类配置, 有 kv 文件, 队列生成完毕后特感数量仍无法达到预期数量, 则再次随机向队列中加入特感种类
* @param 
* @return ArrayList
**/
ArrayList getInfectedQueue() {

	Profiler profiler = new Profiler();
	profiler.Start();

	ArrayList queue = new ArrayList();

	// 获取每种特感在场数量
	int infCount[7]; getInfectedCount(infCount, sizeof(infCount));
	// 获取 Cvar 每种特感允许刷新数量
	int cvarCount[7]; getCvarSpawnCount(cvarCount, sizeof(cvarCount));
	// 获取每种特感可以刷新数量
	int spawnCount[7]; subtractArray(cvarCount, sizeof(cvarCount), infCount, sizeof(infCount), spawnCount, sizeof(spawnCount));

	// 需要刷新的特感数量, 当前存活特感数量, 已经处理的特感数量, 特感等待队列为 null 数量
	int needCount = 0, aliveCount = 0, generatedCount = 0, nullWaitingListCount = 0;
	needCount = g_hInfectedLimit.IntValue - (aliveCount = getTeamClientCount(TEAM_INFECTED, true, false));

	log.debugAndInfo("%s: 当前在场特感数量 %d 只, 需要刷新 %d 只特感", PLUGIN_PREFIX, aliveCount, needCount);

	// 清空当前特感刷新队列
	queue.Clear();

	// 选中的特感类型, 选中特感类型当前在场数量, 有特感队列 kv 文件下当前正在处理的位置, 特感等待队列索引
	int infectedType, infectedCount, handlingIndex = 1, waitingListIndex;
	int tankClient = isTankPresence();
	// 是否正在处理特感等待队列, 有 kv 文件时是否可以随机选择特感
	bool handling, canRandomSelect, tankPresence = (IsValidClient(tankClient) && IsPlayerAlive(tankClient));

	// 特感等待队列, 等待队列拷贝
	ArrayList waitingList, handlingList;
	// 特感名称
	char infectedName[64];

	for (;;) {

		// 为 null 的等待队列等于特感数量, 表示未配置等待队列, 错误退出
		if (nullWaitingListCount >= g_hInfectedLimit.IntValue) {
			SetFailState("\n==========\n 当前 %d 特模式, 未配置任何特感等待队列, 请在 %s 中配置 %d 特的特感等待队列 \n==========\n", g_hInfectedLimit.IntValue, kvFilePath, g_hInfectedLimit.IntValue);
		}

		// 特感需要的数量小于 0 或已经生成了对应需要数量的特感, 跳出
		if (needCount <= 0 || generatedCount >= needCount) {
			break;
		}

		// 只允许刷新单种特感模式
		if (g_hSingleInfectedMode.IntValue > 0) {
			infectedType = g_hSingleInfectedMode.IntValue;
			strcopy(infectedName, sizeof(infectedName), INFECTED_NAME[infectedType]);
			infectedCount = getSpecificInfectedCount(infectedType);
			
			// NOTE: 单特感模式无视 Cvar 数量, 这样 Ht 模式调整 Ht 数量时无需调整 z_hunter_limit, 只需调整插件刷特数量即可
			// Tank 在场且当前特感不允许刷新, 跳出, 单特感模式可无视 Cvar 数量
			if (tankPresence && banSpawnClassDurintTank[infectedType]) {
				log.debugAndInfo("%s: 单特感模式, 当前: %s 允许刷新数量为: %d 只, 在场数量为: %s 只, 不允许继续刷新", PLUGIN_PREFIX, infectedName, spawnCount[infectedType], infectedCount);

				break;
			}
			queue.Push(infectedType);
			spawnCount[infectedType] = spawnCount[infectedType] == 0 ? 0 : spawnCount[infectedType] - 1;

			log.debugAndInfo("%s: 单特感模式, 向特感刷新队列中加入一只: %s, 当前: %s 在场数量: %d 只", PLUGIN_PREFIX, infectedName, infectedName, infectedCount);

			generatedCount++;
			continue;
		}

		// HACK: 多种特感模式下 Tank 在场的刷新控制, 初步完成功能, 检查修复 Bug
		// 允许刷新多种特感模式
		// 特感刷新队列处理完毕, 检查是否还可以加入新的特感, 可以则表示特感队列 kv 文件有位置没配置或配置特感种类过少, 允许随机获取特感种类
		if (handlingIndex > g_hInfectedLimit.IntValue && generatedCount < needCount && !canRandomSelect) {
			canRandomSelect = true;
		}

		if (isInfectedQueueKvFileExist && !handling && handlingIndex <= g_hInfectedLimit.IntValue) {
			// 获取当前处理位置的特感等待队列
			waitingList = infectedQueuePosition[handlingIndex];
			// 当前特感等待队列为空, 跳过
			if (waitingList == null) {
				handlingIndex++;
				nullWaitingListCount++;
				continue;
			} else {
				handlingList = waitingList.Clone();
				handling = true;
			}
		}

		// 没有配置特感队列 kv 文件, 随机选取特感
		if (!isInfectedQueueKvFileExist || canRandomSelect) {
			infectedType = GetRandomIntInRange(ZC_SMOKER, ZC_CHARGER);
			
			// Tank 在场, 且没有配置特感队列 kv 文件
			if (tankPresence && banSpawnClassDurintTank[infectedType]) {
				infectedType = getClassWithBanStrategyDuringTank(infectedType, spawnCount, sizeof(spawnCount));
				// 无效替换 或 使用封锁策略, 跳过这个位置
				if (infectedType < ZC_SMOKER || infectedType > ZC_CHARGER) {
					generatedCount++;
					continue;
				}
			}

			// 该特感不允许刷新了, 进行下一轮循环
			if (spawnCount[infectedType] <= 0) {
				continue;
			}
			queue.Push(infectedType);
			spawnCount[infectedType] = spawnCount[infectedType] == 0 ? 0 : spawnCount[infectedType] - 1;

			strcopy(infectedName, sizeof(infectedName), INFECTED_NAME[infectedType]);
			infectedCount = getSpecificInfectedCount(infectedType);
			log.debugAndInfo("%s: 向特感刷新队列中加入一只：%s, 当前在场 %s 数量: %d 只, 剩余 %s 可刷新数量: %d", PLUGIN_PREFIX, infectedName, infectedName, infectedCount, infectedName, spawnCount[infectedType]);

			if (isInfectedQueueKvFileExist) {
				handlingIndex++;
			}
			generatedCount++;

			continue;
		}

		// 当前位置等待队列为 null, 配置文件中没有配置此位置 或 处理队列为空, 表示此位置可以刷新的所有特感类型都达到在场上限, 无法刷新, 处理下一个位置
		if (waitingList == null || handlingList.Length < 1) {
			log.info("%s: 当前正在处理 %d 号位置, 该位置等待队列是否为 null: %b, 处理队列长度是否小于 1: %b, 跳过, 处理下一个位置", PLUGIN_PREFIX, handlingIndex, waitingList == null, (handlingList == null ? false : handlingList.Length < 1 ? true : false));

			delete handlingList;
			handlingIndex++;
			handling = false;
			continue;
		}

		// 配置了特感队列 kv 文件，从等待队列中随机选取
		waitingListIndex = GetRandomIntInRange(0, handlingList.Length - 1);
		infectedType = handlingList.Get(waitingListIndex);

		// Tank 在场, 且配置了特感队列 kv 文件, 当前随机到的特感类型不允许刷新
		if (tankPresence && banSpawnClassDurintTank[infectedType]) {
			infectedType = getClassWithBanStrategyDuringTank(infectedType, spawnCount, sizeof(spawnCount));
			// 无效替换 或 使用封锁策略, 跳过这个位置
			if (infectedType < ZC_SMOKER || infectedType > ZC_CHARGER) {
				delete handlingList;
				handlingIndex++;
				generatedCount++;
				handling = false;
				continue;
			}
		}

		// 如果选择到当前特感, 且当前特感种类有在场, 在场种类减一, 处理下一个位置
		if (infCount[infectedType] > 0) {
			infCount[infectedType] = infCount[infectedType] == 0 ? 0 : infCount[infectedType] - 1;

			delete handlingList;
			handlingIndex++;
			handling = false;
			continue;
		}

		// 选择到当前特感可刷数量小于等于 0, 擦除这一个特感类型, 随机下一个特感类型
		if (spawnCount[infectedType] <= 0) {
			handlingList.Erase(waitingListIndex);
			continue;
		}
		queue.Push(infectedType);
		spawnCount[infectedType] = spawnCount[infectedType] == 0 ? 0 : spawnCount[infectedType] - 1;

		strcopy(infectedName, sizeof(infectedName), INFECTED_NAME[infectedType]);
		infectedCount = getSpecificInfectedCount(infectedType);
		log.debugAndInfo("%s: 向特感刷新队列中加入一只：%s, 当前在场 %s 数量: %d 只, 剩余 %s 可刷新数量: %d", PLUGIN_PREFIX, infectedName, infectedName, infectedCount, infectedName, spawnCount[infectedType]);

		handlingIndex++;
		generatedCount++;
		
		delete handlingList;
		handling = false;
	}

	profiler.Stop();

	log.debugAndInfo("%s: 特感刷新队列生成完成, 耗时: %.3f s, 当前特感刷新队列: ", PLUGIN_PREFIX, profiler.Time);
	delete profiler;

	printInfectedQueue(queue);

	// 特感刷新队列生成完成后处理接口, 检查 7 特以上是否每种特感产生一个
	postProcessInfectedQueue(queue, spawnCount);

	// 发布队列创建完成事件
	int[] queueArray = new int[queue.Length];
	for (int i = 0; i < queue.Length; i++) {
		queueArray[i] = queue.Get(i);
	}
	Call_StartForward(onInfectedQueueGenerated);
	Call_PushArray(queueArray, queue.Length);
	Call_PushCell(queue.Length);
	Call_Finish();

	// 返回特感刷新队列
	return queue;
}

/**
* 获取在场的每种特感数量
* @param count 特感数量数组
* @param size 特感数量数组长度
* @return void
**/
static void getInfectedCount(int[] count, int size) {
	if (size < INFECTED_ARRAY_SIZE) {
		log.error("%s: 特感数量数组长度不得小于 %d", PLUGIN_PREFIX, INFECTED_ARRAY_SIZE);
		return;
	}

	static int i, class;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i) || IsInGhostState(i)) {
			continue;
		}
		// 获取特感类型并排除 Tank 和 Witch，留下 1 - 6 的特感
		class = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (class < ZC_SMOKER || class > ZC_CHARGER) {
			continue;
		}
		count[class]++;
	}
}

/**
* 从 z_xxx_limit Cvar 中获取当前模式下每种特感允许刷新的数量
* @param count Cvar 特感数量数组
* @param size Cvar 特感数量数组长度
* @return void
**/
static void getCvarSpawnCount(int[] count, int size) {
	if (size < INFECTED_ARRAY_SIZE) {
		log.error("%s: Cvar 特感数量数组长度不得小于 %d", PLUGIN_PREFIX, INFECTED_ARRAY_SIZE);
		return;
	}

	static int i;
	for (i = 1; i < INFECTED_ARRAY_SIZE; i++) {
		if (g_hInfectedCvarLimit[i - 1] == null) {
			continue;
		}
		count[i] = g_hInfectedCvarLimit[i - 1].IntValue;
	}
}

/**
* 根据 z_xxx_limit 获取每种特感限制数量
* @param 
* @return void 
**/
static void getCvarLimit() {
	static int i;
	char cvarStr[64];
	for (i = 1; i < INFECTED_ARRAY_SIZE; i++) {
		FormatEx(cvarStr, sizeof(cvarStr), "z_%s_limit", INFECTED_NAME[i]);
		g_hInfectedCvarLimit[i - 1] = FindConVar(cvarStr);

		if (g_hInfectedCvarLimit[i - 1] == null) {
			log.error("%s: 无法找到对应 Cvar: %s", PLUGIN_PREFIX, cvarStr);
		} else {
			log.debugAll("%s: 成功获取特感: %s 限制数量: %d 只", PLUGIN_PREFIX, INFECTED_NAME[i], g_hInfectedCvarLimit[i - 1].IntValue);
		}
	}
}

/**
* z_xxx_limit Cvar 变动
* @param convar Cvar 句柄
* @param oldValue 旧值
* @param newValue 新值
* @return void
**/
void changeHookInfectedCvarLimit(ConVar convar, const char[] oldValue, const char[] newValue) {
	char cvarName[64];
	convar.GetName(cvarName, sizeof(cvarName));
	log.debugAndInfo("%s: Cvar: %s 值发生改变, 旧值: %s, 新值: %s", PLUGIN_PREFIX, cvarName, oldValue, newValue);
	// 重新获取 Cvar 变动后特感限制值
	getCvarLimit();
}

void changeHookBanSpawnClassDuringTank(ConVar convar, const char[] oldValue, const char[] newValue) {
	// 重新获取 Tank 在场时禁止刷新的特感类型
	getBanSpawnClassDuringTank();
}

void subtractArray(int[] x, int xSize, int[] y, int ySize, int[] z, int zSize) {
	if (xSize != ySize || xSize != zSize || ySize != zSize) {
		log.error("%s: 数组相减时原数组与目标数组与结果数组长度不相等 [%d, %d, %d]", PLUGIN_PREFIX, xSize, ySize, zSize);
		return;
	}

	static int i;
	for (i = 0; i < xSize; i++) {
		z[i] = x[i] - y[i];
	}
}

/**
* 校验特感刷新队列 kv 文件是否有效
* @param 
* @return bool
**/
bool validateInfectedQueueFile() {
	char cvarStr[128];
	g_hKvFileName.GetString(cvarStr, sizeof(cvarStr));
	if (strlen(cvarStr) <= 0) {
		return false;
	}

	BuildPath(Path_SM, kvFilePath, sizeof(kvFilePath), "%s", cvarStr);

	File file = null;
	if (!FileExists(kvFilePath)) {
		log.info("%s: 特感刷新队列文件: %s 不存在, 即将创建文件", PLUGIN_PREFIX, kvFilePath);
		file = OpenFile(kvFilePath, "wt+");
		// 创建文件失败
		if (file == null) {
			log.error("%s: 无法创建特感队列文件: %s, 请手动创建", PLUGIN_PREFIX, kvFilePath);
			return false;
		}
		// 创建成功, 写入根元素
		file.WriteLine("\"%s\"", KV_ROOT_ELEMENT);
		file.WriteLine("{");
		
		for (int i = 1; i <= MaxClients; i++) {
			// 特感数量
			file.WriteLine("\t\"%d\"", i);
			file.WriteLine("\t{");
			for (int j = 1; j < INFECTED_ARRAY_SIZE; j++) {
				file.WriteLine("\t\t\"%s\"\t\"\"", INFECTED_NAME[j]);
			}
			file.WriteLine("\t}");
		}

		file.WriteLine("}");
	}
	delete file;

	log.info("%s: 特感刷新队列文件: %s 校验成功", PLUGIN_PREFIX, kvFilePath);
	return true;
}

/**
* 从特感刷新位置 kv 文件中获取特感刷新位置集合
* @param 
* @return void 
**/
void getInfectedQueuePositionList() {

	Profiler profiler = new Profiler();
	profiler.Start();

	// 清空原有集合
	int i, j;
	for (i = 0; i < MaxClients; i++) {
		if (infectedQueuePosition[i] == null) {
			continue;
		}
		delete infectedQueuePosition[i];
		infectedQueuePosition[i] = null;
	}

	// 检测特感刷新队列文件并读取为 KeyValue
	if (validateInfectedQueueFile()) {
		infectedQueueKv = new KeyValues(KV_ROOT_ELEMENT);
		if (!infectedQueueKv.ImportFromFile(kvFilePath)) {
			log.error("%s: 无法读取特感刷新队列文件: %s 为 KeyValue", PLUGIN_PREFIX, kvFilePath);
		} else {
			isInfectedQueueKvFileExist = true;
			log.info("%s: 特感刷新队列文件: %s 读取为 KeyValue 成功", PLUGIN_PREFIX, kvFilePath);
		}
		char buffer[64];
		if (infectedQueueKv != null) {
			// 跳转到对应特感数量
			g_hInfectedLimit.GetString(buffer, sizeof(buffer));
			if (!infectedQueueKv.JumpToKey(buffer)) {
				delete infectedQueueKv;
				return;
			}
		}
		if (infectedQueueKv != null) {
			int infectedType, count = 0, pos;
			char value[64];
			// 获取每种特感在刷新队列中的位置
			for (i = ZC_SMOKER; i <= ZC_CHARGER; i++) {
				infectedType = i;
				char temp[31][8];

				// 根据特感名称获取特感在刷新队列中允许刷新的位置，如 smoker: 1,3,4,6
				FormatEx(buffer, sizeof(buffer), "%s", INFECTED_NAME[i]);
				infectedQueueKv.GetString(buffer, value, sizeof(value));

				if (strlen(value) > 0) {
					count = ExplodeString(value, ",", temp, 31, 8);
				}

				// 位置字符串：1,3,4,6
				for (j = 0; j < count; j++) {
					if (!IsInteger(temp[j])) {
						continue;
					}
					// pos 代表这个特感的刷新位置, 为每一个数字
					pos = StringToInt(temp[j]);
					// 位置无效或这个特感已经存在于相应的刷新位置中，跳过
					if (pos < ZC_SMOKER || pos > g_hInfectedLimit.IntValue ||
						(infectedQueuePosition[pos] != null && infectedQueuePosition[pos].FindValue(infectedType) >= 0)) {
						continue;
					}
					// 集合为空, 创建新的集合
					if (infectedQueuePosition[pos] == null) {
						infectedQueuePosition[pos] = new ArrayList();
					}
					// 将这个特感加入到相应的刷新位置集合中
					if (infectedQueuePosition[pos] != null) {
						infectedQueuePosition[pos].Push(infectedType);
					}
				}
			}
		}
	}

	delete infectedQueueKv;

	profiler.Stop();
	log.debugAll("%s: 成功获取特感刷新位置集合, 耗时: %.3f s", PLUGIN_PREFIX, profiler.Time);
	log.debugAll("%s: 当前特感刷新位置集合:", PLUGIN_PREFIX);
	for (i = 0; i <= g_hInfectedLimit.IntValue; i++) {
		if (infectedQueuePosition[i] == null) {
			continue;
		}
		log.debugAll("[Position-Index]: %d", i);
		ArrayList position = infectedQueuePosition[i];
		for (j = 0; j < position.Length; j++) {
			log.debugAll("\t\t- %s", INFECTED_NAME[position.Get(j)]);
		}
	}
	delete profiler;
}

/**
* 统计某团队客户端数量
* @param team 团队 ID
* @param includeBot 是否包含 Bot
* @param includeDeath 是否包含死亡客户端
* @return int
**/
int getTeamClientCount(int team, bool includeBot, bool includeDeath) {
	if (team < TEAM_SPECTATOR || team > TEAM_INFECTED) {
		return -1;
	}
	static int i;
	int count = 0;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != team) {
			continue;
		}
		if (!includeBot && IsFakeClient(i)) {
			continue;
		}
		if (!includeDeath && !IsPlayerAlive(i)) {
			continue;
		}
		if (team == TEAM_INFECTED && (GetEntProp(i, Prop_Send, "m_zombieClass") == ZC_TANK || IsInGhostState(i) || IsClientIncapped(i))) {
			continue;
		}
		count++;
	}
	return count;
}

/**
* 获取当前在场的某种特感数量
* @param type 特感种类
* @return int
**/
stock int getSpecificInfectedCount(int type) {
	static int i;
	int count = 0;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i) || IsInGhostState(i)) {
			continue;
		}
		if (GetEntProp(i, Prop_Send, "m_zombieClass") != type) {
			continue;
		}
		count++;
		// 分散刷新情况下, 状态数组中的正在重生的该类型特感数量也统计上
		if (g_hSpawnMethodStrategy.IntValue == SMS_DISPERSE) {
			if (!infectedStates[i].valid || infectedStates[i].infectedType != type) {
				continue;
			}
			count++;
		}
	}
	return count;
}

/**
* 集合深拷贝
* @param source 初始集合
* @param start 起始索引
* @param len 拷贝长度
* @return ArrayList
**/
stock ArrayList copyArrayList(ArrayList source, int start, int len) {
	if (source == null) {
		return null;
	}
	if (start < 0 || start > source.Length || len < 0 || len < start || start + len > source.Length) {
		LogError("Invalid index, start: %d, len: %d, source list length: %d", start, len, source);
		return null;
	}

	ArrayList ret = new ArrayList();

	for (int i = start; i < len; i++) {
		ret.Push(source.Get(i));
	}

	return ret;
}

/**
* 判断当前是否存在 Tank
* @param 
* @return int
**/
static int isTankPresence() {
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_zombieClass") != ZC_TANK || IsClientIncapped(i) || IsInGhostState(i)) {
			continue;
		}
		return i;
	}
	return INVALID_CLIENT_INDEX;
}

void getBanSpawnClassDuringTank() {
	int i, count, class;
	char cvarStr[64], temp[8][8];
	g_hBanSpawnClassDuringTank.GetString(cvarStr, sizeof(cvarStr));
	if (strlen(cvarStr) > 0) {
		count = ExplodeString(cvarStr, ",", temp, 8, 8);
	}
	// 重置数组
	for (i = 0; i < INFECTED_ARRAY_SIZE; i++) {
		banSpawnClassDurintTank[i] = false;
	}
	for (i = 0; i < count; i++) {
		class = StringToInt(temp[i]);
		if (class < ZC_SMOKER || class > ZC_CHARGER) {
			continue;
		}
		banSpawnClassDurintTank[class] = true;
	}
}

/**
* 根据特感替换策略, 替换 Tank 在场时禁止刷新的特感
* @param sourceClass 禁止刷新的特感类型
* @param spawnCount 每种特感剩余刷新数量数组
* @param size 数组长度
* @return int
**/
static int getClassWithBanStrategyDuringTank(int sourceClass, int[] spawnCount, int size) {
	int i, newClass;
	bool spawnCountAvailable;
	// Tank 在场时, 随机到该特感, 该特感不允许刷新, 使用替换策略
	if (g_hBanSpawnClassDuringTankStrategy.IntValue == BSDT_REPLACE) {
		for (i = 1; i < size; i++) {
			// 该特感类型禁止刷新, 跳过
			if (banSpawnClassDurintTank[i]) {
				continue;
			}
			if (spawnCount[i] > 0) {
				newClass = i;
				spawnCountAvailable = true;
				break;
			}
		}
		// 可以被替换, 则加入一个替换后的特感
		if (spawnCountAvailable) {
			log.debugAndInfo("%s: Tank 在场, 当前特感: %s 不允许刷新, 使用替换策略, 新特感: %s", PLUGIN_PREFIX, INFECTED_NAME[sourceClass], INFECTED_NAME[newClass]);

			return i;
		} else {
			log.debugAndInfo("%s: Tank 在场, 当前特感: %s 不允许刷新, 使用替换策略, 其他特感没有余量, 跳过此位置", PLUGIN_PREFIX, INFECTED_NAME[sourceClass]);

			// 不能被替换, 其他特感都没有余量
			return INVALID_CLIENT_INDEX;
		}
	} else if (g_hBanSpawnClassDuringTankStrategy.IntValue == BSDT_BAN) {
		// Tank 在场时, 随机到该特感, 该特感不允许刷新, 使用封锁策略
		log.debugAndInfo("%s: Tank 在场, 当前特感: %s 不允许刷新, 使用封锁策略, 跳过此位置", PLUGIN_PREFIX, INFECTED_NAME[sourceClass]);
	}
	return INVALID_CLIENT_INDEX;
}

/**
* 后处理特感刷新队列
* 当前功能：开启特感数量大于 6 特时每种特感刷新一只, 检查每种特感是否都存在于刷新队列中, 不存在则替换一个队列中数量最多的特感类型
* @param queue 特感刷新队列
* @param spawnCount 特感剩余可刷新数量数组
* @return void
**/
// 2023-08-23: 更改函数签名, ArrayList, int[]
static void postProcessInfectedQueue(ArrayList queue, int spawnCount[INFECTED_ARRAY_SIZE]) {
	if (queue == null) {
		return;
	}
	
	int i, j, infectedType;
	// 配置特感数量大于 6 特且开启每种特感产生一只且非单一特感模式, 开始后处理
	if (g_hInfectedLimit.IntValue > 6 && g_hOverSixEveryClassOne.BoolValue) {
		if (g_hSingleInfectedMode.BoolValue) {
			return;
		}
		// 如果当前特感队列数量小于设置数量, 为上一波没杀完下一波补特感, 不处理, 只处理完整的一波
		if (queue.Length < g_hInfectedLimit.IntValue) {
			return;
		}

		bool haveNotInclude;
		int class, classCount[INFECTED_ARRAY_SIZE];
		// 不存在于队列中的特感类型, 队列中数量最多的特感数量, 队列中最多的特感类型, 刷新队列中的索引
		int notIncludeInfected = INVALID_CLIENT_INDEX, index;
		
		for (;;) {
			// 获取每种特感在刷新队列中的数量
			for (i = 0; i < queue.Length; i++) {
				class = queue.Get(i);
				if (class < ZC_SMOKER || class > ZC_CHARGER) {
					continue;
				}
				classCount[class]++;
			}

			for (i = ZC_SMOKER; i <= ZC_CHARGER; i++) {
				if (classCount[i] <= 0) {
					haveNotInclude = true;

					log.debugAndInfo("%s: 当前允许刷出: %d 只特感, 且每个特感产生一个, 找到了特感: %s 不在刷新队列中", PLUGIN_PREFIX, g_hInfectedLimit.IntValue, INFECTED_NAME[i]);

					// 如果刷新队列当前未满, 可能有位置未配置特感, 则直接将这一种特感类型加入到刷新队列中
					if (queue.Length < g_hInfectedLimit.IntValue) {
						log.debugAndInfo("%s: 特感刷新队列长度 %d, 有剩余位置, 直接加入一只 %s", PLUGIN_PREFIX, queue.Length, INFECTED_NAME[i]);
						queue.Push(i);
						continue;
					}
					notIncludeInfected = i;
				}

				// 当前特感未缺失, 跳过
				if (notIncludeInfected == INVALID_CLIENT_INDEX) {
					continue;
				}

				for (j = ZC_SMOKER; j <= ZC_CHARGER; j++) {
					// 找到了一个存在于刷新队列中且数量大于 1 的特感, 替换
					if (classCount[j] > 1) {
						if ((index = queue.FindValue(j)) >= 0) {
							log.debugAndInfo("%s: 特感刷新队列长度 %d, 无剩余位置, 将索引 %d 位置的特感 %s 替换为 %s", PLUGIN_PREFIX, queue.Length, index, INFECTED_NAME[index], INFECTED_NAME[i]);
							queue.Set(index, i);
							break;
						}
					}
				}
				// 替换完成, 重置 notIncludeInfected
				notIncludeInfected = INVALID_CLIENT_INDEX;
			}

			// 处理完成, 跳出
			if (haveNotInclude && notIncludeInfected == INVALID_CLIENT_INDEX) {
				log.debugAndInfo("%s: 存在缺失的特感类型, 并处理完成, 跳出循环", PLUGIN_PREFIX);
				break;
			}
			// 不存在缺失的特感种类, 跳出
			if (notIncludeInfected == INVALID_CLIENT_INDEX) {
				log.debugAndInfo("%s: 未找到缺失的特感类型, 跳出循环", PLUGIN_PREFIX);
				break;
			}
		}
		log.debugAndInfo("%s: 特感刷新队列后处理完成 (内容: 当前 %d 特, 每种特感均刷新一只)", PLUGIN_PREFIX, g_hInfectedLimit.IntValue);
		printInfectedQueue(queue);
	}
	// 配置 6 特以下特感轮换, 且非单一特感模式, 开始后处理
	if (g_hInfectedLimit.IntValue < 6 && g_hUnreachSixAlternate.BoolValue) {
		if (g_hSingleInfectedMode.BoolValue) {
			return;
		}

		switch (g_hInfectedLimit.IntValue) {
			// 1,5 特, 替换一只特感
			case 1, 5: {
				if (queue.Length < 1) {
					return;
				}
				if (alternateInfecteds[0] < ZC_SMOKER) {
					// 还没有记录轮换特感, 是第一波刷新, 开始记录轮换特感
					alternateInfecteds[0] = queue.Get(queue.Length - 1);
				} else {
					// 已经记录了轮换的特感, 替换最后一只
					infectedType = queue.Get(queue.Length - 1);
					if (infectedType == alternateInfecteds[0]) {
						for (i = ZC_SMOKER; i <= ZC_CHARGER; i++) {
							// 该特感上一波已经刷新过了, 剩余可刷新数量小于等于 0, 跳过
							if (i == infectedType || spawnCount[i] <= 0) {
								continue;
							}
							log.debugAndInfo("%s: 当前刷新队列中索引 %d 的特感类型为 %s, 与上一波记录的轮换类型 %s 相同, 替换为新类型 %s", PLUGIN_PREFIX, queue.Length - 1, INFECTED_NAME[queue.Get(queue.Length - 1)], INFECTED_NAME[alternateInfecteds[0]], INFECTED_NAME[i]);
							
							queue.Set(queue.Length - 1, i);
							break;
						}
					}
					// 没有找到需要轮换的特感, 也记录本波待轮换的特感
					alternateInfecteds[0] = queue.Get(queue.Length - 1);
				}
			} case 2,3,4: {
				// 2,3,4 特, 替换两只特感
				if (queue.Length < 2) {
					return;
				}
				if (alternateInfecteds[0] < ZC_SMOKER && alternateInfecteds[1] < ZC_SMOKER) {
					alternateInfecteds[0] = queue.Get(queue.Length - 2);
					alternateInfecteds[1] = queue.Get(queue.Length - 1);
				} else {
					for (i = 1; i <= 2; i++) {
						infectedType = queue.Get(queue.Length - i);
						if (infectedType == alternateInfecteds[2 - i]) {
							for (j = ZC_SMOKER; j <= ZC_CHARGER; j++) {
								if (j == infectedType || spawnCount[j] <= 0) {
									continue;
								}
								log.debugAndInfo("%s: 当前刷新队列中索引 %d 的特感类型为 %s, 与上一波记录的轮换类型 %s 相同, 替换为新类型 %s", PLUGIN_PREFIX, queue.Length - 1, INFECTED_NAME[queue.Length - 1], INFECTED_NAME[alternateInfecteds[0]], INFECTED_NAME[j]);
								
								queue.Set(queue.Length - i, j);
								break;
							}
						}
					}
					// 记录新的轮换特感
					alternateInfecteds[0] = queue.Get(queue.Length - 2);
					alternateInfecteds[1] = queue.Get(queue.Length - 1);
				}
			}
		}
		log.debugAndInfo("%s: 特感刷新队列后处理完成 (内容: 当前 %d 特, 替换特感)", PLUGIN_PREFIX, g_hInfectedLimit.IntValue);
		printInfectedQueue(queue);
	}

	// 获取本波强控特感的数量, 首先获取在场强控特感数量, 接着在特感队列中获取
	waveDominativeCount = getDominativeInfectedCount();
	for (i = 0; i < queue.Length; i++) {
		infectedType = queue.Get(i);
		if (infectedType == ZC_SMOKER || infectedType == ZC_HUNTER || infectedType == ZC_JOCKEY || infectedType == ZC_CHARGER) {
			waveDominativeCount++;
		}
	}
}

public void changeHookSingleInfectedMode(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (canSpawnNewInfected) {
		return;
	}
	delete infectedQueue;
	infectedQueue = getInfectedQueue();
	log.debugAndInfo("%s: 单一特感模式 Cvar 变动, 旧值 %s, 新值 %s, 处于刷新间隔内, 重新获取特感刷新队列", PLUGIN_PREFIX, oldValue, newValue);
}

/**
* 在控制台中打印特感刷新队列信息
* @param queue 待打印的特感队列
* @return void
**/
void printInfectedQueue(ArrayList queue) {
	log.debugAndInfo("\n===== Infected Queue =====");
	if (queue.Length < 1) {
		log.debugAndInfo("\t\tEmpty");
	}
	for (int i = 0; i < queue.Length; i++) {
		log.debugAndInfo("\t\t[%d]: %s", i + 1, INFECTED_NAME[queue.Get(i)]);
	}
	log.debugAndInfo("\n");
}