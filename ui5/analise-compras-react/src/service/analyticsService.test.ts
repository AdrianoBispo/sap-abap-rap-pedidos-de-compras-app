import { describe, expect, it, vi } from 'vitest';
import { getDomain, getScenario, type DomainDef, type ScenarioDef } from '../model/scenarios';
import { buildUrl, createAnalyticsService } from './analyticsService';

const json = (body: unknown, status = 200) =>
  Promise.resolve(new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }));

describe('analyticsService', () => {
  it('monta a URL com $apply codificado', () => {
    const url = buildUrl('/base/', { entitySet: 'PedidoAnalise', group: ['Uf'], aggregate: ['ValorTotal'], filters: [] });
    expect(url).toBe('/base/PedidoAnalise?$apply=groupby((Uf)%2Caggregate(ValorTotal))'.replace('%2C', encodeURIComponent(',')));
  });

  it('lê e molda as linhas do cenário', async () => {
    const fetchFn = vi.fn(() => json({ value: [{ Uf: 'SP', ValorTotal: '10', Currency: 'BRL' }, { Uf: 'RJ', ValorTotal: '30', Currency: 'BRL' }] }));
    const service = createAnalyticsService('/b/', fetchFn as unknown as typeof fetch);
    const rows = await service.loadScenario(getScenario('PedValorPorUf') as ScenarioDef, { Uf: ['SP', 'RJ'] });
    expect(rows.map((row) => row.key)).toEqual(['RJ', 'SP']);
    const url = decodeURIComponent((fetchFn.mock.calls[0] as unknown as [string])[0]);
    expect(url).toContain("filter((Uf eq 'SP' or Uf eq 'RJ'))/groupby((Uf,Currency),aggregate(ValorTotal))");
  });

  it('propaga a mensagem de erro do serviço', async () => {
    const fetchFn = vi.fn(() => json({ error: { message: 'Sem autorização' } }, 403));
    const service = createAnalyticsService('/b/', fetchFn as unknown as typeof fetch);
    await expect(service.loadKpis(getDomain('pedidos') as DomainDef)).rejects.toThrow('Sem autorização');
  });

  it('cacheia as opções de filtro e esquece em caso de erro', async () => {
    const domain = getDomain('pedidos') as DomainDef;
    const def = domain.filters[2];
    const fetchFn = vi
      .fn()
      .mockImplementationOnce(() => json({ error: { message: 'x' } }, 500))
      .mockImplementation(() => json({ value: [{ Uf: 'SP' }] }));
    const service = createAnalyticsService('/b/', fetchFn as unknown as typeof fetch);
    await expect(service.loadFilterValues(domain, def)).rejects.toThrow();
    await service.loadFilterValues(domain, def);
    await service.loadFilterValues(domain, def);
    expect(fetchFn).toHaveBeenCalledTimes(2);
    service.resetCache();
    await service.loadFilterValues(domain, def);
    expect(fetchFn).toHaveBeenCalledTimes(3);
  });
});
