// -----------------------------
// 1. Delete EVERYTHING (reset DB)
// -----------------------------
MATCH (n)
DETACH DELETE n;

// -----------------------------
// 2. Create Constraints
// -----------------------------
CREATE CONSTRAINT player_id_unique IF NOT EXISTS
FOR (p:Player)
REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT club_name_unique IF NOT EXISTS
FOR (c:Club)
REQUIRE c.name IS UNIQUE;

// -----------------------------
// 3. Load save.csv Into Graph
// -----------------------------
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

// -----------------------------
// 4. View 1000 Relationships
// -----------------------------
MATCH p = ()-[]->()
RETURN p
LIMIT 1000;

// -----------------------------
// 5. Create PLAYED_WITH Relationships
// -----------------------------
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

// -----------------------------
// 6. Delete Clubs + PLAYED_FOR Only
// -----------------------------
MATCH ()-[r:PLAYED_FOR]-()
DELETE r;

MATCH (c:Club)
DELETE c;

// -----------------------------
// 7. 1-Relationship Chain (A–B)
// -----------------------------
MATCH (a:Player)
CALL
  apoc.path.expandConfig(
    a,
    {
      relationshipFilter: "PLAYED_WITH>",
      minLevel: 1,
      maxLevel: 1,
      uniqueness: "NODE_GLOBAL",
      bfs: true,
      filterStartNode: true
    }
  )
  YIELD path

WITH path, nodes(path) AS nds, relationships(path) AS rels
WHERE size(rels) = 1

WITH nds[0] AS A, nds[1] AS B, rels[0] AS ab

// Canonical ordering A.id < B.id (avoids A–B and B–A duplicates)
WHERE A.id < B.id

WITH A, B, ab, ab.weight AS total_weight

RETURN A.name AS Player_A, ab.club AS Club_AB, B.name AS Player_B, total_weight
ORDER BY total_weight * rand() DESC
LIMIT 1000;

// -----------------------------
// 8. 2-Relationship Chain (A–B–C)
// -----------------------------
MATCH (a:Player)
CALL
  apoc.path.expandConfig(
    a,
    {
      relationshipFilter: "PLAYED_WITH>",
      minLevel: 2,
      maxLevel: 2,
      uniqueness: "NODE_GLOBAL",
      bfs: true,
      filterStartNode: true
    }
  )
  YIELD path

WITH path, nodes(path) AS nds, relationships(path) AS rels
WHERE size(rels) = 2 AND rels[0].club <> rels[1].club

WITH nds[0] AS A, nds[1] AS B, nds[2] AS C, rels[0] AS ab, rels[1] AS bc

WHERE A.id < C.id AND NOT (A)-[:PLAYED_WITH]-(C)

WITH A, B, C, ab, bc, (ab.weight + bc.weight) AS total_weight

RETURN
  A.name AS Player_A,
  ab.club AS Club_AB,
  B.name AS Player_B,
  bc.club AS Club_BC,
  C.name AS Player_C,
  total_weight
ORDER BY total_weight * rand() DESC
LIMIT 1000;

// -----------------------------
// 9. 3-Relationship Chain (A–B–C–D)
// -----------------------------
MATCH (a:Player)
CALL
  apoc.path.expandConfig(
    a,
    {
      relationshipFilter: "PLAYED_WITH>",
      minLevel: 3,
      maxLevel: 3,
      uniqueness: "NODE_GLOBAL",
      bfs: true,
      filterStartNode: true
    }
  )
  YIELD path

WITH path, nodes(path) AS nds, relationships(path) AS rels
WHERE
  size(rels) = 3 AND
  rels[0].club <> rels[1].club AND
  rels[1].club <> rels[2].club

WITH
  nds[0] AS A,
  nds[1] AS B,
  nds[2] AS C,
  nds[3] AS D,
  rels[0] AS ab,
  rels[1] AS bc,
  rels[2] AS cd

WHERE
  A.id < D.id AND
  NOT (A)-[:PLAYED_WITH]-(C) AND
  NOT (A)-[:PLAYED_WITH]-(D) AND
  NOT (B)-[:PLAYED_WITH]-(D)

WITH A, B, C, D, ab, bc, cd, (ab.weight + bc.weight + cd.weight) AS total_weight

RETURN
  A.name AS Player_A,
  ab.club AS Club_AB,
  B.name AS Player_B,
  bc.club AS Club_BC,
  C.name AS Player_C,
  cd.club AS Club_CD,
  D.name AS Player_D,
  total_weight
