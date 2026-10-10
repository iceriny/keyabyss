export interface Identified {
  readonly id: string;
}

function freeze<T>(value: T): T {
  if (value && typeof value === "object" && !Object.isFrozen(value)) {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

/** Registration is explicit, stable and sealed before a session begins. */
export class Registry<T extends Identified> {
  readonly #entries: ReadonlyMap<string, T>;
  readonly #values: readonly T[];
  readonly category: string;
  constructor(category: string, values: readonly T[]) {
    this.category = category;
    const entries = new Map<string, T>();
    for (const value of values) {
      if (!/^[a-z][a-z0-9-]*$/.test(value.id))
        throw new Error(`${category}: invalid id ${value.id}`);
      if (entries.has(value.id))
        throw new Error(`${category}: duplicate id ${value.id}`);
      entries.set(value.id, freeze(value));
    }
    this.#entries = entries;
    this.#values = Object.freeze([...entries.values()]);
  }
  get(id: string): T {
    const value = this.#entries.get(id);
    if (!value) throw new Error(`${this.category}: unknown id ${id}`);
    return value;
  }
  has(id: string) {
    return this.#entries.has(id);
  }
  list(): readonly T[] {
    return this.#values;
  }
  record(): Readonly<Record<string, T>> {
    return Object.freeze(Object.fromEntries(this.#entries));
  }
}
