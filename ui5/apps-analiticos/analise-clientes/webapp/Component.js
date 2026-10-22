sap.ui.define([
    "sap/ui/core/UIComponent",
    "sap/ui/model/json/JSONModel",
    "./service/AnalyticsService"
], function (UIComponent, JSONModel, AnalyticsService) {
    "use strict";

    return UIComponent.extend("analiseclientes.Component", {
        metadata: {
            manifest: "json",
            config: { fullWidth: true },
            interfaces: ["sap.ui.core.IAsyncContentCreation"]
        },

        init: function () {
            UIComponent.prototype.init.apply(this, arguments);

            // Estado compartilhado entre o painel e o detalhe: valores dos filtros.
            this.setModel(new JSONModel({ filters: {} }), "state");

            var oBundle = this.getModel("i18n").getResourceBundle();
            this._service = new AnalyticsService(this.getModel(), function (sKey) {
                return oBundle.getText(sKey);
            });

            this.getRouter().initialize();
        },

        getService: function () {
            return this._service;
        },

        destroy: function () {
            this._service.destroy();
            UIComponent.prototype.destroy.apply(this, arguments);
        }
    });
});
