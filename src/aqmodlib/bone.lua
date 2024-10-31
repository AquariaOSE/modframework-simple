
local function bone_copyPropertiesToBone(bfrom, bto)
    bone_setTexture(bto, bone_getTexture(bfrom))
    bone_setBlendType(bto, bone_getBlendType(bfrom))
    bone_scale(bto, bone_getScale(bfrom))
    bone_alpha(bto, bone_getAlpha(bfrom))
    bone_setVisible(bto, bone_isVisible(bfrom))
end

return {
    bone_copyPropertiesToBone = bone_copyPropertiesToBone,
}
