/*
 * Monta as consultas analíticas ($apply) e molda as linhas devolvidas. Sem dependência de React
 * nem de rede: a regra fica testável por unidade (mesma separação da versão SAPUI5).
 */
import {
  DIMENSIONS,
  MEASURES,
  getDomain,
  type DomainDef,
  type FilterDef,
  type ScenarioDef,
} from './scenarios';

const CURRENCY = 'Currency';

/** Linha devolvida pelo serviço. */
export type Row = Record<string, string | number | boolean | null>;

/** Valores escolhidos na barra de filtros, por campo: lista, "true"/"false"/"" ou texto. */
export type FilterValues = Record<string, string[] | string | undefined>;

export interface Condition {
  path: string;
  operator: 'EQ' | 'Contains';
  values: (string | boolean)[];
}

export interface Query {
  entitySet: string;
  group: string[];
  aggregate: string[];
  filters: Condition[];
}

/** Linha moldada para gráfico e tabela. */
export interface ShapedRow {
  key: string;
  label: string;
  currency: string;
  values: Record<string, number>;
}

export type TextFn = (key: string) => string;

function dimensionFields(dimension: string): string[] {
  const text = DIMENSIONS[dimension]?.text;
  return text ? [dimension, text] : [dimension];
}

function needsCurrency(measures: string[]): boolean {
  return measures.some((measure) => MEASURES[measure]?.currency);
}

/**
 * Converte os valores da barra de filtros em condições. Dentro de um campo as condições são OR;
 * entre campos, AND. Campo vazio não filtra; campos de outro domínio são ignorados.
 */
export function buildFilters(values: FilterValues | undefined, defs: FilterDef[]): Condition[] {
  const conditions: Condition[] = [];
  if (!values) {
    return conditions;
  }
  defs.forEach((def) => {
    const value = values[def.field];
    if (def.type === 'list' && Array.isArray(value) && value.length) {
      conditions.push({ path: def.field, operator: 'EQ', values: [...value] });
    } else if (def.type === 'boolean' && (value === 'true' || value === 'false')) {
      conditions.push({ path: def.field, operator: 'EQ', values: [value === 'true'] });
    } else if (def.type === 'search' && typeof value === 'string' && value.trim()) {
      conditions.push({ path: def.field, operator: 'Contains', values: [value.trim()] });
    }
  });
  return conditions;
}

/** Consulta de um cenário: groupby(dimensão[, texto][, Currency]) + aggregate(medidas). */
export function buildScenarioQuery(scenario: ScenarioDef, values?: FilterValues): Query {
  const domain = getDomain(scenario.domain) as DomainDef;
  const group = dimensionFields(scenario.dimension);
  if (needsCurrency(scenario.measures)) {
    group.push(CURRENCY);
  }
  return {
    entitySet: domain.entitySet,
    group,
    aggregate: [...scenario.measures],
    filters: buildFilters(values, domain.filters),
  };
}

/** Totais do domínio (KPIs): aggregate sem dimensão; por moeda quando há medida monetária. */
export function buildKpiQuery(domain: DomainDef, values?: FilterValues): Query {
  return {
    entitySet: domain.entitySet,
    group: needsCurrency(domain.kpis) ? [CURRENCY] : [],
    aggregate: [...domain.kpis],
    filters: buildFilters(values, domain.filters),
  };
}

/** Valores distintos de um campo de filtro (para as listas de seleção). */
export function buildFilterValuesQuery(domain: DomainDef, def: FilterDef): Query {
  return { entitySet: domain.entitySet, group: dimensionFields(def.field), aggregate: [], filters: [] };
}

function literal(value: string | boolean): string {
  return typeof value === 'boolean' ? String(value) : `'${value.replace(/'/g, "''")}'`;
}

function conditionToFilter(condition: Condition): string {
  if (condition.operator === 'Contains') {
    return `contains(${condition.path},${literal(condition.values[0])})`;
  }
  const terms = condition.values.map((value) => `${condition.path} eq ${literal(value)}`);
  return terms.length === 1 ? terms[0] : `(${terms.join(' or ')})`;
}

