# Simple Mode

## 插件介绍
- 本插件整合 `ConfoglCompMod` 中的 `ReqMatch` 模式管理模块及 `match_vote` 投票切换模式插件，提供配置模式管理及配置模式投票切换功能
- 不同的插件及不同的 Cvar 设置构成了不同的配置模式，此插件提供游戏内投票选择使用不同的配置模式，即加载不同的插件及配置文件及配置模式的增加与删除

## 使用方法
- 编译时请在 `sourcemode/scripting/` 目录下新建 `simple_mode_vote` 目录，再将 `simple_mode_vote.sp` 放入目录中，或者更改 `simple_mode.sp` 第 99 行 `#include "simple_mode_vote/simple_mode_vote.sp"` 的路径，否则将会因为找不到模式投票模块导致编译失败

1. 把插件放入 `sourcemod/plugins` 文件夹内即可
2. **新建模式子目录**：插件默认的模式主目录（默认保存不同模式的配置文件的文件夹为 `cfg/cfgogl/`，由 Cvar：`simple_mode_dir_path` 指定）在这个主目录下可以新建不同模式名称的子目录，如 `ZoneMod` 模式则新建子目录名称为 `zonemod`
3. **配置模式配置文件**：模式子目录内一般包含 `confogl.cfg, confogl_off.cfg, confogl_plugins.cfg` 这三个目录，分别用于配置 `模式加载时需要调整的 Cvar, 模式卸载时需要调整的 Cvar, 模式加载时需要加载的插件`<br><br>模式加载时插件优先从模式子目录加载这些配置文件，**若在模式子目录无法找到相应的配置文件则在 `cfg/` 目录下读取同名配置文件（由 Cvar：`simple_mode_modestart_once_config` 指定模式加载时读取哪些配置文件）**，在 `confogl.cfg` 中配置 Cvar 使用 `sm_cvar` 指令配置即可，在 `confogl_plugins.cfg` 中配置插件加载使用 `sm plugins load` 指令配置即可<br><br>如使用 `!addmode 模式名称` 指令添加一个模式则会默认在 `cfg/cfgogl/` 目录下创建由 Cvar `simple_mode_autocreate_config` 指定的配置文件
4. **配置模式投票文件**：如果需要使用 `!match` 模式投票命令更改模式则需要将已有的模式配置到模式投票文件中，默认路径为：`sourcemod/configs/match_modes.cfg`，由 Cvar：`simple_mode_config_path` 指定<br><br>模式投票文件是一个三级层次的 `KeyValue` 类型的文件，第一级的键名默认为 `MatchModes`，由 Cvar：`simple_mode_rootkey_name` 指定，第二级的键名可自行配置，第三级键名则对应模式子目录的名称，如 `zonemod` 模式子目录则配置键名为 `zonemod`，接着在第三级键中配置 `name` 属性（属性名由 Cvar：`simple_mode_key_name` 指定，默认为 `name`）用于在 `!match` 菜单中展示的模式名称，如 `"name" "ZoneMod 2.8.3"` 则在 `!match` 菜单中展示名称 `ZoneMod 2.8.3`，可参考 `ZoneMod` 的 `matchmodex.txt`<br><br>
```java
"MatchModes"
{
    "ZoneMod Configs"
    {
        "zonemod"
        {
            "name" "ZoneMod 2.8.3"
        }
        "zoneretro"
        {
            "name" "ZoneMod Retro 2.8.3"
        }
        "zm3v3"
        {
            "name" "3v3 ZoneMod"
        }
        "zm2v2"
        {
            "name" "2v2 ZoneMod"
        }
        "zm1v1"
        {
            "name" "1v1 ZoneMod"
        }
    }
    ...
}
```
5. 进入游戏中使用 `!match` 即可展示模式选择菜单，使用 `!rmatch` 卸载当前模式

## 指令
```java
!addmode *模式名称*（在模式目录中增加一个模式，仅管理员可用）
!delmode *模式名称*（在模式目录中删除一个已有的模式，仅管理员可用）
!forcematch，fm *模式名称*（强制开始一个模式，仅管理员可用）
!resetmatch（强制卸载当前模式，仅管理员可用）
!match（展示模式投票菜单）
!match *模式名称*（强制开始一个模式，仅管理员可用）
!rmatch（投票卸载当前模式）
```

