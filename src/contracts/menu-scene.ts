/** CSS-pixel anchors supplied by UI layout, independent of DOM and battle state. */
export interface MenuAnchor {
  x: number;
  y: number;
  radius: number;
}
export interface MenuSceneFrame {
  color: string;
  school: number;
  anchors: readonly MenuAnchor[];
  reduced: boolean;
}
