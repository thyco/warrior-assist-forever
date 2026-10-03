local addonName, addon = ...

addon.name = addonName
addon.features = {}
addon.started = false

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end
