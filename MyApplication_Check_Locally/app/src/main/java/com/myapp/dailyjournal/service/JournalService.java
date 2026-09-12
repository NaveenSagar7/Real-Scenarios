package com.myapp.dailyjournal.service;

import com.myapp.dailyjournal.model.AppUser;
import com.myapp.dailyjournal.model.Post;
import com.myapp.dailyjournal.repository.AppUserRepository;
import com.myapp.dailyjournal.repository.PostRepository;
import com.myapp.dailyjournal.util.PanUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Implements user registration, returning-user lookup and posting.
 */
@Service
public class JournalService {

    /** Error message used when a PAN is already registered. */
    private static final String DUPLICATE_PAN_MESSAGE =
            "A user with this PAN is already registered";

    /** Looks up and persists {@link AppUser}s. */
    private final AppUserRepository userRepository;

    /** Looks up and persists {@link Post}s. */
    private final PostRepository postRepository;

    /** Key used to hash PANs for returning-user lookup. */
    private final String panSecret;

    /**
     * Creates the service.
     *
     * @param theUserRepository the user repository
     * @param thePostRepository the post repository
     * @param thePanSecret the key used to hash PANs
     */
    public JournalService(
            final AppUserRepository theUserRepository,
            final PostRepository thePostRepository,
            @Value("${app.security.pan-secret}") final String thePanSecret) {
        this.userRepository = theUserRepository;
        this.postRepository = thePostRepository;
        this.panSecret = thePanSecret;
    }

    /**
     * Registers a new user.
     *
     * @param name the user's display name
     * @param age the user's age
     * @param dob the user's date of birth
     * @param pan the user's PAN
     * @return the persisted user
     */
    @Transactional
    public AppUser register(final String name, final Integer age,
                             final LocalDate dob, final String pan) {
        if (!PanUtil.isValid(pan)) {
            throw new IllegalArgumentException("PAN must look like ABCDE1234F");
        }

        String normalizedPan = PanUtil.normalize(pan);
        String panHash = PanUtil.hash(normalizedPan, panSecret);

        if (userRepository.findByPanHash(panHash).isPresent()) {
            throw new IllegalStateException(DUPLICATE_PAN_MESSAGE);
        }

        AppUser user = new AppUser();
        user.setName(name);
        user.setAge(age);
        user.setDob(dob);
        user.setPanHash(panHash);
        user.setPanMasked(PanUtil.mask(normalizedPan));

        try {
            return userRepository.save(user);
        } catch (DataIntegrityViolationException e) {
            throw new IllegalStateException(DUPLICATE_PAN_MESSAGE, e);
        }
    }

    /**
     * Finds a registered user by PAN.
     *
     * @param pan the PAN to look up
     * @return the matching user, if one is registered
     */
    @Transactional(readOnly = true)
    public Optional<AppUser> findByPan(final String pan) {
        String panHash = PanUtil.hash(PanUtil.normalize(pan), panSecret);
        return userRepository.findByPanHash(panHash);
    }

    /**
     * Finds a registered user by primary key.
     *
     * @param id the primary key to look up
     * @return the matching user, if one exists
     */
    @Transactional(readOnly = true)
    public Optional<AppUser> findById(final Long id) {
        return userRepository.findById(id);
    }

    /**
     * Adds a new journal post for a user.
     *
     * @param user the author
     * @param content the post's body text
     * @return the persisted post
     */
    @Transactional
    public Post addPost(final AppUser user, final String content) {
        Post post = new Post();
        post.setUser(user);
        post.setContent(content);
        return postRepository.save(post);
    }

    /**
     * Returns a user's posts, most recent first.
     *
     * @param user the author to look up posts for
     * @return the user's posts, newest first
     */
    @Transactional(readOnly = true)
    public List<Post> getPosts(final AppUser user) {
        return postRepository.findByUserOrderByCreatedAtDesc(user);
    }
}
