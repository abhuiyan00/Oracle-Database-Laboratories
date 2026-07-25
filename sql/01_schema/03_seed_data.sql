-- =============================================================================
-- Seed the cat-herd schema.
--
-- Insert order is forced by the foreign keys and is not arbitrary:
--
--   1. FUNCTIONS and ENEMIES have no outbound keys, so they go first.
--   2. BANDS goes next, but with band_chief left NULL -- the cats it would
--      point at do not exist yet.
--   3. CATS follows. Rows are ordered so that every chief is already present
--      when the cat reporting to it is inserted, and every band_no already
--      exists in BANDS.
--   4. BANDS.band_chief is filled in by UPDATE, closing the circular key.
--   5. INCIDENTS goes last; it depends on both CATS and ENEMIES.
--
-- Dates are written as ANSI DATE literals rather than bare strings so the script
-- does not depend on the session's NLS_DATE_FORMAT.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Reference data
-- -----------------------------------------------------------------------------
INSERT INTO Functions (function, min_mice, max_mice) VALUES ('BOSS',     90, 110);
INSERT INTO Functions (function, min_mice, max_mice) VALUES ('THUG',     70,  90);
INSERT INTO Functions (function, min_mice, max_mice) VALUES ('CATCHING', 60,  70);
INSERT INTO Functions (function, min_mice, max_mice) VALUES ('CATCHER',  50,  60);
INSERT INTO Functions (function, min_mice, max_mice) VALUES ('CAT',      40,  50);
INSERT INTO Functions (function, min_mice, max_mice) VALUES ('NICE',     20,  30);
INSERT INTO Functions (function, min_mice, max_mice) VALUES ('DIVISIVE', 45,  55);
INSERT INTO Functions (function, min_mice, max_mice) VALUES ('HONORARY',  6,  25);

INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('KAZIO',         10, 'MAN',     'BOTTLE');
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('STUPID SOPHIA',  1, 'MAN',     'BEAD');
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('UNRULY DYZIO',   7, 'MAN',     'CHEWING GUM');
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('DUN',            4, 'DOG',     'BON');
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('WILD BILL',     10, 'DOG',     NULL);
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('REKS',           2, 'DOG',     'BONE');
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('BETHOVEN',       1, 'DOG',     'PEDIGRIPALL');
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('SLYBOOTS',       5, 'FOX',     'CHICKEN');
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('SLIM',           1, 'PINE',    NULL);
INSERT INTO Enemies (enemy_name, hostility_degree, species, bribe) VALUES ('BASIL',          3, 'ROOSTER', 'HEN TO THE HERD');

-- -----------------------------------------------------------------------------
-- 2. Bands, chiefs deliberately left NULL for now
-- -----------------------------------------------------------------------------
INSERT INTO Bands (band_no, name, site, band_chief) VALUES (1, 'SUPERIORS',     'WHOLE AREA', NULL);
INSERT INTO Bands (band_no, name, site, band_chief) VALUES (2, 'BLACK KNIGHTS', 'FIELD',      NULL);
INSERT INTO Bands (band_no, name, site, band_chief) VALUES (3, 'WHITE HUNTERS', 'ORCHARD',    NULL);
INSERT INTO Bands (band_no, name, site, band_chief) VALUES (4, 'PINTO HUNTERS', 'HILLOCK',    NULL);
-- Band 5 is left without members on purpose; several exercises ask for bands
-- that no cat belongs to.
INSERT INTO Bands (band_no, name, site, band_chief) VALUES (5, 'ROCKERS',       'FARM',       NULL);

