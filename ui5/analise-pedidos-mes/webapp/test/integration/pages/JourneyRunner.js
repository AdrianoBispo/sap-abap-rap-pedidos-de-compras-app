sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analisepedidosmes/test/integration/pages/PedidoAnaliseList.gen"
], function (JourneyRunner, PedidoAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analisepedidosmes') + '/test/flp.html#app-preview',
        pages: {
			onThePedidoAnaliseListGenerated: PedidoAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

