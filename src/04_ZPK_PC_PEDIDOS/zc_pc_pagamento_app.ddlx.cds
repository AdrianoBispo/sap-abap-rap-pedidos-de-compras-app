@Metadata.layer: #CORE
@UI: {
  headerInfo: { typeName:       'Pagamento',
                typeNamePlural: 'Pagamentos',
                title:          { type: #STANDARD, value: 'CartaoMascarado' },
                description:    { type: #STANDARD, value: 'StatusPagamento' } }
}
annotate entity ZC_PC_PAGAMENTO_APP with
{
  @UI.facet: [
    { id: 'DadosPagamento', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Pagamento', position: 10 }
  ]

  @UI.hidden: true
  PagamentoUUID;
  @UI.hidden: true
  PedidoUUID;

  @UI: { lineItem: [{ position: 10, label: 'Método' }], identification: [{ position: 10, label: 'Método' }] }
  @EndUserText.label: 'Método'
  MetodoPagamento;
  @UI.hidden: true
  MetodoPagamentoTexto;

  @UI: { lineItem:       [{ position: 20, label: 'Status', criticality: 'StatusPagamentoCriticality' }],
         identification: [{ position: 20, label: 'Status', criticality: 'StatusPagamentoCriticality' }] }
  @EndUserText.label: 'Status'
  StatusPagamento;
  @UI.hidden: true
  StatusPagamentoTexto;
  @UI.hidden: true
  StatusPagamentoCriticality;

  @UI: { lineItem: [{ position: 30, label: 'Bandeira' }], identification: [{ position: 30, label: 'Bandeira' }] }
  @EndUserText.label: 'Bandeira'
  BandeiraCartao;

  @UI.hidden: true
  Ultimos4DigitosCartao;

  @UI: { lineItem: [{ position: 40, label: 'Cartão' }], identification: [{ position: 40, label: 'Cartão' }] }
  @EndUserText.label: 'Cartão'
  CartaoMascarado;

  @UI: { lineItem: [{ position: 50, label: 'Autorização' }], identification: [{ position: 50, label: 'Código de autorização' }] }
  @EndUserText.label: 'Código de autorização'
  CodigoAutorizacao;

  @UI: { lineItem: [{ position: 60, label: 'Mensagem' }], identification: [{ position: 60, label: 'Mensagem' }] }
  @EndUserText.label: 'Mensagem'
  MensagemPagamento;

  @UI: { lineItem: [{ position: 70, label: 'Data' }], identification: [{ position: 70, label: 'Data da tentativa' }] }
  @EndUserText.label: 'Data da tentativa'
  DataPagamento;

  @UI.hidden: true
  CreatedBy;
  @UI.hidden: true
  CreatedAt;
  @UI.hidden: true
  LastChangedBy;
  @UI.hidden: true
  LastChangedAt;
  @UI.hidden: true
  LocalLastChangedAt;
}
