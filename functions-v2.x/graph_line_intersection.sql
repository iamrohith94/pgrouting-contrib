/*
DROP FUNCTION pgr_GraphLineIntersections(TEXT, TEXT); 
CREATE OR REPLACE FUNCTION pgr_GraphLineIntersections(
    graph_table TEXT, lines_table TEXT)
RETURNS TABLE(id BIGINT, isLine BOOLEAN, result_geom GEOMETRY) AS
$body$
DECLARE
loop_sql TEXT;
blade_sql TEXT;
edge RECORD;
blade GEOMETRY;
blade_geom GEOMETRY;
BEGIN
    -- Splitting lines
    loop_sql := 'SELECT id, the_geom FROM %s';
    FOR edge in EXECUTE format(loop_sql, lines_table)
    LOOP
        id := edge.id;
        isLine := TRUE;
        blade_sql := 'SELECT ST_Collect(ST_Intersection(the_geom, '|| quote_literal(edge.the_geom::TEXT) ||')) FROM ' || graph_table || ' WHERE ST_Crosses(the_geom, '|| quote_literal(edge.the_geom::TEXT) || ')';
        EXECUTE blade_sql INTO blade_geom;
        IF blade_geom IS NOT NULL THEN
            result_geom := edge.the_geom;           
            -- Loop on all the points in the blade
            FOR blade IN SELECT (ST_Dump(ST_CollectionExtract(blade_geom, 1))).geom
            LOOP
                -- keep splitting the previous result
                result_geom := ST_CollectionExtract(ST_Split(result_geom, blade), 2);
            END LOOP;
            RETURN NEXT;
        END IF;
    END LOOP;

    -- Splitting graph edges
    FOR edge in EXECUTE format(loop_sql, graph_table)
    LOOP
        id := edge.id;
        isLine := FALSE;
        blade_sql := 'SELECT ST_Collect(ST_Intersection(the_geom, '|| quote_literal(edge.the_geom::TEXT) ||')) FROM ' || lines_table || ' WHERE ST_Crosses(the_geom, '|| quote_literal(edge.the_geom::TEXT) || ')';
        EXECUTE blade_sql INTO blade_geom;
        IF blade_geom IS NOT NULL THEN
            result_geom := edge.the_geom;           
            -- Loop on all the points in the blade
            FOR blade IN SELECT (ST_Dump(ST_CollectionExtract(blade_geom, 1))).geom
            LOOP
                -- keep splitting the previous result
                result_geom := ST_CollectionExtract(ST_Split(result_geom, blade), 2);
            END LOOP;
            RETURN NEXT;
        END IF;
    END LOOP;

END
$body$ language plpgsql volatile;




DROP FUNCTION pgr_GraphLineIntersection(TEXT, GEOMETRY); 
CREATE OR REPLACE FUNCTION pgr_GraphLineIntersection(
    graph_table TEXT, line_geom TEXT)
RETURNS TABLE(id BIGINT, isLine BOOLEAN, result_geom GEOMETRY) AS
$body$
DECLARE
loop_sql TEXT;
blade_sql TEXT;
edge RECORD;
blade GEOMETRY;
blade_geom GEOMETRY;
BEGIN
    loop_sql := 'SELECT id, the_geom FROM %s';
    id := -1;
    isLine := TRUE;
    blade_sql := 'SELECT ST_Collect(ST_Intersection(the_geom, '|| quote_literal(line_geom) ||')) FROM ' || graph_table || ' WHERE ST_Crosses(the_geom, '|| quote_literal(line_geom) || ')';
    -- RAISE NOTICE '%', blade_sql;
    EXECUTE blade_sql INTO blade_geom;
    IF blade_geom IS NOT NULL THEN
        result_geom := line_geom;           
        -- Loop on all the points in the blade
        FOR blade IN SELECT (ST_Dump(ST_CollectionExtract(blade_geom, 1))).geom
        LOOP
            -- keep splitting the previous result
            result_geom := ST_CollectionExtract(ST_Split(result_geom, blade), 2);
        END LOOP;
        RETURN NEXT;
    END IF;

    FOR edge in EXECUTE format(loop_sql, graph_table)
    LOOP
        id := edge.id;
        isLine := FALSE;
        blade_sql := 'SELECT ST_Collect(ST_Intersection('|| quote_literal(line_geom) ||', '|| quote_literal(edge.the_geom::TEXT) ||')) WHERE ST_Crosses('||quote_literal(line_geom) || ', '|| quote_literal(edge.the_geom::TEXT) ||')';
        EXECUTE blade_sql INTO blade_geom;
        IF blade_geom IS NOT NULL THEN
            result_geom := edge.the_geom;           
            -- Loop on all the points in the blade
            FOR blade IN SELECT (ST_Dump(ST_CollectionExtract(blade_geom, 1))).geom
            LOOP
                -- keep splitting the previous result
                result_geom := ST_CollectionExtract(ST_Split(result_geom, blade), 2);
            END LOOP;
            RETURN NEXT;
        END IF;
    END LOOP;

END
$body$ language plpgsql volatile;
*/


