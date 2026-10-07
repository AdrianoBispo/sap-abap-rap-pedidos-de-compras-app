sap.ui.define([
	"sap/ui/core/format/NumberFormat",
	"sap/ui/core/format/DateFormat"
], (NumberFormat, DateFormat) => {
	"use strict";

	const mStatusState = {
		A: "Success",
		L: "Warning",
		O: "Error",
		D: "Error"
	};

	const formatter = {
		/**
		 * Formats a price in the pt-BR style (1.234,56).
		 * @param {string|number} vValue price
		 * @returns {string} formatted price
		 */
		price(vValue) {
			const oFloatInstance = NumberFormat.getFloatInstance({
				maxFractionDigits: 2,
				minFractionDigits: 2,
				groupingEnabled: true,
				groupingSeparator: ".",
				decimalSeparator: ","
			});

			return oFloatInstance.format(vValue);
		},

		/**
		 * Total of a cart line (unit price x quantity).
		 * @param {number} fPrice unit price
		 * @param {number} iQuantity quantity
		 * @returns {string} formatted total
		 */
		lineTotal(fPrice, iQuantity) {
			return formatter.price(fPrice * iQuantity);
		},

		/**
		 * Sum of the prices of all entries in the cart.
		 * @param {object} oCartEntries cart entries
		 * @returns {number} total
		 */
		totalValue(oCartEntries) {
			return Object.values(oCartEntries || {})
				.reduce((fTotal, oEntry) => fTotal + oEntry.Price * oEntry.Quantity, 0);
		},

		/**
		 * Text with the total of the cart.
		 * @param {object} oCartEntries cart entries
		 * @returns {string} total with currency
		 */
		async totalPrice(oCartEntries) {
			const aEntries = Object.values(oCartEntries || {});
			const sCurrency = aEntries.length ? aEntries[0].CurrencyCode : "BRL";

			return (await this.requestResourceBundle())
				.getText("cartTotalPrice", [formatter.price(formatter.totalValue(oCartEntries)), sCurrency]);
		},

		/**
		 * Number of pieces in the cart (shown as badge of the cart button).
		 * @param {object} oCartEntries cart entries
		 * @returns {string} number of pieces, empty when the cart is empty
		 */
		cartCount(oCartEntries) {
			const iCount = Object.values(oCartEntries || {}).reduce((iSum, oEntry) => iSum + oEntry.Quantity, 0);

			return iCount ? String(iCount) : "";
		},

		async statusText(sStatus) {
			const oBundle = await this.requestResourceBundle();
			const mStatusText = {
				A: oBundle.getText("statusA"),
				L: oBundle.getText("statusL"),
				O: oBundle.getText("statusO"),
				D: oBundle.getText("statusD")
			};

			return mStatusText[sStatus] || sStatus;
		},

		statusState(sStatus) {
			return mStatusState[sStatus] || "None";
		},

		/**
		 * Text of the stock indicator, e.g. "Restam 3 unidades".
		 * @param {string} sStatus product status
		 * @param {number} iQuantity available quantity
		 * @returns {string} text
		 */
		async availabilityText(sStatus, iQuantity) {
			const oBundle = await this.requestResourceBundle();
			if (sStatus === "L") {
				return oBundle.getText("availabilityLast", [iQuantity]);
			}

			return await formatter.statusText.call(this, sStatus);
		},

		/**
		 * Products that can be put in the cart.
		 * @param {string} sStatus product status
		 * @returns {boolean} true when the product is in stock
		 */
		isBuyable(sStatus) {
			return sStatus === "A" || sStatus === "L";
		},

		pictureUrl(sUrl) {
			return sUrl || undefined;
		},

		/**
		 * Checks if one of the collections contains items.
		 * @param {object} oCollection1 first array or object
		 * @param {object} oCollection2 second array or object
		 * @returns {boolean} true if one of the collections is not empty
		 */
		hasItems(oCollection1, oCollection2) {
			return !!(oCollection1 && Object.keys(oCollection1).length)
				|| !!(oCollection2 && Object.keys(oCollection2).length);
		},

		/**
		 * Card number with only the last 4 digits visible.
		 * @param {string} sNumber card number
		 * @returns {string} masked number
		 */
		maskedCard(sNumber) {
			const sDigits = String(sNumber || "").replace(/\D/g, "");

			return sDigits.length >= 4 ? "**** **** **** " + sDigits.slice(-4) : "";
		},

		date(vValue) {
			if (!vValue) {
				return "";
			}

			return DateFormat.getDateInstance({style: "medium"}).format(new Date(vValue));
		}
	};

	return formatter;
});
