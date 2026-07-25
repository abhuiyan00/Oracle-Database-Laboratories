-- =============================================================================
-- Anonymous PL/SQL blocks: SELECT INTO, control flow, user-defined exceptions.
--
-- SELECT INTO is all-or-nothing. Exactly one row satisfies it; zero rows raise
-- NO_DATA_FOUND and two or more raise TOO_MANY_ROWS. Both are exceptions, not
-- return values, so every block below that uses it handles them explicitly.
-- =============================================================================

SET SERVEROUTPUT ON

-- -----------------------------------------------------------------------------
-- 34. Look up a function by name and report whether it exists.
--
-- The handlers print the name that was searched for, not the INTO target. When
-- SELECT INTO raises, its target is left unassigned, so reporting the variable
-- would print an empty string where the name should be.
-- -----------------------------------------------------------------------------
DECLARE
    searched_for  VARCHAR2(10) := UPPER('&functionname');
    found_function Functions.function%TYPE;
BEGIN
    SELECT function
    INTO   found_function
    FROM   Functions
    WHERE  function = searched_for;

    DBMS_OUTPUT.PUT_LINE(found_function || ' - function found');
EXCEPTION
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE(searched_for || ' - function found more than once');
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(searched_for || ' - function not found');
END;
/

-- -----------------------------------------------------------------------------
-- 35. Classify one cat against a chain of criteria.
--
-- ELSIF, not a sequence of IFs: the branches are mutually exclusive by design
-- and the first match wins.
-- -----------------------------------------------------------------------------
DECLARE
    searched_for   VARCHAR2(15) := '&nickname';
    cat_name       Cats.name%TYPE;
    cat_ration     NUMBER;
    cat_join_month NUMBER;
BEGIN
    SELECT name,
           (NVL(mice_ration, 0) + NVL(mice_extra, 0)) * 12,
           EXTRACT(MONTH FROM in_herd_since)
    INTO   cat_name, cat_ration, cat_join_month
    FROM   Cats
    WHERE  nickname = searched_for;

    IF cat_ration > 700 THEN
        DBMS_OUTPUT.PUT_LINE(cat_name || ': total annual mice ration > 700');
    ELSIF cat_name LIKE '%A%' THEN
        DBMS_OUTPUT.PUT_LINE(cat_name || ': name contains the letter A');
    ELSIF cat_join_month = 5 THEN
        DBMS_OUTPUT.PUT_LINE(cat_name || ': May is the month of joining the herd');
    ELSE
        DBMS_OUTPUT.PUT_LINE(cat_name || ': does not match the criteria');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No cat with nickname ' || searched_for);
END;
/

-- -----------------------------------------------------------------------------
-- 39. Insert a band, refusing duplicates on any of its three unique attributes.
--
-- Two details worth the keystrokes:
--
--   * Every predicate qualifies the column with its table name. Where a local
--     or a parameter shares a name with a column, PL/SQL resolves in favour of
--     the PL/SQL identifier -- turning "WHERE name = name_band" into a
--     tautology and silently disabling the check. The procedure version in
--     03_procedures_and_packages.sql has exactly that collision.
--
--   * The message buffer is VARCHAR2(200), not 50. Three clashes appended to a
--     50-character buffer overflow it, and ORA-06502 replaces the diagnostic
--     the handler was written to produce.
-- -----------------------------------------------------------------------------
DECLARE
    no_band    NUMBER        := &number_of_band;
    name_band  Bands.name%TYPE := '&band_name';
    hunt_site  Bands.site%TYPE := '&hunt_site';

    clashes           NUMBER;
    clash_message     VARCHAR2(200) := '';
    already_exists    EXCEPTION;
    invalid_band_no   EXCEPTION;
BEGIN
    IF no_band <= 0 THEN
        RAISE invalid_band_no;
    END IF;

    SELECT COUNT(*) INTO clashes FROM Bands WHERE Bands.band_no = no_band;
    IF clashes > 0 THEN
        clash_message := clash_message || ' ' || no_band || ',';
    END IF;

    SELECT COUNT(*) INTO clashes FROM Bands WHERE Bands.name = name_band;
    IF clashes > 0 THEN
        clash_message := clash_message || ' ' || name_band || ',';
    END IF;

    SELECT COUNT(*) INTO clashes FROM Bands WHERE Bands.site = hunt_site;
    IF clashes > 0 THEN
        clash_message := clash_message || ' ' || hunt_site || ',';
    END IF;

    IF LENGTH(clash_message) > 0 THEN
        RAISE already_exists;
    END IF;

    INSERT INTO Bands (band_no, name, site) VALUES (no_band, name_band, hunt_site);
    DBMS_OUTPUT.PUT_LINE('Band ' || no_band || ' added.');
EXCEPTION
    WHEN invalid_band_no THEN
        DBMS_OUTPUT.PUT_LINE('Band number ' || no_band || ' must be greater than 0.');
    WHEN already_exists THEN
        DBMS_OUTPUT.PUT_LINE(TRIM(TRAILING ',' FROM clash_message) || ': already exists');
END;
/

ROLLBACK;
