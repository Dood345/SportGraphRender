// script to delete all nodes
MATCH (n)
DETACH DELETE n;

// script to load all from save.csv
CREATE CONSTRAINT player_id_unique IF NOT EXISTS
FOR (p:Player)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT club_name_unique IF NOT EXISTS
FOR (c:Club)
REQUIRE c.name IS UNIQUE;

LOAD CSV WITH HEADERS FROM "https://media.githubusercontent.com/media/joopixel1/SportGraph/refs/heads/main/data/save.csv" AS row

WITH row
WHERE
  row.club IS NOT NULL AND
  row.club <> "" AND
  row.player_id IS NOT NULL AND
  row.player_id <> "" AND
  row.player_name IS NOT NULL AND
  row.player_name <> ""

WITH
  row,
  toInteger(
    CASE
      WHEN row.start CONTAINS "-" THEN split(row.start, "-")[0]
      ELSE row.start
    END) AS rs,
  toInteger(
    CASE
      WHEN row.end CONTAINS "-" THEN split(row.end, "-")[1]
      ELSE row.end
    END) AS re,
  toInteger(row.appearances) AS apps

MERGE (p:Player {id: row.player_id})
SET p.name = row.player_name

MERGE (c:Club {name: row.club})

MERGE (p)-[r:PLAYED_FOR]->(c)
SET
  r.start_raw = row.start,
  r.end_raw = row.end,
  r.apps_raw = row.appearances,
  r.start_year = rs,
  r.end_year = re,
  r.appearances = apps;

// script to view 1000 relationships
MATCH p = ()-[]->()
RETURN p
LIMIT 1000;

// script to create played_with relationship
MATCH (p1:Player)-[r1:PLAYED_FOR]->(c:Club)<-[r2:PLAYED_FOR]-(p2:Player)
WHERE
  p1.id < p2.id AND
  r1.start_year <= r2.end_year AND
  r2.start_year <= r1.end_year

WITH
  p1,
  p2,
  c,
  apoc.coll.max([r1.start_year, r2.start_year]) AS overlap_start,
  apoc.coll.min([r1.end_year, r2.end_year]) AS overlap_end,
  r1.appearances + r2.appearances AS weight

WHERE overlap_start <= overlap_end

MERGE (p1)-[pw:PLAYED_WITH]->(p2)
SET
  pw.club = c.name,
  pw.start = overlap_start,
  pw.end = overlap_end,
  pw.seasons_overlap = overlap_end - overlap_start + 1,
  pw.weight = weight;

// script to delet clubs and played for relationships
MATCH ()-[r:PLAYED_FOR]-()
DELETE r;

MATCH (c:Club)
DELETE c;

// get 3 players relationship
MATCH (a:Player)-[ab:PLAYED_WITH]-(b:Player)-[bc:PLAYED_WITH]-(c:Player)
WHERE
  a.id <> b.id AND
  b.id <> c.id AND
  a.id <> c.id AND
  a.id < c.id AND
  ab.club <> bc.club AND
  NOT ((a)-[:PLAYED_WITH]-(c))

RETURN
  a.name AS Player_A,
  ab.club AS Club_AB,
  b.name AS Player_B,
  bc.club AS Club_BC,
  c.name AS Player_C,
  (ab.weight + bc.weight) AS total_weight
ORDER BY total_weight DESC
LIMIT 1000;

// get 4 players relationship
MATCH (a:Player)-[ab:PLAYED_WITH]-(b:Player)
MATCH (b)-[bc:PLAYED_WITH]-(c:Player)
MATCH (c)-[cd:PLAYED_WITH]-(d:Player)

WHERE
  a.id <> b.id AND
  b.id <> c.id AND
  c.id <> d.id AND
  a.id <> c.id AND
  a.id <> d.id AND
  b.id <> d.id

  // Avoid mirrored duplicates (canonical ordering)
  AND
  a.id < d.id

  // Every link must be from a different club
  AND
  ab.club <> bc.club AND
  bc.club <> cd.club

  // No shortcuts: A does NOT connect to C or D or B to D
  AND
  NOT ((a)-[:PLAYED_WITH]-(c)) AND
  NOT ((a)-[:PLAYED_WITH]-(d)) AND
  NOT ((b)-[:PLAYED_WITH]-(d))

WITH a, b, c, d, ab, bc, cd, (ab.weight + bc.weight + cd.weight) AS total_weight

RETURN
  a.name AS Player_A,
  ab.club AS Club_AB,
  b.name AS Player_B,
  bc.club AS Club_BC,
  c.name AS Player_C,
  cd.club AS Club_CD,
  d.name AS Player_D,
  total_weight
ORDER BY total_weight DESC
LIMIT 1000;

// 5-player relationship chain
MATCH (a:Player)-[ab:PLAYED_WITH]-(b:Player)
MATCH (b)-[bc:PLAYED_WITH]-(c:Player)
MATCH (c)-[cd:PLAYED_WITH]-(d:Player)
MATCH (d)-[de:PLAYED_WITH]-(e:Player)

WHERE
  // all players distinct
  a.id <> b.id AND
  b.id <> c.id AND
  c.id <> d.id AND
  d.id <> e.id AND
  a.id <> c.id AND
  a.id <> d.id AND
  a.id <> e.id AND
  b.id <> d.id AND
  b.id <> e.id AND
  c.id <> e.id

  // canonical ordering to avoid A-B-C-D-E and E-D-C-B-A duplicates
  AND
  a.id < e.id

  // clubs must all be different along the chain
  AND
  ab.club <> bc.club AND
  bc.club <> cd.club AND
  cd.club <> de.club

  // no shortcut PLAYED_WITH edges:
  // A cannot reach C/D/E directly
  AND
  NOT ((a)-[:PLAYED_WITH]-(c)) AND
  NOT ((a)-[:PLAYED_WITH]-(d)) AND
  NOT ((a)-[:PLAYED_WITH]-(e))

  // B cannot reach D/E directly
  AND
  NOT ((b)-[:PLAYED_WITH]-(d)) AND
  NOT ((b)-[:PLAYED_WITH]-(e))

  // C cannot reach E directly
  AND
  NOT ((c)-[:PLAYED_WITH]-(e))

WITH
  a,
  b,
  c,
  d,
  e,
  ab,
  bc,
  cd,
  de,
  (ab.weight + bc.weight + cd.weight + de.weight) AS total_weight

RETURN
  a.name AS Player_A,
  ab.club AS Club_AB,
  b.name AS Player_B,
  bc.club AS Club_BC,
  c.name AS Player_C,
  cd.club AS Club_CD,
  d.name AS Player_D,
  de.club AS Club_DE,
  e.name AS Player_E,
  total_weight
ORDER BY total_weight DESC
LIMIT 1000;