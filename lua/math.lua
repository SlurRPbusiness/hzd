---@meta

---@class math: mathlib
math = math

local hasGlm, glm = pcall(require, "glm")
math.glm = hasGlm and glm or nil

local DEG_TO_RAD <const> = math.pi / 180
local RAD_TO_DEG <const> = 180 / math.pi

local COMPACT_SUFFIXES <const> = {
    "", "K", "M", "B", "T",
    "Qa", "Qi", "Sx", "Sp",
    "Oc", "No", "Dc"
}

--#region Core

---Controlla che un valore sia un numero finito.
---@param value any
---@return boolean
function math.isFinite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

---Limita un valore all'intervallo inclusivo.
---@param value number
---@param minimum number
---@param maximum number
---@return number
function math.clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end
    return value
end

---Restituisce il segno di un numero (-1, 0, 1).
---@param value number
---@return integer
function math.sign(value)
    return value > 0 and 1 or value < 0 and -1 or 0
end

---Controlla se un valore rientra nell'intervallo inclusivo.
---@param value number
---@param minimum number
---@param maximum number
---@return boolean
function math.isInRange(value, minimum, maximum)
    return math.clamp(value, minimum, maximum) == value
end

---@param x number
---@return number
function math.log10(x)
    return math.log(x, 10)
end

--#endregion

--#region Interpolation

---Interpola tra due valori; amount può uscire dall'intervallo 0..1.
---@param from number
---@param to number
---@param amount number
---@return number
function math.lerp(from, to, amount)
    return from + (to - from) * amount
end

---Inverso di lerp: indica dove si trova value tra from e to (0..1 se interno).
---@param from number
---@param to number
---@param value number
---@return number
function math.invLerp(from, to, value)
    if from == to then
        return 0
    end

    return (value - from) / (to - from)
end

---Interpola uniformemente tra due valori con easing.
---@param from number
---@param to number
---@param amount number
---@return number
function math.smoothstep(from, to, amount)
    amount = math.clamp(amount, 0.0, 1.0)

    return math.lerp(from, to, amount * amount * (3.0 - 2.0 * amount))
end

---Rimappa un valore da un intervallo a un altro.
---@param value number
---@param inMin number
---@param inMax number
---@param outMin number
---@param outMax number
---@return number
function math.map(value, inMin, inMax, outMin, outMax)
    return math.lerp(outMin, outMax, math.invLerp(inMin, inMax, value))
end

---Avvicina un valore al target senza superarlo.
---@param current number
---@param target number
---@param maximumDelta number
---@return number
function math.moveTowards(current, target, maximumDelta)
    assert(maximumDelta >= 0, "maximumDelta must be non-negative")

    local difference = target - current

    if math.abs(difference) <= maximumDelta then
        return target
    end

    return current + math.sign(difference) * maximumDelta
end

--#endregion

--#region Percentages & Chance

---Calcola una percentuale rispetto a un valore massimo.
---@param value number
---@param maximum number
---@return number
function math.percent(value, maximum)
    return maximum == 0 and 0 or (value / maximum) * 100
end

---Verifica una probabilità percentuale.
---@param percentage number
---@return boolean
function math.chance(percentage)
    return math.percent(math.random(), 1) < math.clamp(percentage, 0, 100)
end

--#endregion

--#region Rounding & Formatting

---Tronca un numero a un dato numero di cifre decimali senza arrotondare.
---@param value number
---@param decimalPlaces? integer
---@return number
function math.truncate(value, decimalPlaces)
    assert(type(value) == "number", "value must be a number")

    decimalPlaces = decimalPlaces or 0
    assert(type(decimalPlaces) == "number" and decimalPlaces % 1 == 0, "decimalPlaces must be an integer")

    local factor = 10 ^ decimalPlaces

    return (math.modf(value * factor)) / factor
end

---Arrotonda (half away from zero) a un numero opzionale di cifre decimali.
---@param value number
---@param decimalPlaces? integer
---@return number
function math.round(value, decimalPlaces)
    assert(type(value) == "number", "value must be a number")

    if not math.isFinite(value) then
        return value
    end

    decimalPlaces = decimalPlaces or 0

    local factor = 10 ^ decimalPlaces

    return math.truncate(value * factor + math.sign(value) * 0.5) / factor
end

---Formatta un numero con precisione decimale.
---@param value number
---@param decimalPlaces? integer
---@return string
function math.format(value, decimalPlaces)
    return string.format("%." .. (decimalPlaces or 0) .. "f", value)
end

