

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;




ALTER SCHEMA "public" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."avail_status_t" AS ENUM (
    'Available',
    'On Loan',
    'Reserved'
);


ALTER TYPE "public"."avail_status_t" OWNER TO "postgres";


CREATE TYPE "public"."item_type_t" AS ENUM (
    'Book',
    'Digital Media',
    'Magazine'
);


ALTER TYPE "public"."item_type_t" OWNER TO "postgres";


CREATE TYPE "public"."media_format_t" AS ENUM (
    'eBook',
    'Audiobook',
    'Video',
    'Other'
);


ALTER TYPE "public"."media_format_t" OWNER TO "postgres";


CREATE TYPE "public"."membership_status_t" AS ENUM (
    'Active',
    'Suspended',
    'Overdue'
);


ALTER TYPE "public"."membership_status_t" OWNER TO "postgres";


CREATE TYPE "public"."membership_type_name_t" AS ENUM (
    'Regular',
    'Student',
    'Senior Citizen'
);


ALTER TYPE "public"."membership_type_name_t" OWNER TO "postgres";


CREATE TYPE "public"."notification_type_t" AS ENUM (
    'Reservation',
    'Due Date Alert',
    'Overdue Alert'
);


ALTER TYPE "public"."notification_type_t" OWNER TO "postgres";


CREATE TYPE "public"."staff_role_t" AS ENUM (
    'Librarian',
    'Administrator'
);


ALTER TYPE "public"."staff_role_t" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_calc_fine"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    days_late INT;
    rate      NUMERIC(5,2);
BEGIN
    IF NEW.return_date IS NOT NULL THEN
        days_late := GREATEST((NEW.return_date - NEW.due_date), 0);
        SELECT mt.fine_rate INTO rate
          FROM members m
          JOIN membership_types mt ON mt.type_id = m.membership_type_id
         WHERE m.member_id = NEW.member_id;

        NEW.fine_incurred := days_late * COALESCE(rate,0);
    END IF;
    RETURN NEW;
END; $$;


ALTER FUNCTION "public"."trg_calc_fine"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_check_borrow_limit"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    current_loans INT;
    max_allowed   INT;
BEGIN
    SELECT COUNT(*) INTO current_loans
      FROM borrowing_transactions
     WHERE member_id = NEW.member_id
       AND return_date IS NULL;

    SELECT mt.max_borrow_limit INTO max_allowed
      FROM members m
      JOIN membership_types mt ON mt.type_id = m.membership_type_id
     WHERE m.member_id = NEW.member_id;

    IF current_loans >= COALESCE(max_allowed, 3) THEN
        RAISE EXCEPTION
          'Borrow-limit exceeded for member % (allowed %)', NEW.member_id, max_allowed;
    END IF;
    RETURN NEW;
END; $$;


ALTER FUNCTION "public"."trg_check_borrow_limit"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_return_item_available"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.return_date IS NOT NULL AND OLD.return_date IS NULL THEN
        UPDATE library_items
           SET availability_status = 'Available'
         WHERE item_id = NEW.item_id;
    END IF;
    RETURN NEW;
END; $$;


ALTER FUNCTION "public"."trg_return_item_available"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_set_item_on_loan"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE library_items
       SET availability_status = 'On Loan'
     WHERE item_id = NEW.item_id;
    RETURN NEW;
END; $$;


ALTER FUNCTION "public"."trg_set_item_on_loan"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."books" (
    "book_id" bigint NOT NULL,
    "isbn" "text" NOT NULL,
    "author" "text" NOT NULL,
    "genre" "text",
    "publication_year" smallint
);


ALTER TABLE "public"."books" OWNER TO "postgres";


COMMENT ON TABLE "public"."books" IS 'Book-specific details extending library_items';



CREATE TABLE IF NOT EXISTS "public"."borrowing_transactions" (
    "borrow_id" bigint NOT NULL,
    "member_id" bigint NOT NULL,
    "item_id" bigint NOT NULL,
    "staff_id" bigint,
    "borrow_date" "date" NOT NULL,
    "due_date" "date" NOT NULL,
    "return_date" "date",
    "fine_incurred" numeric(5,2),
    CONSTRAINT "borrowing_transactions_fine_incurred_check" CHECK ((("fine_incurred" IS NULL) OR ("fine_incurred" >= (0)::numeric)))
);


