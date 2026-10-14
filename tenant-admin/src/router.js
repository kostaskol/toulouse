import { createRouter, createWebHistory } from "vue-router";
import { can, loadSession, session } from "./session.js";
import HomePage from "./pages/HomePage.vue";
import LoginPage from "./pages/LoginPage.vue";
import ForgotPasswordPage from "./pages/ForgotPasswordPage.vue";
import SetPasswordPage from "./pages/SetPasswordPage.vue";
import NotFoundPage from "./pages/NotFoundPage.vue";
import ProductsPage from "./pages/ProductsPage.vue";
import ProductNewPage from "./pages/ProductNewPage.vue";
import ProductEditPage from "./pages/ProductEditPage.vue";
import StaffPage from "./pages/StaffPage.vue";
import BrandsPage from "./pages/BrandsPage.vue";
import CategoriesPage from "./pages/CategoriesPage.vue";
import SpecificationsPage from "./pages/SpecificationsPage.vue";

// Pages put the id in API paths, so a crafted one must not climb to another endpoint.
const encodedId = (route) => ({ id: encodeURIComponent(route.params.id) });

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: HomePage },
    { path: "/login", component: LoginPage, meta: { public: true } },
    { path: "/forgot-password", component: ForgotPasswordPage, meta: { public: true } },
    // Both paths match the links in staff emails.
    { path: "/password-reset", component: SetPasswordPage, props: { kind: "reset" }, meta: { public: true } },
    { path: "/invite", component: SetPasswordPage, props: { kind: "invite" }, meta: { public: true } },
    { path: "/products", component: ProductsPage },
    { path: "/products/new", component: ProductNewPage },
    { path: "/products/:id", component: ProductEditPage, props: encodedId },
    { path: "/brands", component: BrandsPage },
    { path: "/categories", component: CategoriesPage },
    { path: "/specifications", component: SpecificationsPage },
    { path: "/staff", component: StaffPage, meta: { permission: "manage_staff" } },
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
