package br.com.srportto.gestaocomprovantesquery.infrastructure.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.srportto.gestaocomprovantesquery.ClienteApi;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

/**
 * Banco indisponível (porta fechada): a aplicação sobe, responde 503 com Retry-After nas consultas, mantém 400/405
 * (que não precisam do banco) e não vaza detalhe interno.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "spring.datasource.url=jdbc:postgresql://localhost:1/inexistente",
        "spring.datasource.username=catalogo_leitura",
        "spring.datasource.password=qualquer",
        "spring.datasource.hikari.connection-timeout=500"
})
class BancoForaDoArTest {

    /** Trechos que nunca podem aparecer no corpo de uma resposta de erro. */
    private static final List<String> PROIBIDOS = List.of("jdbc", "postgresql", "localhost", "Connection", "catalogo",
            "SELECT", "Exception", "at br.com", "qualquer");

    @LocalServerPort
    int porta;

    ClienteApi api;

    @BeforeEach
    void iniciar() {
        api = new ClienteApi(porta);
    }

    private static void semVazamento(String corpo) {
        for (String trecho : PROIBIDOS) {
            assertFalse(corpo.contains(trecho), "o corpo vazou '" + trecho + "': " + corpo);
        }
    }

    @Test
    @DisplayName("Listagem com banco fora do ar: 503, Retry-After e Problem Details sem detalhe interno")
    void listagemIndisponivel() {
        long inicio = System.nanoTime();
        var resposta = api.get("/modelos").status(503).cumpreContrato("ProblemDetails");
        long ms = (System.nanoTime() - inicio) / 1_000_000;

        assertTrue(resposta.cabecalho("Content-Type").startsWith("application/problem+json"));
        assertEquals("5", resposta.cabecalho("Retry-After"));
        assertEquals("Serviço indisponível", resposta.json().get("title").asString());
        semVazamento(resposta.corpo());
        assertTrue(ms < 5_000, "deveria falhar em até connection-timeout + folga, levou " + ms + " ms");
    }

    @Test
    @DisplayName("Detalhe com banco fora do ar: também 503")
    void detalheIndisponivel() {
        var resposta = api.get("/modelos/COMPPIX/versoes/2").status(503).cumpreContrato("ProblemDetails");
        assertEquals("5", resposta.cabecalho("Retry-After"));
        semVazamento(resposta.corpo());
    }

    @Test
    @DisplayName("Parâmetros inválidos dão 400 mesmo sem banco: a validação vem antes de qualquer consulta")
    void validacaoAntesDoBanco() {
        api.get("/modelos?situacao=XYZ").status(400).cumpreContrato("ProblemDetails");
        api.get("/modelos?size=500").status(400).cumpreContrato("ProblemDetails");
        api.get("/modelos/comppix/versoes/0").status(400).cumpreContrato("ProblemDetails");
    }

    @Test
    @DisplayName("Escrita continua 405 sem banco")
    void escritaSemBanco() {
        api.enviar("POST", "/modelos").status(405).cumpreContrato("ProblemDetails");
    }

    @Test
    @DisplayName("A aplicação segue viva: /disponibilidade, liveness e readiness 200; o banco aparece só em /dependencias")
    void aplicacaoViva() {
        api.get("/disponibilidade").status(200);
        api.get("/actuator/health/liveness").status(200);
        api.get("/actuator/health/readiness").status(200);
        api.get("/actuator/health/dependencias").status(503);
    }
}
