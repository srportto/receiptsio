package br.com.srportto.gestaocomprovantesquery.infrastructure.config;

import java.util.List;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

/**
 * Falha na subida, nomeando a variável, quando a configuração obrigatória do banco não foi fornecida.
 *
 * <p>O binder de {@code spring.datasource.*} deixa um {@code ${VARIAVEL}} não resolvido como texto literal e o erro
 * só apareceria na autenticação, longe da causa. {@link Environment#getRequiredProperty} resolve os placeholders e
 * lança "Could not resolve placeholder 'VARIAVEL'", que cita só o nome da variável, nunca valores.
 */
@Configuration
class VerificaConfiguracaoBanco {

    private static final List<String> OBRIGATORIAS = List.of("spring.datasource.url", "spring.datasource.password");

    VerificaConfiguracaoBanco(Environment ambiente) {
        OBRIGATORIAS.forEach(ambiente::getRequiredProperty);
    }
}
