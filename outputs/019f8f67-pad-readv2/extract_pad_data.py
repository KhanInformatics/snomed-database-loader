import csv
import json
from collections import defaultdict
from pathlib import Path

import pyodbc


ROOT = Path(r"O:\GitHub\snomed-database-loader")
OUTPUT = ROOT / "outputs" / "019f8f67-pad-readv2" / "pad_data.json"
MAP_DB = Path(r"O:\GitHub\DMWBtoSQL\DMWB\DMWB NHS Data Migration Maps.mdb")
READ_CSV = ROOT / "Readv2" / "Data" / "Readv2_codes_full.csv"
SQL_SERVER = r"SILENTPRIORY\SQLEXPRESS"
PAD_REFSET_ID = "999005931000230101"


def decode_read_code(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-16le").rstrip("\x00")
    return str(value).strip()


def rows_as_dicts(cursor):
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def connect_sql(database):
    return pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};"
        f"SERVER={SQL_SERVER};DATABASE={database};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;Encrypt=no;",
        timeout=30,
    )


with READ_CSV.open(newline="", encoding="utf-8-sig") as handle:
    read_dictionary = {
        row["ReadCode"]: {
            "term": row["PreferredTerm"],
            "status": row["Status"],
        }
        for row in csv.DictReader(handle)
    }


with connect_sql("snomedct") as connection:
    cursor = connection.cursor()
    cursor.execute(
        """
        SELECT
            CAST(s.referencedcomponentid AS varchar(20)) AS SnomedConceptId,
            d.term AS SnomedFSN,
            CAST(c.active AS int) AS ConceptIsActive,
            s.effectivetime AS MemberEffectiveTime,
            CASE WHEN p.SNOMED_code IS NULL THEN 0 ELSE 1 END AS InLoadedPCDCluster
        FROM dbo.curr_simplerefset_f s
        JOIN dbo.curr_concept_f c
          ON c.id = s.referencedcomponentid
        OUTER APPLY (
            SELECT TOP (1) term
            FROM dbo.curr_description_f d0
            WHERE d0.conceptid = s.referencedcomponentid
              AND d0.typeid = '900000000000003001'
              AND d0.active = 1
            ORDER BY d0.effectivetime DESC, d0.id
        ) d
        LEFT JOIN (
            SELECT DISTINCT SNOMED_code
            FROM dbo.PCD_Refset_Content_V2
            WHERE Cluster_ID = 'PAD_COD'
        ) p
          ON p.SNOMED_code = CAST(s.referencedcomponentid AS varchar(20))
        WHERE s.refsetid = ?
          AND s.active = 1
        ORDER BY CAST(s.referencedcomponentid AS varchar(20));
        """,
        PAD_REFSET_ID,
    )
    pad_concepts = rows_as_dicts(cursor)

    cursor.execute("SELECT MAX(effectivetime) FROM dbo.curr_concept_f;")
    snomed_release_date = str(cursor.fetchone()[0])
    cursor.execute("SELECT MAX(effectivetime) FROM dbo.curr_simplerefset_f;")
    refset_release_date = str(cursor.fetchone()[0])
    cursor.execute(
        """
        SELECT TOP (1) d.term
        FROM dbo.curr_description_f d
        WHERE d.conceptid = ?
          AND d.typeid = '900000000000003001'
          AND d.active = 1
        ORDER BY d.effectivetime DESC, d.id;
        """,
        PAD_REFSET_ID,
    )
    refset_fsn = cursor.fetchone()[0]
    cursor.execute(
        """
        SELECT COUNT(DISTINCT SNOMED_code)
        FROM dbo.PCD_Refset_Content_V2
        WHERE Cluster_ID = 'PAD_COD';
        """
    )
    pcd_cluster_count = int(cursor.fetchone()[0])

    # Build the active SNOMED historical-association graph around the current
    # PAD_COD members. Concept associations are traversed in both directions:
    # forward from an inactive/current source to its target, and backward from
    # a current target to retired predecessor concepts. Incoming associations
    # from descriptions are retained separately so exact retired-description
    # IDs can be matched against RCTSCTMAP.TTUI.
    concept_association_edges = defaultdict(list)
    description_predecessors_by_target = defaultdict(list)
    frontier = {row["SnomedConceptId"] for row in pad_concepts}
    expanded = set()
    seen_associations = set()
    # The original frontier query is retained below for audit history but is
    # disabled; the optimized single-read graph builder later in this file
    # replaces its outputs.
    max_history_depth = 0
    for _ in range(max_history_depth):
        frontier -= expanded
        if not frontier:
            break
        next_frontier = set()
        frontier_values = sorted(frontier)
        for chunk_start in range(0, len(frontier_values), 500):
            chunk = frontier_values[chunk_start : chunk_start + 500]
            placeholders = ",".join("?" for _ in chunk)
            cursor.execute(
                f"""
                SELECT
                    CAST(a.id AS varchar(36)) AS AssociationMemberId,
                    CAST(a.referencedcomponentid AS varchar(20)) AS SourceComponentId,
                    CAST(a.targetcomponentid AS varchar(20)) AS TargetConceptId,
                    CAST(a.refsetid AS varchar(20)) AS AssociationRefsetId,
                    COALESCE(ad.term, '') AS AssociationType,
                    CASE
                        WHEN sc.id IS NOT NULL THEN 'Concept'
                        WHEN sd.id IS NOT NULL THEN 'Description'
                        ELSE 'Other'
                    END AS SourceComponentType,
                    CAST(sc.id AS varchar(20)) AS SourceConceptId,
                    COALESCE(scd.term, '') AS SourceConceptFSN,
                    CAST(sc.active AS int) AS SourceConceptIsActive,
                    CAST(sd.id AS varchar(20)) AS SourceDescriptionId,
                    CAST(sd.conceptid AS varchar(20)) AS DescriptionOwnerConceptId,
                    COALESCE(sd.term, '') AS SourceDescriptionTerm,
                    CAST(sd.active AS int) AS SourceDescriptionIsActive,
                    sd.effectivetime AS SourceDescriptionEffectiveTime,
                    COALESCE(od.term, '') AS DescriptionOwnerFSN,
                    CAST(oc.active AS int) AS DescriptionOwnerIsActive,
                    COALESCE(td.term, '') AS TargetFSN,
                    CAST(tc.active AS int) AS TargetIsActive
                FROM dbo.curr_associationrefset_f a
                JOIN dbo.curr_concept_f tc
                  ON tc.id = a.targetcomponentid
                LEFT JOIN dbo.curr_concept_f sc
                  ON sc.id = a.referencedcomponentid
                OUTER APPLY (
                    SELECT TOP (1)
                        id, conceptid, term, active, effectivetime
                    FROM dbo.curr_description_f sd0
                    WHERE sd0.id = a.referencedcomponentid
                    ORDER BY sd0.effectivetime DESC
                ) sd
                LEFT JOIN dbo.curr_concept_f oc
                  ON oc.id = sd.conceptid
                OUTER APPLY (
                    SELECT TOP (1) term
                    FROM dbo.curr_description_f ad0
                    WHERE ad0.conceptid = a.refsetid
                      AND ad0.typeid = '900000000000003001'
                      AND ad0.active = 1
                    ORDER BY ad0.effectivetime DESC, ad0.id
                ) ad
                OUTER APPLY (
                    SELECT TOP (1) term
                    FROM dbo.curr_description_f scd0
                    WHERE scd0.conceptid = sc.id
                      AND scd0.typeid = '900000000000003001'
                    ORDER BY scd0.active DESC, scd0.effectivetime DESC, scd0.id
                ) scd
                OUTER APPLY (
                    SELECT TOP (1) term
                    FROM dbo.curr_description_f od0
                    WHERE od0.conceptid = oc.id
                      AND od0.typeid = '900000000000003001'
                    ORDER BY od0.active DESC, od0.effectivetime DESC, od0.id
                ) od
                OUTER APPLY (
                    SELECT TOP (1) term
                    FROM dbo.curr_description_f td0
                    WHERE td0.conceptid = a.targetcomponentid
                      AND td0.typeid = '900000000000003001'
                      AND td0.active = 1
                    ORDER BY td0.effectivetime DESC, td0.id
                ) td
                WHERE a.active = 1
                  AND (
                      a.referencedcomponentid IN ({placeholders})
                      OR a.targetcomponentid IN ({placeholders})
                  );
                """,
                [*chunk, *chunk],
            )
            for edge in rows_as_dicts(cursor):
                association_key = edge["AssociationMemberId"]
                if association_key in seen_associations:
                    continue
                seen_associations.add(association_key)
                association_type = str(edge["AssociationType"]).strip()
                association_label = association_type.split(
                    " association reference set"
                )[0].strip()
                edge["AssociationLabel"] = (
                    association_label or edge["AssociationRefsetId"]
                )
                if edge["SourceComponentType"] == "Concept":
                    source_id = edge["SourceConceptId"]
                    target_id = edge["TargetConceptId"]
                    concept_association_edges[source_id].append(
                        {
                            **edge,
                            "NeighborConceptId": target_id,
                            "NeighborFSN": edge["TargetFSN"],
                            "NeighborConceptIsActive": edge["TargetIsActive"],
                            "TraversalDirection": "Forward",
                            "PathSegment": (
                                f"{source_id} --[{edge['AssociationLabel']}]--> "
                                f"{target_id}"
                            ),
                        }
                    )
                    concept_association_edges[target_id].append(
                        {
                            **edge,
                            "NeighborConceptId": source_id,
                            "NeighborFSN": edge["SourceConceptFSN"],
                            "NeighborConceptIsActive": edge[
                                "SourceConceptIsActive"
                            ],
                            "TraversalDirection": "Reverse",
                            "PathSegment": (
                                f"{target_id} <--[{edge['AssociationLabel']}]-- "
                                f"{source_id}"
                            ),
                        }
                    )
                    next_frontier.update({source_id, target_id})
                elif edge["SourceComponentType"] == "Description":
                    description_predecessors_by_target[
                        edge["TargetConceptId"]
                    ].append(edge)
        expanded.update(frontier)
        frontier = next_frontier


