import {
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { createPortal } from "react-dom";
import {
  autoUpdate,
  computePosition,
  flip,
  offset,
  shift,
} from "@floating-ui/dom";
import { createTextTokenizer } from "../shared/game-text.ts";

/** No focus stops or click handlers: works inside buttons and existing manual navigation. */
export function Tooltip({
  title,
  description,
  category = "提示",
  term,
  children,
}: {
  title: string;
  description: string;
  category?: string;
  term?: string;
  children: ReactNode;
}) {
  return (
    <span
      className="game-term"
      data-rich-text
      data-tooltip-title={title}
      data-tooltip-description={description}
      data-tooltip-category={category}
      data-term={term}
    >
      {children}
    </span>
  );
}
const numbers = createTextTokenizer([]);
const numericText = (text: string) =>
  numbers(text, false).map((token, i) =>
    token.kind === "number" ? (
      <span className="game-number" key={i}>
        {token.value}
      </span>
    ) : (
      token.value
    ),
  );

/** One portal + one set of delegated listeners, regardless of the number of terms. */
export function TooltipHost({ scope }: { scope: string }) {
  const [anchor, setAnchor] = useState<HTMLElement | null>(null);
  const panel = useRef<HTMLDivElement>(null);
  const current = useRef(anchor);
  current.current = anchor;
  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    let pending: HTMLElement | null = null;
    let keyboard = false;
    const cancel = () => {
      clearTimeout(timer);
      pending = null;
    };
    const close = () => {
      cancel();
      setAnchor(null);
    };
    const eligible = (node: HTMLElement | null) =>
      !!node?.isConnected &&
      !!node.closest("p,li,dd,[data-prose]") &&
      !node.closest("[inert],[hidden]");
    const show = (node: HTMLElement | null) => {
      if (!eligible(node)) return;
      if (node === pending || node === current.current) {
        clearTimeout(timer);
        return;
      }
      cancel();
      pending = node;
      timer = setTimeout(() => {
        if (eligible(node)) setAnchor(node);
        pending = null;
      }, 280);
    };
    const over = (e: PointerEvent) => {
      if (e.pointerType === "touch" || keyboard) return;
      const el = e.target instanceof Element ? e.target : null;
      if (el?.closest("#gameTooltip")) {
        cancel();
        return;
      }
      show(el?.closest<HTMLElement>("[data-tooltip-title]") ?? null);
    };
    const out = (e: PointerEvent) => {
      const next = e.relatedTarget instanceof Element ? e.relatedTarget : null;
      if (
        next?.closest("#gameTooltip") ||
        (current.current &&
          next?.closest("[data-tooltip-title]") === current.current) ||
        (pending && next?.closest("[data-tooltip-title]") === pending)
      )
        return;
      cancel();
      timer = setTimeout(() => setAnchor(null), 160);
    };
    const key = (e: KeyboardEvent) => {
      keyboard = true;
      if (e.key === "Escape" && current.current) {
        e.preventDefault();
        e.stopImmediatePropagation();
        close();
      } else close();
    };
    const move = (e: PointerEvent) => {
      if (keyboard) {
        keyboard = false;
        over(e);
      }
    };
    close();
    document.addEventListener("pointerover", over);
    document.addEventListener("pointermove", move);
    document.addEventListener("pointerout", out);
    document.addEventListener("focusin", close);
    document.addEventListener("focusout", close);
    document.addEventListener("pointerdown", close);
    window.addEventListener("keydown", key, true);
    window.addEventListener("blur", close);
    document.addEventListener("visibilitychange", close);
    return () => {
      cancel();
      document.removeEventListener("pointerover", over);
      document.removeEventListener("pointermove", move);
      document.removeEventListener("pointerout", out);
      document.removeEventListener("focusin", close);
      document.removeEventListener("focusout", close);
      document.removeEventListener("pointerdown", close);
      window.removeEventListener("keydown", key, true);
      window.removeEventListener("blur", close);
      document.removeEventListener("visibilitychange", close);
    };
  }, [scope]);
  useLayoutEffect(() => {
    if (!anchor || !panel.current) return;
    const element = panel.current;
    let live = true;
    const previous = anchor.getAttribute("aria-describedby");
    anchor.setAttribute(
      "aria-describedby",
      [previous, "gameTooltip"].filter(Boolean).join(" "),
    );
    element.style.visibility = "hidden";
    const update = () => {
      if (
        !anchor.isConnected ||
        anchor.closest("[inert],[hidden]") ||
        !anchor.getClientRects().length
      ) {
        setAnchor(null);
        return;
      }
      void computePosition(anchor, element, {
        strategy: "fixed",
        placement: "top",
        middleware: [offset(12), flip({ padding: 16 }), shift({ padding: 16 })],
      }).then(({ x, y }) => {
        if (live)
          Object.assign(element.style, {
            left: `${x}px`,
            top: `${y}px`,
            visibility: "visible",
          });
      });
    };
    const cleanup = autoUpdate(anchor, element, update);
    const observer = new MutationObserver(() => {
      if (!anchor.isConnected || anchor.closest("[inert],[hidden]"))
        setAnchor(null);
    });
    observer.observe(document.body, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ["inert", "hidden"],
    });
    return () => {
      live = false;
      cleanup();
      observer.disconnect();
      if (previous === null) anchor.removeAttribute("aria-describedby");
      else anchor.setAttribute("aria-describedby", previous);
    };
  }, [anchor]);
  return anchor
    ? createPortal(
        <div
          id="gameTooltip"
          className="game-tooltip"
          role="tooltip"
          ref={panel}
          data-rich-text
        >
          <div className="tooltip-category">
            {anchor.dataset.tooltipCategory} · 咒典注解
          </div>
          <strong>{anchor.dataset.tooltipTitle}</strong>
          <p>{numericText(anchor.dataset.tooltipDescription ?? "")}</p>
          <div className="tooltip-rule" aria-hidden="true" />
        </div>,
        document.body,
      )
    : null;
}