## Cvars
```java
// 模式投票文件所在位置
simple_mode_config_path [configs/match_modes.cfg]
// 模式主目录所在位置
simple_mode_dir_path [../../cfg/cfgogl]
// 插件日志记录级别 1: 禁用, 2: DEBUG, 4: INFO, 8: MESSAGE, 16: SERVER, 32: ERROR, 数字相加
simple_mode_log_level [38]
// 首个玩家连接服务器时默认加载哪个配置模式，为空则不加载任何配置模式
simple_mode_autoload_config [""]
// 使用 !addmode 创建新模式时会创建模式子目录以及这些配置文件，使用英文分号 ; 分割
simple_mode_autocreate_config ["confogl.cfg;confogl_plugins.cfg;confogl_off.cfg;shared_plugins.cfg;shared_settings.cfg;shared_cvars.cfg"]
// 配置模式第一次加载时会加载这些配置文件，之后关卡重启或换图不会再次加载，使用英文分号 ; 分割
simple_mode_modestart_once_config ["generalfixes.cfg;confogl_plugins.cfg;sharedplugins.cfg"]
// 配置模式第一次加载以及地图开始时会加载这些配置文件，使用英文分号 ; 分割
simple_mode_modestart_config ["confogl.cfg"]
// 配置模式被卸载时会加载这些配置文件，使用英文分号 ; 分割
simple_mode_modeend_config ["confogl_off.cfg"]
// 加载和卸载模式成功时是否重启当前地图，0：不重启，1：模式加载完成后重启当前地图，2：模式卸载完成后重启当前地图，3：模式加载完成及卸载完成后都重启
simple_mode_restart_map [3]
// 模式投票文件一级键名
simple_mode_rootkey_name ["MatchModes"]
// 模式投票文件三级键名
simple_mode_key_name ["name"]
// 模式加载完成后设置服务器位置为多少
simpl_mode_maxplayers [30]
// 允许发起模式投票需要的最小玩家数量
simple_mode_vote_player_limit [1]
```

## 注意事项
1. 模式投票文件需要严格遵守三级层次，否则将会无法读取对应模式
2. 由于读取配置文件使用 `ServerCommand` 函数使用 `exec` 命令读取，因此模式主目录需要在 `cfg/` 目录下，同时需要使用到 `BuildPath` 函数建立相对于 `sourcemod` 文件夹的目录结构，因此需要读取 `cfg/` 目录下的文件需要回退两级至 `left4dead2` 目录，书写方式如下 `../../cfg/`，因此更改 Cvar：`simple_mode_dir_path` 时请保留 `../../cfg/`，自定义 `../../cfg/` 之后的内容

## 其他
1. 加载一个模式的过程如下：<br>**a.** 执行 `doLoadMatchMode` 函数，接着调用 `unloadAllPlugins` 函数卸载包括自身在内的所有插件，接着调用 `execModeCfgThenDefault` 函数读取 Cvar：`simple_mode_modestart_once_config` 配置的配置文件，并将插件管理的 Cvar：`simple_mode_is_reloaded` 设置为 1，插件卸载后 Cvar 仍然存在<br>**b.** 插件再次被加载时，读取 Cvar：`simple_mode_is_reloaded`，因为卸载时已经将其值设置为 1，所以再次调用 `doLoadMatchMode` 函数，同时将 `isModePluginLoaded` 设置为 true<br>**c.** 再次调用 `doLoadMatchMode` 函数时由于 `isModePluginLoaded` 为 true 则跳过卸载插件，读取配置文件部分，进入读取 Cvar：`simple_mode_modestart_config` 配置文件以及判断是否需要重启地图部分，如需重启地图则重启地图，**因为读取模式多次加载配置文件以及重启地图的操作都需要本插件完成，所以执行这些操作，需要在新模式配置文件内使用 `sm plugins load` 加载本插件**<br><br>卸载插件 -> 读取模式首次加载的配置文件 -> 加载插件 -> 读取模式多次加载的配置文件 -> 重启地图
2. 卸载一个模式的过程如下：<br>**a.** 执行 `doUnloadMatchMode` 函数<br>**b.** 如果服务器内有真人玩家且非强制卸载则不做任何操作，否则将读 Cvar：`simple_mode_modeend_config` 配置的模式卸载配置文件，接着判断是否需要重启地图，如需重启地图则重启地图<br><br>判断是否有真人玩家及强制卸载 -> 读取模式卸载配置文件 -> 重启地图
3. 投票更换新模式时无需使用 `!rmatch` 卸载当前模式，可直接更换配置模式，插件内部已经做出判断如已经加载模式则调用 `doUnloadMatchMode` 卸载当前模式再加载新的模式

## 更新日志
- 2023-07-05：上传插件、源码与 Readme 文件
- <details>
    <summary>2023-09-22</summary>
    1. 将 simple_mode_enable_logging 是否开启日志记录更改为使用日志记录级别控制日志记录<br>
    2. 将 #include "simple_mode_vote/simple_mode_vote.sp" 路径更改为 #include "simple_mode_vote.sp", 重新编译时请注意<br>
    3. 修复目前已有模式情况下直接使用 !match 命令无法选择新模式, 需要使用 !rmatch 卸载当前模式再使用 !match 选择新模式的问题
  </details>

---
如在使用过程中发现 Bug 或报错请提出 issue