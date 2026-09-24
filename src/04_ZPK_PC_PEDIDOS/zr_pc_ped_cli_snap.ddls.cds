@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Snapshot do cliente - BO child'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_PC_PED_CLI_SNAP
  as select from zta_pc_snap_cli
  association to parent ZR_PC_PEDIDO as _Pedido on $projection.PedidoUUID = _Pedido.PedidoUUID
{
  key snapshot_uuid         as SnapshotUUID,
      pedido_uuid           as PedidoUUID,
      cliente_uuid          as ClienteUUID,
      cpf                   as Cpf,
      nome                  as Nome,
      email                 as Email,
      telefone              as Telefone,
      genero                as Genero,
      data_nascimento       as DataNascimento,
      cliente_ativo         as ClienteAtivo,
      score_cliente         as ScoreCliente,
      endereco_uuid         as EnderecoUUID,
      cep                   as Cep,
      logradouro            as Logradouro,
      numero                as Numero,
      complemento           as Complemento,
      bairro                as Bairro,
      cidade                as Cidade,
      uf                    as Uf,
      estado                as Estado,
      endereco_completo     as EnderecoCompleto,
      motivo_snapshot       as MotivoSnapshot,
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
      _Pedido
}
