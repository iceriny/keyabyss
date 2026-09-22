import { APP_VERSION } from "../shared/version";

export function DevMark() {
  return (
    <div
      style={{
        position: "absolute",
        top: 5,
        left: "50%",
        zIndex: 99999,
        transform: "translateX(-50%)",
        fontSize: "12px",
        opacity: 0.4,
      }}
    >
      游戏仍在开发中玩法及UI将持续调整 v{APP_VERSION}
    </div>
  );
}
