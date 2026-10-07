import { describe, expect, it } from 'vitest';
import {
  buildApply,
  buildFilters,
  buildFilterValuesQuery,
  buildKpiQuery,
  buildScenarioQuery,
  dimensionText,
  shapeFilterValues,
  shapeKpis,
  shapeRows,
} from './analyticsQuery';
import { getDomain, getScenario, type DomainDef, type ScenarioDef } from './scenarios';

const text = (key: string) => `T:${key}`;
const scenario = (id: string) => getScenario(id) as ScenarioDef;
const domain = (key: string) => getDomain(key) as DomainDef;

describe('consultas', () => {
  it('medida monetária agrupa por dimensão, texto e Currency', () => {
    const query = buildScenarioQuery(scenario('PedValorPorStatus'));
    expect(query.entitySet).toBe('PedidoAnalise');
    expect(query.group).toEqual(['StatusPedido', 'StatusPedidoTexto', 'Currency']);
    expect(query.aggregate).toEqual(['ValorTotal']);
  });

  it('quantidade não agrupa por Currency; duas medidas agregam as duas', () => {
    expect(buildScenarioQuery(scenario('PedPorMes')).group).toEqual(['MesCriacao']);
    const estoque = buildScenarioQuery(scenario('EstDisponivelPorCategoria'));
    expect(estoque.aggregate).toEqual(['QtdeReservada', 'QtdeDisponivel']);
    expect(estoque.group).toEqual(['Categoria', 'CategoriaTexto']);
  });

  it('KPIs: sem dimensão, por moeda quando há valor monetário', () => {
    expect(buildKpiQuery(domain('pedidos')).group).toEqual(['Currency']);
    expect(buildKpiQuery(domain('clientes')).group).toEqual([]);
  });

  it('valores de filtro: grupo do campo com o texto, sem medidas', () => {
    const query = buildFilterValuesQuery(domain('pedidos'), domain('pedidos').filters[0]);
    expect(query.group).toEqual(['StatusPedido', 'StatusPedidoTexto']);
    expect(query.aggregate).toEqual([]);
  });
});

describe('filtros', () => {
  it('list vira OR dentro do campo; vazio não filtra', () => {
    const defs = domain('pedidos').filters;
    expect(buildFilters({ StatusPedido: ['ABERTO', 'CANCELADO'], Uf: [] }, defs)).toEqual([
      { path: 'StatusPedido', operator: 'EQ', values: ['ABERTO', 'CANCELADO'] },
    ]);
    expect(buildFilters(undefined, defs)).toEqual([]);
  });

  it('boolean e search; campos de outro domínio são ignorados', () => {
    const defs = domain('clientes').filters;
    expect(buildFilters({ ClienteAtivo: 'false', Nome: '  ana ' }, defs)).toEqual([
      { path: 'ClienteAtivo', operator: 'EQ', values: [false] },
      { path: 'Nome', operator: 'Contains', values: ['ana'] },
    ]);
    expect(buildFilters({ ClienteAtivo: '', Nome: '   ' }, defs)).toEqual([]);
    expect(buildFilters({ Genero: ['F'] }, domain('reembolsos').filters)).toEqual([]);
  });
});

describe('$apply', () => {
  it('groupby + aggregate', () => {
    expect(buildApply(buildScenarioQuery(scenario('PedPorMes')))).toBe('groupby((MesCriacao),aggregate(QtdePedidos))');
  });

  it('filter antes do groupby, com OR, AND, booleano e contains', () => {
    const apply = buildApply(
      buildScenarioQuery(scenario('CliPorUf'), { Genero: ['F', 'M'], ClienteAtivo: 'true', Nome: "d'ana" }),
    );
    expect(apply).toBe(
      "filter((Genero eq 'F' or Genero eq 'M') and ClienteAtivo eq true and contains(Nome,'d''ana'))/groupby((Uf),aggregate(QtdeClientes))",
    );
  });

  it('KPI sem moeda vira só aggregate; opções de filtro viram só groupby', () => {
    expect(buildApply(buildKpiQuery(domain('clientes')))).toBe('aggregate(QtdeClientes,ScoreMedio)');
    expect(buildApply(buildKpiQuery(domain('pedidos')))).toBe(
      'groupby((Currency),aggregate(ValorTotal,QtdePedidos,ValorMedio))',
    );
    expect(buildApply(buildFilterValuesQuery(domain('pedidos'), domain('pedidos').filters[2]))).toBe('groupby((Uf))');
  });
});

