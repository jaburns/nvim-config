-- =============================================================================
-- -----------------------------------------------------------------------------

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- -----------------------------------------------------------------------------

vim.g.mapleader = ' '
vim.opt.clipboard = 'unnamedplus'
vim.opt.completeopt = { 'menu', 'menuone' }

vim.opt.number = true
vim.opt.wrap = false
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.lazyredraw = true
vim.opt.splitbelow = true

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.tabstop = 4
vim.opt.scrolloff = 15

vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

local DEFAULT_PROJECT_PATH = '~/dev/sdl3game'

-- -----------------------------------------------------------------------------

local function switch_source_header()
  local f = vim.api.nvim_buf_get_name(0)
  local base, ext = f:match('(.+)%.(%w+)$')
  if not base then return end
  local candidates = {}
  if ext:match('c$') then
    candidates = { base..'.hpp', base..'.hh', base..'.h' }
  elseif ext:match('^h') then
    candidates = { base..'.cpp', base..'.cc', base..'.c' }
  else
    return
  end
  for _, cf in ipairs(candidates) do
    if vim.fn.filereadable(cf) == 1 then
      vim.cmd('edit ' .. cf)
      return
    end
  end
  vim.notify('No counterpart for ' .. f, vim.log.levels.WARN)
end

-- -----------------------------------------------------------------------------

local lsp_format_augrp = vim.api.nvim_create_augroup('LspFormatOnSave', {})

function on_lsp_attach(client, bufnr)
  local buf = { buffer = bufnr, silent = true, noremap = true }
  vim.keymap.set('n', '<leader>d', vim.lsp.buf.definition, buf)
  vim.keymap.set('n', '<leader>i', vim.lsp.buf.hover, buf)
  vim.keymap.set('i', '<c-i>', vim.lsp.buf.signature_help, buf)
  vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, buf)
  vim.keymap.set('n', '<leader>r', vim.lsp.buf.rename, buf)
  vim.keymap.set('n', '<leader>a', vim.lsp.buf.code_action, buf)
  vim.keymap.set('n', '<leader>o', switch_source_header, { buffer=true, silent=true })

  if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_clear_autocmds({ group = lsp_format_augrp, buffer = bufnr })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = lsp_format_augrp,
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 2000 })
      end,
    })
  end
end

vim.filetype.add { extension = { slang = 'slang' } }

-- =============================================================================

