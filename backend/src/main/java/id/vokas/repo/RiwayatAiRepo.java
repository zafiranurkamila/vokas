package id.vokas.repo;

import id.vokas.model.RiwayatAi;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

public interface RiwayatAiRepo extends JpaRepository<RiwayatAi, UUID> {
    List<RiwayatAi> findTop50ByPedagangIdAndJenisOrderByDibuatDesc(UUID pedagangId, String jenis);

    @Transactional
    int deleteByPedagangIdAndJenis(UUID pedagangId, String jenis);
}
