import type { Vocabulary } from "../contracts/game.ts";

/** Classic-script vocabulary bridge is restricted to this loading adapter. */
export function builtinVocabularies(): readonly Vocabulary[] {
  return window.KAVOCAB.books;
}
