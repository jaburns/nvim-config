-- =============================================================================
-- debugger notes
--   show backtrace: `bt
--   print bytes:    `memory read --format x --size 1 --count {NUM} {0xADDRESS}
--   print array:    `parray {LEN} {VARNAME}
--   watch array:    *({TYPE}(*)[{LEN}]){VARNAME}
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
vim._j = {} -- custom global state

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
vim.opt.signcolumn = 'yes'

vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.tabstop = 4
vim.opt.scrolloff = 15

vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false

vim.opt.ignorecase = true
vim.opt.smartcase  = true

local DEFAULT_PROJECT_PATH = '~/dev/kaizogame/Auxiliary/editor'

-- -----------------------------------------------------------------------------

local function switch_source_header()
  local f = vim.api.nvim_buf_get_name(0)
  local base, ext = f:match('(.+)%.(%w+)$')
  if not base then return end
  local candidates = {}
  if ext:match('c$') then
    candidates = { base..'.hpp', base..'.hh', base..'.h' }
  elseif ext:match('^h') then
    candidates = { base..'.cpp', base..'.cc', base..'.c', base..'.m' }
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
    'cormacrelf/dark-notify', -- auto-toggle dark mode and light mode
    config = function()
      require('dark_notify').run({
        onchange = function(mode)
          if mode == 'dark' then
            vim.cmd.highlight 'Normal guibg=#1E2132'
            vim.cmd.highlight 'NormalNC guibg=#1E2132'
          end
        end,
      })
    end,
  },
-- -----------------------------------------------------------------------------
  {
    -- g? to show help
    'stevearc/oil.nvim', -- filesystem browse/edit
    config = function()
      local oil = require('oil')
      oil.setup({
        view_options = { show_hidden = true },
        watch_for_changes = true,
        keymaps = {
          ['-'] = { 'actions.close', mode = 'n' },
          ['<leader>o'] = 'actions.open_external',
        }
      })
      vim.keymap.set('n', '-', function() oil.open() end)
    end
  },
-- -----------------------------------------------------------------------------
  {
    'nvim-pack/nvim-spectre', -- search and replace with preview
  },
-- -----------------------------------------------------------------------------
  {
    'nvim-treesitter/nvim-treesitter', -- better highlighting and AST ops
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
        ensure_installed = { 'c', 'cpp', 'c_sharp', 'lua', 'vim', 'bash', 'hlsl' },
        indent = { enable = false },
        highlight = { enable = true },
      }
    end,
  },
-- -----------------------------------------------------------------------------
  {
    'neovim/nvim-lspconfig', -- language server protocol
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'Hoffs/omnisharp-extended-lsp.nvim',
    },
    config = function()
      local lspconfig = require('lspconfig')
      local pid = tostring(vim.fn.getpid())
      local lsp_format_augrp = vim.api.nvim_create_augroup('LspFormatOnSave', {})
      local omnix = require('omnisharp_extended')

      function on_lsp_attach(lang)
        return function(client, bufnr)
          local buf = { buffer = bufnr, silent = true, noremap = true }
          if lang == 'c#' then
            vim.keymap.set('n', '<leader>d', omnix.lsp_definition, buf)
          else
            vim.keymap.set('n', '<leader>d', vim.lsp.buf.definition, buf)
          end
          vim.keymap.set('n', '<leader>i', vim.lsp.buf.hover, buf)
          vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, buf)
          vim.keymap.set('n', '<leader>r', vim.lsp.buf.rename, buf)
          vim.keymap.set('n', '<leader>a', vim.lsp.buf.code_action, buf)
          vim.keymap.set('n', '<leader>o', switch_source_header, { buffer=true, silent=true })
          vim.keymap.set('i', '<c-s-space>', vim.lsp.buf.signature_help, buf)

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

      lspconfig.clangd.setup {
        cmd = {
          '/opt/homebrew/opt/llvm/bin/clangd',
          '--background-index',
          '--enable-config',
          '--header-insertion=never',
          '--function-arg-placeholders=false',
        },
        -- compile_commands.json generated by running `bear -- ./build.sh --clean` in project root
        root_dir = require('lspconfig.util').root_pattern('compile_commands.json', '.git'),
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
        on_attach = on_lsp_attach('c++'),
      }
      lspconfig.slangd.setup {
        cmd = { 'vendor/macos-arm64/slang/slangd', '--stdio' },
        filetypes = { 'slang' },
        root_dir = require('lspconfig.util').root_pattern('compile_commands.json', '.git'),
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
        on_attach = on_lsp_attach('slang'),
      }
      lspconfig.omnisharp.setup{
        cmd = {
          vim.fn.expand('~/.local/share/omnisharp/OmniSharp'),
          '--languageserver',
          '--hostPID', pid
        },
        cmd_env= {
            DOTNET_ROOT = '/opt/homebrew/Cellar/dotnet/9.0.5/libexec',
        },
        root_dir = require('lspconfig.util').root_pattern('.sln', '*.csproj', '.git'),
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
        on_attach = on_lsp_attach('c#'),
      }
    end,
  },
-- -----------------------------------------------------------------------------
  {
    'folke/trouble.nvim', -- nicer pane for compile errors and diagnostics
    opts = {},
    cmd = 'Trouble',
    keys = {
      { '<leader>q', '<cmd>Trouble diagnostics open<cr>', desc = 'Diagnostics (Trouble)' },
    },
    config = function()
      require('trouble').setup{
        focus = true,
        win = {
          type = 'split',
          relative = 'win',
          position = 'bottom',
          size = 20,
        },
        preview = {
          type = 'main',
          scratch = false,
        },
      }
      vim.api.nvim_set_hl(0, 'TroublePreview', {
        bg = '#ffff00',
        fg = '#000000',
      })
      vim.keymap.set('n', '<leader>j', function() require('trouble').next({skip_groups = true, jump = true}) end)
      vim.keymap.set('n', '<leader>k', function() require('trouble').prev({skip_groups = true, jump = true}) end)
    end
  },
-- -----------------------------------------------------------------------------
  {
    'nvim-telescope/telescope.nvim', -- fuzzy find
    dependencies = {
      'nvim-lua/plenary.nvim',
      'folke/trouble.nvim',
    },
    config = function()
      local telescope = require('telescope')
      local tb = require('telescope.builtin')
      local trouble = require('trouble.sources.telescope')

      telescope.setup{
        defaults = {
          mappings = {
            i = { ['<c-q>'] = trouble.open, },
            n = { ['<c-q>'] = trouble.open, },
          },
        },
      }

      local map = vim.keymap.set
      local opts = { noremap=true, silent=true }
      map('n', '<c-p>', tb.find_files, opts)
      map('n', '<d-p>', tb.find_files, opts)
      map('n', '<leader>f', tb.lsp_references, opts)
      map('n', '<leader>F', tb.grep_string, opts)
      map('n', '<leader>G', tb.live_grep, opts)
      map('n', '<leader>l', tb.buffers, opts)
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
          -- { name = 'buffer' },
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
      dap.adapters.unity = {
        type = 'executable',
        command = '/opt/homebrew/bin/mono',
        args = { vim.fn.expand('~/unity-nvim/extension/bin/UnityDebug.exe') }, -- downloaded and unzipped from https://github.com/Unity-Technologies/vscode-unity-debug/releases/download/Version-2.7.2/unity-debug-2.7.2.vsix
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
      map('n', '<leader>c', dap.continue, { silent=true })
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
    end,
  },
-- -----------------------------------------------------------------------------
  {
    'lukas-reineke/indent-blankline.nvim', -- indentation lines
    main = 'ibl',
    opts = {},
    config = function()
      -- local highlight = {
      --     'RainbowRed',
      --     'RainbowGreen',
      --     'RainbowBlue',
      -- }
      -- local hooks = require 'ibl.hooks'
      -- hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
      --     vim.api.nvim_set_hl(0, 'RainbowRed', { fg = '#E06C75' })
      --     vim.api.nvim_set_hl(0, 'RainbowGreen', { fg = '#98C379' })
      --     vim.api.nvim_set_hl(0, 'RainbowBlue', { fg = '#61AFEF' })
      -- end)

      require('ibl').setup {
        -- indent = { highlight = highlight },
        scope = { enabled = false },
      }
    end
  }
-- -----------------------------------------------------------------------------
})
-- -----------------------------------------------------------------------------

vim.treesitter.language.register('hlsl', 'slang')

-- =============================================================================

-- f5 to build/run/debug/continue
vim.keymap.set('n', '<f5>', function()
  local overseer = require('overseer')
  local dap = require('dap')
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

  if dap.session() then
    dap.continue()
    return
  end

  if filetype == 'cs' or filetype == 'csharp' then
    dap.run({
      type = 'unity',
      request = 'attach',
      name = 'Unity Editor',
    })
    return
  end

  overseer.run_template({ name = 'build' }, function(task, success)
    vim.cmd('Trouble qflist close')
    task:subscribe('on_complete', function(task, status)
      vim.cmd('cclose')
      if status == 'SUCCESS' then
        dap.run({
          type = 'lldb',
          request = 'launch',
          program = function() return vim.fn.getcwd() .. '/bin/game' end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          runInTerminal = true,
          args = {},
        })
      else
        vim.cmd('Trouble qflist open')
      end
    end)
  end)
end, {
  desc = 'Overseer: build → quickfix → launch DAP',
  silent = true,
})

-- -----------------------------------------------------------------------------
-- font and colors

do
  vim._j.font_size = 14
  local function up()
    vim._j.font_size = vim._j.font_size + 1
    vim.o.guifont = 'Berkeley Mono:h'..vim._j.font_size
  end
  local function down()
    vim._j.font_size = vim._j.font_size - 1
    vim.o.guifont = 'Berkeley Mono:h'..vim._j.font_size
  end
  vim.keymap.set('n', '<d-=>', up)
  vim.keymap.set('n', '<d-->', down)
  vim.o.guifont = 'Berkeley Mono:h'..vim._j.font_size
  vim.cmd.colorscheme 'highlite-iceberg'
end

-- -----------------------------------------------------------------------------
-- neovide-specific config

if vim.g.neovide then
  -- enable opening a file in an existing instance with:
  -- $ /opt/homebrew/bin/nvim --server /tmp/nvimsocket --remote-send ":e $1<cr>:$2<cr>:NeovideFocus<cr>"
  vim.fn.serverstart('/tmp/nvimsocket')

  vim.g.neovide_text_gamma = 1 -- default 0
  vim.g.neovide_text_contrast = 0 -- default 0.5

  vim.g.neovide_window_blurred = true
  vim.g.neovide_opacity = 0.9
  vim.defer_fn(function() vim.cmd('NeovideFocus') end, 25)
  vim.cmd('cd '..DEFAULT_PROJECT_PATH)

  vim._j.scroll_enabled = true
  vim._j.scroll_speed = 0.15 -- default 0.3
  vim.g.neovide_scroll_animation_length = vim._j.scroll_speed
  vim.g.neovide_cursor_animation_length = 0.1 -- default 0.15

  -- disable scroll animation when DAP UI is visible so console logs are readable
  local function dapui_repl_visible()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_get_option(buf, 'filetype') == 'dapui_console' then
        return true
      end
    end
    return false
  end
  vim.api.nvim_create_autocmd({ 'WinNew', 'WinClosed' }, { callback = function()
    if dapui_repl_visible() then
      vim._j.scroll_enabled = false
      vim.g.neovide_scroll_animation_length = 0
    else
      vim._j.scroll_enabled = true
      vim.g.neovide_scroll_animation_length = vim._j.scroll_speed
    end
  end})

  -- disable confusing scroll animation when switching between buffers
  vim.api.nvim_create_autocmd('BufLeave', { callback = function()
    vim.g.neovide_scroll_animation_length = 0
  end})
  vim.api.nvim_create_autocmd('BufEnter', { callback = function()
    vim.fn.timer_start(100, function()
      if vim._j.scroll_enabled then
        vim.g.neovide_scroll_animation_length = vim._j.scroll_speed
      end
    end)
  end})
end

-- -----------------------------------------------------------------------------
-- jump to project root dirs quickly

do
  local function setup_jump_to_project(num, path)
    vim.keymap.set('n', '<leader>'..num, function()
      vim.cmd('cd '..path)
      vim.notify('jumped to '..path)
    end)
  end
  setup_jump_to_project(1, DEFAULT_PROJECT_PATH)
  setup_jump_to_project(2, '~/dev/kaizogame')
end

-- window splits
vim.keymap.set('n', '<c-w>\\', '<c-w>v<c-w>w')
vim.keymap.set('n', '<c-w>-', '<c-w>s')

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
vim.keymap.set('n', '<leader>P', 'viWP') -- paste over WORD
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

-- terminal split, and terminal shortcuts
vim.keymap.set('n', '<c-`>', '<c-w>s:terminal<cr>i')
vim.keymap.set('t', '<d-v>', "<C-\\><C-n>:lua vim.fn.jobsend(vim.b.terminal_job_id, vim.fn.getreg('+'))<CR>a") -- fix paste with cmd+v
vim.keymap.set('t', '<c-w>', '<c-\\><c-n><c-w>')

