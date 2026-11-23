package br.com.srportto.gestaocomprovantesquery;

import com.github.dockerjava.api.exception.NotFoundException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.time.Duration;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.testcontainers.DockerClientFactory;
import org.testcontainers.containers.BindMode;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;

/**
 * PostgreSQL real dos testes: a imagem do catálogo (com pg_cron, pg_partman e pgvector) e as migrations de
 * {@code infra/local/postgres/migrations}, aplicadas pelo entrypoint como no docker compose. Um único contêiner
 * por execução, compartilhado entre as classes de teste.
 *
 * <p>Os dados são os do seed (v1.0.07). Os testes só leem; quem precisar travar ou escrever usa
 * {@link #conexaoAdmin()}.
 */
public final class BancoDeTeste {

    /** Imagem construída por {@code docker compose ... build} em infra/local/postgres. */
    public static final String IMAGEM = "postgres18-receiptsio-extras-partman_cron_vector:1.0";

    public static final String BANCO = "db_catalogo_teste";
    private static final String USUARIO_ADMIN = "admin_teste";
    private static final String SENHA_ADMIN = "senha_admin_teste";
    private static final String SENHA_LEITURA = "senha_leitura_teste";
    private static final String SENHA_ESCRITA = "senha_escrita_teste";

    private static final GenericContainer<?> CONTAINER;

    static {
        exigirImagem();
        CONTAINER = new GenericContainer<>(IMAGEM)
                .withEnv("POSTGRES_DB", BANCO)
                .withEnv("POSTGRES_USER", USUARIO_ADMIN)
                .withEnv("POSTGRES_PASSWORD", SENHA_ADMIN)
                .withEnv("DB_CATALOGO_LEITURA_PASSWORD", SENHA_LEITURA)
                .withEnv("DB_CATALOGO_ESCRITA_PASSWORD", SENHA_ESCRITA)
                .withCommand("postgres",
                        "-c", "shared_preload_libraries=pg_partman_bgw,pg_cron",
                        "-c", "cron.database_name=" + BANCO)
                .withFileSystemBind(pastaMigrations().toString(), "/docker-entrypoint-initdb.d", BindMode.READ_ONLY)
                .withExposedPorts(5432)
                // o entrypoint sobe um servidor temporário para as migrations e depois o definitivo: 2 mensagens
                .waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*\\s", 2)
                        .withStartupTimeout(Duration.ofMinutes(3)));
        CONTAINER.start();
    }

    private BancoDeTeste() {
    }

    private static void exigirImagem() {
        try {
            DockerClientFactory.instance().client().inspectImageCmd(IMAGEM).exec();
        } catch (NotFoundException e) {
            throw new IllegalStateException("Imagem " + IMAGEM + " não existe neste Docker. Construa-a antes: "
                    + "cd infra/local/postgres && docker compose --env-file ../../../.env -f postgres-db-v18.yml build",
                    e);
        }
    }

    private static Path pastaMigrations() {
        Path pasta = Path.of("").toAbsolutePath().resolve("../../infra/local/postgres/migrations").normalize();
        if (!Files.isDirectory(pasta)) {
            throw new IllegalStateException("Pasta de migrations não encontrada: " + pasta);
        }
        return pasta;
    }

    public static String urlJdbc() {
        return "jdbc:postgresql://" + CONTAINER.getHost() + ":" + CONTAINER.getMappedPort(5432) + "/" + BANCO;
    }

    /** Aponta a aplicação para o banco do teste, com a role de leitura (a mesma que roda em produção). */
    public static void registrar(DynamicPropertyRegistry registro) {
        registro.add("spring.datasource.url", BancoDeTeste::urlJdbc);
        registro.add("spring.datasource.username", () -> "catalogo_leitura");
        registro.add("spring.datasource.password", () -> SENHA_LEITURA);
    }

    /** Conexão de superusuário, para travar tabelas e conferir contagens fora da aplicação. */
    public static Connection conexaoAdmin() throws SQLException {
        return DriverManager.getConnection(urlJdbc(), USUARIO_ADMIN, SENHA_ADMIN);
    }

    /** Conexão como a role de leitura, a mesma credencial que a aplicação usa. */
    public static Connection conexaoLeitura() throws SQLException {
        return DriverManager.getConnection(urlJdbc(), "catalogo_leitura", SENHA_LEITURA);
    }
}
