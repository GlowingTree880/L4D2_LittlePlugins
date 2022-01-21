#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name 			= "【JockeyRideSpeed】猴子骑人加速",
	author 			= "夜羽真白",
	description 	= "",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

ConVar g_hPreSpeed, g_hPostSpeed;
float g_fPreSpeed, g_fPostSpeed;

public void OnPluginStart()
{
	g_hPreSpeed = CreateConVar("RideSpeedMutiplier", "1.50", "jockey骑人时相对于被骑的生还原本速度的加速倍数", FCVAR_NOTIFY, true, 1.0);
	g_hPostSpeed = CreateConVar("RideEndSpeedMutiplier", "1.0", "jockey骑乘完毕后将被骑的生还恢复的速度倍数", FCVAR_NOTIFY, true, 1.0);
	// AddChangeHook
	g_hPreSpeed.AddChangeHook(ConVarChanged_Cvars);
	g_hPostSpeed.AddChangeHook(ConVarChanged_Cvars);
	// HookEvents
	HookEvent("jockey_ride", evt_Ride);
	HookEvent("jockey_ride_end", evt_RideEnd);
	// GetCvars
	GetCvars();
}

void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fPreSpeed = g_hPreSpeed.FloatValue;
	g_fPostSpeed = g_hPostSpeed.FloatValue;
}

public void evt_Ride(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	SetSpeed(victim, g_fPreSpeed);
}

public void evt_RideEnd(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	SetSpeed(victim, g_fPostSpeed);
}

void SetSpeed(int client, float speed)
{
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", speed);
}