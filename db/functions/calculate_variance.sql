-- PL/pgSQL function for variance calculation

CREATE OR REPLACE FUNCTION array_variance(arr NUMERIC[])
RETURNS NUMERIC AS $$
DECLARE
    arr_len INTEGER;
    mean_val NUMERIC;
    sum_sq NUMERIC;
    val NUMERIC;
BEGIN
    arr_len := array_length(arr, 1);
    IF arr_len IS NULL OR arr_len = 0 THEN
        RETURN NULL;
    END IF;
    
    -- Calculate mean
    SELECT AVG(val) INTO mean_val FROM unnest(arr) AS val;
    
    -- Calculate sum of squared differences
    sum_sq := 0;
    FOREACH val IN ARRAY arr
    LOOP
        sum_sq := sum_sq + (val - mean_val) * (val - mean_val);
    END LOOP;
    
    RETURN sum_sq / arr_len;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Wrapper for JSON array variance
CREATE OR REPLACE FUNCTION json_array_variance(data JSONB)
RETURNS NUMERIC AS $$
DECLARE
    vals NUMERIC[];
BEGIN
    SELECT ARRAY(SELECT jsonb_array_elements_text(data)::NUMERIC) INTO vals;
    RETURN array_variance(vals);
END;
$$ LANGUAGE plpgsql IMMUTABLE;
