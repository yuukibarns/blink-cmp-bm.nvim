---@class blink-cmp-rg.Options
---@field prefix_min_len? number
---@field get_command? fun(context: blink.cmp.Context, prefix: string): string[]
---@field get_prefix? fun(context: blink.cmp.Context): string[]

local RgSource = {}

---@param opts blink-cmp-rg.Options
function RgSource.new(opts)
    opts = opts or {}

    return setmetatable({
        get_command = opts.get_command or function()
            return {
                "rg",
                "--no-config",
                "--json",
                "--word-regexp",
                "--ignore-case",
                "--type=md",
                "--",
                "(" ..
                "^(<!-- )?#+\\s+.+" ..
                ")" ..
                "|" ..
                "(" ..
                "^\\*\\*(Definition|Theorem|Lemma|Corollary|Proposition|Claim|Example|Problem)\\s+\\(.+?\\)(\\.)?\\*\\*" ..
                ")",
                vim.fs.root(0, ".git") or vim.fn.getcwd(),
            }
        end,
    }, { __index = RgSource })
end

function RgSource:enabled() return vim.bo.filetype == 'markdown' and vim.fs.root(0, ".git") end

function RgSource:get_completions(context, resolve)
    if context.line:sub(context.bounds.start_col - 2, context.bounds.start_col - 1) ~= "**" then
        resolve()
        return
    end

    vim.system(self.get_command(), nil, function(result)
        if result.code ~= 0 then
            resolve()
            return
        end

        local items = {}
        local lines = vim.split(result.stdout, "\n")
        vim.iter(lines)
            :map(function(line)
                local ok, item = pcall(vim.json.decode, line)
                return ok and item or {}
            end)
            :filter(function(item)
                return item.type == "match"
            end)
            :map(function(item)
                return item.data.submatches
            end)
            :flatten()
            :each(function(submatch)
                if submatch.match.text:match("^<!%-%-%s+#+%s+") or submatch.match.text:match("^#+%s+") then
                    local text = submatch.match.text
                        :gsub("^<!%-%-%s+", "")
                        :gsub("%s+%-%->$", "")
                        :gsub("^#+%s+", "")
                        :gsub("%s+$", "")
                    items[submatch.match.text] = {
                        label = text,
                        kind = require('blink.cmp.types').CompletionItemKind.Reference,
                        insertText = text,
                    }
                else
                    local text = submatch.match.text:match("%((.-)%)")
                    items[submatch.match.text] = {
                        label = text,
                        kind = require('blink.cmp.types').CompletionItemKind.Reference,
                        insertText = text,
                    }
                end
            end)

        resolve({
            is_incomplete_forward = false,
            is_incomplete_backward = false,
            items = vim.tbl_values(items),
        })
    end)
end

return RgSource
