sap.ui.define([
	"sap/ui/model/SimpleType",
	"sap/ui/model/ValidateException"
], (SimpleType, ValidateException) => {
	"use strict";

	/**
	 * Checks the two verification digits of a CPF.
	 * @param {string} sDigits the 11 digits of the CPF
	 * @returns {boolean} true when the CPF is valid
	 */
	function isValidCpf(sDigits) {
		if (!/^\d{11}$/.test(sDigits) || /^(\d)\1{10}$/.test(sDigits)) {
			return false;
		}
		const fnDigit = (iLength) => {
			let iSum = 0;
			for (let i = 0; i < iLength; i++) {
				iSum += Number(sDigits.charAt(i)) * (iLength + 1 - i);
			}
			const iRest = (iSum * 10) % 11;

			return iRest === 10 ? 0 : iRest;
		};

		return fnDigit(9) === Number(sDigits.charAt(9)) && fnDigit(10) === Number(sDigits.charAt(10));
	}

	const CpfType = SimpleType.extend("lojaecommerce.model.types.CpfType", {
		formatValue(oValue) {
			return oValue;
		},

		parseValue(oValue) {
			return oValue;
		},

		validateValue(oValue) {
			if (!isValidCpf(String(oValue).replace(/\D/g, ""))) {
				throw new ValidateException("'" + oValue + "' is not a valid CPF");
			}
		}
	});
	CpfType.isValidCpf = isValidCpf;

	return CpfType;
});
