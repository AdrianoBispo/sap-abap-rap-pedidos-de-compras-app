# Tutorial: Migração da consulta ViaCEP do SAP BTP ABAP Environment para SAP On-Premise

## 1. Objetivo

Este tutorial mostra como migrar uma classe ABAP que consulta CEPs no serviço ViaCEP, originalmente desenvolvida no **SAP BTP ABAP Environment Trial**, para um sistema **SAP On-Premise ABAP Platform 2025**.

A implementação original utilizava APIs do modelo ABAP Cloud:

```abap
cl_http_destination_provider=>create_by_url( )
cl_web_http_client_manager=>create_by_http_destination( )
```

No sistema On-Premise utilizado na migração, `CL_HTTP_DESTINATION_PROVIDER` não estava disponível. A solução adotada foi:

1. substituir a API ABAP Cloud por `CL_HTTP_CLIENT`;
2. criar uma destination HTTP do tipo **G** na transação `SM59`;
3. configurar a confiança TLS na transação `STRUST`;
4. criar o cliente com `CL_HTTP_CLIENT=>CREATE_BY_DESTINATION`;
5. manter no código apenas o nome lógico da destination e o caminho variável da consulta.

---

## 2. Arquitetura antes e depois

### Antes: SAP BTP ABAP Environment

```text
Classe ABAP Cloud
    -> CL_HTTP_DESTINATION_PROVIDER=>CREATE_BY_URL
    -> CL_WEB_HTTP_CLIENT_MANAGER
    -> https://viacep.com.br/ws/{CEP}/json/
```

A URL era informada diretamente pelo código.

### Depois: SAP On-Premise

```text
Classe ZCL_PC_VIACEP
    -> CL_HTTP_CLIENT=>CREATE_BY_DESTINATION
    -> Destination Z_VIACEP na SM59
    -> PSE SSL Client (Anonymous) no STRUST
    -> https://viacep.com.br/ws/{CEP}/json/
```

A divisão de responsabilidades passou a ser:

- **Código ABAP:** validação do CEP, cache, chamada HTTP, tratamento do status e leitura do JSON;
- **SM59:** host, porta, HTTPS, proxy e seleção da PSE;
- **STRUST:** certificados confiáveis usados na validação TLS.

---

## 3. Pré-requisitos

Antes da implementação, verifique:

- o objeto ABAP está em um pacote configurado para **Standard ABAP**;
- o servidor SAP possui acesso de saída à internet ou um proxy configurado;
- o usuário possui autorização para criar ou utilizar destinations HTTP;
- há acesso administrativo, direto ou via equipe Basis, às transações `SM59` e `STRUST`;
- o ICM e a biblioteca criptográfica do sistema suportam o protocolo TLS exigido pelo endpoint;
- a classe auxiliar original `ZCL_PC_UTIL` existe ou sua lógica será incorporada à nova classe.

> `CL_HTTP_CLIENT` é uma API clássica. Se o objeto estiver restrito a **ABAP for Cloud Development**, seu uso poderá ser rejeitado pelo controle de linguagem, mesmo que a classe exista no sistema.

---

## 4. Criar a destination HTTP na SM59

### 4.1 Criar a destination

1. Execute a transação `SM59`.
2. Escolha **Create**.
3. Preencha:

```text
RFC Destination: Z_VIACEP
Connection Type: G
Description: ViaCEP - Consulta de CEP
```

O tipo **G** representa uma conexão HTTP com um servidor externo.

### 4.2 Configurar Technical Settings

Na aba **Technical Settings**, informe:

```text
Target Host: viacep.com.br
Service No.: 443
Path Prefix: deixar vazio
```

Não informe protocolo ou caminho no campo de host. Portanto, use:

```text
viacep.com.br
```

Não use:

```text
https://viacep.com.br/ws/
```

O caminho será montado dinamicamente no código:

```text
/ws/{CEP}/json/
```

Se o ambiente depender de proxy para acesso à internet, configure também os campos de proxy disponíveis na destination.

### 4.3 Configurar Logon & Security

Na aba **Logon & Security**, utilize:

```text
Logon Procedure: No Logon
SSL: Active
SSL Certificate: ANONYM SSL Client (Anonymous)
```

