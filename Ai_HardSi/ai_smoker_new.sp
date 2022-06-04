#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

// Defines
#define ZC_SMOKER 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define SMOKER_MELEE_RANGE 300
#define SMOKER_ATTACK_COORDINATE 5.0

enum AimType
{
	AimEye,
	AimBody,
	AimChest
};

public Plugin myinfo = 
{
	name 			= "Ai_Smoker增强",
	author 			= "Breezy，High Cookie，Standalone，Newteee，cravenge，Harry，Sorallll，PaimonQwQ，夜羽真白",
	description 	= "觉得Ai舌头太弱了？ Try this！",
	version 		= "2022/5/2",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hTongueRange, g_hTargetChoose, g_hMeleeAvoid, g_hVisionInverse, g_hLeftDistance, g_hDistancePercent, g_hSmokerBhop, g_hSmokerBhopSpeed;
// Ints
int g_iTongueRange, g_iTargetChoose, g_iValidSurvivor = 0;
// Bools
bool g_bMeleeAvoid, g_bVisionInverse, bIsBehind[MAXPLAYERS + 1], g_bSmokerBhop;
// Floats
float g_fMapFlowDistance, g_fLeftDistance, g_fDistancePercent, g_fSmokerBhopSpeed;

public void OnPluginStart()
{
	g_hSmokerBhop = CreateConVar("ai_SmokerBhop", "1", "是否开启Smoker连跳", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSmokerBhopSpeed = CreateConVar("ai_SmokerBhopSpeed", "80.0", "Smoker连跳的速度", FCVAR_NOTIFY, true, 0.0);
	g_hTargetChoose = CreateConVar("ai_SmokerTarget", "1", "Smoker优先选择的目标：1=距离最近，2=手持喷子的人（无则最近），3=落单者或超前者（无则最近），4=正在换弹的人（无则最近）", FCVAR_NOTIFY, true, 1.0, true, 4.0);
	g_hMeleeAvoid = CreateConVar("ai_SmokerMeleeAvoid", "1", "Smoker的目标如果手持近战则切换目标", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hVisionInverse = CreateConVar("ai_SmokerVisionInverse", "1", "Smoker正在拉人时视角是否转向背后", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hLeftDistance = CreateConVar("ai_SmokerLeftBehindDistance", "15.0", "玩家距离团队多远判定为落后或超前", FCVAR_NOTIFY, true, 0.0);
	g_hDistancePercent = CreateConVar("ai_SmokerDistantPercent", "0.90", "舌头如果处在这个系数 * 舌头长度的距离范围内，则会立刻拉人", FCVAR_NOTIFY, true, 0.0);
	g_hTongueRange = FindConVar("tongue_range");
	// HookEvent
	HookEvent("round_start", evtRoundStart);
	// AddChangeHooks
	g_hSmokerBhop.AddChangeHook(ConVarChanged_Cvars);
	g_hSmokerBhopSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_hTargetChoose.AddChangeHook(ConVarChanged_Cvars);
	g_hMeleeAvoid.AddChangeHook(ConVarChanged_Cvars);
	g_hVisionInverse.AddChangeHook(ConVarChanged_Cvars);
	g_hTongueRange.AddChangeHook(ConVarChanged_Cvars);
	g_hLeftDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hDistancePercent.AddChangeHook(ConVarChanged_Cvars);
	// GetCvars
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bSmokerBhop = g_hSmokerBhop.BoolValue;
	g_fSmokerBhopSpeed = g_hSmokerBhopSpeed.FloatValue;
	g_iTargetChoose = g_hTargetChoose.IntValue;
	g_iTongueRange = g_hTongueRange.IntValue;
	g_bMeleeAvoid = g_hMeleeAvoid.BoolValue;
	g_bVisionInverse = g_hVisionInverse.BoolValue;
	g_fLeftDistance = g_hLeftDistance.FloatValue;
	g_fDistancePercent = g_hDistancePercent.FloatValue;
}

public Action evtRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client))
		{
			bIsBehind[client] = false;
		}
	}
	g_fMapFlowDistance = L4D2Direct_GetMapMaxFlowDistance();
}

