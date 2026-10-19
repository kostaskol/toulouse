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
  category_has_products: "Η κατηγορία έχει προϊόντα. Μεταφέρετέ τα σε άλλη κατηγορία πρώτα.",
  unsupported_media_type: "Ο τύπος αρχείου δεν υποστηρίζεται.",
  import_in_progress: "Τρέχει ήδη μια εισαγωγή. Περιμένετε να τελειώσει.",
  invalid_stock_change: "Δώστε είτε το απόθεμα που μετρήσατε είτε μια αλλαγή σε ακέραιο αριθμό.",
  file_too_large: "Το αρχείο είναι πολύ μεγάλο. Χωρίστε το σε μικρότερα αρχεία.",
  file_not_utf8: "Το αρχείο δεν είναι UTF-8. Αποθηκεύστε το ως «CSV UTF-8» και ανεβάστε το ξανά.",
  file_empty: "Το αρχείο δεν έχει γραμμές προϊόντων.",
  option_columns_invalid:
    "Οι στήλες επιλογών δεν είναι σωστές. Κάθε option<N> θέλει το ζευγάρι της, χωρίς κενά στην αρίθμηση.",
  query_too_short: "Γράψτε τουλάχιστον 2 χαρακτήρες.",
  query_too_long: "Η αναζήτηση είναι πολύ μεγάλη.",
  file_malformed: "Το αρχείο δεν είναι έγκυρο CSV. Αποθηκεύστε το ξανά ως CSV.",
  blank_column: "Η πρώτη γραμμή έχει στήλη χωρίς όνομα.",
  import_failed: "Η εισαγωγή σταμάτησε από απρόσμενο σφάλμα. Ανεβάστε το αρχείο ξανά για να ολοκληρωθεί.",
  too_large: "Το αρχείο είναι πολύ μεγάλο.",
  content_type: "Ο τύπος αρχείου δεν υποστηρίζεται. Δεκτά αρχεία: JPEG, PNG, WebP.",
  too_many_pixels: "Η εικόνα έχει πολύ μεγάλη ανάλυση.",
  too_many_images: "Το προϊόν έχει ήδη όσες φωτογραφίες επιτρέπονται.",
  image_unreachable: "Η φωτογραφία δεν κατέβηκε από τη διεύθυνσή της.",
  image_address_refused: "Η διεύθυνση της φωτογραφίας δεν επιτρέπεται.",
  image_failed: "Η φωτογραφία δεν αποθηκεύτηκε."
};

// The API names these columns in a field of their own.
const COLUMN_MESSAGES = {
  unknown_columns: "Άγνωστες στήλες",
  missing_columns: "Λείπουν στήλες",
  duplicate_columns: "Επαναλαμβάνονται στήλες"
};

// Neutral, as a retry does not fix most of the codes that reach it.
const FALLBACK = "Η ενέργεια δεν ολοκληρώθηκε.";

// Rails validation codes.
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
  too_short: "Το κείμενο είναι πολύ μικρό.",
  inclusion: "Η τιμή δεν είναι έγκυρη.",
  less_than: "Η τιμή είναι πολύ μεγάλη.",
  invalid_parent: "Μια κατηγορία δεν μπαίνει κάτω από τον εαυτό της ή τις υποκατηγορίες της.",
  no_active_variant: "Ένα δημοσιευμένο προϊόν θέλει τουλάχιστον μία ενεργή παραλλαγή.",
  last_active_variant: "Η τελευταία ενεργή παραλλαγή ενός δημοσιευμένου προϊόντος δεν αρχειοθετείται.",
  insufficient_stock: "Το απόθεμα δεν φτάνει.",
  duplicate_combination: "Υπάρχει ήδη παραλλαγή με αυτές τις επιλογές.",
  too_many_variants: "Το προϊόν έχει ήδη όσες παραλλαγές επιτρέπονται.",
  option_names_mismatch: "Οι επιλογές δεν ταιριάζουν με τις επιλογές του προϊόντος.",
  product_cell_conflict: "Η τιμή διαφέρει από την πρώτη γραμμή του προϊόντος."
};

/**
 * Greek text for a failed request or one item of an errors array. Unknown codes get a generic message.
 *
 * @param error [ApiError, Object]
 * @return [String]
 */
export function errorMessage(error) {
  const item = error.errors?.[0] ?? error;
  if (item.code === "too_many_attempts") {
    const minutes = Math.max(1, Math.ceil((error.retryAfter ?? 60) / 60));
    return `Πολλές αποτυχημένες προσπάθειες. Δοκιμάστε ξανά σε ${minutes} λεπτά.`;
  }
  if (COLUMN_MESSAGES[item.code]) return `${COLUMN_MESSAGES[item.code]}: ${(item.columns ?? []).join(", ")}.`;

  return MESSAGES[item.code] ?? FIELD_MESSAGES[item.code] ?? FALLBACK;
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

  for (const item of error.errors ?? [error]) {
    const message = errorMessage({ ...item, retryAfter: error.retryAfter });
    if (item.field && fields.includes(item.field)) result.fields[item.field] ??= message;
    // The field name tells the merchant where to look when the form does not show it.
    else result.base.push(item.field ? `${item.field}: ${message}` : message);
  }
  return result;
}
