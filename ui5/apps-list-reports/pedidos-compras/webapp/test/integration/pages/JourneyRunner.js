sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"pedidoscompras/test/integration/pages/PedidoList.gen",
	"pedidoscompras/test/integration/pages/PedidoObjectPage.gen"
], function (JourneyRunner, PedidoListGenerated, PedidoObjectPageGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('pedidoscompras') + '/test/flp.html#app-preview',
        pages: {
			onThePedidoListGenerated: PedidoListGenerated,
			onThePedidoObjectPageGenerated: PedidoObjectPageGenerated
        },
        async: true
    });

    return runner;
});

