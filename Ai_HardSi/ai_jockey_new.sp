#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

enum AimType
{
	AimEye,
	AimBody,
	AimChest
};

public Plugin myinfo = 
{
	name 			= "Ai_Jockey增强",
	author 			= "Breezy，High Cookie，Standalone，Newteee，cravenge，Harry，Sorallll，PaimonQwQ，夜羽真白",
	description 	= "觉得Ai猴子太弱了？ Try this！",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hBhopSpeed, g_hStartHopDistance, g_hJockeyStumbleRadius, g_hJockeyAirAngles;
// Ints
int g_iStartHopDistance, g_iState[MAXPLAYERS + 1][8], g_iJockeyStumbleRadius;
// Float
float g_fJockeyBhopSpeed, g_fJockeyAirAngles;
// Bools
bool g_bHasBeenShoved[MAXPLAYERS + 1], g_bCanLeap[MAXPLAYERS + 1], g_bDoNormalJump[MAXPLAYERS + 1];

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_JOCKEY 5
#define FL_JUMPING 65922

public void OnPluginStart()
{
	g_hBhopSpeed = CreateConVar("ai_JockeyBhopSpeed", "80.0", "Jockey连跳的速度", FCVAR_NOTIFY, true, 0.0);
	g_hStartHopDistance = CreateConVar("ai_JockeyStartHopDistance", "800", "Jockey距离生还者多少距离开始主动连跳", FCVAR_NOTIFY, true, 0.0);
	g_hJockeyStumbleRadius = CreateConVar("ai_JockeyStumbleRadius", "50", "Jockey骑到人后会对多少范围内的生还者产生硬直效果", FCVAR_NOTIFY, true, 0.0);
	g_hJockeyAirAngles = CreateConVar("ai_JockeyAirAngles", "60.0", "Jockey的速度方向与到目标的向量方向的距离大于这个角度，则停止连跳", FCVAR_NOTIFY, true, 0.0);
	// HookEvent
	HookEvent("player_spawn", evt_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_shoved", evt_PlayerShoved, EventHookMode_Pre);
	HookEvent("player_jump", evt_PlayerJump, EventHookMode_Pre);
	HookEvent("jockey_ride", evt_JockeyRide);
	// AddChangeHook
	g_hBhopSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_hStartHopDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hJockeyStumbleRadius.AddChangeHook(ConVarChanged_Cvars);
	g_hJockeyAirAngles.AddChangeHook(ConVarChanged_Cvars);
	// GetCvars
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fJockeyBhopSpeed = g_hBhopSpeed.FloatValue;
	g_iStartHopDistance = g_hStartHopDistance.IntValue;
	g_iJockeyStumbleRadius = g_hJockeyStumbleRadius.IntValue;
	g_fJockeyAirAngles = g_hJockeyAirAngles.FloatValue;
}

public Action OnPlayerRunCmd(int jockey, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsAiJockey(jockey))
	{
		static float fLeftGroundMaxSpeed[MAXPLAYERS + 1];
		float fSpeed[3], fCurrentSpeed, fJockeyPos[3], fTargetAngles[3];
		GetEntPropVector(jockey, Prop_Data, "m_vecVelocity", fSpeed);
		fCurrentSpeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
		GetClientAbsOrigin(jockey, fJockeyPos);
		// 获取jockey状态
		int iFlags = GetEntityFlags(jockey);
		// 获取jockey与目标之间的向量
		int iTarget = GetClientAimTarget(jockey, true);
		if (iTarget > 0)
		{
			// 锁定视野
			ComputeAimAngles(jockey, iTarget, fTargetAngles, AimChest);
			fTargetAngles[2] = 0.0;
			TeleportEntity(jockey, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
			// 其他操作
			float fBuffer[3], fTargetPos[3];
			GetClientAbsOrigin(iTarget, fTargetPos);
			fBuffer = UpdatePosition(jockey, iTarget, g_fJockeyBhopSpeed);
			if ((iFlags & FL_ONGROUND) && g_bHasBeenShoved[jockey])
			{
				if (g_bDoNormalJump[jockey])
				{
					if (buttons & IN_FORWARD)
					{
						angles[0] = GetRandomFloat(-10.0, 0.0);
						TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
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
					g_bDoNormalJump[jockey] = false;
				}
			}
			else if (fLeftGroundMaxSpeed[jockey] == -1.0)
			{
				fLeftGroundMaxSpeed[jockey] = GetEntPropFloat(jockey, Prop_Data, "m_flMaxspeed");
			}
			if (GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats") == 0 || g_bHasBeenShoved[jockey])
			{
				return Plugin_Continue;
			}
			float fDistance = NearestSurvivorDistance(jockey);
			if (fCurrentSpeed > 130.0)
			{
				// 距离目标距离小于给定距离
				if (fDistance < float(g_iStartHopDistance))
				{
					if (iFlags & FL_ONGROUND)
					{
						if (fDistance < 250.0)
						{
							if (fLeftGroundMaxSpeed[jockey] != -1.0 && fCurrentSpeed > 250.0)
							{
								float fCurrentSpeedVector[3];
								GetEntPropVector(jockey, Prop_Data, "m_vecAbsVelocity", fCurrentSpeedVector);
								if (GetVectorLength(fCurrentSpeedVector) > fLeftGroundMaxSpeed[jockey])
								{
									NormalizeVector(fCurrentSpeedVector, fCurrentSpeedVector);
									ScaleVector(fCurrentSpeedVector, fLeftGroundMaxSpeed[jockey]);
									TeleportEntity(jockey, NULL_VECTOR, NULL_VECTOR, fCurrentSpeedVector);
								}
								fLeftGroundMaxSpeed[jockey] = -1.0;
							}
							if (GetState(jockey, 0) == IN_JUMP)
							{
								bool bIsWatchingJockey = IsTargetWatchingAttacker(jockey, 20);
								// 如果在地上且目标正在看着jockey
								if (angles[2] == 0.0 && bIsWatchingJockey)
								{
									angles = angles;
									angles[0] = GetRandomFloat(-50.0, -10.0);
									TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
								}
								buttons |= IN_ATTACK;
								buttons |= IN_ATTACK2;
								SetState(jockey, 0, IN_ATTACK);
							}
							else
							{
								if(angles[2] == 0.0) 
								{
									angles[0] = GetRandomFloat(-10.0, 0.0);
									TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
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
								SetState(jockey, 0, IN_JUMP);
							}
						}
						else
						{
							buttons |= IN_JUMP;
							buttons |= IN_ATTACK2;
							SetState(jockey, 0, IN_JUMP);
							if ((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT))
							{
								ClientPush(jockey, fBuffer);
							}
						}
					}
					if (GetEntityMoveType(jockey) & MOVETYPE_LADDER)
					{
						buttons &= ~IN_JUMP;
						buttons &= ~IN_DUCK;
					}
				}
			}
		}
		else
		{
			// 选择最近目标
			int iNewTarget = GetClosestSurvivor(fJockeyPos);
			if (iNewTarget > 0)
			{
				// 锁定视野
				ComputeAimAngles(jockey, iNewTarget, fTargetAngles, AimChest);
				fTargetAngles[2] = 0.0;
				TeleportEntity(jockey, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
				// 无目标的情况，do normal jump
				float fJockeyEyeAngle[3], fForwardVec[3];
				GetClientEyeAngles(jockey, fJockeyEyeAngle);
				GetAngleVectors(fJockeyEyeAngle, fForwardVec, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(fForwardVec, fForwardVec);
				ScaleVector(fForwardVec, g_fJockeyBhopSpeed);
				if (iFlags & FL_ONGROUND && !g_bHasBeenShoved[jockey])
				{
					if (g_bDoNormalJump[jockey])
					{
						buttons |= IN_JUMP;
						SetState(jockey, 0, IN_JUMP);
						g_bDoNormalJump[jockey] = false;
						if ((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT))
						{
							ClientPush(jockey, fForwardVec);
						}
					}
					else
					{
						if (g_bCanLeap[jockey])
						{
							buttons |= IN_ATTACK;
							g_bCanLeap[jockey] = false;
							float fLeapCooldown = float(GetConVarInt(FindConVar("z_jockey_leap_again_timer")));
							CreateTimer(fLeapCooldown, Timer_LeapCoolDown, jockey, TIMER_FLAG_NO_MAPCHANGE);
							g_bDoNormalJump[jockey] = true;
						}
					}
				}
			}
			else if (iFlags == FL_JUMPING)
			{
				int NewTarget = NearestSurvivor(jockey);	float fTargetPos[3];
				if (NewTarget > 0)
				{
					GetClientAbsOrigin(NewTarget, fTargetPos);
					if (GetVectorDistance(fJockeyPos, fTargetPos) < 100.0)
					{
						// 防止连跳过头
						float fAnglesPost[3], fAngles[3];
						GetVectorDistance(fSpeed, fAngles);
						fAnglesPost = fAngles;
						fAngles[0] = fAngles[2] = 0.0;
						GetAngleVectors(fAngles, fAngles, NULL_VECTOR, NULL_VECTOR);
						NormalizeVector(fAngles, fAngles);
						// 保存当前位置
						static float fDirection[2][3];
						fDirection[0] = fJockeyPos;
						fDirection[1] = fTargetPos;
						fJockeyPos[2] = fTargetPos[2] = 0.0;
						MakeVectorFromPoints(fJockeyPos, fTargetPos, fJockeyPos);
						NormalizeVector(fJockeyPos, fJockeyPos);
						// 计算距离
						if (RadToDeg(ArcCosine(GetVectorDotProduct(fAngles, fJockeyPos))) < g_fJockeyAirAngles)
						{
							return Plugin_Continue;
						}
						// 重新设置速度方向
						float fNewVelocity[3];
						MakeVectorFromPoints(fDirection[0], fDirection[1], fNewVelocity);
						TeleportEntity(jockey, NULL_VECTOR, fAnglesPost, fNewVelocity);
					}
				}
			}
			else
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_ATTACK;
			}
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action evt_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int iShovedPlayer = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiJockey(iShovedPlayer))
	{
		g_bHasBeenShoved[iShovedPlayer] = true;
		g_bCanLeap[iShovedPlayer] = false;
		int fLeapCooldown = GetConVarInt(FindConVar("z_jockey_leap_again_timer"));
		CreateTimer(float(fLeapCooldown), Timer_LeapCoolDown, iShovedPlayer, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public void evt_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int iJumpingPlayer = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiJockey(iJumpingPlayer))
	{
		g_bHasBeenShoved[iJumpingPlayer] = false;
	}
}

public Action evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iSpawnPlayer = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiJockey(iSpawnPlayer))
	{
		g_bHasBeenShoved[iSpawnPlayer] = false;
		g_bCanLeap[iSpawnPlayer] = true;
	}
	return Plugin_Handled;
}

public Action Timer_LeapCoolDown(Handle timer, int jockey)
{
	g_bCanLeap[jockey] = true;
}

public void evt_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	if (IsCoop)
	{
		int attacker = GetClientOfUserId(event.GetInt("userid"));
		int victim = GetClientOfUserId(event.GetInt("victim"));
		if (attacker > 0 && victim > 0)
		{
			StumbleByStanders(victim, attacker);
		}
	}
}

bool IsCoop()
{
	static char sGameMode[16];
	sGameMode[0] = 0;
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));
	return strcmp(sGameMode, "versus", false) != 0 && strcmp(sGameMode, "scavenge", false) != 0;
}

void StumbleByStanders(int pinnedSurvivor, int pinner) 
{
	static float pinnedSurvivorPos[3], pos[3], dir[3];
	GetClientAbsOrigin(pinnedSurvivor, pinnedSurvivorPos);
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			if(i != pinnedSurvivor && i != pinner && !IsPinned(i)) 
			{
				GetClientAbsOrigin(i, pos);
				SubtractVectors(pos, pinnedSurvivorPos, dir);
				if(GetVectorLength(dir) <= g_iJockeyStumbleRadius) 
				{
					NormalizeVector(dir, dir); 
					L4D_StaggerPlayer(i, pinnedSurvivor, dir);
				}
			}
		} 
	}
}

bool IsPinned(int client)
{
	bool bIsPinned = false;
	if (IsSurvivor(client))
	{
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true;
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true;
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true;
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true;
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true;
	}		
	return bIsPinned;
}

// ***** 方法 *****
bool IsAiJockey(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_JOCKEY && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsSurvivor(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsIncapped(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

float NearestSurvivorDistance(int client)
{
	static int i, iCount;
	static float vPos[3], vTarget[3], fDistance[MAXPLAYERS + 1];
	iCount = 0;
	GetClientAbsOrigin(client, vPos);
	for (i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i) && !IsIncapped(i))
		{
			GetClientAbsOrigin(i, vTarget);
			fDistance[iCount++] = GetVectorDistance(vPos, vTarget);
		}
	}
	if (iCount == 0)
	{
		return -1.0;
	}
	SortFloats(fDistance, iCount, Sort_Ascending);
	return fDistance[0];
}

int NearestSurvivor(int attacker)
{
	int iTarget = -1;
	float minDistance = 100000.0, selfPos[3], targetPos[3];
	GetClientAbsOrigin(attacker, selfPos);
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsSurvivor(client) && IsPlayerAlive(client) && !IsIncapped(client))
		{
			GetClientAbsOrigin(client, targetPos);
			float fDistance = GetVectorDistance(selfPos, targetPos);
			if (fDistance < minDistance)
			{
				minDistance = fDistance;
				iTarget = client;
			}
		}
	}
	return iTarget;
}

