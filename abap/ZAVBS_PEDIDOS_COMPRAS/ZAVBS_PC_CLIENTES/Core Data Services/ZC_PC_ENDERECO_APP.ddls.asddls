@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Endereço - Projection (App Gestão de Clientes)'
@Metadata.allowExtensions: true

/* Projeção do endereço (child) do BO ZR_PC_CLIENTE para o app Gestão de
   Clientes. Expõe os dados do endereço (CEP, logradouro, cidade, UF etc.), a
   indicação de endereço principal e a associação ao cliente pai
   (ZC_PC_CLIENTE_APP). O comportamento está em ZC_PC_CLIENTE_APP (bdef). */
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
      
      /* Campos de auditoria e de controle do RAP */
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associações */
      _Cliente : redirected to parent ZC_PC_CLIENTE_APP
}
