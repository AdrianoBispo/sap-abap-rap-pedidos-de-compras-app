/**
 * Ações customizadas do app Gestão de Reembolsos (List Report e Object Page).
 *
 * Aprovar e Rejeitar reembolso têm o parâmetro MotivoDecisao: o Fiori Elements
 * não mostra o pop-up de confirmação (Common.IsActionCritical) em ações com
 * diálogo de parâmetros, por isso os botões padrão foram trocados por estes,
 * que pedem a confirmação e depois executam a action do RAP via
 * editFlow.invokeAction (que abre o diálogo padrão do motivo).
 * A DDLX ZC_PC_REEMBOLSO_APP agrupa Aprovar e Rejeitar no menu "Ações"
 * (AcoesReembolso), usado no Preview do serviço. Neste app o manifest
 * substitui os itens desse menu pelos botões daqui.
 *
 * Os handlers são chamados pelo Fiori Elements com this = ExtensionAPI.
 */
sap.ui.define([
    "sap/m/MessageBox"
], function (MessageBox) {
    "use strict";

    // Namespace do serviço OData V4 (ZUI_PC_REEMBOLSOS_O4)
    const SERVICO = "com.sap.gateway.srvd.zui_pc_reembolsos.v0001.";

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
     * Há seleção e o feature control do RAP (features : instance →
     * __OperationControl) permite a action em todas as solicitações.
     */
    function todasPermitem(aSelecionados, sAction) {
        return !!aSelecionados && aSelecionados.length > 0
            && aSelecionados.every((oSelecionado) => oSelecionado.getProperty("__OperationControl/" + sAction) === true);
    }

    /** Números dos pedidos das solicitações, para as mensagens de confirmação. */
    function numeros(aContextos) {
        return aContextos.map((oContexto) => oContexto.getProperty("NumeroPedido")).join(", ");
    }

    /**
     * Pede a confirmação e executa a action informada (Aprovar ou Rejeitar)
     * para todas as solicitações selecionadas.
     */
    function confirmarEExecutar(oExtensionAPI, aContextos, sAction, sChaveConfirmacao, sChaveRotulo) {
        if (!aContextos.length) {
            return;
        }

        MessageBox.confirm(texto(oExtensionAPI, sChaveConfirmacao, [numeros(aContextos)]), {
            title: texto(oExtensionAPI, "tituloConfirmacao"),
            emphasizedAction: MessageBox.Action.OK,
            onClose: function (sAcao) {
                if (sAcao !== MessageBox.Action.OK) {
                    return;
                }
                // Erros do backend são exibidos pelo próprio Fiori Elements
                oExtensionAPI.editFlow.invokeAction(SERVICO + sAction, {
                    contexts: aContextos.length === 1 ? aContextos[0] : aContextos,
                    model: aContextos[0].getModel(),
                    label: texto(oExtensionAPI, sChaveRotulo)
                }).catch(function () {});
            }
        });
    }

    return {

        /** Aprovar reembolso: confirma e executa AprovarReembolso. */
        aprovarReembolso: function (oContexto, aSelecionados) {
            confirmarEExecutar(this, contextos(oContexto, aSelecionados),
                "AprovarReembolso", "confirmarAprovacao", "acaoAprovarReembolso");
        },

        /** Rejeitar reembolso: confirma e executa RejeitarReembolso (motivo obrigatório). */
        rejeitarReembolso: function (oContexto, aSelecionados) {
            confirmarEExecutar(this, contextos(oContexto, aSelecionados),
                "RejeitarReembolso", "confirmarRejeicao", "acaoRejeitarReembolso");
        },

        /** Habilita Aprovar na tabela: todas as solicitações com AprovarReembolso permitido. */
        podeAprovar: function (oContexto, aSelecionados) {
            return todasPermitem(aSelecionados, "AprovarReembolso");
        },

        /** Habilita Rejeitar na tabela: todas as solicitações com RejeitarReembolso permitido. */
        podeRejeitar: function (oContexto, aSelecionados) {
            return todasPermitem(aSelecionados, "RejeitarReembolso");
        }
    };
});
