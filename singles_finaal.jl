# 1. Using blok

using GLMakie
using Random

# 2 Structs definiëren

mutable struct GameState
    n::Int                  # gridgrootte: 5, 6, 8, 10 of 12
    grid::Matrix{Int}       # de vaste cijfers — verandert NOOIT tijdens het spel
    blacked::Matrix{Bool}   # true = speler heeft dit vakje zwart geslagen
    solved::Bool            # wordt true zodra het puzzel opgelost is
    solution::Matrix{Int}   # neemt de oplossing mee in de struct
end

# 3 Alle functies maken die ervoor zorgen dat het spel gegenereerd en gespeel kan worden
# 3.1 Generatiefuncties, deze functies zorgen ervoor dat het spel gegenereerd wordt.


"""
    generate_solution(n::Int) -> Matrix{Int}

Maakt een speelbaar grid door duplicaten toe te voegen aan een bestaande oplossing.

# Argumenten
`Neemt een natuurlijk getal als invoerwaarde`

# Returnwaarde
Een `n×n` matrix met cijfers 1 tot n.

# Opmerkingen
- Maakt eerst een leeg grid van de juiste grootte
- Maakt er dan een Latijns vierkant van: in elke rij en kolom staan n verschillende cijfers
- Het maken van een Latijns vierkant zorgt ervoor dat het spel altijd oplosbaar is
"""
function generate_solution(n::Int)::Matrix{Int}
    # Elke rij is een permutatie van 1:n
    # Zo heeft elke rij elk cijfer exact één keer
    solution = zeros(Int, n, n) # Maakt een lege matrix van de juiste grootte
    for r in 1:n
        for c in 1:n
            solution[r,c] = mod(r + c - 2, n) + 1
        end
    end
    solution = solution[randperm(n), :]
    solution = solution[:, randperm(n)]
    return solution
end



"""
    make_grid(solution) -> Matrix{Int}

Maakt een speelbaar grid door duplicaten toe te voegen aan een bestaande oplossing.

# Argumenten
- `solution::Matrix{Int}`: een geldige oplossingsmatrix van `generate_solution`
- `de grootte van het vierkante grid, n, wordt in de functie zelf bepaald`
# Returnwaarde
Een `n×n` matrix met cijfers 1 tot n, waarbij ~30% van de cellen
een duplicaat bevat van een ander cijfer in dezelfde rij.

# Voorbeeld
```julia
sol = generate_solution(5)
grid = make_grid(sol)
```

# Opmerkingen
- Gebruikt `copy(solution)` zodat de originele oplossing niet wordt aangepast
- Duplicaten komen altijd uit dezelfde rij, zodat de puzzel oplosbaar blijft
"""
function make_grid(solution::Matrix{Int})::Matrix{Int}
    grid = copy(solution)
    n = size(solution, 2)

    for r in 1:n
        # Voeg twee duplicaten toe per rij
        for _ in 1:rand(1:div(n,3))
            c = rand(1:n)
            andere_kolom = rand(filter(x -> x != c, 1:n))
            grid[r, c] = solution[r, andere_kolom]
        end
    end
    return grid
end
"""
    new_game(grid) -> GameState

# Argumenten
- `Neemt als invoer de grootte van het spel`

# Returnwaarde
- `Een GameState die alle nodige info geeft om het spel te kunnen spelen`

# Opmerkingen
- Heeft de functies `generate_solution` en `make_grid` nodig
- Heeft slechts één returnwaarde: de GameState
"""
function new_game(n::Int)::GameState
    if n ∉ [5,6,8,10,12]
        error("Ongeledige gridgrootte: Kies een getal uit {5,6,8,10,12}")
    end
    solution = generate_solution(n)
    grid = make_grid(solution)

    # Oplosbaarheid controleren
    test = GameState(n, grid, zeros(Bool, n, n), false, solution)
    for r in 1:n
        for c in 1:n
            if grid[r, c] ≠ solution[r, c]
                test.blacked[r, c] = true
            end
        end
    end
    
    if is_valid(test) 
        return GameState(n, grid, zeros(Bool, n, n), false, solution)
    else
        return new_game(n)
    end
end


# 4. Nakijken of alle regels van het spel gerespecteerd worden

"""
    check_no_duplicates(state::GameState) -> Bool

Controleert of elke rij en kolom geen dubbele witte cijfers bevat.

# Argumenten
- `state::GameState`: de huidige spelstatus
"""
function check_no_duplicates(state::GameState)::Bool
    for r in 1:state.n
        witte_cellen = Set{Int}()
        for c in 1:state.n
            if state.blacked[r,c] == false
                waarde = state.grid[r,c]
                if waarde ∈ witte_cellen
                    return false
                end
                push!(witte_cellen,waarde)
            end
        end
    end

    for c in 1:state.n
        witte_cellen = Set{Int}()
        for r in 1:state.n
            if state.blacked[r,c] == false
                waarde = state.grid[r,c]
                if waarde ∈ witte_cellen
                    return false
                end
                push!(witte_cellen,waarde)
            end
        end
    end
    return true
