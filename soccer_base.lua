-- Illegal Soccer: AutoTackle + AutoDribble + Pitch Line HUD
-- Drawing.new only. WorldToViewportPoint returns (Vector3, bool); depth is Vector3.Z.
-- Marks lie on the turf: cleat, stitch, eyelet, knot. No Y lift.

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local Workspace = cloneref(game:GetService("Workspace"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Client = ReplicatedStorage:WaitForChild("Client")

local ActionCommands = require(Modules.Actions.ActionCommands)
local ActionRemoteProtocol = require(Modules.Actions.ActionRemoteProtocol)
local ActionLocks = require(Modules.Actions.ActionLocks)
local ActionMotion = require(Modules.Actions.ActionMotion)
local Dodge = require(Modules.Actions.Dodge)
local SlideTackle = require(Modules.Actions.SlideTackle)
local ServerCooldownGrace = require(Modules.Actions.ServerCooldownGrace)
local AimFacing = require(Modules.Actions.AimFacing)
local HitboxSettings = require(Modules.Gameplay.HitboxSettings)
local CharacterControllers = require(Modules.Characters.CharacterControllers)
local CharacterMotion = require(Modules.Characters.CharacterMotion)
local LocalMovementGuard = require(Modules.Characters.LocalMovementGuard)
local Ragdoll = require(Modules.Characters.Ragdoll)
local Actors = require(Modules.Characters.Actors)
local ActorTargeting = require(Modules.Items.ActorTargeting)
local Remotes = require(Modules.Remotes)
local Controls = require(Modules.Gameplay.Controls)
local MatchSettings = require(Modules.Gameplay.MatchSettings)
local Renderer = require(Client.Gameplay.Ball.Renderer)
local ActorTeams = require(Client.Gameplay.ActorTeams)
local ClientDodge = require(Client.Gameplay.Actions.Dodge)
local ClientSlide = require(Client.Gameplay.Actions.SlideTackleInput)
local TurnControl = require(Client.Gameplay.Player.TurnControl)
local CommandTime = require(Modules.Gameplay.CommandTime)
local MovementStreamTap = require(Client.Player.MovementStreamTap)
local CharacterMotionSmoothing = require(Client.Player.CharacterMotionSmoothing)
local FieldMarkers = require(Modules.Gameplay.FieldMarkers)
local Physics = require(Modules.Ball.Physics)
local KickCore = require(Modules.Actions.KickCore)
local ShootMod = require(Modules.Actions.Shoot)
local BicycleKick = require(Modules.Actions.BicycleKick)
local CurvedKicks = require(Modules.CurvedKicks)
local ChargedKick = require(Client.Gameplay.Actions.Shoot)
local Reticle = require(Client.Interface.Reticle)
local BarricadeStrikes = require(Modules.Items.BarricadeStrikes)
local ChargePathVelocity = require(Modules.Actions.ChargePathVelocity)

local BallGroup = Remotes.GetGroup("Ball")
ActionRemoteProtocol.Init({
	ActionUpdateRemote = BallGroup.ActionUpdate,
	CallForPassRemote = BallGroup.CallForPass,
	KickRemote = BallGroup.Kick,
	RainbowFlickRemote = BallGroup.RainbowFlick,
	TackleRemote = BallGroup.Tackle,
})

local CFG = {
	AutoTackle = true,
	AutoDribble = true,
	AutoShoot = true,
	AutoKick = true, -- legit charged kick inside AutoBlock / CounterJump (Mark.akTry), released by the kick box
	FeintMode = "Off", -- Off / Chance (roll per charge) / Count (FeintCount feints, then one real charge, repeat)
	FeintChance = 0.6, -- Chance mode: share of charges that become a feint
	FeintCount = 1, -- Count mode: feints in a row before the real shot
	FeintAt = 0.32, -- the charge is cancelled when it has been held this long (s)
	FeintSkipFake = true, -- never feint a FAKE shot
	FeintSkipBounce = true, -- never feint a BOUNCE FAKE
	FeintSmart = true, -- Smart Select: no feint once the enemy keeper has dived (his dive is on cooldown): the shot goes as it is
	AutoFlick = true, -- the flick key starts the scripted flick -> jump -> volley; off = the game's own flick, aim help only
	FlickAutoJump = true, -- scripted jump into the ball after the flick
	FlickAutoKick = true, -- scripted Kick press (volley) once the ball is in reach
	FlickBan = {}, -- [band] = true: shot types never used while a flick / volley is being aimed
	DodgeTeleport = true, -- dodges may step the character (CFrame); off = movement only
	BounceFakeHeight = 2, -- BounceFAKE aim points are raised by this many studs (the keeper's jump reaches low ones)
	AutoKickFull = true, -- AutoKick always charges to the FULL charge (no early release); it misses instead of a weak kick
	BlockCompetitor = true, -- AutoBlock yields to a teammate already on the carrier (CompetitorRadius)
	BallCompetitor = true, -- AutoBall yields to a teammate clearly closer to the ball
	BallYieldGap = 6, -- ... closer by more than this many studs
	TackleCompetitor = false, -- AutoTackle yields to a teammate already on the carrier
	TackleCompetitorRadius = 8,
	CounterCompetitorRadius = 12,
	CounterCompetitor = false, -- CounterJump stands down when a teammate is already on the enemy (CompetitorRadius); off = jump regardless
	CounterKickChance = 0.45, -- share of counter combos that use Kick instead of the slide when both are possible
	CounterComboChance = 0.85, -- share of counter jumps that continue into a combo at all
	TackleReach = 16,
	AutoGK = true,
	AutoWall = true,
	TackleSpeed = 1.2,
	DribbleClose = 13,
	DribbleSlop = 3.6,
	DribbleReact = 22,
	TackleWindup = 0,
	TackleMinSpeed = 0.6,
	TrackStuds = 80,
	PreferCornerCurl = false,
	OnlyTrick = false,
	ShotBan = {}, -- [band] = true: this shot type is never picked (AutoShoot tab > Shot Types)
	ShotWeight = {}, -- [band] = factor on the built-in family weight (1 = default)
	TackleConfidence = 0.15, -- AutoTackle slides only when this share of the 0.3 s hitbox window still connects (0 = any window, as before)
	FakeFoeRadius = 7, -- an enemy this close to the mate would take the ball: the mate is dropped
	FakeLatMul = 1.5, -- prefilter: the straight line through the mate may miss the goal by post * this + FakeSlop (curves bend it back)
	FakeMaxDepth = 100, -- a mate farther than this from the goal is not used
	DrawPos = true, DrawTackle = true, DrawDanger = true, DrawGoal = true, DrawBall = true, DrawShot = true, DrawRoute = true,
	DrawHazards = true, DrawKickBox = true, DrawSilent = true, DrawSilentFov = true, DrawHud = false, ShotDebug = false,
	AgentAddon = true,
	AutoDodge = true,
	AutoBlock = true,
	AutoBall = true,
	BlockRange = 40,
	BlockBehind = 22,
	TackleGoalZone = 40,
	CompetitorRadius = 12,
	CounterJump = true,
	ShootMaxDist = 160,
	Perf = true,
	-- draw (Drawing) update rate cap, used only when the display runs >= ~100 fps; 0 = every frame
	PaintHz = 60,
	-- agent spot look: "corners" (4 squircle corner arcs, like the SilentAim target), "ripple" (squircle drop rings),
	-- "kick" (round drop rings, the kick-charge look)
	AgentSpotStyle = "corners",
	-- agent route look: "flow" (gradient + pulses, matches the corner spot) or "classic" (old chalk route)
	AgentPathStyle = "flow",
	-- new looks, ON by default: shot "aurora", positions "phantom", tackle sight "reticle"; any other value
	-- ("classic") = the old drawing
	ShotStyle = "aurora",
	PosStyle = "phantom",
	SightStyle = "reticle",
	CounterJumpRange = 10,
	PassAssistSync = true, -- AutoDodge x Pass Assist: a legit Lob to the safest teammate instead of the blind ball dump (homing rocket punch, or a projectile we are not sure to dodge)
	ProjHitRadius = 5, -- homing punch -> ball contact distance (not in the client dump; 3 judged real hits as misses)
	ProjSafeMargin = 1.0, -- dodge clearance above the item radius that counts as a sure dodge
	GkBaitInset = 0.6, -- AutoGK: a ball path this far inside an enemy's receive box counts as received (FAKE bait)
	GkBaitRay = 2.5, -- ...and an enemy this close to a charging shooter's aim ray before the goal cancels the charge-position read
	MineMargin = 2.5, -- studs added to half a landmine model's footprint for its (server-side) trigger
	BlastMargin = 1.5, -- extra studs outside ItemHitSettings.ExplosionRadius (14) that we keep from an explosion
	GkInterceptEnemy = 14, -- free (non-shot) ball: no run to the intercept point when an enemy is this close to it
	GkReturn = true, -- after a push (ViolenceDash / shotgun): walk or dive back to the remembered standing spot
	GkReturnDive = 13, -- dive back only when the spot is at least this far
	GkJumpDive = true, -- a shot no ground dive touches: jump first, dive from the air
	GkLostPath = true, -- no reachable point on the path: walk to where the PATH is soonest within dive range, not to the goal-line crossing
	GkLostDiveFrac = 0.75,
	GkPressJump = true, -- no ground dive reaches him (flier / lob): jump first, dive from the air
	GkPressDesperate = 0.8, -- he is in within this many seconds and nothing connects: the closest dive anyway
	GkPress = true, -- AutoGK: forward dive into a carrier who runs / flies into the goal (stuns him)
	PressDist = nil, -- max dive travel to contact (default: dive distance - 2)
	PressReach = 2.6, -- horizontal body-to-body contact radius of the dive (server value unknown: calibrate from `gk press result`)
	PressVert = 4, -- vertical contact window
	PressGoalDist = 30, -- a ground carrier this close to the mouth, closing in, is a press target
	ChargeTackleRange = 10, -- slide at a kick-charging carrier / his shot line only within this many studs of him
	KillerGuard = true, -- ball near OUR goal and we are close to it: slide the enemy nearest to the ball first, keep chasing
	KillerGuardGoal = 55, -- ball this close to our goal (studs)
	KillerGuardNear = 22, -- we are this close to the ball
	KillerGuardFoe = 40, -- the enemy must be this close to the ball
	CandidateKiller = true, -- AutoBall x AutoTackle: slide an enemy who runs for the same loose ball (stun him, and the slide is faster than a run)
	KillerRadius = 22, -- the enemy must be this close to the ball (studs)
	KillerReach = 28, -- ...and this close to us
	KillerMargin = 0.5, -- he counts as a threat when he reaches the ball within this many seconds of us (or is within 8 studs of it)
	KillerAngle = 50, -- the killer slide may leave our route direction by at most this many degrees (searched from 0 outward)
	WallLatency = 0.08, -- press -> wall exists on the server, on top of ping (NOT in the client dump: calibrate from "wall placed dt" in the log)
	WallMin = 3.2, -- predicted distance window the wall can land on a target (it spawns 5 studs ahead: PlacementForwardDistance)
	WallMax = 6.8,
	WallAmbush = true, -- also place it early on an enemy running into the wall's spot
	WallEquip = false, -- Auto Use: AutoWall takes the barricades out itself (item slot press) when a threat is coming; off = only when already in hand
	WallLead = "away", -- where the wall is aimed: "never" = at his current spot, "away" = led only when he runs away from us, "always" = always led
	WallEquipDelay = 0.3, -- extra time the equip needs before the wall can be placed
	WallEquipDist = 26,
	WallEquipHold = 3.5, -- put the unused barricades away after this long
	WallReach = 18, -- ambush: an enemy this far away that closes on the wall's spot gets it placed early
	WallAmbushV = 4.5, -- closing speed from which an ambush wall is considered (was 6)
	WallAmbushT = 0.6, -- ... and he reaches the spot within this many seconds (was 1.0: the wall stood there long before he came and he turned)
	WallShot = true, -- wall on the replicated shot path of a charging carrier (needs barricades in hand)
	TackleGateStrict = false, -- true = the old gate (tackle waits for AutoBlock for every carrier farther than TackleGoalZone)
	CounterKickDelay = 0.08, -- air combo: the Kick goes out this long after the jump when the slide has no legal pair
	BlockCloser = 1.0, -- AutoBlock shadow gap = kick reach - 1 - this (was 4.0 studs, now 3.0)
	BlockGapMin = 2.2,
	ArcMaxErr = 2.5, -- FreezeGun: accepted height error of the scanned landing point (studs)
	JumpSlide = true, -- a lofting carrier: jump first, slide from the air
	JumpSlideDelay = 0.16,
	PressMaxT = 0.4, -- keeper forward dive waits until the contact is this close
	AutoKickRange = 5.5, -- AutoBlock presses the kick when the carrier is within kick reach + this (was +2.5)
	AutoKickCooldown = 0.5,
	AutoKickFlee = 9, -- no kick when the gap would open faster than this (he runs away, we are slowed to ~8 by the charge)
	AutoKickPadPerSpeed = 0.1, -- extra solid-hit margin (studs) per stud/s of opening speed
	AutoKickEager = true, -- press when he is inside the box at the earliest release, solid or not
	AutoKickRelease = 0.4, -- earliest release charge (while he is in the box); >= the full charge (0.35) = always wait for full unless he would leave the box
	SlideLag = 0.03, -- extra seconds the ball is taken ahead when a slide is planned (on top of ping/2)
	SlideMinHits = 3, -- of 11 samples of the live window the box must hold the ball (was 2)
	BlockPreJump = true, -- jump for a high shot BEFORE the release, timed to the replicated charge path
	BlockSlide = true, -- AutoBlock: slide the flying shot when the body cannot reach it (ground slide, or jump + air slide)
	BlockSlideJump = true,
	BarricadeAddon = true, -- projectiles: a wall on their path instead of dodge / pass when the timing allows
	WallMargin = 0.12, -- the path must reach the wall circle this much later than press + ping + WallLatency
	WallHeight = 6, -- wall height estimate for the projectile-height test
	WallHalf = 4, -- half width of the wall for the ambush test until a placed one is measured
	WallCooldown = 0.7,
	RouteSlideGain = 0.4, -- AutoBall route: a slide replaces the run when it touches the ball this much earlier (or the run loses the race)
	BallRamp = 0.2, -- AutoBall: seconds to go from the current speed to full sprint (unmeasured: see "ball track" v= in the log)
	CounterTackle = true, -- CounterJump x AutoTackle: slide the enemy at the ball when it fits (flick wind-up), jump + air slide when he leaves the ground
	GkAutoClear = false,
	PassAssist = true, -- Pass / Lob press while looking at a teammate -> our own lob (yaw + charge solved), see Mark.paSolve
	PassManual = true, -- ManualButton: a UI keybind passes to the best teammate without aiming (Mark.paManual); unbound by default
	PassManualNear = 16, -- a teammate closer than this is only chosen when nobody farther is passable
	PassShow = true, -- lime trajectory + brackets on the selected teammate
	PassFov = 9, -- new lock: crosshair within this many degrees of his chest
	PassGoalLead = 34, -- the predicted receive point never gets closer than this to the enemy goal (the keeper takes it there)
	PassKeeperRadius = 14, -- keeper this close to the landing point -> contested
	PassGoalSep = 9, -- a teammate within this many degrees of the goal (and near it) is a shooting target, not a pass target
	PassGoalZone = 36, -- ... near = this close to the enemy goal (studs)
	PassMinDist = 7,
	PassMaxDist = 130,
	PassToKeeper = false,
	PriorityFAKE = true, -- FAKE is tried FIRST (before BounceFAKE and the normal pool)
	FakeFirstChance = 0.95, -- ...and taken without its own roll in this share of solves; the rest fall back to FakeChance, so it is not every time
	BounceFAKE = true, -- FAKE family member: a flight that looks like a shot on goal, hits a wall and comes back to us (<= 60 studs)
	PriorityBounceFAKE = false, -- BounceFAKE goes first and is used whenever it exists (then PriorityFAKE)
	FakeAfterDiveBan = true, -- no FAKE family while the enemy keeper's dive is on cooldown (a fake only works as a bait for the dive)
	FakeOnceThenShoot = true, -- after a SUCCESSFUL BounceFAKE (the ball came back to us) no fakes until we lose the ball: shoot
	BounceFakeChance = 0.35,
	BounceFakeRange = 110, -- BounceFAKE up to this distance from the goal (was 60)
	BounceFakeSteps = 56,
	BounceFakeMaxSim = 8, -- walled candidates simulated per solve (the solve is sliced: every sim delays the preview) -- flight samples of 0.06 s searched for the return (was 52)
	BounceFakeRun = 14, -- studs we may run for the returning ball (was 10)
	BounceFakeSlack = 3.5, -- accepted remaining gap at the return (was 2.5)
	IntentTackleRadius = 60, -- deliberate slides AT enemies (CandidateKiller) only when the enemy is within this of the ball
	SlideTravelCal = true, -- slide travel model corrected by the measured dash (phase 2 ~0.8-0.86 of the dump formula) -- rolled every solve even when a normal shot exists
	ChargeTackleGuard = true, -- AutoTackle on a charging carrier only if the slide lands before the release, else try a slide-block on the shot line
	ChargeRelease = 0.34, -- assumed seconds from charge start to release (KickCore window 0.2..0.4)
	ChargeBallSpeed = 95, -- assumed shot speed for the slide-block geometry
	ChargeSlideBlock = true,
	FakeShot = true, -- AutoShoot FAKE: a shot that flies through a teammate in front of their goal (he receives it, the keeper has already dived)
	FakeChance = 0.12, -- share of shots that become a FAKE when one is possible (x2.2 for a friend / party / club mate, cap 0.35)
	FakeSlop = 6, -- studs of slack: depth window, mouth-line prefilter, receive-box miss
	FakeCorner = true, -- name the shot FAKE CORNER when the flight really lands in the corner (it is no longer a target, only a landing)
	FakeCurve = true, -- FAKE may bend the flight (none / +-0.45 / +-0.85), each curve is another arc through the same mate
	PrioritizeFriends = true, -- FAKE picks party mates first, then club mates, then Roblox friends
	ManualRadius = 26, -- ManualTackle: enemy carrier closer than this -> the player's own Tackle press is aimed at him
	ManualTackle = true, -- redirect the player's own Tackle press onto the solved hit (works with AutoTackle off)
	HammerRadius = 9, -- estimate: slam radius is server-side; 'skill hammer slam ... dist' logs calibrate it
	OilRadius = 4, -- fallback when the Puddle template gives no part size (server zone not in the client dump)
	ShootSliceMs = 0.9,
	SilentAim = true,
	SilentFov = 140, -- px radius around the gun reticle
	AerialJumpLead = 0.3, -- jump when arrival <= this: the whole ~0.27 s rise sits inside the 0.4 s volley window
	GkWalkSlack = 0.12, -- humanoid accel/turn before full WalkSpeed (not from dump)
	GkReactSeconds = 0.15, -- keeper reaction after release; he sees GoalCrossingPreview (not from dump)
	ShotReachMargin = 0.05,
	Draw = true,
}

local COL = {
	-- neon-blue theme (the old lime / off-white pair read as dull): bright cyan main line, ice-white paper, steel
	-- chalk, amber kept for tackle, violet lobs, mint dodge, deep blue-black ink
	Line = Color3.fromRGB(86, 214, 255),
	Tackle = Color3.fromRGB(255, 172, 56),
	Chalk = Color3.fromRGB(176, 140, 255),
	Paper = Color3.fromRGB(255, 244, 236),
	Ink = Color3.fromRGB(8, 8, 20),
	Lob = Color3.fromRGB(255, 112, 206),
	Flat = Color3.fromRGB(255, 104, 96),
	Dodge = Color3.fromRGB(96, 255, 190),
}

local FONT = Drawing.Fonts.Plex
local C = SlideTackle.Constants
SlideTackle.SetSpeedMultiplier(CFG.TackleSpeed)
local dodgeEnforced = ServerCooldownGrace.GetEnforcedSeconds(Dodge.Constants.RepeatDelaySeconds)
local tackleEnforced = ServerCooldownGrace.GetEnforcedSeconds(C.CooldownSeconds)
local lastDodgeAt = -1e9
local lastTackleAt = -1e9
local dribbleSeen = setmetatable({}, { __mode = "k" })
local lastDbgT = ""
local lastDbgD = ""
local lastTally = 0
local predict = nil
local ghostPos = nil
local ghostDir = nil
local dribbleDanger = nil
local dribbleWhy = "off"
local tackleWhy = "off"
local Log = {
	N = 480,
	ring = table.create(480),
	n = 0,
	head = 1,
	file = "illegalsoccerlog.txt",
	pending = {},
}

local function ringPush(line)
	if Log.n < Log.N then
		Log.n += 1
		Log.ring[Log.n] = line
		return
	end
	Log.ring[Log.head] = line
	Log.head = Log.head % Log.N + 1
end

local function fmtV(v)
	if typeof(v) ~= "Vector3" then
		return "-"
	end
	return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z)
end

local function dbg(...)
	local n = select("#", ...)
	local bits = table.create(n)
	for i = 1, n do
		bits[i] = tostring(select(i, ...))
	end
	local line = string.format("%.3f s=%.3f %s", os.clock(), Workspace:GetServerTimeNow(), table.concat(bits, " "))
	ringPush(line)
	return line
end

local function persist(line)
	if isfile(Log.file) then
		appendfile(Log.file, line .. "\n")
	else
		writefile(Log.file, line .. "\n")
	end
end

local function logFile(...)
	persist(dbg(...))
end

-- Potassium catalog (debug.md): debug.getupvalue(fn, i) -> any (value only)
local function upvalue(fn, i)
	local a, b = debug.getupvalue(fn, i)
	if b ~= nil then
		return b
	end
	return a
end

-- Every Drawing property write crosses into the engine, and the old code rewrote the same Visible / Color / Thickness /
-- ZIndex on hundreds of lines EVERY frame (hideLines over ~40 pools, then redraw). The proxy keeps the last written
-- value per property and forwards only real changes: an already hidden line costs one table compare, a static-style
-- line only pays for From / To. Reads of never-written properties (TextBounds ...) fall through to the real object.
local drawMeta = {}
drawMeta.__index = function(t, k)
	local v = t._c[k]
	if v ~= nil then
		return v
	end
	if k == "Remove" or k == "Destroy" then
		return function(self)
			self._r:Remove()
		end
	end
	return t._r[k]
end
drawMeta.__newindex = function(t, k, v)
	local c = t._c
	if c[k] ~= v then
		c[k] = v
		t._r[k] = v
	end
end
local function newDraw(kind, z)
	local o = setmetatable({ _r = Drawing.new(kind), _c = {} }, drawMeta)
	o.Visible = false
	o.ZIndex = z or 20
	return o
end

local function makeLines(n, thickness, z)
	local t = {}
	for i = 1, n do
		local ln = newDraw("Line", z)
		ln.Thickness = thickness
		t[i] = ln
	end
	return t
end

local ourPath = makeLines(22, 1.4, 24)
local enemyPath = makeLines(22, 1.2, 23)
local lagLine = newDraw("Line", 26)
lagLine.Thickness = 2
local function newTri(z)
	local t = newDraw("Triangle", z)
	t.Filled = true
	t.Thickness = 1
	return t
end
local liveTri = newTri(28)
local liveOutline = newTri(27)
local ghostTri = newTri(28)
local ghostOutline = newTri(27)
local hitTri = newTri(29)
local hitOutline = newTri(28)
local dangerTri = newTri(30)
local slidePip = newTri(31)
local enLiveTri = newTri(28)
local enSrvTri = newTri(29)
local enLag = newDraw("Line", 26)
enLag.Thickness = 2

local goalQuads = {}
for i = 1, 3 do
	local q = newDraw("Quad", 21)
	q.Filled = true
	q.Thickness = 1
	goalQuads[i] = q
end
local goalCorners = {}
for i = 1, 4 do
	goalCorners[i] = newTri(22)
end
local fovLines = makeLines(8, 1.6, 25)
local resLines = makeLines(8, 1.8, 25)
local slidePath = makeLines(24, 1.4, 26)

local ballDot = newDraw("Circle", 22)
ballDot.Filled = true
ballDot.NumSides = 16
ballDot.Radius = 4

local chips = {}
for i = 1, 3 do
	local bg = newDraw("Square", 40)
	bg.Filled = true
	bg.Thickness = 1
	local tx = newDraw("Text", 41)
	tx.Center = false
	tx.Outline = true
	tx.OutlineColor = COL.Ink
	tx.Size = 14
	tx.Font = FONT
	chips[i] = { bg = bg, tx = tx }
end
local shotDbg = newDraw("Text", 62)
shotDbg.Center = true
shotDbg.Outline = true
shotDbg.OutlineColor = COL.Ink
shotDbg.Size = 15
shotDbg.Font = FONT
shotDbg.Color = COL.Paper
shotDbg.Visible = false

-- One table, not a pile of chunk locals. Executor register cap is 200.
local Mark = {
	GhostSpeed = 0.55,
	CatchSpeed = 3.1,
	LagSpeed = 1.35,
	SlideSpeed = 2.6,
	QuietSpeed = 0.7,
	Thread = 1.6,
	ChalkW = 1.2,
	KnotW = 2.4,
	MinPeriod = 0.72,
	move = { mode = nil, dir = nil },
}
Mark.playLive = function()
	local s = Mark.matchSnap
	if type(s) == "table" then
		if s.IsIntermission == true or s.IsComplete == true or s.IsActive ~= true or s.LocalTeamName == nil then
			return false
		end
		if (s.MatchClockPausedAt or 0) ~= 0 then
			return false
		end
		return true
	end
	local ok, live = pcall(function()
		return require(Client.Gameplay.KickoffFreeze).IsPlayLive()
	end)
	return ok and live == true
end
pcall(function()
	local remote = Remotes.Get("Match", "State")
	remote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.Kind ~= "StatDelta" then
			Mark.matchSnap = payload
		end
	end)
	remote:FireServer("RequestState")
end)
Mark.boardText = {}
for i = 1, 4 do
	local tx = newDraw("Text", 45)
	tx.Size = 16
	tx.Font = FONT
	tx.Outline = true
	tx.OutlineColor = COL.Ink
	tx.Color = COL.Paper
	tx.Center = true
	Mark.boardText[i] = tx
end
Mark.mockTri = {}
for i = 1, 8 do
	Mark.mockTri[i] = newTri(46)
end
-- Enemy slide travel at dump 1.0. GetTravel() uses SetSpeedMultiplier(TackleSpeed=1.2) because TuningScope.Applies(nil) is true.
Mark.dumpTravel = function(t)
	t = math.max(t or 0, 0)
	local hand = C.HitboxDelaySeconds
	local a = ActionMotion.GetQuadOutTravel(C.StartupDashDistance, 0.5, math.min(t, hand))
	if t > hand then
		-- MEASURED (`slide audit`, 12 slides, mult 0.72..1.2, ratios identical): the first phase matches the model to 0.2 studs,
		-- the second delivers only ~79% of it at +0.15 s and ~86% at +0.30 s (e.g. mult 1.2: 16.5 got vs 18.0 at 0.42 s,
		-- 22.2 vs 23.9 at 0.57 s). A box planned on the raw model sits 1.5-2 studs behind where it was supposed to be:
		-- "the ball has already rolled past". Factor = lerp over the second phase, toward 0.95 near the end.
		local e = t - hand
		local k = e <= 0.15 and 0.79 or (e <= 0.30 and (0.79 + (e - 0.15) / 0.15 * 0.07) or math.min(0.86 + (e - 0.30) * 0.13, 0.95))
		a += ActionMotion.GetQuadOutTravel(C.Distance, C.MotionSeconds, e) * (CFG.SlideTravelCal == false and 1 or k)
	end
	return a
end
-- CharacterControllers: JumpHeight 7.2, vy = sqrt(2 * workspace.Gravity * H). Ball gravity -100 is not this.
Mark.jumpH = 7.2
Mark.fallT = function(y0, vy, yLand)
	local g = Workspace.Gravity
	if type(g) ~= "number" or g < 10 then
		g = 196.2
	end
	vy = vy or 0
	local h = (y0 or 0) - (yLand or 0)
	if h <= 0.35 and vy <= 2 then
		return 0
	end
	local disc = vy * vy + 2 * g * math.max(h, 0)
	if disc < 0 then
		return 0
	end
	local t = (vy + math.sqrt(disc)) / g
	if t < 0 then
		return 0
	end
	return math.min(t, 1.8)
end
Mark.usQuad = newDraw("Quad", 28)
Mark.usQuad.Filled = true
Mark.usQuad.Thickness = 1
Mark.usEdge = makeLines(4, 1.6, 29)
Mark.usStuds = makeLines(3, 1.2, 30)
Mark.ghostEdge = makeLines(4, 1.2, 27)
Mark.stitchUs = makeLines(16, 1.4, 26)
Mark.stitchEn = makeLines(16, 1.4, 26)
Mark.chalkSmear = makeLines(3, 1.2, 25)
Mark.enHex = makeLines(6, 1.6, 29)
Mark.knotCross = makeLines(2, 2.4, 31)
Mark.knotHex = makeLines(6, 1.6, 32)
Mark.spur = newDraw("Line", 30)
Mark.spur.Thickness = 1.6
Mark.goalStitch = makeLines(8, 1.4, 21)
Mark.ballHex = makeLines(6, 1.6, 23)
Mark.ballTicks = makeLines(2, 1.2, 24)
Mark.flight = makeLines(36, 1.6, 34)
Mark.flightTip = newTri(38)
Mark.flightTail = newTri(38)
Mark.shadow = makeLines(18, 1.1, 22)
Mark.ticks = makeLines(14, 1.3, 35)
Mark.route = makeLines(12, 1.6, 33)
Mark.pathInk = makeLines(12, 2.2, 32)
Mark.stake = makeLines(4, 1.8, 36)
Mark.needle = newTri(37)
Mark.flag = newTri(37)
Mark.flightDot = newDraw("Circle", 36)
Mark.flightDot.Filled = true
Mark.flightDot.NumSides = 16
Mark.flightDot.Radius = 5
Mark.flightTime = newDraw("Text", 37)
Mark.flightTime.Center = true
Mark.flightTime.Outline = true
Mark.flightTime.OutlineColor = COL.Ink
Mark.flightTime.Size = 14
Mark.flightTime.Font = FONT
Mark.box = makeLines(12, 1.8, 35)
Mark.hudRule = newDraw("Line", 42)
Mark.hudRule.Thickness = 1.6
Mark.sight = {}
Mark.routeSight = {}
for i = 1, 4 do
	local t = newDraw("Triangle", 33)
	t.Filled = true
	t.Thickness = 1.4
	Mark.sight[i] = t
	local rt = newDraw("Triangle", 32)
	rt.Filled = true
	rt.Thickness = 1.2
	Mark.routeSight[i] = rt
end
Mark.rib = { our = {}, enemy = {}, slide = {}, us = {}, en = {} }
local ribN = { our = 10, enemy = 10, slide = 10, us = 6, en = 6 }
local ribZ = { our = 24, enemy = 23, slide = 26, us = 26, en = 26 }
for name, n in pairs(ribN) do
	local bucket = Mark.rib[name]
	for i = 1, n do
		local q = newDraw("Quad", ribZ[name])
		q.Filled = true
		q.Thickness = 1
		bucket[i] = q
	end
end
Mark.gate = { us = {}, ghost = {}, enLive = {}, enSrv = {}, ball = {} }
local gateZ = { us = 30, ghost = 27, enLive = 28, enSrv = 31, ball = 23 }
for name, z in pairs(gateZ) do
	local bucket = Mark.gate[name]
	for i = 1, 4 do
		local t = newDraw("Triangle", z)
		t.Filled = true
		t.Thickness = 1
		bucket[i] = t
	end
end

local function hideLines(list)
	for i = 1, #list do
		list[i].Visible = false
	end
end

local function hideWorld()
	if Mark.artHide then
		Mark.artHide()
	end
	hideLines(ourPath)
	hideLines(enemyPath)
	hideLines(fovLines)
	hideLines(resLines)
	hideLines(slidePath)
	lagLine.Visible = false
	liveTri.Visible = false
	liveOutline.Visible = false
	ghostTri.Visible = false
	ghostOutline.Visible = false
	hitTri.Visible = false
	hitOutline.Visible = false
	dangerTri.Visible = false
	slidePip.Visible = false
	enLiveTri.Visible = false
	enSrvTri.Visible = false
	enLag.Visible = false
	ballDot.Visible = false
	for i = 1, #goalQuads do
		goalQuads[i].Visible = false
	end
	for i = 1, #goalCorners do
		goalCorners[i].Visible = false
	end
	hideLines(Mark.usEdge)
	hideLines(Mark.usStuds)
	hideLines(Mark.ghostEdge)
	hideLines(Mark.stitchUs)
	hideLines(Mark.stitchEn)
	hideLines(Mark.chalkSmear)
	hideLines(Mark.enHex)
	hideLines(Mark.knotCross)
	hideLines(Mark.knotHex)
	hideLines(Mark.goalStitch)
	hideLines(Mark.ballHex)
	hideLines(Mark.ballTicks)
	hideLines(Mark.flight)
	Mark.flightTip.Visible = false
	Mark.flightTail.Visible = false
	hideLines(Mark.shadow)
	hideLines(Mark.ticks)
	hideLines(Mark.route)
	hideLines(Mark.pathInk)
	hideLines(Mark.stake)
	Mark.needle.Visible = false
	Mark.flag.Visible = false
	Mark.flightDot.Visible = false
	Mark.flightTime.Visible = false
	hideLines(Mark.box)
	Mark.usQuad.Visible = false
	Mark.spur.Visible = false
	Mark.hudRule.Visible = false
	for i = 1, #Mark.sight do
		Mark.sight[i].Visible = false
	end
	if Mark.routeSight then
		for i = 1, #Mark.routeSight do
			Mark.routeSight[i].Visible = false
		end
	end
	for _, bucket in pairs(Mark.rib) do
		for i = 1, #bucket do
			bucket[i].Visible = false
		end
	end
	for _, tris in pairs(Mark.gate) do
		for i = 1, #tris do
			tris[i].Visible = false
		end
	end
	if Mark.aimLip then
		hideLines(Mark.aimLip)
	end
	if Mark.aimGlow then
		hideLines(Mark.aimGlow)
	end
	if Mark.lockRing then
		hideLines(Mark.lockRing)
	end
end

local function worldTo(p)
	local v, on = Camera:WorldToViewportPoint(p)
	return Vector2.new(v.X, v.Y), on == true, v.Z
end

local function applyLine(ln, a, b, col, alpha)
	if not (a and b) then
		ln.Visible = false
		return
	end
	local sa, oa, za = worldTo(a)
	local sb, ob, zb = worldTo(b)
	if oa and ob and za > 0 and zb > 0 then
		ln.From = sa
		ln.To = sb
		ln.Color = col
		ln.Transparency = alpha
		ln.Visible = true
	else
		ln.Visible = false
	end
end

local function travelAlpha(i, n)
	local u = (os.clock() * 2.15 + (i - 1) / math.max(n, 1)) % 1
	if u < 0.2 then
		return 0.95 - u * 2.2
	end
	return 0.32
end

local function applyPath(list, pts, gy, col, alpha, dashed)
	if not (pts and #pts >= 2) then
		hideLines(list)
		return
	end
	for i = 1, #list do
		local a = pts[i]
		local b = pts[i + 1]
		if a and b and (not dashed or i % 2 == 1) then
			local al = alpha
			if al == true then
				al = travelAlpha(i, #list)
			end
			applyLine(list[i], Vector3.new(a.X, gy, a.Z), Vector3.new(b.X, gy, b.Z), col, al or 0.9)
		else
			list[i].Visible = false
		end
	end
end

local function applyQuad(q, a, b, c, d, col, alpha)
	if not (a and b and c and d) then
		q.Visible = false
		return
	end
	local sa, oa, za = worldTo(a)
	local sb, ob, zb = worldTo(b)
	local sc, oc, zc = worldTo(c)
	local sd, od, zd = worldTo(d)
	if oa and ob and oc and od and za > 0 and zb > 0 and zc > 0 and zd > 0 then
		q.PointA = sa
		q.PointB = sb
		q.PointC = sc
		q.PointD = sd
		q.Color = col
		q.Transparency = alpha
		q.Visible = true
	else
		q.Visible = false
	end
end

local function ground(p, y)
	return Vector3.new(p.X, y, p.Z)
end

local function xzRight(dir)
	return Vector3.new(-dir.Z, 0, dir.X)
end

Mark.hex = function(lines, p, y, radius, col, thick)
	for i = 1, #lines do
		local a0 = (i - 1) / #lines * math.pi * 2
		local a1 = i / #lines * math.pi * 2
		local p0 = Vector3.new(p.X + math.cos(a0) * radius, y, p.Z + math.sin(a0) * radius)
		local p1 = Vector3.new(p.X + math.cos(a1) * radius, y, p.Z + math.sin(a1) * radius)
		lines[i].Thickness = thick
		applyLine(lines[i], p0, p1, col, 1)
	end
end

Mark.pointAlong = function(pts, cum, total, dist)
	dist = math.clamp(dist, 0, total)
	for i = 1, #pts - 1 do
		local a = cum[i]
		local b = cum[i + 1]
		if dist <= b or i == #pts - 1 then
			local span = b - a
			if span < 1e-4 then
				return pts[i]
			end
			return pts[i]:Lerp(pts[i + 1], (dist - a) / span)
		end
	end
	return pts[#pts]
end


Mark.stroke = function(quads, pts, gy, col, wide)
	if not quads then
		return
	end
	if not (pts and #pts >= 2) then
		for i = 1, #quads do
			quads[i].Visible = false
		end
		return
	end
	local cum = table.create(#pts)
	cum[1] = 0
	local total = 0
	for i = 1, #pts - 1 do
		local d = pts[i + 1] - pts[i]
		total += math.sqrt(d.X * d.X + d.Z * d.Z)
		cum[i + 1] = total
	end
	if total < 0.18 then
		for i = 1, #quads do
			quads[i].Visible = false
		end
		return
	end
	local n = #quads
	local function at(dist)
		return Mark.pointAlong(pts, cum, total, dist)
	end
	local function dirAt(dist)
		local a = at(dist)
		local b = at(math.min(total, dist + 0.3))
		local dx, dz = b.X - a.X, b.Z - a.Z
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 1e-4 then
			return Vector3.new(1, 0, 0)
		end
		return Vector3.new(dx / len, 0, dz / len)
	end
	wide = math.clamp(wide or 0.12, 0.08, 0.14)
	for i = 1, n do
		local u0 = (i - 1) / n
		local u1 = i / n
		local p0 = at(u0 * total)
		local p1 = at(u1 * total)
		local d0 = dirAt(u0 * total)
		local d1 = dirAt(u1 * total)
		local r0 = Vector3.new(-d0.Z, 0, d0.X)
		local r1 = Vector3.new(-d1.Z, 0, d1.X)
		local w0 = wide * (1 - u0) ^ 1.35
		local w1 = wide * (1 - u1) ^ 1.35
		if i == n then
			w1 = 0.006
		end
		if w0 < 0.006 then
			w0 = 0.006
		end
		applyQuad(quads[i], ground(p0 - r0 * w0, gy), ground(p0 + r0 * w0, gy), ground(p1 + r1 * w1, gy), ground(p1 - r1 * w1, gy), col, 1)
	end
end


Mark.smear = function(lines, p, dir, gy, col)
	local lens = { 0.36, 0.7, 0.26 }
	local back = { 0.12, 0.52, 0.9 }
	local side = { -0.07, 0.05, -0.02 }
	local right = xzRight(dir)
	for i = 1, #lines do
		local c = p - dir * back[i] + right * side[i]
		lines[i].Thickness = Mark.ChalkW
		applyLine(lines[i], ground(c, gy), ground(c + dir * lens[i], gy), col, 1)
	end
end

Mark.hideKnot = function()
	hideLines(Mark.knotCross)
	hideLines(Mark.knotHex)
end

Mark.hideSight = function()
	for i = 1, #Mark.sight do
		Mark.sight[i].Visible = false
	end
	hideLines(Mark.stitchUs)
	if Mark.aimGlow then
		hideLines(Mark.aimGlow)
	end
end

Mark.fillTri = function(tri, a, b, c, col)
	local sa, oa, za = worldTo(a)
	local sb, ob, zb = worldTo(b)
	local sc, oc, zc = worldTo(c)
	if oa and ob and oc and za > 0 and zb > 0 and zc > 0 then
		tri.PointA = sa
		tri.PointB = sb
		tri.PointC = sc
		tri.Color = col
		tri.Transparency = 1
		tri.Visible = true
	else
		tri.Visible = false
	end
end

Mark.stepReel = function()
	local now = os.clock()
	if Mark.reelAt and now - Mark.reelAt < 0.008 then
		return Mark.reel
	end
	local dt = math.clamp(now - (Mark.reelAt or now), 0, 0.05)
	Mark.reelAt = now
	local r = Mark.reel
	if not r then
		r = {
			fastAng = 0,
			fastGoal = 0,
			fastWait = 0.04,
			fastDir = 1,
			fastN = 0,
			fastVel = 0,
			drumAng = 0,
			drumVel = 0.6,
			drumDir = 1,
			drumMode = "flick",
			drumT = 0,
			drumN = 0,
			drumPeak = 24,
			roll = 0,
			rollV = 0,
			fastRoll = 0,
			fastRollV = 0,
		}
		Mark.reel = r
	end
	local function kick(amount)
		r.rollV = r.rollV + amount
	end
	local function kickFast(amount)
		r.fastRollV = r.fastRollV + amount
	end
	r.rollV = r.rollV + (-20 * r.roll - 4.6 * r.rollV) * dt
	r.roll = r.roll + r.rollV * dt
	r.fastRollV = r.fastRollV + (-16 * r.fastRoll - 3.8 * r.fastRollV) * dt
	r.fastRoll = r.fastRoll + r.fastRollV * dt
	local err = r.fastGoal - r.fastAng
	if math.abs(err) < 0.06 and math.abs(r.fastVel) < 0.45 then
		r.fastWait = r.fastWait - dt
		r.fastVel = r.fastVel * math.exp(-9 * dt)
		if r.fastWait <= 0 then
			r.fastN = r.fastN + 1
			local n = r.fastN
			if n % 4 == 0 or n % 7 == 5 then
				r.fastDir = -r.fastDir
			end
			local turn = math.pi * 0.5
			local k = n % 6
			if k == 2 then
				turn = math.pi
			elseif k == 5 then
				turn = math.pi * 0.25
			end
			r.fastGoal = r.fastAng + r.fastDir * turn
			r.fastWait = 0.06 + (n * 17) % 5 * 0.04
			kickFast(r.fastDir * 3.4)
		end
	else
		r.fastVel = r.fastVel + (err * 42 - r.fastVel * 8.5) * dt
		r.fastAng = r.fastAng + r.fastVel * dt
	end
	r.drumT = r.drumT + dt
	if r.drumMode == "flick" then
		local a = math.clamp(r.drumT / 0.2, 0, 1)
		local target = r.drumDir * r.drumPeak * (a * a)
		r.drumVel = r.drumVel + (target - r.drumVel) * math.min(1, dt * 16)
		r.drumAng = r.drumAng + r.drumVel * dt
		if r.drumT > 0.22 then
			r.drumMode = "coast"
			r.drumT = 0
			kick(r.drumDir * 6)
		end
	elseif r.drumMode == "coast" then
		r.drumVel = r.drumVel * math.exp(-8 * dt)
		r.drumAng = r.drumAng + r.drumVel * dt
		if math.abs(r.drumVel) < 1.5 or r.drumT > 0.28 then
			local step = math.pi * 0.5
			local snapped = math.floor(r.drumAng / step + 0.5) * step
			r.drumAng = r.drumAng + (snapped - r.drumAng) * math.min(1, dt * 16)
			r.drumMode = "heel"
			r.drumT = 0
			r.drumN = r.drumN + 1
			kick(-r.drumDir * 2.8)
		end
	else
		r.drumVel = r.drumVel * math.exp(-12 * dt)
		r.drumAng = r.drumAng + r.drumVel * dt
		if r.drumT > 0.08 then
			r.drumMode = "flick"
			r.drumT = 0
			if r.drumN % 3 ~= 0 then
				r.drumDir = -r.drumDir
			end
			r.drumPeak = 20 + (r.drumN % 4) * 5
			kick(r.drumDir * 4.5)
		end
	end
	return r
end

Mark.chamberAt = function(p, gy, hot, withStitch, style)
	local reel = Mark.stepReel()
	local origin = Vector3.new(p.X + reel.fastRoll * 0.22, gy, p.Z)
	local ang0 = style == "glow" and reel.drumAng or reel.fastAng
	local scale = hot and 1 or 0.9
	local pool = nil
	if style == "glow" or style == "route" then
		local key = style == "glow" and "aimGlow" or "aimLip"
		pool = Mark[key]
		if not pool then
			pool = {}
			for i = 1, 36 do
				local ln = newDraw("Line", 42)
				ln.Visible = false
				pool[i] = ln
			end
			Mark[key] = pool
		end
		for i = 1, #pool do
			pool[i].Visible = false
		end
	end
	local n = 1
	local function strokeEdge(a, b)
		if not pool or not pool[n] then
			return
		end
		if style == "glow" then
			pool[n].Thickness = 8
			applyLine(pool[n], a, b, COL.Tackle, 0.2)
			n = n + 1
			if not pool[n] then
				return
			end
			pool[n].Thickness = 3.6
			applyLine(pool[n], a, b, COL.Tackle, 0.45)
			n = n + 1
			if not pool[n] then
				return
			end
			pool[n].Thickness = 1.3
			applyLine(pool[n], a, b, COL.Paper, 1)
			n = n + 1
		else
			pool[n].Thickness = 3.2
			applyLine(pool[n], a, b, COL.Ink, 1)
			n = n + 1
			if not pool[n] then
				return
			end
			pool[n].Thickness = 1.45
			applyLine(pool[n], a, b, Mark.routeInk or COL.Line, 1)
			n = n + 1
		end
	end
	local tris = style == "route" and Mark.routeSight or Mark.sight
	for i = 1, 4 do
		local ang = ang0 + (i - 1) * math.pi * 0.5
		local warp = 1 + reel.fastRoll * math.cos(ang) * 0.05
		local outward = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local right = Vector3.new(-outward.Z, 0, outward.X)
		local apexDist = 0.5 * scale * warp
		local len = 1.52 * scale
		local halfW = 0.21 * scale
		local apex = origin + outward * apexDist
		local base = apex + outward * len
		tris[i].Filled = true
		Mark.fillTri(tris[i], apex, base + right * halfW, base - right * halfW, COL.Paper)
		if style then
			strokeEdge(apex, base + right * halfW)
			strokeEdge(base + right * halfW, base - right * halfW)
			strokeEdge(base - right * halfW, apex)
		end
		if withStitch and style ~= "route" then
			local o = 1.12
			local apexO = origin + outward * (apexDist * 0.9)
			local baseO = apexO + outward * len * o
			local halfO = halfW * o
			local a = baseO + right * halfO
			local b = baseO - right * halfO
			local li = (i - 1) * 3
			Mark.stitchUs[li + 1].Thickness = 1.7
			Mark.stitchUs[li + 2].Thickness = 1.7
			Mark.stitchUs[li + 3].Thickness = 1.7
			applyLine(Mark.stitchUs[li + 1], apexO, a, COL.Line, 1)
			applyLine(Mark.stitchUs[li + 2], a, b, COL.Line, 1)
			applyLine(Mark.stitchUs[li + 3], b, apexO, COL.Line, 1)
		end
	end
end

Mark.sightAt = function(p, gy, col, hot, aim)
	if CFG.SightStyle == "reticle" and Mark.sightArt then
		Mark.sightArt(Mark.pen, p, gy, hot, aim, os.clock())
		return
	end
	Mark.chamberAt(p, gy, hot, true, nil)
end

-- The tackle solve drops predict.hit for a frame and the mark blinked off. Keep the last hit ~0.35 s.
Mark.sightKeep = function(gy)
	local hold = Mark.sightHold
	if hold and os.clock() - hold.at < 0.35 then
		Mark.sightAt(hold.p, gy, COL.Paper, true, hold.aim)
		Mark.sightP = hold.p
	else
		Mark.hideSight()
	end
end

Mark.hideGate = function(tris)
	if not tris then
		return
	end
	for i = 1, #tris do
		tris[i].Visible = false
	end
end

Mark.bodyFill = function(p, dir, gy, col, scale)
	local right = xzRight(dir)
	local c = Vector3.new(p.X, gy, p.Z)
	local front = 0.7 * scale
	local back = 0.38 * scale
	local wide = 0.2 * scale
	local narrow = 0.12 * scale
	applyQuad(Mark.usQuad, c + dir * front + right * wide, c + dir * front - right * wide, c - dir * back - right * narrow, c - dir * back + right * narrow, col, 1)
end

Mark.bodyLine = function(p, dir, gy, col, scale)
	local right = xzRight(dir)
	local c = Vector3.new(p.X, gy, p.Z)
	local front = 0.78 * scale
	local back = 0.42 * scale
	local wide = 0.24 * scale
	local narrow = 0.14 * scale
	local loop = {
		c + dir * front + right * wide,
		c + dir * front - right * wide,
		c - dir * back - right * narrow,
		c - dir * back + right * narrow,
	}
	for i = 1, 4 do
		Mark.ghostEdge[i].Thickness = 1.5
		applyLine(Mark.ghostEdge[i], loop[i], loop[i % 4 + 1], col, 1)
	end
end

Mark.diamond = function(tris, p, gy, col, r)
	local c = Vector3.new(p.X, gy, p.Z)
	local n = c + Vector3.new(0, 0, r)
	local e = c + Vector3.new(r * 0.7, 0, 0)
	local s = c + Vector3.new(0, 0, -r)
	local w = c + Vector3.new(-r * 0.7, 0, 0)
	tris[1].Filled = true
	tris[2].Filled = true
	tris[1].Thickness = 1
	tris[2].Thickness = 1
	Mark.fillTri(tris[1], n, e, s, col)
	Mark.fillTri(tris[2], n, w, s, col)
	tris[3].Visible = false
	tris[4].Visible = false
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

Mark.approach = function(quads, head, from, to, gy, col)
	for i = 1, #quads do
		quads[i].Visible = false
	end
	if head then
		head.Visible = false
	end
	if not (from and to) then
		return
	end
	local delta = flat(to - from)
	local dist = delta.Magnitude
	if dist < 0.4 then
		return
	end
	local dir = delta.Unit
	local cap = 6.5
	local vis = math.min(dist, cap)
	local a = Vector3.new(from.X, gy, from.Z)
	local tip = a + dir * vis
	local right = xzRight(dir)
	local tailW = 0.22 * (0.45 + 0.55 * vis / cap)
	local noseW = 0.08
	applyQuad(quads[1], a + right * tailW, a - right * tailW, tip - right * noseW, tip + right * noseW, col, 1)
	local u = (os.clock() * 0.8) % 1
	u = u * u * (3 - 2 * u)
	local notch = a:Lerp(tip, 0.12 + 0.72 * u)
	local nw = 0.1 + 0.06 * (1 - u)
	applyQuad(quads[2], notch - dir * 0.28 + right * nw, notch - dir * 0.28 - right * nw, notch + dir * 0.12 - right * nw * 0.35, notch + dir * 0.12 + right * nw * 0.35, COL.Paper, 1)
	if head then
		local back = tip - dir * 0.7
		head.Filled = true
		Mark.fillTri(head, tip + dir * 0.28, back + right * 0.36, back - right * 0.36, col)
	end
end


Mark.frontSeg = function(a, b)
	local _, _, za = worldTo(a)
	local _, _, zb = worldTo(b)
	if za and za > 0.2 and zb and zb > 0.2 then
		return a, b
	end
	if zb and zb > 0.2 then
		return a:Lerp(b, 0.62), b
	end
	if za and za > 0.2 then
		return a, a:Lerp(b, 0.38)
	end
	return a, b
end

Mark.drawFlight = function(pts, col)
	hideLines(Mark.flight)
	Mark.flightTip.Visible = false
	Mark.flightTail.Visible = false
	if not pts or #pts < 2 then
		return
	end
	local vis = pts
	if #vis < 2 then
		vis = pts
	end
	local function point(tri, tail, nose, half)
		local dir = nose - tail
		if dir.Magnitude < 0.08 then
			tri.Visible = false
			return
		end
		dir = dir.Unit
		local right = Vector3.new(-dir.Z, 0, dir.X)
		if right.Magnitude < 0.05 then
			right = Vector3.new(1, 0, 0)
		else
			right = right.Unit
		end
		local base = nose - dir * 0.85
		Mark.fillTri(tri, nose, base + right * half, base - right * half, col)
	end
	local last = #vis
	point(Mark.flightTail, vis[2], vis[1], 0.1)
	point(Mark.flightTip, vis[last - 1], vis[last], 0.16)
	local segs = #Mark.flight
	for i = 1, segs do
		local a = math.floor(1 + (i - 1) * (last - 1) / segs)
		local b = math.floor(1 + i * (last - 1) / segs)
		if b <= a then
			b = math.min(last, a + 1)
		end
		if b > last then
			b = last
		end
		if b > a then
			local pa, pb = Mark.frontSeg(vis[a], vis[b])
			local u = i / segs
			local taper = math.min(u, 1 - u) * 2
			taper = 0.15 + 0.85 * taper
			Mark.flight[i].Thickness = 0.8 + 1.6 * taper
			applyLine(Mark.flight[i], pa, pb, col, 0.55 + 0.45 * taper)
		end
	end
end

Mark.drawShadow = function(pts, gy, col)
	hideLines(Mark.shadow)
	if not pts or #pts < 2 then
		return
	end
	local n = #Mark.shadow
	local last = #pts
	for i = 1, n do
		local a = math.floor(1 + (i - 1) * (last - 1) / n)
		local b = math.floor(1 + i * (last - 1) / n)
		if b <= a then
			b = math.min(last, a + 1)
		end
		if b > a then
			local pa = Vector3.new(pts[a].X, gy + 0.08, pts[a].Z)
			local pb = Vector3.new(pts[b].X, gy + 0.08, pts[b].Z)
			Mark.shadow[i].Thickness = 1.1
			applyLine(Mark.shadow[i], pa, pb, col, 0.28)
		end
	end
end

Mark.drawScar = function(hit, face, along, gy, col)
	hideLines(Mark.box)
	if typeof(hit) ~= "Vector3" then
		return
	end
	local n = (face and face.Magnitude > 0.5) and face.Unit or Vector3.new(0, 0, 1)
	local side = (along and along.Magnitude > 0.5) and along.Unit or Vector3.new(1, 0, 0)
	local pulse = 1
	local w = 0.62
	local tip = hit - n * (0.28 + 0.22 * pulse)
	Mark.box[1].Thickness = 1.8
	Mark.box[2].Thickness = 1.4
	Mark.box[3].Thickness = 1.4
	applyLine(Mark.box[1], hit - side * w, hit + side * w, col, 1)
	applyLine(Mark.box[2], hit - side * w * 0.72, tip, col, 0.9)
	applyLine(Mark.box[3], hit + side * w * 0.72, tip, col, 0.9)
	local foot = Vector3.new(hit.X, gy + 0.08, hit.Z)
	Mark.box[4].Thickness = 1.1
	applyLine(Mark.box[4], hit, foot, COL.Chalk, 0.4)
	local cross = 0.28 + 0.12 * pulse
	Mark.box[5].Thickness = 1.3
	Mark.box[6].Thickness = 1.3
	applyLine(Mark.box[5], foot - side * cross, foot + side * cross, COL.Paper, 0.85)
	applyLine(Mark.box[6], foot - n * cross, foot + n * cross, COL.Paper, 0.85)
end

Mark.ballSeam = function(p, col)
	Mark.hex(Mark.ballHex, p, p.Y, 0.4, col, 1.6)
end

local function unitOrNil(v)
	local m = v.Magnitude
	if m < 0.08 then
		return nil
	end
	return v / m
end

local flickOwner = nil
local flickUntil = 0

local function ownerIdOk(id)
	return type(id) == "number" and id ~= 0
end

local function liveOwnerId()
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	if root and Renderer.GetNearestPracticeBallId then
		local id = Renderer.GetNearestPracticeBallId(root.Position)
		if id then
			local rend = Renderer.GetOrCreateRenderer(id)
			local owner = rend and rend.GetOwnedUserId and rend.GetOwnedUserId()
			if ownerIdOk(owner) then
				local pos = rend.GetPosition and rend.GetPosition()
				local near = typeof(pos) == "Vector3" and flat(pos - root.Position).Magnitude < 48
				if near or owner == LocalPlayer.UserId then
					if owner == LocalPlayer.UserId then
						if Renderer.SetMatchBallId and Renderer.GetMatchBallId and Renderer.GetMatchBallId() ~= id then
							Renderer.SetMatchBallId(id)
						end
					end
					return owner
				end
			end
		end
	end
	local bound = Renderer.GetOwnedUserId()
	if ownerIdOk(bound) then
		return bound
	end
	local a = Renderer.GetMainMatchOwnerUserId()
	if ownerIdOk(a) then
		return a
	end
	if flickOwner and os.clock() < flickUntil then
		return flickOwner
	end
	return nil
end

local function playerOf(userId)
	if type(userId) ~= "number" then
		return nil
	end
	return Actors.GetByUserId(userId)
end

local function actorName(actor)
	if not actor then
		return "-"
	end
	if typeof(actor) == "Instance" and actor:IsA("Player") then
		return actor.Name
	end
	return actor.DisplayName or actor.Name or tostring(Actors.GetUserId(actor))
end

local function isGoalkeeperRaw(actor)
	local character = Actors.GetCharacter(actor)
	return character ~= nil and MatchSettings.IsGoalkeeperCharacter(character)
end
-- role / team lookups ran per actor per caller per frame (tickBall alone walks the roster 3 times; sameTeam also
-- resolved OUR team every call). Both change on respawn / team swap only: 0.3 s cache per actor.
local roleCache = setmetatable({}, { __mode = "k" })
local function isGoalkeeper(actor)
	local now = os.clock()
	local c = roleCache[actor]
	if c and now - c[1] < 0.3 then
		return c[2]
	end
	local v = isGoalkeeperRaw(actor)
	if c then
		c[1], c[2] = now, v
	else
		roleCache[actor] = { now, v }
	end
	return v
end

local teamKey
local sameCache = setmetatable({}, { __mode = "k" })
local sameTeamRaw
local function sameTeam(actor)
	if actor == LocalPlayer then
		return true
	end
	local now = os.clock()
	local c = sameCache[actor]
	if c and now - c[1] < 0.3 then
		return c[2]
	end
	local v = sameTeamRaw(actor)
	if c then
		c[1], c[2] = now, v
	else
		sameCache[actor] = { now, v }
	end
	return v
end
sameTeamRaw = function(actor)
	local a = teamKey(ActorTeams.GetActorTeamName(LocalPlayer))
	local b = teamKey(ActorTeams.GetActorTeamName(actor))
	if not a or not b then
		return true
	end
	return a == b
end

teamKey = function(name)
	if name == "Team1" or name == "Team2" then
		return name
	end
	local display = MatchSettings.Constants.TeamDisplayNames
	if display then
		for k, v in display do
			if v == name then
				return k
			end
		end
	end
	return name
end

local function enemyGoalPart()
	local ours = teamKey(ActorTeams.GetActorTeamName(LocalPlayer))
	local map = Workspace:FindFirstChild("Map")
	local data = map and map:FindFirstChild("Data")
	if ours == "Team1" or ours == "Team2" then
		local opp = MatchSettings.GetOpposingTeamName(ours)
		local folder = data and data:FindFirstChild(opp)
		local g = folder and folder:FindFirstChild("Goal")
		if g and g:IsA("BasePart") then
			return g
		end
	end
	local lobby = Workspace:FindFirstChild("Lobby")
	local practice = lobby and lobby:FindFirstChild("Practice")
	local goals = practice and practice:FindFirstChild("Goals")
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	local pos = root and root.Position
	if goals and pos then
		local best, bestD = nil, 1e9
		for _, child in goals:GetChildren() do
			local g = child:IsA("Model") and child:FindFirstChild("Goal")
			if g and g:IsA("BasePart") then
				local d = (g.Position - pos).Magnitude
				if d < bestD then
					best, bestD = g, d
				end
			end
		end
		if best then
			return best
		end
	end
	if not data then
		return nil
	end
	local best, bestD = nil, -1
	for _, folder in data:GetChildren() do
		if folder.Name ~= ours then
			local g = folder:FindFirstChild("Goal")
			if g and g:IsA("BasePart") then
				local d = pos and (g.Position - pos).Magnitude or 0
				if d > bestD then
					best, bestD = g, d
				end
			end
		end
	end
	return best
end

local function ourGoalPart()
	local ours = teamKey(ActorTeams.GetActorTeamName(LocalPlayer))
	local map = Workspace:FindFirstChild("Map")
	local data = map and map:FindFirstChild("Data")
	if data and (ours == "Team1" or ours == "Team2") then
		local folder = data:FindFirstChild(ours)
		local g = folder and folder:FindFirstChild("Goal")
		if g and g:IsA("BasePart") then
			return g
		end
	end
	local function green(part)
		local c = part.Color
		return c.G > 0.45 and c.G > c.R + 0.08 and c.G > c.B
	end
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	local pos = root and root.Position
	local best, bestD = nil, 1e9
	local function consider(g)
		if g and g:IsA("BasePart") and green(g) and pos then
			local d = (g.Position - pos).Magnitude
			if d < bestD then
				best, bestD = g, d
			end
		end
	end
	if data then
		for _, folder in data:GetChildren() do
			consider(folder:FindFirstChild("Goal"))
		end
	end
	local lobby = Workspace:FindFirstChild("Lobby")
	local practice = lobby and lobby:FindFirstChild("Practice")
	local goals = practice and practice:FindFirstChild("Goals")
	if goals then
		for _, child in goals:GetChildren() do
			consider(child:FindFirstChild("Goal"))
		end
	end
	return best
end


local function goalMouthCorners(part)
	local cf = part.CFrame
	local s = part.Size
	local hx, hy, hz = s.X * 0.5, s.Y * 0.5, s.Z * 0.5
	local mid = FieldMarkers.GetCenterPosition()
	if part:FindFirstAncestor("Practice") then
		local root = ActorTargeting.GetActorRoot(LocalPlayer)
		mid = root and root.Position or mid
	end
	local toField = mid and flat(mid - part.Position) or flat(cf.LookVector)
	if toField.Magnitude < 1 then
		toField = flat(cf.LookVector)
	else
		toField = toField.Unit
	end
	local depthZ = hz <= hx
	local faces = depthZ and {
		{ n = cf.LookVector, u = cf.UpVector, v = cf.RightVector, e = hz, w = hx },
		{ n = -cf.LookVector, u = cf.UpVector, v = cf.RightVector, e = hz, w = hx },
	} or {
		{ n = cf.RightVector, u = cf.UpVector, v = cf.LookVector, e = hx, w = hz },
		{ n = -cf.RightVector, u = cf.UpVector, v = cf.LookVector, e = hx, w = hz },
	}
	local best, bestDot = faces[1], -1e9
	for i = 1, #faces do
		local d = faces[i].n:Dot(toField)
		if d > bestDot then
			bestDot = d
			best = faces[i]
		end
	end
	local origin = part.Position + best.n * best.e
	local u, v = best.u, best.v
	local lt = origin + u * hy - v * best.w
	local rt = origin + u * hy + v * best.w
	local lb = origin - u * hy - v * best.w
	local rb = origin - u * hy + v * best.w
	local along = unitOrNil(flat(rt - lt)) or v
	return lb, lt, rb, rt, along, best.n
end

local function enemyCarrier(oid)
	if type(oid) ~= "number" then
		return nil, "no owner"
	end
	if oid == LocalPlayer.UserId then
		return nil, "have ball"
	end
	local actor = playerOf(oid)
	if not actor then
		return nil, "no actor"
	end
	if sameTeam(actor) then
		return nil, "ally"
	end
	if isGoalkeeper(actor) then
		return nil, "gk"
	end
	local root = ActorTargeting.GetActorRoot(actor)
	if not root then
		return nil, "no root"
	end
	return actor, root
end

local function carrierDribbleWait(actor, eta)
	local ch = Actors.GetCharacter(actor)
	if not ch then
		return false
	end
	local key = (typeof(actor) == "Instance" and actor:IsA("Player") and actor.UserId) or ch
	local now = os.clock()
	local active = Dodge.IsDribbling(ch)
	local rec = dribbleSeen[key] or dribbleSeen[ch]
	local activeSec = Dodge.Constants.ActiveSeconds
	local cdSec = Dodge.Constants.RepeatDelaySeconds
	if active then
		if rec and rec.cdUntil and now < rec.cdUntil then
		else
			rec = {
				untilT = now + activeSec,
				cdUntil = now + cdSec,
			}
			dribbleSeen[key] = rec
			if ch then
				dribbleSeen[ch] = rec
			end
		end
	elseif rec and rec.cdUntil and now > rec.cdUntil then
		dribbleSeen[key] = nil
		if ch then
			dribbleSeen[ch] = nil
		end
		rec = nil
	end
	if not rec then
		return false
	end
	local arrive = eta or C.HitboxDelaySeconds
	return now + arrive < rec.untilT
end

local function tackleTuning()
	local speed = math.max(0.4, CFG.TackleSpeed)
	return {
		speed = speed,
		reach = CFG.TackleReach,
		dashDist = C.StartupDashDistance,
		dashDur = 0.5 / speed,
		handoff = C.StartupDashHandoffSeconds / speed,
		mainDist = C.Distance,
		mainDur = C.MotionSeconds / speed,
		totalT = C.TotalMotionSeconds / speed,
		landing = C.AssistLandingStuds,
	}
end

local Wire = {
	MAX = 60,
	t = table.create(60),
	p = table.create(60),
	n = 0,
	head = 1,
}

MovementStreamTap.Subscribe(function(ch, stamp, cf)
	if ch ~= LocalPlayer.Character then
		return
	end
	if type(stamp) ~= "number" or typeof(cf) ~= "CFrame" then
		return
	end
	if Wire.n < Wire.MAX then
		Wire.n = Wire.n + 1
		Wire.t[Wire.n] = stamp
		Wire.p[Wire.n] = cf.Position
		return
	end
	Wire.t[Wire.head] = stamp
	Wire.p[Wire.head] = cf.Position
	Wire.head = Wire.head % Wire.MAX + 1
end)

local function wireIndex(i)
	if Wire.n < Wire.MAX then
		return i
	end
	return (Wire.head + i - 2) % Wire.MAX + 1
end

local function wireAt(stamp)
	if Wire.n == 0 then
		return nil
	end
	local i0 = wireIndex(1)
	local i1 = wireIndex(Wire.n)
	if stamp <= Wire.t[i0] then
		return Wire.p[i0]
	end
	if stamp >= Wire.t[i1] then
		return Wire.p[i1]
	end
	for i = 1, Wire.n - 1 do
		local a = wireIndex(i)
		local b = wireIndex(i + 1)
		if stamp <= Wire.t[b] then
			local span = Wire.t[b] - Wire.t[a]
			local u = span <= 1e-4 and 1 or (stamp - Wire.t[a]) / span
			return Wire.p[a]:Lerp(Wire.p[b], u)
		end
	end
	return Wire.p[i1]
end

local function ourRewindPosition(root, enemyActor, mode)
	if mode == "live" then
		return root.Position, 0
	end
	local otherOw = 0
	if typeof(enemyActor) == "Instance" and enemyActor:IsA("Player") then
		otherOw = CommandTime.GetPlayerOneWaySeconds(enemyActor)
	end
	local rewind = CommandTime.GetPlayerVictimRewindSeconds(LocalPlayer, otherOw)
	local stamp = CharacterMotionSmoothing.GetSmoothedServerTime() - rewind
	local p = wireAt(stamp)
	if p then
		return p, rewind
	end
	local ch = LocalPlayer.Character
	local vel = flat((ch and CharacterMotion.GetVelocity(ch)) or Vector3.new())
	return root.Position - CommandTime.ClampExtrapolationOffset(vel * rewind), rewind
end

-- Slide origin is dash travel, not vel*delay. Packet: GetPosition + heading * dumpTravel(displayDelay).
Mark.enemySlideOrigin = function(root, ch, heading, elapsed)
	elapsed = elapsed or 0
	local live = root.Position
	if ch then
		live = CharacterMotion.GetPosition(ch) or live
	end
	local delay = 0
	if ch then
		delay = math.clamp(CharacterMotion.GetDisplayDelaySeconds(ch) or 0, 0, 0.25)
	end
	if not heading then
		return live, delay, live
	end
	local pose = live + heading * Mark.dumpTravel(delay)
	return pose - heading * Mark.dumpTravel(elapsed), delay, live
end

local function headingOf(character, root)
	local vel = unitOrNil(flat((character and CharacterMotion.GetVelocity(character)) or Vector3.new()))
	if vel then
		return vel
	end
	return unitOrNil(flat(root.CFrame.LookVector))
end


-- Dump HitboxSettings.SlideTackle: box CFrameOffset Z -3, Size Z 5 -> covers 0.5..5.5 studs ahead of our root.
-- Box is live from HitboxDelaySeconds for HitboxSeconds. Travel at multiplier m is m * dumpTravel(t):
-- GetStartupDashDistance and GetDistance both scale by SetSpeedMultiplier, durations do not.
Mark.slideBox = function()
	local box = HitboxSettings.SlideTackle
	local mid = -box.CFrameOffset.Z
	local half = box.Size.Z * 0.5
	return mid, mid - half, mid + half
end

-- Carrier pose = CharacterMotion.GetPosition/GetVelocity (what SlideTackleInput.getAssistedTackleTargetPosition reads).
Mark.carrierPose = function(carrierRoot, carrierChar)
	local livePos = carrierRoot.Position
	local pos = (carrierChar and CharacterMotion.GetPosition(carrierChar)) or livePos
	local worldVel = carrierChar and (CharacterMotion.GetVelocity(carrierChar) or Vector3.zero) or Vector3.zero
	local rawVel = flat(worldVel)
	if carrierChar then
		Mark.motion = Mark.motion or setmetatable({}, { __mode = "k" })
		local now = os.clock()
		local rec = Mark.motion[carrierChar]
		if not rec or now - (rec.t or 0) > 0.22 then
			Mark.motion[carrierChar] = { t = now, p = livePos, v = rawVel }
		else
			local dt = now - rec.t
			if dt >= 0.025 and rec.p then
				local step = flat(livePos - rec.p) / dt
				local motion = flat(worldVel)
				local spike = step.Magnitude > 32 or (motion.Magnitude > 2 and step.Magnitude > motion.Magnitude * 1.7 + 6)
				if spike then
					rawVel = motion.Magnitude > 0.4 and motion or (rec.v and rec.v.Magnitude <= 32 and rec.v or rawVel)
				elseif step.Magnitude > 0.8 then
					rawVel = step
				end
				rec.t = now
				rec.p = livePos
				rec.v = rawVel
			elseif rec.v and rec.v.Magnitude > 0.4 then
				rawVel = rec.v
			end
		end
		if Dodge.IsDribbling(carrierChar) then
			local u = unitOrNil(rawVel)
			rawVel = u and u * math.min(rawVel.Magnitude, Dodge.Constants.WalkSpeed) or rawVel
		elseif Mark.charges then
			-- A carrier whose KickChargeStarted/Updated is live walks at ActionMovement.GetChargingWalkSpeed (0.5 x jog)
			-- and cannot sprint: the displayed velocity is a few frames stale (display delay + ping) and still shows the
			-- run-up, which is what made the block spot and the slide lead overshoot a charging carrier.
			local pl = Players:GetPlayerFromCharacter(carrierChar)
			local rec = pl and Mark.charges[pl.UserId]
			if rec and rec.live and os.clock() - (rec.seen or 0) < 0.6 then
				Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
				local okW, cw = pcall(Mark.mover.GetChargingWalkSpeed, Mark.mover.GetBaseWalkSpeed(carrierChar), true)
				local u = unitOrNil(rawVel)
				if okW and type(cw) == "number" and u and rawVel.Magnitude > cw then
					rawVel = u * cw
					Mark.chargeClamped = os.clock()
				end
			end
		end
	end
	return pos, rawVel, worldVel, livePos
end

local function solveIntercept(ourRoot, carrierRoot, carrierChar, tune)
	local origin = ourRoot.Position
	local enemyPos, rawVel, worldVel, livePos = Mark.carrierPose(carrierRoot, carrierChar)
	local delay = 0
	if carrierChar then
		delay = math.clamp(CharacterMotion.GetDisplayDelaySeconds(carrierChar) or 0, 0, 0.25)
	end
	local nowDist = flat(enemyPos - origin).Magnitude
	local liveDist = flat(livePos - origin).Magnitude
	if nowDist > CFG.TrackStuds and liveDist > CFG.TrackStuds then
		return nil
	end
	local spd = rawVel.Magnitude
	local t0 = C.HitboxDelaySeconds
	local t1 = C.HitboxDelaySeconds + C.HitboxSeconds
	local wait = nil
	local iframe = 0
	if carrierChar and Dodge.IsDribbling(carrierChar) then
		local rec = dribbleSeen[carrierChar]
		iframe = (rec and rec.untilT) and math.max(0, rec.untilT - os.clock()) or Dodge.Constants.ActiveSeconds
		if iframe >= t1 then
			wait = "iframe"
		end
	end
	local tAir = 0
	local hum = carrierChar and carrierChar:FindFirstChildOfClass("Humanoid")
	if not wait and hum and not CharacterControllers.IsLanded(carrierChar, hum) then
		tAir = Mark.fallT(enemyPos.Y, worldVel.Y, origin.Y)
		if tAir > t1 then
			wait = "air"
		end
	end
	if not wait and hum and CFG.CounterJump and not CharacterControllers.IsLanded(carrierChar, hum) and nowDist <= (CFG.CounterJumpRange or 10) + 4 then
		wait = "counter" -- he left the ground with the ball: Mark.tickCounterJump jumps, a slide under a flying kick is wasted
	end
	-- Ball ABOVE a grounded carrier (above his Receive box top + ball radius): he jumps for it, a slide under a jump is
	-- wasted - the ball is the target (AutoBlock intercept / AutoBall / CounterJump), not him.
	if not wait then
		local ballP = Renderer.GetPosition()
		if typeof(ballP) == "Vector3" then
			local rcvH = HitboxSettings.Receive.CFrameOffset.Y + HitboxSettings.Receive.Size.Y * 0.5 + (Physics.BallRadius or 1)
			if ballP.Y - enemyPos.Y > rcvH + 0.6 and flat(ballP - enemyPos).Magnitude <= 10 then
				wait = "ball high"
			end
		end
	end
	-- flick wind-up far away: the ball is gone before a slide from here lands
	if not wait and carrierChar and nowDist > (CFG.FlickTackleRange or 10) then
		local pl = Players:GetPlayerFromCharacter(carrierChar)
		Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
		if pl and Mark.enemyWind(pl) then
			wait = "flick"
		end
	end
	local mid, near, far = Mark.slideBox()
	local mHi = math.max(0.4, CFG.TackleSpeed)
	local mLo = math.min(mHi, CFG.TackleMinSpeed or 0.6)
	local bestT, bestPred, bestMult = nil, nil, nil
	local edgeT, edgePred, edgeMult = nil, nil, nil
	local mMin, mMax = math.huge, -math.huge
	if not wait then
		local t = math.max(t0, iframe, tAir)
		while t <= t1 + 1e-4 do
			local pred = enemyPos + rawVel * t
			local d = flat(pred - origin).Magnitude
			local T = Mark.dumpTravel(t)
			local mC = (d - mid) / T
			mMin = math.min(mMin, mC)
			mMax = math.max(mMax, mC)
			if mC >= mLo and mC <= mHi then
				bestT, bestPred, bestMult = t, pred, mC
				break
			end
			if not edgeT then
				local lo = math.max((d - far + 1) / T, mLo)
				local hi = math.min((d - near - 1) / T, mHi)
				if lo <= hi then
					edgeT, edgePred = t, pred
					edgeMult = (mC < mLo) and lo or hi
				end
			end
			t += 0.02
		end
		if not bestT and edgeT then
			bestT, bestPred, bestMult = edgeT, edgePred, edgeMult
		end
		if not bestT then
			if mMax < mLo then
				wait = "close"
			elseif nowDist > mHi * Mark.dumpTravel(t1) + far + 8 then
				wait = "track"
			else
				wait = "outrun"
			end
		end
	end
	local aim = bestPred and unitOrNil(flat(bestPred - origin))
	local ourPts, enemyPts = {}, {}
	if aim and bestT then
		for i = 0, 8 do
			local t = bestT * (i / 8)
			ourPts[i + 1] = origin + aim * (bestMult * Mark.dumpTravel(t))
			enemyPts[i + 1] = enemyPos + rawVel * t
		end
	end
	local fire = aim ~= nil and bestT ~= nil and wait == nil
	local conf = 0
	if fire then
		local okN, allN, tt = 0, 0, t0
		local tMin = math.max(t0, iframe, tAir)
		while tt <= t1 + 1e-4 do
			allN += 1
			if tt >= tMin - 1e-4 then
				local mC = (flat(enemyPos + rawVel * tt - origin).Magnitude - mid) / Mark.dumpTravel(tt)
				if mC >= mLo and mC <= mHi then
					okN += 1
				end
			end
			tt += 0.02
		end
		conf = math.max(okN / math.max(allN, 1), edgeT and 0.02 or 0)
	end
	return {
		hit = bestPred,
		eta = bestT,
		aim = aim,
		mult = bestMult,
		our = ourPts,
		enemy = enemyPts,
		dist = nowDist,
		catch = fire,
		short = nil,
		stable = true,
		behind = false,
		must = fire,
		cover = 0,
		marks = {},
		spd = spd,
		instSpd = flat(worldVel).Magnitude,
		meanSpd = spd,
		recentSpd = spd,
		accel = Vector3.zero,
		yaw = 0,
		livePos = livePos,
		serverPos = enemyPos,
		delay = delay,
		delta = flat(enemyPos - livePos).Magnitude,
		distLive = liveDist,
		samples = 0,
		track = wait == "track",
		conf = conf,
		fire = fire,
		wind = 0,
		wait = wait,
		iframe = iframe,
	}
end

local slideLock = setmetatable({}, { __mode = "k" })

local function slideElapsed(model)
	local untilT = SlideTackle.GetSlidingUntil(model)
	local now = Workspace:GetServerTimeNow()
	if not (untilT and now < untilT) then
		return nil
	end
	return math.max(0, C.TotalMotionSeconds - (untilT - now))
end

local function lockEnemySlide(model, root)
	local elapsed = slideElapsed(model)
	local lock = slideLock[model]
	if not elapsed then
		if lock and lock.hold and os.clock() < lock.hold then
			return lock, lock.elapsed or 0
		end
		slideLock[model] = nil
		return nil
	end
	if not lock then
		local heading = headingOf(model, root)
		if not heading then
			return nil
		end
		local origin = Mark.enemySlideOrigin(root, model, heading, elapsed)
		lock = {
			heading = heading,
			origin = origin,
			feet = root.Position,
			startPos = origin,
			fromPacket = false,
			t0 = os.clock() - elapsed,
		}
		slideLock[model] = lock
	else
		-- Re-anchor on his CURRENT motion: a PC tackler steers the whole slide (main dash reads GetDirection =
		-- MoveCommand every frame), the chord from the start point lags every bend. Direction = his displacement
		-- over the last ~0.08 s; origin = shifted so origin + heading * travel(elapsed) = his current server pose.
		-- Packet locks keep the AimDirection for the first 0.12 s (display still lags the packet there).
		local now = os.clock()
		local pose = CharacterMotion.GetPosition(model) or root.Position
		local hist = lock.hist or {}
		lock.hist = hist
		hist[#hist + 1] = { t = now, p = pose }
		while #hist > 2 and now - hist[2].t >= 0.08 do
			table.remove(hist, 1)
		end
		local old = hist[1]
		local moved = flat(pose - old.p)
		if now - old.t >= 0.03 and moved.Magnitude > 0.8 and (not lock.fromPacket or elapsed >= 0.12) then
			local heading = moved.Unit
			lock.heading = heading
			lock.origin = Mark.enemySlideOrigin(root, model, heading, elapsed)
		end
	end
	lock.elapsed = elapsed
	return lock, elapsed
end

local function slideFuture(lock, elapsed)
	local pts = {}
	local n = 12
	local t1 = C.TotalMotionSeconds
	local t0 = elapsed
	if t1 <= t0 then
		return pts
	end
	for i = 0, n do
		local t = t0 + (t1 - t0) * (i / n)
		pts[i + 1] = lock.origin + lock.heading * Mark.dumpTravel(t)
	end
	return pts
end

local function slidePathClosest(lock, elapsed, ourPos)
	if not (lock and lock.heading and lock.origin and ourPos) then
		return nil, 1e9
	end
	local t0 = math.max(elapsed or 0, C.HitboxDelaySeconds)
	local t1 = C.HitboxDelaySeconds + C.HitboxSeconds
	local a = lock.origin + lock.heading * Mark.dumpTravel(t0)
	local b = lock.origin + lock.heading * Mark.dumpTravel(t1)
	local ab = flat(b - a)
	local denom = ab:Dot(ab)
	local u = 0
	if denom > 1e-4 then
		u = math.clamp(flat(ourPos - a):Dot(ab) / denom, 0, 1)
	end
	local pt = a + ab * u
	return pt, flat(ourPos - pt).Magnitude
end

-- Real assisted-tackle steering (SlideTackleInput GetDirection, touch players with AssistedTackles): during the
-- startup dash (< HitboxDelaySeconds) the direction turns toward getAssistedTackleTargetPosition at
-- u4 = 1.5*pi / HitboxDelaySeconds rad/s (rotateFlatDirectionToward); the target is the BALL OWNER (SetOwnerUserId),
-- predicted as pos + vel * (i - now) at the first i in the hitbox window his landing reach covers (reach =
-- travel(i) - travel(now) + AssistLandingStuds), else the closest one if within 4. Homing stops once the target is
-- behind him inside AssistLandingStuds. After the hand-off the direction is frozen. Returns the hit time (seconds
-- from now) of his real box on target + targetVel*tau with `pad`, or nil.
Mark.assistPath = function(body, heading, elapsed, targetAt)
	local HD, HS = C.HitboxDelaySeconds, C.HitboxSeconds
	local landing = C.AssistLandingStuds or 5.5
	local rate = 1.5 * math.pi / HD
	local pos, dir, t = body, heading, elapsed
	local homing = true
	local function aimAt(now)
		local best, bestErr = nil, math.huge
		local trNow = Mark.dumpTravel(now)
		local i = HD
		while i <= HD + HS + 0.001 do
			local p = targetAt(i)
			local err = flat(p - pos).Magnitude - (Mark.dumpTravel(i) - trNow + landing)
			if err <= 0 then
				return p
			end
			if err < bestErr then
				best, bestErr = p, err
			end
			i += 0.05
		end
		return bestErr <= 4 and best or nil
	end
	while t < HD - 1e-4 do
		local dt = math.min(0.03, HD - t)
		if homing then
			local aim = aimAt(t)
			local to = aim and flat(aim - pos)
			if not to then
				homing = false
			elseif to.Magnitude > 0.001 then
				local u = to.Unit
				if u:Dot(dir) < 0 and to.Magnitude < landing then
					homing = false
				else
					local ang = math.acos(math.clamp(dir:Dot(u), -1, 1))
					local turn = rate * dt
					if ang <= turn then
						dir = u
					else
						if dir.Z * u.X - dir.X * u.Z < 0 then
							turn = -turn
						end
						local c, s = math.cos(turn), math.sin(turn)
						dir = Vector3.new(dir.X * c + dir.Z * s, 0, -dir.X * s + dir.Z * c)
					end
				end
			end
		end
		pos += dir * (Mark.dumpTravel(t + dt) - Mark.dumpTravel(t))
		t += dt
	end
	local t0 = math.max(t, elapsed)
	return function(bt)
		return pos + dir * (Mark.dumpTravel(bt) - Mark.dumpTravel(t0)), dir
	end
end

Mark.assistSweep = function(body, heading, elapsed, target, targetVel, pad)
	local HD, HS = C.HitboxDelaySeconds, C.HitboxSeconds
	local box = HitboxSettings.SlideTackle
	local hx, hz, boxMid = box.Size.X * 0.5, box.Size.Z * 0.5, -box.CFrameOffset.Z
	local rootAt = Mark.assistPath(body, heading, elapsed, function(i)
		return target + targetVel * (i - elapsed)
	end)
	local tb = math.max(elapsed, HD)
	while tb <= HD + HS + 1e-4 do
		local rootPos, dir = rootAt(tb)
		local rel = flat(target + targetVel * (tb - elapsed) - rootPos)
		local lon = rel:Dot(dir) - boxMid
		local lat = rel.X * dir.Z - rel.Z * dir.X
		if math.max(math.abs(lon) - hz, math.abs(lat) - hx, 0) <= pad then
			return tb - elapsed
		end
		tb += 0.03
	end
	return nil
end

-- Does his slide hit us. ONE physical test: the server checks our HRP point against his slide box
-- (SlideTackle.IsInsideHitbox: |x|,|y|,|z| <= 2.5 around root + 3 studs ahead), live from HitboxDelaySeconds for
-- HitboxSeconds. His path = lock.origin + lock.heading * travel(t), re-anchored every frame on his CURRENT position and
-- direction (lockEnemySlide): a PC tackler steers the whole slide with MoveCommand (SlideTackle main dash reads
-- GetDirection every frame), so the packet heading alone misses bent slides. Our server pose = ghost (and live)
-- moving with our current step, both packet-delay hypotheses. Pads: strong 0.35 + our motion over ping/2;
-- weak +1.0 before his hand-off. Assisted actors (learned by Mark.slideAudit) with us as ball owner: the real
-- homing (Mark.assistSweep). Removed: predNear / corridor / rear / bent / close / onLine reads - they fired up to
-- 4.5-8.25 studs off his line and on slides already behind us; the old "own ball -> any slide in reach fires"
-- (slideHoming) is gone too.
Mark.slideAtUs = function(lock, elapsed, root, actor)
	if not (lock and lock.heading and lock.origin and root) then
		return nil
	end
	elapsed = elapsed or 0
	local HD = C.HitboxDelaySeconds
	local tEnd = HD + C.HitboxSeconds
	local ghost = ourRewindPosition(root, actor)
	local live = root.Position
	local ch = LocalPlayer.Character
	local vel = flat((ch and CharacterMotion.GetVelocity(ch)) or Vector3.zero)
	local stick = nil
	if ch then
		local cmd = CharacterControllers.GetMoveCommand(ch)
		if typeof(cmd) == "Vector3" then
			stick = unitOrNil(flat(cmd))
		end
	end
	local step = stick and (stick * math.max(vel.Magnitude, 16)) or vel
	local heading = lock.heading
	local body = lock.origin + heading * Mark.dumpTravel(math.min(elapsed, C.TotalMotionSeconds))
	local window = elapsed <= tEnd + 0.04
	local pingS = math.clamp(LocalPlayer:GetNetworkPing() or 0, 0, 0.25)
	local box = HitboxSettings.SlideTackle
	local hx, hz, boxMid = box.Size.X * 0.5, box.Size.Z * 0.5, -box.CFrameOffset.Z
	local motionPad = math.min(step.Magnitude * pingS * 0.5, 1.2)
	local assistOn = Mark.assistOK(actor)
	local padStrong = 0.35 + motionPad
	local padWeak = padStrong + ((elapsed < HD and not assistOn) and 1.0 or 0.3)
	local minOut, outG, outL = 1e9, 1e9, 1e9
	local closest, hitIn = nil, nil
	local nowIn = false
	local function sweep(pad)
		local found = false
		for _, d in { 0, pingS } do
			local tb = math.max(elapsed + d, HD)
			while tb <= tEnd + 1e-4 do
				local tau = math.max(tb - elapsed - d, 0)
				local rootPos = lock.origin + heading * Mark.dumpTravel(tb)
				for k, base in { ghost, live } do
					local rel = flat(base + step * tau - rootPos)
					local lon = rel:Dot(heading) - boxMid
					local lat = rel.X * heading.Z - rel.Z * heading.X
					local out = math.max(math.abs(lon) - hz, math.abs(lat) - hx, 0)
					if out < minOut then
						minOut = out
						closest = rootPos + heading * boxMid
					end
					if k == 1 and out < outG then
						outG = out
					elseif k == 2 and out < outL then
						outL = out
					end
					if out <= 0 and tau <= 0.04 then
						nowIn = true
					end
					if out <= pad then
						if not hitIn or tau < hitIn then
							hitIn = tau
						end
						found = true
					end
				end
				tb += 0.03
			end
		end
		return found
	end
	local hitS = window and sweep(padStrong)
	local hitW = hitS or (window and sweep(padWeak))
	local assistP = false
	if assistOn and window and elapsed < HD and liveOwnerId() == LocalPlayer.UserId then
		local tau = Mark.assistSweep(body, heading, elapsed, ghost, step, padStrong)
		if tau then
			assistP = true
			hitIn = math.min(hitIn or tau, tau)
		end
	end
	local fire = (hitW or assistP) and true or false
	local strong = (hitS or assistP) and true or false
	local toG, toL = flat(ghost - body), flat(live - body)
	local uG, uL = unitOrNil(toG), unitOrNil(toL)
	local side = math.abs(toL.X * heading.Z - toL.Z * heading.X)
	return {
		fire = fire,
		force = fire,
		strong = strong,
		approach = false,
		why = (hitS and "box," or (hitW and "pad," or "")) .. (assistP and "assist," or "") .. string.format("out%.1f,pad%.1f", minOut, padStrong),
		hitIn = fire and hitIn or nil,
		hits = nowIn,
		boxed = nowIn,
		fut = hitW and true or false,
		defend = hitS and true or false,
		walkIn = hitW and true or false,
		predHit = hitS and true or false,
		closest = closest,
		hitP = closest,
		lat = minOut,
		latG = outG,
		latL = outL,
		side = side,
		body = toL.Magnitude,
		srv = toG.Magnitude,
		dist = math.min(toG.Magnitude, toL.Magnitude),
		ghost = ghost,
		dotG = uG and heading:Dot(uG) or nil,
		dotL = uL and heading:Dot(uL) or nil,
	}
end

Mark.assistOK = function(actor)
	local k = actor and actor.UserId
	local r = k and Mark.assistKnow and Mark.assistKnow[k]
	return r ~= nil and r.home > r.straight
end

-- Tracks every enemy slide near us: (a) learns whether that actor's dash homes on us (bend toward us after the
-- packet heading) -> Mark.assistKnow; (b) audits the reaction: did his real slide box ever contain our server pose.
-- Log: "tackle audit <name> fired <why> dist <d> result hit|miss minLat <l> bend <deg> homing <b> dribble <b> dodge <b>".
Mark.slideAudit = function(root)
	local list = Mark.audits
	if not list or #list == 0 then
		return
	end
	local now = os.clock()
	for i = #list, 1, -1 do
		local a = list[i]
		local el = now - a.t0
		local theirRoot = a.root
		if not (theirRoot and theirRoot.Parent) or el > 1.2 then
			table.remove(list, i)
		else
			local pe = theirRoot.Position
			local d = flat(pe - a.p0)
			if d.Magnitude > 3 then
				a.dirNow = d.Unit
				a.travel = d.Magnitude
			end
			if el >= C.HitboxDelaySeconds - 0.05 and el <= C.HitboxDelaySeconds + C.HitboxSeconds + 0.1 then
				local dir = a.dirNow or a.heading
				local ghost = ourRewindPosition(root, a.actor)
				local rel = flat(ghost - pe)
				local ax = rel:Dot(dir)
				if ax > -3 then
					local lat = (rel - dir * ax).Magnitude
					if lat < a.minLat then
						a.minLat = lat
					end
				end
				local proxy = { CFrame = CFrame.lookAt(pe, pe + dir) }
				if SlideTackle.IsInsideHitbox(proxy, Vector3.new(ghost.X, pe.Y, ghost.Z)) then
					a.hit = true
				end
			end
			if el >= C.HitboxDelaySeconds + C.HitboxSeconds + 0.12 then
				table.remove(list, i)
				local bend, homing = 0, false
				if a.dirNow and (a.travel or 0) > 6 then
					bend = math.deg(math.acos(math.clamp(a.heading:Dot(a.dirNow), -1, 1)))
					local toUs = unitOrNil(flat(a.us0 - a.p0))
					if toUs and bend > 6 and a.dirNow:Dot(toUs) > a.heading:Dot(toUs) + 0.06 then
						homing = true
					end
					local key = a.actor and a.actor.UserId
					if key then
						Mark.assistKnow = Mark.assistKnow or {}
						local r = Mark.assistKnow[key] or { home = 0, straight = 0 }
						Mark.assistKnow[key] = r
						if homing then
							r.home += 1
						elseif bend < 4 then
							r.straight += 1
						end
					end
				end
				logFile("tackle audit", a.name, "fired", tostring(a.fired), a.why or "-", "dist", string.format("%.1f", a.dist), "result", a.hit and "hit" or "miss", "minLat", a.minLat < 1e8 and string.format("%.1f", a.minLat) or "-", "bend", string.format("%.0f", bend), "homing", tostring(homing), "dribble", tostring(a.dribble == true), "dodge", tostring(a.dodge == true))
			end
		end
	end
end

-- AgentAddon during / right before our dribble. The dribble only pays (SuccessfulDodgeSpeedBoost 1.5 s, crowd
-- DodgeSucceeded) when his box lands on us INSIDE the iframe (Dodge.ActiveSeconds 1). Plan on his re-anchored path
-- (lockEnemySlide follows his current direction): box centre c(t) = origin + heading * (travel(t) + 3) over the rest
-- of his window; pick the earliest t the dribble walk (Dodge WalkSpeed 12) reaches c(t) by, inside the iframe, and go
-- there. No holding of a final point: once we are in his box (or past the chosen point) keep walking at HIM until his
-- window closes - the box comes at us anyway and staying on his line keeps us in it. Window over or the iframe cannot
-- cover the rest of it -> nil (the user gets the controls back).
-- returns dir, phase ("meet" | "into"), target
Mark.dribblePlan = function(root, iframeEnd)
	local threat = dribbleDanger
	if not (threat and threat.sliding) then
		return nil
	end
	local lock = threat.character and slideLock[threat.character]
	if not lock and threat.actor then
		local ch = Actors.GetCharacter(threat.actor)
		lock = ch and slideLock[ch]
	end
	if not (lock and lock.heading and lock.origin and lock.t0) then
		return nil
	end
	local now = os.clock()
	local e = now - lock.t0
	local HD, tEnd = C.HitboxDelaySeconds, C.HitboxDelaySeconds + C.HitboxSeconds
	if e > tEnd then
		return nil
	end
	iframeEnd = iframeEnd or (lastDodgeAt + Dodge.Constants.ActiveSeconds)
	if iframeEnd - now < (tEnd - math.max(e, HD)) * 0.5 + 0.05 then
		return nil -- the iframe ends before most of his window: walking in would just eat the hit
	end
	local us = flat(root.Position)
	local mid = Mark.slideBox()
	local spd = Dodge.Constants.WalkSpeed or 12
	local body = lock.origin + lock.heading * Mark.dumpTravel(e)
	local t = math.max(e, HD)
	local first = nil
	while t <= tEnd + 1e-4 do
		local c = lock.origin + lock.heading * (Mark.dumpTravel(t) + mid)
		local need = math.max((flat(c) - us).Magnitude - 2.0, 0) / spd -- 2.0: inside the 5x5 box before its centre
		if not first then
			first = c
		end
		if need <= t - e and now + (t - e) <= iframeEnd - 0.05 then
			local to = flat(c) - us
			if to.Magnitude <= 1.0 then
				break -- already there: go at him
			end
			return to.Unit, "meet", c
		end
		t += 0.03
	end
	local toHim = unitOrNil(flat(body) - us)
	return toHim, "into", body
end

-- kept name: every caller (tryDribble dash, approach walk) gets the planned direction
local function dribbleInterceptDir(root, forDash)
	local dir = Mark.dribblePlan(root, (not ClientDodge.IsDribbling()) and (os.clock() + Dodge.Constants.ActiveSeconds) or nil)
	return dir
end

local function dribbleThreat(root)
	if not Mark.playLive() then
		return nil
	end
	local best
	local maxReach = Mark.dumpTravel(C.HitboxDelaySeconds + C.HitboxSeconds) + 5.9
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) and not isGoalkeeper(actor) then
			local r = ActorTargeting.GetActorRoot(actor)
			if r then
				local lock, elapsed = lockEnemySlide(model, r)
				if lock and elapsed then
					local at = Mark.slideAtUs(lock, elapsed, root, actor)
					if at and at.fire and (at.dist <= CFG.DribbleReact or at.dist <= maxReach) then
						if not best or at.dist < best.dist then
							best = {
								root = r,
								dist = at.dist,
								character = model,
								actor = actor,
								ourPos = at.ghost,
								heading = lock.heading,
								origin = lock.origin,
								sliding = true,
								fire = at.fire,
								strong = at.strong and true or false,
								why = at.why,
								approach = at.approach,
								force = at.fire,
								future = slideFuture(lock, elapsed),
								hitIn = at.hitIn,
								hitT = at.hitT,
								hitP = at.hitP,
								closest = at.closest,
								lat = at.lat,
								elapsed = elapsed,
							}
						end
					end
				end
			end
		end
	end
	return best
end

-- Enemy kick charge (ActionPresentationUpdate KickChargeStarted/Updated: userId + aim). The hit is resolved at his
-- release with HitboxSettings.Kick (6x7x7, CFrameOffset Z -1.5) on AimFacing.GetAimedRoot(root, aim): a box laid
-- along his FLAT aim. He may release any time after KickCore.GetMinimumReleaseSeconds. A dribble (Dodge
-- ActiveSeconds 1 iframe) started once that window opens covers every release up to a second later and earns
-- SuccessfulDodgeSpeedMultiplier when the kick lands on the iframe.
-- Enemy kick box art. One renderer for the live overlay, so what is tuned here is
-- what shows in a match. Concept: the box is BUILT by his charge. Edges draw themselves in construction order
-- (floor -> posts -> roof) as the charge climbs to KickCore minimum release; a sweep bar crosses the floor at the
-- same rate. At release-ready the floor takes three hatch strokes that land staggered (fast attack, small overshoot,
-- settle) and chevrons run along the floor toward the front face: the direction the kick will throw us. On the
-- strike the box folds onto its front face. LIP strokes only (ink under, colour on top), weight carries depth.
local function easeOut(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end
-- near-plane clipped segment writer over a Drawing line pool
Mark.segPool = function(lines)
	local pool = { i = 1 }
	pool.seg = function(a, b, color, alpha, thick, z)
		local ln = lines[pool.i]
		if not ln then
			return
		end
		-- camera state is read once per frame (Mark.frameCam, set at the top of RenderStepped); polyline callers
		-- (rings, arcs) reuse the projection of the previous segment's end point instead of projecting it twice
		local cam, cp, lk = Mark.frameCam, Mark.framePos, Mark.frameLook
		if not cam then
			cam = Workspace.CurrentCamera
			local cf = cam.CFrame
			cp, lk = cf.Position, cf.LookVector
		end
		local da, db = (a - cp):Dot(lk), (b - cp):Dot(lk)
		if da < 0.15 and db < 0.15 then
			return
		end
		local ob = b
		local pa, pb
		if da < 0.15 then
			a = a:Lerp(b, (0.15 - da) / (db - da))
		elseif db < 0.15 then
			b = b:Lerp(a, (0.15 - db) / (da - db))
		end
		if pool.lastB == a and pool.lastFrame == Mark.frameId then
			pa = pool.lastP
		else
			pa = cam:WorldToViewportPoint(a)
		end
		pb = cam:WorldToViewportPoint(b)
		if db >= 0.15 then
			pool.lastB, pool.lastP, pool.lastFrame = ob, pb, Mark.frameId
		else
			pool.lastB = nil
		end
		pool.i += 1
		ln.From, ln.To, ln.Color, ln.Transparency, ln.Thickness, ln.ZIndex, ln.Visible =
			Vector2.new(pa.X, pa.Y), Vector2.new(pb.X, pb.Y), color, alpha, thick, z, true
	end
	pool.finish = function()
		for n = pool.i, #lines do
			lines[n].Visible = false
		end
		pool.i = 1
	end
	return pool
end

-- Kick charge as a ripple: rings born at the centre of his kick box on the floor, growing out to the box footprint
-- and fading as they grow, like a drop in water. Born every 0.45 s, three alive at once, ease-out growth. Each ring
-- is 28 segments with a gradient that flows around it (phase moves with time), palette by state: blue (we're out),
-- amber (inside, he cannot release yet), red (inside, release possible). Charge progress speeds the birth rate up.
Mark.kickPalette = {
	safe = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(150, 120, 255), Color3.fromRGB(80, 255, 220) },
	armed = { Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 110, 150), Color3.fromRGB(255, 240, 140) },
	live = { Color3.fromRGB(255, 60, 70), Color3.fromRGB(255, 70, 200), Color3.fromRGB(255, 150, 60) },
}
-- phase is accumulated per caller (Mark.ripplePhase): the old version derived the ring index from os.clock()/period
-- with a period that changed every frame, so ring ages jumped around -> the blue windup state flickered wildly.
Mark.ripplePhase = {}
Mark.rippleRates = { live = 1 / 0.5, armed = 1 / 0.6, safe = 1 / 0.6 } -- rings per second; windup a bit slower than live
Mark.rippleStep = function(key, rate)
	local now = os.clock()
	local st = Mark.ripplePhase[key]
	if not st then
		st = { phase = 0, at = now }
		Mark.ripplePhase[key] = st
	end
	local dt = math.clamp(now - st.at, 0, 0.1)
	st.at = now
	st.phase += dt * rate
	return st.phase
end
Mark.kickRipple = function(seg, center, maxR, palette, phase, t, shape)
	local N = 28
	-- shape: superellipse exponent (2 = circle, 4 = rounded square that still reads as a circle)
	-- unit superellipse points are a constant per shape: built once, not 3 x 29 pow() pairs every frame
	Mark.squircleLut = Mark.squircleLut or {}
	local lut = Mark.squircleLut[shape or 2]
	if not lut then
		local ex = 2 / (shape or 2)
		lut = {}
		for s = 0, N do
			local a = s / N * math.pi * 2
			local c, sn = math.cos(a), math.sin(a)
			lut[s] = Vector3.new((c >= 0 and 1 or -1) * math.abs(c) ^ ex, 0, (sn >= 0 and 1 or -1) * math.abs(sn) ^ ex)
		end
		Mark.squircleLut[shape or 2] = lut
	end
	local function grad(f)
		-- 3-stop loop gradient, f in [0,1)
		local x = (f % 1) * 3
		local i = math.floor(x)
		local u = x - i
		local a, b = palette[i + 1], palette[(i + 1) % 3 + 1]
		u = u * u * (3 - 2 * u)
		return a:Lerp(b, u)
	end
	local born = math.floor(phase)
	for k = 0, 2 do
		local u = math.clamp((phase - (born - k)) / 3, 0, 1)
		local grow = 1 - (1 - u) ^ 3
		local r = 0.35 + (maxR - 0.35) * grow
		local alpha = (1 - u) ^ 1.6
		local thick = 1 + 2.2 * (1 - u)
		local flow = t * 0.35 + k * 0.17
		if alpha > 0.03 then
			local prev = nil
			for s = 0, N do
				local p = center + lut[s] * r
				if prev then
					seg(prev, p, grad(s / N + flow), alpha, thick, 43)
				end
				prev = p
			end
		end
	end
end

Mark.drawKickBox = function(kt, root)
	Mark.kickBoxLines = Mark.kickBoxLines or makeLines(96, 1.4, 42)
	Mark.kickPool = Mark.kickPool or Mark.segPool(Mark.kickBoxLines)
	local pool = Mark.kickPool
	if kt and kt.aimed and CFG.Draw and CFG.DrawKickBox ~= false and Workspace.CurrentCamera then
		local now = os.clock()
		if kt.open and not Mark.kickOpenAt then
			Mark.kickOpenAt = now
		elseif not kt.open then
			Mark.kickOpenAt = nil
		end
		local k = HitboxSettings.Kick
		local maxR = math.sqrt((k.Size.X * 0.5) ^ 2 + (k.Size.Z * 0.5) ^ 2)
		local P = Mark.kickPalette
		local key = (kt.inside and kt.open) and "live" or (kt.inside and "armed" or "safe")
		local phase = Mark.rippleStep("live-overlay", Mark.rippleRates[key])
		Mark.kickRipple(pool.seg, Vector3.new(kt.center.X, root.Position.Y - 2.9, kt.center.Z), maxR, P[key], phase, now)
	end
	pool.finish()
end

-- Seconds until a script Dribble press is actually accepted. The script's own `lastDodgeAt` only knows presses IT sent; the
-- game's Dodge.HandleInputBegan also refuses (returns true, no iframe: log "dodge gate dribble refused no-iframe cdLeft 0.00")
-- after the PLAYER's own dribble (module clock u6 -> Controls cooldown "Dribble"), without stamina (Dodge.Constants.StaminaCost
-- 0.25 via Sprint.SpendStamina) and in the air (CharacterControllers.IsLanded).
Mark.dribbleLeft = function()
	local left = math.max(0, dodgeEnforced - (os.clock() - lastDodgeAt))
	local okC, cd = pcall(function()
		if Controls.IsOnCooldown("Dribble") then
			return Controls.GetCooldownRemaining("Dribble")
		end
		return 0
	end)
	if okC and type(cd) == "number" and cd > left then
		left = cd
	end
	if left <= 0 then
		local ch = LocalPlayer.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum and not CharacterControllers.IsLanded(ch, hum) then
			left = 0.25
			Mark.dribbleBlock = "air"
		else
			Mark.sprint = Mark.sprint or require(Client.Gameplay.Player.Sprint)
			local okS, can = pcall(Mark.sprint.CanSpendStamina, Dodge.Constants.StaminaCost, true)
			if okS and can == false then
				left = 0.6
				Mark.dribbleBlock = "stamina"
			else
				Mark.dribbleBlock = nil
			end
		end
	else
		Mark.dribbleBlock = "cd"
	end
	return left
end

Mark.kickThreat = function(root)
	if not Mark.charges then
		return nil
	end
	local now = os.clock()
	local ping = LocalPlayer:GetNetworkPing()
	local minRel = KickCore.GetMinimumReleaseSeconds and KickCore.GetMinimumReleaseSeconds() or 0.15
	local best = nil
	for uid, rec in Mark.charges do
		if rec.live and now - (rec.seen or 0) < 1.5 and rec.dir then
			local actor = playerOf(uid)
			local r = actor and not sameTeam(actor) and ActorTargeting.GetActorRoot(actor)
			if r then
				local ch = Actors.GetCharacter(actor)
				local pos = (ch and CharacterMotion.GetPosition(ch)) or r.Position
				local vel = flat(ch and CharacterMotion.GetVelocity(ch) or Vector3.zero)
				-- while the Kick charges he walks at ActionMovement.GetChargingWalkSpeed (log: ws 27 -> 8), not at the jog the
				-- displayed velocity still shows: the old sweep put him metres past the real box, `inside` never came true and
				-- the dribble never fired for a kick (no "dribble kick sent" in the log, only kick into/no threat flicker)
				if ch then
					Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
					local okW, cw = pcall(Mark.mover.GetChargingWalkSpeed, Mark.mover.GetBaseWalkSpeed(ch), false)
					if okW and type(cw) == "number" and vel.Magnitude > cw then
						vel = vel.Unit * cw
					end
				end
				local lead = 0.1 + ping
				local P = pos + vel * lead
				local aimed = AimFacing.GetAimedRoot({ Position = P }, rec.dir)
				local us = root.Position + flat(root.AssemblyLinearVelocity) * lead
				-- Sweep the possible release times instead of one fixed lead. He may release any time between the minimum
				-- release and the full charge; the server tests OUR pose from `ping` ago against HIS pose at that moment.
				-- With one fixed lead (0.1 + ping, both sides projected forward) a kick we had already run past still
				-- counted ("dribbles a shot I basically ran through"), and one we were about to run into was missed.
				local inside = false
				do
					local pad = math.min(CFG.HitPad or 0.8, 0.8) -- 1.6 on a 6x7 box fired for kicks a body-width off us
					local elapsedK = now - rec.at
					local rMin = math.max(minRel - elapsedK, 0)
					local rMax = math.max((KickCore.Constants.MaximumChargeSeconds or 0.4) - elapsedK, 0) + 0.12
					local dly = ch and math.clamp(CharacterMotion.GetDisplayDelaySeconds(ch) or 0, 0, 0.25) or 0
					local vUs = flat(root.AssemblyLinearVelocity)
					for ki = 0, 5 do
						local rr = rMin + (rMax - rMin) * (ki / 5)
						local Pk = pos + vel * (dly + rr)
						local usK = root.Position + vUs * (rr - ping)
						local aimedK = AimFacing.GetAimedRoot({ Position = Pk }, rec.dir)
						local hit = HitboxSettings.ContainsPoint(aimedK, HitboxSettings.Kick, usK)
						if not hit then
							for _, o in { { pad, 0 }, { -pad, 0 }, { 0, pad }, { 0, -pad } } do
								if HitboxSettings.ContainsPoint(aimedK, HitboxSettings.Kick, usK + Vector3.new(o[1], 0, o[2])) then
									hit = true
									break
								end
							end
						end
						if hit then
							inside = true
							P, us, aimed = Pk, usK, aimedK
							break
						end
					end
				end
				local k = HitboxSettings.Kick
				local center = (aimed.CFrame * k.CFrameOffset).Position
				local d = flat(us - P).Magnitude
				local elapsed = now - rec.at
				local toUs = unitOrNil(flat(us - P))
				local fd = unitOrNil(flat(rec.dir))
				local th = { us = us, minRel = minRel, aimed = aimed, facing = (toUs and fd) and toUs:Dot(fd) or 0, uid = uid, actor = actor, inside = inside, center = Vector3.new(center.X, root.Position.Y, center.Z), dist = d, elapsed = elapsed, open = elapsed >= minRel - ping - 0.05 }
				if d <= 14 and (not best or d < best.dist) then
					best = th
				end
			end
		end
	end
	return best
end

local function tryDribble(force)
	if Mark.dribbleLeft() > 0 then
		return false, Mark.dribbleBlock or "cd"
	end
	-- A scripted sidestep (dodge tp) is in progress: it already took us out of this slide. The dribble cooldown ends
	-- a moment later and the per-frame threat (read from our lagging server pose) still says "fire": the dribble
	-- was spent after the danger had passed.
	if not force and Mark.move and Mark.move.mode == "dodge" and Mark.dodgeAt and os.clock() - Mark.dodgeAt < 1.0 then
		return false, "evading"
	end
	if ClientDodge.IsDribbling() then
		return false, "active"
	end
	if liveOwnerId() == LocalPlayer.UserId then
		ClientDodge.SetOwnerUserId(LocalPlayer.UserId)
	end
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	local dashDir = root and dribbleInterceptDir(root, true)
	local dir = root and dribbleInterceptDir(root)
	if not dashDir then
		dashDir = root and unitOrNil(flat(root.CFrame.LookVector))
	end
	if CFG.AgentAddon and dir and Mark.moveSteer then
		Mark.moveSteer(dir, "dribble")
	end
	ClientDodge.HandleInputBegan(Controls.CreateInput("Dribble"), false)
	local active = ClientDodge.IsDribbling()
	if not active then
		if not (dashDir or dir) then
			return false, "game-reject"
		end
		ActionRemoteProtocol.Send(ActionCommands.Dodge({
			AimDirection = dashDir or dir,
			ShotTime = Workspace:GetServerTimeNow(),
		}))
		active = ClientDodge.IsDribbling()
	end
	if not active then
		return false, "no-iframe"
	end
	lastDodgeAt = os.clock()
	do
		local th = dribbleDanger
		local ch = th and th.character
		local lk = ch and slideLock[ch]
		if lk then
			lk.usedDribble = true
		end
	end
	logFile("dribble sent")
	Log.pending[#Log.pending + 1] = {
		kind = "dribble",
		at = os.clock(),
		oid = liveOwnerId(),
	}
	return true, "sent"
end

local slideAim = nil
local slideAimUntil = 0
local origGetMove = CharacterControllers.GetMoveCommand
local origSetMove = CharacterControllers.SetMoveCommand
CharacterControllers.GetMoveCommand = function(ch)
	if slideAim and ch == LocalPlayer.Character and os.clock() < slideAimUntil then
		return slideAim
	end
	if ch == LocalPlayer.Character and ClientSlide.IsSlideTackling() then
		return origGetMove(ch)
	end
	if ch == LocalPlayer.Character and Mark.hazEv and next(Mark.hazEv) ~= nil and not (Mark.move and Mark.move.mode) then
		local okC, cc = pcall(Mark.blastClamp, ch, origGetMove(ch))
		if okC and typeof(cc) == "Vector3" then
			return cc
		end
	end
	local move = Mark.move
	if move and move.dir and move.mode and ch == LocalPlayer.Character and move.dir.Magnitude > 0.2 then
		return move.dir
	end
	return origGetMove(ch)
end
Mark.cutSlide = function(move)
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	local mv = unitOrNil(flat(move))
	if not (root and mv) then
		return nil
	end
	local ghost = ourRewindPosition(root, nil)
	for _, lock in slideLock do
		if lock and lock.heading and lock.origin and lock.t0 then
			local elapsed = os.clock() - lock.t0
			if elapsed <= C.HitboxDelaySeconds + C.HitboxSeconds + 0.04 then
				local at = Mark.slideAtUs(lock, elapsed, root, nil)
				local soon = ghost + mv * 10
				local _, soonLat = slidePathClosest(lock, elapsed, soon)
				local into = mv:Dot(lock.heading) > 0.2
				if at and (at.defend or at.walkIn or (into and soonLat <= 3.2 and (at.srv or 99) <= 26)) then
					local side = Vector3.new(-lock.heading.Z, 0, lock.heading.X)
					if side:Dot(ghost - lock.origin) < 0 then
						side = -side
					end
					if not Mark.cutLog or os.clock() - Mark.cutLog > 0.4 then
						Mark.cutLog = os.clock()
						logFile("cut walk", fmtV(side), "srv", at.srv and string.format("%.1f", at.srv) or "-")
					end
					return side
				end
			end
		end
	end
	return nil
end
CharacterControllers.SetMoveCommand = function(ch, move, look, rot)
	if ch == LocalPlayer.Character and typeof(move) == "Vector3" and move.Magnitude > 0.2 and Mark.cutSlide and not ClientDodge.IsDribbling() then
		local cut = Mark.cutSlide(move)
		if cut then
			move = cut
			look = Mark.move.look or cut
		end
	end
	if ch == LocalPlayer.Character and ClientSlide.IsSlideTackling() and not (slideAim and os.clock() < slideAimUntil) then
		return origSetMove(ch, move, look, rot)
	end
	if Mark.move.dir and Mark.move.mode and ch == LocalPlayer.Character and Mark.move.dir.Magnitude > 0.2 then
		move = Mark.move.dir
		if Mark.move.mode == "dodge" or Mark.move.mode == "block" then
			look = Mark.move.look or Mark.move.dir
			rot = true
		end
	end
	if ch == LocalPlayer.Character and Mark.chargeFace and ChargedKick.IsCharging and ChargedKick.IsCharging() then
		look = Mark.chargeFace
		rot = true
	end
	return origSetMove(ch, move, look, rot)
end
Mark.origSlideBegan = ClientSlide.HandleInputBegan
-- Gameplay_Script routes every InputBegan through slideTackleInput.HandleInputBegan; only a real Tackle press
-- from the player may cancel the agent, not W/Shift/Space.
-- ManualSupport: the player's own Tackle (keyboard, pad or the touch button all land here via Controls.IsInput) is
-- redirected onto the AutoTackle solution when the solver has a confirmed hit for this frame (Mark.manualTackle,
-- fresh < 0.15 s). No solution -> the press goes through untouched. Our own synthetic press (tryTackle) sets slideAim
-- first, so it is never re-captured here.
ClientSlide.HandleInputBegan = function(input, processed, ...)
	if not slideAim and not processed and Controls.IsInput("Tackle", input) then
		local character = LocalPlayer.Character
		local root = ActorTargeting.GetActorRoot(LocalPlayer)
		if CFG.ManualTackle and character and root and Mark.tryTackle and not ClientSlide.IsSlideTackling() then
			-- Solved at the moment of the press (the old path used the tick's solution only when it was a confirmed hit
			-- younger than 0.15 s: a press while the carrier was still "outrun"/"close"/"track" went out unaimed).
			-- Enemy carrier within ManualRadius -> the slide is aimed at him; nobody there -> the press is untouched and
			-- the game takes the player's own direction (stick, else where he faces).
			local aim, mult, tgt, how = Mark.manualAim(character, root)
			if not aim then
				local m = Mark.manualTackle
				if m and os.clock() - m.at < 0.15 then
					aim, mult, tgt, how = m.aim, m.mult, { char = m.char, root = m.root }, "tick"
				end
			end
			if aim then
				local _, why = Mark.tryTackle(character, root, aim, mult, tgt)
				logFile("tackle manual", tostring(why), "src", how, "aim", fmtV(aim), "mult", string.format("%.2f", mult or 0))
				if ClientSlide.IsSlideTackling() then
					return true
				end
			elseif not Mark.manualOwnLog or os.clock() - Mark.manualOwnLog > 1 then
				Mark.manualOwnLog = os.clock()
				logFile("tackle manual", "own dir", "no carrier within", tostring(CFG.ManualRadius))
			end
		end
		if Mark.moveStop then
			Mark.moveStop()
		end
	end
	return Mark.origSlideBegan(input, processed, ...)
end

-- Manual Tackle from a UI keybind / mobile button: the same aimed slide the game's own Tackle press gets above.
Mark.manualFire = function()
	local character = LocalPlayer.Character
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	if not (character and root and Mark.tryTackle) or ClientSlide.IsSlideTackling() then
		return
	end
	local aim, mult, tgt, how = Mark.manualAim(character, root)
	if not aim then
		local m = Mark.manualTackle
		if m and os.clock() - m.at < 0.15 then
			aim, mult, tgt, how = m.aim, m.mult, { char = m.char, root = m.root }, "tick"
		end
	end
	if not aim then
		logFile("tackle manual", "key", "no carrier within", tostring(CFG.ManualRadius))
		return
	end
	local _, why = Mark.tryTackle(character, root, aim, mult, tgt)
	logFile("tackle manual", tostring(why), "key", how or "-", "aim", fmtV(aim), "mult", string.format("%.2f", mult or 0))
end

Mark.chargeInst = function()
	local fn = ChargedKick.IsCharging
	if type(fn) ~= "function" then
		return nil
	end
	local inst = upvalue(fn, 1)
	if type(inst) == "table" and type(inst.IsLocalOwner) == "function" then
		return inst
	end
	return nil
end

Mark.weOwn = function()
	if liveOwnerId() == LocalPlayer.UserId then
		return true
	end
	local inst = Mark.chargeInst()
	if inst and inst.IsLocalOwner() then
		return true
	end
	return false
end

Mark.yieldKick = function()
	local cmd = Mark.kickCmd
	if cmd and not ClientSlide.IsSlideTackling() and ActionRemoteProtocol.IsCurrentSession(cmd) then
		ActionRemoteProtocol.Cancel(cmd)
	end
	if ChargedKick.CancelCharge then
		ChargedKick.CancelCharge()
	end
	Mark.dropKick()
end

Mark.dropKick = function()
	Mark.kickCmd = nil
end

-- A slide that would cross a puddle stuns us (HazardZoneKind Oil). Over the first ~14 studs a jump covers it: the slide is
-- pressed from the air (jump first, slide second - the other order is impossible, SetJumpStateBlocked("SlideTackle")). A
-- crossing that the air time does not cover, or a mine on the path, cancels the slide.
Mark.slidePathHazard = function(root, dir, mult)
	local m = mult or 1
	local function timeAt(d)
		for t = 0.02, 1.2, 0.02 do
			if Mark.dumpTravel(t) * m >= d then
				return t
			end
		end
		return 1.2
	end
	local reach = Mark.dumpTravel(1.0) * m
	local mineAt = Mark.mineAhead(root.Position, dir, reach)
	if mineAt then
		return "mine"
	end
	local run = Mark.oilAhead(root.Position, dir, reach)
	if not run then
		return nil
	end
	return "oil", timeAt(run.enter), timeAt(run.exit)
end

Mark.oilSlideTick = function(character, root)
	local p = Mark.oilSlide
	if not p then
		return
	end
	local now = os.clock()
	local hum = character:FindFirstChildOfClass("Humanoid")
	if now - p.at > 0.6 or not hum then
		Mark.oilSlide = nil
		return
	end
	if not CharacterControllers.IsLanded(character, hum) and now - p.at >= 0.1 then
		Mark.oilSlide = nil
		local sent, why = Mark.tryTackle(character, root, p.dir, p.mult, p.target, true)
		logFile("oil slide", "air", sent and "sent" or ("no " .. tostring(why)))
	end
end

local tryTackle
-- A carrier who is popping the ball up (flick wind-up, or the ball already above his Receive box) JUMPS after it: a ground slide
-- under him is wasted (the log: slide at the keeper-side carrier, he flicked and jumped). Returns "flick" | "ball high" | nil.
-- Another player's flick wind-up (see the RainbowFlickStarted note in onFx): true + seconds until the ball detaches
Mark.enemyWind = function(actor)
	local uid = actor and actor.UserId
	local rec = uid and Mark.flickRec and Mark.flickRec[uid]
	if not rec then
		return false, 0
	end
	local left = rec.detachSrv - Workspace:GetServerTimeNow()
	if left < -0.1 then
		Mark.flickRec[uid] = nil
		return false, 0
	end
	return true, math.max(left, 0)
end

Mark.lofting = function(ch, enemyRoot)
	if not ch then
		return nil
	end
	local pl = Players:GetPlayerFromCharacter(ch)
	Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
	if pl and Mark.enemyWind(pl) then
		return "flick"
	end
	local ballP = Renderer.GetPosition()
	local r = enemyRoot or ch:FindFirstChild("HumanoidRootPart")
	if typeof(ballP) == "Vector3" and r then
		local rcvH = HitboxSettings.Receive.CFrameOffset.Y + HitboxSettings.Receive.Size.Y * 0.5 + (Physics.BallRadius or 1)
		if ballP.Y - r.Position.Y > rcvH + 0.6 and flat(ballP - r.Position).Magnitude <= 12 then
			return "ball high"
		end
	end
	return nil
end

-- jump first, slide from the air at where he (and the ball) will be: the pending press is fired by Mark.jumpSlideTick
Mark.jumpSlideTick = function(character, root)
	local cb = Mark.jsCombo
	if not cb then
		return
	end
	local now = os.clock()
	if now > cb.untilT then
		Mark.jsCombo = nil
		return
	end
	if now < cb.pressAt then
		return
	end
	Mark.jsCombo = nil
	local er = cb.root
	if not (er and er.Parent) then
		return
	end
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local look = 0.42 + ping * 0.5
	local E = er.Position + flat(er.AssemblyLinearVelocity) * look
	local ballP = Renderer.GetPosition()
	if typeof(ballP) == "Vector3" and flat(ballP - er.Position).Magnitude < 8 then
		E = E:Lerp(ballP, 0.5)
	end
	local to = flat(E - root.Position)
	local d = to.Magnitude
	local dir = unitOrNil(to)
	local mHi = math.max(0.4, CFG.TackleSpeed)
	local mLo = math.min(mHi, CFG.TackleMinSpeed or 0.6)
	if not dir then
		return
	end
	local mid = -HitboxSettings.SlideTackle.CFrameOffset.Z
	local m = (d - mid) / math.max(Mark.dumpTravel(0.42), 1)
	if m > mHi + 0.15 then
		logFile("jump slide", "too far", "d", string.format("%.1f", d), "need", string.format("%.2f", m))
		return
	end
	m = math.clamp(m, mLo, mHi)
	Mark.jsBypass = true
	local sent, why = Mark.tryTackle(character, root, dir, m)
	Mark.jsBypass = nil
	logFile("jump slide", "air", sent and "sent" or ("no " .. tostring(why)), cb.why, "d", string.format("%.1f", d), "mult", string.format("%.2f", m))
end

tryTackle = function(character, root, dir, mult, target, skipHazard)
	if MatchSettings.IsGoalkeeperCharacter(character) then
		return false, "keeper" -- the keeper has no slide: the key is the dive
	end
	if os.clock() - lastTackleAt < tackleEnforced then
		return false, "cd"
	end
	if Ragdoll.IsActorRagdolled(LocalPlayer) then
		return false, "ragdoll"
	end
	-- SlideTackleInput.HandleInputBegan returns early while the kick charges (u8 = IsKickCharging).
	if ChargedKick.IsCharging and ChargedKick.IsCharging() then
		return false, "charging"
	end
	if ActionLocks.HasTackleBlock(LocalPlayer) then
		return false, "lock"
	end
	if SlideTackle.IsRepeatBlocked(character, false) then
		return false, "repeat"
	end
	if not dir then
		return false, "dir"
	end
	-- a lofting carrier: a ground slide at him is wasted -> jump first, the slide goes from the air (Mark.jumpSlideTick)
	if type(target) == "table" and target.char and not Mark.jsBypass and CFG.JumpSlide ~= false then
		local lw = Mark.lofting(target.char, target.root)
		if lw then
			local humJ = character:FindFirstChildOfClass("Humanoid")
			if humJ and CharacterControllers.IsLanded(character, humJ) then
				if not Mark.jsCombo and Mark.doJump("jumpslide") then
					Mark.jsCombo = { pressAt = os.clock() + (CFG.JumpSlideDelay or 0.16), untilT = os.clock() + 0.6, root = target.root, why = lw }
					logFile("jump slide", "jump first", lw)
				end
				return false, "lofting"
			end
		end
	end
	local wallRoot = ActorTargeting.GetActorRoot(LocalPlayer)
	local wallReach = math.min(Mark.dumpTravel(C.HitboxDelaySeconds) + 4, 14)
	if wallRoot and Mark.wallHit and Mark.wallHit(wallRoot.Position, dir, wallReach) then
		return false, "wall"
	end
	if ClientSlide.IsSlideTackling() then
		return false, "active"
	end
	if not skipHazard and not (Mark.oilSlide and os.clock() - Mark.oilSlide.at < 0.6) then
		local kind, tEnter, tExit = Mark.slidePathHazard(root, dir, mult or math.max(0.4, CFG.TackleSpeed))
		if kind == "mine" then
			return false, "mine"
		elseif kind == "oil" then
			local hum0 = character:FindFirstChildOfClass("Humanoid")
			local airT = Mark.jumpAir()
			-- jump now, slide ~0.1 s later: airborne from about 0.12 to airT - 0.06 after the jump
			if hum0 and CharacterControllers.IsLanded(character, hum0) and 0.1 + tEnter >= 0.12 and 0.1 + tExit <= airT - 0.06 then
				if Mark.doJump("oilslide") then
					Mark.oilSlide = { at = os.clock(), dir = dir, mult = mult, target = target }
					logFile("oil slide", "jump first", "enter", string.format("%.2f", tEnter), "exit", string.format("%.2f", tExit), "air", string.format("%.2f", airT))
					return false, "oil-jump"
				end
			end
			return false, "oil"
		end
	elseif Mark.oilSlide and not skipHazard then
		return false, "oil-pending"
	end
	if Mark.hazEv and next(Mark.hazEv) ~= nil then
		local O0 = wallRoot and wallRoot.Position or root.Position
		local hzEv = Mark.hazardHits(function(t)
			return O0 + dir * Mark.dumpTravel(t)
		end, 1.2)
		if hzEv and hzEv.kind == "blast" then
			return false, "blast"
		end
	end
	if Mark.moveStop then
		Mark.moveStop()
	end
	Mark.yieldKick()
	local hi = math.max(0.4, CFG.TackleSpeed)
	local mul = (type(mult) == "number") and math.clamp(mult, math.min(hi, CFG.TackleMinSpeed or 0.6), hi) or hi
	SlideTackle.SetSpeedMultiplier(mul)
	slideAim = dir
	slideAimUntil = os.clock() + C.TotalVelocityReleaseStartsAt
	origSetMove(character, dir, dir, true)
	ClientSlide.HandleInputBegan(Controls.CreateInput("Tackle"), false)
	SlideTackle.SetSpeedMultiplier(CFG.TackleSpeed)
	if ClientSlide.IsSlideTackling() then
		lastTackleAt = os.clock()
		Mark.slideTrack = { at = os.clock(), O = root.Position, dir = dir, m = mul, tag = (type(target) == "table" and target.char) and "carrier" or "ball" }
		Mark.slideHome = (type(target) == "table" and target.char) and {
			at = os.clock(),
			last = os.clock(),
			char = target.char,
			root = target.root,
			mult = mul,
			turns = 0,
		} or nil
		local p = predict
		logFile(
			"tackle sent",
			"mult",
			string.format("%.2f", mul),
			"distSrv",
			p and string.format("%.2f", p.dist) or "-",
			"distLive",
			p and string.format("%.2f", p.distLive or 0) or "-",
			"delay",
			p and string.format("%.3f", p.delay or 0) or "-",
			"live",
			p and fmtV(p.livePos) or "-",
			"srv",
			p and fmtV(p.serverPos) or "-",
			"eta",
			p and p.eta and string.format("%.3f", p.eta) or "-",
			"spd",
			p and string.format("%.2f", p.spd or 0) or "-",
			"hit",
			p and fmtV(p.hit) or "-",
			"aim",
			fmtV(dir),
			"usLive",
			fmtV(root.Position),
			"iframe",
			p and string.format("%.2f", p.iframe or 0) or "-"
		)
		Log.pending[#Log.pending + 1] = {
			kind = "tackle",
			at = os.clock(),
			oid = liveOwnerId(),
			dist = p and p.dist,
			hit = p and p.hit,
			aim = dir,
			livePos = p and p.livePos,
			serverPos = p and p.serverPos,
			delay = p and p.delay,
			delta = p and p.delta,
			yaw = p and p.yaw,
		}
		return true, "sent"
	end
	slideAim = nil
	slideAimUntil = 0
	logFile("tackle reject", "aim", fmtV(dir), "mult", string.format("%.2f", mul))
	return false, "game-reject"
end

-- Startup dash reads GetDirection every frame until handoff (StartupDashHandoffSeconds); the main dash direction is
-- locked at handoff (runSplitCFrameAction -> runCFrameAction gets a fixed Direction). Our GetDirection source is the
-- MoveCommand hook (slideAim), so re-aim slideAim at the carrier until handoff, at most the dump's assist turn rate
-- (SlideTackleInput u4 = 1.5*pi / HitboxDelaySeconds rad/s).
Mark.homeSlide = function(root)
	local h = Mark.slideHome
	if not h then
		return
	end
	local now = os.clock()
	local e = now - h.at
	local handoff = C.StartupDashHandoffSeconds
	if e >= handoff or not slideAim or not h.char or not h.char.Parent then
		if h.turns and h.turns > 0 then
			logFile("tackle home", "turns", tostring(h.turns), "e", string.format("%.2f", e))
		end
		Mark.slideHome = nil
		return
	end
	if e > 0.05 and not ClientSlide.IsSlideTackling() then
		Mark.slideHome = nil
		return
	end
	local p = CharacterMotion.GetPosition(h.char) or (h.root and h.root.Position)
	if typeof(p) ~= "Vector3" then
		return
	end
	local v = flat(CharacterMotion.GetVelocity(h.char) or Vector3.zero)
	if Dodge.IsDribbling(h.char) then
		local u = unitOrNil(v)
		v = u and u * math.min(v.Magnitude, Dodge.Constants.WalkSpeed) or v
	end
	local mid = Mark.slideBox()
	local done = h.mult * Mark.dumpTravel(e)
	local origin = root.Position
	local best, bestErr = nil, math.huge
	local t = math.max(C.HitboxDelaySeconds, e)
	local t1 = C.HitboxDelaySeconds + C.HitboxSeconds
	while t <= t1 + 1e-4 do
		local pred = p + v * (t - e)
		local d = flat(pred - origin).Magnitude
		local err = math.abs(d - (h.mult * Mark.dumpTravel(t) - done + mid))
		if err < bestErr then
			bestErr = err
			best = pred
		end
		t += 0.02
	end
	local want = best and unitOrNil(flat(best - origin))
	if not want then
		return
	end
	local dt = math.max(now - (h.last or h.at), 0)
	h.last = now
	local cur = unitOrNil(flat(slideAim)) or want
	local maxTurn = (1.5 * math.pi / C.HitboxDelaySeconds) * dt
	local ang = math.acos(math.clamp(cur:Dot(want), -1, 1))
	if ang <= maxTurn then
		slideAim = want
	else
		local turn = maxTurn
		if cur.Z * want.X - cur.X * want.Z < 0 then
			turn = -turn
		end
		slideAim = CFrame.fromAxisAngle(Vector3.yAxis, turn):VectorToWorldSpace(cur)
	end
	if ang > 0.02 then
		h.turns = (h.turns or 0) + 1
	end
end

local function note(kind, why)
	if kind == "t" then
		if why ~= lastDbgT then
			lastDbgT = why
			dbg("tackle", why)
		end
	elseif why ~= lastDbgD then
		lastDbgD = why
		dbg("dribble", why)
	end
end

local Shoot = { busy = false, gen = 0, last = -1e9 }

local function setShootWhy(why)
	if Shoot.why ~= why then
		Shoot.why = why
		dbg("shoot", why)
	end
end

local function sampleFlight(origin, velocity, spin, floorY, planePoint, planeNormal, tuning, doBounce)
	local pts = { origin }
	local times = { 0 }
	local pos, vel, sp = origin, velocity, spin or Vector3.zero
	local step = 0.09
	local t = 0
	local hit = nil
	local hitT = nil
	local bounced = 0
	local upN = Vector3.new(0, 1, 0)
	for stepI = 1, 40 do
		if stepI % 8 == 0 then
			Shoot.slice()
		end
		local prev = pos
		local np, nv, ns = Physics.GetAirFlight(pos, vel, sp, step, tuning)
		if typeof(np) ~= "Vector3" then
			break
		end
		pos = np
		vel = nv or vel
		sp = ns or sp
		t = t + step
		if t > 3.0 and not hit and bounced < 1 then
			break
		end
		if doBounce and bounced < 1 and pos.Y <= floorY and vel.Y < -0.5 then
			local drop = prev.Y - pos.Y
			local alpha = drop > 1e-4 and (prev.Y - floorY) / drop or 1
			alpha = math.clamp(alpha, 0, 1)
			pos = prev:Lerp(pos, alpha)
			pos = Vector3.new(pos.X, floorY + 0.02, pos.Z)
			local okb, bouncedVel = pcall(Physics.BounceVelocity, vel, upN, nil, upN, tuning)
			if okb and typeof(bouncedVel) == "Vector3" then
				vel = bouncedVel
			else
				vel = Vector3.new(vel.X, -vel.Y * 0.6, vel.Z)
			end
			bounced = bounced + 1
			pts[#pts + 1] = pos
			times[#times + 1] = t
		else
			local insertedHit = false
			if planePoint and planeNormal and not hit and (not doBounce or bounced >= 1) then
				local da = (prev - planePoint):Dot(planeNormal)
				local db = (pos - planePoint):Dot(planeNormal)
				if da * db <= 0 and math.abs(da - db) > 1e-4 then
					local alpha = da / (da - db)
					if alpha < 0 then
						alpha = 0
					elseif alpha > 1 then
						alpha = 1
					end
					hit = prev:Lerp(pos, alpha)
					hitT = t - step + step * alpha
					pts[#pts + 1] = hit
					times[#times + 1] = hitT
					insertedHit = true
				end
			end
			if not insertedHit then
				pts[#pts + 1] = pos
				times[#times + 1] = t
			end
			if hit then
				local depth = (hit - pos):Dot(planeNormal)
				if depth >= 4 or t - (hitT or t) >= 0.12 then
					break
				end
			elseif pos.Y <= floorY then
				break
			end
		end
	end
	return pts, hit or pts[#pts], hit ~= nil, times, hitT, bounced
end

local function wallBlocks(a, b, ignore)
	local parts = BarricadeStrikes.GetReplicatedBoundaryParts()
	if type(parts) ~= "table" then
		return false
	end
	local pad = Physics.BallRadius
	for i = 1, #parts do
		local part = parts[i]
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			if ignore and (part == ignore or part:IsDescendantOf(ignore)) then
				continue
			end
			local half = part.Size * 0.5 + Vector3.new(pad, pad, pad)
			if Physics.GetSegmentOrientedBoxEnterAlpha(a, b, part.CFrame, half) then
				return true
			end
		end
	end
	return false
end

local function flightBlocked(pts, ignore)
	if not pts or #pts < 2 then
		return false
	end
	local parts = Mark.boundParts
	if not parts or os.clock() - (Mark.boundAt or 0) > 0.5 then
		parts = BarricadeStrikes.GetReplicatedBoundaryParts()
		Mark.boundParts = parts
		Mark.boundAt = os.clock()
	end
	-- replicated boundary parts + placed barricades (workspace.Misc.Items PlacedItemId=barricades); every segment
	-- (the old stride 3 skipped two of three ~11-stud segments, walls in between were invisible)
	local all = {}
	if type(parts) == "table" then
		table.move(parts, 1, #parts, 1, all)
	end
	if Mark.wallParts then
		local placed = Mark.wallParts()
		table.move(placed, 1, #placed, #all + 1, all)
	end
	parts = all
	-- the placed barricade MODELS themselves (any part, any size): a ball-radius spherecast along every segment.
	-- Boundary parts alone missed low floor-skimming DIPs into a barricade.
	local models = Mark.wallModels
	if models and #models > 0 then
		local sp = Mark.wallSphere
		if not sp or Mark.wallSphereFor ~= models then
			sp = RaycastParams.new()
			sp.FilterType = Enum.RaycastFilterType.Include
			sp.FilterDescendantsInstances = models
			Mark.wallSphere = sp
			Mark.wallSphereFor = models
		end
		local r = Physics.BallRadius
		for i = 2, #pts do
			local a, b = pts[i - 1], pts[i]
			local d = b - a
			if d.Magnitude > 0.05 and Workspace:Spherecast(a, r, d, sp) then
				return true
			end
		end
	end
	if #parts == 0 then
		return false
	end
	local pad = Physics.BallRadius
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local segHalf = (b - a).Magnitude * 0.5
		for j = 1, #parts do
			local part = parts[j]
			if typeof(part) == "Instance" and part:IsA("BasePart") then
				if not (ignore and (part == ignore or part:IsDescendantOf(ignore))) then
					local mid = (a + b) * 0.5
					if (part.Position - mid).Magnitude <= part.Size.Magnitude * 0.5 + segHalf + pad + 1 then
						local half = part.Size * 0.5 + Vector3.new(pad, pad, pad)
						if Physics.GetSegmentOrientedBoxEnterAlpha(a, b, part.CFrame, half) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

local function keeperSide(mid, lateral, allowAlly)
	local side, best, y = 0, 1e9, nil
	Mark.gkRoot = nil
	local function take(model, r)
		if not (model and r) or model == LocalPlayer.Character then
			return
		end
		local tagged = model:GetAttribute("ActiveGoalkeeper") == true
		local actor = Actors.GetFromCharacter(model)
		if not tagged and actor then
			local ch = Actors.GetCharacter(actor)
			tagged = ch and ch:GetAttribute("ActiveGoalkeeper") == true
		end
		if actor and actor ~= LocalPlayer and not allowAlly and sameTeam(actor) then
			return
		end
		local rel = flat(r.Position - mid)
		if not tagged then
			-- NPC / bot keepers may not carry ActiveGoalkeeper: anyone standing in the mouth area counts, but a tagged
			-- keeper always wins (fallback is ranked behind by +100)
			local okF = rel.Magnitude < 14 and math.abs(rel:Dot(lateral)) < 24
			if not okF then
				return
			end
			rel = rel
			if rel.Magnitude + 100 >= best then
				return
			end
			best = rel.Magnitude + 100
			side = rel:Dot(lateral)
			y = r.Position.Y
			Mark.gkRoot = r
			Mark.gkTag = false
			return
		end
		if (best >= 100 or rel.Magnitude < best) and rel.Magnitude < 40 then
			Mark.gkTag = true
			best = rel.Magnitude
			side = rel:Dot(lateral)
			y = r.Position.Y
			Mark.gkRoot = r
		end
	end
	for _, model in Actors.GetAllCharacterModels() do
		local r = model:FindFirstChild("HumanoidRootPart")
		take(model, r)
	end
	local npcs = Workspace:FindFirstChild("Characters")
	npcs = npcs and npcs:FindFirstChild("NPCs")
	if npcs then
		for _, model in npcs:GetChildren() do
			if model:IsA("Model") then
				take(model, model:FindFirstChild("HumanoidRootPart"))
			end
		end
	end
	return side, y
end

local function shotLaunch(character, aim, reported, curve, launchPos)
	if not (character and aim) then
		return nil
	end
	local preview = Mark.pathPreview or require(Client.Gameplay.Actions.ChargePathPreview)
	Mark.pathPreview = preview
	local boundary = preview.GetChargeBoundaryWorld(LocalPlayer)
	local origin = launchPos or aim.Origin
	if origin and boundary and not (aim and aim.IsAirborne) then
		origin = Physics.GetContainedGroundPosition(origin, Physics.BallRadius, boundary) or origin
	end
	local kickDir = AimFacing.GetFlatDirection(aim.Direction)
	Shoot.solving = true
	local bound = if aim and aim.IsAirborne then nil else boundary -- was `and nil or`: always boundary, airborne shots got clamped
	local ok, vel = pcall(ChargePathVelocity.Get, character, KickCore.Constants.MaximumChargeSeconds, "Shot", aim, origin, reported, kickDir, nil, bound, curve)
	Shoot.solving = nil
	if not ok or typeof(vel) ~= "Vector3" then
		if not ok and os.clock() - (Shoot.velErrAt or 0) > 0.8 then
			Shoot.velErrAt = os.clock()
			dbg("shoot", "vel-err", tostring(vel))
		end
		return nil, origin
	end
	return vel, origin
end

local solveShotRaw
-- Time slicing. A full solve costs ~15-20 ms (log: shoot cost max 20.0ms) and ran every 0.12 s while we walk = a
-- frame hitch 8 times a second. Preview solves now run as a coroutine that yields inside packShot once the frame
-- slice (CFG.ShootSliceMs) is spent and resumes next frame; the old aim stays on screen meanwhile. Forced solves
-- (charge / release / G / flick) drop any running job and run synchronously: they need the exact current origin.
Shoot.slice = function()
	-- budget per frame; halved when the frame is already slow (Heartbeat dt > 12.5 ms = under 80 fps)
	if Shoot.inJob and os.clock() - Shoot.sliceAt > (CFG.ShootSliceMs or 0.9) * (Shoot.sliceBoost or 1) * ((Mark.dt or 0) > 0.0125 and 0.5 or 1) / 1000 then
		coroutine.yield()
	end
end
local function solveSliced(root, forced)
	if forced == "async" then
		if Shoot.job then
			Shoot.jobForced = true -- a running preview job becomes the forced one (its origin is still fresh)
		else
			Shoot.jobForced = true
		end
		forced = false
	elseif forced then
		Shoot.job = nil
		Shoot.inJob = false
		return solveShotRaw(root, true)
	else
		Shoot.jobForced = Shoot.jobForced and Shoot.job ~= nil
	end
	if Shoot.job and (os.clock() - Shoot.jobAt > 0.35 or (Shoot.jobArgs and Shoot.jobArgs ~= root)) then
		Shoot.job = nil -- origin went stale before the job finished: start over from the current pose
	end
	if not Shoot.job then
		Shoot.job = coroutine.create(solveShotRaw)
		Shoot.jobArgs = root
		Shoot.jobAt = os.clock()
	end
	Shoot.inJob = true
	Shoot.sliceAt = os.clock()
	local boost = Shoot.jobForced and 2.2 or 1
	Shoot.sliceBoost = boost
	local ok, a, b, c, d = coroutine.resume(Shoot.job, Shoot.jobArgs, Shoot.jobForced == true)
	Shoot.inJob = false
	if not ok then
		Shoot.job = nil
		Shoot.jobForced = false
		logFile("shoot", "job-err", tostring(a))
		return nil, nil, nil, "err"
	end
	if coroutine.status(Shoot.job) == "dead" then
		Shoot.job = nil
		Shoot.jobFrames = 0
		Shoot.jobForced = false
		return a, b, c, d
	end
	-- still running: keep showing the previous result
	if Shoot.aim then
		return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
	end
	return nil, nil, nil, Shoot.lastWhy or "solving"
end
local function solveShot(root, forced, ...)
	local t0 = os.clock()
	local a, b, c, d = solveSliced(root, forced)
	local ms = (os.clock() - t0) * 1000
	if CFG.Perf then
		Mark.perfAdd(forced == "async" and "solve-async" or (forced and "solve-forced" or "solve-slice"), ms)
	end
	if ms > 0.3 then
		Shoot.costN = (Shoot.costN or 0) + 1
		Shoot.costSum = (Shoot.costSum or 0) + ms
		Shoot.costMax = math.max(Shoot.costMax or 0, ms)
	end
	if os.clock() - (Shoot.costLog or 0) > 3 and (Shoot.costN or 0) > 0 then
		Shoot.costLog = os.clock()
		logFile("shoot cost", string.format("n %d avg %.1fms max %.1fms memo %d", Shoot.costN, Shoot.costSum / Shoot.costN, Shoot.costMax, Shoot.memoHit or 0))
		Shoot.costN, Shoot.costSum, Shoot.costMax, Shoot.memoHit = 0, 0, 0, 0
	end
	return a, b, c, d
end
solveShotRaw = function(root, forced)
	Shoot.lob = nil
	local goal = enemyGoalPart()
	if not goal then
		Shoot.preview = nil
		return nil, nil, nil, "no goal"
	end
	local lb, lt, rb, rt, _, face = goalMouthCorners(goal)
	if not lb or not lt then
		Shoot.preview = nil
		return nil, nil, nil, "no mouth"
	end
	local bottom = (lb + rb) * 0.5
	local bar = (lt + rt) * 0.5
	local rise = bar - bottom
	local ball = Renderer.GetPosition() or Renderer.GetMainMatchPosition()
	local origin = ball or (root.Position + Vector3.new(0, 2, 0))
	local up = rise.Magnitude > 0.4 and rise.Unit or Vector3.new(0, 1, 0)
	local mouth = bottom + up * math.min(1.35, math.max(rise.Magnitude * 0.2, 1.2))
	local delta = mouth - origin
	local flatD = flat(delta)
	local dist = flatD.Magnitude
	Shoot.dist = dist
	if dist < 6 then
		Shoot.preview = nil
		Shoot.aim = nil
		Shoot.point = nil
		Shoot.curve = nil
		return nil, nil, nil, "too close"
	end
	if dist > (CFG.ShootMaxDist or 160) then
		Shoot.preview = nil
		Shoot.aim = nil
		Shoot.point = nil
		Shoot.curve = nil
		Shoot.wire = nil
		return nil, nil, nil, "far"
	end
	local forward = flatD.Unit
	local character = LocalPlayer.Character
	local reported = flat(root.AssemblyLinearVelocity)
	local lateral = unitOrNil(flat(rt - lt)) or Vector3.new(1, 0, 0)
	local radius = Physics.BallRadius
	local tuning = character and Physics.GetCharacterTuning(character) or nil
	local mouthHalf = flat(rt - lt).Magnitude * 0.5
	local mouthH = math.max(rise.Magnitude, 1)
	local post = mouthHalf - radius - 0.3 -- +0.3 inset: two shots in the log hit the post / bar
	local low = bottom + up * math.clamp(mouthH * 0.4, radius + 1.1, math.max(mouthH - radius - 0.8, radius + 1.1))
	local keeper = keeperSide(low, lateral, goal:FindFirstAncestor("Practice") ~= nil)
	Mark.gkAhead = Mark.gkRoot and (Mark.gkRoot.Position - bottom):Dot(face) or 0
	local function at(h, side)
		return bottom + up * h + lateral * side
	end
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local bicycle = Mark.forceBike or (hum and BicycleKick.CanBicycleKick(character, hum)) or false
	local wantBand = "high"
	Shoot.wantBand = wantBand
	local moved = Shoot.solveAt and (origin - Shoot.solveAt).Magnitude or 99
	if not forced and Shoot.aim and Shoot.preview and moved < 0.2 and math.abs((Shoot.solveKeeper or 0) - keeper) < 2 then
		return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
	end
	if not forced and Shoot.aim and Shoot.preview and moved < 1.2 and os.clock() - (Shoot.solveT or 0) < 0.12 then
		return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
	end
	-- Throttle. A failed solve left Shoot.aim nil, which bypassed both caches above: with a moving player keeper
	-- (keeper side changes -> cache miss) and an empty pool the full candidate set ran EVERY frame. Plain solves at
	-- most every 0.12 s (0.25 s after a failure), forced re-solves every 0.08 s. One-shot G / flick plans are exempt.
	do
		local nowS = os.clock()
		local oneShot = Mark.forceBike or Mark.aerialContact
		local gapS = forced and 0.08 or (Shoot.aim and 0.2 or 0.3)
		if not oneShot and nowS - (Shoot.lastSolveAt or 0) < gapS then
			if Shoot.aim then
				return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
			end
			return nil, nil, nil, Shoot.lastWhy or "no vel"
		end
		Shoot.lastSolveAt = nowS
		Shoot.solveStart = nowS
	end
	if not Shoot.rollAt or (origin - Shoot.rollAt).Magnitude >= 4 then
		Shoot.roll = math.random()
		Shoot.fakeRoll = math.random()
		Shoot.fakeFirst = math.random()
		Shoot.bounceRoll = math.random()
		Shoot.rollAt = origin
	end
	local function inGoal(hit, crossed)
		if not (crossed and hit) then
			return false
		end
		local side = math.abs(flat(hit - low):Dot(lateral))
		local y = (hit - bottom):Dot(up)
		return side <= post and y >= 0.3 and y <= mouthH - radius
	end
	local function onKeeper(hit)
		if not hit then
			return true
		end
		local pointSide = flat(hit - low):Dot(lateral)
		if math.abs(pointSide) > post * 0.7 then
			return math.abs(pointSide - keeper) < 2
		end
		if math.abs(keeper) < 1.2 and math.abs(pointSide) < 3.2 then
			return true
		end
		return math.abs(pointSide - keeper) < 4.2
	end
	local pool = {}
	local fail = { vel = 0, cross = 0, block = 0, keeper = 0 }
	local stat = {}
	Mark.shotStat = stat
	Mark.shotFail = fail
	local function logFail()
		if os.clock() - (Shoot.failLog or 0) < 1.2 then
			return
		end
		Shoot.failLog = os.clock()
		logFile("shoot", "fail", "dist", string.format("%.0f", dist), "pool", tostring(#pool), "vel", tostring(fail.vel), "cross", tostring(fail.cross), "block", tostring(fail.block), "frame", tostring(fail.frame or 0), "keeper", tostring(fail.keeper), "bands", Mark.bandStat(stat))
	end
	local function holdShot()
		return Shoot.aim and (Shoot.locked or os.clock() - (Shoot.goodT or 0) < 0.5)
	end
	local approach = flat(origin - bottom):Dot(lateral)
	local shooterRight = Vector3.new(0, 1, 0):Cross(forward)
	shooterRight = shooterRight.Magnitude > 0.2 and shooterRight.Unit or lateral
	local rightDot = lateral:Dot(shooterRight)
	local nearSign = approach >= 0 and 1 or -1
	local farSign = -nearSign
	local angled = math.abs(approach) > 6
	Shoot.ang = approach
	local sides = { post, -post }
	local keeperSign = keeper > 1.2 and 1 or (keeper < -1.2 and -1 or 0)
	local awaySign = keeperSign ~= 0 and -keeperSign or farSign
	local flipSide = (Shoot.roll or 0.5) < 0.16
	local openSign = flipSide and -awaySign or awaySign
	local chargeSec = KickCore.Constants.MaximumChargeSeconds
	local start = origin
	if character then
		local Carry = Mark.carry or require(Modules.Ball.Carry)
		Mark.carry = Carry
		local launched = Carry.GetLaunchPosition(character, "Shot", nil, bicycle == true, 0)
		if typeof(launched) == "Vector3" then
			start = launched
		end
	end
	if Mark.volleyContact then
		-- legit volley / bicycle: shoot from the meet point of the incoming ball (tickVolley)
		start = Mark.volleyContact
	elseif Mark.aerial and Mark.aerialContact then
		-- planned airborne contact point from tickAerial (falling ball, after the no-touch apex)
		start = Mark.aerialContact
	elseif (Mark.flickAim or Mark.aerial) and character then
		Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
		local pop = Mark.flick.GetCharacterLaunch(character)
		if pop and typeof(pop.Position) == "Vector3" and typeof(pop.Velocity) == "Vector3" then
			local nt = Mark.flick.GetLaunchNoTouchSeconds(character) or 0.48
			local airPos = Physics.GetAirFlight(pop.Position, pop.Velocity, Vector3.zero, nt, tuning)
			if typeof(airPos) == "Vector3" then
				start = airPos
			end
		end
	end
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or start
	local function serverAim(dir, curve, fromBall)
		local aimOrigin = fromBall and start or camPos
		if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.2 then
			return nil, nil, start
		end
		local look = dir.Unit
		local aimTry = {
			Origin = aimOrigin,
			Direction = look,
			CameraCFrame = CFrame.lookAt(aimOrigin, aimOrigin + look),
			CameraFieldOfView = cam and cam.FieldOfView or nil,
			IsAirborne = bicycle == true or Mark.flickAim == true or Mark.aerial ~= nil,
		}
		local vel, launch = shotLaunch(character, aimTry, reported, curve, start)
		return aimTry, vel, launch or start
	end
	local function curveFor(side)
		if math.abs(side) < 2 then
			return (keeper * rightDot) >= 0 and 1 or -1
		end
		local onRight = side * rightDot >= 0
		return onRight and -1 or 1
	end
	local function packShot(dir, curve, bandName, fromBall)
		if (Shoot.sims or 0) >= (Shoot.simCap or 2) then
			return nil
		end
		Shoot.slice()
		Shoot.sims = (Shoot.sims or 0) + 1
		local aimTry, vel, launch = serverAim(dir, curve, fromBall)
		local isBounce = type(bandName) == "string" and string.sub(bandName, 1, 6) == "bounce"
		local isDip = bandName == "trickLow" or bandName == "dipCorner"
		local floorOk = isBounce or isDip or bandName == "flat" or bandName == "corner" or bandName == "fake"
		-- downward launches are legal from the air (G contact point) and for the floor-skimming dip
		local downOk = floorOk or Mark.aerial ~= nil or Mark.flickAim == true or Mark.forceBike == true
		if typeof(vel) ~= "Vector3" or vel.Magnitude <= 40 or (vel.Y < 1 and not downOk) then
			fail.vel = fail.vel + 1
			return nil
		end
		local spinTry = ShootMod.GetSpin(character, vel, reported, curve, chargeSec) or Vector3.zero
		local pts, hitTry, crossed, timesTry, hitT, bouncedN
		-- Game physics (Physics.NewState -> GoalkeeperPrediction.GetAnyGoalCrossing / Physics.GetStateAtTime through the
		-- charge boundary world): exact entry into the goal box with floor bounces, rolling and world solids. Our old
		-- 0.09 s linear sampler crossed the plane a stud off near the frame and could not do floor contact at all.
		local gameSim = false -- (the GetAnyGoalCrossing generator returned no crossing for every candidate and was removed: the sampler is the generator, GetAnyGoalCrossing only validates in insert())
		local memo = nil
		if not gameSim then
			local skim = isBounce or isDip
			-- Flight memo. The flight is a pure function of (launch, vel, spin, floor mode, goal plane): a moving player
			-- keeper invalidated the solve cache every frame and re-simulated identical flights. Keeper-dependent
			-- scoring (reach, onKeeper, earlyIntercept) still runs fresh on every solve.
			local function q(v)
				return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z)
			end
			local key = q(launch) .. "|" .. q(vel) .. "|" .. q(spinTry) .. (skim and "s" or "a") .. q(bottom)
			local store = Shoot.flightMemo
			if not store or Shoot.flightMemoN > 900 then
				store = {}
				Shoot.flightMemo = store
				Shoot.flightMemoN = 0
			end
			memo = store[key]
			if memo then
				Shoot.memoHit = (Shoot.memoHit or 0) + 1
				pts, hitTry, crossed, timesTry, hitT, bouncedN = memo.pts, memo.hit, memo.crossed, memo.times, memo.hitT, memo.bounced
			else
				pts, hitTry, crossed, timesTry, hitT, bouncedN = sampleFlight(launch, vel, spinTry, skim and bottom.Y or (root.Position.Y - 4), bottom, face, tuning, skim)
				memo = { pts = pts, hit = hitTry, crossed = crossed, times = timesTry, hitT = hitT, bounced = bouncedN }
				store[key] = memo
				Shoot.flightMemoN += 1
			end
		end
		if isBounce and (bouncedN or 0) < 1 then
			fail.cross = fail.cross + 1
			return nil
		end
		if not crossed or not hitTry then
			fail.cross = fail.cross + 1
			return nil
		end
		local y = (hitTry - bottom):Dot(up)
		local heightU = y / mouthH
		local band = bandName or (y >= 7.75 and "high" or (heightU >= 0.45 and "mid" or "low"))
		local pack = {
			aim = aimTry,
			vel = vel,
			from = launch,
			pts = pts,
			land = hitTry,
			times = timesTry,
			crossT = hitT or (timesTry and timesTry[#timesTry]),
			spin = spinTry,
			curve = curve,
			target = hitTry,
			band = band,
			hFrac = heightU,
			gap = (bar - hitTry):Dot(up),
			side = flat(hitTry - low):Dot(lateral),
			inside = inGoal(hitTry, crossed),
			bounced = bouncedN or 0,
			gameChecked = gameSim,
			memo = memo,
			fineTop = memo and memo.fineTop,
		}
		local peakY = launch.Y
		for i = 1, #pts do
			if pts[i].Y > peakY then
				peakY = pts[i].Y
			end
		end
		pack.peakY = peakY
		return pack
	end
	local function earlyIntercept(pack)
		local gk = Mark.gkRoot
		if not (gk and pack and pack.pts and pack.times) then
			return false
		end
		local gpos = gk.Position
		local hitT = pack.crossT or 9
		for i = 1, #pack.pts do
			local t = pack.times[i] or 0
			if t >= hitT - 0.08 then
				break
			end
			local p = pack.pts[i]
			if (p - bottom):Dot(face) > 5 then
				local d = flat(p - gpos).Magnitude
				if d < 3.2 and p.Y < gpos.Y + 7 then
					return true
				end
			end
		end
		return false
	end
	local function postOverflow(pack)
		if not (pack and pack.curve and pack.pts and pack.crossT) then
			return 0
		end
		local extra = 0
		for i = 1, #pack.pts do
			local t = pack.times and pack.times[i] or 0
			if t + 1e-4 >= pack.crossT then
				local s = math.abs(flat(pack.pts[i] - low):Dot(lateral))
				if s > post - 0.05 then
					extra = math.max(extra, s - (post - 0.05))
				end
			end
		end
		return extra
	end
	-- The game's own on-target test (Shoot getOnTargetColor): Physics.NewState + GoalkeeperPrediction.GetAnyGoalCrossing
	-- through the charge boundary world. Exact physics incl. world solids, so bar/post bounces and walls fail here
	-- instead of in our 0.09 s linear samples.
	Mark.pathPreview = Mark.pathPreview or require(Client.Gameplay.Actions.ChargePathPreview)
	local chkWorld = Mark.pathPreview.GetChargeBoundaryWorld(LocalPlayer)
	if not chkWorld then
		local _, w = Renderer.GetMovementState()
		chkWorld = w
	end
	Mark.gkPredMod = Mark.gkPredMod or require(Modules.Gameplay.GoalkeeperPrediction)
	local gameOnTargetRaw
	local function gameOnTarget(pack)
		local m = pack.memo
		if m and m.game ~= nil and m.gameBand == pack.band then
			return m.game
		end
		local r = gameOnTargetRaw(pack)
		if m then
			m.game, m.gameBand = r, pack.band
		end
		return r
	end
	gameOnTargetRaw = function(pack)
		if pack.gameChecked then
			return true
		end
		if not (chkWorld and pack.from and pack.vel) then
			return true
		end
		local t0 = Workspace:GetServerTimeNow()
		local okS, st = pcall(Physics.NewState, pack.from, pack.vel, Physics.BallRadius, t0, pack.spin or Vector3.zero)
		if not okS or type(st) ~= "table" then
			return true
		end
		st.LastKickerUserId = LocalPlayer.UserId
		local okC, p, t, afterFloor = pcall(Mark.gkPredMod.GetAnyGoalCrossing, st, chkWorld, { goal }, t0, 3)
		if not okC then
			if not Mark.onTgtErr or os.clock() - Mark.onTgtErr > 3 then
				Mark.onTgtErr = os.clock()
				logFile("shoot", "ontarget-err", tostring(p))
			end
			return true
		end
		if typeof(p) ~= "Vector3" then
			-- unreliable: the same call returned no crossing for every candidate when used as the generator
			return true
		end
		local dipish = pack.band == "trickLow" or pack.band == "dipCorner"
		local bounceish = pack.band == "bounceHigh" or pack.band == "bounceLow" or dipish
		if afterFloor and not bounceish then
			return false
		end
		if dipish and not afterFloor then
			Mark.dipWhy = "game-nofloor"
			return false
		end
		return true
	end
	-- Exact bar test: re-integrate the flight with Physics.GetAirFlight (same call as the sampler) at 0.02 s, then
	-- 0.004 s within a stud of the plane, and take the highest ball centre while the ball overlaps the plane
	-- (|depth| <= radius + 0.5). The 0.09 s chord + one-slope estimate let straight backspin shots (Magnus lift
	-- right at the line) pass under a bar they then hit.
	local function fineTop(pack)
		if pack.fineTop ~= nil then
			return pack.fineTop
		end
		if not (pack.from and pack.vel) or (pack.bounced or 0) > 0 then
			pack.fineTop = false
			return false
		end
		local pos, vel, sp = pack.from, pack.vel, pack.spin or Vector3.zero
		local top = nil
		local t = 0
		local limit = (pack.crossT or 2) + 0.3
		while t < limit do
			local depth = (pos - bottom):Dot(face)
			local dt = math.abs(depth) < radius + 4 and 0.004 or 0.02
			local np, nv, ns = Physics.GetAirFlight(pos, vel, sp, dt, tuning)
			if typeof(np) ~= "Vector3" then
				break
			end
			pos, vel, sp = np, nv or vel, ns or sp
			t += dt
			local d2 = (pos - bottom):Dot(face)
			if math.abs(d2) <= radius + 0.5 then
				local y = (pos - bottom):Dot(up)
				top = top and math.max(top, y) or y
			elseif d2 < -(radius + 0.5) then
				break
			end
		end
		pack.fineTop = top or false
		if pack.memo then
			pack.memo.fineTop = pack.fineTop
		end
		return pack.fineTop
	end
	-- DIP runs along the floor: anyone (not the keeper, reach model owns him) who can get his receive hitbox onto a
	-- low path sample before the ball does knocks it off. Time for him = reaction + run to (distance - body reach).
	local dipFoes = nil
	local function dipBlocked(pack)
		if not (pack.pts and pack.times) then
			return false
		end
		if not dipFoes then
			dipFoes = {}
			Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
			for _, model in Actors.GetAllCharacterModels() do
				local actor = Actors.GetFromCharacter(model)
				local r = actor and actor ~= LocalPlayer and not sameTeam(actor) and ActorTargeting.GetActorRoot(actor)
				if r and r ~= Mark.gkRoot then
					local okS, s = pcall(function()
						return Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(model), false)
					end)
					dipFoes[#dipFoes + 1] = { p = r.Position, v = flat(r.AssemblyLinearVelocity), s = okS and s or 26.9, name = actorName(actor) }
				end
			end
		end
		if #dipFoes == 0 then
			return false
		end
		local rcv = HitboxSettings.Receive
		local reachXZ = rcv.Size.X * 0.5 + radius
		local reachTop = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5 + radius + 1.5 -- small hop / stretch
		-- the foe has to see the kick (display delay + ping, ~0.1) and read a dipping ball, and nobody runs the straight
		-- line at full speed: 0.2 s / 100% made every low ball "blocked" in a crowd (log: dip:foe ... d4.6)
		local react = 0.32
		for i = 2, #pack.pts do
			local t = pack.times[i] or 0
			if pack.crossT and t >= pack.crossT then
				break
			end
			local q = pack.pts[i]
			if (q - bottom):Dot(face) > 2 then
				for _, f in dipFoes do
					local h = q.Y - f.p.Y
					if h <= reachTop then
						local guess = f.p + f.v * math.min(t, react)
						local need = math.max(flat(q - guess).Magnitude - reachXZ, 0)
						if need <= f.s * 0.85 * math.max(t - react, 0) then
							Mark.dipWhy = string.format("foe %s t%.2f d%.1f", tostring(f.name), t, flat(q - f.p).Magnitude)
							return true
						end
					end
				end
			end
		end
		return false
	end
	local function insert(pack)
		if not pack or not pack.inside then
			return false
		end
		local blocked
		local m = pack.memo
		if m and m.blockStamp == Mark.wallSig then
			blocked = m.blocked
		else
			blocked = pack.pts and flightBlocked(pack.pts, goal) or false
			if m then
				m.blocked, m.blockStamp, m.blockAt = blocked, Mark.wallSig, os.clock()
			end
		end
		if blocked then
			fail.block = fail.block + 1
			return false
		end
		if (pack.band == "trickLow" or pack.band == "dipCorner" or pack.band == "bounceLow") and dipBlocked(pack) then
			fail.foe = (fail.foe or 0) + 1
			return false
		end
		do
			local hb = pack.band
			if hb == "high" or hb == "trick" or hb == "airHigh" or hb == "mid" then
				local top = fineTop(pack)
				local margin = (Mark.forceBike and 1.5 or 1.05) - (hb == "trick" and 0.3 or 0)
				if top and mouthH - top < radius + margin then
					Mark.barWhy = string.format("fine %s %s top %.2f", hb, pack.curve and "spin" or "straight", mouthH - top)
					fail.bar = (fail.bar or 0) + 1
					return false
				end
			end
		end
		if not gameOnTarget(pack) then
			fail.frame = (fail.frame or 0) + 1
			return false
		end
		local bounceish = pack.band == "bounceHigh" or pack.band == "bounceLow"
		if bounceish or pack.band == "trickLow" or pack.band == "dipCorner" then
			local pointSide = flat(pack.land - low):Dot(lateral)
			local pad = bounceish and 1.2 or 2.2
			local gkY = Mark.gkRoot and Mark.gkRoot.Position.Y or 0
			local overDive = pack.land.Y - gkY > 7.75
			if not overDive and math.abs(pointSide - keeper) < pad then
				fail.keeper = fail.keeper + 1
				return false
			end
		elseif onKeeper(pack.land) then
			fail.keeper = fail.keeper + 1
			return false
		end
		if pack.curve and (pack.band == "trick" or pack.band == "trickLow") and not (pack.land and Mark.gkRoot and pack.land.Y - Mark.gkRoot.Position.Y > 7.75) and earlyIntercept(pack) then
			return false
		end
		pool[#pool + 1] = pack
		return true
	end
	local aimAndPackRaw
	local function aimAndPack(h, side, curve, band, fromBall)
		if (Shoot.sims or 0) >= 70 then
			return false
		end
		-- bicycle launch: a curled floor shot breaks (curl + bounce), floor shots go straight there
		if Mark.forceBike and (band == "trickLow" or band == "dipCorner") then
			return false
		end
		local st0 = stat[band or "-"] or { 0, 0 }
		stat[band or "-"] = st0
		st0[1] += 1
		local n0 = #pool
		-- own sim budget per candidate: the shared cap was eaten by the first iterating candidates, later HIGH / TRICK
		-- calls got packShot = nil (high0/3, trick0/4 with no fail reason) and DIP won by being alone in the pool
		local capSaved = Shoot.simCap
		local dipB = band == "trickLow" or band == "dipCorner" or band == "trick"
		Shoot.simCap = (Shoot.sims or 0) + (dist > 70 and 7 or (dipB and 7 or 5))
		local res = aimAndPackRaw(h, side, curve, band, fromBall)
		Shoot.simCap = math.max(capSaved or 0, Shoot.sims or 0)
		if #pool > n0 then
			st0[2] += 1
		end
		return res
	end
	aimAndPackRaw = function(h, side, curve, band, fromBall)
		local aimSide = side
		-- Long range: the ball drops ~0.5 * g * (dist / v)^2 (ball gravity 100, shot ~120 st/s) before the plane. The
		-- correction started at h and climbed +1.2 per miss under a mouthH + 14 ceiling, so past ~80 studs no
		-- iteration ever reached the plane and the pool stayed empty. Pre-lift the aim point by the extra drop beyond
		-- 70 studs and scale the ceiling / miss step with it.
		local lift = 0
		if dist > 70 and band ~= "trickLow" and band ~= "dipCorner" then
			lift = 0.5 * 100 * ((dist / 120) ^ 2 - (70 / 120) ^ 2)
		end
		local ceilH = mouthH + 14 + lift * 1.5
		local aimH = h + lift
		local last = nil
		local prevAim, prevLand = nil, nil
		local tight = math.abs(side) >= post * 0.8
		local function take(pack)
			if not (pack and pack.inside) then
				return false
			end
			local ly = (pack.land - bottom):Dot(up)
			if band == "high" and ly < 7.75 then
				pack.band = "mid"
				return insert(pack)
			end
			-- bar contact is judged by the game sim now (packShot): only keep the ball centre under the bar
			-- ball size at the bar: any sample within (radius + 1.5) of the goal plane whose centre is above
			-- bar - radius - margin touches the crossbar, even if the plane-crossing point itself is lower
			if (band == "high" or band == "trick" or band == "airHigh" or band == "bounceHigh") and pack.pts then
				-- TRICK is a dropping curl: v35 margin; the +0.3 of v36/v37 was for the straight HIGH shots that hit the bar
				-- and it closed the TRICK window (lo 9.0 .. hi bar - radius - 0.15 shrank under the bar check: trick0/N)
				local margin = (Mark.forceBike and 1.5 or 1.05) - (band == "trick" and 0.3 or 0)
				-- samples are ~11 studs apart: take the flight slope at the plane and the highest centre within
				-- +-(radius + 0.5) of the plane (a rising ball touches the bar just past the line)
				local k = #pack.pts
				for idx = 1, #pack.pts do
					if pack.pts[idx] == pack.land then
						k = idx
						break
					end
				end
				local prev = pack.pts[math.max(k - 1, 1)]
				local dd = math.abs((pack.land - prev):Dot(face))
				local slope = dd > 0.05 and ((pack.land - prev):Dot(up) / dd) or 0
				local topY = (pack.land - bottom):Dot(up) + math.max(slope, 0) * (radius + 0.5)
				if (mouthH - topY) < radius + margin then
					Mark.barWhy = string.format("%s top %.2f slope %.2f", band, mouthH - topY, slope)
					return false
				end
			end
			-- sampler error at the bar (0.09 s steps, ~11 studs) + bicycle launch uncertainty: keep a real margin
			if band == "high" and pack.gap and pack.gap < radius + (Mark.forceBike and 1.35 or 0.85) then
				return false
			end
			if band == "high" and math.abs(pack.side or 0) < post * 0.72 then
				return false
			end
			if band == "trick" then
				-- (old gate land.Y - keeperRootY > 7.75 left a ~0.1-stud window under the bar: TRICK never passed)
				if (pack.peakY or 0) < ly + 1.4 then
					Mark.trickWhy = string.format("peak %.1f ly %.1f", pack.peakY or 0, ly)
					return false
				end
				local lo = dist >= 58 and 7.8 or 8.8
				local hi = mouthH - radius - (Mark.forceBike and 1.5 or 0.75) - 0.05
				if ly < lo or ly > hi then
					Mark.trickWhy = string.format("win ly %.1f lo %.1f hi %.1f", ly, lo, hi)
					return false
				end
			end
			if band == "trick" and pack.gap and pack.gap < radius + (Mark.forceBike and 1.35 or 0.55) then
				return false
			end
			-- long range: the high curl may drop in wide of centre too
			-- TRICK is the central family now (user: "closer to the centre"): the old 0.45 / 0.8 let wide drops through
			if band == "trick" and math.abs(pack.side or 0) > post * (dist >= 55 and 0.5 or 0.32) then
				Mark.trickWhy = string.format("side %.1f", pack.side or 0)
				return false
			end
			-- trickLow (DIP): a curl driven into the floor, it skips up and enters low (game sim: entry after floor contact)
			if band == "trickLow" and (pack.bounced or 0) < 1 then
				Mark.dipWhy = string.format("nobounce vy%.0f", pack.vel and pack.vel.Y or -1)
				return false
			end
			if band == "trickLow" and (ly < 0.3 or ly > mouthH * 0.45) then
				Mark.dipWhy = string.format("h%.1f", ly)
				return false
			end
			-- DIP corner: same floor skim, but into the corner (open side, curl brings it in from outside the post)
			-- (the aim target is now post*0.92 - 0.5..1.2 inset, so the old |side| >= post*0.75 gate rejected the converged shot)
			if band == "dipCorner" and ((pack.bounced or 0) < 1 or ly < 0.3 or ly > mouthH * 0.45 or math.abs(pack.side or 0) < post * 0.62) then
				Mark.dipWhy = string.format("corner b%d h%.1f s%.1f", pack.bounced or 0, ly, pack.side or 0)
				return false
			end
			if band == "trickLow" and (math.abs(pack.side or 0) < post * 0.2 or math.abs(pack.side or 0) > post * 0.7) then
				Mark.dipWhy = string.format("side%.1f", pack.side or 0)
				return false
			end
			if band == "bounceHigh" and ly < 7.2 then
				return false
			end
			if band == "bounceLow" and (ly < 0.3 or ly > 5) then
				return false
			end
			if CFG.PreferCornerCurl and pack.curve and band ~= "trick" and math.abs(pack.side or 0) < post * 0.7 then
				return false
			end
			return insert(pack)
		end
			for _ = 1, ((curve or band == "trick" or band == "trickLow" or band == "dipCorner") and 5 or 3) + (lift > 0 and 2 or 0) do
			local point = at(aimH, aimSide)
			local org = fromBall and start or camPos
			local look = point - org
			if look.Magnitude < 1 then
				return false
			end
			local pack = packShot(look.Unit, curve, band, fromBall)
			if pack then
				-- the world point the ray was aimed THROUGH (+ where it started): lets Mark.rebaseAim keep the same
				-- shot geometry while the player moves between full re-solves
				pack.aimPoint = point
				pack.fromBall = fromBall
			end
			if not pack or not pack.land then
				if band == "trickLow" or band == "dipCorner" then
					-- no floor contact before the goal: drive it lower
					aimH = math.clamp(aimH - 2.5, -16, 3)
				else
					aimH = math.clamp(aimH + 1.2 + lift * 0.3, 0.6, ceilH)
				end
				continue
			end
			last = pack
			if take(pack) then
				return true
			end
			local y = (pack.land - bottom):Dot(up)
			local err = side - pack.side
			local extra = pack.curve and band ~= "trick" and postOverflow(pack) or 0
			local sgn = side >= 0 and 1 or -1
			-- slope of landing side vs aim side from the last two sims (a curl and a floor skim do not map 1:1: with the
			-- fixed gain 1 the DIP candidates stalled at 6.8 / 15.9 from the target in 3-5 sims = the dip:corner/side rejects)
			local gain = 1
			if prevAim and math.abs(aimSide - prevAim) > 0.05 then
				local sl = (pack.side - prevLand) / (aimSide - prevAim)
				if sl > 0.25 and sl < 4 then
					gain = 1 / sl
				end
			end
			prevAim, prevLand = aimSide, pack.side
			aimSide = aimSide + err * gain
			if extra > 0 then
				aimSide = aimSide - sgn * extra
			end
			if band == "trick" then
				-- aim at the middle of the window take() accepts (lo 7.8 / 9.0 .. bar - radius - 0.15)
				local want = ((dist >= 58 and 7.8 or 8.8) + (mouthH - radius - (Mark.forceBike and 1.5 or 0.75) - 0.05)) * 0.5
				aimH = math.clamp(aimH + (want - y) * 0.65, 0.6, mouthH + 3.2 + lift * 1.5)
			elseif band == "trickLow" or band == "dipCorner" then
				if (pack.bounced or 0) < 1 then
					aimH = math.clamp(aimH - 2.5, -16, 3)
				else
					aimH = math.clamp(aimH + (1.6 - y) * 0.7, -16, 3)
				end
			elseif band == "high" or tight then
				-- no ceiling on the AIM point: a long shot drops, aiming above the bar is what lands it in the top corner
				-- h sits inside the accept window: full-gain correction converges onto it
				aimH = math.clamp(aimH + (h - y), 0.6, ceilH)
			end
		end
		return take(last)
	end
	if character then
		-- 0.25 under the old target: server flight scatter put gap-1.6 shots on the bar (log: dist 76, gap 1.6, band high)
		-- target INSIDE the acceptance window: the old target (gap 1.35) sat under the reject line (radius + 0.85,
		-- bicycle radius + 1.35) so the correction converged onto rejects (G log: high0/3, bar:high top 1.6)
		local topH = mouthH - radius - (Mark.forceBike and 2.2 or 1.6)
		local curveH = topH
		local dipH = -4 -- aim point below the goal line: the curl hits the floor first (see take trickLow)
		local dipS = post * 0.45
		local function straightSide(sideSign)
			local closed = (sideSign * approach) > 0
			local add = 0.2
			if closed then
				add = add + math.clamp(math.abs(approach) * 0.12, 0, 1.2)
			else
				add = add + math.clamp(math.abs(approach) * 0.03, 0, 0.4)
			end
			return math.max(radius + 0.6, post - add)
		end
		local function curveWide(sideSign, amount)
			local add = 0.03 + math.abs(amount) * 0.06 + (dist >= 62 and 0.05 or 0) + (dist >= 70 and 0.05 or 0)
			if (sideSign * approach) > 0 then
				add = add + 0.05 + math.clamp(math.abs(approach) * 0.025, 0, 0.3)
			end
			return math.max(radius, post - add)
		end
		local amounts = (not Mark.flickAim and not Mark.aerial and not Mark.flickStrike) and CurvedKicks.IsEnabled() and dist > 16 and { 0.85, 0.65 } or nil
		local air = Mark.flickAim or Mark.aerial
		local far = dist >= 80
		Shoot.sims = 0
		Shoot.simCap = 8
		local roll = Shoot.roll or 0
		local sign = roll > 0.72 and -openSign or openSign
		if air then
			-- from the airborne contact point: straight shots into the four corners first (downward launches allowed)
			Shoot.simCap = 24
			aimAndPack(topH, sign * post * 0.85, nil, "airHigh", true)
			aimAndPack(topH, -sign * post * 0.85, nil, "airHigh", true)
			aimAndPack(1.6, sign * post * 0.85, nil, "airLow", true)
			aimAndPack(1.6, -sign * post * 0.85, nil, "airLow", true)
			if #pool == 0 then
				local depth = math.clamp(dist * 0.35, 8, 22)
				local band = roll < 0.45 and "bounceHigh" or "bounceLow"
				local aimFwd = unitOrNil(flat(bottom - start)) or forward
				local g = start + aimFwd * depth + lateral * sign * (post * 0.92)
				g = Vector3.new(g.X, bottom.Y + radius, g.Z)
				local look = g - start
				if look.Magnitude > 1 and look.Y < -0.08 then
					local pack = packShot(look.Unit, nil, band, true)
					if pack and pack.inside then
						insert(pack)
					end
				end
				if #pool == 0 and (Shoot.sims or 0) < 3 then
					local g2 = start + aimFwd * math.clamp(depth + 8, 12, 28) + lateral * -sign * (post * 0.92)
					g2 = Vector3.new(g2.X, bottom.Y + radius, g2.Z)
					local look2 = g2 - start
					if look2.Magnitude > 1 and look2.Y < -0.08 then
						local pack2 = packShot(look2.Unit, nil, band == "bounceHigh" and "bounceLow" or "bounceHigh", true)
						if pack2 and pack2.inside then
							insert(pack2)
						end
					end
				end
			end
		else
			local band = Shoot.wantBand or "high"
			local h = mouthH - radius - 0.3
			local curve = amounts and (0.85 * curveFor(sign * post)) or nil
			local sideAmt = post * 0.92
			if band == "trickLow" and amounts then
				h = dipH
				sideAmt = dipS
			elseif band == "trick" and amounts then
				h = math.clamp(mouthH * 0.72, 7.2, mouthH - radius - 0.2)
				sideAmt = post * 0.2
			elseif band == "corner" and amounts then
				h = 1.2
				curve = 0.65 * curveFor(sign * post)
				sideAmt = post * 0.94
			elseif not amounts then
				band = "high"
				curve = nil
			end
			aimAndPack(h, sign * sideAmt, curve, band, false)
			if amounts and (Shoot.sims or 0) < (Shoot.simCap or 8) then
				aimAndPack(dipH, -sign * dipS, 0.85 * curveFor(-sign * post), "trickLow", false)
			end
			if #pool == 0 and (Shoot.sims or 0) < 5 then
				local alt = (band == "trickLow" or band == "corner") and "high" or "trickLow"
				aimAndPack(alt == "trickLow" and dipH or topH, -sign * (alt == "trickLow" and dipS or post * 0.92), amounts and (0.85 * curveFor(-sign * post)) or nil, alt, false)
			end
		end
		if #pool == 0 then
			Shoot.sims = 0
			Shoot.simCap = 4
		else
			-- the primary pair found shots: still give the high TRICK curls their own sims (they were starved: cap 0)
			Shoot.simCap = (Shoot.sims or 0) + ((amounts and not air) and 6 or (air and 10 or 0))
		end
		local function packHighCurves(amount)
			if not amounts then
				return
			end
			for s = 1, #sides do
				local sign = sides[s] >= 0 and 1 or -1
				local cw = curveWide(sign, amount)
				if cw then
					aimAndPack(curveH, sign * cw, amount * curveFor(sign * post), "high", false)
				end
			end
		end
		if not air then
			if amounts then
				local tSign = openSign
				local trickH = math.clamp(mouthH * 0.72, 7.2, mouthH - radius - 0.2)
				local trickBend = 0.85 * curveFor(tSign * post)
				-- DIP corner into the open side (the far side from a tight angle / away from the keeper)
				-- DIP corner: 0.5 further from the post, and more when the corner is CLOSED for us (we stand on the same
				-- side as the target corner: the ball runs along the post line; log: DIP hit the post from that side)
				local dipInset = 0.5 + 0.7 * math.clamp(openSign * approach / 15, 0, 1)
				aimAndPack(dipH, openSign * math.max(post * 0.92 - dipInset, post * 0.5), 0.85 * curveFor(openSign * post), "dipCorner", false)
				if dist >= 55 then
					-- long range: launched over the bar height, the curl drops it into the upper part wide of centre
					aimAndPack(mouthH + 2, tSign * post * 0.36, trickBend, "trick", false)
					aimAndPack(mouthH + 2, -tSign * post * 0.36, -trickBend, "trick", false)
				end
				aimAndPack(trickH, tSign * post * 0.2, trickBend, "trick", false)
				aimAndPack(math.min(trickH + 2.4, mouthH + 1.5), -tSign * post * 0.15, -trickBend, "trick", false)
			end
			packHighCurves(0.85)
			if amounts then
				for s = 1, #sides do
					local sign = sides[s] >= 0 and 1 or -1
					aimAndPack(dipH, sign * dipS, 0.85 * curveFor(sign * post), "trickLow", false)
				end
			end
			if #pool == 0 then
					if not amounts then -- the trickLow pass above only ran with amounts
						for s = 1, #sides do
							local sign = sides[s] >= 0 and 1 or -1
							aimAndPack(dipH, sign * dipS, 0.85 * curveFor(sign * post), "trickLow", false)
						end
					end
					for s = 1, #sides do
						local sign = sides[s] >= 0 and 1 or -1
						local cw0 = curveWide(sign, 0.65)
						if cw0 then
							aimAndPack(1.2, sign * cw0, 0.65 * curveFor(sign * post), "corner", false)
						end
						end
						if not far or #pool == 0 then
					packHighCurves(0.65)
					for s = 1, #sides do
						local sign = sides[s] >= 0 and 1 or -1
						local sw = straightSide(sign)
						aimAndPack(topH, sign * sw, nil, "high", false)
						if dist < 28 then
							aimAndPack(0.9, sign * sw, nil, "flat", true)
						end
					end
				end
			end
		end
		if Mark.flickAim or Mark.aerial or Mark.forceBike then
			local fwd = unitOrNil(flat(bottom - start))
			-- floor-bounce shots get their own sims (they were starved by the shared cap)
			Shoot.simCap = (Shoot.sims or 0) + 22
			if fwd then
				-- Floor ricochets, scanned relative to the distance (old fixed 5..46-stud floor points bounced most shots
				-- far short of a 50+ stud goal: second floor contact, no crossing). Straight only (curl + bounce breaks).
				-- Entry height decides the label: upper half bounceHigh, lower part bounceLow.
				local gDist = flat(bottom - start).Magnitude
				-- The game lifts every shot (aim -0.09 -> launch vdir +0.31 in the log), so a floor point aimed from the
				-- ball never gets hit (bounce0/18, all c). Aim the camera ray below the goal line like DIP: the scan
				-- over aim depth finds where the lifted shot lands short of the goal and skips in. Straight only.
				local function packBounces(towardSign)
					local offsets = { towardSign * post * 0.8, -towardSign * post * 0.8 }
					for _, aimDown in { -3, -6, -9, -13, -18 } do
						for o = 1, #offsets do
							local point = at(aimDown, offsets[o])
							local look = point - camPos
							if look.Magnitude > 1 then
								local pack = packShot(look.Unit, nil, "bounceLow", false)
								local sb = stat.bounce or { 0, 0 }
								stat.bounce = sb
								sb[1] += 1
								if pack and pack.inside and (pack.bounced or 0) >= 1 then
									local ly = (pack.land - bottom):Dot(up)
									local ok = false
									if ly >= mouthH * 0.55 and (mouthH - ly) >= radius + (Mark.forceBike and 1.35 or 0.85) then
										pack.band = "bounceHigh"
										ok = insert(pack)
									elseif ly >= 0.3 and ly <= mouthH * 0.45 then
										ok = insert(pack)
									end
									if ok then
										sb[2] += 1
									end
								end
							end
						end
					end
				end
				local _ = gDist
				packBounces(openSign)
				if #pool == 0 then
					local farW = straightSide(openSign)
					local nearW = straightSide(-openSign)
					aimAndPack(topH, openSign * farW, nil, "high", true)
					aimAndPack(topH, -openSign * nearW, nil, "high", true)
				end
			end
		end
		if not air and dist <= 50 and #pool == 0 then
		Mark.passMod = Mark.passMod or require(Modules.Actions.Pass)
		local lobTimes = { 0.22 }
		local lobSide = openSign * post
		local lobPoint = bottom + up * math.clamp(mouthH * 0.55, 4.5, topH - 2.2) + lateral * lobSide
		local lobDir = unitOrNil(flat(lobPoint - start))
		if lobDir then
			local lobAim = {
				Origin = start,
				Direction = lobDir,
				CameraCFrame = CFrame.lookAt(start, start + lobDir),
			}
			for i = 1, #lobTimes do
				local secs = lobTimes[i]
				local lobVel = Mark.passMod.GetVelocity(character, secs, "FreeLobPass", lobAim, nil, reported, nil)
				if typeof(lobVel) == "Vector3" and lobVel.Magnitude > 20 then
					local lobSpin = Mark.passMod.GetSpin(character, lobVel, "FreeLobPass", reported) or Vector3.zero
					local lobPts, lobHit, lobIn, lobFlight = sampleFlight(start, lobVel, lobSpin, root.Position.Y - 4, bottom, face, tuning)
					local prev = lobPts and lobPts[#lobPts - 1]
					local dropping = prev and lobHit and prev.Y > lobHit.Y + 0.6
					local gap = lobHit and (bar - lobHit):Dot(up) or 0
					if dropping and gap >= radius + 1.6 and not flightBlocked(lobPts, goal) and inGoal(lobHit, lobIn) then
						local y = (lobHit - bottom):Dot(up)
						pool[#pool + 1] = {
							aim = lobAim,
							vel = lobVel,
							from = start,
							pts = lobPts,
							land = lobHit,
							times = lobFlight,
							spin = lobSpin,
							curve = nil,
							target = lobHit,
							lob = true,
							chipSec = secs,
							band = "chip",
							hFrac = y / mouthH,
							gap = gap,
							side = flat(lobHit - low):Dot(lateral),
							inside = true,
						}
						break
					end
				end
			end
		end
		end
		Shoot.lobWhy = "no"
		for i = 1, #pool do
			if pool[i].lob then
				Shoot.lobWhy = "in"
				break
			end
		end
		local farW = math.clamp((dist - 28) / 55, 0, 1)
		local closeW = math.clamp((24 - dist) / 14, 0, 1)
		local hasCurve = false
		for i = 1, #pool do
			if pool[i].curve then
				hasCurve = true
				break
			end
		end
		-- Keeper reach along the WHOLE flight (he sees the trajectory preview, so assume perfect read after a human
		-- reaction). For every flight sample before the goal plane: the fastest way he can touch it
		--   walk  : Receive hitbox (grounded) at Humanoid.WalkSpeed
		--   jump  : walk + rise, GoalkeeperAirReceive (Receiving.GetReceiveHitbox for an airborne keeper)
		--   dive  : GoalkeeperDive.GetCurveSecondsForTravel(gap - SaveReachStuds, GetDistance), height capped by
		--           GoalkeeperDiveAssist.GetReachableContactHeight and MaximumSaveHeight
		-- margin = min over samples (react + need - t). > 0: no sample is reachable in time.
		local diveMod = Mark.gkDiveMod or require(Modules.Actions.GoalkeeperDive)
		Mark.gkDiveMod = diveMod
		local assist = Mark.gkAssist
		if assist == nil then
			local okA, modA = pcall(function()
				return require(Modules.Actions.GoalkeeperDiveAssist)
			end)
			assist = okA and modA or false
			Mark.gkAssist = assist
		end
		local gkRoot = Mark.gkRoot
		local gkModel = gkRoot and gkRoot.Parent
		local gkHum = gkModel and gkModel:FindFirstChildOfClass("Humanoid")
		local gkWalk = gkHum and gkHum.WalkSpeed or 16
		if gkWalk < 8 then
			gkWalk = 16
		end
		local gkD = diveMod.Constants.Distance
		local gkActor = gkModel and Actors.GetFromCharacter(gkModel)
		if gkActor then
			local okD, d = pcall(diveMod.GetDistance, gkActor)
			if okD and type(d) == "number" then
				gkD = d
			end
		end
		local saveReach = diveMod.Constants.SaveReachStuds
		local maxSave = diveMod.Constants.MaximumSaveHeight
		local rcv = HitboxSettings.Receive
		local airR = HitboxSettings.GoalkeeperAirReceive
		local bodyR = rcv.Size.X * 0.5 + radius
		local groundTop = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5 + radius
		local airTop = airR.CFrameOffset.Y + airR.Size.Y * 0.5 + radius
		local jumpH = Mark.jumpH or 7.2
		local gkReact = CFG.GkReactSeconds
		local function reachMargin(p)
			if p.reach then
				return p.reach
			end
			if not (gkRoot and p.pts and p.times) then
				p.reach = 1
				return 1
			end
			local g0 = gkRoot.Position + flat(gkRoot.AssemblyLinearVelocity) * gkReact
			local hitT = p.crossT or math.huge
			local worst = math.huge
			for i = 1, #p.pts do
				local t = p.times[i] or 0
				if t > hitT + 0.02 then
					break
				end
				local q = p.pts[i]
				if (q - bottom):Dot(face) > -0.5 then
					local g = flat(q - g0).Magnitude
					local h = q.Y - gkRoot.Position.Y
					local walk = math.max(g - bodyR, 0) / gkWalk
					local need = math.huge
					if h >= -3 and h <= groundTop then
						need = walk
					elseif h > groundTop and h <= airTop + jumpH then
						need = walk + Mark.riseT(math.max(h - airTop + 0.5, 0.3))
					end
					if h >= -2 then
						-- dive from where he stands, or walk until the point is inside dive range and then dive
						local walkIn = math.max(g - (gkD + saveReach), 0) / gkWalk
						local curve = diveMod.GetCurveSecondsForTravel(math.clamp(g - saveReach, 0, gkD), gkD)
						local top = assist and assist.GetReachableContactHeight(curve, h) or maxSave
						if h <= math.min(top, maxSave) then
							need = math.min(need, walkIn + curve)
						end
					end
					worst = math.min(worst, gkReact + need - t)
				end
			end
			p.reach = (worst == math.huge) and 1 or worst
			return p.reach
		end
		local function weigh(p)
			if onKeeper(p.land) then
				return 0
			end
			local hitY = p.land and (p.land - bottom):Dot(up) or 0
			local hitSide = p.side or 0
			if p.curve and math.abs(hitSide) >= 2 then
				local onRight = hitSide * rightDot >= 0
				local same = (onRight and p.curve > 0) or ((not onRight) and p.curve < 0)
				if same then
					return 0
				end
			end
			if dist > 50 and hitY < 7.2 and not p.lob and not p.curve and p.band ~= "bounceLow" and p.band ~= "trickLow" then
				return 0
			end
			local w = 1
			if dist >= 50 and p.gap and p.gap < 2.2 then
				w = w * 0.2
			end
			if p.curve then
				w = w + 3 + farW * 4
			elseif hasCurve and not p.lob and p.band ~= "flat" then
				return 0
			elseif hasCurve and dist > 40 then
				w = w * 0.08
			end
			if closeW > 0 and hitY > 7.75 and p.gap and p.gap < 1.6 then
				w = w + 8 * closeW
			end
			if math.abs(hitSide) < post * 0.55 and p.band ~= "trick" and p.band ~= "trickLow" then
				w = w * 0.22
			elseif math.abs(hitSide) > post * 0.78 then
				w = w + 18
			end
			if p.curve and p.band == "high" and math.abs(hitSide) > post * 0.75 then
				w = w + 12
				if math.abs(approach) > 10 and keeper * approach > 0 and hitSide * approach < 0 then
					w = w + (Shoot.roll > 0.42 and 16 or 5)
				end
			elseif math.abs(hitSide) > post * 0.9 and (hitY > 7.75 or hitY < 2.2) then
				w = w + 1.5
			end
			if CFG.PreferCornerCurl and p.curve and math.abs(hitSide) > post * 0.7 then
				w = w + 22
			end
			if p.band == "corner" and p.curve then
				w = w + 10
			end
			if hitY > 2.8 and hitY < 7.75 and p.band ~= "bounceLow" and p.band ~= "trickLow" and p.band ~= "trick" then
				w = w * 0.08
			end
			if hitSide * openSign > 1.5 then
				w = w + 16
			elseif hitSide * openSign < -1.5 and hitY < 8.2 then
				w = w * 0.32
			end
			if Shoot.lastSide and hitSide * Shoot.lastSide > 1.5 and hitSide * openSign < 0 then
				w = w * 0.7
			end
			if p.lob then
				w = w + ((Mark.gkAhead or 0) > 2 and 9 or 0.4)
			end
			if p.band == "flat" then
				w = w + (dist > 50 and 0 or 2)
			end
			if p.band == "trick" then
				w = w + 6
			end
			if p.band == "trickLow" then
				w = w + 5
			end
			if hitY > 7.75 then
				w = w + 6
			end
			if Shoot.band and p.band == Shoot.band and p.band ~= "high" and p.band ~= "trick" then
				w = w * 0.2
			end
			if p.band == "bounceHigh" then
				if angled and hitSide * nearSign > 1 then
					return 0
				end
				w = w + 22
				if hitSide * openSign > 0 then
					w = w + 10
				end
			end
			if p.band == "bounceLow" then
				w = w + 20
			end
			if p.band == "over" and math.abs(hitSide) < post * 0.8 then
				w = w * 0.15
			end
			return math.max(w, 0.05)
		end
		pool = Mark.shotFilter(pool)
		local weights = {}
		local pickFrom = pool
		if Mark.flickAim then
			local highs = {}
			local lows = {}
			for i = 1, #pool do
				if pool[i].band == "bounceHigh" then
					highs[#highs + 1] = pool[i]
				elseif pool[i].band == "bounceLow" then
					lows[#lows + 1] = pool[i]
				end
			end
			if #highs > 0 then
				pickFrom = highs
			elseif #lows > 0 then
				pickFrom = lows
			else
				local directs = {}
				for i = 1, #pool do
					if pool[i].band ~= "bounceHigh" and pool[i].band ~= "bounceLow" then
						directs[#directs + 1] = pool[i]
					end
				end
				pickFrom = directs
			end
		elseif CFG.OnlyTrick then
			local tricks = {}
			for i = 1, #pool do
				if pool[i].band == "trick" or pool[i].band == "trickLow" then
					tricks[#tricks + 1] = pool[i]
				end
			end
			if #tricks > 0 then
				pickFrom = tricks
			end
		elseif CFG.PreferCornerCurl then
			local wide = {}
			local bestS = -1
			local widest = {}
			for i = 1, #pool do
				local p = pool[i]
				if p.curve then
					local s = math.abs(p.side or 0)
					if (p.band == "high" or p.band == "corner") and s > post * 0.7 then
						wide[#wide + 1] = p
					end
					if s > bestS + 0.05 then
						bestS = s
						widest = { p }
					elseif s >= bestS - 0.05 then
						widest[#widest + 1] = p
					end
				end
			end
			pickFrom = #wide > 0 and wide or widest
			if #pickFrom == 0 then
				pickFrom = pool
			end
		else
			pickFrom = pool
		end
		-- weigh() vetoes (explicit 0: wrong-way curve, keeper body, ...). Among the rest keep the full 0.85 bend when
		-- such shots exist (one consistent hard curl), then keeper reach decides.
		local base, curled = {}, {}
		for i = 1, #pickFrom do
			weights[i] = weigh(pickFrom[i])
			Shoot.slice()
			reachMargin(pickFrom[i])
			if weights[i] > 0 then
				base[#base + 1] = pickFrom[i]
				if pickFrom[i].curve and math.abs(pickFrom[i].curve) >= 0.8 then
					curled[#curled + 1] = pickFrom[i]
				end
			end
		end
		if #base == 0 then
			base = pickFrom
		end
		if #curled > 0 and not (Mark.flickAim or Mark.aerial) then
			base = curled
		end
		-- high or low, not mid: mid height is where the keeper's body and dive are
		do
			local hl = {}
			for i = 1, #base do
				local p = base[i]
				local y = p.land and (p.land - bottom):Dot(up) or 0
				if y >= mouthH * 0.6 or y <= mouthH * 0.35 then
					hl[#hl + 1] = p
				end
			end
			if #hl > 0 then
				base = hl
			end
		end
		local bestM, openN = -math.huge, 0
		for i = 1, #base do
			local m = base[i].reach or -math.huge
			bestM = math.max(bestM, m)
			if m >= CFG.ShotReachMargin then
				openN += 1
			end
		end
		-- one candidate per shot type (its best reach), every type within 0.15 s of the best stays in the roll:
		-- the reach model alone always crowned the same low type
		local band = {}
		local perBand = {}
		-- corner shots: the one that crosses closest to the corner (not one that bends in a stud short of it)
		local function cornerGap(p)
			local y = p.land and (p.land - bottom):Dot(up) or 0
			return math.max(post - math.abs(p.side or 0), 0) + math.max((mouthH - radius) - y, 0) * 0.5
		end
		for i = 1, #base do
			local p = base[i]
			local k = (p.band or "-") .. ((p.side or 0) >= 0 and "+" or "-")
			local cur = perBand[k]
			if not cur then
				perBand[k] = p
			elseif p.band == "high" or p.band == "corner" then
				if cornerGap(p) < cornerGap(cur) - 0.05 then
					perBand[k] = p
				end
			elseif (p.reach or -math.huge) > (cur.reach or -math.huge) then
				perBand[k] = p
			end
		end
		local floorM = bestM >= CFG.ShotReachMargin and math.max(CFG.ShotReachMargin, bestM - 0.15) or bestM - 0.15
		for _, p in perBand do
			if (p.reach or -math.huge) >= floorM then
				band[#band + 1] = p
			end
		end
		-- Side preference: the far side of a tight angle and the side away from the keeper are the open goal. The near
		-- corner from a tight angle is a sliver (curl overruns into the post) and sits next to the keeper.
		local famN = {}
		for i = 1, #band do
			local k = band[i].band or ""
			famN[k] = (famN[k] or 0) + 1
		end
		local function sideW(p)
			local s = p.side or 0
			local w = 1
			if math.abs(approach) > 6 then
				local tight = math.clamp((math.abs(approach) - 6) / 10, 0, 1)
				if s * approach > 0 then
					w *= 1 - 0.75 * tight
				else
					w *= 1 + 0.8 * tight
				end
			end
			if math.abs(keeper) > 1.5 then
				w *= (s * keeper > 0) and 0.45 or 1.4
			end
			-- shot-type mix: TRICK had two slots (both sides) and crowded everything else out
			-- each shot family gets a fixed share no matter how many side variants it has in the roll
			-- (DIP was 0.25 / 0.18 against HIGH 1.0: with the families' side variants that was ~5% of the shots, then the
			-- foe filter removed most of those; the user read the result as "always the same shot")
			local typeW = { high = 1, airHigh = 1, dipCorner = 0.6, trickLow = 0.45, trick = 0.8, bounceHigh = 0.9, bounceLow = 0.9, corner = 0.65, airLow = 0.8 }
			w *= (typeW[p.band or ""] or 0.6) / (famN[p.band or ""] or 1) * ((CFG.ShotWeight and CFG.ShotWeight[(p.band == "mid" and "high") or p.band or ""]) or 1)
			-- variety: what was used in the last shots is less likely again (same family x0.55 each, same family+side x0.8 more)
			local hist = Mark.shotHist
			if hist then
				local ps = s >= 0 and 1 or -1
				for hi = 1, #hist do
					local hh = hist[hi]
					local rec = hi > #hist - 3
					if rec and hh.band == p.band then
						w *= 0.55
						if hh.side == ps then
							w *= 0.8
						end
					end
				end
			end
			return w
		end
		table.sort(band, function(x, y)
			return (x.reach or 0) > (y.reach or 0)
		end)
		local totalW = 0
		for i = 1, #band do
			band[i].pickW = sideW(band[i])
			totalW += band[i].pickW
		end
		if totalW > 0 then
			local r = (Shoot.roll or 0) * totalW
			for i = 1, #band do
				r -= band[i].pickW
				if r <= 0 then
					band = { band[i] }
					break
				end
			end
		end
		if #band == 0 then
			band = base
		end
		Shoot.reachOpen = bestM >= CFG.ShotReachMargin
		Shoot.reachN = string.format("%d/%d/%d", openN, #base, #pickFrom)
		local bi = math.clamp(math.floor((Shoot.roll or 0) * #band) + 1, 1, math.max(#band, 1))
		local best = band[bi]
		local picked = best
		-- FAKE: a flight through a teammate in front of goal (CFG.FakeShot). Rolled once per shot like Shoot.roll; when the
		-- normal pool is empty it is used as a fallback.
		Mark.fakeWhy = nil
		local banned = Mark.fakeBan()
		if banned then
			Mark.fakeWhy = "off: " .. banned
		elseif not (Mark.flickAim or Mark.aerial or Mark.flickStrike or Mark.forceBike) then
			local ctx = {
				Shoot = Shoot, start = start, camPos = camPos, bottom = bottom, face = face, lateral = lateral, low = low, up = up,
				radius = radius, post = post, mouthH = mouthH, packShot = packShot, root = root, goal = goal, world = chkWorld, fail = fail,
			}
			local order = {}
			if CFG.BounceFAKE ~= false and CFG.PriorityBounceFAKE then
				order[#order + 1] = { "b", true }
			end
			if CFG.FakeShot ~= false and CFG.PriorityFAKE then
				order[#order + 1] = { "f", (Shoot.fakeFirst or 0) < (CFG.FakeFirstChance or 0.85) }
			end
			if CFG.BounceFAKE ~= false and not CFG.PriorityBounceFAKE then
				order[#order + 1] = { "b", false }
			end
			if CFG.FakeShot ~= false then
				order[#order + 1] = { "f", picked == nil }
			end
			local notes = {}
			for _, o in order do
				ctx.force = o[2]
				local fp, why
				if o[1] == "b" then
					fp, why = Mark.bounceFake(ctx)
				elseif dist >= 12 then
					fp, why = Mark.fakeShot(ctx)
				end
				if why then
					notes[#notes + 1] = (o[1] == "b" and "bounce " or "mate ") .. why
				end
				if fp then
					picked, best = fp, fp
					break
				end
			end
			Mark.fakeWhy = table.concat(notes, " ; ")
		end
		Shoot.reachM = picked and picked.reach
		Shoot.keeperS = keeper
		Shoot.keeperTag = Mark.gkRoot and (Mark.gkTag and "tag" or "npc") or "none"
		if not picked then
			if holdShot() then
				return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
			end
			local bounceKeep = Shoot.aim and (Shoot.band == "bounceHigh" or Shoot.band == "bounceLow")
			if (Mark.keepAim or Mark.flickAim or Mark.aerial or Mark.flickStrike) and bounceKeep and Shoot.solveAt and (origin - Shoot.solveAt).Magnitude < 0.35 then
				return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
			end
			if Mark.flickAim or Mark.aerial or Mark.flickStrike then
				Shoot.aim = nil
				Shoot.curve = nil
				Shoot.preview = nil
				Shoot.solveT = os.clock()
				Shoot.solveVel = reported
				return nil, nil, nil, "no vel"
			end
			logFail()
			Shoot.preview = nil
			Shoot.point = nil
			Shoot.curve = nil
			Shoot.aim = nil
			Shoot.hold = nil
			Shoot.hFrac = nil
			Shoot.gap = nil
			Shoot.band = nil
			Shoot.shotName = nil
			Shoot.poolN = #pool
			Shoot.solveAt = origin
			Shoot.solveKeeper = keeper
			Shoot.solveT = os.clock()
			return nil, nil, nil, "no vel"
		end
		if not picked.inside then
			if holdShot() then
				return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
			end
			if Mark.keepAim and Shoot.aim and Shoot.solveAt and (origin - Shoot.solveAt).Magnitude < 0.35 then
				return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
			end
			logFail()
			Shoot.preview = nil
			Shoot.point = nil
			Shoot.curve = nil
			Shoot.aim = nil
			Shoot.poolN = #pool
			Shoot.solveAt = origin
			Shoot.solveKeeper = keeper
			Shoot.solveT = os.clock()
			return nil, nil, nil, "no vel"
		end
		Shoot.solveAt = origin
		Shoot.solveKeeper = keeper
		Shoot.solveT = os.clock()
		Shoot.solveVel = reported
		local aim = picked.aim
		local shown = picked.vel
		local kickDir = AimFacing.GetFlatDirection(aim.Direction) or forward
		local curve = picked.curve
		local spin = picked.spin
		local flight = picked.pts
		local hit = picked.land
		local times = picked.times
		if not picked.bfake and flightBlocked(flight, goal) then
			Shoot.preview = nil
			Shoot.point = nil
			Shoot.curve = nil
			return nil, nil, nil, "wall"
		end
		if not (flight and #flight >= 2) or not hit then
			Shoot.preview = nil
			Shoot.point = nil
			Shoot.curve = nil
			return nil, nil, nil, "frame"
		end
		Shoot.shotName = picked.lob and "LOB" or (picked.band == "flat" and "FLAT" or (picked.band == "trick" and "TRICK" or (picked.band == "trickLow" and "DIP" or (picked.band == "dipCorner" and "DIP CORNER" or (picked.band == "bounceHigh" and "HIGH" or (picked.band == "bounceLow" and "LOW" or (picked.curve and "SPIN" or "STRAIGHT")))))))
		if picked.fake or picked.bfake then
			Shoot.shotName = picked.bfake and "BOUNCE FAKE" or (picked.fakeCorner and "FAKE CORNER" or "FAKE")
			if not Mark.fakeLogAt or os.clock() - Mark.fakeLogAt > 0.8 then
				Mark.fakeLogAt = os.clock()
				logFile("shoot fake", Mark.fakeWhy or "-")
			end
		end
		Shoot.point = picked.target
		Shoot.lastSide = picked.side
		Shoot.hitSide = picked.side
		Shoot.lob = picked.lob == true
		Shoot.chipSec = picked.chipSec
		Shoot.launch = shown
		Shoot.sampleFrom = picked.from
		Shoot.kickDir = kickDir
		Shoot.face = face
		Shoot.barY = bar.Y
		Shoot.bicycle = bicycle
		Shoot.curve = curve
		Shoot.spin = spin
		Shoot.dist = dist
		Shoot.aim = aim
		Shoot.aimPoint = picked.aimPoint
		Shoot.aimFromBall = picked.fromBall
		Shoot.aimOrg0 = aim.Origin
		Shoot.aimDir0 = aim.Direction
		Shoot.aimBallAt = origin
		Shoot.goodT = os.clock()
		Shoot.hold = nil
		Shoot.hFrac = picked.hFrac
		Shoot.gap = picked.gap
		Shoot.band = picked.band
		Shoot.lastBand = picked.band
		Shoot.solveBand = Shoot.wantBand or picked.band
		Shoot.poolN = #pool
		Shoot.mouth = rise.Magnitude
		Shoot.preview = {
			pts = flight,
			times = times,
			duration = times and times[#times] or 0,
			spin = spin,
			land = hit,
			origin = origin,
			bar = bar,
			face = face,
			along = lateral,
			under = true,
		}
		return aim, kickDir, curve, nil
	end
	if holdShot() then
		return Shoot.aim, Shoot.kickDir, Shoot.curve, nil
	end
	logFail()
	Shoot.preview = nil
	Shoot.point = nil
	Shoot.curve = nil
	Shoot.aim = nil
	Shoot.poolN = 0
	Shoot.solveAt = origin
	Shoot.solveKeeper = keeper
	Shoot.solveT = os.clock()
	return nil, nil, nil, "no vel"
end

-- Re-base the solved aim onto where we are NOW. The full solve runs every 0.2-0.3 s (sliced), but the player keeps
-- moving: a stale ray lands the ball off by the distance walked (user: the ball flies over). Every solved shot keeps
-- the world point its ray passed through; each frame the ray is rebuilt from the current origin (camera, or the
-- ball for ball-origin shots) through that same point, and the preview start follows the player (landing fixed).
-- Free: one subtraction + normalise. Refused for aerial / flick / bicycle / locked strikes, for lobs, and when the
-- turn from the solved direction would exceed ~6 degrees (then the next solve owns it).
Mark.rebaseAim = function()
	local a, ap = Shoot.aim, Shoot.aimPoint
	if not (a and ap and Shoot.aimBallAt and Shoot.aimDir0) then
		return
	end
	if Mark.flickAim or Mark.aerial or Mark.flickStrike or Mark.forceBike or Shoot.lob or (Mark.shotLockUntil and os.clock() < Mark.shotLockUntil) then
		return
	end
	local ball = Renderer.GetPosition()
	local cam = workspace.CurrentCamera
	if not (ball and cam) then
		return
	end
	local org
	if Shoot.aimFromBall then
		org = Shoot.aimOrg0 + (ball - Shoot.aimBallAt)
	else
		org = cam.CFrame.Position
	end
	local d = ap - org
	if d.Magnitude < 3 then
		return
	end
	local dir = d.Unit
	if dir:Dot(Shoot.aimDir0) < 0.9945 then
		return
	end
	if (org - a.Origin).Magnitude < 0.02 and dir:Dot(a.Direction) > 0.99999 then
		return
	end
	Shoot.aim = {
		Origin = org,
		Direction = dir,
		CameraCFrame = CFrame.lookAt(org, org + dir),
		CameraFieldOfView = a.CameraFieldOfView,
		IsAirborne = a.IsAirborne,
	}
	Shoot.kickDir = AimFacing.GetFlatDirection(dir) or Shoot.kickDir
	if Shoot.preview then
		Shoot.preview.shift = ball - Shoot.aimBallAt
	end
	Shoot.rebased = os.clock()
end

local function stepLogic()
	Mark.volleyPending()
	dribbleWhy = "off"
	tackleWhy = "off"
	local character = LocalPlayer.Character
	local root = character and ActorTargeting.GetActorRoot(LocalPlayer)
	if not (character and root) then
		predict = nil
		ghostPos = nil
		dribbleDanger = nil
		dribbleWhy = "no char"
		tackleWhy = "no char"
		return
	end
	ghostPos, ghostDir = ourRewindPosition(root, nil), unitOrNil(flat(root.CFrame.LookVector))
	if Mark.tickGk and Mark.tickGk(character, root) then
		predict = nil
		dribbleDanger = nil
		-- an AutoBall / block / kick order left over from before we became keeper would keep steering us (GetMoveCommand
		-- returns move.dir while any mode is set): only the keeper's own modes survive
		local mm = Mark.move and Mark.move.mode
		if mm and mm ~= "gk" and mm ~= "dodge" then
			logFile("gk drop mode", mm)
			Mark.moveStop()
		end
		Mark.dodgeTend(root)
		-- items / hazards are not field-player only: a keeper can hold a shotgun (SilentAim, AutoWall) and stand in oil
		if Mark.tickSkill then
			Mark.tickSkill(character, root)
		end
		if Mark.tickHazard then
			Mark.tickHazard(character, root)
		end
		if Mark.drawOil then
			Mark.drawOil(root)
		end
		return
	end
	Mark.homeSlide(root)


	if slideAim and os.clock() >= slideAimUntil then
		slideAim = nil
		if Mark.move.mode ~= "ball" and Mark.move.mode ~= "block" then
			origSetMove(character, Vector3.zero, Vector3.zero, false)
			if Mark.move.mode then
				Mark.moveStop()
			end
		end
	end
	if ClientSlide.IsSlideTackling() and not slideAim then
		if Mark.move.mode and Mark.move.mode ~= "block" then
			Mark.moveStop()
		end
		if not Mark.slideClearAt then
			Mark.slideClearAt = os.clock() + C.TotalVelocityReleaseStartsAt
		end
	end
	if Mark.slideClearAt and os.clock() >= Mark.slideClearAt then
		origSetMove(character, Vector3.zero, Vector3.zero, false)
		Mark.slideClearAt = nil
	end

	for i = #Log.pending, 1, -1 do
		local v = Log.pending[i]
		if os.clock() - v.at >= 0.8 then
			local nowOwner = liveOwnerId()
			local result
			if v.kind == "tackle" then
				if nowOwner == LocalPlayer.UserId then
					result = "HIT steal"
				elseif nowOwner == v.oid then
					result = "MISS still-them"
				else
					result = "scramble owner=" .. tostring(nowOwner)
				end
			else
				if nowOwner == LocalPlayer.UserId then
					result = "KEEP ball"
				else
					result = "LOST owner=" .. tostring(nowOwner)
				end
			end
			logFile(
				"verdict",
				v.kind,
				result,
				"distSrv",
				v.dist and string.format("%.2f", v.dist) or "-",
				"delay",
				v.delay and string.format("%.3f", v.delay) or "-",
				"delta",
				v.delta and string.format("%.2f", v.delta) or "-",
				"live",
				fmtV(v.livePos),
				"srv",
				fmtV(v.serverPos),
				"yaw",
				v.yaw and string.format("%.3f", v.yaw) or "-",
				"hit",
				fmtV(v.hit),
				"aim",
				fmtV(v.aim)
			)
			table.remove(Log.pending, i)
		end
	end

	local oid = liveOwnerId()
	local own = oid == LocalPlayer.UserId
	local tune = tackleTuning()
	ghostPos, ghostDir = ourRewindPosition(root, nil), unitOrNil(flat(root.CFrame.LookVector))
	if dribbleDanger and not ClientDodge.IsDribbling() then
		local lk = dribbleDanger.character and slideLock[dribbleDanger.character]
		if not lk and dribbleDanger.actor then
			local ch = Actors.GetCharacter(dribbleDanger.actor)
			lk = ch and slideLock[ch]
		end
		local elapsed = lk and ((lk.t0 and os.clock() - lk.t0) or lk.elapsed or dribbleDanger.elapsed)
		if not lk or (elapsed and elapsed > C.HitboxDelaySeconds + C.HitboxSeconds + 0.08) then
			dribbleDanger = nil
		end
	end

	if CFG.AutoDribble then
		if Mark.kickBoxLines then
			hideLines(Mark.kickBoxLines)
		end
		if not own then
			dribbleWhy = "no ball"
		elseif ClientDodge.IsDribbling() then
			dribbleWhy = "active"
		else
			local kt = Mark.kickThreat(root)
			Mark.drawKickBox(kt, root)
			local threat = nil
			if kt and kt.inside and kt.open then
				local ok, why = tryDribble()
				if not Mark.kickLog or os.clock() - Mark.kickLog > 0.4 then
					Mark.kickLog = os.clock()
					logFile("dribble kick", ok and "sent" or tostring(why), "e", string.format("%.2f", kt.elapsed), "d", string.format("%.1f", kt.dist), "name", actorName(kt.actor))
				end
				dribbleWhy = ok and "kick" or tostring(why)
			elseif kt and kt.facing > 0.8 and kt.dist <= 10 and CFG.AgentAddon and Mark.dribbleLeft() <= 0 and not Mark.aerial and Mark.moveSteer then
				-- dribble ready: walk into his kick box so the release lands on the iframe (speed boost)
				local to = unitOrNil(flat(kt.center - root.Position))
				if to then
					Mark.move.look = to
					Mark.move.pts = { root.Position, kt.center }
					Mark.move.born = Mark.move.born or os.clock()
					Mark.moveSteer(to, "walk")
					Mark.agentHold(true, "walk")
					Mark.kickWalkAt = os.clock()
					dribbleWhy = "kick into"
				end
			else
				threat = dribbleThreat(root)
			end
			if kt and (dribbleWhy == "kick" or dribbleWhy == "kick into") then
				-- handled by the kick branch this tick
			elseif not threat then
			dribbleWhy = "no threat"
			Mark.dodgeDone = nil
			if Mark.move.mode == "walk" and Mark.moveStop and os.clock() - (Mark.kickWalkAt or 0) > 0.3 then
				Mark.moveStop("walk")
			end
			else
				dribbleDanger = threat
				ghostPos = threat.ourPos
				if threat.fire and not Mark.aerial and not Mark.flickStrike then
						local used = false
						do
							local lk = threat.character and slideLock[threat.character]
							used = lk and (lk.usedDribble or lk.handled) and true or false
						end
						local dribbleReady = Mark.dribbleLeft() <= 0
					local ownBall = liveOwnerId() == LocalPlayer.UserId
					if ownBall and not threat.strong then
						dribbleWhy = "weak " .. tostring(threat.why or "")
					elseif ownBall and dribbleReady and CFG.AutoDribble then
						local ok, why = tryDribble()
						if ok then
							dribbleWhy = why or "kick"
						elseif CFG.AutoDodge and not Mark.dodgeDone and not used and Mark.dodgeSteer then
							logFile("dribble", why or "fail", "dodge instead")
							Mark.dodgeSteer(root, threat)
							dribbleWhy = "dodge"
						else
							dribbleWhy = why
						end
					elseif used then
						dribbleWhy = "handled"
					elseif CFG.AutoDodge and not Mark.dodgeDone and Mark.dodgeSteer then
						Mark.dodgeSteer(root, threat)
						dribbleWhy = dribbleReady and "dodge" or "dodge cd"
					end
				else
					dribbleWhy = "slide miss"
					if Mark.move.mode == "walk" and Mark.moveStop then
						Mark.moveStop("walk")
					end
				end
			end
		end
		note("d", dribbleWhy)
	end

	if CFG.AutoDodge and not own and not ClientSlide.IsSlideTackling() and not slideAim and Mark.move.mode ~= "dodge" and Mark.dodgeSteer then
		local threat = dribbleThreat(root)
		if threat and threat.fire and not Mark.dodgeDone then
			dribbleDanger = threat
			Mark.dodgeSteer(root, threat)
		end
	end

	if CFG.AgentAddon and ClientDodge.IsDribbling() then
		local dir, phase, target = Mark.dribblePlan(root)
		if dir and Mark.moveSteer then
			if phase ~= Mark.dribblePhase then
				Mark.dribblePhase = phase
				logFile("dribble agent", phase, "dir", fmtV(dir), "dist", string.format("%.1f", flat(target - root.Position).Magnitude))
			end
			Mark.move.look = dir
			Mark.moveSteer(dir, "dribble")
			Mark.move.pts = { root.Position, target }
			Mark.move.born = Mark.move.born or os.clock()
		elseif Mark.move.mode == "dribble" and Mark.moveStop then
			Mark.moveStop("dribble")
		end
	else
		Mark.dribblePhase = nil
		if Mark.move.mode == "dribble" and Mark.moveStop then
			Mark.moveStop("dribble")
		end
	end

	if Mark.move.mode == "dodge" then
		if ClientDodge.IsDribbling() then
			if Mark.moveStop then
				Mark.moveStop("dodge")
			end
		elseif Mark.dodgeSteer then
			Mark.dodgeSteer(root, Mark.dodgeThreat or dribbleDanger)
		end
	end

	if Mark.flickStrike and os.clock() > Mark.flickStrike then
		Mark.flickStrike = nil
	end

	if Mark.shotLockUntil and os.clock() < Mark.shotLockUntil then
		-- aerial / bicycle strike in flight: the aim solved at the press is the one the release sends; any re-solve
		-- from the moved ball (or the ownership flicker at contact) wiped Shoot.aim and the preview at the strike
		setShootWhy("lock")
	elseif CFG.AutoShoot and own then
		local charging = ChargedKick.IsCharging and ChargedKick.IsCharging()
		if charging and Shoot.aim then
			Shoot.locked = true
			local ballNow = Renderer.GetPosition() or root.Position
			-- bicycle: the hover moves the ball, a re-solve swapped the shot type between press and release
			if not Mark.forceBike and (not Shoot.solveAt or (ballNow - Shoot.solveAt).Magnitude > 0.4) then
				Mark.keepAim = true
				-- "async": same forced semantics (exact current origin, no cache) but run as a time-sliced job. The
				-- synchronous version cost 5-23 ms in ONE frame every time the dribbling ball moved 0.4 studs under
				-- the charge (perf log: solve-forced avg 4.8 max 23.2 = the strike hitch). The previous aim stays
				-- valid until the job lands (a few frames).
				local _, _, _, why = solveShot(root, "async")
				Mark.keepAim = false
				if why and os.clock() - (Shoot.goodT or 0) > 0.5 then
					Shoot.aim = nil
					Shoot.preview = nil
					Shoot.point = nil
					setShootWhy(why)
				else
					setShootWhy("lock")
				end
			else
				setShootWhy("lock")
			end
		elseif Mark.flickStrike or Mark.aerial then
			Shoot.locked = nil
			Mark.flickAim = true
			Mark.keepAim = true
			local _, _, _, why = solveShot(root, false)
			Mark.keepAim = false
			Mark.flickAim = false
			if why then
				setShootWhy(why)
			elseif Shoot.why ~= "lock" then
				setShootWhy("arm")
			end
		else
			Shoot.locked = nil
			local _, _, _, why = solveShot(root, false)
			if why then
				setShootWhy(why)
			elseif Shoot.why ~= "lock" then
				setShootWhy("arm")
			end
		end
		Mark.rebaseAim()
		Mark.feintTick()
	elseif not own and not Mark.flickStrike then
		Shoot.preview = nil
		Shoot.locked = nil
		Shoot.wire = nil
		Shoot.curve = nil
		Shoot.dist = nil
		Shoot.point = nil
		Shoot.aim = nil
		Shoot.kickDir = nil
		Shoot.lob = nil
		Shoot.launch = nil
		if Shoot.why ~= "swap" then
			setShootWhy("no ball")
		end
	end

	if Shoot.faced then
		TurnControl.ReleaseAutoRotate("AimCharge")
		Shoot.faced = nil
	end

	if Mark.bfTrack then
		Mark.bfTrack()
	end
	if Mark.passTick and character and root then
		Mark.passTick(character, root)
	end
	Mark.manualTackle = nil
	if CFG.AutoTackle or CFG.ManualTackle then
		if own then
			predict = nil
			tackleWhy = "have ball"
		else
			local player, croot = enemyCarrier(oid)
			if not player then
				predict = nil
				tackleWhy = croot or "no enemy"
			else
				carrierDribbleWait(player, 0)
				local cch = Actors.GetCharacter(player)
				local solved = solveIntercept(root, croot, cch, tune)
				predict = solved
				if not solved then
					tackleWhy = "far"
				elseif not solved.fire then
					tackleWhy = solved.wait or "outrun"
				elseif not CFG.AutoTackle then
					Mark.manualTackle = { aim = solved.aim, mult = solved.mult, char = cch, root = croot, at = os.clock() }
					tackleWhy = "manual ready"
				elseif (solved.conf or 1) < (CFG.TackleConfidence or 0) then
					tackleWhy = "unsure"
					if os.clock() - (Mark.confLogAt or 0) > 1 then
						Mark.confLogAt = os.clock()
						logFile("tackle unsure", "conf", string.format("%.2f", solved.conf or 0), "need", string.format("%.2f", CFG.TackleConfidence or 0), "eta", string.format("%.2f", solved.eta or 0))
					end
				elseif CFG.TackleCompetitor and Mark.mateNear(croot.Position, CFG.TackleCompetitorRadius or 8) then
					tackleWhy = "mate"
				elseif Mark.kickCmd then
					tackleWhy = "kick"
				elseif Mark.move.mode == "dodge" and dribbleDanger and dribbleDanger.fire then
					tackleWhy = "dodge"
				else
					Mark.manualTackle = { aim = solved.aim, mult = solved.mult, char = cch, root = croot, at = os.clock() }
					local use = solved
					local late = nil
					do
						local rec = Mark.charges and Mark.charges[player.UserId]
						local okC, ct = pcall(Mark.chargeTackle, root, croot, rec, solved)
						if okC and ct then
							if ct.skip then
								late = ct.why
							elseif ct.block and Mark.onShotLine(root, solved, rec) then
								late = "block holds the line"
							elseif ct.block then
								use = table.clone(solved)
								use.aim, use.mult, use.eta, use.hit = ct.aim, ct.mult, ct.eta, ct.X
								if not Mark.chargeBlockLog or os.clock() - Mark.chargeBlockLog > 0.5 then
									Mark.chargeBlockLog = os.clock()
									logFile("charge tackle", "slide-block", "eta", string.format("%.2f", ct.eta), "dX", string.format("%.1f", ct.dX), "mult", string.format("%.2f", ct.mult), "X", fmtV(ct.X))
								end
							end
						end
					end
					if late then
						if not Mark.chargeLateLog or os.clock() - Mark.chargeLateLog > 0.5 then
							Mark.chargeLateLog = os.clock()
							local rec = Mark.charges and Mark.charges[player.UserId]
							logFile("charge tackle", "skip", late, "eta", string.format("%.2f", solved.eta or 0), "left", string.format("%.2f", rec and (rec.at + (CFG.ChargeRelease or 0.34) - os.clock()) or 0))
						end
						tackleWhy = late
					else
						local go, gate = Mark.tackleGate(character, root, player, cch, use)
						if not go then
							tackleWhy = gate
						else
							local _, why = tryTackle(character, root, use.aim, use.mult, { char = cch, root = croot })
							if why == "sent" then
								logFile("tackle gate", gate, use ~= solved and "block" or "")
							end
							tackleWhy = why
						end
					end
				end
		end
	end
	note("t", tackleWhy)
else
		predict = nil
	end

	if character and root then
		if Mark.tickAerial then
			Mark.tickAerial(character, root)
		end
		if Mark.tickBike then
			Mark.tickBike(character, root)
		end
		if Mark.moveTick then
			Mark.moveTick(character, root)
		end
		if Mark.tickSkill then
			Mark.tickSkill(character, root)
		end
		if Mark.tickHazard then
			Mark.tickHazard(character, root)
		end
		if Mark.drawOil then
			Mark.drawOil(root)
		end
		if Mark.tickVolley then
			Mark.tickVolley(character, root)
		end
		if Mark.tickBlock then
			Mark.tickBlock(character, root)
		end
		if Mark.tickBall then
			Mark.tickBall(character, root)
		end
		if Mark.jumpHoldUntil and os.clock() > Mark.jumpHoldUntil then
			Mark.jumpHoldUntil = nil
			CharacterControllers.SetJumpCommand(character, false)
			Mark.endJump()
		end
	end

	local now = os.clock()
	local gap = (tackleWhy == "no owner" or tackleWhy == "off") and 6 or 2
	if now - lastTally >= gap then
		lastTally = now
		local player = enemyCarrier(oid)
		dbg(
			"tally",
			"owner",
			oid,
			"own",
			own,
			"enemy",
			actorName(player),
			"distSrv",
			predict and string.format("%.1f", predict.dist) or "-",
			"distLive",
			predict and string.format("%.1f", predict.distLive or 0) or "-",
			"delay",
			predict and string.format("%.3f", predict.delay or 0) or "-",
			"delta",
			predict and string.format("%.2f", predict.delta or 0) or "-",
			"catch",
			predict and tostring(predict.catch) or "-",
			"inst",
			predict and string.format("%.2f", predict.instSpd or 0) or "-",
			"recent",
			predict and string.format("%.2f", predict.recentSpd or 0) or "-",
			"yaw",
			predict and string.format("%.3f", predict.yaw or 0) or "-",
			"t",
			tackleWhy,
			"d",
			dribbleWhy,
			"wire",
			Wire.n
		)
	end
end

local function cdLeft(lastAt, dur)
	return math.max(0, dur - (os.clock() - lastAt))
end

local function paintWorld()
	if not CFG.Draw then
		hideWorld()
		return
	end
	Camera = Workspace.CurrentCamera
	local character = LocalPlayer.Character
	local root = character and ActorTargeting.GetActorRoot(LocalPlayer)
	if not root then
		hideWorld()
		return
	end
	local gy = root.Position.Y - 3.15
	local live = root.Position
	local ghost = ghostPos or live
	local gdir = ghostDir or unitOrNil(flat(root.CFrame.LookVector)) or Vector3.new(0, 0, 1)
	local predict = CFG.DrawTackle ~= false and predict or nil
	local dribbleDanger = CFG.DrawDanger ~= false and dribbleDanger or nil
	local drawPos = CFG.DrawPos ~= false
	local heroSlide = dribbleDanger ~= nil and dribbleDanger.heading ~= nil

	Mark.usQuad.Visible = false
	hideLines(Mark.usEdge)
	hideLines(Mark.usStuds)
	hideLines(Mark.ghostEdge)
	hideLines(Mark.chalkSmear)
	hideLines(Mark.enHex)
	hideLines(Mark.ballTicks)
	Mark.hideKnot()

	Mark.hideGate(Mark.gate.us)
	Mark.hideGate(Mark.gate.ghost)
	Mark.hideGate(Mark.gate.enLive)
	Mark.hideGate(Mark.gate.ball)
	local phantom = CFG.PosStyle == "phantom"
	if not drawPos then
		-- positions switched off
	elseif phantom then
		Mark.posArt(Mark.pen, live, ghost, gdir, gy, MatchSettings.IsGoalkeeperCharacter(character), os.clock())
	else
		Mark.bodyFill(live, gdir, gy, COL.Paper, 1.15)
	end
	if phantom or not drawPos then
		if not drawPos then
			Mark.stroke(Mark.rib.us, nil, gy, COL.Line)
		end
	elseif MatchSettings.IsGoalkeeperCharacter(character) then
		local h = 2.5
		local c = Vector3.new(ghost.X, gy, ghost.Z)
		local box = {
			c + Vector3.new(h, 0, h),
			c + Vector3.new(h, 0, -h),
			c + Vector3.new(-h, 0, -h),
			c + Vector3.new(-h, 0, h),
		}
		for i = 1, 4 do
			Mark.ghostEdge[i].Thickness = 1.7
			applyLine(Mark.ghostEdge[i], box[i], box[i % 4 + 1], COL.Paper, 1)
		end
		Mark.stroke(Mark.rib.us, { live, ghost }, gy, COL.Paper, 0.35)
	else
		Mark.bodyLine(ghost, gdir, gy, COL.Line, 1.35)
		if flat(ghost - live).Magnitude >= 0.2 then
			Mark.stroke(Mark.rib.us, { live, ghost }, gy, COL.Line, 0.2)
		else
			Mark.stroke(Mark.rib.us, nil, gy, COL.Line)
		end
	end

	if predict and predict.livePos and predict.serverPos then
		local edir = predict.aim or gdir
		Mark.smear(Mark.chalkSmear, predict.livePos, edir, gy, COL.Chalk)
		Mark.diamond(Mark.gate.enSrv, predict.serverPos, gy, COL.Tackle, 0.55)
		Mark.stroke(Mark.rib.en, { predict.livePos, predict.serverPos }, gy, COL.Tackle, 0.12)
	else
		Mark.hideGate(Mark.gate.enLive)
		Mark.hideGate(Mark.gate.enSrv)
		Mark.stroke(Mark.rib.en, nil, gy, COL.Tackle)
	end

	local knotDrawn = false
	if predict then
		local catching = predict.catch == true
		Mark.stroke(Mark.rib.our, nil, gy, COL.Chalk)
		Mark.stroke(Mark.rib.enemy, nil, gy, COL.Chalk)
		if predict.hit then
			local slidePts = predict.our
			if not (slidePts and #slidePts >= 2) then
				local aimU = predict.aim or unitOrNil(flat(predict.hit - live))
				local travel = Mark.dumpTravel and Mark.dumpTravel(predict.eta or 0.42) or flat(predict.hit - live).Magnitude
				slidePts = {}
				if aimU then
					for i = 0, 8 do
						slidePts[i + 1] = live + aimU * travel * (i / 8)
					end
				end
			end
			applyPath(ourPath, slidePts, gy, COL.Tackle, 1, false)
			applyPath(enemyPath, predict.enemy, gy, COL.Chalk, 0.55, false)
			Mark.approach(Mark.rib.our, hitTri, live, predict.hit, gy, catching and COL.Tackle or COL.Chalk)
			local fromEn = predict.livePos or predict.serverPos
			Mark.approach(Mark.rib.enemy, enLiveTri, fromEn, predict.hit, gy, COL.Chalk)
			Mark.sightHold = { p = predict.hit, aim = predict.aim, at = os.clock() }
			Mark.sightAt(predict.hit, gy, COL.Paper, true, predict.aim)
			Mark.sightP = predict.hit
		else
			hideLines(ourPath)
			hideLines(enemyPath)
			hitTri.Visible = false
			enLiveTri.Visible = false
			Mark.sightKeep(gy)
		end
		Mark.spur.Visible = false
	else
		hideLines(ourPath)
		hideLines(enemyPath)
		Mark.stroke(Mark.rib.our, nil, gy, COL.Chalk)
		Mark.stroke(Mark.rib.enemy, nil, gy, COL.Chalk)
		hitTri.Visible = false
		enLiveTri.Visible = false
		Mark.sightKeep(gy)
		Mark.spur.Visible = false
	end

	if heroSlide then
		local col = dribbleDanger.inFov and COL.Line or COL.Chalk
		local point = dribbleDanger.hitP or dribbleDanger.root.Position
		Mark.approach(Mark.rib.slide, dangerTri, live, point, gy, col)
		slidePip.Visible = false
	else
		hideLines(slidePath)
		slidePip.Visible = false
		dangerTri.Visible = false
		Mark.stroke(Mark.rib.slide, nil, gy, COL.Chalk)
	end
	if not knotDrawn then
		Mark.hideKnot()
	end

	local goal = enemyGoalPart()
	local lb, lt, rb, rt, along, face
	if goal then
		lb, lt, rb, rt, along, face = goalMouthCorners(goal)
	end
	if CFG.DrawGoal ~= false and lb and along and face then
		local side = along * 0.06
		local lift = face * 0.04
		local drop = Vector3.new(0, 0.08, 0)
		for i = 1, 4 do
			Mark.goalStitch[i].Thickness = Mark.ChalkW
		end
		for i = 5, 8 do
			Mark.goalStitch[i].Thickness = Mark.Thread
		end
		applyLine(Mark.goalStitch[1], lb + side + lift, lt + side + lift, COL.Line, 1)
		applyLine(Mark.goalStitch[2], lb - side + lift, lt - side + lift, COL.Line, 1)
		applyLine(Mark.goalStitch[3], rb + side + lift, rt + side + lift, COL.Line, 1)
		applyLine(Mark.goalStitch[4], rb - side + lift, rt - side + lift, COL.Line, 1)
		applyLine(Mark.goalStitch[5], lt + lift, rt + lift, COL.Tackle, 1)
		applyLine(Mark.goalStitch[6], lt - drop + lift, rt - drop + lift, COL.Tackle, 1)
		Mark.goalStitch[7].Visible = false
		Mark.goalStitch[8].Visible = false
	else
		hideLines(Mark.goalStitch)
	end

	local oid = liveOwnerId()
	local own = oid == LocalPlayer.UserId
	local ballPos = Renderer.GetMainMatchPosition()
	if ballPos and CFG.DrawBall ~= false then
		local col = own and COL.Line or COL.Paper
		Mark.ballSeam(ballPos, col)
		Mark.hideGate(Mark.gate.ball)
	else
		hideLines(Mark.ballHex)
		hideLines(Mark.ballTicks)
		Mark.hideGate(Mark.gate.ball)
	end
	hideLines(Mark.flight)
	Mark.flightTip.Visible = false
	Mark.flightTail.Visible = false
	hideLines(Mark.shadow)
	hideLines(Mark.ticks)
	hideLines(Mark.route)
	hideLines(Mark.stake)
	Mark.flightDot.Visible = false
	Mark.flightTime.Visible = false
	hideLines(Mark.box)
	local preview = Shoot.preview
	local ballNow = Renderer.GetPosition()
	if preview and preview.origin and ballNow and (preview.origin - ballNow).Magnitude > 1 and not Shoot.locked and os.clock() - (Shoot.goodT or 0) > 0.5 then
		Shoot.preview = nil
		preview = nil
	end
	if preview and preview.pts and #preview.pts >= 2 and Shoot.point and CFG.DrawShot ~= false then
		local col = Shoot.shotName == "LOB" and COL.Lob or (Shoot.shotName == "FLAT" and COL.Flat or (Shoot.shotName == "TRICK" and COL.Lob or (Shoot.shotName == "DIP" and COL.Lob or (Shoot.shotName == "LOW" and COL.Lob or (Shoot.shotName == "HIGH" and COL.Tackle or (Shoot.shotName == "SPIN" and COL.Tackle or COL.Line))))))
		if CFG.ShotStyle == "aurora" then
			local nm = Shoot.shotName
			local kind = (nm == "FLAT" or nm == "LOW") and "lo" or ((nm == "TRICK" or nm == "DIP" or nm == "SPIN") and "curl" or "hi")
			Mark.trajArt(Mark.pen, preview.pts, preview.times, preview.land, preview.along, gy, kind, os.clock(), preview.shift)
		else
			Mark.drawFlight(preview.pts, col)
			Mark.drawShadow(preview.pts, gy, COL.Chalk)
			if preview.land and preview.face then
				Mark.drawScar(preview.land, preview.face, preview.along, gy, col)
			end
		end
	end
	if Mark.paDraw then
		Mark.paDraw(gy)
	end
	if Mark.drawRoute then
		Mark.drawRoute(root, gy)
	end
	Mark.artFinish()
end

local function paintHud()
	if not CFG.Draw then
		for i = 1, 3 do
			chips[i].bg.Visible = false
			chips[i].tx.Visible = false
		end
		Mark.hudRule.Visible = false
		shotDbg.Visible = false
		return
	end
	Camera = Workspace.CurrentCamera
	local oid = liveOwnerId()
	local own = oid == LocalPlayer.UserId
	local ballTxt = "ball  none"
	if own then
		ballTxt = "shot  " .. (Shoot.why or "idle")
	elseif Mark.ak then
		ballTxt = "kick  " .. tostring(Mark.ak.tag)
	elseif ownerIdOk(oid) then
			ballTxt = "ball  " .. tostring(oid)
	end
	local rows = {
		{ chips[1], "tackle  " .. tackleWhy, tackleWhy == "sent" and COL.Tackle or COL.Chalk, tackleWhy == "sent" },
		{ chips[2], "dribble  " .. dribbleWhy, dribbleWhy == "sent" and COL.Line or COL.Chalk, dribbleWhy == "sent" },
		{ chips[3], ballTxt, own and COL.Line or COL.Paper, own },
	}
	local vp = Camera.ViewportSize
	local y = vp.Y - 22
	local x = 16
	local ruleCol = COL.Chalk
	if tackleWhy == "sent" then
		ruleCol = COL.Tackle
	elseif dribbleWhy == "sent" or own then
		ruleCol = COL.Line
	end
	for i = #rows, 1, -1 do
		local row = rows[i]
		local tx = row[1].tx
		row[1].bg.Visible = false
		tx.Text = row[2]
		tx.Color = row[3]
		tx.Size = row[4] and 16 or 13
		tx.Outline = true
		tx.OutlineColor = COL.Ink
		tx.Font = FONT
		tx.Position = Vector2.new(x, y)
		tx.Visible = true
		y -= row[4] and 20 or 16
	end
	Mark.hudRule.From = Vector2.new(x, y + 4)
	Mark.hudRule.To = Vector2.new(x + 108, y + 4)
	Mark.hudRule.Color = ruleCol
	Mark.hudRule.Transparency = 1
	Mark.hudRule.Visible = true
	local curveTxt = Shoot.curve and string.format("%.2f", Shoot.curve) or "-"
	local distTxt = Shoot.dist and string.format("%.0f", Shoot.dist) or "-"
	local sideTxt = Shoot.lastSide and (Shoot.lastSide > 0.8 and "R" or (Shoot.lastSide < -0.8 and "L" or "C")) or "-"
	local name = Shoot.shotName or "NONE"
	shotDbg.Text = name .. "  " .. sideTxt .. "  dist " .. distTxt .. "  h " .. (Shoot.hFrac and string.format("%.2f", Shoot.hFrac) or "-") .. "  curve " .. curveTxt .. "  " .. (Shoot.band or "-")
	shotDbg.Size = 18
	shotDbg.Color = name == "LOB" and COL.Lob or (name == "FLAT" and COL.Flat or (name == "TRICK" and COL.Lob or (name == "LOW" and COL.Lob or (name == "HIGH" and COL.Tackle or (name == "SPIN" and COL.Tackle or COL.Paper)))))
	shotDbg.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5 + 34)
	shotDbg.Visible = CFG.ShotDebug ~= false
	if CFG.DrawHud == false then
		for i = 1, 3 do
			chips[i].bg.Visible = false
			chips[i].tx.Visible = false
		end
		Mark.hudRule.Visible = false
	end
end

local function shotRemote(self)
	if typeof(self) ~= "Instance" then
		return nil
	end
	local parent = self.Parent
	local ball = parent and parent.Name == "Ball"
	if self == BallGroup.Kick or (ball and self.Name == "Kick") then
		return "kick"
	end
	if self == BallGroup.ActionUpdate or (ball and self.Name == "ActionUpdate") then
		return "aim"
	end
	return nil
end

-- While an aerial / bicycle strike is locked, the game's own aim source returns our solved ray: ChargedKick's
-- charge aim ray, Shoot release (GetChargeAimRay or GetCameraAimRayWithoutHit), commitAimLock -> LockAim
-- (AimLockedAt), preview and every remote phase then carry it. Overriding only the remote packet left the client
-- release / lock built from the camera (legit flick bicycle went where the camera looked).
Mark.strikeRay = function()
	if not (Mark.shotLockUntil and os.clock() < Mark.shotLockUntil and Shoot.aim and Shoot.aim.Direction) then
		return nil
	end
	local a = Shoot.aim
	local o = typeof(a.Origin) == "Vector3" and a.Origin or Vector3.zero
	return {
		Origin = o,
		Direction = a.Direction,
		CameraCFrame = a.CameraCFrame or CFrame.lookAt(o, o + a.Direction),
		CameraFieldOfView = a.CameraFieldOfView,
		IsAirborne = a.IsAirborne,
	}
end

local oldCamRay = Reticle.GetCameraRay
Mark.oldCamRay = oldCamRay
Reticle.GetCameraRay = function(...)
	if Mark.pa and Mark.pa.live and Mark.pa.live.ray then
		return Mark.pa.live.ray
	end
	if Mark.silentRay and not (ChargedKick.IsCharging and ChargedKick.IsCharging()) then
		return Mark.silentRay
	end
	return oldCamRay(...)
end

local oldAimRay = Reticle.GetCameraAimRayWithoutHit
Reticle.GetCameraAimRayWithoutHit = function()
	if Mark.pa and Mark.pa.live and Mark.pa.live.ray then
		return Mark.pa.live.ray
	end
	if Mark.skillRay then
		return Mark.skillRay
	end
	local strike = Mark.strikeRay()
	if strike then
		return strike
	end
	local ray = oldAimRay()
	local aim = Mark.volleyAim or Mark.blockAim
	if aim and type(ray) == "table" and ChargedKick.IsCharging and ChargedKick.IsCharging() and liveOwnerId() ~= LocalPlayer.UserId then
		local out = table.clone(ray)
		local camPos = typeof(out.CameraCFrame) == "CFrame" and out.CameraCFrame.Position or (typeof(out.Origin) == "Vector3" and out.Origin) or Vector3.zero
		out.Direction = aim
		out.CameraCFrame = CFrame.lookAt(camPos, camPos + aim)
		out.TargetPosition = nil
		out.ScreenPosition = nil
		return out
	end
	return ray
end

local oldPathGet = ChargePathVelocity.Get
ChargePathVelocity.Get = function(char, secs, kind, aim, origin, reported, kickDir, target, boundary, curve)
	if Shoot.locked and not Shoot.solving and Shoot.aim and Shoot.aim.Direction and not Shoot.lob and Shoot.solveAt then
		local live = Renderer.GetPosition()
		if live and (live - Shoot.solveAt).Magnitude <= (Shoot.aimPoint and 6 or 1) then
			aim = Shoot.aim
			curve = if Mark.flickStrike then nil else Shoot.curve -- was `and nil or`: the flick kept the curve
		end
	end
	return oldPathGet(char, secs, kind, aim, origin, reported, kickDir, target, boundary, curve)
end

local ShotAimAssist = require(Modules.Actions.ShotAimAssist)
local oldAssist = ShotAimAssist.GetAssistedDirection
ShotAimAssist.GetAssistedDirection = function(...)
	if CFG.AutoShoot and Shoot.aim and (liveOwnerId() == LocalPlayer.UserId or Mark.flickStrike) then
		return nil
	end
	return oldAssist(...)
end

local TrajectoryPreviewFollow = require(Client.Gameplay.Visual.TrajectoryPreviewFollow)
local oldAimStep = TrajectoryPreviewFollow.StepAimSampleCFrame
TrajectoryPreviewFollow.StepAimSampleCFrame = function(current, target, dt)
	return oldAimStep(current, target, dt)
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
	local method = getnamecallmethod()
	setnamecallmethod(method)
	if method ~= "FireServer" or not CFG.AutoShoot then
		return oldNamecall(self, ...)
	end
	local packet = ...
	local which = shotRemote(self)
	if (which == "kick" or which == "aim") and type(packet) == "table" then
		local cmd = packet.Command
		if which == "kick" and packet.Phase == "Cancel" then
			Shoot.locked = nil
			Shoot.wire = nil
		elseif Mark.pa and Mark.pa.live and Mark.pa.live.ray and type(cmd) == "table" and cmd.PassType == "FreeLobPass" and (packet.Phase == "Start" or packet.Phase == "Release" or packet.Phase == "Update") then
			-- PASS ASSIST: the packet carries our yaw. At Release the charge is what the hold really produced: re-aim for it.
			local live = Mark.pa.live
			if packet.Phase == "Release" and not live.released then
				live.released = true
				local actual = cmd.ChargeSeconds
				if type(actual) == "number" then
					local okR, sol2 = pcall(Mark.paSolve, live.sel, actual)
					if okR and sol2 and live.sol then
						local worse = math.abs(sol2.along) > math.abs(live.sol.along or 0) + 4 or math.abs(sol2.lat) > math.abs(live.sol.lat or 0) + 3
						if not worse then
							live.dir = sol2.dir
							live.sol = sol2
							Mark.paRay(live)
						else
							logFile("pass assist", "release", "keep", "along", string.format("%.1f", sol2.along), "lat", string.format("%.1f", sol2.lat))
						end
					end
					logFile("pass assist", "release", "planned", string.format("%.3f", live.charge), "actual", string.format("%.3f", actual), "status", live.sol and live.sol.status or "-", "along", live.sol and string.format("%.1f", live.sol.along) or "-", "lat", live.sol and string.format("%.1f", live.sol.lat) or "-")
				end
			end
			local r = live.ray
			cmd.AimDirection = { Origin = r.Origin, Direction = r.Direction, CameraCFrame = r.CameraCFrame, CameraFieldOfView = r.CameraFieldOfView, IsAirborne = false }
			cmd.TargetUserId = nil
		elseif type(cmd) == "table" and not MatchSettings.IsGoalkeeperCharacter(LocalPlayer.Character) and (packet.Phase == "Start" or packet.Phase == "Release" or packet.Phase == "Update") and Shoot.aim and Shoot.aim.Direction and not Shoot.lob and not (liveOwnerId() == LocalPlayer.UserId and (cmd.PassType == "FreeLowPass" or cmd.PassType == "FreeLobPass" or cmd.PassType == "AssistedPass")) and (Mark.flickStrike or (Shoot.launch and Shoot.launch.Y > 1) or Shoot.aim.Direction.Y > 0.05) then
			cmd.AimDirection = {
				Origin = Shoot.aim.Origin,
				Direction = Shoot.aim.Direction,
				CameraCFrame = Shoot.aim.CameraCFrame,
				CameraFieldOfView = Shoot.aim.CameraFieldOfView,
				IsAirborne = Shoot.aim.IsAirborne,
			}
			cmd.KickDirection = AimFacing.GetFlatDirection(Shoot.aim.Direction) or Shoot.aim.Direction
			if Mark.flickStrike then
				cmd.Curve = 0
			elseif cmd.PassType == "Shot" and Shoot.curve then
				cmd.Curve = Shoot.curve
			end
			if packet.Phase == "Release" and (Mark.flickStrike or Mark.forceBike) then
				local src0 = typeof(packet.Command.AimDirection) == "table" and packet.Command.AimDirection.Direction
				logFile("shoot", "release", "sent", fmtV(src0), "locked", tostring(Mark.strikeRay() ~= nil))
			end
			if packet.Phase == "Start" then
				Mark.bfShot = Shoot.shotName == "BOUNCE FAKE" and os.clock() or nil
				Shoot.roll = math.random()
				Shoot.fakeRoll = math.random()
				Shoot.fakeFirst = math.random()
				Shoot.bounceRoll = math.random()
				do
					-- last picks (family + side): the next solve down-weights what was just used (predictable shots)
					local h = Mark.shotHist or {}
					Mark.shotHist = h
					h[#h + 1] = { band = Shoot.band, side = (Shoot.hitSide or 0) >= 0 and 1 or -1 }
					if #h > 4 then
						table.remove(h, 1)
					end
				end
				logFile("shoot", "start", Shoot.lob and "lob" or "dir", "reach", Shoot.reachM and string.format("%.2f", Shoot.reachM) or "-", Shoot.reachOpen and "open" or "saveable", "pool", Shoot.reachN or "-", "bands", Mark.bandStat(Mark.shotStat), "keeper", Shoot.keeperS and string.format("%.1f", Shoot.keeperS) or "-", Shoot.keeperTag or "-", fmtV(Shoot.aim.Direction), "curve", Shoot.curve and string.format("%.2f", Shoot.curve) or "-", "dist", Shoot.dist and string.format("%.0f", Shoot.dist) or "-", "h", Shoot.hFrac and string.format("%.2f", Shoot.hFrac) or "-", "gap", Shoot.gap and string.format("%.1f", Shoot.gap) or "-", "ang", Shoot.ang and string.format("%.1f", Shoot.ang) or "-", "side", Shoot.hitSide ~= nil and string.format("%.1f", Shoot.hitSide) or "-", "band", Shoot.band or "-", "hold", Shoot.hold and "1" or "0", "vel", fmtV(Shoot.launch), "vmag", Shoot.launch and string.format("%.0f", Shoot.launch.Magnitude) or "-", "vdir", Shoot.launch and fmtV(Shoot.launch.Unit) or "-", "spin", fmtV(Shoot.spin), "org", fmtV(Shoot.aim.Origin), "from", fmtV(Shoot.sampleFrom))
			end
		end
	end
	setnamecallmethod(method)
	return oldNamecall(self, ...)
end))

if ChargedKick.IsCharging and ChargedKick.IsCharging() then
	ChargedKick.CancelCharge()
end

if ChargedKick.HandleInputBegan then
	local oldShootBegan = ChargedKick.HandleInputBegan
	ChargedKick.HandleInputBegan = function(input, processed, extra)
		if Controls.IsInput("Kick", input) then
			-- who owns the next charge: a real input object (the player) or a table we made (volley / bike / aerial)
			if typeof(input) == "Instance" then
				Mark.realChargeAt = os.clock()
			else
				Mark.scriptChargeAt = os.clock()
			end
		end
		-- who starts a kick while we hold the ball (real mouse/key vs a script-made Controls.CreateInput, and caller)
		if Controls.IsInput("Kick", input) and liveOwnerId() == LocalPlayer.UserId then
			local okS, src0 = pcall(debug.info, 2, "s")
			local okL, line0 = pcall(debug.info, 2, "l")
			logFile("kick input", "own", "type", typeof(input) == "Instance" and tostring(input.UserInputType) or typeof(input), "key", typeof(input) == "Instance" and tostring(input.KeyCode) or "-", "processed", tostring(processed), "caller", okS and tostring(src0) or "-", okL and tostring(line0) or "-")
		end
		if CFG.AutoShoot and Shoot.lob and Shoot.aim and not processed and Controls.IsInput("Kick", input) then
			local passIn = Mark.passIn or require(Client.Gameplay.Actions.Pass)
			Mark.passIn = passIn
			if passIn.HandleInputBegan(Controls.CreateInput("Lob"), false) ~= false then
				local hold = Shoot.chipSec or 0.22
				task.delay(hold, function()
					if passIn.HandleInputEnded then
						passIn.HandleInputEnded(Controls.CreateInput("Lob"))
					end
				end)
				logFile("shoot", "chip", string.format("%.2f", hold))
				return true
			end
		end
		return oldShootBegan(input, processed, extra)
	end
end

if ChargedKick.HandleInputEnded then
	local oldShootEnded = ChargedKick.HandleInputEnded
	ChargedKick.HandleInputEnded = function(input, ...)
		-- only the player's own release (a real input object); our scripted charges pass tables and go straight through
		if typeof(input) == "Instance" and Shoot.feintDo and not Shoot.feinted and Mark.feintRelease and Controls.IsInput("Kick", input) then
			if Mark.feintRelease() then
				return
			end
		end
		return oldShootEnded(input, ...)
	end
end

Mark.wallParts = function()
	local now = os.clock()
	if Mark.wallCache and now - (Mark.wallAt or 0) < 0.25 then
		return Mark.wallCache
	end
	Mark.wallAt = now
	local list = {}
	local models = {}
	Mark.wallModels = models
	local world = workspace:FindFirstChild("Misc")
	world = world and world:FindFirstChild("Items")
	if not world then
		Mark.wallCache = list
		return list
	end
	local place = require(Modules.Items.PlaceDownPlacement)
	local dest = require(Modules.Gameplay.DestructionSettings)
	for _, inst in world:GetChildren() do
		if inst:GetAttribute("PlacedItemId") == "barricades" and not dest.IsBoundaryDestroyed(inst) then
			models[#models + 1] = inst
			local parts = place.GetBoundaryParts(inst)
			for i = 1, #parts do
				list[#list + 1] = parts[i]
			end
		end
	end
	-- signature: same set of standing barricades -> memoised block results stay valid
	local sig = {}
	for i = 1, #models do
		sig[i] = tostring(models[i])
	end
	local s = #models .. ":" .. table.concat(sig, ",")
	if s == Mark.wallSig and Mark.wallModelsKeep then
		Mark.wallModels = Mark.wallModelsKeep
	else
		Mark.wallSig = s
		Mark.wallModelsKeep = models
	end
	Mark.wallCache = list
	return list
end

Mark.wallHit = function(origin, dir, dist)
	local parts = Mark.wallParts()
	if #parts == 0 or typeof(dir) ~= "Vector3" or dir.Magnitude < 0.05 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	return Workspace:Raycast(origin, dir.Unit * dist, params)
end

-- Barricade avoidance for agent steering. Old version: hit -> "left" whenever both sides were blocked, with no
-- memory, so after AutoWall dropped a barricade between us and the target every agent mode slid along it in one
-- direction (user: "after AutoWall the script runs one way"). Now: rotate the wanted dir by 25..90 deg, keep the side
-- chosen last time for 0.6 s, prefer the side closer to the wanted dir; nothing clear -> keep the wanted dir (walk
-- into it, the game collides) instead of inventing a direction.
Mark.wallDir = function(root, dir)
	if not (root and dir) or dir.Magnitude < 0.05 then
		return dir
	end
	local fd = unitOrNil(flat(dir))
	if not fd or not Mark.wallHit(root.Position, fd, 6) then
		Mark.wallSide = nil
		return dir
	end
	local function rot(a)
		local r = math.rad(a)
		return Vector3.new(fd.X * math.cos(r) - fd.Z * math.sin(r), 0, fd.X * math.sin(r) + fd.Z * math.cos(r))
	end
	local sticky = Mark.wallSide and os.clock() - (Mark.wallSideAt or 0) < 0.6 and Mark.wallSide or nil
	for _, a in { 25, 45, 65, 90 } do
		for _, s in (sticky == -1 and { -1, 1 } or { 1, -1 }) do
			local c = rot(a * s)
			if not Mark.wallHit(root.Position, c, 7) then
				Mark.wallSide, Mark.wallSideAt = s, os.clock()
				if not Mark.wallLog or os.clock() - Mark.wallLog > 0.5 then
					Mark.wallLog = os.clock()
					logFile("wall steer", Mark.move and Mark.move.mode or "-", a * s)
				end
				return c * dir.Magnitude
			end
		end
	end
	return dir
end

Mark.dumpBall = function(root, away)
	if liveOwnerId() ~= LocalPlayer.UserId then
		return
	end
	local aim = unitOrNil(flat(away)) or Vector3.new(0, 0, -1)
	local origin = root.Position + Vector3.new(0, 1.6, 0)
	local ray = {
		Origin = origin,
		Direction = aim,
		CameraCFrame = CFrame.lookAt(origin, origin + aim),
	}
	local now = Workspace:GetServerTimeNow()
	local cmd = ActionCommands.Kick({
		PassType = "FreeLobPass",
		ChargeSeconds = 0,
		HoldSeconds = 0,
		MaximumChargeSeconds = KickCore.Constants.MaximumChargeSeconds,
		AimDirection = ray,
		KickDirection = aim,
		ShotTime = now - 0.25,
	})
	ActionRemoteProtocol.Start(cmd)
	cmd.ShotTime = now
	ActionRemoteProtocol.Release(cmd)
	logFile("ball dump", "lob", fmtV(aim))
end

local function onProjectile(kind, proj)
	if kind ~= "ProjectileStart" or type(proj) ~= "table" then
		return
	end
	local id = proj.ItemId
	-- the same projectile arrives on two remotes (ProjectileMovement + Items.Effect) and again in a ProjectileSnapshot:
	-- a second pass over it reset its state (decision flags) and doubled the reaction
	Mark.projSeen = Mark.projSeen or {}
	if proj.Id ~= nil then
		if Mark.projSeen[proj.Id] then
			return
		end
		Mark.projSeen[proj.Id] = os.clock()
		for k, tt in Mark.projSeen do
			if os.clock() - tt > 30 then
				Mark.projSeen[k] = nil
			end
		end
	elseif os.clock() - (Mark.projAt or 0) < 0.15 and Mark.projId == id then
		return
	end
	Mark.projAt = os.clock()
	Mark.projId = id
	if proj.SourceUserId == LocalPlayer.UserId and type(id) == "string" and typeof(proj.Velocity) == "Vector3" then
		Mark.projSpeed = Mark.projSpeed or {}
		Mark.projSpeed[id] = proj.Velocity.Magnitude
		logFile("proj speed", id, string.format("%.1f", proj.Velocity.Magnitude))
		-- SilentAim calibration: what pitch did the server really launch with? Compared with the ballistic direction we wanted
		-- and with the pitch of the ray we sent: ~wanted -> the peak solve works (the ray is only a landing marker); ~ray ->
		-- the server flies along the sent direction (switch to sending the ballistic direction itself).
		local al = Mark.arcLast
		if id == "freezeGun" and al and os.clock() - al.at < 0.7 and proj.Velocity.Magnitude > 1 then
			local v = proj.Velocity
			local pitch = math.deg(math.asin(math.clamp(v.Y / v.Magnitude, -1, 1)))
			local fl, dl = unitOrNil(flat(v)), unitOrNil(flat(al.desDir))
			local yawErr = (fl and dl) and math.deg(math.acos(math.clamp(fl:Dot(dl), -1, 1))) or -1
			do
				local sp = proj.Position or Vector3.zero
				local fv = flat(v)
				if al.P and fv.Magnitude > 1 then
					local Dp = flat(al.P - sp):Dot(fv.Unit)
					local tt = Dp / fv.Magnitude
					local yAt = sp.Y + v.Y * tt - 0.5 * (al.g or 58.9) * tt * tt
					local ptY = al.P.Y + (al.bias or 0)
					local errY = yAt - ptY
					local lat = flat(al.P - sp):Dot(Vector3.new(-fv.Unit.Z, 0, fv.Unit.X)) -- target's side offset from his own flight line
					if Dp > 8 and tt < 2 then
						local nb = math.clamp((al.bias or 0) + errY * (CFG.ArcBiasGain or 0.7), -9, 9)
						logFile("silent shot err", "Y", string.format("%.2f", errY), "side", string.format("%.2f", -lat), "t", string.format("%.2f", tt), "D", string.format("%.1f", Dp), "bias", string.format("%.2f", al.bias or 0), "->", string.format("%.2f", nb))
					end
				end
			end
			logFile("silent shot", al.mode, "pitch", string.format("%.1f", pitch), "wanted", string.format("%.1f", al.des), "ray", string.format("%.1f", al.ray), "yawErr", string.format("%.1f", yawErr), "D", string.format("%.1f", al.D), "start", fmtV(proj.Position or Vector3.zero), "muzzle", fmtV(al.muzzle))

		end
	end
	local shooter = playerOf(proj.SourceUserId)
	if shooter and sameTeam(shooter) then
		return
	end
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	local pos = proj.Position
	local vel = proj.Velocity
	if not root or typeof(pos) ~= "Vector3" then
		return
	end
	local own = liveOwnerId() == LocalPlayer.UserId

	local function gravOf(item)
		local g = Workspace.Gravity
		if type(g) ~= "number" or g < 10 then
			g = 196.2
		end
		if item == "rocketPunch" then
			return 0
		elseif item == "freezeGun" then
			return g * 0.3
		elseif item == "bazooka" or item == "grenade" then
			return g
		end
		return g * 0.3
	end
	local function radOf(item)
		if item == "bazooka" or item == "grenade" then
			return Mark.blastR()
		end
		if item == "rocketPunch" then
			return 6.2
		end
		return HitboxSettings.Receive.Size.X * 0.5 + 1.4
	end
	-- Closest horizontal miss over the next `cap` seconds, including the item's gravity (ProjectileVfx.PredictionConfigs:
	-- bazooka/grenade = full, freezeGun = 0.3, rocketPunch = 0) and where WE will be.
	local function closest(from, velo, grav, cap)
		if typeof(velo) ~= "Vector3" or velo.Magnitude < 1 then
			return 1e9, 0
		end
		local us = root.AssemblyLinearVelocity
		us = typeof(us) == "Vector3" and us or Vector3.zero
		local best, bestT = 1e9, 0
		local t = 0.04
		while t <= cap do
			local p = from + velo * t + Vector3.new(0, -0.5 * grav * t * t, 0)
			local d = flat(p - (root.Position + us * t)).Magnitude
			if d < best then
				best, bestT = d, t
			end
			t += 0.04
		end
		return best, bestT
	end
	Mark.projDodgeAt = Mark.projDodgeAt or {}
	Mark.projSrc = Mark.projSrc or {}
	local function dodgeAt(tag, from, velo, grav, rad, cap)
		if Mark.move.mode == "dribble" then
			return
		end
		local last = Mark.projDodgeAt[tag]
		if last and os.clock() - last < 0.4 then
			return
		end
		local miss, t = closest(from, velo, grav or 0, cap or 0.5)
		if miss > rad then
			return
		end
		local axis = unitOrNil(flat(velo))
		if not axis then
			return
		end
		local right = Vector3.new(-axis.Z, 0, axis.X)
		local side = right:Dot(flat(root.Position - from))
		local sign = (side >= 0) and 1 or -1
		local need = math.clamp(rad + 1.6 - miss, 3.5, 8)
		if math.abs(side + sign * need) < math.abs(side - sign * need) then
			sign = -sign
		end
		local step = right * sign * need
		Mark.stepAway(root, step, "proj")
		Mark.projDodgeAt[tag] = os.clock()
		logFile("proj dodge", tostring(tag), string.format("miss %.2f", miss), string.format("t %.2f", t), string.format("step %.1f", need))
	end
	local rad = radOf(id)
	local g = gravOf(id)
	if proj.Id ~= nil then
		Mark.projSrc[proj.Id] = proj.SourceUserId
		Mark.projRad = Mark.projRad or {}
		Mark.projRad[proj.Id] = rad
		-- decisions are taken every frame by Mark.projTick on the live state (start + ProjectileMovement rows)
		local nowS = Workspace:GetServerTimeNow()
		Mark.projLive = Mark.projLive or {}
		Mark.projLive[proj.Id] = {
			id = proj.Id, item = id, src = proj.SourceUserId, pos = pos, vel = typeof(vel) == "Vector3" and vel or Vector3.zero,
			at = nowS, born = type(proj.StartedAt) == "number" and proj.StartedAt or nowS, grav = g, rad = rad,
			homing = id == "rocketPunch",
		}
		do
			local stN = Mark.projLive[proj.Id]
			stN.pos0, stN.vel0 = stN.pos, stN.vel
			pcall(Mark.hazAdd, stN)
		end
		logFile("proj start", tostring(id), "from", tostring(shooter and actorName(shooter) or proj.SourceUserId), "dist", string.format("%.1f", flat(pos - root.Position).Magnitude), "spd", string.format("%.0f", typeof(vel) == "Vector3" and vel.Magnitude or 0), "own", tostring(own))
		return
	end
	-- no id: old one-shot reaction
	if typeof(vel) == "Vector3" and vel.Magnitude >= 8 and id ~= "rocketPunch" then
		dodgeAt(id or "?", pos, vel, g, rad, 1.4)
	end
end

-- ProjectileMovement also sends (serverTime, rows) after the start: row = {Id, Sequence, Position, Velocity, Steering, DetonatesAt}
-- (ProjectileVfx.MovementFields). The old handler ignored everything but ProjectileStart, so a grenade arc and a boomerang
-- return were dodged once from the muzzle and never again.
Mark.projBatch = function(rows)
	if type(rows) ~= "table" or not Mark.projLive then
		return
	end
	local nowS = Workspace:GetServerTimeNow()
	for i = 1, #rows do
		local row = rows[i]
		if type(row) == "table" then
			local st = Mark.projLive[row[1]]
			local p, v = row[3], row[4]
			if st and typeof(p) == "Vector3" then
				st.pos = p
				st.vel = typeof(v) == "Vector3" and v or st.vel
				st.at = nowS
				st.steer = typeof(row[5]) == "Vector3" and row[5] or st.steer
				if type(row[6]) == "number" and row[6] > 0 then
					st.det = row[6]
					local ev = Mark.hazEv and Mark.hazEv[st.id]
					if ev and ev.kind == "blast" and st.item == "grenade" then
						ev.t = row[6] -- the server's own detonation time
					end
				end
			end
		end
	end
end

-- ProjectileSnapshot re-sends every live projectile (ProjectileEffects.ShowProjectileState): a Start that never arrived (the
-- rocket punch the script "did not notice") is recovered here.
Mark.projSnapshot = function(pkt)
	if type(pkt) ~= "table" or type(pkt.Projectiles) ~= "table" then
		return
	end
	for _, p in pkt.Projectiles do
		if type(p) == "table" and p.Id ~= nil and not (Mark.projSeen and Mark.projSeen[p.Id]) then
			logFile("proj snapshot", "recovered", tostring(p.ItemId), tostring(p.Id))
			onProjectile("ProjectileStart", p)
		end
	end
end

Remotes.Get("Items", "ProjectileMovement").OnClientEvent:Connect(function(kind, proj)
	if kind == "ProjectileSnapshot" then
		Mark.projSnapshot(proj)
	elseif kind == "ProjectileStart" then
		onProjectile(kind, proj)
	elseif kind == "ProjectileFinish" then
		if type(proj) == "table" and Mark.projLive and proj.Id ~= nil then
			Mark.projLive[proj.Id] = nil
		end
	elseif type(kind) == "number" and type(proj) == "table" then
		Mark.projBatch(proj)
	end
end)
Remotes.Get("Items", "Effect").OnClientEvent:Connect(function(pkt)
	if type(pkt) == "table" and pkt.Kind == "ProjectileSnapshot" then
		Mark.projSnapshot(pkt)
	elseif type(pkt) == "table" and pkt.Kind == "ProjectileStart" then
		onProjectile(pkt.Kind, pkt.Projectile or pkt)
	elseif type(pkt) == "table" and pkt.Kind == "PlacedModelEntrance" then
		-- Items_Script routes this packet to PlacedModelEntrance.Show: {EntranceId, ItemId, PlacerUserId, Model, StartedAt}.
		-- It is the only place the client learns WHO placed a model (the model carries PlacementEntranceId only).
		if pkt.ItemId == "landmines" and pkt.EntranceId ~= nil then
			Mark.mineOwner = Mark.mineOwner or {}
			Mark.mineOwner[pkt.EntranceId] = pkt.PlacerUserId
			local pl = type(pkt.PlacerUserId) == "number" and playerOf(pkt.PlacerUserId)
			logFile("mine placed", "by", pl and actorName(pl) or tostring(pkt.PlacerUserId), "ours", tostring(pl ~= nil and (pl == LocalPlayer or sameTeam(pl))), "entrance", tostring(pkt.EntranceId))
			Mark.mineCache = nil
		end
	elseif type(pkt) == "table" and pkt.Kind == "HeldItemActivate" then
		pcall(Mark.onItemActivate, pkt)
	elseif type(pkt) == "table" and type(pkt.Kind) == "string" and pkt.Kind:sub(1, 10) == "OilPatches" then
		if pkt.Kind == "OilPatchesClear" then
			table.clear(Mark.oil)
		elseif pkt.Kind == "OilPatchesRemove" then
			Mark.oilRemove(pkt.Patches)
		else
			Mark.oilAdd(pkt.Patches)
		end
	end
end)

do
	local ok, reticle = pcall(function()
		return require(Client.Interface.Reticle)
	end)
	local okUse, use = pcall(function()
		return require(Client.Gameplay.ItemUseState)
	end)
	if ok and reticle and reticle.GetCameraAimRay then
		local oldRay = reticle.GetCameraAimRay
		local oldBare = reticle.GetCameraAimRayWithoutHit
		reticle.GetCameraAimRay = function(...)
			if Mark.skillRay then
				return Mark.skillRay
			end
			local strike = Mark.strikeRay()
			if strike then
				return strike
			end
			return oldRay(...)
		end
		if oldBare then
			reticle.GetCameraAimRayWithoutHit = oldBare
		end
	end
	if okUse and use and use.SetEquippedItem then
		Mark.itemUse = use
		local oldSet = use.SetEquippedItem
		use.SetEquippedItem = function(item, ...)
			Mark.itemId = item and item.ItemId or nil
			return oldSet(item, ...)
		end
	end
end

-- Equipped item id straight from ItemUseState (u3 upvalue of UsesZoom): the SetEquippedItem hook misses an item
-- equipped before the script loaded.
Mark.equippedId = function()
	local use = Mark.itemUse
	if use and use.UsesZoom then
		local ok, id = pcall(upvalue, use.UsesZoom, 2)
		if ok and type(id) == "string" then
			return id
		end
	end
	return Mark.itemId
end

Mark.saDraw = function()
	if not Mark.saCircle then
		local c = newDraw("Circle", 45)
		c.Filled = false
		c.NumSides = 48
		c.Thickness = 1
		c.Transparency = 0.5
		c.Color = COL.Paper
		c.Visible = false
		Mark.saCircle = c
		Mark.saBox = makeLines(8, 1.6, 45)
		local t = newDraw("Text", 46)
		t.Size = 13
		t.Center = true
		t.Outline = true
		t.Font = FONT
		t.Visible = false
		Mark.saText = t
		Mark.saLink = newDraw("Line", 44)
		Mark.saLink.Visible = false
	end
end

-- SilentAim target art: beam muzzle -> chest (ink under-stroke + colour), 4 bright pulses running
-- toward the target (period 0.6 s, white fading into the beam colour), 3 spinning arcs at his feet.
Mark.silentArt = function(seg, muzzle, chest, feet, col, t)
	local hot = Color3.fromRGB(255, 255, 255)
	seg(muzzle, chest, Color3.fromRGB(12, 14, 18), 0.55, 3.2, 44)
	seg(muzzle, chest, col, 0.75, 1.2, 45)
	for n = 0, 3 do
		local f = ((t / 0.6) + n / 4) % 1
		local f2 = math.min(f + 0.06, 1)
		seg(muzzle:Lerp(chest, f), muzzle:Lerp(chest, f2), hot:Lerp(col, f), 1, 2.6, 46)
	end
	local R = 2.2
	for arc = 0, 2 do
		local a0 = t * 2.4 + arc * (math.pi * 2 / 3)
		local prev = nil
		for s = 0, 5 do
			local ang = a0 + s / 5 * (math.pi * 2 / 3 * 0.7)
			local p = feet + Vector3.new(math.cos(ang) * R, 0, math.sin(ang) * R)
			if prev then
				seg(prev, p, col, 1, 2.2, 46)
			end
			prev = p
		end
	end
end

Mark.saHide = function()
	if Mark.saPool then
		Mark.saPool.finish()
	end
	if Mark.saCircle then
		Mark.saCircle.Visible = false
		hideLines(Mark.saBox)
		Mark.saText.Visible = false
		Mark.saLink.Visible = false
	end
end

-- SilentAim lead. Old: pos + velocity * (dist / speed + ping) = a straight line, so any strafe or stop made the aim
-- run ahead of the target and miss. This one keeps a short position history of the picked target and models
-- his steering: velocity persists for an expected time tau (from how often his heading flipped lately), so the
-- expected displacement over the flight is v * tau * (1 - exp(-T / tau)). A straight runner (tau large) gets the
-- full lead, a strafer a fraction of it. The flight time is iterated against the lead point; the target is also seen
-- display-delay + one-way ping behind the server pose.
Mark.projSeed = { freezeGun = 77.8 } -- measured muzzle speed (log "proj speed freezeGun 77.6-77.9"); used until we shoot
-- Freeze gun is NOT a straight shot. ProjectileVfx getLaunchVelocity: FreezeGun -> ProjectileAim.GetPeakVelocity(
-- muzzle, payload, Speed 78, Gravity = workspace.Gravity * 0.3, FieldSettings.GetGroundYAt(muzzle)): the game picks
-- the launch angle so the ice LANDS (reaches ground height) where the aim ray points on screen (endpoint screen
-- ratios vs payload.CameraCFrame). Aiming the ray at his body put the landing point behind him, the arc over him.
-- So: lead his position with the ARC flight time (analytic low arc from the muzzle), then bisect the landing point
-- along muzzle -> him with the game's own GetPeakDirection until the arc is at his HRP height over his spot.
-- Returns the ray direction to send (camera -> landing point) and the led target, or nil (out of range / no solve).
Mark.arcAim = function(id, pick, cam, ping)
	if id ~= "freezeGun" then
		return nil
	end
	Mark.projVfx = Mark.projVfx or require(Modules.Items.ProjectileVfx)
	local cfg = Mark.projVfx.PredictionConfigs[id]
	if not (cfg and cfg.Speed and (cfg.Gravity or 0) > 0) then
		return nil
	end
	Mark.projAimMod = Mark.projAimMod or require(Modules.Items.ProjectileAim)
	Mark.fieldMod = Mark.fieldMod or require(Modules.Gameplay.FieldSettings)
	Mark.heldItems = Mark.heldItems or require(Modules.Items.HeldItems)
	local ch = LocalPlayer.Character
	local muzzle = nil
	pcall(function()
		local att = Mark.heldItems.FindMuzzle(ch, id)
		muzzle = att and att.WorldPosition
	end)
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	muzzle = muzzle or (hrp and hrp.Position)
	if not muzzle then
		return nil
	end
	local spd, g = cfg.Speed, cfg.Gravity
	local okG, groundY = pcall(Mark.fieldMod.GetGroundYAt, muzzle)
	if not okG or type(groundY) ~= "number" then
		groundY = muzzle.Y - 3
	end
	local function flight(P)
		local D = flat(P - muzzle).Magnitude
		local dy = P.Y - muzzle.Y
		local v2 = spd * spd
		local disc = v2 * v2 - g * (g * D * D + 2 * dy * v2)
		if disc < 0 or D < 0.5 then
			return D / spd
		end
		local th = math.atan((v2 - math.sqrt(disc)) / (g * D))
		return D / (spd * math.cos(th))
	end
	local P = Mark.silentLead(pick, cam.CFrame.Position, spd, ping, flight)
	-- self-calibrated vertical bias: after every shot of ours the REAL launch velocity says where the flight crosses the
	-- target's distance (`silent shot ... errY`); the aim point is moved by the measured miss
	local camCF = cam.CFrame
	local camPos = camCF.Position
	local toP = flat(P - muzzle)
	local D = toP.Magnitude
	local u = unitOrNil(toP)
	if not u or D < 3 then
		return nil
	end
	-- the launch direction we WANT: the low ballistic arc muzzle -> led point (speed, 0.3 g)
	local desired = nil
	do
		local v2 = spd * spd
		local dyP = P.Y - muzzle.Y
		local disc = v2 * v2 - g * (g * D * D + 2 * dyP * v2)
		if disc >= 0 then
			local th = math.atan((v2 - math.sqrt(disc)) / (g * D))
			desired = u * math.cos(th) + Vector3.new(0, math.sin(th), 0)
		end
	end
	if not desired then
		if os.clock() - (Mark.arcFailAt or 0) > 1 then
			Mark.arcFailAt = os.clock()
			logFile("silent arc", "out of range", "D", string.format("%.1f", D), "dy", string.format("%.1f", P.Y - muzzle.Y), "max", string.format("%.0f", spd * spd / g))
		end
		return nil
	end
	-- The server (and the game's own prediction) launches with ProjectileAim.GetPeakDirection on the ray we send: the shot
	-- LANDS (at groundY) on the screen point of that ray; a flat/ballistic direction sent as a ray becomes a 33 degree lob
	-- (the log: fallback pitch 9.4 sent, launch pitch 33.3, 23 studs over). So the only knob is the landing point L on the
	-- ground; scan it with the REAL game function, simulate the real flight, take the L whose flight crosses the target's
	-- distance at the target's height. Nothing is learned from shots: the model is the game's own code.
	local function shoot(s)
		local L = Vector3.new(muzzle.X + u.X * s, groundY, muzzle.Z + u.Z * s)
		local d = unitOrNil(L - camPos)
		if not d then
			return nil
		end
		local okD, dir = pcall(Mark.projAimMod.GetPeakDirection, muzzle, { Origin = camPos, Direction = d, CameraCFrame = camCF }, spd, g, groundY)
		if not (okD and typeof(dir) == "Vector3") then
			return nil
		end
		local h = flat(dir)
		local hv = h.Magnitude * spd
		if hv < 1e-3 then
			return nil
		end
		local t = toP:Dot(h.Unit) / hv
		if t <= 0 then
			return nil
		end
		local y = muzzle.Y + dir.Y * spd * t - 0.5 * g * t * t
		return y - P.Y, d, t, dir
	end
	local sMax = spd * spd / g - 2
	local bestS, bestF, bestDir, bestT = nil, math.huge, nil, nil
	local s = math.max(D - 12, 3)
	while s <= math.min(D + 50, sMax) do
		local f, d, t = shoot(s)
		if f and math.abs(f) < bestF then
			bestS, bestF, bestDir, bestT = s, math.abs(f), d, t
		end
		s += 3
	end
	if bestS then
		local s2 = math.max(bestS - 3, 3)
		while s2 <= math.min(bestS + 3, sMax) do
			local f, d, t = shoot(s2)
			if f and math.abs(f) < bestF then
				bestS, bestF, bestDir, bestT = s2, math.abs(f), d, t
			end
			s2 += 0.5
		end
	end
	local maxErr = CFG.ArcMaxErr or 2.5
	if bestDir and bestF <= maxErr then
		Mark.arcLast = { at = os.clock(), mode = "peak", des = math.deg(math.asin(desired.Y)), ray = math.deg(math.asin(bestDir.Y)), D = D, muzzle = muzzle, desDir = desired, P = P, bias = 0, g = g }
		if os.clock() - (Mark.arcLogAt or 0) > 2 then
			Mark.arcLogAt = os.clock()
			logFile("silent arc", id, "D", string.format("%.1f", D), "land", string.format("%.1f", bestS), "t", string.format("%.2f", bestT or 0), "err", string.format("%.2f", bestF), "rayPitch", string.format("%.1f", Mark.arcLast.ray), "groundY", string.format("%.1f", groundY), "muzzle", fmtV(muzzle), "targetY", string.format("%.1f", P.Y))
		end
		return bestDir, P
	end
	-- no landing point puts the flight through the target: aim at his FEET (the shot lands there, the descending ice passes
	-- the body just before it) - never a ballistic direction used as a ray
	local feet = Vector3.new(P.X, groundY, P.Z)
	local dF = unitOrNil(feet - camPos)
	if os.clock() - (Mark.arcFailAt or 0) > 1 then
		Mark.arcFailAt = os.clock()
		logFile("silent arc", "no solve - feet", "D", string.format("%.1f", D), "best err", bestF == math.huge and "-" or string.format("%.1f", bestF), "muzzleY", string.format("%.1f", muzzle.Y), "targetY", string.format("%.1f", P.Y), "groundY", string.format("%.1f", groundY))
	end
	if dF then
		Mark.arcLast = { at = os.clock(), mode = "feet", des = math.deg(math.asin(desired.Y)), ray = math.deg(math.asin(dF.Y)), D = D, muzzle = muzzle, desDir = desired, P = P, bias = 0, g = g }
		return dF, P
	end
	return nil
end

Mark.silentLead = function(pick, camPos, spd, ping, flightFn)
	local ch = pick.Parent
	local now = os.clock()
	local tr = Mark.silentTr
	if not tr or tr.ch ~= ch then
		tr = { ch = ch, s = {} }
		Mark.silentTr = tr
	end
	local s = tr.s
	local cur = flat(pick.Position)
	if #s == 0 or now - s[#s].t >= 0.012 then
		s[#s + 1] = { t = now, p = cur }
		while #s > 2 and now - s[1].t > 1.6 do
			table.remove(s, 1)
		end
	end
	local function velOver(w)
		local n = #s
		if n < 2 then
			return Vector3.zero
		end
		local i = n
		while i > 1 and now - s[i - 1].t <= w do
			i -= 1
		end
		local dt = s[n].t - s[i].t
		if dt < 0.04 then
			return Vector3.zero
		end
		return (s[n].p - s[i].p) / dt
	end
	local vS = velOver(0.16)
	local vL = velOver(0.5)
	-- heading flips in the last ~1.5 s (segments of ~0.12 s; >35 deg between neighbours at real speed)
	local flips, span = 0, 0
	do
		local seg, last = {}, nil
		for i = 1, #s do
			if not last or s[i].t - last.t >= 0.12 then
				if last then
					local v = (s[i].p - last.p) / (s[i].t - last.t)
					seg[#seg + 1] = v
				end
				last = s[i]
			end
		end
		for i = 2, #seg do
			local a, b = seg[i - 1], seg[i]
			if a.Magnitude > 3 and b.Magnitude > 3 then
				if a.Unit:Dot(b.Unit) < 0.82 then
					flips += 1
				end
			elseif (a.Magnitude > 3) ~= (b.Magnitude > 3) then
				flips += 1 -- start / stop counts as a change of plan
			end
		end
		span = #s >= 2 and math.clamp(s[#s].t - s[1].t, 0.3, 1.6) or 0.3
	end
	local tau = math.clamp(span / (flips + 0.6), 0.22, 3.2)
	-- the short window is the freshest heading; blend toward the long one only when they disagree on speed
	local v = vS
	if vS.Magnitude < 1.5 and vL.Magnitude > 3 then
		v = vL * 0.3 -- just stopped: a little residual
	end
	local lag = (CharacterMotion.GetDisplayDelaySeconds(ch) or 0) + ping
	local P = cur
	local T = 0
	for _ = 1, 3 do
		local flight = flightFn and flightFn(Vector3.new(P.X, pick.Position.Y, P.Z)) or (Vector3.new(P.X, pick.Position.Y, P.Z) - camPos).Magnitude / spd
		T = flight + lag
		P = cur + v * (tau * (1 - math.exp(-T / tau)))
	end
	Mark.silentInfo = { tau = tau, flips = flips, T = T, lead = (P - cur).Magnitude, speed = v.Magnitude }
	return Vector3.new(P.X, pick.Position.Y, P.Z)
end

-- AutoWall. A barricade appears PlacementForwardDistance (5, PlaceDownPlacement.Configs.barricades) ahead of our HRP
-- along the flat aim ray. The old trigger waited for the target to be 3.5..6.5 studs away NOW, with no lead: by the time
-- the press reached the server he had run 2-3 studs on, so the wall was late. Two triggers now, both on where he will be
-- when the wall exists (ping + WallLatency):
--   overlap - his predicted position is 3.2..6.8 studs from our predicted position: the wall lands on him;
--   ambush  - he closes on the wall's spot and his path crosses the wall's width before he reaches it: place it early.
-- Own ball: any closing enemy. No ball: the enemy carrier only. The server's stun rule is not in the client dump, so every
-- press is followed up in the log ("wall placed dt .. size .. / wall result .. off .. stun yes|no") to calibrate.
Mark.wallWatch = function()
	local p = Mark.wallPend
	if not p then
		return
	end
	local now = os.clock()
	if now - p.at > 1.6 then
		Mark.wallPend = nil
		logFile("wall result", "no barricade seen in 1.6 s", p.kind)
		return
	end
	if not p.seenAt then
		local world = workspace:FindFirstChild("Misc")
		world = world and world:FindFirstChild("Items")
		if not world then
			return
		end
		for _, inst in world:GetChildren() do
			if inst:GetAttribute("PlacedItemId") == "barricades" and not p.before[inst] then
				p.seenAt = now
				p.inst = inst
				local pos, size
				if inst:IsA("Model") then
					local cf, sz = inst:GetBoundingBox()
					pos, size = cf.Position, sz
				else
					pos, size = inst.Position, inst.Size
				end
				p.wallPos = pos
				Mark.wallHalfSeen = math.clamp(math.max(size.X, size.Z) * 0.5, 2, 12)
				logFile("wall placed", "dt", string.format("%.2f", now - p.at), "kind", p.kind, "size", fmtV(size), "fromUs", string.format("%.1f", flat(pos - p.us).Magnitude), "aimed", string.format("%.1f", flat(p.W - pos).Magnitude))
				break
			end
		end
		return
	end
	if p.proj and now - p.seenAt >= 0.45 then
		Mark.wallPend = nil
		local alive = 0
		for _ in Mark.projLive or {} do
			alive += 1
		end
		logFile("wall result", "block", p.kind, "projectiles still live", alive, "ball", fmtV(Renderer.GetPosition() or Vector3.zero))
		return
	end
	if now - p.seenAt >= 0.45 then
		local tp = CharacterMotion.GetPosition(p.model) or p.root.Position
		local off = flat(tp - p.wallPos)
		local vu = unitOrNil(p.vel)
		local along = vu and off:Dot(vu) or 0
		local okD, down = pcall(Mark.mateDown, p.actor, p.model)
		logFile("wall result", p.kind, p.name, "off", string.format("%.1f", off.Magnitude), "alongHisRun", string.format("%.1f", along), "stun", tostring(okD and down))
		Mark.wallPend = nil
	end
end

-- BarricadeAddon: a wall placed so that an incoming projectile / charged shot hits IT. The wall spawns exactly 5 studs ahead of
-- us along the aim ray (PlaceDownPlacement PlacementForwardDistance), so the wall can only stop what crosses the circle of radius
-- 5 around where we stand when it exists: aim = toward the crossing point of the path with that circle. Timing: the wall is
-- there ping + WallLatency (calibrate from `wall placed dt`) after the press, plus a margin; the path must reach the circle
-- later than that, else the caller falls back to the dodge / pass. Needs the barricades item in hand (placeWall).
-- pathFn(t) = predicted position t seconds from now (nil before it exists). Returns true when the wall was placed.
-- Item slots (Client.Interface.Items keeps them in the 3rd upvalue of UpdateState: { [i] = { ItemId, Count } }).
Mark.itemSlots = function()
	local Items = Mark.itemsMod
	if not Items then
		local okI, mod = pcall(function()
			return require(Client.Interface.Items)
		end)
		if not (okI and type(mod) == "table" and mod.UpdateState) then
			return nil
		end
		Items = mod
		Mark.itemsMod = mod
	end
	local okU, slots = pcall(upvalue, Items.UpdateState, 3)
	if okU and type(slots) == "table" then
		if not Mark.slotsLogged or os.clock() - Mark.slotsLogged > 20 then
			local parts = {}
			for i = 1, 4 do
				local e = slots[i]
				parts[#parts + 1] = i .. "=" .. ((type(e) == "table" and tostring(e.ItemId)) or "-")
			end
			local changed = table.concat(parts, " ")
			if changed ~= Mark.slotsLast then
				Mark.slotsLast = changed
				logFile("item slots", changed)
			end
			Mark.slotsLogged = os.clock()
		end
		return slots
	end
	return nil
end

Mark.slotOfItem = function(id)
	local s = Mark.itemSlots()
	if not s then
		return nil
	end
	for i = 1, 4 do
		local e = s[i]
		if type(e) == "table" and e.ItemId == id then
			return i
		end
	end
	return nil
end

-- Press an item slot like the keyboard does: the game's own UserInputService.InputBegan handler (Items script) gets the
-- Item<i> input and runs useSlot(i) - equip, or unequip when it is already the equipped one.
Mark.pressSlot = function(i)
	local input = Controls.CreateInput("Item" .. tostring(i))
	local UIS = game:GetService("UserInputService")
	local okC, conns = pcall(getconnections, UIS.InputBegan)
	if not (okC and type(conns) == "table") then
		return false, "noconns"
	end
	local fallback = nil
	for _, c in conns do
		local f = c.Function
		if type(f) == "function" then
			local okS, src = pcall(debug.info, f, "s")
			if okS and type(src) == "string" then
				if src:match("Gameplay%.Items$") then
					task.spawn(f, input, false)
					return true
				elseif src:match("%.Items$") and not src:find("Interface", 1, true) then
					fallback = fallback or f
				end
			end
		end
	end
	if fallback then
		task.spawn(fallback, input, false)
		return true
	end
	return false, "nohandler"
end

Mark.equipWall = function(tag)
	local now = os.clock()
	if now - (Mark.wallEquipAt or 0) < 0.8 then
		return true
	end
	if Ragdoll.IsActorRagdolled(LocalPlayer) or ActionLocks.HasItemEquipBlock(LocalPlayer) then
		return false
	end
	local slot = Mark.slotOfItem("barricades")
	if not slot then
		return false
	end
	local ok, why = Mark.pressSlot(slot)
	Mark.wallEquipAt = now
	Mark.wallEquipSlot = slot
	logFile("wall equip", tag or "-", "slot", slot, ok and "sent" or ("no " .. tostring(why)))
	return ok
end

-- Not equipped yet and a closing enemy carrier / a charging shot is coming: take the barricades out in time
Mark.wallEquipTick = function(root, oid, own)
	if not CFG.AutoWall or CFG.WallEquip == false then
		return
	end
	local use = Mark.itemUse
	if not (use and use.ActivateEquipped) then
		return
	end
	local now = os.clock()
	local isWall = use.IsEquipped and use.IsEquipped() and Mark.equippedId() == "barricades"
	if isWall then
		-- unequip what we took out and did not use (an equipped item blocks ball controls)
		if Mark.wallEquipAt and now - Mark.wallEquipAt > (CFG.WallEquipHold or 3.5) and now - (Mark.skillAt or 0) > (CFG.WallEquipHold or 3.5) then
			Mark.wallEquipAt = nil
			local slot = Mark.wallEquipSlot or Mark.slotOfItem("barricades")
			if slot then
				Mark.pressSlot(slot)
				logFile("wall equip", "idle - put away", "slot", slot)
			end
		end
		return
	end
	if own or not Mark.slotOfItem("barricades") then
		return
	end
	if use.IsEquipped and use.IsEquipped() then
		return -- some other item is in hand: leave it
	end
	-- 1) a shot that is being charged goes into our mouth
	if CFG.WallShot ~= false and Mark.wallVsShot(root) then
		return
	end
	-- 2) the enemy carrier closes on us
	if type(oid) ~= "number" or oid == 0 then
		return
	end
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and actor.UserId == oid and not sameTeam(actor) and not isGoalkeeper(actor) then
			local r = ActorTargeting.GetActorRoot(actor)
			if r then
				local pos, vel = Mark.carrierPose(r, model)
				local rel = flat(pos - root.Position)
				local d = rel.Magnitude
				if d > 6 and d <= (CFG.WallEquipDist or 26) then
					local closeV = -(vel - flat(root.AssemblyLinearVelocity)):Dot(rel / d)
					if closeV >= (CFG.WallAmbushV or 4.5) and d / closeV <= 1.6 then
						Mark.equipWall("carrier " .. string.format("d %.1f closeV %.1f", d, closeV))
					end
				end
			end
		end
	end
end

Mark.wallVsPath = function(root, pathFn, tEnd, tag)
	if CFG.BarricadeAddon == false or not CFG.AutoWall then
		return false
	end
	local use = Mark.itemUse
	if not (use and use.ActivateEquipped) then
		return false
	end
	local equipped = use.IsEquipped and use.IsEquipped() and Mark.equippedId() == "barricades"
	if not equipped and not Mark.slotOfItem("barricades") then
		return false
	end
	if os.clock() - (Mark.skillAt or 0) < (CFG.WallCooldown or 0.7) then
		return false
	end
	if Mark.wallPend and Mark.wallPend.seenAt == nil and os.clock() - Mark.wallPend.at < 0.5 then
		return false
	end
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local lat = ping + (CFG.WallLatency or 0.08)
	local ready = lat + (CFG.WallMargin or 0.12)
	local us = root.Position + flat(root.AssemblyLinearVelocity) * lat
	local FWD = 5
	local half = Mark.wallHalfSeen or CFG.WallHalf or 4
	local floorY = root.Position.Y - 3
	local hMax = CFG.WallHeight or 6
	local prevD, prevQ, prevT = nil, nil, nil
	local hit = nil
	local t = 0
	while t <= tEnd + 0.25 do
		local q = pathFn(t)
		if q then
			local d = flat(q - us).Magnitude
			if prevD and prevD > FWD and d <= FWD then
				local k = (prevD - FWD) / math.max(prevD - d, 1e-3)
				hit = { q = prevQ:Lerp(q, k), t = prevT + (t - prevT) * k }
				break
			elseif not prevD and d <= FWD then
				return false -- already inside the circle: nothing left to place
			end
			prevD, prevQ, prevT = d, q, t
		end
		t += 0.02
	end
	if not hit then
		return false
	end
	if hit.t < ready then
		return false, "late"
	end
	if not equipped then
		-- take the barricades out first (the key press + the server's echo take WallEquipDelay), place on the next tick
		if hit.t < ready + (CFG.WallEquipDelay or 0.3) then
			return false, "late equip"
		end
		if Mark.equipWall(tag) then
			return "equip", "equip"
		end
		return false, "equip failed"
	end
	local qy = hit.q.Y - floorY
	if qy < -1.5 or qy > hMax + 1 then
		return false, "height"
	end
	local to = unitOrNil(flat(hit.q - us))
	if not to then
		return false
	end
	local W = us + to * FWD
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and sameTeam(actor) then
			local ar = ActorTargeting.GetActorRoot(actor)
			if ar and flat(ar.Position - W).Magnitude < 3.5 then
				return false, "mate"
			end
		end
	end
	local o = root.Position + Vector3.new(0, 1.6, 0)
	local before = {}
	local world = workspace:FindFirstChild("Misc")
	world = world and world:FindFirstChild("Items")
	if world then
		for _, inst in world:GetChildren() do
			if inst:GetAttribute("PlacedItemId") == "barricades" then
				before[inst] = true
			end
		end
	end
	Mark.skillRay = { Origin = o, Direction = to, CameraCFrame = CFrame.lookAt(o, o + to) }
	Mark.skillAt = os.clock()
	use.ActivateEquipped()
	Mark.wallPend = { at = os.clock(), proj = true, name = tag, kind = tag, us = root.Position, W = W, before = before }
	logFile("skill wall", "block", tag, "hitIn", string.format("%.2f", hit.t), "ready", string.format("%.2f", ready), "q", fmtV(hit.q), fmtV(to))
	return true
end

-- the replicated charge as a path: the shot that is being charged crosses the circle around us -> wall on it
Mark.wallVsShot = function(root)
	local oid = liveOwnerId()
	if type(oid) ~= "number" or oid == 0 or oid == LocalPlayer.UserId then
		return false
	end
	local rec = Mark.charges and Mark.charges[oid]
	if not (rec and rec.live and os.clock() - (rec.seen or 0) < 0.6) then
		return false
	end
	local cs = Mark.chargeShot(oid)
	local g = Mark.defendGoal()
	if not (cs and g) then
		return false
	end
	local lb, lt, rb = goalMouthCorners(g)
	if not (lb and lt and rb) then
		return false
	end
	local mouth = (lb + rb) * 0.5
	local sideV = unitOrNil(flat(rb - lb))
	if not sideV then
		return false
	end
	local out = Vector3.new(-sideV.Z, 0, sideV.X)
	if flat(cs.launch - mouth):Dot(out) < 0 then
		out = -out
	end
	local half = flat(rb - lb).Magnitude * 0.5
	local onTarget = false
	for i = 2, #cs.pts do
		local p = cs.pts[i]
		if flat(p - mouth):Dot(out) <= 0.3 then
			onTarget = math.abs(flat(p - mouth):Dot(sideV)) <= half + 2.5 and p.Y <= math.max(lt.Y, lb.Y) + 1.5
			break
		end
	end
	if not onTarget then
		return false
	end
	local minRel = KickCore.GetMinimumReleaseSeconds and KickCore.GetMinimumReleaseSeconds() or 0.2
	local tRel = math.max(minRel - (os.clock() - rec.at), 0)
	return Mark.wallVsPath(root, function(t)
		if t < tRel then
			return nil
		end
		return Mark.chargeAt(cs, t - tRel)
	end, tRel + 1.2, "shot")
end

Mark.wallTick = function(root, oid, own, use, ping)
	Mark.wallWatch()
	if not CFG.AutoWall or os.clock() - (Mark.skillAt or 0) < (CFG.WallCooldown or 0.7) or not use.ActivateEquipped then
		return
	end
	if Mark.wallPend and Mark.wallPend.seenAt == nil and os.clock() - Mark.wallPend.at < 0.5 then
		return -- the last one has not appeared yet
	end
	-- the shot that is being charged flies through the circle the wall can reach: block it with the wall
	if not own and CFG.WallShot ~= false and Mark.wallVsShot(root) then
		return
	end
	local FWD = 5
	local lat = ping + (CFG.WallLatency or 0.08)
	local ourV = flat(root.AssemblyLinearVelocity)
	local us = root.Position + ourV * lat
	local half = Mark.wallHalfSeen or CFG.WallHalf or 4
	local best = nil
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) and not isGoalkeeper(actor) then
			local isOwner = type(oid) == "number" and actor.UserId == oid
			if own or isOwner then
				local r = ActorTargeting.GetActorRoot(actor)
				if r then
					local pos, vel = Mark.carrierPose(r, model)
					if vel.Magnitude > 32 then
						vel = vel.Unit * 32
					end
					local leadMode = CFG.WallLead or "away"
					local rel0 = flat(pos - us)
					local fleeing = rel0.Magnitude > 0.5 and (vel - ourV):Dot(rel0.Unit) > 0.5
					local P = (leadMode == "always" or (leadMode == "away" and fleeing)) and (pos + vel * lat) or pos
					local rel = flat(P - us)
					local d = rel.Magnitude
					if d > 0.5 then
						local toward = rel / d
						local rv = vel - ourV
						local closeV = -rv:Dot(toward) -- > 0: he is closing on us
						local kind, score = nil, nil
						if d >= (CFG.WallMin or 3.2) and d <= (CFG.WallMax or 6.8) and (not own or closeV > 1) and closeV > -3 then
							kind, score = "overlap", math.abs(d - FWD)
						elseif CFG.WallAmbush ~= false and d > (CFG.WallMax or 6.8) and d <= (CFG.WallReach or 28) and closeV >= (CFG.WallAmbushV or 4.5) then
							local tHit = (d - FWD) / closeV
							local q = rel + rv * tHit
							local latOff = (q - toward * q:Dot(toward)).Magnitude
							if tHit >= 0.05 and tHit <= (CFG.WallAmbushT or 1.0) and latOff <= half * 0.8 then
								kind, score = "ambush", 10 + tHit
							end
						end
						if kind and (not best or score < best.score) then
							best = { actor = actor, model = model, root = r, toward = toward, d = d, closeV = closeV, kind = kind, score = score, vel = vel, P = P }
						end
					end
				end
			end
		end
	end
	if not best then
		return
	end
	local W = us + best.toward * FWD
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and sameTeam(actor) then
			local ar = ActorTargeting.GetActorRoot(actor)
			if ar and flat(ar.Position - W).Magnitude < 3.5 then
				return -- a teammate would be walled in
			end
		end
	end
	local to = best.toward
	local o = root.Position + Vector3.new(0, 1.6, 0)
	local before = {}
	local world = workspace:FindFirstChild("Misc")
	world = world and world:FindFirstChild("Items")
	if world then
		for _, inst in world:GetChildren() do
			if inst:GetAttribute("PlacedItemId") == "barricades" then
				before[inst] = true
			end
		end
	end
	Mark.skillRay = { Origin = o, Direction = to, CameraCFrame = CFrame.lookAt(o, o + to) }
	Mark.skillAt = os.clock()
	use.ActivateEquipped()
	Mark.wallPend = { at = os.clock(), actor = best.actor, model = best.model, root = best.root, name = actorName(best.actor), kind = best.kind, us = root.Position, W = W, vel = best.vel, before = before }
	logFile("skill wall", own and "own" or "carrier", best.kind, actorName(best.actor), "predD", string.format("%.1f", best.d), "closeV", string.format("%.1f", best.closeV), "lat", string.format("%.2f", lat), fmtV(to))
end

Mark.tickSkill = function(character, root)
	Mark.skillRay = nil
	Mark.silentRay = nil
	for i = 1, 8 do
		fovLines[i].Visible = false
		resLines[i].Visible = false
	end
	local use = Mark.itemUse
	local cam = Workspace.CurrentCamera
	do
		local okE, errE = pcall(Mark.wallEquipTick, root, liveOwnerId(), liveOwnerId() == LocalPlayer.UserId)
		if not okE and (not Mark.wallEquipErr or os.clock() - Mark.wallEquipErr > 3) then
			Mark.wallEquipErr = os.clock()
			logFile("wall equip err", tostring(errE))
		end
	end
	if not (use and use.IsEquipped and use.IsEquipped() and cam) then
		Mark.saHide()
		return
	end
	local id = Mark.equippedId()
	Mark.itemAim = Mark.itemAim or require(Modules.Items.ItemAim)
	local aimGun = id ~= nil and Mark.itemAim.UsesGunReticle(id)
	local placeWall = id == "barricades"
	if not aimGun then
		Mark.saHide()
	end
	local ping = LocalPlayer:GetNetworkPing()
	local oid = liveOwnerId()
	local own = oid == LocalPlayer.UserId

	-- AutoWall. Barricades land PlacementDistance 5 ahead along the placement (camera) direction
	-- (PlaceDownPlacement.GetPlacementPosition). Own ball: wall the nearest closing opponent; no ball: wall the enemy
	-- carrier only. Current pose, no lead.
	if placeWall then
		Mark.wallTick(root, oid, own, use, ping)
		return
	end
	if not aimGun then
		return
	end

	-- SilentAim. Gun-reticle items (ItemAim.UsesGunReticle: flintlock, freezeGun, bazooka, shotgun) fire with
	-- Reticle.GetCameraAimRay -> getAimRayPayload(u1.GetCameraRay(), hitQuery): replacing GetCameraRay keeps the
	-- game's own payload (ClientHit/TargetPosition from its hit query on the target). Priority: enemy carrier in the
	-- FOV circle, else nearest enemy in it, else untouched.
	Mark.saDraw()
	-- centre = where the game's own gun ray points. Reticle.GetCameraRay works in GUI space (AbsolutePosition /
	-- ViewportSize * GunScreenPosition MINUS GuiInset, then ScreenPointToRay); Drawing is viewport space, so the old
	-- AbsolutePosition centre sat one top-bar inset too high. Projecting the real ray removes the mismatch.
	local center
	do
		local okR, ray = pcall(Mark.oldCamRay or Reticle.GetCameraRay)
		if okR and ray then
			local sp = cam:WorldToViewportPoint(ray.Origin + ray.Direction.Unit * 60)
			center = Vector2.new(sp.X, sp.Y)
		else
			center = cam.ViewportSize * (Reticle.GunScreenPosition or Vector2.new(0.5, 0.5))
		end
	end
	local fov = CFG.SilentFov
	Mark.saCircle.Position = center
	Mark.saCircle.Radius = fov
	Mark.saCircle.Visible = CFG.SilentAim and CFG.DrawSilentFov ~= false
	if not CFG.SilentAim then
		Mark.saHide()
		return
	end
	local pick, pickD, pickOwner = nil, math.huge, false
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) then
			local r = ActorTargeting.GetActorRoot(actor)
			if r then
				local sp, on = cam:WorldToViewportPoint(r.Position)
				if on and sp.Z > 0 then
					local scr = Vector2.new(sp.X, sp.Y)
					if (scr - center).Magnitude <= fov then
						local isOwner = type(oid) == "number" and actor.UserId == oid
						local d = (r.Position - root.Position).Magnitude
						if (isOwner and not pickOwner) or (isOwner == pickOwner and d < pickD) then
							pick, pickD, pickOwner = r, d, isOwner
						end
					end
				end
			end
		end
	end
	if not pick then
		hideLines(Mark.saBox)
		Mark.saText.Visible = false
		Mark.saLink.Visible = false
		if Mark.saPool then
			Mark.saPool.finish()
		end
		return
	end
	local aimP = pick.Position
	local spd = (Mark.projSpeed and Mark.projSpeed[id]) or Mark.projSeed[id]
	local camPos = cam.CFrame.Position
	local arcDir, arcP = Mark.arcAim(id, pick, cam, ping)
	if arcDir then
		aimP = arcP
	elseif spd and spd > 10 then
		-- projectile: lead by its measured muzzle speed (our ProjectileStart events, seeded for the freeze gun)
		aimP = Mark.silentLead(pick, camPos, spd, ping)
		local si = Mark.silentInfo
		if si and si.lead > 1 and os.clock() - (Mark.silentLogAt or 0) > 2 then
			Mark.silentLogAt = os.clock()
			logFile("silent lead", id, "tau", string.format("%.2f", si.tau), "flips", si.flips, "T", string.format("%.2f", si.T), "lead", string.format("%.1f", si.lead), "v", string.format("%.1f", si.speed))
		end
	end
	local dir = arcDir or unitOrNil(aimP - camPos)
	if dir then
		Mark.silentRay = Ray.new(camPos, dir)
	end
	-- visual: a world-space tracer from the weapon muzzle (HeldItems.FindMuzzle) to the target, with light pulses
	-- running down it toward him, plus a spinning split ring at his feet and his name. Reads in one glance as "this
	-- gun -> that player", unlike the old 2D brackets.
	local col = pickOwner and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(90, 220, 255)
	Mark.heldItems = Mark.heldItems or require(Modules.Items.HeldItems)
	local muzzle = nil
	pcall(function()
		local att = Mark.heldItems.FindMuzzle(LocalPlayer.Character, id)
		muzzle = att and att.WorldPosition
	end)
	muzzle = muzzle or (root.Position + Vector3.new(0, 1.2, 0) + flat(cam.CFrame.LookVector) * 1.5)
	local chest = aimP + Vector3.new(0, 0.6, 0)
	Mark.saLines = Mark.saLines or makeLines(48, 1.4, 46)
	Mark.saPool = Mark.saPool or Mark.segPool(Mark.saLines)
	local pool = Mark.saPool
	if CFG.DrawSilent ~= false then
		Mark.silentArt(pool.seg, muzzle, chest, Vector3.new(aimP.X, aimP.Y - 2.9, aimP.Z), col, os.clock())
	end
	pool.finish()
	hideLines(Mark.saBox)
	Mark.saLink.Visible = false
	Mark.saText.Visible = false
end

-- Dive search with the game's own model. role.Dive() turns the move command into one of 8 DirectionChoices
-- relative to the CAMERA (GoalkeeperDive.GetDirectionChoice) and the assist may yaw it only +-12 deg
-- (GoalkeeperDiveAssist MaximumYawDegrees). Our old dive aimed a free vector at the path point, so the game snapped
-- it up to 22.5 deg away: a corner shot 12 studs out was missed by ~4.5 studs. Here every choice is run through
-- GoalkeeperDiveAssist.GetAssist (extra reach <= 3, travel scale 0.3-1.3, lift, yaw) and then FindFlightIntercept with
-- that assisted dive; the save hitbox is AirReceive grown by max(1.25, 2*BallRadius) (GoalkeeperActions), so a
-- residual miss under half of that pad is contact.
-- Our own dive model (primary): the dive is GoalkeeperDive.GetTravel (cubic-out, Distance over DurationSeconds) along
-- one of the 8 camera-relative choices plus GetVerticalTravel; the save box is AirReceive grown by the contact pad
-- (GoalkeeperActions: max(1.25, 2*BallRadius)) and 2*SaveReachStuds along the dive. Every ball path sample
-- (Mark.ballPath, world collisions) inside SaveWindowSeconds is tested after our input delay. Independent of the
-- game's assist, which only nudges.
Mark.gkOwnDive = function(root, td)
	td = td or 0
	local yJ = 0
	if td > 0 then
		local gW = Workspace.Gravity
		yJ = math.max(math.sqrt(2 * gW * (Mark.jumpH or 7.2)) * td - 0.5 * gW * td * td, 0)
	end
	local D = Mark.gkDiveMod
	Mark.actionMotion = Mark.actionMotion or require(Modules.Actions.ActionMotion)
	local cam = Workspace.CurrentCamera
	if not (D and cam) then
		return nil
	end
	local _, _, samples, ts = Mark.ballPath(root)
	if not samples then
		return nil
	end
	local facing = unitOrNil(flat(root.CFrame.LookVector)) or Vector3.new(0, 0, 1)
	local ar = HitboxSettings.AirReceive
	local pad = math.max(1.25, (Physics.BallRadius or 1) * 2)
	local box = { Size = ar.Size + Vector3.new(pad, pad, pad + 2 * D.Constants.SaveReachStuds), Shape = ar.Shape, CFrameOffset = ar.CFrameOffset }
	local dist = D.GetDistance(LocalPlayer)
	local delay = math.clamp(LocalPlayer:GetNetworkPing(), 0, 0.3) * 0.5 + 0.03
	local win = D.Constants.SaveWindowSeconds
	local best = nil
	for name, choice in Mark.actionMotion.DirectionChoices do
		local okW, wd = pcall(D.GetWorldDirection, choice, cam.CFrame, facing)
		-- no backward dives: the backward dive arches the body back and lowers the save box (user: the ball went over
		-- the head on a "B" dive); our box model does not have that pose
		if okW and typeof(wd) == "Vector3" and (not Mark.gkFwd or wd:Dot(Mark.gkFwd) > -0.3) then
			local hold = { CFrame = CFrame.lookAlong(root.Position, wd) }
			for i = 2, #samples do
				local t = ts[i] - delay - td
				if t > win then
					break
				end
				-- goal line: a save at or behind the mouth plane is already a goal (user: dived inward diagonally,
				-- touched the ball after it crossed). Ball sample and keeper pose must both stay in front of the line.
				local mouth = Mark.gkMouth
				local gf = Mark.gkFwd
				local ballR = Physics.BallRadius or 1
				if mouth and gf and (samples[i] - mouth.c):Dot(gf) < ballR + 0.3 then
					break
				end
				if t > 0 then
					local pos = root.Position + wd * D.GetTravel(t, dist) + Vector3.new(0, D.GetVerticalTravel(t) + yJ, 0)
					if mouth and gf and (pos - mouth.c):Dot(gf) < 0.3 then
						break
					end
					hold.CFrame = CFrame.lookAlong(pos, wd)
					-- segment test: path samples are ~6 studs apart at shot speed, a point test skips through the box
					if HitboxSettings.GetSegmentEnterAlpha(hold, box, samples[i - 1], samples[i]) then
						if not best or t < best.t then
							best = { name = name, wd = wd, t = t, miss = 0, own = true, td = td }
						end
						break
					end
				end
			end
		end
	end
	return best
end

Mark.gkDiveSearch = function(root, state, world)
	local A = Mark.gkAssist
	local D = Mark.gkDiveMod
	if not (A and D and state and world and A.FindFlightIntercept and A.GetAssist) then
		return nil
	end
	Mark.actionMotion = Mark.actionMotion or require(Modules.Actions.ActionMotion)
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local t0 = Workspace:GetServerTimeNow()
	pcall(function()
		Mark.cms = Mark.cms or require(game:GetService("ReplicatedStorage").Client.Player.CharacterMotionSmoothing)
		t0 = Mark.cms.GetSmoothedServerTime()
	end)
	local facing = unitOrNil(flat(root.CFrame.LookVector)) or Vector3.new(0, 0, 1)
	local pad = math.max(1.25, (Physics.BallRadius or 1) * 2) * 0.5
	local dist = D.GetDistance(LocalPlayer)
	local best = nil
	for name, choice in Mark.actionMotion.DirectionChoices do
		local okW, wd = pcall(D.GetWorldDirection, choice, cam.CFrame, facing)
		local nearLine = Mark.gkMouth and Mark.gkFwd and (root.Position - Mark.gkMouth.c):Dot(Mark.gkFwd) < 8
		-- assist path has no line check of its own: close to the line, no direction with an inward component
		if okW and typeof(wd) == "Vector3" and (not Mark.gkFwd or wd:Dot(Mark.gkFwd) > (nearLine and -0.05 or -0.3)) then
			local okA, assist = pcall(A.GetAssist, state, world, root, wd, t0)
			assist = okA and assist or nil
			local v0 = D.Constants.InitialVerticalVelocity
			local g = D.Constants.GravityStudsPerSecondSquared
			local dive = { CanExtendReach = false, ElapsedSeconds = 0, WarpedSeconds = 0, TravelScale = 1, Distance = dist }
			local dir = wd
			if assist then
				dive.TravelScale = assist.TravelScale or 1
				dive.Distance = dist + (assist.ExtraDistance or 0)
				v0 = assist.InitialVerticalVelocity or v0
				g = assist.Gravity or g
				dir = D.RotateFlatDirection(wd, assist.YawRadians or 0)
			end
			dive.GetVerticalOffset = function(s)
				return math.max(0, s * (v0 + 0.5 * g * s))
			end
			local okI, ic = pcall(A.FindFlightIntercept, state, world, root.CFrame, dir, t0, dive)
			if okI and type(ic) == "table" and ic.MissDistance and ic.MissDistance <= pad then
				if not best or ic.MissDistance < best.miss then
					best = { name = name, wd = wd, miss = ic.MissDistance, t = ic.OffsetSeconds, assisted = assist ~= nil }
				end
			end
		end
	end
	return best
end

-- Trust but verify the goal read. pred.GetGoalCrossing is the game's own preview; when it answers nothing the old code
-- fell back to the plane time / a straight line - both ignore the walls, so a BounceFAKE (aimed at the wall around the
-- goal, it comes BACK to the shooter) looked like a shot and drew a dive. Mark.ballPath is the same physics WITH world
-- collisions. Verdicts over its samples (distance to the mouth plane `a`):
--   goal   - the path crosses the plane inside the mouth (+0.8 slack) -> point and time of the crossing;
--   bounce - it moved toward the goal by >= 1 stud and then turned back before the plane (wall / post / bar) -> no shot;
--   wide   - it crosses the plane outside the mouth;
--   none   - it never gets there inside the sampled window.
Mark.gkVerify = function(samples, ts, c, fwd, side, half, bottomY, topY)
	local prevA, dec = nil, 0
	for i = 1, #samples do
		local a = flat(samples[i] - c):Dot(fwd)
		if prevA then
			if a < 0 and prevA >= 0 then
				local k = prevA / math.max(prevA - a, 1e-4)
				local p = samples[i - 1]:Lerp(samples[i], k)
				local s = flat(p - c):Dot(side)
				local inMouth = math.abs(s) <= half + 0.8 and p.Y >= bottomY - 0.8 and p.Y <= topY + 0.8
				return inMouth and "goal" or "wide", p, ts[i - 1] + (ts[i] - ts[i - 1]) * k
			elseif a > prevA + 0.4 and dec >= 1.0 then
				return "bounce", samples[i - 1], ts[i - 1]
			end
			if a < prevA then
				dec += prevA - a
			end
		end
		prevA = a
	end
	return "none"
end

-- AutoGK x enemy FAKE. A FAKE shot (AutoShoot / any human) is aimed THROUGH a teammate of the shooter so that, if nobody
-- touched it, it would end in our goal: the game's goal-crossing preview shows a shot, the dive commits, and the ball is
-- received by his teammate (Receiving.Constants.TeammateKickIgnoresSpeedThreshold = true: the shooter's teammates control
-- a Shot at ANY speed) - the keeper is on the floor, the second enemy scores. So before a dive is allowed the predicted
-- ball path (Mark.ballPath samples, world collisions) is tested against every enemy's receive volume at the time the ball
-- gets there (HitboxSettings.Receive grounded / AirReceive airborne, server pose = displayed + v*(display delay + t)).
-- A solid hit (the path goes through the box shrunk by BaitInset on each side) before the goal crossing = bait: no dive,
-- no walk to the crossing point. It is re-evaluated every frame, so a ball that really passes him (he dodged / was
-- ragdolled / the path moved) turns into a normal shot with whatever time is left. The first 0.2 s after a kick are
-- ignored for the kicker himself (Ownership.LaunchNoTouchSeconds 0.25).
-- returns { t, name, dist } or nil
Mark.gkBait = function(samples, ts, limit)
	if not samples or #samples < 2 then
		return nil
	end
	local inset = CFG.GkBaitInset or 0.6
	local rcv, air = HitboxSettings.Receive, HitboxSettings.AirReceive
	local mates = {}
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) then
			local r = ActorTargeting.GetActorRoot(actor)
			if r and not Mark.mateDown(actor, model) then
				local pos = CharacterMotion.GetPosition(model) or r.Position
				local vel = flat(CharacterMotion.GetVelocity(model) or Vector3.zero)
				local dly = math.clamp(CharacterMotion.GetDisplayDelaySeconds(model) or 0, 0, 0.25)
				local hum = model:FindFirstChildOfClass("Humanoid")
				local landed = not hum or CharacterControllers.IsLanded(model, hum)
				local src0 = landed and rcv or air
				mates[#mates + 1] = {
					name = actorName(actor), pos = pos, vel = vel, dly = dly,
					box = {
						Size = Vector3.new(math.max(src0.Size.X - inset * 2, 1), math.max(src0.Size.Y - inset * 2, 1), math.max(src0.Size.Z - inset * 2, 1)),
						Shape = src0.Shape, CFrameOffset = src0.CFrameOffset,
					},
				}
			end
		end
	end
	if #mates == 0 then
		return nil
	end
	for i = 2, #samples do
		local t = ts[i]
		if t > limit then
			break
		end
		if t >= 0.2 then
			for _, m in mates do
				local lead = m.dly + math.min(t, 0.5)
				local c = m.pos + m.vel * lead
				local hold = { CFrame = CFrame.new(c) }
				local ok, alpha = pcall(HitboxSettings.GetSegmentEnterAlpha, hold, m.box, samples[i - 1], samples[i])
				if ok and alpha then
					return { t = ts[i - 1] + (ts[i] - ts[i - 1]) * (type(alpha) == "number" and alpha or 1), name = m.name, dist = flat(c - samples[1]).Magnitude }
				end
			end
		end
	end
	return nil
end

-- PRESS: a forward dive INTO the attacker (the dive stuns the player it hits - the server rule and the hit radius are not in
-- the client dump: CFG.PressReach / PressVert are estimates, every press logs "gk press result" with the closest approach
-- and his state 1 s later to calibrate them). Targets an enemy CARRIER who will otherwise run / fly into the goal (the
-- rocket-down jump: airborne at 60+ studs/s, the walk/jump/dive-for-the-ball logic has nothing to save). Only when the
-- real dive curve (GoalkeeperDive.GetTravel / GetVerticalTravel, 8 camera-relative DirectionChoices, same as gkOwnDive)
-- meets his predicted body (server pose = displayed + v*(display delay + ping/2); ballistic Y when airborne) before he
-- crosses the goal line, inside CFG.PressDist (dive distance - 2: "slightly less than the dive radius"). Not against
-- a charging carrier (that is a shot: the save logic owns it), an iframe, or a downed player.
Mark.gkPress = function(character, root, c)
	if CFG.GkPress == false then
		return false
	end
	if c.now - (Mark.gkDive or 0) <= c.diveMod.Constants.RepeatDelaySeconds + 0.05 then
		return false
	end
	local pl, er = enemyCarrier(c.ownerId)
	if not (pl and er) then
		return false
	end
	local model = Actors.GetCharacter(pl)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local function skip(why)
		if not Mark.gkPressLog or c.now - Mark.gkPressLog > 0.6 then
			Mark.gkPressLog = c.now
			logFile("gk press skip", why, actorName(pl))
		end
		return false
	end
	if not (model and hum) then
		return false
	end
	if Dodge.IsDribbling(model) then
		return skip("iframe")
	end
	if Mark.mateDown(pl, model) then
		return skip("down")
	end
	local crec = Mark.charges and Mark.charges[pl.UserId]
	if crec and crec.live and c.now - (crec.seen or 0) < 0.6 then
		return skip("charging")
	end
	local P, V, W = Mark.carrierPose(er, model)
	local vf = flat(W)
	if vf.Magnitude > V.Magnitude then
		V = vf -- a launched player (rocket jump) moves faster than the walk-speed clamps of carrierPose assume
	end
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local delay = math.clamp(CharacterMotion.GetDisplayDelaySeconds(model) or 0, 0, 0.25)
	local lead = delay + ping * 0.5
	local airborne = not CharacterControllers.IsLanded(model, hum)
	local g = workspace.Gravity
	-- His vertical speed: the displayed velocity (CharacterMotion.GetVelocity) has Y = 0 for another player (log: "air true vy 0.0"
	-- on a flier -> the pose fell like a stone to our height and the dive "connected" with a man several times higher). Track his
	-- displayed Y ourselves: finite difference between polls, smoothed.
	Mark.yTrack = Mark.yTrack or setmetatable({}, { __mode = "k" })
	local yt = Mark.yTrack[model]
	local vyT = 0
	if yt and c.now - yt.t > 0.02 and c.now - yt.t < 0.4 then
		local raw = (P.Y - yt.y) / (c.now - yt.t)
		vyT = yt.vy * 0.5 + raw * 0.5
		Mark.yTrack[model] = { y = P.Y, t = c.now, vy = vyT }
	elseif not yt or c.now - yt.t >= 0.4 then
		Mark.yTrack[model] = { y = P.Y, t = c.now, vy = 0 }
	else
		vyT = yt.vy
	end
	local vy = 0
	if airborne then
		vy = (math.abs(W.Y) > 0.5) and W.Y or vyT
	end
	local groundY = P.Y
	-- JETPACK (JetpackMotion: lift 25 studs over 1 s after a 0.5 s delay, 55 studs flat over 3.5 s, steerable): no gravity while
	-- it burns, the vertical speed is kept and capped at the lift height
	Mark.jetM = Mark.jetM or require(Modules.Actions.JetpackMotion)
	local okJ, jetOn = pcall(Mark.jetM.IsActive, pl)
	jetOn = okJ and jetOn == true
	local function pose(t) -- his server pose t seconds after our dive starts
		local tt = lead + t
		local y
		if jetOn then
			y = math.clamp(P.Y + vy * tt, groundY, groundY + (Mark.jetM.Constants.LiftDistance or 25))
		else
			y = airborne and math.max(P.Y + vy * tt - 0.5 * g * tt * tt, root.Position.Y - 1) or groundY
		end
		return Vector3.new(P.X + V.X * tt, y, P.Z + V.Z * tt)
	end
	-- an airborne man's vertical motion is not known for sure (rocket = ballistic, grapple / jetpack = no gravity): a dive
	-- needs the contact under BOTH readings (ballistic and straight line), otherwise we dive under / at a man who is far higher
	local function poseY2(t)
		local tt = lead + t
		return P.Y + vy * tt
	end
	local fwd, side, mouth = c.fwd, c.side, c.mouth
	local E0 = pose(0)
	local rel = flat(E0 - mouth)
	local along, lat = rel:Dot(fwd), rel:Dot(side)
	if along < -1 then
		return skip("behind line")
	end
	local vIn = -V:Dot(fwd)
	local tG = vIn > 3 and math.max(along, 0) / vIn or math.huge
	local latG = lat + V:Dot(side) * (tG == math.huge and 0 or tG)
	local runIn = tG <= 1.8 and math.abs(latG) <= c.half + 2.5
	-- an airborne attacker cannot change course: any line that ends in the mouth counts, a ground carrier only if he is close
	local near = rel.Magnitude <= (CFG.PressGoalDist or 30)
	if not (runIn or (near and vIn > 4)) then
		return skip(string.format("no need tG %.2f lat %.1f vIn %.1f", tG == math.huge and -1 or tG, latG, vIn))
	end
	local D = c.diveMod
	local dist = D.GetDistance(LocalPlayer)
	local maxD = math.min(CFG.PressDist or (dist - 2), dist - 0.5)
	local R = CFG.PressReach or 2.6
	local H = CFG.PressVert or 4
	local dirE = unitOrNil(flat(E0 - root.Position)) or fwd
	Mark.actionMotion = Mark.actionMotion or require(Modules.Actions.ActionMotion)
	local cam = Workspace.CurrentCamera
	local facing = unitOrNil(flat(root.CFrame.LookVector)) or fwd
	if not cam then
		return false
	end
	local diveReady = c.now - (Mark.gkDive or 0) > D.Constants.RepeatDelaySeconds + 0.05
	-- forward dive INTO him: every camera-relative direction against his predicted server pose; Rr/need = contact radius / steps
	-- td = the dive starts td seconds from now (0 = at once; > 0 = the JUMP combo: we jump first, the dive goes from the air with
	-- the jump height added - a ground dive rises only ~1.7 studs, a flier above that is out of its reach)
	local vJ = math.sqrt(2 * g * (Mark.jumpH or 7.2))
	local function findDive(Rr, need, td)
		td = td or 0
		local yJ = td > 0 and math.max(vJ * td - 0.5 * g * td * td, 0) or 0
		local bestD = nil
		for name, choice in Mark.actionMotion.DirectionChoices do
			local okW, wd = pcall(D.GetWorldDirection, choice, cam.CFrame, facing)
			if okW and typeof(wd) == "Vector3" and wd:Dot(dirE) > 0.3 and wd:Dot(fwd) > -0.2 then
				local run, first, minD = 0, nil, math.huge
				for i = 1, 40 do
					local t = td + i * 0.02
					local travel = D.GetTravel(i * 0.02, dist)
					if travel > maxD then
						break
					end
					local K = root.Position + wd * travel + Vector3.new(0, yJ + D.GetVerticalTravel(i * 0.02), 0)
					local E = pose(t)
					local d = flat(K - E).Magnitude
					local dy = math.abs(K.Y - E.Y)
					local eAlong = flat(E - mouth):Dot(fwd)
					if eAlong < 0.5 or (K - mouth):Dot(fwd) < 0.3 then
						break -- he is over the line (or we would be) before the contact
					end
					if d <= Rr and dy <= H + 1 and (not airborne or math.abs(K.Y - poseY2(t)) <= H + 1) then
						run += 1
						minD = math.min(minD, d)
						first = first or t
						if run >= need then
							break
						end
					else
						run, first, minD = 0, nil, math.huge
					end
				end
				if run >= need and first and (not bestD or first < bestD.t or (first == bestD.t and minD < bestD.minD)) then
					bestD = { name = name, wd = wd, t = first, minD = minD, td = td, choice = choice }
				end
			end
		end
		return bestD
	end
	local function fireDive(best, tag)
		TurnControl.LockAutoRotate("Goalkeeper", fwd)
		origSetMove(character, best.wd, fwd, true)
		Mark.gkDive = c.now
		local ok = c.role.Dive()
		TurnControl.ReleaseAutoRotate("Goalkeeper")
		Mark.gkPressRec = { at = c.now, pl = pl, model = model, minD = math.huge, name = actorName(pl) }
		logFile("gk press", tag, ok and "ok" or "no", actorName(pl), "choice", best.name, "hit t", string.format("%.2f", best.t), "margin", string.format("%.1f", R - best.minD), "d", string.format("%.1f", flat(E0 - root.Position).Magnitude), "v", string.format("%.1f", V.Magnitude), "vy", string.format("%.1f", vy), "dyNow", string.format("%.1f", E0.Y - root.Position.Y), "air", tostring(airborne), "tG", tG == math.huge and "-" or string.format("%.2f", tG), "latG", string.format("%.1f", latG))
		return ok and true or false
	end
	local needN = (math.max(V.Magnitude, W.Magnitude) > 40) and 1 or 3 -- a 70 studs/s flier crosses the contact circle in ~3 samples
	local best = diveReady and findDive(R, needN, 0) or nil
	local maxT = CFG.PressMaxT or 0.4
	local hum0 = character:FindFirstChildOfClass("Humanoid")
	local canJump = hum0 ~= nil and CharacterControllers.IsLanded(character, hum0)
	local jumpBest = nil
	-- no ground dive reaches him (a rocket / jetpack flier, a lob carrier) -> jump, then dive from the air
	if not best and diveReady and canJump and CFG.GkPressJump ~= false then
		for _, td in { 0.14, 0.27 } do
			local jb = findDive(R, needN, td)
			if jb and (not jumpBest or jb.t < jumpBest.t) then
				jumpBest = jb
			end
		end
	end
	local pick = best or jumpBest
	if pick and pick.t - pick.td > maxT and tG > 0.9 then
		-- the contact is further off than a dive is worth: he can still dodge, jump or shoot - wait, re-plan next tick
		return skip(string.format("too early contact %.2f d %.1f tG %.2f", pick.t, flat(E0 - root.Position).Magnitude, tG == math.huge and -1 or tG))
	end
	if best then
		return fireDive(best, "dive")
	end
	if jumpBest then
		if Mark.doJump("gkpress") then
			Mark.gkCombo = { diveAt = c.now + jumpBest.td, untilT = c.now + jumpBest.td + 0.2, choice = jumpBest.choice, fwd = fwd, role = c.role, name = actorName(pl), pl = pl, model = model, t = jumpBest.t }
			logFile("gk press", "jump + dive", actorName(pl), "choice", jumpBest.name, "dive in", string.format("%.2f", jumpBest.td), "hit t", string.format("%.2f", jumpBest.t), "d", string.format("%.1f", flat(E0 - root.Position).Magnitude), "dy", string.format("%.1f", E0.Y - root.Position.Y), "jet", tostring(jetOn), "air", tostring(airborne), "tG", tG == math.huge and "-" or string.format("%.2f", tG))
			Mark.gkPressRec = { at = c.now, pl = pl, model = model, minD = math.huge, name = actorName(pl) }
			return true
		end
	end

	-- last chance: he gets in within ~0.8 s and nothing above connects - the closest dive (wider radius, two steps) still
	-- beats standing there; it also shoves him off the line when the radius guess was a bit small
	if diveReady and tG <= (CFG.GkPressDesperate or 0.8) then
		local d2 = findDive(R + 1.3, 2)
		if d2 then
			return fireDive(d2, "dive late")
		end
	end
	return skip(string.format("no contact d %.1f vIn %.1f air %s dive %s", flat(E0 - root.Position).Magnitude, vIn, tostring(airborne), tostring(diveReady)))
end

-- closest approach + his state ~1 s after a press (calibration of PressReach / the stun rule)
Mark.gkPressWatch = function(root)
	local rec = Mark.gkPressRec
	if not rec then
		return
	end
	local now = os.clock()
	local er = rec.model and rec.model:FindFirstChild("HumanoidRootPart")
	if er then
		rec.minD = math.min(rec.minD, flat(er.Position - root.Position).Magnitude)
	end
	if now - rec.at >= 1.0 then
		Mark.gkPressRec = nil
		local down, left = Mark.mateDown(rec.pl, rec.model)
		logFile("gk press result", rec.name, "stunned", tostring(down), "left", string.format("%.2f", left or 0), "closest", string.format("%.1f", rec.minD))
	end
end

-- The keeper pushed off his spot (shotgun / any ViolenceDash: the server sends a Vector3, the client runs
-- KnockbackMotion.Run(_, root, velocity): flat speed x 1.5, duration ln(1 + speed/26), travel GetMaximumHorizontalTravel).
-- The wrapper records every push of OUR character; Mark.gkReturnTick brings the keeper back to the spot he stood on.
Mark.knockHook = function()
	local okK, KB = pcall(function()
		return require(Modules.Characters.KnockbackMotion)
	end)
	if not (okK and KB and KB.Run) or Mark.knockOrig then
		return
	end
	Mark.knockOrig = KB.Run
	KB.Run = function(a, rootPart, vel, ...)
		pcall(function()
			if typeof(rootPart) == "Instance" and rootPart.Parent == LocalPlayer.Character and typeof(vel) == "Vector3" then
				local dur = KB.GetDuration(vel)
				local travel = KB.GetMaximumHorizontalTravel(vel)
				local dir = unitOrNil(flat(vel))
				Mark.knock = { at = os.clock(), vel = vel, dur = dur, travel = travel, from = rootPart.Position, dir = dir }
				Mark.gkReturnDived = nil
				logFile("push", "vel", fmtV(vel), "dur", string.format("%.2f", dur), "travel", string.format("%.1f", travel), "end", dir and fmtV(rootPart.Position + dir * travel) or "-", "gk", tostring(MatchSettings.IsGoalkeeperCharacter(LocalPlayer.Character)))
			end
		end)
		return Mark.knockOrig(a, rootPart, vel, ...)
	end
end
Mark.knockHook()

-- the spot the keeper stands on: remembered while he stands still near his goal
Mark.gkHomeTrack = function(root, c)
	local recent = Mark.knock and c.now - Mark.knock.at < 6
	if not recent and c.landed and flat(root.AssemblyLinearVelocity).Magnitude < 3 and flat(root.Position - c.mouthP).Magnitude <= 24 and c.now - (Mark.gkHomeAt or 0) > 0.4 then
		Mark.gkHomeAt = c.now
		Mark.gkHome = root.Position
	end
end

Mark.gkReturnTick = function(character, root, c)
	Mark.gkHomeTrack(root, c)
	local k = Mark.knock
	if not k or c.now - k.at > 8 or CFG.GkReturn == false then
		return nil
	end
	if c.now < k.at + k.dur + 0.15 or not c.landed then
		return nil
	end
	local home = Mark.gkHome
	if not home then
		return nil
	end
	local to = flat(home - root.Position)
	local disp = to.Magnitude
	if disp < 2.5 then
		if Mark.knock then
			Mark.knock = nil
			logFile("gk return", "done", string.format("%.1f", disp))
		end
		return nil
	end
	local D = c.diveMod
	if disp >= (CFG.GkReturnDive or 13) and not Mark.gkReturnDived and c.now - (Mark.gkDive or 0) > D.Constants.RepeatDelaySeconds + 0.05 and c.role and c.role.Dive then
		Mark.actionMotion = Mark.actionMotion or require(Modules.Actions.ActionMotion)
		local cam = Workspace.CurrentCamera
		local facing = unitOrNil(flat(root.CFrame.LookVector)) or c.fwd
		local u = to.Unit
		local bestW, bestDot, bestName = nil, 0.8, nil
		if cam then
			for name, choice in Mark.actionMotion.DirectionChoices do
				local okW, wd = pcall(D.GetWorldDirection, choice, cam.CFrame, facing)
				if okW and typeof(wd) == "Vector3" and wd:Dot(u) > bestDot then
					bestW, bestDot, bestName = wd, wd:Dot(u), name
				end
			end
		end
		if bestW then
			Mark.gkReturnDived = true
			TurnControl.LockAutoRotate("Goalkeeper", c.fwd)
			origSetMove(character, bestW, c.fwd, true)
			Mark.gkDive = c.now
			local ok = c.role.Dive()
			TurnControl.ReleaseAutoRotate("Goalkeeper")
			logFile("gk return", "dive", ok and "ok" or "no", "choice", bestName, "disp", string.format("%.1f", disp))
			return nil
		end
	end
	if not Mark.gkReturnLog or c.now - Mark.gkReturnLog > 0.6 then
		Mark.gkReturnLog = c.now
		logFile("gk return", "walk", "disp", string.format("%.1f", disp))
	end
	return home
end

Mark.gkComboTick = function(character, root)
	local cb = Mark.gkCombo
	if not cb then
		return
	end
	local now = os.clock()
	if now > cb.untilT then
		Mark.gkCombo = nil
		return
	end
	if now < cb.diveAt then
		return
	end
	Mark.gkCombo = nil
	local cam = Workspace.CurrentCamera
	local D = Mark.gkDiveMod or require(Modules.Actions.GoalkeeperDive)
	Mark.gkDiveMod = D
	if not cam or now - (Mark.gkDive or 0) <= D.Constants.RepeatDelaySeconds + 0.05 then
		return
	end
	local facing = unitOrNil(flat(root.CFrame.LookVector)) or cb.fwd
	local okW, wd = pcall(D.GetWorldDirection, cb.choice, cam.CFrame, facing)
	if not (okW and typeof(wd) == "Vector3") then
		return
	end
	TurnControl.LockAutoRotate("Goalkeeper", cb.fwd)
	origSetMove(character, wd, cb.fwd, true)
	Mark.gkDive = now
	local ok = cb.role.Dive()
	TurnControl.ReleaseAutoRotate("Goalkeeper")
	logFile("gk press", "air dive", ok and "ok" or "no", cb.name, "airborne", tostring(not CharacterControllers.IsLanded(character, character:FindFirstChildOfClass("Humanoid"))))
end

Mark.tickGk = function(character, root)
	if not CFG.AutoGK or not MatchSettings.IsGoalkeeperCharacter(character) then
		Mark.ballSrcId = nil
		return false
	end
	local posMod = Mark.gkPos or require(Modules.Gameplay.GoalkeeperPositioning)
	local pred = Mark.gkPred or require(Modules.Gameplay.GoalkeeperPrediction)
	local acts = Mark.gkActs or require(Modules.Actions.GoalkeeperActions)
	local role = Mark.gkRole
	if not role then
		local ok, mod = pcall(function()
			return require(Client.Gameplay.Player.GoalkeeperRole)
		end)
		role = ok and mod or nil
		Mark.gkRole = role
	end
	Mark.gkPos, Mark.gkPred, Mark.gkActs = posMod, pred, acts
	Mark.gkComboTick(character, root)
	local ours = ourGoalPart()
	local theirs = enemyGoalPart()
	-- Practice wing: the defended goal is PracticeSession.GetDefendedGoalPart (Lobby.Practice.Goals.Defence.Goal) and
	-- the ball is a practice ball (Renderer.GetNearestPracticeBallId -> GetMovementStateById), not the main match.
	local practice = false
	Mark.ballSrcId = nil
	do
		-- practice mode is a session state: checked 4 times a second, not 120 (the old per-frame closure + require
		-- + IsActive + GetDefendedGoalPart + ball id lookup was a fixed cost of every keeper frame)
		local pc = Mark.practiceCache
		local nowP = os.clock()
		if not pc or nowP - pc.at > 0.25 then
			local okP, ps = pcall(function()
				Mark.practiceMod = Mark.practiceMod or require(Client.Gameplay.PracticeSession)
				return Mark.practiceMod
			end)
			pc = { at = nowP, goal = nil }
			if okP and ps and ps.IsActive and ps.IsActive() then
				pc.goal = ps.GetDefendedGoalPart()
			end
			Mark.practiceCache = pc
		end
		if pc.goal and pc.goal.Parent then
			ours = pc.goal
			practice = true
			local okB, id = pcall(Renderer.GetNearestPracticeBallId, root.Position)
			if okB and id then
				Mark.ballSrcId = id
			end
		end
	end
	if not ours then
		if not Mark.gkNoGoal or os.clock() - Mark.gkNoGoal > 2 then
			Mark.gkNoGoal = os.clock()
			logFile("gk", "no goal")
		end
		return true
	end
	local defend = ours.Position
	local attack = theirs and theirs.Position or (defend + flat(root.CFrame.LookVector) * 40)
	if practice then
		local _, _, _, _, _, faceN = goalMouthCorners(ours)
		attack = defend + flat(faceN or root.CFrame.LookVector) * 40
	end
	local _, fwd, side = posMod.GetFieldDirections(defend, attack)
	fwd = fwd or Vector3.new(0, 0, 1)
	Mark.gkFwd = fwd
	side = side or Vector3.new(-fwd.Z, 0, fwd.X)
	local half = posMod.Constants.GoalHalfWidth
	local diveMod = Mark.gkDiveMod or require(Modules.Actions.GoalkeeperDive)
	Mark.gkDiveMod = diveMod
	local state, gkWorld
	if Mark.ballSrcId then
		state, gkWorld = Renderer.GetMovementStateById(Mark.ballSrcId)
	else
		state, gkWorld = Renderer.GetMovementState()
	end
	local ballPos = (state and state.Position) or Renderer.GetPosition() or Renderer.GetMainMatchPosition()
	local ballVel = (state and state.Velocity) or Renderer.GetTargetVelocity(nil, root.Position) or Vector3.zero
	local crossP, crossT, crossWhy = nil, nil, state and "plane" or "no-state"
	if state then
		-- Physics.GetFirstBoxEntry returns an ABSOLUTE time (GoalCrossingPreview compares it with UpdatedAt).
		local t0 = Workspace:GetServerTimeNow()
		local ok, p, t = pcall(pred.GetGoalCrossing, state, gkWorld, ours, t0, pred.Constants.GoalCrossingMaximumPredictionSeconds, false)
		if ok and typeof(p) == "Vector3" and type(t) == "number" then
			crossP, crossT, crossWhy = p, (t > 1e6) and (t - t0) or t, "cross"
		elseif not ok then
			crossWhy = "cross-err"
			if not Mark.gkCrossErr or os.clock() - Mark.gkCrossErr > 2 then
				Mark.gkCrossErr = os.clock()
				logFile("gk cross", tostring(p))
			end
		end
		if not crossP then
			local planeT = pred.GetPlaneTime(state, defend, fwd, 0)
			if planeT and planeT > 0 and planeT <= 5 then
				crossT = planeT
				crossP = pred.GetBallPositionAtTime(state, planeT)
				crossWhy = "plane"
			end
		end
	end
	-- Y window from the real mouth (goalMouthCorners), not the goal part centre: the part is the net VOLUME, its
	-- centre Y is not the ground, so shots at a normal height were dropped as "bad-y" (log: into 116, along 81,
	-- cross bad-y -> no shot -> no dive). Same for the lateral half width (practice goals differ from GoalHalfWidth).
	do
		local lb, lt, rb = goalMouthCorners(ours)
		if lb and lt and rb then
			local bottomY = math.min(lb.Y, rb.Y)
			local topY = math.max(lt.Y, bottomY + 4)
			half = flat(rb - lb).Magnitude * 0.5
			Mark.gkMouth = { bottomY = bottomY, topY = topY, c = (lb + rb) * 0.5 }
			if crossP and (crossP.Y < bottomY - 1.5 or crossP.Y > topY + (Physics.BallRadius or 1) + 1) then
				crossP, crossT = nil, nil
				crossWhy = "bad-y"
			end
			-- lateral / "lost" stand measured from the mouth line, not the net volume centre behind it
			defend = Vector3.new(((lb + rb) * 0.5).X, defend.Y, ((lb + rb) * 0.5).Z)
		elseif crossP and (crossP.Y < defend.Y - 1.5 or crossP.Y > defend.Y + 12) then
			crossP, crossT = nil, nil
			crossWhy = "bad-y"
		end
	end
	if not crossP and ballPos and typeof(ballVel) == "Vector3" then
		local intoNow = -flat(ballVel):Dot(fwd)
		local relNow = flat(ballPos - defend)
		local alongNow = relNow:Dot(fwd)
		if intoNow > 6 and alongNow > 3 and alongNow < 85 then
			local linT = alongNow / intoNow
			local predSide = relNow:Dot(side) + flat(ballVel):Dot(side) * linT
			local linY = ballPos.Y + ballVel.Y * linT
			if linT > 0.08 and linT < 4.2 and math.abs(predSide) <= half + 2 and linY > defend.Y - 1 and linY < defend.Y + 11 then
				crossT = linT
				crossP = defend + fwd * 0.4 + side * predSide + Vector3.new(0, linY - defend.Y, 0)
				crossWhy = "lin"
			end
		end
	end
	if crossP and ballPos then
		local mc = Mark.gkMouth
		local _, _, smp, tss = Mark.ballPath(root)
		if smp then
			local verdict, vp, vt = Mark.gkVerify(smp, tss, mc and mc.c or defend, fwd, side, half, mc and mc.bottomY or (defend.Y - 1.5), mc and mc.topY or (defend.Y + 8))
			if verdict == "bounce" or (crossWhy ~= "cross" and verdict ~= "goal") then
				if not Mark.gkNoCrossLog or os.clock() - Mark.gkNoCrossLog > 0.5 then
					Mark.gkNoCrossLog = os.clock()
					logFile("gk nocross", crossWhy, "path", verdict, "at", vt and string.format("%.2f", vt) or "-", "was", crossT and string.format("%.2f", crossT) or "-")
				end
				crossP, crossT, crossWhy = nil, nil, "no-" .. verdict
			elseif verdict == "goal" and crossWhy ~= "cross" then
				crossP, crossT, crossWhy = vp, vt, crossWhy .. "+path"
			end
		end
	end
	local along, ballSide, into = 0, 0, 0
	if ballPos then
		local relB = flat(ballPos - defend)
		along = relB:Dot(fwd)
		ballSide = relB:Dot(side)
		into = -flat(ballVel):Dot(fwd)
	end
	local now = os.clock()
	local hum = character:FindFirstChildOfClass("Humanoid")
	local landed = not hum or CharacterControllers.IsLanded(character, hum)
	local spd = hum and hum.WalkSpeed or 16
	if spd < 8 then
		spd = 16
	end
	local assist = Mark.gkAssist
	if assist == nil then
		local ok, mod = pcall(function()
			return require(Modules.Actions.GoalkeeperDiveAssist)
		end)
		assist = ok and mod or false
		Mark.gkAssist = assist
	end
	local react = math.clamp(LocalPlayer:GetNetworkPing(), 0, 0.3) + 0.05
	local diveD = diveMod.GetDistance(LocalPlayer)
	local saveReach = diveMod.Constants.SaveReachStuds
	local maxSave = diveMod.Constants.MaximumSaveHeight
	local ballR = Physics.BallRadius or 1
	-- Receive (grounded) and GoalkeeperAirReceive (airborne keeper) from HitboxSettings / Receiving.GetReceiveHitbox.
	local rcv = HitboxSettings.Receive
	local air = HitboxSettings.GoalkeeperAirReceive
	local bodyR = rcv.Size.X * 0.5 + ballR
	local groundTop = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5 + ballR
	local airTop = air.CFrameOffset.Y + air.Size.Y * 0.5 + ballR
	local jumpH = Mark.jumpH or 7.2
	local areaDepth = posMod.Constants.GoalkeeperAreaDepth
	-- The goal part is the net volume: its centre is behind the line. Measure from the mouth face (goalMouthCorners).
	local mlb, _, mrb = goalMouthCorners(ours)
	local mouthP = (mlb and mrb) and (mlb + mrb) * 0.5 or defend

	-- Ownership decides the mode. An owned ball is a dribble, never a shot: no velocity extrapolation, no jump, no dive.
	local ownerId = liveOwnerId()
	local free = not (type(ownerId) == "number" and ownerId ~= 0)
	local ownerRoot = nil
	if not free and ownerId ~= LocalPlayer.UserId then
		local pl, r = enemyCarrier(ownerId)
		if pl and r and not sameTeam(pl) then
			ownerRoot = r
		end
	end
	local shot = false
	local crossSide = nil
	if free and crossP and crossT and crossT > 0 and crossT <= 3 and into > 4 then
		crossSide = flat(crossP - defend):Dot(side)
		shot = math.abs(crossSide) <= half + 2
	end

	-- Free ball: walk the predicted path (Physics.GetStateAtTime, world collisions) and take the EARLIEST point we can
	-- reach. Walk/jump first (no ragdoll), dive only when walking cannot make it.
	local plan = nil
	local lostStand = nil
	if free and ballPos then
		local _, _, samples, ts = Mark.ballPath(root)
		if samples then
			local limit = shot and (crossT + 0.05) or 2.5
			local diveBest = nil
			local enemies = nil
			if not shot then
				enemies = {}
				for _, model in Actors.GetAllCharacterModels() do
					local actor = Actors.GetFromCharacter(model)
					if actor and actor ~= LocalPlayer and not sameTeam(actor) then
						local r = ActorTargeting.GetActorRoot(actor)
						if r and not Mark.mateDown(actor, model) then
							enemies[#enemies + 1] = r.Position
						end
					end
				end
			end
			for i = 2, #samples do
				local t = ts[i]
				if t > limit then
					break
				end
				local p = samples[i]
				local rel = flat(p - mouthP)
				local a = rel:Dot(fwd)
				local s = rel:Dot(side)
				if a < 0 then
					-- crossed the mouth: everything after is a ball in the net
					break
				end
				local inArea = a <= areaDepth and math.abs(s) <= half + 6
				local contested = false
				if inArea and enemies then
					for _, e in enemies do
						if flat(p - e).Magnitude / 26.9 < t then
							contested = true
							break
						end
					end
				end
				if inArea and not contested then
					local g = flat(p - root.Position).Magnitude
					local h = p.Y - root.Position.Y
					local walkT = math.max(g - bodyR, 0) / spd + react + CFG.GkWalkSlack
					if h >= -3 and h <= groundTop and walkT <= t then
						plan = { kind = "walk", p = p, t = t, h = h, g = g }
						break
					end
					if h > groundTop and h - airTop <= jumpH then
						local rise = Mark.riseT(math.max(h - airTop + 0.5, 0.3))
						if walkT + rise <= t then
							plan = { kind = "jump", p = p, t = t, h = h, g = g, rise = rise }
							break
						end
					end
					if shot and not diveBest and g <= diveD + saveReach then
						local curve = diveMod.GetCurveSecondsForTravel(math.max(g - saveReach, 0), diveD)
						local slack = t - react - curve
						local top = assist and assist.GetReachableContactHeight(curve, h) or maxSave
						if slack >= 0 and h >= -2 and h <= math.min(top, maxSave) then
							diveBest = { kind = "dive", p = p, t = t, h = h, g = g, curve = curve, slack = slack }
						end
					end
				end
			end
			plan = plan or diveBest
			-- No reachable point on the path: do not run to the goal-line crossing (blind) - go to where the ball's PATH is
			-- soonest within dive range (an angled shot is reachable earlier, and sideways, than at the line)
			if shot and not plan then
				for i = 2, #samples do
					local t = ts[i]
					if t > limit then
						break
					end
					local p = samples[i]
					local rel = flat(p - mouthP)
					local a, s = rel:Dot(fwd), rel:Dot(side)
					if a < 0 then
						break
					end
					if a <= areaDepth and math.abs(s) <= half + 6 then
						local g = flat(p - root.Position).Magnitude
						local h = p.Y - root.Position.Y
						if h >= -2.5 and h <= maxSave + jumpH * 0.6 then
							local need = math.max(g - diveD * (CFG.GkLostDiveFrac or 0.75), 0) / spd + react
							local deficit = need - t
							if not lostStand or deficit < lostStand.deficit - 0.03 then
								lostStand = { p = p, t = t, g = g, h = h, deficit = deficit }
							end
						end
					end
				end
			end
			-- A free ball that is NOT a shot: an enemy near the intercept point takes it before we are there (log: we ran
			-- out, he picked it up, nothing left to do). Stay in the goal.
			if plan and not shot and enemies then
				local nearR = CFG.GkInterceptEnemy or 14
				for _, e in enemies do
					local dE = flat(plan.p - e).Magnitude
					if dE <= nearR then
						if not Mark.gkNearLog or now - Mark.gkNearLog > 0.8 then
							Mark.gkNearLog = now
							logFile("gk intercept skip", "enemy near the point", string.format("%.1f", dE), "plan", plan.kind, "t", string.format("%.2f", plan.t), "g", string.format("%.1f", plan.g))
						end
						plan = nil
						break
					end
				end
			end
			if shot then
				local bait = Mark.gkBait(samples, ts, crossT)
				if bait then
					Mark.gkBaitKeep = now + 0.15
					-- a walk / jump that touches the ball BEFORE he does is still ours; everything else (dive, late walk) is not
					if not (plan and plan.kind ~= "dive" and plan.t < bait.t - 0.05) then
						plan = nil
					end
					shot = false
					if not Mark.gkBaitLog or now - Mark.gkBaitLog > 0.5 then
						Mark.gkBaitLog = now
						logFile("gk bait", bait.name, "touch", string.format("%.2f", bait.t), "cross", string.format("%.2f", crossT), "d", string.format("%.1f", bait.dist), "plan", plan and plan.kind or "-")
					end
				elseif Mark.gkBaitKeep and now < Mark.gkBaitKeep and crossT > 0.3 then
					-- the test dropped out for a frame (noise on the receive box edge): do not commit an irreversible dive on it
					shot = false
					plan = (plan and plan.kind ~= "dive") and plan or nil
				end
			end
		end
	end

	-- Charged shot read. While the carrier charges, ActionPresentationUpdate KickChargeStarted/Updated replicates his
	-- aim (Mark.charges[uid].dir). Where that ray meets our mouth is where the shot starts; moving there DURING the
	-- charge buys the 0.3-0.9 s a close corner shot never leaves after release (log: first sight eta 0.27, gap 14.6,
	-- no save possible). Not positioning: it only fires on a live charge aimed inside the frame.
	local chargeS = nil
	if not free and ownerRoot and Mark.charges then
		local rec = Mark.charges[ownerId]
		if rec and rec.live and rec.dir and now - (rec.seen or 0) < 0.6 then
			local d = rec.dir.Unit
			local den = d:Dot(fwd)
			if den < -0.2 then
				local o = ownerRoot.Position
				local tPlane = (mouthP - o):Dot(fwd) / den
				if tPlane > 0 then
					local hitP = o + d * tPlane
					local s = flat(hitP - mouthP):Dot(side)
					if math.abs(s) <= half + 3 then
						chargeS = s
						-- a FAKE charge aims through his teammate: positioning on the ray's mouth point is the bait too
						for _, model in Actors.GetAllCharacterModels() do
							local actor = Actors.GetFromCharacter(model)
							if actor and actor ~= LocalPlayer and actor.UserId ~= ownerId and not sameTeam(actor) then
								local r2 = ActorTargeting.GetActorRoot(actor)
								if r2 then
									local rel = flat(r2.Position - o)
									local along2 = rel:Dot(flat(d).Unit)
									if along2 > 5 and along2 < flat(hitP - o).Magnitude then
										local lat2 = (rel - flat(d).Unit * along2).Magnitude
										if lat2 <= (CFG.GkBaitRay or 2.5) then
											chargeS = nil
											if not Mark.gkBaitLog or now - Mark.gkBaitLog > 0.5 then
												Mark.gkBaitLog = now
												logFile("gk bait", actorName(actor), "on charge ray", "lat", string.format("%.1f", lat2))
											end
											break
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	-- pushed off the spot (shotgun etc.): back to where he stood, unless a save is on
	local retTarget = nil
	if not plan and not shot then
		local okR, rt = pcall(Mark.gkReturnTick, character, root, { now = now, landed = landed, fwd = fwd, side = side, mouthP = mouthP, diveMod = diveMod, role = role })
		if okR then
			retTarget = rt
		end
	end
	local stand, why, eta = nil, "free", nil
	local stopAt, urgent = 0.8, false
	if not plan and not shot and chargeS then
		stand = mouthP + fwd * 1.5 + side * math.clamp(chargeS, -(half - 1), half - 1)
		why = "charge"
		stopAt, urgent = 0.4, true
	end
	if plan then
		stand = plan.p
		why = plan.kind
		eta = plan.t
		stopAt, urgent = 0.3, true
	elseif shot then
		-- No save on the path: still close the crossing on the line, a deflection beats standing.
		stand = defend + fwd * 1.5 + side * math.clamp(crossSide, -(half - 1), half - 1)
		why = "lost"
		if lostStand and CFG.GkLostPath ~= false then
			local dirv = unitOrNil(flat(lostStand.p - root.Position))
			if dirv then
				local goD = math.max(lostStand.g - diveD * (CFG.GkLostDiveFrac or 0.75), 0)
				local cand = root.Position + dirv * goD
				local depthC = math.clamp(flat(cand - mouthP):Dot(fwd), 1.0, areaDepth)
				local sideC = math.clamp(flat(cand - mouthP):Dot(side), -(half - 1), half - 1)
				stand = mouthP + fwd * depthC + side * sideC
				why = "lost-path"
			end
		end
		eta = crossT
		stopAt, urgent = 0.3, true
	end
	if not stand and retTarget then
		stand, why, stopAt, urgent = retTarget, "return", 1.0, true
	end
	-- No positioning: without a ball to chase the player keeps full control of where the keeper stands.

	local toStand = stand and flat(stand - root.Position) or Vector3.zero
	local gapStand = toStand.Magnitude
	if stand and gapStand > stopAt then
		local scale = urgent and 1 or math.clamp(gapStand / 3, 0.3, 1)
		Mark.move.look = fwd
		Mark.moveSteer(toStand.Unit * scale, "gk")
	elseif Mark.move.mode == "gk" then
		Mark.moveStop("gk")
	end

	if not Mark.gkLog or now - Mark.gkLog > 0.45 or Mark.gkWhy ~= why then
		Mark.gkLog = now
		Mark.gkWhy = why
		local rs = flat((stand or root.Position) - defend)
		logFile(
			"gk pos", why,
			"d", string.format("%.1f", rs:Dot(fwd)),
			"lat", string.format("%.1f", rs:Dot(side)),
			"along", string.format("%.1f", along),
			"side", string.format("%.1f", ballSide),
			"into", string.format("%.1f", into),
			"eta", eta and string.format("%.2f", eta) or "-",
			"gap", string.format("%.1f", gapStand),
			"owner", free and "free" or (ownerRoot and "enemy" or "ours"),
			"cross", shot and string.format("%.1f %s", crossSide, crossWhy) or crossWhy,
			"plan", plan and string.format("%s t %.2f g %.1f h %.1f", plan.kind, plan.t, plan.g, plan.h) or "-"
		)
	end

	Mark.gkPressWatch(root)
	if not free and ownerRoot and landed and role and role.Dive then
		local pressed = Mark.gkPress(character, root, { now = now, ownerId = ownerId, fwd = fwd, side = side, half = half, mouth = mouthP, diveMod = diveMod, role = role })
		if pressed then
			return true
		end
	end
	-- walk / jump plans flip frame to frame on noisy h (log: jump, walk, jump, walk...), so neither the jump press
	-- nor the "no movement plan -> dive" test held for two frames. Keep the last movement plan for 0.2 s and the jump
	-- press time for 0.25 s.
	if plan and (plan.kind == "walk" or plan.kind == "jump") then
		Mark.gkMovePlanAt = now
	end
	if plan and plan.kind == "jump" then
		Mark.gkJumpPlan = { pressAt = now + (plan.t - react) - plan.rise - 0.03, h = plan.h, t = plan.t, rise = plan.rise, untilT = now + 0.25 }
	end
	local jp = Mark.gkJumpPlan
	if jp and now > jp.untilT then
		Mark.gkJumpPlan = nil
		jp = nil
	end
	local moveHeld = Mark.gkMovePlanAt and now - Mark.gkMovePlanAt < 0.2
	if jp and landed and (not plan or plan.kind ~= "dive" or moveHeld) then
		if now >= jp.pressAt and now - (Mark.gkJump or 0) > 0.45 then
			Mark.gkJump = now
			Mark.gkJumpPlan = nil
			local jumped = Mark.doJump("gk")
			logFile("gk jump", jumped and "ok" or "no", "h", string.format("%.1f", jp.h), "t", string.format("%.2f", jp.t), "rise", string.format("%.2f", jp.rise))
		end
	elseif shot and (not plan or plan.kind == "dive") and not (moveHeld and (crossT or 0) > 0.18) and role and role.Dive and landed and now - (Mark.gkDive or 0) > diveMod.Constants.RepeatDelaySeconds then
		-- no walk / jump save: dive only in a direction the game's dive + assist actually connects with
		local dState, dWorld = state, gkWorld
		if not Mark.ballSrcId and Renderer.GetAuthoritativeMovementState then
			local okS, s2, w2 = pcall(Renderer.GetAuthoritativeMovementState)
			if okS and s2 and w2 then
				dState, dWorld = s2, w2
			end
		end
		local hit = Mark.gkOwnDive(root) or Mark.gkDiveSearch(root, dState, dWorld)
		if not hit and CFG.GkJumpDive ~= false then
			-- nothing a ground dive touches (the high corner: the dive rises ~1.7 studs): jump first, dive from the air
			for _, td in { 0.12, 0.25 } do
				local h2 = Mark.gkOwnDive(root, td)
				if h2 then
					Mark.actionMotion = Mark.actionMotion or require(Modules.Actions.ActionMotion)
					if Mark.doJump("gk") then
						Mark.gkJump = now
						Mark.gkCombo = { diveAt = now + td, untilT = now + td + 0.25, choice = Mark.actionMotion.DirectionChoices[h2.name], fwd = fwd, role = role, name = "shot " .. h2.name }
						logFile("gk dive", "jump + dive", "choice", h2.name, "dive in", td, "contact", string.format("%.2f", h2.t), "eta", string.format("%.2f", crossT or -1))
						hit = false
					end
					break
				end
			end
			if Mark.gkCombo then
				return true
			end
		end
		if hit then
			TurnControl.LockAutoRotate("Goalkeeper", fwd)
			origSetMove(character, hit.wd, fwd, true)
			Mark.gkDive = now
			local ok = role.Dive()
			TurnControl.ReleaseAutoRotate("Goalkeeper")
			logFile("gk dive", ok and "ok" or "no", "model", hit.own and "own" or "assist", "choice", hit.name, "miss", string.format("%.2f", hit.miss), "t", string.format("%.2f", hit.t or -1), "assist", tostring(hit.assisted), "eta", string.format("%.2f", crossT or -1), "dir", fmtV(hit.wd))
		elseif not Mark.gkNoDiveLog or now - Mark.gkNoDiveLog > 0.3 then
			Mark.gkNoDiveLog = now
			logFile("gk dive none", "eta", string.format("%.2f", crossT or -1), "cross", string.format("%.1f", crossSide or 0))
		end
	end
	-- Auto clear is OFF by default: it sent a GetClearCommand every 1.2 s while we held the ball, which raced the
	-- player's own throw / kick (user: after a save the keeper could not release the ball himself).
	if CFG.GkAutoClear and Mark.weOwn and Mark.weOwn() and os.clock() - (Mark.gkClear or 0) > 1.2 then
		local aim = acts.GetClearForwardDirection(LocalPlayer, {
			GetDefendGoalPosition = function()
				return defend
			end,
			GetAttackGoalPosition = function()
				return attack
			end,
		})
		if aim then
			local cmd = acts.GetClearCommand(LocalPlayer, nil, {
				AimDirection = aim,
				KickDirection = aim,
				ChargeSeconds = acts.Constants.ClearChargeSeconds,
				HoldSeconds = acts.Constants.ClearChargeSeconds,
			})
			cmd.ShotTime = Workspace:GetServerTimeNow()
			ActionRemoteProtocol.Send(cmd)
			Mark.gkClear = os.clock()
			logFile("gk clear", fmtV(aim))
		end
	end
	return true
end

-- Perf probe (CFG.Perf): inclusive time per section, flushed to the log every 5 s as one "perf" line, biggest first.
Mark.perf = {}
Mark.perfAdd = function(name, ms)
	local p = Mark.perf[name]
	if not p then
		p = { 0, 0, 0 }
		Mark.perf[name] = p
	end
	p[1] += 1
	p[2] += ms
	if ms > p[3] then
		p[3] = ms
	end
end
Mark.perfFlush = function()
	local now = os.clock()
	if now - (Mark.perfAt or now) < 5 then
		Mark.perfAt = Mark.perfAt or now
		return
	end
	local span = now - (Mark.perfAt or now)
	Mark.perfAt = now
	local rows = {}
	for name, p in Mark.perf do
		rows[#rows + 1] = { name = name, n = p[1], sum = p[2], max = p[3] }
	end
	Mark.perf = {}
	table.sort(rows, function(x, y)
		return x.sum > y.sum
	end)
	local out = {}
	for i = 1, math.min(#rows, 9) do
		local r = rows[i]
		out[#out + 1] = string.format("%s %.2fms/s avg %.2f max %.1f n %d", r.name, r.sum / span, r.sum / math.max(r.n, 1), r.max, r.n)
	end
	if #out > 0 then
		logFile("perf", string.format("fps %.0f |", 1 / math.max(Mark.dtAvg or 0.0083, 0.001)), table.concat(out, " | "))
	end
end
Mark.perfWrap = function(name)
	local f = Mark[name]
	if type(f) ~= "function" then
		return
	end
	Mark[name] = function(...)
		if not CFG.Perf then
			return f(...)
		end
		local t0 = os.clock()
		local a, b, c, d, e, g = f(...)
		Mark.perfAdd(name, (os.clock() - t0) * 1000)
		return a, b, c, d, e, g
	end
end

RunService.Heartbeat:Connect(function(dt)
	Mark.dt = dt
	Mark.dtAvg = (Mark.dtAvg or dt) * 0.95 + dt * 0.05
	if not CFG.Perf then
		return stepLogic()
	end
	local t0 = os.clock()
	stepLogic()
	Mark.perfAdd("stepLogic", (os.clock() - t0) * 1000)
	Mark.perfFlush()
end)
RunService.RenderStepped:Connect(function()
	-- Paint at CFG.PaintHz (60) when the display is much faster (>= ~100 fps): Drawing objects persist between frames,
	-- so skipping a paint just keeps the previous one on screen; below that rate every frame is painted.
	local hz = CFG.PaintHz
	if hz and hz > 0 then
		local nowP = os.clock()
		if (Mark.dtAvg or 1) < 1 / (hz * 1.7) and nowP - (Mark.paintAt or 0) < 1 / hz - 0.0035 then
			return
		end
		Mark.paintAt = nowP
	end
	local t0 = os.clock()
	local cam = Workspace.CurrentCamera
	if cam then
		local cf = cam.CFrame
		Mark.frameCam, Mark.framePos, Mark.frameLook = cam, cf.Position, cf.LookVector
		Mark.frameId = (Mark.frameId or 0) + 1
		Mark.framePxK = cam.ViewportSize.Y / (2 * math.tan(math.rad(cam.FieldOfView) * 0.5))
	else
		Mark.frameCam = nil
	end
	paintWorld()
	local t1 = os.clock()
	paintHud()
	Mark.frameCam = nil -- Heartbeat-side draws read the live camera
	if CFG.Perf then
		Mark.perfAdd("paintWorld", (t1 - t0) * 1000)
		Mark.perfAdd("paintHud", (os.clock() - t1) * 1000)
	end
end)

local function onEnemyTackleStarted(userId, aim)
	if not Mark.playLive() then
		return
	end
	if not (CFG.AutoDribble or CFG.AutoDodge) then
		return
	end
	if type(userId) ~= "number" or userId == LocalPlayer.UserId then
		return
	end
	local actor = playerOf(userId)
	if not actor or sameTeam(actor) or isGoalkeeper(actor) then
		return
	end
	local character = LocalPlayer.Character
	local root = character and ActorTargeting.GetActorRoot(LocalPlayer)
	local theirRoot = ActorTargeting.GetActorRoot(actor)
	if not (root and theirRoot) then
		return
	end
	local theirChar = Actors.GetCharacter(actor)
	local dist = flat(theirRoot.Position - root.Position).Magnitude
	local heading = AimFacing.GetFlatDirection(aim)
	local fromPacket = heading ~= nil
	if not heading then
		heading = headingOf(theirChar, theirRoot)
	end
	if not heading then
		dbg("dribble", "no heading", "dist", string.format("%.2f", dist))
		return
	end
	local srvPos = Mark.enemySlideOrigin(theirRoot, theirChar, heading, 0)
	slideLock[theirChar] = {
		heading = heading,
		origin = srvPos,
		feet = theirRoot.Position,
		startPos = srvPos,
		elapsed = 0,
		hold = os.clock() + 0.45,
		fromPacket = fromPacket,
		t0 = os.clock(),
	}
	local model = Actors.GetCharacter(actor)
	if model and model ~= theirChar then
		slideLock[model] = slideLock[theirChar]
	end
	local lock = slideLock[theirChar]
	local at = Mark.slideAtUs(lock, 0, root, actor)
	if dist < 60 then
		Mark.audits = Mark.audits or {}
		local list = Mark.audits
		if #list > 6 then
			table.remove(list, 1)
		end
		list[#list + 1] = { t0 = os.clock(), root = theirRoot, theirChar = theirChar, actor = actor, name = actorName(actor), p0 = theirRoot.Position, us0 = root.Position, heading = heading, dist = dist, minLat = 1e9, fired = false }
	end
	local maxReach = Mark.dumpTravel(C.HitboxDelaySeconds + C.HitboxSeconds) + 5.9
	local vis = flat(theirRoot.Position - root.Position).Magnitude
	logFile(
		"enemy tackle",
		"id",
		userId,
		"dist",
		string.format("%.2f", at and at.dist or vis),
		"vis",
		string.format("%.2f", vis),
		"dotG",
		at and at.dotG and string.format("%.2f", at.dotG) or "-",
		"dotL",
		at and at.dotL and string.format("%.2f", at.dotL) or "-",
		"hits",
		tostring(at and at.hits),
		"latG",
		at and string.format("%.1f", at.latG) or "-",
		"latL",
		at and string.format("%.1f", at.latL) or "-",
		"side",
		at and at.side and string.format("%.1f", at.side) or "-",
		"body",
		at and at.body and string.format("%.1f", at.body) or "-",
		"boxed",
		tostring(at and at.boxed),
		"fire",
		tostring(at and at.fire),
		"pred",
		tostring(at and at.predHit),
		"srv",
		at and at.srv and string.format("%.1f", at.srv) or "-",
		"def",
		tostring(at and at.defend),
		"walk",
		tostring(at and at.walkIn),
		"strong",
		tostring(at and at.strong),
		"hitIn",
		at and at.hitIn and string.format("%.2f", at.hitIn) or "-",
		"why",
		at and at.why or "-",
		"own",
		tostring(liveOwnerId() == LocalPlayer.UserId),
		"name",
		actorName(actor)
	)
	local atUs = at and at.fire
	if atUs and (at.dist <= math.max(CFG.DribbleReact, maxReach) or vis <= math.max(CFG.DribbleReact, maxReach)) then
		dribbleDanger = {
			root = theirRoot,
			dist = at.dist,
			character = theirChar,
			actor = actor,
			heading = heading,
			origin = srvPos,
			sliding = true,
			fire = at.fire,
			approach = at.approach,
			elapsed = 0,
			hitP = at.hitP,
			closest = at.closest,
			lat = at.lat,
			ourPos = at.ghost,
			hitIn = at.hitIn,
			strong = at.strong,
		}
		Mark.dodgeDone = nil
		dribbleDanger.force = at.fire
		local ownBall = liveOwnerId() == LocalPlayer.UserId
		local ok = false
		-- the dribble (4 s cooldown: Dodge ActiveSeconds 1 + CooldownSeconds 3) only on a strong read
		if at.fire and at.strong and ownBall and CFG.AutoDribble and Mark.dribbleLeft() <= 0 and not Mark.aerial and not Mark.flickStrike then
			ok = select(1, tryDribble())
		end
		local audit = Mark.audits and Mark.audits[#Mark.audits]
		if audit and audit.theirChar == theirChar then
			audit.fired = at.fire and true or false
			audit.why = at.why
			audit.dribble = ok
		end
		if at.fire and not ok and CFG.AutoDodge and Mark.dodgeSteer and not Mark.aerial and not Mark.flickStrike then
			if audit and audit.theirChar == theirChar then
				audit.dodge = true
			end
			Mark.dodgeSteer(root, dribbleDanger)
		end
	else
		dribbleWhy = "clear"
		note("d", dribbleWhy)
	end
end

-- THE REPLICATED CHARGE. Every KickChargeStarted/Updated carries the shooter's aim, pass type, curve, launch sample; the game
-- itself turns it into a launch velocity (TackleEffects.solveChargePath -> ChargePathVelocity.Get(character, chargeSeconds,
-- passType, aim, launchPos, reportedVelocity, kickDir, targetPos, boundaryWorld, curve)) to draw the observed charge path.
-- We wrap Get, keep the latest inputs per enemy and re-run the SAME function at full charge: the exact launch velocity and
-- spin of the shot that is about to be released, then the game's own ball physics (Physics.NewState/GetStateAtTime with the
-- boundary world) for the flight - the whole path, before the ball exists. AutoBlock stands on it, the slide-block times
-- the box against it.
Mark.cpvArgs = {}
Mark.chargeHook = function()
	local okM, cpv = pcall(function()
		return require(Modules.Actions.ChargePathVelocity)
	end)
	if not (okM and cpv and cpv.Get) or Mark.cpvOrig then
		return
	end
	Mark.cpv, Mark.cpvOrig = cpv, cpv.Get
	cpv.Get = function(character, sec, ...)
		local pl = character and Players:GetPlayerFromCharacter(character)
		if pl and pl ~= LocalPlayer then
			Mark.cpvArgs[pl.UserId] = { at = os.clock(), char = character, sec = sec, a = table.pack(...) }
		end
		return Mark.cpvOrig(character, sec, ...)
	end
end
Mark.chargeHook()

Mark.chargeShot = function(uid)
	local ca = Mark.cpvArgs[uid]
	if not ca or os.clock() - ca.at > 0.6 or not Mark.cpvOrig then
		return nil
	end
	local memo = Mark.chargeMemo and Mark.chargeMemo[uid]
	if memo and memo.src == ca and os.clock() - memo.at < 0.05 then
		return memo
	end
	local a = ca.a
	local full = (KickCore.GetFullChargeSeconds and KickCore.GetFullChargeSeconds()) or 0.35
	local secF = math.max(ca.sec or 0, full)
	local okV, vel = pcall(Mark.cpvOrig, ca.char, secF, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
	local launch = a[3]
	if not (okV and typeof(vel) == "Vector3" and typeof(launch) == "Vector3") then
		return nil
	end
	local okSp, spin = pcall(Mark.cpv.GetLaunchSpin, ca.char, vel, a[1], a[4], a[8], secF)
	local world = a[7]
	if not world then
		local _, w = Renderer.GetMovementState()
		world = w
	end
	local t0 = Workspace:GetServerTimeNow()
	local okS, st = pcall(Physics.NewState, launch, vel, Physics.BallRadius, t0, (okSp and typeof(spin) == "Vector3") and spin or Vector3.zero)
	if not okS or type(st) ~= "table" then
		return nil
	end
	st.LastKickerUserId = uid
	local pts, ts = { launch }, { 0 }
	for i = 1, 50 do
		local t = i * 0.04
		local okG, s = pcall(Physics.GetStateAtTime, st, t0 + t, world)
		local p = okG and s and s.Position
		if typeof(p) ~= "Vector3" then
			break
		end
		pts[#pts + 1] = p
		ts[#ts + 1] = t
		local v = s.Velocity
		if typeof(v) == "Vector3" and v.Magnitude < 1 then
			break
		end
	end
	memo = { src = ca, at = os.clock(), pts = pts, ts = ts, vel = vel, launch = launch, speed = vel.Magnitude, passType = a[1] }
	Mark.chargeMemo = Mark.chargeMemo or {}
	Mark.chargeMemo[uid] = memo
	return memo
end

-- position of the predicted ball `t` seconds after release (linear between the 0.04 s samples)
Mark.chargeAt = function(cs, t)
	local ts, pts = cs.ts, cs.pts
	if t <= 0 then
		return pts[1]
	end
	for i = 2, #ts do
		if ts[i] >= t then
			local k = (t - ts[i - 1]) / math.max(ts[i] - ts[i - 1], 1e-4)
			return pts[i - 1]:Lerp(pts[i], k)
		end
	end
	return nil
end

-- Where to stand for the shot that is being charged. Path samples that (a) end up in our mouth, (b) are at body height,
-- (c) lie beyond his kick reach; the one we reach with the most time to spare and the least running. His release can come at
-- any moment from the minimum charge on, so the budget is: time to the earliest release + ball flight time to the sample.
Mark.chargeSpot = function(character, root, uid)
	local rec = Mark.charges and Mark.charges[uid]
	if not (rec and rec.live and os.clock() - (rec.seen or 0) < 0.6) then
		return nil
	end
	local cs = Mark.chargeShot(uid)
	local g = Mark.defendGoal()
	if not (cs and g) then
		return nil
	end
	local lb, lt, rb = goalMouthCorners(g)
	if not (lb and lt and rb) then
		return nil
	end
	local mouth = (lb + rb) * 0.5
	local sideV = unitOrNil(flat(rb - lb))
	if not sideV then
		return nil
	end
	local launchF = flat(cs.launch - mouth)
	local out = Vector3.new(-sideV.Z, 0, sideV.X)
	if launchF:Dot(out) < 0 then
		out = -out
	end
	local half = flat(rb - lb).Magnitude * 0.5
	local bottomY = math.min(lb.Y, rb.Y)
	local topY = math.max(lt.Y, bottomY + 4)
	-- does the flight end in our mouth?
	local crossI = nil
	for i = 2, #cs.pts do
		local p = cs.pts[i]
		if flat(p - mouth):Dot(out) <= 0.3 then
			if math.abs(flat(p - mouth):Dot(sideV)) <= half + 2.5 and p.Y >= bottomY - 1.5 and p.Y <= topY + 1.5 then
				crossI = i
			end
			break
		end
	end
	if not crossI then
		return nil
	end
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local spd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false)
	if type(spd) ~= "number" or spd < 8 then
		spd = 16
	end
	local rcv = HitboxSettings.Receive
	local bodyHalf = rcv.Size.X * 0.5
	local lo = rcv.CFrameOffset.Y - rcv.Size.Y * 0.5
	local hi = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5 + (Physics.BallRadius or 1)
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local minRel = KickCore.GetMinimumReleaseSeconds and KickCore.GetMinimumReleaseSeconds() or 0.2
	local tRel = math.max(minRel - (os.clock() - rec.at), 0)
	local reach = Mark.kickReach() + 0.8
	local best, bestMove, worst = nil, math.huge, nil
	for i = 2, crossI do
		local p = cs.pts[i]
		local h = p.Y - root.Position.Y
		if h >= lo and h <= hi and flat(p - cs.launch).Magnitude >= reach then
			local d = flat(p - root.Position).Magnitude
			local need = math.max(d - bodyHalf, 0) / spd + ping * 0.5 + 0.06
			local slack = tRel + cs.ts[i] - need
			if slack >= 0 then
				if d < bestMove then
					best, bestMove = { p = p, t = cs.ts[i], slack = slack, ok = true, d = d }, d
				end
			elseif not worst or slack > worst.slack then
				worst = { p = p, t = cs.ts[i], slack = slack, ok = false, d = d }
			end
		end
	end
	local pick = best or worst
	if pick then
		pick.tRel, pick.speed, pick.cross = tRel, cs.speed, cs.pts[crossI]
	end
	return pick
end

local function onFx(kind, userId, a, b, c, aimDir, ...)
	if kind == "GoalkeeperDiveStarted" and type(userId) == "number" and userId ~= LocalPlayer.UserId then
		-- the dive cooldown is GoalkeeperDive.Constants.RepeatDelaySeconds from the START of the dive
		local who = playerOf(userId)
		if who and who ~= LocalPlayer and not sameTeam(who) then
			Mark.foeDive = Mark.foeDive or {}
			Mark.foeDive[userId] = os.clock()
			logFile("keeper dive seen", actorName(who), "gk", tostring(isGoalkeeper(who)), "-> fakes off for", string.format("%.2f", Mark.foeDiveLeft()))
		end
	end
	if kind == "TackleStarted" then
		onEnemyTackleStarted(userId, b)
	elseif kind == "KickChargeStarted" or kind == "KickChargeUpdated" then
		if type(userId) == "number" and userId ~= LocalPlayer.UserId then
			Mark.chargeLive = true
			Mark.charges = Mark.charges or {}
			local rec = Mark.charges[userId]
			if kind == "KickChargeStarted" or not rec or not rec.live then
				rec = { at = os.clock(), live = true, uid = userId }
				Mark.charges[userId] = rec
			end
			do
				local d0 = typeof(aimDir) == "Vector3" and aimDir or (type(aimDir) == "table" and aimDir.Direction)
				if typeof(d0) == "Vector3" then
					rec.dir = d0
				end
				rec.seen = os.clock()
			end
			local dir = nil
			if typeof(aimDir) == "Vector3" then
				dir = aimDir
			elseif type(aimDir) == "table" and typeof(aimDir.Direction) == "Vector3" then
				dir = aimDir.Direction
			end
			if dir then
				Mark.chargeDir = dir
				Mark.chargeId = userId
				Mark.chargeUntil = os.clock() + 1.6
			end
		end
	elseif kind == "KickReleased" or kind == "KickChargeCanceled" then
		if userId == Mark.chargeId then
			Mark.chargeUntil = os.clock() + 0.5
			Mark.chargeLive = false
		end
		if Mark.charges and type(userId) == "number" and Mark.charges[userId] then
			Mark.charges[userId].live = false
		end
		if type(userId) == "number" then
			Mark.noTouchUntil = os.clock() + 0.25
			if userId ~= LocalPlayer.UserId then
				local a = playerOf(userId)
				if a and sameTeam(a) then
					Mark.allyKickUntil = os.clock() + 1.5
				end
			end
		end
	elseif kind == "RainbowFlickStarted" and type(userId) == "number" then
		if userId == LocalPlayer.UserId then
			if Shoot.aim then
				Mark.flickStrike = os.clock() + 3
			end
		else
			flickOwner = userId
			flickUntil = os.clock() + 1.15
			-- RainbowFlick.SetWindingUpUntil is only ever called for the LOCAL player (Gameplay_Script), so IsWindingUp(enemy)
			-- is always false: the flick of another player is known only from this packet (a = server start time). The ball
			-- detaches at start + his display delay + BallDetachSeconds (TackleEffects.RainbowFlickStarted).
			local who = playerOf(userId)
			local ch = who and Actors.GetCharacter(who)
			Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
			local srvNow = Workspace:GetServerTimeNow()
			local startSrv = type(a) == "number" and a or srvNow
			local dly = ch and (CharacterMotion.GetDisplayDelaySeconds(ch) or 0) or 0
			local detachSrv = math.max(startSrv + dly, srvNow) + Mark.flick.Constants.BallDetachSeconds
			Mark.flickRec = Mark.flickRec or {}
			Mark.flickRec[userId] = { at = os.clock(), srvStart = startSrv, detachSrv = detachSrv }
			logFile("flick seen", who and actorName(who) or userId, "detach in", string.format("%.2f", detachSrv - srvNow), "delay", string.format("%.2f", dly), "arg", typeof(a) == "number" and string.format("%.2f", a - srvNow) or tostring(a))
		end
	elseif kind == "RainbowFlickCanceled" and userId == flickOwner then
		flickOwner = nil
		flickUntil = 0
		if Mark.flickRec then
			Mark.flickRec[userId] = nil
		end
	end
end
BallGroup.TackleEffect.OnClientEvent:Connect(onFx)
Remotes.Get("Ball", "ActionPresentationUpdate").OnClientEvent:Connect(onFx)
SlideTackle.SlidingUntilChanged.Event:Connect(function(ch)
	if not (CFG.AutoDribble or CFG.AutoDodge) then
		return
	end
	if not ch then
		return
	end
	local untilT = SlideTackle.GetSlidingUntil(ch)
	if not (untilT and Workspace:GetServerTimeNow() < untilT) then
		return
	end
	local actor = Actors.GetFromCharacter(ch)
	if not actor or actor == LocalPlayer then
		return
	end
	if sameTeam(actor) or isGoalkeeper(actor) then
		return
	end
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	local theirRoot = ActorTargeting.GetActorRoot(actor)
	if not (root and theirRoot) then
		return
	end
	local lock, elapsed = lockEnemySlide(ch, theirRoot)
	if not lock then
		return
	end
	local at = Mark.slideAtUs(lock, elapsed, root, actor)
	local maxReach = Mark.dumpTravel(C.HitboxDelaySeconds + C.HitboxSeconds) + 5.9
	if at and at.fire and (at.dist <= CFG.DribbleReact or at.dist <= maxReach) then
		dribbleDanger = {
			root = theirRoot,
			character = ch,
			actor = actor,
			heading = lock.heading,
			origin = lock.origin,
			sliding = true,
			fire = true,
			elapsed = elapsed,
			closest = at.closest,
			lat = at.lat,
			ourPos = at.ghost,
			hitIn = at.hitIn,
			strong = at.strong,
		}
		local ownBall = liveOwnerId() == LocalPlayer.UserId
		local ok = false
		if ownBall and at.strong and CFG.AutoDribble and Mark.dribbleLeft() <= 0 then
			ok = select(1, tryDribble())
		end
		if not ok and CFG.AutoDodge and Mark.dodgeSteer then
			Mark.dodgeSteer(root, dribbleDanger)
		end
	end
end)

local function dumpLog()
	local lines = {}
	local function add(s)
		lines[#lines + 1] = s
	end
	add("-- illegalsoccerlog " .. os.date("%Y-%m-%d %H:%M:%S"))
	add(string.format("clock=%.3f server=%.3f ping=%.3f", os.clock(), Workspace:GetServerTimeNow(), LocalPlayer:GetNetworkPing()))
	add(string.format(
		"cfg tackleSpeed=%.2f reach=%.1f close=%.1f slop=%.1f windup=%.3f track=%.0f",
		CFG.TackleSpeed,
		CFG.TackleReach,
		CFG.DribbleClose,
		CFG.DribbleSlop,
		CFG.TackleWindup,
		CFG.TrackStuds
	))
	add(string.format(
		"slide hitboxDelay=%.3f hitbox=%.3f travel0.27=%.2f travel0.42=%.2f travel0.57=%.2f land=%.2f dash=%s distC=%.1f/%.1f",
		C.HitboxDelaySeconds,
		C.HitboxSeconds,
		SlideTackle.GetTravel(0.27),
		SlideTackle.GetTravel(0.42),
		SlideTackle.GetTravel(0.57),
		C.AssistLandingStuds,
		tostring(C.StartupDashDistance),
		C.StartupDashDistance,
		C.Distance
	))
	local oid = liveOwnerId()
	local own = oid == LocalPlayer.UserId
	local player, croot = enemyCarrier(oid)
	add(string.format(
		"owner=%s own=%s enemy=%s enemyPos=%s us=%s ghost=%s",
		tostring(oid),
		tostring(own),
		actorName(player),
		fmtV(typeof(croot) == "Instance" and croot.Position or nil),
		fmtV(LocalPlayer.Character and ActorTargeting.GetActorRoot(LocalPlayer) and ActorTargeting.GetActorRoot(LocalPlayer).Position),
		fmtV(ghostPos)
	))
	add("state " .. Mark.stateLine())
	add(string.format(
		"why t=%s d=%s sliding=%s dribbling=%s slideAim=%s moveCmd=%s",
		tackleWhy,
		dribbleWhy,
		tostring(ClientSlide.IsSlideTackling()),
		tostring(ClientDodge.IsDribbling()),
		fmtV(slideAim),
		fmtV(LocalPlayer.Character and origGetMove(LocalPlayer.Character) or nil)
	))
	if predict then
		add(string.format(
			"predict dist=%.2f eta=%.3f catch=%s fire=%s samples=%s inst=%.2f recent=%.2f mean=%.2f spd=%.2f accel=%s hit=%s aim=%s behind=%s track=%s",
			predict.dist or -1,
			predict.eta or -1,
			tostring(predict.catch),
			tostring(predict.fire),
			tostring(predict.samples),
			predict.instSpd or -1,
			predict.recentSpd or -1,
			predict.meanSpd or -1,
			predict.spd or -1,
			fmtV(predict.accel),
			fmtV(predict.hit),
			fmtV(predict.aim),
			tostring(predict.behind),
			tostring(predict.track)
		))
	else
		add("predict=nil")
	end
	if dribbleDanger then
		add(string.format(
			"dribble dist=%.2f fire=%s close=%s elapsed=%s ang=%s heading=%s hitP=%s",
			dribbleDanger.dist or -1,
			tostring(dribbleDanger.fire),
			tostring((dribbleDanger.dist or 99) <= CFG.DribbleClose),
			tostring(dribbleDanger.elapsed),
			tostring(dribbleDanger.ang),
			fmtV(dribbleDanger.heading),
			fmtV(dribbleDanger.hitP)
		))
	else
		add("dribbleDanger=nil")
	end
	add(string.format("cd tackle=%.2f dribble=%.2f wire=%d pending=%d", cdLeft(lastTackleAt, tackleEnforced), cdLeft(lastDodgeAt, dodgeEnforced), Wire.n, #Log.pending))
	add(string.format(
		"shot why=%s dist=%s curve=%s spin=%s aim=%s vel=%s vdir=%s org=%s from=%s point=%s lob=%s h=%s gap=%s ang=%s side=%s mouth=%s pool=%s band=%s lock=%s hold=%s",
		tostring(Shoot.why),
		Shoot.dist and string.format("%.1f", Shoot.dist) or "-",
		Shoot.curve and string.format("%.2f", Shoot.curve) or "-",
		fmtV(Shoot.spin),
		fmtV(Shoot.aim and Shoot.aim.Direction),
		fmtV(Shoot.launch),
		Shoot.launch and fmtV(Shoot.launch.Unit) or "-",
		fmtV(Shoot.aim and Shoot.aim.Origin),
		fmtV(Shoot.sampleFrom),
		fmtV(Shoot.point),
		tostring(Shoot.lob == true),
		Shoot.hFrac and string.format("%.2f", Shoot.hFrac) or "-",
		Shoot.gap and string.format("%.1f", Shoot.gap) or "-",
		Shoot.ang and string.format("%.1f", Shoot.ang) or "-",
		Shoot.hitSide ~= nil and string.format("%.1f", Shoot.hitSide) or "-",
		Shoot.mouth and string.format("%.1f", Shoot.mouth) or "-",
		tostring(Shoot.poolN or "-"),
		tostring(Shoot.band or "-"),
		tostring(Shoot.locked == true),
		tostring(Shoot.hold == true)
	))
	add("-- ring")
	if Log.n < Log.N then
		for i = 1, Log.n do
			add(Log.ring[i])
		end
	else
		for i = 0, Log.N - 1 do
			add(Log.ring[(Log.head + i - 1) % Log.N + 1])
		end
	end
	writefile("illegalsoccerlog.txt", table.concat(lines, "\n") .. "\n")
end

Mark.holdJump = function()
	Mark.walk = Mark.walk or require(Client.Gameplay.Player.Movement)
	if not Mark.jumpHooked then
		Mark.jumpHooked = true
		local oldBlock = Mark.walk.SetJumpStateBlocked
		local oldMin = Mark.walk.SetMinimum
		Mark.walk.SetJumpStateBlocked = function(name, on)
			if Mark.aerial and name == "BallCarrier" then
				return oldBlock(name, false)
			end
			return oldBlock(name, on)
		end
		Mark.walk.SetMinimum = function(name, values)
			if Mark.aerial and name == "BallCarrier" then
				return oldMin(name, nil)
			end
			return oldMin(name, values)
		end
	end
	Mark.walk.SetJumpStateBlocked("BallCarrier", false)
	Mark.walk.SetMinimum("BallCarrier", nil)
end

Mark.endJump = function()
	if Mark.walk and Mark.walk.ReleaseJump then
		Mark.walk.ReleaseJump()
	end
end

Mark.doJump = function(why)
	local character = LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and hum) then
		return false
	end
	if not CharacterControllers.IsLanded(character, hum) then
		if why == "L" or (why == "counter" and os.clock() - (Mark.jumpFailAt or 0) > 0.6) then
			Mark.jumpFailAt = os.clock()
			logFile("jump", "no", "air", why)
		end
		return false
	end
	if os.clock() - (Mark.agentJump or 0) < 0.15 then
		if why == "L" then
			logFile("jump", "cd", why)
		end
		return false
	end
	Mark.holdJump()
	Mark.walk = Mark.walk or require(Client.Gameplay.Player.Movement)
	if Mark.walk.ReleaseJump then
		Mark.walk.ReleaseJump()
	end
	-- Movement.Jump calls the jump-started handler = Sprint.spendJumpStamina, which returns false (no jump, no error)
	-- when stamina is short and no unlimited-stamina source is set. That was the "AutoBlock sometimes does not jump".
	Mark.sprint = Mark.sprint or require(Client.Gameplay.Player.Sprint)
	Mark.sprint.SetUnlimitedStamina("AgentJump", true)
	local ok = Mark.walk.Jump()
	task.delay(0.4, function()
		Mark.sprint.SetUnlimitedStamina("AgentJump", false)
	end)
	if not ok and Mark.walk.SetJumpStateBlocked then
		local blocks = Mark.jumpBlocks and Mark.jumpBlocks()
		if type(blocks) == "table" and blocks.HeldJump and not blocks.Server and not blocks.Ragdoll then
			pcall(function()
			Mark.walk.SetJumpStateBlocked("HeldJump", false)
		end)
			ok = Mark.walk.Jump()
		end
	end
	if not ok then
		if why == "L" or os.clock() - (Mark.jumpFailAt or 0) > 0.6 then
			Mark.jumpFailAt = os.clock()
			local names = {}
			local blocks = Mark.jumpBlocks and Mark.jumpBlocks()
			if type(blocks) == "table" then
				for k, v in blocks do
					if v then
						names[#names + 1] = tostring(k)
					end
				end
			end
			logFile("jump", "fail", why or "?", #names > 0 and table.concat(names, ",") or "no-block", string.format("jh %.1f", hum.JumpHeight or -1))
		end
		return false
	end
	Mark.agentJump = os.clock()
	Mark.jumpHoldUntil = os.clock() + 0.18
	logFile("jump", "ok", why or "block")
	return true
end

Mark.defendGoal = function()
	local ours = teamKey(ActorTeams.GetActorTeamName(LocalPlayer))
	local map = Workspace:FindFirstChild("Map")
	local data = map and map:FindFirstChild("Data")
	local folder = data and ours and data:FindFirstChild(ours)
	local g = folder and folder:FindFirstChild("Goal")
	if g and g:IsA("BasePart") then
		return g
	end
	return nil
end

-- Enemy outfield carrier pose for AutoBlock: displayed CharacterMotion pose, same source as the tackle solver.
Mark.blockTarget = function()
	local oid = liveOwnerId()
	if type(oid) ~= "number" or oid == 0 then
		return nil
	end
	local carrier, cr = enemyCarrier(oid)
	if not carrier then
		return nil
	end
	local ch = Actors.GetCharacter(carrier)
	local p, v = Mark.carrierPose(cr, ch)
	return carrier, cr, ch, p, v
end

-- Kick hitbox reach ahead of the aimed root: HitboxSettings.Kick CFrameOffset Z -1.5, Size Z 7 -> 5 studs.
Mark.kickReach = function()
	local k = HitboxSettings.Kick
	return -k.CFrameOffset.Z + k.Size.Z * 0.5
end

-- Non-owner kick hitbox is oriented by the charge aim ray (Shoot release -> AimFacing.GetAimedRoot(root, ray)),
-- not by body facing. While we charge without the ball, point the ray (Reticle hook) and the body at the carrier.
Mark.blockCharge = function(root)
	local charging = ChargedKick.IsCharging and ChargedKick.IsCharging()
	local aim = nil
	if CFG.AutoBlock and charging and liveOwnerId() ~= LocalPlayer.UserId then
		local carrier, _, _, p = Mark.blockTarget()
		if carrier and flat(p - root.Position).Magnitude <= 42 then
			aim = unitOrNil(flat(p - root.Position))
		end
	end
	if aim then
		if not Mark.blockAim then
			logFile("block charge", "aim", fmtV(aim))
		end
		Mark.chargeFace = aim
		Mark.blockAim = aim
		TurnControl.LockAutoRotate("AimCharge", aim)
	elseif Mark.blockAim then
		Mark.chargeFace = nil
		Mark.blockAim = nil
		TurnControl.ReleaseAutoRotate("AimCharge")
	end
end

Mark.blockIntercept = function(character, root)
	local _, _, samples, ts = Mark.ballPath(root)
	if not samples then
		return nil
	end
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local spd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false)
	local rcv = HitboxSettings.Receive
	local half = rcv.Size.X * 0.5
	local lo = rcv.CFrameOffset.Y - rcv.Size.Y * 0.5
	local hi = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5 + (Physics.BallRadius or 1)
	local foes = {}
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) then
			local r = ActorTargeting.GetActorRoot(actor)
			if r then
				foes[#foes + 1] = { p = r.Position, s = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(model), false) }
			end
		end
	end
	for i = 2, #samples do
		local t = ts[i]
		if t > 2.5 then
			break
		end
		local p = samples[i]
		local h = p.Y - root.Position.Y
		local g = flat(p - root.Position).Magnitude
		if h >= lo and h <= hi and math.max(g - half, 0) / spd + 0.05 <= t then
			local first = true
			for _, f in foes do
				if f.s > 1 and math.max(flat(p - f.p).Magnitude - half, 0) / f.s < t then
					first = false
					break
				end
			end
			if first then
				return { p = p, t = t, g = g, h = h }
			end
		end
	end
	return nil
end

-- CounterJump. An opponent at the ball leaves the ground (plain jump with the ball, jump next to an airborne ball)
-- or starts a RainbowFlick (ball detaches after BallDetachSeconds and pops up): we jump right after him, so the ball
-- meets our body / receive box in the air instead of passing over us. Plain jump: on his take-off (landed -> air
-- edge, seen through CharacterControllers.IsLanded on his model). Flick: at detach minus our rise time. Only when we
-- are close enough to matter (CFG.CounterJumpRange of him and of the ball) and do not own the ball.
-- CounterJump x AutoTackle (CFG.CounterTackle).
-- Dump facts: SlideTackleInput.HandleInputBegan never asks IsLanded, but it blocks the JUMP for the whole slide
-- (SetJumpStateBlocked("SlideTackle") until the tail), so the only order that works is jump -> slide, never slide -> jump.
-- RainbowFlick.Constants.BallDetachSeconds = 0.4: a slide lands HitboxDelaySeconds (0.27) + ping after the press, so
-- against a flick wind-up the slide FITS when it is pressed early, and the jump is what we do when it does not.
--   flick wind-up on the ground -> slide at him now if eta + ping fits in the time left (the flick never happens),
--                                  otherwise the old jump at detach minus rise;
--   he leaves the ground         -> jump (as before), then a slide from the air at him if his body is at our slide
--                                  box height when the hitbox is live (Mark.counterComboTick).
-- Never when a teammate is on him / on the slide line, he is in Dodge iframe, or the tackle is on cooldown.
Mark.counterTackle = function(character, root, actor, model, r, flickLeft)
	if CFG.CounterTackle == false or not CFG.AutoTackle then
		return false, "off"
	end
	if os.clock() - lastTackleAt < tackleEnforced then
		return false, "cd"
	end
	if Dodge.IsDribbling(model) then
		return false, "iframe"
	end
	local myD = flat(root.Position - r.Position).Magnitude
	for _, m in Actors.GetAllCharacterModels() do
		local a = Actors.GetFromCharacter(m)
		if a and a ~= LocalPlayer and sameTeam(a) and not isGoalkeeper(a) and not Mark.mateDown(a, m) then
			local ar = ActorTargeting.GetActorRoot(a)
			if ar then
				local d = flat(ar.Position - r.Position).Magnitude
				if d < 7 and d < myD then
					return false, "mate"
				end
			end
		end
	end
	local okS, solved = pcall(solveIntercept, root, r, model, tackleTuning())
	if not (okS and solved) then
		return false, "solve"
	end
	if not solved.fire then
		return false, solved.wait or "nofire"
	end
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	if flickLeft and (solved.eta or 9) + ping > flickLeft - 0.03 then
		return false, "late"
	end
	-- a teammate on the slide line is knocked over by it
	local line = solved.aim * math.min(solved.dist or 12, 20)
	for _, m in Actors.GetAllCharacterModels() do
		local a = Actors.GetFromCharacter(m)
		if a and a ~= LocalPlayer and sameTeam(a) then
			local ar = ActorTargeting.GetActorRoot(a)
			if ar then
				local rel = flat(ar.Position - root.Position)
				local along = rel:Dot(solved.aim)
				if along > 0 and along < line.Magnitude and (rel - solved.aim * along).Magnitude < 2.4 then
					return false, "mate on line"
				end
			end
		end
	end
	predict = solved
	local sent, why = tryTackle(character, root, solved.aim, solved.mult, { char = model, root = r })
	if sent then
		logFile("counter tackle", "ground", actorName(actor), "eta", string.format("%.2f", solved.eta or 0), "left", flickLeft and string.format("%.2f", flickLeft) or "-", "dist", string.format("%.1f", solved.dist or 0))
	end
	return sent, why
end

-- After the counter jump: slide from the air. Heights are ballistic for both bodies (workspace gravity, the field is
-- flat: floor = our root Y when we left the ground), the horizontal part is the same multiplier window the ground
-- solver uses. Fires on the first frame a legal (time, multiplier) pair puts his body in our slide box.
Mark.counterCombo = nil
Mark.counterComboTick = function(character, root)
	local cb = Mark.counterCombo
	if not cb then
		return
	end
	local now = os.clock()
	if now > cb.untilT or not (cb.model and cb.model.Parent and cb.root and cb.root.Parent) then
		Mark.counterCombo = nil
		return
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if CharacterControllers.IsLanded(character, hum) then
		if now - cb.at > 0.15 then
			Mark.counterCombo = nil
		end
		return
	end
	local chargingNow = ChargedKick.IsCharging and ChargedKick.IsCharging()
	local tackleBusy = os.clock() - lastTackleAt < tackleEnforced or ClientSlide.IsSlideTackling() or CFG.CounterTackle == false or not CFG.AutoTackle
	if Dodge.IsDribbling(cb.model) then
		return
	end
	-- kick leg of the bundle: rolled at the jump, or the slide is on cooldown / not legal after 0.3 s in the air
	if (cb.kind == "kick" or tackleBusy) and not chargingNow and not Mark.ak and CFG.AutoKick ~= false then
		local okK = Mark.akTry("counter", cb.model, cb.root, true)
		if okK then
			Mark.counterCombo = nil
			return
		end
	end
	if cb.kind == "kick" or tackleBusy or chargingNow then
		return
	end
	local pos, vel, worldVel = Mark.carrierPose(cb.root, cb.model)
	local origin = root.Position
	local flatNow = flat(pos - origin).Magnitude
	if flatNow > 26 then
		return
	end
	local g = Workspace.Gravity
	if type(g) ~= "number" or g < 10 then
		g = 196.2
	end
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local myVy = root.AssemblyLinearVelocity.Y
	local hisVy = typeof(worldVel) == "Vector3" and worldVel.Y or 0
	local boxS = HitboxSettings.SlideTackle
	local lo = boxS.CFrameOffset.Y - boxS.Size.Y * 0.5 - 1.6
	local hi = boxS.CFrameOffset.Y + boxS.Size.Y * 0.5 + 1.6
	local mid = Mark.slideBox()
	local mHi = math.max(0.4, CFG.TackleSpeed)
	local mLo = math.min(mHi, CFG.TackleMinSpeed or 0.6)
	local t0 = C.HitboxDelaySeconds
	local t1 = t0 + C.HitboxSeconds
	local bestT, bestPred, bestMult, bestDy
	local t = t0
	while t <= t1 + 1e-4 do
		local yUs = math.max(cb.floor, origin.Y + myVy * t - 0.5 * g * t * t)
		local yHim = math.max(cb.floor, pos.Y + hisVy * (t + ping * 0.5) - 0.5 * g * (t + ping * 0.5) ^ 2)
		local dy = yHim - yUs
		if dy >= lo and dy <= hi then
			local pred = pos + vel * (t + ping * 0.5)
			local d = flat(pred - origin).Magnitude
			local mC = (d - mid) / math.max(Mark.dumpTravel(t), 1)
			if mC >= mLo * 0.85 and mC <= mHi * 1.12 then
				bestT, bestPred, bestMult, bestDy = t, pred, math.clamp(mC, mLo, mHi), dy
				break
			end
		end
		t += 0.02
	end
	if not bestT then
		-- the slide has no legal (time, multiplier) pair yet: do not wait for it - the charged Kick (both bodies are in the
		-- air, it is legal there) goes out after a short beat; the slide keeps its chance on the frames before that
		if now - cb.at > (CFG.CounterKickDelay or 0.08) and not chargingNow and not Mark.ak and CFG.AutoKick ~= false then
			if Mark.akTry("counter", cb.model, cb.root, true) then
				Mark.counterCombo = nil
			end
		end
		return
	end
	local aim = unitOrNil(flat(bestPred - origin))
	if not aim then
		return
	end
	predict = {
		dist = flatNow, distLive = flat(cb.root.Position - origin).Magnitude, delay = 0, livePos = cb.root.Position, serverPos = pos,
		eta = bestT, spd = vel.Magnitude, hit = bestPred, iframe = 0,
	}
	local sent = tryTackle(character, root, aim, bestMult, { char = cb.model, root = cb.root })
	if sent then
		logFile("counter tackle", "air", actorName(cb.actor), "eta", string.format("%.2f", bestT), "dy", string.format("%.1f", bestDy), "dist", string.format("%.1f", flatNow), "mult", string.format("%.2f", bestMult))
		Mark.counterCombo = nil
	end
end

Mark.airSeen = {}
-- Both in the air without our own counter jump (the player jumped, or he is mid bicycle kick): an enemy within the kick
-- reach of our airborne body gets the charged Kick at once (urgent: first legal release), when the box reaches him.
Mark.counterAirKick = function(character, root)
	if CFG.AutoKick == false or Mark.ak or os.clock() - (Mark.airKickAt or 0) < 0.5 then
		return
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or CharacterControllers.IsLanded(character, hum) or liveOwnerId() == LocalPlayer.UserId then
		return
	end
	if (ChargedKick.IsCharging and ChargedKick.IsCharging()) or Mark.counterCombo then
		return
	end
	local reach = Mark.kickReach() + 3
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) then
			local r = ActorTargeting.GetActorRoot(actor)
			local h = model:FindFirstChildOfClass("Humanoid")
			if r and h and not CharacterControllers.IsLanded(model, h) and flat(r.Position - root.Position).Magnitude <= reach and math.abs(r.Position.Y - root.Position.Y) <= 6 then
				Mark.airKickAt = os.clock()
				if Mark.akTry("air", model, r, true) then
					return
				end
			end
		end
	end
end

Mark.tickCounterJump = function(character, root)
	if not CFG.CounterJump then
		return
	end
	Mark.counterComboTick(character, root)
	Mark.counterAirKick(character, root)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (hum and CharacterControllers.IsLanded(character, hum)) or liveOwnerId() == LocalPlayer.UserId then
		return
	end
	if os.clock() - (Mark.counterAt or 0) < 0.6 then
		return
	end
	local ball = Renderer.GetPosition() or Renderer.GetMainMatchPosition()
	if typeof(ball) ~= "Vector3" then
		return
	end
	local range = CFG.CounterJumpRange
	if flat(ball - root.Position).Magnitude > range + 3 then
		return
	end
	Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
	local oid = liveOwnerId()
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) then
			local r = ActorTargeting.GetActorRoot(actor)
			local h = model:FindFirstChildOfClass("Humanoid")
			local isOwner = type(oid) == "number" and actor.UserId == oid
			if r and h and flat(r.Position - root.Position).Magnitude <= range + 2 and (isOwner or flat(ball - r.Position).Magnitude <= 9) then
				local air = not CharacterControllers.IsLanded(model, h)
				local was = Mark.airSeen[model]
				Mark.airSeen[model] = air
				-- air episode: the landed->air edge needs two polls in range (and the poll ran at half rate); an enemy who
				-- is already rising when first seen (jumped from outside the range, or the edge fell in a skipped frame)
				-- was ignored and AutoTackle slid at the airborne carrier instead. Treat the first sight of an episode that
				-- is younger than 0.4 s as the edge.
				Mark.airEp = Mark.airEp or setmetatable({}, { __mode = "k" })
				if not air then
					Mark.airEp[model] = nil
				elseif not Mark.airEp[model] then
					Mark.airEp[model] = { t = os.clock(), done = false }
				end
				local ep = Mark.airEp[model]
				local why = nil
				if (air or Mark.enemyWind(actor)) and (not Mark.ctWatchAt or os.clock() - Mark.ctWatchAt > 0.5) then
					Mark.ctWatchAt = os.clock()
					logFile("counter watch", actorName(actor), "air", tostring(air), "was", tostring(was), "owner", tostring(isOwner), "epAge", ep and string.format("%.2f", os.clock() - ep.t) or "-", "done", tostring(ep and ep.done), "wind", tostring(Mark.enemyWind(actor)), "d", string.format("%.1f", flat(r.Position - root.Position).Magnitude), "cd", string.format("%.2f", os.clock() - (Mark.counterAt or 0)))
				end
				if air and ep and not ep.done and os.clock() - ep.t < 0.4 and (was == false or was == nil or isOwner) then
					why = "jump"
					ep.done = true
				elseif Mark.flickStart and not Mark.enemyWind(actor) then
					Mark.flickStart[actor.UserId] = nil
				end
				if why then
					-- already decided
				elseif type(oid) == "number" and actor.UserId == oid and Mark.enemyWind(actor) then
					local st = Mark.flickStart and Mark.flickStart[actor.UserId]
					if not st then
						Mark.flickStart = Mark.flickStart or {}
						Mark.flickStart[actor.UserId] = os.clock()
						st = os.clock()
					end
					-- tackle first: a slide that lands before the ball detaches means the flick never happens
					if not Mark.ctAt or os.clock() - Mark.ctAt > 0.08 then
						Mark.ctAt = os.clock()
						local fr = Mark.flickRec and Mark.flickRec[actor.UserId]
						local untilT = fr and fr.detachSrv
						local left = type(untilT) == "number" and (untilT - Workspace:GetServerTimeNow()) or (Mark.flick.Constants.BallDetachSeconds - (os.clock() - st))
						local sent, ctWhy = Mark.counterTackle(character, root, actor, model, r, left)
						if sent then
							Mark.counterAt = os.clock() + 0.4
							Mark.flickStart[actor.UserId] = nil
							return
						elseif Mark.ctSkipFor ~= st and ctWhy ~= "off" then
							Mark.ctSkipFor = st
							logFile("counter tackle", "skip", tostring(ctWhy), actorName(actor), "left", string.format("%.2f", left))
						end
					end
					local rise = Mark.riseT and Mark.riseT(Mark.jumpH or 7.2) or 0.27
					-- The flick is a known lob (RainbowFlick.GetCharacterLaunch: forward 6, up 48, his own velocity): jump when the
					-- predicted flight is at our reach at the rise time; no flight through our reach -> no jump (AutoBall runs for
					-- the landing). Without a prediction the old fixed timing (detach - rise) stays.
					local okF, fs = pcall(Mark.flickShot, actor)
					if okF and fs then
						Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
						local spdF = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false) * 1.05
						local jt, jh = Mark.planJump(root, fs.pts, fs.ts, spdF)
						if jt then
							why = "flick"
							Mark.flickStart[actor.UserId] = nil
							logFile("counter flick path", "arrive", string.format("%.2f", jt), "h", string.format("%.1f", jh), "detach in", string.format("%.2f", fs.left))
						end
					elseif os.clock() - st >= Mark.flick.Constants.BallDetachSeconds - rise - LocalPlayer:GetNetworkPing() * 0.5 then
						why = "flick"
						Mark.flickStart[actor.UserId] = nil
					end
				end
				if why and CFG.CounterCompetitor then
					-- optional: a teammate already on him owns the duel (CompetitorRadius), as in AutoBlock
					for _, m2 in Actors.GetAllCharacterModels() do
						local a2 = Actors.GetFromCharacter(m2)
						if a2 and a2 ~= LocalPlayer and sameTeam(a2) and not isGoalkeeper(a2) then
							local r2 = ActorTargeting.GetActorRoot(a2)
							if r2 and flat(r2.Position - r.Position).Magnitude <= (CFG.CounterCompetitorRadius or CFG.CompetitorRadius) then
								logFile("counter jump", "skip", "competitor", actorName(a2))
								why = nil
								break
							end
						end
					end
				end
				if why and Mark.doJump("counter") then
					Mark.counterAt = os.clock()
					local canTackle = CFG.CounterTackle ~= false and CFG.AutoTackle
					local canKick = CFG.AutoKick ~= false
					if (canTackle or canKick) and math.random() < (CFG.CounterComboChance or 0.85) then
						-- the bundle: a slide from the air, or a charged Kick (both bodies in the air), by roll
						local kind = canTackle and "tackle" or "kick"
						if canTackle and canKick and math.random() < (CFG.CounterKickChance or 0.45) then
							kind = "kick"
						end
						Mark.counterCombo = { actor = actor, model = model, root = r, at = os.clock(), untilT = os.clock() + 0.75, floor = root.Position.Y, kind = kind }
					end
					logFile("counter jump", why, actorName(actor), string.format("%.1f", flat(r.Position - root.Position).Magnitude))
					return
				end
			end
		end
	end
end

Mark.blockFrame = 0
-- why AutoBlock did nothing while an enemy owns the ball (rate-limited): "block skip <why> ..."
Mark.blockSkip = function(why, extra)
	local oid = liveOwnerId()
	if type(oid) ~= "number" or oid == 0 or oid == LocalPlayer.UserId then
		return
	end
	local pl = playerOf(oid)
	if not pl or sameTeam(pl) then
		return
	end
	if Mark.blockSkipWhy == why and os.clock() - (Mark.blockSkipAt or 0) < 1.5 then
		return
	end
	Mark.blockSkipWhy, Mark.blockSkipAt = why, os.clock()
	logFile("block skip", why, extra or "")
end
Mark.tickBlock = function(character, root)
	Mark.blockCharge(root)
	Mark.tickCounterJump(character, root)
	-- idle polling at half rate when the frame budget is tight (>= ~100 fps): a started block runs every frame
	Mark.blockFrame += 1
	if Mark.blockFrame % 2 == 0 and (Mark.dtAvg or 1) < 0.0105 and Mark.move.mode ~= "block" then
		return
	end
	if not CFG.AutoBlock then
		return
	end
	Mark.tickBlockJump(character, root)
	do
		local okS, errS = pcall(Mark.blockSlide, character, root)
		if not okS and (not Mark.blockSlideErr or os.clock() - Mark.blockSlideErr > 3) then
			Mark.blockSlideErr = os.clock()
			logFile("block slide err", tostring(errS))
		end
	end
	if Mark.move.mode == "dodge" or Mark.move.mode == "dribble" or Mark.move.mode == "flee" then
		Mark.blockSkip("mode", tostring(Mark.move.mode))
		return
	end
	if slideAim or ClientSlide.IsSlideTackling() then
		Mark.blockSkip("sliding")
		return
	end
	if ClientDodge.IsDribbling() then
		Mark.blockSkip("our dribble")
		return
	end
	if liveOwnerId() == LocalPlayer.UserId then
		if Mark.move.mode == "block" then
			logFile("block stop", "own")
			Mark.moveStop("block")
		end
		return
	end
	local ballPos = Renderer.GetPosition() or Renderer.GetTargetPosition(nil, root.Position)
	local ballVel = Renderer.GetTargetVelocity(nil, root.Position)
	local g0 = Mark.defendGoal()
	if g0 and typeof(ballPos) == "Vector3" and typeof(ballVel) == "Vector3" then
		local toGoal = flat(g0.Position - ballPos)
		local vel = flat(ballVel)
		local into = vel.Magnitude
		if toGoal.Magnitude > 8 and into > 18 and vel.Unit:Dot(toGoal.Unit) > 0.45 then
			local eta = toGoal.Magnitude / vel:Dot(toGoal.Unit)
			if eta > 0.08 and eta < 1.2 then
				local meetT = math.clamp(eta * 0.45, 0.1, 0.55)
				local dest = ballPos + vel.Unit * (vel.Magnitude * meetT)
				local gap = flat(dest - root.Position).Magnitude
				local dir = unitOrNil(flat(dest - root.Position))
				if dir and gap > 1.4 and gap < 16 then
					if not Mark.blockFly or os.clock() - Mark.blockFly > 0.35 then
						Mark.blockFly = os.clock()
						logFile("block fly", string.format("%.2f", eta), string.format("%.1f", gap), string.format("%.1f", into))
					end
					Mark.move.look = unitOrNil(flat(ballPos - root.Position)) or dir
					Mark.moveSteer(dir, "block")
					Mark.blockHold = os.clock()
					Mark.blockRoot = nil
					return
				end
			end
		end
	end
	-- a loose ball is AutoBall's once tickBall took the steering: do not fight it with the stale block hold
	do
		local o2 = liveOwnerId()
		if Mark.move.mode == "ball" and not (type(o2) == "number" and o2 ~= 0) then
			return
		end
	end
	-- The carrier we were shadowing let the ball go (pass / touch away): take the ball path instead of following
	-- his body. Earliest path sample we reach (Receive hitbox, run speed) before any opponent can.
	do
		local oidB = liveOwnerId()
		local freeBall = not (type(oidB) == "number" and oidB ~= 0)
		if freeBall and Mark.blockLast and os.clock() - Mark.blockLast < 1.5 then
			local spot = Mark.blockIntercept(character, root)
			if spot then
				local to = flat(spot.p - root.Position)
				if to.Magnitude > 0.8 then
					if not Mark.blockIcLog or os.clock() - Mark.blockIcLog > 0.4 then
						Mark.blockIcLog = os.clock()
						logFile("block intercept", "t", string.format("%.2f", spot.t), "g", string.format("%.1f", spot.g), "h", string.format("%.1f", spot.h))
					end
					Mark.move.look = to.Unit
					Mark.moveSteer(to.Unit, "block")
					Mark.blockHold = os.clock()
					Mark.blockRoot = nil
					return
				end
			end
		end
	end
	local held = Mark.blockHold and os.clock() - Mark.blockHold < 0.45 and (not Mark.blockRoot or Mark.blockRoot.Parent)
	local carrier, cr, chE, P, V = Mark.blockTarget()
	if not carrier then
		if Mark.move.mode == "block" and not held then
			logFile("block stop", "no carrier")
			Mark.moveStop("block")
		end
		Mark.blockSkip("no carrier")
		return
	end
	local g = Mark.defendGoal()
	if not g then
		if Mark.move.mode == "block" then
			logFile("block stop", "no goal")
			Mark.moveStop("block")
		end
		return
	end
	local rel = flat(root.Position - P)
	local dist = rel.Magnitude
	-- (air duels are handled by Mark.tickCounterJump)
	local eg = flat(g.Position - P)
	if eg.Magnitude < 1 then
		return
	end
	local u = eg.Unit
	local along = rel:Dot(u)
	local active = Mark.move.mode == "block"
	local goalSide = along > -1
	local range = goalSide and ((CFG.BlockRange or 28) + (active and 6 or 0)) or ((CFG.BlockBehind or 14) + (active and 4 or 0))
	if dist > range then
		if active then
			logFile("block stop", goalSide and "far" or "behind", string.format("%.1f", dist), string.format("%.1f", along))
			Mark.moveStop("block")
		end
		Mark.blockSkip(goalSide and "far" or "behind", string.format("dist %.1f range %.1f along %.1f", dist, range, along))
		return
	end
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if CFG.BlockCompetitor ~= false and actor and actor ~= LocalPlayer and sameTeam(actor) and not isGoalkeeper(actor) and not Mark.mateDown(actor, model) then
			local ar = ActorTargeting.GetActorRoot(actor)
			if ar then
				-- CompetitorCheck: a teammate (keeper excluded above) already within CompetitorRadius of the carrier owns
				-- this duel; we only take carriers nobody is on. A stunned / ragdolled / frozen mate owns nothing
				-- (Mark.mateDown), and one who is about to get up is not counted either while he is also behind us
				local mRel = flat(ar.Position - P)
				if mRel.Magnitude <= CFG.CompetitorRadius + (active and 0 or 1) then
					if active then
						logFile("block stop", "mate", actorName(actor), string.format("%.1f", mRel.Magnitude))
						Mark.moveStop("block")
					end
					Mark.blockSkip("mate", actorName(actor) .. string.format(" %.1f", mRel.Magnitude))
					return
				end
			end
		end
	end
	-- AutoKick inside the block: the shadow spot keeps him at the edge of our kick box; when the box really reaches him
	-- (Mark.akTry predicts the release against his pose) the charge goes out and is released by the box
	if CFG.AutoKick ~= false and dist <= Mark.kickReach() + (CFG.AutoKickRange or 5.5) and chE then
		Mark.akTry("block", chE, cr, false)
	end
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local mySpd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false)
	if type(mySpd) ~= "number" or mySpd < 8 then
		mySpd = 16
	end
	-- Shadow spot: on his line to our goal, one stud inside our kick hitbox reach, led by our arrival time.
	local gap = math.max(CFG.BlockGapMin or 2.2, Mark.kickReach() - 1 - (CFG.BlockCloser or 1.0))
	-- P is the DISPLAYED pose (CharacterMotion.GetPosition), behind his server pose by GetDisplayDelaySeconds.
	local delay = chE and math.clamp(CharacterMotion.GetDisplayDelaySeconds(chE) or 0, 0, 0.25) or 0
	-- displayed pose lags the server pose, and the packet itself lags by ping. Stand where he will be.
	local lag = delay + math.clamp(LocalPlayer:GetNetworkPing() or 0, 0, 0.22) + 0.1
	-- light EMA on his velocity (carrierPose differentiates positions every >= 25 ms; single-step jitter swings the spot)
	do
		local nowc = os.clock()
		local bs = Mark.blockVs
		if bs and bs.ch == chE and nowc - bs.t < 0.2 then
			local k = 1 - math.exp(-(nowc - bs.t) / 0.06)
			V = bs.v + (V - bs.v) * k
		end
		Mark.blockVs = { ch = chE, t = nowc, v = V }
	end
	-- He is charging a kick (ActionPresentationUpdate KickChargeStarted/Updated carries his aim): stand on his
	-- shot line instead of the goal line, so the release hits our body.
	local shotLine = nil
	if Mark.chargeLive and Mark.chargeDir and Mark.chargeUntil and os.clock() < Mark.chargeUntil and Mark.chargeId == liveOwnerId() then
		shotLine = unitOrNil(flat(Mark.chargeDir))
	end
	-- Predicted shot line BEFORE the charge packet. KickChargeStarted arrives after he has already wound up, and
	-- his displayed pose is behind the server pose by display-delay + ping, so waiting for the packet and then
	-- stepping onto the line is already late. Velocity toward our goal, else a loose facing (dot > 0.35), is the
	-- line we stand on now. The charge dir above only corrects it when the packet lands.
	local faceLine = false
	if not shotLine then
		local guess = nil
		if V.Magnitude > 4.5 and V.Unit:Dot(u) > 0.35 then
			guess = V.Unit
		elseif cr then
			local look = unitOrNil(flat(cr.CFrame.LookVector))
			if look and look:Dot(u) > 0.35 and flat(g.Position - P).Magnitude < 110 then
				guess = look
			end
		end
		if guess then
			shotLine = guess
			faceLine = true
		end
	end
	do
		-- KickPowerups: the Supercharge item scales the kick and PoweredUpBodyKnockbackMultiplier (1.75) the body
		-- knock-back; the Ragdoll module has a Supercharged state with its own VFX. Nothing else in the client dump
		-- gates a body block by ball speed (Receiving.Resolve only picks Receive / Trap / Bounce by speed).
		local okP, mult = pcall(function()
			Mark.kpMod = Mark.kpMod or require(Modules.Actions.KickPowerups)
			return chE and Mark.kpMod.GetMultiplier(chE) or 1
		end)
		local powered = okP and type(mult) == "number" and mult > 1
		if powered and not Mark.poweredLogged then
			Mark.poweredLogged = true
			logFile("block powered", "mult", string.format("%.2f", mult), "dist", string.format("%.1f", dist))
		elseif not powered then
			Mark.poweredLogged = nil
		end
	end
	if shotLine and not Mark.shotLineLogged then
		Mark.shotLineLogged = true
		logFile("block shotline", faceLine and "facing" or "charge", fmtV(shotLine), "dist", string.format("%.1f", dist))
	elseif not shotLine then
		Mark.shotLineLogged = nil
	end
	-- Lead = OUR arrival time at the moving shadow spot (fixed point of t = |spot(t) - us| / run speed), not the
	-- distance to his body.
	-- Extrapolate at most 0.5 s and at most 30 studs/s. lag + lead reached ~1.1 s, so a sprinting carrier (log: 31.9)
	-- put the spot 35 studs away along his velocity and, running AWAY from our goal, past his own back: we ran through
	-- him to get there.
	local Vc = V.Magnitude > 30 and V.Unit * 30 or V
	local function spotAt(t)
		local Pt = P + Vc * math.min(t + lag, 0.5)
		return Pt, shotLine or unitOrNil(flat(g.Position - Pt)) or u
	end
	local lead = 0.1
	for _ = 1, 4 do
		local Pt, ut = spotAt(lead)
		lead = math.clamp(flat(Pt + ut * gap - root.Position).Magnitude / mySpd, 0.05, 0.8)
	end
	local Pf, uf = spotAt(lead)
	local dest = Pf + uf * gap
	local target = dest
	local around = false
	-- Between him and the goal: the old spot ran back toward the carrier (gap 4 in front of him) = into his dribble
	-- and tackle range while he winds up. The ball meets us anywhere on the line, so stand ON the line at the depth
	-- we already have (clamped gap..26): a sideways step is the shortest move and the one the wind-up leaves time for.
	local ahead = false
	do
		local relL = flat(root.Position - Pf)
		local dAlong = relL:Dot(uf)
		if dAlong >= gap * 0.5 then
			ahead = true
			dest = Pf + uf * math.clamp(dAlong, gap, 26)
			target = dest
		end
	end
	if not ahead and rel:Dot(uf) < gap * 0.5 then
		-- level with him or behind: go round his body to the shot/goal side instead of running through him
		local perp = Vector3.new(-uf.Z, 0, uf.X)
		local s = (rel:Dot(perp) >= 0) and 1 or -1
		local body = HitboxSettings.Receive.Size.X * 0.5 + 1.5
		local wp = Pf + perp * (s * body) + uf * 1
		if flat(wp - root.Position).Magnitude > 1.5 then
			target = wp
			around = true
		end
	end
	-- The target keeps at least `gap` on the GOAL side of where he is now, whatever the prediction says. A target at or
	-- behind his body is what made the shadow run round him and end up at his back. (Only when we are not already
	-- level/behind: that case has its own go-round waypoint above.)
	if not around then
		local Pc = P + Vc * math.min(lag, 0.35)
		local aT = flat(target - Pc):Dot(uf)
		if aT < gap then
			target = target + uf * (gap - aT)
			dest = target
		end
	end
	-- The replicated charge gives the real shot (ChargePathVelocity at full charge + the game's ball physics): stand on the
	-- path sample we reach with the most time to spare, whatever the geometry of the guessed line says.
	local pathSpot = nil
	if shotLine and Mark.chargeId == liveOwnerId() and not faceLine then
		local okC, ps = pcall(Mark.chargeSpot, character, root, Mark.chargeId)
		if okC and ps then
			pathSpot = ps
			target, dest, around, ahead = Vector3.new(ps.p.X, root.Position.Y, ps.p.Z), Vector3.new(ps.p.X, root.Position.Y, ps.p.Z), false, true
			if not Mark.blockPathLog or os.clock() - Mark.blockPathLog > 0.4 then
				Mark.blockPathLog = os.clock()
				logFile("block path", "t", string.format("%.2f", ps.t), "slack", string.format("%.2f", ps.slack), "ok", tostring(ps.ok), "move", string.format("%.1f", ps.d), "tRel", string.format("%.2f", ps.tRel), "speed", string.format("%.0f", ps.speed), "cross", fmtV(ps.cross))
			end
		elseif not Mark.blockPathNoLog or os.clock() - Mark.blockPathNoLog > 1 then
			Mark.blockPathNoLog = os.clock()
			logFile("block path", "none", okC and "no spot" or tostring(ps), "args", tostring(Mark.cpvArgs[Mark.chargeId] ~= nil))
		end
	end
	local off = flat(target - root.Position)
	-- ControllerManager.MovingDirection = unit * min(|MoveCommand|, 1): command his velocity plus the spot error, as a fraction of our run speed
	local desired = V + off * 4
	if pathSpot then
		desired = off * 4
	elseif ahead then
		-- stand-in-line: follow only his sideways drift, not the run toward us
		desired = (V - uf * V:Dot(uf)) + off * 4
	end
	local cmd = Vector3.zero
	if off.Magnitude > 0.6 or V.Magnitude > 2 then
		cmd = desired / mySpd
		if cmd.Magnitude > 1 then
			cmd = cmd.Unit
		end
		-- Move hooks only override input above 0.2 (GetMoveCommand/SetMoveCommand): below that, stand
		if cmd.Magnitude < 0.2 then
			cmd = Vector3.zero
		end
	end
	if not Mark.blockLogged then
		Mark.blockLogged = true
		Mark.blockAt = os.clock()
		logFile("block start", "lead", string.format("%.2f", lead), "ahead", tostring(ahead), "clamp", tostring(os.clock() - (Mark.chargeClamped or -9) < 0.5), "lag", string.format("%.3f", lag), "dist", string.format("%.2f", dist), "along", string.format("%.2f", along), "gap", string.format("%.1f", gap), "around", tostring(around), "spd", string.format("%.1f", V.Magnitude))
	end
	Mark.blockRoot = cr
	Mark.blockHold = os.clock()
	Mark.blockLast = os.clock()
	Mark.blockDest = dest
	if not Mark.blockTraceAt or os.clock() - Mark.blockTraceAt > 0.5 then
		Mark.blockTraceAt = os.clock()
		local latB = math.abs(flat(root.Position - P):Dot(Vector3.new(-uf.Z, 0, uf.X)))
		logFile("block track", "dist", string.format("%.1f", dist), "along", string.format("%.1f", along), "lat", string.format("%.1f", latB), "his", string.format("%.1f", V.Magnitude), "off", string.format("%.1f", off.Magnitude), "ahead", tostring(ahead), "around", tostring(around))
	end
	do
		local face = unitOrNil(flat(P - root.Position))
		Mark.move.look = face or Mark.chargeFace
		if face and ChargedKick.IsCharging and ChargedKick.IsCharging() then
			Mark.chargeFace = face
			Mark.blockAim = face
			TurnControl.LockAutoRotate("AimCharge", face)
		end
	end
	Mark.move.pts = { root.Position, target }
	Mark.move.born = Mark.move.born or os.clock()
	Mark.moveSteer(cmd, "block")
	if off.Magnitude > 6 then
		Mark.agentHold(true, "chase")
	end
end

-- Tackle vs block. The slide is one committed direction; a carrier with Dodge ready dribbles it (Dodge iframe, and
-- SuccessfulDodgeSpeedBoost for him). So with AutoBlock on, the slide is only for: his Dodge seen and still on
-- RepeatDelaySeconds cooldown ("naked"), he is running away from behind us faster than block can follow ("escape"),
-- or he is inside TackleGoalZone of our goal and we are not already holding him in kick range ("goal").
Mark.tryTackle = tryTackle

-- Seconds left on the enemy keeper's dive cooldown (0 = he can dive). Only keepers (isGoalkeeper) count.
Mark.foeDiveLeft = function()
	local d = Mark.foeDive
	if not d then
		return 0
	end
	Mark.gkDiveMod = Mark.gkDiveMod or require(Modules.Actions.GoalkeeperDive)
	local cd = Mark.gkDiveMod.Constants.RepeatDelaySeconds or 1.875
	local now = os.clock()
	local left = 0
	for uid, at in d do
		if now - at > cd + 1 then
			d[uid] = nil
		else
			local a = playerOf(uid)
			if a and isGoalkeeper(a) then
				left = math.max(left, cd - (now - at))
			end
		end
	end
	return left
end

-- ===== PASS ASSIST =====================================================================================
-- The user presses Pass or Lob while the crosshair is on a teammate. The game would send FreeLowPass (a 15 deg ground
-- pass) or its AssistedPass (its own aim). We swap the press for a script-held Lob (FreeLobPass) and choose the two numbers
-- the server derives the velocity from: the aim YAW (flat direction; pitch is ignored by Pass.GetVelocity) and the CHARGE
-- seconds (hspeed 45..80 and upward speed 45..60 both come from the charge). Everything else is the game's own function
-- (ChargePathVelocity.GetLaunchVelocity -> Pass.GetVelocity, Pass.GetSpin, Physics.GetAirFlight), so the preview is the
-- flight the server will compute. Too far -> max charge (the ball lands short of him), too near -> min charge.
Mark.pa = Mark.pa or {}

Mark.paRot = function(v, a)
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

Mark.paConst = function(char)
	Mark.passMod = Mark.passMod or require(Modules.Actions.Pass)
	local ok, c = pcall(Mark.passMod.GetChargeConstants, "FreeLobPass", char)
	if ok and type(c) == "table" and type(c.MinimumChargeSeconds) == "number" and type(c.MaximumChargeSeconds) == "number" then
		return c.MinimumChargeSeconds, c.MaximumChargeSeconds
	end
	return 0.1, 0.3
end

Mark.paPose = function(sel)
	local pos, vel = Mark.carrierPose(sel.root, sel.model)
	sel.pos = pos
	sel.vel = Vector3.new(vel.X, 0, vel.Z)
end

-- One lob: returns { vel, pts, times, land, t, apex, origin } or nil.
Mark.paFlight = function(ctx, charge, dir)
	local look = Vector3.new(dir.X, 0, dir.Z)
	local origin = nil
	local okO, o = pcall(Mark.carry.GetLaunchPosition, ctx.char, "FreeLobPass", look, false, charge)
	if okO and typeof(o) == "Vector3" then
		origin = o
	else
		origin = Renderer.GetPosition()
	end
	if typeof(origin) ~= "Vector3" then
		return nil
	end
	local aim = {
		Origin = ctx.camPos,
		Direction = look,
		CameraCFrame = CFrame.lookAt(ctx.camPos, ctx.camPos + look),
		CameraFieldOfView = ctx.fov,
		IsAirborne = false,
	}
	local ok, vel = pcall(ChargePathVelocity.GetLaunchVelocity, ctx.char, charge, "FreeLobPass", aim, origin, ctx.reported, nil, nil, nil, ctx.boundary)
	if not ok or typeof(vel) ~= "Vector3" then
		return nil
	end
	local okS, spin = pcall(Mark.passMod.GetSpin, ctx.char, vel, "FreeLobPass", ctx.reported)
	local pos, v, sp = origin, vel, (okS and typeof(spin) == "Vector3") and spin or Vector3.zero
	local pts, times = { pos }, { 0 }
	local t, apex = 0, pos.Y
	local land = nil
	local step = 0.05
	for _ = 1, 100 do
		local np, nv, ns = Physics.GetAirFlight(pos, v, sp, step, ctx.tuning)
		if typeof(np) ~= "Vector3" then
			break
		end
		local prev = pos
		pos, v, sp = np, nv or v, ns or sp
		t += step
		apex = math.max(apex, pos.Y)
		pts[#pts + 1], times[#times + 1] = pos, t
		if v.Y < 0 and pos.Y <= ctx.yT then
			local a = math.clamp((prev.Y - ctx.yT) / math.max(prev.Y - pos.Y, 1e-4), 0, 1)
			land = prev:Lerp(pos, a)
			t = t - step + step * a
			pts[#pts], times[#times] = land, t
			break
		end
		if pos.Y <= ctx.floorY then
			land = Vector3.new(pos.X, ctx.floorY, pos.Z)
			pts[#pts] = land
			break
		end
	end
	land = land or pts[#pts]
	return { vel = vel, pts = pts, times = times, land = land, t = t, apex = apex, origin = origin, landedHigh = land.Y > ctx.floorY + 0.5 }
end

-- sel = { actor, model, root, ... }; fixed = charge seconds to keep (re-aim at release), nil = choose the charge.
Mark.paSolve = function(sel, fixed)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and root and Workspace.CurrentCamera) then
		return nil
	end
	Mark.paPose(sel)
	Mark.carry = Mark.carry or require(Modules.Ball.Carry)
	Mark.passMod = Mark.passMod or require(Modules.Actions.Pass)
	Mark.pathPreview = Mark.pathPreview or require(Client.Gameplay.Actions.ChargePathPreview)
	Mark.fieldSet = Mark.fieldSet or require(Modules.Gameplay.FieldSettings)
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local boundary = Mark.pathPreview.GetChargeBoundaryWorld(LocalPlayer)
	local rcv = HitboxSettings.Receive
	local okG, gy = pcall(Mark.fieldSet.GetGroundYAt, sel.pos)
	local ctx = {
		char = char,
		reported = flat(root.AssemblyLinearVelocity),
		tuning = Physics.GetCharacterTuning(char),
		boundary = boundary,
		camPos = Workspace.CurrentCamera.CFrame.Position,
		fov = Workspace.CurrentCamera.FieldOfView,
		yT = sel.pos.Y + rcv.CFrameOffset.Y,
		floorY = (okG and type(gy) == "number" and gy or (sel.pos.Y - 3.8)) + Physics.BallRadius,
	}
	local ceilY = boundary and type(boundary.CeilingY) == "number" and boundary.CeilingY or math.huge
	local ballPos = Renderer.GetPosition() or root.Position
	local goalP = enemyGoalPart()
	goalP = goalP and goalP.Position
	local leadMin = CFG.PassGoalLead or 34
	local function targetAt(tt)
		local lead = sel.vel * (tt + ping * 0.5)
		local T = sel.pos + lead
		if goalP then
			-- never predict a receive point close to their goal: shorten the lead until it is outside the zone (or drop it
			-- when he already stands inside - the keeper owns that area)
			if flat(T - goalP).Magnitude < leadMin then
				if flat(sel.pos - goalP).Magnitude < leadMin then
					return sel.pos
				end
				local lo2, hi2 = 0, 1
				for _ = 1, 6 do
					local m = (lo2 + hi2) * 0.5
					if flat(sel.pos + lead * m - goalP).Magnitude < leadMin then
						hi2 = m
					else
						lo2 = m
					end
				end
				T = sel.pos + lead * lo2
			end
		end
		return T
	end
	local function evalCharge(c, tFly, dirFixed)
		local T0 = targetAt(c + tFly)
		local dir = dirFixed or unitOrNil(flat(T0 - ballPos))
		if not dir then
			return nil
		end
		local fl = Mark.paFlight(ctx, c, dir)
		if not fl then
			return nil
		end
		local T = targetAt(c + fl.t)
		local to = flat(T - fl.origin)
		local D = to.Magnitude
		local d0 = unitOrNil(to) or dir
		local miss = flat(fl.land - T)
		local perp = Vector3.new(-d0.Z, 0, d0.X)
		return { c = c, dir = dir, fl = fl, T = T, D = D, along = miss:Dot(d0), lat = miss:Dot(perp) }
	end
	local lo, hi = Mark.paConst(char)
	local tF = Mark.pa.tFly or 1.5
	local best, status = nil, nil
	if fixed then
		best = evalCharge(math.clamp(fixed, lo, hi), tF)
	else
		local eHi = evalCharge(hi, tF)
		if not eHi then
			return nil
		end
		if eHi.along < 0 then
			best, status = eHi, "short"
		else
			local eLo = evalCharge(lo, eHi.fl.t)
			if not eLo then
				return nil
			end
			if eLo.along > 0 then
				best, status = eLo, "long"
			else
				local a, b = eLo, eHi
				best = a
				for _ = 1, 5 do
					local mid = evalCharge((a.c + b.c) * 0.5, (a.fl.t + b.fl.t) * 0.5)
					if not mid then
						break
					end
					if mid.along < 0 then
						a = mid
					else
						b = mid
					end
					if math.abs(mid.along) < math.abs(best.along) then
						best = mid
					end
				end
			end
		end
	end
	if not best then
		return nil
	end
	for _ = 1, 2 do
		if math.abs(best.lat) < 0.5 then
			break
		end
		local e2 = evalCharge(best.c, best.fl.t, Mark.paRot(best.dir, -best.lat / math.max(best.D, 8) * 0.55))
		if not e2 then
			break
		end
		if math.abs(e2.lat) + math.abs(e2.along) * 0.35 < math.abs(best.lat) + math.abs(best.along) * 0.35 - 0.3 then
			best = e2
		else
			break
		end
	end
	Mark.pa.tFly = best.fl.t
	local fl = best.fl
	local sol = {
		charge = best.c, dir = best.dir, land = fl.land, pts = fl.pts, times = fl.times, vel = fl.vel, t = fl.t, apex = fl.apex,
		origin = fl.origin, T = best.T, along = best.along, lat = best.lat, D = best.D,
		ceiling = fl.apex >= ceilY - Physics.BallRadius - 1,
	}
	sol.along3 = Vector3.new(-best.dir.Z, 0, best.dir.X)
	local contested = false
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		local r = actor and actor ~= LocalPlayer and not sameTeam(actor) and ActorTargeting.GetActorRoot(actor)
		if r and flat(r.Position - fl.land).Magnitude < (isGoalkeeper(actor) and (CFG.PassKeeperRadius or 14) or 5) then
			contested = true
			break
		end
	end
	sol.contested = contested
	if status then
		sol.status = status
	elseif math.abs(sol.lat) <= 2.4 and math.abs(sol.along) <= 4 and not sol.ceiling and not contested then
		sol.status = "ok"
	else
		sol.status = contested and "contested" or (sol.ceiling and "ceiling" or "off")
	end
	sol.ok = sol.status == "ok"
	return sol
end

-- Every teammate we could pass to (range, alive, not standing in their goal mouth). Drawn whether or not the crosshair
-- is on them: the old mark existed only after a solved flight and sat on the ground under the model, so nothing showed.
Mark.paList = function(root)
	local list = {}
	local ballPos = Renderer.GetPosition() or root.Position
	local goal = enemyGoalPart()
	local zone = CFG.PassGoalZone or 36
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		local r = actor and actor ~= LocalPlayer and sameTeam(actor) and ActorTargeting.GetActorRoot(actor)
		if r and (CFG.PassToKeeper or not isGoalkeeper(actor)) and not Mark.mateDown(actor, model) then
			local pos = r.Position
			local flatD = flat(pos - ballPos).Magnitude
			if flatD >= (CFG.PassMinDist or 7) and flatD <= (CFG.PassMaxDist or 130) then
				if not (goal and flat(pos - goal.Position).Magnitude < zone) then
					list[#list + 1] = { actor = actor, root = r, name = actorName(actor), flatD = flatD }
				end
			end
		end
	end
	return list
end

-- The teammate under the crosshair. Candidates sit inside a cone around the camera ray (wider for close teammates);
-- one near the enemy goal and in line with it is a shooting target, and when the crosshair is closer to the goal than to
-- him while AutoShoot has a solution, the goal wins.
Mark.paSelect = function(root)
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local cf = cam.CFrame
	local look = cf.LookVector
	local ballPos = Renderer.GetPosition() or root.Position
	local goal = enemyGoalPart()
	local gdir = goal and (goal.Position - cf.Position)
	local angGoal = gdir and gdir.Magnitude > 1 and math.deg(math.acos(math.clamp(gdir.Unit:Dot(look), -1, 1))) or 999
	local prev = Mark.pa.sel
	local fov = CFG.PassFov or 12
	local best, why = nil, nil
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		local r = actor and actor ~= LocalPlayer and sameTeam(actor) and ActorTargeting.GetActorRoot(actor)
		if r and (CFG.PassToKeeper or not isGoalkeeper(actor)) and not Mark.mateDown(actor, model) then
			local pos = r.Position
			local flatD = flat(pos - ballPos).Magnitude
			if flatD >= (CFG.PassMinDist or 7) and flatD <= (CFG.PassMaxDist or 130) then
				local d = pos + Vector3.new(0, 1.5, 0) - cf.Position
				if d:Dot(look) > 0 then
					local ang = math.deg(math.acos(math.clamp(d.Unit:Dot(look), -1, 1)))
					local tol = fov
					if prev and prev.actor == actor then
						tol = math.min(fov + 6, 16)
					end
					if ang <= tol then
						local shadow = false
						if goal and gdir and gdir.Magnitude > 1 and flat(pos - goal.Position).Magnitude < (CFG.PassGoalZone or 36) then
							local a2 = math.deg(math.acos(math.clamp(d.Unit:Dot(gdir.Unit), -1, 1)))
							shadow = a2 < (CFG.PassGoalSep or 9)
						end
						if shadow then
							why = "goal shadow " .. actorName(actor)
						elseif Shoot.aim and angGoal + 0.5 < ang and angGoal <= fov * 1.3 then
							why = string.format("goal wins %.1f<%.1f", angGoal, ang)
						elseif not best or ang < best.ang then
							best = { actor = actor, model = model, root = r, ang = ang, flatD = flatD, name = actorName(actor) }
						end
					end
				end
			end
		end
	end
	local held = nil
	if prev then
		for _, model in Actors.GetAllCharacterModels() do
			local actor = Actors.GetFromCharacter(model)
			if actor == prev.actor then
				local r = ActorTargeting.GetActorRoot(actor)
				if r and not Mark.mateDown(actor, model) then
					local d = r.Position + Vector3.new(0, 1.5, 0) - cf.Position
					if d.Magnitude > 1 and d:Dot(look) > 0 then
						local ang = math.deg(math.acos(math.clamp(d.Unit:Dot(look), -1, 1)))
						if ang <= math.min(fov + 6, 16) then
							held = { actor = actor, model = model, root = r, ang = ang, flatD = flat(r.Position - ballPos).Magnitude, name = actorName(actor) }
						end
					end
				end
				break
			end
		end
	end
	if held and (not best or best.actor == held.actor or best.ang + 3 >= held.ang) then
		best = held
	end
	Mark.pa.skipWhy = (not best) and why or nil
	return best
end

Mark.passTick = function(character, root)
	local pa = Mark.pa
	local now = os.clock()
	if not CFG.PassAssist or liveOwnerId() ~= LocalPlayer.UserId or MatchSettings.IsGoalkeeperCharacter(character) then
		if not pa.live then
			pa.sel, pa.sol, pa.marks = nil, nil, nil
		end
		return
	end
	if pa.live or now - (pa.at or 0) < 0.1 then
		return
	end
	pa.at = now
	pa.marks = Mark.paList(root)
	pa.marksAt = now
	if (pa.markN or -1) ~= #pa.marks and now - (pa.markLog or 0) > 1 then
		pa.markN, pa.markLog = #pa.marks, now
		logFile("pass marks", #pa.marks)
	end
	local sel = Mark.paSelect(root)
	if not sel then
		if pa.sel and now - (pa.selAt or 0) > 0.2 then
			pa.sel, pa.sol = nil, nil
		end
		if pa.skipWhy and now - (pa.skipLog or 0) > 1.5 then
			pa.skipLog = now
			logFile("pass assist", "skip", pa.skipWhy)
		end
		return
	end
	pa.selAt = now
	if not pa.sel or pa.sel.actor ~= sel.actor then
		logFile("pass assist", "target", sel.name, "ang", string.format("%.1f", sel.ang), "dist", string.format("%.0f", sel.flatD))
	end
	pa.sel = sel
	local ok, sol = pcall(Mark.paSolve, sel)
	if ok and sol then
		pa.sol, pa.solAt = sol, now
	elseif not ok and now - (pa.errLog or 0) > 2 then
		pa.errLog = now
		logFile("pass assist", "solve-err", tostring(sol))
	end
end

Mark.paRay = function(live)
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	live.ray = {
		Origin = camPos,
		Direction = live.dir,
		CameraCFrame = CFrame.lookAt(camPos, camPos + live.dir),
		CameraFieldOfView = cam and cam.FieldOfView or 70,
		IsAirborne = false,
	}
end

-- The press: replaced by a script-held Lob whose aim ray the Reticle/packet overrides carry (live.ray).
Mark.paPress = function(forceSel, forceSol, tag)
	local pa = Mark.pa
	local char = LocalPlayer.Character
	if liveOwnerId() ~= LocalPlayer.UserId or not char or MatchSettings.IsGoalkeeperCharacter(char) then
		return false
	end
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	if not root then
		return false
	end
	local sel = forceSel or pa.sel
	if not forceSel and not (sel and sel.root and os.clock() - (pa.selAt or 0) < 0.4) then
		sel = Mark.paSelect(root)
	end
	if not sel then
		return false
	end
	local sol = forceSol or ((pa.sol and pa.sel and pa.sel.actor == sel.actor and os.clock() - (pa.solAt or 0) < 0.3) and pa.sol or Mark.paSolve(sel))
	if not sol then
		logFile("pass assist", "press", "no solution", sel.name)
		return false
	end
	local live = { sel = sel, sol = sol, at = os.clock(), charge = sol.charge, dir = sol.dir, forced = forceSel ~= nil }
	Mark.paRay(live)
	pa.live = live
	pa.injecting = true
	local okB, r = pcall(Mark.passIn.HandleInputBegan, Controls.CreateInput("Lob"), false)
	pa.injecting = false
	if not okB or r == false then
		pa.live = nil
		logFile("pass assist", "press", "start refused", tostring(r))
		return false
	end
	logFile("pass assist", "press", tag or "user", sel.name, "status", sol.status, "charge", string.format("%.3f", sol.charge), "dist", string.format("%.1f", sol.D), "along", string.format("%.1f", sol.along), "lat", string.format("%.1f", sol.lat), "apex", string.format("%.1f", sol.apex - sol.origin.Y), "t", string.format("%.2f", sol.t))
	task.spawn(function()
		local due = live.at + sol.charge - 0.004
		while os.clock() < due and pa.live == live do
			local cam = Workspace.CurrentCamera
			local rr = live.sel and live.sel.root
			if cam and rr and not live.forced then
				local d = rr.Position + Vector3.new(0, 1.5, 0) - cam.CFrame.Position
				local ang = d.Magnitude > 1 and math.deg(math.acos(math.clamp(d.Unit:Dot(cam.CFrame.LookVector), -1, 1))) or 0
				if ang > 22 then
					pa.injecting = true
					pcall(Mark.passIn.CancelCharge)
					pa.injecting = false
					pa.live = nil
					logFile("pass assist", "cancel", "look away", string.format("%.0f", ang))
					return
				end
			end
			RunService.Heartbeat:Wait()
		end
		if pa.live == live then
			pa.injecting = true
			pcall(Mark.passIn.HandleInputEnded, Controls.CreateInput("Lob"))
			pa.injecting = false
		end
		task.delay(0.35, function()
			if pa.live == live then
				pa.live = nil
			end
		end)
	end)
	return true
end

-- Pass Assist ManualButton (UI keybind, unbound by default): no crosshair needed. Picks a teammate and fires the same legit
-- Lob (Pass.HandleInputBegan with the solved charge / yaw, real animation) through Mark.paPress.
-- Choice: the CLOSEST teammate that is not right next to us (PassManualNear) - a pass to a man standing beside us
-- is no pass; only when nobody else exists the near one gets it. Each candidate is solved with the real flight model
-- (Mark.paSolve); a lob that lands on an enemy / the keeper, hits the ceiling or cannot be placed ranks below the clean
-- ones, an enemy close to the receive point and a pass backwards from the enemy goal cost distance-equivalents.
Mark.paManual = function()
	local pa = Mark.pa
	local char = LocalPlayer.Character
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	if not (CFG.PassManual and char and root) or pa.live then
		return
	end
	if liveOwnerId() ~= LocalPlayer.UserId or MatchSettings.IsGoalkeeperCharacter(char) then
		return
	end
	if os.clock() - (pa.manualAt or 0) < 0.5 then
		return
	end
	local list = Mark.paList(root)
	if #list == 0 then
		logFile("pass manual", "no teammate")
		return
	end
	pa.manualAt = os.clock()
	local near = CFG.PassManualNear or 16
	local goal = enemyGoalPart()
	local toGoal = goal and unitOrNil(flat(goal.Position - root.Position))
	local foes = {}
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		local r = actor and actor ~= LocalPlayer and not sameTeam(actor) and ActorTargeting.GetActorRoot(actor)
		if r then
			foes[#foes + 1] = r.Position
		end
	end
	-- pre-rank by distance only (solving every teammate is a full flight simulation each), then solve the best few
	table.sort(list, function(a, b)
		local fa, fb = a.flatD >= near, b.flatD >= near
		if fa ~= fb then
			return fa
		end
		if fa then
			return a.flatD < b.flatD
		end
		return a.flatD > b.flatD
	end)
	local best = nil
	for i = 1, math.min(#list, 5) do
		local sel = list[i]
		local ok, sol = pcall(Mark.paSolve, sel)
		if ok and sol then
			local tier = (sel.flatD >= near) and 0 or 3
			if sol.status ~= "ok" then
				tier += (sol.status == "short" or sol.status == "long") and 1 or 2
			end
			local score = tier * 1000 + (sel.flatD >= near and sel.flatD or (near - sel.flatD))
			local pressure = 0
			for _, fp in foes do
				if flat(fp - sol.land).Magnitude < 8 then
					pressure += 1
				end
			end
			score += pressure * 30
			local dirU = unitOrNil(flat(sel.root.Position - root.Position))
			if toGoal and dirU and dirU:Dot(toGoal) < -0.3 then
				score += 20
			end
			if not best or score < best.score then
				best = { sel = sel, sol = sol, score = score, pressure = pressure }
			end
		end
	end
	if not best then
		logFile("pass manual", "no solution", #list)
		return
	end
	local okP = Mark.paPress(best.sel, best.sol, "manual")
	logFile("pass manual", okP and "sent" or "refused", best.sel.name, "dist", string.format("%.0f", best.sel.flatD), "status", best.sol.status, "pressure", best.pressure, "score", string.format("%.0f", best.score), "cand", #list)
end

Mark.paInstall = function()
	local passIn = Mark.passIn or require(Client.Gameplay.Actions.Pass)
	Mark.passIn = passIn
	if Mark.paInstalled then
		return
	end
	Mark.paInstalled = true
	local oldBegan, oldEnded = passIn.HandleInputBegan, passIn.HandleInputEnded
	passIn.HandleInputBegan = function(input, processed, ...)
		if CFG.PassAssist and not processed and not Mark.pa.injecting and not Mark.pa.live and typeof(input) == "Instance" and (Controls.IsInput("Pass", input) or Controls.IsInput("Lob", input)) then
			local ok, handled = pcall(Mark.paPress)
			if ok and handled then
				return true
			end
			if not ok then
				logFile("pass assist", "press-err", tostring(handled))
			end
		end
		return oldBegan(input, processed, ...)
	end
	passIn.HandleInputEnded = function(input, ...)
		-- the user's own release must not end our timed charge early
		if Mark.pa.live and typeof(input) == "Instance" and (Controls.IsInput("Pass", input) or Controls.IsInput("Lob", input)) then
			return true
		end
		return oldEnded(input, ...)
	end
end

Mark.paDraw = function(gy)
	local pa = Mark.pa
	if not (CFG.PassAssist and CFG.PassShow and Mark.pen and Mark.artPal) then
		return
	end
	local sel, sol = pa.sel, pa.sol
	if pa.live then
		sel, sol = pa.live.sel, pa.live.sol
	end
	local t = os.clock()
	local cam = Workspace.CurrentCamera
	-- chest-height, camera-facing, at least ~36 px. The old one was a 1.9-stud frame on the grass under the model
	-- (min 15 px) and only after a solved flight, so a teammate never read as a pass target.
	local marks = pa.marks
	if cam and marks and t - (pa.marksAt or 0) < 0.45 then
		local right, up = cam.CFrame.RightVector, cam.CFrame.UpVector
		for i = 1, #marks do
			local m = marks[i]
			if not (sel and sel.actor == m.actor) then
				Mark.cornerFrame(Mark.pen, m.root.Position, right, up, 0.5, Mark.artPal.lime, t, 0.15, 0, 0.4, 9, 12)
			end
		end
		if sel and sel.root then
			local kind = (sol and sol.ok) and "lime" or "limeWarn"
			Mark.cornerFrame(Mark.pen, sel.root.Position, right, up, 0.7, Mark.artPal[kind], t, 0.7, 0.05, 0.85, 13, 17)
		end
	end
	if not (sol and sol.pts and #sol.pts >= 2) or (not pa.live and t - (pa.solAt or 0) > 0.5) then
		return
	end
	local ballNow = Renderer.GetPosition()
	local shift = (ballNow and sol.origin) and (ballNow - sol.origin) or nil
	if shift and shift.Magnitude > 6 then
		shift = nil
	end
	Mark.trajArt(Mark.pen, sol.pts, sol.times, sol.land, sol.along3, gy, sol.ok and "lime" or "limeWarn", t, shift)
end

-- AutoShoot tab > Shot Types: drop candidates whose band the user excluded. The lob is keyed "chip". A flick strike needs
-- the bounce bands, so those stay legal there. An emptied pool simply means "no auto shot" (same path as no candidates).
Mark.shotFilter = function(pool)
	-- while a flick / volley is being aimed its own list decides (FlickBan), the normal list does not apply
	local flick = Mark.flickAim or Mark.aerial or Mark.flickStrike
	local ban = flick and CFG.FlickBan or CFG.ShotBan
	if type(ban) ~= "table" or next(ban) == nil then
		return pool
	end
	local out = {}
	for i = 1, #pool do
		local p = pool[i]
		local key = p.lob and "chip" or (p.band == "mid" and "high" or p.band)
		if not ban[key] then
			out[#out + 1] = p
		end
	end
	if #out == 0 and #pool > 0 and (not Mark.shotBanLog or os.clock() - Mark.shotBanLog > 2) then
		Mark.shotBanLog = os.clock()
		logFile("shoot ban", "every candidate excluded", #pool)
	end
	return out
end

-- Feint: our own charge is cancelled instead of released. Decided ONCE per charge when it starts:
-- Chance = roll FeintChance; Count = FeintCount feints in a row, then one real charge (the counter restarts).
-- The cancel happens at FeintAt, or at the moment YOU release if that comes first (the release is swallowed and becomes
-- the cancel: a timer alone lost the race against a human who lets go at the full charge, 0.35 s).
-- Never on FAKE / BOUNCE FAKE (shot name read from the solver); Smart Select: never once the enemy keeper has dived
-- (his dive is on cooldown: the feint has nothing left to bait and only burns the chance).
Mark.feintReset = function()
	Shoot.feintOn, Shoot.feinted, Shoot.feintDo = false, false, nil
end

-- true = the charge was cancelled as a feint; false = no feint (the caller lets the shot go)
Mark.feintNow = function(why)
	local nm = Shoot.shotName
	local skip = nil
	if (nm == "BOUNCE FAKE" and CFG.FeintSkipBounce ~= false) or ((nm == "FAKE" or nm == "FAKE CORNER") and CFG.FeintSkipFake ~= false) then
		skip = nm
	elseif CFG.FeintSmart ~= false and Mark.foeDiveLeft() > 0 then
		skip = "keeper dived"
	end
	if skip then
		Shoot.feintDo = false
		logFile("feint skip", skip, why)
		return false
	end
	local inst = Mark.chargeInst()
	local held = inst and inst.GetHeldSeconds and inst.GetHeldSeconds() or 0
	Shoot.feinted = true
	Mark.feintN = (Mark.feintN or 0) + 1
	ChargedKick.CancelCharge()
	setShootWhy("feint")
	logFile("feint", CFG.FeintMode or "Off", nm or "-", why, "held", string.format("%.2f", held), "n", Mark.feintN)
	return true
end

-- called from the ChargedKick.HandleInputEnded hook for the player's own release
Mark.feintRelease = function()
	if not Shoot.feintDo or Shoot.feinted or (CFG.FeintMode or "Off") == "Off" then
		return false
	end
	return Mark.feintNow("release")
end

Mark.feintTick = function()
	local mode = CFG.FeintMode or "Off"
	local now = os.clock()
	local gap = now - (Mark.feintTickAt or 0)
	Mark.feintTickAt = now
	local inst = mode ~= "Off" and Mark.chargeInst()
	if not (inst and inst.IsCharging()) then
		Mark.feintReset()
		return
	end
	if gap > 0.25 then
		Mark.feintReset() -- the tick did not run for a while (ball not ours): whatever is stored belongs to another charge
	end
	if not Shoot.feintOn then
		Shoot.feintOn = true
		if mode == "Chance" then
			Shoot.feintDo = math.random() < (CFG.FeintChance or 0.6)
		else
			if (Mark.feintN or 0) < (CFG.FeintCount or 1) then
				Shoot.feintDo = true
			else
				Mark.feintN = 0
				Shoot.feintDo = false
			end
		end
	end
	if not Shoot.feintDo or Shoot.feinted then
		return
	end
	local held = inst.GetHeldSeconds()
	if held and held >= (CFG.FeintAt or 0.32) then
		Mark.feintNow("timer")
	end
end

-- Why the FAKE family must not be used right now (nil = allowed).
Mark.fakeBan = function()
	if CFG.FakeAfterDiveBan ~= false then
		local left = Mark.foeDiveLeft()
		if left > 0 then
			return string.format("keeper dive cd %.1f", left)
		end
	end
	if CFG.FakeOnceThenShoot ~= false and Mark.bfOkAt then
		return "after bounce fake"
	end
	return nil
end

-- BounceFAKE bookkeeping, every step. Shot fired as BOUNCE FAKE (Start packet) -> if the ball is ours again within 7 s it
-- worked: no more fakes (the keeper has been moved / has dived: the next shot is a real one) until we lose the ball.
Mark.bfTrack = function()
	local now = os.clock()
	local own = liveOwnerId() == LocalPlayer.UserId
	local s = Mark.bfShot
	if s then
		if own and now - s > 0.4 then
			Mark.bfShot = nil
			Mark.bfOkAt = now
			Mark.bfLostAt = nil
			logFile("bounce fake", "ok - ball back after", string.format("%.2f", now - s), "-> real shot, fakes off until the ball is lost")
		elseif now - s > 7 or (not own and now - s > 0.6 and type(liveOwnerId()) == "number" and liveOwnerId() ~= 0 and liveOwnerId() ~= LocalPlayer.UserId) then
			Mark.bfShot = nil
			logFile("bounce fake", "failed", "owner", tostring(liveOwnerId()), "after", string.format("%.2f", now - s))
		end
	end
	if Mark.bfOkAt then
		if own then
			Mark.bfLostAt = nil
		else
			Mark.bfLostAt = Mark.bfLostAt or now
		end
		if (Mark.bfLostAt and now - Mark.bfLostAt > 1) or now - Mark.bfOkAt > 20 then
			Mark.bfOkAt, Mark.bfLostAt = nil, nil
		end
	end
end

-- BounceFAKE. A shot whose launch reads as a shot on goal (the unwalled flight lands in the mouth) but which, through
-- the game's own physics (Physics.NewState + GetStateAtTime with the charge boundary world: walls, floor, spin),
-- hits a wall, turns around and comes back to us. Candidates: aim points across the mouth, a few with curve; keep those
-- the sampler says are walled, simulate the real flight, require a horizontal reversal (the wall), no goal crossing
-- before it, and a return that we reach (run + receive box) clearly before any enemy field player.
-- The map walls are NOT in BarricadeStrikes.GetReplicatedBoundaryParts (that is only the placed barricades): they are
-- the box solids of the ball's boundary world (Physics.BuildBoundaryWorld -> world.Solids, IsGoalBoundary marks the goal
-- frame). flightBlocked() therefore never saw a map wall - BounceFAKE reported "walled 0" for every candidate.
Mark.worldBlocked = function(pts, world)
	local solids = world and world.Solids
	if type(solids) ~= "table" or not pts or #pts < 2 then
		return false
	end
	local pad = Vector3.new(1, 1, 1) * (Physics.BallRadius or 1)
	-- Mark.wallList: the VERTICAL solids only. The map's "walls" listed in the log include 129x1x180 slabs at y=32.4 (the
	-- ground) and y=81.4 (the ceiling): every flight touches those, which made "walled" meaningless in the first version.
	local list = Mark.wallListFor == solids and Mark.wallList
	if not list then
		list = {}
		for j = 1, #solids do
			local s = solids[j]
			if s and s.CFrame and s.HalfSize then
				local h = s.HalfSize
				local axis = (h.X <= h.Y and h.X <= h.Z) and s.CFrame.RightVector or ((h.Y <= h.Z) and s.CFrame.UpVector or s.CFrame.LookVector)
				if math.abs(axis.Y) < 0.7 then
					list[#list + 1] = s
				end
			end
		end
		Mark.wallList, Mark.wallListFor = list, solids
	end
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		for j = 1, #list do
			local s = list[j]
			if Physics.GetSegmentOrientedBoxEnterAlpha(a, b, s.CFrame, s.HalfSize + pad) then
				return true
			end
		end
	end
	return false
end

Mark.bounceFake = function(c)
	if not c.world then
		return nil, "noworld"
	end
	if Mark.bfWorld ~= c.world and (not Mark.bfWorldAt or os.clock() - Mark.bfWorldAt > 60) then
		Mark.bfWorld = c.world
		Mark.bfWorldAt = os.clock()
		local sol = c.world.Solids or {}
		local n, goalN = 0, 0
		local lines = {}
		for _, s in sol do
			if s.IsGoalBoundary then
				goalN += 1
			else
				n += 1
				if #lines < 40 and s.CFrame and s.HalfSize then
					lines[#lines + 1] = string.format("%s|%s", fmtV(s.CFrame.Position), fmtV(s.HalfSize * 2))
				end
			end
		end
		logFile("bounce world", "walls", n, "goalSolids", goalN, "ceil", tostring(c.world.CeilingY), "goal", fmtV(c.bottom), "face", fmtV(c.face))
		for _, l in lines do
			logFile("bounce wall", l)
		end
	end
	local cache = Mark.bfCache
	if cache and os.clock() - cache.at < 0.6 and (c.root.Position - cache.us).Magnitude < 0.6 and cache.force == c.force then
		return cache.pack, cache.why
	end
	local packR, whyR = Mark.bounceFakeRaw(c)
	Mark.bfCache = { at = os.clock(), us = c.root.Position, force = c.force, pack = packR, why = whyR }
	return packR, whyR
end

Mark.bounceFakeRaw = function(c)
	local Shoot = c.Shoot
	if flat(c.start - c.bottom).Magnitude > (CFG.BounceFakeRange or 110) then
		return nil, "far"
	end
	if not c.force and (Shoot.bounceRoll or 1) >= (CFG.BounceFakeChance or 0.08) then
		return nil, "roll"
	end
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local root = c.root
	local us = root.Position
	local runSp = (Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(root.Parent), false) or 24)
	local rcv = HitboxSettings.Receive
	local hiR = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5 + c.radius
	local foes = {}
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		local r = actor and actor ~= LocalPlayer and not sameTeam(actor) and not isGoalkeeper(actor) and ActorTargeting.GetActorRoot(actor)
		if r then
			foes[#foes + 1] = { p = r.Position, s = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(model), false) or 24 }
		end
	end
	local function depthOf(p)
		return (p - c.bottom):Dot(c.face)
	end
	local function sideOf(p)
		return flat(p - c.low):Dot(c.lateral)
	end
	-- Aim points on the wall around the goal, not in the mouth: just above the bar (the wall rises above the frame),
	-- and just outside the posts. {lateral fraction of the post, height above the goal floor}. To the keeper's read of the
	-- launch they are a high shot / a shot at the corner.
	local mh = c.mouthH
	local plan = {
		{ 0, mh + 1.5, nil }, { -0.5, mh + 1.5, nil }, { 0.5, mh + 1.5, nil }, { -0.9, mh + 1.5, nil }, { 0.9, mh + 1.5, nil },
		{ 0, mh + 4, nil }, { -0.5, mh + 4, nil }, { 0.5, mh + 4, nil }, { -0.9, mh + 4, nil }, { 0.9, mh + 4, nil },
		{ 0, mh + 8, nil }, { -0.6, mh + 8, nil }, { 0.6, mh + 8, nil },
		{ -1.12, 3, nil }, { 1.12, 3, nil }, { -1.12, 7, nil }, { 1.12, 7, nil },
		-- more wall points: between the posts and the bar, wide of the frame, high on the wall
		{ -0.25, mh + 1.5, nil }, { 0.25, mh + 1.5, nil }, { -0.75, mh + 1.5, nil }, { 0.75, mh + 1.5, nil },
		{ -0.25, mh + 4, nil }, { 0.25, mh + 4, nil }, { -0.75, mh + 6, nil }, { 0.75, mh + 6, nil },
		{ -1.3, 3, nil }, { 1.3, 3, nil }, { -1.3, 10, nil }, { 1.3, 10, nil }, { -1.12, 11, nil }, { 1.12, 11, nil },
		{ 0, mh + 12, nil }, { -0.4, mh + 12, nil }, { 0.4, mh + 12, nil },
	}
	-- curved variants: the bend alone can take the flight into a wall the straight line misses
	if CurvedKicks.IsEnabled() then
		-- { lateral fraction of the post, height above the bar (or an absolute 3 studs beside a post) }
		for _, e in { { 0, mh + 1.5 }, { -0.6, mh + 1.5 }, { 0.6, mh + 1.5 }, { 0, mh + 4 }, { -0.9, mh + 4 }, { 0.9, mh + 4 }, { -1.12, 3 }, { 1.12, 3 }, { -1.12, 8 }, { 1.12, 8 }, { 0, mh + 8 }, { -1.3, 5 }, { 1.3, 5 } } do
			plan[#plan + 1] = { e[1], e[2], 0.85 }
			plan[#plan + 1] = { e[1], e[2], -0.85 }
		end
	end
	local nil0 = c.fail and c.fail.cross or 0
	local velNil0 = c.fail and c.fail.vel or 0
	local saved = Shoot.simCap
	Shoot.simCap = (Shoot.sims or 0) + #plan
	local tried, walled, noRet, goalIn, foeWins = 0, 0, 0, 0, 0
	local best = nil
	local t0 = Workspace:GetServerTimeNow()
	for _, cand in plan do
		local point = c.bottom + c.up * (cand[2] + (CFG.BounceFakeHeight or 0)) + c.lateral * (cand[1] * c.post)
		local look = point - c.camPos
		if look.Magnitude < 1 then
			continue
		end
		local pack = c.packShot(look.Unit, cand[3], "fake", false)
		if not pack then
			continue
		end
		tried += 1
		if math.abs(pack.side or 99) > c.post + 1.6 or (pack.land - c.bottom):Dot(c.up) > mh + 14 + (CFG.BounceFakeHeight or 0) then
			continue
		end
		if not (pack.pts and (Mark.worldBlocked(pack.pts, c.world) or flightBlocked(pack.pts, c.goal))) then
			continue
		end
		walled += 1
		if walled > (CFG.BounceFakeMaxSim or 8) then
			break
		end
		Shoot.slice()
		local okS, st = pcall(Physics.NewState, pack.from, pack.vel, Physics.BallRadius, t0, pack.spin or Vector3.zero)
		if not okS or type(st) ~= "table" then
			continue
		end
		st.LastKickerUserId = LocalPlayer.UserId
		local v0f = unitOrNil(flat(pack.vel))
		local pts, times = { pack.from }, { 0 }
		local bounceT, crossedGoal = nil, false
		local cand2 = nil
		for i = 1, (CFG.BounceFakeSteps or 70) do
			local t = i * 0.06
			local okG, s = pcall(Physics.GetStateAtTime, st, t0 + t, c.world)
			local p = okG and s and s.Position
			if typeof(p) ~= "Vector3" then
				break
			end
			pts[#pts + 1] = p
			times[#times + 1] = t
			local v = s.Velocity
			if not bounceT then
				if depthOf(p) < c.radius and math.abs(sideOf(p)) < c.post + 1 and (p - c.bottom):Dot(c.up) < mh then
					crossedGoal = true
					break
				end
				if typeof(v) == "Vector3" and v0f then
					local vf = flat(v)
					if vf.Magnitude > 3 and vf.Unit:Dot(v0f) < 0.3 then
						bounceT = t
					end
				end
			elseif t > bounceT + 0.12 and typeof(v) == "Vector3" and v.Magnitude < 85 and p.Y - us.Y <= hiR then
				-- Back TO US: we may step up to 10 studs for it, no more (the first version let us "run" 60 studs after a
				-- ball that went somewhere else and called that a return).
				local slack = flat(p - us).Magnitude - math.min(runSp * 0.9 * math.max(t - 0.3, 0), CFG.BounceFakeRun or 14)
				local score = slack + t * 0.8
				if slack <= (CFG.BounceFakeSlack or 3.5) and (not cand2 or score < cand2.score) then
					cand2 = { slack = slack, score = score, t = t, p = p }
				end
			end
		end
		if crossedGoal then
			goalIn += 1
		elseif not bounceT or not cand2 then
			noRet += 1
		else
			local lost = false
			for _, f in foes do
				local fs = flat(cand2.p - f.p).Magnitude - f.s * 0.85 * math.max(cand2.t - 0.3, 0)
				if fs < cand2.slack - 0.5 then
					lost = true
					break
				end
			end
			if lost then
				foeWins += 1
			elseif not best or cand2.score < best.score then
				pack.bfake = true
				pack.inside = true
				pack.pts = pts
				pack.times = times
				pack.reach = 9
				pack.fromBall = false
				pack.aimPoint = point
				best = { pack = pack, slack = cand2.slack, score = cand2.score, t = cand2.t, bt = bounceT, p = cand2.p }
				if cand2.slack <= 0.8 then
					break
				end
			end
		end
	end
	Shoot.simCap = math.max(saved or 0, Shoot.sims or 0)
	local info = string.format("tried %d/%d walled %d noReturn %d goal %d foe %d nil cross %d vel %d", tried, #plan, walled, noRet, goalIn, foeWins, (c.fail and c.fail.cross or 0) - nil0, (c.fail and c.fail.vel or 0) - velNil0)
	if best then
		return best.pack, string.format("%s | wall t %.2f back at %.2f slack %.1f", info, best.bt, best.t, best.slack)
	end
	return nil, info
end

-- AutoTackle on a CHARGING carrier. The release is at most KickCore's full charge (0.4 s) after the charge starts; a slide
-- that lands later hits a ball that has already left (log: ~60% of the charge tackles). Returns
--   nil                      - not charging / guard off: normal behaviour
--   { ok = true }            - the slide lands before the expected release: go
--   { block = true, aim, mult, eta, X } - too late for him, but the slide box can be at the shot line when the ball
--                              passes (the user reports a slide knocks even a full-power ball away)
--   { skip = true, why }     - too late and no block geometry: do not slide
-- AutoBlock is already on his shot line (goal side of him, within a body width of the charge aim): the body is the
-- block, the slide-block from 25 studs only cancelled it (log: block start -> 1 s -> tackle sent "charge block").
Mark.onShotLine = function(root, solved, rec)
	if not CFG.AutoBlock or Mark.move.mode ~= "block" or not (Mark.blockHold and os.clock() - Mark.blockHold < 0.3) then
		return false
	end
	local dir = rec and typeof(rec.dir) == "Vector3" and unitOrNil(flat(rec.dir))
	local P = solved and solved.serverPos
	if not (dir and P) then
		return false
	end
	local rel = flat(root.Position - P)
	local along = rel:Dot(dir)
	local lat = math.abs(rel:Dot(Vector3.new(-dir.Z, 0, dir.X)))
	return along >= 2.5 and along <= (CFG.BlockRange or 40) and lat <= HitboxSettings.Receive.Size.X * 0.5 + 1.0
end

Mark.chargeTackle = function(root, croot, rec, solved)
	if not CFG.ChargeTackleGuard or not (rec and rec.live) or os.clock() - (rec.seen or 0) > 0.6 then
		return nil
	end
	local now = os.clock()
	-- a slide AT the charging carrier only close to him (far away it is a lunge into nothing); the slide-BLOCK on the
	-- predicted shot path below works from any distance
	local near = (solved.dist or 0) <= (CFG.ChargeTackleRange or 10)
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local remain = rec.at + (CFG.ChargeRelease or 0.34) - now
	local eta = solved.eta or C.HitboxDelaySeconds
	if near and eta + ping <= remain - 0.02 then
		return { ok = true }
	end
	if not CFG.ChargeSlideBlock then
		return { skip = true, why = "charge late" }
	end
	local dir = rec.dir
	local P = solved.serverPos
	local dirF = typeof(dir) == "Vector3" and unitOrNil(flat(dir))
	if not (dirF and P) then
		return { skip = true, why = "charge late" }
	end
	local origin = root.Position
	local mid = Mark.slideBox()
	local mHi = math.max(0.4, CFG.TackleSpeed)
	local mLo = math.min(mHi, CFG.TackleMinSpeed or 0.6)
	local vb = CFG.ChargeBallSpeed or 95
	local tRel = math.max(remain, 0)
	local cs = rec.uid and Mark.chargeShot(rec.uid) or nil
	if cs and cs.speed > 20 then
		vb = cs.speed
	end
	local best = nil
	local t = C.HitboxDelaySeconds
	while t <= C.HitboxDelaySeconds + C.HitboxSeconds + 1e-4 do
		-- the ball passes distance dX from the carrier at tb (server clock); our press reaches the server ping/2 later
		local tb = t + ping * 0.5
		local tAfter = tb - tRel - ping * 0.5
		local dX = tAfter * vb
		-- the real predicted flight (replicated charge) when we have it: where the ball IS tAfter seconds after the release
		local pathX = cs and Mark.chargeAt(cs, tAfter)
		if pathX then
			dX = flat(pathX - P).Magnitude
		end
		if dX >= 5 and dX <= 55 and (not cs or pathX) then
			local X = pathX and Vector3.new(pathX.X, origin.Y, pathX.Z) or (P + dirF * dX)
			local to = flat(X - origin)
			local T = Mark.dumpTravel(t)
			local m = (to.Magnitude - mid) / math.max(T, 1)
			if m >= mLo and m <= mHi then
				local score = math.abs(m - (mLo + mHi) * 0.5)
				if not best or score < best.score then
					best = { score = score, aim = to.Unit, mult = m, eta = t, X = X, dX = dX }
				end
			end
		end
		t += 0.02
	end
	if best then
		best.block = true
		return best
	end
	return { skip = true, why = "charge late" }
end

-- ManualTackle target: the enemy carrier inside CFG.ManualRadius. Returns aim, speed multiplier, {char, root}, how.
-- how = "solve" (a real intercept inside the 0.6..TackleSpeed multiplier window) or "best" (no window: the carrier is
-- too close/too far for the solver - slide at where he will be mid hitbox, multiplier clamped to the legal range).
Mark.manualAim = function(character, root)
	local oid = liveOwnerId()
	if type(oid) ~= "number" or oid == 0 or oid == LocalPlayer.UserId then
		return nil
	end
	local player, croot = enemyCarrier(oid)
	if not player or typeof(croot) ~= "Instance" then
		return nil
	end
	local cch = Actors.GetCharacter(player)
	if flat(croot.Position - root.Position).Magnitude > (CFG.ManualRadius or 26) then
		return nil
	end
	local okS, solved = pcall(solveIntercept, root, croot, cch, tackleTuning())
	if okS and solved and solved.aim and solved.mult then
		return solved.aim, solved.mult, { char = cch, root = croot }, "solve"
	end
	local pos, rawVel = Mark.carrierPose(croot, cch)
	local t = C.HitboxDelaySeconds + C.HitboxSeconds * 0.35
	local to = flat(pos + rawVel * t - root.Position)
	local aim = unitOrNil(to)
	if not aim then
		return nil
	end
	local mHi = math.max(0.4, CFG.TackleSpeed)
	local mLo = math.min(mHi, CFG.TackleMinSpeed or 0.6)
	local mult = math.clamp((to.Magnitude - Mark.slideBox()) / math.max(Mark.dumpTravel(t), 1), mLo, mHi)
	return aim, mult, { char = cch, root = croot }, "best"
end

-- Who counts as "ours": 3 = party member (RankedState.Get().Party.MemberUserIds), 2 = club mate (ClubsState.GetClub()),
-- 1 = Roblox friend (Player:IsFriendsWith, fetched off-thread). Cached 4 s.
Mark.friendTier = function(actor)
	local uid = actor and actor.UserId
	if type(uid) ~= "number" then
		return 0
	end
	local c = Mark.friendCache
	if not c then
		c = {}
		Mark.friendCache = c
	end
	local now = os.clock()
	local e = c[uid]
	if e and now - e.t < 4 then
		return e.tier
	end
	local tier = 0
	pcall(function()
		Mark.rankedMod = Mark.rankedMod or require(Client.Interface.RankedState)
		local st = Mark.rankedMod.Get()
		local party = st and st.Party
		if party and type(party.MemberUserIds) == "table" and table.find(party.MemberUserIds, uid) then
			tier = 3
		end
	end)
	if tier == 0 then
		pcall(function()
			Mark.clubsMod = Mark.clubsMod or require(Client.Interface.ClubsState)
			local club = Mark.clubsMod.GetClub()
			local budget = 600
			local function scan(t, depth)
				if type(t) ~= "table" or depth > 3 or budget <= 0 then
					return false
				end
				for k, v in t do
					budget -= 1
					if (type(v) == "number" and v == uid and (type(k) ~= "string" or k:find("User") or k:find("Member") or k:find("Id"))) or (type(k) == "number" and k == uid) or (type(k) == "string" and k == tostring(uid)) then
						return true
					end
					if type(v) == "table" and scan(v, depth + 1) then
						return true
					end
				end
				return false
			end
			if club and scan(club, 0) then
				tier = 2
			end
		end)
	end
	Mark.rbxFriends = Mark.rbxFriends or {}
	if tier == 0 then
		local f = Mark.rbxFriends[uid]
		if f == nil then
			Mark.rbxFriends[uid] = false
			task.spawn(function()
				local ok, res = pcall(function()
					return LocalPlayer:IsFriendsWith(uid)
				end)
				Mark.rbxFriends[uid] = ok and res == true
			end)
		elseif f then
			tier = 1
		end
	end
	c[uid] = { t = now, tier = tier }
	return tier
end

-- FAKE shot. A normal shot at goal whose flight passes through a teammate's Receive box: the preview (and the keeper
-- reading the replicated launch) says "goal", the ball is received by the mate (Receiving.Resolve: a teammate's Shot
-- is a clean Receive, TeammateKickIgnoresSpeedThreshold) and the keeper has already dived. Candidates: mates in front
-- of their goal, slow, with no enemy near them or on the pass. The aim is iterated (<= 4 sims) until the flight
-- crosses the mate's Receive box AND the same flight still ends inside the mouth. Returns pack, info.
Mark.fakeShot = function(c)
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local Shoot = c.Shoot
	local rcv = HitboxSettings.Receive
	local lo = rcv.CFrameOffset.Y - rcv.Size.Y * 0.5
	local hi = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5
	local bodyR = rcv.Size.X * 0.5
	local function depthOf(p)
		return (p - c.bottom):Dot(c.face)
	end
	local function sideOf(p)
		return flat(p - c.low):Dot(c.lateral)
	end
	local Ds = depthOf(c.start)
	local sS = sideOf(c.start)
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local mates, foes = {}, {}
	local dg = { team = 0, down = 0, fast = 0, depth = 0, lat = 0, foe = 0, dMin = 999, dMax = -999 }
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		local r = actor and actor ~= LocalPlayer and ActorTargeting.GetActorRoot(actor)
		if r and not isGoalkeeper(actor) then
			if sameTeam(actor) then
				dg.team += 1
				if Mark.mateDown(actor, model) then
					dg.down += 1
				else
					-- Moving mates are fine: his pose is projected to the moment the ball gets there (first guess from the
					-- distance, refined from the simulated flight time below). Only a sprint across the line is too uncertain.
					local v = flat(r.AssemblyLinearVelocity)
					if v.Magnitude > 30 then
						dg.fast += 1
					else
						local tFly = flat(r.Position - c.start).Magnitude / 95
						local M = r.Position + v * (ping + tFly)
						local Dm = depthOf(M)
						local sM = sideOf(M)
						dg.dMin, dg.dMax = math.min(dg.dMin, Dm), math.max(dg.dMax, Dm)
						local slop0 = CFG.FakeSlop or 3.5
						if not (Dm > 6 - slop0 and Dm < Ds - 2 and Dm <= (CFG.FakeMaxDepth or 100) + slop0 and flat(M - c.start).Magnitude >= 6) then
							dg.depth += 1
						else
							local f = Ds / (Ds - Dm)
							local sg = sS + (sM - sS) * f
							-- straight line may miss the mouth: curve (FAKE CORNER) can still bend through him into the post
							if math.abs(sg) > c.post * (CFG.FakeLatMul or 1.5) + slop0 then
								dg.lat += 1
							else
								mates[#mates + 1] = { actor = actor, root = r, v = v, spd = v.Magnitude, M = M, Dm = Dm, sM = sM, sg = sg, f = f, off = math.abs(sg) > c.post - 1.2, tier = Mark.friendTier(actor), name = actorName(actor) }
							end
						end
					end
				end
			else
				foes[#foes + 1] = { p = r.Position, v = flat(r.AssemblyLinearVelocity), s = Mark.mover and Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(model), false) or 26, y = r.Position.Y }
			end
		end
	end
	-- an enemy next to the mate takes the ball (Ownership: whoever's Receive box it enters first)
	for i = #mates, 1, -1 do
		for _, f in foes do
			if flat(f.p - mates[i].M).Magnitude < (CFG.FakeFoeRadius or 7) then
				dg.foe += 1
				table.remove(mates, i)
				break
			end
		end
	end
	if #mates == 0 then
		return nil, string.format("no mate (team %d down %d fast %d depth %d lat %d foe %d D %.0f..%.0f of Ds %.0f)", dg.team, dg.down, dg.fast, dg.depth, dg.lat, dg.foe, dg.dMin, dg.dMax, Ds)
	end
	local prio = CFG.PrioritizeFriends ~= false
	table.sort(mates, function(a, b)
		if prio and a.tier ~= b.tier then
			return a.tier > b.tier
		end
		return a.Dm < b.Dm
	end)
	local chance = CFG.FakeChance or 0.12
	if prio and mates[1].tier > 0 then
		chance = math.min(chance * 2.2, 0.35)
	end
	if not c.force and (Shoot.fakeRoll or 1) >= chance then
		return nil, string.format("roll %.2f >= %.2f", Shoot.fakeRoll or 1, chance)
	end
	local slop = CFG.FakeSlop or 3.5
	local latLim = math.max(bodyR - 0.5, 1.1) + slop * 0.4
	local saved = Shoot.simCap
	Shoot.simCap = (Shoot.sims or 0) + 40
	local result, info = nil, "none"
	local function crossOf(pack, mate)
		if not (pack and pack.inside and pack.pts) then
			return nil
		end
		local Q, tQ = nil, nil
		for i = 2, #pack.pts do
			local d0, d1 = depthOf(pack.pts[i - 1]), depthOf(pack.pts[i])
			if d0 >= mate.Dm and d1 <= mate.Dm and d0 ~= d1 then
				local a = (d0 - mate.Dm) / (d0 - d1)
				Q = pack.pts[i - 1]:Lerp(pack.pts[i], a)
				tQ = (pack.times[i - 1] or 0) + ((pack.times[i] or 0) - (pack.times[i - 1] or 0)) * a
				break
			end
		end
		if not Q then
			return nil
		end
		local side = pack.side or 99
		local landH = (pack.land - c.bottom):Dot(c.up)
		return {
			pack = pack, Q = Q, tQ = tQ,
			latErr = mate.sM - sideOf(Q),
			yRel = Q.Y - mate.root.Position.Y,
			inMouth = math.abs(side) <= c.post - 0.35 and landH >= -0.3 and landH <= c.mouthH - c.radius - 0.9,
			corner = math.abs(side) >= c.post * 0.5,
		}
	end
	local function aimAt(mate, aimSide, aimH, curve)
		local point = c.bottom + c.up * math.clamp(aimH, 0.4, c.mouthH - 2.2) + c.lateral * aimSide
		local look = point - c.camPos
		if look.Magnitude < 1 then
			return nil
		end
		local pack = c.packShot(look.Unit, curve, "fake", false)
		local hit = crossOf(pack, mate)
		if not hit then
			return nil
		end
		hit.point, hit.curve, hit.aimSide, hit.aimH = point, curve, aimSide, aimH
		hit.latOk = math.abs(hit.latErr) <= latLim
		hit.yOk = hit.yRel >= lo - slop * 0.3 and hit.yRel <= hi + slop * 0.2
		return hit
	end
	local function foeBlocks(hit, mate)
		for _, f in foes do
			for i = 2, #hit.pack.pts do
				local t = hit.pack.times[i] or 0
				if t > hit.tQ then
					break
				end
				local q = hit.pack.pts[i]
				local need = math.max(flat(q - (f.p + f.v * math.min(t, 0.3))).Magnitude - (bodyR + c.radius), 0)
				if q.Y - f.y <= hi + c.radius + 1.5 and need <= f.s * 0.85 * math.max(t - 0.3, 0) then
					return true
				end
			end
		end
		return false
	end
	local function take(hit, mate, corner)
		if foeBlocks(hit, mate) then
			info = "foe on pass"
			return false
		end
		local pack = hit.pack
		pack.fake = true
		pack.fakeCorner = (CFG.FakeCorner ~= false and hit.corner) or nil
		pack.reach = 9
		pack.mate = mate
		pack.aimPoint = hit.point
		pack.fromBall = false
		result = pack
		info = string.format("%s %s tier %d d %.0f lat %.1f y %.1f curve %s land %.1f/%.1f", mate.name, hit.corner and "corner" or "line", mate.tier, mate.Dm, hit.latErr, hit.yRel, hit.curve and string.format("%.2f", hit.curve) or "-", pack.side or 0, hit.aimH or 0)
		return true
	end
	-- AIM AT THE MATE, then make the flight a goal. The flight has to pass through his body (a point inside his Receive
	-- box at his depth) AND finish inside the mouth. Unknowns: the aim point on the goal plane (side, height) - two
	-- numbers - against two requirements (lateral and vertical position at his depth), solved by damped Newton steps
	-- on the real flight sim. The free choices are then what makes it not a template, all taken from the shot roll so
	-- the picture does not flicker frame to frame: where in his body the ball goes (height, a little sideways) and
	-- which curve (none / +-0.45 / +-0.85) - each curve is another arc through the SAME mate with a different landing
	-- in the mouth. The corner is not a goal, it is just where a bent arc sometimes ends (the name follows the landing).
	local function frac(x)
		return x - math.floor(x)
	end
	local r0 = Shoot.fakeRoll or 0.5
	local u1, u2, u3 = frac(r0 * 7.31 + 0.17), frac(r0 * 13.7 + 0.43), frac(r0 * 29.3 + 0.71)
	local curves = { false }
	if CurvedKicks.IsEnabled() and CFG.FakeCurve ~= false then
		for _, v in { 0.85, -0.85, 0.45, -0.45 } do
			curves[#curves + 1] = v
		end
		-- the first curve tried follows the roll, so the cheap early exit does not always favour the same side
		if u2 > 0.5 then
			curves[2], curves[3] = curves[3], curves[2]
			curves[4], curves[5] = curves[5], curves[4]
		end
	end
	local yLoT, yHiT = lo + 1.0, hi - 0.8
	local function solveCurve(mate, curve, yT, latWant)
		local aSide = mate.sg + latWant * mate.f
		local aH = 2.4
		local bestH, bestS = nil, math.huge
		for it = 1, 3 do
			local h = aimAt(mate, aSide, aH, curve or nil)
			if not h then
				if it == 1 then
					aSide = math.clamp(aSide, -(c.post - 1.5), c.post - 1.5)
					h = aimAt(mate, aSide, aH, curve or nil)
				end
				if not h then
					break
				end
			end
			local eLat = h.latErr + latWant
			local eY = yT - h.yRel
			local s = math.abs(eLat) + 0.5 * math.abs(eY)
			if s < bestS then
				bestH, bestS = h, s
			end
			if math.abs(eLat) <= 0.6 and math.abs(eY) <= 0.9 then
				break
			end
			aSide += eLat * mate.f * 0.85
			aH = math.clamp(aH + eY * mate.f * 0.85, 0.5, c.mouthH - 2.2)
		end
		return bestH
	end
	local pool, tried, blocked = {}, 0, 0
	for mi = 1, math.min(#mates, 2) do
		local mate = mates[mi]
		-- a different spot of his body for each mate (the roll is reused with an offset)
		local yT = yLoT + (yHiT - yLoT) * frac(u1 + mi * 0.37)
		local latWant = (frac(u2 + mi * 0.21) - 0.5) * bodyR * 0.7
		for _, curve in curves do
			if #pool >= 4 then
				break
			end
			tried += 1
			local h = solveCurve(mate, curve, yT, latWant)
			if h and h.inMouth and h.latOk and h.yOk then
				if foeBlocks(h, mate) then
					blocked += 1
				else
					local k = h.curve and math.abs(h.curve) or 0
					pool[#pool + 1] = { hit = h, mate = mate, w = k == 0 and 1.0 or (k < 0.6 and 0.9 or 0.7) }
				end
			end
		end
		if #pool > 0 then
			break
		end
	end
	if #pool > 0 then
		local total = 0
		for _, e in pool do
			total += e.w
		end
		local x, pick = u3 * total, pool[1]
		for _, e in pool do
			x -= e.w
			if x <= 0 then
				pick = e
				break
			end
		end
		take(pick.hit, pick.mate, pick.hit.corner)
		info = info .. string.format(" pool %d/%d", #pool, tried)
	else
		info = blocked > 0 and "foe on pass" or string.format("miss (%d solves)", tried)
	end
	Shoot.simCap = math.max(saved or 0, Shoot.sims or 0)
	return result, info
end

-- A teammate who is stunned, ragdolled or frozen cannot contest anything: CompetitorCheck must not yield to him.
-- Stun.IsCharacterStunned(model) / Ragdoll.IsActorRagdolled(actor, model) / FreezeIce.IsCharacterFrozen(model) read the
-- replicated server-time deadlines (the same ones the game's own press checks use). TTL 0.1 s per model.
-- Returns down, secondsLeft (0 when unknown).
Mark.mateDown = function(actor, model)
	if not model then
		return false, 0
	end
	local c = Mark.downCache
	if not c then
		c = setmetatable({}, { __mode = "k" })
		Mark.downCache = c
	end
	local now = os.clock()
	local e = c[model]
	if e and now - e.t < 0.1 then
		return e.down, e.left
	end
	local down, left = false, 0
	local okS, stunned = pcall(function()
		Mark.stunMod = Mark.stunMod or require(Modules.Characters.Stun)
		return Mark.stunMod.IsCharacterStunned(model)
	end)
	if okS and stunned then
		down, left = true, 0.5
	end
	local okR, rag = pcall(function()
		return Ragdoll.IsActorRagdolled(actor, model)
	end)
	if okR and rag then
		down = true
		local okU, untilT = pcall(Ragdoll.GetRagdolledUntil, actor)
		if okU and type(untilT) == "number" then
			left = math.max(left, untilT - Workspace:GetServerTimeNow())
		else
			left = math.max(left, 0.5)
		end
	end
	local okF, frozen = pcall(function()
		Mark.iceMod = Mark.iceMod or require(Modules.Characters.FreezeIce)
		return Mark.iceMod.IsCharacterFrozen(model)
	end)
	if okF and frozen then
		down, left = true, math.max(left, 1)
	end
	c[model] = { t = now, down = down, left = left }
	return down, left
end

-- A field teammate (not the keeper, not stunned / ragdolled / frozen) within `radius` of `pos`, or nil.
Mark.mateNear = function(pos, radius)
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and sameTeam(actor) and not isGoalkeeper(actor) and not Mark.mateDown(actor, model) then
			local ar = ActorTargeting.GetActorRoot(actor)
			if ar and flat(ar.Position - pos).Magnitude <= radius then
				return actor
			end
		end
	end
	return nil
end

Mark.tackleGate = function(character, root, player, ch, solved)
	if not CFG.AutoBlock then
		return true, "noblock"
	end
	local now = os.clock()
	local eta = solved.eta or C.HitboxDelaySeconds
	if Mark.chargeLive and Mark.chargeUntil and now < Mark.chargeUntil and Mark.chargeId == liveOwnerId() then
		return true, "charge"
	end
	local key = (typeof(player) == "Instance" and player:IsA("Player") and player.UserId) or nil
	local rec = (ch and dribbleSeen[ch]) or (key and dribbleSeen[key])
	if rec and rec.cdUntil and now > (rec.untilT or 0) and now + eta + 0.15 < rec.cdUntil and not (ch and Dodge.IsDribbling(ch)) then
		return true, "naked"
	end
	local g = Mark.defendGoal()
	local P = solved.serverPos
	if not (g and P) then
		return true, "nogoal"
	end
	local u = unitOrNil(flat(g.Position - P))
	local rel = flat(root.Position - P)
	local along = u and rel:Dot(u) or 0
	local holding = along > 0 and rel.Magnitude <= Mark.kickReach() + 1.5
	-- The old gate waited for AutoBlock / AutoKick ("block" / "hold") for EVERY carrier farther than TackleGoalZone from our goal
	-- - the tackle did nothing even when no kick could ever fire (log: tackle held right after our own kick). A tackle is held
	-- only when the kick really is about to go: AutoKick on, off cooldown, not already charging, he is inside the kick reach
	-- and not running away from us faster than a charging body can follow.
	if CFG.TackleGateStrict ~= true then
		local d = rel.Magnitude
		local kickLive = CFG.AutoKick ~= false and holding and not Mark.ak and now - (Mark.akAt or 0) >= (CFG.AutoKickCooldown or 0.5)
		if kickLive then
			local vAway = solved.spd and (solved.spd * 0.6) or 0
			kickLive = d <= Mark.kickReach() + 0.5 and vAway <= (CFG.AutoKickFlee or 9)
		end
		if not kickLive then
			return true, "free"
		end
		return false, "hold"
	end
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local mySpd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false)
	if type(mySpd) ~= "number" then
		mySpd = 16
	end
	if along < -1 and rel.Magnitude > Mark.kickReach() + 2 and (solved.spd or 0) >= mySpd * 0.85 then
		return true, "escape"
	end
	if not holding and flat(g.Position - P).Magnitude <= (CFG.TackleGoalZone or 40) then
		return true, "goal"
	end
	return false, holding and "hold" or "block"
end

Mark.ballStop = function(why)
	if Mark.move.mode == "ball" then
		Mark.ballStopWhy = why
		Mark.moveStop("ball")
	end
end

-- Ball path from the renderer's authoritative movement state through Physics.GetStateAtTime (rolling damping,
-- bounces, walls). Dense 0.05 s for the first 1.2 s (slide/jump/volley windows), then 0.1 s until the state says the
-- ball is at rest (Mode Resting / speed under Physics StopSpeed-ish), capped at 8 s. No fixed "2 s ahead" point.
Mark.ballPath = function(root)
	local pos = Renderer.GetTargetPosition(nil, root.Position) or Renderer.GetMainMatchPosition()
	if typeof(pos) ~= "Vector3" then
		return nil
	end
	local samples, ts = { pos }, { 0 }
	local state, world
	if Mark.ballSrcId then
		state, world = Renderer.GetMovementStateById(Mark.ballSrcId)
		if state and typeof(state.Position) == "Vector3" then
			pos = state.Position
			samples[1] = pos
		end
	else
		state, world = Renderer.GetMovementState()
	end
	local memo = Mark.ballMemo
	if state and memo and memo.state == state and os.clock() - memo.at < 0.04 then
		-- callers only read the arrays: hand out the memo itself (the old copy of ~90 entries ran per caller per frame)
		return pos, memo.vel, memo.samples, memo.ts, true, memo.rest
	end
	local vel = nil
	local rest = false
	if state then
		local now = CharacterMotionSmoothing.GetSmoothedServerTime()
		local s0 = Physics.GetStateAtTime(state, now, world)
		vel = s0 and s0.Velocity
		local t = 0
		while t < 8 do
			t += (t < 1.2 - 1e-6) and 0.05 or 0.1
			local s = Physics.GetStateAtTime(state, now + t, world)
			local p = s and s.Position
			if typeof(p) ~= "Vector3" then
				break
			end
			samples[#samples + 1] = p
			ts[#ts + 1] = t
			local v = s.Velocity
			if s.Mode == "Resting" or (typeof(v) == "Vector3" and v.Magnitude < 0.5) then
				rest = true
				break
			end
		end
	end
	if typeof(vel) ~= "Vector3" then
		vel = Renderer.GetTargetVelocity(nil, root.Position)
	end
	vel = typeof(vel) == "Vector3" and vel or Vector3.zero
	Mark.ballMemo = state and { state = state, at = os.clock(), samples = samples, ts = ts, vel = vel, rest = rest } or nil
	return pos, vel, samples, ts, state ~= nil, rest
end

-- Jump rise time to lift the root by r studs: vy0 = sqrt(2 g H) (CharacterControllers JumpHeight), ballistic.
Mark.riseT = function(r)
	local g = Workspace.Gravity
	if type(g) ~= "number" or g < 10 then
		g = 196.2
	end
	local H = Mark.jumpH or 7.2
	r = math.clamp(r, 0, H)
	local v0 = math.sqrt(2 * g * H)
	return (v0 - math.sqrt(math.max(v0 * v0 - 2 * g * r, 0))) / g
end

-- Volley: press Kick only when the game's own VolleyOpportunity.GetEvaluation(char) is non-nil (Shoot.HandleInputBegan
-- then claims with GetClaim and the arrival time; DelayRelease waits for arrival). Release with the same input
-- object (ChargedKick.IsChargeInput compares identity). Rising in a jump lifts the miss-angle gate (Evaluate v161).
-- Volley only when it is worth losing a clean reception: an opponent can reach the contact point about as soon
-- as we can (threat), or we are in shooting range of their goal. A free grounded ball is received, not struck.
Mark.volleyAimAt = function(from)
	local goal = enemyGoalPart()
	if not goal then
		return nil
	end
	local lb, lt, rb, rt = goalMouthCorners(goal)
	if not (lb and lt and rb and rt) then
		return unitOrNil(goal.Position - from)
	end
	local bottom = (lb + rb) * 0.5
	local rise = (lt + rt) * 0.5 - bottom
	local up = rise.Magnitude > 0.4 and rise.Unit or Vector3.yAxis
	local lateral = unitOrNil(flat(rt - lt)) or Vector3.xAxis
	local half = flat(rt - lt).Magnitude * 0.5 - Physics.BallRadius
	local keeper = keeperSide(bottom + up * 2, lateral, false)
	local side = (keeper >= 0) and -1 or 1
	local target = bottom + up * math.min(rise.Magnitude * 0.35, 4) + lateral * (side * half * 0.7)
	return unitOrNil(target - from), target
end

Mark.volleyPlan = function(root, ev)
	local _, _, samples, ts = Mark.ballPath(root)
	local meet = nil
	if samples then
		local ta = ev.ApproachSeconds or 0
		for i = 1, #samples do
			if ts[i] >= ta then
				meet = samples[i]
				break
			end
		end
		meet = meet or samples[#samples]
	end
	meet = meet or root.Position
	local ourD = flat(meet - root.Position).Magnitude
	local threat, threatD = false, math.huge
	-- a teammate's pass is ours to receive: only an opponent who actually gets there first makes it a volley
	local pass = Mark.allyKickUntil and os.clock() < Mark.allyKickUntil
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) then
			local r = ActorTargeting.GetActorRoot(actor)
			if r then
				local d = flat(r.Position - meet).Magnitude
				threatD = math.min(threatD, d)
				if (pass and d < ourD + 1) or (not pass and d <= math.max(10, ourD + 6)) then
					threat = true
				end
			end
		end
	end
	local goal = enemyGoalPart()
	local goalD = goal and flat(goal.Position - meet).Magnitude or math.huge
	-- shooting range = AutoShoot's range; whether a shot really exists is decided by AutoShoot in tickVolley
	local near = goalD <= (CFG.ShootMaxDist or 160)
	if not threat and not near then
		return nil, string.format("free goalD %.0f threatD %.0f", goalD, threatD)
	end
	if pass and not threat then
		return nil, "pass"
	end
	-- only a ball we could NOT simply receive: airborne and above the grounded Receive hitbox (jump height). A
	-- grounded / low ball is a plain reception; striking it just threw our own ball away (log: volley press ...
	-- grounded true).
	-- grounded ball: a plain reception unless we are in shooting range (then the volley IS the shot). Airborne ball
	-- at any height: volley / bicycle (the game upgrades to bicycle itself when CanBicycleKick). The old "only above
	-- the Receive box" rule killed every waist-high volley and with it the auto bicycle.
	-- Back to the v23 rule (v29 loosened it and the script started giving the ball away again): NEVER on a grounded
	-- ball, and never on a ball we can simply receive (airborne but inside the Receive box height). Only a ball above
	-- the Receive box is a volley / bicycle: jump height, rising, game upgrades it itself.
	do
		local rcv = HitboxSettings.Receive
		local top = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5 + (Physics.BallRadius or 1)
		if ev.BallGrounded then
			return nil, string.format("grounded goalD %.0f", goalD)
		end
		if meet.Y - root.Position.Y <= top then
			return nil, string.format("low goalD %.0f", goalD)
		end
	end
	local aim = Mark.volleyAimAt(meet)
	if not aim then
		return nil, "no goal"
	end
	return { aim = aim, threat = threat, near = near, goalD = goalD, threatD = threatD, meet = meet }
end

-- Pending release of OUR volley press. It lived inside tickVolley, which stepLogic skips on several paths (keeper
-- branch, early returns): the release never came and the charge sat at full ("charge stuck ... ourVolley true").
-- Runs first thing every Heartbeat now; a press older than 0.6 s is released / cancelled unconditionally.
-- AutoKick (rewritten). Legit: the game's own charge (ChargedKick.HandleInputBegan with a real Kick input, the game's
-- own KickChargeStarted/Updated packets, release through HandleInputEnded with the SAME input object), never a raw
-- server command. Pressed only inside the AutoBlock / CounterJump logic, only when the kick box can actually reach the
-- target, and released by the box, not by a timer:
--   * KickCore: MinimumChargeSeconds 0.2 (earliest release), MaximumChargeSeconds 0.4 (ChargedKick.StartCharge arms
--     task.delay(max, ReleaseFullCharge): the game fires a held charge itself at 0.4, so a charge we cannot land is
--     cancelled before that, never left to fire), GetFullChargeSeconds = max - 0.05.
--   * The hit is resolved at release with HitboxSettings.Kick (6x7x7, CFrameOffset Z -1.5) laid along the FLAT aim on
--     AimFacing.GetAimedRoot (the same boxes kickThreat uses against us). Mark.akEval predicts our pose (root + v * rr)
--     and his server pose (displayed + v * (display delay + ping/2 + rr), ballistic Y when he is in the air) for a
--     release rr seconds from now, aims at that point and tests his HRP (and 4 points 0.6 around it: "solid").
--   * Wait for the full charge while he stays in the box (more power), release the frame before he would leave it
--     or at the full charge; urgent (air duel) = release at the first legal moment.
--   * The aim ray is replaced while the charge runs (Mark.volleyAim, the Reticle override that already exists).
-- Body knock-back of a kick is server-side (the dump only has KickPowerups.PoweredUpBodyKnockbackMultiplier): the
-- result is logged ("autokick release ... / end") to calibrate.
Mark.akCtx = function(root, model, r)
	local character = LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local hisHum = model:FindFirstChildOfClass("Humanoid")
	local pos, vel, worldVel = Mark.carrierPose(r, model)
	local g = Workspace.Gravity
	if type(g) ~= "number" or g < 10 then
		g = 196.2
	end
	return {
		root = root, ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25),
		pos = pos, vel = vel, vy = (typeof(worldVel) == "Vector3") and worldVel.Y or 0,
		dly = math.clamp(CharacterMotion.GetDisplayDelaySeconds(model) or 0, 0, 0.25),
		hisAir = hisHum ~= nil and not CharacterControllers.IsLanded(model, hisHum),
		usAir = hum ~= nil and not CharacterControllers.IsLanded(character, hum),
		vUs = flat(root.AssemblyLinearVelocity), vyUs = root.AssemblyLinearVelocity.Y, g = g,
	}
end

-- while the Kick charges we walk at ActionMovement.GetChargingWalkSpeed (log: ws 27 -> 8): the box moves with THAT
Mark.akClampUs = function(ctx, character)
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local okW, cw = pcall(Mark.mover.GetChargingWalkSpeed, Mark.mover.GetBaseWalkSpeed(character), false)
	if okW and type(cw) == "number" and ctx.vUs.Magnitude > cw then
		ctx.vUs = ctx.vUs.Unit * cw
	end
	return ctx
end

Mark.akEval = function(ctx, rr, pad)
	local t = ctx.dly + ctx.ping * 0.5 + rr
	local tgt = ctx.pos + ctx.vel * t
	if ctx.hisAir then
		tgt = Vector3.new(tgt.X, ctx.pos.Y + ctx.vy * t - 0.5 * ctx.g * t * t, tgt.Z)
	end
	local us = ctx.root.Position + ctx.vUs * rr
	if ctx.usAir then
		us = Vector3.new(us.X, ctx.root.Position.Y + ctx.vyUs * rr - 0.5 * ctx.g * rr * rr, us.Z)
	end
	local aim = unitOrNil(flat(tgt - us)) or unitOrNil(flat(ctx.root.CFrame.LookVector))
	if not aim then
		return false, false, nil, tgt
	end
	local box = HitboxSettings.Kick
	local aimed = AimFacing.GetAimedRoot({ Position = us }, aim)
	local inside = HitboxSettings.ContainsPoint(aimed, box, tgt)
	local solid = inside
	if inside then
		local pd = pad or 0.6
		for _, o in { { pd, 0 }, { -pd, 0 }, { 0, pd }, { 0, -pd } } do
			if not HitboxSettings.ContainsPoint(aimed, box, tgt + Vector3.new(o[1], 0, o[2])) then
				solid = false
				break
			end
		end
	end
	return inside, solid, aim, tgt
end

Mark.akTry = function(tag, model, r, urgent)
	if CFG.AutoKick == false then
		return false, "off"
	end
	local now = os.clock()
	if Mark.ak or now - (Mark.akAt or 0) < (CFG.AutoKickCooldown or 0.5) then
		return false, "busy"
	end
	local character = LocalPlayer.Character
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	if not (character and root and model and r and r.Parent) then
		return false, "nochar"
	end
	if MatchSettings.IsGoalkeeperCharacter(character) or liveOwnerId() == LocalPlayer.UserId then
		return false, "role"
	end
	if (ChargedKick.IsCharging and ChargedKick.IsCharging()) or Mark.volleyInput or (Mark.realKick and Mark.realKick.down) then
		return false, "charging"
	end
	if slideAim or ClientSlide.IsSlideTackling() or ClientDodge.IsDribbling() or Ragdoll.IsActorRagdolled(LocalPlayer) or Mark.aerial then
		return false, "busy2"
	end
	if Dodge.IsDribbling(model) then
		return false, "iframe"
	end
	local okD, down = pcall(Mark.mateDown, Actors.GetFromCharacter(model), model)
	if okD and down then
		return false, "down"
	end
	local ctx = Mark.akClampUs(Mark.akCtx(root, model, r), character)
	local minRel = (KickCore.GetMinimumReleaseSeconds and KickCore.GetMinimumReleaseSeconds()) or 0.2
	local maxC = KickCore.Constants.MaximumChargeSeconds or 0.4
	-- A charge slows us to ~8 studs/s (ws 27 -> 8) and stands us still for ~0.3 s: against a carrier who is pulling AWAY
	-- (we are behind him, he runs straight) the box is empty by the time it goes live - the charge is wasted and the chase
	-- is lost. opening = how fast the gap grows with us at charging speed. Fleeing -> no kick: the run / slide / AutoBall
	-- logic goes on (the tackle gate takes him); a slow opening gap needs a margin that scales with it.
	local toHim = unitOrNil(flat(r.Position - root.Position))
	local vHim = flat(r.AssemblyLinearVelocity)
	if ctx.vel.Magnitude > vHim.Magnitude then
		vHim = flat(ctx.vel)
	end
	local opening = toHim and (vHim:Dot(toHim) - ctx.vUs:Dot(toHim)) or 0
	if not urgent and opening > (CFG.AutoKickFlee or 9) then
		if not Mark.akFleeLog or now - Mark.akFleeLog > 0.8 then
			Mark.akFleeLog = now
			logFile("autokick skip fleeing", tag, actorName(Actors.GetFromCharacter(model)), "opening", string.format("%.1f", opening), "his", string.format("%.1f", vHim.Magnitude), "dist", string.format("%.1f", flat(r.Position - root.Position).Magnitude))
		end
		return false, "fleeing"
	end
	local pad = 0.6 + math.max(opening, 0) * (CFG.AutoKickPadPerSpeed or 0.1)
	local first, bestSolid, bestAim = nil, nil, nil
	local rr = minRel
	while rr <= maxC - 0.02 do
		local inside, solid, aim = Mark.akEval(ctx, rr, pad)
		if inside then
			first = first or rr
			if solid then
				bestSolid, bestAim = rr, aim
			end
			bestAim = bestAim or aim
		end
		rr += 0.02
	end
	-- eager: press as soon as the box already holds him at the earliest release (a solid hit later is a bonus, not a condition);
	-- waiting for a solid hit across the whole 0.2-0.4 s window made the kick start after he had gone
	if not first or (not urgent and not bestSolid and not (CFG.AutoKickEager ~= false and opening <= 2 and first <= minRel + 0.07)) then
		return false, "nohit"
	end
	if CFG.AutoKickFull ~= false then
		-- the kick will be released at the full charge: he has to be inside the box THEN, not only at the earliest release
		local fullT = (KickCore.GetFullChargeSeconds and KickCore.GetFullChargeSeconds()) or (maxC - 0.05)
		if not Mark.akEval(ctx, fullT, pad) then
			return false, "nohit full"
		end
	end
	-- never kick through a teammate or toward our own goal with the ball at his feet
	local aimDir = bestAim
	for _, m in Actors.GetAllCharacterModels() do
		local a = Actors.GetFromCharacter(m)
		if a and a ~= LocalPlayer and sameTeam(a) then
			local ar = ActorTargeting.GetActorRoot(a)
			if ar then
				local usAt = root.Position + ctx.vUs * (bestSolid or first)
				local aimed = AimFacing.GetAimedRoot({ Position = usAt }, aimDir)
				if HitboxSettings.ContainsPoint(aimed, HitboxSettings.Kick, ar.Position) then
					return false, "mate"
				end
			end
		end
	end
	local ball = Renderer.GetPosition()
	local goal = Mark.defendGoal()
	if ball and goal and flat(ball - r.Position).Magnitude < 7 then
		local own = unitOrNil(flat(goal.Position - root.Position))
		if own and own:Dot(aimDir) > 0.5 and flat(goal.Position - root.Position).Magnitude < 70 then
			return false, "ownside"
		end
	end
	Mark.volleyAim = aimDir
	Mark.volleyAimUntil = now + 0.7
	local input = Controls.CreateInput("Kick")
	if not (ChargedKick.HandleInputBegan(input, false) and ChargedKick.IsCharging()) then
		Mark.volleyAim, Mark.volleyAimUntil = nil, nil
		return false, "refused"
	end
	Mark.volleyAt = now
	Mark.scriptChargeAt = now
	Mark.userVolleyAt = now
	Mark.ak = { input = input, at = now, model = model, root = r, tag = tag, urgent = urgent and true or false, miss = 0, lastT = now }
	Mark.akAt = now
	logFile("autokick", "press", tag, actorName(Actors.GetFromCharacter(model)), "first", string.format("%.2f", first), "solid", bestSolid and string.format("%.2f", bestSolid) or "-", "urgent", tostring(urgent == true), "dist", string.format("%.1f", flat(r.Position - root.Position).Magnitude), "air", tostring(ctx.hisAir) .. "/" .. tostring(ctx.usAir))
	return true, "pressed"
end

Mark.akTick = function(character, root)
	local ak = Mark.ak
	if not ak then
		return
	end
	local now = os.clock()
	local dt = math.clamp(now - (ak.lastT or now), 0, 0.1)
	ak.lastT = now
	local function finish(why, cancel)
		if cancel and ChargedKick.CancelCharge and ChargedKick.IsCharging and ChargedKick.IsCharging() then
			ChargedKick.CancelCharge()
		end
		Mark.ak = nil
		Mark.volleyAim, Mark.volleyAimUntil = nil, nil
		logFile("autokick", why, ak.tag, "held", string.format("%.2f", now - ak.at))
	end
	if not (ChargedKick.IsCharging and ChargedKick.IsCharging()) then
		return finish("end")
	end
	if not (ak.model and ak.model.Parent and ak.root and ak.root.Parent) or liveOwnerId() == LocalPlayer.UserId or ClientSlide.IsSlideTackling() or Ragdoll.IsActorRagdolled(LocalPlayer) then
		return finish("abort", true)
	end
	if Mark.realKick and Mark.realKick.down and Mark.realKick.at and Mark.realKick.at > ak.at then
		Mark.ak = nil -- the user took the kick over
		return
	end
	-- he dribbled: the iframe eats the kick. Cancel it, remember his Dodge (carrierDribbleWait) so the tackle gate
	-- ("naked": slide right after his iframe while his cooldown runs) takes over.
	if Dodge.IsDribbling(ak.model) then
		pcall(carrierDribbleWait, Actors.GetFromCharacter(ak.model), 0)
		TurnControl.ReleaseAutoRotate("AimCharge")
		return finish("cancel iframe", true)
	end
	local inst = Mark.chargeInst()
	local held = (inst and inst.GetHeldSeconds and inst.GetHeldSeconds()) or (now - ak.at)
	local minRel = (KickCore.GetMinimumReleaseSeconds and KickCore.GetMinimumReleaseSeconds()) or 0.2
	local maxC = KickCore.Constants.MaximumChargeSeconds or 0.4
	local fullAt = KickCore.GetFullChargeSeconds and KickCore.GetFullChargeSeconds() or (maxC - 0.05)
	local ctx = Mark.akClampUs(Mark.akCtx(root, ak.model, ak.root), character)
	local r0 = math.max(minRel - held, 0)
	local inNow, solidNow, aimNow = Mark.akEval(ctx, r0)
	-- keep the override on the aim of the best upcoming moment
	if aimNow then
		Mark.volleyAim = aimNow
		Mark.volleyAimUntil = now + 0.5
		TurnControl.LockAutoRotate("AimCharge", aimNow)
	end
	if held >= minRel - 0.004 then
		if inNow then
			ak.miss = 0
			-- release at the FULL charge when the box still holds him then; earlier only if he would be out of it by then
			-- (a hit at 0.30 s is half the power: the log showed every release at held 0.30)
			local toFull = math.max(fullAt - 0.008 - held, 0)
			local inFull = toFull <= 0 or Mark.akEval(ctx, toFull)
			local releaseNow
			if CFG.AutoKickFull ~= false then
				-- always the FULL charge: no early release for an urgent kick or a carrier who would leave the box; if he
				-- leaves it the charge is cancelled below (miss) instead of sending a weak kick
				releaseNow = held >= fullAt + 0.002 or held >= maxC - 0.03
			else
				releaseNow = ak.urgent or held >= math.min(fullAt - 0.008, CFG.AutoKickRelease or 9) or not inFull or held >= maxC - 0.045
			end
			if releaseNow then
				Mark.ak = nil
				Mark.volleyAimUntil = now + 0.25
				pcall(ChargedKick.HandleInputEnded, ak.input)
				TurnControl.ReleaseAutoRotate("AimCharge")
				logFile("autokick", "release", ak.tag, "held", string.format("%.3f", held), "full", tostring(held >= fullAt - 0.01), "solid", tostring(solidNow), "dist", string.format("%.1f", flat(ak.root.Position - root.Position).Magnitude))
				return
			end
		else
			ak.miss += dt
			-- he is out of the box now: any later moment still in the window?
			local any = false
			local rr = r0 + 0.02
			while rr <= maxC - held - 0.02 do
				if Mark.akEval(ctx, rr) then
					any = true
					break
				end
				rr += 0.02
			end
			if not any or ak.miss > 0.16 then
				TurnControl.ReleaseAutoRotate("AimCharge")
				return finish("cancel miss", true)
			end
		end
	end
end

Mark.volleyPending = function()
	local input = Mark.volleyInput
	if not input then
		return
	end
	local charging = ChargedKick.IsCharging and ChargedKick.IsCharging()
	local age = os.clock() - (Mark.volleyAt or 0)
	if not charging then
		Mark.volleyInput = nil
		return
	end
	if age >= 0.05 then
		Mark.volleyInput = nil
		ChargedKick.HandleInputEnded(input)
		logFile("volley", "release", age > 0.3 and "late" or "")
		if age > 0.6 and ChargedKick.IsCharging() and ChargedKick.CancelCharge then
			ChargedKick.CancelCharge()
			logFile("volley", "cancel", "stale")
		end
	end
end

Mark.tickVolley = function(character, root)
	Mark.volleyPending()
	Mark.akTick(character, root)
	if not (CFG.AutoBall or CFG.AutoBlock) then
		return
	end
	local charging = ChargedKick.IsCharging and ChargedKick.IsCharging()
	-- Our volley charge turned into a normal reception (we own the ball): the delayed release would now shoot our
	-- own ball away. Cancel it.
	if Mark.volleyAt and os.clock() - Mark.volleyAt < 1.2 and charging and liveOwnerId() == LocalPlayer.UserId then
		ChargedKick.CancelCharge()
		Mark.volleyInput = nil
		Mark.volleyAt = nil
		Mark.volleyAim = nil
		logFile("volley", "cancel", "own")
		return
	end
	if Mark.volleyInput then
		return -- still waiting for the 0.05 s press (Mark.volleyPending releases it)
	end
	if Mark.volleyAimUntil and os.clock() > Mark.volleyAimUntil then
		Mark.volleyAim = nil
		Mark.volleyAimUntil = nil
	end
	-- The player's OWN volley / bicycle (he jumped and pressed Kick at an incoming ball): AutoShoot it once per claim
	-- from the meet point and lock the aim, so the release goes into the goal instead of where the camera looks.
	if charging and not Mark.volleyAt and CFG.AutoShoot and not Mark.weOwn() and not Mark.aerial then
		Mark.volleyMod = Mark.volleyMod or require(Client.Gameplay.Actions.VolleyOpportunity)
		local evU = Mark.volleyMod.GetEvaluation(character)
		if evU and not (Mark.userVolleyAt and os.clock() - Mark.userVolleyAt < 1.0) then
			Mark.userVolleyAt = os.clock()
			local _, _, samples, ts = Mark.ballPath(root)
			local meet = nil
			if samples then
				for i = 1, #samples do
					if ts[i] >= (evU.ApproachSeconds or 0) then
						meet = samples[i]
						break
					end
				end
			end
			local goal = enemyGoalPart()
			if meet and goal and flat(goal.Position - meet).Magnitude <= (CFG.ShootMaxDist or 160) then
				Mark.volleyContact = meet
				Mark.flickAim = true
				Shoot.curve = nil
				solveShot(root, true)
				Mark.flickAim = false
				Mark.volleyContact = nil
				if Shoot.aim then
					Mark.shotLockUntil = os.clock() + (evU.ApproachSeconds or 0.4) + 1.0
				end
				local hum = character:FindFirstChildOfClass("Humanoid")
				logFile("volley", "user", Shoot.aim and ("shot " .. tostring(Shoot.band)) or "noshot", "bike", tostring(hum and BicycleKick.CanBicycleKick(character, hum)), "goalD", string.format("%.0f", flat(goal.Position - meet).Magnitude))
			end
		end
	end
	if charging or not Mark.playLive() or Mark.weOwn() or Mark.aerial then
		return
	end
	local oid = liveOwnerId()
	if type(oid) == "number" and oid ~= 0 then
		-- a team-mate's ball is his; an ENEMY on the ball only blocks us if the game gives no volley evaluation (it
		-- does for a ball he pops or kicks up). VolleyOpportunity.GetEvaluation + the plan gate below decide.
		local who = playerOf(oid)
		if not who or who == LocalPlayer or sameTeam(who) then
			return
		end
	end
	if slideAim or ClientSlide.IsSlideTackling() or ClientDodge.IsDribbling() then
		return
	end
	local inst = Mark.chargeInst()
	if inst and inst.CanKick and not inst.CanKick() then
		return
	end
	Mark.volleyMod = Mark.volleyMod or require(Client.Gameplay.Actions.VolleyOpportunity)
	local ev = Mark.volleyMod.GetEvaluation(character)
	if not ev then
		return
	end
	local plan, skip = Mark.volleyPlan(root, ev)
	if not plan then
		local skipKey = tostring(skip):match("^%S+")
		if Mark.volleySkip ~= skipKey then
			Mark.volleySkip = skipKey
			logFile("volley", "skip", skip)
		end
		return
	end
	Mark.volleySkip = nil
	-- The bicycle kick is the game's upgrade of this press (BicycleKick.CanBicycleKick: unused jump AND rising). A
	-- press while landed / falling is a plain volley that just launches the ball. Wait for the rise (AutoBall's jump
	-- is timed to it); only the last 0.14 s before arrival go with whatever we have.
	do
		local humB = character:FindFirstChildOfClass("Humanoid")
		local canBike = humB and BicycleKick.CanBicycleKick(character, humB)
		if not canBike and (ev.ApproachSeconds or 0) > 0.14 then
			return
		end
	end
	-- AutoShoot from the contact point: the volley / bicycle is a real shot at goal, not a blind "far side 70%" poke.
	-- The aim is locked through strikeRay (shotLockUntil) so commitAimLock / release use it. In range but no shot
	-- found and no threat -> do not volley (receive instead).
	local shotFrom = nil
	-- a forced solve is 5-20 ms; with no shot found and no threat this ran EVERY frame while the ball hung in the air
	if CFG.AutoShoot and plan.near and not plan.threat and Mark.volleyNoShotAt and os.clock() - Mark.volleyNoShotAt < 0.3 then
		return
	end
	if CFG.AutoShoot and plan.near and plan.meet then
		Mark.volleyContact = plan.meet
		Mark.flickAim = true
		Shoot.curve = nil
		solveShot(root, true)
		Mark.flickAim = false
		Mark.volleyContact = nil
		if Shoot.aim then
			shotFrom = Shoot.band or "-"
			Mark.shotLockUntil = os.clock() + (ev.ApproachSeconds or 0.4) + 1.0
		elseif not plan.threat then
			Mark.volleyNoShotAt = os.clock()
			if Mark.volleySkip ~= "noshot" then
				Mark.volleySkip = "noshot"
				logFile("volley", "skip", "noshot", "goalD", string.format("%.0f", plan.goalD), "why", tostring(Shoot.lastWhy))
			end
			return
		end
	end
	Mark.volleyAim = plan.aim
	Mark.volleyAimUntil = os.clock() + 1.5
	local input = Controls.CreateInput("Kick")
	if not (ChargedKick.HandleInputBegan(input, false) and ChargedKick.IsCharging()) then
		Mark.volleyAim = nil
		Mark.volleyAimUntil = nil
	else
		Mark.volleyInput = input
		Mark.volleyAt = os.clock()
		local hum = character:FindFirstChildOfClass("Humanoid")
		logFile("volley", "press", shotFrom and ("shot " .. shotFrom) or (plan.near and "goal" or "clear"), "threat", string.format("%.1f", plan.threatD), "goalD", string.format("%.0f", plan.goalD), "approach", string.format("%.2f", ev.ApproachSeconds or -1), "miss", string.format("%.1f", ev.MissAngleDegrees or -1), "grounded", tostring(ev.BallGrounded), "air", tostring(hum and not CharacterControllers.IsLanded(character, hum)), "counter", tostring(os.clock() - (Mark.counterAt or 0) < 1.5), "enemyOwner", tostring(type(oid) == "number" and oid ~= 0))
	end
end

-- Jump planner shared by AutoBall and AutoBlock: a ball that will pass ABOVE the standing contact band but inside jump
-- reach, near enough to be at us when the rise lifts the root to it. The old rule jumped only when the sample time
-- matched the rise time within +-0.05 and lived in tickBall, which returns while AutoBlock is active - so under
-- block a high shot or lob never made the script jump. A jump holds us above height h from the rise time tr until
-- the fall back through it (2*apexT - tr): jump as soon as the ball arrives no later than 0.1 s after that rise, not
-- before -0.03 (too late to get there).
Mark.planJump = function(root, samples, ts, spd)
	local front = HitboxSettings.FrontAssist
	local reachHi = front.CFrameOffset.Y + front.Size.Y * 0.5
	local reachXZ = front.Size.X * 0.5 + (-front.CFrameOffset.Z)
	local jumpH = Mark.jumpH or 7.2
	for i = 2, #samples do
		local t = ts[i]
		if t > 1.25 then
			break
		end
		local p = samples[i]
		local h = p.Y - root.Position.Y
		if h > reachHi and h <= reachHi + jumpH - 0.3 then
			local tr = Mark.riseT(h - reachHi + 0.6)
			local d = t - tr
			local flatD = flat(p - root.Position).Magnitude
			-- already under the arc: jump up to 0.28 s early (the hold covers it). Running in: 0.18 s, not the old 0.1 s window that a skipped frame missed.
			if flatD <= reachXZ + 2 and d >= -0.04 and d <= 0.14 then
				return t, h
			end
			if d >= -0.04 and d <= 0.10 and flatD <= reachXZ + spd * math.min(t, 0.5) then
				return t, h
			end
		end
	end
	return nil
end

-- The flick as a path. RainbowFlick pops the ball up 0.4 s (BallDetachSeconds) after the start: GetCharacterLaunch gives the
-- launch position and velocity (ForwardSpeed 6 forward, PopUpSpeed 48 up, the carrier's own velocity inherited), and the ball
-- is a plain ballistic flight from there - so the whole lob is known the moment the wind-up starts. Times are from now.
Mark.flickShot = function(actor)
	Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
	local ch = Actors.GetCharacter(actor)
	if not ch or not Mark.enemyWind(actor) then
		return nil
	end
	local memo = Mark.flickMemo and Mark.flickMemo[actor]
	if memo and os.clock() - memo.at < 0.06 then
		return memo
	end
	local okL, L = pcall(Mark.flick.GetCharacterLaunch, ch)
	if not (okL and L and typeof(L.Position) == "Vector3" and typeof(L.Velocity) == "Vector3") then
		return nil
	end
	local fr = Mark.flickRec and Mark.flickRec[actor.UserId]
	local untilT = fr and fr.detachSrv
	local nowS = Workspace:GetServerTimeNow()
	local left = 0
	if type(untilT) == "number" then
		left = math.max(untilT - nowS, 0)
	end
	local carrierV = flat(CharacterMotion.GetVelocity(ch) or Vector3.zero)
	local launch = L.Position + carrierV * left
	local t0 = nowS + left
	local okS, st = pcall(Physics.NewState, launch, L.Velocity, Physics.BallRadius, t0, Vector3.zero)
	if not okS or type(st) ~= "table" then
		return nil
	end
	local _, world = Renderer.GetMovementState()
	local pts, ts = { launch }, { left }
	for i = 1, 40 do
		local t = i * 0.04
		local okG, s = pcall(Physics.GetStateAtTime, st, t0 + t, world)
		local p = okG and s and s.Position
		if typeof(p) ~= "Vector3" then
			break
		end
		pts[#pts + 1] = p
		ts[#ts + 1] = left + t
	end
	memo = { at = os.clock(), pts = pts, ts = ts, left = left, launch = launch, vel = L.Velocity }
	Mark.flickMemo = Mark.flickMemo or setmetatable({}, { __mode = "k" })
	Mark.flickMemo[actor] = memo
	return memo
end

-- true when a predicted flight (points, relative times) ends in our mouth
Mark.pathOnTarget = function(pts)
	local g = Mark.defendGoal()
	if not (g and pts and #pts >= 2) then
		return false
	end
	local lb, lt, rb = goalMouthCorners(g)
	if not (lb and lt and rb) then
		return false
	end
	local mouth = (lb + rb) * 0.5
	local sideV = unitOrNil(flat(rb - lb))
	if not sideV then
		return false
	end
	local out = Vector3.new(-sideV.Z, 0, sideV.X)
	if flat(pts[1] - mouth):Dot(out) < 0 then
		out = -out
	end
	local half = flat(rb - lb).Magnitude * 0.5
	for i = 2, #pts do
		local p = pts[i]
		if flat(p - mouth):Dot(out) <= 0.3 then
			return math.abs(flat(p - mouth):Dot(sideV)) <= half + 2.5 and p.Y <= math.max(lt.Y, lb.Y) + 1.5, i
		end
	end
	return false
end

-- BEFORE the release: the replicated charge gives the flight, so the jump for a high shot is timed to it (the release is
-- assumed at the full charge: the game releases by itself at the maximum). The old jump waited for the ball to exist - on a
-- close shot the rise (0.27 s) was longer than the ball's whole flight.
Mark.preJump = function(character, root, oid)
	if CFG.BlockPreJump == false then
		return
	end
	local rec = Mark.charges and Mark.charges[oid]
	if not (rec and rec.live and os.clock() - (rec.seen or 0) < 0.6) then
		return
	end
	local cs = Mark.chargeShot(oid)
	if not (cs and Mark.pathOnTarget(cs.pts)) then
		return
	end
	local full = (KickCore.GetFullChargeSeconds and KickCore.GetFullChargeSeconds()) or 0.35
	local shift = math.max(rec.at + full - 0.03 - os.clock(), 0)
	local ts2 = table.create(#cs.ts)
	for i, t in cs.ts do
		ts2[i] = t + shift
	end
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local spd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false) * 1.05
	local t, h = Mark.planJump(root, cs.pts, ts2, spd)
	if t and Mark.doJump("prejump") then
		Mark.blockJumpAt = os.clock()
		logFile("block prejump", "arrive", string.format("%.2f", t), "h", string.format("%.1f", h), "release in", string.format("%.2f", shift), "speed", string.format("%.0f", cs.speed))
	end
end

-- Slide at the BALL, verified against its path: the box (5x5x5, 3 studs ahead, travel = the game's cubic-out dash x the multiplier)
-- must hold the ball in >= SlideMinHits of 11 samples of the live window, the ball taken at press + ping/2 + SlideLag + tau
-- (the server receives the press later and the ball keeps rolling). Tries the given direction and small rotations.
Mark.slideSweepBall = function(O, dir, m, samples, ts, ping)
	local box = HitboxSettings.SlideTackle
	local boxMid = -box.CFrameOffset.Z
	local hx, hz = box.Size.X * 0.5 + 0.25, box.Size.Z * 0.5 + 0.25
	local hLo = box.CFrameOffset.Y - box.Size.Y * 0.5 - 0.5
	local hHi = box.CFrameOffset.Y + box.Size.Y * 0.5 + 0.5
	local t0, t1 = C.HitboxDelaySeconds, C.HitboxDelaySeconds + C.HitboxSeconds
	local lag = ping * 0.5 + (CFG.SlideLag or 0.03)
	local function ballAt(t)
		if t <= 0 then
			return samples[1]
		end
		for i = 2, #ts do
			if ts[i] >= t then
				local k = (t - ts[i - 1]) / math.max(ts[i] - ts[i - 1], 1e-3)
				return samples[i - 1]:Lerp(samples[i], k)
			end
		end
		return nil
	end
	local best, bestHits = nil, 0
	for _, deg in { 0, 6, -6, 12, -12, 18, -18 } do
		local r = math.rad(deg)
		local phi = Vector3.new(dir.X * math.cos(r) - dir.Z * math.sin(r), 0, dir.X * math.sin(r) + dir.Z * math.cos(r))
		local hits = 0
		for k = 0, 10 do
			local tau = t0 + (t1 - t0) * k / 10
			local B = ballAt(lag + tau)
			if B then
				local h = B.Y - O.Y
				if h >= hLo and h <= hHi then
					local rel = flat(B - (O + phi * (Mark.dumpTravel(tau) * m + boxMid)))
					if math.abs(rel:Dot(phi)) <= hz and math.abs(rel.X * phi.Z - rel.Z * phi.X) <= hx then
						hits += 1
					end
				end
			end
		end
		if hits > bestHits then
			best, bestHits = phi, hits
		end
	end
	return best, bestHits
end

-- measured, not modelled: what did the slide really cover, and how close did the ball come to its box? (`slide audit`)
Mark.slideTrackTick = function(root)
	local tr = Mark.slideTrack
	if not tr then
		return
	end
	local now = os.clock()
	local tau = now - tr.at
	if tau < 0 then
		return
	end
	local disp = flat(root.Position - tr.O):Dot(tr.dir)
	for _, b in { 0.27, 0.42, 0.57 } do
		if not tr["g" .. b] and tau >= b then
			tr["g" .. b] = disp
		end
	end
	local ball = Renderer.GetPosition()
	if typeof(ball) == "Vector3" and tau >= 0.2 and tau <= 0.8 then
		local box = HitboxSettings.SlideTackle
		local d = flat(ball - (root.Position + tr.dir * (-box.CFrameOffset.Z))).Magnitude
		if not tr.minD or d < tr.minD then
			tr.minD, tr.minT = d, tau
		end
	end
	if tau >= 0.95 then
		Mark.slideTrack = nil
		logFile("slide audit", tr.tag or "ball", "mult", string.format("%.2f", tr.m),
			"travel@0.27", string.format("%.1f/%.1f", tr["g0.27"] or -1, Mark.dumpTravel(0.27) * tr.m),
			"@0.42", string.format("%.1f/%.1f", tr["g0.42"] or -1, Mark.dumpTravel(0.42) * tr.m),
			"@0.57", string.format("%.1f/%.1f", tr["g0.57"] or -1, Mark.dumpTravel(0.57) * tr.m),
			"ballClosest", tr.minD and string.format("%.1f at %.2f", tr.minD, tr.minT) or "-", "ownerNow", tostring(liveOwnerId()))
	end
end

Mark.tackleReady = function(character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	return CFG.AutoTackle ~= false and hum ~= nil and os.clock() - lastTackleAt >= tackleEnforced
		and not Ragdoll.IsActorRagdolled(LocalPlayer)
		and not (ChargedKick.IsCharging and ChargedKick.IsCharging())
		and not ActionLocks.HasTackleBlock(LocalPlayer)
		and not SlideTackle.IsRepeatBlocked(character, false)
		and not ClientDodge.IsDribbling()
end

-- AutoBlock x TACKLE. The block stands where the replicated charge says; when the shot is out and the body cannot get to it
-- in time, a slide can: ~36 studs/s for the first second against 27 for a run, and the box (5x5x5, 3 ahead) stops the ball.
-- Ground slide first; a ball above the box but inside jump reach -> jump, then the slide from the air (Mark.blockCombo,
-- server acceptance of an air slide is not confirmed: `block slide air` + the tackle verdict decide). A body that reaches the
-- ball in time keeps the slide in the pocket (cooldown 3 s, ~1 s of lock).
Mark.blockSlide = function(character, root)
	if CFG.BlockSlide == false or not CFG.AutoTackle then
		return
	end
	local now = os.clock()
	if now - (Mark.blockSlideAt or 0) < 0.6 or slideAim or ClientSlide.IsSlideTackling() then
		return
	end
	local oid = liveOwnerId()
	if (type(oid) == "number" and oid ~= 0) or Mark.weOwn() or (Mark.allyKickUntil and now < Mark.allyKickUntil) then
		return
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or not Mark.tackleReady(character) then
		return
	end
	local landed = CharacterControllers.IsLanded(character, hum)
	local combo = Mark.blockCombo
	if combo and now > combo.untilT then
		Mark.blockCombo = nil
		combo = nil
	end
	if not landed and not combo then
		return
	end
	local _, vel, samples, ts = Mark.ballPath(root)
	if not samples or #samples < 3 or vel.Magnitude < 24 then
		return
	end
	local ok, ci = Mark.pathOnTarget(samples)
	if not ok then
		return
	end
	local crossT = ts[ci] or 9
	if crossT > 1.5 then
		return
	end
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local spd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false)
	local rcv = HitboxSettings.Receive
	local bodyHalf = rcv.Size.X * 0.5
	local lo = rcv.CFrameOffset.Y - rcv.Size.Y * 0.5
	local hi = rcv.CFrameOffset.Y + rcv.Size.Y * 0.5 + (Physics.BallRadius or 1)
	-- the body gets there first: nothing to add
	if not combo then
		for i = 2, ci do
			local p = samples[i]
			local h = p.Y - root.Position.Y
			if h >= lo and h <= hi and (math.max(flat(p - root.Position).Magnitude - bodyHalf, 0) / spd + ping * 0.5 + 0.06) <= ts[i] then
				return
			end
		end
	end
	local box = HitboxSettings.SlideTackle
	local boxMid = -box.CFrameOffset.Z
	local hx, hz = box.Size.X * 0.5, box.Size.Z * 0.5
	local yLo, yHi = box.CFrameOffset.Y - box.Size.Y * 0.5 - (Physics.BallRadius or 1), box.CFrameOffset.Y + box.Size.Y * 0.5 + (Physics.BallRadius or 1)
	local t0, t1 = C.HitboxDelaySeconds, C.HitboxDelaySeconds + C.HitboxSeconds
	local mHi = math.max(0.4, CFG.TackleSpeed)
	local mLo = math.min(mHi, CFG.TackleMinSpeed or 0.6)
	local function ballAt(t)
		if t <= 0 then
			return samples[1]
		end
		for i = 2, #ts do
			if ts[i] >= t then
				local k = (t - ts[i - 1]) / math.max(ts[i] - ts[i - 1], 1e-3)
				return samples[i - 1]:Lerp(samples[i], k)
			end
		end
		return nil
	end
	local O = root.Position
	local vy = root.AssemblyLinearVelocity.Y
	local g = Workspace.Gravity
	local fine = {}
	for k = 0, 10 do
		local tau = t0 + (t1 - t0) * k / 10
		fine[#fine + 1] = { tau, Mark.dumpTravel(tau) }
	end
	local best = nil
	for a = 0, 345, 15 do
		local r = math.rad(a)
		local phi = Vector3.new(math.cos(r), 0, math.sin(r))
		for mi = 0, 4 do
			local m = mLo + (mHi - mLo) * mi / 4
			local hits = 0
			for _, f in fine do
				local B = ballAt(ping * 0.5 + (CFG.SlideLag or 0.03) + f[1])
				if B then
					local oy = landed and 0 or (vy * f[1] - 0.5 * g * f[1] * f[1])
					local ctr = O + phi * (f[2] * m + boxMid)
					local rel = flat(B - ctr)
					local dy = B.Y - (O.Y + oy)
					if math.abs(rel:Dot(phi)) <= hz and math.abs(rel.X * phi.Z - rel.Z * phi.X) <= hx and dy >= yLo and dy <= yHi then
						hits += 1
					end
				end
			end
			if hits >= (CFG.SlideMinHits or 3) and (not best or hits > best.hits) then
				best = { aim = phi, mult = m, hits = hits, ang = a }
			end
		end
	end
	if best then
		Mark.blockSlideAt = now
		Mark.blockCombo = nil
		local sent, why = Mark.tryTackle(character, root, best.aim, best.mult)
		logFile("block slide", landed and "ground" or "air", sent and "sent" or ("no " .. tostring(why)), "hits", best.hits, "mult", string.format("%.2f", best.mult), "cross", string.format("%.2f", crossT), "speed", string.format("%.0f", vel.Magnitude))
		return
	end
	-- nothing on the ground: a ball above the box but inside jump reach, close to us -> jump now, slide from the air
	if landed and not combo and CFG.BlockSlideJump ~= false then
		for i = 2, ci do
			local p = samples[i]
			local t = ts[i]
			local h = p.Y - O.Y
			local d = flat(p - O).Magnitude
			if t >= 0.22 and t <= 0.9 and h > yHi and h <= yHi + 4 and d <= boxMid + hz + spd * 0.15 then
				if Mark.doJump("blockslide") then
					Mark.blockCombo = { at = now, untilT = now + 0.55 }
					Mark.blockSlideAt = now - 0.45
					logFile("block slide", "jump first", "t", string.format("%.2f", t), "h", string.format("%.1f", h), "d", string.format("%.1f", d))
				end
				return
			end
		end
	end
end

-- AutoBlock jump: enemy shots / lobs / passes over the Receive box while we shadow the carrier.
Mark.tickBlockJump = function(character, root)
	if os.clock() - (Mark.blockJumpAt or 0) < 0.5 or Mark.aerial then
		return
	end
	local oid = liveOwnerId()
	if type(oid) == "number" and oid ~= 0 then
		if oid ~= LocalPlayer.UserId then
			local humP = character:FindFirstChildOfClass("Humanoid")
			if humP and CharacterControllers.IsLanded(character, humP) and not ClientDodge.IsDribbling() then
				local okP, errP = pcall(Mark.preJump, character, root, oid)
				if not okP and (not Mark.preJumpErr or os.clock() - Mark.preJumpErr > 3) then
					Mark.preJumpErr = os.clock()
					logFile("block prejump err", tostring(errP))
				end
			end
		end
		return
	end
	if Mark.weOwn() or ClientDodge.IsDribbling() or (Mark.allyKickUntil and os.clock() < Mark.allyKickUntil) then
		return
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (hum and CharacterControllers.IsLanded(character, hum)) then
		return
	end
	local _, vel, samples, ts = Mark.ballPath(root)
	if not samples or #samples < 3 or vel.Magnitude < 8 then
		return
	end
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local spd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false) * 1.05
	local t, h = Mark.planJump(root, samples, ts, spd)
	if t and Mark.doJump("blockjump") then
		Mark.blockJumpAt = os.clock()
		logFile("block jump", "t", string.format("%.2f", t), "h", string.format("%.1f", h))
	end
end

-- ROUTE PLANNER for AutoBall (Mark.routePlan). A Baritone-style search over ACTION SEQUENCES instead of "run straight at
-- the earliest reachable sample":
--   run    - run to a point of the ball path and receive it there (also "jump" for a ball above the Receive box);
--   slide  - run for tp seconds to a waypoint W, then slide in ANY direction phi with multiplier m so the slide box
--            (HitboxSettings.SlideTackle 5x5x5, 3 studs ahead, -0.5 Y) contains the ball somewhere in its live window
--            [HitboxDelaySeconds, +HitboxSeconds]. W does not have to lie on the line to the ball: besides the direct
--            waypoint, waypoints rotated +-35 / +-70 deg around the contact point give slides that cut ACROSS the ball's
--            path (the box sweeps over it for longer = more robust), so the route bends: run one way, slide another.
-- Our reach is modelled with inertia: from the current velocity v0 to full speed in CFG.BallRamp, so the set of points we
-- can be at after t seconds is a disk C(t), r(t) (closed form) - turning around costs what it really costs.
-- Contact must be earlier than the ball by ping/2 + 0.08 (we arrived exactly on time before: "t 4.20 ourT 4.20" and
-- the ball went past). The race: every foe's earliest touch of the ball path (straight run); since that is a constant,
-- the earliest contact of ours is also the best margin. A slide replaces the run only when it is clearly earlier
-- (0.25 s) or the run loses the race and the slide does not.
Mark.routePlan = function(c)
	local O, v0, spd = c.O, c.v0, c.spd
	local S, T, n = c.samples, c.ts, #c.samples
	local ramp = math.max(CFG.BallRamp or 0.2, 0.05)
	local function reach(t)
		if t <= 0 then
			return O, 0
		elseif t <= ramp then
			return O + v0 * (t - t * t / (2 * ramp)), spd * t * t / (2 * ramp)
		end
		return O + v0 * (ramp * 0.5), spd * (t - ramp * 0.5)
	end
	local function arriveT(p, pad)
		local function ok(t)
			local Cc, r = reach(t)
			return flat(p - Cc).Magnitude - pad <= r
		end
		if ok(0) then
			return 0
		end
		local lo, hi = 0, 0.5
		while not ok(hi) do
			lo = hi
			hi *= 2
			if hi > 32 then
				return math.huge
			end
		end
		for _ = 1, 12 do
			local m = (lo + hi) * 0.5
			if ok(m) then
				hi = m
			else
				lo = m
			end
		end
		return hi
	end
	local hint = 2
	local function ballAt(t)
		if t <= 0 then
			return S[1]
		end
		if t >= T[n] then
			return c.rest and S[n] or nil
		end
		if T[hint] and T[hint] > t then
			hint = 2
		end
		while hint < n and T[hint] < t do
			hint += 1
		end
		local a, b = T[hint - 1], T[hint]
		local k = b > a and (t - a) / (b - a) or 0
		return S[hint - 1]:Lerp(S[hint], k)
	end
	-- foes: earliest touch of the ball path each (straight run, no ramp; the reaction they need is not modelled)
	local foeFirst = math.huge
	for _, f in c.foes do
		local first = math.huge
		if f.s > 1 then
			for i = 1, n do
				local tF = (f.delay or 0) + math.max(0, flat(S[i] - f.p).Magnitude - c.half) / f.s
				local tt = math.max(T[i], tF)
				if tt < first then
					first = tt
				end
				if T[i] > first then
					break
				end
			end
		end
		f.first = first
		foeFirst = math.min(foeFirst, first)
	end
	local safe = 0.08 + c.ping * 0.5
	-- RUN / JUMP
	local run = nil
	for i = 2, n do
		local p, tb = S[i], T[i]
		local h = p.Y - O.Y
		local mode = nil
		if h >= c.recvLo - 0.6 and h <= c.recvHi then
			mode = "run"
		elseif h > c.recvHi and h <= c.recvHi + c.jumpH - 0.4 then
			mode = "jump"
		end
		if mode then
			local tU = arriveT(p, c.half)
			if tU + safe + (mode == "jump" and 0.12 or 0) <= tb then
				run = { kind = mode, p = p, t = tb, tUs = tU, way = p }
				break
			end
		end
	end
	if not run and c.rest and n >= 2 then
		local p = S[n]
		local tU = arriveT(p, c.half)
		run = { kind = "rest", p = p, t = math.max(T[n], tU), tUs = tU, way = p }
	end
	-- RUN + SLIDE (W, phi, m)
	local slide = nil
	if c.slideReady then
		local t0, t1 = C.HitboxDelaySeconds, C.HitboxDelaySeconds + C.HitboxSeconds
		local box = HitboxSettings.SlideTackle
		local boxMid = -box.CFrameOffset.Z
		local hx, hz = box.Size.X * 0.5 + 0.25, box.Size.Z * 0.5 + 0.25
		local hLo = box.CFrameOffset.Y - box.Size.Y * 0.5 - 0.5
		local hHi = box.CFrameOffset.Y + box.Size.Y * 0.5 + 0.5
		local mLo, mHi = c.mLo, c.mHi
		local fine, fineD = {}, {}
		for k = 0, 10 do
			local tau = t0 + (t1 - t0) * k / 10
			fine[k + 1], fineD[k + 1] = tau, Mark.dumpTravel(tau)
		end
		local coarse = { 1, 3, 5, 7, 9, 11 }
		local function inBox(W, phi, m, k, B)
			local h = B.Y - O.Y
			if h < hLo or h > hHi then
				return false
			end
			local ctr = W + phi * (fineD[k] * m + boxMid)
			local rel = flat(B - ctr)
			local lon = rel:Dot(phi)
			local lat = rel.X * phi.Z - rel.Z * phi.X
			return math.abs(lon) <= hz and math.abs(lat) <= hx
		end
		local slideLag = c.ping * 0.5 + (CFG.SlideLag or 0.03)
		local function sweep(W, phi, m, tp)
			local first, hits = nil, 0
			for k = 1, #fine do
				-- the press reaches the server ping/2 later and the ball keeps moving: the box window starts at tp + ping/2 + tau (the
				-- old tp + tau put the ball ~1-3 studs behind where it really is when the box goes live: "the ball is already gone")
				local B = ballAt(tp + slideLag + fine[k])
				if B and inBox(W, phi, m, k, B) then
					first = first or fine[k]
					hits += 1
				end
			end
			return first, hits
		end
		local rots = { 0, math.rad(35), -math.rad(35), math.rad(70), -math.rad(70) }
		local limit = math.min(run and run.t or math.huge, 3)
		local tp = 0
		while tp <= 1.5 + 1e-6 do
			if tp + t0 >= (slide and slide.tc or limit) then
				break
			end
			local Cc, r = reach(tp)
			for _, k in coarse do
				local B = ballAt(tp + slideLag + fine[k])
				if B then
					local h = B.Y - O.Y
					if h >= hLo and h <= hHi then
						local toB = flat(B - Cc)
						local dCB = toB.Magnitude
						local Slo = fineD[k] * mLo + boxMid - hz + 0.6
						local Shi = fineD[k] * mHi + boxMid + hz - 0.6
						local s = math.clamp(dCB, Slo, Shi)
						local u = dCB > 1e-3 and toB / dCB or Vector3.new(1, 0, 0)
						for _, a in rots do
							local ca, sa = math.cos(a), math.sin(a)
							local ur = Vector3.new(u.X * ca - u.Z * sa, 0, u.X * sa + u.Z * ca)
							local W = Vector3.new(B.X, O.Y, B.Z) - ur * s
							local off = flat(W - Cc).Magnitude
							if off <= r + 0.05 then
								local m = math.clamp((s - boxMid) / math.max(fineD[k], 1), mLo, mHi)
								local first, hits = sweep(W, ur, m, tp)
								if first and hits >= (CFG.SlideMinHits or 3) then
									local tc = tp + first
									if not slide or tc < slide.tc - 0.02 or (tc <= slide.tc + 0.02 and hits > slide.hits) then
										local heading = off > 0.3 and unitOrNil(flat(W - Cc)) or nil
										slide = { kind = "slide", p = B, tc = tc, t = tc, tp = tp, W = W, phi = ur, mult = m, hits = hits, rot = math.deg(a), heading = heading, way = W }
									end
								end
							end
						end
					end
				end
			end
			tp += 0.05
		end
	end
	local pick = run
	if slide then
		local runMargin = run and (foeFirst - run.t) or -math.huge
		local slideMargin = foeFirst - slide.tc
		if not run or slide.tc < run.t - (CFG.RouteSlideGain or 0.4) or (runMargin < 0.15 and slideMargin > runMargin + 0.05) then
			pick = slide
		end
	end
	if not pick then
		return nil, foeFirst
	end
	pick.margin = foeFirst - pick.t
	pick.foeFirst = foeFirst
	return pick, foeFirst, run, slide
end

-- CandidateKiller (CFG.CandidateKiller). An enemy racing us for the loose ball is slid NOW if a slide direction within
-- CFG.KillerAngle of our route direction puts his body (his server-side pose: displayed + velocity * (display delay +
-- ping/2 + tau)) inside the slide box for >= 2 samples of the live window. Smallest deviation first, then more hits.
-- He is a racer when he is within KillerReach of us and either touches the ball path no later than KillerMargin after
-- us or is already within KillerRadius of the ball. The old version measured "near the ball" to OUR intercept point
-- (often the ball's rest point 60-200 studs away) and never fired once.
Mark.killerSlide = function(root, routeDir, foes, ballNow, ourT, mLo, mHi, guard)
	local O = root.Position
	local t0, t1 = C.HitboxDelaySeconds, C.HitboxDelaySeconds + C.HitboxSeconds
	local box = HitboxSettings.SlideTackle
	local boxMid = -box.CFrameOffset.Z
	local hx, hz = box.Size.X * 0.5, box.Size.Z * 0.5
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local fine, fineD = {}, {}
	for k = 0, 10 do
		local tau = t0 + (t1 - t0) * k / 10
		fine[k + 1], fineD[k + 1] = tau, Mark.dumpTravel(tau)
	end
	local maxA = CFG.KillerAngle or 50
	local why = {}
	local best = nil
	local mates = nil
	for _, f in foes do
		local name = f.actor and actorName(f.actor) or "?"
		if not (f.root and f.root.Parent and f.model) then
			continue
		end
		local pos, vel = Mark.carrierPose(f.root, f.model)
		local dUs = flat(pos - O).Magnitude
		if dUs > (CFG.KillerReach or 28) then
			why[#why + 1] = name .. " far " .. string.format("%.0f", dUs)
			continue
		end
		local dBall = ballNow and flat(pos - ballNow).Magnitude or math.huge
		if dBall > (CFG.IntentTackleRadius or 60) then
			why[#why + 1] = name .. string.format(" ball %.0f > %d", dBall, CFG.IntentTackleRadius or 60)
			continue
		end
		local racer = dBall <= (CFG.KillerRadius or 22) or (f.first or math.huge) <= (ourT or math.huge) + (CFG.KillerMargin or 0.5)
		if not racer and not guard then
			why[#why + 1] = name .. string.format(" notracer ball %.0f first %.2f us %.2f", dBall, f.first or -1, ourT or -1)
			continue
		end
		if Dodge.IsDribbling(f.model) then
			why[#why + 1] = name .. " iframe"
			continue
		end
		if (f.delay or 0) > 0 then
			why[#why + 1] = name .. " down"
			continue
		end
		if f.sliding then
			why[#why + 1] = name .. " sliding"
			continue
		end
		local delay = math.clamp(CharacterMotion.GetDisplayDelaySeconds(f.model) or 0, 0, 0.25)
		if vel.Magnitude > 32 then
			vel = vel.Unit * 32
		end
		local E = {}
		for k = 1, #fine do
			E[k] = pos + vel * (delay + ping * 0.5 + fine[k])
		end
		local found = nil
		-- guard: the slide is at HIM (nearest to the ball), not along our route to the ball
		local base = (not guard and routeDir) or unitOrNil(flat(pos - O))
		if base then
			for step = 0, math.floor(maxA / 3) do
				for _, sg in (step == 0 and { 1 } or { 1, -1 }) do
					local a = math.rad(step * 3 * sg)
					local ca, sa = math.cos(a), math.sin(a)
					local phi = Vector3.new(base.X * ca - base.Z * sa, 0, base.X * sa + base.Z * ca)
					for mi = 0, 4 do
						local m = mLo + (mHi - mLo) * mi / 4
						local hits = 0
						for k = 1, #fine do
							local ctr = O + phi * (fineD[k] * m + boxMid)
							local rel = flat(E[k] - ctr)
							if math.abs(rel:Dot(phi)) <= hz and math.abs(rel.X * phi.Z - rel.Z * phi.X) <= hx then
								hits += 1
							end
						end
						if hits >= (CFG.SlideMinHits or 3) and (not found or hits > found.hits) then
							found = { aim = phi, mult = m, hits = hits, ang = step * 3 * sg }
						end
					end
				end
				if found then
					break
				end
			end
		end
		if not found then
			why[#why + 1] = name .. string.format(" angle (dist %.0f)", dUs)
			continue
		end
		if not mates then
			mates = {}
			for _, mm in Actors.GetAllCharacterModels() do
				local a = Actors.GetFromCharacter(mm)
				if a and a ~= LocalPlayer and sameTeam(a) then
					local ar = ActorTargeting.GetActorRoot(a)
					if ar then
						mates[#mates + 1] = ar.Position
					end
				end
			end
		end
		local clear = true
		for _, mp in mates do
			local rel = flat(mp - O)
			local along = rel:Dot(found.aim)
			if along > 0 and along < dUs + 3 and math.abs(rel.X * found.aim.Z - rel.Z * found.aim.X) < 2.6 then
				clear = false
				break
			end
		end
		if not clear then
			why[#why + 1] = name .. " mate on line"
			continue
		end
		-- rank: who reaches the ball first, a small bonus for staying close to our route
		local score = (f.first or 9) + math.abs(found.ang) * 0.004
		if not best or score < best.score then
			found.foe, found.dist, found.dBall, found.name, found.score = f, dUs, dBall, name, score
			best = found
		end
	end
	return best, table.concat(why, "; ")
end

Mark.tickBall = function(character, root)
	if not CFG.AutoBall then
		return
	end
	if not Mark.playLive() then
		Mark.ballStop("intermission")
		if Mark.ballWhy ~= "intermission" then
			Mark.ballWhy = "intermission"
			logFile("ball", "intermission")
		end
		return
	end
	if Mark.move.mode == "dodge" or Mark.move.mode == "dribble" or Mark.move.mode == "flee" or Mark.aerial then
		return
	end
	if Mark.move.mode == "block" then
		-- Block shadows a CARRIER. The moment he loses the ball nothing owned it for ~0.45 s (block hold) because this
		-- tick returned on mode == "block": that dead zone is where the enemy got to the loose ball first.
		local o = liveOwnerId()
		if type(o) == "number" and o ~= 0 then
			return
		end
	end
	if slideAim or ClientSlide.IsSlideTackling() then
		return
	end
	if ClientDodge.IsDribbling() or Mark.weOwn() then
		Mark.ballStop("own")
		return
	end
	-- Frozen (kickoff freeze: ws=0.0, jblock/sprintBlk/rot = Kickoff; also stun/ragdoll): there is nothing to run with.
	-- The log showed ball start / slideboost / tackle sent three times in a row at kickoff, every one a MISS, and a
	-- start/stop every 0.15 s at ws=0.
	do
		local humF = character:FindFirstChildOfClass("Humanoid")
		if humF and humF.WalkSpeed < 2 then
			Mark.ballStop("frozen")
			return
		end
	end
	local oid = liveOwnerId()
	if type(oid) == "number" and oid ~= 0 then
		local a = playerOf(oid)
		if a and a ~= LocalPlayer and sameTeam(a) then
			Mark.allyKickUntil = os.clock() + 1.5
		end
		if Mark.move.mode == "ball" and (not Mark.ballLostAt or os.clock() - Mark.ballLostAt > 1) then
			Mark.ballLostAt = os.clock()
			local info = Mark.ballInfo
			logFile("ball lost", "to", a and actorName(a) or tostring(oid), "team", tostring(a ~= nil and sameTeam(a)), "age", string.format("%.2f", os.clock() - (Mark.move.born or os.clock())), "plan", info and info.mode or "-", "tUs", info and string.format("%.2f", info.tUs or 0) or "-", "margin", info and info.margin and string.format("%.2f", info.margin) or "-")
		end
		Mark.ballStop("owner")
		return
	end
	local pos, vel, samples, ts, live, rest = Mark.ballPath(root)
	if not pos then
		Mark.ballStop("no ball")
		return
	end
	do
		local sp = vel.Magnitude
		if sp > 4 then
			if os.clock() - (Mark.ballPeakAt or 0) > 0.8 then
				Mark.ballPeak = sp
			else
				Mark.ballPeak = math.max(Mark.ballPeak or 0, sp)
			end
			Mark.ballPeakAt = os.clock()
		elseif os.clock() - (Mark.ballPeakAt or 0) > 0.8 then
			Mark.ballPeak = sp
		end
	end
	local to = flat(pos - root.Position)
	local dist = to.Magnitude
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local spd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false) * 1.05
	-- HitboxSettings.Receive: Oval 5.5 x 5.25, CFrameOffset Y -0.45 around our root
	local receive = HitboxSettings.Receive
	local receiveHalf = receive.Size.X * 0.5
	local recvLo = receive.CFrameOffset.Y - receive.Size.Y * 0.5
	local recvHi = receive.CFrameOffset.Y + receive.Size.Y * 0.5
	local jumpH = Mark.jumpH or 7.2
	local steer, steerT, how = nil, nil, nil
	-- Enemy field players compete for the same loose ball (Ownership.FindNearestOwner: whoever's Receive hitbox the
	-- ball enters first); Mark.routePlan races every candidate contact against them.
	local foes = {}
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if actor and actor ~= LocalPlayer and not sameTeam(actor) and not isGoalkeeper(actor) then
			local fr = ActorTargeting.GetActorRoot(actor)
			if fr and flat(fr.Position - pos).Magnitude < 60 then
				-- delay = seconds until he can move again (stun / ragdoll / freeze ice / WalkSpeed 0): a downed enemy is not a
				-- racer for that long (it was: killer slides and "foe near" boosts at men who could not walk)
				local okD, down, left = pcall(Mark.mateDown, actor, model)
				local delay = (okD and down) and math.max(left or 0, 0.5) or 0
				local humF = model:FindFirstChildOfClass("Humanoid")
				if delay == 0 and humF and humF.WalkSpeed < 2 then
					delay = 0.5
				end
				local slideUntil = SlideTackle.GetSlidingUntil(model)
				local sliding = slideUntil ~= nil and Workspace:GetServerTimeNow() < slideUntil
				-- fr.Position is the DISPLAYED pose, behind his server pose by display delay + ping/2: the old race gave him
				-- those metres for free (log: "t 0.60 ourT 0.12", owner = the enemy 0.4 s later)
				local fpos, fvel = Mark.carrierPose(fr, model)
				local lead = math.clamp(CharacterMotion.GetDisplayDelaySeconds(model) or 0, 0, 0.25) + math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25) * 0.5
				if fvel.Magnitude > 32 then
					fvel = fvel.Unit * 32
				end
				foes[#foes + 1] = { p = fpos + fvel * lead, s = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(model), false), root = fr, model = model, actor = actor, delay = delay, sliding = sliding }
			end
		end
	end
	-- real run speed: the speed boosts (ws 33.3 in the log) were planned as 26.9
	do
		local humS = character:FindFirstChildOfClass("Humanoid")
		if humS and humS.WalkSpeed > spd then
			spd = humS.WalkSpeed
		end
	end
	local boxS = HitboxSettings.SlideTackle
	local slideLo = boxS.CFrameOffset.Y - boxS.Size.Y * 0.5
	local slideHi = boxS.CFrameOffset.Y + boxS.Size.Y * 0.5
	local humB = character:FindFirstChildOfClass("Humanoid")
	local readyB = CFG.AutoTackle ~= false and CFG.BallBoost ~= false and humB and CharacterControllers.IsLanded(character, humB)
		and os.clock() - lastTackleAt >= tackleEnforced
		and not Ragdoll.IsActorRagdolled(LocalPlayer)
		and not (ChargedKick.IsCharging and ChargedKick.IsCharging())
		and not ActionLocks.HasTackleBlock(LocalPlayer)
		and not SlideTackle.IsRepeatBlocked(character, false)
		and not ClientDodge.IsDribbling()
	local mHiB = math.max(0.4, CFG.TackleSpeed)
	local mLoB = math.min(mHiB, CFG.TackleMinSpeed or 0.6)
	local plan = nil
	local memo = Mark.routeMemo
	local nowR = os.clock()
	if memo and nowR - memo.at < 0.06 and memo.ready == (readyB and true or false) then
		plan = memo.plan
		if plan and plan.tp then
			plan.tp = math.max(0, memo.tp0 - (nowR - memo.at))
		end
	else
	plan = Mark.routePlan({
		O = root.Position, v0 = flat(root.AssemblyLinearVelocity), spd = spd, samples = samples, ts = ts, rest = rest, foes = foes,
		half = receiveHalf, recvLo = recvLo, recvHi = recvHi, jumpH = jumpH, ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25),
		slideReady = readyB, mLo = mLoB, mHi = mHiB,
	})
		Mark.routeMemo = { at = nowR, plan = plan, tp0 = plan and plan.tp, ready = readyB and true or false }
	end
	local wayP = nil
	local slideP, slideT, slidePress = nil, nil, nil
	if plan then
		steer, steerT, how = plan.p, plan.t, plan.kind
		wayP = plan.way
		Mark.ballInfo = { n = #samples, tUs = plan.tUs or plan.tp or 0, margin = plan.margin, mode = plan.kind, tp = plan.tp, rot = plan.rot, hits = plan.hits }
		if plan.kind == "slide" and plan.tp <= 0.03 then
			slidePress = plan
			slideP, slideT = plan.p, plan.tc
		end
	else
		Mark.ballInfo = nil
	end
	local aimP = steer
	if not aimP then
		Mark.ballStop("no aim")
		return
	end
	local dir = unitOrNil(flat(aimP - root.Position))
	if plan and plan.kind == "slide" and not slidePress then
		dir = plan.heading or unitOrNil(flat(plan.W - root.Position)) or dir
	end
	local gap = flat(aimP - root.Position).Magnitude
	local beaten = false
	local ourNeed = math.max(0, gap - receiveHalf)
	for _, model in Actors.GetAllCharacterModels() do
		local actor = Actors.GetFromCharacter(model)
		if CFG.BallCompetitor ~= false and actor and actor ~= LocalPlayer and sameTeam(actor) and not isGoalkeeper(actor) and not Mark.mateDown(actor, model) then
			local ar = ActorTargeting.GetActorRoot(actor)
			if ar then
				-- CompetitorCheck (ball): yield only when a teammate is NOTICEABLY closer (e.g. 6 vs our 20 studs):
				-- clearly earlier in time and in distance, not a coin flip
				local d = math.max(0, flat(ar.Position - aimP).Magnitude - receiveHalf)
				local their = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(model), false)
				local ourT = ourNeed / math.max(spd, 8)
				local theirT = their > 1 and d / their or math.huge
				if theirT < ourT * 0.6 and ourT - theirT > 0.25 and ourNeed - d > (CFG.BallYieldGap or 6) then
					beaten = true
					break
				end
			end
		end
	end
	-- Enemy keeper gets to our contact point first (run, or a GoalkeeperDive whose curve time beats us): the chase is
	-- pointless, he claims it.
	local keeperFirst = false
	if not beaten then
		local diveMod = Mark.gkDiveMod or require(Modules.Actions.GoalkeeperDive)
		Mark.gkDiveMod = diveMod
		local ourT = ourNeed / math.max(spd, 8)
		for _, model in Actors.GetAllCharacterModels() do
			local actor = Actors.GetFromCharacter(model)
			if actor and actor ~= LocalPlayer and not sameTeam(actor) and isGoalkeeper(actor) then
				local ar = ActorTargeting.GetActorRoot(actor)
				if ar then
					local d = math.max(0, flat(ar.Position - aimP).Magnitude - receiveHalf)
					local their = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(model), false)
					local theirT = their > 1 and d / their or math.huge
					local okD, dd = pcall(diveMod.GetDistance, actor)
					local diveD = okD and type(dd) == "number" and dd or diveMod.Constants.Distance
					local reachD = flat(ar.Position - aimP).Magnitude - diveMod.Constants.SaveReachStuds
					if reachD <= diveD and aimP.Y - ar.Position.Y <= diveMod.Constants.MaximumSaveHeight then
						theirT = math.min(theirT, diveMod.GetCurveSecondsForTravel(math.max(reachD, 0), diveD))
					end
					if theirT + 0.1 < ourT then
						keeperFirst = true
						break
					end
				end
			end
		end
	end
	-- yield flapping: "ball start" / "ball stop teammate" alternated every frame (log 14911.9-14912.4) because the
	-- competitor test sits on a threshold. Once we yielded, stay yielded for 0.6 s.
	if beaten then
		Mark.ballYieldUntil = os.clock() + 0.6
	elseif Mark.ballYieldUntil and os.clock() < Mark.ballYieldUntil and not keeperFirst then
		beaten = true
	end
	do
		local hzEv, hzT = Mark.hazardGate(root, aimP, steerT, spd)
		if hzEv then
			Mark.ballStop("hazard")
			if not Mark.ballHazLog or os.clock() - Mark.ballHazLog > 0.6 then
				Mark.ballHazLog = os.clock()
				logFile("ball", "hazard", hzEv.item or hzEv.kind, "ta", string.format("%.2f", hzT or 0), "gap", string.format("%.1f", gap))
			end
			return
		end
	end
	if keeperFirst then
		Mark.ballStop("keeper")
		if Mark.ballWhy ~= "keeper" then
			Mark.ballWhy = "keeper"
			logFile("ball", "keeper")
		end
		return
	end
	if beaten then
		Mark.ballStop("teammate")
		if Mark.ballWhy ~= "teammate" then
			Mark.ballWhy = "teammate"
			logFile("ball", "teammate")
		end
		return
	end
	if dir and gap > receiveHalf then
		if not Mark.ballLogged then
			Mark.ballLogged = true
			logFile("ball start", how, "dist", string.format("%.2f", dist), "destT", string.format("%.2f", steerT or 0), "dest", string.format("%.1f", gap), "spd", string.format("%.1f", spd), "h", string.format("%.1f", aimP.Y - root.Position.Y), "state", tostring(live), "n", tostring(#samples), "rest", tostring(rest))
		end
		Mark.ballWhy = "chase"
		Mark.move.look = dir
		Mark.move.pts = (wayP and wayP ~= aimP) and { root.Position, wayP, aimP } or { root.Position, aimP }
		Mark.move.born = Mark.move.born or os.clock()
		Mark.moveSteer(dir, "ball")
		Mark.agentHold(true, "ball")
		if not Mark.ballTraceAt or os.clock() - Mark.ballTraceAt > 0.5 then
			Mark.ballTraceAt = os.clock()
			local pi = Mark.ballInfo
			local humT = character:FindFirstChildOfClass("Humanoid")
			logFile("ball track", how, "gap", string.format("%.1f", gap), "t", string.format("%.2f", steerT or 0), "ourT", pi and string.format("%.2f", pi.tUs) or "-", "margin", pi and ((pi.margin == math.huge or pi.margin ~= pi.margin) and "inf" or string.format("%.2f", pi.margin)) or "-", "mode", pi and pi.mode or "-", "tp", pi and pi.tp and string.format("%.2f", pi.tp) or "-", "rot", pi and pi.rot and string.format("%.0f", pi.rot) or "-", "hits", pi and pi.hits and tostring(pi.hits) or "-", "v", string.format("%.1f", flat(root.AssemblyLinearVelocity).Magnitude), "ws", humT and string.format("%.1f", humT.WalkSpeed) or "-", "spd", string.format("%.1f", spd))
		end
	elseif Mark.move.mode == "ball" then
		Mark.moveSteer(Vector3.zero, "ball")
	end
	local cross = 0
	if dir then
		cross = flat(vel - dir * dir:Dot(vel)).Magnitude
	end
	local boxHalf = HitboxSettings.SlideTackle.Size.X * 0.5
	local leaves = cross * C.HitboxSeconds > boxHalf + 1.2
	local noTouch = Mark.noTouchUntil and os.clock() < Mark.noTouchUntil
	local allyBlock = Mark.allyKickUntil and os.clock() < Mark.allyKickUntil
	if not allyBlock then
		for _, model in Actors.GetAllCharacterModels() do
			local actor = Actors.GetFromCharacter(model)
			if actor and actor ~= LocalPlayer and sameTeam(actor) and not isGoalkeeper(actor) and not Mark.mateDown(actor, model) then
				local ar = ActorTargeting.GetActorRoot(actor)
				if ar and (flat(ar.Position - root.Position).Magnitude <= 8 or flat(ar.Position - pos).Magnitude <= 8) then
					allyBlock = true
					break
				end
			end
		end
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local landed = hum and CharacterControllers.IsLanded(character, hum)
	local hstate = hum and hum:GetState()
	local airborne = hstate == Enum.HumanoidStateType.Jumping or hstate == Enum.HumanoidStateType.Freefall
	local liveH0 = pos.Y - root.Position.Y
	local nowBox = liveH0 >= slideLo and liveH0 <= slideHi
	-- Jump timing: a ball that will pass above the standing contact band (FrontAssist top) but under jump reach,
	-- close enough to be at us when the rise lifts the root to it. Volley press itself is tickVolley (game evaluation).
	local jumpAt, jumpMeet = nil, nil
	if landed then
		jumpAt, jumpMeet = Mark.planJump(root, samples, ts, spd)
	end
	local slideDir = slidePress and slidePress.phi
	-- CandidateKiller first: an enemy racing us for this ball and a slide within KillerAngle of our route that hits him.
	-- While such a racer exists the "slide as a sprint" toward the ball is off (that was the slide the user saw: our
	-- route direction, the enemy beside it untouched).
	local kill, killWhy, killRacer = nil, nil, false
	if CFG.CandidateKiller ~= false and CFG.AutoTackle and readyB and not slideDir and not noTouch
		and not (Mark.allyKickUntil and os.clock() < Mark.allyKickUntil) then
		-- GUARD: the loose ball is close to OUR goal and we are within ~20 studs of it. The enemy nearest to the ball (not its
		-- owner yet, not downed / in iframe / sliding) is slid first if the geometry allows; the run for the ball goes on
		-- regardless (a miss costs the 3 s cooldown, not the chase).
		local guardFoes = nil
		do
			local gGoal = Mark.defendGoal()
			if CFG.KillerGuard ~= false and gGoal and flat(pos - gGoal.Position).Magnitude <= (CFG.KillerGuardGoal or 55) and flat(pos - root.Position).Magnitude <= (CFG.KillerGuardNear or 22) then
				local bestF, bestD = nil, math.huge
				for _, f in foes do
					local dB = flat(f.p - pos).Magnitude
					if (f.delay or 0) <= 0 and not f.sliding and dB <= (CFG.KillerGuardFoe or 40) and dB < bestD then
						bestF, bestD = f, dB
					end
				end
				if bestF then
					guardFoes = { bestF }
				end
			end
		end
		kill, killWhy = Mark.killerSlide(root, dir, guardFoes or foes, pos, steerT, mLoB, mHiB, guardFoes ~= nil)
		if kill and guardFoes then
			kill.guard = true
		end
		killRacer = kill ~= nil or (killWhy ~= nil and killWhy:find("angle") ~= nil)
		if not kill and killWhy and killWhy ~= "" and (not Mark.killLogAt or os.clock() - Mark.killLogAt > 1) then
			Mark.killLogAt = os.clock()
			logFile("killer skip", killWhy)
		end
	end
	local boostDir = nil
	if CFG.AutoTackle and CFG.BallSlideBoost ~= false and not slideDir and not killRacer and landed and dir and steer and steerT and how ~= "now" and not allyBlock and not noTouch and not leaves then
		local D = flat(aimP - root.Position).Magnitude
		local face = unitOrNil(flat(root.CFrame.LookVector))
		if D >= 26 and D <= 90 and face and face:Dot(dir) > 0.94 and not ClientDodge.IsDribbling() then
			local mulB = math.max(0.4, CFG.TackleSpeed)
			local tS = nil
			for tt = 0.3, 1.02, 0.02 do
				if Mark.dumpTravel(tt) * mulB >= D - 2 then
					tS = tt
					break
				end
			end
			local Tslide = tS or (1.02 + (D - Mark.dumpTravel(1.02) * mulB) / spd)
			local Trun = D / spd
			local gain = Trun - Tslide
			local ourT = math.max(0, D - receiveHalf) / spd
			local foeNear = false
			for _, f in foes do
				if f.s > 1 and (f.delay or 0) + math.max(0, flat(aimP - f.p).Magnitude - receiveHalf) / f.s < ourT + 0.4 then
					foeNear = true
					break
				end
			end
			if gain >= 0.3 and (steerT - ourT < 0.3 or foeNear) then
				-- the old test was "the slide covers D - 2 sooner than the run": it fired with slack -0.35 (the run is already
				-- LATE) and never looked at where the ball is when the box goes live. Now the box must hold the ball.
				local pingB = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
				local bd, bh = Mark.slideSweepBall(root.Position, dir, mulB, samples, ts, pingB)
				if bd and bh >= (CFG.SlideMinHits or 3) then
					boostDir = bd
				end
				if not Mark.slideBoostLog or os.clock() - Mark.slideBoostLog > 1 then
					Mark.slideBoostLog = os.clock()
					logFile("ball slideboost", boostDir and "go" or "no sweep", "D", string.format("%.1f", D), "gain", string.format("%.2f", gain), "slack", string.format("%.2f", steerT - ourT), "foe", tostring(foeNear), "hits", tostring(bh))
				end
			end
		end
	end
	if kill then
		local f = kill.foe
		local okS, solved = pcall(solveIntercept, root, f.root, f.model, tackleTuning())
		predict = okS and solved or predict
		local sent, why = tryTackle(character, root, kill.aim, kill.mult, { char = f.model, root = f.root })
		logFile(kill.guard and "killer guard" or "killer", sent and "sent" or ("no " .. tostring(why)), kill.name, "ang", string.format("%.0f", kill.ang), "hits", tostring(kill.hits), "mult", string.format("%.2f", kill.mult), "dist", string.format("%.1f", kill.dist), "ballD", string.format("%.1f", kill.dBall), "hisFirst", string.format("%.2f", f.first or -1), "ourT", string.format("%.2f", steerT or -1))
	elseif boostDir and not (slideAim or ClientSlide.IsSlideTackling()) then
		tryTackle(character, root, boostDir)
	elseif CFG.AutoTackle and slideDir and not allyBlock and not noTouch and (landed or (airborne and nowBox)) then
		logFile("ball tackle", "route", "tc", string.format("%.2f", slideT or 0), "h", string.format("%.1f", slideP.Y - root.Position.Y), "rot", string.format("%.0f", slidePress.rot or 0), "hits", tostring(slidePress.hits), "mult", string.format("%.2f", slidePress.mult))
		tryTackle(character, root, slideDir, slidePress.mult)
	elseif jumpAt then
		if Mark.doJump("ball") then
			logFile("ball jump", "t", string.format("%.2f", jumpAt), "h", string.format("%.1f", jumpMeet))
		end
		Mark.ballTackleLog = nil
	else
		Mark.ballTackleLog = nil
	end
end


Mark.armFlickWindow = function()
	if not CFG.AutoShoot then
		return
	end
	local character = LocalPlayer.Character
	local root = character and ActorTargeting.GetActorRoot(LocalPlayer)
	if not root then
		return
	end
	if liveOwnerId() == LocalPlayer.UserId then
		Mark.flickAim = true
		solveShot(root, true)
		Mark.flickAim = false
	end
	if Shoot.aim then
		Mark.flickStrike = os.clock() + 3
		logFile("aerial", "arm", "flick", "dist", Shoot.dist and string.format("%.0f", Shoot.dist) or "-", "band", Shoot.band or "-")
	end
end

Mark.startAerial = function()
	if Mark.aerial then
		return
	end
	if not Mark.weOwn() then
		dbg("aerial", "no ball")
		return
	end
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root) then
		return
	end
	Mark.flickAim = true
	Shoot.curve = nil
	solveShot(root, true)
	Mark.flickAim = false
	local now = CharacterMotionSmoothing.GetSmoothedServerTime()
	Mark.aerial = { phase = "pop", at = os.clock(), server = now, jumped = false }
	Mark.flickStrike = os.clock() + 3
	if not Shoot.aim then
		logFile("aerial", "flick", "no aim", "dist", Shoot.dist and string.format("%.0f", Shoot.dist) or "-", "pool", tostring(Shoot.poolN))
	end
	-- no jump here: jumping at the flick lands us before the ball is even touchable (detach 0.4 + apex 0.48)
	Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
	Mark.fx = Mark.fx or require(Client.Gameplay.Actions.TackleEffects)
	Mark.fx.PlayLocalRainbowFlick()
	ActionRemoteProtocol.Send(ActionCommands.RainbowFlick({ ShotTime = now }))
	Mark.flick.SetWindingUpUntil(LocalPlayer, now + Mark.flick.Constants.BallDetachSeconds + Mark.flick.Constants.DetachCommandGraceSeconds)
	logFile("aerial", "flick")
end

-- G test: owned ball, plain jump (as L) and an OWNER bicycle. Shoot.HandleInputBegan(input, false, extra) passes
-- extra.IsBicycleKick into startCharge (v241 = p234.IsBicycleKick or ...), ChargedKick sets u40 and the command gets
-- IsBicycleKick (ActionRemoteProtocol); Carry.GetLaunchPosition(..., isBicycle) moves the launch point. Press while
-- rising (BicycleKick.CanBicycleKick: unused jump + vy > 0), hold the full charge, release. Server acceptance of an
-- owner bicycle is NOT confirmed by the dump.
Mark.startBike = function()
	if Mark.bike or Mark.aerial then
		return
	end
	if not Mark.weOwn() then
		logFile("bike", "no ball")
		return
	end
	if not Mark.doJump("bike") then
		logFile("bike", "no jump")
		return
	end
	Mark.bike = { at = os.clock() }
	logFile("bike", "jump")
end

Mark.tickBike = function(character, root)
	local b = Mark.bike
	if not b then
		return
	end
	local now = os.clock()
	local hum = character:FindFirstChildOfClass("Humanoid")
	if b.input then
		local charging = ChargedKick.IsCharging and ChargedKick.IsCharging()
		if not charging then
			logFile("bike", "end", "charge gone")
			Mark.bike = nil
			Mark.forceBike = nil
			return
		end
		if now - b.pressAt >= (KickCore.Constants.MaximumChargeSeconds or 0.4) then
			ChargedKick.HandleInputEnded(b.input)
			logFile("bike", "release", "aim", Shoot.aim and fmtV(Shoot.aim.Direction) or "-", "band", Shoot.band or "-")
			Mark.bike = nil
			task.delay(0.3, function()
				Mark.forceBike = nil
			end)
		end
		return
	end
	if now - b.at > 0.6 or not Mark.weOwn() then
		logFile("bike", "end", Mark.weOwn() and "no rise" or "lost ball")
		Mark.bike = nil
		return
	end
	if not (hum and BicycleKick.CanBicycleKick(character, hum)) then
		return
	end
	Mark.forceBike = true
	solveShot(root, true)
	local input = Controls.CreateInput("Kick")
	local started = ChargedKick.HandleInputBegan(input, false, { IsBicycleKick = true }) and ChargedKick.IsCharging()
	local inst = Mark.chargeInst()
	local isBike = inst and inst.IsBicycleKickCharge and inst.IsBicycleKickCharge()
	logFile("bike", "press", started and "ok" or "no", "bike", tostring(isBike), "aim", Shoot.aim and fmtV(Shoot.aim.Direction) or "-", "band", Shoot.band or "-", "bands", Mark.bandStat(Mark.shotStat))
	if started then
		b.input = input
		b.pressAt = now
		Mark.shotLockUntil = now + (KickCore.Constants.MaximumChargeSeconds or 0.4) + 0.6
	else
		Mark.bike = nil
		Mark.forceBike = nil
	end
end

Mark.bandStat = function(stat)
	local out = {}
	for k, v in stat or {} do
		out[#out + 1] = string.format("%s%d/%d", k, v[2], v[1])
	end
	table.sort(out)
	if Mark.dipWhy then
		out[#out + 1] = "dip:" .. Mark.dipWhy
		Mark.dipWhy = nil
	end
	if Mark.trickWhy then
		out[#out + 1] = "trk:" .. Mark.trickWhy
		Mark.trickWhy = nil
	end
	if Mark.fakeWhy then
		out[#out + 1] = "fake:" .. Mark.fakeWhy
	end
	if Mark.barWhy then
		out[#out + 1] = "bar:" .. Mark.barWhy
		Mark.barWhy = nil
	end
	local f = Mark.shotFail
	if f then
		out[#out + 1] = string.format("f:v%d,c%d,b%d,fr%d,k%d,bar%d,foe%d", f.vel or 0, f.cross or 0, f.block or 0, f.frame or 0, f.keeper or 0, f.bar or 0, f.foe or 0)
	end
	return table.concat(out, ",")
end

Mark.tickAerial = function(character, root)
	local a = Mark.aerial
	if not (a and character and root) then
		return
	end
	local now = os.clock()
	local dt = now - a.at
	local hum = character:FindFirstChildOfClass("Humanoid")
	Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
	local detach = Mark.flick.Constants.BallDetachSeconds
	if a.phase == "pop" then
		if dt < detach then
			return
		end
		local launch = Mark.flick.GetCharacterLaunch(character)
		if not launch then
			logFile("aerial", "detach", "miss")
			Mark.aerial = nil
			return
		end
		ActionRemoteProtocol.Send(ActionCommands.RainbowFlick({
			Mode = ActionCommands.Modes.RainbowFlickDetach,
			AimDirection = launch.Direction,
			ShotTime = a.server + detach,
		}))
		a.phase = "air"
		a.detachAt = now
		a.noTouch = Mark.flick.GetLaunchNoTouchSeconds(character) or 0.48
		Mark.flickStrike = now + 2.2
		logFile("aerial", "detach", string.format("%.1f", launch.Velocity.Y), "noTouch", string.format("%.2f", a.noTouch))
		return
	end
	local charging = ChargedKick.IsCharging and ChargedKick.IsCharging()
	if a.input then
		if charging and (now - a.pressAt >= 0.05 or liveOwnerId() == LocalPlayer.UserId) then
			ChargedKick.HandleInputEnded(a.input)
			logFile("aerial", "release", "air", tostring(hum and not CharacterControllers.IsLanded(character, hum)))
			Mark.aerial = nil
			Mark.aerialContact = nil
		elseif not charging then
			a.input = nil
		end
		return
	end
	-- Right after detach the client still reports us as owner (IsLocalOwner lags the detach); only a real reception
	-- after the untouchable apex ends the move.
	local ownNow = liveOwnerId() == LocalPlayer.UserId and now - a.detachAt > (a.noTouch or 0.48) + 0.1
	local late = a.plan and now > a.plan.t0 + 0.4
	if now - a.detachAt > 3 or (ownNow and not a.plan) or late then
		logFile("aerial", "end", late and "late" or (ownNow and "own" or "timeout"))
		Mark.aerial = nil
		Mark.aerialContact = nil
		return
	end
	local _, _, samples, ts = Mark.ballPath(root)
	if not samples then
		return
	end
	local landed = not hum or CharacterControllers.IsLanded(character, hum)
	if not a.plan or now - a.planAt > 0.1 then
		local air = HitboxSettings.AirReceive
		local ballR = Physics.BallRadius or 1
		local airTop = air.CFrameOffset.Y + air.Size.Y * 0.5 + ballR
		local reachXZ = air.Size.X * 0.5 + ballR
		local jumpH = Mark.jumpH or 7.2
		Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
		local spd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false)
		local untouch = a.detachAt + a.noTouch - now
		local baseY = landed and root.Position.Y or (a.groundY or root.Position.Y)
		a.groundY = baseY
		local plan, chase, chaseX = nil, nil, math.huge
		local floored = false
		for i = 2, #samples - 1 do
			local t = ts[i]
			local p = samples[i]
			if p.Y <= baseY + 1.5 then
				floored = true -- after a floor bounce the rising ball is fair game too
			end
			local falling = samples[i + 1].Y < p.Y
			if t >= untouch and (falling or floored) then
				local h = p.Y - baseY
				local g = math.max(flat(p - root.Position).Magnitude - reachXZ, 0)
				if h <= airTop + jumpH then
					if g <= spd * math.max(t - 0.05, 0) then
						plan = { t = t, p = p, h = h, rise = Mark.riseT(math.clamp(h - airTop + 0.5, 0.3, jumpH)) }
						break
					end
					local x = g - spd * t
					if x < chaseX then
						chaseX, chase = x, p
					end
				end
			end
		end
		a.plan, a.planAt = plan and { t0 = now + plan.t, p = plan.p, h = plan.h, rise = plan.rise } or nil, now
		a.chase = (not plan) and chase or nil
		if a.chase and not a.chaseLog then
			a.chaseLog = true
			logFile("aerial", "chase", "short", string.format("%.1f", chaseX))
		end
		if plan and a.solved and Mark.aerialContact and (plan.p - Mark.aerialContact).Magnitude > 3 then
			a.solved = false -- contact moved: the old aim was solved from the wrong point
		end
		if plan and not a.solved then
			a.solved = true
			Mark.aerialContact = plan.p
			Mark.flickAim = true
			Shoot.curve = nil
			solveShot(root, true)
			Mark.flickAim = false
			if not Shoot.aim and Mark.volleyAimAt then
				local dirA = Mark.volleyAimAt(plan.p)
				if dirA then
					Shoot.aim = { Origin = plan.p, Direction = dirA, CameraCFrame = CFrame.lookAt(plan.p, plan.p + dirA), IsAirborne = true }
					Shoot.curve = nil
					Shoot.band = "fallback"
				end
			end
			if Shoot.aim then
				Mark.shotLockUntil = now + plan.t + 1.2
			end
			logFile("aerial", "plan", "t", string.format("%.2f", plan.t), "h", string.format("%.1f", plan.h), "rise", string.format("%.2f", plan.rise), "aim", Shoot.aim and fmtV(Shoot.aim.Direction) or "-", "band", Shoot.band or "-", "bands", Mark.bandStat(Mark.shotStat))
		end
	end
	local plan = a.plan
	if not plan then
		-- out of reach this tick: run at the closest sample so a later replan finds a contact
		if a.chase then
			local toC = flat(a.chase - root.Position)
			if toC.Magnitude > 1 then
				Mark.move.look = toC.Unit
				Mark.moveSteer(toC.Unit, "kick")
			end
		end
		return
	end
	local left = plan.t0 - now
	local to = flat(plan.p - root.Position)
	if to.Magnitude > 1 then
		Mark.move.look = to.Unit
		Mark.moveSteer(to.Unit, "kick")
	end
	-- The kick the game counts is the VOLLEY claim: Shoot.HandleInputBegan only claims when
	-- VolleyOpportunity.GetEvaluation is non-nil (ball arrival <= VolleyLockOn MaximumApproachSeconds 0.4, miss angle),
	-- and upgrades it to a bicycle kick only while BicycleKick.CanBicycleKick (unused jump AND rising). The bicycle
	-- then hovers us (StartHover) until arrival. So: jump inside the approach window, press while rising with an
	-- evaluation; a press without an evaluation is a plain kick and is never sent.
	-- The bicycle needs the volley evaluation (arrival <= MaximumApproachSeconds 0.4) WHILE we still rise (~0.27 s).
	-- Jump only when the whole rise lies inside that window: the game's own ApproachSeconds if it already evaluates,
	-- else our contact time. Once pressed, BicycleKick.StartHover holds us up until the ball arrives.
	Mark.volleyMod = Mark.volleyMod or require(Client.Gameplay.Actions.VolleyOpportunity)
	local ev = Mark.volleyMod.GetEvaluation(character)
	if landed and not a.jumped and CFG.FlickAutoJump ~= false then
		local gameLeft = ev and ev.ApproachSeconds
		if (gameLeft and gameLeft <= CFG.AerialJumpLead) or left <= CFG.AerialJumpLead then
			a.jumped = Mark.doJump("aerial")
			a.jumpAt = now
			logFile("aerial", "jump", tostring(a.jumped), "left", string.format("%.2f", left), "approach", gameLeft and string.format("%.2f", gameLeft) or "-")
		end
	end
	if charging or Mark.flick.IsWindingUp(LocalPlayer) or left > 0.5 then
		return
	end
	local rising = hum and BicycleKick.IsRisingInJump(character, hum)
	local bike = hum and BicycleKick.CanBicycleKick(character, hum)
	-- plain volley only as the last chance (rise already spent, ball about to arrive)
	local ready = ev ~= nil and (bike or (a.jumped and not rising and left < 0.12))
	if not ready then
		if not a.waitLog or now - a.waitLog > 0.15 then
			a.waitLog = now
			logFile("aerial", "wait", "ev", tostring(ev ~= nil), "approach", ev and string.format("%.2f", ev.ApproachSeconds or -1) or "-", "miss", ev and string.format("%.1f", ev.MissAngleDegrees or -1) or "-", "rising", tostring(rising), "bike", tostring(bike), "left", string.format("%.2f", left))
		end
		return
	end
	if CFG.FlickAutoKick == false then
		return -- the player kicks; the aim stays locked on the solved shot
	end
	local input = Controls.CreateInput("Kick")
	local started = ChargedKick.HandleInputBegan(input, false) and ChargedKick.IsCharging()
	if started then
		a.input = input
		a.pressAt = now
		Mark.shotLockUntil = now + 1.2
	end
	logFile("aerial", "press", started and "ok" or "no", "bike", tostring(bike), "approach", string.format("%.2f", ev.ApproachSeconds or -1), "miss", string.format("%.1f", ev.MissAngleDegrees or -1), "left", string.format("%.2f", left), "aim", Shoot.aim and fmtV(Shoot.aim.Direction) or "-")
end

Mark.agentHold = function(on, why)
	Mark.sprint = Mark.sprint or require(Client.Gameplay.Player.Sprint)
	Mark.sprintMod = Mark.sprintMod or require(Modules.Actions.Sprint)
	local ch = LocalPlayer.Character
	if on then
		if not Mark.agentSprinting and ch then
			-- remember the character's own IsSprinting attribute; only GoalkeeperActions ever writes it in the game, the
			-- client Sprint loop never sets it back, so forcing false on release left it false (slow, no sprint)
			Mark.sprintAttrPrev = ch:GetAttribute(Mark.sprintMod.Constants.IsSprintingAttribute)
		end
		Mark.agentSprinting = true
		Mark.sprint.SetUnlimitedStamina("MoveAgent", true)
		Mark.sprintMod.SetUnlimitedStamina(LocalPlayer, "MoveAgent", true)
		Mark.sprintMod.SetCharacterIsSprinting(LocalPlayer, true)
		if why ~= "block" and why ~= "dribble" and why ~= "dodge" and ch and Mark.sprintMod.SetDodgeBoost then
			local now = Workspace:GetServerTimeNow()
			local want = now + 0.4
			local boostUntil = Mark.sprintMod.GetDodgeBoostUntil and Mark.sprintMod.GetDodgeBoostUntil(ch)
			if type(boostUntil) ~= "number" or boostUntil < want then
				Mark.sprintMod.SetDodgeBoost(ch, want, 1.08)
			end
		end
	else
		Mark.sprint.SetUnlimitedStamina("MoveAgent", false)
		Mark.sprintMod.SetUnlimitedStamina(LocalPlayer, "MoveAgent", false)
		if Mark.agentSprinting then
			Mark.agentSprinting = false
			-- restore what the attribute was before the agent, or the live client sprint state
			local want = Mark.sprintAttrPrev
			if want == nil then
				want = Mark.sprint.IsSprinting and Mark.sprint.IsSprinting() or false
			end
			Mark.sprintMod.SetCharacterIsSprinting(LocalPlayer, want == true or (Mark.sprint.IsSprinting and Mark.sprint.IsSprinting()))
		end
		if Mark.sprint.RestoreStamina then
			Mark.sprint.RestoreStamina(1)
		end
	end
end

-- Oil Spill (ItemIds.OilSpill). Server streams patches as {Id, Position, TeamName, ExpiresAt} (OilSpill.PatchFields)
-- on Items/OilPatches (gen, patches) and Items/Effect (Kind OilPatchesCheckpoint/Snapshot/Remove/Clear). HazardZoneKind
-- "Oil": the stun zone is resolved server-side, its radius is NOT in the client dump -> taken from the Puddle VFX
-- template extents (fallback 3.5). Patches of our own team are assumed harmless (puddle tinted by TeamName).
Mark.oil = {}
Mark.oilRadius = function()
	if Mark.oilR then
		return Mark.oilR
	end
	-- the stun zone is server-side (HazardZoneKind "Oil"); best client proxy is the Puddle VFX footprint: the largest
	-- flat BasePart / Attachment-emitter extent under the template. Logged so the radius can be checked in game.
	local r, how = CFG.OilRadius or 4, "cfg"
	pcall(function()
		local t = game:GetService("ReplicatedStorage").VFX.Items["Oil Spill"].Puddle
		local best = 0
		local info = {}
		for _, d in t:GetDescendants() do
			if d:IsA("BasePart") then
				best = math.max(best, math.max(d.Size.X, d.Size.Z) * 0.5)
				info[#info + 1] = d.ClassName .. string.format("%.1fx%.1f", d.Size.X, d.Size.Z)
			elseif d:IsA("ParticleEmitter") then
				local sz = d.Size.Keypoints
				local m = 0
				for _, kp in sz do
					m = math.max(m, kp.Value)
				end
				info[#info + 1] = "PE" .. string.format("%.1f", m)
			end
		end
		logFile("oil template", t.ClassName, table.concat(info, ","))
		if best > 1 then
			r, how = math.clamp(best, 2, 9), "part"
		end
	end)
	Mark.oilR = r
	logFile("oil radius", string.format("%.2f", r), how)
	return r
end
Mark.oilAdd = function(list)
	if type(list) ~= "table" then
		return
	end
	local ours = ActorTeams.GetActorTeamName(LocalPlayer)
	for _, p in list do
		if type(p) == "table" then
			local id, pos, team, exp = p[1], p[2], p[3], p[4]
			if id ~= nil and typeof(pos) == "Vector3" and type(exp) == "number" then
				if team == nil or team ~= ours then
					Mark.oil[id] = { pos = pos, exp = exp }
				end
			end
		end
	end
end
Mark.oilRemove = function(list)
	if type(list) ~= "table" then
		return
	end
	for _, p in list do
		local id = type(p) == "table" and p[1] or p
		if id ~= nil then
			Mark.oil[id] = nil
		end
	end
end
pcall(function()
	Remotes.Get("Items", "OilPatches").OnClientEvent:Connect(function(_, patches)
		Mark.oilAdd(patches)
	end)
end)
-- live patches near a point, expired ones dropped (server clock)
Mark.oilNear = function(pos, range)
	local now = Workspace:GetServerTimeNow()
	local out = nil
	for id, p in Mark.oil do
		if p.exp <= now then
			Mark.oil[id] = nil
		elseif flat(p.pos - pos).Magnitude <= range then
			out = out or {}
			out[#out + 1] = p.pos
		end
	end
	return out
end
-- Covered stretch of our flat path: patches merge into one run when their discs overlap along the ray. Returns the
-- first run {enter, exit} within `ahead` studs, or nil.
Mark.oilAhead = function(pos, dir, ahead)
	local R = Mark.oilRadius() + 0.3 -- a fat margin merged separate puddles into one "too long to jump" run
	local list = Mark.oilNear(pos, ahead + R + 30)
	if not list then
		return nil
	end
	local spans = {}
	for _, c in list do
		local rel = flat(c - pos)
		local along = rel:Dot(dir)
		local lat = (rel - dir * along).Magnitude
		if lat < R then
			local h = math.sqrt(R * R - lat * lat)
			if along + h > 0 then
				spans[#spans + 1] = { math.max(0, along - h), along + h }
			end
		end
	end
	if #spans == 0 then
		return nil
	end
	table.sort(spans, function(x, y)
		return x[1] < y[1]
	end)
	local enter, exit = spans[1][1], spans[1][2]
	if enter > ahead then
		return nil
	end
	for i = 2, #spans do
		if spans[i][1] <= exit + 0.5 then
			exit = math.max(exit, spans[i][2])
		else
			break
		end
	end
	return { enter = enter, exit = exit }
end
-- Jump flight: Movement.Jump with the humanoid jump height, workspace gravity. Airtime = 2*sqrt(2h/g).
Mark.jumpAir = function()
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local h = (hum and hum.UseJumpPower == false and hum.JumpHeight) or (hum and (hum.JumpPower ^ 2) / (2 * Workspace.Gravity)) or 7.2
	if h < 1 then
		h = Mark.jumpH or 7.2
	end
	return 2 * math.sqrt(2 * h / Workspace.Gravity)
end
-- Movement filter used by moveSteer. Free to jump (ball not ours): hop the whole covered run only when the jump
-- covers it with margin, taking off so the run sits in the middle of the flight; a run longer than the jump is walked
-- around. Own ball (no jump) / dribble: bend around it, or stop when every side is covered.
-- Enemy landmines (PlaceDownPlacement.Configs.landmines): placed models live in workspace.Misc.Items with
-- PlacedItemId == "landmines" (the same container as barricades). Nothing in the client says which team owns one - the
-- stripes are tinted from the LOCAL player's team - so a mine is skipped only when one of its attributes names our team /
-- one of our team's userIds (attributes are logged once per mine to find the key). Trigger radius is server-side:
-- half the model's footprint + CFG.MineMargin (2.5).
Mark.mineCache = nil
Mark.mines = function()
	local now = os.clock()
	local c = Mark.mineCache
	if c and now - c.at < 0.25 then
		return c.list
	end
	local list = {}
	local world = workspace:FindFirstChild("Misc")
	world = world and world:FindFirstChild("Items")
	if world then
		local ours = ActorTeams.GetActorTeamName(LocalPlayer)
		Mark.mineSeen = Mark.mineSeen or setmetatable({}, { __mode = "k" })
		for _, inst in world:GetChildren() do
			if inst:GetAttribute("PlacedItemId") == "landmines" then
				local friendly = false
				local attrs = inst:GetAttributes()
				-- owner: the PlacedModelEntrance packet (PlacerUserId by EntranceId). Mines placed before the script ran have
				-- no record: they stay hostile (a detour is cheaper than the stun)
				local entrance = inst:GetAttribute("PlacementEntranceId")
				local placer = entrance ~= nil and Mark.mineOwner and Mark.mineOwner[entrance]
				if type(placer) == "number" then
					local pl = placer == LocalPlayer.UserId and LocalPlayer or playerOf(placer)
					friendly = pl ~= nil and (pl == LocalPlayer or sameTeam(pl))
				end
				if not Mark.mineSeen[inst] then
					Mark.mineSeen[inst] = true
					local ks = {}
					for k, v in attrs do
						ks[#ks + 1] = tostring(k) .. "=" .. tostring(v)
					end
					logFile("mine seen", fmtV(inst:GetPivot().Position), "friendly", tostring(friendly), "owner", tostring(placer), table.concat(ks, ","))
				end
				if not friendly then
					local okE, size = pcall(function()
						return inst:GetExtentsSize()
					end)
					local r = okE and typeof(size) == "Vector3" and math.max(size.X, size.Z) * 0.5 or 2
					list[#list + 1] = { pos = inst:GetPivot().Position, r = r + (CFG.MineMargin or 2.5), model = inst }
				end
			end
		end
	end
	Mark.mineCache = { at = now, list = list }
	return list
end

-- distance along dir (within `ahead`) where the straight path first comes within a mine's radius, or nil
Mark.mineAhead = function(pos, dir, ahead)
	local list = Mark.mines()
	if #list == 0 then
		return nil
	end
	local best = nil
	for _, m in list do
		local rel = flat(m.pos - pos)
		local along = rel:Dot(dir)
		if along > -m.r and along < ahead + m.r then
			local lat = (rel - dir * along).Magnitude
			if lat < m.r then
				local enter = math.max(along - math.sqrt(m.r * m.r - lat * lat), 0)
				if enter <= ahead and (not best or enter < best) then
					best = enter
				end
			end
		end
	end
	return best
end

Mark.mineDir = function(root, dir)
	local fd = unitOrNil(flat(dir))
	if not fd or #Mark.mines() == 0 then
		return dir
	end
	local hum = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if hum and not CharacterControllers.IsLanded(root.Parent, hum) then
		return dir
	end
	local speed = math.max(flat(root.AssemblyLinearVelocity).Magnitude, 16)
	local look = speed * 0.7 + 2
	if not Mark.mineAhead(root.Position, fd, look) then
		return dir
	end
	for _, a in { 25, -25, 50, -50, 80, -80, 110, -110 } do
		local r = math.rad(a)
		local cand = Vector3.new(fd.X * math.cos(r) - fd.Z * math.sin(r), 0, fd.X * math.sin(r) + fd.Z * math.cos(r))
		if not Mark.mineAhead(root.Position, cand, look) then
			if not Mark.mineLog or os.clock() - Mark.mineLog > 0.6 then
				Mark.mineLog = os.clock()
				logFile("mine avoid", a)
			end
			return cand * dir.Magnitude
		end
	end
	return dir
end

Mark.oilDir = function(root, dir, mode)
	if not next(Mark.oil) then
		return dir
	end
	local fd = unitOrNil(flat(dir))
	if not fd then
		return dir
	end
	-- one timed hop, then just run: no second jump, no swerve while airborne or right after the hop (user: it
	-- jumped 2-3 times and did nonsense)
	local hum = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	if hum and not CharacterControllers.IsLanded(root.Parent, hum) then
		return dir
	end
	if os.clock() - (Mark.oilJumpAt or 0) < 0.9 then
		return dir
	end
	local speed = math.max(flat(root.AssemblyLinearVelocity).Magnitude, 16)
	local look = speed * 0.7
	local run = Mark.oilAhead(root.Position, fd, look)
	if not run then
		return dir
	end
	local own = liveOwnerId() == LocalPlayer.UserId
	if not own and mode ~= "dribble" then
		local air = Mark.jumpAir()
		local reach = speed * air * 0.85 - 1.0 -- landing margin
		local len = run.exit - run.enter
		if len <= reach then
			-- take off so the run is centred in the flight; ping delay eats ~speed*ping of run-up
			local takeoff = (reach - len) * 0.5
			local lead = speed * (LocalPlayer:GetNetworkPing() * 0.5 + 0.03)
			if run.enter <= takeoff + lead then
				if run.enter >= 0.2 and Mark.doJump("oil") then
					Mark.oilJumpAt = os.clock()
					logFile("oil hop", "enter", string.format("%.1f", run.enter), "len", string.format("%.1f", len), "reach", string.format("%.1f", reach))
				end
				if run.enter >= 0.2 then
					return dir
				end
			else
				return dir -- keep running, the hop point is still ahead
			end
		end
	end
	for _, a in { 30, -30, 55, -55, 80, -80, 110, -110 } do
		local r = math.rad(a)
		local cand = Vector3.new(fd.X * math.cos(r) - fd.Z * math.sin(r), 0, fd.X * math.sin(r) + fd.Z * math.cos(r))
		if not Mark.oilAhead(root.Position, cand, look) then
			if not Mark.oilLog or os.clock() - Mark.oilLog > 0.5 then
				Mark.oilLog = os.clock()
				logFile("oil avoid", mode or "-", a, "run", string.format("%.1f-%.1f", run.enter, run.exit))
			end
			return cand * dir.Magnitude
		end
	end
	return Vector3.zero
end

-- Debug rings: every live enemy patch within 60 studs, radius = the model radius, so the zone can be checked in game.
Mark.drawOil = function(root)
	Mark.oilLines = Mark.oilLines or makeLines(160, 1.2, 22)
	Mark.oilPool = Mark.oilPool or Mark.segPool(Mark.oilLines)
	local pool = Mark.oilPool
	if CFG.Draw and CFG.DrawHazards ~= false and next(Mark.oil) and Workspace.CurrentCamera then
		local list = Mark.oilNear(root.Position, 60)
		if list then
			local R = Mark.oilRadius()
			local col = Color3.fromRGB(190, 120, 255)
			for n = 1, math.min(#list, 20) do
				local c = list[n]
				local prev = nil
				for k = 0, 8 do
					local a = k / 8 * math.pi * 2
					local p = Vector3.new(c.X + math.cos(a) * R, c.Y + 0.1, c.Z + math.sin(a) * R)
					if prev then
						pool.seg(prev, p, col, 0.8, 1.2, 22)
					end
					prev = p
				end
			end
		end
	end
	pool.finish()
end

-- User's own steering intent, independent of the agent's move override: PlayerModule controls (keyboard / pad /
-- touch) in camera space -> flat world; WASD fallback.
Mark.userInputDir = function()
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local mv = nil
	pcall(function()
		if Mark.ctrls == nil then
			local pm = LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
			Mark.ctrls = pm and require(pm):GetControls() or false
		end
		if not Mark.ctrls then
			return
		end
		mv = Mark.ctrls:GetMoveVector()
	end)
	if not (mv and mv.Magnitude > 0.1) then
		local UIS = game:GetService("UserInputService")
		local x, z = 0, 0
		if UIS:IsKeyDown(Enum.KeyCode.W) then z -= 1 end
		if UIS:IsKeyDown(Enum.KeyCode.S) then z += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.A) then x -= 1 end
		if UIS:IsKeyDown(Enum.KeyCode.D) then x += 1 end
		mv = Vector3.new(x, 0, z)
	end
	if mv.Magnitude < 0.1 then
		return nil
	end
	local f = unitOrNil(flat(cam.CFrame.LookVector))
	local r = unitOrNil(flat(cam.CFrame.RightVector))
	if not (f and r) then
		return nil
	end
	return unitOrNil(r * mv.X - f * mv.Z)
end

-- Instant sidestep used by the hazard dodges (same displacement path as the slide dodge: root CFrame + guard).
-- One place for every sidestep. DodgeTeleport: the old instant step (CFrame + displacement guard). Off: no CFrame write,
-- the agent walks that way for the time the step would have taken (moveSteer "dodge", stopped by moveTick).
Mark.stepAway = function(root, step, why, stream)
	if CFG.DodgeTeleport ~= false then
		root.CFrame = root.CFrame + step
		LocalMovementGuard.RegisterDisplacement(root, step)
		if stream then
			CharacterMotion.SetStreamVelocity(root.Parent, root.AssemblyLinearVelocity)
		end
		return true
	end
	local dir = unitOrNil(flat(step))
	if not dir then
		return false
	end
	Mark.walkOff = { untilT = os.clock() + math.clamp(step.Magnitude / 20, 0.2, 0.6) }
	Mark.moveSteer(dir, "dodge")
	logFile("step walk", why or "-", fmtV(step))
	return false
end

Mark.hazardStep = function(root, step, why)
	Mark.stepAway(root, step, why, true)
	logFile("hazard step", why, fmtV(step))
end

-- Kick charge dodge (no ball, or ball with the dribble unavailable). Exit the HitboxSettings.Kick box through the
-- nearest face whose direction does not go back against the user's own movement (or facing when idle). Exit within
-- 5 studs -> instant step; otherwise leave it.
Mark.tickKickDodge = function(root, own)
	if not CFG.AutoDodge or os.clock() - (Mark.kickDodgeAt or 0) < 0.9 then
		return
	end
	local kt = Mark.kickThreat(root)
	if not (kt and kt.inside and kt.open and kt.aimed) then
		return
	end
	if own then
		if ClientDodge.IsDribbling() then
			return
		end
		-- With the ball the dribble owns the kick. A step (teleport) only when the dribble is still on cooldown at the EARLIEST
		-- release (min charge): if it frees up before that, wait and dribble (the dribble branch fires as soon as it is ready).
		local left = Mark.dribbleLeft()
		local pingK = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
		local rMinK = math.max(kt.minRel - kt.elapsed, 0)
		if left <= 0 or left + pingK * 0.5 + 0.03 <= rMinK then
			if left > 0 and (not Mark.kickWaitLog or os.clock() - Mark.kickWaitLog > 0.5) then
				Mark.kickWaitLog = os.clock()
				logFile("hazard kick", "wait dribble", "cdLeft", string.format("%.2f", left), "release in", string.format("%.2f", rMinK))
			end
			return
		end
		logFile("hazard kick", "dribble cd at release", Mark.dribbleBlock or "cd", "cdLeft", string.format("%.2f", left), "release in", string.format("%.2f", rMinK))
	end
	local k = HitboxSettings.Kick
	local cf = kt.aimed.CFrame * k.CFrameOffset
	-- geometry from the point that was tested (root + velocity * lead): taking the exit distances from the current
	-- root gave negative distances ("no-forward-exit -4.6,4.8") and a step the wrong way
	local lp = cf:PointToObjectSpace(Vector3.new(kt.us.X, root.Position.Y, kt.us.Z))
	local hx, hz = k.Size.X * 0.5, k.Size.Z * 0.5
	local u = Mark.userInputDir() or unitOrNil(flat(root.AssemblyLinearVelocity)) or unitOrNil(flat(root.CFrame.LookVector))
	local opts = {
		{ d = hx - lp.X + 0.8, v = cf.RightVector },
		{ d = hx + lp.X + 0.8, v = -cf.RightVector },
		{ d = hz - lp.Z + 0.8, v = -cf.LookVector }, -- back face (+Z, toward him)
		{ d = hz + lp.Z + 0.8, v = cf.LookVector }, -- front face (-Z, along the kick)
	}
	local best = nil
	for _, o in opts do
		local v = unitOrNil(flat(o.v))
		if v and o.d > 0.2 and o.d <= 5.2 and (not u or v:Dot(u) >= -0.4) then
			if not best or o.d < best.d then
				best = { d = o.d, v = v }
			end
		end
	end
	if best then
		Mark.kickDodgeAt = os.clock()
		Mark.hazardStep(root, best.v * best.d, "kick " .. actorName(kt.actor))
	elseif not Mark.kickDodgeLog or os.clock() - Mark.kickDodgeLog > 0.5 then
		Mark.kickDodgeLog = os.clock()
		logFile("hazard kick", "no-forward-exit", string.format("%.1f,%.1f", lp.X, lp.Z))
	end
end

-- Sledgehammer (dump: Items.Sledgehammer). Effect "HeldItemActivate" (ItemId sledgehammer) carries StartedAt and
-- LandingSeconds: the slam lands at StartedAt + LandingSeconds after a LungeDistance 12 leap, striking at
-- GetStrikePoint = landing + 6.1 forward, 0.7 side (SlamOffset). It is a ground slam: airborne = safe. The slam radius
-- is server-side and NOT in the client dump -> CFG.HammerRadius (estimate) and every slam is logged with our
-- distance to calibrate. Response: no ball -> jump so we are in the air at the slam. Own ball (cannot jump) -> flick
-- (detach 0.4 s) then jump; too late for that -> step out of the zone.
Mark.hammers = {}
Mark.onItemActivate = function(pkt)
	local uid = pkt.UserId
	if type(uid) ~= "number" or uid == LocalPlayer.UserId then
		return
	end
	local actor = playerOf(uid)
	if actor and sameTeam(actor) then
		return
	end
	local ch = actor and Actors.GetCharacter(actor)
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	logFile("skill activate", tostring(pkt.ItemId), actorName(actor), r and string.format("d %.1f", (r.Position - (ActorTargeting.GetActorRoot(LocalPlayer) or r).Position).Magnitude) or "-", "land", tostring(pkt.LandingSeconds))
	if pkt.ItemId == "sledgehammer" and r and type(pkt.StartedAt) == "number" then
		local look = unitOrNil(flat(r.CFrame.LookVector)) or Vector3.new(0, 0, 1)
		local land = r.Position + look * 12
		local right = Vector3.new(-look.Z, 0, look.X)
		Mark.hammers[uid] = {
			slamAt = pkt.StartedAt + (tonumber(pkt.LandingSeconds) or 0.7),
			strike = land + look * 6.1 - right * 0.7,
			name = actorName(actor),
		}
	end
end

Mark.plainFlick = function()
	local now = CharacterMotionSmoothing.GetSmoothedServerTime()
	Mark.flick = Mark.flick or require(Modules.Actions.RainbowFlick)
	Mark.fx = Mark.fx or require(Client.Gameplay.Actions.TackleEffects)
	Mark.fx.PlayLocalRainbowFlick()
	ActionRemoteProtocol.Send(ActionCommands.RainbowFlick({ ShotTime = now }))
	Mark.flick.SetWindingUpUntil(LocalPlayer, now + Mark.flick.Constants.BallDetachSeconds + Mark.flick.Constants.DetachCommandGraceSeconds)
	Mark.hazardFlickAt = os.clock()
end

-- Diagnostic for "charge stays full": a charge older than MaximumChargeSeconds + 1.5 s gets one log line with
-- everything that can hold a release (volley lock / delayed release, our own kick session, dodge / facing locks).
Mark.chargeWatch = function()
	local charging = ChargedKick.IsCharging and ChargedKick.IsCharging()
	if not charging then
		Mark.chargeSeenAt = nil
		Mark.chargeWarned = nil
		return
	end
	Mark.chargeSeenAt = Mark.chargeSeenAt or os.clock()
	local held = os.clock() - Mark.chargeSeenAt
	-- Recovery: the player already let go of Kick (real input up for > 0.25 s) but the game still shows a charge and
	-- nothing of ours owns it. Re-sending HandleInputEnded does NOT release it: Shoot.HandleInputEnded only calls
	-- releaseCharge when the ended input IS the charge input (ChargedKick.IsChargeInput, identity compare), and a
	-- fresh call carries a different object, so the game returns without releasing (log: "release resent" then the
	-- charge still stuck, then "cancelled"). ReleaseFullCharge is the game's own releaseCharge handed to the charge
	-- action - it fires the shot outright, no input-identity check. One shot at it; if the charge survives (a volley
	-- delay re-armed it) cancel so it can never sit at full.
	-- The game releases a charge itself: ChargedKick.StartCharge arms task.delay(maxSeconds, ReleaseFullCharge), and a
	-- release can be delayed legitimately (DelayReleaseUntilMinimum, a volley claim waiting for arrival). The v41 fix
	-- cancelled 0.25 s after the real input went up, i.e. it killed those legitimate delayed releases (the "my shot
	-- is dropped") and every keeper FORCED CLEAR (after a catch the game holds a charge it owns and ignores input:
	-- Gameplay_Script returns on goalkeeperRole.IsForcedClearActive). Now only a charge that outlived its own
	-- auto-release by 0.9 s with the real input long up, never a forced clear, never a goalkeeper's.
	local forced = (ChargedKick.IsForcedClearCharging and ChargedKick.IsForcedClearCharging()) or MatchSettings.IsGoalkeeperCharacter(LocalPlayer.Character)
	local rk = Mark.realKick
	local maxC = KickCore.Constants.MaximumChargeSeconds or 0.4
	local dodgeT = Mark.dodgeAt or Mark.dodgeEndedAt
	local afterDodge = dodgeT and os.clock() - dodgeT < 2.5
	local function stillCharging()
		return ChargedKick.IsCharging and ChargedKick.IsCharging()
	end
	local function fireRelease()
		-- the SAME input object StartCharge stored (IsChargeInput is an identity compare). A fresh Controls.CreateInput
		-- does not release. This is releaseCharge, so the shot goes out; CancelCharge only deletes it.
		if rk and rk.input and ChargedKick.HandleInputEnded then
			pcall(ChargedKick.HandleInputEnded, rk.input)
		end
	end
	-- After a script dodge the game's own task.delay(max, ReleaseFullCharge) does not finish the charge: releaseCharge
	-- sees the ball the dodge knocked loose, marks a volley and DelayReleases until an arrival that never comes. The
	-- charge sits at full. The old fix then CancelCharge'd it (log: dodge, kick 0.06 s later, charge fix cancelled
	-- held 1.3) so the shot never existed.
	if not forced and afterDodge and stillCharging() and held > maxC + 0.2 and rk and rk.input and (not Mark.chargeFixAt or os.clock() - Mark.chargeFixAt > 0.45) then
		Mark.chargeFixAt = os.clock()
		fireRelease()
		if stillCharging() then
			pcall(function()
				Mark.volleyMod = Mark.volleyMod or require(Client.Gameplay.Actions.VolleyOpportunity)
				if Mark.volleyMod.ClearPredictedLock then
					Mark.volleyMod.ClearPredictedLock()
				end
			end)
			local inst = Mark.chargeInst and Mark.chargeInst()
			if inst and inst.SetVolleyArrivalTime then
				pcall(inst.SetVolleyArrivalTime, inst, 0)
			end
			fireRelease()
		end
		if stillCharging() and ChargedKick.CancelCharge then
			ChargedKick.CancelCharge()
			logFile("charge fix", "cancelled", string.format("held %.1f", held), "after dodge")
		else
			logFile("charge fix", "released", string.format("held %.1f", held), "after dodge")
		end
	elseif not forced and rk and rk.down == false and not Mark.volleyInput and Mark.realChargeAt and Mark.realChargeAt >= (Mark.scriptChargeAt or 0) and rk.upAt >= Mark.realChargeAt and os.clock() - rk.upAt > 0.6 and held > maxC + 0.9 and (not Mark.chargeFixAt or os.clock() - Mark.chargeFixAt > 0.5) then
		Mark.chargeFixAt = os.clock()
		fireRelease()
		if stillCharging() and ChargedKick.CancelCharge then
			ChargedKick.CancelCharge()
			logFile("charge fix", "cancelled", string.format("held %.1f", held))
		else
			logFile("charge fix", "released", string.format("held %.1f", held))
		end
	end
	if held > KickCore.Constants.MaximumChargeSeconds + 1.5 and not Mark.chargeWarned then
		Mark.chargeWarned = true
		Mark.volleyMod = Mark.volleyMod or require(Client.Gameplay.Actions.VolleyOpportunity)
		local okL, locked = pcall(Mark.volleyMod.IsLockedBy, LocalPlayer)
		logFile("charge stuck", string.format("%.1f", held), "forced", tostring(forced), "volleyLock", tostring(okL and locked), "ourVolley", tostring(Mark.volleyAt ~= nil), "ourKick", tostring(Mark.kickCmd ~= nil), "move", tostring(Mark.move and Mark.move.mode), "dodgeLock", tostring(Mark.dodgeLockOn), "rotLock", tostring(TurnControl.GetActiveAutoRotateLockName and TurnControl.GetActiveAutoRotateLockName()))
	end
end

-- Sprint "forbidden for good". Sprint.SetBlocked(source) keeps a per-source flag table (module-local u121); while any
-- source is true the sprint state never starts a sprint (canStartSprinting / isSprintBlocked). The game clears its own
-- sources in stopDribble ("Dribble"), the slide-tackle cleanup / OnVelocityReleased ("SlideTackle"), the jetpack end
-- ("Jetpack"). The agent starts and cancels dribbles / tackles from outside, so a source can outlive its action. Read
-- the table through the upvalue chain (log what is stuck) and clear only sources whose action is provably dead.
Mark.sprintWatch = function()
	local now = os.clock()
	if now - (Mark.sprintWatchAt or 0) < 0.5 then
		return
	end
	Mark.sprintWatchAt = now
	Mark.sprint = Mark.sprint or require(Client.Gameplay.Player.Sprint)
	local slideLive = ClientSlide.IsSlideTackling()
	local dribLive = ClientDodge.IsDribbling()
	local chargeLive = ChargedKick.IsCharging and ChargedKick.IsCharging()
	if slideLive or dribLive then
		Mark.sprintBusyAt = now
	end
	if now - (Mark.sprintBusyAt or 0) < 0.8 then
		return
	end
	-- diagnostic: which sources are actually set (executor debug API; silent if it is not there)
	if debug.getupvalues and not Mark.sprintWatchLogged then
		pcall(function()
			local function find(fn, want)
				for _, v in debug.getupvalues(fn) do
					if want(v) then
						return v
					end
				end
			end
			local function allBool(v)
				if type(v) ~= "table" then
					return false
				end
				for _, x in v do
					if type(x) ~= "boolean" then
						return false
					end
				end
				return true
			end
			local state = find(Mark.sprint.SetBlocked, function(v)
				return type(v) == "table" and type(v.SetBlocked) == "function"
			end)
			-- the source flags (u121) are the table of booleans among SetBlocked's upvalues; the module table the first
			-- version matched holds functions
			local blocks = state and find(state.SetBlocked, allBool)
			if blocks then
				local out = {}
				for k, v in blocks do
					if v then
						out[#out + 1] = tostring(k)
					end
				end
				if #out > 0 then
					Mark.sprintWatchLogged = true
					logFile("sprint stuck", table.concat(out, ","), "slide", tostring(slideLive), "dribble", tostring(dribLive), "charge", tostring(chargeLive))
				end
			end
		end)
	end
	-- idempotent: SetBlocked(src,false) on an unset source is a table write of nil
	Mark.sprint.SetBlocked("SlideTackle", false)
	Mark.sprint.SetBlocked("Dribble", false)
	if Mark.sprint.SetRefillBlocked then
		Mark.sprint.SetRefillBlocked("SlideTackle", false)
		Mark.sprint.SetRefillBlocked("Dribble", false)
		if not chargeLive then
			Mark.sprint.SetRefillBlocked("KickCharge", false)
		end
	end
end

-- Player-state probe. The "can't jump / can't run / charge sits at full" reports share one suspect: a block state
-- that outlived its action. Everything that gates those is listed here in one line (logged when the set changes, and
-- on H): Movement jump-state blocks (module-local table, HeldJump = jump disabled until the key is released), humanoid
-- WalkSpeed / JumpHeight / Jumping state, ActionLocks, Sprint block sources, ragdoll/stun/frozen, auto-rotate lock,
-- our own move mode, jump hold, volley/kick flags.
Mark.stateLine = function()
	local out = {}
	local function add(k, v)
		out[#out + 1] = k .. "=" .. tostring(v)
	end
	local function try(fn)
		pcall(fn)
	end
	local ch = LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	try(function()
		local ch1 = ChargedKick.IsCharging and ChargedKick.IsCharging()
		add("charge", ch1 and string.format("%.1f", os.clock() - (Mark.chargeSeenAt or os.clock())) or 0)
		add("forced", (ChargedKick.IsForcedClearCharging and ChargedKick.IsForcedClearCharging()) or false)
		add("gk", MatchSettings.IsGoalkeeperCharacter(ch))
		add("drib", ClientDodge.IsDribbling())
		add("slide", ClientSlide.IsSlideTackling())
	end)
	try(function()
		if hum then
			add("ws", string.format("%.1f", hum.WalkSpeed))
			add("jh", string.format("%.1f", hum.JumpHeight))
			add("hs", hum:GetState().Name)
			add("jumpOn", hum:GetStateEnabled(Enum.HumanoidStateType.Jumping))
			add("landed", CharacterControllers.IsLanded(ch, hum))
		end
	end)
	try(function()
		local t = Mark.jumpBlocks and Mark.jumpBlocks()
		if t then
			local keys = {}
			for k, v in t do
				if v then
					keys[#keys + 1] = tostring(k)
				end
			end
			table.sort(keys)
			add("jblock", #keys > 0 and table.concat(keys, "+") or "-")
		end
	end)
	try(function()
		local keys = {}
		for _, name in ActionLocks.LockNames do
			if ActionLocks.IsLocked(LocalPlayer, name) then
				keys[#keys + 1] = name
			end
		end
		add("locks", #keys > 0 and table.concat(keys, "+") or "-")
		add("kickBlk", ActionLocks.HasKickBlock(LocalPlayer))
		add("tackleBlk", ActionLocks.HasTackleBlock(LocalPlayer))
		add("dodgeBlk", ActionLocks.HasDodgeBlock(LocalPlayer))
	end)
	try(function()
		Mark.sprint = Mark.sprint or require(Client.Gameplay.Player.Sprint)
		Mark.sprintMod = Mark.sprintMod or require(Modules.Actions.Sprint)
		local keys = Mark.sprintBlockKeys and Mark.sprintBlockKeys() or {}
		add("sprintBlk", #keys > 0 and table.concat(keys, "+") or "-")
		add("sprinting", Mark.sprintMod.GetCharacterIsSprinting(LocalPlayer))
		add("unlimited", Mark.sprintMod.HasUnlimitedStamina(LocalPlayer))
	end)
	try(function()
		local down, left = Mark.mateDown(LocalPlayer, ch)
		add("down", down and string.format("%.1f", left) or false)
		add("rot", TurnControl.GetActiveAutoRotateLockName and TurnControl.GetActiveAutoRotateLockName() or "-")
	end)
	try(function()
		add("move", Mark.move and Mark.move.mode or "-")
		add("agentSpr", Mark.agentSprinting == true)
		add("volleyIn", Mark.volleyInput ~= nil)
		add("jumpHold", Mark.jumpHoldUntil ~= nil)
		add("slideAim", slideAim ~= nil)
	end)
	try(function()
		local attrs = {}
		for k, v in ch:GetAttributes() do
			if type(v) == "boolean" or type(v) == "number" then
				attrs[#attrs + 1] = k .. ":" .. (type(v) == "number" and string.format("%.1f", v) or tostring(v))
			end
			if #attrs >= 10 then
				break
			end
		end
		table.sort(attrs)
		add("attrs", table.concat(attrs, ","))
	end)
	return table.concat(out, " ")
end

Mark.jumpBlocks = function()
	if Mark.jumpBlockTbl then
		return Mark.jumpBlockTbl
	end
	if not debug.getupvalues then
		return nil
	end
	Mark.walk = Mark.walk or require(Client.Gameplay.Player.Movement)
	local function allBool(v)
		if type(v) ~= "table" then
			return false
		end
		for _, x in v do
			if type(x) ~= "boolean" then
				return false
			end
		end
		return true
	end
	local function search(fn, depth)
		local ups = debug.getupvalues(fn)
		for _, v in ups do
			if allBool(v) and v ~= Mark then
				return v
			end
		end
		if depth > 0 then
			for _, v in ups do
				if type(v) == "function" then
					local t = search(v, depth - 1)
					if t then
						return t
					end
				end
			end
		end
	end
	local okS, t = pcall(search, Mark.walk.SetJumpStateBlocked, 2)
	if okS and t then
		Mark.jumpBlockTbl = t
	end
	return Mark.jumpBlockTbl
end

Mark.sprintBlockKeys = function()
	if not debug.getupvalues then
		return {}
	end
	local out = {}
	local function find(fn, want)
		for _, v in debug.getupvalues(fn) do
			if want(v) then
				return v
			end
		end
	end
	local function allBool(v)
		if type(v) ~= "table" then
			return false
		end
		for _, x in v do
			if type(x) ~= "boolean" then
				return false
			end
		end
		return true
	end
	local state = find(Mark.sprint.SetBlocked, function(v)
		return type(v) == "table" and type(v.SetBlocked) == "function"
	end)
	local blocks = state and find(state.SetBlocked, allBool)
	if blocks then
		for k, v in blocks do
			if v then
				out[#out + 1] = tostring(k)
			end
		end
	end
	table.sort(out)
	return out
end

Mark.stateWatch = function(character)
	local now = os.clock()
	-- the jump command we hold for an agent jump is released here (it used to live only in the field-player half of
	-- stepLogic: a jump as keeper never let go of Movement's HeldJump block)
	if Mark.jumpHoldUntil and now > Mark.jumpHoldUntil then
		Mark.jumpHoldUntil = nil
		CharacterControllers.SetJumpCommand(character, false)
		Mark.endJump()
	end
	if now - (Mark.stateAt or 0) < 0.25 then
		return
	end
	Mark.stateAt = now
	local line = Mark.stateLine()
	-- signature without volatile fields
	local sig = line:gsub("charge=[%d%.]+", "charge=N"):gsub("move=%S+", ""):gsub("landed=%S+", ""):gsub("hs=%S+", ""):gsub("ws=%S+", ""):gsub("unlimited=%S+", ""):gsub("agentSpr=%S+", ""):gsub("sprinting=%S+", ""):gsub("slideAim=%S+", ""):gsub("jh=%S+", function(s)
		return s == "jh=0.0" and s or "jh=N"
	end):gsub("down=%S+", function(s)
		return s:match("false") and s or "down=T"
	end)
	local blk = Mark.jumpBlocks and Mark.jumpBlocks()
	local held = blk and blk.HeldJump
	if held then
		Mark.heldSince = Mark.heldSince or now
	else
		Mark.heldSince = nil
	end
	-- HeldJump stays until the jump key is released; with the key up and no agent jump pending it is stale
	if held and now - Mark.heldSince > 1.2 and not UserInputService:IsKeyDown(Enum.KeyCode.Space) and not Mark.jumpHoldUntil then
		Mark.heldSince = now
		Mark.walk = Mark.walk or require(Client.Gameplay.Player.Movement)
		if Mark.walk.ReleaseJump then
			Mark.walk.ReleaseJump()
		end
		logFile("jump unblock", "HeldJump stale, released")
	end
	if sig ~= Mark.stateSig and now - (Mark.stateLogAt or 0) > 0.4 then
		Mark.stateSig = sig
		Mark.stateLogAt = now
		logFile("state", line)
	end
end

-- ===== Blast / projectile hazards (AutoDodge) =====
-- Explosive items (bazooka, grenade) stun everyone inside ItemHitSettings.ExplosionRadius (14; ScreenShakeEffects uses it as
-- the full-amplitude radius, the server's stun rule is not in the client dump - CFG.BlastRadius / BlastMargin tune it).
-- The blast is an EVENT: where and when. Grenade: the game's own flight model (Grenade.NewFlight / GetDetonationTime /
-- GetStateAtTime with the movement world: bounces, TimeScale 0.7, countdown after the first ground contact), the
-- ProjectileMovement row's DetonatesAt overrides the time. Bazooka: ballistic path (workspace gravity) to the ground or the
-- first body on the way. Freeze gun: not a blast but a contact path (sampled), used by the chase gate.
-- Consumers: Mark.hazFlee (run out of the radius / pass the ball when we cannot), Mark.hazardGate (AutoBall never walks
-- into a zone before it fires), GetMoveCommand clamp (the player's own stick cannot carry us into it), tryTackle.
Mark.hazEv = Mark.hazEv or {}
Mark.blastR = function()
	if CFG.BlastRadius then
		return CFG.BlastRadius
	end
	local ok, m = pcall(function()
		Mark.itemHit = Mark.itemHit or require(Modules.Items.ItemHitSettings)
		return Mark.itemHit.ExplosionRadius
	end)
	return ok and type(m) == "number" and m or 14
end

Mark.hazAdd = function(st)
	local item = st.item
	if item ~= "grenade" and item ~= "bazooka" and item ~= "freezeGun" then
		return
	end
	local who = st.src and playerOf(st.src)
	if st.src == LocalPlayer.UserId or (who and sameTeam(who)) then
		return
	end
	local nowS = Workspace:GetServerTimeNow()
	local ev = nil
	if item == "grenade" then
		local ok, res = pcall(function()
			Mark.grenMod = Mark.grenMod or require(Modules.Items.Grenade)
			local _, world = Renderer.GetMovementState()
			local flight = Mark.grenMod.NewFlight(st.pos0, st.vel0, st.born)
			local tDet = Mark.grenMod.GetDetonationTime(flight, world, nil)
			if type(st.det) == "number" then
				tDet = st.det
			end
			local s = Mark.grenMod.GetStateAtTime(flight, tDet, world)
			return { kind = "blast", t = tDet, p = s.Position }
		end)
		if ok and res and typeof(res.p) == "Vector3" then
			ev = res
		end
	elseif item == "bazooka" then
		local g = st.grav or 196.2
		local dt0 = math.max(nowS - st.at, 0)
		local p = st.pos + st.vel * dt0 + Vector3.new(0, -0.5 * g * dt0 * dt0, 0)
		local v = st.vel + Vector3.new(0, -g * dt0, 0)
		Mark.fieldMod = Mark.fieldMod or require(Modules.Gameplay.FieldSettings)
		local bodies = {}
		for _, model in Actors.GetAllCharacterModels() do
			local a = Actors.GetFromCharacter(model)
			local r = a and ActorTargeting.GetActorRoot(a)
			if r and a.UserId ~= st.src then
				bodies[#bodies + 1] = r
			end
		end
		local t = 0
		while t < 4 do
			local q = p + v * t + Vector3.new(0, -0.5 * g * t * t, 0)
			local okG, gy = pcall(Mark.fieldMod.GetGroundYAt, q)
			if okG and type(gy) == "number" and q.Y <= gy + 0.8 then
				ev = { kind = "blast", t = nowS + dt0 * 0 + t, p = q }
				break
			end
			local hit = false
			for _, br in bodies do
				if flat(q - br.Position).Magnitude < 3.8 and math.abs(q.Y - br.Position.Y) < 4.5 then
					ev = { kind = "blast", t = nowS + t, p = q }
					hit = true
					break
				end
			end
			if hit then
				break
			end
			t += 0.03
		end
	else
		-- freeze gun: contact path
		local g = st.grav or 58.9
		local dt0 = math.max(nowS - st.at, 0)
		local samples = {}
		local t = 0
		while t < 2.5 do
			local tt = dt0 + t
			samples[#samples + 1] = { t = nowS + t, p = st.pos + st.vel * tt + Vector3.new(0, -0.5 * g * tt * tt, 0) }
			t += 0.05
		end
		ev = { kind = "path", samples = samples, r = HitboxSettings.Receive.Size.X * 0.5 * 1.15 + 1.2 }
	end
	if ev then
		ev.id, ev.item, ev.srcName = st.id, item, who and actorName(who) or "?"
		ev.r = ev.r or Mark.blastR()
		Mark.hazEv[st.id] = ev
		if ev.kind == "blast" then
			logFile("blast event", item, "from", ev.srcName, "in", string.format("%.2f", ev.t - nowS), "at", fmtV(ev.p), "r", string.format("%.1f", ev.r))
		end
	end
end

-- first event our position hits. posAt(tAhead) -> Vector3 (flat is taken). blasts: inside radius + margin at the blast (one-way
-- ping earlier: the server judges our pose then) or 0.2 s after it; paths: inside the contact radius at that sample's time.
Mark.hazardHits = function(posAt, tMax)
	local list = Mark.hazEv
	if not list or next(list) == nil then
		return nil
	end
	local nowS = Workspace:GetServerTimeNow()
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local margin = CFG.BlastMargin or 1.5
	for id, ev in list do
		if ev.kind == "blast" then
			local ta = ev.t - nowS
			if ta < -0.6 then
				list[id] = nil
			elseif ta <= tMax then
				for _, tt in { ta - 0.05, ta, ta + 0.2 } do
					if tt >= -0.05 then
						local pp = posAt(math.max(tt - ping * 0.5, 0))
						if flat(pp - ev.p).Magnitude < ev.r + margin then
							return ev, ta
						end
					end
				end
			end
		else
			local last = ev.samples[#ev.samples]
			if last.t < nowS - 0.3 then
				list[id] = nil
			else
				for _, s in ev.samples do
					local ta = s.t - nowS
					if ta >= 0 and ta <= tMax then
						if (posAt(math.max(ta - ping * 0.5, 0)) - s.p).Magnitude < ev.r then
							return ev, ta
						end
					end
				end
			end
		end
	end
	return nil
end

-- AutoBall: do not run into a zone / projectile corridor before it is over (the ball is not worth the stun)
Mark.hazardGate = function(root, aimP, steerT, spd)
	if not Mark.hazEv or next(Mark.hazEv) == nil then
		return nil
	end
	local O = root.Position
	local to = flat(aimP - O)
	local D = to.Magnitude
	local u = unitOrNil(to)
	if not u then
		return nil
	end
	local y = O.Y
	return Mark.hazardHits(function(t)
		local d = math.min(spd * t, D)
		return Vector3.new(O.X + u.X * d, y, O.Z + u.Z * d)
	end, 4)
end

-- run out of a blast / pass the ball when we cannot
Mark.hazFlee = function(character, root)
	local list = Mark.hazEv
	if not list or next(list) == nil then
		if Mark.move.mode == "flee" then
			Mark.moveStop("flee")
		end
		return
	end
	local nowS = Workspace:GetServerTimeNow()
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local O = flat(root.Position)
	local ourV = flat(root.AssemblyLinearVelocity)
	local margin = CFG.BlastMargin or 1.5
	local worst = nil
	for id, ev in list do
		if ev.kind == "blast" then
			local ta = ev.t - nowS
			if ta > -0.15 and ta < 3.5 then
				local d = flat(O + ourV * math.max(ta - ping * 0.5, 0) - ev.p).Magnitude
				if d < ev.r + margin and (not worst or ta < worst.ta) then
					worst = { ev = ev, ta = ta, d = d }
				end
			end
		end
	end
	if not worst then
		if Mark.move.mode == "flee" then
			Mark.moveStop("flee")
		end
		return
	end
	local ev, ta = worst.ev, worst.ta
	local d0 = flat(O - ev.p).Magnitude
	local away = unitOrNil(flat(O - ev.p)) or unitOrNil(flat(root.CFrame.LookVector)) or Vector3.new(0, 0, 1)
	local hum = character:FindFirstChildOfClass("Humanoid")
	Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
	local spd = Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(character), false) or 24
	if hum and hum.WalkSpeed > spd then
		spd = hum.WalkSpeed
	end
	local gain = spd * math.max(ta - ping * 0.5 - 0.05, 0)
	local need = ev.r + margin
	local byRun = d0 + gain >= need
	local byStep = d0 + gain + 5 >= need
	local own = liveOwnerId() == LocalPlayer.UserId
	if not ev.logged then
		ev.logged = true
		logFile("blast flee", ev.item, "ta", string.format("%.2f", ta), "d", string.format("%.1f", d0), "need", string.format("%.1f", need), "gain", string.format("%.1f", gain), "run", tostring(byRun), "step", tostring(byStep), "own", tostring(own))
	end
	-- cannot get out: give the ball to a teammate legitimately (the stun takes it otherwise)
	if own and not byRun and not ev.passed and CFG.PassAssistSync ~= false and Mark.paList and not (Mark.pa and Mark.pa.live) then
		local pick, pickSol, pickScore = nil, nil, -1
		for _, sel in Mark.paList(root) do
			local okS, sol = pcall(Mark.paSolve, sel)
			if okS and sol and not sol.contested and (sol.charge or 0.3) + ping * 0.5 + 0.03 < ta - 0.03 then
				local far = flat(sol.land - ev.p).Magnitude
				if far > pickScore then
					pick, pickSol, pickScore = sel, sol, far
				end
			end
		end
		ev.passed = true
		if pick and Mark.paPress(pick, pickSol, "blast") then
			logFile("blast pass", ev.item, "to", pick.name, "ta", string.format("%.2f", ta), "land", string.format("%.1f", pickScore))
		end
	end
	if Mark.move.mode == "dodge" or Mark.move.mode == "dribble" then
		return
	end
	if byRun or own or not byStep then
		Mark.move.look = away
		Mark.moveSteer(away, "flee")
		Mark.agentHold(true, "flee")
	end
	-- not enough by running alone: the 5-stud step (it knocks the ball loose, so never with the ball)
	if not byRun and byStep and not own and not ev.stepped and ta > 0.12 then
		ev.stepped = true
		Mark.moveSteer(away, "flee")
		Mark.hazardStep(root, away * 5, "blast")
		logFile("blast step", ev.item, "ta", string.format("%.2f", ta))
	end
end

-- the player's own stick cannot carry us into a zone that is about to go off
Mark.blastClamp = function(ch, cmd)
	local list = Mark.hazEv
	if not list or next(list) == nil or typeof(cmd) ~= "Vector3" or cmd.Magnitude < 0.2 then
		return cmd
	end
	local root = ActorTargeting.GetActorRoot(LocalPlayer)
	if not root then
		return cmd
	end
	local nowS = Workspace:GetServerTimeNow()
	local O = flat(root.Position)
	local c = flat(cmd)
	if c.Magnitude < 0.2 then
		return cmd
	end
	local cu = c.Unit
	local spd = (ch:FindFirstChildOfClass("Humanoid") and ch:FindFirstChildOfClass("Humanoid").WalkSpeed) or 24
	local margin = CFG.BlastMargin or 1.5
	local out = c
	for _, ev in list do
		if ev.kind == "blast" then
			local ta = ev.t - nowS
			if ta > 0 and ta < 3.5 then
				local rel = O - ev.p
				local d = rel.Magnitude
				local radial = rel / math.max(d, 1e-3)
				local inward = -cu:Dot(radial)
				-- outside now, and the straight run would be inside the zone when it goes off
				if d > ev.r + margin - 0.2 and inward > 0.05 and flat(O + cu * spd * ta - ev.p).Magnitude < ev.r + margin then
					out = out - radial * (out:Dot(radial) * 1) -- keep only the tangential part
					out = out + radial * 0 -- never pushed outward, the player decides how far to turn away
				end
			end
		end
	end
	if out ~= c then
		if not Mark.clampLog or os.clock() - Mark.clampLog > 1 then
			Mark.clampLog = os.clock()
			logFile("blast clamp", "stick bent away from the zone")
		end
		return Vector3.new(out.X, cmd.Y, out.Z)
	end
	return cmd
end

-- Projectiles, every frame on the live state (Mark.projLive: ProjectileStart + ProjectileMovement rows).
-- HOMING (rocketPunch, ProjectileVfx MotionKind PointHomingBall): it homes on the BALL (TargetBallId), not on us, with
-- the game's own steering ProjectileHoming.AdvancePointHoming (intercept lead, turn rate Speed/TurnRadius doubling every
-- TurnRateDoublingSeconds, x4 inside LinearTurnNearDistance). A sidestep cannot shake it (the ball moves with us). So
-- the decision is simulated with that same function, for every option:
--   keep  - the ball stays at our feet (moves with our current velocity);
--   pass  - PassAssistSync: a legit Lob (Pass.HandleInputBegan, real charge + animation, Mark.paPress) to a teammate;
--           the ball sits with us for the charge, then flies the solved lob (paSolve pts/times). Safe when the punch
--           never gets within ProjHitRadius of the ball before the teammate's arrival time and the release happens
--           before the punch reaches us.
-- If keep is hit, the safest pass (largest closest approach) is taken; no safe pass -> the old dump as a last resort.
-- STRAIGHT / BALLISTIC (bazooka, grenade, freezeGun, ...): our clearance for "stay" and 8 sidesteps of 5 studs over
-- the remaining flight, with the item's gravity and an explosion pad. Best clearance >= rad + ProjSafeMargin -> just
-- dodge (confidence high). Lower -> with the ball, pass it first (if the release fits before impact), then still step.
-- ProjHitRadius / the blast radius are NOT in the client dump: every decision is logged with its numbers ("proj ...").
Mark.projTick = function(character, root)
	Mark.hazFlee(character, root)
	local live = Mark.projLive
	if not live or next(live) == nil then
		return
	end
	local nowS = Workspace:GetServerTimeNow()
	local own = liveOwnerId() == LocalPlayer.UserId
	local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	local O = root.Position
	local ourV = flat(root.AssemblyLinearVelocity)
	for id, st in live do
		if nowS - st.at > 1.2 or nowS - st.born > 8 then
			live[id] = nil
			continue
		end
		if st.item == "grenade" or st.item == "bazooka" then
			continue -- explosives are events (Mark.hazEv / Mark.hazFlee), not a corridor
		end
		local who = st.src and playerOf(st.src)
		if st.src == LocalPlayer.UserId or (who and sameTeam(who)) or st.done then
			continue
		end
		if st.wallUntil and os.clock() < st.wallUntil then
			continue -- a wall is being placed on its path: no dodge / pass in the meantime
		end
		local dt = math.max(nowS - st.at, 0)
		if st.homing then
			if not own then
				if not st.waitLogged then
					st.waitLogged = true
					logFile("proj punch", "wait: ball not ours", "owner", tostring(liveOwnerId()))
				end
				continue
			end
			Mark.homingMod = Mark.homingMod or require(Modules.Items.ProjectileHoming)
			Mark.projVfx = Mark.projVfx or require(Modules.Items.ProjectileVfx)
			local cfg = Mark.projVfx.PredictionConfigs[st.item]
			local ball = Renderer.GetPosition()
			if not (cfg and typeof(ball) == "Vector3") then
				continue
			end
			local dir0 = st.vel.Magnitude > 0.1 and st.vel.Unit or unitOrNil(ball - st.pos) or Vector3.new(0, 0, 1)
			local hitR = CFG.ProjHitRadius or 3
			-- returns time of hit (or nil) and the closest approach, against ballFn(t) = position, velocity
			local function chase(ballFn, horizon)
				local p, d, age = st.pos, dir0, (st.at - st.born)
				-- catch up the time since the last packet first (target = where the ball is now)
				if dt > 0 then
					local b0, v0 = ballFn(0)
					p, d, age = Mark.homingMod.AdvancePointHoming(cfg, p, d, b0, v0, age, dt)
				end
				local step = 1 / 30
				local t = 0
				local closest = (p - ballFn(0)).Magnitude
				while t < horizon do
					local b, v = ballFn(t)
					p, d, age = Mark.homingMod.AdvancePointHoming(cfg, p, d, b, v, age, step)
					t += step
					local b2 = ballFn(t)
					local dd = (p - b2).Magnitude
					if dd < closest then
						closest = dd
					end
					if dd <= hitR then
						return t, closest
					end
				end
				return nil, closest
			end
			local keepFn = function(t)
				return ball + ourV * t, ourV
			end
			local tKeep, cKeep = chase(keepFn, 2.0)
			if not st.evalLogged then
				st.evalLogged = true
				logFile("proj punch", "eval", "keepHit", tKeep and string.format("%.2f", tKeep) or "none", "closest", string.format("%.1f", cKeep or -1), "dist", string.format("%.1f", (st.pos - ball).Magnitude), "spd", string.format("%.0f", st.vel.Magnitude), "age", string.format("%.2f", st.at - st.born))
			end
			if not tKeep then
				continue
			end
			-- BarricadeAddon: the punch homes on the ball we hold; a wall on its approach stops it (path = the same simulation)
			if not st.wallTried then
				local trail = {}
				do
					local p, d, age = st.pos, dir0, (st.at - st.born)
					if dt > 0 then
						local b0, v0b = keepFn(0)
						p, d, age = Mark.homingMod.AdvancePointHoming(cfg, p, d, b0, v0b, age, dt)
					end
					trail[1] = p
					local tt = 0
					while tt < tKeep + 0.2 and #trail < 90 do
						local b, vb = keepFn(tt)
						p, d, age = Mark.homingMod.AdvancePointHoming(cfg, p, d, b, vb, age, 1 / 30)
						tt += 1 / 30
						trail[#trail + 1] = p
					end
				end
				local okW, wWhy = Mark.wallVsPath(root, function(t)
					local f = t * 30
					local i = math.floor(f) + 1
					if i < 1 or i >= #trail then
						return nil
					end
					return trail[i]:Lerp(trail[i + 1], f - math.floor(f))
				end, tKeep, "rocketPunch")
				if okW == "equip" then
					st.wallUntil = os.clock() + 0.12 -- barricades coming out: hold the dodge a moment, place on the next tick
					continue
				elseif okW then
					st.wallTried = true
					st.wallUntil = os.clock() + 0.35
					continue
				elseif wWhy and (not st.wallLog or os.clock() - st.wallLog > 1) then
					st.wallLog = os.clock()
					logFile("proj wall", st.item, "no", wWhy, "keepHit", string.format("%.2f", tKeep))
				end
			end
			-- options: a lob to each teammate
			local best, bestSel, bestSol, tried = nil, nil, nil, {}
			if CFG.PassAssistSync ~= false and Mark.paList and Mark.paSolve and Mark.paPress then
				for _, sel in Mark.paList(root) do
					if #tried >= 4 then
						break
					end
					local okS, sol = pcall(Mark.paSolve, sel)
					if okS and sol and sol.pts and sol.times and #sol.pts >= 2 then
						local charge = sol.charge or 0.1
						local release = charge + ping * 0.5 + 0.03
						local pts, ts = sol.pts, sol.times
						local function lobFn(t)
							if t <= release then
								return ball + ourV * t, ourV
							end
							local tt = t - release
							for i = 2, #ts do
								if ts[i] >= tt then
									local a = (tt - ts[i - 1]) / math.max(ts[i] - ts[i - 1], 1e-3)
									local v = (pts[i] - pts[i - 1]) / math.max(ts[i] - ts[i - 1], 1e-3)
									return pts[i - 1]:Lerp(pts[i], math.clamp(a, 0, 1)), v
								end
							end
							return pts[#pts], Vector3.zero
						end
						local horizon = release + (sol.t or ts[#ts])
						local tHit, cl = chase(lobFn, math.min(horizon, 3))
						local safe = tHit == nil and release < tKeep - 0.03 and not sol.contested
						tried[#tried + 1] = string.format("%s %s cl %.1f rel %.2f%s", sel.name, safe and "SAFE" or "no", cl, release, sol.contested and " contested" or "")
						if safe and (not best or cl > best) then
							best, bestSel, bestSol = cl, sel, sol
						end
						-- no safe lob: the one that keeps the punch farthest from the ball is still a legit pass to a mate,
						-- better than the raw-packet dump (which the punch also reaches: in sim it catches a lob launched
						-- 80-120 studs away almost always; only a lob back over a far punch escaped)
						if not sol.contested and release < tKeep - 0.03 and (not st.fbCl or cl > st.fbCl) then
							st.fbCl, st.fbSel, st.fbSol = cl, sel, sol
						end
					end
				end
			end
			st.done = true
			local unsafe = false
			if not bestSel and st.fbSel then
				bestSel, bestSol, best, unsafe = st.fbSel, st.fbSol, st.fbCl, true
			end
			if Mark.pa and Mark.pa.live then
				logFile("proj", st.item, "pass already live")
			elseif bestSel and Mark.paPress(bestSel, bestSol, unsafe and "projectile-unsafe" or "projectile") then
				logFile("proj pass", unsafe and "UNSAFE" or "safe", st.item, "to", bestSel.name, "keepHit", string.format("%.2f", tKeep), "clear", string.format("%.1f", best), "tried", table.concat(tried, " | "))
			else
				local fly = ball - st.pos
				Mark.dumpBall(root, Vector3.new(-fly.Z, 0, fly.X))
				logFile("proj dump", st.item, "keepHit", string.format("%.2f", tKeep), "keepClose", string.format("%.1f", cKeep), "tried", #tried > 0 and table.concat(tried, " | ") or "no mates")
			end
		else
			if Mark.move.mode == "dribble" or (st.lastDodge and os.clock() - st.lastDodge < 0.4) then
				continue
			end
			local g = st.grav or 0
			local p0 = st.pos + st.vel * dt + Vector3.new(0, -0.5 * g * dt * dt, 0)
			local v0 = st.vel + Vector3.new(0, -g * dt, 0)
			if v0.Magnitude < 8 then
				continue
			end
			local rad = st.rad or 4
			local function clearance(off)
				local best, bestT = math.huge, 0
				local t = 0
				while t <= 1.4 do
					local p = p0 + v0 * t + Vector3.new(0, -0.5 * g * t * t, 0)
					local us = O + off + ourV * t
					local dz = math.abs(p.Y - (us.Y - 0.5))
					local d = flat(p - us).Magnitude
					if dz < 4.5 + rad * 0.5 and d < best then
						best, bestT = d, t
					end
					t += 0.03
				end
				return best, bestT
			end
			local stay, tImp = clearance(Vector3.zero)
			local margin = CFG.ProjSafeMargin or 1.0
			if stay >= rad + margin then
				continue
			end
			-- BarricadeAddon: a wall on its path instead of a dodge / pass (explosives excluded: the blast would still reach us)
			if st.item ~= "bazooka" and st.item ~= "grenade" and not st.wallTried then
				local okW, wWhy = Mark.wallVsPath(root, function(t)
					return p0 + v0 * t + Vector3.new(0, -0.5 * g * t * t, 0)
				end, tImp, st.item)
				if okW == "equip" then
					st.wallUntil = os.clock() + 0.12 -- barricades coming out: hold the dodge a moment, place on the next tick
					continue
				elseif okW then
					st.wallTried = true
					st.wallUntil = os.clock() + 0.35
					continue
				elseif wWhy and (not st.wallLog or os.clock() - st.wallLog > 1) then
					st.wallLog = os.clock()
					logFile("proj wall", st.item, "no", wWhy, "tImp", string.format("%.2f", tImp))
				end
			end
			local axis = unitOrNil(flat(v0)) or Vector3.new(0, 0, 1)
			local bestOff, bestC = nil, stay
			for k = 0, 7 do
				local a = k * math.pi / 4
				local dir = Vector3.new(axis.X * math.cos(a) - axis.Z * math.sin(a), 0, axis.X * math.sin(a) + axis.Z * math.cos(a))
				local off = dir * 5
				if not (Mark.wallHit and Mark.wallHit(O, dir, 5.5)) then
					local c = clearance(off)
					if c > bestC then
						bestOff, bestC = off, c
					end
				end
			end
			local sure = bestC >= rad + margin
			if own and not sure and CFG.PassAssistSync ~= false and Mark.paList and Mark.paPress and not (Mark.pa and Mark.pa.live) then
				-- low confidence: get rid of the ball legitimately before the impact if the lob can be released in time
				local pick, pickSol, pickD = nil, nil, -1
				for _, sel in Mark.paList(root) do
					local okS, sol = pcall(Mark.paSolve, sel)
					if okS and sol and not sol.contested and (sol.charge or 0.3) + ping * 0.5 + 0.03 < tImp then
						local dAway = flat(sol.land - (p0 + v0 * tImp)).Magnitude
						if dAway > pickD then
							pick, pickSol, pickD = sel, sol, dAway
						end
					end
				end
				if pick and Mark.paPress(pick, pickSol, "projectile") then
					logFile("proj pass", st.item, "to", pick.name, "stay", string.format("%.1f", stay), "bestStep", string.format("%.1f", bestC), "rad", string.format("%.1f", rad), "tImp", string.format("%.2f", tImp))
				end
			end
			if bestOff then
				Mark.stepAway(root, bestOff, "proj")
				st.lastDodge = os.clock()
				logFile("proj dodge", st.item, sure and "sure" or "unsure", "stay", string.format("%.1f", stay), "step", string.format("%.1f", bestC), "rad", string.format("%.1f", rad), "tImp", string.format("%.2f", tImp))
			end
		end
	end
end

Mark.tickHazard = function(character, root)
	Mark.stateWatch(character)
	Mark.chargeWatch()
	Mark.sprintWatch()
	local own = liveOwnerId() == LocalPlayer.UserId
	Mark.slideAudit(root)
	Mark.tickKickDodge(root, own)
	Mark.slideTrackTick(root)
	Mark.jumpSlideTick(character, root)
	if not CFG.AutoDodge then
		return
	end
	Mark.oilSlideTick(character, root)
	local okP, errP = pcall(Mark.projTick, character, root)
	if not okP and (not Mark.projErrAt or os.clock() - Mark.projErrAt > 3) then
		Mark.projErrAt = os.clock()
		logFile("proj err", tostring(errP))
	end
	local now = Workspace:GetServerTimeNow()
	local R = CFG.HammerRadius
	for uid, h in Mark.hammers do
		local left = h.slamAt - now
		if left < -0.4 then
			local d = flat(root.Position - h.strike).Magnitude
			logFile("skill hammer slam", h.name, "dist", string.format("%.1f", d), "air", tostring(not CharacterControllers.IsLanded(character, character:FindFirstChildOfClass("Humanoid"))))
			Mark.hammers[uid] = nil
		elseif left > -0.05 then
			local at = root.Position + flat(root.AssemblyLinearVelocity) * math.max(left, 0)
			local d = flat(at - h.strike).Magnitude
			if d <= R then
				local act = "-"
				if own then
					local flickReady = os.clock() - (Mark.hazardFlickAt or 0) > 1.5
					if flickReady and left >= 0.5 then
						Mark.plainFlick()
						act = "flick"
					elseif left < 0.5 and os.clock() - (Mark.hazardFlickAt or 0) > 1.5 and not h.stepped then
						local away = unitOrNil(flat(root.Position - h.strike)) or unitOrNil(flat(root.CFrame.LookVector))
						local need = math.min(R - d + 1, 5)
						if away and need > 0 then
							h.stepped = true
							Mark.hazardStep(root, away * need, "hammer")
							act = "step"
						end
					end
				end
				-- jump: airborne through the slam; rise ~0.27 s, so leave 0.3 s before it
				if (not own or os.clock() - (Mark.hazardFlickAt or 0) > 0.42) and left <= 0.32 and not h.jumped then
					if Mark.doJump("hammer") then
						h.jumped = true
						act = act .. "+jump"
					end
				end
				if act ~= "-" then
					logFile("skill hammer", act, h.name, "left", string.format("%.2f", left), "d", string.format("%.1f", d))
				end
			end
		end
	end
end

Mark.moveSteer = function(dir, mode, replay)
	local m = Mark.move
	m.mode = mode or m.mode or "steer"
	-- m.want is what the CALLER asked for; m.dir is that after barricade / oil deflection. moveTick re-applies the
	-- steer every frame from m.want: it used to feed the already deflected m.dir back through wallDir, so the
	-- deflection compounded frame after frame and the agent ended up running along the wall in one direction
	-- (AutoWall bug) until the next caller overwrote it.
	if not replay then
		m.want = dir
	end
	m.dir = dir
	local ch = LocalPlayer.Character
	if ch and dir then
		local face = m.look or dir
		local steerRoot = ActorTargeting.GetActorRoot(LocalPlayer)
		if Mark.wallDir and steerRoot then
			dir = Mark.wallDir(steerRoot, dir) or dir
			m.dir = dir
		end
		if steerRoot then
			dir = Mark.oilDir(steerRoot, dir, m.mode) or dir
			dir = Mark.mineDir(steerRoot, dir) or dir
			m.dir = dir
		end
		local rot = (m.mode == "dodge" or m.mode == "block")
		origSetMove(ch, dir, face, rot)
		if m.mode == "ball" or m.mode == "walk" or m.mode == "dodge" or m.mode == "dribble" or m.mode == "take" or m.mode == "block" or m.mode == "gk" or m.mode == "kick" or m.mode == "flee" then
			Mark.agentHold(true, m.mode)
		end
		if m.mode == "dodge" then
			local root = ActorTargeting.GetActorRoot(LocalPlayer)
			if root and not Mark.dodgeFaced then
				-- snap the facing and hold it with an auto-rotate lock for the whole dodge (the old one-off CFrame write
				-- was turned back at normal turn speed by TurnControl the next frame)
				local fd = unitOrNil(flat(dir))
				if fd then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + fd)
					TurnControl.LockAutoRotate("Dodge", fd)
					Mark.dodgeLockOn = true
				end
				Mark.dodgeFaced = true
			end
		end
	end
end

Mark.moveStop = function(only)
	local m = Mark.move
	if only and m.mode ~= only then
		return
	end
	local was = m.mode
	m.mode = nil
	m.dir = nil
	m.want = nil
	m.look = nil
	m.pts = nil
	local ch = LocalPlayer.Character
	if ch then
		origSetMove(ch, Vector3.zero, Vector3.zero, false)
	end
	if was == "walk" or was == "take" or was == "dodge" or was == "block" or was == "ball" or was == "gk" or was == "kick" or was == "flee" then
		Mark.agentHold(false)
	end
	if was == "block" then
		Mark.blockLogged = nil
		Mark.blockDest = nil
		Mark.blockAt = nil
		TurnControl.ReleaseAutoRotate("Aim")
		TurnControl.SetTurnSpeedFactor(1)
		logFile("block stop")
	end
	if was == "ball" then
		Mark.ballLogged = nil
		logFile("ball stop", Mark.ballStopWhy or "-")
		Mark.ballStopWhy = nil
	end
	if was == "dodge" then
		Mark.dodgeEndedAt = os.clock()
		Mark.dodgeAt = nil
		Mark.dodgeDest = nil
		Mark.dodgeSign = nil
		Mark.dodgeFrom = nil
		Mark.dodgeThreat = nil
		Mark.dodgeLogged = nil
		Mark.dodgeFaced = nil
		Mark.dodgeDone = true
		Mark.dodgeBoosted = nil
		TurnControl.ReleaseAutoRotate("Dodge")
		Mark.dodgeLockOn = nil
		Mark.dodgeDirFixed = nil
		TurnControl.SetTurnSpeedFactor(1)
	end
	if was == "dribble" then
	end
end

-- End of a dodge. It lived only in the field-player half of stepLogic; the keeper branch returns before it, so a
-- dodge taken as keeper kept steering (GetMoveCommand returns move.dir while any mode is set) and kept its facing
-- lock until the next dodge. Called from both halves; hard cap 1.4 s.
Mark.dodgeTend = function(root)
	local m = Mark.move
	if Mark.dodgeLockOn and (not m or m.mode ~= "dodge") then
		TurnControl.ReleaseAutoRotate("Dodge")
		TurnControl.SetTurnSpeedFactor(1)
		Mark.dodgeLockOn = nil
		Mark.dodgeFaced = nil
		logFile("dodge lock", "released-orphan")
	end
	if not (m and m.mode == "dodge") then
		return
	end
	if ClientDodge.IsDribbling() then
		Mark.moveStop("dodge")
		return
	end
	Mark.dodgeSteer(root, Mark.dodgeThreat or dribbleDanger)
	if Mark.move.mode == "dodge" and Mark.dodgeAt and os.clock() - Mark.dodgeAt > 1.4 then
		logFile("dodge", "timeout")
		Mark.moveStop("dodge")
	end
end

-- Where the slide box will be. rootAt(te): his root and heading at slide time te. Non-assisted: his current
-- (re-anchored) line. Assisted: the game's real homing (Mark.assistPath, rotateFlatDirectionToward toward the
-- predicted target until the hand-off) toward OUR predicted pose.
Mark.slideRootAt = function(lock, elapsed, targetAt, assisted)
	if not assisted or liveOwnerId() ~= LocalPlayer.UserId then -- the assist homes on the ball OWNER only
		return function(bt)
			return lock.origin + lock.heading * Mark.dumpTravel(bt), lock.heading
		end
	end
	local body = lock.origin + lock.heading * Mark.dumpTravel(math.max(elapsed, 0))
	return Mark.assistPath(body, lock.heading, math.max(elapsed, 0), targetAt)
end

-- posAt(sv): our pose sv seconds after NOW on the client timeline (negative = the past). The server tests the pose we
-- had `ping` ago, so slide time te maps to sv = te - elapsed - ping.
Mark.slideClearance = function(lock, elapsed, posAt, assisted, ping)
	local hb = HitboxSettings.SlideTackle
	local half = hb.Size * 0.5
	local t0 = C.HitboxDelaySeconds
	local t1 = t0 + C.HitboxSeconds
	local function targetAt(te)
		return posAt(te - elapsed - ping)
	end
	local rootAt = Mark.slideRootAt(lock, elapsed, targetAt, assisted)
	local worst = math.huge
	local te = math.max(t0, elapsed)
	while te <= t1 + 1e-4 do
		local rp, hd = rootAt(te)
		local p = targetAt(te)
		local proxy = { CFrame = CFrame.lookAt(rp, rp + hd) }
		local cf = HitboxSettings.GetCFrame(proxy, hb)
		local lp = cf:PointToObjectSpace(Vector3.new(p.X, rp.Y, p.Z))
		local c = math.max(math.abs(lp.X) - half.X, math.abs(lp.Z) - half.Z)
		if c < worst then
			worst = c
		end
		te += 0.04
	end
	if worst == math.huge then
		return 99
	end
	return worst - 1.6
end

Mark.dodgeSteer = function(root, threat)
	if ClientDodge.IsDribbling() then
		return
	end
	-- (a dodge is plain movement: it must NOT touch a charge. v39 cancelled it here - that was the "dodge resets my
	-- charge" report. The hang after a dodge came from the keeper-branch dodge never ending: see Mark.dodgeTend.)
	if not (root and threat) then
		if Mark.dodgeAt and os.clock() - Mark.dodgeAt > 0.4 then
			Mark.dodgeDone = true
			if Mark.moveStop then
				Mark.moveStop("dodge")
			end
		end
		return
	end
	local lock = slideLock[threat.character]
	if not lock and threat.actor then
		local ch = Actors.GetCharacter(threat.actor)
		lock = ch and slideLock[ch]
	end
	if not lock then
		lock = {
			heading = threat.heading,
			origin = threat.origin or (threat.root and threat.root.Position),
		}
	end
	if lock.usedDribble and ClientDodge.IsDribbling() then
		return
	end
	if Mark.dodgeDone then
		return
	end
	-- WITH THE BALL: the dribble is the answer, the dodge only when the dribble is still on cooldown AT THE IMPACT.
	-- The dribble's iframe (Dodge.ActiveSeconds 1) covering the hit is what gives the game's
	-- SuccessfulDodgeSpeedBoost (1.5 s), so: cooldown free now -> dribble now; it frees up before his box reaches us
	-- (cdLeft + ping/2 + 0.03 <= impact) -> wait and dribble then (the threat is re-read every frame); otherwise -> dodge.
	-- Impact = threat.hitIn (first time his real box contains our server pose, from Mark.slideAtUs), else the earliest
	-- possible hit from his elapsed slide time.
	if not Mark.dodgeAt and liveOwnerId() == LocalPlayer.UserId and not threat.strong then
		return -- with the ball only a strong read (his real box on our server pose) costs a dribble or a dodge
	end
	if not Mark.dodgeAt and liveOwnerId() == LocalPlayer.UserId and CFG.AutoDribble then
		local now = os.clock()
		local cdLeft = Mark.dribbleLeft()
		local elapsed0 = lock.t0 and (now - lock.t0) or (lock.elapsed or threat.elapsed or 0)
		local hitIn = threat.hitIn or math.max(C.HitboxDelaySeconds - elapsed0, 0)
		local pingD = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
		local verdict
		if cdLeft <= 0 then
			local ok, why = false, "aerial"
			if not Mark.aerial and not Mark.flickStrike then
				ok, why = tryDribble()
			end
			if ok then
				lock.handled = true
				verdict = "dribble sent"
			else
				verdict = "dribble refused " .. tostring(why)
			end
		elseif cdLeft + pingD * 0.5 + 0.03 <= hitIn then
			verdict = "wait dribble"
		end
		if verdict then
			if not Mark.ownDodgeLog or now - Mark.ownDodgeLog > 0.3 or verdict ~= Mark.ownDodgeWhy then
				Mark.ownDodgeLog, Mark.ownDodgeWhy = now, verdict
				logFile("dodge gate", verdict, "cdLeft", string.format("%.2f", cdLeft), "hitIn", string.format("%.2f", hitIn), "strong", tostring(threat.strong))
			end
			if verdict ~= "dribble refused cd" and not verdict:find("refused") then
				return
			end
		else
			logFile("dodge gate", "dodge: dribble cd at impact", "cdLeft", string.format("%.2f", cdLeft), "hitIn", string.format("%.2f", hitIn), "strong", tostring(threat.strong))
		end
	end
	local elapsed = lock.t0 and (os.clock() - lock.t0) or (lock.elapsed or threat.elapsed or 0)
	local live = root.Position
	local heading = lock.heading or Vector3.new(0, 0, 1)
	local right = Vector3.new(-heading.Z, 0, heading.X)
	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	local at = Mark.slideAtUs(lock, elapsed, root, threat.actor)
	local approach = threat.approach or (at and at.approach)
	local willHit = (at and at.fire) or threat.fire or threat.force
	local closest = (at and at.closest) or (threat.root and threat.root.Position) or live
	local lat = right:Dot(flat(live - closest))
	local along = heading:Dot(flat(live - (lock.origin or closest)))
	-- a homing (assisted) tackler is still turning toward us until the hand-off: a step now is re-aimed at. Wait until
	-- the direction is about to lock (hand-off minus ping), then step - the plan below simulates the locked heading.
	local pingD = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
	if not Mark.dodgeAt and Mark.assistOK(threat.actor) and elapsed < C.HitboxDelaySeconds - pingD - 0.05 then
		return
	end
	-- the window is over for the SERVER only after the packet and our pose have both travelled: hold until then, so
	-- control does not come back (and walk into the box) while the slide is still live there
	local slideOver = elapsed > C.HitboxDelaySeconds + C.HitboxSeconds + pingD + 0.08
	if Mark.dodgeAt and slideOver then
		Mark.dodgeDone = true
		if Mark.moveStop then
			Mark.moveStop("dodge")
		end
		return
	end
	if not Mark.dodgeAt and not willHit and not approach then
		return
	end
	if not Mark.dodgeSign then
		local side = right:Dot(flat(live - (lock.origin or live)))
		local sign = (side >= 0) and 1 or -1
		if math.abs(side + sign * 5) < math.abs(side - sign * 5) then
			sign = -sign
		end
		-- the user's own direction wins: dodging against it is undone the moment control comes back
		local u = Mark.userInputDir()
		if u and math.abs(right:Dot(u)) > 0.25 then
			sign = right:Dot(u) > 0 and 1 or -1
		end
		Mark.dodgeSign = sign
		Mark.dodgeUser = u and fmtV(u) or "-"
	end
	local sign = Mark.dodgeSign
	local dir = right * sign
	if dir.Magnitude < 0.1 then
		dir = right
	end
	-- Teleport direction by score, not just "perpendicular to his heading". Roblox interpolates our replicated CFrame
	-- from the old spot to the new one, so for the server-side hit check we sweep the whole segment: the midpoint
	-- must already be clear of the slide path, not only the end. Straight ahead along our own run is penalised (it
	-- keeps us on the line he is sliding into), straight back too; user input breaks near-ties.
	if not Mark.dodgeAt and lock and lock.heading then
		local u = Mark.userInputDir()
		local runDir = unitOrNil(flat(root.AssemblyLinearVelocity)) or u
		local best, bestS = dir, -math.huge
		local ping = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
		Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
		local vB = (Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(root.Parent), false) or 24) * 1.08
		local v0 = flat(root.AssemblyLinearVelocity)
		local assisted = Mark.assistOK(threat.actor)
		-- Each of the 16 directions is simulated against the REAL slide box over its whole hit window: our server pose
		-- (what the server tests) is the pose from `ping` ago - the old run until the step lands, then +5 studs and the
		-- dash - against a box laid along the packet heading, or, for an actor seen homing, along the heading the assist
		-- will have turned to by the hand-off. Score = clearance of the body (1.6) from the box, minimum over the window.
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local function posAt(sv)
				if sv < 0 then
					return live + v0 * sv
				end
				return live + d * (CFG.DodgeTeleport ~= false and 5 or 0) + d * (vB * sv)
			end
			local okC, clear = pcall(Mark.slideClearance, lock, elapsed, posAt, assisted, ping)
			if okC and type(clear) == "number" then
				local s = clear
				if runDir then
					local f = d:Dot(runDir)
					if f > 0.8 then
						s -= 1.2 -- keeps us on the line we run on
					elseif f < -0.8 then
						s -= 0.8
					end
				end
				-- the user's own stick breaks ties among SAFE options only (never buys an unsafe one)
				if u and s >= 0 then
					s += d:Dot(u) * 1.5
				end
				if s > bestS then
					best, bestS = d, s
				end
			end
		end
		dir = best
		Mark.dodgeDirFixed = best
		Mark.dodgeScore = bestS
	elseif Mark.dodgeAt and Mark.dodgeDirFixed then
		dir = Mark.dodgeDirFixed
	end
	if not Mark.dodgeAt then
		Mark.dodgeAt = os.clock()
		lock.handled = true
		Mark.dodgeFrom = root.Position
		if CFG.DodgeTeleport ~= false then
			local step = dir.Unit * 5
			root.CFrame = root.CFrame + step
			LocalMovementGuard.RegisterDisplacement(root, step)
			CharacterMotion.SetStreamVelocity(root.Parent, root.AssemblyLinearVelocity)
			logFile("dodge tp", "5.00", fmtV(step))
		else
			logFile("dodge walk", fmtV(dir))
		end
	end
	Mark.dodgeDest = root.Position + dir * 6
	Mark.move.pts = { Mark.dodgeFrom or root.Position, Mark.dodgeDest }
	Mark.move.born = Mark.move.born or os.clock()
	Mark.move.i = 1
	Mark.dodgeThreat = threat
	if not Mark.dodgeLogged then
		Mark.dodgeLogged = true
		logFile(
			"dodge start",
			"dir",
			fmtV(dir),
			"hit",
			willHit,
			"lat",
			string.format("%.2f", lat),
			"along",
			string.format("%.1f", along),
			"live",
			tostring(at and at.hits),
			"ghost",
			tostring(at and at.hits),
			"fut",
			tostring(at and at.fut),
			"user",
			Mark.dodgeUser or "-",
			"score",
			string.format("%.1f", Mark.dodgeScore or -1),
			"dribbleReady",
			tostring(os.clock() - lastDodgeAt >= dodgeEnforced),
			"cdLeft",
			string.format("%.1f", math.max(0, dodgeEnforced - (os.clock() - lastDodgeAt))),
			"own",
			tostring(liveOwnerId() == LocalPlayer.UserId),
			"assisted",
			tostring(Mark.assistOK(threat.actor))
		)
	end
	local holdDir = dir
	if Mark.dodgeAt and os.clock() - Mark.dodgeAt > 0.3 then
		local uIn = Mark.userInputDir()
		if uIn and lock.heading then
			-- the burst is over: give the stick back only where the box stays clear for the rest of the window
			-- (before, the whole dodge belonged to the script and control returned the moment `fire` flickered off)
			Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
			local vU = (Mark.mover.GetRunWalkSpeed(Mark.mover.GetBaseWalkSpeed(root.Parent), false) or 24)
			local pingH = math.clamp(LocalPlayer:GetNetworkPing() or 0.07, 0.02, 0.25)
			local v0h = flat(root.AssemblyLinearVelocity)
			local okH, clr = pcall(Mark.slideClearance, lock, elapsed, function(sv)
				if sv < 0 then
					return root.Position + v0h * sv
				end
				return root.Position + uIn * (vU * sv)
			end, Mark.assistOK(threat.actor), pingH)
			if okH and type(clr) == "number" and clr >= 0.8 then
				holdDir = uIn
			end
		end
	end
	if Mark.moveSteer then
		Mark.moveSteer(holdDir, "dodge")
	end
	Mark.agentHold(true, "dodge")
	if not Mark.dodgeBoosted then
		Mark.dodgeBoosted = true
		Mark.sprintMod = Mark.sprintMod or require(Modules.Actions.Sprint)
		local ch2 = LocalPlayer.Character
		if ch2 and Mark.sprintMod.SetDodgeBoost then
			local now = Workspace:GetServerTimeNow()
			local want = now + 0.2
			Mark.sprintMod.SetDodgeBoost(ch2, want, 1.08)
			logFile("dodge burst", "0.20", "1.08")
			end
			end
			end

Mark.moveTick = function(character, root)
	local m = Mark.move
	if Mark.walkOff and os.clock() >= Mark.walkOff.untilT then
		Mark.walkOff = nil
		if m and m.mode == "dodge" and not Mark.dodgeAt then
			Mark.moveStop("dodge")
		end
	end
	-- watchdog: a dodge replaced by another mode (moveSteer overwrites m.mode) never ran moveStop("dodge"), leaving
	-- the facing lock on -> stuck facing, backpedal speed, no sprint
	if Mark.dodgeLockOn and (not m or m.mode ~= "dodge") then
		TurnControl.ReleaseAutoRotate("Dodge")
		TurnControl.SetTurnSpeedFactor(1)
		Mark.dodgeLockOn = nil
		Mark.dodgeFaced = nil
		logFile("dodge lock", "released-orphan")
	end
	if not (m and m.mode and root) then
		return
	end
	if m.mode == "dribble" or m.mode == "dodge" or m.mode == "block" or m.mode == "ball" or m.mode == "kick" or (m.mode == "steer" and not m.pts) then
		if m.want or m.dir then
			Mark.moveSteer(m.want or m.dir, m.mode, true)
		end
		return
	end
	if not m.pts then
		return
	end
	local i = m.i or 1
	local nxt = m.pts[math.min(#m.pts, i + 1)]
	if not nxt then
		Mark.moveStop(m.mode)
		return
	end
	local delta = flat(nxt - root.Position)
	if delta.Magnitude < 1.5 then
		if i + 1 >= #m.pts then
			Mark.moveStop(m.mode)
			return
		end
		m.i = i + 1
		nxt = m.pts[m.i + 1]
		delta = nxt and flat(nxt - root.Position) or Vector3.zero
	end
	local dir = delta.Magnitude > 0.15 and delta.Unit or Vector3.zero
	if m.mode == "walk" or m.mode == "take" then
		Mark.agentHold(true)
	end
	local ahead = root.Position + dir * 3.2
	local up = Vector3.new(0, 5.5, 0)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local probe = false
	if dir.Magnitude > 0.2 and hum and os.clock() - (Mark.agentJump or 0) > 0.9 and os.clock() - (Mark.wallProbeAt or 0) > 0.08 then
		Mark.wallProbeAt = os.clock() -- two box sweeps over every barricade part: 12 times a second is plenty
		probe = wallBlocks(root.Position, ahead) and not wallBlocks(root.Position + up, ahead + up)
	end
	if probe and CharacterControllers.IsLanded(character, hum) then
		Mark.mover = Mark.mover or require(Modules.Actions.ActionMovement)
		if CharacterControllers.RequestJump(character, hum, Mark.mover.GetBaseJumpHeight(character)) then
			Mark.agentJump = os.clock()
		end
	end
	Mark.moveSteer(dir, m.mode)
end

Mark.agentPalette = {
	route = { Color3.fromRGB(235, 240, 255), Color3.fromRGB(120, 210, 255), Color3.fromRGB(170, 150, 255) },
	dodge = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(80, 255, 220), Color3.fromRGB(150, 120, 255) },
	dribble = { Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 110, 150), Color3.fromRGB(255, 240, 140) },
}
Mark.drawRoute = function(root, gy)
	Mark.agentLines = Mark.agentLines or makeLines(200, 1.4, 42)
	Mark.agentPool = Mark.agentPool or Mark.segPool(Mark.agentLines)
	Mark.agentPool.finish()
	hideLines(Mark.route)
	hideLines(Mark.pathInk)
	hideLines(Mark.stake)
	hideLines(Mark.ticks)
	if Mark.routeSight then
		for i = 1, #Mark.routeSight do
			Mark.routeSight[i].Visible = false
		end
	end
	Mark.needle.Visible = false
	Mark.flag.Visible = false
	Mark.spur.Visible = false
	if Mark.aimLip then
		hideLines(Mark.aimLip)
	end
	if Mark.lockRing then
		hideLines(Mark.lockRing)
	end
	local sightP = Mark.sightP
	Mark.sightP = nil
	local m = Mark.move
	if CFG.DrawRoute == false or not (m and m.pts and #m.pts >= 2 and root) then
		return
	end
	local chain = m.pts
	local y = gy + 0.06
	local col = m.mode == "dodge" and COL.Dodge or (m.mode == "dribble" and COL.Tackle or COL.Line)
	local total = 0
	for i = 2, #chain do
		total = total + flat(chain[i] - chain[i - 1]).Magnitude
	end
	if total < 0.4 then
		return
	end
	local keyP = (m.mode == "dodge" and "dodge") or (m.mode == "dribble" and "dribble") or "route"
	Mark.agentPath(Mark.agentPool.seg, chain, y, CFG.AgentPathStyle, keyP, os.clock(), col)
	local destP = chain[#chain]
	Mark.routeInk = col
	if sightP and flat(destP - sightP).Magnitude <= 3 then
		-- agent spot and tackle sight agree: keep the tackle sight, ring it with the route colour (one locked mark)
		Mark.lockRing = Mark.lockRing or makeLines(10, 1.6, 43)
		local reel = Mark.stepReel()
		local mid = (destP + sightP) * 0.5
		local r = 2.35 + reel.fastRoll * 0.06
		for i = 1, #Mark.lockRing do
			local a0 = reel.drumAng * 0.25 + (i - 1) / #Mark.lockRing * math.pi * 2
			local a1 = a0 + math.pi * 2 / #Mark.lockRing * 0.55
			Mark.lockRing[i].Thickness = 1.9
			applyLine(Mark.lockRing[i], Vector3.new(mid.X + math.cos(a0) * r, y, mid.Z + math.sin(a0) * r), Vector3.new(mid.X + math.cos(a1) * r, y, mid.Z + math.sin(a1) * r), col, 1)
		end
		Mark.agentPool.finish() -- the path above already used pool lines; without this they stayed lit next frame
		return
	end
	local key = (m.mode == "dodge" and "dodge") or (m.mode == "dribble" and "dribble") or "route"
	Mark.agentSpot(Mark.agentPool.seg, Vector3.new(destP.X, y, destP.Z), CFG.AgentSpotStyle, key, os.clock())
	Mark.agentPool.finish()
end

-- ===== new-look art ======================================================================
-- Rendering model (rewritten for cost): every shape projects its vertices ONCE (pen.P = one WorldToViewportPoint),
-- then every layer (glow / core / fill) is written from those 2D points through pen.L / pen.T. Lines go straight
-- to the Drawing object with per-property change checks, gradient colours come from a 48-step LUT (no Color3:Lerp
-- per segment), alpha is quantised to 1/24 so unchanged segments cost nothing. Ring / arc resolution follows the
-- on-screen radius (LOD). Live drawing goes through the pen.
Mark.artInit = function()
	local floor, clamp, cos, sin, abs, pi = math.floor, math.clamp, math.cos, math.sin, math.abs, math.pi
	local V2 = Vector2.new

	Mark.artPal = {
		hi = { Color3.fromRGB(90, 212, 255), Color3.fromRGB(160, 132, 255), Color3.fromRGB(110, 255, 232) },
		lo = { Color3.fromRGB(110, 255, 226), Color3.fromRGB(80, 200, 255), Color3.fromRGB(196, 242, 255) },
		curl = { Color3.fromRGB(190, 122, 255), Color3.fromRGB(255, 112, 204), Color3.fromRGB(110, 204, 255) },
		live = { Color3.fromRGB(235, 245, 255), Color3.fromRGB(120, 216, 255), Color3.fromRGB(170, 152, 255) },
		srv = { Color3.fromRGB(255, 192, 92), Color3.fromRGB(255, 122, 162), Color3.fromRGB(255, 228, 144) },
		hot = { Color3.fromRGB(255, 108, 92), Color3.fromRGB(255, 192, 72), Color3.fromRGB(255, 240, 164) },
		lime = { Color3.fromRGB(150, 255, 40), Color3.fromRGB(70, 255, 130), Color3.fromRGB(226, 255, 96) },
		limeWarn = { Color3.fromRGB(255, 214, 60), Color3.fromRGB(190, 255, 70), Color3.fromRGB(255, 238, 140) },
	}
	Mark.artGrad = function(pal, f)
		f = f % 1
		local k = f * 3
		local i = floor(k)
		local u = k - i
		u = u * u * (3 - 2 * u)
		return pal[i % 3 + 1]:Lerp(pal[(i + 1) % 3 + 1], u)
	end
	local lutCache = setmetatable({}, { __mode = "k" })
	local function artCol(pal, f)
		local l = lutCache[pal]
		if not l then
			l = {}
			for i = 0, 47 do
				l[i + 1] = Mark.artGrad(pal, i / 48)
			end
			lutCache[pal] = l
		end
		return l[floor((f % 1) * 48) + 1]
	end
	local WHITE = Color3.fromRGB(255, 255, 255)
	local INK = Color3.fromRGB(8, 10, 22)

	-- pen: nextLine() -> Line proxy or nil, nextTri(layer) -> Triangle proxy or nil
	Mark.makePen = function(nextLine, nextTri)
		local pen = {}
		pen.P = function(p)
			local v = (Mark.frameCam or Workspace.CurrentCamera):WorldToViewportPoint(p)
			return v.X, v.Y, v.Z
		end
		pen.L = function(x0, y0, d0, x1, y1, d1, col, alpha, thick, z)
			if d0 < 0.15 or d1 < 0.15 then
				return
			end
			local ln = nextLine()
			if not ln then
				return
			end
			local c, r = ln._c, ln._r
			local f, t = V2(x0, y0), V2(x1, y1)
			if c.From ~= f then
				r.From = f
				c.From = f
			end
			if c.To ~= t then
				r.To = t
				c.To = t
			end
			if c.Color ~= col then
				r.Color = col
				c.Color = col
			end
			alpha = floor(alpha * 24 + 0.5) / 24
			if c.Transparency ~= alpha then
				r.Transparency = alpha
				c.Transparency = alpha
			end
			if c.Thickness ~= thick then
				r.Thickness = thick
				c.Thickness = thick
			end
			if c.ZIndex ~= z then
				r.ZIndex = z
				c.ZIndex = z
			end
			if c.Visible ~= true then
				r.Visible = true
				c.Visible = true
			end
		end
		pen.T = function(layer, x0, y0, d0, x1, y1, d1, x2, y2, d2, col, alpha)
			if d0 < 0.15 or d1 < 0.15 or d2 < 0.15 then
				return
			end
			local tri = nextTri(layer)
			if not tri then
				return
			end
			local c, r = tri._c, tri._r
			local a, b, cc = V2(x0, y0), V2(x1, y1), V2(x2, y2)
			if c.PointA ~= a then
				r.PointA = a
				c.PointA = a
			end
			if c.PointB ~= b then
				r.PointB = b
				c.PointB = b
			end
			if c.PointC ~= cc then
				r.PointC = cc
				c.PointC = cc
			end
			if c.Color ~= col then
				r.Color = col
				c.Color = col
			end
			alpha = floor(alpha * 24 + 0.5) / 24
			if c.Transparency ~= alpha then
				r.Transparency = alpha
				c.Transparency = alpha
			end
			if c.Visible ~= true then
				r.Visible = true
				c.Visible = true
			end
		end
		return pen
	end

	-- live pen over a dedicated pool; high-water marks keep the per-frame hide pass proportional to what changed
	local lines = makeLines(520, 1.4, 42)
	local tris = {}
	for n = 1, 48 do
		tris[n] = newTri(n <= 24 and 37 or 38)
	end
	local lineI, lineHi = 1, 0
	local triI, triHi = { 1, 25 }, { 0, 24 }
	Mark.pen = Mark.makePen(function()
		local ln = lines[lineI]
		if ln then
			lineI += 1
		end
		return ln
	end, function(layer)
		layer = layer or 1
		local i = triI[layer]
		if i > (layer == 1 and 24 or 48) then
			return nil
		end
		triI[layer] = i + 1
		return tris[i]
	end)
	Mark.artFinish = function()
		for n = lineI, lineHi do
			lines[n].Visible = false
		end
		lineHi = lineI - 1
		lineI = 1
		for layer = 1, 2 do
			for n = triI[layer], triHi[layer] do
				tris[n].Visible = false
			end
			triHi[layer] = triI[layer] - 1
		end
		triI[1], triI[2] = 1, 25
	end
	Mark.artHide = function()
		Mark.artFinish()
		for n = 1, lineHi do
			lines[n].Visible = false
		end
		lineHi = 0
	end

	-- ring LOD: segments follow the on-screen radius (about 11 px per chord), clamped
	local function ringN(center, r, maxN)
		local fp = Mark.framePos
		if not fp then
			return maxN
		end
		local dist = math.max((center - fp).Magnitude, 1)
		return clamp(floor(r * (Mark.framePxK or 700) / dist * 0.55), 10, maxN)
	end
	-- scratch arrays (no allocation per frame)
	local RX, RY, RD = {}, {}, {}
	local function ringProject(pen, c, axA, axB, r, N, a0)
		for s = 0, N do
			local a = a0 + s / N * pi * 2
			RX[s], RY[s], RD[s] = pen.P(c + axA * (cos(a) * r) + axB * (sin(a) * r))
		end
	end

	-- Corner frame in an arbitrary plane (the agent-spot look): four squircle arcs, glow + gradient core, a faint
	-- filled quad behind, centre cross; never smaller than ~22 px on screen so it stays readable at 100+ studs.
	local QX, QY, QD = {}, {}, {}
	Mark.cornerFrame = function(pen, center, axA, axB, R0, pal, t, spinRate, fillAlpha, k, minPx, maxPx)
		k = k or 1
		local fp = Mark.framePos
		local R = R0
		if fp then
			local dd = math.max((center - fp).Magnitude, 1)
			local K = Mark.framePxK or 700
			R = math.max(R0, (minPx or 22) * dd / K)
			-- screen-size ceiling: R0 is in studs, so a close mark grew without limit (1.15 studs at 10 studs = ~80 px)
			if maxPx then
				R = math.min(R, maxPx * dd / K)
			end
		end
		R = R * (1 + 0.08 * sin(t * pi * 2 / 1.2))
		local spin = t * (spinRate or 0.9)
		local cs, sn = cos(spin), sin(spin)
		local span = math.rad(52)
		local CX, CY, CD = {}, {}, {}
		for q = 0, 3 do
			for s = 0, 4 do
				local a = pi / 4 + q * pi / 2 - span * 0.5 + span * s / 4
				local c, sg = cos(a), sin(a)
				local x = (c >= 0 and 1 or -1) * abs(c) ^ 0.5 * R
				local z = (sg >= 0 and 1 or -1) * abs(sg) ^ 0.5 * R
				QX[s], QY[s], QD[s] = pen.P(center + axA * (x * cs - z * sn) + axB * (x * sn + z * cs))
			end
			for s = 1, 4 do
				pen.L(QX[s - 1], QY[s - 1], QD[s - 1], QX[s], QY[s], QD[s], artCol(pal, q / 4 + s / 4 * 0.25 + t * 0.35), k, 1.6 + k, 43)
			end
			pen.L(QX[0], QY[0], QD[0], QX[2], QY[2], QD[2], pal[1], 0.26 * k * k, 4 + 4 * k, 41)
			pen.L(QX[2], QY[2], QD[2], QX[4], QY[4], QD[4], pal[1], 0.26 * k * k, 4 + 4 * k, 41)
			CX[q], CY[q], CD[q] = QX[2], QY[2], QD[2]
		end
		if fillAlpha and fillAlpha > 0 then
			pen.T(1, CX[0], CY[0], CD[0], CX[1], CY[1], CD[1], CX[2], CY[2], CD[2], pal[1], fillAlpha)
			pen.T(1, CX[0], CY[0], CD[0], CX[2], CY[2], CD[2], CX[3], CY[3], CD[3], pal[1], fillAlpha)
		end
		local mx, my, md = pen.P(center)
		local cr = clamp((R * (Mark.framePxK or 700) / math.max(md or 1, 1)) * 0.4, 1.5, 4)
		pen.L(mx - cr, my, md, mx + cr, my, md, WHITE, 0.9 * k, 1.8, 44)
		pen.L(mx, my - cr, md, mx, my + cr, md, WHITE, 0.9 * k, 1.8, 44)
	end

	-- TRAJECTORY "aurora". Glow + core ribbon in a flowing 3-colour gradient (core never dimmer than 0.8), a comet
	-- with a bright tail running the shot, tick beads, a dashed ground shadow, a small arrow at the START that
	-- points BACK toward the shooter, and a corner-frame landing mark on the goal plane. shift (Vector3) moves the
	-- start with the player while the landing stays put (the aim is re-based every frame while we move).
	local VX, VY, VD = {}, {}, {}
	local SX, SY, SD = {}, {}, {}
	Mark.trajArt = function(pen, pts, times, land, along, gy, kind, t, shift)
		local n = #pts
		if n < 2 then
			return
		end
		local pal = Mark.artPal[kind] or Mark.artPal.hi
		-- the preview keeps sampling past the goal plane: cut the ribbon at the vertex nearest the landing mark
		if typeof(land) == "Vector3" then
			local cut, best = n, math.huge
			for i = 2, n do
				local dd = (pts[i] - land).Magnitude
				if dd < best then
					best, cut = dd, i
				end
			end
			if best < 4 then
				n = cut
			end
		end
		local lens, total = { 0 }, 0
		for i = 2, n do
			total += (pts[i] - pts[i - 1]).Magnitude
			lens[i] = total
		end
		if total < 1 then
			return
		end
		local steps = clamp(floor(total / 3), 12, 32)
		local idx = 1
		for k = 0, steps do
			local d = total * k / steps
			while idx < n - 1 and lens[idx + 1] < d do
				idx += 1
			end
			local s = lens[idx + 1] - lens[idx]
			local u = s > 1e-4 and clamp((d - lens[idx]) / s, 0, 1) or 0
			local p = pts[idx]:Lerp(pts[idx + 1], u)
			if shift then
				p = p + shift * (1 - k / steps)
			end
			VX[k], VY[k], VD[k] = pen.P(p)
			if k % 2 == 0 then
				SX[k], SY[k], SD[k] = pen.P(Vector3.new(p.X, gy + 0.08, p.Z))
			end
		end
		local dur = math.max(times and times[#times] or 1, 0.45)
		local head = (t / dur) % 1.3
		local hf = math.min(head, 1)
		for k = 1, steps do
			local f = k / steps
			local behind = hf - f + 0.5 / steps
			local tail = (behind >= 0 and behind < 0.3) and (1 - behind / 0.3) or 0
			local col = artCol(pal, f * 0.8 - t * 0.25)
			pen.L(VX[k - 1], VY[k - 1], VD[k - 1], VX[k], VY[k], VD[k], col, 0.8 + 0.2 * tail, 2.1 + 1.7 * tail, 42)
			if k % 2 == 0 or tail > 0 then
				pen.L(VX[k - 1], VY[k - 1], VD[k - 1], VX[k], VY[k], VD[k], col, 0.18 + 0.24 * tail, 7.5, 41)
			end
			if k % 4 == 0 then
				pen.L(SX[k - 2], SY[k - 2], SD[k - 2], SX[k], SY[k], SD[k], col, 0.3, 1.2, 41)
			end
		end
		-- comet
		if head <= 1.02 then
			local function xyAt(hv)
				hv = clamp(hv, 0, steps)
				local k0 = floor(hv)
				local k1 = math.min(k0 + 1, steps)
				local u = hv - k0
				return VX[k0] + (VX[k1] - VX[k0]) * u, VY[k0] + (VY[k1] - VY[k0]) * u, VD[k0] + (VD[k1] - VD[k0]) * u
			end
			local hv = hf * steps
			local hx, hy, hd = xyAt(hv)
			local tx, ty, td = xyAt(hv - 0.9)
			local ux, uy, ud = xyAt(hv - 2.4)
			pen.L(tx, ty, td, hx, hy, hd, WHITE, 1, 4, 44)
			pen.L(ux, uy, ud, tx, ty, td, WHITE, 0.7, 2.6, 43)
			pen.L(tx, ty, td, hx, hy, hd, pal[1], 0.35, 9, 41)
		end
		-- start arrow: a thin chevron LYING IN THE WORLD (horizontal plane at the ball), tip pointing back toward the
		-- shooter, so it has perspective like everything else instead of facing the camera
		do
			local p0 = pts[1]
			if shift then
				p0 = p0 + shift
			end
			local fwdv = Vector3.new(pts[2].X - pts[1].X, 0, pts[2].Z - pts[1].Z)
			if fwdv.Magnitude < 0.05 then
				fwdv = Vector3.new(pts[n].X - pts[1].X, 0, pts[n].Z - pts[1].Z)
			end
			if fwdv.Magnitude > 0.05 then
				fwdv = fwdv.Unit
				local sidev = Vector3.new(-fwdv.Z, 0, fwdv.X)
				local tipx, tipy, tipd = pen.P(p0 - fwdv * 0.5)
				local w1x, w1y, w1d = pen.P(p0 + fwdv * 0.1 + sidev * 0.32)
				local w2x, w2y, w2d = pen.P(p0 + fwdv * 0.1 - sidev * 0.32)
				pen.L(tipx, tipy, tipd, w1x, w1y, w1d, pal[1], 0.7, 1.5, 43)
				pen.L(tipx, tipy, tipd, w2x, w2y, w2d, pal[1], 0.7, 1.5, 43)
				pen.L(tipx, tipy, tipd, w1x, w1y, w1d, pal[1], 0.12, 4.5, 41)
				pen.L(tipx, tipy, tipd, w2x, w2y, w2d, pal[1], 0.12, 4.5, 41)
			end
		end
		-- landing: corner frame on the goal plane + a drop line to the ground
		if typeof(land) == "Vector3" then
			local ax = (along and along.Magnitude > 0.5) and along.Unit or Vector3.new(1, 0, 0)
			if kind == "lime" or kind == "limeWarn" then
				Mark.cornerFrame(pen, land, ax, Vector3.new(0, 1, 0), 0.5, pal, t, 0.7, 0.06, 0.72, 10, 14)
			else
				Mark.cornerFrame(pen, land, ax, Vector3.new(0, 1, 0), 1.0, pal, t, 0.7, 0.1, 0.72, 15)
			end
			local lx, ly, ld = pen.P(land)
			local fx, fy, fd2 = pen.P(Vector3.new(land.X, gy + 0.08, land.Z))
			pen.L(lx, ly, ld, fx, fy, fd2, pal[1], 0.4, 1.4, 41)
		end
	end

	-- POSITIONS "phantom". FIELD PLAYER: a puzzle pair of circles. SERVER = amber ring with a flowing gradient, glow
	-- and a faint fill; LIVE = plain white ring with a glow, just inside it; when they agree the server ring hugs
	-- the live one. A running tether links them when they drift apart. GOALKEEPER: breathing corner frame at the
	-- server position + live chevron + tether.
	Mark.posArt = function(pen, live, ghost, dir, gy, isKeeper, t)
		local y = gy + 0.06
		local l = Vector3.new(live.X, y, live.Z)
		local g = Vector3.new(ghost.X, y, ghost.Z)
		local fd = (dir and dir.Magnitude > 0.05) and Vector3.new(dir.X, 0, dir.Z).Unit or Vector3.new(0, 0, 1)
		local right = Vector3.new(-fd.Z, 0, fd.X)
		local srv, lv = Mark.artPal.srv, Mark.artPal.live
		if isKeeper then
			local h = 2.5 * (1 + 0.04 * sin(t * pi * 2 / 1.4))
			for sx = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local c = g + right * (sx * h) + fd * (sz * h)
					local ax, ay, ad = pen.P(c)
					local bx, by, bd = pen.P(c - right * (sx * 1.2))
					local cx, cy, cd = pen.P(c - fd * (sz * 1.2))
					local col = artCol(srv, (sx + sz) * 0.12 + t * 0.3)
					pen.L(ax, ay, ad, bx, by, bd, col, 1, 2.2, 43)
					pen.L(ax, ay, ad, cx, cy, cd, col, 1, 2.2, 43)
					pen.L(ax, ay, ad, bx, by, bd, col, 0.2, 7, 41)
					pen.L(ax, ay, ad, cx, cy, cd, col, 0.2, 7, 41)
				end
			end
			local gx, gy2, gd = pen.P(g)
			pen.L(gx - 6, gy2, gd, gx + 6, gy2, gd, srv[1], 0.85, 1.8, 43)
			pen.L(gx, gy2 - 6, gd, gx, gy2 + 6, gd, srv[1], 0.85, 1.8, 43)
			local tip = l + fd * 1.0
			local tx, ty, td = pen.P(tip)
			local ax, ay, ad = pen.P(l - fd * 0.3 - right * 0.62)
			local bx, by, bd = pen.P(l - fd * 0.3 + right * 0.62)
			pen.L(ax, ay, ad, tx, ty, td, lv[1], 1, 2.2, 44)
			pen.L(tx, ty, td, bx, by, bd, lv[1], 1, 2.2, 44)
			pen.L(ax, ay, ad, tx, ty, td, lv[2], 0.25, 7, 41)
			pen.L(tx, ty, td, bx, by, bd, lv[2], 0.25, 7, 41)
		else
			local R = 1.0
			local apart = (g - l).Magnitude
			local lock = apart < 0.15 and (0.5 + 0.5 * sin(t * 6)) or 0
			local ex, ez = Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
			local N = ringN(g, R + 0.12, 28)
			N = N - N % 2
			-- server ring: faint fill (fan over every second ring vertex) + gradient core + glow
			local rs = R + 0.12
			ringProject(pen, g, ex, ez, rs, N, 0)
			local cx, cy, cd = pen.P(g)
			for s = 0, N - 2, 2 do
				pen.T(1, cx, cy, cd, RX[s], RY[s], RD[s], RX[s + 2], RY[s + 2], RD[s + 2], srv[1], 0.2)
			end
			for s = 1, N do
				local col = artCol(srv, s / N - t * 0.4)
				pen.L(RX[s - 1], RY[s - 1], RD[s - 1], RX[s], RY[s], RD[s], col, 0.95, 2.1 + 1.2 * lock, 43)
				if s % 2 == 0 then
					pen.L(RX[s - 2], RY[s - 2], RD[s - 2], RX[s], RY[s], RD[s], col, 0.22, 6.5, 41)
				end
			end
			-- live ring: plain white + glow
			local glowK = 0.85 + 0.15 * sin(t * 3)
			ringProject(pen, l, ex, ez, R, N, 0)
			for s = 1, N do
				pen.L(RX[s - 1], RY[s - 1], RD[s - 1], RX[s], RY[s], RD[s], WHITE, 1, 2, 44)
				if s % 2 == 0 then
					pen.L(RX[s - 2], RY[s - 2], RD[s - 2], RX[s], RY[s], RD[s], lv[2], 0.28 * glowK, 6.5, 41)
				end
			end
		end
		-- tether live -> server (edge to edge), dashes interpolated in screen space
		local d = g - l
		local m = d.Magnitude
		if m > 0.25 then
			local u = d / m
			local from = isKeeper and l or (l + u * 1.0)
			local to = isKeeper and g or (g - u * 1.12)
			if (to - from):Dot(u) > 0.1 then
				local x0, y0, d0 = pen.P(from)
				local x1, y1, d1 = pen.P(to)
				for k = 0, 5 do
					local f0 = (k + (t * 2.2) % 1) / 6
					local f1 = f0 + 0.5 / 6
					if f1 <= 1 then
						pen.L(x0 + (x1 - x0) * f0, y0 + (y1 - y0) * f0, d0 + (d1 - d0) * f0, x0 + (x1 - x0) * f1, y0 + (y1 - y0) * f1, d0 + (d1 - d0) * f1, artCol(srv, f0), 0.9, 1.6, 43)
					end
				end
			end
		end
	end

	-- TACKLE SIGHT. Three arcs like the SilentAim target ring, spinning fast, four filled arrows on the outer edge
	-- turning with them, and the slide-direction arrow when we have one. No dashed inner ring, no centre diamond.
	-- Scale barely grows with distance. Alpha stays full once shown: resetting the fade on every jitter of the
	-- slide point was the flicker.
	Mark.sightArt = function(pen, p, gy, hot, aim, t, bornOverride)
		-- fade only on a real retarget. Resetting on a 1.8-stud jitter of the slide point dropped alpha to 0
		-- every few frames (the flicker). Live stays full.
		local st = Mark.sightState
		if not st or (st.pos - p).Magnitude > 14 then
			st = { born = t, pos = p, last = t, ang = 0, vel = 5.6, dir = 1, flipAt = t + 1.2, n = 0 }
			Mark.sightState = st
		end
		local dtS = clamp(t - st.last, 0, 0.05)
		st.last, st.pos = t, p
		-- spin that reverses: the target speed flips sign every ~0.9-2 s and the real speed eases through zero
		if t >= st.flipAt then
			st.dir = -st.dir
			st.n += 1
			st.flipAt = t + 0.9 + (st.n * 0.37) % 1.1
		end
		st.vel += (st.dir * 5.6 - st.vel) * math.min(1, dtS * 6)
		st.ang += st.vel * dtS
		local e = bornOverride and clamp((t - bornOverride) / 0.2, 0, 1) or 1
		local pal = hot and Mark.artPal.hot or Mark.artPal.hi
		local spin = st.ang
		local c = Vector3.new(p.X, gy + 0.07, p.Z)
		local fp = Mark.framePos
		local sc = 1
		if fp then
			sc = clamp(1 + math.max((c - fp).Magnitude - 12, 0) / 220, 1, 1.12)
		end
		local R = 1.45 * sc
		-- three arcs, SilentAim target language (gap between them), ink under-stroke so it reads on the pitch
		for arc = 0, 2 do
			local a0 = spin + arc * (pi * 2 / 3)
			local px0, py0, pd0 = nil, nil, nil
			for s = 0, 5 do
				local ang = a0 + s / 5 * (pi * 2 / 3 * 0.72)
				local x, y, d = pen.P(c + Vector3.new(cos(ang) * R, 0, sin(ang) * R))
				if s > 0 then
					local col = artCol(pal, arc / 3 + spin / (pi * 2))
					pen.L(px0, py0, pd0, x, y, d, INK, 0.4 * e, 4.4, 40)
					pen.L(px0, py0, pd0, x, y, d, col, 0.16 * e, 7.2, 41)
					pen.L(px0, py0, pd0, x, y, d, col, e, 2.2, 44)
				end
				px0, py0, pd0 = x, y, d
			end
		end
		-- four filled arrows on the OUTER edge of the ring, pointing outward, turning with the drum
		for q = 0, 3 do
			local a = spin + q * pi / 2
			local ca, sa = cos(a), sin(a)
			local tipR, baseR, half = R * 1.5, R * 1.05, R * 0.17
			local ox, oz = ca, sa
			local px, pz = -sa, ca
			local tx, ty, td = pen.P(c + Vector3.new(ox * tipR, 0, oz * tipR))
			local w1x, w1y, w1d = pen.P(c + Vector3.new(ox * baseR + px * half, 0, oz * baseR + pz * half))
			local w2x, w2y, w2d = pen.P(c + Vector3.new(ox * baseR - px * half, 0, oz * baseR - pz * half))
			local col = artCol(pal, q / 4 + t * 0.2)
			pen.T(2, tx, ty, td, w1x, w1y, w1d, w2x, w2y, w2d, col, e)
			-- outline: dark under-stroke + glow + bright edge on all three sides
			pen.L(tx, ty, td, w1x, w1y, w1d, INK, 0.5 * e, 4.4, 40)
			pen.L(tx, ty, td, w2x, w2y, w2d, INK, 0.5 * e, 4.4, 40)
			pen.L(w1x, w1y, w1d, w2x, w2y, w2d, INK, 0.5 * e, 4.4, 40)
			pen.L(tx, ty, td, w1x, w1y, w1d, col, 0.3 * e, 7.5, 41)
			pen.L(tx, ty, td, w2x, w2y, w2d, col, 0.3 * e, 7.5, 41)
			pen.L(tx, ty, td, w1x, w1y, w1d, WHITE, 0.9 * e, 1.6, 44)
			pen.L(tx, ty, td, w2x, w2y, w2d, WHITE, 0.9 * e, 1.6, 44)
			pen.L(w1x, w1y, w1d, w2x, w2y, w2d, WHITE, 0.7 * e, 1.4, 44)
		end
		if typeof(aim) == "Vector3" and Vector3.new(aim.X, 0, aim.Z).Magnitude > 0.05 then
			local d = Vector3.new(aim.X, 0, aim.Z).Unit
			local r = Vector3.new(-d.Z, 0, d.X)
			local a = c + d * (R * 1.75)
			local b = c + d * (R * 1.75 + 1.8 * sc)
			local ax, ay, ad = pen.P(a)
			local bx, by, bd = pen.P(b)
			local h1x, h1y, h1d = pen.P(b - d * 0.55 * sc + r * 0.4 * sc)
			local h2x, h2y, h2d = pen.P(b - d * 0.55 * sc - r * 0.4 * sc)
			pen.L(ax, ay, ad, bx, by, bd, INK, 0.45 * e, 4.6, 40)
			pen.L(bx, by, bd, h1x, h1y, h1d, INK, 0.45 * e, 4.6, 40)
			pen.L(bx, by, bd, h2x, h2y, h2d, INK, 0.45 * e, 4.6, 40)
			pen.L(ax, ay, ad, bx, by, bd, pal[1], 1, 2.2, 43)
			pen.L(bx, by, bd, h1x, h1y, h1d, pal[1], 1, 2.2, 43)
			pen.L(bx, by, bd, h2x, h2y, h2d, pal[1], 1, 2.2, 43)
			local f = (t * 1.6) % 1
			local f2 = math.min(f + 0.12, 1)
			pen.L(ax + (bx - ax) * f, ay + (by - ay) * f, ad + (bd - ad) * f, ax + (bx - ax) * f2, ay + (by - ay) * f2, ad + (bd - ad) * f2, WHITE, 1, 3, 44)
		end
	end
end
Mark.artInit()

-- Agent path, same visual language as the corner spot it ends in (palette per mode, ink under-stroke, gradient that
-- flows, short bright pulses running toward the destination). style "flow" (default) or "classic" (the old chalk
-- route: ink + solid mode colour + three paper chevrons). pts are world points, drawn flat at height y.
Mark.agentPath = function(seg, pts, y, style, key, t, classicCol)
	local n = #pts
	if n < 2 then
		return
	end
	local g = {}
	local lens, total = { 0 }, 0
	for i = 1, n do
		g[i] = Vector3.new(pts[i].X, y, pts[i].Z)
		if i > 1 then
			total += (g[i] - g[i - 1]).Magnitude
			lens[i] = total
		end
	end
	if total < 0.4 then
		return
	end
	local function atDist(d)
		d = math.clamp(d, 0, total)
		for i = 2, n do
			if lens[i] >= d then
				local s = lens[i] - lens[i - 1]
				local u = s > 1e-4 and (d - lens[i - 1]) / s or 0
				return g[i - 1]:Lerp(g[i], u), (g[i] - g[i - 1])
			end
		end
		return g[n], g[n] - g[n - 1]
	end
	if style == "classic" then
		local col = classicCol or COL.Line
		for i = 1, n - 1 do
			seg(g[i], g[i + 1], COL.Ink, 0.55, 2.2, 41)
			seg(g[i], g[i + 1], col, 1, 1.45, 42)
		end
		for k = 1, 3 do
			local p, tang = atDist(total * (0.22 + (k - 1) * 0.28))
			if tang.Magnitude > 0.05 then
				local dir = tang.Unit
				local r = Vector3.new(-dir.Z, 0, dir.X)
				local tip, base = p + dir * 0.65, p - dir * 0.18
				seg(tip, base + r * 0.4, COL.Paper, 1, 1.85, 43)
				seg(tip, base - r * 0.4, COL.Paper, 1, 1.85, 43)
			end
		end
		return
	end
	local pal = Mark.agentPalette[key] or Mark.agentPalette.route
	local function grad(f)
		f = f % 1
		local k = f * 3
		local i = math.floor(k)
		return pal[i % 3 + 1]:Lerp(pal[(i + 1) % 3 + 1], k - i)
	end
	local ink = Color3.fromRGB(12, 14, 18)
	-- dock into the corner frame: the path stops at its edge instead of running through the middle
	local dock = total > 3.4 and 2.0 or 0
	local len = total - dock
	-- with the phantom position rings on, the path leaves from the ring edge (live ring r 1.0 / server ring r 1.12)
	-- instead of running through them
	local startTrim = (CFG.PosStyle == "phantom" and len > 3.5) and 1.25 or 0
	local span = len - startTrim
	local steps = math.clamp(math.floor(span / 1.4), 3, 34)
	local flowSpeed = key == "route" and 0.35 or 0.7
	local prev = atDist(startTrim)
	for i = 1, steps do
		local f1 = i / steps
		local p = atDist(startTrim + span * f1)
		local k = f1
		-- brighter and a touch thicker toward the destination, tail fades out behind us
		seg(prev, p, ink, 0.35 + 0.2 * k, 3.4, 41)
		seg(prev, p, grad(f1 * 0.9 - t * flowSpeed), 0.3 + 0.65 * k, 1.3 + 0.7 * k, 42)
		prev = p
	end
	local hot = Color3.fromRGB(255, 255, 255)
	local period = key == "route" and 1.2 or 0.7
	for q = 0, 2 do
		local f = ((t / period) + q / 3) % 1
		local a0 = atDist(startTrim + span * f)
		local a1 = atDist(startTrim + span * math.min(f + 0.07, 1))
		seg(a0, a1, hot:Lerp(grad(f), 0.35 * f), 1 - f * 0.5, 2.6, 44)
	end
end

-- One entry for every agent-spot look (live route).
-- corners: 4 corner arcs of a squircle (superellipse n = 4: a rounded square that almost reads as a circle), each
-- arc a gradient across the palette, ink under-stroke, slow spin, the radius breathes (+-8 %, 1.2 s) and snaps in a
-- little when the destination is fresh. ripple / kick: the water-drop rings, squircle or round.
Mark.agentSpot = function(seg, center, style, key, t)
	local pal = Mark.agentPalette[key] or Mark.agentPalette.route
	if style == "ripple" or style == "kick" then
		local phase = Mark.rippleStep("agent-" .. style, key == "route" and 1 / 0.7 or 1 / 0.5)
		Mark.kickRipple(seg, center, 2.2, pal, phase, t, style == "ripple" and 4 or 2)
		return
	end
	local R = 1.9 * (1 + 0.08 * math.sin(t * math.pi * 2 / 1.2))
	local spin = t * (key == "route" and 0.6 or 1.3)
	local ex = 2 / 4
	local function pt(a)
		local c, s = math.cos(a), math.sin(a)
		return center + Vector3.new((c >= 0 and 1 or -1) * math.abs(c) ^ ex * R, 0, (s >= 0 and 1 or -1) * math.abs(s) ^ ex * R)
	end
	local function grad(f)
		f = f % 1
		local k = f * 3
		local i = math.floor(k)
		local a, b = pal[i % 3 + 1], pal[(i + 1) % 3 + 1]
		return a:Lerp(b, k - i)
	end
	local ink = Color3.fromRGB(12, 14, 18)
	local N = 7
	local span = math.rad(52)
	local rot = CFrame.fromAxisAngle(Vector3.yAxis, -spin) -- one rotation per frame, not one CFrame per point
	for q = 0, 3 do
		local mid = spin + math.pi / 4 + q * math.pi / 2
		local prev = nil
		for s = 0, N do
			local a = mid - span * 0.5 + span * s / N
			local p = pt(a - spin) -- arcs sit on the squircle's corners in its own frame; the whole frame spins
			p = center + rot:VectorToWorldSpace(p - center)
			if prev then
				seg(prev, p, ink, 0.5, 3.4, 42)
				seg(prev, p, grad(q / 4 + s / N * 0.25 + t * 0.35), 0.95, 1.8, 43)
			end
			prev = p
		end
	end
	-- centre pip
	seg(center + Vector3.new(-0.18, 0, 0), center + Vector3.new(0.18, 0, 0), pal[1], 0.9, 2, 43)
	seg(center + Vector3.new(0, 0, -0.18), center + Vector3.new(0, 0, 0.18), pal[1], 0.9, 2, 43)
end

UserInputService.InputBegan:Connect(function(input, gp)
	if Controls.IsInput("Kick", input) then
		Mark.realKick = { down = true, at = os.clock(), input = input }
	end
	if Controls.IsInput("RainbowFlick", input) then
		Mark.armFlickWindow()
		if CFG.AutoFlick ~= false then
			Mark.startAerial()
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if Controls.IsInput("Kick", input) then
		Mark.realKick = { down = false, upAt = os.clock(), input = input }
	end
end)

pcall(Mark.paInstall)
dbg("boot", "drawing.new", true, "reach", CFG.TackleReach, "track", CFG.TrackStuds, "dribble", "slide-predict", "speed", CFG.TackleSpeed, "dump", "H", "corner", CFG.PreferCornerCurl, "trick", CFG.OnlyTrick)

-- perf probe wrappers: installed last, after every Mark.* function exists
for _, name in { "tickGk", "tickSkill", "tickHazard", "tickVolley", "tickBlock", "tickBall", "tickBike", "tickAerial", "tickKickDodge", "moveTick", "drawRoute", "drawOil", "drawKickBox", "kickThreat", "saDraw", "homeSlide", "ballPath", "gkOwnDive", "gkDiveSearch", "volleyPlan", "drawFlight", "drawShadow", "drawScar", "dodgeSteer", "silentArt", "trajArt", "posArt", "sightArt", "passTick", "paDraw" } do
	Mark.perfWrap(name)
end

-- ============================================================================================================
-- Syllinse loader contract (loaderv10.lua): the chunk above has already run; the loader calls this with
-- (Lib, Core), then M.start() and M.buildUI(ctx). The UI only READS / WRITES CFG, COL and Mark.artPal (all read
-- live by the script) and calls a few Mark.* actions. No new top-level locals: the chunk sits at Luau's limit.
-- No key is bound by default: every keybind below is created empty.
-- Layout: every function is one card: Enabled + the settings you touch, the rest behind its own "Show Advanced".
-- ============================================================================================================
return function(_Lib, _Core)
	local M = {}

	local FEATURES = {
		"AutoTackle", "AutoDribble", "AutoShoot", "AutoKick", "AutoGK", "AutoWall", "AgentAddon", "AutoDodge",
		"AutoBlock", "AutoBall", "CounterJump", "SilentAim", "PassAssist", "ManualTackle", "Draw",
	}

	function M.start() end

	function M.stop()
		for _, k in ipairs(FEATURES) do
			CFG[k] = false
		end
	end

	function M.buildUI(ctx)
		local uiReady = false
		local T = ctx.tabs
		-- while set, every element the helpers create is also collected here (one "Show Advanced" group)
		local cap = nil

		local function notify(title, body)
			if uiReady then
				pcall(ctx.notify, title, body)
			end
		end
		local function fl(key)
			return ctx.flag("IS_" .. key)
		end
		local function round(v, p)
			local m = 10 ^ (p or 0)
			return math.floor(v * m + 0.5) / m
		end
		local function keep(el)
			if cap and el then
				cap[#cap + 1] = el
			end
			return el
		end
		-- fresh[sec] = nothing in the card yet: its first header needs no divider, every later one gets one
		local fresh = {}
		local function card(tab, s)
			local sec = tab:Section({ Side = s })
			fresh[sec] = true
			return sec
		end
		local function head(sec, name)
			if not fresh[sec] then
				keep(sec:Divider())
			end
			fresh[sec] = false
			return keep(sec:Header({ Name = name }))
		end
		local function note(sec, text)
			return keep(sec:SubLabel({ Text = text }))
		end

		-- Enabled switch of a function. Notifies like AutoParry does.
		local function feature(sec, title, key, set)
			return sec:Toggle({
				Name = "Enabled",
				Default = CFG[key] == true,
				Callback = function(v)
					CFG[key] = v and true or false
					if set then
						set(CFG[key])
					end
					notify(title, v and "Enabled" or "Disabled")
				end,
			}, fl(key))
		end

		local function tog(sec, name, key, text, set)
			local el = keep(sec:Toggle({
				Name = name,
				Default = CFG[key] == true,
				Callback = function(v)
					CFG[key] = v and true or false
					if set then
						set(CFG[key])
					end
				end,
			}, fl(key)))
			if text then
				note(sec, text)
			end
			return el
		end

		-- o.scale: the slider shows CFG * scale (percent / ms); o.prec decimals; o.text = one short hint
		local function sld(sec, name, key, mn, mx, o)
			o = o or {}
			local sc = o.scale or 1
			local cur = CFG[key]
			if cur == nil then
				cur = mn / sc
			end
			local el = keep(sec:Slider({
				Name = name,
				Default = math.clamp(round(cur * sc, o.prec or 0), mn, mx),
				Minimum = mn,
				Maximum = mx,
				Precision = o.prec or 0,
				Suffix = o.suffix,
				Callback = function(v)
					CFG[key] = v / sc
					if o.set then
						o.set(CFG[key])
					end
				end,
			}, fl(key)))
			if o.text then
				note(sec, o.text)
			end
			return el
		end

		local function drop(sec, name, key, opts, text)
			local el = keep(sec:Dropdown({
				Name = name,
				Options = opts,
				Default = CFG[key],
				Callback = function(v)
					if type(v) == "string" and v ~= "" then
						CFG[key] = v
					end
				end,
			}, fl(key)))
			if text then
				note(sec, text)
			end
			return el
		end

		-- dropdown with a label per value: list = { { label, value }, ... }; onChange(value) for dependent controls
		local function pick(sec, name, key, list, text, onChange, current)
			local opts, byLabel, def = {}, {}, list[1][1]
			-- `current` given = the control is virtual (no CFG key of its own): onChange does the writing
			local virtual = current ~= nil
			local cur = current
			if cur == nil then
				cur = CFG[key]
			end
			if cur == nil then
				cur = true
			end
			for _, e in ipairs(list) do
				opts[#opts + 1] = e[1]
				byLabel[e[1]] = e[2]
				if e[2] == cur then
					def = e[1]
				end
			end
			local el = keep(sec:Dropdown({
				Name = name,
				Options = opts,
				Default = def,
				Callback = function(v)
					if byLabel[v] ~= nil then
						if not virtual then
							CFG[key] = byLabel[v]
						end
						if onChange then
							onChange(byLabel[v])
						end
					end
				end,
			}, fl(key)))
			if text then
				note(sec, text)
			end
			return el
		end

		-- multi dropdown over { { key, label }, ... } writing { [key] = true } of the UNCHECKED ones into CFG[banKey]
		local function typeList(sec, name, banKey, flag, items, text)
			local keyOf, opts, def = {}, {}, {}
			for _, t in ipairs(items) do
				keyOf[t[2]] = t[1]
				opts[#opts + 1] = t[2]
				if not (CFG[banKey] and CFG[banKey][t[1]]) then
					def[#def + 1] = t[2]
				end
			end
			local el = keep(sec:Dropdown({
				Name = name,
				Options = opts,
				Multi = true,
				Default = def,
				Callback = function(sel)
					local allowed = {}
					if type(sel) == "table" then
						for k, v in pairs(sel) do
							if v == true and keyOf[k] then
								allowed[keyOf[k]] = true
							elseif type(v) == "string" and keyOf[v] then
								allowed[keyOf[v]] = true
							end
						end
					end
					local ban = {}
					for _, t in ipairs(items) do
						if not allowed[t[1]] then
							ban[t[1]] = true
						end
					end
					CFG[banKey] = ban
				end,
			}, fl(flag)))
			if text then
				note(sec, text)
			end
			return el
		end

		-- keybinds are created empty (ctx.keybind passes no Default): nothing is bound until the user does it
		local function bind(sec, name, key, fn)
			return keep(ctx.keybind(sec, { Name = name, Flag = fl(key), Toggle = fn }))
		end

		local function color(sec, name, role)
			return keep(sec:Colorpicker({
				Name = name,
				Default = COL[role],
				Callback = function(c)
					COL[role] = c
				end,
			}, fl("COL_" .. role)))
		end

		-- art palettes: a 48-step LUT is cached per palette TABLE, so a colour change swaps in a new table
		local function palette(sec, kind, names)
			local pal = Mark.artPal and Mark.artPal[kind]
			if not pal then
				return
			end
			for i = 1, 3 do
				keep(sec:Colorpicker({
					Name = names[i],
					Default = pal[i],
					Callback = function(c)
						local old = Mark.artPal[kind]
						local new = { old[1], old[2], old[3] }
						new[i] = c
						Mark.artPal[kind] = new
					end,
				}, fl("PAL_" .. kind .. i)))
			end
		end

		-- Everything built inside fn() sits behind one toggle at the bottom of the card. Hidden controls keep
		-- their value and stay in the config; the toggle itself is saved too, so the card opens as you left it.
		local function advanced(sec, key, fn, label)
			local els, shown = {}, false
			local function apply()
				for _, e in ipairs(els) do
					pcall(function()
						e:SetVisibility(shown)
					end)
				end
			end
			keep(sec:Divider())
			sec:Toggle({
				Name = label or "Show Advanced Settings",
				Default = false,
				Callback = function(v)
					shown = v and true or false
					apply()
				end,
			}, fl("ADV_" .. key))
			local outer = cap
			cap = els
			local ok, err = pcall(fn)
			cap = outer
			if not ok then
				logFile("ui advanced", key, tostring(err))
			end
			apply()
		end

		local function block(name, fn)
			local ok, err = pcall(fn)
			if not ok then
				logFile("ui block failed", name, tostring(err))
			end
		end

		-- ==================================================================================================
		-- AUTOSHOOT
		-- ==================================================================================================
		-- band key -> label. "high" also covers the low-landing high shots the solver relabels "mid".
		local SHOT_TYPES = {
			{ "high", "High" },
			{ "corner", "Corner Curl" },
			{ "trick", "Trick" },
			{ "trickLow", "Dip" },
			{ "dipCorner", "Dip Corner" },
			{ "flat", "Flat" },
			{ "chip", "Lob" },
			{ "bounceHigh", "Bounce High" },
			{ "bounceLow", "Bounce Low" },
			{ "airHigh", "Air High" },
			{ "airLow", "Air Low" },
		}

		block("AutoShoot", function()
			local tab = T.AutoShoot

			-- left column ------------------------------------------------------------------------------------
			local s = card(tab, "Left")
			head(s, "AutoShoot")
			feature(s, "AutoShoot", "AutoShoot")
			sld(s, "Max Distance", "ShootMaxDist", 20, 160, { suffix = " st" })
			sld(s, "Keeper Margin", "ShotReachMargin", -0.2, 0.5, { prec = 2, suffix = " s", text = "How late the keeper must be for a shot to count." })

			local pr = card(tab, "Left")
			head(pr, "Priority")
			pick(pr, "Try First", "TryFirst", { { "FAKE", "FAKE" }, { "Normal Shot", "NORMAL" }, { "Bounce FAKE", "BOUNCE" } }, "The rest follow it, the normal shot comes last.", function(v)
				CFG.PriorityFAKE = v == "FAKE"
				CFG.PriorityBounceFAKE = v == "BOUNCE"
			end, (CFG.PriorityBounceFAKE and "BOUNCE") or (CFG.PriorityFAKE and "FAKE") or "NORMAL")
			sld(pr, "FAKE Chance", "FakeFirstChance", 0, 100, { scale = 100, suffix = "%", text = "When a teammate is open and FAKE is tried first." })
			tog(pr, "Wait For Keeper Dive", "FakeAfterDiveBan", "No FAKE while the enemy keeper's dive is on cooldown.")
			tog(pr, "Shoot After Bounce FAKE", "FakeOnceThenShoot", "After one worked, no fakes until the ball is lost.")

			-- Feint: the controls that do not apply to the chosen mode are hidden
			local fe = card(tab, "Left")
			head(fe, "Feint")
			local chanceEl, countEl, atEl, atNote, skipEl, smartEl, smartNote
			local function feintVis(mode)
				mode = mode or CFG.FeintMode or "Off"
				local rows = { { chanceEl, mode == "Chance" }, { countEl, mode == "Count" }, { atEl, mode ~= "Off" }, { skipEl, mode ~= "Off" }, { smartEl, mode ~= "Off" }, { atNote, mode ~= "Off" }, { smartNote, mode ~= "Off" } }
				for i = 1, 7 do
					local el, on = rows[i][1], rows[i][2]
					if el then
						pcall(function()
							el:SetVisibility(on)
						end)
					end
				end
			end
			pick(fe, "Mode", "FeintMode", { { "Off", "Off" }, { "Chance", "Chance" }, { "Count", "Count" } }, "Chance: rolled per charge. Count: N feints, then a real shot.", feintVis)
			chanceEl = sld(fe, "Chance", "FeintChance", 0, 100, { scale = 100, suffix = "%" })
			countEl = sld(fe, "Feints In A Row", "FeintCount", 1, 5)
			atEl = sld(fe, "Cancel At", "FeintAt", 0.2, 0.38, { prec = 2, suffix = " s" })
			atNote = note(fe, "Or when you release, if that comes first.")
			smartEl = tog(fe, "Smart Select", "FeintSmart")
			smartNote = note(fe, "No feint once the keeper has dived: the shot goes.")
			do
				local def = {}
				if CFG.FeintSkipFake ~= false then
					def[#def + 1] = "FAKE"
				end
				if CFG.FeintSkipBounce ~= false then
					def[#def + 1] = "Bounce FAKE"
				end
				skipEl = fe:Dropdown({
					Name = "Never Feint On",
					Options = { "FAKE", "Bounce FAKE" },
					Multi = true,
					Default = def,
					Callback = function(sel)
						local on = {}
						if type(sel) == "table" then
							for k, v in pairs(sel) do
								if v == true then
									on[k] = true
								elseif type(v) == "string" then
									on[v] = true
								end
							end
						end
						CFG.FeintSkipFake = on["FAKE"] == true
						CFG.FeintSkipBounce = on["Bounce FAKE"] == true
					end,
				}, fl("FeintSkip"))
			end
			feintVis()

			local b = card(tab, "Left")
			head(b, "Bounce FAKE")
			tog(b, "Enabled", "BounceFAKE", "A shot that bounces off a wall and comes back to you.")
			sld(b, "Chance", "BounceFakeChance", 0, 100, { scale = 100, suffix = "%" })
			sld(b, "Extra Height", "BounceFakeHeight", 0, 10, { prec = 1, suffix = " st", text = "Raises the aim points, out of the keeper's jump." })
			sld(b, "Max Distance To Goal", "BounceFakeRange", 30, 160, { suffix = " st" })
			advanced(b, "BounceFake", function()
				sld(b, "Run Allowance", "BounceFakeRun", 4, 24, { suffix = " st", text = "How far you may run for the returning ball." })
				sld(b, "Return Slack", "BounceFakeSlack", 0.5, 8, { prec = 1, suffix = " st" })
				sld(b, "Walls Tried", "BounceFakeMaxSim", 2, 20, { text = "Higher finds more, delays the preview." })
				sld(b, "Flight Steps", "BounceFakeSteps", 20, 90)
			end)

			local v = card(tab, "Left")
			head(v, "Shot Preview")
			tog(v, "Show Preview", "DrawShot")
			drop(v, "Style", "ShotStyle", { "aurora", "classic" }, "Classic uses the colors from Visuals.")
			if Mark.artPal then
				head(v, "High Shots")
				palette(v, "hi", { "Color 1", "Color 2", "Color 3" })
				head(v, "Low Shots")
				palette(v, "lo", { "Color 1", "Color 2", "Color 3" })
				head(v, "Curled Shots")
				palette(v, "curl", { "Color 1", "Color 2", "Color 3" })
			end

			-- right column -----------------------------------------------------------------------------------
			local ty = card(tab, "Right")
			head(ty, "Shot Types")
			typeList(ty, "Allowed Types", "ShotBan", "ShotTypes", SHOT_TYPES, "Unchecked types are never used.")
			tog(ty, "Prefer Corner Curl", "PreferCornerCurl")
			tog(ty, "Only Trick / Dip", "OnlyTrick")
			advanced(ty, "Weights", function()
				note(ty, "100% = default mix. 0% = never, 200% = twice as often.")
				for _, t in ipairs(SHOT_TYPES) do
					keep(ty:Slider({
						Name = t[2],
						Default = math.clamp(round(((CFG.ShotWeight and CFG.ShotWeight[t[1]]) or 1) * 100, 0), 0, 300),
						Minimum = 0,
						Maximum = 300,
						Precision = 0,
						Suffix = "%",
						Callback = function(x)
							CFG.ShotWeight = CFG.ShotWeight or {}
							CFG.ShotWeight[t[1]] = x / 100
						end,
					}, fl("W_" .. t[1])))
				end
			end, "Edit Weights")

			local f = card(tab, "Right")
			head(f, "FAKE")
			tog(f, "Enabled", "FakeShot", "A shot through a teammate in front of goal.")
			tog(f, "Friends First", "PrioritizeFriends")
			tog(f, "Curved FAKE", "FakeCurve")
			tog(f, "Corner Name", "FakeCorner", "Labels it FAKE CORNER when it lands in a corner.")
			advanced(f, "Fake", function()
				head(f, "Teammate Rules")
				sld(f, "Max Distance To Goal", "FakeMaxDepth", 30, 160, { suffix = " st" })
				sld(f, "Defender Clearance", "FakeFoeRadius", 2, 14, { suffix = " st", text = "An enemy this close to him takes the ball." })
				sld(f, "Side Tolerance", "FakeLatMul", 1, 3, { prec = 1, suffix = "x", text = "How far off the goal his line may be. Curves bend it back." })
				sld(f, "Slack", "FakeSlop", 1, 12, { suffix = " st" })
				sld(f, "Fallback Chance", "FakeChance", 0, 100, { scale = 100, suffix = "%", text = "Used when FAKE is not tried first." })
			end)

			local fk = card(tab, "Right")
			head(fk, "Flick")
			tog(fk, "Auto Flick", "AutoFlick", "The flick key runs flick, jump and volley for you.")
			tog(fk, "Auto Jump", "FlickAutoJump")
			tog(fk, "Auto Kick", "FlickAutoKick", "Off: you kick, the aim stays locked.")
			typeList(fk, "Flick Shot Types", "FlickBan", "FlickTypes", SHOT_TYPES, "Used while a flick or volley is aimed.")
			advanced(fk, "Flick", function()
				sld(fk, "Jump Timing", "AerialJumpLead", 0.1, 0.5, { prec = 2, suffix = " s", text = "Jumps this long before the ball arrives." })
			end)
		end)

		-- ==================================================================================================
		-- DEFENSE
		-- ==================================================================================================
		block("Defense", function()
			local tab = T.Defense

			-- AutoTackle -----------------------------------------------------------------------------------
			local s = card(tab, "Left")
			head(s, "AutoTackle")
			feature(s, "AutoTackle", "AutoTackle")
			sld(s, "Confidence", "TackleConfidence", 0, 100, { scale = 100, suffix = "%", text = "Share of the hit window that must still connect. 0 = any." })
			sld(s, "Reach", "TackleReach", 8, 30, { suffix = " st" })
			sld(s, "Slide Power", "TackleSpeed", 0.8, 1.6, {
				prec = 2, suffix = "x",
				set = function(x)
					pcall(SlideTackle.SetSpeedMultiplier, x)
				end,
			})
			tog(s, "Competitor Check", "TackleCompetitor", "Skips a carrier a teammate is already on.")
			sld(s, "Competitor Radius", "TackleCompetitorRadius", 3, 25, { suffix = " st" })
			head(s, "Charging Carrier")
			tog(s, "Charge Guard", "ChargeTackleGuard", "Slide only if it lands before his release.")
			tog(s, "Slide Across The Shot", "ChargeSlideBlock")
			head(s, "Lofting Carrier")
			tog(s, "Jump Slide", "JumpSlide", "Jump first, then slide from the air.")
			head(s, "Manual Tackle")
			tog(s, "Manual Tackle", "ManualTackle", "Your own tackle press is aimed at the carrier.")
			bind(s, "Manual Tackle Key", "KB_ManualTackle", function()
				pcall(Mark.manualFire)
			end)
			head(s, "Visual")
			tog(s, "Show Prediction", "DrawTackle")
			drop(s, "Sight Style", "SightStyle", { "reticle", "classic" })
			advanced(s, "Tackle", function()
				sld(s, "Goal Zone", "TackleGoalZone", 0, 80, { suffix = " st", text = "Inside it near our goal, never wait for AutoBlock." })
				tog(s, "Strict Kick Wait", "TackleGateStrict", "Wait for AutoBlock even when its kick cannot fire.")
				sld(s, "Track Radius", "TrackStuds", 30, 160, { suffix = " st" })
				sld(s, "Min Slide Power", "TackleMinSpeed", 0.3, 1.2, { prec = 2, suffix = "x" })
				sld(s, "Charge Range", "ChargeTackleRange", 4, 20, { suffix = " st" })
				sld(s, "Jump Delay", "JumpSlideDelay", 50, 400, { scale = 1000, suffix = " ms" })
				sld(s, "Manual Radius", "ManualRadius", 8, 50, { suffix = " st" })
			end)

			-- AutoBlock ------------------------------------------------------------------------------------
			local b = card(tab, "Left")
			head(b, "AutoBlock")
			feature(b, "AutoBlock", "AutoBlock")
			sld(b, "Range", "BlockRange", 15, 80, { suffix = " st" })
			tog(b, "Competitor Check", "BlockCompetitor", "Stops when a teammate is already on the carrier.")
			sld(b, "Competitor Radius", "CompetitorRadius", 4, 30, { suffix = " st" })
			head(b, "High Shots")
			tog(b, "Pre-Release Jump", "BlockPreJump", "Jumps before the release, timed to his charge.")
			tog(b, "Slide Block", "BlockSlide")
			tog(b, "Jump + Air Slide", "BlockSlideJump")
			advanced(b, "Block", function()
				sld(b, "Behind Limit", "BlockBehind", 8, 40, { suffix = " st", text = "How far behind the carrier it may still start." })
				sld(b, "Stand Closer By", "BlockCloser", -1, 3, { prec = 1, suffix = " st" })
				sld(b, "Min Gap", "BlockGapMin", 1, 6, { prec = 1, suffix = " st" })
			end)

			-- AutoKick -------------------------------------------------------------------------------------
			local k = card(tab, "Left")
			head(k, "AutoKick")
			feature(k, "AutoKick", "AutoKick")
			note(k, "Works inside AutoBlock and CounterJump.")
			tog(k, "Always Full Charge", "AutoKickFull", "Never releases early: a miss instead of a weak kick.")
			sld(k, "Range", "AutoKickRange", 1, 12, { prec = 1, suffix = " st" })
			advanced(k, "Kick", function()
				sld(k, "Cooldown", "AutoKickCooldown", 0.2, 2, { prec = 2, suffix = " s" })
				sld(k, "Min Charge", "AutoKickRelease", 0.2, 0.4, { prec = 2, suffix = " s", text = "Only when Always Full Charge is off." })
				tog(k, "Eager Press", "AutoKickEager")
				sld(k, "Flee Limit", "AutoKickFlee", 3, 20, { suffix = " st/s", text = "No kick if he pulls away faster than this." })
				sld(k, "Flee Margin", "AutoKickPadPerSpeed", 0, 0.3, { prec = 2 })
			end)

			-- AutoDribble ----------------------------------------------------------------------------------
			local d = card(tab, "Right")
			head(d, "AutoDribble")
			feature(d, "AutoDribble", "AutoDribble")
			tog(d, "Agent Addon", "AgentAddon", "Walks into the tackler's box inside the iframe.")
			tog(d, "Show Threat", "DrawDanger")
			advanced(d, "Dribble", function()
				sld(d, "React Range", "DribbleReact", 10, 40, { suffix = " st" })
				sld(d, "Close Range", "DribbleClose", 5, 25, { suffix = " st" })
				sld(d, "Margin", "DribbleSlop", 1, 8, { prec = 1, suffix = " st" })
			end)

			-- AutoDodge ------------------------------------------------------------------------------------
			local dg = card(tab, "Right")
			head(dg, "AutoDodge")
			feature(dg, "AutoDodge", "AutoDodge")
			note(dg, "Last resort when the dribble is on cooldown.")
			pick(dg, "Dodge Mode", "DodgeTeleport", { { "Teleport + Movement", true }, { "Movement Only", false } }, "Movement Only never moves the character by CFrame.")
			tog(dg, "Pass Instead", "PassAssistSync", "Lobs to the safest teammate when a dodge is unsure.")
			advanced(dg, "Dodge", function()
				head(dg, "Projectiles")
				sld(dg, "Safe Margin", "ProjSafeMargin", 0, 4, { prec = 1, suffix = " st" })
				sld(dg, "Punch Radius", "ProjHitRadius", 2, 10, { prec = 1, suffix = " st" })
				head(dg, "Hazards")
				sld(dg, "Blast Margin", "BlastMargin", 0, 5, { prec = 1, suffix = " st" })
				sld(dg, "Mine Margin", "MineMargin", 0, 6, { prec = 1, suffix = " st" })
			end)

			-- CounterJump ----------------------------------------------------------------------------------
			local c = card(tab, "Right")
			head(c, "CounterJump")
			feature(c, "CounterJump", "CounterJump")
			note(c, "Jumps when an enemy goes airborne with the ball.")
			tog(c, "Counter Tackle", "CounterTackle", "Slides at the ball during a flick wind-up.")
			tog(c, "Competitor Check", "CounterCompetitor", "Stops when a teammate is already on him.")
			sld(c, "Competitor Radius", "CounterCompetitorRadius", 4, 30, { suffix = " st" })
			advanced(c, "Counter", function()
				sld(c, "Range", "CounterJumpRange", 4, 20, { suffix = " st" })
				sld(c, "Combo Chance", "CounterComboChance", 0, 100, { scale = 100, suffix = "%" })
				sld(c, "Kick Share", "CounterKickChance", 0, 100, { scale = 100, suffix = "%" })
				sld(c, "Kick Delay", "CounterKickDelay", 0, 0.4, { prec = 2, suffix = " s" })
			end)
		end)

		-- ==================================================================================================
		-- GOALKEEPER
		-- ==================================================================================================
		block("Goalkeeper", function()
			local tab = T.Goalkeeper

			local g = card(tab, "Left")
			head(g, "AutoGK")
			feature(g, "AutoGK", "AutoGK")
			note(g, "Reactions only: intercept, dive, press, return.")
			tog(g, "Jump + Dive", "GkJumpDive", "For shots no ground dive reaches.")
			tog(g, "Lost-Path Stand", "GkLostPath")
			tog(g, "Auto Clear", "GkAutoClear")
			advanced(g, "Gk", function()
				sld(g, "Reaction", "GkReactSeconds", 0.05, 0.4, { prec = 2, suffix = " s" })
				sld(g, "Walk Slack", "GkWalkSlack", 0, 0.3, { prec = 2, suffix = " s" })
				sld(g, "Intercept Radius", "GkInterceptEnemy", 4, 30, { suffix = " st", text = "Free ball with an enemy this close: no run." })
				sld(g, "Bait Inset", "GkBaitInset", 0, 2, { prec = 1, suffix = " st" })
				sld(g, "Bait Ray", "GkBaitRay", 0.5, 6, { prec = 1, suffix = " st" })
				sld(g, "Lost-Path Share", "GkLostDiveFrac", 0.3, 1, { prec = 2 })
			end)

			local p = card(tab, "Right")
			head(p, "Press")
			tog(p, "Press", "GkPress", "Forward dive into a carrier coming at goal.")
			tog(p, "Press Jump", "GkPressJump")
			advanced(p, "GkPress", function()
				sld(p, "Press Distance", "PressGoalDist", 10, 60, { suffix = " st" })
				sld(p, "Wait For Contact", "PressMaxT", 0.1, 1, { prec = 2, suffix = " s" })
				sld(p, "Desperate Window", "GkPressDesperate", 0.2, 1.5, { prec = 2, suffix = " s" })
			end)

			local r = card(tab, "Right")
			head(r, "Return")
			tog(r, "Return After Push", "GkReturn", "Back to the spot after a shotgun or dash push.")
			advanced(r, "GkReturn", function()
				sld(r, "Dive Back From", "GkReturnDive", 5, 30, { suffix = " st" })
			end)
		end)

		-- ==================================================================================================
		-- SKILLS (items)
		-- ==================================================================================================
		block("Skills", function()
			local tab = T.Skills

			local sa = card(tab, "Left")
			head(sa, "SilentAim")
			feature(sa, "SilentAim", "SilentAim")
			note(sa, "Item aim: leads the target, arcs the freeze gun.")
			sld(sa, "FOV", "SilentFov", 30, 400, { suffix = " px" })
			tog(sa, "Show FOV Circle", "DrawSilentFov")
			tog(sa, "Show Tracer", "DrawSilent")
			advanced(sa, "Silent", function()
				sld(sa, "Freeze Gun Tolerance", "ArcMaxErr", 0.5, 6, { prec = 1, suffix = " st", text = "Arc error accepted. Beyond it, aims at the feet." })
			end)

			local w = card(tab, "Right")
			head(w, "AutoWall")
			feature(w, "AutoWall", "AutoWall")
			tog(w, "Auto Use", "WallEquip", "Takes the barricades out by itself. Off: only when already in hand.")
			pick(w, "Aim Ahead", "WallLead", { { "Never", "never" }, { "Only When He Runs Away", "away" }, { "Always", "always" } })
			tog(w, "Block Projectiles", "BarricadeAddon", "Puts a wall on a projectile's path.")
			tog(w, "Wall On Shot Path", "WallShot", "Walls a charged shot.")
			tog(w, "Ambush", "WallAmbush", "Places early on an enemy running into the spot.")
			advanced(w, "Wall", function()
				sld(w, "Equip Distance", "WallEquipDist", 8, 50, { suffix = " st" })
				sld(w, "Put Away After", "WallEquipHold", 1, 10, { prec = 1, suffix = " s" })
				sld(w, "Cooldown", "WallCooldown", 0.2, 3, { prec = 1, suffix = " s" })
				sld(w, "Ambush Reach", "WallReach", 8, 50, { suffix = " st" })
				sld(w, "Min Closing Speed", "WallAmbushV", 1, 12, { prec = 1, suffix = " st/s" })
				sld(w, "Ambush Time", "WallAmbushT", 0.2, 2, { prec = 2, suffix = " s" })
			end)
		end)

		-- ==================================================================================================
		-- MOVEMENT
		-- ==================================================================================================
		block("Movement", function()
			local tab = T.Movement

			local ba = card(tab, "Left")
			head(ba, "AutoBall")
			feature(ba, "AutoBall", "AutoBall")
			tog(ba, "Competitor Check", "BallCompetitor", "Stops when a teammate is clearly closer to the ball.")
			sld(ba, "Competitor Gap", "BallYieldGap", 2, 20, { suffix = " st", text = "How much closer he must be." })
			head(ba, "Rival Slide")
			tog(ba, "Enabled", "CandidateKiller", "Slides an enemy who runs for the same ball.")
			head(ba, "Goal Guard")
			tog(ba, "Enabled", "KillerGuard", "Ball near our goal: slide the closest enemy first.")
			advanced(ba, "Ball", function()
				sld(ba, "Slide Gain", "RouteSlideGain", 0, 1.5, { prec = 2, suffix = " s", text = "A slide replaces the run if it gets there this much sooner." })
				head(ba, "Rival Slide")
				sld(ba, "Ball Radius", "KillerRadius", 8, 40, { suffix = " st" })
				sld(ba, "Our Reach", "KillerReach", 10, 50, { suffix = " st" })
				sld(ba, "Threat Margin", "KillerMargin", 0, 1.5, { prec = 2, suffix = " s" })
				sld(ba, "Max Turn", "KillerAngle", 10, 90, { suffix = "°" })
				sld(ba, "Intent Radius", "IntentTackleRadius", 20, 120, { suffix = " st" })
				head(ba, "Goal Guard")
				sld(ba, "Goal Distance", "KillerGuardGoal", 20, 100, { suffix = " st" })
				sld(ba, "Ball Distance", "KillerGuardNear", 8, 40, { suffix = " st" })
				sld(ba, "Enemy Distance", "KillerGuardFoe", 10, 80, { suffix = " st" })
			end)

			local j = card(tab, "Right")
			head(j, "Free Jump")
			j:Keybind({
				Name = "Free Jump Key",
				Callback = function()
					if UserInputService:GetFocusedTextBox() then
						return
					end
					pcall(Mark.doJump, "L")
				end,
				onBindHeld = function(held)
					if not held then
						pcall(Mark.endJump)
					end
				end,
			}, fl("KB_Jump"))
			note(j, "A jump that costs no stamina.")

			local fb = card(tab, "Right")
			head(fb, "Force Bicycle")
			bind(fb, "Force Bicycle Key", "KB_Bike", function()
				local ok, err = pcall(Mark.startBike)
				if not ok then
					logFile("ui bike", "err", tostring(err))
				end
			end)
			note(fb, "Jumps and bicycle-kicks the ball. Needs the ball.")
		end)

		-- ==================================================================================================
		-- VISUALS
		-- ==================================================================================================
		block("Visuals", function()
			local tab = T.Visuals

			local s = card(tab, "Left")
			head(s, "Overlay")
			tog(s, "Draw Overlay", "Draw")
			head(s, "Show")
			tog(s, "Positions", "DrawPos")
			tog(s, "Goal Frame", "DrawGoal")
			tog(s, "Ball Mark", "DrawBall")
			tog(s, "Agent Route", "DrawRoute")
			tog(s, "Oil Puddles", "DrawHazards")
			tog(s, "Kick Box", "DrawKickBox")
			note(s, "Shot preview, tackle and threat marks, silent aim and pass marks sit in their own functions.")
			advanced(s, "Overlay", function()
				sld(s, "Paint Rate", "PaintHz", 0, 240, { suffix = " Hz", text = "Only at 100+ fps. 0 = every frame." })
			end)

			local st = card(tab, "Right")
			head(st, "Styles")
			drop(st, "Positions", "PosStyle", { "phantom", "classic" })
			drop(st, "Route Destination", "AgentSpotStyle", { "corners", "ripple", "kick" })
			drop(st, "Route Line", "AgentPathStyle", { "flow", "classic" })

			local r = card(tab, "Right")
			head(r, "Colors")
			note(r, "Shot preview and pass mark colors sit in their own functions.")
			if Mark.artPal then
				head(r, "You")
				palette(r, "live", { "Color 1", "Color 2", "Color 3" })
				head(r, "Server Position")
				palette(r, "srv", { "Color 1", "Color 2", "Color 3" })
				head(r, "Alerts")
				palette(r, "hot", { "Color 1", "Color 2", "Color 3" })
			end
			head(r, "Classic Style")
			color(r, "Route / Ball Path", "Line")
			color(r, "Tackle", "Tackle")
			color(r, "Shadows", "Chalk")
			color(r, "Highlights", "Paper")
			color(r, "Lob / Curl", "Lob")
			color(r, "Flat Shots", "Flat")
			color(r, "Dodge", "Dodge")
		end)

		-- ==================================================================================================
		-- MISC
		-- ==================================================================================================
		block("Misc", function()
			local p = card(T.Misc, "Left")
			head(p, "Pass Assist")
			feature(p, "Pass Assist", "PassAssist")
			note(p, "A pass press on a teammate becomes a solved lob.")
			tog(p, "Manual Pass", "PassManual", "One key passes to the best teammate.")
			bind(p, "Manual Pass Key", "KB_ManualPass", function()
				if CFG.PassManual then
					local ok, err = pcall(Mark.paManual)
					if not ok then
						logFile("pass manual", "err", tostring(err))
					end
				end
			end)
			tog(p, "Pass To Keeper", "PassToKeeper")
			tog(p, "Show Marks", "PassShow")
			head(p, "Mark Colors")
			palette(p, "lime", { "Mark 1", "Mark 2", "Mark 3" })
			advanced(p, "Pass", function()
				sld(p, "Lock Angle", "PassFov", 3, 25, { suffix = "°" })
				sld(p, "Min Distance", "PassMinDist", 3, 30, { suffix = " st" })
				sld(p, "Max Distance", "PassMaxDist", 40, 200, { suffix = " st" })
				sld(p, "Manual Near Limit", "PassManualNear", 4, 40, { suffix = " st" })
				head(p, "Landing")
				sld(p, "Goal Lead", "PassGoalLead", 10, 60, { suffix = " st", text = "Receive point stays this far from their goal." })
				sld(p, "Keeper Radius", "PassKeeperRadius", 4, 30, { suffix = " st" })
				sld(p, "Goal Angle", "PassGoalSep", 2, 25, { suffix = "°" })
				sld(p, "Goal Zone", "PassGoalZone", 10, 70, { suffix = " st" })
			end)
		end)

		-- ==================================================================================================
		-- DEBUG (the loader adds its own sections here too)
		-- ==================================================================================================
		block("Debug", function()
			local tab = T.Debug

			local s = card(tab, "Left")
			head(s, "AutoShoot")
			tog(s, "Debug Text", "ShotDebug", "Shot name, side, distance and curve under the crosshair.")
			tog(s, "Status Text", "DrawHud", "Tackle, dribble and ball state, bottom left.")
			sld(s, "Solver Budget", "ShootSliceMs", 0.3, 3, { prec = 1, suffix = " ms", text = "CPU per frame. Higher solves faster, hitches more." })

			local lg = card(tab, "Left")
			head(lg, "Log")
			tog(lg, "Perf Probe", "Perf", "Writes ms per section into the log every 5 s.")
			lg:Button({
				Name = "Dump Log To File",
				Callback = function()
					local ok, err = pcall(dumpLog)
					notify("Log", ok and "Saved: illegalsoccerlog.txt" or ("Failed: " .. tostring(err)))
				end,
			})

			local ag = card(tab, "Right")
			head(ag, "Agent Estimates")
			note(ag, "Server values the dump does not give. Check the log before changing.")
			head(ag, "Hazards")
			sld(ag, "Oil Radius", "OilRadius", 2, 8, { prec = 1, suffix = " st" })
			sld(ag, "Hammer Radius", "HammerRadius", 4, 16, { suffix = " st" })
			head(ag, "Slide")
			sld(ag, "Slide Lag", "SlideLag", 0, 120, { scale = 1000, suffix = " ms" })
			sld(ag, "Min Ball Hits", "SlideMinHits", 1, 8, { text = "Of 11 samples the slide must hold the ball." })
			sld(ag, "Run Ramp-Up", "BallRamp", 0, 0.6, { prec = 2, suffix = " s" })
			head(ag, "Keeper Press")
			sld(ag, "Contact Radius", "PressReach", 1, 5, { prec = 1, suffix = " st" })
			sld(ag, "Contact Height", "PressVert", 1, 8, { prec = 1, suffix = " st" })
			head(ag, "Wall")
			sld(ag, "Latency", "WallLatency", 0, 300, { scale = 1000, suffix = " ms" })
			sld(ag, "Margin", "WallMargin", 0, 0.5, { prec = 2, suffix = " s" })
			sld(ag, "Min Distance", "WallMin", 1, 8, { prec = 1, suffix = " st" })
			sld(ag, "Max Distance", "WallMax", 3, 14, { prec = 1, suffix = " st" })
		end)

		task.defer(function()
			uiReady = true
		end)
	end

	return M
end