def build_shortest_concept_paths(source_concept_id):
    """Return shortest pure-forward or pure-reverse concept-history paths."""
    paths = []
    best_depth_by_target = {}
    queue = [(source_concept_id, [], [source_concept_id], None)]
    while queue:
        current_id, edge_path, concept_path, traversal_mode = queue.pop(0)
        if len(edge_path) >= max_history_depth:
            continue
        for edge in concept_association_edges.get(current_id, []):
            edge_direction = edge["TraversalDirection"]
            if traversal_mode and edge_direction != traversal_mode:
                continue
            target_id = edge["NeighborConceptId"]
            if target_id in concept_path:
                continue
            next_edges = [*edge_path, edge]
            next_concepts = [*concept_path, target_id]
            depth = len(next_edges)
            prior_depth = best_depth_by_target.get(target_id)
            if prior_depth is not None and prior_depth <= depth:
                continue
            best_depth_by_target[target_id] = depth
            path_text = " ; ".join(hop["PathSegment"] for hop in next_edges)
            paths.append(
                {
                    "ResolvedConceptId": target_id,
                    "ResolvedFSN": edge["NeighborFSN"],
                    "ResolvedConceptIsActive": edge[
                        "NeighborConceptIsActive"
                    ],
                    "HistoricalDepth": depth,
                    "HistoricalAssociationPath": path_text,
                }
            )
            queue.append(
                (
                    target_id,
                    next_edges,
                    next_concepts,
                    traversal_mode or edge_direction,
                )
            )
    return sorted(
        paths,
        key=lambda row: (
            row["HistoricalDepth"],
            row["ResolvedConceptId"],
            row["HistoricalAssociationPath"],
        ),
    )


concept_paths_by_concept = {
    row["SnomedConceptId"]: build_shortest_concept_paths(
        row["SnomedConceptId"]
    )
    for row in pad_concepts
}


description_paths_by_concept = {}
for concept in pad_concepts:
    source_id = concept["SnomedConceptId"]
    target_paths = [
        {
            "ResolvedConceptId": source_id,
            "ResolvedFSN": concept["SnomedFSN"],
            "ResolvedConceptIsActive": concept["ConceptIsActive"],
            "HistoricalDepth": 0,
            "HistoricalAssociationPath": "",
        },
        *concept_paths_by_concept[source_id],
    ]
    best_description_paths = {}
    for target_path in target_paths:
        target_id = target_path["ResolvedConceptId"]
        for edge in description_predecessors_by_target.get(target_id, []):
            description_id = edge["SourceDescriptionId"]
            depth = target_path["HistoricalDepth"] + 1
            path_prefix = target_path["HistoricalAssociationPath"]
            description_segment = (
                f"{target_id} <--[{edge['AssociationLabel']}]-- retired "
                f"description {description_id} "
                f"({edge['SourceDescriptionTerm']}) on concept "
                f"{edge['DescriptionOwnerConceptId']}"
            )
            path_text = (
                f"{path_prefix} ; {description_segment}"
                if path_prefix
                else description_segment
            )
            candidate = {
                "ResolvedConceptId": edge["DescriptionOwnerConceptId"],
                "ResolvedFSN": edge["DescriptionOwnerFSN"],
                "ResolvedConceptIsActive": edge["DescriptionOwnerIsActive"],
                "MappedDescriptionId": description_id,
                "MappedDescriptionTerm": edge["SourceDescriptionTerm"],
                "MappedDescriptionIsActive": edge[
                    "SourceDescriptionIsActive"
                ],
                "MappedDescriptionEffectiveTime": edge[
                    "SourceDescriptionEffectiveTime"
                ],
                "HistoricalDepth": depth,
                "HistoricalAssociationPath": path_text,
            }
            prior = best_description_paths.get(description_id)
            if prior is None or depth < prior["HistoricalDepth"]:
                best_description_paths[description_id] = candidate
    description_paths_by_concept[source_id] = sorted(
        best_description_paths.values(),
        key=lambda row: (
            row["HistoricalDepth"],
            row["MappedDescriptionId"],
            row["HistoricalAssociationPath"],
        ),
    )


