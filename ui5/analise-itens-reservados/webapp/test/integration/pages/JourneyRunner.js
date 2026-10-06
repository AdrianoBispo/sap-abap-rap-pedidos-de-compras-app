sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analiseitensreservados/test/integration/pages/ItemAnaliseList.gen"
], function (JourneyRunner, ItemAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analiseitensreservados') + '/test/flp.html#app-preview',
        pages: {
			onTheItemAnaliseListGenerated: ItemAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

