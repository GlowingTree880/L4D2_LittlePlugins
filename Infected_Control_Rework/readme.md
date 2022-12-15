# Infected Control Rework

## 插件介绍

- 本插件为基于原 [Infected Control](https://github.com/GlowingTree880/L4D2_LittlePlugins/tree/main/Infected_Control) 的修改增强版本，后续将会持续维护这一刷特插件，停止维护原 Infected Control 刷特插件
- 插件默认开启控制台输出特感队列生成与其他相关信息，方便调试时维护，如需要关闭可修改 .sp 源码 11 行处宏定义 `#define DEBUG_ALL 1` 为 `#define DEBUG_ALL 0` 即可

---

- 本插件目前仍处于开发阶段，主要用于药役模式特感刷新控制，已支持战役模式特感刷新，简单模式（仅使用函数刷特，适用于三方图）正在开发中，如有任何 Bug 或错误信息或更好的改进建议欢迎提出 (｡･ω･｡)

## 名词解释

- 刷新集合：保存着下一波刷新的特感种类序号的集合，下一波特感刷新将会按照次序刷新
- 位置集合：保存着射线找位找到的位置的集合
- 延迟刷新集合：保存着每一波需要延迟刷新的特感的集合，当射线找位找到位置且有任何生还者被控时或超过最大延迟刷新等待时间时，依次刷新该集合中的特感
- 预传送集合：当某个特感满足传送条件时，立即将其踢出，并将特感种类序号加入该集合中，同时允许射线找位，找到位置则依次刷新该集合中的特感

## 部分说明

- 特感刷新联合采用 **射线找位**（`TR_TraceRayFilterEx()`） 与 **函数找位**（`L4D_GetRandomPZSpawnPosition()`） 刷新特感，具体细节见下：

  1. 第一个生还者出门第一波使用 **射线找位** 刷新特感，找到位置立即刷新，超过最大找位时间仍为找到转为使用 **函数找位** 刷新特感，第一波特感刷新
  2. 后续每波相同，首先使用 **射线找位** 寻找有效刷新位置加入 **位置集合** 中，如超过最大找位时间未填满位置集合则停止找位，进行特感刷新逻辑
  3. 特感刷新前，先对位置集合中的位置数据采用 **按高度降序** 或 **按距离升序** 的排序策略进行排序（最优位置判别），接着每次使用位置集合的 **第一个位置** 刷新特感
  4. 特感刷新前，如位置集合中没有位置，则直接使用 **函数找位** 刷新特感
  5. 当特感刷新到 **需要进行延迟刷新** 的特感时，不会立即刷新，而会加入 **延迟刷新集合** 中，此时允许继续找位，当 **找到有效位置且有任何生还者被控** 则 **立即刷新** 延迟刷新集合中的第一个特感，如超过最大延迟刷新等待时间，则使用 **函数找位** 强制刷新延迟刷新集合中的特感
  6. 特感复活后，将会进行一次向目标生还者方向的 **加速跳跃**（request by 音理酱）**[已弃用]**
  7. 判别某个坐标是否可以进行特感刷新条件如下：<br>
     ```Java
      // 当前位置对生还者不可见
      !canBeVisibleBySurvivor(visiblePos)
      // 当前位置在有效 Nav Area 上
      isOnValidMesh(rayEndPos)
      // 当前位置距离生还者的距离大于最小特感生成距离
      GetVectorDistance(rayEndPos, targetSurvivorPos) >= g_hMinSpawnDist.FloatValue
      // 当前位置到生还者的 Nav 距离小于最大特感生成距离（不判断 -1.0 有效性，否则会导致某些地方，如 c2m2 开局安全屋房顶无法刷新特感）
      navDist <= g_hMaxSpawnDist.FloatValue * 2.0 &&
      // 当前位置不会卡住即将刷出的特感
      !isPlayerWillStuck(rayEndPos);
      // 如果开启禁止特感刷新在安全区域内则会增加以下判断
      L4D_GetNavArea_SpawnAttributes(rayEndNav) % CHECKPOINT（2048） != 0;
     ```
  8. 判断玩家是否可见某个坐标的检测高度更改为 72，降低特感脸刷概率（11-28 插件为 20）

## Cvars

```Java
// 一次刷新的特感数量限制
l4d_infected_limit 6
// 特感复活时间（秒）
versus_special_respawn_interval 16.0
// 位置集合最大长度（默认为特感数量）
inf_find_pos_limit [6]
// 最小刷新距离
inf_min_spawn_dist 250
// 最大刷新距离
inf_max_spawn_dist 500
// 以当前生还者作为中心点进行找位的帧数
inf_evert_target_frame 15
// 发射了多少次找位射线后每帧扩大 1 单位找位范围
inf_expand_frame 50
// 最大允许找位时间（秒）
inf_max_find_pos_time 2
// 特感刷新时间超过 9 秒的加时（原本 8 秒）
inf_gt9_add_time 6
// 特感刷新时间未超过 9 秒的加时（原本 4 秒）
inf_lt9_add_time 1
// 特感满足传送条件（距离大于传送距离且无视野）多少秒后允许传送
inf_pre_teleport_count 3
// 特感传送距离
inf_teleport_distance 250
// 路程最大的玩家距离路程最小的玩家多远将路程最大的玩家视为跑图玩家
inf_ahead_target_distance 1500
// 某种特感在队列中允许的刷新位置
inf_in_queue_pos_ [smoker, boomer, hunter, spitter, jockey, spitter, charger]
// 特感默认找位策略（1：按距离升序，2：按高度降序）
inf_spawn_stratergy 2
// 一个位置允许刷新多少只特感
inf_one_pos_limit 2
// 是否允许一个位置刷新随机（1 - 特感上限）只特感
inf_allow_one_pos_random_limit 0
// 是否允许特感延迟刷新
inf_allow_delay_spawn 1
// 延迟刷新的特感种类
inf_delay_spawn_infected 4
// 最大延迟刷新等待时间（秒）
inf_delay_spawn_time 2
// 6 特以上是否保证每种特感均生成一只
inf_allow_all_spawn_one 1
// 是否开启日志记录信息（没什么用处）
inf_enable_log 1
```

## 插件更新日志：

- 2022-12-12：上传第一版本，添加 readme 文件
- 2022-12-13：将特感生成时向生还者方向推动功能更改为使用单独插件 [Infected Push When Spawn](https://github.com/GlowingTree880/L4D2_LittlePlugins/tree/main/InfectedPushWhenSpawn) 管理，本刷特插件不再提供这一功能
<details>
<summary>2022-12-15：</summary>
<pre>

1. 增加设置导演系统 Cvar
2. 去除口水死亡立刻踢出导致无声口水的 Bug
3. 修复第一波特感未完全使用射线刷出导致第二波无法生成特感的 Bug
4. 修复待传送特感找不到位置而导致长时间特感不刷新的 Bug
5. 增加每次传送射线找位时间为最大允许找位时间，超过则使用函数刷新待传送特感
6. 增加是否在安全屋内刷新特感的选项
</pre>
</details>
