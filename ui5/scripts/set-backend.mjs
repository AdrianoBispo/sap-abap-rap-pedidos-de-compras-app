// Troca a URL do SAP BTP ABAP Environment em todos os ui5*.yaml das três apps.
// Uso (na pasta ui5/):  npm run set-backend -- https://<id>.abap.<regiao>.hana.ondemand.com
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const url = (process.argv[2] ?? '').replace(/\/+$/, '');

if (!/^https:\/\/[\w.-]+(:\d+)?$/.test(url)) {
    console.error('Informe a URL base do sistema, por exemplo:');
    console.error('  npm run set-backend -- https://abc123.abap.us10.hana.ondemand.com');
    process.exit(1);
}

// Linhas "url:" dentro de "backend:" (ui5.yaml / ui5-launchpad.yaml) e de "target:" (ui5-deploy.yaml).
// A linha do proxy de recursos UI5 (url: https://ui5.sap.com) é preservada.
const pattern = /^(\s+url:\s*)(?!https:\/\/ui5\.sap\.com)\S+\s*$/gm;

let total = 0;
for (const app of ['clientes', 'estoque', 'pedidos']) {
    const dir = join(root, app);
    if (!existsSync(dir)) continue;
    for (const file of readdirSync(dir).filter((f) => /^ui5.*\.yaml$/.test(f))) {
        const path = join(dir, file);
        const before = readFileSync(path, 'utf-8');
        let count = 0;
        const after = before.replace(pattern, (_m, prefix) => {
            count++;
            return `${prefix}${url}`;
        });
        if (count > 0) {
            writeFileSync(path, after);
            total += count;
            console.log(`${app}/${file}: ${count} URL(s) atualizada(s)`);
        }
    }
}
console.log(total > 0 ? `Backend configurado: ${url}` : 'Nenhuma URL encontrada para trocar.');
