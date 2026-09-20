import { GameText } from "./GameText";
import { Sigil } from "./Sigil";
import { Button } from "./components";

export interface LoadingState {
  label: string;
  completed: number;
  total: number;
  error?: string;
}

export function LoadingScreen({
  state,
  onCancel,
  onRetry,
}: {
  state: LoadingState;
  onCancel: () => void;
  onRetry: () => void;
}) {
  return (
    <GameText>
      <div
        className="loading-screen"
        role="dialog"
        aria-modal="true"
        aria-labelledby="loadingTitle"
        data-menu-root
        tabIndex={-1}
      >
        <Sigil
          className="loading-sigil"
          progress={state.completed / Math.max(1, state.total)}
        />
        <h2 id="loadingTitle">
          {state.error ? "书页未能展开" : "正在展开咒典"}
        </h2>
        <p role="status" aria-live="polite">
          {state.error || state.label}
        </p>
        {!state.error && (
          <>
            <div
              className="loading-track"
              role="progressbar"
              aria-label="资源准备进度"
              aria-valuemin={0}
              aria-valuemax={state.total}
              aria-valuenow={state.completed}
            >
              <i
                style={{ width: `${(state.completed / state.total) * 100}%` }}
              />
            </div>
            <span className="loading-count">
              {state.completed} / {state.total}
            </span>
          </>
        )}
        <div className="actions">
          {state.error && (
            <Button word="retry" variant="primary" onClick={onRetry}>
              重试
            </Button>
          )}
          <Button word="back" onClick={onCancel}>
            返回
          </Button>
        </div>
      </div>
    </GameText>
  );
}
