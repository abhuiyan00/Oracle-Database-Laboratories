-- =============================================================================
-- Hierarchical querying with CONNECT BY.
--
-- The herd's chain of command lives in a single self-referencing column:
-- Cats.chief points at Cats.nickname, TIGER sits at the root with a NULL chief.
--
-- Direction matters and is easy to get backwards:
--
--   CONNECT BY PRIOR nickname = chief   walks DOWN  (root -> subordinates)
--   CONNECT BY PRIOR chief = nickname   walks UP    (leaf -> chain of chiefs)
--
-- LEVEL is 1 at whatever START WITH selects, not at the top of the tree.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 14. Everyone at or below a THUG, male cats only.
--
-- LEVEL is a pseudocolumn, not a column name, so it is aliased rather than
-- selected bare: an unaliased pseudocolumn parses, but produces a column that
-- downstream tools cannot reference by name.
-- -----------------------------------------------------------------------------
SELECT LEVEL AS hierarchy_level,
       nickname,
       function,
       band_no
FROM   Cats
WHERE  gender = 'M'
CONNECT BY PRIOR nickname = chief
START WITH function = 'THUG'
ORDER  BY band_no, hierarchy_level;

-- -----------------------------------------------------------------------------
-- 15. The chain of command drawn as an indented tree, restricted to cats that
--     draw a bonus ration.
--
-- The WHERE clause is applied after the tree is walked, so pruning a cat here
-- does not prune its subordinates -- which is exactly what is wanted: the shape
-- of the hierarchy is preserved and only the display is filtered.
-- -----------------------------------------------------------------------------
SELECT LPAD(' ', (LEVEL - 1) * 4) || LEVEL - 1     AS "Hierarchy",
       NVL(chief, 'Master yourself')               AS "Nickname of the chief",
       function                                    AS "Function"
FROM   Cats
WHERE  mice_extra IS NOT NULL
CONNECT BY PRIOR nickname = chief
START WITH chief IS NULL;

-- -----------------------------------------------------------------------------
-- 16. Root-to-leaf paths for long-serving male cats on a flat ration.
--
-- Written as a DATE literal, which needs no format mask -- and so cannot be
-- broken by one. TO_DATE with a hand-written mask is a common source of
-- ORA-01861 in scripts that move between sessions.
-- -----------------------------------------------------------------------------
SELECT LPAD(' ', (LEVEL - 1) * 4) || SYS_CONNECT_BY_PATH(nickname, ' / ')
           AS "Path of chiefs"
FROM   Cats
WHERE  mice_extra IS NULL
  AND  gender = 'M'
  AND  MONTHS_BETWEEN(DATE '2020-04-06', in_herd_since) / 12 >= 11
CONNECT BY PRIOR nickname = chief
START WITH chief IS NULL
ORDER  BY nickname, LEVEL;

-- -----------------------------------------------------------------------------
-- 19. The chain of chiefs above every rank-and-file cat, three ways.
--
-- (a) self-joins, (b) CONNECT BY + PIVOT, (c) CONNECT BY + a path string.
-- Same answer, three different tools -- the point of the exercise.
-- -----------------------------------------------------------------------------

-- (a) One OUTER JOIN per level of hierarchy. Explicit, but it hard-codes the
--     depth: a fourth tier of chiefs would need another join.
SELECT c1.name,
       c1.function,
       c2.name AS "Chief 1",
       c3.name AS "Chief 2",
       c4.name AS "Chief 3"
FROM        Cats c1
LEFT JOIN   Cats c2 ON c1.chief = c2.nickname
LEFT JOIN   Cats c3 ON c2.chief = c3.nickname
LEFT JOIN   Cats c4 ON c3.chief = c4.nickname
WHERE  c1.function IN ('CAT', 'NICE')
ORDER  BY c1.name;

-- (b) Walk up the tree, then PIVOT the levels into columns. Adapts to any depth
--     by adding another value to the IN list.
SELECT *
FROM (
    SELECT CONNECT_BY_ROOT name AS "Name",
           name,
           LEVEL              AS lvl
    FROM   Cats
    CONNECT BY PRIOR chief = nickname
    START WITH function IN ('CAT', 'NICE')
)
PIVOT (
    MIN(name) FOR lvl IN (2 AS "Chief 1", 3 AS "Chief 2", 4 AS "Chief 3")
)
ORDER BY "Name";

-- (c) The whole chain as a single delimited string.
SELECT name,
       function,
       SYS_CONNECT_BY_PATH(name, ' | ') AS "Chain of chiefs"
FROM   Cats
WHERE  function IN ('CAT', 'NICE')
CONNECT BY PRIOR nickname = chief
START WITH chief IS NULL;