require('lazy').setup({
  { 'tpope/vim-sleuth' }, -- auto-determine indentation level
  { 'tpope/vim-fugitive' }, -- git integrations
  { 'djoshea/vim-autoread' }, -- auto-reload externally modified files
  { 'knsh14/vim-github-link' }, -- copy link to selection on github
  { 'mbbill/undotree' }, -- visualize/navigate undo tree
  { 'Iron-E/nvim-highlite' }, -- colors
-- -----------------------------------------------------------------------------
  {
    'stevearc/oil.nvim', -- filesystem browse/edit
    config = function()
      require('oil').setup({
          view_options = { show_hidden = true }
      })
      vim.keymap.set('n', '-', require('oil').open, { desc = 'open parent directory' })
      -- NB: backtick changes cwd to the directory open in oil
    end
  },
-- -----------------------------------------------------------------------------
  {
    'nvim-treesitter/nvim-treesitter', -- better highlighting and AST ops
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
        ensure_installed = { 'c', 'cpp', 'lua', 'vim', 'bash' },
        highlight = { enable = true },
        indent    = { enable = true },
      }
    end,
  },
-- -----------------------------------------------------------------------------
  {
    'neovim/nvim-lspconfig', -- language server protocol
    dependencies = { 'hrsh7th/cmp-nvim-lsp' },
    config = function()
      local lspconfig = require('lspconfig')

      require('lspconfig').clangd.setup {
        cmd = {
          '/opt/homebrew/opt/llvm/bin/clangd',
          '--background-index',
          '--enable-config',
          '--function-arg-placeholders=false',
        },
        root_dir = require('lspconfig.util').root_pattern('compile_commands.json', '.git'),
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
        on_attach = on_lsp_attach,
      }
      require('lspconfig').slangd.setup {
        cmd = { 'vendor/slang/slangd', '--stdio' },
        filetypes = { 'slang' },
        root_dir = require('lspconfig.util').root_pattern('compile_commands.json', '.git'),
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
        on_attach = on_lsp_attach,
      }
    end,
  },
-- -----------------------------------------------------------------------------
  {
    'nvim-telescope/telescope.nvim', -- fuzzy find
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('telescope').setup{}
      local tb = require('telescope.builtin')
      local map = vim.keymap.set
      local opts = { noremap=true, silent=true }
      map('n', '<c-p>', tb.find_files, opts)
      map('n', '<d-p>', tb.find_files, opts)
      map('n', '<leader>f', tb.lsp_references, opts)
      map('n', '<leader>F', tb.grep_string, opts)
      map('n', '<leader>G', tb.live_grep, opts)
      -- map('n', '<leader>fb', tb.buffers,       opts)  -- open buffers
      -- map('n', '<leader>fh', tb.help_tags,     opts)  -- help tags
    end,
  },
-- -----------------------------------------------------------------------------
  {
    'hrsh7th/nvim-cmp', -- autocomplete
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup {
        preselect = cmp.PreselectMode.Item,
        completion = {
          autocomplete = false ,
          completeopt = 'menu,menuone',
        },
        mapping = {
          ['<c-space>'] = cmp.mapping.complete(),
          ['<cr>'] = cmp.mapping.confirm { select = true },
          ['<tab>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
          ['<s-tab>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
          ['<esc>'] = cmp.mapping.abort(),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'buffer' },
        },
      }
    end,
  },
-- -----------------------------------------------------------------------------
  {
    'mfussenegger/nvim-dap', -- debug adapter protocol
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'nvim-neotest/nvim-nio',
    },
    config = function()
      local dap = require('dap')
      local dapui = require('dapui')

      dapui.setup {
        element_mappings = {
          stacks = {
            open = '<cr>',
            expand = 'o',
          }
        },
      }
      dap.adapters.lldb = {
        type = 'executable',
        command = '/opt/homebrew/opt/llvm/bin/lldb-dap',
        name = 'lldb'
      }
      dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
      dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
      dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

      local map = vim.keymap.set
      map('n', '<leader>z', dapui.toggle, { silent=true })
      -- map('n', '<F5>', function() dap.run(game_config) end, { silent=true })
      map('n', '<leader>b', dap.toggle_breakpoint, { silent=true })
      map('n', '<leader>B', function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, { silent=true })
    end,
  },
-- -----------------------------------------------------------------------------


{
  'stevearc/overseer.nvim', -- task runner (for build scripts etc)
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local overseer = require('overseer')
    overseer.setup()
    overseer.register_template({
      name = 'build',
      builder = function()
        return {
          cmd = { './build.sh' },
          components = { { 'on_output_quickfix', open = true }, 'default' }
        }
      end,
    })
    vim.keymap.set('n', '<f5>', function()
      overseer.run_template({ name = 'build' }, function(task, success)
        task:subscribe('on_complete', function(task, status)
          if status == 'SUCCESS' then
            vim.cmd('cclose')
            require('dap').run({
              type = 'lldb',
              request = 'launch',
              program = function() return vim.fn.getcwd() .. '/bin/game' end,
              cwd = '${workspaceFolder}',
              stopOnEntry = false,
              runInTerminal = true,
              args = {},
            })
          end
        end)
      end)
    end, {
      desc = 'Overseer: build → quickfix → launch DAP',
      silent = true,
    })
  end,
},

-- -----------------------------------------------------------------------------
})
-- =============================================================================

vim.o.guifont = 'Berkeley Mono:h12'

local appleInterfaceStyle = vim.fn.system({'defaults', 'read', '-g', 'AppleInterfaceStyle'})
if appleInterfaceStyle:find('Dark') then
  vim.cmd.colorscheme 'highlite-iceberg'
else
  vim.cmd.colorscheme 'shine'
end

if vim.g.neovide then
  vim.g.neovide_window_blurred = true
  vim.g.neovide_transparency = 0.9
  vim.defer_fn(function() vim.cmd('NeovideFocus') end, 25)
  vim.cmd('cd '..DEFAULT_PROJECT_PATH)
end

-- -----------------------------------------------------------------------------

-- enter to yank in visual mode
vim.keymap.set('v', '<cr>', 'y')

