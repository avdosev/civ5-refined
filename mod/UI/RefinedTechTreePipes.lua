-- Each dependency owns its elbows and vertical stroke. Native TechTree.xml and
-- textures are retained; no shared adapter depends on another child's column.
function DrawRefinedTechTreePipes(manager)
    -- Different destinations in one column get parallel tracks in its 96px
    -- gutter. Parents of the same destination intentionally share its track.
    local columns, tracks = {}, {}
    for tech in GameInfo.Technologies() do
        columns[tech.GridX] = columns[tech.GridX] or {}
        table.insert(columns[tech.GridX], tech)
    end
    for _, column in pairs(columns) do
        table.sort(column, function(a,b) return a.GridY < b.GridY end)
        for index, tech in ipairs(column) do
            tracks[tech.Type] = #column == 1 and 0 or -12 + math.floor((index - 1) * 48 / (#column - 1) + 0.5)
        end
    end
    local function sprite(x, y, w, h, texture, u, v)
        local pipe = manager:GetInstance().TechPipeIcon
        pipe:SetOffsetVal(x, y)
        pipe:SetSize({x=w, y=h})
        pipe:SetTexture(texture)
        pipe:SetTextureOffset(Vector2(u or 0, v or 0))
    end
    for row in GameInfo.Technology_PrereqTechs() do
        local parent = GameInfo.Technologies[row.PrereqTech]
        local child = GameInfo.Technologies[row.TechType]
        if parent and child then
            local sourceX = parent.GridX * 366 + 334
            local targetX = child.GridX * 366 + 64
            local sourceY = (parent.GridY - 5) * 68 + 32
            local targetY = (child.GridY - 5) * 68 + 32
            if sourceY == targetY then
                sprite(sourceX, sourceY + 12, targetX - sourceX, 42, 'TechBranchH.dds')
            else
                local track = tracks[child.Type]
                local elbowX = child.GridX * 366 - 12 + track
                sprite(sourceX, sourceY + 12, elbowX - sourceX + 1, 42, 'TechBranchH.dds')
                local down = targetY > sourceY
                sprite(elbowX, sourceY + (down and 12 or -3), 32, 42,
                    'TechBranches.dds', 72, down and 0 or 72)
                sprite(child.GridX * 366 + track, targetY + (down and -3 or 12), 32, 42,
                    'TechBranches.dds', 0, down and 72 or 0)
                sprite(child.GridX * 366 + 26 + track, targetY + 12, 38 - track, 42, 'TechBranchH.dds')
                -- Short overlapping pieces avoid the old 1..4 row lookup and
                -- do not rely on texture wrapping beyond the native DDS size.
                local top = math.min(sourceY, targetY) + 12
                local bottom = math.max(sourceY, targetY) - 12
                while top < bottom do
                    local height = math.min(96, bottom - top)
                    sprite(child.GridX * 366 + track, top + height / 2, 32, height, 'TechBranchV.dds')
                    top = top + height - 1
                    if height <= 1 then break end
                end
            end
        end
    end
end
