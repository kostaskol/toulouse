import { get } from "./api.js";

/**
 * @return [Array<Object>] the category tree
 */
export async function loadCategories() {
  return (await get("/categories")).categories;
}

/**
 * Flattens the tree in display order, for a select.
 *
 * @param tree [Array<Object>]
 * @return [Array<Object>] each category with its `depth` and a `label` indented by it
 */
export function flatten(tree, depth = 0) {
  return tree.flatMap((category) => [
    { ...category, depth, label: `${"— ".repeat(depth)}${category.name}` },
    ...flatten(category.children, depth + 1)
  ]);
}

/**
 * The spec links a category holds, its own and those of every category above it.
 *
 * @param categories [Array<Object>] flattened
 * @param id [String, null]
 * @return [Array<Object>] links of `specification_id` and `required`, the nearest category's first
 */
export function lineageLinks(categories, id) {
  const links = [];
  for (let category = categories.find((each) => each.id === id); category;
    category = categories.find((each) => each.id === category.parent_id)) {
    links.push(...category.specification_links);
  }
  return links;
}