end

"""
    check_no_adjacent_blacks(state::GameState) -> Bool

Controleert of er geen twee zwarte cellen horizontaal of verticaal
naast elkaar staan.
Omdat de for-lus de vakjes van links naar rechts en van boven naar onder overloopt moet er slechts rechts en onder elk vakje gekeken worden voor een aangrenzend zwart vakje.

# Argumenten
- `state::GameState`: de huidige spelstatus
"""
function check_no_adjacent_blacks(state::GameState)::Bool
    for r in 1:state.n
        for c in 1:state.n
            if state.blacked[r, c]
                # controleer de cel rechts
                if c + 1 <= state.n && state.blacked[r, c + 1]
                    return false
                end
                # controleer de cel onder
                if r + 1 <= state.n && state.blacked[r + 1, c]
                    return false
                end
            end
        end
    end
    return true
end

"""
    has_black_adjacent(state::GameState, r::Int, c::Int)::Bool

# Argumenten
- state::GameState
- r::Int, de rij van een vakje
- c::Int, de kolom van een vakje

# Returnwaarde
- Bool, true of false
"""
function has_black_adjacent(state::GameState, r::Int, c::Int)::Bool
    for (dr,dc) in [(-1,0), (1,0), (0,-1), (0,1)]
        nr, nc = r + dr, c + dc
        if 1 ≤ nr ≤ state.n && 1 ≤ nc ≤ state.n
            if state.blacked[nr,nc] == true
                return true
            end
        end
    end
    return false
end

"""
    check_whites_connected(state::GameState) -> Bool

Controleert of alle witte cellen met elkaar verbonden zijn door alle witte cellen af te gaan die bereikbaar zijn via een andere witte cel. 
Al deze witte cellen worden toegevoegd aan een Set. Deze Set moet even groot zijn als de verzameling van bezochte witte cellen.
Als dit niet zo is dan zijn niet alle witte cellen bereikbaar via een andere witte cel, met andere woorden: niet alle witte cellen zijn verbonden. 

# Argumenten
- `state::GameState`: de huidige spelstatus
"""
function check_whites_connected(state::GameState)::Bool
    # Maakt een Set van de coördianten van alle witte cellen.
    # Een Set hebben we niet gezien in de leerstof maar anders werkt dit simpelweg niet.
    witte_cellen = Set{Tuple{Int,Int}}()
    for r in 1:state.n
        for c in 1:state.n
            if state.blacked[r,c] == false
                push!(witte_cellen, (r,c))
            end
        end
    end

    if isempty(witte_cellen)
        return true
    end

    eerste = first(witte_cellen)
    bezocht = Set([eerste])
    stack = [eerste]

    while isempty(stack) == false
        # Neemt de volgende cel
        r, c = pop!(stack)
        # Bekijkt alle vier buren van de cel
        # Cellen buiten het grid behoren automatisch niet tot de witte_cellen en vormen dus ook geen probleem
        for (dr, dc) in [(-1,0), (1,0), (0,-1), (0,1)]
            buur = (r + dr, c + dc)
            # De functie voegt alleen een buur toe aan stack als die een witte cel is én nog niet bezocht is
            if buur ∈ witte_cellen && buur ∉ bezocht
                push!(bezocht, buur) # Nu weten we dat de cel bezocht is
                push!(stack, buur) # Voeg toe om later te verwerken
            end
        end
    end

    return length(bezocht) == length(witte_cellen)
end


"""
    is_valid(state::GameState) -> Bool

Deze functie roept alle check-functies aan om na te kijken of ze allemaal `true` teruggeven.
Wanneer één van de aangeroepen functies `false` teruggeeft, wilt dat zeggen dat er een spelregel niet gerespecteerd werd door de speler.

# Argument
`state::GameState`: de huidige spelstatus

# Returnwaarde
`Bool`: true or false
De regels worden gevolgd of niet, dit is vanzelfsprekend.
"""
function is_valid(state::GameState)::Bool
    check_no_duplicates(state) &&
    check_no_adjacent_blacks(state) &&
    check_whites_connected(state)

end


# 6. Het spel maken in GLMakie