# Optimized full-history graph build. Association rows are read once, the small
# PAD-connected component is identified in memory, and only those concepts and
# retired descriptions are enriched from the large RF2 component tables.
max_history_depth = 20


def chunks(values, size=500):
    for start in range(0, len(values), size):
        yield values[start : start + size]


with connect_sql("snomedct") as connection:
    cursor = connection.cursor()

    associations_out = defaultdict(list)
    associations_in = defaultdict(list)
    cursor.execute(
        """
        SELECT
            CAST(referencedcomponentid AS varchar(20)) AS SourceComponentId,
            CAST(targetcomponentid AS varchar(20)) AS TargetConceptId,
            CAST(refsetid AS varchar(20)) AS AssociationRefsetId
        FROM dbo.curr_associationrefset_f
        WHERE active = 1
          AND 1 = 0;
        """
    )
    for source_id, target_id, refset_id in cursor.fetchall():
        edge = (str(source_id), str(target_id), str(refset_id))
        associations_out[edge[0]].append(edge)
        associations_in[edge[1]].append(edge)
    print(
        f"Loaded {sum(len(rows) for rows in associations_out.values())} "
        "active association rows",
        flush=True,
    )

    concept_metadata = {
        row["SnomedConceptId"]: {
            "ConceptId": row["SnomedConceptId"],
            "FSN": row["SnomedFSN"],
            "IsActive": row["ConceptIsActive"],
        }
        for row in pad_concepts
    }
    known_nonconcept_ids = set()

    def fetch_concept_metadata(component_ids):
        requested = sorted(
            set(component_ids)
            - set(concept_metadata)
            - known_nonconcept_ids
        )
        for chunk in chunks(requested):
            placeholders = ",".join("?" for _ in chunk)
            cursor.execute(
                f"""
                SELECT
                    CAST(c.id AS varchar(20)) AS ConceptId,
                    CAST(c.active AS int) AS IsActive,
                    COALESCE(d.term, '') AS FSN
                FROM dbo.curr_concept_f c
                OUTER APPLY (
                    SELECT TOP (1) term
                    FROM dbo.curr_description_f d0
                    WHERE d0.conceptid = c.id
                      AND d0.typeid = '900000000000003001'
                    ORDER BY d0.active DESC, d0.effectivetime DESC, d0.id
                ) d
                WHERE c.id IN ({placeholders});
                """,
                chunk,
            )
            found = set()
            for row in rows_as_dicts(cursor):
                concept_id = str(row["ConceptId"])
                found.add(concept_id)
                concept_metadata[concept_id] = {
                    "ConceptId": concept_id,
                    "FSN": row["FSN"],
                    "IsActive": row["IsActive"],
                }
            known_nonconcept_ids.update(set(chunk) - found)

    reached_concepts = {
        row["SnomedConceptId"] for row in pad_concepts
    }
    frontier = set(reached_concepts)
    relevant_concept_associations = {}
    candidate_description_associations = {}

    for history_iteration in range(max_history_depth):
        if not frontier:
            break
        print(
            f"History iteration {history_iteration + 1}: "
            f"{len(frontier)} concept(s)",
            flush=True,
        )
        incoming_edges = []
        next_frontier = set()
        for concept_id in frontier:
            for edge in associations_out.get(concept_id, []):
                relevant_concept_associations[edge] = edge
                next_frontier.add(edge[1])
            for edge in associations_in.get(concept_id, []):
                incoming_edges.append(edge)

        fetch_concept_metadata([edge[0] for edge in incoming_edges])
        for edge in incoming_edges:
            source_id = edge[0]
            if source_id in concept_metadata:
                relevant_concept_associations[edge] = edge
                next_frontier.add(source_id)
            else:
                candidate_description_associations[edge] = edge

        fetch_concept_metadata(next_frontier)
        next_frontier = {
            concept_id
            for concept_id in next_frontier
            if concept_id in concept_metadata
        }
        next_frontier -= reached_concepts
        reached_concepts.update(next_frontier)
        frontier = next_frontier

    refset_ids = sorted(
        {
            edge[2] for edge in relevant_concept_associations
        }
        | {
            edge[2] for edge in candidate_description_associations
        }
    )
    fetch_concept_metadata(refset_ids)
    association_labels = {}
    for refset_id in refset_ids:
        term = concept_metadata.get(refset_id, {}).get("FSN", "")
        label = str(term).split(" association reference set")[0].strip()
        association_labels[refset_id] = label or refset_id

    description_ids = sorted(
        {edge[0] for edge in candidate_description_associations}
    )
    print(
        f"History graph: {len(reached_concepts)} concepts, "
        f"{len(relevant_concept_associations)} concept associations, "
        f"{len(description_ids)} possible description components",
        flush=True,
    )
    description_metadata = {}
    for chunk in chunks(description_ids):
        placeholders = ",".join("?" for _ in chunk)
        cursor.execute(
            f"""
            WITH ranked_descriptions AS (
                SELECT
                    id,
                    conceptid,
                    term,
                    active,
                    effectivetime,
                    ROW_NUMBER() OVER (
                        PARTITION BY id
                        ORDER BY effectivetime DESC
                    ) AS row_rank
                FROM dbo.curr_description_f
                WHERE id IN ({placeholders})
            )
            SELECT
                CAST(rd.id AS varchar(20)) AS DescriptionId,
                CAST(rd.conceptid AS varchar(20)) AS OwnerConceptId,
                rd.term AS DescriptionTerm,
                CAST(rd.active AS int) AS DescriptionIsActive,
                rd.effectivetime AS DescriptionEffectiveTime,
                CAST(oc.active AS int) AS OwnerConceptIsActive,
                COALESCE(od.term, '') AS OwnerFSN
            FROM ranked_descriptions rd
            JOIN dbo.curr_concept_f oc
              ON oc.id = rd.conceptid
            OUTER APPLY (
                SELECT TOP (1) term
                FROM dbo.curr_description_f od0
                WHERE od0.conceptid = rd.conceptid
                  AND od0.typeid = '900000000000003001'
                ORDER BY od0.active DESC, od0.effectivetime DESC, od0.id
            ) od
            WHERE rd.row_rank = 1;
            """,
            chunk,
        )
        for row in rows_as_dicts(cursor):
            description_metadata[str(row["DescriptionId"])] = row


