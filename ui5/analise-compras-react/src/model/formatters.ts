import type { MeasureKind } from './scenarios';

const DEFAULT_CURRENCY = 'BRL';
const LOCALE = 'pt-BR';

/** Formata o valor de uma medida conforme o tipo (int | dec | money). */
export function formatMeasure(value: number | undefined, kind: MeasureKind, currency?: string): string {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return '-';
  }
  if (kind === 'money') {
    try {
      return new Intl.NumberFormat(LOCALE, { style: 'currency', currency: currency || DEFAULT_CURRENCY }).format(value);
    } catch {
      // código de moeda inválido (ex.: dados de teste): cai para o real
      return new Intl.NumberFormat(LOCALE, { style: 'currency', currency: DEFAULT_CURRENCY }).format(value);
    }
  }
  if (kind === 'dec') {
    return new Intl.NumberFormat(LOCALE, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value);
  }
  return new Intl.NumberFormat(LOCALE, { maximumFractionDigits: 0 }).format(value);
}

/** Rótulos curtos para os eixos e rótulos de dados dos gráficos (ex.: 158 mil). */
export function formatCompact(value: number, kind: MeasureKind): string {
  const fraction = kind === 'int' ? 0 : 1;
  return new Intl.NumberFormat(LOCALE, {
    notation: 'compact',
    maximumFractionDigits: Math.abs(value) >= 1000 ? fraction : kind === 'int' ? 0 : 2,
  }).format(value);
}

/** Participação no total, em % (0 quando o total é zero). */
export function formatShare(value: number, total: number): string {
  return new Intl.NumberFormat(LOCALE, { style: 'percent', minimumFractionDigits: 1, maximumFractionDigits: 1 }).format(
    total ? value / total : 0,
  );
}
