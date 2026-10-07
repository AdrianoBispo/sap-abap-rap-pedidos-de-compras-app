import type { DomainDef } from '../model/scenarios';

/**
 * Abre o app de gestão do domínio. Fora do launchpad, a BSP irmã (mesmo servidor ABAP:
 * ../zpc_clientes/index.html etc.) em outra aba; dentro do launchpad, o shell expõe
 * `sap.ushell.Container`, que navega pelo intent semântico (ex.: ZPCCliente-manage).
 */
export function openManageApp(domain: DomainDef): void {
  const ushell = (window as unknown as { sap?: { ushell?: { Container?: UshellContainer } } }).sap?.ushell?.Container;
  if (ushell?.getServiceAsync) {
    const [semanticObject, action] = domain.manage.intent.split('-');
    void ushell
      .getServiceAsync('Navigation')
      .then((navigation) => navigation.navigate({ target: { semanticObject, action } }));
    return;
  }
  window.open(`../${domain.manage.bsp}/index.html`, '_blank', 'noopener');
}

interface UshellContainer {
  getServiceAsync?: (name: string) => Promise<{
    navigate: (args: { target: { semanticObject: string; action: string } }) => Promise<unknown>;
  }>;
}
