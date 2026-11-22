> Delegação (skill `openspec-catalogo-java`, linha "apply — SQL e banco"): agent `especialista-banco-dados`, skill `banco-de-dados-performance`.
> Prova padrão: `docker exec -i postgres18-receiptsio psql -v ON_ERROR_STOP=1 -U docker -d db-receiptsio < verificar-catalogo.sql` com código de saída lido (`echo $?`).
> Comandos executados em `infra/local/postgres/`. Sem código Java nesta change, portanto sem portão do `java-revisor`.

## 1. Limpeza da infra legada e isolamento de nomes

- [x] 1.1 Remover `migrations/v1.0.0` … `v1.1.0` (domínio `autorizacoes`), `gerar-massa-sintetica-expurgo.sql` e `gerar-massa-sintetica-representativa.sql`. Prova: `ls migrations/` vazio; `git status` lista as remoções.
- [x] 1.2 Atualizar `postgres-db-v18.yml` conforme D10/D11: container `postgres18-receiptsio`, imagem `postgres18-receiptsio-extras-partman_cron_vector:1.0`, volume `receiptsio_pg_data`, rede `receiptsio_postgres`, `DB_NAME:-db-receiptsio`, porta `${DB_PORT:-5432}:5432`, variáveis `DB_CATALOGO_LEITURA_PASSWORD`/`DB_CATALOGO_ESCRITA_PASSWORD` com `:?`, limites `1.0`/`1G`; manter `shared_preload_libraries` e `cron.database_name`; comentários do projeto de origem revisados. Prova: `docker compose --env-file ../../../.env -f postgres-db-v18.yml config` sem erro e com os nomes novos.
- [x] 1.3 Atualizar `.env.example` (`DB_NAME=db-receiptsio`, `DB_PORT`, as duas senhas de role com placeholder). Prova: `docker compose ... config` com `.env` sem `DB_CATALOGO_LEITURA_PASSWORD` falha citando a variável (cenário "Senha ausente").

## 2. Verificação primeiro (RED)

- [x] 2.1 Criar `verificar-catalogo.sql` (D12) com um bloco por cenário de `specs/catalogo-modelos-comprovante/spec.md` e os cenários de roles de `specs/postgres-local/spec.md`, tudo em `BEGIN … ROLLBACK`, contabilizando falhas e encerrando com `\q 1` se houver alguma. Comentários em português.
- [x] 2.2 Criar `migrations/v1.0.00.-extensoes-schema-timezone-funcoes.sql` (extensões `pg_cron`, `pg_partman`, `vector`; schema `catalogo`; `search_path`; `timezone America/Sao_Paulo`; `catalogo.fn_atualiza_data_hora()`), subir com volume vazio e rodar o script. Prova (RED): script executa e termina com código ≠ 0 apontando os cenários de tabelas inexistentes.

## 3. Schema do catálogo (GREEN incremental)

- [x] 3.1 `v1.0.01.-cria-tabela-campo.sql` (D6: identity, CHECK de `tipo_dado` e nome não vazio, índice único `lower(nome_campo), tipo_dado`, `version`, datas, trigger de atualização). Prova: cenários de campo do script passam.
- [x] 3.2 `v1.0.02.-cria-template-estrutural-e-campos.sql` (D4/D5/D7: `uuidv7()`, sem `indexador_1..5`, associação com `posicao_indexador`, `ordem`, `aceita_nulo_vazio`, únicos e CHECKs, FKs `ON DELETE RESTRICT`). Prova: cenários de indexador, ordem e campo repetido passam.
- [x] 3.3 `v1.0.03.-cria-template-variavel-e-campos.sql` (associação sem `posicao_indexador`). Prova: cenário "Mesmo campo pode compor template estrutural e variável" passa.
- [x] 3.4 `v1.0.04.-cria-tabela-modelo.sql` (D2: PK composta, CHECKs de código/versão/situação, FKs UUID NOT NULL, índice parcial `uk_modelo_ativo`, índices nas FKs de template). Prova: cenários de identificação, composição e "Duas versões ativas" passam.
- [x] 3.5 `v1.0.05.-triggers-imutabilidade-e-publicacao.sql` (D3/D4: imutabilidade do modelo publicado, bloqueio de escrita em associações/templates referenciados por modelo publicado, transições de situação, exigência de indexador 1 na publicação, mensagens nomeando modelo/template). Prova: cenários de imutabilidade, transição e publicação passam.

## 4. Roles, seed e consultas

- [x] 4.1 `v1.0.06.-roles-privilegio-minimo.sh` (D11: `catalogo_leitura`, `catalogo_escrita`, GRANTs no schema `catalogo` e `ALTER DEFAULT PRIVILEGES`, senhas lidas do ambiente, `set -euo pipefail`). Prova: cenários "Leitura tenta escrever" e "Escrita tenta DDL" passam; `psql -U catalogo_leitura` conecta com a senha do `.env`.
- [x] 4.2 `v1.0.07.-seed-modelo-exemplo.sql`: campos de exemplo, um template estrutural com indexadores 1 e 2, um template variável, modelo `COMPPIX` versão 1 `ATIVO` e versão 2 `RASCUNHO`. Prova: `SELECT id_modelo, versao, situacao FROM catalogo.modelo` mostra as duas versões.
- [x] 4.3 Reescrever `exemplos-queries.sql` com a consulta de modelo completo por `(id_modelo, versao)` (campos dos dois templates, ordenados, com tipo, obrigatoriedade e posição de indexador) e a consulta de versão vigente. Prova: cenários "Carregar modelo para cache" e "Resolver versão vigente" executados contra o seed com o resultado conferido.

## 5. Prova final e documentação

- [x] 5.1 Subida limpa ponta a ponta: `down -v`, `up -d --build`, aguardar `healthy`, conferir log sem `ERROR`, `LC_ALL=C ls migrations | sort` na ordem do design, extensões em `pg_extension` e `SHOW shared_preload_libraries`. Prova: saídas lidas e anotadas.
- [x] 5.2 Executar `verificar-catalogo.sql` contra o banco recém-criado. Prova: todos os cenários `OK`, `echo $?` = 0, e nenhuma linha residual (`SELECT count(*) FROM catalogo.campo` igual ao seed).
- [x] 5.3 Prova negativa do verificador: em sessão manual, `ALTER TABLE catalogo.campo DROP CONSTRAINT <check tipo_dado>` e rodar o script. Prova: cenário correspondente `FALHA` e `echo $?` ≠ 0; depois recriar o banco (`down -v` + `up`).
- [x] 5.4 Confirmar que o volume legado não foi tocado: `docker volume ls` mostra `receiptsio_pg_data` separado de `postgres_pg_data` (se existir).
- [x] 5.5 Reescrever `README.md` (domínio de comprovantes, Subir/Validar/Parar com nomes novos, migrations e numeração de dois dígitos, roles e senhas, verificação, consulta de cache; preservar a seção de receita de extensões ajustando os exemplos) e atualizar `info_pra_run_v18.txt`. Prova: todos os comandos do README executados conforme escritos.
