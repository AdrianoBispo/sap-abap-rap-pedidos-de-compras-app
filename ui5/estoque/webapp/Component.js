sap.ui.define(["sap/fe/core/AppComponent"], function (AppComponent) {
    "use strict";

    /**
     * Gestão de Estoque - Fiori Elements (OData V4).
     * Toda a UI (List Report e Object Pages) vem das anotações CDS do
     * serviço ZUI_PC_ESTOQUE; o manifest.json só define rotas e ajustes.
     */
    return AppComponent.extend("zpc.estoque.Component", {
        metadata: {
            manifest: "json"
        }
    });
});
