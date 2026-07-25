-- =============================================================================
-- Tear down the object-relational schema.
--
-- Object tables go before the types they are built on -- a type with a table
-- depending on it cannot be dropped, and FORCE would leave the table invalid
-- rather than removing the dependency. Type bodies are dropped with their types.
-- =============================================================================

SET SERVEROUTPUT ON

DECLARE
    TYPE name_list IS TABLE OF VARCHAR2(30);

    -- Children first: Accounts and IncidentsR point at Elites and CatsR.
    tables_to_drop name_list := name_list(
        'ACCOUNTS', 'INCIDENTSR', 'ELITES', 'COMMONS', 'CATSR'
    );

    -- Types in reverse dependency order.
    types_to_drop name_list := name_list(
        'INCIDENT_TYPE', 'ACCOUNT_TYPE', 'ELITE_TYPE', 'COMMON_TYPE', 'CAT_TYPE'
    );

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

    FOR i IN 1 .. types_to_drop.COUNT LOOP
        drop_object('TYPE', types_to_drop(i));
    END LOOP;
END;
/
