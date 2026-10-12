// Loaded from the BFF at runtime, the way a storefront in another repo gets it.
export const shop = await import(/* @vite-ignore */ new URL("client.js", import.meta.env.VITE_BFF_URL).href);
