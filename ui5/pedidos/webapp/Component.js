sap.ui.define(["sap/fe/core/AppComponent"], function (AppComponent) {
    "use strict";

    /**
     * Pedidos de Compras - Fiori Elements (OData V4).
     * Toda a UI (List Report e Object Pages) vem das anotações CDS do
     * serviço ZUI_PC_PEDIDOS_COMPRAS; o manifest.json só define rotas e ajustes.
     */
    return AppComponent.extend("zpc.pedidos.Component", {
        metadata: {
            manifest: "json"
        }
    });
});
