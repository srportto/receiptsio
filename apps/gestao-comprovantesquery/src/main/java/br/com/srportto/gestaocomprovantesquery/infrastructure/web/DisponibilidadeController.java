package br.com.srportto.gestaocomprovantesquery.infrastructure.web;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Smoke test funcional. NÃO é probe: as probes são /actuator/health/liveness e /actuator/health/readiness. */
@RestController
public class DisponibilidadeController {

    /** Corpo de {@code GET /disponibilidade}. */
    public record Disponibilidade(String aplicacao, String status) {
    }

    private final String nomeAplicacao;

    public DisponibilidadeController(@Value("${spring.application.name}") String nomeAplicacao) {
        this.nomeAplicacao = nomeAplicacao;
    }

    @GetMapping("/disponibilidade")
    public Disponibilidade disponibilidade() {
        return new Disponibilidade(nomeAplicacao, "DISPONIVEL");
    }
}
