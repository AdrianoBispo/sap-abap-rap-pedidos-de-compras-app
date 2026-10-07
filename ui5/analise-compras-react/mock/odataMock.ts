/*
 * Plugin do Vite que simula o serviço ZUI_PC_ANALITICO_O4 com os JSON de mock/data
 * (um arquivo por entity set). Ativo com `npm run dev:mock`.
 */
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Plugin } from 'vite';
import { applyTransformations, type MockRow } from './apply.ts';

const SERVICE_PATH = '/sap/opu/odata4/sap/zui_pc_analitico_o4/srvd/sap/zui_pc_analitico/0001/';
const DATA_DIR = resolve(dirname(fileURLToPath(import.meta.url)), 'data');

function loadEntitySet(name: string): MockRow[] | undefined {
  if (!/^[A-Za-z]+$/.test(name)) {
    return undefined;
  }
  try {
    return JSON.parse(readFileSync(resolve(DATA_DIR, `${name}.json`), 'utf-8')) as MockRow[];
  } catch {
    return undefined;
  }
}

export function odataMock(): Plugin {
  return {
    name: 'odata-mock-zui-pc-analitico',
    configureServer(server) {
      server.middlewares.use((request, response, next) => {
        const url = new URL(request.url ?? '', 'http://localhost');
        if (!url.pathname.startsWith(SERVICE_PATH)) {
          next();
          return;
        }
        const send = (status: number, body: unknown) => {
          response.statusCode = status;
          response.setHeader('Content-Type', 'application/json;odata.metadata=minimal');
          response.end(JSON.stringify(body));
        };
        const entitySet = url.pathname.slice(SERVICE_PATH.length);
        const rows = loadEntitySet(entitySet);
        if (!rows) {
          send(404, { error: { message: `Entity set ${entitySet} não existe no mock` } });
          return;
        }
        try {
          const apply = url.searchParams.get('$apply');
          send(200, { '@odata.context': `$metadata#${entitySet}`, value: apply ? applyTransformations(rows, apply) : rows });
        } catch (error) {
          send(400, { error: { message: error instanceof Error ? error.message : String(error) } });
        }
      });
    },
  };
}
