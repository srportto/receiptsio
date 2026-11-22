## ADDED Requirements

### Requirement: Campo é único por nome e tipo de dado
O catálogo SHALL impedir dois campos com o mesmo nome (comparado sem diferenciar maiúsculas/minúsculas) e o mesmo `tipo_dado`. O mesmo nome com tipos de dado diferentes MUST ser aceito.

#### Scenario: Nome e tipo repetidos
- **WHEN** existe o campo `cpf` do tipo `TEXTO` e se insere o campo `CPF` do tipo `TEXTO`
- **THEN** a inserção é rejeitada por violação de unicidade

#### Scenario: Mesmo nome com tipo diferente
- **WHEN** existe o campo `valor` do tipo `DECIMAL` e se insere o campo `valor` do tipo `TEXTO`
- **THEN** a inserção é aceita

### Requirement: Tipo de dado do campo pertence a domínio fechado
O catálogo SHALL aceitar em `tipo_dado` somente valores do domínio definido no design (ex.: `TEXTO`, `INTEIRO`, `DECIMAL`, `DATA`, `DATA_HORA`, `BOOLEANO`).

#### Scenario: Tipo fora do domínio
- **WHEN** se insere um campo com `tipo_dado = 'texto livre'`
- **THEN** a inserção é rejeitada por violação de CHECK

### Requirement: Campo em uso não pode ser removido
O catálogo SHALL impedir a exclusão de um campo associado a qualquer template estrutural ou variável.

#### Scenario: Excluir campo associado
- **WHEN** se exclui um campo que está associado a um template
- **THEN** a exclusão é rejeitada por violação de chave estrangeira

### Requirement: Campo aparece no máximo uma vez por template
Cada template (estrutural ou variável) SHALL conter um mesmo campo no máximo uma vez, e cada posição de `ordem` MUST ser única dentro do template.

#### Scenario: Campo repetido no template
- **WHEN** se associa ao template T um campo que já está associado a T
- **THEN** a associação é rejeitada por violação de chave primária

#### Scenario: Ordem repetida no template
- **WHEN** se associam dois campos diferentes ao template T com a mesma `ordem`
- **THEN** a segunda associação é rejeitada por violação de unicidade

### Requirement: Mesmo campo pode compor template estrutural e variável
O catálogo SHALL permitir que um campo esteja associado ao template estrutural e ao template variável de um mesmo modelo.

#### Scenario: Campo nos dois templates do modelo
- **WHEN** o campo `data_pagamento` é associado ao template estrutural E ao template variável referenciados pelo mesmo modelo
- **THEN** ambas as associações são aceitas

### Requirement: Indexadores ocupam posições de 1 a 5 no template estrutural
A associação template estrutural–campo SHALL ter `posicao_indexador` nula (campo não indexador) ou entre 1 e 5. Cada posição MUST ser única dentro do template. Um campo indexador MUST NOT aceitar nulo/vazio. O template variável MUST NOT ter indexadores.

#### Scenario: Posição fora da faixa
- **WHEN** se associa um campo com `posicao_indexador = 6`
- **THEN** a associação é rejeitada por violação de CHECK

#### Scenario: Posição repetida
- **WHEN** o template T já tem um indexador na posição 2 e se associa outro campo na posição 2
- **THEN** a associação é rejeitada por violação de unicidade

#### Scenario: Indexador que aceita nulo
- **WHEN** se associa um campo com `posicao_indexador = 1` e `aceita_nulo_vazio = true`
- **THEN** a associação é rejeitada por violação de CHECK

### Requirement: Modelo é identificado por código e versão
O modelo SHALL ser identificado por `(id_modelo, versao)`. `id_modelo` MUST ter de 1 a 10 caracteres em `[A-Z0-9_]` (garantindo no máximo 10 bytes) e `versao` MUST estar entre 1 e 999.

#### Scenario: Duas versões do mesmo modelo
- **WHEN** existe `(COMPPIX, 1)` e se insere `(COMPPIX, 2)`
- **THEN** a inserção é aceita

#### Scenario: Código inválido
- **WHEN** se insere um modelo com `id_modelo = 'comp-pix-çã'`
- **THEN** a inserção é rejeitada por violação de CHECK

#### Scenario: Versão fora da faixa
- **WHEN** se insere um modelo com `versao = 1000`
- **THEN** a inserção é rejeitada por violação de CHECK

### Requirement: Modelo é composto por um template estrutural e um variável
Todo modelo SHALL referenciar exatamente um template estrutural e exatamente um template variável existentes. Um template MAY ser referenciado por vários modelos.

#### Scenario: Modelo sem template variável
- **WHEN** se insere um modelo com `id_template_variavel` nulo
- **THEN** a inserção é rejeitada por violação de NOT NULL

