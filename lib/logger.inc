/*
 * @Author: 夜羽真白
 * @Date: 2023-05-23 00:03 周二
 * @Type: Left 4 Dead 2 Plugin
 * @Description: 日志记录对象
 * @URL: https://github.com/GlowingTree880/L4D2_LittlePlugins
 */

#include <colors.inc>

#define LOGGER_LEVEL_OFF    (1 << 0)
#define LOGGER_LEVEL_DEBUG (1 << 1)
#define LOGGER_LEVEL_INFO   (1 << 2)
#define LOGGER_LEVEL_MESSAGE    (1 << 3)
#define LOGGER_LEVEL_SERVER (1 << 4)
#define LOGGER_LEVEL_ERROR  (1 << 5)

methodmap Logger __nullable__
{

    public Logger(int level)
    {
        return view_as<Logger>(level);
    }

    property int level
    {
        public get() { return view_as<int>(this); }
    }

    public void debugAndInfo(const char[] message, any ...) {
        if (this.level & LOGGER_LEVEL_OFF) {
            return;
        }
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        if (this.level & LOGGER_LEVEL_DEBUG) {
            PrintToConsoleAll(buffer);
        }
        if (this.level & LOGGER_LEVEL_INFO) {
            LogMessage(buffer);
        }
    }

    /**
    * DEBUG 级别输出, 输出到所有客户端控制台
    * @param message 输出信息
    * @param any 任意数据
    * @return void
    **/
    public void debugAll(const char[] message, any ...)
    {
        if (this.level & LOGGER_LEVEL_OFF) {
            return;
        } else if (!(this.level & LOGGER_LEVEL_DEBUG)) {
            return;
        }

        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        PrintToConsoleAll(buffer);
    }

    /**
    * DEBUG 级别输出, 输出到指定客户端控制台
    * @param client 指定客户端
    * @param message 输出信息
    * @param any 任意数据
    * @return void
    **/
    public void debug(int client, const char[] message, any ...)
    {
        if (client < 1 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client)) {
            return;
        } else if (this.level & LOGGER_LEVEL_OFF) {
            return;
        } else if (!(this.level & LOGGER_LEVEL_DEBUG)) {
            return;
        }

        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 4);
        PrintToConsole(client, buffer);
    }

    /**
    * INFO 级别输出, 输出到 Log 目录日志文件中
    * @param message 输出信息
    * @param any 任意数据
    * @return void
    **/
    public void info(const char[] message, any ...)
    {
        if (this.level & LOGGER_LEVEL_OFF) {
            return;
        } else if (!(this.level & LOGGER_LEVEL_INFO)) {
            return;
        }

        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        LogMessage(buffer);
    }

    /**
    * INFO 级别输出, 输出到指定客户端控制台及目录日志文件中
    * @param client 指定客户端
    * @param message 输出信息
    * @param any 任意数据
    * @return void
    **/
    public void infoToClient(int client, const char[] message, any ...)
    {
        if (client < 1 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client)) {
            LogMessage("[Logger]: client %d is invalid", client);
            return;
        } else if (this.level & LOGGER_LEVEL_OFF) {
            return;
        } else if (!(this.level & LOGGER_LEVEL_INFO)) {
            return;
        }

        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 4);
        LogMessage(buffer);
        PrintToConsole(client, buffer);
    }

    /**
    * MESSAGE 级别输出, 输出到服务器控制台与所有客户端聊天框
    * @param message 输出信息
    * @param any 任意数据
    * @return void
    **/
    public void messageAll(const char[] message, any ...)
    {
        if (this.level & LOGGER_LEVEL_OFF) {
            return;
        } else if (!(this.level & LOGGER_LEVEL_MESSAGE)) {
            return;
        }

        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        PrintToServer(buffer);
        CPrintToChatAll(buffer);
    }

    /**
    * MESSAGE 级别输出, 输出到服务器控制台与指定客户端聊天框
    * @param client 指定客户端
    * @param message 输出信息
    * @param any 任意数据
    * @return void
    **/
    public void message(int client, const char[] message, any ...)
    {
        if (client < 1 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client)) {
            PrintToServer("[Logger]: client: %d is invalid", client);
            return;
        } else if (this.level & LOGGER_LEVEL_OFF) {
            return;
        } else if (!(this.level & LOGGER_LEVEL_MESSAGE)) {
            return;
        }

        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 4);
        PrintToServer(buffer);
        CPrintToChat(client, buffer);
    }

    /**
    * SERVER 级别输出, 输出到服务端控制台
    * @param message 输出信息
    * @param any 任意数据
    * @return void
    **/
    public void server(const char[] message, any ...)
    {
        if (this.level & LOGGER_LEVEL_OFF) {
            return;
        } else if (!(this.level & LOGGER_LEVEL_SERVER)) {
            return;
        }
        
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        PrintToServer(buffer);
    }

    /**
    * ERROR 级别输出, 输出到服务端控制台与 Log 目录错误日志
    * @param message 输出信息
    * @param any 任意数据
    * @return void
    **/
    public void error(const char[] message, any ...)
    {
        if (this.level & LOGGER_LEVEL_OFF) {
            return;
        } else if (!(this.level & LOGGER_LEVEL_ERROR)) {
            return;
        }

        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        PrintToServer(buffer);
        LogError(buffer);
    }

}