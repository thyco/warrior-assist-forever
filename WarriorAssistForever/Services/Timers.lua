local _, addon = ...
local Timers = {}
addon.Timers = Timers

function Timers.New()
    local timer = {}

    function timer:SetDeadline(deadline, quality)
        self.deadline = deadline
        self.quality = quality
    end

    function timer:StartFrom(startedAt, duration, quality)
        self:SetDeadline(startedAt + duration, quality)
    end

    function timer:Clear()
        self.deadline = nil
        self.quality = nil
    end

    function timer:Remaining()
        return self.deadline and math.max(0, self.deadline - GetTime()) or nil
    end

    function timer:IsDue(lead)
        return self.deadline ~= nil and GetTime() >= self.deadline - lead
    end

    function timer:Quality()
        return self.quality
    end

    return timer
end
