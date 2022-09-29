# GlowingTree's Server Little Plugins
* 这里是一个存放着一些自用，因为个人突发奇想或好友建议而制作的L4D2插件的小仓库，将会不间断上传包含服务器功能，游戏玩法等多种类型的插件
* 刚刚开始学着写L4D2的插件，可能只注重实现了功能而忽略了架构和其他的一些方面，还可能会有非常非常多的Bug，目前还在向大佬学习中，如果发现了Bug欢迎向我提出哦( ･ω< ) 
> This is a small project whitch stores some L4D2 plug-ins made since sudden whims or suggestions from friends. Various types of plug-ins including server functions, gameplay, etc. will be uploaded continuously（Sorry for my poor English(；へ：)）.
<br>I have just started to learn to write L4D2 plug-ins. So may only focus on the realization of the function and ignore the architecture and some other aspects. There may also be a lot of bugs. Now I am keep on learning from the great guys. If you find a bug or something strange when using the plugin, any report is appreciated.
* [我的Steam个人资料链接（My Steam Profile Link）](https://steamcommunity.com/id/saku_ra/)

# Require
* Sourcemod 1.10 (or newer)
* [Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?p=2684862)

# Plugins
* **KillRegain：** When killing a certain number of special infected or common infected, this plugin will restore certain number of bullets or HP, the bullets can be restored to the front clip or the backup clip
<br>（当击杀一定数量的特殊感染者或丧尸时，这个插件将会回复一定数量的子弹或血量，子弹可选择回复至前置弹夹或后备弹夹）
* **KillSound：** When killing a common infected or special infected, this plugin will display a sound, when performing a headshot, it will dispaly a special sound
<br>（当击杀丧尸或特殊感染者时，这个插件将会播放一个提示音，当爆头击杀时，将会播放一个特殊提示音）
* **Headshot！：** When only a headshot kills a common infected to make it die, the same goes for melee weapons
<br>（当只有爆头丧尸才会使其死亡，近战武器也相同）
* **DefibrillatorHealingField：** In the case of holding the defibrillator, you can aim at one survivor who is not full of blood, then press the E (USE) key. A treatment field (range) will be triggered to treat the target (not dead/incapacitated) Multiple survivors within the range (recovery of permanent health + temporary health) can be restored.
<br>（手持电击器的情况下，可以将目标对准未满血的生还者按住E（USE）键，将会触发一个治疗场（范围），对需要治疗的对象（未死亡/未倒地）进行治疗（回复实血+虚血）范围内的多个对象皆可受到治疗）
* **TankAnnounce：** In any gamemode, The plugin will announce a message when Tank spawn. The message type can be selected (chat/hint text/central text. Compared with l4d_tank_announce in ZoneMod, the depend to the l4d_tank_control_eq plug-in is deleted.
<br>（任意模式下，Tank刷新将会进行提示的插件，提示类型：聊天框/中央文本框提示/中央文字提示，相比ZoneMod中的TankAnnounce删除了对 l4d_tank_control_eq 插件的调用）
* **JockeyRideSpeed：** A plugin that can customize the movement speed of the survivors after jockeys ride on them (also can customize the movement speed of the survivors after jockeys ride end)
<br>（任意模式下，允许自定义 Jockey 骑乘到生还者之后携带生还者的移动速度，同时允许自定义Jockey死亡或被救下后被骑乘的生还者速度的插件）
* **ChinaQingGong：** If a player not dead or incapacitated, it is allowed to hold down the crouch button for a certain period of time and combine the space bar or move keys to obtain the effect of jumping up or sprinting in the corresponding direction at a longer distance (China Qinggong)
<br>（生还者（未死亡/未倒地）状态下，允许按住蹲下键一定时长配合空格键或方向键获得更远距离的向上跳跃或向对应方向冲刺的效果（中国轻功））
* **Ai_HardSi：** Improves the AI behaviour of special infected
<br>（通过改进 Ai 特感的行为来增强游戏性，整合了其他大佬的一些功能，同时添加了一些自己想到的功能）
* **Infected_Control：** A simple infected spawner
<br>（参考国内主流药役插件 AnneServer （7-7与2月15日版本）中核心插件 infected_control.smx 反编译修复编写，添加了一些其他功能的射线找位刷特，传送特感的插件，注：请修改游戏模式为 versus，否则只能刷3特，具体原因目前还在研究中）
* **Text：** Use with Infected_Control.smx, Auto start spawn when the first survivor leave safe area, and indicates the current difficulty
<br>（需要配合 Infected_Control 插件使用，否则需要手动刷特！参考国内主流药役插件 AnneServer （2月15日版本）中核心插件 text.smx 反编译并修复编写，此插件主要负责提供 !xx，!zs，!kill 指令的功能，显示当前难度，自动关闭大厅匹配，自动出门刷特，团灭时更改游戏模式为写实等功能）
* **ServerFunction：** A simple plugin which provides base server functions
<br>（参考国内主流药役服务器 AnneServer （2月15日版本）中核心插件 server.smx 反编译修复编写，主要提供 !jg !away !ip !restart !restartmap 指令的功能以及玩家加入退出显示，出门物资发放，秒妹回血，motd页面标题，链接控制等功能，增加安全屋内无限子弹&无敌，生还者团队未满情况下可通过 !jg 指令选择喜欢的人物功能）
* **AsiAi：** Advanced Special Infected Ai
<br>（参考国内主流药役服务器 AnneServer （2月15日版本）中 l4d2_tank_throw.smx 反编译修复编写，实际为 def075 Asiai 0.4 版本，增强特感攻击性）
* **ZhenduiMode：** Target mode, the admin can type !zhendui in chat to turn it on and off. After turning on and selecting a player as the target, the special infected on spot  and subsequent resurrection will preferentially target this player until the player is pinned or the mode is turned off
<br>（针对模式，管理员输入 !zhendui 可开启关闭，开启并选择某位玩家作为针对目标后，在场及后续复活的特感将优先以这位玩家为目标，直到这位玩家被控或关闭针对模式）
* **TankStatusPanel：** After the Tank spawning, display the current tank status panel to human spectators and infected players, including the current tank HP, control, fire status, whether it is in bile status, and the current Tank controller, etc.
<br>（Tank 刷新后，对旁观者与特感方显示的当前 Tank 状态面板，包含当前 Tank 血量，控制权，着火状态，是否处在胆汁状态中，与当前 Tank 控制者等信息）
* **ThrowPunish：** Limit the usage count of each player in the game can use each type of projectile (molotov, vomitjar, pipebomb) or the total usage count of three projectiles in a round (such as c2m1, c2m2), and punish players who use more than the times limit and players who throw molotov into safeareas
<br>（限制游戏内每位玩家在一关（如 c2m1，c2m2）中能够使用每种投掷物（燃烧瓶，胆汁，土制炸弹）的次数或三种投掷物的总次数，并且对使用超过次数上限的玩家进行惩罚与对向安全区域中投掷燃烧瓶的玩家给予惩罚（喜欢烧烤队友48））
* **HappyDPS：** a happy DPS infected (Spitter, Boomer) plugin, this plugin controls whether there is still a Tank on the field that prohibits opening and closing the end saferoom door and controls melee damage to DPS special infected
<br>（令人快乐的 DPS 特感（Spitter，Boomer）插件，控制近战对 DPS 特感的伤害同时令 DPS 特感免受除了近战伤害外的其他武器伤害，并且能控制是否在场上还有 Tank 存在时禁止开关终点安全门，阳间服必备）
* **SpecVote：** Vote to move a player who were not originally in the spectator team to the spectator team
<br>（任意或指定团队成员可发起投票，将当前不在旁观者团队内的玩家移动至旁观者团队，防止出现演员）
* **TankDamageAnnounce：** When the last spawned tank dies, print survivor's damage to this tank and survivor's injuries amount
<br>（当最后一个刷新的 Tank 死亡时，打印生还者对该 Tank 的伤害及吃拳/石/铁的数量及生还者受到该 Tank 的伤害情况）
* **UnsilentHunterJockey：** After hunter or jockey spawning and they are not pinning someone, then make them emit an alert sound at regular intervals
<br>（当 Hunter 与 Jockey 刷新后并在 Hunter 未在飞扑与它们未在控人时，令他们固定间隔发出警示音）
* **ServerRPGwithDatabase：** A plug-in that uses MySQL database to record player level/points/skills and other information
<br>（配合使用 MySQL 数据库记录玩家等级/B数/技能/其他信息的插件）
* **BossController：** A plug-in that in campaign or versus (may support other modes) allows the Boss to be spawned on a fixed distance
<br>（战役或对抗（可能支持其他模式）允许在固定路程刷新 Boss，支持投票更改 Boss 刷新位置）

  * 注：上述有关 AnneServer 的插件源代码 **非 AnneServer 对应插件实际源代码**，为通过反编译 .smx 二进制插件文件并修复反编译后的文件内容得到<br>（The above plugins's code which related to AnneServer **is NOT the actual code for the the corresponding plugin** is obtained by decompiling the .smx binary file and repairing the content of the decompiled file.）
  * 关于反编译行为的合理性与 Sourcemod GPL version 3 许可证及编写的插件/拓展与许可证间的关系可查阅：<br>[SourceModLicense](https://www.sourcemod.net/license.php)<br>[Quoted from Azelphur](https://forums.alliedmods.net/showpost.php?p=1648709&postcount=80)<br>[Quoted from Silvers](https://forums.alliedmods.net/showpost.php?p=2709004&postcount=394)<br>[Quoted from Sazpaimon](https://forums.alliedmods.net/showpost.php?p=1587691&postcount=10)