describe('linhas', () => {
  it('texto da dimensão: descrição, mês, faixa e vazio', () => {
    expect(dimensionText('StatusPedido', { StatusPedido: 'ABERTO', StatusPedidoTexto: 'Aberto' }, text)).toBe('Aberto');
    expect(dimensionText('MesCriacao', { MesCriacao: '202610' }, text)).toBe('10/2026');
    expect(dimensionText('FaixaScore', { FaixaScore: 'ALTO' }, text)).toBe('T:faixaALTO');
    expect(dimensionText('Uf', { Uf: '' }, text)).toBe('-');
  });

  it('ordena por medida decrescente e converte decimais em string', () => {
    const rows = shapeRows(
      scenario('PedValorPorUf'),
      [
        { Uf: 'RJ', ValorTotal: '10.50', Currency: 'BRL' },
        { Uf: 'SP', ValorTotal: '99', Currency: 'BRL' },
        { Uf: 'MG', ValorTotal: 30, Currency: 'BRL' },
      ],
      text,
    );
    expect(rows.map((row) => row.key)).toEqual(['SP', 'MG', 'RJ']);
    expect(rows[2].values.ValorTotal).toBe(10.5);
    expect(rows[0].currency).toBe('BRL');
  });

  it('ordena meses cronologicamente', () => {
    const rows = shapeRows(
      scenario('PedPorMes'),
      [
        { MesCriacao: '202611', QtdePedidos: 2 },
        { MesCriacao: '202510', QtdePedidos: 9 },
        { MesCriacao: '202610', QtdePedidos: 5 },
      ],
      text,
    );
    expect(rows.map((row) => row.label)).toEqual(['10/2025', '10/2026', '11/2026']);
  });

  it('soma moedas diferentes da mesma chave e tira a média das médias', () => {
    const sum = shapeRows(scenario('PedValorPorStatus'), [
      { StatusPedido: 'ABERTO', StatusPedidoTexto: 'Aberto', ValorTotal: 10, Currency: 'BRL' },
      { StatusPedido: 'ABERTO', StatusPedidoTexto: 'Aberto', ValorTotal: 5, Currency: 'USD' },
    ]);
    expect(sum).toHaveLength(1);
    expect(sum[0].values.ValorTotal).toBe(15);
    const avg = shapeRows(scenario('PedTicketMedio'), [
      { StatusPedido: 'ABERTO', StatusPedidoTexto: 'Aberto', ValorMedio: 10, Currency: 'BRL' },
      { StatusPedido: 'ABERTO', StatusPedidoTexto: 'Aberto', ValorMedio: 20, Currency: 'USD' },
    ]);
    expect(avg[0].values.ValorMedio).toBe(15);
  });

  it('limita ao top do cenário', () => {
    const raw = Array.from({ length: 15 }, (_, i) => ({ Nome: `Item ${i + 1}`, QtdeReservada: i + 1 }));
    const rows = shapeRows(scenario('EstMaisReservados'), raw);
    expect(rows).toHaveLength(10);
    expect(rows[0].label).toBe('Item 15');
    expect(rows[9].label).toBe('Item 6');
  });

  it('estoque ordena por Disponível, não pela 1ª medida; sem dados devolve vazio', () => {
    const rows = shapeRows(scenario('EstDisponivelPorCategoria'), [
      { Categoria: 'A', CategoriaTexto: 'A', QtdeReservada: 100, QtdeDisponivel: 1 },
      { Categoria: 'B', CategoriaTexto: 'B', QtdeReservada: 1, QtdeDisponivel: 50 },
    ]);
    expect(rows.map((row) => row.key)).toEqual(['B', 'A']);
    expect(shapeRows(scenario('PedPorMes'), undefined)).toEqual([]);
  });

  it('KPIs e opções de filtro', () => {
    const kpis = shapeKpis(domain('pedidos'), [{ ValorTotal: '100', QtdePedidos: 2, ValorMedio: '50', Currency: 'BRL' }]);
    expect(kpis).toEqual({ values: { ValorTotal: 100, QtdePedidos: 2, ValorMedio: 50 }, currency: 'BRL' });
    expect(shapeKpis(domain('clientes'), []).values).toEqual({ QtdeClientes: 0, ScoreMedio: 0 });
    const months = shapeFilterValues({ field: 'MesCriacao', type: 'list' }, [{ MesCriacao: '202701' }, { MesCriacao: '202612' }]);
    expect(months.map((option) => option.key)).toEqual(['202612', '202701']);
    const status = shapeFilterValues({ field: 'StatusPedido', type: 'list' }, [
      { StatusPedido: 'B', StatusPedidoTexto: 'Zeta' },
      { StatusPedido: 'A', StatusPedidoTexto: 'Alfa' },
    ]);
    expect(status.map((option) => option.text)).toEqual(['Alfa', 'Zeta']);
  });
});
