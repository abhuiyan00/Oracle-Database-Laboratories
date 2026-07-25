-- =============================================================================
-- Explicit cursors: FOR UPDATE / WHERE CURRENT OF, fetch loops, nested cursors.
--
-- Cursor FOR loops open, fetch and close automatically and cannot leak. Explicit
-- OPEN / FETCH / CLOSE is only worth the extra code when the loop needs to stop
-- early -- and then the CLOSE has to be written on every path out, including
-- the exception path.
-- =============================================================================

SET SERVEROUTPUT ON

-- -----------------------------------------------------------------------------
-- 36. Raise rations by 10% each pass, capped at each function's maximum, until
--     the herd's total consumption exceeds 1050.
--
-- The loop counts what each pass changed and exits when a pass achieves
-- nothing. A bare "WHILE total <= 1050" would not terminate: once every cat
-- sits at its function's ceiling no further increase is possible, total stops
-- moving, and the target may simply be unreachable.
-- -----------------------------------------------------------------------------
DECLARE
    CURSOR queue IS
        SELECT c.nickname,
               NVL(c.mice_ration, 0) AS eats,
               f.max_mice            AS max_allowed
        FROM   Cats      c
        JOIN   Functions f ON c.function = f.function
        ORDER  BY NVL(c.mice_ration, 0)
        FOR UPDATE OF c.mice_ration;

    total            NUMBER := 0;
    changes          NUMBER := 0;
    changes_this_pass NUMBER;
BEGIN
    SELECT SUM(NVL(mice_ration, 0)) INTO total FROM Cats;

    LOOP
        changes_this_pass := 0;

        FOR cat IN queue LOOP
            IF ROUND(cat.eats * 1.1) <= cat.max_allowed THEN
                UPDATE Cats
                SET    mice_ration = ROUND(mice_ration * 1.1)
                WHERE  CURRENT OF queue;

                total   := total + ROUND(cat.eats * 0.1);
                changes_this_pass := changes_this_pass + 1;

            ELSIF cat.eats <> cat.max_allowed THEN
                UPDATE Cats
                SET    mice_ration = cat.max_allowed
                WHERE  CURRENT OF queue;

                total   := total + cat.max_allowed - cat.eats;
                changes_this_pass := changes_this_pass + 1;
            END IF;
        END LOOP;

        changes := changes + changes_this_pass;

        -- Either the target is met, or nothing moved and it never will be.
        EXIT WHEN total > 1050 OR changes_this_pass = 0;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total ration ' || total || ', changes: ' || changes);
END;
/

SELECT name, mice_ration AS "Eats" FROM Cats ORDER BY mice_ration DESC;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- 37. The five hungriest cats, via an explicit fetch loop.
--
-- CLOSE is guaranteed here by an exception handler: the loop can exit early, and
-- an unclosed cursor holds its cursor slot for the whole session.
-- -----------------------------------------------------------------------------
DECLARE
    CURSOR top_cats IS
        SELECT nickname,
               NVL(mice_ration, 0) + NVL(mice_extra, 0) AS eats
        FROM   Cats
        ORDER  BY eats DESC;

    cat top_cats%ROWTYPE;
BEGIN
    OPEN top_cats;

    DBMS_OUTPUT.PUT_LINE('No   Nickname   Eats');
    DBMS_OUTPUT.PUT_LINE('----------------------');

    FOR i IN 1 .. 5 LOOP
        FETCH top_cats INTO cat;
        EXIT WHEN top_cats%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(RPAD(i, 5) || RPAD(cat.nickname, 11) ||
                             LPAD(cat.eats, 5));
    END LOOP;

    CLOSE top_cats;
EXCEPTION
    WHEN OTHERS THEN
        IF top_cats%ISOPEN THEN
            CLOSE top_cats;
        END IF;
        RAISE;
END;
/

-- -----------------------------------------------------------------------------
-- 38. For each rank-and-file cat, walk up N levels of chiefs and print them
--     across the row.
--
-- Substitution variables (&...) throughout, consistent with the rest of the
-- file -- mixing in a host bind (:name) would need a separate VARIABLE
-- declaration before the block would run under SQL*Plus.
--
-- The inner lookup is wrapped in its own block so that walking off the top of
-- the hierarchy ends the chain rather than raising NO_DATA_FOUND.
-- -----------------------------------------------------------------------------
DECLARE
    no_of_superiors NUMBER := &no_of_superiors;

    CURSOR under_cats IS
        SELECT nickname, name
        FROM   Cats
        WHERE  function IN ('CAT', 'NICE');

    chief_nickname Cats.chief%TYPE;
    chief_name     Cats.name%TYPE;
