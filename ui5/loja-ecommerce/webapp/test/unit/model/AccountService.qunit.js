sap.ui.define([
	"lojaecommerce/model/AccountService",
	"lojaecommerce/model/CustomerService",
	"lojaecommerce/model/ImageService",
	"sap/ui/model/odata/v4/ODataModel"
], (AccountService, CustomerService, ImageService, ODataModel) => {
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

	QUnit.module("AccountService - dados completos e desativação da conta", {
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

	QUnit.test("carrega os dados completos e os endereços, o principal primeiro", async function(assert) {
		const oProfile = await AccountService.loadProfile(this.oModel, "c0000000-0000-0000-0000-000000000001");

		assert.strictEqual(oProfile.customer.Nome, "Maria Silva");
		assert.strictEqual(oProfile.customer.Email, "maria@exemplo.com.br");
		assert.strictEqual(oProfile.customer.Telefone, "81999990000");
		assert.strictEqual(oProfile.customer.DataNascimento, "1990-05-20");
		assert.strictEqual(oProfile.customer.GeneroTexto, "Feminino");
		assert.strictEqual(oProfile.addresses.length, 2, "os dois endereços");
		assert.ok(oProfile.addresses[0].EnderecoPrincipal, "o principal vem primeiro");
		assert.strictEqual(oProfile.addresses[0].Numero, "1235");
	});

	QUnit.test("cliente inexistente volta sem dados", async function(assert) {
		const oProfile = await AccountService.loadProfile(this.oModel, "00000000-0000-0000-0000-000000000000");

		assert.strictEqual(oProfile.customer, undefined);
		assert.deepEqual(oProfile.addresses, []);
	});

	QUnit.test("desativar a conta impede o login e mantém o cadastro", async function(assert) {
		const oNew = await CustomerService.register(this.oModel, {
			Cpf: "123.456.789-09", Nome: "Carlos Teste", Email: "carlos@exemplo.com.br", Telefone: "(11) 98888-7777",
			DataNascimento: "1980-01-15", Cep: "01001-000", Numero: "10", Complemento: ""
		});
		const oCredentials = {cpf: "12345678909", method: "EMAIL", value: "carlos@exemplo.com.br"};

		assert.ok(await AccountService.login(this.oModel, oCredentials), "antes: entra");

		await AccountService.deactivate(this.oModel, oNew.id);

		assert.strictEqual(await AccountService.login(this.oModel, oCredentials), undefined, "depois: login recusado");
		const oProfile = await AccountService.loadProfile(this.oModel, oNew.id);

		assert.strictEqual(oProfile.customer.ClienteAtivo, false, "o cadastro continua, inativo");
		assert.strictEqual(oProfile.customer.Nome, "Carlos Teste");
	});

	QUnit.test("troca a foto de perfil (rascunho, envio do stream, Prepare e Activate)", async function(assert) {
		// a 200 x 100 PNG, drawn here
		const oCanvas = new OffscreenCanvas(200, 100);
		const oContext = oCanvas.getContext("2d");
		oContext.fillStyle = "#0a6ed1";
		oContext.fillRect(0, 0, 200, 100);
		const oImage = await ImageService.toSquareJpeg(await oCanvas.convertToBlob({type: "image/png"}), 64);

		assert.strictEqual(oImage.type, "image/jpeg", "sempre JPEG");

		await AccountService.updatePhoto(this.oModel, "c0000000-0000-0000-0000-000000000002", oImage, "perfil.jpg");

		// the mock server does not keep the content of stream properties; the file name proves the draft was
		// edited, prepared and activated (the stream itself was checked against the real service)
		const oEntity = await (await fetch(this.oModel.getServiceUrl()
			+ "Cliente(ClienteUUID=c0000000-0000-0000-0000-000000000002,IsActiveEntity=true)?$select=FotoFileName")).json();

		assert.strictEqual(oEntity.FotoFileName, "perfil.jpg");
		assert.strictEqual(await AccountService.loadPhoto(this.oModel, "c0000000-0000-0000-0000-000000000001"), "",
			"cliente sem foto: nada");
	});
});
