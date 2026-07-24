return {
	"lunacookies/vim-colors-xcode",
	lazy = false,
	priority = 1000,
	config = function()
		vim.g.xcode_green_comments = 0 -- 1 = Xcode's green comments
		vim.o.background = "dark"

		-- Toggle background transparency
		local transparent = true

		vim.api.nvim_create_autocmd("ColorScheme", {
			callback = function()
				if not transparent then
					return
				end
				-- TabLine* is the base highlight the bufferline is drawn over
				local groups = { "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn", "EndOfBuffer", "TabLine", "TabLineFill", "TabLineSel" }
				for _, g in ipairs(groups) do
					local hl = vim.api.nvim_get_hl(0, { name = g, link = false })
					hl.bg, hl.ctermbg = nil, nil
					vim.api.nvim_set_hl(0, g, hl)
				end
			end,
		})

		vim.cmd.colorscheme("xcodedark") -- fires ColorScheme, applying transparency

		vim.keymap.set("n", "<leader>bg", function()
			transparent = not transparent
			vim.cmd.colorscheme("xcodedark")
		end, { noremap = true, silent = true })
	end,
}