ALTER TABLE "public"."borrowing_transactions" OWNER TO "postgres";


COMMENT ON TABLE "public"."borrowing_transactions" IS 'Records of items borrowed by members';



ALTER TABLE "public"."borrowing_transactions" ALTER COLUMN "borrow_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."borrowing_transactions_borrow_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."digital_media" (
    "media_id" bigint NOT NULL,
    "creator" "text" NOT NULL,
    "format" "public"."media_format_t" NOT NULL
);


ALTER TABLE "public"."digital_media" OWNER TO "postgres";


COMMENT ON TABLE "public"."digital_media" IS 'Digital media details extending library_items';



CREATE TABLE IF NOT EXISTS "public"."library_items" (
    "item_id" bigint NOT NULL,
    "title" "text" NOT NULL,
    "item_type" "public"."item_type_t" NOT NULL,
    "availability_status" "public"."avail_status_t" DEFAULT 'Available'::"public"."avail_status_t" NOT NULL
);


ALTER TABLE "public"."library_items" OWNER TO "postgres";


COMMENT ON TABLE "public"."library_items" IS 'Contains all library items regardless of type';



ALTER TABLE "public"."library_items" ALTER COLUMN "item_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."library_items_item_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."magazines" (
    "magazine_id" bigint NOT NULL,
    "issue_number" integer NOT NULL,
    "publication_date" "date" NOT NULL
);


ALTER TABLE "public"."magazines" OWNER TO "postgres";


COMMENT ON TABLE "public"."magazines" IS 'Magazine-specific details extending library_items';



CREATE TABLE IF NOT EXISTS "public"."members" (
    "member_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "contact_info" "text",
    "membership_type_id" bigint,
    "account_status" "public"."membership_status_t" DEFAULT 'Active'::"public"."membership_status_t" NOT NULL
);


ALTER TABLE "public"."members" OWNER TO "postgres";


COMMENT ON TABLE "public"."members" IS 'Library members and their account information';



ALTER TABLE "public"."members" ALTER COLUMN "member_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."members_member_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."membership_types" (
    "type_id" bigint NOT NULL,
    "type_name" "public"."membership_type_name_t" NOT NULL,
    "max_borrow_limit" integer NOT NULL,
    "fine_rate" numeric(5,2) NOT NULL,
    CONSTRAINT "membership_types_fine_rate_check" CHECK (("fine_rate" >= (0)::numeric)),
    CONSTRAINT "membership_types_max_borrow_limit_check" CHECK (("max_borrow_limit" > 0))
);


ALTER TABLE "public"."membership_types" OWNER TO "postgres";


COMMENT ON TABLE "public"."membership_types" IS 'Stores different membership types and their privileges';



ALTER TABLE "public"."membership_types" ALTER COLUMN "type_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."membership_types_type_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "notification_id" bigint NOT NULL,
    "member_id" bigint NOT NULL,
    "notification_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "notification_type" "public"."notification_type_t" NOT NULL
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


COMMENT ON TABLE "public"."notifications" IS 'Member notifications for various events';



