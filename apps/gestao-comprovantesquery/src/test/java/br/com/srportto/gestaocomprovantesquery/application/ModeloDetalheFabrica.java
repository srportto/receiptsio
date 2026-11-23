package br.com.srportto.gestaocomprovantesquery.application;

import br.com.srportto.gestaocomprovantesquery.domain.model.CampoEstrutural;
import br.com.srportto.gestaocomprovantesquery.domain.model.ModeloDetalhe;
import br.com.srportto.gestaocomprovantesquery.domain.model.Situacao;
import br.com.srportto.gestaocomprovantesquery.domain.model.TemplateEstrutural;
import br.com.srportto.gestaocomprovantesquery.domain.model.TemplateVariavel;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Dado de teste: um detalhe mínimo e coerente. */
final class ModeloDetalheFabrica {

    private ModeloDetalheFabrica() {
    }

    static ModeloDetalhe simples() {
        var campo = new CampoEstrutural(1L, "valor", "DECIMAL", 1, false, 1, null, "Valor", "Valor");
        var agora = OffsetDateTime.now();
        return new ModeloDetalhe("COMPPIX", 2, "PIX", Situacao.ATIVO, agora, agora,
                new TemplateEstrutural(UUID.randomUUID(), "Estrutura PIX v2", List.of(campo)),
                new TemplateVariavel(UUID.randomUUID(), "Variável PIX v2", List.of()));
    }
}
