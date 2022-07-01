#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include "treeutil\treeutil.sp"

#define CVAR_FLAG FCVAR_NOTIFY
#define EYE_ANGLE_UP_HEIGHT 15.0
#define NAV_MESH_HEIGHT 20.0
#define FALL_DETECT_HEIGHT 120.0
#define FORCE_ATTACK_DIST 500.0
#define COMMAND_INTERVAL 1.0

public Plugin myinfo = 
{
	name 			= "Ai Boomer 2.0",
	author 			= "夜羽真白",
	description 	= "Ai Boomer 增强 2.0 版本",
	version 		= "2.0.0.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar g_hAllowBhop, g_hBhopSpeed, g_hUpVision, g_hTurnVision, g_hForceBile, g_hBileFindRange, g_hVomitRange, g_hVomitDuration, g_hVomitInterval, g_hTurnInterval;
// Bools
bool can_bile[MAXPLAYERS + 1] = true, in_bile_interval[MAXPLAYERS + 1] = false;
// Ints
int bile_target[MAXPLAYERS + 1][MAXPLAYERS + 1], bile_target_num[MAXPLAYERS + 1][3];

public void OnPluginStart()
{
	// CreateConVars
	g_hAllowBhop = CreateConVar("ai_BoomerBhop", "1", "是否开启 Boomer 连跳", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hBhopSpeed = CreateConVar("ai_BoomerBhopSpeed", "90.0", "Boomer 连跳速度", CVAR_FLAG, true, 0.0);
	g_hUpVision = CreateConVar("ai_BoomerUpVision", "1", "Boomer 喷吐时是否上抬视角", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hTurnVision = CreateConVar("ai_BoomerTurnVision", "1", "Boomer 喷吐时是否旋转视角", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hForceBile = CreateConVar("ai_BoomerForceBile", "0", "是否开启生还者到 Boomer 喷吐范围内强制被喷", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hBileFindRange = CreateConVar("ai_BoomerBileFindRange", "300", "在这个距离内有被控或倒地的生还 Boomer 会优先攻击，0 = 关闭此功能", CVAR_FLAG, true, 0.0, true, 1.0);
	g_hTurnInterval = CreateConVar("ai_BoomerTurnInterval", "5", "Boomer 喷吐旋转视角时每隔多少帧转移一个目标", CVAR_FLAG, true, 0.0);
	g_hVomitRange = FindConVar("z_vomit_range");
	g_hVomitDuration = FindConVar("z_vomit_duration");
	g_hVomitInterval = FindConVar("z_vomit_interval");
	// HookEvents
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("player_shoved", evt_PlayerShoved);
	// SetConVars
	SetConVarFloat(FindConVar("boomer_exposed_time_tolerance"), 10000.0);
	SetConVarFloat(FindConVar("boomer_vomit_delay"), 0.1);
}
public void OnPluginEnd()
{
	ResetConVar(FindConVar("boomer_exposed_time_tolerance"));
	ResetConVar(FindConVar("boomer_vomit_delay"));
}

public void evt_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsBoomer(client))
	{
		in_bile_interval[client] = true;
		CreateTimer(1.5, Timer_ResetAbility, client);
	}
}
public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsBoomer(client))
	{
		can_bile[client] = true;
		in_bile_interval[client] = false;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if (IsBoomer(client))
	{
		float self_pos[3] = {0.0}, self_eye_pos[3] = {0.0}, target_pos[3] = {0.0}, target_eye_pos[3] = {0.0}, vec_speed[3] = {0.0}, cur_speed = 0.0;
		int flags = GetEntityFlags(client), target = GetClientAimTarget(client, true), closet_survivor_dist = GetClosetSurvivorDistance(client);
		bool has_sight = view_as<bool>(GetEntProp(client, Prop_Send, "m_hasVisibleThreats"));
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec_speed);
		cur_speed = SquareRoot(Pow(vec_speed[0], 2.0) + Pow(vec_speed[1], 2.0));
		GetClientAbsOrigin(client, self_pos);
		GetClientEyePosition(client, self_eye_pos);
		// 上抬视野，可喷的生还者人数大于 0 且不在 cd 时间内，转视野和上抬视野
		if (bile_target_num[client][0] > 0 && g_hTurnVision.BoolValue && !in_bile_interval[client])
		{
			if (IsValidSurvivor(bile_target[client][bile_target_num[client][1]]) && bile_target_num[client][2] <= g_hTurnInterval.IntValue)
			{
				float bile_target_pos[3] = {0.0}, dist = 0.0;
				GetClientAbsOrigin(bile_target[client][bile_target_num[client][1]], target_pos);
				GetClientEyePosition(bile_target[client][bile_target_num[client][1]], bile_target_pos);
				MakeVectorFromPoints(self_eye_pos, bile_target_pos, bile_target_pos);
				NormalizeVector(bile_target_pos, bile_target_pos);
				GetVectorAngles(bile_target_pos, bile_target_pos);
				dist = GetVectorDistance(self_pos, target_pos);
				if (g_hUpVision.BoolValue)
				{
					// 计算需要上抬的角度
					if (self_pos[2] == target_pos[2])
					{
						bile_target_pos[0] = 0.0;
						bile_target_pos[0] -= 0.040 * dist;
						// PrintToConsoleAll("[Ai-Boomer]：当前目标 %N，高度相等，距离 %.2f，计算得出角度 %.2f", bile_target[client][bile_target_num[client][1]], dist, bile_target_pos[0]);
					}
					// 目标 z 高度减去自身 z 高度小于 0，表示目标处于自身下方
					else if (target_pos[2] - self_pos[2] < 0)
					{
						bile_target_pos[0] = 0.0;
						bile_target_pos[0] += (0.030 * dist) + 0.05 * FloatAbs(target_pos[2] - self_pos[2]);
						// PrintToConsoleAll("[Ai-Boomer]：当前目标 %N，在下面，距离 %.2f，计算角度 %.2f", bile_target[client][bile_target_num[client][1]], dist, bile_target_pos[0]);
					}
					// 目标 z 高度减去自身 z 高度大于 0，表示目标处于自身上方
					else if (target_pos[2] - self_pos[2] > 0)
					{
						bile_target_pos[0] = 0.0;
						bile_target_pos[0] -= (0.030 * dist) + 0.15 * FloatAbs(target_pos[2] - self_pos[2]);
						// PrintToConsoleAll("[Ai-Boomer]：当前目标 %N，在上面，距离 %.2f，计算角度 %.2f", bile_target[client][bile_target_num[client][1]], dist, bile_target_pos[0]);
					}
				}
				TeleportEntity(client, NULL_VECTOR, bile_target_pos, NULL_VECTOR);
				bile_target_num[client][2] += 1;
			}
			else
			{
				bile_target_num[client][1] += 1;
				bile_target_num[client][2] = 0;
			}
		}
		// 靠近生还者，立即喷吐
		if ((flags & FL_ONGROUND) && has_sight && closet_survivor_dist <= RoundToNearest(0.8 * g_hVomitRange.FloatValue) && !in_bile_interval[client] && can_bile[client])
		{
			buttons |= IN_FORWARD;
			buttons |= IN_ATTACK;
			CreateTimer(g_hVomitDuration.FloatValue, Timer_ResetBile, client);
			can_bile[client] = false;
		}
		// 强行被喷
		if (g_hForceBile.BoolValue && (buttons & IN_ATTACK) && !in_bile_interval[client] && IsValidSurvivor(target))
		{
			in_bile_interval[client] = true;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == view_as<int>(TEAM_SURVIVOR) && IsPlayerAlive(i))
				{
					GetClientEyePosition(i, target_eye_pos);
					Handle hTrace = TR_TraceRayFilterEx(self_eye_pos, target_eye_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, client);
					if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == i)
					{
						if (GetVectorDistance(self_eye_pos, target_eye_pos) <= g_hVomitRange.FloatValue)
						{
							L4D_CTerrorPlayer_OnVomitedUpon(i, client);
						}
					}
					delete hTrace;
					hTrace = INVALID_HANDLE;
				}
			}
			CreateTimer(g_hVomitInterval.FloatValue, Timer_ResetAbility, client);
		}
		// 连跳
		if (g_hAllowBhop.BoolValue && has_sight && (flags & FL_ONGROUND) && 0.5 * g_hVomitRange.FloatValue < closet_survivor_dist < 10000.0 && cur_speed > 160.0 && IsValidSurvivor(target))
		{
			float vel_buffer[3] = {0.0};
			GetClientAbsOrigin(target, target_pos);
			vel_buffer = CalculateVel(self_pos, target_pos, g_hBhopSpeed.FloatValue);
			buttons |= IN_JUMP;
			buttons |= IN_DUCK;
			if (Do_Bhop(client, buttons, vel_buffer))
			{
				return Plugin_Changed;
			}
		}
		// 爬梯时，禁止连跳
		if (GetEntityMoveType(client) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	return Plugin_Continue;
}
// 重置胖子能力使用限制
public Action Timer_ResetAbility(Handle timer, int client)
{
	in_bile_interval[client] = false;
}
public Action Timer_ResetBile(Handle timer, int client)
{
	can_bile[client] = false;
	in_bile_interval[client] = true;
	CreateTimer(g_hVomitInterval.FloatValue, Timer_ResetAbility, client);
}

