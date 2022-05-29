enum PlayerTeam
{
	TEAM_SPECTATOR = 1,
	TEAM_SURVIVOR,
	TEAM_INFECTED
};

enum ZombieClass
{
	ZC_NONE = 0,
	ZC_SMOKER,
	ZC_BOOMER,
	ZC_HUNTER,
	ZC_SPITTER,
	ZC_JOCKEY,
	ZC_CHARGER,
	ZC_WITCH,
	ZC_TANK,
	ZC_NOTINFECTED
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
	return bIsPinned;
}

// 随机获取一个未死亡，未被控，未倒地的生还者或只是活着的生还者，如有则返回生还者 id，无则返回 0
stock int GetRandomSurvivor(bool is_mobile = false)
{
	int[] survivor_array = new int[GetConVarInt(FindConVar("survivor_limit"))];
	int survivor_index = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (is_mobile && IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR) && !IsClientPinned(client) && !IsClientIncapped(client))
		{
			survivor_array[survivor_index] = client;
			survivor_index += 1;
		}
		else if (!is_mobile && IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR))
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
		int closet_survivor = GetRandomSurvivor(true);
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
	else
	{
		return 0;
	}
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

// 获取指定团队的成员数量，可指定是否包含 bot 与死亡的成员，成功返回成员数量，失败返回 0
stock int GetTeamMemberCount(int team, bool include_bot = true, bool include_death = false)
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		switch (team)
		{
			case view_as<int>TEAM_SPECTATOR:
			{
				if (IsValidClient(client) && GetClientTeam(client) == view_as<int>TEAM_SPECTATOR)
				{
					count += 1;
				}
			}
			case view_as<int>TEAM_SURVIVOR:
			{
				if (include_bot && include_death)
				{
					if (IsValidSurvivor(client))
					{
						count += 1;
					}
				}
				else if (include_bot && !include_death)
				{
					if ((IsValidSurvivor(client)) && IsPlayerAlive(client))
					{
						count += 1;
					}
				}
				else if (!include_bot && include_death)
				{
					if ((IsValidSurvivor(client)) && !IsFakeClient(client))
					{
						count += 1;
					}
				}
				else if (!include_bot && !include_death)
				{
					if ((IsValidSurvivor(client)) && !IsFakeClient(client) && IsPlayerAlive(client))
					{
						count += 1;
					}
				}
			}
			case view_as<int>TEAM_INFECTED:
			{
				if (include_bot && include_death)
				{
					if (IsValidInfected(client))
					{
						count += 1;
					}
				}
				else if (include_bot && !include_death)
				{
					if ((IsValidInfected(client)) && IsPlayerAlive(client))
					{
						count += 1;
					}
				}
				else if (!include_bot && include_death)
				{
					if ((IsValidInfected(client)) && !IsFakeClient(client))
					{
						count += 1;
					}
				}
				else if (!include_bot && !include_death)
				{
					if ((IsValidInfected(client)) && !IsFakeClient(client) && IsPlayerAlive(client))
					{
						count += 1;
					}
				}
			}
		}
	}
	return count;
}

// 判断当前客户端是否是 Tank，是返回 true，否返回 false
stock bool IsTank(int client)
{
	if (GetInfectedClass(client) == view_as<int>(ZC_TANK))
	{
		return true;
	}
	else
	{
		return false;
	}
}

// 判断目前场上是否有 Tank，有返回 true，无返回 false
stock bool IsTankInSpot()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == view_as<int>(TEAM_INFECTED) 
		&& GetEntProp(client, Prop_Send, "m_isGhost") != 1 && GetEntProp(client, Prop_Send, "m_zombieClass") == view_as<int>(ZC_TANK) && GetEntProp(client, Prop_Send, "m_isIncapacitated") != 1)
		{
			return true;
		}
	}
	return false;
}

// 判断玩家的武器是否处于正在换弹的状态，是返回 true，否或无效武器返回 false
stock bool IsWeaponInReload(int client)
{
	if (IsValidClient(client))
	{
		int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(active_weapon) && IsValidEdict(active_weapon))
		{
			if (HasEntProp(active_weapon, Prop_Send, "m_bInReload"))
			{
				return view_as<bool>(GetEntProp(active_weapon, Prop_Send, "m_bInReload"));
			}
		}
	}
	return false;
}

// 判断所有生还者中正在使用的某种武器的数量，成功返回指定武器数量，失败返回 0
stock int GetSurvivorWeaponCount(bool include_mobile = false, char[] weapon_name)
{
	int weapon_count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (include_mobile && IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR) && !IsClientIncapped(client) && !IsClientPinned(client))
		{
			int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(active_weapon) && IsValidEdict(active_weapon))
			{
				char class_name[64] = '\0';
				GetEdictClassname(active_weapon, class_name, sizeof(class_name));
				if (strcmp(class_name, weapon_name) == 0)
				{
					weapon_count += 1;
				}
			}
		}
		else if (!include_mobile && IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == view_as<int>(TEAM_SURVIVOR))
		{
			int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(active_weapon) && IsValidEdict(active_weapon))
			{
				char class_name[64] = '\0';
				GetEdictClassname(active_weapon, class_name, sizeof(class_name));
				if (strcmp(class_name, weapon_name) == 0)
				{
					weapon_count += 1;
				}
			}
		}
	}
	return weapon_count;
}

// 返回当前客户端实际速度大小，有效返回速度大小，无效返回 -1
stock int GetClientCurrentSpeed(int client)
{
	float current_velocity[3] = {0.0}, current_speed = 0.0;
	if (IsValidClient(client) && HasEntProp(client, Prop_Data, "m_vecVelocity"))
	{
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", current_velocity);
		return RoundToNearest(SquareRoot(Pow(current_velocity[0], 2.0) + Pow(current_velocity[1], 2.0));
	}
	return -1;	
}