import { createRouter, createWebHistory } from "vue-router";
import HomePage from "./pages/HomePage.vue";
import CategoryPage from "./pages/CategoryPage.vue";
import ProductPage from "./pages/ProductPage.vue";
import LoginPage from "./pages/LoginPage.vue";
import SignupPage from "./pages/SignupPage.vue";
import ForgotPasswordPage from "./pages/ForgotPasswordPage.vue";
import NotFoundPage from "./pages/NotFoundPage.vue";

export const router = createRouter({
  history: createWebHistory(),
  scrollBehavior: () => ({ top: 0 }),
  routes: [
    { path: "/", component: HomePage },
    { path: "/categories/:slug", component: CategoryPage, props: true },
    { path: "/products/:slug", component: ProductPage, props: true },
    { path: "/login", component: LoginPage },
    { path: "/signup", component: SignupPage },
    { path: "/forgot-password", component: ForgotPasswordPage },
    { path: "/:path(.*)*", component: NotFoundPage }
  ]
});
