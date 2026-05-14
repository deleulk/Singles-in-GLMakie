include("singles_finaal.jl")


function find_duplicates(state::GameState)::Vector{Tuple{Int,Int}}
    candidates = Set{Tuple{Int,Int}}()

    for r in 1:state.n
        per_waarde = Dict{Int, Vector{Tuple{Int,Int}}}()
        for c in 1:state.n
            if !state.blacked[r, c]
                waarde = state.grid[r, c]
                push!(get!(per_waarde, waarde, Tuple{Int,Int}[]), (r, c))
            end
        end
        for (_, cellen) in per_waarde
            if length(cellen) > 1
                union!(candidates, cellen)
            end
        end
    end

    for c in 1:state.n
        per_waarde = Dict{Int, Vector{Tuple{Int,Int}}}()
        for r in 1:state.n
            if !state.blacked[r, c]
                waarde = state.grid[r, c]
                push!(get!(per_waarde, waarde, Tuple{Int,Int}[]), (r, c))
            end
        end
        for (_, cellen) in per_waarde
            if length(cellen) > 1
                union!(candidates, cellen)
            end
        end
    end

    return collect(candidates)
end


function apply_forced_whites!(state::GameState, forced_white::Matrix{Bool})::Bool
    changed = false

    for (r, c) in find_duplicates(state)
        waarde = state.grid[r, c]

        rij_partners = [(r, c2) for c2 in 1:state.n
                        if c2 != c && !state.blacked[r, c2] && state.grid[r, c2] == waarde]
        col_partners = [(r2, c) for r2 in 1:state.n
                        if r2 != r && !state.blacked[r2, c] && state.grid[r2, c] == waarde]

        for (pr, pc) in vcat(rij_partners, col_partners)
            # Geval 1: (r,c) kan niet zwart worden → maak de partner zwart
            if (has_black_adjacent(state, r, c) || forced_white[r, c]) && !state.blacked[pr, pc]
                state.blacked[pr, pc] = true
                changed = true
                for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)]
                    nr, nc = pr+dr, pc+dc
                    if 1 ≤ nr ≤ state.n && 1 ≤ nc ≤ state.n
                        forced_white[nr, nc] = true
                    end
                end
            end

            # Geval 2: partner kan niet zwart worden → maak (r,c) zwart
            if (has_black_adjacent(state, pr, pc) || forced_white[pr, pc]) && !state.blacked[r, c]
                state.blacked[r, c] = true
                changed = true
                for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)]
                    nr, nc = r+dr, c+dc
                    if 1 ≤ nr ≤ state.n && 1 ≤ nc ≤ state.n
                        forced_white[nr, nc] = true
                    end
                end
            end
        end
    end

    return changed
end


function has_contradiction(state::GameState, forced_white::Matrix{Bool})::Bool

    if !check_no_adjacent_blacks(state)
        return true
    end

    for (r, c) in find_duplicates(state)
        waarde = state.grid[r, c]

        rij_partners = [(r, c2) for c2 in 1:state.n
                        if c2 != c && !state.blacked[r, c2] && state.grid[r, c2] == waarde]
        col_partners = [(r2, c) for r2 in 1:state.n
                        if r2 != r && !state.blacked[r2, c] && state.grid[r2, c] == waarde]

        for (pr, pc) in vcat(rij_partners, col_partners)
            cant_black_rc      = has_black_adjacent(state, r, c)  || forced_white[r, c]
            cant_black_partner = has_black_adjacent(state, pr, pc) || forced_white[pr, pc]
            if cant_black_rc && cant_black_partner
                return true
            end
        end
    end

    if !check_whites_connected(state)
        return true
    end

    return false
end


function solve!(state::GameState, forced_white::Matrix{Bool} = zeros(Bool, state.n, state.n))::Bool

    while apply_forced_whites!(state, forced_white)
    end

    if has_contradiction(state, forced_white)
        return false
    end

    if is_valid(state)
        return true
    end

    candidates = filter(rc -> !forced_white[rc[1], rc[2]], find_duplicates(state))
    if isempty(candidates)
        return false
    end

    r, c = first(candidates)

    # (r,c) proberen zwart te maken
    kopie = deepcopy(state)
    kopie_fw = deepcopy(forced_white)
    kopie.blacked[r, c] = true
    for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)]
        nr, nc = r+dr, c+dc
        if 1 ≤ nr ≤ kopie.n && 1 ≤ nc ≤ kopie.n
            kopie_fw[nr, nc] = true
        end
    end
    if solve!(kopie, kopie_fw)
        state.blacked .= kopie.blacked
        return true
    end

    # Stap 6: probeer de partner zwart te maken
    waarde = state.grid[r, c]
    partner = nothing

    for c2 in 1:state.n
        if c2 != c && !state.blacked[r, c2] && state.grid[r, c2] == waarde
            partner = (r, c2)
            break
        end
    end
    if partner === nothing
        for r2 in 1:state.n
            if r2 != r && !state.blacked[r2, c] && state.grid[r2, c] == waarde
                partner = (r2, c)
                break
            end
        end
    end

    if partner !== nothing
        kopie2 = deepcopy(state)
        kopie2_fw = deepcopy(forced_white)
        kopie2.blacked[partner[1], partner[2]] = true
        for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)]
            nr, nc = partner[1]+dr, partner[2]+dc
            if 1 ≤ nr ≤ kopie2.n && 1 ≤ nc ≤ kopie2.n
                kopie2_fw[nr, nc] = true
            end
        end
        if solve!(kopie2, kopie2_fw)
            state.blacked .= kopie2.blacked
            return true
        end
    end

    return false
end


function add_solve_button!(fig, ax, state::GameState)
    knop_bot = Button(fig[1, 3][6, 1], label = "Bot oplossen")

    on(knop_bot.clicks) do _
    state.blacked = zeros(Bool, state.n, state.n)  # reset first
    solve!(state)
    draw_board!(ax, state)
        if is_valid(state)
            show_victory!(ax, fig)
        end
    end
end

fig, ax, state = run_game(5)
add_solve_button!(fig, ax, state)