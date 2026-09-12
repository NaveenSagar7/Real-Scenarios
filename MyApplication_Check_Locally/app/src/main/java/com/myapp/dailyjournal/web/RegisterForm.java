package com.myapp.dailyjournal.web;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/**
 * Form backing a new-user registration submission.
 */
public class RegisterForm {

    /** Maximum allowed length of {@link #name}. */
    private static final int NAME_MAX_LENGTH = 100;

    /** Maximum realistic value of {@link #age}. */
    private static final int AGE_MAX = 130;

    /** The user's display name. */
    @NotBlank(message = "Name is required")
    @Size(max = NAME_MAX_LENGTH, message = "Name is too long")
    private String name;

    /** The user's age. */
    @NotNull(message = "Age is required")
    @Min(value = 1, message = "Age must be positive")
    @Max(value = AGE_MAX, message = "Enter a realistic age")
    private Integer age;

    /** The user's date of birth. */
    @NotNull(message = "Date of birth is required")
    @Past(message = "Date of birth must be in the past")
    private LocalDate dob;

    /** The user's PAN. */
    @NotBlank(message = "PAN number is required")
    @Pattern(regexp = "^[A-Za-z]{5}[0-9]{4}[A-Za-z]$",
            message = "PAN must look like ABCDE1234F")
    private String pan;

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
     * Returns the user's PAN.
     *
     * @return the PAN
     */
    public String getPan() {
        return pan;
    }

    /**
     * Sets the user's PAN.
     *
     * @param newPan the PAN
     */
    public void setPan(final String newPan) {
        this.pan = newPan;
    }
}