public Action OnPlayerRunCmd(int smoker, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsAiSmoker(smoker))
	{
		int iTarget = GetClientAimTarget(smoker, true);
		float fSmokerPos[3] = {0.0}, fTargetPos[3] = {0.0}, fTargetAngles[3] = {0.0};
		GetClientAbsOrigin(smoker, fSmokerPos);
		bool bHasSight = view_as<bool>(GetEntProp(smoker, Prop_Send, "m_hasVisibleThreats"));
		if (IsSurvivor(iTarget))
		{
			GetClientAbsOrigin(iTarget, fTargetPos);
			float fDistance = GetVectorDistance(fSmokerPos, fTargetPos);
			if (g_bSmokerBhop)
			{
				float fSpeed[3], fCurrentSpeed;
				GetEntPropVector(smoker, Prop_Data, "m_vecVelocity", fSpeed);
				fCurrentSpeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
				if (g_fDistancePercent * float(g_iTongueRange) < fDistance < 2000.0 && fCurrentSpeed > 190.0)
				{
					if (GetEntityFlags(smoker) & FL_ONGROUND)
					{
						float fSmokerEyeAngles[3], fForwardVec[3];
						GetClientEyeAngles(smoker, fSmokerEyeAngles);
						GetAngleVectors(fSmokerEyeAngles, fForwardVec, NULL_VECTOR, NULL_VECTOR);
						NormalizeVector(fForwardVec, fForwardVec);
						ScaleVector(fForwardVec, g_fSmokerBhopSpeed);
						buttons |= IN_JUMP;
						buttons |= IN_DUCK;
						if ((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT))
						{
							ClientPush(smoker, fForwardVec);
						}
					}
				}
			}
			// 没有开视角锁定，则可以锁定视角在生还身上
			if (bHasSight && !g_bVisionInverse)
			{
				ComputeAimAngles(smoker, iTarget, fTargetAngles, AimChest);
				fTargetAngles[2] = 0.0;
				TeleportEntity(smoker, NULL_VECTOR, fTargetAngles, NULL_VECTOR);
			}
			// 由于舌头需要拉人，所以此时需要判断可见性
			if (IsSurvivor(iTarget) && bHasSight && !IsIncapped(iTarget) && !IsPinned(iTarget))
			{
				if (fDistance < SMOKER_MELEE_RANGE)
				{
					buttons |= IN_ATTACK;
					buttons |= IN_ATTACK2;
					return Plugin_Changed;
				}
				else if (fDistance < g_fDistancePercent * float(g_iTongueRange))
				{
					buttons |= IN_ATTACK2;
					buttons |= IN_ATTACK;
					return Plugin_Changed;
				}
			}
		}
		// 拉到人了
		int iVictim = L4D_GetVictimSmoker(smoker);
		if (IsSurvivor(iVictim))
		{
			if (g_bVisionInverse)
			{
				DataPack pack = new DataPack();
				pack.WriteCell(iVictim);
				pack.WriteCell(smoker);
				VisionInverse(pack);
			}
		}
	}
	return Plugin_Continue;
}

