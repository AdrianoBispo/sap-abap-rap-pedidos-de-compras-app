import { Card } from '@ui5/webcomponents-react/Card';
import { CardHeader } from '@ui5/webcomponents-react/CardHeader';
import { useNavigate } from 'react-router-dom';
import { useAsync } from '../hooks/useAsync';
import { t } from '../i18n/texts';
import type { FilterValues } from '../model/analyticsQuery';
import type { ScenarioDef } from '../model/scenarios';
import { analyticsService } from '../service/analyticsService';
import { AnalysisChart } from './AnalysisChart';

interface ScenarioCardProps {
  scenario: ScenarioDef;
  values: FilterValues;
  /** muda quando o usuário aciona "Atualizar" */
  refreshToken: number;
}

/** Card de um cenário no painel: gráfico com o tipo padrão; o título abre o detalhe. */
export function ScenarioCard({ scenario, values, refreshToken }: ScenarioCardProps) {
  const navigate = useNavigate();
  const rows = useAsync(() => analyticsService.loadScenario(scenario, values), [
    scenario.id,
    JSON.stringify(values),
    refreshToken,
  ]);

  return (
    <Card
      className="scenarioCard"
      header={
        <CardHeader
          titleText={t(`${scenario.id}.title`)}
          subtitleText={t(`${scenario.id}.sub`)}
          interactive
          onClick={() => navigate(`/analise/${scenario.id}`)}
        />
      }
    >
      <div className="cardBody">
        {rows.error ? (
          <div className="chartEmpty">{t('loadError', rows.error)}</div>
        ) : (
          <AnalysisChart
            type={scenario.chart}
            measures={scenario.measures}
            rows={rows.data ?? []}
            loading={rows.loading && !rows.data}
          />
        )}
      </div>
    </Card>
  );
}
