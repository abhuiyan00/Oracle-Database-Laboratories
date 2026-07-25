-- =============================================================================
-- Seed the object tables.
--
-- Every REF is produced by a scalar subquery over the already-inserted rows,
-- so ordering matters exactly as it did in the relational schema: a cat's chief
-- must exist before the cat that points at it.
--
-- These are single-row INSERT ... VALUES statements rather than INSERT ALL:
-- Oracle does not permit a subquery in the values clause of a multitable
-- insert, and every REF here comes from one. Single-row inserts have allowed
-- scalar subqueries since 9i.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Cats. TIGER first: it is the only cat with no chief.
-- -----------------------------------------------------------------------------
INSERT INTO CatsR VALUES ('MRUCZEK', 'M', 'TIGER', 'BOSS', NULL, DATE '2002-01-01', 103, 33, 1);

INSERT INTO CatsR VALUES ('BOLEK', 'M', 'BALD', 'THUG',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'), DATE '2006-08-15', 72, 21, 2);
INSERT INTO CatsR VALUES ('MICKA', 'W', 'LOLA', 'NICE',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'), DATE '2009-10-14', 25, 47, 1);
INSERT INTO CatsR VALUES ('KOREK', 'M', 'ZOMBIES', 'THUG',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'), DATE '2004-03-16', 75, 13, 3);
INSERT INTO CatsR VALUES ('RUDA', 'W', 'LITTLE', 'NICE',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'), DATE '2006-09-17', 22, 42, 1);
INSERT INTO CatsR VALUES ('PUCEK', 'M', 'REEF', 'CATCHING',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'), DATE '2006-10-15', 65, NULL, 4);
INSERT INTO CatsR VALUES ('CHYTRY', 'M', 'BOLEK', 'DIVISIVE',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'), DATE '2002-05-05', 50, NULL, 1);

INSERT INTO CatsR VALUES ('JACEK', 'M', 'CAKE', 'CATCHING',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'BALD'), DATE '2008-12-01', 67, NULL, 2);
INSERT INTO CatsR VALUES ('BARI', 'M', 'TUBE', 'CATCHER',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'BALD'), DATE '2009-09-01', 56, NULL, 2);
INSERT INTO CatsR VALUES ('ZUZIA', 'W', 'FAST', 'CATCHING',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'BALD'), DATE '2006-07-21', 65, NULL, 2);
INSERT INTO CatsR VALUES ('BELA', 'W', 'MISS', 'NICE',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'BALD'), DATE '2008-02-01', 24, 28, 2);

INSERT INTO CatsR VALUES ('SONIA', 'W', 'FLUFFY', 'NICE',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'ZOMBIES'), DATE '2010-11-18', 20, 35, 3);
INSERT INTO CatsR VALUES ('PUNIA', 'W', 'HEN', 'CATCHING',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'ZOMBIES'), DATE '2008-01-01', 61, NULL, 3);

INSERT INTO CatsR VALUES ('LATKA', 'W', 'EAR', 'CAT',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'REEF'), DATE '2011-01-01', 40, NULL, 4);
INSERT INTO CatsR VALUES ('DUDEK', 'M', 'SMALL', 'CAT',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'REEF'), DATE '2011-05-15', 40, NULL, 4);
INSERT INTO CatsR VALUES ('KSAWERY', 'M', 'MAN', 'CATCHER',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'REEF'), DATE '2008-07-12', 51, NULL, 4);
INSERT INTO CatsR VALUES ('MELA', 'W', 'LADY', 'CATCHER',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'REEF'), DATE '2008-11-01', 51, NULL, 4);

-- ZERO reports to HEN, so it has to wait for HEN.
INSERT INTO CatsR VALUES ('LUCEK', 'M', 'ZERO', 'CAT',
    (SELECT REF(k) FROM CatsR k WHERE nickname = 'HEN'), DATE '2010-03-01', 43, NULL, 3);

