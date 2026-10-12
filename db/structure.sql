SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: platform; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA platform;


--
-- Name: tenant_api_keys_reject_token_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tenant_api_keys_reject_token_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'tenant_api_keys.token_digest and token_prefix cannot change';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_sessions; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.admin_sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    admin_id uuid NOT NULL,
    token_digest text NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: admins; Type: TABLE; Schema: platform; Owner: -
--

CREATE TABLE platform.admins (
    id uuid DEFAULT uuidv7() NOT NULL,
    email text NOT NULL,
    password_digest text NOT NULL,
    otp_secret text NOT NULL,
    last_otp_at timestamp(6) with time zone,
    failed_count integer DEFAULT 0 NOT NULL,
    last_failed_at timestamp(6) with time zone,
    locked_until timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brands (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    parent_id uuid,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: login_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.login_attempts (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    email text NOT NULL,
    failed_count integer DEFAULT 0 NOT NULL,
    last_failed_at timestamp(6) with time zone,
    locked_until timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT login_attempts_email_lowercase CHECK ((email = lower(email)))
);


--
-- Name: product_categorizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_categorizations (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    product_id uuid NOT NULL,
    category_id uuid NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: product_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_variants (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    product_id uuid NOT NULL,
    option_values jsonb DEFAULT '{}'::jsonb NOT NULL,
    sku text,
    barcode text,
    mpn text,
    price_cents integer NOT NULL,
    compare_at_price_cents integer,
    vat_class integer NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT product_variants_compare_at_above_price CHECK ((compare_at_price_cents > price_cents)),
    CONSTRAINT product_variants_price_not_negative CHECK ((price_cents >= 0))
);


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    title text NOT NULL,
    slug text NOT NULL,
    description text,
    status integer DEFAULT 0 NOT NULL,
    option_names jsonb DEFAULT '[]'::jsonb NOT NULL,
    brand_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: shopper_email_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shopper_email_codes (
    id uuid DEFAULT uuidv7() CONSTRAINT shopper_signup_codes_id_not_null NOT NULL,
    tenant_id uuid CONSTRAINT shopper_signup_codes_tenant_id_not_null NOT NULL,
    email text CONSTRAINT shopper_signup_codes_email_not_null NOT NULL,
    code_digest text CONSTRAINT shopper_signup_codes_code_digest_not_null NOT NULL,
    expires_at timestamp(6) with time zone CONSTRAINT shopper_signup_codes_expires_at_not_null NOT NULL,
    attempts integer DEFAULT 0 CONSTRAINT shopper_signup_codes_attempts_not_null NOT NULL,
    created_at timestamp(6) with time zone CONSTRAINT shopper_signup_codes_created_at_not_null NOT NULL,
    updated_at timestamp(6) with time zone CONSTRAINT shopper_signup_codes_updated_at_not_null NOT NULL,
    purpose integer NOT NULL,
    CONSTRAINT shopper_email_codes_email_lowercase CHECK ((email = lower(email)))
);


--
-- Name: shopper_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shopper_sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    shopper_id uuid NOT NULL,
    token_digest text NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: shoppers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shoppers (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    email text NOT NULL,
    password_digest text,
    staff_id uuid,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT shoppers_email_lowercase CHECK ((email = lower(email))),
    CONSTRAINT shoppers_password_unless_linked CHECK (((staff_id IS NULL) = (password_digest IS NOT NULL)))
);


--
-- Name: staff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    email text NOT NULL,
    password_digest text,
    role integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    invited_at timestamp(6) with time zone,
    CONSTRAINT staff_email_lowercase CHECK ((email = lower(email))),
    CONSTRAINT staff_password_unless_pending CHECK (((status = 0) OR (password_digest IS NOT NULL)))
);


--
-- Name: staff_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    staff_id uuid NOT NULL,
    token_digest text NOT NULL,
    expires_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: tenant_api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_api_keys (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    name text NOT NULL,
    token_prefix text NOT NULL,
    token_digest text NOT NULL,
    last_used_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    token text NOT NULL
);


--
-- Name: tenant_domains; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_domains (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    hostname text NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    verified_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT tenant_domains_hostname_lowercase CHECK ((hostname = lower(hostname)))
);


--
-- Name: tenant_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_settings (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT tenant_settings_is_object CHECK ((jsonb_typeof(settings) = 'object'::text))
);


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id uuid DEFAULT uuidv7() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT tenants_slug_format CHECK ((slug ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'::text))
);


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions (
    id uuid DEFAULT uuidv7() NOT NULL,
    tenant_id uuid NOT NULL,
    item_type text NOT NULL,
    item_id uuid NOT NULL,
    event text NOT NULL,
    whodunnit text,
    object jsonb,
    object_changes jsonb,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: admin_sessions admin_sessions_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.admin_sessions
    ADD CONSTRAINT admin_sessions_pkey PRIMARY KEY (id);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: brands brands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT brands_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: login_attempts login_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_attempts
    ADD CONSTRAINT login_attempts_pkey PRIMARY KEY (id);


--
-- Name: product_categorizations product_categorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categorizations
    ADD CONSTRAINT product_categorizations_pkey PRIMARY KEY (id);


--
-- Name: product_variants product_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT product_variants_pkey PRIMARY KEY (id);


--
-- Name: product_variants product_variants_unique_combination; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT product_variants_unique_combination UNIQUE (tenant_id, product_id, option_values) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: shopper_sessions shopper_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shopper_sessions
    ADD CONSTRAINT shopper_sessions_pkey PRIMARY KEY (id);


--
-- Name: shopper_email_codes shopper_signup_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shopper_email_codes
    ADD CONSTRAINT shopper_signup_codes_pkey PRIMARY KEY (id);


--
-- Name: shoppers shoppers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shoppers
    ADD CONSTRAINT shoppers_pkey PRIMARY KEY (id);


--
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (id);


--
-- Name: staff_sessions staff_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_sessions
    ADD CONSTRAINT staff_sessions_pkey PRIMARY KEY (id);


--
-- Name: tenant_api_keys tenant_api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_api_keys
    ADD CONSTRAINT tenant_api_keys_pkey PRIMARY KEY (id);


--
-- Name: tenant_domains tenant_domains_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_domains
    ADD CONSTRAINT tenant_domains_pkey PRIMARY KEY (id);


--
-- Name: tenant_settings tenant_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT tenant_settings_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: index_admin_sessions_on_admin_id; Type: INDEX; Schema: platform; Owner: -
--

CREATE INDEX index_admin_sessions_on_admin_id ON platform.admin_sessions USING btree (admin_id);


--
-- Name: index_admin_sessions_on_token_digest; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX index_admin_sessions_on_token_digest ON platform.admin_sessions USING btree (token_digest);


--
-- Name: index_admins_on_email; Type: INDEX; Schema: platform; Owner: -
--

CREATE UNIQUE INDEX index_admins_on_email ON platform.admins USING btree (email);


--
-- Name: idx_on_tenant_id_category_id_product_id_2d20c5b4a1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_tenant_id_category_id_product_id_2d20c5b4a1 ON public.product_categorizations USING btree (tenant_id, category_id, product_id);


--
-- Name: index_brands_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_brands_on_tenant_id ON public.brands USING btree (tenant_id);


--
-- Name: index_brands_on_tenant_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_brands_on_tenant_id_and_name ON public.brands USING btree (tenant_id, name);


--
-- Name: index_brands_on_tenant_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_brands_on_tenant_id_and_slug ON public.brands USING btree (tenant_id, slug);


--
-- Name: index_categories_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_tenant_id ON public.categories USING btree (tenant_id);


--
-- Name: index_categories_on_tenant_id_and_parent_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_tenant_id_and_parent_id_and_position ON public.categories USING btree (tenant_id, parent_id, "position");


--
-- Name: index_categories_on_tenant_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_tenant_id_and_slug ON public.categories USING btree (tenant_id, slug);


--
-- Name: index_login_attempts_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_login_attempts_on_tenant_id ON public.login_attempts USING btree (tenant_id);


--
-- Name: index_login_attempts_on_tenant_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_login_attempts_on_tenant_id_and_email ON public.login_attempts USING btree (tenant_id, email);


--
-- Name: index_product_categorizations_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_categorizations_on_product_id ON public.product_categorizations USING btree (product_id);


--
-- Name: index_product_categorizations_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_categorizations_on_tenant_id ON public.product_categorizations USING btree (tenant_id);


--
-- Name: index_product_variants_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_variants_on_tenant_id ON public.product_variants USING btree (tenant_id);


--
-- Name: index_product_variants_on_tenant_id_and_sku; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_product_variants_on_tenant_id_and_sku ON public.product_variants USING btree (tenant_id, sku) WHERE (sku IS NOT NULL);


--
-- Name: index_products_on_brand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_on_brand_id ON public.products USING btree (brand_id);


--
-- Name: index_products_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_on_tenant_id ON public.products USING btree (tenant_id);


--
-- Name: index_products_on_tenant_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_products_on_tenant_id_and_slug ON public.products USING btree (tenant_id, slug);


--
-- Name: index_shopper_email_codes_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shopper_email_codes_on_tenant_id ON public.shopper_email_codes USING btree (tenant_id);


--
-- Name: index_shopper_email_codes_on_tenant_id_and_purpose_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shopper_email_codes_on_tenant_id_and_purpose_and_email ON public.shopper_email_codes USING btree (tenant_id, purpose, email);


--
-- Name: index_shopper_sessions_on_shopper_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shopper_sessions_on_shopper_id ON public.shopper_sessions USING btree (shopper_id);


--
-- Name: index_shopper_sessions_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shopper_sessions_on_tenant_id ON public.shopper_sessions USING btree (tenant_id);


--
-- Name: index_shopper_sessions_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shopper_sessions_on_token_digest ON public.shopper_sessions USING btree (token_digest);


--
-- Name: index_shoppers_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shoppers_on_staff_id ON public.shoppers USING btree (staff_id);


--
-- Name: index_shoppers_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shoppers_on_tenant_id ON public.shoppers USING btree (tenant_id);


--
-- Name: index_shoppers_on_tenant_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shoppers_on_tenant_id_and_email ON public.shoppers USING btree (tenant_id, email);


--
-- Name: index_staff_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_on_tenant_id ON public.staff USING btree (tenant_id);


--
-- Name: index_staff_on_tenant_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_on_tenant_id_and_email ON public.staff USING btree (tenant_id, email);


--
-- Name: index_staff_sessions_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_sessions_on_staff_id ON public.staff_sessions USING btree (staff_id);


--
-- Name: index_staff_sessions_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_sessions_on_tenant_id ON public.staff_sessions USING btree (tenant_id);


--
-- Name: index_staff_sessions_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_sessions_on_token_digest ON public.staff_sessions USING btree (token_digest);


--
-- Name: index_tenant_api_keys_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tenant_api_keys_on_tenant_id ON public.tenant_api_keys USING btree (tenant_id);


--
-- Name: index_tenant_api_keys_on_tenant_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tenant_api_keys_on_tenant_id_and_created_at ON public.tenant_api_keys USING btree (tenant_id, created_at);


--
-- Name: index_tenant_api_keys_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenant_api_keys_on_token_digest ON public.tenant_api_keys USING btree (token_digest);


--
-- Name: index_tenant_domains_on_hostname; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenant_domains_on_hostname ON public.tenant_domains USING btree (hostname);


--
-- Name: index_tenant_domains_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tenant_domains_on_tenant_id ON public.tenant_domains USING btree (tenant_id);


--
-- Name: index_tenant_domains_on_tenant_id_and_is_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tenant_domains_on_tenant_id_and_is_primary ON public.tenant_domains USING btree (tenant_id, is_primary);


--
-- Name: index_tenant_domains_one_primary_per_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenant_domains_one_primary_per_tenant ON public.tenant_domains USING btree (tenant_id) WHERE is_primary;


--
-- Name: index_tenant_settings_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenant_settings_on_tenant_id ON public.tenant_settings USING btree (tenant_id);


--
-- Name: index_tenants_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenants_on_slug ON public.tenants USING btree (slug);


--
-- Name: index_versions_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_tenant_id ON public.versions USING btree (tenant_id);


--
-- Name: index_versions_on_tenant_id_and_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_tenant_id_and_item_type_and_item_id ON public.versions USING btree (tenant_id, item_type, item_id);


--
-- Name: tenant_api_keys freeze_token_digest; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER freeze_token_digest BEFORE UPDATE OF token_digest, token_prefix ON public.tenant_api_keys FOR EACH ROW WHEN (((old.token_digest IS DISTINCT FROM new.token_digest) OR (old.token_prefix IS DISTINCT FROM new.token_prefix))) EXECUTE FUNCTION public.tenant_api_keys_reject_token_change();


--
-- Name: admin_sessions fk_rails_879ac839ae; Type: FK CONSTRAINT; Schema: platform; Owner: -
--

ALTER TABLE ONLY platform.admin_sessions
    ADD CONSTRAINT fk_rails_879ac839ae FOREIGN KEY (admin_id) REFERENCES platform.admins(id) ON DELETE CASCADE;


--
-- Name: brands fk_rails_052f97e5af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT fk_rails_052f97e5af FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: versions fk_rails_06b8b76679; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT fk_rails_06b8b76679 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_domains fk_rails_1987f42a92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_domains
    ADD CONSTRAINT fk_rails_1987f42a92 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: shoppers fk_rails_20ad1531ba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shoppers
    ADD CONSTRAINT fk_rails_20ad1531ba FOREIGN KEY (staff_id) REFERENCES public.staff(id);


--
-- Name: tenant_settings fk_rails_3edf7ce8f1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT fk_rails_3edf7ce8f1 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: login_attempts fk_rails_4e3518a87b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_attempts
    ADD CONSTRAINT fk_rails_4e3518a87b FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: product_categorizations fk_rails_52d3dc85fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categorizations
    ADD CONSTRAINT fk_rails_52d3dc85fd FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: shopper_sessions fk_rails_5315be07a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shopper_sessions
    ADD CONSTRAINT fk_rails_5315be07a5 FOREIGN KEY (shopper_id) REFERENCES public.shoppers(id) ON DELETE CASCADE;


--
-- Name: staff fk_rails_61253bcc4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff
    ADD CONSTRAINT fk_rails_61253bcc4f FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: product_variants fk_rails_66387557fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT fk_rails_66387557fd FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: categories fk_rails_82f48f7407; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_82f48f7407 FOREIGN KEY (parent_id) REFERENCES public.categories(id);


--
-- Name: shopper_email_codes fk_rails_8d2d640287; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shopper_email_codes
    ADD CONSTRAINT fk_rails_8d2d640287 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: product_categorizations fk_rails_9399c1d791; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categorizations
    ADD CONSTRAINT fk_rails_9399c1d791 FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: product_categorizations fk_rails_9472f7aede; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categorizations
    ADD CONSTRAINT fk_rails_9472f7aede FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: staff_sessions fk_rails_b69a960ef4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_sessions
    ADD CONSTRAINT fk_rails_b69a960ef4 FOREIGN KEY (staff_id) REFERENCES public.staff(id) ON DELETE CASCADE;


--
-- Name: categories fk_rails_cf18d1e171; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_cf18d1e171 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_api_keys fk_rails_cf4e1e4e6e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_api_keys
    ADD CONSTRAINT fk_rails_cf4e1e4e6e FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: shopper_sessions fk_rails_d23dfe0ae6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shopper_sessions
    ADD CONSTRAINT fk_rails_d23dfe0ae6 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: product_variants fk_rails_dae52f850b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT fk_rails_dae52f850b FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: shoppers fk_rails_e62ebc1b85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shoppers
    ADD CONSTRAINT fk_rails_e62ebc1b85 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: staff_sessions fk_rails_e948faa396; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_sessions
    ADD CONSTRAINT fk_rails_e948faa396 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: products fk_rails_f3b4d49caa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_f3b4d49caa FOREIGN KEY (brand_id) REFERENCES public.brands(id);


--
-- Name: products fk_rails_fbc24595c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_fbc24595c9 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_api_keys api_key_lookup; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY api_key_lookup ON public.tenant_api_keys FOR SELECT USING ((token_digest = NULLIF(current_setting('app.api_key_digest'::text, true), ''::text)));


--
-- Name: brands; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: login_attempts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: product_categorizations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_categorizations ENABLE ROW LEVEL SECURITY;

--
-- Name: product_variants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;

--
-- Name: products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

--
-- Name: shopper_email_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shopper_email_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: shopper_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shopper_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: shoppers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shoppers ENABLE ROW LEVEL SECURITY;

--
-- Name: staff; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;

--
-- Name: staff_sessions staff_session_lookup; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staff_session_lookup ON public.staff_sessions FOR SELECT USING ((token_digest = NULLIF(current_setting('app.staff_session_digest'::text, true), ''::text)));


--
-- Name: staff_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staff_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_api_keys; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_api_keys ENABLE ROW LEVEL SECURITY;

--
-- Name: tenant_domains; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: brands tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.brands USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: categories tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.categories USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: login_attempts tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.login_attempts USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: product_categorizations tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.product_categorizations USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: product_variants tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.product_variants USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: products tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.products USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: shopper_email_codes tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.shopper_email_codes USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: shopper_sessions tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.shopper_sessions USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: shoppers tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.shoppers USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: staff tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.staff USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: staff_sessions tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.staff_sessions USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: tenant_api_keys tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.tenant_api_keys USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: tenant_domains tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.tenant_domains USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: tenant_settings tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.tenant_settings USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: versions tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.versions USING ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)) WITH CHECK ((tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid));


--
-- Name: tenant_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tenant_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.versions ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;


GRANT USAGE ON SCHEMA public TO "toulouse_app";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "toulouse_app";
REVOKE ALL ON "schema_migrations", "ar_internal_metadata" FROM "toulouse_app";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "toulouse_app";

GRANT USAGE ON SCHEMA public TO "toulouse_platform";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "toulouse_platform";
REVOKE ALL ON "schema_migrations", "ar_internal_metadata" FROM "toulouse_platform";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "toulouse_platform";
GRANT USAGE ON SCHEMA platform TO "toulouse_platform";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA platform TO "toulouse_platform";
ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "toulouse_platform";
INSERT INTO "schema_migrations" (version) VALUES
('20261012130000'),
('20261012120300'),
('20261012120200'),
('20261012120100'),
('20261012120000'),
('20261011120000'),
('20261008200000'),
('20261008180000'),
('20261007180100'),
('20261007180000'),
('20261007120000'),
('20261006180000'),
('20261004190100'),
('20261004190000'),
('20261004080536'),
('20260930194708'),
('20260930194057'),
('20260926180646'),
('20260926180509'),
('20260926180319'),
('20260926180007'),
('0');

