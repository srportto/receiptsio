package br.com.srportto.gestaocomprovantesquery.infrastructure.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.srportto.gestaocomprovantesquery.ClienteApi;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Falha não prevista: 500 em Problem Details genérico; a causa (com SQL e segredo) fica só no log. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "spring.datasource.url=jdbc:postgresql://localhost:1/inexistente",
        "spring.datasource.username=catalogo_leitura",
        "spring.datasource.password=qualquer"
})
@Import(ErroInesperadoTest.ControllerQueFalha.class)
class ErroInesperadoTest {

    /** Endpoint só dos testes: lança uma exceção cheia de detalhes internos. */
    @RestController
    static class ControllerQueFalha {
        @GetMapping("/teste/falha")
        String falha() {
            throw new IllegalStateException("SELECT * FROM catalogo.campo WHERE senha = 'segredo123' falhou");
        }
    }

    @LocalServerPort
    int porta;

    @Test
    @DisplayName("Exceção inesperada vira 500 genérico, no contrato, sem SQL, tabela, segredo ou pilha")
    void erroInesperado() {
        var resposta = new ClienteApi(porta).get("/teste/falha").status(500).cumpreContrato("ProblemDetails");
        assertTrue(resposta.cabecalho("Content-Type").startsWith("application/problem+json"));
        assertEquals("Erro interno", resposta.json().get("title").asString());
        assertEquals("Erro interno", resposta.json().get("detail").asString());
        for (String proibido : new String[] {"SELECT", "catalogo", "segredo123", "IllegalStateException", "at br.com"}) {
            assertFalse(resposta.corpo().contains(proibido), "vazou '" + proibido + "': " + resposta.corpo());
        }
    }
}
