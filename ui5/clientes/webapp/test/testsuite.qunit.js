sap.ui.define(function () {
    "use strict";

    return {
        name: "Testes - Gestão de Clientes",
        defaults: {
            page: "ui5://test-resources/zpc/clientes/Test.qunit.html?testsuite={suite}&test={name}",
            qunit: {
                version: 2
            },
            ui5: {
                theme: "sap_horizon"
            },
            loader: {
                paths: {
                    "zpc/clientes": "../"
                }
            }
        },
        tests: {
            "unit/unitTests": {
                title: "Testes unitários - Consulta de CEP"
            }
        }
    };
});
