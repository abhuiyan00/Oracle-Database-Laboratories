-- =============================================================================
-- Triggers: row-level, statement-level, compound, and autonomous transactions.
--
-- The recurring hazard in this file is the mutating table. A row-level trigger
-- may not query or modify the table it fires on -- Oracle raises ORA-04091,
-- because the table is mid-change and any read would see an undefined state.
-- Each trigger below is built to stay clear of it, and the comments say how.
-- =============================================================================

SET SERVEROUTPUT ON

-- -----------------------------------------------------------------------------
-- 41. Force band numbers to be consecutive on insert.
--
-- A sequence, not SELECT MAX(band_no) + 1. Reading Bands from a row-level
-- trigger on Bands is the textbook mutating-table error, and MAX + 1 is also
-- wrong under concurrency: two sessions inserting at once would compute the
-- same number. A sequence is transactional and never touches the table.
-- -----------------------------------------------------------------------------
DECLARE
    already_there NUMBER;
BEGIN
    SELECT COUNT(*) INTO already_there
    FROM   user_sequences
    WHERE  sequence_name = 'BANDS_SEQ';

    IF already_there > 0 THEN
        EXECUTE IMMEDIATE 'DROP SEQUENCE bands_seq';
    END IF;
END;
/

DECLARE
    next_free NUMBER;
BEGIN
    SELECT NVL(MAX(band_no), 0) + 1 INTO next_free FROM Bands;
    EXECUTE IMMEDIATE 'CREATE SEQUENCE bands_seq START WITH ' || next_free;
END;
/

CREATE OR REPLACE TRIGGER bands_number_consecutively
    BEFORE INSERT ON Bands
    FOR EACH ROW
BEGIN
    -- Whatever the caller supplied, the band number comes from the sequence.
    :NEW.band_no := bands_seq.NEXTVAL;
END;
/

INSERT INTO Bands (band_no, name, site) VALUES (99, 'STRAYS', 'BARN');
SELECT band_no, name, site FROM Bands ORDER BY band_no;
ROLLBACK;

DROP TRIGGER bands_number_consecutively;

-- -----------------------------------------------------------------------------
-- 42. The chief taxes cats that award themselves a raise.
--
-- Rule: when a NICE cat's ration goes up, the raise is topped up to at least 10%
-- of the chief's own ration and the chief pays for it out of his ration; a raise
-- that already clears the threshold earns the chief a bonus instead.
--
-- The rule needs state that spans the whole statement -- the chief's ration read
-- once before any row changes, and the running totals accumulated across rows --
-- which a row-level trigger cannot hold on its own.
-- -----------------------------------------------------------------------------

-- (a) The three-trigger version: package variables carry the state between a
--     BEFORE STATEMENT trigger, a BEFORE EACH ROW trigger and an AFTER STATEMENT
--     trigger.
--
--     This works, but it is fragile in a way worth naming: the AFTER STATEMENT
--     trigger updates Cats.mice_ration, which is the very column its own
--     BEFORE UPDATE OF trigger watches, so it re-enters the trigger chain. The
--     guard flag below is what stops that recursion. Version (b) has no such
--     problem and is the one to prefer.
CREATE OR REPLACE PACKAGE virus_state IS
    punishment   NUMBER := 0;
    reward       NUMBER := 0;
    chief_ration Cats.mice_ration%TYPE;
    settling     BOOLEAN := FALSE;
END virus_state;
/

CREATE OR REPLACE TRIGGER virus_before_statement
    BEFORE UPDATE OF mice_ration ON Cats
BEGIN
    IF NOT virus_state.settling THEN
        SELECT mice_ration INTO virus_state.chief_ration
        FROM   Cats WHERE nickname = 'TIGER';

        virus_state.punishment := 0;
        virus_state.reward     := 0;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER virus_each_row
    BEFORE UPDATE OF mice_ration ON Cats
    FOR EACH ROW
BEGIN
    IF NOT virus_state.settling AND :NEW.function = 'NICE' THEN
        IF :NEW.mice_ration <= :OLD.mice_ration THEN
            :NEW.mice_ration := :OLD.mice_ration;

        ELSIF :NEW.mice_ration - :OLD.mice_ration
              < 0.1 * virus_state.chief_ration THEN
            :NEW.mice_ration := :NEW.mice_ration
                                + ROUND(0.1 * virus_state.chief_ration);
            :NEW.mice_extra  := NVL(:NEW.mice_extra, 0) + 5;
            virus_state.punishment := virus_state.punishment
                                      + ROUND(0.1 * virus_state.chief_ration);
        ELSE
            virus_state.reward := virus_state.reward + 5;
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER virus_after_statement
    AFTER UPDATE OF mice_ration ON Cats
