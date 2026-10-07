import { BarChart } from '@ui5/webcomponents-react-charts/BarChart';
import { ColumnChart } from '@ui5/webcomponents-react-charts/ColumnChart';
import { DonutChart } from '@ui5/webcomponents-react-charts/DonutChart';
import { LineChart } from '@ui5/webcomponents-react-charts/LineChart';
import { t } from '../i18n/texts';
import type { ShapedRow } from '../model/analyticsQuery';
import { formatCompact, formatMeasure } from '../model/formatters';
import { MEASURES, type ChartType } from '../model/scenarios';

interface AnalysisChartProps {
  type: ChartType;
  measures: string[];
  rows: ShapedRow[];
  loading?: boolean;
  height?: string;
}

/** Gráfico de uma análise: uma dimensão, uma ou mais medidas e o tipo escolhido. */
export function AnalysisChart({ type, measures, rows, loading, height = '18rem' }: AnalysisChartProps) {
  if (!loading && rows.length === 0) {
    return (
      <div className="chartEmpty" style={{ height }}>
        {t('noData')}
      </div>
    );
  }

  const dataset = rows.map((row) => ({ label: row.label, ...row.values }));
  const style = { width: '100%', height };
  const dimension = { accessor: 'label' };
  const kindOf = (measure: string) => MEASURES[measure].kind;

  if (type === 'donut') {
    // a rosca mostra uma só medida
    const measure = measures[0];
    return (
      <DonutChart
        style={style}
        dataset={dataset}
        loading={loading}
        dimension={dimension}
        measure={{ accessor: measure, formatter: (value: number) => formatMeasure(value, kindOf(measure)) }}
      />
    );
  }

  const chartMeasures = measures.map((measure) => ({
    accessor: measure,
    label: t(MEASURES[measure].labelKey),
    formatter: (value: number) => formatCompact(value, kindOf(measure)),
  }));
  const common = {
    style,
    dataset,
    loading,
    noLegend: measures.length === 1,
    measures: chartMeasures,
    chartConfig: { yAxisWidth: 56 },
    dimensions: [dimension],
  };

  if (type === 'bar') {
    return <BarChart {...common} />;
  }
  if (type === 'line') {
    return <LineChart {...common} />;
  }
  return <ColumnChart {...common} />;
}
