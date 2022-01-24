#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name 			= "China-QingGong：中国轻功",
	author 			= "夜羽真白",
	description 	= "中 国 轻 功（按住蹲下+空格或方向键将会有增强跳跃或推动效果）",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

// ConVar
ConVar g_hEnable, g_hDuckTime, g_hCoolDownTime, g_hUpDistance, g_hDirectionDistance, g_hDuckUpSpeed;
// Bools
bool g_bEnable, g_bInCoolDown[MAXPLAYERS + 1] = false;
// Floats
float g_fDuckTime, g_fCoolDownTime, g_fUpDistance, g_fDirectionDistance, g_fDuckUpSpeed, g_fKeyPressedTime[MAXPLAYERS + 1], g_fLastTime[MAXPLAYERS + 1], g_fPressedTime[MAXPLAYERS + 1];

#define TEAM_SURVIVOR 2
#define PLAYER_HEIGHT 72.0

enum CustomMoveType
{
	MoveUp,
	MoveDirection
};

public void OnPluginStart()
{
	// CreateConVar
	g_hEnable = CreateConVar("QG_Enable", "1", "是否开启中国轻功功能", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hDuckTime = CreateConVar("QG_DuckTime", "0.5", "需要按住蹲下键多少秒后按空格或方向键才能施法", FCVAR_NOTIFY, true, 0.0);
	g_hCoolDownTime = CreateConVar("QG_CoolDownTime", "5.0", "施一次法之后的CD时间", FCVAR_NOTIFY, true, 0.0);
	g_hUpDistance = CreateConVar("QG_UpSpeed", "150.0", "按住蹲下+空格将会向上飞多高（距离）", FCVAR_NOTIFY, true, 0.0);
	g_hDuckUpSpeed = CreateConVar("QG_DuckUpSpeed", "20.0", "按住蹲下键后如果生还者的行走速度小于这个值再按空格，则视为垂直跳跃", FCVAR_NOTIFY, true, 0.0);
	g_hDirectionDistance = CreateConVar("QG_DirectionSpeed", "10.0", "按住蹲下+方向键会将玩家加速的倍数（倍数）", FCVAR_NOTIFY, true, 0.0);
	// HookEvent
	HookEvent("round_start", evt_RoundStart);
	HookEvent("round_end", evt_RoundEnd);
	// AddChangeHook
	g_hEnable.AddChangeHook(ConVarChanged_Cvars);
	g_hDuckTime.AddChangeHook(ConVarChanged_Cvars);
	g_hCoolDownTime.AddChangeHook(ConVarChanged_Cvars);
	g_hUpDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hDuckUpSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_hDirectionDistance.AddChangeHook(ConVarChanged_Cvars);
	// GetCvars
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnable = g_hEnable.BoolValue;
	g_fDuckTime = g_hDuckTime.FloatValue;
	g_fCoolDownTime = g_hCoolDownTime.FloatValue;
	g_fUpDistance = g_hUpDistance.FloatValue;
	g_fDuckUpSpeed = g_hDuckUpSpeed.FloatValue;
	g_fDirectionDistance = g_hDirectionDistance.FloatValue;
}

// ***** 事件 *****
public void evt_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetStatus();
}

public void evt_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetStatus();
}

void ResetStatus()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		g_fKeyPressedTime[client] = 0.0;
		g_fLastTime[client] = 0.0;
		g_fPressedTime[client] = 0.0;
		g_bInCoolDown[client] = false;
	}
}