// 获取目标
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if (IsBoomer(specialInfected))
	{
		// 寻找范围内符合要求的玩家
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == view_as<int>(TEAM_SURVIVOR) && IsPlayerAlive(i) && (IsClientIncapped(i) || IsClientPinned(i)))
			{
				float self_eye_pos[3] = {0.0}, target_eye_pos[3] = {0.0};
				GetClientEyePosition(specialInfected, self_eye_pos);
				GetClientEyePosition(i, target_eye_pos);
				if (g_hBileFindRange.FloatValue != 0.0 && GetVectorDistance(self_eye_pos, target_eye_pos) <= g_hBileFindRange.FloatValue)
				{
					Handle hTrace = TR_TraceRayFilterEx(self_eye_pos, target_eye_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, i);
					if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == i)
					{
						curTarget = i;
						return Plugin_Changed;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}
// 当生还被胖子喷中时，开始计算范围内的玩家
public Action L4D_OnVomitedUpon(int victim, int &attacker, bool &boomerExplosion)
{
	int target_num = 0;
	if (IsBoomer(attacker) && IsValidSurvivor(victim))
	{
		// 计算范围内的玩家
		float self_pos[3] = {0.0}, target_pos[3] = {0.0}, self_eye_pos[3] = {0.0}, target_eye_pos[3] = {0.0};
		GetClientAbsOrigin(attacker, self_pos);
		GetClientEyePosition(attacker, self_eye_pos);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == view_as<int>(TEAM_SURVIVOR) && IsPlayerAlive(i))
			{
				GetClientAbsOrigin(i, target_pos);
				GetClientEyePosition(i, target_eye_pos);
				if (GetVectorDistance(self_pos, target_pos) <= g_hVomitRange.FloatValue + 100.0)
				{
					// 判断可视性
					Handle hTrace = TR_TraceRayFilterEx(self_eye_pos, target_eye_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, attacker);
					if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == i)
					{
						bile_target[attacker][target_num] = i;
						target_num += 1;
					}
					delete hTrace;
					hTrace = INVALID_HANDLE;
				}
			}
		}
		bile_target_num[attacker][0] = target_num;
		CreateTimer(g_hVomitDuration.FloatValue, Timer_ResetBileTarget, attacker);
	}
}
public Action Timer_ResetBileTarget(Handle timer, int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		bile_target[client][i] = 0;
	}
	bile_target_num[client][0] = bile_target_num[client][1] = bile_target_num[client][2] = 0;
}

