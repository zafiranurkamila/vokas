package id.vokas.repo;

import id.vokas.model.Kasbon;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface KasbonRepo extends JpaRepository<Kasbon, UUID> {
    List<Kasbon> findByPedagangIdAndLunasFalseOrderByDibuatAsc(UUID pedagangId);
    List<Kasbon> findTop20ByPedagangIdAndLunasTrueOrderByDilunasiDesc(UUID pedagangId);
    Optional<Kasbon> findByIdAndPedagangId(UUID id, UUID pedagangId);
}
