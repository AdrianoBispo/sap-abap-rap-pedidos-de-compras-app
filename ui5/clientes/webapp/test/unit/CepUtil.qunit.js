/* global QUnit */
sap.ui.define([
    "zpc/clientes/ext/util/CepUtil"
], function (CepUtil) {
    "use strict";

    QUnit.module("CepUtil.normalizar");

    QUnit.test("remove máscara e caracteres não numéricos", function (assert) {
        assert.strictEqual(CepUtil.normalizar("01001-000"), "01001000");
        assert.strictEqual(CepUtil.normalizar("01001 000"), "01001000");
        assert.strictEqual(CepUtil.normalizar(" 01.001-000 "), "01001000");
        assert.strictEqual(CepUtil.normalizar("ABCDEFGH"), "");
    });

    QUnit.test("limita a 8 dígitos e tolera vazios", function (assert) {
        assert.strictEqual(CepUtil.normalizar("010010001234"), "01001000");
        assert.strictEqual(CepUtil.normalizar(""), "");
        assert.strictEqual(CepUtil.normalizar(null), "");
        assert.strictEqual(CepUtil.normalizar(undefined), "");
    });

    QUnit.module("CepUtil.formatar");

    QUnit.test("aplica a máscara 99999-999 progressivamente", function (assert) {
        assert.strictEqual(CepUtil.formatar("0"), "0");
        assert.strictEqual(CepUtil.formatar("01001"), "01001");
        assert.strictEqual(CepUtil.formatar("010010"), "01001-0");
        assert.strictEqual(CepUtil.formatar("01001000"), "01001-000");
        assert.strictEqual(CepUtil.formatar("01001-000"), "01001-000");
    });

    QUnit.module("CepUtil.isCompleto");

    QUnit.test("só aceita 8 dígitos", function (assert) {
        assert.strictEqual(CepUtil.isCompleto("01001000"), true);
        assert.strictEqual(CepUtil.isCompleto("01001-000"), true);
        assert.strictEqual(CepUtil.isCompleto("01001"), false);
        assert.strictEqual(CepUtil.isCompleto("ABCDEFGH"), false);
    });

    QUnit.module("CepUtil.valorParametro");

    QUnit.test("repassa o valor da consulta sem transformar", function (assert) {
        var oResultado = { Cep: "01001000", CepGeral: true, Status: "V", Logradouro: "" };

        assert.strictEqual(CepUtil.valorParametro(oResultado, "Cep"), "01001000");
        assert.strictEqual(CepUtil.valorParametro(oResultado, "CepGeral"), true);
        assert.strictEqual(CepUtil.valorParametro(oResultado, "Logradouro"), "");
    });

    // A linha montada quando a consulta não devolve nada só tem Cep, Status
    // e Message. CepGeral é Edm.Boolean: "" seria recusado pela ação.
    QUnit.test("campo ausente vira o padrão do seu tipo", function (assert) {
        var oResultado = { Cep: "01001000", Status: "X", Message: "" };

        assert.strictEqual(CepUtil.valorParametro(oResultado, "CepGeral"), false);
        assert.strictEqual(CepUtil.valorParametro(oResultado, "Cidade"), "");
        assert.strictEqual(CepUtil.valorParametro({ Uf: null }, "Uf"), "");
    });
});
