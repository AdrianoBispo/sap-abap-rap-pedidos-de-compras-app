sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"analiseitenssituacao/test/integration/pages/ItemAnaliseList.gen"
], function (JourneyRunner, ItemAnaliseListGenerated) {
    'use strict';

    var runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('analiseitenssituacao') + '/test/flp.html#app-preview',
        pages: {
			onTheItemAnaliseListGenerated: ItemAnaliseListGenerated
        },
        async: true
    });

    return runner;
});

