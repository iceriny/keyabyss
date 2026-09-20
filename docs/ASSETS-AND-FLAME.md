# 外部素材与灰烬之书

## 素材入口

`src/platform/AssetManager.ts` 是统一浏览器素材管理器，`src/bootstrap/assets.ts` 提供应用共享实例。模拟层不导入此类。

| 能力 | API |
| --- | --- |
| 登记图片 / 音频 | `register({ id, kind, src })` |
| 解析 file / HTTP / data / blob 地址 | `resolve(id)` |
| 加载与复用图片 / 音频 | `loadImage(id)` / `loadAudio(id)` |
| 批量预加载与实际完成进度 | `preload(ids, onProgress)` |
| 导入用户选择的本地文件 | `importFile(id, file)` |
| 独立音轨播放 | `playAudio(id, { loop, volume })` |
| 释放缓存并停止对应音轨 | `unload(id)` |
| 移除登记并回收导入文件 URL | `unregister(id)` |
| 取消加载、停止音轨并回收资源 | `dispose()` |

相同 ID 的并发加载共享一个 Promise，失败后可重试；默认 15 秒超时。图片和音频使用浏览器原生加载器，所以 `file://` 下的音乐不依赖 fetch CORS。播放接口返回 `{ element, stop }`，音量范围为 0–1；应在用户音频交互后调用，浏览器拒绝播放时 Promise 会拒绝。

组件只借用应用缓存，不在卸载某一缩略图时清除共享资源。应用实例长期复用，独立工具或预览创建自己的 AssetManager 并在结束时销毁。

### 添加随游戏分发的素材

1. 将文件放入 `art/`，例如 `art/music/library.ogg`。
2. 在 `src/content/assets.ts` 添加定义：

```ts
{ id: 'music-library', kind: 'audio', source: 'art/music/library.ogg', src: './assets/music/library.ogg' }
```

3. 运行 `npm run assets`，或直接启动 `npm run dev` / `npm run build`。工具校验路径并将文件原样复制到 public，发行构建继续逐文件核对 SHA-256。
4. 在浏览器应用层调用管理器：

```ts
await assetManager.preload(['music-library']);
const track = await assetManager.playAudio('music-library', { loop: true, volume: 0.25 });
// 切换场景或关闭预览时：
track.stop();
```

这是接入示例；本次 `art/` 只有图片，战斗音效继续使用已配置的 Web Audio 音色。

### 导入本地文件

```ts
assetManager.importFile('preview-image', imageFile);
const image = await assetManager.loadImage('preview-image');
// image.src 可交给 DOM 图片元素。
assetManager.unregister('preview-image');
```

`importFile` 接受 image/* 或 audio/* MIME 类型，文件只在当前会话使用，不自动写入本地存储。需要持久化时由调用方保存文件或内容引用。

## 四本法书插画

| 法书 | 素材 ID | 原始文件 |
| --- | --- | --- |
| 寒墨之书 | book-frost | art/FROST_GRIMOIRE.png |
| 雷鸣之书 | book-storm | art/STORM_GRIMOIRE.png |
| 纸灵之书 | book-spirit | art/SPIRIT_GRIMOIRE.png |
| 灰烬之书 | book-flame | art/FLAME_GRIMOIR.png |

保留输入文件名、透明背景和原始像素，未重绘、裁切或压缩。`Book.artwork` 引用素材 ID，`BookArtwork` 共用于首页主视觉、选择卡、图鉴和 HUD。加载失败时保留图标和操作入口。1080P、720P、平板与窄屏使用同一组件，减少动态设置停止主视觉漂浮。

## 火焰玩法

入口：词令 `flame`，快捷键 `4`。内容定义和法书行为在 `src/content/books/flame/`，共享火焰规则在 `simulation/systems/FlameSystem.ts`。

- 普通火弹：直接伤害为基础施法伤害的 0.85 倍，实际飞行命中后施加 1 层灼烧，并对周围造成 22% 的溅射。
- 每三次施法：火弹直接伤害为基础伤害的 1.45 倍，附加 2 层灼烧，115 半径内造成 50% 溅射，留下 3.2 秒火场。
- 灼烧：基础上限 3 层、持续 3 秒；每 0.5 秒每层造成 6 点伤害，受伤害倍率和灼烧遗物影响。再次点燃叠层并刷新持续时间，不重置跳伤倒计时。
- 火场：每 0.5 秒对范围内敌人施加一层灼烧。闪避会在起点留下半径 60、持续 2 秒的火场。
- 终式「焚世余烬」：目标附近 240 半径引爆，造成 65 点基础伤害（受伤害倍率影响）并施加 3 层灼烧，留下火场；随后 5 秒每 0.7 秒降下一枚强化陨火。

词条占用沿用公共弹道协议。灼烧、火场和终式使用模拟时间，暂停冻结；清房、重新开始时清理旧状态。灼烧死亡经过公共死亡结算，不重复奖励。

## 火焰遗物

| 遗物 / 词令 | 最大层数 | 效果 |
| --- | --- | --- |
| 余烬墨水 / cinder | 3 | 每层灼烧伤害 +30% |
| 松脂印章 / pitch | 2 | 每层灼烧持续时间 +1 秒 |
| 野火书签 / wildfire | 2 | 死亡传播灼烧，最多两代；每层增加目标数量与距离 |
| 熔炉封蜡 / crucible | 2 | 每层火弹爆炸与爆炸火场半径 +25 |
| 炽炭护符 / coal | 2 | 每层在强化施法时获得 5 护盾，沿用 60 护盾上限 |
| 灼痕鞋 / firewalk | 2 | 每层闪避火场半径 +20、持续 +1 秒 |
| 不灭炉心 / inferno | 1 | 拥有余烬墨水与松脂印章后可出现；灼烧上限 5 层，终式持续 7 秒，陨火间隔 0.45 秒 |

七件遗物均为火焰专属，使用既有 grants 和资格校验，不增加中心遗物 ID 分支。正式目录现在包含 4 本法书、56 件遗物。

## 原生表现与验证

火舌使用现有实例批次中的着色器图元；FlameBrush 负责火弹拖尾、敌人灼烧、火场裂纹与局部热扭曲。终式在 UltimateEffects 注册，继续复用 postprocessing 辉光和 Quarks 粒子。文字和危险提示独立绘制，灼烧层数位于敌人下方。

验证入口：

```powershell
npm run assets
npm test
npm run build
npm run test:flame
npm run test:ui
npm run test:visual
```

`tests/assets.test.cjs` 验证缓存去重、错误重试、取消、音轨和 URL 释放；`tests/flame.test.cjs` 验证延迟命中、灼烧周期、熔爆、传播深度、火场、遗物和觉醒；`tests/flame-browser.py` 验证原图逐字节发行、四本插画、真实音频播放、GPU 画面和减少动态。截图与报告在 `docs/test-output-flame/`。
