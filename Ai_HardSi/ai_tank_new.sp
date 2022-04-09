#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

// Defines
#define TEAM_SURVIVOR 2 
#define TEAM_INFECTED 3
#define OBSTACLE_HEIGHT 18.0
#define PLAYER_HEIGHT 72.0
#define TANKAIMDELAY 0.25
#define TANKAIMTIME 3.0
// CommandAbot
#define PLUGIN_SCRIPTLOGIC "plugin_scripting_logic_entity"
#define COMMANDABOT_MOVE "CommandABot({cmd = 1, pos = Vector(%f, %f, %f), bot = GetPlayerFromUserID(%i)})"
#define COMMANDABOT_ATTACK "CommandABot({cmd = 0, bot = GetPlayerFromUserID(%i), target = GetPlayerFromUserID(%i)})"
#define COMMANDABOT_RESET "CommandABot({cmd = 3, bot = GetPlayerFromUserID(%i)})"
// RockThrowSequence
#define SEQUENCE_ONEHAND 49
#define SEQUENCE_UNDERHAND 50
#define SEQUENCE_TWOHAND 51
// ZC_CLASS
#define ZC_SMOKER 1
#define ZC_BOOMER 2
#define ZC_HUNTER 3
#define ZC_SPITTER 4
#define ZC_JOCKEY 5
#define ZC_CHARGER 6
#define ZC_TANK 8
// Flags
#define FL_JUMPING 65922

// Enums
enum AimType
{
	AimEye,
	AimBody,
	AimChest
};

