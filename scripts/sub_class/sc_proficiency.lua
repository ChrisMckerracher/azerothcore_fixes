Proficiency = {}
Proficiency.__index = Proficiency

function Proficiency:new(skill, spell, ignore_classes)
    local instance = {}
    setmetatable(instance, Proficiency)
    instance.skill = skill
    instance.spell = spell
    instance.ignore_classes = ignore_classes
    return instance
end

function Proficiency:Register(player)
    if item_exists(self.ignore_classes, player:GetClassAsString()) then
        return
    end

    player:SetSkill(self.skill, 0, 1, 1)
    player:LearnSpell(self.spell.spell_id)
end

function Proficiency:Register(player)
    if item_exists(self.ignore_classes, player:GetClassAsString()) then
        return
    end

    -- Weapon skills must be relearned
    player:SetSkill(self.skill, 0, 1, 1)
    player:LearnSpell(self.spell.spell_id)
end

function Proficiency:Deregister(player)
    if item_exists(self.ignore_classes, player:GetClassAsString()) then
        return
    end
    player:SetSkill(self.skill, 0, 0, 0)
    player:RemoveSpell(self.spell.spell_id)
end

-- leather
leather_proficiency = Proficiency:new(414, leather, {})
-- mail: ToDo: for now you'll have to lose mail as shaman and hunter when you change subclass between those 2
mail_proficiency = Proficiency:new(413, mail, {})
-- plate
plate_proficiency = Proficiency:new(293, plate, {
    CLASS_WARRIOR,
    CLASS_PALADIN,
})

--shield ToDo: does not support block atm, as we need custom rules around this
shield_proficiency = Proficiency:new(433, shield, {})
block_proficiency = Proficiency:new(433, block, {})

fist_proficiency = Proficiency:new(473, fist_weapons, {})

dagger_proficiency = Proficiency:new(173, daggers, {})

one_hand_sword_proficiency = Proficiency:new(43, one_handed_swords, {})

two_handed_sword_proficiency = Proficiency:new(55, two_handed_swords, {})

one_handed_axe_proficiency = Proficiency:new(44, one_handed_axes, {})

two_hand_axe_proficiency = Proficiency:new(172, two_handed_axes, {})

one_hand_mace_proficiency = Proficiency:new(54, one_handed_maces, {})

two_handed_mace_proficiency = Proficiency:new(160, two_handed_maces, {})

polearm_proficiency = Proficiency:new(229, polearms, {})

staff_proficiency = Proficiency:new(136, staves, {})

bow_proficiency = Proficiency:new(45, bows, {})

crossbow_proficiency = Proficiency:new(226, crossbows, {})

gun_proficiency = Proficiency:new(46, guns, {})

thrown_proficiency = Proficiency:new(176, thrown, {})

wand_proficiency = Proficiency:new(228, wands, {})
