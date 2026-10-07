import { describe, expect, it } from 'vitest';
import { texts } from '../i18n/texts';
import { DIMENSIONS, DOMAINS, MEASURES, SCENARIOS, getDomain, getScenario, getScenariosOf } from './scenarios';

describe('catálogo de cenários', () => {
  it('tem 20 cenários, 5 por domínio, com ids únicos', () => {
    expect(SCENARIOS).toHaveLength(20);
    expect(DOMAINS).toHaveLength(4);
    DOMAINS.forEach((domain) => expect(getScenariosOf(domain.key)).toHaveLength(5));
    expect(new Set(SCENARIOS.map((scenario) => scenario.id)).size).toBe(20);
    expect(getScenario('PedPorMes')?.domain).toBe('pedidos');
    expect(getScenario('inexistente')).toBeUndefined();
    expect(getDomain('estoque')?.entitySet).toBe('ItemAnalise');
  });

  it('só usa dimensões e medidas conhecidas', () => {
    SCENARIOS.forEach((scenario) => {
      expect(getDomain(scenario.domain), scenario.id).toBeDefined();
      expect(DIMENSIONS[scenario.dimension], scenario.id).toBeDefined();
      scenario.measures.forEach((measure) => expect(MEASURES[measure], `${scenario.id}/${measure}`).toBeDefined());
    });
    DOMAINS.forEach((domain) => {
      domain.filters.forEach((filter) => expect(DIMENSIONS[filter.field], filter.field).toBeDefined());
      domain.kpis.forEach((measure) => expect(MEASURES[measure], measure).toBeDefined());
    });
  });

  it('todas as chaves de texto usadas existem', () => {
    const keys = [
      ...Object.values(MEASURES).map((measure) => measure.labelKey),
      ...Object.values(DIMENSIONS).map((dimension) => dimension.labelKey),
      ...DOMAINS.map((domain) => `domain${domain.key}`),
      ...SCENARIOS.flatMap((scenario) => [`${scenario.id}.title`, `${scenario.id}.sub`]),
      ...['BAIXO', 'MEDIO', 'ALTO'].map((faixa) => `faixa${faixa}`),
      ...['column', 'bar', 'line', 'donut'].map((type) => `chartType${type}`),
    ];
    keys.forEach((key) => expect(texts[key], key).toBeDefined());
  });
});
