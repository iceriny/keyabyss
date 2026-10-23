# Windows 发布流程

适用于根目录 Godot 工程，发布到 [GitHub Releases](https://github.com/iceriny/keyabyss/releases)。常规发布按以下四步完成。

| 包 | 导出命令 | 输出目录 | GitHub 标记 |
| --- | --- | --- | --- |
| 测试包 | `godot.ps1 export` | `builds/windows/` | Pre-release，Latest=false |
| 正式包 | `godot.ps1 export-release` | `builds/windows-release/` | 正式发布，Latest=true |

测试包使用 Debug／ExportDebug，正式包使用 Release／ExportRelease。正式包在已有功能验收基础上发布，新增验证按本次差异选择。

## 1. 固定版本并提交

- 测试版本：`0.7.0-test.YYYYMMDD`，同日再次发布追加 `.2`、`.3`；正式版本：`0.7.0`。标签加 `v` 前缀。
- 更新 `project.godot` 的 `config/version`，以及 `export_presets.cfg` 中两个 Windows 四段版本，末段按构建顺序递增。
- 提交并推送本次代码；素材有变化时，先按[资产流程](GIT-AND-ASSETS.md)上传素材并更新 `asset-lock.json`。记录构建提交，标签指向该提交；已发布的标签与同名包保持不变。

提交后用 `$sourceCommit = git rev-parse HEAD` 保存本次构建提交。

## 2. 导出

在仓库根目录执行本次需要的一个命令：

```powershell
pwsh -NoProfile -File tools/godot/godot.ps1 export
# 正式包：
pwsh -NoProfile -File tools/godot/godot.ps1 export-release
```

脚本检查引擎／SDK版本和锁定依赖，由 Godot 编译导出、烘焙shader并复制许可；测试包同时附带诊断工具。旧输出及资源转换缓存自动移入 `.delete/`，导出目录每次重新生成。导出失败或日志报错时先处理错误。

首次配置环境或资产锁变化时，按[工具链](migration/TOOLCHAIN.md)准备素材和导入。日常使用已就绪环境直接导出。

## 3. 启动一次成品

使用临时 APPDATA 启动导出的程序，确认到达首页、没有启动错误后关闭：

```powershell
$output = 'builds/windows' # 正式包使用 builds/windows-release
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path (Get-Location) '.temp/release-appdata'
    New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    & "./$output/keyabyss.console.exe"
    if ($LASTEXITCODE -ne 0) { throw '成品启动失败' }
} finally { $env:APPDATA = $previousAppData }
```

功能测试在开发阶段按改动完成，发布时沿用结果。仅当本次仍有具体疑点时追加对应检查，例如存档结构变化后的旧档回读、资源序列化变化后的包内数据核对。入口见 [TESTING](TESTING.md)。

## 4. 压包并发布

完整压缩输出目录，上传 ZIP 与校验文件。以下变量填写本次版本及实际构建提交：

```powershell
$version = '0.7.0-test.20261019.2'
$zip = "builds/keyabyss-$version-windows-x64.zip"
$sums = 'builds/SHA256SUMS.txt'
Compress-Archive -LiteralPath $output -DestinationPath $zip
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($zip))" | Set-Content -LiteralPath $sums -Encoding ascii
gh release create "v$version" $zip $sums --repo iceriny/keyabyss --target $sourceCommit --title "键渊 $version" --notes "本次变化；完整解压后运行 keyabyss.exe。" --prerelease --latest=false
```

正式包将最后两个参数改为 `--latest=true`。发布说明简述变化、启动方式及直接影响试玩的已知问题。

确认上传成功、资产名称和大小正确；平台提供SHA-256时与本地值核对。下载异常时再下载排查。更新根README下载链接，在阶段总结留一条版本、构建提交与发布链接；已有对应TODO时更新其状态，一起提交推送。Git提交与资产锁已保存构建输入，本地保留最终ZIP和必要日志即可。
