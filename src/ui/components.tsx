import { GameText } from "./GameText";
import {
  createContext,
  useContext,
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type ButtonHTMLAttributes,
  type ReactNode,
  type Ref,
} from "react";
import type { SessionView as Game } from "../contracts/session.ts";
import { CommandBuffer } from "../input";
import { MagicPattern } from "./MagicPattern";
import { navigationOrder } from "./navigation";

const CommandContext = createContext("");
export const Key = ({ children }: { children: ReactNode }) => (
  <GameText>
    <kbd>{children}</kbd>
  </GameText>
);
export function Command({
  word,
  shortcut,
}: {
  word?: string;
  shortcut?: string;
}) {
  const prefix = useContext(CommandContext),
    match = !!prefix && word?.startsWith(prefix);
  return word ? (
    <span className={`cmd-badge ${match ? "matching" : ""}`} aria-hidden="true">
      <b>{match ? prefix : ""}</b>
      {match ? word.slice(prefix.length) : word}
      {shortcut && <i>{shortcut}</i>}
    </span>
  ) : null;
}
interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  word?: string;
  shortcut?: string;
  variant?: string;
  ref?: Ref<HTMLButtonElement>;
}
export function Button({
  word,
  shortcut,
  variant = "",
  children,
  className = "",
  ...props
}: ButtonProps) {
  const prefix = useContext(CommandContext);
  return (
    <GameText>
      <button
        {...props}
        tabIndex={-1}
        data-nav-order={navigationOrder(word)}
        data-command={word}
        data-shortcut={shortcut}
        className={`button ${variant} ${className} ${prefix && word?.startsWith(prefix) ? "command-match" : ""}`}
      >
        <span className="button-content">{children}</span>
        <Command word={word} shortcut={shortcut} />
      </button>
    </GameText>
  );
}
export function ChoiceCard({
  icon,
  title,
  tag,
  description,
  selected,
  children,
  ...props
}: ButtonProps & {
  icon: ReactNode;
  title: string;
  tag?: string;
  description?: string;
  selected?: boolean;
}) {
  return (
    <GameText>
      <Button
        {...props}
        variant={`choice-card ${selected ? "selected" : ""}`}
        aria-pressed={selected}
      >
        <span className="choice-icon" aria-hidden="true">
          {icon}
        </span>
        {tag && <span className="tag">{tag}</span>}
        <strong>{title}</strong>
        {description && <p>{description}</p>}
        {children}
      </Button>
    </GameText>
  );
}
export const Stat = ({ label, value }: { label: string; value: ReactNode }) => (
  <GameText>
    <div className="stat">
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  </GameText>
);
export const Meter = ({
  value,
  label,
  className = "",
}: {
  value: number;
  label: string;
  className?: string;
}) => (
  <GameText>
    <div
      className={`meter ${className}`}
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(value * 100)}
    >
      <i style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%` }} />
    </div>
  </GameText>
);
export function Modal({
  title,
  children,
  onBack,
  wide = false,
}: {
  title: string;
  children: ReactNode;
  onBack?: () => void;
  wide?: boolean;
}) {
  return (
    <GameText>
      <div className="modal" id="modal">
        <section
          className={`modal-panel ${wide ? "wide" : ""}`}
          data-menu-root
          role="dialog"
          aria-modal="true"
          aria-labelledby="modalTitle"
          tabIndex={-1}
        >
          <div className="modal-heading">
            <MagicPattern school="spirit" className="heading-pattern" />
            <h2 id="modalTitle">{title}</h2>
            {onBack && (
              <Button
                word="back"
                className="close-button"
                onClick={onBack}
                aria-label="返回"
              >
                ×
              </Button>
            )}
          </div>
          {children}
        </section>
      </div>
    </GameText>
  );
}
export function Toggle({
  id,
  label,
  value,
  onChange,
  word,
}: {
  id?: string;
  label: string;
  value: boolean;
  onChange: (value: boolean) => void;
  word: string;
}) {
  return (
    <GameText>
      <div className="setting-row">
        <span>{label}</span>
        <Button
          id={id}
          word={word}
          role="switch"
          aria-label={label}
          aria-checked={value}
          variant={`toggle ${value ? "on" : ""}`}
          onClick={() => onChange(!value)}
        >
          {value ? "开启" : "关闭"}
        </Button>
      </div>
    </GameText>
  );
}
export function Field({
  label,
  word,
  id,
  value,
  onChange,
  multiline = false,
  type = "text",
  min,
  max,
  step,
}: {
  label: string;
  word: string;
  id: string;
  value: string | number;
  onChange: (value: string) => void;
  multiline?: boolean;
  type?: "text" | "range";
  min?: number;
  max?: number;
  step?: number;
}) {
  const before = useRef(value),
    Tag = multiline ? "textarea" : "input";
  return (
    <GameText>
      <label className="field" htmlFor={id}>
        <span>
          {label}
          <Command word={word} />
          {type === "range" && (
            <output>{Math.round(Number(value) * 100)}%</output>
          )}
        </span>
        <Tag
          min={min}
          max={max}
          step={step}
          id={id}
          type={multiline ? undefined : type}
          data-command={word}
          tabIndex={-1}
          data-nav-order={navigationOrder(word)}
          value={value}
          onFocus={(e) => {
            before.current = value;
            if (type === "text" && !multiline) e.target.select();
          }}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Escape") {
              e.preventDefault();
              e.stopPropagation();
              onChange(String(before.current));
              e.currentTarget.blur();
            } else if (e.key === "Enter" && !multiline) {
              e.preventDefault();
              e.currentTarget.blur();
            }
          }}
        />
      </label>
    </GameText>
  );
}
interface Option {
  value: string;
  label: string;
  detail?: string;
}
export function Select({
  id,
  label,
  value,
  options,
  onChange,
  word,
}: {
  id: string;
  label: string;
  value: string;
  options: Option[];
  onChange: (value: string) => void;
  word: string;
}) {
  const [open, setOpen] = useState(false),
    [index, setIndex] = useState(0),
    ref = useRef<HTMLDivElement>(null),
    trigger = useRef<HTMLButtonElement>(null),
    list = useRef<HTMLDivElement>(null),
    uid = useId();
  const current = Math.max(
    0,
    options.findIndex((o) => o.value === value),
  );
  const close = () => {
      setOpen(false);
      trigger.current?.focus();
    },
    commit = (i: number) => {
      onChange(options[i].value);
      close();
    };
  useEffect(() => {
    if (open) {
      list.current?.focus();
      list.current
        ?.querySelector(`[data-index="${index}"]`)
        ?.scrollIntoView({ block: "nearest" });
    }
  }, [open, index]);
  useEffect(() => {
    if (!open) return;
    const outside = (e: PointerEvent) => {
      if (!ref.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", outside);
    return () => document.removeEventListener("pointerdown", outside);
  }, [open]);
  return (
    <GameText>
      <div
        className="select-field"
        ref={ref}
        data-listbox-scope={open || undefined}
      >
        <span className="field-label" id={`${uid}-label`}>
          {label}
        </span>
        <Button
          ref={trigger}
          id={id}
          word={word}
          role="combobox"
          aria-labelledby={`${uid}-label`}
          aria-expanded={open}
          aria-controls={`${uid}-list`}
          aria-haspopup="listbox"
          onKeyDown={(e) => {
            if (e.key === "ArrowDown" || e.key === "ArrowUp") {
              e.preventDefault();
              e.stopPropagation();
              setIndex(current);
              setOpen(true);
            }
          }}
          onClick={() => {
            setIndex(current);
            setOpen(!open);
          }}
        >
          <span>{options[current]?.label}</span>
          <span className="chevron">⌄</span>
        </Button>
        {open && (
          <div
            ref={list}
            id={`${uid}-list`}
            className="select-options"
            role="listbox"
            aria-labelledby={`${uid}-label`}
            aria-activedescendant={`${uid}-${index}`}
            tabIndex={-1}
            onKeyDown={(e) => {
              e.stopPropagation();
              if (
                [
                  "ArrowDown",
                  "ArrowUp",
                  "Home",
                  "End",
                  "Enter",
                  " ",
                  "Escape",
                  "Tab",
                ].includes(e.key)
              )
                e.preventDefault();
              if (e.key === "ArrowDown")
                setIndex((i) => (i + 1) % options.length);
              if (e.key === "ArrowUp")
                setIndex((i) => (i - 1 + options.length) % options.length);
              if (e.key === "Home") setIndex(0);
              if (e.key === "End") setIndex(options.length - 1);
              if (e.key === "Enter" || e.key === " ") commit(index);
              if (e.key === "Escape" || e.key === "Tab") close();
            }}
          >
            {options.map((o, i) => (
              <div
                id={`${uid}-${i}`}
                key={o.value}
                role="option"
                aria-selected={value === o.value}
                data-index={i}
                className={i === index ? "active" : ""}
                onPointerMove={() => setIndex(i)}
                onClick={() => commit(i)}
              >
                <span>{o.label}</span>
                <small>{o.detail}</small>
                {value === o.value && <b>✓</b>}
              </div>
            ))}
          </div>
        )}
      </div>
    </GameText>
  );
}

const controls = (root: ParentNode | null) =>
  [...(root || document).querySelectorAll<HTMLElement>("[data-nav-order]")]
    .filter(
      (el) =>
        !el.hasAttribute("disabled") &&
        !el.closest("[hidden], [inert]") &&
        el.getClientRects().length > 0,
    )
    .sort((a, b) => Number(a.dataset.navOrder) - Number(b.dataset.navOrder));
export function KeyboardLayer({
  scope,
  playing,
  game,
  onBack,
  children,
}: {
  scope: string;
  playing: boolean;
  game: Game | null;
  onBack: () => void;
  children: ReactNode;
}) {
  const [prefix, setPrefix] = useState(""),
    [miss, setMiss] = useState(false),
    buffer = useRef(
      new CommandBuffer<{
        word: string;
        element?: HTMLElement;
        disabled: boolean;
      }>(),
    ),
    state = useRef({ scope, playing, game, onBack }),
    shift = useRef<{ valid: boolean; scope: string } | null>(null);
  state.current = { scope, playing, game, onBack };
  useEffect(() => {
    let keyboard = false;
    const clear = () =>
      document
        .querySelectorAll(".game-focus")
        .forEach((el) => el.classList.remove("game-focus"));
    const focus = () => {
      clear();
      if (keyboard && document.activeElement?.hasAttribute("data-nav-order"))
        document.activeElement.classList.add("game-focus");
    };
    const key = (e: KeyboardEvent) => {
      if (
        ["Tab", "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(
          e.key,
        )
      ) {
        keyboard = true;
        focus();
      }
    };
    const pointer = () => {
      keyboard = false;
      clear();
    };
    window.addEventListener("keydown", key, true);
    document.addEventListener("focusin", focus);
    window.addEventListener("pointerdown", pointer, true);
    return () => {
      window.removeEventListener("keydown", key, true);
      document.removeEventListener("focusin", focus);
      window.removeEventListener("pointerdown", pointer, true);
      clear();
    };
  }, []);
  useLayoutEffect(() => {
    buffer.current.clear();
    setPrefix("");
    setMiss(false);
    const root =
      document.querySelector<HTMLElement>('[role="dialog"][data-menu-root]') ||
      document.querySelector<HTMLElement>("[data-menu-root]");
    if (root && !playing)
      (
        root.querySelector<HTMLElement>("[data-default-focus]") ||
        controls(root)[0] ||
        root
      ).focus({ preventScroll: true });
  }, [scope, playing]);
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      const s = state.current,
        target = e.target as HTMLElement;
      if (e.key !== "Shift" && shift.current) shift.current.valid = false;
      if (
        e.key === "Alt" &&
        s.playing &&
        !e.ctrlKey &&
        !e.metaKey &&
        !e.isComposing
      ) {
        e.preventDefault();
        if (!e.repeat) s.game?.input("Alt");
        return;
      }
      if (
        e.isComposing ||
        e.keyCode === 229 ||
        e.ctrlKey ||
        e.metaKey ||
        e.altKey ||
        target.closest?.('[data-listbox-scope="true"]')
      )
        return;
      const root =
          document.querySelector('[role="dialog"][data-menu-root]') ||
          document.querySelector("[data-menu-root]"),
        items = controls(root);
      if (["INPUT", "TEXTAREA"].includes(target.tagName)) {
        if (e.key === "Tab") {
          e.preventDefault();
          const index = items.indexOf(target);
          items[
            (index + (e.shiftKey ? -1 : 1) + items.length) % items.length
          ]?.focus();
        }
        return;
      }
      if (s.playing) {
        if (e.key === "Escape") {
          e.preventDefault();
          if (!e.repeat) s.game?.pause();
          return;
        }
        if (e.key === "Shift") {
          if (!e.repeat) shift.current = { valid: true, scope: s.scope };
          return;
        }
        if (e.repeat) {
          e.preventDefault();
          return;
        }
        if (e.key === "Tab" && e.shiftKey) {
          e.preventDefault();
          s.game?.cycle(-1);
          return;
        }
        if (s.game?.input(e.key)) e.preventDefault();
        return;
      }
      if (
        e.repeat &&
        ![
          "Backspace",
          "ArrowDown",
          "ArrowUp",
          "ArrowLeft",
          "ArrowRight",
        ].includes(e.key)
      ) {
        e.preventDefault();
        return;
      }
      buffer.current.setCommands(
        [
          { word: "imsuperman", disabled: false },
          ...[
            ...(root || document).querySelectorAll<HTMLElement>(
              "[data-command]",
            ),
          ]
            .filter(
              (el) =>
                el.getClientRects().length && !el.closest("[hidden],[inert]"),
            )
            .map((element) => ({
              word: element.dataset.command!,
              element,
              disabled: element.hasAttribute("disabled"),
            })),
        ],
        true,
      );
      const clear = () => {
        buffer.current.clear();
        setPrefix("");
        setMiss(false);
      };
      const execute = (el: HTMLElement) => {
        clear();
        if (["INPUT", "TEXTAREA"].includes(el.tagName)) el.focus();
        else el.click();
      };
      if (e.key === "Escape") {
        e.preventDefault();
        if (buffer.current.value) clear();
        else s.onBack();
        return;
      }
      if (e.key === "Backspace") {
        e.preventDefault();
        buffer.current.backspace();
        setPrefix(buffer.current.value);
        return;
      }
      if (e.key === "Tab" || e.key.startsWith("Arrow")) {
        e.preventDefault();
        const index = items.indexOf(document.activeElement as HTMLElement),
          dir = e.shiftKey || ["ArrowLeft", "ArrowUp"].includes(e.key) ? -1 : 1;
        items[(index + dir + items.length) % items.length]?.focus();
        return;
      }
      if (["Enter", " "].includes(e.key)) {
        e.preventDefault();
        if (
          !buffer.current.value &&
          items.includes(document.activeElement as HTMLElement)
        )
          execute(document.activeElement as HTMLElement);
        return;
      }
      const shortcut =
        !buffer.current.value &&
        items.find((el) => el.dataset.shortcut === e.key);
      if (shortcut) {
        e.preventDefault();
        execute(shortcut);
        return;
      }
      const result = buffer.current.feed(e.key);
      if (result.kind === "ignored") return;
      s.game?.playUISound("type");
      e.preventDefault();
      setMiss(result.kind === "miss" || result.kind === "disabled");
      if (result.kind === "execute") {
        if (result.command.word === "imsuperman") {
          clear();
          s.game?.dispatch({ type: "god-mode" });
        } else if (result.command.element) execute(result.command.element);
      } else setPrefix(buffer.current.value);
    };
    const up = (e: KeyboardEvent) => {
      const s = state.current;
      s.game?.releaseKey(e.key);
      if (e.key === "Shift") {
        if (
          shift.current?.valid &&
          shift.current.scope === s.scope &&
          s.playing &&
          !e.ctrlKey &&
          !e.altKey &&
          !e.metaKey
        )
          s.game?.input("Shift");
        shift.current = null;
      }
    };
    const blur = () => {
      shift.current = null;
      buffer.current.clear();
      setPrefix("");
      state.current.game?.pause();
    };
    const visibility = () => {
      if (document.hidden) blur();
    };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    window.addEventListener("blur", blur);
    document.addEventListener("visibilitychange", visibility);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
      window.removeEventListener("blur", blur);
      document.removeEventListener("visibilitychange", visibility);
    };
  }, []);
  return (
    <CommandContext.Provider value={prefix}>
      {children}
      {!playing && (
        <GameText>
          <div
            id="commandDock"
            className={`command-dock ${miss ? "error" : ""}`}
          >
            <span className="command-input" data-plain-text>
              › {prefix || <span>输入词令</span>}
              <i />
            </span>
            <span>
              {prefix ? (
                "敲完即执行 · Esc 清空"
              ) : (
                <>
                  <Key>Tab</Key> 切换 <Key>Enter</Key> 确认 <Key>Esc</Key> 返回
                </>
              )}
            </span>
          </div>
        </GameText>
      )}
    </CommandContext.Provider>
  );
}
