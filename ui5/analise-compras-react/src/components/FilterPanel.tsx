import { Button } from '@ui5/webcomponents-react/Button';
import { Input } from '@ui5/webcomponents-react/Input';
import { Label } from '@ui5/webcomponents-react/Label';
import { MultiComboBox } from '@ui5/webcomponents-react/MultiComboBox';
import { MultiComboBoxItem } from '@ui5/webcomponents-react/MultiComboBoxItem';
import { Option } from '@ui5/webcomponents-react/Option';
import { Select } from '@ui5/webcomponents-react/Select';
import { useAsync } from '../hooks/useAsync';
import { t } from '../i18n/texts';
import { DIMENSIONS, type DomainDef, type FilterDef } from '../model/scenarios';
import { analyticsService } from '../service/analyticsService';
import { useFilters } from '../state/FiltersContext';

interface FieldProps {
  domain: DomainDef;
  def: FilterDef;
  /** muda quando o usuário aciona "Atualizar", para recarregar as opções */
  refreshToken: number;
}

function ListFilter({ domain, def, refreshToken }: FieldProps) {
  const { filtersOf, setFilter } = useFilters();
  const options = useAsync(() => analyticsService.loadFilterValues(domain, def), [domain.key, def.field, refreshToken]);
  const selected = filtersOf(domain.key)[def.field];
  const selectedKeys = Array.isArray(selected) ? selected : [];

  return (
    <MultiComboBox
      className="filterControl"
      placeholder={t('filterAll')}
      loading={options.loading}
      selectedValues={selectedKeys}
      valueState={options.error ? 'Negative' : 'None'}
      onSelectionChange={(event) => {
        setFilter(
          domain.key,
          def.field,
          event.detail.items.map((item) => item.value ?? ''),
        );
      }}
    >
      {(options.data ?? []).map((option) => (
        <MultiComboBoxItem key={option.key} text={option.text} value={option.key} />
      ))}
    </MultiComboBox>
  );
}

function BooleanFilter({ domain, def }: FieldProps) {
  const { filtersOf, setFilter } = useFilters();
  const current = filtersOf(domain.key)[def.field];
  const value = typeof current === 'string' ? current : '';
  return (
    <Select
      className="filterControl"
      onChange={(event) => setFilter(domain.key, def.field, event.detail.selectedOption.value ?? '')}
    >
      <Option value="" selected={value === ''}>
        {t('filterAll')}
      </Option>
      <Option value="true" selected={value === 'true'}>
        {t('yes')}
      </Option>
      <Option value="false" selected={value === 'false'}>
        {t('no')}
      </Option>
    </Select>
  );
}

function SearchFilter({ domain, def }: FieldProps) {
  const { filtersOf, setFilter } = useFilters();
  const current = filtersOf(domain.key)[def.field];
  return (
    <Input
      className="filterControl"
      placeholder={t('filterSearchPlaceholder')}
      value={typeof current === 'string' ? current : ''}
      onChange={(event) => setFilter(domain.key, def.field, event.target.value)}
    />
  );
}

/** Barra de filtros do domínio, montada a partir de DOMAINS[].filters. */
export function FilterPanel({ domain, refreshToken }: { domain: DomainDef; refreshToken: number }) {
  const { clearFilters } = useFilters();
  return (
    <div className="filterPanel">
      {domain.filters.map((def) => {
        const props = { domain, def, refreshToken };
        return (
          <div className="filterItem" key={def.field}>
            <Label>{t(DIMENSIONS[def.field].labelKey)}</Label>
            {def.type === 'list' && <ListFilter {...props} />}
            {def.type === 'boolean' && <BooleanFilter {...props} />}
            {def.type === 'search' && <SearchFilter {...props} />}
          </div>
        );
      })}
      <Button design="Transparent" onClick={() => clearFilters(domain.key)}>
        {t('clearFilters')}
      </Button>
    </div>
  );
}