"""
    draw_board!(state::GameState)

Deze functie tekent het vierkantig veld met de matrix ingevoerd in de GLMakie-terminal.
Hier wordt handig gebruik gemaakt van Rect(x, y, breedte, hoogte)
# Argumenten
- `fig`: dit is de huidige figuur die wordt meegegeven als argument. Anders moet de code telkens een nieuw venster maken.
- `state::GameState`: de huidige spelstatus

"""
function draw_board!(ax, state::GameState)
    n = state.n
    empty!(ax)
    ax.limits = (0, n, 0, n)

    for r in 1:state.n
        for c in 1:state.n
            kleur = if state.blacked[r,c]
                if has_black_adjacent(state, r, c) == true
                    :red
                elseif has_black_adjacent(state, r, c) == false
                    :black
                end
            else
                    :white
            end
        
            poly!(ax,
                Rect(c-1, state.n - r, 1, 1),
                color = kleur,
                strokecolor = :black,
                strokewidth = 1
            )
        end
    end

    for r in 1:state.n
        for c in 1:state.n
            if state.blacked[r, c] == false
                text!(ax,
                    string(state.grid[r, c]),
                    position = (c - 0.5, state.n - r + 0.5),
                    align = (:center, :center),
                    fontsize = 20
                )
            end
        end
    end
end

"""
        show_victory(ax::Axis, fig::Figure)
# Argumenten
- ax: Axis, het assenstelsel waarin het bord getekend is
- fig: de figuur die in de GLMakie terminal gemaakt wordt

# Resultaat
- Maakt het spelbord groen en zorgt ervoor dat de speler weet wanneer die gewonnen is.
"""
function show_victory!(ax, fig)
    empty!(ax)
    ax.limits = (0, 1, 0, 1)
    ax.backgroundcolor = :green

    text!(ax,
    "U heeft gewonnen!", 
    position = (0.5,0.5),
    align = (:center, :center),
    fontsize = 50,
    color = :white
    )
end

"""
        on_click!(ax::Axis, fig::Figure, state::Gamestate)
# Argumenten
- ax: Axis, het assenstelsel waarin het bord getekend is
- fig: de figuur die in de GLMakie terminal gemaakt wordt

# Resultaat
- Deze functie zorgt ervoor dat wanneer de speler op een vakje klikt, het zwart wordt.
- Wanneer de speler nog eens op een vakje klikt wordt het terug wit en is het overspronkelijke cijfer van dat vakje terug zichtbaar in het desbetreffende vakje.
"""
function on_click!(ax, fig, state::GameState)
    on(events(fig).mousebutton) do event
        if event.button == Mouse.left && event.action == Mouse.press
            pixel_pos = events(fig).mouseposition[]
            w, h = size(fig.scene)

            # Controleer of de klik binnen de axis valt
            ax_origin = pixelarea(ax.scene)[]
            ax_x = ax_origin.origin[1]
            ax_y = ax_origin.origin[2]
            ax_w = ax_origin.widths[1]
            ax_h = ax_origin.widths[2]

            if ax_x <= pixel_pos[1] <= ax_x + ax_w &&
               ax_y <= pixel_pos[2] <= ax_y + ax_h

                # Zet pixelpositie om naar gridcoördinaten
                c = Int(floor((pixel_pos[1] - ax_x) / ax_w * state.n)) + 1
                r = Int(floor((1 - (pixel_pos[2] - ax_y) / ax_h) * state.n)) + 1

                if 1 <= r <= state.n && 1 <= c <= state.n
                    state.blacked[r, c] = !state.blacked[r, c]
                    draw_board!(ax, state)
                    if is_valid(state)
                        state.solved = true
                        show_victory!(ax, fig)
                    end
                end
            end
        end
    end
end

function save_game(state::GameState, bestandsnaam::String = "savegame.txt")
    open(bestandsnaam, "w") do f
        # Grootte van het grid
        println(f, state.n)

        # Het grid rij per rij printen in het txt-bestand
        for r in 1:state.n
            rij = state.grid[r, :]
            rij_tekst = join(rij," ")
            println(f,rij_tekst)
        end

        # Zwarte cellen rij per rij printen in het txt-bestand
        for r in 1:state.n
            zwarte_rij = state.blacked[r, :]
            zwarte_rij_int = Int.(zwarte_rij)
            zwarte_rij_tekst = join(zwarte_rij_int," ")
            println(f, zwarte_rij_tekst)
        end

        # De oplossing rij per rij printen in het txt-bestand
        for r in 1:state.n
            opl_rij = state.solution[r,:]
            opl_rij_tekst = join(opl_rij, " ")
            println(f,opl_rij_tekst)
        end
    end
    println("Spel opgeslagen in $bestandsnaam")
end



