sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analiseclientesuf/test/integration/pages/ClienteAnaliseList.gen"
], function (JourneyRunner, ClienteAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analiseclientesuf') + '/test/flp.html#app-preview',
        pages: {
			onTheClienteAnaliseListGenerated: ClienteAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

