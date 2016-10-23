CREATE OR REPLACE PACKAGE markdown_reporter AUTHID CURRENT_USER IS

  g_print_server_url VARCHAR2(100); -- see package body initialization
  g_max_rows_util_query2mdtab CONSTANT INTEGER := 100;

  g_max_rows_util_query2csv CONSTANT INTEGER := 1000;

  -----------------------------------------------------------------------------
  TYPE ref_cursor_type IS REF CURSOR;

  -----------------------------------------------------------------------------
  FUNCTION util_url_encode(p_data IN VARCHAR2) RETURN VARCHAR2;

  -----------------------------------------------------------------------------
  PROCEDURE util_clob_append(p_clob     IN OUT NOCOPY CLOB
                            ,p_cache    IN OUT NOCOPY VARCHAR2
                            ,p_text     IN VARCHAR2
                            ,p_finalize IN BOOLEAN DEFAULT FALSE);

  -----------------------------------------------------------------------------
  FUNCTION util_query2mdtab(p_query           IN VARCHAR2
                           ,p_nls_date_format VARCHAR2 DEFAULT 'YYYY-MM-DD HH24:MI:SS'
                           ,p_debug           VARCHAR2 DEFAULT NULL)
    RETURN CLOB;

  -----------------------------------------------------------------------------
  FUNCTION util_query2csv(p_query           IN VARCHAR2
                         ,p_nls_date_format VARCHAR2 DEFAULT 'YYYY-MM-DD HH24:MI:SS'
                         ,p_debug           VARCHAR2 DEFAULT NULL)
    RETURN CLOB;

  -----------------------------------------------------------------------------
  FUNCTION util_unibar(p_value                  IN NUMBER
                      ,p_scale                  IN NUMBER DEFAULT 1
                      ,p_width_block_characters IN NUMBER DEFAULT 25
                      ,p_fill_scale             IN NUMBER DEFAULT 0)
    RETURN VARCHAR2 DETERMINISTIC;

  -----------------------------------------------------------------------------
  FUNCTION preprocess_data(p_markdown CLOB, p_debug VARCHAR2 DEFAULT NULL)
    RETURN CLOB;

  -----------------------------------------------------------------------------
  FUNCTION convert_document(p_markdown CLOB
                           ,p_format   VARCHAR2 DEFAULT 'html'
                           ,p_options  VARCHAR2 DEFAULT NULL
                           ,p_debug    VARCHAR2 DEFAULT NULL) RETURN BLOB;

-----------------------------------------------------------------------------
END markdown_reporter;
/
