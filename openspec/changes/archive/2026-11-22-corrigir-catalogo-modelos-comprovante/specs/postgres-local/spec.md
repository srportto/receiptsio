## ADDED Requirements

### Requirement: Nome do banco e superusuário parametrizados
As migrations SHALL usar o nome do banco e o superusuário configurados no ambiente (`DB_NAME`, `DB_USER_NAME` → `POSTGRES_DB`, `POSTGRES_USER`) e MUST NOT ter `db-receiptsio` ou `docker` fixos no código.

#### Scenario: Banco com outro nome
- **WHEN** o ambiente é iniciado com volume vazio e `DB_NAME` diferente de `db-receiptsio`
- **THEN** todas as migrations rodam sem erro e `timezone`/`search_path` ficam configurados nesse banco

### Requirement: Verificação de concorrência da publicação
O ambiente SHALL incluir o script `verificar-concorrencia.sh`, que abre duas sessões reais contra o container nos dois sentidos (editar template e depois publicar; publicar e depois editar). O script MUST terminar com código ≠ 0 se algum modelo publicado ficar com template alterado depois da validação, e MUST remover os dados que criou.

#### Scenario: Corrida bloqueada
- **WHEN** o script é executado contra o banco recém-criado
- **THEN** os dois sentidos reportam `OK`, o código de saída é 0 e nenhum dado `CONC_` permanece

#### Scenario: Proteção removida
- **WHEN** os locks de linha da publicação são removidos manualmente e o script é executado
- **THEN** o script reporta `FALHA` e termina com código ≠ 0

### Requirement: Seed de inspeção
A inicialização SHALL carregar um seed que permite inspecionar o catálogo manualmente, com:
- `COMPPIX` v1 `INATIVO`, v2 `ATIVO` e v3 `RASCUNHO`, cada versão com templates próprios;
- `COMPTED` v1 `ATIVO` com indexadores nas posições 1 a 5;
- `COMPBOL` v1 `ATIVO` só com indexador 1 e v2 `RASCUNHO` sem indexador 1;
- campos compartilhados entre modelos;
- associações com e sem `descricao_campo_template`.

#### Scenario: Conferir o seed
- **WHEN** se consulta `catalogo.modelo` após a subida
- **THEN** aparecem as seis versões com as situações acima e exatamente uma versão `ATIVO` por `id_modelo`

#### Scenario: Publicar o rascunho sem indexador 1
- **WHEN** se altera `(COMPBOL, 2)` para `ATIVO`
- **THEN** a alteração é rejeitada com mensagem que identifica o template

## MODIFIED Requirements

### Requirement: Roles de privilégio mínimo
O banco SHALL ter um role de leitura do catálogo (somente `SELECT` no schema do catálogo, incluindo views) e um role de escrita (`SELECT/INSERT/DELETE` e `UPDATE` coluna a coluna, sem DDL), ambos com `LOGIN` e senha definida na inicialização a partir das variáveis de ambiente do container, sem `psql -v` informado manualmente. O role de escrita MUST NOT ter `UPDATE` em `data_hora_criacao` de nenhuma tabela do catálogo.

#### Scenario: Leitura tenta escrever
- **WHEN** o role de leitura executa `INSERT` em `campo`
- **THEN** o comando é rejeitado com `permission denied`

#### Scenario: Escrita tenta DDL
- **WHEN** o role de escrita executa `DROP TABLE` em uma tabela do catálogo
- **THEN** o comando é rejeitado com `insufficient_privilege` ou por não ser dono da tabela

#### Scenario: Escrita altera data de criação
- **WHEN** o role de escrita executa `UPDATE ... SET data_hora_criacao = now()` em qualquer tabela do catálogo
- **THEN** o comando é rejeitado com `permission denied`

#### Scenario: Leitura consulta a view de modelo completo
- **WHEN** o role de leitura consulta `catalogo.vw_modelo_completo`
- **THEN** a consulta é aceita

### Requirement: Verificação automatizada das regras do catálogo
O ambiente SHALL incluir um script de verificação executável via `psql` que exercita cada cenário de `catalogo-modelos-comprovante` (exceto os de concorrência, cobertos por `verificar-concorrencia.sh`) em transação revertida e imprime o resultado por cenário. Cada cenário de rejeição MUST conferir o SQLSTATE exato esperado; um erro com outro SQLSTATE MUST ser reportado como falha, com o SQLSTATE e a mensagem obtidos. Os cenários MUST usar dados próprios que não colidam com o seed. O script MUST terminar com código de saída diferente de zero se algum cenário falhar.

#### Scenario: Banco correto
- **WHEN** o script é executado contra um banco recém-criado
- **THEN** todos os cenários reportam sucesso, o código de saída é 0 e nenhum dado permanece

#### Scenario: Regra quebrada
- **WHEN** uma constraint do catálogo é removida e o script é executado
- **THEN** o cenário correspondente reporta falha e o código de saída é diferente de zero

#### Scenario: Erro inesperado
- **WHEN** um cenário que espera `check_violation` recebe outro erro (por exemplo `foreign_key_violation`)
- **THEN** o cenário reporta falha com o SQLSTATE obtido, em vez de sucesso
