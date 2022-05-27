enum PlayerTeam
{
	TEAM_SPECTATOR = 1,
	TEAM_SURVIVOR,
	TEAM_INFECTED
};

enum ZombieClass
{
	ZC_SMOKER = 1,
	ZC_BOOMER,
	ZC_HUNTER,
	ZC_SPITTER,
	ZC_JOCKEY,
	ZC_CHARGER,
	ZC_WITCH,
	ZC_TANK
};

// 判断是否有效玩家 id，有效返回 true，无效返回 false
stock bool IsValidClient(int client)
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

// 判断生还者是否有效，有效返回 true，无效返回 false
stock bool IsValidSurvivor(int client)
{
	if (IsValidClient(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR))
	{
		return true;
	}
	else
	{
		return false;
	}
}

// 判断特感是否有效，有效返回 true，无效返回 false
stock bool IsValidInfected(int client)
{
	if (IsValidClient(client) && GetClientTeam(client) == view_as<int>(TEAM_INFECTED))
	{
		return true;
	}
	else
	{
		return false;
	}
}

// 判断是否 Bot 特感，是返回 true，否返回 false
stock bool IsBotInfected(int client)
{
	if (IsValidInfected(client) && IsFakeClient(client))
	{
		return true;
	}
	else
	{
		return false;
	}
}

// 获取特感类型，成功返回特感类型，失败返回 0
stock int GetInfectedClass(int client)
{
	if (IsValidInfected(client))
	{
		return GetEntProp(client, Prop_Send, "m_zombieClass");
	}
	else
	{
		return 0;
	}
}

// 判断特感是否处于灵魂状态，是返回 1，否返回 0，无效返回 -1
stock int IsInGhostState(int client)
{
	if (IsValidInfected(client))
	{
		return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
	}
	else
	{
		return -1;
	}
}

// 判断玩家是否倒地，倒地返回 true，未倒地返回 false
stock bool IsClientIncapped(int client)
{
	if (IsValidClient(client))
	{
		return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
	}
	else
	{
		return false;
	}
}

// 判断玩家是否被控，被控返回 true，未被控返回 false
stock bool IsClientPinned(int client)
{
	bool survivor_ispinned = false;
	if (IsValidSurvivor(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 || GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0
			|| GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		{
			survivor_ispinned = true;
		}
	}		
	return survivor_ispinned;
}

// 随机获取一个未死亡，未被控，未倒地的生还者，如有则返回生还者 id，无则返回 0
stock int GetRandomMobileSurvivor()
{
	int[] survivor_array = new int[GetConVarInt(FindConVar("survivor_limit"))];
	int survivor_index = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR) && !IsClientPinned(client) && !IsClientIncapped(client))
		{
			survivor_array[survivor_index] = client;
			survivor_index += 1;
		}
	}
	if (survivor_index > 0)
	{
		return survivor_array[GetRandomInt(0, survivor_index - 1)];
	}
	else
	{
		return 0;
	}
}

// 获取距离某玩家最近的有效（未死亡，未倒地，未被控）生还者，如有则返回生还者 id，无则返回 0
stock int GetClosetMobileSurvivor(int client, int exclude_client = -1)
{
	if (IsValidClient(client))
	{
		float self_pos[3] = {0.0}, target_pos[3] = {0.0};
		int closet_survivor = GetRandomMobileSurvivor();
		if (IsValidSurvivor(closet_survivor))
		{
			GetClientAbsOrigin(client, self_pos);
			GetClientAbsOrigin(closet_survivor, target_pos);
			int target_distance = RoundToNearest(GetVectorDistance(self_pos, target_pos));
			for (int newtarget = 1; newtarget <= MaxClients; newtarget++)
			{
				if (IsValidSurvivor(newtarget) && IsPlayerAlive(newtarget) && !IsClientIncapped(client) &&!IsClientPinned(client) && newtarget != exclude_client)
				{
					GetClientAbsOrigin(newtarget, target_pos);
					int newtarget_distance = RoundToNearest(GetVectorDistance(self_pos, target_pos));
					if (target_distance < 0)
					{
						target_distance = newtarget_distance;
						closet_survivor = newtarget;
					}
					else if (newtarget_distance < target_distance)
					{
						target_distance = newtarget_distance;
						closet_survivor = newtarget;
					}
				}
			}
			return closet_survivor;
		}
		else if (closet_survivor == 0)
		{
			return 0;
		}
	}
	return 0;
}