-- -----------------------------------------------------------------------------
-- 3. Cats, ordered so every chief already exists
-- -----------------------------------------------------------------------------
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('MRUCZEK', 'M', 'TIGER',   'BOSS',     NULL,      DATE '2002-01-01', 103,   33, 1);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('BOLEK',   'M', 'BALD',    'THUG',     'TIGER',   DATE '2006-08-15',  72,   21, 2);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('JACEK',   'M', 'CAKE',    'CATCHING', 'BALD',    DATE '2008-12-01',  67, NULL, 2);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('BARI',    'M', 'TUBE',    'CATCHER',  'BALD',    DATE '2009-09-01',  56, NULL, 2);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('MICKA',   'W', 'LOLA',    'NICE',     'TIGER',   DATE '2009-10-14',  25,   47, 1);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('KOREK',   'M', 'ZOMBIES', 'THUG',     'TIGER',   DATE '2004-03-16',  75,   13, 3);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('PUNIA',   'W', 'HEN',     'CATCHING', 'ZOMBIES', DATE '2008-01-01',  61, NULL, 3);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('LUCEK',   'M', 'ZERO',    'CAT',      'HEN',     DATE '2010-03-01',  43, NULL, 3);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('SONIA',   'W', 'FLUFFY',  'NICE',     'ZOMBIES', DATE '2010-11-18',  20,   35, 3);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('PUCEK',   'M', 'REEF',    'CATCHING', 'TIGER',   DATE '2006-10-15',  65, NULL, 4);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('LATKA',   'W', 'EAR',     'CAT',      'REEF',    DATE '2011-01-01',  40, NULL, 4);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('DUDEK',   'M', 'SMALL',   'CAT',      'REEF',    DATE '2011-05-15',  40, NULL, 4);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('CHYTRY',  'M', 'BOLEK',   'DIVISIVE', 'TIGER',   DATE '2002-05-05',  50, NULL, 1);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('ZUZIA',   'W', 'FAST',    'CATCHING', 'BALD',    DATE '2006-07-21',  65, NULL, 2);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('RUDA',    'W', 'LITTLE',  'NICE',     'TIGER',   DATE '2006-09-17',  22,   42, 1);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('BELA',    'W', 'MISS',    'NICE',     'BALD',    DATE '2008-02-01',  24,   28, 2);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('KSAWERY', 'M', 'MAN',     'CATCHER',  'REEF',    DATE '2008-07-12',  51, NULL, 4);
INSERT INTO Cats (name, gender, nickname, function, chief, in_herd_since, mice_ration, mice_extra, band_no)
VALUES ('MELA',    'W', 'LADY',    'CATCHER',  'REEF',    DATE '2008-11-01',  51, NULL, 4);

-- -----------------------------------------------------------------------------
-- 4. Close the circular key now that the cats exist
-- -----------------------------------------------------------------------------
UPDATE Bands SET band_chief = 'TIGER'   WHERE band_no = 1;
UPDATE Bands SET band_chief = 'BALD'    WHERE band_no = 2;
UPDATE Bands SET band_chief = 'ZOMBIES' WHERE band_no = 3;
UPDATE Bands SET band_chief = 'REEF'    WHERE band_no = 4;

-- -----------------------------------------------------------------------------
-- 5. Incidents
-- -----------------------------------------------------------------------------
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('TIGER',   'KAZIO',         DATE '2004-10-13', 'TRIED TO STICK HIM ON A FORK');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('ZOMBIES', 'UNRULY DYZIO',  DATE '2005-03-07', 'POKED AN EYE WITH A CATAPULT');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('BOLEK',   'KAZIO',         DATE '2005-03-29', 'SET THE DOG ON HIM');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('FAST',    'STUPID SOPHIA', DATE '2006-09-12', 'USED THE CAT AS A CLOTH');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('LITTLE',  'SLYBOOTS',      DATE '2007-03-07', 'PROPOSED HIMSELF AS A HUSBAND');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('TIGER',   'WILD BILL',     DATE '2007-06-12', 'TRIED TO KILL HIM');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('BOLEK',   'WILD BILL',     DATE '2007-11-10', 'BIT HIS EAR');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('MISS',    'WILD BILL',     DATE '2008-12-12', 'SNARLED AT HER');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('MISS',    'KAZIO',         DATE '2009-01-07', 'GRABBED HER TAIL AND SPUN HER');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('LADY',    'KAZIO',         DATE '2009-02-07', 'WANTED TO SKIN HER');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('MAN',     'REKS',          DATE '2009-04-14', 'BARKED EXTREMELY RUDELY');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('BALD',    'BETHOVEN',      DATE '2009-05-11', 'DID NOT SHARE THE PORRIDGE');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('TUBE',    'WILD BILL',     DATE '2009-09-03', 'TOOK HIM BY THE TAIL');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('CAKE',    'BASIL',         DATE '2010-07-12', 'STOPPED HIM HUNTING THE CHICKEN');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('FLUFFY',  'SLIM',          DATE '2010-11-19', 'THREW CONES AT HER');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('HEN',     'DUN',           DATE '2010-12-14', 'CHASED HER');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('SMALL',   'SLYBOOTS',      DATE '2011-07-13', 'TOOK THE STOLEN EGGS');
INSERT INTO Incidents (nickname, enemy_name, incident_date, incident_desc)
VALUES ('EAR',     'UNRULY DYZIO',  DATE '2011-07-14', 'THREW STONES');

COMMIT;

-- -----------------------------------------------------------------------------
-- Row counts, as a smoke test that everything landed.
-- -----------------------------------------------------------------------------
SELECT 'FUNCTIONS' AS table_name, COUNT(*) AS rows_loaded FROM Functions
UNION ALL SELECT 'ENEMIES',   COUNT(*) FROM Enemies
UNION ALL SELECT 'BANDS',     COUNT(*) FROM Bands
UNION ALL SELECT 'CATS',      COUNT(*) FROM Cats
UNION ALL SELECT 'INCIDENTS', COUNT(*) FROM Incidents;
