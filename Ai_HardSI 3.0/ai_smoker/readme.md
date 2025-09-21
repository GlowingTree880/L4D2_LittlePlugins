## 这是什么
对 Ai Smoker 进行增强, 使其更具有攻击性, 目前增强部分包括但不限于<br>

- Smoker 连跳
- Smoker 拉到生还者时将视角转向背后
- Smoker 拉人被推无技能时防止逃跑 (将逃跑行为转为追击目标生还者)

## Requirements

1. [[TF2 & L4D & L4D2] Actions](https://forums.alliedmods.net/showthread.php?t=336374). Nextbots 行为树管理拓展

## 使用方式
假设已安装 Actions 拓展
1. 将 `l4d2_ai_smoker.txt` 放入 `sourcemod/gamedata` 下
2. 将 [logger2.inc](https://github.com/GlowingTree880/L4D2_LittlePlugins/blob/dev/lib/logger2.inc) 放入 `sourcemod/scripting/include` 下
3. 将 `ai_smoker3.sp` 和 `stocks.sp` 放入 `sourcemod/scripting` 下并编译, 将编译过后的 `.smx` 文件放入 `sourcemod/plugins` 下
4. enjoy

## 实现细节

### 防止 Smoker 无技能逃跑
1. Smoker 拉到人后, 处于 `SmokerRetreatToCover` (Smoker 退避到掩体) 行为, 一旦被推开, 将会退避到一个生还者无法看到的位置等待攻击
2. 使用 Actions 拓展 Hook 行为节点的生成, 判断节点名称为 `SmokerRetreatToCover` 则为其添加自定义 `OnUpdate` (每帧会调用这个函数更新该行为) 函数

```java
    SmokerAttack
    |__ SmokerRetreatToCover
```

3. 函数中使用 `L4D2_CommandABot(actor, target, BOT_CMD_MOVE, g_AiSmokers[actor].m_vecMoveToPos);` 强制 Smoker 移动到目标生还者位置 (此时将会生成一个 `BehaviorMoveTo` 行为节点将原先的 `SmokerRetreatToCover` 节点暂停, 优先执行移动逻辑)
4. 接着每隔 `ai_smoker3_anti_retreat` 时间判断当前目标生还者的坐标与上一次 `L4D2_CommandABot(...)` 令 Smoker 移动到的坐标是否相同, 若不相同则将当前 `BehaviorMoveTo` 行为设置为完成, 行为节点销毁, `SmokerRetreatToCover` 节点取消暂停, 继续触发 `SmokerRetreatToCover` 的 `OnUpdate` 回调函数, 再次基于当前目标生还者的坐标使用 `L4D2_CommandABot(...)` 强制 Smoker 移动到最新的目标生还者位置

```java
    SmokerAttack                        SmokerAttack
    |__ SmokerRetreatToCover    -->     |__ SmokerRetreatToCover
     |__ BehaviorMoveTo

    --> SmokerAttack
        |__ SmokerRetreatToCover
         |__ BehaviorMoveTo
```

5. 由于目标生还者位置在生还者脚底, Smoker 靠近生还者时会被生还者模型阻挡一直右键攻击生还者, 此时 `BehaviorMoveTo` 行为并不会完成, 因此还需要 Hook `BehaviorMoveTo` 状态, 为其添加自定义 `OnUpdate` 函数, 函数中判断若 Smoker 舌头技能已经准备就绪, 则强制将 `BehaviorMoveTo` 行为行为更改为 `SmokerMoveToAttackPositon` 行为, 控制 Smoker 进入攻击位置, 进入到攻击位置就绪后产生 `SmokerTongueVictim` 状态控制其发射舌头, 实现无技能防止 Smoker 逃跑效果


```java
    SmokerAttack                                SmokerAttack
    |__ SmokerMoveToAttackPosition      -->     |__ SmokerTongueVictim
```

## 代码参考
1. [umlka/l4d2. ai_tank.sp](https://github.com/umlka/l4d2/blob/main/AI_HardSI/ai_tank.sp)
2. breezy/AI_HardSI. AI_Smoker.sp
3. [BHaType/Actions ext AlliedModders Forum 部分示例代码](https://forums.alliedmods.net/showthread.php?t=336374)

## 实用插件
1. [[L4D2] Air Ability Patch](https://forums.alliedmods.net/showthread.php?p=2660278). BHaType. 控制特感是否允许在空中释放技能
2. [smoker_anim_fix](https://github.com/HoongDou/L4D2-HoongDou-Project/tree/master/smoker_anim_fix). HoongDou. 修复 Ai Smoker 发射舌头时不会像玩家 Smoker 发射舌头一样弯下腰而是保持直立的问题

## 现存待修复的 Bug
1. 目前使用 Actions Constructor 构造器构造 SmokerMoveToAttackPosition 行为, 可能会因为传参不当或其他原因导致服务器崩溃, 待测试, 若崩溃可尝试使用 SdkCall 调用构造函数来初始化行为, 代码如下
```java
    // 在 ai_smoker3.sp 顶部全局 Handle 定义处添加 g_hSdkSmokerMove2AtkPos 定义
    Handle
        g_hSdkSmokerMove2AtkPos,
        g_hSdkGetRunTopSpeed;

    // 在 OnAllPluginsLoaded 函数中添加如下代码准备
    StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, SIG_SMOKER_MOVE_2_ATTACK_POSITION);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkSmokerMove2AtkPos = EndPrepSDKCall();
	if (!g_hSdkSmokerMove2AtkPos)
		SetFailState("Failed to find signature: %s in gamedata file: %s.", SIG_SMOKER_MOVE_2_ATTACK_POSITION, GAMEDATA);
    
    // 将 createSmokerMoveToAttackPosition 函数更改为如下形式
    stock BehaviorAction createSmokerMoveToPosition(int target) {
        if (!IsValidSurvivor(target))
            return INVALID_ACTION;
        
        BehaviorAction action = ActionsManager.Allocate(18480);
        SDKCall(g_hSdkSmokerMove2AtkPos, action, target);
        return action;
    }
```
