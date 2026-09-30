export interface MenuCommand {
  word: string;
  disabled?: boolean;
}
export type CommandResult<T> =
  | { kind: "ignored" }
  | { kind: "miss"; value: string; key: string }
  | { kind: "progress"; value: string }
  | { kind: "execute" | "disabled"; command: T };

/** Pure command parser shared by React and Node regression tests. */
export class CommandBuffer<T extends MenuCommand = MenuCommand> {
  value = "";
  commands: T[] = [];
  constructor(commands: T[] = []) {
    this.setCommands(commands);
  }
  setCommands(commands: T[], keep = false) {
    const words = new Set<string>();
    for (const command of commands) {
      if (!/^[a-z][a-z0-9-]*$/.test(command.word))
        throw Error(`Invalid UI word: ${command.word}`);
      if (words.has(command.word))
        throw Error(`Duplicate UI word: ${command.word}`);
      for (const word of words)
        if (word.startsWith(command.word) || command.word.startsWith(word))
          throw Error(`Prefix collision: ${word} / ${command.word}`);
      words.add(command.word);
    }
    this.commands = commands;
    if (
      !keep ||
      !commands.some((command) => command.word.startsWith(this.value))
    )
      this.value = "";
  }
  get matches() {
    return this.commands.filter((command) =>
      command.word.startsWith(this.value),
    );
  }
  clear() {
    this.value = "";
  }
  backspace(): CommandResult<T> {
    this.value = this.value.slice(0, -1);
    return { kind: "progress", value: this.value };
  }
  feed(key: string): CommandResult<T> {
    if (key.length !== 1 || !/[a-zA-Z0-9-]/.test(key))
      return { kind: "ignored" };
    const next = this.value + key.toLowerCase(),
      matches = this.commands.filter((command) =>
        command.word.startsWith(next),
      );
    if (!matches.length) return { kind: "miss", value: this.value, key };
    this.value = next;
    const exact = matches.find((command) => command.word === next);
    if (exact) {
      this.clear();
      return { kind: exact.disabled ? "disabled" : "execute", command: exact };
    }
    return { kind: "progress", value: this.value };
  }
}
