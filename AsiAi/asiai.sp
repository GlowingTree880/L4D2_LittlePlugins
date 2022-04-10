#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define MAXMOVESPEED 1000
// 特感类型
#define ZC_SMOKER       1
#define ZC_BOOMER       2
#define ZC_HUNTER       3
#define ZC_SPITTER      4
#define ZC_JOCKEY       5
#define ZC_CHARGER      6
#define ZC_WITCH        7
#define ZC_TANK         8
// 数据
#define VEM_MAX 450.0
#define MAXSURVIVORS 8
#define SURVIVORHEIGHT 72.0
#define FL_JUMPING 65922
// SMOKER
#define SMOKERMELEERANGE 300.0
// JOCKEY
#define JOCKEYJUMPDELAY 2.0
#define JOCKEYJUMPNEARDELAY 0.1
#define JOCKEYJUMPRANGE 400.0
#define JOCKEYMINSPEED 130.0
// CHARGER
#define CHARGERMELEEDELAY 0.2
#define CHARGERMELEERANGE 400.0
// HUNTER
#define HUNTERATTACKTIME 5.0
#define HUNTERREPEATSPEED 4
#define HUNTERONGTOUNDSTATE 1
#define HUNTERFLYSTATE 2
#define HUNTERCOOLDOWNTIME 0.5
// TANK
#define TANKMELEESCANDELAY 0.0
#define TANKROCKAIMTIME 2.5
#define TANKROCKAIMDELAY 0.25
#define TANKATTACKRANGEFACTOR 0.90
#define TANKTHROWHEIGHT 100.0
// SPITTER
#define SPITTERRUNSPEED 200.0
#define SPITDELAY 2.0
#define SPITTERJUMPDELAY 0.1

enum AimType
{
	AimEye,
	AimBody,
	AimChest
};

// ConVars
ConVar g_hPlayBackRate;
// Ints
int g_iState[MAXPLAYERS + 1][8];
// Floats
float g_fPlayBackRate, g_fDelay[MAXPLAYERS + 1][8], g_fSiAttackTime, g_fMoveGrad[MAXPLAYERS + 1][3], g_fMoveSpeed[MAXPLAYERS + 1], g_fPos[MAXPLAYERS + 1][3];
// Bools
bool g_bAiEnable[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name 			= "Advance Special Infected AI",
	author 			= "def075, Caibiii, 夜羽真白",
	description 	= "Advanced Special Infected AI",
	version 		= "2022.03.03",
	url 			= "https://github.com/GlowingTree880/L4D2_LittlePlugins"
}

public void OnPluginStart()
{
	g_hPlayBackRate = CreateConVar("ai_TankSequencePlayBackRate", "4.5", "坦克攀爬动画加速速率", FCVAR_NOTIFY, true, 0.0);
	g_hPlayBackRate.AddChangeHook(ConVarChanged_Cvars);
	g_fPlayBackRate = g_hPlayBackRate.FloatValue;
	HookEvent("round_start", evt_RoundStart, EventHookMode_Post);
	HookEvent("player_spawn", evt_PlayerSpawn, EventHookMode_Post);
	HookEvent("tank_spawn", evt_TankSpawn, EventHookMode_Post);
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fPlayBackRate = g_hPlayBackRate.FloatValue;
}

// 向量绘制
// #include "vector/vector_show.sp"

// *********************
//		   事件
// *********************
public void OnMapStart()
{
	CreateTimer(1.0, Timer_MapStartMoveSpeed, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		g_bAiEnable[client] = false;
	}
	InitStatus();
	return Plugin_Continue;
}

public Action evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInfectedBot(client))
	{
		g_bAiEnable[client] = true;
	}
	return Plugin_Continue;
}

public void evt_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsInfectedBot(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK)
	{
		SDKHook(client, SDKHook_PostThinkPost, UpdateThink);
	}
}

// 坦克扔石头力度大小，跳砖设置
public Action L4D_OnCThrowActivate(int ability)
{
	SetConVarString(FindConVar("z_tank_throw_force"), "1000");
	int tankclient = GetEntPropEnt(ability, Prop_Data, "m_hOwnerEntity");
	if (IsInfectedBot(tankclient) && GetZombieClass(tankclient) == ZC_TANK)
	{
		RequestFrame(NextFrame_JumpRock, tankclient);
	}
	return Plugin_Continue;
}

