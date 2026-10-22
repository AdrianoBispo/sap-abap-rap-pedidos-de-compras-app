/*
 * Tiles do tipo URL no SAP Build Work Zone acrescentam o intent do launchpad
 * ("#<SemanticObject>-<action>?sap-ui-app-id-hint=...") à URL desta página.
 * Fora de um launchpad esse hash seria lido como rota do Fiori Elements e a
 * app abriria na página de "não encontrado"; por isso ele é descartado antes
 * do bootstrap. Rotas reais da app (#Entidade(...), #?sap-iapp-state=...) não
 * têm esse formato e são preservadas.
 */
(function () {
    "use strict";
    if (/^#[A-Za-z][\w.]*-[A-Za-z]\w*(\?|$)/.test(window.location.hash)) {
        window.history.replaceState(null, "", window.location.pathname + window.location.search);
    }
}());
