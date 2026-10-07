import { Label } from '@ui5/webcomponents-react/Label';
import { Title } from '@ui5/webcomponents-react/Title';
import { t } from '../i18n/texts';
import type { Kpis } from '../model/analyticsQuery';
import { formatMeasure } from '../model/formatters';
import { MEASURES, type DomainDef } from '../model/scenarios';

/** Indicadores (totais) do domínio. */
export function KpiTiles({ domain, kpis }: { domain: DomainDef; kpis: Kpis | undefined }) {
  return (
    <div className="kpis">
      {domain.kpis.map((measure) => (
        <div className="kpi" key={measure}>
          <Label>{t(MEASURES[measure].labelKey)}</Label>
          <Title level="H2" size="H2">
            {kpis ? formatMeasure(kpis.values[measure], MEASURES[measure].kind, kpis.currency) : '…'}
          </Title>
        </div>
      ))}
    </div>
  );
}
