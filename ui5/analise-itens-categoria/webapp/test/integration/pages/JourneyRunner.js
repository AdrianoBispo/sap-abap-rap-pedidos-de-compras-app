sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analiseitenscategoria/test/integration/pages/ItemAnaliseList.gen"
], function (JourneyRunner, ItemAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analiseitenscategoria') + '/test/flp.html#app-preview',
        pages: {
			onTheItemAnaliseListGenerated: ItemAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

