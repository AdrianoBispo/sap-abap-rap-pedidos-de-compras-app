@Metadata.layer: #CORE
@UI: {
  headerInfo: { typeName:       'Cliente',
                typeNamePlural: 'Clientes',
                title:          { type: #STANDARD, value: 'Nome' },
                description:    { type: #STANDARD, value: 'CpfFormatado' },
                imageUrl:       'FotoCliente' },
  presentationVariant: [{ sortOrder:      [{ by: 'Nome', direction: #ASC }],
                          visualizations: [{ type: #AS_LINEITEM }] }]
}
annotate entity ZC_PC_CLIENTE_APP with
{
  @UI.facet: [
    { id: 'DadosCliente',   purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
      label: 'Dados do cliente', position: 10 },
    { id: 'Enderecos',      purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: 'Endereços', position: 20, targetElement: '_Endereco' },
    { id: 'Administrativo', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
      label: 'Dados administrativos', position: 30, targetQualifier: 'Admin' }
  ]

  @UI.hidden: true
  ClienteUUID;

  @UI: { lineItem:       [{ position: 10, label: 'Foto', importance: #HIGH }],
         identification: [{ position: 10, label: 'Foto (JPEG ou PNG)' }] }
  FotoCliente;

  @UI.hidden: true
  FotoMimeType;

  @UI.hidden: true
  FotoFileName;

  @UI: { identification: [{ position: 20, label: 'CPF (somente números)' }],
         selectionField: [{ position: 20 }] }
  @EndUserText.label: 'CPF'
  Cpf;

  @UI: { lineItem: [{ position: 20, label: 'CPF', importance: #HIGH }] }
  CpfFormatado;

  @UI: { lineItem:       [{ position: 30, label: 'Nome', importance: #HIGH }],
         identification: [{ position: 30, label: 'Nome completo' }],
         selectionField: [{ position: 10 }] }
  @EndUserText.label: 'Nome'
  Nome;

  @UI: { lineItem:       [{ position: 40, label: 'E-mail' }],
         identification: [{ position: 40, label: 'E-mail' }],
         selectionField: [{ position: 30 }] }
  @EndUserText.label: 'E-mail'
  Email;

  @UI: { identification: [{ position: 50, label: 'Telefone (DDD + número)' }] }
  @EndUserText.label: 'Telefone'
  Telefone;

  @UI: { lineItem: [{ position: 50, label: 'Telefone' }] }
  TelefoneFormatado;

  @UI: { identification: [{ position: 60, label: 'Gênero' }] }
  @EndUserText.label: 'Gênero'
  Genero;

  @UI.hidden: true
  GeneroTexto;

  @UI: { identification: [{ position: 70, label: 'Data de nascimento' }] }
  @EndUserText.label: 'Data de nascimento'
  DataNascimento;

  @UI: { lineItem:       [{ position: 60, label: 'Ativo', importance: #HIGH }],
         identification: [{ position: 80, label: 'Cliente ativo' }],
         selectionField: [{ position: 40 }] }
  @EndUserText.label: 'Ativo'
  ClienteAtivo;

  @UI: { identification: [{ position: 90, label: 'Score' }] }
  @EndUserText.label: 'Score'
  ScoreCliente;

  @UI: { lineItem:       [{ position: 70, label: 'Cidade' }],
         selectionField: [{ position: 50 }] }
  @EndUserText.label: 'Cidade'
  CidadePrincipal;

  @UI: { lineItem:       [{ position: 80, label: 'UF' }],
         selectionField: [{ position: 60 }] }
  @EndUserText.label: 'UF'
  UfPrincipal;

  @UI: { lineItem:   [{ position: 90, label: 'Data de cadastro' }],
         fieldGroup: [{ qualifier: 'Admin', position: 10, label: 'Criado em' }] }
  CreatedAt;

  @UI.fieldGroup: [{ qualifier: 'Admin', position: 20, label: 'Criado por' }]
  CreatedBy;

  @UI.fieldGroup: [{ qualifier: 'Admin', position: 30, label: 'Alterado em' }]
  LastChangedAt;

  @UI.fieldGroup: [{ qualifier: 'Admin', position: 40, label: 'Alterado por' }]
  LastChangedBy;

  @UI.hidden: true
  LocalLastChangedAt;
}
