package br.com.srportto.gestaocomprovantesquery.infrastructure.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import br.com.srportto.gestaocomprovantesquery.BancoDeTeste;
import br.com.srportto.gestaocomprovantesquery.ClienteApi;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import tools.jackson.databind.JsonNode;

/**
 * API de ponta a ponta: servidor real, PostgreSQL real com o seed e a role de leitura. Toda resposta, de sucesso ou
 * de erro, também é validada contra os schemas de {@code docs/contratos-rest/.../openapi.yaml}.
 *
 * <p>Seed: COMPPIX v1 INATIVO / v2 ATIVO / v3 RASCUNHO; COMPTED v1 ATIVO; COMPBOL v1 ATIVO / v2 RASCUNHO.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ModelosApiTest {

    @DynamicPropertySource
    static void banco(DynamicPropertyRegistry registro) {
        BancoDeTeste.registrar(registro);
    }

    @LocalServerPort
    int porta;

    ClienteApi api;

    @BeforeEach
    void iniciar() {
        api = new ClienteApi(porta);
    }

    private static List<String> chaves(JsonNode pagina) {
        var chaves = new ArrayList<String>();
        for (JsonNode item : pagina.get("items")) {
            chaves.add(item.get("idModelo").asString() + ":" + item.get("versao").asInt());
        }
        return chaves;
    }

    private static List<String> parametrosComErro(JsonNode problema) {
        var nomes = new ArrayList<String>();
        for (JsonNode erro : problema.get("errors")) {
            nomes.add(erro.get("parametro").asString());
        }
        return nomes;
    }

    // ---------------------------------------------------------------- listagem

    @Test
    @DisplayName("GET /modelos sem filtro: 200, todos os 6 modelos na ordem fixa e objeto pagination")
    void listarSemFiltro() {
        var resposta = api.get("/modelos").status(200).cumpreContrato("PaginaModelos");
        assertTrue(resposta.cabecalho("Content-Type").startsWith("application/json"));
        assertEquals(List.of("COMPBOL:2", "COMPBOL:1", "COMPPIX:3", "COMPPIX:2", "COMPPIX:1", "COMPTED:1"),
                chaves(resposta.json()));
        var pagination = resposta.json().get("pagination");
        assertEquals(1, pagination.get("page").asInt());
        assertEquals(20, pagination.get("size").asInt());
        assertEquals(6, pagination.get("totalElements").asInt());
        assertEquals(1, pagination.get("totalPages").asInt());
    }

    @Test
    @DisplayName("Cada item da listagem traz idModelo, versao, descricao, situacao e dataHoraAtualizacao")
    void camposDoItem() {
        var item = api.get("/modelos?idModelo=COMPPIX&versao=2").status(200).json().get("items").get(0);
        assertEquals("COMPPIX", item.get("idModelo").asString());
        assertEquals(2, item.get("versao").asInt());
        assertEquals("ATIVO", item.get("situacao").asString());
        assertFalse(item.get("descricao").asString().isBlank());
        assertTrue(item.get("dataHoraAtualizacao").asString().matches("\\d{4}-\\d{2}-\\d{2}T.*"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"ATIVO", "RASCUNHO", "INATIVO"})
    @DisplayName("situacao filtra: todos os itens têm a situação pedida")
    void filtrarPorSituacao(String situacao) {
        var corpo = api.get("/modelos?situacao=" + situacao).status(200).cumpreContrato("PaginaModelos").json();
        assertFalse(corpo.get("items").isEmpty());
        for (JsonNode item : corpo.get("items")) {
            assertEquals(situacao, item.get("situacao").asString());
        }
    }

    @Test
    @DisplayName("Ativos: 3 modelos; rascunhos: 2")
    void quantidades() {
        assertEquals(List.of("COMPBOL:1", "COMPPIX:2", "COMPTED:1"),
                chaves(api.get("/modelos?situacao=ATIVO").status(200).json()));
        assertEquals(List.of("COMPBOL:2", "COMPPIX:3"),
                chaves(api.get("/modelos?situacao=RASCUNHO").status(200).json()));
    }

    @Test
    @DisplayName("idModelo sem versão devolve todas as versões, em qualquer situação")
    void porModelo() {
        var corpo = api.get("/modelos?idModelo=COMPPIX").status(200).cumpreContrato("PaginaModelos").json();
        assertEquals(List.of("COMPPIX:3", "COMPPIX:2", "COMPPIX:1"), chaves(corpo));
    }

    @Test
    @DisplayName("idModelo e versao devolvem no máximo um item")
    void porModeloEVersao() {
        assertEquals(List.of("COMPPIX:2"),
                chaves(api.get("/modelos?idModelo=COMPPIX&versao=2").status(200).cumpreContrato("PaginaModelos").json()));
    }

    @Test
    @DisplayName("Filtros combinados: rascunhos de COMPBOL")
    void combinados() {
        assertEquals(List.of("COMPBOL:2"),
                chaves(api.get("/modelos?idModelo=COMPBOL&situacao=RASCUNHO").status(200).json()));
    }

    @Test
    @DisplayName("Sem resultado: 200 com items vazio, totalElements 0 e totalPages 0")
    void semResultado() {
        var pagination = api.get("/modelos?idModelo=COMPPIX&versao=999").status(200)
                .cumpreContrato("PaginaModelos").json().get("pagination");
        assertEquals(0, pagination.get("totalElements").asInt());
        assertEquals(0, pagination.get("totalPages").asInt());
    }

    @Test
    @DisplayName("Parâmetros em branco valem como ausentes")
    void emBranco() {
        assertEquals(6, api.get("/modelos?situacao=&idModelo=&versao=&page=&size=").status(200).json()
                .get("items").size());
    }

    @Test
    @DisplayName("Paginação: page=2&size=2 traz o 3º e o 4º; total 6 e 3 páginas")
    void segundaPagina() {
        var corpo = api.get("/modelos?page=2&size=2").status(200).cumpreContrato("PaginaModelos").json();
        assertEquals(List.of("COMPPIX:3", "COMPPIX:2"), chaves(corpo));
        assertEquals(2, corpo.get("pagination").get("page").asInt());
        assertEquals(3, corpo.get("pagination").get("totalPages").asInt());
    }

    @Test
    @DisplayName("Página além da última: 200, items vazio e total real")
    void alemDaUltima() {
        var corpo = api.get("/modelos?page=99").status(200).cumpreContrato("PaginaModelos").json();
        assertTrue(corpo.get("items").isEmpty());
        assertEquals(6, corpo.get("pagination").get("totalElements").asInt());
    }

    // ----------------------------------------------------------------- detalhe

    @Test
    @DisplayName("Detalhe de COMPTED v1: 5 indexadores (1 a 5), campos em ordem e descrição efetiva")
    void detalheComIndexadores() {
        var corpo = api.get("/modelos/COMPTED/versoes/1").status(200).cumpreContrato("ModeloDetalhe").json();
        assertEquals("ATIVO", corpo.get("situacao").asString());
        var posicoes = new ArrayList<Integer>();
        var ordens = new ArrayList<Integer>();
        for (JsonNode campo : corpo.get("templateEstrutural").get("campos")) {
            ordens.add(campo.get("ordem").asInt());
            if (!campo.get("posicaoIndexador").isNull()) {
                posicoes.add(campo.get("posicaoIndexador").asInt());
            }
            assertFalse(campo.get("descricaoEfetiva").isNull());
        }
        posicoes.sort(Integer::compare);
        assertEquals(List.of(1, 2, 3, 4, 5), posicoes);
        assertEquals(ordens.stream().sorted().toList(), ordens);
        assertTrue(corpo.get("templateVariavel").get("campos").isArray());
    }

    @Test
    @DisplayName("Detalhe de rascunho COMPBOL v2: 200, RASCUNHO e nenhum campo com indexador 1")
    void detalheRascunho() {
        var corpo = api.get("/modelos/COMPBOL/versoes/2").status(200).cumpreContrato("ModeloDetalhe").json();
        assertEquals("RASCUNHO", corpo.get("situacao").asString());
        for (JsonNode campo : corpo.get("templateEstrutural").get("campos")) {
            assertFalse(campo.get("posicaoIndexador").isInt() && campo.get("posicaoIndexador").asInt() == 1);
        }
    }

    @Test
    @DisplayName("Detalhe de versão INATIVA também responde")
    void detalheInativo() {
        assertEquals("INATIVO",
                api.get("/modelos/COMPPIX/versoes/1").status(200).cumpreContrato("ModeloDetalhe").json()
                        .get("situacao").asString());
    }

    @Test
    @DisplayName("Modelo inexistente: 404 application/problem+json dentro do contrato")
    void detalheInexistente() {
        var resposta = api.get("/modelos/COMPPIX/versoes/999").status(404).cumpreContrato("ProblemDetails");
        assertTrue(resposta.cabecalho("Content-Type").startsWith("application/problem+json"));
        assertEquals("Não existe o modelo COMPPIX versão 999.", resposta.json().get("detail").asString());
    }

    // ------------------------------------------------------------- validação

    @Test
    @DisplayName("situacao desconhecida: 400 com errors citando situacao")
    void situacaoDesconhecida() {
        var resposta = api.get("/modelos?situacao=XYZ").status(400).cumpreContrato("ProblemDetails");
        assertTrue(resposta.cabecalho("Content-Type").startsWith("application/problem+json"));
        assertEquals(List.of("situacao"), parametrosComErro(resposta.json()));
    }

    @Test
    @DisplayName("size acima do teto: 400 com errors citando size")
    void sizeAcimaDoTeto() {
        var resposta = api.get("/modelos?size=500").status(400).cumpreContrato("ProblemDetails");
        assertEquals(List.of("size"), parametrosComErro(resposta.json()));
    }

    @Test
    @DisplayName("Vários parâmetros inválidos: errors lista todos")
    void variosErros() {
        var resposta = api.get("/modelos?situacao=XYZ&size=500&page=0&versao=1000&idModelo=abc")
                .status(400).cumpreContrato("ProblemDetails");
        assertEquals(List.of("situacao", "idModelo", "versao", "page", "size"), parametrosComErro(resposta.json()));
    }

    @Test
    @DisplayName("Path inválido: 400 com errors citando idModelo e versao")
    void pathInvalido() {
        var resposta = api.get("/modelos/comppix/versoes/0").status(400).cumpreContrato("ProblemDetails");
        assertEquals(List.of("idModelo", "versao"), parametrosComErro(resposta.json()));
    }

    @Test
    @DisplayName("versao não numérica no path: 400, não 500")
    void versaoNaoNumerica() {
        var resposta = api.get("/modelos/COMPPIX/versoes/abc").status(400).cumpreContrato("ProblemDetails");
        assertEquals(List.of("versao"), parametrosComErro(resposta.json()));
    }

    // ------------------------------------------------- somente leitura e erros

    @ParameterizedTest
    @ValueSource(strings = {"POST", "PUT", "PATCH", "DELETE"})
    @DisplayName("Métodos de escrita não existem: 405 application/problem+json")
    void escritaNaoExiste(String metodo) {
        var resposta = api.enviar(metodo, "/modelos").status(405).cumpreContrato("ProblemDetails");
        assertTrue(resposta.cabecalho("Content-Type").startsWith("application/problem+json"));
        assertTrue(resposta.cabecalho("Allow").contains("GET"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"POST", "PUT", "PATCH", "DELETE"})
    @DisplayName("Escrita também é recusada no detalhe")
    void escritaNoDetalhe(String metodo) {
        api.enviar(metodo, "/modelos/COMPPIX/versoes/2").status(405).cumpreContrato("ProblemDetails");
    }

    @Test
    @DisplayName("Rota inexistente: 404 em Problem Details")
    void rotaInexistente() {
        api.get("/nao-existe").status(404).cumpreContrato("ProblemDetails");
    }

    @Test
    @DisplayName("GET /disponibilidade responde 200 com o nome da aplicação")
    void disponibilidade() {
        var corpo = api.get("/disponibilidade").status(200).json();
        assertEquals("gestao-comprovantesquery", corpo.get("aplicacao").asString());
        assertEquals("DISPONIVEL", corpo.get("status").asString());
    }

    @Test
    @DisplayName("Probes liveness e readiness respondem 200")
    void probes() {
        api.get("/actuator/health/liveness").status(200);
        api.get("/actuator/health/readiness").status(200);
    }
}
