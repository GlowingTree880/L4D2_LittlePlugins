# Infected Control Rework

## 插件介绍
- 本插件为基于原 [Infected Control](https://github.com/GlowingTree880/L4D2_LittlePlugins/tree/main/Infected_Control) 的修改增强版本，后续将会持续维护这一刷特插件，停止维护原 Infected Control 刷特插件
- 插件默认开启控制台输出特感队列生成与其他相关信息，方便调试与维护，如需关闭请修改 Cvar: `inf_enable_logging` 为 `1` 即禁用日志

## Cvars
```java
// 特感刷新数量
inf_limit 6
// 集中刷新时两次刷新的基本间隔 或 分散刷新时每个特感的重生时间
inf_spawn_duration 16
// 特感刷新策略 (1: 每波之间间隔固定 [固定] [击杀特感数量达到设置数量 / 2 开始计时], 2: 每波之间间隔根据击杀情况自动调整 [动态] [击杀特感数量达到设置数量 / 2 或 击杀强控特感数量达到强控总数 / 2 + 1 特时开始计时])
inf_spawn_strategy 2
// 特感刷新方式 (1: 集中刷新 [到时间一起刷新一波, 传统 Anne], 2: 分散刷新 [每个特感单独按 g_hSpawnDuration 计时, 到时间不会一起刷新一波, 类似 Ast])
inf_spawn_method_strategy 1
// 采用分散刷新方式时, 先死亡的特感需要等待至少 [g_hDisperseSpawnPercent * g_hInfectedLimit] 取下整 个特感复活时间完成或在场才允许复活, [如配置 5 特感, 本值为 0.5, 则先死亡的特感需要等待至少 3 只特感复活完成或在场至少 3 只特感才可复活]
inf_disperse_spawn_per 0.5
// 特感找位策略 (1: 每刷新一只特感时随机一个生还者找位, 2: 在一个刷新队列刷新完毕前都以一个生还者找位, 3: 总是以路程最大的生还者找位, 4: 总是以路程最小的生还者找位)
inf_centeralize_spawn_strategy 1
// 每个刷新位置允许刷新多少只特感
inf_each_pos_count 1
// 每局第一波特感刷新在首个生还者离开安全区域后延迟多少秒 (0: 不延迟)
inf_firstwave_delay 0.0
// 有一个生还者倒地则下一波刷特向后延迟多少秒 (0: 不延迟) [仅集中刷新模式可用]
inf_incap_extra_time 5.0
// 多少秒后踢出死亡的特感 [除 Spitter 与 Tank]
inf_dead_kick_time 0.5
// 以何种方式开启特感刷新 (1: 自动控制 [首个生还者离开安全区域自动刷新], 2: 手动控制 [需要输入 !startspawn 指令, 适配 Anne text.smx 插件])
inf_start_spawn_control 1
// 插件日志级别 (1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR) 数字相加, 6 = 2 + 4 表示同时启用 DEBUG 与 INFO 功能
inf_log_level 6

// 特感刷新队列文件位置
inf_queue_kvfile_path data/infected_queue.cfg
// 启用哪种特感的单特感模式 (只会刷新这一种特感, 0: 禁用此功能, [1 - 6] 启用 Smoker, Boomer, Hunter, Spitter, Jockey, Charger 的单特感模式)
inf_single_infected 0
// Tank 在场时禁用哪种特感的刷新 (0: 禁用此功能, 英文逗号隔开, 例 [4,5] 则 Tank 在场时禁用 Spitter 与 Jockey 刷新)
inf_ban_spawn_class_tank 4
// Tank 在场时对禁用刷新特感测策略 (1: 禁止刷新, 2: 替换为可以刷新的其他特感)
inf_ban_spawn_tank_strategy 2
// 超过 6 特以上是否更改刷新队列使得每种类型特感产生一只
inf_over_six_every_class_one 1

// 特感找位方式 (1: 使用 L4D_GetRandomPZSpawnPosition API, 2: 使用增强 L4D_GetRandomPZSpawnPosition API, 3: 使用射线找位)
inf_pos_find_method 3
// 特感刷新位置距离目标的最小直线距离
inf_pos_min_distance 150
// 特感刷新位置距离目标的最小 Nav 距离
inf_pos_min_nav_distance 100
// 特感刷新位置距离目标的最大直线距离
inf_pos_max_distance 1000
// 特感刷新位置距离目标的初始 Nav 距离
inf_pos_init_nav_distance 1500
// 特感刷新位置距离目标的最大 Nav 距离 (从 inf_pos_init_nav_distance 开始, 经过 inf_pos_start_expand_time 时间开始以每帧 inf_pos_nav_expand_unit 值进行 Nav 距离增加, 直到增加到 inf_pos_max_nav_distance 为止)
inf_pos_max_nav_distance 2800
// 特感是否允许在安全区域刷新
inf_pos_allow_in_safearea 0
// 特感找位是否需要在目标生还者前方
inf_pos_should_ahead 0
// 找位时网格初始大小
inf_pos_default_grid_min 600
// 找位时网格可拓展的最大大小
inf_pos_default_grid_max 1500
// 从开始找位刷新的时间算起, 超过这个时间 (单位: s) 没有刷新完成一波特感, 开始逐帧进行找位网格拓展
inf_pos_start_expand_time 1.25
// 允许一次找位刷新的最大时间, 超过这个时间 (单位: s) 则暂停 g_hFailedFindPosNextDelay 时间后继续启动找位 (0: 无上限)
inf_pos_find_max_time 8.0
// 一次找位刷新失败找位的暂停时间
inf_pos_fail_delay 2.5
// 逐帧进行找位网格拓展时每帧网格拓展多少单位
inf_pos_expand_unit 3
// 逐帧进行 Nav 距离拓展时每帧拓展多少单位
inf_pos_nav_expand_unit 3

``````

## Cmds
```java
// 手动开始第一波特感刷新, Cvar: inf_start_spawn_control 为 2 时可用
sm_startspawn (!startspawn) [仅管理可用]
// 更改特感数量
sm_limit (!limit <num>) [仅管理可用]
// 更改特感刷新时间
sm_duration (!duration <sec>) [仅管理可用]
// 启用或禁用单一特感模式
sm_type (!type <num>) [仅管理可用]
// 使用分散刷新模式时, 在控制台输出特感状态数组情况, 调试时使用, 且需要 inf_log_level 等级包含 2 (DEBUG) 时可将结果展示到控制台上
sm_statelist (!statelist) [仅管理可用]
// 连续测试多次获取特感刷新队列, 如无参数则默认获取 10 次特感刷新队列, 调试时使用, 且需要 inf_log_level 等级包含 2 (DEBUG) 时可将结果展示到控制台上
sm_state (!state) [仅管理可用]
// 展示插件特感刷新状态 (是否允许刷新、是否已经刷新完成一波、是否在找位失败延迟中等)
sm_entmap (!entmap) [仅管理可用]
// 展示插件特感实体引用 Map 集合内容, 该集合用于在需要进行特感轮换时或分散刷新时判断死亡的特感是否是插件刷出的, 防止非法特感干扰插件刷新导致刷特数量不准确的情况
sm_infqueue (!infqueue <num [10]>)
``````

## 其他图示
![图示 1](./pic/feat.png)

## 注意事项
1. 当前暂不支持在一局游戏内更改特感刷新方式 Cvar，即 `inf_spawn_method_strategy`，若需要更改请重启当前地图，否则会出现更改完毕后无法刷新特感的情况
2. 当前暂不支持在一局游戏内更改特感刷新策略 Cvar, 即 `inf_spawn_strategy`, 若需要更改请重启一次地图
3. 插件采用三阶增时设计, 小于一阶增时阈值 `SPAWN_TIME_INCREASE_FIRST_THRESHOLD` (默认 5.0) 时使用一阶增时 `SPAWN_TIME_INCREASE_FIRST_ORDER` (默认 0.5s), 超过一阶增时阈值使用二阶增时 `SPAWN_TIME_INCREASE_SECOND_ORDER` (默认 2.0s), 超过二阶增时阈值 `SPAWN_TIME_INCREASE_SECOND_THRESHOLD` (默认 10.0s) 使用三阶增时 `SPAWN_TIME_INCREASE_THIRD_ORDER` (默认 4.0s)。在 6 特时有以下示例: `inf_spawn_duration` 设置为 1s 时使用一阶增时 (默认 0.5s), 则基准时钟 2.5s, 固定时钟周期 1.5s, 动态时钟 2s; 设置为 6s 时使用二阶增时 (默认 2s), 则基准时钟 12s, 固定时钟 8s, 动态时钟 10s; 设置为 16s 时使用三阶增时 (默认 4s), 则基准时钟 28s, 固定时钟 20s, 动态时钟 24s
4. 基准时钟周期计算方式为: `inf_spawn_duration` + (`inf_limit` / 2 > 0 ? `inf_limit` / 2 : 1) * 增时; 固定时钟计算方式为 `inf_spawn_duration` + 增时; 动态时钟计算方式为 `inf_spawn_duration` + (`inf_limit` / 2 - 1 > 0 ? `inf_limit` / 2 - 1 : 1) * 增时
5. 分散刷新时实际复活时间为: 时钟周期 + 1.0s (timers L269 `CreateTimer(1.0, timerSetAllowSpawnFlagHandler, entRef, TIMER_REPEAT);`, 此时钟循环设置允许特感复活)
6. 2024-02-07 版本新增两种找位方式, 可以通过 Cvar `inf_pos_find_method` 设置, 设置为 1 单独使用 `L4D_GetRandomPZSpawnPosition` 函数进行找位; 设置为 2 使用射线找位, 射线仅判断位置可见性及有效性, 位置有效则将射线撞击处 Nav Area 增加 `OBSCURED` 属性 (即使该 Nav Area 可以被看见也允许刷新特感), 接着使用 `L4D_GetRandomPZSpawnPosition` 进行找位; 设置为 3 使用单独射线找位, 可以根据服务器性能自行选择
7. 插件第一次运行时会在 Cvar: `inf_queue_kvfile_path` 值，默认为 `sourcemod/data/` 目录下生成 `infected_queue.cfg` 特感刷新队列配置文件，若当前特感数量未在特感刷新队列中配置特感等待队列信息，则获取特感队列时，插件将会进入错误状态无法运行，如插件因无法获取操作权限等原因导致无法自动创建配置文件，请手动在 `inf_queue_kvfile_path` 值路径中创建 infected_queue.cfg 文件，详细信息见其他图示中特感刷新队列配置文字
   
   infected_queue.cfg 的一个配置示例如下：
   ```java
   "InfectedQueue"
    {
    	"1"
    	{
    		"smoker"	"1"
    		"boomer"	"1"
    		"hunter"	"1"
    		"spitter"	"1"
    		"jockey"	"1"
    		"charger"	"1"
    	}
    	"2"
    	{
    		"smoker"	"1"
    		"boomer"	"1"
    		"hunter"	"1"
    		"spitter"	"2"
    		"jockey"	"2"
    		"charger"	"2"
    	}
        ... 此处省略 3 - 5 的配置
        "6"
    	{
    		"smoker"	"1,2"
    		"boomer"	"4,5,6"
    		"hunter"	"2,3,4"
    		"spitter"	"4,5,6"
    		"jockey"	"4,5,6"
    		"charger"	"4,5,6"
    	}
        ... 此处省略 7 - 31 的配置, 插件默认生成的 infected_queue.cfg 默认生成到 31, 相当于 31 特的配置, 实际使用时请按实际游玩需要特感数量配置
    }
   ``````
8. 更改 Cvar `inf_spawn_method_strategy` 后请重启当前地图，否则可能会出现更改完成后无法刷新下一波特感的情况
9. 如特感刷新不完全情况, 请检查所有特感的 `z_xxx_limit` 值相加是否大于或等于 `inf_limit` 值, 插件刷新的最大特感数量为所有特感 `z_xxx_limit` 之和
10. 生还者数量与 `inf_limit` 特感刷新数量之和大于 `MaxClients (31)` 则超过 `MaxClients` 的特感将会无法刷新并在服务器控制台显示 `CreateFakeClient() returned Null`

## 更新日志
- 2023-08-09: 上传插件与 readme 文件
<details>
<summary>2023-08-23</summary>
1. 修复超过 6 特无法读取特感位置队列的问题<br>
2. 增加 Cvar: inf_unreach_six_alternative 控制是否开启 6 特以下特感轮换 (1,5 特最后一个刷新的特感类型下一波不会出现, 2,3,4 特最后两个刷新的特感类型下一波不会出现, 需要保证该特感类型允许刷新, 即 z_xxx_limit 不为 0)<br>
3. 修复检查基准时钟及动态时钟是否允许被触发相关函数中特感总数及强控阈值获取错误的问题
</details>

<details>
<summary>2023-08-25</summary>
1. 更改一些特感刷新队列的生成策略与 Tank 在场时特感的替换策略<br>
2. 修复特感实际刷新位置为 rayEndPos + PLAYER_HEIGHT 的问题
</details>

<details>
<summary>2023-10-12</summary>
1. 增加 Cvar: inf_pos_init_nav_distance 与 inf_pos_nav_expand_unit 实现找位时 Nav 距离随着时间增大而增大<br>
2. 更改 6 特以下特感轮换实现方式为使用 InfectedEntityReferenceMap 与记录击杀顺序实现<br>
3. 增加特感刷出时实体有效性检验
</details>

<details>
<summary>2023-10-13</summary>
1. 上传插件及 inc 文件，修复 `2023-10-12` 更新导致的分散刷新无法刷特的问题
</details>

<details>
<summary>2023-11-16</summary>
1. 更新 natives_and_forwards.sp 修复直接拉取源码编译由于部分 forward 签名与调用时传参不一而导致的无法刷新特感的情况<br>
2. 修复开启生还者倒地增时时增时时间不准确的问题<br>
3. 修复固定/动态时钟触发时间早于本波次基准时钟触发时间时并未删除基准时钟导致连续刷新两波特感的问题<br>
4. 修复特感刷新时钟部分参数，日志记录不准确的问题
</details>

<details>
<summary>2023-11-27</summary>
1. 增加分散刷新模式对固定时间间隔与动态时间间隔刷新的支持<br>
2. 修复分散刷新模式 round_start 初始化时并未重置特感状态数组的问题<br>
3. inf_pos_find 增加判断条件，随机选择一个射线起始位置后先检查到目标生还者的直线距离，若小于 inf_pos_min_distance 则立即开始随机下一个位置，减少判断过近的位置<br>
4. 优化 6 特以下特感轮换算法, 解决死循环从而导致服务器无响应的问题
</details>

<details>
<summary>2024-02-07</summary>
1. 改进特感轮换机制, 使得集中或分散刷新都支持特感轮换<br>
2. 改进特感找位与刷新机制, 使其资源占用更少<br>
3. 改进目标获取方法, 使其支持获取最高与最低路程目标<br>
4. 增加两种找位方式<br>
5. 优化分散刷新模式代码, 增加健壮性<br>
</details>

---
- 如在使用过程中发现任何 Bug，请提出 issue 说明 Bug 类型及发生时情况，如有报错请附上 log 文件信息 (｡･ω･｡)