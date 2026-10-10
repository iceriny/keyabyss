/** Invented stroke glyphs shared by the UI seal and exported vector artwork. */
export const runeGlyphs = [
  "M0 -4V4M-3 -2L0 -4L3 -2M-2 1H2",
  "M-3 -4L3 0L-3 4V-4M0 -2V2",
  "M-3 -3L0 0L3 -3M0 0V4M-2 2H2",
  "M-3 4V-4L3 1H-3M0 1L3 4",
  "M0 -4L3 0L0 4L-3 0ZM0 -4V4",
  "M-3 -4V4M3 -4V4M-3 0L3 -2M-3 3L3 1",
  "M-3 -2Q0 -6 3 -2Q4 1 0 2V4M-2 0H2",
  "M-3 -4L0 -1L3 -4M-3 4L0 1L3 4M0 -1V1",
  "M-3 3L0 -4L3 3ZM-2 0H2M0 3V5",
  "M-3 -4L3 4M3 -4L-3 4M-3 0H3",
  "M-3 -3H3L-3 3H3M0 -5V5",
  "M-3 0A3 3 0 1 1 3 0A3 3 0 1 1 -3 0M0 -5V5",
] as const;
export function starPath(
  cx: number,
  cy: number,
  r: number,
  count: number,
  step: number,
  offset = -Math.PI / 2,
) {
  return (
    Array.from({ length: count }, (_, i) => {
      const a = offset + (((i * step) % count) * Math.PI * 2) / count;
      return `${i ? "L" : "M"}${(cx + Math.cos(a) * r).toFixed(3)} ${(cy + Math.sin(a) * r).toFixed(3)}`;
    }).join("") + "Z"
  );
}
