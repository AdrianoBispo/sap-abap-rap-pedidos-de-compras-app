sap.ui.define([], () => {
	"use strict";

	return {
		// every request is sent at once: the steps depend on each other (draft, children, activation, action)
		group: "$direct",

		/**
		 * Invokes a bound action ignoring the ETag (If-Match: *). The ETag of a draft changes every time a child is
		 * created or the draft is prepared, but the model keeps the one of the creation, so a draft action with it
		 * answers "412 stale If-Match": the order stayed as a draft and the draft could not even be discarded.
		 * The shop is the only one working on the draft it has just created, so there is nothing to protect.
		 * @param {sap.ui.model.odata.v4.ODataContextBinding} oOperation the operation binding
		 * @returns {Promise} resolves when the action was executed
		 */
		invoke(oOperation) {
			return oOperation.invoke(this.group, {"@odata.etag": "*"});
		},

		/**
		 * Plain HTTP request to the service, for what the model cannot do: uploading the content of a stream
		 * property. It reuses the session and the CSRF token of the model and ignores the ETag like invoke().
		 * @param {sap.ui.model.odata.v4.ODataModel} oModel model of the service
		 * @param {string} sMethod HTTP method (PUT, PATCH)
		 * @param {string} sPath path relative to the service root
		 * @param {Blob|string} vBody request body
		 * @param {string} sContentType content type of the body
		 * @returns {Promise<Response>} the response (an error status is thrown as an Error with the back-end message)
		 */
		async rawRequest(oModel, sMethod, sPath, vBody, sContentType) {
			const sUrl = oModel.getServiceUrl() + sPath;
			let sToken = (oModel.getHttpHeaders() || {})["X-CSRF-Token"];

			if (!sToken || sToken === "Fetch") {
				sToken = (await fetch(oModel.getServiceUrl(), {headers: {"X-CSRF-Token": "Fetch"}, credentials: "same-origin"}))
					.headers.get("X-CSRF-Token");
			}
			const oResponse = await fetch(sUrl, {
				method: sMethod,
				credentials: "same-origin",
				headers: {"Content-Type": sContentType, "X-CSRF-Token": sToken, "If-Match": "*", "Accept": "application/json"},
				body: vBody
			});

			if (!oResponse.ok) {
				let oBody;
				try {
					oBody = await oResponse.json();
				} catch {
					oBody = {};
				}
				const oError = new Error((oBody.error && oBody.error.message) || `${sMethod} ${sPath}: ${oResponse.status}`);
				oError.error = oBody.error;
				throw oError;
			}

			return oResponse;
		},

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
					await this.invoke(this.bindAction(oModel, sNamespace, "Discard", oDraft));
				}
			} catch {
				// nothing else to do: the back-end cleans up the draft when it expires
			}
		}
	};
});
