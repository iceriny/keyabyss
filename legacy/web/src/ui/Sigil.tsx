import { runeGlyphs, starPath } from "../shared/sigil";
/** Concentric inscription, interlocking stars and satellite seals. */
export function Sigil({
  className = "",
  progress = 1,
}: {
  className?: string;
  progress?: number;
}) {
  return (
    <svg
      className={`sigil ${className}`}
      viewBox="0 0 100 100"
      aria-hidden="true"
      focusable="false"
    >
      <g fill="none" stroke="currentColor" strokeWidth=".28">
        {[46, 44, 37, 35].map((r, i) => (
          <circle key={r} cx="50" cy="50" r={r} opacity={i % 2 ? 0.6 : 0.3} />
        ))}
        <circle
          className="sigil-progress"
          cx="50"
          cy="50"
          r="46"
          pathLength="1"
          strokeDasharray={`${Math.max(0, Math.min(1, progress))} 1`}
          transform="rotate(-90 50 50)"
        />
        <g className="sigil-orbit">
          {Array.from({ length: 36 }, (_, i) => (
            <g
              key={i}
              transform={`translate(50 50) rotate(${i * 10}) translate(0 -40.5)`}
            >
              <path
                d={runeGlyphs[i % runeGlyphs.length]}
                transform="scale(.46)"
                strokeWidth=".65"
              />
            </g>
          ))}
        </g>
        <g className="sigil-core">
          <path d={starPath(50, 50, 34, 7, 3)} opacity=".58" />
          <path d={starPath(50, 50, 31, 7, 2)} opacity=".26" />
          <circle cx="50" cy="50" r="24" opacity=".55" />
          {[0, 120, 240].map((angle) => (
            <g key={angle} transform={`rotate(${angle} 50 50)`}>
              <circle cx="50" cy="27" r="9" />
              <circle cx="50" cy="27" r="7.5" opacity=".5" />
              <path d={starPath(50, 27, 6.5, 5, 2)} />
              <circle cx="50" cy="27" r="2" />
              <path d="M50 1V12M47 7H53M50 12L48 10M50 12L52 10" />
            </g>
          ))}
        </g>
        <circle cx="50" cy="50" r="9" />
        <circle cx="50" cy="50" r="7" opacity=".5" />
        <path d={starPath(50, 50, 5.5, 6, 1)} opacity=".8" />
        <circle cx="50" cy="50" r="1.4" fill="currentColor" stroke="none" />
      </g>
    </svg>
  );
}
