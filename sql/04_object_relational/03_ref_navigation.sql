-- =============================================================================
-- Querying through REFs.
--
-- Three ways to follow a pointer:
--
--   DEREF(r)        returns the whole object the REF points at
--   alias.col.attr  dot navigation, only available through a table alias
--   VALUE(t)        returns the row object of an object table
--
-- Dot navigation needs the alias: "SELECT cat.name FROM Elites" is parsed as
-- table.column, not as an attribute of the REF, and fails.
-- =============================================================================

SET SERVEROUTPUT ON

-- -----------------------------------------------------------------------------
-- Every elite with a servant, both ends resolved through REFs.
-- -----------------------------------------------------------------------------
SELECT e.cat.nickname          AS "Elite",
       e.servant.cat.get_name() AS "Servant"
FROM   Elites e
WHERE  e.servant IS NOT NULL
ORDER  BY e.id_elite;

-- The same result with DEREF, for comparison.
SELECT DEREF(e.cat).nickname                AS "Elite",
       DEREF(DEREF(e.servant).cat).name     AS "Servant"
FROM   Elites e
WHERE  e.servant IS NOT NULL
ORDER  BY e.id_elite;

-- -----------------------------------------------------------------------------
-- Elites holding an open account.
--
-- An account is open when it has no deletion date -- one IS NULL test. Adding
-- "OR creation_date > deletion_date" would be dead weight: the CHECK constraint
-- on Accounts already makes that branch unsatisfiable.
-- -----------------------------------------------------------------------------
SELECT e.cat.get_name()  AS "Owner",
       a.creation_date   AS "Opened"
FROM   Elites   e
JOIN   Accounts a ON a.owner = REF(e)
WHERE  a.deletion_date IS NULL
ORDER  BY a.creation_date;

-- -----------------------------------------------------------------------------
-- Cats that serve an elite, with what they eat.
--
-- get_total_eats() is a member function of cat_type, so the NVL arithmetic lives
-- with the type rather than being repeated at every call site.
-- -----------------------------------------------------------------------------
SELECT c.cat.name              AS "Name",
       c.cat.function          AS "Function",
       c.cat.get_total_eats()  AS "Eats",
       c.cat.get_in_herd_since() AS "In herd since"
FROM   Commons c
WHERE  c.cat.nickname IN (SELECT e.servant.cat.nickname
                          FROM   Elites e
                          WHERE  e.servant IS NOT NULL)
ORDER  BY c.cat.name;

-- -----------------------------------------------------------------------------
-- How many open accounts each elite holds.
-- -----------------------------------------------------------------------------
SELECT a.owner.cat.nickname AS "Owner",
       COUNT(*)             AS "Open accounts"
FROM   Accounts a
WHERE  a.deletion_date IS NULL
GROUP  BY a.owner.cat.nickname
ORDER  BY COUNT(*) DESC, "Owner";

-- -----------------------------------------------------------------------------
-- The chain of command, walked through the REF column instead of a value join.
-- CONNECT BY works over REFs once they are resolved to a comparable attribute.
-- -----------------------------------------------------------------------------
SELECT LEVEL AS depth,
       LPAD(' ', (LEVEL - 1) * 3) || c.nickname AS "Chain of command",
       c.function
FROM   CatsR c
CONNECT BY PRIOR c.nickname = c.chief.nickname
START WITH c.chief IS NULL;

-- -----------------------------------------------------------------------------
-- Incidents rendered by the type's own formatting method.
-- -----------------------------------------------------------------------------
SELECT i.victim.nickname AS "Victim",
       i.get_info()      AS "Incident"
FROM   IncidentsR i
ORDER  BY i.incident_date;

-- -----------------------------------------------------------------------------
-- A dangling REF: delete the row an account's owner points at, and the pointer
-- survives while its target does not. IS DANGLING is the only reliable test.
-- -----------------------------------------------------------------------------
SELECT a.action_id
FROM   Accounts a
WHERE  a.owner IS DANGLING;