ORDER BY total_weight * rand() DESC
LIMIT 1000;

// -----------------------------
// 10. 4-Relationship Chain (A–B–C–D–E)
// -----------------------------
MATCH (a:Player)
CALL
  apoc.path.expandConfig(
    a,
    {
      relationshipFilter: "PLAYED_WITH>",
      minLevel: 4,
      maxLevel: 4,
      uniqueness: "NODE_GLOBAL",
      bfs: true,
      filterStartNode: true
    }
  )
  YIELD path

WITH path, nodes(path) AS nds, relationships(path) AS rels
WHERE
  size(rels) = 4 AND
  rels[0].club <> rels[1].club AND
  rels[1].club <> rels[2].club AND
  rels[2].club <> rels[3].club

WITH
  nds[0] AS A,
  nds[1] AS B,
  nds[2] AS C,
  nds[3] AS D,
  nds[4] AS E,
  rels[0] AS ab,
  rels[1] AS bc,
  rels[2] AS cd,
  rels[3] AS de

WHERE
  A.id < E.id AND
  NOT (A)-[:PLAYED_WITH]-(C) AND
  NOT (A)-[:PLAYED_WITH]-(D) AND
  NOT (A)-[:PLAYED_WITH]-(E) AND
  NOT (B)-[:PLAYED_WITH]-(D) AND
  NOT (B)-[:PLAYED_WITH]-(E) AND
  NOT (C)-[:PLAYED_WITH]-(E)

WITH
  A,
  B,
  C,
  D,
  E,
  ab,
  bc,
  cd,
  de,
  (ab.weight + bc.weight + cd.weight + de.weight) AS total_weight

RETURN
  A.name AS Player_A,
  ab.club AS Club_AB,
  B.name AS Player_B,
  bc.club AS Club_BC,
  C.name AS Player_C,
  cd.club AS Club_CD,
  D.name AS Player_D,
  de.club AS Club_DE,
  E.name AS Player_E,
  total_weight
ORDER BY total_weight * rand() DESC
LIMIT 1000;

// -----------------------------
// 11. 5-Relationship Chain (A–B–C–D–E–F)
// -----------------------------
MATCH (a:Player)
CALL
  apoc.path.expandConfig(
    a,
    {
      relationshipFilter: "PLAYED_WITH>",
      minLevel: 5,
      maxLevel: 5,
      uniqueness: "NODE_GLOBAL",
      bfs: true,
      filterStartNode: true
    }
  )
  YIELD path

WITH path, nodes(path) AS nds, relationships(path) AS rels
WHERE
  size(rels) = 5 AND
  rels[0].club <> rels[1].club AND
  rels[1].club <> rels[2].club AND
  rels[2].club <> rels[3].club AND
  rels[3].club <> rels[4].club

WITH
  nds[0] AS A,
  nds[1] AS B,
  nds[2] AS C,
  nds[3] AS D,
  nds[4] AS E,
  nds[5] AS F,
  rels[0] AS ab,
  rels[1] AS bc,
  rels[2] AS cd,
  rels[3] AS de,
  rels[4] AS ef

// canonical ordering (avoid reverse duplicates)
WHERE
  A.id < F.id AND

  // prevent shortcut edges
  NOT (A)-[:PLAYED_WITH]-(C) AND
  NOT (A)-[:PLAYED_WITH]-(D) AND
  NOT (A)-[:PLAYED_WITH]-(E) AND
  NOT (A)-[:PLAYED_WITH]-(F) AND
  NOT (B)-[:PLAYED_WITH]-(D) AND
  NOT (B)-[:PLAYED_WITH]-(E) AND
  NOT (B)-[:PLAYED_WITH]-(F) AND
  NOT (C)-[:PLAYED_WITH]-(E) AND
  NOT (C)-[:PLAYED_WITH]-(F) AND
  NOT (D)-[:PLAYED_WITH]-(F)

WITH
  A,
  B,
  C,
  D,
  E,
  F,
  ab,
  bc,
  cd,
  de,
  ef,
  (ab.weight + bc.weight + cd.weight + de.weight + ef.weight) AS total_weight

RETURN
  A.name AS Player_A,
  ab.club AS Club_AB,
  B.name AS Player_B,
  bc.club AS Club_BC,
  C.name AS Player_C,
  cd.club AS Club_CD,
  D.name AS Player_D,
  de.club AS Club_DE,
  E.name AS Player_E,
  ef.club AS Club_EF,
  F.name AS Player_F,
  total_weight
ORDER BY total_weight * rand() DESC
LIMIT 1000;