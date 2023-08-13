# Boss Controller
- 本插件是 `L4D2-Competitive-Rework` 插件包中 `witch_and_tankifier.smx` (读取 `MapInfo` 文件并设置随机 Tank 与 Witch 的刷新路程), `l4d_boss_percent.smx` (`!boss`, `!tank`, `!witch` 指令显示 Boss 刷新路程), `l4d_boss_vote.smx` (`!bossvote` 指令投票更改 Boss 刷新路程) 3 个插件的整合版本, 支持战役与对抗使用, 支持无 `MapInfo` 文件使用

## Cvars
```java
// MapInfo 文件路径, 相对于 sourcemod 文件夹
boss_map_info_path "../../cfg/cfgogl/mapinfo.txt"
// 插件接管 Boss 刷新时是否允许插件生成 Tank [0: 禁止]
boss_tank_can_spawn 1
// 插件接管 Boss 刷新时是否允许插件生成 Witch [0: 禁止]
boss_witch_can_spawn 1
// Witch 应该距离 Tank 刷新位置多远的路程刷新 [将会以 Tank 刷新位置为中间点，左右 (这个值 / 2) 距离禁止刷新 Witch，比如 Tank 在 76 路程, Witch 则不能设置在 66-86 的路程], 回合开始插件自动获取 Boss 刷新路程时, 本 Cvar 的值也会被考虑进入 Witch 刷新路程, ZoneMod 则不会, 只会在投票更改 Boss 路程时使用
boss_witch_avoid_tank 20
// 在距离 Boss 刷新路程之前多少路程开始提示即将刷新 [0: 不提示, 假设 Tank 在 50 路程刷新, 生还者到达 45 路程时每推进 1 路程会在聊天框显示 生还者当前路程与 Tank 刷新位置]
boss_prompt_dist 5
// 非对抗模式下是否踢出非本插件刷新的 Boss [救援关请手动禁用, 否则导演 Boss 会被踢出]
boss_prohibit_non_plugin 1
// 救援关时是否禁止本插件接管 Boss 刷新 [如 c2m5 等救援关, 本 Cvar 开启则插件不会接管 Boss 刷新]
boss_disable_in_finale 0
// 是否允许通过 !bossvote 指令投票更改 Tank 和 Witch 刷新路程
boss_enable_vote 1
// 非对抗模式下插件刷新 Boss 距离目标生还者的最小直线距离 [建议不要大于 1200, 否则使用 L4D_GetRandomPZSpawnPosition 函数找位时很难找到位置]
boss_min_distance 1000
// 非对抗模式下插件刷新 Boss 距离目标生还者的最小 Nav 距离 [建议不要大于 1200, 否则使用 L4D_GetRandomPZSpawnPosition 函数找位时很难找到位置]
boss_min_nav_distance 1000
// 非对抗模式下, 使用函数找位无法获取有效 Boss 刷新位置转为使用射线找位, 射线找位的最大用时 [非对抗模式下, 首先使用 L4D_GetRandomPZSpawnPosition 进行一轮找位, 如无法获取到有效刷新位置, 则使用射线进行找位, 射线找位找位开始经过这个时间仍未找到有效刷新位置, 则本局不会刷新对应 Boss]
boss_find_pos_max_time 8.0
// 插件日志级别 (1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR) 
boss_log_level 38

// 是否在使用显示 Boss 刷新路程指令时将结果显示给使用指令的客户端所在团队所有玩家
boss_global_percent 0
// 使用显示 Boss 路程指令时是否显示 Tank 刷新路程
boss_tank_percent 1
// 使用显示 Boss 路程指令时是否显示 Witch 刷新路程
boss_witch_percent 1
// 使用显示 Boss 路程指令时是否显示当前路程
boss_current 1
``````

## Cmds
```java
static_tank_map [注册静态 Tank 地图, 仅服务器可用]
static_witch_map [注册静态 Witch 地图, 仅服务器可用]
reset_static_maps [重置静态 Tank 与 Witch 地图, 仅服务器可用]

// 本插件注册了 !cur 与 !current 指令, 如与其他路程显示插件冲突请注释注册 cur 与 current 指令并重新编译
sm_boss (!boss) [显示 Boss 刷新路程]
sm_tank (!tank) [显示 Boss 刷新路程]
sm_witch (!witch) [显示 Boss 刷新路程]
sm_cur (!cur) [显示 Boss 刷新路程]
sm_current (!current) [显示 Boss 刷新路程]

