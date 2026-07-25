-- =============================================================================
-- Single-table querying: predicates, string and date functions, CASE, grouping.
--
-- Every date comparison uses an ANSI DATE literal. Comparing a DATE column
-- against a bare string such as '2009-01-01' forces an implicit conversion
-- through the session's NLS_DATE_FORMAT: it works on a session set to
-- YYYY-MM-DD and raises ORA-01861 on any other.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Enemies involved in an incident during 2009, with the description.
--
-- The upper bound is written as < 2010-01-01 rather than BETWEEN ... AND
-- '2009-12-31'. BETWEEN on a DATE excludes anything after midnight on the last
-- day, so an incident timestamped later on 31 December would be dropped.
-- -----------------------------------------------------------------------------
SELECT enemy_name,
       incident_desc AS "Fault description"
FROM   Incidents
WHERE  incident_date >= DATE '2009-01-01'
  AND  incident_date <  DATE '2010-01-01';

-- -----------------------------------------------------------------------------
-- 2. Female cats that joined the herd between September 2005 and July 2007.
-- -----------------------------------------------------------------------------
SELECT name,
       function,
       in_herd_since AS "With us from"
FROM   Cats
WHERE  gender = 'W'
  AND  in_herd_since >= DATE '2005-09-01'
  AND  in_herd_since <  DATE '2007-08-01';

-- -----------------------------------------------------------------------------
-- 3. Enemies that cannot be bribed, least hostile first.
-- -----------------------------------------------------------------------------
SELECT enemy_name,
       species,
       hostility_degree
FROM   Enemies
WHERE  bribe IS NULL
ORDER  BY hostility_degree ASC;

-- -----------------------------------------------------------------------------
-- 4. One sentence per male cat, newest joiner first.
-- -----------------------------------------------------------------------------
SELECT name || ' called ' || nickname ||
       ' (fun. ' || function || ') has been catching mice in band ' ||
       band_no || ' since ' || TO_CHAR(in_herd_since, 'YYYY-MM-DD')
           AS all_about_male_cats
FROM   Cats
WHERE  gender = 'M'
ORDER  BY in_herd_since DESC, nickname ASC;

-- -----------------------------------------------------------------------------
-- 5. Mask the digraphs AL and LA inside nicknames.
--
-- The replacements are nested, so the outer REPLACE only ever sees what the
-- inner one left behind. Because the substitution characters (# and %) are not
-- letters, the second pass cannot re-match text the first pass produced.
-- -----------------------------------------------------------------------------
SELECT nickname,
       REPLACE(REPLACE(nickname, 'AL', '#%'), 'LA', '%#')
           AS "After replacing AL and LA"
FROM   Cats
WHERE  nickname LIKE '%AL%'
   OR  nickname LIKE '%LA%'
ORDER  BY nickname;

-- -----------------------------------------------------------------------------
-- 6. Veterans of more than eleven years who joined between March and September:
--    what they ate, and what a 10% cut would leave them.
-- -----------------------------------------------------------------------------
SELECT name,
       in_herd_since                        AS "In herd",
       ROUND(0.9 * mice_ration)             AS ate,
       ADD_MONTHS(in_herd_since, 6)         AS increase,
       mice_ration                          AS eat
FROM   Cats
WHERE  MONTHS_BETWEEN(SYSDATE, in_herd_since) / 12 > 11
  AND  TO_CHAR(in_herd_since, 'MM-DD') BETWEEN '03-01' AND '09-30';

-- -----------------------------------------------------------------------------
-- 7. Quarterly consumption for the well-fed cats whose base ration dwarfs their
--    bonus. NVL guards the arithmetic: mice_extra is NULL for most of the herd,
--    and NULL * 3 is NULL, which would silently drop those rows from the result.
-- -----------------------------------------------------------------------------
SELECT name,
       mice_ration * 3                AS "Mice quarterly",
       NVL(mice_extra, 0) * 3         AS "Extra quarterly"
FROM   Cats
WHERE  mice_ration > 2 * NVL(mice_extra, 0)
  AND  mice_ration > 55
ORDER  BY mice_ration DESC;

-- -----------------------------------------------------------------------------
-- 8. Annual consumption bucketed against a 660-mouse threshold.
-- -----------------------------------------------------------------------------
SELECT name,
       CASE
           WHEN (mice_ration + NVL(mice_extra, 0)) * 12 < 660 THEN 'Below 660'
           WHEN (mice_ration + NVL(mice_extra, 0)) * 12 = 660 THEN 'LIMIT'
           ELSE TO_CHAR((mice_ration + NVL(mice_extra, 0)) * 12)
       END AS "Eats annually"
FROM   Cats
ORDER  BY name;

-- -----------------------------------------------------------------------------
-- 9. Payment date: cats that joined in the first half of a month are paid on
--    the 29th, the rest on the 25th of the following month.
--
-- The CASE returns a DATE rather than a formatted string, so the result sorts
-- chronologically. Returning TO_CHAR(...) here would sort it alphabetically.
-- -----------------------------------------------------------------------------
SELECT nickname,
       in_herd_since AS "In herd",
       CASE
           WHEN EXTRACT(DAY FROM in_herd_since) <= 15 THEN DATE '2020-10-29'
           ELSE DATE '2020-11-25'
       END AS payment
FROM   Cats
ORDER  BY in_herd_since ASC;

-- -----------------------------------------------------------------------------
-- 10. Are nicknames unique? Are chiefs? (Two aggregates over the same table.)
-- -----------------------------------------------------------------------------
SELECT nickname || CASE WHEN COUNT(*) = 1 THEN ' - unique' ELSE ' - non-unique' END
           AS "Uniqueness of the nickname"
FROM   Cats
GROUP  BY nickname
ORDER  BY nickname ASC;

SELECT chief || CASE WHEN COUNT(*) = 1 THEN ' - unique' ELSE ' - non-unique' END
           AS "Uniqueness of the chief"
FROM   Cats
WHERE  chief IS NOT NULL
GROUP  BY chief
ORDER  BY chief;

-- -----------------------------------------------------------------------------
-- 11. Cats that have tangled with more than one enemy.
-- -----------------------------------------------------------------------------
SELECT nickname,
       COUNT(enemy_name) AS "Number of enemies"
FROM   Incidents
GROUP  BY nickname
HAVING COUNT(enemy_name) > 1
ORDER  BY nickname;

-- -----------------------------------------------------------------------------
-- 12. Per function, among non-boss female cats: headcount and the biggest
--     appetite, but only where the function's average appetite clears 50.
-- -----------------------------------------------------------------------------
SELECT 'Number of Cats= ' || COUNT(*) ||
       ' hunts as ' || function ||
       ' and eats max. ' || MAX(mice_ration + NVL(mice_extra, 0)) ||
       ' mice per month' AS summary
FROM   Cats
WHERE  function <> 'BOSS'
  AND  gender   <> 'M'
GROUP  BY function
HAVING AVG(mice_ration + NVL(mice_extra, 0)) > 50
ORDER  BY MAX(mice_ration + NVL(mice_extra, 0)) ASC;

-- -----------------------------------------------------------------------------
-- 13. Smallest ration in each band/gender combination.
-- -----------------------------------------------------------------------------
SELECT band_no          AS "Band no",
       gender,
       MIN(mice_ration) AS "Minimum ration"
FROM   Cats
GROUP  BY band_no, gender
ORDER  BY band_no, gender;
