SubClassLevelRange = {}
SubClassLevelRange.__index = SubClassLevelRange
function SubClassLevelRange:new(level, spells, proficiencies)
    local instance = {}
    setmetatable(instance, SubClassLevelRange)
    instance.level = level
    instance.spells = spells
    instance.proficiencies = proficiencies
    return instance
end

SubClass = {}
SubClass.__index = SubClass

-- ToDo: Implement proficiencies, Registration and Deregistration, with careful attention to dereg
function SubClass:new(name, spell_level_ranges, mandatory_items)
    local instance = {}
    setmetatable(instance, SubClass)
    instance.name = name
    instance.spell_level_ranges = spell_level_ranges
    instance.mandatory_items = mandatory_items
    return instance
end

-- Because Player is a builtin concept in Eluna, I'm not sure I can extend it. Instead Subclass Registers the Player. Like a shitty listener pattern
function SubClass:Register(player)
    if player:GetClassAsString() ~= self.name then
        local spells_to_register = self:GetSpells(player:GetLevel())
        for _, v in ipairs(spells_to_register) do
            if v.class ~= player_class then
                RegisterSpellEvent(v.spell_id, 1, OnPrepare)
            end
            player:LearnSpell(v.spell_id)
        end

        local proficiencies = self:GetProficiencies(player:GetLevel())
        for _, v in ipairs(proficiencies) do
            v:Register(player)
        end
    end
end

-- Because Player is a builtin concept in Eluna, instead Subclass Deregisters the Player. Like a shitty listener pattern
function SubClass:Deregister(player)
    local player_class = player:GetClassAsString()
    local spells_to_register = self:GetSpells(player:GetLevel())
    for _, v in ipairs(spells_to_register) do
        -- Some subclasses may be amalgamations of other classes, we don't want to remove an overlapped spell with the actual players mainclass spell
        if v.class ~= player_class then
            player:RemoveSpell(v.spell_id)
        end
    end

    local proficiencies = self:GetProficiencies(player:GetLevel())
    for _, v in ipairs(proficiencies) do
        v:Deregister(player)
    end
end

function SubClass:GetSpells(max_level)
    local spells = {}
    for _, v in ipairs(self.spell_level_ranges) do
        if v.level <= max_level then
            spells = append(spells, v.spells)
        end
    end
    return spells
end

function SubClass:GetProficiencies(max_level)
    local proficiencies = {}
    for _, v in ipairs(self.spell_level_ranges) do
        if v.level <= max_level then
            proficiencies = append(proficiencies, v.proficiencies)
        end
    end
    return proficiencies
end

LEVEL_1_SUBCLASS_PROFICIENCIES = {
    leather_proficiency,
    mail_proficiency,
    shield_proficiency,
    block_proficiency,
    fist_proficiency,
    dagger_proficiency,
    one_hand_sword_proficiency,
    two_handed_sword_proficiency,
    one_handed_axe_proficiency,
    two_hand_axe_proficiency,
    one_hand_mace_proficiency,
    two_handed_mace_proficiency,
    polearm_proficiency,
    staff_proficiency,
    bow_proficiency,
    crossbow_proficiency,
    gun_proficiency,
    thrown_proficiency,
    wand_proficiency
}

SUBCLASS_MAGE = SubClass:new(CLASS_MAGE, {
    SubClassLevelRange:new(1, {}, LEVEL_1_SUBCLASS_PROFICIENCIES),
    -- Fast, disruptive control mage: keep the spellbook lean and favor instant casts over buff clutter.
    SubClassLevelRange:new(6, {
        fire_blast_r1
    }, {}),
    SubClassLevelRange:new(8, {
        arcane_missiles_r1,
        polymorph_r1
    }, {}),
    SubClassLevelRange:new(14, {
        fire_blast_r2,
        arcane_explosion_r1
    }, {}),
    SubClassLevelRange:new(16, {
        arcane_missiles_r2
    }, {}),
    SubClassLevelRange:new(20, {
        polymorph_r2,
        blink_r1
    }, {})
})

