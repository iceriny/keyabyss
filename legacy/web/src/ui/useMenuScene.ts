import { useEffect, useRef } from "react";
import type { SessionView } from "../contracts/session.ts";
import type { MenuAnchor } from "../contracts/menu-scene.ts";

/** Layout is sampled on changes only; rendering consumes plain CSS-pixel anchors. */
export function useMenuScene(
  game: SessionView | null,
  color: string,
  school: string,
  reduced: boolean,
) {
  const root = useRef<HTMLElement>(null);
  useEffect(() => {
    if (!game || !root.current) return;
    const element = root.current,
      media = matchMedia("(prefers-reduced-motion: reduce)");
    let pending = 0, tracking = 0;
    const measure = () => {
      const anchors: MenuAnchor[] = [];
      const hero = element.querySelector<HTMLElement>(".hero-art");
      const icon = element.querySelector<HTMLElement>(
        ".choice-card.selected .choice-icon",
      );
      if (hero && getComputedStyle(hero).display !== "none") {
        const box = hero.getBoundingClientRect();
        anchors.push({
          x: box.x + box.width * 0.5,
          y: box.y + box.height * 0.44,
          radius: Math.min(box.width * 0.51, box.height * 0.46),
        });
      }
      if (icon) {
        const box = icon.getBoundingClientRect();
        anchors.push({
          x: box.x + box.width / 2,
          y: box.y + box.height / 2,
          radius: Math.max(box.width, box.height) * 0.86,
        });
      }
      game.setMenuScene({
        color,
        school: Math.max(
          0,
          ["frost", "storm", "spirit", "flame"].indexOf(school),
        ),
        anchors,
        reduced: reduced || media.matches,
      });
      if (performance.now() < tracking) pending = requestAnimationFrame(measure);
    };
    const schedule = () => {
      cancelAnimationFrame(pending);
      pending = requestAnimationFrame(measure);
    };
    const track = () => {
      tracking = performance.now() + 1300;
      schedule();
    };
    const observer = new ResizeObserver(schedule);
    observer.observe(element);
    const grid = element.querySelector(".book-grid");
    if (grid) observer.observe(grid);
    window.addEventListener("resize", schedule);
    window.addEventListener("scroll", schedule, true);
    media.addEventListener("change", schedule);
    // Re-measure after the existing entrance transform has settled.
    element.addEventListener("animationend", schedule);
    element.addEventListener("transitionend", schedule);
    element.addEventListener("transitionrun", track);
    schedule();
    return () => {
      cancelAnimationFrame(pending);
      observer.disconnect();
      window.removeEventListener("resize", schedule);
      window.removeEventListener("scroll", schedule, true);
      media.removeEventListener("change", schedule);
      element.removeEventListener("animationend", schedule);
      element.removeEventListener("transitionend", schedule);
      element.removeEventListener("transitionrun", track);
      game.setMenuScene(null);
    };
  }, [game, color, school, reduced]);
  return root;
}
