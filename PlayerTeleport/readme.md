# player_teleport

- 本插件提供基本玩家传送功能，支持传送生还者与特感，同时支持通过名称或 userId 进行传送，指令为 !tp
- 当使用 `!tp @a @s` 时表示传送所有生还者（未死亡，挂边会被自动救起）到自己的位置，@a 表示 all，@s 表示 self，可更改第 21 行与 22 行的 `TELEPORT_ME_FLAG @s` 与 `TELEPORT_ALL_CLIENT_FLAG @a` 更改需要输入的内容
- 支持通过名字传送，如 `!tp Coach Ellis` 可以将 Coach 传送到 Ellis 处
- 当仅输入 `!tp` 时且当前玩家有权限使用传送指令时会打开传送菜单，选择传送类型（传送生还者、传送特感）与传送方式（传送我到目标、传送目标到我）后即可执行传送操作，**传送生还者时生还者死亡无法传送，传送特感时特感死亡或处于灵魂状态无法传送**

# Cvar
```java
    // 是否开启插件
    teleport_player_enable 1
    // !tp 指令可以被哪些人使用：1 = 管理员，2 = 管理员与普通玩家
    teleport_player_access_level 1
    // 每局可以使用多少次 !tp 传送指令
    teleport_round_count 5
```

# 更新日志
- 2023-6-3：首次上传插件与 Readme 文档

---
# Logger
- Logger 是一个日志头文件，提供了**面向对象的方法**用于记录日志，类似于 Java 语言中的 Slf4j 依赖
```java
import org.slf4j.LoggerFactory;

private static final Logger log = LoggerFactory.getLogger(getClass());
// 记录 info 级别日志
log.info("这是 info 级别的日志");
// 记录 error 级别日志
log.info("这是 error 级别的日志");
```
- 需要使用 Logger 的功能，首先需要在 .sp 文件中引入 Logger 头文件
```java
#include <Logger>
```
- 接着创建 Logger 的对象，不同于普通的 `methodmap`，由于 Logger 使用了 `__nullable__` 修饰，所以创建 Logger 时需要使用 `new` 关键字，`true` 代表是否打印日志，如设置为 `false` 则不打印日志
```java
Logger log = new Logger(true);
```
- 最后在 .sp 文件中就可以使用 Logger 对象来记录日志了
```java
log.info("这是 info 级别日志");
```
- 在 Logger 中，指定了 `debug`（仅输出到客户端控制台），`info` （输出到 log/Lxxxx 文件中），`message`（输出到服务器与客户端控制台），`server`（输出到服务器控制台），`error`（输出到服务器控制台与 log/error_xxxx 文件中），共五种日志级别，当然也可以自己定义