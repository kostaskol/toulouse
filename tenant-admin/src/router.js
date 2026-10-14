import { createRouter, createWebHistory } from "vue-router";
import { can, loadSession, session } from "./session.js";
import HomePage from "./pages/HomePage.vue";
import LoginPage from "./pages/LoginPage.vue";
import ForgotPasswordPage from "./pages/ForgotPasswordPage.vue";
import SetPasswordPage from "./pages/SetPasswordPage.vue";
import NotFoundPage from "./pages/NotFoundPage.vue";
import BrandsPage from "./pages/BrandsPage.vue";
import CategoriesPage from "./pages/CategoriesPage.vue";
import SpecificationsPage from "./pages/SpecificationsPage.vue";

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: HomePage },
    { path: "/login", component: LoginPage, meta: { public: true } },
    { path: "/forgot-password", component: ForgotPasswordPage, meta: { public: true } },
    // Both paths match the links in staff emails.
    { path: "/password-reset", component: SetPasswordPage, props: { kind: "reset" }, meta: { public: true } },
    { path: "/invite", component: SetPasswordPage, props: { kind: "invite" }, meta: { public: true } },
    { path: "/brands", component: BrandsPage },
    { path: "/categories", component: CategoriesPage },
    { path: "/specifications", component: SpecificationsPage },
    { path: "/:path(.*)*", component: NotFoundPage }
  ]
});

router.beforeEach(async (to) => {
  await loadSession();
  if (to.path === "/login" && session.staff) return "/";
  if (to.meta.public) return true;
  if (!session.staff) return { path: "/login", query: { next: to.fullPath } };
  if (to.meta.permission && !can(to.meta.permission)) return "/";
  return true;
});
