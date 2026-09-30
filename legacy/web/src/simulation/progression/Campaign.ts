import type { ChapterDefinition } from "../../contracts/content.ts";

export class Campaign {
  readonly chapters: readonly ChapterDefinition[];
  readonly totalRooms: number;
  constructor(chapters: readonly ChapterDefinition[]) {
    if (!chapters.length || chapters.some((c) => !c.rooms.length))
      throw new Error("Campaign requires non-empty chapters");
    this.chapters = chapters;
    this.totalRooms = chapters.reduce((sum, c) => sum + c.rooms.length, 0);
  }
  stageFor(id: string, loop = 0) {
    let offset = 0;
    for (const chapter of this.chapters) {
      const index = chapter.rooms.findIndex((room) => room.id === id);
      if (index >= 0) return loop * this.totalRooms + offset + index;
      offset += chapter.rooms.length;
    }
    throw new Error(`Unknown room ${id}`);
  }
  successors(stage: number) {
    const progress = this.at(stage);
    return (
      progress.room.exits?.map((exit) => ({
        route: exit.route,
        stage: this.stageFor(exit.to, progress.loop),
      })) ??
      (progress.index < this.totalRooms - 1
        ? [{ route: null, stage: stage + 1 }]
        : [])
    );
  }
  nextLoop(stage: number) {
    return (this.at(stage).loop + 1) * this.totalRooms;
  }
  at(stage: number) {
    if (!Number.isInteger(stage) || stage < 0)
      throw new Error("Invalid campaign stage");
    const index = stage % this.totalRooms,
      loop = Math.floor(stage / this.totalRooms);
    let offset = index;
    for (let chapter = 0; chapter < this.chapters.length; chapter++) {
      const definition = this.chapters[chapter];
      if (offset < definition.rooms.length)
        return {
          stage,
          index,
          loop,
          chapter,
          roomNumber: offset,
          room: definition.rooms[offset],
          definition,
          isLast: definition.rooms[offset].exits
            ? definition.rooms[offset].exits!.length === 0
            : index === this.totalRooms - 1,
        };
      offset -= definition.rooms.length;
    }
    throw new Error("Unreachable campaign position");
  }
}
