@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Snapshot do cliente - Projection (somente leitura)'
@Metadata.allowExtensions: true
define view entity ZC_PC_PED_CLI_SNAP_APP
  as projection on ZR_PC_PED_CLI_SNAP
{
  key SnapshotUUID,
      PedidoUUID,
      /* Navegação entre apps (FLP): nome e CPF do snapshot abrem o cliente
         na app Gestão de Clientes (pedidos FINALIZADO/CANCELADO) */
      @Consumption.semanticObject: 'ZPCCliente'
      ClienteUUID,
      @Consumption.semanticObject: 'ZPCCliente'
      Cpf,
      @Consumption.semanticObject: 'ZPCCliente'
      Nome,
      Email,
      Telefone,
      Genero,
      DataNascimento,
      ClienteAtivo,
      ScoreCliente,
      EnderecoUUID,
      Cep,
      Logradouro,
      Numero,
      Complemento,
      Bairro,
      Cidade,
      Uf,
      Estado,
      EnderecoCompleto,
      MotivoSnapshot,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Pedido : redirected to parent ZC_PC_PEDIDO_APP
}
