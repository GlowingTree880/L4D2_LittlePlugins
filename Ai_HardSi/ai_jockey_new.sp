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
	version 		= "2022/5/2",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hBhopSpeed, g_hStartHopDistance, g_hJockeyStumbleRadius, g_hJockeyAirAngles, g_hStaggerTime;
// Ints
int g_iStartHopDistance, g_iState[MAXPLAYERS + 1][8], g_iJockeyStumbleRadius;
// Float
float g_fJockeyBhopSpeed, g_fJockeyAirAngles, g_fStaggerTime, g_fShovedTime[MAXPLAYERS + 1] = {0.0};
// Bools
bool g_bHasBeenShoved[MAXPLAYERS + 1], g_bCanLeap[MAXPLAYERS + 1];

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_JOCKEY 5
#define FL_JUMPING 65922

public void OnPluginStart()
{
	g_hBhopSpeed = CreateConVar("ai_JockeyBhopSpeed", "80.0", "Jockey连跳的速度", FCVAR_NOTIFY, true, 0.0);
	g_hStartHopDistance = CreateConVar("ai_JockeyStartHopDistance", "800", "Jockey距离生还者多少距离开始主动连跳", FCVAR_NOTIFY, true, 0.0);
	g_hJockeyStumbleRadius = CreateConVar("ai_JockeyStumbleRadius", "50", "Jockey骑到人后会对多少范围内的生还者产生硬直效果", FCVAR_NOTIFY, true, 0.0);
	g_hJockeyAirAngles = CreateConVar("ai_JockeyAirAngles", "60.0", "Jockey的速度方向与到目标的向量方向的距离大于这个角度，则停止连跳", FCVAR_NOTIFY, true, 0.0, true, 180.0);
	g_hStaggerTime = FindConVar("z_jockey_stagger_speed");
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
	g_hStaggerTime.AddChangeHook(ConVarChanged_Cvars);
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
	g_fStaggerTime = g_hStaggerTime.FloatValue;
}

public Action OnPlayerRunCmd(int jockey, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsAiJockey(jockey))
	{
		float fSpeed[3] = {0.0}, fCurrentSpeed, fJockeyPos[3] = {0.0};
		GetEntPropVector(jockey, Prop_Data, "m_vecVelocity", fSpeed);
		fCurrentSpeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
		GetClientAbsOrigin(jockey, fJockeyPos);
		// 获取jockey状态
		int iFlags = GetEntityFlags(jockey), iTarget = GetClientAimTarget(jockey, true);
		bool bHasSight = view_as<bool>(GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats"));
		if (IsSurvivor(iTarget) && IsPlayerAlive(iTarget) && bHasSight && !g_bHasBeenShoved[jockey])
		{
			// 其他操作
			float fBuffer[3] = {0.0}, fTargetPos[3] = {0.0}, fDistance = NearestSurvivorDistance(jockey);
			GetClientAbsOrigin(iTarget, fTargetPos);
			fBuffer = UpdatePosition(jockey, iTarget, g_fJockeyBhopSpeed);
			if (fCurrentSpeed > 130.0 && fDistance < float(g_iStartHopDistance))
			{
				if (iFlags & FL_ONGROUND)
				{
					if (fDistance < 250.0)
					{
						// 在地上的情况，首先 GetState 如果状态不是跳跃状态，则按跳跃键，设置为跳跃状态，如果在地上且是跳跃状态，且目标正在看着 jockey，则向上 50 度抬起视野再攻击，设置状态为攻击
						if (GetState(jockey, 0) == IN_JUMP)
						{
							bool bIsWatchingJockey = IsTargetWatchingAttacker(jockey, 20);
							if (angles[2] == 0.0 && bIsWatchingJockey)
							{
								angles = angles;
								angles[0] = GetRandomFloat(-50.0, -10.0);
								TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
							}
							buttons |= IN_ATTACK;
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
						SetState(jockey, 0, IN_JUMP);
						if ((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT))
						{
							ClientPush(jockey, fBuffer);
						}
					}
				}
				// 不在地上，禁止按下跳跃键和攻击键
				else
				{
					buttons &= ~IN_JUMP;
					buttons &= ~IN_ATTACK;
				}
				// 增加在空中被推的判断
				if (iFlags == FL_JUMPING && !g_bHasBeenShoved[jockey] && (GetGameTime() - g_fShovedTime[jockey]) > g_fStaggerTime)
				{
					buttons &= ~IN_JUMP;
					// 距离大于等于 150.0 才允许防止连跳过头，否则可能控不到人卡在空中
					if (GetVectorDistance(fJockeyPos, fTargetPos) >= 150.0)
					{
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
						NormalizeVector(fNewVelocity, fNewVelocity);
						ScaleVector(fNewVelocity, fCurrentSpeed);
						TeleportEntity(jockey, NULL_VECTOR, fAnglesPost, fNewVelocity);
					}
				}
			}
		}
		if (GetEntityMoveType(jockey) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
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
		g_fShovedTime[iShovedPlayer] = GetGameTime();
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
		g_fShovedTime[iSpawnPlayer] = 0.0;
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

float[] UpdatePosition(int jockey, int target, float fForce)
{
	float fBuffer[3] = {0.0}, fTankPos[3] = {0.0}, fTargetPos[3] = {0.0};
	GetClientAbsOrigin(jockey, fTankPos);
	GetClientAbsOrigin(target, fTargetPos);
	SubtractVectors(fTargetPos, fTankPos, fBuffer);
	NormalizeVector(fBuffer, fBuffer);
	ScaleVector(fBuffer, fForce);
	fBuffer[2] = 0.0;
	return fBuffer;
}

void ClientPush(int client, float fForwardVec[3])
{
	float fCurVelVec[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fCurVelVec);
	AddVectors(fCurVelVec, fForwardVec, fCurVelVec);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fCurVelVec);
}