-- -----------------------------------------------------------------------------
-- Commoners -- the cats available to serve an elite.
-- -----------------------------------------------------------------------------
INSERT INTO Commons VALUES (1, (SELECT REF(k) FROM CatsR k WHERE nickname = 'CAKE'));
INSERT INTO Commons VALUES (2, (SELECT REF(k) FROM CatsR k WHERE nickname = 'TUBE'));
INSERT INTO Commons VALUES (3, (SELECT REF(k) FROM CatsR k WHERE nickname = 'LOLA'));
INSERT INTO Commons VALUES (4, (SELECT REF(k) FROM CatsR k WHERE nickname = 'ZERO'));
INSERT INTO Commons VALUES (5, (SELECT REF(k) FROM CatsR k WHERE nickname = 'FLUFFY'));
INSERT INTO Commons VALUES (6, (SELECT REF(k) FROM CatsR k WHERE nickname = 'EAR'));
INSERT INTO Commons VALUES (7, (SELECT REF(k) FROM CatsR k WHERE nickname = 'SMALL'));
INSERT INTO Commons VALUES (8, (SELECT REF(k) FROM CatsR k WHERE nickname = 'MISS'));
INSERT INTO Commons VALUES (9, (SELECT REF(k) FROM CatsR k WHERE nickname = 'MAN'));

-- -----------------------------------------------------------------------------
-- Elites. Each servant is assigned to at most one elite.
-- -----------------------------------------------------------------------------
INSERT INTO Elites VALUES (1, (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'),
                              (SELECT REF(p) FROM Commons p WHERE common_id = 1));
INSERT INTO Elites VALUES (2, (SELECT REF(k) FROM CatsR k WHERE nickname = 'BOLEK'), NULL);
INSERT INTO Elites VALUES (3, (SELECT REF(k) FROM CatsR k WHERE nickname = 'ZOMBIES'),
                              (SELECT REF(p) FROM Commons p WHERE common_id = 3));
INSERT INTO Elites VALUES (4, (SELECT REF(k) FROM CatsR k WHERE nickname = 'BALD'),
                              (SELECT REF(p) FROM Commons p WHERE common_id = 4));
INSERT INTO Elites VALUES (5, (SELECT REF(k) FROM CatsR k WHERE nickname = 'FAST'),
                              (SELECT REF(p) FROM Commons p WHERE common_id = 2));
INSERT INTO Elites VALUES (6, (SELECT REF(k) FROM CatsR k WHERE nickname = 'SMALL'), NULL);
INSERT INTO Elites VALUES (7, (SELECT REF(k) FROM CatsR k WHERE nickname = 'REEF'),
                              (SELECT REF(p) FROM Commons p WHERE common_id = 7));
INSERT INTO Elites VALUES (8, (SELECT REF(k) FROM CatsR k WHERE nickname = 'HEN'),
                              (SELECT REF(p) FROM Commons p WHERE common_id = 5));
INSERT INTO Elites VALUES (9, (SELECT REF(k) FROM CatsR k WHERE nickname = 'LADY'), NULL);

-- -----------------------------------------------------------------------------
-- Incidents.
-- -----------------------------------------------------------------------------
INSERT INTO IncidentsR VALUES (1,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'),
    'KAZIO',        DATE '2004-10-13', 'TRIED TO STICK HIM ON A FORK');
INSERT INTO IncidentsR VALUES (2,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'BOLEK'),
    'KAZIO',        DATE '2005-03-29', 'SET THE DOG ON HIM');
INSERT INTO IncidentsR VALUES (3,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'SMALL'),
    'SLYBOOTS',     DATE '2007-03-07', 'PROPOSED HIMSELF AS A HUSBAND');
INSERT INTO IncidentsR VALUES (4,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'TIGER'),
    'WILD BILL',    DATE '2007-06-12', 'TRIED TO KILL HIM');
INSERT INTO IncidentsR VALUES (5,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'BOLEK'),
    'WILD BILL',    DATE '2007-11-10', 'BIT HIS EAR');
INSERT INTO IncidentsR VALUES (6,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'MISS'),
    'WILD BILL',    DATE '2008-12-12', 'SNARLED AT HER');
INSERT INTO IncidentsR VALUES (7,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'MISS'),
    'KAZIO',        DATE '2009-01-07', 'GRABBED HER TAIL AND SPUN HER');
INSERT INTO IncidentsR VALUES (8,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'LADY'),
    'KAZIO',        DATE '2009-02-07', 'WANTED TO SKIN HER');
