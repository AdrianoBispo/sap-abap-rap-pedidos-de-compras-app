sap.ui.define([
	"./BaseController"
], (BaseController) => {
	"use strict";

	return BaseController.extend("lojaecommerce.controller.NotFound", {
		onInit() {
			this.getRouter().getTarget("notFound").attachDisplay(() => {
				this._setLayout("Two");
			}, this);
		}
	});
});
