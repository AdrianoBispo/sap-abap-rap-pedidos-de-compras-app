/**
 * Ações customizadas do app Pedidos de Compras (List Report e Object Page).
 *
 * Efetuar Pagamento e Cancelar pedido têm parâmetros: o Fiori Elements não
 * mostra o pop-up de confirmação (Common.IsActionCritical) em ações com diálogo
 * de parâmetros, por isso os botões padrão foram trocados por estes, que pedem
 * a confirmação e depois executam a action do RAP via editFlow.invokeAction.
 * Os botões padrão continuam na DDLX ZC_PC_PEDIDO_APP (para o Preview do
 * serviço) e ficam ocultos neste app pelo manifest (visible: false).
 * Aprovar pedido não tem parâmetros e usa o botão padrão com IsActionCritical
 * (annotations/annotation.xml).
 *
 * Efetuar Pagamento usa um diálogo próprio com máscaras de entrada (número do
 * cartão, validade MM/AA e CVV). O backend valida todos os campos no precheck
 * da action SimularPagamento.
 *
 * Os handlers são chamados pelo Fiori Elements com this = ExtensionAPI.
 */
sap.ui.define([
    "sap/m/MessageBox",
    "sap/m/Dialog",
    "sap/m/Button",
    "sap/m/Label",
    "sap/m/MaskInput",
    "sap/m/Select",
    "sap/ui/core/Item",
    "sap/ui/layout/form/SimpleForm"
], function (MessageBox, Dialog, Button, Label, MaskInput, Select, Item, SimpleForm) {
    "use strict";

    // Namespace do serviço OData V4 (ZUI_PC_PEDIDOS_COMPRAS_O4)
    const SERVICO = "com.sap.gateway.srvd.zui_pc_pedidos_compras.v0001.";

    // Valores de ZIF_PC_CONSTANTS=>c_metodo_pagamento
    const METODO = {
        CREDITO: "CARTAO_CREDITO",
        DEBITO: "CARTAO_DEBITO"
    };

    // Máscaras: "9" aceita só dígito; "_" é o marcador de posição vazia
    const MASCARA = {
        CARTAO: "9999 9999 9999 9999",
        VALIDADE: "99/99",
        CVV: "999"
    };

    /** Texto do i18n do app. */
    function texto(oExtensionAPI, sChave, aParametros) {
        return oExtensionAPI.getModel("i18n").getResourceBundle().getText(sChave, aParametros);
    }

    /** Contextos da ação: linhas selecionadas (tabela) ou o objeto da página. */
    function contextos(oContexto, aSelecionados) {
        if (aSelecionados && aSelecionados.length) {
            return aSelecionados;
        }
        return oContexto ? [oContexto] : [];
    }

    /**
     * Instância ativa (não rascunho) em que o feature control do RAP
     * (features : instance → __OperationControl) permite a action.
     */
    function acaoPermitida(oContexto, sAction) {
        return !!oContexto
            && oContexto.getProperty("IsActiveEntity") === true
            && oContexto.getProperty("__OperationControl/" + sAction) === true;
    }

    /** Somente dígitos (remove espaços e marcadores da máscara). */
    function digitos(sValor) {
        return (sValor || "").replace(/\D/g, "");
    }

    /** Números dos pedidos para as mensagens de confirmação. */
    function numeros(aContextos) {
        return aContextos.map((oContexto) => oContexto.getProperty("NumeroPedido")).join(", ");
    }

    /** Campo com máscara; a regra padrão "9" do MaskInput aceita apenas dígitos. */
    function campoComMascara(sMascara, sPlaceholder) {
        return new MaskInput({
            mask: sMascara,
            placeholderSymbol: "_",
            placeholder: sPlaceholder
        });
    }

    /**
     * Executa SimularPagamento com os valores do diálogo, sem o diálogo de
     * parâmetros padrão (os valores já foram informados e confirmados).
     */
    function executarPagamento(oExtensionAPI, oContexto, oDados) {
        return oExtensionAPI.editFlow.invokeAction(SERVICO + "SimularPagamento", {
            contexts: oContexto,
            model: oContexto.getModel(),
            label: texto(oExtensionAPI, "acaoEfetuarPagamento"),
            skipParameterDialog: true,
            parameterValues: [
                { name: "MetodoPagamento", value: oDados.metodo },
                { name: "NumeroCartao", value: oDados.numero },
                { name: "Validade", value: oDados.validade },
                { name: "Cvv", value: oDados.cvv }
            ]
        });
    }

    /**
     * Diálogo de pagamento com máscaras. Ao confirmar os dados, pede a
     * confirmação do pagamento e só então executa a action.
     */
    function abrirDialogoPagamento(oExtensionAPI, oContexto) {
        const oMetodo = new Select({
            width: "100%",
            items: [
                new Item({ key: METODO.CREDITO, text: texto(oExtensionAPI, "metodoCredito") }),
                new Item({ key: METODO.DEBITO, text: texto(oExtensionAPI, "metodoDebito") })
            ]
        });
        const oNumero = campoComMascara(MASCARA.CARTAO, texto(oExtensionAPI, "placeholderCartao"));
        const oValidade = campoComMascara(MASCARA.VALIDADE, texto(oExtensionAPI, "placeholderValidade"));
        const oCvv = campoComMascara(MASCARA.CVV, texto(oExtensionAPI, "placeholderCvv"));

        const oDialogo = new Dialog({
            title: texto(oExtensionAPI, "tituloPagamento", [oContexto.getProperty("NumeroPedido")]),
            contentWidth: "28rem",
            content: [
                new SimpleForm({
                    editable: true,
                    layout: "ResponsiveGridLayout",
                    labelSpanL: 4,
                    labelSpanM: 4,
                    content: [
                        new Label({ text: texto(oExtensionAPI, "campoMetodo"), labelFor: oMetodo, required: true }),
                        oMetodo,
                        new Label({ text: texto(oExtensionAPI, "campoCartao"), labelFor: oNumero, required: true }),
                        oNumero,
                        new Label({ text: texto(oExtensionAPI, "campoValidade"), labelFor: oValidade, required: true }),
                        oValidade,
                        new Label({ text: texto(oExtensionAPI, "campoCvv"), labelFor: oCvv, required: true }),
                        oCvv
                    ]
                })
            ],
            beginButton: new Button({
                text: texto(oExtensionAPI, "botaoPagar"),
                type: "Emphasized",
                press: function () {
                    const oDados = {
                        metodo: oMetodo.getSelectedKey(),
                        numero: digitos(oNumero.getValue()),
                        validade: oValidade.getValue().replace(/_/g, ""),
                        cvv: digitos(oCvv.getValue())
                    };

                    MessageBox.confirm(texto(oExtensionAPI, "confirmarPagamento", [oContexto.getProperty("NumeroPedido")]), {
                        title: texto(oExtensionAPI, "tituloConfirmacao"),
                        emphasizedAction: MessageBox.Action.OK,
                        onClose: function (sAcao) {
                            if (sAcao !== MessageBox.Action.OK) {
                                return;
                            }
                            oDialogo.close();
                            // Erros (precheck/validação) são exibidos pelo próprio Fiori Elements
                            executarPagamento(oExtensionAPI, oContexto, oDados).catch(function () {});
                        }
                    });
                }
            }),
            endButton: new Button({
                text: texto(oExtensionAPI, "botaoCancelar"),
                press: function () {
                    oDialogo.close();
                }
            }),
            afterClose: function () {
                // Dados do cartão não ficam em memória depois do diálogo
                oDialogo.destroy();
            }
        });

        oExtensionAPI.addDependent(oDialogo);
        oDialogo.open();
    }

    return {

        /** Efetuar Pagamento: um pedido ativo em ABERTO por vez. */
        efetuarPagamento: function (oContexto, aSelecionados) {
            const aContextos = contextos(oContexto, aSelecionados);
            if (aContextos.length !== 1) {
                MessageBox.warning(texto(this, "pagamentoUmPedido"));
                return;
            }
            abrirDialogoPagamento(this, aContextos[0]);
        },

        /** Habilita Efetuar Pagamento na tabela: exatamente um pedido com SimularPagamento permitido. */
        podePagar: function (oContexto, aSelecionados) {
            return !!aSelecionados && aSelecionados.length === 1
                && acaoPermitida(aSelecionados[0], "SimularPagamento");
        },

        /**
         * Cancelar pedido: confirma e então executa CancelarPedido, que abre o
         * diálogo padrão do motivo do cancelamento (parâmetro obrigatório).
         */
        cancelarPedido: function (oContexto, aSelecionados) {
            const aContextos = contextos(oContexto, aSelecionados);
            if (!aContextos.length) {
                return;
            }

            MessageBox.confirm(texto(this, "confirmarCancelamento", [numeros(aContextos)]), {
                title: texto(this, "tituloConfirmacao"),
                emphasizedAction: MessageBox.Action.OK,
                onClose: (sAcao) => {
                    if (sAcao !== MessageBox.Action.OK) {
                        return;
                    }
                    // Erros do backend são exibidos pelo próprio Fiori Elements
                    this.editFlow.invokeAction(SERVICO + "CancelarPedido", {
                        contexts: aContextos.length === 1 ? aContextos[0] : aContextos,
                        model: aContextos[0].getModel(),
                        label: texto(this, "acaoCancelarPedido")
                    }).catch(function () {});
                }
            });
        },

        /** Habilita Cancelar pedido na tabela: todos os pedidos com CancelarPedido permitido. */
        podeCancelar: function (oContexto, aSelecionados) {
            return !!aSelecionados && aSelecionados.length > 0
                && aSelecionados.every((oSelecionado) => acaoPermitida(oSelecionado, "CancelarPedido"));
        }
    };
});
