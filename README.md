# GlowingTree's Server Little Plugins
* <br>这里是一个存放着一些自用，因为个人突发奇想或好友建议而制作的L4D2插件的小仓库，将会不间断上传包含服务器功能，游戏玩法等多种类型的插件
* <br>刚刚开始学着写L4D2的插件，可能只注重实现了功能而忽略了架构和其他的一些方面，还可能会有非常非常多的Bug，目前还在向大佬学习中，如果发现了Bug欢迎向我提出哦( ･ω< ) 
> This is a small project whitch stores some L4D2 plug-ins made since sudden whims or suggestions from friends. Various types of plug-ins including server functions, gameplay, etc. will be uploaded continuously（Sorry for my poor English(；へ：)）.
<br>I have just started to learn to write L4D2 plug-ins. So may only focus on the realization of the function and ignore the architecture and some other aspects. There may also be a lot of bugs. Now I am keep on learning from the great guys. If you find a bug or something strange when using the plugin, any report is appreciated.
* <br>[我的Steam个人资料链接（My Steam Profile Link）](https://steamcommunity.com/id/saku_ra/)

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
* **DefibrillatorHealingField：** In the case of holding the defibrillator, you can aim at one survivor who is not full of blood, then press the E (USE) key. A treatment field (range) will be triggered to treat the target (not dead/incapped) Multiple survivors within the range (recovery of permanent health + temporary health) can be restored.
<br>（手持电击器的情况下，可以将目标对准未满血的生还者按住E（USE）键，将会触发一个治疗场（范围），对需要治疗的对象（未死亡/未倒地）进行治疗（回复实血+虚血）范围内的多个对象皆可受到治疗）
* **TankAnnounce：** In any gamemode, The plugin will announce a message when Tank spawn. The message type can be selected (chat/hint text/central text. Compared with l4d_tank_announce in ZoneMod, the depend to the l4d_tank_control_eq plug-in is deleted.
<br>（任意模式下，Tank刷新将会进行提示的插件，提示类型：聊天框/中央文本框提示/中央文字提示，相比ZoneMod中的TankAnnounce删除了对 l4d_tank_control_eq 插件的调用）
* **JockeyRideSpeed：** A plugin that can customize the movement speed of the survivors after jockeys ride on them (also can customize the movement speed of the survivors after jockeys ride end)
<br>（任意模式下，允许自定义 Jockey 骑乘到生还者之后携带生还者的移动速度，同时允许自定义Jockey死亡或被救下后被骑乘的生还者速度的插件）