ALTER TABLE "public"."notifications" ALTER COLUMN "notification_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."notifications_notification_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."payments" (
    "payment_id" bigint NOT NULL,
    "member_id" bigint NOT NULL,
    "amount_paid" numeric(7,2) NOT NULL,
    "payment_date" "date" NOT NULL,
    CONSTRAINT "payments_amount_paid_check" CHECK (("amount_paid" >= (0)::numeric))
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


COMMENT ON TABLE "public"."payments" IS 'Payment records for fines and fees';



ALTER TABLE "public"."payments" ALTER COLUMN "payment_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."payments_payment_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."reservations" (
    "reservation_id" bigint NOT NULL,
    "member_id" bigint NOT NULL,
    "item_id" bigint NOT NULL,
    "reservation_date" "date" NOT NULL,
    "expiry_date" "date" NOT NULL,
    CONSTRAINT "reservations_check" CHECK (("expiry_date" >= "reservation_date"))
);


ALTER TABLE "public"."reservations" OWNER TO "postgres";


COMMENT ON TABLE "public"."reservations" IS 'Item reservations by members';



ALTER TABLE "public"."reservations" ALTER COLUMN "reservation_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."reservations_reservation_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."staff" (
    "staff_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "role" "public"."staff_role_t" NOT NULL,
    "contact_info" "text" NOT NULL
);


ALTER TABLE "public"."staff" OWNER TO "postgres";


COMMENT ON TABLE "public"."staff" IS 'Library staff members and their roles';



ALTER TABLE "public"."staff" ALTER COLUMN "staff_id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."staff_staff_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE ONLY "public"."books"
    ADD CONSTRAINT "books_isbn_key" UNIQUE ("isbn");



ALTER TABLE ONLY "public"."books"
    ADD CONSTRAINT "books_pkey" PRIMARY KEY ("book_id");



ALTER TABLE ONLY "public"."borrowing_transactions"
    ADD CONSTRAINT "borrowing_transactions_pkey" PRIMARY KEY ("borrow_id");



ALTER TABLE ONLY "public"."digital_media"
    ADD CONSTRAINT "digital_media_pkey" PRIMARY KEY ("media_id");



ALTER TABLE ONLY "public"."library_items"
    ADD CONSTRAINT "library_items_pkey" PRIMARY KEY ("item_id");



ALTER TABLE ONLY "public"."magazines"
    ADD CONSTRAINT "magazines_issue_number_key" UNIQUE ("issue_number");



ALTER TABLE ONLY "public"."magazines"
    ADD CONSTRAINT "magazines_pkey" PRIMARY KEY ("magazine_id");



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_pkey" PRIMARY KEY ("member_id");



ALTER TABLE ONLY "public"."membership_types"
    ADD CONSTRAINT "membership_types_pkey" PRIMARY KEY ("type_id");



ALTER TABLE ONLY "public"."membership_types"
    ADD CONSTRAINT "membership_types_type_name_key" UNIQUE ("type_name");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("notification_id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("payment_id");



ALTER TABLE ONLY "public"."reservations"
    ADD CONSTRAINT "reservations_pkey" PRIMARY KEY ("reservation_id");



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_pkey" PRIMARY KEY ("staff_id");



CREATE OR REPLACE TRIGGER "after_borrow_set_on_loan" AFTER INSERT ON "public"."borrowing_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."trg_set_item_on_loan"();



CREATE OR REPLACE TRIGGER "after_update_return_date" AFTER UPDATE OF "return_date" ON "public"."borrowing_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."trg_return_item_available"();



CREATE OR REPLACE TRIGGER "before_borrow_enforce_limit" BEFORE INSERT ON "public"."borrowing_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."trg_check_borrow_limit"();



CREATE OR REPLACE TRIGGER "before_update_calc_fine" BEFORE UPDATE OF "return_date" ON "public"."borrowing_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."trg_calc_fine"();



ALTER TABLE ONLY "public"."books"
    ADD CONSTRAINT "books_book_id_fkey" FOREIGN KEY ("book_id") REFERENCES "public"."library_items"("item_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."borrowing_transactions"
    ADD CONSTRAINT "borrowing_transactions_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."library_items"("item_id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."borrowing_transactions"
    ADD CONSTRAINT "borrowing_transactions_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."borrowing_transactions"
    ADD CONSTRAINT "borrowing_transactions_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("staff_id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."digital_media"
    ADD CONSTRAINT "digital_media_media_id_fkey" FOREIGN KEY ("media_id") REFERENCES "public"."library_items"("item_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."magazines"
    ADD CONSTRAINT "magazines_magazine_id_fkey" FOREIGN KEY ("magazine_id") REFERENCES "public"."library_items"("item_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_membership_type_id_fkey" FOREIGN KEY ("membership_type_id") REFERENCES "public"."membership_types"("type_id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



ALTER TABLE ONLY "public"."reservations"
    ADD CONSTRAINT "reservations_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."library_items"("item_id");



ALTER TABLE ONLY "public"."reservations"
    ADD CONSTRAINT "reservations_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("member_id");



CREATE POLICY "Enable read access for authenticated users" ON "public"."membership_types" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."books" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."borrowing_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."digital_media" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."library_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."magazines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."membership_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reservations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."staff" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
























































































































































































































RESET ALL;
