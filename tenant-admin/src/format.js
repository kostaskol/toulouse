const DATE_TIME = new Intl.DateTimeFormat("el-GR", { dateStyle: "short", timeStyle: "short" });

export const formatDateTime = (iso) => (iso ? DATE_TIME.format(new Date(iso)) : "");