#### Scenario: Template inexistente
- **WHEN** se insere um modelo referenciando um UUID de template estrutural que não existe
- **THEN** a inserção é rejeitada por violação de chave estrangeira

#### Scenario: Template reutilizado
- **WHEN** dois modelos distintos referenciam o mesmo template estrutural
- **THEN** ambos são aceitos

### Requirement: Situação do modelo e versão vigente
O modelo SHALL ter `situacao` em `RASCUNHO`, `ATIVO` ou `INATIVO`, criado como `RASCUNHO`. No máximo uma versão por `id_modelo` MUST estar `ATIVO`. As transições permitidas são `RASCUNHO → ATIVO`, `ATIVO → INATIVO` e `INATIVO → ATIVO`; nenhuma situação publicada volta a `RASCUNHO`.

#### Scenario: Duas versões ativas
- **WHEN** `(COMPPIX, 1)` está `ATIVO` e se altera `(COMPPIX, 2)` para `ATIVO` sem inativar a versão 1
- **THEN** a alteração é rejeitada por violação de unicidade

#### Scenario: Troca de versão vigente na mesma transação
- **WHEN** numa mesma transação `(COMPPIX, 1)` passa a `INATIVO` e depois `(COMPPIX, 2)` passa a `ATIVO`
- **THEN** a transação é confirmada e a versão 2 é a vigente

#### Scenario: Publicado volta a rascunho
- **WHEN** se altera um modelo `ATIVO` para `RASCUNHO`
- **THEN** a alteração é rejeitada

### Requirement: Publicação exige indexador na posição 1
Um modelo SHALL passar de `RASCUNHO` para `ATIVO` somente se o seu template estrutural tiver um campo na `posicao_indexador = 1`.

#### Scenario: Publicar sem indexador principal
- **WHEN** se altera para `ATIVO` um modelo cujo template estrutural não tem indexador na posição 1
- **THEN** a alteração é rejeitada com mensagem que identifica o template

#### Scenario: Publicar com indexador principal
- **WHEN** se altera para `ATIVO` um modelo cujo template estrutural tem indexador na posição 1
- **THEN** a alteração é aceita

### Requirement: Versão publicada é imutável
Depois que um modelo sai de `RASCUNHO`, seus templates referenciados e sua composição SHALL ser imutáveis: o próprio modelo só pode alterar `situacao` (e colunas de controle), e os templates referenciados por algum modelo publicado MUST NOT ter associações de campo incluídas, alteradas ou excluídas, nem ser excluídos. Comprovantes no NoSQL referenciam `(id_modelo, versao)` e dependem dessa garantia.

#### Scenario: Trocar template de modelo publicado
- **WHEN** se altera `id_template_estrutural` de um modelo `ATIVO`
- **THEN** a alteração é rejeitada

#### Scenario: Incluir campo em template publicado
- **WHEN** se inclui uma associação de campo em um template referenciado por um modelo `ATIVO` ou `INATIVO`
- **THEN** a inclusão é rejeitada

#### Scenario: Editar rascunho
- **WHEN** se inclui uma associação de campo em um template referenciado apenas por modelos `RASCUNHO`
- **THEN** a inclusão é aceita

### Requirement: Datas de auditoria em horário de São Paulo
Toda tabela do catálogo SHALL ter `data_hora_criacao` e `data_hora_atualizacao` como instantes com fuso (`timestamptz`), preenchidas automaticamente na inclusão; `data_hora_atualizacao` MUST ser renovada automaticamente em toda alteração. O fuso padrão de exibição do banco MUST ser `America/Sao_Paulo`.

#### Scenario: Inclusão sem informar datas
- **WHEN** se insere uma linha sem informar as datas de auditoria
- **THEN** ambas recebem o instante atual

#### Scenario: Alteração renova data de atualização
- **WHEN** se altera uma linha existente
- **THEN** `data_hora_atualizacao` passa a ser o instante da alteração e `data_hora_criacao` não muda

### Requirement: Modelo completo pode ser carregado em uma consulta
O catálogo SHALL oferecer uma consulta que, dado `(id_modelo, versao)`, devolve o modelo com os dois templates e seus campos ordenados (incluindo tipo, obrigatoriedade e posição de indexador), e uma consulta que resolve a versão `ATIVO` de um `id_modelo`. Essas consultas são a fonte de carga do cache.

#### Scenario: Carregar modelo para cache
- **WHEN** se executa a consulta de modelo completo para `(COMPPIX, 1)` do seed
- **THEN** o resultado traz os campos dos dois templates na ordem definida, com os indexadores identificados por posição

#### Scenario: Resolver versão vigente
- **WHEN** se consulta a versão vigente de `COMPPIX`
- **THEN** o resultado é a única versão em `ATIVO`, ou vazio se nenhuma estiver ativa
