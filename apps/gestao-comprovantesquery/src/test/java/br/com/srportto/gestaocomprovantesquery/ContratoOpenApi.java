package br.com.srportto.gestaocomprovantesquery;

import com.networknt.schema.Error;
import com.networknt.schema.Schema;
import com.networknt.schema.SchemaRegistry;
import com.networknt.schema.SpecificationVersion;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.dataformat.yaml.YAMLMapper;

/**
 * Valida corpos de resposta contra os schemas de {@code docs/contratos-rest/gestao-comprovantesquery/openapi.yaml},
 * a fonte da verdade do contrato (a aplicação não tem anotações OpenAPI).
 *
 * <p>O OpenAPI 3.1 usa JSON Schema 2020-12. Cada schema nomeado de {@code components.schemas} vira a raiz de um
 * documento que carrega {@code components} junto, para que os {@code $ref} internos continuem resolvendo.
 */
public final class ContratoOpenApi {

    private static final Path ARQUIVO = Path.of("").toAbsolutePath()
            .resolve("../../docs/contratos-rest/gestao-comprovantesquery/openapi.yaml").normalize();

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final SchemaRegistry REGISTRO = SchemaRegistry.withDefaultDialect(SpecificationVersion.DRAFT_2020_12);
    private static final String COMPONENTES = carregarComponentes();

    private ContratoOpenApi() {
    }

    private static String carregarComponentes() {
        if (!Files.isRegularFile(ARQUIVO)) {
            throw new IllegalStateException("Contrato não encontrado: " + ARQUIVO);
        }
        JsonNode documento = YAMLMapper.builder().build().readTree(ARQUIVO.toFile());
        return JSON.writeValueAsString(documento.get("components"));
    }

    /** Erros de validação do corpo contra o schema nomeado; lista vazia significa que o corpo cumpre o contrato. */
    public static List<String> validar(String nomeSchema, String corpoJson) {
        String raiz = "{\"$schema\":\"https://json-schema.org/draft/2020-12/schema\","
                + "\"$ref\":\"#/components/schemas/" + nomeSchema + "\",\"components\":" + COMPONENTES + "}";
        Schema schema = REGISTRO.getSchema(raiz);
        return schema.validate(JSON.readTree(corpoJson)).stream().map(Error::getMessage).toList();
    }
}
