## 这是什么
对 Ai Tank 进行增强, 使其更具有攻击性, 目前增强部分包括但不限于<br>

- Tank 连跳
- 扔石头上抬或下压角度计算(增加石头精准度)
- Tank 背后拳(在肘面前的人时同时可以肘到背后的人)
- 对一些小障碍物攀爬加速(不包括梯子)

由于之前旧版本 Ai Tank 的消耗效果并不理想, 因此暂时没有写消耗部分, 若有其他增强意见以及消耗意见可以添加我的 Steam 告知我, 或提交 issue/PR, 插件若有报错请联系我或提交 issue

## 使用方式
1. 将 `l4d2_ai_tank3.txt` 放入 `sourcemod/gamedata` 下
2. 将 `ai_tank3.sp` 和 `stocks.sp` 放入 `sourcemod/scripting` 下并编译, 将编译过后的 `.smx` 文件放入 `sourcemod/plugins` 下
3. enjoy

## 实现细节

### 防止连跳过头
Tank 在空中时检测其合成速度向量 `m_absVecVelocity` 方向, 与其到目标生还者的位置向量的夹角<br>
将向量单位化后进行点积 $|a||b|cos\theta$, 由于 $|a|$=$|b|$ = $1$, 因此直接使用反三角函数解出夹角, 最后将弧度制转为角度<br> $RadToDeg(ArcCosine(GetVectorDotProduct(vVel, vDir)))$<br>
若这个角度超过限定值, 则将 Tank 向目标方向推(旧版本将 Tank 纵向 $z 轴速度设置为 0, 因此 Tank 会按到地上, 且旧版为在空中每帧检测, 因此会出现 Tank 无法起跳的情况, 3.0 增加了检测间隔并保持 $z$ 轴速度)

### 背后拳
Tank 出拳时调用 `CTankClaw::DoSwing()`, 这个函数找到右手手部坐标, 调用 `CTankClaw::SweepFist(Vector const& start, Vector const& end)` 进行拳头碰撞检测, 大约在右拳挥动到身体中间时触发碰撞检测 (SweepHull) 发射一个检测盒, 参数 $start$ 和 $end$ 为检测盒中心的开始与结束坐标, 若玩家在检测盒内则会被击中(没有特感玩家的情况下仅检测击中一名生还者, 有特感玩家的情况下则会遍历所有生还者进行碰撞检测), 因此只需要通过 `SDKCall` 调用 `CTankClaw::SweepFist(...)` 将 $start$ 和 $end$ 坐标传入身体背后的坐标即可

### 扔石头时上下 pitch 角度计算
使用抛体运动公式计算, 抛射物位置随时间 $t$ 的关系为<br>
水平位移: $x(t)=v_0*cos\theta*t$ ($v_0$ 为物体初速度)<br>
垂直位移: $y(t)=v_0*sin\theta*t-\frac{1}{2}*g*t^2$<br>
计算 Tank 与目标的水平距离 $d$, 垂直距离 $h$<br>
得到以下式子:<br>
1. $d=v_0*cos\theta*t$
2. $h=v_0*sin\theta*t-\frac{1}{2}*g*t^2$<br>
   
将 $1$ 式的时间 $t$ 使用其他字母表示, 带入到 $2$ 式中得到<br>
$h=v_0*sin\theta*(\frac{d}{v_0*cos\theta}) - \frac{1}{2}*g*(\frac{d}{v_0*cos\theta})^2$<br>
接着进行化简得到<br>
$h=d*tan\theta - \frac{1}{2}*g*d^2*(\frac{1}{v_0*cos\theta})^2$<br>
又因为 $\frac{1}{cos^2\theta}$ = $1 + tan\theta$<br>
可以将公式转化为 $tan^2\theta$ 的二次多项式如下<br>
$h=d*tan\theta - \frac{g*d^2}{2*v_0^2}(1+tan^2\theta)$<br>
整理得到<br>
$\frac{g*d^2}{2*v_0^2}tan^2\theta+\frac{g*d^2}{2*v_0^2}-d*tan\theta+h=0$<br>解这个二次方程, 使用求根公式判断有无解, 无解则以当前石头初速度不可击中目标, 若有解则得到<br>
$tan\theta = \frac{v_0^2 \pm \sqrt{v_0^4 - g^2*d^2 + 2*g*h*v_0^2}}{g*d}$<br>
使用反三角函数 $Arctan(tan\theta)$ 即可得到抛射角度(弧度制), 取减号分支(低抛, 若取加号分支则为高抛解, 目标离 Tank 越近则出手上抬角度越大), 即<br>
$tan\theta = \frac{v_0^2 - \sqrt{v_0^4 - g^2*d^2 + 2*g*h*v_0^2}}{g*d}$<br>
最后使用 $RadToDeg(Arctan(tan\theta))$ 转换为角度即可, 由于 $pitch$ 角向上抬为负, 向下压为正, 因此实际使用 $eyeAng[0] -RadToDeg(Arctan(tan\theta))$ 得到最终抛射角度
<br>

> Tank 石头受到的重力并不是 `sv_gravity` 值, 而是通过 `sv_gravity` * 石头实体属性 `m_flGravity` 值得到重力, 其中 `m_flGravity` 值默认为 0.4, 因此石头受到的重力为 `sv_gravity` (默认 800) * `m_flGravity` (默认 0.4) = 320

## 代码参考
1. [umlka/l4d2. ai_tank.sp](https://github.com/umlka/l4d2/blob/main/AI_HardSI/ai_tank.sp)
2. [febf0102/L4D1_2-Plugins. AI_HardSI. Ai_Tank.sp](https://github.com/fbef0102/L4D1_2-Plugins/blob/master/AI_HardSI/addons/sourcemod/scripting/AI_HardSI/AI_Tank.sp)
3. breezy/AI_HardSI. AI_Tank.sp

## 实用插件
1. [l4d_sweep_fist_path. Tank 一拍多](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_sweep_fist_patch)
2. [smart_ai_rock. 禁用低抛 E 砖并去除 Tank 扔石头后视角锁定石头出手位置 5 秒](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/smart_ai_rock)
3. [skip_tank_taunt. 跳过 Tank 石头击中后的捶胸嘲讽动作与锤人的怒吼动作并加速 Tank 攀爬障碍物动作](https://forums.alliedmods.net/showthread.php?t=336707&highlight=tank+taunt)