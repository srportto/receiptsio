## ADDED Requirements

### Requirement: Template tem nome obrigatório e descrição opcional
Os templates estrutural e variável SHALL ter `nome_template` obrigatório e não vazio, e `descricao` opcional.

#### Scenario: Template sem nome
- **WHEN** se insere um template com `nome_template` vazio ou só com espaços
- **THEN** a inserção é rejeitada por violação de CHECK

#### Scenario: Template sem descrição
- **WHEN** se insere um template com `nome_template` preenchido e sem `descricao`
- **THEN** a inserção é aceita

### Requirement: Campo tem descrição própria em cada template
As associações template estrutural–campo e template variável–campo SHALL ter `descricao_campo_template` opcional. Quando ela é nula, a descrição efetiva do campo naquele template MUST ser a `descricao_base` do campo.

#### Scenario: Descrição específica do template
- **WHEN** o campo `valor` está associado a um template com `descricao_campo_template = 'Valor da parcela'`
- **THEN** a descrição efetiva do campo nesse template é `Valor da parcela`

#### Scenario: Descrição herdada do campo
- **WHEN** o campo `valor` está associado a um template sem `descricao_campo_template`
- **THEN** a descrição efetiva do campo nesse template é a `descricao_base` do campo

### Requirement: Lock otimista em coluna de controle dedicada
As tabelas `campo`, `template_estrutural`, `template_variavel` e `modelo` SHALL ter a coluna `data_version BIGINT NOT NULL DEFAULT 0` para lock otimista, incrementada pela aplicação. Nenhuma tabela do catálogo MUST ter coluna chamada `version`. As associações template–campo MUST NOT ter `data_version`: a concorrência delas é controlada pelo `data_version` do template.

#### Scenario: Coluna de controle presente
- **WHEN** se insere uma linha em `campo`, `template_estrutural`, `template_variavel` ou `modelo` sem informar `data_version`
- **THEN** a linha é gravada com `data_version = 0`

#### Scenario: Nenhuma coluna version
- **WHEN** se consulta `information_schema.columns` do schema `catalogo`
- **THEN** nenhuma coluna se chama `version` e as associações não têm `data_version`

### Requirement: Campo em uso por versão publicada não muda de significado
O catálogo SHALL rejeitar a alteração de `nome_campo` ou `tipo_dado` de um campo associado a qualquer template referenciado por modelo publicado (`ATIVO` ou `INATIVO`). A alteração de `descricao_base` MUST continuar permitida.

#### Scenario: Alterar tipo de campo publicado
- **WHEN** se altera `tipo_dado` de um campo usado pelo template estrutural de um modelo `ATIVO`
- **THEN** a alteração é rejeitada com mensagem que identifica o campo

#### Scenario: Alterar descrição de campo publicado
- **WHEN** se altera `descricao_base` de um campo usado por um modelo `ATIVO`
- **THEN** a alteração é aceita

#### Scenario: Alterar campo só usado em rascunho
- **WHEN** se altera `tipo_dado` de um campo usado apenas por templates de modelos `RASCUNHO`
- **THEN** a alteração é aceita

## MODIFIED Requirements

### Requirement: Situação do modelo e versão vigente
O modelo SHALL ter `situacao` em `RASCUNHO`, `ATIVO` ou `INATIVO`, criado como `RASCUNHO` por padrão. No máximo uma versão por `id_modelo` MUST estar `ATIVO`. As transições permitidas são `RASCUNHO → ATIVO`, `ATIVO → INATIVO` e `INATIVO → ATIVO`. Nenhuma situação publicada volta a `RASCUNHO`, e `RASCUNHO → INATIVO` MUST ser rejeitada.

#### Scenario: Duas versões ativas
- **WHEN** `(COMPPIX, 1)` está `ATIVO` e se altera `(COMPPIX, 2)` para `ATIVO` sem inativar a versão 1
- **THEN** a alteração é rejeitada por violação de unicidade

#### Scenario: Troca de versão vigente na mesma transação
- **WHEN** numa mesma transação `(COMPPIX, 1)` passa a `INATIVO` e depois `(COMPPIX, 2)`, existente e publicável, passa a `ATIVO`
- **THEN** a transação é confirmada e a versão 2 é a vigente

#### Scenario: Publicado volta a rascunho
- **WHEN** se altera um modelo `ATIVO` para `RASCUNHO`
- **THEN** a alteração é rejeitada

#### Scenario: Rascunho direto para inativo
- **WHEN** se altera um modelo `RASCUNHO` para `INATIVO`
- **THEN** a alteração é rejeitada

### Requirement: Publicação exige indexador na posição 1
Um modelo SHALL ficar publicado (`ATIVO` ou `INATIVO`) somente se o seu template estrutural tiver um campo na `posicao_indexador = 1`. A regra MUST valer tanto na transição `RASCUNHO → ATIVO` quanto num `INSERT` que já informe situação publicada. A validação MUST enxergar todas as alterações confirmadas no template, inclusive as feitas por transações concorrentes.

#### Scenario: Publicar sem indexador principal
- **WHEN** se altera para `ATIVO` um modelo cujo template estrutural não tem indexador na posição 1
- **THEN** a alteração é rejeitada com mensagem que identifica o template

#### Scenario: Publicar com indexador principal
- **WHEN** se altera para `ATIVO` um modelo cujo template estrutural tem indexador na posição 1
- **THEN** a alteração é aceita

#### Scenario: Inserir já publicado sem indexador principal
- **WHEN** se insere um modelo com `situacao = 'ATIVO'` cujo template estrutural não tem indexador na posição 1
- **THEN** a inserção é rejeitada com mensagem que identifica o template