-- don't auto-insert comments
vim.cmd('autocmd BufEnter * set formatoptions-=cro')
vim.cmd('autocmd BufEnter * setlocal formatoptions-=cro')

-- trim trailing whitespace
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*',
  command = '%s/\\s\\+$//e',
})

-- shortcut to save all and then close hidden buffers
do
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
end

-- -----------------------------------------------------------------------------
-- data breakpoints for lldb
-- usage: :DapSetDataBreakpoint [0xADDRESS] [num bytes] [write/read/readWrite (default is write)]

do
  local breakpoints = {}

  local function ensure_session()
    local dap = require('dap')
    local session = dap.session()
    if not session then
      vim.notify('nvim-dap: no active debug session', vim.log.levels.ERROR)
    end
    return session
  end

  vim.api.nvim_create_user_command(
    'DapSetDataBreakpoint',
    function(opts)
      local addr = opts.fargs[1]
      local size = tonumber(opts.fargs[2]) or 1
      local access = opts.fargs[2] or 'write'

      local a = type(addr) == 'number' and addr or tonumber(addr) or tonumber(addr:gsub('^0[xX]', ''), 16)
      if not a then
        vim.notify('DapSetDataBreakpoint: invalid address: '..tostring(addr), vim.log.levels.ERROR)
        return
      end

      -- de-duplicate by dataId
      local data_id = string.format('%x/%d', a, size)
      for _,bp in ipairs(breakpoints) do
        if bp.dataId == data_id then
          vim.notify('Data breakpoint already set for 0x' ..string.format('%x',a)..' ('..size..' B)')
          return
        end
      end
      table.insert(breakpoints, { dataId = data_id, accessType = access })

      local session = ensure_session(); if not session then return end
      session:request(
        'setDataBreakpoints',
        { breakpoints = breakpoints },
        function(err, resp)
          if err then
            vim.notify('setDataBreakpoints: '..err.message, vim.log.levels.ERROR)
            return
          end
          local bp = resp.body and resp.body.breakpoints[#resp.body.breakpoints]
          vim.notify(string.format('Data breakpoint @ 0x%X (%d B) → %s', a, size, (bp and bp.verified) and 'verified' or 'NOT verified'))
        end
      )
    end,
    {nargs = '+', desc = 'Set LLDB data breakpoint'}
  )

  vim.api.nvim_create_user_command(
    'DapClearDataBreakpoints',
    function()
      breakpoints = {}
      local session = ensure_session(); if not session then return end
      session:request('setDataBreakpoints', { breakpoints = {} }, function() end)
      vim.notify('All data breakpoints cleared')
    end,
    {nargs = 0,  desc = 'Remove all LLDB data breakpoints'}
  )
end

-- -----------------------------------------------------------------------------
-- keep focus in the DAP stack list when selecting items in it

do
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

  local lnum = tonumber(line)
  if col then
    local cnum = tonumber(col) - 1
    vim.api.nvim_win_set_cursor(0, {lnum, cnum})
  else
    vim.api.nvim_win_set_cursor(0, {lnum, 0})
  end
end, { silent = true })

-- -----------------------------------------------------------------------------
-- =============================================================================
