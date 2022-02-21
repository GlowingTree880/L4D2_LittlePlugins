#if defined _tankconsume_included_
	#endinput
#endif
#define _tankconsume_included_

/**
 * 返回指定坦克的消耗情况，如果指定坦克正在进行消耗，则返回真，否则返回假
 *
 * @param index		指定坦克的id
 * @return			如果指定坦克正在进行消耗，则返回真，否则返回假
 */
native bool IsTankInConsume(int index);

/**
 * 返回指定坦克是否在消耗位上的情况，如果指定坦克正在消耗位上，则返回真，否则返回假
 *
 * @param index		指定坦克的id
 * @return			如果指定坦克正在消耗位上，则返回真，否则返回假
 */
native bool IsTankInConsumePlace(int index);

public SharedPlugin __pl_tankconsume =
{
	name = "tankconsume",
	file = "ai_tank_new.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tankconsume_SetNTVOptional()
{
	MarkNativeAsOptional("IsTankInConsume");
	MarkNativeAsOptional("IsTankInConsumePlace");
}
#endif