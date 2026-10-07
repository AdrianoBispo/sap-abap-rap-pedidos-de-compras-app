import '@ui5/webcomponents-react/dist/Assets.js';
import './icons';
import { setLanguage } from '@ui5/webcomponents-base/dist/config/Language.js';
import { ThemeProvider } from '@ui5/webcomponents-react/ThemeProvider';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import { App } from './App';
import { FiltersProvider } from './state/FiltersContext';
import './index.css';

// Os textos da aplicação são pt-BR; alinha também os textos internos dos componentes.
void setLanguage('pt_BR');

createRoot(document.getElementById('root') as HTMLElement).render(
  <StrictMode>
    <ThemeProvider>
      {/* HashRouter: a BSP do ABAP não redireciona rotas para o index.html */}
      <HashRouter>
        <FiltersProvider>
          <App />
        </FiltersProvider>
      </HashRouter>
    </ThemeProvider>
  </StrictMode>,
);
