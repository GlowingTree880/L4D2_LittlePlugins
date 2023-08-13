#pragma semicolon 1
#pragma newdecls required

GlobalForward
	// 投票更改 Boss 刷新位置完成后事件
	forwardUpdateBosses;

void nativesAndForwardsOnModuleStart() {
	forwardUpdateBosses = new GlobalForward("OnUpdateBosses", ET_Ignore, Param_Cell, Param_Cell);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "本插件仅支持 L4D2");
		return APLRes_SilentFailure;
	}
	// 注册 witch_and_tankifier 插件的 Native
	CreateNative("IsStaticTankMap", Native_IsStaticTankMap);
	CreateNative("IsStaticWitchMap", Native_IsStaticWitchMap);
	CreateNative("IsTankPercentValid", Native_IsTankPercentValid);
	CreateNative("IsWitchPercentValid", Native_IsWitchPercentValid);
	CreateNative("IsWitchPercentBlockedForTank", Native_IsWitchPercentBlockedForTank);
	CreateNative("SetTankPercent", Native_SetTankPercent);
	CreateNative("SetWitchPercent", Native_SetWitchPercent);
	// 注册 boss_percent 插件的 Native
	CreateNative("SetTankDisabled", Native_SetTankDisabled);
	CreateNative("SetWitchDisabled", Native_SetWitchDisabled);
	CreateNative("UpdateBossPercents", Native_UpdateBossPercents);
	CreateNative("GetStoredTankPercent", Native_GetStoredTankPercent);
	CreateNative("GetStoredWitchPercent", Native_GetStoredWitchPercent);
	CreateNative("GetReadyUpFooterIndex", Native_GetReadyUpFooterIndex);
	CreateNative("RefreshBossPercentReadyUp", Native_RefreshReadyUp);
	CreateNative("IsDarkCarniRemix", Native_IsDarkCarniRemix);
	// 注册插件支持
	RegPluginLibrary("boss_controller");
	return APLRes_Success;
}

void updateBossPercents() {
	CreateTimer(0.1, timerGetBossFlowWithDkrInclude, _, _);
	updateReadyUpFooter(0.2);
}

void setTankPercentWitchWitchAvoidance(int newTankPercent) {
	dynamicAdjustWtichPercent(newTankPercent);
	tankFlow = newTankPercent;
	setTankPercent(newTankPercent);
}

bool setWitchPercentWithValid(int newWitchPercent) {
	if (!isWitchPercentValid(newWitchPercent)) {
		return false;
	}
	witchFlow = newWitchPercent;
	setWitchPercent(newWitchPercent);
	return true;
}

bool isWitchPercentValidWithBlock(int newWitchPercent, bool ignoreBlock) {
	if (!ignoreBlock) {
		return isWitchPercentValid(newWitchPercent);
	}
	
	ArrayList pValidFlow = witchPercentList.Clone(),
			 pTempWitchFlow = witchPercentList;
	int i, interval[2];
	if (getTankAvoidInterval(interval) && isValidInterval(interval[0], interval[1])) {
		for (i = interval[0]; i <= interval[1]; i++) {
			if (pValidFlow.FindValue(i) >= 0) {
				continue;
			}
			pValidFlow.Push(i);
		}
		pValidFlow.Sort(Sort_Ascending, Sort_Integer);
		witchPercentList = pValidFlow;
	}
	bool result = isWitchPercentValid(newWitchPercent);
	// 判断完成, 更改 witchPercentList 的引用为原来的引用
	witchPercentList = pTempWitchFlow;
	delete pValidFlow;
	return result;
}

// ========== Natives ==========
any Native_IsStaticTankMap(Handle plugins, int numParams) {
	char mapName[64];
	GetNativeString(1, mapName, sizeof(mapName));
	return isStaticTankMap(mapName);
}

any Native_IsStaticWitchMap(Handle plugins, int numParams) {
	char mapName[64];
	GetNativeString(1, mapName, sizeof(mapName));
	return isStaticWitchMap(mapName);
}

any Native_SetTankPercent(Handle plugin, int numParams) {
	int flow = GetNativeCell(1);
	if (!isTankPercentValid(flow)) {
		return false;
	}
	setTankPercentWitchWitchAvoidance(flow);
	return true;
}

any Native_SetWitchPercent(Handle plugin, int numParams) {
	int flow = GetNativeCell(1);
	return setWitchPercentWithValid(flow);
}

any Native_IsWitchPercentBlockedForTank(Handle plugin, int numParams)
{
	int interval[2];
	if (getTankAvoidInterval(interval) && isValidInterval(interval[0], interval[1])) {
		int flow = GetNativeCell(1);
		return (flow >= interval[0] && flow <= interval[1]);
	}
	return false;
}

any Native_IsTankPercentValid(Handle plugin, int numParams) {
	int flow = GetNativeCell(1);
	return isTankPercentValid(flow);
}

any Native_IsWitchPercentValid(Handle plugin, int numParams) {
	int flow = GetNativeCell(1);
	bool ignoreBlock = GetNativeCell(2);
	return isWitchPercentValidWithBlock(flow, ignoreBlock);
}

any Native_UpdateBossPercents(Handle plugin, int numParams) {
	updateBossPercents();
	return 1;
}

any Native_SetTankDisabled(Handle plugin, int numParams) {
	g_hTankCanSpawn.BoolValue = view_as<bool>(GetNativeCell(1));
	updateReadyUpFooter();
	return 1;
}

any Native_SetWitchDisabled(Handle plugin, int numParams) {
	g_hWitchCanSpawn.BoolValue = view_as<bool>(GetNativeCell(1));
	updateReadyUpFooter();
	return 1;
}

any Native_IsDarkCarniRemix(Handle plugin, int numParams) {
	return isDarkCarnivalRemix();
}

any Native_GetStoredTankPercent(Handle plugin, int numParams) {
	return tankFlow;
}

any Native_GetStoredWitchPercent(Handle plugin, int numParams) {
	return witchFlow;
}

any Native_GetReadyUpFooterIndex(Handle plugin, int numParams) {
	if (isReadyUpExist) {
		return readyUpFooterIndex;
	}
	return -1;
}

any Native_RefreshReadyUp(Handle plugin, int numParams) {
	if (isReadyUpExist) {
		updateReadyUpFooter();
		return true;
	}
	return false;
}