INSERT INTO IncidentsR VALUES (9,  (SELECT REF(k) FROM CatsR k WHERE nickname = 'MAN'),
    'REKS',         DATE '2009-04-14', 'BARKED EXTREMELY RUDELY');
INSERT INTO IncidentsR VALUES (10, (SELECT REF(k) FROM CatsR k WHERE nickname = 'BALD'),
    'BETHOVEN',     DATE '2009-05-11', 'DID NOT SHARE THE PORRIDGE');
INSERT INTO IncidentsR VALUES (11, (SELECT REF(k) FROM CatsR k WHERE nickname = 'TUBE'),
    'WILD BILL',    DATE '2009-09-03', 'TOOK HIM BY THE TAIL');
INSERT INTO IncidentsR VALUES (12, (SELECT REF(k) FROM CatsR k WHERE nickname = 'CAKE'),
    'BASIL',        DATE '2010-07-12', 'STOPPED HIM HUNTING THE CHICKEN');
INSERT INTO IncidentsR VALUES (13, (SELECT REF(k) FROM CatsR k WHERE nickname = 'FLUFFY'),
    'SLIM',         DATE '2010-11-19', 'THREW CONES AT HER');
INSERT INTO IncidentsR VALUES (14, (SELECT REF(k) FROM CatsR k WHERE nickname = 'HEN'),
    'DUN',          DATE '2010-12-14', 'CHASED HER');
INSERT INTO IncidentsR VALUES (15, (SELECT REF(k) FROM CatsR k WHERE nickname = 'SMALL'),
    'SLYBOOTS',     DATE '2011-07-13', 'TOOK THE STOLEN EGGS');
INSERT INTO IncidentsR VALUES (16, (SELECT REF(k) FROM CatsR k WHERE nickname = 'EAR'),
    'UNRULY DYZIO', DATE '2011-07-14', 'THREW STONES');

-- -----------------------------------------------------------------------------
-- Accounts. Accounts 4 and 9 are closed; the rest are still open.
-- -----------------------------------------------------------------------------
INSERT INTO Accounts VALUES (1,  (SELECT REF(e) FROM Elites e WHERE id_elite = 1), DATE '2011-01-10', NULL);
INSERT INTO Accounts VALUES (2,  (SELECT REF(e) FROM Elites e WHERE id_elite = 2), DATE '2011-02-14', NULL);
INSERT INTO Accounts VALUES (3,  (SELECT REF(e) FROM Elites e WHERE id_elite = 3), DATE '2011-03-01', NULL);
INSERT INTO Accounts VALUES (4,  (SELECT REF(e) FROM Elites e WHERE id_elite = 8), DATE '2011-03-15', DATE '2011-09-30');
INSERT INTO Accounts VALUES (5,  (SELECT REF(e) FROM Elites e WHERE id_elite = 8), DATE '2011-04-02', NULL);
INSERT INTO Accounts VALUES (6,  (SELECT REF(e) FROM Elites e WHERE id_elite = 1), DATE '2011-05-19', NULL);
INSERT INTO Accounts VALUES (7,  (SELECT REF(e) FROM Elites e WHERE id_elite = 7), DATE '2011-06-08', NULL);
INSERT INTO Accounts VALUES (8,  (SELECT REF(e) FROM Elites e WHERE id_elite = 1), DATE '2011-07-21', NULL);
INSERT INTO Accounts VALUES (9,  (SELECT REF(e) FROM Elites e WHERE id_elite = 1), DATE '2011-08-03', DATE '2012-01-15');
INSERT INTO Accounts VALUES (10, (SELECT REF(e) FROM Elites e WHERE id_elite = 4), DATE '2011-09-11', NULL);

COMMIT;

SELECT 'CatsR'      AS table_name, COUNT(*) AS rows_loaded FROM CatsR
UNION ALL SELECT 'Commons',    COUNT(*) FROM Commons
UNION ALL SELECT 'Elites',     COUNT(*) FROM Elites
UNION ALL SELECT 'IncidentsR', COUNT(*) FROM IncidentsR
UNION ALL SELECT 'Accounts',   COUNT(*) FROM Accounts;
