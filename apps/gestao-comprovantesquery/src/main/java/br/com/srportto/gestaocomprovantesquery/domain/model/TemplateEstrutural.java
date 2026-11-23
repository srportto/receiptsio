package br.com.srportto.gestaocomprovantesquery.domain.model;

import java.util.List;
import java.util.UUID;

/** Template estrutural: campos obrigatórios e indexadores, em ordem. */
public record TemplateEstrutural(UUID idTemplate, String nome, List<CampoEstrutural> campos) {
}
