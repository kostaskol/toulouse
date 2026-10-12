const EURO = new Intl.NumberFormat("el-GR", { style: "currency", currency: "EUR" });

export const formatPrice = (cents) => EURO.format(cents / 100);
