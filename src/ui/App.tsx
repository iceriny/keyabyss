import { BattleArrival } from "./BattleArrival";
import { FirstVisitSetup } from "./FirstVisitSetup";
import { GameText } from "./GameText";
import { readRunArchive, settleRun } from "../application/runArchive.ts";
import { ResultPanel, HistoryPanel, OutcomeEffects } from "./RunResults.tsx";
import { storage } from "./storage.ts";
import { TooltipHost } from "./Tooltip";
import { StartupGate } from "./StartupGate";
import { ArcaneCursor } from "./ArcaneCursor";
import { useUIAudio } from "./useUIAudio.ts";
import { EdgeVeil } from "./EdgeVeil";
import { builtinVocabularies } from "../platform/vocabulary.ts";
import { createBrowserSession } from "../bootstrap/browser-session.ts";
import type { SessionView } from "../contracts/session.ts";
import { useCallback, useEffect, useRef, useState } from "react";
import type {
  BookId,
  GameState,
  ModeId,
  Relic,
  Report,
  Settings,
  Vocabulary,
  Word,
} from "../contracts/game.ts";
import {
  C,
  customBooks,
  defaultSettings,
  download,
  fmt,
  read,
  save,
} from "./storage";
import { Button, KeyboardLayer, Modal, Stat } from "./components";
import { Home, Deployment } from "./Home";
import { CodexPanel, HelpPanel, SettingsPanel, VocabPanel } from "./Panels";
import { HUD, RoutePanel, UpgradePanel } from "./Battle";
import { LoadingScreen, type LoadingState } from "./LoadingScreen";
import { loadVocabulary, paint, prepareBattle } from "../loading";

type Screen =
  | {
      type:
        | "calibration"
        | "deploy"
        | "vocab"
        | "codex"
        | "help"
        | "settings"
        | "history"
        | "pause"
        | "quit"
        | "tutorial"
        | "bag";
    }
  | {
      type: "upgrade";
      choices: import("../contracts/rewards.ts").RewardChoice[];
    }
  | {
      type: "route";
      offers: readonly import("../contracts/content.ts").RouteDefinition[];
    }
  | { type: "result"; report: Report };
const titles: Record<Screen["type"], string> = {
  calibration: "初入书库 · 调校共鸣",
  deploy: "准备出征",
  vocab: "词库工坊",
  codex: "咒典图鉴",
  help: "施法指南",
  settings: "设置",
  pause: "已暂停",
  quit: "结束本次冒险？",
  tutorial: "直接敲键盘，即可施法",
  bag: "当前构筑",
  upgrade: "选择遗物",
  route: "选择下一页",
  result: "未完待续",
  history: "远征记录",
};

