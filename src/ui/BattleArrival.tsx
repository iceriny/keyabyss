import { useEffect, useRef, type CSSProperties } from "react";
import type { Book } from "../contracts/game.ts";
import { BookArtwork } from "./BookArtwork";
import { Sigil } from "./Sigil";

/** Runs only after resources are ready. The world starts at the reveal cue. */
export function BattleArrival({ book, reduced, reveal, complete, sound, origin }: {
  origin?: { x: number; y: number };
  book: Book; reduced: boolean; reveal: () => void; complete: () => void;
  sound: (cue: "ritualRise" | "ritualImpact") => void;
}) {
  const callbacks = useRef({ reveal, complete, sound });
  callbacks.current = { reveal, complete, sound };
  useEffect(() => {
    const less = reduced || matchMedia("(prefers-reduced-motion: reduce)").matches;
    let revealed = false;
    const guard = (event: KeyboardEvent) => {
      if (revealed || event.key === "F11") return;
      event.preventDefault();
      event.stopImmediatePropagation();
    };
    window.addEventListener("keydown", guard, true);
    if (!less) callbacks.current.sound("ritualRise");
    const open = setTimeout(() => {
      revealed = true;
      callbacks.current.reveal();
      if (!less) callbacks.current.sound("ritualImpact");
    }, less ? 100 : 1200);
    const end = setTimeout(() => callbacks.current.complete(), less ? 240 : 2000);
    return () => { clearTimeout(open); clearTimeout(end); window.removeEventListener("keydown", guard, true); };
  }, [reduced]);
  return <div className={`battle-arrival${reduced ? " reduced" : ""}${origin ? " in-place" : ""}`} style={{ "--arrival-color": book.color, "--arrival-x": origin ? `${origin.x}px` : "50%", "--arrival-y": origin ? `${origin.y}px` : "44%" } as CSSProperties} aria-hidden="true">
    <div className="arrival-veil" />
    <div className="arrival-gate"><Sigil progress={1} /></div>
    <div className="arrival-wave" />
    {!origin && <div className="arrival-book"><BookArtwork book={book} decorative /></div>}
    <div className="arrival-caption"><small>THE EXPEDITION BEGINS</small><strong>{book.name}</strong><span>落笔 · 入境</span></div>
    <div className="arrival-motes">{Array.from({ length: 24 }, (_, i) => <i key={i} style={{ "--angle": `${i * 137.5}deg`, "--travel": `${28 + i % 7 * 5}vmin`, "--delay": `${i % 5 * 40}ms` } as CSSProperties} />)}</div>
  </div>;
}
