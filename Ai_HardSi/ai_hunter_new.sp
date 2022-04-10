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
	name 			= "Ai-Hunter增强",
	author 			= "Breezy，High Cookie，Standalone，Newteee，cravenge，Harry，Sorallll，PaimonQwQ，夜羽真白",
	description 	= "觉得Ai-Hunter不够强？ Try this！",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hHunterFastPounceDistance, g_hPounceVerticalAngle, g_hPounceAngleMean, g_hPounceAngleStd, g_hStraightPounceDistance, g_hHunterAimOffset, g_hWallPounceDistance, g_hHunterTarget, g_hShotGunCheckRange;
// Ints
int g_iPounceVerticalAngle, g_iPounceAngleMean, g_iPounceAngleStd, g_iHunterAimOffset, g_iHunterTarget, g_iShotgunPlayer = -1, g_iMobileSurvivor = 0;
// Floats
float g_fHunterFastPounceDistance, g_fStraightPounceDistance, g_fWallPounceDistance, g_fShotGunCheckRange;
// Bools
bool g_bHasQueuedLunge[MAXPLAYERS + 1], g_bCanLunge[MAXPLAYERS + 1];

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZC_HUNTER 3
#define POSITIVE 0
#define NEGETIVE 1
#define X 0
#define Y 1
#define Z 2

public void OnPluginStart()
{
	// CreateConVar
	g_hHunterFastPounceDistance = CreateConVar("ai_HunterFastPounceDistance", "2000", "在距离目标多近Hunter开始快速突袭", FCVAR_NOTIFY, true, 0.0);
	g_hPounceVerticalAngle = CreateConVar("ai_HunterPounceVerticalAngle", "6", "Hunter突袭的垂直角度限制", FCVAR_NOTIFY, true, 0.0);
	g_hPounceAngleMean = CreateConVar("ai_HunterPounceAngleMean", "10", "Hunter突袭的平均角度（由随机数发生器产生）", FCVAR_NOTIFY, true, 0.0);
	g_hPounceAngleStd = CreateConVar("ai_HunterPounceAngleStd", "20", "Hunter突袭角度与平均角度的偏差（由随机数发生器产生）", FCVAR_NOTIFY, true, 0.0);
	g_hStraightPounceDistance = CreateConVar("ai_HunterStraightPounceDistance", "200.0", "Hunter在离生还者多近时允许直扑", FCVAR_NOTIFY, true, 0.0);
	g_hHunterAimOffset = CreateConVar("ai_HunterAimOffset", "360", "目标与Hunter处在这一角度范围内，Hunter将不会直扑", FCVAR_NOTIFY, true, 0.0);
	g_hWallPounceDistance = CreateConVar("ai_HunterWallDetectDistance", "-1", "在这个范围内，Hunter突袭时将会优先检测是否有墙体", FCVAR_NOTIFY);
	g_hHunterTarget = CreateConVar("ai_HunterTarget", "2", "Hunter目标选择：1=自然目标选择，2=最近目标，3=手持非霰弹枪的生还者", FCVAR_NOTIFY, true, 1.0, true, 2.0);
	g_hShotGunCheckRange = CreateConVar("ai_HunterShotGunCheckRange", "150.0", "目标选择为3时，Hunter在大于这个距离时允许进行目标枪械检测", FCVAR_NOTIFY, true, 0.0);
	// HookEvents
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("ability_use", evt_AbilityUse);
	// AddChangeHook
	g_hHunterFastPounceDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hPounceVerticalAngle.AddChangeHook(ConVarChanged_Cvars);
	g_hPounceAngleMean.AddChangeHook(ConVarChanged_Cvars);
	g_hPounceAngleStd.AddChangeHook(ConVarChanged_Cvars);
	g_hStraightPounceDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hHunterAimOffset.AddChangeHook(ConVarChanged_Cvars);
	g_hWallPounceDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hHunterTarget.AddChangeHook(ConVarChanged_Cvars);
	g_hShotGunCheckRange.AddChangeHook(ConVarChanged_Cvars);
	// GetCvars
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fHunterFastPounceDistance = g_hHunterFastPounceDistance.FloatValue;
	g_iPounceVerticalAngle = g_hPounceVerticalAngle.IntValue;
	g_iPounceAngleMean = g_hPounceAngleMean.IntValue;
	g_iPounceAngleStd = g_hPounceAngleStd.IntValue;
	g_fStraightPounceDistance = g_hStraightPounceDistance.FloatValue;
	g_iHunterAimOffset = g_hHunterAimOffset.IntValue;
	g_fWallPounceDistance = g_hWallPounceDistance.FloatValue;
	g_iHunterTarget = g_hHunterTarget.IntValue;
	g_fShotGunCheckRange = g_hShotGunCheckRange.FloatValue;
}

