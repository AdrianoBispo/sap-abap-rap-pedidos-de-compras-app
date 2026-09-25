sap.ui.define([
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator",
    "sap/base/Log"
], function (Filter, FilterOperator, Log) {
    "use strict";

    var LOG_COMPONENT = "zpc.clientes.ext.util.CepUtil";

    /**
     * Tamanho do CEP brasileiro, sem máscara.
     */
    var CEP_LENGTH = 8;

    /**
     * Entity set da custom entity ZI_PC_CEP_LOOKUP no serviço ZUI_PC_CLIENTES.
     */
    var LOOKUP_ENTITY_SET = "/CepLookUp";

    /**
     * Nome curto da ação RAP do Endereço. O namespace é descoberto em runtime.
     */
    var ACTION_NAME = "AplicarDadosCep";

    /**
     * Campos lidos da custom entity — também são os parâmetros da ação
     * AplicarDadosCep, porque a ação usa a abstract entity ZPC_A_CEP_RESULTADO.
     */
    var LOOKUP_FIELDS = [
        "Cep",
        "Logradouro",
        "Complemento",
        "Bairro",
        "Cidade",
        "Uf",
        "Estado",
        "CepGeral",
        "Status",
        "Message"
    ];

    /**
     * Valor enviado quando a linha da consulta não traz o campo. CepGeral é
     * Edm.Boolean: uma string vazia seria recusada pelo parâmetro da ação.
     */
    var PARAM_DEFAULTS = {
        CepGeral: false
    };

    /**
     * Campos que a ação altera no draft e que precisam ser relidos.
     * Espelha o bloco "side effects" da Behavior Definition ZR_PC_CLIENTE.
     */
    var SIDE_EFFECT_FIELDS = [
        "Logradouro",
        "Complemento",
        "Bairro",
        "Cidade",
        "Uf",
        "Estado",
        "CepGeral",
        "CepStatus",
        "ConsultedCep"
    ];

    /**
     * Controle de campo dinâmico (features : instance) de Logradouro e
     * Bairro, que só ficam editáveis para CEP geral de município.
     */
    var FIELD_CONTROL_PATH = "__FieldControl";

    /**
     * Valores de ZIF_PC_CONSTANTS=>c_status_cep.
     */
    var STATUS = {
        VALIDADO: "V",
        INVALIDO: "I",
        INDISPONIVEL: "X"
    };

    return {

        CEP_LENGTH: CEP_LENGTH,
        SIDE_EFFECT_FIELDS: SIDE_EFFECT_FIELDS,
        STATUS: STATUS,

        /**
         * Remove máscara e qualquer caractere não numérico, limitando a 8
         * dígitos. É a normalização exigida na camada de UI.
         *
         * @param {string} sValue valor digitado
         * @returns {string} somente dígitos, no máximo 8
         */
        normalizar: function (sValue) {
            return String(sValue || "")
                .replace(/\D/g, "")
                .slice(0, CEP_LENGTH);
        },

        /**
         * Aplica a máscara 99999-999 sobre o que já foi digitado.
         *
         * @param {string} sValue valor digitado
         * @returns {string} valor mascarado
         */
        formatar: function (sValue) {
            var sCep = this.normalizar(sValue);

            if (sCep.length > 5) {
                return sCep.slice(0, 5) + "-" + sCep.slice(5);
            }

            return sCep;
        },

        /**
         * @param {string} sValue valor digitado
         * @returns {boolean} true quando há exatamente 8 dígitos
         */
        isCompleto: function (sValue) {
            return this.normalizar(sValue).length === CEP_LENGTH;
        },

        /**
         * Valor de um campo da consulta pronto para virar parâmetro da ação.
         *
         * @param {object} oResultado linha devolvida por consultar()
         * @param {string} sField nome do campo
         * @returns {any} valor do campo ou o padrão do seu tipo
         */
        valorParametro: function (oResultado, sField) {
            var vValue = oResultado[sField];

            if (vValue !== undefined && vValue !== null) {
                return vValue;
            }

            return Object.prototype.hasOwnProperty.call(PARAM_DEFAULTS, sField)
                ? PARAM_DEFAULTS[sField]
                : "";
        },

        /**
         * Descobre o namespace do serviço a partir do entity container,
         * evitando fixar "com.sap.gateway.srvd...." no código.
         *
         * @param {sap.ui.model.odata.v4.ODataModel} oModel modelo OData V4
         * @returns {Promise<string>} namespace, ex.: com.sap.gateway.srvd.zui_pc_clientes.v0001
         */
        requestServiceNamespace: function (oModel) {
            return oModel.getMetaModel()
                .requestObject("/$EntityContainer")
                .then(function (sContainer) {
                    if (!sContainer || sContainer.indexOf(".") < 0) {
                        throw new Error(
                            "Não foi possível determinar o namespace do serviço OData."
                        );
                    }
                    return sContainer.slice(0, sContainer.lastIndexOf("."));
                });
        },

        /**
         * Consulta o CEP na custom entity, que por sua vez chama o ViaCEP.
         * Nunca rejeita por CEP inexistente: o provider devolve uma linha
         * com Status = I ou X.
         *
         * @param {sap.ui.model.odata.v4.ODataModel} oModel modelo OData V4
         * @param {string} sCep CEP normalizado (8 dígitos)
         * @returns {Promise<object>} linha de ZI_PC_CEP_LOOKUP
         */
        consultar: function (oModel, sCep) {
            var oListBinding = oModel.bindList(
                LOOKUP_ENTITY_SET,
                undefined,
                undefined,
                [new Filter("Cep", FilterOperator.EQ, sCep)],
                {
                    $$groupId: "$direct",
                    $select: LOOKUP_FIELDS.join(",")
                }
            );

            return oListBinding.requestContexts(0, 1).then(function (aContexts) {
                if (!aContexts.length) {
                    return {
                        Cep: sCep,
                        Status: STATUS.INDISPONIVEL,
                        Message: ""
                    };
                }

                return aContexts[0].getObject();
            });
        },

        /**
         * Invoca a ação AplicarDadosCep sobre o draft do endereço e recarrega
         * os campos afetados.
         *
         * @param {sap.ui.model.odata.v4.ODataModel} oModel modelo OData V4
         * @param {sap.ui.model.odata.v4.Context} oContext contexto do draft
         * @param {object} oResultado linha devolvida por consultar()
         * @returns {Promise} resolvida quando o draft já está atualizado
         */
        aplicar: function (oModel, oContext, oResultado) {
            var that = this;

            return this.requestServiceNamespace(oModel).then(function (sNamespace) {
                var oAction = oModel.bindContext(
                    sNamespace + "." + ACTION_NAME + "(...)",
                    oContext
                );

                LOOKUP_FIELDS.forEach(function (sField) {
                    oAction.setParameter(sField, that.valorParametro(oResultado, sField));
                });

                // invoke() substituiu execute() a partir do UI5 1.123
                var fnInvoke = oAction.invoke || oAction.execute;

                // bIgnoreETag = true: a determination LimparDadosCep altera o
                // draft antes da ação e a ETag em cache fica desatualizada.
                return fnInvoke.call(oAction, "$auto", true);
            }).then(function () {
                return oContext.requestSideEffects(SIDE_EFFECT_FIELDS);
            }).then(function () {
                // Logradouro e Bairro passam a editáveis (ou deixam de ser)
                // conforme CepGeral. Em separado e sem propagar erro: o
                // endereço já foi gravado, e uma falha aqui só atrasa a
                // troca de editabilidade até a próxima leitura da página.
                return oContext.requestSideEffects([FIELD_CONTROL_PATH])
                    .catch(function (oError) {
                        Log.warning("Não foi possível reler o controle de campos",
                            oError, LOG_COMPONENT);
                    });
            });
        }
    };
});
