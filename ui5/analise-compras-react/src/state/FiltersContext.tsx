import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import type { FilterValues } from '../model/analyticsQuery';
import type { DomainKey } from '../model/scenarios';

type AllFilters = Partial<Record<DomainKey, FilterValues>>;

interface FiltersContextValue {
  filtersOf: (domain: DomainKey) => FilterValues;
  setFilter: (domain: DomainKey, field: string, value: string[] | string) => void;
  clearFilters: (domain: DomainKey) => void;
}

const EMPTY: FilterValues = {};
const FiltersContext = createContext<FiltersContextValue | undefined>(undefined);

/** Valores dos filtros por domínio; ficam na raiz para sobreviver à navegação painel <-> detalhe. */
export function FiltersProvider({ children }: { children: ReactNode }) {
  const [all, setAll] = useState<AllFilters>({});

  const filtersOf = useCallback((domain: DomainKey) => all[domain] ?? EMPTY, [all]);
  const setFilter = useCallback((domain: DomainKey, field: string, value: string[] | string) => {
    setAll((previous) => ({ ...previous, [domain]: { ...previous[domain], [field]: value } }));
  }, []);
  const clearFilters = useCallback((domain: DomainKey) => {
    setAll((previous) => ({ ...previous, [domain]: {} }));
  }, []);

  const value = useMemo(() => ({ filtersOf, setFilter, clearFilters }), [filtersOf, setFilter, clearFilters]);
  return <FiltersContext.Provider value={value}>{children}</FiltersContext.Provider>;
}

export function useFilters(): FiltersContextValue {
  const context = useContext(FiltersContext);
  if (!context) {
    throw new Error('useFilters precisa estar dentro de <FiltersProvider>');
  }
  return context;
}
