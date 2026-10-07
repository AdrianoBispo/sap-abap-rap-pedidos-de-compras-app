import { Breadcrumbs } from '@ui5/webcomponents-react/Breadcrumbs';
import { BreadcrumbsItem } from '@ui5/webcomponents-react/BreadcrumbsItem';
import { Button } from '@ui5/webcomponents-react/Button';
import { Card } from '@ui5/webcomponents-react/Card';
import { CardHeader } from '@ui5/webcomponents-react/CardHeader';
import { DynamicPage } from '@ui5/webcomponents-react/DynamicPage';
import { DynamicPageHeader } from '@ui5/webcomponents-react/DynamicPageHeader';
import { DynamicPageTitle } from '@ui5/webcomponents-react/DynamicPageTitle';
import { MessageStrip } from '@ui5/webcomponents-react/MessageStrip';
import { SegmentedButton } from '@ui5/webcomponents-react/SegmentedButton';
import { SegmentedButtonItem } from '@ui5/webcomponents-react/SegmentedButtonItem';
import { Table } from '@ui5/webcomponents-react/Table';
import { TableCell } from '@ui5/webcomponents-react/TableCell';
import { TableHeaderCell } from '@ui5/webcomponents-react/TableHeaderCell';
import { TableHeaderRow } from '@ui5/webcomponents-react/TableHeaderRow';
import { TableRow } from '@ui5/webcomponents-react/TableRow';
import { Text } from '@ui5/webcomponents-react/Text';
import { Title } from '@ui5/webcomponents-react/Title';
import { useState } from 'react';
import { Navigate, useNavigate, useParams } from 'react-router-dom';
import { AnalysisChart } from '../components/AnalysisChart';
import { FilterPanel } from '../components/FilterPanel';
import { useAsync } from '../hooks/useAsync';
import { t } from '../i18n/texts';
import { formatMeasure, formatShare } from '../model/formatters';
import { DIMENSIONS, DOMAINS, MEASURES, getDomain, getScenario, type ChartType } from '../model/scenarios';
import { analyticsService } from '../service/analyticsService';
import { useFilters } from '../state/FiltersContext';

const CHART_TYPES: { type: ChartType; icon: string }[] = [
  { type: 'column', icon: 'vertical-bar-chart' },
  { type: 'bar', icon: 'horizontal-bar-chart' },
  { type: 'line', icon: 'line-chart' },
  { type: 'donut', icon: 'donut-chart' },
];

