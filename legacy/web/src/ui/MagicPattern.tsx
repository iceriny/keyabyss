import type { CSSProperties } from "react";
import { assetManager } from "../bootstrap/assets.ts";

/** Native SVG images also work under file://, where external CSS masks are blocked. */
export function MagicPattern({
  school = "frost",
  className = "",
}: {
  school?: string;
  className?: string;
}) {
  const name = ["frost", "storm", "spirit", "flame"].includes(school)
    ? school
    : "frost";
  const hue: Record<string, number> = {
    frost: 145,
    storm: 0,
    spirit: 25,
    flame: 325,
  };
  return (
    <img
      alt=""
      aria-hidden="true"
      draggable={false}
      className={`magic-pattern ${className}`}
      src={assetManager.resolve(`rune-${name}`)}
      style={{ "--rune-hue": `${hue[name]}deg` } as CSSProperties}
    />
  );
}
