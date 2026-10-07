sap.ui.define([
	"./BaseController",
	"sap/ui/model/json/JSONModel",
	"sap/m/MessageBox"
], (BaseController, JSONModel, MessageBox) => {
	"use strict";

	return BaseController.extend("lojaecommerce.controller.App", {
		onInit() {
			const oViewModel = new JSONModel({
				busy: true,
				delay: 0,
				layout: "TwoColumnsMidExpanded",
				smallScreenMode: true
			});
			this.setModel(oViewModel, "appView");

			const iOriginalBusyDelay = this.getView().getBusyIndicatorDelay();
			const fnSetNotBusy = () => {
				oViewModel.setProperty("/busy", false);
				oViewModel.setProperty("/delay", iOriginalBusyDelay);
			};

			// the shop is busy until the products are read from the stock service
			this.getOwnerComponent().loadCatalog().then(fnSetNotBusy, async (oError) => {
				fnSetNotBusy();
				MessageBox.error((await this.requestResourceBundle()).getText("catalogLoadError"), {
					details: oError && oError.message
				});
			});

			this.getView().addStyleClass(this.getOwnerComponent().getContentDensityClass());
		}
	});
});
