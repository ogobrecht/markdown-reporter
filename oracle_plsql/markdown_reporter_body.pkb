CREATE OR REPLACE PACKAGE BODY markdown_reporter IS

  ----------------------------------------------------------------------------- 
  FUNCTION util_url_encode(p_data IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN utl_url.escape(p_data, TRUE, 'UTF-8');
  END util_url_encode;

  ----------------------------------------------------------------------------- 
  PROCEDURE util_clob_append(p_clob     IN OUT NOCOPY CLOB
                            ,p_cache    IN OUT NOCOPY VARCHAR2
                            ,p_text     IN VARCHAR2
                            ,p_finalize IN BOOLEAN DEFAULT FALSE) IS
  BEGIN
    p_cache := p_cache || p_text;
    IF p_finalize
    THEN
      IF p_clob IS NULL
      THEN
        p_clob := p_cache;
      ELSE
        dbms_lob.append(p_clob, p_cache);
      END IF;
      p_cache := NULL;
    END IF;
  EXCEPTION
    WHEN value_error THEN
      IF p_clob IS NULL
      THEN
        p_clob := p_cache;
      ELSE
        dbms_lob.append(p_clob, p_cache);
      END IF;
      p_cache := p_text;
      IF p_finalize
      THEN
        dbms_lob.append(p_clob, p_cache);
        p_cache := NULL;
      END IF;
  END util_clob_append;

  ----------------------------------------------------------------------------- 
  FUNCTION util_query2mdtab(p_query           IN VARCHAR2
                           ,p_nls_date_format VARCHAR2 DEFAULT 'YYYY-MM-DD HH24:MI:SS')
    RETURN CLOB IS
    v_return                 CLOB;
    v_return_cache           VARCHAR2(32767);
    v_cursor                 INTEGER;
    v_desc_tab               dbms_sql.desc_tab;
    v_status                 INTEGER;
    v_col_cnt                INTEGER := 0;
    v_col_val                VARCHAR2(4000);
    v_row_cnt                INTEGER := 0;
    v_nls_date_format        VARCHAR2(30);
    v_nls_numeric_characters VARCHAR2(10);
    v_pattern                VARCHAR2(50) := '\s*;\s*(?:\/\*.*\*\/)*\s*';
  BEGIN
    IF p_query IS NOT NULL
    THEN
      -----------------------------------------------------------------------
      -- initalization
      dbms_lob.createtemporary(v_return, TRUE);
      -- backup nls_date_format and nls_numeric_characters
      SELECT VALUE
        INTO v_nls_date_format
        FROM nls_session_parameters
       WHERE parameter = 'NLS_DATE_FORMAT';
      SELECT VALUE
        INTO v_nls_numeric_characters
        FROM nls_session_parameters
       WHERE parameter = 'NLS_NUMERIC_CHARACTERS';
      -- set session for implicit date to varchar conversions in the cursor data
      EXECUTE IMMEDIATE 'alter session set nls_date_format=''' ||
                        p_nls_date_format || '''';
      EXECUTE IMMEDIATE 'alter session set nls_numeric_characters=''.,''';
      v_cursor := dbms_sql.open_cursor;
      dbms_sql.parse(v_cursor
                    ,regexp_replace(p_query, v_pattern, NULL)
                    ,dbms_sql.native);
      dbms_sql.describe_columns(v_cursor, v_col_cnt, v_desc_tab);
      -----------------------------------------------------------------------
      -- process header (and column definition for later use)
      util_clob_append(v_return, v_return_cache, '|');
      FOR i IN 1 .. v_col_cnt
      LOOP
        util_clob_append(v_return
                        ,v_return_cache
                        ,v_desc_tab(i).col_name || '|');
        dbms_sql.define_column(v_cursor, i, v_col_val, 4000);
      END LOOP;
      util_clob_append(v_return, v_return_cache, chr(10) || '|');
      FOR i IN 1 .. v_col_cnt
      LOOP
        util_clob_append(v_return
                        ,v_return_cache
                        ,CASE
                           WHEN v_desc_tab(i).col_type = dbms_types.typecode_number THEN
                            '--:|'
                           ELSE
                            '---|'
                         END);
      END LOOP;
      -----------------------------------------------------------------------
      -- process data
      v_status := dbms_sql.execute(v_cursor);
      WHILE dbms_sql.fetch_rows(v_cursor) > 0
      LOOP
        util_clob_append(v_return, v_return_cache, chr(10) || '|');
        IF v_row_cnt < g_max_rows_util_query2mdtab
        THEN
          -- normal processing: |val|val|val|val|val|
          FOR i IN 1 .. v_col_cnt
          LOOP
            dbms_sql.column_value(v_cursor, i, v_col_val);
            util_clob_append(v_return, v_return_cache, v_col_val || '|');
          END LOOP;
        ELSE
          -- last row, if resultset is greater then g_max_rows_util_query2mdtab
          -- indicating, that more rows exists: |...|||||
          FOR i IN 1 .. v_col_cnt
          LOOP
            util_clob_append(v_return
                            ,v_return_cache
                            ,CASE
                               WHEN i = 1 THEN
                                '...|'
                               ELSE
                                '|'
                             END);
          END LOOP;
          EXIT;
        END IF;
        v_row_cnt := v_row_cnt + 1;
      END LOOP;
      -----------------------------------------------------------------------
      -- post processing
      -- flush clob cache
      util_clob_append(p_clob     => v_return
                      ,p_cache    => v_return_cache
                      ,p_text     => NULL
                      ,p_finalize => TRUE);
      dbms_sql.close_cursor(v_cursor);
      -- reset session to original nls_date_format
      EXECUTE IMMEDIATE 'alter session set nls_date_format=''' ||
                        v_nls_date_format || '''';
    END IF;
    RETURN v_return;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_sql.close_cursor(v_cursor);
      dbms_lob.freetemporary(v_return);
      EXECUTE IMMEDIATE 'alter session set nls_date_format=''' ||
                        v_nls_date_format || '''';
      EXECUTE IMMEDIATE 'alter session set nls_numeric_characters=''' ||
                        v_nls_numeric_characters || '''';
      RAISE;
  END util_query2mdtab;

  ----------------------------------------------------------------------------- 
  FUNCTION util_query2csv(p_query           IN VARCHAR2
                         ,p_nls_date_format VARCHAR2 DEFAULT 'YYYY-MM-DD HH24:MI:SS')
    RETURN CLOB IS
    v_return                 CLOB;
    v_return_cache           VARCHAR2(32767);
    v_cursor                 INTEGER;
    v_desc_tab               dbms_sql.desc_tab;
    v_status                 INTEGER;
    v_col_cnt                INTEGER := 0;
    v_col_val                VARCHAR2(4000);
    v_row_cnt                INTEGER := 0;
    v_nls_date_format        VARCHAR2(30);
    v_nls_numeric_characters VARCHAR2(10);
    v_pattern                VARCHAR2(50) := '\s*;\s*(?:\/\*.*\*\/)*\s*';
  BEGIN
    IF p_query IS NOT NULL
    THEN
      -----------------------------------------------------------------------
      -- initalization
      dbms_lob.createtemporary(v_return, TRUE);
      -- backup nls_date_format and nls_numeric_characters
      SELECT VALUE
        INTO v_nls_date_format
        FROM nls_session_parameters
       WHERE parameter = 'NLS_DATE_FORMAT';
      SELECT VALUE
        INTO v_nls_numeric_characters
        FROM nls_session_parameters
       WHERE parameter = 'NLS_NUMERIC_CHARACTERS';
      -- set session for implicit conversions in the cursor data
      EXECUTE IMMEDIATE 'alter session set nls_date_format=''' ||
                        p_nls_date_format || '''';
      EXECUTE IMMEDIATE 'alter session set nls_numeric_characters=''.,''';
      v_cursor := dbms_sql.open_cursor;
      dbms_sql.parse(v_cursor
                    ,regexp_replace(p_query, v_pattern, NULL)
                    ,dbms_sql.native);
      dbms_sql.describe_columns(v_cursor, v_col_cnt, v_desc_tab);
      -----------------------------------------------------------------------
      -- process header (and column definition for later use)
      FOR i IN 1 .. v_col_cnt
      LOOP
        util_clob_append(v_return
                        ,v_return_cache
                        ,'"' || REPLACE(v_desc_tab(i).col_name, '"', '""') || '"' || CASE
                           WHEN i < v_col_cnt THEN
                            ','
                           ELSE
                            chr(10)
                         END);
        dbms_sql.define_column(v_cursor, i, v_col_val, 4000);
      END LOOP;
      -----------------------------------------------------------------------
      -- process data
      v_status := dbms_sql.execute(v_cursor);
      WHILE dbms_sql.fetch_rows(v_cursor) > 0
      LOOP
        IF v_row_cnt < g_max_rows_util_query2csv
        THEN
          FOR i IN 1 .. v_col_cnt
          LOOP
            dbms_sql.column_value(v_cursor, i, v_col_val);
            util_clob_append(v_return
                            ,v_return_cache
                            ,CASE WHEN v_col_val IS NOT NULL THEN
                             '"' || REPLACE(TRIM(v_col_val), '"', '""') || '"' ELSE NULL
                             END || CASE WHEN i < v_col_cnt THEN ',' ELSE
                             chr(10) END);
          END LOOP;
        END IF;
        v_row_cnt := v_row_cnt + 1;
      END LOOP;
      -----------------------------------------------------------------------
      -- post processing
      -- flush clob cache
      util_clob_append(p_clob     => v_return
                      ,p_cache    => v_return_cache
                      ,p_text     => NULL
                      ,p_finalize => TRUE);
      dbms_sql.close_cursor(v_cursor);
      -- reset session to original nls_date_format
      EXECUTE IMMEDIATE 'alter session set nls_date_format=''' ||
                        v_nls_date_format || '''';
      EXECUTE IMMEDIATE 'alter session set nls_numeric_characters=''' ||
                        v_nls_numeric_characters || '''';
    END IF;
    RETURN v_return;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_sql.close_cursor(v_cursor);
      dbms_lob.freetemporary(v_return);
      EXECUTE IMMEDIATE 'alter session set nls_date_format=''' ||
                        v_nls_date_format || '''';
      RAISE;
  END util_query2csv;

  ----------------------------------------------------------------------------- 
  FUNCTION preprocess_data(p_markdown CLOB) RETURN CLOB IS
    v_markdown               CLOB;
    v_pattern                VARCHAR2(100) := '`{3,}\s*(\{{1}[^}]*\.sql{1}[^}]*\.(chart|table){1}[^}]*\}{1})([^`]*)`{3,}'; -- confused by the regex? try it out on http://regexr.com
    v_code_block             VARCHAR2(32767);
    v_fenced_code_attributes VARCHAR2(1000); -- something like this: { #testID .sql .chart sampleAttribute="100" }, see also: http://pandoc.org/README.html#fenced-code-blocks
    v_target_type            VARCHAR2(100); -- table or chart
    v_select_statement       VARCHAR2(32767); -- our select statement
    v_occurence              PLS_INTEGER;
    v_no_replaced_md_tables  PLS_INTEGER := 0; -- after query is replaced by markdown table our pattern finds can't find this
  BEGIN
    dbms_lob.createtemporary(v_markdown, TRUE);
    --------------------------------------------------------------------------
    -- process inline reports in markdown code blocks
    v_markdown := p_markdown;
    FOR i IN 1 .. regexp_count(v_markdown, v_pattern)
    LOOP
      v_occurence              := i - v_no_replaced_md_tables;
      v_code_block             := regexp_substr(v_markdown
                                               ,v_pattern
                                               ,1
                                               ,v_occurence);
      v_fenced_code_attributes := regexp_substr(v_markdown
                                               ,v_pattern
                                               ,1
                                               ,v_occurence
                                               ,'i'
                                               ,1);
      v_target_type            := lower(regexp_substr(v_markdown
                                                     ,v_pattern
                                                     ,1
                                                     ,v_occurence
                                                     ,'i'
                                                     ,2));
      v_select_statement       := regexp_substr(v_markdown
                                               ,v_pattern
                                               ,1
                                               ,v_occurence
                                               ,'i'
                                               ,3);
      v_markdown               := regexp_replace(v_markdown
                                                ,v_pattern
                                                ,CASE lower(v_target_type)
                                                   WHEN 'table' THEN
                                                    chr(10) ||
                                                    util_query2mdtab(v_select_statement) ||
                                                    chr(10)
                                                   WHEN 'chart' THEN
                                                    '``` ' ||
                                                    v_fenced_code_attributes ||
                                                    chr(10) ||
                                                    util_query2csv(v_select_statement) ||
                                                    '```'
                                                 END
                                                ,1
                                                ,v_occurence);
      IF v_target_type = 'table'
      THEN
        v_no_replaced_md_tables := v_no_replaced_md_tables + 1;
      END IF;
    END LOOP;
    RETURN v_markdown;
  END preprocess_data;

  ----------------------------------------------------------------------------- 
  FUNCTION convert_document(p_markdown CLOB
                           ,p_format   VARCHAR2 DEFAULT 'html'
                           ,p_options  VARCHAR2 DEFAULT NULL) RETURN BLOB IS
    v_request        utl_http.req;
    v_response       utl_http.resp;
    v_post_data      CLOB;
    v_return         BLOB;
    v_response_chunk RAW(32767);
    v_length         PLS_INTEGER;
    v_amount         PLS_INTEGER;
    v_offset         PLS_INTEGER;
  BEGIN
    --------------------------------------------------------------------------
    -- initialization
    IF g_print_server_url IS NULL
    THEN
      raise_application_error(-20000
                             ,'Package ' || $$PLSQL_UNIT ||
                              ': unknown printserver - please review the package initialization code');
    END IF;
    dbms_lob.createtemporary(v_post_data, TRUE);
    dbms_lob.createtemporary(v_return, TRUE);
    utl_http.set_body_charset('UTF-8');
    utl_http.set_response_error_check(FALSE);
    utl_http.set_detailed_excp_support(FALSE);
    --------------------------------------------------------------------------
    -- create post body
    dbms_lob.append(v_post_data
                   ,'filename=dummy&format=' || util_url_encode(p_format) ||
                    '&options=' || util_url_encode(p_options) ||
                    '&markdown=');
    v_length := dbms_lob.getlength(p_markdown);
    v_amount := 20000; -- we need some reserve for the url encoding
    v_offset := 1;
    WHILE v_offset <= v_length
    LOOP
      v_amount := least(v_amount, v_length - (v_offset - 1));
      dbms_lob.append(v_post_data
                     ,util_url_encode(dbms_lob.substr(lob_loc => p_markdown
                                                     ,amount  => v_amount
                                                     ,offset  => v_offset)));
      v_offset := v_offset + v_amount;
    END LOOP;
    --------------------------------------------------------------------------
    -- do the HTTP request
    v_length  := dbms_lob.getlength(v_post_data);
    v_amount  := 32000; --inital chunk size
    v_offset  := 1;
    v_request := utl_http.begin_request(url          => g_print_server_url
                                       ,method       => 'POST'
                                       ,http_version => 'HTTP/1.1');
    utl_http.set_header(r     => v_request
                       ,NAME  => 'Content-Type'
                       ,VALUE => 'application/x-www-form-urlencoded;charset=UTF-8');
    utl_http.set_header(r     => v_request
                       ,NAME  => 'Content-Length'
                       ,VALUE => v_length);
    -- setting chunked transfer and sending only one chunk leads to errors, so we check here for chunking
    IF v_length > v_amount
    THEN
      utl_http.set_header(v_request, 'Transfer-Encoding', 'chunked');
    END IF;
    -- send the data
    WHILE v_offset <= v_length
    LOOP
      v_amount := least(v_amount, v_length - (v_offset - 1));
      dbms_output.put_line('v_amount: ' || v_amount);
      dbms_output.put_line('v_length: ' || v_length);
      dbms_output.put_line('v_offset: ' || v_offset);
      utl_http.write_text(r    => v_request
                         ,data => dbms_lob.substr(lob_loc => v_post_data
                                                 ,amount  => v_amount
                                                 ,offset  => v_offset));
      v_offset := v_offset + v_amount;
    END LOOP;
    --------------------------------------------------------------------------
    -- get the response and copy it into the BLOB
    v_response := utl_http.get_response(v_request);
    BEGIN
      IF v_response.status_code != utl_http.http_ok
      THEN
        utl_http.read_raw(v_response, v_response_chunk, 32767);
        utl_http.end_response(v_response);
        raise_application_error(-20000
                               ,'Package ' || $$PLSQL_UNIT ||
                                ': Unsuccessful HTTP call. Status code ' ||
                                v_response.status_code || ' (' ||
                                lower(v_response.reason_phrase) || '). ' ||
                                chr(10) || 'Backend error message: ' ||
                                utl_raw.cast_to_varchar2(v_response_chunk));
      ELSE
        LOOP
          utl_http.read_raw(v_response, v_response_chunk, 32767);
          dbms_lob.writeappend(v_return
                              ,utl_raw.length(v_response_chunk)
                              ,v_response_chunk);
        END LOOP;
      END IF;
    EXCEPTION
      WHEN utl_http.end_of_body THEN
        utl_http.end_response(v_response);
    END;
    dbms_lob.freetemporary(v_post_data);
    RETURN v_return;
  END convert_document;

-----------------------------------------------------------------------------
-- PACKAGE INITIALIZATION
BEGIN
  --> modify this to your needs - here a possible example:
  /* 
  IF tools.environment.get_system_role != 'PROD'
  THEN
    g_print_server_url := 'http://apexdev.mycompany.tld/pandoc';
  ELSE
    g_print_server_url := 'http://apex.mycompany.tld/pandoc';
  END IF;
  */
  g_print_server_url := 'http://192.168.56.1:3000/pandoc';
END markdown_reporter;
/
