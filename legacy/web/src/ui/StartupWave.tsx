import { useEffect, useId, useRef, type ReactNode } from "react";

export const startupTiming = {
  duration: 7000,
  firstEnd: 1150,
  rise: 1200,
  impact: 2400,
  waveEnd: 5450,
  chime: 5700,
} as const;

let displacementMap: string | undefined;
/** A static radial vector field, expanded by SVG; no per-frame image encoding. */
function radialDisplacement() {
  if (displacementMap) return displacementMap;
  const size = 384, canvas = document.createElement("canvas");
  canvas.width = canvas.height = size;
  const context = canvas.getContext("2d")!;
  const image = context.createImageData(size, size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const dx = (x + .5) / size * 2 - 1, dy = (y + .5) / size * 2 - 1;
    const radius = Math.hypot(dx, dy), distance = (radius - .72) / .10;
    const bend = Math.exp(-distance * distance) * Math.sin(distance * 2.2);
    const offset = (y * size + x) * 4;
    image.data[offset] = 128 + dx / Math.max(radius, .001) * bend * 120;
    image.data[offset + 1] = 128 + dy / Math.max(radius, .001) * bend * 120;
    image.data[offset + 2] = 128;
    image.data[offset + 3] = 255;
  }
  context.putImageData(image, 0, 0);
  return displacementMap = canvas.toDataURL();
}

/** Distorts actual startup pixels. Wave light and refraction share one radius/clock. */
export function StartupWave({ startedAt, children, frozen = false }: { startedAt: number | null; children: ReactNode; frozen?: boolean }) {
  const freeze = useRef(frozen);
  freeze.current = frozen;
  const id = `startup-wave-${useId().replace(/[^a-zA-Z0-9_-]/g, "")}`;
  const layer = useRef<HTMLDivElement>(null);
  const field = useRef<SVGFEImageElement>(null);
  const displacement = useRef<SVGFEDisplacementMapElement>(null);
  useEffect(() => { field.current?.setAttribute("href", radialDisplacement()); }, []);
  useEffect(() => {
    if (startedAt === null) return;
    const element = layer.current!, image = field.current!, map = displacement.current!;
    let frame = 0;
    const tick = () => {
      if (freeze.current) return;
      const elapsed = performance.now() - startedAt;
      const first = elapsed < startupTiming.impact;
      const progress = Math.max(0, Math.min(1, first
        ? elapsed / startupTiming.firstEnd
        : (elapsed - startupTiming.impact) / (startupTiming.waveEnd - startupTiming.impact)));
      const width = element.clientWidth, height = element.clientHeight;
      const farthest = Math.hypot(width * .5, height * .52);
      const radius = Math.min(width, height) * .11 + farthest * 1.24 * Math.pow(progress, first ? .85 : .78);
      const envelope = Math.min(1, progress / (first ? .025 : .035)) * Math.min(1, (1 - progress) / (first ? .3 : .22));
      const extent = radius / .72;
      image.setAttribute("x", String(width * .5 - extent));
      image.setAttribute("y", String(height * .48 - extent));
      image.setAttribute("width", String(extent * 2));
      image.setAttribute("height", String(extent * 2));
      map.setAttribute("scale", String((first ? 95 : 270) * envelope));
      element.style.filter = envelope > 0 ? `url(#${id})` : "none";
      element.style.setProperty("--wave-radius", `${radius}px`);
      element.style.setProperty("--wave-light", String(envelope * (first ? .48 : 1)));
      element.dataset.wave = envelope === 0 ? "hold" : first ? "first" : "second";
      if (elapsed < startupTiming.waveEnd) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(frame);
      element.style.filter = "none";
      element.style.setProperty("--wave-light", "0");
    };
  }, [startedAt, id]);
  return <>
    <svg className="startup-filter" aria-hidden="true" width="0" height="0">
      <defs>
        <filter id={id} x="-5%" y="-5%" width="110%" height="110%" colorInterpolationFilters="sRGB">
          <feFlood floodColor="#808080" result="neutral" />
          <feImage ref={field} preserveAspectRatio="none" result="radial" />
          <feComposite in="radial" in2="neutral" operator="over" result="field" />
          <feFlood floodColor="#080e16" result="backdrop" />
          <feComposite in="SourceGraphic" in2="backdrop" operator="over" result="source" />
          <feDisplacementMap ref={displacement} in="source" in2="field" scale="0" xChannelSelector="R" yChannelSelector="G" />
        </filter>
      </defs>
    </svg>
    <div className="startup-visual" ref={layer}>{children}</div>
  </>;
}
