import { Sigil } from "./Sigil";
import type { CSSProperties } from "react";
export function Portal({
  color,
  reduced,
  density,
}: {
  color: string;
  reduced: boolean;
  density: number;
}) {
  return (
    <div
      className="portal"
      data-static={reduced || density < 0.5}
      style={{ "--school": color } as CSSProperties}
      aria-hidden="true"
    >
      <Sigil className="portal-core" />
      <svg viewBox="0 0 600 600">
        <g fill="none" stroke="var(--school)">
          <circle cx="300" cy="300" r="191" opacity=".34" />
          <circle
            cx="300"
            cy="300"
            r="207"
            opacity=".25"
            strokeDasharray="2 22"
          />
          <path
            d="M300 82V105 M300 495V518 M82 300H105 M495 300H518"
            opacity=".7"
          />
          <rect
            x="163"
            y="163"
            width="274"
            height="274"
            transform="rotate(45 300 300)"
            opacity=".14"
          />
        </g>
      </svg>
    </div>
  );
}
