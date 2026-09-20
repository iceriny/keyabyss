import type { EventEnvelope, EventReader } from "../contracts/events.ts";

/** Independent readers own their cursors; bounded history never controls simulation. */
export class EventJournal<T extends object> implements EventReader<T> {
  session = 0;
  sequence = 0;
  private entries: EventEnvelope<T>[] = [];
  reset() {
    this.session++;
    this.sequence = 0;
    this.entries = [];
  }
  publish(value: T) {
    const event = Object.freeze({
      session: this.session,
      sequence: ++this.sequence,
      value: Object.freeze(value),
    });
    this.entries.push(event);
    if (this.entries.length > 512) this.entries.shift();
  }
  after(sequence: number) {
    return this.entries.filter((entry) => entry.sequence > sequence);
  }
  reader(): EventReader<T> {
    const journal = this;
    return Object.freeze({
      get session() {
        return journal.session;
      },
      get sequence() {
        return journal.sequence;
      },
      after(sequence: number) {
        return journal.after(sequence);
      },
    });
  }
}