public Plugin myinfo =
{
	name 			= "Ai_Tank_Enhance",
	author 			= "Breezy，High Cookie，Standalone，Newteee，cravenge，Harry，Sorallll，PaimonQwQ，夜羽真白",
	description 	= "觉得Ai克太弱了？ Try this！",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVars
ConVar g_hTankBhop, g_hTankThrow, g_hTankThrowDist, g_hTankTarget, g_hTankBhopSpeed, g_hTreeDetect, g_hTreeNewTarget, g_hTankAirAngles, g_hTankAttackRange, g_hTankConsumeFindPositionCount
, g_hTankConsumeHeight, g_hTankConsumLimit, g_hTankConsumeNewPositionDistance, g_hTankConsumeRaidus, g_hTankAttackVomitedNum, g_hVomitCanInstantAttack, g_hVomitAttackInterval, g_hTeleportForwardPercent
, g_hVsBossFlowBuffer, g_hTankConsumeLimitNum, g_hTankThrowForce, g_hTankConsume, g_hTankConsumeType, g_hTankBhopHitWllDistance, g_hTankRetreatAirAngles, g_hTankConsumeAction, g_hTankConsumeDamagePercent
, g_hTankForceAttackDistance, g_hTankConsumeHealthLimit, g_hDebugMod;
// Ints
int g_iTankTarget, g_iTankThrowDist, g_iTreeDetect, g_iTreePlayer[MAXPLAYERS + 1] = -1, g_iTreeNewTarget, g_iTankConsumeFindPositionCount, g_iTankConsumeLimit, g_iTankConsumeChooseNewPositionDistance
, g_iTankConsumeRaidus, g_iTankAttackVomitedNum, g_iVomitedPlayer = 0, g_iTeleportForwardPercent, g_iTankConsumeSurvivorProgress[MAXPLAYERS + 1] = 0
, g_iTankConsumeNum, g_iTankConsumeLimitNum[MAXPLAYERS + 1] = 0, g_iTankConsumeType, g_iTankConsumeAction, g_iTankConsumeDamagePercent, g_iTankForceAttackDistance, g_iTankConsumeHealthLimit;
// Bools
bool g_bTankBhop, g_bTankThrow, g_bCanTankConsume[MAXPLAYERS + 1] = false, g_bInConsumePlace[MAXPLAYERS + 1] = false, g_bReturnConsumePlace[MAXPLAYERS + 1] = false, g_bCanTankAttack[MAXPLAYERS + 1] = true
, g_bVomitCanInstantAttack, g_bVomitCanConsume[MAXPLAYERS + 1] = false, g_bTankConsume, g_bIsFirstConsumeCheck[MAXPLAYERS + 1] = true, g_bDebugMod;
// Floats
float g_fTankBhopSpeed, g_fTankAirAngles, g_fTankAttackRange, g_fTreePlayerOriginPos[3], g_fTankConsumeHeight, g_fConsumePosition[MAXPLAYERS + 1][3]
, g_fTeleportPosition[MAXPLAYERS + 1][3], g_fVomitAttackInterval, g_fRunTopSpeed[MAXPLAYERS + 1], g_fTankBhopHitWallDistance, g_fTankRetreatAirAngles, g_fDelay[MAXPLAYERS + 1][8];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion Engine = GetEngineVersion();
	if (Engine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "当前插件仅适用于 Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	CreateNative("IsTankInConsume", Native_IsTankInConsume);
	CreateNative("IsTankInConsumePlace", Native_IsTankInConsumePlace);
	RegPluginLibrary("tankconsume");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hTankBhopSpeed = CreateConVar("ai_Tank_BhopSpeed", "80.0", "Tank连跳的速度", FCVAR_NOTIFY, true, 0.0);
	g_hTankBhop = CreateConVar("ai_Tank_Bhop", "1", "是否开启Tank连跳功能：0=关闭，1=开启", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hTankThrow = CreateConVar("ai_Tank_Throw", "1", "是否允许Tank投掷石块：0=关闭，1=开启", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hTankThrowDist = CreateConVar("ai_Tank_ThrowDistance", "300", "Tank距离目标多近允许投掷石块", FCVAR_NOTIFY, true, 0.0);
	g_hTankTarget = CreateConVar("ai_Tank_Target", "1", "Tank目标选择：1=最近，2=血量最少，3=血量最多", FCVAR_NOTIFY, true, 1.0, true, 3.0);
	g_hTreeDetect = CreateConVar("ai_Tank_TreeDetect", "1", "生还者与Tank进行秦王绕柱时进行的操作：0=关闭此项，1=切换目标，2=将Tank传送至绕树的生还者后", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_hTreeNewTarget = CreateConVar("ai_Tank_TreeNewTargetDistance", "300", "Tank记录绕树生还者并选择新目标后，距离新目标多近重置绕树目标记录", FCVAR_NOTIFY, true, 0.0);
	g_hTankAirAngles = CreateConVar("ai_TankAirAngles", "60.0", "Tank在空中的速度向量与到生还者的方向向量夹角大于这个值停止连跳", FCVAR_NOTIFY, true, 0.0, true, 90.0);
	g_hTankConsume = CreateConVar("ai_TankConsume", "1", "是否开启Tank消耗功能", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hTankConsumeFindPositionCount = CreateConVar("ai_Tank_ConsumeFindPositionCount", "10", "Tank进行消耗时的找位次数", FCVAR_NOTIFY, true, 0.0);
	g_hTankConsumeHeight = CreateConVar("ai_Tank_ConsumeHeight", "250", "Tank进行消耗时将会优先选择高于这个高度的位置，如无则随机选位", FCVAR_NOTIFY, true, 0.0);
	g_hTankConsumLimit = CreateConVar("ai_Tank_ConsumeLimit", "2", "感染者团队少于多少特感时，Tank会进行消耗", FCVAR_NOTIFY, true, 0.0);
	g_hTankConsumeNewPositionDistance = CreateConVar("ai_Tank_ConsumeChooseNewPositionDistance", "150", "当Tank进入消耗位置时生还者距离Tank多近它会选择新的消耗位置", FCVAR_NOTIFY, true, 0.0);
	g_hTankConsumeRaidus = CreateConVar("ai_Tank_ConsumeRaidus", "50.0", "Tank消耗位置的范围，从中心坐标以这个半径画圆", FCVAR_NOTIFY, true, 0.0);
	g_hTankAttackVomitedNum = CreateConVar("ai_Tank_AttackVomitedNum", "1", "如果有这个数量的生还者被Boomer喷吐到，正在进行消耗的Tank将会攻击", FCVAR_NOTIFY, true, 0.0);
	g_hVomitCanInstantAttack = CreateConVar("ai_Tank_VomitCanInstantAttack", "1", "是否开启固定数量生还者被喷吐后Tank立刻攻击", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hVomitAttackInterval = CreateConVar("ai_Tank_VomitAttackInterval", "20.0", "从开始被喷且Tank允许攻击时开始，这个时间内Tank允许攻击", FCVAR_NOTIFY, true, 0.0);
	g_hTeleportForwardPercent = CreateConVar("ai_Tank_TeleportForwardPercent", "10", "Tank开始消耗时，记录此时生还者行进距离x，生还者前压超过x + 这个值时，Tank会传送至生还者处进行压制", FCVAR_NOTIFY, true, 0.0);
	g_hTankConsumeLimitNum = CreateConVar("ai_Tank_ConsumeLimitNum", "2", "Tank最多进行消耗的次数（这个值 * 50）", FCVAR_NOTIFY, true, 0.0);
	g_hTankConsumeType = CreateConVar("ai_TankConsumeType", "3", "Tank进行消耗将会按照哪种特感类型找位：1=Smoker，2=Boomer，3=Hunter，4=Spitter，5=Jockey，6=Charger，8=Tank");
	g_hTankBhopHitWllDistance = CreateConVar("ai_TankBhopHitWallDistance", "100.0", "Tank视角前这个距离内有障碍物，Tank将会停止连跳", FCVAR_NOTIFY, true, 0.0);
	g_hTankRetreatAirAngles = CreateConVar("ai_TankRetreatAirAngles", "75.0", "Tank在回避的连跳过程中视角与速度超过这个值将会停止连跳", FCVAR_NOTIFY, true, 0.0);
	g_hTankConsumeAction = CreateConVar("ai_TankConsumeAction", "2", "Tank在消耗范围内将会：1=冰冻，2=可活动但不允许超出消耗范围", FCVAR_NOTIFY, true, 1.0, true, 2.0);
	g_hTankConsumeDamagePercent = CreateConVar("ai_TankConsumeDamagePercent", "50", "Tank在消耗过程中只会受到这个百分比的伤害", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	// 2022-4-7新增
	g_hTankForceAttackDistance = CreateConVar("ai_TankForceAttackDistance", "1000", "Tank在离最近生还这个距离时即使可以消耗也不会当着生还的面回避生还", FCVAR_NOTIFY, true, 0.0);
	g_hTankConsumeHealthLimit = CreateConVar("ai_TankConsumeHealthLimit", "2500", "Tank在少于这么多血量时不会消耗", FCVAR_NOTIFY, true, 0.0);
	// 调试输出
	g_hDebugMod = CreateConVar("ai_TankDebugMod", "0", "是否开启调试输出", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// 其他 Cvar
	g_hTankAttackRange = FindConVar("tank_attack_range");
	g_hVsBossFlowBuffer = FindConVar("versus_boss_buffer");
	g_hTankThrowForce = FindConVar("z_tank_throw_force");
	// HookEvents
	HookEvent("player_spawn", evt_PlayerSpawn);
	HookEvent("player_death", evt_PlayerDeath);
	HookEvent("player_now_it", evt_PlayerNowIt);
	// AddChangeHook
	g_hTankBhop.AddChangeHook(ConVarChanged_Cvars);
	g_hTankThrow.AddChangeHook(ConVarChanged_Cvars);
	g_hTankThrowDist.AddChangeHook(ConVarChanged_Cvars);
	g_hTankTarget.AddChangeHook(ConVarChanged_Cvars);
	g_hTreeDetect.AddChangeHook(ConVarChanged_Cvars);
	g_hTreeNewTarget.AddChangeHook(ConVarChanged_Cvars);
	g_hTankBhopSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_hTankAirAngles.AddChangeHook(ConVarChanged_Cvars);
	g_hTankAttackRange.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeFindPositionCount.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeHeight.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumLimit.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeNewPositionDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeRaidus.AddChangeHook(ConVarChanged_Cvars);
	g_hTankAttackVomitedNum.AddChangeHook(ConVarChanged_Cvars);
	g_hVomitCanInstantAttack.AddChangeHook(ConVarChanged_Cvars);
	g_hVomitAttackInterval.AddChangeHook(ConVarChanged_Cvars);
	g_hTeleportForwardPercent.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeLimitNum.AddChangeHook(ConVarChanged_Cvars);
	g_hVsBossFlowBuffer.AddChangeHook(ConVarChanged_Cvars);
	g_hTankThrowForce.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsume.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeType.AddChangeHook(ConVarChanged_Cvars);
	g_hTankBhopHitWllDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hTankRetreatAirAngles.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeAction.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeDamagePercent.AddChangeHook(ConVarChanged_Cvars);
	g_hTankForceAttackDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hTankConsumeHealthLimit.AddChangeHook(ConVarChanged_Cvars);
	g_hDebugMod.AddChangeHook(ConVarChanged_Cvars);
	// GetConVar
	GetCvars();
	// 数组初始化
	for (int i = 0; i < MAXPLAYERS + 1; i++)
	{
		for (int j = 0; j < 3; j++)
		{
			g_fConsumePosition[i][j] = 0.0;
			g_fTeleportPosition[i][j] = 0.0;
		}
	}
	// Debug
	RegAdminCmd("sm_con", Cmd_Consume, ADMFLAG_BAN);
}

// **************
//		指令
// **************
public Action Cmd_Consume(int client, int args)
{
	if (client && client <= MaxClients && IsClientInGame(client))
	{
		int iTank;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsAiTank(i))
			{
				iTank = i;
			}
		}
		DoConsume(iTank);
	}
}

// 向量绘制
// #include "vector/vector_show.sp"

// ******************
//		Natives
// ******************
public int Native_IsTankInConsume(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_bCanTankConsume[client];
}

public int Native_IsTankInConsumePlace(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_bInConsumePlace[client];
}

// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bTankBhop = g_hTankBhop.BoolValue;
	g_bTankThrow = g_hTankThrow.BoolValue;
	g_iTankTarget = g_hTankTarget.IntValue;
	g_iTankThrowDist = g_hTankThrowDist.IntValue;
	g_iTreeDetect = g_hTreeDetect.IntValue;
	g_iTreeNewTarget = g_hTreeNewTarget.IntValue;
	g_fTankBhopSpeed = g_hTankBhopSpeed.FloatValue;
	g_fTankAirAngles = g_hTankAirAngles.FloatValue;
	g_fTankAttackRange = g_hTankAttackRange.FloatValue;
	g_iTankConsumeFindPositionCount = g_hTankConsumeFindPositionCount.IntValue;
	g_fTankConsumeHeight = g_hTankConsumeHeight.FloatValue;
	g_iTankConsumeLimit = g_hTankConsumLimit.IntValue;
	g_iTankConsumeChooseNewPositionDistance = g_hTankConsumeNewPositionDistance.IntValue;
	g_iTankConsumeRaidus = g_hTankConsumeRaidus.IntValue;
	g_iTankAttackVomitedNum = g_hTankAttackVomitedNum.IntValue;
	g_bVomitCanInstantAttack = g_hVomitCanInstantAttack.BoolValue;
	g_fVomitAttackInterval = g_hVomitAttackInterval.FloatValue;
	g_iTeleportForwardPercent = g_hTeleportForwardPercent.IntValue;
	g_iTankConsumeNum = g_hTankConsumeLimitNum.IntValue;
	g_bTankConsume = g_hTankConsume.BoolValue;
	g_iTankConsumeType = g_hTankConsumeType.IntValue;
	g_fTankBhopHitWallDistance = g_hTankBhopHitWllDistance.FloatValue;
	g_fTankRetreatAirAngles = g_hTankRetreatAirAngles.FloatValue;
	g_iTankConsumeAction = g_hTankConsumeAction.IntValue;
	g_iTankConsumeDamagePercent = g_hTankConsumeDamagePercent.IntValue;
	g_iTankForceAttackDistance = g_hTankForceAttackDistance.IntValue;
	g_iTankConsumeHealthLimit = g_hTankConsumeHealthLimit.IntValue;
	g_bDebugMod = g_hDebugMod.BoolValue;
}

// **************
//		主要
// **************
public Action OnPlayerRunCmd(int tank, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsAiTank(tank))
	{
		float fTankPos[3];
		GetClientAbsOrigin(tank, fTankPos);
		int iSurvivorDistance, iTarget, iFlags, iNearestTarget;
		iSurvivorDistance = GetSurvivorDistance(fTankPos);	iTarget = GetClientAimTarget(tank, true);	iNearestTarget = GetClosestSurvivor(fTankPos);
		// 获取坦克状态，速度
		iFlags = GetEntityFlags(tank);
		float fSpeed[3], fCurrentSpeed, fAngles[3];
		GetEntPropVector(tank, Prop_Data, "m_vecVelocity", fSpeed);
		fCurrentSpeed = SquareRoot(Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0));
		bool bHasSight = view_as<bool>(GetEntProp(tank, Prop_Send, "m_hasVisibleThreats"));
		// 是否允许投掷石块？
		if (g_bTankThrow)
		{
			if (iSurvivorDistance > g_iTankThrowDist)
			{
				buttons &= ~IN_ATTACK2;
			}
		}
		else
		{
			buttons &= ~IN_ATTACK2;
		}
		if (buttons & IN_ATTACK2)
		{
			DelayStart(tank, 3);
			DelayStart(tank, 4);
		}
		if (iTarget > 0)
		{
			// 连跳操作
			if (g_bTankBhop)
			{
				// 有目标并且没有扔石头时，锁定视野
				if (bHasSight && DelayExpired(tank, 4, TANKAIMDELAY) && DelayExpired(tank, 3, TANKAIMTIME))
				{
					float TargetAngles[3] = 0.0;
					ComputeAimAngles(tank, iTarget, TargetAngles, AimChest);
					TargetAngles[2] = 0.0;
					TeleportEntity(tank, NULL_VECTOR, TargetAngles, NULL_VECTOR);
				}
				// 计算坦克与目标之间的距离
				float fBuffer[3], fTargetPos[3];
				GetClientAbsOrigin(iTarget, fTargetPos);
				fBuffer = UpdatePosition(tank, iTarget, g_fTankBhopSpeed);
				if (g_fTankAttackRange < iSurvivorDistance < 2000 && fCurrentSpeed > 190.0)
				{
					if (iFlags & FL_ONGROUND)
					{
						if (!BhopWillHitWall(tank, g_fTankBhopHitWallDistance))
						{
							buttons |= IN_JUMP;
							buttons |= IN_DUCK;
							// 方向按钮按下的情况，判断下一帧位置是否会坠落，如果已传送，则不会坠落，返回true，执行方向，会则返回false，不执行方向，直到不会坠落
							if (DoBhop(tank, buttons, fBuffer))
							{
								return Plugin_Changed;
							}
						}
					}
					else if (iFlags == FL_JUMPING)
					{
						if (!g_bCanTankConsume[tank])
						{
							if (iSurvivorDistance > g_fTankAttackRange)
							{
								float fAnglesPost[3];
								GetVectorAngles(fSpeed, fAngles);
								fAnglesPost = fAngles;
								fAngles[0] = fAngles[2] = 0.0;
								GetAngleVectors(fAngles, fAngles, NULL_VECTOR, NULL_VECTOR);
								NormalizeVector(fAngles, fAngles);
								// 保存当前位置
								static float fDirection[2][3];
								fDirection[0] = fTankPos;
								fDirection[1] = fTargetPos;
								fTankPos[2] = fTargetPos[2] = 0.0;
								MakeVectorFromPoints(fTankPos, fTargetPos, fTankPos);
								NormalizeVector(fTankPos, fTankPos);
								// 计算距离
								if (g_bDebugMod)
								{
									PrintToChatAll("\x05【提示】：有目标时速度与视角的角度：\x04%.2f", RadToDeg(ArcCosine(GetVectorDotProduct(fAngles, fTankPos))));
								}
								if (RadToDeg(ArcCosine(GetVectorDotProduct(fAngles, fTankPos))) < g_fTankAirAngles)
								{
									return Plugin_Continue;
								}
								// 重新设置速度方向
								float fNewVelocity[3];
								MakeVectorFromPoints(fDirection[0], fDirection[1], fNewVelocity);
								TeleportEntity(tank, NULL_VECTOR, fAnglesPost, fNewVelocity);
							}
						}
					}
				}
			}
		}
		else
		{
			if (!g_bInConsumePlace[tank])
			{
				// 逃跑时，前往消耗位的途中连跳，在消耗位时不允许连跳，减少从消耗位里跳出来的概率
				float fTankEyeAngles[3], fForwardVec[3];
				GetClientEyeAngles(tank, fTankEyeAngles);
				GetAngleVectors(fTankEyeAngles, fForwardVec, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(fForwardVec, fForwardVec);
				ScaleVector(fForwardVec, g_fTankBhopSpeed);
				if (g_bCanTankConsume[tank] && !g_bInConsumePlace[tank])
				{
					if (g_bTankBhop)
					{
						if (iFlags & FL_ONGROUND)
						{
							if (fCurrentSpeed > 190.0)
							{
								if (!BhopWillHitWall(tank, g_fTankBhopHitWallDistance))
								{
									buttons |= IN_JUMP;
									buttons |= IN_DUCK;
									if (DoBhop(tank, buttons, fForwardVec))
									{
										return Plugin_Changed;
									}
								}
							}
						}
						else if (iFlags == FL_JUMPING)
						{
							float fRetreatAnglePost[3];
							GetVectorAngles(fSpeed, fAngles);
							fRetreatAnglePost = fAngles;
							fAngles[0] = fAngles[2] = 0.0;
							GetAngleVectors(fAngles, fAngles, NULL_VECTOR, NULL_VECTOR);
							NormalizeVector(fAngles, fAngles);
							static float fEyeAngles[3];
							GetClientEyeAngles(tank, fEyeAngles);
							fEyeAngles[0] = fEyeAngles[2] = 0.0;
							GetAngleVectors(fEyeAngles, fEyeAngles, NULL_VECTOR, NULL_VECTOR);
							NormalizeVector(fEyeAngles, fEyeAngles);
							if (g_bDebugMod)
							{
								PrintToChatAll("\x05【提示】：无目标时速度与视角的角度：\x04%.2f", RadToDeg(ArcCosine(GetVectorDotProduct(fAngles, fEyeAngles))));
							}
							if (RadToDeg(ArcCosine(GetVectorDotProduct(fAngles, fEyeAngles))) < g_fTankRetreatAirAngles)
							{
								return Plugin_Continue;
							}
							TeleportEntity(tank, NULL_VECTOR, fRetreatAnglePost, fSpeed);
						}
					}
				}
			}
			// 不允许消耗时或允许消耗且在消耗位置时，锁定视野，不影响逃跑时的路线
			if (g_bCanTankConsume[tank] && g_bInConsumePlace[tank])
			{
				if (iNearestTarget > 0)
				{
					PrintToChatAll("在消耗位上锁定视角");
					float fNewTargetAngles[3] = 0.0;
					ComputeAimAngles(tank, iNearestTarget, fNewTargetAngles, AimEye);
					fNewTargetAngles[2] = 0.0;
					TeleportEntity(tank, NULL_VECTOR, fNewTargetAngles, NULL_VECTOR);
				}
			}
		}
		// 消耗操作
		if (g_bTankConsume)
		{
			if (!g_bIsFirstConsumeCheck[tank])
			{
				CheckCanTankConsume(tank);
			}
			// 消耗位置判断
			if ((g_fConsumePosition[tank][0] != 0.0) && (g_fConsumePosition[tank][1] != 0.0) && (g_fConsumePosition[tank][2] != 0.0))
			{
				if (!g_bInConsumePlace[tank])
				{
					// 为假，则坦克进入了范围内
					if (!bHasLeftRoundPoint(g_fConsumePosition[tank], fTankPos, g_iTankConsumeRaidus))
					{
						// 如果进入了消耗范围内仍然能看到生还者，或者最近生还者位置与坦克位置小于200，则选择新的消耗位置
						if (bHasSight || IsVisible(tank, iNearestTarget) || iSurvivorDistance < g_iTankConsumeChooseNewPositionDistance)
						{
							g_bInConsumePlace[tank] = false;
							if (g_iTankConsumeLimitNum[tank] <= g_iTankConsumeNum)
							{
								DoConsume(tank);
								g_iTankConsumeLimitNum[tank] += 1;
							}
							else
							{
								TankActionReset(tank);
							}
						}
						else
						{
							g_bInConsumePlace[tank] = true;
							g_bReturnConsumePlace[tank] = false;
							switch (g_iTankConsumeAction)
							{
								case 1:
								{
									SetEntityMoveType(tank, MOVETYPE_NONE);
								}
								case 2:
								{
									buttons |= IN_ATTACK2;
								}
							}
						}
					}
				}
				else
				{
					if (bHasLeftRoundPoint(g_fConsumePosition[tank], fTankPos, g_iTankConsumeRaidus))
					{
						g_bInConsumePlace[tank] = false;
						// 出了消耗范围，重新进入
						if (g_bCanTankConsume[tank])
						{
							if (!g_bReturnConsumePlace[tank])
							{
								Logic_RunScript(COMMANDABOT_MOVE, g_fConsumePosition[tank][0], g_fConsumePosition[tank][1], g_fConsumePosition[tank][2], GetClientUserId(tank));
								g_bReturnConsumePlace[tank] = true;
							}
						}
					}
				}
			}
			// 消耗时生还者前压判断
			if (g_bCanTankConsume[tank])
			{
				int iNowSurvivorPercent = RoundToNearest(GetBossProximity() * 100.0);
				// 当前路程大于等于开始消耗的路程加给定路程，生还者前压，找位传送
				if (iNowSurvivorPercent >= g_iTankConsumeSurvivorProgress[tank] + g_iTeleportForwardPercent)
				{
					bool bHasFind;
					bHasFind = L4D_GetRandomPZSpawnPosition(iNearestTarget, ZC_TANK, 50, g_fTeleportPosition[tank]);
					if (bHasFind)
					{
						// 传送位置有效
						if ((g_fTeleportPosition[tank][0] != 0.0) && (g_fTeleportPosition[tank][1] != 0.0) && (g_fTeleportPosition[tank][2] != 0.0))
						{
							TeleportEntity(tank, g_fTeleportPosition[tank], NULL_VECTOR, NULL_VECTOR);
							g_bCanTankConsume[tank] = false;
							g_bCanTankAttack[tank] = true;
						}
					}
				}
			}
		}
		// 着火时，自动灭火
		if (GetEntProp(tank, Prop_Data, "m_fFlags") & FL_ONFIRE)
		{
			ExtinguishEntity(tank);
		}
		// 梯子上，阻止跳跃和蹲下
		if (GetEntityMoveType(tank) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	return Plugin_Continue;
}

// 重置坦克行动状态
void TankActionReset(int client)
{
	if (g_bCanTankConsume[client] && !g_bCanTankAttack[client])
	{
		if (g_iTankConsumeAction == 1)
		{
			SetEntityMoveType(client, MOVETYPE_CUSTOM);
		}
		g_bCanTankConsume[client] = false;
		g_fConsumePosition[client][0] = g_fConsumePosition[client][1] = g_fConsumePosition[client][2] = 0.0;
		Logic_RunScript(COMMANDABOT_RESET, GetClientUserId(client));
		g_bCanTankAttack[client] = true;
	}
}

void CheckCanTankConsume(int tank)
{
	int iInfectedCount = GetInfectedCount();
	if (iInfectedCount < g_iTankConsumeLimit)
	{
		// 被喷后，重新设置状态
		if (g_iVomitedPlayer >= g_iTankAttackVomitedNum)
		{
			g_bCanTankConsume[tank] = false;
			g_bCanTankAttack[tank] = true;
		}
		if (!g_bCanTankConsume[tank])
		{
			// 如果开启被喷吐后立刻攻击，尽管允许消耗，也可以攻击，未开启，则继续消耗
			if (g_bVomitCanInstantAttack)
			{
				if (g_iVomitedPlayer >= g_iTankAttackVomitedNum)
				{
					TankActionReset(tank);
					g_fConsumePosition[tank][0] = g_fConsumePosition[tank][1] = g_fConsumePosition[tank][2] = 0.0;
					if (!g_bVomitCanConsume[tank])
					{
						CreateTimer(g_fVomitAttackInterval, Timer_VomitAttackAgain, TIMER_FLAG_NO_MAPCHANGE);
						g_bVomitCanConsume[tank] = true;
					}
				}
				else
				{
					if (g_iTankConsumeLimitNum[tank] <= g_iTankConsumeNum)
					{
						DoConsume(tank);
						g_iTankConsumeLimitNum[tank] += 1;
						g_bVomitCanConsume[tank] = false;
					}
					else
					{
						TankActionReset(tank);
					}
				}
			}
			else
			{
				if (g_iTankConsumeLimitNum[tank] <= g_iTankConsumeNum)
				{
					DoConsume(tank);
					g_iTankConsumeLimitNum[tank] += 1;
				}
				else
				{
					TankActionReset(tank);
				}
			}
		}
	}
	else
	{
		TankActionReset(tank);
	}
}

// 进行消耗
void DoConsume(int client)
{
	if (IsAiTank(client))
	{
		// 血量，距离限制，血量小于等于消耗限制血量且距离大于强制压制距离允许消耗
		float fTankPos[3];
		GetClientAbsOrigin(client, fTankPos);
		int iNearestTarget = GetClosestSurvivor(fTankPos);
		if (IsSurvivor(iNearestTarget) && GetClientHealth(client) <= g_iTankConsumeHealthLimit && GetSurvivorDistance(fTankPos, iNearestTarget) > g_iTankForceAttackDistance)
		{
			// 记录当前生还路程
			int iNowSurvivorPercent = RoundToNearest(GetBossProximity() * 100.0);
			g_iTankConsumeSurvivorProgress[client] = iNowSurvivorPercent;
			// 设置状态
			g_bCanTankConsume[client] = true;
			g_bCanTankAttack[client] = false;
			// 找位
			bool bHasFind;
			for (int i = 0; i < g_iTankConsumeFindPositionCount; i++)
			{
				bHasFind = L4D_GetRandomPZSpawnPosition(iNearestTarget, g_iTankConsumeType, 50, g_fConsumePosition[client]);
				// 如果找到的位置大于给定高度，跳出，否则随机找位
				if (bHasFind)
				{
					if (g_fConsumePosition[client][2] >= g_fTankConsumeHeight)
					{
						break;
					}
				}
			}
			if (g_bDebugMod)
			{
				PrintToChatAll("\x05【提示】：找到了位置：\x04%.2f，%.2f，%.2f，正在前往", g_fConsumePosition[client][0], g_fConsumePosition[client][1], g_fConsumePosition[client][2]);
			}
			Logic_RunScript(COMMANDABOT_MOVE, g_fConsumePosition[client][0], g_fConsumePosition[client][1], g_fConsumePosition[client][2], GetClientUserId(client));
		}
	}
}

public Action Timer_VomitAttackAgain(Handle timer)
{
	g_iVomitedPlayer = 0;
}

// 选择目标时
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	if (IsAiTank(specialInfected))
	{
		int newtarget = -1;
		int iButtons = GetClientButtons(specialInfected);
		// 有目标的情况
		if (IsSurvivor(curTarget))
		{
			float fTankPos[3];
			GetClientAbsOrigin(specialInfected, fTankPos);
			// 如果目标正在被控或倒地，则选择新目标
			if (IsPinned(curTarget) || IsIncapped(curTarget))
			{
				newtarget = TargetChoose(g_iTankTarget, specialInfected, curTarget);
				if (IsSurvivor(newtarget))
				{
					curTarget = newtarget;
					return Plugin_Changed;
				}
				else
				{
					return Plugin_Continue;
				}
			}
			if (GetSurvivorDistance(fTankPos, curTarget) < 170)
			{
				switch (g_iTreeDetect)
				{
					case 1:
					{
						bool bCanSee = IsVisible(specialInfected, curTarget);
						if (!bCanSee)
						{
							g_iTreePlayer[specialInfected] = curTarget;
							// 开始记录绕树生还原始位置并选择新目标
							GetClientAbsOrigin(curTarget, g_fTreePlayerOriginPos);
							newtarget = TargetChoose(g_iTankTarget, specialInfected, g_iTreePlayer[specialInfected]);
						}
						if (IsSurvivor(newtarget))
						{
							curTarget = newtarget;
							return Plugin_Changed;
						}
						else
						{
							return Plugin_Continue;
						}
					}
					// 搞传送
					case 2:
					{
						float fNewTargetPos[3], fNewTargetAngles[3];
						GetClientAbsOrigin(curTarget, fNewTargetPos);	GetClientEyeAngles(curTarget, fNewTargetAngles);
						TeleportEntity(specialInfected, fNewTargetPos, fNewTargetAngles, NULL_VECTOR);
						CPrintToChat(curTarget, "{R}<Tank>：{G}喜欢绕树是吧？");
						return Plugin_Continue;
					}
				}
			}
			else
			{
				// 绕树生还突然跑出来接近坦克，如果有绕树情况，则选择treeTarget，不执行此段，坦克选择新目标后，绕树生还突然追坦克，清空绕树保存目标重新选择
				if (IsSurvivor(g_iTreePlayer[specialInfected]))
				{
					float fTreePlayerNewPos[3];
					GetClientAbsOrigin(g_iTreePlayer[specialInfected], fTreePlayerNewPos);
					// PrintToChatAll("%d，半径%d", RoundToNearest((g_fTreePlayerOriginPos[0] - fTreePlayerNewPos[0]) * (g_fTreePlayerOriginPos[0] - fTreePlayerNewPos[0]) + (g_fTreePlayerOriginPos[1] - fTreePlayerNewPos[1]) * (g_fTreePlayerOriginPos[1] - fTreePlayerNewPos[1])), 225 * 225);
					if (!bHasLeftRoundPoint(g_fTreePlayerOriginPos, fTreePlayerNewPos, 225))
					{
						// 还在绕树啊？
						newtarget = TargetChoose(g_iTankTarget, specialInfected, g_iTreePlayer[specialInfected]);
						if (IsSurvivor(newtarget))
						{
							curTarget = newtarget;
							return Plugin_Changed;
						}
						else
						{
							return Plugin_Continue;
						}
					}
					else
					{
						if (GetSurvivorDistance(fTankPos, g_iTreePlayer[specialInfected]) < g_iTreeNewTarget)
						{
							SetEntProp(specialInfected, Prop_Data, "m_nButtons", iButtons |= IN_BACK);
							SetEntProp(specialInfected, Prop_Data, "m_nButtons", iButtons |= IN_FORWARD);
							SetEntProp(specialInfected, Prop_Data, "m_nButtons", iButtons |= IN_JUMP);
							// 检测绕树目标与坦克之间的距离，终于出来了
							g_iTreePlayer[specialInfected] = -1;
							for (int i = 0; i < 3; i++)
							{
								g_fTreePlayerOriginPos[i] = 0.0;
							}
							newtarget = TargetChoose(g_iTankTarget, specialInfected);
							if (IsSurvivor(newtarget))
							{
								curTarget = newtarget;
								return Plugin_Changed;
							}
							else
							{
								return Plugin_Continue;
							}
						}
					}
				}
				// 绕树保存目标为-1时的情况，没有人绕树，选择新目标，Tank刷新初始目标
				else
				{
					curTarget = TargetChoose(g_iTankTarget, specialInfected);
				}
			}
			// 坦克距离新目标小于g_iTreeNewTarget的距离时，重置绕树目标
			if (curTarget != g_iTreePlayer[specialInfected] && GetSurvivorDistance(fTankPos, curTarget) < g_iTreeNewTarget)
			{
				g_iTreePlayer[specialInfected] = -1;
			}
		}
	}
	return Plugin_Continue;
}

// From：Sorallll（Ai_Tank.smx）：https://github.com/umlka/l4d2/blob/main/AI_HardSI/ai_tank.sp
public Action L4D_OnGetRunTopSpeed(int target, float &retVal)
{
	g_fRunTopSpeed[target] = retVal;
	return Plugin_Continue;
}

public Action L4D_TankRock_OnRelease(int tank, int rock, float vecPos[3], float vecAng[3], float vecVel[3], float vecRot[3])
{
	int iTarget = GetClientAimTarget(tank, true);
	if (iTarget > 0)
	{
		float fTargetPos[3], fRockPos[3], fVectors[3];
		GetClientAbsOrigin(iTarget, fTargetPos);
		GetClientAbsOrigin(tank, fRockPos);
		float fDelta = GetVectorDistance(fRockPos, fTargetPos) / GetConVarFloat(g_hTankThrowForce) * PLAYER_HEIGHT;
		fTargetPos[2] += fDelta;
		while(fDelta < PLAYER_HEIGHT)
		{
			if (!WillHitWll(tank, rock, -1, fTargetPos))
			{
				break;
			}
			fDelta += 10.0;
			fTargetPos[2] += 10.0;
		}
		fDelta = fTargetPos[2] - fRockPos[2];
		if (fDelta > PLAYER_HEIGHT)
		{
			fTargetPos[2] += fDelta / PLAYER_HEIGHT * 10.0;
		}
		GetClientEyePosition(tank, fRockPos);
		MakeVectorFromPoints(fRockPos, fTargetPos, fVectors);
		GetVectorAngles(fVectors, fTargetPos);
		TeleportEntity(rock, NULL_VECTOR, fTargetPos, NULL_VECTOR);
		static float vLength;
		vLength = GetVectorLength(fVectors);
		vLength = vLength > GetConVarFloat(g_hTankThrowForce) ? vLength : GetConVarFloat(g_hTankThrowForce);
		NormalizeVector(fVectors, fVectors);
		ScaleVector(fVectors, vLength + g_fRunTopSpeed[iTarget]);
		TeleportEntity(rock, fVectors, NULL_VECTOR, NULL_VECTOR);
	}
}

bool WillHitWll(int iTank, int iEntity, int iTarget = -1, const float vEndPos[3] = NULL_VECTOR)
{
	static float fSource[3], fTargetPos[3];
	GetClientEyePosition(iTank, fSource);
	// 无目标的情况，目标位置等于中止位置
	if (iTarget == -1)
	{
		fTargetPos = vEndPos;
	}
	else
	{
		GetClientEyePosition(iTarget, fTargetPos);
	}
	static float vMins[3], vMaxs[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vMaxs);
	static bool bHit;
	static Handle hTrace;
	// 从坦克视角位置到目标视角位置发射射线，撞到实体返回真
	hTrace = TR_TraceHullFilterEx(fSource, fTargetPos, vMins, vMaxs, MASK_SOLID, bTraceEntityFilter);
	bHit = TR_DidHit(hTrace);
	delete hTrace;
	return bHit;
}

bool BhopWillHitWall(int client, float fDistance)
{
	float fTankEyePos[3], fTankEyeAngles[3];
	GetClientEyePosition(client, fTankEyePos);
	GetClientEyeAngles(client, fTankEyeAngles);
	bool bHit = false;
	Handle hTrace;
	hTrace = TR_TraceRayFilterEx(fTankEyePos, fTankEyeAngles, MASK_SOLID, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(hTrace))
	{
		float fHitPos[3], fCollisonDistance;
		TR_GetEndPosition(fHitPos, hTrace);
		fCollisonDistance = GetVectorDistance(fTankEyePos, fHitPos);
		int hit = TR_GetEntityIndex(hTrace);
		char sClassname[16];
		GetEntityClassname(hit, sClassname, sizeof(sClassname));
		if ((sClassname[0] == 'w') && fCollisonDistance <= fDistance)
		{
			bHit = true;
		}
	}
	delete hTrace;
	return bHit;
}

// **************
//		事件
// *************
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsAiTank(victim))
	{
		if (g_bCanTankConsume[victim])
		{
			if (GetRandomInt(1, 100) <= g_iTankConsumeDamagePercent)
			{
				return Plugin_Continue;
			}
			else
			{
				damage = 0.0;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public void evt_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiTank(client))
	{
		TankInitialization(client);
		for (int index = 0; index < 8; index++)
		{
			g_fDelay[client][index] = GetGameTime();
		}
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		if (g_bTankConsume)
		{
			CreateTimer(1.5, Timer_CheckCanConsume, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_CheckCanConsume(Handle timer, int client)
{
	if (g_bIsFirstConsumeCheck[client])
	{
		CheckCanTankConsume(client);
		g_bIsFirstConsumeCheck[client] = false;
	}
}

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsAiTank(client))
	{
		TankInitialization(client);
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void evt_PlayerNowIt(Event event, const char[] name, bool dontBroadcast)
{
	int iTank = FindTank();
	if (iTank > 0)
	{
		// 坦克可以进行消耗或正在消耗，触发玩家被喷事件，计算被喷玩家数量
		if (g_bCanTankConsume[iTank])
		{
			g_iVomitedPlayer += 1;
		}
	}
}

// 坦克初始化
void TankInitialization(int client)
{
	g_iTreePlayer[client] = -1;
	g_bCanTankConsume[client] = false;
	g_bInConsumePlace[client] = false;
	g_bCanTankAttack[client] = true;
	g_bReturnConsumePlace[client] = false;
	g_bVomitCanConsume[client] = false;
	g_fConsumePosition[client][0] = g_fConsumePosition[client][1] = g_fConsumePosition[client][2] = 0.0;
	g_fTeleportPosition[client][0] = g_fTeleportPosition[client][1] = g_fTeleportPosition[client][2] = 0.0;
	g_iTankConsumeSurvivorProgress[client] = 0;
	g_iTankConsumeLimitNum[client] = 0;
	g_bIsFirstConsumeCheck[client] = true;
}

// **************
//		方法
// *************
bool IsAiTank(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK && GetEntProp(client, Prop_Send, "m_isGhost") != 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

// 是否离开树检测，坦克转换目标，记录绕树生还原始位置向量，以原始向量为起点画圆，将绕树生还后续位置与原始向量作的圆对比，到圆心的距离，是否大于给定半径（树宽）
//  if (!((x - x1)*(x - x1) + (y - y1)*(y - y1) > r*r)) return true; else return false;
bool bHasLeftRoundPoint(float originPos[3], float nowPos[3], int radius)
{
	if (RoundToNearest((originPos[0] - nowPos[0]) * (originPos[0] - nowPos[0]) + (originPos[1] - nowPos[1]) * (originPos[1] - nowPos[1])) > radius * radius)
	{
		return true;
	}
	else
	{
		return false;
	}
}

// 计算加速后的向量
float UpdatePosition(int tank, int target, float fForce)
{
	float fBuffer[3], fTankPos[3], fTargetPos[3];
	GetClientAbsOrigin(tank, fTankPos);	GetClientAbsOrigin(target, fTargetPos);
	SubtractVectors(fTargetPos, fTankPos, fBuffer);
	NormalizeVector(fBuffer, fBuffer);
	ScaleVector(fBuffer, fForce);
	return fBuffer;
}

// 连跳操作
bool ClientPush(int client, float fForwardVec[3])
{
	float fCurVelVec[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fCurVelVec);
	AddVectors(fCurVelVec, fForwardVec, fCurVelVec);
	// 判断下一帧的位置是否会坠落，再进行传送
	if (DontFall(client, fCurVelVec))
	{
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fCurVelVec);
		return true;
	}
	return false;
}

bool DoBhop(int client, int &buttons, float fForwardVec[3])
{
	static bool bJumped;
	bJumped = false;
	if (buttons & IN_FORWARD || buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		if (ClientPush(client, fForwardVec))
		{
			bJumped = true;
		}
	}
	return bJumped;
}

bool DontFall(int client, const float fVelocity[3])
{
	static float vPos[3], vEnd[3];
	GetClientAbsOrigin(client, vPos);
	// 当前位置加当前速度，等于下一帧理论位置，保存在vEnd里
	AddVectors(vPos, fVelocity, vEnd);
	vPos[2] += OBSTACLE_HEIGHT;
	static float vMins[3], vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);
	static bool bHit;
	static Handle hTrace;
	static float vEndPos[3];
	bHit = false;
	vEnd[2] += OBSTACLE_HEIGHT;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	vEnd[2] -= OBSTACLE_HEIGHT;
	// 当前位置与射线的中止位置距离小于64.0，继续连跳可能会撞墙，返回false
	if (TR_DidHit(hTrace))
	{
		bHit = true;
		TR_GetEndPosition(vEndPos, hTrace);
		if (GetVectorDistance(vPos, vEndPos) < 64.0)
		{
			delete hTrace;
			return false;
		}
	}
	delete hTrace;
	if (!bHit)
	{
		// 设置vEndPos为下一帧理论位置
		vEndPos = vEnd;
	}
	// 向下射线检测，将vDown的z坐标设置为下一帧理论位置向下-100000.0的位置
	static float vDown[3];
	vDown[0] = vEndPos[0];
	vDown[1] = vEndPos[1];
	vDown[2] = vEndPos[2] - 100000.0;
	// 创建射线，从下一帧理论位置指向vDown的位置
	hTrace = TR_TraceHullFilterEx(vEndPos, vDown, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	if (TR_DidHit(hTrace))
	{
		// 将hTrace的中止位置保存于vEnd中
		TR_GetEndPosition(vEnd, hTrace);
		// 如果下一帧的理论位置（高位）z坐标减去射线终止位置的z坐标（低位）大于120，则判定会坠落，返回false
		if (vEndPos[2] - vEnd[2] > 120.0)
		{
			delete hTrace;
			return false;
		}
		static int iEntity;
		// 检测是否非玩家实体
		if ((iEntity = TR_GetEntityIndex(hTrace)) > MaxClients)
		{
			// 判断低位的实体是否会对坦克造成伤害
			static char sClassname[13];
			GetEdictClassname(iEntity, sClassname, sizeof(sClassname));
			if (strcmp(sClassname, "trigger_hurt") == 0)
			{
				delete hTrace;
				return false;
			}
		}
		delete hTrace;
		return true;
	}
	delete hTrace;
	return false;
}

bool bTraceEntityFilter(int entity, int contentsMask)
{
	if (entity <= MaxClients)
	{
		return false;
	}
	else
	{
		static char sClassname[9];
		GetEntityClassname(entity, sClassname, sizeof(sClassname));
		if (sClassname[0] == 'i' || sClassname[0] == 'w')
		{
			if (strcmp(sClassname, "infected") == 0 || strcmp(sClassname, "witch") == 0)
			{
				return false;
			}
		}
	}
	return true;
}

// 坦克目标选择
int TargetChoose(int iMethod, int iTank, int iSpecificClient = -1)
{
	int iTarget = -1;
	switch (iMethod)
	{
		// 第一种情况，选择最近生还者
		case 1:
		{
			float mindistance = 100000.0, selfpos[3], targetpos[3];
			GetClientAbsOrigin(iTank, selfpos);
			for (int client = 1; client <= MaxClients; ++client)
			{
				if (IsSurvivor(client) && IsPlayerAlive(client) && client != iSpecificClient && !IsIncapped(client))
				{
					GetClientAbsOrigin(client, targetpos);
					float distance = GetVectorDistance(selfpos, targetpos);
					if (distance < mindistance)
					{
						mindistance = distance;
						iTarget = client;
					}
				}
			}
		}
		// 第二种情况，选择血量最少的生还者
		case 2:
		{
			int minHealth = 100;
			float selfpos[3], targetpos[3];
			GetClientAbsOrigin(iTank, selfpos);
			for (int client = 1; client <= MaxClients; ++client)
			{
				if (IsSurvivor(client) && IsPlayerAlive(client) && client != iSpecificClient && !IsIncapped(client))
				{
					GetClientAbsOrigin(client, targetpos);
					int iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
					if (iHealth < minHealth)
					{
						minHealth = iHealth;
						iTarget = client;
					}
				}
			}
		}
		// 第三种情况，选择血量最多的生还者
		case 3:
		{
			int maxHealth = 0;
			float selfpos[3], targetpos[3];
			GetClientAbsOrigin(iTank, selfpos);
			for (int client = 1; client <= MaxClients; ++client)
			{
				if (IsSurvivor(client) && IsPlayerAlive(client) && client != iSpecificClient && !IsIncapped(client))
				{
					GetClientAbsOrigin(client, targetpos);
					int iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
					if (iHealth > maxHealth)
					{
						maxHealth = iHealth;
						iTarget = client;
					}
				}
			}
		}
	}
	return iTarget;
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

// 是否两者可见？
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

bool traceFilter(int entity, int mask, int self)
{
	return entity != self;
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

// 获取生还距离
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

// 有目的性选择最近生还
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

int GetInfectedCount()
{
	int iInfectedCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_TANK)
		{
			iInfectedCount += 1;
		}
	}
	return iInfectedCount;
}

// From：Shadowysn，https://forums.alliedmods.net/showthread.php?t=261566&page=8
void Logic_RunScript(const char[] sCode, any ...) 
{
	int iScriptLogic = FindEntityByTargetname(-1, PLUGIN_SCRIPTLOGIC);
	if (!iScriptLogic || !IsValidEntity(iScriptLogic))
	{
		iScriptLogic = CreateEntityByName("logic_script");
		DispatchKeyValue(iScriptLogic, "targetname", PLUGIN_SCRIPTLOGIC);
		DispatchSpawn(iScriptLogic);
	}
	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

int FindEntityByTargetname(int index, const char[] findname)
{
	for (int i = index; i < GetMaxEntities(); i++)
	{
		if (IsValidEntity(i))
		{
			char name[128];
			GetEntPropString(i, Prop_Data, "m_iName", name, sizeof(name));
			if (StrEqual(name, findname, false))
			{
				return i;
			}
		}
	}
	return -1;
}

// 禁止低抛
public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if (sequence == SEQUENCE_UNDERHAND)
	{
		sequence = GetRandomInt(0, 1) ? SEQUENCE_ONEHAND : SEQUENCE_TWOHAND;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// 检测特感团队是否有坦克
int FindTank()
{
	int iTank = -1;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsAiTank(client))
		{
			iTank = client;
		}
	}
	return iTank;
}

// 计算生还者在地图上的路程
float GetBossProximity()
{
	float proximity = GetMaxSurvivorCompletion() + g_hVsBossFlowBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();
	return (proximity > 1.0) ? 1.0 : proximity;
}

float GetMaxSurvivorCompletion()
{
	float flow = 0.0, tmp_flow = 0.0, origin[3];
	Address pNavArea;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			GetClientAbsOrigin(i, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null)
			{
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = (flow > tmp_flow) ? flow : tmp_flow;
			}
		}
	}
	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}

void DelayStart(int client, int number)
{
	g_fDelay[client][number] = GetGameTime();
}

bool DelayExpired(int client, int number, float delay)
{
	return view_as<bool>(GetGameTime() - g_fDelay[client][number] > delay);
}