# Server-side indexed history expansion. This avoids repeatedly scanning or
# transferring the full 382k-row association snapshot.
with connect_sql("snomedct") as connection:
    cursor = connection.cursor()
    cursor.execute(
        """
        SELECT
            CAST(referencedcomponentid AS varchar(20)) AS SourceComponentId,
            CAST(targetcomponentid AS varchar(20)) AS TargetConceptId,
            CAST(refsetid AS varchar(20)) AS AssociationRefsetId
        INTO #pad_associations
        FROM dbo.curr_associationrefset_f
        WHERE active = 1;

        CREATE INDEX IX_pad_associations_source
            ON #pad_associations(SourceComponentId);
        CREATE INDEX IX_pad_associations_target
            ON #pad_associations(TargetConceptId);

        CREATE TABLE #forward_reached (
            ConceptId varchar(20) NOT NULL PRIMARY KEY
        );
        CREATE TABLE #reverse_reached (
            ConceptId varchar(20) NOT NULL PRIMARY KEY
        );
        CREATE TABLE #frontier (
            ConceptId varchar(20) NOT NULL
        );
        CREATE TABLE #next_frontier (
            ConceptId varchar(20) NOT NULL
        );
        """
    )
    pad_ids = sorted(row["SnomedConceptId"] for row in pad_concepts)
    cursor.fast_executemany = True
    cursor.executemany(
        "INSERT INTO #forward_reached(ConceptId) VALUES (?);",
        [(concept_id,) for concept_id in pad_ids],
    )
    cursor.executemany(
        "INSERT INTO #reverse_reached(ConceptId) VALUES (?);",
        [(concept_id,) for concept_id in pad_ids],
    )
    cursor.execute(
        "INSERT INTO #frontier(ConceptId) "
        "SELECT ConceptId FROM #forward_reached;"
    )

    for history_iteration in range(max_history_depth):
        cursor.execute(
            """
            TRUNCATE TABLE #next_frontier;

            INSERT INTO #next_frontier(ConceptId)
            SELECT DISTINCT a.TargetConceptId
            FROM #pad_associations a
            JOIN #frontier f
              ON f.ConceptId = a.SourceComponentId
            JOIN dbo.curr_concept_f c
              ON c.id = a.TargetConceptId;

            TRUNCATE TABLE #frontier;

            INSERT INTO #frontier(ConceptId)
            SELECT DISTINCT n.ConceptId
            FROM #next_frontier n
            WHERE NOT EXISTS (
                SELECT 1
                FROM #forward_reached r
                WHERE r.ConceptId = n.ConceptId
            );

            INSERT INTO #forward_reached(ConceptId)
            SELECT ConceptId
            FROM #frontier;
            """
        )
        cursor.execute(
            "SELECT COUNT(*) AS FrontierCount FROM #frontier;"
        )
        frontier_count = int(cursor.fetchone()[0])
        print(
            f"Forward history iteration {history_iteration + 1}: "
            f"{frontier_count} new concept(s)",
            flush=True,
        )
        if frontier_count == 0:
            break

    cursor.execute(
        "TRUNCATE TABLE #frontier; "
        "INSERT INTO #frontier(ConceptId) "
        "SELECT ConceptId FROM #reverse_reached;"
    )
    for history_iteration in range(max_history_depth):
        cursor.execute(
            """
            TRUNCATE TABLE #next_frontier;

            INSERT INTO #next_frontier(ConceptId)
            SELECT DISTINCT a.SourceComponentId
            FROM #pad_associations a
            JOIN #frontier f
              ON f.ConceptId = a.TargetConceptId
            JOIN dbo.curr_concept_f c
              ON c.id = a.SourceComponentId;

            TRUNCATE TABLE #frontier;

            INSERT INTO #frontier(ConceptId)
            SELECT DISTINCT n.ConceptId
            FROM #next_frontier n
            WHERE NOT EXISTS (
                SELECT 1
                FROM #reverse_reached r
                WHERE r.ConceptId = n.ConceptId
            );

            INSERT INTO #reverse_reached(ConceptId)
            SELECT ConceptId
            FROM #frontier;
            """
        )
        cursor.execute(
            "SELECT COUNT(*) AS FrontierCount FROM #frontier;"
        )
        frontier_count = int(cursor.fetchone()[0])
        print(
            f"Reverse history iteration {history_iteration + 1}: "
            f"{frontier_count} new concept(s)",
            flush=True,
        )
        if frontier_count == 0:
            break

    cursor.execute(
        """
        WITH reached AS (
            SELECT ConceptId FROM #forward_reached
            UNION
            SELECT ConceptId FROM #reverse_reached
        )
        SELECT
            CAST(c.id AS varchar(20)) AS ConceptId,
            CAST(c.active AS int) AS IsActive,
            COALESCE(d.term, '') AS FSN
        FROM reached r
        JOIN dbo.curr_concept_f c
          ON c.id = r.ConceptId
        OUTER APPLY (
            SELECT TOP (1) term
            FROM dbo.curr_description_f d0
            WHERE d0.conceptid = c.id
              AND d0.typeid = '900000000000003001'
            ORDER BY d0.active DESC, d0.effectivetime DESC, d0.id
        ) d;
        """
    )
    concept_metadata = {
        str(row["ConceptId"]): {
            "ConceptId": str(row["ConceptId"]),
            "FSN": row["FSN"],
            "IsActive": row["IsActive"],
        }
        for row in rows_as_dicts(cursor)
    }

    cursor.execute(
        """
        SELECT DISTINCT
            a.SourceComponentId,
            a.TargetConceptId,
            a.AssociationRefsetId,
            'Forward' AS TraversalDirection
        FROM #pad_associations a
        JOIN #forward_reached rs
          ON rs.ConceptId = a.SourceComponentId
        JOIN #forward_reached rt
          ON rt.ConceptId = a.TargetConceptId

        UNION

        SELECT DISTINCT
            a.SourceComponentId,
            a.TargetConceptId,
            a.AssociationRefsetId,
            'Reverse' AS TraversalDirection
        FROM #pad_associations a
        JOIN #reverse_reached rs
          ON rs.ConceptId = a.SourceComponentId
        JOIN #reverse_reached rt
          ON rt.ConceptId = a.TargetConceptId;
        """
    )
    relevant_concept_associations = {
        (
            str(row["SourceComponentId"]),
            str(row["TargetConceptId"]),
            str(row["AssociationRefsetId"]),
            str(row["TraversalDirection"]),
        ): (
            str(row["SourceComponentId"]),
            str(row["TargetConceptId"]),
            str(row["AssociationRefsetId"]),
            str(row["TraversalDirection"]),
        )
        for row in rows_as_dicts(cursor)
    }

    cursor.execute(
        """
        WITH reached AS (
            SELECT ConceptId FROM #forward_reached
            UNION
            SELECT ConceptId FROM #reverse_reached
        )
        SELECT DISTINCT
            a.SourceComponentId AS DescriptionId,
            a.TargetConceptId,
            a.AssociationRefsetId,
            CAST(sd.conceptid AS varchar(20)) AS OwnerConceptId,
            CAST(sd.term AS nvarchar(500)) AS DescriptionTerm,
            CAST(sd.active AS int) AS DescriptionIsActive,
            sd.effectivetime AS DescriptionEffectiveTime,
            CAST(oc.active AS int) AS OwnerConceptIsActive,
            CAST(COALESCE(od.term, '') AS nvarchar(500)) AS OwnerFSN
        FROM #pad_associations a
        JOIN reached rt
          ON rt.ConceptId = a.TargetConceptId
        OUTER APPLY (
            SELECT TOP (1)
                conceptid,
                term,
                active,
                effectivetime
            FROM dbo.curr_description_f sd0
            WHERE sd0.id = a.SourceComponentId
            ORDER BY sd0.effectivetime DESC
        ) sd
        JOIN dbo.curr_concept_f oc
          ON oc.id = sd.conceptid
        OUTER APPLY (
            SELECT TOP (1) term
            FROM dbo.curr_description_f od0
            WHERE od0.conceptid = sd.conceptid
              AND od0.typeid = '900000000000003001'
            ORDER BY od0.active DESC, od0.effectivetime DESC, od0.id
        ) od
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.curr_concept_f sc
            WHERE sc.id = a.SourceComponentId
        );
        """
    )
    description_rows = rows_as_dicts(cursor)

    refset_ids = sorted(
        {
            edge[2] for edge in relevant_concept_associations
        }
        | {
            str(row["AssociationRefsetId"])
            for row in description_rows
        }
    )
    association_labels = {}
    for chunk in chunks(refset_ids):
        placeholders = ",".join("?" for _ in chunk)
        cursor.execute(
            f"""
            SELECT
                CAST(c.id AS varchar(20)) AS RefsetId,
                COALESCE(d.term, '') AS FSN
            FROM dbo.curr_concept_f c
            OUTER APPLY (
                SELECT TOP (1) term
                FROM dbo.curr_description_f d0
                WHERE d0.conceptid = c.id
                  AND d0.typeid = '900000000000003001'
                ORDER BY d0.active DESC, d0.effectivetime DESC, d0.id
            ) d
            WHERE c.id IN ({placeholders});
            """,
            chunk,
        )
        for row in rows_as_dicts(cursor):
            refset_id = str(row["RefsetId"])
            label = str(row["FSN"]).split(
                " association reference set"
            )[0].strip()
            association_labels[refset_id] = label or refset_id

    description_metadata = {
        str(row["DescriptionId"]): {
            "DescriptionId": str(row["DescriptionId"]),
            "OwnerConceptId": str(row["OwnerConceptId"]),
            "DescriptionTerm": row["DescriptionTerm"],
            "DescriptionIsActive": row["DescriptionIsActive"],
            "DescriptionEffectiveTime": row["DescriptionEffectiveTime"],
            "OwnerConceptIsActive": row["OwnerConceptIsActive"],
            "OwnerFSN": row["OwnerFSN"],
        }
        for row in description_rows
    }
    candidate_description_associations = {
        (
            str(row["DescriptionId"]),
            str(row["TargetConceptId"]),
            str(row["AssociationRefsetId"]),
        ): (
            str(row["DescriptionId"]),
            str(row["TargetConceptId"]),
            str(row["AssociationRefsetId"]),
        )
        for row in description_rows
    }
    print(
        f"Indexed history graph: {len(concept_metadata)} concepts, "
        f"{len(relevant_concept_associations)} concept associations, "
        f"{len(description_metadata)} description components",
        flush=True,
    )