-- scroll movements
vim.keymap.set({'n','v'}, '<c-j>', '8j')
vim.keymap.set({'n','v'}, '<c-k>', '8k')
vim.keymap.set({'n','v'}, '<c-d>', '32jzz')
vim.keymap.set({'n','v'}, '<c-u>', '32kzz')

-- x for delete without register clobber
vim.keymap.set({'n','v'}, 'X', '"_d')
vim.keymap.set({'n','v'}, 'x', '"_x')

-- quick macro invocation with q register
vim.keymap.set('n', 'Q', '@q')

vim.keymap.set('v', 'p', '"_dP') -- visual mode paste without register clobber
vim.keymap.set('n', '<leader>p', 'viwP') -- paste over word
vim.keymap.set('i', '<d-v>', '<c-r>*') -- paste in insert mode with cmd+v
vim.keymap.set('c', '<d-v>', '<c-r>*') -- paste in command mode with cmd+v

-- split line
vim.keymap.set('n', 'K', 'i<cr><esc>')

-- keep selection during indentation
vim.keymap.set('v', '>', '>gv')
vim.keymap.set('v', '<', '<gv')

-- misc shortcuts
vim.keymap.set('n', '<leader>V', '<cmd>e ~/.config/nvim/init.lua<cr>')
vim.keymap.set('n', '<leader><leader>', '<c-^>')
vim.keymap.set('n', '<leader><cr>', '<cmd>nohlsearch<cr>')
vim.keymap.set('n', '<leader>y', '<cmd>nohlsearch<cr>')
vim.keymap.set('n', '<leader>u', '<cmd>UndotreeToggle<cr>')

-- git
vim.keymap.set('n', '<leader>gco', '<cmd>Git checkout<space>')
vim.keymap.set('n', '<leader>gB', '<cmd>Git branch<cr>')
vim.keymap.set('n', '<leader>gg', '<cmd>Ge :<cr>')
vim.keymap.set('n', '<leader>gd', '<cmd>Git diff<cr>')
vim.keymap.set('n', '<leader>gf', '<cmd>split<cr>:e term://git fetch --all<cr>i')
vim.keymap.set('n', '<leader>gu', '<cmd>split<cr>:e term://git pull --rebase<cr>i')
vim.keymap.set('n', '<leader>gU', '<cmd>split<cr>:e term://git pull<cr>i')
vim.keymap.set('n', '<leader>gp', '<cmd>split<cr>:e term://git push<cr>i')
vim.keymap.set('n', '<leader>gl', '<cmd>Git log --all --graph --decorate --oneline --date=relative --pretty=format:"%h %ad %an%d :: %s"<cr>')
vim.keymap.set('n', '<leader>gb', '<cmd>Git blame<cr>')

-- quickfix navigation
vim.keymap.set('n', '<leader>q', '<cmd>cclose<cr>')
vim.keymap.set('n', '<leader>J', '<cmd>cnext<cr>')
vim.keymap.set('n', '<leader>K', '<cmd>cprev<cr>')

-- terminal split
vim.keymap.set('n', '<c-`>', '<c-w>s:terminal<cr>i')

-- -----------------------------------------------------------------------------

-- don't auto-insert comments
vim.cmd('autocmd BufEnter * set formatoptions-=cro')
vim.cmd('autocmd BufEnter * setlocal formatoptions-=cro')

-- trim trailing whitespace
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  command = '%s/\\s\\+$//e',
})

-- shortcut to save all and then close hidden buffers
local function delete_hidden_buffers()
  local visible = {}
  for tp = 1, vim.fn.tabpagenr('$') do
    for _, buf in ipairs(vim.fn.tabpagebuflist(tp)) do
      visible[buf] = true
    end
  end
  for buf = 1, vim.fn.bufnr('$') do
    if vim.fn.buflisted(buf) == 1 and not visible[buf] then
      -- silent bdelete
      vim.cmd(('silent bdelete %d'):format(buf))
    end
  end
end
vim.keymap.set('n', '<leader>w', function()
  vim.cmd('wa')
  delete_hidden_buffers()
end, { noremap = true, silent = true })

-- -----------------------------------------------------------------------------
-- data breakpoints for lldb.
-- usage: :DapSetDataBreakpoint [0xADDRESS] [num bytes] [write/read/readWrite (default is write)]

