sap.ui.define([
	"sap/ui/model/json/JSONModel",
	"sap/ui/util/Storage"
], (JSONModel, Storage) => {
	"use strict";

	/**
	 * JSON model whose data is mirrored in the browser local storage (cart, saved items, comparison).
	 * The storage access is wrapped, so the app keeps working when the storage is blocked.
	 */
	return JSONModel.extend("lojaecommerce.model.LocalStorageModel", {
		_STORAGE_KEY: "LOCALSTORAGE_MODEL",

		_storage: new Storage(Storage.Type.local),

		/**
		 * @param {string} sStorageKey storage key used as id of the persisted data
		 * @param {object} oSettings initial data, handed to the JSON model constructor
		 */
		constructor: function(sStorageKey, oSettings) {
			JSONModel.apply(this, [].slice.call(arguments, 1));
			this.setSizeLimit(1000000);

			if (sStorageKey) {
				this._STORAGE_KEY = sStorageKey;
			}
			this._loadData();

			return this;
		},

		_loadData() {
			try {
				const sJSON = this._storage.get(this._STORAGE_KEY);
				if (sJSON) {
					this.setData(JSON.parse(sJSON));
				}
			} catch {
				// storage blocked or corrupted content: start with the initial data
			}
			this._bDataLoaded = true;
		},

		_storeData() {
			try {
				this._storage.put(this._STORAGE_KEY, JSON.stringify(this.getData()));
			} catch {
				// storage blocked or full: the model keeps working in memory
			}
		},

		setProperty() {
			JSONModel.prototype.setProperty.apply(this, arguments);
			this._storeData();
		},

		setData() {
			JSONModel.prototype.setData.apply(this, arguments);
			// called from the constructor: only store after the first load
			if (this._bDataLoaded) {
				this._storeData();
			}
		},

		refresh() {
			JSONModel.prototype.refresh.apply(this, arguments);
			this._storeData();
		}
	});
});