public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if (IsAiSmoker(specialInfected))
	{
		// 不拉被控和倒地的人
		if (IsSurvivor(curTarget))
		{
			if (IsPinned(curTarget) || IsIncapped(curTarget))
			{
				int newtarget = SmokerTargetChoose(g_iTargetChoose, specialInfected, curTarget);
				if (IsSurvivor(newtarget))
				{
					curTarget = newtarget;
					return Plugin_Changed;
				}
			}
		}
		if (g_bMeleeAvoid)
		{
			// 先检测团队近战数量，如果所有生还者都拿着近战，则随机选择目标
			int iTeamMeleeCount = TeamMeleeCheck();
			if (iTeamMeleeCount == g_iValidSurvivor)
			{
				g_iValidSurvivor = 0;
				iTeamMeleeCount = 0;
				int newtarget = SmokerTargetChoose(g_iTargetChoose, specialInfected);
				if (IsSurvivor(newtarget))
				{
					curTarget = newtarget;
					return Plugin_Changed;
				}
			}
			// 团队中并不是所有生还者都拿着近战，重新将g_iValidSurvivor设置为0
			else
			{
				g_iValidSurvivor = 0;
				iTeamMeleeCount = 0;
			}
			// 如果有目标，则继续判断目标是否拿着近战
			if (IsSurvivor(curTarget))
			{
				// 检测目标是否手持近战
				int iActiveWeapon = GetEntPropEnt(curTarget, Prop_Send, "m_hActiveWeapon");
				if (IsValidEntity(iActiveWeapon) && IsValidEdict(iActiveWeapon))
				{
					char sWeaponName[32];
					GetEdictClassname(iActiveWeapon, sWeaponName, sizeof(sWeaponName));
					if (strcmp(sWeaponName[7], "melee") == 0 || strcmp(sWeaponName, "weapon_chainsaw") == 0)
					{
						int newtarget = SmokerTargetChoose(g_iTargetChoose, specialInfected, curTarget);
						for (int i = 1; i <= MaxClients; i++)
						{
							if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == view_as<int>(TEAM_SURVIVOR) && i != curTarget)
							{
								float self_eye_pos[3] = {0.0}, eye_pos[3] = {0.0};
								GetClientEyePosition(specialInfected, self_eye_pos);
								GetClientEyePosition(i, eye_pos);
								Handle hTrace = TR_TraceRayFilterEx(self_eye_pos, eye_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, specialInfected);
								if (!TR_DidHit(hTrace) && GetVectorDistance(self_eye_pos, eye_pos) < 600.0 && IsSurvivor(newtarget))
								{
									curTarget = newtarget;
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
bool TR_RayFilter(int entity, int mask, int self)
{
	return entity != self;
}

bool IsAiSmoker(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_SMOKER && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

void VisionInverse(DataPack pack)
{
	pack.Reset();
	int victim = pack.ReadCell();
	int attacker = pack.ReadCell();
	float fSelfPos[3], fTargetPos[3], fLookAt[3], fNegetiveLookAt[3];
	if (IsAiSmoker(attacker))
	{
		GetClientEyePosition(attacker, fSelfPos);
		if (IsSurvivor(victim))
		{
			GetClientEyePosition(victim, fTargetPos);
			MakeVectorFromPoints(fSelfPos, fTargetPos, fLookAt);
			NegateVector(fLookAt);
			GetVectorAngles(fLookAt, fNegetiveLookAt);
			TeleportEntity(attacker, NULL_VECTOR, fNegetiveLookAt, NULL_VECTOR);
		}
	}
	delete pack;
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

// 团队近战检测
int TeamMeleeCheck()
{
	int iTeamMeleeCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !IsIncapped(client) && IsPinned(client))
		{
			g_iValidSurvivor += 1;
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

// 目标选择
int SmokerTargetChoose(int iMethod, int iSmoker, int iSpecificTarget = -1)
{
	int iTarget = -1;
	float fSelfPos[3];
	GetClientAbsOrigin(iSmoker, fSelfPos);
	switch (iMethod)
	{
		case 1:
		{
			int newtarget = GetClosestSurvivor(fSelfPos, iSpecificTarget);
			if (IsSurvivor(newtarget))
			{
				iTarget = newtarget;
			}
		}
		case 2:
		{
			for (int client = 1; client <= MaxClients; ++client)
			{
				if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_SURVIVOR && !IsIncapped(client) && !IsPinned(client) && client != iSpecificTarget)
				{
					char sWeaponName[32] = '\0';
					char iWeapon = GetPlayerWeaponSlot(client, 0);
					if (IsValidEntity(iWeapon) && IsValidEdict(iWeapon))
					{
						GetEdictClassname(iWeapon, sWeaponName, sizeof(sWeaponName));
						if (strcmp(sWeaponName, "weapon_pumpshotgun") == 0 || strcmp(sWeaponName, "weapon_shotgun_chrome") == 0 || strcmp(sWeaponName, "weapon_autoshotgun") == 0 || strcmp(sWeaponName, "weapon_shotgun_spas") == 0)
						{
							iTarget = client;
							return iTarget;
						}
					}
				}
			}
			// 检测完毕所有玩家，如果所有玩家主武器不是喷子，选择最近玩家
			int newtarget = GetClosestSurvivor(fSelfPos, iSpecificTarget);
			if (IsSurvivor(newtarget))
			{
				iTarget = newtarget;
			}
		}
		case 3:
		{
			float fTeamDistance = 0.0, fPlayerDistance = 0.0;
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !IsIncapped(client) && !IsPinned(client) && client != iSpecificTarget)
				{
					// 玩家落后的情况
					if (IsClientLeftBehind(client))
					{
						float targetpos[3] = {0.0};
						L4D_GetRandomPZSpawnPosition(iSmoker, ZC_SMOKER, 5, targetpos);
						TeleportEntity(iSmoker, targetpos, NULL_VECTOR, NULL_VECTOR);
						iTarget = client;
						bIsBehind[client] = true;
						return iTarget;
					}
					else
					{
						bIsBehind[client] = false;
					}
					// 先将落后玩家的IsBehind设置为true，再计算团队距离，将排除落后玩家，判断玩家是否超前
					fTeamDistance = CalculateTeamDistance(client);
					fPlayerDistance = L4D2Direct_GetFlowDistance(client) / g_fMapFlowDistance;
					if (fPlayerDistance > 0.0 && fPlayerDistance < 1.0 && fTeamDistance != 1.0)
					{
						if (fTeamDistance + g_fLeftDistance < fPlayerDistance)
						{
							float targetpos[3] = {0.0};
							L4D_GetRandomPZSpawnPosition(iSmoker, ZC_SMOKER, 5, targetpos);
							TeleportEntity(iSmoker, targetpos, NULL_VECTOR, NULL_VECTOR);
							iTarget = client;
							return iTarget;
						}
						else
						{
							bIsBehind[client] = false;
						}
					}
				}
				// 到这里已经执行完了所有操作，将所有玩家IsBehind设置为false
				bIsBehind[client] = false;
			}
			// 检测完毕所有玩家，如果玩家既无落后又无超前，选择最近玩家
			int newtarget = GetClosestSurvivor(fSelfPos, iSpecificTarget);
			if (IsSurvivor(newtarget))
			{
				iTarget = newtarget;
			}
		}
		case 4:
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !IsIncapped(client) && !IsPinned(client) && client != iSpecificTarget)
				{
					if (IsInReload(client))
					{
						iTarget = client;
						return iTarget;
					}
				}
			}
			// 检测完毕所有玩家，如果没人正在换弹，选择最近玩家
			int newtarget = GetClosestSurvivor(fSelfPos, iSpecificTarget);
			if (IsSurvivor(newtarget))
			{
				iTarget = newtarget;
			}
		}
	}
	return iTarget;
}

// 检测生还是否在换弹
bool IsInReload(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(weapon) && IsValidEdict(weapon) && HasEntProp(weapon, Prop_Data, "m_bInReload"))
	{
		if (GetEntProp(weapon, Prop_Data, "m_bInReload") == 1)
		{
			return true;
		}
	}
	return false;
}

// 计算团队距离
float CalculateTeamDistance(int excludeClient)
{
	float fTeamDistance = 0.0;
	int counter = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVOR && !IsIncapped(i) && !IsPinned(i) && i != excludeClient && !bIsBehind[i])
		{
			float fPlayerFlow = L4D2Direct_GetFlowDistance(i) / g_fMapFlowDistance;
			if (fPlayerFlow > 0.0 && fPlayerFlow < 1.0)
			{
				fTeamDistance += fPlayerFlow;
				counter++;
			}
		}
	}
	if (counter > 1)
	{
		// 根据其他生还者的距离计算平均距离作为团队距离
		fTeamDistance /= counter;
	}
	else
	{
		fTeamDistance = -1.0;
	}
	return fTeamDistance;
}

// 判断生还是否落后
bool IsClientLeftBehind(int client)
{
	float fTeamDistance = CalculateTeamDistance(client);
	float fPlayerDistance = L4D2Direct_GetFlowDistance(client) / g_fMapFlowDistance;
	if (fPlayerDistance > 0.0 && fPlayerDistance <= 1.0 && fTeamDistance != -1.0)
	{
		if (fPlayerDistance + g_fLeftDistance < fTeamDistance)
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

// 是否是生还？
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

// 目标是否在倒地状态？
bool IsIncapped(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

int GetRandomMobileSurvivor()
{
	int survivors[16] = {0}, index = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !IsIncapped(client) && !IsPinned(client))
		{
			survivors[index] = client;
			index += 1;
		}
	}
	if (index > 0)
	{
		return survivors[GetRandomInt(0, index - 1)];
	}
	return 0;
}

// 选择最近玩家
int GetClosestSurvivor(float refpos[3], int excludeSur = -1)
{
	float surPos[3] = {0.0};
	int closetSur = GetRandomMobileSurvivor();
	if (IsSurvivor(closetSur))
	{
		GetClientAbsOrigin(closetSur, surPos);
		int iClosetAbsDisplacement = RoundToNearest(GetVectorDistance(refpos, surPos));
		for (int client = 1; client < MaxClients; client++)
		{
			if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !IsIncapped(client) && !IsPinned(client) && client != excludeSur)
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