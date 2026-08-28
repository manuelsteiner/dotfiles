return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  dependencies = { "nvim-treesitter/nvim-treesitter", branch = "main" },
  init = function()
    vim.g.no_plugin_maps = true
  end,
  config = function()
    require("nvim-treesitter-textobjects").setup({
      select = {
        lookahead = true,
        selection_modes = {
          ["@parameter.outer"] = "v",
          ["@function.outer"] = "V",
          ["@class.outer"] = "V",
        },
        include_surrounding_whitespace = false,
      },
      move = { set_jumps = true },
    })

    local sel = require("nvim-treesitter-textobjects.select")
    local move = require("nvim-treesitter-textobjects.move")
    local swap = require("nvim-treesitter-textobjects.swap")

    local selects = {
      ["af"] = { "@function.outer", "a function" },
      ["if"] = { "@function.inner", "inner function" },
      ["ac"] = { "@class.outer", "a class" },
      ["ic"] = { "@class.inner", "inner class" },
      ["aa"] = { "@parameter.outer", "an argument" },
      ["ia"] = { "@parameter.inner", "inner argument" },
      ["al"] = { "@loop.outer", "a loop" },
      ["il"] = { "@loop.inner", "inner loop" },
      ["a/"] = { "@comment.outer", "a comment" },
      ["i/"] = { "@comment.inner", "inner comment" },
      ["a="] = { "@assignment.outer", "an assignment" },
      ["i="] = { "@assignment.inner", "inner assignment" },
      ["gl="] = { "@assignment.lhs", "assignment LHS" },
      ["gr="] = { "@assignment.rhs", "assignment RHS" },
    }
    for key, spec in pairs(selects) do
      vim.keymap.set({ "x", "o" }, key, function()
        sel.select_textobject(spec[1], "textobjects")
      end, { desc = spec[2] })
    end

    local moves = {
      goto_next_start     = { ["]f"] = "@function.outer", ["]a"] = "@parameter.inner",
                              ["]="] = "@assignment.outer", ["]/"] = "@comment.outer" },
      goto_previous_start = { ["[f"] = "@function.outer", ["[a"] = "@parameter.inner",
                              ["[="] = "@assignment.outer", ["[/"] = "@comment.outer" },
      goto_next_end       = { ["]F"] = "@function.outer", ["]A"] = "@parameter.inner" },
      goto_previous_end   = { ["[F"] = "@function.outer", ["[A"] = "@parameter.inner" },
    }
    for dir, maps in pairs(moves) do
      for key, capture in pairs(maps) do
        vim.keymap.set({ "n", "x", "o" }, key, function()
          move[dir](capture, "textobjects")
        end, { desc = dir:gsub("goto_", ""):gsub("_", " ") .. " " .. capture })
      end
    end

    vim.keymap.set("n", "<leader>a", function() swap.swap_next("@parameter.inner") end,
      { desc = "swap arg next" })
    vim.keymap.set("n", "<leader>A", function() swap.swap_previous("@parameter.inner") end,
      { desc = "swap arg prev" })

    local rep = require("nvim-treesitter-textobjects.repeatable_move")
    vim.keymap.set({ "n", "x", "o" }, ";", rep.repeat_last_move)
    vim.keymap.set({ "n", "x", "o" }, ",", rep.repeat_last_move_opposite)
    vim.keymap.set({ "n", "x", "o" }, "f", rep.builtin_f_expr, { expr = true })
    vim.keymap.set({ "n", "x", "o" }, "F", rep.builtin_F_expr, { expr = true })
    vim.keymap.set({ "n", "x", "o" }, "t", rep.builtin_t_expr, { expr = true })
    vim.keymap.set({ "n", "x", "o" }, "T", rep.builtin_T_expr, { expr = true })
  end,
}
