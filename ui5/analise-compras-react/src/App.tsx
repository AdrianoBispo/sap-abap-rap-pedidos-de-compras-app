import { ShellBar } from '@ui5/webcomponents-react/ShellBar';
import { Navigate, Route, Routes } from 'react-router-dom';
import { t } from './i18n/texts';
import { DOMAINS } from './model/scenarios';
import { DashboardPage } from './pages/DashboardPage';
import { DetailPage } from './pages/DetailPage';

export function App() {
  return (
    <div className="appRoot">
      <ShellBar primaryTitle={t('shellTitle')} />
      <main className="appMain">
        <Routes>
          <Route path="/painel/:domain" element={<DashboardPage />} />
          <Route path="/analise/:scenario" element={<DetailPage />} />
          <Route path="*" element={<Navigate to={`/painel/${DOMAINS[0].key}`} replace />} />
        </Routes>
      </main>
    </div>
  );
}