public Action OnPlayerRunCmd(int hunter, int& buttons, int& impulse, float vel[3], float eyeAngles[3], int& weapon)
{
	if (IsAiHunter(hunter))
	{
		buttons &= ~IN_ATTACK2;
		int iFlags = GetEntityFlags(hunter);
		float fDistance = NearestSurvivorDistance(hunter);
		float fHunterPos[3], fTargetAngles[3];
		GetClientAbsOrigin(hunter, fHunterPos);
		int iTarget = GetClientAimTarget(hunter, true);
		bool bHasSight = view_as<bool>(GetEntProp(hunter, Prop_Send, "m_hasVisibleThreats"));
		if (iTarget > 0)
		{
			if (bHasSight)
			{
				ComputeAimAngles(hunter, iTarget, fTargetAngles, AimChest);
				fTargetAngles[2] = 0.0;
				TeleportEntity(hunter, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
			}
		}
		else
		{
			if (bHasSight)
			{
				int iNewTarget = GetClosestSurvivor(fHunterPos);
				ComputeAimAngles(hunter, iNewTarget, fTargetAngles, AimChest);
				fTargetAngles[2] = 0.0;
				TeleportEntity(hunter, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
			}
		}
		if ((iFlags & FL_DUCKING) && (iFlags & FL_ONGROUND))
		{
			if (bHasSight)
			{
				if (fDistance < g_fHunterFastPounceDistance)
				{
					buttons &= ~IN_ATTACK;
					if (!g_bHasQueuedLunge[hunter])
					{
						g_bCanLunge[hunter] = false;
						g_bHasQueuedLunge[hunter] = true;
						CreateTimer(GetConVarFloat(FindConVar("z_lunge_interval")), Timer_LungeInterval, hunter, TIMER_FLAG_NO_MAPCHANGE);
					}
					else if (g_bCanLunge[hunter])
					{
						buttons |= IN_ATTACK;
						g_bHasQueuedLunge[hunter] = false;
					}
				}
			}
		}
		if (GetEntityMoveType(hunter) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	return Plugin_Changed;
}

public Action Timer_LungeInterval(Handle timer, int client)
{
	g_bCanLunge[client] = true;
}

public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if (IsAiHunter(specialInfected))
	{
		float fSelfPos[3];
		GetClientAbsOrigin(specialInfected, fSelfPos);
		if (curTarget > 0)
		{
			float fTargetPos[3], fDistance;
			GetClientAbsOrigin(curTarget, fTargetPos);
			fDistance = GetVectorDistance(fSelfPos, fTargetPos);
			if (IsPinned(curTarget) || IsIncapped(curTarget))
			{
				curTarget = GetClosestSurvivor(fSelfPos, curTarget);
				return Plugin_Changed;
			}
			switch (g_iHunterTarget)
			{
				case 2:
				{
					curTarget = GetClosestSurvivor(fSelfPos);
				}
				case 3:
				{
					if (fDistance > g_fShotGunCheckRange)
					{
						int iTeamShotgunCount = TeamShotgunCheck();
						// 团队中所有人（未被控，未倒地，未死亡）都拿着霰弹枪，随机选择最近目标
						if (iTeamShotgunCount == g_iMobileSurvivor)
						{
							curTarget = GetClosestSurvivor(fSelfPos);
							g_iMobileSurvivor = 0;
							iTeamShotgunCount = 0;
							return Plugin_Changed;
						}
						else
						{
							g_iMobileSurvivor = 0;
							iTeamShotgunCount = 0;
						}
						if (curTarget)
						{
							// 检测目标是否手持霰弹枪
							int iActiveWeapon = GetEntPropEnt(curTarget, Prop_Send, "m_hActiveWeapon");
							if (iActiveWeapon)
							{
								char sWeaponName[64];
								GetEdictClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
								if ((strcmp(sWeaponName, "weapon_shotgun_spas") == 0) || (strcmp(sWeaponName, "weapon_autoshotgun") == 0) || (strcmp(sWeaponName, "weapon_pumpshotgun") == 0) || (strcmp(sWeaponName, "weapon_shotgun_chrome") == 0))
								{
									g_iShotgunPlayer = curTarget;
									curTarget = GetClosestSurvivor(fSelfPos, g_iShotgunPlayer);
									return Plugin_Changed;
								}
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

int TeamShotgunCheck()
{
	int iTeamShotgunCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsSurvivor(client) && !IsIncapped(client) && IsPlayerAlive(client) && IsPinned(client))
		{
			g_iMobileSurvivor += 1;
			char sName[64];
			GetClientName(client, sName, sizeof(sName));
			int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(iActiveWeapon) && IsValidEdict(iActiveWeapon))
			{
				char sWeaponName[64];
				GetEdictClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
				if ((strcmp(sWeaponName, "weapon_shotgun_spas") == 0) || (strcmp(sWeaponName, "weapon_autoshotgun") == 0) || (strcmp(sWeaponName, "weapon_pumpshotgun") == 0) || (strcmp(sWeaponName, "weapon_shotgun_chrome") == 0))
				{
					iTeamShotgunCount += 1;
				}
			}
		}
	}
	return iTeamShotgunCount;
}

bool IsPinned(int client)
{
	bool bIsPinned = false;
	if (IsSurvivor(client))
	{
		if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true;
		if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true;
	}		
	return bIsPinned;
}

// ***** 事件 *****
public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadCast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiHunter(client))
	{
		g_bHasQueuedLunge[client] = false;
	}
}

public void evt_AbilityUse(Event event, const char[] name, bool dontBroadCast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiHunter(client))
	{
		static char sAbility[16];
		event.GetString("ability", sAbility, sizeof(sAbility));
		if (strcmp(sAbility, "ability_lunge") == 0)
		{
			Hunter_OnPounce(client);
		}
	}
}

public Action Hunter_OnPounce(int hunter)
{
	float fLungeVector[3];
	int iEntLunge = GetEntPropEnt(hunter, Prop_Send, "m_customAbility");
	GetEntPropVector(iEntLunge, Prop_Send, "m_queuedLunge", fLungeVector);
	// 如果周围有墙体，则优先选择弹墙
	float fHunterPos[3], fHunterAngles[3];
	GetClientAbsOrigin(hunter, fHunterPos);
	GetClientEyeAngles(hunter, fHunterAngles);
	TR_TraceRayFilter(fHunterPos, fHunterAngles, MASK_PLAYERSOLID, RayType_Infinite, TracerayFilter, hunter);
	float fImpactPos[3];
	TR_GetEndPosition(fImpactPos);
	// 如果撞到物体
	if (GetVectorDistance(fHunterPos, fImpactPos) < g_fWallPounceDistance)
	{
		if (GetRandomInt(0, 1))
		{
			AngleLunge(iEntLunge, 45.0);
		}
		else
		{
			AngleLunge(iEntLunge, 315.0);
		}
	}
	else
	{
		float fDistance = NearestSurvivorDistance(hunter);
		if (IsTargetWatchingAttacker(hunter, g_iHunterAimOffset) && fDistance > g_fStraightPounceDistance)
		{
			float fPounceAngle = GaussianRNG(float(g_iPounceAngleMean), float(g_iPounceAngleStd));
			AngleLunge(iEntLunge, fPounceAngle);
			LimitLungeVerticality(iEntLunge);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

bool TracerayFilter(int impactEntity, int contentMask, int rayOriginEntity)
{
	return view_as<bool>(impactEntity > MaxClients && impactEntity != rayOriginEntity);
}

void AngleLunge(int LungeEntity, float turnAngle)
{
	float LungeVector[3];
	GetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", LungeVector);
	float x = LungeVector[X];
	float y = LungeVector[Y];
	float z = LungeVector[Z];
	turnAngle = DegToRad(turnAngle);
	float fForceLunge[3];
	fForceLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle);
	fForceLunge[Y] = x * Sine(turnAngle) + y * Cosine(turnAngle);
	fForceLunge[Z] = z;
	SetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", fForceLunge);
}

void LimitLungeVerticality(int LungeEntity)
{
	float vertAngle = float(g_iPounceVerticalAngle);
	float LungeVector[3];
	GetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", LungeVector);
	float x = LungeVector[X];
	float y = LungeVector[Y];
	float z = LungeVector[Z];
	vertAngle = DegToRad(vertAngle);
	float fFlatLunge[3];
	fFlatLunge[Y] = y * Cosine(vertAngle) - z * Sine(vertAngle);
	fFlatLunge[Z] = y * Sine(vertAngle) + z * Cosine(vertAngle);
	fFlatLunge[X] = x * Cosine(vertAngle) + z * Sine(vertAngle);
	fFlatLunge[Z] = x * -Sine(vertAngle) + z * Cosine(vertAngle);
	SetEntPropVector(LungeEntity, Prop_Send, "m_queuedLunge", fFlatLunge);
}

float GaussianRNG(float mean, float std)
{
	float fChanceToken = GetRandomFloat(0.0, 1.0);
	int iSignBit;
	if (fChanceToken > 0.5)
	{
		iSignBit = POSITIVE;
	}
	else
	{
		iSignBit = NEGETIVE;
	}
	float x1, x2, w;
	do
	{
		float rand1 = GetRandomFloat(0.0, 1.0);
		float rand2 = GetRandomFloat(0.0, 1.0);
		x1 = 2.0 * rand1 - 1.0;
		x2 = 2.0 * rand2 - 1.0;
		w = x1 * x1 + x2 * x2;
	} while (w >= 1.0);
	static float e = 2.71828;
	w = SquareRoot(-2.0 * (Logarithm(w, e) / w));
	float y1 = x1 * w;
	float y2 = x2 * w;
	float z1 = y1 * std + mean;
	float z2 = y2 * std - mean;
	if (iSignBit == NEGETIVE)
	{
		return z1;
	}
	else
	{
		return z2;
	}
}

// ***** 方法 *****
bool IsAiHunter(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_HUNTER && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
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