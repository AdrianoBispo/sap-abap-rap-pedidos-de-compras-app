@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Endereço - Projection (App Gestão de Clientes)'
@Metadata.allowExtensions: true

define view entity ZC_PC_ENDERECO_APP
  as projection on ZR_PC_ENDERECO
{
  key EnderecoUUID,
      ClienteUUID,

      /* Sugere os CEPs já cadastrados; um CEP novo pode ser digitado e é
         consultado no ViaCEP pela determination PreencherEnderecoViaCep. */
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_PC_CEP_VH', element: 'Cep' } }]
      Cep,
      Logradouro,
      Numero,
      Complemento,
      Bairro,
      Cidade,
      Uf,
      Estado,
      CepGeral,
      CepStatus,
      EnderecoPrincipal,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Cliente : redirected to parent ZC_PC_CLIENTE_APP
}
