import { useEffect, useRef } from "react";

/** Event-driven pointer. No render loop, hit testing or interception of game input. */
export function ArcaneCursor() {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current!;
    let pending = 0,
      timer: ReturnType<typeof setTimeout>;
    const hide = () => {
      el.hidden = true;
      document.body.classList.remove("arcane-pointer");
    };
    const move = (e: PointerEvent) => {
      if (e.pointerType === "touch") {
        hide();
        return;
      }
      el.hidden = false;
      document.body.classList.add("arcane-pointer");
      el.dataset.hot = String(
        !!(e.target as HTMLElement).closest(
          "button,a,input,textarea,[role=option],[data-tooltip-title]",
        ),
      );
      cancelAnimationFrame(pending);
      pending = requestAnimationFrame(() => {
        el.style.transform = `translate3d(${e.clientX}px,${e.clientY}px,0)`;
      });
    };
    const click = () => {
      el.classList.remove("cursor-pulse");
      void el.offsetWidth;
      el.classList.add("cursor-pulse");
      clearTimeout(timer);
      timer = setTimeout(() => el.classList.remove("cursor-pulse"), 420);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerdown", click);
    window.addEventListener("blur", hide);
    document.documentElement.addEventListener("pointerleave", hide);
    return () => {
      cancelAnimationFrame(pending);
      clearTimeout(timer);
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerdown", click);
      window.removeEventListener("blur", hide);
      document.documentElement.removeEventListener("pointerleave", hide);
      document.body.classList.remove("arcane-pointer");
    };
  }, []);
  return (
    <div ref={ref} className="arcane-cursor" aria-hidden="true" hidden>
      <svg viewBox="0 0 32 32">
        <path d="M2 2L10 24L14 14L24 10Z" />
        <path d="M14 14L24 24" />
      </svg>
      <i />
      <b />
    </div>
  );
}
