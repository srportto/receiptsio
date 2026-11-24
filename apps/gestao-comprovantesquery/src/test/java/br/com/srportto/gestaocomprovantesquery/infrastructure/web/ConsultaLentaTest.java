package br.com.srportto.gestaocomprovantesquery.infrastructure.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.srportto.gestaocomprovantesquery.BancoDeTeste;
import br.com.srportto.gestaocomprovantesquery.ClienteApi;
import com.zaxxer.hikari.HikariDataSource;
import java.sql.SQLException;
import javax.sql.DataSource;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * Consulta acima do tempo limite: uma sessão de superusuário trava {@code catalogo.modelo} (ACCESS EXCLUSIVE), a
 * consulta da API fica esperando o lock, estoura o {@code query-timeout} (1 s aqui; 5 s em produção), a API
 * responde 503 e a conexão volta ao pool.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "spring.jdbc.template.query-timeout=1s"
})
class ConsultaLentaTest {

    @DynamicPropertySource
    static void banco(DynamicPropertyRegistry registro) {
        BancoDeTeste.registrar(registro);
    }

    @LocalServerPort
    int porta;

    @Autowired
    DataSource dataSource;

    @Test
    @DisplayName("Consulta travada estoura o tempo limite: 503 em ~1 s, conexão devolvida e API volta ao normal")
    void consultaAcimaDoLimite() throws SQLException {
        var api = new ClienteApi(porta);
        var hikari = dataSource.unwrap(HikariDataSource.class);

        try (var trava = BancoDeTeste.conexaoAdmin()) {
            trava.setAutoCommit(false);
            try (var st = trava.createStatement()) {
                st.execute("LOCK TABLE catalogo.modelo IN ACCESS EXCLUSIVE MODE");
            }

            long inicio = System.nanoTime();
            var resposta = api.get("/modelos").status(503).cumpreContrato("ProblemDetails");
            long ms = (System.nanoTime() - inicio) / 1_000_000;

            assertEquals("5", resposta.cabecalho("Retry-After"));
            assertTrue(ms >= 900, "não deveria falhar antes do query-timeout de 1 s: " + ms + " ms");
            assertTrue(ms < 5_000, "deveria falhar logo após o query-timeout: " + ms + " ms");
            // o detalhe também depende da tabela travada (a view junta modelo)
            api.get("/modelos/COMPPIX/versoes/2").status(503);
            trava.rollback();
        }

        // Trava liberada: a conexão foi devolvida e a próxima requisição funciona
        assertEquals(0, hikari.getHikariPoolMXBean().getActiveConnections(), "conexão presa no pool");
        api.get("/modelos").status(200).cumpreContrato("PaginaModelos");
    }
}
