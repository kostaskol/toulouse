import { ref } from "vue";
import { ApiError } from "./api.js";

/**
 * Tracks one request at a time: whether it runs and how it failed.
 *
 * @return [Object] `busy`, `error` and `run`, which answers whether the call succeeded
 */
export function useAction() {
  const busy = ref(false);
  const error = ref(null);

  async function run(call) {
    busy.value = true;
    error.value = null;
    try {
      await call();
      return true;
    } catch (caught) {
      if (!(caught instanceof ApiError)) console.error(caught);
      error.value = caught;
      return false;
    } finally {
      busy.value = false;
    }
  }

  return { busy, error, run };
}