function load_game(bestandsnaam::String = "savegame.txt")::GameState
    open(bestandsnaam, "r") do f
        # Lees gridgrootte
        n = parse(Int, readline(f))

        # Lees het grid zelf
        grid = zeros(Int, n, n)
        for r in 1:n
            rij_tekst = readline(f)
            rij_waarden = split(rij_tekst)
            grid[r, :] = parse.(Int, rij_waarden)
        end

        # Lees zwarte vakjes in het grid
        blacked = zeros(Bool, n, n)
        for r in 1:n
            zwarte_tekst = readline(f)
            zwarte_waarden = split(zwarte_tekst)
            blacked[r, :] = Bool.(parse.(Int, zwarte_waarden))
        end

        # Lees de oplossing
        solution = zeros(Int, n, n)
        for r in 1:n
            oplossing_tekst = readline(f)
            oplossing_waarden = split(oplossing_tekst)
            solution[r, :] = parse.(Int, oplossing_waarden)
        end

        return GameState(n, grid, blacked, false, solution)
    end
end

function run_game(n::Int = 5)
    state = new_game(n)
    fig = Figure(size = (950, 600))

    # Kolom 1: De spelregels
    ax_tekst = Axis(fig[1, 1])
    hidedecorations!(ax_tekst)
    hidespines!(ax_tekst)
    ax_tekst.limits = (0, 1, 0, 1)

    text!(ax_tekst, "Regels",
        position = (0.5, 0.9),
        align = (:center, :center),
        fontsize = 16,
        font = :bold
    )

    text!(ax_tekst, "1. Geen zelfde getallen \nin dezelfde rij of kolom.",
        position = (0.5, 0.7),
        align = (:center, :center),
        fontsize = 13
    )

    text!(ax_tekst, "2. Geen twee zwarte \nvakjes naast elkaar.",
        position = (0.5, 0.5),
        align = (:center, :center),
        fontsize = 13
    )

    text!(ax_tekst, "3. Alle witte vakjes\nmoeten verbonden zijn.",
        position = (0.5, 0.3),
        align = (:center, :center),
        fontsize = 13
    )
    colsize!(fig.layout, 1, Fixed(200))

    # Kolom 2: het grid
    ax = Axis(fig[1, 2], limits = (0, n, 0, n))
    hidedecorations!(ax)
    hidespines!(ax)


    # Kolom 3: de knoppen
    knop_nieuw     = Button(fig[1, 3][1, 1], label = "Nieuw spel")
    knop_herstart  = Button(fig[1, 3][2, 1], label = "Herstart spel")
    menu = Menu(fig[1,3][5,1], options = ["5x5", "6x6", "8x8", "10x10", "12x12"])
    knop_opslaan = Button(fig[1, 3][4,1], label = "Opslaan")
    knop_laden = Button(fig[1,3][3,1], label = "Spel laden")

    on(menu.selection) do selectie
        nieuwe_n = parse(Int, split(selectie, "x")[1])
        new_state = new_game(nieuwe_n)
        state.n = new_state.n
        state.grid = new_state.grid
        state.blacked = new_state.blacked
        state.solved = false
        state.solution = new_state.solution
        empty!(ax)
        ax.limits = (0, nieuwe_n, 0, nieuwe_n)
        draw_board!(ax, state)
    end


    on(knop_nieuw.clicks) do _
        new_state = new_game(state.n)
        state.n = new_state.n
        state.grid = new_state.grid
        state.blacked = new_state.blacked
        state.solved = false
        state.solution = new_state.solution
        empty!(ax)
        ax.limits = (0, new_state.n, 0, new_state.n)
        draw_board!(ax, state)
    end

    on(knop_herstart.clicks) do _
        state.blacked = zeros(Bool, state.n, state.n)
        state.solved = false
        empty!(ax)
        ax.limits = (0, state.n, 0, state.n)
        draw_board!(ax, state)
    end

    on(knop_opslaan.clicks) do _
        pad = joinpath(@__DIR__, "savegame.txt")
        save_game(state, pad)
    end

    on(knop_laden.clicks) do _
        pad = joinpath(@__DIR__, "savegame.txt")
        if isfile(pad)
            geladen = load_game(pad)
            state.n = geladen.n
            state.grid = geladen.grid
            state.blacked = geladen.blacked
            state.solved = geladen.solved
            state.solution = geladen.solution
            empty!(ax)
            ax.limits = (0, state.n, 0, state.n)
            draw_board!(ax, state)
            println("Spel geladen!")
        else
            println("Geen opgeslagen spel gevonden")
        end
    end

    
    colsize!(fig.layout, 2, Fixed(600)) # Breedt van kolom 2: het bord
    rowsize!(fig.layout, 1, Fixed(600)) # Alles staat op rij 1 en heeft bijgevolg een hoogte 600
    colsize!(fig.layout, 3, Fixed(150)) # Breedte van kolom 3: de knoppen

    
    draw_board!(ax, state)
    on_click!(ax, fig, state)
    display(fig)
    return fig, ax, state
end



fig, ax, state = run_game(5)