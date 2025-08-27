#if defined _qyng_store_included_
    #endinput
#endif
#define _qyng_store_included_

/**
* 获取当前 Map 生效的团队卡名称
* @param buffer 用于存放名称的数组名
* @param len 数组长度
* @return int 写入字符数量
**/
native int QyngStore_GetActiveTeamCardNames(char[] buffer, int len);

/**
* 判断给定位置是否会卡住售货机放置
* @param pos 位置
* @param size 数组大小
* @return bool 是否会卡住
**/
native bool QyngStore_IsPosWillStuckVendingMachine(const float[] pos, int size);

/**
* 在给定位置放置售货机
* @param pos 位置
* @param size 数组大小
* @return void
**/
native void QyngStore_SpawnVendingMachineAtPos(const float[] pos, int size);