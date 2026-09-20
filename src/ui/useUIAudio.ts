import { useEffect, useRef } from 'react';
import type { SessionView } from '../contracts/session.ts';
/** Shared button feedback includes mouse, focus navigation and command-triggered clicks. */
export function useUIAudio(game: SessionView | null, entered: boolean, depth: number, panel?: string) {
  const previous = useRef({ depth, panel, entered });
  useEffect(() => {
    const old = previous.current;
    previous.current = { depth, panel, entered };
    if (!game || !entered) return;
    if (!old.entered) return; // The startup gate owns its timed arrival sound.
    else if (depth > old.depth) game.playUISound('open');
    else if (depth < old.depth) game.playUISound('close');
    else if (panel !== old.panel) game.playUISound('tab');
  }, [game, entered, depth, panel]);
  useEffect(() => {
    if (!game || !entered) return;
    const button = (target: EventTarget | null) => target instanceof Element ? target.closest<HTMLButtonElement>('button:not(:disabled)') : null;
    const focus = (event: Event) => {
      const target = button(event.target);
      if (!target || event instanceof PointerEvent && target.contains(event.relatedTarget as Node | null)) return;
      game.playUISound('focus');
    };
    const select = (event: Event) => { if (button(event.target)) { game.unlockAudio(); game.playUISound('select'); } };
    document.addEventListener('pointerover', focus);
    document.addEventListener('focusin', focus);
    document.addEventListener('click', select, true);
    return () => { document.removeEventListener('pointerover', focus); document.removeEventListener('focusin', focus); document.removeEventListener('click', select, true); };
  }, [game, entered]);
}