O ViaCEP é um serviço público, portanto não exige usuário, senha ou certificado de cliente. A opção `ANONYM` não desativa a validação do servidor. Ela apenas seleciona a PSE de cliente SSL anônimo.

Salve a destination.

---

## 5. Configurar a confiança TLS no STRUST

### 5.1 Por que o STRUST é necessário

Em uma chamada HTTPS, o ICM/CommonCryptoLib valida a cadeia X.509 apresentada pelo servidor antes de liberar a resposta para o programa ABAP. A destination pode estar correta e a rede pode estar acessível, mas a conexão falhar se nenhuma autoridade da cadeia for confiável na PSE selecionada.

Durante esta migração, o teste da SM59 retornou:

```text
SSSLERR_PEER_CERT_UNTRUSTED (-102)
Failed to verify peer certificate. Peer not trusted.
The verified certificate chain is complete but no certificate is trusted.
```

Isso confirmou que:

- a resolução DNS funcionava;
- o SAP alcançava `viacep.com.br:443`;
- a negociação TLS havia começado;
- o certificado do servidor estava válido;
- porém nenhuma âncora da cadeia era confiável na `SAPSSLA.pse`.

### 5.2 Cadeia observada no teste

A cadeia apresentada pelo endpoint era:

```text
CN=viacep.com.br
    -> Sectigo Public Server Authentication CA DV R36
        -> Sectigo Public Server Authentication Root R46
            -> USERTrust RSA Certification Authority
```

A correção foi incluir na PSE anônima a raiz confiável e, se necessário, o certificado R46 cross-signed:

```text
USERTrust RSA Certification Authority
Sectigo Public Server Authentication Root R46 x USERTrust RSA CA
```

### 5.3 Baixar os certificados

Baixe os certificados diretamente do repositório oficial da Sectigo:

- `USERTrustRSACertificationAuthority.crt`
- `SectigoPublicServerAuthenticationRootR46_USERTrust.crt`

Antes de importar, confira no visualizador de certificados:

- Subject;
- Issuer;
- validade;
- impressão digital SHA-256;
- se o R46 cross-signed foi emitido pela `USERTrust RSA Certification Authority`.

Evite usar apenas o certificado final `CN=viacep.com.br` como âncora permanente. Ele é renovado com mais frequência, o que geraria manutenção recorrente.

### 5.4 Importar no STRUST

1. Execute `STRUST`.
2. Entre no modo de alteração, normalmente usando `Ctrl+F1`.
3. Selecione:

```text
SSL client
    -> SSL Client (Anonymous)
```

4. Escolha **Certificate > Import**.
5. Importe primeiro:

```text
USERTrustRSACertificationAuthority.crt
```

6. Confira Subject, Issuer, validade e impressão digital.
7. Clique em **Add to Certificate List**.
8. Salve.
9. Se necessário, repita o processo para:

```text
SectigoPublicServerAuthenticationRootR46_USERTrust.crt
```

10. Salve novamente.

> Carregar o certificado na área de visualização não basta. É necessário clicar em **Add to Certificate List** e salvar a PSE.

### 5.5 Retestar a destination

Retorne à `SM59`, abra `Z_VIACEP` e execute **Connection Test**.

O objetivo inicial não é necessariamente obter HTTP 200 na raiz do site, mas eliminar erros de:

- handshake SSL;
- certificado não confiável;
- DNS;
- proxy;
- conexão recusada;
- timeout.

Após a importação da cadeia confiável, o teste funcionou corretamente.

---

## 6. Classe ABAP migrada

A classe abaixo substitui as APIs ABAP Cloud pelo cliente HTTP clássico e utiliza a destination `Z_VIACEP`.

