import { Color } from "three";
const colors = new Map<string, Color>();
export function rgb(value: string): Color {
  let color = colors.get(value);
  if (!color) {
    color = new Color(value);
    colors.set(value, color);
  }
  return color;
}
