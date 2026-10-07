import { Button } from '@ui5/webcomponents-react/Button';
import { DynamicPage } from '@ui5/webcomponents-react/DynamicPage';
import { DynamicPageHeader } from '@ui5/webcomponents-react/DynamicPageHeader';
import { DynamicPageTitle } from '@ui5/webcomponents-react/DynamicPageTitle';
import { MessageStrip } from '@ui5/webcomponents-react/MessageStrip';
import { Option } from '@ui5/webcomponents-react/Option';
import { SegmentedButton } from '@ui5/webcomponents-react/SegmentedButton';
import { SegmentedButtonItem } from '@ui5/webcomponents-react/SegmentedButtonItem';
import { Select } from '@ui5/webcomponents-react/Select';
import { Title } from '@ui5/webcomponents-react/Title';
import { useState } from 'react';
import { Navigate, useNavigate, useParams } from 'react-router-dom';
import { FilterPanel } from '../components/FilterPanel';
import { KpiTiles } from '../components/KpiTiles';
import { ScenarioCard } from '../components/ScenarioCard';
import { useAsync } from '../hooks/useAsync';
import { t } from '../i18n/texts';
import { DOMAINS, getDomain, getScenariosOf } from '../model/scenarios';
import { analyticsService } from '../service/analyticsService';
import { openManageApp } from '../service/navigation';
import { useFilters } from '../state/FiltersContext';

/** Painel de um domínio: filtros, indicadores e os gráficos dos cenários. */
export function DashboardPage() {
  const { domain: domainParam } = useParams();
  const domain = getDomain(domainParam);
  const navigate = useNavigate();
  const { filtersOf } = useFilters();
  const [refreshToken, setRefreshToken] = useState(0);

  const values = domain ? filtersOf(domain.key) : {};
  const kpis = useAsync(
    () => (domain ? analyticsService.loadKpis(domain, values) : Promise.resolve(undefined)),
    [domain?.key, JSON.stringify(values), refreshToken],
  );

  if (!domain) {
    return <Navigate to={`/painel/${DOMAINS[0].key}`} replace />;
  }

  const goTo = (key: string) => navigate(`/painel/${key}`);

  return (
    <DynamicPage
      className="page"
      titleArea={
        <DynamicPageTitle
          heading={<Title wrappingType="None">{t(`domain${domain.key}`)}</Title>}
          actionsBar={
            <>
              <Button
                className="onlyWide"
                design="Transparent"
                icon="action"
                tooltip={t('openManageTooltip', t(`domain${domain.key}`))}
                onClick={() => openManageApp(domain)}
              >
                {t('openManage')}
              </Button>
              <Button
                className="onlyNarrow"
                design="Transparent"
                icon="action"
                tooltip={t('openManageTooltip', t(`domain${domain.key}`))}
                onClick={() => openManageApp(domain)}
              />
              <Button
                design="Transparent"
                icon="refresh"
                tooltip={t('refresh')}
                onClick={() => {
                  analyticsService.resetCache();
                  setRefreshToken((token) => token + 1);
                }}
              />
            </>
          }
        >
          {/* telas largas: botões segmentados; estreitas: lista suspensa (classes em index.css) */}
          <SegmentedButton
            className="onlyWide"
            onSelectionChange={(event) => {
              const key = (event.detail.selectedItems[0] as HTMLElement | undefined)?.dataset.key;
              if (key) goTo(key);
            }}
          >
            {DOMAINS.map((item) => (
              <SegmentedButtonItem key={item.key} data-key={item.key} icon={item.icon} selected={item.key === domain.key}>
                {t(`domain${item.key}`)}
              </SegmentedButtonItem>
            ))}
          </SegmentedButton>
          <Select
            className="onlyNarrow"
            onChange={(event) => goTo(event.detail.selectedOption.value ?? domain.key)}
          >
            {DOMAINS.map((item) => (
              <Option key={item.key} value={item.key} selected={item.key === domain.key}>
                {t(`domain${item.key}`)}
              </Option>
            ))}
          </Select>
        </DynamicPageTitle>
      }
      headerArea={
        <DynamicPageHeader>
          <FilterPanel domain={domain} refreshToken={refreshToken} />
        </DynamicPageHeader>
      }
    >
      <div className="content">
        {kpis.error && (
          <MessageStrip design="Negative" hideCloseButton className="strip">
            {t('loadError', kpis.error)}
          </MessageStrip>
        )}
        <Title level="H3" className="sectionTitle">
          {t('kpiTitle')}
        </Title>
        <KpiTiles domain={domain} kpis={kpis.data} />
        <Title level="H3" className="sectionTitle">
          {t('chartsTitle')}
        </Title>
        <div className="cards">
          {getScenariosOf(domain.key).map((scenario) => (
            <ScenarioCard key={scenario.id} scenario={scenario} values={values} refreshToken={refreshToken} />
          ))}
        </div>
      </div>
    </DynamicPage>
  );
}
