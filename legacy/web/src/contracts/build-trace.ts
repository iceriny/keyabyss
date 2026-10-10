export interface BuildTraceEntry {
  readonly sequence: number;
  readonly room: number;
  readonly rootId: number | null;
  readonly packetId: number | null;
  readonly kind: 'cast' | 'copy' | 'store' | 'split' | 'relay' | 'hit' | 'guard' | 'release' | 'recover' | 'loss';
  readonly power: number;
  readonly heat: number;
  readonly sourceIds: readonly string[];
  readonly reason: string;
}

export interface BuildTrace {
  readonly entries: readonly BuildTraceEntry[];
  readonly omitted: number;
}
