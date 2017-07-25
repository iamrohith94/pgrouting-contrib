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