concept_association_edges = defaultdict(list)
for (
    source_id,
    target_id,
    refset_id,
    traversal_direction,
) in relevant_concept_associations:
    source_meta = concept_metadata[source_id]
    target_meta = concept_metadata[target_id]
    label = association_labels[refset_id]
    if traversal_direction == "Forward":
        concept_association_edges[source_id].append(
            {
                "NeighborConceptId": target_id,
                "NeighborFSN": target_meta["FSN"],
                "NeighborConceptIsActive": target_meta["IsActive"],
                "TraversalDirection": "Forward",
                "PathSegment": f"{source_id} --[{label}]--> {target_id}",
            }
        )
    else:
        concept_association_edges[target_id].append(
            {
                "NeighborConceptId": source_id,
                "NeighborFSN": source_meta["FSN"],
                "NeighborConceptIsActive": source_meta["IsActive"],
                "TraversalDirection": "Reverse",
                "PathSegment": f"{target_id} <--[{label}]-- {source_id}",
            }
        )

description_predecessors_by_target = defaultdict(list)
for source_id, target_id, refset_id in candidate_description_associations:
    metadata = description_metadata.get(source_id)
    if not metadata:
        continue
    description_predecessors_by_target[target_id].append(
        {
            "TargetConceptId": target_id,
            "AssociationLabel": association_labels[refset_id],
            "SourceDescriptionId": source_id,
            "SourceDescriptionTerm": metadata["DescriptionTerm"],
            "SourceDescriptionIsActive": metadata["DescriptionIsActive"],
            "SourceDescriptionEffectiveTime": metadata[
                "DescriptionEffectiveTime"
            ],
            "DescriptionOwnerConceptId": str(metadata["OwnerConceptId"]),
            "DescriptionOwnerFSN": metadata["OwnerFSN"],
            "DescriptionOwnerIsActive": metadata["OwnerConceptIsActive"],
        }
    )

