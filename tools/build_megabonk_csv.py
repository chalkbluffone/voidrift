import csv
from pathlib import Path

header = [
    "Weapon","Unlock","BaseBehavior","Types","ElementOrDamageType","SpecialOrCC","Tags","StrategySynergies",
    "DamageC","DamageU","DamageR","DamageE","DamageL",
    "ProjectileCountC","ProjectileCountU","ProjectileCountR","ProjectileCountE","ProjectileCountL",
    "ProjectileSpeedC","ProjectileSpeedU","ProjectileSpeedR","ProjectileSpeedE","ProjectileSpeedL",
    "SizeC","SizeU","SizeR","SizeE","SizeL",
    "DurationC","DurationU","DurationR","DurationE","DurationL",
    "CritChanceC","CritChanceU","CritChanceR","CritChanceE","CritChanceL",
    "CritDamageC","CritDamageU","CritDamageR","CritDamageE","CritDamageL",
    "BouncesC","BouncesU","BouncesR","BouncesE","BouncesL",
    "KnockbackC","KnockbackU","KnockbackR","KnockbackE","KnockbackL",
]

def weapon(
    name, unlock, behavior, types, element, special, tags, strategy,
    dmg, pc, ps=None, size=None, dur=None, cc=None, cd=None, bnc=None, kb=None
):
    def fill(seq):
        if seq is None:
            return ["", "", "", "", ""]
        if len(seq) != 5:
            raise ValueError(f"{name} field length !=5: {seq}")
        return ["" if v is None else v for v in seq]
    return {
        "Weapon": name,
        "Unlock": unlock,
        "BaseBehavior": behavior,
        "Types": types,
        "ElementOrDamageType": element,
        "SpecialOrCC": special,
        "Tags": tags,
        "StrategySynergies": strategy,
        "Damage": fill(dmg),
        "ProjectileCount": fill(pc),
        "ProjectileSpeed": fill(ps),
        "Size": fill(size),
        "Duration": fill(dur),
        "CritChance": fill(cc),
        "CritDamage": fill(cd),
        "Bounces": fill(bnc),
        "Knockback": fill(kb),
    }