SUBCLASS_WARLOCK = SubClass:new(CLASS_WARLOCK, {
    SubClassLevelRange:new(1, {}, LEVEL_1_SUBCLASS_PROFICIENCIES),
    SubClassLevelRange:new(4, {
        corruption_r1,
        curse_of_weakness_r1
    }, {}),
    -- Attrition warlock: stack rot effects and sustain through drains, with no fear or life tap clutter.
    SubClassLevelRange:new(8, {
        curse_of_agony_r1
    }, {}),
    SubClassLevelRange:new(10, {
        drain_soul_r1
    }, {}),
    SubClassLevelRange:new(12, {
        curse_of_weakness_r2
    }, {}),
    SubClassLevelRange:new(14, {
        drain_life_r1,
        corruption_r2
    }, {}),
    SubClassLevelRange:new(18, {
        curse_of_agony_r2
    }, {})
})

SUBCLASS_PRIEST = SubClass:new(CLASS_PRIEST, {
    SubClassLevelRange:new(1, {
        power_word_fortitude_r1
    }, LEVEL_1_SUBCLASS_PROFICIENCIES),
    -- Support priest: shields, HoTs, buffs, and just enough pressure and peel to protect the little party machine.
    SubClassLevelRange:new(4, {
        shadow_word_pain_r1
    }, {}),
    SubClassLevelRange:new(6, {
        power_word_shield_r1
    }, {}),
    SubClassLevelRange:new(8, {
        renew_r1
    }, {}),
    SubClassLevelRange:new(10, {
        shadow_word_pain_r2
    }, {}),
    SubClassLevelRange:new(12, {
        power_word_shield_r2,
        power_word_fortitude_r2
    }, {}),
    SubClassLevelRange:new(14, {
        cure_disease_r1,
        renew_r2,
        psychic_scream_r1
    }, {}),
    SubClassLevelRange:new(18, {
        dispel_magic_r1,
        power_word_shield_r3,
        shadow_word_pain_r3
    }, {}),
    SubClassLevelRange:new(20, {
        renew_r3
    }, {})
})

SUBCLASS_SHAMAN = SubClass:new(CLASS_SHAMAN, {
    SubClassLevelRange:new(1, {
        rockbiter_weapon_r1
    }, LEVEL_1_SUBCLASS_PROFICIENCIES),
    -- Self-buff shock shaman: no totems, no cast-bar filler, just imbues, shields, shocks, and rude interference.
    SubClassLevelRange:new(4, {
        earth_shock_r1
    }, {}),
    SubClassLevelRange:new(8, {
        rockbiter_weapon_r2,
        lightning_shield_r1,
        earth_shock_r2
    }, {}),
    SubClassLevelRange:new(10, {
        flametongue_weapon_r1,
        flame_shock_r1
    }, {}),
    SubClassLevelRange:new(12, {
        purge_r1
    }, {}),
    SubClassLevelRange:new(14, {
        earth_shock_r3
    }, {}),
    SubClassLevelRange:new(16, {
        lightning_shield_r2,
        rockbiter_weapon_r3,
        wind_shear_r1
    }, {}),
    SubClassLevelRange:new(18, {
        flametongue_weapon_r2,
        flame_shock_r2
    }, {}),
    SubClassLevelRange:new(20, {
        frostbrand_weapon_r1,
        frost_shock_r1
    }, {})
})

SUBCLASS_DRUID = SubClass:new(CLASS_DRUID, {
    SubClassLevelRange:new(1, {}, LEVEL_1_SUBCLASS_PROFICIENCIES),
    SubClassLevelRange:new(4, {
        rejuvenation_r1
    }, {}),
    -- Support-cat druid: light HoTs and prickly protection first, with cat form as a playful side mode rather than full feral takeover.
    SubClassLevelRange:new(6, {
        thorns_r1
    }, {}),
    SubClassLevelRange:new(10, {
        rejuvenation_r2
    }, {}),
    SubClassLevelRange:new(14, {
        thorns_r2
    }, {}),
    SubClassLevelRange:new(16, {
        rejuvenation_r3
    }, {}),
    SubClassLevelRange:new(20, {
        cat_form,
        claw_r1,
        rip_r1
    }, {})
})