DECLARE
    ration Cats.mice_ration%TYPE;
    extra  Cats.mice_extra%TYPE;
BEGIN
    IF virus_state.settling THEN
        RETURN;
    END IF;

    IF virus_state.punishment = 0 AND virus_state.reward = 0 THEN
        RETURN;
    END IF;

    SELECT mice_ration, NVL(mice_extra, 0)
    INTO   ration, extra
    FROM   Cats
    WHERE  nickname = 'TIGER';

    ration := GREATEST(ration - virus_state.punishment, 0);
    extra  := extra + virus_state.reward;

    virus_state.punishment := 0;
    virus_state.reward     := 0;

    -- Re-entry guard: this UPDATE would otherwise fire this same trigger again.
    virus_state.settling := TRUE;
    UPDATE Cats
    SET    mice_ration = ration,
           mice_extra  = extra
    WHERE  nickname = 'TIGER';
    virus_state.settling := FALSE;
END;
/

-- Exercise it. Note which column each predicate uses: NICE is a function and
-- ZOMBIES is a nickname, and filtering on the wrong one of the two matches zero
-- rows -- which looks exactly like a trigger that did nothing.
UPDATE Cats SET mice_ration = mice_ration + 22 WHERE nickname = 'ZOMBIES';
UPDATE Cats SET mice_ration = mice_ration +  1 WHERE function = 'NICE';

SELECT nickname, function, mice_ration, mice_extra
FROM   Cats
WHERE  function = 'NICE' OR nickname = 'TIGER'
ORDER  BY nickname;

ROLLBACK;

DROP TRIGGER virus_after_statement;
DROP TRIGGER virus_each_row;
DROP TRIGGER virus_before_statement;
DROP PACKAGE virus_state;

-- (b) The compound trigger: one object, four timing points, state held in the
--     trigger's own declaration section. No package, no globals leaking between
--     statements, and the state is reinitialised automatically for each
--     statement -- which is what the package version had to do by hand.
CREATE OR REPLACE TRIGGER virus_compound
    FOR UPDATE OF mice_ration ON Cats
    COMPOUND TRIGGER

    chief_ration Cats.mice_ration%TYPE;
    punishment   NUMBER := 0;
    reward       NUMBER := 0;

BEFORE STATEMENT IS
BEGIN
    SELECT mice_ration INTO chief_ration FROM Cats WHERE nickname = 'TIGER';
    punishment := 0;
    reward     := 0;
END BEFORE STATEMENT;

BEFORE EACH ROW IS
BEGIN
    IF :NEW.function = 'NICE' THEN
        IF :NEW.mice_ration <= :OLD.mice_ration THEN
            :NEW.mice_ration := :OLD.mice_ration;
        ELSIF :NEW.mice_ration - :OLD.mice_ration < 0.1 * chief_ration THEN
            :NEW.mice_ration := :NEW.mice_ration + ROUND(0.1 * chief_ration);
            :NEW.mice_extra  := NVL(:NEW.mice_extra, 0) + 5;
            punishment       := punishment + ROUND(0.1 * chief_ration);
        ELSE
            reward := reward + 5;
        END IF;
    END IF;
END BEFORE EACH ROW;

AFTER STATEMENT IS
    ration Cats.mice_ration%TYPE;
    extra  Cats.mice_extra%TYPE;
BEGIN
    IF punishment = 0 AND reward = 0 THEN
        RETURN;
    END IF;

    SELECT mice_ration, NVL(mice_extra, 0)
    INTO   ration, extra
    FROM   Cats
    WHERE  nickname = 'TIGER';

    UPDATE Cats
    SET    mice_ration = GREATEST(ration - punishment, 0),
           mice_extra  = extra + reward
    WHERE  nickname = 'TIGER';
END AFTER STATEMENT;

END virus_compound;
/

UPDATE Cats SET mice_ration = mice_ration + 1 WHERE function = 'NICE';

SELECT nickname, function, mice_ration, mice_extra
FROM   Cats
WHERE  function = 'NICE' OR nickname = 'TIGER'
ORDER  BY nickname;

ROLLBACK;

DROP TRIGGER virus_compound;

-- -----------------------------------------------------------------------------
-- 45. Log a penalty against every NICE cat whenever anyone other than the chief
--     raises a NICE cat's ration.
--
-- Two things worth noting:
--
--   * The session user comes from ORA_LOGIN_USER, which is available inside a
--     trigger. Outside one it is SYS_CONTEXT('USERENV', 'SESSION_USER').
--
--   * The insert-or-update is a single MERGE rather than a count followed by a
--     branch, which closes the race between checking and writing. Dynamic SQL
--     would buy nothing here -- the statement is a constant with one bind.
-- -----------------------------------------------------------------------------
CREATE TABLE Extra_extra_rations (
    catnickname   VARCHAR2(15)
                  CONSTRAINT extra_rations_pk PRIMARY KEY
                  CONSTRAINT extra_rations_cat_fk REFERENCES Cats(nickname),
    extra_rations NUMBER(4) DEFAULT 0
);

