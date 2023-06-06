__api.add_cbs({
    control = function(cmtype, data)
        return true
    end,
})

__api.await(-1)
return "success"