bool IsTargetWatchingAttacker(int attacker, int offset)
{
	bool bIsWatching = true;
	if (GetClientTeam(attacker) == TEAM_INFECTED && IsPlayerAlive(attacker))
	{
		int iTarget = GetClientAimTarget(attacker);
		if (IsSurvivor(iTarget))
		{
			int iOffset = RoundToNearest(GetPlayerAimOffset(iTarget, attacker));
			if (iOffset <= offset)
			{
				bIsWatching = true;
			}
			else
			{
				bIsWatching = false;
			}
		}
	}
	return bIsWatching;
}

float GetPlayerAimOffset(int attacker, int target)
{
	if (IsClientConnected(attacker) && IsClientInGame(attacker) && IsPlayerAlive(attacker) && IsClientConnected(target) && IsClientInGame(target) && IsPlayerAlive(target))
	{
		float fAttackerPos[3], fTargetPos[3], fAimVector[3], fDirectVector[3], fResultAngle;
		GetClientEyeAngles(attacker, fAimVector);
		fAimVector[0] = fAimVector[2] = 0.0;
		GetAngleVectors(fAimVector, fAimVector, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(fAimVector, fAimVector);
		// 获取目标位置
		GetClientAbsOrigin(target, fTargetPos);
		GetClientAbsOrigin(attacker, fAttackerPos);
		fAttackerPos[2] = fTargetPos[2] = 0.0;
		MakeVectorFromPoints(fAttackerPos, fTargetPos, fDirectVector);
		NormalizeVector(fDirectVector, fDirectVector);
		// 计算角度
		fResultAngle = RadToDeg(ArcCosine(GetVectorDotProduct(fAimVector, fDirectVector)));
		return fResultAngle;
	}
	return -1.0;
}

void SetState(int client, int no, int value)
{
	g_iState[client][no] = value;
}

int GetState(int client, int no)
{
	return g_iState[client][no];
}

float UpdatePosition(int jockey, int target, float fForce)
{
	float fBuffer[3], fTankPos[3], fTargetPos[3];
	GetClientAbsOrigin(jockey, fTankPos);	GetClientAbsOrigin(target, fTargetPos);
	SubtractVectors(fTargetPos, fTankPos, fBuffer);
	NormalizeVector(fBuffer, fBuffer);
	ScaleVector(fBuffer, fForce);
	return fBuffer;
}

void ClientPush(int client, float fForwardVec[3])
{
	float fCurVelVec[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fCurVelVec);
	for (int i = 0; i < 3; i++)
	{
		fCurVelVec[i] += fForwardVec[i];
	}
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fCurVelVec);
}

int GetClosestSurvivor(float refpos[3], int excludeSur = -1)
{
	float surPos[3];	int closetSur = GetRandomSurvivor();
	if (closetSur == 0)
	{
		return 0;
	}
	GetClientAbsOrigin(closetSur, surPos);
	int iClosetAbsDisplacement = RoundToNearest(GetVectorDistance(refpos, surPos));
	for (int client = 1; client < MaxClients; client++)
	{
		if (IsSurvivor(client) && IsPlayerAlive(client) && client != excludeSur)
		{
			GetClientAbsOrigin(client, surPos);
			int iAbsDisplacement = RoundToNearest(GetVectorDistance(refpos, surPos));
			if (iClosetAbsDisplacement < 0)
			{
				iClosetAbsDisplacement = iAbsDisplacement;
				closetSur = client;
			}
			else if (iAbsDisplacement < iClosetAbsDisplacement)
			{
				iClosetAbsDisplacement = iAbsDisplacement;
				closetSur = client;
			}
		}
	}
	return closetSur;
}

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