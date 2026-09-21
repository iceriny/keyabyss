import { RelicIcon } from "./RelicIcon";
import { About } from "./About";
import { GameText } from "./GameText";
import { TERMS } from "../content/glossary.ts";
import { BookArtwork } from "./BookArtwork";
import { TYPES, ELITES } from "../content/catalog.ts";
import { useEffect, useRef, useState } from "react";
import type {
  ImportResult,
  Settings,
  Vocabulary,
  BookId,
} from "../contracts/game.ts";
import { C, vocabCommand } from "./storage";
import { Button, Field, Key, Select, Toggle } from "./components";
import {
  RELIC_RARITIES,
  relicRarity,
  sortRelicsByRarity,
} from "./relic-presentation.ts";

export function SettingsPanel({
  settings,
  onChange,
  onFull,
  showAbout = true,
}: {
  settings: Settings;
  onChange: (next: Settings) => void;
  onFull: () => void;
  showAbout?: boolean;
}) {
  const set = <K extends keyof Settings>(key: K, value: Settings[K]) =>
    onChange({ ...settings, [key]: value });
  return (
    <GameText>
      <>
        <div className="panel-scroll settings-content">
        <Toggle
          label="声音"
          word="sound"
          value={settings.sound}
          onChange={(v) => set("sound", v)}
        />
        <Field
          label="总音量"
          word="volume"
          id="settingVolume"
          type="range"
          min={0}
          max={1}
          step={0.01}
          value={settings.volume}
          onChange={(v) => set("volume", Number(v))}
        />
        <Field
          label="音效音量"
          word="sfx"
          id="settingSfxVolume"
          type="range"
          min={0}
          max={1}
          step={0.01}
          value={settings.sfxVolume}
          onChange={(v) => set("sfxVolume", Number(v))}
        />
        <Toggle
          label="氛围音"
          word="music"
          value={settings.music}
          onChange={(v) => set("music", v)}
        />
        <Field
          label="屏幕震动"
          word="shake"
          id="settingShake"
          type="range"
          min={0}
          max={1}
          step={0.05}
          value={settings.shake}
          onChange={(v) => set("shake", Number(v))}
        />
        <Select
          id="settingFx"
          label="特效等级"
          word="effects"
          value={String(settings.fx)}
          options={[
            { value: "1", label: "高 · 完整空间效果" },
            { value: "0.6", label: "中 · 均衡表现" },
            { value: "0.3", label: "低 · 精简粒子" },
          ]}
          onChange={(v) => set("fx", Number(v))}
        />
        <Toggle
          label="大字号咒文"
          word="font"
          value={settings.largeText}
          onChange={(v) => set("largeText", v)}
        />
        <Toggle
          label="词条释义"
          word="meaning"
          value={settings.meaning}
          onChange={(v) => set("meaning", v)}
        />
        <Toggle
          label="头顶中文释义"
          word="translation"
          value={settings.labelMeaning}
          onChange={(v) => set("labelMeaning", v)}
        />
        <Toggle
          label="减少动态效果"
          word="motion"
          value={settings.reduceMotion}
          onChange={(v) => set("reduceMotion", v)}
        />
        {showAbout && <About />}
        </div>
        <div className="modal-footer">
          <span>自动保存</span>
          <Button word="full" onClick={onFull}>
            切换全屏
          </Button>
        </div>
      </>
    </GameText>
  );
}
export function HelpPanel() {
  return (
    <GameText>
      <div className="help-grid">
        <article>
          <Key>A–Z</Key>
          <h3>落笔 · 完词施法</h3>
          <p>
            输入敌人身上的咒文。首字符锁定目标，写完一词即施法；错字不会清空已写进度。
          </p>
        </article>
        <article>
          <Key>Space</Key>
          <h3>回锋 · 弹反</h3>
          <p>
            轻按空格弹反：窗口 0.24 秒，冷却 0.70 秒，次数不限。
            反弹近身敌弹，将接触或冲锋的敌人推远并造成伤害，同时无伤推开周边敌人。成功时短暂时缓，随后平滑恢复；激光和地面爆炸需要闪避。
          </p>
        </article>
        <article>
          <Key>方向键 / Alt</Key>
          <h3>折页 · 闪避</h3>
          <p>
            按方向键立即朝对应方向闪避，或按 Alt 自动选择威胁较低的落点，获得 1
            秒无敌。空格独立释放弹反。
          </p>
        </article>
        <article>
          <Key>Shift</Key>
          <h3>终章 · 释放终式</h3>
          <p>共鸣充满后单独轻按 Shift。组合输入不会误触终式。</p>
        </article>
        <article>
          <Key>Tab / ⌫</Key>
          <h3>换行 · 调整目标</h3>
          <p>
            Tab 切换同前缀目标，退格取消锁定。Esc 暂停。菜单词令敲完即执行。
          </p>
        </article>
        <article>
          <h3>翻卷 · 三章九场</h3>
          <p>
            清除每波增援，选择遗物与补给路线，击败守页者。通关可携构筑挑战下一周目。
          </p>
        </article>
        <article>
          <h3>观潮 · 八向来袭</h3>
          <p>每波敌人从随机方向主攻。角色周围的金色箭头指向敌人来处，珊瑚红外围箭头短暂提示其他方向的偷袭。注意观察四周，及时调整目标。</p>
        </article>
        <article>
          <h3>留痕 · 远征记录</h3>
          <p>书库和结算页可查看最近 50 份战报，回顾到达阶段、施法表现、遗物与错词，并导出留存。记录保存在当前浏览器中。</p>
        </article>
        <article>
          <h3>藏词 · 自己的词库</h3>
          <p>
            本局始终使用所选词库。支持英文、数字、下划线、连字符与撇号；请使用英文输入法。
          </p>
        </article>
        <article>
          <h3>页边注 · 术语</h3>
          <p>
            咒文是敌人身上的可输入词条；词令是菜单中的英文指令。连续完词积累「连笔」；「共鸣」蓄满后可释放终式。绿色咒印的咒文写完后，可清除敌弹和危险预警。
          </p>
        </article>
      </div>
    </GameText>
  );
}
export function CodexPanel({
  held,
  book,
}: {
  held?: Record<string, number>;
  book: BookId;
}) {
  const [tab, setTab] = useState("books");
  const [termQuery, setTermQuery] = useState("");
  const [termCategory, setTermCategory] = useState("all");
  const query = termQuery.trim().toLocaleLowerCase();
  const terms = TERMS.filter(
    (t) =>
      (termCategory === "all" || t.category === termCategory) &&
      (!query ||
        `${t.name} ${t.aliases?.join(" ") ?? ""} ${t.description}`
          .toLocaleLowerCase()
          .includes(query)),
  );
  const relics = sortRelicsByRarity(
    held ? C.RELICS.filter((r) => held[r.id]) : C.RELICS,
  );
  return (
    <GameText>
      <>
        {!held && (
          <div className="tabs">
            {[
              ["books", "咒典"],
              ["enemies", "敌人"],
              ["relics", "遗物"],
              ["terms", "术语"],
            ].map(([id, label], i) => (
              <Button
                key={id}
                word={id}
                shortcut={String(i + 1)}
                aria-pressed={tab === id}
                className={tab === id ? "selected" : ""}
                onClick={() => setTab(id)}
              >
                {label}
              </Button>
            ))}
          </div>
        )}
        {(held || tab === "relics") && (
          <p className="codex-note">按稀有度编目 · 普通 → 稀有 → 诅咒 → 觉醒</p>
        )}
        {!held && tab === "terms" && (
          <>
            <div className="glossary-tools">
              <Field
                id="termSearch"
                label="查找术语"
                word="search"
                value={termQuery}
                onChange={setTermQuery}
              />
              <Select
                id="termCategory"
                label="知识分类"
                word="category"
                value={termCategory}
                onChange={setTermCategory}
                options={[
                  { value: "all", label: "全部分类" },
                  ...Array.from(new Set(TERMS.map((t) => t.category))).map(
                    (category) => ({ value: category, label: category }),
                  ),
                ]}
              />
            </div>
            <p className="codex-note">
              {terms.length} / {TERMS.length} 条注解 · 悬停带点线的术语即可查阅
            </p>
          </>
        )}
        <div className="codex-grid" tabIndex={-1} aria-label="图鉴内容">
          {!held && tab === "terms"
            ? terms.map((t) => (
                <article
                  className="codex-card term-card"
                  key={t.id}
                  data-term-entry={t.id}
                >
                  <span className="term-category">{t.category}</span>
                  <h3>{t.name}</h3>
                  <p>{t.description}</p>
                  {!!t.aliases?.length && (
                    <small>也称：{t.aliases.join(" / ")}</small>
                  )}
                </article>
              ))
            : !held && tab === "books"
              ? Object.entries(C.BOOKS).map(([id, b]) => (
                  <article className="codex-card" key={id}>
                    <BookArtwork
                      book={b}
                      className="codex-book-art"
                      decorative
                    />
                    <h3>
                      {b.name}
                      {id === book && " · 当前"}
                    </h3>
                    <p>{b.detail}</p>
                    <p className="accent">终式 · {b.ultimate}</p>
                    <p>{b.ultimateDesc}</p>
                  </article>
                ))
              : !held && tab === "enemies"
                ? [...Object.entries(TYPES), ...Object.entries(ELITES)].map(
                    ([id, e]) => (
                      <article className="codex-card" key={id}>
                        <h3 style={{ color: e.color }}>{e.name}</h3>
                        <p>{e.tip}</p>
                      </article>
                    ),
                  )
                : relics.map((r) => (
                    <article
                      className={`codex-card ${relicRarity(r)}`}
                      key={r.id}
                      data-relic={r.id}
                      data-rarity={relicRarity(r)}
                    >
                      <div className="codex-card-meta">
                        <span className="codex-icon" aria-hidden="true">
                          <RelicIcon id={r.id} />
                        </span>
                        <span className="codex-rarity">
                          {RELIC_RARITIES[relicRarity(r)].label}
                        </span>
                        {r.tag !== RELIC_RARITIES[relicRarity(r)].label && (
                          <span>{r.tag}</span>
                        )}
                      </div>
                      <h3>
                        {r.name}
                        {held && ` × ${held[r.id]}`}
                      </h3>
                      <p>{r.desc}</p>
                      {r.requires && (
                        <p className="accent">
                          觉醒前置：
                          {r.requires
                            .map(
                              (id) => C.RELICS.find((x) => x.id === id)?.name,
                            )
                            .join(" + ")}
                        </p>
                      )}
                    </article>
                  ))}
          {held && !relics.length && <p>尚未获得遗物。</p>}
          {!held && tab === "terms" && !terms.length && (
            <p className="glossary-empty">
              未找到匹配的术语，试试其他关键词或分类。
            </p>
          )}
        </div>
      </>
    </GameText>
  );
}
interface VocabProps {
  onExport: (book: Vocabulary) => void;
  books: Vocabulary[];
  selected: string;
  locked: boolean;
  onSelect: (id: string) => void;
  onImport: (book: Vocabulary) => boolean;
  onDelete: (id: string) => void;
  toast: (message: string) => void;
}
export function VocabPanel({
  onExport,
  books,
  selected,
  locked,
  onSelect,
  onImport,
  onDelete,
  toast,
}: VocabProps) {
  const [viewId, setViewId] = useState(selected),
    [editing, setEditing] = useState(false),
    [name, setName] = useState("我的词库.txt"),
    [text, setText] = useState(""),
    [report, setReport] = useState<ImportResult | null>(null),
    [error, setError] = useState(""),
    [deleting, setDeleting] = useState(false),
    [syncing, setSyncing] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null),
    generation = useRef(0),
    alive = useRef(true),
    controller = useRef<AbortController | null>(null);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      generation.current++;
      controller.current?.abort();
    };
  }, []);
  const book = books.find((b) => b.id === viewId) || books[0];
  const analyze = (content = text, filename = name) => {
    try {
      setReport(C.parseImport(content, filename));
      setError("");
    } catch (e) {
      setReport(null);
      setError((e as Error).message);
    }
  };
  const accept = () => {
    if (!report) return;
    const entry: Vocabulary = {
      id: `custom-${crypto.randomUUID()}`,
      title: report.title,
      words: report.words,
      custom: true,
    };
    if (!onImport(entry)) return;
    setViewId(entry.id);
    setEditing(false);
    setReport(null);
  };
  const sync = async () => {
    if (!book.upstreamFile || syncing) return;
    const ctl = new AbortController();
    controller.current = ctl;
    setSyncing(true);
    const timeout = setTimeout(() => ctl.abort(), 15000);
    try {
      const files = book.upstreamFiles?.length
        ? book.upstreamFiles
        : [book.upstreamFile];
      const results = await Promise.all(
        files.map(async (filename) => {
          const file = encodeURIComponent(filename);
          for (const source of [
            `https://raw.githubusercontent.com/RealKai42/qwerty-learner/master/public/dicts/${file}`,
            `https://cdn.jsdelivr.net/gh/RealKai42/qwerty-learner@master/public/dicts/${file}`,
          ]) {
            try {
              const response = await fetch(source, {
                signal: ctl.signal,
                credentials: "omit",
              });
              if (!response.ok) throw Error(`源站返回 ${response.status}`);
              return C.parseImport(await response.text(), filename);
            } catch (e) {
              if (ctl.signal.aborted) throw e;
            }
          }
          throw Error(`源词表 ${filename} 暂不可用，已有离线词库仍可使用`);
        }),
      );
      const result = C.normalize(results.flatMap((r) => r.words));
      if (!alive.current) return;
      const existing = books.find(
        (b) => b.synced && b.upstreamFile === book.upstreamFile,
      );
      const entry: Vocabulary = {
        ...book,
        id: existing?.id || `sync-${crypto.randomUUID()}`,
        title: book.title.replace(/ · 同步版/g, "") + " · 同步版",
        words: result.words,
        custom: true,
        synced: true,
        source: book.source,
        asset: undefined,
        count: result.words.length,
        snapshot: "complete",
        scope: `${result.words.length} 个可用词条`,
      };
      if (!onImport(entry)) return;
      setViewId(entry.id);
      toast(`已同步 ${result.words.length} 词`);
    } catch (e) {
      if (alive.current)
        toast(
          ctl.signal.aborted
            ? "同步超时，离线词库仍可使用"
            : (e as Error).message,
        );
    } finally {
      clearTimeout(timeout);
      if (alive.current) setSyncing(false);
    }
  };
  if (editing)
    return (
      <GameText>
        <>
          <div className="panel-scroll">
          <Field
            id="pasteName"
            label="名称 / 文件名"
            word="name"
            value={name}
            onChange={(v) => {
              setName(v);
              setReport(null);
            }}
          />
          <Field
            id="pasteText"
            label="词库内容"
            word="content"
            value={text}
            onChange={(v) => {
              setText(v);
              setReport(null);
            }}
            multiline
          />
          <p>TXT 每行一词；CSV、JSON、JSONL 均可。最多 5 MB。</p>
          {error && (
            <p role="alert" className="error-text">
              {error}
            </p>
          )}
          {report && (
            <div className="import-report" role="status">
              <strong>{report.words.length} 个可用词条</strong>
              <p>
                原始 {report.raw} · 去重 {report.duplicates} · 过滤{" "}
                {report.invalid.length}
              </p>
              <div className="word-preview">
                {report.words.slice(0, 12).map((w) => (
                  <span key={w.word}>{w.word}</span>
                ))}
              </div>
            </div>
          )}
          </div>
          <div className="modal-footer">
            <Button
              word="cancel"
              onClick={() => {
                generation.current++;
                setEditing(false);
              }}
            >
              返回词库
            </Button>
            <Button id="analyzePaste" word="analyze" onClick={() => analyze()}>
              预览解析
            </Button>
            {report && (
              <Button word="accept" variant="primary" onClick={accept}>
                确认导入
              </Button>
            )}
          </div>
        </>
      </GameText>
    );
  if (deleting)
    return (
      <GameText>
        <>
          <p>删除「{book.title}」的本地词库？</p>
          <div className="modal-footer">
            <Button
              word="cancel"
              data-default-focus
              onClick={() => setDeleting(false)}
            >
              取消
            </Button>
            <Button
              word="confirm"
              variant="danger"
              onClick={() => {
                onDelete(book.id);
                setViewId(books[0].id);
                setDeleting(false);
              }}
            >
              确认删除
            </Button>
          </div>
        </>
      </GameText>
    );
  return (
    <GameText>
      <>
        {locked && (
          <p className="accent">本局词库已锁定，导入的词库可在下一局使用。</p>
        )}
        <div className="vocab-layout">
          <div className="vocab-list" aria-label="词库列表">
            {books.map((b, i) => (
              <Button
                key={b.id}
                word={vocabCommand(b, i)}
                className={b.id === book.id ? "selected" : ""}
                onClick={() => setViewId(b.id)}
              >
                {b.title}
                <small>
                  {(b.custom
                    ? b.words.length
                    : (b.count ?? b.words.length)
                  ).toLocaleString()}{" "}
                  词
                </small>
              </Button>
            ))}
          </div>
          <section className="vocab-detail">
            <div className="panel-scroll vocab-description">
            <h3>{book.title}</h3>
            <p>{book.description}</p>
            <p className="source">
              {book.sourceLabel || (book.custom ? "本地导入" : "离线词表")}
              <br />
              {book.scope}
            </p>
            <div className="word-preview">
              {book.words.slice(0, 32).map((w) => (
                <span key={w.word}>
                  <b>{w.word}</b>
                  {w.meaning && <small>{w.meaning}</small>}
                </span>
              ))}
            </div>
            </div>
            <div className="actions">
              <Button
                word="use"
                variant="primary"
                disabled={locked}
                onClick={() => onSelect(book.id)}
              >
                {book.id === selected ? "当前词库" : "使用词库"}
              </Button>
              <Button word="export" onClick={() => onExport(book)}>
                导出
              </Button>
              {book.upstreamFile && (
                <Button word="sync" disabled={syncing || locked} onClick={sync}>
                  {syncing ? "同步中…" : "同步源词表"}
                </Button>
              )}
              {book.custom && (
                <Button
                  word="delete"
                  variant="danger"
                  onClick={() => setDeleting(true)}
                >
                  删除
                </Button>
              )}
            </div>
          </section>
        </div>
        <div className="modal-footer">
          <Button word="file" onClick={() => fileRef.current?.click()}>
            选择文件
          </Button>
          <Button
            word="paste"
            onClick={() => {
              setReport(null);
              setError("");
              setEditing(true);
            }}
          >
            粘贴导入
          </Button>
          <span>仅主动同步时联网</span>
        </div>
        <input
          ref={fileRef}
          hidden
          type="file"
          accept=".txt,.csv,.tsv,.json,.jsonl"
          onChange={async (e) => {
            const file = e.target.files?.[0];
            if (!file) return;
            const token = ++generation.current;
            e.target.value = "";
            try {
              if (file.size > 5_000_000) throw Error("文件超过 5 MB");
              const content = await file.text();
              if (!alive.current || token !== generation.current) return;
              setName(file.name);
              setText(content);
              setEditing(true);
              analyze(content, file.name);
            } catch (err) {
              if (alive.current) toast((err as Error).message);
            }
          }}
        />
      </>
    </GameText>
  );
}
