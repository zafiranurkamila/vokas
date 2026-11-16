package id.vokas.repo;

import id.vokas.model.Pedagang;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.UUID;

public interface PedagangRepo extends JpaRepository<Pedagang, UUID> {
    Optional<Pedagang> findByNoWa(String noWa);
    Optional<Pedagang> findByEmailIgnoreCase(String email);
    Optional<Pedagang> findByGoogleSub(String googleSub);
}
