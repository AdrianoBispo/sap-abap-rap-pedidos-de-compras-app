#!/usr/bin/env node
// Executa um comando do UI5 tooling / SAP Fiori tools com a configuração do sistema SAP lida do .env.
//
// Uso (nos scripts do package.json de cada app):
//   node ../../scripts/sap-env.mjs fiori run --config ./ui5-local.yaml --open "test/flp.html#app-preview"
//
// O que o script faz:
//   1. Carrega as variáveis, nesta ordem de prioridade (a primeira vence):
//      variáveis já definidas no ambiente > <app>/.env > ui5/.env
//   2. Lê o YAML informado em --config (ou ui5.yaml, se o comando não informar nenhum), troca os
//      placeholders ${VAR} e ${VAR:-padrão} pelos valores e grava o resultado em <app>/.sap-env.<arquivo>.yaml
//      (ignorado pelo Git).
//   3. Executa o comando com --config apontando para o arquivo gerado e com as variáveis no ambiente
//      (FIORI_TOOLS_USER e FIORI_TOOLS_PASSWORD, se definidas, chegam ao proxy e ao deploy).
//
// Sem dependências: só módulos nativos do Node.js (>= 18).

import { spawn } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ui5Dir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const appDir = process.cwd();
const PLACEHOLDER = /\$\{([A-Z0-9_]+)(?::-([^}]*))?\}/g;

function parseEnvFile(file) {
  const vars = {};
  if (!existsSync(file)) {
    return vars;
  }
  for (const rawLine of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }
    const match = line.match(/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (!match) {
      continue;
    }
    let value = match[2].trim();
    const quote = value[0];
    if ((quote === '"' || quote === "'") && value.endsWith(quote) && value.length >= 2) {
      value = value.slice(1, -1);
    } else {
      value = value.replace(/\s+#.*$/, '');
    }
    vars[match[1]] = value;
  }
  return vars;
}

function loadEnv() {
  const fromFiles = { ...parseEnvFile(join(ui5Dir, '.env')), ...parseEnvFile(join(appDir, '.env')) };
  return { ...fromFiles, ...process.env };
}

function render(template, env, file) {
  const missing = new Set();
  const output = template.replace(PLACEHOLDER, (_, name, fallback) => {
    const value = env[name];
    if (value !== undefined && value !== '') {
      return value;
    }
    if (fallback !== undefined) {
      return fallback;
    }
    if (value === '') {
      return '';
    }
    missing.add(name);
    return '';
  });
  if (missing.size > 0) {
    console.error(`[sap-env] Variáveis não definidas para ${file}: ${[...missing].join(', ')}`);
    console.error('[sap-env] Copie ui5/.env.example para ui5/.env e preencha os valores do seu sistema SAP.');
    process.exit(1);
  }
  return output;
}

function splitConfigArg(args) {
  const rest = [];
  let config;
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--config' || arg === '-c') {
      config = args[++i];
    } else if (arg.startsWith('--config=')) {
      config = arg.slice('--config='.length);
    } else {
      rest.push(arg);
    }
  }
  return { config, rest };
}

const [command, ...args] = process.argv.slice(2);
if (!command) {
  console.error('Uso: node sap-env.mjs <comando> [argumentos...]');
  process.exit(1);
}

const env = loadEnv();
const { config = 'ui5.yaml', rest } = splitConfigArg(args);
const source = resolve(appDir, config);
if (!existsSync(source)) {
  console.error(`[sap-env] Arquivo de configuração não encontrado: ${source}`);
  process.exit(1);
}
const generated = join(dirname(source), `.sap-env.${basename(source)}`);
writeFileSync(generated, render(readFileSync(source, 'utf8'), env, config));

// Caminho relativo: o `fiori deploy` junta o --config ao diretório da app mesmo quando ele é absoluto.
const child = spawn(command, [...rest, '--config', relative(appDir, generated)], {
  stdio: 'inherit',
  env,
  shell: process.platform === 'win32'
});
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => child.kill(signal));
}
child.on('exit', (code, signal) => process.exit(signal ? 1 : (code ?? 0)));
