using GLMakie, GeoMakie, Downloads
using GeoJSON, GeoInterface, ColorSchemes
using HDF5, GeometryBasics, Proj4
using CSV, DataFrames

function toCartesian(lon, lat; r = 1.02, cxyz = (0,0,0) )
    x = cxyz[1] + r * cosd(lat) * cosd(lon)
    y = cxyz[2] + r * cosd(lat) * sind(lon)
    z = cxyz[3] + r *sind(lat)
    return x, y, z
end

function lonlat3D2(lon, lat; cxyz = (0,0,0))
    xyzw = zeros(length(lon), 3)
    for (i,lon) in enumerate(lon)
        x, y, z = toCartesian(lon, lat[i]; cxyz = cxyz)
        xyzw[i,1] = x
        xyzw[i,2] = y
        xyzw[i,3] = z
    end
    xyzw[:,1], xyzw[:,2], xyzw[:,3]
end


# https://www.kaggle.com/code/akshaychavan/average-temperature-per-country-per-year/data
year_country = CSV.read(assetpath("matYearCountry.csv"), DataFrame)
country_names = names(year_country)

country_to_temps = Dict(map(country_names) do name
    name => year_country[!, name]
end)

states_geo = GeoJSON.read(read(assetpath("countries.geojson"), String))
polys = geo2basic(states_geo)
n_temps = length(last(first(country_to_temps)))

begin
    poly_mapped = []
    temps = []
    for feat in features(states_geo)
        poly = geo2basic(feat)
        poly = poly isa Vector ? poly : [poly]
        meshes = []
        for p in poly
            m = GeometryBasics.triangle_mesh(p)
            x = first.(m.position)
            y = last.(m.position)
            xw, yw, zw = lonlat3D2(x, y)
            push!(meshes, GeometryBasics.Mesh(Point3f.(xw, yw, zw), faces(m)))
        end
        push!(poly_mapped, merge([meshes...]))
        name = feat.properties["name"]
        if name == "United States of America"
            name = "United States"
        end
        if haskey(country_to_temps, name)
            t = country_to_temps[name]
            if t isa Vector
                push!(temps, t .- t[1])
            else
                println("Not Vector: $(name)")
                push!(temps, fill(0f0, n_temps))
            end
        else
            println("Not found: $(name)")
            push!(temps, fill(0f0, n_temps))
        end
    end
end

function create_visual(idx_obs)
    fig = Figure(resolution = (1250,700), fontsize = 22)
    crange = extrema(vcat(temps...))
    color_values = lift(idx_obs) do idx
        return getindex.(temps, idx)
    end
    year = lift(idx_obs) do idx
        return "Year: $(year_country.year[idx])"
    end
    ax = LScene(fig[1,1]; show_axis = false)
    s = campixel(fig.scene)
    text!(s, year, position=(10, 700/2), space=:screen)
    # now the plot
    s = Sphere(Point3f(0), 1.03f0)
    sm = GeometryBasics.normal_mesh(Tesselation(s, 100))
    mesh!(sm, color = (:white, 0.35), transparency = true)
    mp = mesh!(ax, [poly_mapped...], colorrange=crange, color=color_values, colormap = [:blue, :gray, :red], strokecolor = :black, shading=false)
    Colorbar(fig[2, 1], mp; label = "temperature difference to 2000", vertical = false)
    fig
end
