sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"gestaoestoque/test/integration/pages/ItemList.gen",
	"gestaoestoque/test/integration/pages/ItemObjectPage.gen"
], function (JourneyRunner, ItemListGenerated, ItemObjectPageGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('gestaoestoque') + '/test/flp.html#app-preview',
        pages: {
			onTheItemListGenerated: ItemListGenerated,
			onTheItemObjectPageGenerated: ItemObjectPageGenerated
        },
        async: true
    });

    return runner;
});