void NextFrame_JumpRock(int tankclient)
{
	int target = GetNearestSurvivor(tankclient);
	if (IsValidSurvivor(target))
	{
		int flags = GetEntityFlags(tankclient);
		if (flags & FL_ONGROUND)
		{
			float eyeangles[3] = 0.0, lookat[3] = 0.0;
			GetClientEyeAngles(tankclient, eyeangles);
			GetAngleVectors(eyeangles, lookat, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(lookat, lookat);
			ScaleVector(lookat, 300.0);
			lookat[2] = 300.0;
			TeleportEntity(tankclient, NULL_VECTOR, NULL_VECTOR, lookat);
		}
	}
}

public void L4D_TankClaw_DoSwing_Pre(int tank, int claw)
{
	SetConVarString(FindConVar("z_tank_throw_force"), "500");
}

// 修正玩家速度
public Action Timer_MapStartMoveSpeed(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			int team = GetClientTeam(client);
			{
				if (team == TEAM_SURVIVOR || team == TEAM_INFECTED)
				{
					float pos[3];
					GetClientAbsOrigin(client, pos);
					g_fMoveGrad[client][0] = pos[0] - g_fPos[client][0];
					g_fMoveGrad[client][1] = pos[1] - g_fPos[client][1];
					g_fMoveGrad[client][2] = pos[2] - g_fPos[client][2];
					// 获取玩家速度
					g_fMoveSpeed[client] = SquareRoot(g_fMoveGrad[client][0] * g_fMoveGrad[client][0] + g_fMoveGrad[client][1] * g_fMoveGrad[client][1]);
					if (g_fMoveSpeed[client] > MAXMOVESPEED)
					{
						g_fMoveSpeed[client] = 0.0;
						g_fMoveGrad[client][0] = 0.0;
						g_fMoveGrad[client][1] = 0.0;
						g_fMoveGrad[client][2] = 0.0;
					}
					g_fPos[client] = pos;
				}
			}
		}
	}
	return Plugin_Continue;
}

public void UpdateThink(int client)
{
	switch (GetEntProp(client, Prop_Send, "m_nSequence"))
	{
		case 16, 17, 18, 19, 20, 21, 22, 23:
		{
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", g_fPlayBackRate);
		}
		case 54, 55, 56, 57, 58, 59, 60:
		{
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 999.0);
		}
	}
}

// *********************
//		   主要
// *********************
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsInfectedBot(client))
	{
		if (!IsGhost(client))
		{
			int zombieclass = GetZombieClass(client);
			Action react = Plugin_Continue;
			if (zombieclass == ZC_TANK)
			{
				react = OnTankRunCmd(client, buttons, vel, angles);
			}
			else if (g_bAiEnable[client])
			{
				switch (zombieclass)
				{
					case ZC_SMOKER:
					{
						react = OnSmokerRunCmd(client, buttons, vel, angles);
					}
					case ZC_HUNTER:
					{
						react = OnHunterRunCmd(client, buttons, vel, angles);
					}
					case ZC_SPITTER:
					{
						react = OnSpitterRunCmd(client, buttons, vel, angles);
					}
					case ZC_JOCKEY:
					{
						react = OnJockeyRunCmd(client, buttons, vel, angles);
					}
					case ZC_CHARGER:
					{
						react = OnChargerRunCmd(client, buttons, vel, angles);
					}
				}
			}
			// 保存特感最近的一次攻击的时间戳
			if (buttons & IN_ATTACK)
			{
				UpdateSiAttackTime();
			}
			return react;
		}
	}
	return Plugin_Continue;
}

// *********************
//	   单一特感处理
// *********************
public Action OnSmokerRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	float tonguerange = -1.0;
	Action react = Plugin_Continue;
	if (tonguerange < 0.0)
	{
		tonguerange = GetConVarFloat(FindConVar("tongue_range"));
	}
	if (!(buttons & IN_ATTACK))
	{
		if (DelayExpired(client, 0, 0.5) && GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			DelayStart(client, 0);
			int target = GetClientAimTarget(client, true);
			if (target > 0 && IsValidSurvivor(target) && IsVisibleTo(client, target))
			{
				float targetpos[3] = 0.0, selfpos[3] = 0.0, dist = 0.0;
				GetClientAbsOrigin(client, selfpos);
				GetClientAbsOrigin(target, targetpos);
				dist = GetVectorDistance(selfpos, targetpos, false);
				if (dist < SMOKERMELEERANGE)
				{
					buttons |= IN_ATTACK | IN_ATTACK2;
					react = Plugin_Changed;
				}
				else if (dist < tonguerange)
				{
					if (GetGameTime() - GetSiAttackTime() < 5.0)
					{
						buttons |= IN_ATTACK;
						react = Plugin_Changed;
					}
					else
					{
						int aimtarget = GetClientAimTarget(target, true);
						if (aimtarget == client)
						{
							buttons |= IN_ATTACK;
							react = Plugin_Changed;
						}
					}
				}
			}
		}
	}
	return react;
}

