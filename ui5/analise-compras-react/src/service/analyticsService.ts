/*
 * Acesso ao serviço analítico ZUI_PC_ANALITICO_O4 (OData V4, somente leitura). Cada consulta é
 * um GET com $apply=filter()/groupby()/aggregate(); a resposta traz as linhas em `value`.
 * Na BSP implantada o app roda na mesma origem do serviço, então não há CORS nem token.
 */
import {
  buildApply,
  buildFilterValuesQuery,
  buildKpiQuery,
  buildScenarioQuery,
  shapeFilterValues,
  shapeKpis,
  shapeRows,
  type FilterOption,
  type FilterValues,
  type Kpis,
  type Query,
  type Row,
  type ShapedRow,
  type TextFn,
} from '../model/analyticsQuery';
import type { DomainDef, FilterDef, ScenarioDef } from '../model/scenarios';
import { t } from '../i18n/texts';

export const DEFAULT_BASE = '/sap/opu/odata4/sap/zui_pc_analitico_o4/srvd/sap/zui_pc_analitico/0001/';

export interface AnalyticsService {
  loadScenario(scenario: ScenarioDef, values?: FilterValues): Promise<ShapedRow[]>;
  loadKpis(domain: DomainDef, values?: FilterValues): Promise<Kpis>;
  loadFilterValues(domain: DomainDef, def: FilterDef): Promise<FilterOption[]>;
  resetCache(): void;
}

export function buildUrl(base: string, query: Query): string {
  return `${base}${query.entitySet}?$apply=${encodeURIComponent(buildApply(query))}`;
}

async function errorMessage(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as { error?: { message?: string } };
    if (body.error?.message) {
      return body.error.message;
    }
  } catch {
    // corpo que não é JSON: usa o status
  }
  return `${response.status} ${response.statusText}`.trim();
}

export function createAnalyticsService(
  base: string = import.meta.env.VITE_ODATA_BASE || DEFAULT_BASE,
  fetchFn: typeof fetch = (...args) => fetch(...args),
  text: TextFn = t,
): AnalyticsService {
  let filterValues = new Map<string, Promise<FilterOption[]>>();

  async function read(query: Query): Promise<Row[]> {
    const response = await fetchFn(buildUrl(base, query), {
      headers: { Accept: 'application/json' },
      credentials: 'same-origin',
    });
    if (!response.ok) {
      throw new Error(await errorMessage(response));
    }
    return ((await response.json()) as { value?: Row[] }).value ?? [];
  }

  return {
    async loadScenario(scenario, values) {
      return shapeRows(scenario, await read(buildScenarioQuery(scenario, values)), text);
    },
    async loadKpis(domain, values) {
      return shapeKpis(domain, await read(buildKpiQuery(domain, values)));
    },
    loadFilterValues(domain, def) {
      const key = `${domain.key}/${def.field}`;
      let cached = filterValues.get(key);
      if (!cached) {
        cached = read(buildFilterValuesQuery(domain, def))
          .then((rows) => shapeFilterValues(def, rows, text))
          .catch((error: unknown) => {
            filterValues.delete(key);
            throw error;
          });
        filterValues.set(key, cached);
      }
      return cached;
    },
    resetCache() {
      filterValues = new Map();
    },
  };
}

export const analyticsService = createAnalyticsService();
