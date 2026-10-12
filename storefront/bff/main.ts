import { createBff } from "./server.ts";

function required(name: string) {
  const value = process.env[name];
  if (value) return value;

  console.error(`${name} is not set`);
  process.exit(1);
}

const config = {
  toulouseUrl: required("TOULOUSE_URL").replace(/\/+$/, ""),
  apiVersion: required("TOULOUSE_API_VERSION"),
  apiKey: required("TOULOUSE_API_KEY"),
  storefrontOrigin: required("STOREFRONT_ORIGIN"),
  trustProxy: process.env.TRUST_PROXY === "true"
};
const port = Number(process.env.PORT ?? 4000);
if (!Number.isInteger(port)) {
  console.error("PORT is not a number");
  process.exit(1);
}

createBff(config).listen(port, () => console.log(`Listening on ${port}`));
