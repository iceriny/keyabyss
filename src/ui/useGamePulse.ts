import { useSyncExternalStore } from "react";
import type { SessionView } from "../contracts/session.ts";
export function useGamePulse(game: SessionView) {
  return useSyncExternalStore(
    game.subscribe,
    game.getSnapshot,
    game.getSnapshot,
  );
}
