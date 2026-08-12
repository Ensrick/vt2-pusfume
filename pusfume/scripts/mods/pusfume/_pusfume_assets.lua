local M = {}

-- The Ranger Veteran base animates the placeholder. Extra Skaven nodes remain
-- parented under these linked bones until the final Globadier rebind is ready.
M.third_person_attachment = {
    -- Link the generated DCC scene root so the mesh and armature move together.
    { source = "root_point", target = 0 },
    { source = "j_hips", target = "j_hips" },
    { source = "j_spine", target = "j_spine" },
    { source = "j_spine1", target = "j_spine1" },
    { source = "j_leftupleg", target = "j_upleg_L" },
    { source = "j_leftleg", target = "j_leg_L" },
    { source = "j_leftfoot", target = "j_foot_L" },
    { source = "j_lefttoebase", target = "j_toebase_L" },
    { source = "j_rightupleg", target = "j_upleg_R" },
    { source = "j_rightleg", target = "j_leg_R" },
    { source = "j_rightfoot", target = "j_foot_R" },
    { source = "j_righttoebase", target = "j_toebase_R" },
    { source = "j_neck", target = "j_neck" },
    { source = "j_head", target = "j_head" },
    { source = "j_leftshoulder", target = "j_shoulder_L" },
    { source = "j_leftarm", target = "j_arm_L" },
    { source = "j_leftforearm", target = "j_forearm_L" },
    { source = "j_leftforearm_roll", target = "j_forearmroll_L" },
    { source = "j_lefthand", target = "j_hand_L" },
    { source = "j_lefthandindex1", target = "j_handindex1_L" },
    { source = "j_lefthandindex2", target = "j_handindex2_L" },
    { source = "j_lefthandindex3", target = "j_handindex3_L" },
    { source = "j_lefthandmiddle1", target = "j_handmiddle1_L" },
    { source = "j_lefthandmiddle2", target = "j_handmiddle2_L" },
    { source = "j_lefthandmiddle3", target = "j_handmiddle3_L" },
    { source = "j_lefthandpinky1", target = "j_handpinky1_L" },
    { source = "j_lefthandpinky2", target = "j_handpinky2_L" },
    { source = "j_lefthandpinky3", target = "j_handpinky3_L" },
    { source = "j_lefthandring1", target = "j_handring1_L" },
    { source = "j_lefthandring2", target = "j_handring2_L" },
    { source = "j_lefthandring3", target = "j_handring3_L" },
    { source = "j_lefthandthumb1", target = "j_handthumb1_L" },
    { source = "j_lefthandthumb2", target = "j_handthumb2_L" },
    { source = "j_rightshoulder", target = "j_shoulder_R" },
    { source = "j_rightarm", target = "j_arm_R" },
    { source = "j_rightforearm", target = "j_forearm_R" },
    { source = "j_rightforearm_roll", target = "j_forearmroll_R" },
    { source = "j_righthand", target = "j_hand_R" },
    { source = "j_righthandindex1", target = "j_handindex1_R" },
    { source = "j_righthandindex2", target = "j_handindex2_R" },
    { source = "j_righthandindex3", target = "j_handindex3_R" },
    { source = "j_righthandmiddle1", target = "j_handmiddle1_R" },
    { source = "j_righthandmiddle2", target = "j_handmiddle2_R" },
    { source = "j_righthandmiddle3", target = "j_handmiddle3_R" },
    { source = "j_righthandpinky1", target = "j_handpinky1_R" },
    { source = "j_righthandpinky2", target = "j_handpinky2_R" },
    { source = "j_righthandpinky3", target = "j_handpinky3_R" },
    { source = "j_righthandring1", target = "j_handring1_R" },
    { source = "j_righthandring2", target = "j_handring2_R" },
    { source = "j_righthandring3", target = "j_handring3_R" },
    { source = "j_righthandthumb1", target = "j_handthumb1_R" },
    { source = "j_righthandthumb2", target = "j_handthumb2_R" },
}

-- Diagnostic bridge: preserve placement while the packaged controller drives
-- Pusfume's complete child skeleton. This isolates skin deformation from the
-- production Bardin-to-Pusfume bone bridge without removing that bridge.
M.root_animation_attachment = {
    { source = "root_point", target = 0 },
}

function M.install()
    if not AttachmentNodeLinking then
        return false
    end

    AttachmentNodeLinking.pusfume_third_person_attachment = M.third_person_attachment
    AttachmentNodeLinking.pusfume_root_animation_attachment = M.root_animation_attachment

    return true
end

return M
