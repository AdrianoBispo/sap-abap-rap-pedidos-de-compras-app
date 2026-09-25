/* global QUnit */
sap.ui.define([
    "zpc/clientes/ext/fragment/CepLookup"
], function (CepLookup) {
    "use strict";

    QUnit.module("CepLookup.editavel");

    QUnit.test("só o draft é editável", function (assert) {
        assert.strictEqual(CepLookup.editavel(false), true, "draft");
        assert.strictEqual(CepLookup.editavel(true), false, "instância ativa");
    });

    // Formatter e não expression binding: com "{= ${IsActiveEntity} === false }"
    // um IsActiveEntity ausente deixaria "editable" cair no padrão do
    // controle, que é true.
    QUnit.test("devolve booleano quando IsActiveEntity não chegou", function (assert) {
        assert.strictEqual(CepLookup.editavel(undefined), false);
        assert.strictEqual(CepLookup.editavel(null), false);
    });

    QUnit.module("CepLookup: superfície do handler");

    QUnit.test("expõe só os formatters e eventos que o fragmento usa", function (assert) {
        ["formatarCep", "editavel", "onCepLiveChange", "onCepChange", "onCepSubmit"]
            .forEach(function (sNome) {
                assert.strictEqual(typeof CepLookup[sNome], "function", sNome);
            });
    });
});
