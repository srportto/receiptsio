package br.com.srportto.gestaocomprovantesquery.domain.model;

import java.util.List;
import java.util.UUID;

/** Template variável: campos complementares, em ordem. */
public record TemplateVariavel(UUID idTemplate, String nome, List<CampoVariavel> campos) {
}
