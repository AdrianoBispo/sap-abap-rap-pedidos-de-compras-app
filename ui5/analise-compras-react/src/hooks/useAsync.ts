import { useEffect, useState } from 'react';

export interface AsyncState<T> {
  data: T | undefined;
  loading: boolean;
  error: string | undefined;
}

/**
 * Executa `load` quando `deps` mudam. Mantém os dados anteriores enquanto recarrega (sem piscar)
 * e descarta respostas de consultas já substituídas por uma mais nova.
 */
export function useAsync<T>(load: () => Promise<T>, deps: readonly unknown[]): AsyncState<T> {
  const [state, setState] = useState<AsyncState<T>>({ data: undefined, loading: true, error: undefined });

  useEffect(() => {
    let current = true;
    setState((previous) => ({ ...previous, loading: true, error: undefined }));
    load().then(
      (data) => {
        if (current) {
          setState({ data, loading: false, error: undefined });
        }
      },
      (error: unknown) => {
        if (current) {
          setState({ data: undefined, loading: false, error: error instanceof Error ? error.message : String(error) });
        }
      },
    );
    return () => {
      current = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return state;
}