DROP FUNCTION pgr_EdgeLineIntersection(TEXT, TEXT); 
CREATE OR REPLACE FUNCTION pgr_EdgeLineIntersection(
    edge_geom TEXT, line_geom TEXT)
RETURNS TABLE(intersection_geom GEOMETRY) AS
$body$
DECLARE
edge RECORD;
intersection_sql TEXT;
BEGIN
    intersection_sql := 'SELECT ST_Collect(ST_Intersection('|| quote_literal(line_geom) ||', '|| quote_literal(edge_geom) ||')) WHERE ST_Crosses('||quote_literal(line_geom) || ', '|| quote_literal(edge_geom) ||')';
    EXECUTE intersection_sql INTO intersection_geom;
    RETURN NEXT;
END
$body$ language plpgsql volatile;

DROP FUNCTION pgr_EdgeLinesIntersection(TEXT, TEXT); 
CREATE OR REPLACE FUNCTION pgr_EdgeLinesIntersection(
    edge_geom TEXT, lines_sql TEXT)
RETURNS TABLE(intersections_geom GEOMETRY) AS
$body$
DECLARE
lin RECORD;
intersection_sql TEXT;
collection_sql TEXT;
temp_geom GEOMETRY;
BEGIN
    intersection_sql := 'SELECT intersection_geom FROM 
    pgr_EdgeLineIntersection(%s, %s)';
    collection_sql := 'SELECT ST_Collect(%s, %s)';
    intersections_geom := NULL;
    FOR lin in EXECUTE lines_sql
    LOOP
        EXECUTE format(intersection_sql, quote_literal(edge_geom), quote_literal(lin.the_geom::TEXT)) INTO temp_geom;
        IF temp_geom IS NOT NULL THEN
            IF intersections_geom IS NULL THEN
                intersections_geom := temp_geom;
            ELSE
                EXECUTE format(collection_sql, quote_literal(temp_geom::TEXT), quote_literal(intersections_geom::TEXT)) INTO intersections_geom;
            END IF;
            --RAISE NOTICE 'yoo %', intersections_geom;
        END IF;
    END LOOP;
    RETURN NEXT;
END
$body$ language plpgsql volatile;

DROP FUNCTION pgr_GraphLineIntersection(TEXT, TEXT); 
CREATE OR REPLACE FUNCTION pgr_GraphLineIntersection(
    graph_sql TEXT, line_geom TEXT)
RETURNS TABLE(id BIGINT, intersections_geom GEOMETRY) AS
$body$
DECLARE
edge RECORD;
intersection_sql TEXT;
BEGIN
    intersection_sql := 'SELECT intersection_geom FROM 
    pgr_EdgeLineIntersection(%s, %s)';
    FOR edge in EXECUTE graph_sql
    LOOP
        id := edge.id;
        EXECUTE format(intersection_sql, quote_literal(edge.the_geom::TEXT), quote_literal(line_geom::TEXT)) INTO intersections_geom;
        IF intersections_geom IS NOT NULL THEN
            RETURN NEXT;
        END IF;
    END LOOP;

END
$body$ language plpgsql volatile;


DROP FUNCTION pgr_GraphLinesIntersection(TEXT, TEXT); 
CREATE OR REPLACE FUNCTION pgr_GraphLinesIntersection(
    graph_sql TEXT, lines_sql TEXT)
RETURNS TABLE(id BIGINT, intersections_geom GEOMETRY) AS
$body$
DECLARE
intersection_sql TEXT;
collection_sql TEXT;
temp_geom GEOMETRY;
edge RECORD;
BEGIN
    intersection_sql := 'SELECT intersections_geom FROM 
    pgr_EdgeLinesIntersection(%s, %s)';
    -- Splitting graph edges
    FOR edge in EXECUTE graph_sql
    LOOP
        id := edge.id;
        EXECUTE format(intersection_sql, quote_literal(edge.the_geom::TEXT), quote_literal(lines_sql)) INTO intersections_geom;
        IF intersections_geom IS NOT NULL THEN
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$body$ language plpgsql volatile;

DROP FUNCTION pgr_SplitGraph(TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION pgr_SplitGraph(edge_table TEXT, 
    vertex_table TEXT, split_sql TEXT)
RETURNS void AS
$body$
DECLARE
intersection_sql TEXT;
temp_geom GEOMETRY;
edge RECORD;
BEGIN
    -- Splitting graph edges
    FOR edge in EXECUTE split_sql
    LOOP
        
    END LOOP;

END
$body$ language plpgsql volatile;