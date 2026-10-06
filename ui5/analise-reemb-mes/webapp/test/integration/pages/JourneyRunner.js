sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analisereembmes/test/integration/pages/ReembolsoAnaliseList.gen"
], function (JourneyRunner, ReembolsoAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analisereembmes') + '/test/flp.html#app-preview',
        pages: {
			onTheReembolsoAnaliseListGenerated: ReembolsoAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

