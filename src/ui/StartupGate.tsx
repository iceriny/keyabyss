import { read, save } from "./storage";
import { GameText } from "./GameText";
import { useEffect, useRef, useState, type CSSProperties } from "react";
import type { SessionView } from "../contracts/session.ts";
import { assetManager } from "../bootstrap/assets.ts";
import { BOOKS } from "../content/catalog.ts";
import { Sigil } from "./Sigil";
import { Button } from "./components";
import { StartupWave, startupTiming } from "./StartupWave";
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
    [leaving, setLeaving] = useState(false),
    [skipping, setSkipping] = useState(false),
    [phase, setPhase] = useState("封印回应"),
    [waveStartedAt, setWaveStartedAt] = useState<number | null>(null);
  const [canSkip] = useState(() => read("intro-complete", false));
  const gate = useRef<HTMLDivElement>(null);
  const settling = useRef(false), beganAt = useRef(0);
  const fades = useRef<Animation[]>([]);
  const continued = useRef(false),
    timers = useRef<ReturnType<typeof setTimeout>[]>([]);
  useEffect(() => () => {
    timers.current.forEach(clearTimeout);
    fades.current.forEach(animation => animation.cancel());
  }, []);
  useEffect(() => {
    const enter = (event: Event) => {
      // Preserve the browser's native fullscreen toggle without entering the game.
      if (event instanceof KeyboardEvent && event.key === "F11") {
        event.stopImmediatePropagation();
        return;
      }
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
      if (event instanceof KeyboardEvent && event.repeat) return;
      if (continued.current) {
        if (!canSkip || settling.current || performance.now() - beganAt.current < 350) return;
        settling.current = true;
        setSkipping(true);
        timers.current.forEach(clearTimeout);
        timers.current = [];
        const reduced = reduceMotion || matchMedia("(prefers-reduced-motion: reduce)").matches;
        const duration = reduced ? 160 : 650;
        const overlay = gate.current;
        const home = document.querySelector<HTMLElement>(".home-arrival #home");
        // Continue from the exact visible frame, including late-stage partial fades.
        if (overlay) {
          const opacity = getComputedStyle(overlay).opacity;
          overlay.getAnimations({ subtree: true }).forEach(animation => animation.pause());
          fades.current.push(overlay.animate([{ opacity }, { opacity: 0 }],
            { duration, easing: "cubic-bezier(.22,.61,.36,1)", fill: "forwards" }));
        }
        if (home) {
          const { opacity, filter } = getComputedStyle(home);
          home.getAnimations().forEach(animation => animation.pause());
          fades.current.push(home.animate([{ opacity, filter }, { opacity: 1, filter: "blur(0px)" }],
            { duration, easing: "cubic-bezier(.22,.61,.36,1)", fill: "forwards" }));
        }
        timers.current.push(setTimeout(onContinue, duration));
        return;
      }
      continued.current = true;
      beganAt.current = performance.now();
      game?.unlockAudio();
      game?.playUISound("enter");
      setLeaving(true);
      onBegin();
      const reduced = reduceMotion || matchMedia("(prefers-reduced-motion: reduce)").matches;
      const at = (ms: number, action: () => void) => timers.current.push(setTimeout(action, ms));
      if (!reduced) {
        setWaveStartedAt(performance.now());
        at(startupTiming.rise, () => { setPhase("静候回响"); game?.playUISound("ritualRise"); });
        at(startupTiming.impact, () => { setPhase("破印 · 苏醒"); game?.playUISound("ritualImpact"); });
        at(startupTiming.chime, () => { setPhase("咒典在等待你的名字"); game?.playUISound("ritualChime"); });
      }
      at(reduced ? 240 : startupTiming.duration, () => {
        save("intro-complete", true);
        onContinue();
      });
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
  }, [ready, error, game, onContinue, onBegin, reduceMotion, canSkip]);
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
        ref={gate}
        className="startup-gate"
        data-skipping={skipping}
        data-ready={ready}
        data-leaving={leaving}
        style={{
          "--ritual-impact-delay": `${startupTiming.impact}ms`,
          "--ritual-wave-duration": `${startupTiming.waveEnd - startupTiming.impact}ms`,
        } as CSSProperties}
        role="dialog"
        aria-modal="true"
        aria-label="唤醒咒典"
        aria-describedby="startupPrompt"
        aria-busy={!ready && !error}
        data-menu-root
        tabIndex={-1}
      >
        <StartupWave startedAt={waveStartedAt} frozen={skipping}>
        <div className="startup-atmosphere" aria-hidden="true">
          <div className="startup-halo" />
          <div className="ritual-seal-bloom" />
          <div className="ritual-rings"><b /><b /><b /></div>
          <div className="ritual-rays">
            {Array.from({ length: 24 }, (_, i) => <b key={i} style={{ "--ray": i } as CSSProperties} />)}
          </div>
          <div className="ritual-shock" />
          <div className="ritual-flare" />
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
                  <small>F11 切换全屏 · 其他任意键继续</small>
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
        </StartupWave>
        {leaving && <div className="ritual-phase" role="status"><span>{phase}</span><small>THE ARCHIVE AWAKENS</small></div>}
      </div>
    </GameText>
  );
}
