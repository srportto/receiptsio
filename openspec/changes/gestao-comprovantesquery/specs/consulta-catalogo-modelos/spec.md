## ADDED Requirements

### Requirement: Contrato REST como fonte da verdade
O contrato da API SHALL estar em `docs/contratos-rest/gestao-comprovantesquery/openapi.yaml` (OpenAPI 3.1), e a aplicação MUST NOT conter anotações OpenAPI. Toda resposta de sucesso e de erro MUST ser válida contra os schemas desse arquivo.

#### Scenario: Resposta válida contra o contrato
- **WHEN** a listagem e o detalhe são consultados com dados do seed
- **THEN** o corpo de cada resposta valida contra os schemas `PaginaModelos` e `ModeloDetalhe` do `openapi.yaml`

#### Scenario: Aplicação sem anotações de contrato
- **WHEN** se procura `io.swagger` ou `springdoc` no código e nas dependências da aplicação
- **THEN** não há nenhuma ocorrência

### Requirement: Listagem simples de modelos
`GET /modelos` SHALL devolver `{ items, pagination }` com os modelos em ordem fixa (`idModelo` crescente, `versao` decrescente). Cada item MUST conter `idModelo`, `versao`, `descricao`, `situacao` e `dataHoraAtualizacao`. Sem nenhum filtro, MUST listar modelos de todas as situações.

#### Scenario: Sem filtros
- **WHEN** o cliente chama `GET /modelos` com o seed carregado
- **THEN** recebe 200 com os modelos de todas as situações (ATIVO, INATIVO e RASCUNHO) na ordem fixa

#### Scenario: Banco sem modelos
- **WHEN** não há modelo que atenda ao filtro
- **THEN** recebe 200 com `items` vazio e `pagination.totalElements` igual a 0 e `totalPages` igual a 0

### Requirement: Filtros opcionais da listagem
A listagem SHALL aceitar os parâmetros opcionais `situacao` (`RASCUNHO`, `ATIVO` ou `INATIVO`), `idModelo` e `versao`, combináveis por E lógico. A ausência de um parâmetro MUST NOT restringir o resultado por ele.

#### Scenario: Somente ativos
- **WHEN** o cliente chama `GET /modelos?situacao=ATIVO`
- **THEN** todos os itens têm `situacao` igual a `ATIVO`

#### Scenario: Somente rascunhos
- **WHEN** o cliente chama `GET /modelos?situacao=RASCUNHO`
- **THEN** todos os itens têm `situacao` igual a `RASCUNHO`

#### Scenario: Por modelo sem versão
- **WHEN** o cliente chama `GET /modelos?idModelo=COMPPIX`
- **THEN** recebe todas as versões de `COMPPIX`, em qualquer situação

#### Scenario: Por modelo e versão
- **WHEN** o cliente chama `GET /modelos?idModelo=COMPPIX&versao=2`
- **THEN** recebe no máximo um item, o de `COMPPIX` versão 2

#### Scenario: Filtros combinados
- **WHEN** o cliente chama `GET /modelos?idModelo=COMPBOL&situacao=RASCUNHO`
- **THEN** recebe apenas os rascunhos de `COMPBOL`

### Requirement: Paginação por offset
A listagem SHALL paginar por offset com `page` (inteiro a partir de 1, padrão 1) e `size` (de 1 a 100, padrão 20), e MUST devolver o objeto `pagination` com `page`, `size`, `totalElements` e `totalPages`. Uma página além da última MUST devolver `items` vazio, com 200.

#### Scenario: Valores padrão
- **WHEN** o cliente chama `GET /modelos` sem `page` nem `size`
- **THEN** `pagination.page` é 1 e `pagination.size` é 20

#### Scenario: Segunda página
- **WHEN** existem 3 modelos e o cliente chama `GET /modelos?page=2&size=2`
- **THEN** `items` tem 1 elemento, `pagination.totalElements` é 3 e `pagination.totalPages` é 2

#### Scenario: Página além da última
- **WHEN** o cliente chama `GET /modelos?page=99`
- **THEN** recebe 200 com `items` vazio e `totalElements` com o total real

### Requirement: Detalhe do modelo com seus campos
`GET /modelos/{idModelo}/versoes/{versao}` SHALL devolver o modelo (qualquer situação) com `templateEstrutural` e `templateVariavel`, cada um com `idTemplate`, `nome` e `campos` ordenados por `ordem`. Cada campo MUST conter `idCampo`, `nomeCampo`, `tipoDado`, `ordem`, `aceitaNuloVazio`, `descricaoCampoTemplate`, `descricaoBase` e `descricaoEfetiva`; os campos estruturais MUST conter também `posicaoIndexador` (nulo quando não é indexador).

#### Scenario: Modelo ativo com indexadores
- **WHEN** o cliente detalha `COMPTED` versão 1 (ATIVO, 5 indexadores do seed)
- **THEN** `templateEstrutural.campos` contém exatamente 5 campos com `posicaoIndexador` de 1 a 5

