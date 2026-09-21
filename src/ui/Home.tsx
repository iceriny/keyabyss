import { GameText } from "./GameText";
import { BookArtwork } from "./BookArtwork";
import { MagicPattern } from "./MagicPattern";
import { useMenuScene } from "./useMenuScene";
import type { SessionView } from "../contracts/session.ts";
import { useState, type CSSProperties } from "react";
import type {
  BookId,
  ModeId,
  Settings,
  Vocabulary,
} from "../contracts/game.ts";
import { C } from "./storage";
import { Button, ChoiceCard, Field, Key, Select, Toggle } from "./components";
import { Portal } from "./Portal";

export const modeWords: Record<ModeId, string> = {
  story: "easy",
  normal: "normal",
  hard: "hard",
  nightmare: "nightmare",
  apocalypse: "doom",
};
export function Home({
  book,
  onBook,
  settings,
  onDeploy,
  onOpen,
  game,
}: {
  book: BookId;
  game: SessionView | null;
  onBook: (id: BookId) => void;
  settings: Settings;
  onDeploy: () => void;
  onOpen: (name: "vocab" | "codex" | "help" | "settings" | "history") => void;
}) {
  const b = C.BOOKS[book],
    copy = [b.headline, b.subtitle, b.eyebrow];
  const bookIds = Object.keys(C.BOOKS);
  const [orbit, setOrbit] = useState({ book, turn: bookIds.indexOf(book) });
  if (orbit.book !== book) {
    const count = bookIds.length;
    const delta = bookIds.indexOf(book) - bookIds.indexOf(orbit.book);
    const shortest = ((delta + count * 1.5) % count) - count / 2;
    setOrbit({ book, turn: orbit.turn + shortest });
  }
  const root = useMenuScene(game, b.color, book, settings.reduceMotion);
  return (
    <GameText>
      <main
        id="home"
        ref={root}
        className="home-screen ritual-home"
        data-menu-root
        style={{ "--school": b.color } as CSSProperties}
      >
        <div className="game-title">
          <span className="edition">KEYABYSS / THE SEALED ARCHIVE</span>
          <h1>
            键<span>渊</span>
          </h1>
          <p>失 控 咒 典</p>
        </div>
        <div className="hero-art">
          <MagicPattern school={book} className="hero-pattern" />
          <Portal
            color={b.color}
            reduced={settings.reduceMotion}
            density={settings.fx}
          />
          <div className="archive-floor" />
          <div className="archive-beam" />
          <div className="hero-caption" key={book} aria-live="polite">
            <span>{copy[2]}</span>
            <h2>{copy[0]}</h2>
            <p>{copy[1]}</p>
            <small>{b.desc}</small>
          </div>
        </div>
        <section className="book-selection" aria-label="选择咒典">
          <div className="section-label">
            <span>封 印 书 库 <small>触碰法书 · 唤醒共鸣</small></span>
            <span>
              0{Object.keys(C.BOOKS).indexOf(book) + 1} /{" "}
              {String(Object.keys(C.BOOKS).length).padStart(2, "0")}
            </span>
          </div>
          <div className="book-grid">
            {(Object.entries(C.BOOKS) as [BookId, typeof b][]).map(
              ([id, item], i) => {
                const count = Object.keys(C.BOOKS).length;
                const angle = (i - Object.keys(C.BOOKS).indexOf(book)) * Math.PI * 2 / count;
                const depth = (Math.cos(angle) + 1) / 2;
                return (
                <ChoiceCard
                  key={id}
                  word={item.command}
                  shortcut={item.shortcut}
                  data-book={id}
                  icon={
                    <>
                      <MagicPattern school={id} className="card-pattern" />
                      <BookArtwork book={item} decorative />
                      <span className="book-aura" />
                      <span className="book-satellites">
                        {Array.from({ length: 12 }, (_, n) => <i key={n} style={{ "--spark": n } as CSSProperties} />)}
                      </span>
                      {book === id && <span key={id} className="book-resonance" />}
                    </>
                  }
                  title={item.name}
                  selected={book === id}
                  onClick={() => { if (book !== id) { game?.playUISound("book"); onBook(id); } }}
                  style={{
                    "--card-color": item.color,
                    "--orbit-angle": `${(i - orbit.turn) * 360 / count}deg`,
                    zIndex: Math.round(depth * 10) + 2,
                  } as CSSProperties}
                />
              ); },
            )}
          </div>
          <Button
            word="start"
            variant="primary deploy-button"
            id="startBtn"
            data-default-focus
            onClick={onDeploy}
          >
            准备出征 <span>→</span>
          </Button>
        </section>
        <nav className="camp-menu" aria-label="营地菜单">
          <Button word="vocab" onClick={() => onOpen("vocab")}>
            词库
          </Button>
          <Button word="codex" onClick={() => onOpen("codex")}>
            咒典图鉴
          </Button>
          <Button word="help" onClick={() => onOpen("help")}>
            施法指南
          </Button>
          <Button word="settings" onClick={() => onOpen("settings")}>
            设置
          </Button>
          <Button word="history" onClick={() => onOpen("history")}>
            远征记录
          </Button>
        </nav>
        <div className="home-controls">
          <span>
            <Key>A–Z</Key> 施法
          </span>
          <span>
            <Key>Space</Key> 弹反 · 方向键闪避 · Alt 自动择位
          </span>
          <span>
            <Key>Shift</Key> 终式
          </span>
        </div>
      </main>
    </GameText>
  );
}
export function Deployment({
  books,
  vocab,
  onVocab,
  mode,
  onMode,
  progressive,
  onProgressive,
  seed,
  onSeed,
  onStart,
  onLibrary,
}: {
  books: Vocabulary[];
  vocab: string;
  onVocab: (id: string) => void;
  mode: ModeId;
  onMode: (id: ModeId) => void;
  progressive: boolean;
  onProgressive: (value: boolean) => void;
  seed: string;
  onSeed: (value: string) => void;
  onStart: () => void;
  onLibrary: () => void;
}) {
  const notes: Record<ModeId, string> = {
    story: "宽裕预警与生命，适合初次落笔。",
    normal: "从容开场，逐波迎接完整挑战。",
    hard: "更快攻势，考验处置顺序与弹反时机。",
    nightmare: "精英围猎，需要成熟构筑。",
    apocalypse: "极限压力，留给熟练的施法者。",
  };
  return (
    <GameText>
      <>
        <div className="panel-scroll">
        <div className="deployment-grid">
          <Select
            id="vocabSelect"
            label="本局词库"
            word="list"
            options={books.map((b) => ({
              value: b.id,
              label: b.title,
              detail: `${(b.custom ? b.words.length : (b.count ?? b.words.length)).toLocaleString()} 词`,
            }))}
            value={vocab}
            onChange={onVocab}
          />
          <Button word="import" onClick={onLibrary}>
            管理 / 导入
          </Button>
        </div>
        <div className="field-label">战斗难度</div>
        <div className="difficulty-options">
          {(Object.keys(C.MODES) as ModeId[]).map((id) => (
            <Button
              key={id}
              word={modeWords[id]}
              data-mode={id}
              aria-pressed={mode === id}
              className={mode === id ? "selected" : ""}
              onClick={() => onMode(id)}
            >
              {C.MODES[id].name}
            </Button>
          ))}
        </div>
        <p className="mode-description">{notes[mode]}</p>
        <Toggle
          id="progressive"
          label="渐进词长"
          word="grow"
          value={progressive}
          onChange={onProgressive}
        />
        <Field
          id="seedInput"
          label="书页种子 · 留空随机"
          word="seed"
          value={seed}
          onChange={onSeed}
        />
        </div>
        <div className="modal-footer">
          <span>三章 · 九场 · 一次全新构筑</span>
          <Button
            id="beginRun"
            word="begin"
            variant="primary"
            onClick={onStart}
          >
            进入咒典 →
          </Button>
        </div>
      </>
    </GameText>
  );
}
