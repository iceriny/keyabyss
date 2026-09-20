import { GameText } from "./GameText";
import { useEffect, useRef, useState, type CSSProperties } from "react";
import type { SessionView } from "../contracts/session.ts";
import { assetManager } from "../bootstrap/assets.ts";
import { BOOKS } from "../content/catalog.ts";
import { Sigil } from "./Sigil";
import { Button } from "./components";
/** The first interaction is deliberate; it also unlocks browser audio. */
export function StartupGate({
  game,
  onContinue,
  onBegin,
  reduceMotion,
}: {
  game: SessionView | null;
  onContinue: () => void;
  onBegin: () => void;
  reduceMotion: boolean;
}) {
  const [ready, setReady] = useState(false),
    [error, setError] = useState(""),
    [attempt, setAttempt] = useState(0),
    [leaving, setLeaving] = useState(false);
  const continued = useRef(false),
    exitTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => clearTimeout(exitTimer.current), []);
  useEffect(() => {
    const enter = (event: Event) => {
      if (!ready) {
        // Loading input is not queued and must not feed hidden menu commands.
        if (!error && event.type === "keydown") {
          event.preventDefault();
          event.stopImmediatePropagation();
        }
        return;
      }
      event.preventDefault();
      event.stopImmediatePropagation();
      if (continued.current || (event instanceof KeyboardEvent && event.repeat))
        return;
      continued.current = true;
      game?.unlockAudio();
      game?.playUISound("enter");
      setLeaving(true);
      onBegin();
      exitTimer.current = setTimeout(onContinue, reduceMotion ? 240 : 1600);
    };
    // Capture before the menu keyboard layer; the entry gesture is consumed in full.
    window.addEventListener("keydown", enter, true);
    window.addEventListener("click", enter, true);
    window.addEventListener("auxclick", enter, true);
    return () => {
      window.removeEventListener("keydown", enter, true);
      window.removeEventListener("click", enter, true);
      window.removeEventListener("auxclick", enter, true);
    };
  }, [ready, error, game, onContinue, onBegin, reduceMotion]);
  useEffect(() => {
    if (!game) return;
    let active = true;
    setError("");
    setReady(false);
    Promise.all([
      game.prepare(),
      document.fonts.ready,
      assetManager.preload(
        Object.values(BOOKS).flatMap((b) => (b.artwork ? [b.artwork] : [])),
      ),
    ])
      .then(() => {
        if (active) setReady(true);
      })
      .catch((e) => {
        if (active) setError(String(e.message || e));
      });
    return () => {
      active = false;
    };
  }, [game, attempt]);
  return (
    <GameText>
      <div
        className="startup-gate"
        data-ready={ready}
        data-leaving={leaving}
        role="dialog"
        aria-modal="true"
        aria-label="唤醒咒典"
        aria-describedby="startupPrompt"
        aria-busy={!ready && !error}
        data-menu-root
        tabIndex={-1}
      >
        <div className="startup-atmosphere" aria-hidden="true">
          <div className="startup-aperture" />
          <div className="startup-halo" />
          <Sigil className="startup-orbit" progress={0.18} />
          {Array.from({ length: 64 }, (_, i) => (
            <i
              key={i}
              style={
                {
                  "--x": `${(i * 37 + 11) % 100}%`,
                  "--y": `${(i * 23 + 7) % 100}%`,
                  "--delay": `${-i * 0.83}s`,
                  "--duration": `${7 + (i % 6)}s`,
                  "--size": `${1.5 + (i % 4)}px`,
                } as CSSProperties
              }
            />
          ))}
        </div>
        <div className="startup-content">
          <Sigil className="startup-mark" progress={ready ? 1 : 0.18} />
          <h1>键渊</h1>
          <span className="startup-subtitle">失 控 咒 典</span>
          <div className="startup-rule" aria-hidden="true" />
          <p id="startupPrompt" role="status">
            {error ||
              (ready ? (
                <>
                  <span id="enterGame">点击任意位置或按任意键继续</span>
                  <small>PRESS ANY KEY TO CONTINUE</small>
                </>
              ) : (
                "正在唤醒咒典"
              ))}
          </p>
          {error && (
            <Button word="retry" onClick={() => setAttempt((n) => n + 1)}>
              重新加载
            </Button>
          )}
        </div>
      </div>
    </GameText>
  );
}