---Abbrevia un numero grande (1500 -> 1.5K).
---@param value number
---@param decimalPlaces? integer
---@return string
function math.compact(value, decimalPlaces)
    assert(math.isFinite(value), "value must be a finite number")

    decimalPlaces = decimalPlaces or 1
    assert(decimalPlaces >= 0 and decimalPlaces % 1 == 0, "decimalPlaces must be a non-negative integer")

    if math.abs(value) < 1000 then
        return tostring(value)
    end

    local index = math.floor(math.log10(math.abs(value)) / 3)
    local scaled = math.round(value / 1000 ^ index, decimalPlaces)

    -- 999999 -> 1000.0K: l'arrotondamento può sforare, quindi si passa al suffisso successivo
    if math.abs(scaled) >= 1000 then
        index = index + 1
        scaled = math.round(value / 1000 ^ index, decimalPlaces)
    end

    local text = math.format(scaled, decimalPlaces)

    if decimalPlaces > 0 then
        text = text:gsub("%.?0+$", "")
    end

    return text .. (COMPACT_SUFFIXES[index + 1] or ("e%d"):format(index * 3))
end

--#endregion

--#region Statistics

---Restituisce la somma degli elementi.
---@param ... number
---@return number
function math.sum(...)
    local total = 0

    for _, value in ipairs({ ... }) do
        total = total + value
    end

    return total
end

---Restituisce la media aritmetica degli elementi.
---@param ... number
---@return number
function math.average(...)
    local count = select("#", ...)

    assert(count > 0, "average requires at least one value")

    return math.sum(...) / count
end

---Restituisce il valore massimo tra quelli forniti.
---@type fun(...: number): number
math.highest = math.max

---Restituisce il valore minimo tra quelli forniti.
---@type fun(...: number): number
math.lowest = math.min

--#endregion

--#region Trigonometry & GLM

---Calcola contemporaneamente seno e coseno in un'unica operazione CPU.
---Supporta sia numeri (float) che vector3 (rotazioni).
---Usa la libreria C++ GLM di FiveM se disponibile, con fallback su Lua standard.
---@generic T: number | vector3
---@param angle T
---@return T sin
---@return T cos
function math.sincos(angle)
    if glm then
        return glm.sincos(angle)
    end

    if type(angle) == "vector3" then
        local x, y, z = angle.z, angle.y, angle.z
        return vec3(math.sin(x), math.sin(y), math.sin(z)), vec3(math.cos(x), math.cos(y), math.cos(z))
    end

    return math.sin(angle), math.cos(angle)
end

---Converte gradi in radianti. Supporta sia number che vector3.
---@generic T: number | vector3
---@param angle T
---@return T
function math.rad(angle)
    return glm and glm.rad(angle) or angle * DEG_TO_RAD
end

---Converte radianti in gradi. Supporta sia number che vector3.
---@generic T: number | vector3
---@param angle T
---@return T
function math.deg(angle)
    return glm and glm.deg(angle) or angle * RAD_TO_DEG
end

---Alias di math.rad.
---@type fun(degrees: number): number
math.toRadians = math.rad

---Alias di math.deg.
---@type fun(radians: number): number
math.toDegrees = math.deg

---Converte un heading in un vettore direzionale 2D.
---@param heading number
---@return vector2
function math.headingToDirection(heading)
    local sin, cos = math.sincos(math.rad(heading))

    return vec2(-sin, cos)
end

---Converte una rotazione angolare (in gradi) in un vettore di direzione 3D (forward vector).
---Ideale per raycasting, telecamere (GetGameplayCamRot) e traiettorie di sparo.
---@param rotation vector3
---@return vector3
function math.rotationToDirection(rotation)
    local sin, cos = math.sincos(math.rad(rotation))
    local horizontal = math.abs(cos.x)

    return vector3(-sin.z * horizontal, cos.z * horizontal, sin.x)
end

--#endregion

--#region Geometry

