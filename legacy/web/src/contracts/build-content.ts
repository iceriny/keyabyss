/** Player-facing content identity. Mechanical conditions and effects remain in typed definitions. */
export interface BuildPresentation {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly drawback: string;
  readonly requirements: readonly string[];
  /** Authored semantic vocabulary aliases, consumed by the shared concept normalizer. */
  readonly concepts: readonly string[];
}
