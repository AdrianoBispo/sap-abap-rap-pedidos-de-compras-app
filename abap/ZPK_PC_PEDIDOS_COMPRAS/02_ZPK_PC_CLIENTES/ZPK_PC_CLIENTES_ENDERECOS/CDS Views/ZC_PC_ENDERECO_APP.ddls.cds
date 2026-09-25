@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Endereço - Projection (App Gestão de Clientes)'
@Metadata.allowExtensions: true
define view entity ZC_PC_ENDERECO_APP
  as projection on ZR_PC_ENDERECO
{
  key EnderecoUUID,
      ClienteUUID,
      Cep,
      Logradouro,
      Numero,
      Complemento,
      Bairro,
      Cidade,
      Uf,
      Estado,
      CepGeral,

      // Campos técnicos: expostos para a extensão SAPUI5 poder reagir ao
      // resultado da consulta do CEP. Ocultos no formulário pela Metadata
      // Extension; ConsultedCep é a coluna "CEP" da tabela de endereços.
      CepStatus,
      ConsultedCep,

      EnderecoPrincipal,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Cliente : redirected to parent ZC_PC_CLIENTE_APP
}
