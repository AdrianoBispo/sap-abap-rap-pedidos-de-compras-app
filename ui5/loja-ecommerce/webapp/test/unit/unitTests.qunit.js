QUnit.config.autostart = false;

sap.ui.require([
	"lojaecommerce/test/unit/model/Catalog.qunit",
	"lojaecommerce/test/unit/model/cart.qunit",
	"lojaecommerce/test/unit/model/CpfType.qunit",
	"lojaecommerce/test/unit/model/AccountService.qunit",
	"lojaecommerce/test/unit/model/OrderService.qunit",
	"lojaecommerce/test/unit/model/formatter.qunit"
], () => {
	"use strict";

	QUnit.start();
});
