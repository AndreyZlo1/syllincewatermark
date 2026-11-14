-- HUSH combat. Standalone runtime + Syllinse buildUI(ctx). No FireServer rewrite.
-- Re-execution must not leave a second renderer, loot registry or Heartbeat loop alive.
do
    local previous = getgenv().HushSilent
    if previous and type(previous.unload) == "function" then previous.unload() end
end
-- shoot() builds Unit, pellets and the tracer from upvalue u108 and the packet origin from Head.Position: both are swapped for the call and put back.
-- Drawing.Circle does not render on this executor, nothing here uses it.

local cloneref = cloneref or function(x)
    return x
end


local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local SoundService = cloneref(game:GetService("SoundService"))
local Debris = cloneref(game:GetService("Debris"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Workspace = cloneref(game:GetService("Workspace"))
local CollectionService = cloneref(game:GetService("CollectionService"))
local LP = Players.LocalPlayer
local Cam = Workspace.CurrentCamera

-- Config.Guns.OriginSlack = 4 (server only). Sledge: a hold >= Config.Sledge.QuickHold (0.22) is a heavy swing, press() is refused again for 0.91 s.
local SLEDGE_REACH = 5
local QUICK_HOLD = 0.11
local QUICK_GAP = 0.74
local DRAW_WAIT = 1.35

local CFG = {
    Silent = true,
    ESP = true,
    FOV = 140,
    SilentAimDistance = 800,
    RespectRange = true, -- only target what the held gun's bullet can reach (Guns.Defs[id].range)
    DeathMarker = true,
    -- AutoHeal: uses the best Medical item from the backpack (Items.Defs[id].heal: bandage 20, medkit 70) when HP% falls
    -- to the threshold. AutoHealPvP: only while the server says we are in a fight (Player attribute CombatAt, 15 s).
    AutoHeal = false,
    AutoHealThreshold = 50, -- percent of MaxHealth
    AutoHealPvP = false,
    AutoHealDelay = 2.5, -- seconds between uses
    ExtractMarkers = true,
    ExtractAlpha = 0.7,
    -- Bosses: BossMarkers = skull icon + distance + name/HP% instead of an ESP box; with markers off, Bosses draws an
    -- ESP box. Bosses also lets Silent Aim target Mother (the game's own Mother.rayHit decides what is hittable).
    BossMarkers = true,
    Bosses = true,
    FindMarkers = true, -- workspace.WorldFinds (Find_<item> / Dropped_<item> pickups)
    FindMaxDist = 1500,
    FindAlpha = 0.85,
    -- FullAuto: every firearm def gets auto = true (tryFire still enforces def.delay).
    -- ShootEverywhere: masks the five Controls fields canFire() reads (sprinting, move, vaulting, gesturing, stunned) for one call. Server acceptance is unverified.
    ShootEverywhere = true, -- RightCtrl toggles
    -- WeaponFx / SelfFx: client-only Instance edits (material, colour gradient, Highlight) on the first-person gun, the held gun and your own character; originals are restored on toggle/unload.
    WeaponScale = false, -- local third-person HeldGun only; no first-person/viewmodel scaling
    WeaponScaleFactor = 4,
    WeaponFx = true, -- [ toggles
    WeaponFxMaterial = "ForceField", WeaponFxTransparency = 0,
    WeaponFxColorA = Color3.fromRGB(70, 230, 255), WeaponFxColorB = Color3.fromRGB(190, 80, 255),
    WeaponFxSpeed = 0.5, WeaponFxFlow = 0.12,
    WeaponFxHighlight = true, WeaponFxHlFill = 0.82, WeaponFxHlOutline = 0.15,
    -- ModelSwap: a client-only Creator Store model replaces how you look (Visual.SWAP_MODELS); hitboxes and the server keep the real character.
    ModelSwap = false, -- \ toggles, = cycles the model
    ModelSwapModel = "Tun Tun Sahur", ModelSwapYaw = 0, -- extra yaw in degrees if a model faces the wrong way
    SelfFx = true, -- ] toggles
    SelfFxMaterial = "Neon", SelfFxTransparency = 0.8, SelfFxStripClothes = true,
    SelfFxColorA = Color3.fromRGB(186, 150, 255), SelfFxColorB = Color3.fromRGB(255, 92, 163),
    SelfFxSpeed = 0.35, SelfFxFlow = 0.08,
    SelfFxHighlight = true, SelfFxHlFill = 1, SelfFxHlOutline = 0.1,
    FullAuto = true, -- RightAlt toggles; bolt/break-action guns (sniper, double barrel, revolver) cannot hold fire by the game's own rules
    -- Speed (key X): "Safe" = eased CFrame push inside the AntiCheat windows (extra distance only); "Pulse" = SpeedValue for PulseLength s, then PulseDelay s of nothing, no budget;
    -- "Hop" = bunny hop: jumps again on the landing frame and pushes only while FALLING (the user's measurement: no put-back when the speed comes during the descent of a
    -- jump; Config.AntiCheat.DescentBonus = 2 is the server's number for it). Extra speed = HopK x fall speed, capped at HopExtra, zero on the ground, while rising and at the apex.
    -- Distance left scales the horizontal extra only. Hop descent is capped at HopFallSpeed, independent of height or state multiplier.
    -- HopFallBurst briefly raises the descent cap after the uplink estimate; the cooldown persists across landings. Server acceptance is unconfirmed.
    -- HopClaim: Hop tells the server we slide while it pushes (Move "slide", dir ... "slideEnd", renewed every HopClaimRenew s; SlideMaxTime is 4).
    -- Safe and Pulse get the same fall speed on top (SpeedFallBonus, no state boost); SpeedFallOnly pushes ONLY while falling.
    -- All keep the wall ray and the put-back guard (a rollback pauses the push 6 s, a second one in 120 s switches it off).
    Speed = false,
    SpeedMode = "Hop",
    SpeedValue = 40,
    PulseLength = 0.4,
    PulseDelay = 0.15,
    SpeedMargin = 1.04,
    SpeedReserve = 0,
    SpeedMax = 42, -- Safe mode only
    SpeedRamp = 10, -- Safe mode only
    SpeedSlack = 0, -- studs added to each window (Config.AntiCheat.Slack = 6 exists, meaning unknown)
    HopExtra = 26, -- st/s, most the fall can add
    HopK = 1.2, -- st/s of extra per st/s of fall speed
    HopFallMin = 2, -- fall speed below which nothing is added
    HopRemain = 4, -- studs still to fall up to which the extra is full
    HopRemainPow = 1,
    HopFeet = 3, -- root centre to the soles
    HopRayMax = 80,
    HopRamp = 80, -- st/s^2 the extra grows at (it is cut at once on landing)
    HopStateK = 1.5,
    HopHorizontalSpeed = 22, -- total horizontal velocity plus scripted displacement, not extra speed
    HopHorizontalBurstSpeed = 28, -- shares the vertical burst window/cooldown
    HopFallSpeed = 22, -- fixed downward cap (sprint is 21)
    HopFallBurst = true,
    HopFallBurstSpeed = 28,
    HopFallBurstLength = 0.12,
    HopFallBurstEvery = 8, -- cooldown after a burst ends; not reset on landing
    HopUplinkMargin = 0.05,
    SpeedFallBonus = true,
    SpeedFallOnly = false,
    HopClaim = true,
    HopClaimRenew = 3.2,
    HopLog = true, -- one console line per 0.5 s while Hop pushes: state, uplink, fall speed, extra, snap
    HopAuto = true, -- jump again as soon as the feet touch down (the game's own landing lockout of 0.3-1.2 s is skipped)
    -- Strafer (key .): the horizontal velocity follows the move keys at once, in the air too (the game steers its air velocity at 14 st/s^2 only), in every stance:
    -- the speed is kept and never below StrafeSpeed (sprint is 21; crouch 6, aim 7.8 and walk 12 are the game's own limits). StrafeStop: no keys in the air = stop dead.
    -- The difference between the wanted and the real velocity is added as a CFrame step, so the path never gets faster than the wanted speed.
    Strafer = true,
    StrafeSpeed = 22,
    StrafeStop = true,
    -- FastClimb (key ,): Config.Climb.Pace scales the load / flight / catch time of every hold-to-hold hop (hopOf reads it per hop; 1 = the game's pace).
    -- ClimbAuto hops on by itself (Vault.try, the game's own jump handler) while a climb is idle and a move key is held; ClimbForce also starts climbs and
    -- vaults by itself when moving next to something climbable.
    AntiClimb = true, -- blocks new vaults, ledge grabs and wall moves; takes priority over FastClimb / ClimbForce
    FastClimb = false,
    FastClimbPace = 0.45,
    ClimbAuto = true,
    ClimbForce = false,
    -- AutoJump (key Y): every PreSimulation step while grounded and moving: Humanoid:ChangeState(Jumping); AutoJumpPower > 0
    -- writes that vertical velocity instead (custom jump).
    AutoJump = false,
    AutoJumpPower = 0,
    -- HighJump (key J): any jump gets its vertical velocity set to HighJumpPower on the first frame after the game's own jump fit ran. Apex = power^2 / 140 st; Config.AntiCheat.JumpStuds = 12 (power 41).
    HighJump = false,
    HighJumpPower = 55, -- apex = power^2 / 140 = 21 st; Config.AntiCheat.JumpStuds = 12 st (power 41) is the number the server could flag
    WaterMargin = 0.5, -- AntiDrown: the slab sits this far ABOVE the water surface (crouch / prone drop head and torso)
    -- PvP mode (key Insert): hides loot/body/airdrop ESP, exit/find/death markers and pauses AutoDecrypt so only the fight is left.
    -- PvPAuto switches it on by itself: server combat flag (CombatAt, 15 s) or an enemy player within PvPRange.
    PvPMode = false,
    PvPAuto = false, -- on by itself from CombatAt / an enemy within PvPRange; the Insert key (PvPMode) still works
    PvPRange = 150,
    PvPHold = 8,
    PvPPauseLoot = true,
    -- PvP mode (auto: CombatAt 15 s + PvPHold) hides the world markers; a body is the one thing wanted right after a kill, so a body
    -- that appeared in the last PvPCorpseSeconds stays on screen.
    PvPKeepCorpses = true,
    PvPCorpseSeconds = 60,
    -- WorldFinds filter: shown when its category is on OR its rarity order >= FindMinRarity (3 = Rare, 4 Epic, 5 Legendary,
    -- 6 Limited) OR the model has RareFind. Firearms = Weapons that have a Guns.Defs entry, Melee = other Weapons.
    FindMinRarity = 3,
    FindFilter = {
        Firearms = true, Ammo = true, Melee = false, Medical = false, Armor = false, Attachments = false, Tools = false,
        Valuables = false, Materials = false, Building = false, Food = false, Water = false, Accessories = false,
        Junk = false, Unknown = true,
    },
    ExtractMaxDist = 4000,
    VisibleCheck = true,
    AimPoints = true, -- covered head: aim at another visible point (head top/sides, torso, root)
    -- Party and Roblox Team share one rule. Safe zone = the Outpost boxes in ReplicatedStorage.OutpostBoxes; a player not in RaidState "Raid" is never a target.
    TeamCheck = true,
    SafeZoneCheck = true,
    SafeMargin = 2,
    EspAllies = true,
    -- Players inside this radius and inside the FOV are picked before anyone else; NPCs come last.
    PriorityRadius = 400,

    AimSpoof = true, -- tell the server we are scoped (Gun "Aim" ads=true) around each hip shot (Visual.aimSpoof)
    -- AlwaysAim: the server is told we are scoped the whole time one of these guns is held (the sniper's cone is 0.17 mrad scoped, 2.4 mrad median / 45 p90 when not: measured on 196 shots).
    -- The real state is handed back when the gun goes away.
    AlwaysAim = true,
    AlwaysAimGuns = { sniper = true, sniper_gold = true },
    InfStamina = true,
    NoRecoil = true,
    CrouchSpoof = false, -- experimental server stance; no local crouch or camera change
    CrouchSpoofMoving = false, -- opt in separately: a crouched server may enforce a lower movement envelope
    -- Client animation only; ammo/reload and seat entry remain server-authoritative.
    InstantEquip = true,
    -- Door/seat prompt hold -> 0 (client-side hold), and the local climb-in/out pose is finished at
    -- once (CarAnimFor). Whatever the server itself waits before the car is usable is untouched.
    InstantSit = true,
    InstantInteract = false, -- SearchPrompt / PryPrompt hold -> 0 (client-side hold)
    FastBolt = true,
    FastBoltScale = 0.25, -- local bolt cycle; a server prime timer (State.primeLeft) still wins
    NoHeat = true, -- Config.Guns.HeatPerShot -> 0: no climbing recoil/spread from sustained fire
    FullBright = false,
    -- Timing minigames are judged by the CLIENT: Breath sends Remotes.Breath(bool) per check, hotwire
    -- and lockpick send only the final "start"/"picked". Auto plays them at the normal pace.
    AutoBreath = true,
    AutoHotwire = true,
    NoFall = true, -- the client measures the fall and reports it (Move "fall"); we never report one
    AntiDrown = true, -- silence the local Drown report AND keep the feet on a local slab at the water surface
    BulletTracer = true,
    TracerStyle = 1, -- 1 Lightning, 2 Helix, 3 Rail
    HelixSpin = 14, -- rad/s the helix strands turn at
    HelixRadius = 0.26, -- studs, helix strand radius at the middle of the path
    TracerTrail = true, -- fading comet wake along the whole path (muzzle -> impact), fades out with the tracer
    HitMarker = true,
    HitMarkerStyle = 3, -- Wedges
    NoRagdoll = true, -- see Visual.unRagdoll
    -- Loot ESP per class: on = draw, color = box/title colour. Item names keep their rarity colour.
    -- Live: getgenv().HushSilent.cfg.LootClasses.Household.on = false
    LootClasses = {
        AirDrop = { on = true, color = Color3.fromRGB(255, 40, 40) },     -- Supply Flare crate (event)
        SupplyDrop = { on = true, color = Color3.fromRGB(255, 205, 76) }, -- loot bags after a death
        Corpse = { on = true, color = Color3.fromRGB(226, 214, 190) },
        Weapons = { on = true, color = Color3.fromRGB(255, 120, 40) },
        Ammo = { on = true, color = Color3.fromRGB(255, 225, 80) },
        Medical = { on = true, color = Color3.fromRGB(80, 255, 150) },
        Valuables = { on = true, color = Color3.fromRGB(200, 110, 255) },
        Crates = { on = true, color = Color3.fromRGB(110, 200, 255) },
        Tools = { on = true, color = Color3.fromRGB(160, 185, 210) },
        Stores = { on = true, color = Color3.fromRGB(120, 235, 235) },
        Vehicles = { on = true, color = Color3.fromRGB(255, 150, 190) },
        Household = { on = true, color = Color3.fromRGB(175, 175, 175) },
        Other = { on = true, color = Color3.fromRGB(150, 150, 150) },
    },
    EspObjectMaxDist = 600,
    EspArmor = true, -- "[Medium Armor]" under the weapons, coloured by the armor's rarity
    -- Enemy weapons (in hand + 3 hotbar slots) by Items rarity. on = false hides that rarity.
    -- Live: getgenv().HushSilent.cfg.WeaponRarity.Common.on = false
    WeaponRarity = {
        Common = { on = true, color = Color3.fromRGB(185, 185, 185) },
        Uncommon = { on = true, color = Color3.fromRGB(90, 225, 90) },
        Rare = { on = true, color = Color3.fromRGB(80, 155, 255) },
        Epic = { on = true, color = Color3.fromRGB(195, 100, 255) },
        Legendary = { on = true, color = Color3.fromRGB(255, 210, 50) },
        Limited = { on = true, color = Color3.fromRGB(255, 50, 60) },
    },
    EspSupplyMaxDist = 2000,
    MultiPoint = true,
    Monsters = true,
    EspPlayerMaxDist = 2000,
    EspNpcMaxDist = 600,
    EspInfoRate = 0.25,
    EspStateRate = 0.2,
    EspHealthRate = 0.1,
    PickRate = 1 / 60,
    VisCacheSec = 0.1,
    MuzzleVisual = true,
    MuzzleAlpha = 0.5, -- opacity of the aim guide only; bullet tracers keep their own fade
    AimVisuals = true,
    AimCenter = 1, -- silent-aim centre mark: 1 ring + dot, 2 turning ticks + dot, 3 dashed ring + dot
    EspRound = true, -- rounded box corners when the box is tall enough (>= 46 px); far boxes use straight corners
    EspHideIds = { sledgehammer = true }, -- every player has it: not listed in ESP
    HitSound = true,
    HitSoundPreset = "Fatality",
    HitSoundId = 115982072912004,
    HitSoundVolume = 3.5,
    HitSoundPitch = 1,
    HitParticles = true,
    -- Hit particles: lightning arcs (the ; key plays a preview).
    -- Wallbang: "Game" = pierce what Ballistics.trace lets the held gun pierce; "Off" = clean lines only (MP still works); "Ignore" = line not checked.
    Wallbang = "Game",
    -- Guns that must NOT be shot through walls (only at targets with a clean line), e.g. { sniper = true }. Default empty: the log says the sniper DOES pierce
    -- (25 shots through Metal/Concrete/Brick/Wood with 2.6-3.5 of its 3.5 pen used: 44% creature hits against 47% on clean lines, same at every range).
    NoWallbangGuns = {},
    -- Staff signals: Player attribute StaffRank (mod|admin|owner, server-set), UserId in Config.Admins/Moderators (outdated), AdminInvisible/AdminFly,
    -- optional group rank (StaffGroupRank > 0, 0 = off). Config.Clippers only with StaffClippers.
    StaffDetect = "Alert", -- "Off" | "Alert" (banner + console) | "Kick" (banner, then LocalPlayer:Kick after StaffKickDelay)
    StaffKickDelay = 0.4,
    StaffKickMsg = "Left the server (staff detected)",
    StaffClippers = false,
    StaffIgnore = {}, -- UserIds or names to leave out of the detection, e.g. { [5774574594] = true, Kannonprime = true }
    StaffGroupRank = 0,
    ParticleScale = 1,
    -- the lightning colour drifts along A -> B -> C (cool cyan -> violet -> soft rose) over its life
    ParticleColorA = Color3.fromRGB(70, 230, 255), ParticleColorB = Color3.fromRGB(150, 90, 255), ParticleColorC = Color3.fromRGB(255, 130, 200),
    KillAura = true,
    -- Same Fire packet the hammer sends. KaWall keeps the aim on the body when a wall sits inside Reach (server code not in the dump).
    KaWall = true,
    -- KaLead: aim point and facing ahead by his speed x 0.2 s (hammer contact delay), capped at KaLeadMax (Sledge.Force.Radius is 2.2).
    -- ServerSpread: the server cone is centred on the aim with ~0.1 deg radius; where it is wider than the head, Visual.serverSpread scores head/neck/chest/belly/hips
    -- and aims where the expected hit is highest (needs SSGain over the head and a clear line).
    ServerSpread = true,
    SSHead = 1.35, -- value of a head hit against a torso hit (1.0); a guess, the damage table is server-side
    SSLimb = 0.45,
    SSGain = 0.12,
    SSLeadSlop = 0.06, -- s x his speed added to the radius: measured sniper lead error p25..p75 = +-0.08 s
    SSSlop = 0.35,
    SSMin = 0.3, -- below this cone radius (studs) the head centre stays
    AimCone = true, -- silent-aim overlay: ring with the server's cone radius around the aim point (true scale, never smaller than ~7 px)
    -- DownedReplicaFix: beyond ~200 st the crawl pose is not replicated, our rig of a downed player stands and the head is ~4 st too high.
    -- Aims at the pose rebuilt from CrawlPose geometry (head 2.4 ahead / 1.4 below the root, upper torso 1.14 / 1.87, hips 2.04 below).
    DownedReplicaFix = true,
    -- SlopeLead: a grounded target on a slope or stairs gets a vertical lead (fitted speed, both windows agree, |vy| 2..40, capped by SlopeCap).
    -- AirBody: in the air no extrapolation helps, so a jumper's upper torso is aimed instead of the head.
    SlopeLead = true,  -- grounded non-seated target: lead vertically with the fitted speed (both regression windows must agree, |vy| 2..40 st/s, offset <= SlopeCap)
    SlopeCap = 3,      -- studs, vertical lead cap
    AirBody = true,    -- a jumping/bhopping player with the head selected: aim the upper torso (3x bigger target vertically) instead of leading the jump
    TracerFade = 0.95, -- seconds a tracer lives after the round landed
    -- Keeps telling the server we are scoped (Gun "Aim" ads=true) while a silent target is locked, so an ADS focus timer, if it keeps one, runs before the shot (debug file: focusAge).
    AimSpoofHold = true,
    -- Debug file hush/shots_<time>.jsonl in the executor workspace (Potassium: %LOCALAPPDATA%/Potassium/workspace/hush): one line per shot with everything the
    -- solver, the wall trace and the target looked like at the packet, the raw server events, per-shot hit/miss and (DebugAfter) where the target was seen later.
    DebugFile = true,
    DebugAfter = true,
    KaAim = "Head", -- "Head" or "HRP": the part the hammer is aimed at (the other parts are the fallback when it is out of reach)
    KaLead = true,
    -- KaLookahead: where the server will have him when the hammer lands = QuickContact + 3 x ping/2 + KaInterp. Unverified model, the shot log prints it.
    KaLeadMax = 4.5, -- studs; the point is also clamped inside the sledge Reach from the head
    KaInterp = 0.1, -- our render interpolation delay (s)
    KaFaceRange = 9, -- keep facing the nearest enemy inside this range (swinging still needs Reach)
    Quality = 1,
    -- MultiPoint origin offset in studs. The server fires from its own head when the claimed origin is outside Config.Guns.OriginSlack (4): 16 of 31 shots at 4.0, 0 of 6 at <= 3.5.
    -- Visual.mpBudget keeps MPSlackMargin under the config value.
    MPReach = 3.4,
    MPSlackMargin = 0.5,
    MPPreferFrac = 0.5, -- first try this share of the budget along each direction; 0.5 of 3.4 = 1.7 studs
    -- The server compares the claimed origin with where it last SAW our head (about ping/2 + MPLagExtra behind while we move),
    -- so the offset is measured from that estimated position, not from the head we see.
    MPLagComp = true,
    MPLagExtra = 0.03,
    LootViz = true,
    LootRange = 90,
    LootMinRarity = 1, -- Items.Rarity.order; 3 = Rare+. Unknown boxes are separate.
    LootUnknown = true,
    LootHideEmpty = true,
    -- Sledge aura keeps the root turned to the nearest enemy (KaFaceRange) the whole time the hammer is held: the server sees
    -- our facing with a delay, so a turn that starts at the charge is already too late.
    KaTurn = true,
    -- Resolver: rounds are projectiles (Exterior RK4 path under GunPhysics, Ballistics.arcAt otherwise); the lead is v * (flight time + lag shift)
    -- and the aim point also carries the gravity sag. The [hush] shot log prints speed / lead / drop / flight / ping lead / why-no-lead.
    Resolver = true,
    HelmetAim = false, -- a worn helmet that stops the held gun's round: aim the torso instead of the head
    -- Acceleration term of the lead: (recent - old velocity) / the gap between the two regression windows, capped to ResolverAccel st/s^2 and scaled by ResolverAccelK.
    -- A braking target is clamped at standstill (no reversing through zero); the lead never exceeds his top recent speed * t.
    ResolverAccel = 70,
    ResolverAccelK = 0.7,
    -- Lag model: the server rewinds targets by Config.Guns.RewindView and tolerates RewindSlack. We see a target at
    -- (ping + our interpolation delay) behind, so the part of (ping + PredictInterp - RewindView) beyond the slack is led.
    PingPredict = true, -- lead v * (ping + PredictInterp - RewindView - slack), clamped; ~0 at 80 ms ping, grows with ping. false = off
    PredictInterp = 0.1,
    MPFirst = true, -- covered head: head centre -> MultiPoint -> head edge -> body (false: head edge before MultiPoint)
    LeadCap = 24, -- studs the target may be led at most
    MPRate = 0.15,
    ShotLog = true,
    PerfLog = false, -- one compact console line every 15 s: avg/max ms per section
    -- AutoDecrypt opens through fireproximityprompt (Config.Loot.OpenDistance 10; the server's distance check is unread, the radius is a test).
    AutoDecrypt = false,
    AutoDecryptRadius = 10,
    AutoDecryptMax = 3, -- prompts fired in the same frame; drops to 1 if the server closes the earlier one
    AutoDecryptReveal = true, -- false: open, read the slot count, close at once
    -- AutoLoot: Remotes.Loot "take" (part, slot) on an OPEN container (opened by AutoDecrypt, or by hand with AutoLootManual). A slot is taken when its category is on in
    -- AutoLootCats and its rarity order >= AutoLootMinRarity, or its rarity order >= AutoLootAlways (any category; 7 = off). Hidden slots wait for their reveal.
    AutoLoot = false,
    AutoLootManual = true,
    AutoLootMinRarity = 1,
    AutoLootAlways = 7,
    AutoLootDelay = 0.25, -- s between two takes; a slot the server leaves unchanged after two takes is skipped
    AutoLootCats = {
        Firearms = true, Ammo = true, Medical = true, Armor = true, Attachments = true, Valuables = true,
        Melee = false, Tools = false, Materials = false, Building = false, Food = false, Water = false, Accessories = false, Junk = false,
    },
    -- AutoArmor: InvAction Wear from the backpack, ranked by Items rarity order (light < medium < heavy; helmets by their tier). Empty slots are always filled;
    -- "Upgrade" also replaces a worn piece with a higher tier, and waits for the end of the server combat flag when AutoArmorSafe is on.
    AutoArmor = false,
    AutoArmorBody = true,
    AutoArmorHelmet = true,
    AutoArmorMode = "Upgrade", -- "Upgrade" | "Empty"
    AutoArmorSafe = true,
    -- CrouchAB: alternates CrouchSpoof in random on/off pairs of CrouchABBlock shots and tags each shot record (ab = { block, idx, want }); tools/ab_crouch.py reads it.
    CrouchAB = false,
    CrouchABBlock = 20,
    -- K is Backpack, P is Bounty, L is Doors and J is MotherTurn in this game. Rebind here.
    Keys = {
        ESP = Enum.KeyCode.RightControl,
        Gallery = Enum.KeyCode.Delete,
        AutoDecrypt = Enum.KeyCode.Home,
        LootFilter = Enum.KeyCode.PageUp,
        Perf = Enum.KeyCode.PageDown,
        Unload = Enum.KeyCode.End,
        Speed = Enum.KeyCode.X, -- NOTE: the game binds X to HANDS UP (on foot) / HATCH (car); see the key sink below
        HighJump = Enum.KeyCode.J, -- the game reads J for MotherTurn during her event only
        AutoJump = Enum.KeyCode.Y,
        FastClimb = Enum.KeyCode.Comma,
        Strafer = Enum.KeyCode.Period,
        PvP = Enum.KeyCode.Insert,
        FullAuto = Enum.KeyCode.RightAlt,
        ShootEverywhere = Enum.KeyCode.RightShift, -- was RightControl = the same key as ESP, so one press flipped both
        ParticleTest = Enum.KeyCode.Semicolon,
        WeaponFx = Enum.KeyCode.LeftBracket,
        SelfFx = Enum.KeyCode.RightBracket,
        ModelSwap = Enum.KeyCode.BackSlash,
        ModelSwapNext = Enum.KeyCode.Equals,
    },
}

-- Players: green = clear shot, red = behind cover. NPC: translucent purple. Ally sky blue, protected player gold, corpse bone. States have fixed colours (Drive orange, Aim red, Run light blue).
local COL_INK = Color3.fromRGB(8, 8, 12)
local COL_PAPER = Color3.fromRGB(240, 244, 248)
local COL_VIS = Color3.fromRGB(70, 255, 110)
local COL_HID = Color3.fromRGB(255, 56, 56)
local COL_NPC = Color3.fromRGB(184, 96, 255)
local COL_DIST = Color3.fromRGB(220, 224, 230)
local COL_WEP = Color3.fromRGB(255, 214, 120)
local COL_IRON = Color3.fromRGB(148, 160, 170)
local COL_RUST = Color3.fromRGB(214, 92, 66)
local COL_CORPSE = Color3.fromRGB(226, 214, 190)
local PAL = {
    npcHid = Color3.fromRGB(132, 70, 196),
    npcAlpha = 0.55,
    npcHidAlpha = 0.4,
    ally = Color3.fromRGB(80, 180, 255),
    peek = Color3.fromRGB(110, 205, 245),
    safe = Color3.fromRGB(255, 206, 64),
    hpLow = Color3.fromRGB(255, 50, 50),
    hpHigh = Color3.fromRGB(70, 255, 110),
    -- aim mark by priority tier: 0 player inside PriorityRadius, 1 other player, 2 NPC
    tier = { [0] = Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 150, 60), COL_NPC },
    -- stroke weight per role
    weight = { foe = 1.8, ally = 1.5, safe = 1.5, npc = 1.1, corpse = 1.3 },
    tag = { ally = " [team]", safe = " [safe]" },
}
-- read by tools/make_icons.py (icon colours), not by this script
local STATE_COLOR = {
    Aim = Color3.fromRGB(255, 60, 60),
    Shoot = Color3.fromRGB(255, 30, 120),
    Crouch = Color3.fromRGB(190, 160, 255),
    Lay = Color3.fromRGB(160, 160, 160),
    Run = Color3.fromRGB(110, 210, 255),
    Walk = Color3.fromRGB(200, 230, 240),
    Drive = Color3.fromRGB(255, 150, 30),
    Sit = Color3.fromRGB(255, 200, 120),
    Charge = Color3.fromRGB(255, 110, 20),
    Reload = Color3.fromRGB(255, 230, 70),
    Light = Color3.fromRGB(255, 255, 190),
    Dying = Color3.fromRGB(200, 30, 30),
    Ragdoll = Color3.fromRGB(160, 160, 160),
}

local Visual = {} -- declared early: aim_part (DownedReplicaFix) and alive_model sit above the old declaration
local connections = {}
-- Separate lifetime owners: respawn/folder replacement must not append dead subscriptions forever.
local Life = { char = {}, monsters = {} }
Life.clear = function(list)
    for i = #list, 1, -1 do list[i]:Disconnect(); list[i] = nil end
end
local espByModel = {}
local visCache = setmetatable({}, { __mode = "k" })
local shotAt = setmetatable({}, { __mode = "k" })
local reloadAt = setmetatable({}, { __mode = "k" })

local oldShoot = nil
local hooked = false
local running = true
local lastAim = nil
local saTgt = nil
local pickAt = 0
local kaAim = nil
local sledgeRelease = nil
local aimWrapped = false
local visPhase = 0
local held = { id = nil, firearm = false, att = nil, model = nil, since = nil }
local ka = { phase = "idle", untilAt = 0, nextPick = 0, tgt = nil, tick = 0, scarUntil = 0, scarA = nil, scarB = nil }
local sledgeMod = nil

local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.IgnoreWater = true

local function bind(conn)
    if not running then conn:Disconnect(); return conn end
    connections[#connections + 1] = conn
    return conn
end

-- Cached roster and Monsters list: the old code asked the engine for fresh
-- GetPlayers()/GetChildren() arrays several times per frame.
local roster = {}
local function rebuild_roster()
    table.clear(roster)
    local list = Players:GetPlayers()
    for i = 1, #list do
        if list[i] ~= LP then
            roster[#roster + 1] = list[i]
        end
    end
end
rebuild_roster()
bind(Players.PlayerAdded:Connect(rebuild_roster))
bind(Players.PlayerRemoving:Connect(function(plr)
    -- PlayerRemoving fires before GetPlayers necessarily drops that Player.
    for i = #roster, 1, -1 do if roster[i] == plr then table.remove(roster, i) end end
end))

local monsterList, monsterFolder, monsterCheckAt = {}, nil, 0
local function add_monster(m)
    if m:IsA("Model") then
        monsterList[#monsterList + 1] = m
    end
end
local function drop_monster(m)
    for i = #monsterList, 1, -1 do
        if monsterList[i] == m then
            table.remove(monsterList, i)
        end
    end
end
local function monsters()
    if monsterFolder and monsterFolder.Parent then
        return monsterList
    end
    local now = os.clock()
    if now >= monsterCheckAt then
        monsterCheckAt = now + 1
        Life.clear(Life.monsters)
        monsterFolder = nil
        local folder = Workspace:FindFirstChild("Monsters")
        if folder then
            monsterFolder = folder
            table.clear(monsterList)
            for _, m in folder:GetChildren() do
                add_monster(m)
            end
            Life.monsters[1] = folder.ChildAdded:Connect(add_monster)
            Life.monsters[2] = folder.ChildRemoved:Connect(drop_monster)
        else
            table.clear(monsterList)
        end
    end
    return monsterList
end


local gunsMod = nil
local itemsMod = nil
local function guns()
    if gunsMod then
        return gunsMod
    end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local inst = shared and shared:FindFirstChild("Guns")
    if inst then
        local ok, mod = pcall(require, inst)
        if ok and type(mod) == "table" then
            gunsMod = mod
        end
    end
    return gunsMod
end

local function items()
    if itemsMod then
        return itemsMod
    end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local inst = shared and shared:FindFirstChild("Items")
    if inst then
        local ok, mod = pcall(require, inst)
        if ok and type(mod) == "table" then
            itemsMod = mod
        end
    end
    return itemsMod
end

local function item_name(id)
    if type(id) ~= "string" or id == "" then
        return nil
    end
    local defs = items() and items().Defs
    local row = defs and defs[id]
    return (row and row.name) or id
end

local function gun_row(id)
    local defs = guns() and guns().Defs
    return defs and defs[id] or nil
end

local function is_firearm(id)
    local row = gun_row(id)
    if not row then
        return false
    end
    if row.melee == true or row.gadget ~= nil then
        return false
    end
    return true
end

local function kind_of(model)
    local k = model and model:GetAttribute("Kind")
    if type(k) == "string" and k ~= "" then
        return k
    end
    return nil
end

local humCache = setmetatable({}, { __mode = "k" })
local humRecheck = setmetatable({}, { __mode = "k" })
local function hum_of(model)
    if not model then
        return nil
    end
    local hum = humCache[model]
    if not (hum and hum.Parent) then
        local now = os.clock()
        if hum == false and now < (humRecheck[model] or 0) then
            return nil
        end
        hum = model:FindFirstChildOfClass("Humanoid") or false
        humCache[model] = hum
        humRecheck[model] = now + 1
    end
    return hum or nil
end
local function hp_of(model)
    local hum = hum_of(model)
    if hum and hum.MaxHealth > 0 then
        return hum.Health, hum.MaxHealth
    end
    return nil
end

local function is_corpse(model)
    -- Corpses are detached Body models under Workspace.Bodies, not a zero-HP player rig.
    local parent = model and model.Parent
    return parent ~= nil and parent.Parent == Workspace and parent.Name == "Bodies"
end

local function alive_model(model)
    if not model or not model.Parent or model == LP.Character or is_corpse(model) then
        return false
    end
    -- the server marks a dying rig with DyingAt (the fall lasts DyingFor s): it is already a body, not a target
    if type(model:GetAttribute("DyingAt")) == "number" then
        return false
    end
    -- NPC rigs carry the server's state in the model attribute State; the game's own animators treat "Dead" as a corpse before the model leaves workspace or Health reads 0.
    if model:GetAttribute("State") == "Dead" then
        return false
    end
    local cur = hp_of(model)
    if cur == nil then
        return kind_of(model) ~= nil
    end
    return cur > 0
end

-- DownedReplicaFix (see CFG). "Ahead" = the root's horizontal look vector (CrawlPose.crawl lays the body along it). Offsets: 35 replicated poses;
-- that the server boxes follow the pose is an inference, shot records keep tgt.dn to check it.
Visual.knockedOut = function(model)
    local untilAt = model and model:GetAttribute("KnockedOut")
    return type(untilAt) == "number" and Workspace:GetServerTimeNow() < untilAt
end
Visual.dn = { proxies = setmetatable({}, { __mode = "k" }), folder = nil }
Visual.dnPose = function(model, now)
    if not CFG.DownedReplicaFix or model:GetAttribute("Downed") ~= true or model:GetAttribute("Slumped") == true then return nil end
    if type(model:GetAttribute("DyingAt")) == "number" then return nil end
    local root, head = model:FindFirstChild("HumanoidRootPart"), model:FindFirstChild("Head")
    if not (root and head and root:IsA("BasePart") and head:IsA("BasePart")) then return nil end
    if head.Position.Y - root.Position.Y < 0.5 then return nil end -- our rig already shows the pose (head dropped): the real parts are right
    -- DownPose.downOverlay: the pose starts 1 s after ShotDown and ramps at 4/s
    local sd = model:GetAttribute("ShotDown")
    if type(sd) == "number" and (Workspace:GetServerTimeNow() - sd - 1) * 4 < 0.5 then return nil end
    local look = root.CFrame.LookVector
    local f = Vector3.new(look.X, 0, look.Z)
    if f.Magnitude < 0.05 then return nil end
    f = f.Unit
    local rp = root.Position
    return { head = rp + f * 2.4 + Vector3.new(0, -1.4, 0), ut = rp + f * 1.14 + Vector3.new(0, -1.87, 0), lt = rp + Vector3.new(0, -2.04, 0), f = f }
end
Visual.dnPart = function(name, size)
    local f = Visual.dn.folder
    if not (f and f.Parent) then
        f = Instance.new("Folder")
        f.Name = "HushDownedProxy"
        f.Parent = Workspace.CurrentCamera or Workspace
        Visual.dn.folder = f
    end
    local p = Instance.new("Part")
    p.Name, p.Size, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = name, size, true, false, false, false, 1
    p:SetAttribute("HushProxy", true)
    p.Parent = f
    return p
end
-- the stand-in parts of a downed player whose pose is not replicated, or nil. Updated on every call (aim_part runs once per candidate per frame).
Visual.dnProxy = function(model, now)
    local pose = Visual.dnPose(model, now)
    local px = Visual.dn.proxies[model]
    if not pose then
        if px then px.on = false end
        return nil
    end
    if not (px and px.head.Parent) then
        for m, old in pairs(Visual.dn.proxies) do -- parts of players that left: gone with them
            if not m.Parent then
                old.head:Destroy(); old.ut:Destroy(); old.lt:Destroy()
                Visual.dn.proxies[m] = nil
            end
        end
        px = { head = Visual.dnPart("Head", Vector3.new(1.2, 1.2, 1.2)), ut = Visual.dnPart("UpperTorso", Vector3.new(2, 1.6, 1)), lt = Visual.dnPart("LowerTorso", Vector3.new(2, 0.4, 1)) }
        Visual.dn.proxies[model] = px
    end
    px.head.CFrame, px.ut.CFrame, px.lt.CFrame = CFrame.new(pose.head), CFrame.new(pose.ut), CFrame.new(pose.lt)
    px.on, px.f = true, pose.f
    return px
end
Visual.dnClear = function()
    local f = Visual.dn.folder
    if f then f:Destroy() end
    Visual.dn.folder = nil
    table.clear(Visual.dn.proxies)
end

local bone_of
local aimPartCache = setmetatable({}, { __mode = "k" })

-- Listeners are a motor rig (HeadJoint, Maw, Jaw), not a humanoid skeleton.
-- Aiming the Head joint misses the body the gun ray actually stops on.
local function aim_part(model)
    if model:GetAttribute("Downed") == true then
        local px = Visual.dnProxy(model, os.clock())
        if px then return px.head end
    end
    local cached = aimPartCache[model]
    if cached and cached.Parent then
        return cached
    end
    if Players:GetPlayerFromCharacter(model) then
        local bone = bone_of(model, "Head")
        aimPartCache[model] = bone
        return bone
    end
    local best, vol = nil, 0
    local kids = model:GetDescendants()
    for i = 1, #kids do
        local d = kids[i]
        if d:IsA("BasePart") and d.Transparency < 0.85 and d.Name ~= "HumanoidRootPart" and d.Name ~= "Drool" then
            local v = d.Size.X * d.Size.Y * d.Size.Z
            if v > vol then
                best, vol = d, v
            end
        end
    end
    best = best or bone_of(model)
    aimPartCache[model] = best
    return best
end

function bone_of(model, name)
    if not model then
        return nil
    end
    if name then
        local named = model:FindFirstChild(name)
        if named and named:IsA("BasePart") then
            return named
        end
    end
    for _, n in { "Head", "UpperTorso", "Torso", "HumanoidRootPart" } do
        local p = model:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            return p
        end
    end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

-- Liveness for the per-frame ESP loop only (combat gates keep the fresh alive_model): sampled at the HP rate.
local aliveCache = setmetatable({}, { __mode = "k" })
local function alive_ui(model, now)
    local c = aliveCache[model]
    if c and now < c.at then return c.v end
    local v = alive_model(model)
    if c then c.at, c.v = now + (CFG.EspHealthRate or 0.1), v else aliveCache[model] = { at = now + (CFG.EspHealthRate or 0.1), v = v } end
    return v
end
-- Actors past their ESP range are re-tested 4 times a second, not every frame.
local farUntil = setmetatable({}, { __mode = "k" })

-- Root part per model, cached weakly. Out-of-range actors have no ESP slot, so without this every one of
-- them paid a FindFirstChild every frame just to be range-culled.
local rootCache = setmetatable({}, { __mode = "k" })
local function root_of(model)
    local r = rootCache[model]
    if r and r.Parent then return r end
    r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or bone_of(model)
    rootCache[model] = r
    return r
end

-- Relation to us: "out" > "ally" (party/team) > "safe" (Outpost box) > "foe". Slow facts are sampled 4x/s per player, the position test is exact on every call.
local Rel = { cache = setmetatable({}, { __mode = "k" }), boxes = {}, nBoxes = 0, boxText = nil, boxAt = -1 }
Rel.readBoxes = function(now)
    if now < Rel.boxAt then return end
    Rel.boxAt = now + 0.5
    local text = ReplicatedStorage:GetAttribute("OutpostBoxes")
    if text == Rel.boxText then return end
    Rel.boxText, Rel.nBoxes = text, 0
    if type(text) ~= "string" then return end
    for chunk in string.gmatch(text, "[^;]+") do
        local v, n = Rel.boxes[Rel.nBoxes + 1] or {}, 0
        for num in string.gmatch(chunk, "[^,]+") do n += 1; v[n] = tonumber(num) or 0 end
        if n == 6 then Rel.nBoxes += 1; Rel.boxes[Rel.nBoxes] = v end
    end
end
Rel.inside = function(pos, now)
    Rel.readBoxes(now)
    local m, x, y, z = CFG.SafeMargin or 0, pos.X, pos.Y, pos.Z
    for i = 1, Rel.nBoxes do
        local b = Rel.boxes[i]
        if x >= b[1] - m and x <= b[4] + m and z >= b[3] - m and z <= b[6] + m and y >= b[2] - 10 and y <= b[5] + m then
            return true
        end
    end
    return false
end
-- Players the client can see are untargetable: player AdminInvincible, character AdminParked / SparOn
-- (sparring match). Read inside Rel.of's 0.25 s window, never per frame.
Rel.static = function(plr)
    if plr:GetAttribute("AdminInvincible") == true then return true end
    -- staff event rule (Admin panel "PvP off": "Nobody can hurt another raider on this server"), replicated on ReplicatedStorage
    if ReplicatedStorage:GetAttribute("EventNoPvp") == true then return true end
    -- Player attribute NewRaider (number > 0): the beginner protection, raiders cannot damage them.
    local nr = plr:GetAttribute("NewRaider")
    if type(nr) == "number" and nr > 0 then return true end
    local char = plr.Character
    return char ~= nil and (char:GetAttribute("AdminParked") ~= nil or type(char:GetAttribute("SparOn")) == "number")
end
Rel.of = function(plr, now)
    local c = Rel.cache[plr]
    if not c then c = { at = -1, v = "foe" }; Rel.cache[plr] = c end
    if now - c.at >= 0.25 then
        c.at = now
        local state, party = plr:GetAttribute("RaidState"), LP:GetAttribute("PartyId")
        if (type(state) == "string" and state ~= "Raid") or plr:GetAttribute("EventOut") == true then
            c.v = "out"
        elseif CFG.TeamCheck and ((LP.Team ~= nil and plr.Team == LP.Team)
            or (party ~= nil and plr:GetAttribute("PartyId") == party)) then
            c.v = "ally"
        else
            c.v = "foe"
            if Rel.static(plr) then c.v = "safe" end
        end
    end
    if c.v == "foe" and CFG.SafeZoneCheck then
        local char, root = plr.Character, c.root
        if not (root and root.Parent) then
            root = char and char:FindFirstChild("HumanoidRootPart")
            c.root = root
        end
        if root and Rel.inside(root.Position, now) then return "safe" end
    end
    return c.v
end

local function is_enemy_player(plr)
    if plr == nil or plr == LP then
        return false
    end
    if Rel.of(plr, os.clock()) ~= "foe" then
        return false
    end
    return alive_model(plr.Character)
end

-- Environment LOS filter. Do not let local gun/debris FX decide visibility.
local visFilter = { char = false, cam = false, nextAt = 0, list = {}, fxNames = { "Debris", "GunFX", "BodyFX", "FirstPersonView" } }
local function vis_list()
    local char, now = LP.Character, os.clock()
    if visFilter.char ~= char or visFilter.cam ~= Cam or now >= visFilter.nextAt then
        visFilter.char, visFilter.cam, visFilter.nextAt = char, Cam, now + 0.5
        local list = visFilter.list
        table.clear(list)
        if char then list[#list + 1] = char end
        if Cam then list[#list + 1] = Cam end
        for i = 1, #visFilter.fxNames do
            local fx = Workspace:FindFirstChild(visFilter.fxNames[i])
            if fx then list[#list + 1] = fx end
        end
        visParams.FilterDescendantsInstances = list
    end
    return visFilter.list
end
local function world_clear(fromPos, toPos, model)
    vis_list()
    local delta = toPos - fromPos
    if delta.Magnitude < 0.05 then return true end
    local hit = Workspace:Raycast(fromPos, delta, visParams)
    return not hit or (model ~= nil and hit.Instance:IsDescendantOf(model))
end

local function cached_clear(key, fromPos, toPos, model)
    local ttl = CFG.VisCacheSec or 0
    local now = os.clock()
    local slot = visCache[key]
    if slot and ttl > 0 and now - slot.t < ttl and slot.from and slot.to
        and (slot.from - fromPos).Magnitude < 0.25
        and (slot.to - toPos).Magnitude < 0.25 then
        return slot.v
    end
    local v = world_clear(fromPos, toPos, model)
    slot = slot or {}
    slot.t, slot.v, slot.from, slot.to = now, v, fromPos, toPos
    visCache[key] = slot
    return v
end

local function fov_px()
    Cam = Workspace.CurrentCamera
    if not Cam then
        return 90
    end
    local vp = Cam.ViewportSize
    local half = math.rad(Cam.FieldOfView) * 0.5
    if half < 0.05 then
        return 90
    end
    return (vp.Y * 0.5 / math.tan(half)) * math.tan(math.rad(CFG.FOV) * 0.5)
end

-- Silent hook install is driven by equipping a firearm, not by a 40 s poll of the GC:
-- the shoot function and its look slot only exist once a gun has been drawn.
local Install = { tries = 0, nextAt = 0, warned = false }
-- Bullet reach: a flight ends after range / velocity * 1.04 s and nothing extends it, so targets past def.range are not valid candidates.
local reachLim, reachFor = nil, nil
local function sa_reach()
    local md = CFG.SilentAimDistance
    if reachLim and reachLim < md then return reachLim end
    return md
end
local function refresh_held()
    local char = LP.Character
    local id = char and char:GetAttribute("Gun")
    if type(id) ~= "string" then
        id = nil
    end
    if id ~= held.id then
        held.since = id and os.clock() or nil
        Install.tries, Install.warned, Install.nextAt = 0, false, 0
    end
    held.id = id
    held.firearm = is_firearm(id)
    if reachFor ~= id then
        local g = id and guns()
        if not id or g then
            reachFor = id
            local def = g and g.Defs and g.Defs[id]
            reachLim = CFG.RespectRange and held.firearm and def and type(def.range) == "number" and def.range > 20 and def.range - 1 or nil
        end
    end
    local model = char and char:FindFirstChild("HeldGun")
    if not (model and model:IsA("Model")) then
        held.model, held.att = nil, nil
        return
    end
    if held.model ~= model then held.model, held.att, held.muzzleAt = model, nil, 0 end
    if held.att and held.att.Parent then return end
    local now = os.clock()
    if held.att == false and now < held.muzzleAt then return end
    -- Cache absence too: gadgets/melee without a muzzle must not GetDescendants every Heartbeat.
    held.att, held.muzzleAt = false, now + 0.5
    for _, d in model:GetDescendants() do
        if d:IsA("Attachment") and string.sub(d.Name, 1, 6) == "Muzzle" then
            held.att = d
            break
        end
    end
end

local function muzzle_pos()
    if held.att and held.att.Parent then
        return held.att.WorldPosition
    end
    local head = LP.Character and LP.Character:FindFirstChild("Head")
    return head and head.Position
end

-- Bounded candidate pool sorted by screen error; no table allocation on a warmed pick.
local picks = { rows = {}, n = 0, cap = 6 }
local Resolver -- defined below; consider() feeds its position history
local function consider(model, origin, cx, cy, maxR2, isPlayer)
    local bone = aim_part(model)
    if not bone then return end
    local pos = bone.Position
    local delta = pos - origin
    local d2 = delta:Dot(delta)
    local md = sa_reach()
    if d2 > md * md or d2 < 2.25 then return end
    if not alive_model(model) then return end -- hp reads only for actors that are in range
    -- Feed off-screen enemies too; the sweep samples tracked roots up to 120 Hz.
    if CFG.Resolver then
        local root = root_of(model)
        if root then Resolver.sample(model, root, os.clock()) end
    end
    local sp, onScreen = Cam:WorldToViewportPoint(pos)
    if not onScreen or sp.Z <= 0 then return end
    local dx, dy = sp.X - cx, sp.Y - cy
    local fov2 = dx * dx + dy * dy
    if fov2 > maxR2 then return end
    -- Priority: player inside PriorityRadius (0), any other player (1), NPC (2). Inside a tier the
    -- candidate nearest the crosshair wins. 1e8 exceeds any possible squared screen error.
    local dist = math.sqrt(d2)
    local tier = isPlayer and (dist <= CFG.PriorityRadius and 0 or 1) or 2
    local key = tier * 1e8 + fov2
    local n, rows = picks.n, picks.rows
    if n == picks.cap and key >= rows[n].key then return end
    if n < picks.cap then n += 1 end
    local row = rows[n] or {}
    row.model, row.bone, row.pos, row.dist, row.fov2, row.tier, row.key = model, bone, pos, dist, fov2, tier, key
    local at = n
    while at > 1 and rows[at - 1].key > key do rows[at] = rows[at - 1]; at -= 1 end
    rows[at] = row
    picks.n = n
end

local function pick_raw(origin)
    Cam = Workspace.CurrentCamera
    picks.n = 0
    if not Cam or typeof(origin) ~= "Vector3" then return nil end
    local vp = Cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local r = fov_px()
    local maxR2 = r * r
    for i = 1, #roster do
        local plr = roster[i]
        if is_enemy_player(plr) then consider(plr.Character, origin, cx, cy, maxR2, true) end
    end
    if CFG.Monsters then
        local list = monsters()
        for i = 1, #list do consider(list[i], origin, cx, cy, maxR2) end
    end
    return picks.n > 0 and picks.rows[1] or nil
end

local MP_LOCAL = {
    Vector3.new(1, 0, 0),
    Vector3.new(-1, 0, 0),
    Vector3.new(0, 1, 0),
    Vector3.new(1, 0, 1),
    Vector3.new(-1, 0, 1),
    Vector3.new(0, -1, 0), -- down (crouch / lean under a sill)
    Vector3.new(1, -1, 0),
    Vector3.new(-1, -1, 0),
    Vector3.new(0, -1, 1),
    dirs = {},
    up = Vector3.new(0, 1, 0),
}

local function mp_dirs()
    local cf = Cam and Cam.CFrame
    local right = cf and cf.RightVector or Vector3.new(1, 0, 0)
    local look = cf and cf.LookVector or Vector3.new(0, 0, -1)
    if MP_LOCAL.right == right and MP_LOCAL.look == look then return MP_LOCAL.dirs end
    MP_LOCAL.right, MP_LOCAL.look = right, look
    local up, dirs = MP_LOCAL.up, MP_LOCAL.dirs
    table.clear(dirs)
    for i = 1, #MP_LOCAL do
        local d = MP_LOCAL[i]
        local world = right * d.X + up * d.Y + look * d.Z
        if world.Magnitude > 0.05 then
            dirs[#dirs + 1] = world.Unit
        end
    end
    return dirs
end

Visual = Visual or {}
-- Half the round-trip time, from Stats (Data Ping, ms), refreshed twice a second
Visual.pingHalf = function()
    local now = os.clock()
    if now >= (Visual.pingAt or 0) then
        Visual.pingAt = now + 0.5
        local ok, ping = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
        Visual.pingV = ok and type(ping) == "number" and ping / 2000 or 0
    end
    return Visual.pingV
end

-- Bullet reach: what the ROUND sees. world_clear is a camera-style ray (glass, Transparency >= 0.9 and ignored collision groups stop it, none of them stops a round).
-- Visual.reach runs the game's own Ballistics.trace with the held gun's pen budget: a solid is crossed when thickness x Resist x Armor < budget left;
-- Stops names, Armor == true parts and every character end the round. Returns reaches, pierced.
Visual.bt = { params = RaycastParams.new(), group = false, nextTry = 0 }
Visual.bt.params.FilterType = Enum.RaycastFilterType.Exclude
Visual.bt.params.IgnoreWater = true
Visual.btModule = function()
    local B = Visual.bt
    if not B.group then
        local now = os.clock()
        if now >= B.nextTry then
            B.nextTry = now + 2
            local ok, reg = pcall(function() return game:GetService("PhysicsService"):IsCollisionGroupRegistered("Bullets") end)
            if ok and reg then B.params.CollisionGroup = "Bullets"; B.group = true end
        end
    end
    return Visual.sharedMod("Ballistics")
end
-- The wall mode of the held gun: a gun in CFG.NoWallbangGuns only gets clean lines.
Visual.wallMode = function()
    if CFG.NoWallbangGuns and held.id and CFG.NoWallbangGuns[held.id] then return "Off" end
    return CFG.Wallbang
end
Visual.penBudget = function()
    if Visual.wallMode() ~= "Game" then return 0 end
    local g = guns()
    local def = held.id and g and g.Defs[held.id]
    return def and not def.melee and not def.gadget and def.pen or 0
end
Visual.reach = function(from, to, model, pen)
    local d = to - from
    local dist = d.Magnitude
    if dist < 0.05 then return true, false end
    local Bal = Visual.btModule()
    if not Bal then return world_clear(from, to, model), false end -- Ballistics not loadable: the camera-style ray is all that is left
    local r = Bal.trace(from, d / dist, model and dist + 2 or dist, pen or 0, Visual.bt.params, vis_list())
    local contacts, pierced = r.contacts, false
    for i = 1, #contacts do
        if contacts[i].kind == "in" then pierced = true; break end
    end
    local stop = r.stop
    if stop == nil then return true, pierced end
    if model and stop.part and stop.part:IsDescendantOf(model) then return true, pierced end
    return false, pierced
end
Visual.reachCache = setmetatable({}, { __mode = "k" })
Visual.reachCached = function(key, from, to, model, pen)
    local ttl, now = CFG.VisCacheSec or 0, os.clock()
    local slot = Visual.reachCache[key]
    if slot and ttl > 0 and now - slot.t < ttl and slot.pen == pen
        and (slot.from - from).Magnitude < 0.25 and (slot.to - to).Magnitude < 0.25 then
        return slot.v, slot.p
    end
    local v, pierced = Visual.reach(from, to, model, pen)
    if not slot then slot = {}; Visual.reachCache[key] = slot end
    slot.t, slot.v, slot.p, slot.from, slot.to, slot.pen = now, v, pierced, from, to, pen
    return v, pierced
end
-- A point on the target the held gun can pierce to: head centre first, then torso / hips / root (a thin wall may let the body through where
-- the head does not). Wallbang "Ignore" aims at the bone without looking. Returns the point or nil.
Visual.pierce = function(row, from, fresh)
    local mode = Visual.wallMode()
    local bone, model = row.bone, row.model
    if mode == "Ignore" then return bone.Position end
    if mode ~= "Game" then return nil end
    local pen = Visual.penBudget()
    if pen <= 0 then return nil end
    local c = bone.Position
    local ok
    if fresh then ok = Visual.reach(from, c, model, pen) else ok = Visual.reachCached(bone, from, c, model, pen) end
    if ok then return c end
    if bone.Name == "Head" then
        local parts = Visual.bodyParts(model)
        for i = 1, #parts do
            local part = parts[i]
            if part and part.Parent then
                local pt = part.Position
                if Visual.reach(from, pt, model, pen) then return pt end
            end
        end
    end
    return nil
end

-- MultiPoint v3: the claimed origin is a point on camera-relative directions around the real head, searched on the firing frame:
-- no spoof if the line is clear > preferred distance (MPReach * MPPreferFrac) per direction > the neighbouring bands > the full budget.
-- A candidate needs a clear head->point line, a clear point->aim line and a forward bullet (Visual.mpFwd). The budget shrinks by speed x lag while we move (MPLagComp).
Visual.mpBudget = function()
    local limit = math.max(CFG.MPReach, 1)
    local cfg = Visual.speedCfg()
    local slack = cfg and cfg.Guns and cfg.Guns.OriginSlack
    if type(slack) == "number" then limit = math.min(limit, slack - CFG.MPSlackMargin) end
    if CFG.MPLagComp then
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local v = root.AssemblyLinearVelocity
            local sp = math.sqrt(v.X * v.X + v.Z * v.Z)
            limit = math.max(limit - sp * (Visual.pingHalf() + CFG.MPLagExtra), math.min(1.5, limit))
        end
    end
    return limit
end
-- The peek direction must stay within 60 degrees of the honest head-to-target line, or the bullet turns back toward us.
Visual.mpFwd = function(origin, pt, aim)
    local to, base = aim - pt, aim - origin
    local tm, bm = to.Magnitude, base.Magnitude
    return tm >= 1.5 and (bm < 1 or to:Dot(base) >= 0.5 * tm * bm)
end
-- head > origin stays a camera-style ray (the server may check the claimed origin against the walls it knows, and a part the round ignores
-- is still a part); origin > aim is the ROUND's line with the budget given (0 = clean).
local function mp_ok(origin, pt, aim, model, pen)
    return Visual.mpFwd(origin, pt, aim) and world_clear(origin, pt, nil) and (Visual.reach(pt, aim, model, pen))
end
local function find_multipoint(origin, aim, model, pen)
    pen = pen or 0
    if not CFG.MultiPoint or (aim - origin).Magnitude > sa_reach() then
        return nil
    end
    if Visual.reach(origin, aim, model, pen) then
        return origin
    end
    local limit = Visual.mpBudget()
    local frac = math.clamp(CFG.MPPreferFrac, 0.15, 0.9)
    local prefer = limit * frac
    local dirs = mp_dirs()
    for i = 1, #dirs do
        local pt = origin + dirs[i] * prefer
        if mp_ok(origin, pt, aim, model, pen) then return pt end
    end
    local bandA, bandB = limit * math.min(frac + 0.15, 0.85), limit * math.max(frac - 0.15, 0.2)
    local best, bestDev = nil, math.huge
    for i = 1, #dirs do
        for _, dist in { bandA, bandB } do
            local pt = origin + dirs[i] * dist
            local dev = math.abs(dist - prefer)
            if dev < bestDev and mp_ok(origin, pt, aim, model, pen) then best, bestDev = pt, dev end
        end
    end
    if best then return best end
    for i = 1, #dirs do
        local pt = origin + dirs[i] * limit
        if mp_ok(origin, pt, aim, model, pen) then return pt end
    end
    return nil
end


-- Resolver: Resolver.fly integrates the game's own round (Exterior.path with GunPhysics, Ballistics.arcAt without; tEnd = timeTo * 1.04), so flight time and sag are the game's numbers.
-- Resolver.apply iterates (aim, flight time, led point) to a fixed point. The server's placement of the target in time is not in the dump:
-- Resolver.lagTime is the one assumed shift, printed in every shot log line.
Resolver = { track = setmetatable({}, { __mode = "k" }), N = 64, SampleRate = 1 / 120 }
-- r = { n, i, t[], x[], y[], z[], root, seen }: numbers only, ring of root positions
Resolver.push = function(r, root, now)
    if r.i > 0 and now - r.t[r.i] > 0.6 then
        r.n, r.i, r.chgAt, r.reactUntil, r.cf = 0, 0, now, nil, nil
    end
    local p = root.Position -- translation of root.CFrame; no reported velocity is consumed
    local c = r.cf
    if not c then
        c = { n = 0, i = 0, t = {}, x = {}, y = {}, z = {} }
        r.cf = c
    end
    local changed = c.i == 0
    if not changed then
        local dx, dy, dz = p.X - c.x[c.i], p.Y - c.y[c.i], p.Z - c.z[c.i]
        local d2, gap = dx * dx + dy * dy + dz * dz, now - c.t[c.i]
        changed = d2 > 0.0004
        if changed and gap > 0 then
            if math.sqrt(d2) > math.max(12, (c.speed or 0) * gap * 3 + 3) then
                c.n, c.i, c.speed, c.cadence, r.reactUntil = 0, 0, nil, nil, nil
                r.n, r.i = 0, 0 -- discontinuity: never fit a velocity through the snap
            else
                c.speed = math.sqrt(d2) / gap
                c.cadence = c.cadence and c.cadence * 0.5 + gap * 0.5 or gap
            end
        end
    end
    if changed then
        local eventAt = now
        if c.i > 0 and r.i > 0 and now - c.t[c.i] > 1.5 * math.max(now - r.t[r.i], 0.001) then
            eventAt = (now + r.t[r.i]) * 0.5 -- only a held pose has an unknown change time between samples
        end
        local j = c.i % Resolver.N + 1
        c.t[j], c.x[j], c.y[j], c.z[j] = eventAt, p.X, p.Y, p.Z
        c.i, c.n, r.chgAt = j, math.min(c.n + 1, Resolver.N), eventAt
    end
    local i = r.i % Resolver.N + 1
    r.t[i], r.x[i], r.y[i], r.z[i] = now, p.X, p.Y, p.Z
    r.i, r.n = i, math.min(r.n + 1, Resolver.N)
end
-- consider() calls this for every enemy in reach (on or off screen) at the pick rate; r.seen keeps Resolver.sweep alive for it.
Resolver.sample = function(model, root, now)
    local r = Resolver.track[model]
    if not r then
        r = { n = 0, i = 0, t = {}, x = {}, y = {}, z = {} }
        Resolver.track[model] = r
    end
    r.root, r.seen = root, now
    if r.i > 0 and now - r.t[r.i] + 1e-6 < Resolver.SampleRate then return end
    Resolver.push(r, root, now)
end
-- Track up to 120 Hz while seen recently; 64 samples retain the long regression window.
Resolver.sweep = function(now)
    for model, r in pairs(Resolver.track) do
        local root, last = r.root, r.t[r.i]
        local unseen = now - (r.seen or 0)
        if not root or not root.Parent or unseen > 2 then
            Resolver.track[model] = nil -- this history is already too old to participate in prediction
        elseif last and now - last + 1e-6 >= Resolver.SampleRate and unseen < 0.5 then
            Resolver.push(r, root, now)
        end
    end
end
-- Least-squares line through the samples with age in [lo, hi] (the replicated root arrives in steps, the regression averages them). Returns the slope per axis and the mean age, or nil with < 3 samples.
Resolver.fit = function(r, lo, hi)
    local N, i = Resolver.N, r.i
    local tn = r.t[i]
    local n, st, stt, sx, sy, sz, stx, sty, stz = 0, 0, 0, 0, 0, 0, 0, 0, 0
    for k = 0, r.n - 1 do
        local j = (i - k - 1) % N + 1
        local age = tn - r.t[j]
        if age > hi then break end
        if age >= lo then
            local t, x, y, z = -age, r.x[j], r.y[j], r.z[j]
            n += 1
            st += t; stt += t * t
            sx += x; sy += y; sz += z
            stx += t * x; sty += t * y; stz += t * z
        end
    end
    if n < 3 then return nil end
    local den = n * stt - st * st
    if den < 1e-6 then return nil end
    return (n * stx - st * sx) / den, (n * sty - st * sy) / den, (n * stz - st * sz) / den, -st / n
end
-- Two-point slope (newest vs the first sample >= 0.04 s older, within 0.3 s): only when a hitch left < 3 points in the recent window.
Resolver.pair = function(r)
    local N, i = Resolver.N, r.i
    local tn = r.t[i]
    for k = 1, r.n - 1 do
        local j = (i - k - 1) % N + 1
        local age = tn - r.t[j]
        if age > 0.3 then return nil end
        if age >= 0.04 then
            return (r.x[i] - r.x[j]) / age, (r.y[i] - r.y[j]) / age, (r.z[i] - r.z[j]) / age, age * 0.5
        end
    end
    return nil
end
-- Jumping / bhopping: the humanoid reports no floor AND the root moved vertically (|vy| > 5 st/s now, or a 1.5 st range in the last 0.5 s: the apex has vy ~ 0).
Resolver.airborne = function(model)
    local hum = hum_of(model)
    if not hum or hum.FloorMaterial ~= Enum.Material.Air or hum.SeatPart ~= nil then return false end
    local r = Resolver.track[model]
    if not r or r.n < 3 then return false end
    local N, i = Resolver.N, r.i
    local tn, lo, hi = r.t[i], r.y[i], r.y[i]
    for k = 1, r.n - 1 do
        local j = (i - k - 1) % N + 1
        if tn - r.t[j] > 0.5 then break end
        local y = r.y[j]
        if y < lo then lo = y elseif y > hi then hi = y end
    end
    if hi - lo >= 1.5 then return true end
    local vy = select(2, Resolver.fit(r, 0, 0.18))
    return vy ~= nil and math.abs(vy) > 5
end
-- Position-only motion: changed-pose regression preserves burst updates; the dense sample ring detects turns/stops.
Resolver.motion = function(model, root, veh, now)
    Resolver.whyNot, Resolver.vsrc = nil, "cf-fit"
    local r = Resolver.track[model]
    if not r or r.n < 2 then Resolver.whyNot = "hist"; return nil end
    if now - r.t[r.i] > 0.3 then Resolver.whyNot = "stale"; return nil end
    local c = r.cf
    if not c or c.n < 2 then return 0, 0, 0, 0, 0, 0, 0, 0, 0 end
    local vx, vy, vz, c1 = Resolver.fit(c, 0, veh and 0.4 or 0.18)
    if not vx then
        local j = (c.i - 2) % Resolver.N + 1
        local dt = c.t[c.i] - c.t[j]
        if dt <= 0 or dt > 0.6 then Resolver.whyNot = "hist"; return nil end
        vx, vy, vz = (c.x[c.i] - c.x[j]) / dt, (c.y[c.i] - c.y[j]) / dt, (c.z[c.i] - c.z[j]) / dt
        c1 = dt * 0.5
        Resolver.vsrc = "cf-step"
    end
    local ox, oy, oz, c2 = Resolver.fit(c, veh and 0.4 or 0.18, veh and 0.8 or 0.40)
    local slope = false
    if not veh then
        local hum = CFG.SlopeLead and hum_of(model)
        slope = hum and hum.FloorMaterial ~= Enum.Material.Air and ox ~= nil and math.abs(vy) >= 2 and math.abs(vy) <= 40 and oy * vy > 0
        if not slope then vy, oy = 0, 0 end
    end
    local ax, ay, az, unc = 0, 0, 0, 0
    local top = math.sqrt(vx * vx + vy * vy + vz * vz)
    if ox then
        local dx, dy, dz = vx - ox, vy - oy, vz - oz
        unc = math.sqrt(dx * dx + dy * dy + dz * dz)
        local old = math.sqrt(ox * ox + oy * oy + oz * oz)
        top = math.max(top, old)
        -- Only coherent velocity windows justify extending acceleration into the future.
        if c2 - c1 > 0.05 and old > 2 and vx * ox + vy * oy + vz * oz > 0.9 * math.sqrt(vx * vx + vy * vy + vz * vz) * old then
            ax, ay, az = dx / (c2 - c1), veh and dy / (c2 - c1) or 0, dz / (c2 - c1)
            local am = math.sqrt(ax * ax + ay * ay + az * az)
            local k = CFG.ResolverAccelK * math.min(1, CFG.ResolverAccel / math.max(am, 0.001))
            ax, ay, az = ax * k, ay * k, az * k
            vx, vy, vz = vx + ax * c1, vy + ay * c1, vz + az * c1
        end
    end
    local age = math.max(now - c.t[c.i], 0)
    local cadence = c.cadence or 1 / 60
    if cadence <= 0.045 and not veh then
        local fx, _, fz = Resolver.fit(r, 0, 0.06)
        if fx then
            local fm, speed = math.sqrt(fx * fx + fz * fz), math.sqrt(vx * vx + vz * vz)
            local dx, dz = fx - vx, fz - vz
            local change = math.sqrt(dx * dx + dz * dz)
            local turn = fm > 3 and speed > 3 and fx * vx + fz * vz < 0.75 * fm * speed
            local brake = fm < speed * 0.45 and speed > 4
            if change > 4 and (turn or brake) then r.reactUntil = now + 0.12 end
            if now <= (r.reactUntil or -math.huge) then
                vx, vz, ax, ay, az = fx, fz, 0, 0, 0
                top, unc = math.max(top, fm), math.max(unc, change)
                Resolver.vsrc = fm < 1.5 and "cf-stop" or "cf-turn"
            end
        end
    end
    -- A pose held beyond its observed update cadence is ambiguous: fade extrapolation instead of trusting reported velocity.
    local hold = math.max(0.08, cadence * 1.6)
    if age > hold then
        local k = math.clamp(1 - (age - hold) / math.max(cadence, 0.08), 0, 1)
        vx, vy, vz, ax, ay, az = vx * k, vy * k, vz * k, 0, 0, 0
        if k == 0 then top = 0; Resolver.vsrc = "cf-stop" end
    end
    local stale = age >= 0.05 and math.min(age, 0.4) or 0
    if Resolver.vsrc == "cf-stop" then stale = 0 end
    return vx, vy, vz, ax, ay, az, top, unc, stale
end
-- Offset (studs) after t seconds: constant acceleration, a braking component stops at standstill (no reversal through zero),
-- and the result never exceeds the top recent speed * t.
Resolver.offset = function(vx, vy, vz, ax, ay, az, top, t)
    local sp = math.sqrt(vx * vx + vy * vy + vz * vz)
    local te = t
    if sp > 0.1 then
        local par = (ax * vx + ay * vy + az * vz) / sp
        if par < 0 then te = math.min(t, sp / -par) end
    end
    local tr = t - te
    local fx = vx * te + 0.5 * ax * te * te
    local fy = vy * te + 0.5 * ay * te * te
    local fz = vz * te + 0.5 * az * te * te
    if tr > 0 then
        fx, fy, fz = fx + (vx + ax * te) * tr, fy + (vy + ay * te) * tr, fz + (vz + az * te) * tr
    end
    local m = math.sqrt(fx * fx + fy * fy + fz * fz)
    local lim = top * t
    if m > lim and m > 0 then
        local k = lim / m
        fx, fy, fz = fx * k, fy * k, fz * k
    end
    return fx, fy, fz
end
Visual.phys = { cache = {} }
Visual.sharedMod = function(name)
    local P = Visual.phys
    local m = P[name]
    if m == nil then
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local inst = shared and shared:FindFirstChild(name)
        if not inst then return nil end -- not streamed yet: ask again next time instead of caching a failure
        local ok, r = pcall(require, inst)
        m = ok and type(r) == "table" and r or false
        P[name] = m
    end
    return m or nil
end
Visual.physExt = function() return Visual.sharedMod("Exterior") end
-- The held weapon's round exactly as Guns.shoot builds it: { round, ext, v, tEnd, drop, dt, range, physics }. Never nil for a gun def.
Visual.flight = function(id, def)
    if not (id and def and def.range) then return nil end
    local physics = ReplicatedStorage:GetAttribute("GunPhysics") == true
    local ext = physics and Visual.physExt() or nil
    local round = ext and ext.roundOf(id) or nil
    local f = Visual.phys.cache[id]
    if f and f.round == round and f.range == def.range and f.physics == physics and f.legacyV == def.velocity then return f end
    local v, tEnd = def.velocity or 1500, nil
    if round then
        v = ext.muzzle(id) or v
        tEnd = ext.timeTo(round, v, def.range) * 1.04 -- the game's own duration
    else
        ext = nil
        tEnd = def.range / math.max(v, 1) * 1.04 -- Ballistics.arcTime
    end
    f = { round = round, ext = ext, v = v, tEnd = tEnd, drop = def.drop or 0, range = def.range, physics = physics, legacyV = def.velocity,
        dt = ext and ext.STEP or (1 / 30) }
    Visual.phys.cache[id] = f
    return f
end
-- Fly the round from `from` along the unit `u` until it has covered `dist` studs measured ALONG u. Returns the flight time (s),
-- the sag (round position at that moment - (from + u * dist), a vector) and true when the round ends (tEnd) before getting there.
Resolver.fly = function(f, from, u, dist)
    local dt, tEnd, ext = f.dt, f.tEnd, f.ext
    local t, p0, prev, v0 = 0, from, 0, nil
    if ext then v0 = u * f.v end
    local ux, uy, uz, v, hg = u.X, u.Y, u.Z, f.v, f.drop * 0.5
    while t < tEnd do
        local p1, v1
        local t1 = t + dt
        if ext then
            p1, v1 = ext.step(f.round, p0, v0, dt)
        else
            p1 = Vector3.new(from.X + ux * v * t1, from.Y + uy * v * t1 - hg * t1 * t1, from.Z + uz * v * t1)
        end
        local pr = (p1 - from):Dot(u)
        if pr >= dist then
            local k = pr > prev and (dist - prev) / (pr - prev) or 1
            local pos
            if ext then
                -- inside the step the game reads Exterior.pathAt = cubic Hermite through (p0, v0) and (p1, v1): the same curve, so the
                -- crossing is solved on it (a straight chord is up to ~0.5 st off for a 3000 st/s round that covers 100 st per step)
                local d0, d1 = v0:Dot(u) * dt, v1:Dot(u) * dt
                local a = 2 * prev - 2 * pr + d0 + d1
                local b = -3 * prev + 3 * pr - 2 * d0 - d1
                local klo, khi = 0, 1
                for _ = 1, 22 do
                    local km = (klo + khi) * 0.5
                    if ((a * km + b) * km + d0) * km + prev < dist then klo = km else khi = km end
                end
                k = (klo + khi) * 0.5
                local k2, k3 = k * k, k * k * k
                pos = p0 * (2 * k3 - 3 * k2 + 1) + v0 * ((k3 - 2 * k2 + k) * dt) + p1 * (3 * k2 - 2 * k3) + v1 * ((k3 - k2) * dt)
            else
                pos = p0:Lerp(p1, k)
            end
            return t + dt * k, pos - (from + u * dist), false
        end
        prev, p0, v0, t = pr, p1, v1, t1
    end
    return tEnd, p0 - (from + u * dist), true
end
-- Signed time added to the flight when the server's picture of the target is not the one we draw: only the part of (ping + PredictInterp - RewindView) beyond RewindSlack counts.
-- Unverified model, printed as `ping lead`.
Resolver.lagTime = function(now)
    if now < (Resolver.lagAt or 0) then return Resolver.lag or 0 end
    Resolver.lagAt = now + 0.5
    local lag = 0
    local ok, ping = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
    local cfg = Visual.speedCfg()
    local gcfg = cfg and cfg.Guns
    if ok and type(ping) == "number" and gcfg then
        local te = ping / 1000 + CFG.PredictInterp - (gcfg.RewindView or 0.18)
        local beyond = math.max(math.abs(te) - (gcfg.RewindSlack or 0.04), 0)
        lag = math.clamp(te < 0 and -beyond or beyond, -0.1, 0.15)
    end
    Resolver.lag = lag
    return lag
end
-- Sets tgt.pos (aim point) and the log fields lead, drop, flightT, speed, unc, lag, veh, why (nil|"still"|"hist"|"stale"|"range"); `still` = drop only.
-- Fixed point: T(t) = raw + offset(t + lag); aim = the point whose launch direction puts the round on T(t) after t seconds of flight.
Resolver.apply = function(tgt, from, now, still)
    local raw = tgt.raw
    tgt.pos, tgt.lead, tgt.speed, tgt.veh, tgt.drop, tgt.flightT, tgt.unc, tgt.lag, tgt.why = raw, 0, 0, false, 0, nil, nil, 0, nil
    tgt.stale, tgt.vsrc, tgt.T = 0, "fit", nil
    local g = guns()
    local def = held.id and g and g.Defs[held.id]
    if not def or def.melee or def.gadget or def.sledge then return end
    local f = Visual.flight(held.id, def)
    if not f then return end
    local vx, vy, vz, ax, ay, az, top, unc = 0, 0, 0, 0, 0, 0, 0, 0
    local lag, stale = 0, 0
    if not still then
        local root = bone_of(tgt.model, "HumanoidRootPart")
        if root then
            Resolver.sample(tgt.model, root, now)
            local hum = hum_of(tgt.model)
            local veh = hum ~= nil and hum.SeatPart ~= nil
            tgt.veh = veh
            local mx, my, mz, ma, mb, mc, mtop, munc, mstale = Resolver.motion(tgt.model, root, veh, now)
            if mx then
                vx, vy, vz, ax, ay, az, top, unc, stale = mx, my, mz, ma, mb, mc, mtop, munc, mstale or 0
                tgt.vsrc = Resolver.vsrc
                if math.sqrt(vx * vx + vy * vy + vz * vz) < 1.5 and top < 1.5 then
                    vx, vy, vz, ax, ay, az = 0, 0, 0, 0, 0, 0
                    tgt.why = "still"
                end
            else
                tgt.why = Resolver.whyNot or "hist"
            end
        else
            tgt.why = "hist"
        end
        if CFG.PingPredict then lag = Resolver.lagTime(now) end
    end
    local cap = CFG.LeadCap
    local t, aim, T = 0, raw, raw
    for _ = 1, 4 do
        local tt = t + lag + stale
        local ox, oy, oz = 0, 0, 0
        if tt > 0 then ox, oy, oz = Resolver.offset(vx, vy, vz, ax, ay, az, top, tt) end
        if not tgt.veh then oy = math.clamp(oy, -CFG.SlopeCap, CFG.SlopeCap) end
        local m2 = ox * ox + oy * oy + oz * oz
        if m2 > cap * cap then local k = cap / math.sqrt(m2); ox, oy, oz = ox * k, oy * k, oz * k end
        T = Vector3.new(raw.X + ox, raw.Y + oy, raw.Z + oz)
        local d = aim - from
        local dm = d.Magnitude
        if dm < 0.5 then break end
        local u = d / dm
        local dist = (T - from):Dot(u)
        if dist < 0.5 then break end
        local nt, sag, short = Resolver.fly(f, from, u, dist)
        t = nt
        if short then tgt.why = "range" end
        aim = aim + (T - (from + u * dist) - sag)
    end
    tgt.pos = aim
    tgt.T = T
    tgt.lead, tgt.drop, tgt.flightT = (T - raw).Magnitude, aim.Y - T.Y, t
    tgt.speed, tgt.unc, tgt.lag, tgt.stale = math.sqrt(vx * vx + vy * vy + vz * vz), unc, lag, stale
end

-- The overlay solves the peek every MPRate (cached per target while neither the head nor the aim moved 0.25 st); the shot
-- (fresh) never reuses that result: the claimed origin is searched again on the firing frame.
Visual.mp = setmetatable({}, { __mode = "k" })
local function mp_spoof(from, aimPoint, model, fresh, now, pen)
    pen = pen or 0
    local c = Visual.mp[model]
    if not c then c = { at = -math.huge }; Visual.mp[model] = c end
    if not fresh and c.from and c.point and c.pen == pen and now - c.at <= CFG.MPRate
        and (c.from - from).Magnitude < 0.25 and (c.point - aimPoint).Magnitude < 0.25 then
        return c.spoof or nil
    end
    local spoof = find_multipoint(from, aimPoint, model, pen)
    if spoof == from then spoof = nil end -- the line is open already: nothing to spoof
    c.from, c.point, c.spoof, c.at, c.pen = from, aimPoint, spoof or false, now, pen
    return spoof
end

-- Aim point on the target: head centre first; when covered try the head's top/bottom/sides, then torso and root, first with a clear line. Cached 0.1 s per model.
Visual.aimPts = setmetatable({}, { __mode = "k" })
Visual.aimParts = setmetatable({}, { __mode = "k" })
local function aim_pos(k, row, parts)
    local bone = row.bone
    local pos = bone.Position
    if k == 1 then return pos end
    if k == 2 then return pos + Vector3.new(0, bone.Size.Y * 0.42, 0) end
    if k == 3 then return pos - Vector3.new(0, bone.Size.Y * 0.32, 0) end
    if k == 4 then return pos + bone.CFrame.RightVector * (bone.Size.X * 0.38) end
    if k == 5 then return pos - bone.CFrame.RightVector * (bone.Size.X * 0.38) end
    local part = parts[k - 5]
    return part and part.Parent and part.Position or nil
end
Visual.bodyParts = function(model)
    local px = Visual.dn.proxies[model]
    if px and px.on then return { px.ut, px.lt, px.lt } end -- DownedReplicaFix: where the lying body is, not our standing rig
    local parts = Visual.aimParts[model]
    if not (parts and parts[3] and parts[3].Parent) then
        parts = { model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso"), model:FindFirstChild("LowerTorso"), model:FindFirstChild("HumanoidRootPart") }
        Visual.aimParts[model] = parts
    end
    return parts
end
-- stage 1: head centre, then head top/bottom/sides (k 2..5); stage 2: torso/hips/root (k 6..8, head targets only).
-- MultiPoint sits BETWEEN the stages so a covered head is peeked at before the aim drops to the body.
Visual.aimPoint = function(row, from, fresh, now, deep, stage)
    local model, bone = row.model, row.bone
    if stage <= 1 then
        local center = bone.Position
        if fresh then
            if Visual.reach(from, center, model, 0) then return center end
        elseif Visual.reachCached(bone, from, center, model, 0) then
            return center
        end
        if stage == 0 then return nil end -- stage 0 = head centre only (MPFirst), stage 1 = centre + edges
    end
    if not (deep and CFG.AimPoints) then return nil end
    local head = bone.Name == "Head"
    local lo, hi
    if stage == 1 then
        lo, hi = 2, head and 5 or 3
    elseif head then
        lo, hi = 6, 8
    else
        return nil
    end
    local E = Visual.aimPts[model]
    if not E then E = {}; Visual.aimPts[model] = E end
    local e = E[stage]
    if not e then e = { k = 0, at = -math.huge, from = from }; E[stage] = e end
    local parts = Visual.bodyParts(model)
    if now - e.at < 0.1 and (e.from - from).Magnitude < 0.25 then
        if e.k > 0 then
            local pt = aim_pos(e.k, row, parts)
            if pt and (not fresh or Visual.reach(from, pt, model, 0)) then return pt end
        elseif not fresh then
            return nil
        end
    end
    e.at, e.from, e.k = now, from, 0
    for k = lo, hi do
        local pt = aim_pos(k, row, parts)
        if pt and Visual.reach(from, pt, model, 0) then
            e.k = k
            return pt
        end
    end
    return nil
end

-- Worn helmets: a round is stopped when Exterior.Rounds[round].need exceeds Helmets.Tiers[tier].rating (rare IIIA stops pistol, mp5, shotguns, honey badger; epic III all but rifle and sniper).
-- The pieces sit under the wearer's Head with attribute HelmetPiece = the item id. Server code is not in the dump, the first sighting is logged.
Visual.helm = setmetatable({}, { __mode = "k" })
Visual.helmetStops = function(model, head, now)
    local c = Visual.helm[model]
    if not c then c = { at = -1 }; Visual.helm[model] = c end
    if now - c.at >= 0.5 then
        c.at, c.gun = now, nil
        local id
        for _, d in head:GetDescendants() do
            local v = d:GetAttribute("HelmetPiece")
            if v ~= nil then id = v; break end
        end
        if id ~= c.id and id and CFG.ShotLog then warn("[hush] helmet seen on " .. model.Name .. ": " .. tostring(id)) end
        c.id = id
    end
    if not c.id then return false end
    if c.gun ~= held.id then
        c.gun, c.stop = held.id, false
        local H, E = Visual.sharedMod("Helmets"), Visual.physExt()
        local tier = H and type(H.parse) == "function" and H.parse(c.id)
        local def = tier and H.Tiers[tier]
        local round = E and E.roundOf(held.id)
        if def and round and not def.stopsNone and ReplicatedStorage:GetAttribute("GunPhysics") == true then
            c.stop = E.stops(def.rating, round)
        end
    end
    return c.stop
end

-- ServerSpread: the server's direction is a uniform disc around ours (centre offset ~0, radius ~0.1 deg for an ADS rifle). The aim moves to where the disc covers the most weighted body area.
Visual.cone = { g = {} }
Visual.coneKey = function(id)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return id .. ":" .. (char and char:GetAttribute("Aiming") == true and "a" or "h")
        .. (char and char:GetAttribute("Crouch") == true and "c" or "s")
        .. (hum and hum.FloorMaterial == Enum.Material.Air and "f" or "g")
        .. (hum and hum.MoveDirection.Magnitude > 0.1 and "m" or "i")
        .. (char and char:GetAttribute("CarLean") ~= nil and "l" or "n")
end
Visual.coneR = function(id, def)
    local cfg = Visual.speedCfg()
    local focus = cfg and cfg.Guns and cfg.Guns.FocusSpread or 0.35
    local s2 = def and def.spread and def.spread[2] or 0.4
    local prior = math.tan(math.rad(s2 * focus * 0.8)) -- rifle 0.112 deg, sniper 0.0144 deg (measured 0.106-0.122 / 0.016 with claim 0)
    local e = Visual.cone.g[Visual.coneKey(id)]
    if not e then return prior end
    return (prior * 3 + 1.5 * e.sum) / (3 + e.n) -- E[r] of a uniform disc = 2/3 R
end
Visual.coneAdd = function(key, r)
    if r > 0.012 then return end -- hip / rejected-origin shots are another population
    local e = Visual.cone.g[key]
    if not e then e = { n = 0, sum = 0 }; Visual.cone.g[key] = e end
    if e.n >= 40 then e.n, e.sum = e.n * 0.5, e.sum * 0.5 end
    e.n += 1
    e.sum += r
end
Visual.ssDisc = (function()
    local t, n = {}, 19
    for i = 1, n do
        local r, a = math.sqrt((i - 0.5) / n), i * 2.399963
        t[i] = { math.cos(a) * r, math.sin(a) * r }
    end
    return t
end)()
Visual.ssWeight = function(name)
    if name == "Head" then return CFG.SSHead end
    if name == "UpperTorso" or name == "LowerTorso" or name == "Torso" then return 1 end
    if string.find(name, "Arm", 1, true) or string.find(name, "Leg", 1, true) or string.find(name, "Hand", 1, true) or string.find(name, "Foot", 1, true) then return CFG.SSLimb end
    return 0
end
Visual.ssLists = setmetatable({}, { __mode = "k" })
Visual.ssList = function(model, now)
    local c = Visual.ssLists[model]
    if c and now - c.at < 2 then return c.list end
    local list = {}
    for _, d in model:GetChildren() do
        if d:IsA("BasePart") then
            local w = Visual.ssWeight(d.Name)
            if w > 0 then list[#list + 1] = { part = d, w = w } end
        end
    end
    Visual.ssLists[model] = { at = now, list = list }
    return list
end
-- share of the cone (value-weighted) that ends on the target when the aim is `cand`; fr = per-solve part frames seen from the origin O
Visual.ssScore = function(fr, O, cand, rho)
    local base = cand - O
    local L = base.Magnitude
    if L < 1 then return 0 end
    local fwd = base / L
    local right = fwd:Cross(Vector3.yAxis)
    if right.Magnitude < 0.05 then right = fwd:Cross(Vector3.xAxis) end
    right = right.Unit
    local up = right:Cross(fwd)
    local disc, cfs, ol, hs, ws, n = Visual.ssDisc, fr.cfs, fr.ol, fr.hs, fr.ws, #fr.cfs
    local sum = 0
    for k = 1, #disc do
        local o = disc[k]
        local D = (cand + right * (o[1] * rho) + up * (o[2] * rho) - O).Unit
        local bestT, bestW = math.huge, 0
        for i = 1, n do
            local dl = cfs[i]:VectorToObjectSpace(D)
            local p, h = ol[i], hs[i]
            local tmin, tmax, miss = -math.huge, math.huge, false
            local px, dx, hx = p.X, dl.X, h.X
            if math.abs(dx) < 1e-9 then
                if math.abs(px) > hx then miss = true end
            else
                local t1, t2 = (-hx - px) / dx, (hx - px) / dx
                if t1 > t2 then t1, t2 = t2, t1 end
                if t1 > tmin then tmin = t1 end
                if t2 < tmax then tmax = t2 end
            end
            if not miss then
                local py, dy, hy = p.Y, dl.Y, h.Y
                if math.abs(dy) < 1e-9 then
                    if math.abs(py) > hy then miss = true end
                else
                    local t1, t2 = (-hy - py) / dy, (hy - py) / dy
                    if t1 > t2 then t1, t2 = t2, t1 end
                    if t1 > tmin then tmin = t1 end
                    if t2 < tmax then tmax = t2 end
                end
            end
            if not miss then
                local pz, dz, hz = p.Z, dl.Z, h.Z
                if math.abs(dz) < 1e-9 then
                    if math.abs(pz) > hz then miss = true end
                else
                    local t1, t2 = (-hz - pz) / dz, (hz - pz) / dz
                    if t1 > t2 then t1, t2 = t2, t1 end
                    if t1 > tmin then tmin = t1 end
                    if t2 < tmax then tmax = t2 end
                end
            end
            if not miss and tmin <= tmax and tmax > 0 then
                local t = tmin > 0 and tmin or tmax
                if t < bestT then bestT, bestW = t, ws[i] end
            end
        end
        sum += bestW
    end
    return sum / #disc
end
Visual.ssCache = setmetatable({}, { __mode = "k" })
-- returns the better aim point (Vector3), info  | nil when the head centre stays
Visual.serverSpread = function(tgt, now)
    local model, bone, O = tgt.model, tgt.bone, tgt.spoof
    if not (CFG.ServerSpread and bone.Name == "Head" and Players:GetPlayerFromCharacter(model)) or bone:GetAttribute("HushProxy") then return nil end
    local def = gun_row(held.id)
    if not def or (def.pellets or 1) > 1 then return nil end
    local head = tgt.raw
    local dist = (head - O).Magnitude
    local R = Visual.coneR(held.id, def)
    local rho0 = R * dist
    local speed = math.min(tgt.speed or 0, 40) -- from the previous solve of this row
    if rho0 < CFG.SSMin and speed < 4 then return nil end
    local slop = CFG.SSSlop + CFG.SSLeadSlop * speed -- the position of a fast target is only known to ~0.06 s of his speed
    local rho = math.sqrt(rho0 * rho0 + slop * slop)
    local c = Visual.ssCache[model]
    if c and now - c.at < 0.12 and (c.O - O).Magnitude < 0.3 and math.abs(c.rho - rho) < rho * 0.15 and (c.head - head).Magnitude < 0.6 then
        return c.pt, c.info
    end
    local parts = Visual.bodyParts(model)
    local ut, lt = parts[1], parts[2]
    if not (ut and ut.Parent) then return nil end
    local list = Visual.ssList(model, now)
    local fr = { cfs = {}, ol = {}, hs = {}, ws = {} }
    for i = 1, #list do
        local pt = list[i].part
        if pt.Parent then
            local cf = pt.CFrame
            local k = #fr.cfs + 1
            fr.cfs[k], fr.ol[k], fr.hs[k], fr.ws[k] = cf, cf:PointToObjectSpace(O), pt.Size * 0.5, list[i].w
        end
    end
    if #fr.cfs == 0 then return nil end
    local pu = ut.Position
    local pl = lt and lt.Parent and lt.Position or pu - Vector3.new(0, 1, 0)
    local cands = {
        { head, "Head" }, { head:Lerp(pu, 0.5), "Neck" }, { pu, ut.Name }, { pu:Lerp(pl, 0.5), "Belly" }, { pl, "LowerTorso" },
    }
    local scores = {}
    for i = 1, #cands do scores[i] = Visual.ssScore(fr, O, cands[i][1], rho) end
    local headScore = scores[1]
    local order = {}
    for i = 2, #cands do order[#order + 1] = i end
    table.sort(order, function(a, b) return scores[a] > scores[b] end)
    local pt, info = nil, { part = "Head", rho = rho0, R = R, pHead = headScore, p = headScore }
    for _, i in order do
        if scores[i] > headScore * (1 + CFG.SSGain) + 0.02 and Visual.reach(O, cands[i][1], model, 0) then
            pt, info = cands[i][1], { part = cands[i][2], rho = rho0, R = R, pHead = headScore, p = scores[i] }
            break
        end
    end
    Visual.ssCache[model] = { at = now, O = O, rho = rho, head = head, pt = pt, info = info }
    return pt, info
end

local function resolve_target(camOrigin, fresh)
    local head = LP.Character and LP.Character:FindFirstChild("Head")
    if not (head and head:IsA("BasePart")) or not Cam then return nil end
    if not pick_raw(camOrigin) then return Visual.bossPick(head.Position, fresh) end
    local from, now = head.Position, os.clock()
    local tgt, spoof, aimPt, pierceHow
    -- Rows come ordered by tier, then crosshair error. In a tier a visible candidate beats a blocked one; MultiPoint is tried (two rows) only when the tier has no visible candidate.
    -- The head centre goes first, other points only when it is covered.
    if CFG.VisibleCheck then
        local first, rows, count = 1, picks.rows, picks.n
        while first <= count and not tgt do
            local tier, last = rows[first].tier, first
            while last < count and rows[last + 1].tier == tier do last += 1 end
            for i = first, last do
                local pt = Visual.aimPoint(rows[i], from, fresh, now, i - first < 2, CFG.MPFirst and 0 or 1)
                if pt then tgt, aimPt = rows[i], pt; break end
            end
            if not tgt and CFG.MultiPoint then
                for i = first, math.min(last, first + 1) do
                    local row = rows[i]
                    local point = mp_spoof(from, row.bone.Position, row.model, fresh, now, 0)
                    if point and (point - from).Magnitude >= 0.25 then
                        tgt, spoof = row, point
                        break
                    end
                end
            end
            if not tgt and CFG.MPFirst then
                for i = first, last do
                    local pt = Visual.aimPoint(rows[i], from, fresh, now, i - first < 2, 1)
                    if pt then tgt, aimPt = rows[i], pt; break end
                end
            end
            if not tgt then
                for i = first, last do
                    local pt = Visual.aimPoint(rows[i], from, fresh, now, i - first < 2, 2)
                    if pt then tgt, aimPt = rows[i], pt; break end
                end
            end
            -- Every clean option (direct points, MP peeks, body points) is exhausted: spend penetration. The line is the game's own walk with the held
            -- gun's budget (Visual.reach), so a wall it cannot cross is not tried; first from the honest head, then from an MP origin.
            if not tgt then
                for i = first, last do
                    local pt = Visual.pierce(rows[i], from, fresh)
                    if pt then tgt, aimPt, pierceHow = rows[i], pt, true; break end
                end
            end
            if not tgt and CFG.MultiPoint then
                local pen = Visual.penBudget()
                if pen > 0 then
                    for i = first, math.min(last, first + 1) do
                        local row = rows[i]
                        local point = mp_spoof(from, row.bone.Position, row.model, fresh, now, pen)
                        if point and (point - from).Magnitude >= 0.25 then
                            tgt, spoof, pierceHow = row, point, true
                            break
                        end
                    end
                end
            end
            first = last + 1
        end
        -- Identical contract for preview and firing: no path means no silent target (a boss is the only extra candidate).
        if not tgt then return Visual.bossPick(from, fresh) end
    else
        tgt = picks.rows[1]
    end
    tgt.raw = aimPt or tgt.bone.Position
    tgt.how = not CFG.VisibleCheck and "direct" or (pierceHow and (spoof and "multipoint + pen" or (Visual.wallMode() == "Ignore" and "wall ignored" or "penetration"))
        or (spoof and "multipoint" or ((aimPt - tgt.bone.Position).Magnitude < 0.01 and "centre" or "edge / body point")))
    if tgt.bone:GetAttribute("HushProxy") then tgt.how = tgt.how .. " (downed replica)" end
    tgt.bodyAim = nil
    tgt.spoof, tgt.peek = spoof or from, spoof
    -- a helmet that stops this round turns a headshot into a wasted bullet: aim the torso while it is on
    if CFG.HelmetAim and tgt.bone.Name == "Head" and (tgt.raw - tgt.bone.Position).Magnitude < 0.9
        and Visual.helmetStops(tgt.model, tgt.bone, now) then
        local parts = Visual.bodyParts(tgt.model)
        local part = parts[1] or parts[3]
        if part and part.Parent and Visual.reach(tgt.spoof, part.Position, tgt.model, 0) then
            tgt.raw, tgt.bodyAim = part.Position, "helmet > " .. part.Name
        end
    end
    -- a jumper's head is a 1.2 st target that moves 1-3 st vertically between our picture and the server's: the upper torso is 3x taller
    if CFG.AirBody and not tgt.bodyAim and tgt.bone.Name == "Head" and (tgt.raw - tgt.bone.Position).Magnitude < 0.9
        and Players:GetPlayerFromCharacter(tgt.model) and Resolver.airborne(tgt.model) then
        local parts = Visual.bodyParts(tgt.model)
        local part = parts[1] or parts[3]
        if part and part.Parent and Visual.reach(tgt.spoof, part.Position, tgt.model, 0) then
            tgt.raw, tgt.bodyAim = part.Position, "air > " .. part.Name
        end
    end
    tgt.ss = nil
    if CFG.ServerSpread and not tgt.bodyAim and not pierceHow then
        local pt, info = Visual.serverSpread(tgt, now)
        tgt.ss = info
        if pt then
            tgt.raw = pt
            tgt.how = tgt.how .. " > cone " .. info.part
        end
    end
    tgt.pos = tgt.raw
    tgt.lead, tgt.speed, tgt.veh = 0, 0, false
    if CFG.Resolver then Resolver.apply(tgt, tgt.spoof, now) end
    -- the bullet leaves from the spoofed origin: that distance, to the final aim point, must be inside the gun's reach
    if (tgt.pos - tgt.spoof).Magnitude > sa_reach() then return nil end
    -- A visible raw head does not authorize a lead/drop aim point behind another wall.
    if CFG.VisibleCheck and Visual.wallMode() ~= "Ignore" and (tgt.pos - tgt.raw).Magnitude > 0.01
        and not Visual.reach(tgt.spoof, tgt.pos, tgt.model, Visual.penBudget()) then
        -- The peek was searched against the current head: search again against the led point first, only then drop the lead.
        local sp2 = CFG.MultiPoint and find_multipoint(from, tgt.pos, tgt.model, Visual.penBudget())
        if sp2 and sp2 ~= from then
            tgt.spoof, tgt.peek, tgt.how = sp2, sp2, "multipoint"
        elseif Visual.reach(tgt.spoof, tgt.raw, tgt.model, Visual.penBudget()) then
            Resolver.apply(tgt, tgt.spoof, now, true) -- the straight point keeps the gravity compensation, only the lead goes
        else
            return nil
        end
        if (tgt.pos - tgt.spoof).Magnitude > sa_reach() then return nil end -- the origin changed: reach again from the new one
    end
    return tgt
end

local function silent_plan()
    if not CFG.Silent then
        return nil
    end
    Cam = Workspace.CurrentCamera
    local head = LP.Character and LP.Character:FindFirstChild("Head")
    if not Cam or not (head and head:IsA("BasePart")) then
        return nil
    end
    local tgt = resolve_target(Cam.CFrame.Position, true)
    if not tgt or not tgt.bone then
        return nil
    end
    local spoof = tgt.spoof or head.Position
    local aim = tgt.pos
    local delta = aim - spoof
    if delta.Magnitude < 0.05 then
        return nil
    end
    lastAim = aim
    return {
        model = tgt.model,
        bone = tgt.bone,
        pos = aim,
        peek = tgt.peek,
        resolvedAt = os.clock(),
        dir = delta.Unit,
        offset = spoof - head.Position,
        head = head,
        spoof = spoof,
        aim = aim,
        lead = tgt.lead,
        speed = tgt.speed,
        veh = tgt.veh,
        bodyAim = tgt.bodyAim,
        how = tgt.how,
        drop = tgt.drop, flightT = tgt.flightT, unc = tgt.unc, lag = tgt.lag, why = tgt.why, stale = tgt.stale, vsrc = tgt.vsrc, T = tgt.T, raw = tgt.raw, ss = tgt.ss,
    }
end

-- Guns.shoot is found once, its helpers and state slots are kept. Redirected shots use the live packet/FX contract with an explicit origin.
Visual.fire = {}
Visual.fireShot = function(plan, id, hand)
    local b = Visual.fire
    local u, S, fn = b.u, b.S, oldShoot
    local guns = u[S.guns]
    local def, char = guns.Defs[id], LP.Character
    local from, dir = plan.spoof, plan.dir
    if not b.carLean.canFire(id, dir) then return fn(id, hand) end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local ignore = hum and (guns.rideOf(hum.SeatPart) or char:GetAttribute("CarLean") ~= nil) and u[S.aimIgnore]() or u[S.ignore]()
    u[S.params].FilterDescendantsInstances = u[S.aimIgnore]()
    -- The packet carries a scalar spread (degrees); the client uses it only to wobble its own tracer, the server keeps a cone of its own that floors at ~0.1 deg
    -- (rifle, scoped): the smallest claim, 0, is sent. sp0 = the game's own value, for the log.
    local sp0 = u[S.spread](def)
    local spread = 0
    if CFG.ShotLog then
        local root = char:FindFirstChild("HumanoidRootPart")
        local hp = plan.bone and plan.bone.Position
        local miss = hp and (hp - from):Cross(dir).Magnitude or -1
        local base, dev = plan.aim - plan.head.Position, 0
        if base.Magnitude > 0.1 then dev = math.deg(math.acos(math.clamp(dir:Dot(base.Unit), -1, 1))) end
        warn(string.format("[hush] origin offset %.2f st (budget %.2f / %.2f) | %s | aim %s | own speed %.0f | lead %.2f st | ray passes %.2f st from the bone centre | dir %.0f deg off head>aim | spread sent 0 (game %.2f) deg | drop %.2f st | flight %.3f s | unc %.0f st/s | ping lead %.3f s | stale %.2f s | target %.1f st/s (%s), lead %s",
            plan.offset.Magnitude, Visual.mpBudget(), CFG.MPReach, plan.how or "?",
            plan.bodyAim or "head/point", root and root.AssemblyLinearVelocity.Magnitude or -1, plan.lead or 0, miss, dev, sp0, plan.drop or 0, plan.flightT or 0, plan.unc or 0, plan.lag or 0, plan.stale or 0, plan.speed or 0, plan.vsrc or "fit", plan.why or "on"))
    end
    local speed = def.velocity or 1500
    local duration = u[S.ballistics].arcTime(def.range, speed)
    local fl = Visual.flight(id, def) -- GunPhysics: the game takes speed and duration from Exterior and passes the round id on
    if fl then speed, duration = fl.v, fl.tEnd end
    local boss = b.rounds.herAlong(from, dir * speed, def.drop or 0, duration, u[S.mother].rayHit, fl and fl.round) or -1
    local state = u[S.state]
    state.shotSeq = (state.shotSeq or 0) + 1
    local seq = state.shotSeq
    local cch = LP.Character
    Visual.sentBySeq[seq] = { from = from, dir = dir, aiming = cch ~= nil and cch:GetAttribute("Aiming") == true, coneKey = Visual.coneKey(id) }
    Visual.ledAdd({ seq = seq, ss = plan.ss and plan.ss.part or "-", body = plan.bodyAim, t = os.clock(), gun = id, name = plan.model and plan.model.Name or "?", dist = (plan.aim - from).Magnitude, lead = plan.lead or 0,
        speed = plan.speed or 0, veh = plan.veh, how = plan.how })
    Visual.crouchAB.tag = Visual.crouchABShot()
    if CFG.DebugFile then
        local okd, errd = pcall(Visual.dbgShot, plan, id, def, fl, from, dir, spread, sp0, seq, boss, os.clock())
        if not okd and not Visual.dbg.errWarned then Visual.dbg.errWarned = true; warn("[hush] debug file: shot record failed: " .. tostring(errd)) end
    end
    -- Exactly the CURRENT firearm payload: direction, scalar spread, boss distance, origin, sequence.
    u[S.gun]:FireServer("Fire", dir, spread, boss, from, seq)
    local muzzle = u[S.muzzle](char, hand) or from
    for i = 1, math.max(def.pellets, 1) do
        b.rounds.fly({own = true, key = "own:" .. seq .. ":" .. i,
            origin = from, v = u[S.wobble](dir, math.rad(spread)) * speed,
            drop = def.drop or 0, tEnd = duration, round = fl and fl.round, pen = CFG.Wallbang == "Ignore" and 99 or def.pen, muzzle = plan.peek and from or muzzle,
            color = def.tracer, ignore = ignore, trail = def.oneShot == true or def.scope == true})
    end
    -- Keep the game's flash, sound, recoil, bloom and heat on its ORIGINAL upvalue cells.
    local get = debug.getupvalue
    local suppressed = get(fn, S.suppr) ~= nil or def.integral ~= nil
    u[S.flash](muzzle, dir, suppressed)
    u[S.sound](char, id, suppressed)
    local gear = get(fn, S.gearCache) or u[S.gear].stats(id, get(fn, S.gearIn))
    local ads, ctl, skills = get(fn, S.ads), u[S.ctl], u[S.skills]
    local factor = (1 - ads * ads * (3 - ads * 2) * 0.15)
        * (not ctl.crouching and 1 or 0.85 * (def.crouch or 1))
        * (not skills.has(LP, "recoil_master") and 1 or skills.Fx.RecoilClimb)
    local heat = get(fn, S.heat)
    local base = def.recoil -- GunRecoilPhysics: the kick comes from the round's momentum (Exterior.recoil)
    if def.recoil > 0 and ReplicatedStorage:GetAttribute("GunRecoilPhysics") == true then
        local ext = Visual.physExt()
        local joules
        if ext then local _, _, j = ext.recoil(id); joules = j end
        if joules and joules > 0 then base = joules * (u[S.cfg].RecoilPerJ or 0.2303) end
    end
    local recoil = base * gear.recoilMul * (heat + 1) * factor
    local side = (math.random() * 2 - 1) * def.side * (def.recoil <= 0 and 1 or base / def.recoil) * gear.recoilMul * (heat + 1) * factor
    debug.setupvalue(fn, S.kick, get(fn, S.kick) + recoil * (1 - def.climb))
    debug.setupvalue(fn, S.climb, get(fn, S.climb) + recoil * def.climb)
    debug.setupvalue(fn, S.side, get(fn, S.side) + side * 0.7)
    debug.setupvalue(fn, S.sideSlow, get(fn, S.sideSlow) + side * 0.3)
    debug.setupvalue(fn, S.heat, math.min(u[S.cfg].HeatMax, heat + u[S.cfg].HeatPerShot))
    debug.setupvalue(fn, S.clock, os.clock())
    local bloom = 1 - ads * ads * (3 - ads * 2) * 0.5
    debug.setupvalue(fn, S.bloom, math.min(def.spread[1] * bloom, get(fn, S.bloom) + base * 0.22 * bloom))
    u[S.ears].shot(def.db - gear.suppressDb, 0)
end

-- Shot ledger, hit rate and the debug file. Every shot is a ledger entry; the result comes from the server's ShotLand (by seq). A Gun "Hit" ack has no seq: it is only counted.
-- No answer 0.9 s after the packet = miss.
Visual.led = { q = {}, shots = 0, hits = 0, miss = 0, acks = 0 }
Visual.stats = { n = 0, g = {} }
Visual.statAdd = function(rec, hit)
    local S = Visual.stats
    local how = rec.how or "?"
    local kind = (string.find(how, "pen", 1, true) or how == "wall ignored") and "pen" or (string.find(how, "multipoint", 1, true) and "mp" or "clean")
    local keys = {
        "line:" .. kind,
        (rec.speed or 0) > 8 and "moving" or "still",
        rec.dist < 100 and "<100st" or (rec.dist < 250 and "100-250st" or ">=250st"),
        "gun:" .. tostring(rec.gun),
        "aim:" .. tostring(rec.ss or "-"),
        "fix:" .. (string.find(how, "downed", 1, true) and "replica" or "-"),
        "body:" .. (rec.body and string.match(rec.body, "^%a+") or "-"),
    }
    for i = 1, #keys do
        local e = S.g[keys[i]]
        if not e then e = { 0, 0 }; S.g[keys[i]] = e end
        e[1] += 1
        if hit then e[2] += 1 end
    end
    S.n += 1
    if S.n % 15 == 0 then
        local order, parts = { "line:clean", "line:mp", "line:pen", "moving", "still", "<100st", "100-250st", ">=250st" }, {}
        for i = 1, #order do
            local e = S.g[order[i]]
            if e then parts[#parts + 1] = string.format("%s %d%% (%d)", order[i], math.floor(e[2] / e[1] * 100 + 0.5), e[1]) end
        end
        for k, e in S.g do
            local pre = string.sub(k, 1, 4)
            if pre == "clai" or pre == "gun:" or pre == "aim:" or pre == "fix:" or pre == "body" then parts[#parts + 1] = string.format("%s %d%% (%d)", k, math.floor(e[2] / e[1] * 100 + 0.5), e[1]) end
        end
        local L = Visual.led
        local line = string.format("[hush] hit rate | shots %d: %d hit, %d miss, %d pending (server ShotLand) | %d Gun Hit acks | %s", L.shots, L.hits, L.miss, #L.q, L.acks, table.concat(parts, " | "))
        warn(line)
        Visual.dbgW({ ev = "summary", t = Visual.dbgR(os.clock()), text = line })
    end
end
Visual.ledResolve = function(rec, hit, kind, how)
    local L = Visual.led
    if hit then L.hits += 1 else L.miss += 1 end
    Visual.statAdd(rec, hit)
    local dt = os.clock() - rec.t
    if CFG.ShotLog then
        warn(string.format("[hush] shot #%d %s +%.2fs | %s | %s %.0f st | speed %.1f lead %.1f | %s%s%s", rec.seq, hit and "HIT" or ("MISS (" .. how .. ")"), dt, tostring(rec.gun),
            tostring(rec.name), rec.dist, rec.speed or 0, rec.lead or 0, tostring(rec.how), rec.veh and " | seated" or "", kind and (" | landed on " .. kind) or ""))
    end
    Visual.dbgW({ ev = hit and "hit" or "miss", seq = rec.seq, t = Visual.dbgR(os.clock()), dt = Visual.dbgR(dt), kind = kind, how = how, note = rec.note })
end
Visual.ledAdd = function(rec)
    local L = Visual.led
    L.q[#L.q + 1] = rec
    L.shots += 1
end
-- ShotLand (Effect remote) carries our seq and hit.kind (a creature kind = the round ended on a creature, nil = the world). The first ShotLand of a shotgun volley decides.
Visual.ledLand = function(seq, kind)
    local q = Visual.led.q
    for i = 1, #q do
        if q[i].seq == seq then
            Visual.ledResolve(table.remove(q, i), kind ~= nil, kind, "landed on the world")
            return
        end
    end
end
-- Gun "Hit" acks are only counted (they are also written raw to the debug file).
Visual.ledHit = function()
    Visual.led.acks += 1
end
Visual.ledSweep = function(now)
    local q = Visual.led.q
    while q[1] and now - q[1].t > 2 do
        Visual.ledResolve(table.remove(q, 1), false, nil, "no ShotLand in 2 s")
    end
end

-- Debug file hush/shots_<unix>.jsonl in the executor workspace, one JSON per line: session | shot | after (target at +flight) | gun (raw server events) |
-- srv_Shot / srv_ShotLand (arcs.v = launch velocity) | hit / miss | summary. Written in 1 s batches, flushed at unload.
Visual.dbg = { buf = {}, nextAt = 0, ok = false, tried = false, open = {} }
Visual.dbgR = function(n)
    if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then return 0 end
    return math.floor(n * 10000 + 0.5) / 10000
end
Visual.dbgV = function(v)
    if typeof(v) ~= "Vector3" then return nil end
    local r = Visual.dbgR
    return { r(v.X), r(v.Y), r(v.Z) }
end
Visual.dbgAttrs = function(inst)
    local out = {}
    if typeof(inst) ~= "Instance" then return out end
    for k, v in inst:GetAttributes() do
        local t = type(v)
        if t == "number" then out[k] = Visual.dbgR(v)
        elseif t == "string" or t == "boolean" then out[k] = v
        else out[k] = tostring(v) end
    end
    return out
end
Visual.dbgOpen = function()
    local D = Visual.dbg
    if D.ok then return true end
    if D.tried or not CFG.DebugFile then return false end
    D.tried = true
    local ok, err = pcall(function()
        if not isfolder("hush") then makefolder("hush") end
        D.path = "hush/shots_" .. tostring(os.time()) .. ".jsonl"
        writefile(D.path, "")
    end)
    if not ok then
        warn("[hush] debug file: cannot create it (" .. tostring(err) .. ")")
        return false
    end
    D.ok = true
    warn("[hush] debug file: executor workspace/" .. D.path .. " (Potassium: %LOCALAPPDATA%/Potassium/workspace/" .. D.path .. ")")
    local keys = { "Wallbang", "AimSpoof", "AimSpoofHold", "MultiPoint", "MPReach", "MPFirst", "PingPredict", "PredictInterp", "Resolver", "ResolverAccel",
        "ResolverAccelK", "LeadCap", "VisibleCheck", "AimPoints", "SilentAimDistance", "PickRate", "BodyAim", "HelmetAim", "FullAuto" }
    local cfg = {}
    for _, k in keys do
        local v = CFG[k]
        if type(v) == "number" then v = Visual.dbgR(v) elseif type(v) ~= "string" and type(v) ~= "boolean" then v = v ~= nil and tostring(v) or nil end
        cfg[k] = v
    end
    local ex = type(identifyexecutor) == "function" and identifyexecutor() or "?"
    Visual.dbgW({ ev = "session", t = Visual.dbgR(os.clock()), unix = os.time(), place = game.PlaceId, executor = tostring(ex), cfg = cfg,
        flags = { GunPhysics = ReplicatedStorage:GetAttribute("GunPhysics"), GunRecoilPhysics = ReplicatedStorage:GetAttribute("GunRecoilPhysics") },
        gunsCfg = (function() local c = Visual.speedCfg() local g = c and c.Guns return g and { RewindView = g.RewindView, RewindSlack = g.RewindSlack, RewindMax = g.RewindMax, OriginSlack = g.OriginSlack, FocusSpread = g.FocusSpread, SpreadMax = g.SpreadMax } or nil end)(),
        note = "ev=gun lines are every raw server event; a Hit has no sequence, hit/miss attribution is FIFO" })
    return true
end
Visual.dbgW = function(tbl)
    if not CFG.DebugFile or not Visual.dbgOpen() then return end
    local D = Visual.dbg
    local ok, js = pcall(function() return game:GetService("HttpService"):JSONEncode(tbl) end)
    D.buf[#D.buf + 1] = ok and js or ('{"ev":"encode_error","for":"' .. tostring(tbl.ev) .. '"}')
end
Visual.dbgFlush = function(now, force)
    local D = Visual.dbg
    if not D.ok or #D.buf == 0 or (not force and now < D.nextAt) then return end
    D.nextAt = now + 1
    local chunk = table.concat(D.buf, "\n") .. "\n"
    table.clear(D.buf)
    local ok, err = pcall(appendfile, D.path, chunk)
    if not ok then warn("[hush] debug file: write failed (" .. tostring(err) .. ")") ; D.ok = false end
end
-- what the ROUND meets between `from` and `to` (same call as Visual.reach, but with the details)
Visual.reachInfo = function(from, to, model, pen)
    local d = to - from
    local dist = d.Magnitude
    if dist < 0.05 then return { ok = true } end
    local Bal = Visual.btModule()
    if not Bal then return { err = "Ballistics not loadable" } end
    local r = Bal.trace(from, d / dist, model and dist + 2 or dist, pen or 0, Visual.bt.params, vis_list())
    local crossed = 0
    for i = 1, #r.contacts do
        if r.contacts[i].kind == "in" then crossed += 1 end
    end
    local stop = r.stop
    local info = { pen = pen, crossed = crossed, left = Visual.dbgR(r.power) }
    if stop then
        info.stop = stop.part and stop.part:GetFullName() or "?"
        info.mat = stop.material
        info.target = model ~= nil and stop.part ~= nil and stop.part:IsDescendantOf(model)
        info.at = Visual.dbgR((stop.pos - from).Magnitude)
    end
    info.ok = stop == nil or info.target == true
    return info
end
-- Everything known when the packet leaves. `after` samples are scheduled here (Visual.dbgTick).
Visual.dbgShot = function(plan, id, def, f, from, dir, spread, sp0, seq, boss, now)
    local R, V3 = Visual.dbgR, Visual.dbgV
    local model, bone = plan.model, plan.bone
    local char = LP.Character
    local head = plan.head
    local root = model and model:FindFirstChild("HumanoidRootPart")
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    local plr = model and Players:GetPlayerFromCharacter(model)
    local cam = Workspace.CurrentCamera
    local hum0 = char and char:FindFirstChildOfClass("Humanoid")
    local tp = bone and bone.Position
    local rec = { ev = "shot", seq = seq, t = R(now), st = R(Workspace:GetServerTimeNow()), unix = os.time(), dt = R(Visual.dt or 0), gun = id }
    local ok, ping = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
    rec.ping = ok and R(ping) or nil
    rec.def = { range = def.range, pen = def.pen, spread = def.spread, pellets = def.pellets, auto = def.auto, delay = def.delay, velocity = def.velocity, drop = def.drop }
    rec.round = f and { round = f.round, v = R(f.v), tEnd = R(f.tEnd), physics = f.physics } or nil
    rec.me = { head = V3(head and head.Position), from = V3(from), offset = R(plan.offset and plan.offset.Magnitude or 0), cam = V3(cam and cam.CFrame.Position), look = V3(cam and cam.CFrame.LookVector),
        vel = V3(char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.AssemblyLinearVelocity), attrs = Visual.dbgAttrs(char), spoofOn = Visual.aimS.on,
        spoofAge = R(now - (Visual.aimS.sent or -9)), focusAge = Visual.aimS.on and R(now - (Visual.aimS.since or now)) or 0,
        crouchSpoof = { enabled = CFG.CrouchSpoof, sent = Visual.crouchS.on, age = Visual.crouchS.sent and R(now - Visual.crouchS.sent), rejected = Visual.crouchS.blocked == true },
        floor = hum0 and tostring(hum0.FloorMaterial) or nil, moveDir = hum0 and R(hum0.MoveDirection.Magnitude) or nil, ctlAiming = Visual.fire.u and Visual.fire.u[Visual.fire.S.ctl].aiming or nil, ctlCrouch = Visual.fire.u and Visual.fire.u[Visual.fire.S.ctl].crouching or nil }
    rec.claim = { sent = R(spread), game = R(sp0) }
    rec.ab = Visual.crouchAB.tag
    rec.aim = { dir = V3(dir), aim = V3(plan.aim), T = V3(plan.T), raw = V3(plan.raw), how = plan.how, peek = plan.peek ~= nil, bodyAim = plan.bodyAim }
    rec.pred = { lead = R(plan.lead), drop = R(plan.drop), flight = R(plan.flightT), speed = R(plan.speed), vsrc = plan.vsrc, stale = R(plan.stale), lag = R(plan.lag), unc = R(plan.unc), why = plan.why, veh = plan.veh }
    rec.boss = boss
    rec.ss = plan.ss and { part = plan.ss.part, rho = R(plan.ss.rho), R = R(plan.ss.R), pHead = R(plan.ss.pHead), p = R(plan.ss.p) } or nil
    if model then
        local t = { name = model.Name, kind = plr and "player" or (model.Parent and model.Parent.Name or "?"), bone = bone and bone.Name, bonePos = V3(tp), root = V3(root and root.Position),
            rootVel = V3(root and root.AssemblyLinearVelocity), seat = hum and hum.SeatPart and hum.SeatPart.Name or nil, hp = hum and R(hum.Health) or nil, hpMax = hum and R(hum.MaxHealth) or nil,
            floor = hum and tostring(hum.FloorMaterial) or nil, attrs = Visual.dbgAttrs(model), pattrs = plr and Visual.dbgAttrs(plr) or nil, dist = R(tp and (tp - from).Magnitude or 0) }
        if model:GetAttribute("Downed") == true then
            local sd = model:GetAttribute("ShotDown")
            t.dn = { look = V3(root and root.CFrame.LookVector), sdAge = type(sd) == "number" and R(Workspace:GetServerTimeNow() - sd) or nil, fix = bone ~= nil and bone:GetAttribute("HushProxy") == true,
                slumped = model:GetAttribute("Slumped") }
            local px = Visual.dn.proxies[model]
            if px and px.on then t.dn.proxy = { head = V3(px.head.Position), ut = V3(px.ut.Position), lt = V3(px.lt.Position) } end
            -- where the pose put each part (the crawl pose is client-side: compare with root to learn where a lying body really is)
            local parts = {}
            for _, n in { "Head", "UpperTorso", "LowerTorso", "LeftFoot", "LeftHand" } do
                local pt = model:FindFirstChild(n)
                parts[n] = pt and pt:IsA("BasePart") and V3(pt.Position) or nil
            end
            t.parts = parts
        end
        local tr = Resolver.track[model]
        if tr then
            local hist, N = {}, Resolver.N
            for k = 0, math.min(tr.n - 1, 11) do
                local j = (tr.i - k - 1) % N + 1
                hist[#hist + 1] = { R(now - tr.t[j]), R(tr.x[j]), R(tr.y[j]), R(tr.z[j]) }
            end
            t.hist = hist -- newest first: age (s), x, y, z of the replicated root
            t.chgAge = R(now - (tr.chgAt or now))
        end
        rec.tgt = t
    end
    -- what the round meets on the way to the aimed bone
    if tp then
        rec.reach0 = Visual.reachInfo(from, tp, model, 0)
        local pb = Visual.penBudget()
        if pb > 0 then rec.reachPen = Visual.reachInfo(from, tp, model, pb) end
        if plan.peek then rec.headToOrigin = Visual.reachInfo(head.Position, from, nil, 0) end
        -- where our own round is when it has covered the distance to the target's CURRENT bone (= a judge that uses the displayed position)
        local dh = (tp - from):Dot(dir)
        if f and dh > 1 then
            local tt, sag = Resolver.fly(f, from, dir, dh)
            local P = from + dir * dh + sag
            local d = P - tp
            rec.geo = { dist = R(dh), tFlight = R(tt), bulletMinusBoneNow = V3(d), missNow = R(d.Magnitude) }
        end
    end
    Visual.dbgW(rec)
    if CFG.DebugAfter and model and bone then
        local ft = plan.flightT or 0.1
        local o = { seq = seq, t = now, model = model, bone = bone, root = root, hum = hum, k = 1,
            due = { ft, ft + 0.1, ft + 0.2, ft + 0.35, ft + 0.6 }, out = {} }
        local D = Visual.dbg
        if #D.open >= 24 then table.remove(D.open, 1) end
        D.open[#D.open + 1] = o
    end
end
Visual.dbgTick = function(now)
    local D = Visual.dbg
    for i = #D.open, 1, -1 do
        local o = D.open[i]
        while o.due[o.k] and now >= o.t + o.due[o.k] do
            local R, V3 = Visual.dbgR, Visual.dbgV
            local alive = o.bone.Parent ~= nil
            o.out[#o.out + 1] = { dt = R(now - o.t), bone = alive and V3(o.bone.Position) or nil, root = o.root and o.root.Parent and V3(o.root.Position) or nil,
                rootVel = o.root and o.root.Parent and V3(o.root.AssemblyLinearVelocity) or nil, hp = o.hum and o.hum.Parent and R(o.hum.Health) or nil }
            o.k += 1
        end
        if not o.due[o.k] then
            Visual.dbgW({ ev = "after", seq = o.seq, t = Visual.dbgR(o.t), samples = o.out })
            table.remove(D.open, i)
        end
    end
    Visual.dbgFlush(now, false)
end

-- Upvalue slots of Guns.shoot are located by ROLE (function name / table shape), never by fixed index (indices move with every game edit).
-- The recoil cells + clock + bloom are the numeric run before Ears, in code order (heat, kick, climb, side, sideSlow, shotClock, bloom).
Visual.fireSlots = function(u)
    local S = {}
    local function find(pred)
        for i = 1, 48 do
            local v = u[i]
            if v ~= nil and pred(v) then return i end
        end
    end
    local function fn(name) return function(v) return type(v) == "function" and debug.info(v, "n") == name end end
    local function tbl(...)
        local keys = { ... }
        return function(v)
            if type(v) ~= "table" then return false end
            for _, k in keys do if v[k] == nil then return false end end
            return true
        end
    end
    local roles = {
        guns = tbl("Defs", "rideOf"), aimIgnore = fn("aimIgnoreList"), ignore = fn("ignoreList"),
        params = function(v) return typeof(v) == "RaycastParams" end, mother = tbl("rayHit", "setMode"),
        gun = function(v) return typeof(v) == "Instance" and v.Name == "Gun" end,
        impact = fn("impact"), spread = fn("currentSpread"), ballistics = tbl("arcTime", "trace"),
        state = tbl("pickSlot", "heldId"), muzzle = fn("muzzleOf"), wobble = fn("wobble"), flash = fn("flash"),
        sound = fn("shotSound"), gear = tbl("stats", "slotOf"), ctl = tbl("addStamina", "isWinded"),
        skills = tbl("has", "levelCost"), cfg = tbl("HeatMax", "HeatPerShot"), ears = tbl("shot", "level"),
    }
    for role, pred in roles do
        S[role] = find(pred)
        if not S[role] then return nil, "shoot upvalue role '" .. role .. "' not found" end
    end
    S.bloom, S.clock = S.ears - 1, S.ears - 2
    local cells, idx = {}, S.clock - 1
    while #cells < 5 and idx > S.skills do
        if type(u[idx]) == "number" then cells[#cells + 1] = idx end
        idx -= 1
    end
    if #cells < 5 then return nil, "shoot recoil cells not found" end
    S.sideSlow, S.side, S.climb, S.kick, S.heat = cells[1], cells[2], cells[3], cells[4], cells[5]
    S.suppr, S.gearCache, S.gearIn, S.ads = S.wobble + 1, S.sound + 1, S.gear + 1, S.gear + 2
    S.look = S.params + 1 -- u108: the aim vector shoot() reads; nil while no gun is out, so it is type-checked at every write
    for _, k in { "bloom", "clock", "ads", "heat", "kick", "climb", "side", "sideSlow" } do
        if type(u[S[k]]) ~= "number" then return nil, "shoot cell '" .. k .. "' is not a number (slot " .. S[k] .. ")" end
    end
    return S
end
-- AimSpoof: the server learns ADS from Gun "Aim"(pitch, ads, yaw), sent only on change, and publishes the Aiming attribute: we tell it we are scoped for the shot
-- and take it back 0.35 s after the last one.
-- Server-only stance uses the live HushCrouch callback's shared sequence cell, without invoking its local movement/slide path.
Visual.crouchS = { on = false, nextAt = 0, bindAt = 0 }
Visual.crouchInstall = function(client)
    local S = Visual.crouchS
    if S.registry then return true end
    if os.clock() < S.bindAt then return false end
    S.bindAt = os.clock() + 1
    local actions = require(client.Actions)
    for _, v in debug.getupvalues(actions.bound) do
        if type(v) == "table" and type(v.HushCrouch) == "function" then S.registry = v; break end
    end
    if not S.registry then return false end
    S.remote = ReplicatedStorage.Remotes:FindFirstChild("Stance")
    if not (S.remote and S.remote:IsA("RemoteEvent")) then S.registry = nil; return false end
    bind(S.remote.OnClientEvent:Connect(function(on, seq)
        if on == false and S.on and seq == S.seq then
            S.on, S.blocked = false, true
            warn("[hush] CrouchSpoof: stance rejected; paused until toggle-off or respawn")
        end
    end))
    return true
end
Visual.crouchSend = function(on)
    local S, ctl = Visual.crouchS, Visual.base.controls
    local fn = S.registry and S.registry.HushCrouch
    if not fn then return false end
    if S.fn ~= fn then
        local slot, count, sameCtl, sameRemotes = nil, 0, false, false
        for i, v in debug.getupvalues(fn) do
            if v == ctl then sameCtl = true end
            if v == ReplicatedStorage.Remotes then sameRemotes = true end
            if type(v) == "number" then slot, count = i, count + 1 end
        end
        if not (sameCtl and sameRemotes and count == 1) then
            S.blocked = true
            warn("[hush] CrouchSpoof: HushCrouch layout changed; no stance sent")
            return false
        end
        S.fn, S.slot = fn, slot
    end
    local seq = debug.getupvalue(fn, S.slot)
    if type(seq) ~= "number" or seq < 0 or seq % 1 ~= 0 then S.blocked = true; return false end
    seq += 1
    debug.setupvalue(fn, S.slot, seq)
    S.seq, S.sent, S.on = seq, os.clock(), on
    S.remote:FireServer(on, seq)
    return true
end
Visual.crouchRelease = function()
    local S, ctl = Visual.crouchS, Visual.base.controls
    if S.on and S.char == LP.Character and ctl and S.fn and debug.getupvalue(S.fn, S.slot) == S.seq then
        Visual.crouchSend(ctl.crouching == true)
    end
    S.on = false
end
Visual.crouchStep = function(now)
    local S, b = Visual.crouchS, Visual.base
    if not (running and CFG.CrouchSpoof) then
        if S.on then Visual.crouchRelease() end
        S.blocked = false
        return
    end
    if now < S.nextAt then return end
    S.nextAt = now + 0.1
    local char, ctl = LP.Character, b.controls
    if S.char ~= char then S.on, S.blocked, S.char = false, false, char end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local want = hooked and held.firearm and hum and hum.Health > 0 and not hum.SeatPart
        and hum.FloorMaterial ~= Enum.Material.Air and ctl and not (ctl.move or ctl.stunned or ctl.held or ctl.vaulting or ctl.noCrouch)
        and char:GetAttribute("Downed") ~= true and not Visual.knockedOut(char)
    if want and not CFG.CrouchSpoofMoving then
        local root = hum.RootPart
        local v = root and root.AssemblyLinearVelocity
        want = hum.MoveDirection.Magnitude <= 0.1 and v and v.X * v.X + v.Z * v.Z < 1
    end
    if not want or S.blocked then
        if S.on then Visual.crouchRelease() end
        return
    end
    if not b.client or not Visual.crouchInstall(b.client) then return end
    if S.on and S.fn and debug.getupvalue(S.fn, S.slot) ~= S.seq then S.on = false end
    if ctl.crouching then return end -- the player's own stance owns its normal replication
    if (not S.on or char:GetAttribute("Crouch") ~= true) and now - (S.sent or -1) >= 0.35 then
        Visual.crouchSend(true)
    end
end
Visual.crouchAB = { block = 0, idx = 0, first = true }
Visual.crouchABFlip = function()
    local A = Visual.crouchAB
    if A.block % 2 == 1 then A.first = math.random() < 0.5 end -- each pair of blocks is on/off in random order
    CFG.CrouchSpoof = (A.block % 2 == 1) == A.first
    if Life.uiState then Life.uiState("CrouchSpoof") end
end
-- called once per own shot: tags the record and swaps the state after the last shot of a block
Visual.crouchABShot = function()
    local A = Visual.crouchAB
    if not (running and CFG.CrouchAB) then A.block, A.idx = 0, 0; return nil end
    if A.block == 0 then A.block, A.idx = 1, 0; Visual.crouchABFlip() end
    A.idx += 1
    local tag = { block = A.block, idx = A.idx, want = CFG.CrouchSpoof }
    if A.idx >= CFG.CrouchABBlock then A.block, A.idx = A.block + 1, 0; Visual.crouchABFlip() end
    return tag
end
Visual.aimS = { on = false, at = 0 }
-- The spoof is re-sent before every shot: the game re-sends its own Aim(false) when its pitch moves.
Visual.alwaysAimOn = function()
    return CFG.AlwaysAim and held.id ~= nil and CFG.AlwaysAimGuns[held.id] == true
end
Visual.aimSpoof = function(dir, hold)
    if not (CFG.AimSpoof or Visual.alwaysAimOn()) then return end
    local b, A = Visual.fire, Visual.aimS
    local now = os.clock()
    -- Spoof whenever the server's own Aiming attribute is not true, whatever ctl.aiming says: the game sends Aim only on change, so our take-back can leave the server at hip.
    local char = LP.Character
    if char and char:GetAttribute("Aiming") == true then
        A.on = false -- the server already has us scoped (real ADS or an earlier spoof that arrived)
        return
    end
    A.at = now
    if not A.on or now - (A.sent or 0) > (hold and 0.3 or 0.1) then
        if not A.on then A.since = now end
        A.on, A.sent = true, now
        b.u[b.S.gun]:FireServer("Aim", math.asin(math.clamp(dir.Y, -1, 1)), true, 0)
    end
end
-- every frame: keep the server scoped while an AlwaysAim gun is held; when it is put away, let aimSpoofTick hand the real state back
Visual.alwaysAimStep = function()
    local A = Visual.aimS
    if running and hooked and held.firearm and Visual.fire.u and Visual.alwaysAimOn() then
        A.always = true
        if os.clock() - (A.sent or 0) >= 0.15 then Visual.aimSpoof(Cam.CFrame.LookVector, true) end -- the game re-sends Aim(false) when its pitch moves: at most 6 corrections/s
    elseif A.always then
        A.always, A.on, A.at = false, true, -math.huge
    end
end
Visual.aimSpoofTick = function(now)
    local A = Visual.aimS
    if not A.on or now - A.at < 0.35 then return end
    A.on = false
    local b, cam = Visual.fire, workspace.CurrentCamera
    -- hand the real state back: false only when the player is not scoped himself, otherwise re-assert his ADS (the game would not re-send it)
    local real = b.u and b.u[b.S.ctl].aiming == true
    if b.u and cam then b.u[b.S.gun]:FireServer("Aim", math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)), real, 0) end
end
-- ShootEverywhere: hook of Guns' local canFire() (one filtergc hit, fail closed). ctl = the Controls table taken from shoot's upvalues.
Visual.everywhere = {}
Visual.everywhereInstall = function(ctl)
    local ev = Visual.everywhere
    local target, why = Visual.heldFn("onFire", nil, "canFire") -- held by onFire; searching canFire itself finds our own stale clones
    if not target then
        warn("[hush] ShootEverywhere off: " .. tostring(why))
        return
    end
    ev.target = target
    ev.orig = hookfunction(target, function(...)
        if not (running and CFG.ShootEverywhere) then return ev.orig(...) end
        local sp, mv, va, ge, st = ctl.sprinting, ctl.move, ctl.vaulting, ctl.gesturing, ctl.stunned
        ctl.sprinting, ctl.move, ctl.vaulting, ctl.gesturing, ctl.stunned = false, nil, false, false, false
        local ok, res = pcall(ev.orig, ...) -- the masked fields MUST be put back even if canFire throws
        ctl.sprinting, ctl.move, ctl.vaulting, ctl.gesturing, ctl.stunned = sp, mv, va, ge, st
        if not ok then error(res, 0) end
        return res
    end)
    warn("[hush] ShootEverywhere: canFire hooked")
end
local function install(shoot)
    local b = Visual.fire
    local u = debug.getupvalues(shoot)
    local S, why = Visual.fireSlots(u)
    if not S then
        Install.why = why
        return false
    end
    b.u, b.S = u, S
    b.rounds = require(getfenv(shoot).script.Parent.Rounds)
    b.carLean = require(getfenv(shoot).script.Parent.CarLean)
    Visual.everywhereInstall(u[S.ctl])
    oldShoot = hookfunction(shoot, function(id, hand, cut)
        local def = u[S.guns].Defs[id]
        -- The game still owns input, delay, ammo, reload and sword cuts. Never auto-fire here.
        if not running or not def or def.melee or def.gadget then return oldShoot(id, hand, cut) end
        local plan = silent_plan()
        if not plan then
            local cam = workspace.CurrentCamera
            if cam then Visual.aimSpoof(cam.CFrame.LookVector) end
            return oldShoot(id, hand, cut)
        end
        Visual.aimSpoof(plan.dir)
        saTgt = plan
        return Visual.fireShot(plan, id, hand)
    end)
    Life.shootTarget = shoot
    hooked = true
    warn("[hush] silent: direct shoot adapter, scalar spread + Rounds; no metahook")
    return true
end

-- A function the game's code holds (upvalue of an unhooked holder) is the live closure; a signature search also matches the stale clone hookfunction leaves behind after a reload.
Visual.heldFn = function(holderName, holderConsts, fnName)
    local holders = filtergc("function", {Name = holderName, Constants = holderConsts, IgnoreExecutor = true})
    local found
    for _, h in holders do
        for _, v in debug.getupvalues(h) do
            if type(v) == "function" and debug.info(v, "n") == fnName then
                if found and found ~= v then return nil, fnName .. " is held as two different closures" end
                found = v
            end
        end
    end
    if not found then return nil, holderName .. " (" .. #holders .. " found) holds no upvalue " .. fnName end
    return found
end
local function try_install()
    if hooked then return true end
    local shoot, why = Visual.heldFn("tryFire", {"RopeOut", "ChargesOut"}, "shoot")
    if not shoot then
        Install.why = why
        return false
    end
    return install(shoot)
end

local function upv(fn, i)
    if type(debug.getupvalue) ~= "function" or not fn then
        return nil
    end
    local ok, v = pcall(debug.getupvalue, fn, i)
    if ok then
        return v
    end
    return nil
end

local function find_bind(fn)
    for i = 1, 12 do
        local v = upv(fn, i)
        if type(v) == "table" and type(v.aim) == "function" and v.remote then
            return v
        end
    end
    return nil
end

local ka_lead -- defined with the hammer helpers below
local function install_aim(bindTable)
    if not bindTable or bindTable.__hushAim then
        return bindTable ~= nil
    end
    local oldAim = bindTable.aim
    local mother
    for _, value in debug.getupvalues(oldAim) do
        if type(value) == "table" and type(value.rayHit) == "function" then mother = value; break end
    end
    if not mother then return false end
    Visual.sledgeBind, Visual.sledgeOriginalAim = bindTable, oldAim
    Visual.sledgeOriginalSwing = bindTable.swing
    bindTable.swing = function(heavy, power)
        if kaAim and Visual.kaAimResult then
            local sent = Visual.kaSent
            sent.fired, sent.at = true, os.clock()
            -- release has ALREADY executed FireServer before invoking this callback.
            Visual.kaRecovery = (heavy and (0.16 + 0.75) or (0.2 + 0.45)) + 0.09
            if CFG.ShotLog then warn(string.format("[hush] KA Fire branch: %s | power %.2f | next %.2fs",
                heavy and "heavy" or "quick", power, Visual.kaRecovery)) end
        end
        return Visual.sledgeOriginalSwing(heavy, power)
    end
    bindTable.aim = function()
        local force = kaAim
        if not force then return oldAim() end
        local head = LP.Character and LP.Character:FindFirstChild("Head")
        if not (head and force.bone and force.bone.Parent and alive_model(force.model)) then return nil end
        local pos, lead = ka_lead(force.bone)
        local from = head.Position
        -- the client strips a point past Reach: pull the led point back onto the Reach sphere instead of dropping the lead
        local pm = (pos - from).Magnitude
        if pm > SLEDGE_REACH - 0.05 then pos = from + (pos - from) * ((SLEDGE_REACH - 0.05) / pm) end
        local delta = pos - from
        local dist = delta.Magnitude
        if dist < 0.8 or dist > SLEDGE_REACH then return nil end
        if not CFG.KaWall and not world_clear(from, pos, force.model) then return nil end
        local dir = delta.Unit
        local sent = Visual.kaSent or {}
        sent.at, sent.model, sent.lead, sent.fired = os.clock(), force.model, lead, false
        Visual.kaSent = sent
        -- Third aim result is a Mother-only distance, not a generic victim id.
        -- Recompute on the NEW direction instead of reusing oldAim's camera-ray value.
        local bossDistance = mother.rayHit(head.Position, dir, SLEDGE_REACH + 1)
        Visual.kaAimResult = true
        if CFG.ShotLog then
            local root = LP.Character:FindFirstChild("HumanoidRootPart")
            warn(string.format("[hush] KA aim -> Fire: target %s | dist %.2f | lead %.2f | dir %.2f %.2f %.2f | rootDot %.2f | mother %s",
                force.model.Name, dist, lead, dir.X, dir.Y, dir.Z, root and root.CFrame.LookVector:Dot(dir) or -1, tostring(bossDistance)))
        end
        return head.Position, dir, bossDistance, pos
    end
    bindTable.__hushAim = true
    return true
end

local function hook_sledge()
    local client = LP:FindFirstChild("PlayerScripts")
    client = client and client:FindFirstChild("Client")
    local inst = client and client:FindFirstChild("Sledge")
    if not inst or sledgeMod then return end
    local ok, mod = pcall(require, inst)
    if not ok or type(mod) ~= "table" or type(mod.release) ~= "function" then return end
    sledgeMod, sledgeRelease = mod, mod.release
    aimWrapped = install_aim(find_bind(sledgeRelease))
    warn("[hush] sledge aim bound: " .. tostring(aimWrapped))
end

-- Sledge.bind runs when Guns loads. Until then u3 is nil and the aim table is not visible.
local function retry_aim_wrap()
    if aimWrapped or not sledgeRelease then
        return
    end
    aimWrapped = install_aim(find_bind(sledgeRelease))
    if aimWrapped then
        warn("[hush] sledge aim wrapped")
    end
end

-- Cache Drawing writes like the Soccer pen: unchanged visibility/style/text never
-- crosses the executor bridge. All holders below receive the proxy, not the raw object.
local drawMeta = {}
drawMeta.stats = { created = 0, removed = 0, live = 0, peak = 0 }
drawMeta.remove = function(self)
    if self._dead then return end
    self._raw:Remove()
    rawset(self, "_dead", true)
    table.clear(self._cache)
    local stats = drawMeta.stats
    stats.removed += 1
    stats.live -= 1
end
drawMeta.__index = function(t, k)
    if k == "Remove" then return drawMeta.remove end
    local v = t._cache[k]
    if v ~= nil then return v end
    return t._raw[k]
end
drawMeta.__newindex = function(t, k, v)
    local c = t._cache
    if c[k] ~= v then
        t._raw[k] = v
        c[k] = v
        if k == "From" then c.fx = nil elseif k == "To" then c.tx = nil
        elseif k == "Position" then c.px = nil elseif k == "Size" then c.sw = nil end
    end
end
local function new_draw(kind)
    local raw = Drawing.new(kind)
    local stats = drawMeta.stats
    stats.created += 1
    stats.live += 1
    stats.peak = math.max(stats.peak, stats.live)
    return setmetatable({ _raw = raw, _cache = {}, _dead = false }, drawMeta)
end

local function new_line(z, thick)
    local line = new_draw("Line")
    line.Thickness = thick or 1
    line.Visible = false
    line.Transparency = 1
    line.ZIndex = z or 20
    return line
end

-- put_* read and write the proxy's own cache tables (no __index/__newindex per property); a Vector2 is built only when a coordinate changed. Transparency 1 is opaque on this executor.
local function put_line(line, col, thick, alpha, z, ax, ay, bx, by)
    local c, r = line._cache, line._raw
    if c.Visible ~= true then r.Visible = true; c.Visible = true end
    if c.Color ~= col then r.Color = col; c.Color = col end
    if c.Thickness ~= thick then r.Thickness = thick; c.Thickness = thick end
    if c.Transparency ~= alpha then r.Transparency = alpha; c.Transparency = alpha end
    if c.ZIndex ~= z then r.ZIndex = z; c.ZIndex = z end
    if c.fx ~= ax or c.fy ~= ay then r.From = Vector2.new(ax, ay); c.fx, c.fy = ax, ay end
    if c.tx ~= bx or c.ty ~= by then r.To = Vector2.new(bx, by); c.tx, c.ty = bx, by end
end
local function put_text(t, text, col, x, y, alpha)
    local c, r = t._cache, t._raw
    alpha = alpha or 1
    x, y = math.floor(x + 0.5), math.floor(y + 0.5) -- whole pixels: crisper text and far fewer position writes
    if c.Visible ~= true then r.Visible = true; c.Visible = true end
    if c.Transparency ~= alpha then r.Transparency = alpha; c.Transparency = alpha end
    if c.Text ~= text then r.Text = text; c.Text = text end
    if c.Color ~= col then r.Color = col; c.Color = col end
    if c.px ~= x or c.py ~= y then r.Position = Vector2.new(x, y); c.px, c.py = x, y end
end
local function put_rect(sq, col, x, y, w, h, alpha)
    local c, r = sq._cache, sq._raw
    alpha = alpha or 1
    if c.Transparency ~= alpha then r.Transparency = alpha; c.Transparency = alpha end
    if c.Visible ~= true then r.Visible = true; c.Visible = true end
    if c.Color ~= col then r.Color = col; c.Color = col end
    if c.px ~= x or c.py ~= y then r.Position = Vector2.new(x, y); c.px, c.py = x, y end
    if c.sw ~= w or c.sh ~= h then r.Size = Vector2.new(w, h); c.sw, c.sh = w, h end
end

-- Soccer GLOW: two strokes. A dark bed under a core of the role colour; contrast, not a halo.
-- layers 1 = core only (NPC, corpses). `width` is the core weight; the bed is always 2.4 wider.
local function stroke3(lines, i, x1, y1, x2, y2, color, width, layers, alpha, stride)
    width = (width and width > 0) and width or 1.5
    layers = layers or (CFG.Quality >= 1 and 2 or 1)
    local ink, core = lines[i + stride], lines[i]
    local halo = lines[i + stride * 2]
    if layers >= 3 and halo then
        put_line(halo, color, width + 5, (alpha or 1) * 0.18, 17, x1, y1, x2, y2)
    elseif halo then halo.Visible = false end
    if layers >= 2 and ink then
        put_line(ink, COL_INK, width + 2.4, 0.72 * (alpha or 1), 18, x1, y1, x2, y2)
    elseif ink then
        ink.Visible = false
    end
    if core then
        put_line(core, color, width, alpha or 1, 21, x1, y1, x2, y2)
    end
end

local function make_text(z)
    local t = new_draw("Text")
    t.Size = 14
    t.Font = Visual.fxFont()
    t.Center = true
    t.Outline = true
    t.Visible = false
    t.ZIndex = z
    return t
end

local function new_esp()
    local o = { lines = {}, hot = {}, states = {}, slotTxt = {}, slotIds = {}, slotCol = {}, slotN = 0 }
    for i = 1, 48 do -- 16 core + 16 ink + 16 glow strokes (rounded corners; straight use 8 of each)
        o.lines[i] = new_line(20, 1.6)
    end
    o.name = make_text(22)
    o.dist = make_text(23)
    o.weapon = make_text(23)
    o.weapon.Color = COL_WEP
    for i = 1, 4 do -- 3 hotbar slots + armor
        o.hot[i] = make_text(23)
        o.hot[i].Color = COL_DIST
        o.hot[i].Size = 13
    end
    o.hpOutline = new_draw("Square")
    o.hpOutline.Filled = false
    o.hpOutline.Thickness = 1
    o.hpOutline.Color = Color3.fromRGB(8, 8, 8)
    o.hpOutline.Visible = false
    o.hpOutline.ZIndex = 17
    o.hpBg = new_draw("Square")
    o.hpBg.Filled = true
    o.hpBg.Color = Color3.fromRGB(22, 22, 22)
    o.hpBg.Visible = false
    o.hpBg.ZIndex = 18
    o.hpTail = new_draw("Square")
    o.hpTail.Filled = true
    o.hpTail.Visible = false
    o.hpTail.ZIndex = 19
    o.hpS = {}
    for i = 1, 16 do -- fixed-position gradient, red bottom -> amber -> green top
        local sq = new_draw("Square")
        sq.Filled, sq.Visible, sq.ZIndex = true, false, 19
        o.hpS[i] = sq
    end
    o.hidden = true
    return o
end

local function hide_esp(o)
    if o.hidden then
        return
    end
    o.hidden = true
    for i = 1, #o.lines do
        o.lines[i].Visible = false
    end
    o.name.Visible = false
    o.dist.Visible = false
    o.weapon.Visible = false
    for i = 1, #o.hot do
        o.hot[i].Visible = false
    end
    o.hpOutline.Visible = false
    o.hpBg.Visible = false
    o.hpTail.Visible = false
    for i = 1, #o.hpS do o.hpS[i].Visible = false end
end

local function free_esp(o)
    hide_esp(o)
    for i = 1, #o.lines do
        o.lines[i]:Remove()
    end
    o.name:Remove()
    o.dist:Remove()
    o.weapon:Remove()
    for i = 1, #o.hot do
        o.hot[i]:Remove()
    end
    o.hpOutline:Remove()
    o.hpBg:Remove()
    o.hpTail:Remove()
    for i = 1, #o.hpS do o.hpS[i]:Remove() end
end

-- High-water pool: retain/reuse the largest simultaneous demand, not every encountered model.
-- Normal release NEVER destroys a Drawing. Only explicit session unload disposes the pool.
local espPool = { free = {}, inUse = 0, created = 0 }
espPool.acquire = function()
    local o = table.remove(espPool.free)
    if not o then o = new_esp(); espPool.created += 1 end
    o.usedAt = os.clock()
    espPool.inUse += 1
    return o
end
espPool.release = function(model)
    local o = espByModel[model]
    if not o then return end
    espByModel[model] = nil
    hide_esp(o)
    o.hrp, o.head, o.usedAt = nil, nil, nil
    o.infoAt, o.stateAt, o.di = nil, nil, nil
    o.hpAt, o.hpHum, o.hpFraction = nil, nil, nil
    o.weaponId, o.aiming, o.running, o.shooting = nil, nil, nil, nil
    o.itemDefs = nil
    o.shotBase, o.shotColor, o.hotShown = nil, nil, 0
    o.tailFrac, o.dropAt, o.hpPrev, o.tailT, o.shownAt = nil, nil, nil, nil, nil
    o.wstr, o.labelStr, o.distStr, o.slotN, o.wCol, o.weaponId = nil, nil, nil, 0, nil, nil
    o.armorKey, o.armorStr, o.armorCol = nil, nil, nil
    o.role, o.lblKey, o.lblKind, o.lblRole = nil, nil, nil, nil
    table.clear(o.states)
    table.clear(o.slotTxt)
    table.clear(o.slotIds)
    table.clear(o.slotCol)
    espPool.inUse -= 1
    espPool.free[#espPool.free + 1] = o
end
espPool.sweep = function(seen, now)
    for model, o in espByModel do
        if not seen[model] or not model.Parent or now - o.usedAt >= 2 then espPool.release(model) end
    end
end
espPool.destroy = function()
    for model in espByModel do espPool.release(model) end
    for i = #espPool.free, 1, -1 do free_esp(espPool.free[i]); espPool.free[i] = nil end
end

local CORNERS = { { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } }
-- Line pool layout: strokes 1..S core, S+1..2S ink, 2S+1..3S glow (S = #lines / 3). Straight corners use 8
-- strokes, rounded corners use 16 (arm, two-segment quarter arc, arm per corner).
local function draw_corner(o, minX, minY, maxX, maxY, color, width, longTop, layers, alpha, round)
    -- half-pixel grid: a sub-pixel drift is invisible, but each changed endpoint costs a Vector2 and a bridge write
    minX, minY, maxX, maxY = math.floor(minX * 2 + 0.5) * 0.5, math.floor(minY * 2 + 0.5) * 0.5, math.floor(maxX * 2 + 0.5) * 0.5, math.floor(maxY * 2 + 0.5) * 0.5
    local w, h = maxX - minX, maxY - minY
    -- Far boxes (< 26 px tall) get 30% arms so they still read as corners, not as a closed rectangle.
    local frac = longTop and 0.46 or (h < 26 and 0.3 or 0.24)
    local cx, cy = math.min(w * frac, w * 0.5), math.min(h * frac, h * 0.5)
    cx, cy = math.max(cx, math.min(2.5, w * 0.5)), math.max(cy, math.min(2.5, h * 0.5))
    local lines = o.lines
    local st = #lines // 3
    local rm = round == true and st >= 16
    if o.rm ~= rm then
        o.rm = rm
        for i = 9, st do
            lines[i].Visible = false
            lines[i + st].Visible = false
            lines[i + st * 2].Visible = false
        end
    end
    if rm then
        local r = math.clamp(math.min(w, h) * 0.14, 3, 10)
        cx, cy = math.max(cx, r + 3), math.max(cy, r + 3)
        local k = 0.2929 * r
        for c = 1, 4 do
            local d = CORNERS[c]
            local x0, y0, sx, sy = d[1] == 0 and minX or maxX, d[2] == 0 and minY or maxY, d[3], d[4]
            local i = (c - 1) * 4
            stroke3(lines, i + 1, x0 + sx * r, y0, x0 + sx * cx, y0, color, width, layers, alpha, st)
            stroke3(lines, i + 2, x0 + sx * r, y0, x0 + sx * k, y0 + sy * k, color, width, layers, alpha, st)
            stroke3(lines, i + 3, x0 + sx * k, y0 + sy * k, x0, y0 + sy * r, color, width, layers, alpha, st)
            stroke3(lines, i + 4, x0, y0 + sy * r, x0, y0 + sy * cy, color, width, layers, alpha, st)
        end
        return
    end
    stroke3(lines, 1, minX, minY, minX + cx, minY, color, width, layers, alpha, st)
    stroke3(lines, 2, minX, minY, minX, minY + cy, color, width, layers, alpha, st)
    stroke3(lines, 3, maxX - cx, minY, maxX, minY, color, width, layers, alpha, st)
    stroke3(lines, 4, maxX, minY, maxX, minY + cy, color, width, layers, alpha, st)
    stroke3(lines, 5, minX, maxY - cy, minX, maxY, color, width, layers, alpha, st)
    stroke3(lines, 6, minX, maxY, minX + cx, maxY, color, width, layers, alpha, st)
    stroke3(lines, 7, maxX, maxY - cy, maxX, maxY, color, width, layers, alpha, st)
    stroke3(lines, 8, maxX - cx, maxY, maxX, maxY, color, width, layers, alpha, st)
end

local function player_states(model, plr, o)
    local now = os.clock()
    if o.stateAt and now - o.stateAt < (CFG.EspStateRate or 0.2) then
        return o.states
    end
    local out = o.states
    table.clear(out)
    local downed = model:GetAttribute("Downed") == true or Visual.knockedOut(model)
    local crouch = model:GetAttribute("Crouch") == true
    if downed then
        out[#out + 1] = "Lay"
    end
    if model:GetAttribute("Ragdoll") == true then
        out[#out + 1] = "Ragdoll"
    end
    if crouch then
        out[#out + 1] = "Crouch"
    end
    if model:GetAttribute("Aiming") == true then
        out[#out + 1] = "Aim"
    end
    if type(model:GetAttribute("SledgeCharge")) == "number" then
        out[#out + 1] = "Charge"
    end
    if type(model:GetAttribute("DyingAt")) == "number" then
        out[#out + 1] = "Dying"
    end
    if model:GetAttribute("FlashlightOn") == true then
        out[#out + 1] = "Light"
    end
    local hrp = o.hrp
    if not (hrp and hrp.Parent) then hrp = model:FindFirstChild("HumanoidRootPart") end
    local vel = hrp and hrp.AssemblyLinearVelocity
    if typeof(vel) == "Vector3" and not crouch and not downed then
        local horiz = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
        if horiz > 15.5 then
            out[#out + 1] = "Run"
        elseif horiz > 2 then
            out[#out + 1] = "Walk"
        end
    end
    local hum = hum_of(model)
    local seat = hum and hum.SeatPart
    if seat then
        if seat.Name == "DriverSeat" then
            out[#out + 1] = "Drive"
        else
            out[#out + 1] = "Sit"
        end
    end
    local shotTime, reloadTime = shotAt[model], reloadAt[model]
    local playerShot, playerReload = plr and shotAt[plr], plr and reloadAt[plr]
    if playerShot and (not shotTime or playerShot > shotTime) then shotTime = playerShot end
    if playerReload and (not reloadTime or playerReload > reloadTime) then reloadTime = playerReload end
    if shotTime and now - shotTime < 0.55 then
        out[#out + 1] = "Shoot"
    end
    if reloadTime and now - reloadTime < 0.8 then
        out[#out + 1] = "Reload"
    end
    o.aiming, o.running, o.shooting = false, false, false
    for i = 1, #out do
        local state = out[i]
        if state == "Aim" then o.aiming = true
        elseif state == "Run" then o.running = true
        elseif state == "Shoot" then o.shooting = true end
    end
    o.stateAt = now
    return out
end

local SLOT_ATTRS = { "SlotMain", "SlotSecondary", "SlotMelee" }
Visual.ARMOR_RARITY = { light = "Uncommon", medium = "Rare", heavy = "Epic" }
Visual.ARMOR_ICON = { light = "ArmorUncommon", medium = "ArmorRare", heavy = "ArmorEpic" } -- colour baked from CFG.WeaponRarity by make_icons.py
-- Other players replicate only the Character attributes Gun, SlotMain/SlotSecondary/SlotMelee (+ Armor). Colour = Items.Defs[id].rarity -> CFG.WeaponRarity.
local function item_color(id)
    local module = items()
    local def = module and type(id) == "string" and module.Defs[id]
    local cls = def and CFG.WeaponRarity[def.rarity] or CFG.WeaponRarity.Common
    return cls.on and cls.color or nil
end
Visual.hpGrad = {}
for i = 1, 16 do
    local t = (i - 0.5) / 16
    Visual.hpGrad[i] = t < 0.5 and PAL.hpLow:Lerp(Color3.fromRGB(255, 205, 60), t * 2) or Color3.fromRGB(255, 205, 60):Lerp(PAL.hpHigh, (t - 0.5) * 2)
end
local ESP_COL = { line = Color3.fromRGB(8, 8, 8), bg = Color3.fromRGB(22, 22, 22) }

-- Strings and attribute reads that do not change per frame are rebuilt 4 times a second.
local function esp_info(o, model, plr, now, role)
    o.infoAt = now
    local module = items()
    local defs = module and module.Defs
    local namesChanged = o.itemDefs ~= defs
    o.itemDefs = defs
    local heldId = model:GetAttribute("Gun")
    if namesChanged or o.weaponId ~= heldId then
        o.weaponId = heldId
        local wname = item_name(heldId)
        o.wstr = wname and not CFG.EspHideIds[heldId] and ("[" .. wname .. "]") or nil
    end
    -- colours are re-read every info poll so a live CFG.WeaponRarity edit applies at once
    o.wCol = o.wstr and item_color(heldId) or nil
    local n = 0
    for i = 1, 3 do
        local id = model:GetAttribute(SLOT_ATTRS[i])
        if type(id) == "string" and id ~= "" and id ~= heldId and not CFG.EspHideIds[id] then
            n += 1
            if namesChanged or o.slotIds[n] ~= id then o.slotIds[n], o.slotTxt[n] = id, item_name(id) end
            o.slotCol[n] = item_color(id)
        end
    end
    for i = n + 1, o.slotN do o.slotIds[i], o.slotTxt[i], o.slotCol[i] = nil, nil, nil end
    o.slotN = n
    -- Body armor replicates as Character attribute Armor = light|medium|heavy (Footsteps reads it on
    -- every char). Shared Armor.Weights rarity: light Uncommon, medium Rare, heavy Epic.
    local armor = model:GetAttribute("Armor")
    if type(armor) == "string" and armor ~= "" then
        -- Character attributes ArmorLeft / ArmorMax sit next to Armor
        local left, mx = model:GetAttribute("ArmorLeft"), model:GetAttribute("ArmorMax")
        local key = armor .. "|" .. tostring(left) .. "|" .. tostring(mx)
        if o.armorKey ~= key then
            o.armorKey, o.armorType = key, armor
            local dur = (type(left) == "number" and type(mx) == "number") and string.format(" %d/%d", left, mx) or ""
            o.armorStr = "[" .. armor:sub(1, 1):upper() .. armor:sub(2) .. " Armor" .. dur .. "]"
        end
        local cls = CFG.WeaponRarity[Visual.ARMOR_RARITY[armor] or "Common"] or CFG.WeaponRarity.Common
        o.armorCol = CFG.EspArmor and cls.on and cls.color or nil
    else
        o.armorKey, o.armorStr, o.armorCol = nil, nil, nil
    end
    -- The label string is rebuilt only when its three inputs change, not every metadata poll.
    local key = plr and plr.Name or (kind_of(model) or model.Name)
    local kind = plr and 1 or (role == "corpse" and 2 or 3)
    if o.lblKey ~= key or o.lblKind ~= kind or o.lblRole ~= role then
        o.lblKey, o.lblKind, o.lblRole = key, kind, role
        if plr then
            o.labelStr = key .. (PAL.tag[role] or "")
        elseif kind == 2 then
            o.labelStr = "[CORPSE] " .. key
        else
            o.labelStr = "[NPC] " .. key
        end
    end
end

-- UI-only sampling. Combat health/alive gates remain fresh; absence of a streamed Humanoid
-- invalidates this immediately, while stable HP is sampled at one fixed rate at ALL ranges.
local function esp_health(o, model, now)
    local hum = hum_of(model)
    if not o.hpAt or o.hpHum ~= hum or now - o.hpAt >= (CFG.EspHealthRate or 0.1) then
        o.hpAt, o.hpHum = now, hum
        local cur, cap = hum and hum.Health, hum and hum.MaxHealth
        if not Players:GetPlayerFromCharacter(model) then
            -- NPC health is server-side and not replicated (Humanoid stays at MaxHealth): only bosses/vehicles that publish attributes get a bar.
            local ah = model:GetAttribute("Health")
            local am = model:GetAttribute("HealthMax") or model:GetAttribute("MaxHealth")
            cur, cap = (type(ah) == "number") and ah or nil, (type(am) == "number") and am or nil
        end
        if cur and cap and cap > 0 then
            local frac = math.clamp(cur / cap, 0, 1)
            o.hpFraction = frac
        else
            o.hpFraction = nil
        end
    end
    return o.hpFraction
end

local ESP_UP, ESP_DOWN = Vector3.new(0, 2.7, 0), Vector3.new(0, 3.0, 0)
local function update_esp_one(model, plr, origin, forceColor, role)
    role = forceColor and "corpse" or role or (plr and "foe" or "npc")
    local o = espByModel[model]
    local hrp = o and o.hrp
    local pt = os.clock()
    if not (hrp and hrp.Parent) then hrp = root_of(model) end
    if not hrp or not Cam then
        if o then hide_esp(o) end
        return
    end
    local hpos = hrp.Position
    local dist = (hpos - origin).Magnitude
    local maxDist = plr and CFG.EspPlayerMaxDist or CFG.EspNpcMaxDist
    if dist > maxDist then
        if o then hide_esp(o) end
        return
    end
    -- Head can stream in/out while the root survives; do not bind its cache to root lifetime.
    local head = o and o.head
    if not (head and head.Parent) then
        head = model:FindFirstChild("Head")
        if head and not head:IsA("BasePart") then head = nil end
    end
    -- Box from the root alone: a ragdolled/dead rig flings its Head metres away from the root and the
    -- old head-to-root span blew the box up to the whole screen. Fixed rig height around the root.
    local top = Cam:WorldToViewportPoint(hpos + ESP_UP)
    local bot = Cam:WorldToViewportPoint(hpos - ESP_DOWN)
    if top.Z <= 0 or bot.Z <= 0 then
        if o then hide_esp(o) end
        return
    end
    local minY, maxY = math.min(top.Y, bot.Y), math.max(top.Y, bot.Y)
    local height = math.max(maxY - minY, 8)
    local width = height * 0.62
    local cx = (top.X + bot.X) * 0.5
    local minX, maxX = cx - width * 0.5, cx + width * 0.5
    -- off screen: no raycast, no stroke writes
    local vp = Cam.ViewportSize
    if maxX < -60 or minX > vp.X + 60 or maxY < -60 or minY > vp.Y + 60 then
        if o then hide_esp(o) end
        return
    end
    local now = os.clock()
    pt = Visual.measure("e1box", pt)
    if not o then o = espPool.acquire(); espByModel[model] = o end
    o.hrp, o.head, o.usedAt = hrp, head, now
    local color = forceColor
    local alpha = 1
    if not color then
        local part = head or hrp
        local vis = cached_clear(part, origin, part.Position, model)
        if plr then
            color = vis and COL_VIS or COL_HID
        else
            color = COL_NPC
            alpha = vis and PAL.npcAlpha or PAL.npcHidAlpha
        end
    end
    pt = Visual.measure("e2vis", pt)
    local calm = role == "npc" or role == "corpse"
    if o.hidden then o.shownAt = now end
    o.hidden = false
    -- 0.22 s fade-in whenever a box (re)appears
    local fin = (now - (o.shownAt or now)) / 0.22
    if fin < 1 then alpha *= fin < 0 and 0 or fin end
    local layers = (CFG.Quality >= 1 and not calm) and (height >= 60 and 3 or 2) or 1
    -- Distance LOD: under ~26 px tall the 3-stroke corners (ink bed is 2.4 px wider than the core)
    -- overlap into a grid. Far boxes are one thin core stroke and the corners reach each other.
    local tiny = height < 26
    local weight = PAL.weight[role]
    if tiny then layers, weight = 1, math.min(weight, 0.6 + height / 40) end
    if o.role ~= role or not o.infoAt or now - o.infoAt >= (CFG.EspInfoRate or 0.25) then
        o.role = role
        esp_info(o, model, plr, now, role)
    end
    put_text(o.name, o.labelStr, color, cx, minY - 18, alpha)
    local di = math.floor(dist)
    if o.di ~= di then
        o.di = di
        o.distStr = di .. " st"
    end
    local ly = maxY + 2
    put_text(o.dist, o.distStr, role == "npc" and color or COL_DIST, cx, ly, alpha)
    ly += 14
    pt = Visual.measure("e3text", pt)
    local states = player_states(model, plr, o)
    pt = Visual.measure("e4states", pt)
    local shown = color
    if o.shooting then
        if o.shotBase ~= color then o.shotBase, o.shotColor = color, color:Lerp(COL_PAPER, 0.4) end
        shown = o.shotColor
    end
    draw_corner(o, minX, minY, maxX, maxY, shown, weight, o.aiming, layers, alpha, CFG.EspRound ~= false and height >= 46)

    pt = Visual.measure("e5corner", pt)
    if o.wstr and o.wCol then
        put_text(o.weapon, o.wstr, o.wCol, cx, ly, alpha)
        ly += 14
    else
        o.weapon.Visible = false
    end
    local hotN = 0
    for i = 1, o.slotN do
        local col = o.slotCol[i]
        if col then
            hotN += 1
            put_text(o.hot[hotN], o.slotTxt[i], col, cx, ly, alpha * 0.85)
            ly += 13
        end
    end
    if o.armorStr and o.armorCol then
        hotN += 1
        put_text(o.hot[hotN], o.armorStr, o.armorCol, cx, ly, alpha)
        ly += 13
    end
    for i = hotN + 1, o.hotShown or 0 do o.hot[i].Visible = false end
    o.hotShown = hotN
    -- State icons (Lucide, pooled): size follows the box height, never hidden by distance.
    local isz = Visual.icon.size(height)
    local nst = math.min(#states, 8)
    if nst > 0 then
        if height >= nst * (isz + 2) then
            for i = 1, nst do Visual.icon.draw(states[i], maxX + 6, minY + (i - 1) * (isz + 2), isz, alpha) end
        else
            -- A short (far) box cannot hold a column without running into the distance text, so the icons form a row
            -- right next to the box, bottom-aligned to it (the distance text starts below maxY).
            for i = 1, nst do Visual.icon.draw(states[i], maxX + 4 + (i - 1) * (isz + 2), maxY - isz, isz, alpha) end
        end
    end
    if o.armorStr and o.armorCol then Visual.icon.draw(Visual.ARMOR_ICON[o.armorType], minX - 9 - isz, maxY - isz, isz, alpha) end
    pt = Visual.measure("e6slots", pt)
    local frac = esp_health(o, model, now)
    if frac ~= nil then
        local x = minX - 6
        put_rect(o.hpOutline, ESP_COL.line, x - 1, minY - 1, 5, height + 2, alpha)
        put_rect(o.hpBg, ESP_COL.bg, x, minY, 3, height, alpha)
        -- trailing damage rail: holds 0.3 s after a drop, then drains toward the real value
        local tf = o.tailFrac
        local dtT = now - (o.tailT or now)
        o.tailT = now
        if not tf or frac >= tf then
            tf, o.dropAt = frac, now
        else
            if o.hpPrev and frac < o.hpPrev then o.dropAt = now end
            if now - o.dropAt > 0.3 then tf = math.max(frac, tf - dtT * 0.7) end
        end
        o.tailFrac, o.hpPrev = tf, frac
        if tf > frac + 0.004 then
            put_rect(o.hpTail, COL_RUST, x, minY + height * (1 - tf), 3, math.max(height * tf, 1), alpha * 0.65)
        else
            o.hpTail.Visible = false
        end
        for i = 1, 16 do
            local sq, hi = o.hpS[i], math.min(frac, i / 16)
            if hi > (i - 1) / 16 + 0.001 then
                put_rect(sq, Visual.hpGrad[i], x, minY + height * (1 - hi), 3, (hi - (i - 1) / 16) * height, alpha)
            else
                sq.Visible = false
            end
        end
    else
        o.hpOutline.Visible = false
        o.hpBg.Visible = false
        o.hpTail.Visible = false
        for i = 1, #o.hpS do o.hpS[i].Visible = false end
    end
    Visual.measure("e7hp", pt)
end

-- Plain continuous FOV circle; geometry is rewritten only when its radius/viewport changes.
local FOV_N = 96
local fovLines = {}
local fovOn = false
local fovShape = {}
for i = 1, FOV_N do
    fovLines[i] = new_line(10, 1)
end

local function hide_fov()
    if not fovOn then
        return
    end
    fovOn = false
    fovShape.r = nil
    for i = 1, FOV_N do
        fovLines[i].Visible = false
    end
end

local function draw_fov()
    local vp = Cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local radius = math.clamp(fov_px(), 8, math.min(vp.X, vp.Y) * 0.48)
    if fovOn and fovShape.x == vp.X and fovShape.y == vp.Y and fovShape.r == radius then return end
    fovOn = true
    fovShape.x, fovShape.y, fovShape.r = vp.X, vp.Y, radius
    for k = 0, FOV_N - 1 do
        local a, b = k / FOV_N * math.pi * 2, (k + 1) / FOV_N * math.pi * 2
        put_line(fovLines[k + 1], COL_PAPER, 1, 0.65, 10,
            cx + math.cos(a) * radius, cy + math.sin(a) * radius,
            cx + math.cos(b) * radius, cy + math.sin(b) * radius)
    end
end


local RET_N = 256 -- 2 lines per segment (ink + core)
local retLines = {}
for i = 1, RET_N do
    retLines[i] = new_line(45, 1.2)
end

local retHidden = true
local function hide_ret()
    if retHidden then
        return
    end
    retHidden = true
    for i = 1, RET_N do
        retLines[i].Visible = false
    end
    local pen = Visual.pens[retLines]
    if pen then for _, tri in pen.tris do tri.Visible = false end end
end

local function hide_aim_lines()
    hide_ret()
end

local KA_N = 120
local kaLines = {}
for i = 1, KA_N do
    kaLines[i] = new_line(16, 1.4)
    kaLines[i].Color = COL_IRON
end

local function hide_ka()
    if Visual.kaHidden then return end
    Visual.kaHidden = true
    local pen = Visual.pens and Visual.pens[kaLines]
    if pen then for _, tri in pen.tris do tri.Visible = false end end
    for i = 1, KA_N do
        kaLines[i].Visible = false
    end
end

-- One projection/clipping per segment, three stroke roles, over a fixed pool; no world edits, no render raycasts.
Visual.COL_AIM = PAL.tier[1]
Visual.TRACE_HI = Color3.fromRGB(255, 244, 222)
Visual.KA_BASE = Color3.fromRGB(104, 232, 206)
Visual.KA_WARM = Color3.fromRGB(255, 176, 82)
Visual.KA_HOT = Color3.fromRGB(255, 96, 72)
Visual.galleryRoles = {
    { name = "Ash / CHAKRA PETCH", kind = "foe", color = COL_VIS, font = "ChakraPetch", weapon = "Honey Badger", rarity = "Legendary", armor = "Heavy Armor", round = true, states = { "Aim", "Run", "Reload" } },
    { name = "Fox / RAJDHANI", kind = "foe", color = COL_HID, font = "Rajdhani", weapon = "Hand Cannon", rarity = "Epic", armor = "Medium Armor", round = false, states = { "Crouch", "Shoot", "Light" } },
    { name = "Listener / SHARE TECH", kind = "npc", color = COL_NPC, font = "ShareTechMono", weapon = "NPC", rarity = "Common", armor = "", round = true, states = { "Walk", "Drive", "Dying" } },
}


-- One cached pen per Drawing pool: the closures and the table are built once, a frame only
-- resets the cursor and the camera snapshot. Segments are clipped at the near plane here.
local function clip(pen, a, b)
    local cp, lk = pen.cp, pen.lk
    local da, db = (a - cp):Dot(lk), (b - cp):Dot(lk)
    if da <= 0.1 and db <= 0.1 then
        return nil
    end
    if da < 0.1 then
        a = a:Lerp(b, (0.1 - da) / (db - da))
    elseif db < 0.1 then
        b = b:Lerp(a, (0.1 - db) / (da - db))
    end
    return a, b
end
Visual.pens = {}
Visual.pen = function(lines)
    local pen = Visual.pens[lines]
    if not pen then
        pen = { used = 0, tris = {}, triUsed = 0, quads = {}, quadUsed = 0 }
        -- two roles: ink bed under a core. No halo.
        pen.seg = function(a, b, color, alpha, width)
            if pen.used + 2 > #lines then return end
            a, b = clip(pen, a, b)
            if not a then return end
            local pa = pen.lastWorld == a and pen.lastScreen or Cam:WorldToViewportPoint(a)
            local pb = Cam:WorldToViewportPoint(b)
            pen.lastWorld, pen.lastScreen = b, pb
            local i = pen.used
            put_line(lines[i + 1], COL_INK, width + 2.4, alpha * 0.6, 17, pa.X, pa.Y, pb.X, pb.Y)
            put_line(lines[i + 2], color, width, alpha, 21, pa.X, pa.Y, pb.X, pb.Y)
            pen.used = i + 2
        end
        -- detail strokes: thinner bed (ticks, dashes)
        pen.thin = function(a, b, color, alpha, width)
            if pen.used + 2 > #lines then return end
            a, b = clip(pen, a, b)
            if not a then return end
            local pa, pb = Cam:WorldToViewportPoint(a), Cam:WorldToViewportPoint(b)
            local i = pen.used
            put_line(lines[i + 1], COL_INK, width + 1.6, alpha * 0.55, 17, pa.X, pa.Y, pb.X, pb.Y)
            put_line(lines[i + 2], color, width, alpha, 21, pa.X, pa.Y, pb.X, pb.Y)
            pen.used = i + 2
        end
        -- screen-space segment, two roles (brackets)
        pen.flat = function(x1, y1, x2, y2, color, alpha, width)
            if pen.used + 2 > #lines then return end
            local i = pen.used
            put_line(lines[i + 1], COL_INK, width + 2.4, alpha * 0.6, 17, x1, y1, x2, y2)
            put_line(lines[i + 2], color, width, alpha, 21, x1, y1, x2, y2)
            pen.used = i + 2
        end
        pen.tri = function(a, b, c, color, alpha)
            local pa, pb, pc = Cam:WorldToViewportPoint(a), Cam:WorldToViewportPoint(b), Cam:WorldToViewportPoint(c)
            if pa.Z <= 0.1 or pb.Z <= 0.1 or pc.Z <= 0.1 then return end
            pen.triUsed += 1
            local tri = pen.tris[pen.triUsed]
            if not tri then
                tri = new_draw("Triangle")
                tri.Filled, tri.ZIndex, tri.Thickness = true, 19, 0
                pen.tris[pen.triUsed] = tri
            end
            tri.PointA, tri.PointB, tri.PointC = Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y), Vector2.new(pc.X, pc.Y)
            tri.Color, tri.Transparency, tri.Visible = color, alpha, true
        end
        pen.quad = function(a, b, c, d, color, alpha)
            local pa, pb = Cam:WorldToViewportPoint(a), Cam:WorldToViewportPoint(b)
            local pc, pd = Cam:WorldToViewportPoint(c), Cam:WorldToViewportPoint(d)
            if math.min(pa.Z, pb.Z, pc.Z, pd.Z) <= 0.1 then return end
            pen.quadUsed += 1
            local q = pen.quads[pen.quadUsed]
            if not q then
                q = new_draw("Quad")
                q.Filled, q.Thickness, q.ZIndex = true, 0, 19
                pen.quads[pen.quadUsed] = q
            end
            q.PointA, q.PointB = Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y)
            q.PointC, q.PointD = Vector2.new(pc.X, pc.Y), Vector2.new(pd.X, pd.Y)
            q.Color, q.Transparency, q.Visible = color, alpha, true
        end
        -- the same Quad from screen coordinates (callers that project once and build the geometry in 2D)
        pen.quadS = function(ax, ay, bx, by, cx, cy, dx, dy, color, alpha)
            pen.quadUsed += 1
            local q = pen.quads[pen.quadUsed]
            if not q then
                q = new_draw("Quad")
                q.Filled, q.Thickness, q.ZIndex = true, 0, 19
                pen.quads[pen.quadUsed] = q
            end
            q.PointA, q.PointB = Vector2.new(ax, ay), Vector2.new(bx, by)
            q.PointC, q.PointD = Vector2.new(cx, cy), Vector2.new(dx, dy)
            q.Color, q.Transparency, q.Visible = color, alpha, true
        end
        -- only what the previous frame left visible is hidden
        pen.finish = function()
            local tris, quads = pen.tris, pen.quads
            for i = pen.used + 1, math.min(pen.hiL or #lines, #lines) do lines[i].Visible = false end
            for i = pen.triUsed + 1, math.min(pen.hiT or #tris, #tris) do tris[i].Visible = false end
            for i = pen.quadUsed + 1, math.min(pen.hiQ or #quads, #quads) do quads[i].Visible = false end
            pen.hiL, pen.hiT, pen.hiQ = pen.used, pen.triUsed, pen.quadUsed
        end
        Visual.pens[lines] = pen
    end
    pen.used, pen.triUsed, pen.quadUsed = 0, 0, 0
    pen.lastWorld, pen.lastScreen = nil, nil
    local cf = Cam.CFrame
    pen.cp, pen.lk = cf.Position, cf.LookVector
    return pen
end

-- Soccer silentArt tracer/pulses + a camera-plane target mark, no text and no floor mark.
Visual.lock = { model = nil, at = 0 }
Visual.dashed = function(pen, a, b, color, width, alpha)
    local d = b - a
    for i = 0, 4 do
        pen.seg(a + d * (i / 5), a + d * ((i + 0.55) / 5), color, alpha or 1, width)
    end
end
-- Returns the screen point of the marked bone and the mark colour, or nil.
-- cornerFrame: four rotating superellipse corner arcs in an arbitrary world plane (SA: camera right/up, KA: X/Z at the target's feet).
Visual.frameCorners = {}
for q = 0, 3 do
    for j = 0, 4 do
        local a = math.pi / 4 + q * math.pi / 2 + (j / 4 - 0.5) * math.rad(52)
        local x, y = math.cos(a), math.sin(a)
        Visual.frameCorners[q * 5 + j + 1] = { math.sign(x) * math.sqrt(math.abs(x)), math.sign(y) * math.sqrt(math.abs(y)) }
    end
end
Visual.targetFrame = function(pen, center, ax, ay, radius, color, t, speed, detail, grad)
    speed = speed or 0.7
    local base = color
    -- grad: every piece gets its own iridescent colour (Visual.irid) instead of one flat colour
    local function colorAt(u) return grad and Visual.irid(u, t) or base end
    local spin = t * speed
    local cs, sn = math.cos(spin), math.sin(spin)
    for q = 0, 3 do
        local prev
        for j = 0, 4 do
            local corner = Visual.frameCorners[q * 5 + j + 1]
            local x, y = corner[1] * radius, corner[2] * radius
            local p = center + ax * (x * cs - y * sn) + ay * (x * sn + y * cs)
            if prev then pen.seg(prev, p, colorAt((q * 4 + j - 0.5) / 16), 1, 2.2) end
            prev = p
        end
    end
    if not detail then return end
    -- Centre mark, CFG.AimCenter: 1 ring + core, 2 turning ticks + core, 3 turning dashed ring + core.
    local variant, ir, ia = CFG.AimCenter or 1, radius * 0.2, -t * speed * 1.7
    if variant == 1 then
        local prev, first
        for k = 0, 11 do
            local a = k / 12 * 6.2832
            local pt = center + ax * (math.cos(a) * ir) + ay * (math.sin(a) * ir)
            if prev then pen.thin(prev, pt, colorAt(k / 12), 0.5, 1.2) else first = pt end
            prev = pt
        end
        pen.thin(prev, first, colorAt(1), 0.5, 1.2)
    elseif variant == 2 then
        for q = 0, 3 do
            local a = ia + q * math.pi / 2
            local ca, sa = math.cos(a), math.sin(a)
            pen.thin(center + ax * (ca * ir * 0.55) + ay * (sa * ir * 0.55), center + ax * (ca * ir * 1.5) + ay * (sa * ir * 1.5), colorAt(q / 4), 0.5, 1.2)
        end
    else
        for m = 0, 2 do
            local prev
            for k = 0, 3 do
                local a = ia + m * 2.0944 + k / 3 * 1.2
                local pt = center + ax * (math.cos(a) * ir) + ay * (math.sin(a) * ir)
                if prev then pen.thin(prev, pt, colorAt(m / 3 + k / 12), 0.5, 1.3) end
                prev = pt
            end
        end
    end
    local cr = radius * 0.05 * (1 + 0.3 * math.sin(t * 9))
    local rx, ry = ax * cr, ay * cr
    pen.tri(center + rx, center + ry, center - rx, Visual.TRACE_HI, 0.6)
    pen.tri(center + rx, center - ry, center - rx, Visual.TRACE_HI, 0.6)
end
-- Iridescent gradient: u (0..1 along a path / around a ring) and time give a hue that slides cyan > blue > violet > magenta > rose and drifts over time.
Visual.irid = function(u, t, sat, val)
    local h = 0.5 + 0.5 * (0.5 + 0.5 * math.sin((u + t * 0.22) * 6.2832))
    return Color3.fromHSV(h % 1, sat or 0.55, val or 1)
end
-- In first person the head IS the camera: a trace from there is edge-on and collapses. Start it at a muzzle where the gun sits on screen.
Visual.traceOrigin = function(from)
    local cf = Cam.CFrame
    if (from - cf.Position).Magnitude < 2.5 then
        return cf.Position + cf.RightVector * 0.85 - cf.UpVector * 0.65 + cf.LookVector * 1.4
    end
    return from
end
-- Where the SHOT goes (not where the enemy is): the point the round passes through at the end of its flight, led by his motion, on the chosen body part.
-- Draw order is priority order (the pool is finite): trace, frame, cone, then the small details.
Visual.aim = function(pen, tgt, from, now, full)
    local raw = tgt.T or tgt.raw or tgt.pos
    local sp = Cam:WorldToViewportPoint(raw)
    if sp.Z <= 0.1 then return nil end
    local cf = Cam.CFrame
    local ax, ay = cf.RightVector, cf.UpVector
    local px = Cam.ViewportSize.Y / (2 * math.tan(math.rad(Cam.FieldOfView) * 0.5))
    local unit = sp.Z / px -- studs per pixel at the aim point
    local radius = math.clamp(0.7 * px / sp.Z, 10, 22) * unit
    local base = tgt.peek and PAL.peek or Visual.COL_AIM
    local irid = Visual.irid
    -- 1. the trace: muzzle > (peek >) aim point, a gradient with travelling pulses and an arrowhead
    if full and from then
        local a0 = Visual.traceOrigin(from)
        local alpha = math.clamp(CFG.MuzzleAlpha, 0, 1)
        if tgt.peek then
            Visual.boltTracer(pen, a0, tgt.peek, 0, now, now, alpha)
            a0 = tgt.peek
        end
        local dv = raw - a0
        local len = dv.Magnitude
        if len > 0.5 then
            local du = dv / len
            local inner = radius * 0.2
            local stop = len > inner * 3 and raw - du * (inner * 1.4) or raw
            Visual.boltTracer(pen, a0, stop, 0, now, now, alpha)
            local side = du:Cross(cf.LookVector)
            if side.Magnitude > 0.01 and len > inner * 3 then
                side = side.Unit * (inner * 0.7)
                pen.tri(stop + du * (inner * 0.45), stop - du * (inner * 0.35) + side, stop - du * (inner * 0.35) - side, irid(1, now), alpha * 0.95)
            end
        end
    end
    -- 2. the original frame (rotating superellipse corners + the AimCenter mark) with the iridescent gradient
    Visual.targetFrame(pen, raw, ax, ay, math.clamp(0.7 * px / sp.Z, 10, 22) * unit, base, now, 2.6, true, true)
    -- 3. the server's cone: ring at the true radius (rho studs), never smaller than 7 px so it stays readable
    if CFG.AimCone and held.id then
        local def = gun_row(held.id)
        if def and (def.pellets or 1) <= 1 then
            local rho = Visual.coneR(held.id, def) * (raw - (from or cf.Position)).Magnitude
            if rho > 0.01 then
                local clamped = rho < 7 * unit
                local rr = clamped and 7 * unit or rho
                local prevp
                for k = 0, 24 do
                    local ang = k / 24 * 6.2832
                    local p = raw + ax * (math.cos(ang) * rr) + ay * (math.sin(ang) * rr)
                    if prevp then pen.thin(prevp, p, irid(k / 24, now, 0.7), clamped and 0.5 or 0.9, 1.1) end
                    prevp = p
                end
            end
        end
    end
    -- 5. link to where the enemy is now, when that is somewhere else (lead, body part, lying proxy)
    local enemy = tgt.bone and tgt.bone.Parent and tgt.bone.Position
    if enemy and (raw - enemy).Magnitude > 0.7 then
        local d = enemy - raw
        for i = 0, 4 do
            pen.thin(raw + d * (i / 5), raw + d * ((i + 0.5) / 5), irid(i / 5, now, 0.35), 0.75, 1.1)
        end
    end
    return sp, base
end

-- Soccer sightArt, fed the selected target's feet and the actual aura state.
Visual.ka = function(pen, state)
    if not state.feet then return end
    local color = state.wind and Visual.KA_HOT or (state.ready >= 1 and Visual.KA_BASE or Visual.KA_WARM)
    local t = os.clock()
    local st = pen.sightState
    if not st then st = { at = t, ang = 0, vel = 5.6, dir = 1, flip = t + 1.2, n = 0 }; pen.sightState = st end
    local dt = math.clamp(t - st.at, 0, 0.05)
    st.at = t
    if t >= st.flip then st.dir = -st.dir; st.n += 1; st.flip = t + 0.9 + (st.n * 0.37) % 1.1 end
    st.vel += (st.dir * 5.6 - st.vel) * math.min(1, dt * 6)
    st.ang += st.vel * dt
    -- Soccer sightArt: three split arcs and four outward arrowheads, on the ground plane.
    local c, r = state.feet + Vector3.new(0, 0.07, 0), 1.45
    for arc = 0, 2 do
        local prev
        for j = 0, 5 do
            local a = st.ang + arc * math.pi * 2 / 3 + j / 5 * math.pi * 2 / 3 * 0.72
            local p = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
            if prev then pen.seg(prev, p, color, 1, 2.2) end
            prev = p
        end
    end
    for q = 0, 3 do
        local a = st.ang + q * math.pi / 2
        local out = Vector3.new(math.cos(a), 0, math.sin(a))
        local side = Vector3.new(-out.Z, 0, out.X)
        local tip, base = c + out * (r * 1.5), c + out * (r * 1.05)
        local a1, a2 = base + side * (r * 0.17), base - side * (r * 0.17)
        pen.tri(tip, a1, a2, color, 0.9)
        pen.seg(tip, a1, COL_PAPER, 1, 1.8)
        pen.seg(tip, a2, COL_PAPER, 1, 1.8)
        pen.seg(a1, a2, color, 1, 1.8)
    end
end

-- aim part order: the preferred part first, the rest only when it is out of reach (a swing at the torso beats no swing)
local KA_HEAD = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }
local KA_HRP = { "HumanoidRootPart", "UpperTorso", "Torso", "Head" }
local kaCtx = { best = nil, bestD = 0 }
local function ka_take(model, head, look, reach)
    if not alive_model(model) then
        return
    end
    local plr = Players:GetPlayerFromCharacter(model)
    if plr and not is_enemy_player(plr) then
        return
    end
    if not plr and not CFG.Monsters then
        return
    end
    local bone, dist = nil, reach
    local order = CFG.KaAim == "HRP" and KA_HRP or KA_HEAD
    for i = 1, #order do
        local part = model:FindFirstChild(order[i])
        if part and part:IsA("BasePart") then
            local delta = part.Position - head.Position
            local d = delta.Magnitude
            if d < reach and d > 1 then
                local fx, fz = delta.X, delta.Z
                local fm = math.sqrt(fx * fx + fz * fz)
                if fm >= 0.05 and (CFG.KaTurn or (fx * look.X + fz * look.Z) / fm >= 0.5) then
                    bone, dist = part, d
                    break
                end
            end
        end
    end
    if bone and dist < kaCtx.bestD then
        kaCtx.best, kaCtx.bestD = { model = model, bone = bone, pos = bone.Position, dist = dist }, dist
    end
end

local function ka_pick(range)
    local char = LP.Character
    local head = char and char:FindFirstChild("Head")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (head and hrp) then
        return nil
    end
    local look = hrp.CFrame.LookVector
    look = Vector3.new(look.X, 0, look.Z)
    if look.Magnitude < 0.05 then
        return nil
    end
    look = look.Unit
    -- Client strips the aim point past Reach. Do not swing into that strip (range > Reach is only for facing).
    local reach = range or (SLEDGE_REACH - 0.12)
    kaCtx.best, kaCtx.bestD = nil, reach
    for i = 1, #roster do
        local c = roster[i].Character
        if c then
            ka_take(c, head, look, reach)
        end
    end
    if CFG.Monsters then
        local list = monsters()
        for i = 1, #list do
            ka_take(list[i], head, look, reach)
        end
    end
    return kaCtx.best
end

local function cancel_swing()
    kaAim = nil
    if sledgeMod and type(sledgeMod.release) == "function" then
        pcall(sledgeMod.release, true)
    end
end

-- Aim point on a bone: where the SERVER will have him when the hammer lands (see CFG.KaLead). The picture we render is old by
-- his latency + ours + interpolation, and the strike is judged QuickContact after our packet arrives.
local KA_CONTACT = 0.2 -- Config.Sledge.QuickContact; the hold is below QuickHold so every swing is a quick one
function ka_lead(bone)
    local pos = bone.Position
    if not CFG.KaLead then return pos, 0 end
    local model = bone.Parent
    local root = model and (bone.Name == "HumanoidRootPart" and bone or model:FindFirstChild("HumanoidRootPart"))
    if not root then return pos, 0 end
    local now = os.clock()
    Resolver.sample(model, root, now)
    local hum = hum_of(model)
    local vx, _, vz, ax, _, az, top = Resolver.motion(model, root, hum ~= nil and hum.SeatPart ~= nil, now)
    if not vx then return pos, 0 end
    local ph = Visual.pingHalf()
    local t = KA_CONTACT + ph * 3 + CFG.KaInterp
    local ox, _, oz = Resolver.offset(vx, 0, vz, ax, 0, az, top, t)
    local off = Vector3.new(ox, 0, oz)
    local m = off.Magnitude
    if m < 0.15 then return pos, 0 end
    if m > CFG.KaLeadMax then off = off * (CFG.KaLeadMax / m); m = CFG.KaLeadMax end
    return pos + off, m
end

-- Turn the root toward the (led) bone. The server reads the character's facing, so this runs every render frame while an
-- enemy is inside KaFaceRange (Visual.kaFaceStep), not only around the swing.
local function ka_face(bone)
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not (hrp and bone and bone.Parent) then
        return
    end
    local p, b = hrp.Position, ka_lead(bone)
    local dx, dz = b.X - p.X, b.Z - p.Z
    if dx * dx + dz * dz < 0.0025 then
        return
    end
    hrp.CFrame = CFrame.lookAt(p, Vector3.new(b.X, p.Y, b.Z))
end

local function step_killaura(now)
    if not CFG.KillAura or held.id ~= "sledgehammer" or not sledgeMod or not aimWrapped then
        if ka.phase == "wind" then
            cancel_swing()
        end
        ka.phase = "idle"
        ka.tgt, ka.lookTgt = nil, nil
        return
    end
    if CFG.KaTurn and now >= (ka.nextLook or 0) then
        ka.nextLook = now + 0.1
        ka.lookTgt = ka_pick(CFG.KaFaceRange)
    end
    if held.since and now - held.since < DRAW_WAIT then
        return
    end
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        if ka.phase == "wind" then
            cancel_swing()
            ka.phase = "idle"
            ka.untilAt = now + 0.08
        end
        return
    end
    if ka.phase == "idle" and now >= ka.untilAt then
        if now < ka.nextPick then
            return
        end
        ka.nextPick = now + 0.1
        local tgt = ka_pick()
        ka.tgt = tgt
        if not (tgt and type(sledgeMod.press) == "function") then
            return
        end
        if CFG.KaTurn then ka_face(tgt.bone) end
        sledgeMod.press()
        ka.phase = "wind"
        ka.untilAt = now + QUICK_HOLD
        ka.tick = 0
    elseif ka.phase == "wind" and now >= ka.untilAt then
        local tgt = ka_pick()
        ka.phase = "idle"
        ka.tick = 1
        if not (tgt and tgt.bone and tgt.bone.Parent) then
            ka.tgt = nil
            cancel_swing()
            ka.untilAt = now + 0.08
            return
        end
        ka.tgt = tgt
        if CFG.KaTurn then ka_face(tgt.bone) end
        ka.scarA = muzzle_pos()
        ka.scarB = tgt.bone.Position
        Visual.kaAimResult = false
        Visual.kaRecovery = nil
        kaAim = { model = tgt.model, bone = tgt.bone }
        if type(sledgeMod.release) == "function" then
            sledgeMod.release(false)
        end
        kaAim = nil
        if Visual.kaAimResult then
            ka.scarUntil = now + 0.18
            -- Config.Sledge.QuickContact = 0.2; retain facing through contact + one short margin.
            ka.faceUntil = now + 0.25
        end
        ka.untilAt = now + (Visual.kaRecovery or QUICK_GAP)
        if not Visual.kaRecovery and CFG.ShotLog then
            warn("[hush] KA no Fire branch: press was not armed, or release cancelled by aim/range")
        end
    elseif ka.phase == "wind" then
        ka.tick = 1 - math.max(ka.untilAt - now, 0) / QUICK_HOLD
        if CFG.KaTurn and ka.tgt then ka_face(ka.tgt.bone) end
    end
end

Visual.kaFaceStop = function()
    if ka.faceHum and ka.faceHum.Parent and ka.faceHum.AutoRotate == false then
        ka.faceHum.AutoRotate = ka.savedRotate
    end
    ka.faceHum, ka.savedRotate = nil, nil
end
Visual.kaFaceStep = function()
    local now = os.clock()
    -- during the swing window the swing target wins, otherwise the nearest enemy in KaFaceRange
    local tgt = (ka.phase == "wind" or now < (ka.faceUntil or 0)) and ka.tgt or ka.lookTgt
    if not (running and CFG.KillAura and CFG.KaTurn and held.id == "sledgehammer" and tgt
        and tgt.bone and tgt.bone.Parent and alive_model(tgt.model)) then
        Visual.kaFaceStop()
        return
    end
    local hum = hum_of(LP.Character)
    if hum ~= ka.faceHum then
        Visual.kaFaceStop()
        if hum then ka.faceHum, ka.savedRotate = hum, hum.AutoRotate end
    end
    if hum then hum.AutoRotate = false end
    ka_face(tgt.bone)
end

Visual.kaState = {}
local function draw_killaura()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not CFG.KillAura or held.id ~= "sledgehammer" or not hrp then hide_ka(); return end
    local now = os.clock()
    local tgt = ka.tgt
    local to = tgt and tgt.bone and tgt.bone.Parent and alive_model(tgt.model) and tgt.bone.Position or nil
    if to and (to - hrp.Position).Magnitude > SLEDGE_REACH + 2 then to = nil end
    if not to then ka.lockModel = nil elseif ka.lockModel ~= tgt.model then ka.lockModel, ka.lockAt = tgt.model, now end
    local root = to and bone_of(tgt.model, "HumanoidRootPart")
    local feet = root and root.Position - Vector3.new(0, 2.7, 0)
    local ready = 1
    if ka.phase == "idle" and now < ka.untilAt then
        ready = math.clamp(1 - (ka.untilAt - now) / QUICK_GAP, 0, 1)
    end
    Visual.kaHidden = false
    local pen = Visual.pen(kaLines)
    local st = Visual.kaState
    st.center, st.look, st.reach = hrp.Position - Vector3.new(0, 2.7, 0), hrp.CFrame.LookVector, SLEDGE_REACH
    st.ready, st.wind, st.tick, st.phase = ready, ka.phase == "wind", ka.tick or 0, visPhase * 0.6
    st.from, st.to, st.feet = to and muzzle_pos(), to, feet

    st.lock = ka.lockAt and (now - ka.lockAt) / 0.18 or 0
    st.impact = math.clamp((ka.scarUntil - now) / 0.18, 0, 1)
    Visual.ka(pen, st)
    pen.finish()
end

-- Same standalone HitSound path/presets as Cold war/ballistics-combat.lua.
Visual.HIT_SOUNDS = {
    Fatality = 115982072912004,
    ["Minecraft XP"] = 15181891182,
    ["Minecraft Hit"] = 73571339886360,
    ["Minecraft Egg"] = 134530432300459,
    ["Minecraft Bow"] = 111481862692779,
    Click = 95635059379804,
    Bell = 124010691633262,
    Neverlose = 139452805868562,
    Primordial = 97511223764004,
}
Visual.hitSoundAt = -math.huge
local function play_hit()
    if not CFG.HitSound then return end
    local now = os.clock()
    if now - Visual.hitSoundAt < 0.04 then return end
    Visual.hitSoundAt = now
    local id = Visual.HIT_SOUNDS[CFG.HitSoundPreset] or CFG.HitSoundId
    local s = Instance.new("Sound")
    -- Ears.route captures ungrouped sounds into the gunshot-deafened World mixer.
    -- Assign our own group BEFORE Parent triggers the game's DescendantAdded listener.
    if not Visual.hitGroup then
        local group = Instance.new("SoundGroup")
        group.Name = "HushHitFeedbackMixer"
        group.Volume = 1
        group.Parent = SoundService
        Visual.hitGroup = group
    end
    s.Name = "HushHitFeedback"
    s.SoundGroup = Visual.hitGroup
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = math.clamp(CFG.HitSoundVolume or 3.5, 0, 10)
    s.PlaybackSpeed = math.clamp(CFG.HitSoundPitch or 1, 0.5, 2)
    s.Looped = false
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 4)
end

-- Hit particles: jagged arcs from the hit in two waves, screen-space lines, pooled. Length is clamped in pixels so near and far hits both read.
Visual.pfx = { list = {}, n = 0, lines = {}, lUsed = 0, lShown = 0, demo = nil }
Visual.pfxRamp = function(t)
    t = t < 0 and 0 or (t > 1 and 1 or t)
    if t < 0.5 then return CFG.ParticleColorA:Lerp(CFG.ParticleColorB, t * 2) end
    return CFG.ParticleColorB:Lerp(CFG.ParticleColorC, (t - 0.5) * 2)
end
Visual.pfxSpawn = function(pos)
    local P, now, sc = Visual.pfx, os.clock(), CFG.ParticleScale
    for i = 1, 11 do
        if P.n >= 40 then return end
        P.n += 1
        local p = P.list[P.n]
        if not p then p = {}; P.list[P.n] = p end
        local d = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
        p.pos, p.dir = pos, d.Magnitude > 0.05 and d.Unit or Vector3.yAxis
        -- staggered life: every arc has its own length of life and its own start, so the burst dissolves arc by arc instead of all at once
        p.life, p.size, p.t0, p.seed = 0.28 + math.random() * 0.37, (2.2 + math.random() * 2.4) * sc, math.random(), math.random()
        p.born = i > 6 and now + 0.07 + math.random() * 0.16 or now + math.random() * 0.04 -- second wave
    end
end
Visual.pfxLine = function(col, thick, alpha, ax, ay, bx, by)
    local P = Visual.pfx
    local n = P.lUsed + 1
    P.lUsed = n
    local l = P.lines[n]
    if not l then l = new_line(25, 1); P.lines[n] = l end
    put_line(l, col, thick, alpha, 25, ax, ay, bx, by)
end
Visual.pfxStep = function(cam, now)
    local P = Visual.pfx
    if P.n == 0 and not P.demo and P.lShown == 0 then return end
    P.lUsed = 0
    local cf = cam.CFrame
    local look = cf.LookVector
    local focal = cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView) * 0.5))
    local line, clamp, ramp = Visual.pfxLine, math.clamp, Visual.pfxRamp
    local i = 1
    while i <= P.n do
        local p = P.list[i]
        local age = now - p.born
        if age >= p.life then
            P.list[i], P.list[P.n] = P.list[P.n], p
            P.n -= 1
        else
            i += 1
            if age >= 0 then
                local u = age / p.life
                local alpha = (1 - u) ^ 1.3 * 0.9 -- preserve the dissolve curve
                -- the arc dissolves from its root outwards: the first segments drop out as it ages (also fewer lines to draw)
                local j0 = 1 + math.floor(u * u * 3.2)
                local s = cam:WorldToViewportPoint(p.pos)
                if s.Z > 0.5 then
                    local kk = focal / s.Z
                    local reach = clamp(p.size * kk, 30, 120) / kk * Visual.oe(u * 4)
                    local frame = math.floor(age * 48) -- the zigzag is re-rolled 48 times a second: flicker
                    local d = p.dir
                    local side = d:Cross(look)
                    side = side.Magnitude > 0.05 and side.Unit or cf.RightVector
                    local up = d:Cross(side)
                    local col = ramp(math.min(p.t0 + u * 0.4, 1))
                    local prev = s
                    for j = 1, 5 do
                        if j < j0 - 1 then continue end -- not drawn and not needed as the start of a drawn segment
                        local jit = (5.4 - j) / 5 * reach * 0.22
                        local h1 = math.sin(p.seed * 91.7 + j * 12.9 + frame * 7.3)
                        local h2 = math.sin(p.seed * 53.1 + j * 78.2 + frame * 3.7)
                        local q = cam:WorldToViewportPoint(p.pos + d * (reach * j / 5) + side * (h1 * jit) + up * (h2 * jit))
                        if j >= j0 and prev.Z > 0 and q.Z > 0 then
                            line(col, 3.6, alpha * 0.2, prev.X, prev.Y, q.X, q.Y)
                            line(COL_PAPER:Lerp(col, 0.25), 1.3, alpha, prev.X, prev.Y, q.X, q.Y)
                        end
                        prev = q
                    end
                end
            end
        end
    end
    for j = P.lUsed + 1, P.lShown do P.lines[j].Visible = false end
    P.lShown = P.lUsed
    if P.demo then
        if now - P.demo.at > 4 then P.demo = nil
        elseif now >= P.demo.nextAt then
            P.demo.nextAt = now + 1.1
            Visual.pfxSpawn(P.demo.base)
        end
    end
end
-- preview (; key): the same burst, 12 st ahead, repeating for 4 s
Visual.pfxDemo = function()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local look = Cam.CFrame.LookVector
    look = Vector3.new(look.X, 0, look.Z)
    look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
    Visual.pfx.demo = { at = os.clock(), nextAt = 0, base = hrp.Position + look * 12 + Vector3.new(0, 1.5, 0) }
end
Visual.clearParticles = function(destroy)
    local P = Visual.pfx
    P.n, P.demo = 0, nil
    for _, l in P.lines do if destroy then l:Remove() else l.Visible = false end end
    P.lShown = 0
    if destroy then P.lines = {} end
end
local function burst(pos)
    if not CFG.HitParticles or typeof(pos) ~= "Vector3" then return end
    Visual.pfxSpawn(pos)
end

local Loot = { grid = {}, selected = {}, nextQuery = 0, pending = nil, nextAuto = 0, perf = {} }
-- One console line every 15 s: calls/s, average and worst ms per section, then reset.
Visual.report = function()
    local parts = {}
    for name, row in Loot.perf do
        parts[#parts + 1] = string.format("%s %.2f/%.1fms %.2fKB", name, row.totalMs / math.max(row.calls, 1), row.maxMs,
            row.kb / math.max(row.calls, 1))
    end
    table.sort(parts)
    warn("[hush] perf avg/max per call: " .. table.concat(parts, " | "))
    local st = Loot.stats
    if st then
        warn(string.format("[hush] loot search since report: queries %d | local rows %d/max %d | rebuilds %d cells %d | CPU %.2f/max %.2fms | position samples %d",
            st.queries, st.rows, st.maxRows, st.rebuilds, st.cells, st.totalMs, st.maxMs, st.moves))
        for key in st do st[key] = 0 end
    end
    table.clear(Loot.perf)
    local ds = drawMeta.stats
    warn(string.format("[hush] resources: Drawing live %d peak %d created %d removed %d | ECP active %d free %d | connections %d/%d/%d | particle slots %d",
        ds.live, ds.peak, ds.created, ds.removed, espPool.inUse, #espPool.free,
        #connections, #Life.char, #Life.monsters, #Visual.pfx.lines))
end
-- Sections are chained: each call books the heap growth since the previous call (a collector step shows as a negative delta and is dropped, so KB is a floor).
-- Visual.memAt must be set at the start of every chain (step, Heartbeat, moveStep).
Visual.memAt = 0
Visual.memStart = function()
    if CFG.PerfLog then Visual.memAt = collectgarbage("count") end
end
Visual.measure = function(name, since)
    if not CFG.PerfLog then return since end
    local kb = collectgarbage("count")
    local elapsed = (os.clock() - since) * 1000
    local row = Loot.perf[name] or { calls = 0, totalMs = 0, maxMs = 0, kb = 0 }
    row.calls += 1
    row.totalMs += elapsed
    row.maxMs = math.max(row.maxMs, elapsed)
    if kb > Visual.memAt then row.kb += kb - Visual.memAt end
    Visual.memAt = kb
    Loot.perf[name] = row
    return os.clock()
end
-- time only (a whole-callback total must not disturb the memory chain)
Visual.measureT = function(name, since)
    if not CFG.PerfLog then return end
    local elapsed = (os.clock() - since) * 1000
    local row = Loot.perf[name] or { calls = 0, totalMs = 0, maxMs = 0, kb = 0 }
    row.calls += 1
    row.totalMs += elapsed
    row.maxMs = math.max(row.maxMs, elapsed)
    Loot.perf[name] = row
end
local MOCK_N = 700
local mockLines = {}
local mockText = {}
local stations = {}
Visual.mockActors = {}
-- Exact supplied pointer-bolt SVG rasterized ONCE offline; Drawing.Image takes PNG bytes, not XML.

local function hide_mock()
    if Loot.mockHidden then return end
    Loot.mockHidden = true
    local pen = Visual.pens[mockLines]
    if pen then
        for _, tri in pen.tris do tri.Visible = false end
        for _, quad in pen.quads do quad.Visible = false end
    end
    for i = 1, #mockLines do
        mockLines[i].Visible = false
    end
    for i = 1, #mockText do
        mockText[i].Visible = false
    end
end

local function drop_mock()
    if #stations > 0 then
        Loot.galleryVisible = not Loot.galleryVisible
        if not Loot.galleryVisible then hide_mock() end
        return
    end
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Debug gallery is opt-in: no demo lines, labels or images allocated in normal gameplay.
    if #mockLines == 0 then
        for i = 1, MOCK_N do mockLines[i] = new_line(12, 1.2) end
        for i = 1, 72 do mockText[i] = make_text(24); mockText[i].Size = 13 end
        for r = 1, #Visual.galleryRoles do Visual.mockActors[r] = { lines = {} } end
    end
    local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
    look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
    local right = Vector3.new(-look.Z, 0, look.X)
    for i, kind in { "ECP", "SA / SOCCER", "KA", "LOOT", "TRACERS", "HIT" } do
        stations[i] = { feet = hrp.Position - Vector3.new(0, 2.7, 0) + right * (9 + (i - 1) * 11) + look * 4,
            look = look, born = os.clock(), phase = 0, kind = kind }
    end
    Loot.galleryVisible = true
end

local function station_beat(age)
    local t = age % 4.6
    if t < 0.7 then
        return "IDLE", 0
    elseif t < 1.6 then
        return "RUN", (t - 0.7) / 0.9
    elseif t < 2.5 then
        return "AIM", 0
    elseif t < 3.1 then
        return "SHOOT", (t - 2.5) / 0.6
    end
    local u = math.clamp((t - 3.1) / 0.8, 0, 1)
    return "CHARGE", 1 - (1 - u) * (1 - u)
end



-- @@ICONS (generated by tools/make_icons.py + tools/inject_icons.py; Lucide, ISC licence) @@
Visual.ICON64 = {
    Aim = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAACGUlEQVR42lWSXUhTcQDFz//e7VL7sC5uMYxthdDDvgrLvdgWJMVyK7YoMHFhKDICwRKhp+K+GQROiNiDEOSDGEOhhzkGWr0UtFhN1LUKDLN0y8Lch9vd7v33YEWdp/NwHn5wfgQAA0AGcOi6zzcYcLs9B3U6EyQJX75trs48exp/kEiEAXwCwBCGEGjYPa0PbwyMX3S7HFIuB2g0FNUqQClhdTrMxOMLPZFIX1GSkgBgjoZCi3RqiiZ6rqXtPC+s3L5TWRkertj38UKivz9Np6dptLt7EYAZvU5nmI6N0Tl/IA3ADICb8PpSEx3eFAAOgHkuGEzT0VHaa7GEMd/Vld0JhWQeRACgYQkBAAMAw++u4QkRdm4OyfNeb1Zh4Dgjq1CQl5cvDb368PH81bdvOpQMswEANVk2PGprizmNpiMsS4hBpkaFuPUT1e1tIJeHJIoAAEop/kQqFoG1zxA5JcRSEYi6XNlcICBrgV2k3d1/SFpWKeQ7r8iPrdYsM/nu/SyrUpH7x0/4ATRKAHe3pSU2YrHGJEo5AI0Rz1k/LZfI5NrXWTZTLmUaxNqZzmNH7YfV6tPL6+sHglZbgJfq+lShwIy0twvnGrSOSPL1UiSfGyDM7tWtt5qbxy/YbI6tWg2cXk/rpRJotUrUlQqeLGUW7uU3+uR6PUn+VeOUSjV4sqnJs3+vygRZxo9CYfXF5vf483Lxrxq/ADQN3C1rYorhAAAAAElFTkSuQmCC", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADcElEQVR42mWSXUybZQCFn/d7+2MHs2NgSS3ZRplox1jn+BsgK2maSbZlGWQsomYuuIAXcxcm27JlMd5MN9JwpQGSxjskQadLFm8IAU00QVq1kzglkwt+BuVvFMZf+fi+14saM+O5PycnzzmCtITUNGWYpgRCJyurz7zmP1Tqyc4uwDR5PD8/9kP819i3sdg9oF8KYRhKCUCJZ8yuUHHxtetvvd0UPFjkxmoFmw02N8FqhVSKgeHozCdfdPf0P3p0RwoxZyglpCYEplKud2sCnZHL7zf7XsjZ+fvQ0HLX3bsTvqws59r4uNne3f1XjmlaKioqck77/ZVPpmf2x6anBzUh1ggEApZAYWE42dmpVDis2oKhYeAE0Lpw+7a5cPOmCbQCJ9pCoWEViahkOKwCe/aEA2ABCA1eupRQ7e2q7WhlFPBLIcjOcNber29YvF9fv5id4ayVQgD422pqoioSUYNNbyaAEHUFL3WYt26phw0NSZB1Vk3QS6MErMBxkMcBay9Iq6YB1D1saUmaN26oOrenQwvm5ZWJZJLe30ZmHRh7dasteI4vBaAL6BMYfYB+DoQuRNABe3ujsVmhFMGc7DKLx2714nDwXuVRb0t11Wc/j4wsn33woGnLMPqOpFvwC+g2KYNfHTvWU5Kf79SkVAhBnmF4LdsbG6ipKfSxMTSbDWNLB4sFDIP/yoKxlMQ0xzBsNpQQ6LoOHx0oiqnmZnXF7R61a1orUgb5h+7/EqQM2qH1qv/wqDp/Xn3o8cS0gcmp6IKu8/q+fbkp0xy3mMZAI6h/Ico0xEZQFqUGUjB+srAwdzaR4LuV1ShA6POS0sT6xYvqstudnlHTyJCytqOyavHTg8WLTmmvlVp6xqul5dHVCxdUl7cggbSHZAAmvn+y5DqStasqWFz8oplcLvkpmXysK+W9Ulpy1plKOSKT40NKkftBeUV76wFf2R/xOB9Pz3S9vLkWkZNgJozt+MTc/H5fxg7fqVcPe8pzc089rzhUmJe3a2NzU2Vm7nzlanXVO6ddLu+f8TjtU9Pf/Li8dH0SngpAaKBMcPnsjmtveNxNFfn57qzMTMzdu9leW8O6vs7CwgLRicmZr1ef9oysrNzRYM6E9D+fCZFAqMj23Blfxo7SLKulAGBpSx8b3dqKjaS272Gk+jUwTBCA+huZB3X/rYHq9QAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAFFUlEQVR42nWVXUxTZxjH/+c9p8d+U2or5cOxFrCIEOZAJTiHE4WADBO1cQlsuvgR5rIsYVxsWbbiohE/wryRYLjYzKiGYJxZOmUmZnNZiNGQCNMNCy0o3xWktLQ97WnPu4vWr4v9r968eZ7/xfP+nv/L4KUYAJQlBHFJWgWgwpKZVVaYYynJSNXnQaKYXpgfeeD2DHjmZu4AuM0S4o1L0ove5wcAYBiA7rXZ2N7e3tr6TZsaD9fXbyy3Wk16jUYOrRYIhYB4HM+WloT+wcHZLqfz7i/373fbbLbrV3p74zRpyjw3y8zKUsxOTh/t/OzTpo937MglhAATE3j45ImYt66Qg28RIzMzsXVmswxmMyS/Hz9c/Xm0yXGp05Rh6pianAxTgIEdIHa7neMJae778qs5eu0ajZ1qk7r3feDakpN7Qa/WOpe6uuJLbafierXWucVsvtC9b58r1tEhUaeT9h06PMfzfLO9ooKzAwQswwBAbdf+/W56yUF9LS3CgbdLbgCoA6DIW2lsFc+do2JrK80zGlsBKADUHSgsuuE7flygly/Trp073QBqk14w1BQU9MQ6Omik5YtYY2FhH4AinmXBMgw0KlXz3YbG0L2GhpBGpWpmGQY8ywJAUWPemr7ImTOx2MmTtCbb3APAAAB7nAcPPqZtbdSx5d1RALU8IQAgSz6aSSlXtiiVyhYApuSdLFlT66iuHqXnz9Nfa2oeA9jDWdTa8s0Ggyn66BFtH350C8DNWAIFMUnAbEgIncXrEpM1N9vvDdzaW1pqKU9LM1nU2nKuaJWxRCdJ/D+eMXFieTnTotV9PR4VAxCCDgBzAAh9yRgDQAKQBl7eYFHKNRN+X+bo2FisQKPhi5SKEi6D49bQlBTk5ltlI/nWWiJJO/8dGgpVDw4SnyCc/TZhRAHADjDfAdBx3Ie/bd92bK3FopSCQSrPymKo14sMhlnDSbEYmOlpiMPDEAGsYBjEIxEABP8rjkfc+xQQBIjhMLhoFHw8DolScBOBgCsejaYPBYPirr8f3NTI+Hvj0WhAigoOADiW2Cnm1bVaFEI/bR4alN6UyzWBwPIGZ0Zm1fqIIJsQRRcZerY4MOb3Ry0mE2di2SnPsv8EjQrtyfkBgMQkVoom5wcAczQabff4/SfSU/VTOak6zj3njT4QYwNkMi7233a7Z9NWr2Y+MhorAbaKSzQlsVGa5BzfIpfLWwDlC2y4BDZVh94qrtRHIsyfXu/sk7DQDwCGcrW6x22z0dHdu2NVKnUfgCIZw4AAUBGuubeyMuQoLg6pOL6ZAJAlzIrezzb3jR85EntYWkrf0a/sAWAgBJjvXw5f7Ozv9yi1WvbYtve2VqvUp0VK6yRAoZPJtLnp6QqzWq3QyWRaCVCIklRXb7Gcbt2+bWvc5WJ/nJ7x/LUUuEiAeZYCxA7qOR2OkNSF+fUbcnJSyq3WnHRgw3wwnD8bDubvMptzl7xe6picDK01GDd/XlbWdLC4eKPM5eKuesa8JxcWv/9GFC79kZxHIr4AxTQvP/qJLqVpV741943sbHhFEe6FBdFaUMCFp6YwGQ7HzDqdTB8KYnxkBH3zC6OdvkCnSQh2TAFhmvB6JWABtpfla9ev4Bu367Qb1xkMJmNKipwoFJBEEVIohLnFRWHY55/9PSLcHVgOddvi0etXgNcC9rUvgCTYWAWWr1jJsWWZLClJJUweGAKfREemKR14GovfQTR8mwBe6ZVeAPgP1ks+FxzTyn0AAAAASUVORK5CYII=" },
    Shoot = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAACAElEQVR42l2RQUjTcRzF3/e3/S1HpGNzbjmqZXOxDfeHFUVZgzCFVCRpEIUFWRAU2MGKivgrYYeiQspLSBnRpQ6jg4esZISXiDQrtA20y7b6N9baHGzq/H87mA16l3f58N6DRyiJiIiZWbR591wSa6RF+UP4bi8zExHjf7HCAgA6dzRfSw6FeerCgzwg+ZmZAOhWOfHPe8EGySCf391+0ZwC6o2b1nbVNXQSEXOwVCAAIICA0JFgj8HqkPVV6yZev5rLJNTslb1HulyS6Rg9p2UFiiiNBwGAGUBz/PCd7GzrDfVcdcMonwnx1MHrv7eX13QIEBQoAmIFtjyTT07esja97bYHRrjjCTdKW273W/YPc/Apv/GcjgFw6Iig18BoXe86FHTuknOm9FJk4VcM8R9wS2b16s8xxfOpxtdu88st+tqWkeLsfQEAdZUbnDk1pcXjibw9JxwD0dHJR8WPLyTS5cKF2DgEaw6pwg4AegD4mk6ohW0kQurnucvpsX6Y8FIs0bzGXL7VaPMnCxkxvZBKrr4FAL5h99HsTKPCx43+AQB+ADtPOfc9jDT18VB1WwZAvQCBGIoQ6NN8wtLd4zpw023dWDadU4s6vWBnmUn6Eo0sDibf9bwvfr/H4JV4BogAroLhRLDSe9ZbYdusLWs0k058C+Wjgwlt/vFfBn8AZJ3HWrKggHkAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADBElEQVR42o1TWWyMYRQ99/v/+XXU0tZkWqqj1BShm1EkZNS+lEpEtBUVIqLiQQiRCBnaF0uIRHgoQvDAgz2NpVL7kkqEYui0MqXM0G3QWWpm/u96oDGJCOfp5ibn5NyTexT8CSJQzzwbQCYANwDG/4DBBIAGJySvq91e9fncqgovoNqZmQCIf/GFIAGjZiyq3XDAx+dczHtr2D4kew+BwA7+QyB2QYoQUrI0lk8oXD3VYkvoqr4bgiEOazLt8xk8UqtQJQDlrwLRM7oCwJSfmJ4u20Nccfvs/VaX6+vicbNGlSTbtkZY76+S0IHfIcUKsFas6sOBVk/LB5+IEPVWNGXzxSMPtJDAwTnlpcWJOfujLBMFiHtEYu0ICZ7WqcIc8gVEWVpuwRgl0VRWf/JyyqegYs/IH1KQnJnr/OhOcIXbbzJY34mdBADil5/CS/lrOq8PW/EOwNo7E9c38NwqLjNm7QKQsztpWh0vOc0vszcGzYhfKkBwAEJRQCwBbYUpv3KLvdRmUeLjO7r9YpI1OzXFG+5/9HPd87fSd7wm5G4aH+03fZIlb0Czpxl1Ee+F+yBdEBEAJI0fNNwaaWrhLt8X9ZBteWFOq9Fytvlhxy18vK6zJMeUKffOf214KIXOY+LMGQCSCAS15/5oOKKyAjpWX/tENBrYEw1EDvPLqu5wqBoO0GinmRtdzZI4TN/1qPIzP4bKzADQ+art/XtpnTy6q4/oVdl5ayMG4pHwUpDBpFWqHJF6zh5bcW7AH4Dze5sHgI8BiG1gAaD7asfraw88LlmaV5C1SFjL4cVQCdYIpESknluUZtuxYFBW5t3G53xNtlwFENoGFgSAGAzqQ6aiqPWUI2/hbL1vL1xxP2144fc+EwaFxyZn5M01jxrR7fyA3d57Ny6rrmXCT20STBTTQGaNR87joftK0sbNHJGaboBCAAh6IASnuyl8wd9QUy3fbhJheiN/lo4p9pUFiGVvTkkKxq2cbEidYTEkmKSU/E7/1v6Y2m52qN9OiCB96iEDwA9rtViVAl7rfwAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAENklEQVR42qWUa0yTZxTH/+d5315sS21BhGgptwpIRRSDE4JzXpCFhUQ3cZm7fHEmC8YtGTGZySLzi1l0W5ZlcR/mh8Vdskiim5mimZnRbMPNa0EY3ZzKkJuFIqWUt337PmcfCgkaE112Pj7J+Z/f+Z/zHOAxIUgAQAGAAgLh/4RgZgKwefezr5zf9cyWCwBqiQgAxH8Vo2myLQcad3bzqZusHzjN5dm+T1rQMlPoyckUIQDAt72m4Sf+/Dfm/W1sfPqz3Fv1YjuAYjVV7JGUj3yUzLAIy/rm6k0rcTvEwcuBIaEnaduiVX5VNW9mAC3TnTxWkECSmVHkWuDzmdz2WF+/Vtf20ZmBju6x4sUVaQf9m14yWNbtJ0U+iSBJ7BUARHQyqk2Gx6WZTKYpThh7fjzSjqFR7FzbWLo7Z22LzkatQkI+rKE8SAe8h/MsCDyWjLk3pi3aUJi7xGEdHNPe7z171jMqMyo9/gW1heWexNBYyYWJ270K6G+eRargQS/mm6G+4bA7KwxonfYoLa7Pr/C5x+Pur0LXT7WOXD+dNaCVV3oWz1vnLVs41N+fe0kb+F0BhThFygoATFcQQeFoPrfm7Xe3GN4NhyOBjquRf3pfn7+8Ns9wWE8Odt3uMyIfnIwFR7L6tdLKwmWZT8n07GP3uowsjp0bAZIzHgoTCd4HFDd5VzcsL6u0VeWU2LZxycYSt6fE7HToeigCXWUTgxUTi2+bRtsOtXf+OpLpKbDssJWt7TahSKSaFGpqEAwApdULi/L1q0GGVaXP6nc0aoKT8/p09WQ4GL5qDF8SICPBBtlgO/7lvWvPr1q0Yl25LduDGHwM3ABAKgDmlH9Oq2K2RKOTdDHQ2evNWrjArkNtnbh77534L62WePz7CYAUCJbg8K3E/QE9GYNZUS0QwsWGBABWARClfIyOxCJxiyPd/nG8I3Dt7pmv04XTGuThADT8ACBMgMKQ0pnmtM+1OdySJca0qA5VTpJOYDAJAEwpxDuBwVsh4bJhw5zcshBPXQxODTcLjY4QKAxAaQHYLFSemJioeTqv1J+MxhDQhkMAemnWYqdazkDPiaHOKz1jA1y/vNpbn8jbBRWrDJZEBAgiYx+R1KVR1eBZ0bQ+qyTnRrCH23D3MqbQzak5yJm1EWKK4gPmaEwZ1lauzvdnVnh9uYnRybJX9+zMToDTGSh2wfrCa6Vr3nxrWV210tGvfhEO3Pwu2XNAGNQtp+Fm/0VxFI201XK8qVmt2L21rCbHlunGn5GheH98PAIhyGvPmJuvpJnud/XiRPiPvg9l4ODRqfihrQADkA9fCwLAKwDTFYt4+TmZv73O5Vvizch2pVnmgA2J8cg47owO3z/Pg10njL8Ol8blN91AYib3UeeHALAAQdp5qdCtDX7DuTSTrC4AHFb0SIcyfkXqsVOko5Nn5cwI/AsGWN1oGUvWxgAAAABJRU5ErkJggg==" },
    Reload = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAACRUlEQVR42i3Q20uTcRzH8c/v9zw7YAedzk2TmYqnqTQVLTFnWSQD8yIiIiqvjKFCRSMIIh+Q7EIQEvSiizSTArWyMjQ70YiVoVmewC3YwmO4idam6Nyzbxf2htc/8GYAQESMMUYAkorNByxFhUYjJ5JHxpxuu338BaDcU1VVanU4XA8hSRIHgKLC5POvXkozoUAvEfXvCPaRfah++obt5Bd58wldrStvY5wzmEz7zz7qqO0ymuIVb59/mh6fmP3MBR5KNOjNlZWFOYyJUKqF8O07PQ8AwDD4tMZF1EI3bQWdAOKw096mhhPfVpcbiMJdRNRO1y/nD4glJYmW42W6tPfPhpyNzaM2pZL7trZknpSkizDsU8hLi54/7qnp0NxSQDM85nOJ5oOxuQpNAFPO+Y+iwH0g4P+A3+eqByoAxOTlaauu1WbZVOKmh/+YWHR13RsKdnR7VkJyOCO4HY4FQACYUsG9gsBnLp7OjL5QbVLmGlWpfGVNTmHMKDTXl1tH350Zbmk09SfrdumJiAEMshzWJsRrjixNLsD+dWWCm7IiM05VpAk5Rk2MWvRGzc6viZ7l9Q3GWDi4LevrLhU0W8riMvsGnD9HxjZei1xQL7hcM+H1gJ+LyjhERQXVV6yaJoLAjen6w5ajuuw3H75vt7b/usUY5kSvzx/0eVd5W+ekw3zIoCktSshWqeKziQh+/1887nU47/fMNbjdm92SBA6tNiK/tDi6FdidBSAhPVVVYzmmaSkvi7ybkqKyAkgEAEkCB4B//nX2saho1GMAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADkklEQVR42m2TW0ybZRzGn/f9vo9CyTrCOE3HYSDlpGQZDgTZICbTkW1RLEMFDwSdWTV6oclm4oXRC7N54bZ4sTCcMZntRHGLS7aoGykdDgcJY5yWAjIopwI9DJp25evX7/17MRYT4+/+yfPklzwM/8I45ySEAIAUAE9CUdIAnUETHgAuACuSxKHr4gUAAoCDbYS5xLnQhUjKyUl948i79ZbqyiLzYxmbTQBhxbcWutE7OmW3Xe+4Mzy7cLnz09NEKl5+9eSbG80MALLeaqrumJpo14l+IxLnKTDzNQVmThIJGxE5yLf4XexIa9Wkz/2tHnCf1jcnG1sZETHGWFLTKxVt7W3vHzKagrjw/Q2X/afhK7eHF0YBjpKilMLa6twD71nrCpNMm6SoqtG8e14tf/6bwzLnnPLykl8//nm9xZiwgE8+utR14lT/MQADj+SEImrjM+Vmy+T4TKRspzkhLjGLM3LFSRxpMhFtsb5ddSizIIF3tF8aP3Gq/2NF4UM2m0VKTV1h3d21YmTownNffFn5BEgCgh5ACWI94mexGBllAEXVu9Lz9dA9arO5fuWcDdlsFqmx8WfxsN9JUJSzB/a161szDHFRleQlf2T31HR0NeAL2aEovNlzt0UTi42UnW1sJSJGBAkAw//zrP3s3tkr9t2Tcry8RyaJz/X1j0wHQ1q82/1gnDFGAPT/hJjDUSPV1nbrj2fF579Ul5fp981oTBfb5Nh6bO7Dz+6t5mYbkxsthe8YDLxlaSmodfcst2uaNvhoidebRpLEqbIio5hJjIbHfF5NE27ZZEKz7Uz9rqryPCx7xvJMpk0Q2iIaDt+SKvd4rUANLylJo+amX3QhaGdTQ+mL8YYo6+nz/g3AJTMZ4ai6JuYXFpkaUYWzZ2Dd2fdgsfd25NofDgjAuSETZdbWsq8a9ueau6716z9cvt/BGPxyTIM3olJ0YW7UYExMk3LzK+J7BgY18/bQjplZJRHgrLQ4peRg3VMH6/dlFkxODOH4mdnOeXfQTgQmx3SuMNLiPMuaOGe/Pm1tKd1+7IOni/2BHcXL3nUAwNZ0IxLiwviz9y/93I+eTudN/1HOscoYmKyqbM55866HA3S1K3h0cPTWtr01468Vm7fkJJkMJoJgd4bDayOutYmrjvDF1UD4POe4LwQ4AMEAKIChFohxzvXfH74Z6QAKIEnpIOIQYgnAGAAf54AQYAAIAP4BwtezOsIVZm4AAAAASUVORK5CYII=", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAE5ElEQVR42mWVeUzURxTHvzPz211dYVdQUHCDXF6AB1YEkRK1rUBttSKSmB5ajdY21B7amthETJRWqdYa7WFt0isVq1I8omitihUPxIMCKogsFLmWleVc2WX3N69/7GKsfcnLTCYzn7z3zfdlBP4fnHNO3r0OQLA3AwAMBuBkjKlCcBARAAwBMB6AHYCLPQVjQnBSVRkEIDUxaVJ8QnxUxKjAoUaAYGnv6L52vcpcdK68FEBhamqktcXCt2RmzEg5cOCvkxUVdVseg7yVAUBa+oKEo8VFO63SfoyIzhLReW8WETmO0bVLuV0fvPv8SQAbtm9bXk50g3ZuzSwHMEkZIArBparKV7dtfm392nXpE8UgF7oaK9UbZxusDU2dXQCDKchonBobOiwuMdoQlxiTFhZinOyWTuF2t9JgnSoBKADABWcAkLJ1c2Y50WEi+2fyl72LqidMCNoO4BUAz3jzRZPJL2fD2mf/bqvPcZLcTz2N21xEP9HeXfPLAExRhGBSVSkwY2Fs1kcfpkxU7WUyO7uoJGdHcS6AE0IwFwMDY0BKaqz+ZvmDpNs1vVRQUNKz9A0M1Q2J4KpqR29PzzAAgxQiABwp67LmzOT6dvy4+3JNzo7iXK2GH3H2q4wxxgESRKQyxpLyf05/M/31l0cC3YDbCVAHINzo73cEAAhQpCRdctLomXHT/f06zJWu7C/LThw8uPj44tuHOGOMAEgAEJxJAHW/n7hboejt0LiJOGfM2e/Su4WiP3mu6Q6ASgAwrc2K/1OlzfLMoeRWAC9xj6b8aUt513AAKQBSAcwFsAsQNwG+auCRYbRJ8efoZC2Wrl5FQZuqZggA4ikoeVzPzEKw01oNOzU2yOfm+29Pjey2LQtfs3L0QgChHEDfvdoWS1fb7c7SMnvV2JGG+zptvio4c3HmaffJkJK4qpLG2Z8hzNbeiMkxw8b5+hmMYSHKCAB6BUDdnn3mgj37zIEAagFM87bHANR4z9hAhV5NmRCHVSkR4GfU69HXQeb6vg4APQqA8Pjpo1avWRk3UVWdkVqNNhOMEZfdLO9oVXnB8eYszlAjCXwAlp0N2rRpIw8J+XzWpOjg4VazmV2vdNQAsADA/I/fi3WSay9Z760mS+UCaq9eQmTLoK+3TmgFMJc8MA0AzhigUTgALPgiZ261q2UVHfg2ygY+aClnnlGxMvC25ruXTB1dqmREtD//fGfJLVfjnXo6lZBguqhRmqQQkESAlKRzuWXq6hXT1i+ePyayuuoW7ct7WAzpKAT3APu0WuVhv4tMzY0VMiwyXklLec63vvkKldyqU6822GYDaPNqaAo1+SS/tSJx3qJ54eO62yuw+4fGirMX2r/iHG1SgisAuLNfMs4VOlxotSm80P3O8mnBn254YcqyJV1R1TXtK1of9nVwLlhQoMEYNcZ/+KiRqvJPfSnyjlrKv//Vksu5elpKj8YKANVm62TOR03M6RSt3/3WnPeg9eKsOYmBM2LGBxuS4owjNFr/ESCCw2FHS8td5JdY24/80Xv5SqntG87UwgHYgPt9QkJ8P0mO95134eqjwmhd58ZT9xEA6NJiorVxocHaMINBGImA7l7ZXdvgrq2qclwGHGc4R7OU/7HU43HSA4gAYAZg5xwgCZDnCwgA4OO9ZwdgZQwOxoAnKxuIfwEOS0Gvatn+lQAAAABJRU5ErkJggg==" },
    Crouch = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAABgklEQVR42oWRyytEcRTHv+f8RCmhDIqFhUcyY9goNVaivBYWd5Qkr41kMWI8kvKKYkGxUCIW0p0yFmxGIXktlCiP8jeQt6YZcyzmXqQmn+U5p/M93+9RMCAiKGYQEUQEAMDMYCJEggFkAICIEBGb9QyjF0bXdAUA5aXOTu/q4UNtTeeo2auubB73rh7dV5Q1dACArusqygOAQAgEgbzM4sQxt23w+fHJH8I7JvunBzgUh6B/XhER4DE2iQgBQElRXc+F7y1wsvXwebp9HzzbegkU2qp6f80QA2AiEqvVkR8bo+KbXHUb4o8J+Z+ipcFVs2lJTIi3ZjvyyTSv62EPpY7G6bs9kWHX+nl6in0mNSl3bsS9cn67I1LmaJ0Kz4qCoYDk5BzbYMfa1e2uSF/70uFQ1+LBlU+ku235Os2SZedwat9pmWFbu1oWro+9H7K//irt9bM3AOy/Yv9B0zRl3Glrc05cNNYOXwIoIGJomqYiPs+QsgCwGAsY/8BMjL83m3wBOv2B/t0f5pEAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACGUlEQVR42p2Ty0uUYRTGf+f9RoIwh6gk/4CiCySO05AWpVktqo1BCx03EdI0XRiSUioajSLoOnRRuhAiblIpGEo0kwJREUsSxk3ZLlL5dFpUEEVzWjg6N23RszzvOc9z3uecA6kQOGgBhkyY+JuwGEQEAYwY0hIlHkMktd5KKAPgBPYqqiIyHe9EjBiNaWwdsAOYBH6mCKiqABQWlNZ3tY/+qgvcGwE8lrFwWA6AorpToXfd7ZHfmwt21wMEg2pSCAShIL+0fuTVD535oFrjvzsKuAB3zYnr76MfVYdefFN34Z6LIjIvOv/HeGDFzuLKxwPhaZ2KqB4/dGsw4Lvab4+pvn4yFSv2lDcDq+K5GWaKMRbA0pIib2Nfx0zs06DqeL9qb6v9Z6vnQBOwzJgMg5NMzMJVWlwVAuPf7vE+6GmJaucjW7e4yu+D8ZdtqwyRleVKMz5hojt/X1PkpWrT5YEvQO2mDbuCG9eXnMU46lrvDE8MP1V15+9vTK6ZoxARw+rctVVXzjy3x/tUb5zrmgQqgYqH197YY92qlwKd0by8NRUiQpBg+rLNMjocOb4LJ9vsSK9qQ6Dt882GZxNvw6rnj3ZEnc7c6uTcDMy15ViS46s90jw9GP6uPa1f9fThlqhz+Wxx+vgyzEyQZPv83pB9zHvbznaurE5ann8SzJIkWiwDSpKUFxnfwjzM342CovwPrKSDWxB/AVIc27so4FVWAAAAAElFTkSuQmCC", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAACxklEQVR42r2UW0gTYBTH/+ebWs2yYW5z2bxsqWiUtmUYCUEUEoEgtKceIgIJgp4SNMjZvcimVpvZsjShi5cCK6WUFQ6LQKWSjEK6SKFt5q2ZuuFOL7PE5qUePE8ffOf8vv93bsACGDEzARAAyN89AOHzofnw/pyIMC2ICDQrReKHFBckle2fmHAngvktEXkmVRERM3gZgL3SkNAdnvHRHgD9/pSST43QatcXPan76C6/+NQplcryAEiJBIgIcjmWSgKD8ysuN35rrP7siYpZV+R76LcgMZVqgIG83gleJJaLXRlbwi6dqjuwWCrL1mo1i3ThOmn/YHB2hfl+Vub2bYogEcIBQngNBsOMGSBBAgDiU3U7a5vv9o0PvGe+WmB3BARIcwCRW2Gx9fZ1MjfddI7qk7bWAEjwxcwCFQIA4lJ1GbW2O073905my8mn3WXFTZ8cr5kflTvG9MnpNQAS54JNt7hNuszbjZUOz5d25g8tzPVWx3hK8o5bABL+pcqpGo3+aGDgUtW7rpaaru6uJRpFWmJvj4uPle6ran3ZUBoRsSZdIVfvGRjo+Qbg62xVDlgdvdHaXDXC5QWvXKtUa88DSIuJ0p/TalJMADZrovUFtdY3Y/XWQdbEbLgCQEL+vs7MZDQahUoZf+zKiVZXl5257HTb8MrwhAsAFABWxKiTiqutHSMdDcyW/PYRpVJ71Gg0Tk7NXzbZT+GKUK3FnNcy1NHEXHL82Q+ZLNKkUsaablrafr64y1yc+9wVqU40A1D6mabpUAEA4WGh0RbTYdtQe8MEFx553Het0N5vrxrjs4dsLrU6wQxATvOsskRMgZ7JfjhkvzfA9dd7+fjBB66IiHgzALmvvcR8W2YKNLIkJ6tyOCerclilirXMBZtNriAiLzMrRVDQbgDkdbtvEJGTmQUA73/tRl/SZ1pn/6RwJh/GQtovXkcN81RInmMAAAAASUVORK5CYII=" },
    Lay = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAABvklEQVR42m1RTWsTURQ9d/KaCTJ+JKFSR4UsupP8AJGEEEts61eooCAFd9VNDKXCIBTEfVEQoVtXXVXsTkWJUSmIO7tTQYqumsRSnGHmvcm8d110ChE8cBaXe8+9nHMJAAFgADaAEgCR1kh7CYBtAAoAERGBmU/f87zVWrV6FkAGI2Bm/a7b/fRoZeUOEf3KAKDm3FzrvufdllEUR2EY78+xSZIkyefzY9VKpfxj++fu929fPwoAbNu5olLKeMvLLz9vbj4DcCg9EFZq9VurT5/cyOayBQAsAJROuu55i8haareb3GrVrUyGAEBrzWNCHAVgnZiYmAJQEvVGY2H6QqP8ttPRcRzDztqHmfc9ExGkkqY/GJjLs7PlL1tbC6JYKB7XWvP68xdrH7qdBwdeR1JCY3rm4WL77nzxWGHcUkpq3/dJSTlMo2MAJiUDUCpWwyAIKFKREYEfuMzMzatXbl66OHMdRDS63xjDjuMIKSX7vu+KYZLkgsCnXr9ngzkGkfWPQGsOw9A+4jikE2OLfm+w8er1mzOd993Hv3d21tOPm1RiAYjH3VPXapVzi3t/9jaQfnbyIJX/McUkAPEXVlDJs2oY58EAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACoElEQVR42o1TS0hUYRT+zv//d2aamcwpKdBhmKiFWBsXZVhS0sIJCWshtIyKqFwV9MKF1qboYZQuikCIFkkqLXpADzfVojYVRGgbH9QdJ2NipPTO/e+9/2nhBBaKHTiLA+ccvsc5QCmICP8b83upVDMzwrHy8tad2xvrSEpl2ECU+gwDRERBEPgvX7968zOf7ycil5kJHR0dghlUXVNzZmBw0LXtr2zbNmezNmez2VLabNs2T2azfK+vT6+vrj5NNDdLUkoEQVBxtr392bEjR2ofPX4yNvUt90sopZiZS5Ap8P0gmUzGM01N6ctXu95dv9aVkVJ+V77vUywWs+KxeGi6UODr3T3PRz597AQg/qFuNtbWnttWX3+obEVZJBqNqpmZGVJKKQ6CoLIwXVjjeR42btjQsC6dalfhZTDGAACEEPBdB2UrV251tcaPfH717OxslZJykgBU7Gpu7j1x/PjusuXLwcyQUi6ovjEGSkpM5nK4dqP74dCzp/sVILfsaWnZUXQcvt8/MEOEfCQc/mWYBYgYAMBMgsgUXTcOYNW+1tZYcybTODT0YpsSEWuVpazQ2Ng43751sxPAAwAMwPwDQJRs31u3adOlUChkWeFoQgEwWmvWWlM0kRguThdGAQLmDJh/PQAzIvH4sPY8KrpFBgKjEEA4RUc6zixcx82QisRYcKiE4u8VhrTjeg1u0YXjOBIGQgkpUsYYa206zRfOd7ZJpY4yMy1ywhz4vqiqqsT7Dx8sqVRKCQFRdBz+NjXFk7kcqUUc+EPD9zxKlJez1hoAhPI97/P4xASMMaL3zt0rgsRbZg4tJCIp0sY3mw8fPHDS8zRr1xkhAIlkKt1GRNaXibGLAJwlnnFZMpU+BSHM1/HRnoW4yiUWBPOL35AXQJjAicYUAAAAAElFTkSuQmCC", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADZ0lEQVR42o1UTWhcVRT+zn333TfJTGZiNGMm0iRtQTCKrWAtlJoKJSkdI40JKFW0rrTQhQspCqIrXVh/Nq7ciXQ5GsW2QSGuIpZ2UaxJUxujTYONCTiYTOfNu+++e4+LZtpJjWk+uJt7z/kO3znfPYS1ICEEExHAjA1BBGaGc44A3AqmtTEEZt4CYDsAtRpId1DV7wyAWSK6xg3F6TYXMTMPDQ0Pvz7QP7BVSi8AwMx3FgUDRLGJzdjYd7+d/vabT4lolJkJAEsAQgjhnHOPPHf4heMfvP/eHinlTSaiddU6ZgSBQv/+/VtU4AejpdIVIcSUc07IhridhwYHe2tRxF+cPHlxZmZmyfd937q1zfQEkTHG9D7Um3/lyEuPHjxw4OHRUmkHmKcAQAKAc46E8FWQSvmVSoVOnR47P/nzheMAkv8Zifx152MnRoaf3aGUkiJoTjkdUp2QiMg5Z1KVSkVqrVG5UekBsBtADEA0TJEAOACqWg23xXGMarUqnQ6D1RmQJCLLzA8+0L31+fb2e5UQxMeOHt1jE/O5kD4Ya+1DILjEQCqVJSLOtmRVZ3f34etzc+NEdIUKhUKzVMGJjz/68NVCR4cfRRGamlIQwtvQhs45RFGETCaD6enL5u133/nMxvFbcmFhofvFl4883tPV5Z86c6Y6MTGx7Cn1p+/5/zCzWN/T5BKbtOpa2FksFnP7+voyT+zavevrr0pdEkBTJt0cJNZiavry3A/j428AuNBg4nU5687o2bb9k769e3vTzU0BgJQEwCaxiLWG9DzX1tY2V1lZWXR3+XqeIGRasteUlE5rDWMMGmxjOTYxtNYol8sSm4CzQLlcljqOEccxjE24Tih0FKWjWgStdXs6nT7WlMstWGPkRpJ930+qy8sFHev2SEfQkU4DEBJAvlaLCkopDBYP5p95uvjazRbdZduA4JxFS0sL60gjDMMCgLwEAOssLy4t8fz8PHueR9gUHWCtRa61lTvyeVhrb0n+K4mTRV2rZc+eO//3ubM/fZnKZq8bY/wNJXu+iW6sdD6576mRkaFD90npLQFYlADmL16a/FH6Xm729z++D8PwzTAMl7E53PPL5FRaKX9g9urcBICr9YcCgH4AHasri1a7SOsdur1DG3Pvb9iZgCCqu5Wwefwn91/E3JFJ9rH8PgAAAABJRU5ErkJggg==" },
    Run = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAABdklEQVR42oVSTShEYRQ93/dmsFTEhmGJGb8vNQw1hBqpadRXhMjGws9YSEghoYlENKWUZDF5IimxVIqVQkJEVkos/OQ9Bl2L9wwh7ure2zl1z7kHMEooiiQURTJGpigkAT0c/xURsW8r/hvAbHdXNFsLy70AkJRTbMurqB0GYAMAIYT0SecSAFi6lra1wJVKaWV1bWkl5QNrRNQyu34AIJUxhtB5PUQcsmzOrm7tmzi7I//57Zsl1zVfM7m4t0JE9dOrRzqJA4B+rjEgsbSue+jw5tl38qiFJ6SMCf/y5lyQyDO+uA8ghksSTDqLCAALU2/4i8boFk+g4JMpIqjS9T3woKpMl/shWpbNGe6q/r6tS2rauHiNTLYvVA5M7Y5eEjl7Z44BZDDOdceMxuIZCWgNa6cUlelsT8wpGuzYeaD8zolDAOkhsGEsA2COc7gao7McXgCITXdY4ws8PgCpYAz4auvfj2M/HxeKhlAkIT6jYcTkB/gdsuGN4bVrBUMAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACCUlEQVR42rVTXUiTYRg9z/u6zznry/mNkVB5V0pK5MCyH8rKLAcl4Ypm3VSa/TCCAgPBz36goIQSh7GLfozQkEKCELFCIegijSKMLiIKw4StRcP+t+/p4hvxtbYLoc7d+zxwOOc55wX+IYiZiZkJAFln0HUxMyYhYCFJDunv2e+VucxbVFHZVuhZexJAPgkJAJ7Sqq1ddm3ubgBIUZeEzyeJCJBK7dn743z19Qcu9dZfBjB7iXfnxTvTzM19IxGhak2UgUQkJRdtae0cu/WFOfgiYpTU7g3mOLUDR/sfvxtk5kDvcFioWpPFTooNk6S8qqXz2fUY87nxqLGwekcIQmlu7H041c/MjTdGItlO935d1wVMJX9ACCkBYGnFsY5HoSk2Wp58Muat2NSKXNW/q3t4ouc7c11oMAyZvY5IAIBMiYcAQM4xYvz5BxCZ/sqEeNyWk8uaAjEZA74lDMoiSnAGC8urj5x42jHBvGfoTXz+ypqQsDuOB3oehNvfM28ODnx0uAv2gZmsFswjKkrxxoA+2v7yJ9fffp5YsMrblTVLPXi4e2jyzCvmDef7og6XuwFmnlb/PgkiQFG2bb90l/03R7mgvPIKgLzC1TUXDt17y+tPX4s6nK4GANB1FqkxUvKdry1e1qYVlZ0C4CIhAJutzO1ZE7SrTn/mIqWtZpoqp4nt/32mmeAXjy7KaHkY2swAAAAASUVORK5CYII=", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAACxUlEQVR42sWUS0jUURTGv3P/43uccWbUMVPGR+P4zCDMhagYRFAGYkULsVW1MSNclYomRKRkamSQFUY+JlCkMLCIChOKICES00zELMpXWDo+5uGcFmOmMpNZRGd5uefHd797zgf8x6I/aiIiENFaABEJZ+e/rYRIiBXNBADSEvmXUGkZ4rhoCI7eWuyp0u6e/TL6noQ0CWYCkKxLTC6xC/ck88xUHwlhArMAwM6xpaUCILj7+RdVPRuy1b0ZtejT97YCiCIhsClu+43GITOf7+ybUYVFXwEQREJaKWi5xE+TALJZJgeHR6ZCDVq3/Mu3MiPT951juz3KtmAe7B14N7c9LVp+sv5OjjIsuoTti0EkpMWVjNW+MZMW8JEp1CVHmrrG2xaYy19NWMIzsm4DSFXrEysLHvRPt1uZCx+//eb7QykJuIQuGe4tk/uV5jY8nTDOM5d1T1ojdmY1AUhVRibU5HX0mVoszAUPB6ZVEQ4oO3wmF1ABnU7nKZMrTh+ofzLS+JX5RNeYzT8+qQJAoHeI/uLRe72TzbPMuW2vp2W+ygIiwtLnOZPKUCoXJJvFQsEy6+L4HDBjsUGSJAmAzd1NRkEeJD5MA2aLjWRCELucPyIEAHK4eZUdr+8Yrf7MnNsxbA5N3tUIIEW1JaGm6H7PfMVH5oMtPSa1Pr4WQKCzJxPApNFofMnD50zetbufLgwxH2rrXdiclGEEkKYxJFaeau+ePTvAnNXw3KSOjK0FEAAXgy6IBISH97HDVc1j5f1Wzm5+ORe8LaUVQIwiPKYw39hpLusxc2bdI5M6IqYWQMDSNjmzzWGop59/8f6rHYvZN7vM2oQdrQBiiQRUkbHXc4wveM+l9llVmH4d2OokMchDwqsVIeFVAGJX7HOyX0RcnZdGWwYgcD2Y83AgsdYbaXmlNpA4jpBwGl+0Ydg/Cdi/ru/xc/neH3V3TQAAAABJRU5ErkJggg==" },
    Walk = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAACM0lEQVR42i3GW0hTcRwH8O//7zkeLaJUwoKSioi0xEt2MbUHIzCKBBPqwUB6KoV6CnrTB7sgGV3Ih4QEoUIJvFA6u2xuS9vZlluabeLmth50Z2rlVm1znf+vFz9PH3DOIctySfujJ1ZvILTcOzTs35dfWMs4hyRJ4JwjLS0NADjWbX7w9NlHIiLn7Hz8LxF19rywA5ABZAHYu34AYMgvKmnwr8RoVJ2c44py+ZPHv2r+4gln526/9vK14avJ6frV2vHwHWS5iDEGNDZfv7ckiG7can8MoNQVCuvdA8PBm213PTEiGvcGEmtEdKezaxzAFs4kSSIGLEUiqfzisupdebncajFrhysqs5wzvtWqwv1No7bPvprauuO7Cw6e4e5JlyeyEkPpkWP1jVebmqOJFIwjIxMCfEXO2LBJpJJui9FoyMnNxtET1cWSy2oOuh0Ocbbu/E5GBJvdgaBn6q3PN7etrKK8IO9A0cklLfxvLUUQROkSoIcF0Z8xk5EpkkTxeDxDURSPYah//FTN6YsXGi5d2Zqdkz4/58eUwz4jAYiEAoGf5ZVVeUIIWEwmLZlMLtvMllm3asO5uvo9iizD9OG98E6qIQnAYl9Pd1siEW8VuhADvc9vM8Z+J6M/tFgsmrSax1IbMzOZEAIANAkAptWJrml14g0AASDMOQcRad9DQa30UNkOXQjm/TYTABDhAEBEjHO+wDkPt7S0cF3XGQBt8FVfh11VNdVmWzQM9t8HsPAfuj0bg3GugEcAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADh0lEQVR42l2TXUybdRTGn/N/247PAQq4TRMwOBzQIGrmB/vAiw3dBULiqpvJFqeGGDajiZlmbs4shhjAZEu2RNGpZBGiWYy6KS3UbUFwHVvHoJVC11kGUsaktBTbvm3fj+OFzbL4u31OnjwXvwMAREQA8ETTizu//brnu9HPT3W71j+18RiAgnQmYLFIsFgkAAJ3I4QAgKoPWtucy6rGOv/H5Qmf8nB19TvMTJLBcOdekiQwM93dYaqr39YZUTT2LYRT+9471NfZc/oaM/P+I60DlZWVJgDFAJogSU0AHsL/qDrR9Y1HYdb3HThsBVBk2fVqZ0rX+dOe01cBbH3r/cP2wVF3csg1IXd89sXkvavWvAFApJdIjfYro+GJ4DKXmavflAwGtOw/cEbRdT74ybGhddWPdC+kmH1LcX0ssMAaM3ed6Ytk5uQ3CiEgREZGzoqsrBXBYAhKIjlnMhrXVFSZzQkinO/vDzVsf6k02wg+2tZue/6ZjYd+cVxd2N5Qv9KyZ8/ruq7nCj0RC4ZDS/Gi+4qh6NoDsixveuzp2hLffFh1Dlzw3F9Sakgw0+zsTGDa52090dH+Q0zVuW7LszUAKgUAr8czfrsoPxPbGl/Yu7O55cOy8lIxfNFxS0nKtuBiKEJEKHmwrPzx5majyzU6NDW7QIWrVucLo7FUAJi/+NtAfDmu4N0jH61tPXq8YjmawsC5/n8ADDsvOSZCcQWVNTVmd1fXWokonpDj0HRdAiQIAMlIKBiIxpOw9Vqjdps1GosnEbg5NQ1APmfrdYw4RxIVVeZ7UhrtMBlNdYXFxZj2+0O6kggYALDJlDkniNjtvHwzLzuD19duMDOJAAAoy+ErQ+d/vf1ay96Sg23tb+fl5ghNVTEy7AgCuG4AAL/POzPudtHLu3etYwbGRq9RwP/nFBGBmedcI87FyOJiyeYt9bmZJhPm5+Yw+cdYDEDIQETwe1w9xzs+rn2uoWkrA7D//JN1asLdLUkSNE2T5XjcKydTj5766uSt3OwsNFl2rNZU1Q9ANaRtmhnsPfvKYO/ZJ9N2XiKisKqqRESsKkpEU1JUWFAQXZmdjVgsSrqqRQDAAIABEAkRgq5bGQAJAdZ1SsM3Jsd/t9usuzds2lyeUhRcsNvlv274HEQE6c5HpL0GIMCMdDEAUCIWu+71emkxvJTncY/93ffj918G5wMnmVn7F5b20VVkOzNKAAAAAElFTkSuQmCC", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAE50lEQVR42o2VW2xUVRSG/73POTPSy0CnLdMbpQ4ChVqwtkIalFsrxWAwIRETxagIJDyggWCURKyXhAejMQY0gQSiEWukkSAFhELpDdtCpxc6Lb0PQ+8t7VzKzOmZmTN7+UCHCC/6P+3k//e3s3fWWpvhoTjnXAghnktIXrBj0+ZNmfPi5imVldWjnS22k4yxWiJiAAj/Q5xzDgD5b76/+9odh9MfIKIwETknJoPb39lZAWDZbEYCwImIzR7AAbAnaQCQUrhla9l9VSM/EV1paPaUVddPaETU2O0IJaSkfVpcXMw555E8AECSJDDG8BiUcw7FGLW7vK7RGySiH06f6QPwAYCD1c12z7QgKtq2vRSADMAMYEdShvWz2PjEjwAUAYh5EhpdsGXrL5PBMNnuDgct6RnfMcYgSdKGn8+eH9NI0Lv79l8AsCzr+byjpZfKpzoGx3Rbr1M7+nOJM23RM98DSJ2FcgCwfnjocG2IiI7/fm4EwCsP34e/faG23u0SRNt37ikBcOB8Vd2kRkTt4x7hmA6QTkTltjZfaob1W4vFEk1EjAOINpnjowBgbGLUqyjKGGeMkhY+nZW20GoamfLh76pKd3bu6qycVXnxTY6Rmfde3/bTW69tOX3V1uZam5sdvb/4qzfGx8c3SpJEHEBAVVVdByDJRoOiKFiydGns+sKX89LT5vOe7m7XsKP3bk5+/lzTHAUdt1t9jTXXS+orrx04fPDAtSG3jwqKNqcsenZFgRBC4QBcdx39Y34A6VZrgqqqS7u7u1e/tHHjcs6A+hs1/QCaOJclHQBXZCZJUqyiKPdt1RXnbzba3AuSzSx/Q0EWgEQZwFSzzdZ7b8SFJZnLTWuKXj2kqf7wyrxVFqfLj+orlzsA2Hq6O6fcfh3JKekmo8m0RPN6Icty373+/imF1pkTk1LjAMRxxhg5O+1THa0tSJ4fTyd+O7OipOxSTmpqKmtvbcPtW/XjjLEHrQ11Pd1dXZp1sdWQk782TwhhZIwFgqGACDKGgDZDAATnjAFCjAwPDmDar6HR1qTbmlp0LRhCf9cdBPwPHLIsQ/W6GxtqqodjYwxYtebFlQCsoVAoMWG+Jd6thjEyNOAGMB0p+zEQTXFJYkePfN5+7MgX7bKisFAoOAlgkIgAwF5bWWGfHPcgc3l2Opj0idEUtyc9PcPsdDjRY7f3AZiQ8bAgRUjXNREK0OLMLM/c6CiaUVXSQ7oGQJ8FTt6qrXJ2tbchOyvTcOLM2R0Gg4Lk5CReW9+AvjvtYwBC8mzYWV9bM7S2oDB1565d6wDGBoeHYbc1DgMYICJwzqF63EO9XZ2wJCXBnJTCjYoMTdNowNHPgqpvgnMOWQjBiKiPSYZTUTExc9cWblqk62Gqq6rov1j66wki6mGMyZxzHUDvA6/HF9TDMT9+8/XQU0YFHxd/mTaj+v0AhjHb8DTbhyf/OHXc+dfZ0hcgBNRpz00AlbNeRBoY80KEo0eGBu1x80wI66FUAF4AWgQYUZhzXq56XOWRKSSEiHiRxXRfT69vfUGI7d23b7VRMWB84j4bHRz0AfA8mg6PdgnBQcRAxIQQ//YoHA4zi8Viv36p7GLZn+dchjlR5oAgc+XVK64bVy+XpaWltYfD4cfv8x+KfAEpTDHuzcrJzeUSh725qYUCM8cAjAJg/wAOt3OpRgOBTQAAAABJRU5ErkJggg==" },
    Drive = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB4klEQVR42nWR30tTYRzGn/d9z85cWzPPGHhWGMfdOIgyt3NRygaGRAQLbCfLKxG86DJvg4SgP6BCCAqFLpbMRr9gRDdR+WM02jK1Vgtx6CyXpWtNzhl23i6i9QN74Ln5wMPz/fIAAIaGQHlMY5xzWnNMYwAothHBf0QIwb8hAgCy23n09LG248460TRNDk4JKSyvFkcTM3FCSJZRINodYafGx03S4BA67l7quRfs9ErQDYASgANgIm7fSea0i4/6AEz9bASEcydbB4MBuzR2bSz5uqBPixbBWq3qxuH9TZ2RE4EDcx77/ee5YmoinZ8cebx8k7wd7vogiWWXeyB5BMCzP87dFz3bfDXU5gl45AYHqIjReOopOx/ecyG/tGo8nPv6fjCsnKl8K0krJT4LoJiYL+8ofKo0jsQzuXafy+WVIJN3V4Lrm5VN22dDEEK+ejad/cKjEx9vQRBJX2h35KBiszx5tVZy7bJbbVtrOrnevzcfCbY06cTO07NZQ/W31gnlRVCrAwbdiRcv56uq6hdpaQHxyYUlIjutXR3NWwPd7V5NbZExlckiMbMRhfkd4UNKr+rzIJl5gwfpjVhqxXKjNofiZlqP33JZaXRov77+zWw1Bg1gnP+9Nucg2zENYD8APOG4dztKUicAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAC70lEQVR42q2Tb2jUdRzHX9/v7363225zXtNxv7nWzdy5qTd/el25zIwsQmZYG2YWuf4wGFRI9MB6MI4e+KjI3IOQCsWkkf1BIhY4NVCTsWqrEdjUbbqzybStTXbe7bzf/T49uPWHQfWkN7wevXjDhw+fD/xPUfF4XBtaMR8RUYD+97ZS/+Hz/GNXhODqO8tfsFeGQjnHFTTgCtowmPptMvnl2eFu4JiIoJTSgPyBikajZmXhdMe7rze1VVT6QQTUnFZAVnPy677JtreP7xkaT+9VSqEViAiu5Ad76Mw7T350X2xB+bGub0em0jplaAyFwnGc3IpQmVX/cENZb/ePE6/sP/1ez4WZHmAQGFYK4akHQp3uiedlYE/kBrADqAKqgTuAJSU+Wk622xPS2yry1U4ZfP/x1JHd689viy3aD9R4GtcsqlPuOB+fTnwjsu2TAvPznIj8uaSZWTm0veNn75tj11vX1wYqaoLFweWPVIYftYvCnr09JZ4FXtckeZPRqexlpT6tCfhYOzXLOETPGLo/6zEUEzcyHzx34GoGrt5bauK+0XypbtczsY3NdqHtSWdRTsohcS1lv/Ws/dnWhorlF4dGkrsP9R3+6Tr7AGXf7t21r63hiWVWke9wV9/5gz3J1ItNDo4LnuytjJEWS17buWHNhrrbCkfO9bv3x+5Z2FEceHkgkW5EcqxdUb20vnSC0bFRXtq+MRapTWTSGc1sxtGGT2e31FssC1ctNpO3yB3oHroZCIZ0bZljrLYIRCwjECxfzMDwr9kvfphORsLVZkXBtDn2yxX1Ye/M9wrM+ruW8PTScnns1aZI2LIsZicTHDxxcfq7y9KFm+PucElj6xZ7ofZ4uTJ8jo7j1y4MTXqO9id0J39dqH/Vg3UFne2b/YMt6/yn8BY3zx0rGIXNLeuKTrVv9g9uWlncCYFVcwYAHY+jtQKImuCrgkApgFZ58gmU5h2mVhCPo+c/mdYKDA1GvvR3qY05p+e53wH1BxSj9OXsVgAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAED0lEQVR42q2Uf0yVVRjHv8953/vCvdyLlx/yYxIJkheaIIRiCOiAbDSxzeGPOYtlzX6utRVbrracrWVbDf+wVdRaf5izwqUxa1kOqqkMid1ZYBTKLyEuV8R7L5f7Xu593/P0B5DJZOXW2c7O9pxnnz3P2XM+wP+86D/G5hffCVAQkSRaHCWZxRyU/xUoBEFKBgBtkVxJRAaBIRm0GJQAEDODiKrzc1K2ZKYnJ5imeUuyKgS8N3yhCz1jXQBaBJFXMisA5EKwKgQxEW3Yt3v9Oy/v3VTgtBLhNn0bEUZ7V/f1l949s76zz3dAU2nIMBmmBBH9XTFTejps6Y6lje1NTzyl6cPcP+AJRk1S/smUUnLaUqfmLCiyjLi79a37W47+3B9uBHAVQFARBObZp1DHxrDhYH3xRs3u5x++c1+tfvvKe4pC16ISAgALAZJRmPnLlMJPn/c8UlBdlnj8tYe3H23tW9V52Tt4vnu8xxsw3ADOEsGP3AxHk7+5Pmx8Vsabi5K+AOBUFnQ8V21CVmrsoYsHVwe4bQdz++PMZ/bw6NFdMy2vrh0tyYn7CIjJVrauS3tuW1Vq7sWObl9Ds/+wKswOEgRBBFOCLh2A0jM7BKEbQe2Xk13XVdN71dRHh8JqcCzmLkfY5lqz0lGdOuP6yj3BaqqDNJZRDE3qeqyqDoaNsB1ANoAQ0fYBomYTDCEZqqDQmMd39/59J4Y2AnABNsfm3L7MxidRtzInOemhvMuFajgCUIShKEokbITLNhUura8pziiZnBjXP/mxpfVPX8ohomvjAKRka1pGoueFZ2vzy51aRDvZPuL+ukcM7B2XgZwMTrRrJFQJAAZ4xDsVU5HnePRYQ4UryRokxKzAA/d0Fuz8YOhebxCnACDFHqo91lD1YHmeNQYWDXX3OUvq3uronZg2rcIgRE2Q6gsEMD1DVFZ6f3JV7fIUDvbSwSPt/rxV+ZaayhrbcWfPlihiq1lGYXUk2lYv09B84oQ+ELBGnnlsx5L3X7S7EBNv+m70UyBKpJ6+FHafaruwpjjLES+mFYTUeHnOY9ctWQnsGx+2pgkvKRbNBinBMohQdAX/Pp0003XdHt4d8DksukeI0JD6Td/k1Le9wk2ALS0ujnflxBuVZS5LRUNdsVOxJgIRPwb/+BWvnw4NBHXZDgHEWczSN3a6sjKXZ8MwTOie33D4e4/v/AD9dGWK2qb8/Dnd/OWpcUBgz95yero0KzYzFIlGv+yGu7VHvglMn52dyLjySpd8ZVtRbFGsIi0dwzz84TmzCXL6YwAhmpfDrLvAJoMI1rUQchWkqgNGh6CZ/luUw0uygZl1EMIKyd0MvVMhsGSIhaKYB4PmTkE3jTS/5+PzOQs1eDudioUevJP7vwBRv8jwQuvnXwAAAABJRU5ErkJggg==" },
    Sit = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAACBElEQVR42k2RXWiScRTGn/P3nR9jNtSLaptLcctllLBqKCv2oYu+oGhgxChiMogiVwSxIMquAi/a5W7Fm67dGgwK6iJYEXQzaQRLLacD07Vpe99p+p4uei/2gwPn4fldHDgEgAAwAAMABwBJy9C6BoAsgBoAImYmIuqajd6bCwT9fpNOEFjziaA0m/zu7YeP09G528y8LoQQHL5+buL+g9BFp4UElE0d1bf0VN/SQynrHDaDiEyHLoSvjUwIQSwxM9paW7yq1FDvPn75PjH/+REAvXZS7cb4cCyeeHbZbJSOMwPw9btCqcUXMpcW+Ovic9nZbQ1qMpzOjuDqUkzh0gKnkk93fF57SAr6Dp892mc1LSeTZX/gtO3J5Fg0XaheAhpwOQ6c7HNbjcvJZNk/PGALnHKOSaSqUKtVTn3Pr3k9eevkzaFBgAfBAEhAXs/ySqa0NnCiYhWskqTsNoTaBN58WttOzH951dXRbq7VG01AwKAXuh+5zWq3w24LXz2DP0qNpHRuYyNXrNCdW+NDlUr1t75FUrGHv01V7DO3W9I/C5QubBd0q5lfmVajOH9l5Nj+fC7bJss7umZNNjVqsmlXqRoNEiz97oPSbHzpW/z1ykMAgKe3cyoWGS322G0zAFwAjmjj6jlkm4lFRoue3s4p7Hm/BMANAIIIRADR/13DrTn0Dy9LygMKTcB8AAAAAElFTkSuQmCC", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADLElEQVR42o1TW2hcVRRd53EnM2NymzQ2bTpxMhlia6ttJ05TwZYxFtG2vooam59AjVXED8Gq0YLt/bD6oUTB4iNgVVpBMEUQVGhsRixaG4ydNAWlQvpK7TSaSeaVe+/MnXO2H00hBAUX7I+9WQvWZq8NzIExhv+L+Vw21xMRqmprazu33HvnHT4hpNYaAJ+jaTDGWUWryuDQ8MlMJjPAGEpEYCDL4kRgsbU370kd+7hEpRSRlyLyRhdUisgbo9TR98tta1pfJgIjy+LSeH2/Dr5jLu579YFHYx23+Ua/+Xb8jwtXHS6kIBBds8mYqnh6RbQ50Lbt7ujTj3c8ZpqTHzn2/owEAfl8vgbKvVEVp+ipvQeHR8bO7Qbgm782gPKGthV9JzpiLT5eWVIoFKql4BmxN5GQxWr20jM7H9q2PLSUGXY29Otvl372PHVKcJ6Xgud9hsgta1i08YUnH+yNt8cCsLPm6bMXSlsao8cBYFPy8J5JuvIZTf/0pqK/vqDenYnvANwwz0Fw9xNbj9LfRyjzw2uKJo9Q8uCzVwEkZE3QiK4O19alz4zZ+/qTv3/47nNt929aGUlPzb5tVAU4OOA5jn54861R7czoV/o+T+17vvuW1c11i2tq/BEpBOCWHG4octNTucsin4knNq9vTdyzvhXX70107aTTk7g05UwIUIvjOH4BQCoF2G5FG7ocOPbL5dNvffA1RRrN5nJFVa4Hhojgk1yOpwvnvx/5c8xxy/c5jqcVAKm0gltWuuQp/6IgNfUeGEoCCADQCwLIAcw21Adut8u6ynZKnlIgabv6/OiZs9ntW+9q+PLAiz2kXKoO+Bylic9XC8500fWCosrEUpPoq+GJnG2750Q8Hk8P/XiqPrK8buOqSIO6MjEuprN5OVvMyUI+JwuFnCwWczI7M2NAl9FyU6NKHj8h3jg08l5L6+xhCM4AoGnXIxsunvykh9atXDZocL7DNP1dfr/R5fcbXabp7zI4dqxbFRoc/nQX9WyPXwTQNKcFsyyLh0P13e1rw/0wgrH/fEPDiLWvCfeHQ0u6LcviAP79hzsBgc4FwwFgAFALuf8ATtx6shHExbkAAAAASUVORK5CYII=", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEFUlEQVR42o1UbUidZRi+7ud53/d8oOfolg4zZaVjdjI2EyJXi0lr0SmX5c4Q+hHzR8VgRFGwWjCilT9qP0ZZEK22VhRzZ4pMN3GQNYMGfW1TaX7gyanTY3PnHD0fnvd9n7sfHjeVbXTB9efhui+47+e6b8JykJSCCQQG404gEJgZtlIE3BTTMhERmLkIQAkAIyOkFV6LbyaAYSIaZWasNCQiYmau3VX/7GtP+7fcm6VJBwNMKwwZYEGguJU229vODn3d3PUJEbUwMwFgDYCQQihbqfLdu55/q+nQ25vgzJTSbfplBjQX6p7ZVOR2a46mo6cHpKA+W7HQAMCybZJSbmzYudUHjvHxpuBf5y+GpnWHQyplM/OCNRFYCEnmfNJ+pGJ9fqChfkPDC4/7Pj/WucGy7X4ighYIgIhIAXC6pHIiFqEPD5+5dKF35A0AMjMWXjIiBqDKzw8c3BF4aqNTKqdS0i2IOBCAEMETsAHke7zuGt3pctjMWHe39zEAZYYuw1KKKSlFOMMpQ5dhAGXri/M3KzKg62R4cl01DKwJnoANn89nFKzJff/3lsY4T7YyT7Rw5M8mVffkhq48j6NElwLM+wXzfqFLgTyPp6R228Ndkd5jiseDzJMt/Efz3kRhQe6ByspKHQDW7du9vYejrdz7w6uptkMvxfhakH/68uUwgB2Z+DgzNADs7P5u3xRPfsMtH9XFLrW8m+KZ47y3YfM5AKUagOyi/KwsJRJoO3e5/7PW3iv+56prSgq9+rZH76/TNFmzNM6WOW+UFuYYdnSGd3/c+eOeF7nYt/WBjcV57iwA2RoANk2LhZlGtksmXQ4RlakYFZaU5nQe3lMPLEni4tcICSSvwut2RrPdRkKY87AtCwCgAYBp2UDSBBHpQyP/jn1xtGOwqrzwnrRpMxGtiCDDoQv82h8eHwxdG9MEypAwMW+qm4a2YiCZxvVo0mC2m19pPNMO6L7Met1q9TTA/BvA3Ew04UfKgmnaNwztaGxWsSnhdjkKVnucB1at9lxKpa0oGAK04kowSBCUpmmlsUj0QW9uboE1G8dsMs0AlAZg8txvg6GRoVBFoK42v3pLtZ847RdC3PHaKGYIhwfZWgrDAwP4pW96BMCEJEI8NBGJj1+9WvWQb22OjqS6Hv4HibkYJeciuBUTs9dhpqLKm3OXGh/po8Zvz4dO9wx8QIQLGjMEEbUHu4erap4YfqfiPq9889Pu3tGxSJvhNmxr4d7dgCYEpxNpubZo1fYj760uH7wS4eDZ/u+J0MGMheOgFJPLpXWc+vmiv/dydn5fKHIkFY8fRDR+25ajFma+Otnz+uh0Iux0aqeSSWtZICjDCgDVANxEADOICFjKxTcA7oy2Ykn9cggiSEH4v5CCIFbk9D89D+Pbb2cOJwAAAABJRU5ErkJggg==" },
    Charge = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAACDUlEQVR42k2QW0iTcRjGn/f/zcNMW/VlWRs12kRaxlgZBDUXw9yiYNL4uimLiq2DXY0UNULWZlB33XQgg6CuJoI3iSwqQbMQBPNUFyOTHOxQNkubrbW3i9nhd/XA8+O5eAh5BICcVltudu+rOSfLq4u+LS1nhsem3gyPR3qIkGTOOwAADikSAHicu2/y6GPmoS7mobucfn6bH/qUIQDVRAADJAGAv3saggjL6e8JY9FPm0G/Tu7r7ZtIJJIZl9tabSlT2Z9NfuhvfnR0AX9QFEgr8XDi/nkeaHbOADg4eq1hhJ+0cIOpvA0AVCsShUKcIyKhmDfZ1aWroCvJ6iVA0/RgoPfVNo2lyW70MnI5CYBgZhARnzBvDN47VdNSGB1DWZnml7vWdEzMRysW43E4juzVVS7O1hEzExHBvWN9Z9dJS9uP6LuFWy+TkXZlv6U0My9YvRZpKsjEIxOF7S8+dQOAcJnkQCxQx+8v6FKenSXhjwHn55mLW7PODegJNxoycV8V12vpDtAh4KiS/ZOtNh4/rUsd364Ov71a/2Xas4UP6SgIeAtcetXl2s3SdcBYJBGA7jN7kiNnDUuKsfjp69b61HCjjq0V1AkwqejviRD5TGIulkh/LZSLvY5d1lhkSuPrnwsOxnCFmZBlCO6ACCmQcgwCwKhcIy4FDpTP3rBp4maZ/AAT58v/9v/xG47+zb0jZAXpAAAAAElFTkSuQmCC", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADG0lEQVR42o2Tb2hTZxTGn/O+N7np9TbNne2djlHXWAeVrI51Q9uuNLZFS+cfhkaZoOJKVJx2g7mJE70URFc39kHFGoV1DFG64GbZl0o31+H+6LSFrcLcSiWDgutK0jiT2MTmHj80ddHB2PPxwHOec973dwj/lgTgLynSSiGd2VR6MptMTo4BGAQQYwYRAQAYACjfSERZIYS/29p69oUqn8GJJKQiaTQWv9N3+aeh9k8vdgI4n2vCAKDkR+dqNFtOuspKn3AhEkXqbvLePG+JWVu9qbF2wdzn1x86V0KUDjFAlJvioRggtiDcqtg22LExNvXNEfvI2qpvW3xzTv/8/oYoX+vkS/vWREs8ro1sWSIwve4jImYmAGJ15VPH7C/e4avvtUwA8D+piS39e1fc5r4DbLVU9H8WCEinJIjHO4TDJADY126N2akUw3RkPIqqVoyl7K5Q7/UvkYij/hm9bF04vDKT5QL5SLoF8u0k29REMNzWvLu8tMilZhL4bXjE+DWapZF4xg6WKy/5KrymzxCvTmXSz8p8M7WTbaoc/LytsePlsqwx/FXv1CyPgXXN9aWBhYWrxN1owSff/x5fW1c597kyh5Ia/cNL/5hhmyqC3Tv8HX7vlHHl0sCt1b2TN/vbapsqTOlEMg4UzMbAuJ2uMlJqz+VfeNePohNsTb9DsYrgxV31Mf6whvtWFkRcCp3qf7tphD+o4QvN6p8tT+PmxMEG5qPL+fxy9X6hVrj7IUfFKlp7dtRN8OFq7mlWI05Jod43GyJ8uJrDy9S46Xa/BmivdDa602eWzWKPpn0EAMwgFDrE5jOvV49nDtbw2SZnxCEpdGFnQ+Re+xLuWuqMGbq+dRpTAE5tBaQemP5uEADCWw3zr4zur+MTNTTskBTq3u6P/LVvMR+vc8QMXQ8CmFmTZtjP51/xiPt6MiswlCkeP9m6qHFx0d/zur4ejB+64dpzJ5E4zRYEtYNzxyNz7Nozx4QqU/n43PoF9sC79fxdcCEfeNExVqTrrQBg5SX/h9zllcWy6w2fMrTGK38QLm0zAFj4X2Y8ABZ7NAYyU7OAAAAAAElFTkSuQmCC", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEQklEQVR42o2UfUzUdRzH39/v73cH9xjBcXI8Cudxd4igFpFMIVN5MI+HzK0tRWqzNlxREqsxwRw45pWOmS0tW23Nstaq1R/GsOlcsFNTeUjhYD4EBSgCHtwJd9z9Pv3BYUKw9fnv8/l+P6/t8/Rm+K8xAARABcAU9AHAD8ANYJBzNkVEIHr4d07yHJ8IYAyqFcmJ+3ZuWbtJGxoCAmde77R/6P6Y++LVrt4zV5xNAE5zxtwSEQcgzQLE+UCZyCVAii1bZ9myp3KHBUP3gIAHUCkBJoBGPdk/Np0rqPj4h8z+e+5DnLHBR6HC/HoDErGjRyO8N/4aSsjWTlv1EWFyj7PT9/1P5zoHup3eaAVp03Ke1uYl6VKbL3eHjbi9VxnDxALVPjTOZ56irIbHjvV9Uu4O/HpQqspPPQtgV15qzIku+4suunCUnIdLx01LtI3LwsO1wX4uDpVxDgDJb220NFPzfmrbW+BRK+TbAEQkR6qOdzU8P0pn6+nLsqduhwjYRLSPAxD5IkDy1Uhc4Kzn1KWbo/6hYUSpmFIhFzeKnI30DHvqa061nsfYKGVEhYZ7AzyB8/0SB/x8kbVhsjomBSQqeS3bspb0cRTiG4c/ICX6JaucM9bfc8fVPfV3PzMmJyheXaXZRcRrJWhMwkIwkXPJL5Ht/a0r66pL0pcJ/VdZqD4WBu9d7aW+2xu84NaBcdw1y8cMq4w6Q0FGWkxeDK3/c2TMKCwMk2z2QuuBKlvKCnS14JvWm+N6PiVmbXhWvTNneVLRUqzzuEZZXcvoSH60sDTebOTxU06cuTklCgvBGraY69/ZbEmD8zccu+Jqfbl54vJKgzIhNS5Mruq7yGKNcciN1ySaI0Oj16+2KOTdTbyyacx7vN1/aBbGxZmp2uo2m9vpw2KarlhCh7O1DgD2xhJLi+9IcSBQoafKlSGD9jXyEd9HL0h0opQCr0fQ3kz1DUDzSnDdwIUgrLbA1O5tLCJXeSQ1ZKkdAOwHbWaHt7GIJsr1VJup7ADUxY+rZN/1vWGiBxUxVJ6umARU28UZGIfAGADY3s01dd7/oJAGdkXSe2tUDgD2+ufMjtlY1ZOKDkBdLGNASIgyv2y5ont7inIIUL4tzMCE2cXO351j/H3YXki9ZTqqzpiB7ctPdgwdtFFvmY7eXK1oBzQ28d9EAFojoDHz+SKTGqU+eaU6d7qtNCqw5wmlA4C9Oi/ZceuAjdpeiqDd6aHtgMYmzJYUHKDAgGBszrmJFp1MpxEl8fQtV9/hy5Pnq3LN2TuyTJkDHS344vqDjk87ZXsFNvFzgMCD2kcAEPTxqHQBgMADvuKseK01KsmsfMZqSMwx6VNGrl/AZ9cedH5+TVazEGz2POeLKwAIdydV0rT7jtmo8BkiRV/Ybecfvq+cvravnaxWYJ7FYIvbNkAA1FtNYcK3m+L4L0k6xUlAWcDn9ux/2z/oWMCaWITezwAAAABJRU5ErkJggg==" },
    Light = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB4klEQVR42lWQwUsUYRxA3++bndnVJcGEjQ5GS500L0mlVGfFQ52EDv0N0cUIPew1CvsHhEAqIg+dJdBUQvRQ1gpN1orrIajDzo7muDuzM9+viwW983uXh6oKkJ+euf/8e+1TEIY7QRD4zSD0m2G4E9RqW8HDmXvzQEFVRRxjyKy98Ln69uPgwGDPxub6see5ApAkHR25dqPb96uHQ0Njlx1jdo1VBehLkrjYakXWdY04jojjiLiukVYrsu04KgJ9VpWcCKhi07RlikWRnlO5pFDIC0A7Fu3uNl1p2lIgEwFjjAHw9/Z2N0U8Hj2eWy2XxwfL5fFLT2bn10Ry1Pfrm4BvjIFKpWIA+vtLt5rN92l1++X+xMTI1NjY1anq9kI9PFhN+8+XbgNMTk46AhgRsap68Yv/+kOj0ci7bj6v2iFNnbjvdFc8MHB3WERqqmpynOB5nhtFscRxGq+tbdVBGR29cvb3UUs8z3M7nQ4A/4IkSTQMj7DWysz03B2ApeXh1WYzIkkSFZH/A8AcR7Fpt48yoABweBBhbWIA+SvlAEQEVQ2+fttt3Lw+fO7Zs8oiYiiVenverWzsA8HJfnKAzbJMROTni1eLT9NO58GZUm8REZaW138svFmZBX5lmRURsX8Ai/LprtJg/kEAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACw0lEQVR42m2TTUhUURTH/+e+93o8m5mgMB3LXERUg2kQhlgGGRH0tZuF9J1tylXQIugDsmUFbqJPKdoUCEGLAonKTVqaREoFWSJUhmPm+N7om3nv3XtazHPKqQMX7uJ3/vd//pxLAIiImJlLGrdubms93rIzFrXAUCAAgAjvApmZLG7cutv1rKv7rBA0oxQTAGiCCJppbnv1+rHN7DHzFDPbRWeKmSX39D60NdPcLijfqyeTSXR2diIWscorK0uj6fRg7uDR0x+lhC9CSilmXYdx9/blRFVVeXRhxFpqT+aQTCahp1IpAgDTNCqCIOBotMJov3JujaHrPv4qP/CNWGyJ7mSm2DSNCgBIpVKkzwFKKhD5pGkuW1YgBKkSxUoDAEFCGguU1DQPRAEpGcYTlhY63fqy557D/I33H9z11jBES7wq3hxfHm82DNGy78Det8w/uPfVHRtAkxD5DACANCEAIHK4Zc993x/mkdFH9rIVZbvmXiirKNs9MvLE8f33fOTYngcAFmqaAPDHiQhFNj17fnWM+RM37ajraNhc27apcd2Fpu31Hcyf+UV3+xiAhpAVAFDIgATBMq3R72O/0sxBXBBX37xxppnZxclT1weZA3z9NpG2LGvU93KF+QsCzIDrupqSkohmEHhSZTJpAAGkVEzkwvcCcl1XD+3PFwAYANjNeux5WQhDG2k9cekpACwuLV0ZBNn62dkcz4GF2VFUuZzPjjOLWKTEGRgYPj8wMHw+tijiOM4s3GyOi/l/BDzPh23PYHx8sgCPj//kTMZFLuvNS75ohPw+TdsZklJgfe2aRLQkdk1BUU1NIpHNekhPOwzA/5+ACgJJRDTxoru/p27D6rWH9u/dIpXckt9Ewrt3Q+jvH+4FMBGyqtgOEYGZsaquPnGxfuPqal3X8v/AD7jvzZcPfb1DZ4jwmRk0F+Zvj45km4w4RaAAAAAASUVORK5CYII=", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADt0lEQVR42o1UTWxUVRT+zn0/88CZNrWlQ1tLrfUnEMumpBJp1OhGgtHEaCIaF9XYuHBHrCYk1YoxLlho3dioERcQERCLxkhidKEVupCwKESGVmwd2k4ytsObeW/efe++e1zMFGZKMZ7kbu4957vf+c69H6ESxMwgottM23lt8OW9j7ZtThs6VlgvSAjkcjl96ItjP4W+/xEze0QEALyaI4QQMGz72WPHP8ky+8wcMHN0iyWZ2eMTX49nDdt+RggBAAIATAAgIq21Rldn2/179jzSodRV/evk1BUpIxARrV5LAJiZEwkLA7se6t79+EDHHZ1tvXOzc8eJSDNzBVBrXakjbFSRZNaK9774ei63mF8wEzYxVyCJCEqGnG5rbp/94+c741iyILGxFsOs1UaFUU8ca0qlbhdXMj8+aJpWWEMQqDAkpSLbcRq5ULhGYRj21J6bVQErRQLEHAIoQsqCVsqwqp3WRRwr7Tg2geKqcjcwTAAYGRkRo6OjuuiWfi8WC082NDTS4Csjs2d+OX+6oaUpHwWRCQCWYyk3v9K86+H+3UcPf9zjuoW46HrnajGuT9kwBAAMfHborQxznqcvHF02bXt4LTvTtoenL0wsMy/wp5/vzwAYqNaKuqfFzDQ01Gel25rfvTxz8hrzPO9744VJx3G6qsnCcZwt+4YHf2PO8szsl266I/1OX1+fxcy0njTCNA0AuG/0wKtTWi/yxKn3MgCGduzsPbhjZ+9BAEMTpz7MaD3Pbx946SyAe6o1om4oNwbISCaT/xQKJZeoDMexBBnmYye+ev8JZh/ddz333YYNJhGV4bpeMZlMFsplv+6HmGtplkolQ2tNQIhi0QdZppVuTTrMFsgUlucFBISIophKpdKq9rglIABWSgEIoDVDB0H2g7EjFwkCWkZZANuBMqJI1TH7L0CEkUasAriu5wA4/ebw+OHqUUux6D8dhgGiMFrXOMR6m0op+GWJciAFAGVZ5pRtmVMAlJSh8LwAYaT+P2Acx/B9ibIfIZFIKGYGM5BIJFQQhPB9iYosNzdd33LVA6SUXPZDBsdKSnnv9Tylug3DUJ7ncyTXZ2iu+fgA4F26NLd8dWGJ+vsf2Dw21rQ/kLEgYti2rbZtvTs999c8zfyZywPwNddTNNYQJCKES0srFlG0vatrU3Nn56bGjvamVHt7U6q1NdWYzy+Kk99MXv7h+6lxIj7HXLFJ1HjmTQ5fZf781t6ep7q2tKQEkahcyPrv7Io7fT7z7TbgyEUgWqviv+FSAPgmlognAAAAAElFTkSuQmCC" },
    Dying = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAACJ0lEQVR42kXKT0iTcRwH4M/394pzkzU35+Y2J9YWRTapnCb1JiFRHSoo6BJKCKLQofDgqUipQ7cKunmoXRJSEPUQdEjdS5b2Bw9LR1bEO2Pbu7m1zeXet+193w4VPeeH8AcDoAFwtPn3nesOHGhTVV1fjnyMrH778hxA8t+hUYDdIdIMHNf9aHDwwdlA4IjNYAAYw49SCTOv37wbm5ocychyWAOIGBE4XT8YGhp6caW11T25tPT9bSw2TyD9mN936iLPe56Gw4n+iYkzKlEEAHCD50Pl0VH9XjA4D8CL/7wPe3oWlLEx/Vog8BgAOACukfb2u+VEwjggvJoZ2Os/LAFkMZn39Hq9l+9/eJ887/UGjYpSNy2Kz6oAWGqLRfN6IqHePNTWN9zV5Wycne2vdrkx3Nnhcu4UpY3NTXVXsWgFYGUA8lI2W7DX1BgrSckgRaPIbReRkVKUXFsDk2VDPccZU5lMAUCeAUguimLYZbdTWtUKfYIwxzxuVdHVylVBmM253AVbuUwvU6kFAElGRHpoa2t8NZ9XjjbU1y1WKp95s9nFm82NC5r26YSjwbocj8sTpdI4AagiADogbqTTue6WFvslMcZfX1mZBoBen++kkeNMX3P5LZhMIu3sgLsNMAEoxLNZxWexnO70+5p3O5zW9iZP8/Gmpv2RaFSdktK3sr+UeQ0gAkA6AAKoo7b2SY/NdqGaMQ5EkGW5IuS351ZKP/v/HvwG6/Dovt5748wAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADYklEQVR42mWTX2hbZRjGn/fLyf+kScwirSboVte60qbMdmUMQWQOR5eyrdoiiliL0AmuMqpSEc2GA+1ApjDolYwhZTpk6M1GqhPchktlNXboXOdM1uKapmly0tOmWc5JvteLrZvo7/bleS5+Lw/hPkREzMwA4AEQhhAPCYCllGkAvwFQiQjMTAAYAOg/YQXA828/1/PK060t4UBNjUcw09+5vHoxkfjj07NnPjek/JoIFWYQACYAxMwgInM4GPzgSF/fm882Nrq0xSxuLmTBRFhfV4eawDqcuRQvvvvlqaNXMukPmdkgIiAKCEGEoNe7/4fh4ZIxMsJfRLrSO9fXjwYc7lcDDkff9lDo2Ik93XNydJTPDQzcftTtHiQA0WhUwCQIAB47snvPNePQQf5s69YkTKZd+D+dx7Y/c6M6MsKHt22bBrDRRHcN1Dkcr13e97qciESMdRb74F2Jtf8K1wKo8QoxmOjvN+I9PdUHFesAAAgAaPb5G4OGTolU6mahYvgOd3TEhjdtijlttl6n2db7Xlt77GBz8/iylP4rs7OzISFEi8O+EQAUADBXDZtJ0ziVzcr++voX9re1PV7J57Fway5qqavFOx1bmir5PGZmZjwpTauYFIUtum6/VzCvLhUKpVUK2Gy+eTW3UkgmIVUVFcYqFzTWkknohQJ0w7AGLFZ3bnGR0oaRBwCFiDBVLiXi8xn9qQ0b/MfPX0h9FJ9YMBGsPxp6Xqhl/nhiIlGVUp+yOzHk8z4Sn/zLmDZRgqprEuDxdbvcscudnfJ4U5MGRRmCEAe+6eoqjYXDtwFxABbLWyd37NAubN4s99qdMXg8PgFAvA8IkKaeXln+6vdiseIhcnsrFWe7w/WweS5tc5ZK1iccjmCNrjv9QrinVNX4tlw6iaUlVQJCOQQQS0kKUS5bKLA/FKruzmQiJ3Lq94OTk0cVs4WmDb38RktLxDCbq+pqiRRFyZd1nXoBUgBIQcTscv10+urVc/tcrp3dra1b8r/8unTL5bomjTJ6rLaOroaG9uvxOI8vr4zrFssloevMgLw3JgGwBBp2ebxjL7aG26tEd17EDDabsZrJ4NSfN37+js0vC335usT9Ma0hCJAOm+2lJ4GhB0wmq1w7MJBjWT4vxCflYnGM77iXAPAPBwyE35oOVcUAAAAASUVORK5CYII=", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAE0UlEQVR42m2Va2xURRTH/2fu3d1CW9xun9BSWrotbaEWqIJAyFIg2EY+qGnC44NiBLEfVAIxSkSIMSomGA3SbxqgRAgYESQhiikPW0glQbCtbG363L7udst2t/ex3bt7Z/zQbQKVSSaZTM75nTPnP3OG8P/BiIgzIlicSwAWAEgGQABUAAojigsAQggGgD/uTLNhjIhzIeYB2FxZVORZt6yiPCfN6SQhMDo2Hmrp6OhsGxxoAtDEiFQuBAEQTwPOwMqW5S48cHDn9hpPWVlubkpKwp4AxjASDqOp9c/hLy5dvuoN+L9mRF7+WKY0C7aspuLZo9/s2b25xG53dHd3i3uDQ4GBcCgIAIucaa6qosUZxeXlrKOrK/ru6TO/3+jvPciIOp6ACiEoFUhfnrewsfPol+bk4cPi7NatIy/k5Z8EUAegCsBKAK9WZeV8f+7lV0anGhpE2/795oqs7FPzAJeYPjrNZAcAu86/tTcQOXRInPR4RmC3HwTgkoggMTY9p+3SAfZRY23tsHnsmDhdUxMA2K4EgyGxSPYUFp4f/vAD0VpbGytIc50QR8BkxsASJZkJLDMGcQRsYdLcE/d3744N7N3L12dmnQeQwojAEg6F6/PySp2TKm729A70TwR/ok+wOs55PQeqE6oILkR1nPN6+ixp9eCU8fN1b+dAhs1Ga1JTSwEsIgByQm9XNpOc0WAQfaGwD4ytO7xq1Y6NOTn5Vx48UL5SlE+ZaeL9quc+rs1dkHOtrc33eW//ud5H4764YRRlQjgBuCAE5ITKMiKGJDQVo5oqr83M3lDvdpfrnOO94mL37RHlNVtWNvYtKXHrnONtt7v8mm+w2m/GJK6qYIYhQ3LIsKIzJUJobGJCJ2LIkiSnaeh2fWgIUU2D6vMhyW6PSIYemdnTfD5YRLbc5BSXpWnw68YkmBQGAIkBEEi2Uk19o8ddVOTQNPnbsbGHCIejDr+SfHFS67mgqnf649YjayLoTFL8SZc11XtJ04YPrV5VISvKnB/8gXvdUXaKwTRkCyAiY6xZo5a7fX0bli8tT39jPFBwXNN/OW5Gu2CYlfUF+VugGawhGLraELP+hq6WvFNZ+dJiIlfrwIDZCrQKaOMAiAEgEgKTKXN/bPR6m8fjcWtnaenKzQxFc3T9xqaUuXn1mzZVbi8sqNgoYcEcXb3+Ynpm8Y7S0pU97e3Whalo84QVOysBghJALgBA1ztvmmaLYll8MhwSfstCBLYcm8Tme2/dwogyCrvDkROBLWM4GOSGpgkF4H9Epu7ANLsSt4XLmH6ARJzDRlJMDYdZVkEBLws8WuyPmXVNZvzM8OBwO0mS5GXS3WyHvO35kuLCqCwL3TCYw2aLRqzYNAMQLNEhiBEJzWG7/WvHP/08akp71q1dsyUS2RYzVLN9yvitTVevxtSQqCvI3/b60vI1Y/f/Yi2G0RcS1m2WYMxuX+QBpGbZ8Wadw75vZ7WndGhiYnIoboUIkEEAt6zYktzcNOrqmnelp+fhJZvtxApN++4eEE8whPQ40Adwwa37g0wqnB8OLU+321My4rFnXJaV6orHUzOEcE4piuNfRZm6yHE2omtHFcBKJCae2rEFIMieWuxC7EAxj7tplolgJHolW2/Aih2jaTGe+Ab+AxR7YVN8B+K5AAAAAElFTkSuQmCC" },
    Ragdoll = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB6ElEQVR42l2RvW9SYRjFz/PeS6B+DAaKQAexTRoK2qGJUQnENhqLeJsmJlJr08ndxY8JGOAP8L8glBBiAi4OxsFojK1tSKlyC1wxMQGt0ojWr3vfx6UsnOS3nJwznBwAADMTAFxbWEiVK0/24pqWPPQFhiQAkKqqDGDk6uUr2vV4zBmNRDUAI6qqSgA0XFCSyaRQVTXk9XimWi0Dfv+pMzabLSgta5AZQEJRFDObzcjIpbmw1+s5bhjGr5Nu99Fz58NhBoiZWQghiUgSEQvLslxS8mQwEJgjIl4rFqsOhwNnp0OzADERCSnlBDMHmNml3ntw/2loKjjh8/mONRoNs1gsvYzPz8+M+/0zAJ9eWll5OBuNLtntdtvbzc26+uf3X/7e7yuf1tf332xsrO1//fKorus3xny+sROjo3e1WOyOEEJ0Op2f/0xTAIALQBDA+OEw3F5dLeVyOb55a/lVPp+X2uJiCcAkALcgoj0i2hFErUKhQABoq1p91uv1ELl4Ybrb7dJus/mciHRFiM+CmYmZhWQWiUQCRMR6rfbaaH/su5zOI7qu/6hvb79Ip9PCklIVABiAHEBEME2z1m5/2LGkRMMw3gF4n81kJABr+HpOpVICwMFWtVouVyrfGrvNxwAOLCkJAP8HZ3bT9RP1TOsAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACwklEQVR42oVTS0+TURA9c+9tBa2IoESFBD5RENCgrRXKQhNjjPheWHzgH3CpwcSQEDbqzr0bX9GFisbn1oUaBU2qgdoHSKVQxPokUT4Dft+948L6jOLZTDInOTM5Mwf4CUFEANB0qO3wo4NtbT0AmnI9gf+BmQkAgqHQ8XQ6zclkkoOh0LFfub/huzIppRiAr3FNY4PrukxE3BAMNgHw5TiaVoCZAaCqrramzrZtcl2XllRWVgOoynH/FBCBQEB2dHSIeQsX+ivKy+cPDw/b2WzWtiqsBXNLSoLGGHR2dn4XkeFwWAJhCUCAiJAzChs2NZ+JxWJ8pL297+ix4329vb28bv2GUwAEM5MQ4rc1iAiCmZfPmD17t8fj2R9aE6x3HcdEIk8z9x88SCspUVdTHQCwSCnFxphCBppnFczdKzx5u5m5Vu1pbT25Y+vWRq21Li0tVdFYTETj8Tsej8ebGR3dZllWpZSySms9tSvccmHL5uZ1Xq9Xuq5L12/d7lFTk1N4/+EDtNZyJJNx7t67fzebGT4PYHksHrcty/ItKCtr0Fr7W1v3bdSOwy/HxhwppQSD1bWrVw5cu3mjNi8/X0x+/PgJQLcQ4r0xJhWPJwbrV6yoLystayosnCMKfD5z+uy5vsuXLp6QXu+XSduOKSKKsuNEJx3n21mEgNaaiCjT9yz6ZOf2bfU11csqioqKzNt370Q0Fu91HOeC67o/TBQAJMJhCUAaY4ioRQDgRH9/z2AqZaqWVlqLrfIlyWTSvEi/eAhA+P1+DzMLAcAA0Ojq0gA0AAa6WAiBifHxx8mBgdfFxcWzlFIznw+m3kyMj0eIyEQiEQ3A/CsknKuD/QMDyfy8PLZtm1NDQ3EAidzb8HQpY601AZhIJBLdQ+k0ZbOvaCQz8gjAZ60N/TIE0wdNqbUrA4GeVauD3QBCf2QIXwGxrUSgihFWBAAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADwElEQVR42pWUXUybZRTH/+d53wGStlA2vil00I6P0NF2TBHQxSxxhBiTGYjeafTCGK808cYbwtXcjR9ZzK69MCxh3ppNzOIVdhsDhH4AUlqK/YIGutLSFnif44UvE82Swbl7znnyy/Oc/zl/4L9BRAQA5rqm5m/f//Cj3xqs1q8BmPU84ZQhhBAAMPTdrVvrhwcHfOPmzTCAa3pevBBw/MDMLKWEobLK7XI6G+KJBNxOV2NVTc0lKSWYmU8DJEVRGIBhoL/fVWU2q8lkUtbX16o9PS43AJNepxMD9T7ZLrldXaqiIJPJcFlpGZw9jk4ArTrpxEBIKQEhLnZ1dljST5/C8/DR6l4+j3a7vQkQTvniH0MAEGNjY0IIIUdGRpTztgu9FovFGI/HCz9O3FlIpVJFa0uL6bzN5mJmhYik/koBQBARiAjMTACEICI5Pj4upZSYnJysdV50dJkrKxAKh1O+hfnkajC4VVtbi67OdgeAOr0tQgghAUhmBjODiJgAqTLzK+WmyjfNZnNJMZcre31woDWfL7DPF4gKYPqPhcXe/lf7mux2eyuAdk3TYkIITUrZDaFera6vPSdAtJvL5vfS6SnVffnlL7/4/LPh8vJyhYikyWRSlpdXMO2ZXpTA/d89D4dH3rneZ7fZ6krKDZeJ6AGAweG33v7qvXdH3UaDoUwIgc2tLe3727d7VSKB7e1tZLNZHGqa8AcC+fu/TM0GvN4fiGjbHwh4g8FgsbGhobSrq8MxPzNj7uh2fPDpJx8PFItFbG5uakQkisUiJAjqk0eeGz6//7HRaCyVUvLOTjol9/NTRBSQUhIRzXj9/sR1m63lgt1uW5iZGbry2mB3aWkJ/3zvXnhiYuKnM6UvFXZ3dwt7mfSvKhF5CtmMp5DN/Cs9ESSzoiiKBmBl0esLDQ9da2m1Wpsk0Gdra2vc2UnTk9n5te1U6hsAsaMBFcwsWB/qI+klszhSEEDU6/ct/BWNcU119dnmVlv92aqqc6FQiMORiH90dDTJzISxMcGAUAFI+meRQUQMgI/ttiAiuRWLza6thbLWZovx6htXHOoZtSwYXMskohszd+9GNCJSAGgncg997uYDy0sRRVVhb2uz5/fyCK+vRyHlol7n567ec+LIYEKBpaWlXC6HiooKisfjWFtf9wP4U6+fCkgAMqsrq7OJZPLAYDCIyMaGFo/H5gBk9fozoHoS0yUi7XC/MDs3N59QhbCEIxvRbDr9+JiQz4DKKdw8ldhKVUfjsaJ/aeXBfiF/B0D+/5f+BsMmyUQVp1RfAAAAAElFTkSuQmCC" },
    Armor = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB7UlEQVR42lWPT0iTcRzGP9/fK7FsL2zRRZgghhJLoz+nStSyGAhSdggKImY1JOlUp1C3snkJO9ix8hj6ltAlTwpFh1j+2WvCnCRsuRiDmpttB7dovw7LsOf08PCB53ngf+052dZ2+2MkkopE5jfaOjruAI7dgAA0NDW1X7rQe/H40SMtPp+vy+3er0Qgu7lZeTszMxuLxWKvpqffJNfX3wPUTVrWF/1X0ahd8PfdHL123R+2bfvnTv5ycmoNqANo+byykkskEls9PT1DwLFdC050d3cPJpPJLXt5OQccBvBGbTv7aX6hANQrESzLMizLMpQIQP3C4mJhKRrNAt4aAF2piGEonE6nebdQUJdFNEBQazVmmqahFL8rFQFQgC6Xf+nt7W1VLBYJgd7ZEwJdLBalVC4bpVIJgBogn/qW2mxubj5oug40GoYRCwQCNblcTgzDKO81XY37amsd8fhaBsgDqP6BgclMJqPvDw6+Azy7TnsehsMf0um0vhXonwIUIoLD4Tw9Pv40vxpb1Q9GRuymQ94r3tbWq4/Co0vx+Kp+PDaWN93uUyKCaK1FRHSdx9N7w9/3pOvsmYYf2SwigtvlYnZu7uvziYl73zOZ18FgUFWL/xla2zs7nwWDoY2h4eHUufO+F0BLFakyfwCRQNXkDpNQAwAAAABJRU5ErkJggg==", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAC/ElEQVR42mWTXWzTVRjGf+ecf7sFpDYNjQ4TE9d0gQu80DhlsCkTvxJjJDFiQggLGCcCRo0xGKLDgeCFN34gGSTGiwmklURG8Wp3C2lXSIWwtYENSBzT6RLZOmM/z3m96Idfv7tz8Tx53vd5D9RQxhg8z0NrDeAPhcN7Pz969OIXXx27FFq58k2gRWuN53kYYwAU/6EVaAc2btm69Xjm8uU7UieT+fH3l17echx4EngAaGmqlFIAq1/t7z8bi8enU6lUU3jq9Okb3548Od14J1Ophe/OnJna+drr3wOr61rY9PSzhwuFgoiIFItFSaZS+d179p4HHgd63nr7nR/Gx9P5UqkkIiKFYlGeeua5T5optvXtGBIRO3IuMbVu/fqPgOeBgNa6sZMVwAvd3d2HRhKJ6yJit/X1DQFogFK5ZEVEz/32azF54cKXnucljDF555x2zmljzJLP80bGxsY+m5+fL4mILpXLtmmgauD3fDoYDC6rVCrGWmsABzhrrSlXKjoYDC7zfD6tlAKpLcCrDSEAOOdYWFhwnufZhnkd8Xmeq1rrnLX/qk4DiHMAlMvlepv/R4DW1lZlrVUigrVWmgny+fyfS/k8vhb/CigGqlVRzYrqVKtVpZS62+/z3bW4uMjSH/lCM8GVq1dvXbs+RTQSaVseDPUarSUWi6n6talYLKaMMbI8GNoYjUbvzWazks3lbtZmqNX04MdHjvw0Nzcn7+/fnwWeADDGNM4WoOfgocOTP8/OyoHBwRlgrdYaRESJiIp0dByMx+M2l83Ke/v25QKBwBtAGAiHwuE9H3x4IDcxMSHDw8M2umbN4MDAgBapVaFEBKVU8KGHH/l0167+7Y92dpqJycnq6Oho0uf3s6m3tyvS3m5S6bQbOnHimyuZzLtaqTtORKu/v4QSEQnc09a2+8XNm7dv6OrquG/VKuWsZeb2bRkfT0+fPZf4+pfZmWNKqUURUYD8c9UNE4DO+9sjr2xY91gPKJLpi2O3pq6dAtJaKVxdDPAXUWByXh7UjwgAAAAASUVORK5CYII=", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEAklEQVR42pVUXUybVRh+3nNOoT/olgExjslPpXQah6Tlx4XFXhiyGGMg8UaMwemFXriBF7vRkDX+DEeyIJebbJlkXg62CYyIGGIRf4gyLBEhQFtKXcGwMYhfC+33neMFbccULnyTky/f+73v8z3neZ9zgAdBALjX62VEBCEEADwC4OTrJ07canrzrUEAJwE8KoQAEcHr9TIAPNX7cBAROGPpVw7giL2s7Hz/wK2wSsVXff1he2npeQBHAAgA4IyBiB5iRQAUgH0APMJie+KZp5xPNtQ31Da90VReUlRkXopEthgRCgoKskOhULz76lV/X1/fT9PTs/NxbWMRwCiA+wAISinKz8/Pebq8vPNaT+/yzMyMtrq6KtOsfKOjaxWuygsud9VF3+joWjp/796amp2djV3r6VkucTg+A2BTSmW0qrl85UpIKaVisZi8E43q3wx/u/Juc7MPwHsADgDIBXDqVHOL7zuf7240GtVjsZhUSqkLF7sCAGoE5wDnHACO37h5M6rrumxrbx8rLC5uA9AIwEFEICIworTyTgBNdru97eyn7WO6rsve6zeWARznnG8LC0Dpug7OOYUWl7RwKNRhMplWpZQwDIOQEhkAOOezjGg2EAjkRv6MVHLOKaknZbqE/XvalmwTs9lsLJFIMMMweKowswzD4IlkktlsNp6dncVSk82MOc0ww8CQCpqmQQghd/UXIIUQyjAMGIbcTiiV+fiA4Y7k/42dnRlAXZepp449mP0XSKV6EskMdBowoWlaUikJxshsNpuzdF2nPYBJ13WyWCxZRCwbSkHTtCSALYAygHcjkchGMqGj4GDBY5ubm8VCCLUXoBBCxePx4pKiosc3tzYRCi+uA1ijHVsO/zg+HlheWUaV23Vof17eyxUVFSYiMlLnOnPGGZHhdDqz9ufl1dfUVBcsLoYxMXE7CCCSHs727WKxtHzR3b2+tLSkPvzo4wUA73g8HsFY2hlgnDN4PBAA3u7o7AwGg0HVdenSusVmayEiYPv2AWOMAKCwpra2f2RkRE5NTan3W1vns8zmMwAcOxjazVbrmbPnzs35/X41ODgoj3k8AwAKUz9mHIBSCkRE65FwOHpn5a+yw86yQ8eOHj1QWVnlTuqGey4QyGVMVNc31J9u/aD1lWq362AgGMTnXZfHh4e+/oQRTUqlCIDaKTpjjEkp5QuV1TWnX2tsfL7S7bIKwfH79B8xwTkcDoc1Ho/jN78/1tt7ffSHse87GGNDUkoGQO7mtzSow5qT82pdXd1L1VVVhx2lpfsMw8D8wsL67cnJuaGh4b6/N+5/yRgLSClpp7d3s0UaFADczGx90fVs+XMmYeK/TEz8nIxrAwB+TdVkmKXjH96Y1fopaJ2qAAAAAElFTkSuQmCC" },
    ArmorUncommon = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB1UlEQVR42lXRv2tTcRQF8HO+L2maSEykqZChdjDYCK0/ECeLVtFFEFEQpBR1FhQKToq0/4HiDzo4aaqzUiLdrLTGZnAUhA55icSKzcsPY1+I7717HaJR73w+cA7XAgCSoCGgAIDE1MXTd0ayo1OVT/YHAD9pCIL49yIAJg5NHrk092T+9bqzroWtQnB74e5S9uj4BQAHfmd67Mz02dlrt2bmdqWSO9MjabY7bYBAfDCOavmLtOrNdu7ei/nlXP5+CAD2H8yOZQ7vTZR+lIJGvUFjjIEC6qqEhkKaGc0k9o2PZZeRRwgAVMQrdUtacSsaZtjSoDeGoPFcz5cBURXxAPSAIenAYdkrM2IiUPQButJlTGM0JPtAfZGaW9Nqu4qoif4HOtJBekdaVSB90Nhs1na3h+luuTQDBoEGAACLFra9bYTjYX7/1nb+tMFqvrAy+DnWiTPO+td64Ld8+C0f9c16kGTCDJQjnZWXb9+QhBER2vbGWvFZ8eHx5AmmoinLqTrqVB0djqWsk0On+D5XfGzbG2siQgIgDVVFo+emz9+cvHLsejPW2EMQSTdpry6+W1hafPVAVbvk33/TGKMiAgATMzeuXlaF9fzR0xyAj8YYiAgB6C/eYNdb3VPknQAAAABJRU5ErkJggg==", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACsklEQVR42nWT3YuVVRSHn7X2e46j09R4FEcIGtFRhxSjJEEr5s6JLkqNwtJrveii28Dbon+gLvoirCG6qIgog5lB8Sgk1KAhZmmMg6TDmfPFfJzPd++9ujjnqMi4YLFhs/Zvr9/DWsL9UDMzlzgThBDCpk0jT74NsPDvnW+ccwuGEXwQEREg8ojIAvtfO3FkYnJ2sj45O1V//Z03JoB9wJqHi6V7OmD82bG9+7bv3j784ssvvDQ2PrYtSRwA3gcunr04lz+Tz9+4evPW5XNXLkGYAqKoU2KIu9775NR3h4+/OmoZyGYyVFeq5qMHBKdK7rGcpD6FNvw48dM/H5784LA6vZ5gAORG9+zYuLJuhUK5EFUUVdWOVTBvlCqlGIk2lBtyO/fs2ABsxCDpWoj1ZiOU0iLVUJEkycgqiNR7by5V6s1G6EHsCWBiUg4VFnyRjGVWpZuGFAmC9VrrCHQ8RAtUQ4VCKJAli3Xv79MW2qGNBiVnG3rf3uvAggXKjTKlWols8ggB36Zv7RoGWd95DSSIANaw1No0oLncNHMmqwm0Qsus38Q3fBNoIkKPdKE8V70z5IaoVWuEWiBdTklXurmcEmqBWrXG5mQzpbnKf8BdEUF96gWY/+XLnyeH02EbkAFZLC1ZrMeOyHJKrEeWSks2wIA8lW6JZ77+dRoo+NSLioioql2+NHP63Gf5s0efOyrrWEtxvhhbiy1rLbasOF+MfdbHseePyfkvLuT//G3mK1U1EREHmJmJOq3MnP/jr8d1cPjQK4e29j/Rr/OFuyJB5MDuA3JwZJzpj6anPn//01Pq9GqMUQCTBzmpU4shbnlm/97jb7375pH1OwdHRdUq18s3vv34+x+uXPj9tKrejjFqb5Dk4WlTpzGGCPD0yK7RgxGYvfb3FHCtuzf64Cr/D1ydX0+CMdg6AAAAAElFTkSuQmCC", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADiklEQVR42pWUb0jdZRTHv+c8v7vu3a7/BuXAmw0MrVyi2dxc60UFMcYoGEkEUkTbaDQIidWr2t72rmARWRBzjcoRTmj9ebcivbUkzFLHbOlcFuqu94/3/3Ofc3rhVa82ax04PHCe7/PhnOccjsFaIwBcPNV4BipaC+AggFYAEeOZuIqiRLehETHBGIYxBgAMgPbGh3Z09wyemekJn/nj3j2N7wHY3dHRYYxnYAyDmHBz8FKoEkAdgL2bgptePXTyyMXwwveZaZ3Wab2mg5HB7AtvHLrIfu8VAO1FbRWI1pVIECja73/4gcO7H91ZG9pec3vL3pbtDXfXl6fzaSSzSQWAYCBIm30BXL58JTY0MDQ19+d8ZPDr8PQvA8PvEyGsCiYigtbpbXVl9W+++8Wpl0LbajyLAjIug3gyrkoKw4YAwIlTUkJlWQX5OQAffLj+13X74r5j7wQKE6+Nj1PeIyLob+qvebKmMlgZ9H6NjKpClZiImYmUALdakUIRj8dVRZWJEdoa8t1ZF6r6tm/Cz0x5ryhUJyq5Qg4pSpFA1oPW/zcpKTExMjYDl1dZvvJWW0xUQAExF4NCQf8+ESuakC8EMqtdWQEyAKsWC24B/2UEWgFateCSuxIgw2IJ+H8yXALyP4BKIFixiGajK1ncEnCLXaP1AAWAgs3bnFiBzViIyC0BmRhSIbA5mwdgAYWnCgDITU5MzZmssQEX8C2kouoVZ28jc+K0anMVccbYyYnJeQB5VYBVlZlZZq5eG41cXZirr6xHMr6okhHYlIVNr/OUhWYUidiiNmxtQHQyOjvz+/QYMztVpdIGXer/8POhtm1tCEoQyXgSmlW4tFvjmlUsxhdRjjI8eMdOfNbdNwQgvDwADEBEhFR16sLp/t5w7w9jRx8/yj7rk+iNqLq0g8sUPe0QvRFVkzNy5LHDHP4kPPrV2Qu9zDwpIgRAuHS2Wltbz5949vXun879PNa1v4tb7mqmRCShsfmYxuZjmogktLm2mY4/cZyHz42Mnnz+xAetBw70F2FYv8cIgFY3VW+ZHZk9+ExXZ+fTx57alS/PV4THwxBxaL9vD/yJQOzTU70/fvzW2Z6mpuq+kZHZ1PLbmy1GAqBsGOJkh78iuP+5lzsfadu3q9HzMX13fmD09NsffZNPpr9kw8PiBKWwDTbtUowNqzhhAPcAaCvGLwG4woatuJUytfTx38bg3SeimQmjAAAAAElFTkSuQmCC" },
    ArmorRare = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB0UlEQVR42l2QvWvTYRSFz3nfNB8tNqloB4cORWi01AYH6eQHooPoUFToIAVBFwexowj+AYIOighaFCI4OIhaaK2CLdgiGh0UFGnE/LQfmuazlSQ0yXuvQ2JAz3ruw8O5FgBIgiSaCe89MnKpZ/uO/T++fn4PoPpfDwAIABiI7dl38vLV+OT8wm999WXNXbwyPhEdHBoGsKt508jB4dGx+PTH4tNERt6lVV8mVWeSqolfqo/fpF18+kPx8InTFwDABwA7+3f39cYGwqlFuHxKSNIAAHIqpq1be2Pd4b7oYPT5X0BcvfZtxen3jFW/z1htuWlqddRhnIrWay2DtWSmZJnKg4E2QJsECWzUwPZNlra5umEQkew6dDlbQtBv/gEqVcG2zR0KEWkBhcxStqtaYXltlSbkQ6MCrAHKZQe/+Lie/5kDAEMS8y+ezHZUkpXOgLCQWXH1cg6unEd+ddlFQs4ESwuV2WePZkjCiAg9z5tLTN2+cSDq55bOgM2llzSbXtStkaA91N/Ot1PjNz3PmxMREgBpjKpI6Njx0fNDR8+cK7hID0l02aL3evLurYmH966r6gZJsPU/Y7S5a+DU2bERAe2DO9fuA/hkjIGIEID+ARPK2L2ou1G0AAAAAElFTkSuQmCC", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACtklEQVR42nWTX4jUVRTHP+fc3+xMG05m/qF92bJwl91MBFuwkCBxy4cifUhICR967MWXCILefQiCgl5C3ZDCEItAjFZdWZON/uFSpglZuLrbzP6dmZ2dP7977+lhZ2rZ8sDlPpzL93zPOZ8r/BtqZuaSxAQIIWzc2N3/KjFQnLjxiXOuaEDwXkREgMg9ogPY+eLBN06e+2Fi6asf7yztP3zkJDAAZFc/ltbtgOe37dw9sKXnye6nn3th17O7Bx9L3HLSR7hyaeTP0fNnR29ev/rH+NiFb4FhIIqqI8bQ/+bRE6dfPnCg1yRHpgPmFzAfll06VdY9iPgmGHW+/PTUb0ffOrxP1V1PwADW9fRvX1+JOf4q+qgiqKqKKABmxnTFYsRs04ac2/LE9oeA9WAkrRZirVYPxbIxWxVJEif/7VTU+2CaNWq1emgPsS1ANJGZqlCsGJm2r1USqTckJziTfwqsEIDiIkxVhI57CDS9IPfBphXJtoCFaMyWYXqhQUfG/e9+m2kgm+tkgxm0aiStTdYsNJpYoLFUMjJObJUFEWikwUiz4v1SHaiDoMtQUZibvHX34XykWpolNMqk9RK+ddJ6iVAvUy3N0pU35u7+fgeYFBHU+1SAqbOnP/p685qK5XNRynPTZo1F0lqZtFbGGouUF6Ytn43yaL4Sz505fh4oeJ+Kioioqo1/983Q6OfvXzy4p0/uz0RmCpOxWZ23ZnXeZgqTsTMJvLZ3q1z+4sPR8e+vfKyqJiLiljkxUXVzP42N/PpAp3Tve2lwc+eatTo1VRCxIM/s6JG9A11cPPXu8LH33nlb1f0cYxTAVgIjqmoxxke2PbXr0CuvH9m/tquvFxUrTfxy87OhD85cHRsZUtXbMUZtg7SKOFSdizEEgL7He7cORiK3blwbBq6pc8QQdOVX/hs8oVOGS4zkKQAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADgElEQVR42pVUbWjVZRT/nfP879zddjdHL8ucQxizO5RBW6xuL7hFEMRKiJZSCwRRgpEIon7pQxQEfYogsVbYF8NeBhkJUoPUpq7WCq3mdCzdhjO22u773fZ/eX592J1d82p24OGBc37Pj3PO7zzH4HoTAJq/aYwD0tYBeBZAC4BZY5wkaVGAu6mJiMIYA2McdAIGQKyxpa3no6NDUwePDl2JNm98H8BDnZ2dxhgHxhiIKIoTiwDASgD1AB51yqr2btv95onTo5n58Qx5OU32X0wtbN31xgktKd8NIJbHVuffFpQoYkHG1rc+vj32WFvdvXUNd93/wCNr72tcU5nLAelsQACIlBspCwMXRiYSP//QPz79x/jsmZN9k8M/fveBiAyQVBERsL5+RX1J1VvvHj7evbo24ng+ML8AJFIBAQPVpZKsBQUWVVUq4RVAKARcmUh63S+07w/L4r6RkRHXERFwbKx01ZPPrayIRJzffg9oCYqKGDVyo2iKxLQlLWlUUHtnVWj12obqU8c+K1VV18kDSfh23iXSnhFayK30E6iQS3rMLxLWd+1yzLkGoohvBfEcYInCPhc1ElAB6qoFKv+grxFCAS8A5rIA/2PAWKCoG1wfcwr44AXAX1n8L/MCQPVGQqoovACIZ9zboBEs1+H5DrRIhr7ruovW9+AtZBFY3lYPjQpoK+C6ngvAAwCHJAAsTlwanXFs1gsbLzSXnadj9JaUQWBZURkW9TPexKULfwJwSUJJqqraqcsXh2evjs5EayuQSSVILwt/MVP00MsinYqzcU0E8atj01PjY+dVTUBSCssf/OqTnqFYtAyRkI9MKgF6uSJkOaRTcVSWWDy4Lowjhw8MARhYbq4BQJJCMtH1/CZtWLeh8ZlNT9w9eHbMJpMphAwFgQ8EHhi4SCVTDDvgKy8+rD/1fTp88O1X31PVfmutAKAWLpuWlo4jr+3c3HPu297ze7Zu1OboKknHZ5mYm2Fibobp+Cybo/fIvm3t+svxz4df37Xlw5aOji/zZEVnATU1NeUAXtqyY+/XvWcmEx8PZtl94Fe+vP8cD32fZu/AZHzz9j3fAOhqamoqL3xbbDEupa0G1gYbSivueKprx8721ran1ztG5VTfF8OHet456eYSx1TNWWuDwqHETTbtkk+NoQ0CBRAF0Jr3DwIYVWM8GwTyr58IAPgbTD29GkQJQ6kAAAAASUVORK5CYII=" },
    ArmorEpic = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB0klEQVR42k2RO2iTYRiFz/m+v4m3JIJSL6Au0lRoFOpSEamDk4LiEMlUEQTBQewsuLgreEGUoqhLVCiIWBQVHZKAiIMWSzHLj00T21xIm9Q0l+99HdLWnvk8HB6OBQCSMCQUAIDI6ROJa/v3HTie9ae+AWgZEiCxPkEAsSOHh+N3bzydyH+t6cyXBXfr+tjrwYGhswAOrnS6iZ8cGU0nf1Sn3xWlOalaTKsWM6rLk6pTb+dcKvm9eu7UhasA4AHAQP9gdKgvFpn14XLTQpIGABZVJeT1arSvN/Ixeqgfb1YAJ532vO908bdVEzB2VQakabTQ8dSpk057bcFasl2xXMqBNoB1fcA1wfAWS2u71h4AiIjUy9BqYQle0ED1P9BpCsI7N6tAZA3IV3Klv7sbrNTmGYQHcV3AWmC55rDD81hcKJQBwJDE+8yrz8VAtuGFhH/KeVdvl1FvV1Aoz7qesDNz3q/GxIfxTyRhRIR+1k89zzy8s+togKFtQVso5bRQmtHQ9g12z/AmvkiP3fN9PyUiJAAaGhWVjfEzI1cSxy5e7qlt3UsQrXDVf5l+dD85/vi2qjZJYvVvGmNUul6xS+dHEwDtgyc3nwH4aYyBiBCA/gPgV9npWWccegAAAABJRU5ErkJggg==", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACsklEQVR42nWT32vWdRTHX+d8vumTrQyzXVgxKVq2MUMkwWIQiNOLLkKIftBFN93Vhddif0AQFAkiFKmsgi660gjnNhVHkT4Qms0GWbi1Z7+ezWd7nuf7fZ7n+znHi205TQ8cDhwOb877xTnCnVB39yQkjkCMsb3jqe53zSLjpevfhhBmcMhjLiIigPGAWAfsfv/Ah/2jg+P10cGJ+gdvHewHdgHr7x2WlRqAfa/u3LOr+/ntHXt79/fue63vuRAABzMYvDj8z0/nT1+4+udvf48UB38BBgAjaADo/uzw8dH5YuoLRff0invpvNvEULSJoWiT59zSK+63iu7zxdQ/P3z8OvBi0EDiOMCmns4dm5NagZnp3ESFoKqILu/nTqns5u7+ZHsh9HTueALY7DjJigXL0izW55zmLZEkCRL/51Q0z6PX1cnSLK5CTP6bcZHmgpDNOUlyf7p57jRVcJdVdmsEDBplyGaE5KEHCLSELACP3uklywhwi05tHqrlBsm6wEr/Lhd5M7KhsAF/xAEch0REwElzbzQzj1TTiicW5L4Cjegbbb1keT0DMhFBl4+K6fG5G/8W2o1KrUyaL1JrVu7KNF+kUi1TaHduzv01AUyKCNrKWwKU+k99eUafXvLQZlKuzHoaq9Rai9Rai6SxSrky66HNRJ9Zsu9+/PosMN3KW6IiIqrqvxYvnjg59MXQK292SXjYmJqdtKVswZcaCz41O2laiPS+0yPfDB+9cKk4clJVXUQkAO7uohrmRy4P/xEek47X3+h7dmPb4zpVmhaXKC/tfkG69m7hqzOfDnxy7ONDQcNVMxPAZS2moOrRbOvLO3vf++jtgwe2burapiJ+o/z72NHvj/zw86XhE6p608x09ZDkHtYaNFi0CNDV2dnTB8bY2LUB4FrQQLSoa1/5NvdNbN5YCvw0AAAAAElFTkSuQmCC", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADg0lEQVR42o2UXWhcRRTHf2fmbpNuNiZBNEpqCIQUaUsrtg0NCm1KH6SkD5aGClaftFWLCn5Ekb4Jgo+iokZRBPvQ1H6E+IEWTGvRYIhSaZPYsNIkthWjm91NdrO59+6d40PSJlvTmgPDwJn/+XHmzJ+xlIYAZn5Xz3o4dfXAbmAjkLLWy6o6FuluGmLEYK3FWg/AAi3N67Z19h4euPLd4YHLm9du/QDY0t7ebq31sNZixLAkWOZy1UAj8GB8RVXHawfeOP1nf66gV1T1surVn6ZmX93/+ukVXsWLQMu8tkZESq8oiFO0pfm+7U/u2LKtvr6u6Y6WTQ80rGm657b8DBRykQLEE1bicTh/cSzTN3B29OrEaOrUD6fG+899/6GI9KmqERGhURvLyldXvdn9fu/BhrpKLwzBn4WpbKSiFmPm2ncORRyVVUbKyiEWg9E/suGup1vfJea/Mjw8HHgiQlKT5Tvr9lRXJyq9saFIVVEjIsZYQSAqeTTD5JRTp6rGCNV1VbGGVU01X/V2lRtjAm9eqC4qusBX3IwVdYiWgm4II6qIGghmFRcF7tqJt0gjFIUgC+pAbmkIUAUxEC/KXO1/gAKuCEF6XrwcoICGpabxFkwILgQ/Dej/WXZB44pztTcCFTG4EAqZYBk8QVEEIQq9JTssBmHghy6kEORxTpd1ZWOFyCXwwzAAQgBPVQH85OjIRGjyoZaHsXy6oNYzt0RGRaeJmpXim1yYvPTb30CgqhhVNcYYNzZ2cXA0NTJxZ1OCqemM+lGeQpBbcvlRnqnptNaurmQslfxrfDw5ZIyNVHXxOOn/tLtzoH5THKkoks1l8HWGQjFXsnydIZtLYxKOVfev5ONj7w0AfdeG6wHOOSeqOioiXds3P9T08IE9a468c9r9M5mReKJcFqauzGRnNZ4o091PtJgTPx4ZPPrlJ13GmEvORQI4s9iHbRvbTu4/tLez++fPh9qf32oaN9wtk9mUpjITmspM6GQ2pY0b7pK9L7Sanl+ODj516JGP2traup1zsrQXgNra2grgsYP7Or650DOe+f14Xk92nNfjL/2qyWPTeuGL8fQzj778LbBvfe36isW1S32MAqg1lshF6xLx23c++/hzrTtadq2NeUZ6zpwYfPuzt87MzmS+Nsaecy66XnMz4PWcNVYjFxngXqB5Pt8PjFhjw2huZiyGAfwL1YbCV86Nlh0AAAAASUVORK5CYII=" },
    DeathPin = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB9ElEQVR42k2RT0iTcRzGn+/vDfa6LTJheO3PsjRCashMKG8hEZYyMPAQQceSNgyCWp46mBARiy6dBO2YsEtQIOmraQUxY+/F0965GZu+vK/o+7q9e3/fDlvR5/jweZ7LQ2hCRMTMHIl1dd0cjPXFAImVXO7nuq4vEFGFmQkAAwAJIgDoyaRSi0Y26+8vL/OBpnEhm/UzydQigJ6WQ4oiBCTz8Zf3H8xPjIxc9W0bh5aFum2jjZkGL1082X60vffj+tqCIoSrMDOuxPrGngzfmHA2N/1D0yTs7ZG0baqbJpxyWZ45ferEt1Ipb5RKGwIA4t3dF0LVKtu6To2CQeOzcxifnYNnGGTpOoUqFb589lwvABwBAJfZd4tFcvN59oNBNHZ3AABOPg/PceCGw1QHNf4VcgXjV/XYed7f2iKhqpgOqgAAq1iEdF1CPM4/igUdAIQiBDTty+cNVdWD0Sht27Y0PQ+m56FsWTIUjVIuoOprS0ufFEEQjXRaENHvt9rX6YP+/jpCIarWarxTqzGFw+QMDNTera68IKLtp+lnAgCodYpyZ/jWzGoyyW8iEfm6o0N+n3zEd0dHZwCIltN8AwApQrAvZdu9ROL5WGfnQ0FEH3bNV5n384+ZuU5NlfEfpAgBAIHEtaGp20PXpwAERDP7O4w/OvjtPPNPblcAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADFklEQVR42m2T32ubdRTGn+ckaUyTrEs6pUhXdcG6NdCUma6j7cWc4A9YV/Hai+kQ+g+Iu3BWobA6J7ar7EJ24YY3QuuFiA682OYmFrFg6NIwoYusWZEtafomS968efN+jxdm/hj73J7zPHCecw7xLySpqgoAzwI4mEok+mCATH59A8AygN9JQlUJQAGAD4lDsc7ON6aPH3/z0MjIvu5YLKIAytvb9y8vL+c+PH/+Ytm2L5KsPzAhAKoqkmTA9Pa9e+H99945sH9/1KnX0XRdAEBHIIBgKITllZXqsZmZ075C4XRW1SUJAhAhjV8Cr3/z0anPX0oNdm9ubHgiIkoSChCqxhjz5O7dvh9WV4sTJ05MtVx3yaiKzyeiRjX89muT01MvHn6+kMkYNps+1G1GWi46HAdOtUq1bSkXCibZ3x8u2o3AL7m1b30iTX87g77DqcHBxvq6Njc34Q8GQVWcya4BAN5KDkBJtBwHTjCoY8mB5Lmvl54iseZvp74j6g9EavlbrBc2EesM4XqxiJkr1wAAe1UxvqsbFdtmTZXxnp4uADuMUfhJAqqNmuM0vHtFuH/ktRIKsbfZxHBsJwCgt1REpVpBy7bVdHSwHo/bAOok4W/vsZArFfMj0ejT1du34XR1IaiKuc7HAAWkVIJFomlZ6Emnkb1XvAWgQADieh4BlBavXrtkJRKeiUZZaTS07LqwHAdW00HZdVFpNNREo9zek2h9deXyJQBbrudRSNInRCa7uvhdofDrM0eOsGRZapOoGYOaMbBJlCxL9xyd4Pd37qxkc7lFnwhI0gdAVUERKf9440ZtYnLyUNyYcP7mTSOhEFsktstl0z8+Llup1NbU/MJJz2teP2lUrgLmnz9on2ZgaO/AdGZ+vr40PKwfh8PemUjEW0yn9be5OTv13L4PAATbvcRDUEQAoOvVsbFz2bNnnS/Tab0wNKRrCwvuK6OjnwHYKSQeJX6A+P42efyFAwc/+enUrPXz7Oz9l0dHPwUQa9f+J36Uk4iIMcbE4rueOOYX4d27f34hIlvGGMF/5gaAvwACHYGNs18W1wAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEQ0lEQVR42o2UW2xUVRSG/7XOXNrOVDpAM71gB5oW0KgEy7UpaBQfjNREwwMvNSGQoITwYmJiIkbfpMaYgCKJSZVEg/EBhAdDFBrBmoYEJlSYVoptpS0NpdM5M9PT07PPZS8fOkWMEPyT/bT+9WVl/3svwn9FzCxa6zIAzQCaAFSXatMAbgK4wcxKa00A5F/ND4GtWVQee+3N9va259Y9uyKRSFQSSKams8Xevmtjx06f/iVnWz8w8+8Pgi6IDWYAeGlH25Yzgye+K0o6LdLXJ346LUE6LXL1qkg6LYMnThR3tLWdAbCt1HNvMOPeZESiRTZ2vLDt3S8Pvvfy4kRVWW5yUtumKXP5POYKBdiFgswWi5Ksri5r37q1aXR8Itk3PDTERONSghoLsHhl5eKVdXVvH3//4Oth3w/lx8c1uy6LUhQoRVopglIExyErm9WRcNh4fsP6hnOXL4vt+72e684JQAYAZmZxHGfLob1v7du8IpW809+vjSBgPTcH37ZR5vswlIJjWRDHAZQi684dXVtbG6qofKzy+/PnrzPznyLCISLSgda0uKqqZdPqlQ3ZTD+0aZIbCgEiiBoGLmezAICnly6FCgKACNr3Kdvfjw0rmxuWLEo8M10wz4qIhEoRRVY3LK+vZC63/rqFwHNJiBAPh3Dm1hgOXOwBABze2obtqcdheT5IhKxiEVXJZPmTy5enfu0zowazE1oIJx6LRUkpqInbEK0RAIhHIugZHoGnNQCgZ3gE28uiUK4LA4DPjAqlUF5REV4IeAHo3p6eLiittTZNdi0LZBjIE2FnJIzrsQoAwM5IGPmxMQQi8IMAkVgMThAEo3cnTQAOAIS0CDGRPzAyNDDhOGZ1PL4kNzgo4ViMbK1RQ4Rj8XlgaKaIfFHAzPBmZ6W2pYVuO8ocHBkeYKJAixADICKC9rx0dyYzWNXaCkspsV0Xc56HnFKYKZ2cUpjzPNiuC0spSbS2ojuTuam1vkZE8+8ZgGjRSKVSA0dOnuzO19bZibVruWBZ4hDBEYENwAbgiMAhQsGyJLFmDeeSSfvzUye7l2FZRosGAFn4KTwzM+PN2nZRwuFVO15tbxzs6REvCMhnhicCXwQ+EdwgQGAYsnH/fvrop58vXLhy5TOLrVER4fuBIiJkME9c6s/wunXrn9rU0rLk2sWLGpEIeSLwAfgAZixLv3jgAPfM2kPvfHH0iMF89v4FwfdvB19rampqOrX7UOe3UzU1k5s7OnjKNLUigiLCVC6nN7/RwZM1NXd3f9z5TUtj42l/HvZQEc9fbm1jff2RP7q+KvTu2SMfRqPBB9Fo8NuuXTLQ1ZVvrKs/DKC25GU8QlwyNj/RkDrW39U13bt3r1zat09ufH3cXLWs4SiA5v8L+wc6v+caG5LJT853do6eO9Q5uqKm7lMAqVLtgTB6xKRai9QBeKXk/ZGJxvV8ovpBTX8D0MBE40l/f3gAAAAASUVORK5CYII=" },
    ExitRun = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB7klEQVR42m2RT0iTcRjHv8/7/l5XzsbeXtPGOiRmU8MhexlEaLagoRNFAxdYhBKb4aFilwqsHQzqkJeyg3UoGAQ1osOyQ6wQyiDabNFhIoWQLIypg0Hh3J+ngw6k+pw/D8/3eb4y/oWICAD2nhu/cLd76GQgtfBjOZNOf2VmEn/L/qkpkVGjpXzMMDx81T9UKRtBqmIc7w3MCCHWtw+QJEl8f2QkDwB6f4dIZhfZrGqUzqxUA9jP4Hm5LANgZjbYDts9tqP27tYTztN5E7Rnt0PJRv3QvrquFnsiPPtUACBmBhFpZ26N3nH6jg+CgEa1Dt9yKRzxtNdYXQd3xu4lVgHk5SCz5CLi9uv9k66xgbOv379Zk5loqWJVfjfzNqU21e6ai8+VIqOPzmO9sIRgMCiBmRxXOv2OiZ7wgR49Ecq+KvgWbhYt7uYnkHDKaNOOAZDK2ctUAWi7+PLGY9FkUnNrv6HVVuPFw+eR+LXpXpIlcLG0+db6PoevbcB1WbPWWEvWih3hidAHjc0rnYE+Ty63oUCHUooVC0S0uUaYDM5fpmL9p+TnjeiDyOz3yY+XbA0N4mdqmRajyWnEkfd6vRIALsfZg92yG0AzAIPFYql0BNxf9LGuLIxKy5Yj4X+QvHWWorQKc1XHtp4AAH8AFcqnTL2YvsUAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADB0lEQVR42oVTW0zTdxg93+//b6FFVxwbzAvVolXBTQIit4E4ExM2t0SJTdzcMOFhy6JBH4iJCa5umZj44C0xPmi2qBkJmgwvie6BsKCbIrbgbX9LBYqEWsCWDmibppfft5c6Z8bmef3ynXO+k/MB/wNmJgBQ9MaPtzY1tG3euf0cgKrUmPAaCBIE1aCWfv/z8aH7PMw3+CHvPrXfAWBZilyI/1imGnuNYMmKtayovKC22DIdmZKT0Sm5qraoOHPBgpUkiG02GymzLQtF8EjXiATAz4fHci0b8j8Ry+foSVWpt+vudNfpKw8A9GmalnzVAYOIiGVS5kgpS5h5S1nDhq+SacT3f+8L/3Tw9BMOJ2L23pPfLaxcWQ9Aqv9UBoEZvH7HscaWgspCazQRNa1dvUZHGTpcaL8Y8vS4xz/dU79kSPp0aem6N18mySASxPNyc7buOLrrcGFdhWWUJ6CEgTzOkQNJr8jOzIYReowhiOs/Xu7vaDi7iRQxqAIQQhVSsnyrdN+H3yypW2O55uqMPGy7E/z8yy/m//HGiHA8coYj7uDoopI8cyweNzz64dZ5AIMykSQVAEtmAIgMOdzOq79cmtPT1O76oH5TtTVrsbgUuAH3eadn4NStFv3bprjelG4KDYy3AyAi+rsMRIKYJasA5huXZh0+1HlyG3SUmEqE1EgwHNMGXWPdRzqOTfzmPkqCwJIBAGoqB2bJy/COoTC3xGKt+/qzdc/iAXmz97ZqjOsSVavK1YKK98z9lZpt4nHgjPT7Q0QEAKwSETOzdd3eza1rN5YVGk1zddIA9A1reHrC0eb3jPuKW9/d6Rnz0oz23IlAYOaFaMoBA4pi1pkzSvzGMHxP3JiemY796fD1eH91NVfs+qjZmG5UR+89jU92P7sJAHSAXhIwA0gm7zjPdNkfm++tiHpDWqg/oMVCoW5kZCSRhveHI16adE34ov5gLwkCf8t4LUgQABiyKvKO5DdWe7KKFh8AoKZu/9cnEpiJBMFutwvYoAB4UfN0APkA9LMJ/QXv6lSvYaNe8gAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEM0lEQVR42o2UX2yTVRjGn3P6tV0/1rVdx9piWZHhxmDrxsLUZHFqGBcaMZpIYvQKRbliagT0QpTtggsDkRBicETDxRK9IEYMhPHPbA4IjHVjo8jcyv63XbtuXdd+W9uvPa8XW2Aokp3kvTrn/PKe5zzvo8HKFgMDADgMRtPuuh31HzNJeiEajsQYYwFgaXelMMYZLBaLyf3S88dO9/0WvZLwZH4PdSTf3ffhFQCVnHMA4CsF8qUL9Y0XjgcHKER9ii/bKrro58lL9Gxl2SF8A05EbCVUBoALITjXavONLqvsVQepPzWKyWhYwKSBo8RpYk1McI2GADD+NM24hhOXeEbSa4VQ1dE/f7kcjknzbEavcF3+Ku71eBc6L1xfTURbiAQAQPNEzRgjEEBEdhKUL7Kiwuou2lu2vWoTM2i0Uf/0vPdaz0zwznhy15EGd1qmqpEb928yzqak/34AJxLCyM2GD15veOfNwrV2YzadclbW1Tjc5W5ci3ZTy3s/TAy33uk97T/3mn6NOce1bWMpjsDJGLsv/bszEsKRX+H8ZN+PBz/aWFORn0QaKjJwqQWUmE1gndaOvc37nUkllceNWn1P4h7+Ou/pAnCPAEjLrEGyQS60vVjc2HDyy/dzXHny1WgnYtGYWiTbJeSorDPdj1xdLgrXWnWO7OqCB9kgRruHYz2n2s4wzgKUFUxa3p2iKO6t+7e/ndygk3sSXgz81DmWSiT19V99ahucHkWU4nTr6NURw7q8tLV8jctgWaXvPtHWpqZSrYwzAHgIBBEBgP9uq6d/wYHq4NmB7q7DF4xfdB6tzMTT1C/Gmf/iwFzX1+daAPyRW1T4nJQjOWYHAufAECRBDIBYPjIcBAJDTV6hdcNceNpSsrv22++bT8iBcT8NiUmEJkOqz+cbGbro7XzQcvskgOuMMyzB6HHbMBAOAQD8KWVhVFtq3rHncMMrQ/EJ6oj3IkerZ8+YbBp3Wbk1u0V2z47N5kqRzKUDygG1vbH9IUZamgYCoQhG6S1bzfrNthLHuto3Xq4ym0zUPuVhwY5h9Ce6/Ju3VVu2Wjfp5xMK1+fl8ImZGTRpmsTycJCIAMagzyu3f7azcdee4uL1Bq6TkE2ruBXoRcw/ne7/7sbxRCgSrKuuPRjLV+SpocnMVMeYB8AcZYmBLT4XACSuYQSQbC5xlGadkuFu6G/EUnEoC/PIKGpmpKXvbCIUOWatW/+53WYzD0cCSPhmwnPjIQ9jDMQe6bfY4aKgsamOB+evFVwu1pkN2lRAGU9OzPmm74YGktPRM5AhHCXOWlVkxGQkxJXB6CAALx5DPdIQAMTC1NwpX/PN20t6jAKYAZBmGgaaJ1c8HMvcGPHw+VAckVtjHgDhJauJ/88qzh4r0GJ8AeDQ6HbaXy391epe2wygclm8PT37ltWTDlsAyE/D/ANFafHn4IBG7QAAAABJRU5ErkJggg==" },
    ExitRunActive = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB6klEQVR42mWSX0hTcRTHv+fu/txyGzVndUUi0TXpyiJY5jCGETosQyGYSig5nFsQRVEg9odBD2K9FEXJCqmkF5MeCob05hIZlRckCdIegiSj+adsD1ub2+lhFaLn9Xy/fL98zgE2DxERACgDfb5Hw4N9UVW1NwIAM5O8URwOB2SL5UfufTTl673Y0YWteiimrNHTeXNcyLrUegPpJOJg8EEGALxHnfLv+AzrJTOtriwWAyhjxkf6XwNgBvSuA1Ue+y6zrb620le3z7I3/PztbIvnUPn3b19izWdHmmQAxMwgIuutK+13Au2OkwYCJEUFfs6hpaFmx0GXdcuTh++WAWTAHJIAoP9MzRDHL7M25F5eGOtOZrRgbvKeez7xujsx/bghWWSWXUQAOBSSmEHX/Y5A+NKe0RNHKqbTnwbXll55s8drlREBtFXuNh4GIG3EaQLQGB3uWVkd9/PnF6c4GbvAt8+pLwFA1hEA5LF668t6Opure0t3WkvLi1OG/vuRN9kCZemq330slUwLpxNiaiq3RkT5mG1GudpSkKiY/aCl7z6dmLzxbPG8zWaX5xfiFIl9jWgaMqOtJAHgf3W2FxXCA0AFoC8pQeG1rqqZgdPqLyGE469G2vwTAHRS/jRCiP0mk6Fu3QoA8Acgb6K5POjgiQAAAABJRU5ErkJggg==", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAC7ElEQVR42oVTWUiUYRQ99/u/cRZbcFqGNCzBKaMsKbOyrHltIyInqgdfWoyMDKqXsmwhH6RFiKKgooUiW6GQCOmhok0dMQe1ctRMy6JxpvR3spn5v9vDTL60ndfLOecu5wL/ADMTAGgJtmW7tuZXbtuw8hKABfEy4T8QQhCsUuZUXS5t51ANc+ABnztSVAcgPS4uxF/IVLpokVCKtdy5GXOXLHSmqa/flKH3qhUu50xHsiNDELHb7f5jF6RpAkIIEBGAhPyaa8Uh7qpgDpzh6vObvwLYDsD8WwfMICJiw1AOpVQ2M68sdGcWsiXCnpfNA0fLbrf2DyLsvb/jYO7MlAIASg6RASICA+w6dWhdWW5OhlMLh0ZOy5ptwnCF6mu39Gevuj/v2JI/Efobk81ssg9tkhmkCeIJyUn5Jw+sLV+8fFIa+juBH2bAMkmhv0XAMQbg4UC4G7evPHyzas/zpZqgNglAmCQpxTz64Kbp+xa77WmBx/dCF6t8wU3rV49LNOpFm7d2wFsV6c7JdKRGIxHriZsdlwloixqKJABWzAAQqmns9Iy/qg8rLn/9ev2avLxEx2QR8VXi1N0PHcdudJXZ7dbI6GEJI9++/3YHABHRUBhIELFilgDGpafYymvvlKwxS44ag0EZ7Pse9rW2fDp8obHiocd/XAhAqRhRxvfAijk9xY4Zc6Y6nMUbVyzkUJeqq38sw2yNZmS5ZF62M9Xl8bkb3uGs38967MRgGXd27i2cd3WJK2tG0giryWaKostXi0PXA5Wt7wI9VafnFPnfd1BD+6Cntxf9AFHscIBkMDRNS3WO5ewk+oj2ps/o69PDT1tCNdUvekp2FuSUmC022eDriTzyDjwBgP2x0WMCYMAwjJcVlc2l6cltkzu/GM1NneFmXddfJCbCsMjo/EjQR972vh5/MFovBHBA4f/QYhm15mWNOrZ73cSOWVNG7QcgY6P//okUDxO4FMINaAB+xdwCYAqAhD8Z/QTtzk5u6GRp7AAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEMklEQVR42pWUW2xUZRDH//Odc7ruKdvdLWzbhWLpZSkB6VZEBAUSI2LEe+IlxjcEJQZEJRoMMVBiQiJGoRoRIfogRIMNhqYYY9UiUiXaBWkprW2RbUt3m7PdS7uXbnfPOePDcqkECE4ymZf5fpmZb+Yv4daMKBfd+Tb7msdWLX1JJuUebSQ8SkQBAIT/YSSI4HTCvuxe766u1r3RTKBJH+k7lN68/tkfAXiFIAAQtwoUUu7BimNfbQkyn2E95DNYO8yJc5+zd55n21ZAMPMtUQmAMEwWiqIUVkzPV82hdjZjHdDDw2a+amBOpcu+nWBKkmAAJG44MwJkSbAsCd2SJ5vZbLb/yyMnNcERUhAS8jQS7X91jR9t9rmYcSczAwCk68OImQGTucRkLjQMc753tmvDg8vL57ryoPQPx1K/t3ZHfF3h9Ps7nqtxSNna420DJ4WgkHwtTBLEhsm2Qpu8+rU1DzxeMaPIlslkS+9fMt896647MHG+hddtbLzYdNx/Jnrmk4cds+i2RxaXVL+7F6UC6JKvaZMNk90LPI6NX+xev7Zm4exCmCnAyAJKFesjCShTqnBg54uliXS6wKGSBf/40PDT+TYAnUyAPGk12KqqRUtri+r271z7QmmJrOLCd0hG41mLo0wWDkFy+AQwJR92lzvPLhVPQ/Ic+roHR+u/6WwQhIBhMF0BkgAnk8mautVzniqdGVUROIt9DYGBsWTGsmnzQ8XmcBeQGeEP93f4PSVyxuspKMu3Wy07DvYey05MfC8JAvgqEMj90lBjS093YcHogqbjY6fe3ttp62l8xZtNMivxdmr8LTz2xkedBwD8PMNt99gskrvbH2kiQtAwmQCYk09GMMAE+W53kb0qqIWdG54uf69+T70avRhgKdWD4LCW7e3t8x85Efhjf1P/pwBaBQEmgwAwJt8g0eUiAQAFc2dKW77d8+pbdqvOZqQd6tQKgnU6VHUKYv4WrPug41B7R3Btb3hrgqiOLwPlKyzG7flWPLm0xjVvXrlz1hMrF9faHQ6OX/iBmk9FEY/7h1Yt8zhtM5dY9HhKOGx5oi8CyNJ2c3JhMjPgIVjUyoLXd7756MtVlRVWiyKQyeoInW/FUDCZ2XYwUK9pseCCRcvfsWVias9AVG8+nfABGNMNJiJc6U2WJbABqM+XF1RXFqas4YHTyI7HMD6eRDxt6nuaQkc0LbZrxULnpqJityOi9aJ7IK0NDiV8ggCiq/MDANkwQVuB0Y9PR48Wfd1WOdWuKIMhfdAf0vva+uI90XCiQVVhVpe57mNjwgxrQdE5mOkFJs7Sf1CXgABQB5gIJ/ftPpz889I8+gFEAGRkAaRSKNOiKX3o719FIJzGLx1xHwDNzMHMGwsf5VwSuci5dRAABCTrMysXFR+urZ76GaB4J8nbzbVvkl8v2QlAvRnlX8LQ4aNFwaybAAAAAElFTkSuQmCC" },
    ExitRunLocked = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB7UlEQVR42mVSXUhTcRw9v3v/l13bFtuuxQ1fZNrEqTAYa4ULkWJQgj5Jscoa4eqhBwnCl8KHyKyXIHvZ3uqhD4R6iEHrYWSyUtMMRx8riXANmssNi+S6Xe+/h1WMPK/nHDjncERsBRERAKhjp8PjAz2HzmdyK98KpdUlzjmx/8XRSITZSyVjUdPCwyePn4Jsgso3zcEr159JTNRqDSQKxM/EYhUA6Pd52cbbNDfZrLRWKNQDaOQcH+hfDIBzwLS3pS3oUqzNB90t4S7F3hqdns30dXY681+XX/beedDDABDnHESk3Dh29GbE2xGSOSC0uoGlj+jz+3fuUZW623OvVgFURD4yIlB3Nx8N+G9dCHgH0slkkUSB6pY/i9OpVK7dZrG+X3hjhJ4+P6sZRpYBAAfo8vr6TOzexPaEZuy+fyTUvjaZ5FcXP71IJKYeOs3mfFHXZwGAakpbAAQmzw3e9QjcXixXoDociD5JPB56/a6XEUH/O2t/U+PgiX2+4QZFaXDqmjz6KD6zWa9+v3hg/2Ftoyx5AWnOMHQiggAANsZ89l8/mzIL8+Xx5FTqWrYw1OxysWx+heJfcvF5oDJBJFTTV7HDAQQBuAGYdgHbLnna0mMe9w8JUscfjbD1EwDE6i0gQfJYZLmrhgIA/AY6IrKlHbpGswAAAABJRU5ErkJggg==", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAC6ElEQVR42oWTS0hUcRTGv/O/d0ZnpjBfDWqZklMjvWuysiy3WRGW08uohVCLoBbVJizLyIWQCVGtWlQQCWWLMAgxlOjlK2lqtHKcfI6Gr9GZqZx7/6fFTEHQ49sevvNxfucc4B9iMAGAYjRvP72nqOZ4YeFtAJuiZcJ/JAQRTKqaU1de1sNvmpmfPuGbx4+1AshiZgIgxF/MVLZli5DMSq7dvr7AbsuUfr/Ux8fkzmzbamuS1S6I2Ol0kvInsyIEN/X1SQDcMzY5f1tG6o55HDYKSHrR8W7qRmPTWwBv3G63Ln6fGURErEtplVI6mLnwqGPZUdbC3OZyBy/X1H6aZsy4Sk+W56anHQIg1d/MAIM5//rhAxW5drtN+RaKW+pYawAk6u8/CLzoHRg5ubcoA90fDGbVkPCLJAOkEPGCpPiia8X7K7cuWZSJ/l7AEAMsXCTxsVNgbjJgmQ34BlBb3/Bhd8PLbQqRRwUgDIKklJxUvmr5ua1pCZnjjx+FbnV2TxzZvyfF4moXnpaWoOt7eCAn1ZqufQ+brr733iHAo0lJKgCWkgEg1Py5t21eXWDWifaurpL8vDyLbbEI19bgunfQW+Xpr0gwmcJJRmPcR7//ISK8fh0DCSKWzCqAlCyzubLlYum+GGJNn5xQJ0JfZ7rdncOXWt9WN3wZvSIIiGQCIsqBJXNWGrBzV5q1+GbJwc081C9b791VXzc2aiLWpObZben5c8zORGC2Lpl+8lOjybazmzfcLVi9ckW82WQw6xr621twcWi85tPouK/Ose7YaI+XOgLf2saA6cjCwACgMjMURUm3CXbEjwyhZ3gEU9OBmef+UHP9gK/01Iac0hiLWe0Y9IWb/MFnAHA+MnqkAQDouv66usNdltXlWdyr6e73wRl34GvglQXQY6W2MezpJtfklG80qLULAi4w/i8lgteUl5xYdcaW4V2TnHgegEp/+USKHhMYEE5AiQIGgFgA2QCMfwr6AaSZTup2Ouk5AAAAAElFTkSuQmCC", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEJ0lEQVR42pWUaWxUVRTH//e++2baGWbp1Om0MlLoQlnsTKlRJFSisYgbLjEoxhgTBRe0USQxGmMoxMQPboQYjSL6wX7RVIxN6wIEoaEpiR2BlmHqdLGldGE6W2ftzHvzjh+mQiGIeJKTk7vkd885958j4fqMsXwsMxotWzaua3heSPLqQDg0wxibAMDwP4xxxlAEWO5wu/f49n8eyf7argZ/+G72zc2PHwbg5vnn+PUCucQZADQebX57knynST3lyVHHAUq0fEXuyurmnQAnouuiMgA8pxGXuWyrWGA0aH29pPn6oE5NaUbKYZnDbtkNaBLnBIDxa/VMcE6Cc1UvhKZoyug3x08EeDTM5NA0F4LxXq8v3dHjsROwiogAANJVYYwRAdCISjUiW07Tat0Oe9P66iUr7IA8Go2mur39YU8gNPvB00+4rKpS1zly7gRnbFpcCZMYoxyRySbEs6/de/dDFSUlpqyiOO9y1ZYtdt2MTOdv9OK3befbh0dOR/Z/ep9VZgUP3FRa8y7g5IBPXFEm5YjK6m3WV7/e/spWV81SG9IpQFWAxVWkJhKQl1Sh5aXnnInMrNnKmR4nPWj1DfUA8BIAMU8aVGgwlDQ4SnZ9+fLWp5x6YcChn5CMxRX9onLBGWfixHHAaITFUaazOBw3wH8Wg6NjM3tPeVs5w0SOiIlLfQMlk0nXrlXLHnUmIwb8fgb7/po4F8tk9TvWb3Bof/qAcJA+9vSNVOtE1m0zlxsLC/Xv9Q0cVZTMLxJjAC4Bgfwvjbd5/f22xEx9ezD2x1ser8m/Y5tbyRHJZ3tZ24VQ7HWPtwXAkYUWS7VJksr6w+F2Bkzm8jrUpHk4TkCwMRg/0xpOdH0/PDq0bemSzZubmuRYKg1FVwC9ycw3mI1OI5ccx6Yu/BxMp1s4MEl5vdJlsmEANQMAtPHEbHp0hSxt/GjLM3eqQwOkdB6GrC9gCxY6peWu2uK1mbhrKJ5aoIjEweAbO5Vdx45dLFT887sELDICjzQ47CtX2osWP7zm9jqL1UrxIwfZoekI4v6R8fuXVxeZbl2jV1MpbtXr+OB5QOzerc0fDoIIqGbQG8zm7e8/9uALVRUVhXrOkVVVTHd3YTyWzDYPT+wNRKOT9evWvWOaiRr8oYh6KJrwAIipRIzNlQsAQnBQDjA8aTXXVGZThaHek1CiUaSTScRzmvrZ+PSPgWh0T2Nx0Y6S0jJreHgA/anZwFgo4eH51C72DwBEjsB2AjOfhCIdJd09lcU6WR7LqmMjGXWwZybujyQSrQZAqym1ryUlo4WmJrk3lR0AMmfYZajLJwoA6ADcBmA1gNK5NUT+tHxTubOro6Ge9t2ygqqs1g8BSP85VfmcSywf5+SQ39YVbrrnRseBuuLiLwDZfUUy/z775vnVLhcBMFyL8jdiJs5fUQKP+AAAAABJRU5ErkJggg==" },
    BossSkull = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB8ElEQVR42k2Rz0uTcRzHX5/nWWA0l25OQ5AsyUOudtGD0EFykh1FhCyEunSoS+DBf6BDl251kA4WFZ6EGUIeDGKRDi1rUdEhWvPH3PPMyG3QJtvz/XTYgt6nN7zf7w8feNk0ZImgdesHzgDtwCFw+F+GAKKqiAgXItHrt65M3ug72d1j1OPb9s6PB/PP595+/jT3r4OqCsD4UGwms/DC042Pqok11TdJ1fUPmllY9CYuxmYah0UsEVqDwYFXd++tRE90BjzX9bBtCwWMZ+z2djuVyxYHZ6aHD0uld5ZRZWJ45FLUHwiwmTLkXNvec8TOOULOtdlMmeixQOBabHTUqOID6GgJtpF1dTm5pjdTG8wPDgEwufaa2egAl/3N2hkOhYH6IFMquJTLUsnmxFRrVBwXAFOtUcnmoFKR3WLxF4BPRHiZXF1JnT1/Z6S3N5wIhfSobQtA4ly/dgRD1qZU95eSq8uWCJYxRpx0en3R2Vkqd3exXzhQ16vhejX2Dw603N1FfG8n7qTT654xYjVYkM5sfS+3tlLy+XQrnzdb+bwpHfFpNdzG9nY2Iw1uPhFRVRUReRQ53dM/NT429vPLVwBORfp45uzGHy/FZxudOjQFsUS0uampf/rq1O3g8RYL4Hex4N1/8vRhsfrnvdY/0b91d/ImSktIgQAAAABJRU5ErkJggg==", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADAUlEQVR42mVTS2hUZxT+zn8fSY2ZOEZj0jwUra0kJVFRu7AlRR0tpOq6ohupUuhC0D7ALkIWLsQHBFy4Ky2Cha4jWNEWm4U4EjWTSTqZUJOWGjLeSebOjMmde+/8XxczaY0eOIvz5HznfAdYKaKUetVeDSBSiQiMSkxWFLxWTK11A4DYsdgnvZ2bN7cJoCamZ2Zu3B4aBnBbKeVqrQUAVzSqdt96fH/sx8TNn/OMPyYTE2RinIw/5pMbP+VOHDj0A4At6pVJDACiRKjJ5lOfHr1y/fx3n73d0FCjnSyZcytafImW5ubavt7enhdOtvVRauJ3JVIgIEJSlAi733n327uXr15oDKn83AIN01KGVBCWSZTDQNvRqGTA8r6vz50f/zN9SZOiLNMkgfUn+w73NYphhJNp2oueMnIu6Dig48DIubAXPRWm0mwyLfOLI0ePEFhvmSZNkgDQ2t3e3sGpZzCz80hOTwMkuhrXAQCSWQcQQVd9BJx6hp6Ojk0A2km+MKvLrLWAGpnLIJGaxO7huyCJiVgfAGDnnSGICB5+uF+6DRPGhrUWABsklIgCAHfe8wpY8ljKZFDxCXwnC9/JAhCIKPiZDOGVuOAtFQDkRQTLEGaG05Njh7fv3rrxYRy/dPaAmtigTADAnc7tECXYGGrBlk3y28iDUQDTBGCQVCLij0ylg4MHYh81WXbEnp1jY02tuGGIRV1Gk2WjPgxZv3OHPF235vmX1wYv6iAY1aRSAGiIYKlY/PVWcmxEtbbw77zL2cBHIQxQCAPMBiX8lXdptLXyXjr1ZKlYvKcqJ6aJ/znpBSUvqItGJVhdx8AvEVIlQkiirg6romukmBrzAJSWeWwAQJVMQTz1x2LXng/e37trV/Po/fsSgPDCAPlCQT4+/bkM5eYTZ68NXqXWSU0KAP73TP39/WpgYEArq+Zk/OLlwUhZv1X2fQCAsm3JCV7u+earM9DB98u5b3wjSURE1ja0tB3rfG9bi5TLlSTLUKPJ8X+Kc89vuuRCFRkB4F9pgoN7aJfjVAAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEU0lEQVR42n1VTWxUVRT+zn1v5k1bWkCqwzDYFhtaW0hqUAllGoL1h7jRWFIL0URjiNFECJqIusJFo5tGNv5sDGEjtkyCYWUCYkyptGAxBdtm2s6Q/tDS4nRm2pk3b+a9d+9xMR1+pHqTuzn3ni/nnvN93wVWX0IQQde0hw50TYMgAgCxWiKtFtSEgFRqPYAmQNQ/Xlm5QQCYiscTgBoHcEMTIi6VIgD8X4AEAMwMInpuz7btB97b/3ro2e3bgo9UVJQChER62RocGbn13Zmey72jw93M/CvRXQh+qFpmFgAOfv7mW5eyl/odHo4wDw4xDwwW9uAQ8/AYZ/v6nS/ePtQH4OBKzl1UvQgmhGAieuHLd9498unhI7sQj0NORBUR0UrPoJjBzFyyZo3+2dGjocIRLQohzquV52sAhBCCfUoFXtzZfOzrY5/s41uzQDwOTSpBtkOwbYJtE9kOCcchlUqxMk2EQqHgn5GIZ2Zm+ndJlGGARLF5WaD544NvtGhpU2BqmpExyU0koRJJIJkCkimoRBJuIgmYJmFqhrWMKT7q6NidBXat9JJ0IlJSKRH0B55qqqrayGPjoKU0CcOA0DRASsB1C1zS9UJMSahcXvDYBJpqagJVGzc1Tc/PnSMipa/M3dtY88Sj5YAXM7MQIOqPTqAnNo6O2q1o9m8CAPQvzKEnNoGO2jo0+wPgdBoV1Zu9dTXV/un5OYOAXHEomsfj0Slvg+IJxHMW2n47j/mlJLpjUYw9/zIA4LWLP2NhOYWemzH8tfclVBo+iLwNn+HzAtBAdHfK+ek7d5JZsCrLWsJNJgFmwOsFwHATqXtUK8YWk+D162Eyy5tztxcB5MAMXTGTIHJHo5GxaSubeHJzYEPZ/DxObW2ks3duo63SDx8XOHuqtgE/xRfQ9lgAZfk8y+BGTFlmMhIbjwgiqZiFAEBEBKXUlZMXLwxpLbspLoAdRgm6ttTh6bJyLLo2Fl0bz5SVo2tLHXYYpYgToO8J0clfLgwppa4UFSMAKKkU8fHjo1+dPn2md3YmGmx7leZMkydzFhbsPEzXhem6WLDzmMxZmDXTHGx7hXrnZmInun8I83GOrOhaFR2DPJ2dClAD12IT82QYnLbznFcKWekiIyUyUiIrXeSVQsa2mXw+vhaNLgC46unUVVF++r8FbXg8Xo/hpSwrdlwH94m/MBaWcFjB4/WSR2gCgHzAqe5dZPj9fnPgxo2qfa2tddv37imNXv2Dl5eWkJMuLMeGaWUBw8ctHx5G1HX+fv9E19mytRXn0um0s6p9UYEs1ZrHOHT7xzMfLPddXjcZicDwlRS4lbOwpbERa0PNKf+B/d9Ix/megEku4PADFRadWhMiJaWbtXL5hp2trRXrGupz5fV1Vnn9VmvttgZLBgOZru7T1wdGR77VhBhRBfvi/3Ns0d7eTuFwuAVAk+4tIaUkF/4FjVzbkgCut7e3Xw6HwwxA3Z/8D2veL79ZOL+BAAAAAElFTkSuQmCC" },
    SupplyBox = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAB10lEQVR42m2Rz0uTcRzH35/P93n2m60pZel6pJaSwaJDePEQRBfTEBKRCOoQXUIC+wdGnr0EdayLp3aRwGOHILpFpHNgTsjRY2u1zW3Oue15nu+ngxkhvY5v3q/L+w38AzGDmJEGeGYGKpPJKBFRAAjHOAosAGfxf/5KTEQAMDS/+HJvfvFV3TTN2Z6oMTp+6/bco7nHzwHEDisgAsCJRMK/W95Zeri8PV1ruhhbm8LVERPr7Xu4cfMuUpcuvAlUG3cepNMdBqDtYmXS6qHpA9fRrU5XRi8G5MrlMPpOGJqJ3DMxPWUDkwsLT7UCEB9MxF9YJ4MDXq2I9uZ7/vYlT583HHz4aFMu+wmVH9uAEbBq9dYyWdb5idfP7q8MD8bELnyneMSAqyJwPYGiLsrVBpLn+mVr54BmnyxNGH3WcDskP7XUy6yI4VRWYSrAJMDxAG546BbWKKRG9Kn+ZMfwG4BdaqC0lcWvBiEWZhhMEACeFtRbGrtVgRutw28ABrNmn8/Pe802mi2CAkPx4YaeFjRbGkEWhHv9DHHI+Jov5PLFgexQ8lrKrex7kZDJ9EcQEcF+V6K9EbVpO6sbuXzu6L3TY9fHU0Gf0sfvFRHyPJJ3b1fWAZR+A+Hvvq9W7OO3AAAAAElFTkSuQmCC", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACuElEQVR42p2TS2hcZRTHf+f77mMemWSSScYmViU1sUVLRQNCFxIqZNONqFQRsQsRUwQXFuqiiyoIXQhu3IivhYi4cOuqVIuIuOrCKvXVB2lRGtOZZB73zr1z7/2OiyYlbXb+d+fB//wOhwN3a3HRW1hY8AF7V0X4H7JHjmABa63FWrvDaHtgAFtrNF6o1Rqz7RvXziZJ8tNWk+6kuSNljTEAT7z5/md67p+b+tTzr1wBDjebzacheOb4ibe+fXX52DfAjIhsDbw9WcJmc49nOPPSx9/np29odvDl48OvTz+kv59b0uUXH9HVta5evvSnliqV7yCc1VsUZstFXZQsz++yS77NzOq683ZPqH/o8bru3Teqi4/WiaK40Hzg5qeDQ9Y3x4zcWsEIOAjnxkvuudHQaRZ1sdaQ9jp0+pmQ5tJa71PkQ5ukmVS9oY7XeFY1nBNwApigUvngwAPV1yu+wx+/l3Byt/SuXuD+KWFsLOTS1S5TM/O4ItfrK3+R5JYLK/GHwzh6Q4Bd75w4+utrR59spO2WttsdKYcBI2N1kqFSFI5yyaPX6xEnGfdMjWswVpNPv/ihdeq9z/d7QLZ/bro17V1pFI1JLfl1CeI/qBYrqAWxICqMmJwNl9HMPS2baXl4fqYFZB6g7Y2uu3j+Gp2swkZs8OLLlHxFNy9tRIhSR5Q4/h5RJps3abf3OEA9AOt5OAzx2m90u1Crlgl8j2LTwYpQaEGhQq7gJMBaIwAeIK5Qc3214/5dy1xnIHTjPuVAcLcJYDBU4tQR951LpUrh7mPLIF7vp9HSwQOmFFw0GxFUS5ZqyeI2CYwIUVIQpQX1Cmb2wX38/ONgAESewOCjL8+cDPzD705MPDYaM9DQefiZ3UYgZC4n1ZzIVuSX81Hvk6/Ovg2k258pBEZ2/s0OGaAHpAD/AUzPLrz8esYiAAAAAElFTkSuQmCC", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADpElEQVR42q2Uy2ucZRSHn/fyzXyTyUwyk2TSaFtLk2K1C1GDtpG27iz1SqCgbRfdCIWurFA3YvAPqEUENy4UpQt1pS6k1EupUuyNWgiGGLEtVhNz6WRu38x3PS5moglEBOlZvfBynt+5w7+b4i6ZmpiY0NoYREQBeh0h/X8EV4PMgQMYwCilsNaitf7PLNTExIQGilu2bf9o9zPj13Y8uuuc69pdquOm2w8LDAOFdYTXmO2oPn3indMyKSIfX/tduopDnwPjme78UeDZ0Z1PvH/yrVOzLx06fBl4QLVFzLrpuYWBMeDscye/8N+YkejlM+Vw24Nb6+fee0wmzz4lbx7dlLz62uuJiMilS5dFOekfrOvuXs1YKa4AXVHgnxgZUE926ZbTCMS0/JbdeX86u3esjx3bu+WFPX0M9UAYhiKRl2zbYEdBH2dwMNthKA1oBYLJ7OvPqtFSXtmUm8FYRcrNkklbCBPBFxXFQneXqxzHUa7rqlLe6P6cHqXc2KfaQK2BZBjSWsvBwTwDUSJUf7mCXy3TvHmV+dkFZucDVW0E3J7z1cz0FJXlO8xMT9Js+WpDXpe0RC8OM5IG4k7/nCNDA+6pkaFUTxSL0gpsd4HIqxEFPtmuFE5K43kRfhBRLPbRqNcIwpC0Y+TnWX95bsE/DuEHClBjjz/0/YdvHxszUSsBdLlah0QoFHuQBJJEEBG0VhhrWFxaxhhDb083JEkS6pQ+8sq75y9cvL7XAjK8ddOfw5vS0vxtGjc3iAk8JKyz0a0TRAm6k4cIOFaDqSEibM704Lc8MpsfkZGt9y1euHgd2254yo/mb6jF21PSO7IFcSyNuUnmygvE2E4DV4CKxaUAgLTn4jdrbMz0K1E2WJl6JInU1K0a09dvkr3xCfOVAIlaDOQdoqS1asMEaxQLlRCAueWYVsOjmruDSPT3GmGM4Z5SjnLBkslEREEAylIqOISxrMKBYxSJtCMu9To0U5Z7S3mMaS+LbU+3cGu2Ir/+4ZPNpVmsxCARTV+IkrVAqxVL1XaErVDRqPnkZiuitfwDbDT9oFgsqjhoxl4todloOzSNsy6w6bX/PdMiDvykt1CwtdpPYfsgKMXX31098+P+hw/tP3zMxl6dO5UWgtBfyJLEyRqgNpqlsocAfT1pTCanL0/V+fb8lS+1UigRlFKgnezB8ef37Cvkup0obEegOnVZuU/JCjiOQSHWOqrqNf1PP/vmq6TlnRbpjMPdtL8ATEWjzhoEAOsAAAAASUVORK5CYII=" },
    CorpseSkull = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAACJElEQVR42lWRXUhTcRyG3//Z2XDtnOWOLnXNDY0Z2zqYLBeRi/zIUVKryKhYXYjeWCDSB110s6u6qQiEvEiCQERysYKQPohcmQQbWS5IJDEtI2fTnKSeufProqJ8rh5enrsX+Af7K+6t7spyj8f738bWRI2NjRqXy0WCkGf3bNtyy2bJ94FWWfxN4nn72VBTS0vwSygUYgCyAMB0Oi04jkN3d1eYiIiU2SwtTWeJVLrd1RnhOA46nRYAGA+AFCVTBIAvdzq8Tc2nso5NNgYwjI1PZc+dafaqqmpXFFVhwFcNAP+li6fvGQxCbbGteP1QbNgkGvRYXl5hk5+nOaulaH5uPrX7yOF97YOvYqMIHNjzODkxSA96O+Zq6+uHxkaiarink/p6btJYIqrW+f2x+70dc8mJl7S/oe6RJtBQc9VSkGf4kV7McZbZremfGbawkCZFyUDJENtcarZwjHJAhJnZlJGZ8vOPbijI2zX+8VN0b+2OoMvtrvZUlAtEKuLxd+mRROLFk4HXd0pL7L6Z5PcoLxj0knGd3lhcYJYkU66xxCoJb4fjyxzHYNsoiZNTolhozpVEIUdML+olFjwRSPmrt5u+JVPIKKuIDb+PhCPPbvC8Vj0UqGmvkB0HeY0GlkIzHj4dTEGWnX3Xr1ygttbgEoBja279zfG21pMr1y6fJ7e77C4A+Hw7vaOy7OwHIBIRA8AD4P+4KMvO/qqqyg8AfL8AwZHViPl4dB0AAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADjElEQVR42m1Ta0xbZQA93723DuiF29LSTl7WSZG68mhTGbGAY0PLJjKWrJu4ReZ+kBgTNdGYGDdL3JIlGqMm06nzh+jiBrIYkWzAXiZkZCLlZcsoq7S821KgUFZo6e7nn5mQyElOcpKTc3L+HOD/YDZpxSNu5W0JBgBKSkqMH59ubG1vax1vb7/yz9mzZ1oAiQEAbDbb1iVWq5UFgH01NabBAXuYUkopXaN0I0gpfUBbf/lpQaHYbiKEAAC7OUsAMJRSAoA5deqD3yiNULoeiK4ujovhoFuMhadilEZoY+PJDgCsRML9t5YwACgAkRACtRqJu8t2GYftPXT/wVcl/YNDZGD4b1J75AQ3ZO+hFeW7igRBSNnYiDMARACUy8zMTFwMh9/UaXeY7X0D/cnSRNJ5s5tcu3aDGo0FAICrV69jb4WZVJSXYXl5+e0iQ0HBiMvTo0oVvmJXVlZq3nrjtU++/eIjw+S0L9s1Prd2vO6Aci0Ww+FaC9HuyAbDSfD6MSv5+vvmWU22qqjlh8+e24jFTB1df9xjdDpt/UsvmhOj6xHx0IG9/MWfm2em5+ajJ99rIEOOMQw7xvDhuw3EFwjFLrdcmX3l4At8NBoRqy2lSTqdtp7dZ3n+zKGaPaqZWT9Jf1zFmwxPawILEZZjCPH5/RDFh9i2LQEu9ySpsRRrCnZq+fn5RZKVqeJG3ZMcO+0L7nwYj2d03r7rvnj59yF9Xo5yaSmUxEikEFJSaDKfgpVInMzOeMARGjr96YXu0fsT4bH7E2j+tauDAJAAqAPgBdAL4J2y0uKjlsrSHLlMSACA4MJitOvmnbE7PX2XAHwOoBiABsAl9rGEpPctlebjgkzQA/TZo4era1+uKtNmpacl3HO5Q8vLoaghP1ea/4xWnpGhzprzLzyZm/tUVWF+XqV3yifjzCWFJ+rrqrU+f9BEQbFdpUSv3bF6u/uvtoHBkQsAUKDPa9hdbrKYiwt1uTlP6AgAtUqBtfV1GRcILvrGvdOalGQp5w8sRM5919LpdnvOA7jFMEQEgGHH6K1hx+ieNk1Ww7Ej+6vS1UqpZ2ImHgguzTFOh6upb3DkASgld+3ONbfb8yXLMDesVisRRcqIImVsNhtlGea61zt17k+7c51SSnr7nasjTteP4Hk+Ta5SNhmMepeQmvqNXC4XAHCPPrL5L5xcLheSZbLzBoPeJSgVTTzPp/0LMYiBnOcBWWAAAAAASUVORK5CYII=", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAFGElEQVR42oVUWUxUZxg9/38HZpgdBmYQsCxBJFGKuACigzFtJVEfTI0lNlgepBVjo23TNk1rnNC0jS9t2pqmjdFUg9UIWqhag3UrIpugIqjsoMgywAzDHWZhlnu/vmjbpLU9TycnOV/O+R4O8BwQERcE4R865xw2m40/z8eeo3MAMoBM67p12/Nzc5YQOOvsevjgt7q6UwC6bTYbr6iokPF/sNlsnDGG/fttZTW1Z51z4jQReYkkkbxuO1VWHnXEJyaWMMb+M+mfxwBAoVJZb7U2yUREAZ8YnnONSrOT/ZLoGAoReai66oRXoVAVcs6ftfnX6sL169cVAHhZ2c4zQe8Ehb2jIZqfII9zgDzOAZL9YxR0PwpT2Em7yned+5tHePY+/pSQwLlUVLQhHBcXp87PX74iQhlBX3z1HS95812IoghRnMUbb72Pg18f5iCJ8nNzluv1ekNR0YawwLkEgAAwxVOSKMnyFikoY3p6utsSZ8JQXy878PkhYN6DwtUrAAAnKk8BKg1e37qRLbDEwu125wJIexqqFsCYQqfTmSAIX+4tL9kQHW1AxWff3Ol60MvWrFqCxYtS8GjwMRIWxAEgKNU6pKQlIzragO5LjdBq1R/YPnlnmcslskOHf7JCkvYAQPFr2zb3Tz9uptnxNtr3dmlfQlJyw+jwveCNy1VUU3WEeu5eoZ67V6im+gjVXzpNk0/uh5LTMlr27N7RI463k+NxM23btqkfQLFgMpkOfrivNFOtUio9Hg+RjHD12QuPdMbYmLzlSzRadSRVVv/KOu73wpq3DAZjNE7XXnad+6V2aHdZ8Qs6rUoz5/HAHBstXLvRbhTy8pa9V7ZjS1owGGAgsMxFydrsrMXJY3ZXVEZ6qtA/MMAYY9Bp1QgGAtDpjejo6onYWbIxZb11pdHnm2eSFGZJCRbVrY6HbmHW7Xs13mxKUEepFIeP14ze6+oNrluzQu9yOYWgHAlLnAlRqkgYDXqYTHEYnXQh5HMI2UszhMPHfp661tA+k/pCgv5mS4e/quZyNwOwSlCqtkcbDWbH5OQNAK6lSzO3bnylIC8Q5pasrGxVMBgAAERGKnGv845fIGmy7mpze09P/1kA+liLpdA1K05LgflTAmNsXA6H/T6v16XRaC6EQqH2qSmHoWdwJNma96JGoyIdR5BxCjA55GUBv3/qh2NnhsZHJy4BqNSYzSPi1JRAUriZMdbMwIRPc1dlFaenLtRevNrUqVWrQpuLrPmFBctjYox6Ycrhws2WDrskyVS4OsdiMcdwp0sM1zfcdl643NDu8QX4ppcLsvuGn8zdbuusYukZaa0f7S1dadBr+eDwE79Wq4lamGTB8KMxam7rstc33mmwT9h/BKAwxcaWrreuLFibn70gLSWRPX5ih8fr9y1KS1LPih754LfH2xUAyD3nIfeclwx6XdSc1+c/erx2rKGl45ZrZuYkgKuc83kAcDoc187U1L10tb612Jqfk7e2ICfRaNCqR0YniTGSAZAw43Sla3Xa1LTkBIMkSWhu65ypOX/l+3m//2POeTeAMBEJRMQZY0HOeZ/f57/Y2z+s0ul1yxYmmLWCwNnvjXfHm5pun+cATrbdfTg5bp8OOV1iqG9wxKtUKts4Y/OyLEcQEQMgAZCIiMmyHMEZm1cqla19AyNep1MMjU9Mh9rvddsjgJNPF4eXx1rMjfGJ8U0APwBA+byd+2vR05UAP2BZEN9kMsfeBHg5AP4HFL51kNB+IwEAAAAASUVORK5CYII=" },
    Bolt = { [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAABvklEQVR4nIxRWyiDYRi2/fbLxkxy+nOYkUU51E+KkNOU44ULTSSjJNyQC+LGldwoFy6EO7lwSoRGDoklltmoicbIzw5E2/7Zfn/53tXWkgvfxff1fN/7PO/3PC83AC0+n08E/HNhsGW292pzugZGwiUp8jfNWQyO43aGYV7+InBAvX75UB+ZlRPqvXSYKLdxZ+P+Xa9VXc/PrLhcrnVfB6Rk47Lf+eLK+tTj0f6Hz9sbOihMhIlltURCaVV2mlzREJEsbX493lNBVy6waIvpBM5widR1OjaYu9ZQXLLZUj0EAoJoAk+sqEliWdbj00OgVAdKy+W5DR4QjKVpWu2m7VHZnf2eIsP6khXDMMpnmsfjcUQSaWtcUbmIcdhtwaFCUlxe2wYYhHZ6mvqcTue2jwA+hNGxJeDDuL9FZCp6ZVFknvD5aPfDsL1qLhydbGQdNrNVf3XB8bpHaZEdd45zLwZlO/XkDiHicUjwdHxYo5ueqMa8BfAt5stZFldQGqObmaSU3XIFTxAiSG/uJOEd7h8PlRjHfygwE5QGiQyqkXEKcKKsbrFiaiEfOkJ6gf4EKILQfuE5VJyBIp6F9H4AAAD//6jF3CUAAAAGSURBVAMABzTE+WMgRmkAAAAASUVORK5CYII=", [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACj0lEQVR4nKRTbUhTYRT23jt3bbnNj2xtKW06yj9iuJXTVaNAK5o5+yDqTwTin8iMEKKkQMgfkkWBMSWQRF2ky60JmQY2R7WZm64Z4tS1qY19FYPV2lrbumdwYyuiovPj3HPP+57nnPOc86Jp/ykYKBqNxmELK1rDPrcIwzBGNBq1/i0ABdSGUmGzTKlt+ux2fg26nGGvxeT0mPSLVpVCg6KoMRgMGn8HgIDKF5QPHNHoT/58CIAekyHgsRhXzfIOVTweN4XDYc0vAEQLglqldiKvVEh/0XrRDj7Ojl103sG63GQwqM72VLVs6b5VT1aV4CA9PR3JKtx2mlVWTv+06nDP3L4uWRoZnFrTjbtdBp0vHovlIgiaBgmy+cU5IZ+nwD03q4BYFBSB5lxUD2jBzisp4xAfNpS68mrywpsHPTXjZ09dtqoVH+B8PYtD9TuWl1JIBPG9NT/3mqeltE0cPBaLSQlXokQcx2vqhnU3IDv8Q4s+83QfGYf+MFB0xPX6ZQAy8A7IqkluEASRkncs9+4453vl4uSpYKQRiUQCDBZ7L3d/7VYUxWgrY+p1skeTXYKmFqG+7dIak8unLih7P1KzsjeGvC4quStY0kTScDpjZ/GJMyIqg0mJRb8VETaLmknH2KI99IdV27VMHj9H2j96CM9kSOwTozdTWkjwQPRG8JBoQ3y1gwu+d0+GE+QRrfh3t3VyybsZGRnXYIORZABwbKk+PFh1V1FJEjbX09kIduWVdnlJfSMneS/6RIXHKMkAME7H2OPjqqOSZs/MlB+IJcaZIGxh6P75zM0FOLlcNs2Qj3g3xpQK/iRE2V0Nti8NkL2/ouhcKBTqpvwLQL54n93Q3jL7XvdsHoLB9x0AAP//TwwvswAAAAZJREFUAwCaOBt7IAa9qAAAAABJRU5ErkJggg==", [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADMklEQVR4nKyUbUhTURjHr/fObW3OxOGcy0wzJgUiuESnkJppCxO1glAiqMwvgV8ypOyLH5KQIjIqGIoZqYSyWY6cSvlStEwn6mi+pG7m3M2ZbTJbzjntPOaV6/SDSQ9c7jn3POd3nnP+/3Nx7D8HQTU4HI7I29tbjB4vl8tlx3YZG8CwE+m9MYUl+ewAwQXbl/4UBoMhZjKZCwhOYv8QXuvVSVIevWgJO5XNpwZ+zZiXJpoafnzv0xgN6sbW1dXVPqfT2bRToCg4Ma1dVqkUb5cEcEtft93c88Gur36qQ3AVjuNah8Oh3RYIESyJrT3T9CkHJqtyZSN7Q8NZEecu8n1E+5kBUUd5ngtA9SMN1UO2seEiOnjjDJesc/yQJFmSX3gEh+zuGp969yZ9TFX/efhlldHQrHRbJ0bxPX58gisUsZg+PCIwOpZ3IDUj2NTVJrbPkM+3AJEAmN/BiLOQiOMEx9CsaFxcXOxYXl7uhAnz+oF6fV2lxqhWCgAeknjSD8DQhjHKGThtJ+S0pn0BGgIEXVlZOU3fJtqWmSAIs9vlEogzczbEM3W22WGM6uP0Cd/a1R3Q5gaKmGGyrDTMI5BwteffDkbCmcI5qq9kj9onxy/Rc/BNHRyXzw70rpUujJaGgp2gDS5gs9n5+6TJPlQuCGfqbE32VBr3KILUlt9ZM7IwJh62LQEoWCr1cW2pvq5ijloQXLC+mIQOYGAe5+SwkLCimIPURG+AXaf8CWdbIw3X+YuP2Kxfh2xxN+/2OH5aLDr5gzyqUsKjwk32mR3U8iQFxUHcv3AMVGVyfbERRU1ZfHHZ5ci8AhHLx5eL1G9zu92j2wLp9gmKO8YDMAigzEzQcwVChqH11bwXjkuPP3x2CPL75fdJ92+H2DVvZSOLab08gSCA/+HIe3BrqG+gJhIgF1Uhgn7ak7oq+r2H6C673Y+2ns7wBK55akhXqMiIwwJjEqTkx45x2vXSgggL01NOqBrywWLwNra8JmDulgp3EiwWKwNZ7GqWoisJPKmrKDdrSotK0M2S47sBwm8M/XFIcAJUimAqgMEYge0ykHik3TQZ9f7WNR2q9gZ1l/8AAAD//zUxjRMAAAAGSURBVAMAgvaW7bnbqeUAAAAASUVORK5CYII=" },
}
-- @@END ICONS@@
-- ===================== Fonts, icons and 3D FX (gallery only) =====================
Visual.FXC = {
    ink = Color3.fromRGB(8, 8, 10), white = Color3.fromRGB(255, 250, 240), hot = Color3.fromRGB(255, 196, 92),
    orange = Color3.fromRGB(255, 120, 32), red = Color3.fromRGB(255, 60, 60), cyan = Color3.fromRGB(70, 230, 255),
    mint = Color3.fromRGB(110, 255, 200), gold = Color3.fromRGB(255, 214, 64), violet = Color3.fromRGB(180, 110, 255),
}
Visual.fx = { fontId = {}, fonts = {} }
Visual.FONT_FILES = {
    { "Rajdhani", "Rajdhani-Bold.ttf", "rajdhani/Rajdhani-Bold.ttf" },
    { "ChakraPetch", "ChakraPetch-Bold.ttf", "chakrapetch/ChakraPetch-Bold.ttf" },
    { "Orbitron", "Orbitron.ttf", "orbitron/Orbitron%5Bwght%5D.ttf" },
    { "ShareTechMono", "ShareTechMono-Regular.ttf", "sharetechmono/ShareTechMono-Regular.ttf" },
}
-- Font.Data takes the TTF BYTES (assigning the Font object to Text.Font turns it into a numeric id). Fonts are downloaded once into
-- workspace hush/fonts, loaded at startup, removed on unload.
Visual.loadFonts = function()
    local fx = Visual.fx
    if next(fx.fontId) then return end
    if not isfolder("hush") then makefolder("hush") end
    if not isfolder("hush/fonts") then makefolder("hush/fonts") end
    for _, row in Visual.FONT_FILES do
        local path = "hush/fonts/" .. row[2]
        if not isfile(path) then
            local res = request({ Url = "https://raw.githubusercontent.com/google/fonts/main/ofl/" .. row[3], Method = "GET" })
            if res and res.StatusCode == 200 then
                writefile(path, res.Body)
            else
                warn("[hush] font " .. row[1] .. " download failed: " .. tostring(res and res.StatusCode))
                continue
            end
        end
        local font = Drawing.new("Font")
        font.Data = readfile(path)
        local probe = Drawing.new("Text")
        probe.Font = font
        fx.fontId[row[1]] = probe.Font
        probe:Remove()
        fx.fonts[#fx.fonts + 1] = font
    end
end
-- Default UI font is Chakra Petch; a number is a built-in Drawing font; unknown names fall back to 0.
Visual.fxQ = 1 -- segment-count scale: 1 in the gallery, lower for live shots
Visual.fxFont = function(f)
    if f == nil then f = "ChakraPetch" end
    if type(f) == "string" then return Visual.fx.fontId[f] or 0 end
    return f
end
Visual.loadFonts()

-- ---- Icons: one pooled drawer for the live ESP and the gallery ----
-- PNG bytes are decoded once per name; Images are high-water pooled per name; step() calls flush() once a frame.
Visual.icon = { sets = {} }
for _, tier in { 12, 16, 20 } do Visual.icon.sets[tier] = { pool = {}, used = {}, shown = {}, bytes = {} } end
-- Pixel-exact PNG per tier (12/16/20 px, stroke weight tuned per tier, dark outline baked in): the image is
-- never resampled, so it stays crisp at 600+ st where the icon is small. Edge tier from the box height.
Visual.icon.size = function(boxH)
    local s = boxH * 0.22
    return s < 14 and 12 or (s < 18 and 16 or 20)
end
Visual.icon.draw = function(name, x, y, size, alpha)
    local set = Visual.icon.sets[size]
    local list = set.pool[name]
    if not list then
        list = {}
        set.pool[name], set.used[name], set.shown[name] = list, 0, 0
        set.bytes[name] = crypt.base64decode(Visual.ICON64[name][size])
    end
    local n = set.used[name] + 1
    set.used[name] = n
    local im = list[n]
    if not im then
        im = new_draw("Image")
        im.Data, im.ZIndex = set.bytes[name], 28
        list[n] = im
    end
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    local c = im._cache
    if c.ix ~= x or c.iy ~= y then im.Position = Vector2.new(x, y); c.ix, c.iy = x, y end
    if c.isz ~= size then im.Size = Vector2.new(size, size); c.isz = size end
    im.Transparency, im.Visible = alpha, true
end
Visual.icon.flush = function()
    for _, set in Visual.icon.sets do
        for name, list in set.pool do
            for i = set.used[name] + 1, set.shown[name] do list[i].Visible = false end
            set.shown[name], set.used[name] = set.used[name], 0
        end
    end
end
Visual.icon.free = function()
    for _, set in Visual.icon.sets do
        for _, list in set.pool do for _, im in list do im:Remove() end end
        table.clear(set.pool); table.clear(set.used); table.clear(set.shown); table.clear(set.bytes)
    end
end
Visual.fxFree = function()
    Visual.icon.free()
    for _, font in Visual.fx.fonts do font:Remove() end
    table.clear(Visual.fx.fonts); table.clear(Visual.fx.fontId)
end

Visual.c01 = function(x) return x < 0 and 0 or (x > 1 and 1 or x) end
Visual.oe = function(x) x = Visual.c01(x); return 1 - (1 - x) ^ 3 end
Visual.ob = function(x) x = Visual.c01(x) - 1; return 1 + x * x * (2.70158 * x + 1.70158) end

-- 3D ribbons: camera-facing strips in world space, width in studs, every profile goes to zero at the ends.
Visual.shapeF = {
    function(u) return math.sin(math.pi * u) ^ 0.6 end,          -- 1 spindle: sharp at both ends
    function(u) local e = math.min(u, 1 - u) * 9; return e > 1 and 1 or e end, -- 2 flat body, sharp tips
}
Visual.trK = 1 -- widths/jitter scale with distance (set around the style call)
Visual.tr = { A = Vector3.zero, B = Vector3.zero, D = Vector3.zero, side = Vector3.xAxis, up2 = Vector3.yAxis }
Visual.trSet = function(A, B)
    local R = Visual.tr
    local D = B - A
    local side = D:Cross(Cam.CFrame.LookVector)
    side = side.Magnitude < 1e-3 and Cam.CFrame.RightVector or side.Unit
    R.A, R.B, R.D, R.side, R.up2 = A, B, D, side, D.Unit:Cross(side)
end
-- mode 0 straight, 1 helix (amp/turns/phase), 2 jag (amp/seed). Alpha ramps aTail -> aHead along the strip.
Visual.ribbon = function(pen, s0, s1, n, w, shape, col, aTail, aHead, fade, mode, amp, turns, phase)
    local R = Visual.tr
    n = math.max(4, math.floor(n * Visual.fxQ))
    local A, D, side, up2 = R.A, R.D, R.side, R.up2
    local sf, env = Visual.shapeF[shape], Visual.shapeF[1]
    local pl, pr
    for i = 0, n do
        local u = i / n
        local c = A + D * (s0 + (s1 - s0) * u)
        if mode == 1 then
            local ph, e = turns * 6.2832 * u + phase, amp * env(u)
            c += side * (math.cos(ph) * e) + up2 * (math.sin(ph) * e)
        elseif mode == 2 then
            local e = amp * env(u) * math.sin(i * 12.9 + phase)
            c += side * e + up2 * (e * 0.6)
        end
        local half = w * sf(u) * 0.5
        local l, r = c + side * half, c - side * half
        if pl then
            -- Uniform alpha across shared edges: per-piece alpha steps made the strip look tiled.
            local a = aHead * fade
            pen.quad(pl, pr, r, l, col, a)
        end
        pl, pr = l, r
    end
end
-- Billboard ring (camera plane) at world point C
Visual.bring = function(pen, C, r, col, alpha, n)
    local cf = Cam.CFrame
    local ax, ay = cf.RightVector, cf.UpVector
    local prev, first
    for i = 0, n - 1 do
        local a = i / n * 6.2832
        local p = C + ax * (math.cos(a) * r) + ay * (math.sin(a) * r)
        if prev then pen.thin(prev, p, col, alpha, 1.8) else first = p end
        prev = p
    end
    pen.thin(prev, first, col, alpha, 1.8)
end

-- Tracer styles: 1 Lightning (Visual.boltTracer, also on the live path), 2 Helix, 3 Rail. Gallery loop 2.8 s: shot at 0.15 s, round flies 0.22 s, trail fades 0.9 s.
Visual.trNames = { "LIGHTNING", "HELIX", "RAIL" }
Visual.trStyles = {
    function(pen, t, p, f) -- lightning: same bolt the live path draws, here over the gallery segment
        local R = Visual.tr
        Visual.boltTracer(pen, R.A, R.A + R.D * p, f, t, os.clock())
    end,
    function(pen, t, p, f) -- helix = rifling: pitch fixed in studs, the twist runs toward the impact, the strands tighten into the line as it fades
        local C, R, k = Visual.FXC, Visual.tr, Visual.trK
        local len = R.D.Magnitude * p
        if len < 1 then return end
        local pitch = math.max(7, R.D.Magnitude / 12) -- long shots stay under ~12 turns
        local turns = len / pitch
        local n = math.clamp(math.floor(turns * 9), 24, 120)
        local spin = -t * CFG.HelixSpin
        local amp = CFG.HelixRadius * k * (1 - 0.85 * Visual.oe(f)) * math.min(1, 0.35 + len / 20)
        local w, a = 0.075 * k, 1 - f
        Visual.ribbon(pen, 0, p, n, w, 1, C.mint, 0.1, 0.55, a, 1, amp, turns, spin)
        Visual.ribbon(pen, 0, p, n, w, 1, C.violet, 0.1, 0.55, a, 1, amp, turns, spin + math.pi)
        Visual.ribbon(pen, 0, p, 8, 0.06 * k, 2, C.white, 0.7, 1, a, 0)
    end,
    function(pen, t, p, f) -- rail: thin core + 3D rings perpendicular to the path, spawned as the round passes
        local C = Visual.FXC
        local R = Visual.tr
        Visual.ribbon(pen, 0, p, 8, 0.08, 2, C.white, 0.3, 1, 1 - f, 0)
        for k = 1, 3 do
            local sk = k * 0.25
            local kk = Visual.c01((t - 0.15 - 0.22 * sk) / 0.55)
            if kk > 0 and kk < 1 then
                local c, rr, al = R.A + R.D * sk, 0.25 + 1.1 * Visual.oe(kk), 0.85 * (1 - kk)
                local prev, first
                for i = 0, 7 do
                    local a = i / 8 * 6.2832
                    local pt = c + R.side * (math.cos(a) * rr) + R.up2 * (math.sin(a) * rr)
                    if prev then pen.thin(prev, pt, C.violet, al, 1.7) else first = pt end
                    prev = pt
                end
                pen.thin(prev, first, C.violet, al, 1.7)
            end
        end
    end,
}
-- Rail trail: a comet-shaped wake along the whole path from four stacked low-alpha ribbons plus a thin core; while fading the tail slides to the tip.
Visual.WAKE = { Visual.FXC.violet, Visual.FXC.mint, Visual.FXC.violet }
Visual.wake = function(pen, from, tip, fade)
    if (tip - from).Magnitude < 1 then return end
    Visual.trSet(from, tip)
    local C = Visual.FXC
    local col = Visual.WAKE[CFG.TracerStyle] or C.violet
    local live = 1 - fade
    local a = 0.2 * live * live
    local w = 0.14 * (1 - 0.5 * fade)
    local pull = Visual.oe(fade)
    for k = 0, 3 do
        local s0 = k * 0.22
        s0 = s0 + (1 - s0) * pull -- the tail slides to the tip while it fades
        if s0 < 0.98 then Visual.ribbon(pen, s0, 1, 6, w * (1 + (3 - k) * 0.15), 2, col, 0, a, 1, 0) end
    end
    Visual.ribbon(pen, 0.35 + 0.65 * pull, 1, 6, w * 0.4, 2, C.white, 0, 0.5 * live * live, 1, 0)
end
-- One station: 7 styles, each a real 3D segment (muzzle near/left -> impact far/right), staggered in time.
Visual.drawTracers = function(pen, st, age, label)
    local look = st.look
    local right = Vector3.new(-look.Z, 0, look.X)
    for i = 1, #Visual.trStyles do
        local h = 0.7 + (i - 1) * 1.6
        local A = st.feet + right * -5 + look * -2.4 + Vector3.new(0, h + 0.35, 0)
        local B = st.feet + right * 5 + look * 2.6 + Vector3.new(0, h - 0.2, 0)
        local t = (age - i * 0.37) % 2.8
        local p, f = Visual.c01((t - 0.15) / 0.22), Visual.c01((t - 0.37) / 0.9)
        if p > 0 and f < 1 then
            Visual.trSet(A, B)
            Visual.trStyles[i](pen, t, p, f)
        end
        local sp = Cam:WorldToViewportPoint(A + right * -0.4)
        if sp.Z > 0.1 then label(Visual.trNames[i], sp.X - 64, sp.Y - 6, Visual.FXC.white, 1) end
    end
end

-- ---- Hit markers: a billboard at the world hit point, born stretched OUT and pulled IN with a back-out snap ----
Visual.hitNames = { "PULL-IN", "PULL-IN + RING", "WEDGES", "CRIT + DMG" }
Visual.hitArms = function(pen, C, gap, len, col, alpha, w)
    local cf = Cam.CFrame
    local ax, ay = cf.RightVector, cf.UpVector
    for q = 0, 3 do
        local a = math.pi / 4 + q * math.pi / 2
        local d = ax * math.cos(a) + ay * math.sin(a)
        pen.seg(C + d * gap, C + d * (gap + len), col, alpha, w)
    end
end
Visual.hitScale = 1 -- >1 only inside the live loop: keeps the marker readable at range
Visual.hitStyles = {
    function(pen, C, e, gap, len, a)
        Visual.hitArms(pen, C, gap, len, Visual.FXC.white, a, 2.2)
    end,
    function(pen, C, e, gap, len, a)
        local F = Visual.FXC
        Visual.hitArms(pen, C, gap, len, F.cyan, a, 2.2)
        local k = Visual.c01((e - 0.12) / 0.4)
        if k > 0 and k < 1 then Visual.bring(pen, C, (0.25 + 1.4 * Visual.oe(k)) * Visual.hitScale, F.white, (1 - k) * 0.9, 10) end
    end,
    function(pen, C, e, gap, len, a)
        local F, cf = Visual.FXC, Cam.CFrame
        local ax, ay = cf.RightVector, cf.UpVector
        for q = 0, 3 do
            local ang = math.pi / 4 + q * math.pi / 2
            local d = ax * math.cos(ang) + ay * math.sin(ang)
            local sd = ax * -math.sin(ang) + ay * math.cos(ang)
            local tip, base = C + d * gap, C + d * (gap + len)
            pen.tri(tip, base + sd * (len * 0.5), base - sd * (len * 0.5), F.orange, a * 0.22)

            pen.tri(tip, base + sd * (len * 0.2), base - sd * (len * 0.2), F.hot, a)
        end
    end,
    function(pen, C, e, gap, len, a)
        local F, cf = Visual.FXC, Cam.CFrame
        Visual.hitArms(pen, C, gap, len, F.red, a, 2.6)
        local r = (0.5 + 0.9 * (1 - Visual.ob(e / 0.16))) * Visual.hitScale
        local ax, ay = cf.RightVector * r, cf.UpVector * r
        local p1, p2, p3, p4 = C + ay, C + ax, C - ay, C - ax
        pen.thin(p1, p2, F.gold, a, 1.8); pen.thin(p2, p3, F.gold, a, 1.8)
        pen.thin(p3, p4, F.gold, a, 1.8); pen.thin(p4, p1, F.gold, a, 1.8)
    end,
}
-- Real own-round state, retained after Rounds removes it from its active array. No extra raycast/predicted target.
Visual.liveFx = { records = {}, cursor = 0, lines = {}, hits = {}, hitCursor = 0, activeUntil = 0 }
Visual.attachRoundsFx = function(client)
    local f = Visual.liveFx
    if f.module or f.failed then return end
    local inst = client:FindFirstChild("Rounds")
    if not inst then return end
    local mod = require(inst)
    local ballistics = require(ReplicatedStorage.Shared.Ballistics)
    -- upvalues of Rounds.fly by ROLE: Ballistics = the module table, the array = the one table upvalue without string keys; anything else is ambiguous and fails closed.
    local states, bal = nil, nil
    for _, v in debug.getupvalues(mod.fly) do -- getupvalue(fn, i) past the last slot throws "index out of range" on this executor
        if type(v) == "table" then
            if v == ballistics then
                bal = v
            elseif next(v) == nil or type(next(v)) == "number" then
                states = states == nil and v or false
            end
        end
    end
    if bal ~= ballistics or not states then
        f.failed = true
        warn("[hush] Rounds.fly layout changed; custom shot FX not attached")
        return
    end
    f.module, f.flyOld, f.landOld = mod, mod.fly, mod.land
    f.ballistics = ballistics
    f.flyHook = function(args)
        local out = f.flyOld(args)
        if running and args.own and (CFG.BulletTracer or CFG.HitMarker) then
            f.activeUntil = os.clock() + 5
            local state = states[#states]
            if state and state.key == args.key and state.origin == args.origin then
                f.cursor = f.cursor % 24 + 1
                local row = f.records[f.cursor]
                if not row then row = {}; f.records[f.cursor] = row end
                row.state, row.born, row.endAt, row.pos = state, os.clock(), nil, nil
                f.last = row
            end
        end
        return out
    end
    f.landHook = function(key, pos)
        local out = f.landOld(key, pos)
        if running and typeof(pos) == "Vector3" and (key == "own" or string.sub(key, 1, 4) == "own:") then
            f.landPos, f.landAt = pos, os.clock()
            for _, row in f.records do
                if row.state and (row.state.key == key or (key == "own" and row == f.last)) then row.pos = pos end
            end
            if f.hitPending and f.landAt - f.hitPending < 0.5 then
                Visual.addHitFx(pos)
                f.hitPending, f.landAt = nil, nil
            end
        end
        return out
    end
    mod.fly, mod.land = f.flyHook, f.landHook
end
Visual.addHitFx = function(pos)
    local f = Visual.liveFx
    f.hitCursor = f.hitCursor % 8 + 1
    local h = f.hits[f.hitCursor]
    if not h then h = {}; f.hits[f.hitCursor] = h end
    h.pos, h.at = pos, os.clock()
    f.activeUntil = math.max(f.activeUntil, h.at + 1)
end
Visual.hitAck = function()
    if not CFG.HitMarker then return end
    local f, now = Visual.liveFx, os.clock()
    if f.landAt and now - f.landAt < 0.5 then
        Visual.addHitFx(f.landPos)
        f.landAt = nil
    else
        f.hitPending = now -- Hit carries no world position; wait for the own-round land, never use lastAim
    end
end
-- Rounds.drawnAt: the drawn bullet is path(t) + (muzzle - origin) * (1 - t/0.03). A named function, not a closure built per tracer per frame.
Visual.drawnAt = function(f, r, ext, mz, tt)
    local pt = (ext and ext.pathAt(r.path, tt)) or f.ballistics.arcAt(r.origin, r.v, r.drop, tt)
    if mz then
        local w = 1 - math.clamp(tt / 0.03, 0, 1)
        if w > 0 then pt += (mz - r.origin) * w end
    end
    return pt
end
-- Bolt tracer (TracerStyle 1): one jagged bolt muzzle > bullet with forks and an iridescent gradient. The zigzag is smooth noise between two 24 Hz re-rolls,
-- the bolt lives TracerFade s after the landing.
Visual.hn = function(i, k, s)
    local x = math.sin(i * 12.9898 + k * 78.233 + s * 37.719) * 43758.5453
    return (x - math.floor(x)) * 2 - 1
end
Visual.boltPts = {}
Visual.boltFork = {}
-- The bolt is projected once per frame and every strip is built in screen space from that. S = { x, y, nx, ny, k, ok }: screen position, unit normal, pixels per stud, in front of the camera.
Visual.boltS = { x = {}, y = {}, nx = {}, ny = {}, k = {}, ok = {} }
Visual.boltProject = function(pts, n)
    local S = Visual.boltS
    local x, y, nx, ny, k, ok = S.x, S.y, S.nx, S.ny, S.k, S.ok
    local px = Cam.ViewportSize.Y / (2 * math.tan(math.rad(Cam.FieldOfView) * 0.5))
    for i = 1, n + 1 do
        local sp = Cam:WorldToViewportPoint(pts[i])
        x[i], y[i], ok[i] = sp.X, sp.Y, sp.Z > 0.1
        k[i] = sp.Z > 0.1 and px / sp.Z or 0
    end
    for i = 1, n + 1 do
        local i0, i1 = math.max(i - 1, 1), math.min(i + 1, n + 1)
        local dx, dy = x[i1] - x[i0], y[i1] - y[i0]
        local m = math.sqrt(dx * dx + dy * dy)
        if m < 1e-4 then nx[i], ny[i] = 0, 1 else nx[i], ny[i] = -dy / m, dx / m end
    end
    return S
end
-- strip with half-width w * sin(pi u)^0.5 / 2 studs (at least 0.6 px), colour per piece from irid, `mix` towards white
Visual.boltStrip = function(pen, S, n, w, alpha, now, hueShift, sat, mix)
    local irid, white = Visual.irid, Color3.new(1, 1, 1)
    local x, y, nx, ny, k, ok = S.x, S.y, S.nx, S.ny, S.k, S.ok
    local lx, ly, rx, ry, was
    for i = 1, n + 1 do
        local u = (i - 1) / n
        local half = math.max(w * (math.sin(math.pi * u) ^ 0.5) * 0.5 * k[i], 0.6)
        local ax, ay, bx, by = x[i] + nx[i] * half, y[i] + ny[i] * half, x[i] - nx[i] * half, y[i] - ny[i] * half
        if was and ok[i] then
            local col = irid((u + hueShift) % 1, now, sat)
            if mix > 0 then col = col:Lerp(white, mix) end
            pen.quadS(lx, ly, rx, ry, bx, by, ax, ay, col, alpha)
        end
        lx, ly, rx, ry, was = ax, ay, bx, by, ok[i]
    end
end
Visual.boltTracer = function(pen, A, B, fade, elapsed, now, opacity)
    local D = B - A
    local L = D.Magnitude
    if L < 1 then return end
    local live = (1 - fade) ^ 1.3
    local flick = fade > 0 and (0.78 + 0.22 * math.sin(now * 55)) or 1
    local alpha = live * flick * (opacity or 1)
    if alpha <= 0.01 then return end
    Visual.trSet(A, B)
    local R = Visual.tr
    local side, up2 = R.side, R.up2
    local k = math.clamp((B - Cam.CFrame.Position).Magnitude / 120, 1, 1.6) -- widths and jitter scale with distance
    local n = math.clamp(math.floor(L / 8), 8, 32)
    local rate = elapsed * 24
    local blk = math.floor(rate)
    local frac = rate - blk
    local e = frac * frac * (3 - 2 * frac)
    local hn = Visual.hn
    local amp = 0.14 * k
    local pts = Visual.boltPts
    for i = 0, n do
        local u = i / n
        local env = math.sin(math.pi * u) ^ 0.6
        local a1 = hn(i, blk, 1.3)
        local n1 = a1 + (hn(i, blk + 1, 1.3) - a1) * e
        local a2 = hn(i, blk, 4.1)
        local n2 = a2 + (hn(i, blk + 1, 4.1) - a2) * e
        pts[i + 1] = A + D * u + side * (amp * env * n1) + up2 * (amp * 0.6 * env * n2)
    end
    local w = 0.05 * k * (1 - 0.5 * fade)
    local drift = now * 0.05
    local S = Visual.boltProject(pts, n)
    Visual.boltStrip(pen, S, n, w * 1.8, 0.25 * alpha, now, drift, 0.6, 0.15) -- soft glow
    Visual.boltStrip(pen, S, n, w, 0.9 * alpha, now, drift, 0.35, 0.5)        -- core
    -- two bright pulses running down the bolt (before the forks: they reuse the main bolt's projection)
    for j = 0, 1 do
        local u0 = (elapsed * 1.6 + j * 0.5) % 1
        local i0, i1 = math.floor(u0 * n) + 1, math.floor(math.min(u0 + 0.06, 1) * n) + 1
        if i1 > i0 and i1 <= n + 1 and S.ok[i0] and S.ok[i1] then
            local h0, h1 = math.max(w * 0.5 * S.k[i0], 0.6), math.max(w * 0.5 * S.k[i1], 0.6)
            pen.quadS(S.x[i0] + S.nx[i0] * h0, S.y[i0] + S.ny[i0] * h0, S.x[i0] - S.nx[i0] * h0, S.y[i0] - S.ny[i0] * h0,
                S.x[i1] - S.nx[i1] * h1, S.y[i1] - S.ny[i1] * h1, S.x[i1] + S.nx[i1] * h1, S.y[i1] + S.ny[i1] * h1, Color3.new(1, 1, 1), 0.63 * alpha)
        end
    end
    -- forks: short zigzags leaving the main bolt (projected on their own, 7 points)
    local nF = math.min(3, 1 + math.floor(L / 200))
    local fk = Visual.boltFork
    for f = 1, nF do
        if math.abs(hn(f, blk, 9.1)) > 0.25 then
            local u0 = 0.08 + 0.84 * math.abs(hn(f, blk, 1.7))
            local idx = math.clamp(math.floor(u0 * n) + 1, 1, n + 1)
            local origin = pts[idx]
            local dirf = (R.D.Unit * (0.35 + 0.4 * hn(f, blk, 2.9)) + side * hn(f, blk, 3.3) + up2 * hn(f, blk, 4.4))
            if dirf.Magnitude > 0.05 then
                dirf = dirf.Unit
                local fl = math.clamp(L * 0.03, 2, 8) * (0.4 + 0.6 * math.abs(hn(f, blk, 6.6)))
                local m = 6
                for i = 0, m do
                    local u = i / m
                    local jit = side * (hn(i + f * 7, blk, 7.7) * fl * 0.12) + up2 * (hn(i + f * 7, blk, 8.8) * fl * 0.12)
                    fk[i + 1] = origin + dirf * (fl * u) + jit * math.sin(math.pi * u)
                end
                Visual.boltStrip(pen, Visual.boltProject(fk, m), m, w * 0.55, 0.35 * alpha, now, drift + 0.2, 0.7, 0.35)
            end
        end
    end
end
Visual.stepLiveFx = function(now)
    local f = Visual.liveFx
    if not f.module then return end
    -- idle frames cost two comparisons: draw only while a round/marker is alive, and clear once afterwards
    if now > f.activeUntil then
        if f.drawn then
            f.drawn = false
            local pen = Visual.pens[f.lines]
            if pen then pen.used, pen.triUsed, pen.quadUsed = 0, 0, 0; pen.finish() end
        end
        return
    end
    f.drawn = true
    if not f.lines[1] then for i = 1, 320 do f.lines[i] = new_line(21, 1) end end
    local pen = Visual.pen(f.lines)
    Visual.fxQ = 0.6
    local budget = 5 -- tracers drawn per frame: a bolt is ~150 Quads, rapid fire must not turn into hundreds of them
    for _, row in f.records do
        local r = row.state
        if r and budget > 0 then
            local elapsed = now - row.born
            if r.done and not row.endAt then row.endAt = now end
            local fade = row.endAt and (now - row.endAt) / (CFG.TracerFade or 0.95) or 0
            if elapsed > 4 or fade >= 1 then
                row.state = nil
            elseif CFG.BulletTracer then
                local t = math.min(r.t or elapsed, r.endT or r.tEnd)
                local ext = r.path and Visual.physExt() -- GunPhysics rounds carry a path; the old arc is only the fallback
                -- Rounds.drawnAt: the drawn bullet is path(t) + (muzzle - origin) * (1 - t/0.03). The origin is the HEAD, which in first
                -- person is the camera eye: a ribbon from there is edge-on and collapses, the game itself starts at the (view-model) muzzle.
                local mz = r.muzzle
                local tip = row.pos or Visual.drawnAt(f, r, ext, mz, t)
                local tail = Visual.drawnAt(f, r, ext, mz, math.max(0, t - 0.09))
                if (tip - tail).Magnitude > 0.02 then
                    budget -= 1
                    local id = Visual.trStyles[CFG.TracerStyle] and CFG.TracerStyle or 1
                    local from = mz or r.origin
                    if id == 1 then
                        Visual.boltTracer(pen, from, tip, fade, elapsed, now)
                    else
                        Visual.trK = math.clamp((tip - Cam.CFrame.Position).Magnitude / 120, 1, 2.2)
                        if id == 3 then -- rail: the dart tail -> tip plus the optional wake over the whole path
                            if CFG.TracerTrail then Visual.wake(pen, from, tip, fade) end
                            Visual.trSet(tail, tip)
                        else -- helix: the whole path muzzle -> round
                            Visual.trSet(from, tip)
                        end
                        Visual.trStyles[id](pen, elapsed, 1, fade)
                        Visual.trK = 1
                    end
                end
            end
        end
    end
    if CFG.HitMarker then
        for _, h in f.hits do
            local e = now - h.at
            if e < 0.75 then
                local q = Visual.ob(e / 0.16)
                local a = Visual.c01(e / 0.04) * (1 - Visual.c01((e - 0.3) / 0.45))
                local style = Visual.hitStyles[CFG.HitMarkerStyle] or Visual.hitStyles[3]
                -- world size is ~1 stud: at 200 st that is a few pixels. Grow with distance so the on-screen size
                -- stays what it is at 45 st (cap x10).
                local s = math.clamp((h.pos - Cam.CFrame.Position).Magnitude / 80, 1, 5) * 0.65
                Visual.hitScale = s
                style(pen, h.pos, e, (1.15 - 0.95 * q) * s, (0.95 - 0.53 * math.min(q, 1)) * s, a)
                Visual.hitScale = 1
            end
        end
    end
    Visual.fxQ = 1
    pen.finish()
end
Visual.stopLiveFx = function()
    local f = Visual.liveFx
    if f.module then
        if f.module.fly == f.flyHook then f.module.fly = f.flyOld end
        if f.module.land == f.landHook then f.module.land = f.landOld end
    end
    for _, line in f.lines do line:Remove() end
    table.clear(f.records); table.clear(f.hits)
end

Visual.drawHits = function(pen, st, age, label)
    local look = st.look
    local right = Vector3.new(-look.Z, 0, look.X)
    local cf = Cam.CFrame
    for i = 1, 4 do
        local C = st.feet + right * (-5 + (i - 1) * 3.3) + Vector3.new(0, 3.6, 0)
        local e = (age - i * 0.2) % 2.2 - 0.25
        if e >= 0 and e < 1.0 then
            local q = Visual.ob(e / 0.16)
            local gap = 1.15 + (0.2 - 1.15) * q        -- stretched out -> pulled in, overshoots past rest and settles
            local len = 0.95 + (0.42 - 0.95) * math.min(q, 1)
            local a = Visual.c01(e / 0.05) * (1 - Visual.c01((e - 0.3) / 0.45))
            Visual.hitStyles[i](pen, C, e, gap, len, a)
            if i == 4 and a > 0 then
                local sp = Cam:WorldToViewportPoint(C + cf.UpVector * (0.9 + 0.9 * Visual.oe(e / 0.7)))
                if sp.Z > 0.1 then label("-87", sp.X - 12, sp.Y, Visual.FXC.gold, a, "Orbitron") end
            end
        end
        local sp = Cam:WorldToViewportPoint(C - Vector3.new(0, 1.7, 0))
        if sp.Z > 0.1 then label(Visual.hitNames[i], sp.X - 40, sp.Y, Visual.FXC.white, 1) end
    end
end

Visual.mockLabel = function(value, x, y, color, alpha, font)
    Visual.mockTI += 1
    local t = mockText[Visual.mockTI]
    t.Center, t.Font = false, Visual.fxFont(font)
    put_text(t, value, color, x, y, alpha or 1)
end
Visual.mockSeg = function(a, b, c, d, col, alpha, thick)
    local pen = Visual.mockPen
    pen.used += 1
    local line = mockLines[pen.used]
    if line then put_line(line, col, thick, alpha, 20, a, b, c, d) end
end
local function draw_mock(dt)
    if #stations == 0 or not Loot.galleryVisible or not Cam then hide_mock(); return end
    Loot.mockHidden = false
    local pen = Visual.pen(mockLines)
    Visual.mockTI = 0
    local label = Visual.mockLabel
    for _, st in stations do
        st.phase += dt * 0.7
        local age = os.clock() - st.born
        local beat, k = station_beat(age)
        local point = Cam:WorldToViewportPoint(st.feet + Vector3.new(0, 5.2, 0))
        if point.Z < 0.1 then continue end
        label(st.kind .. " / " .. beat, point.X, point.Y - 20, COL_PAPER)
        local from = st.feet + Vector3.new(-2, 2.2, 0)
        local targetFeet = st.feet + st.look * 3.7
        local to = targetFeet + Vector3.new(0, 2.8, 0)
        if st.kind == "KA" then
            local cycle = age % 4.6
            Visual.ka(pen, { center = st.feet, look = st.look, reach = SLEDGE_REACH,
                ready = cycle < 0.7 and 0 or (cycle < 1.6 and (cycle - 0.7) / 0.9 or 1),
                wind = beat == "CHARGE", tick = k, phase = st.phase, from = from, to = to, feet = targetFeet,

                lock = math.clamp((cycle - 1.6) / 0.18, 0, 1),
                impact = beat == "SHOOT" and (1 - k) or 0 })
        elseif st.kind == "SA / SOCCER" then
            -- 6 s loop: direct player (inside priority radius) -> bent through a peek -> NPC with lead
            local t = age % 6
            local tgt = { model = st, bone = { Size = Vector3.new(1.2, 1, 1) }, raw = to,
                pos = t >= 4 and to + st.look * 0.9 or to, dist = 90 + t * 110,
                tier = t < 2 and 0 or (t < 4 and 1 or 2), peek = t >= 2 and t < 4 and (from + Vector3.new(0, 1.2, 1.4)) or nil,
                lead = t >= 4 and 0.9 or 0 }
            Visual.aim(pen, tgt, from, os.clock(), true)
        elseif st.kind == "TRACERS" then
            Visual.drawTracers(pen, st, age, label)
        elseif st.kind == "HIT" then
            Visual.drawHits(pen, st, age, label)
        elseif st.kind == "LOOT" then
            local t = age % 5
            local revealed = t >= 2.6
            local p = Cam:WorldToViewportPoint(st.feet + Vector3.new(0, 1.4, 0))
            local size = math.clamp(900 / math.max(p.Z, 1), 18, 90)
            local box = { minX = p.X - size * 0.6, maxX = p.X + size * 0.6, minY = p.Y - size * 0.45, maxY = p.Y + size * 0.45 }
            local rare = Color3.fromRGB(75, 145, 235)
            local color = revealed and rare or Color3.fromRGB(96, 214, 255)
            Visual.mockPen = pen
            local cx, top, bottom = Loot.art(Visual.mockSeg, box, color, revealed)
            label("Crate  12 st", cx - 30, top - 14, color)
            if revealed then
                label("Rare rifle", cx - 22, bottom + 3, rare)
                label("Bandage x2", cx - 26, bottom + 16, Color3.fromRGB(150, 150, 150))
            else
                label("? not de$rypted", cx - 40, bottom + 3, color)
            end
        else
            -- Review stage only: stable world placement, event-like fade in/hold/out, no idle breathing.
            local bottom = Cam:WorldToViewportPoint(st.feet)
            local h = math.max(10, bottom.Y - point.Y)
            local w = h * 0.62
            local roles = Visual.galleryRoles
            for r = 1, #roles do
                local role = roles[r]
                local cx = (bottom.X + point.X) * 0.5 + (r - 2) * (w + 78)
                local cycle = math.max(0, age - (r - 1) * 0.09) % 7
                local fade = math.min(math.clamp(cycle / 0.22, 0, 1), math.clamp((6.8 - cycle) / 0.65, 0, 1))
                local settle = 1 - math.exp(-cycle * 18)
                local y = point.Y + (1 - settle) * 6
                local proxy = Visual.mockActors[r]
                for i = 1, 48 do proxy.lines[i] = mockLines[pen.used + i] end
                pen.used += 48
                draw_corner(proxy, cx - w / 2, y, cx + w / 2, bottom.Y, role.color, 1.35, beat == "AIM", 3, fade, role.round)
                label(role.name, cx - w / 2, y - 20, role.color, fade, role.font)
                label("124 st", cx - 20, bottom.Y + 4, COL_DIST, fade, role.font)
                label(role.weapon, cx - w / 2, bottom.Y + 19, CFG.WeaponRarity[role.rarity].color, fade, role.font)
                if role.armor ~= "" then label(role.armor, cx - w / 2, bottom.Y + 34, COL_DIST, fade, role.font) end
                -- Icons scale with the box (Visual.icon.size), so they shrink with distance like the box does.
                local isz = Visual.icon.size(bottom.Y - y)
                if isz > 0 then
                    for k, name in role.states do
                        Visual.icon.draw(name, cx + w / 2 + 6, y + (k - 1) * (isz + 3), isz, fade)
                    end
                    if role.armor ~= "" then Visual.icon.draw(Visual.ARMOR_ICON[role.armor:sub(1, role.armor:find(" ") - 1):lower()], cx - w / 2 - 8 - isz - 3, bottom.Y - isz, isz, fade) end
                    Visual.icon.draw("Bolt", cx - w / 2 - 8 - isz - 3, y - isz - 3, isz, fade)
                end
                -- Simulated damage: .16s drain plus a slower trailing damage rail.
                local hp = 1 - 0.36 * math.clamp((cycle - 3.2) / 0.16, 0, 1)
                local tail = 1 - 0.36 * math.clamp((cycle - 3.38) / 0.6, 0, 1)
                pen.used += 1
                put_line(mockLines[pen.used], COL_INK, 5, fade, 18, cx - w / 2 - 8, y, cx - w / 2 - 8, bottom.Y)
                pen.used += 1
                put_line(mockLines[pen.used], COL_RUST, 2, fade * 0.65, 20, cx - w / 2 - 8, bottom.Y, cx - w / 2 - 8, bottom.Y - (bottom.Y-y) * tail)
                pen.used += 1
                put_line(mockLines[pen.used], PAL.hpHigh, 2, fade, 21, cx - w / 2 - 8, bottom.Y, cx - w / 2 - 8, bottom.Y - (bottom.Y-y) * hp)
            end
            label("GLOW / 0.22s IN / 0.65s OUT / FONT 0-1-3", bottom.X - 130, bottom.Y + 57, COL_DIST)
        end
    end
    pen.finish()
    for i = Visual.mockTI + 1, #mockText do mockText[i].Visible = false end
end

local LOOT_BOXES = 8
local LOOT_LINES = 67 -- 8 boxes x 8 flat corner strokes + 3 search indicators; no glow/snapline
local LOOT_TEXT = 20 -- 3 full boxes x (title + 3 items) + 5 one-line boxes = 17
local lootLines = {}
local lootText = {}
local searchPrompts = {}
local lootKnown = {}
for i = 1, LOOT_LINES do
    lootLines[i] = new_line(14, 1.3)
end
for i = 1, LOOT_TEXT do
    lootText[i] = make_text(24)
    lootText[i].Size = 13
end

Loot.stats = { queries = 0, rows = 0, maxRows = 0, totalMs = 0, maxMs = 0, moves = 0, rebuilds = 0, cells = 0 }
Loot.scan = { [0] = { rows = {}, keys = {} }, { rows = {}, keys = {} }, { rows = {}, keys = {} } }
Loot.dirtyCell = function(key)
    for _, cache in Loot.scan do
        if cache.keys[key] then cache.dirty = true end
    end
end
Loot.moving = {}
Loot.movingAt = 0
Loot.waiting = {}
Loot.byPart = {}
Loot.knownAt = 0
Loot.expireKnown = function(now)
    if now < Loot.knownAt then return end
    Loot.knownAt = now + 10
    -- TTL must expire while away too, not only when that box is queried again.
    for part, info in lootKnown do
        if not part.Parent or (info.changed and now - info.changed >= 600) then
            lootKnown[part] = nil
            local prompt = Loot.byPart[part]
            local row = prompt and searchPrompts[prompt]
            if row then
                row.sStamp = nil
                if Loot.scan[1].keys[row.key] then Loot.nextQuery = 0 end
            end
        end
    end
end
Loot.key = function(p)
    return Loot.cell(math.floor(p.X / 64), math.floor(p.Y / 64), math.floor(p.Z / 64))
end
Loot.cell = function(x, y, z)
    return ((x + 512) * 1024 + (y + 512)) * 1024 + (z + 512)
end
Loot.move = function(row)
    Loot.stats.moves += 1
    local pos = row.part.Position
    row.pos = pos
    local key = Loot.key(pos)
    if key == row.key then return end
    if row.key then
        Loot.dirtyCell(row.key)
        local old = Loot.grid[row.key]
        old[row.prompt] = nil
        if next(old) == nil then Loot.grid[row.key] = nil end
    end
    row.key = key
    Loot.grid[key] = Loot.grid[key] or {}
    Loot.grid[key][row.prompt] = row
    Loot.dirtyCell(key)
    -- Moving containers anywhere in the world must not cancel the query cadence.
    -- The next scheduled query reads the updated buckets (at most 0.25 s later).
end
Loot.remove = function(inst)
    local row = searchPrompts[inst]
    if row then
        if row.conn then row.conn:Disconnect() end
        Loot.moving[inst] = nil
        local bucket = Loot.grid[row.key]
        Loot.dirtyCell(row.key)
        if bucket then
            bucket[inst] = nil
            if next(bucket) == nil then Loot.grid[row.key] = nil end
        end
        if row.econn then row.econn:Disconnect() end
        lootKnown[row.part] = nil
        Loot.byPart[row.part] = nil
        searchPrompts[inst] = nil
    end
end
-- Only an explicit empty marker is evidence; case is presentation, not state.
Loot.emptyText = function(text)
    return type(text) == "string" and string.find(string.lower(text), "%(%s*empty%s*%)") ~= nil
end
local function watch_prompt(inst)
    if not running or searchPrompts[inst] or not inst:IsA("ProximityPrompt") or inst.Name ~= "SearchPrompt" then return end
    local part = inst.Parent
    if part and part:IsA("Attachment") then part = part.Parent end
    if not part or not part:IsA("BasePart") then return end
    local row = { prompt = inst, part = part, born = os.clock(), retry = 0 }
    row.class = Loot.CLASS_OF[part:GetAttribute("ContainerType")] or "Other"
    searchPrompts[inst] = row
    Loot.byPart[part] = inst
    -- the server appends "(Empty)" to ObjectText of emptied containers: no decrypt needed to know
    row.empty = Loot.emptyText(inst.ObjectText)
    row.econn = inst:GetPropertyChangedSignal("ObjectText"):Connect(function()
        if not running or searchPrompts[inst] ~= row then return end
        row.empty = Loot.emptyText(inst.ObjectText)
        row.sStamp = nil
        -- A far-away emptied crate must not force a local search next frame.
        local center = Loot.viewOrigin
        if center then
            local delta = row.pos - center
            if delta:Dot(delta) <= CFG.LootRange * CFG.LootRange then Loot.nextQuery = 0 end
        end
    end)
    Loot.move(row)
    if not part.Anchored then Loot.moving[inst] = row end
    -- Anchored map containers never move. Only the dynamic subset is sampled on a fixed clock.
    row.conn = part:GetPropertyChangedSignal("Anchored"):Connect(function()
        if not running or searchPrompts[inst] ~= row then return end
        Loot.moving[inst] = not part.Anchored and row or nil
        Loot.move(row)
    end)
end

Loot.updateMoving = function(now)
    if now < Loot.movingAt then return end
    Loot.movingAt = now + 0.25
    for prompt, row in Loot.moving do
        if row.part.Parent and prompt.Parent then
            Loot.move(row)
        else
            local part = row.part
            Loot.remove(prompt)
            if part.Parent then Loot.watchContainer(part) end
        end
    end
end

Loot.watchContainer = function(part)
    if not running or not part:IsA("BasePart") then return end
    local prompt = part:FindFirstChild("SearchPrompt")
    if prompt then
        watch_prompt(prompt)
    elseif not Loot.waiting[part] then
        -- Tag replication may precede its prompt; this watches that container only.
        local conn
        conn = part.ChildAdded:Connect(function(child)
            if not running or Loot.waiting[part] ~= conn then return end
            if child.Name == "SearchPrompt" then
                watch_prompt(child)
                conn:Disconnect()
                Loot.waiting[part] = nil
            end
        end)
        Loot.waiting[part] = conn
    end
end
Loot.dropContainer = function(part)
    local waiting = Loot.waiting[part]
    if waiting then waiting:Disconnect(); Loot.waiting[part] = nil end
    local prompt = Loot.byPart[part]
    if prompt then Loot.remove(prompt) end
end

-- Slots retain server indices. reveal replaces a slot, never appends duplicates;
-- slot updates remove taken items, and an all-hidden open is not an empty box.
Loot.refresh = function(row)
    table.clear(row.items)
    row.hidden, row.rank = 0, 0
    local defs = items()
    for _, slot in row.slots do
        if slot.hidden then
            row.hidden += 1
        elseif type(slot.id) == "string" and (slot.qty or 0) > 0 then
            local def = defs and defs.Defs[slot.id]
            local rarity = def and defs.Rarity[def.rarity]
            local rank = rarity and rarity.order or 1
            row.rank = math.max(row.rank, rank)
            row.items[#row.items + 1] = {
                id = slot.id, qty = slot.qty, rank = rank,
                label = (def and def.name or slot.id) .. (slot.qty > 1 and (" x" .. slot.qty) or ""),
                color = rarity and rarity.color or COL_DIST,
            }
        end
    end
    table.sort(row.items, function(a, b) return a.rank > b.rank end)
    row.known = true
    row.changed = os.clock()
    Loot.nextQuery = 0
end
Loot.say = function(...)
    warn("[hush] auto decrypt:", ...)
end
local function note_loot(action, part, a, b)
    if not running or typeof(part) ~= "Instance" then return end
    local now = os.clock()
    local pending = Loot.pending[part]
    -- The user is holding E on this box: whatever opens is theirs, auto must neither close it nor hide its window.
    if pending and action == "open" and Loot.userPart == part and now - Loot.userAt < 4 then
        Loot.pending[part] = nil
        pending = nil
    end
    if not pending and action == "open" then
        -- A reply later than the 1.5 s NO REPLY window is still OURS. Treating it as a manual open
        -- parked auto forever (Loot.manual was cleared only by a close we never sent): the stall.
        local inst = Loot.byPart[part]
        local r = inst and searchPrompts[inst]
        local userOwns = Loot.userPart == part and now - Loot.userAt < 4 -- the user held E on it: never adopt
        if r and r.autoAt and now - r.autoAt < 8 and not userOwns then
            pending = { prompt = inst, sentAt = r.autoAt, lastEvent = now, dist = 0, late = true }
            Loot.pending[part] = pending
        end
    end
    if pending then pending.lastEvent = now end
    local row = lootKnown[part]
    if action == "open" and type(a) == "table" then
        row = { slots = {}, items = {}, known = true, total = 0, name = tostring(a.name or "Container"),
            searching = a.searching, searchStart = now, searchSecs = tonumber(a.left) or 0, changed = now }
        for index, slot in a.slots or {} do
            if type(slot) == "table" then
                row.slots[index] = { id = slot.id, qty = tonumber(slot.qty) or 0, hidden = slot.hidden == true }
                row.total += 1
            end
        end
        lootKnown[part] = row
        Loot.refresh(row)
        if pending then
            pending.opened, pending.openedAt = true, now
            Loot.say("opened at " .. string.format("%.1f", pending.dist or 0) .. " st -", row.name .. ":", row.total == 0 and "empty" or (row.total .. " slots, " .. row.hidden .. " hidden"))
        else
            -- the player opened this one by hand: auto stands down until it is closed
            Loot.manual = part
            for other in Loot.pending do Loot.closeOne(other) end
        end
    elseif row then
        if action == "reveal" and type(b) == "table" and type(b.id) == "string" then
            row.slots[a] = { id = b.id, qty = tonumber(b.qty) or 0 }
            if row.searching == a then row.searching = nil end
            Loot.refresh(row)
        elseif action == "slot" and row.slots[a] then
            row.slots[a].qty = tonumber(b) or 0
            Loot.refresh(row)
        elseif action == "searching" then
            row.searching, row.searchStart, row.searchSecs = a, now, tonumber(b) or 0.6
        elseif action == "close" and pending then
            local info = lootKnown[part]
            if pending.openedAt and now - pending.openedAt < 0.6 then
                Loot.say("the game closed it at once (client Looting is only enabled in Raid mode)")
            elseif pending.opened and info and info.hidden > 0 and Loot.maxPar > 1 then
                -- closed by the SERVER before its slots were revealed while another of ours was open
                for other, p in Loot.pending do
                    if other ~= part and p.opened and p.openedAt and p.openedAt >= pending.openedAt then
                        Loot.maxPar = 1
                        Loot.say("server keeps ONE open container: multi decrypt falls back to 1")
                        break
                    end
                end
            end
            Loot.pending[part] = nil
            Loot.nextAuto = now + 0.3
        end
    end
    if action == "close" and Loot.manual == part then Loot.manual = nil end
end

local function hide_loot()
    if Loot.hidden then return end
    Loot.hidden = true
    for i = 1, #lootLines do
        lootLines[i].Visible = false
    end
    for i = 1, #lootText do
        lootText[i].Visible = false
    end
end

Loot.COL_DARK = Color3.fromRGB(130, 130, 130)
-- ContainerType -> CFG.LootClasses key.
Loot.CLASS_OF = {
    WeaponCrate = "Weapons", CampArmory = "Weapons", BunkerArmory = "Weapons",
    AmmoCrate = "Ammo", TruckAmmo = "Ammo",
    MedicalCabinet = "Medical", MedicalShelf = "Medical", TruckMedical = "Medical", BunkerMedical = "Medical",
    Lockbox = "Valuables", Briefcase = "Valuables", Register = "Valuables",
    Crate = "Crates", SupplyCrate = "Crates",
    Toolbox = "Tools", HardwareShelf = "Tools",
    GeneralShelf = "Stores", GroceryShelf = "Stores", SportsShelf = "Stores",
    CarTrunk = "Vehicles",
    Drawer = "Household", Cabinet = "Household", Fridge = "Household", Locker = "Household", Dumpster = "Household",
}
Loot.classOf = function(name)
    return CFG.LootClasses[name] or CFG.LootClasses.Other
end
Loot.CORNERS = {}
for _, x in { -1, 1 } do
    for _, y in { -1, 1 } do
        for _, z in { -1, 1 } do
            Loot.CORNERS[#Loot.CORNERS + 1] = Vector3.new(x, y, z)
        end
    end
end
Loot.bufs = { [0] = { n = 0, rows = {}, d2 = {} }, { n = 0, rows = {}, d2 = {} }, { n = 0, rows = {}, d2 = {} } }
Loot.used, Loot.ti = 0, 0

-- Flat rarity-colored corners: exactly eight strokes, no glow/ink bed/entry animation.
-- Shared with the gallery so the preview cannot retain a more expensive alternate renderer.
Loot.art = function(seg, box, color, strong)
    local x0, x1, y0, y1 = box.minX, box.maxX, box.minY, box.maxY
    local lx, ly = math.max((x1 - x0) * 0.3, 5), math.max((y1 - y0) * 0.3, 5)
    local width = strong and 2 or 1.6
    seg(x0, y0, x0 + lx, y0, color, 1, width)
    seg(x0, y0, x0, y0 + ly, color, 1, width)
    seg(x1, y0, x1 - lx, y0, color, 1, width)
    seg(x1, y0, x1, y0 + ly, color, 1, width)
    seg(x0, y1, x0 + lx, y1, color, 1, width)
    seg(x0, y1, x0, y1 - ly, color, 1, width)
    seg(x1, y1, x1 - lx, y1, color, 1, width)
    seg(x1, y1, x1, y1 - ly, color, 1, width)
    return (x0 + x1) * 0.5, y0, y1
end

-- Shared accept test, no closure per query. mode 0 = all, 1 = ESP view, 2 = auto open.
Loot.accept = function(row, mode, now)
    if mode == 0 then
        return true
    end
    local info = lootKnown[row.part]
    local empty = row.empty or (info and (info.total == 0 or Loot.emptyText(info.name)))
    if mode == 2 then
        return not empty and row.prompt.Enabled and now >= row.retry and (not info or (info.total > 0 and info.hidden > 0))
    end
    if not Loot.classOf(row.class).on then return false end
    if CFG.LootHideEmpty and empty then return false end
    if info and info.rank < CFG.LootMinRarity and not (info.hidden > 0 and CFG.LootUnknown) then return false end
    if not info and not CFG.LootUnknown then return false end
    local _, on = Cam:WorldToViewportPoint(row.pos)
    return on
end
-- Union of nearby spatial cells per consumer (ESP/auto/query); only a cell-boundary change or a mutation inside it rebuilds the row array.
Loot.candidates = function(origin, radius, mode)
    local cache = Loot.scan[mode]
    local x0, x1 = math.floor((origin.X - radius) / 64), math.floor((origin.X + radius) / 64)
    local y0, y1 = math.floor((origin.Y - radius) / 64), math.floor((origin.Y + radius) / 64)
    local z0, z1 = math.floor((origin.Z - radius) / 64), math.floor((origin.Z + radius) / 64)
    if cache.dirty or cache.x0 ~= x0 or cache.x1 ~= x1 or cache.y0 ~= y0 or cache.y1 ~= y1 or cache.z0 ~= z0 or cache.z1 ~= z1 then
        cache.x0, cache.x1, cache.y0, cache.y1, cache.z0, cache.z1 = x0, x1, y0, y1, z0, z1
        cache.dirty = false
        table.clear(cache.rows)
        table.clear(cache.keys)
        Loot.stats.rebuilds += 1
        for x = x0, x1 do
            for y = y0, y1 do
                for z = z0, z1 do
                    local key = Loot.cell(x, y, z)
                    cache.keys[key] = true -- retain empty cells too: a streamed-in crate must invalidate
                    Loot.stats.cells += 1
                    local bucket = Loot.grid[key]
                    if bucket then
                        for _, row in bucket do cache.rows[#cache.rows + 1] = row end
                    end
                end
            end
        end
    end
    return cache.rows
end
-- Fills and returns a REUSED buffer {n, rows[], d2[]} sorted by distance (bounded insertion).
Loot.query = function(origin, radius, mode, cap)
    local started, scanned = os.clock(), 0
    Loot.updateMoving(started)
    local out = Loot.bufs[mode]
    local oldN, n = out.n, 0
    local r2 = radius * radius
    local rows = Loot.candidates(origin, radius, mode)
    for index = 1, #rows do
        local row = rows[index]
        scanned += 1
        if row.prompt.Parent and row.part.Parent then
            local info = lootKnown[row.part]
            if info and info.changed and started - info.changed >= 600 then lootKnown[row.part] = nil end
            local pos = row.pos
            local dx, dy, dz = pos.X - origin.X, pos.Y - origin.Y, pos.Z - origin.Z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 <= r2 and (n < cap or d2 < out.d2[n]) and Loot.accept(row, mode, started) then
                local at = n + 1
                for i = 1, n do if d2 < out.d2[i] then at = i; break end end
                if at <= cap then
                    if n < cap then n += 1 end
                    for i = n, at + 1, -1 do out.rows[i], out.d2[i] = out.rows[i - 1], out.d2[i - 1] end
                    out.rows[at], out.d2[at] = row, d2
                end
            end
        else
            local part = row.part
            Loot.remove(row.prompt)
            if part.Parent then Loot.watchContainer(part) end
        end
    end
    for i = n + 1, oldN do out.rows[i], out.d2[i] = nil, nil end
    out.n = n
    local st, ms = Loot.stats, (os.clock() - started) * 1000
    st.queries += 1
    st.rows += scanned
    st.maxRows = math.max(st.maxRows, scanned)
    st.totalMs += ms
    st.maxMs = math.max(st.maxMs, ms)
    return out
end
Loot.bounds = function(part, out)
    local cf, size = part.CFrame, part.Size
    -- Cache world-space corners. Projection changes with the camera; static geometry does not.
    if out.cf ~= cf or out.size ~= size then
        out.cf, out.size = cf, size
        out.corners = out.corners or {}
        local h = size * 0.5
        for i = 1, 8 do out.corners[i] = cf * (h * Loot.CORNERS[i]) end
    end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, 8 do
        local v = Cam:WorldToViewportPoint(out.corners[i])
        if v.Z <= 0.1 then return nil end
        minX, minY = math.min(minX, v.X), math.min(minY, v.Y)
        maxX, maxY = math.max(maxX, v.X), math.max(maxY, v.Y)
    end
    -- never smaller than a readable mark at long range
    local w, hgt = math.max(maxX - minX, 16), math.max(maxY - minY, 16)
    local cx, cy = (minX + maxX) * 0.5, (minY + maxY) * 0.5
    out.minX, out.maxX, out.minY, out.maxY = cx - w * 0.5, cx + w * 0.5, cy - hgt * 0.5, cy + hgt * 0.5
    return out
end
Loot.seg = function(a, b, c, d, col, alpha, thick)
    local used = Loot.used + 1
    Loot.used = used
    local line = lootLines[used]
    if line then put_line(line, col, thick, alpha, 16, a, b, c, d) end
end
Loot.text = function(value, col, x, y)
    local ti = Loot.ti + 1
    Loot.ti = ti
    local t = lootText[ti]
    if not t then return end
    put_text(t, value, col, x, y)
end
Loot.view = Loot.bufs[1]
local function draw_loot(dt, origin)
    if not CFG.LootViz or Visual.pvp.on then hide_loot(); return end
    Loot.hidden = false
    local now = os.clock()
    if now >= Loot.nextQuery then
        Loot.nextQuery = now + 0.25
        Loot.viewOrigin = origin
        Loot.view = Loot.query(origin, math.clamp(CFG.LootRange, 1, 180), 1, LOOT_BOXES)
    end
    Loot.used, Loot.ti = 0, 0
    local view = Loot.view
    for i = 1, view.n do
        local row = view.rows[i]
        local part = row.part
        local box = (part.Parent and row.prompt.Parent) and Loot.bounds(part, row.box or Loot.newBox(row)) or nil
        if box then
            local tier = i <= 3 and 1 or (i <= 6 and 2 or 3)
            local info = lootKnown[part]
            local list = info and info.items
            local empty = row.empty or (info and (info.total == 0 or Loot.emptyText(info.name)))
            local unknown = not empty and (not info or info.hidden > 0)
            local strong = not empty and info and info.rank >= 3
            local color = empty and Loot.COL_DARK or Loot.classOf(row.class).color
            local cx, top, bottom = Loot.art(Loot.seg, box, color, strong)
            -- strings are rebuilt only when the integer distance or the container data changed
            local dist = math.floor(math.sqrt(view.d2[i]))
            local stamp = info and info.changed or 0
            if row.sDist ~= dist or row.sStamp ~= stamp then
                row.sDist, row.sStamp = dist, stamp
                local title = info and info.name or row.prompt.ObjectText
                title = string.gsub(title, "%s*%(%s*[Ee][Mm][Pp][Tt][Yy]%s*%)", "")
                if title == "" then title = "Container" end
                row.titleStr = string.sub(title, 1, 18):lower():gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end) .. "  " .. dist .. " st"
                if empty then
                    row.countStr = "EMPTY"
                elseif info then
                    row.countStr = info.total .. (info.total == 1 and " item" or " items") .. (info.hidden > 0 and (" / " .. info.hidden .. " hidden") or "")
                else
                    row.countStr = "? not de$rypted"
                end
                row.lineStr = row.titleStr .. "  " .. row.countStr
            end
            if tier == 1 then
                Loot.text(row.titleStr, color, cx, top - 14)
                local y = bottom + 3
                if info and info.searching and info.searchSecs > 0 then
                    local frac = math.clamp((now - info.searchStart) / info.searchSecs, 0, 1)
                    Loot.seg(cx - 22, y + 2, cx - 22 + 44 * frac, y + 2, color, 1, 2.4)
                    y += 8
                end
                Loot.text(row.countStr, empty and Loot.COL_DARK or (unknown and color or COL_DIST), cx, y)
                y += 13
                if list and not empty then
                    for k = 1, math.min(#list, 2) do
                        Loot.text(list[k].label, list[k].color, cx, y)
                        y += 13
                    end
                end

            else
                -- one text object: name, distance and count together
                Loot.text(row.lineStr, color, cx, top - 14)
            end
        end
    end
    for i = Loot.used + 1, #lootLines do lootLines[i].Visible = false end
    for i = Loot.ti + 1, #lootText do lootText[i].Visible = false end
end
Loot.newBox = function(row)
    row.box = {}
    return row.box
end

-- Opening goes through SearchPrompt.Triggered (fireproximityprompt, reply ~110 ms); the client never sends an `open` packet.
-- Several boxes: every prompt is fired in the same frame, because Looting disables ProximityPromptService while a container is open.
Loot.pending = {}
Loot.userPart, Loot.userAt = nil, -math.huge
bind(game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
    -- only a real player hold raises this; fireproximityprompt does not simulate a button hold
    if prompt.Name == "SearchPrompt" then
        Loot.userPart, Loot.userAt = prompt.Parent, os.clock()
    end
end))
Loot.maxPar = 3
Loot.pps = cloneref(game:GetService("ProximityPromptService"))
Loot.closeOne = function(part)
    local p = Loot.pending[part]
    Loot.pending[part] = nil
    if p and p.opened and Loot.remote then Loot.remote:FireServer("close", part) end -- the game's own verb
end
Loot.finish = function()
    for part in Loot.pending do Loot.closeOne(part) end
    Loot.nextAuto = os.clock() + 0.25
    if Loot.module and Loot.module.isOpen() and not Loot.manual and os.clock() - Loot.userAt > 4 then
        Loot.module.close(true) -- local only: the server already got "close" per container
    end
end
Loot.stopAuto = Loot.finish
-- AutoLoot: at most one take per CFG.AutoLootDelay, best rarity first, revealed slots only. Returns true while this container still has a wanted slot or an unanswered take.
Loot.takeAt = 0
Loot.want = function(id)
    local cat, rank = Visual.itemInfo(id)
    return rank >= CFG.AutoLootAlways or (CFG.AutoLootCats[cat] == true and rank >= CFG.AutoLootMinRarity)
end
Loot.takeStep = function(part, info, now)
    if not (Loot.remote and info and info.slots and CFG.AutoLoot) or (CFG.PvPPauseLoot and Visual.pvp.on) then return false end
    local busy, pick, pickRank, pickSlot = false, nil, -1, nil
    for index, slot in info.slots do
        if not slot.hidden and type(slot.id) == "string" and (slot.qty or 0) > 0 and Loot.want(slot.id) then
            if slot.lastQty ~= slot.qty then slot.lastQty, slot.takeN = slot.qty, 0 end
            local n = slot.takeN or 0
            if n < 2 then
                busy = true
                if now - (slot.takeAt or -9) > 1.2 then
                    local _, rank = Visual.itemInfo(slot.id)
                    if rank > pickRank then pick, pickRank, pickSlot = index, rank, slot end
                end
            elseif now - slot.takeAt <= 1.2 then
                busy = true
            elseif not slot.refused then
                slot.refused = true
                Loot.say("take refused twice:", slot.id, "(backpack full or the server closed the slot)")
            end
        end
    end
    if pick ~= nil and now >= Loot.takeAt then
        pickSlot.takeAt, pickSlot.takeN = now, (pickSlot.takeN or 0) + 1
        Loot.takeAt = now + CFG.AutoLootDelay
        Loot.remote:FireServer("take", part, pick)
        if CFG.ShotLog then Loot.say("take", pickSlot.id, "x" .. tostring(pickSlot.qty), "slot", tostring(pick)) end
    end
    return busy
end
Loot.auto = function(now)
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if CFG.AutoLoot and CFG.AutoLootManual and Loot.manual and Loot.manual.Parent then
        Loot.takeStep(Loot.manual, lootKnown[Loot.manual], now)
    end
    -- the user took over (holding E, or a box of theirs is open): drop our boxes, touch neither window nor server state
    if Loot.manual or now - Loot.userAt < 1.5 then
        if next(Loot.pending) then
            for part in Loot.pending do Loot.closeOne(part) end
        end
        -- we may have hidden the shared LootGui for our own boxes: give it back to the user's window
        if Loot.guiHidden then
            Loot.guiHidden = false
            local g = Loot.gui
            if g and g.Parent and Loot.module and Loot.module.isOpen() then g.Enabled = true end
        end
        Loot.nextAuto = math.max(Loot.nextAuto, now + 0.5)
        if not Loot.manual then return end
    end
    if next(Loot.pending) then
        if not CFG.AutoDecrypt or not root then Loot.finish(); return end
        local anyOpen = false
        for part, pending in Loot.pending do
            if not part.Parent then
                Loot.pending[part] = nil
            elseif pending.opened then
                anyOpen = true
                local info = lootKnown[part]
                local busy = CFG.AutoLoot and Loot.takeStep(part, info, now)
                local waits = info and info.total > 0 and info.hidden > 0 and (CFG.AutoDecryptReveal or CFG.AutoLoot)
                local done = not waits and not busy
                if done or now - pending.lastEvent > 12 then Loot.closeOne(part) end
            elseif now - pending.sentAt > 1.5 then
                local row = searchPrompts[pending.prompt]
                if row then row.retry = now + 6 end
                Loot.say("NO REPLY for", part:GetFullName(), "at", string.format("%.1f", pending.dist),
                    "studs, prompt enabled", tostring(pending.prompt.Enabled), "service", tostring(Loot.pps.Enabled))
                Loot.pending[part] = nil
            end
        end
        if anyOpen then
            -- the game's modal would flash up for every box we open: keep it hidden
            local gui = Loot.gui
            if not (gui and gui.Parent) then
                local pg = LP:FindFirstChildOfClass("PlayerGui")
                gui = pg and pg:FindFirstChild("LootGui")
                Loot.gui = gui
            end
            if gui and gui.Enabled then gui.Enabled = false; Loot.guiHidden = true end
        end
        if not next(Loot.pending) then Loot.finish() end
        return
    end
    if not CFG.AutoDecrypt or now < Loot.nextAuto or not root then return end
    if CFG.PvPPauseLoot and Visual.pvp.on then return end
    Loot.nextAuto = now + 0.2
    if type(fireproximityprompt) ~= "function" then
        CFG.AutoDecrypt = false
        if Life.uiState then Life.uiState("AutoDecrypt") end
        Loot.say("this executor has no fireproximityprompt, auto decrypt is OFF")
        return
    end
    if not Loot.module then
        local scripts = LP:FindFirstChild("PlayerScripts")
        local client = scripts and scripts:FindFirstChild("Client")
        local module = client and client:FindFirstChild("Looting")
        if not module then return end
        Loot.module = require(module)
    end
    -- a manual box that the game already closed (or never really opened) must not park auto
    if Loot.manual and (not Loot.manual.Parent or not Loot.module.isOpen()) then Loot.manual = nil end
    -- the game window still holding one of OUR finished boxes (its close came for another part)
    if not Loot.manual and Loot.module.isOpen() then Loot.module.close(true) end
    local idle = (Loot.manual and "you have a box open")
        or (Loot.module.isOpen() and "the game's loot window is open")
        -- seated, stunned or another game UI holds prompts off; a fire now would be silently dropped
        or (not Loot.pps.Enabled and "ProximityPromptService is disabled by the game")
    if idle then
        if idle ~= Loot.idleWhy or now - (Loot.idleAt or 0) > 10 then
            Loot.idleWhy, Loot.idleAt = idle, now
            Loot.say("waiting:", idle)
        end
        return
    end
    Loot.idleWhy = nil
    local cap = math.clamp(math.min(CFG.AutoDecryptMax or 1, Loot.maxPar), 1, 3)
    local near = Loot.query(root.Position, math.clamp(CFG.AutoDecryptRadius, 1, 80), 2, cap)
    for i = 1, near.n do
        local row = near.rows[i]
        row.retry = now + 8
        row.autoAt = now
        Loot.pending[row.part] = { prompt = row.prompt, sentAt = now, lastEvent = now, dist = math.sqrt(near.d2[i]) }
        fireproximityprompt(row.prompt)
    end
end

-- Resource counts are sampled on demand/report, never by traversing Workspace.
Life.count = function(t)
    local n = 0
    for _ in t do n += 1 end
    return n
end
Life.snapshot = function()
    local withCharacter, withRoot, positionOnly = 0, 0, 0
    for i = 1, #roster do
        local plr = roster[i]
        local char = plr.Character
        if char then withCharacter += 1 end
        if char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart) then
            withRoot += 1
        elseif typeof(plr:GetAttribute("PartyAt")) == "Vector3" then
            -- Dump Party.whereOf: coarse position only, NOT HP/inventory for every enemy.
            positionOnly += 1
        end
    end
    return {
        drawings = { live = drawMeta.stats.live, peak = drawMeta.stats.peak, created = drawMeta.stats.created, removed = drawMeta.stats.removed },
        ecp = { active = espPool.inUse, free = #espPool.free, createdSlots = espPool.created },
        particles = { active = Visual.pfx.n, slots = #Visual.pfx.lines },
        connections = { global = #connections, character = #Life.char, monsters = #Life.monsters },
        loot = { registered = Life.count(searchPrompts), moving = Life.count(Loot.moving), waiting = Life.count(Loot.waiting), known = Life.count(lootKnown) },
        players = { totalOthers = #roster, withCharacter = withCharacter, withRoot = withRoot, coarsePositionOnly = positionOnly },
    }
end

-- World objects have their own high-water text pool. Discovery is folder/tag scoped, never a world scan.
Visual.world = { rows = {}, folders = {}, scopes = {}, pool = {}, used = 0, shown = 0,
    -- Map "Supply Crate" is ordinary loot. Airdrops come on Remotes.Effect (SupplyDrop, SupplyLand, SupplyBlare/SupplyOpen).
    folderKinds = { Bodies = "corpse", LootBags = "bag" },
    drops = {},
    classes = { bag = "SupplyDrop", corpse = "Corpse" },
    labels = { bag = "Supply Drop", corpse = "Corpse" } }
Visual.dropNear = function(pos)
    for _, d in Visual.world.drops do
        if (d.pos - pos).Magnitude < 40 then return d end
    end
    return nil
end
Visual.onSupply = function(action, p)
    local w = Visual.world
    local now = Workspace:GetServerTimeNow()
    for i = #w.drops, 1, -1 do if now > w.drops[i].untilAt then table.remove(w.drops, i) end end
    if action == "SupplyDrop" and typeof(p.landPos) == "Vector3" then
        local land = type(p.landAt) == "number" and p.landAt or now
        -- Config.Supply.CrateMinutes = 15
        table.insert(w.drops, { pos = p.landPos, landAt = land, untilAt = land + 15 * 60, state = "falling" })
        return
    end
    local pos = typeof(p.position) == "Vector3" and p.position
        or (typeof(p.crate) == "Instance" and p.crate:IsA("PVInstance") and p.crate:GetPivot().Position)
    if not pos then return end
    local d = Visual.dropNear(pos)
    if not d then
        d = { pos = pos, landAt = now, untilAt = now + 15 * 60, state = "landed" }
        table.insert(w.drops, d)
    end
    d.pos = pos
    if typeof(p.crate) == "Instance" then d.crate = p.crate end
    if action == "SupplyLand" then d.state = "landed"
    elseif action == "SupplyBlare" then d.state = "locked"
    elseif action == "SupplyOpen" then d.state = "open" end
end
Visual.worldAdd = function(obj, kind)
    if not running or not (obj:IsA("BasePart") or obj:IsA("Model")) then return end
    if not Visual.world.rows[obj] then Visual.world.rows[obj] = { kind = kind, born = os.clock() } end
end
Visual.worldRemove = function(obj) Visual.world.rows[obj] = nil end
Visual.worldFolder = function(folder)
    local w = Visual.world
    local kind = w.folderKinds[folder.Name]
    if not kind or w.folders[folder.Name] == folder then return end
    local name = folder.Name
    local old = w.folders[name]
    if old then
        Life.clear(w.scopes[name])
        for obj in w.rows do if obj.Parent == old then w.rows[obj] = nil end end
    end
    w.folders[name], w.scopes[name] = folder, {}
    local scope = w.scopes[name]
    local function add(obj)
        if running and w.folders[name] == folder then
            Visual.worldAdd(obj, kind)
        end
    end
    scope[1] = folder.ChildAdded:Connect(add)
    scope[2] = folder.ChildRemoved:Connect(Visual.worldRemove)
    for _, obj in ipairs(folder:GetChildren()) do add(obj) end
end
Visual.worldStart = function()
    bind(Workspace.ChildAdded:Connect(Visual.worldFolder))
    bind(Workspace.ChildRemoved:Connect(function(folder)
        local w = Visual.world
        if w.folders[folder.Name] ~= folder then return end
        w.folders[folder.Name] = nil
        Life.clear(w.scopes[folder.Name])
        for obj in w.rows do if obj.Parent == folder or not obj.Parent then w.rows[obj] = nil end end
    end))
    for _, name in ipairs({ "Bodies", "LootBags" }) do
        local f = Workspace:FindFirstChild(name)
        if f then Visual.worldFolder(f) end
    end
end
Visual.worldDraw = function(origin)
    local w = Visual.world
    w.used = 0
    if CFG.ESP then
        local now, pvp = os.clock(), Visual.pvp.on
        for obj, row in w.rows do
            if not obj.Parent then w.rows[obj] = nil; continue end
            local k = row.kind
            local cls = CFG.LootClasses[w.classes[k]]
            if not cls.on then continue end
            if pvp and not (k == "corpse" and CFG.PvPKeepCorpses and now - (row.born or 0) < CFG.PvPCorpseSeconds) then continue end
            local part = row.part
            if not part or not part.Parent then
                if now < (row.retry or 0) then continue end
                row.retry = now + 0.5
                part = obj:IsA("BasePart") and obj or obj:FindFirstChild("UpperTorso")
                    or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                row.part = part
            end
            if not part then continue end -- streamed-out body: no made-up position or HP
            local pos = part.Position
            local d = (pos - origin).Magnitude
            if d > CFG.EspObjectMaxDist then continue end
            local sp, on = Cam:WorldToViewportPoint(pos)
            if not on or sp.Z <= 0.1 then continue end
            w.used += 1
            local slot = w.pool[w.used]
            if not slot then
                local text = make_text(28)
                text.Size = 13
                slot = { text = text }; w.pool[w.used] = slot
            end
            local di = math.floor(d)
            if slot.kind ~= k or slot.di ~= di then
                slot.kind, slot.di, slot.label = k, di, w.labels[k] .. "  " .. di .. " st"
            end
            local alpha = k == "corpse" and 0.85 or 1
            Visual.icon.draw(k == "corpse" and "CorpseSkull" or "SupplyBox", sp.X - 8, sp.Y - 18, 16, alpha)
            put_text(slot.text, slot.label, cls.color, sp.X, sp.Y, alpha)
        end
        local air = CFG.LootClasses.AirDrop
        if air.on and not pvp then
            local st = Workspace:GetServerTimeNow()
            for _, drop in w.drops do
                local crate = drop.crate
                local pos = (crate and crate.Parent and crate:IsA("PVInstance")) and crate:GetPivot().Position or drop.pos
                local d = (pos - origin).Magnitude
                if st > drop.untilAt or d > CFG.EspSupplyMaxDist then continue end
                local sp, on = Cam:WorldToViewportPoint(pos + Vector3.new(0, 3, 0))
                if not on or sp.Z <= 0.1 then continue end
                w.used += 1
                local slot = w.pool[w.used]
                if not slot then
                    local text = make_text(28)
                    text.Size = 13
                    slot = { text = text }; w.pool[w.used] = slot
                end
                local eta = math.ceil(drop.landAt - st)
                local di = math.floor(d)
                local key = drop.state .. (eta > 0 and eta or 0)
                if slot.kind ~= key or slot.di ~= di then
                    local tail = eta > 0 and (" lands " .. eta .. "s") or (drop.state == "locked" and " locked"
                        or (drop.state == "open" and " open" or ""))
                    slot.kind, slot.di, slot.label = key, di, "AirDrop Crate" .. tail .. "  " .. di .. " st"
                end
                Visual.icon.draw("SupplyBox", sp.X - 10, sp.Y - 22, 20, 1)
                put_text(slot.text, slot.label, air.color, sp.X, sp.Y, 1)
            end
        end
    end
    for i = w.used + 1, w.shown do w.pool[i].text.Visible = false end
    w.shown = w.used
end
Visual.worldStop = function()
    local w = Visual.world
    for _, scope in w.scopes do Life.clear(scope) end
    for _, slot in w.pool do slot.text:Remove() end
    table.clear(w.rows); table.clear(w.pool); table.clear(w.folders); table.clear(w.scopes); table.clear(w.drops)
end

-- InstantSit: zero the client-side hold on vehicle entry prompts only when they are shown.
Visual.sitHolds = setmetatable({}, { __mode = "k" })
Visual.onPromptShown = function(prompt)
    if not running then return end
    local n = prompt.Name
    local vehicle = n == "CarDoorPrompt" or n == "SitPrompt"
    local loot = n == "SearchPrompt" or n == "PryPrompt"
    if not ((vehicle and CFG.InstantSit) or (loot and CFG.InstantInteract)) or prompt.HoldDuration <= 0 then return end
    if Visual.sitHolds[prompt] == nil then Visual.sitHolds[prompt] = prompt.HoldDuration end
    prompt.HoldDuration = 0
end
Visual.sitStop = function()
    for prompt, hold in Visual.sitHolds do
        if prompt.Parent and prompt.HoldDuration == 0 then prompt.HoldDuration = hold end
    end
    table.clear(Visual.sitHolds)
end

Visual.base = { originals = {}, autoOrig = {}, nextAt = 0 }

-- Movement: Speed, AutoJump, HighJump and FastClimb run from one PreSimulation callback (Visual.moveStep).
-- Server anti-cheat numbers come from Config.AntiCheat at runtime (SustainSpeed 24 / 3 s, BurstSpeed 37 / 1 s, HopSpeed 40, 10 Hz sampling, StrikesToKick 3 in 120 s); the server code is not in the dump.
Visual.speed = { last = 0, sampleAt = 0, cumX = 0, ring = {}, head = 0, px = nil, py = 0, pz = 0, rate = 0, pause = 0,
    backs = {}, push = 0 }
Visual.SPEED_N = 100 -- 5 s of 20 Hz samples
Visual.speedCfg = function()
    local S = Visual.speed
    if S.cfg == nil then
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local inst = shared and shared:FindFirstChild("Config")
        local ok, cfg = pcall(require, inst)
        S.cfg = ok and type(cfg) == "table" and cfg or false
    end
    return S.cfg
end
-- extra-distance budgets: per window, what we may add on top of the natural movement (reserve B = speed we fall back to)
Visual.speedBudget = function()
    local cfg = Visual.speedCfg()
    local ac, mc, m = cfg and cfg.AntiCheat, cfg and cfg.Movement, CFG.SpeedMargin
    local B = CFG.SpeedReserve > 0 and CFG.SpeedReserve or (mc and mc.SprintSpeed or 21)
    local sus, sw, bur, bw = 24, 3, 37, 1
    if ac then sus, sw, bur, bw = ac.SustainSpeed, ac.SustainWindow, ac.BurstSpeed, ac.BurstWindow end
    return math.max((sus * m - B) * sw + CFG.SpeedSlack, 0), sw, math.max((bur * m - B) * bw + CFG.SpeedSlack, 0), bw
end
Visual.speedBack = function(S, seconds, now)
    -- extra distance pushed during the last `seconds` (ring of {t, cumX})
    local N = Visual.SPEED_N
    local newest = S.ring[S.head]
    if not newest then return 0 end
    for k = 1, N - 1 do
        local e = S.ring[(S.head - k - 1) % N + 1]
        if not e then return newest[2] end
        if now - e[1] >= seconds then return newest[2] - e[2] end
    end
    return newest[2] - (S.ring[S.head % N + 1] or newest)[2]
end
Visual.speedStrike = function(now, S)
    local backs = S.backs
    backs[#backs + 1] = now
    for i = #backs - 1, 1, -1 do
        if now - backs[i] > 120 then table.remove(backs, i) end
    end
    S.pause, S.push = now + 6, 0
    if #backs >= 2 then
        CFG.Speed = false
        if Life.uiState then Life.uiState("Speed") end
        warn("[hush] server put us back twice inside 120 s: Speed switched OFF (3 strikes = kick)")
    else
        warn("[hush] server put us back: Speed paused 6 s")
    end
end
Visual.speedSample = function(S, now, pos, hum)
    local gap = math.max(now - S.sampleAt, 0.05)
    S.sampleAt = now
    if S.px and not hum.SeatPart then
        local dx, dz = pos.X - S.px, pos.Z - S.pz
        -- a rollback is a step no movement of ours can make in `gap` seconds
        if math.sqrt(dx * dx + dz * dz) > 8 + 60 * gap or math.abs(pos.Y - S.py) > 15 + 130 * gap then
            Visual.speedStrike(now, S)
        end
    end
    S.px, S.py, S.pz = pos.X, pos.Y, pos.Z
    S.head = S.head % Visual.SPEED_N + 1
    local e = S.ring[S.head]
    if e then e[1], e[2] = now, S.cumX else S.ring[S.head] = { now, S.cumX } end
    local E3, W3, E1, W1 = Visual.speedBudget()
    local tau = 0.05
    S.rate = math.max(math.min((E3 - Visual.speedBack(S, W3 - tau, now)) / tau, (E1 - Visual.speedBack(S, W1 - tau, now)) / tau), 0)
end
-- A state that raises the server's limits is known to it: the game's own slide / dive / rush (Controls.move, sent with Move at its start) or our claim, and its packet had
-- time to arrive (one-way ping + margin).
Visual.hopState = function(now, S)
    local ctl = Visual.base.controls
    local mv = ctl and ctl.move
    local t0
    if mv and (mv.kind == "slide" or mv.kind == "dive" or mv.kind == "rush") then t0 = mv.t0 elseif S.claimOn then t0 = S.claimAt end
    return t0 ~= nil and now >= t0 + Visual.pingHalf() + CFG.HopUplinkMargin
end
-- Raycast filter for the local character (shared by every push).
Visual.speedParams = function(S, char)
    if S.paramsFor ~= char then
        S.params = S.params or RaycastParams.new()
        S.params.FilterDescendantsInstances = { char }
        S.paramsFor = char
    end
    return S.params
end
-- Hop controls the actual downward velocity; Safe/Pulse only consume the horizontal fall bonus.
Visual.fallExtra = function(now, S, root, hum, withState)
    S.fallBurst, S.left, S.fallIn, S.fallOut, S.fallCap, S.stateK = false, 0, 0, 0, 0, 1
    S.nextFallBurst = S.nextFallBurst or now + CFG.HopFallBurstEvery
    if hum.FloorMaterial ~= Enum.Material.Air then S.fallBurstUntil = nil; return 0 end
    local v = root.AssemblyLinearVelocity
    if v.Y > -CFG.HopFallMin then S.fallBurstUntil = nil; return 0 end
    local hit = Workspace:Raycast(root.Position, Vector3.new(0, -CFG.HopRayMax, 0), Visual.speedParams(S, hum.Parent))
    local left = hit and math.max(hit.Distance - CFG.HopFeet, 0) or CFG.HopRayMax
    S.left = left
    local f = left <= CFG.HopRemain and 1 or (CFG.HopRemain / left) ^ CFG.HopRemainPow
    local k = withState and Visual.hopState(now, S) and CFG.HopStateK or 1
    local down = -v.Y
    S.stateK, S.fallIn = k, down
    if withState then
        local cap = CFG.HopFallSpeed
        local eligible = CFG.HopFallBurst and k > 1 and down >= cap
        if eligible and now >= S.nextFallBurst then
            S.fallBurstUntil = now + CFG.HopFallBurstLength
            S.nextFallBurst = S.fallBurstUntil + CFG.HopFallBurstEvery
        end
        if eligible and S.fallBurstUntil and now < S.fallBurstUntil then
            cap = math.max(cap, CFG.HopFallBurstSpeed)
            S.fallBurst = true
            down = cap
        else
            S.fallBurstUntil = nil
            down = math.min(down, cap)
        end
        root.AssemblyLinearVelocity = Vector3.new(v.X, -down, v.Z)
        S.fallCap = cap
    end
    S.fallOut = down
    return math.min(CFG.HopExtra * k, CFG.HopK * k * down) * f
end
Visual.speedPush = function(now, dt, S, root, char, mdir, hum)
    if mdir.Magnitude < 0.1 then S.push, S.phaseAt = 0, nil; return end
    local hop = CFG.SpeedMode == "Hop"
    local fall, bonus = Visual.fallExtra(now, S, root, hum, hop), 0
    if hop then
        S.push = fall > S.push and math.min(S.push + CFG.HopRamp * S.stateK * dt, fall) or fall -- ease in, cut instantly
    else
        if CFG.SpeedMode == "Pulse" then
            -- reference Pulse: a burst of (SpeedValue - WalkSpeed) for PulseLength s, then PulseDelay s of nothing
            S.phaseAt = S.phaseAt or now
            local on = (now - S.phaseAt) % (CFG.PulseLength + CFG.PulseDelay) < CFG.PulseLength
            S.push = on and math.max(CFG.SpeedValue - hum.WalkSpeed, 0) or 0
        else
            local v = root.AssemblyLinearVelocity
            local base = math.sqrt(v.X * v.X + v.Z * v.Z)
            local extra = math.min(math.max(math.min(CFG.SpeedValue, CFG.SpeedMax) - base, 0), S.rate)
            S.push = math.min(S.push + (extra - S.push) * math.min(1, dt * CFG.SpeedRamp), extra) -- ease in, cut instantly
        end
        if CFG.SpeedFallOnly then S.push = 0 end
        if CFG.SpeedFallBonus or CFG.SpeedFallOnly then bonus = fall end
    end
    local push = S.push + bonus
    if hop and CFG.HopLog and push >= 0.3 and now >= (S.logAt or 0) then
        S.logAt = now + 0.5
        warn(string.format("[hush] hop | fall %.1f -> %.1f (cap %.1f), %.1f st left | state x%.2f (claim %s, uplink estimate %.0f ms) | extra %.1f | fallBurst %s | pushing %.1f st/s",
            S.fallIn, S.fallOut, S.fallCap, S.left, S.stateK, S.claimOn and "on" or "off", (Visual.pingHalf() + CFG.HopUplinkMargin) * 1000, fall, S.fallBurst and "on" or "off", push))
    end
    if push < 0.3 then return end
    local dir = Vector3.new(mdir.X, 0, mdir.Z).Unit
    local dist = push * dt
    local params = Visual.speedParams(S, char)
    -- the server checks wall depth (Config.AntiCheat.WallDepth): never push through geometry
    if Workspace:Raycast(root.Position, dir * (dist + 1.8), params) then return end
    root.CFrame = root.CFrame + dir * dist
    S.cumX += S.push * dt -- the free fall speed does not eat the Safe budget
end

-- AutoJump, like the reference module: grounded + moving -> Jumping state (or a custom vertical velocity)
Visual.autoJumpStep = function()
    if not (running and CFG.AutoJump) then return end
    local char = LP.Character
    local hum = char and hum_of(char)
    local root = hum and hum.RootPart
    if not (root and hum.Health > 0) then return end
    if hum.FloorMaterial == Enum.Material.Air or hum.MoveDirection.Magnitude < 0.1 then return end
    if hum:GetState() == Enum.HumanoidStateType.Climbing then return end
    if CFG.AutoJumpPower > 0 then
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(v.X, CFG.AutoJumpPower, v.Z)
    else
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end
-- HighJump: hooked on the Humanoid's own Jumping state change, so a plain Space press, the touch jump button and AutoJump are
-- all covered (checking Space + state ourselves only worked when we ran before the Humanoid did: "works every other time")
Visual.hjConnect = function(S, hum)
    if S.hjHum == hum then return end
    if S.hjConn then S.hjConn:Disconnect() end
    S.hjHum = hum
    S.hjConn = hum.StateChanged:Connect(function(_, new)
        local root = hum.RootPart
        if new == Enum.HumanoidStateType.Jumping and CFG.HighJump and running and root then
            S.hj = { y0 = root.Position.Y, dead = os.clock() + 0.5, tries = 0 }
        end
    end)
end
Visual.highJump = function(now, S, hum, root)
    Visual.hjConnect(S, hum)
    local hj = S.hj
    if not hj then return end
    if now > hj.dead or hum.Health <= 0 then S.hj = nil; return end
    local v = root.AssemblyLinearVelocity
    if not hj.wrote then
        if root.Position.Y > hj.y0 + 0.2 then -- the game's fit already ran (it triggers at +0.05)
            hj.wrote = now
            hj.tries = 1
            root.AssemblyLinearVelocity = Vector3.new(v.X, CFG.HighJumpPower, v.Z)
        end
    elseif hj.tries < 3 and now - hj.wrote < 0.15 and v.Y > 0 and v.Y < CFG.HighJumpPower * 0.55 then
        hj.tries += 1 -- something reset it again
        root.AssemblyLinearVelocity = Vector3.new(v.X, CFG.HighJumpPower, v.Z)
    end
end
Visual.speedTick = function(now, dt)
    local S = Visual.speed
    dt = math.clamp(dt, 0, 0.05)
    S.claimWant = false
    if not (running and (CFG.Speed or CFG.HighJump)) then S.px, S.hj = nil, nil; return end
    local char = LP.Character
    local hum = char and hum_of(char)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root and hum.Health > 0) then S.px = nil; return end
    if S.char ~= char then
        S.char, S.px, S.pause, S.hj, S.claimOn = char, nil, 0, nil, false
        S.fallBurstUntil, S.nextFallBurst = nil, now + CFG.HopFallBurstEvery
    end
    if CFG.HighJump then Visual.highJump(now, S, hum, root) end
    if not CFG.Speed then return end
    if now - S.sampleAt >= 0.05 then Visual.speedSample(S, now, root.Position, hum) end
    if S.pause > now then return end
    if hum.SeatPart or hum.PlatformStand or char:GetAttribute("Ragdoll") or char:GetAttribute("Downed") == true
        or char:GetAttribute("Slumped") == true or hum:GetState() == Enum.HumanoidStateType.Climbing then return end
    if CFG.SpeedMode == "Hop" then
        Visual.hopJump(hum)
        S.claimWant = hum.MoveDirection.Magnitude >= 0.1
    end
    Visual.speedPush(now, dt, S, root, char, hum.MoveDirection, hum)
end
-- FastClimb: pace from Config.Climb.Pace (hopOf multiplies every hop's load / flight / catch by it at call time), ClimbAuto / ClimbForce press the game's own jump handler.
Visual.climb = { orig = nil, nextAt = 0 }
-- Gate entry closures, including references already captured by Space/mobile handlers. Active moves keep their normal cleanup.
Visual.antiClimbGate = function(fn, active)
    local h = { target = fn }
    h.old = hookfunction(fn, function(...)
        if running and CFG.AntiClimb and not (active and active()) then return false end
        return h.old(...)
    end)
    return h
end
Visual.antiClimbInstall = function(client)
    local C, vault = Visual.climb, Visual.base.vault
    if C.hooks or C.failed or not vault then return end
    local ci, wi = client:FindFirstChild("Climb"), client:FindFirstChild("WallMove")
    if not (ci and wi) then return end
    local climb, wall = require(ci), require(wi)
    local beginVault
    for _, fn in debug.getupvalues(vault.try) do
        if type(fn) == "function" and islclosure(fn) and table.find(debug.getconstants(fn), "HushVaultSlow") then
            if beginVault then C.failed = true; warn("[hush] AntiClimb unavailable: ambiguous vault entry"); return end
            beginVault = fn
        end
    end
    if not beginVault then C.failed = true; warn("[hush] AntiClimb unavailable: vault entry not found"); return end
    local entries = {
        { vault.try }, { beginVault },
        { climb.try }, { climb.fromHang }, { climb.grabStep }, { climb.grabWall },
        { climb.step, climb.active },
        { wall.run }, { wall.up }, { wall.kick },
    }
    for _, row in entries do
        if type(row[1]) ~= "function" then C.failed = true; warn("[hush] AntiClimb unavailable: movement API changed"); return end
    end
    C.hooks = {}
    for _, row in entries do C.hooks[#C.hooks + 1] = Visual.antiClimbGate(row[1], row[2]) end
    warn("[hush] AntiClimb ready")
end
Visual.antiClimbStop = function()
    local C = Visual.climb
    if C.hooks then
        for _, h in C.hooks do restorefunction(h.target) end
    end
    C.hooks, C.failed = nil, nil
end
Visual.climbPace = function()
    local cfg = Visual.speedCfg()
    local pace = cfg and cfg.Climb and cfg.Climb.Pace
    if not pace then return end
    local C = Visual.climb
    if not C.orig then C.orig = { load = pace.load, flight = pace.flight, catch = pace.catch } end
    local k = (running and CFG.FastClimb and not CFG.AntiClimb) and math.clamp(CFG.FastClimbPace, 0.2, 1) or 1
    for name, v in C.orig do
        if pace[name] ~= v * k then pace[name] = v * k end
    end
end
Visual.climbStep = function(now, hum)
    Visual.climbPace()
    if CFG.AntiClimb or not (CFG.FastClimb and (CFG.ClimbAuto or CFG.ClimbForce)) or now < Visual.climb.nextAt then return end
    local vault = Visual.base.vault
    if not (vault and hum and hum.Health > 0) or hum.MoveDirection.Magnitude < 0.35 then return end
    local climbing = vault.climbing()
    if climbing and not CFG.ClimbAuto then return end
    if not climbing and not CFG.ClimbForce then return end
    Visual.climb.nextAt = now + (climbing and 0.05 or 0.2)
    vault.try()
end
-- Hop mode: the jump half (the push is in speedPush). The game disables Jumping for 0.3-1.2 s after a landing; the state is re-enabled the way the game does it.
Visual.hopJump = function(hum)
    if not CFG.HopAuto or hum.FloorMaterial == Enum.Material.Air or hum.MoveDirection.Magnitude < 0.1 then return end
    local ctl = Visual.base.controls
    if ctl and (ctl.move or ctl.held or ctl.vaulting or ctl.stunned) then return end
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
end
-- Hop: tell the server we slide while the push runs (what the game's own slide sends: Move "slide", dir ... Move "slideEnd").
Visual.moveSend = function(...)
    local S = Visual.speed
    local r = S.moveRemote
    if not (r and r.Parent) then
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        r = remotes and remotes:FindFirstChild("Move")
        S.moveRemote = r
    end
    if r and r:IsA("RemoteEvent") then r:FireServer(...) end
end
Visual.hopClaim = function(now, hum)
    local S = Visual.speed
    local want = S.claimWant and CFG.HopClaim and CFG.SpeedMode == "Hop"
    local ctl = Visual.base.controls
    if want and ctl and ctl.move then want = false end -- the game's own slide / dive is running
    if want then
        if S.claimOn and now - S.claimAt >= CFG.HopClaimRenew then
            Visual.moveSend("slideEnd")
            S.claimOn, S.claimGap = false, now + 0.1
        end
        if not S.claimOn and now >= (S.claimGap or 0) then
            local d = hum.MoveDirection
            Visual.moveSend("slide", Vector3.new(d.X, 0, d.Z).Unit)
            S.claimOn, S.claimAt = true, now
        end
    elseif S.claimOn then
        Visual.moveSend("slideEnd")
        S.claimOn = false
    end
end
-- Strafer: add (wanted - real) horizontal velocity x dt as a step, wanted = move direction x max(real speed, WalkSpeed, StrafeSpeed).
Visual.strafeStep = function(now, dt, hum, root, char)
    local S = Visual.speed
    if not CFG.Strafer or S.pause > now or hum.Health <= 0 then return end
    if hum.SeatPart or hum.PlatformStand or char:GetAttribute("Ragdoll") or char:GetAttribute("Downed") == true
        or char:GetAttribute("Slumped") == true or hum:GetState() == Enum.HumanoidStateType.Climbing then return end
    local ctl = Visual.base.controls
    if ctl and (ctl.move or ctl.held or ctl.vaulting or ctl.stunned or ctl.restrained or ctl.reviving) then return end
    local dir = hum.MoveDirection
    local v = root.AssemblyLinearVelocity
    local hv = Vector3.new(v.X, 0, v.Z)
    local d
    if dir.Magnitude >= 0.1 then
        d = Vector3.new(dir.X, 0, dir.Z).Unit * math.max(hv.Magnitude, hum.WalkSpeed, CFG.StrafeSpeed) - hv
    elseif CFG.StrafeStop and hum.FloorMaterial == Enum.Material.Air then
        d = -hv
    else
        return
    end
    if d.Magnitude < 0.5 then return end
    local step = d * math.min(dt, 0.05)
    if Workspace:Raycast(root.Position, step.Unit * (step.Magnitude + 1.8), Visual.speedParams(S, char)) then return end
    root.CFrame = root.CFrame + step
end
-- Cap the vector sum of native velocity and this frame's Hop/Strafer displacement.
Visual.hopHorizontalLimit = function(now, dt, hum, root, char, origin)
    local S = Visual.speed
    if not (running and CFG.Speed and CFG.SpeedMode == "Hop") or S.pause > now or hum.Health <= 0 then return end
    if hum.SeatPart or hum.PlatformStand or char:GetAttribute("Ragdoll") or char:GetAttribute("Downed") == true
        or char:GetAttribute("Slumped") == true or hum:GetState() == Enum.HumanoidStateType.Climbing then return end
    local ctl = Visual.base.controls
    if ctl and (ctl.held or ctl.vaulting or ctl.stunned) then return end
    local cap = CFG.HopHorizontalSpeed
    if CFG.HopFallBurst and S.fallBurst and S.fallBurstUntil and now < S.fallBurstUntil
        and hum.FloorMaterial == Enum.Material.Air and root.AssemblyLinearVelocity.Y < -CFG.HopFallMin
        and Visual.hopState(now, S) then cap = math.max(cap, CFG.HopHorizontalBurstSpeed) end
    local v = root.AssemblyLinearVelocity
    local hv = Vector3.new(v.X, 0, v.Z)
    local total = hv
    if origin and dt > 0 then
        local moved = root.Position - origin
        total += Vector3.new(moved.X, 0, moved.Z) / dt
    end
    if total.Magnitude > cap then total = total.Unit * cap end
    local native = hv.Magnitude > cap and hv.Unit * cap or hv
    if origin and dt > 0 then
        local moved = root.Position - origin
        local correction = (total - native) * dt - Vector3.new(moved.X, 0, moved.Z)
        root.CFrame = root.CFrame + correction
    end
    if native ~= hv then root.AssemblyLinearVelocity = Vector3.new(native.X, v.Y, native.Z) end
    S.horizontalCap = cap
end
-- Jump.post restores its own horizontal velocity after simulation; cap that result too.
Visual.hopHorizontalPost = function()
    if not (running and CFG.Speed and CFG.SpeedMode == "Hop") then return end
    local char = LP.Character
    local hum = char and hum_of(char)
    local root = hum and hum.RootPart
    if root then Visual.hopHorizontalLimit(os.clock(), 0, hum, root, char) end
end
Visual.moveStep = function(dt)
    if not running then return end
    local t0 = os.clock()
    local char = LP.Character
    local hum = char and hum_of(char)
    local root = hum and hum.RootPart
    local origin = root and root.Position
    Visual.memStart()
    Visual.autoJumpStep()
    Visual.speedTick(t0, dt)
    Visual.climbStep(t0, hum)
    if hum then Visual.hopClaim(t0, hum) end
    if running and CFG.Strafer and root then Visual.strafeStep(t0, dt, hum, root, char) end
    if root then Visual.hopHorizontalLimit(t0, dt, hum, root, char, origin) end
    Visual.measure("move", t0)
end
Visual.moveStop = function()
    local S = Visual.speed
    if S.claimOn then Visual.moveSend("slideEnd"); S.claimOn = false end
    CFG.FastClimb = false
    Visual.climbPace()
    if S.hjConn then S.hjConn:Disconnect(); S.hjConn, S.hjHum = nil, nil end
end
Visual.toggle = function(flag)
    CFG[flag] = not CFG[flag]
    warn(string.format("[hush] %s %s", flag, CFG[flag] and "ON" or "OFF"))
end

-- WeaponFx / SelfFx groups: fp = workspace.FirstPersonView.FPGun (re-cloned on every item change), tp = Character.HeldGun, me = the character.
-- A group owns its root, a weak part->original table, live parts with a flow phase, parked textures, a DescendantAdded connection and one Highlight. Animation 20 Hz, discovery 10 Hz.
Visual.skin = { nextAt = 0, findAt = 0, groups = {} }
for _, k in { "fp", "tp", "me", "fa" } do -- fa = the first-person ARM clones the game keeps in workspace.FirstPersonView next to FPGun
    Visual.skin.groups[k] = { key = k, prefix = (k == "me" or k == "fa") and "SelfFx" or "WeaponFx", skipName = k == "me" and "HeldGun" or k == "fa" and "FPGun" or nil, parts = setmetatable({}, { __mode = "k" }), list = {}, phase = {}, kids = {} }
end
Visual.skinMaterial = function(name)
    local ok, m = pcall(function() return Enum.Material[name] end)
    if ok and m then return m end
    warn("[hush] skin: unknown material '" .. tostring(name) .. "', using Neon")
    return Enum.Material.Neon
end
Visual.skinPart = function(g, d)
    if g.parts[d] or not d:IsA("BasePart") or d.Name == "HumanoidRootPart" or d.Transparency >= 0.99 then return end
    local p = d.Parent
    while p and p ~= g.root do -- the held gun is the weapon group's job, not the body's
        if g.skipName and p.Name == g.skipName then return end
        p = p.Parent
    end
    if not p then return end
    g.parts[d] = { d.Material, d.Color, d.Reflectance, d.Transparency, d:IsA("MeshPart") and d.TextureID or false }
    for _, ch in d:GetChildren() do
        if ch:IsA("SurfaceAppearance") or ch:IsA("Texture") or ch:IsA("Decal") then
            g.kids[ch] = d
            ch.Parent = nil
        elseif ch:IsA("SpecialMesh") and ch.TextureId ~= "" then
            g.kids[ch] = ch.TextureId
            ch.TextureId = ""
        end
    end
    d.Material, d.Reflectance = g.mat, 0
    if g.tr and g.tr > 0 then d.Transparency = g.tr end -- 0 must not flatten scope lenses
    if d:IsA("MeshPart") then d.TextureID = "" end
    -- flow phase = position along the model's long axis (the body: height), fixed at paint time
    local rel = g.cf:PointToObjectSpace(d.Position)
    g.list[#g.list + 1] = d
    g.phase[d] = (g.axis == 1 and rel.X or g.axis == 2 and rel.Y or rel.Z) * g.flow
end
Visual.skinRelease = function(g)
    if g.conn then g.conn:Disconnect(); g.conn = nil end
    for d, o in g.parts do
        if d.Parent then
            d.Material, d.Color, d.Reflectance, d.Transparency = o[1], o[2], o[3], o[4]
            if o[5] then d.TextureID = o[5] end
        end
    end
    for ch, v in g.kids do
        if typeof(v) == "Instance" then
            if v.Parent then ch.Parent = v end
        elseif ch.Parent then
            ch.TextureId = v
        end
    end
    if g.clothes then
        for c, par in g.clothes do if par.Parent then c.Parent = par end end
        g.clothes = nil
    end
    if g.hl then g.hl:Destroy(); g.hl = nil end
    table.clear(g.parts); table.clear(g.kids); table.clear(g.phase); table.clear(g.list)
    if g.last then table.clear(g.last) end
    g.root = nil
end
Visual.skinBind = function(g, root)
    local pre = g.prefix
    local mat, tr, hlOn = CFG[pre .. "Material"], CFG[pre .. "Transparency"], CFG[pre .. "Highlight"]
    local strip = CFG.SelfFxStripClothes and g.key == "me"
    if g.root == root and g.matName == mat and g.tr == tr and g.hlOn == hlOn and g.strip == strip then return end
    if g.root then Visual.skinRelease(g) end
    if not root then return end
    -- root is assigned last: an error half-way must not leave g.root set with nothing painted (the identity check would skip that weapon forever)
    g.matName, g.tr, g.hlOn, g.strip = mat, tr, hlOn, strip
    g.mat, g.flow = Visual.skinMaterial(mat), CFG[pre .. "Flow"]
    local cf, size = CFrame.new(), Vector3.new(1, 1, 1)
    if root:IsA("Model") then
        cf, size = root:GetBoundingBox()
    elseif root:IsA("BasePart") then
        cf, size = root.CFrame, root.Size
    end
    g.cf = cf
    g.axis = (g.key == "me" or g.key == "fa") and 2 or (size.X >= size.Y and size.X >= size.Z) and 1 or (size.Y >= size.Z) and 2 or 3
    g.root = root
    if strip then
        g.clothes = {}
        for _, d in root:GetDescendants() do
            if d:IsA("Clothing") or d:IsA("ShirtGraphic") then g.clothes[d] = d.Parent; d.Parent = nil end
        end
    end
    for _, d in root:GetDescendants() do Visual.skinPart(g, d) end
    g.conn = root.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then Visual.skinPart(g, d) end
    end)
    if hlOn and g.key ~= "fa" then -- the arm clones live in a shared folder: no Highlight there
        local hl = Instance.new("Highlight")
        hl.Name = "HushFx"
        hl.DepthMode = Enum.HighlightDepthMode.Occluded
        hl.Parent = root
        g.hl = hl
    end
    g.tries = 0
    if CFG.ShotLog then warn(string.format("[hush] skin %s: bound %s (%s), %d parts", g.key, root:GetFullName(), root.ClassName, #g.list)) end
end
-- 64-step palette of the A->B->A wave, rebuilt only when a colour changes: the per-part cost is one table read and a compare, and a part
-- whose step did not change since the last tick is not written at all (a Color write crosses the executor bridge).
Visual.skinPal = { n = 64, groups = {} }
Visual.skinPalette = function(a, b, key)
    local cache = Visual.skinPal
    local P = cache.groups[key]
    if not P then P = { n = cache.n }; cache.groups[key] = P end
    if P.a ~= a or P.b ~= b then
        P.a, P.b = a, b
        for i = 1, P.n do P[i] = a:Lerp(b, 0.5 - 0.5 * math.cos((i - 1) / P.n * 6.2831853)) end
    end
    return P
end
Visual.skinAnim = function(g, t, skipBody)
    if not g.root then return end
    local pre = g.prefix
    local a, b = CFG[pre .. "ColorA"], CFG[pre .. "ColorB"]
    local base = t * CFG[pre .. "Speed"]
    if not skipBody then -- the body is invisible in first person: nothing to repaint
        local list, phase, n = g.list, g.phase, #g.list
        local first = list[1]
        if first and first.Parent and first.Material ~= g.mat then -- the game re-skinned the model under us: put our material back
            for k = 1, n do local d = list[k]; if d.Parent then d.Material = g.mat end end
            if g.last then table.clear(g.last) end
        end
        local pal = Visual.skinPalette(a, b, pre)
        local steps = pal.n
        local last = g.last
        if not last then last = {}; g.last = last end
        local i = 1
        while i <= n do
            local d = list[i]
            if d.Parent then
                local idx = math.floor(((base + phase[d]) % 1) * steps) + 1
                if last[d] ~= idx then
                    last[d] = idx
                    d.Color = pal[idx]
                end
                i += 1
            else -- part destroyed: swap-remove, keep order irrelevant
                g.parts[d], phase[d], last[d] = nil, nil, nil
                list[i] = list[n]; list[n] = nil; n -= 1
            end
        end
    end
    local hl = g.hl
    if hl then
        hl.FillColor = a:Lerp(b, 0.5 - 0.5 * math.cos(base * 6.2831853))
        hl.OutlineColor = a:Lerp(b, 0.5 - 0.5 * math.cos((base + 0.5) * 6.2831853))
        hl.FillTransparency, hl.OutlineTransparency = CFG[pre .. "HlFill"], CFG[pre .. "HlOutline"]
    end
end
Visual.skinTick = function(now)
    local S = Visual.skin
    if now < S.nextAt then return end
    S.nextAt = now + 0.05
    local G = S.groups
    if now >= S.findAt then
        S.findAt = now + 0.1
        local char = LP.Character
        local fpf = workspace:FindFirstChild("FirstPersonView")
        Visual.skinBind(G.fp, CFG.WeaponFx and fpf and fpf:FindFirstChild("FPGun") or nil)
        Visual.skinBind(G.tp, CFG.WeaponFx and char and char:FindFirstChild("HeldGun") or nil)
        local self_on = CFG.SelfFx and not CFG.ModelSwap -- ModelSwap owns the body's transparency
        Visual.skinBind(G.me, self_on and char or nil)
        Visual.skinBind(G.fa, self_on and fpf or nil)
        for _, g in G do -- a model that was bound while still empty (parts stream in after the root): sweep again, a few times
            if g.root and #g.list == 0 and g.tries < 20 then
                g.tries += 1
                for _, d in g.root:GetDescendants() do Visual.skinPart(g, d) end
            end
        end
    end
    local cam = workspace.CurrentCamera
    local fp = (cam.CFrame.Position - cam.Focus.Position).Magnitude < 1.1 -- the same first-person test the game and ModelSwap use
    for _, g in G do Visual.skinAnim(g, now, fp and g.key == "me") end
end
Visual.skinStop = function()
    for _, g in Visual.skin.groups do Visual.skinRelease(g) end
end

Visual.weaponScale = { nextAt = 0 }
Visual.weaponScaleStop = function()
    local S = Visual.weaponScale
    if S.model and S.model.Parent and S.base then S.model:ScaleTo(S.base) end
    S.model, S.base, S.applied, S.nextAt = nil, nil, nil, 0
end
Visual.weaponScaleTick = function(now)
    local S = Visual.weaponScale
    if now < S.nextAt then return end
    S.nextAt = now + 0.1
    local char = LP.Character
    local model = running and CFG.WeaponScale and char and char:FindFirstChild("HeldGun") or nil
    if model and (not model:IsA("Model") or not model.PrimaryPart) then model = nil end
    if S.model ~= model then
        Visual.weaponScaleStop()
        S.model, S.base = model, model and model:GetScale() or nil
        S.nextAt = now + 0.1
    end
    if not model then return end
    local target = S.base * math.clamp(CFG.WeaponScaleFactor, 0.1, 8)
    if S.applied ~= target then
        model:ScaleTo(target)
        S.applied = target
    end
end
-- ModelSwap presets: Tun Tun Sahur = standard R15 (walks via joint Transforms), the others are flat-joint MeshParts.
-- R15 joint signs measured live: hip/shoulder/elbow + = forward/up, knee + = foot forward, Waist + = lean back.
Visual.SWAP_MODELS = {
    ["Tun Tun Sahur"] = { id = 94100079746169, kind = "r15", height = 5.6 },
    ["Skibidi Toilet"] = { id = 14819601003, kind = "bob", height = 4.2 },
    ["Skebob"] = { id = 87004047058803, kind = "bob", height = 5 },
    ["Sponge Bob"] = { id = 5459687221, kind = "bob", height = 4.5, yaw = -90 }, -- the mesh's front is its local -X (yaw +90 turned him to face away)
}
Visual.SWAP_ORDER = { "Tun Tun Sahur", "Skibidi Toilet", "Skebob", "Sponge Bob" }
Visual.swap = { orig = setmetatable({}, { __mode = "k" }), ph = 0, k = 0, t = 0 }
Visual.swapHide = function(on)
    local S = Visual.swap
    for part, tr in S.orig do
        if part.Parent then part.Transparency = on and 1 or tr end
    end
    S.hidden = on
end
Visual.swapBindCharacter = function(char)
    local S = Visual.swap
    if S.char == char then return end
    if S.conn then S.conn:Disconnect(); S.conn = nil end
    Visual.swapHide(false)
    table.clear(S.orig)
    local body = Visual.skin.groups.me
    if body.root then Visual.skinRelease(body) end -- finish SelfFx ownership before capturing body transparency
    S.char, S.fp, S.hidden, S.P = char, nil, false, nil
    if not char then return end
    local function take(d)
        if not d:IsA("BasePart") or d.Name == "HumanoidRootPart" or S.orig[d] ~= nil then return end
        local p = d.Parent
        while p and p ~= char do
            if p.Name == "HeldGun" then return end
            p = p.Parent
        end
        if p ~= char then return end
        S.orig[d] = d.Transparency
        if S.hidden then d.Transparency = 1 end
    end
    S.conn = char.DescendantAdded:Connect(take)
    for _, d in char:GetDescendants() do take(d) end
end
Visual.swapModelHidden = function(hidden)
    local S = Visual.swap
    if S.modelHidden == hidden then return end
    for _, d in S.parts or {} do
        if d.Parent then d.LocalTransparencyModifier = hidden and 1 or 0 end
    end
    S.modelHidden = hidden
end
Visual.swapLoad = function()
    local S = Visual.swap
    S.loading = true
    S.generation = (S.generation or 0) + 1
    local generation = S.generation
    local name = CFG.ModelSwapModel
    local preset = Visual.SWAP_MODELS[name]
    task.spawn(function()
        local ok, res
        if preset then ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. preset.id) end) end
        local obj = ok and res[1]
        -- S.loading stays true until S.model is assigned: the step must not start a second load during the settle below
        if S.generation ~= generation or not running or not CFG.ModelSwap or CFG.ModelSwapModel ~= name then
            if S.generation == generation then S.loading = false end
            if obj then obj:Destroy() end
            return
        end
        if not obj then
            warn("[hush] ModelSwap: '" .. tostring(name) .. "' did not load: " .. tostring(preset and res or "unknown preset"))
            S.failed, S.loading = true, false
            return
        end
        local m = obj
        if not obj:IsA("Model") then -- a bare MeshPart
            m = Instance.new("Model")
            m.Name = name
            obj.Parent = m
            m.PrimaryPart = obj
        end
        local joints = {}
        for _, d in m:GetDescendants() do
            if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Animator") or d:IsA("AnimationController") or d:IsA("Sound")
                or d:IsA("Camera") or d:IsA("NoCollisionConstraint") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, true
                d.LocalTransparencyModifier = 1
            elseif d:IsA("Motor6D") then
                joints[d.Name] = d
            end
        end
        if obj:IsA("BasePart") then obj.CanCollide, obj.CanQuery, obj.CanTouch, obj.Massless = false, false, false, true end
        local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
        if not root then
            warn("[hush] ModelSwap: '" .. name .. "' has no part to anchor")
            S.failed, S.loading = true, false
            m:Destroy()
            return
        end
        root.Anchored = true
        m.PrimaryPart = root
        local folder = Instance.new("Folder")
        folder.Name = "HushSwap"
        folder.Parent = workspace
        m.Parent = folder
        local _, size0 = m:GetBoundingBox()
        m:ScaleTo(m:GetScale() * preset.height / math.max(size0.Y, 1e-3)) -- ScaleTo is ABSOLUTE and imported models carry a scale of their own
        task.wait(0.1)
        local cf, size = m:GetBoundingBox()
        local bottom = (root.CFrame:Inverse() * cf).Position.Y - size.Y / 2
        if S.generation ~= generation or not (running and CFG.ModelSwap and CFG.ModelSwapModel == name) then
            if S.generation == generation then S.loading = false end
            folder:Destroy()
            return
        end
        S.bottom, S.fp, S.modelHidden = bottom, nil, true
        S.model, S.root, S.folder, S.name, S.preset, S.j = m, root, folder, name, preset, joints
        S.loading = false
        S.parts = {}
        for _, d in m:GetDescendants() do if d:IsA("BasePart") then S.parts[#S.parts + 1] = d end end
        warn(string.format("[hush] ModelSwap: loaded %s (%s, %d parts, scaled to %.1f st, feet %.2f below its root)", name, preset.kind, #S.parts, size.Y, S.bottom))
    end)
end
Visual.swapOff = function()
    local S = Visual.swap
    S.generation, S.loading, S.modelHidden = (S.generation or 0) + 1, false, nil
    if S.conn then S.conn:Disconnect(); S.conn = nil end
    Visual.swapHide(false)
    table.clear(S.orig)
    if S.folder then S.folder:Destroy() end
    S.model, S.root, S.folder, S.parts, S.char, S.fp, S.failed, S.name, S.preset, S.j, S.P = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
end
-- Poses follow the game's own state of your character: seat (Humanoid.SeatPart), Downed, Crouch, Aiming (character attributes, the same ones
-- player_states reads for ESP) and being airborne (FloorMaterial Air). Each is a weight that eases 0..1 so the pose blends instead of snapping.
Visual.swapPoseTargets = function(P, char, hum)
    local down = char:GetAttribute("Downed") == true or Visual.knockedOut(char)
    local seat = hum.SeatPart ~= nil and not down
    local crouch = char:GetAttribute("Crouch") == true
    if char == LP.Character and Visual.crouchS.on then crouch = Visual.base.controls.crouching == true end
    crouch = crouch and not seat and not down
    local air = hum.FloorMaterial == Enum.Material.Air and not seat and not down and not crouch
    return seat and 1 or 0, crouch and 1 or 0, down and 1 or 0, air and 1 or 0, char:GetAttribute("Aiming") == true and not seat and not down and 1 or 0
end
-- Returns the vertical offset of the model root from our root and an extra rotation. R15: Transforms on the live joints (hip/shoulder/elbow + =
-- forward/up, knee + = foot forward, Waist + = lean back, all measured). Others: the whole mesh bounces, leans and sinks.
Visual.swapAnim = function(S, char, hum, root, dt, now, standY)
    local P = S.P
    if not P then P = { sit = 0, crouch = 0, lay = 0, air = 0, aim = 0 }; S.P = P end
    local ts, tc, tl, ta, tm = Visual.swapPoseTargets(P, char, hum)
    local e = math.min(1, dt * 11)
    P.sit += (ts - P.sit) * e
    P.crouch += (tc - P.crouch) * e
    P.lay += (tl - P.lay) * e
    P.air += (ta - P.air) * e
    P.aim += (tm - P.aim) * e
    local sit, crouch, lay, air, aim = P.sit, P.crouch, P.lay, P.air, P.aim
    local v = root.AssemblyLinearVelocity
    local sp = math.sqrt(v.X * v.X + v.Z * v.Z)
    local walkW = (1 - math.max(sit, lay)) * (1 - air * 0.7) * (1 - crouch * 0.5)
    S.k += (math.clamp(sp / 14, 0, 1) - S.k) * math.min(1, dt * 10)
    S.ph += dt * (2.5 + sp * 0.5)
    local ph, k = S.ph, S.k * walkW
    local height = S.preset.height
    local pitch = -lay * 1.5708
    if S.preset.kind == "r15" then
        local j, A = S.j, CFrame.Angles
        local sn, cs, a = math.sin(ph), math.cos(ph), 0.75 * k
        local hipL = a * sn + sit * 1.5 + crouch * 0.85 + air * 0.6
        local hipR = -a * sn + sit * 1.5 + crouch * 0.85 + air * -0.15
        j.LeftHip.Transform, j.RightHip.Transform = A(hipL, 0, 0), A(hipR, 0, 0)
        local kb = sit * -1.5 + crouch * -1.7
        j.LeftKnee.Transform = A(-k * math.max(0, cs) + kb + air * -0.7, 0, 0)
        j.RightKnee.Transform = A(-k * math.max(0, -cs) + kb + air * -0.25, 0, 0)
        local arms = aim * 1.35 + air * 0.9 + sit * 0.3
        j.LeftShoulder.Transform = A(-0.9 * a * sn + arms, 0, 0)
        j.RightShoulder.Transform = A(0.9 * a * sn + arms, 0, 0)
        local el = (0.25 + 0.5 * k + sit * 0.3) * (1 - aim) + aim * 0.15
        j.LeftElbow.Transform, j.RightElbow.Transform = A(el, 0, 0), A(el, 0, 0)
        j.Waist.Transform = A(-0.12 * k + crouch * -0.3 + sit * -0.06 + 0.02 * math.sin(now * 1.6), 0, 0)
        -- sitting/lying keep the model root on our root (the pelvis is where the seat/ground is); standing/crouching use the feet formula
        local w = math.max(sit, lay)
        return (standY * (1 - w)) - crouch * 0.125 * height, CFrame.Angles(pitch, 0, 0)
    end
    local bounce = math.abs(math.sin(ph)) * 0.3 * k + math.sin(now * 2) * 0.04
    local lean = -0.12 * k + crouch * -0.15 + sit * 0.1 + air * 0.1 - aim * 0.08
    local dy = standY - crouch * 0.18 * height - sit * 0.1 * height
    dy = dy * (1 - lay) + (-0.3) * lay
    return dy + bounce, CFrame.Angles(pitch + lean, 0, math.sin(ph) * 0.1 * k)
end
Visual.swapStep = function()
    local S = Visual.swap
    if not (running and CFG.ModelSwap) then
        if S.model or S.conn or S.folder or S.loading then Visual.swapOff() end
        S.failed = nil
        return
    end
    if S.model and S.name ~= CFG.ModelSwapModel then Visual.swapOff() end -- another model was picked
    if not S.model then
        if not S.loading and not S.failed then Visual.swapLoad() end
        return
    end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and head and hum) then
        if S.char ~= char then Visual.swapBindCharacter(nil) end
        Visual.swapModelHidden(true)
        return
    end
    Visual.swapBindCharacter(char)
    -- first person = the game's own test (camera to its focus < 0.9 / 1.3 st, FirstPerson.isOn): the model would surround the camera
    local cam = workspace.CurrentCamera
    if not cam then Visual.swapModelHidden(true); return end
    local fp = (cam.CFrame.Position - cam.Focus.Position).Magnitude < 1.1
    if fp ~= S.fp then
        S.fp = fp
        Visual.swapHide(not fp)
    end
    Visual.swapModelHidden(fp)
    local now = os.clock()
    local dt = math.min(now - S.t, 0.1)
    S.t = now
    local feet = hum.HipHeight + root.Size.Y / 2
    local dy, lean = Visual.swapAnim(S, char, hum, root, dt, now, -feet - S.bottom)
    -- PivotTo moves the model's PIVOT, which is the root only if its PivotOffset is zero (the R15 rig's is not: it floated +2.44 st)
    S.model:PivotTo(root.CFrame * CFrame.new(0, dy, 0) * CFrame.Angles(0, math.rad(CFG.ModelSwapYaw + (S.preset.yaw or 0)), 0) * lean * S.root.PivotOffset)
end
Visual.swapStop = function()
    Visual.swapOff()
    Visual.swap.loading = nil
end

-- AutoHeal: the inventory comes from Inventory.setSnapshot's upvalue (u2.snap.backpack = { id = count }); use = Remotes.InvAction:FireServer({ action = "Use", id = id }), what the inventory UI sends.
Visual.heal = { at = 0 }
Visual.healState = function(client)
    local H = Visual.heal
    if H.u2 then return H.u2 end
    local inst = client and client:FindFirstChild("Inventory")
    if not inst then return nil end
    local ok, mod = pcall(require, inst)
    if not ok or type(mod) ~= "table" or not mod.setSnapshot then return nil end
    for _, up in debug.getupvalues(mod.setSnapshot) do
        if type(up) == "table" and rawget(up, "mode") ~= nil and rawget(up, "drawn") ~= nil then
            H.u2 = up
            return up
        end
    end
    return nil
end
Visual.healPick = function(backpack, defs, missing)
    -- Among Medical items with a heal value: an item is acceptable when it is used >= 50% (healed/heal); of the
    -- acceptable ones take the one that heals the most (fewest uses); none acceptable -> the smallest.
    local best, bestHealed, small, smallHeal
    for id, n in backpack do
        local def = defs[id]
        local heal = def and def.heal
        if def and def.hemostatic then
            local cfg = Visual.base.config and Visual.base.config.Hemostatic
            local char = LP.Character
            local untilAt = char and char:GetAttribute("HemostaticUntil")
            local regenAt = char and char:GetAttribute("HemostaticRegenUntil")
            local now = Workspace:GetServerTimeNow()
            if (type(untilAt) == "number" and untilAt > now) or (type(regenAt) == "number" and regenAt > now) then
                heal = nil
            else
                heal = cfg and cfg.Heal -- rank the immediate heal, not a promise that every regen tick will land
            end
        end
        if type(n) == "number" and n > 0 and def and def.category == "Medical" and type(heal) == "number" and heal > 0 then
            local healed = math.min(heal, missing)
            if healed / heal >= 0.5 and (not bestHealed or healed > bestHealed) then best, bestHealed = id, healed end
            if not smallHeal or heal < smallHeal then small, smallHeal = id, heal end
        end
    end
    return best or small
end
Visual.healTick = function(now, client)
    local H = Visual.heal
    if not (running and CFG.AutoHeal) or now < H.at then return end
    local char = LP.Character
    local hum = char and hum_of(char)
    if not (hum and hum.Health > 0 and hum.MaxHealth > 0 and LP:GetAttribute("RaidState") == "Raid") then return end
    if char:GetAttribute("Downed") == true or char:GetAttribute("Slumped") == true then return end
    if hum.Health / hum.MaxHealth * 100 > CFG.AutoHealThreshold then return end
    if CFG.AutoHealPvP then
        local c = LP:GetAttribute("CombatAt")
        if not (type(c) == "number" and Workspace:GetServerTimeNow() - c < 15) then return end
    end
    local u2 = Visual.healState(client)
    local snap = u2 and u2.snap
    local backpack = snap and snap.backpack
    if not backpack then return end
    if not H.defs then
        local I = Visual.itemDefs()
        H.defs = I and I.Defs
        H.remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("InvAction")
    end
    if not (H.defs and H.remote) then return end
    local id = Visual.healPick(backpack, H.defs, hum.MaxHealth - hum.Health)
    if not id then return end
    H.at = now + CFG.AutoHealDelay
    H.remote:FireServer({ action = "Use", id = id })
    if CFG.ShotLog then warn(string.format("[hush] AutoHeal: used %s at %.0f/%.0f HP", id, hum.Health, hum.MaxHealth)) end
end

-- AutoArmor: snap.slots.armor / snap.slots.helmet = worn id, snap.backpack = { id = count }; Wear is the verb the inventory UI sends when a piece is dropped on the ARMOR / HELMET square.
Visual.armor = { at = 0, tries = {} }
Visual.armorTick = function(now, client)
    local A = Visual.armor
    if not (running and CFG.AutoArmor) or now < A.at then return end
    A.at = now + 1
    local char = LP.Character
    local hum = char and hum_of(char)
    if not (hum and hum.Health > 0 and LP:GetAttribute("RaidState") == "Raid") then return end
    if char:GetAttribute("Downed") == true or char:GetAttribute("Slumped") == true then return end
    local u2 = Visual.healState(client)
    local snap = u2 and u2.snap
    local backpack, slots = snap and snap.backpack, snap and snap.slots
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("InvAction")
    if not (backpack and slots and remote and Visual.itemDefs()) then return end
    local c = LP:GetAttribute("CombatAt")
    local combat = type(c) == "number" and Workspace:GetServerTimeNow() - c < 15
    for _, row in { { "armor", "armor", CFG.AutoArmorBody }, { "helmet", "helmet", CFG.AutoArmorHelmet } } do
        if row[3] then
            local worn = slots[row[1]]
            if type(worn) == "table" then worn = worn.id end
            local wornRank = 0
            if type(worn) == "string" then local _, r = Visual.itemInfo(worn); wornRank = math.max(r, 1) end
            local best, bestRank
            for id, n in backpack do
                local _, rank, def = Visual.itemInfo(id)
                if type(n) == "number" and n > 0 and def and def[row[2]] == true and rank > (bestRank or 0) then best, bestRank = id, rank end
            end
            if best and best ~= worn and bestRank > wornRank then
                local fill = wornRank == 0
                if fill or (CFG.AutoArmorMode == "Upgrade" and not (CFG.AutoArmorSafe and combat)) then
                    local try = A.tries[best]
                    if try and try.n >= 2 and now - try.at < 30 then continue end
                    A.tries[best] = { n = (try and try.n or 0) + 1, at = now }
                    A.at = now + 1.5
                    remote:FireServer({ action = "Wear", id = best, from = "backpack" })
                    if CFG.ShotLog then warn(string.format("[hush] AutoArmor: wear %s (%s, tier %d over %d)", best, row[1], bestRank, wornRank)) end
                    return
                end
            elseif best == worn then
                A.tries[best] = nil
            end
        end
    end
end

-- AntiDrown: the server also judges the replicated body (Config.Drown.ServerFeet 1.4), so a local invisible slab at the water surface under the feet keeps the point 1.4 st above them dry.
-- Entries 0.5..6 st deep are lifted onto it. 20 Hz terrain ray.
Visual.water = { at = 0, ray = nil, slab = nil, lastSeen = 0, lifted = 0 }
Visual.waterPark = function()
    local W = Visual.water
    if W.slab then W.slab:Destroy(); W.slab = nil end
end
Visual.waterWalk = function(now)
    local W = Visual.water
    if now < W.at then return end
    W.at = now + (W.slab and 0.05 or 0.2) -- no water around: 5 probes/s are enough (ray looks 60 st ahead)
    local char = LP.Character
    local hum = char and hum_of(char)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (running and CFG.AntiDrown and hum and hrp and hum.Health > 0 and not hum.SeatPart) then
        if W.slab then Visual.waterPark() end
        return
    end
    if not W.mod then
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local inst = shared and shared:FindFirstChild("Water")
        if not inst then return end
        W.mod = require(inst)
        W.ray = RaycastParams.new()
        W.ray.FilterType, W.ray.IgnoreWater = Enum.RaycastFilterType.Include, false
        W.ray.FilterDescendantsInstances = { Workspace.Terrain }
    end
    local pos = hrp.Position
    local feetY = pos.Y - hum.HipHeight - hrp.Size.Y * 0.5
    -- feet at/below the surface: the game's own test (works from inside water); otherwise a ray from above
    local top = W.mod.topOver(pos.X, pos.Z, feetY)
    if not top then
        local hit = Workspace:Raycast(Vector3.new(pos.X, pos.Y + 2, pos.Z), Vector3.new(0, -60, 0), W.ray)
        if hit and hit.Material == Enum.Material.Water then top = hit.Position.Y end
    end
    if not top then
        if W.slab and now - W.lastSeen > 0.8 then Visual.waterPark() end
        return
    end
    W.lastSeen = now
    local slab = W.slab
    if not slab then
        slab = Instance.new("Part")
        slab.Name, slab.Anchored, slab.CanCollide, slab.CanQuery, slab.CanTouch = "Part", true, true, false, false
        slab.Transparency, slab.CastShadow, slab.Size = 1, false, Vector3.new(9, 0.5, 9)
        slab.Parent = Workspace
        W.slab = slab
    end
    local c = slab.Position
    local slabY = top + CFG.WaterMargin - 0.25
    if math.abs(c.X - pos.X) > 1.5 or math.abs(c.Z - pos.Z) > 1.5 or math.abs(c.Y - slabY) > 0.05 then
        slab.Position = Vector3.new(pos.X, slabY, pos.Z)
    end
    local depth = top - feetY
    if depth > 0.5 and depth < 12 then
        -- already in the water (jumped in / fell in): stand back up on the slab, once per 0.3 s
        if now - W.lifted > 0.3 then
            W.lifted = now
            hrp.CFrame = hrp.CFrame + Vector3.new(0, depth + CFG.WaterMargin + 0.1, 0)
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0), v.Z)
            if CFG.ShotLog then warn(string.format("[hush] AntiDrown: lifted %.1f st onto the water surface", depth)) end
        end
    end
end
Visual.baseTick = function(now)
    local b = Visual.base
    Visual.crouchStep(now)
    if CFG.AntiDrown or Visual.water.slab then Visual.waterWalk(now) end
    if CFG.NoRagdoll then Visual.unRagdoll() end
    if b.controls and CFG.InfStamina then
        b.controls.stamina = b.controls.staminaMax()
        b.controls.breathing, b.controls.windedUntil = false, 0
    end
    if now < b.nextAt then return end
    b.nextAt = now + 0.25
    local client = b.client
    if not client or not client.Parent then
        local ps = LP:FindFirstChild("PlayerScripts")
        client = ps and ps:FindFirstChild("Client")
        b.client = client
    end
    if client and not b.controls then
        local inst = client:FindFirstChild("Controls")
        if inst then b.controls = require(inst) end
    end
    if client and not b.vault then
        local inst = client:FindFirstChild("Vault")
        if inst then b.vault = require(inst) end
    end
    if client then
        Visual.antiClimbInstall(client)
        Visual.attachRoundsFx(client)
    end
    Visual.healTick(now, client)
    Visual.armorTick(now, client)
    if client and not b.drown then
        local inst = client:FindFirstChild("Drown")
        if inst then
            b.drown = require(inst)
            b.drownSetRaid = b.drown.setRaid
            b.drownHook = function(inRaid)
                b.drownRaid = inRaid
                b.drownApplied = running and CFG.AntiDrown or false
                return b.drownSetRaid(inRaid and not b.drownApplied)
            end
            b.drown.setRaid = b.drownHook
            b.drownHook(LP:GetAttribute("RaidState") == "Raid")
        end
    end
    if b.drown and b.drownApplied ~= CFG.AntiDrown then
        b.drownHook(b.drownRaid)
    end
    if client and not b.draw then
        local inst = client:FindFirstChild("BodyAnimDefs")
        if inst then
            local defs = require(inst)
            b.draw, b.drawSpeed = defs.Draw, defs.Draw.speed
            b.drawHook = function(plr)
                if CFG.InstantEquip and plr == LP then return 0.001 end
                return b.drawSpeed(plr)
            end
            b.draw.speed = b.drawHook
        end
    end
    if client and not b.breath then
        local inst = client:FindFirstChild("Breath")
        if inst then
            -- ClientMain calls Breath.run(checks, onCheck, onDone) through the module table; onCheck is
            -- Remotes.Breath:FireServer(bool). The zone is random on the client, the server only sees the bool.
            local mod = require(inst)
            b.breath, b.breathRun, b.breathStop, b.breathToken = mod, mod.run, mod.stop, 0
            warn("[hush] auto breath hooked (Breath.run)")
            mod.stop = function(...)
                b.breathToken += 1
                return b.breathStop(...)
            end
            mod.run = function(checks, onCheck, onDone)
                if not (running and CFG.AutoBreath) then return b.breathRun(checks, onCheck, onDone) end
                if CFG.ShotLog then warn("[hush] auto breath: start, " .. tostring(checks) .. " checks") end
                mod.stop()
                local token = b.breathToken
                task.spawn(function()
                    task.wait(0.4)
                    for i = 1, checks do
                        -- BreathLeadIn 0.45 + the needle reaching a mid zone (~0.6 of BreathSpinSeconds 1.15)
                        task.wait(0.45 + 1.15 * (0.4 + math.random() * 0.3))
                        if b.breathToken ~= token then return end
                        onCheck(true)
                        if i < checks then task.wait(0.9 + math.random() * 1.3) end
                    end
                    task.wait(0.9)
                    if b.breathToken ~= token then return end
                    if onDone then onDone(true) end
                    if CFG.ShotLog then warn("[hush] auto breath: " .. checks .. " checks sent as quiet") end
                end)
            end
        end
    end
    local g = guns()
    if g and not b.boltTimes and type(g.boltTimes) == "function" then
        b.boltTimes = g.boltTimes
        b.boltHook = function(loads)
            local t = b.boltTimes(loads)
            if CFG.FastBolt and type(t) == "table" then
                local k = CFG.FastBoltScale or 0.25
                for key, v in t do if type(v) == "number" then t[key] = v * k end end
            end
            return t
        end
        g.boltTimes = b.boltHook
    end
    if not b.config then
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local inst = shared and shared:FindFirstChild("Config")
        if inst then b.config = require(inst) end
    end
    local gc = b.config and b.config.Guns
    if gc then
        if b.heat == nil then b.heat = gc.HeatPerShot end
        gc.HeatPerShot = CFG.NoHeat and 0 or b.heat
        if not b.airSway then b.airSway = { JumpSway = gc.JumpSway, JumpKick = gc.JumpKick } end
        for key, value in b.airSway do gc[key] = CFG.NoRecoil and 0 or value end
    end
    if CFG.AutoHotwire and not b.wireFn and now >= (b.wireNextAt or 0) and type(filtergc) == "function" then
        b.wireNextAt = now + 5
        -- closeHotwire is inlined and getupvalues skips nil slots: capture the dial table in runChecks(state, run) instead.
        local fn = filtergc("function", { Name = "runChecks", Constants = { "HushWire" } }, true)
        if fn then
            b.wireFn = fn
            b.wireOld = hookfunction(fn, function(st, run, ...)
                b.wire = st
                if CFG.ShotLog and type(st) == "table" then
                    warn("[hush] auto hotwire: " .. tostring(st.kind) .. ", " .. tostring(st.of) .. " checks")
                end
                return b.wireOld(st, run, ...)
            end)
            warn("[hush] auto hotwire hooked (Vehicles.runChecks)")
        end
    end
    if client and not b.fallSlots and CFG.NoFall then
        -- Fall.lua lands through the local judge() (PostSimulation post -> judge); judge computes the damage and sends Move "fall".
        -- Replace the judge upvalue in both closures with a gate (post() re-arms its state next frame).
        b.fallSlots = {}
        local ok, posts = pcall(filtergc, "function", { Name = "post", Constants = { "FloorMaterial", "RootPart" }, IgnoreExecutor = true })
        local ok2, lands = pcall(filtergc, "function", { Name = "landed", Constants = { "IsA", "Model" }, IgnoreExecutor = true })
        for _, group in { ok and posts or {}, ok2 and lands or {} } do
            for _, f in group do
                for idx, up in debug.getupvalues(f) do
                    if type(up) == "function" and debug.info(up, "n") == "judge" then
                        local sends = false
                        for _, c in debug.getconstants(up) do if c == "fall" then sends = true end end
                        if sends then
                            b.fallJudge = b.fallJudge or up
                            if up == b.fallJudge then b.fallSlots[#b.fallSlots + 1] = { fn = f, idx = idx } end
                        end
                    end
                end
            end
        end
        if #b.fallSlots == 0 then
            warn("[hush] NoFall: Fall.judge not found (filtergc post/landed); fall damage is NOT blocked")
        else
            b.fallHook = function(...)
                if running and CFG.NoFall then return false end
                return b.fallJudge(...)
            end
            for _, slot in b.fallSlots do debug.setupvalue(slot.fn, slot.idx, b.fallHook) end
            if CFG.ShotLog then warn(string.format("[hush] NoFall: judge gated in %d closures", #b.fallSlots)) end
        end
    end
    if client and not b.hitReact then
        local inst = client:FindFirstChild("HitReact")
        if inst then
            -- Effect "Ragdoll" calls HitReact.fall(shot): per-Heartbeat velocity kicks on every limb
            local mod = require(inst)
            b.hitReact, b.hitFall = mod, mod.fall
            mod.fall = function(...)
                if running and CFG.NoRagdoll then
                    if CFG.ShotLog then warn("[hush] NoRagdoll: blocked HitReact.fall (limb kicks)") end
                    return
                end
                return b.hitFall(...)
            end
        end
    end
    if b.controls and not b.bounce and type(b.controls.bounce) == "function" then
        -- Effect "Ragdoll" -> Controls.setStunned(true) + Controls.bounce(knock velocity)
        b.bounce = b.controls.bounce
        b.controls.bounce = function(v, ...)
            if running and CFG.NoRagdoll then
                if CFG.ShotLog then warn(string.format("[hush] NoRagdoll: blocked bounce, knock velocity %.0f st/s", typeof(v) == "Vector3" and v.Magnitude or -1)) end
                return
            end
            return b.bounce(v, ...)
        end
        b.stun = b.controls.setStunned
        b.controls.setStunned = function(on, ...)
            -- only the ragdoll stun; monster grabs/hits (no Ragdoll attribute) keep the game's stun
            local char = LP.Character
            if on and running and CFG.NoRagdoll and char and char:GetAttribute("Ragdoll") then on = false end
            return b.stun(on, ...)
        end
    end
    if CFG.FullBright and not b.fbBound then
        b.fbBound = true
        b.lighting = cloneref(game:GetService("Lighting"))
        -- WorldFX rewrites Lighting every RenderStepped; write after it, every frame.
        RunService:BindToRenderStep("HushFullBright", Enum.RenderPriority.Last.Value + 1, Visual.fullBright)
        b.fbCheckAt = now + 2
    end
    if b.fbBound and not CFG.FullBright then
        b.fbBound, b.fbCheckAt = nil, nil
        RunService:UnbindFromRenderStep("HushFullBright") -- the game's own Lighting writes return on the next frame
    end
    if b.fbCheckAt and now >= b.fbCheckAt then
        b.fbCheckAt = nil
        if CFG.FullBright then
            local L, bad = b.lighting, {}
            if L.Ambient ~= Visual.FB_AMBIENT then bad[#bad + 1] = "Ambient" end
            if L.Brightness ~= 2 then bad[#bad + 1] = "Brightness" end
            if L.ClockTime ~= 14 then bad[#bad + 1] = "ClockTime" end
            if #bad > 0 then warn("[hush] Fullbright: overwritten after our write: " .. table.concat(bad, ", ")) end
        end
    end
    if b.fullAuto ~= CFG.FullAuto then
        local gg = guns()
        if gg then
            for _, def in gg.Defs do
                if type(def) == "table" and def.ammo ~= nil and not def.melee then
                    if CFG.FullAuto then
                        if def.auto == false then
                            local ok = pcall(function() def.auto = true end)
                            if ok then b.autoOrig[def] = true; b.autoN = (b.autoN or 0) + 1 else b.autoFail = (b.autoFail or 0) + 1 end
                        end
                    elseif b.autoOrig[def] then
                        def.auto = false
                        b.autoOrig[def] = nil
                    end
                end
            end
            b.fullAuto = CFG.FullAuto
            if CFG.FullAuto then warn(string.format("[hush] FullAuto: %d weapons switched to auto, %d writes refused", b.autoN or 0, b.autoFail or 0)) end
        end
    end
    if b.recoil ~= CFG.NoRecoil then
        if not g then return end
        for _, def in g.Defs do
            if type(def) == "table" then
                local saved = b.originals[def]
                if not saved then saved = { recoil = def.recoil, side = def.side }; b.originals[def] = saved end
                if saved.recoil ~= nil then def.recoil = CFG.NoRecoil and 0 or saved.recoil end
                if saved.side ~= nil then def.side = CFG.NoRecoil and 0 or saved.side end
            end
        end
        b.recoil = CFG.NoRecoil
    end
end
Visual.baseStop = function()
    local b = Visual.base
    Visual.crouchRelease()
    Visual.antiClimbStop()
    Visual.waterPark()
    if b.drown then
        if b.drown.setRaid == b.drownHook then b.drown.setRaid = b.drownSetRaid end
        b.drownSetRaid(b.drownRaid)
        b.drown = nil
    end
    for def, saved in b.originals do def.recoil, def.side = saved.recoil, saved.side end
    for def in b.autoOrig do def.auto = false end
    table.clear(b.autoOrig)
    b.fullAuto = nil
    if b.draw and b.draw.speed == b.drawHook then b.draw.speed = b.drawSpeed end
    if b.breath then b.breath.run, b.breath.stop = b.breathRun, b.breathStop end
    local g = guns()
    if g and b.boltTimes and g.boltTimes == b.boltHook then g.boltTimes = b.boltTimes end
    if b.config and b.heat ~= nil then b.config.Guns.HeatPerShot = b.heat end
    if b.config and b.airSway then
        for key, value in b.airSway do b.config.Guns[key] = value end
        b.airSway = nil
    end
    if b.fbBound then RunService:UnbindFromRenderStep("HushFullBright") end
    if b.wireFn and restorefunction then restorefunction(b.wireFn) end
    if b.fallSlots then
        for _, slot in b.fallSlots do
            if debug.getupvalue(slot.fn, slot.idx) == b.fallHook then debug.setupvalue(slot.fn, slot.idx, b.fallJudge) end
        end
        b.fallSlots, b.fallJudge, b.fallHook = nil, nil, nil
    end
    if b.hitReact then b.hitReact.fall = b.hitFall; b.hitReact, b.hitFall = nil, nil end
    if b.controls and b.bounce then b.controls.bounce, b.controls.setStunned = b.bounce, b.stun end
    table.clear(b.originals)
    b.draw, b.drawSpeed, b.drawHook, b.controls = nil, nil, nil, nil
    b.breath, b.boltTimes, b.config, b.heat, b.wireFn, b.fbBound = nil, nil, nil, nil, nil, nil
    b.wire, b.wireOld, b.bounce, b.stun = nil, nil, nil, nil
end
Visual.FB_AMBIENT = Color3.fromRGB(178, 178, 178)
Visual.fullBright = function()
    local L = Visual.base.lighting
    if not (running and CFG.FullBright and L) then return end
    L.Ambient, L.OutdoorAmbient = Visual.FB_AMBIENT, Visual.FB_AMBIENT
    L.Brightness, L.ExposureCompensation, L.FogEnd, L.GlobalShadows = 2, 0.3, 1e6, false
    L.ClockTime = 14
    local atm = Visual.base.atmosphere
    if atm == nil or (atm and not atm.Parent) then
        atm = L:FindFirstChildOfClass("Atmosphere") or false
        Visual.base.atmosphere = atm
    end
    if atm then atm.Density, atm.Haze = 0, 0 end
end
-- Hotwire / lockpick dial: the client judges the press and sends only "start"/"picked"/"spark".
-- Press inside the GREAT window at the dial's own pace (no early finish against Min* timers).
Visual.autoWire = function()
    local b = Visual.base
    if not CFG.AutoHotwire then return end
    local st = b.wire
    if type(st) ~= "table" or not st.spinning or st.pressedAt ~= nil then return end
    local zone, speed, t0 = st.zoneAt, st.speed, st.spinStart
    if type(zone) ~= "number" or type(speed) ~= "number" or type(t0) ~= "number" then return end
    local rot = (os.clock() - t0) * speed
    if rot >= zone + 2 then st.pressedAt = math.min(rot, zone + 10) end
end
-- The client has no ragdoll code: a server ragdoll turns the rig's 16 AnimationConstraints off and adds ~28 physical joint constraints.
-- We keep an upright snapshot, re-enable it while the Ragdoll attribute is set and switch off every physical joint that appears (attribute read per frame, rig walk every 0.1 s).
Visual.rag = { at = 0, snapAt = 0, snap = {}, char = nil, active = false, rebuilt = 0, offJoints = 0 }
Visual.RAG_JOINTS = { RodConstraint = true, RopeConstraint = true, SpringConstraint = true, HingeConstraint = true,
    BallSocketConstraint = true, UniversalConstraint = true, CylindricalConstraint = true, PrismaticConstraint = true }
Visual.ragSnap = function(char, now)
    local R = Visual.rag
    R.char, R.snapAt = char, now
    table.clear(R.snap)
    for _, d in char:GetDescendants() do
        if d:IsA("Motor6D") then
            if d.Part0 and d.Part1 then
                R.snap[#R.snap + 1] = { inst = d, kind = 1, name = d.Name, parent = d.Parent, a = d.Part0, b = d.Part1, c0 = d.C0, c1 = d.C1 }
            end
        elseif d:IsA("AnimationConstraint") then
            if d.Attachment0 and d.Attachment1 then
                R.snap[#R.snap + 1] = { inst = d, kind = 2, name = d.Name, parent = d.Parent, a = d.Attachment0, b = d.Attachment1, f = d.MaxForce, t = d.MaxTorque }
            end
        end
    end
end
Visual.ragReport = function(char, tag)
    local R, ok, off, missing, phys = Visual.rag, 0, 0, 0, 0
    for _, sn in R.snap do
        if not sn.inst.Parent then missing += 1 elseif not sn.inst.Enabled then off += 1 else ok += 1 end
    end
    for _, d in char:GetDescendants() do if Visual.RAG_JOINTS[d.ClassName] and d.Enabled then phys += 1 end end
    local hum = hum_of(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    local own = "?"
    if isnetworkowner and root then
        local good, v = pcall(isnetworkowner, root)
        own = good and tostring(v) or "err"
    end
    warn(string.format("[hush] NoRagdoll %s: rig joints ok %d / off %d / destroyed %d of %d | physical joints on %d (we switched off %d) | state %s | PlatformStand %s | rebuilt %d | we own physics %s | root speed %.0f",
        tag, ok, off, missing, #R.snap, phys, R.offJoints, hum and hum:GetState().Name or "?", tostring(hum and hum.PlatformStand), R.rebuilt, own,
        root and root.AssemblyLinearVelocity.Magnitude or -1))
end
Visual.unRagdoll = function()
    local char = LP.Character
    local R = Visual.rag
    local now = os.clock()
    if not (running and CFG.NoRagdoll and char) then return end
    if not char:GetAttribute("Ragdoll") then
        if R.active then
            R.active = false
            if CFG.ShotLog then Visual.ragReport(char, string.format("over after %.1fs", now - R.since)) end
        end
        -- rig snapshot: first sight of a character, then every 5 s while upright
        if R.char ~= char or (now - R.snapAt > 5 and char:FindFirstChild("HumanoidRootPart")) then Visual.ragSnap(char, now) end
        return
    end
    if not R.active then
        R.active, R.since, R.rebuilt, R.offJoints, R.reported = true, now, 0, 0, false
        if R.char ~= char then Visual.ragSnap(char, now) end
    end
    if now - R.at >= 0.1 then
        R.at = now
        for _, sn in R.snap do
            local m = sn.inst
            if not m.Parent then
                if sn.a.Parent and sn.b.Parent and sn.parent.Parent then
                    local n
                    if sn.kind == 1 then
                        n = Instance.new("Motor6D")
                        n.Part0, n.Part1, n.C0, n.C1 = sn.a, sn.b, sn.c0, sn.c1
                    else
                        n = Instance.new("AnimationConstraint")
                        n.Attachment0, n.Attachment1, n.MaxForce, n.MaxTorque = sn.a, sn.b, sn.f, sn.t
                    end
                    n.Name, n.Parent = sn.name, sn.parent
                    sn.inst = n
                    R.rebuilt += 1
                end
            elseif not m.Enabled then
                m.Enabled = true
            end
        end
        for _, d in char:GetDescendants() do
            if Visual.RAG_JOINTS[d.ClassName] and d.Enabled then d.Enabled = false; R.offJoints += 1 end
        end
        if CFG.ShotLog and not R.reported and now - R.since > 0.5 then
            R.reported = true
            Visual.ragReport(char, "0.5 s into ragdoll")
        end
    end
    local hum = hum_of(char)
    if hum then
        if hum.PlatformStand then hum.PlatformStand = false end
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.PlatformStanding then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
    local ctl = Visual.base.controls
    if ctl and ctl.stunned then ctl.setStunned(false) end
    -- knock velocity from anything else (server-made force, leftover impulse): horizontal speed capped to sprint pace
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and hum then
        local v = root.AssemblyLinearVelocity
        local cap = math.max(hum.WalkSpeed * 1.7, 26)
        local hs = math.sqrt(v.X * v.X + v.Z * v.Z)
        if hs > cap then
            local k = cap / hs
            root.AssemblyLinearVelocity = Vector3.new(v.X * k, v.Y, v.Z * k)
        end
    end
end
-- Movers nobody on the client creates (BodyMovers/LinearVelocity; VectorForce/Torque are used by Jump/Rockets/CarPhysics and are left alone) are server- or injector-made pushes: remove them from our character.
Visual.PUSH_CLASSES = { BodyVelocity = true, BodyForce = true, BodyPosition = true, BodyGyro = true, BodyThrust = true,
    BodyAngularVelocity = true, RocketPropulsion = true, LinearVelocity = true, AngularVelocity = true,
    AlignPosition = true, AlignOrientation = true, LineForce = true }
Visual.noPush = function(inst)
    if running and CFG.NoRagdoll and Visual.PUSH_CLASSES[inst.ClassName] then
        if CFG.ShotLog then warn("[hush] NoRagdoll: removed foreign " .. inst.ClassName .. " from " .. inst.Parent.Name) end
        inst:Destroy()
    end
end

-- Climb-in/out pose length is CarAnimFor (or Vehicles.EnterTime). Locally finish it at once.
Visual.skipCarAnim = function()
    local char = LP.Character
    if not (running and CFG.InstantSit and char) then return end
    local anim = char:GetAttribute("CarAnim")
    if (anim == "in" or anim == "out") and char:GetAttribute("CarAnimFor") ~= 0.001 then
        char:SetAttribute("CarAnimFor", 0.001)
    end
end

local seen = {}
-- Last death marker: where the character stood while it still had health, committed when it dies (Humanoid.Died or
-- RaidState "Dead"). Icon is the same pooled Lucide set, distance above, "Last death" below.
Visual.death = { pos = nil, alive = nil, aliveAt = 0, at = -10 }
Visual.DEATH_COL = Color3.fromRGB(255, 96, 96)
Visual.deathCommit = function(pos)
    local D = Visual.death
    local now = os.clock()
    if now - D.at < 5 then return end
    pos = pos or D.alive
    if not pos then return end
    D.pos, D.at = pos, now
    if CFG.ShotLog then warn(string.format("[hush] last death marked at %.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)) end
end
Visual.deathHide = function()
    local D = Visual.death
    if D.t1 then D.t1.Visible = false; D.t2.Visible = false end
end
Visual.deathStep = function(now, origin)
    local D = Visual.death
    if now - D.aliveAt >= 0.2 then
        D.aliveAt = now
        local char = LP.Character
        local hum = char and hum_of(char)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then D.alive = root.Position end
    end
    local pos = D.pos
    if not (CFG.DeathMarker and pos) or Visual.pvp.on then Visual.deathHide(); return end
    local sp = Cam:WorldToViewportPoint(pos)
    if sp.Z <= 0 then Visual.deathHide(); return end
    if not D.t1 then
        D.t1, D.t2 = make_text(26), make_text(26)
        D.t1.Size, D.t2.Size = 13, 13
    end
    local x, y = math.floor(sp.X + 0.5), math.floor(sp.Y + 0.5)
    Visual.icon.draw("DeathPin", x - 10, y - 20, 20, 1)
    put_text(D.t1, string.format("%d st", (pos - origin).Magnitude + 0.5), Visual.DEATH_COL, x, y - 38, 1)
    put_text(D.t2, "Last death", Visual.DEATH_COL, x, y + 3, 1)
end
Visual.deathStop = function()
    local D = Visual.death
    if D.t1 then D.t1:Remove(); D.t2:Remove(); D.t1, D.t2 = nil, nil end
    D.pos, D.alive = nil, nil
end

-- Extraction markers: models tagged "ExtractSite" with attributes SiteName, Kind, State and StormAt (the real position; the pivot is underground). Attributes re-read once a second.
-- Shared marker drawing: icon + distance above + label below, one pooled pair of texts per slot.
Visual.markText = function(P, n)
    local t = P.texts[n]
    if not t then
        t = { a = make_text(26), b = make_text(26) }
        t.a.Size, t.b.Size = 13, 13
        P.texts[n] = t
    end
    return t
end
Visual.markDraw = function(P, n, icon, size, col, alpha, x, y, top, bottom)
    local t = Visual.markText(P, n)
    if icon then
        Visual.icon.draw(icon, x - size * 0.5, y - size, size, alpha)
        put_text(t.a, top, col, x, y - size - 18, alpha)
        put_text(t.b, bottom, col, x, y + 3, alpha)
    else -- text only (WorldFinds)
        put_text(t.a, top, col, x, y - 14, alpha)
        put_text(t.b, bottom, col, x, y + 1, alpha)
    end
end
Visual.markHide = function(P, from)
    for i = from, #P.texts do
        local t = P.texts[i]
        t.a.Visible = false
        t.b.Visible = false
    end
end
Visual.markFree = function(P)
    for _, t in P.texts do t.a:Remove(); t.b:Remove() end
    table.clear(P.texts)
end
Visual.UP4 = Vector3.new(0, 4, 0)

Visual.exits = { rows = {}, list = {}, P = { texts = {} }, at = 0 }
Visual.EXIT_COL, Visual.EXIT_ACTIVE, Visual.EXIT_LOCKED = Color3.fromRGB(90, 230, 130), Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 84, 70)
Visual.exitScan = function(now)
    local E = Visual.exits
    E.at = now + 1
    table.clear(E.list)
    E.locked = ReplicatedStorage:GetAttribute("ExitsLocked") == true -- the game's own switch (Extract: readout LOCKED)
    for _, m in CollectionService:GetTagged("ExtractSite") do
        local pos, name = m:GetAttribute("StormAt"), m:GetAttribute("SiteName")
        if typeof(pos) == "Vector3" and type(name) == "string" then
            local r = E.rows[m]
            if not r then r = { di = -1 }; E.rows[m] = r end
            r.pos, r.name, r.state = pos, name, tostring(m:GetAttribute("State") or "")
            r.label = nil
            E.list[#E.list + 1] = r
        end
    end
end
Visual.exitStep = function(now, origin)
    local E = Visual.exits
    if not CFG.ExtractMarkers or Visual.pvp.on then
        Visual.markHide(E.P, 1)
        return
    end
    if now >= E.at then Visual.exitScan(now) end
    local n = 0
    for i = 1, #E.list do
        local r = E.list[i]
        local d = (r.pos - origin).Magnitude
        if d <= CFG.ExtractMaxDist then
            local sp = Cam:WorldToViewportPoint(r.pos + Visual.UP4)
            if sp.Z > 0 then
                n += 1
                local di = math.floor(d + 0.5)
                if r.di ~= di then r.di, r.dtxt = di, di .. " st" end
                local locked = E.locked
                if not r.label or r.lockedShown ~= locked then
                    r.lockedShown = locked
                    r.label = r.name .. (locked and " [LOCKED]" or (r.state ~= "" and r.state ~= "Ready" and (" [" .. r.state .. "]") or ""))
                end
                local icon, col = "ExitRun", Visual.EXIT_COL
                if locked then icon, col = "ExitRunLocked", Visual.EXIT_LOCKED
                elseif r.state == "Active" then icon, col = "ExitRunActive", Visual.EXIT_ACTIVE end
                Visual.markDraw(E.P, n, icon, 16, col, CFG.ExtractAlpha, math.floor(sp.X + 0.5), math.floor(sp.Y + 0.5), r.dtxt, r.label)
            end
        end
    end
    Visual.markHide(E.P, n + 1)
end

-- WorldFinds: workspace.WorldFinds holds Models named Find_<itemId> or Dropped_<itemId> (RareFind = true on rare ones); the id resolves through
-- Items.Defs. Positions are static, the folder is re-read once a second.
Visual.items = nil
Visual.itemDefs = function()
    if Visual.items == nil then
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        local inst = shared and shared:FindFirstChild("Items")
        local ok, m = pcall(require, inst)
        Visual.items = ok and type(m) == "table" and type(m.Defs) == "table" and m or false
    end
    return Visual.items
end
-- category (Weapons split into Firearms / Melee), rarity order (0 = unknown), def, rarity row
Visual.itemInfo = function(id)
    local I = Visual.itemDefs()
    local def = I and I.Defs[id]
    local rar = def and I.Rarity[def.rarity]
    local cat = def and def.category or "Unknown"
    if cat == "Weapons" then
        local g = guns()
        local gd = g and g.Defs[id]
        cat = (gd and gd.ammo ~= nil and not gd.melee) and "Firearms" or "Melee"
    end
    return cat, rar and rar.order or 0, def, rar
end
Visual.finds = { rows = setmetatable({}, { __mode = "k" }), list = {}, P = { texts = {} }, at = 0 }
Visual.FIND_COL = Color3.fromRGB(150, 225, 255)
Visual.findScan = function(now)
    local F = Visual.finds
    F.at = now + 1
    table.clear(F.list)
    local folder = Workspace:FindFirstChild("WorldFinds")
    if not folder then return end
    local I = Visual.itemDefs()
    local filter = CFG.FindFilter
    for _, m in folder:GetChildren() do
        if m:IsA("Model") then
            local pos = m:GetPivot().Position
            if pos.Magnitude > 2 then -- a streamed-out model sits at the origin
                local r = F.rows[m]
                if not r then
                    local id = m.Name:match("^%a+_(.+)$") or m.Name
                    local cat, rank, def, rar = Visual.itemInfo(id)
                    r = { di = -1, label = def and def.name or (id:gsub("_", " ")), col = rar and rar.color or Visual.FIND_COL,
                        cat = cat, rank = rank, rare = m:GetAttribute("RareFind") == true }
                    F.rows[m] = r
                end
                if r.rank >= CFG.FindMinRarity or r.rare or filter[r.cat] then
                    r.pos = pos
                    F.list[#F.list + 1] = r
                end
            end
        end
    end
end
Visual.findStep = function(now, origin)
    local F = Visual.finds
    if not CFG.FindMarkers or Visual.pvp.on then
        Visual.markHide(F.P, 1)
        return
    end
    if now >= F.at then Visual.findScan(now) end
    local n = 0
    for i = 1, #F.list do
        local r = F.list[i]
        local d = (r.pos - origin).Magnitude
        if d <= CFG.FindMaxDist then
            local sp = Cam:WorldToViewportPoint(r.pos + Visual.UP4)
            if sp.Z > 0 then
                n += 1
                local di = math.floor(d + 0.5)
                if r.di ~= di then r.di, r.dtxt = di, di .. " st" end
                Visual.markDraw(F.P, n, nil, 0, r.col, CFG.FindAlpha, math.floor(sp.X + 0.5), math.floor(sp.Y + 0.5), r.label, r.dtxt)
            end
        end
    end
    Visual.markHide(F.P, n + 1)
end

-- PvP mode: manual (CFG.PvPMode, key Insert) or automatic (CFG.PvPAuto): server combat flag (Player attribute CombatAt,
-- Config.QuickExtract.CombatSeconds 15 s) or an enemy player within PvPRange. Auto keeps itself on PvPHold s after the last trigger.
Visual.pvp = { on = false, at = 0, untilAt = 0, why = "" }
Visual.pvpTick = function(now)
    local P = Visual.pvp
    if now < P.at then return end
    P.at = now + 0.25
    local why = CFG.PvPMode and "manual" or nil
    if not why and CFG.PvPAuto then
        local c = LP:GetAttribute("CombatAt")
        if type(c) == "number" and Workspace:GetServerTimeNow() - c < 15 then
            why = "combat"
        else
            local char = LP.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local rp, r2 = root.Position, CFG.PvPRange * CFG.PvPRange
                for i = 1, #roster do
                    local plr = roster[i]
                    if is_enemy_player(plr) then
                        local er = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if er then
                            local d = er.Position - rp
                            if d:Dot(d) <= r2 then why = "enemy " .. math.floor(d.Magnitude) .. " st"; break end
                        end
                    end
                end
            end
        end
        if why then P.untilAt = now + CFG.PvPHold elseif now < P.untilAt then why = P.why end
    end
    local on = why ~= nil
    if on ~= P.on then warn("[hush] PvP mode " .. (on and ("ON (" .. why .. ")") or "OFF")) end
    P.on, P.why = on, why or ""
end

-- Bosses: Mother is the only boss the client can aim at; Mother.rayHit(origin, dir, range) is the game's own hit test, sent as the third Fire argument, so the aim is always a point rayHit confirms.
-- Walkers get markers/ESP only.
Visual.BOSS_COL = Color3.fromRGB(255, 72, 84)
Visual.boss = { list = {}, rows = setmetatable({}, { __mode = "k" }), P = { texts = {} }, lines = {}, at = 0, motherAt = 0,
    parts = {}, partsAt = 0, cand = {}, row = {}, pickAt = 0 }
Visual.bossMod = function()
    local B = Visual.boss
    if B.mod == nil then
        local scripts = LP:FindFirstChild("PlayerScripts")
        local client = scripts and scripts:FindFirstChild("Client")
        local inst = client and client:FindFirstChild("Mother")
        local ok, m = pcall(require, inst)
        B.mod = ok and type(m) == "table" and type(m.rayHit) == "function" and m or false
    end
    return B.mod
end
Visual.bossMother = function(now)
    local B = Visual.boss
    if now >= B.motherAt then
        B.motherAt = now + 0.5
        local m = Workspace:FindFirstChild("Mother")
        B.mother = (m and m:IsA("Model") and m.Parent) and m or nil
    end
    local m = B.mother
    if m and (m ~= B.partsFor or now >= B.partsAt) then
        B.partsFor, B.partsAt = m, now + 2
        table.clear(B.parts)
        for _, d in m:GetDescendants() do
            if d:IsA("BasePart") and d.Transparency < 1 and d.Size.Magnitude >= 3 then B.parts[#B.parts + 1] = d end
        end
    end
    return m
end
Visual.bossPick = function(from, fresh)
    if not CFG.Bosses then return nil end
    local now = os.clock()
    local B = Visual.boss
    local model = Visual.bossMother(now)
    if not model then return nil end
    if not fresh and now < B.pickAt then return B.pickRow end
    local mod = Visual.bossMod()
    Cam = Workspace.CurrentCamera
    if not (mod and Cam) then return nil end
    local reach = sa_reach()
    local vp = Cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local rpx = fov_px()
    local maxR2 = rpx * rpx
    local cand, n, parts = B.cand, 0, B.parts
    for k = 1, 3 do cand[k] = cand[k] or {} end
    -- the three parts nearest the crosshair
    for i = 1, #parts do
        local p = parts[i]
        if p.Parent then
            local pos = p.Position
            if (pos - from).Magnitude <= reach + 30 then
                local sp, on = Cam:WorldToViewportPoint(pos)
                if on and sp.Z > 0 then
                    local dx, dy = sp.X - cx, sp.Y - cy
                    local e = dx * dx + dy * dy
                    if e <= maxR2 and (n < 3 or e < cand[n].e) then
                        if n < 3 then n += 1 end
                        local at = n
                        cand[at].p, cand[at].e = p, e
                        while at > 1 and cand[at - 1].e > e do
                            cand[at], cand[at - 1] = cand[at - 1], cand[at]
                            at -= 1
                        end
                    end
                end
            end
        end
    end
    local result
    for k = 1, n do
        local p = cand[k].p
        local v = p.Position - from
        local dist = v.Magnitude
        if dist >= 3 then
            local dir = v / dist
            local hit = mod.rayHit(from, dir, math.min(dist + 40, reach))
            if hit and hit <= reach then
                local point = from + dir * hit
                if not CFG.VisibleCheck or world_clear(from, point, model) then
                    local row = B.row
                    row.model, row.bone, row.pos, row.raw, row.dist, row.fov2, row.tier, row.key = model, p, point, point, hit, cand[k].e, -1, -1
                    row.spoof, row.peek, row.lead, row.speed, row.veh, row.bodyAim = from, nil, 0, 0, false, nil
                    row.how = "boss"
                    result = row
                    break
                end
            end
        end
    end
    B.pickAt, B.pickRow = now + 0.1, result
    return result
end
Visual.bossAdd = function(B, model, name, src)
    local r = B.rows[model]
    if not r then r = { boxAt = 0, di = -1, label = name }; B.rows[model] = r end
    r.model, r.name, r.src = model, name, src
    B.list[#B.list + 1] = r
end
Visual.bossScan = function(now)
    local B = Visual.boss
    B.at = now + 0.5
    table.clear(B.list)
    local mother = Visual.bossMother(now)
    if mother then Visual.bossAdd(B, mother, "MOTHER", ReplicatedStorage:FindFirstChild("Mother")) end
    local w = Workspace:FindFirstChild("Walkers")
    if w then
        for _, m in w:GetChildren() do
            if m:IsA("Model") then Visual.bossAdd(B, m, "WALKER", m) end
        end
    end
end
Visual.bossLinesHide = function(B, from)
    for k = from, #B.lines do B.lines[k].Visible = false end
end
-- Mother's bounding box is useless (1081 st wide, under the map, no Head/PrimaryPart): the marker hangs on the largest part named "head" and the ESP box uses only the parts within BOSS_CLUSTER studs, re-read twice a second.
Visual.BOSS_CLUSTER = 150
Visual.bossBox = function(r, m, now)
    local a = r.anchor
    if not (a and a.Parent) or now >= (r.anchorAt or 0) then
        r.anchorAt = now + 3
        a = m:FindFirstChild("Head")
        if not (a and a:IsA("BasePart")) then
            a = nil
            local best = 0
            for _, d in m:GetDescendants() do
                if d:IsA("BasePart") and string.lower(d.Name) == "head" then
                    local v = d.Size.X * d.Size.Y * d.Size.Z
                    if v > best then a, best = d, v end
                end
            end
        end
        r.anchor = a
    end
    if not a then
        local cf, size = m:GetBoundingBox() -- a rig without any head part: the box is all there is
        r.cf, r.size, r.mid = cf, size, nil
        return
    end
    r.top = math.max(3, a.Size.Y * 0.5 + 3)
    r.cf = CFrame.new(a.Position) -- fallback when the head part vanishes before the next re-read
    if CFG.BossMarkers then
        r.mid, r.size = nil, a.Size
        return
    end
    local c, lo, hi = a.Position, nil, nil
    local R2 = Visual.BOSS_CLUSTER * Visual.BOSS_CLUSTER
    for _, d in m:GetDescendants() do
        if d:IsA("BasePart") then
            local dp = d.Position
            local off = dp - c
            if off.X * off.X + off.Y * off.Y + off.Z * off.Z <= R2 then
                local h = d.Size * 0.5
                local l, u = dp - h, dp + h -- axis-aligned approximation, good enough for a 2D box
                lo = lo and Vector3.new(math.min(lo.X, l.X), math.min(lo.Y, l.Y), math.min(lo.Z, l.Z)) or l
                hi = hi and Vector3.new(math.max(hi.X, u.X), math.max(hi.Y, u.Y), math.max(hi.Z, u.Z)) or u
            end
        end
    end
    if lo then
        r.mid, r.size = (lo + hi) * 0.5 - c, hi - lo
    else
        r.mid, r.size = Vector3.zero, a.Size
    end
end
Visual.bossStep = function(now, origin)
    local B = Visual.boss
    if not (CFG.BossMarkers or CFG.Bosses) then
        Visual.markHide(B.P, 1)
        Visual.bossLinesHide(B, 1)
        return
    end
    if now >= B.at then Visual.bossScan(now) end
    local n, ln = 0, 0
    for i = 1, #B.list do
        local r = B.list[i]
        local m = r.model
        if m.Parent then
            if now >= r.boxAt then
                r.boxAt = now + 0.5
                Visual.bossBox(r, m, now)
                local src = r.src
                local hp = src and src:GetAttribute("Health")
                local mx = src and (src:GetAttribute("HealthMax") or src:GetAttribute("MaxHealth"))
                local ph = src and (src:GetAttribute("Phase") or src:GetAttribute("State"))
                r.label = r.name .. ((type(hp) == "number" and type(mx) == "number" and mx > 0) and string.format(" %d%%", math.floor(hp / mx * 100 + 0.5)) or "")
                    .. (ph ~= nil and (" [" .. tostring(ph) .. "]") or "")
            end
            local a = r.anchor
            local live = a and a.Parent and a.Position or nil -- the head moves every frame, the box is re-read twice a second
            local centre = live and (live + (r.mid or Vector3.zero)) or r.cf.Position
            local d = ((live or centre) - origin).Magnitude
            if d <= 6000 then
                local di = math.floor(d + 0.5)
                if r.di ~= di then r.di, r.dtxt = di, di .. " st" end
                if CFG.BossMarkers then
                    local sp = Cam:WorldToViewportPoint(live and (live + Vector3.new(0, r.top or 3, 0)) or centre)
                    if sp.Z > 0 then
                        n += 1
                        Visual.markDraw(B.P, n, "BossSkull", 20, Visual.BOSS_COL, 1, math.floor(sp.X + 0.5), math.floor(sp.Y + 0.5), r.dtxt, r.label)
                    end
                else
                    -- ESP: 2D box around the projected oriented bounding box
                    local cf, hs = CFrame.new(centre), r.size * 0.5
                    if not live then cf = r.cf end
                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                    for c = 0, 7 do
                        local sp = Cam:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(
                            (c % 2 == 0) and -hs.X or hs.X, (c // 2 % 2 == 0) and -hs.Y or hs.Y, (c // 4 == 0) and -hs.Z or hs.Z)))
                        if sp.Z > 0 then
                            minX, maxX = math.min(minX, sp.X), math.max(maxX, sp.X)
                            minY, maxY = math.min(minY, sp.Y), math.max(maxY, sp.Y)
                        end
                    end
                    if minX < maxX then
                        local col = Visual.BOSS_COL
                        local x1, y1, x2, y2 = math.floor(minX), math.floor(minY), math.floor(maxX), math.floor(maxY)
                        local edges = { { x1, y1, x2, y1 }, { x2, y1, x2, y2 }, { x2, y2, x1, y2 }, { x1, y2, x1, y1 } }
                        for k = 1, 4 do
                            ln += 1
                            local line = B.lines[ln]
                            if not line then line = new_line(21, 2); B.lines[ln] = line end
                            local e = edges[k]
                            put_line(line, col, 2, 1, 21, e[1], e[2], e[3], e[4])
                        end
                        n += 1
                        local t = Visual.markText(B.P, n)
                        local cxm = math.floor((x1 + x2) * 0.5)
                        put_text(t.a, r.dtxt, col, cxm, y1 - 16, 1)
                        put_text(t.b, r.label, col, cxm, y2 + 3, 1)
                    end
                end
            end
        end
    end
    Visual.markHide(B.P, n + 1)
    Visual.bossLinesHide(B, ln + 1)
end
Visual.markersStop = function()
    for _, P in { Visual.exits.P, Visual.finds.P, Visual.boss.P } do Visual.markFree(P) end
    for _, l in Visual.boss.lines do l:Remove() end
    table.clear(Visual.boss.lines)
    table.clear(Visual.exits.rows); table.clear(Visual.exits.list)
    table.clear(Visual.finds.rows); table.clear(Visual.finds.list)
    table.clear(Visual.boss.rows); table.clear(Visual.boss.list)
end

-- ============================ Staff detect ============================
-- see CFG.StaffDetect. Scan at 4 Hz (20 players x 3-4 attribute reads), banner animation only while somebody is found.
Visual.staff = { found = {}, n = 0, nextScan = 0, banner = nil, sub = nil, grp = {}, kickAt = nil, warned = {} }
Visual.staffRole = function(p)
    local a = p:GetAttribute("StaffRank")
    if type(a) == "string" and a ~= "" then return a end
    local cfg = Visual.speedCfg()
    if cfg then
        local id = p.UserId
        if cfg.Admins and cfg.Admins[id] then return "admin (Config)" end
        if cfg.Moderators and cfg.Moderators[id] then return "mod (Config)" end
        if CFG.StaffClippers and cfg.Clippers and cfg.Clippers[id] then return "clipper (Config)" end
    end
    if p:GetAttribute("AdminInvisible") == true or p:GetAttribute("AdminFly") == true then return "admin (invisible/fly)" end
    local c = p.Character
    if c and (c:GetAttribute("AdminInvisible") == true or c:GetAttribute("AdminFly") == true) then return "admin (invisible/fly)" end
    local need = CFG.StaffGroupRank
    if need and need > 0 and game.CreatorType == Enum.CreatorType.Group then
        local G = Visual.staff.grp
        local r = G[p.UserId]
        if r == nil then
            G[p.UserId] = false -- asked: the answer comes later (a network call, ~0.2 s)
            task.spawn(function()
                local ok, rank = pcall(function() return p:GetRankInGroup(game.CreatorId) end)
                G[p.UserId] = ok and rank or 0
            end)
        elseif r and r >= need then
            return "group rank " .. tostring(r)
        end
    end
    return nil
end
Visual.staffText = function(z, size)
    local t = make_text(z)
    t.Size = size
    return t
end
Visual.staffTick = function(now)
    local S = Visual.staff
    if CFG.StaffDetect == "Off" or not CFG.StaffDetect then
        if S.n > 0 or S.banner then Visual.staffStop() end
        return
    end
    if now >= S.nextScan then
        S.nextScan = now + 0.25
        local n = 0
        for _, p in Players:GetPlayers() do
            if p ~= LP and not (CFG.StaffIgnore[p.UserId] or CFG.StaffIgnore[p.Name]) then
                local role = Visual.staffRole(p)
                if role then
                    n += 1
                    local row = S.found[n]
                    if not row then row = {}; S.found[n] = row end
                    local grants = p:GetAttribute("StaffGrants")
                    row.p, row.role, row.grants = p, role, type(grants) == "string" and grants or nil
                    local key = p.UserId .. role .. (row.grants or "")
                    if not S.warned[key] then -- again when the role or the grants change (they are handed out live)
                        S.warned[key] = true
                        warn(string.format("[hush] STAFF DETECTED: %s (%d) role %s | grants %s | invisible %s invincible %s", p.Name, p.UserId, role, row.grants or "-",
                            tostring(p:GetAttribute("AdminInvisible") == true), tostring(p:GetAttribute("AdminInvincible") == true)))
                    end
                end
            end
        end
        for i = n + 1, #S.found do S.found[i].p = nil end
        S.n = n
        if n > 0 and CFG.StaffDetect == "Kick" and not S.kickAt then S.kickAt = now + (CFG.StaffKickDelay or 0) end
        if n == 0 then S.kickAt = nil end
    end
    if S.kickAt and now >= S.kickAt then
        S.kickAt = nil
        warn("[hush] staff mode Kick: leaving")
        local ok = pcall(function() LP:Kick(CFG.StaffKickMsg or "staff detected") end)
        if not ok then pcall(function() game:Shutdown() end) end
    end
    if S.n == 0 then
        if S.banner then S.banner.Visible = false; S.sub.Visible = false end
        return
    end
    if not S.banner then
        S.banner = Visual.staffText(60, 36)
        S.sub = Visual.staffText(60, 16)
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local cx = cam.ViewportSize.X * 0.5
    local pulse = 0.5 + 0.5 * math.sin(now * 7)
    local b = S.banner
    b.Color = Color3.new(1, 0.15 + 0.35 * pulse, 0.15 + 0.2 * pulse)
    b.Text = "STAFF DETECTED!"
    b.Position = Vector2.new(cx, 56)
    b.Transparency = 0.7 + 0.3 * pulse
    b.Visible = true
    local parts = {}
    local me = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    for i = 1, math.min(S.n, 3) do
        local row = S.found[i]
        local root = row.p.Character and row.p.Character:FindFirstChild("HumanoidRootPart")
        local d = me and root and math.floor((root.Position - me.Position).Magnitude + 0.5)
        local g = row.grants and (" {" .. string.sub(row.grants, 1, 28) .. "}") or ""
        parts[#parts + 1] = string.format("%s [%s]%s%s", row.p.DisplayName ~= "" and row.p.DisplayName or row.p.Name, string.upper(string.match(row.role, "^%a+") or row.role), g, d and (" " .. d .. " st") or "")
    end
    if S.n > 3 then parts[#parts + 1] = "+" .. (S.n - 3) end
    local sub = S.sub
    sub.Color = Color3.new(1, 0.85, 0.85)
    sub.Text = table.concat(parts, "   ·   ") .. (CFG.StaffDetect == "Kick" and "   (kick)" or "")
    sub.Position = Vector2.new(cx, 100)
    sub.Transparency = 1
    sub.Visible = true
end
Visual.staffStop = function()
    local S = Visual.staff
    if S.banner then S.banner:Remove(); S.sub:Remove(); S.banner, S.sub = nil, nil end
    S.n, S.kickAt = 0, nil
    table.clear(S.warned)
end

local function step(dt)
    if not running then
        return
    end
    dt = math.clamp(type(dt) == "number" and dt or 0.016, 0, 0.05)
    Visual.dt = dt
    visPhase += dt * 1.15
    Cam = Workspace.CurrentCamera
    if not Cam then
        return
    end
    local now = os.clock()
    local origin = Cam.CFrame.Position
    local measuredAt = os.clock()
    local stepStart = measuredAt
    Visual.memStart()
    if held.firearm then
        draw_fov()
    else
        hide_fov()
    end
    if CFG.Resolver and CFG.Silent and held.firearm then Resolver.sweep(now) end
    if CFG.AimSpoofHold and saTgt and held.firearm and Visual.fire.u then Visual.aimSpoof(Cam.CFrame.LookVector, true) end
    Visual.alwaysAimStep()
    if CFG.Silent and held.firearm and (now - pickAt + 1e-6 >= (CFG.PickRate or 1 / 60)) then
        pickAt = now
        -- Resolve against the honest head origin; hold the chosen peek between solves.
        saTgt = resolve_target(origin, false)
    elseif not CFG.Silent or not held.firearm then
        saTgt = nil
    end
    if saTgt and saTgt.pos and held.firearm then
        local pen = Visual.pen(retLines)
        Visual.aim(pen, saTgt, CFG.MuzzleVisual and muzzle_pos() or nil, now, CFG.AimVisuals)
        pen.finish()
        retHidden = false

    else
        Visual.lock.model = nil

        hide_aim_lines()
    end
    measuredAt = Visual.measure("aim", measuredAt)
    draw_killaura()
    measuredAt = Visual.measure("kaArt", measuredAt)
    table.clear(seen)
    if CFG.ESP then
        for i = 1, #roster do
            local plr = roster[i]
            local char = plr.Character
            if char then
                seen[char] = true
                local rel = Rel.of(plr, now)
                local root = root_of(char)
                if root and now < (farUntil[char] or 0) then
                    -- out of range a moment ago: skip all work until the next 0.25 s re-test
                elseif root and (root.Position - origin).Magnitude > CFG.EspPlayerMaxDist then
                    farUntil[char] = now + 0.25
                    local o = espByModel[char]
                    if o then hide_esp(o) end
                elseif is_corpse(char) then
                    update_esp_one(char, plr, origin, COL_CORPSE)
                elseif rel == "out" then
                    local o = espByModel[char]
                    if o then hide_esp(o) end
                elseif alive_ui(char, now) and (rel == "foe" or CFG.EspAllies) then
                    update_esp_one(char, plr, origin, nil, rel)
                else
                    local o = espByModel[char]
                    if o then hide_esp(o) end
                end
            end
        end
        measuredAt = Visual.measure("espPlr", measuredAt)
        if CFG.Monsters then
            local list = monsters()
            for i = 1, #list do
                local m = list[i]
                seen[m] = true
                local root = root_of(m)
                if root and now < (farUntil[m] or 0) then
                    -- far: skip until the next re-test
                elseif root and (root.Position - origin).Magnitude > CFG.EspNpcMaxDist then
                    farUntil[m] = now + 0.25
                    local o = espByModel[m]
                    if o then hide_esp(o) end
                elseif alive_ui(m, now) then
                    update_esp_one(m, nil, origin)
                else
                    local o = espByModel[m]
                    if o then hide_esp(o) end
                end
            end
        end
    else
        for _, o in espByModel do
            hide_esp(o)
        end
    end
    measuredAt = Visual.measure("espNpc", measuredAt)
    espPool.sweep(seen, now)
    measuredAt = Visual.measure("sweep", measuredAt)
    Visual.worldDraw(origin)
    measuredAt = Visual.measure("world", measuredAt)
    Visual.pvpTick(now)
    draw_loot(dt, origin)
    measuredAt = Visual.measure("loot", measuredAt)
    draw_mock(dt)
    measuredAt = Visual.measure("mock", measuredAt)
    Visual.stepLiveFx(now)
    measuredAt = Visual.measure("liveFx", measuredAt)
    Visual.deathStep(now, origin)
    Visual.exitStep(now, origin)
    Visual.findStep(now, origin)
    Visual.bossStep(now, origin)
    measuredAt = Visual.measure("marks", measuredAt)
    Visual.aimSpoofTick(now)
    Visual.pfxStep(Cam, now)
    measuredAt = Visual.measure("particles", measuredAt)
    Visual.icon.flush()
    Visual.measure("iconFlush", measuredAt)
    Visual.measureT("STEP", stepStart)
end

local function unload()
    if not running then return end
    running = false
    Life.uiState = nil
    Visual.aimSpoofTick(math.huge) -- take a spoofed ADS back
    Visual.dbgFlush(0, true)
    Life.clear(connections)
    Visual.worldStop()
    Visual.baseStop()
    Visual.weaponScaleStop()
    Visual.skinStop()
    Visual.swapStop()
    Visual.stopLiveFx()
    Visual.deathStop()
    game:GetService("ContextActionService"):UnbindAction("HushMoveKeys")
    Visual.markersStop()
    Visual.dnClear()
    Visual.staffStop()
    Visual.moveStop()
    Visual.sitStop()
    Life.clear(Life.char)
    Life.clear(Life.monsters)
    Life.character = nil
    RunService:UnbindFromRenderStep("HushKA_Facing")
    RunService:UnbindFromRenderStep("HushSwap")
    Visual.kaFaceStop()
    if Visual.hitGroup then Visual.hitGroup:Destroy(); Visual.hitGroup = nil end
    if Visual.sledgeBind then
        Visual.sledgeBind.aim = Visual.sledgeOriginalAim
        Visual.sledgeBind.swing = Visual.sledgeOriginalSwing
        Visual.sledgeBind.__hushAim = nil
    end
    Loot.stopAuto()
    for prompt in searchPrompts do Loot.remove(prompt) end
    for _, cache in Loot.scan do table.clear(cache.rows); table.clear(cache.keys) end
    for part, conn in Loot.waiting do conn:Disconnect(); Loot.waiting[part] = nil end
    table.clear(lootKnown)
    table.clear(Loot.moving)
    table.clear(Loot.byPart)
    table.clear(Loot.grid)
    Loot.module, Loot.gui = nil, nil
    for _, buffer in Loot.bufs do table.clear(buffer.rows); table.clear(buffer.d2); buffer.n = 0 end
    if restorefunction then
        if Life.shootTarget then restorefunction(Life.shootTarget); Life.shootTarget = nil end
        if Visual.everywhere.target then restorefunction(Visual.everywhere.target); Visual.everywhere.target = nil end
    end
    hooked = false
    espPool.destroy()
    Visual.clearParticles(true)
    for _, pen in Visual.pens do
        for _, tri in pen.tris do tri:Remove() end
        for _, quad in pen.quads do quad:Remove() end
    end
    table.clear(Visual.pens)
    table.clear(visCache)
    table.clear(shotAt)
    table.clear(reloadAt)
    table.clear(aimPartCache)
    table.clear(humCache)
    table.clear(humRecheck)
    table.clear(Resolver.track)
    table.clear(Visual.mp)
    table.clear(monsterList)
    table.clear(roster)
    saTgt, kaAim, lastAim, ka.tgt = nil, nil, nil, nil
    Visual.lock.model = nil
    table.clear(Rel.cache)
    hide_fov()
    for i = 1, FOV_N do
        fovLines[i]:Remove()
    end
    hide_aim_lines()
    for i = 1, RET_N do
        retLines[i]:Remove()
    end
    hide_ka()
    for i = 1, KA_N do
        kaLines[i]:Remove()
    end
    hide_mock()
    for i = 1, #mockLines do
        mockLines[i]:Remove()
    end
    for i = 1, #mockText do
        mockText[i]:Remove()
    end
    Visual.fxFree()
    table.clear(Visual.mockActors)
    table.clear(stations)
    hide_loot()
    for i = 1, #lootLines do
        lootLines[i]:Remove()
    end
    for i = 1, #lootText do
        lootText[i]:Remove()
    end
    getgenv().HushSilent = nil
    warn("[hush] unloaded")
end

bind(UserInputService.InputBegan:Connect(function(input)
    -- not gated on `processed`: the game's own binds mark keys processed (K = Backpack)
    if Life.uiActive or UserInputService:GetFocusedTextBox() then return end
    local key, keys = input.KeyCode, CFG.Keys
    if key == keys.ESP then
        CFG.ESP = not CFG.ESP
    elseif key == keys.Gallery then
        drop_mock()
    elseif key == keys.AutoDecrypt then
        CFG.AutoDecrypt = not CFG.AutoDecrypt
        if not CFG.AutoDecrypt then Loot.stopAuto() end
        Loot.say(CFG.AutoDecrypt and "ON (fireproximityprompt, radius " .. CFG.AutoDecryptRadius .. ")" or "OFF")
    elseif key == keys.LootFilter then
        CFG.LootMinRarity = CFG.LootMinRarity == 1 and 3 or 1
        CFG.LootUnknown = CFG.LootMinRarity == 1
        Loot.nextQuery = 0
        warn("[hush] loot filter: " .. (CFG.LootMinRarity == 3 and "confirmed Rare+ only" or "all + unknown"))
    elseif key == keys.Perf then
        warn("[hush] sections/resources: " .. game:GetService("HttpService"):JSONEncode({ sections = getgenv().HushSilent.perf(), resources = Life.snapshot() }))
    elseif key == keys.Speed then
        Visual.toggle("Speed")
    elseif key == keys.HighJump then
        Visual.toggle("HighJump")
    elseif key == keys.AutoJump then
        Visual.toggle("AutoJump")
    elseif key == keys.FastClimb then
        Visual.toggle("FastClimb")
    elseif key == keys.Strafer then
        Visual.toggle("Strafer")
    elseif key == keys.PvP then
        Visual.toggle("PvPMode")
    elseif key == keys.FullAuto then
        Visual.toggle("FullAuto")
    elseif key == keys.ShootEverywhere then
        Visual.toggle("ShootEverywhere")
    elseif key == keys.ParticleTest then
        Visual.pfxDemo()
    elseif key == keys.WeaponFx then
        Visual.toggle("WeaponFx")
    elseif key == keys.SelfFx then
        Visual.toggle("SelfFx")
    elseif key == keys.ModelSwap then
        Visual.toggle("ModelSwap")
    elseif key == keys.ModelSwapNext then
        local order, at = Visual.SWAP_ORDER, 1
        for i, n in order do if n == CFG.ModelSwapModel then at = i end end
        CFG.ModelSwapModel = order[at % #order + 1]
        warn("[hush] ModelSwap model: " .. CFG.ModelSwapModel)
    elseif key == keys.Unload then
        unload()
    end
end))
-- X is the game's HANDS UP on foot (AntiCheat.HeldUp caps speed at 16 while it is active): swallow the key at the
-- ContextAction layer so toggling Speed does not also raise the hands. Only effective if the game binds it there.
game:GetService("ContextActionService"):BindActionAtPriority("HushMoveKeys", function() return Enum.ContextActionResult.Sink end,
    false, 3000, CFG.Keys.Speed, CFG.Keys.HighJump)

bind(RunService.RenderStepped:Connect(step))
bind(RunService.PreSimulation:Connect(Visual.moveStep))
bind(RunService.PostSimulation:Connect(Visual.hopHorizontalPost))
Visual.worldStart()
bind(game:GetService("ProximityPromptService").PromptShown:Connect(Visual.onPromptShown))
-- Runs after the game's Camera/Character yaw writers; Heartbeat yaw alone is overwritten.
RunService:BindToRenderStep("HushKA_Facing", Enum.RenderPriority.Character.Value + 1, Visual.kaFaceStep)
-- after the game's cameraStep (Camera+1) rewrote u108: keeps the HUD crosshair and the next shot on the camera centre
RunService:BindToRenderStep("HushSwap", Enum.RenderPriority.Camera.Value + 3, Visual.swapStep)
Visual.perfAt = os.clock() + 15
bind(RunService.Heartbeat:Connect(function()
    if not running then
        return
    end
    local hbStart = os.clock()
    Visual.memStart()
    refresh_held()
    local now = hbStart
    Visual.baseTick(now)
    Visual.skinTick(now)
    Visual.weaponScaleTick(now)
    Visual.autoWire()
    Visual.measure("hbBase", hbStart)
    if not hooked and held.firearm and now >= Install.nextAt and Install.tries < 8 then
        Install.tries += 1
        Install.nextAt = now + 1.5
        local ok, err = pcall(try_install)
        if not ok then
            Install.why = tostring(err)
        end
        if not hooked and Install.tries == 8 then
            warn("[hush] silent off: " .. tostring(Install.why) .. ". Unequip and equip a firearm to retry.")
        end
    end
    Visual.ledSweep(now)
    Visual.dbgTick(now)
    Visual.staffTick(now)
    local t0 = os.clock()
    step_killaura(now)
    t0 = Visual.measure("hbKillAura", t0)
    Loot.auto(now)
    Loot.expireKnown(now)
    Visual.measure("hbAutoOpen", t0)
    Visual.measureT("HB", hbStart)
    if CFG.PerfLog and now >= Visual.perfAt then
        Visual.perfAt = now + 15
        Visual.report()
    end
end))

local function watch_char(char)
    if not running or not char or Life.character == char then return end
    Life.clear(Life.char)
    Life.character = char
    Life.char[1] = char:GetAttributeChangedSignal("Gun"):Connect(refresh_held)
    Life.char[2] = char.ChildAdded:Connect(function(ch)
        if ch.Name == "HeldGun" then
            held.model = nil
            refresh_held()
        end
    end)
    Life.char[3] = char:GetAttributeChangedSignal("CarAnimAt"):Connect(Visual.skipCarAnim)
    Life.char[4] = char:GetAttributeChangedSignal("CarAnimFor"):Connect(Visual.skipCarAnim)
    Life.char[5] = char:GetAttributeChangedSignal("Ragdoll"):Connect(function()
        -- next frame: the game's own handler (stun/bounce) runs on the same change
        task.defer(Visual.unRagdoll)
    end)
    local hum = hum_of(char)
    if hum then
        Life.char[6] = hum.Died:Connect(function()
            local root = char:FindFirstChild("HumanoidRootPart")
            Visual.deathCommit(root and root.Position)
        end)
    end
    Life.char[7] = char.DescendantAdded:Connect(Visual.noPush)
    for _, d in char:GetDescendants() do Visual.noPush(d) end
    refresh_held()
end
bind(LP:GetAttributeChangedSignal("RaidState"):Connect(function()
    if LP:GetAttribute("RaidState") == "Dead" then Visual.deathCommit() end
end))

if LP.Character then
    watch_char(LP.Character)
end
bind(LP.CharacterAdded:Connect(watch_char))
bind(LP.CharacterRemoving:Connect(function(char)
    if Life.character == char then Life.clear(Life.char); Life.character = nil end
end))

-- Gun "Hit" is server feedback for both gun and melee. Playback is independent of shot logs.
-- Plain-data copy of a server payload for the debug file (Instances by name, vectors as arrays, depth and size bounded).
Visual.dbgPlain = function(v, depth)
    local t = typeof(v)
    if t == "number" then return Visual.dbgR(v) end
    if t == "string" or t == "boolean" or v == nil then return v end
    if t == "Vector3" then return Visual.dbgV(v) end
    if t == "CFrame" then local p0, l = v.Position, v.LookVector return { p = Visual.dbgV(p0), look = Visual.dbgV(l) } end
    if t == "Instance" then return v:GetFullName() end
    if t == "table" and depth < 4 then
        local out, n = {}, 0
        for k, x in v do
            n += 1
            if n > 40 then break end
            out[tostring(k)] = Visual.dbgPlain(x, depth + 1)
        end
        return out
    end
    return tostring(v)
end
-- ShotLand / Shot carry the direction and impact the server used for each round (dir, hit.pos, seq, k), ours included: logged raw so the server's spread can be measured offline.
Visual.sentBySeq = {}
Visual.onEffectShot = function(action, payload)
    if payload.shooter ~= LP then return end
    if action == "Shot" and type(payload.seq) == "number" then
        local rec = Visual.sentBySeq[payload.seq]
        Visual.sentBySeq[payload.seq - 64] = nil
        if rec then
            local shifted = typeof(payload.origin) == "Vector3" and (payload.origin - rec.from).Magnitude > 0.5
            if shifted then
                warn(string.format("[hush] shot #%d: the SERVER fired from %.2f st away from the origin we claimed (OriginSlack): same direction, the bullet is shifted by that much", payload.seq, (payload.origin - rec.from).Magnitude))
            end
            -- the server's own cone radius, from the direction it fired (arcs.v[k] = launch velocity): feeds Visual.coneR (ServerSpread)
            local v = type(payload.arcs) == "table" and type(payload.arcs.v) == "table" and (payload.arcs.v[1] or payload.arcs.v["1"])
            local def = type(payload.gun) == "string" and gun_row(payload.gun)
            if rec.aiming and not shifted and def and (def.pellets or 1) <= 1 and typeof(v) == "Vector3" and v.Magnitude > 1 then
                local u = v.Unit
                local d = u:Dot(rec.dir)
                if d > 0.5 then Visual.coneAdd(rec.coneKey, (u / d - rec.dir).Magnitude) end
            end
        end
    end
    if action == "ShotLand" and type(payload.seq) == "number" then
        Visual.ledLand(payload.seq, type(payload.hit) == "table" and payload.hit.kind or nil)
    end
    if not CFG.DebugFile then return end
    Visual.dbgW({ ev = "srv_" .. action, t = Visual.dbgR(os.clock()), st = Visual.dbgR(Workspace:GetServerTimeNow()), payload = Visual.dbgPlain(payload, 0) })
end
Visual.onGunEvent = function(action, kind)
    if not running then return end
    if action == "Hit" then
        play_hit()
        Visual.hitAck()
        Visual.dbgW({ ev = "gun", action = "Hit", kind = tostring(kind), ktype = typeof(kind), t = Visual.dbgR(os.clock()), st = Visual.dbgR(Workspace:GetServerTimeNow()), pending = #Visual.led.q })
        Visual.ledHit()
        local f = Visual.liveFx
        burst(f.landPos and f.landAt and os.clock() - f.landAt < 0.5 and f.landPos or lastAim)
    elseif action == "State" then
        -- Server-owned reload clock: Guns.lua overwrites the local reload end with this value.
        local left = type(kind) == "table" and kind.reloadLeft
        if CFG.ShotLog and type(left) == "number" and left > 0 and os.clock() - (Visual.reloadLogAt or 0) > 1 then
            Visual.reloadLogAt = os.clock()
            warn(string.format("[hush] server reload timer %.2fs (client cannot shorten it)", left))
        end
    else
        local note = tostring(action)
        Visual.dbgW({ ev = "gun", action = note, kind = type(kind) == "table" and "(table)" or tostring(kind), t = Visual.dbgR(os.clock()), pending = #Visual.led.q })
        local last = Visual.led.q[#Visual.led.q]
        if last then last.note = note end
    end
end

task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
    local gun = remotes and remotes:WaitForChild("Gun", 20)
    if gun and gun:IsA("RemoteEvent") then
        bind(gun.OnClientEvent:Connect(Visual.onGunEvent))
    end
    local effect = remotes and remotes:WaitForChild("Effect", 20)
    if effect and effect:IsA("RemoteEvent") then
        bind(effect.OnClientEvent:Connect(function(action, payload)
            if not running or type(payload) ~= "table" then
                return
            end
            local who = payload.shooter or payload.char
            if action == "ShotLand" or action == "Shot" then Visual.onEffectShot(action, payload) end
            if action == "SupplyDrop" or action == "SupplyLand" or action == "SupplyBlare" or action == "SupplyOpen" then
                Visual.onSupply(action, payload)
                return
            end
            if action == "Shot" or action == "SledgeHit" then
                if who then
                    shotAt[who] = os.clock()
                end
                local sent = Visual.kaSent
                if action == "SledgeHit" and payload.shooter == LP and CFG.ShotLog and sent and sent.fired and os.clock() - sent.at < 1.5 then
                    local hit = type(payload.hit) == "table" and payload.hit or nil
                    local tr = sent.model and sent.model:FindFirstChild("HumanoidRootPart")
                    local hp = hit and typeof(hit.pos) == "Vector3" and hit.pos
                    warn(string.format("[hush] KA server: landed %s | kind %s | part %s | miss %.2f | lead %.2f | dt %.2f",
                        tostring(payload.landed), tostring(hit and hit.kind), tostring(hit and (hit.part or hit.name)),
                        (hp and tr) and (hp - tr.Position).Magnitude or -1, sent.lead, os.clock() - sent.at))
                end
            elseif action == "Reload" or action == "Prime" then
                if payload.char then
                    reloadAt[payload.char] = os.clock()
                end
            end
        end))
    end
    local lootRemote = remotes and remotes:WaitForChild("Loot", 20)
    if lootRemote and lootRemote:IsA("RemoteEvent") then
        Loot.remote = lootRemote
        bind(lootRemote.OnClientEvent:Connect(function(action, part, a, b)
            note_loot(action, part, a, b)
        end))
    end
end)

task.spawn(function()
    -- Runtime: all 836 SearchPrompts belong to 836 tagged LootContainer parts.
    -- No Workspace-wide listeners and no 132k-instance initial traversal.
    bind(CollectionService:GetInstanceAddedSignal("LootContainer"):Connect(Loot.watchContainer))
    bind(CollectionService:GetInstanceRemovedSignal("LootContainer"):Connect(Loot.dropContainer))
    local list = CollectionService:GetTagged("LootContainer")
    for i = 1, #list do
        if not running then return end
        Loot.watchContainer(list[i])
        if i % 100 == 0 then task.wait() end
    end
end)

task.spawn(function()
    for _ = 1, 240 do
        if not running then
            return
        end
        if not sledgeMod then
            pcall(hook_sledge)
        end
        if sledgeMod then
            pcall(retry_aim_wrap)
            if aimWrapped then
                return
            end
        end
        task.wait(0.5)
    end
    if running and sledgeMod and not aimWrapped then
        warn("[hush] sledge aim table never appeared, aura uses look-spoof only (needs silent hook)")
    end
end)

getgenv().HushSilent = {
    cfg = CFG,
    unload = unload,
    soundTest = play_hit,
    resources = Life.snapshot,
    perf = function()
        local result = {}
        for name, row in Loot.perf do
            result[name] = { calls = row.calls, averageMs = row.totalMs / row.calls, maxMs = row.maxMs }
        end
        return result
    end,
}

warn("[hush] Standalone keys in CFG.Keys; Syllinse UI uses its own unbound keybinds")

-- The runtime above starts once. The loader only mounts controls and owns teardown.
return function(_Lib, _Core)
    local M = getgenv().HushSilent
    M.stop = unload

    function M.buildUI(ctx)
        assert(running, "HUSH runtime is unloaded")
        if Life.uiActive then return end
        local T, toggles, captured = ctx.tabs, {}, nil
        local ready = false
        local firearmIds, equipmentIds = {}, { "sledgehammer" }
        for _, id in ipairs(assert(guns(), "HUSH Guns module unavailable").Order) do
            equipmentIds[#equipmentIds + 1] = id
            if is_firearm(id) then firearmIds[#firearmIds + 1] = id end
        end
        local function flag(k) return ctx.flag("HUSH_" .. k) end
        local function keep(el)
            if captured then captured[#captured + 1] = el end
            return el
        end
        local function note(s, text) return keep(s:SubLabel({ Text = text })) end
        local function head(s, text)
            keep(s:Divider())
            return keep(s:Header({ Name = text }))
        end
        local function card(tab, side, title, text)
            local s = T[tab]:Section({ Side = side })
            s:Header({ Name = title })
            if text then note(s, text) end
            return s
        end
        local function toggle(s, name, key, text, after)
            local el = keep(s:Toggle({
                Name = name, Default = CFG[key] == true,
                Callback = function(v)
                    if not running then return end
                    local changed = CFG[key] ~= v
                    CFG[key] = v
                    if after then after(v) end
                    if ready and changed and name == "Enabled" then
                        ctx.notify(key, v and "Enabled" or "Disabled")
                    end
                end,
            }, flag(key)))
            toggles[key] = el
            if text then note(s, text) end
            return el
        end
        local function slider(s, name, key, lo, hi, prec, suffix, text, scale, after)
            scale = scale or 1
            local el = keep(s:Slider({
                Name = name, Default = CFG[key] * scale,
                Minimum = lo, Maximum = hi, Precision = prec or 0, Suffix = suffix,
                Callback = function(v)
                    if not running then return end
                    CFG[key] = v / scale
                    if after then after(CFG[key]) end
                end,
            }, flag(key)))
            if text then note(s, text) end
            return el
        end
        -- Labels map to actual runtime values; numeric style IDs never appear to the user.
        local function choice(s, name, key, rows, text, after)
            local opts, values, def = {}, {}, nil
            for _, row in ipairs(rows) do
                local label, value = row, row
                if type(row) == "table" then label, value = row[1], row[2] end
                opts[#opts + 1], values[label] = label, value
                if CFG[key] == value then def = label end
            end
            local el = keep(s:Dropdown({
                Name = name, Options = opts, Default = def or opts[1], Required = true,
                Callback = function(v)
                    if not running or values[v] == nil then return end
                    CFG[key] = values[v]
                    if after then after(values[v]) end
                end,
            }, flag(key)))
            if text then note(s, text) end
            return el
        end
        local function color(s, name, key, holder, id)
            holder = holder or CFG
            return keep(s:Colorpicker({
                Name = name, Default = holder[key],
                Callback = function(v) if running then holder[key] = v end end,
            }, flag(id or key)))
        end
        local function advanced(s, key, build)
            local group = {}
            local switch = s:Toggle({
                Name = "Advanced", Default = false,
                Callback = function(v)
                    for _, el in ipairs(group) do el:SetVisibility(v) end
                end,
            }, flag("UI_Advanced_" .. key))
            switch.IgnoreConfig = true
            captured = group
            build()
            captured = nil
            for _, el in ipairs(group) do el:SetVisibility(false) end
        end
        local function bindAction(s, name, key, fn)
            local function onBind(v)
                if not running then return end
                CFG.Keys[key] = v or Enum.KeyCode.Unknown
                if key == "Speed" or key == "HighJump" then
                    local cas, keys = game:GetService("ContextActionService"), {}
                    cas:UnbindAction("HushMoveKeys")
                    for _, k in { CFG.Keys.Speed, CFG.Keys.HighJump } do
                        if k and k ~= Enum.KeyCode.Unknown then keys[#keys + 1] = k end
                    end
                    if #keys > 0 then
                        cas:BindActionAtPriority("HushMoveKeys", function()
                            return Enum.ContextActionResult.Sink
                        end, false, 3000, table.unpack(keys))
                    end
                end
            end
            local el = keep(ctx.keybind(s, {
                Name = name, Flag = flag("Key_" .. key),
                Toggle = function()
                    if running and not UserInputService:GetFocusedTextBox() then fn() end
                end,
                OnBinded = onBind,
            }))
            -- Config loads call Bind(), not onBinded. Keep the game's key sink in sync too.
            if key == "Speed" or key == "HighJump" then
                local oldBind, oldUnbind = el.Bind, el.Unbind
                function el:Bind(v) oldBind(self, v); onBind(v) end
                function el:Unbind() oldUnbind(self); onBind(nil) end
            end
            return el
        end
        local function keyToggle(s, key, option)
            bindAction(s, "Toggle key", key, function()
                toggles[option]:UpdateState(not CFG[option])
            end)
        end
        local function setList(s, name, id, target, names, inverted, after)
            local def = {}
            for _, k in ipairs(names) do
                if (target[k] == true) ~= (inverted == true) then def[#def + 1] = k end
            end
            return keep(s:Dropdown({
                Name = name, Options = names, Default = def, Multi = true,
                Callback = function(sel)
                    if not running then return end
                    local selected = {}
                    for k, v in pairs(sel) do
                        if v == true then selected[k] = true
                        elseif type(v) == "string" then selected[v] = true end
                    end
                    for _, k in ipairs(names) do
                        local on = (selected[k] == true) ~= (inverted == true)
                        target[k] = on or nil
                    end
                    if after then after() end
                end,
            }, flag(id)))
        end
        local function rarity(s, key)
            choice(s, "Min Rarity", key, {
                { "Common+", 1 }, { "Uncommon+", 2 }, { "Rare+", 3 },
                { "Epic+", 4 }, { "Legendary+", 5 }, { "Limited", 6 },
            })
        end

        local SIMPLE = {
            AutoBreath = { "Main", "Auto Breath", "Plays the breath checks at their normal pace." },
            AutoHotwire = { "Main", "Auto Hotwire", "Plays the hotwire / lockpick timing minigames." },
            NoRecoil = { "GunMods", "No Recoil", "Suppresses local recoil, jump sway and jump kick." },
            FullAuto = { "GunMods", "Full Auto", "Fire delay and bolt / break-action rules of the weapon still apply." },
            NoHeat = { "GunMods", "No Heat", "Stops the client heat buildup from sustained fire." },
            InstantEquip = { "GunMods", "Instant Equip", "Local draw animation only; ammo and reload stay server-owned." },
            ShootEverywhere = { "GunMods", "Shoot Everywhere", "Clears the local firing gates for the shot. Server acceptance is unverified." },
            NoFall = { "Movement", "No Fall", "Never reports a fall to the server." },
            InfStamina = { "Movement", "Infinite Stamina", "Keeps the local stamina full." },
            NoRagdoll = { "Movement", "No Ragdoll", "Local rig and knockback handling; does not cancel a server knockout." },
            AntiClimb = { "Movement", "Anti Climb", "Blocks new vaults, ledge grabs and wall moves. Takes priority over Fast Climb." },
            FullBright = { "Visuals", "Fullbright", "Local lighting only." },
        }
        local function simple(option, side)
            local row = SIMPLE[option]
            local s = card(row[1], side, row[2], row[3])
            toggle(s, "Enabled", option)
            keyToggle(s, option, option)
        end
        local function fxCard(pre, title, side)
            local s = card("Visuals", side, title, "Client-only materials and colors; originals are restored on disable / unload.")
            toggle(s, "Enabled", pre)
            keyToggle(s, pre, pre)
            choice(s, "Material", pre .. "Material", { "ForceField", "Neon", "SmoothPlastic", "Glass", "Metal" })
            slider(s, "Transparency", pre .. "Transparency", 0, 0.95, 2)
            color(s, "Color 1", pre .. "ColorA")
            color(s, "Color 2", pre .. "ColorB")
            slider(s, "Cycle Speed", pre .. "Speed", 0, 2, 2)
            slider(s, "Gradient Spacing", pre .. "Flow", 0, 0.5, 2, nil, nil, nil, function()
                for _, group in pairs(Visual.skin.groups) do
                    if group.prefix == pre and group.root then Visual.skinRelease(group) end
                end
                Visual.skin.findAt = 0
            end)
            if pre == "SelfFx" then
                toggle(s, "Hide Clothes", "SelfFxStripClothes")
                note(s, "Model Swap takes priority over Self Chams.")
            end
            advanced(s, pre, function()
                head(s, "Highlight")
                toggle(s, "Highlight", pre .. "Highlight")
                slider(s, "Fill Transparency", pre .. "HlFill", 0, 1, 2)
                slider(s, "Outline Transparency", pre .. "HlOutline", 0, 1, 2)
            end)
        end
        local function interactCard(side)
            local s = card("Main", side, "Instant Interact", "Zeroes the local hold time of prompts. How the server judges hold time is not readable from the dump.")
            toggle(s, "Enabled", "InstantInteract", "Loot (SearchPrompt) and pry (PryPrompt) prompts.", function(v) if not v then Visual.sitStop() end end)
            toggle(s, "Vehicle Doors / Seats", "InstantSit", "Door and seat prompts, plus the local climb-in / climb-out pose.", function(v) if not v then Visual.sitStop() end end)
        end

        -- Order inside a tab = priority: main function first, utilities after, test / debug last.
        do
            local s = card("SilentAim", "Left", "Silent Aim", "Redirects the shot without moving your camera. Firearm required.")
            toggle(s, "Enabled", "Silent")
            slider(s, "FOV", "FOV", 20, 600, 0, " px")
            slider(s, "Max Distance", "SilentAimDistance", 50, 3000, 0, " st")
            toggle(s, "Weapon Range Check", "RespectRange")
            bindAction(s, "Toggle key", "Silent", function() toggles.Silent:UpdateState(not CFG.Silent) end)
            head(s, "Target Filters")
            toggle(s, "Team Check", "TeamCheck")
            toggle(s, "Safe Zone Check", "SafeZoneCheck")
            toggle(s, "Target NPCs", "Monsters", "Also controls ordinary monster ESP.")
            toggle(s, "Target Bosses", "Bosses", "Also permits boss ESP / markers; marker style is in Visuals.")
            slider(s, "Player Priority Radius", "PriorityRadius", 0, 1000, 0, " st", "Nearby players take priority; NPCs come last.")
            advanced(s, "Targeting", function()
                slider(s, "Safe Zone Padding", "SafeMargin", 0, 8, 1, " st")
            end)
        end
        do
            local s = card("SilentAim", "Right", "Wall Check & MultiPoint")
            toggle(s, "Visible Check", "VisibleCheck")
            choice(s, "Wallbang", "Wallbang", { { "Game penetration", "Game" }, { "Clean line only", "Off" }, { "Ignore cover (unverified)", "Ignore" } }, "Game uses the held gun's penetration rules. Ignore is not a guaranteed wall hit.")
            toggle(s, "Visible Aim Points", "AimPoints")
            toggle(s, "MultiPoint", "MultiPoint", "Tries offset shot origins within the configured budget.")
            toggle(s, "MultiPoint Priority", "MPFirst")
            advanced(s, "MultiPoint", function()
                slider(s, "Origin Reach", "MPReach", 0, 3.5, 2, " st", "Increasing the origin offset can make the server replace it.")
                slider(s, "Origin Safety Margin", "MPSlackMargin", 0.3, 2, 2, " st")
                slider(s, "First Offset", "MPPreferFrac", 0.1, 1, 2)
                toggle(s, "Lag Compensation", "MPLagComp")
                slider(s, "Extra Lag", "MPLagExtra", 0, 0.2, 3, " s")
                slider(s, "Update Rate", "MPRate", 0.05, 0.5, 2, " s")
                setList(s, "No Wallbang Guns", "NoWallbangGuns", CFG.NoWallbangGuns, firearmIds)
            end)
        end
        do
            local s = card("SilentAim", "Left", "Resolver", "Position-based lead and the game's projectile ballistics.")
            toggle(s, "Enabled", "Resolver")
            toggle(s, "Ping Prediction", "PingPredict")
            toggle(s, "Downed Pose Fix", "DownedReplicaFix")
            toggle(s, "Slope Lead", "SlopeLead")
            toggle(s, "Air Body Aim", "AirBody")
            toggle(s, "Helmet Aim", "HelmetAim")
            advanced(s, "Resolver", function()
                slider(s, "Max Lead", "LeadCap", 0, 50, 1, " st")
                slider(s, "Max Acceleration", "ResolverAccel", 0, 150, 0, " st/s²")
                slider(s, "Acceleration Weight", "ResolverAccelK", 0, 1, 2)
                slider(s, "Interpolation", "PredictInterp", 0, 0.3, 3, " s")
                slider(s, "Slope Cap", "SlopeCap", 0, 8, 1, " st")
            end)
        end
        do
            local s = card("SilentAim", "Right", "Spread Aim", "Chooses a larger body region when the estimated server cone is wider than the head. Does not remove server spread.")
            toggle(s, "Enabled", "ServerSpread")
            advanced(s, "ServerSpread", function()
                slider(s, "Head Weight", "SSHead", 1, 3, 2)
                slider(s, "Limb Weight", "SSLimb", 0, 1, 2)
                slider(s, "Min Gain", "SSGain", 0, 0.5, 2)
                slider(s, "Lead Slop", "SSLeadSlop", 0, 0.2, 3, " s")
                slider(s, "Position Slop", "SSSlop", 0, 1.5, 2, " st")
                slider(s, "Min Cone Radius", "SSMin", 0, 2, 2, " st")
            end)
        end
        do
            local s = card("SilentAim", "Left", "Aim Visuals")
            toggle(s, "Target Overlay", "AimVisuals")
            choice(s, "Center Mark", "AimCenter", { { "Ring + dot", 1 }, { "Turning ticks", 2 }, { "Dashed ring", 3 } })
            toggle(s, "Cone Ring", "AimCone")
            toggle(s, "Muzzle Line", "MuzzleVisual")
            slider(s, "Muzzle Opacity", "MuzzleAlpha", 0, 1, 2)
        end
        do
            local s = card("Main", "Left", "Auto Heal", "Uses medical items in the backpack. Does not create items or shorten server effects.")
            toggle(s, "Enabled", "AutoHeal")
            slider(s, "Heal Below", "AutoHealThreshold", 5, 100, 0, "%")
            toggle(s, "Only In Combat", "AutoHealPvP")
            slider(s, "Heal Delay", "AutoHealDelay", 0.5, 10, 1, " s")
            keyToggle(s, "AutoHeal", "AutoHeal")
        end
        do
            local s = card("Main", "Right", "Auto Decrypt", "Opens nearby containers through their prompts; distance is still checked by the game.")
            toggle(s, "Enabled", "AutoDecrypt", nil, function(v) if not v then Loot.stopAuto() end end)
            slider(s, "Radius", "AutoDecryptRadius", 2, 15, 1, " st")
            toggle(s, "Reveal Slots", "AutoDecryptReveal", "Off: open, read the slot count, then close.")
            keyToggle(s, "AutoDecrypt", "AutoDecrypt")
            advanced(s, "AutoDecrypt", function()
                slider(s, "Max Parallel", "AutoDecryptMax", 1, 3, 0, nil, "The runtime reduces concurrency if earlier containers get closed.")
            end)
        end
        do
            local s = card("Main", "Left", "Auto Loot", "Takes items from an open container. Auto Decrypt opens them, or open one by hand. Hidden slots are taken once revealed.")
            toggle(s, "Enabled", "AutoLoot")
            rarity(s, "AutoLootMinRarity")
            setList(s, "Categories", "AutoLootCats", CFG.AutoLootCats,
                { "Firearms", "Melee", "Ammo", "Medical", "Armor", "Attachments", "Valuables", "Tools", "Materials", "Building", "Food", "Water", "Accessories", "Junk" })
            choice(s, "Always Take", "AutoLootAlways", { { "Off", 7 }, { "Epic+", 4 }, { "Legendary+", 5 }, { "Limited", 6 } },
                "Takes this rarity from any category, ignoring Categories and Min Rarity.")
            toggle(s, "Containers I Open", "AutoLootManual", "Also takes from a container you opened by hand.")
            keyToggle(s, "AutoLoot", "AutoLoot")
            advanced(s, "AutoLoot", function()
                slider(s, "Take Delay", "AutoLootDelay", 0.1, 1, 2, " s", "One take per delay. A slot the server leaves unchanged after two takes is skipped.")
            end)
        end
        do
            local s = card("Main", "Right", "Auto Armor", "Wears the best armor in your backpack by rarity tier. Empty slots are always filled.")
            toggle(s, "Enabled", "AutoArmor")
            toggle(s, "Body Armor", "AutoArmorBody")
            toggle(s, "Helmet", "AutoArmorHelmet")
            choice(s, "Mode", "AutoArmorMode", { { "Upgrade", "Upgrade" }, { "Fill Empty Only", "Empty" } })
            toggle(s, "Not In Combat", "AutoArmorSafe", "Upgrades wait for the end of the server combat flag.")
            keyToggle(s, "AutoArmor", "AutoArmor")
        end
        do
            local s = card("Main", "Left", "Kill Aura", "Uses the real sledge quick-swing path. It does not extend server melee reach.")
            toggle(s, "Enabled", "KillAura")
            choice(s, "Aim Part", "KaAim", { "Head", { "Root / torso", "HRP" } })
            toggle(s, "Face Target", "KaTurn")
            slider(s, "Face Range", "KaFaceRange", 5, 15, 1, " st")
            toggle(s, "Lead", "KaLead")
            toggle(s, "Wall Aim", "KaWall", "Server acceptance of covered swings is not confirmed.")
            keyToggle(s, "KillAura", "KillAura")
            advanced(s, "KillAura", function()
                slider(s, "Max Lead", "KaLeadMax", 0, 8, 1, " st")
                slider(s, "Interpolation", "KaInterp", 0, 0.3, 3, " s")
            end)
        end
        do
            local s = card("Main", "Right", "PvP Mode", "Hides world clutter and can pause Auto Decrypt while fighting.")
            toggle(s, "Enabled", "PvPMode")
            toggle(s, "Auto Enable", "PvPAuto")
            slider(s, "Auto Range", "PvPRange", 25, 600, 0, " st")
            slider(s, "Hold Time", "PvPHold", 0, 30, 1, " s")
            toggle(s, "Pause Auto Decrypt", "PvPPauseLoot")
            toggle(s, "Keep Corpses", "PvPKeepCorpses")
            slider(s, "Corpse Time", "PvPCorpseSeconds", 5, 180, 0, " s")
            keyToggle(s, "PvP", "PvPMode")
        end
        simple("AutoBreath", "Left")
        simple("AutoHotwire", "Right")
        interactCard("Left")
        simple("NoRecoil", "Left")
        simple("FullAuto", "Right")
        do
            local s = card("GunMods", "Left", "ADS Spoof")
            toggle(s, "Spoof ADS On Shot", "AimSpoof")
            toggle(s, "Hold ADS On Target", "AimSpoofHold")
            toggle(s, "Always ADS", "AlwaysAim")
            setList(s, "Always ADS Guns", "AlwaysAimGuns", CFG.AlwaysAimGuns, firearmIds)
            note(s, "Reports scoped state without forcing your local camera into ADS.")
        end
        do
            local s = card("GunMods", "Right", "Fast Bolt")
            toggle(s, "Enabled", "FastBolt")
            slider(s, "Bolt Time Scale", "FastBoltScale", 0.05, 1, 2, "x", "Smaller = faster local cycle. The server prime timer still wins.")
        end
        simple("NoHeat", "Left")
        simple("InstantEquip", "Right")
        simple("ShootEverywhere", "Left")
        do
            local s = card("GunMods", "Right", "Crouch Spoof")
            toggle(s, "Enabled", "CrouchSpoof")
            toggle(s, "While Moving", "CrouchSpoofMoving")
            toggle(s, "A/B Test", "CrouchAB", "Alternates the spoof in random on / off blocks and tags every shot in the log. Controls Enabled while it runs.", function(v)
                if v and not CFG.DebugFile then CFG.DebugFile = true; if Life.uiState then Life.uiState("DebugFile") end end
            end)
            advanced(s, "CrouchAB", function()
                slider(s, "Shots Per Block", "CrouchABBlock", 5, 60, 0, nil, "Analyse with tools/ab_crouch.py. Needs Shot Log File on (turned on automatically).")
            end)
            note(s, "No local crouch. Server cone benefit is unconfirmed; moving may change server speed allowances.")
        end
        do
            local s = card("Movement", "Left", "Speed", "Existing Safe / Pulse / Hop paths. Mode names are not a promise of server safety.")
            toggle(s, "Enabled", "Speed")
            choice(s, "Mode", "SpeedMode", { "Safe", "Pulse", "Hop" })
            keyToggle(s, "Speed", "Speed")
            advanced(s, "Speed", function()
                head(s, "Safe / Pulse")
                slider(s, "Speed Value", "SpeedValue", 12, 80, 1, " st/s")
                slider(s, "Pulse Length", "PulseLength", 0.05, 1, 2, " s")
                slider(s, "Pulse Delay", "PulseDelay", 0.05, 2, 2, " s")
                slider(s, "Safe Max Speed", "SpeedMax", 12, 60, 1, " st/s")
                slider(s, "Safe Ramp", "SpeedRamp", 1, 30, 1)
                toggle(s, "Fall Bonus", "SpeedFallBonus")
                toggle(s, "Fall Only", "SpeedFallOnly")
                head(s, "Bunny Hop")
                slider(s, "Max Horizontal", "HopHorizontalSpeed", 12, 40, 1, " st/s")
                slider(s, "Max Fall Speed", "HopFallSpeed", 12, 40, 1, " st/s")
                slider(s, "Max Extra", "HopExtra", 0, 40, 1, " st/s")
                slider(s, "Fall Ratio", "HopK", 0, 2, 2)
                slider(s, "Acceleration", "HopRamp", 10, 150, 0, " st/s²")
                toggle(s, "Fall Burst", "HopFallBurst")
                slider(s, "Burst Horizontal", "HopHorizontalBurstSpeed", 15, 45, 1, " st/s")
                slider(s, "Burst Fall Speed", "HopFallBurstSpeed", 15, 45, 1, " st/s")
                slider(s, "Burst Length", "HopFallBurstLength", 0.03, 0.3, 2, " s")
                slider(s, "Burst cooldown", "HopFallBurstEvery", 3, 30, 1, " s")
                head(s, "Slide Claim")
                toggle(s, "Claim Slide", "HopClaim")
                slider(s, "Claim Renew", "HopClaimRenew", 0.5, 3.8, 1, " s")
                slider(s, "Uplink Margin", "HopUplinkMargin", 0, 0.2, 3, " s")
                slider(s, "State Multiplier", "HopStateK", 1, 2, 2)
                note(s, "No movement algorithm or auto-jump setting is changed by mounting this UI.")
            end)
        end
        simple("NoFall", "Right")
        do
            local s = card("Movement", "Left", "Strafer")
            toggle(s, "Enabled", "Strafer")
            slider(s, "Min Speed", "StrafeSpeed", 6, 40, 1, " st/s")
            toggle(s, "Air Stop", "StrafeStop")
            keyToggle(s, "Strafer", "Strafer")
        end
        simple("InfStamina", "Right")
        do
            local s = card("Movement", "Left", "High Jump")
            toggle(s, "Enabled", "HighJump")
            slider(s, "Jump Power", "HighJumpPower", 30, 80, 1, " st/s", "Higher values can exceed the game's movement allowance.")
            keyToggle(s, "HighJump", "HighJump")
        end
        simple("NoRagdoll", "Right")
        do
            local s = card("Movement", "Left", "Fast Climb")
            toggle(s, "Enabled", "FastClimb")
            slider(s, "Climb Pace", "FastClimbPace", 0.1, 1, 2, "x", "Smaller = faster. Anti climb must be off.")
            toggle(s, "Auto Continue", "ClimbAuto")
            toggle(s, "Force Climb", "ClimbForce")
            keyToggle(s, "FastClimb", "FastClimb")
        end
        simple("AntiClimb", "Right")
        do
            local s = card("Movement", "Left", "Anti Drown")
            toggle(s, "Enabled", "AntiDrown")
            slider(s, "Water Offset", "WaterMargin", 0, 2, 2, " st", "Keeps the feet above the water and suppresses the local drown report.")
        end
        do
            local s = card("Visuals", "Left", "Player ESP")
            toggle(s, "Enabled", "ESP")
            keyToggle(s, "ESP", "ESP")
            slider(s, "Player Distance", "EspPlayerMaxDist", 100, 3000, 0, " st")
            slider(s, "NPC Distance", "EspNpcMaxDist", 50, 1500, 0, " st")
            toggle(s, "Show Allies", "EspAllies")
            toggle(s, "Rounded Boxes", "EspRound")
            toggle(s, "Armor", "EspArmor")
            choice(s, "Quality", "Quality", { { "Light", 0 }, { "Layered", 1 } })
            note(s, "Monster / boss inclusion shares the target filters in SilentAim.")
            advanced(s, "CharacterESP", function()
                head(s, "Colors")
                for _, row in ipairs({
                    { "Visible enemy", "Visible", COL_VIS }, { "Covered enemy", "Hidden", COL_HID },
                    { "NPC", "NPC", COL_NPC },
                }) do
                    keep(s:Colorpicker({ Name = row[1], Default = row[3], Callback = function(v)
                        if not running then return end
                        if row[2] == "Visible" then COL_VIS = v
                        elseif row[2] == "Hidden" then COL_HID = v else COL_NPC = v end
                    end }, flag("Color_" .. row[2])))
                end
                color(s, "Ally", "ally", PAL, "Color_Ally")
                color(s, "Protected", "safe", PAL, "Color_Safe")
                color(s, "Peek", "peek", PAL, "Color_Peek")
                color(s, "Low HP", "hpLow", PAL, "Color_HpLow")
                color(s, "Full HP", "hpHigh", PAL, "Color_HpHigh")
                setList(s, "Hidden Items", "EspHideIds", CFG.EspHideIds, equipmentIds)
                head(s, "Refresh Rates")
                slider(s, "Items Rate", "EspInfoRate", 0.1, 1, 2, " s")
                slider(s, "State Rate", "EspStateRate", 0.1, 1, 2, " s")
                slider(s, "Health Rate", "EspHealthRate", 0.05, 0.5, 2, " s")
                note(s, "These only affect ESP information, not resolver sampling or shot accuracy.")
            end)
        end
        do
            local s = card("Visuals", "Right", "Loot ESP", "Container contents stay unknown until the game reveals them.")
            toggle(s, "Enabled", "LootViz")
            slider(s, "Contents Distance", "LootRange", 10, 200, 0, " st")
            slider(s, "Box Distance", "EspObjectMaxDist", 50, 1500, 0, " st")
            slider(s, "Supply Distance", "EspSupplyMaxDist", 100, 4000, 0, " st")
            rarity(s, "LootMinRarity")
            toggle(s, "Show Unknown", "LootUnknown")
            toggle(s, "Hide Empty", "LootHideEmpty")
            bindAction(s, "Rare+ Filter Key", "LootFilter", function()
                local rare = CFG.LootMinRarity ~= 3
                local opt = ctx.MacLib.Options[flag("LootMinRarity")]
                opt:UpdateSelection(rare and "Rare+" or "Common+")
                toggles.LootUnknown:UpdateState(not rare)
                Loot.nextQuery = 0
            end)
            advanced(s, "LootClasses", function()
                head(s, "Categories")
                for _, row in ipairs({
                    { "AirDrop", "Flare airdrops" }, { "SupplyDrop", "Death loot bags" },
                    { "Corpse", "Corpses" }, { "Weapons", "Weapons" }, { "Ammo", "Ammo" },
                    { "Medical", "Medical" }, { "Valuables", "Valuables" }, { "Crates", "Crates" },
                    { "Tools", "Tools" }, { "Stores", "Stores" }, { "Vehicles", "Vehicles" },
                    { "Household", "Household" }, { "Other", "Other" },
                }) do
                    local data, id = CFG.LootClasses[row[1]], "LootClass_" .. row[1]
                    keep(s:Toggle({ Name = row[2], Default = data.on, Callback = function(v)
                        if running then data.on = v; Loot.nextQuery = 0 end
                    end }, flag(id)))
                    color(s, row[2] .. " color", "color", data, id .. "_Color")
                end
            end)
        end
        do
            local s = card("Visuals", "Left", "Weapon ESP Rarity", "Filters and colors for the weapon list under player boxes, not loot-container visibility.")
            for _, key in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Limited" }) do
                local data = CFG.WeaponRarity[key]
                s:Toggle({ Name = key, Default = data.on, Callback = function(v)
                    if running then data.on = v end
                end }, flag("WeaponRarity_" .. key))
                color(s, key .. " color", "color", data, "WeaponRarityColor_" .. key)
            end
        end
        do
            local s = card("Visuals", "Right", "Extract ESP")
            toggle(s, "Enabled", "ExtractMarkers")
            slider(s, "Distance", "ExtractMaxDist", 100, 6000, 0, " st")
            slider(s, "Opacity", "ExtractAlpha", 0.1, 1, 2)
        end
        do
            local s = card("Visuals", "Right", "World Items ESP", "Shown if the category is selected OR rarity meets the threshold OR the game marks it RareFind.")
            toggle(s, "Enabled", "FindMarkers")
            slider(s, "Distance", "FindMaxDist", 50, 4000, 0, " st")
            slider(s, "Opacity", "FindAlpha", 0.1, 1, 2)
            rarity(s, "FindMinRarity")
            setList(s, "Always Show", "FindFilter", CFG.FindFilter,
                { "Firearms", "Ammo", "Melee", "Medical", "Armor", "Attachments", "Tools", "Valuables",
                    "Materials", "Building", "Food", "Water", "Accessories", "Junk", "Unknown" }, false,
                function() Visual.finds.at = 0 end)
        end
        do
            local s = card("Visuals", "Right", "Boss ESP")
            toggle(s, "Skull Marker", "BossMarkers")
            note(s, "On: skull markers. Off: boss boxes remain if Target bosses is enabled in SilentAim.")
        end
        do
            local s = card("Visuals", "Right", "Death Marker")
            toggle(s, "Enabled", "DeathMarker")
            note(s, "Marks your last death position; hidden during PvP focus.")
        end
        do
            local s = card("Visuals", "Left", "Bullet Tracers")
            toggle(s, "Enabled", "BulletTracer")
            choice(s, "Style", "TracerStyle", { { "Lightning", 1 }, { "Helix", 2 }, { "Rail", 3 } })
            toggle(s, "Rail Trail", "TracerTrail", "Comet wake along the whole path; Rail style only.")
            slider(s, "Fade Time", "TracerFade", 0.1, 3, 2, " s")
            advanced(s, "Tracers", function()
                head(s, "Helix")
                slider(s, "Spin Speed", "HelixSpin", 0, 40, 1, " rad/s", "Twist runs toward the impact. 0 = frozen spiral.")
                slider(s, "Radius", "HelixRadius", 0.05, 0.8, 2, " st")
            end)
        end
        do
            local s = card("Visuals", "Left", "Hit Marker")
            toggle(s, "Enabled", "HitMarker")
            choice(s, "Style", "HitMarkerStyle", {
                { "Pull-in", 1 }, { "Pull-in + ring", 2 }, { "Wedges", 3 }, { "Crit + damage", 4 },
            })
        end
        do
            local s = card("Visuals", "Left", "Hit Sound")
            toggle(s, "Enabled", "HitSound")
            choice(s, "Sound", "HitSoundPreset", {
                "Fatality", "Minecraft XP", "Minecraft Hit", "Minecraft Egg", "Minecraft Bow",
                "Click", "Bell", "Neverlose", "Primordial", "Custom",
            })
            s:Input({ Name = "Custom Sound ID", Default = tostring(CFG.HitSoundId), AcceptedCharacters = "Numeric",
                Callback = function(v)
                    local id = tonumber(v)
                    if running and id and id > 0 and id % 1 == 0 then CFG.HitSoundId = id end
                end,
            }, flag("HitSoundId"))
            note(s, "Custom ID is used only with the Custom preset. The asset must be accessible to this game.")
            slider(s, "Volume", "HitSoundVolume", 0, 10, 1)
            slider(s, "Pitch", "HitSoundPitch", 0.5, 2, 2)
            s:Button({ Name = "Test Sound", Callback = function() if running then play_hit() end end })
        end
        do
            local s = card("Visuals", "Left", "Hit Effects")
            toggle(s, "Enabled", "HitParticles")
            slider(s, "Scale", "ParticleScale", 0.2, 3, 1)
            color(s, "Color 1", "ParticleColorA")
            color(s, "Color 2", "ParticleColorB")
            color(s, "Color 3", "ParticleColorC")
            bindAction(s, "Test Effect", "ParticleTest", Visual.pfxDemo)
            s:Button({ Name = "Test Effect", Callback = function() if running then Visual.pfxDemo() end end })
        end
        fxCard("WeaponFx", "Weapon Chams", "Left")
        fxCard("SelfFx", "Self Chams", "Right")
        do
            local s = card("Visuals", "Left", "Weapon Scale", "Only scales your third-person held model, not first person or server hitboxes.")
            toggle(s, "Enabled", "WeaponScale")
            slider(s, "Scale", "WeaponScaleFactor", 0.1, 8, 1, "x")
        end
        do
            local s = card("Visuals", "Right", "Model Swap", "Changes your local appearance only. The real character and hitboxes stay unchanged.")
            toggle(s, "Enabled", "ModelSwap")
            choice(s, "Model", "ModelSwapModel", Visual.SWAP_ORDER)
            slider(s, "Yaw Offset", "ModelSwapYaw", -180, 180, 0, "°")
            keyToggle(s, "ModelSwap", "ModelSwap")
            bindAction(s, "Next Model Key", "ModelSwapNext", function()
                local at = table.find(Visual.SWAP_ORDER, CFG.ModelSwapModel) or 1
                ctx.MacLib.Options[flag("ModelSwapModel")]:UpdateSelection(Visual.SWAP_ORDER[at % #Visual.SWAP_ORDER + 1])
            end)
        end
        simple("FullBright", "Right")
        do
            local s = card("Misc", "Right", "Staff Detector", "Uses replicated staff signals. It cannot guarantee an undetected server.")
            choice(s, "Mode", "StaffDetect", { "Off", "Alert", "Kick" })
            toggle(s, "Include Clippers", "StaffClippers")
            slider(s, "Group Rank (0 = Off)", "StaffGroupRank", 0, 255, 0)
            slider(s, "Kick Delay", "StaffKickDelay", 0, 5, 1, " s")
            s:Input({ Name = "Kick message", Default = CFG.StaffKickMsg, CharacterLimit = 160,
                Callback = function(v) if running then CFG.StaffKickMsg = v end end,
            }, flag("StaffKickMsg"))
        end
        do
            local s = card("Misc", "Left", "FX Gallery", "Toggles the existing world-space preview gallery; does not move it with the character.")
            s:Button({ Name = "Toggle Gallery", Callback = function() if running then drop_mock() end end })
            bindAction(s, "Gallery key", "Gallery", drop_mock)
        end
        do
            local s = card("Debug", "Right", "Shot Logs")
            toggle(s, "Shot Log File", "DebugFile")
            toggle(s, "Post-Shot Samples", "DebugAfter")
            toggle(s, "Console Log", "ShotLog")
            toggle(s, "Hop Log", "HopLog")
            note(s, "Files: executor workspace / hush / shots_<time>.jsonl. Existing logs are never deleted.")
            head(s, "Performance")
            toggle(s, "Perf Log", "PerfLog")
            local function report()
                if not running then return end
                warn("[hush] sections/resources: " .. game:GetService("HttpService"):JSONEncode({
                    sections = M.perf(), resources = Life.snapshot(),
                }))
                ctx.notify("HUSH", "Section timings and resource counts printed to the console.")
            end
            s:Button({ Name = "Print Perf", Callback = report })
            bindAction(s, "Performance key", "Perf", report)
        end
        do
            local s = card("Misc", "Right", "Script")
            note(s, "Unloading the Syllinse window also stops HUSH hooks, renderers and movement. Reload the file to start again.")
            s:Button({ Name = "Unload", DoubleClick = true, Callback = unload })
            bindAction(s, "Unload key", "Unload", unload)
        end
        Life.uiState = function(key)
            local el = toggles[key]
            if el and el:GetState() ~= CFG[key] then el:UpdateState(CFG[key]) end
        end
        ready = true
        Life.uiActive = true
        game:GetService("ContextActionService"):UnbindAction("HushMoveKeys")
        for key in pairs(CFG.Keys) do CFG.Keys[key] = Enum.KeyCode.Unknown end
    end
    return M
end
