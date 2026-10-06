@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pedido de compra - BO root'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_PC_PEDIDO
  as select from zta_pc_pedido
  composition [0..*] of ZR_PC_ITEM_PEDIDO   as _Itens
  composition [0..1] of ZR_PC_PAGAMENTO     as _Pagamento
  composition [0..1] of ZR_PC_PED_CLI_SNAP  as _ClienteSnapshot
  composition [0..*] of ZR_PC_PED_ITEM_SNAP as _ItensSnapshot
  association [0..1] to ZR_PC_CLIENTE       as _Cliente  on $projection.ClienteUUID = _Cliente.ClienteUUID
  association [0..1] to ZR_PC_ENDERECO      as _Endereco on $projection.EnderecoUUID = _Endereco.EnderecoUUID
  association [0..1] to ZR_PC_CODELIST as _StatusPedidoTxt on  _StatusPedidoTxt.Lista  = 'STATUS_PEDIDO'
                                                          and _StatusPedidoTxt.Codigo = $projection.StatusPedido
  association [0..1] to ZR_PC_CODELIST as _StatusPagamentoTxt on  _StatusPagamentoTxt.Lista  = 'STATUS_PAGAMENTO'
                                                             and _StatusPagamentoTxt.Codigo = $projection.StatusPagamento
{
  key pedido_uuid           as PedidoUUID,
      numero_pedido         as NumeroPedido,
      cliente_uuid          as ClienteUUID,
      endereco_uuid         as EnderecoUUID,
      endereco_completo     as EnderecoPrincipalCompleto,
      status_pedido         as StatusPedido,
      status_pagamento      as StatusPagamento,

      /* Personalização dinâmica da Object Page (ver ZC_PC_PEDIDO_APP.ddlx):
         Itens (ativos) só faz sentido enquanto o pedido não foi encerrado;
         Histórico (snapshots) só existe a partir do encerramento. Mantidos
         como colunas físicas (determination AtualizarFlagsStatus) porque
         projections/CDS aqui não reconhecem CASE/CAST como Boolean para
         o annotation "hidden" do Fiori Elements. */
      pedido_encerrado      as PedidoEncerrado,
      pedido_ativo_sem_hist as PedidoAtivoSemHistorico,
      pedido_nao_finalizado as PedidoNaoFinalizado,
      pedido_nao_cancelado  as PedidoNaoCancelado,
      observacao            as Observacao,
      currency              as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      valor_total           as ValorTotal,
      data_finalizacao      as DataFinalizacao,
      motivo_cancelamento   as MotivoCancelamento,
      data_cancelamento     as DataCancelamento,
      cancelado_por         as CanceladoPor,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      /* Associações */
      _Itens,
      _Pagamento,
      _ClienteSnapshot,
      _ItensSnapshot,
      _Cliente,
      _Endereco,
      _StatusPedidoTxt,
      _StatusPagamentoTxt
}
