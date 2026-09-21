import { relicArt } from "./relic-art";
const routeArt: Record<string, string> = {
  rest: relicArt.heal, gift: relicArt.gold, shelter: relicArt.ward,
  trade: relicArt.bond, forge: relicArt.crucible, trial: relicArt.sacrifice,
  renewal: relicArt.heal,
};
/** Vector artwork inherits the rarity/school color and never relies on a symbol font. */
export function RelicIcon({ id }: { id: string }) {
  const path = relicArt[id] ?? routeArt[id] ?? "M15 12H48V53H15ZM23 12V53M30 23H41M30 32H41";
  return <svg className="relic-art" data-relic-icon={id} viewBox="0 0 64 64" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false"><path d={path} /></svg>;
}
