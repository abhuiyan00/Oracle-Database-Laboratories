-- =============================================================================
-- Tear down the cat-herd schema.
--
-- Run this before 02_create_tables.sql for a clean rebuild. Objects are dropped
-- child-first so that no foreign key ever blocks a DROP. The script is safe to
-- run against an empty schema: each DROP is wrapped so that "table or view does
-- not exist" (ORA-00942) and "type does not exist" (ORA-04043) are swallowed
-- while any other error is re-raised.
-- =============================================================================

SET SERVEROUTPUT ON

DECLARE
    -- Object names in dependency order: children before parents.
    TYPE name_list IS TABLE OF VARCHAR2(30);

    tables_to_drop name_list := name_list(
        'EXTRA_EXTRA_RATIONS',
        'INVALID_CHANGE_ATTEMPTS',
        'INCIDENTS',
        'CATS',
        'BANDS',
        'ENEMIES',
        'FUNCTIONS'
    );

    packages_to_drop name_list := name_list('HERD_ADMIN', 'VIRUS_STATE');

PROCEDURE drop_object(object_kind VARCHAR2, object_name VARCHAR2) IS
BEGIN
    EXECUTE IMMEDIATE 'DROP ' || object_kind || ' ' || object_name ||
                      CASE WHEN object_kind = 'TABLE' THEN ' CASCADE CONSTRAINTS' END;
    DBMS_OUTPUT.PUT_LINE('dropped ' || LOWER(object_kind) || ' ' || object_name);
EXCEPTION
    WHEN OTHERS THEN
        -- ORA-00942 table/view does not exist, ORA-04043 object does not exist.
        IF SQLCODE IN (-942, -4043) THEN
            NULL;
        ELSE
            RAISE;
        END IF;
END drop_object;

BEGIN
    FOR i IN 1 .. tables_to_drop.COUNT LOOP
        drop_object('TABLE', tables_to_drop(i));
    END LOOP;

    FOR i IN 1 .. packages_to_drop.COUNT LOOP
        drop_object('PACKAGE', packages_to_drop(i));
    END LOOP;
END;
/
