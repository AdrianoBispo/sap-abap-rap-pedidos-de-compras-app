sap.ui.define([
	"lojaecommerce/model/types/CpfType"
], (CpfType) => {
	"use strict";

	QUnit.module("CpfType");

	QUnit.test("aceita CPF válido, com ou sem pontuação", (assert) => {
		assert.ok(CpfType.isValidCpf("52998224725"));
		assert.ok(CpfType.isValidCpf("11144477735"));
		assert.notOk(CpfType.isValidCpf("52998224724"), "dígito verificador errado");
	});

	QUnit.test("recusa tamanho errado e dígitos repetidos", (assert) => {
		assert.notOk(CpfType.isValidCpf("123"));
		assert.notOk(CpfType.isValidCpf("11111111111"));
		assert.notOk(CpfType.isValidCpf("abcdefghijk"));
	});

	QUnit.test("o tipo lança exceção de validação para CPF inválido", (assert) => {
		const oType = new CpfType();

		oType.validateValue("529.982.247-25");
		assert.throws(() => oType.validateValue("111.111.111-11"));
	});
});
