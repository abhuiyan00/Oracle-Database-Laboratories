-- =============================================================================
-- Cat-herd schema: tables, constraints and the one circular foreign key.
--
-- Five relations model a herd of cats organised into bands, each cat holding a
-- function that caps how many mice it may draw, and each cat logging incidents
-- against the herd's enemies.
--
--   FUNCTIONS  1---*  CATS  *---1  BANDS
--                      |             |
--                      |             +-- band_chief -> CATS.nickname
--                      |
--                      *  INCIDENTS  *---1  ENEMIES
--
-- CATS.band_no references BANDS, and BANDS.band_chief references CATS, so the
-- two tables are mutually dependent. Neither can be created with both keys in
-- place, so CATS is created first without its band key and the constraint is
-- added by ALTER TABLE once BANDS exists. Seeding has the same problem and is
-- handled in 03_seed_data.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- FUNCTIONS -- the role a cat holds, and the mice ration band that role allows.
-- -----------------------------------------------------------------------------
CREATE TABLE Functions (
    function    VARCHAR2(10)
                CONSTRAINT functions_pk PRIMARY KEY,
    min_mice    NUMBER(3)
                CONSTRAINT functions_min_mice_ck CHECK (min_mice > 5),
    max_mice    NUMBER(3)
                CONSTRAINT functions_max_mice_ck CHECK (max_mice > 5 AND max_mice <= 200),
    -- An upper bound below the lower bound would make the role unsatisfiable,
    -- so the two columns are also constrained against each other.
    CONSTRAINT functions_range_ck CHECK (max_mice >= min_mice)
);

-- -----------------------------------------------------------------------------
-- ENEMIES -- everything the herd has to defend itself against.
-- -----------------------------------------------------------------------------
CREATE TABLE Enemies (
    enemy_name       VARCHAR2(15)
                     CONSTRAINT enemies_pk PRIMARY KEY,
    hostility_degree NUMBER(2)
                     CONSTRAINT enemies_hostility_ck CHECK (hostility_degree BETWEEN 1 AND 10),
    species          VARCHAR2(15),
    bribe            VARCHAR2(20)
);

-- -----------------------------------------------------------------------------
-- CATS -- the herd itself. Self-referencing on chief, and band_no is added
-- further down once BANDS exists.
-- -----------------------------------------------------------------------------
CREATE TABLE Cats (
    name          VARCHAR2(15)
                  CONSTRAINT cats_name_nn NOT NULL,
    gender        VARCHAR2(1)
                  CONSTRAINT cats_gender_ck CHECK (gender IN ('M', 'W')),
    nickname      VARCHAR2(15)
                  CONSTRAINT cats_pk PRIMARY KEY,
    function      VARCHAR2(10)
                  CONSTRAINT cats_function_fk REFERENCES Functions(function),
    -- The chief of a cat is another cat. Pointing this key at chief rather than
    -- at nickname is what makes the reporting hierarchy enforceable -- every
    -- CONNECT BY query in sql/02_queries walks it.
    chief         VARCHAR2(15)
                  CONSTRAINT cats_chief_fk REFERENCES Cats(nickname),
    in_herd_since DATE DEFAULT SYSDATE
                  CONSTRAINT cats_in_herd_since_nn NOT NULL,
    mice_ration   NUMBER(3),
    mice_extra    NUMBER(2),
    band_no       NUMBER(2)
);

-- -----------------------------------------------------------------------------
-- BANDS -- hunting parties. Each band has at most one chief, who is a cat.
-- -----------------------------------------------------------------------------
CREATE TABLE Bands (
    band_no    NUMBER(2)
               CONSTRAINT bands_pk PRIMARY KEY,
    name       VARCHAR2(20)
               CONSTRAINT bands_name_nn NOT NULL,
    site       VARCHAR2(15)
               CONSTRAINT bands_site_uq UNIQUE,
    band_chief VARCHAR2(15)
               CONSTRAINT bands_chief_uq UNIQUE
               CONSTRAINT bands_chief_fk REFERENCES Cats(nickname)
);

-- The second half of the circular dependency, now that BANDS exists.
ALTER TABLE Cats
    ADD CONSTRAINT cats_band_no_fk FOREIGN KEY (band_no) REFERENCES Bands(band_no);

-- -----------------------------------------------------------------------------
-- INCIDENTS -- a run-in between one cat and one enemy.
--
-- The primary key is (nickname, enemy_name), which is what the assignment
-- specifies. Note the consequence: a cat cannot record two separate incidents
-- with the same enemy. Adding incident_date to the key would lift that
-- restriction, and would be the right call outside the assignment's constraints.
-- -----------------------------------------------------------------------------
CREATE TABLE Incidents (
    nickname      VARCHAR2(15)
                  CONSTRAINT incidents_cat_fk REFERENCES Cats(nickname),
    enemy_name    VARCHAR2(15)
                  CONSTRAINT incidents_enemy_fk REFERENCES Enemies(enemy_name),
    incident_date DATE
                  CONSTRAINT incidents_date_nn NOT NULL,
    incident_desc VARCHAR2(50),
    CONSTRAINT incidents_pk PRIMARY KEY (nickname, enemy_name)
);

-- -----------------------------------------------------------------------------
-- Verify what was actually created.
-- -----------------------------------------------------------------------------
SELECT table_name, constraint_name, constraint_type
FROM   user_constraints
WHERE  table_name IN ('CATS', 'BANDS', 'FUNCTIONS', 'ENEMIES', 'INCIDENTS')
ORDER  BY table_name, constraint_type, constraint_name;
