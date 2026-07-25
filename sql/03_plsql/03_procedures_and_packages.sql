-- =============================================================================
-- Stored procedures and packages.
--
-- herd_admin groups the two operations the herd needs administratively: the
-- levy on a cat's consumption, and adding a band.
--
-- add_band reports failure through RAISE_APPLICATION_ERROR in the -20000 to
-- -20999 range Oracle reserves for application errors, rather than printing a
-- message and returning normally. A procedure that swallows its own exceptions
-- leaves the caller unable to tell a successful insert from a rejected one.
-- =============================================================================

SET SERVEROUTPUT ON

CREATE OR REPLACE PACKAGE herd_admin IS

    -- Levy on a cat's total consumption, plus surcharges for cats that lead
    -- nobody and cats that have never defended the herd.
    FUNCTION get_tax(cat_nickname Cats.nickname%TYPE) RETURN NUMBER;

    -- Insert a band, rejecting duplicates on band_no, name or site.
    PROCEDURE add_band(no_band   Bands.band_no%TYPE,
                       name_band Bands.name%TYPE,
                       hunt_site Bands.site%TYPE);

END herd_admin;
/

CREATE OR REPLACE PACKAGE BODY herd_admin IS

    FUNCTION get_tax(cat_nickname Cats.nickname%TYPE) RETURN NUMBER IS
        tax         NUMBER := 0;
        subordinates NUMBER;
        incidents   NUMBER;
        base_ration NUMBER;
    BEGIN
        SELECT CEIL(0.05 * (mice_ration + NVL(mice_extra, 0))),
               NVL(mice_ration, 0)
        INTO   tax, base_ration
        FROM   Cats
        WHERE  nickname = cat_nickname;

        -- Leads nobody.
        SELECT COUNT(*) INTO subordinates
        FROM   Cats
        WHERE  chief = cat_nickname;

        IF subordinates = 0 THEN
            tax := tax + 2;
        END IF;

        -- Has never been in a fight.
        SELECT COUNT(*) INTO incidents
        FROM   Incidents
        WHERE  nickname = cat_nickname;

        IF incidents = 0 THEN
            tax := tax + 1;
        END IF;

        -- Draws a large base ration.
        IF base_ration > 20 THEN
            tax := tax + 5;
        END IF;

        RETURN tax;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,
                'No cat with nickname ' || cat_nickname);
    END get_tax;


    PROCEDURE add_band(no_band   Bands.band_no%TYPE,
                       name_band Bands.name%TYPE,
                       hunt_site Bands.site%TYPE) IS
        clashes       NUMBER;
        clash_message VARCHAR2(200) := '';
    BEGIN
        IF no_band <= 0 THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Band number ' || no_band || ' must be greater than 0.');
        END IF;

        -- Every predicate qualifies the column with its table name. Without
        -- the qualifier the parameter wins over the identically named column,
        -- and the comparison degenerates into name_band = name_band -- always
        -- true, so every insert would be reported as a duplicate.
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
            RAISE_APPLICATION_ERROR(-20002,
                TRIM(TRAILING ',' FROM clash_message) || ': already exists');
        END IF;

        INSERT INTO Bands (band_no, name, site)
        VALUES (no_band, name_band, hunt_site);
    END add_band;

END herd_admin;
/

SHOW ERRORS PACKAGE BODY herd_admin

-- -----------------------------------------------------------------------------
-- Exercise the procedure. The first three calls each collide with an existing
-- band on a different column; the fourth is rejected on the band number.
-- -----------------------------------------------------------------------------
BEGIN
    FOR attempt IN (
        SELECT 2 AS no, 'BLACK KNIGHTS' AS nm, 'FIELD'   AS st FROM dual
        UNION ALL SELECT 6, 'SUPERIORS',     'CELLAR'  FROM dual
        UNION ALL SELECT 7, 'PINTO HUNTERS', 'HILLOCK' FROM dual
        UNION ALL SELECT 0, 'NEW',           'CAVE'    FROM dual
        UNION ALL SELECT 6, 'ROCK CATS',     'CELLAR'  FROM dual
    ) LOOP
        BEGIN
            herd_admin.add_band(attempt.no, attempt.nm, attempt.st);
            DBMS_OUTPUT.PUT_LINE('added band ' || attempt.no ||
                                 ' (' || attempt.nm || ')');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('rejected: ' || SQLERRM);
        END;
    END LOOP;
END;
/

SELECT * FROM Bands ORDER BY band_no;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- Tax owed by every cat in the herd.
-- -----------------------------------------------------------------------------
BEGIN
    FOR cat IN (SELECT nickname FROM Cats ORDER BY nickname) LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(cat.nickname, 10) || ' tax ' ||
                             herd_admin.get_tax(cat.nickname));
    END LOOP;
END;
/
