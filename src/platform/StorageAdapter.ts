export interface KeyValueStore {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}
const versions: Readonly<Record<string, number>> = {
  settings: 1,
  prefs: 1,
  history: 1,
  custom: 1,
};

/** Old unwrapped values remain readable; unknown future schemas are not reinterpreted. */
export class StorageAdapter {
  private readonly store: () => KeyValueStore;
  constructor(store: () => KeyValueStore) {
    this.store = store;
  }
  read<T>(key: string, fallback: T): T {
    try {
      const value = JSON.parse(
        this.store().getItem(`keyabyss.${key}`) || "null",
      );
      if (value && typeof value === "object" && value.schema === "keyabyss")
        return value.version === (versions[key] ?? 1)
          ? (value.data ?? fallback)
          : fallback;
      return value ?? fallback;
    } catch {
      return fallback;
    }
  }
  save(key: string, data: unknown): boolean {
    try {
      this.store().setItem(
        `keyabyss.${key}`,
        JSON.stringify({
          schema: "keyabyss",
          version: versions[key] ?? 1,
          data,
        }),
      );
      return true;
    } catch {
      return false;
    }
  }
}
