/*
 * @Author: 夜羽真白
 * @Date: 2023-05-23 00:03 周二
 * @Type: Left 4 Dead 2 Plugin
 * @Description: 日志记录对象
 * @URL: https://github.com/GlowingTree880/L4D2_LittlePlugins
 */

#include <colors.inc>

methodmap Logger __nullable__
{

    public Logger(bool enable)
    {
        return view_as<Logger>(enable);
    }

    property bool enable
    {
        public get() { return view_as<bool>(this); }
    }

    // debug 级别输出，输出到所有客户端控制台
    public void debugAll(const char[] message, any ...)
    {
        if (!this.enable) { return; }
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        PrintToConsoleAll(buffer);
    }

    // debug 级别输出，输出到指定用户控制台
    public void debug(int client, const char[] message, any ...)
    {
        if (!this.enable) { return; }
        if (client < 1 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client)) { return; }
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 4);
        PrintToConsole(client, buffer);
    }

    // info 级别输出，输出到 LogMessage 文件中
    public void info(const char[] message, any ...)
    {
        if (!this.enable) { return; }
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        LogMessage(buffer);
    }

    // info 级别输出，输出到指定用户控制台与 LogMessage 文件中
    public void infoToClient(int client, const char[] message, any ...)
    {
        if (!this.enable) { return; }
        if (client < 1 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client))
        {
            LogMessage("[Logger]: client %d is invalid", client);
            return;
        }
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 4);
        LogMessage(buffer);
        PrintToConsole(client, buffer);
    }

    // message 级别输出，输出到服务器与所有用户控制台
    public void messageAll(const char[] message, any ...)
    {
        if (!this.enable) { return; }
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        PrintToServer(buffer);
        CPrintToChatAll(buffer);
    }

    // message 级别输出，输出到服务器与指定用户控制台
    public void message(int client, const char[] message, any ...)
    {
        if (!this.enable) { return; }
        if (client < 1 || client >= MaxClients || !IsClientInGame(client) || IsFakeClient(client))
        {
            PrintToServer("[Logger]: client: %d is invalid", client);
            return;
        }
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 4);
        PrintToServer(buffer);
        CPrintToChat(client, buffer);
    }

    // server 级别输出，输出到服务器控制台
    public void server(const char[] message, any ...)
    {
        if (!this.enable) { return; }
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        PrintToServer(buffer);
    }

    // error 级别输出，输出到服务器与 error 文件
    public void error(const char[] message, any ...)
    {
        char buffer[512];
        VFormat(buffer, sizeof(buffer), message, 3);
        PrintToServer(buffer);
        LogError(buffer);
    }

}