// ***** 开始 施法 *****
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float eyeAngles[3], int& weapon)
{
	// 是有效玩家
	if (IsValidPlayer(client))
	{
		// PrintToChatAll("状态：%b", g_bInCoolDown[client]);
		float fTime = GetEngineTime();
		float fInterval = fTime - g_fLastTime[client];
		g_fLastTime[client] = fTime;
		// Interval
		if (fInterval < 0.0)
		{
			fInterval = 0.01;
		}
		else if (fInterval > 1.0)
		{
			fInterval = 0.01;
		}
		bool bPress = false;
		float fLastPressTime = g_fKeyPressedTime[client];
		int iFlags = GetEntityFlags(client);
		if ((buttons & IN_DUCK) && (iFlags & FL_DUCKING) && (iFlags & FL_ONGROUND))
		{
			bPress = true;
		}
		else if (iFlags & ~FL_DUCKING)
		{
			g_fPressedTime[client] = 0.0;
		}
		// 计算蹲下键按下时间
		if (bPress)
		{
			g_fKeyPressedTime[client] = fTime;
			float fDuration = fTime - fLastPressTime;
			fDuration *= 10.0;
			if (fDuration < 0.8)
			{
				fDuration = 0.8;
			}
			else if (fDuration > 2.0)
			{
				fDuration = 2.0;
			}
			fDuration = (2.0 - fDuration) / (2.0 - 0.8);
			if (fDuration > 0.0)
			{
				// 累计，/= 1/2，化为秒
				g_fPressedTime[client] += fDuration / 30.0;
			}
			// 施法
			if (g_fPressedTime[client] > g_fDuckTime)
			{
				if (g_bEnable)
				{
					// 技能非冷却状态才可使用
					if (!g_bInCoolDown[client])
					{
						float fVelocity[3], fCurrentSpeed;
						GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
						fCurrentSpeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));
						PrintHintText(client, "中国轻功已蓄力完成，请按空格或方向键+空格键开始施法");
						// 检测按键，蹲下时生还者速度小于g_fDuckUpSpeed，则视为垂直跳跃
						if ((buttons & IN_DUCK) && (buttons & IN_JUMP) && fCurrentSpeed < g_fDuckUpSpeed)
						{
							CustomMove(MoveUp, client);
							g_bInCoolDown[client] = true;
							CreateTimer(g_fCoolDownTime, Timer_CoolDown, client, TIMER_FLAG_NO_MAPCHANGE);
						}
						else if (((buttons & IN_DUCK) && (buttons & IN_FORWARD)) || ((buttons & IN_DUCK) && (buttons & IN_BACK)) || ((buttons & IN_DUCK) && (buttons & IN_MOVELEFT)) || ((buttons & IN_DUCK) && (buttons & IN_MOVERIGHT)))
						{
							if (buttons & IN_JUMP)
							{
								CustomMove(MoveDirection, client);
								g_bInCoolDown[client] = true;
								CreateTimer(g_fCoolDownTime, Timer_CoolDown, client, TIMER_FLAG_NO_MAPCHANGE);
							}
						}
					}
					// 正在冷却
					else
					{
						PrintHintText(client, "中国轻功技能正在冷却中，请等待");
					}
				}
				else
				{
					PrintHintText(client, "中国轻功功能目前已被禁用，请使用 QG_Enable 1 启用");
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_CoolDown(Handle timer, int client)
{
	g_bInCoolDown[client] = false;
}

void CustomMove(CustomMoveType type, int client)
{
	float fSelfPos[3];
	GetClientAbsOrigin(client, fSelfPos);
	switch (type)
	{
		// 向上跳的情况，如果直接在地上向上跳，m_vecVelocity, m_vecAbsVelocity z速度为0.0，无法加速
		case MoveUp:
		{
			// 获取玩家视线角度
			float fEyeAngles[3];
			GetClientEyeAngles(client, fEyeAngles);
			fEyeAngles[0] = -90.0;
			static Handle hTrace;
			hTrace = TR_TraceRayFilterEx(fSelfPos, fEyeAngles, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TracerayFilter, client);
			if (TR_DidHit(hTrace))
			{
				float fEndPos[3];
				TR_GetEndPosition(fEndPos, hTrace);
				// PrintToChatAll("\x05【Debug】：玩家坐标：\x04%.2f，%.2f，%.2f", fSelfPos[0], fSelfPos[1], fSelfPos[2]);
				// PrintToChatAll("\x05【Debug】：射线终点：\x04%.2f，%.2f，%.2f", fEndPos[0], fEndPos[1], fEndPos[2]);
				// PrintToChatAll("\x05【Debug】相减结果：\x04%.2f", fEndPos[2] - fSelfPos[2]);
				// 取射线终点z坐标减去玩家位置z坐标减去传送高度，小于一个玩家身高，则减去一个玩家身高再传送
				if (fEndPos[2] - fSelfPos[2] - g_fUpDistance < PLAYER_HEIGHT)
				{
					// PrintToChatAll("\x05【Debug】：两点间距离：\x04%.2f", GetVectorDistance(fSelfPos, fEndPos));
					fEndPos[2] -= PLAYER_HEIGHT;
					TeleportEntity(client, fEndPos, NULL_VECTOR, NULL_VECTOR);
				}
				else
				{
					fSelfPos[2] += g_fUpDistance;
					TeleportEntity(client, fSelfPos, NULL_VECTOR, NULL_VECTOR);
				}
				delete hTrace;
			}
			delete hTrace;
		}
		case MoveDirection:
		{
			float fVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
			if (fVelocity[2] >= 0.0)
			{
				for (int i = 0; i < 3; i++)
				{
					fVelocity[i] *= g_fDirectionDistance;
				}
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
				SetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
			}
		}
	}
}

bool TracerayFilter(int entity, int contentsMask, int self)
{
	return entity != self;
}

// 玩家离开，将他位置的冷却状态设置为false，防止下一个加入的玩家无法使用
public void OnClientDisconnect(int client)
{
	if (IsValidPlayer(client))
	{
		g_bInCoolDown[client] = false;
	}
}

// ***** 方法 *****
bool IsValidPlayer(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_SURVIVOR && !IsFakeClient(client) && !IsIncapped(client))
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