@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Clientes - cubo analítico'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #CUBE
@ObjectModel.modelingPattern: #ANALYTICAL_CUBE
@ObjectModel.supportedCapabilities: [ #ANALYTICAL_PROVIDER ]

define view entity ZI_PC_CLIENTE_CUBE
  as select from ZR_PC_CLIENTE
{
  key ClienteUUID,
      Nome,

      @ObjectModel.text.element: [ 'GeneroTexto' ]
      Genero,
      _GeneroTxt.Descricao                as GeneroTexto,

      ClienteAtivo,
      _EnderecoPrincipal.Uf               as Uf,

      /* Faixa do score: BAIXO (até 40), MEDIO (até 70), ALTO (acima de 70) */
      cast( case when ScoreCliente < 40 then 'BAIXO'
                  when ScoreCliente <= 70 then 'MEDIO'
                  else 'ALTO' end as abap.char(5) ) as FaixaScore,

      @Semantics.calendar.yearMonth: true
      cast( left( cast( tstmp_to_dats( cast( CreatedAt as abap.dec(15,0) ), 'UTC', $session.client, 'NULL' ) as abap.char(8) ), 6 ) as abap.numc(6) ) as MesCadastro,

      @Aggregation.default: #SUM
      cast( 1 as abap.int4 )              as QtdeClientes,

      @Aggregation.default: #AVG
      ScoreCliente                        as ScoreMedio
}