weapons = [
    weapon("Sword","Starter melee","Short-range slash arc","Melee","None","None","melee;slash","Prioritize damage/count then size; knockback helps safety", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=None, size=["20%","24%","28%","32%","40%"], dur=None, cc=None, cd=None, bnc=None, kb=[0.5,0.6,0.7,0.8,1]),
    weapon("Flamewalker","Starter","Leaves fire trail behind player","AoE","Fire","Burn trail","fire;dot;aoe","Size/quantity boost coverage; great with duration/cooldown tomes", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=None, size=["15%","18%","21%","24%","30%"], dur=[0.18,0.21,0.25,0.29,0.36], cc=None, cd=None, bnc=None, kb=None),
    weapon("Lightning Staff","Starter","Instant lightning strikes that chain via bounces","Projectile","Lightning","Chain/bounce","lightning;bounce;projectile","Stack bounces and size for chaining; quantity for coverage", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=None, size=["20%","24%","28%","32%","40%"], dur=None, cc=None, cd=None, bnc=[1,1.2,1.4,1.6,2], kb=None),
    weapon("Firestaff","Starter","Fireball projectile with AoE explosion","Projectile","Fire","AoE blast","fire;aoe;projectile","Size/quantity for bigger blasts; damage scaling strong; projectile speed minor", [2.5,3,3.5,4,5],[1,1.2,1.4,1.6,2], ps=[0.1,0.12,0.14,0.16,0.2], size=["16%","19%","22%","26%","32%"], dur=None, cc=None, cd=None, bnc=None, kb=None),
    weapon("Chunkers","Starter","Orbiting rocks knock back nearby enemies","Orbit","Physical","Knockback","orbit;knockback;projectile","Size/knockback for safety; speed to tighten orbit coverage", [3,3.6,4.2,4.8,6],[1,1.2,1.4,1.6,2], ps=[0.35,0.42,0.49,0.56,0.7], size=["20%","24%","28%","32%","40%"], dur=None, cc=None, cd=None, bnc=None, kb=[0.7,0.8,0.8,1,1.3]),
    weapon("Bone","Starter","Bouncing bone projectile","Projectile","Physical","Bounce","projectile;bounce","Bounces then count; speed for more hits; pairs with size", [2.5,3,3.5,4,5],[1,1.2,1.4,1.6,2], ps=[0.2,0.24,0.28,0.32,0.4], size=None, dur=None, cc=None, cd=None, bnc=[1,1.2,1.4,1.6,2], kb=[0.3,0.3,0.4,0.5,0.6]),
    weapon("Bow","Starter","Piercing arrows","Projectile","Physical","Pierce","projectile;pierce;crit","Crit-focused; take crit tomes; projectile count and speed for coverage", [1.75,2.1,2.45,2.8,3.5],[1,1.2,1.4,1.6,2], ps=[0.3,0.36,0.42,0.48,0.6], size=["0.2","0.2","0.2","0.3","0.3"], dur=None, cc=["8%","10%","11%","13%","16%"], cd=["18%","22%","25%","29%","36%"], bnc=None, kb=None),
    weapon("Revolver","Kill 7,500 enemies (1 Silver)","Multi-bullet projectile weapon","Projectile","Physical","Bounce","projectile;bounce;crit","Bounce first for chaining; crit tomes; keep damage scaling", [2.5,3,3.5,4,5],[1,1.2,1.4,1.6,2], ps=[0.4,0.5,0.6,0.6,0.8], size=None, dur=None, cc=["10%","12%","14%","16%","20%"], cd=["20%","24%","28%","32%","40%"], bnc=[1,1.2,1.4,1.6,2], kb=None),
    weapon("Aegis","Block 500 damage with Armor as Sir Oofie (1 Silver)","Shield blocks hit then emits shockwave","AoE","Physical","Block + shockwave CC","aoe;defense;knockback","Quantity for more shields; knockback for space; cooldown/armor synergies", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=None, size=["15%","18%","21%","24%","30%"], dur=None, cc=None, cd=None, bnc=None, kb=[0.8,0.9,1.1,1.2,1.5]),
    weapon("Bananarang","Find hidden banana in Forest (1 Silver)","Returning banana projectile","Projectile","Physical","Return path","projectile;return","Count then size; speed for faster cycles; works well with cooldown", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=[0.1,0.12,0.14,0.16,0.2], size=["14%","17%","20%","22%","28%"], dur=None, cc=None, cd=None, bnc=None, kb=None),
    weapon("Aura","Survive 2 minutes without taking damage (1 Silver)","Constant ring damage aura","AoE","None","Constant aura","aoe;dot","Pure area scaling; size is main multiplier; pairs with duration/cooldown", [1.4,1.7,2,2.2,2.8],["","","","",""], ps=None, size=["14%","17%","20%","22%","28%"], dur=None, cc=None, cd=None, bnc=None, kb=None),
    weapon("Axe","Get 2,000 kills with Sword (1 Silver)","Spinning axe linger AoE","AoE","Physical","Linger","aoe;linger","Duration and count for coverage; size helpful; pairs with cooldown", [1.5,1.8,2.1,2.4,3],[1,1.2,1.4,1.6,2], ps=None, size=["10%","12%","14%","16%","20%"], dur=[0.08,0.1,0.11,0.13,0.16], cc=None, cd=None, bnc=None, kb=None),
    weapon("Space Noodle","Clear Desert Tier 2 as Tony McZoom (2 Silver)","Tether beam between player and target; target cannot die until beam ends","Beam","None","Lock target until duration ends","beam;channel","Duration and size to secure kill window; pair with cooldown/defense", [2,2.4,2.8,3.2,4],["","","","",""] , ps=None, size=["20%","24%","28%","32%","40%"], dur=[0.2,0.24,0.28,0.32,0.4], cc=None, cd=None, bnc=None, kb=None),
    weapon("Sniper Rifle","Level Precision Tome to 10 (2 Silver)","Manual-aim piercing shot","Projectile","Physical","Pierce","projectile;pierce;crit","High damage scaling; count for multi-shots; size for easier hits", [4,4.8,5.6,6.4,8],[1,1.2,1.4,1.6,2], ps=None, size=["13%","16%","18%","21%","26%"], dur=None, cc=None, cd=None, bnc=None, kb=None),
    weapon("Slutty Rocket","15,000 kills as CL4NK (2 Silver)","Homing rockets","Projectile","Physical","Homing","projectile;homing;crit","Crit chance is strong; count for more rockets; speed for reliability", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=[0.2,0.24,0.28,0.32,0.4], size=None, dur=None, cc=["8%","10%","11%","13%","16%"], cd=None, bnc=None, kb=None),
    weapon("Shotgun","5% drop from Desert Stage 2 Tumbleweed (2 Silver)","Cone burst; pellets pierce and scale with range","Projectile","Physical","Pierce cone","projectile;cone;crit","Count boosts pellet count; damage and crit solid; size for spread control", [3,3.6,4.2,4.8,6],[1,1.2,1.4,1.6,2], ps=None, size=["15%","18%","21%","24%","30%"], dur=None, cc=["7%","8%","10%","11%","14%"], cd=None, bnc=None, kb=[0.35,0.42,0.49,0.56,0.7]),
    weapon("Mines","7,500 kills with Slutty Rocket (2 Silver)","Drops proximity mines","AoE","Physical","Knockback","aoe;trap;knockback","Duration and size for coverage; count for area denial; pairs with cooldown", [3,3.6,4.2,4.8,6],[1,1.2,1.4,1.6,2], ps=None, size=["15%","18%","21%","24%","30%"], dur=[0.4,0.48,0.56,0.64,0.8], cc=None, cd=None, bnc=None, kb=None),
    weapon("Wireless Dagger","Lightning Staff to level 15 (2 Silver)","Homing daggers that never miss","Projectile","Physical","Bounce homing","projectile;homing;bounce","Count then bounces; speed to reach targets; pairs with cooldown", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=[0.1,0.12,0.14,0.16,0.2], size=None, dur=None, cc=None, cd=None, bnc=[1,1.2,1.4,1.6,2], kb=None),
    weapon("Frostwalker","Freeze 1,000 enemies with Ice Cube (2 Silver)","Pulse that freezes enemies","AoE","Ice","Freeze","aoe;ice;cc","Duration for longer freeze; size for catch radius; cooldown pairs well", [2,2.4,2.8,3.2,4],["","","","",""] , ps=None, size=["10%","12%","14%","16%","20%"], dur=[0.12,0.14,0.17,0.19,0.24], cc=None, cd=None, bnc=None, kb=None),
    weapon("Tornado","Charge a Charge Shrine during Sandstorm on Desert (2 Silver)","Piercing tornadoes with knockback","Projectile","Physical","Knockback","projectile;knockback;aoe","Count and size for walling; speed to reach targets; great defensive tool", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=[4,4.8,5.6,6.4,8], size=["14%","17%","20%","22%","28%"], dur=None, cc=None, cd=None, bnc=None, kb=[0.6,0.72,0.84,0.96,1.2]),
    weapon("Dexecutioner","12,500 kills with Sword (2 Silver)","Piercing blade with 2% execute chance","Projectile","Physical","Execute chance","projectile;execute;crit","Count and size; crit supports execute; pairs with CC setup", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=None, size=["20%","24%","28%","32%","40%"], dur=None, cc=["5%","6%","7%","8%","10%"], cd=None, bnc=None, kb=None),
    weapon("Blood Magic","Bloody Tome to level 12 (2 Silver)","AoE pulse; on-kill +1 Max HP (no cap)","AoE","None","Max HP on kill","aoe;dot;sustain","Count then size; pairs with tank builds; cooldown helps pulses", [1.5,1.8,2.1,2.4,3],[1,1.2,1.4,1.6,2], ps=None, size=["15%","18%","21%","24%","30%"], dur=None, cc=None, cd=None, bnc=None, kb=None),
    weapon("Black Hole","Knockback Tome to level 10 (2 Silver)","Pulls enemies inward (CC)","AoE","None","Pull","aoe;cc;setup","Duration/count for control; size for catch; great to set up other DPS", [1.3,1.5,1.8,2,2.5],[1,1.2,1.4,1.6,2], ps=None, size=["13%","16%","18%","21%","26%"], dur=[0.12,0.14,0.17,0.19,0.24], cc=None, cd=None, bnc=None, kb=None),
    weapon("Poison Flask","Kill Scorpionussy miniboss in Desert 3 times (2 Silver)","Lobbed poison AoE applying stacks","Projectile","Poison","Poison DoT","projectile;aoe;dot;poison","Duration for stacking; speed for coverage; anti-crit; pairs with DoT boosts", [0.5,0.6,0.7,0.8,1],[1,1.2,1.4,1.6,2], ps=[2,2.4,2.8,3.2,4], size=["15%","18%","21%","24%","30%"], dur=[1,1.2,1.4,1.6,2], cc=None, cd=None, bnc=None, kb=None),
    weapon("Katana","5% drop from Desert Stage 1 Tumbleweed (2 Silver)","Auto-target nearest melee slash","Melee","Physical","None","melee;slash;crit","Crit-focused melee; count/size for coverage; cooldown helps uptime", [2.2,2.6,3.1,3.5,4.4],[1,1.2,1.4,1.6,2], ps=None, size=["20%","24%","28%","32%","40%"], dur=None, cc=["8%","10%","11%","13%","16%"], cd=["20%","24%","28%","32%","40%"], bnc=None, kb=None),
    weapon("Dragon's Breath","Kill 1,000 Wisps as Fox on Desert (2 Silver)","Directional fire cone (channeled)","Cone","Fire","Burn cone","fire;cone;dot","Duration and size for sustained burn; cooldown/quantity boost uptime", [3,3.6,4.2,4.8,6],["","","","",""] , ps=None, size=["15%","18%","21%","24%","30%"], dur=[0.2,0.24,0.28,0.32,0.4], cc=None, cd=None, bnc=None, kb=None),
    weapon("Dice","Luck Tome to level 12 (4 Silver)","Throws dice (damage 1-6); rolling 6 grants +0.5% permanent self crit chance","Projectile","Physical","Self-buff crit on 6","projectile;crit;random","Crit stacking; count for more rolls; speed for more throws", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=[0.2,0.24,0.28,0.32,0.4], size=["15%","18%","21%","24%","30%"], dur=None, cc=["10%","12%","14%","16%","20%"], cd=["20%","24%","28%","32%","40%"], bnc=None, kb=None),
    weapon("Hero Sword","Defeat stage boss without picking ground items/powerups/shrines (4 Silver)","Melee slash plus ranged slashing projectile (pierces)","Hybrid","Physical","Pierce","melee;projectile;pierce","Count for multi-projectiles; speed for reach; size for coverage", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=[4,4.8,5.6,6.4,8], size=["15%","18%","21%","24%","30%"], dur=None, cc=None, cd=None, bnc=None, kb=None),
    weapon("Corrupted Sword","Level Cursed Tome to 20 within 10:00 (8 Silver)","Dual-direction slash; backward projectile pierces; damage scales up at low HP","Hybrid","Physical","Damage scales up at low HP","melee;projectile;pierce;risk","Count/speed for coverage; high-risk high-reward scaling at low HP", [2,2.4,2.8,3.2,4],[1,1.2,1.4,1.6,2], ps=[4,4.8,5.6,6.4,8], size=["15%","18%","21%","24%","30%"], dur=None, cc=None, cd=None, bnc=None, kb=None),
]

out_path = Path(__file__).resolve().parents[1] / "data" / "megabonk_weapons.csv"
with out_path.open("w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(header)
    for w in weapons:
        row = [
            w["Weapon"], w["Unlock"], w["BaseBehavior"], w["Types"], w["ElementOrDamageType"],
            w["SpecialOrCC"], w["Tags"], w["StrategySynergies"],
        ]
        for key in ("Damage","ProjectileCount","ProjectileSpeed","Size","Duration","CritChance","CritDamage","Bounces","Knockback"):
            row.extend(w[key])
        writer.writerow(row)

print(f"Wrote {len(weapons)} weapons to {out_path}")