/** Detalhe de uma análise: gráfico grande com troca de tipo e tabela com valores e % do total. */
export function DetailPage() {
  const { scenario: scenarioParam } = useParams();
  const scenario = getScenario(scenarioParam);
  const navigate = useNavigate();
  const { filtersOf } = useFilters();
  const [refreshToken, setRefreshToken] = useState(0);
  const [chartType, setChartType] = useState<{ scenarioId: string; type: ChartType } | undefined>();

  const domain = getDomain(scenario?.domain);
  const values = domain ? filtersOf(domain.key) : {};
  const rows = useAsync(
    () => (scenario ? analyticsService.loadScenario(scenario, values) : Promise.resolve([])),
    [scenario?.id, JSON.stringify(values), refreshToken],
  );

  if (!scenario || !domain) {
    return <Navigate to={`/painel/${DOMAINS[0].key}`} replace />;
  }

  const type = chartType?.scenarioId === scenario.id ? chartType.type : scenario.chart;
  const single = scenario.measures.length === 1;
  const hasAvg = scenario.measures.some((measure) => MEASURES[measure].avg);
  const showShare = single && !hasAvg;
  const showTotal = !hasAvg && (rows.data?.length ?? 0) > 1;
  const data = rows.data ?? [];
  const totals = scenario.measures.map((measure) => data.reduce((sum, row) => sum + row.values[measure], 0));
  const title = t(`${scenario.id}.title`);

  return (
    <DynamicPage
      className="page"
      titleArea={
        <DynamicPageTitle
          breadcrumbs={
            <Breadcrumbs onItemClick={() => navigate(`/painel/${domain.key}`)}>
              <BreadcrumbsItem>{t(`domain${domain.key}`)}</BreadcrumbsItem>
              <BreadcrumbsItem>{title}</BreadcrumbsItem>
            </Breadcrumbs>
          }
          heading={<Title>{title}</Title>}
          subheading={<Text>{t(`${scenario.id}.sub`)}</Text>}
          actionsBar={
            <Button
              design="Transparent"
              icon="refresh"
              tooltip={t('refresh')}
              onClick={() => {
                analyticsService.resetCache();
                setRefreshToken((token) => token + 1);
              }}
            />
          }
        />
      }
      headerArea={
        <DynamicPageHeader>
          <FilterPanel domain={domain} refreshToken={refreshToken} />
        </DynamicPageHeader>
      }
    >
      <div className="content">
        {rows.error && (
          <MessageStrip design="Negative" hideCloseButton className="strip">
            {t('loadError', rows.error)}
          </MessageStrip>
        )}
        <Card
          header={
            <CardHeader
              titleText={title}
              subtitleText={t(`${scenario.id}.sub`)}
              action={
                <SegmentedButton
                  onSelectionChange={(event) => {
                    const next = (event.detail.selectedItems[0] as HTMLElement | undefined)?.dataset.type;
                    if (next) setChartType({ scenarioId: scenario.id, type: next as ChartType });
                  }}
                >
                  {CHART_TYPES.map((item) => (
                    <SegmentedButtonItem
                      key={item.type}
                      data-type={item.type}
                      icon={item.icon}
                      tooltip={t(`chartType${item.type}`)}
                      selected={item.type === type}
                      disabled={item.type === 'donut' && !single}
                    />
                  ))}
                </SegmentedButton>
              }
            />
          }
        >
          <div className="cardBody">
            <AnalysisChart
              type={type}
              measures={scenario.measures}
              rows={data}
              loading={rows.loading && !rows.data}
              height="26rem"
            />
          </div>
        </Card>

        <div className="tableHeader">
          <Title level="H3">{t('detailTable')}</Title>
          <Text>{t('rowsCount', data.length)}</Text>
        </div>
        <Table
          noDataText={t('noData')}
          loading={rows.loading}
          headerRow={
            <TableHeaderRow sticky>
              <TableHeaderCell>{t(DIMENSIONS[scenario.dimension].labelKey)}</TableHeaderCell>
              {scenario.measures.map((measure) => (
                <TableHeaderCell key={measure} horizontalAlign="End">
                  {t(MEASURES[measure].labelKey)}
                </TableHeaderCell>
              ))}
              {showShare && <TableHeaderCell horizontalAlign="End">{t('share')}</TableHeaderCell>}
            </TableHeaderRow>
          }
        >
          {data.map((row) => (
            <TableRow key={row.key} rowKey={row.key}>
              <TableCell>{row.label}</TableCell>
              {scenario.measures.map((measure) => (
                <TableCell key={measure} horizontalAlign="End">
                  {formatMeasure(row.values[measure], MEASURES[measure].kind, row.currency)}
                </TableCell>
              ))}
              {showShare && <TableCell horizontalAlign="End">{formatShare(row.values[scenario.measures[0]], totals[0])}</TableCell>}
            </TableRow>
          ))}
          {showTotal && (
            <TableRow rowKey="__total">
              <TableCell>
                <b>{t('total')}</b>
              </TableCell>
              {scenario.measures.map((measure, index) => (
                <TableCell key={measure} horizontalAlign="End">
                  <b>{formatMeasure(totals[index], MEASURES[measure].kind, data[0]?.currency)}</b>
                </TableCell>
              ))}
              {showShare && (
                <TableCell horizontalAlign="End">
                  <b>{formatShare(totals[0], totals[0])}</b>
                </TableCell>
              )}
            </TableRow>
          )}
        </Table>
      </div>
    </DynamicPage>
  );
}
