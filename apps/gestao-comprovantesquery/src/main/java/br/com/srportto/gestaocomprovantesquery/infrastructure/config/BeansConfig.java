package br.com.srportto.gestaocomprovantesquery.infrastructure.config;

import br.com.srportto.gestaocomprovantesquery.application.usecase.DetalharModeloService;
import br.com.srportto.gestaocomprovantesquery.application.usecase.ListarModelosService;
import br.com.srportto.gestaocomprovantesquery.domain.port.in.DetalharModeloUseCase;
import br.com.srportto.gestaocomprovantesquery.domain.port.in.ListarModelosUseCase;
import br.com.srportto.gestaocomprovantesquery.domain.port.out.CatalogoModelos;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Composição: liga os casos de uso (application) às portas; é a camada que conhece o Spring. */
@Configuration
public class BeansConfig {

    @Bean
    ListarModelosUseCase listarModelosUseCase(CatalogoModelos catalogo) {
        return new ListarModelosService(catalogo);
    }

    @Bean
    DetalharModeloUseCase detalharModeloUseCase(CatalogoModelos catalogo) {
        return new DetalharModeloService(catalogo);
    }
}
