# 目标机周期卡顿调查

2026-10-10：GitHub 测试包 `v0.7.0-test.20261010` 在目标机再次复现。用户确认同设置运行“无诊断对照.cmd”仍卡顿；新增会话诊断不是触发问题的必要条件。补充ETL已确定重复停顿发生在游戏主线程的Vulkan围栏等待，正在核实ToDesk／显存竞争与驱动唤醒的触发关系；尚未确认最终根因或修复效果。

## 首次复现日志

约50.217秒，正常结束。61条有效事件，其中26条长帧、9条心跳、9条渲染线程探针；没有日志队列丢弃记录。首次文件从本机忽略目录 `.temp/logs/` 分析，该目录随后由补充记录替换；以下哈希用于辨认首次样本，不随仓库分发原始日志。

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `session-2026-10-10T12-10-51-2968.jsonl` | 121762 | `1810fe046fd60126fbdd619b9e99512609f44beb2d2f48d21fe732693526d6d6` |
| `engine-1457-4110.log` | 277761 | `0695c599dcfbb3e1a25486ebad7a1eeb8c2f0c8785c4344d2d6536938cb38671` |

目标机为 i7-11700、Quadro P620，Windows版本字符串 `10.0.26200`；官方Godot4.7.2 Debug、Forward+／Vulkan1.4.312。窗口1920×1080，画质2、流体质量3，减少动态关闭，垂直同步1、无帧率上限。严重长帧中窗口有焦点，游戏未暂停。

| 观察 | 结果 |
| --- | --- |
| 超过1秒的帧 | 23次：home 11、prepare 1、departure 3、battle 8 |
| 单次停顿 | 最小1103.246ms、中位1193.973ms、最大1301.263ms |
| 相邻停顿结束时刻的间隔 | 中位2206.740ms |
| 两次停顿之间的正常运行时间 | 中位1017.296ms，范围916.263～1103.777ms |
| 严重长帧墙钟合计 | 27.200秒，占整个样本约54.2% |
| GPU时间异常 | 12个严重长帧的当前／前八帧／离屏视口中有超过1秒的GPU计时 |
| 战斗固定步 | 严重长帧样本中最高3.006ms；战场仅1～3个敌人 |
| 管线计数 | canvas从481增长至490，约12.8秒后保持490；draw／specialization为0 |
| 渲染线程探针 | 9次均0.002～0.003ms；稀疏且在帧回调中提交 |

用户描述的“约每秒一次”在这个样本中表现为：正常运行约1秒，停顿约1.2秒，再重复。不是平均帧率略低，也不是只发生在密集战场。

## 首次日志的排查边界

- 已测量的碰撞、索敌、战斗步、UI布局及流体提交没有接近秒级耗时；主线程的提交时间不等于GPU执行时间。不能通过继续改战斗算法解释首页同样出现的停顿。
- 存档保存约77～89ms，设置保存约7ms，次数与严重长帧不一致；没有证据支持逐秒存盘归因。
- 管线计数稳定，详细引擎日志没有对应的周期PSO更新。项目报告的显存分配未持续增长，约344～472MiB；这不包含其他进程的占用与设备驻留预算，不能据此排除所有显存调度问题。
- 引擎日志有一条Vulkan层清单注册表查询警告，没有脚本错误。警告本身没有与23次停顿对应的时间证据，不能据此修改驱动或注册表。
- 无诊断对照排除了新增测量为必要触发条件，但两份脚本共有的Debug模板、控制台包装器、`--verbose`和引擎日志仍未分离。

## 引擎指标的含义

核对锁定引擎提交 `ed1daf0bf001b61586d9930840f2f1394092c079` 后，不能把诊断中的正常CPU数字解释为“引擎主线程一定没有阻塞”：

