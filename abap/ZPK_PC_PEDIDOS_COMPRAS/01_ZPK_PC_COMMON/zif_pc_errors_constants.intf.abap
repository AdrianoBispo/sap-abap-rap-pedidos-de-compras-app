"! <p class="shorttext synchronized"> Interface - Constantes de Erros</p>
INTERFACE zif_pc_errors_constants PUBLIC.

    CONSTANTS:
      "! 001 - CPF inválido. Verifique o número informado.
      BEGIN OF cliente_cpf_invalido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cliente_cpf_invalido,

      "! 002 - Já existe um cliente cadastrado com este CPF.
      BEGIN OF cliente_cpf_duplicado,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cliente_cpf_duplicado,

      "! 003 - Cliente inativo não pode realizar pedido.
      BEGIN OF cliente_inativo,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cliente_inativo,

      "! 004 - Cliente não pode ser excluído pois possui pedido vinculado.
      BEGIN OF cliente_com_pedido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cliente_com_pedido,

      "! 005 - Cliente selecionado não possui endereço principal válido.
      BEGIN OF cliente_sem_endereco_principal,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cliente_sem_endereco_principal,

      "! 006 - Não foi possível validar o CEP agora. Tente novamente em instantes.
      BEGIN OF cep_indisponivel,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '006',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cep_indisponivel,
      
      "! 007 - CEP inválido ou não encontrado. Verifique o número informado.
      BEGIN OF cep_invalido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '007',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cep_invalido,

      "! 008 - Número do endereço é obrigatório.
      BEGIN OF endereco_numero_obrigatorio,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '008',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF endereco_numero_obrigatorio,

      "! 009 - Formato de imagem inválido. Utilize JPEG ou PNG.
      BEGIN OF foto_formato_invalido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '009',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF foto_formato_invalido,

      "! 010 - Já existe item cadastrado com este SKU.
      BEGIN OF item_sku_duplicado,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '010',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_sku_duplicado,

      "! 011 - Estoque insuficiente para o item &1 (disponível: &2).
      BEGIN OF item_estoque_insuficiente,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE 'MV_ATTR2',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_estoque_insuficiente,

      "! 012 - Estoque do item &1 alterado por outra operação. Atualize e tente de novo.
      BEGIN OF item_estoque_concorrente,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '012',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_estoque_concorrente,

      "! 013 - Item &1 inativo não pode ser usado em novo pedido.
      BEGIN OF item_inativo,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '013',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_inativo,

      "! 014 - Item possui estoque disponível ou pedido ativo. Inativação bloqueada.
      BEGIN OF item_inativacao_bloqueada,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '014',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_inativacao_bloqueada,

      "! 015 - Transição de status não permitida (status atual: &1).
      BEGIN OF pedido_status_invalido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '015',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_status_invalido,

      "! 016 - Pagamento pendente. O pedido não pode ser finalizado.
      BEGIN OF pedido_pagamento_pendente,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '016',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_pagamento_pendente,

      "! 017 - Pedido finalizado não pode ser alterado.
      BEGIN OF pedido_finalizado_imutavel,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '017',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_finalizado_imutavel,

      "! 018 - Pedido cancelado não pode ser alterado.
      BEGIN OF pedido_cancelado_imutavel,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '018',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_cancelado_imutavel,

      "! 019 - Informe o motivo do cancelamento.
      BEGIN OF pedido_motivo_cancel_obrig,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '019',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_motivo_cancel_obrig,

      "! 020 - Pagamento aprovado com sucesso.
      BEGIN OF pagamento_aprovado,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '020',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pagamento_aprovado,

      "! 021 - Pagamento recusado. O pedido permanecerá aguardando pagamento.
      BEGIN OF pagamento_recusado,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '021',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pagamento_recusado,

      "! 022 - Snapshot do pedido já foi gerado e não pode ser recriado.
      BEGIN OF snapshot_existente,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '022',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF snapshot_existente,

      "! 023 - Campo &1 é obrigatório.
      BEGIN OF campo_obrigatorio,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '023',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF campo_obrigatorio,

      "! 024 - E-mail em formato inválido.
      BEGIN OF email_invalido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '024',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF email_invalido,

      "! 025 - Data de nascimento não pode ser futura.
      BEGIN OF data_nascimento_futura,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '025',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF data_nascimento_futura,

      "! 026 - Telefone deve conter 10 ou 11 dígitos (DDD + número).
      BEGIN OF telefone_invalido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '026',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF telefone_invalido,

      "! 027 - Pedido deve possuir ao menos um item.
      BEGIN OF pedido_sem_itens,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '027',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_sem_itens,

      "! 028 - Quantidade do item deve ser maior que zero.
      BEGIN OF item_qtde_invalida,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '028',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_qtde_invalida,

      "! 029 - Preço unitário deve ser maior ou igual a zero.
      BEGIN OF item_preco_invalido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '029',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_preco_invalido,

      "! 030 - Qtde em estoque não pode ser negativa nem menor que a reservada (&1).
      BEGIN OF item_qtde_estoque_invalida,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '030',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_qtde_estoque_invalida,

      "! 031 - Item não pode ser excluído pois está vinculado a pedido ou reserva.
      BEGIN OF item_exclusao_bloqueada,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '031',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_exclusao_bloqueada,

      "! 032 - Dados do cartão inválidos: &1.
      BEGIN OF cartao_dados_invalidos,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '032',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF cartao_dados_invalidos,

      "! 033 - Pedido &1 confirmado. Estoque reservado.
      BEGIN OF pedido_confirmado,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '033',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_confirmado,

      "! 034 - Pedido &1 finalizado com sucesso.
      BEGIN OF pedido_finalizado,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '034',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_finalizado,

      "! 035 - Pedido &1 cancelado.
      BEGIN OF pedido_cancelado,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '035',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_cancelado,

      "! 036 - Erro ao obter numeração (&1). Verifique o intervalo de numeração.
      BEGIN OF numeracao_erro,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '036',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF numeracao_erro,

      "! 037 - Usuário sem autorização para esta operação.
      BEGIN OF sem_autorizacao,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '037',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF sem_autorizacao,

      "! 038 - Reserva do item &1 inconsistente com o pedido.
      BEGIN OF item_reserva_inconsistente,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '038',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_reserva_inconsistente,

      "! 039 - Pedido só pode ser editado ou excluído no status CRIADO.
      BEGIN OF pedido_edicao_bloqueada,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '039',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF pedido_edicao_bloqueada,

      "! 040 - Peso e dimensões não podem ser negativos.
      BEGIN OF item_dimensao_invalida,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '040',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF item_dimensao_invalida,

      "! 041 - Valor inválido para o campo &1.
      BEGIN OF valor_invalido,
        msgid TYPE symsgid VALUE 'ZPC_MSG',
        msgno TYPE symsgno VALUE '041',
        attr1 TYPE scx_attrname VALUE 'MV_ATTR1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF valor_invalido.

ENDINTERFACE.