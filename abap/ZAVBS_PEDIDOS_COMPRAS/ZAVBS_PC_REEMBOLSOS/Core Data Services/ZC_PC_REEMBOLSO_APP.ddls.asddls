@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reembolso - Projection (App Gestão de Reembolsos)'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'NumeroPedido' ]
define root view entity ZC_PC_REEMBOLSO_APP
  provider contract transactional_query
  as projection on ZR_PC_REEMBOLSO
{
  key ReembolsoUUID,

      /* Navegação entre apps (FLP): o Pedido abre o pedido na app Pedidos de
         Compras (chave PedidoUUID; NumeroPedido é a chave semântica) */
      @Consumption.semanticObject: 'ZPCPedidoCompra'
      PedidoUUID,

      @Search.defaultSearchElement: true
      @Consumption.semanticObject: 'ZPCPedidoCompra'
      NumeroPedido,

      /* Navegação entre apps (FLP): Cliente e CPF abrem o cliente na app
         Gestão de Clientes (chave ClienteUUID; CpfCliente vai como Cpf) */
      @Consumption.semanticObject: 'ZPCCliente'
      @Consumption.semanticObjectMapping.additionalBinding: [{ localElement: 'CpfCliente', element: 'Cpf' }]
      @ObjectModel.text.element: [ 'NomeCliente' ]
      ClienteUUID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Consumption.semanticObject: 'ZPCCliente'
      @Consumption.semanticObjectMapping.additionalBinding: [{ localElement: 'CpfCliente', element: 'Cpf' }]
      _Cliente.Nome          as NomeCliente,
      @Search.defaultSearchElement: true
      @Consumption.semanticObject: 'ZPCCliente'
      @Consumption.semanticObjectMapping.additionalBinding: [{ localElement: 'CpfCliente', element: 'Cpf' }]
      _Cliente.Cpf           as CpfCliente,

      @ObjectModel.text.element: [ 'StatusReembolsoTexto' ]
      @UI.textArrangement: #TEXT_ONLY
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_STATUSREEMB_VH', element: 'Codigo' } }]
      StatusReembolso,
      _StatusTxt.Descricao   as StatusReembolsoTexto,
      _StatusTxt.Criticality as StatusReembolsoCriticality,

      StatusPedidoAnterior,

      Currency,
      ValorReembolso,

      @Search.defaultSearchElement: true
      MotivoSolicitacao,
      DataSolicitacao,
      SolicitadoPor,

      MotivoDecisao,
      DataDecisao,
      DecididoPor,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Cliente,
      _StatusTxt
}
