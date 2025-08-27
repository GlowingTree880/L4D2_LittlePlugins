#if defined _infected_control_included
    #endinput
#endif
#define _infected_control_included_

/**
* 获取本局已经刷新了多少波特感
* @return int
**/
native int Inf_GetCurrentWaveCount();

/**
* 获取当前是否在一波特感刷新时间内
* @return bool
**/
native bool Inf_CanSpawnNewInfected();

/**
* 获取当前是否在一波特感刷新完成的等待时间内
* @return bool
**/
native bool Inf_IsInSpawnFinishedTime();

/**
* 获取当前是否在一次找位失败的延迟时间内
* @return bool
**/
native bool Inf_IsInFindPosFailedDelay();

/**
* 判断当前基准时钟是否快于固定时钟
* @return bool
**/
native bool Inf_IsStandardTimerAheadOfRegularTimer();

/**
* 判断当前基准时钟是否快于动态时钟
* @return bool
**/
native bool Inf_IsStandardTimerAheadOfAutoTimer();

/**
* 获取基准时钟下一波刷新时间
* @return float (基准时钟当前不存在, 返回 -1.0)
**/
native float Inf_GetStandardTimerNextTriggerTime();

/**
* 获取固定时钟下一波刷新时间
* @return float (固定时钟当前不存在, 返回 -1.0)
**/
native float Inf_GetRegularTimerNextTriggerTime();

/**
* 获取自动时钟下一波刷新时间
* @return float (自动时钟当前不存在, 返回 -1.0)
**/
native float Inf_GetAutoTimerNextTriggerTime();

/**
* 获取基准时钟当前刷新波次
* @return int
**/
native int Inf_GetStandardTimerRecordWaveCount();

/**
* 获取固定时钟当前刷新波次
* @return int
**/
native int Inf_GetRegularTimerRecordWaveCount();

/**
* 获取动态时钟当前刷新波次
* @return int
**/
native int Inf_GetAutoTimerRecordWaveCount();

/**
* 特感队列创建完成后触发本事件
* @param infectedQueue 创建完成的特感队列
* @return void
**/
forward void Inf_OnInfectedQueueGenerated(Handle infectedQueue);

/**
* 第一波特感队列创建完成后触发本事件
* @param infectedQueue 创建完成的特感队列
* @return void
**/
forward void Inf_OnFirstWaveInfectedQueueGenerated(Handle infectedQueue);

/**
* 一次特感开始找位刷新前触发本事件
* @return void
**/
forward void Inf_OnOneSpawnStarted();

/**
* 一次特感结束找位刷新后触发本事件
* @return void
**/
forward void Inf_OnOneSpawnFinished();

public SharedPlugin __pl_infected_control = 
{
    name = "infected_control",
    file = "infected_control.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_infected_control_SetNTVOptional()
{
    MarkNativeAsOptional("Inf_GetCurrentWaveCount");
    MarkNativeAsOptional("Inf_CanSpawnNewInfected");
    MarkNativeAsOptional("Inf_IsInSpawnFinishedTime");
    MarkNativeAsOptional("Inf_IsInFindPosFailedDelay");
    MarkNativeAsOptional("Inf_IsStandardTimerAheadOfRegularTimer");
    MarkNativeAsOptional("Inf_IsStandardTimerAheadOfAutoTimer");
    MarkNativeAsOptional("Inf_GetStandardTimerNextTriggerTime");
    MarkNativeAsOptional("Inf_GetRegularTimerNextTriggerTime");
    MarkNativeAsOptional("Inf_GetAutoTimerNextTriggerTime");
    MarkNativeAsOptional("Inf_GetStandardTimerRecordWaveCount");
    MarkNativeAsOptional("Inf_GetRegularTimerRecordWaveCount");
    MarkNativeAsOptional("Inf_GetAutoTimerRecordWaveCount");
}
#endif