export function App() {
  const [archive, setArchive] = useState(() => readRunArchive(storage));
  const archiveRef = useRef(archive);
  const [entered, setEntered] = useState(false);
  const [arrival, setArrival] = useState<{ reveal: () => void; book: BookId; origin?: { x: number; y: number } } | null>(null);
  const [arriving, setArriving] = useState(false);
  const [loading, setLoading] = useState<LoadingState | null>(null);
  const loadingToken = useRef(0),
    loadingBusy = useRef(false),
    retryLoad = useRef<() => void>(() => {});
  const labels = useRef<HTMLCanvasElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null),
    gameRef = useRef<ReturnType<typeof createBrowserSession> | null>(null),
    [game, setGame] = useState<SessionView | null>(null),
    [state, setState] = useState<GameState>("home");
  const [stack, setStack] = useState<Screen[]>([]),
    screen = stack.at(-1),
    [custom, setCustom] = useState(customBooks);
  useUIAudio(game, entered, stack.length, screen?.type);
  const prefs = useRef(
    read<{ book?: BookId; mode?: ModeId; vocab?: string }>("prefs", {}),
  ).current;
  const [book, setBook] = useState<BookId>(
      prefs.book && C.BOOKS[prefs.book] ? prefs.book : "frost",
    ),
    [mode, setMode] = useState<ModeId>(
      prefs.mode && C.MODES[prefs.mode] ? prefs.mode : "normal",
    );
  const [vocab, setVocab] = useState(prefs.vocab || "primary1"),
    [progressive, setProgressive] = useState(true),
    [seed, setSeed] = useState("");
  const [settings, setSettings] = useState<Settings>(() => ({
    ...defaultSettings,
    ...read<Partial<Settings>>("settings", {}),
  }));
  const [notice, setNotice] = useState(""),
    [banner, setBanner] = useState(""),
    toastTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined),
    bannerTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const books = [...builtinVocabularies(), ...custom],
    allBooksRef = useRef(books);
  allBooksRef.current = books;
  const toast = useCallback((message: string) => {
    setNotice(message);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setNotice(""), 3500);
  }, []);
  useEffect(() => {
    if (!canvas.current || gameRef.current) return;
    const runtime = createBrowserSession({
      canvas: canvas.current,
      overlay: labels.current,
      books: () => allBooksRef.current,
      events: {
        state(s) {
          setState(s);
          if (s === "home" || s === "playing") setStack([]);
        },
        toast,
        banner(value) {
          setBanner(value.title);
          clearTimeout(bannerTimer.current);
          bannerTimer.current = setTimeout(() => setBanner(""), 1800);
        },
        pause() {
          setStack([{ type: "pause" }]);
        },
        upgrade(choices) {
          setStack([{ type: "upgrade", choices }]);
        },
        route(info) {
          setStack([
            {
              type: "route",
              offers: info.offers,
            },
          ]);
        },
        result(report) {
          const nextArchive = settleRun(archiveRef.current, report);
          archiveRef.current = nextArchive;
          setArchive(nextArchive);
          if (!save("archive", nextArchive))
            toast("存储空间不足，本次战报可手动导出");
          setStack([{ type: "result", report }]);
        },
      },
    });
    gameRef.current = runtime;
    setGame(runtime.session);
    return () => {
      loadingToken.current++;
      runtime.dispose();
      gameRef.current = null;
      clearTimeout(toastTimer.current);
      clearTimeout(bannerTimer.current);
    };
  }, [toast]);
  useEffect(() => {
    if (!game) return;
    game.applySettings(settings);
    document.body.classList.toggle("reduced-motion", settings.reduceMotion);
    document.body.dataset.uiFx =
      settings.fx < 0.5 ? "low" : settings.fx < 0.9 ? "medium" : "high";
    save("settings", settings);
  }, [game, settings]);
  useEffect(() => {
    save("prefs", { book, mode, vocab });
  }, [book, mode, vocab]);
  const open = (
    type: "vocab" | "codex" | "help" | "settings" | "deploy" | "bag" | "quit" | "history",
  ) => setStack((s) => [...s, { type }]);
  const back = () => {
    if (loading) {
      cancelLoading();
      return;
    }
    if (!screen) return;
    if (stack.length > 1) setStack((s) => s.slice(0, -1));
    else if (screen.type === "pause") game?.resume();
    else if (screen.type === "result") game?.home();
    else if (!["upgrade", "route", "calibration"].includes(screen.type)) setStack([]);
  };
  const cancelLoading = () => {
    loadingToken.current++;
    loadingBusy.current = false;
    setLoading(null);
  };
  const prepare = async (
    selected: Vocabulary,
    ready: (words: Word[]) => void,
    label: string,
    battle = false,
  ) => {
    if (loadingBusy.current || arrival) return;
    loadingBusy.current = true;
    const token = ++loadingToken.current;
    retryLoad.current = () => {
      void prepare(selected, ready, label, battle);
    };
    const total = battle ? 4 : 2;
    setLoading({ label: `读取 ${selected.title}`, completed: 0, total });
    try {
      await paint();
      if (token !== loadingToken.current) return;
      const words = await loadVocabulary(selected);
      if (token !== loadingToken.current) return;
      setLoading({ label, completed: 1, total });
      if (battle && game) {
        await game.prepare((stage) => {
          if (token === loadingToken.current)
            setLoading({
              label: stage,
              completed: stage === "展开战场" ? 1 : 2,
              total,
            });
        }, book);
        if (token !== loadingToken.current) return;
        setLoading({ label: "战场已就绪", completed: 3, total });
      }
      await paint();
      if (token !== loadingToken.current) return;
      ready(words);
      setLoading(null);
    } catch (error) {
      if (token === loadingToken.current)
        setLoading({
          label,
          completed: 0,
          total,
          error: (error as Error).message,
        });
    } finally {
      if (token === loadingToken.current) loadingBusy.current = false;
    }
  };
  const launch = () => {
    const selected = books.find((b) => b.id === vocab) || books[0];
    if (!game || !selected) return;
    void prepare(
      selected,
      (words) => {
        const icon = document.querySelector("#home .choice-card.selected .choice-icon")?.getBoundingClientRect();
        const origin = icon ? { x: icon.x + icon.width / 2, y: icon.y + icon.height / 2 } : undefined;
        setArrival({ book, origin, reveal: () => { setStack([]); game.start({
          book,
          mode,
          words,
          vocabTitle: selected.title,
          vocabId: selected.id,
          progressive,
          seed:
            seed.trim() ||
            Math.random().toString(36).slice(2, 10).toUpperCase(),
        }); } });
      },
      "准备战场",
      true,
    );
  };
  const start = () => {
    if (!read("tutorial", false)) setStack((s) => [...s, { type: "tutorial" }]);
    else launch();
  };
  const changeCustom = (next: Vocabulary[]) => {
    setCustom(next);
    if (!save("custom", next)) toast("存储空间不足，本次仍可使用；请导出备份");
  };
  const full = async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
    } catch {
      toast("此浏览器请使用 F11 全屏");
    }
  };
  const playing = state === "playing" && !screen;
  let content = null;
  if (screen) {
    if (screen.type === "calibration") content = <FirstVisitSetup settings={settings} onChange={value => { game?.unlockAudio(); setSettings(value); }} onFull={full} onDone={() => { save("calibration-complete", true); setStack([]); }} />;
    if (screen.type === "settings")
      content = (
        <SettingsPanel
          settings={settings}
          onChange={(value) => {
            game?.unlockAudio();
            setSettings(value);
          }}
          onFull={full}
        />
      );
    if (screen.type === "help" || screen.type === "tutorial")
      content = (
        <>
          <HelpPanel />
          {screen.type === "tutorial" && (
            <div className="modal-footer">
              <span>请切换为英文输入法</span>
              <Button
                id="beginTutorial"
                word="begin"
                variant="primary"
                onClick={() => {
                  save("tutorial", true);
                  launch();
                }}
              >
                开始施法 →
              </Button>
            </div>
          )}
        </>
      );
    if (screen.type === "codex" || screen.type === "bag")
      content = (
        <CodexPanel
          book={state === "home" ? book : game!.book}
          held={screen.type === "bag" ? game!.relics : undefined}
          game={screen.type === "bag" ? game ?? undefined : undefined}
        />
      );
    if (screen.type === "vocab")
      content = (
        <VocabPanel
          books={books}
          selected={vocab}
          locked={state !== "home" && state !== "result"}
          onSelect={(id) => {
            setVocab(id);
            toast("词库已切换");
          }}
          onImport={(entry) => {
            const existing = custom.find((b) => b.id === entry.id);
            if (!existing && custom.length >= 20) {
              toast("最多保存 20 个自定义词库");
              return false;
            }
            const used = new Set(custom.map((b) => b.uiWord));
            let n = 1;
            while (used.has(`local${String(n).padStart(2, "0")}`)) n++;
            const next = {
              ...entry,
              uiWord: existing?.uiWord || `local${String(n).padStart(2, "0")}`,
            };
            changeCustom([...custom.filter((b) => b.id !== entry.id), next]);
            if (state === "home") setVocab(entry.id);
            return true;
          }}
          onDelete={(id) => {
            changeCustom(custom.filter((b) => b.id !== id));
            if (vocab === id) setVocab(books[0].id);
          }}
          toast={toast}
          onExport={(entry) => {
            void prepare(
              entry,
              (words) =>
                download(
                  { ...entry, words, count: words.length, asset: undefined },
                  `${entry.id}.json`,
                ),
              "准备导出",
            );
          }}
        />
      );
    if (screen.type === "pause" && game)
      content = (
        <>
          <div className="stats-grid">
            <Stat label="生命" value={Math.ceil(game.player.hp)} />
            <Stat label="击破" value={game.kills} />
            <Stat label="时间" value={fmt(game.elapsed)} />
            <Stat label="等级" value={game.level} />
          </div>
          <div className="pause-menu">
            {(
              [
                ["bag", "当前构筑"],
                ["codex", "咒典图鉴"],
                ["vocab", "词库工坊"],
                ["help", "施法指南"],
                ["settings", "设置"],
              ] as const
            ).map(([type, label]) => (
              <GameText>
                <Button key={type} word={type} onClick={() => open(type)}>
                  {label}
                </Button>
              </GameText>
            ))}
          </div>
          <div className="modal-footer">
            <Button word="quit" onClick={() => open("quit")}>
              结束本局
            </Button>
            <Button
              id="resumeBtn"
              word="resume"
              data-default-focus
              variant="primary"
              onClick={() => game.resume()}
            >
              继续战斗 →
            </Button>
          </div>
        </>
      );
    if (screen.type === "quit" && game)
      content = (
        <>
          <p>结束后进入本局战报。</p>
          <div className="modal-footer">
            <Button word="cancel" data-default-focus onClick={back}>
              继续冒险
            </Button>
            <Button
              word="confirm"
              variant="danger"
              onClick={() => game.end(false)}
            >
              结束并结算
            </Button>
          </div>
        </>
      );
    if (screen.type === "upgrade" && game)
      content = (
        <UpgradePanel
          game={game}
          choices={screen.choices}
          onQuit={() => open("quit")}
        />
      );
    if (screen.type === "route" && game)
      content = (
        <RoutePanel
          game={game}
          offers={screen.offers}
          onQuit={() => open("quit")}
        />
      );
    if (screen.type === "result" && game)
      content = (
        <ResultPanel report={screen.report} game={game} onRetry={launch} onHistory={() => open("history")} />
      );
    if (screen.type === "history") content = <HistoryPanel archive={archive} />;
  }
  return (
    <GameText>
      <KeyboardLayer
        scope={
          !entered
            ? "startup"
            : loading
              ? `loading:${!!loading.error}`
              : `${screen?.type || state}:${stack.length}`
        }
        playing={entered && playing && !loading}
        game={game}
        onBack={back}
      >
        <canvas id="world" ref={canvas} aria-label="键渊战场" />
        <ArcaneCursor />
        {arrival && game && <BattleArrival
          book={C.BOOKS[arrival.book]}
          origin={arrival.origin}
          reduced={settings.reduceMotion}
          reveal={arrival.reveal}
          complete={() => setArrival(null)}
          sound={(cue) => game.playUISound(cue)}
        />}
        <TooltipHost
          game={game && ["playing", "paused", "upgrade", "route"].includes(state) && !["codex", "history", "result"].includes(screen?.type ?? "") ? game : undefined}
          scope={`${entered}:${loading?.label ?? ""}:${screen?.type || state}:${stack.length}`}
        />
        <canvas id="battle-labels" ref={labels} aria-hidden="true" />
        {state !== "home" && <EdgeVeil />}
        {loading && !(state === "home" && stack.some(s => s.type === "deploy")) && (
          <LoadingScreen
            state={loading}
            onCancel={cancelLoading}
            onRetry={() => retryLoad.current()}
          />
        )}
        {!entered && (
          <StartupGate
            game={game}
            reduceMotion={settings.reduceMotion}
            onBegin={() => setArriving(true)}
            onContinue={() => {
              setArriving(false);
              setEntered(true);
              if (!read("calibration-complete", false)) setStack([{ type: "calibration" }]);
            }}
          />
        )}
        {(entered || arriving) && state === "home" && (
          <div
            className={arriving ? "home-arrival" : undefined}
            inert={!entered || (!!screen && screen.type !== "deploy") || !!arrival}
          >
            <Home
              game={game}
              book={book}
              onBook={setBook}
              settings={settings}
              deploying={stack.some(s => s.type === "deploy")}
              leaving={!!arrival}
              busy={!!loading}
              onStart={start}
              onBack={back}
              loading={loading ? <>{loading.error || loading.label}{loading.error && <Button word="retry" onClick={() => retryLoad.current()}>重试</Button>}</> : undefined}
              deployment={<Deployment books={books} vocab={vocab} onVocab={setVocab} mode={mode} onMode={setMode} progressive={progressive} onProgressive={setProgressive} seed={seed} onSeed={setSeed} onLibrary={() => open("vocab")} />}
              onDeploy={() => open("deploy")}
              onOpen={open}
            />
          </div>
        )}
        {game && state !== "home" && state !== "result" && (
          <div inert={!!screen || !!loading}>
            <HUD
              game={game}
              meaning={settings.meaning}
              announcement={playing ? banner : ""}
              onBag={() => {
                game.pause();
                setStack([{ type: "pause" }, { type: "bag" }]);
              }}
            />
          </div>
        )}
        {screen && screen.type !== "deploy" && (
          <div inert={!!loading}>
            <Modal
              effects={screen.type === "result" ? <OutcomeEffects /> : undefined}
              variant={screen.type === "result" ? `outcome-modal ${screen.report.win ? "victory" : screen.report.outcome === "abandoned" ? "abandoned" : "defeat"}` : screen.type === "history" ? "history-modal" : ["upgrade", "route"].includes(screen.type) ? "upgrade-modal" : screen.type === "calibration" ? "calibration-modal" : ""}
              title={
                screen.type === "result"
                  ? screen.report.win ? "终稿已改写" : screen.report.outcome === "abandoned" ? "此行暂落笔" : "墨尽 · 未完待续"
                  : titles[screen.type]
              }
              wide={[
                "calibration",
                "vocab",
                "codex",
                "help",
                "tutorial",
                "upgrade",
                "route",
                "bag",
                "result",
                "history",
              ].includes(screen.type)}
              onBack={
                ["upgrade", "route", "result", "calibration"].includes(screen.type)
                  ? undefined
                  : back
              }
            >
              {content}
            </Modal>
          </div>
        )}
        {notice && (
          <div className={`toast${state === "playing" && !screen ? " combat-toast" : ""}`} role="status" aria-live="polite" aria-atomic="true">
            <span key={notice} className="toast-message">{notice}</span>
          </div>
        )}
      </KeyboardLayer>
    </GameText>
  );
}
