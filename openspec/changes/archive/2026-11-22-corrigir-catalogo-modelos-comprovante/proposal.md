## Why

A change `criar-banco-catalogo-modelos-comprovante` foi arquivada com todas as tarefas marcadas, mas a validação descrita em `infra/local/postgres/explicacao.md` (feita contra um container real em 2026-11-22) mostrou outra coisa:

- o catálogo **não sobe**: a v1.0.01 tem erro de sintaxe e a v1.0.06 não repassa as senhas;
- a imutabilidade da versão publicada, que sustenta o cache sem invalidação e os comprovantes do NoSQL, tem **cinco brechas comprovadas**;
- a consulta de carga do cache **duplica campos** (32/32 em vez de 8/4);
- o `verificar-catalogo.sql` **aborta**, e mesmo corrigido termina com código 0 com cenários falhando;
- faltam colunas pedidas em `docs/modelagem-dados-para-modelo-de-comprovante.txt`.

É preciso corrigir agora, antes que a aplicação Java de administração e o carregador de cache sejam construídos sobre esse esquema.

## What Changes

**Correções de execução e prova**

- Corrige `v1.0.01` (constraint `UNIQUE` com expressão, que o PostgreSQL rejeita) e `v1.0.06` (`run_sql` descartava `-v senha_...`).
- Reescreve `verificar-catalogo.sql`. Cada cenário passa a esperar um SQLSTATE exato e a usar dados próprios que não colidem com o seed. O script termina com código ≠ 0 quando algum cenário falha.
- Cria `verificar-concorrencia.sh`, que prova com duas sessões `psql` que não dá para publicar um modelo enquanto o template dele é editado.

**Mudanças de esquema e regras**

- **BREAKING (esquema):** a coluna de lock otimista `version` passa a se chamar `data_version` em `campo`, `template_estrutural`, `template_variavel` e `modelo`, para não ser confundida com a `versao` de negócio do modelo.
- **BREAKING (comportamento):** remove a função `catalogo.fn_atualiza_data_hora()` e todos os triggers de auditoria. O banco preenche as duas datas no INSERT (`DEFAULT now()`). No UPDATE, renovar `data_hora_atualizacao` passa a ser responsabilidade da aplicação. `data_hora_criacao` fica protegida por privilégio de coluna: a role de escrita não tem `UPDATE` nela.
- Mantém e corrige os triggers de imutabilidade:
  - a publicação passa a exigir indexador 1 também no `INSERT` direto como `ATIVO`;
  - `nome_campo` e `tipo_dado` ficam congelados quando o campo está em template de modelo publicado;
  - `id_modelo` e `versao` ficam congelados depois da publicação;
  - a corrida entre publicar e editar é serializada pela linha do template.
- Templates estrutural e variável ganham `descricao` (opcional), além do `nome_template` (obrigatório).
- As duas associações template–campo ganham `descricao_campo_template` (opcional; quando nula, vale a `descricao_base` do campo) e `data_hora_criacao`/`data_hora_atualizacao`. Não ganham `data_version`.
- Ajustes menores:
  - parametriza nome do banco e usuário nas migrations (hoje estão fixos em `db-receiptsio`/`docker`);
  - remove índices redundantes com a PK das associações;
  - alinha comentários de `aceita_nulo_vazio`.

**Dados e documentação**

- Corrige a consulta "modelo completo" (carga do cache) para agregar cada template separadamente.
- Substitui o seed por cenários para inspeção manual:
  - PIX com v1 `INATIVO`, v2 `ATIVO` e v3 `RASCUNHO`, cada versão com templates próprios;
  - TED usando os 5 indexadores;
  - Boleto com v1 `ATIVO` e v2 `RASCUNHO` sem indexador 1, para testar o bloqueio de publicação;
  - campos compartilhados entre modelos.
- Sobe o ambiente com `docker compose` usando o `.env` da raiz.
- Atualiza `README.md`, `explicacao.md`, `exemplos-queries.sql` e `info_pra_run_v18.txt`.

## Capabilities

### New Capabilities

<!-- Nenhuma: as duas capabilities já existem em openspec/specs/. -->

### Modified Capabilities

- `catalogo-modelos-comprovante`:
  - datas de auditoria (a renovação no UPDATE sai do banco);
  - imutabilidade ampliada (INSERT `ATIVO`, campo em uso, chave do modelo, concorrência);
  - novas colunas de descrição;
  - coluna de lock otimista `data_version`;
  - a consulta de modelo completo não pode duplicar campos;
  - associações com datas de auditoria.
- `postgres-local`:
  - a verificação precisa provar falha com código ≠ 0;
  - novo verificador de concorrência;
  - privilégio de coluna em `data_hora_criacao`;
  - seed de inspeção com os cenários acima.

## Critérios de aceite (DoR)

- **Subida:** dado volume vazio e `.env` válido, quando o compose sobe, então o log não contém `ERROR` de migration e o container fica `healthy`.
- **Verificação ok:** dado o banco recém-criado, quando `verificar-catalogo.sql` roda, então todos os cenários são `OK`, o código de saída é 0 e nenhum dado de teste permanece.
- **Verificação falha:** dada uma regra removida manualmente, quando o script roda, então o cenário correspondente é `FALHA` e o código de saída é ≠ 0.
- **Concorrência:** dadas duas sessões, uma editando o template e outra publicando o modelo, quando ambas tentam confirmar, então não existe modelo `ATIVO` cujo template tenha sido alterado depois da validação de publicação.
- **Cache:** dado o seed, quando a consulta de modelo completo roda para qualquer `(id_modelo, versao)`, então a quantidade de campos devolvidos por template é igual à de linhas da associação.
- **Inspeção:** dado o seed, quando o usuário inspeciona as tabelas, então vê os três tipos de comprovante, o ciclo de versões e o bloqueio de publicação do Boleto v2.

**Carga e recuperação:** a escrita é administrativa e rara (dezenas a centenas de modelos, hipótese do design anterior), e a leitura de produção vem do cache. A recuperação local é `down -v` seguido de `up`. Não há dado a preservar: o volume atual nunca chegou a ser criado com sucesso.

## Impact

- `infra/local/postgres/migrations/v1.0.00` … `v1.0.07`: editadas no lugar, sem migrations novas. O init só roda com volume vazio e nenhum ambiente subiu com a versão atual.
- `infra/local/postgres/verificar-catalogo.sql` (reescrito), `verificar-concorrencia.sh` (novo), `exemplos-queries.sql`, `README.md`, `explicacao.md`, `info_pra_run_v18.txt`.
- `openspec/specs/catalogo-modelos-comprovante` e `openspec/specs/postgres-local`, via delta specs.
- Aplicações futuras:
  - JPA mapeia `@Version` em `data_version`;
  - a aplicação atualiza `data_hora_atualizacao` (`@UpdateTimestamp`);
  - `data_hora_criacao` é `@Column(updatable = false)`;
  - erros de imutabilidade chegam como SQLSTATE `23514` (`check_violation`).
- Sem código Java nesta change.

## Fora de escopo

- Aplicação de administração, carregador de cache e NoSQL.
- Flyway/Liquibase e migração incremental de banco existente.
- Remover as extensões `pg_cron`, `pg_partman` e `vector` (decisão anterior mantida).
