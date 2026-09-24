sap.ui.define(["sap/fe/core/AppComponent"], function (AppComponent) {
    "use strict";

    /**
     * Gestão de Clientes - Fiori Elements (OData V4).
     * Toda a UI (List Report e Object Pages) vem das anotações CDS do
     * serviço ZUI_PC_CLIENTES; o manifest.json só define rotas e ajustes.
     */
    return AppComponent.extend("zpc.clientes.Component", {
        metadata: {
            manifest: "json"
        }
    });
});
