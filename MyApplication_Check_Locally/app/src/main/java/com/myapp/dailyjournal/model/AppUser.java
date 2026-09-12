package com.myapp.dailyjournal.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import java.time.Instant;
import java.time.LocalDate;

/**
 * A registered user of the journal app, looked up on return visits by a
 * keyed hash of their PAN rather than the plaintext value.
 */
@Entity
@Table(name = "app_user",
        uniqueConstraints = @UniqueConstraint(columnNames = "pan_hash"))
public class AppUser {

    /** Maximum stored length of {@link #name}. */
    private static final int NAME_MAX_LENGTH = 100;

    /** Stored length of {@link #panHash}. */
    private static final int PAN_HASH_LENGTH = 64;

    /** Stored length of {@link #panMasked}. */
    private static final int PAN_MASKED_LENGTH = 10;

    /** Primary key. */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** The user's display name. */
    @Column(nullable = false, length = NAME_MAX_LENGTH)
    private String name;

    /** The user's age at registration. */
    @Column(nullable = false)
    private Integer age;

    /** The user's date of birth. */
    @Column(nullable = false)
    private LocalDate dob;

    /**
     * Keyed hash of the PAN, used to look returning users up. The
     * plaintext PAN is never stored.
     */
    @Column(name = "pan_hash", nullable = false, unique = true,
            length = PAN_HASH_LENGTH)
    private String panHash;

    /** Masked form kept only for display, e.g. XXXXX1234F. */
    @Column(name = "pan_masked", nullable = false, length = PAN_MASKED_LENGTH)
    private String panMasked;

    /** When this user registered. */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    /**
     * Returns the primary key.
     *
     * @return the primary key, or {@code null} if not yet persisted
     */
    public Long getId() {
        return id;
    }

    /**
     * Sets the primary key.
     *
     * @param newId the primary key
     */
    public void setId(final Long newId) {
        this.id = newId;
    }

    /**
     * Returns the user's display name.
     *
     * @return the display name
     */
    public String getName() {
        return name;
    }

    /**
     * Sets the user's display name.
     *
     * @param newName the display name
     */
    public void setName(final String newName) {
        this.name = newName;
    }

    /**
     * Returns the user's age.
     *
     * @return the age
     */
    public Integer getAge() {
        return age;
    }

    /**
     * Sets the user's age.
     *
     * @param newAge the age
     */
    public void setAge(final Integer newAge) {
        this.age = newAge;
    }

    /**
     * Returns the user's date of birth.
     *
     * @return the date of birth
     */
    public LocalDate getDob() {
        return dob;
    }

    /**
     * Sets the user's date of birth.
     *
     * @param newDob the date of birth
     */
    public void setDob(final LocalDate newDob) {
        this.dob = newDob;
    }

    /**
     * Returns the keyed hash of the user's PAN.
     *
     * @return the PAN hash
     */
    public String getPanHash() {
        return panHash;
    }

    /**
     * Sets the keyed hash of the user's PAN.
     *
     * @param newPanHash the PAN hash
     */
    public void setPanHash(final String newPanHash) {
        this.panHash = newPanHash;
    }

    /**
     * Returns the masked, display-only form of the user's PAN.
     *
     * @return the masked PAN
     */
    public String getPanMasked() {
        return panMasked;
    }

    /**
     * Sets the masked, display-only form of the user's PAN.
     *
     * @param newPanMasked the masked PAN
     */
    public void setPanMasked(final String newPanMasked) {
        this.panMasked = newPanMasked;
    }

    /**
     * Returns when this user registered.
     *
     * @return the registration timestamp
     */
    public Instant getCreatedAt() {
        return createdAt;
    }

    /**
     * Sets when this user registered.
     *
     * @param newCreatedAt the registration timestamp
     */
    public void setCreatedAt(final Instant newCreatedAt) {
        this.createdAt = newCreatedAt;
    }
}
