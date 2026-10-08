sap.ui.define([
	"lojaecommerce/model/OrderService",
	"lojaecommerce/model/CustomerService",
	"sap/ui/model/odata/v4/ODataModel"
], (OrderService, CustomerService, ODataModel) => {
	"use strict";

	// These tests talk to the mock server (npm run unit-test uses ui5-mock.yaml) with the metadata of the real services
	const sOrders = "/sap/opu/odata4/sap/zui_pc_pedidos_compras_o4/srvd/sap/zui_pc_pedidos_compras/0001/";
	const sCustomers = "/sap/opu/odata4/sap/zui_pc_clientes_o4/srvd/sap/zui_pc_clientes/0001/";
	const oModelSettings = {operationMode: "Server", autoExpandSelect: true, groupId: "$auto", updateGroupId: "$direct"};

	QUnit.module("OrderService - helpers");

	QUnit.test("texto do erro junta a mensagem e os detalhes, sem repetir", (assert) => {
		const oError = {error: {message: "Falha", details: [{message: "Item sem estoque"}, {message: "Falha"}]}};

		assert.strictEqual(OrderService.errorText(oError), "Falha\nItem sem estoque");
		assert.strictEqual(OrderService.errorText(new Error("rede")), "rede");
	});

	QUnit.test("observação do pedido leva a entrega e a nota, limitada a 500 caracteres", (assert) => {
		assert.strictEqual(OrderService.buildNote("Entrega expressa", " tocar a campainha "),
			"Loja virtual | Entrega expressa | tocar a campainha");
		assert.strictEqual(OrderService.buildNote("Entrega padrão", ""), "Loja virtual | Entrega padrão");
		assert.strictEqual(OrderService.buildNote("x", "a".repeat(600)).length, 500);
	});

	QUnit.test("CPF só com dígitos e formatado", (assert) => {
		assert.strictEqual(OrderService.onlyDigits("529.982.247-25"), "52998224725");
		assert.strictEqual(OrderService.formatCpf("52998224725"), "529.982.247-25");
	});

	QUnit.module("OrderService - integração com o mock dos serviços", {
		beforeEach() {
			this.oOrders = new ODataModel({serviceUrl: sOrders, ...oModelSettings});
			this.oCustomers = new ODataModel({serviceUrl: sCustomers, ...oModelSettings});
		},
		afterEach() {
			this.oOrders.destroy();
			this.oCustomers.destroy();
		}
	});

	QUnit.test("encontra o cliente pelo CPF, com ou sem pontuação, e não encontra CPF desconhecido", async function(assert) {
		const oFound = await OrderService.findCustomer(this.oOrders, "529.982.247-25");

		assert.strictEqual(oFound.Nome, "Maria Silva");
		assert.ok(oFound.ClienteUUID, "traz a chave do cliente");
		assert.strictEqual((await OrderService.findCustomer(this.oOrders, "52998224725")).Nome, "Maria Silva");
		assert.strictEqual(await OrderService.findCustomer(this.oOrders, "39053344705"), undefined);
	});

	QUnit.test("cadastra o cliente novo (cliente + endereço) e ativa", async function(assert) {
		const oCustomer = await CustomerService.register(this.oCustomers, {
			Cpf: "390.533.447-05", Nome: "Ana Souza", Email: "Ana@Exemplo.com.br", Telefone: "(81) 99999-1111",
			DataNascimento: "1990-05-20", Cep: "50670-901", Numero: "100", Complemento: ""
		});

		assert.ok(oCustomer.id, "cliente com chave");
		assert.strictEqual(oCustomer.name, "Ana Souza");
		assert.strictEqual(oCustomer.city, "Recife", "cidade do endereço principal");
	});

	QUnit.test("grava o pedido (rascunho, itens, ativação) e paga", async function(assert) {
		const oPlaced = await OrderService.createOrder(this.oOrders, {
			customerId: "c0000000-0000-0000-0000-000000000001",
			items: [{ItemUUID: "5a1b0000-0000-0000-0000-000000000001", Quantity: 2}],
			note: "Loja virtual | Entrega padrão"
		});

		assert.ok(/^\d{10}$/.test(oPlaced.number), "número do pedido do back-end");
		assert.strictEqual(oPlaced.status, "ABERTO");

		const oPayment = await OrderService.pay(this.oOrders, oPlaced.context, {
			method: "CARTAO_CREDITO", number: "4111-1111-1111-1111", expiry: "12/2030", cvv: "123"
		});

		assert.ok(oPayment.approved, "pagamento aprovado");
		assert.strictEqual(oPayment.status, "AGUARDANDO_APROVACAO");
		OrderService.release(oPlaced);
	});

	QUnit.test("pagamento recusado (CVV 000) não é erro: o pedido segue aberto e pode ser cancelado", async function(assert) {
		const oPlaced = await OrderService.createOrder(this.oOrders, {
			customerId: "c0000000-0000-0000-0000-000000000001",
			items: [{ItemUUID: "5a1b0000-0000-0000-0000-000000000002", Quantity: 1}],
			note: ""
		});
		const oPayment = await OrderService.pay(this.oOrders, oPlaced.context, {
			method: "CARTAO_DEBITO", number: "5555555555554444", expiry: "12/2030", cvv: "000"
		});

		assert.notOk(oPayment.approved, "recusado");
		assert.strictEqual(oPayment.status, "ABERTO");

		await OrderService.cancel(this.oOrders, oPlaced.context, "Cancelado pelo cliente");
		assert.strictEqual(oPlaced.context.getObject().StatusPedido, "CANCELADO");
		OrderService.release(oPlaced);
	});
});
