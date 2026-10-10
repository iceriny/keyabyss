import { useSyncExternalStore } from "react";

let held = false;
const listeners = new Set<() => void>();
const publish = (next: boolean) => {
  if (held === next) return;
  held = next;
  listeners.forEach((listener) => listener());
};
const down = (event: KeyboardEvent) => {
  if (event.code === "Backslash" || event.key === "\\") publish(true);
};
const up = (event: KeyboardEvent) => {
  if (event.code === "Backslash" || event.key === "\\") publish(false);
};
const reset = () => publish(false);
const visibility = () => {
  if (document.hidden) reset();
};
function subscribe(listener: () => void) {
  if (!listeners.size) {
    window.addEventListener("keydown", down, true);
    window.addEventListener("keyup", up, true);
    window.addEventListener("blur", reset);
    document.addEventListener("visibilitychange", visibility);
  }
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
    if (!listeners.size) {
      window.removeEventListener("keydown", down, true);
      window.removeEventListener("keyup", up, true);
      window.removeEventListener("blur", reset);
      document.removeEventListener("visibilitychange", visibility);
      held = false;
    }
  };
}
export const useRelicFormulas = () =>
  useSyncExternalStore(
    subscribe,
    () => held,
    () => false,
  );
