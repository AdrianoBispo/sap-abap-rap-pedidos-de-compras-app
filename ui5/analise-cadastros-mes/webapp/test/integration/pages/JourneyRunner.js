sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analisecadastrosmes/test/integration/pages/ClienteAnaliseList.gen"
], function (JourneyRunner, ClienteAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analisecadastrosmes') + '/test/flp.html#app-preview',
        pages: {
			onTheClienteAnaliseListGenerated: ClienteAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

