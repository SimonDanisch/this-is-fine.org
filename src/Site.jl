using JSServe
using Markdown
using Hyperscript
using JSServe: Asset, jsrender
using WGLMakie

library(name, paths...) = JSServe.Dependency(name, joinpath.(joinpath, "site", "libs", collect(paths)))
site_path(files...) = normpath(joinpath(@__DIR__, "..", "docs", files...))
markdown(files...) = joinpath(@__DIR__, "pages", "blogposts", files...)
assetpath(files...) = normpath(joinpath(@__DIR__, "..", "docs", files...))
asset(files...) = Asset(assetpath(files...))


function page(session)
    sl = JSServe.Slider(1:14; style="width: 500px; margin: 100")
    viz = create_visual(sl.value)
    banner = jsrender(session, DOM.img(src = asset("images", "header.png"), style="height: 200px; margin: auto"))
    style = """
        display: flex;
        align-items: center;
        justify-content: center;
        flex-direction: column;
        width: 1000px;
    """
    style2 = """
        display: flex;
        align-items: center;
        justify-content: center;
        flex-direction: column;
        width: 100%;
    """
    body = DOM.div(DOM.div(banner, viz, sl, style=style), class="outer-page", style=style2)
    return make_app(session, body)
end

function make_app(session, dom)
    return App() do session
        assets = asset.([
            "css/franklin.css",
            "css/makie.css",
            "css/minimal-mistakes.css",
            "css/style.css"])
        return JSServe.record_states(session, DOM.div(dom, assets...))
    end
end

function StaticSession()
    us = JSServe.UrlSerializer(false, site_path(), false, "", false)
    return Session(; url_serializer=us)
end

function show_html(io)
    s = StaticSession()
    app = page(s)
    show(io, MIME"text/html"(), Page(offline=true, exportable=true, session=s))
    show(io, MIME"text/html"(), app)
end

function make()
    open(joinpath(@__DIR__, "..", "docs", "index.html"), "w") do io
        session = StaticSession()
        show_html(io)
    end
end

make()
