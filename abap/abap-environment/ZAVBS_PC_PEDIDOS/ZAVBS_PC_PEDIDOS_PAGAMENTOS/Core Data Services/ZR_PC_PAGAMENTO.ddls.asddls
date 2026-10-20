@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pagamento do pedido - BO child'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_PC_PAGAMENTO
  as select from zta_pc_pagamento
  association to parent ZR_PC_PEDIDO as _Pedido on $projection.PedidoUUID = _Pedido.PedidoUUID
  association [0..1] to ZR_PC_CODELIST as _MetodoTxt on  _MetodoTxt.Lista  = 'METODO_PAGAMENTO'
                                                    and _MetodoTxt.Codigo = $projection.MetodoPagamento
  association [0..1] to ZR_PC_CODELIST as _StatusTxt on  _StatusTxt.Lista  = 'STATUS_PAGAMENTO'
                                                    and _StatusTxt.Codigo = $projection.StatusPagamento
{
  key pagamento_uuid        as PagamentoUUID,
      pedido_uuid           as PedidoUUID,
      metodo_pagamento      as MetodoPagamento,
      status_pagamento      as StatusPagamento,
      bandeira_cartao       as BandeiraCartao,
      ultimos4_digitos      as Ultimos4DigitosCartao,
      cartao_mascarado      as CartaoMascarado,
      codigo_autorizacao    as CodigoAutorizacao,
      mensagem_pagamento    as MensagemPagamento,
      data_pagamento        as DataPagamento,
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
      _Pedido,
      _MetodoTxt,
      _StatusTxt
}
