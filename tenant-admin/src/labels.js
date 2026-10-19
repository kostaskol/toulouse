export const ROLES = { owner: "Ιδιοκτήτης", staff: "Μέλος" };

export const PRODUCT_STATUSES = { draft: "Πρόχειρο", published: "Δημοσιευμένο", archived: "Αρχειοθετημένο" };
export const PRODUCT_STATUS_BADGES = { draft: "badge-yellow", published: "badge-green", archived: "" };
export const VAT_CLASSES = { standard: "Κανονικός", reduced: "Μειωμένος", super_reduced: "Υπερμειωμένος" };
export const VARIANT_STATUSES = { active: "Ενεργή", archived: "Αρχειοθετημένη" };
export const SPECIFICATION_KINDS = { none: "Κανένα", colour: "Χρώμα", size: "Μέγεθος" };

export const STAFF_STATUSES = { pending: "Σε αναμονή", active: "Ενεργό" };
export const IMPORT_STATUSES = { queued: "Σε αναμονή", running: "Σε εξέλιξη", done: "Ολοκληρώθηκε", failed: "Απέτυχε" };
export const IMPORT_STATUS_BADGES = {
  queued: "badge-yellow", running: "badge-blue", done: "badge-green", failed: "badge-red"
};
export const IMPORT_RESULTS = { created: "Νέα", updated: "Ενημερώθηκαν", skipped: "Χωρίς αλλαγή", failed: "Απέτυχαν" };
export const IMPORT_WARNINGS = {
  product_cell_ignored: "Αγνοήθηκαν κελιά προϊόντος",
  variant_cell_ignored: "Αγνοήθηκαν κελιά παραλλαγής",
  image_urls_ignored: "Αγνοήθηκαν φωτογραφίες"
};
