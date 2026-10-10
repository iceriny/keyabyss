export interface AssetDefinition {
  readonly id: string;
  readonly kind: "image" | "audio";
  readonly src: string;
  /** Build input relative to the repository, omitted for runtime imports. */
  readonly source?: string;
}
