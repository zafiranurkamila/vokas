package id.vokas.repo;

import id.vokas.model.RiwayatAudio;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

public interface RiwayatAudioRepo extends JpaRepository<RiwayatAudio, UUID> {

    /** Simpan audio hanya untuk 30 catatan suara terbaru per pedagang supaya database gratis tidak cepat penuh. */
    @Modifying
    @Transactional
    @Query(value = "delete from riwayat_audio where riwayat_id in ("
            + "select id from riwayat_ai where pedagang_id = :p and ada_audio order by dibuat desc offset 30)",
            nativeQuery = true)
    int pangkas(@Param("p") UUID pedagangId);

    @Modifying
    @Transactional
    @Query(value = "update riwayat_ai set ada_audio = false where pedagang_id = :p and ada_audio "
            + "and id not in (select riwayat_id from riwayat_audio)", nativeQuery = true)
    int tandaiTerpangkas(@Param("p") UUID pedagangId);
}