concept_paths_by_concept = {
    row["SnomedConceptId"]: build_shortest_concept_paths(
        row["SnomedConceptId"]
    )
    for row in pad_concepts
}

description_paths_by_concept = {}
for concept in pad_concepts:
    source_id = concept["SnomedConceptId"]
    target_paths = [
        {
            "ResolvedConceptId": source_id,
            "ResolvedFSN": concept["SnomedFSN"],
            "ResolvedConceptIsActive": concept["ConceptIsActive"],
            "HistoricalDepth": 0,
            "HistoricalAssociationPath": "",
        },
        *concept_paths_by_concept[source_id],
    ]
    best_description_paths = {}
    for target_path in target_paths:
        target_id = target_path["ResolvedConceptId"]
        for edge in description_predecessors_by_target.get(target_id, []):
            description_id = edge["SourceDescriptionId"]
            depth = target_path["HistoricalDepth"] + 1
            path_prefix = target_path["HistoricalAssociationPath"]
            status_label = (
                "active description"
                if edge["SourceDescriptionIsActive"]
                else "retired description"
            )
            description_segment = (
                f"{target_id} <--[{edge['AssociationLabel']}]-- "
                f"{status_label} {description_id} "
                f"({edge['SourceDescriptionTerm']}) on concept "
                f"{edge['DescriptionOwnerConceptId']}"
            )
            path_text = (
                f"{path_prefix} ; {description_segment}"
                if path_prefix
                else description_segment
            )
            candidate = {
                "ResolvedConceptId": edge["DescriptionOwnerConceptId"],
                "ResolvedFSN": edge["DescriptionOwnerFSN"],
                "ResolvedConceptIsActive": edge[
                    "DescriptionOwnerIsActive"
                ],
                "MappedDescriptionId": description_id,
                "MappedDescriptionTerm": edge["SourceDescriptionTerm"],
                "MappedDescriptionIsActive": edge[
                    "SourceDescriptionIsActive"
                ],
                "MappedDescriptionEffectiveTime": edge[
                    "SourceDescriptionEffectiveTime"
                ],
                "HistoricalDepth": depth,
                "HistoricalAssociationPath": path_text,
            }
            prior = best_description_paths.get(description_id)
            if prior is None or depth < prior["HistoricalDepth"]:
                best_description_paths[description_id] = candidate
    description_paths_by_concept[source_id] = sorted(
        best_description_paths.values(),
        key=lambda row: (
            row["HistoricalDepth"],
            row["MappedDescriptionId"],
            row["HistoricalAssociationPath"],
        ),
    )


v32_source_rows = [
    {
        "ReadV2Code": "G73..",
        "SourceExpression": "G73..",
        "IncludedInV32": "Yes",
        "DecisionBasis": "Exact code listed in the v32 source workbook",
    },
    {
        "ReadV2Code": "G734.",
        "SourceExpression": "G734.",
        "IncludedInV32": "Yes",
        "DecisionBasis": "Exact code listed in the v32 source workbook",
    },
    {
        "ReadV2Code": "G73y.",
        "SourceExpression": "G73y.",
        "IncludedInV32": "Yes",
        "DecisionBasis": "Exact code listed in the v32 source workbook",
    },
    {
        "ReadV2Code": "G73z.",
        "SourceExpression": "G73z% (excluding G73z1)",
        "IncludedInV32": "Yes",
        "DecisionBasis": "Included by the explicit percent-wildcard expression",
    },
    {
        "ReadV2Code": "G73z0",
        "SourceExpression": "G73z% (excluding G73z1)",
        "IncludedInV32": "Yes",
        "DecisionBasis": "Included by the explicit percent-wildcard expression",
    },
    {
        "ReadV2Code": "G73z1",
        "SourceExpression": "G73z% (excluding G73z1)",
        "IncludedInV32": "No",
        "DecisionBasis": "Explicitly excluded from the percent-wildcard expression",
    },
    {
        "ReadV2Code": "G73zz",
        "SourceExpression": "G73z% (excluding G73z1)",
        "IncludedInV32": "Yes",
        "DecisionBasis": "Included by the explicit percent-wildcard expression",
    },
    {
        "ReadV2Code": "Gyu74",
        "SourceExpression": "Gyu74",
        "IncludedInV32": "Yes",
        "DecisionBasis": "Exact code listed in the v32 source workbook",
    },
]


access_connection = pyodbc.connect(
    "DRIVER={Microsoft Access Driver (*.mdb, *.accdb)};"
    f"DBQ={MAP_DB};"
)
access_cursor = access_connection.cursor()
concept_ids = sorted(
    {
        row["SnomedConceptId"]
        for row in pad_concepts
    }
    | {
        path["ResolvedConceptId"]
        for paths in concept_paths_by_concept.values()
        for path in paths
    }
)
placeholders = ",".join("?" for _ in concept_ids)
access_cursor.execute(
    f"""
    SELECT SCUI, STUI, TCUI, TTUI, MAPTYP, ASSURED
    FROM RCTSCTMAP
    WHERE TCUI IN ({placeholders});
    """,
    concept_ids,
)
raw_concept_map_rows = rows_as_dicts(access_cursor)

description_ids = sorted(
    {
        path["MappedDescriptionId"]
        for paths in description_paths_by_concept.values()
        for path in paths
    }
)
raw_description_map_rows = []
if description_ids:
    placeholders = ",".join("?" for _ in description_ids)
    access_cursor.execute(
        f"""
        SELECT SCUI, STUI, TCUI, TTUI, MAPTYP, ASSURED
        FROM RCTSCTMAP
        WHERE TTUI IN ({placeholders});
        """,
        description_ids,
    )
    raw_description_map_rows = rows_as_dicts(access_cursor)

access_cursor.execute(
    """
    SELECT MAP, RELEASEDATE, BUILDDATE, SNAPSHOTDATE
    FROM MAPVERSIONS
    WHERE MAP = 'RCTSCTMAP';
    """
)
map_version_row = rows_as_dicts(access_cursor)[0]
access_connection.close()


maps_by_pair = {}
for row in raw_concept_map_rows:
    read_code = decode_read_code(row["SCUI"])
    key = (str(row["TCUI"]), read_code)
    aggregate = maps_by_pair.setdefault(
        key,
        {
            "term_ids": set(),
            "map_types": set(),
            "assured_values": set(),
            "description_ids": set(),
        },
    )
    aggregate["term_ids"].add(str(row["STUI"]).strip())
    aggregate["map_types"].add(str(row["MAPTYP"]).strip())
    aggregate["assured_values"].add(bool(row["ASSURED"]))
    aggregate["description_ids"].add(str(row["TTUI"]).strip())

