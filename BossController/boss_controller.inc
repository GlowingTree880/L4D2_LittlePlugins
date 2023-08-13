#if defined _boss_controller_included
 #endinput
#endif
#define _boss_controller_included

/**
 * @brief Check if the current map contains a static witch spawn.
 * @remarks Map string will be converted to lowercase internally.
 *
 * @param	map				Specific map to query, or current map if empty.
 *
 * @return					True on contains a static spawn, false otherwise.
 */
native bool IsStaticWitchMap(const char[] map = "");

/**
 * @brief Check if the current map contains a static tank spawn.
 * @remarks Map string will be converted to lowercase internally.
 *
 * @param	map				Specific map to query, or current map if empty.
 *
 * @return					True on contains a static spawn, false otherwise.
 */
native bool IsStaticTankMap(const char[] map = "");

/**
 * @brief Validate the flow percentage of tank on current map.
 * @remarks Passing 0 is allowed and considered disabling.
 *
 * @param	percent			Flow percentage to check.
 *
 * @return					True on valid, false otherwise.
 */
native bool IsTankPercentValid(int percent);

/**
 * @brief Validate the flow percentage of witch on current map.
 * @remarks Passing 0 is allowed and considered disabling.
 *
 * @param	percent			Flow percentage to check.
 * @param	ignoreBlock		Ignore percent block due to tank percent.
 *
 * @return					True on valid, false otherwise.
 */
native bool IsWitchPercentValid(int percent, bool ignoreBlock = false);

/**
 * @brief Check if the flow percentage of witch is blocked due to current tank percent.
 * @remarks The blocked range covers as much as the value of convar "sm_witch_avoid_tank_spawn",
 *			taking current tank percent as middle point.
 *
 * @param	percent			Flow percentage to check.
 *
 * @return					True on blocked, false otherwise.
 */
native bool IsWitchPercentBlockedForTank(int percent);

/**
 * @brief Set the flow percentage of tank on current map.
 * @remarks Passing 0 is allowed and will disable flow tank.
 *
 * @param	percent			Flow percentage to check.
 *
 * @return					True on success, false otherwise.
 */
native bool SetTankPercent(int percent);

/**
 * @brief Set the flow percentage of witch on current map.
 * @remarks Passing 0 is allowed and will disable flow witch.
 *
 * @param	percent			Flow percentage to check.
 *
 * @return					True on success, false otherwise.
 */
native bool SetWitchPercent(int percent);

// ========== Boss Percent's Natives ==========

/**
 * @brief Set the tank as "disabled" on the ready up, and when the !boss command is used.
 * @remarks YOU NEED TO SET THIS EVERY MAP.
 *
 * @param disable			Boolean to set
 *
 * @noreturn
 */
native void SetTankDisabled(bool disable);

/**
 * @brief Set the witch as "disabled" on the ready up, and when the !boss command is used.
 * @remarks YOU NEED TO SET THIS EVERY MAP.
 *
 * @param disable			Boolean to set
 *
 * @noreturn
 */
native void SetWitchDisabled(bool disable);

/**
 * @brief Update the boss percentages.
 *
 * @noreturn
 */
native void UpdateBossPercents();

/**
 * @brief Get the stored tank percent.
 *
 * @return					Integer of the percentage, 0 if spawn disabled or spawn static, -1 if unsupported game.
 */
native int GetStoredTankPercent();

/**
 * @brief Get the stored witch percent.
 *
 * @return					Integer of the percentage, 0 if spawn disabled or spawn static, -1 if unsupported game.
 */
native int GetStoredWitchPercent();

/**
 * @brief Get the ready footer index of the boss percents.
 * @remarks Safe to use no matter readyup is available or not.
 *
 * @return					Index of the ready up footer, -1 if readyup is not available.
 */
native int GetReadyUpFooterIndex();

/**
 * @brief Refresh the boss percents on the ready up.
 * @remarks All hooks are removed on map change.
 *
 * @return					True on success, false if readyup is not available.
 */
native bool RefreshBossPercentReadyUp();

/**
 * @brief Check if the current map is Dark Carnival: Remix.
 * @remarks Dark Carnival: Remix uses built-in custom boss system, which is not the usual way that the game performs.
 *
 * @return					True if current map is Dark Carnival: Remix, false otherwise.
 */
native bool IsDarkCarniRemix();

public SharedPlugin __pl_boss_controller =
{
	name = "boss_controller",
	file = "boss_controller.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_boss_controller_SetNTVOptional()
{
	// Witch And Tankifier
	MarkNativeAsOptional("IsStaticWitchMap");
	MarkNativeAsOptional("IsStaticTankMap");
	MarkNativeAsOptional("IsTankPercentValid");
	MarkNativeAsOptional("IsWitchPercentValid");
	MarkNativeAsOptional("SetTankPercent");
	MarkNativeAsOptional("SetWitchPercent");
	// Boss Percent
	MarkNativeAsOptional("SetTankDisabled");
	MarkNativeAsOptional("SetWitchDisabled");
	MarkNativeAsOptional("UpdateBossPercents");
	MarkNativeAsOptional("GetStoredTankPercent");
	MarkNativeAsOptional("GetStoredWitchPercent");
	MarkNativeAsOptional("GetReadyUpFooterIndex");
	MarkNativeAsOptional("RefreshBossPercentReadyUp");
	MarkNativeAsOptional("IsDarkCarniRemix");
}
#endif