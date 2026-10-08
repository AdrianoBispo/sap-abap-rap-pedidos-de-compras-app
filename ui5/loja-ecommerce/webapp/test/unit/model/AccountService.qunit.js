sap.ui.define([
	"lojaecommerce/model/AccountService",
	"sap/ui/model/odata/v4/ODataModel"
], (AccountService, ODataModel) => {
	"use strict";

	const oCustomer = {Email: "Maria.Souza.1@Example.com", Telefone: "12920123457"};

	QUnit.module("AccountService - conferência do e-mail e do telefone");

	QUnit.test("e-mail: sem diferenciar maiúsculas nem espaços", (assert) => {
		assert.ok(AccountService.matches(oCustomer, "EMAIL", "maria.souza.1@example.com"));
		assert.ok(AccountService.matches(oCustomer, "EMAIL", "  MARIA.SOUZA.1@EXAMPLE.COM "));
		assert.ok(AccountService.matches({Email: "maria souza.1@example.com"}, "EMAIL", "mariasouza.1@example.com"),
			"o cadastro de demonstração tem espaços no e-mail");
		assert.notOk(AccountService.matches(oCustomer, "EMAIL", "outra@example.com"));
		assert.notOk(AccountService.matches(oCustomer, "EMAIL", ""));
	});

	QUnit.test("telefone: só os dígitos, com ou sem pontuação e com o código do país", (assert) => {
		assert.ok(AccountService.matches(oCustomer, "TELEFONE", "(12) 92012-3457"));
		assert.ok(AccountService.matches(oCustomer, "TELEFONE", "12920123457"));
		assert.ok(AccountService.matches(oCustomer, "TELEFONE", "+55 12 92012-3457"));
		assert.notOk(AccountService.matches(oCustomer, "TELEFONE", "(12) 92012-3458"));
		assert.notOk(AccountService.matches(oCustomer, "TELEFONE", "3457"), "número curto demais");
	});

	QUnit.test("o e-mail não vale como telefone e o telefone não vale como e-mail", (assert) => {
		assert.notOk(AccountService.matches(oCustomer, "TELEFONE", "maria.souza.1@example.com"));
		assert.notOk(AccountService.matches(oCustomer, "EMAIL", "12920123457"));
	});

	QUnit.module("AccountService - login no mock do serviço de clientes", {
		beforeEach() {
			this.oModel = new ODataModel({
				serviceUrl: "/sap/opu/odata4/sap/zui_pc_clientes_o4/srvd/sap/zui_pc_clientes/0001/",
				operationMode: "Server", autoExpandSelect: true, groupId: "$auto", updateGroupId: "$direct"
			});
		},
		afterEach() {
			this.oModel.destroy();
		}
	});

	QUnit.test("entra com CPF + e-mail e com CPF + telefone", async function(assert) {
		const oByEmail = await AccountService.login(this.oModel,
			{cpf: "529.982.247-25", method: "EMAIL", value: "Maria@exemplo.com.br"});

		assert.strictEqual(oByEmail.Nome, "Maria Silva");
		assert.strictEqual(oByEmail.Cidade, "Recife");
		assert.strictEqual(oByEmail.ClienteUUID, "c0000000-0000-0000-0000-000000000001");
		assert.notOk("Email" in oByEmail || "Telefone" in oByEmail, "e-mail e telefone não ficam na sessão");

		const oByPhone = await AccountService.login(this.oModel,
			{cpf: "52998224725", method: "TELEFONE", value: "(81) 99999-0000"});

		assert.strictEqual(oByPhone.Nome, "Maria Silva");
	});

	QUnit.test("recusa e-mail/telefone errado e CPF desconhecido (mesma resposta)", async function(assert) {
		assert.strictEqual(await AccountService.login(this.oModel,
			{cpf: "529.982.247-25", method: "EMAIL", value: "joao@exemplo.com.br"}), undefined, "e-mail de outro cliente");
		assert.strictEqual(await AccountService.login(this.oModel,
			{cpf: "529.982.247-25", method: "TELEFONE", value: "11988887777"}), undefined, "telefone de outro cliente");
		assert.strictEqual(await AccountService.login(this.oModel,
			{cpf: "390.533.447-05", method: "EMAIL", value: "maria@exemplo.com.br"}), undefined, "CPF sem cadastro");
	});
});
