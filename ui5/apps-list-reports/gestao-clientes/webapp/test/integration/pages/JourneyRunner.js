sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"gestaoclientes/test/integration/pages/ClienteList.gen",
	"gestaoclientes/test/integration/pages/ClienteObjectPage.gen"
], function (JourneyRunner, ClienteListGenerated, ClienteObjectPageGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('gestaoclientes') + '/test/flp.html#app-preview',
        pages: {
			onTheClienteListGenerated: ClienteListGenerated,
			onTheClienteObjectPageGenerated: ClienteObjectPageGenerated
        },
        async: true
    });

    return runner;
});

