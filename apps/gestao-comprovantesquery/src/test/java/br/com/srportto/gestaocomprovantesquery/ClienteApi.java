package br.com.srportto.gestaocomprovantesquery;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** Cliente HTTP dos testes de API: chama a aplicação de verdade (servidor real, porta aleatória). */
public final class ClienteApi {

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final HttpClient HTTP = HttpClient.newBuilder()
            .version(HttpClient.Version.HTTP_1_1).connectTimeout(Duration.ofSeconds(5)).build();

    private final int porta;

    public ClienteApi(int porta) {
        this.porta = porta;
    }

    /** Resposta já lida: status, cabeçalhos e corpo (texto e JSON). */
    public record Resposta(HttpResponse<String> http) {
        public int status() {
            return http.statusCode();
        }

        public String corpo() {
            return http.body();
        }

        public String cabecalho(String nome) {
            return http.headers().firstValue(nome).orElse("");
        }

        public JsonNode json() {
            return JSON.readTree(http.body());
        }

        public Resposta status(int esperado) {
            assertEquals(esperado, status(), corpo());
            return this;
        }

        /** Confere que o corpo cumpre o schema nomeado do openapi.yaml. */
        public Resposta cumpreContrato(String schema) {
            var erros = ContratoOpenApi.validar(schema, corpo());
            assertEquals(java.util.List.of(), erros, "corpo fora do contrato " + schema + ": " + corpo());
            return this;
        }
    }

    public Resposta get(String caminho) {
        return enviar("GET", caminho);
    }

    public Resposta enviar(String metodo, String caminho) {
        try {
            var req = HttpRequest.newBuilder(URI.create("http://localhost:" + porta + caminho))
                    .timeout(Duration.ofSeconds(30))
                    .method(metodo, HttpRequest.BodyPublishers.noBody())
                    .build();
            return new Resposta(HTTP.send(req, HttpResponse.BodyHandlers.ofString()));
        } catch (Exception e) {
            throw new IllegalStateException("Falha ao chamar " + metodo + " " + caminho, e);
        }
    }
}