// 方法，是否 AI 胖子
bool IsBoomer(int client)
{
	return view_as<bool>(GetInfectedClass(client) == view_as<int>(ZC_BOOMER) && IsFakeClient(client));
}
// 计算与目标之间的向量
float[] CalculateVel(float self_pos[3], float target_pos[3], float force)
{
	float vecbuffer[3] = {0.0};
	SubtractVectors(target_pos, self_pos, vecbuffer);
	NormalizeVector(vecbuffer, vecbuffer);
	ScaleVector(vecbuffer, force);
	return vecbuffer;
}
// 检测下一帧的位置是否会撞墙或向下受到伤害或会掉落
bool Dont_HitWall_Or_Fall(int client, float vel[3])
{
	bool hullrayhit = false;
	int down_hullray_hitent = -1;
	char down_hullray_hitent_classname[16] = '\0';
	float selfpos[3] = {0.0}, resultpos[3] = {0.0}, mins[3] = {0.0}, maxs[3] = {0.0}, hullray_endpos[3] = {0.0}, down_hullray_startpos[3] = {0.0}, down_hullray_endpos[3] = {0.0}, down_hullray_hitpos[3] = {0.0};
	GetClientAbsOrigin(client, selfpos);
	AddVectors(selfpos, vel, resultpos);
	GetClientMins(client, mins);
	GetClientMaxs(client, maxs);
	selfpos[2] += NAV_MESH_HEIGHT;
	resultpos[2] += NAV_MESH_HEIGHT;
	// 由自身位置 +NAV_MESH_HEIGHT 高度 向前射出大小为 mins，maxs 的固体，检测前方 NAV_MESH_HEIGHT 距离是否能撞到，撞到则不允许连跳
	Handle hTrace = TR_TraceHullFilterEx(selfpos, resultpos, mins, maxs, MASK_NPCSOLID_BRUSHONLY, TR_EntityFilter);
	if (TR_DidHit(hTrace))
	{
		hullrayhit = true;
		TR_GetEndPosition(hullray_endpos, hTrace);
		if (GetVectorDistance(selfpos, hullray_endpos) <= NAV_MESH_HEIGHT)
		{
			delete hTrace;
			return false;
		}
	}
	delete hTrace;
	resultpos[2] -= NAV_MESH_HEIGHT;
	// 没有撞到，则说明前方 g_hAttackRange 距离内没有障碍物，接着进行下一帧理论位置向下的检测，检测是否有会对自身造成伤害的位置
	if (!hullrayhit)
	{
		down_hullray_startpos = resultpos;
	}
	CopyVectors(down_hullray_startpos, down_hullray_endpos);
	down_hullray_endpos[2] -= 100000.0;
	Handle hDownTrace = TR_TraceHullFilterEx(down_hullray_startpos, down_hullray_endpos, mins, maxs, MASK_NPCSOLID_BRUSHONLY, TR_EntityFilter);
	if (TR_DidHit(hDownTrace))
	{
		TR_GetEndPosition(down_hullray_hitpos, hDownTrace);
		// 如果向下的射线撞到的位置减去起始位置的高度大于 FALL_DETECT_HEIGHT 则说明会掉下去，返回 false
		if (FloatAbs(down_hullray_startpos[2] - down_hullray_hitpos[2]) > FALL_DETECT_HEIGHT)
		{
			delete hDownTrace;
			return false;
		}
		down_hullray_hitent = TR_GetEntityIndex(hDownTrace);
		GetEdictClassname(down_hullray_hitent, down_hullray_hitent_classname, sizeof(down_hullray_hitent_classname));
		if (strcmp(down_hullray_hitent_classname, "trigger_hurt") == 0)
		{
			delete hDownTrace;
			return false;
		}
		delete hDownTrace;
		return true;
	}
	delete hDownTrace;
	return false;
}
bool TR_EntityFilter(int entity, int mask)
{
	if (entity <= MaxClients)
	{
		return false;
	}
	else if (entity > MaxClients)
	{
		char classname[16] = '\0';
		GetEdictClassname(entity, classname, sizeof(classname));
		if (strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0 || strcmp(classname, "prop_physics") == 0 || strcmp(classname, "tank_rock") == 0)
		{
			return false;
		}
	}
	return true;
}
// 胖子连跳
bool Do_Bhop(int client, int &buttons, float vec[3])
{
	if (buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		if (ClientPush(client, vec))
		{
			return true;
		}
	}
	return false;
}
bool ClientPush(int client, float vec[3])
{
	float curvel[3] = {0.0};
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", curvel);
	AddVectors(curvel, vec, curvel);
	if (Dont_HitWall_Or_Fall(client, curvel))
	{
		if (GetVectorLength(curvel) <= 250.0)
		{
			NormalizeVector(curvel, curvel);
			ScaleVector(curvel, 251.0);
		}
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, curvel);
		return true;
	}
	return false;
}
// 阻止或恢复喷吐
/* void BlockBile(int client, bool block = true)
{
	int ability = GetEntPropEnt(client, Prop_Send,"m_customAbility");
	if (IsValidEntity(ability) && block)
	{
		SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + 0.5);
	}
	else if (IsValidEntity(ability) && !block)
	{
		SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() - 0.5);
	}
} */