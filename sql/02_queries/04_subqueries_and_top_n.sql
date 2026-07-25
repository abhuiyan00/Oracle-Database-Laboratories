-- =============================================================================
-- Subqueries, correlated subqueries and Top-N.
--
-- The recurring trap in this file is ROWNUM. Oracle assigns ROWNUM as rows are
-- produced, which is *before* ORDER BY runs. So
--
--     SELECT ... FROM t WHERE ROWNUM = 1 ORDER BY col DESC
--
-- does not return the largest row: it returns whichever row the access path
-- happened to emit first, then sorts that single row. The fix is to force the
-- sort to complete first -- either in an inline view that ROWNUM then filters,
-- or with the row-limiting clause (FETCH FIRST, 12c and later).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 25. Cats eating at least three times as much as the hungriest NICE cat that
--     hunts the whole area or the orchard.
--
-- MAX does the work directly. Reaching for ROWNUM = 1 with an ORDER BY in the
-- same query block is the classic way to get this wrong: the aggregate needs no
-- ordering at all, and is both clearer and cheaper than any Top-N formulation.
-- -----------------------------------------------------------------------------
SELECT c.name,
       c.function,
       c.mice_ration AS "Ration of mice"
FROM   Cats c
WHERE  c.mice_ration >= 3 * (
           SELECT MAX(inner_cat.mice_ration)
           FROM   Cats  inner_cat
           JOIN   Bands b ON inner_cat.band_no = b.band_no
           WHERE  inner_cat.function = 'NICE'
             AND  b.site IN ('WHOLE AREA', 'ORCHARD')
       )
ORDER  BY c.mice_ration;

-- -----------------------------------------------------------------------------
-- 26. The functions with the lowest and the highest average appetite, bosses
--     excluded.
--
-- The aggregate is computed once in a WITH clause and referenced twice, rather
-- than the same GROUP BY being written out in both halves of the predicate.
-- -----------------------------------------------------------------------------
WITH function_averages AS (
    SELECT function,
           CEIL(AVG(mice_ration + NVL(mice_extra, 0))) AS avg_eaten
    FROM   Cats
    WHERE  function <> 'BOSS'
    GROUP  BY function
)
SELECT function, avg_eaten
FROM   function_averages
WHERE  avg_eaten = (SELECT MIN(avg_eaten) FROM function_averages)
   OR  avg_eaten = (SELECT MAX(avg_eaten) FROM function_averages)
ORDER  BY avg_eaten;

-- -----------------------------------------------------------------------------
-- 27. The six largest appetites in the herd, three ways.
-- -----------------------------------------------------------------------------

-- (a) Correlated count: keep a cat when fewer than six distinct appetites beat
--     it. Ties share a rank, so this can return more than six rows -- which is
--     the desired behaviour for "the six largest values".
SELECT nickname,
       mice_ration + NVL(mice_extra, 0) AS eats
FROM   Cats c
WHERE  (
           SELECT COUNT(DISTINCT mice_ration + NVL(mice_extra, 0))
           FROM   Cats
           WHERE  mice_ration + NVL(mice_extra, 0)
                  > c.mice_ration + NVL(c.mice_extra, 0)
       ) < 6
ORDER  BY eats DESC;

-- (b) Sort inside an inline view, then let ROWNUM slice the sorted result. This
--     is the pre-12c idiom, and the ordering must sit inside the view for it to
--     be correct.
SELECT nickname, eats
FROM (
    SELECT nickname,
           mice_ration + NVL(mice_extra, 0) AS eats
    FROM   Cats
    ORDER  BY eats DESC
)
WHERE ROWNUM <= 6;

-- (c) The row-limiting clause. WITH TIES matches (a)'s handling of equal
--     appetites; FETCH FIRST 6 ROWS ONLY would cut the list at exactly six.
SELECT nickname,
       mice_ration + NVL(mice_extra, 0) AS eats
FROM   Cats
ORDER  BY eats DESC
FETCH  FIRST 6 ROWS WITH TIES;