#### Scenario: Rascunho
- **WHEN** o cliente detalha `COMPBOL` versão 2 (RASCUNHO)
- **THEN** recebe 200 com `situacao` igual a `RASCUNHO` e nenhum campo com `posicaoIndexador` igual a 1

#### Scenario: Campos ordenados e sem duplicação
- **WHEN** o cliente detalha qualquer modelo do seed
- **THEN** os campos de cada template vêm em `ordem` crescente e a quantidade bate com a da view `catalogo.vw_modelo_completo`

#### Scenario: Descrição efetiva
- **WHEN** um campo tem `descricaoCampoTemplate` nula
- **THEN** `descricaoEfetiva` é igual a `descricaoBase`

#### Scenario: Modelo inexistente
- **WHEN** o cliente detalha `COMPPIX` versão 999
- **THEN** recebe 404 `application/problem+json`

### Requirement: Validação dos parâmetros
A API SHALL rejeitar com 400 `application/problem+json`, listando cada parâmetro inválido em `errors`, `situacao` fora do conjunto, `idModelo` fora de `^[A-Z0-9_]{1,10}$`, `versao` fora de 1 a 999, `page` menor que 1 e `size` fora de 1 a 100, tanto na query quanto no path. A validação MUST ocorrer antes de qualquer consulta ao banco.

#### Scenario: Situação desconhecida
- **WHEN** o cliente chama `GET /modelos?situacao=XYZ`
- **THEN** recebe 400 com `errors` contendo o parâmetro `situacao`

#### Scenario: Tamanho acima do teto
- **WHEN** o cliente chama `GET /modelos?size=500`
- **THEN** recebe 400 com `errors` contendo o parâmetro `size`

#### Scenario: Vários erros juntos
- **WHEN** o cliente chama `GET /modelos?situacao=XYZ&size=500`
- **THEN** `errors` lista `situacao` e `size`

#### Scenario: Path inválido
- **WHEN** o cliente chama `GET /modelos/comppix/versoes/0`
- **THEN** recebe 400 com `errors` contendo `idModelo` e `versao`, sem consultar o banco

### Requirement: Somente leitura garantida pelo banco
A aplicação SHALL conectar ao banco exclusivamente com a role `catalogo_leitura` e MUST NOT expor nenhum método HTTP de escrita. Mesmo que uma escrita fosse tentada, o banco MUST rejeitá-la.

#### Scenario: Métodos de escrita não existem
- **WHEN** o cliente envia `POST`, `PUT`, `PATCH` ou `DELETE` a `/modelos`
- **THEN** recebe 405 `application/problem+json`

#### Scenario: Role rejeita escrita
- **WHEN** um teste abre a conexão da aplicação e executa `INSERT`, `UPDATE` e `DELETE` em `catalogo.modelo`
- **THEN** cada comando falha com `insufficient_privilege` (SQLSTATE 42501)

### Requirement: Indisponibilidade e erros inesperados
A API SHALL responder 503 `application/problem+json` com `Retry-After` quando o banco estiver indisponível, o pool esgotar ou a consulta exceder o tempo limite, e 500 `application/problem+json` para falha inesperada. Nenhuma resposta MUST expor SQL, nome de tabela, stack trace ou credencial.

#### Scenario: Banco indisponível
- **WHEN** o banco está parado e o cliente chama `GET /modelos`
- **THEN** recebe 503 com `Retry-After` e sem detalhe interno no corpo

#### Scenario: Consulta acima do tempo limite
- **WHEN** a consulta excede o tempo limite configurado
- **THEN** recebe 503 em até o tempo limite somado a uma folga pequena, e a conexão é devolvida ao pool

#### Scenario: Falha inesperada
- **WHEN** ocorre uma exceção não prevista
- **THEN** recebe 500 com `title` genérico, e o detalhe vai apenas para o log

### Requirement: Sem segurança embutida
A aplicação MUST NOT depender de Spring Security nem implementar autenticação, autorização ou CORS; esses controles pertencem à camada web e ao gateway.

#### Scenario: Dependências
- **WHEN** se inspeciona o `pom.xml` e o classpath de execução
- **THEN** não há `spring-boot-starter-security` nem `spring-security-*`

### Requirement: Disponibilidade e configuração externa
A aplicação SHALL expor `GET /disponibilidade` (rota padrão do catálogo) e ler host, porta, nome do banco, usuário e senha do ambiente (`.env` da raiz), sem valores fixos no código ou em arquivos versionados.

#### Scenario: Aplicação saudável
- **WHEN** o banco responde
- **THEN** `GET /disponibilidade` devolve 200

#### Scenario: Senha ausente
- **WHEN** a variável da senha da role `catalogo_leitura` não está definida
- **THEN** a aplicação falha na subida com mensagem que nomeia a variável, sem imprimir valores