CREATE OR REPLACE TRIGGER penalise_unauthorised_raise
    BEFORE UPDATE OF mice_ration ON Cats
    FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    IF ORA_LOGIN_USER <> 'TIGER'
       AND :NEW.mice_ration > :OLD.mice_ration
       AND :NEW.function = 'NICE'
    THEN
        DBMS_OUTPUT.PUT_LINE('Ration of ' || :NEW.nickname ||
                             ' was raised without authority; penalty applied');

        MERGE INTO Extra_extra_rations target
        USING (SELECT nickname FROM Cats WHERE function = 'NICE') source
        ON    (target.catnickname = source.nickname)
        WHEN MATCHED THEN
            UPDATE SET target.extra_rations = target.extra_rations - 10
        WHEN NOT MATCHED THEN
            INSERT (catnickname, extra_rations) VALUES (source.nickname, -10);

        COMMIT;
    END IF;
END;
/

UPDATE Cats SET mice_ration = 30 WHERE nickname = 'LITTLE';

SELECT * FROM Extra_extra_rations ORDER BY catnickname;

ROLLBACK;

DROP TRIGGER penalise_unauthorised_raise;
DROP TABLE Extra_extra_rations;

-- -----------------------------------------------------------------------------
-- 46. Refuse any ration outside the band allowed by the cat's function, and log
--     the attempt.
--
-- Three naming decisions this trigger depends on:
--
--   * No reserved words as column names. "when" and "for" read naturally for an
--     audit table and neither can be used unquoted.
--   * The INTO targets are allowed_min and allowed_max, deliberately distinct
--     from the min_mice and max_mice columns they read. Naming them alike would
--     have PL/SQL resolve the WHERE clause against the variables, matching
--     nothing.
--   * RAISE_APPLICATION_ERROR takes -20000 to -20999. Any other code raises
--     ORA-21000 in place of the intended message.
-- -----------------------------------------------------------------------------
CREATE TABLE invalid_change_attempts (
    attempt_id     NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY
                   CONSTRAINT invalid_change_attempts_pk PRIMARY KEY,
    changed_by     VARCHAR2(30) NOT NULL,
    changed_at     DATE         NOT NULL,
    target_cat     VARCHAR2(25) NOT NULL,
    operation      VARCHAR2(25) NOT NULL
);

CREATE OR REPLACE TRIGGER enforce_ration_limits
    BEFORE INSERT OR UPDATE OF mice_ration ON Cats
    FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;

    -- Deliberately named apart from the columns they are read from.
    allowed_min Functions.min_mice%TYPE;
    allowed_max Functions.max_mice%TYPE;
    operation   VARCHAR2(25);
BEGIN
    SELECT f.min_mice, f.max_mice
    INTO   allowed_min, allowed_max
    FROM   Functions f
    WHERE  f.function = :NEW.function;

    IF :NEW.mice_ration NOT BETWEEN allowed_min AND allowed_max THEN
        operation := CASE WHEN INSERTING THEN 'INSERT' ELSE 'UPDATE' END;

        INSERT INTO invalid_change_attempts
                    (changed_by, changed_at, target_cat, operation)
        VALUES      (ORA_LOGIN_USER, SYSDATE, :NEW.nickname, operation);
        COMMIT;

        RAISE_APPLICATION_ERROR(-20010,
            'Ration ' || :NEW.mice_ration || ' for function ' || :NEW.function ||
            ' is outside the allowed range ' || allowed_min || '-' || allowed_max);
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20011,
            'Unknown function ' || :NEW.function);
END;
/

-- BALD is a THUG, allowed 70-90. 91 is one over the line.
UPDATE Cats SET mice_ration = 91 WHERE nickname = 'BALD';

-- A DIVISIVE cat is allowed 45-55, so this insert is rejected too.
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since,
                  mice_ration, mice_extra, band_no)
VALUES ('NEWCAT', 'M', 'NEWCAT', 'DIVISIVE', 'TIGER', DATE '2022-12-11',
        56, NULL, 1);

SELECT * FROM invalid_change_attempts ORDER BY attempt_id;

ROLLBACK;

DROP TRIGGER enforce_ration_limits;
DROP TABLE invalid_change_attempts;
