# error_file_deleter

- 本插件提供 sourcemod\logs 目录下的 error_XXXX.log 与 LXXXX.log 错误日志文件自动删除功能，支持选择需要删除距今多少天前的错误日志文件，以防日志文件堆积过多

# Cvars

```Java
// 是否允许插件自动删除错误日志文件
file_deleter_allow_delete 1
// 需要删除距今大于多少天的错误日志文件
file_deleter_time_different 3
// 是否允许插件记录删除日志
file_deleter_allow_log 1
// 默认删除日志文件位置
file_deleter_log_path "logs\\file_deleter_log.txt"
```

# 更新日志

- 2022-12-15：上传插件与 readme 文件
