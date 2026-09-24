@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Endereço do cliente - BO child'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_PC_ENDERECO
  as select from za_pc_endereco
  association to parent ZR_PC_CLIENTE as _Cliente on $projection.ClienteUUID = _Cliente.ClienteUUID
{
  key endereco_uuid         as EnderecoUUID,
      cliente_uuid          as ClienteUUID,
      cep                   as Cep,
      logradouro            as Logradouro,
      numero                as Numero,
      complemento           as Complemento,
      bairro                as Bairro,
      cidade                as Cidade,
      uf                    as Uf,
      estado                as Estado,
      cep_geral             as CepGeral,
      cep_status            as CepStatus,
      endereco_principal    as EnderecoPrincipal,
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
      _Cliente
}
