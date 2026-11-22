## ADDED Requirements

### Requirement: Subida limpa com volume vazio
O ambiente SHALL subir com `docker compose --env-file ../../../.env -f postgres-db-v18.yml up -d` a partir de volume vazio, aplicando todas as migrations sem erro, e o container MUST ficar `healthy`.

#### Scenario: Primeira subida
- **WHEN** o volume `receiptsio_pg_data` não existe e o compose é iniciado com `.env` válido
- **THEN** o log do container não contém `ERROR` de migration e `docker inspect` reporta `healthy`

### Requirement: Migrations aplicadas na ordem pretendida
Os arquivos de `migrations/` SHALL ter nomes cuja ordenação lexicográfica (a usada por `docker-entrypoint-initdb.d`) coincida com a ordem de aplicação pretendida.

#### Scenario: Ordenação lexicográfica
- **WHEN** se lista `migrations/` com `LC_ALL=C sort`
- **THEN** a ordem obtida é a mesma ordem de versões declarada no design (ex.: `v1.0.09` antes de `v1.0.10`)

### Requirement: Nomes de Docker isolados do projeto
Container, volume e rede SHALL ter nomes próprios do receiptsio (`postgres18-receiptsio`, `receiptsio_pg_data`, `receiptsio_postgres`) e MUST NOT reutilizar os nomes do projeto de origem (`postgres18-kiq`, `postgres_pg_data`, `postgres_default`).

#### Scenario: Volume legado presente na máquina
- **WHEN** o volume `postgres_pg_data` de outro projeto existe na máquina e o compose do receiptsio é iniciado
- **THEN** um volume novo `receiptsio_pg_data` é criado, as migrations do catálogo rodam e o volume legado não é alterado

### Requirement: Segredos obrigatórios vindos do .env
A senha do superusuário e as senhas dos roles de aplicação SHALL vir do `.env` da raiz; a ausência de qualquer uma MUST interromper a subida com mensagem que nomeia a variável ausente.

#### Scenario: Senha ausente
- **WHEN** o compose é iniciado sem `DB_PASSWORD` definida
- **THEN** o Compose falha antes de criar o container, citando `DB_PASSWORD`

### Requirement: Extensões disponíveis
O banco SHALL ter as extensões `pg_cron`, `pg_partman` e `vector` criadas, e `shared_preload_libraries` MUST conter `pg_partman_bgw,pg_cron`.

#### Scenario: Conferir extensões
- **WHEN** se consulta `pg_extension` e `SHOW shared_preload_libraries`
- **THEN** as três extensões aparecem e as duas bibliotecas estão carregadas

### Requirement: Roles de privilégio mínimo
O banco SHALL ter um role de leitura do catálogo (somente `SELECT` no schema do catálogo) e um role de escrita (`SELECT/INSERT/UPDATE/DELETE`, sem DDL), ambos com `LOGIN` e senha definida na inicialização sem uso de variável `psql -v` informada manualmente.

#### Scenario: Leitura tenta escrever
- **WHEN** o role de leitura executa `INSERT` em `campo`
- **THEN** o comando é rejeitado com `permission denied`

#### Scenario: Escrita tenta DDL
- **WHEN** o role de escrita executa `DROP TABLE` em uma tabela do catálogo
- **THEN** o comando é rejeitado

### Requirement: Verificação automatizada das regras do catálogo
O ambiente SHALL incluir um script de verificação executável via `psql` que exercita cada cenário de `catalogo-modelos-comprovante` em transação revertida, imprime o resultado por cenário e termina com código de saída diferente de zero se algum cenário falhar.

#### Scenario: Banco correto
- **WHEN** o script é executado contra um banco recém-criado
- **THEN** todos os cenários reportam sucesso, o código de saída é 0 e nenhum dado permanece

#### Scenario: Regra quebrada
- **WHEN** uma constraint do catálogo é removida e o script é executado
- **THEN** o cenário correspondente reporta falha e o código de saída é diferente de zero