#### Scenario: Inserir já publicado com indexador principal
- **WHEN** se insere um modelo com `situacao = 'ATIVO'` cujo template estrutural tem indexador na posição 1
- **THEN** a inserção é aceita

### Requirement: Versão publicada é imutável
Depois que um modelo sai de `RASCUNHO`, seus templates referenciados e sua composição SHALL ser imutáveis:
- o próprio modelo só pode alterar `situacao` e as colunas de controle (`data_version`, `data_hora_atualizacao`). `id_modelo`, `versao`, `descricao` e os templates referenciados MUST NOT mudar;
- os templates referenciados por algum modelo publicado MUST NOT ser alterados nem excluídos, nem ter associações de campo incluídas, alteradas ou excluídas.

A garantia MUST valer sob concorrência: uma edição de template e a publicação de um modelo que o usa MUST NOT terminar ambas confirmadas se a edição não foi vista pela validação da publicação. Comprovantes no NoSQL referenciam `(id_modelo, versao)` e dependem dessa garantia.

#### Scenario: Trocar template de modelo publicado
- **WHEN** se altera `id_template_estrutural` de um modelo `ATIVO`
- **THEN** a alteração é rejeitada

#### Scenario: Trocar a chave de modelo publicado
- **WHEN** se altera `versao` ou `id_modelo` de um modelo `ATIVO`
- **THEN** a alteração é rejeitada

#### Scenario: Incluir campo em template publicado
- **WHEN** se inclui uma associação de campo em um template referenciado por um modelo `ATIVO` ou `INATIVO`
- **THEN** a inclusão é rejeitada

#### Scenario: Mover associação para template publicado
- **WHEN** se altera uma associação de um template em rascunho para apontar para um template referenciado por modelo publicado
- **THEN** a alteração é rejeitada

#### Scenario: Editar rascunho
- **WHEN** se inclui uma associação de campo em um template referenciado apenas por modelos `RASCUNHO`
- **THEN** a inclusão é aceita

#### Scenario: Edição concorrente com publicação
- **WHEN** uma sessão inclui uma associação no template T sem confirmar e outra sessão publica um modelo que referencia T
- **THEN** a publicação espera a primeira sessão terminar e valida o template já com a associação incluída

#### Scenario: Publicação concorrente com edição
- **WHEN** uma sessão publica um modelo que referencia T sem confirmar e outra sessão tenta incluir uma associação em T
- **THEN** a inclusão espera a publicação terminar e é rejeitada por o template estar publicado

### Requirement: Datas de auditoria em horário de São Paulo
Todas as tabelas do catálogo, incluindo as associações template–campo, SHALL ter `data_hora_criacao` e `data_hora_atualizacao` como instantes com fuso (`timestamptz NOT NULL`), preenchidos pelo banco na inclusão quando não informados. O banco MUST NOT ter trigger de auditoria: renovar `data_hora_atualizacao` em cada alteração é responsabilidade da aplicação. `data_hora_criacao` MUST NOT poder ser alterada pela role de escrita do catálogo. O fuso padrão de exibição do banco MUST ser `America/Sao_Paulo`.

#### Scenario: Inclusão sem informar datas
- **WHEN** se insere uma linha sem informar as datas de auditoria
- **THEN** ambas recebem o instante atual

#### Scenario: Banco não renova a data de atualização
- **WHEN** se altera uma linha sem informar `data_hora_atualizacao`
- **THEN** `data_hora_atualizacao` permanece com o valor anterior

#### Scenario: Aplicação renova a data de atualização
- **WHEN** a role de escrita altera uma linha informando `data_hora_atualizacao = now()`
- **THEN** a alteração é aceita e a data passa a ser o instante informado

#### Scenario: Data de criação protegida
- **WHEN** a role de escrita tenta alterar `data_hora_criacao` de qualquer tabela do catálogo
- **THEN** o comando é rejeitado com `permission denied`

#### Scenario: Sem triggers de auditoria
- **WHEN** se consultam os triggers do schema `catalogo`
- **THEN** nenhum trigger altera `data_hora_atualizacao` e a função `fn_atualiza_data_hora` não existe

### Requirement: Modelo completo pode ser carregado em uma consulta
O catálogo SHALL oferecer a view `catalogo.vw_modelo_completo`, que devolve uma linha por `(id_modelo, versao)` com os campos dos dois templates em listas separadas, ordenadas por `ordem`. Cada campo MUST trazer tipo, obrigatoriedade, posição de indexador (no estrutural), a descrição do template, a `descricao_base` e a descrição efetiva. Cada lista MUST ter exatamente um elemento por associação, sem duplicação entre templates. O catálogo SHALL oferecer também uma consulta que resolve a versão `ATIVO` de um `id_modelo`. Essas consultas são a fonte de carga do cache.

#### Scenario: Carregar modelo para cache
- **WHEN** se consulta `vw_modelo_completo` para um `(id_modelo, versao)` do seed
- **THEN** o resultado traz os campos dos dois templates na ordem definida, com os indexadores identificados por posição

#### Scenario: Sem duplicação de campos
- **WHEN** se consulta `vw_modelo_completo` para um modelo com N campos estruturais e M campos variáveis
- **THEN** `campos_estruturais` tem exatamente N elementos e `campos_variaveis` tem exatamente M

#### Scenario: Resolver versão vigente
- **WHEN** se consulta a versão vigente de `COMPPIX`
- **THEN** o resultado é a única versão em `ATIVO`, ou vazio se nenhuma estiver ativa
