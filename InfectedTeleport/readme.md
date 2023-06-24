# infected_teleport

## 插件介绍
- 本插件提供落后特感的传送功能，特感传送找位基于使用 `TR_TraceRayFilterEx()` 函数的射线找位，支持更改传送距离、单局允许传送次数、传送检测间隔等功能
- 插件会为每个在场特感根据 `teleport_target_type` 分配目标，特感落后时会以目标为中心，`teleport_max_distance` 为最大范围 **绘制正方形网格，** 在网格中使用 `TR_TraceRayFilterEx()` 垂直射线找位并记录找位帧数， **若位置满足要求则传送，** 若找位帧数大于 `teleport_expand_frame` 则开始 **扩大最大范围，** 直到 `teleport_max_nav_distance` 大小（默认 2000），若最大范围已达到 `teleport_max_nav_distance` 大小且 2 秒内仍然找不到位置，则会 **暂停找位** `FIND_POS_DELAY`（默认 5 秒）继续尝试找位

```Java
// 是否开启特感传送插件
teleport_enable 1
// 特感无生还者目标视野多少秒则开始传送找位
teleport_check_time 3.0
// 每隔多少秒检测一次在场特感的可视状态
teleport_check_interval 1.0
// 哪些特感种类允许被传送
teleport_infected_class 1,2,3,4,5,6
// 特感传送位置距离目标生还者最近直线距离
teleport_min_distance 250.0
// 特感传送位置距离目标生还者最远直线距离（建议不要小于 800 否则位置很少）
teleport_max_distance 800.0
// 特感传送的位置距离目标生还者的最大 Nav 距离（最小值为 teleport_max_distance 值 + 1.0）
teleport_max_nav_distance 2000.0
// 特感落后目标生还者这么多则试图将其传送
teleport_start_distance 600.0
// 特感传送找位时经过这么多游戏帧还没有找到位置则扩大找位范围
teleport_expand_frame 50.0
// 每只特感单局允许被传送的最大次数（-1：无限制）
teleport_max_count -1
// 特感传送后回复失去的生命之这么多百分比的生命值（失去 300 则回复 300 * 50% = 150，0：关闭）
teleport_health_restore 50
// 特感传送的位置是否需要在目标生还者当前路程之前
teleport_pos_ahead 1
// 特感传送检测是否可以被生还者看见时是否忽略倒地生还者
teleport_ignore_incap 0
// 特感传送目标选择（1：随机生还者，2：离自身最近的生还者，3：路程最高的生还者，4：路程最低的生还者）
teleport_target_type 1
// 是否在特感传送前将其设置为透明，传送后恢复
teleport_transparent 1
```

## 更新日志
- 2023-4-1：上传插件与 readme 文件，修正找位射线撞击位置可视高度
- 2023-4-16：修复代码 bug（传送位置是否卡住判断错误，Nav 距离判断错误），增加特感传送时是否设置透明，传送后恢复原可见度功能（防止 Spitter 和 Hunter 传送时拉丝），将传送位置最大 Nav 距离从原 Cvar：`z_spawn_range` 更改为使用单独 Cvar：`teleport_max_nav_distance`，修复特感即将传送时未检测是否可传送导致的相关问题
- 2023-6-24：修复使用 FindValue 查找当前特感是否在某个生还的传送队列中时的报错问题