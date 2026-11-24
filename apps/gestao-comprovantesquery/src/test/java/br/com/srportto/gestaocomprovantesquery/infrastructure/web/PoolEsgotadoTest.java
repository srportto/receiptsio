package br.com.srportto.gestaocomprovantesquery.infrastructure.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.srportto.gestaocomprovantesquery.BancoDeTeste;
import br.com.srportto.gestaocomprovantesquery.ClienteApi;
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
 * Teto do pool: com o pool reduzido a 1 conexão e essa conexão retida, a requisição seguinte espera no máximo o
 * {@code connection-timeout} e responde 503 (não fica pendurada). Liberada a conexão, a API volta ao normal.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "spring.datasource.hikari.maximum-pool-size=1",
        "spring.datasource.hikari.connection-timeout=500"
})
class PoolEsgotadoTest {

    @DynamicPropertySource
    static void banco(DynamicPropertyRegistry registro) {
        BancoDeTeste.registrar(registro);
    }

    @LocalServerPort
    int porta;

    @Autowired
    DataSource dataSource;

    @Test
    @DisplayName("Pool esgotado: 503 em até connection-timeout (+ folga), sem pendurar; depois volta ao normal")
    void poolEsgotado() throws SQLException {
        var api = new ClienteApi(porta);

        long ms;
        try (var retida = dataSource.getConnection()) {
            assertTrue(retida.isValid(1));
            long inicio = System.nanoTime();
            var resposta = api.get("/modelos").status(503).cumpreContrato("ProblemDetails");
            ms = (System.nanoTime() - inicio) / 1_000_000;
            assertEquals("5", resposta.cabecalho("Retry-After"));
        }

        System.out.println("PoolEsgotadoTest: 503 em " + ms + " ms (connection-timeout = 500 ms)");
        assertTrue(ms >= 450, "esperou menos que o connection-timeout: " + ms + " ms");
        assertTrue(ms < 3_000, "deveria responder logo após o connection-timeout: " + ms + " ms");

        api.get("/modelos").status(200).cumpreContrato("PaginaModelos");
    }
}
