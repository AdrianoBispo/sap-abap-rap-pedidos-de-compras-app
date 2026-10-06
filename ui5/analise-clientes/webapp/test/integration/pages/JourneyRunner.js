sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analiseclientes/test/integration/pages/ClienteAnaliseList.gen"
], function (JourneyRunner, ClienteAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analiseclientes') + '/test/flp.html#app-preview',
        pages: {
			onTheClienteAnaliseListGenerated: ClienteAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

