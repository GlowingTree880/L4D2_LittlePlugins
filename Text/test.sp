#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>

#define GAMEDATA "test"

Address aRetreat = Address_Null;
static int iOriginalBytes_Retreat[2] = {-1, ...};

public Plugin myinfo = 
{
	name 			= "test",
	author 			= "夜羽真白",
	description 	= "",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

public void OnPluginStart()
{
	GameData gd_Retreat = FetchGameData("test");
	if (gd_Retreat == null)
	{
		PrintToServer("无法找到 gamedata 文件");
	}
	aRetreat = gd_Retreat.GetAddress("ActionInitialized_TB");
	if (aRetreat != Address_Null)
	{
		int iOffset_Retreat = gd_Retreat.GetOffset("RetreatOffset");
		if (iOffset_Retreat != -1)
		{
			for (int i = 0; i < iOffset_Retreat; i++)
			{
				PrintToServer("原字节：0x%X", LoadFromAddress(aRetreat += view_as<Address>(i), NumberType_Int8));
			}
			int iByte = LoadFromAddress(aRetreat + view_as<Address>(iOffset_Retreat), NumberType_Int8);
			if (iByte == 0x75)
			{
				aRetreat += view_as<Address>(iOffset_Retreat);
				PrintToServer("偏移位置原字节：0x%X", LoadFromAddress(aRetreat, NumberType_Int8));
				for (int i = 0; i < 2; i++)
				{
					iOriginalBytes_Retreat[i] = LoadFromAddress(aRetreat + view_as<Address>(i), NumberType_Int8);
				}
				StoreToAddress(aRetreat, 0x79, NumberType_Int8);
				PrintToServer("修改特感逃跑行为成功");
			}
			else
			{
				PrintToServer("偏移错误");
			}
		}
		else
		{
			PrintToServer("无法找到偏移");
		}
	}
	else
	{
		PrintToServer("无法找到签名地址");
	}
	delete gd_Retreat;
}

public void OnPluginEnd()
{
	if (aRetreat == Address_Null)
	{
		return;
	}
	for (int i = 0; i < 2; i++)
	{
		StoreToAddress(aRetreat + view_as<Address>(i), iOriginalBytes_Retreat[i], NumberType_Int8);
		iOriginalBytes_Retreat[i] = -1;
	}
	PrintToServer("已将特感行为复原");
}

GameData FetchGameData(const char[] file)
{
	char sFilePath[128];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "gamedata/%s.txt", file);
	if (!FileExists(sFilePath))
	{
		SetFailState("无法找到 %s 文件位于 gamedata 文件夹中", file);
	}
	else
	{
		PrintToServer("读取 %s gamedata 文件成功", file);
	}
	return new GameData(file);
}