maps_by_concept = defaultdict(list)
for (concept_id, read_code), aggregate in maps_by_pair.items():
    term_ids = sorted(value for value in aggregate["term_ids"] if value)
    assured_values = aggregate["assured_values"]
    if assured_values == {True}:
        assurance = "Assured"
    elif assured_values == {False}:
        assurance = "Unassured"
    else:
        assurance = "Mixed"
    if "00" in term_ids and len(term_ids) == 1:
        term_basis = "Preferred term (00)"
    elif "00" in term_ids:
        term_basis = "Preferred + synonym term(s)"
    else:
        term_basis = "Synonym term(s) only"
    dictionary_entry = read_dictionary.get(read_code, {})
    maps_by_concept[concept_id].append(
        {
            "ReadV2Code": read_code,
            "ReadV2Term": dictionary_entry.get("term", ""),
            "ReadV2Status": dictionary_entry.get("status", ""),
            "MapType": ", ".join(sorted(aggregate["map_types"])),
            "Assurance": assurance,
            "MapTermIDs": ", ".join(term_ids),
            "MapTermBasis": term_basis,
            "ListClosureCode": "Yes"
            if read_code and read_code[-1] in {"y", "z", "Z"}
            else "No",
        }
    )


description_maps_by_pair = {}
for row in raw_description_map_rows:
    read_code = decode_read_code(row["SCUI"])
    description_id = str(row["TTUI"]).strip()
    mapped_concept_id = str(row["TCUI"]).strip()
    key = (description_id, mapped_concept_id, read_code)
    aggregate = description_maps_by_pair.setdefault(
        key,
        {
            "term_ids": set(),
            "map_types": set(),
            "assured_values": set(),
        },
    )
    aggregate["term_ids"].add(str(row["STUI"]).strip())
    aggregate["map_types"].add(str(row["MAPTYP"]).strip())
    aggregate["assured_values"].add(bool(row["ASSURED"]))

maps_by_description = defaultdict(list)
for (
    description_id,
    mapped_concept_id,
    read_code,
), aggregate in description_maps_by_pair.items():
    term_ids = sorted(value for value in aggregate["term_ids"] if value)
    assured_values = aggregate["assured_values"]
    if assured_values == {True}:
        assurance = "Assured"
    elif assured_values == {False}:
        assurance = "Unassured"
    else:
        assurance = "Mixed"
    if "00" in term_ids and len(term_ids) == 1:
        term_basis = "Preferred term (00)"
    elif "00" in term_ids:
        term_basis = "Preferred + synonym term(s)"
    else:
        term_basis = "Synonym term(s) only"
    dictionary_entry = read_dictionary.get(read_code, {})
    maps_by_description[description_id].append(
        {
            "ResolvedConceptIdFromMap": mapped_concept_id,
            "ReadV2Code": read_code,
            "ReadV2Term": dictionary_entry.get("term", ""),
            "ReadV2Status": dictionary_entry.get("status", ""),
            "MapType": ", ".join(sorted(aggregate["map_types"])),
            "Assurance": assurance,
            "MapTermIDs": ", ".join(term_ids),
            "MapTermBasis": term_basis,
            "ListClosureCode": "Yes"
            if read_code and read_code[-1] in {"y", "z", "Z"}
            else "No",
        }
    )


mapping_rows = []
for concept in pad_concepts:
    concept_id = concept["SnomedConceptId"]
    concept_resolution_paths = [
        {
            "BackMapRoute": "Direct",
            "ResolvedConceptId": concept_id,
            "ResolvedFSN": concept["SnomedFSN"],
            "ResolvedConceptIsActive": concept["ConceptIsActive"],
            "MappedDescriptionId": "",
            "MappedDescriptionTerm": "",
            "MappedDescriptionIsActive": "",
            "MappedDescriptionEffectiveTime": "",
            "HistoricalDepth": 0,
            "HistoricalAssociationPath": "",
        },
        *[
            {
                "BackMapRoute": "Concept history",
                "MappedDescriptionId": "",
                "MappedDescriptionTerm": "",
                "MappedDescriptionIsActive": "",
                "MappedDescriptionEffectiveTime": "",
                **path,
            }
            for path in concept_paths_by_concept[concept_id]
        ],
    ]
    concept_mapping_rows = []
    seen_mapping_rows = set()
    for resolution in concept_resolution_paths:
        resolved_maps = sorted(
            maps_by_concept.get(resolution["ResolvedConceptId"], []),
            key=lambda row: row["ReadV2Code"],
        )
        for map_row in resolved_maps:
            row_key = (
                resolution["BackMapRoute"],
                resolution["ResolvedConceptId"],
                "",
                map_row["ReadV2Code"],
                resolution["HistoricalAssociationPath"],
            )
            if row_key in seen_mapping_rows:
                continue
            seen_mapping_rows.add(row_key)
            concept_mapping_rows.append(
                {
                    **concept,
                    **resolution,
                    **map_row,
                }
            )

    for resolution in description_paths_by_concept[concept_id]:
        resolved_maps = sorted(
            maps_by_description.get(resolution["MappedDescriptionId"], []),
            key=lambda row: (
                row["ReadV2Code"],
                row["ResolvedConceptIdFromMap"],
            ),
        )
        for map_row in resolved_maps:
            row_key = (
                "Description history",
                map_row["ResolvedConceptIdFromMap"],
                resolution["MappedDescriptionId"],
                map_row["ReadV2Code"],
                resolution["HistoricalAssociationPath"],
            )
            if row_key in seen_mapping_rows:
                continue
            seen_mapping_rows.add(row_key)
            description_resolution = {
                **resolution,
                "BackMapRoute": "Description history",
                "ResolvedConceptId": map_row["ResolvedConceptIdFromMap"],
            }
            concept_mapping_rows.append(
                {
                    **concept,
                    **description_resolution,
                    **{
                        key: value
                        for key, value in map_row.items()
                        if key != "ResolvedConceptIdFromMap"
                    },
                }
            )
    if concept_mapping_rows:
        mapping_rows.extend(concept_mapping_rows)
        continue

    checked_concept_paths = concept_paths_by_concept[concept_id]
    checked_description_paths = description_paths_by_concept[concept_id]
    mapping_rows.append(
        {
            **concept,
            "BackMapRoute": "Unmapped",
            "ResolvedConceptId": "",
            "ResolvedFSN": "",
            "ResolvedConceptIsActive": "",
            "MappedDescriptionId": "",
            "MappedDescriptionTerm": "",
            "MappedDescriptionIsActive": "",
            "MappedDescriptionEffectiveTime": "",
            "HistoricalDepth": "",
            "HistoricalAssociationPath": (
                "No mapped direct, concept-history, or retired-description "
                f"route; checked {len(checked_concept_paths)} related "
                f"concept(s) and {len(checked_description_paths)} retired "
                "description(s)"
            ),
            "ReadV2Code": "",
            "ReadV2Term": "",
            "ReadV2Status": "",
            "MapType": "",
            "Assurance": "",
            "MapTermIDs": "",
            "MapTermBasis": "",
            "ListClosureCode": "",
        }
    )