```abap
CLASS zcl_pc_viacep DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_endereco,
        cep         TYPE string,
        logradouro  TYPE string,
        complemento TYPE string,
        bairro      TYPE string,
        localidade  TYPE string,
        uf          TYPE string,
        estado      TYPE string,
        erro        TYPE string,
      END OF ty_endereco.

    TYPES:
      BEGIN OF ty_resultado,
        valido        TYPE abap_bool,
        indisponivel  TYPE abap_bool,
        cep_geral     TYPE abap_bool,
        status_http   TYPE i,
        mensagem_erro TYPE string,
        endereco      TYPE ty_endereco,
      END OF ty_resultado.

    CONSTANTS c_destination TYPE rfcdest VALUE 'Z_VIACEP'.

    CLASS-METHODS consultar
      IMPORTING
        iv_cep              TYPE csequence
      RETURNING
        VALUE(rs_resultado) TYPE ty_resultado.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_cache,
        cep       TYPE string,
        resultado TYPE ty_resultado,
      END OF ty_cache.

    CONSTANTS:
      c_max_cache TYPE i VALUE 100,
      c_timeout   TYPE i VALUE 30.

    CLASS-DATA gt_cache TYPE STANDARD TABLE OF ty_cache
      WITH EMPTY KEY.

    CLASS-METHODS chamar_servico
      IMPORTING
        iv_cep              TYPE string
      RETURNING
        VALUE(rs_resultado) TYPE ty_resultado.

    CLASS-METHODS extrair_campo
      IMPORTING
        iv_json         TYPE string
        iv_campo        TYPE string
      RETURNING
        VALUE(rv_valor) TYPE string.

    CLASS-METHODS somente_digitos
      IMPORTING
        iv_valor        TYPE csequence
      RETURNING
        VALUE(rv_valor) TYPE string.

ENDCLASS.


CLASS zcl_pc_viacep IMPLEMENTATION.

  METHOD consultar.

    DATA(lv_cep) = somente_digitos( iv_cep ).

    IF strlen( lv_cep ) <> 8.
      rs_resultado-valido        = abap_false.
      rs_resultado-mensagem_erro =
        'O CEP deve possuir exatamente 8 dígitos.'.
      RETURN.
    ENDIF.

    READ TABLE gt_cache
      INTO DATA(ls_cache)
      WITH KEY cep = lv_cep.

    IF sy-subrc = 0.
      rs_resultado = ls_cache-resultado.
      RETURN.
    ENDIF.

    rs_resultado = chamar_servico( lv_cep ).

    " Indisponibilidades temporárias não devem entrar no cache.
    IF rs_resultado-indisponivel = abap_false.

      IF lines( gt_cache ) >= c_max_cache.
        DELETE gt_cache INDEX 1.
      ENDIF.

      APPEND VALUE #(
        cep       = lv_cep
        resultado = rs_resultado
      ) TO gt_cache.

    ENDIF.

  ENDMETHOD.


  METHOD chamar_servico.

    DATA:
      lo_http_client TYPE REF TO if_http_client,
      lv_uri         TYPE string,
      lv_json        TYPE string,
      lv_status      TYPE i,
      lv_reason      TYPE string,
      lv_error_code  TYPE i,
      lv_error_text  TYPE string.

    CLEAR rs_resultado.

    lv_uri = |/ws/{ iv_cep }/json/|.

    cl_http_client=>create_by_destination(
      EXPORTING
        destination              = c_destination
      IMPORTING
        client                   = lo_http_client
      EXCEPTIONS
        argument_not_found       = 1
        destination_not_found    = 2
        destination_no_authority = 3
        plugin_not_active        = 4
        internal_error           = 5
        OTHERS                   = 6 ).

    IF sy-subrc <> 0 OR lo_http_client IS NOT BOUND.
      rs_resultado-indisponivel = abap_true.

      CASE sy-subrc.
        WHEN 2.
          rs_resultado-mensagem_erro =
            |A destination { c_destination } não foi encontrada na SM59.|.
        WHEN 3.
          rs_resultado-mensagem_erro =
            |O usuário não possui autorização para usar a destination { c_destination }.|.
        WHEN OTHERS.
          rs_resultado-mensagem_erro =
            |Não foi possível criar o cliente HTTP. SY-SUBRC: { sy-subrc }.|.
      ENDCASE.

      RETURN.
    ENDIF.

    cl_http_utility=>set_request_uri(
      request = lo_http_client->request
      uri     = lv_uri ).

    lo_http_client->request->set_method(
      if_http_request=>co_request_method_get ).

    lo_http_client->request->set_header_field(
      name  = 'Accept'
      value = 'application/json' ).

    lo_http_client->request->set_header_field(
      name  = 'User-Agent'
      value = 'SAP-ABAP-ViaCEP-Client/1.0' ).

    lo_http_client->request->set_header_field(
      name  = 'Connection'
      value = 'close' ).

    lo_http_client->send(
      EXPORTING
        timeout                    = c_timeout
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        OTHERS                     = 5 ).

    IF sy-subrc <> 0.
      lo_http_client->get_last_error(
        IMPORTING
          code    = lv_error_code
          message = lv_error_text ).

      rs_resultado-indisponivel = abap_true.
      rs_resultado-mensagem_erro =
        |Falha no envio HTTP. Código: { lv_error_code }. Detalhe: { lv_error_text }.|.

      lo_http_client->close( ).
      RETURN.
    ENDIF.

    lo_http_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    IF sy-subrc <> 0.
      lo_http_client->get_last_error(
        IMPORTING
          code    = lv_error_code
          message = lv_error_text ).

      rs_resultado-indisponivel = abap_true.
      rs_resultado-mensagem_erro =
        |Falha ao receber HTTP. Código: { lv_error_code }. Detalhe: { lv_error_text }.|.

      lo_http_client->close( ).
      RETURN.
    ENDIF.

    lo_http_client->response->get_status(
      IMPORTING
        code   = lv_status
        reason = lv_reason ).

    rs_resultado-status_http = lv_status.
    lv_json = lo_http_client->response->get_cdata( ).

    lo_http_client->close( ).

    CASE lv_status.
      WHEN 200.
        " Continua para o processamento do JSON.

      WHEN 400 OR 404.
        rs_resultado-valido = abap_false.
        rs_resultado-mensagem_erro =
          |CEP inválido ou não encontrado. HTTP { lv_status } { lv_reason }.|.
        RETURN.

      WHEN 408 OR 429.
        rs_resultado-indisponivel = abap_true.
        rs_resultado-mensagem_erro =
          |Serviço temporariamente indisponível. HTTP { lv_status } { lv_reason }.|.
        RETURN.

      WHEN 500 OR 501 OR 502 OR 503 OR 504.
        rs_resultado-indisponivel = abap_true.
        rs_resultado-mensagem_erro =
          |Erro temporário no ViaCEP. HTTP { lv_status } { lv_reason }.|.
        RETURN.

      WHEN OTHERS.
        rs_resultado-indisponivel = abap_true.
        rs_resultado-mensagem_erro =
          |Resposta HTTP inesperada: { lv_status } { lv_reason }.|.
        RETURN.
    ENDCASE.

    IF lv_json IS INITIAL.
      rs_resultado-indisponivel  = abap_true.
      rs_resultado-mensagem_erro =
        'O ViaCEP retornou uma resposta vazia.'.
      RETURN.
    ENDIF.

    rs_resultado-endereco = VALUE #(
      cep = extrair_campo(
        iv_json  = lv_json
        iv_campo = 'cep' )
      logradouro = extrair_campo(
        iv_json  = lv_json
        iv_campo = 'logradouro' )
      complemento = extrair_campo(
        iv_json  = lv_json
        iv_campo = 'complemento' )
      bairro = extrair_campo(
        iv_json  = lv_json
        iv_campo = 'bairro' )
      localidade = extrair_campo(
        iv_json  = lv_json
        iv_campo = 'localidade' )
      uf = extrair_campo(
        iv_json  = lv_json
        iv_campo = 'uf' )
      estado = extrair_campo(
        iv_json  = lv_json
        iv_campo = 'estado' )
      erro = extrair_campo(
        iv_json  = lv_json
        iv_campo = 'erro' ) ).

    IF rs_resultado-endereco-erro = 'true'
       OR rs_resultado-endereco-localidade IS INITIAL.
      rs_resultado-valido = abap_false.
      rs_resultado-mensagem_erro =
        |O CEP { iv_cep } não foi encontrado pelo ViaCEP.|.
      RETURN.
    ENDIF.

    rs_resultado-valido = abap_true.
    rs_resultado-cep_geral = xsdbool(
      rs_resultado-endereco-logradouro IS INITIAL
      AND rs_resultado-endereco-localidade IS NOT INITIAL ).

  ENDMETHOD.


  METHOD extrair_campo.

    DATA:
      lv_texto   TYPE string,
      lv_literal TYPE string.

    DATA(lv_pattern) =
      `"` && iv_campo &&
      `"\s*:\s*(?:"([^"]*)"|([a-zA-Z]+))`.

    FIND PCRE lv_pattern
      IN iv_json
      SUBMATCHES lv_texto lv_literal.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF lv_texto IS NOT INITIAL.
      rv_valor = lv_texto.
    ELSEIF lv_literal = 'null'.
      CLEAR rv_valor.
    ELSE.
      rv_valor = lv_literal.
    ENDIF.

  ENDMETHOD.


  METHOD somente_digitos.

    rv_valor = CONV string( iv_valor ).

    REPLACE ALL OCCURRENCES OF REGEX '[^0-9]'
      IN rv_valor
      WITH ''.

  ENDMETHOD.

