package com.myapp.dailyjournal.repository;

import com.myapp.dailyjournal.model.AppUser;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

/**
 * Spring Data repository for {@link AppUser}.
 */
public interface AppUserRepository extends JpaRepository<AppUser, Long> {

    /**
     * Finds a user by the keyed hash of their PAN.
     *
     * @param panHash the PAN hash to look up
     * @return the matching user, if one exists
     */
    Optional<AppUser> findByPanHash(String panHash);
}