/** Valor da opção $apply: filter(...)/groupby((...),aggregate(...)). */
export function buildApply(query: Query): string {
  const steps: string[] = [];
  if (query.filters.length) {
    steps.push(`filter(${query.filters.map(conditionToFilter).join(' and ')})`);
  }
  const aggregate = query.aggregate.length ? `aggregate(${query.aggregate.join(',')})` : '';
  if (query.group.length) {
    steps.push(`groupby((${query.group.join(',')})${aggregate ? ',' + aggregate : ''})`);
  } else if (aggregate) {
    steps.push(aggregate);
  }
  return steps.join('/');
}

/** AAAAMM -> MM/AAAA */
export function formatMonth(value: string): string {
  return /^\d{6}$/.test(value) ? `${value.substring(4)}/${value.substring(0, 4)}` : value;
}

/** Texto exibido de um valor de dimensão. */
export function dimensionText(dimension: string, row: Row, text?: TextFn): string {
  const def = DIMENSIONS[dimension] ?? { labelKey: '' };
  const value = row[dimension];
  if (def.text && row[def.text]) {
    return String(row[def.text]);
  }
  if (def.kind === 'month') {
    return formatMonth(String(value));
  }
  if (def.kind === 'faixa' && text) {
    return text('faixa' + value);
  }
  if (def.kind === 'boolean' && text) {
    return text(value ? 'yes' : 'no');
  }
  return value === null || value === undefined || value === '' ? '-' : String(value);
}

function compare(a: string, b: string): number {
  if (a === b) {
    return 0;
  }
  return a < b ? -1 : 1;
}

/** Une linhas da mesma chave (moedas diferentes): soma, ou média para medidas "avg". */
function mergeRows(rows: Row[], dimension: string, measures: string[], text?: TextFn): ShapedRow[] {
  const byKey = new Map<string, ShapedRow & { count: number }>();
  rows.forEach((row) => {
    const key = String(row[dimension]);
    let entry = byKey.get(key);
    if (!entry) {
      entry = {
        key,
        label: dimensionText(dimension, row, text),
        currency: String(row[CURRENCY] ?? ''),
        values: Object.fromEntries(measures.map((measure) => [measure, 0])),
        count: 0,
      };
      byKey.set(key, entry);
    }
    entry.count += 1;
    measures.forEach((measure) => {
      entry.values[measure] += Number(row[measure]) || 0;
    });
  });
  return [...byKey.values()].map(({ count, ...entry }) => {
    measures.forEach((measure) => {
      if (MEASURES[measure]?.avg && count > 1) {
        entry.values[measure] /= count;
      }
    });
    return entry;
  });
}

/** Linhas de um cenário prontas para gráfico/tabela: junta, ordena e limita (top). */
export function shapeRows(scenario: ScenarioDef, raw: Row[] | undefined, text?: TextFn): ShapedRow[] {
  const rows = mergeRows(raw ?? [], scenario.dimension, scenario.measures, text);
  const { by, desc, measure } = scenario.sort;
  const sortMeasure = measure ?? scenario.measures[0];
  const direction = desc ? -1 : 1;
  rows.sort((a, b) =>
    by === 'measure' ? (a.values[sortMeasure] - b.values[sortMeasure]) * direction : compare(a.key, b.key) * direction,
  );
  return scenario.top ? rows.slice(0, scenario.top) : rows;
}

export interface Kpis {
  values: Record<string, number>;
  currency: string;
}

/** Totais do domínio: soma entre moedas (média para medidas "avg"). */
export function shapeKpis(domain: DomainDef, raw: Row[] | undefined): Kpis {
  const rows = raw ?? [];
  const values: Record<string, number> = {};
  domain.kpis.forEach((measure) => {
    const sum = rows.reduce((acc, row) => acc + (Number(row[measure]) || 0), 0);
    values[measure] = MEASURES[measure]?.avg && rows.length > 1 ? sum / rows.length : sum;
  });
  return { values, currency: String(rows[0]?.[CURRENCY] ?? '') };
}

export interface FilterOption {
  key: string;
  text: string;
}

/** Opções do filtro "list": meses em ordem cronológica, demais pelo texto. */
export function shapeFilterValues(def: FilterDef, raw: Row[] | undefined, text?: TextFn): FilterOption[] {
  const isMonth = DIMENSIONS[def.field]?.kind === 'month';
  return (raw ?? [])
    .map((row) => ({ key: String(row[def.field]), text: dimensionText(def.field, row, text) }))
    .sort((a, b) => (isMonth ? compare(a.key, b.key) : compare(a.text, b.text)));
}
