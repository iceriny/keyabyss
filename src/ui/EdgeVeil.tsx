/** Above world and words, below HUD. Native backdrop filters include both canvases. */
export function EdgeVeil() {
  return (
    <div className="edge-veil" aria-hidden="true">
      <div className="edge-veil-soft" />
      <div className="edge-veil-medium" />
      <div className="edge-veil-deep" />
    </div>
  );
}
