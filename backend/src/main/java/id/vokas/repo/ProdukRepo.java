package id.vokas.repo;

import id.vokas.model.Produk;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.UUID;

public interface ProdukRepo extends JpaRepository<Produk, UUID> {
    List<Produk> findByPedagangIdOrderByNama(UUID pedagangId);
}
