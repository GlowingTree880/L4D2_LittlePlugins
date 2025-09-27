## 这是什么
对 Ai Tank 进行增强, 使其更具有攻击性, 目前增强部分包括但不限于<br>

- Tank 连跳
- 扔石头上抬或下压角度计算(增加石头精准度)
- Tank 背后拳(在肘面前的人时同时可以肘到背后的人)
- 对一些小障碍物攀爬加速(不包括梯子)

由于之前旧版本 Ai Tank 的消耗效果并不理想, 因此暂时没有写消耗部分, 若有其他增强意见以及消耗意见可以添加我的 Steam 告知我, 或提交 issue/PR, 插件若有报错请联系我或提交 issue

## 使用方式
1. 将 `l4d2_ai_tank3.txt` 放入 `sourcemod/gamedata` 下
2. 将 [logger2.inc](https://github.com/GlowingTree880/L4D2_LittlePlugins/blob/dev/lib/logger2.inc) 放入 `sourcemod/scripting/include` 下
3. 将 `ai_tank3.sp` 和 `stocks.sp` 放入 `sourcemod/scripting` 下并编译, 将编译过后的 `.smx` 文件放入 `sourcemod/plugins` 下
4. enjoy

## 实现细节

### 防止连跳过头
Tank 在空中时检测其合成速度向量 `m_absVecVelocity` 方向, 与其到目标生还者的位置向量的夹角

将向量单位化后进行点积 $|a||b|cos\theta$, 由于 $|a| = |b| = 1$, 因此直接使用反三角函数解出夹角, 最后将弧度制转为角度

$RadToDeg(ArcCosine(GetVectorDotProduct(vVel, vDir)))$

若这个角度超过限定值, 则将 Tank 向目标方向推(旧版本将 Tank 纵向 $z$ 轴速度设置为 0, 因此 Tank 会按到地上, 且旧版为在空中每帧检测, 因此会出现 Tank 无法起跳的情况, 3.0 增加了检测间隔并保持 $z$ 轴速度)

### 背后拳
Tank 出拳时会调用 `CTankClaw::SweepFist(Vector const& start, Vector const& end)` 进行拳头碰撞检测, 从 `start` 到 `end` 位置进行碰撞检测, 若击中生还者则造成拳击效果 (无玩家特感的模式下只检测一名生还者, 否则循环检测所有生还者), 因此直接使用 `SdkCall` 调用 `CTankClaw::SweepFist` 将 Tank 坐标 `ai_tank3_back_fist_range` 的生还者坐标传入 `start` 与 `end` 即可
> 若无玩家特感的模式 (如战役模式) 想要实现背后拳效果, 建议安装 [l4d_sweep_fist_path. Tank 一拍多](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_sweep_fist_patch) 插件, 否则 Tank 无法同时攻击多个生还, 可能导致 Tank 攻击面前的生还者而无法攻击到背后的生还者

### 扔石头时上下 pitch 角度计算
使用抛体运动公式计算, 抛射物位置随时间 $t$ 的关系为

```math
水平位移: x(t)=v_0*cos\theta*t\quad\text(v_0 为物体初速度)\\
垂直位移: y(t)=v_0*sin\theta*t-\frac{1}{2}*g*t^2
```

计算 Tank 与目标的水平距离 $d$, 垂直距离 $h$, 得到以下式子

```math
d=v_0*cos\theta*t\\
h=v_0*sin\theta*t-\frac{1}{2}*g*t^2
```

将 $1$ 式的时间 $t$ 使用其他字母表示, 带入到 $2$ 式中得到

```math
h=v_0*sin\theta*(\frac{d}{v_0*cos\theta}) - \frac{1}{2}*g*(\frac{d}{v_0*cos\theta})^2
```

接着进行化简得到
```math
h=d*tan\theta - \frac{1}{2}*g*d^2*(\frac{1}{v_0*cos\theta})^2
```

又因为$\frac{1}{cos^2\theta} = 1 + tan^2\theta$

可以将公式转化为 $tan^2\theta$ 的二次多项式如下

```math
h=d*tan\theta - \frac{g*d^2}{2*v_0^2}(1+tan^2\theta)
```

整理得到

```math
\frac{g*d^2}{2*v_0^2}tan^2\theta+\frac{g*d^2}{2*v_0^2}-d*tan\theta+h=0
```

解这个二次方程, 使用求根公式判断有无解, 无解则以当前石头初速度不可击中目标, 若有解则得到

```math
tan\theta = \frac{v_0^2 \pm \sqrt{v_0^4 - g^2*d^2 + 2*g*h*v_0^2}}{g*d}
```

使用反三角函数 $Arctan(tan\theta)$ 即可得到抛射角度(弧度制), 取减号分支(低抛, 若取加号分支则为高抛解, 目标离 Tank 越近则出手上抬角度越大), 即
```math
tan\theta = \frac{v_0^2 - \sqrt{v_0^4 - g^2*d^2 + 2*g*h*v_0^2}}{g*d}
```

最后使用 $RadToDeg(Arctan(tan\theta))$ 转换为角度即可, 由于 $pitch$ 角向上抬为负, 向下压为正, 因此实际使用 $eyeAng[0] -RadToDeg(Arctan(tan\theta))$ 得到最终抛射角度

> Tank 石头受到的重力并不是 `sv_gravity` 值, 而是通过 `sv_gravity` * 石头实体属性 `m_flGravity` 值得到重力, 其中 `m_flGravity` 值默认为 0.4, 因此石头受到的重力为 `sv_gravity` (默认 800) * `m_flGravity` (默认 0.4) = 320

> 若有错误还请指出😶‍🌫️

> 若网页无法显示数学公式可以尝试安装浏览器插件: [MathJax Plugin for Github](https://chromewebstore.google.com/detail/mathjax-plugin-for-github/ioemnmodlmafdkllaclgeombjnmnbima/related)

## 代码参考
1. [umlka/l4d2. ai_tank.sp](https://github.com/umlka/l4d2/blob/main/AI_HardSI/ai_tank.sp)
2. [febf0102/L4D1_2-Plugins. AI_HardSI. Ai_Tank.sp](https://github.com/fbef0102/L4D1_2-Plugins/blob/master/AI_HardSI/addons/sourcemod/scripting/AI_HardSI/AI_Tank.sp)
3. breezy/AI_HardSI. AI_Tank.sp

## 实用插件
1. [l4d_sweep_fist_path. Tank 一拍多](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_sweep_fist_patch)
2. [smart_ai_rock. 禁用低抛 E 砖并去除 Tank 扔石头后视角锁定石头出手位置 5 秒](https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/smart_ai_rock)
3. [skip_tank_taunt. 跳过 Tank 石头击中后的捶胸嘲讽动作与锤人的怒吼动作并加速 Tank 攀爬障碍物动作](https://forums.alliedmods.net/showthread.php?t=336707&highlight=tank+taunt)

## 现存待修复的 Bug
1. 音理说防止连跳过头会导致 Tank 起飞? (目前未能复现, 待修复)

## 更新日志
<details>
<summary>2025-08-28</summary>
1. 修复背后拳 Linux 签名错误导致的报错<br>
2. 将石头出手时的目标选择从 <strong>先使用 Tank 默认目标, 若默认目标不可视再选择最近可视目标</strong>, 更改为 <strong>直接选择最近可视目标</strong><br>
3. 修复一些低级错误
</details>

<details>
<summary>2025-08-30</summary>
1. 修改背后拳碰撞检测逻辑, 感谢 Forgetest<br>
2. 为石头出手添加目标移动预测逻辑, 类似于原版克的提前量预测, 适用于目标单向移动的情况, 同时修正了目标站立不动时低抛 E 砖落点偏移导致无法砸中生还者的问题, 建议将 Cvar: <strong>z_tank_throw_force</strong> 更改为 1000 (默认 800) 以获得更好的效果<br>
3. 修复一些低级错误
</details>

<details>
<summary>2025-09-04</summary>
1. 添加 Cvar: <b>ai_tank3_back_fist_max_spd</b> 用于调整 Tank 使用通背拳时的最大速度 (超过这个速度则不允许使用通背拳), 避免 Tank 在追逐目标时误伤其他生还者, 降低难度<br>
2. 添加 Cvar: <b>ai_tank3_jump_rock</b> 用于控制 Tank 是否允许使用跳砖<br>
3. 将空中防止连跳过头的加速度从 <b>当前速度+一次连跳加速度</b> 更改为 <b>Tank 当前模式下的最大奔跑速度+一次连跳加速度</b>, 使其不会突然被推向目标, 降低难度<br>
4. 为石头出手时的目标选择增加排除条件, 排除 <b>倒地的以及正在被 Hunter 与 Charger 控制的生还者</b>
</details>

<details>
<summary>2025-09-27</summary>
1. 修改连跳逻辑, 先前版本默认 Tank 有生还者视野时不会向后退, 因此无论向前还是向后加速度方向均指向生还者方向, 导致部分地形 Tank 有生还者视野时需要向后退寻路, 后退连跳时速度与加速度方向不一致导致连跳减速, 此版本更改为后退连跳时加速度方向与速度方向一致<br>
2. 修复一些低级错误
</details>