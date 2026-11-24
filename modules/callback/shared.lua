---@meta

---@class callbacklib
---@field timeout integer
---@field registerServer fun(name: string, handler: fun(source: integer, ...: any): any): string
---@field registerClient fun(name: string, handler: fun(...: any): any): string
---@field server fun(name: string, ...: any): Promise<any>
---@field client fun(target: integer|string, name: string, ...: any): Promise<any>
---@field setTimeout fun(timeout: integer)

local callback = {
    timeout = 10000,
}

_ENV.callback = callback

---Configura il timeout predefinito delle callback remote.
---@param timeout integer
function callback.setTimeout(timeout)
    assertType("timeout", timeout, "integer")
    assert(timeout > 0, "timeout must be greater than zero")
    callback.timeout = timeout
end
