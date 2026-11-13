package id.vokas.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final VokasProperties props;

    public WebConfig(VokasProperties props) {
        this.props = props;
    }

    @Override
    public void addCorsMappings(CorsRegistry reg) {
        reg.addMapping("/api/**")
                .allowedOriginPatterns(props.corsOrigins().split("\\s*,\\s*"))
                .allowedMethods("GET", "POST", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }

    /**
     * Kunci sederhana di header X-Api-Key untuk /api/**. Cukup untuk pilot tertutup; sebelum dipakai publik
     * ganti dengan Supabase Auth (verifikasi JWT per pedagang), karena kunci di frontend bisa dilihat orang.
     */
    @Bean
    public FilterRegistrationBean<OncePerRequestFilter> filterKunciApi() {
        String kunci = props.apiKey();
        OncePerRequestFilter f = new OncePerRequestFilter() {
            @Override
            protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
                    throws ServletException, IOException {
                if (kunci == null || kunci.isBlank() || "OPTIONS".equals(req.getMethod())) {
                    chain.doFilter(req, res);
                    return;
                }
                String h = req.getHeader("X-Api-Key");
                if (h != null && MessageDigest.isEqual(h.getBytes(StandardCharsets.UTF_8), kunci.getBytes(StandardCharsets.UTF_8))) {
                    chain.doFilter(req, res);
                } else {
                    res.sendError(HttpServletResponse.SC_UNAUTHORIZED, "X-Api-Key salah atau tidak ada");
                }
            }
        };
        FilterRegistrationBean<OncePerRequestFilter> reg = new FilterRegistrationBean<>(f);
        reg.addUrlPatterns("/api/*");
        return reg;
    }
}
