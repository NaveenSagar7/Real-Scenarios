package com.myapp.dailyjournal.web;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Form backing a new journal post submission.
 */
public class PostForm {

    /** Maximum allowed length of {@link #content}. */
    private static final int CONTENT_MAX_LENGTH = 5000;

    /** The post's body text. */
    @NotBlank(message = "Write something before saving")
    @Size(max = CONTENT_MAX_LENGTH,
            message = "That's a lot to say - keep it under 5000 characters")
    private String content;

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
}
