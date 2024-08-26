CREATE OR REPLACE PROCEDURE sp_dynamic_inserts(p_num_records IN NUMBER, tab_name IN VARCHAR) IS
        v_sql VARCHAR2(30000);
        col_list VARCHAR2(10000);
        col_values VARCHAR2(30000);
        TYPE pk_arr IS TABLE OF VARCHAR2(100);
        pk pk_arr;
        FLAG BOOLEAN := FALSE;
        
        CURSOR col_cur IS
        SELECT column_name, data_type, data_length, data_precision
        FROM all_tab_columns
        WHERE table_name = tab_name order by column_id;
        
        --col_rec col_cur%ROWTYPE;
BEGIN
        SELECT LISTAGG(column_name, ', ') WITHIN GROUP (ORDER BY column_id) INTO col_list
        FROM all_tab_columns WHERE table_name=tab_name;
        
        --dbms_output.put_line(col_list); 
        
        SELECT column_name BULK COLLECT INTO pk FROM all_cons_columns WHERE constraint_name = (
        SELECT constraint_name FROM all_constraints 
        WHERE table_name = tab_name AND CONSTRAINT_TYPE = 'P');
        
        FOR i IN 1..p_num_records LOOP
            -- Generate random values
            FOR j IN col_cur LOOP
				FLAG := FALSE;
				--dbms_output.put_line(j.data_type);
				IF j.column_name MEMBER OF pk THEN
						col_values := col_values || dynamic_insert_pk.nextval || ', ';
						FLAG := TRUE;
				END IF;  
				IF FLAG<>TRUE THEN        
					IF j.data_type IN ('NUMBER', 'FLOAT', 'INTEGER') THEN 
						col_values := col_values || TRUNC(dbms_random.value(0,nvl(j.data_precision,j.data_length))) || ', ';
					ELSIF j.data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') THEN
						col_values := col_values || '''' || substr(dbms_random.string('x', j.data_length),1,10) || '''' || ', ';
					ELSIF j.data_type IN ('DATE') THEN
						col_values := col_values || '''' || TRUNC(TO_DATE('01-JAN-2000', 'DD-MON-YYYY') + DBMS_RANDOM.VALUE(0,1)*(SYSDATE - TO_DATE('01-JAN-2000', 'DD-MON-YYYY'))) || '''' || ', ';
					ELSIF j.data_type LIKE '%TIMESTAMP%' THEN
						col_values := col_values || '''' || TO_CHAR(systimestamp, 'DD-MM-YYYY HH12:MI:SS') || '''' || ', ';
					ELSE
						dbms_output.put_line('Invalid!!');
					END IF;
				END IF;    
			END LOOP;
            
            -- Remove the trailing comma
            col_values := SUBSTR(col_values, 1, LENGTH(col_values) - 2);
            --DBMS_OUTPUT.PUT_LINE(col_values);

            -- Build INSERT statement
            v_sql := 'INSERT INTO ' || tab_name || '(' || col_list || ') VALUES (' || col_values || ')';
            
            dbms_output.put_line(v_sql);
            
            -- Execute the INSERT statement
            EXECUTE IMMEDIATE v_sql;
            COMMIT;
            col_values := '';
        END LOOP; 
END;

EXEC sp_dynamic_inserts(100, 'SOURCE');
TRUNCATE TABLE CEN_ANA_MONTHLY_TRANS;
SELECT * FROM CEN_ANA_MONTHLY_TRANS; 