- `TIME_PROCESS`按约一秒周期更新该周期的最大处理时间，不是当前帧脚本CPU耗时。帧回调中读到的值也不覆盖当前帧后续全部渲染和等待。[main.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/main/main.cpp#L5121)
- Vulkan时间戳读取没有使用`VK_QUERY_RESULT_WAIT_BIT`，没有发现诊断强制等待GPU的调用。GPU时间戳之间包含执行及期间的排队／抢占影响，秒级计时不能直接等同于某个shader需要秒级计算。[时间戳读取](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/vulkan/rendering_device_driver_vulkan.cpp#L6768)
- Vulkan围栏等待与交换链取图使用无限超时，不能仅凭“约1秒”认定存在硬编码的1秒等待。[围栏](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/vulkan/rendering_device_driver_vulkan.cpp#L3054)、[交换链取图](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/vulkan/rendering_device_driver_vulkan.cpp#L4026)
- 管线缓存更新由新管线创建和退出触发，核查源码未发现逐秒更新路径；不采用关闭管线缓存的猜测性补丁。[缓存更新](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/rendering_device.cpp#L8617)

探针在长帧结束后的回调中提交，即使很快执行，也不能排除此前发生的渲染等待。首次日志把调查重点收窄到引擎原生等待、GPU／驱动调度和系统抢占，仅凭该批数据不足以在三者之间定案；补充ETL的结论见下一节。

## 补充系统记录结果

用户已取回系统轨迹与配套游戏日志：

| 文件 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `session-2026-10-10T12-43-11-13280.jsonl` | 168699 | `ddda10161ac0006349f57755f5082609df96f8b5c2076e6c926eeb8d7423934a` |
| `engine-7769-5868.log` | 285163 | `3e482ed8b28fff0d1385e05a29cb922f985f8d3109cf87f7a574206decd33d55` |
| `system-stall-8086-32655.etl` | 845659653 | `a04afc01ccf2a75a11f2608e934c2d11e685b9ebb21af356ff19fef28d09c7e8` |

ETL覆盖12:42:46.983～12:44:55.460（目标机时间），约128.477秒，解析60,138,307个事件，记录的丢失事件数为0。配套游戏会话约74.028秒，有32次超过1秒的帧，范围1085.337～2216.411ms，中位1372.679ms；覆盖首页10次、战场17次、出征2次、准备／奖励／暂停各1次。严重帧中的战斗固定步最高1.864ms。

### 已确定的阻塞位置

游戏PID为13280，主线程TID为16732（`Startup Thread`）。会话期间在同一围栏等待栈中有35段超过半秒的离CPU等待，合计33.928秒，其中32段在990～1010ms之间。其线程状态为`Wait`、原因`UserRequest`；32段约1秒等待结束时，从ReadyThread到实际重新运行只需0.019～0.170ms，中位0.070ms。秒级延迟发生在等待中，并非线程已经就绪却持续抢不到CPU。

关键栈由上层至下层为：

```text
Godot RenderingDevice Vulkan fence_wait
  → Vulkan loader
  → nvoglv64.dll（32.0.15.8278）
  → KERNELBASE
  → ntdll!NtWaitForMultipleObjects
  → Windows内核等待
```

通过目标`ntdll.pdb`的GUID匹配解析出`NtWaitForMultipleObjects`。Godot与NVIDIA私有函数缺少完整符号；Godot调用点另用同一测试包EXE反汇编确认：目标返回地址RVA `0x1022ee7`调用五参数函数，设备、一个围栏、`VK_TRUE`和`UINT64_MAX`参数与锁定源码`vkWaitForFences`一致，错误文本明确为`Couldn't wait for Vulkan fence`／`fence_wait`，错误行号3055。不是仅凭模块名猜测Vulkan函数。

以诊断写入线程`_write_loop`的创建时刻（ETL相对24478.192ms）近似对齐会话起点，首次初始化长帧之外的31次严重长帧都覆盖该围栏等待；数次长帧跨两段等待。近似起点不是新增的跨时钟精确标记，不能宣称亚毫秒时间对齐。首次长帧另覆盖资源准备阶段的Vulkan／DxgKrnl等待。

队列记录也显示完成延迟：按`hContext + SubmitSequence`配对的游戏QueuePacket有72,412对，其中2,288对跨度超过800ms，最大2234.170ms。按上下文与提交编号配对的全机DMA Start／Stop有51,321对，最大跨度15.575ms；这些DMA事件不等于完整shader时间，也不能把QueuePacket总跨度全部归为GPU计算。现有证据指向同步／队列等待，不能用削减某个视觉效果作为已证实修复。

### 同一显卡上的资源竞争

按游戏Device事件、适配器地址和`MemorySegmentGroup=0`分组，确认ToDesk、游戏、Chrome及桌面合成器使用同一块P620，而不是把另一个适配器或系统内存混入显存统计。本地段容量为2,057,957,376字节，约1962.621MiB。

ETL相对50秒（战场期间）的一组同时状态如下；各值取该时刻之前最新的Usage事件：

| 进程 | 本地段用量 |
| --- | ---: |
| ToDesk（PID 24396） | 1236.5MiB |
| keyabyss | 832.9MiB |
| Chrome | 226.9MiB |
| dwm | 172.4MiB |
| 上述四项合计 | 2468.7MiB |

这是WDDM按进程报告的本地段用量，不代表四项同时物理驻留；实际本地驻留峰值约1884.4MiB。会话内ToDesk用量约1214～1267MiB，游戏约569～833MiB，ToDesk和游戏均出现Usage高于当时Budget的记录，系统另有大量驱逐、换页与页表更新事件。引擎自身约数百MiB的计数不覆盖这些驱动及其他进程资源。

微软对[视频内存预算](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_4/ns-dxgi1_4-dxgi_query_video_memory_info)说明，超过操作系统分配的预算可能因资源重新分配产生卡顿；[本地段与非本地段](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_4/ne-dxgi1_4-dxgi_memory_segment_group)需要分别统计。因此ToDesk的GPU占用／远控与Vulkan驱动同步交互成为有具体证据的优先核查方向。这仍不能证明唯一根因是显存容量，也不能仅凭ToDesk存在就宣称因果成立。

已请求目标机本地完全退出ToDesk及后台进程，以同一测试包、同一画质复测约30秒；在获得对照结果前，不修改碰撞／索敌算法、关闭围栏同步或调整视觉。若退出后消失，先记录环境触发条件，再研究需要远控时的处理；若仍复现，继续沿已确定的驱动等待路径分析。

### 分析工具与证据边界

本机xperf解析新版.NET事件（ID190、版本9）时报`0x80070032`，未生成有效汇总；没有把这次失败表述为ETL损坏。改用微软[TraceEvent](https://github.com/microsoft/perfview)3.2.8生成ETLX，读取上下文切换、ReadyThread、模块、GPU事件及符号。转换中有部分栈关联／符号缺失警告；零丢失事件不等于所有栈完整。上面的重复等待栈、原生调用点和模块GUID单独核对。

分析程序、转换日志、`waits.jsonl`、`ready.jsonl`、`gpu-all.jsonl`、`metadata.jsonl`、`summary.json`以及反汇编输出在本机 `.temp/stall-investigation-20261010/`，不随游戏或代码仓库分发。游戏源码与视觉未修改，目标机对照尚待结果。

## 系统记录操作

同一测试包、同一设置，采集一次约30秒的Windows线程调度与GPU事件，与游戏JSONL对齐。使用Windows自带WPR，不需要安装Godot或重新导出游戏。具体操作及开始／保存脚本在 [测试包工具](../../tools/godot/playtest/系统记录说明.txt)。

脚本执行的命令为：

```powershell
wpr -start GeneralProfile -start GPU -filemode
wpr -stop "测试包目录\logs\system-stall.etl" "Keyabyss periodic stall" -skipPdbGen -compress
```

开始和保存需要管理员权限，游戏仍按原有方式正常启动；只有开始成功后才执行保存。保存会结束记录。采用微软官方[WPR命令](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/wpr-command-line-options)，内置GeneralProfile包含CSwitch／ReadyThread调用栈，GPU包含DxgKrnl事件和调度记录；本轮目标机实际采集与解析见上文。

后续对照应保留版本与设置，优先验证已发现的触发疑点，避免同时改变多个条件。只有找到对应原因才实施修复；待办状态仍维护在 [TODO](../TODO.md)。
