const MESSAGES = {
  network: "Δεν υπάρχει σύνδεση με τον διακομιστή. Δοκιμάστε ξανά σε λίγο.",
  not_found: "Δεν βρέθηκε. Μπορεί να διαγράφηκε.",
  permission_denied: "Ο ρόλος σας δεν επιτρέπει αυτή την ενέργεια.",
  tenant_suspended: "Το κατάστημα είναι σε αναστολή. Μπορείτε να δείτε τα στοιχεία αλλά όχι να τα αλλάξετε.",
  invalid_credentials: "Λάθος κατάστημα, email ή κωδικός πρόσβασης.",
  invite_pending: "Δεν έχετε αποδεχτεί ακόμα την πρόσκληση. Ορίστε κωδικό από τον σύνδεσμο στο email της πρόσκλησης.",
  invalid_token: "Ο σύνδεσμος δεν ισχύει ή έληξε. Ζητήστε νέο.",
  invalid_password: "Ο κωδικός πρόσβασης θέλει τουλάχιστον 12 χαρακτήρες και δεν πρέπει να είναι πολύ μεγάλος.",
  invalid_email: "Το email δεν είναι έγκυρο.",
  email_taken: "Υπάρχει ήδη ενεργό μέλος με αυτό το email.",
  last_owner: "Το κατάστημα πρέπει να έχει τουλάχιστον έναν ιδιοκτήτη.",
  brand_in_use: "Υπάρχουν προϊόντα με αυτή τη μάρκα. Αλλάξτε τους μάρκα πρώτα.",
  category_has_children: "Η κατηγορία έχει υποκατηγορίες. Μετακινήστε ή διαγράψτε τες πρώτα.",
  unsupported_media_type: "Ο τύπος αρχείου δεν υποστηρίζεται.",
  import_in_progress: "Τρέχει ήδη μια εισαγωγή. Περιμένετε να τελειώσει.",
  invalid_stock_change: "Δώστε είτε το απόθεμα που μετρήσατε είτε μια αλλαγή σε ακέραιο αριθμό.",
  file_too_large: "Το αρχείο είναι πολύ μεγάλο. Χωρίστε το σε μικρότερα αρχεία.",
  file_not_utf8: "Το αρχείο δεν είναι UTF-8. Αποθηκεύστε το ως «CSV UTF-8» και ανεβάστε το ξανά.",
  file_empty: "Το αρχείο δεν έχει γραμμές προϊόντων.",
  duplicate_columns: "Μια στήλη εμφανίζεται δύο φορές.",
  option_columns_invalid:
    "Οι στήλες επιλογών δεν είναι σωστές. Κάθε option<N> θέλει το ζευγάρι της, χωρίς κενά στην αρίθμηση.",
  query_too_short: "Γράψτε τουλάχιστον 2 χαρακτήρες.",
  query_too_long: "Η αναζήτηση είναι πολύ μεγάλη."
};

// Rails validation codes. Anything else keeps the API's English message.
const FIELD_MESSAGES = {
  blank: "Συμπληρώστε το πεδίο.",
  taken: "Χρησιμοποιείται ήδη.",
  invalid: "Η τιμή δεν είναι έγκυρη.",
  not_a_number: "Γράψτε αριθμό.",
  not_an_integer: "Γράψτε ακέραιο αριθμό.",
  greater_than: "Η τιμή είναι πολύ μικρή.",
  greater_than_or_equal_to: "Η τιμή είναι πολύ μικρή.",
  less_than_or_equal_to: "Η τιμή είναι πολύ μεγάλη.",
  too_long: "Το κείμενο είναι πολύ μεγάλο.",
  inclusion: "Η τιμή δεν είναι έγκυρη."
};

/**
 * Greek text for a failed request.
 *
 * @param error [ApiError]
 * @return [String]
 */
export function errorMessage(error) {
  if (error.code === "too_many_attempts") {
    const minutes = Math.max(1, Math.ceil((error.retryAfter ?? 60) / 60));
    return `Πολλές αποτυχημένες προσπάθειες. Δοκιμάστε ξανά σε ${minutes} λεπτά.`;
  }

  return MESSAGES[error.code] ?? error.message;
}

/**
 * Messages for the whole page from several requests.
 *
 * @param errors [Array<ApiError, null>]
 * @return [Array<String>]
 */
export const baseErrors = (...errors) => errors.flatMap((error) => formErrors(error).base);

/**
 * Splits a failure into messages for named form fields and messages for the whole form.
 *
 * @param error [ApiError, null]
 * @param fields [Array<String>] the fields the form shows
 * @return [Object] `fields` keyed by field name, and `base`, a list
 */
export function formErrors(error, fields = []) {
  const result = { fields: {}, base: [] };
  if (!error) return result;
  if (!error.errors) return { ...result, base: [error.message] };

  for (const item of error.errors) {
    if (item.field && fields.includes(item.field)) {
      result.fields[item.field] ??= MESSAGES[item.code] ?? FIELD_MESSAGES[item.code] ?? item.message;
    } else if (item.field) {
      // The API's full message names the field, which this form does not show.
      result.base.push(MESSAGES[item.code] ?? item.message);
    } else {
      result.base.push(errorMessage({ ...item, retryAfter: error.retryAfter }));
    }
  }
  return result;
}