public Action OnJockeyRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (GetMoveSpeed(client) > JOCKEYMINSPEED && (buttons & IN_FORWARD) && (GetEntityFlags(client) & FL_ONGROUND) && (GetEntityMoveType(client) != MOVETYPE_LADDER) 
	&& (NearestSurvivorDistance(client) < JOCKEYJUMPRANGE && DelayExpired(client, 0, JOCKEYJUMPNEARDELAY) || DelayExpired(client, 0, JOCKEYJUMPDELAY)))
	{
		vel[0] = VEM_MAX;
		if (GetState(client, 0) == IN_JUMP)
		{
			if (angles[2] == 0.0)
			{
				angles[0] = GetRandomFloat(-30.0, -10.0);
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			}
			buttons |= IN_ATTACK;
			SetState(client, 0, IN_ATTACK);
		}
		else
		{
			if (angles[2] == 0.0)
			{
				angles[0] = GetRandomFloat(-10.0, 0.0);
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			}
			buttons |= IN_JUMP;
			switch (GetRandomInt(0, 2))
			{
				case 0:
				{
					buttons |= IN_DUCK;
				}
				case 1:
				{
					buttons |= IN_ATTACK2;
				}
			}
			SetState(client, 0, IN_JUMP);
		}
		DelayStart(client, 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnChargerRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (!(buttons & IN_ATTACK) && GetEntityMoveType(client) != MOVETYPE_LADDER && (GetEntityFlags(client) & FL_ONGROUND) && DelayExpired(client, 0, CHARGERMELEEDELAY) && NearestSurvivorDistance(client) < CHARGERMELEERANGE)
	{
		DelayStart(client, 0);
		buttons |= IN_ATTACK2;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnHunterRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	Action react = Plugin_Continue;
	bool internaltrigger = false;
	if (!DelayExpired(client, 1, HUNTERATTACKTIME) && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		buttons |= IN_DUCK;
		if (!(GetRandomInt(0, HUNTERREPEATSPEED)))
		{
			buttons |= IN_ATTACK;
			internaltrigger = true;
		}
		react = Plugin_Changed;
	}
	if (!(GetEntityFlags(client) & FL_ONGROUND) && GetState(client, HUNTERFLYSTATE) == 0)
	{
		DelayStart(client, 2);
		SetState(client, HUNTERONGTOUNDSTATE, 0);
		SetState(client, HUNTERFLYSTATE, 1);
	}
	else if (!(GetEntityFlags(client) & FL_ONGROUND))
	{
		if (GetState(client, 0) == IN_FORWARD)
		{
			buttons |= IN_FORWARD;
			vel[0] = VEM_MAX;
			if (GetState(client, HUNTERONGTOUNDSTATE) == 0 && DelayExpired(client, 2, 0.2))
			{
				if (angles[2] == 0.0)
				{
					angles[0] = GetRandomFloat(-50.0, 20.0);
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				}
				SetState(client, HUNTERONGTOUNDSTATE, 1);
			}
			react = Plugin_Changed;
		}
		else if (!(GetState(client, 2) == 1))
		{
			SetState(client, HUNTERFLYSTATE, 0);
		}
	}
	if (DelayExpired(client, 0, 0.1) && (buttons & IN_ATTACK) && (GetEntityFlags(client) & FL_ONGROUND))
	{
		float dist = NearestSurvivorDistance(client);
		DelayStart(client, 0);
		if (!internaltrigger && !(buttons & IN_BACK) && dist < 1000.0 && DelayExpired(client, 1, HUNTERATTACKTIME + HUNTERCOOLDOWNTIME))
		{
			DelayStart(client, 1);
		}
		if (GetRandomInt(0, 1) == 0)
		{
			if (dist < 1000.0)
			{
				if (angles[2] == 0.0)
				{
					// 4 / 5 的概率向 10 - 30 度的 x 轴角度突袭，向右， 1 / 5 的概率向 -30 -10 度的 x 轴角度突袭，向左
					if (GetRandomInt(0, 4))
					{
						angles[0] = GetRandomFloat(10.0, 30.0);
					}
					else
					{
						angles[0] = GetRandomFloat(-30.0, -10.0);
					}
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				}
				SetState(client, 0, IN_FORWARD);
			}
			else
			{
				SetState(client, 0, 0);
			}
		}
		else
		{
			SetState(client, 0, 0);
		}
		react = Plugin_Changed;
	}
	return react;
}

public Action OnTankRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	bool bHasSight = view_as<bool>(GetEntProp(client, Prop_Send, "m_hasVisibleThreats"));
	if (GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		float tankattackrange = -1.0, tankspeed = -1.0;
		if (tankattackrange < 0.0)
		{
			tankattackrange = GetConVarFloat(FindConVar("tank_attack_range"));
		}
		if (tankspeed < 0.0)
		{
			tankspeed = GetConVarFloat(FindConVar("z_tank_speed"));
		}
		int flags = GetEntityFlags(client);
		if (flags == FL_JUMPING)
		{
			buttons &= ~IN_ATTACK2;
			return Plugin_Changed;
		}
		else if (buttons & IN_ATTACK2)
		{
			DelayStart(client, 3);
			DelayStart(client, 4);
			SetConVarString(FindConVar("z_tank_throw_force"), "1000");
		}
		// 按了左键之后 0.25s 并在 0.25 + 10s内，锁定视野
		if (DelayExpired(client, 4, TANKROCKAIMDELAY) && !DelayExpired(client, 3, TANKROCKAIMTIME))
		{
			Handle hTrace = INVALID_HANDLE;
			int targetclient = 0, hittimes = 0, survivorcount = 0;
			float selfpos[3] = {0.0}, targetpos[3] = {0.0}, aimangles[3] = {0.0};
			GetClientAbsOrigin(client, selfpos);
			selfpos[2] += TANKTHROWHEIGHT;
			// 2022-4-8更新：判断目标有效，判断目标是否可见
			for (int survivor = 1; survivor <= MaxClients; survivor++)
			{
				if (IsValidSurvivor(survivor))
				{
					survivorcount += 1;
				}
			}
			int firsttarget = GetNearestSurvivor(client);
			if (IsValidSurvivor(firsttarget))
			{
				GetClientAbsOrigin(firsttarget, targetpos);
				targetpos[2] += SURVIVORHEIGHT;
				hTrace = TR_TraceRayFilterEx(selfpos, targetpos, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, traceFilter, client);
				if (!TR_DidHit(hTrace))
				{
					targetclient = firsttarget;
					GetClientAbsOrigin(targetclient, targetpos);
					delete hTrace;
					hTrace = INVALID_HANDLE;
				}
				else
				{
					int entity = 0;
					char classname[64];
					entity = TR_GetEntityIndex(hTrace);
					GetEntityClassname(entity, classname, sizeof(classname));
					if (strcmp(classname, "player") != 0 && strcmp(classname, "env_physics_blocker") != 0 && strcmp(classname, "tank_rock") != 0)
					{
						hittimes += 1;
						for (int newtarget = 1; newtarget <= MaxClients; newtarget++)
						{
							if (IsValidSurvivor(newtarget))
							{
								GetClientAbsOrigin(newtarget, targetpos);
								// 射线，坦克 z 高度 +115，作为石头出手高度
								targetpos[2] += SURVIVORHEIGHT;
								hTrace = TR_TraceRayFilterEx(selfpos, targetpos, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, traceFilter, client);
								if (!TR_DidHit(hTrace))
								{
									// 射线未撞击到物体，则跳出，找到可以被攻击的生还者
									targetclient = newtarget;
									if (IsValidSurvivor(targetclient))
									{
										GetClientAbsOrigin(targetclient, targetpos);
										delete hTrace;
										hTrace = INVALID_HANDLE;
										break;
									}
								}
								else
								{
									entity = TR_GetEntityIndex(hTrace);
									GetEntityClassname(entity, classname, sizeof(classname));
									if (strcmp(classname, "player") != 0 && strcmp(classname, "env_physics_blocker") != 0 && strcmp(classname, "tank_rock") != 0)
									{
										hittimes += 1;
										delete hTrace;
										hTrace = INVALID_HANDLE;
									}
								}
							}
						}
					}
				}
				delete hTrace;
				hTrace = INVALID_HANDLE;
			}
			// 撞击次数和生还者数相等，所有生还者皆在障碍后，取最近目标
			if (hittimes == survivorcount)
			{
				PrintToConsoleAll("[Ai-Tank]：所有生还者均被遮挡");
				int nearesttarget = GetNearestSurvivor(client);
				ComputeAimAngles(client, nearesttarget, aimangles, AimEye);
				TeleportEntity(client, NULL_VECTOR, aimangles, NULL_VECTOR);
				return Plugin_Changed;
			}
			else
			{
				// 撞击次数与生还者数不相等，能直视某个生还，则计算角度
				float absdist[3] = {0.0};
				GetClientAbsOrigin(client, selfpos);
				if (IsValidSurvivor(targetclient))
				{
					ComputeAimAngles(client, targetclient, aimangles, AimEye);
					GetEntPropVector(targetclient, Prop_Send, "m_vecOrigin", absdist);
					int dist = RoundToNearest(GetVectorDistance(selfpos, absdist));
					float height = selfpos[2] - targetpos[2];
					// PrintToChatAll("目标pos：%.2f %.2f %.2f", targetpos[0], targetpos[1], targetpos[2]);
					// PrintToChatAll("dist：%d，height：%.2f, 余1000：%d", dist, height, dist / 1000);
					// 距离小于 300，则说明离生还较近，直接瞄准生还下部即可
					if (dist <= 300)
					{
						ComputeAimAngles(client, targetclient, aimangles, AimBody);
						aimangles[0] += 20.0;
					}
					else if ((dist / 1000) == 0)
					{
						aimangles[0] = 0.0;
						aimangles[0] -= (dist * 0.0060);
						// 高度相减小于 0，说明自身处于生还下方，高度相减大于 0，则在生还上方
						if (flags == FL_ONGROUND)
						{
							if (height < 0.0 && height < -100.0)
							{
								// PrintToChatAll("克的位置位于生还下方，且距离小于1000");
								aimangles[0] = 0.0;
								aimangles[0] -= 0.060 * FloatAbs(height);
							}
							else if (height > 0.0 && height > 100.0)
							{
								// PrintToChatAll("克的位置位于生还上方，且距离小于1000");
								aimangles[0] = 0.0;
								aimangles[0] += 0.050 * height;
							}
						}
					}
					else
					{
						float times = dist / 1000.0;
						aimangles[0] = 0.0;
						aimangles[0] -= ((dist * 0.0060) + (2.35 * times));
						if (flags == FL_ONGROUND)
						{
							if (height < 0.0 && height < -100.0)
							{
								// PrintToChatAll("克的位置位于生还下方，且距离大于1000");
								aimangles[0] = 0.0;
								aimangles[0] -= 0.070 * FloatAbs(height);
							}
							else if (height > 0.0 && height > 100.0)
							{
								// PrintToChatAll("克的位置位于生还上方，且距离大于1000");
								aimangles[0] = 0.0;
								aimangles[0] -= 0.020 * height;
							}
						}
					}
					// PrintToChatAll("计算得出的角度：%.2f %.2f %.2f", aimangles[0], aimangles[1], aimangles[2]);
					TeleportEntity(client, NULL_VECTOR, aimangles, NULL_VECTOR);
					return Plugin_Changed;
				}
				else
				{
					PrintToConsoleAll("[Ai-Tank]：投石对象不是有效生还者");
					return Plugin_Continue;
				}
			}
		}
		if (DelayExpired(client, 0, TANKMELEESCANDELAY))
		{
			DelayStart(client, 0);
			if (NearestSurvivorDistance(client) < tankattackrange * TANKATTACKRANGEFACTOR)
			{
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
		if (bHasSight && DelayExpired(client, 4, TANKROCKAIMDELAY) && DelayExpired(client, 3, TANKROCKAIMTIME))
		{
			float aimangles[3] = {0.0};
			int nearesttarget = GetNearestSurvivor(client);
			ComputeAimAngles(client, nearesttarget, aimangles, AimChest);
			TeleportEntity(client, NULL_VECTOR, aimangles, NULL_VECTOR);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action OnSpitterRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (GetMoveSpeed(client) > SPITTERRUNSPEED && DelayExpired(client, 0, SPITTERJUMPDELAY) && (GetEntityFlags(client) & FL_ONGROUND))
	{
		DelayStart(client, 0);
		buttons |= IN_JUMP;
		if (GetState(client, 0) == IN_MOVERIGHT)
		{
			SetState(client, 0, IN_MOVELEFT);
			buttons |= IN_MOVERIGHT;
			vel[1] = VEM_MAX;
		}
		else
		{
			SetState(client, 0, IN_MOVERIGHT);
			buttons |= IN_MOVELEFT;
			vel[1] = -VEM_MAX;
		}
		return Plugin_Changed;
	}
	if (buttons & IN_ATTACK)
	{
		if (DelayExpired(client, 1, SPITDELAY))
		{
			DelayStart(client, 1);
			buttons |= IN_JUMP;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

// *********************
//		   方法
// *********************
bool IsValidSurvivor(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsInfectedBot(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsGhost(int client)
{
	if (IsInfectedBot(client))
	{
		if (GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
}

int GetZombieClass(int client)
{
	return view_as<int>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

void InitStatus()
{
	float time = GetGameTime();
	for (int client = 1; client <= MaxClients; client++)
	{
		for (int index = 0; index < 8; index++)
		{
			g_fDelay[client][index] = time;
			g_iState[client][index] = 0;
		}
	}
}

void DelayStart(int client, int number)
{
	g_fDelay[client][number] = GetGameTime();
}

bool DelayExpired(int client, int number, float delay)
{
	return view_as<bool>(GetGameTime() - g_fDelay[client][number] > delay);
}

void SetState(int client, int number, int value)
{
	g_iState[client][number] = value;
}

int GetState(int client, int number)
{
	return view_as<int>(g_iState[client][number]);
}

// 保存当前一个特感开始攻击时的时间戳
void UpdateSiAttackTime()
{
	g_fSiAttackTime = GetGameTime();
}

float GetSiAttackTime()
{
	return view_as<float>(g_fSiAttackTime);
}

float GetMoveSpeed(int client)
{
	return view_as<float>(g_fMoveSpeed[client]);
}

bool IsVisibleTo(int client, int target)
{
	bool bCanSee = false;
	float selfpos[3], angles[3];
	GetClientEyePosition(client, selfpos);
	ComputeAimAngles(client, target, angles);
	Handle hTrace = TR_TraceRayFilterEx(selfpos, angles, MASK_SOLID, RayType_Infinite, TraceFilter, client);
	if (TR_DidHit(hTrace))
	{
		int hit = TR_GetEntityIndex(hTrace);
		if (hit == target)
		{
			bCanSee = true;
		}
	}
	delete hTrace;
	return bCanSee;
}

bool TraceFilter(int entity, int mask, int self)
{
	return entity != self;
}

bool IsIncapped(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

// 计算角度
void ComputeAimAngles(int client, int target, float angles[3], AimType type = AimEye)
{
	float selfpos[3], targetpos[3], lookat[3];
	GetClientEyePosition(client, selfpos);
	switch (type)
	{
		case AimEye:
		{
			GetClientEyePosition(target, targetpos);
		}
		case AimBody:
		{
			GetClientAbsOrigin(target, targetpos);
		}
		case AimChest:
		{
			GetClientAbsOrigin(target, targetpos);
			targetpos[2] += 45.0;
		}
	}
	MakeVectorFromPoints(selfpos, targetpos, lookat);
	GetVectorAngles(lookat, angles);
}

float NearestSurvivorDistance(int client)
{
	float selfpos[3] = 0.0, mindist = 100000.0;
	GetClientAbsOrigin(client, selfpos);
	for (int target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target) && IsValidSurvivor(target) && IsPlayerAlive(target) && !IsIncapped(target))
		{
			float targetpos[3] = 0.0;
			GetClientAbsOrigin(target, targetpos);
			float dist = GetVectorDistance(selfpos, targetpos, false);
			if (dist < mindist)
			{
				mindist = dist;
			}
		}
	}
	return mindist;
}

int GetNearestSurvivor(int client)
{
	int target = -1;
	float mindist = 100000.0, selfpos[3] = 0.0, targetpos[3] = 0.0;
	GetClientAbsOrigin(client, selfpos);
	for (int count = 1; count <= MaxClients; count++)
	{
		if (IsValidSurvivor(count) && IsPlayerAlive(count) && !IsIncapped(count) && !IsPinned(count))
		{
			float dist = 0.0;
			GetClientAbsOrigin(count, targetpos);
			dist = GetVectorDistance(selfpos, targetpos, false);
			if (dist < mindist)
			{
				mindist = dist;
				target = count;
			}
		}
	}
	return target;
}

bool IsPinned(int client)
{
	bool bIsPinned = false;
	if (IsValidSurvivor(client) && IsPlayerAlive(client))
	{
		if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true;
	}		
	return bIsPinned;
}

bool traceFilter(int entity, int mask, int self)
{
	return entity != self;
}