SUBCLASS_HUNTER = SubClass:new(CLASS_HUNTER, {
    SubClassLevelRange:new(1, {}, LEVEL_1_SUBCLASS_PROFICIENCIES),
    SubClassLevelRange:new(2, {
        track_beasts_r1
    }, {}),
    -- Tracker-trapper hunter: mark prey, reveal movement, and turn the battlefield into a nuisance machine.
    SubClassLevelRange:new(6, {
        hunters_mark_r1,
        arcane_shot_r1
    }, {}),
    SubClassLevelRange:new(8, {
        concussive_shot_r1
    }, {}),
    SubClassLevelRange:new(10, {
        track_humanoids_r1
    }, {}),
    SubClassLevelRange:new(12, {
        distracting_shot_r1
    }, {}),
    SubClassLevelRange:new(16, {
        immolation_trap_r1
    }, {}),
    SubClassLevelRange:new(18, {
        track_undead_r1
    }, {}),
    SubClassLevelRange:new(20, {
        freezing_trap_r1
    }, {})
})

SUBCLASS_PALADIN = SubClass:new(CLASS_PALADIN, {
    SubClassLevelRange:new(1, {
        devotion_aura_r1
    }, LEVEL_1_SUBCLASS_PROFICIENCIES),
    -- Warder paladin: an off-tank bodyguard kit built around peel, threat pickup, and holding ground.
    SubClassLevelRange:new(6, {
        divine_protection_r1
    }, {}),
    SubClassLevelRange:new(8, {
        hammer_of_justice_r1
    }, {}),
    SubClassLevelRange:new(10, {
        hand_of_protection_r1,
        devotion_aura_r2
    }, {}),
    SubClassLevelRange:new(14, {
        righteous_defense_r1
    }, {}),
    SubClassLevelRange:new(16, {
        righteous_fury_r1,
        hand_of_reckoning_r1
    }, {}),
    SubClassLevelRange:new(18, {
        hand_of_freedom_r1
    }, {}),
    SubClassLevelRange:new(20, {
        devotion_aura_r3,
        consecration_r1
    }, {})
})

SUBCLASS_WARRIOR = SubClass:new(CLASS_WARRIOR, {
    SubClassLevelRange:new(1, {
        battle_stance,
        warrior_parry
    }, LEVEL_1_SUBCLASS_PROFICIENCIES),
    -- Tactician warrior: a disciplined control fighter built around engagement, stance play, and enemy disruption.
    SubClassLevelRange:new(4, {
        charge_r1
    }, {}),
    SubClassLevelRange:new(6, {
        thunder_clap_r1
    }, {}),
    SubClassLevelRange:new(10, {
        defensive_stance
    }, {}),
    SubClassLevelRange:new(14, {
        demoralizing_shout_r1
    }, {}),
    SubClassLevelRange:new(16, {
        mocking_blow_r1
    }, {}),
    SubClassLevelRange:new(18, {
        thunder_clap_r2
    }, {})
})

SUBCLASS_ROGUE = SubClass:new(CLASS_ROGUE, {
    SubClassLevelRange:new(1, {}, LEVEL_1_SUBCLASS_PROFICIENCIES),
    SubClassLevelRange:new(4, {
        backstab_r1
    }, {}),
    -- Saboteur rogue: open-combat disruption built around weak-point strikes, evasive trickery, and breaking the enemy's setup.
    SubClassLevelRange:new(6, {
        gouge_r1
    }, {}),
    SubClassLevelRange:new(8, {
        evasion_r1
    }, {}),
    SubClassLevelRange:new(10, {
        sprint_r1
    }, {}),
    SubClassLevelRange:new(12, {
        kick_r1,
        backstab_r2
    }, {}),
    SubClassLevelRange:new(14, {
        expose_armor_r1
    }, {}),
    SubClassLevelRange:new(16, {
        feint_r1
    }, {}),
    SubClassLevelRange:new(20, {
        backstab_r3,
        dismantle
    }, {})
})

SUBCLASSES = {
    [CLASS_MAGE] = SUBCLASS_MAGE,
    [CLASS_WARLOCK] = SUBCLASS_WARLOCK,
    [CLASS_PRIEST] = SUBCLASS_PRIEST,
    [CLASS_SHAMAN] = SUBCLASS_SHAMAN,
    [CLASS_DRUID] = SUBCLASS_DRUID,
    [CLASS_HUNTER] = SUBCLASS_HUNTER,
    [CLASS_PALADIN] = SUBCLASS_PALADIN,
    [CLASS_WARRIOR] = SUBCLASS_WARRIOR,
    [CLASS_ROGUE] = SUBCLASS_ROGUE,
}
