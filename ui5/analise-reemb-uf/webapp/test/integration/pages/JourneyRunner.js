sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analisereembuf/test/integration/pages/ReembolsoAnaliseList.gen"
], function (JourneyRunner, ReembolsoAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analisereembuf') + '/test/flp.html#app-preview',
        pages: {
			onTheReembolsoAnaliseListGenerated: ReembolsoAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

