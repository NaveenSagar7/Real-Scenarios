package com.myapp.dailyjournal.controller;

import com.myapp.dailyjournal.model.AppUser;
import com.myapp.dailyjournal.service.JournalService;
import com.myapp.dailyjournal.web.PostForm;
import com.myapp.dailyjournal.web.RegisterForm;
import com.myapp.dailyjournal.web.ReturningForm;
import jakarta.servlet.http.HttpSession;
import jakarta.validation.Valid;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;

import java.util.Optional;

/**
 * MVC controller for the welcome, registration, returning-user and
 * journal pages.
 */
@Controller
public class HomeController {

    /** Session attribute key holding the logged-in user's id. */
    private static final String SESSION_USER_ID = "userId";

    /** Error message shown when a returning-user PAN lookup fails. */
    private static final String NO_PAN_MATCH_MESSAGE =
            "We couldn't find that PAN. New here? Register instead.";

    /** The service used to register users and manage posts. */
    private final JournalService journalService;

    /**
     * Creates the controller.
     *
     * @param theJournalService the service used to register users and
     *     manage posts
     */
    public HomeController(final JournalService theJournalService) {
        this.journalService = theJournalService;
    }

    /**
     * Renders the welcome page.
     *
     * @return the welcome view name
     */
    @GetMapping("/")
    public String welcome() {
        return "welcome";
    }

    /**
     * Renders the registration form.
     *
     * @param model the view model
     * @return the registration view name
     */
    @GetMapping("/register")
    public String registerForm(final Model model) {
        if (!model.containsAttribute("registerForm")) {
            model.addAttribute("registerForm", new RegisterForm());
        }
        return "register";
    }

    /**
     * Handles a registration submission.
     *
     * @param form the submitted registration form
     * @param bindingResult validation results for {@code form}
     * @param session the current HTTP session
     * @param model the view model
     * @return the next view name or a redirect
     */
    @PostMapping("/register")
    public String register(
            @Valid @ModelAttribute("registerForm") final RegisterForm form,
            final BindingResult bindingResult,
            final HttpSession session,
            final Model model) {
        if (bindingResult.hasErrors()) {
            return "register";
        }
        try {
            AppUser user = journalService.register(
                    form.getName(), form.getAge(), form.getDob(),
                    form.getPan());
            session.setAttribute(SESSION_USER_ID, user.getId());
            return "redirect:/post/new";
        } catch (IllegalStateException | IllegalArgumentException e) {
            model.addAttribute("errorMessage", e.getMessage());
            return "register";
        }
    }

    /**
     * Renders the returning-user lookup form.
     *
     * @param model the view model
     * @return the returning-user view name
     */
    @GetMapping("/returning")
    public String returningForm(final Model model) {
        if (!model.containsAttribute("returningForm")) {
            model.addAttribute("returningForm", new ReturningForm());
        }
        return "returning";
    }

    /**
     * Handles a returning-user lookup submission.
     *
     * @param form the submitted returning-user form
     * @param bindingResult validation results for {@code form}
     * @param session the current HTTP session
     * @param model the view model
     * @return the next view name or a redirect
     */
    @PostMapping("/returning")
    public String returning(
            @Valid @ModelAttribute("returningForm") final ReturningForm form,
            final BindingResult bindingResult,
            final HttpSession session,
            final Model model) {
        if (bindingResult.hasErrors()) {
            return "returning";
        }
        Optional<AppUser> user = journalService.findByPan(form.getPan());
        if (user.isEmpty()) {
            model.addAttribute("errorMessage", NO_PAN_MATCH_MESSAGE);
            return "returning";
        }
        session.setAttribute(SESSION_USER_ID, user.get().getId());
        return "redirect:/dashboard";
    }

    /**
     * Renders the dashboard for the logged-in user.
     *
     * @param session the current HTTP session
     * @param model the view model
     * @return the dashboard view name or a redirect
     */
    @GetMapping("/dashboard")
    public String dashboard(final HttpSession session, final Model model) {
        AppUser user = requireUser(session);
        if (user == null) {
            return "redirect:/";
        }
        model.addAttribute("user", user);
        return "dashboard";
    }

    /**
     * Renders the new-post form for the logged-in user.
     *
     * @param session the current HTTP session
     * @param model the view model
     * @return the write-post view name or a redirect
     */
    @GetMapping("/post/new")
    public String newPostForm(final HttpSession session, final Model model) {
        AppUser user = requireUser(session);
        if (user == null) {
            return "redirect:/";
        }
        model.addAttribute("user", user);
        if (!model.containsAttribute("postForm")) {
            model.addAttribute("postForm", new PostForm());
        }
        return "write-post";
    }

    /**
     * Handles a new-post submission for the logged-in user.
     *
     * @param form the submitted post form
     * @param bindingResult validation results for {@code form}
     * @param session the current HTTP session
     * @param model the view model
     * @return the next view name or a redirect
     */
    @PostMapping("/post/new")
    public String createPost(
            @Valid @ModelAttribute("postForm") final PostForm form,
            final BindingResult bindingResult,
            final HttpSession session,
            final Model model) {
        AppUser user = requireUser(session);
        if (user == null) {
            return "redirect:/";
        }
        if (bindingResult.hasErrors()) {
            model.addAttribute("user", user);
            return "write-post";
        }
        journalService.addPost(user, form.getContent());
        return "redirect:/dashboard";
    }

    /**
     * Renders the logged-in user's posts.
     *
     * @param session the current HTTP session
     * @param model the view model
     * @return the posts view name or a redirect
     */
    @GetMapping("/posts")
    public String posts(final HttpSession session, final Model model) {
        AppUser user = requireUser(session);
        if (user == null) {
            return "redirect:/";
        }
        model.addAttribute("user", user);
        model.addAttribute("posts", journalService.getPosts(user));
        return "posts";
    }

    /**
     * Logs the current user out.
     *
     * @param session the current HTTP session
     * @return a redirect to the welcome page
     */
    @PostMapping("/logout")
    public String logout(final HttpSession session) {
        session.invalidate();
        return "redirect:/";
    }

    private AppUser requireUser(final HttpSession session) {
        Object id = session.getAttribute(SESSION_USER_ID);
        if (id == null) {
            return null;
        }
        return journalService.findById((Long) id).orElse(null);
    }
}
