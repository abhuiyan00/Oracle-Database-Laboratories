-- =============================================================================
-- Joins, anti-joins and set operators.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 17. Well-fed cats hunting the field or the whole area.
-- -----------------------------------------------------------------------------
SELECT c.nickname    AS "Hunts in the field",
       c.mice_ration AS "Ration of mice",
       b.name        AS "Band"
FROM   Cats  c
JOIN   Bands b ON c.band_no = b.band_no
WHERE  c.mice_ration > 50
  AND  b.site IN ('FIELD', 'WHOLE AREA');

-- -----------------------------------------------------------------------------
-- 18. Cats that joined before December 2008.
--
-- No join here. A self-join on the primary key would match every row to itself,
-- costing a second scan while bringing in no columns and restricting no rows --
-- a plain predicate is the whole query.
-- -----------------------------------------------------------------------------
SELECT name,
       in_herd_since
FROM   Cats
WHERE  in_herd_since < DATE '2008-12-01'
ORDER  BY in_herd_since DESC;

-- -----------------------------------------------------------------------------
-- 20. Incidents involving female cats since 2007, with band and enemy detail.
--
-- The band is reached through c.band_no = b.band_no -- the cat's own band.
-- Joining on c.chief = b.band_chief instead would read as "the band whose chief
-- happens to be this cat's chief", which coincides for most rows in this data
-- and diverges for any cat whose chief leads a band it does not belong to.
-- -----------------------------------------------------------------------------
SELECT c.name             AS "Name of female cat",
       b.name             AS "Band name",
       i.enemy_name       AS "Enemy name",
       e.hostility_degree AS "Enemy rating",
       i.incident_date    AS "Incident date"
FROM   Cats      c
JOIN   Incidents i ON c.nickname   = i.nickname
JOIN   Bands     b ON c.band_no    = b.band_no
JOIN   Enemies   e ON i.enemy_name = e.enemy_name
WHERE  i.incident_date > DATE '2007-01-01'
  AND  c.gender = 'W'
ORDER  BY c.name ASC;

-- -----------------------------------------------------------------------------
-- 21. Per band: how many cats have enemies at all, and how many have more than
--     two.
--
-- COUNT(DISTINCT c.nickname) rather than COUNT(*). A cat with three incidents
-- contributes three rows to the join, so a plain COUNT(*) would report it three
-- times and inflate every band's total by the number of fights its cats picked.
-- -----------------------------------------------------------------------------
SELECT b.name                          AS "Band name",
       COUNT(DISTINCT c.nickname)      AS "Cats with enemies",
       COUNT(DISTINCT CASE WHEN i.incident_count > 2 THEN c.nickname END)
                                       AS "Cats with >2 enemies"
FROM   Cats  c
JOIN   Bands b ON c.band_no = b.band_no
JOIN   (
           SELECT nickname, COUNT(*) AS incident_count
           FROM   Incidents
           GROUP  BY nickname
       ) i ON i.nickname = c.nickname
GROUP  BY b.name
ORDER  BY b.name;

-- -----------------------------------------------------------------------------
-- 22. Cats with more than one enemy, grouped by function.
-- -----------------------------------------------------------------------------
SELECT c.function  AS "Function",
       c.nickname  AS "Nickname of cat",
       COUNT(*)    AS "Number of enemies"
FROM   Cats      c
JOIN   Incidents i ON c.nickname = i.nickname
GROUP  BY c.function, c.nickname
HAVING COUNT(*) > 1
ORDER  BY c.function, c.nickname;

-- -----------------------------------------------------------------------------
-- 23. Annual dose against an 864-mouse benchmark, as a three-branch UNION.
--
-- The branches are disjoint by construction, so UNION ALL is used instead of
-- UNION: there are no duplicates for UNION to remove, and skipping the sort and
-- de-duplication pass is free.
-- -----------------------------------------------------------------------------
SELECT name,
       (mice_ration + mice_extra) * 12 AS "Annual dose",
       'Above 864'                     AS "Dose"
FROM   Cats
WHERE  mice_extra IS NOT NULL
  AND  mice_ration IS NOT NULL
  AND  (mice_ration + mice_extra) * 12 > 864
UNION ALL
SELECT name,
       (mice_ration + mice_extra) * 12,
       'LIMIT'
FROM   Cats
WHERE  mice_extra IS NOT NULL
  AND  mice_ration IS NOT NULL
  AND  (mice_ration + mice_extra) * 12 = 864
UNION ALL
SELECT name,
       (mice_ration + mice_extra) * 12,
       'Below 864'
FROM   Cats
WHERE  mice_extra IS NOT NULL
  AND  mice_ration IS NOT NULL
  AND  (mice_ration + mice_extra) * 12 < 864
ORDER  BY "Annual dose" DESC;

-- -----------------------------------------------------------------------------
-- 24. Bands nobody belongs to, expressed three ways.
--
-- Each is labelled for what it actually is: an outer-join anti-join, a set
-- difference, and a correlated NOT EXISTS.
-- -----------------------------------------------------------------------------

-- (a) Outer join, keeping only the rows that found no match.
SELECT b.band_no, b.name, b.site
FROM   Bands b
LEFT   JOIN Cats c ON b.band_no = c.band_no
WHERE  c.nickname IS NULL;

-- (b) Set difference.
SELECT band_no, name, site FROM Bands
MINUS
SELECT b.band_no, b.name, b.site
FROM   Bands b
WHERE  b.band_no IN (SELECT band_no FROM Cats WHERE band_no IS NOT NULL);

-- (c) Correlated NOT EXISTS. Usually the clearest statement of intent, and the
--     only one of the three that is immune to NULL band_no values.
SELECT b.band_no, b.name, b.site
FROM   Bands b
WHERE  NOT EXISTS (SELECT 1 FROM Cats c WHERE c.band_no = b.band_no);
