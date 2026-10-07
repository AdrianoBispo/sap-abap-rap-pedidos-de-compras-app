import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { buildApply, buildKpiQuery, buildScenarioQuery } from '../src/model/analyticsQuery';
import { SCENARIOS, getDomain, type DomainDef } from '../src/model/scenarios';
import { applyTransformations, parseFilter, type MockRow } from './apply';

const load = (name: string) => JSON.parse(readFileSync(new URL(`./data/${name}.json`, import.meta.url), 'utf-8')) as MockRow[];
const pedidos = load('PedidoAnalise');

describe('mock de $apply', () => {
  it('filtros: eq, OR, AND, booleano e contains (sem diferenciar maiúsculas)', () => {
    const rows: MockRow[] = [
      { A: 'x', B: true, N: "d'Ana" },
      { A: 'y', B: false, N: 'Bia' },
    ];
    expect(rows.filter(parseFilter("A eq 'x'"))).toHaveLength(1);
    expect(rows.filter(parseFilter("(A eq 'x' or A eq 'y')"))).toHaveLength(2);
    expect(rows.filter(parseFilter("(A eq 'x' or A eq 'y') and B eq false"))).toHaveLength(1);
    expect(rows.filter(parseFilter("contains(N,'d''ana')"))).toHaveLength(1);
    expect(() => parseFilter('A gt 1')).toThrow();
  });

  it('agrupa e soma; médias não são somadas', () => {
    const porStatus = applyTransformations(pedidos, 'groupby((StatusPedido,Currency),aggregate(ValorTotal,QtdePedidos))');
    expect(porStatus.reduce((sum, row) => sum + Number(row.QtdePedidos), 0)).toBe(pedidos.length);
    const total = applyTransformations(pedidos, 'aggregate(ValorTotal,ValorMedio)')[0];
    expect(Number(total.ValorMedio)).toBeCloseTo(Number(total.ValorTotal) / pedidos.length, 5);
  });

  it('toda consulta gerada pelo app roda no mock', () => {
    SCENARIOS.forEach((scenario) => {
      const domain = getDomain(scenario.domain) as DomainDef;
      const rows = load(domain.entitySet);
      const result = applyTransformations(rows, buildApply(buildScenarioQuery(scenario)));
      expect(result.length, scenario.id).toBeGreaterThan(0);
      const kpis = applyTransformations(rows, buildApply(buildKpiQuery(domain)));
      expect(kpis.length, domain.key).toBeGreaterThan(0);
    });
  });

  it('filtro de lista reduz o resultado', () => {
    const query = buildScenarioQuery(SCENARIOS[0], { StatusPedido: ['FINALIZADO'] });
    const result = applyTransformations(pedidos, buildApply(query));
    expect(result).toHaveLength(1);
    expect(result[0].StatusPedido).toBe('FINALIZADO');
  });
});
