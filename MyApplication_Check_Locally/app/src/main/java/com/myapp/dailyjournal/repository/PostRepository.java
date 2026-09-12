package com.myapp.dailyjournal.repository;

import com.myapp.dailyjournal.model.AppUser;
import com.myapp.dailyjournal.model.Post;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * Spring Data repository for {@link Post}.
 */
public interface PostRepository extends JpaRepository<Post, Long> {

    /**
     * Finds all posts by a user, most recent first.
     *
     * @param user the author to look up posts for
     * @return the user's posts, newest first
     */
    List<Post> findByUserOrderByCreatedAtDesc(AppUser user);
}
