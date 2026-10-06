@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pedidos de Compras - Cliente Root View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZR_PC_CLIENTE
  as select from zta_pc_cliente
  composition [0..*] of ZR_PC_ENDERECO as _Endereco
  association [0..1] to ZR_PC_ENDERECO as _EnderecoPrincipal on  _EnderecoPrincipal.ClienteUUID       = $projection.ClienteUUID
                                                             and _EnderecoPrincipal.EnderecoPrincipal = 'X'
  association [0..1] to ZR_PC_CODELIST as _GeneroTxt on  _GeneroTxt.Lista  = 'GENERO'
                                                    and _GeneroTxt.Codigo = $projection.Genero
{
  key cliente_uuid          as ClienteUUID,
      @Semantics.largeObject: { mimeType: 'FotoMimeType',
                                fileName: 'FotoFileName',
                                acceptableMimeTypes: [ 'image/jpeg', 'image/png', 'image/webp' ],
                                contentDispositionPreference: #INLINE }
      foto_cliente          as FotoCliente,
      @Semantics.mimeType: true
      foto_mime_type        as FotoMimeType,
      foto_file_name        as FotoFileName,
      cpf                   as Cpf,
      nome                  as Nome,
      email                 as Email,
      telefone              as Telefone,
      genero                as Genero,
      data_nascimento       as DataNascimento,
      cliente_ativo         as ClienteAtivo,
      score_cliente         as ScoreCliente,
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
      _Endereco,
      _EnderecoPrincipal,
      _GeneroTxt
}
