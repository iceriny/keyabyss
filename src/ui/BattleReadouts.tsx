import { useState, type CSSProperties } from "react";
import type { SessionView } from "../contracts/session.ts";
import { BookArtwork } from "./BookArtwork";
import { GameText } from "./GameText";
import { Sigil } from "./Sigil";
import { Tooltip } from "./Tooltip";
import { C } from "./storage";

/** Shield gains currently cap at 60; keep a stable scale as it is consumed. */
export function VitalBars({ player }: { player: SessionView["player"] }) {
  const bars = [
    { id: "health", name: "生命", value: Math.max(0, player.hp), max: player.maxHp },
    { id: "shield", name: "护盾", value: Math.max(0, player.shield), max: Math.max(60, player.shield) },
  ];
  return <div className="vital-bars">{bars.map(bar => <div className={`vital-line ${bar.id}`} key={bar.id}>
    <div className="vital-caption"><span>{bar.name}</span><span>{Math.ceil(bar.value)}{bar.id === "health" ? ` / ${bar.max}` : ""}</span></div>
    <div className="meter" role="progressbar" aria-label={bar.name} aria-valuemin={0} aria-valuemax={bar.max} aria-valuenow={Math.min(bar.value, bar.max)} aria-valuetext={`${Math.ceil(bar.value)} 点${bar.name}`}>
      <i style={{ width: `${Math.min(1, bar.value / Math.max(1, bar.max)) * 100}%` }} />
    </div>
  </div>)}</div>;
}

export function ComboReadout({ combo, counter, cycle, cadence }: { combo: number; counter: number; cycle: number; cadence: string }) {
  const [change, setChange] = useState({ value: combo, rising: false, serial: 0 });
  if (change.value !== combo) setChange({ value: combo, rising: combo > change.value, serial: change.serial + 1 });
  const strength = Math.min(1, Math.sqrt(Math.max(0, combo) / 100));
  return <div className="combat-side" data-combo={combo} style={{ "--combo-size": `${28 + strength * 36}px`, "--combo-glow": `${3 + strength * 25}px`, "--combo-burst": 1.04 + strength * .3, "--combo-strength": .12 + strength * .48 } as CSSProperties}>
    <div className="combo-figure" key={change.serial} data-change={change.rising ? "rise" : "fall"} data-plain-text>
      <strong className="combo-value">{combo}</strong>
      {change.rising && <><span className="combo-echo" aria-hidden="true">{combo}</span><i className="combo-ring" aria-hidden="true" /></>}
    </div>
    <div className="combo-caption"><span>连笔</span><div className="cadence" aria-hidden="true">{Array.from({length: cycle},(_,i)=><i key={i} className={i < counter % cycle ? "active" : ""} />)}</div><small>{cadence}</small></div>
  </div>;
}

export function UpgradeCompanion({ game }: { game: SessionView }) {
  const b = game.bookData;
  return <GameText><aside className="upgrade-companion" aria-label="当前法书与构筑" style={{ "--school": b.color } as CSSProperties}>
    <div className="companion-book" aria-hidden="true"><Sigil /><BookArtwork book={b} decorative /><i /><i /></div>
    <section className="companion-vitals"><span className="companion-caption">此刻的你</span><strong>{b.name}</strong><VitalBars player={game.player} /></section>
    <section className="companion-build"><h3>当前构筑 <small>{Object.keys(game.relics).length} 件遗物</small></h3>
      <div className="companion-relics" data-prose>{Object.entries(game.relics).length ? Object.entries(game.relics).map(([id, count]) => {
        const relic = C.RELICS.find(r => r.id === id);
        return <span key={id}>{relic ? <Tooltip title={relic.name} description={relic.desc} category="遗物" term={relic.id}>{relic.name}</Tooltip> : id}{count > 1 && <small> ×{count}</small>}</span>;
      }) : <span className="companion-empty">此行尚未获得遗物</span>}</div>
    </section>
  </aside></GameText>;
}
