package id.vokas.repo;

import id.vokas.model.Transaksi;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface TransaksiRepo extends JpaRepository<Transaksi, UUID> {
    List<Transaksi> findByPedagangIdAndTanggalBetweenOrderByTanggalAscDibuatAsc(UUID pedagangId, LocalDate dari, LocalDate sampai);
    List<Transaksi> findByPedagangIdAndPerluCekTrueOrderByTanggalDesc(UUID pedagangId);
    boolean existsByPedagangIdAndRefEksternal(UUID pedagangId, String refEksternal);
}
