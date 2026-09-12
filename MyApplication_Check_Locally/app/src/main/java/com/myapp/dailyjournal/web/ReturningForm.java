package com.myapp.dailyjournal.web;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Form backing the returning-user lookup by PAN.
 */
public class ReturningForm {

    /** The PAN to look the user up by. */
    @NotBlank(message = "PAN number is required")
    @Pattern(regexp = "^[A-Za-z]{5}[0-9]{4}[A-Za-z]$",
            message = "PAN must look like ABCDE1234F")
    private String pan;

    /**
     * Returns the entered PAN.
     *
     * @return the PAN
     */
    public String getPan() {
        return pan;
    }

    /**
     * Sets the entered PAN.
     *
     * @param newPan the PAN
     */
    public void setPan(final String newPan) {
        this.pan = newPan;
    }
}
