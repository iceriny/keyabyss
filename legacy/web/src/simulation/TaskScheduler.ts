export interface ScheduledTask {
  blocksClear?: boolean;
  at: number;
  fn: () => void;
  source: number | null;
}

/** Room-scoped tasks. New tasks never run recursively inside the current tick. */
export class TaskScheduler {
  pending: ScheduledTask[] = [];
  private generation = 0;
  schedule(
    now: number,
    delay: number,
    fn: () => void,
    source: number | null = null,
    options: { blocksClear?: boolean } = {},
  ) {
    if (this.pending.length < 120)
      this.pending.push({ at: now + delay, fn, source, ...options });
  }
  replace(tasks: ScheduledTask[]) {
    this.generation++;
    this.pending = tasks;
  }
  tick(
    now: number,
    sourceAlive: (id: number) => boolean,
    roomEnded: () => boolean,
  ) {
    const tasks = this.pending,
      generation = this.generation;
    this.pending = [];
    for (const task of tasks) {
      if (roomEnded() || generation !== this.generation) break;
      if (task.at <= now) {
        if (task.source === null || sourceAlive(task.source)) task.fn();
      } else this.pending.push(task);
    }
  }
}
