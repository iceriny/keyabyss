import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties, type KeyboardEvent, type PointerEvent, type ReactNode } from "react";
import type { GraphBounds, GraphDefinition, GraphNode, GraphNodeState, GraphPoint, GraphLayout, GraphProjection, GraphRelation } from "../contracts/graph.ts";
import { routeGraphRelations, visibleGraphNodes } from "../shared/graph-layout.ts";
import "./graph.css";

interface GraphViewportProps {
  definition: GraphDefinition;
  layout: GraphLayout;
  projection: GraphProjection;
  selectedId: string;
  onSelect: (id: string) => void;
  rootId?: string;
  renderIcon?: (node: GraphNode, size: number) => ReactNode;
  label?: string;
  obscuredRight?: number;
}

interface Camera { x: number; y: number; scale: number }
const margin = 80;
const stateNames: Record<GraphNodeState, string> = {
  active: "已取得", available: "可选", locked: "未解锁", excluded: "互斥", replaced: "已替换", planned: "规划中",
};
const relationNames: Record<GraphRelation["kind"], string> = {
  path: "路径", requires: "前置", evolution: "演化", excludes: "互斥", connection: "关联", event: "事件",
};

function padded(bounds: GraphBounds): GraphBounds {
  return { x: bounds.x - margin, y: bounds.y - margin, width: bounds.width + margin * 2, height: bounds.height + margin * 2 };
}
function intersects(a: GraphBounds, b: GraphBounds): boolean {
  return a.x <= b.x + b.width && a.x + a.width >= b.x && a.y <= b.y + b.height && a.y + a.height >= b.y;
}
function routeBounds(points: readonly GraphPoint[]): GraphBounds {
  const xs = points.map(point => point.x), ys = points.map(point => point.y);
  const x = Math.min(...xs), y = Math.min(...ys);
  return { x, y, width: Math.max(...xs) - x, height: Math.max(...ys) - y };
}
function relationPoints(relation: GraphRelation, layout: GraphLayout): readonly GraphPoint[] {
  const routed = layout.routes[relation.id];
  if (routed?.length) return routed;
  return [];
}
function etchedPath(points: readonly GraphPoint[]): string {
  if (!points.length) return '';
  let path = `M${points[0].x},${points[0].y}`;
  for (let i = 1; i < points.length - 1; i++) {
    const a = points[i - 1], b = points[i], c = points[i + 1];
    const before = Math.hypot(b.x - a.x, b.y - a.y), after = Math.hypot(c.x - b.x, c.y - b.y);
    const radius = Math.min(18, before / 3, after / 3);
    if (!before || !after) continue;
    path += ` L${b.x + (a.x - b.x) * radius / before},${b.y + (a.y - b.y) * radius / before} Q${b.x},${b.y} ${b.x + (c.x - b.x) * radius / after},${b.y + (c.y - b.y) * radius / after}`;
  }
  const end = points[points.length - 1];
  return `${path} L${end.x},${end.y}`;
}
function clampCamera(prior: Camera, point: GraphPoint, size: { width: number; height: number }, world: GraphBounds, minScale: number, maxScale: number): Camera {
  const scale = Math.max(minScale, Math.min(maxScale, prior.scale));
  const halfW = size.width / scale / 2, halfH = size.height / scale / 2;
  return {
    x: Math.max(world.x - halfW, Math.min(world.x + world.width + halfW, point.x)),
    y: Math.max(world.y - halfH, Math.min(world.y + world.height + halfH, point.y)),
    scale,
  };
}
function defaultIcon(node: GraphNode, size: number): ReactNode {
  const r = size * .55;
  switch (node.kind) {
    case "root": return <path d={`M 0 ${-r} L ${r} 0 L 0 ${r} L ${-r} 0 Z`} />;
    case "keystone": return <><path d={`M 0 ${-r} L ${r * .85} ${r * .48} L ${-r * .85} ${r * .48} Z`} /><circle r={r * .18} /></>;
    case "rule": return <path d={`M ${-r} ${-r * .65} H ${r} M ${-r} 0 H ${r * .6} M ${-r} ${r * .65} H ${r}`} />;
    case "relic": return <path d={`M ${-r * .8} ${-r} L ${r * .8} ${-r} L ${r * .65} ${r * .7} L 0 ${r} L ${-r * .65} ${r * .7} Z`} />;
    case "event": return <path d={`M 0 ${-r} C ${r} ${-r * .5} ${r} ${r * .5} 0 ${r} C ${-r} ${r * .5} ${-r} ${-r * .5} 0 ${-r} Z`} />;
    case "junction": return <><circle r={r * .5} /><path d={`M ${-r} 0 H ${r} M 0 ${-r} V ${r}`} /></>;
    default: return <path d={`M ${-r} 0 H ${r} M 0 ${-r} V ${r}`} />;
  }
}