sm_bv (!bv <Tank> <Witch>) [投票更改 Boss 刷新路程, 0 禁用刷新, -1 忽略]
sm_voteboss (!voteboss <Tank> <Witch>) [投票更改 Boss 刷新路程, 0 禁用刷新, -1 忽略]
sm_bossvote (!bossvote <Tank> <Witch>) [投票更改 Boss 刷新路程, 0 禁用刷新, -1 忽略]

sm_ftank (!ftank <Tank>) [强制更改本局 Tank 刷新位置, 仅管理可用]
sm_fwitch (!fwitch <Witch>) [强制更改本局 Witch 刷新位置, 仅管理可用]
sm_checkflow (!checkflow) [显示本局 Tank 与 Witch 刷新路程信息, 测试使用, 仅管理可用]
sm_staticmap (!staticmap) [显示所有静态地图信息, 测试使用, 仅管理可用]
``````

## 使用方法
1. 将本插件丢到 `sourcemod\plugins` 文件夹中
2. **可选:** 在 Tips 中链接获取 `MapInfo` 文件并丢到插件 Cvar: `boss_map_info_path` 值的位置, 默认 `cfg/cfgogl/` 目录, 如果没有请自行新建<br>
    对于一个 `MapInfo` 文件, 以下为示例
    ```java
    "MapInfo"
    {
    	"c2m2_fairgrounds"
    	{
    		"start_point"		"1718.106934 2897.631592 83.232269"
    		"end_point"			"-4797.248047 -5396.388184 15.232277"
    		"start_dist"		"50.000000"
    		"start_extra_dist"	"0.000000"
    		"end_dist"			"150.000000"
    		"horde_limit"		"120"
    		"tank_ban_flow"
    		{
    			"Alley choke to up top"
    			{
    				"min"		"56"
    				"max"		"68"
    			}
    		}
    		"witch_ban_flow"
    		{
    			"Ladder"
    			{
    				"min"		"54"
    				"max"		"58"
    			}
    			"Start of event"
    			{
    				"min"		"78"
    				"max"		"87"
    			}
    		}
    	}
        ...
    }
    ``````
    在使用本插件时, 如需禁止一段 Tank 或 Witch 刷新的路程, 只需在配置 `tank_ban_flow` 与 `witch_ban_flow`, 增加对应需要禁止刷新的路程即可, 其中 `min` 为开始禁止刷新的路程, `max` 为结束禁止刷新的路程, 范围为 `1 - 100`
3. **可选:** 在任意一个地图加载时会被读取到的 `.cfg` 文件中使用 `static_tank_map` 或 `static_witch_map` 指令注册静态 Tank 与 Witch 地图, 可参考 [ZoneMod SharedSettings](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/cfg/cfgogl/zonemod/shared_settings.cfg) `331 - 350` 行位置, 在对应静态地图下插件不会接管对应 Boss 刷新 
4. 编译本插件时请使用 [lib](https://github.com/GlowingTree880/L4D2_LittlePlugins/tree/main/lib) 中的 treeutil.inc 编译

## 注意事项
1. 在非对抗模式下, 如果允许插件随机 Boss 位置, 则插件会自动将 `director_no_bosses` 设置为 1 令导演系统不会刷新 Boss, 之后如需使用导演系统刷新 Boss, 请手动设置 `director_no_bosses` 为 0
2. 对于 `Dark Carnival Remix (DKR)` 地图, 在 `ZoneMod SharedSettings` 已经被注册为静态 Tank 与 Witch 地图, 如使用 `ZoneMod SharedSettings` 的静态地图配置, 那么在使用非对抗模式游玩此地图时插件将不会接管 Boss 刷新, 如需插件接管 Boss 刷新请移除本地图静态地图的设定
3. 对于 `Dark Carnival Remix (DKR)` 地图, 对抗模式下, 其使用脚本刷新 Boss, 因此本插件不会接管 Boss 刷新, Tank 与 Witch 路程显示均为获取在聊天框中脚本输出的 Tank 与 Witch 位置

## 当前存在的问题
1. 判断是否终局使用判断是否存在 `trigger_finale` 实体, 对于某些救援关不适用

## Tips
1. `MapInfo` 文件可在 [ZoneMod MapInfo](https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/cfg/cfgogl/zonemod/mapinfo.txt) 获取
2. `builtinvotes.inc` 与 `readyup.inc` 文件可在 [ZoneMod Include](https://github.com/SirPlease/L4D2-Competitive-Rework/tree/master/addons/sourcemod/scripting/include) 获取

## 更新日志
- 2023-08-13: 在老版本 Boss Controller 基础上优化结构, 并将老版本 Boss Controller 移到 .history 目录中, 上传新版本与 readme

---
- 如在使用过程中发现任何 Bug，请提出 issue 说明 Bug 类型及发生时情况，如有报错请附上 log 文件信息 (｡･ω･｡)