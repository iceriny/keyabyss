/** Semantic content is independent of the generated world coordinates and account state. */
export type GraphNodeKind = 'root' | 'path' | 'rule' | 'keystone' | 'relic' | 'event' | 'junction';
export type GraphRelationKind = 'path' | 'requires' | 'evolution' | 'excludes' | 'connection' | 'event';
export interface GraphNode {
  readonly id: string;
  readonly definitionId: string;
  readonly name: string;
  readonly description: string;
  readonly region: string;
  readonly family: string;
  readonly kind: GraphNodeKind;
  readonly cost: number;
  readonly tags: readonly string[];
  readonly condition?: 'all' | 'any';
}
export interface GraphRelation {
  readonly id: string;
  readonly source: string;
  readonly target: string;
  readonly kind: GraphRelationKind;
  readonly label?: string;
}
export interface GraphRegion {
  readonly id: string;
  readonly name: string;
  readonly color: string;
}
export interface GraphDefinition {
  readonly id: string;
  readonly version: number;
  readonly nodes: readonly GraphNode[];
  readonly relations: readonly GraphRelation[];
  readonly regions: readonly GraphRegion[];
}
export interface GraphPoint { readonly x: number; readonly y: number }
export interface GraphBounds { readonly x: number; readonly y: number; readonly width: number; readonly height: number }
export interface GraphNodeLayout extends GraphPoint { readonly radius: number; readonly labelBounds: GraphBounds }
export interface GraphRegionLayout { readonly bounds: GraphBounds; readonly center: GraphPoint }
export interface GraphDiagnostic { readonly code: string; readonly ids: readonly string[]; readonly message: string }
export interface GraphLayout {
  readonly graphId: string;
  readonly graphVersion: number;
  readonly layoutVersion: number;
  readonly hash: string;
  readonly bounds: GraphBounds;
  readonly nodes: Readonly<Record<string, GraphNodeLayout>>;
  readonly regions: Readonly<Record<string, GraphRegionLayout>>;
  readonly routes: Readonly<Record<string, readonly GraphPoint[]>>;
  readonly spatialIndex: Readonly<Record<string, readonly string[]>>;
  readonly cellSize: number;
  readonly diagnostics: readonly GraphDiagnostic[];
}
export type GraphNodeState = 'active' | 'available' | 'locked' | 'excluded' | 'replaced' | 'planned';
export interface GraphProjection {
  readonly states: Readonly<Record<string, GraphNodeState>>;
  readonly reasons?: Readonly<Record<string, string>>;
  readonly highlighted?: readonly string[];
  readonly relations?: readonly GraphRelation[];
}
