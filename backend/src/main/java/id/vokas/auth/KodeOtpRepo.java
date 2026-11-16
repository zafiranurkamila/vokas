package id.vokas.auth;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

public interface KodeOtpRepo extends JpaRepository<KodeOtp, UUID> {
    Optional<KodeOtp> findFirstByEmailIgnoreCaseAndKeperluanOrderByDibuatDesc(String email, String keperluan);

    @Query("select count(k) from KodeOtp k where lower(k.email) = lower(?1) and k.dibuat > ?2")
    long hitungSejak(String email, OffsetDateTime sejak);
}
