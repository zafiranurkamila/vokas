package id.vokas.repo;

import id.vokas.model.CelenganSetoran;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface CelenganSetoranRepo extends JpaRepository<CelenganSetoran, UUID> {
    List<CelenganSetoran> findTop30ByPedagangIdOrderByDibuatDesc(UUID pedagangId);

    @Query("select coalesce(sum(s.nominal), 0) from CelenganSetoran s where s.pedagangId = :p")
    long total(@Param("p") UUID pedagangId);

    @Query("select coalesce(sum(s.nominal), 0) from CelenganSetoran s where s.pedagangId = :p and s.dibuat >= :sejak and s.nominal > 0")
    long setorSejak(@Param("p") UUID pedagangId, @Param("sejak") OffsetDateTime sejak);
}