v32_candidates = []
for row in v32_source_rows:
    code = row["ReadV2Code"]
    dictionary_entry = read_dictionary.get(code, {})
    v32_candidates.append(
        {
            "IncludedInV32": row["IncludedInV32"],
            "ReadV2Code": code,
            "ReadV2Term": dictionary_entry.get("term", ""),
            "ReadV2Status": dictionary_entry.get("status", ""),
            "ContractRuleTriggered": row["SourceExpression"],
            "DecisionBasis": row["DecisionBasis"],
        }
    )
v32_candidates.sort(key=lambda row: row["ReadV2Code"])


included_v32_codes = {
    row["ReadV2Code"] for row in v32_candidates if row["IncludedInV32"] == "Yes"
}
backmapped_read_codes = {
    row["ReadV2Code"] for row in mapping_rows if row["ReadV2Code"]
}
direct_mapped_concepts = {
    row["SnomedConceptId"]
    for row in mapping_rows
    if row["ReadV2Code"] and row["BackMapRoute"] == "Direct"
}
concept_history_mapped_concepts = {
    row["SnomedConceptId"]
    for row in mapping_rows
    if row["ReadV2Code"] and row["BackMapRoute"] == "Concept history"
}
description_history_mapped_concepts = {
    row["SnomedConceptId"]
    for row in mapping_rows
    if row["ReadV2Code"] and row["BackMapRoute"] == "Description history"
}
historically_mapped_concepts = (
    concept_history_mapped_concepts | description_history_mapped_concepts
)
all_mapped_concepts = direct_mapped_concepts | historically_mapped_concepts
all_pad_concepts = {row["SnomedConceptId"] for row in pad_concepts}

metadata = {
    "PADRefsetId": PAD_REFSET_ID,
    "PADRefsetFSN": refset_fsn,
    "SnomedDatabaseReleaseDate": snomed_release_date,
    "SimpleRefsetReleaseDate": refset_release_date,
    "ActivePADConceptCount": len(pad_concepts),
    "LoadedPCDClusterCount": pcd_cluster_count,
    "LoadedPCDClusterMissingActiveMembers": sorted(
        row["SnomedConceptId"]
        for row in pad_concepts
        if not row["InLoadedPCDCluster"]
    ),
    "MapSourceFile": str(MAP_DB),
    "MapType": map_version_row["MAP"],
    "MapReleaseDate": str(map_version_row["RELEASEDATE"]),
    "MapBuildDate": str(map_version_row["BUILDDATE"]),
    "MapSnapshotDate": str(map_version_row["SNAPSHOTDATE"]),
    "V32IncludedReadCodeCount": len(included_v32_codes),
    "V32ExcludedReadCodeCount": sum(
        row["IncludedInV32"] == "No" for row in v32_candidates
    ),
    "DirectBackMappedConceptCount": len(direct_mapped_concepts),
    "ConceptHistoryBackMappedConceptCount": len(
        concept_history_mapped_concepts
    ),
    "ConceptHistoryOnlyBackMappedConceptCount": len(
        concept_history_mapped_concepts - direct_mapped_concepts
    ),
    "DescriptionHistoryBackMappedConceptCount": len(
        description_history_mapped_concepts
    ),
    "DescriptionHistoryOnlyBackMappedConceptCount": len(
        description_history_mapped_concepts
        - direct_mapped_concepts
        - concept_history_mapped_concepts
    ),
    "HistoricallyBackMappedConceptCount": len(historically_mapped_concepts),
    "HistoricalOnlyBackMappedConceptCount": len(
        historically_mapped_concepts - direct_mapped_concepts
    ),
    "BackMappedConceptCount": len(all_mapped_concepts),
    "UnmappedConceptCount": len(all_pad_concepts - all_mapped_concepts),
    "MembersWithReachableHistoricalAssociations": sum(
        bool(paths) for paths in concept_paths_by_concept.values()
    ),
    "MembersWithReachableDescriptionHistory": sum(
        bool(paths) for paths in description_paths_by_concept.values()
    ),
    "MaximumHistoricalAssociationDepth": max_history_depth,
    "BackMappedUniqueReadCodeCount": len(backmapped_read_codes),
    "OverlapReadCodeCount": len(included_v32_codes & backmapped_read_codes),
    "V32OnlyReadCodeCount": len(included_v32_codes - backmapped_read_codes),
    "BackMapOnlyReadCodeCount": len(backmapped_read_codes - included_v32_codes),
}


payload = {
    "metadata": metadata,
    "contract_rules": [
        {
            "ContractExpression": "G73..",
            "ContractTerm": "Other peripheral vascular disease",
            "Action": "Include",
            "AppliedInterpretation": "Include this exact Read v2 code only; no percent wildcard is present",
        },
        {
            "ContractExpression": "G734.",
            "ContractTerm": "Peripheral arterial disease",
            "Action": "Include",
            "AppliedInterpretation": "Include this exact Read v2 code only",
        },
        {
            "ContractExpression": "G73y.",
            "ContractTerm": "Other specified peripheral vascular disease",
            "Action": "Include",
            "AppliedInterpretation": "Include this exact Read v2 code only; no percent wildcard is present",
        },
        {
            "ContractExpression": "G73z%",
            "ContractTerm": "Peripheral vascular disease NOS branch",
            "Action": "Include",
            "AppliedInterpretation": "Include the G73z branch, subject to the explicit G73z1 exclusion",
        },
        {
            "ContractExpression": "G73z1",
            "ContractTerm": "Spasm of peripheral artery",
            "Action": "Exclude",
            "AppliedInterpretation": "Explicit exclusion; takes precedence over parent inclusion",
        },
        {
            "ContractExpression": "Gyu74",
            "ContractTerm": "[X]Other specified peripheral vascular diseases",
            "Action": "Include",
            "AppliedInterpretation": "Include exact Read v2 code",
        },
    ],
    "v32_candidates": v32_candidates,
    "pad_concepts": pad_concepts,
    "mapping_rows": mapping_rows,
}

OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(metadata, indent=2))
