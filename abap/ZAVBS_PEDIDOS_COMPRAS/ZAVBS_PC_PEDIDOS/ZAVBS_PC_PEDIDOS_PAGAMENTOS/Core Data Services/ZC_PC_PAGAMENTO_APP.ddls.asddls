@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pagamento - Projection (somente leitura)'
@Metadata.allowExtensions: true
define view entity ZC_PC_PAGAMENTO_APP
  as projection on ZR_PC_PAGAMENTO
{
  key PagamentoUUID,
      PedidoUUID,

      @ObjectModel.text.element: [ 'MetodoPagamentoTexto' ]
      @UI.textArrangement: #TEXT_ONLY
      MetodoPagamento,
      _MetodoTxt.Descricao  as MetodoPagamentoTexto,

      @ObjectModel.text.element: [ 'StatusPagamentoTexto' ]
      @UI.textArrangement: #TEXT_ONLY
      StatusPagamento,
      _StatusTxt.Descricao  as StatusPagamentoTexto,
      _StatusTxt.Criticality as StatusPagamentoCriticality,

      BandeiraCartao,
      Ultimos4DigitosCartao,
      CartaoMascarado,
      CodigoAutorizacao,
      MensagemPagamento,
      DataPagamento,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Pedido : redirected to parent ZC_PC_PEDIDO_APP
}