local function init_dap_data_breakpoint()
  local M = {}
  M._bps = {}

  local function ensure_session()
    local dap = require('dap')
    local session = dap.session()
    if not session then
      vim.notify('nvim-dap: no active debug session', vim.log.levels.ERROR)
    end
    return session
  end

  function M.add(addr, size, access) -- access: 'write','read','readWrite'
    size = tonumber(size) or 1
    access = access or 'write'

    local a = type(addr) == 'number' and addr or tonumber(addr) or tonumber(addr:gsub('^0[xX]', ''), 16)
    if not a then
      vim.notify('DapSetDataBreakpoint: invalid address: '..tostring(addr), vim.log.levels.ERROR)
      return
    end

    -- de-duplicate by dataId
    local data_id = string.format('%x/%d', a, size)
    for _,bp in ipairs(M._bps) do
      if bp.dataId == data_id then
        vim.notify('Data breakpoint already set for 0x' ..string.format('%x',a)..' ('..size..' B)')
        return
      end
    end
    table.insert(M._bps, { dataId = data_id, accessType = access })

    local session = ensure_session(); if not session then return end
    session:request(
      'setDataBreakpoints',
      { breakpoints = M._bps },
      function(err, resp)
        if err then
          vim.notify('setDataBreakpoints: '..err.message, vim.log.levels.ERROR)
          return
        end
        local bp = resp.body and resp.body.breakpoints[#resp.body.breakpoints]
        vim.notify(string.format('Data breakpoint @ 0x%X (%d B) → %s', a, size, (bp and bp.verified) and 'verified' or 'NOT verified'))
      end
    )
  end

  function M.clear()
    M._bps = {}
    local session = ensure_session(); if not session then return end
    session:request('setDataBreakpoints', { breakpoints = {} }, function() end)
    vim.notify('All data breakpoints cleared')
  end

  vim.api.nvim_create_user_command(
    'DapSetDataBreakpoint',
    function(opts) M.add(opts.fargs[1], opts.fargs[2]) end,
    {nargs = '+', desc = 'Set LLDB data breakpoint'}
  )

  vim.api.nvim_create_user_command(
    'DapClearDataBreakpoints',
    function() M.clear() end,
    {nargs = 0,  desc = 'Remove all LLDB data breakpoints'}
  )
end
init_dap_data_breakpoint()

-- -----------------------------------------------------------------------------
-- keep focus in the DAP stack list when selecting items in it

function init_dap_stay_in_stack_window_when_selecting_item()
  local util = require('dapui.util')

  if not util.__stack_focus_patch then
    util.__stack_focus_patch = true
    local apply_orig = util.apply_mapping

    util.apply_mapping = function(keys, fn, buffer, action)
      if  action == 'open'
          and vim.api.nvim_buf_is_valid(buffer)
          and vim.api.nvim_buf_get_option(buffer, 'filetype') == 'dapui_stacks'
          and type(fn) == 'function'
      then
        local original_fn = fn
        fn = function(...)
          original_fn(...)
          vim.schedule(function()
            pcall(vim.cmd, 'wincmd p')
          end)
        end
      end
      return apply_orig(keys, fn, buffer, action)
    end
  end
end
init_dap_stay_in_stack_window_when_selecting_item()

-- -----------------------------------------------------------------------------
-- command+click to go to file:line:column locations

vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    if vim.bo.buftype == '' and vim.bo.buflisted then
      vim.g.__last_code_win = vim.fn.win_getid()
    end
  end,
})

vim.keymap.set('n', '<d-leftrelease>', function()
  local target = vim.fn.expand('<cWORD>')
  target = target:gsub(':+$', '')

  local file, line, col = target:match('(.+):(%d+):(%d+)$')
  if not file then file, line = target:match('(.+):(%d+)$') end
  if not file then return end

  if vim.bo.buftype ~= '' and vim.g.__last_code_win then
    if vim.api.nvim_win_is_valid(vim.g.__last_code_win) then
      vim.api.nvim_set_current_win(vim.g.__last_code_win)
    end
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(file))

  -- f) move to line and column
  local lnum = tonumber(line)
  if col then
    local cnum = tonumber(col) - 1   -- nvim_win_set_cursor expects 0-based col
    vim.api.nvim_win_set_cursor(0, {lnum, cnum})
  else
    vim.api.nvim_win_set_cursor(0, {lnum, 0})
  end
end, { silent = true })

-- -----------------------------------------------------------------------------
-- =============================================================================
