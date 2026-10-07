sap.ui.define([], () => {
	"use strict";

	return {
		// every request is sent at once: the steps depend on each other (draft, children, activation, action)
		group: "$direct",

		onlyDigits(sValue) {
			return String(sValue || "").replace(/\D/g, "");
		},

		/**
		 * Readable text of an error of the OData V4 model: the message and the detail messages of the back-end
		 * (validation, stock, authorization), without repetitions.
		 * @param {Error} oError error thrown by the model
		 * @returns {string} text for the message box
		 */
		errorText(oError) {
			const oBackend = (oError && oError.error) || {};
			const aTexts = [oBackend.message || (oError && oError.message)]
				.concat((oBackend.details || []).map((oDetail) => oDetail.message))
				.filter(Boolean);

			return [...new Set(aTexts)].join("\n");
		},

		/**
		 * Binds a bound action of the service of the model to a context.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the service
		 * @param {string} sNamespace namespace of the actions (see the $metadata of the service)
		 * @param {string} sAction action name
		 * @param {sap.ui.model.odata.v4.Context} oContext context of the entity
		 * @returns {sap.ui.model.odata.v4.ODataContextBinding} operation binding
		 */
		bindAction(oModel, sNamespace, sAction, oContext) {
			return oModel.bindContext(`${sNamespace}.${sAction}(...)`, oContext);
		},

		/**
		 * Discards the draft of a failed registration, so that it is not left behind in the back-end.
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the service
		 * @param {string} sNamespace namespace of the actions
		 * @param {sap.ui.model.odata.v4.Context} oDraft context of the draft
		 */
		async discardDraft(oModel, sNamespace, oDraft) {
			try {
				if (oDraft.isTransient()) {
					await oDraft.delete(this.group);
				} else {
					await this.bindAction(oModel, sNamespace, "Discard", oDraft).invoke(this.group);
				}
			} catch {
				// nothing else to do: the back-end cleans up the draft when it expires
			}
		}
	};
});
