*&---------------------------------------------------------------------*
*& Report ZPC_TESTE_VIACEP
*&---------------------------------------------------------------------*
*& Pedidos de Compras - teste da destination Z_VIACEP (On-Premise).
*& Executar (F8) em cada sistema depois de configurar SM59 e STRUST, antes
*& de testar o cadastro de endereço na app Gestão de Clientes.
*& Pacote ZAVBS_PC_COMMON_T2 (Standard ABAP); não transportar para PRD se a
*& política do landscape proibir reports de teste.
*&---------------------------------------------------------------------*
REPORT zpc_teste_viacep.

PARAMETERS p_cep TYPE c LENGTH 9 DEFAULT '01310-100'.

START-OF-SELECTION.
  DATA(ls_resultado) = zcl_pc_viacep=>consultar( p_cep ).

  IF ls_resultado-indisponivel = abap_true.
    WRITE: / 'Serviço indisponível.',
           / 'Status HTTP:', ls_resultado-status_http,
           / 'Detalhe:', ls_resultado-mensagem_erro.
    RETURN.
  ENDIF.

  IF ls_resultado-valido = abap_false.
    WRITE: / 'CEP inválido ou inexistente.',
           / 'Status HTTP:', ls_resultado-status_http,
           / 'Detalhe:', ls_resultado-mensagem_erro.
    RETURN.
  ENDIF.

  WRITE: / 'CEP:',         ls_resultado-endereco-cep,
         / 'Logradouro:',  ls_resultado-endereco-logradouro,
         / 'Complemento:', ls_resultado-endereco-complemento,
         / 'Bairro:',      ls_resultado-endereco-bairro,
         / 'Cidade:',      ls_resultado-endereco-localidade,
         / 'UF:',          ls_resultado-endereco-uf,
         / 'Estado:',      ls_resultado-endereco-estado,
         / 'CEP geral:',   ls_resultado-cep_geral,
         / 'HTTP:',        ls_resultado-status_http.
