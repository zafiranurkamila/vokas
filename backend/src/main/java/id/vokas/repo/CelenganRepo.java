package id.vokas.repo;

import id.vokas.model.Celengan;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface CelenganRepo extends JpaRepository<Celengan, UUID> {}
