package com.myapp.dailyjournal.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.time.Instant;

/**
 * A single journal entry written by an {@link AppUser}.
 */
@Entity
@Table(name = "post")
public class Post {

    /** Primary key. */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** The author of this post. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    /** The post's body text. */
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    /** When this post was created. */
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
     * Returns the author of this post.
     *
     * @return the author
     */
    public AppUser getUser() {
        return user;
    }

    /**
     * Sets the author of this post.
     *
     * @param newUser the author
     */
    public void setUser(final AppUser newUser) {
        this.user = newUser;
    }

    /**
     * Returns the post's body text.
     *
     * @return the body text
     */
    public String getContent() {
        return content;
    }

    /**
     * Sets the post's body text.
     *
     * @param newContent the body text
     */
    public void setContent(final String newContent) {
        this.content = newContent;
    }

    /**
     * Returns when this post was created.
     *
     * @return the creation timestamp
     */
    public Instant getCreatedAt() {
        return createdAt;
    }

    /**
     * Sets when this post was created.
     *
     * @param newCreatedAt the creation timestamp
     */
    public void setCreatedAt(final Instant newCreatedAt) {
        this.createdAt = newCreatedAt;
    }
}
