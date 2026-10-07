/*
 * Interpretador mínimo de $apply para o mock: filter(...) / groupby((...)[,aggregate(...)]) /
 * aggregate(...). Cobre só o que o app gera (eq, contains, and, or, parênteses). As medidas
 * seguem a agregação do backend: soma, exceto as médias (ValorMedio, ScoreMedio).
 */
export type MockRow = Record<string, string | number | boolean | null>;

const AVG_MEASURES = new Set(['ValorMedio', 'ScoreMedio']);

/** Divide `text` em `separator`, ignorando o que está entre parênteses ou aspas. */
function splitTop(text: string, separator: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let quoted = false;
  let start = 0;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === "'") {
      quoted = !quoted;
    } else if (!quoted) {
      if (char === '(') depth++;
      else if (char === ')') depth--;
      else if (char === separator && depth === 0) {
        parts.push(text.slice(start, i));
        start = i + 1;
      }
    }
  }
  parts.push(text.slice(start));
  return parts.map((part) => part.trim()).filter(Boolean);
}

function parseLiteral(token: string): string | number | boolean {
  if (token === 'true') return true;
  if (token === 'false') return false;
  if (token.startsWith("'")) return token.slice(1, -1).replace(/''/g, "'");
  return Number(token);
}

type Predicate = (row: MockRow) => boolean;

/** Expressão de $filter: or > and > (eq | contains | parênteses). */
export function parseFilter(expression: string): Predicate {
  const orParts = splitTopWord(expression, 'or');
  if (orParts.length > 1) {
    const predicates = orParts.map(parseFilter);
    return (row) => predicates.some((predicate) => predicate(row));
  }
  const andParts = splitTopWord(expression, 'and');
  if (andParts.length > 1) {
    const predicates = andParts.map(parseFilter);
    return (row) => predicates.every((predicate) => predicate(row));
  }
  const text = expression.trim();
  if (text.startsWith('(') && text.endsWith(')')) {
    return parseFilter(text.slice(1, -1));
  }
  const contains = /^contains\((\w+),\s*('(?:[^']|'')*')\)$/.exec(text);
  if (contains) {
    const needle = String(parseLiteral(contains[2])).toLowerCase();
    return (row) => String(row[contains[1]] ?? '').toLowerCase().includes(needle);
  }
  const equals = /^(\w+) eq (.+)$/.exec(text);
  if (equals) {
    const expected = parseLiteral(equals[2].trim());
    return (row) => row[equals[1]] === expected;
  }
  throw new Error(`Filtro não suportado pelo mock: ${expression}`);
}

/** Divide por uma palavra (and/or) fora de parênteses e aspas. */
function splitTopWord(text: string, word: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let quoted = false;
  let start = 0;
  const token = ` ${word} `;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === "'") {
      quoted = !quoted;
    } else if (!quoted) {
      if (char === '(') depth++;
      else if (char === ')') depth--;
      else if (depth === 0 && text.startsWith(token, i)) {
        parts.push(text.slice(start, i));
        start = i + token.length;
        i = start - 1;
      }
    }
  }
  parts.push(text.slice(start));
  return parts.map((part) => part.trim());
}

function inner(step: string, name: string): string {
  return step.slice(name.length + 1, -1);
}

function aggregateRows(rows: MockRow[], measures: string[]): MockRow {
  const result: MockRow = {};
  measures.forEach((measure) => {
    const sum = rows.reduce((acc, row) => acc + (Number(row[measure]) || 0), 0);
    result[measure] = AVG_MEASURES.has(measure) && rows.length ? sum / rows.length : sum;
  });
  return result;
}

/** Aplica o $apply às linhas da entidade. */
export function applyTransformations(rows: MockRow[], apply: string): MockRow[] {
  let current = rows;
  splitTop(apply, '/').forEach((step) => {
    if (step.startsWith('filter(')) {
      current = current.filter(parseFilter(inner(step, 'filter')));
    } else if (step.startsWith('groupby(')) {
      // groupby((A,B),aggregate(M1,M2)): lista de campos e, opcionalmente, o aggregate(...)
      const [groupPart, aggregatePart] = splitTop(inner(step, 'groupby'), ',');
      const fields = splitTop(groupPart.replace(/^\(|\)$/g, ''), ',');
      const measures = aggregatePart ? splitTop(inner(aggregatePart, 'aggregate'), ',') : [];
      const groups = new Map<string, MockRow[]>();
      current.forEach((row) => {
        const key = JSON.stringify(fields.map((field) => row[field]));
        groups.set(key, [...(groups.get(key) ?? []), row]);
      });
      current = [...groups.values()].map((members) => ({
        ...Object.fromEntries(fields.map((field) => [field, members[0][field]])),
        ...aggregateRows(members, measures),
      }));
    } else if (step.startsWith('aggregate(')) {
      const measures = splitTop(inner(step, 'aggregate'), ',');
      current = [aggregateRows(current, measures)];
    } else {
      throw new Error(`Transformação não suportada pelo mock: ${step}`);
    }
  });
  return current;
}