ENDCLASS.
```

### Compatibilidade de assinatura

As exceções nomeadas de `CREATE_BY_DESTINATION`, `SEND` e `RECEIVE` podem variar conforme o release ou Support Package. Se o editor indicar uma exceção inexistente, abra a assinatura do método no sistema e mantenha somente as exceções disponíveis.

Uma chamada simplificada pode ser usada quando necessário:

```abap
cl_http_client=>create_by_destination(
  EXPORTING
    destination = c_destination
  IMPORTING
    client      = lo_http_client
  EXCEPTIONS
    OTHERS      = 1 ).
```

---

## 7. Programa de teste

Crie um report temporário para validar a classe:

```abap
REPORT zteste_viacep.

PARAMETERS p_cep TYPE c LENGTH 9
                 DEFAULT '01310-100'.

START-OF-SELECTION.

  DATA(ls_resultado) =
    zcl_pc_viacep=>consultar( p_cep ).

  IF ls_resultado-indisponivel = abap_true.
    WRITE:
      / 'Serviço indisponível.',
      / 'Status HTTP:', ls_resultado-status_http,
      / 'Detalhe:', ls_resultado-mensagem_erro.
    RETURN.
  ENDIF.

  IF ls_resultado-valido = abap_false.
    WRITE:
      / 'CEP inválido ou inexistente.',
      / 'Status HTTP:', ls_resultado-status_http,
      / 'Detalhe:', ls_resultado-mensagem_erro.
    RETURN.
  ENDIF.

  WRITE:
    / 'CEP:',         ls_resultado-endereco-cep,
    / 'Logradouro:',  ls_resultado-endereco-logradouro,
    / 'Complemento:', ls_resultado-endereco-complemento,
    / 'Bairro:',      ls_resultado-endereco-bairro,
    / 'Cidade:',      ls_resultado-endereco-localidade,
    / 'UF:',          ls_resultado-endereco-uf,
    / 'Estado:',      ls_resultado-endereco-estado,
    / 'CEP geral:',   ls_resultado-cep_geral,
    / 'HTTP:',        ls_resultado-status_http.
