sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analisepedidosuf/test/integration/pages/PedidoAnaliseList.gen"
], function (JourneyRunner, PedidoAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analisepedidosuf') + '/test/flp.html#app-preview',
        pages: {
			onThePedidoAnaliseListGenerated: PedidoAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

