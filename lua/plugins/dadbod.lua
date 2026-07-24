-- In-editor SQL client: browse connections, run queries, schema-aware completion.
-- Define connections with :DBUIAddConnection (persisted) or vim.g.dbs below.
return {
  'kristijanhusak/vim-dadbod-ui',
  dependencies = {
    { 'tpope/vim-dadbod', lazy = true },
    { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
  },
  cmd = { 'DBUI', 'DBUIToggle', 'DBUIAddConnection', 'DBUIFindBuffer' },
  ft = { 'sql', 'mysql', 'plsql' },
  init = function()
    vim.g.db_ui_use_nerd_fonts = 1
    -- Prefer :DBUIAddConnection or env vars over hardcoding secrets. Example:
    -- vim.g.dbs = {
    --   { name = 'picky-local', url = 'postgres://postgres:postgres@localhost:5432/postgres' },
    --   { name = 'etk-oracle',  url = 'oracle://user:pass@host:1521/XEPDB1' },
    -- }
  end,
  config = function()
    -- Layer dadbod completion onto your existing cmp sources for SQL buffers.
    local ft = { 'sql', 'mysql', 'plsql' }
    local function dadbod_cmp()
      require('cmp').setup.buffer {
        sources = {
          { name = 'vim-dadbod-completion' },
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        },
      }
    end
    vim.api.nvim_create_autocmd('FileType', { pattern = ft, callback = dadbod_cmp })
    -- Wire the buffer that lazy-loaded this plugin (opening a SQL file).
    if vim.tbl_contains(ft, vim.bo.filetype) then
      dadbod_cmp()
    end
  end,
  keys = {
    { '<leader>u', '<cmd>DBUIToggle<CR>', desc = 'Toggle DB UI (dadbod)' },
  },
}
