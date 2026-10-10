/** Canvas text uses the same two preloaded families as the DOM. */
export function canvasFont(size: number, weight: number | string = 400): string {
  const family = size <= 15 ? "京華老宋体v3.0" : "汇文明朝体";
  return `${weight} ${size}px "${family}", serif`;
}
