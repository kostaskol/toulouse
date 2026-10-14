import { ref, toValue } from "vue";
import { get } from "./api.js";
import { useAction } from "./action.js";

/**
 * A cursor-paged list from the API.
 *
 * @param path [String, Function] the endpoint below /admin
 * @param key [String] the array's key in the answer
 * @param query [Function] filters for every page
 * @return [Object] `items`, `next`, `busy`, `error`, `load` and `loadMore`
 */
export function useList(path, key, query = () => ({})) {
  const items = ref([]);
  const next = ref(null);
  const { busy, error, run } = useAction();
  let latest = 0;

  async function load(more = false) {
    const call = ++latest;
    await run(async () => {
      const body = await get(toValue(path), { ...query(), after: more ? next.value : undefined });
      // A slower answer to an earlier filter must not overwrite a newer one.
      if (call !== latest) return;

      items.value = more ? [...items.value, ...body[key]] : body[key];
      next.value = body.meta.next_cursor;
    });
  }

  return { items, next, busy, error, load, loadMore: () => load(true) };
}

/**
 * Every page of a cursor-paged list, for a select that needs them all.
 *
 * @param path [String]
 * @param key [String]
 * @return [Array<Object>]
 */
export async function getAll(path, key) {
  const items = [];
  let after;
  do {
    const body = await get(path, { after, limit: 100 });
    items.push(...body[key]);
    after = body.meta.next_cursor;
  } while (after);
  return items;
}
