-- =============================================================================
-- Oracle's object-relational layer: object types, typed tables, REF navigation.
--
-- The same herd, remodelled. Instead of foreign keys carrying values that a join
-- resolves, the columns hold REFs -- pointers to row objects -- and navigation
-- is a dot: E.cat.name rather than a join back to CATS.
--
-- Prerequisite: the relational schema from sql/01_schema must already exist.
-- These tables take foreign keys against Functions, Bands and Enemies.
--
-- Constraint names are unique per schema in Oracle, not per table, so every
-- constraint here carries an _r suffix to avoid colliding with the relational
-- schema's names.
-- =============================================================================

SET SERVEROUTPUT ON

-- -----------------------------------------------------------------------------
-- Types. Each CREATE TYPE is terminated by / -- inside a type body a bare
-- semicolon ends the enclosed statement, not the body, so a file without the
-- slashes cannot be run as a script.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TYPE cat_type AS OBJECT (
    name          VARCHAR2(15),
    gender        VARCHAR2(1),
    nickname      VARCHAR2(15),
    function      VARCHAR2(10),
    chief         REF cat_type,
    in_herd_since DATE,
    mice_ration   NUMBER(3),
    mice_extra    NUMBER(3),
    band_no       NUMBER(3),

    MEMBER FUNCTION get_name          RETURN VARCHAR2,
    MEMBER FUNCTION get_total_eats    RETURN NUMBER,
    -- Returns VARCHAR2, matching what the body produces. Declaring RETURN DATE
    -- over a TO_CHAR body makes Oracle convert the string back through the
    -- session's NLS format -- silent on a matching session, PLS-00382 on any
    -- other.
    MEMBER FUNCTION get_in_herd_since RETURN VARCHAR2
);
/

CREATE OR REPLACE TYPE BODY cat_type AS

    MEMBER FUNCTION get_name RETURN VARCHAR2 IS
    BEGIN
        RETURN name;
    END get_name;

    MEMBER FUNCTION get_total_eats RETURN NUMBER IS
    BEGIN
        RETURN NVL(mice_ration, 0) + NVL(mice_extra, 0);
    END get_total_eats;

    MEMBER FUNCTION get_in_herd_since RETURN VARCHAR2 IS
    BEGIN
        RETURN TO_CHAR(in_herd_since, 'YYYY-MM-DD');
    END get_in_herd_since;

END;
/

CREATE OR REPLACE TYPE common_type AS OBJECT (
    common_id NUMBER,
    cat       REF cat_type
);
/

CREATE OR REPLACE TYPE elite_type AS OBJECT (
    id_elite NUMBER,
    cat      REF cat_type,
    servant  REF common_type
);
/

CREATE OR REPLACE TYPE account_type AS OBJECT (
    action_id     NUMBER,
    owner         REF elite_type,
    creation_date DATE,
    deletion_date DATE,

    MEMBER PROCEDURE open_account,
    MEMBER PROCEDURE close_account
);
/

CREATE OR REPLACE TYPE BODY account_type AS

    -- A MEMBER PROCEDURE receives SELF as IN OUT by default, so assigning to an
    -- attribute here mutates the object instance the caller holds.
    MEMBER PROCEDURE open_account IS
    BEGIN
        creation_date := SYSDATE;
        deletion_date := NULL;
    END open_account;

    MEMBER PROCEDURE close_account IS
    BEGIN
        deletion_date := SYSDATE;
    END close_account;

END;
/

CREATE OR REPLACE TYPE incident_type AS OBJECT (
    incident_id          NUMBER,
    victim               REF cat_type,
    enemy_name           VARCHAR2(15),
    incident_date        DATE,
    incident_description VARCHAR2(50),

    MEMBER FUNCTION get_info RETURN VARCHAR2
);
/

CREATE OR REPLACE TYPE BODY incident_type AS

    MEMBER FUNCTION get_info RETURN VARCHAR2 IS
    BEGIN
        -- The date is formatted explicitly. Concatenating a DATE onto a string
        -- relies on NLS_DATE_FORMAT and produces different text per session.
        RETURN 'Incident with ' || enemy_name ||
               ' on ' || TO_CHAR(incident_date, 'YYYY-MM-DD');
    END get_info;

END;
/

-- -----------------------------------------------------------------------------
-- Object tables.
-- -----------------------------------------------------------------------------
CREATE TABLE CatsR OF cat_type (
    CONSTRAINT cats_r_pk          PRIMARY KEY (nickname),
    CONSTRAINT cats_r_function_fk FOREIGN KEY (function) REFERENCES Functions(function),
    CONSTRAINT cats_r_band_fk     FOREIGN KEY (band_no)  REFERENCES Bands(band_no)
);

CREATE TABLE Commons OF common_type (
    CONSTRAINT commons_pk PRIMARY KEY (common_id),
    cat NOT NULL,
    -- SCOPE FOR constrains the REF to one table. Without it a REF may point at
    -- any table of the type, the pointer needs more storage, and Oracle cannot
    -- resolve dot navigation as efficiently.
    SCOPE FOR (cat) IS CatsR
);

CREATE TABLE Elites OF elite_type (
    CONSTRAINT elites_pk PRIMARY KEY (id_elite),
    cat NOT NULL,
    SCOPE FOR (cat)     IS CatsR,
    SCOPE FOR (servant) IS Commons
);

CREATE TABLE Accounts OF account_type (
    CONSTRAINT accounts_pk PRIMARY KEY (action_id),
    SCOPE FOR (owner) IS Elites,
    CONSTRAINT accounts_creation_nn CHECK (creation_date IS NOT NULL),
    -- An account cannot be closed before it was opened. Note the direction:
    -- creation_date >= deletion_date would assert the reverse and reject every
    -- correctly ordered pair.
    CONSTRAINT accounts_date_order_ck
        CHECK (deletion_date IS NULL OR deletion_date >= creation_date)
);

-- Named IncidentsR, not Incidents: the relational schema already owns that
-- name, and both labs are meant to coexist in one schema.
CREATE TABLE IncidentsR OF incident_type (
    CONSTRAINT incidents_r_pk       PRIMARY KEY (incident_id),
    CONSTRAINT incidents_r_enemy_fk FOREIGN KEY (enemy_name) REFERENCES Enemies(enemy_name),
    SCOPE FOR (victim) IS CatsR,
    enemy_name    NOT NULL,
    incident_date NOT NULL
);
