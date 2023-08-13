// 整合 confogl 的 bossSpawn 和 witchAndTankIfer 和 bossPercent 插件，适用于战役和对抗，限制坦克女巫刷新数量，刷新位置和提供指令查看本轮坦克女巫刷新地点

#pragma semicolon 1
#pragma newdecls required

#include <left4dhooks>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#define CVAR_FLAGS  FCVAR_NOTIFY
#define MAX_TANKS   5
#define MAX_WITCHES 5
#define DEBUG_ALL   1

ConVar g_hEnableBossSpawn, g_hKilledExtraBoss;
bool   bIsFirstRound = true, bDeleteWitches = false, bFinaleStarted = false;
float  fTankPos[MAX_TANKS][3], fWitchPos[MAX_WITCHES][2][3];
int    iTankCount[2] = { 0 }, iWitchCount[2] = { 0 };
char   sMapName[64] = { 0 };

public void OnPluginStart()
{
	g_hEnableBossSpawn = CreateConVar("lock_boss_spawns", "1", "是否强制对抗中两局的 Boss 刷新在同一位置", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hKilledExtraBoss = CreateConVar("kill_extra_bosses", "1", "是否强制杀死多产生的 Boss", CVAR_FLAGS, true, 0.0, true, 1.0);
	HookEvent("tank_spawn", evt_TankSpawn);
	HookEvent("witch_spawn", evt_WitchSpawn);
	HookEvent("round_end", evt_RoundEnd);
	HookEvent("finale_start", evt_FinaleStart);
}

public void OnMapStart()
{
	bIsFirstRound = true;
	bFinaleStarted = false;
	iTankCount[0] = iTankCount[1] = 0;
	iWitchCount[0] = iWitchCount[1] = 0;
	GetCurrentMap(sMapName, sizeof(sMapName));
	LogMessage("[Boss-Spawn]：当前地图：%s，OnMapStart 执行", sMapName);
}

// 坦克刷新
public void evt_TankSpawn(Event event, const char[] name, bool dontBroadCast)
{
	if (g_hEnableBossSpawn.BoolValue && !bFinaleStarted)
	{
		if (strcmp(sMapName, "c5m5_bridge") != 0)
		{
			// 获得当前坦克 userid
			int client = GetClientOfUserId(event.GetInt("userid"));
			if (iTankCount[view_as<int>(!bIsFirstRound)] < MAX_TANKS)
			{
				#if (DEBUG_ALL)
				{
					LogMessage("[Boss-Spawn]：正在读取当前 Boss 信息，目前刷出第：%d 只坦克", iTankCount[view_as<int>(!bIsFirstRound)] + 1);
				}
				#endif
				// 对抗第一局，刷克，记录当前刷克的位置
				if (bIsFirstRound)
				{
					GetClientAbsOrigin(client, fTankPos[iTankCount[0]]);
					#if (DEBUG_ALL)
					{
						LogMessage("[Boss-Spawn]：记录当前刷新坦克的位置：%.2f，%.2f，%.2f", fTankPos[iTankCount[0]][0], fTankPos[iTankCount[0]][1], fTankPos[iTankCount[0]][2]);
						// 记录坦克数量加一
						iTankCount[0] += 1;
					}
					#endif
				}
				// 非对抗第一局，刷出的坦克数量少于第一局刷出的数量，则把坦克传送到相应位置
				else if (iTankCount[1] < iTankCount[0])
				{
					TeleportEntity(client, fTankPos[iTankCount[1]], NULL_VECTOR, NULL_VECTOR);
					#if (DEBUG_ALL)
					{
						LogMessage("[Boss-Spawn]：当前非对抗第一局，刷新坦克数量少于对抗第一局刷新坦克数量，将刷出的坦克传送到第一局指定位置：%.2f，%.2f，%.2f", fTankPos[iTankCount[1]][0], fTankPos[iTankCount[1]][1], fTankPos[iTankCount[1]][2]);
					}
					#endif
					// 第二局记录坦克数量加一
					iTankCount[1] += 1;
				}
				else
				{
					#if (DEBUG_ALL)
					{
						LogMessage("[Boss-Spawn]：当前非对抗第一局且刷出坦克数量多于第一局刷出坦克数量，无法进行调整，第一局刷出坦克数量：%d，第二局刷出坦克数量：%d", iTankCount[0], iTankCount[1]);
					}
					#endif
					// 强制杀死多生成的坦克
					if (g_hKilledExtraBoss.BoolValue)
					{
						ForcePlayerSuicide(client);
						KickClient(client, "[Boss-Spawn]：踢出多生成的坦克");
						#if (DEBUG_ALL)
						{
							LogMessage("[Boss-Spawn]：已将多余的坦克，ID：%d，踢出", client);
						}
						#endif
					}
				}
			}
			else
			{
				return;
			}
		}
	}
}
// 刷新女巫
public void evt_WitchSpawn(Event event, const char[] name, bool dontBroadCast)
{
	if (g_hEnableBossSpawn.BoolValue)
	{
		int witchIndex = event.GetInt("witchid");
		// 如果本局需要删除女巫，则删除女巫
		if (bDeleteWitches)
		{
			AcceptEntityInput(witchIndex, "kill");
			RemoveEdict(witchIndex);
		}
		// 如果本局刷除的女巫数量小于限制数量，则继续进行
		if (iWitchCount[view_as<int>(!bIsFirstRound)] < MAX_WITCHES)
		{
			if (bIsFirstRound)
			{
				GetEntPropVector(witchIndex, Prop_Send, "m_vecOrigin", fWitchPos[iWitchCount[0]][0]);
				GetEntPropVector(witchIndex, Prop_Send, "m_angRotation", fWitchPos[iWitchCount[0]][1]);
				iWitchCount[0] += 1;
			}
			else if (iWitchCount[1] < iWitchCount[0])
			{
				TeleportEntity(witchIndex, fWitchPos[iWitchCount[1]][0], fWitchPos[iWitchCount[1]][1], NULL_VECTOR);
				iWitchCount[1] += 1;
			}
			else
			{
				#if (DEBUG_ALL)
				{
					LogMessage("[Boss-Spawn]：当前非对抗第一局且刷出的女巫数量多于第一局刷出的女巫数量，无法进行调整，第一局刷出的女巫数量：%d，第二局刷出的女巫数量：%d", iWitchCount[0], iWitchCount[1]);
				}
				#endif
				if (g_hKilledExtraBoss.BoolValue)
				{
					AcceptEntityInput(witchIndex, "kill");
					RemoveEdict(witchIndex);
					#if (DEBUG_ALL)
					{
						LogMessage("[Boss-Spawn]：已将多余的女巫，实体 ID：%d，踢出", witchIndex);
					}
					#endif
				}
			}
		}
		else
		{
			return;
		}
	}
}
// 本局结束
public void evt_RoundEnd(Event event, const char[] name, bool dontBroadCast)
{
	bIsFirstRound = bFinaleStarted = false;
	if (strcmp(sMapName, "c6m1_riverbank") == 0)
	{
		bDeleteWitches = false;
	}
	else
	{
		bDeleteWitches = true;
		CreateTimer(5.0, Timer_WitchTimerReset);
	}
}
// 删除女巫后，将是否删除女巫的判断置为 false
public Action Timer_WitchTimerReset(Handle time)
{
	bDeleteWitches = false;
	return Plugin_Continue;
}
// 救援开始
public Action evt_FinaleStart(Event event, const char[] name, bool dontBroadCast)
{
	bFinaleStarted = true;
	return Plugin_Continue;
}