import { ref } from "vue";

export const notice = ref("");

let timer;

/**
 * Shows a short confirmation for a few seconds.
 *
 * @param text [String]
 */
export function notify(text) {
  notice.value = text;
  clearTimeout(timer);
  timer = setTimeout(() => (notice.value = ""), 3000);
}
