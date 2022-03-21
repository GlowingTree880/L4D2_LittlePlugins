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
	name 			= "Ai-Charger增强",
	author 			= "Breezy，High Cookie，Standalone，Newteee，cravenge，Harry，Sorallll，PaimonQwQ，夜羽真白",
	description 	= "觉得Ai-Charger不够强？ Try this！",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hChargerBhop, g_hChargerBhopSpeed, g_hChargerTarget, g_hStartChargeDistance, g_hChargerAimOffset, g_hHealthStartCharge, g_hChargerAirAngles;
// Ints
int g_iChargerTarget, g_iStartChargeDistance, g_iChargerAimOffset, g_iHealthStartCharge, g_iValidSurvivor = 0;
// Bools
bool g_bChargerBhop, g_bShouldCharge[MAXPLAYERS + 1];
// Floats
float g_fChargerBhopSpeed, g_fChargerAirAngles;

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_CHARGER 6
#define FL_JUMPING 65922

public void OnPluginStart()
{
	// CreateConVar
	g_hChargerBhop = CreateConVar("ai_ChargerBhop", "1", "是否开启Charger连跳", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hChargerBhopSpeed = CreateConVar("ai_ChargerBhopSpeed", "80.0", "Charger连跳的速度", FCVAR_NOTIFY, true, 0.0);
	g_hChargerTarget = CreateConVar("ai_ChargerTarget", "3", "Charger目标选择：1=自然目标选择，2=优先撞人多处，3=优先取最近目标", FCVAR_NOTIFY, true, 1.0, true, 2.0);
	g_hStartChargeDistance = CreateConVar("ai_ChargerStartChargeDistance", "300", "Charger只能在与目标小于这一距离时冲锋", FCVAR_NOTIFY, true, 0.0);
	g_hChargerAimOffset = CreateConVar("ai_ChargerAimOffset", "15", "目标的瞄准角度与Charger处于这一角度内，Charger将不会冲锋", FCVAR_NOTIFY, true, 0.0);
	g_hHealthStartCharge = CreateConVar("ai_ChargerStartChargeHealth", "350", "Charger的生命值低于这一个值才会冲锋", FCVAR_NOTIFY, true, 0.0);
	g_hChargerAirAngles = CreateConVar("ai_ChargerAirAngles", "60.0", "Charger在空中的速度向量与到生还者的方向向量夹角大于这个值停止连跳", FCVAR_NOTIFY, true, 0.0);
	// HookEvents
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("charger_charge_start", evt_ChargerChargeStart);
	// AddChangeHook
	g_hChargerBhop.AddChangeHook(ConVarChanged_Cvars);
	g_hChargerBhopSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_hChargerTarget.AddChangeHook(ConVarChanged_Cvars);
	g_hStartChargeDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hChargerAimOffset.AddChangeHook(ConVarChanged_Cvars);
	g_hHealthStartCharge.AddChangeHook(ConVarChanged_Cvars);
	g_hChargerAirAngles.AddChangeHook(ConVarChanged_Cvars);
	// GetCvars
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bChargerBhop = g_hChargerBhop.BoolValue;
	g_fChargerBhopSpeed = g_hChargerBhopSpeed.FloatValue;
	g_iChargerTarget = g_hChargerTarget.IntValue;
	g_iStartChargeDistance = g_hStartChargeDistance.IntValue;
	g_iChargerAimOffset = g_hChargerAimOffset.IntValue;
	g_iHealthStartCharge = g_hHealthStartCharge.IntValue;
	g_fChargerAirAngles = g_hChargerAirAngles.FloatValue;
}

public Action OnPlayerRunCmd(int charger, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsAiCharger(charger))
	{
		float fChargerPos[3], fTargetAngles[3];
		GetClientAbsOrigin(charger, fChargerPos);
		static float fLeftGroundMaxSpeed[MAXPLAYERS + 1];
		// 获取状态
		int iFlags = GetEntityFlags(charger);
		if (iFlags & FL_ONGROUND)
		{
		
		}
		else if (fLeftGroundMaxSpeed[charger] == -1.0)
		{
			fLeftGroundMaxSpeed[charger] = GetEntPropFloat(charger, Prop_Data, "m_flMaxspeed");
		}
		int iTarget = GetClientAimTarget(charger, true);
		float fDistance = NearestSurvivorDistance(charger);
		// 距离小于 150 且右键攻击到人，如果可以冲锋，则直接冲锋
		if ((buttons & IN_ATTACK2) && g_bShouldCharge[charger] && fDistance < 150.0 && ChargerCanCharge(charger))
		{
			vel[0] = vel[1] = 0.0;
			if (IsSurvivor(iTarget) && IsVisible(charger, iTarget) && !IsIncapped(iTarget) && !IsPinned(iTarget))
			{
				buttons |= IN_ATTACK;
				buttons |= IN_ATTACK2;
				return Plugin_Changed;
			}
		}
		float fSpeed[3], fCurrentSpeed;
		GetEntPropVector(charger, Prop_Data, "m_vecVelocity", fSpeed);
		fCurrentSpeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
		bool bHasSight = view_as<bool>(GetEntProp(charger, Prop_Send, "m_hasVisibleThreats"));
		if (buttons & IN_ATTACK)
		{
			vel[0] = vel[1] = vel[2] = 0.0;
		}
		else if (bHasSight && float(g_iStartChargeDistance) < fDistance < 1000.0 && fCurrentSpeed > 175.0)
		{
			if (IsSurvivor(iTarget))
			{
				if (bHasSight)
				{
					// 锁定视野
					ComputeAimAngles(charger, iTarget, fTargetAngles, AimChest);
					fTargetAngles[2] = 0.0;
					TeleportEntity(charger, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
				}
				// 其他操作
				float fBuffer[3], fTargetPos[3];
				GetClientAbsOrigin(iTarget, fTargetPos);
				fBuffer = UpdatePosition(charger, iTarget, g_fChargerBhopSpeed);
				if (g_bChargerBhop)
				{
					if (iFlags & FL_ONGROUND)
					{
						buttons |= IN_JUMP;
						buttons |= IN_DUCK;
						if ((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT))
						{
							ClientPush(charger, fBuffer);
						}
					}
					else if (iFlags == FL_JUMPING)
					{
						float fSelfPos[3], fTargetDistance, fAngles[3];
						GetClientAbsOrigin(charger, fSelfPos);
						fTargetDistance = GetVectorDistance(fTargetPos, fSelfPos);
						if (fTargetDistance < 100.0)
						{
							float fAnglesPost[3];
							GetVectorAngles(fSpeed, fAngles);
							fAnglesPost = fAngles;
							fAngles[0] = fAngles[2] = 0.0;
							GetAngleVectors(fAngles, fAngles, NULL_VECTOR, NULL_VECTOR);
							NormalizeVector(fAngles, fAngles);
							// 保存当前位置
							static float fDirection[2][3];
							fDirection[0] = fSelfPos;
							fDirection[1] = fTargetPos;
							fSelfPos[2] = fTargetPos[2] = 0.0;
							MakeVectorFromPoints(fSelfPos, fTargetPos, fSelfPos);
							NormalizeVector(fSelfPos, fSelfPos);
							// 计算距离
							if (RadToDeg(ArcCosine(GetVectorDotProduct(fAngles, fSelfPos))) < g_fChargerAirAngles)
							{
								return Plugin_Continue;
							}
							// 重新设置速度方向
							float fNewVelocity[3];
							MakeVectorFromPoints(fDirection[0], fDirection[1], fNewVelocity);
							TeleportEntity(charger, NULL_VECTOR, fAnglesPost, fNewVelocity);
						}
					}
				}
				if (GetEntityMoveType(charger) & MOVETYPE_LADDER)
				{
					buttons &= ~IN_JUMP;
					buttons &= ~IN_DUCK;
				}
			}
			else
			{
				int iNewTarget = GetClosestSurvivor(fChargerPos);
				ComputeAimAngles(charger, iNewTarget, fTargetAngles, AimChest);
				fTargetAngles[2] = 0.0;
				TeleportEntity(charger, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
			}
		}
		else if (float(g_iStartChargeDistance) - 10.0 < fDistance < float(g_iStartChargeDistance) + 100.0 && fCurrentSpeed > 260.0)
		{
			if (iFlags & FL_ONGROUND)
			{
				if (fLeftGroundMaxSpeed[charger] != -1.0)
				{
					float fCurVelVec[3];
					GetEntPropVector(charger, Prop_Data, "m_vecAbsVelocity", fCurVelVec);
					if (GetVectorLength(fCurVelVec) > fLeftGroundMaxSpeed[charger])
					{
						NormalizeVector(fCurVelVec, fCurVelVec);
						ScaleVector(fCurVelVec, fLeftGroundMaxSpeed[charger]);
						TeleportEntity(charger, NULL_VECTOR, NULL_VECTOR, fCurVelVec);
					}
					fLeftGroundMaxSpeed[charger] = -1.0;
				}
			}
		}
		if (IsSurvivor(iTarget))
		{
			int iSurvivorDistance = GetSurvivorDistance(fChargerPos, iTarget);
			int iChargerHealth = GetEntProp(charger, Prop_Send, "m_iHealth");
			if (iChargerHealth > g_iHealthStartCharge || iSurvivorDistance > g_iStartChargeDistance)
			{
				if (!g_bShouldCharge[charger] && ChargerCanCharge(charger))
				{
					BlockCharge(charger);
					buttons |= IN_ATTACK2;
					return Plugin_Changed;
				}
			}
			else
			{
				buttons |= IN_ATTACK2;
				g_bShouldCharge[charger] = true;
			}
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if (IsAiCharger(specialInfected))
	{
		float fSelfPos[3];
		GetClientAbsOrigin(specialInfected, fSelfPos);
		int iTeamMeleeCount = TeamMeleeCheck();
		switch (g_iChargerTarget)
		{
			case 2:
			{
				curTarget = GetCrowdPlace();
				return Plugin_Changed;
			}
			case 3:
			{
				if (curTarget > 0)
				{
					// 所有人都拿着近战，随机选取最近目标
					if (iTeamMeleeCount == g_iValidSurvivor)
					{
						curTarget = GetClosestSurvivor(fSelfPos);
						return Plugin_Changed;
					}
					else
					{
						if (NearestSurvivorDistance(specialInfected) > 0.50 * float(g_iStartChargeDistance))
						{
							if (ClientMeleeCheck(curTarget))
							{
								curTarget = GetClosestSurvivor(fSelfPos, curTarget);
								return Plugin_Changed;
							}
							else
							{
								curTarget = GetClosestSurvivor(fSelfPos);
								return Plugin_Changed;
							}
						}
						else
						{
							curTarget = GetClosestSurvivor(fSelfPos);
							return Plugin_Changed;
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

bool ClientMeleeCheck(int client)
{
	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(iActiveWeapon) && IsValidEdict(iActiveWeapon))
	{
		char sWeaponName[64];
		GetEdictClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
		if (strcmp(sWeaponName[7], "melee") == 0 || strcmp(sWeaponName, "weapon_chainsaw") == 0)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	// 不是有效的武器
	else
	{
		return false;
	}
}

int TeamMeleeCheck()
{
	int iTeamMeleeCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsSurvivor(client) && !IsIncapped(client) && IsPlayerAlive(client) && !IsPinned(client))
		{
			g_iValidSurvivor += 1;
			char sName[64];
			GetClientName(client, sName, sizeof(sName));
			int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(iActiveWeapon) && IsValidEdict(iActiveWeapon))
			{
				char sWeaponName[64];
				GetEdictClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
				if (strcmp(sWeaponName[7], "melee") == 0 || strcmp(sWeaponName, "weapon_chainsaw") == 0)
				{
					iTeamMeleeCount += 1;
				}
			}
		}
	}
	return iTeamMeleeCount;
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

bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
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

// ***** 事件 *****
public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiCharger(client))
	{
		g_bShouldCharge[client] = false;
	}
}

public void evt_ChargerChargeStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiCharger(client))
	{
		int iTarget = GetClientAimTarget(client, true);
		if (!IsSurvivor(iTarget) || IsIncapped(iTarget) || IsPinned(iTarget) || IsTargetWatchingAttacker(client, g_iChargerAimOffset))
		{
			int iNewTarget, iTargets[MAXPLAYERS + 1];
			float fNewDistance;
			static float vPos[3];
			static int iNumClients, i;
			iNumClients = 0;
			GetClientEyePosition(client, vPos);
			iNumClients = GetClientsInRange(vPos, RangeType_Visibility, iTargets, MAXPLAYERS);
			if (iNumClients != 0)
			{
				static ArrayList aTargets;
				aTargets = new ArrayList(2);
				static float vTarget[3], dist;
				static int index, victim;
				for (i = 0; i < iNumClients; i++)
				{
					victim = iTargets[i];
					if (victim && victim != iTarget && GetClientTeam(victim) == TEAM_SURVIVOR && IsPlayerAlive(victim) && !IsIncapped(victim) && !IsPinned(victim))
					{
						GetClientAbsOrigin(victim, vTarget);
						dist = GetVectorDistance(vPos, vTarget);
						index = aTargets.Push(dist);
						aTargets.Set(index, victim, 1);
					}
				}
				if (aTargets.Length != 0)
				{
					SortADTArray(aTargets, Sort_Ascending, Sort_Float);
					fNewDistance = aTargets.Get(0, 0);
					iNewTarget = aTargets.Get(0, 1);
				}
				delete aTargets;
			}
			if (iNewTarget && fNewDistance <= g_iStartChargeDistance)
			{
				iTarget = iNewTarget;
			}
			ChargerPridiction(client, iTarget);
		}
	}
}

void ChargerPridiction(int charger, int survivor)
{
	if (IsAiCharger(charger) && IsSurvivor(survivor))
	{
		float fSelfPos[3], fTargetPos[3], fAttackDirection[3], fAttackAngle[3];
		GetClientAbsOrigin(charger, fSelfPos);
		GetClientAbsOrigin(survivor, fTargetPos);
		MakeVectorFromPoints(fSelfPos, fTargetPos, fAttackDirection);
		GetVectorAngles(fAttackDirection, fAttackAngle);
		TeleportEntity(charger, NULL_VECTOR, fAttackAngle, NULL_VECTOR);
	}
}

// ***** 方法 *****
bool IsAiCharger(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_CHARGER && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
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

bool ChargerCanCharge(int client)
{
	if (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0)
	{
		return false;
	}
	static int iAbility;
	iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	return iAbility != -1 && !GetEntProp(iAbility, Prop_Send, "m_isCharging") && GetEntPropFloat(iAbility, Prop_Send, "m_timestamp") < GetGameTime();
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

bool IsVisible(int client, int target)
{
	bool bCanSee = false;
	float selfpos[3], angles[3];
	GetClientEyePosition(client, selfpos);
	ComputeAimAngles(client, target, angles);
	Handle hTrace = TR_TraceRayFilterEx(selfpos, angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
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

bool traceFilter(int entity, int mask, int self)
{
	return entity != self;
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

float UpdatePosition(int charger, int target, float fForce)
{
	float fBuffer[3], fChargerPos[3], fTargetPos[3];
	GetClientAbsOrigin(charger, fChargerPos);	GetClientAbsOrigin(target, fTargetPos);
	SubtractVectors(fTargetPos, fChargerPos, fBuffer);
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

int GetSurvivorDistance(const float refpos[3], int SpecificSur = -1)
{
	int TargetSur;
	float TargetSurPos[3], RefSurPos[3];
	RefSurPos[0] = refpos[0];	RefSurPos[1] = refpos[1];	RefSurPos[2] = refpos[2];
	if (SpecificSur > 0 && IsSurvivor(SpecificSur))
	{
		TargetSur = SpecificSur;
	}
	else
	{
		TargetSur = GetClosestSurvivor(RefSurPos);
	}
	GetEntPropVector(TargetSur, Prop_Send, "m_vecOrigin", TargetSurPos);
	return RoundToNearest(GetVectorDistance(RefSurPos, TargetSurPos));
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

void BlockCharge(int charger)
{
	int iChargeEntity = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if (iChargeEntity > 0)
	{
		SetEntPropFloat(iChargeEntity, Prop_Send, "m_timestamp", GetGameTime() + 0.1);
	}
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