export function GraphViewport({ definition, layout, projection, selectedId, onSelect, rootId, renderIcon, label = "图谱", obscuredRight = 0 }: GraphViewportProps) {
  const frameRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef<{ id: number; x: number; y: number; camera: Camera; moved: boolean } | null>(null);
  const suppressClick = useRef(false);
  const focusRef = useRef<string | null>(null);
  const [size, setSize] = useState({ width: 1, height: 1 });
  const [camera, setCamera] = useState<Camera | null>(null);
  const [focusedId, setFocusedId] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [searchOpen, setSearchOpen] = useState(false);
  const [relationMode, setRelationMode] = useState<"all" | "related">("all");
  const pendingCamera = useRef<Camera | null>(null);
  const cameraFrame = useRef(0);
  useEffect(() => () => cancelAnimationFrame(cameraFrame.current), []);
  const nodeById = useMemo(() => new Map(definition.nodes.map(node => [node.id, node])), [definition]);
  const regionById = useMemo(() => new Map(definition.regions.map(region => [region.id, region])), [definition]);
  const world = useMemo(() => padded(layout.bounds), [layout]);
  const usableWidth = Math.max(1, size.width - obscuredRight);
  const fitScale = Math.min(usableWidth / world.width, size.height / world.height);
  const minScale = fitScale * .72;
  const maxScale = Math.max(fitScale * 14, 2.4);
  const current = camera ?? { x: world.x + world.width / 2 + obscuredRight / (2 * fitScale), y: world.y + world.height / 2, scale: fitScale };
  const currentRef = useRef(current);
  currentRef.current = current;

  useEffect(() => {
    const frame = frameRef.current;
    if (!frame) return;
    const observer = new ResizeObserver(entries => {
      const rect = entries[0]?.contentRect;
      if (rect && rect.width && rect.height) setSize({ width: rect.width, height: rect.height });
    });
    observer.observe(frame);
    return () => observer.disconnect();
  }, []);
  useEffect(() => setCamera(null), [layout]);
  useEffect(() => {
    if (!focusedId) return;
    const target = [...(frameRef.current?.querySelectorAll<SVGGElement>("[data-graph-id]") ?? [])].find(element => element.dataset.graphId === focusedId);
    if (target && document.activeElement !== target) target.focus({ preventScroll: true });
  }, [focusedId, camera, size]);
  useEffect(() => {
    const point = layout.nodes[selectedId];
    if (!point) return;
    const prior = currentRef.current;
    const center = prior.x - obscuredRight / (2 * prior.scale);
    if (Math.abs(point.x - center) > usableWidth * .42 / prior.scale || Math.abs(point.y - prior.y) > size.height * .42 / prior.scale) {
      setCamera(clampCamera(prior, { x: point.x + obscuredRight / (2 * prior.scale), y: point.y }, size, world, minScale, maxScale));
    }
  }, [selectedId, layout, size, world, minScale, maxScale, obscuredRight, usableWidth]);

  const clamp = useCallback((next: Camera): Camera => {
    const scale = Math.max(minScale, Math.min(maxScale, next.scale));
    return clampCamera({ ...next, scale }, next, size, world, minScale, maxScale);
  }, [minScale, maxScale, size, world]);
  const moveCamera = useCallback((next: Camera) => {
    pendingCamera.current = clamp(next);
    currentRef.current = pendingCamera.current;
    if (!cameraFrame.current) cameraFrame.current = requestAnimationFrame(() => {
      cameraFrame.current = 0;
      setCamera(pendingCamera.current);
    });
  }, [clamp]);
  const focusNode = useCallback((id: string, close = false) => {
    const point = layout.nodes[id];
    if (!point) return;
    const prior = currentRef.current;
    const scale = close ? Math.max(prior.scale, fitScale * 3, .7) : prior.scale;
    moveCamera({ x: point.x + obscuredRight / (2 * scale), y: point.y, scale });
  }, [layout, moveCamera, fitScale, obscuredRight]);
  const selectNode = useCallback((id: string, center = false) => {
    focusRef.current = id;
    setFocusedId(id);
    onSelect(id);
    if (center) focusNode(id, true);
  }, [onSelect, focusNode]);
  const zoomAt = useCallback((factor: number, px = size.width / 2, py = size.height / 2) => {
    const old = currentRef.current;
    const scale = Math.max(minScale, Math.min(maxScale, old.scale * factor));
    const wx = old.x + (px - size.width / 2) / old.scale;
    const wy = old.y + (py - size.height / 2) / old.scale;
    moveCamera({ x: wx - (px - size.width / 2) / scale, y: wy - (py - size.height / 2) / scale, scale });
  }, [size, minScale, maxScale, moveCamera]);
  useEffect(() => {
    const frame = frameRef.current;
    if (!frame) return;
    const onWheel = (event: WheelEvent) => {
      event.preventDefault();
      const rect = frame.getBoundingClientRect();
      zoomAt(Math.exp(-event.deltaY * .0013), event.clientX - rect.left, event.clientY - rect.top);
    };
    frame.addEventListener('wheel', onWheel, { passive: false });
    return () => frame.removeEventListener('wheel', onWheel);
  }, [zoomAt]);
  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (event.button !== 0) return;
    suppressClick.current = false;
    dragRef.current = { id: event.pointerId, x: event.clientX, y: event.clientY, camera: currentRef.current, moved: false };
  };
  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const drag = dragRef.current;
    if (!drag || drag.id !== event.pointerId) return;
    const dx = event.clientX - drag.x, dy = event.clientY - drag.y;
    if (!drag.moved && Math.abs(dx) + Math.abs(dy) > 4) { drag.moved = true; event.currentTarget.setPointerCapture(event.pointerId); }
    if (drag.moved) moveCamera({ ...drag.camera, x: drag.camera.x - dx / drag.camera.scale, y: drag.camera.y - dy / drag.camera.scale });
  };
  const endPointer = (event: PointerEvent<HTMLDivElement>) => {
    if (dragRef.current?.id === event.pointerId) { suppressClick.current = dragRef.current.moved; dragRef.current = null; }
  };
  const searchResults = useMemo(() => {
    const needle = query.trim().toLocaleLowerCase();
    if (!needle) return [];
    return definition.nodes.filter(node => `${node.name} ${node.description} ${node.tags.join(" ")} ${node.family}`.toLocaleLowerCase().includes(needle)).slice(0, 12);
  }, [definition, query]);
  const related = useMemo(() => {
    const ids = new Set([selectedId]);
    for (const relation of [...definition.relations, ...(projection.relations ?? [])]) {
      if (relation.source === selectedId) ids.add(relation.target);
      if (relation.target === selectedId) ids.add(relation.source);
    }
    return ids;
  }, [definition, projection.relations, selectedId]);
  const relationGeometry = useMemo(() => {
    const relations = [...new Map([...definition.relations, ...(projection.relations ?? [])].map(relation => [relation.id, relation])).values()];
    const overlays = relations.filter(relation => !layout.routes[relation.id]);
    const routed = overlays.length ? { ...layout, routes: { ...layout.routes, ...routeGraphRelations(layout, overlays) } } : layout;
    return relations.map(relation => {
      const points = relationPoints(relation, routed);
      return { relation, points, path: etchedPath(points), bounds: points.length > 1 ? routeBounds(points) : null };
    });
  }, [definition, projection.relations, layout]);
  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.target instanceof HTMLInputElement || event.target instanceof HTMLButtonElement) return;
    if (event.key === "Enter" || event.key === " ") { event.preventDefault(); if (focusRef.current) selectNode(focusRef.current, true); return; }
    if (event.key === "+" || event.key === "=") { event.preventDefault(); zoomAt(1.28); return; }
    if (event.key === "-" || event.key === "_") { event.preventDefault(); zoomAt(1 / 1.28); return; }
    const directions: Record<string, [number, number]> = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    const direction = directions[event.key];
    if (!direction) return;
    event.preventDefault();
    const startId = focusRef.current ?? selectedId;
    const start = layout.nodes[startId];
    if (!start) return;
    let best: { id: string; score: number } | undefined;
    for (const node of definition.nodes) {
      if (node.id === startId) continue;
      const point = layout.nodes[node.id];
      if (!point) continue;
      const dx = point.x - start.x, dy = point.y - start.y;
      const forward = dx * direction[0] + dy * direction[1];
      if (forward <= 0) continue;
      const side = Math.abs(dx * direction[1] - dy * direction[0]);
      const score = forward + side * 2.4;
      if (!best || score < best.score) best = { id: node.id, score };
    }
    if (best) { focusRef.current = best.id; setFocusedId(best.id); focusNode(best.id); }
  };

  const view: GraphBounds = { x: current.x - size.width / current.scale / 2, y: current.y - size.height / current.scale / 2, width: size.width / current.scale, height: size.height / current.scale };
  const clip: GraphBounds = { x: view.x - 100 / current.scale, y: view.y - 100 / current.scale, width: view.width + 200 / current.scale, height: view.height + 200 / current.scale };
  const lod = current.scale / fitScale < 1.8 ? "overview" : current.scale / fitScale < 3.5 ? "middle" : "detail";
  const visibleIds = useMemo(() => new Set(size.width > 1 && size.height > 1 ? visibleGraphNodes(layout, clip) : []), [layout, size.width, size.height, clip.x, clip.y, clip.width, clip.height]);
  const visibleNodes = [...visibleIds].map(id => nodeById.get(id)).filter((node): node is GraphNode => !!node).filter(node => {
    const point = layout.nodes[node.id];
    if (!point || !visibleIds.has(node.id)) return false;
    return true;
  });
  const visibleRelations = relationGeometry.filter(({ relation, bounds }) => {
    if (definition.id === 'talents' && relation.kind !== 'path' && relation.source !== selectedId && relation.target !== selectedId) return false;
    if (relationMode === "related" && !related.has(relation.source) && !related.has(relation.target)) return false;
    if (lod === "overview" && !["path", "evolution", "connection"].includes(relation.kind)) return false;
    return bounds && intersects(bounds, clip);
  });
  const visibleRegions = definition.regions.filter(region => layout.regions[region.id] && intersects(layout.regions[region.id].bounds, clip));
  const zoomLabel = `${Math.round(current.scale / fitScale * 100)}%`;

  const rooted = definition.nodes.filter(node => node.kind === 'root').length > 1;
  return <div className={`graph-viewport${rooted ? ' graph-rooted' : ''}`} aria-label={label}>
    <div className="graph-toolbar">
      <div className="graph-search-wrap">
        <input className="graph-search" type="search" value={query} onChange={event => { setQuery(event.target.value); setSearchOpen(true); }} onFocus={() => setSearchOpen(true)} aria-label={`搜索${label}节点`} placeholder="搜索名称、描述或功能" />
        {searchOpen && query.trim() && <div className="graph-search-results" role="listbox" aria-label="搜索结果">
          {searchResults.length ? searchResults.map(node => <button key={node.id} type="button" role="option" aria-selected={selectedId === node.id} onClick={() => { selectNode(node.id, true); setQuery(node.name); setSearchOpen(false); frameRef.current?.focus(); }}>{node.name}<small>{regionById.get(node.region)?.name ?? node.family}</small></button>) : <span>未找到节点</span>}
        </div>}
      </div>
      <button type="button" onClick={() => setRelationMode(value => value === "all" ? "related" : "all")} aria-pressed={relationMode === "related"} title="切换关系显示">{relationMode === "all" ? "全部关系" : "所选关系"}</button>
      <button type="button" onClick={() => zoomAt(1 / 1.35)} aria-label="缩小">−</button>
      <span className="graph-zoom-value">{zoomLabel}</span>
      <button type="button" onClick={() => zoomAt(1.35)} aria-label="放大">＋</button>
      <button type="button" onClick={() => { cancelAnimationFrame(cameraFrame.current); cameraFrame.current = 0; setCamera(null); }}>全图</button>
      {rootId && <button type="button" onClick={() => focusNode(rootId, true)}>起点</button>}
      <button type="button" onClick={() => focusNode(selectedId, true)}>定位所选</button>
    </div>
    <div className="graph-frame" ref={frameRef} tabIndex={0} role="application" aria-label={`${label}，方向键移动焦点，Enter 选择，滚轮缩放，拖动平移`} onPointerDown={onPointerDown} onPointerMove={onPointerMove} onPointerUp={endPointer} onPointerCancel={endPointer} onKeyDown={onKeyDown}>
      <svg className={`graph-canvas graph-lod-${lod}`} viewBox={`${view.x} ${view.y} ${view.width} ${view.height}`} aria-label={`${label}节点与关系`}>
        <defs>
          <radialGradient id={`graph-stone-${definition.id}`} cx="32%" cy="22%" r="85%"><stop stopColor="#718698" stopOpacity=".6" /><stop offset=".42" stopColor="#1b293a" /><stop offset="1" stopColor="#070c14" /></radialGradient>
          <linearGradient id={`graph-metal-${definition.id}`} x1="0" y1="0" x2="1" y2="1"><stop stopColor="#f8e9ba" /><stop offset=".3" stopColor="#8e7b51" /><stop offset=".52" stopColor="#3e4144" /><stop offset=".8" stopColor="#bfa771" /><stop offset="1" stopColor="#eed4a0" /></linearGradient>
          <pattern id={`graph-dust-${definition.id}`} width="180" height="180" patternUnits="userSpaceOnUse"><circle cx="10" cy="18" r=".8" fill="#d9d3bb" opacity=".18" /><circle cx="82" cy="67" r=".6" fill="#d9d3bb" opacity=".1" /></pattern>
          {visibleRelations.map(({ relation, points }) => <linearGradient key={relation.id} id={`edge-${definition.id}-${relation.id}`} gradientUnits="userSpaceOnUse" x1={points[0].x} y1={points[0].y} x2={points[points.length - 1].x} y2={points[points.length - 1].y}>
            <stop stopColor={regionById.get(nodeById.get(relation.source)!.region)?.color ?? '#d9c596'} /><stop offset="1" stopColor={regionById.get(nodeById.get(relation.target)!.region)?.color ?? '#d9c596'} />
          </linearGradient>)}
        </defs>
        <rect x={view.x} y={view.y} width={view.width} height={view.height} fill={`url(#graph-dust-${definition.id})`} />
        {rooted && <g className="graph-core" aria-hidden="true"><circle r="450" /><circle r="210" /><path d="M-135 0H135M0-135V135M-95-95L95 95M-95 95L95-95" /><text y="8" textAnchor="middle">咒典</text></g>}
        <g className="graph-regions">{!rooted && visibleRegions.map(region => {
          const shape = layout.regions[region.id];
          const rx = shape.bounds.width * .48, ry = shape.bounds.height * .48;
          return <g key={region.id} style={{ "--graph-color": region.color } as CSSProperties}>
            <ellipse cx={shape.center.x} cy={shape.center.y} rx={rx} ry={ry} />
            <text x={shape.center.x} y={shape.bounds.y + Math.min(55, shape.bounds.height * .15)} textAnchor="middle" style={{ fontSize: lod === 'overview' ? Math.max(39, 13 / current.scale) : 29 }}>{region.name}</text>
          </g>;
        })}</g>
        <g className="graph-relations">{visibleRelations.map(({ relation, path }) => {
          const active = projection.states[relation.source] === "active" && projection.states[relation.target] === "active";
          const selected = relation.source === selectedId || relation.target === selectedId;
          const highlight = projection.highlighted ?? [];
          const sourceIndex = highlight.indexOf(relation.source), targetIndex = highlight.indexOf(relation.target);
          const planned = definition.id === 'talents' && relation.kind === 'path' && sourceIndex >= 0 && targetIndex >= 0 && Math.abs(sourceIndex - targetIndex) === 1;
          return <g key={relation.id} className={`graph-edge${planned ? ' is-route' : ''}`}>
            <path d={path} className="graph-edge-recess" aria-hidden="true" />
            <path d={path} style={{ '--edge-ink': `url(#edge-${definition.id}-${relation.id})` } as CSSProperties} className={`graph-relation graph-relation-${relation.kind}${active ? " is-active" : ""}${selected ? " is-related" : ""}${planned ? " is-route" : ""}`} aria-label={`${relationNames[relation.kind]}：${nodeById.get(relation.source)?.name ?? relation.source}至${nodeById.get(relation.target)?.name ?? relation.target}`} />
          </g>;
        })}</g>
        <g className="graph-nodes">{visibleNodes.map(node => {
          const point = layout.nodes[node.id];
          const state = projection.states[node.id] ?? "locked";
          const selected = node.id === selectedId;
          const focused = node.id === focusedId;
          const color = regionById.get(node.region)?.color ?? "#d8c597";
          const r = Math.max(point.radius || (node.kind === "keystone" ? 22 : 14), rooted ? (node.kind === 'root' ? 20 : node.kind === 'keystone' ? 11 : node.kind === 'rule' ? 7 : 4) / current.scale : 0);
          return <g key={node.id} data-graph-id={node.id} transform={`translate(${point.x} ${point.y})`} className={`graph-node graph-node-${node.kind} graph-state-${state}${selected ? " is-selected" : ""}${focused ? " is-focused" : ""}${related.has(node.id) ? " is-related" : ""}`} style={{ "--graph-color": color } as CSSProperties} role="button" tabIndex={0} aria-label={`${node.name}，${stateNames[state]}${node.kind === "relic" ? "" : `，${node.cost}点`}。${node.description}${projection.reasons?.[node.id] ? `。${projection.reasons[node.id]}` : ""}`} aria-pressed={selected} onClick={event => { if (!suppressClick.current && !dragRef.current?.moved) selectNode(node.id); suppressClick.current = false; event.stopPropagation(); }} onFocus={() => { focusRef.current = node.id; setFocusedId(node.id); }} onKeyDown={event => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); event.stopPropagation(); selectNode(node.id, true); } }}>
            <circle className="graph-node-halo" r={r * 1.6} />
            <circle className="graph-node-ring" r={r} style={{ fill: `url(#graph-stone-${definition.id})` }} />
            {node.kind !== 'path' && <circle className="graph-node-bezel" r={r * 1.18} style={{ stroke: `url(#graph-metal-${definition.id})` }} />}
            <path className="graph-node-glint" d={`M${-r * .86},${-r * .18} A${r * .88},${r * .88} 0 0 1 ${r * .18},${-r * .86}`} />
            {(lod !== "overview" || selected || ["root", "rule", "keystone", "junction"].includes(node.kind)) && <g className="graph-node-icon">{renderIcon?.(node, r) ?? defaultIcon(node, r)}</g>}
            {(lod !== "overview" || selected || node.kind === "root") && <text className="graph-node-name" y={r + (lod === 'overview' ? 16 / current.scale : 23)} textAnchor="middle" style={{ fontSize: lod === 'overview' ? 12 / current.scale : 19 }}>{node.name}</text>}
            {lod === "detail" && node.cost > 0 && <text className="graph-node-cost" y={r + 41} textAnchor="middle">{state === "active" ? "已取得" : `${node.kind === "relic" ? "" : `${node.cost} 点 · `}${stateNames[state]}`}</text>}
          </g>;
        })}</g>
      </svg>
      <div className="graph-frame-hint" aria-hidden="true">{rooted ? '实线可通行 · 金线为所选路线 · 虚线表示条件或互斥　｜　' : ''}拖动平移 · 滚轮缩放 · 方向键寻路</div>
    </div>
  </div>;
}
