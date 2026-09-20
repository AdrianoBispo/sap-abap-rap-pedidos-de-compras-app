@Metadata.layer: #CORE
@UI: {
  headerInfo: { typeName:       'Snapshot do cliente',
                typeNamePlural: 'Snapshots do cliente',
                title:          { type: #STANDARD, value: 'Nome' },
                description:    { type: #STANDARD, value: 'Cpf' } }
}
annotate entity ZC_PC_PED_CLI_SNAP_APP with
{
  @UI.facet: [
    { id: 'Historico', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
      label: 'Dados congelados no encerramento (somente leitura)', position: 10 }
  ]

  @UI.hidden: true
  SnapshotUUID;

  @UI.hidden: true
  PedidoUUID;

  @UI.hidden: true
  ClienteUUID;

  @UI: { lineItem: [{ position: 10, label: 'CPF' }],
         identification: [{ position: 10, label: 'CPF' }] }
  @EndUserText.label: 'CPF'
  Cpf;

  @UI: { lineItem: [{ position: 20, label: 'Nome' }],
         identification: [{ position: 20, label: 'Nome' }] }
  @EndUserText.label: 'Nome'
  Nome;

  @UI: { lineItem: [{ position: 30, label: 'E-mail' }],
         identification: [{ position: 30, label: 'E-mail' }] }
  @EndUserText.label: 'E-mail'
  Email;

  @UI: { lineItem: [{ position: 40, label: 'Telefone' }],
         identification: [{ position: 40, label: 'Telefone' }] }
  @EndUserText.label: 'Telefone'
  Telefone;

  @UI: { identification: [{ position: 50, label: 'Gênero' }] }
  @EndUserText.label: 'Gênero'
  Genero;

  @UI: { identification: [{ position: 60, label: 'Data de nascimento' }] }
  @EndUserText.label: 'Data de nascimento'
  DataNascimento;

  @UI: { identification: [{ position: 70, label: 'Ativo no encerramento' }] }
  @EndUserText.label: 'Ativo no encerramento'
  ClienteAtivo;

  @UI: { identification: [{ position: 80, label: 'Score' }] }
  @EndUserText.label: 'Score'
  ScoreCliente;

  @UI.hidden: true
  EnderecoUUID;

  @UI: { identification: [{ position: 90, label: 'CEP' }] }
  @EndUserText.label: 'CEP'
  Cep;

  @UI: { identification: [{ position: 100, label: 'Logradouro' }] }
  @EndUserText.label: 'Logradouro'
  Logradouro;

  @UI: { identification: [{ position: 110, label: 'Número' }] }
  @EndUserText.label: 'Número'
  Numero;

  @UI: { identification: [{ position: 120, label: 'Complemento' }] }
  @EndUserText.label: 'Complemento'
  Complemento;

  @UI: { identification: [{ position: 130, label: 'Bairro' }] }
  @EndUserText.label: 'Bairro'
  Bairro;

  @UI: { identification: [{ position: 140, label: 'Cidade' }] }
  @EndUserText.label: 'Cidade'
  Cidade;

  @UI: { identification: [{ position: 150, label: 'UF' }] }
  @EndUserText.label: 'UF'
  Uf;

  @UI: { identification: [{ position: 160, label: 'Estado' }] }
  @EndUserText.label: 'Estado'
  Estado;

  @UI: { lineItem: [{ position: 50, label: 'Endereço completo' }],
         identification: [{ position: 170, label: 'Endereço completo' }] }
  @EndUserText.label: 'Endereço completo'
  EnderecoCompleto;

  @UI: { lineItem: [{ position: 60, label: 'Motivo' }],
         identification: [{ position: 180, label: 'Motivo' }] }
  @EndUserText.label: 'Motivo'
  MotivoSnapshot;

  @UI.hidden: true
  CreatedBy;

  @UI: { lineItem: [{ position: 70, label: 'Gerado em' }],
         identification: [{ position: 190, label: 'Gerado em' }] }
  @EndUserText.label: 'Gerado em'
  CreatedAt;

  @UI.hidden: true
  LastChangedBy;

  @UI.hidden: true
  LastChangedAt;

  @UI.hidden: true
  LocalLastChangedAt;
}
