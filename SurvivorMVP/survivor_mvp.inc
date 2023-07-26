#if defined _survivor_mvp_included_
  #endinput
#endif
#define _survivor_mvp_included_

/**
* 获取本局总伤 MVP
* @return 总伤 MVP 玩家索引
*/
native int GetTotalDamageMvp();

/**
* 获取本局特感 MVP
* @return 特感 MVP 玩家索引
*/
native int GetSiMvp();

/**
* 获取本局丧尸 MVP
* @return 丧尸 MVP 玩家索引
*/
native int GetCiMvp();

/**
* 获取本局友伤 MVP
* @return 友伤 MVP 玩家索引
*/
native int GetFFMvp();

/**
* 获取本局被黑 MVP
* @return 被黑 MVP 玩家索引
*/
native int GetFFReceiveMvp();

/**
* 获取本地图重启次数
* @return 当前地图重启次数
*/
native int GetMapFailCount();

/**
* 获取某个客户端（必须是生还者）本局的排名（type: 1: TotalDamage, 2:SI, 3:CI, 4:FF, 5:FFReceive）
* @param client 需要获取的客户端索引
* @param type 查询方式
* @return int 客户端在本查询方式下的排名
* @error 客户端无效或查询方式无效
*/
native int GetClientRank(int client, int type);

public SharedPlugin __pl_survivor_mvp = {
	name = "survivor_mvp",
	file = "survivor_mvp.smx"
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_survivor_mvp_SetNTVOptional() {
	MarkNativeAsOptional("GetTotalDamageMvp");
	MarkNativeAsOptional("GetSiMvp");
	MarkNativeAsOptional("GetCiMvp");
	MarkNativeAsOptional("GetFFMvp");
	MarkNativeAsOptional("GetFFReceiveMvp");
	MarkNativeAsOptional("GetMapFailCount");
	MarkNativeAsOptional("GetClientRank");
}
#endif