```

---

## 8. Diagnóstico de problemas

### Destination não encontrada

Possível mensagem:

```text
A destination Z_VIACEP não foi encontrada na SM59.
```

Verifique:

- nome da constante `C_DESTINATION`;
- existência da destination no cliente atual;
- transporte ou criação manual da destination no ambiente.

### Falha de autorização

Verifique as autorizações do usuário para utilizar destinations RFC/HTTP e, para administração, as autorizações relacionadas às transações `SM59` e `STRUST`.

### `SSSLERR_PEER_CERT_UNTRUSTED`

Significa que o servidor foi alcançado, mas a cadeia X.509 não encontrou uma âncora confiável na PSE utilizada.

Verifique:

1. `SSL = Active` na SM59;
2. PSE `ANONYM SSL Client (Anonymous)` selecionada;
3. certificado raiz incluído na lista da PSE anônima;
4. uso de **Add to Certificate List**;
5. salvamento da PSE;
6. distribuição da PSE entre instâncias, caso haja mais de um application server.

### Timeout ou falha de comunicação

Verifique:

- acesso externo do servidor SAP;
- DNS;
- firewall;
- porta 443;
- proxy na SM59;
- logs do ICM na `SMICM`;
- detalhes retornados por `GET_LAST_ERROR`.

### Status HTTP inesperado

A aplicação diferencia:

- `200`: resposta processável;
- `400` e `404`: CEP inválido ou recurso não encontrado;
- `408` e `429`: indisponibilidade temporária ou limitação;
- `5xx`: falha temporária do serviço;
- demais códigos: resposta inesperada.

---

## 9. Cuidados de segurança e manutenção

- Não desative a validação TLS para contornar erros de certificado.
- Não grave senhas ou certificados privados no código.
- Prefira uma destination SM59 a URLs técnicas fixadas na classe.
- Confie preferencialmente em CAs adequadas, não somente no certificado final do site.
- Revise periodicamente a validade e a cadeia de certificados.
- Mantenha respostas de indisponibilidade fora do cache, permitindo nova tentativa.
- Não exponha detalhes internos de SSL e infraestrutura diretamente ao usuário final em uma aplicação produtiva.
- Considere substituir a extração por regex por um parser JSON suportado no release On-Premise, caso a estrutura da resposta se torne mais complexa.

---

## 10. Transporte entre ambientes

O código ABAP e a configuração técnica não seguem necessariamente o mesmo ciclo de transporte.

Considere separadamente:

1. **Classe e report ABAP:** transportados por request do Workbench;
2. **Destination SM59:** transportar conforme a política do landscape ou recriar parametrizada em cada ambiente;
3. **Certificados e PSE:** normalmente administrados pela equipe Basis em cada sistema;
4. **Proxy e firewall:** configurações específicas de infraestrutura;
5. **Autorizações:** mantidas por perfis e funções do ambiente.

Não presuma que a importação do código levará automaticamente a destination e os certificados para qualidade ou produção.

---

## 11. Checklist final

- [ ] Classe criada em **Standard ABAP**.
- [ ] `CL_HTTP_DESTINATION_PROVIDER` removida da implementação On-Premise.
- [ ] Uso de `CL_HTTP_CLIENT=>CREATE_BY_DESTINATION`.
- [ ] Destination `Z_VIACEP` criada na `SM59`.
- [ ] Tipo de conexão `G`.
- [ ] Host `viacep.com.br` sem protocolo ou caminho.
- [ ] Porta `443`.
- [ ] `Path Prefix` vazio.
- [ ] `No Logon` selecionado.
- [ ] SSL ativo.
- [ ] PSE `ANONYM SSL Client (Anonymous)` selecionada.
- [ ] `USERTrust RSA Certification Authority` confiável no `STRUST`.
- [ ] R46 cross-signed incluído, caso necessário.
- [ ] Destination testada sem erro de handshake.
- [ ] Programa de teste retornando HTTP 200 para um CEP válido.
- [ ] Tratamento de timeout, status HTTP e `GET_LAST_ERROR` preservado.
- [ ] Configurações técnicas documentadas para os próximos ambientes.

---

## 12. Resultado da migração

A lógica originalmente criada no SAP BTP ABAP Environment foi preservada, incluindo:

- higienização e validação do CEP;
- cache por sessão;
- distinção entre CEP inválido e serviço indisponível;
- reconhecimento de CEP geral de município;
- extração dos campos da resposta JSON;
- encerramento do cliente HTTP;
- tratamento de falhas técnicas.

A principal mudança foi a camada de conectividade:

```text
ABAP Cloud
CL_HTTP_DESTINATION_PROVIDER + CL_WEB_HTTP_CLIENT_MANAGER
```

foi substituída por:

```text
SAP On-Premise
SM59 + STRUST + CL_HTTP_CLIENT
```

Com isso, a URL-base, o SSL e o proxy ficam desacoplados do código, enquanto a classe mantém somente a regra funcional e o caminho variável da consulta.

---

## Referências

- SAP Help: *Establishing a Connection Using a Destination (SM59)*.
- SAP Help: documentação de criação e manutenção de destinations HTTP externas.
- SAP Help: documentação do Trust Manager e das PSEs de cliente SSL.
- Sectigo Knowledge Base: *Sectigo Root Certificates*.
- Sectigo Knowledge Base: *Sectigo Public Intermediates and Roots*.
