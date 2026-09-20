import { GameText } from "./GameText";
import { BookArtwork } from "./BookArtwork";
import type { SessionView as Game } from "../contracts/session.ts";
import { ROUTES } from "../content/catalog.ts";
import { type CSSProperties } from "react";
import { Sigil } from "./Sigil";
import { useGamePulse } from "./useGamePulse";
import type { Relic, Report, Route } from "../contracts/game.ts";
import { C, download, fmt } from "./storage";
import { Button, ChoiceCard, Key, Meter, Stat } from "./components";

export function HUD({
  game,
  meaning,
  announcement,
  onBag,
}: {
  game: Game;
  meaning: boolean;
  announcement: string;
  onBag: () => void;
}) {
  useGamePulse(game);
  const p = game.player,
    b = game.bookData,
    target = game.target && !game.target.dead ? game.target : null,
    boss = game.boss && !game.boss.dead ? game.boss : null;
  if (!b || !game.mode) return null;
  return (
    <GameText>
      <div id="hud" style={{ "--school": b.color } as CSSProperties}>
        {game.godMode && <div className="god-mode-badge">GOD MODE · ∞</div>}
        <div className="hud-top">
          <section className="health-block">
            <div>
              <strong className="hud-book-name">
                <BookArtwork book={b} decorative />
                {b.name}
              </strong>
              <span>
                {Math.ceil(p.hp)} / {p.maxHp}
              </span>
            </div>
            <Meter label="生命" value={p.hp / p.maxHp} />
            <div className="hud-secondary">
              <span>护盾 {Math.ceil(p.shield)}</span>
              <span>
                闪避 {game.godMode ? "∞" : "◆".repeat(Math.floor(p.dash))}
                {"◇".repeat(Math.max(0, p.maxDash - Math.floor(p.dash)))}
              </span>
            </div>
          </section>
          <div className="chapter-block">
            <span
              className={announcement ? "announcement" : ""}
              aria-live="polite"
            >
              {announcement ||
                `第 ${game.chapter + 1} 章 · ${game.chapterName}`}
            </span>
            <div className="room-dots">
              {Array.from({ length: game.roomCount }, (_, i) => i).map((i) => (
                <i key={i} className={i <= game.roomNumber ? "active" : ""} />
              ))}
            </div>
            <span>
              {game.bossRoom
                ? "守页者之战"
                : `第 ${game.wave} / ${game.waveCount} 波 · ${game.spawned} / ${game.roomQuota}`}
            </span>
          </div>
          <div className="battle-actions">
            <span>
              {fmt(game.elapsed)} · {game.kills} 击破
            </span>
            <Button id="pauseBtn" onClick={() => game.pause()}>
              暂停 <Key>Esc</Key>
            </Button>
          </div>
        </div>
        {boss && game.bossRoom && (
          <div id="bossHUD" className="boss-hud">
            <span>
              {game.bossName} · 阶段 {boss.phase} / 3
            </span>
            <Meter label="守页者生命" value={boss.hp / boss.maxHp} />
          </div>
        )}
        <div className="combat-side">
          <strong>{game.combo}</strong>
          <span>连笔</span>
          <div className="cadence">
            {Array.from({ length: b.cycle }, (_, i) => (
              <i
                key={i}
                className={i < game.bookCounter % b.cycle ? "active" : ""}
              />
            ))}
          </div>
          <span>{b.cadence}</span>
        </div>
        <Button className="build-button" onClick={onBag}>
          构筑 · {Object.keys(game.relics).length}
        </Button>
        <div
          className={`defense-readout ${p.parryTime > 0 ? "active" : p.parryCooldown <= 0 ? "ready" : ""}`}
        >
          <span>
            <Key>Space</Key>{" "}
            {p.parryTime > 0
              ? "弹反中"
              : p.parryCooldown > 0
                ? `弹反 ${p.parryCooldown.toFixed(1)}s`
                : "弹反就绪"}
          </span>
          <small>方向键 · 闪避 / Alt · 自动择位</small>
          {p.invuln > 0 && (
            <small className="invulnerability">
              无敌 {p.invuln.toFixed(1)}s
            </small>
          )}
        </div>
        <div className="hud-bottom">
          <div className="level-block">
            <strong>LV {game.level}</strong>
            <Meter label="经验" value={game.xp / game.nextXP} />
            <span>
              {Math.floor(game.xp)} / {game.nextXP} XP
            </span>
          </div>
          <div
            className="cast-box"
            id="castBox"
            data-casting={!!target}
            style={
              {
                "--cast-progress": target
                  ? game.prefix.length / target.word.length
                  : 0,
              } as CSSProperties
            }
          >
            <span className="cast-label">
              {game.precisionTime > 0
                ? `停笔 ${game.precisionTime.toFixed(1)}s · 继续施法`
                : target
                  ? "正在施法"
                  : "输入咒文"}
            </span>
            <div id="castWord" className="cast-word" data-plain-text>
              {target ? (
                <>
                  <span className="typed">{game.prefix}</span>
                  {target.word.slice(game.prefix.length)}
                </>
              ) : (
                <span className="cast-ready">READY TO CAST</span>
              )}
            </div>
            <div className="cast-meaning">
              {game.precisionTime > 0
                ? "咒文进度已保留"
                : target && meaning
                  ? target.meaning || "完成咒文即可施法"
                  : "Tab 切换目标 · ⌫ 取消锁定"}
            </div>
          </div>
          <div className="ultimate-block">
            <Button
              id="ultimateBtn"
              className={game.resonance >= 100 ? "ready" : ""}
              onClick={() => game.input("Shift")}
            >
              <Sigil
                className="ability-sigil"
                progress={game.resonance / 100}
              />
              <Key>Shift</Key> {b.ultimate}
              <strong>
                {game.godMode
                  ? "∞"
                  : game.ultimateTime > 0
                    ? `${game.ultimateTime.toFixed(1)}s`
                    : `${Math.floor(game.resonance)}%`}
              </strong>
            </Button>
            <Meter label="共鸣" value={game.resonance / 100} />
            <span>闪避后无敌 1 秒</span>
          </div>
        </div>
      </div>
    </GameText>
  );
}
export function UpgradePanel({
  game,
  choices,
  onQuit,
}: {
  game: Game;
  choices: import("../contracts/rewards.ts").RewardChoice[];
  onQuit: () => void;
}) {
  return (
    <GameText>
      <>
        <div className="choice-grid">
          {choices.map((r, i) => (
            <ChoiceCard
              key={r.id}
              data-upgrade={r.id}
              word={r.command ?? r.id}
              shortcut={String(i + 1)}
              icon={r.icon}
              tag={
                r.rarity === "awaken"
                  ? "咒典觉醒"
                  : r.rarity === "curse"
                    ? "诅咒遗物"
                    : r.tag
              }
              title={r.name}
              description={r.desc}
              className={r.rarity || ""}
              onClick={() => game.chooseUpgrade(r.id)}
            />
          ))}
        </div>
        <div className="modal-footer">
          <Button
            word="reroll"
            disabled={game.rerolls <= 0}
            onClick={() => game.rerollUpgrade()}
          >
            重掷 · {game.rerolls}
          </Button>
          <Button word="quit" onClick={onQuit}>
            结束本局
          </Button>
          <span>LV {game.level}</span>
        </div>
      </>
    </GameText>
  );
}
export function RoutePanel({
  game,
  offers,
  onQuit,
}: {
  game: Game;
  offers: readonly import("../contracts/content.ts").RouteDefinition[];
  onQuit: () => void;
}) {
  const trial = C.difficulty(game.mode, game.stage, 0, true);
  return (
    <GameText>
      <>
        <p>
          生命 {Math.ceil(game.player.hp)} / {game.player.maxHp}
          {game.nextRoomIsBoss && " · 下一页：守页者"}
        </p>
        <div className="choice-grid">
          {offers.map((r, i) => {
            return (
              <ChoiceCard
                key={r.id}
                word={r.word}
                shortcut={String(i + 1)}
                data-route={i}
                icon={r.icon}
                title={r.name}
                description={
                  r.type === "elite"
                    ? `下一页敌人生命 +${Math.round((trial.trialHealth - 1) * 100)}%，击杀经验 +${Math.round((trial.trialXP - 1) * 100)}%。`
                    : r.desc
                }
                onClick={() => game.chooseRoute(r.id)}
              />
            );
          })}
        </div>
        <div className="modal-footer">
          <span>
            第 {game.stage + 1} 页 / 周目 {game.loopCount + 1}
          </span>
          <Button word="quit" onClick={onQuit}>
            结束本局
          </Button>
        </div>
      </>
    </GameText>
  );
}
export function ResultPanel({
  report,
  game,
  onRetry,
}: {
  report: Report;
  game: Game;
  onRetry: () => void;
}) {
  const mistakes = Object.entries(report.words)
    .filter(([, s]) => s.errors > 0)
    .sort((a, b) => b[1].errors - a[1].errors)
    .slice(0, 12);
  return (
    <GameText>
      <>
        <div className="stats-grid">
          <Stat label="击破" value={report.kills} />
          <Stat label="最高连笔" value={report.maxCombo} />
          <Stat
            label="准确率"
            value={`${(report.accuracy * 100).toFixed(1)}%`}
          />
          <Stat label="WPM" value={Math.round(report.wpm)} />
        </div>
        <p>
          {fmt(report.elapsed)} · {report.casts} 次施法 ·{" "}
          {C.MODES[report.mode].name}
        </p>
        <p>
          {report.vocab} · 种子 {report.seed}
        </p>
        {mistakes.length > 0 && (
          <div className="word-preview">
            {mistakes.map(([w, s]) => (
              <span key={w}>
                {w} · {s.errors} 错
              </span>
            ))}
          </div>
        )}
        <div className="modal-footer">
          <Button word="home" onClick={() => game.home()}>
            返回书库
          </Button>
          <Button
            word="report"
            onClick={() => download(report, "keyabyss-report.json")}
          >
            导出战报
          </Button>
          {report.win ? (
            <Button
              word="next"
              variant="primary"
              onClick={() => game.continueLoop()}
            >
              下一周目 →
            </Button>
          ) : (
            <Button word="retry" variant="primary" onClick={onRetry}>
              再写一局 →
            </Button>
          )}
        </div>
      </>
    </GameText>
  );
}
