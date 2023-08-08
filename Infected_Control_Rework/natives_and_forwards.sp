/**
* @Author 夜羽真白
* @Date 2023-07-28 14:47:08
* @Description Natives And Forwards
* @Version 1.0.0.0
* @GitHub https://github.com/GlowingTree880/L4D2_LittlePlugins
**/

#pragma semicolon 1
#pragma newdecls required

void setUpNatives() {
	CreateNative("Inf_GetCurrentWaveCount",	Native_Inf_GetCurrentWaveCount);
	CreateNative("Inf_CanSpawnNewInfected", Native_Inf_CanSpawnNewInfected);
	CreateNative("Inf_IsInSpawnFinishedTime", Native_Inf_IsInSpawnFinishedTime);
	CreateNative("Inf_IsInFindPosFailedDelay", Native_Inf_IsInFindPosFailedDelay);
	CreateNative("Inf_IsStandardTimerAheadOfRegularTimer", Native_Inf_IsStandardTimerAheadOfRegularTimer);
	CreateNative("Inf_IsStandardTimerAheadOfAutoTimer", Native_Inf_IsStandardTimerAheadOfAutoTimer);
	CreateNative("Inf_GetStandardTimerNextTriggerTime",	Native_Inf_GetStandardTimerNextTriggerTime);
	CreateNative("Inf_GetRegularTimerNextTriggerTime", Native_Inf_GetRegularTimerNextTriggerTime);
	CreateNative("Inf_GetAutoTimerNextTriggerTime", Native_Inf_GetAutoTimerNextTriggerTime);
	CreateNative("Inf_GetStandardTimerRecordWaveCount", Native_Inf_GetStandardTimerRecordWaveCount);
	CreateNative("Inf_GetRegularTimerRecordWaveCount", Native_Inf_GetRegularTimerRecordWaveCount);
	CreateNative("Inf_GetAutoTimerRecordWaveCount", Native_Inf_GetAutoTimerRecordWaveCount);
}

// Natives
any Native_Inf_GetCurrentWaveCount(Handle plugin, int numParams) {
	return currentSpawnWaveCount;
}

any Native_Inf_CanSpawnNewInfected(Handle plugin, int numParams) {
	return canSpawnNewInfected;
}

any Native_Inf_IsInSpawnFinishedTime(Handle plugin, int numParams) {
	return isInSpawnFinishedTime;
}

any Native_Inf_IsInFindPosFailedDelay(Handle plugin, int numParams) {
	return isInFindPosFailedDelay;
}

any Native_Inf_IsStandardTimerAheadOfRegularTimer(Handle plugin, int numParams) {
	if (regularInfectedSpawnTimer.timer == null) {
		return true;
	} else {
		if (standardInfectedSpawnTimer.nextTriggerTime < regularInfectedSpawnTimer.nextTriggerTime) {
			return true;
		}
	}
	return false;
}

any Native_Inf_IsStandardTimerAheadOfAutoTimer(Handle plugin, int numParams) {
	if (autoInfectedSpawnTimer.timer == null) {
		return true;
	} else {
		if (standardInfectedSpawnTimer.nextTriggerTime < autoInfectedSpawnTimer.nextTriggerTime) {
			return true;
		}
	}
	return false;
}

any Native_Inf_GetStandardTimerNextTriggerTime(Handle plugin, int numParams) {
	if (standardInfectedSpawnTimer.timer == null) {
		return -1.0;
	}
	return standardInfectedSpawnTimer.nextTriggerTime;
}

any Native_Inf_GetRegularTimerNextTriggerTime(Handle plugin, int numParams) {
	if (regularInfectedSpawnTimer.timer == null) {
		return -1.0;
	}
	return regularInfectedSpawnTimer.nextTriggerTime;
}

any Native_Inf_GetAutoTimerNextTriggerTime(Handle plugin, int numParams) {
	if (autoInfectedSpawnTimer.timer == null) {
		return -1.0;
	}
	return autoInfectedSpawnTimer.nextTriggerTime;
}

any Native_Inf_GetStandardTimerRecordWaveCount(Handle plugin, int numParams) {
	return regularInfectedSpawnTimer.recordSpawnWaveCount;
}

any Native_Inf_GetRegularTimerRecordWaveCount(Handle plugin, int numParams) {
	return regularInfectedSpawnTimer.recordSpawnWaveCount;
}

any Native_Inf_GetAutoTimerRecordWaveCount(Handle plugin, int numParams) {
	return autoInfectedSpawnTimer.recordSpawnWaveCount;
}

// Forwards
GlobalForward
	// 第一波特感队列生成完成后事件
	onFirstWaveInfectedQueueGenerated,
	// 普通特感队列生成完成后事件
	onInfectedQueueGenerated,
	// 一波特感开始刷新事件
	onOnceSpawnStarted,
	// 一波特感刷新完成后事件
	onOnceSpawnFinished;

void nativesAndForwardsOnModuleStart() {
	onFirstWaveInfectedQueueGenerated = new GlobalForward("Inf_OnFirstWaveInfectedQueueGenerated", ET_Ignore, Param_Array, Param_Cell);
	onInfectedQueueGenerated = new GlobalForward("Inf_OnInfectedQueueGenerated", ET_Ignore, Param_Array, Param_Cell);
	onOnceSpawnStarted = new GlobalForward("Inf_OnOneSpawnStarted", ET_Ignore);
	onOnceSpawnFinished = new GlobalForward("Inf_OnOneSpawnFinished", ET_Ignore);
}