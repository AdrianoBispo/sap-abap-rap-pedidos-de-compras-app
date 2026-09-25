@Metadata.layer: #CORE
@UI: {
  headerInfo: { typeName:       'Endereço',
                typeNamePlural: 'Endereços',
                title:          { type: #STANDARD, value: 'Logradouro' },
                description:    { type: #STANDARD, value: 'Cidade' } },
  presentationVariant: [{ sortOrder:      [{ by: 'EnderecoPrincipal', direction: #DESC }],
                          visualizations: [{ type: #AS_LINEITEM }] }]
}
annotate entity ZC_PC_ENDERECO_APP with
{
  @UI.facet: [
    { id: 'DadosEndereco', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
      label: 'Endereço', position: 10 }
  ]

  @UI.hidden: true
  EnderecoUUID;

  @UI.hidden: true
  ClienteUUID;

  // O CEP aparece no formulário "Endereço" (facet DadosEndereco), mas NÃO via
  // @UI.identification: é um campo customizado da extensão SAPUI5 da app de
  // Clientes (manifest.json > controlConfiguration > Identification > fields),
  // que normaliza a máscara, lê a custom entity CepLookUp e dispara a ação
  // AplicarDadosCep. Um DataField padrão para Cep criaria um segundo campo,
  // sem consulta. Pelo mesmo motivo Cep fica fora da tabela de endereços do
  // cliente: em modo de edição, uma coluna Cep editável mudaria o CEP sem
  // consulta (LimparDadosCep apaga os dados e ValidarCep bloqueia a ativação).
  @EndUserText.label: 'CEP'
  Cep;

  @UI: { lineItem:       [{ position: 20, label: 'Logradouro', importance: #HIGH }],
         identification: [{ position: 20, label: 'Logradouro' },
                          { type: #FOR_ACTION, dataAction: 'DefinirEnderecoPrincipal',
                            label: 'Definir como principal' }] }
  @EndUserText.label: 'Logradouro'
  Logradouro;

  @UI: { lineItem:       [{ position: 30, label: 'Número', importance: #HIGH }],
         identification: [{ position: 30, label: 'Número' }] }
  @EndUserText.label: 'Número'
  Numero;

  @UI: { lineItem:       [{ position: 40, label: 'Complemento' }],
         identification: [{ position: 40, label: 'Complemento' }] }
  @EndUserText.label: 'Complemento'
  Complemento;

  @UI: { lineItem:       [{ position: 50, label: 'Bairro' }],
         identification: [{ position: 50, label: 'Bairro' }] }
  @EndUserText.label: 'Bairro'
  Bairro;

  @UI: { lineItem:       [{ position: 60, label: 'Cidade' }],
         identification: [{ position: 60, label: 'Cidade' }] }
  @EndUserText.label: 'Cidade'
  Cidade;

  @UI: { lineItem:       [{ position: 70, label: 'UF' }],
         identification: [{ position: 70, label: 'UF' }] }
  @EndUserText.label: 'UF'
  Uf;

  @UI: { identification: [{ position: 80, label: 'Estado' }] }
  @EndUserText.label: 'Estado'
  Estado;

  @UI.hidden: true
  CepGeral;

  // Campos técnicos consumidos pela extensão SAPUI5, ocultos no formulário.
  // ConsultedCep é a coluna "CEP" da tabela: é somente leitura e, depois da
  // ativação, sempre igual a Cep (ValidarCep garante).
  @UI.hidden: true
  CepStatus;

  @UI: { lineItem: [{ position: 10, label: 'CEP', importance: #HIGH },
                    { type: #FOR_ACTION, dataAction: 'DefinirEnderecoPrincipal',
                      label: 'Definir como principal' }] }
  @EndUserText.label: 'CEP'
  ConsultedCep;

  @UI: { lineItem:       [{ position: 80, label: 'Principal', importance: #HIGH }],
         identification: [{ position: 90, label: 'Endereço principal' }] }
  @EndUserText.label: 'Principal'
  EnderecoPrincipal;

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
