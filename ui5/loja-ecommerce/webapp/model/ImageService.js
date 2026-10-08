sap.ui.define([], () => {
	"use strict";

	return {
		/**
		 * Turns a picture chosen by the customer into a square JPEG (center crop), so that the upload is small and
		 * always in a type the back-end accepts (JPEG, PNG or WebP; the back-end also checks the content).
		 * @param {File|Blob} oFile image chosen by the customer
		 * @param {number} [iSize] side of the result in pixels
		 * @param {number} [fQuality] JPEG quality, 0 to 1
		 * @returns {Promise<Blob>} the image/jpeg
		 */
		async toSquareJpeg(oFile, iSize = 512, fQuality = 0.85) {
			const oBitmap = await createImageBitmap(oFile);
			const iSide = Math.min(oBitmap.width, oBitmap.height);
			const oCanvas = new OffscreenCanvas(iSize, iSize);
			const oContext = oCanvas.getContext("2d");

			// transparent PNGs get a white background (JPEG has no transparency)
			oContext.fillStyle = "#fff";
			oContext.fillRect(0, 0, iSize, iSize);
			oContext.drawImage(oBitmap, (oBitmap.width - iSide) / 2, (oBitmap.height - iSide) / 2, iSide, iSide, 0, 0,
				iSize, iSize);
			oBitmap.close();

			return oCanvas.convertToBlob({type: "image/jpeg", quality: fQuality});
		}
	};
});