// 获取某玩家到最近或指定生还者的距离，如果存在有效最近或指定生还者则返回距离，无则返回 -1
stock int GetClosetSurvivorDistance(int client, int specific_survivor = -1)
{
	if (IsValidClient(client))
	{
		float self_pos[3] = {0.0}, target_pos[3] = {0.0};
		int target_survivor = -1;
		GetClientAbsOrigin(client, self_pos);
		if (IsValidSurvivor(specific_survivor))
		{
			target_survivor = specific_survivor;
		}
		else
		{
			target_survivor = GetClosetMobileSurvivor(client);
		}
		if (IsValidSurvivor(target_survivor))
		{
			GetEntPropVector(target_survivor, Prop_Send, "m_vecOrigin", target_pos);
			return RoundToNearest(GetVectorDistance(self_pos, target_pos));
		}
		else
		{
			return -1;
		}
	}
	else
	{
		return -1;
	}
}

// 获取生还者数量，可指定是否包含 bot 和死亡的玩家
stock int GetSurvivorCount(bool include_bot, bool include_death)
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidSurvivor(client) && include_bot && include_death)
		{
			count += 1;
		}
		else if (IsValidSurvivor(client) && !include_bot && !include_death)
		{
			if (!IsFakeClient(client) && IsPlayerAlive(client))
			{
				count += 1;
			}
		}
		else if (IsValidSurvivor(client) && !include_bot && include_death)
		{
			if (!IsFakeClient(client))
			{
				count += 1;
			}
		}
		else if (IsValidSurvivor(client) && include_bot && !include_death)
		{
			if (IsPlayerAlive(client))
			{
				count += 1;
			}
		}
	}
	return count;
}

// 向量复制
stock void CopyVectors(float origin[3], float result[3])
{
	result[0] = origin[0];
	result[1] = origin[1];
	result[2] = origin[2];
}

// 检测某个坐标是否能被任意生还者看到，如果有一个生还者能看见这个位置，返回 true，所有生还者都不可见这个位置，返回 false
bool PosIsVisibleToPlayer(int self, float refpos[3])
{
	bool bVisible = false;
	float target_pos[3] = {0.0};
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR) && IsPlayerAlive(client))
		{
			GetClientEyePosition(client, target_pos);
			Handle hTrace = TR_TraceRayFilterEx(refpos, target_pos, MASK_VISIBLE, RayType_EndPoint, TR_RayFilter, self);
			if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == client)
			{
				delete hTrace;
				bVisible = true;
			}
			delete hTrace;
		}
	}
	return bVisible;
}

// 检测某个玩家是否能看到生还者，能看见返回 true，不能看见则返回 false
bool Player_IsVisible_To(int client, int target)
{
	bool bVisible = false;
	float self_pos[3] = {0.0}, target_pos[3] = {0.0}, look_at[3] = {0.0}, vec_angles[3] = {0.0};
	GetClientEyePosition(client, self_pos);
	GetClientEyePosition(target, target_pos);
	MakeVectorFromPoints(self_pos, target_pos, look_at);
	GetVectorAngles(look_at, vec_angles);
	Handle hTrace = TR_TraceRayFilterEx(self_pos, vec_angles, MASK_SOLID, RayType_Infinite, TR_RayFilter, client);
	if (TR_DidHit(hTrace))
	{
		int ray_hit_ent = TR_GetEntityIndex(hTrace);
		if (ray_hit_ent == target)
		{
			bVisible = true;
		}
	}
	delete hTrace;
	return bVisible;
}

static bool TR_RayFilter(int entity, int mask, int self)
{
	return entity != self;
}