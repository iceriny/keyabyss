import type { SpellObject } from '../../contracts/build-runtime.ts';

/** Merge keeps one physical form; distinct timing/binding systems cannot be hidden inside it. */
export function mergeCompatible(a: SpellObject, b: SpellObject): boolean {
  return (a.kind === 'spell' && a.state === 'ready' || a.kind === 'shell' && a.state === 'stored')
    && a.kind === b.kind && a.state === b.state && a.rootReceiptId === b.rootReceiptId && a.program === b.program
    && a.shape === b.shape && a.inheritedShape === b.inheritedShape && a.targetId === b.targetId && a.targetPolicy === b.targetPolicy
    && a.position.x === b.position.x && a.position.y === b.position.y && !!a.targetWaitUsed === !!b.targetWaitUsed
    && a.exitOf === undefined && b.exitOf === undefined && !a.transport && !b.transport
    && !!a.transportReturned === !!b.transportReturned && !!a.relayed === !!b.relayed
    && !a.letter && !b.letter && !a.field && !b.field && !a.status && !b.status
    && Object.keys(a.properties).length === Object.keys(b.properties).length
    && Object.entries(a.properties).every(([key, value]) => b.properties[key as keyof SpellObject['properties']] === value);
}
