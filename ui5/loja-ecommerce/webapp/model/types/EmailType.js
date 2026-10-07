sap.ui.define([
	"sap/ui/model/SimpleType",
	"sap/ui/model/ValidateException"
], (SimpleType, ValidateException) => {
	"use strict";

	return SimpleType.extend("lojaecommerce.model.types.EmailType", {
		formatValue(oValue) {
			return oValue;
		},

		parseValue(oValue) {
			return oValue;
		},

		validateValue(oValue) {
			const rEmail = /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/;
			if (!rEmail.test(oValue)) {
				throw new ValidateException("'" + oValue + "' is not a valid email address");
			}
		}
	});
});
