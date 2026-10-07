import react from '@vitejs/plugin-react';
import { defineConfig, loadEnv } from 'vite';
import { odataMock } from './mock/odataMock.ts';

// Variáveis de ambiente (arquivo .env.local, não versionado):
//   BACKEND_URL    host do ABAP (padrão: o trial do projeto), alvo do proxy de /sap no `npm run dev`
//   BACKEND_COOKIE cookie de sessão copiado do navegador logado no ABAP (o login do trial é por SAP ID)
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const useMock = mode === 'mock';
  return {
    // caminhos relativos: a app roda numa BSP (/sap/bc/ui5_ui5/sap/zpc_analise_r/) sem servidor de rotas
    base: './',
    plugins: [react(), ...(useMock ? [odataMock()] : [])],
    server: {
      proxy: useMock
        ? undefined
        : {
            '/sap': {
              target: env.BACKEND_URL || 'https://6449ad14-b137-4a27-8017-6421c2c4f0b0.abap.us10.hana.ondemand.com',
              changeOrigin: true,
              secure: true,
              headers: env.BACKEND_COOKIE ? { Cookie: env.BACKEND_COOKIE } : undefined,
            },
          },
    },
    test: { environment: 'node', include: ['src/**/*.test.ts', 'mock/**/*.test.ts'] },
  };
});
