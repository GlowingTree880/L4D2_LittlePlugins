#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo = 
{
	name 			= "Ai-Spitter增强",
	author 			= "Breezy，High Cookie，Standalone，Newteee，cravenge，Harry，Sorallll，PaimonQwQ，夜羽真白",
	description 	= "觉得Ai Spitter不够强？ Try this！",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hSpitterBhop, g_hSpitterBhopSpeed, g_hSpitterStartBhopDistance, g_hSpitterTarget, g_hInstantKill, g_hSpitterAirAngle;
// Ints
int g_iSpitterTarget;
// Floats
float g_fSpitterBhopSpeed, g_fSpitterStartBhopDistance, g_fSpitterAirAngle;
// Bools
bool g_bSpitterBhop, g_bInstantKill;

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_SPITTER 4
#define FL_JUMPING 65922

public void OnPluginStart()
{
	// CreateConVar
	g_hSpitterBhop = CreateConVar("ai_SpitterBhop", "1", "是否开启Spitter连跳", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSpitterBhopSpeed = CreateConVar("ai_SpitterBhopSpeed", "60.0", "Spitter连跳的速度", FCVAR_NOTIFY, true, 0.0);
	g_hSpitterStartBhopDistance = CreateConVar("ai_SpitterBhopStartBhopDistance", "2000.0", "Spitter在什么距离开始连跳", FCVAR_NOTIFY, true, 0.0);
	g_hSpitterTarget = CreateConVar("ai_SpitterTarget", "3", "Spitter的目标选择：1=默认目标选择，2=多人的地方优先，3=被扑，撞，拉者优先（无3则2）", FCVAR_NOTIFY, true, 1.0, true, 3.0);
	g_hInstantKill = CreateConVar("ai_SpitterInstantKill", "0", "Spitter吐完痰之后是否处死", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSpitterAirAngle = CreateConVar("ai_SpitterAirAngle", "60.0", "Spitter连跳时，其速度与到目标生还者向量方向超过这一角度，将会停止连跳", FCVAR_NOTIFY, true, 0.0);
	// AddChangeHook
	g_hSpitterBhop.AddChangeHook(ConVarChanged_Cvars);
	g_hSpitterBhopSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_hSpitterStartBhopDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hSpitterTarget.AddChangeHook(ConVarChanged_Cvars);
	g_hInstantKill.AddChangeHook(ConVarChanged_Cvars);
	g_hSpitterAirAngle.AddChangeHook(ConVarChanged_Cvars);
	// GetCvars
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bSpitterBhop = g_hSpitterBhop.BoolValue;
	g_fSpitterBhopSpeed = g_hSpitterBhopSpeed.FloatValue;
	g_fSpitterStartBhopDistance = g_hSpitterStartBhopDistance.FloatValue;
	g_iSpitterTarget = g_hSpitterTarget.IntValue;
	g_bInstantKill = g_hInstantKill.BoolValue;
	g_fSpitterAirAngle = g_hSpitterAirAngle.FloatValue;
}

public Action OnPlayerRunCmd(int spitter, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsAiSpitter(spitter))
	{
		// 跳着吐痰
		if (buttons & IN_ATTACK)
		{
			buttons |= IN_JUMP;
			if (g_bInstantKill)
			{
				// 延迟10秒处死，防止无声痰
				CreateTimer(10.0, Timer_ForceSuicide, spitter);
			}
			return Plugin_Changed;
		}
		float fSpeed[3], fCurrentSpeed, fAngles[3], fDistance;
		GetEntPropVector(spitter, Prop_Data, "m_vecVelocity", fSpeed);
		fCurrentSpeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
		fDistance = NearestSurvivorDistance(spitter);
		// 获取状态
		int iFlags = GetEntityFlags(spitter);
		if (fDistance < g_fSpitterStartBhopDistance && fCurrentSpeed > 150.0)
		{
			if (g_bSpitterBhop)
			{
				if (iFlags & FL_ONGROUND)
				{
					float fSpitterEyeAngles[3], fForwardVec[3];
					GetClientEyeAngles(spitter, fSpitterEyeAngles);
					GetAngleVectors(fSpitterEyeAngles, fForwardVec, NULL_VECTOR, NULL_VECTOR);
					NormalizeVector(fForwardVec, fForwardVec);
					ScaleVector(fForwardVec, g_fSpitterBhopSpeed);
					buttons |= IN_JUMP;
					buttons |= IN_DUCK;
					if ((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT))
					{
						ClientPush(spitter, fForwardVec);
					}
				}
				else if (iFlags == FL_JUMPING)
				{
					int iNearestTarget = NearestSurvivor(spitter);
					// 获取位置
					float fSpitterPos[3], fTargetPos[3];
					GetClientAbsOrigin(spitter, fSpitterPos);	
					if (iNearestTarget > 0)
					{
						GetClientAbsOrigin(iNearestTarget, fTargetPos);
						float fTargetDistance = GetVectorDistance(fTargetPos, fSpitterPos);
						if (fTargetDistance < 100.0)
						{
							// 防止跳过头
							float fAnglesPost[3];
							GetVectorAngles(fSpeed, fAngles);
							fAnglesPost = fAngles;
							fAngles[0] = fAngles[2] = 0.0;
							GetAngleVectors(fAngles, fAngles, NULL_VECTOR, NULL_VECTOR);
							NormalizeVector(fAngles, fAngles);
							// 保存当前位置
							static float fDirection[2][3];
							fDirection[0] = fSpitterPos;
							fDirection[1] = fTargetPos;
							fSpitterPos[2] = fTargetPos[2] = 0.0;
							MakeVectorFromPoints(fSpitterPos, fTargetPos, fSpitterPos);
							NormalizeVector(fSpitterPos, fSpitterPos);
							// 计算角度
							if (RadToDeg(ArcCosine(GetVectorDotProduct(fAngles, fSpitterPos))) > g_fSpitterAirAngle)
							{
								// 重新设置速度方向
								float fNewVelocity[3];
								MakeVectorFromPoints(fDirection[0], fDirection[1], fNewVelocity);
								TeleportEntity(spitter, NULL_VECTOR, fAnglesPost, fNewVelocity);
							}
						}
					}
				}
			}
			if (GetEntityMoveType(spitter) & MOVETYPE_LADDER)
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_ForceSuicide(Handle timer, int client)
{
	ForcePlayerSuicide(client);
}

// 目标选择
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if (IsAiSpitter(specialInfected))
	{
		switch (g_iSpitterTarget)
		{
			case 2:
			{
				int iTarget = GetCrowdPlace();
				if (iTarget > 0)
				{
					curTarget = iTarget;
				}
			}
			case 3:
			{
				// 检测是否有生还被撞，扑，拉
				for (int client = 1; client <= MaxClients; client++)
				{
					if (IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR)
					{
						if (GetEntProp(client, Prop_Send, "m_pummelAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
						{
							curTarget = client;
							return Plugin_Changed;
						}
						else
						{
							int iTarget = GetCrowdPlace();
							if (iTarget > 0)
							{
								curTarget = iTarget;
								return Plugin_Changed;
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

// ***** 方法 *****
bool IsAiSpitter(int client)
{
	if(IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_SPITTER && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsValidClient(int client)
{
	if (client && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		return true;
	}
	else
	{
		return false;
	}
}

int GetSurvivorCount()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			iCount++;
		}
	}
	return iCount;
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

// From：http://github.com/PaimonQwQ/L4D2-Plugins/smartspitter.sp
int GetCrowdPlace()
{
	int iCount = GetSurvivorCount();
	if (iCount > 0)
	{
		int index = 0, iTarget = 0;
		int[] iSurvivors = new int[iCount];
		float fDistance[MAXPLAYERS + 1] = -1.0;
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && GetClientTeam(client) == TEAM_SURVIVOR)
			{
				iSurvivors[index++] = client;
			}
		}
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_SURVIVOR)
			{
				fDistance[client] = 0.0;
				float fClientPos[3] = 0.0;
				GetClientAbsOrigin(client, fClientPos);
				for (int i = 0; i < iCount; i++)
				{
					float fPos[3] = 0.0;
					GetClientAbsOrigin(iSurvivors[i], fPos);
					fDistance[client] += GetVectorDistance(fClientPos, fPos, true);
				}
			}
		}
		for (int i = 0; i < iCount; i++)
		{
			if (fDistance[iSurvivors[iTarget]] > fDistance[iSurvivors[i]])
			{
				if (fDistance[iSurvivors[i]] != -1.0)
				{
					iTarget = i;
				}
			}
		}
		return iSurvivors[iTarget];
	}
	else
	{
		return -1;
	}
}

float NearestSurvivorDistance(int client)
{
	static int i, iCount;
	static float vPos[3], vTargetPos[3], fDistance[MAXPLAYERS + 1];
	iCount = 0;
	GetClientAbsOrigin(client, vPos);
	for (i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, vTargetPos);
			fDistance[iCount++] = GetVectorDistance(vPos, vTargetPos);
		}
	}
	if (iCount == 0)
	{
		return -1.0;
	}
	SortFloats(fDistance, iCount, Sort_Ascending);
	return fDistance[0];
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