BEGIN
    DBMS_OUTPUT.PUT(RPAD('name ', 15));
    FOR i IN 1 .. no_of_superiors LOOP
        DBMS_OUTPUT.PUT(RPAD('|  Chief ' || i, 15));
    END LOOP;
    DBMS_OUTPUT.NEW_LINE;
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 15 * (no_of_superiors + 1), '-'));

    FOR cat IN under_cats LOOP
        DBMS_OUTPUT.PUT(RPAD(cat.name, 15));

        SELECT chief INTO chief_nickname FROM Cats WHERE nickname = cat.nickname;

        FOR level_no IN 1 .. no_of_superiors LOOP
            IF chief_nickname IS NULL THEN
                DBMS_OUTPUT.PUT(RPAD('|  ', 15));
            ELSE
                BEGIN
                    SELECT name, chief
                    INTO   chief_name, chief_nickname
                    FROM   Cats
                    WHERE  nickname = chief_nickname;

                    DBMS_OUTPUT.PUT(RPAD('|  ' || chief_name, 15));
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        chief_nickname := NULL;
                        DBMS_OUTPUT.PUT(RPAD('|  ', 15));
                END;
            END IF;
        END LOOP;

        DBMS_OUTPUT.NEW_LINE;
    END LOOP;
END;
/

-- -----------------------------------------------------------------------------
-- 43. A cross-tabulation of consumption: bands down the side, functions across
--     the top, gender splitting each band into two rows.
--
-- One pass aggregates into a collection, then formatting reads from it. Driving
-- the report straight from SQL would issue a query per cell -- bands x genders
-- x functions round trips to render one table.
-- -----------------------------------------------------------------------------
DECLARE
    TYPE cell_table IS TABLE OF NUMBER INDEX BY VARCHAR2(60);
    cells       cell_table;
    row_totals  cell_table;
    col_totals  cell_table;
    grand_total NUMBER := 0;

    key         VARCHAR2(60);
    line        VARCHAR2(4000);

    -- Reading an associative array at a key that was never assigned raises
    -- NO_DATA_FOUND rather than returning NULL, so every read goes through
    -- this helper instead of through NVL.
    FUNCTION value_at(source cell_table, at_key VARCHAR2) RETURN NUMBER IS
    BEGIN
        IF source.EXISTS(at_key) THEN
            RETURN source(at_key);
        END IF;
        RETURN 0;
    END value_at;

BEGIN
    -- One pass over the data fills every cell of the table.
    FOR r IN (
        SELECT c.band_no,
               c.gender,
               c.function,
               SUM(c.mice_ration + NVL(c.mice_extra, 0)) AS eaten
        FROM   Cats c
        GROUP  BY c.band_no, c.gender, c.function
    ) LOOP
        key := r.band_no || '/' || r.gender || '/' || r.function;
        cells(key) := r.eaten;

        key := r.band_no || '/' || r.gender;
        row_totals(key) := value_at(row_totals, key) + r.eaten;

        col_totals(r.function) := value_at(col_totals, r.function) + r.eaten;
        grand_total := grand_total + r.eaten;
    END LOOP;

    -- Header.
    line := RPAD('BAND NAME', 21) || RPAD('GENDER', 15);
    FOR f IN (SELECT function FROM Functions ORDER BY function) LOOP
        line := line || RPAD(f.function, 10);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(line || 'SUM');

    -- Body.
    FOR b IN (SELECT band_no, name FROM Bands ORDER BY band_no) LOOP
        FOR g IN (SELECT 'M' AS gender FROM dual
                  UNION ALL SELECT 'W' FROM dual) LOOP

            line := RPAD(b.name, 21) ||
                    RPAD(CASE g.gender WHEN 'M' THEN 'Male cat'
                                       ELSE 'Female cat' END, 15);

            FOR f IN (SELECT function FROM Functions ORDER BY function) LOOP
                key  := b.band_no || '/' || g.gender || '/' || f.function;
                line := line || RPAD(value_at(cells, key), 10);
            END LOOP;

            key  := b.band_no || '/' || g.gender;
            DBMS_OUTPUT.PUT_LINE(line || value_at(row_totals, key));
        END LOOP;
    END LOOP;

    -- Footer.
    line := RPAD('Eats in total', 36);
    FOR f IN (SELECT function FROM Functions ORDER BY function) LOOP
        line := line || RPAD(value_at(col_totals, f.function), 10);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(line || grand_total);
END;
/
