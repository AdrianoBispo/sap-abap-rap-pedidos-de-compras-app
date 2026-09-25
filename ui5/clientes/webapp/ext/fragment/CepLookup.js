sap.ui.define([
    "zpc/clientes/ext/util/CepUtil",
    "sap/m/MessageToast",
    "sap/base/Log"
], function (CepUtil, MessageToast, Log) {
    "use strict";

    var LOG_COMPONENT = "zpc.clientes.ext.fragment.CepLookup";

    /**
     * Intervalo de silêncio antes de disparar a consulta enquanto o
     * usuário digita. Junto com o token de sequência abaixo, é o que
     * impede uma rajada de requisições ao ViaCEP a cada tecla.
     */
    var DEBOUNCE_MS = 700;

    /**
     * Estado por instância do Input, indexado pelo id do controle.
     * { iTimer, iToken, sPath, sProcessado }
     *
     * `sProcessado` guarda o último CEP que já passou pelo pipeline neste
     * contexto. É o que impede reconsultar o mesmo CEP a cada blur do
     * campo — inclusive o blur provocado pelo clique em "Aplicar" ou
     * "Salvar", que mandaria uma `AplicarDadosCep` em paralelo com a
     * navegação de volta ao cliente ou com a ativação do draft.
     * O Enter ignora essa guarda: é como o usuário repete uma consulta
     * que falhou.
     */
    var mStates = {};

    function getState(oInput) {
        // sInputId e nao sId: a regra sap-no-ui5base-prop do plugin Fiori
        // trata qualquer "sId" como acesso ao membro privado de
        // sap.ui.base.Event e derruba o lint.
        var sInputId = oInput.getId();

        if (!mStates[sInputId]) {
            mStates[sInputId] = {
                iTimer: null,
                iToken: 0,
                sPath: null,
                sProcessado: ""
            };
        }

        return mStates[sInputId];
    }

    function getText(oControl, sKey) {
        var oModel = oControl.getModel("i18n");

        if (!oModel) {
            return sKey;
        }

        var oBundle = oModel.getResourceBundle();

        return oBundle && oBundle.getText ? oBundle.getText(sKey) : sKey;
    }

    function setState(oInput, sState, sText) {
        oInput.setValueState(sState);
        oInput.setValueStateText(sText || "");
    }

    /**
     * Único canal de retorno da consulta: um toast transitório mais o
     * valueState do campo.
     *
     * @param {sap.m.Input} oInput campo do CEP
     * @param {string} sState valueState a aplicar
     * @param {string} sTexto mensagem exibida
     */
    function avisar(oInput, sState, sTexto) {
        setState(oInput, sState, sTexto);
        MessageToast.show(sTexto);
    }

    /**
     * Alinha o estado local ao draft assim que o contexto muda.
     *
     * `ConsultedCep` e `CepStatus` são `@UI.hidden` e não entram em nenhuma
     * anotação de UI, então o Fiori Elements não os inclui no `$select` da
     * Object Page e `getProperty()` devolveria `undefined`. `requestProperty`
     * força a leitura tardia dessas duas propriedades, que é o que torna a
     * guarda de "já consultado" confiável ao reabrir um draft existente.
     *
     * @param {sap.ui.model.odata.v4.Context} oContext contexto do draft do endereço
     * @param {object} oState estado local do Input
     * @returns {Promise} resolvida quando o estado está alinhado
     */
    function sincronizarContexto(oContext, oState) {
        var sPath = oContext.getPath();

        if (oState.sPath === sPath) {
            return Promise.resolve();
        }

        oState.sPath = sPath;
        oState.sProcessado = "";

        return oContext.requestProperty(["ConsultedCep", "CepStatus"])
            .then(function (aValores) {
                // O usuário já navegou para outro endereço
                if (oState.sPath !== sPath) {
                    return;
                }

                if (aValores[1]) {
                    oState.sProcessado = CepUtil.normalizar(aValores[0]);
                }
            })
            .catch(function (oError) {
                Log.warning("Não foi possível ler o estado do CEP no draft",
                    oError, LOG_COMPONENT);
            });
    }

    /**
     * Grava o CEP no draft, consulta a custom entity e aplica o resultado
     * pela ação AplicarDadosCep.
     *
     * @param {sap.m.Input} oInput campo do CEP
     * @param {sap.ui.model.odata.v4.Context} oContext contexto do draft
     * @param {sap.ui.model.odata.v4.ODataModel} oModel modelo OData V4
     * @param {object} oState estado local do Input
     * @param {string} sCep CEP normalizado (8 dígitos)
     * @returns {Promise} resolvida no fim do ciclo
     */
    function executar(oInput, oContext, oModel, oState, sCep) {
        var iToken = ++oState.iToken;

        oInput.setBusy(true);
        setState(oInput, "None", "");

        return oContext.setProperty("Cep", sCep)
            .then(function () {
                return CepUtil.consultar(oModel, sCep);
            })
            .then(function (oResultado) {
                // Chegou fora de ordem: o usuário já digitou outro CEP
                if (iToken !== oState.iToken) {
                    return null;
                }

                return CepUtil.aplicar(oModel, oContext, oResultado)
                    .then(function () {
                        return oResultado;
                    });
            })
            .then(function (oResultado) {
                if (!oResultado || iToken !== oState.iToken) {
                    return;
                }

                // Vale para sucesso e para falha: um CEP inexistente ou uma
                // indisponibilidade do ViaCEP não devem ser reconsultados a
                // cada blur. O Enter força a repetição.
                oState.sProcessado = sCep;

                if (oResultado.Status === CepUtil.STATUS.VALIDADO) {
                    // CEP geral de município: o ViaCEP não traz logradouro
                    // nem bairro, que passam a ser digitados pelo usuário
                    avisar(
                        oInput,
                        "Success",
                        getText(oInput, oResultado.CepGeral ? "cepGeralAplicado" : "cepAplicado")
                    );
                } else {
                    avisar(
                        oInput,
                        "Error",
                        oResultado.Message || getText(oInput, "cepStatusFalha")
                    );
                }
            })
            .catch(function (oError) {
                Log.error("Falha ao consultar o CEP", oError, LOG_COMPONENT);

                if (iToken === oState.iToken) {
                    avisar(oInput, "Error", getText(oInput, "cepStatusFalha"));
                }
            })
            .then(function () {
                if (iToken === oState.iToken) {
                    oInput.setBusy(false);
                }
            });
    }

    /**
     * Pipeline completo, com as guardas que evitam trabalho repetido.
     *
     * @param {sap.m.Input} oInput campo do CEP
     * @param {boolean} bForce ignora o cache do último CEP consultado
     * @returns {Promise} resolvida no fim do ciclo
     */
    function processar(oInput, bForce) {
        var oContext = oInput.getBindingContext();
        var oState = getState(oInput);

        if (oState.iTimer) {
            clearTimeout(oState.iTimer);
            oState.iTimer = null;
        }

        if (!oContext) {
            return Promise.resolve();
        }

        var oModel = oContext.getModel();
        var sCep = CepUtil.normalizar(oInput.getValue());

        if (!sCep.length) {
            setState(oInput, "None", "");
            return Promise.resolve();
        }

        if (sCep.length < CepUtil.CEP_LENGTH) {
            setState(oInput, "Warning", getText(oInput, "cepIncompleto"));
            return Promise.resolve();
        }

        return sincronizarContexto(oContext, oState).then(function () {
            if (!bForce && sCep === oState.sProcessado) {
                return undefined;
            }

            return executar(oInput, oContext, oModel, oState, sCep);
        });
    }

    return {

        /**
         * Formatter do binding: mostra o CEP gravado no draft com máscara.
         *
         * @param {string} sCep valor do campo Cep
         * @returns {string} CEP mascarado
         */
        formatarCep: function (sCep) {
            return CepUtil.formatar(sCep);
        },

        /**
         * O campo só opera sobre o draft.
         *
         * Um formatter em vez de `{= ${IsActiveEntity} === false }`: o
         * formatter devolve sempre um booleano, então `editable` nunca cai
         * no valor padrão do controle.
         *
         * @param {boolean} bIsActiveEntity flag de draft do RAP
         * @returns {boolean} true apenas no draft
         */
        editavel: function (bIsActiveEntity) {
            return bIsActiveEntity === false;
        },

        /**
         * Aplica a máscara enquanto o usuário digita e agenda a consulta.
         *
         * @param {sap.ui.base.Event} oEvent evento liveChange
         */
        onCepLiveChange: function (oEvent) {
            var oInput = oEvent.getSource();
            var sMascarado = CepUtil.formatar(oEvent.getParameter("value"));

            if (oInput.getValue() !== sMascarado) {
                oInput.setValue(sMascarado);
            }

            var oState = getState(oInput);

            if (oState.iTimer) {
                clearTimeout(oState.iTimer);
            }

            if (!CepUtil.isCompleto(sMascarado)) {
                // Feedback imediato, sem chamada ao backend
                setState(
                    oInput,
                    sMascarado.length ? "Warning" : "None",
                    getText(oInput, "cepIncompleto")
                );
                return;
            }

            oState.iTimer = setTimeout(function () {
                processar(oInput, false);
            }, DEBOUNCE_MS);
        },

        /**
         * Perda de foco: consulta na hora, sem esperar o debounce, mas
         * respeitando a guarda do último CEP processado. É essa guarda que
         * impede uma `AplicarDadosCep` em paralelo com a ativação do draft
         * quando o blur vem do clique em "Aplicar" ou "Salvar".
         *
         * @param {sap.ui.base.Event} oEvent evento change
         */
        onCepChange: function (oEvent) {
            processar(oEvent.getSource(), false);
        },

        /**
         * Enter: consulta na hora e ignora a guarda. É como o usuário
         * repete uma consulta que falhou.
         *
         * @param {sap.ui.base.Event} oEvent evento submit
         */
        onCepSubmit: function (oEvent) {
            processar(oEvent.getSource(), true);
        }
    };
});