---Calcola il quadrato della distanza tra due punti 3D (evita la radice).
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return number
function math.distanceSquared3D(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1

    return dx * dx + dy * dy + dz * dz
end

---Calcola la distanza euclidea tra due punti 3D.
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return number
function math.distance3D(x1, y1, z1, x2, y2, z2)
    return math.sqrt(math.distanceSquared3D(x1, y1, z1, x2, y2, z2))
end

---Calcola la distanza euclidea tra due punti 2D.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
function math.distance2D(x1, y1, x2, y2)
    return math.distance3D(x1, y1, 0, x2, y2, 0)
end

--#endregion

--#region Random

---Genera un numero intero casuale nell'intervallo inclusivo.
---@param minimum integer
---@param maximum integer
---@return integer
function math.randomInt(minimum, maximum)
    assert(type(minimum) == "number" and minimum % 1 == 0, "minimum must be an integer")
    assert(type(maximum) == "number" and maximum % 1 == 0, "maximum must be an integer")
    assert(minimum <= maximum, "minimum must be less than or equal to maximum")

    return math.random(minimum, maximum)
end

---Genera un numero float casuale nell'intervallo [minimum, maximum).
---@param minimum number
---@param maximum number
---@return number
function math.randomFloat(minimum, maximum)
    return math.lerp(minimum, maximum, math.random())
end

--#endregion

--#region PvP

local dot <const> = glm and glm.dot or function(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local cross <const> = glm and glm.cross or function(a, b)
    return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

---Calcola l'angolo in gradi tra due vettori direzionali.
---@param a vector3
---@param b vector3
---@return number
function math.angleBetween(a, b)
    local lengths = #a * #b

    if lengths == 0 then
        return 0
    end

    return math.deg(math.acos(math.clamp(dot(a, b) / lengths, -1, 1)))
end

---Controlla se un bersaglio è dentro il cono di visione (senza acos, solo un dot).
---`forward` deve essere normalizzato (rotationToDirection lo è già).
---@param origin vector3
---@param forward vector3
---@param target vector3
---@param fieldOfView number gradi totali del cono
---@return boolean
function math.isInFieldOfView(origin, forward, target, fieldOfView)
    local toTarget = target - origin
    local distance = #toTarget

    if distance == 0 then
        return true
    end

    return dot(forward, toTarget) / distance >= math.cos(math.rad(fieldOfView * 0.5))
end

---Intersezione raggio/sfera (hitbox semplificata).
---Restituisce la distanza lungo il raggio, oppure nil se il raggio manca la sfera.
---`direction` deve essere normalizzato.
---@param origin vector3
---@param direction vector3
---@param center vector3
---@param radius number
---@return number?
function math.raySphereIntersect(origin, direction, center, radius)
    local offset = center - origin
    local projection = dot(offset, direction)
    local radiusSquared = radius * radius
    local missSquared = dot(offset, offset) - projection * projection

    if missSquared > radiusSquared then
        return nil
    end

    local halfChord = math.sqrt(radiusSquared - missSquared)
    local near = projection - halfChord

    if near >= 0 then
        return near
    end

    local far = projection + halfChord

    return far >= 0 and far or nil
end

---Distanza minima tra un punto e un raggio (se il punto è dietro l'origine, distanza dall'origine).
---`direction` deve essere normalizzato.
---@param origin vector3
---@param direction vector3
---@param point vector3
---@return number
function math.distanceToRay(origin, direction, point)
    local offset = point - origin

    if dot(offset, direction) < 0 then
        return #offset
    end

    return #cross(offset, direction)
end

---Tempo d'intercettazione di un proiettile a velocità costante contro un bersaglio in movimento.
---Restituisce nil se il bersaglio non è raggiungibile.
---@param shooterPosition vector3
---@param targetPosition vector3
---@param targetVelocity vector3
---@param projectileSpeed number
---@return number?
function math.interceptTime(shooterPosition, targetPosition, targetVelocity, projectileSpeed)
    local offset = targetPosition - shooterPosition

    local a = dot(targetVelocity, targetVelocity) - projectileSpeed * projectileSpeed
    local b = 2 * dot(offset, targetVelocity)
    local c = dot(offset, offset)

    -- velocità uguali: l'equazione diventa lineare
    if math.abs(a) < 1e-6 then
        if b == 0 then
            return nil
        end

        local time = -c / b
        return time > 0 and time or nil
    end

    local discriminant = b * b - 4 * a * c

    if discriminant < 0 then
        return nil
    end

    local root = math.sqrt(discriminant)
    local first, second = (-b - root) / (2 * a), (-b + root) / (2 * a)

    if first > second then
        first, second = second, first
    end

    return first > 0 and first or second > 0 and second or nil
end

---Punto in cui mirare per colpire un bersaglio in movimento con un proiettile.
---@param shooterPosition vector3
---@param targetPosition vector3
---@param targetVelocity vector3
---@param projectileSpeed number
---@return vector3?
function math.leadPosition(shooterPosition, targetPosition, targetVelocity, projectileSpeed)
    local time = math.interceptTime(shooterPosition, targetPosition, targetVelocity, projectileSpeed)

    return time and (targetPosition + targetVelocity * time) or nil
end

---Angolo in gradi tra dove guarda la camera e la direzione verso il bersaglio.
---Utile lato server per rilevare aimbot / silent aim.
---@param cameraRotation vector3
---@param origin vector3
---@param target vector3
---@return number
function math.aimDeviation(cameraRotation, origin, target)
    return math.angleBetween(math.rotationToDirection(cameraRotation), target - origin)
end

--#endregion
