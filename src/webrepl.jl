function web_show(user_id, p::Winston.PlotContainer)
    g = nothing
    try
        g = Winston.svg(p)
    catch err
        return __Message(__MSG_OUTPUT_EVAL_ERROR, {user_id, sprint(show,err)})
    end
    return __Message(__MSG_OUTPUT_HTML, {user_id, g})
end
