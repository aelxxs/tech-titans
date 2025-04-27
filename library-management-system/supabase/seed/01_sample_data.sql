
/* 01_sample_data.sql  — runs through psycopg2 (no backslash meta-cmds) */

INSERT INTO membership_types (type_id, type_name, max_borrow_limit, fine_rate)
  OVERRIDING SYSTEM VALUE
VALUES
  (1,'Regular',5,0.25),
  (2,'Student',7,0.15),
  (3,'Senior Citizen',3,0.10);

INSERT INTO staff (staff_id, name, role, contact_info)
  OVERRIDING SYSTEM VALUE
VALUES
  (1,'Librarian Lee','Librarian','lee@library.org'),
  (2,'Admin Kim','Administrator','kim@library.org');

COMMIT;


-- -- 1) Fixed IDs for membership_types & staff so FKs match

-- INSERT INTO membership_types (type_id, type_name, max_borrow_limit, fine_rate) OVERRIDING SYSTEM VALUE
-- VALUES
--   (1,'Regular',5,0.25),
--   (2,'Student',7,0.15),
--   (3,'Senior Citizen',3,0.10);

-- INSERT INTO staff (staff_id, name, role, contact_info) OVERRIDING SYSTEM VALUE
-- VALUES
--   (1,'Librarian Lee','Librarian','lee@library.org'),
--   (2,'Admin Kim','Administrator','kim@library.org');

-- -- 2) Bulk-load remaining tables from the CSVs generated above
-- -- (Saved in the repo’s /seed directory or uploaded via Supabase Studio)

-- \copy members(name,contact_info,membership_type_id,account_status)
--       FROM 'members.csv' DELIMITER ',' CSV HEADER;

-- \copy library_items(title,item_type,availability_status)
--       FROM 'library_items.csv' DELIMITER ',' CSV HEADER;

-- -- Attach subtype rows in the same order the items were inserted
-- -- Books
-- WITH ids AS (
--   SELECT item_id
--         ,ROW_NUMBER() OVER () AS rn
--     FROM library_items
--    WHERE item_type='Book'
--    ORDER BY item_id)
-- INSERT INTO books(book_id,isbn,author,genre,publication_year)
-- SELECT i.item_id,b.isbn,b.author,b.genre,b.publication_year
--   FROM ids i
--   JOIN (
--         SELECT ROW_NUMBER() OVER () AS rn, *
--           FROM
--           (SELECT * FROM
--            pg_read_file('books.csv')  -- or use \copy with a temp table
--           ) AS raw
--        ) b USING(rn);

-- -- Digital media
-- WITH ids AS (
--   SELECT item_id, ROW_NUMBER() OVER () rn
--     FROM library_items
--    WHERE item_type='Digital Media'
--    ORDER BY item_id)
-- INSERT INTO digital_media(media_id,creator,format)
-- SELECT i.item_id,d.creator,d.format
--   FROM ids i
--   JOIN (
--         SELECT ROW_NUMBER() OVER () rn, *
--           FROM
--           (SELECT * FROM
--            pg_read_file('digital_media.csv')
--           ) AS raw
--        ) d USING(rn);

-- -- Magazines
-- WITH ids AS (
--   SELECT item_id, ROW_NUMBER() OVER () rn
--     FROM library_items
--    WHERE item_type='Magazine'
--    ORDER BY item_id)
-- INSERT INTO magazines(magazine_id,issue_number,publication_date)
-- SELECT i.item_id,m.issue_number,m.publication_date
--   FROM ids i
--   JOIN (
--         SELECT ROW_NUMBER() OVER () rn, *
--           FROM
--           (SELECT * FROM
--            pg_read_file('magazines.csv')
--           ) AS raw
--        ) m USING(rn);


-- COMMIT;
