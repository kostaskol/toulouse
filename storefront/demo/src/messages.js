const MESSAGES = {
  invalid_email: "Το email δεν είναι έγκυρο.",
  email_taken: "Υπάρχει ήδη λογαριασμός με αυτό το email. Συνδεθείτε.",
  invalid_code: "Ο κωδικός επιβεβαίωσης είναι λάθος ή έληξε. Ζητήστε νέο κωδικό.",
  // The API does not say which rule failed, so one message covers them all.
  invalid_password: "Ο κωδικός πρόσβασης θέλει τουλάχιστον 8 χαρακτήρες και δεν πρέπει να είναι πολύ μεγάλος.",
  invalid_credentials: "Λάθος email ή κωδικός πρόσβασης.",
  query_too_short: "Γράψτε τουλάχιστον 2 χαρακτήρες.",
  query_too_long: "Η αναζήτηση είναι πολύ μεγάλη. Γράψτε λιγότερες λέξεις."
};
const FALLBACK = "Κάτι πήγε στραβά. Δοκιμάστε ξανά σε λίγο.";

/**
 * Shopper copy for a failed request.
 *
 * @param error [Error]
 * @return [String]
 */
export function errorMessage(error) {
  if (error.code === "too_many_attempts") {
    const minutes = Math.max(1, Math.ceil((error.retryAfter ?? 60) / 60));
    return `Πολλές αποτυχημένες προσπάθειες. Δοκιμάστε ξανά σε ${minutes} λεπτά.`;
  }

  return MESSAGES[error.code] ?? FALLBACK;
}
