do
	local _E = (getgenv and getgenv()) or _G
	if not _E["LPH_NO_VIRTUALIZE"] then
		local id, nop = function(f) return f end, function() end
		_E["LPH_NO_VIRTUALIZE"] = id
		_E["LPH_JIT_MAX"] = id
		_E["LPH_JIT"] = id
		_E["LPH_ENCFUNC"] = id
		_E["LPH_NO_UPVALUES"] = id
		_E["LPH_ENCSTR"] = id
		_E["LPH_ENCNUM"] = id
		_E["LPH_SKIP"] = id
		_E["LPH_CRASH"] = nop
		_E["LPH_OBFUSCATED"] = false
	end
end
local _C = {}
local _D = {}

local Config = {
	Version       = "V304",
	Enabled       = false,
	Mode          = "Perfect",

	Range         = 18,
	ReachCloseCap = 8,
	RequireFacing = false,
	IncludeNPCs   = true,
	ParryWhitelist = {},
	HeavyEnabled  = true,

	M1Forward     = 4,
	M2Forward     = 3,
	HitboxDepth   = 4.0,
	HitboxDepthBack = 1.0,
	HitHalfWidth  = 3.0,
	HitboxSlack   = 1.25,
	HighSlack     = 1.25,
	HighReachPad  = 6.0,
	HighFaceFloor = -0.50,
	ProvenReachPad    = 4.0,
	ProvenReachWindow = 0.22,
	WillHitLeadFrac = 0.90,
	FaceHardDeg     = 115,
	TurnSnapDeg     = 50,
	StickyStrict    = true,
	StickyReachPad  = 8.0,
	StickyFaceAllowPadDeg = 45,
	LatchStrict     = true,
	LatchSidePad    = 8.0,
	MultiHitKeep    = true,
	-- Метки Hit в анимации — TimePosition. Height-aMult на нашем клиенте
	-- в track.Speed не виден (spd=1.00 при aMult=1.10). Делить маркеры на
	-- aMult нельзя: контакт уезжал на ~50мс раньше, исход при TP=0.725.
	-- Pad на первом хите Boxing M2 давал contact=680 при маркере 600
	-- (лог V188: meas=608, LATE при IN-WINDOW). Второй хит: 1130 vs ~1080.
	MultiHitOverlapPad = 0,
	HeavyFacePadDeg = 55,
	-- Perfect: удержание гарда вне окна = BLOCK, чип бара, затем GB.
	GuardLastResort        = false,
	GuardLastResortHorizon = 0.18,

	WillHitVelCap   = 8.0,
	WillHitCloseCap = 14,
	WillHitLatCap   = 8.0,
	HighApproachCap = 14.0,
	ApproachVelMin  = 0.5,
	ClosingEtaSlack = 0.12,
	ClosingFacePadDeg = 45,
	OvGapEps        = 1.25,

	ComboEscape        = true,
	ComboEscapeDodge   = true,
	DodgeOnParryCooldown = true,
	StunReleaseLead    = 0.14,
	GuardbreakProtect  = true,
	StaminaFloor       = 18,
	StaminaAttrs       = { "Stamina", "BlockStamina", "GuardStamina", "Posture", "Guard" },

	PerfectWindow = 0.125,
	PerfectWindowLive = true,
	PerfectMin    = 0.05,
	PerfectLead   = 0.095,
	HoldAfter     = 0.12,
	HoldLateGrace = 0.14,
	GapOffsetCap  = 0.28,
	LatchTrustMultiHit = true,
	SchedulerWatchdog    = false,
	LatchTrustThrottled  = true,

	ServerGapOffsetMs = 0,
	GapCalibDiag  = true,

	AnimTimeModel   = true,
	AnimPingCompMax = 0.35,
	HitboxWindupExtra = 0.012,
	SpeedSanityMin  = 0.20,
	SpeedSanityMax  = 3.00,


	ThreatStallSec   = 0.45,
	ThreatMaxAgeSec  = 1.5,
	LatchClusterGrace = 0.25,

	BlockFaceHard   = true,
	BlockFaceHardDt = 0.30,

	M2WidenWindow = false,
	M2WidenFront  = 0.22,
	M2WidenHold   = 0.10,

	HitboxDodge     = true,

	ReleaseGap    = 0.40,

	-- V189: face=0.36 BACK! при FaceGateMin=0.2 — FACETURN не срабатывал,
	-- пакет уходил спиной, игра LATE при локальном EARLY. Ждём доворот до FaceGoodDot.
	FaceGateMin   = 0.52,
	FacePressFloor = 0.055,
	CloseM1EarlyStuds = 4.5,
	CloseAliC3HitTL = 0.36,

	UplinkFactor  = 0.5,
	UplinkMargin  = 0.008,
	-- GetNetworkPing в дампе пишется как net1w и часто > RTT/2. Не делить его
	-- повторно, иначе press уходит на ~30–40мс позже, чем пакет реально летит.
	UplinkPreferGnpOneWay = true,
	ThrottleCatchPad  = 0.07,
	M2WallCapSlack    = 0.035,
	UplinkMin     = 0.010,
	LowPingFloor   = 0.0,
	LowPingThresh  = 0.090,
	UplinkMax     = 0.500,
	PingCap       = 0.500,
	PingSourceMaxRatio = 2.5,
	PingWindow    = 24,
	PingSampleGap = 0.03,
	FallbackDodgeOnRefusal = true,

	OverlapLeadBase = 2.0,
	OverlapReaction = 0.050,
	OverlapLeadCap  = 18.0,

	MoveLeadMax   = 0.100,
	MoveSpeedFull = 22,

	MaxWait       = 1.6,

	MinActGap     = 0.004,
	MinDeactGap   = 0.050,

	MatchWindow   = 1.30,
	MultiHitWindow = 1.30,

	AutoDodge     = true,
	DodgeHeavy    = true,
	FOV           = 360,

	MustDodge       = true,
	MustDodgeAutoGrab = true,
	MustDodgeStyles = {
		wrestling = { M2 = true },
		kure = { M2 = true },
		judo = { M2 = true },
	},

	IFrameDur     = 0.30,
	DodgeLead     = 0.10,
	UseServerCooldown = true,
	DodgeCooldown = 2.05,
	MultiDodgeLate      = true,
	MultiDodgeLateGrace = 0.06,

	OutnumberedDashSpeedMult    = 1.5,
	OutnumberedDashDurationMult = 1.2,
	EvasiveAckTimeout  = 0.18,
	LocalParryAttackLockout = 0.15,
	LocalBlockAttackLockout = 0.15,
	LocalM2AttemptLockout   = 0.20,
	ParryAttackLockout = 0.15,
	GuardbreakLockout  = 2.0,
	ParryBufferAfterHit = 2.0,
	DodgeMinSpacing = 0.35,
	OutnumberEscape = true,
	ExposedEscapeDodge = true,
	ExposedDodgeWindow = 0.28,
	ExposedEscapeAttackOnly = true,
	OutnumberEscapePreferBlock = true,
	DashSpeed     = 30,
	MaxHeightDiff = 8,
	BoxingM2FirstFloor = 0.58,
	DashDuration  = 0.20,
	DodgeConfirm  = 0.18,
	DodgeCenter   = true,
	HeavyDodgeInset = 0.075,
	DodgeCenterBias = 0.00,
	HeavyDodgeBias  = 0.00,
	FrameLookahead   = 0.5,
	FrameLookaheadCap= 0.045,
	FrameLookaheadPeakK  = 0.50,
	FrameLookaheadPeakDecay = 1.10,
	FrameLookaheadCapK   = 0.75,
	FrameLookaheadCapHi  = 0.11,
	FrameStepCostComp    = 0.60,

	LowFpsComp     = true,
	LowFpsFrameMs  = 25,
	LowFpsPeakK    = 0.85,
	LowFpsCapHi    = 0.13,
	LowFpsEdgeMs   = 6,

	-- Target gap is a FRACTION of live PerfectWindow. uplink() already
	-- subtracts ping at press. Do not bake one player's ping into ms floors.
	LeadQuantCenter = 0.72,
	LeadQuantFloorFrac = 0.64,
	GapEdgeMs     = 6,

	HitboxDuration   = 0.15,
	HitboxRetime     = true,
	HitboxContactLead = 0.02,
	HitboxRetimeMinMs = 40,
	-- Анимация реплицируется и её можно соврать (desync / AP-breaker).
	-- Серверный хитбокс (AttackName, Owner, VictimSwingId) — источник контакта.
	-- M2 жмётся по стене detect+hitTL; TimePosition не тянет press раньше.
	-- Поздний хитбокс снимает ранний гард, если удержание уже > PerfectWindow.
	HitboxCommitPress = true,
	HitboxOriginDetect = true,
	-- Анимация на клиенте часто появляется позже хитбокса (V204: meas=106
	-- при pred=331, NO-PRESS — хитбокс отвергли из‑за окна 35мс).
	HitboxLookbackSec = 0.55,
	HoldForLiveAnim   = true,
	HoldLiveCap       = 1.15,
	StunPressMaxRemain = 0.140,
	StunPressMinRemain = 0.050,
	EmergencyPress      = true,
	EmergencyPressGrace = 0.20,
	TurnRateRad      = 6.0,
	ReachSlack       = 1,
	DodgeMode      = "Defensive",
	DodgeAggroSteer   = true,
	DodgeAggroClose   = 0.45,
	DodgeExitSteer    = true,
	DodgeWallCheck = true,
	DodgeWallDist  = 8,

	DodgeHardStates = { "Ragdoll", "Downed", "Knocked", "KnockedDown", "Grabbed", "Carried",
	                    "Frozen", "Sitting", "Cutscene", "Greenzone", "RpCombatLocked",
	                    "StaffModPeaceMode" },
	NoDodgeWhileStunned = true,
	DodgeRejectMute     = 3.0,
	DodgeOnlyWhenNoParry = true,
	CounterOnlyWhenNoParry = true,
	-- Boxing-counter ставит CantAnything: чужой M2 в том же окне пропускается
	-- (V188: COUNTER-SEND → Hakari M2 refused). Не контрить, если M2 уже в полёте.
	-- V216: Ali M2 — parry-only, но M2RagdollLaunchStrength>0 считался GB;
	-- контра снимала гард на remaining≈80мс → LATE. Не контрить, если
	-- iframes/ack заведомо не успеют до контакта.
	CounterYieldToM2 = true,
	CounterM2Horizon = 0.95,
	CounterMinRemain = 0.22,
	DodgeTelemetry  = true,

	LiveHeavyTimer    = true,
	LiveSpeedFloor    = 0.15,
	LiveSpeedSmooth   = 0.35,
	LiveM1Timer       = true,
	LiveM1WallCap     = true,
	LiveM1SpeedFloor  = 0.45,
	LiveRateTrust     = true,
	LiveRateMinSamples = 3,
	M1WallCapSlack    = 0.040,
	LiveSpeedMinDt    = 0.03,
	LiveSpeedMaxFactor= 1.5,
	LiveSpeedMinSamples = 1,

	EmergencyDualDodge = true,
	MultiDodgeCover = true,
	MultiDodgeConfirmSlack = 0.03,
	TurnRateDegPerSec  = 720,
	RearmBudget        = 0.06,
	DualDodgeMaxGap     = 0.22,

	DeepDiag           = false,
	TraceDiag          = false,
	PerfProbe          = false,

	BoxingCounter     = false,
	BoxingCounterReach= 5.5,
	BoxingCounterGap  = 0.30,

	WingChunCounter     = false,
	WingChunCounterReach= 6.5,
	AikidoCounter       = false,
	AikidoCounterReach  = 6.5,
	WCStartup           = 7 / 60,
	WCCalibrate         = false,
	WCAimFrac           = 0.35,
	WCEarlyMargin       = 0.045,
	WCLateMargin        = 0.10,
	WCRequireLiveTrack  = true,
	WCSoloOnly          = true,
	WCSkipGrabs         = true,

	AliCounter        = false,
	AliCounterReach   = 7.5,
	AliM2Variant      = "Left",
	AliProcTTLFrac    = 0.25,
	AliProcTTLMax     = 1.5,
	AliVariantSteerDur= 0.15,
	AliEvasiveCounter = false,
	AliDodgeAbuse     = false,
	CounterPreemptsDodge = true,
	DodgeCenterFrac   = 0.38,

	SkillAddon        = true,
	SA_WrestlingGrab  = true,
	SA_DirtyGrab      = true,
	SA_CQCRingDodge   = true,
	SA_WrestlingPunishM2 = false,
	SA_BlatantDodge   = false,
	SA_BlatantWindow  = 0.32,

	AutoPlay          = false,
	AP_ForceNativeM1  = true,
	-- V301: M1 after PERFECT vs a player = their AP's BUFFER-WAIT
	-- free parry → ApplyLocalParriedStun on us → LATE. NPC-only.
	AP_PunishOnParry  = false,
	AP_Interrupt      = false,
	-- Сбив только при AutoPlay. По умолчанию выключен: при включении
	-- имеет приоритет над парри, если свой удар реально опережает чужой.
	-- Margin 80мс: 25мс давал trade M1 vs Lethwei M2 и глушил парри.
	AP_InterruptMargin= 0.08,
	AP_InterruptNetK  = 0.25,
	AP_BaseReach      = 5.5,
	AP_RefHeight      = 5.5,
	AP_InterruptM2       = true,
	AP_InterruptPreferM2 = true,
	AP_M2BaseReach       = 6.5,
	AP_M2Gap             = 0.30,
	AP_M2IFrameMargin    = 0.08,
	-- I-frames M2 обычно стартуют у первого хитбокса, не с кадра Activate.
	-- Не прерываем удар, который прилетит раньше нашего окна неуязвимости.
	AP_M2IFrameLead      = 0.10,
	AP_AnimGuard    = true,
	AP_AnimFallback = 0.45,
	AP_MaxPerSec      = 8,
	AP_MinSendGap     = 0.08,
	AP_PunishFastGap  = 0.08,
	AP_M2Stun         = 1.0,
	AP_M1Stun         = 0.5,
	AP_PollGap        = 0,
	AP_FaceHold       = 0.35,
	AP_ComboMode      = "Follow",
	AP_FixedHit       = 1,

	RequireEquip      = true,

	RestrictZone      = true,
	RestrictLongOnly  = true,
	RestrictMinWindup = 0.30,
	RestrictPad       = 2.0,
	RestrictSoft      = true,
	RestrictShowZone  = true,

	SelfBusyDur     = 0.45,

	DesyncAttack   = false,
	DesyncMode     = "delay",
	DesyncDelayMs  = 140,
	DesyncDecoyId  = 507766388,
	DesyncApplyM1  = true,
	DesyncApplyM2  = true,
	AntiDecoy      = true,
	AntiDecoyGap   = 0.12,
	AntiDecoyMaxBurst = 3,
	DecoyRefireSec  = 0.60,
	DecoySpeedMin   = 0.30,
	DecoySpeedMax   = 1.25,
	DecoySpeedTol   = 0.50,
	DecoyHardDrop   = true,
	DecoySweepSec   = 5,
	DecoySeenMax    = 512,
	ServerProofGate = true,
	ProofGraceSec   = 0.06,
	TimeSpoof    = false,
	TimeShiftMs  = 40,
	DesyncClientVisible = false,
	DesyncSendHz      = 0,
	InvisibleOn    = false,
	InvisibleHeight= 0,
	InvisibleAnim  = true,

	BoxingFaceLockDur = 0.55,
	AliFaceLockDur = 0.75,

	MultiThreatGuard  = true,
	MultiThreatMinN   = 2,
	BlockCooldown     = 0.50,
	BlockCooldownPredict = true,
	BlockCooldownSafety  = 0.03,
	SequentialMargin  = 0.05,
	PlanLatchSec      = 1.2,
	CooldownDodge     = true,
	SequentialSpread  = 0.78,
	MultiFaceAngleMax = 70,
	MultiFaceJitter   = 0.30,
	MultiFaceOnlyFront= true,
	DesyncSafeDecoy   = true,

	AntiCheatBypass = true,
	HideHooks       = true,
	MuteAC          = true,
	BlockKick       = true,
	BlockACReports  = true,
	ACScriptName    = "so you're challenging me",
	NeutralizeAC    = true,

	MultiFaceHard     = true,
	FaceOnlyRealThreats = true,
	HeavyFirst        = true,

	DodgeHorizon      = 0.34,
	MinBlockSeparation= 0.17,
	DodgeArmWindow    = 0.05,

	LegitAnims    = true,

	AutoFace      = true,
	FaceLerp      = 0.80,
	FaceLeadWindow= 0.30,
	FaceGoodDot   = 0.55,
	FaceLead      = 0.07,
	FaceLeadMax   = 4,
	FacePingLead  = 1.0,
	FaceLeadCap   = 0.28,
	FaceLeadMaxStuds = 16,
	FaceLatMaxStuds = 18,
	FaceRadMaxStuds = 5,

	OmniBlock      = true,

	ShowVisuals   = true,
	VizRing       = true,
	VizRingStyle  = "Flat",
	VizRingSeg    = 16,
	VizRingMirror = true,
	VizRingTilt   = 0.7,
	RotationMethod = "LookAt",
	AimLockLerp    = 0.35,
	VizHitbox     = true,
	VizRestrict   = true,
	VizRingSpeed  = 1.0,
	VizRingScale  = 1.0,
	VizRange      = 100,
	VizMaxFPS     = 30,
	VizAutoDegrade   = true,
	VizFrameShare    = 1.5,
	VizSkipNearPress = 0.20,
	VizSkipMaxFrames = 2,
	Debug         = false,

	Key_Toggle    = Enum.KeyCode.K,
	Key_Mode      = Enum.KeyCode.N,
	Key_Desync    = Enum.KeyCode.J,
	Key_Boxing    = Enum.KeyCode.V,
	Key_Double    = Enum.KeyCode.H,
	Key_Face      = Enum.KeyCode.G,
	Key_LogDump   = Enum.KeyCode.L,
	Key_Save      = Enum.KeyCode.P,
	Key_ACScan    = Enum.KeyCode.O,
	Key_DesyncSave = Enum.KeyCode.Semicolon,
	Key_DesyncTest = Enum.KeyCode.LeftBracket,
	Key_DesyncMode = Enum.KeyCode.RightBracket,
	AutoScanAC    = false,
	Key_Panel     = Enum.KeyCode.RightShift,
}

_D.LEGACY_ATTACKS = {
	[113961476814500]={t="M1",d=0.32,s="Base",c=1}, [82165070516177]={t="M1",d=0.32,s="Base",c=2},
	[138197524717835]={t="M1",d=0.32,s="Base",c=3}, [81174027972159]={t="M1",d=0.32,s="Base",c=4},
	[113480104450803]={t="M2",d=0.30,s="Base"},
	[102632933427597]={t="M1",d=0.37,s="Ali",c=2}, [119814294807778]={t="M1",d=0.42,s="Ali",c=3},
	[137247073345979]={t="M1",d=0.28,s="Ali",c=1}, [74315946602284]={t="M1",d=0.22,s="Ali",c=4},
	[128315752013166]={t="M2",d=0.53,s="Ali",v="Left"}, [70642098724811]={t="M2",d=0.67,s="Ali",v="Right"},
	[106980660082799]={t="M1",d=0.34,s="Basic",c=4}, [83491849294956]={t="M1",d=0.34,s="Basic",c=1},
	[83730275893449]={t="M1",d=0.34,s="Basic",c=3}, [89420531853362]={t="M1",d=0.34,s="Basic",c=2},
	[78888626472394]={t="M2",d=0.525,s="Basic"},
	[100408082509740]={t="M1",d=0.34,s="Boxing",c=2}, [137980914350618]={t="M1",d=0.34,s="Boxing",c=1},
	[78695517680318]={t="M1",d=0.38,s="Boxing",c=4}, [94803478352691]={t="M1",d=0.34,s="Boxing",c=3},
	[132022052139564]={t="M2",d=0.43,s="Boxing"},
	[106965238908791]={t="M1",d=0.28,s="Capoeira",c=4}, [117877243065533]={t="M1",d=0.35,s="Capoeira",c=3},
	[125976167173936]={t="M1",d=0.35,s="Capoeira",c=1}, [134945199381140]={t="M1",d=0.43,s="Capoeira",c=2},
	[131071815103338]={t="M2",d=0.45,s="Capoeira"},
	[103026596903060]={t="M1",d=0.37,s="Hakari",c=2}, [103100834246116]={t="M1",d=0.38,s="Hakari",c=4},
	[86626533783115]={t="M1",d=0.28,s="Hakari",c=3}, [92865171012109]={t="M1",d=0.35,s="Hakari",c=1},
	[103359839046574]={t="M2",d=0.35,s="Hakari"},
	[102961997518914]={t="M2",d=0.48,s="Hakari",mom=true},
	[113719263885794]={t="M1",d=0.32,s="HakariOther",c=2}, [126612786608030]={t="M1",d=0.32,s="HakariOther",c=1},
	[136305578634960]={t="M1",d=0.32,s="HakariOther",c=3}, [89039586375625]={t="M1",d=0.32,s="HakariOther",c=4},
	[101619248052969]={t="M2",d=0.30,s="HakariOther"},
	[82855179231529]={t="M2",d=0.48,s="HakariOther",mom=true},
	[100981571094705]={t="M1",d=0.315,s="Karate",c=2}, [130865087635587]={t="M1",d=0.39,s="Karate",c=3},
	[137837926745158]={t="M1",d=0.2775,s="Karate",c=1}, [86495068205420]={t="M1",d=0.465,s="Karate",c=4},
	[120393553812903]={t="M2",d=0.4875,s="Karate"},
	[103732110215321]={t="M1",d=0.32,s="Kure",c=2}, [103964436023727]={t="M1",d=0.32,s="Kure",c=3},
	[71676634048602]={t="M1",d=0.32,s="Kure",c=4}, [82904229252991]={t="M1",d=0.32,s="Kure",c=1},
	[102407060635393]={t="M2",d=0.30,s="Kure"},
	[104515319350296]={t="M1",d=0.30,s="MuayThai",c=3}, [139911027872047]={t="M1",d=0.30,s="MuayThai",c=2},
	[74960202100098]={t="M1",d=0.30,s="MuayThai",c=4}, [96726284968458]={t="M1",d=0.30,s="MuayThai",c=1},
	[137034747040618]={t="M2",d=0.60,s="MuayThai"},
	[104867156139010]={t="M1",d=0.45,s="Slugger",c=2}, [112759168172605]={t="M1",d=0.45,s="Slugger",c=3},
	[114647502301740]={t="M1",d=0.37,s="Slugger",c=4}, [134829666925953]={t="M1",d=0.50,s="Slugger",c=1},
	[118943955490014]={t="M2",d=0.82,s="Slugger"},
	[118070233153900]={t="M1",d=0.23,s="Striker",c=3}, [127909081017342]={t="M1",d=0.35,s="Striker",c=1},
	[77710266587706]={t="M1",d=0.12,s="Striker",c=4}, [79563637573277]={t="M1",d=0.35,s="Striker",c=2},
	[114364673509520]={t="M2",d=0.45,s="Striker"},
	[116642061934550]={t="M1",d=0.35, s="Striker",c=1}, [115234849770695]={t="M1",d=0.35,s="Striker",c=2},
	[73777821288331] ={t="M1",d=0.12, s="Striker",c=4},
	[99309341097380] ={t="M2",d=0.45, s="Striker"},
	[117898175201201]={t="M1",d=0.30,s="WingChun",c=2}, [121315597867666]={t="M1",d=0.30,s="WingChun",c=3},
	[71178147313608]={t="M1",d=0.30,s="WingChun",c=1}, [81810173569294]={t="M1",d=0.70,s="WingChun",c=4},
	[82196924299426]={t="M2",d=0.525,s="WingChun",counter=true},
	[107464726433388]={t="M1",d=0.36,s="Wrestling",c=3}, [119685134442395]={t="M1",d=0.37,s="Wrestling",c=2},
	[82903450925391]={t="M1",d=0.36,s="Wrestling",c=1}, [91485623489753]={t="M1",d=0.35,s="Wrestling",c=4},
	[73748315742870]={t="M2",d=0.30,s="Wrestling"},
}

_D.WINGCHUN = {
	CounterWindow   = 0.58,
	-- M2CounterParryDisableDuration was removed from CombatConfig this patch.
	CounterParryDisable = 0,
	CounterWhiffStun= 0.6,
	CounterHoldSecs = 1.367,
	CounterFps      = 60,
	CounterFrames   = { 25, 41, 52, 62, 82 },
	VictimHitStun   = 2.8,
	StartupFrame    = 7,
	PostHitLockout  = 0.35,
	Cooldown        = 10,
}
_D.WINGCHUN.StartupSecs = _D.WINGCHUN.StartupFrame / _D.WINGCHUN.CounterFps

_D.WCTxn = {
	pending = false, sentAt = 0, openAt = 0, closeAt = 0,
	startupEma = nil, samples = 0, hits = 0, whiffs = 0,
	threat = nil, threatId = nil, style = nil,
	whiffStun = nil, holdSecs = nil, victimHitStun = nil,
}

local WingChunCounter = setmetatable({}, { __mode = "k" })

local function wingChunCounterActive(model)
	if not model then return false end
	local untilClock = WingChunCounter[model]
	return untilClock ~= nil and os.clock() < untilClock
end

-- Counter-stance styles: wingchun (V299) + aikido (V303). Both are
-- M2RequiresCounterHit in CombatConfig: no damage during the window,
-- whiff = long self-stun. Attacking into the stance is a free counter.
_D.COUNTER_STANCE = {
	wingchun = {
		Window   = 0.58,
		WhiffStun = 0.6,
		VictimHitStun = 2.8,
	},
	aikido = {
		Window   = 0.55,
		WhiffStun = 1.2,
		VictimHitStun = 2.3,
	},
}

local function counterStanceFor(sl)
	return _D.COUNTER_STANCE[sl]
end

-- Window length of a counter stance by style key; nil = not a stance style.
local function counterStanceWindow(cs)
	local c = _D.COUNTER_STANCE[cs]
	return c and c.Window or 0.55
end

local function isCounterStance(info, id)
	if not info or info.t ~= "M2" then return nil end
	local sl = string.lower(tostring(info.s or "")):gsub("[%s_%-]", "")
	local cs = counterStanceFor(sl)
	if not cs then return nil end
	local le = id and _D.LEGACY_ATTACKS[id]
	if le and le.counter then return cs end
	local nm = (info.name or ""):lower()
	if nm == "m2" or nm == "" then return cs end
	return nil
end

_D.LEGACY_M2_VARIANT = { M2 = "Left", M2Right = "Right", M2Left = "Left" }

_D.LEGACY_M1_OFFSETS = {
	ali      = {0.06, 0.15, 0.2, 0},
	basic    = {0.02, 0.02, 0.02, 0.02},
	boxing   = {0.02, 0.02, 0.02, 0.06},
	hakari   = {0.14, 0.16, 0.07, 0.17},
	hakario  = {0.14, 0.16, 0.07, 0.17},
	karate   = {0.0375, 0.075, 0.15, 0.225},
	capoeira = {0.02, 0.1, 0.02, -0.05},
	slugger  = {0.3, 0.25, 0.25, 0.17},
	wrestling= {0, 0.06, 0.09, 0.14},
	wingchun = {0, 0, 0, 0.4},
	striker  = {0, 0, -0.12, -0.23},
	cqc      = {0, 0, -0.1, 0.1},
	kickboxing = {-0.05, 0, 0.11, 0.22},
	kyokushin = {0, 0.08, 0.08, 0.3},
	mishima  = {0, -0.02, 0.12, 0.13},
	lethwei  = {0.12, 0.12, 0.05, 0},
}
_D.LEGACY_M1_BASE = { ali=0.22, karate=0.24, muaythai=0.30, slugger=0.20, capoeira=0.33,
                         hakari=0.21, hakario=0.21, wingchun=0.30, striker=0.35,
                         kure=0.32, wrestling=0.26, basic=0.32, boxing=0.32,
                         cqc=0.40, kickboxing=0.30, kyokushin=0.20,
                         mishima=0.20, lethwei=0.35 }
_D.LEGACY_M2_BASE = { ali=0.53, boxing=0.43, capoeira=0.45, hakari=0.35, hakario=0.35, karate=0.4875,
                         muaythai=0.60, slugger=0.82, wrestling=0.30, basic=0.525,
                         taekwondo=0.46, wild=0.525, bulky=0.43, dirty=0.30, wingchun=0.525,
                         skygaolang=0.35, variant=0.35, kure=0.30, striker=0.45,
                         cqc=0.50, kickboxing=0.30, kyokushin=0.82,
                         mishima=0.4167, lethwei=0.4333 }
_D.LEGACY_M2_MOM_BASE = { hakari=0.48, hakario=0.48 }
_D.WINDUP_EXTRA = 0.012
_D.COMBO_RESET  = 1.55

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local Stats             = game:GetService("Stats")

local LocalPlayer  = Players.LocalPlayer
local ServerRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Server")

local State = {
	blocking     = false,
	guardUp      = false,
	holdUntil    = 0,
	status       = "ARMED",
	lastThreat   = nil,
	parryCount   = 0,
	dodgeCount   = 0,
	grantEscapes = 0,
	selfBusyUntil= 0,
	attackBusyUntil = 0,
	kicksBlocked   = 0,
	reportsBlocked = 0,
	acMuted        = 0,
	acScript       = nil,
	desyncFires    = 0,
	fireCount    = 0,
	lastDodge    = -99,
	dodgeRejects = 0,
	swingAnimUntil = 0,
	threatNeutralized = 0,
	dodgeGateSaid = nil,
	lastDodgeInfo   = nil,
	aliM2CD = { char=nil, observed=false, active=false, known=false, started=0, duration=7 },
	dodgeTxn = { pending=false, confirmed=false, fire=0, lo=0, hi=0, untilAt=0, reason=nil },
	counterTxn = { seq=0, pending=false, confirmed=false, sent=0, ackDeadline=0,
		expectedIFramesAt=0, threat=nil, threatId=nil, source=nil, result=nil },
	lastDodgeRefuse = nil,
	lastAct      = -99,
	lastDeact    = -99,
	flashUntil   = 0,
	lastResult   = "—",
	lastErrMs    = 0,
	lastGapMs    = 0,
	tally        = { PERFECT=0, EARLY=0, LATE=0, GUARDBREAK=0 },
	vizTarget    = nil,
	faceGoalHRP   = nil,
	faceGoalHard  = false,
	faceGoalUntil = 0,
	faceHum       = nil,
	faceGoalPos   = nil,
	noParryActive = false,
	noParryNow    = false,
	interruptLockUntil = 0,
	m2Tally       = {},
}

local Threats = {}

	_D.FaceByResult = {}
	_D.ResidByKS    = {}
local ComboState = {}
local Pending = {}

local logTrim = LPH_NO_VIRTUALIZE(function(t, cap)
	local n = #t
	if n <= cap then return end
	local drop = n - cap
	if drop < 1 then return end
	table.move(t, drop + 1, n, 1)
	for i = n - drop + 1, n do t[i] = nil end
end)

-- Combat debug after Luraph: never pack `...` in a native proto (select/format of
-- varargs hitch the VM). Fixed arity + event-only lines. Default off.
_D.DiagLog, _D.DIAG_MAX = {}, 3500
_D.TraceLog, _D.TRACE_MAX = {}, 3500
local diagPush = LPH_NO_VIRTUALIZE(function(fmt, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24)
	if not Config.Debug then return end
	local line = string.format(fmt, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24)
	local log = _D.DiagLog
	log[#log + 1] = line
	logTrim(log, _D.DIAG_MAX)
end)
local diagTrace = LPH_NO_VIRTUALIZE(function(fmt, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24)
	if not (Config.Debug and Config.TraceDiag) then return end
	local line = string.format(fmt, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24)
	local log = _D.TraceLog
	log[#log + 1] = line
	logTrim(log, _D.TRACE_MAX)
end)
local function applyCombatDebug(on)
	on = on and true or false
	Config.Debug = on
	Config.DeepDiag = on
	if not on then
		Config.TraceDiag = false
		Config.PerfProbe = false
	else
		Config.PerfProbe = Config.TraceDiag and true or false
	end
end

_D.DesyncLog, _D.DESYNC_MAX = {}, 800
local function desyncPush(line)
	local stamped = string.format("t=%.2f  %s", os.clock(), line)
	_D.DesyncLog[#_D.DesyncLog+1] = stamped
	logTrim(_D.DesyncLog, _D.DESYNC_MAX)
end
_D.StatusLog, _D.STATUS_MAX = {}, 200
local function statusPush(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	local line = table.concat(parts, " ")
	_D.StatusLog[#_D.StatusLog + 1] = line
	logTrim(_D.StatusLog, _D.STATUS_MAX)
end

local function dbg(...)
	if Config.Debug then statusPush(...) end
end

local function aclog(...)
	statusPush(...)
end

_C.lastGoodPing = 0.08

local V93 = {
	frameDt   = 1/60,
	lookahead = 0,
	frameDtPeak = 1/60,
	lowFps    = false,
	stepCost  = 0,
	nearPress = math.huge,
	nearPressStamp = 0,
	vizLast   = 0,
	pingBuf   = {},
	pingBufN  = 0,
	pingBufI  = 0,
	gnpEma    = nil,
	gnpJit    = nil,
	gnpJumps  = 0,
	gnpLastSample = nil,
	uplinkSlow = nil,
	pingSampleClock = -1,
	pingCacheVal   = 0.08,
	pingMedTmp = {},
	hbFolder = nil,
	sizes = {},
	hbParams = nil,
	hbChar = nil,
	hbFrame = -1,
	hbKids = {},
	hbKidsN = 0,
	hbWatched = nil,
	byOwner = {},
	hbFirstSeen = setmetatable({}, { __mode = "k" }),
	hbClaimBySid = {},
	hbLiveSid = {},
	m1Streak = {},
	lastSwingAt = {},
	imminentBuf = {},
	clusterBuf  = {},
	faceBuf     = {},
	seenAttackers = {},
	threatSeen = {},
	interruptSeen = {},
	boxingM2Contacts = { 0.6000000, 1.0500000 },
	ownM1Info = { t = "M1", s = "Basic" },
	ownM2Info = { t = "M2", s = "Basic", mom = false, variant = nil },
	hbInfoScratch = { t = "M1", s = "Basic", mom = false, variant = nil, name = "hitbox" },
	sortByContact = function(a, b) return a.contactAbs < b.contactAbs end,
	dodgeParams = nil,
	dodgeChar = nil,
	lastWall = nil,
	lastStepClock = 0,
	schedulerSource = nil,
	pingRawClock = -1e9,
	gnpVal = nil,
	statsVal = nil,
	statsPingItem = nil,
	uplinkFrame = -1,
	uplinkVal = 0.08,
}

local samplePingSources = LPH_NO_VIRTUALIZE(function()
	local nowc = os.clock()
	if (nowc - V93.pingRawClock) < 0.12 then return end
	V93.pingRawClock = nowc
	local gnp = LocalPlayer:GetNetworkPing()
	if type(gnp) == "number" and gnp == gnp and gnp > 0 then
		V93.gnpVal = gnp
		-- V304: raw GNP jumps packet-to-packet; max(raw) at press time moved
		-- pressAt by 20-40ms within one swing. Smooth GNP with an EMA
		-- (~1s time constant) so uplink reflects sustained network state.
		local prev = V93.gnpLastSample
		V93.gnpLastSample = gnp
		if prev then
			local jump = gnp - prev
			V93.gnpJit = (V93.gnpJit or 0) * 0.9 + math.abs(jump) * 0.1
			if math.abs(jump) > 0.020 then V93.gnpJumps = (V93.gnpJumps or 0) + 1 end
		end
		local e = V93.gnpEma
		V93.gnpEma = e and (e * 0.88 + gnp * 0.12) or gnp
	end
	local item = V93.statsPingItem
	if item ~= false then
		if not item then
			local net = Stats:FindFirstChild("Network")
			if net then
				local ssi = net.ServerStatsItem
				item = ssi and ssi["Data Ping"]
				if item then V93.statsPingItem = item end
			end
		end
		-- StatsItem:GetValue is PluginSecurity. Executor threads throw
		-- "lacking capability Plugin"; one failure disables this source.
		if item then
			local ok, ms = pcall(item.GetValue, item)
			if not ok then
				V93.statsPingItem = false
			elseif type(ms) == "number" and ms == ms and ms > 1 then
				V93.statsVal = ms / 1000
			end
		end
	end
end)
local function pingDiagSnapshot()
	samplePingSources()
	return V93.gnpVal, V93.statsVal
end
local getPingRaw = LPH_NO_VIRTUALIZE(function()
	samplePingSources()
	local aRtt, bRtt = V93.gnpVal, V93.statsVal
	local best
	if bRtt and aRtt then
		local ratio = Config.PingSourceMaxRatio or 2.5
		best = (aRtt > bRtt * ratio) and bRtt or math.max(aRtt, bRtt)
	else
		best = bRtt or aRtt
	end
	if best and best > 0 then
		_C.lastGoodPing = math.clamp(best, 0.005, 1.5)
	end
	return _C.lastGoodPing
end)

local getPing = LPH_NO_VIRTUALIZE(function()
	local nowc = os.clock()
	if (nowc - V93.pingSampleClock) < (Config.PingSampleGap or 0.03) then
		return V93.pingCacheVal
	end
	V93.pingSampleClock = nowc

	local raw = getPingRaw()
	local win = math.max(3, Config.PingWindow or 24)
	V93.pingBufI = (V93.pingBufI % win) + 1
	V93.pingBuf[V93.pingBufI] = raw
	if V93.pingBufN < win then V93.pingBufN = V93.pingBufN + 1 end

	local n = V93.pingBufN
	local tmp = V93.pingMedTmp
	for i = 1, n do tmp[i] = V93.pingBuf[i] end
	for i = n + 1, #tmp do tmp[i] = nil end
	table.sort(tmp)
	local med
	if n % 2 == 1 then med = tmp[(n + 1) // 2]
	else med = (tmp[n // 2] + tmp[n // 2 + 1]) * 0.5 end

	V93.pingCacheVal = math.min(med, Config.PingCap)
	return V93.pingCacheVal
end)

local uplink = LPH_NO_VIRTUALIZE(function()
	if V93.uplinkFrame == _C.FrameId then return V93.uplinkVal end
	local med = getPing()
	local raw = getPingRaw()
	local ping = (raw > med) and raw or med
	local up = ping * (Config.UplinkFactor or 0.5) + (Config.UplinkMargin or 0.008)
	if Config.UplinkPreferGnpOneWay ~= false then
		-- V304: prefer the SMOOTHED GNP EMA over the raw sample. The raw
		-- GNP spikes frame-to-frame and max(raw) dragged pressAt around;
		-- EMA tracks sustained latency, which is what the press needs.
		local ema = V93.gnpEma
		if type(ema) == "number" and ema > 0 then
			up = math.max(up, ema)
		else
			local gnp, stats = V93.gnpVal, V93.statsVal
			if type(gnp) == "number" and gnp > 0 then
				up = math.max(up, gnp)
			end
			if type(stats) == "number" and stats > 0 then
				up = math.max(up, stats * 0.5)
			end
		end
		local stats = V93.statsVal
		if type(stats) == "number" and stats > 0 then
			up = math.max(up, stats * 0.5)
		end
	end
	up = math.clamp(up, Config.UplinkMin, Config.UplinkMax)
	-- V304: a smoothed estimate is allowed to rise fast but fall slowly —
	-- a single clean GNP sample after a spike must not yank pressAt later.
	local slow = V93.uplinkSlow
	V93.uplinkSlow = (slow and slow > up) and (slow * 0.85 + up * 0.15) or up
	local thr = Config.LowPingThresh or 0
	if thr > 0 and ping < thr then
		up = up + (Config.LowPingFloor or 0) * (1 - ping / thr)
	end
	V93.uplinkFrame = _C.FrameId
	V93.uplinkVal = up
	return up
end)

local localChar = LPH_NO_VIRTUALIZE(function() return LocalPlayer.Character end)

local planarDist = LPH_NO_VIRTUALIZE(function(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end)

local verticalOk = LPH_NO_VIRTUALIZE(function(aPos, myPos, extra)
	if not (aPos and myPos) then return false end
	local ay, my = aPos.Y, myPos.Y
	if type(ay) ~= "number" or type(my) ~= "number" then return false end
	local maxYd = (Config.MaxHeightDiff or 8) + (extra or 0)
	return math.abs(ay - my) <= maxYd
end)

local localTorsoHalf = LPH_NO_VIRTUALIZE(function()
	if _C.torsoFrame == _C.FrameId then return _C.torsoVal end
	_C.torsoFrame = _C.FrameId
	local c = localChar()
	local val = 1.5
	if c then
		local p = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
		if p and p:IsA("BasePart") then
			val = math.max(p.Size.X, p.Size.Z) * 0.5
		end
	end
	_C.torsoVal = val
	return val
end)

local localHeightYBudget = LPH_NO_VIRTUALIZE(function()
	if _C.hyFrame == _C.FrameId then return _C.hyVal end
	_C.hyFrame = _C.FrameId
	local val = 0
	local y = _C.extY
	if _C.extFrame ~= _C.FrameId then
		y = nil
		local c = localChar()
		if c then
			y = c:GetExtentsSize().Y
			_C.extFrame, _C.extModel, _C.extY = _C.FrameId, c, y
		end
	end
	if type(y) == "number" and y > 5.5 then
		val = (y - 5.5) * 0.5
	end
	_C.hyVal = val
	return val
end)

_C.index = function(o, k) return o[k] end
V93.humMove = function(hum, dir) return hum:Move(dir, false) end
local safeGet = function(o, k, default)
	if o == nil then return default end
	local v = o[k]
	if v ~= nil then return v end
	return default
end

_C.FrameId = 0
_C.hrpCache, _C.hrpFrame = nil, -1
local localHRP = LPH_NO_VIRTUALIZE(function()
	if _C.hrpFrame == _C.FrameId and _C.hrpCache and _C.hrpCache.Parent then return _C.hrpCache end
	local c = localChar()
	_C.hrpCache = (c and c:FindFirstChild("HumanoidRootPart")) or nil
	_C.hrpFrame = _C.FrameId
	return _C.hrpCache
end)

_D.HARD_BLOCKERS = { "BlockCooldown", "Ragdoll", "Downed", "Greenzone",
                        "RpCombatLocked", "StaffModPeaceMode", "Grappling" }
local parryBufferedNow = LPH_NO_VIRTUALIZE(function(c)
	if Config.ComboEscape == false then return false end
	c = c or localChar()
	if not c then return false end
	if _C.pbFrame == _C.FrameId and _C.pbChar == c then return _C.pbVal end
	local ok = c:GetAttribute("ParryBuffered")
		and not c:GetAttribute("ParryWindowDisabled")
		and not c:GetAttribute("GuardBroken") and true or false
	_C.pbFrame, _C.pbChar, _C.pbVal = _C.FrameId, c, ok
	return ok
end)

-- Очередь нажатия в стане. Жёсткий отказ: GuardBroken / Ragdoll / Downed /
-- ParryWindowDisabled / Grappling. Свой M1/M2 (CantAnything без Stunned) —
-- не буфер. CombatRecovery без своей атаки — игра снова принимает Block.
local stunEscapeNow = LPH_NO_VIRTUALIZE(function(c)
	if Config.ComboEscape == false then return false end
	c = c or localChar()
	if not c then return false end
	if _C.seFrame == _C.FrameId and _C.seChar == c then return _C.seVal end
	local ok = false
	if c:GetAttribute("ParryWindowDisabled") then
		ok = false
	elseif c:GetAttribute("GuardBroken") then
		ok = false
	elseif c:GetAttribute("Ragdoll") or c:GetAttribute("Downed") then
		ok = false
	elseif c:GetAttribute("Grappling") then
		ok = false
	elseif c:GetAttribute("Stunned") then
		ok = true
	elseif c:GetAttribute("CantAnything") and c:GetAttribute("CombatRecovery") then
		if not (c:GetAttribute("CombatAttacking") or c:GetAttribute("M1") or c:GetAttribute("M2")) then
			ok = true
		end
	end
	_C.seFrame, _C.seChar, _C.seVal = _C.FrameId, c, ok
	return ok
end)

-- Block.Activated во время своего M2 срывает iframes контры (V178/V198).
-- Пока txn.pending — не жать парирование. После confirm follow-up снова в парри.
local counterBusyNow = LPH_NO_VIRTUALIZE(function()
	local tx = State.counterTxn
	return tx ~= nil and tx.pending and true or false
end)

local canBlockNow = LPH_NO_VIRTUALIZE(function()
	local c = localChar()
	if not c then return false, "no-char" end
	if Config.RequireEquip ~= false and not c:GetAttribute("Equip") then
		return false, "Unequip"
	end
	if stunEscapeNow(c) then
		if not parryBufferedNow(c) then
			if c:GetAttribute("Stunned") then return false, "Stunned" end
			return false, "CantAnything"
		end
		for _, attr in ipairs(_D.HARD_BLOCKERS) do
			if attr ~= "BlockCooldown" and c:GetAttribute(attr) then
				return false, attr
			end
		end
		return true, nil
	end
	-- Свой M1/CombatAttacking даёт CantAnything без стана. V204 на этом
	-- молчал (Boxing M2 → HIT). Блок снимает M1; свой M2/контру не рвём.
	if c:GetAttribute("CantAnything")
	   and not c:GetAttribute("M2")
	   and not c:GetAttribute("PendingM2")
	   and not counterBusyNow()
	   and not c:GetAttribute("GuardBroken")
	   and not c:GetAttribute("Ragdoll")
	   and not c:GetAttribute("Downed")
	   and not c:GetAttribute("Grappling")
	   and not c:GetAttribute("ParryWindowDisabled") then
		return true, nil
	end
	if Config.BlockCooldownPredict ~= false then
	local nowB = os.clock()
	local rearm = State.allowRearmUntil
	local multiR = State.multiRearmUntil
	if not ((type(rearm) == "number" and nowB < rearm)
		or (type(multiR) == "number" and nowB < multiR)) then
		local rel = State.lastBlockRelease or State.lastPress
		if rel then
			local cd = Config.BlockCooldown or 0.5
			local ready = rel + cd + (Config.BlockCooldownSafety or 0.03)
			if nowB < ready then return false, "BlockCooldown" end
		end
	end
	end
	do
	local nowB = os.clock()
	local skipCd = (type(State.allowRearmUntil) == "number" and nowB < State.allowRearmUntil)
		or (type(State.multiRearmUntil) == "number" and nowB < State.multiRearmUntil)
	for _, attr in ipairs(_D.HARD_BLOCKERS) do
		if not (skipCd and attr == "BlockCooldown") and c:GetAttribute(attr) then
			return false, attr
		end
	end
	end
	if c:GetAttribute("Stunned") or c:GetAttribute("CantAnything") then
		return false, c:GetAttribute("Stunned") and "Stunned" or "CantAnything"
	end
	return true, nil
end)

local blockStamina = LPH_NO_VIRTUALIZE(function()
	local c = localChar()
	if not c then return nil end
	for _, name in ipairs(Config.StaminaAttrs) do
		local v = c:GetAttribute(name)
		if type(v) == "number" and v >= 0 and v <= 1000 then return v end
	end
	for _, name in ipairs(Config.StaminaAttrs) do
		local obj = c:FindFirstChild(name)
		if obj and (obj:IsA("NumberValue") or obj:IsA("IntValue")) then return obj.Value end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		for _, name in ipairs(Config.StaminaAttrs) do
			local obj = hum:FindFirstChild(name)
			if obj and (obj:IsA("NumberValue") or obj:IsA("IntValue")) then return obj.Value end
		end
	end
	return nil
end)

local function ownerOf(animator)
	local p = animator.Parent
	if p and (p:IsA("Humanoid") or p:IsA("AnimationController")) then return p.Parent end
	return p
end

local isEnemyModel = LPH_NO_VIRTUALIZE(function(model)
	if not model or model == localChar() then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return false end
	local plr = Players:GetPlayerFromCharacter(model)
	if plr then
		if plr == LocalPlayer then return false end
		local wl = Config.ParryWhitelist
		if type(wl) == "table" and wl[plr.Name] == true then return false end
		return true, hrp
	end
	if Config.IncludeNPCs then return true, hrp end
	return false
end)

local function flatDirTo(fromPos, targetPos)
	local d = Vector3.new(targetPos.X - fromPos.X, 0, targetPos.Z - fromPos.Z)
	if d.Magnitude < 0.05 then return nil end
	return d.Unit
end

local function faceDotToThreat(th)
	local a = th and th.attackerHRP
	local targetPos = (a and a.Parent) and a.Position or nil
	local myHRP = localHRP()
	if not myHRP or not targetPos then return nil end
	local dir = flatDirTo(myHRP.Position, targetPos)
	if not dir then return 1 end
	local look = myHRP.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.05 then return nil end
	return flatLook.Unit:Dot(dir)
end

local function heavyRank(th)
	local k = th and th.kind
	if k == "SKILL" then return 2 end
	if k == "M2" then return 1 end
	return 0
end

local aimedAtMe = LPH_NO_VIRTUALIZE(function(th)
	if not th then return false end
	if th.kind == "M2" and type(th.geomDist2d) == "number" and th.geomDist2d <= (Config.Range or 18) then
		return true
	end
	if not th.threatens then return false end
	if th.offTarget then return false end
	if Config.FaceOnlyRealThreats == false then return true end
	if th.trustedHit then return true end
	return not th.geomLatched
end)

local computeMultiFaceGoal = LPH_NO_VIRTUALIZE(function()
	if not Config.AutoFace then return nil end
	local nThreat = 0
	for _, th in ipairs(Threats) do
		if aimedAtMe(th) and th.attackerHRP and th.attackerHRP.Parent then
			nThreat = nThreat + 1
			if nThreat >= 2 then break end
		end
	end
	if nThreat < 2 then return nil end

	local me = localHRP(); if not me then return nil end
	local mePos = me.Position
	local flatMe = me.CFrame.LookVector; flatMe = Vector3.new(flatMe.X, 0, flatMe.Z)
	flatMe = flatMe.Magnitude > 0.05 and flatMe.Unit or Vector3.new(0, 0, 1)
	local t = V93.faceBuf
	local n = 0
	for _, th in ipairs(Threats) do
		if aimedAtMe(th) and th.attackerHRP and th.attackerHRP.Parent then
			local to = th.attackerHRP.Position - mePos
			local d = Vector3.new(to.X, 0, to.Z)
			local dist = d.Magnitude
			if dist > 0.05 then
				d = d.Unit
				n = n + 1
				local e = t[n]
				if not e then e = {}; t[n] = e end
				e.k = th.attackerModel or th.attackerHRP or th.name
				e.dir = d
				e.dist = dist
				e.front = flatMe:Dot(d) > 0.05
			end
		end
	end
	for i = #t, n + 1, -1 do t[i] = nil end
	if n < 2 then return nil end
	local best, bestAng = nil, nil
	local maxA = math.rad(Config.MultiFaceAngleMax or 70)
	for i = 1, #t-1 do for j = i+1, #t do
		local a, b = t[i], t[j]
		if a.k ~= b.k then
			local ok = (not Config.MultiFaceOnlyFront) or (a.front and b.front)
			if ok then
				local ang = math.acos(math.clamp(a.dir:Dot(b.dir), -1, 1))
				if ang <= maxA and (bestAng == nil or ang < bestAng) then
					bestAng = ang; best = {a, b}
				end
			end
		end
	end end
	if not best then return nil end
	local a, b = best[1], best[2]
	local bis = a.dir + b.dir
	if bis.Magnitude < 0.05 then return nil end
	bis = bis.Unit
	local td = math.min(a.dist, b.dist) + math.abs(a.dist - b.dist)*0.35
	local base = mePos + bis*td
	local j = (Config.MultiFaceJitter or 0.30)
	local side = (math.sin((_C.FrameId % 12)/12 * math.pi * 2) + 1) * 0.5
	local perp = Vector3.new(-bis.Z, 0, bis.X)
	return base + perp * (math.min(a.dist, b.dist) * j * (side - 0.5) * 2)
end)

local function snapLookAtThreat(th)
	if not Config.AutoFace then return end
	local myHRP = localHRP()
	local a = th and th.attackerHRP
	if not myHRP or not a or not a.Parent then return end
	local dir = flatDirTo(myHRP.Position, a.Position)
	if not dir then return end
	myHRP.CFrame = CFrame.lookAt(myHRP.Position, myHRP.Position + dir)
end

local setFaceGoalPos = LPH_NO_VIRTUALIZE(function(pos, hard, holdFor)
	if not Config.AutoFace then return end
	if not pos then return end
	State.faceGoalHRP = nil
	State.faceGoalPos = pos
	State.faceGoalHard = hard and true or false
	State.faceGoalUntil = os.clock() + (holdFor or 0.15)
end)

local setFaceGoal = LPH_NO_VIRTUALIZE(function(targetHRP, hard, holdFor)
	if not Config.AutoFace then return end
	if not targetHRP or not targetHRP.Parent then return end
	State.faceGoalHRP   = targetHRP
	State.faceGoalHard  = hard and true or false
	State.faceGoalUntil = os.clock() + (holdFor or 0.15)
end)

local styleForward
local styleStepForward
local hitboxSizeMult
local registryKind

_C.FaceTrack = setmetatable({}, { __mode = "k" })
local attackerPrevPos = LPH_NO_VIRTUALIZE(function(aHRP)
	local rec = _C.FaceTrack[aHRP]
	if rec then return rec.pos, rec.t end
	return nil, nil
end)

local attackerSamplePos = LPH_NO_VIRTUALIZE(function(aHRP)
	if not aHRP then return end
	local rec = _C.FaceTrack[aHRP]
	if rec then rec.t, rec.pos = os.clock(), aHRP.Position
	else _C.FaceTrack[aHRP] = { t = os.clock(), pos = aHRP.Position } end
end)

local sampleNearbyHRPs = LPH_NO_VIRTUALIZE(function()
	local me = localHRP()
	if not me then return end
	for i = 1, #Threats do
		local h = Threats[i].attackerHRP
		if h then attackerSamplePos(h) end
	end
end)

-- Сближение в XZ: физика часто врёт на дэше (CFrame / 0 AssemblyLinearVelocity).
-- Берём max(физика, смещение с прошлого кадра).
local planarClosing = LPH_NO_VIRTUALIZE(function(aHRP, meHRP, th)
	if not (aHRP and aHRP.Parent and meHRP and meHRP.Parent) then return 0 end
	local aPos, mPos = aHRP.Position, meHRP.Position
	local dx, dz = mPos.X - aPos.X, mPos.Z - aPos.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 0.05 then return 0, dist end
	local ux, uz = dx / dist, dz / dist
	local closing = 0
	local av = aHRP.AssemblyLinearVelocity
	local mv = meHRP.AssemblyLinearVelocity
	if av and mv then
		closing = (av.X - mv.X) * ux + (av.Z - mv.Z) * uz
	elseif av then
		closing = av.X * ux + av.Z * uz
	end
	local pp, pt = th and th.prevPos, th and th.prevPosT
	if not (pp and pt) then
		local rec = _C.FaceTrack[aHRP]
		if rec then pp, pt = rec.pos, rec.t end
	end
	if pp and pt then
		local dt = os.clock() - pt
		if dt > 1e-3 and dt < 0.4 then
			local pdx, pdz = pp.X - mPos.X, pp.Z - mPos.Z
			local prevD = math.sqrt(pdx * pdx + pdz * pdz)
			local meas = (prevD - dist) / dt
			if meas > closing then closing = meas end
		end
	end
	return closing, dist
end)

local function watchHitboxFolder(folder)
	if folder == V93.hbWatched then return end
	V93.hbWatched = folder
	local kids, n = V93.hbKids, 0
	for i = 1, (V93.hbKidsN or 0) do kids[i] = nil end
	for _, child in ipairs(folder:GetChildren()) do
		n = n + 1
		kids[n] = child
	end
	V93.hbKidsN = n
	folder.ChildAdded:Connect(function(c)
		local k, nn = V93.hbKids, (V93.hbKidsN or 0) + 1
		k[nn] = c
		V93.hbKidsN = nn
		V93.hbFrame = -1
		local ingest = State.ingestHitbox
		if ingest then
			task.defer(function()
				ingest(c)
				if not (c:FindFirstChild("Owner") and c:FindFirstChild("AttackName")) then
					task.delay(0.06, ingest, c)
				end
			end)
		end
	end)
	folder.ChildRemoved:Connect(function(c)
		local k, nn = V93.hbKids, V93.hbKidsN or 0
		for i = 1, nn do
			if k[i] == c then
				k[i] = k[nn]
				k[nn] = nil
				V93.hbKidsN = nn - 1
				break
			end
		end
		V93.hbFrame = -1
	end)
end

local hitboxIndex = LPH_NO_VIRTUALIZE(function()
	if V93.hbFrame == _C.FrameId then return V93.byOwner end
	V93.hbFrame = _C.FrameId
	local byOwner = V93.byOwner
	for k in pairs(byOwner) do byOwner[k] = nil end
	local liveSid = V93.hbLiveSid
	for k in pairs(liveSid) do liveSid[k] = nil end
	local folder = V93.hbFolder
	if not (folder and folder.Parent) then
		folder = Workspace:FindFirstChild("Hitboxes")
		V93.hbFolder = folder
	end
	if not folder then return byOwner end
	if folder ~= V93.hbWatched then watchHitboxFolder(folder) end
	local kids, nKids = V93.hbKids, V93.hbKidsN or 0
	for idx = 1, nKids do
		if idx > 60 then break end
		local child = kids[idx]
		if child and child:IsA("BasePart") then
			local sidNow = child:GetAttribute("VictimSwingId")
			local seenRec = V93.hbFirstSeen[child]
			if not seenRec or seenRec.sid ~= sidNow then
				seenRec = { sid = sidNow, t = os.clock() }
				V93.hbFirstSeen[child] = seenRec
			end
			local owner = child:FindFirstChild("Owner")
			local atk   = child:FindFirstChild("AttackName")
			if owner and atk and owner:IsA("StringValue") and atk:IsA("StringValue") then
				local sid = sidNow
				if typeof(sid) == "string" and sid ~= "" then
					liveSid[sid] = true
					local aType = atk.Value
					if aType == "M1" or aType == "M2" then V93.sizes[aType] = child.Size end
					local nm  = owner.Value
					local lst = byOwner[nm]
					if not lst then lst = {}; byOwner[nm] = lst end
					lst[#lst + 1] = child
				end
			end
		end
	end
	for sid in pairs(V93.hbClaimBySid) do
		if not liveSid[sid] then V93.hbClaimBySid[sid] = nil end
	end
	return byOwner
end)

local associatedHitbox = LPH_NO_VIRTUALIZE(function(th)
	if th.serverHitbox and th.serverHitbox.Parent then return th.serverHitbox end
	local lst = hitboxIndex()[th.name]
	if not lst then return nil end
	local best, bestScore
	for i = 1, #lst do
		local part = lst[i]
		local atk = part and part:FindFirstChild("AttackName")
		local sid = part and part:GetAttribute("VictimSwingId")
		if part.Parent and atk and atk:IsA("StringValue") and atk.Value == th.kind
			and typeof(sid) == "string" and sid ~= "" then
			local owner = V93.hbClaimBySid[sid]
			local claimKey = th.group or th
			if owner == nil or owner == claimKey then
				local seenRec2 = V93.hbFirstSeen[part]
				local seen = (seenRec2 and seenRec2.sid == sid and seenRec2.t) or os.clock()
				local lookback = Config.HitboxLookbackSec or 0.55
				local c0 = th.contact0 or 0
				-- Strike 2 (Boxing M2 1050ms) must not look back a full second:
				-- the first hitbox of the same swing was bound to s2 (+687→+20),
				-- strike 1 never pressed.
				if (th.strike or 1) <= 1 and c0 > lookback then
					lookback = math.min(c0 + 0.08, 0.72)
				end
				if seen >= th.detectClock - lookback then
					local expect = th.contactAbs or (th.detectClock + c0)
					if (th.strike or 1) >= 2 and seen < expect - 0.28 then
						-- first-hit box of this swing, not this strike
					else
						local score = math.abs(seen - expect)
						if not bestScore or score < bestScore then best, bestScore = part, score end
					end
				end
			end
		end
	end
	if best then
		local sid = best:GetAttribute("VictimSwingId")
		V93.hbClaimBySid[sid] = th.group or th
		th.serverHitbox, th.serverSwingId = best, sid
		local bestSeen = V93.hbFirstSeen[best]
		th.hbFirstClock = (bestSeen and bestSeen.sid == sid and bestSeen.t) or os.clock()
		th.hbFirstServer = Workspace:GetServerTimeNow()
		th.hbFirstPos, th.hbFirstSize = best.Position, best.Size
		if th.group then
			th.group.serverHitbox, th.group.serverSwingId = best, sid
			th.group.hbFirstClock = th.hbFirstClock
		end
		if Config.HitboxRetime ~= false and th.contactAbs then
			local nowHb = os.clock()
			local hbLead = Config.HitboxContactLead or 0.02
			local hbContact = th.hbFirstClock + hbLead
			-- First-seen давно в прошлом: это поздняя привязка анимации к уже
			-- живому хитбоксу, а не контакт 200мс назад. Контакт = сейчас.
			if (nowHb - (th.hbFirstClock or nowHb)) > 0.15 then
				hbContact = nowHb + hbLead
			end
			local minShift = Config.HitboxRetimeMinMs or 40
			local meH, aH = localHRP(), th.attackerHRP
			if meH and aH and aH.Parent then
				local hdx, hdz = meH.Position.X - aH.Position.X, meH.Position.Z - aH.Position.Z
				if hdx * hdx + hdz * hdz <= 81 then minShift = 18 end
			end
			local shiftMs = (hbContact - th.contactAbs) * 1000
			local pminR = Config.PerfectMin or 0.05
			local upHb = uplink()
			local hbRemain = hbContact - nowHb
			-- HB-KEEP по остатку АНИМАЦИИ пропускал ранний хитбокс
			-- (V214: meas=219 pred=335 LATE). Контакт всегда двигаем;
			-- rearm только если второе нажатие ещё может попасть в окно.
			if math.abs(shiftMs) >= minShift then
				local oldContact = th.contactAbs
				th.contactAbs = hbContact
				th.hbContactAbs = hbContact
				th.contactRetimed = true
				if th.group then th.group.contactAbs = hbContact end
				if shiftMs < 0 then
					local canRearm = hbRemain > (upHb + pminR + 0.02)
					if canRearm then
						th.pressed = nil
						if th.group then th.group.pressed = nil end
						th.hbEarlyRearm = true
						State.allowRearmUntil = os.clock() + 0.14
						diagPush("HB-RETIME t=%.2f %s %s контакт %+.0fms→%+.0fms (хитбокс РАНЬШЕ таблицы — пересчёт)",
							os.clock(), tostring(th.name), tostring(th.kind),
							(oldContact - os.clock()) * 1000, (hbContact - os.clock()) * 1000)
					else
						diagPush("HB-RETIME t=%.2f %s %s контакт %+.0fms→%+.0fms (хитбокс раньше, rearm не успеет)%s",
							os.clock(), tostring(th.name), tostring(th.kind),
							(oldContact - os.clock()) * 1000, (hbContact - os.clock()) * 1000,
							th.pressed and " hold" or "")
					end
				else
					-- Хитбокс в кадре контакта: повторное нажатие не доезжает.
					diagPush("HB-RETIME t=%.2f %s %s контакт %+.0fms→%+.0fms (удар задержан: хитбокс появился только сейчас)%s",
						os.clock(), tostring(th.name), tostring(th.kind),
						(oldContact - os.clock()) * 1000, (hbContact - os.clock()) * 1000,
						th.pressed and " hold" or "")
				end
			end
		end

		if Config.TraceDiag then
			diagTrace("TRACE-HB t=%.3f %s %s s%d sid=%s first=%+.0fms toPred=%+.0fms pos=(%.1f,%.1f,%.1f) size=(%.1f,%.1f,%.1f)", os.clock(), th.name or "?", th.kind or "?", th.strike or 1, tostring(sid),
				(th.hbFirstClock - th.detectClock)*1000, ((th.contactAbs or th.hbFirstClock)-th.hbFirstClock)*1000,
				best.Position.X, best.Position.Y, best.Position.Z, best.Size.X, best.Size.Y, best.Size.Z)
		end
	end
	return best
end)

local realHitboxHitsMe = LPH_NO_VIRTUALIZE(function(ownerName, th)
	if th and th.gtQueryFrame == _C.FrameId then return th.gtQueryResult end
	if not ownerName or not th then return nil end
	local part = (th.group and th.group.serverHitbox) or th.serverHitbox or associatedHitbox(th)
	if not (part and part.Parent) then
		th.gtQueryFrame, th.gtQueryResult = _C.FrameId, nil
		return nil
	end
	local char = localChar()
	if not char then return nil end
	local params = V93.hbParams
	if not params then
		params = OverlapParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.MaxParts = 1
		V93.hbParams = params
	end
	if V93.hbChar ~= char then params.FilterDescendantsInstances = { char }; V93.hbChar = char end

	if Config.PerfProbe then V93.probeGPBB = (V93.probeGPBB or 0) + 1 end
	local realHit = #Workspace:GetPartBoundsInBox(part.CFrame, part.Size, params) > 0
	if realHit and not th.hbOverlapClock then
		th.hbOverlapClock, th.hbOverlapServer = os.clock(), Workspace:GetServerTimeNow()
		local my = localHRP()
		local av = th.attackerHRP and th.attackerHRP.AssemblyLinearVelocity or Vector3.zero
		local mv = my and my.AssemblyLinearVelocity or Vector3.zero
		diagTrace("TRACE-OV t=%.3f %s %s s%d sid=%s detect=%+.0fms predErr=%+.0fms av=(%.1f,%.1f) mv=(%.1f,%.1f)", th.hbOverlapClock, th.name or "?", th.kind or "?", th.strike or 1,
				tostring(th.serverSwingId or (th.group and th.group.serverSwingId) or "none"),
				(th.hbOverlapClock-th.detectClock)*1000,
				(th.hbOverlapClock-(th.contactAbs or th.hbOverlapClock))*1000,
				av.X, av.Z, mv.X, mv.Z)
	end

	local hit = realHit
	if not hit then
		local remain = (th.contactAbs or os.clock()) - os.clock()
		if remain <= 0.26 then
		local leadTime = getPing() + (Config.OverlapReaction or 0.050)
		local sp = 0
		local pv = part.AssemblyLinearVelocity
		if pv then sp = math.sqrt(pv.X * pv.X + pv.Z * pv.Z) end
		local ah = th.attackerHRP
		if ah and ah.Parent then
			local apv = ah.AssemblyLinearVelocity
			if apv then local asp = math.sqrt(apv.X * apv.X + apv.Z * apv.Z); if asp > sp then sp = asp end end
			local closing = planarClosing(ah, localHRP(), th)
			if closing > sp then sp = closing end
		end
		local lead = math.clamp((Config.OverlapLeadBase or 2.0) + sp * leadTime, 0, Config.OverlapLeadCap or 18.0)
		local yPad = math.min(lead, 1.25)
		local infl = part.Size + Vector3.new(lead * 2, yPad, lead * 2)
		if Config.PerfProbe then V93.probeGPBB = (V93.probeGPBB or 0) + 1 end
		hit = #Workspace:GetPartBoundsInBox(part.CFrame, infl, params) > 0
		if hit and not th.gtLeadClock then
			th.gtLeadClock = os.clock()
			diagTrace("TRACE-LEAD t=%.3f %s %s s%d lead=%.1f sp=%.1f ping=%.0fms toContact=%+.0fms", th.gtLeadClock, th.name or "?", th.kind or "?", th.strike or 1,
					lead, sp, getPing() * 1000, ((th.contactAbs or th.gtLeadClock) - th.gtLeadClock) * 1000)
		end
		end
	end
	th.gtQueryFrame, th.gtQueryResult = _C.FrameId, hit
	return hit
end)

local hitboxNearestPart = LPH_NO_VIRTUALIZE(function(ownerName, kind)
	if not ownerName then return nil, nil end
	local lst = hitboxIndex()[ownerName]
	if not lst or #lst == 0 then return nil, nil end
	local me = localHRP()
	if not me then return nil, nil end
	local best, bestD = nil, math.huge
	for i = 1, #lst do
		local part = lst[i]
		local atk = part and part:FindFirstChild("AttackName")
		if part.Parent and atk and atk:IsA("StringValue") and (not kind or atk.Value == kind) then
			local d = (part.Position - me.Position).Magnitude
			if d < bestD then bestD = d; best = part end
		end
	end
	return best, bestD
end)

local syncContactWithHitbox = LPH_NO_VIRTUALIZE(function(th, now)
	if not Config.HitboxDodge then return end
	if (th.strike or 1) > 1 then return end
	if th.dodged or th.hitboxSynced then return end
	local remain = (th.contactAbs or now) - now
	if remain > 0.22 then return end
	local part = hitboxNearestPart(th.name, th.kind)
	if not part then return end
	if not th.hitboxSeen then
		th.hitboxSeen, th.hitboxPart = now, part
	end
	if realHitboxHitsMe(th.name, th) == true then
		th.gtConfirmed, th.hitboxSynced = true, true
	end
end)

local clampLeadToVictim = LPH_NO_VIRTUALIZE(function(lead, aPos, mePos)
	local d = Vector3.new(aPos.X - mePos.X, 0, aPos.Z - mePos.Z).Magnitude
	local maxLead = d * (Config.WillHitLeadFrac or 0.90)
	if lead.Magnitude <= maxLead then return lead end
	if maxLead <= 1e-3 then return Vector3.zero end
	return lead.Unit * maxLead
end)

local hitboxGeom = LPH_NO_VIRTUALIZE(function(th)
	if th.geomFrame == _C.FrameId then
		return th.geomC, th.geomF, th.geomP, th.geomL
	end
	local aHRP = th.attackerHRP
	if not aHRP or not aHRP.Parent then th.geomFrame = _C.FrameId; th.geomC = nil; return nil end
	local now  = os.clock()
	local tHit = math.clamp((th.contactAbs or now) - now, 0, 0.6)
	local aPos = aHRP.Position
	local meG = localHRP()
	local closing, distToMe = planarClosing(aHRP, meG, th)
	th.closeVel = closing
	th.geomDist2d = distToMe
	local aV = aHRP.AssemblyLinearVelocity
	local lead = Vector3.new((aV and aV.X or 0) * tHit, 0, (aV and aV.Z or 0) * tHit)
	if meG then
		local toMeG = Vector3.new(meG.Position.X - aPos.X, 0, meG.Position.Z - aPos.Z)
		if toMeG.Magnitude > 0.05 then
			toMeG = toMeG.Unit
			local closeAmt = math.max(0, closing) * tHit
			local leadDot  = lead:Dot(toMeG)
			local latVec   = lead - toMeG * leadDot
			local latCap   = Config.WillHitLatCap or 8.0
			if latVec.Magnitude > latCap then latVec = latVec.Unit * latCap end
			local closeCap = math.min(Config.WillHitCloseCap or 14, distToMe * 0.95)
			closeAmt = math.clamp(closeAmt, 0, closeCap)
			lead = toMeG * closeAmt + latVec
			lead = clampLeadToVictim(lead, aPos, meG.Position)
		else
			local cap = Config.WillHitVelCap or 8.0
			if lead.Magnitude > cap then lead = lead.Unit * cap end
			lead = clampLeadToVictim(lead, aPos, meG.Position)
		end
	else
		local cap = Config.WillHitVelCap or 8.0
		if lead.Magnitude > cap then lead = lead.Unit * cap end
	end
	local predA = Vector3.new(aPos.X + lead.X, 0, aPos.Z + lead.Z)
	local look = aHRP.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	-- Dragon M2RootLock / aerial M2: LookVector is (0,1,0), flat=0, geom nil
	-- → V280 source=none NO-PRESS. Aim at victim on the plane.
	if flatLook.Magnitude < 0.05 then
		if meG then
			local toMeL = Vector3.new(meG.Position.X - aPos.X, 0, meG.Position.Z - aPos.Z)
			if toMeL.Magnitude > 0.05 then
				flatLook = toMeL
			end
		end
	end
	if flatLook.Magnitude < 0.05 then return nil end
	flatLook = flatLook.Unit

	local forward = styleForward(th.style, th.kind)
	                or ((th.kind == "M2") and Config.M2Forward or Config.M1Forward)
	do
		local st = styleStepForward(th.style, th.kind, th.combo)
		if type(st) == "number" and st > 0 then
			forward = forward + st
			th.geomStep = st
		end
	end
	if th.kind == "M2" then
		local ok, go = pcall(_C.grabOffFn, th.style)
		if ok and type(go) == "number" and go > 0 then
			forward = forward + go
			th.geomGrab = go
		end
	end

	-- Не сэмплируем FaceTrack здесь: иначе velLead в этом же кадре видит dt≈0
	-- и CFrame-дэш даёт closing=0. Сэмпл — в конце кадра (sampleNearbyHRPs).
	local prevPos, prevT = attackerPrevPos(aHRP)
	th.prevPos  = prevPos
	th.prevPosT = prevT

	do
		local nowT = os.clock()
		local pl, plT = th.prevLook, th.prevLookT
		if pl and plT then
			local dt = nowT - plT
			if dt > 1e-3 and dt < 0.5 then
				local d = math.clamp(pl.X * flatLook.X + pl.Z * flatLook.Z, -1, 1)
				local rate = math.acos(d) / dt
				th.turnRate = th.turnRate and (th.turnRate * 0.5 + rate * 0.5) or rate
			end
		end
		th.prevLook, th.prevLookT = flatLook, nowT
	end

	local center = predA + flatLook * forward
	th.geomFrame, th.geomC, th.geomF, th.geomP, th.geomL = _C.FrameId, center, forward, predA, flatLook
	return center, forward, predA, flatLook
end)

local attackerAnimThrottled = LPH_NO_VIRTUALIZE(function(th)
	if Config.LatchTrustThrottled == false then return false end
	local model = th and th.attackerModel
	if not model then return false end
	if th.throttledFrame == _C.FrameId then return th.throttledNow == true end
	th.throttledFrame = _C.FrameId
	th.throttledNow = false
	local animator = th.attackerAnimator
	if not (animator and animator.Parent) then
		local model = th.attackerModel
		if not model then return false end
		local hum = model:FindFirstChildOfClass("Humanoid")
			or model:FindFirstChildOfClass("AnimationController")
		animator = hum and hum:FindFirstChildOfClass("Animator")
		th.attackerAnimator = animator
	end
	th.throttledNow = animator and animator.EvaluationThrottled == true
	return th.throttledNow
end)

-- Luraph: LPH_NO_VIRTUALIZE emits native Luau. Nested `function` / `pcall(function`
-- inside that span become child protos that Luraph still virtualizes, then the
-- native parent cannot close over them — runtime break or a per-frame hitch.
-- Keep native bodies free of inner closures; hoist helpers to sibling macros.
local whmSet = LPH_NO_VIRTUALIZE(function(th, hit)
	th.whmFrame, th.whmHit = _C.FrameId, hit
	return hit
end)

local willHitMe = LPH_NO_VIRTUALIZE(function(th)
	if th.whmFrame == _C.FrameId then return th.whmHit == true end
	if Config.PerfProbe then V93.probeWHM = (V93.probeWHM or 0) + 1 end
	local myHRP, aHRP = localHRP(), th.attackerHRP
	if not myHRP then
		th.recognitionSource = "no-my-hrp"
		return whmSet(th, false)
	end
	if not aHRP or not aHRP.Parent then
		th.recognitionSource = "no-hrp"
		return whmSet(th, false)
	end
	local aPos, myPos = aHRP.Position, myHRP.Position
	local now0 = os.clock()
	local remain0 = (th.contactAbs or now0) - now0
	local dxEarly, dzEarly = myPos.X - aPos.X, myPos.Z - aPos.Z
	local dist2dEarly = math.sqrt(dxEarly * dxEarly + dzEarly * dzEarly)
	local velToMeEarly = planarClosing(aHRP, myHRP, th)
	local maxYd = Config.MaxHeightDiff or 8
	local yOk = math.abs(myPos.Y - aPos.Y) <= maxYd
	-- Floors / pits: |dY| > maxYd cannot hit. m2-range used to skip this
	-- and we faced/pressed rooftop M2 (V285 y-diff after the fact).
	if th.kind == "M2" and yOk then
		local cap = Config.Range or 18
		local st = string.lower(tostring(th.style or ""))
		if st == "cqc" then cap = math.max(cap, 30) end
		if dist2dEarly <= cap then
			th.recognitionSource = "m2-range"
			th.geomDist2d = dist2dEarly
			th.offTarget = nil
			th.trustedHit = true
			return whmSet(th, true)
		end
	end
	local ovH = (th.kind == "M1") and 0.16 or 0.28
	if dist2dEarly <= 9 or velToMeEarly >= 7 then
		ovH = 0.38
	end
	local gt
	-- GetPartBoundsInBox is the per-frame killer. Hitbox is not out for
	-- most of the windup; dist<=9 used to query every PreSimulation.
	if th.serverHitbox or (th.group and th.group.serverHitbox) or remain0 <= ovH then
		gt = realHitboxHitsMe(th.name, th)
	end
	if not yOk then
		if gt ~= true then
			th.recognitionSource = "y-diff"
			th.offTarget = true
			return whmSet(th, false)
		end
	end

	if gt == true then
		th.gtConfirmed, th.trustedHit = true, true
		th.recognitionSource = "server-overlap"
		return whmSet(th, true)
	end
	if gt == false then
		th.recognitionSource = "server-pending"
	end

	local _, forward, predA, rawLook = hitboxGeom(th)
	if not predA or not rawLook then
		if th.kind == "M2" and dist2dEarly <= (Config.Range or 18) then
			th.recognitionSource = "m2-no-look"
			th.geomDist2d = dist2dEarly
			th.offTarget = nil
			return whmSet(th, true)
		end
		th.recognitionSource = th.recognitionSource or "geom-nil"
		return whmSet(th, false)
	end
	local now = now0
	local tHit = math.clamp((th.contactAbs or now) - now, 0, 0.6)
	local look, origin = rawLook, aPos
	local mode = "High"
	origin = Vector3.new(predA.X, aPos.Y, predA.Z)
	local sz = V93.sizes[th.kind]
	local myAt = myPos
	local hbMul = hitboxSizeMult(th.attackerModel)
	local halfW = (sz and sz.X * 0.5 or Config.HitHalfWidth or 3) * hbMul
		+ (Config.HighSlack or 0.35)
		+ localTorsoHalf()
	local halfH = (sz and sz.Y * 0.5 or 3) * hbMul + 2.5 + localHeightYBudget()
	local halfD = (sz and sz.Z * 0.5 or (Config.HitboxDepth or 4)) * hbMul
	if math.abs(myAt.Y - origin.Y) > halfH then
		th.recognitionSource = "y-diff"
		return whmSet(th, false)
	end
	local ox, oz = myAt.X - origin.X, myAt.Z - origin.Z
	local depth = ox * look.X + oz * look.Z
	local side = math.abs(ox * (-look.Z) + oz * look.X)
	th.geomDepth, th.geomSide = depth, side
	th.geomForward, th.geomHalfD, th.geomHalfW = forward, halfD, halfW
	th.geomTHit, th.geomOrigin, th.geomVictim, th.geomLook = tHit, origin, myAt, look

	local hit
	if mode == "High" then
		local dist2d = math.sqrt(ox * ox + oz * oz)
		local coreReach = forward + halfD
		local toMeX, toMeZ = ox, oz
		if dist2d > 0.05 then toMeX, toMeZ = ox / dist2d, oz / dist2d else toMeX, toMeZ = look.X, look.Z end
		local faceToMe = look.X * toMeX + look.Z * toMeZ
		th.geomFaceToMe = faceToMe

		local velMin = Config.ApproachVelMin or 0.5
		local velToMe = planarClosing(aHRP, myHRP, th)
		th.closeVel = velToMe
		local dtc = (th.contactAbs or now) - now
		local approachAllow = 0
		if velToMe > velMin and dtc > 0 and dtc <= (Config.MaxWait or 1.2) then
			approachAllow = math.clamp(velToMe * dtc, 0, Config.HighApproachCap or 10.0)
		end
		local approaching = velToMe > velMin
		local reach = coreReach + (Config.HighReachPad or 2.0)
		th.geomApproach = approachAllow
		th.ovDelay = 0

		local angToMe = math.acos(math.clamp(faceToMe, -1, 1))
		do
			local pa, pt = th.angPrev, th.angPrevT
			if pa and pt then
				local dtA = now - pt
				if dtA > 1e-3 and dtA < 0.5 then
					local r = (pa - angToMe) / dtA
					th.angClose = th.angClose and (th.angClose * 0.5 + r * 0.5) or r
				end
			end
			th.angPrev, th.angPrevT = angToMe, now
		end
		-- На малой дистанции ориентация атакующего недостоверна: его CFrame
		-- реплицируется с задержкой, а сам свинг доворачивается автофейсом уже
		-- на сервере. В радиусе halfD+halfW хитбокс накрывает нас при любом
		-- face, поэтому проверку направления здесь отключаем полностью.
		local faceExemptCore = (dist2d <= (halfD + halfW))
			or (th.serverProven and dist2d <= coreReach)
		local faceOk, faceAllowDeg
		if faceExemptCore then
			faceOk, faceAllowDeg = true, 180
		else
			local angNeed = angToMe - math.atan2(halfW, math.max(dist2d, 0.5))
			if angNeed < 0 then angNeed = 0 end
			local tRem   = math.clamp((th.contactAbs or now) - now, 0, 0.4)
			local wClose = math.clamp(th.angClose or 0, 0, Config.TurnRateRad or 6.0)
			local budget = wClose * tRem + math.rad(Config.TurnSnapDeg or 35)
			local hardMax = math.rad(Config.FaceHardDeg or 100)
			faceOk = (angNeed <= budget) and (angToMe <= hardMax)
			faceAllowDeg = math.deg(math.atan2(halfW, math.max(dist2d, 0.5)) + budget)
		end
		th.geomFaceFloor  = faceOk and -1.01 or math.cos(math.rad(math.min(faceAllowDeg, 180)))
		th.geomFaceAllow  = faceAllowDeg
		th.geomAngToMe    = math.deg(angToMe)
		local reachEff = reach + approachAllow
		if th.serverProven then
			local dtc = (th.contactAbs or now) - now
			if dtc <= (Config.ProvenReachWindow or 0.18) then
				local provenPad = Config.ProvenReachPad or 2.0
				reachEff = math.max(reachEff, coreReach + provenPad)
			end
		end
		th.geomReachEff = reachEff
		th.geomDist2d   = dist2d
		local rangeCap = Config.Range or 18
		if th.kind == "M2" then
			local st = string.lower(tostring(th.style or ""))
			if st == "cqc" then
				rangeCap = math.max(rangeCap, 30)
			end
		end
		if reachEff > rangeCap then
			reachEff = rangeCap
			th.geomReachEff = reachEff
		end
		hit = (dist2d <= reachEff) and faceOk
		if not hit and approaching and dist2d <= rangeCap then
			local gap = math.max(0, dist2d - coreReach)
			local eta = gap / math.max(velToMe, 0.05)
			local slack = Config.ClosingEtaSlack or 0.12
			if eta <= math.max(dtc, 0) + slack then
				local faceDashOk = faceOk
					or (angToMe <= math.rad((Config.FaceHardDeg or 100) + (Config.ClosingFacePadDeg or 45)))
				if faceDashOk then
					hit, faceOk = true, true
					th.recognitionSource = "closing-eta"
					th.geomEta = eta
				end
			end
		end
		if not hit and dist2d <= reachEff and (th.kind == "M2" or th.kind == "SKILL") then
			local pad = math.rad(Config.HeavyFacePadDeg or 40)
			if angToMe <= math.rad(Config.FaceHardDeg or 100) + pad then
				hit, faceOk = true, true
			end
		end
		-- Серверные ярлыки не перекрывают удар в спину / мимо конуса.
		local lookAway = (not faceOk) and (angToMe > math.rad(90))
		if not lookAway then
			if not hit and th.serverProven and attackerAnimThrottled(th) then
				hit = true
				th.recognitionSource = "anim-throttled"
			end
			if not hit and th.serverProven and th.kind == "M2" and dist2d <= 8 then
				hit = true
				th.recognitionSource = "m2-close"
			end
			if not hit and th.serverProven then
				local dtcA = (th.contactAbs or now) - now
				if dist2d <= 12
				   and (th.closeVel or 0) > (Config.ApproachVelMin or 0.5)
				   and dtcA > -0.02 and dtcA <= 0.45 then
					hit = true
					th.recognitionSource = "approach-predict"
				end
			end
		elseif not hit then
			th.recognitionSource = "look-away"
		end
	end

	-- M2 step-in lands even when replica LookVector is >90°. look-away
	-- vetoed m2-close and produced V279 Hakari M2 NO-PRESS at dist=5.
	if not hit and th.kind == "M2" then
		local d2 = th.geomDist2d
		if type(d2) ~= "number" then
			d2 = math.sqrt(ox * ox + oz * oz)
		end
		local cap = Config.Range or 18
		local st = string.lower(tostring(th.style or ""))
		if st == "cqc" then cap = math.max(cap, 30) end
		if type(d2) == "number" and d2 <= cap then
			hit = true
			th.offTarget = nil
			th.recognitionSource = "m2-in-range"
		end
	end

	if hit and th.serverProven then
		th.geomStickyUntil = math.max(th.geomStickyUntil or 0,
			(th.contactAbs or now) + (Config.HoldAfter or 0.12) + 0.05)
		th.geomStickySource = th.recognitionSource or "predicted-overlap"
	elseif not hit and th.serverProven and (th.geomStickyUntil or 0) >= now then
		local d2       = math.sqrt(ox * ox + oz * oz)
		local approaching = (th.closeVel or 0) > (Config.ApproachVelMin or 0.5)
		local reachPad = forward + halfD + (Config.HighReachPad or 2.0)
		local reason = (d2 > reachPad) and "OUT-OF-REACH" or "BACK-FACING"
		local revive = true
		if Config.StickyStrict ~= false then
			if attackerAnimThrottled(th) then
				revive = true
			elseif reason == "OUT-OF-REACH" then
				revive = d2 <= math.min(reachPad, Config.Range or 18)
			elseif reason == "BACK-FACING" then
				revive = d2 <= (forward + halfD + 1.5)
			end
		end
		if revive then
			hit = true
			th.recognitionSource = "geom-sticky/" .. reason
		else
			th.recognitionSource = "sticky-dropped/" .. reason
		end
		if Config.TraceDiag and (not th.geomStickyLogAt or now - th.geomStickyLogAt > 0.10) then
			th.geomStickyLogAt = now
			diagTrace("GEOM-STICKY t=%.3f %s %s s%d veto=%s revive=%s source=%s contactIn=%+.0fms stickyLeft=%.0fms dist=%.1f reach=%.1f face=%.2f", now, tostring(th.name), tostring(th.kind), th.strike or 1, reason,
					tostring(revive), tostring(th.geomStickySource or "?"), ((th.contactAbs or now)-now)*1000,
					((th.geomStickyUntil or now)-now)*1000, d2, reachPad, th.geomFaceToMe or 0)
		end
	end

	th.trustedHit = hit
	if th.recognitionSource and (th.recognitionSource:sub(1, 12) == "geom-sticky/"
		or th.recognitionSource:sub(1, 15) == "sticky-dropped/") then
	elseif gt == false and not hit then
		th.recognitionSource = "server-pending+predicted-miss"
	else
		th.recognitionSource = hit and "predicted-overlap" or "predicted-miss"
	end
	if not hit then th.offTarget = true end
	if not hit and Config.DeepDiag and not th.geomRejLogged then
		th.geomRejLogged = true
		local dist2d = math.sqrt(ox * ox + oz * oz)
		local reachD = forward + halfD + (Config.HighReachPad or 2.0)
		local f2m = th.geomFaceToMe
		if f2m == nil then
			f2m = 1
			if dist2d > 0.05 then f2m = (look.X * ox + look.Z * oz) / dist2d end
		end
			local appr = th.geomApproach or 0
			local reachEff = th.geomReachEff or (reachD + appr)
			if Config.TraceDiag then
			diagTrace("GEOM-REJECT t=%.3f %s %s(%s) c%s v%s mode=%s dt=%+.0fms | dist2d=%.2f reachEff=%.2f (fwd=%.2f step=%.2f halfD=%.2f appr=%.2f) %s | угол=%.0f° допуск=%.0f° закрытие=%.1fрад/с %s | depth=%.2f side=%.2f/%.2f", now, tostring(th.name), tostring(th.kind), tostring(th.style),
				tostring(th.combo or "?"), tostring(th.variant or "-"), tostring(mode),
				((th.contactAbs or now) - now) * 1000,
				dist2d, reachEff, forward - (th.geomStep or 0), th.geomStep or 0, halfD, appr,
				(dist2d > reachEff) and "OUT-OF-REACH" or "reach-ok",
				th.geomAngToMe or math.deg(math.acos(math.clamp(f2m, -1, 1))),
				th.geomFaceAllow or 0, th.angClose or 0,
				((th.geomAngToMe or 999) > (th.geomFaceAllow or 0)) and "NOT-AIMED-AT-ME" or "aim-ok",
				depth, side, halfW)
			end
		end
		return whmSet(th, hit)
	end)

local function nextCombo(attacker)
	local now = os.clock()
	local c = ComboState[attacker]
	local isFresh = (c == nil)
	local isNew = isFresh or (now - c.last) > _D.COMBO_RESET
	if isNew then c = { idx = 0, last = now } end
	c.idx  = (c.idx % 4) + 1
	c.last = now
	ComboState[attacker] = c
	ComboState._count = (ComboState._count or 0) + (isFresh and 1 or 0)
	if ComboState._count > 64 then
		local oldest, oldestName = math.huge, nil
		for name, rec in pairs(ComboState) do
			if type(rec) == "table" and rec.last and rec.last < oldest then
				oldest = rec.last; oldestName = name
			end
		end
		if oldestName then ComboState[oldestName] = nil; ComboState._count = ComboState._count - 1 end
	end
	return c.idx
end

local GameData = { cfg = nil, cau = nil, cu = nil, resolved = false }

local function loadGameModules()
	if GameData.resolved then return end
	local now = os.clock()
	if (now - (GameData.lastTry or -1)) < 0.25 then return end
	GameData.lastTry = now
	GameData.tries   = (GameData.tries or 0) + 1
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local cfgMod = shared and shared:FindFirstChild("Config") and shared.Config:FindFirstChild("CombatConfig")
	if cfgMod then GameData.cfg = require(cfgMod) end
	local cauMod = shared and shared:FindFirstChild("Utils") and shared.Utils:FindFirstChild("CombatAnimationUtils")
	if cauMod then GameData.cau = require(cauMod) end
	local pauMod = shared and shared:FindFirstChild("Utils") and shared.Utils:FindFirstChild("CombatPingAnimUtils")
	if pauMod then GameData.pau = require(pauMod) end
	local pkgs = ReplicatedStorage:FindFirstChild("Packages")
	local cuMod = pkgs and pkgs:FindFirstChild("CombatUtils")
	if cuMod then GameData.cu = require(cuMod) end
	do
		local ev = GameData.cfg and GameData.cfg.Evasive
		if ev and type(ev.IFrameDuration) == "number" and ev.IFrameDuration > 0.05 then
			GameData.iframeDur = ev.IFrameDuration
		end
		local cp = GameData.cfg and GameData.cfg.ClientPredict
		local cpe = cp and cp.Evasive
		if cpe and type(cpe.ServerConfirmTimeout) == "number" then
			GameData.confirmTimeout = cpe.ServerConfirmTimeout
		end
		if type(ev) == "table" and type(ev.Cooldown) == "number" and ev.Cooldown > 0 then
			GameData.evCooldown = ev.Cooldown
		end
		if cpe and type(cpe.Cooldown) == "number" and cpe.Cooldown > 0 then
			GameData.evPredictCooldown = cpe.Cooldown
		end
		if type(ev) == "table" and type(ev.DashDuration) == "number" and ev.DashDuration > 0 then
			GameData.dashDuration = ev.DashDuration
		end
		local bl = GameData.cfg and GameData.cfg.Block
		if bl and type(bl.PerfectBlockWindow) == "number" then
			GameData.perfectWindow = bl.PerfectBlockWindow
		end
		local sh = GameData.cfg and GameData.cfg.Shared
		local nap = sh and sh.NetworkAnimPingCompensation
		if nap and type(nap.MaxEstimatedOneWaySeconds) == "number" then
			GameData.animPingCap = nap.MaxEstimatedOneWaySeconds
		end
		if sh and type(sh.HitboxWindupExtra) == "number" then
			GameData.windupExtra = sh.HitboxWindupExtra
		end
	end
	if GameData.cfg then
		GameData.resolved = true
		diagPush("GAMEDATA-OK tries=%d perfectWindow=%s iframeDur=%s pau=%s cu=%s",
			GameData.tries or 0,
			GameData.perfectWindow and string.format("%.0fms", GameData.perfectWindow * 1000) or "nil",
			GameData.iframeDur and string.format("%.0fms", GameData.iframeDur * 1000) or "nil",
			GameData.pau and "yes" or "no", GameData.cu and "yes" or "no")
	end
end

local HEIGHT_H_LO, HEIGHT_H_HI = 0.983, 1.45

local resolveCharHeight = LPH_NO_VIRTUALIZE(function(model)
	local h, src
	local pd = model:FindFirstChild("PlayerData")
	if pd then
		local v = tonumber(pd:GetAttribute("CurrentHeight")) or tonumber(pd:GetAttribute("Height"))
		if type(v) == "number" and v > 0.05 then h, src = v, "playerdata" end
	end
	if not h then
		local hum = model:FindFirstChildOfClass("Humanoid")
		local scale = hum and hum:FindFirstChild("BodyHeightScale")
		if scale and scale:IsA("NumberValue") and scale.Value > 0.05 then
			h, src = scale.Value, "bodyscale"
		end
	end
	if type(h) == "number" then
		if h < HEIGHT_H_LO * 0.5 or h > HEIGHT_H_HI * 1.5 then return nil, nil end
		return h, src
	end
	return nil, nil
end)

_C.AttackMultCache = setmetatable({}, { __mode = "k" })
_C.HeightSrcLogged = setmetatable({}, { __mode = "k" })
local attackSpeedMult = LPH_NO_VIRTUALIZE(function(model)
	if not model then return 1 end
	local c = _C.AttackMultCache[model]
	if c and (os.clock() - c.t) < 8.0 then return c.m end
	if not GameData.resolved then loadGameModules() end
	local mult, src = 1, nil
	if GameData.cu then
		local h = GameData.cu.GetCharacterHeight(model)
		if type(h) == "number" then
			local m = GameData.cu.GetAttackSpeedMultiplier(h)
			if type(m) == "number" and m > 0.05 then mult, src = m, "cu" end
		end
	end
	if not src then
		local h, hsrc = resolveCharHeight(model)
		if h then
			local applied = false
			if GameData.cu then
				local m = GameData.cu.GetAttackSpeedMultiplier(h)
				if type(m) == "number" and m > 0.05 then
					mult, src, applied = m, "cu-fn/" .. tostring(hsrc), true
				end
			end
			if not applied then
				mult = 1.15 - math.clamp((h - HEIGHT_H_LO) / (HEIGHT_H_HI - HEIGHT_H_LO), 0, 1) * 0.3
				src = "formula/" .. tostring(hsrc)
			end
		end
	end
	mult = math.clamp(mult, 0.80, 1.20)
	if Config.DeepDiag and not _C.HeightSrcLogged[model] then
		_C.HeightSrcLogged[model] = true
		diagPush("HEIGHT-SRC %s → aMult=%.3f src=%s", tostring(model and model.Name), mult, tostring(src or "none(=1.0)"))
	end
	_C.AttackMultCache[model] = { m = mult, t = os.clock(), src = src }
	return mult
end)

_C.HbSizeCache = setmetatable({}, { __mode = "k" })
hitboxSizeMult = LPH_NO_VIRTUALIZE(function(model)
	if not model then return 1 end
	local rec = _C.HbSizeCache[model]
	if rec and (os.clock() - rec.t) < 8.0 then return rec.m end
	local h = resolveCharHeight(model)
	local m = 1
	if h then
		if not GameData.resolved then loadGameModules() end
		if GameData.cu and GameData.cu.GetHitboxSizeMultiplier then
			local v = GameData.cu.GetHitboxSizeMultiplier(h)
			if type(v) == "number" and v > 0.05 then
				m = math.clamp(v, 0.85, 1.15)
			else
				m = math.clamp((h - HEIGHT_H_LO) / (HEIGHT_H_HI - HEIGHT_H_LO), 0, 1) * 0.3 + 0.85
			end
		else
			m = math.clamp((h - HEIGHT_H_LO) / (HEIGHT_H_HI - HEIGHT_H_LO), 0, 1) * 0.3 + 0.85
		end
	end
	_C.HbSizeCache[model] = { m = m, t = os.clock() }
	return m
end)
_C.hitboxSizeMult = hitboxSizeMult

local function heightDiag(model)
	local attrHeight, bodyScale, modelHeight = nil, nil, nil
	local pd = model and model:FindFirstChild("PlayerData")
	if pd then attrHeight = tonumber(pd:GetAttribute("CurrentHeight")) or tonumber(pd:GetAttribute("Height")) end
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local scale = hum and hum:FindFirstChild("BodyHeightScale")
	if scale and scale:IsA("NumberValue") then bodyScale = scale.Value end
	if model then
		local me = localChar()
		if me and model == me and _C.extFrame == _C.FrameId then
			modelHeight = _C.extY
		else
			modelHeight = model:GetExtentsSize().Y
			if me and model == me then
				_C.extFrame, _C.extModel, _C.extY = _C.FrameId, model, modelHeight
			end
		end
	end
	return attrHeight, bodyScale, modelHeight
end

_C.styleFn  = function(m) return GameData.cau.GetCombatStyleForCharacter(m) end
_C.styleAttr = function(m) return m:GetAttribute("CombatStyle") end
_C.styleCache = setmetatable({}, { __mode = "k" })
local styleOf = LPH_NO_VIRTUALIZE(function(model)
	local e = _C.styleCache[model]
	local nowc = os.clock()
	if e and nowc < e.t then return e.v end
	if not GameData.resolved then loadGameModules() end
	local out
	if GameData.cau then
		local s = _C.styleFn(model)
		if type(s) == "string" and #s > 0 then out = s end
	end
	if not out then
		local s = _C.styleAttr(model)
		if type(s) == "string" and #s > 0 then out = s end
	end
	out = out or "Basic"
	if e then e.v, e.t = out, nowc + 0.5 else _C.styleCache[model] = { v = out, t = nowc + 0.5 } end
	return out
end)

_D.AttackIds = {}
local function comboFromName(nm)
	local n = nm:match("^(%d+)")
	if n then return tonumber(n) end
	local l = nm:lower()
	if l:find("first")  then return 1 end
	if l:find("second") then return 2 end
	if l:find("third")  then return 3 end
	if l:find("fourth") then return 4 end
	return nil
end
local function kindFromName(nm)
	if type(nm) ~= "string" or nm == "" then return nil end
	local l = nm:lower()
	-- M2Success / M2EHit = already-connected grab, not a new swing.
	if l:find("success", 1, true) or l:find("ehit", 1, true)
		or l:find("blockhit", 1, true) or l:find("block", 1, true)
		or l:find("guard", 1, true) or l:find("parry", 1, true) then
		return nil
	end
	if nm:match("M2") then return "M2" end
	if nm:match("M1") then return "M1" end
	if l:find("crit", 1, true) or l:find("momentum", 1, true) then return "M2" end
	return nil
end
local function animIdOf(inst)
	if inst:IsA("Animation") then return tonumber(tostring(inst.AnimationId):match("(%d+)")) end
	local a = inst:FindFirstChildWhichIsA("Animation")
	if a then return tonumber(tostring(a.AnimationId):match("(%d+)")) end
	return nil
end
_D.BlockIds = {}
local function looksDefensive(nm)
	local l = nm:lower()
	return (l:find("block") or l:find("guard") or l:find("parry")
		or l:find("deflect") or l:find("perfect")) ~= nil
end
local function indexAllAnims()
	local anims  = ReplicatedStorage:FindFirstChild("Animations")
	if anims then
		local combat = anims:FindFirstChild("Combat")
		if combat then
			for _, styleFolder in ipairs(combat:GetChildren()) do
				if styleFolder:IsA("Folder") then
					local isStyleFolder = styleFolder:FindFirstChild("M2") ~= nil
						or styleFolder:FindFirstChild("1stM1") ~= nil
						or styleFolder:FindFirstChild("2ndM1") ~= nil
					for _, child in ipairs(styleFolder:GetChildren()) do
						local lname     = child.Name:lower()
						local defensive = looksDefensive(child.Name)
						local reaction  = (lname:find("ehit") or lname:find("success")
							or lname:find("blockhit")) ~= nil
						local benignMove = (lname == "idle" or lname == "walk" or lname == "run"
							or lname:find("dash")) ~= nil
						local kind = nil
						if not defensive and not reaction and not benignMove then
							kind = kindFromName(child.Name)
							if not kind and isStyleFolder then kind = "SKILL" end
						end
						local id = animIdOf(child)
						if id and defensive then _D.BlockIds[id] = true end
						if kind and id then
							_D.AttackIds[id] = {
								kind = kind,
								combo = (kind == "M1") and comboFromName(child.Name) or nil,
								name = child.Name,
								mom = lname:find("momentum") ~= nil,
							}
						end
					end
				end
			end
		end
			for _, d in ipairs(anims:GetDescendants()) do
				if d:IsA("Animation") then
					local id = tonumber(tostring(d.AnimationId):match("(%d+)"))
					if id then
						if looksDefensive(d.Name) or (d.Parent and looksDefensive(d.Parent.Name)) then
							_D.BlockIds[id] = true
						end
						if not _D.AttackIds[id] and not _D.BlockIds[id] then
							local lname = d.Name:lower()
							if not (lname:find("ehit") or lname:find("success")) then
								local k = kindFromName(d.Name)
								if not k and (lname:find("slam") or lname:find("special") or lname:find("finisher")) then
									k = "SKILL"
								end
								if k then
									_D.AttackIds[id] = {
										kind = k, combo = nil, name = d.Name,
										mom = lname:find("momentum") ~= nil,
									}
								end
							end
						end
					end
				end
			end
	end
	for id, v in pairs(_D.LEGACY_ATTACKS) do
		if not _D.AttackIds[id] then _D.AttackIds[id] = { kind = v.t, combo = nil } end
	end
end

local function attackEntry(id)
	return _D.AttackIds[id]
end

GameData.m2VarCache = {}
GameData.m2VariantId = function(style, animName)
	if type(animName) ~= "string" or animName == "" then return nil end
	local ck = tostring(style):lower() .. "|" .. animName
	local c = GameData.m2VarCache[ck]
	if c ~= nil then return c or nil end
	local out = false
	loadGameModules()
	if GameData.cfg and GameData.cfg.GetStyleM2Variants then
		local vs = GameData.cfg.GetStyleM2Variants(style)
		if type(vs) == "table" then
			for id, v in pairs(vs) do
				if type(v) == "table" and v.Anim == animName then out = id; break end
			end
			if out == false then
				local ln = animName:lower()
				for id in pairs(vs) do
					local lid = tostring(id):lower()
					if #lid > 0 and ln:find(lid, 1, true) then out = id; break end
				end
			end
		end
	end
	if out == false then out = _D.LEGACY_M2_VARIANT[animName] or false end
	GameData.m2VarCache[ck] = out
	return out or nil
end

local function isBoxingStyle(style)
	local s = string.lower(tostring(style or "")):gsub("[%s_%-]", "")
	return s:sub(1, 6) == "boxing"
end

local function styleM2MultiHitCount(style)
	loadGameModules()
	local cfg = GameData.cfg
	if cfg and cfg.GetStyleNumber then
		local n = cfg.GetStyleNumber(style, "M2MultiHitCount", 1)
		if type(n) == "number" then return n end
	end
	if cfg then
		local sl = string.lower(tostring(style or "")):gsub("[%s_%-]", "")
		local alias = _D.STYLE_ALIAS
		if type(alias) == "table" then sl = alias[sl] or sl end
		local styles = cfg.Styles
		local s = type(styles) == "table" and (styles[style] or styles[sl]) or nil
		if type(s) == "table" and type(s.M2MultiHitCount) == "number" then
			return s.M2MultiHitCount
		end
	end
	return isBoxingStyle(style) and 2 or 1
end

local function boxingM2ContactTable()
	loadGameModules()
	local first, second = 0.43, 1.05
	local mc = V93.boxingM2Contacts
	if type(mc) == "table" then
		if type(mc[1]) == "number" then first = mc[1] end
		if type(mc[2]) == "number" then second = mc[2] end
	end
	-- cfg M2HitboxDelay=0.43 is windup, not overlap. Live first contact
	-- is ~0.60–0.63 (V209: pred=442 meas=606–629 → EARLY BLOCK + GB).
	-- Never pull the first marker down to 0.43.
	local floor = Config.BoxingM2FirstFloor or 0.58
	if first < floor then first = floor end
	return { first, second }
end

-- Boxing first-hit floor is live-log only. Mishima/Jin use CombatConfig delays.
_C.styleM2ContactTable = function(style)
	loadGameModules()
	if isBoxingStyle(style) then
		return boxingM2ContactTable()
	end
	local cfg = GameData.cfg
	if cfg and cfg.GetStyleM2MultiHitDelays then
		local ok, d = pcall(cfg.GetStyleM2MultiHitDelays, style)
		if ok and type(d) == "table" and type(d[1]) == "number" and type(d[2]) == "number" then
			return { d[1], d[2] }
		end
	end
	return nil
end

local resolveInfo = function(id, model)
	local entry  = _D.AttackIds[id]
	if not entry then return nil end
	local legacy = _D.LEGACY_ATTACKS[id]
	local kind = entry.kind
	local rk = registryKind and registryKind(model, id)
	if rk == "M1" or rk == "M2" then kind = rk end
	local style = styleOf(model) or (legacy and legacy.s) or "Basic"
	local variant = nil
	if kind == "M2" then
		if model then
			local av = model:GetAttribute("M2VariantId")
			if type(av) == "string" and av ~= "" then variant = av end
		end
		if not variant then
			variant = GameData.m2VariantId(style, entry and entry.name) or (legacy and legacy.v) or nil
		end
	end
	local sprint = false
	if kind == "M2" then
		sprint = _C.attackerSprinting(model) == true
	end
	return {
		t     = kind,
		s     = style,
		id    = id,
		hit   = entry.hit,
		contacts = (kind == "M2" and styleM2MultiHitCount(style) >= 2)
			and _C.styleM2ContactTable(style) or nil,
		combo = entry and entry.combo or (legacy and legacy.c) or nil,
		mom   = (entry and entry.mom) or (legacy and legacy.mom) or false,
		name  = entry and entry.name or nil,
		variant = variant,
		sprint = sprint,
	}
end

_D.STYLE_ALIAS = {
	hakariother = "hakario", hakarialt = "hakario", hakario = "hakario",
	wing = "wingchun", wingchun = "wingchun", ["wing chun"] = "wingchun",
	muay = "muaythai", ["muay thai"] = "muaythai", muaythai = "muaythai",
	cqc = "cqc", closequarters = "cqc", closequarterscombat = "cqc",
	kickboxing = "kickboxing", kickbox = "kickboxing",
	kyokushin = "kyokushin", kyokushinkarate = "kyokushin",
	mishima = "mishima", lethwei = "lethwei", jin = "jin",
}
local function styleKey(s)
	local sl = string.lower(tostring(s or "")):gsub("[%s_%-]", "")
	return _D.STYLE_ALIAS[sl] or sl
end

local function cfgKnowsStyle(style)
	loadGameModules()
	local c = GameData.cfg
	if not c then return false end
	local styles = c.Styles
	if type(styles) ~= "table" then
		return false
	end
	local key = style
	if type(c.NormalizeStyleKey) == "function" then
		key = c.NormalizeStyleKey(style)
	end
	return styles[key] ~= nil
end

_C.attackerSprinting = function(model, hrp)
	if model and model:GetAttribute("Sprinting") then return true end
	local p = hrp
	if not p and model then p = model:FindFirstChild("HumanoidRootPart") end
	if not p then return false end
	local v = p.AssemblyLinearVelocity
	if typeof(v) ~= "Vector3" then return false end
	return (v.X * v.X + v.Z * v.Z) >= 400
end

_C.sprintM2Delay = function(style)
	loadGameModules()
	local cfg = GameData.cfg
	if not (cfg and cfg.GetStyleNumber) then return nil end
	local d = cfg.GetStyleNumber(style, "M2SprintHitboxDelay", -1)
	if type(d) ~= "number" or d <= 0 then return nil end
	if cfg.GetScaledHitboxDelay then
		local sc = cfg.GetScaledHitboxDelay(d, 1)
		if type(sc) == "number" then return sc end
	end
	return d
end

local function hitTimelineBase(info, combo)
	if info.t == "SKILL" then
		if info.hit and info.hit > 0 then return info.hit end
		return 0.35
	end
	if info.id and not cfgKnowsStyle(info.s) then
		local le0 = _D.LEGACY_ATTACKS[info.id]
		if le0 and le0.t == info.t and type(le0.d) == "number" then
			return le0.d + _D.WINDUP_EXTRA
		end
	end
	if info.t == "M2" then
		loadGameModules()
		local cfgv, multi = nil, 1
		if GameData.cfg then
			local d = GameData.cfg.GetStyleM2HitboxDelay(info.s, info.mom, info.variant)
			if type(d) == "number" then
				-- Игра: GetScaled(d, heightMult) = d/aMult + windup/aMult.
				-- База speed=1; aMult один раз в hitTimeline. Не d+WINDUP.
				if GameData.cfg.GetScaledHitboxDelay then
					local sc = GameData.cfg.GetScaledHitboxDelay(d, 1)
					if type(sc) == "number" then cfgv = sc end
				end
				if not cfgv then cfgv = d + (GameData.windupExtra or _D.WINDUP_EXTRA) end
			end
			local mc = GameData.cfg.GetStyleNumber(info.s, "M2MultiHitCount", 1)
			if type(mc) == "number" then multi = mc end
		end
		if not cfgv then
			local sl = styleKey(info.s)
			local le = info.id and _D.LEGACY_ATTACKS[info.id] or nil
			if le and le.t == "M2" and type(le.d) == "number" then
				cfgv = le.d + _D.WINDUP_EXTRA
			elseif info.mom and _D.LEGACY_M2_MOM_BASE[sl] then
				cfgv = _D.LEGACY_M2_MOM_BASE[sl] + _D.WINDUP_EXTRA
			else
				cfgv = (_D.LEGACY_M2_BASE[sl] or 0.30) + _D.WINDUP_EXTRA
			end
		end
		-- Dragon standing 0.655 vs sprint 0.29. V292 pred=692 meas=335 NO-PRESS.
		if info.sprint then
			local sd = _C.sprintM2Delay(info.s)
			if type(sd) == "number" then cfgv = sd end
		end
		if multi > 1 and info.hit and info.hit > 0 then
			return cfgv
		end
		return cfgv
	end

	loadGameModules()
	if GameData.cfg then
		local d = GameData.cfg.GetScaledStyleM1HitboxDelay(info.s, combo or 1, 1)
		if type(d) == "number" then return d end
	end
	local sl   = styleKey(info.s)
	local base = _D.LEGACY_M1_BASE[sl] or 0.32
	local off  = _D.LEGACY_M1_OFFSETS[sl]
	if off then base = base + (off[math.clamp(combo or 1, 1, 4)] or 0) end
	return base + _D.WINDUP_EXTRA
end

local function hitTimeline(info, combo, mult, contactBase)
	local base = contactBase or hitTimelineBase(info, combo)
	local m = (type(mult) == "number" and mult > 0.05) and mult or 1
	return base / math.max(0.05, m)
end

local function markAttackStreak(name, kind, style, info)
	local streak = V93.m1Streak
	if kind == "M1" then
		streak[name] = (streak[name] or 0) + 1
		return
	end
	if kind == "M2" then
		streak[name] = 0
	end
	-- Momentum только из id анимации / M2VariantId. Streak≥3 ставил 480ms
	-- на обычный Hakari M2 → pred=455 meas=348 LATE (V213).
end

local function gamePingAnimMult(animContact)
	if type(animContact) ~= "number" or animContact <= 0 then return 1 end
	local v = LocalPlayer:GetNetworkPing()
	if type(v) ~= "number" or v ~= v or v <= 0 then return 1 end
	local cap = GameData.animPingCap or Config.AnimPingCompMax or 0.35
	return animContact / (animContact + math.clamp(v * 0.5, 0, cap))
end

local function effAnimSpeed(track, aMult, animContact)
	local sp
	if track then
		local v = track.Speed
		if type(v) == "number" then sp = v end
	end
	if type(sp) == "number" and sp >= (Config.SpeedSanityMin or 0.2)
		and sp <= (Config.SpeedSanityMax or 3.0) then
		return sp, "live"
	end
	local m = (type(aMult) == "number" and aMult > 0.05) and aMult or 1
	local d = (type(animContact) == "number" and animContact > 0.01) and animContact or 0.32
	local comp = gamePingAnimMult(d)
	return math.clamp(m * comp, Config.SpeedSanityMin or 0.2, Config.SpeedSanityMax or 3.0), "predict"
end


local tpSpeed = LPH_NO_VIRTUALIZE(function(track)
	if track then
		local v = track.Speed
		if type(v) == "number"
			and v >= (Config.SpeedSanityMin or 0.2)
			and v <= (Config.SpeedSanityMax or 3.0) then
			return v
		end
	end
	return 1
end)

local function animToWall(animDelta, track, aMult, animContact)
	local sp = effAnimSpeed(track, aMult, animContact)
	return animDelta / sp
end


_C.fwdFn = function(st, k) return GameData.cfg.GetStyleHitboxForwardOffset(st, k) end
_C.fwdCache = {}
_C.grabOffFn = function(st)
	local cfg = GameData.cfg
	if not cfg or not cfg.GetStyleNumber then return 0 end
	return cfg.GetStyleNumber(st, "M2GrabTargetForwardOffset", 0)
end
_C.applyGrabSwingSpeed = function(info, track, hitTL)
	if not info or info.t ~= "M2" or type(hitTL) ~= "number" then return hitTL end
	local cfg = GameData.cfg
	if not (cfg and cfg.GetStyleNumber) then return hitTL end
	local gsp = cfg.GetStyleNumber(info.s, "M2GrabSwingAnimSpeed", 1)
	if type(gsp) ~= "number" or gsp <= 0.05 or gsp >= 0.97 then return hitTL end
	local live = 1
	if track then
		local sp = track.Speed
		if type(sp) == "number" and sp > 0.05 then live = sp end
	end
	if math.abs(live - 1) >= 0.08 then return hitTL end
	return hitTL / gsp
end
styleForward = LPH_NO_VIRTUALIZE(function(style, kind)
	local ck = tostring(style) .. "|" .. tostring(kind)
	local hit = _C.fwdCache[ck]
	if type(hit) == "number" then return hit end
	if hit == false then
		return (kind == "M2" or kind == "SKILL") and Config.M2Forward or Config.M1Forward
	end
	if not GameData.resolved then loadGameModules() end
	if GameData.cfg then
		local ok, f = pcall(_C.fwdFn, style, kind)
		if ok and type(f) == "number" then _C.fwdCache[ck] = f; return f end
		_C.fwdCache[ck] = false
	end
	return (kind == "M2" or kind == "SKILL") and Config.M2Forward or Config.M1Forward
end)

_C.stepCache = {}
styleStepForward = LPH_NO_VIRTUALIZE(function(style, kind, combo)
	local ck = tostring(style) .. "|" .. tostring(kind) .. "|" .. tostring(combo or 1)
	local v = _C.stepCache[ck]
	if type(v) == "number" then return v end
	if v == false then return 0 end
	if not GameData.resolved then loadGameModules() end
	local out = nil
	if GameData.cfg then
		local fn, ok, r
		if kind == "M1" then
			fn = GameData.cfg.GetStyleM1StepForwardStuds
			if fn then ok, r = pcall(fn, style, combo or 1) end
		else
			fn = GameData.cfg.GetStyleM2StepForwardStuds
			if fn then ok, r = pcall(fn, style) end
		end
		if ok and type(r) == "number" then out = r end
	end
	if type(out) ~= "number" then
		local sl = string.lower(tostring(style))
		if sl == "ali" then
			out = (kind == "M1") and (((combo == 1) or (combo == 3)) and 1.5 or 0) or 2
		else
			out = nil
		end
	end
	if type(out) ~= "number" then _C.stepCache[ck] = false; return 0 end
	out = math.clamp(out, 0, 8)
	_C.stepCache[ck] = out
	return out
end)

local velLead = LPH_NO_VIRTUALIZE(function(hrp, th)
	if th and th.kind == "M2" then return 0 end
	local me = localHRP()
	if not me or not hrp then return 0 end
	local closing = planarClosing(hrp, me, th)
	if closing <= 0.5 then return 0 end
	local full = Config.MoveSpeedFull or 22
	local cap = Config.MoveLeadMax or 0.10
	return math.clamp(closing / full, 0, 1) * cap
end)


local Debris = game:GetService("Debris")
local AnimLib = { tracks = {}, dashCache = {}, blockAnim = nil, handler = nil, resolvedHandler = false }

local function looksLikeHandler(t)
	return type(t) == "table"
		and type(rawget(t, "LoadAnim"))  == "function"
		and type(rawget(t, "GetAnims"))  == "function"
		and type(rawget(t, "IsAnim"))    == "function"
		and type(rawget(t, "StopAnim"))  == "function"
		and type(rawget(t, "Anims"))     == "table"
end

AnimLib.handlers    = {}
AnimLib._handlerSet = setmetatable({}, { __mode = "k" })

local function addHandler(t)
	if not t or AnimLib._handlerSet[t] then return false end
	AnimLib._handlerSet[t] = true
	AnimLib.handlers[#AnimLib.handlers + 1] = t
	return true
end

_C.handlerNextScan = 0
local function scanAllHandlers()
	if AnimLib.resolvedHandler and #AnimLib.handlers > 0 then
		return AnimLib.handlers
	end
	local now = os.clock()
	if now < _C.handlerNextScan then return AnimLib.handlers end
	_C.handlerNextScan = now + 8

	local pkgs = ReplicatedStorage:FindFirstChild("Packages")
	local mod  = pkgs and pkgs:FindFirstChild("AnimationHandler")
	if mod then
		local ok, ret = pcall(require, mod)
		if ok and looksLikeHandler(ret) then addHandler(ret) end
	end
	if #AnimLib.handlers > 0 then
		AnimLib.resolvedHandler = true
		return AnimLib.handlers
	end

	local scanned, before = 0, #AnimLib.handlers
	if type(filtergc) == "function" then
		local scan = filtergc("table", { Keys = { "LoadAnim", "GetAnims", "IsAnim", "StopAnim", "Anims" } })
		if looksLikeHandler(scan) then addHandler(scan)
		elseif type(scan) == "table" then
			for _, obj in pairs(scan) do if looksLikeHandler(obj) then addHandler(obj) end end
		end
	elseif not AnimLib._gcWarned then
		AnimLib._gcWarned = true
		if aclog then aclog("[DESYNC] no filtergc — skip full getgc walk (Luraph hitch)") end
	end

	local added = #AnimLib.handlers - before
	if #AnimLib.handlers > 0 then
		AnimLib.resolvedHandler = true
		if added > 0 and aclog then
			aclog(string.format("[DESYNC] handler: %d instance(s) (walked %d, +%d)", #AnimLib.handlers, scanned, added))
		end
	elseif aclog and not AnimLib._scanLogged then
		AnimLib._scanLogged = true
		aclog("[DESYNC] AnimationHandler not found yet (retry in 8s)")
	end
	return AnimLib.handlers
end

local function getHandler()
	if #AnimLib.handlers == 0 then scanAllHandlers() end
	local lc = localChar()
	if lc then
		for _, h in ipairs(AnimLib.handlers) do
			local anims = rawget(h, "Anims")
			if type(anims) == "table" and anims[lc] ~= nil then
				AnimLib.handler = h
				return h
			end
		end
	end
	AnimLib.handler = AnimLib.handlers[1]
	return AnimLib.handler
end

function registryKind(model, id)
	if not model then return nil end
	if #AnimLib.handlers == 0 then getHandler() end
	for _, h in ipairs(AnimLib.handlers) do
		if type(rawget(h, "GetAnims")) == "function" then
			local cats
			local ok = pcall(function() cats = h.GetAnims(model) end)
			if ok and type(cats) == "table" then
				for catName, entries in pairs(cats) do
					if type(catName) == "string" and type(entries) == "table" then
						for key, entry in pairs(entries) do
							local kid = tonumber(tostring(key):match("(%d+)"))
							if not kid and type(entry) == "table" and entry.Track then
								pcall(function()
									local a = entry.Track.Animation
									if a then kid = tonumber(tostring(a.AnimationId):match("(%d+)")) end
								end)
							end
							if kid == id then
								if catName == "M1" then return "M1" end
								if catName == "M2" or catName == "WrestlingM2" then return "M2" end
								return catName
							end
						end
					end
				end
			end
		end
	end
	return nil
end

local function getAnimator()
	local c = localChar()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	return hum:FindFirstChildOfClass("Animator") or hum
end

local function findAnimByName(root, wanted)
	local found
	pcall(function()
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Animation") and d.Name == wanted then found = d; break end
		end
	end)
	return found
end

local function resolveBlockAnim()
	if AnimLib.blockAnim and AnimLib.blockAnim.Parent then return AnimLib.blockAnim end
	local a
	pcall(function()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local utils  = shared and shared:FindFirstChild("Utils")
		local mod    = utils and utils:FindFirstChild("CombatAnimationUtils")
		if mod then
			local CAU = require(mod)
			local folder = CAU.GetCombatAnimsFolderForPlayer(LocalPlayer)
			if folder then a = folder:FindFirstChild("Blocking") end
		end
	end)
	if not a then
		local anims = ReplicatedStorage:FindFirstChild("Animations") or ReplicatedStorage:FindFirstChild("Animations_Folder")
		if anims then a = findAnimByName(anims, "Blocking") end
	end
	AnimLib.blockAnim = a
	return a
end

local function playBlockAnim()
	if not Config.LegitAnims then return end
	if os.clock() < (State.swingAnimUntil or 0) then return end
	local char = localChar()
	local anim = resolveBlockAnim()
	if not char or not anim then return end

	local h = getHandler()
	if h and h.LoadAnim then
		local ok, tr = pcall(function() return h.LoadAnim(char, "Blocking", anim, nil, false) end)
		if ok and tr then
			local oldTr = AnimLib.tracks.Blocking
			AnimLib.tracks.Blocking = tr
			pcall(function() if oldTr and oldTr ~= tr and oldTr.Destroy then oldTr:Destroy() end end)
			pcall(function() if not tr.IsPlaying then tr:Play(0.08) end end)
			return
		end
	end
	local animator = getAnimator()
	if not animator then return end
	local tr = AnimLib.tracks.Blocking
	if not tr or not tr.IsPlaying then
		pcall(function()
			if not tr then
				local oldTr = AnimLib.tracks.Blocking
				tr = animator:LoadAnimation(anim); AnimLib.tracks.Blocking = tr
				pcall(function() if oldTr and oldTr ~= tr and oldTr.Destroy then oldTr:Destroy() end end)
			end
			tr.Priority = Enum.AnimationPriority.Action
			if not tr.IsPlaying then tr:Play(0.08) end
		end)
	end
end

local function stopBlockAnim()
	local char = localChar()
	local h = getHandler()
	if char and h and h.StopAnim then
		pcall(function() h.StopAnim(char, "Blocking", nil, 0.08) end)
	end
	local tr = AnimLib.tracks.Blocking
	if tr then pcall(function() tr:Stop(0.08) end) end
end

local function dashAnimMix(hrp, moveDir)
	local flat = Vector3.new(moveDir.X, 0, moveDir.Z)
	if flat.Magnitude < 0.05 then return { "DashBack" } end
	local u     = flat.Unit
	local fwd   = hrp.CFrame.LookVector;  fwd   = Vector3.new(fwd.X, 0, fwd.Z)
	local right = hrp.CFrame.RightVector; right = Vector3.new(right.X, 0, right.Z)
	if fwd.Magnitude < 0.05 then return { "DashBack" } end
	local ang = math.deg(math.atan2(u:Dot(right.Unit), u:Dot(fwd.Unit)))
	if ang > -22.5 and ang <= 22.5   then return { "DashFront" } end
	if ang > 22.5  and ang <= 67.5   then return { "DashFront", "DashRight" } end
	if ang > 67.5  and ang <= 112.5  then return { "DashRight" } end
	if ang > 112.5 and ang <= 157.5  then return { "DashBack", "DashRight" } end
	if ang > 157.5 or  ang <= -157.5 then return { "DashBack" } end
	if ang > -157.5 and ang <= -112.5 then return { "DashBack", "DashLeft" } end
	if ang > -112.5 and ang <= -67.5 then return { "DashLeft" } end
	return { "DashFront", "DashLeft" }
end

local function resolveDashAnim(name)
	if AnimLib.dashCache[name] and AnimLib.dashCache[name].Parent then return AnimLib.dashCache[name] end
	local a
	local anims = ReplicatedStorage:FindFirstChild("Animations") or ReplicatedStorage:FindFirstChild("Animations_Folder")
	if anims then
		local mv = anims:FindFirstChild("Movement")
		if mv then a = mv:FindFirstChild(name) end
		if not a then a = findAnimByName(anims, name) end
	end
	AnimLib.dashCache[name] = a
	return a
end

local function playDodgeMotion(dirOverride, speedOverride)
	if not Config.LegitAnims then return end
	local hrp = localHRP()
	if not hrp then return end
	local c   = localChar()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local moveDir = (hum and hum.MoveDirection) or Vector3.new()
	if dirOverride and dirOverride.Magnitude > 0.05 then
		moveDir = Vector3.new(dirOverride.X, 0, dirOverride.Z)
	end
	local mix = dashAnimMix(hrp, moveDir)

	local h = getHandler()
	local playedViaHandler = false
	if c and h and h.LoadAnim then
		pcall(function() h.StopAnim(c, "Evasive", nil, 0.05) end)
		local tracks = {}
		for _, name in ipairs(mix) do
			local anim = resolveDashAnim(name)
			if anim then
				local ok, tr = pcall(function() return h.LoadAnim(c, "Evasive", anim, nil, false) end)
				if ok and tr then tracks[#tracks+1] = tr end
			end
		end
		if #tracks == 2 then
			pcall(function() tracks[1]:AdjustWeight(0.5, 0.05); tracks[2]:AdjustWeight(0.5, 0.05) end)
		end
		playedViaHandler = #tracks > 0
	end
	if not playedViaHandler then
		local animator = getAnimator()
		if animator then
			for _, name in ipairs(mix) do
				local anim = resolveDashAnim(name)
				if anim then
					pcall(function()
						local tr = animator:LoadAnimation(anim)
						tr.Priority = Enum.AnimationPriority.Action2
						tr:Play(0.05, #mix == 2 and 0.5 or 1)
					end)
				end
			end
		end
	end

	pcall(function()
		local oldV = hrp:FindFirstChild("EvasiveDashLinearVelocity"); if oldV then oldV:Destroy() end
		local oldA = hrp:FindFirstChild("EvasiveDashAttachment");     if oldA then oldA:Destroy() end
		hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
		local flat = Vector3.new(moveDir.X, 0, moveDir.Z)
		local dir  = (flat.Magnitude > 0.001) and flat.Unit or (-hrp.CFrame.LookVector)
		local att  = Instance.new("Attachment"); att.Name = "EvasiveDashAttachment"; att.Parent = hrp
		local lv   = Instance.new("LinearVelocity"); lv.Name = "EvasiveDashLinearVelocity"
		lv.MaxForce = 100000
		lv.VectorVelocity = dir * math.min(speedOverride or Config.DashSpeed, Config.DashSpeed)
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = hrp
		Debris:AddItem(att, Config.DashDuration)
		Debris:AddItem(lv, Config.DashDuration)
	end)
end

local spoofStamp = LPH_NO_VIRTUALIZE(function(tsServer)
	local extra = State.pressSpoofExtra or 0
	if Config.TimeSpoof then
		extra = extra + ((Config.TimeShiftMs or 0) / 1000)
	end
	if extra <= 0 then return tsServer end
	return tsServer - extra
end)

local sendActivate = LPH_NO_VIRTUALIZE(function(tsServer, stunTap)
	local now = os.clock()
	if now - State.lastAct < Config.MinActGap then return false end
	State.lastAct = now
	local c = localChar()
	if stunTap then
		if c and c:GetAttribute("Blocking") then
			c:SetAttribute("Blocking", nil)
		end
		State.guardUp = false
		stopBlockAnim()
	else
		if c then c:SetAttribute("Blocking", true) end
		State.guardUp = true
		playBlockAnim()
	end
	local ts = tsServer or Workspace:GetServerTimeNow()
	ServerRemote:FireServer(
		{ Type = "Combat", Action = "Block", Func = "Activated" },
		spoofStamp(ts)
	)
	return true
end)

local sendDeactivate = LPH_NO_VIRTUALIZE(function(force)
	local now = os.clock()
	if not force and now - State.lastDeact < Config.MinDeactGap then return false end
	State.lastDeact = now
	local c = localChar()
	if c then c:SetAttribute("Blocking", nil) end
	ServerRemote:FireServer({ Type = "Combat", Action = "Block", Func = "Deactivated" })
	State.guardUp = false
	stopBlockAnim()
	return true
end)

local function sendDodge(dir, speedOverride)
	if State.guardUp or State.blocking then
		State.blocking, State.holdUntil = false, 0
		sendDeactivate(true)
		stopBlockAnim()
	end
	ServerRemote:FireServer({ Type = "Combat", Action = "Evasive", Func = "Evasive" })
	playDodgeMotion(dir, speedOverride)
	State.lastDodge  = os.clock()
	State.dodgeCount = State.dodgeCount + 1
	State.flashUntil = os.clock() + 0.25
	State.status     = "DODGE"
	return true, nil
end

_D.BOXING_BLOCK_ATTRS = {
	"CombatAttacking", "Stunned", "Ragdoll",
	"ParryAttackLockout", "BlockAttackLockout",
}

local function counterStyle()
	if _C.counterStyleFrame == _C.FrameId then return _C.counterStyleVal end
	local c = localChar()
	local key = c and styleKey(styleOf(c) or "") or ""
	local out
	if key == "boxing" then out = Config.BoxingCounter and "boxing" or nil
	elseif key == "ali" then out = Config.AliCounter and "ali" or nil
	elseif key == "wingchun" then out = Config.WingChunCounter and "wingchun" or nil
	elseif key == "aikido" then out = Config.AikidoCounter and "aikido" or nil
	end
	_C.counterStyleFrame, _C.counterStyleVal = _C.FrameId, out
	return out
end

local function wcStartup()
	local base = Config.WCStartup or _D.WINGCHUN.StartupSecs or (7 / 60)
	return math.clamp(base, 0.02, 0.9)
end

local function steerM2Variant(want)
	local c = localChar(); if not c then return end
	local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local hrp = localHRP(); if not hrp then return end
	local dir
	if want == "Right" then dir = hrp.CFrame.RightVector else dir = hrp.CFrame.LookVector end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.05 then return end
	State.ap.steerDir   = dir.Unit
	State.ap.steerUntil = os.clock() + (Config.AliVariantSteerDur or 0.15)
	hum:Move(State.ap.steerDir, false)
end

local eHitActive = LPH_NO_VIRTUALIZE(function(c)
	local h = getHandler()
	if not (c and h and h.GetAnims) then return false end
	local ok, bucket = pcall(h.GetAnims, c, "EHit")
	return ok and type(bucket) == "table" and next(bucket) ~= nil
end)

local counterReady = LPH_NO_VIRTUALIZE(function()
	if not Config.SkillAddon then return false, "SkillAddon-off" end
	local c = localChar()
	if not c then return false, "no-character" end
	local cs = counterStyle()
	if not cs then return false, "counter-style-disabled" end
	if (os.clock() - (State.lastCounter or 0)) < (Config.BoxingCounterGap or 0.30) then
		return false, "BoxingCounterGap"
	end
	for _, attr in ipairs(_D.BOXING_BLOCK_ATTRS) do
		if c:GetAttribute(attr) then return false, attr end
	end
	if c:GetAttribute("CantAnything") and not c:GetAttribute("CombatRecovery") then
		return false, "CantAnything"
	end
	if not c:GetAttribute("Equip") then return false, "Equip" end
	if c:GetAttribute("Greenzone") then return false, "Greenzone" end
	if c:GetAttribute("RpCombatLocked") then return false, "RpCombatLocked" end
	if c:GetAttribute("M2Cooldown") then return false, "M2Cooldown" end
	if c:GetAttribute("M2CD") then return false, "M2CD" end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false, "dead" end
	if eHitActive(c) then return false, "EHit" end
	return true, "ready"
end)

function V93.markOwnM2IFrames(now, tag)
	local style = tostring(styleOf(localChar()) or ""):lower()
	loadGameModules()
	local lastContact = 0.43
	if GameData.cfg and GameData.cfg.GetStyleM2HitboxDelay then
		local d = GameData.cfg.GetStyleM2HitboxDelay(style, false, nil)
		if type(d) == "number" and d > 0 then lastContact = d end
		if GameData.cfg.GetStyleM2Variants then
			local vs = GameData.cfg.GetStyleM2Variants(style)
			if type(vs) == "table" then
				for _, vid in pairs(vs) do
					local d2 = GameData.cfg.GetStyleM2HitboxDelay(style, false, vid)
					if type(d2) == "number" and d2 > lastContact then lastContact = d2 end
				end
			end
		end
	end
	if isBoxingStyle(style) then
		local mc = V93.boxingM2Contacts
		if type(mc) == "table" then
			for i = 1, #mc do
				if type(mc[i]) == "number" and mc[i] > lastContact then lastContact = mc[i] end
			end
		end
	end
	State.counterIFramesUntil = 0
	State.attackBusyUntil = math.max(State.attackBusyUntil or 0, now + lastContact)
	State.selfBusyUntil   = math.max(State.selfBusyUntil or 0, now + lastContact)
	State.ownIFrameTag = tag
end

State.updateCounterTxn = LPH_NO_VIRTUALIZE(function(now)
	local tx = State.counterTxn
	if not tx or (not tx.pending and not tx.confirmed) then return end
	local th = tx.threat
	local ch = localChar()
	local liveIFrames = ch and (ch:GetAttribute("IFRAMES")
		or ch:GetAttribute("UltraInstinct")) or false
	local enemyStopped, stopSource = false, nil
	local enemy = th and th.attackerModel
	if enemy and enemy.Parent then
		if enemy:GetAttribute("Parried") or enemy:GetAttribute("Stunned")
			or enemy:GetAttribute("Ragdoll") or enemy:GetAttribute("Downed")
			or enemy:GetAttribute("GuardBroken") then
			enemyStopped, stopSource = true, "enemy-state"
		elseif th.kind == "M1" and th.trackSeen and th.track then
			if th.track.IsPlaying == false and now > tx.sent then
				enemyStopped, stopSource = true, "enemy-track-stopped"
			end
		end
	end

	if liveIFrames then
		local follow = 0
		local iframeUntil = (tx.sent or now) + (GameData.iframeDur or Config.IFrameDur or 0.30)
		for i = 1, #Threats do
			local other = Threats[i]
			local sameAttacker = (other == th)
				or (th and other.attackerModel and th.attackerModel and other.attackerModel == th.attackerModel)
				or (th and other.name == th.name)
			if sameAttacker and not other.dodged then
				if (other.contactAbs or 0) <= iframeUntil + 0.04 then
					other.coveredByCounter = true
					other.counterPendingId = nil
					if other ~= th then follow = follow + 1 end
				elseif other ~= th and other.coveredByCounter then
					other.coveredByCounter = nil
				end
			end
		end
		if th then
			th.coveredByCounter, th.counterPendingId, th.resolved = true, nil, true
		end
		if not tx.confirmed then
			tx.confirmed, tx.pending, tx.result = true, false, "IFRAMES"
			State.counterIFramesUntil = now + 0.45
			diagPush("COUNTER-CONFIRM t=%.2f id=%s src=IFRAMES sentAgo=%.0fms → threat covered, dodge not needed", now, tostring(tx.threatId), (now - tx.sent) * 1000)
		elseif follow > 0 and not tx.followCoverLogged then
			tx.followCoverLogged = true
			diagPush("COUNTER-COVER t=%.2f id=%s follow-ups=%d while IFRAMES live → не парируем (CantAnything от своего M2)", now, tostring(tx.threatId), follow)
		end
		return
	end
	if tx.confirmed then
		for i = 1, #Threats do
			local other = Threats[i]
			if other.coveredByCounter and other ~= th and not other.resolved then
				other.coveredByCounter = nil
			end
		end
		tx.confirmed, tx.pending, tx.followCoverLogged = false, false, nil
		State.counterIFramesUntil = 0
		return
	end

	if enemyStopped then
		if th then
			th.coveredByCounter, th.counterPendingId, th.resolved = true, nil, true
		end
		tx.pending, tx.confirmed, tx.result = false, false, stopSource
		diagPush("COUNTER-CONFIRM t=%.2f id=%s src=%s sentAgo=%.0fms → threat neutralized, dodge not needed", now, tostring(tx.threatId), tostring(stopSource), (now - tx.sent) * 1000)
		return
	end

	local coverageMiss = th and (th.contactAbs or 0) <= (tx.expectedIFramesAt or 0)
	local timedOut = now >= (tx.ackDeadline or 0)
	if (tx.confirmed and not liveIFrames) or (tx.pending and (timedOut or coverageMiss)) then
		if th then
			th.counterPendingId = nil
			th.coveredByCounter = nil
		end
		local why = tx.confirmed and "IFRAMES ended before contact"
			or (coverageMiss and "expected IFRAMES cannot precede contact" or "IFRAMES not confirmed")
		tx.pending, tx.confirmed, tx.result = false, false, "fallback"
		State.counterIFramesUntil = 0
		State.allowRearmUntil = now + 0.28
		diagPush("COUNTER-FAIL/FALLBACK t=%.2f id=%s gate=%s sentAgo=%.0fms → normal defense restored", now, tostring(tx.threatId), why, (now - tx.sent) * 1000)
	end
end)

State.updateAliM2Cooldown = LPH_NO_VIRTUALIZE(function(now)
	local cd = State.aliM2CD
	local ch = localChar()
	if ch ~= cd.char then
		cd.char, cd.observed, cd.active, cd.known, cd.started = ch, false, false, false, 0
		local tx = State.dodgeTxn
		if tx then
			tx.pending, tx.confirmed, tx.perfectConfirmed = false, false, false
			tx.abuseThreat, tx.perfectAt, tx.reason = nil, nil, nil
		end
		State.ap.dodgeSteerDir, State.ap.dodgeSteerUntil = nil, 0
	end
	if not ch then return end
	local active = ch:GetAttribute("M2Cooldown")
	if not cd.observed then
		cd.observed, cd.active = true, active
		if active then cd.known = false end
		return
	end
	if active and not cd.active then
		loadGameModules()
		local duration = 7
		if GameData.cfg and GameData.cfg.GetStyleM2Cooldown then
			local ok, v = pcall(GameData.cfg.GetStyleM2Cooldown, "ali")
			if ok and type(v) == "number" and v > 0 then duration = v end
		end
		cd.started, cd.duration, cd.known = now, duration, true
	elseif not active and cd.active then
		cd.known, cd.started = false, 0
	end
	cd.active = active
end)

_C.PARRY_ONLY_M2_CACHE = {}
local function m2IsParryOnlyStyle(style)
	local st = tostring(style or ""):lower()
	if st == "" then return false end
	local cached = _C.PARRY_ONLY_M2_CACHE[st]
	if cached ~= nil then return cached end
	loadGameModules()
	local cfg = GameData.cfg
	local verdict = (st == "boxing")
	if cfg then
		local iframeDur = GameData.iframeDur or Config.IFrameDur or 0.30
		if cfg.GetStyleM2HitboxDuration then
			local dur = cfg.GetStyleM2HitboxDuration(st)
			if type(dur) == "number" and dur > 0 and dur >= iframeDur then
				verdict = true
			end
		end
		local multi
		if cfg.GetStyleNumber then
			local v = cfg.GetStyleNumber(st, "M2MultiHitCount", 1)
			if type(v) == "number" then multi = v end
		end
		local grants
		if cfg.GetStyleBoolean then
			local v = cfg.GetStyleBoolean(st, "M2GrantsIFrames", false)
			if type(v) == "boolean" then grants = v end
		end
		if multi == nil or grants == nil then
			local styles = cfg.Styles
			local s = type(styles) == "table" and styles[st] or nil
			if type(s) == "table" then
				if multi == nil and type(s.M2MultiHitCount) == "number" then multi = s.M2MultiHitCount end
				if grants == nil and type(s.M2GrantsIFrames) == "boolean" then grants = s.M2GrantsIFrames end
			end
		end
		if type(multi) == "number" and multi > 1 then verdict = true end
		if grants == true then verdict = true end
	end
	_C.PARRY_ONLY_M2_CACHE[st] = verdict
	return verdict
end

function State.isParryOnlyM2(th)
	return th ~= nil and th.kind == "M2" and m2IsParryOnlyStyle(th.style)
end

_C.M2_BREAKS_GUARD = {}
local function styleM2BreaksHeldGuard(style)
	local st = tostring(style or ""):lower()
	if st == "" then return false end
	local cached = _C.M2_BREAKS_GUARD[st]
	if cached ~= nil then return cached end
	-- V216: Ali/Boxing M2 парируются. M2RagdollLaunchStrength на стиле
	-- (Ali Left Ragdolls=false) ошибочно снимал гард под boxing-counter.
	if m2IsParryOnlyStyle(st) then
		_C.M2_BREAKS_GUARD[st] = false
		return false
	end
	loadGameModules()
	local verdict = false
	local cfg = GameData.cfg
	if cfg and cfg.GetStyleConfig then
		local ok, sc = pcall(cfg.GetStyleConfig, st)
		if ok and type(sc) == "table" then
			-- Ragdoll-on-HIT (Hakari/Dragon/Striker) is parryable. V281
			-- treated M2RagdollLaunchStrength as guard-break → SkillAddon
			-- counter path skipped parry. Only grabs / fat chip.
			if type(sc.M2BlockChipPercent) == "number" and sc.M2BlockChipPercent >= 0.45 then
				verdict = true
			elseif type(sc.M2GrabTargetForwardOffset) == "number" then
				verdict = true
			elseif sc.M2GrabAllowRagdollCombo
				or (type(sc.M2GrabLockDuration) == "number")
				or (type(sc.M2SlamParryWindowDisableDuration) == "number") then
				verdict = true
			end
		end
	end
	if not verdict then
		verdict = st == "wrestling" or st == "kure" or st == "judo" or st == "dirty"
	end
	_C.M2_BREAKS_GUARD[st] = verdict
	return verdict
end

local function m2BreaksHeldGuard(th)
	return th ~= nil and th.kind == "M2" and styleM2BreaksHeldGuard(th.style)
end
State.m2BreaksHeldGuard = m2BreaksHeldGuard

-- full=true: cover the whole iframe (grabs / ali abuse).
-- full=false: center window used by optional dodges.
_C.dodgeCoverWindow = function(ifLat, ifDur, full)
	local lo = (ifLat or 0.08) - 0.03
	local dur = ifDur or 0.30
	local hi
	if full then
		hi = (ifLat or 0.08) + dur - 0.04
	else
		hi = math.min(
			(ifLat or 0.08) + dur * (Config.DodgeCenterFrac or 0.5) + (Config.DodgeCenterBias or 0),
			(ifLat or 0.08) + dur - 0.04
		)
	end
	if hi < lo then hi = lo end
	return lo, hi
end

function State.isAliBoxingM2(th)
	return (styleOf(localChar()) or ""):lower() == "ali" and State.isParryOnlyM2(th)
end

function State.clusterHasAliBoxingM2(cluster)
	for _, th in ipairs(cluster or {}) do
		if State.isAliBoxingM2(th) then return true end
	end
	return false
end

function State.aliDodgeAbuseEligible(th, now, imminent, ifLat, ifDur)
	if not (Config.SkillAddon and Config.AliDodgeAbuse and Config.AliEvasiveCounter and Config.AutoDodge) then
		return false, nil, "disabled"
	end
	if (styleOf(localChar()) or ""):lower() ~= "ali" then return false, nil, "not-ali" end
	if not th or not th.serverProven then return false, nil, "not-server-proven" end
	if State.isMustDodge and State.isMustDodge(th) then return false, nil, "must-dodge" end

	local meC = localChar()
	if meC then
		if meC:GetAttribute("CombatAttacking") then return false, nil, "self-attacking" end
		if meC:GetAttribute("Stunned") then return false, nil, "stunned" end
		if meC:GetAttribute("CantAnything") then return false, nil, "cant-anything" end
		if meC:GetAttribute("GuardBroken") then return false, nil, "guard-broken" end
	end

	if State.isAliBoxingM2(th) then return false, nil, "boxing-m2-parry" end

	local remaining = 999
	local cd = State.aliM2CD
	if cd and cd.active and cd.known then
		remaining = (cd.started + cd.duration) - now
		if remaining <= 1.0 then return false, nil, "m2-ready-soon" end
	end

	local innerLo, innerHi = _C.dodgeCoverWindow(ifLat, ifDur, true)
	local dt = th.contactAbs - now
	if dt < innerLo or dt > innerHi then return false, nil, "primary-outside-iframe" end
	return true, remaining, "primary-covered"
end

local function resolveM2Module()
	if State.ap.m2 and type(State.ap.m2.OnM2Activated) == "function" then
		return State.ap.m2
	end
	local mod
	pcall(function()
		local csc = ReplicatedStorage:FindFirstChild("CombatSystemClient")
		local base = csc and csc:FindFirstChild("Combat")
		base = base and base:FindFirstChild("Base")
		mod = base and base:FindFirstChild("M2")
	end)
	if not mod then
		pcall(function()
			for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
				if d.Name == "M2" and d:IsA("ModuleScript")
				   and d.Parent and d.Parent.Name == "Base" then
					mod = d
					break
				end
			end
		end)
	end
	if mod then
		local ok, tbl = pcall(require, mod)
		if ok and type(tbl) == "table" and type(tbl.OnM2Activated) == "function" then
			State.ap.m2 = tbl
		end
	end
	if not State.ap.m2 and type(filtergc) == "function" then
		pcall(function()
			local t = filtergc("table", {
				Keys = { "OnM2Activated", "ServerResponse", "OnServerSwing" },
			}, true)
			if type(t) == "table" and type(t.OnM2Activated) == "function" then
				State.ap.m2 = t
			end
		end)
	end
	return State.ap.m2
end

-- Игра ставит клиентский M2-кулдаун (HUD) только в OnM2Activated
-- (scheduleM2SwingCooldown). Голый ServerCheck HUD не видит.
local function fireNativeM2()
	local m2 = resolveM2Module()
	if m2 and type(m2.OnM2Activated) == "function" then
		local ok = pcall(m2.OnM2Activated)
		return ok
	end
	ServerRemote:FireServer({ Type = "Combat", Action = "M2", Func = "ServerCheck" })
	return true
end

local fireBoxingCounter = LPH_NO_VIRTUALIZE(function(th, targetDist)
	local myHRP = localHRP()
	local aHRP  = th and th.attackerHRP
	if myHRP and aHRP and aHRP.Parent then
		local d = flatDirTo(myHRP.Position, aHRP.Position)
		if d then myHRP.CFrame = CFrame.lookAt(myHRP.Position, myHRP.Position + d) end
		local faceHold = (counterStyle() == "ali") and (Config.AliFaceLockDur or 0.75)
			or (Config.BoxingFaceLockDur or 0.55)
		setFaceGoal(aHRP, true, faceHold)
	end
	if State.blocking then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		sendDeactivate(true)
	end
	local cs = counterStyle()
	if cs == "ali" then
		if _D.aliM2HasVars == nil then
			loadGameModules()
			local hasVars = false
			if GameData.cfg and GameData.cfg.GetStyleM2Variants then
				local vs = GameData.cfg.GetStyleM2Variants(cs)
				hasVars = type(vs) == "table"
			end
			_D.aliM2HasVars = hasVars
		end
		if _D.aliM2HasVars then steerM2Variant(Config.AliM2Variant or "Left") end
	end
	if not fireNativeM2() then return end
	local sentAt = os.clock()
	State.lastCounter  = sentAt
	State.counterFiredFrame = _C.FrameId
	State.interruptLockUntil = math.max(State.interruptLockUntil or 0, sentAt + 0.40)
	State.counterCount = (State.counterCount or 0) + 1
	State.flashUntil   = sentAt + 0.25
	State.status       = (cs == "ali") and "ALI-COUNTER"
		or ((cs == "wingchun" or cs == "aikido") and "WC-COUNTER") or "BOX-COUNTER"
	local tx = State.counterTxn
	if tx.threat and tx.threat ~= th then tx.threat.counterPendingId = nil end
	tx.seq = (tx.seq or 0) + 1
	local net = math.max(uplink(), 0.02)
	local rtt = getPing()
	if rtt < net * 2 then rtt = net * 2 end
	tx.pending, tx.confirmed, tx.sent = true, false, sentAt
	tx.ackDeadline = sentAt + rtt + (V93.lookahead or 0) + 0.10
	tx.expectedIFramesAt = (cs == "wingchun" or cs == "aikido") and math.huge
			or (sentAt + net + math.max(V93.lookahead or 0, 0) + math.max(V93.frameDt or 0, 1 / 60))
	tx.threat, tx.source, tx.result = th, cs, "sent"
	tx.threatId = tostring(th.serverSwingId or (th.group and th.group.serverSwingId)
		or ((th.name or "?") .. "/" .. (th.kind or "?") .. "/" .. math.floor((th.detectClock or sentAt) * 1000)))
	th.counterPendingId = tx.seq
	State.counterPreemptFrame = -1
	diagPush("COUNTER-SEND t=%.2f id=%s target=%s/%s dist=%.1f gate=M2-ready ack=%0.fms", sentAt, tx.threatId, tostring(th.name), tostring(th.kind), targetDist or -1,
			(tx.ackDeadline - sentAt) * 1000)
	if cs == "wingchun" or cs == "aikido" then
		local su = wcStartup()
		_D.WCTxn.pending  = true
		_D.WCTxn.sentAt   = sentAt
		_D.WCTxn.openAt   = sentAt + net + su
		_D.WCTxn.closeAt  = _D.WCTxn.openAt + counterStanceWindow(cs)
		_D.WCTxn.threat   = th
		_D.WCTxn.threatId = tx.threatId
		_D.WCTxn.style    = cs
		_D.WCTxn.whiffStun = (cs == "aikido") and 1.2 or _D.WINGCHUN.CounterWhiffStun
		_D.WCTxn.holdSecs = (cs == "aikido") and 1.95 or _D.WINGCHUN.CounterHoldSecs
		_D.WCTxn.victimHitStun = (cs == "aikido") and 2.3 or _D.WINGCHUN.VictimHitStun
		State.attackBusyUntil = math.max(State.attackBusyUntil or 0, _D.WCTxn.closeAt)
		State.selfBusyUntil   = math.max(State.selfBusyUntil or 0, _D.WCTxn.closeAt)
		diagPush("WC-COUNTER-SEND t=%.2f id=%s style=%s target=%s/%s dist=%.1f startup=%.0fms(%s) window=[%.0f..%.0f]ms contactIn=%.0fms iframes=NONE",
			sentAt, tostring(tx.threatId), tostring(cs), tostring(th.name), tostring(th.kind), targetDist or -1,
			su * 1000, "fixed+ping",
			(_D.WCTxn.openAt - sentAt) * 1000, (_D.WCTxn.closeAt - sentAt) * 1000,
			((th.contactAbs or sentAt) - sentAt) * 1000)
	else
		V93.markOwnM2IFrames(os.clock(), "counter/" .. tostring(cs))
	end
end)

local tryAliEvasiveCounter = LPH_NO_VIRTUALIZE(function(now)
	if not Config.SkillAddon or not Config.AliEvasiveCounter then return false end
	if (styleOf(localChar()) or ""):lower() ~= "ali" then return false end
	local tx = State.dodgeTxn
	if not (tx and tx.pending and tx.perfectConfirmed) then return false end
	if tx.evCounterFired then return false end
	if not tx.confirmed then
		if not tx.evCounterAwaitIframeLogged then
			tx.evCounterAwaitIframeLogged = true
			diagPush("ALI-EVCOUNTER-WAIT t=%.2f gate=await-iframe perfectAgo=%.0fms", now, (now-(tx.perfectAt or now))*1000)
		end
		return false
	end
	if GameData.aliEvCfg == nil then
		loadGameModules()
		local ec0
		if GameData.cfg and GameData.cfg.GetStyleEvasiveCounter then
			local ok, v = pcall(GameData.cfg.GetStyleEvasiveCounter, "ali")
			if ok and type(v) == "table" then ec0 = v end
		end
		GameData.aliEvCfg = ec0 or false
	end
	local ec = GameData.aliEvCfg ~= false and GameData.aliEvCfg or nil
	local cd    = (ec and tonumber(ec.Cooldown))  or 6
	local range = (ec and tonumber(ec.MaxRange))  or 22
	if (now - (State.lastEvCounter or -99)) < cd then return false end
		local procTTL = math.min(cd * (Config.AliProcTTLFrac or 0.25), Config.AliProcTTLMax or 1.5)
		local procDeadline = math.max(tx.untilAt or 0, (tx.perfectAt or now) + procTTL)
		if now > procDeadline then
			if not tx.evCounterExpiredLogged then
				tx.evCounterExpiredLogged = true
				diagPush("ALI-EVCOUNTER-EXPIRE t=%.2f perfectAgo=%.0fms gate=proc-window-ended ttl=%.0fms", now, (now-(tx.perfectAt or now))*1000, procTTL*1000)
			end
			return false
		end
	local c = localChar()
	if not c then return false end
	local stateGate = not c:GetAttribute("Equip") and "not-equipped"
		or (c:GetAttribute("Stunned") and "stunned")
		or nil
	if stateGate then
		if tx.evCounterStateGate ~= stateGate then
			tx.evCounterStateGate = stateGate
			diagPush("ALI-EVCOUNTER-WAIT t=%.2f gate=%s perfectAgo=%.0fms", now, stateGate, (now-(tx.perfectAt or now))*1000)
		end
		return false
	end
	local myHRP = localHRP(); if not myHRP then return false end
	local myPos = myHRP.Position
	local best, bestDist
	local bound = tx.abuseThreat
	if bound then
		local aHRP = bound.attackerHRP
		if aHRP and aHRP.Parent then
			local dx, dz = myPos.X - aHRP.Position.X, myPos.Z - aHRP.Position.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= range then best, bestDist = bound, d end
		end
		if not best then
			if not tx.evCounterTargetGateLogged then
				tx.evCounterTargetGateLogged = true
				diagPush("ALI-EVCOUNTER-WAIT t=%.2f gate=bound-target-missing-or-range range=%.0f", now, range)
			end
			return false
		end
	else
		for i = 1, #Threats do
			local th = Threats[i]
			local aHRP = th.attackerHRP
			local boxingM2 = tostring(th.style or ""):lower() == "boxing" and th.kind == "M2"
			if aHRP and aHRP.Parent and not boxingM2 then
				local dx, dz = myPos.X - aHRP.Position.X, myPos.Z - aHRP.Position.Z
				local d = math.sqrt(dx * dx + dz * dz)
				if d <= range and (not bestDist or d < bestDist) then best, bestDist = th, d end
			end
		end
		if not best then return false end
	end
	local aHRP = best.attackerHRP
	if aHRP and aHRP.Parent then
		local d = flatDirTo(myPos, aHRP.Position)
		if d then myHRP.CFrame = CFrame.lookAt(myPos, myPos + d) end
		setFaceGoal(aHRP, true, Config.AliFaceLockDur or 0.75)
	end
	if State.blocking then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		sendDeactivate(true)
	end
	do
		local attacking = c and c:GetAttribute("CombatAttacking")
		if attacking then
			ServerRemote:FireServer({ Type = "Combat", Action = "M2", Func = "ServerCheck" })
		elseif not fireNativeM2() then
			return
		end
	end
	tx.evCounterFired    = true
	State.lastEvCounter  = now
	State.evCounterCount = (State.evCounterCount or 0) + 1
	State.flashUntil     = now + 0.25
	State.status         = "ALI-EV-COUNTER"
	diagPush("ALI-EVCOUNTER-SEND t=%.2f target=%s dist=%.1f range=%.0f specialCd=%.0fs ignoreNormalM2Cd=true variant=Left perfectAgo=%.0fms gate=one-StyleEvasiveCounter", now, best.name or "?", bestDist, range, cd, (now-(tx.perfectAt or now))*1000)
	return true
end)

function State.counterBlockedPerm()
	if not Config.SkillAddon then return true end
	local c = localChar(); if not c then return true end
	if not counterStyle() then return true end
	if not c:GetAttribute("Equip") then return true end
	if c:GetAttribute("M2Cooldown") or c:GetAttribute("M2CD") then return true end
	if c:GetAttribute("Greenzone") or c:GetAttribute("RpCombatLocked") then return true end
	if c:GetAttribute("Ragdoll") or c:GetAttribute("Downed") then return true end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return true end
	if eHitActive(c) then return true end
	return false
end

function State.counterReadyAt(now)
	local at = now
	local gapEnd = (State.lastCounter or 0) + (Config.BoxingCounterGap or 0.30)
	if gapEnd > at then at = gapEnd end
	local swingEnd = State.swingAnimUntil or 0
	if swingEnd > at then at = swingEnd end
	return at
end

local counterCandidate = LPH_NO_VIRTUALIZE(function(now, ignoreTransient)
	if ignoreTransient then
		if State.counterBlockedPerm() then return nil end
	else
		local ready, gate = counterReady()
		if not ready then return nil, nil, gate end
	end
	local myHRP = localHRP()
	if not myHRP then return nil end
	local cs = counterStyle()
	if Config.CounterOnlyWhenNoParry ~= false and cs ~= "wingchun" and cs ~= "aikido" then
		local okB = canBlockNow()
		if okB then
			local pwin = Config.PerfectWindow or 0.125
			local lead = Config.PerfectLead or 0.0625
			local upx = uplink()
			local parrySoon = false
			for i = 1, #Threats do
				local o = Threats[i]
				if o and not o.dodged and not o.resolved and not o.coveredByCounter then
					local rem = (o.contactAbs or 0) - now
					if rem <= (lead + upx + pwin + 0.05) and rem > -0.05 then
						parrySoon = true
						break
					end
				end
			end
			if parrySoon then return nil, nil, "parry-available" end
		end
	end
	if Config.CounterYieldToM2 ~= false and cs ~= "wingchun" and cs ~= "aikido" then
		local m2H = Config.CounterM2Horizon or 0.95
		for i = 1, #Threats do
			local o = Threats[i]
			if o and o.kind == "M2" and not o.dodged and not o.resolved and not o.staleTrack then
				local dtM2 = (o.contactAbs or 0) - now
				if dtM2 > -0.05 and dtM2 < m2H then
					if Config.DeepDiag and (now - (State.lastCounterM2YieldLog or 0)) > 0.35 then
						State.lastCounterM2YieldLog = now
						diagPush("COUNTER-YIELD-M2 t=%.2f skip counter: %s M2 contactIn=%.0fms",
							now, tostring(o.name), dtM2 * 1000)
					end
					return nil, nil, "m2-incoming"
				end
			end
		end
	end
	local reach = (cs == "ali") and (Config.AliCounterReach or 7.5)
		or (cs == "wingchun") and (Config.WingChunCounterReach or 6.5)
		or (cs == "aikido") and (Config.AikidoCounterReach or 6.5)
		or (Config.BoxingCounterReach or 5.5)
	local myPos = myHRP.Position
	local best, bestDist
	local mustDodgeFn = State.isMustDodge
	local minCounterRemain = math.max(Config.CounterMinRemain or 0.22, uplink() + 0.08)
	local styleIsAli = (styleOf(localChar()) or ""):lower() == "ali"
	local aliAbuseOn = styleIsAli and Config.SkillAddon and Config.AliDodgeAbuse
		and Config.AliEvasiveCounter and Config.AutoDodge ~= false
	for i = 1, #Threats do
		local th = Threats[i]
		local aHRP = th.attackerHRP
		local aliVsBoxingM2 = State.isAliBoxingM2(th)
		if aliVsBoxingM2 and not th.aliBoxingCounterLogged then
			th.aliBoxingCounterLogged = true
			diagPush("ALI-BOXING-M2=PARRY t=%.2f target=%s strike=%d contactIn=%.0fms gate=counter", now, tostring(th.name), th.strike or 1, (th.contactAbs-now)*1000)
		end
		local yieldToAbuse = false
		if aliAbuseOn then
			local ifLat = math.max(uplink(), 0.02)
			local ifDur = GameData.iframeDur or Config.IFrameDur or 0.30
			local ok = State.aliDodgeAbuseEligible(th, now, Threats, ifLat, ifDur)
			if ok then yieldToAbuse = true end
		end
		if aHRP and aHRP.Parent and not aliVsBoxingM2 and not yieldToAbuse and not th.dodged
		   and not th.coveredByDodge and not th.coveredByCounter and not th.counterPendingId
		   and not th.counterCommittedToParry
		   and not (mustDodgeFn and mustDodgeFn(th))
		   and (th.contactAbs - now) > minCounterRemain then
			local dx, dz = myPos.X - aHRP.Position.X, myPos.Z - aHRP.Position.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= reach and (not bestDist or dist < bestDist) then
				best, bestDist = th, dist
			end
		end
	end
	return best, bestDist
end)

local function counterPreemptsDodge(now)
	if State.counterPreemptFrame == _C.FrameId then return State.counterPreemptVal end
	local ch = localChar()
	if ch then
		if ch:GetAttribute("IFRAMES") or ch:GetAttribute("UltraInstinct") then
			local mustFn = State.isMustDodge
			if mustFn then
				for i = 1, #Threats do
					local o = Threats[i]
					if o and mustFn(o) and not o.dodged and not o.resolved then
						if ((o.contactAbs or 0) - now) > 0.12 then
							State.counterPreemptFrame, State.counterPreemptVal = _C.FrameId, false
							return false
						end
					end
				end
			end
			State.counterPreemptFrame, State.counterPreemptVal = _C.FrameId, true
			if now >= (State.lastPreemptLogAt or 0) + 0.5 then
				State.lastPreemptLogAt = now
				diagPush("IFRAME-COVER t=%.2f  dodge skipped, live IFRAMES attribute on us (src=%s)", now, tostring(State.ownIFrameTag or "game"))
			end
			return true
		end
	end
	if Config.CounterPreemptsDodge == false then return false end
	local ctx = State.counterTxn
	-- PENDING must not cover: V208 COUNTER-SEND → FAIL/IFRAMES → Karate c3 NO-PRESS HIT.
	-- Only confirmed iframes skip dodge/parry overlap.
	if ctx and ctx.confirmed and ctx.threat
		and now < (State.counterIFramesUntil or 0) then
		State.counterPreemptFrame, State.counterPreemptVal = _C.FrameId, true
		return true
	end
	State.counterPreemptFrame, State.counterPreemptVal = _C.FrameId, false
	return false
end

local function wcPoll(now)
	if not _D.WCTxn.pending then return end
	local net = math.max(uplink(), 0.02)
	if now <= _D.WCTxn.closeAt + net then return end
	_D.WCTxn.pending = false
	_D.WCTxn.whiffs  = (_D.WCTxn.whiffs or 0) + 1
	local whiffStun = _D.WCTxn.whiffStun or _D.WINGCHUN.CounterWhiffStun
	State.selfBusyUntil = math.max(State.selfBusyUntil or 0,
		now + whiffStun)
	diagPush("WC-COUNTER-WHIFF t=%.2f id=%s style=%s → стан %.0fms + CD %.0fс  (hits=%d whiffs=%d)",
		now, tostring(_D.WCTxn.threatId), tostring(_D.WCTxn.style or "wingchun"), whiffStun * 1000,
		_D.WINGCHUN.Cooldown, _D.WCTxn.hits or 0, _D.WCTxn.whiffs)
	_D.WCTxn.threat = nil
end

local function wcDecide(th, now, threatCount)
	local net    = math.max(uplink(), 0.02)
	local su     = wcStartup()
	local openIn = net + su
	local cs     = counterStyle()
	local win    = counterStanceWindow(cs)
	local early  = Config.WCEarlyMargin or 0.045
	local late   = Config.WCLateMargin or 0.10
	local aimIn  = openIn + math.min((Config.WCAimFrac or 0.35) * win, win - late)
	local contactIn = (th.contactAbs or now) - now

	if Config.WCSoloOnly ~= false and threatCount > 1 then
		return "parry", string.format("multi-threat(%d) без iframes", threatCount)
	end
	if Config.WCSkipGrabs ~= false and th.kind == "M2" then
		local st = styleKey(th.style)
		if st == "wrestling" or st == "dirty" or st == "perfectcopy" or st == "kure" or st == "judo" then
			return "parry", "grab-style M2 (" .. st .. ")"
		end
	end
	if Config.WCRequireLiveTrack ~= false and th.spdSrc ~= "live" then
		return "parry", "contact=predict (нет живого track.Speed)"
	end
	if contactIn < openIn + early then
		return "parry", string.format("contactIn=%.0fms < open=%.0f+%.0fms",
			contactIn * 1000, openIn * 1000, early * 1000)
	end
	if contactIn > aimIn then
		return "wait", string.format("contactIn=%.0fms > aim=%.0fms",
			contactIn * 1000, aimIn * 1000)
	end
	return "fire", string.format("contact на %.0f%% окна",
		((contactIn - openIn) / win) * 100)
end

local tryBoxingCounter = LPH_NO_VIRTUALIZE(function(now)
	wcPoll(now)
	if (State.interruptLockUntil or 0) > now then return false end
	if not Config.SkillAddon then return false end
	if not (Config.BoxingCounter or Config.AliCounter or Config.WingChunCounter or Config.AikidoCounter) then return false end
	-- Hakari/Lethwei M2: m2BreaksHeldGuard=true → ниже releaseBlock, потом
	-- COUNTER-YIELD. Гард снят, парри не жмётся. Skill Addon off = парри жив.
	if Config.CounterYieldToM2 ~= false then
		local cs0 = counterStyle()
		if cs0 ~= "wingchun" and cs0 ~= "aikido" then
			local m2H = Config.CounterM2Horizon or 0.95
			for i = 1, #Threats do
				local o = Threats[i]
				if o and o.kind == "M2" and not o.dodged and not o.resolved and not o.staleTrack then
					local dtM2 = (o.contactAbs or now) - now
					if dtM2 > -0.05 and dtM2 < m2H then
						if Config.DeepDiag and (now - (State.lastCounterM2YieldLog or 0)) > 0.35 then
							State.lastCounterM2YieldLog = now
							diagPush("COUNTER-YIELD-M2 t=%.2f skip counter: %s M2 contactIn=%.0fms keep-guard=%s",
								now, tostring(o.name), dtM2 * 1000, tostring(State.blocking == true))
						end
						return false
					end
				end
			end
		end
	end
	-- Лог V178: COUNTER-SEND через 21мс после TRACE-PRESS сорвал гард
	-- (IN-WINDOW → LATE). Контра и парри в одном кадре несовместимы.
	local gbIn = false
	for i = 1, #Threats do
		if m2BreaksHeldGuard(Threats[i]) and not Threats[i].resolved and not Threats[i].dodged then
			gbIn = true
			break
		end
	end
	-- Don't drop guard unless we actually fire. fireBoxingCounter releases.
	if State.blocking and not gbIn then
		return false
	end
	if State.lastPress and (now - State.lastPress) < 0.28 and not gbIn then return false end
	local best, bestDist = counterCandidate(now, true)
	if not best then return false end
	if wingChunCounterActive(best.attackerModel) then
		best.counterCommittedToParry = true
		if not best.wingChunGateLogged then
			best.wingChunGateLogged = true
			diagPush("WINGCHUN-GATE t=%.2f %s держит counter-стойку → контратака отменена (и��аче 2.2с стан)",
				now, tostring(best.name))
		end
		return false
	end
	local ready, gate = counterReady()
	if not ready then
		local contactAt = best.contactAbs or now
		local lead = math.max(uplink(), 0.02) + math.max(V93.lookahead or 0, 0)
			+ math.max(V93.frameDt or 0, 1 / 60)
		local viableAgain = State.counterReadyAt(now) + lead < contactAt
		if not viableAgain then best.counterCommittedToParry = true end
		if best.counterFallbackGate ~= gate then
			best.counterFallbackGate = gate
			diagPush("COUNTER-FALLBACK/PARRY t=%.2f target=%s/%s contactIn=%.0fms gate=%s retry=%s readyIn=%.0fms", now, tostring(best.name), tostring(best.kind),
					(contactAt-now)*1000, tostring(gate or "unknown"),
					tostring(viableAgain), (State.counterReadyAt(now)-now)*1000)
		end
		return false
	end
	if cs == "wingchun" or cs == "aikido" then
		local live = 0
		for i = 1, #Threats do
			local t = Threats[i]
			if not t.dodged and (t.contactAbs or 0) > now - 0.05 then
				live = live + 1
			end
		end
		local act, why = wcDecide(best, now, live)
		if act == "fire" then
			fireBoxingCounter(best, bestDist)
			return true
		end
		if act == "parry" then
			best.counterCommittedToParry = true
			if best.wcSkipWhy ~= why then
				best.wcSkipWhy = why
				diagPush("WC-COUNTER-SKIP/PARRY t=%.2f target=%s/%s reason=%s", now,
					tostring(best.name), tostring(best.kind), why)
			end
		elseif best.wcWaitWhy ~= why then
			best.wcWaitWhy = why
			diagPush("WC-COUNTER-WAIT t=%.2f target=%s/%s %s", now,
				tostring(best.name), tostring(best.kind), why)
		end
		return false
	end
	local contactIn = (best.contactAbs or now) - now
		local fr = math.max(V93.frameDt or 0, 1 / 60)
		local iframeLead = math.max(uplink(), 0.02) + math.max(V93.lookahead or 0, 0) + fr
		local parryLead = math.max(Config.PerfectLead - math.max(uplink(), 0.02), 0) + fr
	local yieldLead = math.max(iframeLead, parryLead, Config.CounterMinRemain or 0.22)
	if contactIn <= yieldLead then
		best.counterCommittedToParry = true
		if not best.counterLateSkipLogged then
			best.counterLateSkipLogged = true
			diagPush("COUNTER-SKIP/PARRY t=%.2f target=%s/%s contactIn=%.0fms need=%.0fms (iframe=%.0f parry=%.0f) gate=%s", now, tostring(best.name), tostring(best.kind), contactIn * 1000,
					yieldLead * 1000, iframeLead * 1000, parryLead * 1000,
					parryLead >= iframeLead and "PARRY-DEADLINE-FIRST" or "IFRAMES-cannot-precede-contact")
		end
		return false
	end
	fireBoxingCounter(best, bestDist)
	return true
end)

local isMustDodge = LPH_NO_VIRTUALIZE(function(th)
	if not th then return false end
	local st = (th.style or ""):lower()
	if Config.SkillAddon then
		if Config.MustDodge and Config.SA_WrestlingGrab and st == "wrestling" and th.kind == "M2" then return true end
		if Config.MustDodge and Config.SA_DirtyGrab and st == "dirty" and (th.kind == "M2" or th.kind == "SKILL") then return true end
		if Config.MustDodge and Config.SA_CQCRingDodge and st == "cqc" and th.kind == "M2" then return true end
	end
	if not Config.MustDodge then return false end
	-- Boxing/iframe/multi M2 are parryable. MustDodgeStyles listing them
	-- (or leftover Grabbing) stripped wantBlock: entered=true want=nil.
	-- SkillAddon CQC/wrestling/dirty already returned above.
	if th.kind == "M2" and m2IsParryOnlyStyle(st) then return false end
	local byStyle = Config.MustDodgeStyles and Config.MustDodgeStyles[st]
	if byStyle and (byStyle[th.kind] or byStyle.all) then return true end
	if th.kind == "M2" and Config.MustDodgeAutoGrab ~= false and st ~= "" then
		GameData.grabCache = GameData.grabCache or {}
		local cached = GameData.grabCache[st]
		if cached == nil then
			cached = false
			if not GameData.resolved then loadGameModules() end
			local getSC = GameData.cfg and GameData.cfg.GetStyleConfig
			if getSC then
				local ok, sc = pcall(getSC, st)
				if ok and type(sc) == "table" then
					cached = sc.M2GrabAllowRagdollCombo
						or (type(sc.M2GrabTargetForwardOffset) == "number")
						or (type(sc.M2GrabLockDuration) == "number")
						or (type(sc.M2SlamParryWindowDisableDuration) == "number")
						or false
				end
			end
			GameData.grabCache[st] = cached
		end
		if cached then return true end
	end
	-- V292: Grabbing without grab fields is GrappleChance / leftover.
	-- MuayThai M2 (GrappleChance 0.55, no M2Grab*) was must-dodged, wantBlock
	-- stripped, dodge CD empty → NO-PRESS HIT. Unblockable/GuardBreak already
	-- excluded; Grabbing follows the same rule.
	return false
end)
State.isMustDodge = isMustDodge

State.ap = {
	m1         = nil,
	tryM1Fn    = nil,
	comboIdx   = nil,
	m1Tried    = false,
	fireOK     = false,
	u25idx     = nil,
	u26idx     = nil,
	u21idx     = nil,
	u32idx     = nil,
	u33idx     = nil,
	u27tbl     = nil,
	u28tbl     = nil,
	crc        = nil,
	getAnims   = nil,
	getSpeed   = nil,
	playSwing  = nil,
	m2         = nil,
	nextM1At   = 0,
	punishTgt  = nil,
	punishUntil= 0,
		punishFresh= false,
		m1Txn      = nil,
		m1TxnSeq   = 0,
		busyAttrs = {
		"Stunned", "Ragdoll", "Downed", "GuardBroken", "CantAnything",
		"M1Cooldown", "ParryAttackLockout", "BlockAttackLockout",
	},
}

function State.ap.getM1()
	if State.ap.m1 then return State.ap.m1 end
	if State.ap.m1Tried then return nil end
	State.ap.m1Tried = true
	local mod
	pcall(function()
		local csc = ReplicatedStorage:FindFirstChild("CombatSystemClient")
		local base = csc and csc:FindFirstChild("Combat")
		base = base and base:FindFirstChild("Base")
		mod = base and base:FindFirstChild("M1")
	end)
	if not mod then
		pcall(function()
			for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
				if d.Name == "M1" and d:IsA("ModuleScript")
				   and d.Parent and d.Parent.Name == "Base" then mod = d; break end
			end
		end)
	end
	if mod then
		local ok, tbl = pcall(require, mod)
		if ok and type(tbl) == "table" and type(tbl.OnM1Activated) == "function" then State.ap.m1 = tbl end
	end
	if not State.ap.m1 and type(filtergc) == "function" then
		pcall(function()
			local t = filtergc("table",
				{ Keys = { "Hold", "OnM1Activated", "ServerResponse", "OnHoldSwing" } }, true)
			if type(t) == "table" and type(t.OnM1Activated) == "function" then State.ap.m1 = t end
		end)
	end
	if State.ap.m1 and type(debug) == "table" and type(debug.getupvalue) == "function" then
		pcall(function()
			local fn = debug.getupvalue(State.ap.m1.OnM1Activated, 1)
			if type(fn) == "function" then State.ap.tryM1Fn = fn end
		end)
			if State.ap.tryM1Fn and type(debug.setupvalue) == "function" then
				pcall(function()
					local fn = State.ap.tryM1Fn
					local function uv(i)
						local ok, v = pcall(debug.getupvalue, fn, i)
						if ok then return v end
						return nil
					end
					local C
					for i = 1, 40 do
						local v = uv(i)
						if type(v) == "table" and type(rawget(v, "Fire")) == "function" then C = i; break end
						if v == nil and i > 25 then break end
					end
					if not C then return end
					local getSpeed = uv(C - 12)
					local u19v     = uv(C - 11)
					local getAnims = uv(C - 10)
					local playSw   = uv(C - 8)
					local u25v     = uv(C - 4)
					local u26v     = uv(C - 3)
					local u27v     = uv(C - 2)
					local u28v     = uv(C - 1)
					local u21v     = uv(C - 16)
					local u32v     = uv(C - 15)
					local u33v     = uv(C - 14)
					if type(getSpeed) == "function"
					   and type(getAnims) == "function"
					   and type(playSw)  == "function"
					   and type(u19v) == "number" and u19v >= 0 and u19v <= 4
					   and type(u25v) == "number" and type(u26v) == "number"
					   and type(u27v) == "table"  and type(u28v) == "table" then
						State.ap.comboIdx  = C - 11
						State.ap.u25idx    = C - 4
						State.ap.u26idx    = C - 3
						State.ap.u27tbl    = u27v
						State.ap.u28tbl    = u28v
						State.ap.crc       = uv(C)
						State.ap.getSpeed  = getSpeed
						State.ap.getAnims  = getAnims
						State.ap.playSwing = playSw
						State.ap.fireOK    = true
						if type(u21v) == "boolean" then State.ap.u21idx = C - 16 end
						if type(u32v) == "number"  then State.ap.u32idx = C - 15 end
						if type(u33v) == "number"  then State.ap.u33idx = C - 14 end
					end
				end)
			end
		end
	if State.ap.m1 then diagPush("AUTOPLAY: M1 module resolved (legit attacks ready)"
		.. (State.ap.tryM1Fn and " +tryM1" or " (OnM1Activated only)")
		.. (State.ap.fireOK and " +CUSTOM-FIRE(fast)" or ""))
	else diagPush("AUTOPLAY: M1 module NOT found — attacks disabled") end
	return State.ap.m1
end

function State.ap.trackOwners()
	local g = getgenv()
	local r = rawget(g, "__V0_COMBAT_TRACK_OWNERS")
	if type(r) ~= "table" then
		r = setmetatable({}, { __mode = "k" })
		rawset(g, "__V0_COMBAT_TRACK_OWNERS", r)
	end
	return r
end

function State.ap.finishM1Txn(reason, now)
	local ap, tx = State.ap, State.ap.m1Txn
	if not tx then return end
	ap.m1Txn = nil
	now = now or os.clock()
	diagPush("AUTOPLAY-DONE t=%.2f tx=%d swing=%d combo=%d reason=%s suppressed=%d age=%.0fms", now, tx.txid or 0, tx.swingId or 0, tx.combo or 0, tostring(reason or "complete"),
			tx.suppressed or 0, math.max(0, now - (tx.sentAt or now)) * 1000)
end

function State.ap.m1TxnActive(now)
	local ap, tx = State.ap, State.ap.m1Txn
	if not tx then return false end
	now = now or os.clock()
	local c = localChar()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if c ~= tx.char or not hum or hum.Health <= 0 then
		ap.finishM1Txn("character/death", now)
		return false
	end
	if now < (tx.untilAt or 0) then
		tx.suppressed = (tx.suppressed or 0) + 1
		return true
	end
	local why = tx.trackStopped and "track-stopped+floor" or "duration"
	ap.finishM1Txn(why, now)
	return false
end

function State.ap.markM1Track(char, anim, tx)
	local h = getHandler()
	if not (h and h.GetAnims and anim and tx) then return nil end
	local track
	pcall(function()
		local bucket = h.GetAnims(char, "M1")
		local entry = bucket and bucket[anim.AnimationId]
		track = entry and entry.Track
	end)
	if not track then return nil end
	tx.track = track
	local owners = State.ap.trackOwners()
	if owners then owners[track] = { owner = "autoplay", txid = tx.txid, swingId = tx.swingId } end
	pcall(function()
		track.Stopped:Connect(function()
			if State.ap.m1Txn == tx then tx.trackStopped = true end
		end)
	end)
	return track
end

function State.ap.fireM1Custom(char, model, wantCombo, ignoreRate, priority, dropGuard)
	local ap = State.ap
	if not (ap.fireOK and ap.tryM1Fn) then return false end
	local ok = false
	pcall(function()
		local now = os.clock()
		if ap.m1TxnActive(now) then return end
		if Config.CounterYieldToM2 ~= false then
			local m2H = Config.CounterM2Horizon or 0.95
			for i = 1, #Threats do
				local o = Threats[i]
				if o and o.kind == "M2" and not o.resolved and not o.staleTrack then
					local dtM2 = (o.contactAbs or 0) - now
					if dtM2 > -0.08 and dtM2 < math.max(m2H, 1.20) then
						return
					end
				end
			end
		end
	if Config.SkillAddon and Config.AliEvasiveCounter then
		local etx = State.dodgeTxn
		if etx and etx.pending and etx.perfectConfirmed and not etx.evCounterFired then
			return
		end
		if Config.AliDodgeAbuse and Config.AutoDodge then
			local cdA = State.aliM2CD
			if cdA and cdA.active and cdA.known then
				local holdUntilContact = math.max(uplink(), 0.02)
					+ (GameData.iframeDur or Config.IFrameDur or 0.30) + 0.10
				for i = 1, #Threats do
					local th = Threats[i]
					if th and th.serverProven and not th.resolved and not th.dodged then
						local dtA = (th.contactAbs or 0) - os.clock()
						if dtA > 0 and dtA <= holdUntilContact then return end
					end
				end
			end
		end
	end
		local combo
		if wantCombo then
			combo = math.clamp(math.floor(wantCombo), 1, 4)
		elseif Config.AP_ComboMode == "Fixed" then
			combo = math.clamp(math.floor(Config.AP_FixedHit or 1), 1, 4)
		else
			combo = ((debug.getupvalue(ap.tryM1Fn, ap.comboIdx) or 0) % 3) + 1
		end
		if not ignoreRate then
			local rate = math.max(1, Config.AP_MaxPerSec or 6)
			local gap = priority and (Config.AP_PunishFastGap or 0.08)
				or math.max(Config.AP_MinSendGap or 0.09, (1 / rate) * 0.97)
			if (now - (ap.m1SendLast or 0)) < gap then return end
			if (now - (ap.m1WinStart or 0)) >= 1 then ap.m1WinStart, ap.m1WinCount = now, 0 end
			if (ap.m1WinCount or 0) >= rate then return end
		end
		if Config.AP_AnimGuard ~= false and (now - (ap.swingAnimAt or 0)) < (ap.swingAnimMin or 0) then
			return
		end
		local anims = ap.getAnims()
		local v53   = anims and anims[combo] or nil
		if not v53 then return end
		local spd = 1
		pcall(function() spd = ap.getSpeed(char, combo) or 1 end)
		local len = 0
		pcall(function()
			local cp = GameData.cfg and GameData.cfg.ClientPredict
			local m1 = cp and cp.M1
			len = tonumber(m1 and m1.AttackDuration) or 0
		end)
		if len <= 0 then len = Config.AP_AnimFallback or 0.45 end
		len = len / math.max(spd, 0.01)
		State.swingAnimUntil = now + len
		if AnimLib.tracks.Blocking or (char:GetAttribute("Blocking") == true) then
			stopBlockAnim()
		end
		local owners = ap.trackOwners()
		if owners then
			owners.__intent = { owner = "autoplay", char = char, animationId = v53.AnimationId, expires = now + 0.15 }
		end
		local played = false
		pcall(function() played = ap.playSwing(char, combo, spd, false) == true end)
		if not played then
			if owners and owners.__intent and owners.__intent.char == char then owners.__intent = nil end
			State.swingAnimUntil = 0
			return
		end
		ap.swingAnimAt  = now
		ap.swingAnimMin = len
		if dropGuard and (State.blocking or char:GetAttribute("Blocking") == true) then
			State.blocking, State.holdUntil = false, 0
			stopBlockAnim()
			sendDeactivate(true)
		end
		local newId = (debug.getupvalue(ap.tryM1Fn, ap.u25idx) or 0) + 1
			ServerRemote:FireServer({ Type = "Combat", Action = "M1", Func = "ServerCheck" }, newId)
			ap.m1SendLast = now
			ap.m1WinCount = (ap.m1WinCount or 0) + 1
			debug.setupvalue(ap.tryM1Fn, ap.comboIdx, combo)
			debug.setupvalue(ap.tryM1Fn, ap.u25idx, newId)
			debug.setupvalue(ap.tryM1Fn, ap.u26idx, newId)
			ap.u27tbl[newId] = combo
			ap.u28tbl[newId] = v53
			ap.m1TxnSeq = (ap.m1TxnSeq or 0) + 1
			local tx = {
				txid = ap.m1TxnSeq, swingId = newId, combo = combo, char = char,
				sentAt = now, untilAt = now + len, suppressed = 0,
			}
			ap.m1Txn = tx
			local tr = ap.markM1Track(char, v53, tx)
			if owners and owners.__intent and owners.__intent.char == char then owners.__intent = nil end
			diagPush("AUTOPLAY-SEND t=%.2f tx=%d swing=%d combo=%d duration=%.0fms track=%s", now, tx.txid, newId, combo, len * 1000, tr and "owned" or "unresolved")
			ok = true
	end)
	return ok
end

function State.ap.canAttack(ignoreBlocking)
	local c = localChar()
	if not c then return false end
	if not c:GetAttribute("Equip") then return false end
	if not ignoreBlocking and c:GetAttribute("Blocking") then return false end
	if c:GetAttribute("CombatAttacking") or c:GetAttribute("M1")
	   or c:GetAttribute("M2") or c:GetAttribute("PendingM2") then return false end
	if c:GetAttribute("Greenzone") or c:GetAttribute("RpCombatLocked") then return false end
	for _, a in ipairs(State.ap.busyAttrs) do
		if c:GetAttribute(a) then return false end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	return true
end

function State.ap.reach()
	if _C.apReachFrame == _C.FrameId then return _C.apReachVal end
	local base = Config.AP_BaseReach or 5.5
	loadGameModules()
	if GameData.cfg and GameData.cfg.GetStyleHitboxForwardOffset then
		local ok, fwd = pcall(GameData.cfg.GetStyleHitboxForwardOffset, styleOf(localChar()), "M1")
		if ok and type(fwd) == "number" then base = fwd + 1.5 end
	end
	local _, _, myH = heightDiag(localChar())
	if type(myH) == "number" and myH > 0 then
		base = base * math.clamp(myH / (Config.AP_RefHeight or 5.5), 0.85, 1.45)
	end
	_C.apReachFrame, _C.apReachVal = _C.FrameId, base
	return base
end

function State.ap.flatDist(model)
	local myHRP = localHRP()
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not (myHRP and hrp) then return math.huge end
	local aim = hrp.Position
	local lead = math.clamp(getPing() * (Config.FacePingLead or 1.0), 0, Config.FaceLeadCap or 0.22)
	if lead > 0 then
		local v = hrp.AssemblyLinearVelocity
		aim = aim + Vector3.new(v.X, 0, v.Z) * lead
	end
	return (Vector3.new(myHRP.Position.X, 0, myHRP.Position.Z)
	        - Vector3.new(aim.X, 0, aim.Z)).Magnitude
end

function State.ap.snapTo(hrp)
	setFaceGoal(hrp, true, Config.AP_FaceHold or 0.35)
	local myHRP = localHRP()
	if myHRP then
		local d = flatDirTo(myHRP.Position, hrp.Position)
		if d then myHRP.CFrame = CFrame.lookAt(myHRP.Position, myHRP.Position + d) end
	end
end

function State.ap.ownAttackWall(base)
	if type(base) ~= "number" or base <= 0 then return nil end
	local char = localChar()
	local windup = GameData.windupExtra or Config.HitboxWindupExtra or 0.012
	local animContact = base + windup
	local mult = attackSpeedMult(char)
	if type(mult) ~= "number" or mult < 0.05 then mult = 1 end
	local speed = mult * gamePingAnimMult(animContact)
	if speed < 0.05 then speed = 0.05 end
	return animContact / speed
end

function State.ap.ownM1Delay()
	local ap = State.ap
	local char = localChar()
	if not char then return nil, nil end
	local combo = 1
	if Config.AP_ComboMode == "Fixed" then
		combo = math.clamp(math.floor(Config.AP_FixedHit or 1), 1, 4)
	elseif ap.fireOK and ap.tryM1Fn and ap.comboIdx then
		combo = ((debug.getupvalue(ap.tryM1Fn, ap.comboIdx) or 0) % 3) + 1
	end
	local style = styleOf(char)
	local info  = V93.ownM1Info
	info.s = style
	local base = hitTimelineBase(info, combo)
	if type(base) ~= "number" or base <= 0 then return nil, nil end
	local eta = ap.ownAttackWall(base)
	if not eta then return nil, nil end
	return eta, combo
end

function State.ap.ownM2Delay()
	local ap = State.ap
	local char = localChar()
	if not char then return nil, nil end
	local style = styleOf(char)
	local info  = V93.ownM2Info
	info.s, info.mom, info.variant, info.hit, info.id = style, false, nil, nil, nil
	local vc = State.ap.m2VarCache
	if not vc then vc = {}; State.ap.m2VarCache = vc end
	local hit = vc[style]
	if hit == nil then
		local bestId, bestBase = nil, nil
		loadGameModules()
		if GameData.cfg and GameData.cfg.GetStyleM2Variants then
			local okv, vs = pcall(GameData.cfg.GetStyleM2Variants, style)
			if okv and type(vs) == "table" then
				for id in pairs(vs) do
					info.variant = id
					local okb, base = pcall(hitTimelineBase, info, nil)
					if okb and type(base) == "number" and (not bestBase or base < bestBase) then
						bestId, bestBase = id, base
					end
				end
			end
		end
		info.variant = bestId
		if not bestBase then
			local okb, base = pcall(hitTimelineBase, info, nil)
			if okb and type(base) == "number" then bestBase = base end
		end
		hit = bestBase and { id = bestId, base = bestBase } or false
		vc[style] = hit
	end
	if hit == false then return nil, nil end
	if type(hit.base) ~= "number" or hit.base <= 0 then return nil, nil end
	info.variant = hit.id
	local eta = ap.ownAttackWall(hit.base)
	if not eta then return nil, nil end
	return eta, hit.id
end

function State.ap.m2GrantsIFrames()
	local char = localChar()
	if not char then return false end
	local style = styleOf(char)
	loadGameModules()
	if GameData.cfg then
		if GameData.cfg.GetStyleBoolean then
			local ok, v = pcall(GameData.cfg.GetStyleBoolean, style, "M2GrantsIFrames", false)
			if ok and type(v) == "boolean" then return v end
		end
		if GameData.cfg.GetStyleConfig then
			local ok, sc = pcall(GameData.cfg.GetStyleConfig, style)
			if ok and type(sc) == "table" and type(sc.M2GrantsIFrames) == "boolean" then
				return sc.M2GrantsIFrames
			end
		end
	end
	return false
end

function State.ap.reachM2()
	if _C.apReachM2Frame == _C.FrameId then return _C.apReachM2Val end
	local base = Config.AP_M2BaseReach or 6.5
	loadGameModules()
	if GameData.cfg then
		if GameData.cfg.GetStyleHitboxForwardOffset then
			local ok, fwd = pcall(GameData.cfg.GetStyleHitboxForwardOffset, styleOf(localChar()), "M2")
			if ok and type(fwd) == "number" then base = fwd + 1.5 end
		end
		if GameData.cfg.GetStyleNumber then
			local oks, step = pcall(GameData.cfg.GetStyleNumber, styleOf(localChar()), "M2StepForwardStuds", 0)
			if oks and type(step) == "number" and step > 0 then base = base + step end
		end
	end
	local _, _, myH = heightDiag(localChar())
	if type(myH) == "number" and myH > 0 then
		base = base * math.clamp(myH / (Config.AP_RefHeight or 5.5), 0.85, 1.45)
	end
	_C.apReachM2Frame, _C.apReachM2Val = _C.FrameId, base
	return base
end

function State.ap.m2Ready()
	local c = localChar()
	if not c then return false end
	if c:GetAttribute("M2Cooldown") == true or c:GetAttribute("M2CD") == true then return false end
	if c:GetAttribute("M2") == true or c:GetAttribute("PendingM2") == true then return false end
	local lastM2 = State.ap.m2SendLast or 0
	local lastCn = State.lastCounter or 0
	if lastCn > lastM2 then lastM2 = lastCn end
	if (os.clock() - lastM2) < (Config.AP_M2Gap or 0.30) then return false end
	return true
end

function State.ap.fireM2(model, why, variant)
	local ap = State.ap
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	ap.snapTo(hrp)
	local c = localChar()
	if State.blocking or (c and c:GetAttribute("Blocking") == true) then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		sendDeactivate(true)
	end
	if variant then steerM2Variant(variant) end
	if not fireNativeM2() then return false end
	local now = os.clock()
	ap.m2SendLast    = now
	State.lastCounter = now
	State.flashUntil = now + 0.25
	State.apM2Count  = (State.apM2Count or 0) + 1
	return true
end

function State.ap.interruptible(th)
	if not th or not th.attackerModel or not th.attackerHRP then return false end
	if th.attackerModel:GetAttribute("IFRAMES")
	   or th.attackerModel:GetAttribute("HyperArmor") then return false end
	if th.kind == "M2" then
		loadGameModules()
		if GameData.cfg and GameData.cfg.GetStyleConfig then
			local ok, sc = pcall(GameData.cfg.GetStyleConfig, th.style or "basic")
			if ok and type(sc) == "table"
			   and (sc.M2GrantsIFrames == true or sc.M2GrantsHyperArmor == true) then return false end
		end
	end
	return true
end

-- AutoPlay/Skill не должны перебивать входящий M2: interrupt и punish
-- вешают CombatAttacking/CantAnything, и парри M2 срывается (V269).
local function incomingHeavyM2(now, horizon)
	horizon = horizon or 1.2
	for i = 1, #Threats do
		local o = Threats[i]
		if o and o.kind == "M2" and not o.dodged and not o.resolved and not o.staleTrack then
			local dt = (o.contactAbs or now) - now
			if dt > -0.08 and dt < horizon then
				return o
			end
		end
	end
	return nil
end

State.ap.tryInterrupt = LPH_NO_VIRTUALIZE(function(now, th, threatCount)
	local ap = State.ap
	-- Без AutoPlay не трогаем парри. ownM1Delay/GetStyleConfig каждый кадр
	-- сдвигали press (Hakari M2).
	if Config.AutoPlay ~= true or Config.AP_Interrupt == false then return false end
	-- Lethwei V278: interrupt fired on every M1 (ours 400 vs enemy 462) and
	-- stole the parry — CombatAttacking then NO-PRESS / EARLY-block. Only
	-- interrupt when Block is actually refused.
	do
		local okB = canBlockNow()
		if okB then return false end
	end
	if (State.lastCounter or 0) > 0 and (now - State.lastCounter) < 0.40 then return false end
	if State.counterFiredFrame == _C.FrameId then return false end
	if not th or th.pressed or th.dodged or th.interruptAttempted
		or th.coveredByInterrupt or th.interruptGaveUp then return false end
	if th.kind ~= "M1" then return false end
	if isMustDodge(th) then return false end
	if incomingHeavyM2(now, 1.2) then
		th.interruptGaveUp = true
		return false
	end
	local myH = localHRP()
	local aH = th.attackerHRP
	if not (myH and aH and aH.Parent) then return false end
	if not verticalOk(aH.Position, myH.Position, 0) then
		if realHitboxHitsMe(th.name, th) ~= true then return false end
	end
	if not ap.interruptible(th) or not ap.canAttack(true) then return false end
	local enemyLeft = (th.contactAbs or now) - now
	if enemyLeft < 0.10 then return false end
	local netLag = getPingRaw() * (Config.AP_InterruptNetK or 0.25)
	local reachM1 = ap.reach()
	local distNow = ap.flatDist(th.attackerModel)

	local m1Hit, m1Combo = nil, nil
	if distNow <= reachM1 + 0.75 then
		local d, combo = ap.ownM1Delay()
		if d and (d + netLag + 0.03) < enemyLeft then
			m1Hit, m1Combo = d + netLag, combo
		end
	end

	local m2Hit, m2Var, m2Iframes = nil, nil, false
	local myStyle = styleKey(styleOf(localChar()) or "")
	local m2IsCounter = myStyle == "boxing" or myStyle == "ali" or myStyle == "wingchun"
		or myStyle == "aikido"
	if not m2IsCounter and Config.AP_InterruptM2 ~= false and ap.m2Ready()
	   and ap.flatDist(th.attackerModel) <= ap.reachM2() then
		local d, variant = ap.ownM2Delay()
		if d then
			m2Iframes = ap.m2GrantsIFrames()
			local ours = d + netLag
			if m2Iframes then
				local iframeReady = math.max(0, d - (Config.AP_M2IFrameLead or 0.10)) + netLag
					+ (Config.AP_M2IFrameMargin or 0.08)
				if iframeReady + 0.04 < enemyLeft and ours < enemyLeft then
					m2Hit, m2Var = ours, variant
				end
			elseif ours + 0.03 < enemyLeft then
				m2Hit, m2Var = ours, variant
			end
		end
	end

	local useM2 = false
	if m2Hit and m1Hit then
		useM2 = Config.AP_InterruptPreferM2 ~= false and m2Hit + 0.04 < m1Hit
	elseif m2Hit then
		useM2 = true
	end
	if not useM2 and not m1Hit then
		th.interruptGaveUp = true
		return false
	end
	if useM2 and m2Hit >= enemyLeft then return false end
	if not useM2 and m1Hit >= enemyLeft then return false end
	local oursEta = useM2 and m2Hit or m1Hit
	if threatCount >= 2 and oursEta then
		for i = 1, #Threats do
			local other = Threats[i]
			if other ~= th and not other.dodged and not other.pressed then
				local otherDt = (other.contactAbs or now) - now
				if otherDt >= 0 and otherDt < oursEta then
					th.interruptGaveUp = true
					return false
				end
			end
		end
	end
	if State.blocking or State.guardUp then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		sendDeactivate(true)
	end

	ap.skipM2YieldUntil = now + 0.08
	local ownHit, tag
	if useM2 then
		if not ap.fireM2(th.attackerModel, "interrupt", m2Var) then
			if not m1Hit then return false end
			useM2 = false
		end
	end
	if useM2 then
		ownHit = m2Hit
		tag = string.format("M2%s%s", m2Var and ("/" .. m2Var) or "", m2Iframes and "+IF" or "")
		if m2Iframes then V93.markOwnM2IFrames(now, "interrupt/M2+IF") end
	else
		if not ap.fireM1(th.attackerModel, "interrupt", true, true) then return false end
		ownHit = m1Hit
		tag = string.format("M1/c%d", m1Combo or 0)
	end
	th.interruptAttempted = true
	-- coveredByInterrupt не ставим: промах trade не должен глушить парри.
	State.interruptFiredFrame = _C.FrameId
	State.interruptLockUntil = now + math.max(ownHit or 0.35, 0.28)
	State.status = useM2 and "INTERRUPT-M2" or "INTERRUPT"
	diagPush("INTERRUPT t=%.2f %s %s(%s) via=%s ours=%.0fms enemy=%.0fms m1=%s m2=%s", now, th.name or "?", th.kind or "?", th.style or "?", tag,
			(ownHit or 0) * 1000, enemyLeft * 1000,
			m1Hit and string.format("%.0fms", m1Hit * 1000) or "no",
			m2Hit and string.format("%.0fms", m2Hit * 1000) or "no")
	return true
end)

function State.ap.fireM1(model, why, priority, dropGuard)
		local ap = State.ap
		local now = os.clock()
		if ap.m1TxnActive(now) then return false end
		if now < ap.nextM1At then return false end
		if not ap.canAttack(dropGuard) then return false end
	local m1 = ap.getM1()
	if not m1 then return false end
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	ap.snapTo(hrp)
	ap.nextM1At = now + (Config.AP_PollGap or 0)
		local swung = false
		local useFast = ap.fireOK and (Config.AP_ForceNativeM1 == false)
		if useFast then
			local char = localChar()
			if char then swung = ap.fireM1Custom(char, model, nil, false, priority, dropGuard) end
			if not swung and ap.tryM1Fn then
				local ok, res = pcall(ap.tryM1Fn); swung = ok and res == true
			end
		elseif ap.tryM1Fn then
			local ok, res = pcall(ap.tryM1Fn)
			swung = ok and res == true
		else
			pcall(function() m1.OnM1Activated() end)
			swung = true
		end
		if swung then
			State.status      = "AUTO-M1"
			State.flashUntil  = now + 0.2
			State.autoM1Count = (State.autoM1Count or 0) + 1
		end
	return swung
end

function State.ap.testSwing()
	local ap = State.ap
	if not ap.getM1() then return 0, false end
	local char = localChar()
	if not char then return 0, false end
	local combo
	if Config.AP_ComboMode == "Fixed" then
		combo = math.clamp(math.floor(Config.AP_FixedHit or 1), 1, 4)
		elseif ap.fireOK and ap.tryM1Fn then
			combo = ((debug.getupvalue(ap.tryM1Fn, ap.comboIdx) or 0) % 3) + 1
		else
		combo = 1
	end
	local ok = false
	if ap.fireOK then
		ok = ap.fireM1Custom(char, nil, combo, true)
	elseif ap.tryM1Fn then
		local r; local s = pcall(function() r = ap.tryM1Fn() end); ok = s and r == true
	end
	return combo, ok
end

function State.ap.onPerfectParry(attackerName, kind, th)
	if Config.AP_PunishOnParry == false then return end
	local model = th and th.attackerModel
	if not (model and model.Parent) then
		local plr = attackerName and Players:FindFirstChild(attackerName)
		model = plr and plr.Character
	end
	if not (model and model.Parent) then
		if Config.DeepDiag then
			diagPush("PUNISH-SKIP t=%.2f no-model %s", os.clock(), tostring(attackerName))
		end
		return
	end
	-- V302: never M1 into a player's stun. Their AP is already in
	-- BUFFER-WAIT; our 335ms windup is a free PERFECT for them, then
	-- we eat ApplyLocalParriedStun and the next swing is LATE (V301
	-- 00:52: PUNISH-FIRE → CantAnything → Stunned → STUN-PARRY LATE).
	if Players:GetPlayerFromCharacter(model) then
		State.ap.punishTgt = nil
		State.ap.punishFresh = false
		diagPush("PUNISH-SKIP t=%.2f hvh-player %s", os.clock(), tostring(attackerName))
		return
	end
	if Config.BoxingCounter and (os.clock() - (State.lastCounter or 0)) < 0.40 then
		if Config.DeepDiag then
			diagPush("PUNISH-SKIP t=%.2f counter-iframes", os.clock())
		end
		return
	end
	local stun = (kind == "M2") and (Config.AP_M2Stun or 1.0) or (Config.AP_M1Stun or 0.5)
	-- V300: until=stun (0.5s) expired while Stunned/ParryAttackLockout.
	-- Stay armed through our stun so we M1 in the gap before their next swing.
	State.ap.getM1()
	State.ap.punishTgt   = model
	State.ap.punishUntil = os.clock() + stun + stun
	State.ap.punishFresh = true
	if Config.DeepDiag then
		diagPush("PUNISH-ARM t=%.2f %s until=+%.0fms", os.clock(), tostring(attackerName), (stun + stun) * 1000)
	end
end

function State.ap.step(now)
	if Config.AP_PunishOnParry == false then return end
	if incomingHeavyM2(now, 1.2) then return end
	local ap = State.ap
	local tgt = ap.punishTgt
	if not tgt then return end
	if Players:GetPlayerFromCharacter(tgt) then
		ap.punishTgt = nil
		ap.punishFresh = false
		diagPush("PUNISH-SKIP t=%.2f hvh-player-step", now)
		return
	end
	local hum = tgt:FindFirstChildOfClass("Humanoid")
	if (not hum) or hum.Health <= 0 then
		ap.punishTgt = nil
		ap.punishFresh = false
		return
	end
	if now > ap.punishUntil then
		if Config.DeepDiag then
			diagPush("PUNISH-EXPIRE t=%.2f", now)
		end
		ap.punishTgt = nil
		ap.punishFresh = false
		return
	end
	if not ap.canAttack(true) then
		if Config.DeepDiag and (now - (ap.punishWaitLog or 0)) > 0.20 then
			ap.punishWaitLog = now
			local c = localChar()
			local why = "no-char"
			if c then
				if not c:GetAttribute("Equip") then why = "no-equip"
				elseif c:GetAttribute("Stunned") then why = "Stunned"
				elseif c:GetAttribute("CantAnything") then why = "CantAnything"
				elseif c:GetAttribute("ParryAttackLockout") then why = "ParryAttackLockout"
				elseif c:GetAttribute("BlockAttackLockout") then why = "BlockAttackLockout"
				elseif c:GetAttribute("M1Cooldown") then why = "M1Cooldown"
				elseif c:GetAttribute("CombatAttacking") then why = "CombatAttacking"
				elseif c:GetAttribute("Ragdoll") then why = "Ragdoll"
				else why = "busy"
				end
			end
			diagPush("PUNISH-WAIT t=%.2f %s", now, why)
		end
		return
	end
	if ap.flatDist(tgt) > ap.reach() then
		local meStyle = styleKey(styleOf(localChar()) or "")
		if not (Config.SkillAddon and Config.SA_WrestlingPunishM2 and meStyle == "wrestling"
			and ap.flatDist(tgt) <= math.max(Config.AP_M2BaseReach or 6.5, 8)) then
			return
		end
	end
	if State.blocking then
		State.blocking, State.holdUntil = false, 0
		stopBlockAnim()
		sendDeactivate(true)
	end
	local meStyle = styleKey(styleOf(localChar()) or "")
	if Config.SkillAddon and Config.SA_WrestlingPunishM2 and meStyle == "wrestling" then
		if ap.fireM2(tgt, "punish-grab") then ap.punishFresh = false end
		return
	end
	-- dropGuard: ignore Blocking leftover from the parry tap
	if ap.fireM1(tgt, "punish", ap.punishFresh, true) then
		ap.punishFresh = false
		if Config.DeepDiag then
			diagPush("PUNISH-FIRE t=%.2f", now)
		end
	end
end

local function evasiveGranted()
	local c = localChar()
	return c and c:GetAttribute("OutnumberedEvasiveGrant") == true or false
end

local function dodgeReady()
	local c = localChar()
	if (os.clock() - State.lastDodge) < Config.DodgeMinSpacing then return false end
	if c then
		if c:GetAttribute("IFRAMECD") == true then return false end
		local remG = c:GetAttribute("EvasiveCooldownRemaining")
		if type(remG) == "number" and remG > 0 then return false end
	end
	local since = os.clock() - State.lastDodge
	if evasiveGranted() then
		local fullCd = GameData.evPredictCooldown or Config.DodgeCooldown
		local grantFloor = GameData.evCooldown or 1.5
		if (State.dodgeRejects or 0) >= 2 and since < fullCd then
			if not State.dodgeGateSaid then
				State.dodgeGateSaid = true
				diagPush("DODGE-GATE  грант активен, но %d отказа подряд → откат на полный CD %.2fс (прошло %.2fс)", State.dodgeRejects, fullCd, since)
			end
			return false
		end
		if since < grantFloor then
			if not State.dodgeGateSaid then
				State.dodgeGateSaid = true
				diagPush("DODGE-GATE  грант активен → серверный Evasive.Cooldown %.2fс, прошло %.2fс", grantFloor, since)
			end
			return false
		end
		State.dodgeGateSaid = nil
		return true
	end
	if Config.UseServerCooldown and c then
		return true
	end
	return since >= (GameData.evPredictCooldown and (GameData.evPredictCooldown + 0.05)
		or Config.DodgeCooldown)
end

local function canDodgeNow(force)
	local c = localChar()
	if not c then return false, "no-char" end
	if not c:GetAttribute("Equip") then return false, "Unequipped" end
	for _, attr in ipairs(Config.DodgeHardStates) do
		if c:GetAttribute(attr) then return false, attr end
	end
	-- Evasive-грант на клиенте не отменяет серверный отказ: в Stunned/CantAnything
	-- Evasive.Server отклоняет запрос, IFRAMES не выставляются, а угроза уже
	-- помечена как «накрытая доджем» и парри не жмётся. Диагностика V185:
	-- 12 доджей из 12 в стане — все DODGE-REJECT, все закончились HIT.
	-- Рабочий путь в стане — combo-escape Activated (BUFFER-PARRY / STUN-PARRY).
	if Config.NoDodgeWhileStunned
	   and (c:GetAttribute("Stunned") or c:GetAttribute("CantAnything")) then
		return false, "Stunned"
	end
	-- Два подряд неподтверждённых гранта означают, что Evasive недоступен по
	-- серверному кулдауну. Дальнейшие попытки только съедают защиту.
	if not force and (State.dodgeRejects or 0) >= 2
	   and os.clock() < (State.dodgeMuteUntil or 0) then
		return false, "reject-mute"
	end
	if c:GetAttribute("CombatAttacking") then return false, "CombatAttacking" end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum and (hum.Health <= 0
	   or hum:GetState() == Enum.HumanoidStateType.Dead
	   or hum:GetState() == Enum.HumanoidStateType.Physics) then
		return false, "humanoid-state"
	end
	return true, nil
end

local releaseBlock = LPH_NO_VIRTUALIZE(function()
	if not State.blocking then return end
	State.blocking  = false
	State.holdUntil = 0
	State.lastBlockRelease = os.clock()
	sendDeactivate(true)
end)
State.releaseBlock = releaseBlock

local fireBlock = LPH_NO_VIRTUALIZE(function(tsServer, allowComboEscape)
	if not Config.Enabled then return nil end
	local me = localChar()
	local stunTap = me and stunEscapeNow(me) or false
	if stunTap and me and not me:GetAttribute("Stunned") then
		stunTap = false
	end
	local ok, reason = canBlockNow()
	if not ok then
		-- V298 waited until Stunned dropped, then pressed at rem=37-67 LATE.
		-- We FireServer Block.Activated ourselves — dump Block() early-return
		-- does not apply. Tap in the perfect window even without ParryBuffered.
		local hard = false
		if me then
			if me:GetAttribute("GuardBroken") or me:GetAttribute("Ragdoll")
				or me:GetAttribute("Downed") or me:GetAttribute("Grappling")
				or me:GetAttribute("ParryWindowDisabled") then
				hard = true
			end
		end
		if not (stunTap and Config.ComboEscape ~= false and not hard) then
			State.blockedReason = reason
			return nil
		end
	end
	State.blockedReason = nil
	-- Combo-escape tap (без Blocking/анимации) — живой Stunned.
	-- CombatRecovery после своего M1/сбива/контры даёт stunEscapeNow=true,
	-- но M2 в этот момент нужен обычный гард.
	if not stunTap then
		State.stunQueued = false
	end
	local ts = tsServer or Workspace:GetServerTimeNow()
	local nowS = os.clock()
	local liveBuf = stunTap and parryBufferedNow(me) or false
	if stunTap and not allowComboEscape then
		if liveBuf then
			return true, true
		end
		if State.stunQueued then
			return true, true
		end
		if nowS - (State.lastStunArm or 0) < 0.033 then
			return true, true
		end
	end
	if stunTap and allowComboEscape then
		if nowS - State.lastAct < Config.MinActGap then
			return nil
		end
	end
	if not sendActivate(ts, stunTap) then return nil end
	if stunTap and not allowComboEscape then
		State.lastStunArm = nowS
		State.stunQueued = true
		State.fireCount = (State.fireCount or 0) + 1
		if Config.DeepDiag then
			diagPush("BUFFER-ARM t=%.2f queued Block.Activated while stunned (replay on stun end)", nowS)
		end
		return ts, true
	end
	if stunTap and allowComboEscape and Config.DeepDiag then
		diagPush("STUN-PARRY t=%.2f tap buffered=%s → combo-escape в окне, без локального Blocking",
			nowS, tostring(liveBuf))
	end
	State.stunQueued = false
	State.blocking   = true
	State.lastPress  = os.clock()
	State.fireCount  = (State.fireCount or 0) + 1
	State.status     = "PARRY"
	State.flashUntil = os.clock() + 0.14
	return ts
end)

local refreshContact = LPH_NO_VIRTUALIZE(function(th)
	local now = os.clock()
	if th.kind == "M2" and not th.variantLocked and th.attackerModel then
		local av = th.attackerModel:GetAttribute("M2VariantId")
		if type(av) == "string" and av ~= "" then
			th.variantLocked = true
			if av ~= th.variant then
				local prev = th.hitTL
				th.variant = av
				local newTL = hitTimeline({ t = "M2", s = th.style, mom = th.mom, id = th.id,
					variant = av, name = th.animName }, th.combo, th.attackMult)
				if type(newTL) == "number" and newTL > 0 then
					th.hitTL = newTL
					th.hitTLReal = newTL
					local dAnim = newTL - (prev or newTL)
					local tpV = th.track and th.track.TimePosition
					if type(tpV) == "number" then
						local remV = (newTL - tpV) / math.max(tpSpeed(th.track), 0.05)
						th.contact0 = (now - th.detectClock) + math.max(0, remV)
					else
						th.contact0 = math.max(0, (th.contact0 or 0)
							+ animToWall(dAnim, th.track, th.attackMult, newTL))
					end
					th.contactAbs = th.detectClock + th.contact0
					th.pressed = nil
					diagPush("VARIANT t=%.2f  %s  M2 → %s  hitTL %.0f→%.0fms (server attr)", now, tostring(th.name), av, (prev or 0)*1000, newTL*1000)
				end
			end
		end
	end
	-- Dragon sprint M2: standing delay 0.655, sprint 0.29. Attribute may
	-- land a frame late — retarget in the first 120ms.
	if th.kind == "M2" and not th.sprintLocked and (now - (th.detectClock or now)) < 0.12
		and th.attackerModel and _C.attackerSprinting(th.attackerModel, th.attackerHRP) then
		local sd = _C.sprintM2Delay(th.style)
		if type(sd) == "number" then
			th.sprintLocked = true
			local prev = th.hitTL
			local newTL = hitTimeline({ t = "M2", s = th.style, mom = th.mom, id = th.id,
				variant = th.variant, name = th.animName, sprint = true }, th.combo, th.attackMult)
			if type(newTL) == "number" and newTL > 0 and math.abs(newTL - (prev or 0)) > 0.05 then
				th.hitTL = newTL
				th.hitTLReal = newTL
				local tpV = th.track and th.track.TimePosition
				if type(tpV) == "number" then
					local remV = (newTL - tpV) / math.max(tpSpeed(th.track), 0.05)
					th.contact0 = (now - th.detectClock) + math.max(0, remV)
				else
					th.contact0 = math.max(0.05, newTL)
				end
				th.contactAbs = th.detectClock + th.contact0
				th.pressed = nil
				diagPush("SPRINT-M2 t=%.2f %s hitTL %.0f→%.0fms", now, tostring(th.name), (prev or 0)*1000, newTL*1000)
			end
		end
	end
	local remaining = th.contact0 - (now - th.detectClock)

	local playing = true
	if th.track then
		playing = th.track.IsPlaying
		local tp = th.track.TimePosition
		if type(tp) ~= "number" then tp = th.initTP end

		local lastTP    = th.lastTP or th.initTP
		local lastClock = th.lastTPClock or th.detectClock
		local dtReal    = now - lastClock
		local minDt = math.max(Config.LiveSpeedMinDt or 0.03, (V93.frameDt or 1/60) * 2)
		if dtReal >= minDt then
			local jump = tp - lastTP
			local decl = th.track.Speed
			if type(decl) ~= "number" or decl <= 0.01 then
				decl = math.max(th.initSpeed or 1, 0.05)
			end
			local expect = decl * dtReal
			if jump > expect + (Config.ThrottleCatchPad or 0.07) then
				local hbJ = th.hitTLReal or th.hitTL
				if type(hbJ) == "number" then
					local remJ = hbJ - tp / math.max(tpSpeed(th.track), 0.05)
					th.catchRemain = math.clamp(remJ, 0, Config.MaxWait or 2)
					if Config.DeepDiag and not th.catchLogged then
						th.catchLogged = true
						diagPush("THROTTLE-CATCH t=%.2f %s %s tp %.3f→%.3f jump=%.0fms remain=%.0fms (реплика догнала)",
							now, tostring(th.name), tostring(th.kind), lastTP or 0, tp, jump * 1000, th.catchRemain * 1000)
					end
					State.allowRearmUntil = now + 0.12
					th.pressed = nil
				end
			end
			local inst = jump / dtReal
			if inst < 0 then inst = 0 end
			inst = math.min(inst, decl * (Config.LiveSpeedMaxFactor or 1.5))
			local a = Config.LiveSpeedSmooth or 0.35
			th.liveSpeed   = th.liveSpeed and (th.liveSpeed * (1 - a) + inst * a) or inst
			th.liveSamples = (th.liveSamples or 0) + 1
			th.lastTP = tp; th.lastTPClock = now
		end
		local liveOk = (th.liveSamples or 0) >= (Config.LiveSpeedMinSamples or 1)

		if playing and tp > (th.maxTP or th.initTP) + 0.0005 then
			th.maxTP = tp; th.trackSeen = true; th.lastAdvanceClock = now
			if not th.firstProgressClock then
				th.firstProgressClock = now
				diagTrace("TRACE-ANIM t=%.3f %s %s s%d firstProgress=%+.0fms tp=%.3f init=%.3f live=%.2f(n=%d) decl=%.2f", now, th.name or "?", th.kind or "?", th.strike or 1,
						(now-th.detectClock)*1000, tp, th.initTP or 0, th.liveSpeed or 0,
						th.liveSamples or 0, th.track.Speed)
			end
		elseif not playing and not th.trackStopClock then
			th.trackStopClock = now
			diagTrace("TRACE-ANIM t=%.3f %s %s s%d stopped=%+.0fms tp=%.3f maxTP=%.3f hitTL=%.3f", now, th.name or "?", th.kind or "?", th.strike or 1,
					(now-th.detectClock)*1000, tp, th.maxTP or th.initTP or 0, th.hitTL or 0)
		end

		if (th.kind == "M1" or th.kind == "M2") and playing and Config.LiveM1Timer ~= false then
			local hbReal = th.hitTLReal or th.hitTL
			if type(hbReal) == "number" and type(tp) == "number"
				and tp / tpSpeed(th.track) < hbReal - 0.001 and liveOk then
				local nominal = math.max(th.initSpeed or 1, 0.05)
				local floor   = nominal * (Config.LiveM1SpeedFloor or 0.45)
				local sp      = math.max(th.liveSpeed or nominal, floor)
				-- Маркер в времени анимации. Остаток = (маркер − tp) / темп.
				-- min(стена, live) на Lethwei давал EARLY: стена 501, meas 627.
				local trustRateM1 = (Config.LiveRateTrust ~= false)
					and (th.liveSamples or 0) >= (Config.LiveRateMinSamples or 3)
					and sp <= nominal * 1.02
					and not attackerAnimThrottled(th)
					and th.catchRemain == nil
					and not th.replicaAge and not th.residPad
				local liveRemain
				if trustRateM1 then
					liveRemain = (hbReal - tp) / math.max(sp, 0.05)
				else
					liveRemain = hbReal - tp / math.max(sp, 0.05)
				end
				local wallRemain = math.max(0, (th.contact0 or 0) - (now - th.detectClock))
				-- V292: trustRateM1 skipped this cap. Frozen tp keeps
				-- liveRemain=(hb-tp)/sp ≈ 27ms forever, contactAbs slides,
				-- releaseByGap never fires (meas=814 vs pred=294).
				local stalled = (now - (th.lastAdvanceClock or th.detectClock)) > 0.08
				if Config.LiveM1WallCap ~= false and liveRemain > wallRemain
					and not th.replicaAge then
					local dLive = liveRemain - wallRemain
					local slack = Config.M1WallCapSlack or 0.040
					if stalled or ((not trustRateM1) and not th.residPad and dLive < slack) then
						liveRemain = wallRemain
					end
					end
					-- V293: crawling replica still ticks tp so stall=false.
					-- wall already passed + liveRemain still in the future
					-- (meas=812-881 vs pred=328) — do not slide contactAbs.
					local pwinW = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
						or Config.PerfectWindow or 0.125
					if wallRemain <= 0 and liveRemain > pwinW then
						liveRemain = 0
					end
					remaining = math.clamp(liveRemain, 0, Config.MaxWait or 2)
			end
		elseif th.kind == "SKILL" and playing then
			local hbReal2 = th.hitTLReal or th.hitTL
			if Config.LiveHeavyTimer and (not th.animDesync)
				and type(hbReal2) == "number" and type(tp) == "number"
				and tp < hbReal2 - 0.001 and liveOk then
				local nominal = math.max(th.initSpeed or 1, 0.05)
				local floor   = nominal * (Config.LiveSpeedFloor or 0.15)
				local sp      = math.max(th.liveSpeed or nominal, floor)
				local liveRemain = (hbReal2 - tp) / math.max(sp, 0.05)
				local held = th.liveSpeed and th.liveSpeed < nominal * 0.6
				local wallRemain = math.max(0, (th.contact0 or 0) - (now - th.detectClock))
				local trustRate = (Config.LiveRateTrust ~= false)
					and (th.liveSamples or 0) >= (Config.LiveRateMinSamples or 3)
					and sp < nominal * 0.995
					and not attackerAnimThrottled(th)
					and th.catchRemain == nil
				if (not trustRate) and Config.LiveM1WallCap ~= false and not held
					and liveRemain > wallRemain then
					if (liveRemain - wallRemain) < (Config.M2WallCapSlack or 0.035) then
						liveRemain = wallRemain
					end
				end
				local liveClamped = math.clamp(liveRemain, 0, Config.MaxWait or 2)
				local stalledM2 = (now - (th.lastAdvanceClock or th.detectClock)) > 0.08
				if held or th.animDesync then
					remaining = math.max(remaining, liveClamped)
				elseif trustRate then
					remaining = liveClamped
				elseif liveClamped > remaining then
					remaining = liveClamped
				elseif not stalledM2 and liveClamped < remaining then
					-- V300 M2 meas=428 pred=511: wall-only refused to pull earlier.
					remaining = liveClamped
				end
				th.heldBy = held and
					(liveRemain - math.max(th.contact0 - (now - th.detectClock), 0)) or 0
			end
		end

		if type(th.catchRemain) == "number" and th.catchRemain < remaining then
			remaining = th.catchRemain
		end

	end

	if th.hbContactAbs then
		local hbRem = th.hbContactAbs - now
		if hbRem < 0 then hbRem = 0 end
		remaining = hbRem
	end

	th.trackPlaying = playing
	remaining = math.max(remaining, 0)
	th.contactAbs = now + remaining
	-- Для удержания блока берём БОЛЕЕ ПОЗДНИЙ контакт: wall-cap нужен
	-- нажатию (иначе LATE), но отпускать гард по стене при живой анимации
	-- ещё до маркера = HIT (V204: meas=708 vs pred=331, pressDt=173ms).
	local holdRem = remaining
	if playing and th.track then
		local skipLiveHold = Config.HitboxCommitPress ~= false and th.kind == "M2"
			and th.animDesync == true
		if not skipLiveHold then
		local tpH = th.track.TimePosition
		local hbH = th.hitTLReal or th.hitTL
		if type(tpH) == "number" and type(hbH) == "number" and tpH < hbH - 0.001 then
			local liveH = (hbH - tpH) / math.max(tpSpeed(th.track), 0.05)
			-- V204: extend hold while anim ADVANCES toward the marker.
			-- V292: frozen tp is not a slow marker — extending hold here
			-- kept guard 500ms past wall (EARLY BLOCK-NOT-PARRY).
			local stallHold = (now - (th.lastAdvanceClock or th.detectClock)) > 0.08
			local wallGone = ((th.contact0 or 0) - (now - (th.detectClock or now))) <= 0
			local crawl = th.liveSpeed and th.initSpeed and th.liveSpeed < th.initSpeed * 0.5
			if liveH > holdRem and not stallHold and not wallGone and not crawl then holdRem = liveH end
		end
		end
	end
	local holdCap = Config.HoldLiveCap or 1.15
	if holdRem > holdCap then holdRem = holdCap end
	th.holdRemain = holdRem
	return remaining
end)

local function insideAutoFOV(attackerHRP)
	local fov = math.clamp(tonumber(Config.FOV) or 360, 1, 360)
	if fov >= 359.5 then return true end
	local cam = Workspace.CurrentCamera
	if not cam or not attackerHRP then return true end
	local point, visible = cam:WorldToViewportPoint(attackerHRP.Position)
	if not point or point.Z <= 0 or not visible then return false end
	local vp = cam.ViewportSize
	local dx, dy = point.X - vp.X * 0.5, point.Y - vp.Y * 0.5
	local focal = math.max(vp.Y * 0.5, 1)
	local angle = math.deg(math.atan(math.sqrt(dx * dx + dy * dy) / focal))
	return angle <= fov * 0.5
end

local serverAttackProof = LPH_NO_VIRTUALIZE(function(model)
	if not model then return false end
	-- Truthy, not `== true`: Luraph's VM sometimes boxes attribute booleans so
	-- a set M1/M2 fails a strict equality and the press waits for CombatAttacking
	-- (~200ms), which is already inside the LATE side of the perfect window.
	if model:GetAttribute("M1") then return true end
	if model:GetAttribute("M2") then return true end
	if model:GetAttribute("CombatAttacking") then return true end
	return false
end)

local function reachLimit(kind, approaching)
	local sz = V93.sizes and V93.sizes[kind]
	local half = 4.5
	if sz then
		local flat = Vector3.new(sz.X, 0, sz.Z).Magnitude
		if flat > 0 then half = flat / 2 end
	end
	local off = (kind == "M2") and 3 or 4
	local pad = 6
	return off + half + pad + (Config.ReachSlack or 1) + localTorsoHalf()
end

local function serverHitboxProof(ownerName)
	if not ownerName then return false end
	local folder = Workspace:FindFirstChild("Hitboxes")
	if not folder then return false end
	for _, part in ipairs(folder:GetChildren()) do
		local o = part:FindFirstChild("Owner")
		if o and o.Value == ownerName then
			local a = part:FindFirstChild("AttackName")
			local an = a and a.Value
			if an == "M1" or an == "M2" then return true end
		end
	end
	return false
end

local onAttack = function(attackerHRP, info, model, id, track, origin, hbPart)
	local myHRP = localHRP()
	if not myHRP then return end
	if not insideAutoFOV(attackerHRP) then return end
	local cs2 = isCounterStance(info, id)
	if cs2 then
		if model then
			WingChunCounter[model] = os.clock() + (cs2.Window or 0.55)
		end
		diagPush("COUNTER-STANCE t=%.2f  %s поднял counter-стойку (%s) → окно %.0fms: НЕ парируем (урона нет), не атакуем (вернётся контра %.1fс стана)",
			os.clock(), tostring(model and model.Name or "?"), tostring(info.s or "?"),
			(cs2.Window or 0.55) * 1000, cs2.VictimHitStun or 2.2)
		return
	end
	local dist = planarDist(attackerHRP.Position, myHRP.Position)
	local kindGuess = (info and info.t) or "M1"
	local closingSpeed = planarClosing(attackerHRP, myHRP, nil)
	local approaching = closingSpeed > (Config.ApproachVelMin or 0.5)
	local reachMax = math.min(reachLimit(kindGuess, approaching), Config.Range)
	if kindGuess == "M2" then
		loadGameModules()
		local ringR
		if GameData.cfg and GameData.cfg.GetStyleCQCRing then
			local ok, ring = pcall(GameData.cfg.GetStyleCQCRing, info.s)
			if ok and type(ring) == "table" and type(ring.Radius) == "number" then
				ringR = ring.Radius
			end
		end
		if not ringR and styleKey(info.s) == "cqc" then ringR = 30 end
		if ringR then reachMax = math.max(reachMax, ringR) end
	end
	if dist > reachMax then
		if not approaching then return end
		local canClose = math.max(closingSpeed, 0) * (Config.ReachCloseWindow or 0.35)
		local closeCap = Config.ReachCloseCap or 8
		if canClose > closeCap then canClose = closeCap end
		if dist > reachMax + canClose then return end
	end
	if info.t == "M2" and not Config.HeavyEnabled then return end

	local plr  = Players:GetPlayerFromCharacter(model)
	local name = plr and plr.Name or model.Name
	local nowMerge = os.clock()
	if origin ~= "hitbox" then
		for i = 1, #Threats do
			local old = Threats[i]
			if old and old.name == name and old.kind == info.t
				and not old.resolved and not old.dodged then
				local ttl = math.max(0.4, (old.hitTL or 0) + 0.25)
				if (nowMerge - old.detectClock) < ttl then
					if track then
						old.track = track
						State.seenAnimTrack = State.seenAnimTrack or setmetatable({}, { __mode = "k" })
						State.seenAnimTrack[track] = true
					end
					return
				end
			end
		end
	end
	local lookback = Config.HitboxLookbackSec or 0.55
	local swingRec = V93.lastSwingAt[name]
	if not swingRec then
		swingRec = {}
		V93.lastSwingAt[name] = swingRec
	end
	if origin == "hitbox" then
		local sidNew = hbPart and hbPart:GetAttribute("VictimSwingId")
		local prevT = swingRec[info.t]
		-- Сначала склеиваем с живым свингом. Kyokushin M2 ~828ms: окно
		-- lookback 0.55с не покрывало появление хитбокса, плодился второй
		-- SWING-HB contact=20ms → срыв гарда и BlockCooldown.
		for i = 1, #Threats do
			local old = Threats[i]
			if old and old.name == name and old.kind == info.t
				and not old.resolved and not old.dodged then
				local ttl = math.max(lookback, (old.hitTL or 0) + 0.45, 1.2)
				local live = (nowMerge - old.detectClock) < ttl
					or ((old.contactAbs or 0) > nowMerge - 0.25)
				if live then
					if hbPart then
						old.serverHitbox = hbPart
						if typeof(sidNew) == "string" and sidNew ~= "" then
							old.serverSwingId = old.serverSwingId or sidNew
							V93.hbClaimBySid[sidNew] = old
						end
					end
					return
				end
			end
		end
		if type(prevT) == "number" and (nowMerge - prevT) < 0.72 then
			return
		end
	end

	local suspectSwing = false
	if origin ~= "hitbox" and Config.AntiDecoy and info.t ~= "M2" then
		local sig = State.antiDecoySig; if not sig then sig = {}; State.antiDecoySig = sig end
		local cnt = State.antiDecoyCount; if not cnt then cnt = {}; State.antiDecoyCount = cnt end
		local nowc = os.clock()
		local prev = sig[name]
		if prev and (nowc - prev) < (Config.AntiDecoyGap or 0.12) then
			cnt[name] = (cnt[name] or 1) + 1
			if cnt[name] > (Config.AntiDecoyMaxBurst or 3) then
				if (nowc - (State.lastAntiDecoyLog or 0)) > 1 then
					State.lastAntiDecoyLog = nowc
					aclog(string.format("[decoy] burst cap %dx %s from %s — dropped", cnt[name], tostring(info.t), name))
				end
				return
			end
			suspectSwing = true
			if (nowc - (State.lastAntiDecoyLog or 0)) > 1 then
				State.lastAntiDecoyLog = nowc
				aclog(string.format("[resolver] rapid %s from %s — kept as SUSPECT (needs swing-id proof)", tostring(info.t), name))
			end
		else
			cnt[name] = 1
		end
		sig[name] = nowc
	end

	local attrProof = serverAttackProof(model)

	local combo = (info.t == "M1") and (info.combo or nextCombo(name)) or 1

	local aMult    = attackSpeedMult(model)
	local heightAttr, bodyHeightScale, modelHeight = heightDiag(model)
	local speed    = 1
	local already  = 0
	if track then
		local sp = track.Speed
		if type(sp) == "number" and sp > 0.05 then speed = sp end
		local tp = track.TimePosition
		if type(tp) == "number" and tp > 0 then already = tp end
	end
	local hitTL
	local remaining0
	if origin == "hitbox" then
		hitTL = hitTimeline(info, combo, aMult)
		hitTL = _C.applyGrabSwingSpeed(info, track, hitTL)
		local overlapping = false
		local charOv = localChar()
		if hbPart and hbPart.Parent and charOv then
			local params = V93.hbParams
			if not params then
				params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.MaxParts = 1
				V93.hbParams = params
			end
			if V93.hbChar ~= charOv then
				params.FilterDescendantsInstances = { charOv }
				V93.hbChar = charOv
			end
			overlapping = #Workspace:GetPartBoundsInBox(hbPart.CFrame, hbPart.Size, params) > 0
		end
		if overlapping then
			remaining0 = Config.HitboxContactLead or 0.02
		else
			remaining0 = hitTL
		end
	else
		markAttackStreak(name, info.t, info.s, info)
		if info.contacts and info.contacts[1] then
			-- Маркеры Hit — это TimePosition. На чужом клиенте Speed читается ~1,
			-- даже если у атакующего height-mult. Деление на aMult в логе V178
			-- дало contact=547ms при фактическом TP удара 0.725.
			hitTL = info.contacts[1]
		else
			hitTL = hitTimeline(info, combo, aMult)
		end
		hitTL = _C.applyGrabSwingSpeed(info, track, hitTL)
	end
	local effSpd, spdSrc = effAnimSpeed(track, aMult, hitTL)
	local hitTLReal  = hitTL
	if origin ~= "hitbox" then
		remaining0 = math.max(0, hitTLReal - already / tpSpeed(track))
	end
	-- Ali c3 вблизи: хитбокс на ~75% таблицы (V189: dist=4 meas=338 vs pred=451 LATE;
	-- dist=5 тот же id — PERFECT в 451). Режем только ближний контакт.
	if origin ~= "hitbox" and info.t == "M1" and combo == 3 and dist <= (Config.CloseM1EarlyStuds or 4.5) then
		local sk = styleKey(info.s)
		if sk == "ali" then
			local cap = Config.CloseAliC3HitTL or 0.36
			if hitTLReal > cap + 0.001 then
				hitTL, hitTLReal = cap, cap
				remaining0 = math.max(0, cap - already / tpSpeed(track))
			end
		end
	end
	if remaining0 > Config.MaxWait then return end

	local nowClock  = os.clock()
	if origin ~= "hitbox" then
		for i = #Threats, 1, -1 do
			local old = Threats[i]
			if old and old.origin == "hitbox" and not old.resolved
				and old.name == name and old.kind == info.t
				and (nowClock - old.detectClock) < lookback then
				old.track = track
				old.id = id
				old.combo = combo
				local oldRemain = (old.contactAbs or nowClock) - nowClock
				if remaining0 > oldRemain + 0.08 then
					old.hitTL = hitTL
					old.hitTLReal = hitTL
					old.contact0 = remaining0
					old.contactAbs = nowClock + remaining0
					old.initTP = already
					if old.pressed and not old.resolved then
						old.pressed = false
						old.didPressClock = nil
						if old.rec then old.rec.pressServer, old.rec.pressDt = nil, nil end
					end
					if Config.DeepDiag then
						diagPush("HB-ORIGIN t=%.2f %s %s анимация догнала хитбокс (sid=%s) contact %.0f→%.0fms",
							nowClock, name, tostring(info.t), tostring(old.serverSwingId or "?"),
							oldRemain * 1000, remaining0 * 1000)
					end
				elseif Config.DeepDiag then
					diagPush("HB-ORIGIN t=%.2f %s %s анимация догнала хитбокс (sid=%s) — контакт не пересчитываем",
						nowClock, name, tostring(info.t), tostring(old.serverSwingId or "?"))
				end
				return
			end
		end
	end
	local nowServer = Workspace:GetServerTimeNow()
	local netOneWay, statsRtt = pingDiagSnapshot()
	local pingRawDetect, pingMedDetect, uplinkDetect = getPingRaw(), getPing(), uplink()
	local trackLength, trackPlaying = 0, false
	if track then
		trackLength = track.Length
		trackPlaying = track.IsPlaying
	end
	local th = {
		name = name, kind = info.t, style = info.s, mom = info.mom, id = id,
		combo = combo, variant = info.variant, animName = info.name,
		sprintLocked = info.sprint == true,
		track = track, hitTL = hitTL, hitTLReal = hitTLReal, initTP = already,
		initSpeed = (track and speed) or effSpd, effSpd = effSpd, spdSrc = spdSrc,
		detectClock = nowClock, detectServer = nowServer, contact0 = remaining0,
		contactAbs = nowClock + remaining0, velLead = 0,
		attackerHRP = attackerHRP, attackerModel = model,
		attackerAnimator = track and track.Parent,
		heightAttr = heightAttr, bodyHeightScale = bodyHeightScale, modelHeight = modelHeight,
		attackMult = aMult,
		pingOneWayDetect = netOneWay, pingStatsDetect = statsRtt,
		pingRawDetect = pingRawDetect, pingMedDetect = pingMedDetect, uplinkDetect = uplinkDetect,
		trackLengthDetect = trackLength, trackPlayingDetect = trackPlaying,
		attackerPosDetect = attackerHRP.Position, victimPosDetect = myHRP.Position,
		attackerVelDetect = attackerHRP.AssemblyLinearVelocity, victimVelDetect = myHRP.AssemblyLinearVelocity,
		pressed = false, dodged = false,
		pressDt = nil,
		faceDot = nil,
		suspect = suspectSwing,
		serverProven = (info.t == "M2") or ((not suspectSwing) and attrProof) or false,
		provenBy = (info.t == "M2" and "m2-anim") or (((not suspectSwing) and attrProof) and "attr") or nil,
		serverProofClock = nil,
		origin = origin,
	}
	th.velLead = velLead(attackerHRP, th)
	if origin == "hitbox" and hbPart then
		local sidHb = hbPart:GetAttribute("VictimSwingId")
		th.serverHitbox = hbPart
		th.serverSwingId = sidHb
		th.serverProven = true
		th.provenBy = "hitbox"
		th.hbFirstClock = nowClock
		th.hbFirstServer = nowServer
		if typeof(sidHb) == "string" and sidHb ~= "" then
			V93.hbClaimBySid[sidHb] = th
		end
	end
	if th.serverProven then th.serverProofClock = nowClock end
	if already < 0.04 and remaining0 > 0.12 then
		local replicaAge = 0
		local throttledDet = false
		local par = track and track.Parent
		if par and par.EvaluationThrottled == true then throttledDet = true end
		local upD = uplinkDetect or 0.08
		if throttledDet then
			replicaAge = math.min(upD, remaining0 * 0.5)
		end
		-- V207 combo-age при throttled=false у Kikila: pred 263, meas 347–375.
		-- Не укорачивать незатроттленный combo.
		if replicaAge > 0.025 then
			remaining0 = math.max(0.06, remaining0 - replicaAge)
			th.contact0 = remaining0
			th.contactAbs = nowClock + remaining0
			th.replicaAge = replicaAge
			if Config.DeepDiag then
				diagPush("REPLICA-AGE t=%.2f %s %s c%d tp=%.3f throttled=%s −%.0fms → contact %.0fms",
					nowClock, name, tostring(info.t), combo, already, tostring(throttledDet),
					replicaAge * 1000, remaining0 * 1000)
			end
		end
	end
	do
		local ksTab = _D.ResidByKS
		local ksKey = tostring(info.t) .. ":" .. tostring(info.s or "?") .. ":1"
		local ks = ksTab and ksTab[ksKey]
		if ks and (ks.n or 0) >= 3 then
			local avg = ks.sum / ks.n
			if avg > 22 then
				local pad = math.min(avg / 1000, 0.040)
				remaining0 = remaining0 + pad
				th.contact0 = remaining0
				th.contactAbs = nowClock + remaining0
				th.residPad = pad
				if Config.DeepDiag and not th.residLogged then
					th.residLogged = true
					diagPush("RESID-PAD t=%.2f %s %s +%.0fms (n=%d avg=%+.0f) → contact %.0fms",
						nowClock, name, tostring(info.t), pad * 1000, ks.n, avg, remaining0 * 1000)
				end
			end
		end
	end
	if track then
		for i = #Threats, 1, -1 do
			local old = Threats[i]
			if old.name == name and old.track == track and not old.resolved and not old.staleTrack then
				old.staleTrack = true
				if Config.DeepDiag then
					diagTrace("TRACE-STALE t=%.3f %s %s superseded: same track restarted (age=%.0fms, was dt=%+.0fms)", nowClock, name, tostring(old.kind),
							(nowClock - old.detectClock) * 1000,
							(old.contactAbs - nowClock) * 1000)
				end
			end
		end
	end
	Threats[#Threats+1] = th
	if track then
		State.seenAnimTrack = State.seenAnimTrack or setmetatable({}, { __mode = "k" })
		State.seenAnimTrack[track] = true
	end
	do
		local recAt = V93.lastSwingAt[name]
		if not recAt then
			recAt = {}
			V93.lastSwingAt[name] = recAt
		end
		recAt[info.t] = nowClock
	end

	do
		local key = model or attackerHRP or name
		if key then
			State.lastSwingBy = State.lastSwingBy or setmetatable({}, { __mode = "k" })
			State.swingGapBy  = State.swingGapBy or setmetatable({}, { __mode = "k" })
			local prev = State.lastSwingBy[key]
			if prev then State.swingGapBy[key] = nowClock - prev end
			State.lastSwingBy[key] = nowClock
		end
	end

	local rec = { clock = nowClock, detectServer = nowServer, type = info.t, style = info.s,
	              id = id, contact = remaining0, pingRaw = pingRawDetect, combo = combo,
	              speed = speed, matched = false, th = th, strike = 1 }
	th.rec = rec
	local q = Pending[name]; if not q then q = {}; Pending[name] = q end
	q[#q+1] = rec
	if info.contacts and info.contacts[2] then
		local group = { cancelled = false, held = false }
		th.group, th.strike = group, 1
		local hit2     = info.contacts[2]
		local hit2Real = hit2
		local rem2 = math.max(0, hit2Real - already / tpSpeed(track))
		local th2 = table.clone(th)
		th2.hitTL, th2.hitTLReal, th2.contact0, th2.contactAbs = hit2, hit2Real, rem2, nowClock + rem2
		group.lastContact = th2.contactAbs
		th2.strike, th2.pressed, th2.dodged = 2, false, false
		group.second = th2
		th2.pressDt, th2.faceDot, th2.rec = nil, nil, nil
		th2.hitboxSeen, th2.hitboxSynced, th2.hitboxPart = nil, nil, nil
		Threats[#Threats+1] = th2
		local rec2 = { clock = nowClock, detectServer = nowServer, type = info.t, style = info.s,
			id = id, contact = rem2, pingRaw = rec.pingRaw, combo = combo,
			speed = speed, matched = false, th = th2, strike = 2 }
		th2.rec = rec2
		q[#q+1] = rec2
		diagPush("MULTI  t=%.2f  %s M2 contacts=[%.0f,%.0f]ms markers=[%.0f,%.0f]ms speed=%.2f", nowClock, name, remaining0*1000, rem2*1000,
				info.contacts[1]*1000, info.contacts[2]*1000, speed)
	end
	while #q > 10 do table.remove(q, 1) end

	State.lastThreat = { name = name, type = info.t, dist = dist, hitIn = remaining0 }
	if State.status ~= "PARRY" then State.status = "THREAT" end
	State.parryCount = State.parryCount + 1

	if Config.DeepDiag then
		diagTrace("TRACE-DETECT t=%.3f srv=%.3f %s %s id=%s tp=%.3f/%.3f spd=%.2f playing=%s | net1w=%sms statsRTT=%sms rawRTT=%.0fms medRTT=%.0fms uplink=%.0fms | av=(%.1f,%.1f) mv=(%.1f,%.1f)", nowClock, nowServer, name, info.t, tostring(id), already, trackLength or 0, speed,
				tostring(trackPlaying), netOneWay and string.format("%.0f", netOneWay*1000) or "?",
				statsRtt and string.format("%.0f", statsRtt*1000) or "?", pingRawDetect*1000,
				pingMedDetect*1000, uplinkDetect*1000,
				th.attackerVelDetect.X, th.attackerVelDetect.Z, th.victimVelDetect.X, th.victimVelDetect.Z)
		local pRaw  = pingRawDetect
		local pMult = hitTL / (hitTL + math.clamp(pRaw * 0.5, 0, 0.35))
		local meSt = "ok"
		do
			local cMe = localChar()
			if not cMe then
				meSt = "nochar"
			elseif cMe:GetAttribute("Stunned") then
				meSt = "stun"
			elseif cMe:GetAttribute("Ragdoll") then
				meSt = "ragdoll"
			elseif cMe:GetAttribute("CantAnything") then
				meSt = "cant"
			elseif cMe:GetAttribute("BlockCooldown") then
				meSt = "cd"
			elseif State.blocking then
				meSt = "block"
			end
		end
		diagPush("SWING  t=%.2f  %s  %s(%s)  combo=%d  dist=%.0f  contact=%.0fms  spd=%.2f  aMult=%.2f  height=%s  bodyScale=%s  modelY=%s  pingMult=%.2f  hitTL=%.0fms  vlead=%.0fms  ping=%.0f  origin=%s tp=%.3f me=%s nT=%d nP=%d", os.clock(), name, info.t, info.s, combo, dist, remaining0*1000, speed, aMult,
				heightAttr and string.format("%.3f", heightAttr) or "?",
				bodyHeightScale and string.format("%.3f", bodyHeightScale) or "?",
				modelHeight and string.format("%.2f", modelHeight) or "?",
					pMult, hitTL*1000, (th.velLead or 0)*1000, pRaw*1000,
					tostring(origin or "anim"), already, meSt, #Threats, q and #q or 0)
			if origin == "hitbox" and hbPart then
				diagPush("SWING-HB t=%.2f %s %s(%s) sid=%s size=(%.1f,%.1f,%.1f) → контакт с серверного хитбокса (анимации нет)",
					os.clock(), name, info.t, info.s, tostring(th.serverSwingId or "?"),
					hbPart.Size.X, hbPart.Size.Y, hbPart.Size.Z)
			end
			diagTrace("ANIMTIME t=%.2f %s %s  animContact=%.0fms  effSpd=%.3f(%s)  wall=%.0fms  pingComp=%.0fms  window=%.0fms",
					os.clock(), name, info.t, hitTL*1000, effSpd, spdSrc, remaining0*1000,
					math.clamp((V93.gnpVal or LocalPlayer:GetNetworkPing() or 0) * 0.5,
						0, GameData.animPingCap or Config.AnimPingCompMax or 0.35)*1000,
					((Config.PerfectWindowLive ~= false and GameData.perfectWindow)
						or Config.PerfectWindow or 0.125)*1000)
		end
end

local function ingestHitboxPart(part)
	if not Config.Enabled or Config.HitboxOriginDetect == false then return end
	if not (part and part.Parent and part:IsA("BasePart")) then return end
	local ownerVal = part:FindFirstChild("Owner")
	local atkVal = part:FindFirstChild("AttackName")
	if not (ownerVal and atkVal and ownerVal:IsA("StringValue") and atkVal:IsA("StringValue")) then
		return
	end
	local kind = atkVal.Value
	if kind ~= "M1" and kind ~= "M2" then return end
	if kind == "M2" and not Config.HeavyEnabled then return end
	local ownerName = ownerVal.Value
	if type(ownerName) ~= "string" or ownerName == "" then return end
	local plr = Players:FindFirstChild(ownerName)
	local model = (plr and plr:IsA("Player") and plr.Character) or nil
	if not model then
		local inst = Workspace:FindFirstChild(ownerName)
		if inst and inst:FindFirstChildOfClass("Humanoid") then model = inst end
	end
	if not model or model == localChar() then return end
	local enemy, hrp = isEnemyModel(model)
	if not (enemy and hrp and hrp.Parent) then return end
	local style = styleOf(model) or "Basic"
	local variant = model:GetAttribute("M2VariantId")
	if type(variant) ~= "string" or variant == "" then variant = nil end
	local info = V93.hbInfoScratch
	if not info then
		info = { t = kind, s = style, mom = false, variant = variant, name = "hitbox" }
		V93.hbInfoScratch = info
	else
		info.t = kind
		info.s = style
		info.mom = false
		info.variant = variant
		info.name = "hitbox"
	end
	onAttack(hrp, info, model, nil, nil, "hitbox", part)
end
State.ingestHitbox = ingestHitboxPart

local function dirIsClear(origin, dir, allowedModel)
	if not Config.DodgeWallCheck then return true end
	local char = localChar()
	if not char then return true end
	local params = V93.dodgeParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		V93.dodgeParams = params
	end
	if V93.dodgeChar ~= char then
		V93.dodgeChar = char
		params.FilterDescendantsInstances = { char }
	end
	local hit = Workspace:Raycast(origin, dir.Unit * Config.DodgeWallDist, params)
	if not hit then return true end
	local part = hit.Instance
	if part and (not part.CanCollide or part:IsDescendantOf(char or part)
		or (allowedModel and part:IsDescendantOf(allowedModel))) then return true end
	return false
end

local function bestDodgeDir(now, preferBack)
	local me = localHRP(); if not me then return nil, false end
	local best, bestC
	for _, th in ipairs(Threats) do
		if th.threatens and th.attackerHRP and th.attackerHRP.Parent then
			if not bestC or th.contactAbs < bestC then best, bestC = th, th.contactAbs end
		end
	end
	if not best then return nil, false end
	local aHRP  = best.attackerHRP
	local aLook = aHRP.CFrame.LookVector
	local flook = Vector3.new(aLook.X, 0, aLook.Z)
	local toMe  = me.Position - aHRP.Position
	toMe = Vector3.new(toMe.X, 0, toMe.Z)
	if toMe.Magnitude < 0.05 then return nil, false end
	local away = toMe.Unit
	local toward = -away
	local orbit = Vector3.new(-toMe.Z, 0, toMe.X).Unit
	if flook.Magnitude >= 0.05 then
		flook = flook.Unit
		local perp = Vector3.new(-flook.Z, 0, flook.X)
		if perp:Dot(orbit) < 0 then orbit = -orbit end
	end

	local aggressive = (Config.DodgeMode == "Aggressive") and not preferBack
	local candidates
	if aggressive then
		local close = math.clamp(tonumber(Config.DodgeAggroClose) or 0.45, 0, 1)
		candidates = {
			(orbit + toward * close).Unit,
			(-orbit + toward * close).Unit,
			orbit,
			-orbit,
			toward,
		}
	elseif preferBack or Config.DodgeMode ~= "Aggressive" then
		candidates = {
			away,
			(away * 0.7 + orbit * 0.5).Unit,
			(away * 0.7 - orbit * 0.5).Unit,
			orbit,
			-orbit,
		}
	end
	local origin = me.Position
	for _, dir in ipairs(candidates) do
		if dir and dir.Magnitude > 0.05 and dirIsClear(origin, dir) then
			return dir.Unit, false
		end
	end
	return nil, true
end

function State.bestAliForwardDodgeDir(th)
	local me = localHRP()
	local aHRP = th and th.attackerHRP
	if not me or not aHRP or not aHRP.Parent then return nil, "no-target" end

	local origin = th.geomOrigin or aHRP.Position
	local look = th.geomLook
	if not look or look.Magnitude < 0.05 then
		local lv = aHRP.CFrame.LookVector
		look = Vector3.new(lv.X, 0, lv.Z)
	end
	if look.Magnitude < 0.05 then return nil, "no-look" end
	look = look.Unit
	local forward = tonumber(th.geomForward) or 0
	local target = origin + look * forward
	local delta = target - me.Position
	local toward = Vector3.new(delta.X, 0, delta.Z)
	local targetDist = toward.Magnitude
	if targetDist < 0.05 then return nil, "already-in-sweet-spot" end
	toward = toward.Unit
	local side = Vector3.new(-toward.Z, 0, toward.X)
	local allowed = aHRP.Parent
	local duration = math.max(tonumber(Config.DashDuration) or 0.2, 0.05)
	local maxTravel = (tonumber(Config.DashSpeed) or 30) * duration
	local travel = math.min(targetDist, maxTravel)
	local speed = travel / duration
	local startDelta = aHRP.Position - me.Position
	local startDist = Vector3.new(startDelta.X, 0, startDelta.Z).Magnitude
	local candidates = {
		{ toward, "hitbox-center", speed },
		{ (toward * 0.8 + side * 0.35).Unit, "hitbox-center-side", speed },
		{ (toward * 0.8 - side * 0.35).Unit, "hitbox-center-side", speed },
	}
	for _, candidate in ipairs(candidates) do
		if dirIsClear(me.Position, candidate[1], allowed) then
			return candidate[1], candidate[2], candidate[3], startDist, targetDist, travel
		end
	end
	return nil, "blocked"
end

local function performDodge(now, reason, preferBack, force, bypassAutoOff, dodgeTarget)
	if Config.AutoDodge == false and not bypassAutoOff then
		if State.lastDodgeRefuse ~= "AutoDodge-off" then
			State.lastDodgeRefuse = "AutoDodge-off"
			diagPush("DODGE-SKIP t=%.2f  %s  (AutoDodge disabled)", now, reason)
		end
		return false
	end
	local tx0 = State.dodgeTxn
	if tx0 and tx0.pending then return false end
	do
		local ch0 = localChar()
		if ch0 and (ch0:GetAttribute("IFRAMES") or ch0:GetAttribute("UltraInstinct")) then
			if State.lastDodgeRefuse ~= "already-iframed" then
				State.lastDodgeRefuse = "already-iframed"
				diagPush("DODGE-SKIP t=%.2f  %s  (already invulnerable: IFRAMES live, src=%s)", now, reason, tostring(State.ownIFrameTag or "game"))
			end
			return false
		end
	end
	local can, why = canDodgeNow(force)
	if not can then
		if State.lastDodgeRefuse ~= why then
			State.lastDodgeRefuse = why
			diagPush("DODGE-SKIP t=%.2f  %s  (cannot dodge: %s)", now, reason, tostring(why))
		end
		return false
	end
	State.lastDodgeRefuse = nil

	local granted = evasiveGranted()
	local isAliAbuse = reason == "ali-dodge-abuse"
	local timingTarget = dodgeTarget
	if not timingTarget then
		for _, candidate in ipairs(Threats) do
			if type(candidate.contactAbs) == "number" and candidate.contactAbs >= now
			   and not candidate.resolved and not candidate.coveredByDodge
			   and (not timingTarget or candidate.contactAbs < timingTarget.contactAbs) then
				timingTarget = candidate
			end
		end
	end
	local forceBackOnly = false
	do
		local ct = timingTarget
		if ct and ct.kind == "M2" and type(ct.style) == "string" and ct.style:lower() == "capoeira" then
			forceBackOnly = true
			preferBack = true
			if not ct.capoBackLogged then
				ct.capoBackLogged = true
				diagPush("DODGE-CAPO t=%.2f  %s Capoeira M2 → back-only (mode ignored)", now, tostring(ct.name))
			end
		end
	end
	local optionalDodge = not isAliAbuse and not (reason == "must-dodge" or reason == "must-dodge(unblockable→back)"
		or (type(reason) == "string" and reason:sub(1, 10) == "must-dodge"))
	if optionalDodge and timingTarget and type(timingTarget.contactAbs) == "number" then
		local contactIn = timingTarget.contactAbs - now
		local net = math.max(uplink(), 0.02)
		local duration = GameData.iframeDur or Config.IFrameDur or 0.30
		local frame = math.max(V93.lookahead or 0, V93.frameDt or (1/60))
		local centerLead = net + duration * 0.5 + (Config.DodgeCenterBias or 0)
		if timingTarget.kind == "M2" then centerLead = centerLead + (Config.HeavyDodgeBias or 0) end
		if contactIn > centerLead + frame then
			if not timingTarget.dodgeCenterWaitLogged then
				timingTarget.dodgeCenterWaitLogged = true
				diagPush("DODGE-WAIT/CENTER t=%.2f %s contactIn=%.0fms target=%.0fms frame=%.0fms", now, tostring(reason), contactIn*1000, centerLead*1000, frame*1000)
			end
			return false
		end
		if contactIn <= net + frame then
			if not timingTarget.dodgeTooLateLogged then
				timingTarget.dodgeTooLateLogged = true
				diagPush("DODGE-SKIP/TOO-LATE t=%.2f %s contactIn=%.0fms minArrival=%.0fms", now, tostring(reason), contactIn*1000, (net+frame)*1000)
			end
			return false
		end
	end

	local dir, dirMode, dodgeSpeed, startDist, targetDist, travel
	if isAliAbuse and not forceBackOnly then
		dir, dirMode, dodgeSpeed, startDist, targetDist, travel = State.bestAliForwardDodgeDir(dodgeTarget)
		if not dir then
			diagPush("ALI-DODGE-SKIP t=%.2f gate=trajectory reason=%s", now, tostring(dirMode))
			return false
		end
		diagPush("ALI-DODGE-TRAJECTORY t=%.2f mode=%s startDist=%.2f targetDist=%.2f travel=%.2f speed=%.1f", now, tostring(dirMode), startDist or -1, targetDist or -1, travel or -1, dodgeSpeed or -1)
	else
		dir = bestDodgeDir(now, preferBack)
		dirMode = dir and "smart" or "input"
	end
	local aggressiveOrbit = (Config.DodgeMode == "Aggressive") and not preferBack
	local wantSteer = isAliAbuse
		or (aggressiveOrbit and Config.DodgeAggroSteer ~= false)
		or (not aggressiveOrbit and Config.DodgeExitSteer ~= false)
	if dir and wantSteer then
		local c = localChar()
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum then hum:Move(dir, false) end
		State.ap.dodgeSteerDir = dir
		State.ap.dodgeSteerUntil = now + math.max((uplink() * 0.5) + 0.06, 0.12)
	end
	sendDodge(dir, dodgeSpeed)
	if granted then State.grantEscapes = (State.grantEscapes or 0) + 1 end
	if type(reason) == "string" and reason:sub(1, 4) == "dual" then
		State.dualDodgeCount = (State.dualDodgeCount or 0) + 1
	end
	State.lastDodgeRefuse = nil
	local tx = State.dodgeTxn
	local ifLat0 = math.max(uplink(), 0.02)
	local ifDur0 = GameData.iframeDur or Config.IFrameDur or 0.30
	local iframeLo = now + ifLat0
	local iframeHi = iframeLo + ifDur0
	tx.pending, tx.confirmed = true, false
	tx.fire, tx.lo, tx.hi = now, iframeLo, iframeHi
	-- V293 log: ack=610ms, contact already gone, parry restored dead.
	-- Floor 0.6 ignored ping. Ack = 2*uplink + 50ms, never a baked 600.
	-- GRANT is local prediction. 1.2s ack left parry dead until after the HIT
	-- (V297 stun-exit: ack=1203ms, IFRAMES never came). Always ping-based.
	local ackWindow = math.max(GameData.confirmTimeout or Config.DodgeConfirm or Config.EvasiveAckTimeout or 0.18, uplink() * 2 + 0.05)
	tx.ackDeadline = now + ackWindow
	tx.untilAt, tx.reason = iframeHi + 0.08, reason
	tx.abuseThreat = isAliAbuse and dodgeTarget or nil
	tx.forced = (preferBack == true) or (force == true)
	tx.dodgeDirMode = dirMode
	tx.perfectConfirmed, tx.perfectAt = false, nil
	if (counterStyle() or "") == "ali" and Config.SkillAddon and Config.AliEvasiveCounter then
		diagPush("ALI-DODGE-ARM t=%.2f reason=%s await=StyleEvasiveCounter proc=one-perfect-dodge specialCd=6s range=22 ignoreNormalM2Cd=true deadline=%.0fms", now, tostring(reason), (tx.untilAt-now)*1000)
	end
	tx.evCounterFired, tx.evCounterExpiredLogged = false, false
	tx.evCounterAwaitIframeLogged, tx.evCounterTargetGateLogged, tx.evCounterStateGate = false, false, nil
	local planned, soonest = 0, nil
	for _, th in ipairs(Threats) do
		local c = th.contactAbs
		if c >= iframeLo - 0.03 and c <= iframeHi + 0.03 then
			planned = planned + 1
			if not soonest or c < soonest then soonest = c end
		end
	end
	State.lastDodgeInfo = {
		fire=now, reason=reason, contactAbs=soonest, iframeLo=iframeLo, iframeHi=iframeHi,
		dir=dirMode or (dir and "smart" or "input"), planned=planned,
		targetTh = timingTarget,
	}
	diagPush("DODGE  t=%.2f  %s%s  planned=%d  dir=%s  fire→contact=%s  iframe=[+%.0f,+%.0f]ms", now, reason, granted and " [GRANT]" or "", planned, State.lastDodgeInfo.dir,
			soonest and string.format("%.0fms", (soonest-now)*1000) or "n/a",
			ifLat0*1000, (ifLat0+ifDur0)*1000)
	return true
end

local updateDodgeTxn = LPH_NO_VIRTUALIZE(function(now)
	local tx = State.dodgeTxn
	if not tx or not tx.pending then return end
	local c = localChar()
	if not tx.confirmed and c and c:GetAttribute("IFRAMES") then
		tx.confirmed = true
		State.dodgeRejects, State.dodgeMuteUntil = 0, 0
		tx.lo, tx.hi = now, now + (GameData.iframeDur or Config.IFrameDur or 0.30)
		tx.untilAt = tx.hi + 0.08
		if State.lastDodgeInfo then
			State.lastDodgeInfo.iframeLo, State.lastDodgeInfo.iframeHi = tx.lo, tx.hi
		end
		local covered = 0
		for _, th in ipairs(Threats) do
			local contact = th.contactAbs
			if not th.dodged and contact >= tx.lo
				and contact <= tx.hi then
				th.dodged, th.coveredByDodge = true, true
				covered = covered + 1
			end
		end
		diagPush("DODGE-CONFIRM t=%.2f  %s  covered=%d  window=[+%.0f,+%.0f]ms", now, tostring(tx.reason or "?"), covered,
				(tx.lo-tx.fire)*1000, (tx.hi-tx.fire)*1000)
	end
	if not tx.confirmed and now >= (tx.ackDeadline or tx.untilAt) then
		State.dodgeRejects = (State.dodgeRejects or 0) + 1
		State.dodgeMuteUntil = now + (Config.DodgeRejectMute or 3.0)
		diagPush("DODGE-REJECT/EARLY-FALLBACK t=%.2f %s ack=%.0fms IFRAMES not confirmed; EDF/parry restored (подряд=%d)", now, tostring(tx.reason or "?"), (now-(tx.fire or now))*1000, State.dodgeRejects)
		tx.pending, tx.confirmed, tx.reason = false, false, nil
		tx.abuseThreat, tx.perfectConfirmed, tx.perfectAt = nil, false, nil
		State.ap.dodgeSteerDir, State.ap.dodgeSteerUntil = nil, 0
		return
	end
	local hardClose = tx.untilAt
	local budget = tx.ackDeadline or 0
	local awaitingProc = Config.AliEvasiveCounter
		and (tx.reason == "ali-dodge-abuse")
		and not tx.perfectConfirmed
	if (not tx.confirmed or awaitingProc) and budget > hardClose then hardClose = budget end
	if tx.perfectConfirmed and not tx.evCounterFired and Config.AliEvasiveCounter then
		local ttl = math.min(6 * (Config.AliProcTTLFrac or 0.25), Config.AliProcTTLMax or 1.5)
		local procEnd = (tx.perfectAt or 0) + ttl
		if procEnd > hardClose then hardClose = procEnd end
	end
	if now >= hardClose then
		if tx.reason == "ali-dodge-abuse" and tx.confirmed and not tx.perfectConfirmed then
			diagPush("ALI-PERFECT-MISS/EXPIRE t=%.2f target=%s gate=no-StyleEvasiveCounter iframe=[%.0f,%.0f]ms", now, tostring(tx.abuseThreat and tx.abuseThreat.name or "?"),
					((tx.lo or tx.fire)-tx.fire)*1000, ((tx.hi or tx.fire)-tx.fire)*1000)
		end
		if not tx.confirmed then
			State.dodgeRejects = (State.dodgeRejects or 0) + 1
			State.dodgeMuteUntil = now + (Config.DodgeRejectMute or 3.0)
			diagPush("DODGE-REJECT t=%.2f  %s  IFRAMES not confirmed; EDF retained (подряд отказов=%d%s)", now, tostring(tx.reason or "?"), State.dodgeRejects,
					State.dodgeRejects >= 2
						and string.format(", гейт откатился на полный CD %.2fс",
							GameData.evPredictCooldown or Config.DodgeCooldown)
						or ", пол остаётся 0.38с")
		else
			State.dodgeRejects = 0
		end
		tx.pending, tx.confirmed, tx.reason = false, false, nil
		tx.abuseThreat, tx.perfectConfirmed, tx.perfectAt = nil, false, nil
		State.ap.dodgeSteerDir, State.ap.dodgeSteerUntil = nil, 0
	end
end)

_C.pubTargetModel, _C.pubThreat = nil, nil

local publishVizTarget = LPH_NO_VIRTUALIZE(function(model, hrp)
	if not model then
		if _C.pubTargetModel ~= nil then _C.pubTargetModel = nil; getgenv().AP_TARGET = nil end
		return
	end
	local th = _C.pubThreat
	if th and th.attackerModel ~= model then th = nil end
	local plr = Players:GetPlayerFromCharacter(model)
	if model ~= _C.pubTargetModel then
		_C.pubTargetModel = model
		getgenv().AP_TARGET = {
			model = model, hrp = hrp,
			name = plr and plr.Name or model.Name,
			style = th and th.style or nil,
			kind = th and th.kind or nil,
			contactIn = th and math.max((th.contactAbs or 0) - os.clock(), 0) or nil,
			threatens = th and th.threatens == true or false,
			t = os.clock(),
		}
		return
	end
	local t = getgenv().AP_TARGET
	if not t then _C.pubTargetModel = nil; return end
	t.hrp = hrp
	t.style = th and th.style or t.style
	t.kind = th and th.kind or nil
	t.contactIn = th and math.max((th.contactAbs or 0) - os.clock(), 0) or nil
	t.threatens = th and th.threatens == true or false
	t.t = os.clock()
end)

local heldGuardCovers = LPH_NO_VIRTUALIZE(function(th, heldPwin, up)
	if th.plannedDodge or isMustDodge(th) then return false end
	if m2BreaksHeldGuard(th) then return false end
	if State.lastPressEarly then return false end
	local since = State.lastPress
	if type(since) ~= "number" or since <= 0 then return false end
	return th.contactAbs <= since + heldPwin + up
end)

local schedulerStep = LPH_NO_VIRTUALIZE(function(now)
	updateDodgeTxn(now)
	State.updateAliM2Cooldown(now)
	State.updateCounterTxn(now)
	if State.interruptFiredFrame ~= _C.FrameId and tryAliEvasiveCounter(now) then return end
	if #Threats == 0 and not State.blocking and not Config.AutoPlay then
		State.interruptCandidate = nil
		State.interruptThreatCount = 0
		State.multiThreat = false
		State.multiThreatN = 0
		State.vizTarget = nil
		V93.nearPress = math.huge
		V93.nearPressStamp = os.clock()
		_C.pubThreat = nil
		return
	end
	local serverNow = Workspace:GetServerTimeNow()
	local up        = uplink()
	local ifDur     = GameData.iframeDur or Config.IFrameDur or 0.30
	local ifLat     = math.max(up, 0.02)
	local wantBlock = nil
	local faceTgt   = nil
	local imminent  = V93.imminentBuf
	table.clear(imminent)
	State.interruptCandidate = nil
	State.interruptThreatCount = 0
	table.clear(V93.interruptSeen)
	V93.nearPress = math.huge
	V93.nearPressStamp = os.clock()

		for i = #Threats, 1, -1 do
			local th = Threats[i]
			local trackGone = th.track and th.track.Parent == nil
			refreshContact(th)
			syncContactWithHitbox(th, now)
			local dt = th.contactAbs - now
			local wallRemain = (th.contact0 or 0) - (now - th.detectClock)
			local noTrackExpired = (not th.track)
				and (now - th.detectClock) > ((th.contact0 or 0) + 0.35)

			if not th.stallDt or math.abs(dt - th.stallDt) > 0.012 then
				th.stallDt, th.stallSince = dt, now
			end
			local animStalled = (now - (th.stallSince or now)) > (Config.ThreatStallSec or 0.45)
			-- Hitbox-origin remaining зажат в 0 после контакта → dt вечно +0ms.
			-- Stall-expire в 450ms снимал угрозу до нажатия. Возраст — отдельно.
			if th.origin == "hitbox" then
				animStalled = false
			end
			-- M2 windup 360–600ms. Stall 450ms + trackGone@500ms снимали
			-- угрозу до willHitMe (V280/V281 source=none на любом M2).
			if th.kind == "M2" then
				animStalled = false
			end
			local hbOriginAged = th.origin == "hitbox"
				and (now - th.detectClock) > ((th.contact0 or 0) + (Config.HoldAfter or 0.12) + 0.20)
			local ageCapped = (now - th.detectClock)
				> ((th.contact0 or 0) + (th.hitTL or 0) + (Config.ThreatMaxAgeSec or 1.5))
			if (animStalled or ageCapped) and not th.stallLogged then
				th.stallLogged = true
				if Config.DeepDiag then
					diagPush("THREAT-EXPIRE t=%.2f  %s  %s  → снят как фантом: %s (dt застыл на %+.0fms, возраст %.0fms)",
						now, tostring(th.name), tostring(th.kind),
						animStalled and "анимация-встала" or "превышен-возраст",
						dt * 1000, (now - th.detectClock) * 1000)
				end
			end

			local atkNeutralized = false
			if th.attackerModel and th.attackerModel.Parent then
				local am = th.attackerModel
				atkNeutralized = am:GetAttribute("Parried")
					or am:GetAttribute("Stunned")
					or am:GetAttribute("Ragdoll")
					or am:GetAttribute("Downed")
					or am:GetAttribute("GuardBroken")
			end
			if atkNeutralized and th.group and (th.strike or 1) >= 2
				and not th.group.cancelled and Config.MultiHitKeep ~= false then
				local m = th.attackerModel
				local terminal = m and m.Parent and (m:GetAttribute("Ragdoll")
					or m:GetAttribute("Downed")
					or m:GetAttribute("GuardBroken"))
				if not terminal then
					atkNeutralized = false
					if Config.DeepDiag and not th.multiKeepLogged then
						th.multiKeepLogged = true
						diagPush("MULTI-KEEP t=%.2f  %s  %s s%d  → 2-й удар связки НЕ снят: у атакующего "
							.. "транзиентный Parried/Stunned, но связка не отменена (contactIn=%+.0fms)",
							now, tostring(th.name), tostring(th.kind), th.strike or 2,
							(th.contactAbs - now) * 1000)
					end
				end
			end
			if atkNeutralized then
					if Config.DeepDiag and not th.neutralLogged then
						th.neutralLogged = true
						diagPush("NEUTRALIZED t=%.2f  %s  %s  → угроза снята: атакующий в Parried/Stunned, "
							.. "свинг заве��шиться не может (додж не нужен)", now, th.name, th.kind)
					end
					State.threatNeutralized = (State.threatNeutralized or 0) + 1
					table.remove(Threats, i)
				elseif th.resolved or th.staleTrack or (th.group and th.group.cancelled) then
				table.remove(Threats, i)
			elseif dt < -0.35 or wallRemain < -0.35 or noTrackExpired or animStalled or ageCapped or hbOriginAged
			or (th.kind ~= "M2" and trackGone and (now - th.detectClock) > 0.5 and dt < Config.PerfectLead) then
			local coveredByGuard = th.coveredByHeldGuard == true
				or (Config.OmniBlock and State.blocking and th.enteredWindow
					and th.contactAbs <= (State.holdUntil or 0) + 0.05)
				if th.coveredByDodge or th.coveredByCounter then
				elseif coveredByGuard then
				State.guardCovered = (State.guardCovered or 0) + 1
			elseif Config.DeepDiag and not th.pressed and not th.dodged and not th.deadLogged then
				th.deadLogged = true
				local reason
				if th.everThreatened == nil or th.everThreatened == false then
					reason = string.format("geometry-rejected source=%s sid=%s", tostring(th.recognitionSource or "none"), tostring(th.serverSwingId or (th.group and th.group.serverSwingId) or "none"))
					if th.offTarget then State.offTargetRej = (State.offTargetRej or 0) + 1 end
				elseif th.enteredWindow then
					reason = string.format("in-window но нажатия не было: threatens=%s geomLatched=%s blocked=%s", tostring(th.threatens), tostring(th.geomLatched or false),
							tostring((th.rec and th.rec.blockedReason) or State.blockedReason or (th.bufferEscapeLogged and "BUFFER-WAIT") or (State.dodgeTxn and State.dodgeTxn.pending and "dodge-pending") or "-"))
				elseif th.contactPassedFast then
					reason = string.format("окно не открылось: контакт приле���ел быстре�� pressAt (minDtToPress=%.0fms)", (th.minDtToPress or 0)*1000)
				else
					reason = string.format("no-window (maxTP=%.0f%% hitTL)", (th.maxTP or 0)/math.max(th.hitTL,0.001)*100)
				end
				reason = reason .. string.format(" | proof=%s%s",
					th.serverProven and ("yes/" .. tostring(th.provenBy or "?")) or "NO",
					th.pressHeldForProof and " HELD-BY-GATE" or "")
				diagPush("MISS!  t=%.2f  %s  %s(%s)  contact0=%.0fms  height=%s bodyScale=%s modelY=%s aMult=%.2f  → %s", now, th.name, th.kind, th.style or "?", (th.contact0 or 0)*1000,
						th.heightAttr and string.format("%.3f", th.heightAttr) or "?",
						th.bodyHeightScale and string.format("%.3f", th.bodyHeightScale) or "?",
						th.modelHeight and string.format("%.2f", th.modelHeight) or "?",
						th.attackMult or 1, reason)
				State.independentMiss = (State.independentMiss or 0) + 1
			end
			table.remove(Threats, i)
		elseif not th.dodged then
			local threatens = willHitMe(th)
			if th.kind == "M2" and not th.m2WhmLogged then
				th.m2WhmLogged = true
				diagPush("M2-WHM t=%.2f %s(%s) s%d hit=%s src=%s dist=%.1f",
					now, tostring(th.name), tostring(th.style), th.strike or 1,
					tostring(threatens), tostring(th.recognitionSource or "none"),
					th.geomDist2d or -1)
			end
			if not threatens and th.kind == "M2" then
				local dM2 = th.geomDist2d
				if type(dM2) ~= "number" then
					local meR, aR = localHRP(), th.attackerHRP
					if meR and aR and aR.Parent then
						local dx, dz = meR.Position.X - aR.Position.X, meR.Position.Z - aR.Position.Z
						dM2 = math.sqrt(dx * dx + dz * dz)
						th.geomDist2d = dM2
					end
				end
				local capM2 = Config.Range or 18
				if styleKey(th.style) == "cqc" then capM2 = math.max(capM2, 30) end
				if type(dM2) == "number" and dM2 <= capM2 then
					threatens = true
					th.offTarget = nil
					th.recognitionSource = th.recognitionSource or "m2-in-range"
				end
			end
			th.velLead = velLead(th.attackerHRP, th)
			if not threatens and th.serverProven and th.everThreatened
			   and (th.contactAbs - now) > 0.08 then
				local latchOk = true
				local latchWhy = nil
				local hbConfirmed = (th.provenBy == "hitbox") or (th.hbOverlapClock ~= nil)
					or (th.group ~= nil and th.serverProven and Config.LatchTrustMultiHit ~= false)
				local src = tostring(th.recognitionSource or "")
				local closeCore = (th.geomDist2d or 99)
					<= ((th.geomHalfD or 2) + (th.geomHalfW or 3) + 2)
				if src:find("OUT-OF-REACH", 1, true) or src:find("y-diff", 1, true) then
					latchOk, latchWhy = false, "LIVE-MISS"
				end
				if latchOk and (th.geomDist2d or 0) > (Config.Range or 18) then
					latchOk, latchWhy = false, "OUT-OF-RANGE"
				end
				if latchOk and not hbConfirmed and Config.LatchStrict ~= false then
						local skipStrict = closeCore or (th.serverProven and (attackerAnimThrottled(th)
							or ((th.contactAbs - now) <= (Config.ProvenReachWindow or 0.18))))
						if not skipStrict then
						local ang, allow = th.geomAngToMe, th.geomFaceAllow
						if ang and allow and ang > allow then
							latchOk, latchWhy = false, "NOT-AIMED-AT-ME"
						end
					local side, halfW = th.geomSide, th.geomHalfW
					if latchOk and side and halfW
						and side > halfW + (Config.LatchSidePad or 4.0) then
						latchOk, latchWhy = false, "OFF-AXIS"
					end
						end
				end
				if latchOk then
					threatens = true
					if not th.geomLatched then th.geomLatchSince = now end
					th.geomLatched = true
					if Config.Debug and not th.geomLatchLogged then
						th.geomLatchLogged = true
						diagPush("GEOM-LATCH t=%.3f %s %s s%d proven-swing un-threatened by live geometry → HELD"
							.. " | contactIn=%+.0fms src=%s", now, tostring(th.name), tostring(th.kind), th.strike or 1,
								(th.contactAbs - now) * 1000, tostring(th.recognitionSource or "?"))
					end
				else
					th.offTarget = true
					if Config.Debug and not th.latchDropLogged then
						th.latchDropLogged = true
						diagPush("LATCH-DROP t=%.3f %s %s s%d → чужой удар (%s): face=%.2f side=%.1f/%.1f contactIn=%+.0fms",
							now, tostring(th.name), tostring(th.kind), th.strike or 1, tostring(latchWhy),
							th.geomFaceToMe or 0, th.geomSide or 0, th.geomHalfW or 0,
							(th.contactAbs - now) * 1000)
					end
				end
			end
			th.threatens = threatens
			if threatens and not th.firstThreatClock then
				th.firstThreatClock = now
				local ga, gm, gl = th.geomOrigin, th.geomVictim, th.geomLook
				if Config.TraceDiag then
				diagTrace("TRACE-GEOM t=%.3f %s %s s%d src=%s first=%+.0fms dt=%+.0fms tHit=%.0fms depth=%.2f range=[%.2f,%.2f] side=%.2f/%.2f A=(%s) M=(%s) look=(%s)", now, th.name or "?", th.kind or "?", th.strike or 1,
						tostring(th.recognitionSource or "?"), (now-th.detectClock)*1000,
						(th.contactAbs-now)*1000, (th.geomTHit or 0)*1000,
						th.geomDepth or 0, (th.geomForward or 0)-(th.geomHalfD or 0),
						(th.geomForward or 0)+(th.geomHalfD or 0), th.geomSide or 0, th.geomHalfW or 0,
						ga and string.format("%.1f,%.1f", ga.X,ga.Z) or "?",
						gm and string.format("%.1f,%.1f", gm.X,gm.Z) or "?",
						gl and string.format("%.2f,%.2f", gl.X,gl.Z) or "?")
				end
			end
			if threatens then th.everThreatened = true end
			if th.kind == "M2" and threatens and th.attackerHRP and th.attackerHRP.Parent then
				setFaceGoal(th.attackerHRP, true, math.max(dt, 0) + (Config.HoldAfter or 0.12))
			end
			if threatens then
				if th.group and th.group.held and State.blocking
					and (th.strike or 1) < 2
					and not m2BreaksHeldGuard(th)
					and not State.lastPressEarly then
					th.pressed, th.coveredByHeldGuard = true, true
					State.holdUntil = math.max(State.holdUntil or 0,
						th.contactAbs + Config.HoldAfter + (Config.HoldLateGrace or 0))
				end
				local ik = th.attackerModel or th.attackerHRP or th.name
				if ik and not V93.interruptSeen[ik] then
					V93.interruptSeen[ik] = true
					State.interruptThreatCount = State.interruptThreatCount + 1
				end
				if (th.kind == "M1" or th.kind == "M2") and not th.coveredByCounter
				   and (not State.interruptCandidate
				   or th.contactAbs < State.interruptCandidate.contactAbs) then
					State.interruptCandidate = th
				end
				local lead = Config.PerfectLead
				local hold = Config.HoldAfter
		if Config.M2WidenWindow and th.kind == "M2" then
			lead = lead + Config.M2WidenFront
			hold = hold + Config.M2WidenHold
		end
					local pwin = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
						or Config.PerfectWindow or 0.125
						local gapBias = 0
						local edgeS = (Config.GapEdgeMs or 6) / 1000
						local pmin0 = Config.PerfectMin or 0.05
						-- lead/velLead are the intended remaining gap ON THE SERVER after
						-- the activate packet arrives. pressAt already subtracts uplink.
						local vlCap = math.max(pwin - edgeS - pmin0 - gapBias, 0)
						if (th.velLead or 0) > vlCap then
							if Config.DeepDiag and not th.vlClampLogged then
								th.vlClampLogged = true
								diagTrace("VLEAD-CLAMP t=%.2f %s %s velLead %.0f→%.0fms (окно=%.0fms невязка=%.0fms)",
									now, tostring(th.name), tostring(th.kind),
									(th.velLead or 0) * 1000, vlCap * 1000, pwin * 1000, gapBias * 1000)
							end
							th.velLead = vlCap
						end
						local leadCap = math.max(pwin - edgeS - gapBias, pmin0)
					if lead > leadCap then
						if Config.DeepDiag and not th.leadClampLogged then
							th.leadClampLogged = true
							diagTrace("LEAD-CLAMP t=%.2f %s %s lead %.0f→%.0fms (window=%.0fms velLead=%.0fms)",
								now, tostring(th.name), tostring(th.kind), lead*1000, leadCap*1000,
								pwin*1000, (th.velLead or 0)*1000)
						end
						lead = leadCap
					end
						if Config.LeadQuantComp ~= false then
							local edge    = (Config.LowFpsEdgeMs or 6) / 1000
						local vl      = th.velLead or 0
						local pmin    = Config.PerfectMin or 0.05
						local q = V93.frameDt or (1/60)
						local qPeak = (V93.frameDtPeak or q) * (Config.LowFpsQuantPeakK or 0.75)
						if qPeak > q then q = qPeak end
							local centerFrac = Config.LeadQuantCenter or 0.90
							local center = pwin * centerFrac
							local target = center + q * 0.5
							local hiCap  = pwin - edge
							local loCap  = math.max(pmin, pwin * (Config.LeadQuantFloorFrac or 0.86))
						if target > hiCap then target = hiCap end
						if target < loCap then target = loCap end
						-- velLead уже вычитается в pressAt как более ранний оверлап.
						-- QUANT двигает только lead, иначе vl снимается дважды (M2 EARLY в V184).
						local newLead = lead
						if math.abs(lead - target) > 0.0005 then
							newLead = target
						end
						if newLead < 0 then newLead = 0 end
						-- V304: this M2-only ratchet kept M2 lead pinned at
						-- PerfectLead=95ms while QUANT wanted ~90 - center 0.72.
						-- M1 quantizes down fine; M2 never could. Allow the M2
						-- quant target, but never below the same pmin floor M1 uses.
						local quantFloor = math.max(pmin, pwin * (Config.LeadQuantFloorFrac or 0.64))
						if th.kind == "M2" and newLead < lead and newLead < quantFloor then
							newLead = math.min(lead, quantFloor)
						end
						if math.abs(newLead - lead) > 0.0005 then
							if Config.DeepDiag and not th.jitLogged then
								th.jitLogged = true
								diagTrace("LEAD-QUANT t=%.2f %s %s lead %.0f→%.0fms (кадр=%.0fms peak=%.0fms q=%.0fms velLead=%.0fms serverGap=[%.0f..%.0f]ms localRemain=[%.0f..%.0f]ms окно=[%.0f..%.0f]ms)",
									now, tostring(th.name), tostring(th.kind), lead*1000, newLead*1000,
									(V93.frameDt or 0)*1000, (V93.frameDtPeak or 0)*1000, q*1000, vl*1000,
									(newLead + vl + gapBias - q)*1000, (newLead + vl + gapBias)*1000,
									(newLead + vl + gapBias + up - q)*1000, (newLead + vl + gapBias + up)*1000,
									pmin*1000, pwin*1000)
							end
							lead = newLead
						end
					end
						-- V208: lead+velLead 100+69 sat at 169 > window 125 → EARLY.
						-- V291: cap the SUM at QUANT center, not pwin-edge (119).
						-- velLead filling the 125 wall undoes LeadQuantCenter 0.72.
						local serverGap = lead + (th.velLead or 0)
						local maxGap = pwin * (Config.LeadQuantCenter or 0.72)
						local wall = pwin - edgeS
						if maxGap > wall then maxGap = wall end
						if maxGap < pmin0 then maxGap = pmin0 end
						if serverGap > maxGap then serverGap = maxGap end
						local gapFloor = math.max(pmin0, pwin * (Config.LeadQuantFloorFrac or 0.64))
						if serverGap < gapFloor then serverGap = gapFloor end
						th.aimGap = serverGap
						local pressAt = th.contactAbs - serverGap - up
					local holdEnd = th.contactAbs + hold
					local qLook = V93.lookahead or 0
					local room = maxGap - serverGap
					if room < 0 then room = 0 end
					if qLook > room then qLook = room end
					local pressAtQ = pressAt - qLook
					do
						local meS = localChar()
						-- V300 floor-aim on unbuffered stun-tap: trueGap 76-91 still
						-- HIT in clash AND more LATE than V299 (90.6% → 86.4%).
						-- Clash is not a 10ms QUANT problem. Keep the live window
						-- center; only clamp earliest when the buffer is up.
						if meS and stunEscapeNow(meS) and parryBufferedNow(meS) then
							local stunMax = pwin + up
							local earliest = th.contactAbs - stunMax
							if pressAtQ < earliest then pressAtQ = earliest end
						end
					end
					th.pressAtQ = pressAtQ
					th.holdEndQ = holdEnd
				local dtToPress = pressAt - now
				if th.minDtToPress == nil or dtToPress < th.minDtToPress then
					th.minDtToPress = dtToPress
				end
				if dtToPress > -(Config.HoldAfter or 0.12) and dtToPress < V93.nearPress then
					V93.nearPress = dtToPress
				end
				if now < pressAt and (th.contactAbs - now) < lead then
					th.contactPassedFast = true
				end
				if not th.serverProven then
						if th.suspect then
							if th.serverSwingId or (th.group and th.group.serverSwingId) then
								th.serverProven, th.serverProofClock = true, now
								th.suspect = false
								th.provenBy = "swingid"
							end
						elseif serverAttackProof(th.attackerModel) then
							th.serverProven, th.serverProofClock = true, now
							th.provenBy = "attr"
							if Config.DeepDiag and not th.proofLogged then
								th.proofLogged = true
								diagTrace("TRACE-PROOF t=%.3f %s %s PROVEN by=attr +%.0fms after detect, %+.0fms to contact", now, tostring(th.name), tostring(th.kind),
										(now - th.detectClock) * 1000,
										(th.contactAbs - now) * 1000)
							end
						elseif associatedHitbox(th) then
								th.serverProven, th.serverProofClock = true, now
								th.provenBy = "hitbox"
							end
				end

					local emergency = false
					if Config.EmergencyPress ~= false and not th.pressed and not th.didPressClock
					   and th.hbOverlapClock
					   and (th.serverProven or th.hbOverlapClock)
					   and now < th.hbOverlapClock + (Config.EmergencyPressGrace or 0.20) then
						local remainEm = (th.contactAbs or now) - now
						if remainEm <= (pwin + 0.04) then
							emergency = true
							th.needComboEscape = true
							if Config.DeepDiag and not th.emergencyLogged then
								th.emergencyLogged = true
								local okE, whyE = canBlockNow()
								if okE then
									diagPush("EMERGENCY t=%.2f %s %s хитбокс уже на нас (оверлап %+.0fms, прогноз contact %+.0fms) → жмём немедленно",
										now, tostring(th.name), tostring(th.kind),
										(now - th.hbOverlapClock) * 1000, remainEm * 1000)
								else
									diagPush("EMERGENCY t=%.2f %s %s хитбокс на нас, нажатие недоступно (%s) contact %+.0fms",
										now, tostring(th.name), tostring(th.kind), tostring(whyE), remainEm * 1000)
								end
							end
						end
					end
					-- Очередь: только если буфера ещё нет. Живой ParryBuffered +
					-- Activated = combo-escape сейчас — это только в окне pressAt.
					if not emergency and not th.pressed and th.serverProven
					   and not th.coveredByCounter
					   and (th.threatens or th.everThreatened
					        or (th.geomDist2d and th.geomDist2d <= 10)) then
						local me = localChar()
						if me and stunEscapeNow(me) and not parryBufferedNow(me) then
							if Config.DeepDiag and not th.bufferEscapeLogged then
								th.bufferEscapeLogged = true
								diagPush("BUFFER-WAIT t=%.2f %s %s contactIn=%+.0fms buffered=false → ждём ParryBuffered, пакет не шлём",
									now, tostring(th.name), tostring(th.kind), (th.contactAbs - now) * 1000)
								if th.rec and not th.rec.blockedReason then th.rec.blockedReason = "BUFFER-WAIT" end
							end
						end
					end
				if ((now >= pressAtQ and now <= holdEnd) or emergency) and not th.coveredByCounter then
					th.enteredWindow = true
					-- HOLD only bait/decoy suspects. After Luraph, GetAttribute("M1") at
					-- detect is often still nil; waiting for CombatAttacking (~+200ms)
					-- makes every M1 press LATE. Source proves on the first frame and
					-- fires at pressAt — non-suspect swings must do the same.
					if Config.ServerProofGate and not th.serverProven and th.suspect
					   and th.kind ~= "M2"
					   and (th.contactAbs - now) > (Config.ProofGraceSec or 0.06) then
						if not th.baitHeldLogged then
							th.baitHeldLogged = true
							th.proofHoldClock = now
							diagTrace("TRACE-PROOF t=%.3f %s %s HOLD unproven%s | dt=%+.0fms", now, tostring(th.name), tostring(th.kind),
									th.suspect and " SUSPECT(no swing-id)" or "",
									(th.contactAbs - now) * 1000)
							aclog(string.format("[resolver] %s %s unproven%s — holding press (bait?)", tostring(th.name), tostring(th.kind),
									th.suspect and " (SUSPECT: no swing-id)" or " by server"))
						end
						th.pressHeldForProof = true
					else
						th.pressHeldForProof = false
						local take = false
						if not wantBlock then
							take = true
						else
							local wbU, thU = not wantBlock.pressed, not th.pressed
							if thU ~= wbU then take = thU
							else
								local dHeavy = heavyRank(th) - heavyRank(wantBlock)
								local gap = math.abs(th.contactAbs - wantBlock.contactAbs)
								local cd  = (Config.BlockCooldown or 0.5)
								if Config.HeavyFirst ~= false and dHeavy ~= 0 and gap < cd then
									local light = dHeavy > 0 and wantBlock or th
									local lightDt = (light.contactAbs or now) - now
									-- V204: M2 +456ms перебивал M1 +20ms → NO-PRESS HIT.
									if lightDt <= 0.30 then
										take = (th == light)
									elseif m2BreaksHeldGuard(dHeavy > 0 and th or wantBlock) and lightDt <= 0.45 then
										take = (th == light)
									else
										take = dHeavy > 0
										if take and Config.DeepDiag and not th.heavyPrioLogged then
											th.heavyPrioLogged = true
											diagPush("HEAVY-FIRST t=%.2f приоритет %s %s(%+.0fms) вместо %s %s(%+.0fms): "
												.. "разрыв %.0fms < кулдауна %.0fms, оплатить можно только одно нажатие",
												now, tostring(th.name), tostring(th.kind), (th.contactAbs - now) * 1000,
												tostring(wantBlock.name), tostring(wantBlock.kind),
												(wantBlock.contactAbs - now) * 1000, gap * 1000, cd * 1000)
										end
									end
								else
									take = th.contactAbs < wantBlock.contactAbs
								end
							end
						end
						if take and isMustDodge(th) then take = false end
						if take then
							if wantBlock and wantBlock ~= th and Config.DeepDiag
								and not th.choiceSwapLogged then
								th.choiceSwapLogged = true
								diagPush("CHOICE-SWAP t=%.2f wantBlock %s %s(%+.0fms) → %s %s(%+.0fms): враги в одном окне, приоритет отдан второму",
									now, tostring(wantBlock.name), tostring(wantBlock.kind),
									(wantBlock.contactAbs - now) * 1000,
									tostring(th.name), tostring(th.kind), (th.contactAbs - now) * 1000)
							end
							wantBlock = th
						end
					end
				end
					if dt <= (Config.FaceLeadWindow + up) and dt >= -Config.HoldAfter
						and aimedAtMe(th) then
						local grace = now - 0.03
						local take = false
						if not faceTgt then
							take = true
						else
							local fUp, thUp = faceTgt.contactAbs >= grace, th.contactAbs >= grace
							if thUp ~= fUp then take = thUp
							else take = th.contactAbs < faceTgt.contactAbs end
						end
						if take then faceTgt = th end
					end
				local reachPhantom = (th.recognitionSource == "geom-sticky/OUT-OF-REACH")
					or (th.geomLatched and not th.trustedHit
						and (now - (th.geomLatchSince or now)) > (Config.LatchClusterGrace or 0.25))
				local hz = Config.DodgeHorizon
			if isMustDodge(th) then hz = math.max(hz, 0.70) end
			if dt <= hz and dt > 0.05 and not th.staleTrack
					and not th.pressed and not reachPhantom and not th.coveredByCounter then
					imminent[#imminent+1] = th
				end
			end
		end
	end

	State.ap.tryInterrupt(now, State.interruptCandidate, State.interruptThreatCount)

	table.sort(imminent, V93.sortByContact)

	if State.interruptFiredFrame ~= _C.FrameId and (State.interruptLockUntil or 0) <= now then
		tryBoxingCounter(now)
	end
	if wantBlock and State.counterFiredFrame == _C.FrameId then
		wantBlock = nil
	end

	local cluster = V93.clusterBuf
	table.clear(cluster)
	local clusterHeavy = false
	for _, th in ipairs(imminent) do
		cluster[#cluster + 1] = th
		if th.kind == "M2" then clusterHeavy = true end
	end
	local clusterN = #cluster
	local clusterFirst = cluster[1]
	local clusterLast = cluster[#cluster]
	local clusterSpread = (clusterFirst and clusterLast) and (clusterLast.contactAbs - clusterFirst.contactAbs) or 0
		local planTTL = Config.PlanLatchSec or 1.2
			for _, th in ipairs(imminent) do
				th.plannedParry, th.planCovered = nil, nil
				if th.plannedDodge and (now - (th.planStamp or 0)) > planTTL then
					th.plannedDodge, th.planStamp = nil, nil
				end
			end

		local clusterStrategy = nil
		local activeTxn = State.dodgeTxn
	if activeTxn and activeTxn.pending then
		clusterStrategy = "DODGE_TXN"
	end
	if not clusterStrategy and Config.MultiThreatGuard and clusterN >= (Config.MultiThreatMinN or 2) then
		local iframeSpan = math.max(0, ifDur - 0.07)
		local blockCd = Config.BlockCooldown or 0.5
		local frame   = math.max(V93.frameDt or 0, 1 / 60)
		local lead    = Config.PerfectLead or 0.0625
		local actGap  = Config.MinActGap or 0.004

		local pwinPlan = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
			or Config.PerfectWindow or 0.125
		local parryCover  = math.max(pwinPlan - (Config.GapEdgeMs or 6) / 1000, 0.04)
		local dodgeCover  = math.max(iframeSpan, 0.05)
		local plannedParries, plannedDodges, planParts = 0, 0, nil
		local blockFreeAt = now
		if State.lastBlockRelease then
			blockFreeAt = math.max(blockFreeAt, State.lastBlockRelease + blockCd)
		end

		for i = 1, clusterN do
			local anchor = cluster[i]
			if anchor and not anchor.planCovered then
				local forceDodge = isMustDodge(anchor)
				local canParry = (not forceDodge)
					and (anchor.contactAbs - lead - up) >= (blockFreeAt - actGap)
				if canParry then
					plannedParries = plannedParries + 1
					anchor.plannedParry, anchor.planCovered = true, true
					local covered = 1
					for j = i + 1, clusterN do
						local o = cluster[j]
						if o and not o.planCovered and not isMustDodge(o)
							and (o.contactAbs - anchor.contactAbs) <= parryCover then
							o.planCovered, o.plannedParry = true, true
							covered = covered + 1
						end
					end
					blockFreeAt = anchor.contactAbs + blockCd
					do
						local nxt = cluster[i + 1]
						if nxt and nxt.group and nxt.group == anchor.group then
							blockFreeAt = anchor.contactAbs + 0.22
						end
					end
						if Config.TraceDiag then
							planParts = (planParts and planParts .. ", " or "")
								.. string.format("парри %s %s(+%.0fms, закрывает %d)",
									tostring(anchor.name), tostring(anchor.kind),
									(anchor.contactAbs - now) * 1000, covered)
						end
				elseif Config.AutoDodge then
					plannedDodges = plannedDodges + 1
					anchor.plannedDodge, anchor.planStamp, anchor.planCovered = true, now, true
					local covered = 1
					for j = i + 1, clusterN do
						local o = cluster[j]
						if o and not o.planCovered
							and (o.contactAbs - anchor.contactAbs) <= dodgeCover then
							o.planCovered = true
							covered = covered + 1
						end
					end
						if Config.TraceDiag then
							planParts = (planParts and planParts .. ", " or "")
								.. string.format("додж %s %s(+%.0fms, закрывает %d)",
									tostring(anchor.name), tostring(anchor.kind),
									(anchor.contactAbs - now) * 1000, covered)
						end
				end
			end
		end

		if plannedParries >= 1 and plannedDodges >= 1 then
			clusterStrategy = "PARRY_THEN_DODGE"
		elseif plannedParries >= 2 then
			clusterStrategy = "SEQUENTIAL"
		elseif plannedParries >= 1 then
			clusterStrategy = "PARRY"
		elseif plannedDodges >= 1 and plannedParries == 0 then
			clusterStrategy = "IFRAME_CLUSTER"
		end
		if clusterStrategy and planParts and Config.TraceDiag then
			local psig = clusterStrategy .. ":" .. plannedParries .. ":" .. plannedDodges .. ":" .. clusterN
			if V93.planLogSig ~= psig then
				V93.planLogSig = psig
				diagPush("PLAN t=%.2f %s (%d угроз): %s", now, clusterStrategy, clusterN, planParts)
			end
		end
		for _, th in ipairs(cluster) do th.planCovered = nil end
	if not clusterStrategy then
		clusterStrategy = clusterSpread <= iframeSpan and "IFRAME_CLUSTER" or "HELD_GUARD"
		end
		for _, th in ipairs(cluster) do
			th.clusterStrategy = clusterStrategy
		end
		local meLock = localChar()
		if clusterStrategy == "IFRAME_CLUSTER" and meLock
		   and (meLock:GetAttribute("Stunned") or meLock:GetAttribute("CantAnything")) then
			clusterStrategy = "PARRY"
			for _, th in ipairs(cluster) do
				th.clusterStrategy = clusterStrategy
			end
		end

		local sigN = clusterN
		if State.lastClusterSigN ~= sigN
			or State.lastClusterSigStrat ~= clusterStrategy then
			State.lastClusterSigN = sigN
			State.lastClusterSigStrat = clusterStrategy
			State.lastClusterLogAt = now
			diagPush("CLUSTER t=%.2f n=%d spread=%.0fms strategy=%s contacts=[+%.0f,+%.0f]ms", now, clusterN, clusterSpread * 1000, clusterStrategy,
					(clusterFirst.contactAbs - now) * 1000, (clusterLast.contactAbs - now) * 1000)
		end

			if clusterStrategy == "IFRAME_CLUSTER" and Config.EmergencyDualDodge
				and not canBlockNow()
			and not State.clusterHasAliBoxingM2(cluster)
			and Config.MultiDodgeCover ~= false and dodgeReady() and canDodgeNow()
			and not counterPreemptsDodge(now) then
			local firstDt = clusterFirst.contactAbs - now
			local iframeLo = ifLat
			local iframeHi = ifLat + ifDur
			local covered = 0
			for _, th in ipairs(cluster) do
				local dtc = th.contactAbs - now
				if dtc >= iframeLo and dtc <= iframeHi then
					local dup = false
					for _, other in ipairs(cluster) do
						if other == th then break end
						local odtc = other.contactAbs - now
						if other.attackerModel == th.attackerModel
						   and odtc >= iframeLo and odtc <= iframeHi
						   and math.abs(odtc - dtc) <= 0.03 then
							dup = true
							break
						end
					end
					if not dup then covered = covered + 1 end
				end
			end
			if firstDt >= iframeLo and covered >= 2 then
				if performDodge(now, string.format("multi-cover(n=%d span=%.0fms)", covered, clusterSpread * 1000)) then
					return
				end
			end
		end
	end

	local dtx = State.dodgeTxn
	if dtx and dtx.pending then
		local inFlightUntil = (dtx.fire or 0) + math.max(uplink(), 0.02)
			+ math.max(V93.frameDt or 0, 1 / 60)
		if now < inFlightUntil then return end
	end

	if clusterStrategy == "DODGE_M1_PARRY_M2" and not canBlockNow()
	   and dodgeReady() and canDodgeNow() and not counterPreemptsDodge(now) then
		local m1th = cluster[1]
		local m1Dt = m1th.contactAbs - now
		local dLo, dHi = _C.dodgeCoverWindow(ifLat, ifDur, false)
		if m1Dt >= dLo and m1Dt <= dHi then
			if performDodge(now, "dodge-m1-parry-m2") then
				return
			end
		end
	end

	for _, th in ipairs(imminent) do
		if th.plannedDodge and not th.coveredByDodge and not th.pressed then
			local pdDt = th.contactAbs - now
			local pdLo, pdHi = _C.dodgeCoverWindow(ifLat, ifDur, isMustDodge(th))
			if pdDt >= pdLo and pdDt <= pdHi
				and dodgeReady() and canDodgeNow() and not counterPreemptsDodge(now) then
				if performDodge(now, "parry-then-dodge", false, false, false, th) then
					diagPush("PLAN-DODGE t=%.2f %s %s contactIn=%.0fms → уходим с линии (первую парировали)",
						now, tostring(th.name), tostring(th.kind), pdDt * 1000)
					return
				end
			end
		end
	end

	if Config.CooldownDodge ~= false and Config.AutoDodge then
		local okBlock, whyBlock = canBlockNow()
		if not okBlock and (whyBlock == "BlockCooldown" or whyBlock == "Unequip")
			and dodgeReady() and canDodgeNow() and not counterPreemptsDodge(now) then
			-- BlockCooldown здесь предсказанный (lastPress + 0.5с), а не серверный
			-- отказ: диагностика V186 показывает PERFECT-нажатия сразу после
			-- «refused: BlockCooldown». Уходим доджем только если кулдаун
			-- физически не успеет истечь до момента нажатия по этой угрозе.
			local cdReadyAt = now + (Config.BlockCooldown or 0.5)
				+ (Config.BlockCooldownSafety or 0.03)
			for _, th in ipairs(imminent) do
				local pressBy = th.contactAbs - (Config.PerfectLead or 0.0625) - ifLat
				if not th.coveredByDodge and not th.pressed
					and (whyBlock ~= "BlockCooldown" or cdReadyAt > pressBy) then
					local cdDt = th.contactAbs - now
					local cdLo, cdHi = _C.dodgeCoverWindow(ifLat, ifDur, isMustDodge(th))
					if cdDt >= cdLo and cdDt <= cdHi then
						if performDodge(now, "block-on-cooldown", false, false, false, th) then
							diagPush("CD-DODGE t=%.2f %s %s contactIn=%.0fms → блок недоступен (%s), уходим доджем",
								now, tostring(th.name), tostring(th.kind), cdDt * 1000, tostring(whyBlock))
							return
						end
					end
				end
			end
		end
	end

		local mustDodgeThreat = nil
		for _, candidate in ipairs(imminent) do
			if isMustDodge(candidate) then mustDodgeThreat = candidate; break end
		end
	if mustDodgeThreat and dodgeReady() and canDodgeNow() then
		local mustDt = mustDodgeThreat.contactAbs - now
		local mLo, mHi = _C.dodgeCoverWindow(ifLat, ifDur, true)
		if mustDt >= mLo and mustDt <= mHi then
			if performDodge(now, "must-dodge(unblockable→back)", true, false, true, mustDodgeThreat) then
				return
			end
		end
	end

	if Config.SkillAddon and Config.SA_BlatantDodge and dodgeReady() and #imminent >= 1 then
		local a  = imminent[1]
		local dt = a.contactAbs - now
		local normalOk = canDodgeNow(false)
		local forceOk  = canDodgeNow(true)
		local locked   = (State.selfBusyUntil or 0) > now or (not canBlockNow())
		local coverLo  = ifLat - 0.03
		local coverHi  = ifLat + ifDur - 0.04
		if (not normalOk) and forceOk and locked and not State.isAliBoxingM2(a)
		   and dt >= (coverLo - 0.06) and dt <= math.max(coverHi, Config.SA_BlatantWindow or 0.32)
		   and not counterPreemptsDodge(now) then
			if performDodge(now, "blatant-override(locked)", true, true) then return end
		end
	end

	if dodgeReady() and canDodgeNow() and #imminent >= 1 then
		local a = imminent[1]
		local soonestDt = a.contactAbs - now

		local coverLo, coverHi = _C.dodgeCoverWindow(ifLat, ifDur, isMustDodge(a))
		local _, coverMax = _C.dodgeCoverWindow(ifLat, ifDur, true)

		local multiNow   = #imminent >= (Config.MultiThreatMinN or 2)
		local lateGrace  = (multiNow and Config.MultiDodgeLate ~= false)
			and (Config.MultiDodgeLateGrace or 0.06) or 0
		local coverHiEff = multiNow and coverMax or coverHi
		if coverHiEff < coverLo then coverHiEff = coverLo end
		local frameQ     = math.max(V93.frameDt or 0, 1 / 60) * 0.5
		local coverLoEff = math.max(coverLo - lateGrace, frameQ)
		local coverable = soonestDt >= coverLoEff and soonestDt <= coverHiEff

		if multiNow and not coverable then
			local pick, pickN = nil, 0
			for _, t in ipairs(imminent) do
				if (t.contactAbs - now) >= coverLoEff and (t.contactAbs - now) <= coverHiEff then
					pickN = pickN + 1
					if not pick then pick = t end
				end
			end
			if pick then
				a, soonestDt, coverable = pick, pick.contactAbs - now, true
				if Config.DeepDiag and (not State.dodgeRetargetLogAt
					or now - State.dodgeRetargetLogAt > 0.25) then
					State.dodgeRetargetLogAt = now
					diagPush("DODGE-RETARGET t=%.2f ближний %s(%+.0fms) уже не покрывается → цель %s %s(%+.0fms), накроет %d уд.",
						now, tostring(imminent[1].name), (imminent[1].contactAbs - now) * 1000,
						tostring(pick.name), tostring(pick.kind), soonestDt * 1000, pickN)
				end
			end
		end

		local abuse, m2Remaining, abuseWhy = State.aliDodgeAbuseEligible(a, now, imminent, ifLat, ifDur)
		if abuse and not counterPreemptsDodge(now) then
			if performDodge(now, "ali-dodge-abuse", false, false, false, a) then
				diagPush("ALI-DODGE-ABUSE t=%.2f target=%s/%s s%d contactIn=%.0fms m2Remaining=%.2fs dir=%s", now, tostring(a.name), tostring(a.kind), a.strike or 1,
						(a.contactAbs-now)*1000, m2Remaining or -1,
						tostring(State.dodgeTxn.dodgeDirMode or "?"))
				return
			end
		elseif abuseWhy == "boxing-m2-parry" and not a.aliBoxingParryLogged then
			a.aliBoxingParryLogged = true
			diagPush("ALI-BOXING-M2=PARRY t=%.2f target=%s strike=%d contactIn=%.0fms gate=dodge-abuse", now, tostring(a.name), a.strike or 1, (a.contactAbs-now)*1000)
		end

		local aAlreadyDefended = a.pressed or a.coveredByDodge or a.coveredByHeldGuard
			or a.coveredByCounter
		if m2BreaksHeldGuard(a) then
			aAlreadyDefended = a.pressed or a.coveredByDodge or a.coveredByCounter
		end
		if Config.OutnumberEscape and evasiveGranted() and coverable and not aAlreadyDefended
		   and not State.isAliBoxingM2(a) and not counterPreemptsDodge(now) then
			local coverableCount = 0
			for _, t in ipairs(imminent) do
				if (t.contactAbs - now) >= coverLoEff and (t.contactAbs - now) <= coverHiEff then coverableCount = coverableCount + 1 end
			end
			-- Парри строго приоритетнее доджа: оно даёт PERFECT и стан атакующему,
			-- тогда как додж тратит Evasive и снимает угрозу с обработки парри.
			-- Уходим доджем только когда блок физически отказан.
			local preferBlock = Config.OutnumberEscapePreferBlock ~= false
				and canBlockNow()
				and (Config.DodgeOnlyWhenNoParry ~= false or coverableCount <= 1)
			if not preferBlock then
				if performDodge(now, "outnumbered-escape") then return end
			end
		elseif aAlreadyDefended and Config.DeepDiag and not a.escapeSkipLogged then
			a.escapeSkipLogged = true
			diagPush("ESCAPE-SKIP t=%.2f %s %s уже накрыт (pressed=%s dodge=%s heldGuard=%s blocking=%s) → додж не нужен",
				now, tostring(a.name), tostring(a.kind), tostring(a.pressed), tostring(a.coveredByDodge),
				tostring(a.coveredByHeldGuard), tostring(State.blocking))
		end
				if Config.ComboEscapeDodge and Config.DodgeOnParryCooldown ~= false
				   and not canBlockNow() and coverable and not aAlreadyDefended
				   and not State.isAliBoxingM2(a)
				   and not counterPreemptsDodge(now) then
					if performDodge(now, "combo-escape") then return end
				end
			local blatantOn = Config.SkillAddon and Config.SA_BlatantDodge
			local busyRef = (Config.ExposedEscapeAttackOnly ~= false)
				and (State.attackBusyUntil or 0) or (State.selfBusyUntil or 0)
			if blatantOn and Config.ExposedEscapeDodge and busyRef > now
			   and soonestDt <= Config.ExposedDodgeWindow and coverable and not aAlreadyDefended
			   and not State.isAliBoxingM2(a)
			   and not counterPreemptsDodge(now) then
				if performDodge(now, "exposed-escape(blatant)", false, true) then return end
			end

		local fireLead
		if Config.DodgeCenter then
			fireLead = ifDur * 0.5 + (Config.DodgeCenterBias or 0)
			if a.kind == "M2" then fireLead = fireLead + (Config.HeavyDodgeBias or 0) end
		else
			fireLead = Config.DodgeLead
		end
			if soonestDt <= (fireLead + up + (V93.lookahead or 0)) then
				local overloaded, why = false, nil
				local blockUp = canBlockNow()
				if not blockUp and Config.DodgeOnParryCooldown ~= false then
					if clusterStrategy ~= "HELD_GUARD" then
						if clusterN >= 2 and clusterHeavy and Config.DodgeHeavy then
							overloaded, why = true, "heavy+multi"
						elseif clusterN >= 3 then
							overloaded, why = true, string.format("%dx-burst", clusterN)
						end
					end
					if a.kind == "M2" and clusterN == 1 and Config.DodgeHeavy and not overloaded then
						overloaded, why = true, "heavy-dodge(no-block)"
					end
				end
	if not overloaded and Config.GuardbreakProtect then
		local st = blockStamina()
		if st and st <= Config.StaminaFloor then
			overloaded, why = true, string.format("guardbreak-save(st=%.0f)", st)
		end
	end
				if not overloaded and not blockUp and (State.blockChipStreak or 0) >= 1
					and a.kind == "M1" and Config.DodgeOnParryCooldown ~= false then
					overloaded, why = true, "chip-streak"
				end
				if not overloaded and m2BreaksHeldGuard(a) then
					local okB = canBlockNow()
					if not okB then
						overloaded, why = true, "guardbreak-m2"
					end
				end
				if overloaded and counterPreemptsDodge(now) then overloaded = false end
			if overloaded and not aAlreadyDefended and not State.isAliBoxingM2(a) then
				if performDodge(now, why) then return end
			end
			end
	end

	local midPos = computeMultiFaceGoal()
	if midPos then
		local nearest = math.huge
		for _, th in ipairs(imminent) do
			local dt = (th.contactAbs or now) - now
			if dt < nearest then nearest = dt end
		end
		local hard = nearest <= (Config.BlockFaceHardDt or 0.30) + up
		setFaceGoalPos(midPos, hard, math.max(nearest, 0) + (Config.HoldAfter or 0.12) + 0.08)
		faceTgt = nil
	end

	local turnTo = faceTgt or (aimedAtMe(wantBlock) and wantBlock or nil)
	if turnTo and turnTo.attackerHRP then
		local dtc = turnTo.contactAbs - now
		local hardWin = (Config.BlockFaceHardDt or 0.30) + up
		local hard = (dtc <= hardWin) or (Config.MultiFaceHard and clusterN >= (Config.MultiThreatMinN or 2))
		setFaceGoal(turnTo.attackerHRP, hard, math.max(dtc, 0) + (Config.HoldAfter or 0.12) + 0.06)
		State.vizTarget = { hrp = turnTo.attackerHRP, model = turnTo.attackerModel }
		_C.pubThreat = turnTo
	else
		State.vizTarget = nil
		_C.pubThreat = nil
	end

	local threatN, farContact = 0, nil
	do
		local seen = V93.threatSeen
		for k in pairs(seen) do seen[k] = nil end
		for _, th in ipairs(imminent) do
				local key = th.attackerModel or th.attackerHRP or th.name
				if key and not seen[key] then seen[key] = true; threatN = threatN + 1 end
				if not th.plannedDodge
					and (not farContact or th.contactAbs > farContact) then
					farContact = th.contactAbs
				end
		end
	end
	local multiThreat = Config.MultiThreatGuard
		and (threatN >= (Config.MultiThreatMinN or 2) or clusterN >= (Config.MultiThreatMinN or 2))
	State.multiThreat  = multiThreat
	State.multiThreatN = math.max(threatN, clusterN)
	if multiThreat then
		State.multiThreatMax   = math.max(State.multiThreatMax or 0, State.multiThreatN)
		State.multiThreatFrames = (State.multiThreatFrames or 0) + 1
		if farContact then
			local latch = farContact + Config.HoldAfter + (Config.HoldLateGrace or 0) + 0.05
			State.multiHoldUntil = math.max(State.multiHoldUntil or 0, latch)
		end
	end

	if wantBlock and State.interruptFiredFrame == _C.FrameId
		and wantBlock.interruptAttempted then
		wantBlock = nil
	end
	if wantBlock and counterBusyNow() and wantBlock.kind ~= "M2" then
		wantBlock = nil
	end
	if wantBlock and isMustDodge(wantBlock) then
		-- Keep parry if dodge will not cover this frame (naked M2 otherwise).
		local dtMd = (wantBlock.contactAbs or now) - now
		local mLo, mHi = _C.dodgeCoverWindow(ifLat, ifDur, true)
		if dodgeReady() and canDodgeNow() and dtMd >= mLo and dtMd <= mHi then
			wantBlock = nil
		end
	end
	-- V284 Kyokushin M2: rem<0.35 stole wantBlock 350ms before contact,
	-- fireBlock ignored pressAtQ (comboOk is stun-only) → trueGap +312 GB.
	-- Do not assign wantBlock here. M2-NOPRESS below is the log.
	if wantBlock then
		local dtx2 = State.dodgeTxn
		if dtx2 and dtx2.pending then
			local cAbs = wantBlock.contactAbs
			if type(cAbs) == "number" and cAbs >= (dtx2.lo or 0) - 0.05
				and cAbs <= (dtx2.hi or 0) + 0.05 then
				-- Predicted i-frame is not IFRAMES. V293 Ali M2 rem=0 want=nil
				-- then DODGE-REJECT ack=610ms — parry was already stripped.
				if dtx2.confirmed then
					wantBlock = nil
				end
			end
		end
	end

	for ni = 1, #Threats do
		local nth = Threats[ni]
		if nth and nth.kind == "M2" and not nth.dodged and not nth.m2NoPressLogged
			and not nth.pressed and not nth.coveredByCounter then
			local remN = (nth.contactAbs or now) - now
			if remN < 0.16 and remN > -0.05 and wantBlock ~= nth then
				nth.m2NoPressLogged = true
				local okN, whyN = canBlockNow()
				local dtxNP = State.dodgeTxn
				local whyNP = "unselected"
				if nth.enteredWindow == nil and remN > 0.09 then whyNP = "before-pressAt"
				elseif wantBlock and wantBlock ~= nth then whyNP = "want-other"
				elseif dtxNP and dtxNP.pending and not dtxNP.confirmed then whyNP = "dodge-unacked"
				elseif dtxNP and dtxNP.pending and dtxNP.confirmed then whyNP = "dodge-cover"
				elseif not okN then whyNP = tostring(whyN)
				end
				diagPush("M2-NOPRESS t=%.2f %s(%s) rem=%.0fms threatens=%s src=%s dist=%.1f entered=%s want=%s blocking=%s canBlock=%s/%s why=%s",
					now, tostring(nth.name), tostring(nth.style), remN * 1000,
					tostring(nth.threatens), tostring(nth.recognitionSource or "?"),
					nth.geomDist2d or -1,
					tostring(nth.enteredWindow),
					wantBlock and (tostring(wantBlock.name) .. "/" .. tostring(wantBlock.kind)) or "nil",
					tostring(State.blocking), tostring(okN), tostring(whyN), whyNP)
			end
		end
	end

		local heldPwin = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
			or Config.PerfectWindow or 0.125

		if wantBlock then
			local meC = LocalPlayer.Character
			State.noParryNow = meC and meC:GetAttribute("ParryWindowDisabled") and true or false
		if State.noParryNow ~= State.noParryActive then
			State.noParryActive = State.noParryNow
			diagPush("PARRY-WINDOW t=%.2f %s → %s", now, State.noParryNow and "DISABLED" or "RESTORED",
					State.noParryNow and "normal guard / must-dodge" or "perfect parry")
		end
		if State.noParryNow and State.blocking then
			wantBlock.pressed = true
			wantBlock.coveredByHeldGuard = true
			if wantBlock.rec then wantBlock.rec.blockedReason = "ParryWindowDisabled: normal guard" end
		end
			if clusterStrategy == "HELD_GUARD" and State.blocking then
				for _, th in ipairs(cluster) do
					if heldGuardCovers(th, heldPwin, up) then
						th.pressed = true
						th.coveredByHeldGuard = true
					elseif Config.DeepDiag and not th.heldMissLogged then
						th.heldMissLogged = true
						local since = State.lastPress
						diagPush("HELD-GUARD-MISS t=%.2f %s %s: гард поднят %s назад, окно=%.0fms, "
							.. "контакт через %+.0fms → не накрыт, решаем отдельно",
							now, tostring(th.name), tostring(th.kind),
							(type(since) == "number" and since > 0)
								and string.format("%.0fms", (now - since) * 1000) or "н/д",
							heldPwin * 1000, (th.contactAbs - now) * 1000)
					end
				end
			end
			local deferForHeavy, heavyTh = false, nil
			if Config.HeavyFirst ~= false and not wantBlock.pressed
				and heavyRank(wantBlock) == 0 and State.blocking and heldGuardCovers(wantBlock, heldPwin, up)
				and ((wantBlock.contactAbs or now) - now) > 0.14 then
				local cd   = Config.BlockCooldown or 0.5
				local lead = Config.PerfectLead or 0.0625
				for _, th in ipairs(Threats) do
					if th ~= wantBlock and th.threatens and not th.pressed and not th.offTarget
						and heavyRank(th) > 0 and th.contactAbs > wantBlock.contactAbs
						and not m2BreaksHeldGuard(th)
						and (th.contactAbs - wantBlock.contactAbs) < cd
						and (th.contactAbs - lead - up) > now then
						deferForHeavy, heavyTh = true, th
						break
					end
				end
			end
			if deferForHeavy then
				wantBlock.coveredByHeldGuard = true
				if wantBlock.rec then wantBlock.rec.blockedReason = "DeferredForHeavy: covered by held guard" end
				if Config.DeepDiag and not wantBlock.deferLogged then
					wantBlock.deferLogged = true
					diagPush("HEAVY-DEFER t=%.2f нажатие копим на %s %s(%+.0fms): %s %s(%+.0fms) уже накрыт "
						.. "поднятым гардом, парри достаётся тяжёлому",
						now, tostring(heavyTh.name), tostring(heavyTh.kind), (heavyTh.contactAbs - now) * 1000,
						tostring(wantBlock.name), tostring(wantBlock.kind), (wantBlock.contactAbs - now) * 1000)
				end
			end
			if not wantBlock.pressed and not deferForHeavy then
			local faceHold = false
			if Config.AutoFace then
				snapLookAtThreat(wantBlock)
				local fdNow = faceDotToThreat(wantBlock)
				local gate = Config.FaceGateMin or Config.FaceGoodDot or 0.52
				local remainFace = (wantBlock.contactAbs or now) - now
				local ov = wantBlock.hbOverlapClock
				local emergencyFace = ov and now < ov + (Config.EmergencyPressGrace or 0.20)
				if fdNow ~= nil and fdNow < gate and not emergencyFace
					and remainFace > (Config.FacePressFloor or 0.055) then
					faceHold = true
					setFaceGoal(wantBlock.attackerHRP, true, math.max(remainFace, 0) + (Config.HoldAfter or 0.12) + 0.06)
					if not wantBlock.faceWaitLogged then
						wantBlock.faceWaitLogged = true
						diagPush("FACETURN t=%.2f %s %s face=%.2f dt=%+.0fms → rotating, press held", now, wantBlock.name or "?", wantBlock.kind or "?", fdNow, remainFace * 1000)
					end
				end
			end
			if meC and stunEscapeNow(meC) then
				faceHold = false
				local remS = (wantBlock.contactAbs or now) - now
				-- Sticky stunTooLate ate the press after stun dropped (V296 HvH
				-- NO-PRESS / LATE pressDt=78). Skip only this frame while stunned.
				if remS < (Config.StunPressMinRemain or 0.05) then
					wantBlock.stunTooLate = true
				else
					wantBlock.stunTooLate = false
					snapLookAtThreat(wantBlock)
				end
			else
				wantBlock.stunTooLate = false
			end
			local comboOk = false
			local pAt = wantBlock.pressAtQ
			local hEnd = wantBlock.holdEndQ
			if type(pAt) == "number" and now >= pAt then
				comboOk = (type(hEnd) ~= "number") or now <= hEnd
			end
			if wantBlock.needComboEscape then comboOk = true end
			local sent, armOnly
			local tooEarly = type(pAt) == "number" and now < pAt - 0.008
				and not wantBlock.needComboEscape
			do
				local stunnedNow = meC and stunEscapeNow(meC) and true or false
				State.prevStunEsc = stunnedNow
			end
			if not faceHold and not wantBlock.stunTooLate and not tooEarly then
				if (wantBlock.strike or 1) >= 2 and State.blocking then
					releaseBlock()
				end
				snapLookAtThreat(wantBlock)
				State.pressSpoofExtra = 0
				if wantBlock.origin == "hitbox" then
					local pmin = Config.PerfectMin or 0.05
					local pwin = Config.PerfectWindow or 0.125
					local extra = up + (pmin + pwin) * 0.5
					if extra > 0.16 then extra = 0.16 end
					State.pressSpoofExtra = extra
				end
				sent, armOnly = fireBlock(serverNow, comboOk)
				State.pressSpoofExtra = 0
			end
			if sent and armOnly then
				wantBlock.stunArmed = true
			elseif sent then
				wantBlock.pressed  = true
				wantBlock.didPressClock = now
				wantBlock.pressDt  = wantBlock.contactAbs - now
				if (wantBlock.strike or 1) == 1 and wantBlock.group and wantBlock.group.second
					and not wantBlock.group.second.pressed then
					local t2 = wantBlock.group.second.contactAbs
					if type(t2) == "number" then
						State.multiRearmUntil = math.max(State.multiRearmUntil or 0, t2 + 0.10)
					end
				end
				do
					local pwinP = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
						or Config.PerfectWindow or 0.125
					State.lastPressEarly = (wantBlock.pressDt or 0) > (pwinP + 0.02)
				end
					if clusterStrategy == "HELD_GUARD" then
						for _, th in ipairs(cluster) do
							if heldGuardCovers(th, heldPwin, up) then
								th.pressed = true
								th.coveredByHeldGuard = true
							end
						end
					end
				wantBlock.faceDot  = faceDotToThreat(wantBlock)
				State.rearmCount   = (State.rearmCount or 0) + 1
				if wantBlock.trustedHit and not wantBlock.trustCounted then
					wantBlock.trustCounted = true
					State.trustPress = (State.trustPress or 0) + 1
				end
				if wantBlock.rec then
					wantBlock.rec.pressDt = wantBlock.pressDt
					wantBlock.rec.pressServer = serverNow
					wantBlock.rec.pressClock = now
					wantBlock.rec.pressAt = wantBlock.contactAbs - (wantBlock.aimGap or Config.PerfectLead or 0) - up
					wantBlock.rec.pressLateBy = now - wantBlock.rec.pressAt
					wantBlock.rec.uplinkAtPress = up
					wantBlock.rec.faceDot = wantBlock.faceDot
					local p1, ps = pingDiagSnapshot()
					local tpNow = wantBlock.track and wantBlock.track.TimePosition or -1
					diagTrace("TRACE-PRESS t=%.3f srv=%.3f %s %s s%d dt=%+.0fms lateBy=%+.0fms tp=%.3f | detect net1w=%sms stats=%sms raw=%.0f med=%.0f up=%.0f | press net1w=%sms stats=%sms raw=%.0f med=%.0f up=%.0f ema=%.0f jit=%.0f", now, serverNow, wantBlock.name or "?", wantBlock.kind or "?", wantBlock.strike or 1,
						wantBlock.pressDt*1000, wantBlock.rec.pressLateBy*1000, tpNow,
						wantBlock.pingOneWayDetect and string.format("%.0f", wantBlock.pingOneWayDetect*1000) or "?",
						wantBlock.pingStatsDetect and string.format("%.0f", wantBlock.pingStatsDetect*1000) or "?",
						(wantBlock.pingRawDetect or 0)*1000, (wantBlock.pingMedDetect or 0)*1000,
						(wantBlock.uplinkDetect or 0)*1000,
						p1 and string.format("%.0f", p1*1000) or "?", ps and string.format("%.0f", ps*1000) or "?",
						getPingRaw()*1000, getPing()*1000, up*1000,
						(V93.gnpEma or 0)*1000, (V93.gnpJit or 0)*1000)
				end
			elseif State.blockedReason then
				if wantBlock.rec then wantBlock.rec.blockedReason = State.blockedReason end
				if wantBlock.lastReason ~= State.blockedReason
					or (State.blockedReason == "BlockCooldown"
						and now - (wantBlock.lastReasonAt or 0) > 0.15) then
					wantBlock.lastReason = State.blockedReason
					wantBlock.lastReasonAt = now
					local cdLeft = -1
					if State.blockedReason == "BlockCooldown" then
						local rel = State.lastBlockRelease or State.lastPress
						if rel then
							cdLeft = math.max(0, rel + (Config.BlockCooldown or 0.5)
								+ (Config.BlockCooldownSafety or 0.03) - now)
						end
					end
					diagPush("BLOCK? t=%.2f  %s  %s  refused: %s  (buffered=%s stun=%s cant=%s gb=%s pwd=%s pb=%s)%s", now, wantBlock.name, wantBlock.kind, State.blockedReason,
						tostring(meC and parryBufferedNow(meC)),
						tostring(meC and meC:GetAttribute("Stunned") and true or false),
						tostring(meC and meC:GetAttribute("CantAnything") and true or false),
						tostring(meC and meC:GetAttribute("GuardBroken") and true or false),
						tostring(meC and meC:GetAttribute("ParryWindowDisabled") and true or false),
						tostring(meC and meC:GetAttribute("PerfectBlocking") and true or false),
						(cdLeft >= 0) and string.format(" [CD left %.0fms, contactIn %+.0fms]", cdLeft*1000, (wantBlock.contactAbs - now)*1000) or "")
				end
				do
					local remD = (wantBlock.contactAbs or now) - now
					if not wantBlock.pressed and not wantBlock.coveredByDodge
					   and not wantBlock.stunArmed
					   and not (meC and stunEscapeNow(meC))
					   and remD > 0.09
					   and Config.AutoDodge ~= false and Config.FallbackDodgeOnRefusal ~= false
					   and dodgeReady() and canDodgeNow() and not counterPreemptsDodge(now) then
						if performDodge(now, "must-dodge(block-refused:" .. tostring(State.blockedReason) .. ")",
							false, true, false, wantBlock) then
							diagPush("FALLBACK-DODGE t=%.2f %s %s contactIn=%.0fms → блок отказан (%s), додж как последний рубеж",
								now, tostring(wantBlock.name), tostring(wantBlock.kind),
								remD * 1000, tostring(State.blockedReason))
							return
						end
					end
				end
			end
		end
		local holdExtra = (wantBlock.kind == "M2" and Config.M2WidenWindow) and Config.M2WidenHold or 0
		local base = wantBlock.contactAbs
			if Config.Mode ~= "Perfect" and multiThreat and farContact and farContact > base
				and clusterStrategy ~= "SEQUENTIAL"
				and clusterStrategy ~= "PARRY_THEN_DODGE" then
				base = farContact
			end
		if m2BreaksHeldGuard(wantBlock) then
			base = wantBlock.contactAbs
		end
		-- Jin/Mishima M2 s2 is +550ms. Extending holdUntil to s2 keeps s1 guard
		-- up the whole gap; the 2nd hit never gets a fresh Activated (ragdoll phase).
		if not ((wantBlock.strike or 1) >= 2 and not wantBlock.pressed) then
			State.holdUntil = math.max(State.holdUntil,
				base + Config.HoldAfter + (Config.HoldLateGrace or 0) + holdExtra)
		end
	elseif State.blocking then
		local keepForCluster = Config.Mode ~= "Perfect" and ((multiThreat and farContact
			and now < (farContact + Config.HoldAfter + (Config.HoldLateGrace or 0)))
			or (State.multiHoldUntil and now < State.multiHoldUntil))
		local releaseByGap = (not multiThreat) and (not (State.multiHoldUntil and now < State.multiHoldUntil))
			and (now - State.lastPress) > Config.ReleaseGap
		if releaseByGap then
			for ri = 1, #Threats do
				local rt = Threats[ri]
				if rt and not rt.resolved and not rt.dodged
					and (rt.threatens or rt.everThreatened)
					and (rt.contactAbs or 0) > now + 0.02
					and not (rt.group and (rt.strike or 1) >= 2) then
					releaseByGap = false
					break
				end
			end
		end

		local keepAsLastResort, lastResortTh = false, nil
		if Config.GuardLastResort ~= false then
			local horizon = now + (Config.GuardLastResortHorizon or 0.18)
			local soonest = nil
			for i = 1, #Threats do
				local th = Threats[i]
				if th.threatens and not th.pressed and not th.coveredByDodge
					and not th.coveredByCounter and not th.offTarget
					and not m2BreaksHeldGuard(th)
					and not State.lastPressEarly
					and th.contactAbs > now and th.contactAbs <= horizon
					and (not soonest or th.contactAbs < soonest.contactAbs) then
					soonest = th
				end
			end
			if soonest then
				local remainHold = soonest.contactAbs - now
				local pwinHold = (Config.PerfectWindowLive ~= false and GameData.perfectWindow)
					or Config.PerfectWindow or 0.125
				local cd   = Config.BlockCooldown or 0.5
				local lead = Config.PerfectLead or 0.0625
				local readyAt = now + cd + (Config.BlockCooldownSafety or 0.03)
				local pressBy = soonest.contactAbs - lead - uplink()
				local canRepress = readyAt <= pressBy
				local canDodgeIt = Config.AutoDodge and dodgeReady() and canDodgeNow()
					and not counterPreemptsDodge(now)
				if remainHold <= (pwinHold + 0.06)
				   and not canRepress and not canDodgeIt then
					local stam = blockStamina()
					if stam == nil or stam > (Config.StaminaFloor or 18) then
						keepAsLastResort, lastResortTh = true, soonest
						State.holdUntil = math.max(State.holdUntil or 0,
							soonest.contactAbs + Config.HoldAfter + (Config.HoldLateGrace or 0))
						soonest.coveredByHeldGuard = true
					end
				end
			end
		end
		if keepAsLastResort and Config.DeepDiag
			and (not State.lastResortLogAt or now - State.lastResortLogAt > 0.25) then
			State.lastResortLogAt = now
			diagPush("GUARD-HOLD t=%.2f  %s  %s  → парри на кулдауне и додж недоступен, "
				.. "гард НЕ отпускаем (contactIn=%+.0fms): обычный блок вместо пропуска",
				now, tostring(lastResortTh.name), tostring(lastResortTh.kind),
				(lastResortTh.contactAbs - now) * 1000)
		end

		local liveWindup = false
		if Config.HoldForLiveAnim ~= false and State.blocking then
			for wi = 1, #Threats do
				local wth = Threats[wi]
				if wth and (wth.threatens or wth.everThreatened) and not wth.offTarget
				   and not wth.resolved and not wth.staleTrack then
					local hr = wth.holdRemain
					if type(hr) ~= "number" then
						hr = (wth.contactAbs or now) - now
					end
					if hr > 0.04 then
						liveWindup = true
						State.holdUntil = math.max(State.holdUntil or 0,
							now + hr + (Config.HoldAfter or 0.12))
					end
				end
			end
		end

		if not keepForCluster and not keepAsLastResort and not liveWindup
			and (now >= State.holdUntil or releaseByGap) then
			releaseBlock()
			State.multiHoldUntil = 0
		end
	end

	-- Своя атака выставляет CombatAttacking/CantAnything на ~0.4с, а это ровно
	-- то состояние, в котором парри отказано (V186: «refused: CantAnything»
	-- с последующим HIT). Бьём только когда ни одного отслеживаемого свинга нет.
	-- Punish is NPC-only (V302). Never swing while a tracked threat
	-- still needs a parry — M1 sets CantAnything and the next parry dies.
	if Config.AP_PunishOnParry ~= false and not wantBlock and #imminent == 0 and #Threats == 0 then
		if Config.AutoPlay or State.ap.punishTgt then
			State.ap.step(now)
		end
	end
end)

local function parseEvent(ev)
	local kind = ev:match("^(M%d)")
	if not kind then return nil end
	local rest = ev:sub(#kind + 1)
	if rest == "Hit" then return kind, "LATE"
	elseif rest == "Blocked" then return kind, "EARLY"
	elseif rest == "PerfectBlocked" then return kind, "PERFECT"
	elseif rest == "GuardBroken" then return kind, "GUARDBREAK" end
	return nil
end

local function outcomeTypeMatches(recType, kind)
	if recType == kind then return true end
	if kind == "M2" and recType == "SKILL" then return true end
	return false
end

local function onOutcome(attacker, result, kind, eventClock)
	local q = Pending[attacker]
	local rec, looseRec, followUp
	if q then
		for i = #q, 1, -1 do
			local r = q[i]
			local age = eventClock - r.clock
			if age >= 0 and age <= Config.MatchWindow and outcomeTypeMatches(r.type, kind) then
				local pred = r.contact or 0
				local leftover = pred > 0.15 and age < math.max(0.06, pred * 0.22)
				if leftover then
					local otherOpen = false
					for j = 1, #q do
						local o = q[j]
						if o ~= r and not o.matched and outcomeTypeMatches(o.type, kind) then
							otherOpen = true
							break
						end
					end
					if not otherOpen then leftover = false end
				end
				if leftover then
					-- leftover Hit from a previous swing, not this rec
				elseif not r.matched then
					local score = math.abs((eventClock - r.clock) - (r.contact or 0))
					if r.type == kind then
						if not rec or score < (rec.matchScore or math.huge) then
							rec, r.matchScore = r, score
						end
					elseif not looseRec or score < (looseRec.matchScore or math.huge) then
						looseRec, r.matchScore = r, score
					end
				elseif not followUp and (eventClock - r.clock) <= Config.MultiHitWindow then
					followUp = r
				end
			end
		end
		if not rec then rec = looseRec end
	end

	if not rec and followUp then
		diagPush("OUT    t=%.2f  %s  %s  %s  (multi-hit follow-up +%.0fms, guard kept)", eventClock, attacker, kind, result, (eventClock - followUp.clock)*1000)
		return
	end

	if not rec then
		local nPend, bits = 0, {}
		if q then
			nPend = #q
			local lim = math.min(nPend, 4)
			for i = nPend - lim + 1, nPend do
				local r = q[i]
				if r then
					bits[#bits + 1] = string.format("%s%s age=%.0f pred=%.0f %s",
						tostring(r.type), r.strike and ("s"..tostring(r.strike)) or "",
						(eventClock - r.clock) * 1000, (r.contact or 0) * 1000,
						r.matched and "matched" or "open")
				end
			end
		end
		diagPush("OUT    t=%.2f  %s  %s  %s  (no fresh swing) pending=%d [%s] skip=%s poll=%d decoyDrop=%d",
			eventClock, attacker, kind, result, nPend, table.concat(bits, "; "),
			tostring(State.lastAnimSkip or "-"), State.pollDetect or 0, State.decoyDropped or 0)
		return
	end

	State.tally[result] = (State.tally[result] or 0) + 1
	State.lastResult    = result
	State.flashUntil    = os.clock() + 0.25
	if kind == "M2" then
		-- V304: per-style M2 bucket for the diag header.
		local sk = tostring(rec.style or "?") .. " s" .. tostring(rec.strike or 1)
		local mt = State.m2Tally
		if type(mt) ~= "table" then mt = {}; State.m2Tally = mt end
		local b = mt[sk]
		if type(b) ~= "table" then b = {}; mt[sk] = b end
		b[result] = (b[result] or 0) + 1
	end

	if Config.DodgeTelemetry and State.lastDodgeInfo then
		local di = State.lastDodgeInfo
		local dtSinceFire = eventClock - di.fire
		local targetMatches = (di.targetTh == nil) or (rec.th ~= nil and rec.th == di.targetTh)
		if targetMatches and dtSinceFire >= 0 and dtSinceFire <= 0.9 then
			local hitT = eventClock
			local rel
			if hitT < di.iframeLo then
				rel = string.format("hit %.0fms BEFORE window → dodge TOO EARLY", (di.iframeLo - hitT)*1000)
			elseif hitT > di.iframeHi then
				rel = string.format("hit %.0fms AFTER window → dodge TOO LATE", (hitT - di.iframeHi)*1000)
			else
				rel = string.format("hit INSIDE i-frame window (+%.0fms from start)", (hitT - di.iframeLo)*1000)
			end
			diagPush("DODGE-OUT t=%.2f  %s  %s  %s  fired %.0fms before  [%s]", eventClock, attacker, kind, result, dtSinceFire*1000, rel)
			State.lastDodgeInfo = nil
		end
	end

	rec.matched = true
	if rec.th then rec.th.resolved = true end

	if result == "GUARDBREAK" then
		State.blocking, State.holdUntil = false, 0
		State.blockChipStreak = 0
		State.lastPressEarly = false
	elseif result == "LATE" then
		local holding = State.blocking and (os.clock() < (State.holdUntil or 0))
		if not (State.multiThreat and holding) then State.blocking, State.holdUntil = false, 0 end
	elseif result == "EARLY" then
		State.blockChipStreak = (State.blockChipStreak or 0) + 1
		State.lastPressEarly = true
		if Config.Mode == "Perfect" then
			State.holdUntil = math.min(State.holdUntil or 0, os.clock() + (Config.HoldAfter or 0.12))
		end
	elseif result == "PERFECT" then
		State.blockChipStreak = 0
		State.lastPressEarly = false
	end
	if result == "PERFECT" and rec.th and rec.th.group then
		if (rec.th.strike or 1) >= 2 then
			rec.th.group.cancelled = true
		end
	elseif result == "EARLY" and rec.th and rec.th.group then
		if (rec.th.strike or 1) >= 2 and not m2BreaksHeldGuard(rec.th) then
			rec.th.group.held = true
		end
	end
	if result == "PERFECT" and rec.th and rec.th.clusterStrategy == "HELD_GUARD" then
		for _, other in ipairs(Threats) do
			if other ~= rec.th and not other.resolved and other.contactAbs > eventClock then
				other.pressed, other.coveredByHeldGuard = false, false
				if other.rec then other.rec.pressDt, other.rec.pressServer = nil, nil end
			end
		end
		State.blocking, State.holdUntil, State.multiHoldUntil = false, 0, 0
	end
	if result == "PERFECT" then State.ap.onPerfectParry(attacker, kind, rec.th) end

	local measured = eventClock - rec.clock
	local predErr  = (measured - rec.contact) * 1000
	State.lastErrMs = predErr

	local ksKey = tostring(kind) .. ":" .. tostring(rec.style or "?") .. ":" .. tostring(rec.strike or 1)
	local ks = _D.ResidByKS[ksKey]; if not ks then ks = { sum = 0, n = 0 }; _D.ResidByKS[ksKey] = ks end
	-- Delayed-hitbox LATE (+146ms) must not poison RESID-PAD for the next swing.
	-- PERFECT predErr trains Jin/Mishima M2 s1 (cfg 280ms, live ~320). LATE-only
	-- mixed s2 residuals and never padded the first hit.
	-- LATE predErr mixes miss causes (−87 fast / +61 slow) and kills the pad
	-- (avg drops under 22). PERFECT is the only clean residual.
	if result == "PERFECT" and predErr > -90 and predErr < 90 then
		ks.sum = ks.sum + predErr; ks.n = ks.n + 1
		if ks.n > 100 then ks.sum = ks.sum * (100 / ks.n); ks.n = 100 end
	end
	local resAvg = (ks.n > 0) and (ks.sum / ks.n) or 0
	local resNShown = ks.n


	local upAtPress = (type(rec.uplinkAtPress) == "number" and rec.uplinkAtPress or uplink()) * 1000
	local eventServer = rec.detectServer and (rec.detectServer + measured) or nil
	local blockGap = nil
	if rec.pressServer and eventServer then blockGap = (eventServer - rec.pressServer) * 1000 end
	local trueGap = blockGap and (blockGap - upAtPress) or nil
	local gapStr  = blockGap and string.format("%+.0f→true%+.0fms", blockGap, trueGap) or "NO-PRESS"
	local pressStr = rec.pressDt and string.format("%.0fms", rec.pressDt*1000) or "—"
	local hint = "?"
	if trueGap then
		local pwinMs = ((Config.PerfectWindowLive ~= false and GameData.perfectWindow)
			or Config.PerfectWindow or 0.125) * 1000
		if trueGap < Config.PerfectMin*1000 then hint = string.format("LATE(<%.0f)", Config.PerfectMin*1000)
		elseif trueGap > pwinMs then hint = string.format("EARLY(>%.0f)=BLOCK-NOT-PARRY", pwinMs)
		else hint = "IN-WINDOW" end
	elseif rec.pressServer == nil then
		hint = "NOT-BLOCKED"
	end

	local faceStr = rec.faceDot and string.format("%.2f", rec.faceDot) or "n/a"
	local faceFlag = (rec.faceDot ~= nil and rec.faceDot < Config.FaceGoodDot) and " BACK!" or ""
	if rec.faceDot ~= nil then
		local b = _D.FaceByResult[result]; if not b then b = { sum = 0, n = 0 }; _D.FaceByResult[result] = b end
		b.sum = b.sum + rec.faceDot; b.n = b.n + 1
		if b.n > 100 then b.sum = b.sum * (100 / b.n); b.n = 100 end
	end

	local reasonStr = rec.blockedReason and (" STATE:" .. rec.blockedReason) or ""
	-- IN-WINDOW press that the server still HIT is clash, not state-lock.
	-- V300 counted those as locked (8/9) while we did tap.
	if rec.blockedReason and (result == "LATE" or result == "GUARDBREAK") then
		local inWin = trueGap and trueGap >= (Config.PerfectMin or 0.05) * 1000
			and trueGap <= (((Config.PerfectWindowLive ~= false and GameData.perfectWindow)
				or Config.PerfectWindow or 0.125) * 1000)
		if not (rec.pressDt and inWin) then
			State.stateHits = (State.stateHits or 0) + 1
		end
	end

	do
		State.comboStat = State.comboStat or { opener = {}, tail = {} }
		local bucket = ((rec.combo or 0) >= 3) and State.comboStat.tail or State.comboStat.opener
		bucket[result] = (bucket[result] or 0) + 1
	end

	do
		if Config.Debug then
		local th = rec.th
		local p1, ps = pingDiagSnapshot()
		local tpOut = th and th.track and th.track.TimePosition or -1
		diagTrace("TRACE-OUT t=%.3f %s %s s%d result=%s age=%.0fms tp=%.3f | firstThreat=%sms hbFirst=%sms hbOverlap=%sms sid=%s src=%s | pressLate=%sms | net1w=%sms stats=%sms raw=%.0f med=%.0f up=%.0f", eventClock, attacker, kind, rec.strike or 1, result, measured*1000, tpOut,
				th and th.firstThreatClock and string.format("%.0f", (th.firstThreatClock-rec.clock)*1000) or "?",
				th and th.hbFirstClock and string.format("%.0f", (th.hbFirstClock-rec.clock)*1000) or "?",
				th and th.hbOverlapClock and string.format("%.0f", (th.hbOverlapClock-rec.clock)*1000) or "?",
				tostring(th and (th.serverSwingId or (th.group and th.group.serverSwingId)) or "none"),
				tostring(th and th.recognitionSource or "none"),
				rec.pressLateBy and string.format("%+.0f", rec.pressLateBy*1000) or "?",
				p1 and string.format("%.0f", p1*1000) or "?", ps and string.format("%.0f", ps*1000) or "?",
				getPingRaw()*1000, getPing()*1000, uplink()*1000)
		end
	end

	diagPush("OUT    t=%.2f  %s  %s(c%d,s%d)  %-10s  meas=%.0fms pred=%.0fms predErr=%+.0fms resAvg=%+.0fms(n=%d) | blockGap=%s guard=%s pressDt=%s%s | face=%s%s spd=%.2f ping=%.0f", eventClock, attacker, kind, rec.combo or 0, rec.strike or 1, result, measured*1000, rec.contact*1000,
		        predErr, resAvg, resNShown, gapStr, hint, pressStr, reasonStr, faceStr, faceFlag, rec.speed or 1, (rec.pingRaw or 0)*1000)
end

_C.hooked = setmetatable({}, { __mode = "k" })
_C.animIdCache = setmetatable({}, { __mode = "k" })
_C.ownerCache  = setmetatable({}, { __mode = "k" })
_C.OWNER_TTL    = 8.0

local function cachedAnimId(anim)
	local v = _C.animIdCache[anim]
	if v ~= nil then return v or nil end
	local parsed = tonumber(tostring(anim.AnimationId):match("(%d+)"))
	_C.animIdCache[anim] = parsed or false
	return parsed
end

local function cachedOwner(animator)
	local now = os.clock()
	local rec = _C.ownerCache[animator]
	if rec and (now - rec.t) < _C.OWNER_TTL then return rec end
	local model = ownerOf(animator)
	local enemy, hrp = isEnemyModel(model)
	rec = { model = model, isLocal = (model ~= nil and model == localChar()), enemy = enemy or false, hrp = hrp, t = now }
	_C.ownerCache[animator] = rec
	return rec
end

local function hookAnimator(animator)
	if _C.hooked[animator] then return end
	_C.hooked[animator] = true
	animator.AnimationPlayed:Connect(function(track)
		local anim = track and track.Animation
		if not anim then return end
		local id = cachedAnimId(anim)
		if not id then return end
		local rec = cachedOwner(animator)
		if Config.DesyncAttack and AnimLib.desyncOwnTrack and rec.isLocal then
			AnimLib.desyncOwnTrack(track, id, animator)
		end
		if not Config.Enabled then return end
		if not rec.enemy then return end
		if _D.BlockIds[id] then return end
		if not attackEntry(id) then
			local nm = anim.Name
			local k = kindFromName(nm)
			if not k then
				local p = anim.Parent
				if p then k = kindFromName(p.Name) end
			end
			if not k then return end
			_D.AttackIds[id] = {
				kind = k, combo = (k == "M1") and comboFromName(nm) or nil,
				name = nm, mom = tostring(nm):lower():find("momentum") ~= nil,
			}
		end
		local knownKind = attackEntry(id) and attackEntry(id).kind
		if Config.AntiDecoy and Config.DecoyHardDrop ~= false then
			local S = State.decoySeen; if not S then S = {}; State.decoySeen = S end
			local nowd = os.clock()
			local spd = track.Speed
			if type(spd) == "number" and spd > 0 then
				local lo = Config.DecoySpeedMin or 0.30
				local hi = Config.DecoySpeedMax or 1.25
				if spd < lo or spd > hi then
					State.decoyDropped = (State.decoyDropped or 0) + 1
					if (nowd - (State.lastDecoyLog or 0)) > 1 then
						State.lastDecoyLog = nowd
						aclog(string.format("[breaker] %s speed=%.2f (legal %.2f..%.2f) — phantom dropped x%d", tostring(rec.model and rec.model.Name or "?"), spd, lo, hi,
								State.decoyDropped))
					end
					return
				end
			end
			local dk = tostring(rec.model and rec.model.Name or "?") .. "|" .. tostring(id)
			local prevT = S[dk]
			if knownKind ~= "M2" and knownKind ~= "SKILL"
				and prevT and (nowd - prevT) < (Config.DecoyRefireSec or 0.60) then
				State.decoyDropped = (State.decoyDropped or 0) + 1
				State.lastAnimSkip = "decoy-refire"
				if (nowd - (State.lastDecoyLog or 0)) > 1 then
					State.lastDecoyLog = nowd
					aclog(string.format("[breaker] %s same-id refire %.0fms (< %.0fms) — phantom dropped x%d", tostring(rec.model and rec.model.Name or "?"), (nowd - prevT)*1000,
							(Config.DecoyRefireSec or 0.60)*1000, State.decoyDropped))
				end
				if Config.DeepDiag then
					diagPush("SKIP-ANIM t=%.2f %s id=%s same-id +%.0fms → decoy hard-drop", nowd, tostring(rec.model and rec.model.Name), tostring(id), (nowd - prevT)*1000)
				end
				return
			end
			S[dk] = nowd
			State.decoySweepAt = State.decoySweepAt or nowd
			if nowd >= State.decoySweepAt then
				State.decoySweepAt = nowd + (Config.DecoySweepSec or 5)
				local live = 0
				for k, t in pairs(S) do
					if (nowd - t) > 8 then S[k] = nil else live = live + 1 end
				end
				if live > (Config.DecoySeenMax or 512) then
					State.decoySeen = { [dk] = nowd }
				end
			end
		end
		local info = resolveInfo(id, rec.model)
		if not info then return end
		onAttack(rec.hrp, info, rec.model, id, track)
	end)
end

local function scanAnimators()
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch  = plr.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local an  = hum and hum:FindFirstChildOfClass("Animator")
		if an then hookAnimator(an) end
	end
	if not State.didInitialAnimatorSweep then
		State.didInitialAnimatorSweep = true
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("Animator") then hookAnimator(d) end
		end
	end
end

_C.scanPlayingAttacks = function()
	if not Config.Enabled then return end
	local now = os.clock()
	if now - (_C.lastPlayScan or 0) < 0.18 then return end
	_C.lastPlayScan = now
	local me = localHRP()
	if not me then return end
	local rangeCap = math.min(Config.Range or 18, 20)
	local players = Players:GetPlayers()
	for pi = 1, #players do
		local plr = players[pi]
		if plr ~= LocalPlayer then
			local ch = plr.Character
			if ch then
				local hrp = ch:FindFirstChild("HumanoidRootPart")
				local hum = ch:FindFirstChildOfClass("Humanoid")
				local an = hum and hum:FindFirstChildOfClass("Animator")
				if hrp and an then
					local dx = hrp.Position.X - me.Position.X
					local dz = hrp.Position.Z - me.Position.Z
					-- Anim-only poll is free bait. Resolver: server attr must
					-- already be up (CombatAttacking/M1/M2). Fake tracks don't replicate that.
					if not serverAttackProof(ch) then
					elseif (dx * dx + dz * dz) > rangeCap * rangeCap then
					else
						local recAt = V93.lastSwingAt[plr.Name]
						local seenRecent = false
						if recAt then
							local a = recAt.M1
							local b = recAt.M2
							if type(a) == "number" and (now - a) < 0.45 then seenRecent = true end
							if type(b) == "number" and (now - b) < 0.45 then seenRecent = true end
						end
						if seenRecent then
						else
						local tracks = an:GetPlayingAnimationTracks()
						for ti = 1, #tracks do
							local track = tracks[ti]
							local anim = track and track.Animation
							local id = anim and cachedAnimId(anim)
							if id and attackEntry(id) then
								local spdP = track.Speed
								if type(spdP) == "number" and spdP > 0 then
									local loP = Config.DecoySpeedMin or 0.30
									local hiP = Config.DecoySpeedMax or 1.25
									if spdP < loP or spdP > hiP then
										id = nil
									end
								end
							end
							if id and attackEntry(id) then
								local info = resolveInfo(id, ch)
								if info then
									local live = false
									for k = 1, #Threats do
										local thP = Threats[k]
										if thP and not thP.resolved and thP.track == track then
											live = true
											break
										end
									end
									if not live and not (State.seenAnimTrack and State.seenAnimTrack[track]) then
										local tp = track.TimePosition
										-- AnimationPlayed fires at tp=0. Mid-track poll is the
										-- same swing after PERFECT/NEUTRALIZED (V295: 165x contact=0).
										if type(tp) == "number" and tp <= 0.08 then
											State.pollDetect = (State.pollDetect or 0) + 1
											if Config.DeepDiag then
												diagPush("POLL-SWING t=%.2f %s %s id=%s tp=%.3f proof=attr", now, plr.Name, tostring(info.t), tostring(id), type(tp) == "number" and tp or -1)
											end
											onAttack(hrp, info, ch, id, track, "poll")
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
	end
end

Workspace.DescendantAdded:Connect(function(d)
	if d.ClassName == "Animator" then hookAnimator(d) end
end)

task.spawn(function()
	local Shared  = ReplicatedStorage:WaitForChild("Shared", 30)
	local Network = Shared and Shared:WaitForChild("Network", 30)
	local ure     = Network and Network:WaitForChild("CombatBroadcastURE", 30)
	if not ure then dbg("CombatBroadcastURE not found — calibration off"); return end
	local myName = LocalPlayer.Name
	ure.OnClientEvent:Connect(function(eventName, attacker, victim, ...)
		if type(eventName) ~= "string" then return end
		if eventName == "StyleEvasiveCounter" then
			if attacker ~= myName then return end
			local now = os.clock()
			local tx = State.dodgeTxn
			if tx and tx.pending and now <= math.max(tx.untilAt or 0, tx.ackDeadline or 0) then
				tx.perfectConfirmed, tx.perfectAt = true, now
			diagPush("ALI-PERFECT-CONFIRM t=%.2f proc=one-perfect-dodge normalHeavyReset=false dodgeAgo=%.0fms iframeConfirmed=%s reason=%s", now, (now-(tx.fire or now))*1000, tostring(tx.confirmed == true),
					tostring(tx.reason or "?"))
			end
			return
		end
		if eventName == "WingChunCounterStartup" then
			local now = os.clock()
			if attacker == myName then
				if _D.WCTxn.pending and _D.WCTxn.sentAt > 0 then
					local ack = now - _D.WCTxn.sentAt
					_D.WCTxn.openAt  = now
					_D.WCTxn.closeAt = now + (_D.WCTxn.style and counterStanceWindow(_D.WCTxn.style) or _D.WINGCHUN.CounterWindow)
					diagPush("WC-STARTUP-ACK t=%.2f ack=%.0fms window=[now..+%.0fms] (fixed-timing, no-calib)",
						now, ack * 1000, (_D.WCTxn.closeAt - now) * 1000)
				end
			else
				local p = type(attacker) == "string" and Players:FindFirstChild(attacker)
				local m = p and p.Character
				if m then
					WingChunCounter[m] = now + _D.WINGCHUN.CounterWindow
					diagPush("WC-ENEMY-STANCE t=%.2f %s открыл counter-окно на %.0fms (broadcast)",
						now, tostring(attacker), _D.WINGCHUN.CounterWindow * 1000)
				end
			end
			return
		end
		if eventName == "StyleCounterHit" then
			-- Aikido M2CounterHitEvent (V303). Same shape as WingChunCounterHit:
			-- (attacker, victim, phase?). Server confirms our counter landed.
			local now = os.clock()
			if attacker == myName then
				if _D.WCTxn.pending then
					_D.WCTxn.pending = false
					_D.WCTxn.hits    = (_D.WCTxn.hits or 0) + 1
					State.selfBusyUntil = math.max(State.selfBusyUntil or 0,
						now + (_D.WCTxn.holdSecs or 1.95) + 0.35)
					diagPush("AIKIDO-COUNTER-HIT t=%.2f victim=%s hold=%.0fms (hits=%d whiffs=%d)",
						now, tostring(victim), (_D.WCTxn.holdSecs or 1.95) * 1000,
						_D.WCTxn.hits, _D.WCTxn.whiffs or 0)
				end
			elseif victim == myName then
				State.selfBusyUntil = math.max(State.selfBusyUntil or 0,
					now + 2.3)
				diagPush("AIKIDO-COUNTERED-BY t=%.2f %s → мы в стане %.1fс",
					now, tostring(attacker), 2.3)
			end
			return
		end
		if eventName == "WingChunCounterHit" then
			local now = os.clock()
			local holdS = _D.WCTxn.holdSecs or _D.WINGCHUN.CounterHoldSecs
			local vhs   = _D.WCTxn.victimHitStun or _D.WINGCHUN.VictimHitStun
			if attacker == myName then
				_D.WCTxn.pending = false
				_D.WCTxn.hits    = (_D.WCTxn.hits or 0) + 1
				State.selfBusyUntil = math.max(State.selfBusyUntil or 0,
					now + holdS + _D.WINGCHUN.PostHitLockout)
				diagPush("WC-COUNTER-HIT t=%.2f victim=%s стан=%.1fс hold=%.0fms (hits=%d whiffs=%d)",
					now, tostring(victim), vhs,
					holdS * 1000, _D.WCTxn.hits, _D.WCTxn.whiffs or 0)
			elseif victim == myName then
				State.selfBusyUntil = math.max(State.selfBusyUntil or 0,
					now + vhs)
				diagPush("WC-COUNTERED-BY t=%.2f %s → мы в стане %.1fс",
					now, tostring(attacker), vhs)
			end
			return
		end
		local kind, result = parseEvent(eventName)
		if not kind then return end
		if victim ~= myName then return end
		onOutcome(attacker, result, kind, os.clock())
	end)
	dbg("calibration active — listening CombatBroadcastURE")
end)

local function hideHook(fn)
	if not Config.HideHooks then return fn end
	local out = newcclosure(fn)
	setstackhidden(out, true)
	return out
end

local function findACScript()
	local rf = game:GetService("ReplicatedFirst")
	local s = rf:FindFirstChild(Config.ACScriptName)
	if s then return s end
	local roots = { rf }
	local lp = Players.LocalPlayer
	if lp then
		table.insert(roots, lp:FindFirstChild("PlayerScripts"))
		table.insert(roots, lp:FindFirstChild("PlayerGui"))
	end
	table.insert(roots, game:GetService("ReplicatedStorage"))
	for _, root in ipairs(roots) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("LocalScript") and d.Name:lower():find("challenging") then return d end
			end
		end
	end
	return nil
end

local function muteAC()
	if not (Config.AntiCheatBypass and Config.MuteAC) then return end
	if (State.acMuted or 0) > 0 then return end
	local ac = findACScript()
	if not ac then
		if not State.acMissLogged then
			State.acMissLogged = true
			aclog("[AC] anticheat script NOT FOUND yet (name/location changed?) — will keep retrying")
		end
		return
	end
	State.acScript = ac
	if not State.acFoundLogged then
		State.acFoundLogged = true
		aclog(string.format("[AC] DETECTED anticheat LocalScript: %s  (parent=%s) — muting now",
			tostring(ac.Name), tostring(ac.Parent and ac.Parent.Name or "?")))
	end

	local RS = game:GetService("RunService")
	local signals = {
		RS.Heartbeat, RS.RenderStepped, RS.Stepped, RS.PreSimulation, RS.PostSimulation,
		game.DescendantAdded, game.ChildAdded, workspace.DescendantAdded, workspace.ChildAdded,
	}
	pcall(function()
		local lp = Players.LocalPlayer
		if lp then table.insert(signals, lp.CharacterAdded); table.insert(signals, lp.Idled) end
	end)
	pcall(function()
		for _, svc in ipairs({ "ReplicatedStorage", "StarterGui", "StarterPlayer", "Players" }) do
			local s = game:GetService(svc)
			table.insert(signals, s.ChildAdded); table.insert(signals, s.DescendantAdded)
		end
	end)

	local muted = 0
	for _, sig in ipairs(signals) do
		pcall(function()
			for _, conn in ipairs(getconnections(sig)) do
				if conn.Script == ac then
					if type(conn.Disable) == "function" then
						conn:Disable(); muted = muted + 1
					elseif conn.Enabled ~= nil then
						conn.Enabled = false; muted = muted + 1
					end
				end
			end
		end)
	end
	State.acMuted = muted
	if muted > 0 then
		if (State.acMutedLogged or 0) ~= muted then
			State.acMutedLogged = muted
			aclog(string.format("[AC] BYPASS ACTIVE — muted %d connection(s) on the anticheat; script left enabled", muted))
		end
	elseif not State.acZeroLogged then
		State.acZeroLogged = true
		aclog("[AC] anticheat found but it owns no muteable connections yet — retrying")
	end
end

local function neutralizeAC()
	if not (Config.AntiCheatBypass and Config.NeutralizeAC) then return end
	if State.acGcWalked then return end
	State.acGcWalked = true
	local killNames = {
		["_sendanticheatreport"]      = true,
		["_sendanticheatshadowreport"] = true,
		["_reportvictimhit"]          = true,
		["_scanhitboxes"]             = true,
		["_wireremotespamtouch"]      = true,
		["_reporthitbox"]             = true,
		["_reportswing"]              = true,
		["_flag"]                     = true,
	}
	local trueNames = { ["_issuppressed"] = true }
	local noop   = hideHook(function() end)
	local truefn = hideHook(function() return true end)

	local patched, tablesHit = 0, 0
	pcall(function()
		for _, o in ipairs(getgc(true)) do
			if type(o) == "table" then
				local todo
				pcall(function()
					for k, v in pairs(o) do
						if type(k) == "string" and type(v) == "function" then
							local lk = k:lower()
							if killNames[lk] then todo = todo or {}; todo[#todo + 1] = { k, noop } end
							if trueNames[lk] then todo = todo or {}; todo[#todo + 1] = { k, truefn } end
						end
					end
				end)
				if todo then
					local hitThis = false
					for _, pair in ipairs(todo) do
						if pcall(function() rawset(o, pair[1], pair[2]) end) then
							patched = patched + 1; hitThis = true
						end
					end
					if hitThis then tablesHit = tablesHit + 1 end
				end
			end
		end
	end)

	State.acNeutralized = patched
	if patched > 0 then
		if (State.acNeutLogged or 0) ~= patched then
			State.acNeutLogged = patched
			aclog(string.format("[AC] NEUTRALIZED — replaced %d report method(s) across %d AC object(s) with no-ops (report senders killed at the source)", patched, tablesHit))
		end
	elseif not State.acNeutZeroLogged then
		State.acNeutZeroLogged = true
		aclog("[AC] neutralize: no AC report methods in GC yet — retrying")
	end
end

local function scanAC()
	local L = {}
	local function w(s) L[#L + 1] = s end
	local function has(name)
		local v = getgenv()[name] or getfenv(0)[name]
		return type(v) == "function", v
	end
	local function trunc(s, n)
		s = tostring(s):gsub("[%z\1-\8\11-\31]", ".")
		if #s > n then return s:sub(1, n) .. "…(" .. #s .. ")" end
		return s
	end

	w("===== AUTOPARRY ANTICHEAT SCAN =====")
	do
		local okId, exe, ver = pcall(function() local a, b = identifyexecutor(); return a, b end)
		w(string.format("executor: %s %s", okId and tostring(exe) or "?", okId and tostring(ver or "") or ""))
	end
	do
		local caps = { "getscriptclosure","getgc","filtergc","getconnections","getscriptbytecode",
			"getscripthash","getrunningscripts","getscriptthread","getcallingscript","decompile",
			"debug","hookfunction","newcclosure","setstackhidden","getsenv","getscripts" }
		local line = {}
		for _, c in ipairs(caps) do line[#line + 1] = (has(c) and "+" or "-") .. c end
		w("caps: " .. table.concat(line, " "))
	end

	local ac = findACScript()
	if not ac then
		w("!! AC script NOT FOUND by findACScript(). Listing candidate LocalScripts (name/parent):")
		local okScr, scripts = pcall(getscripts)
		if okScr and scripts then
			local shown = 0
			for _, s in ipairs(scripts) do
				local okA = pcall(function() return s:IsA("LocalScript") end)
				if okA and s:IsA("LocalScript") and shown < 60 then
					w(string.format("   %s  <%s>", tostring(s.Name), tostring(s.Parent and s.Parent:GetFullName() or "?")))
					shown = shown + 1
				end
			end
		end
	else
		w(string.format("AC script: %s", tostring(ac:GetFullName())))
		pcall(function() w("  hash: " .. tostring(getscripthash(ac))) end)
		pcall(function() local bc = getscriptbytecode(ac); w("  bytecode bytes: " .. tostring(bc and #bc or "?")) end)

		local hasGSC, gsc = has("getscriptclosure")
		local mainFn
		if hasGSC then local ok, f = pcall(gsc, ac); if ok then mainFn = f end end
		if type(mainFn) ~= "function" then
			w("  getscriptclosure: unavailable/failed — cannot walk protos")
		else
			local seen, fnCount = {}, 0
			local function walk(fn, depth, tag)
				if type(fn) ~= "function" or seen[fn] or depth > 6 or fnCount > 400 then return end
				seen[fn] = true; fnCount = fnCount + 1
				local info = {}
				pcall(function() local i = debug.getinfo(fn); if i then
					info = { nups = i.nups, npar = i.numparams, line = i.linedefined, name = i.name } end end)
				w(string.format("  fn[%s] d%d line=%s nups=%s name=%s", tag, depth,
					tostring(info.line or "?"), tostring(info.nups or "?"), tostring(info.name or "")))
				pcall(function()
					local cs = debug.getconstants(fn)
					if cs then for i, c in pairs(cs) do
						local t = type(c)
						if t == "string" and #c > 0 then
							w(string.format("     const[%s] %q", tostring(i), trunc(c, 90)))
						elseif t == "boolean" or t == "number" then
							w(string.format("     const[%s] = %s", tostring(i), tostring(c)))
						end
					end end
				end)
				pcall(function()
					local ups = debug.getupvalues(fn)
					if ups then for name, v in pairs(ups) do
						local t = type(v)
						local desc
						if t == "boolean" or t == "number" then desc = tostring(v)
						elseif t == "string" then desc = string.format("%q", trunc(v, 60))
						elseif t == "table" then
							local n = 0; pcall(function() for _ in pairs(v) do n = n + 1 end end)
							desc = string.format("table(#%d)", n)
						elseif t == "userdata" then
							local cls; pcall(function() cls = v.ClassName end)
							desc = "Instance<" .. tostring(cls or "userdata") .. ">"
							pcall(function() if v.Name then desc = desc .. ' "' .. tostring(v.Name) .. '"' end end)
						else desc = t end
						w(string.format("     up[%s] %s = %s", tostring(name), t, desc))
					end end
				end)
				pcall(function()
					local ps = debug.getprotos(fn)
					if ps then for i, p in ipairs(ps) do walk(p, depth + 1, tag .. "." .. i) end end
				end)
			end
			walk(mainFn, 0, "main")
			w(string.format("  (walked %d functions)", fnCount))
		end

		local hasGC, gc = has("getgc")
		if hasGC then
			local okSrc, acSrc = pcall(function() local i = debug.getinfo(mainFn); return i and i.source end)
			acSrc = okSrc and acSrc or nil
			local fnHit, tblHit = 0, 0
			local ok = pcall(function()
				for _, o in ipairs(gc(true)) do
					local t = type(o)
					if t == "function" and fnHit < 40 then
						local src; pcall(function() local i = debug.getinfo(o); src = i and i.source end)
						if src and acSrc and src == acSrc then
							local ln; pcall(function() ln = debug.getinfo(o).linedefined end)
							w(string.format("  gc.fn line=%s (AC-owned, live in GC)", tostring(ln)))
							fnHit = fnHit + 1
						end
					elseif t == "table" and tblHit < 25 then
						local keys = {}
						local okK = pcall(function()
							for k in pairs(o) do
								if type(k) == "string" then keys[#keys + 1] = k:lower() end
								if #keys > 24 then break end
							end
						end)
						if okK then
							local blob = table.concat(keys, ",")
							if blob:find("kick") or blob:find("detect") or blob:find("report")
							   or blob:find("flag") or blob:find("ban") or blob:find("exploit")
							   or blob:find("cheat") or blob:find("suspic") then
								w(string.format("  gc.table keys={%s}", trunc(blob, 120)))
								tblHit = tblHit + 1
							end
						end
					end
				end
			end)
			w(string.format("  gc sweep: %s (AC fns=%d, suspicious tables=%d)", ok and "ok" or "err", fnHit, tblHit))
		end

		local hasConn, gconn = has("getconnections")
		if hasConn then
			local RS = game:GetService("RunService")
			local sigs = {
				{ "Heartbeat", RS.Heartbeat }, { "RenderStepped", RS.RenderStepped }, { "Stepped", RS.Stepped },
				{ "PreSimulation", RS.PreSimulation }, { "PostSimulation", RS.PostSimulation },
				{ "PreRender", RS.PreRender }, { "PreAnimation", RS.PreAnimation },
				{ "game.DescendantAdded", game.DescendantAdded }, { "game.ChildAdded", game.ChildAdded },
				{ "ws.DescendantAdded", workspace.DescendantAdded },
			}
			pcall(function()
				local lp = Players.LocalPlayer
				if lp then
					sigs[#sigs+1] = { "LP.CharacterAdded", lp.CharacterAdded }
					sigs[#sigs+1] = { "LP.Idled", lp.Idled }
					if lp.Character then
						local hum = lp.Character:FindFirstChildOfClass("Humanoid")
						if hum then sigs[#sigs+1] = { "Humanoid.StateChanged", hum.StateChanged } end
					end
				end
			end)
			for _, pair in ipairs(sigs) do
				pcall(function()
					local total, mine = 0, 0
					for _, conn in ipairs(gconn(pair[2])) do
						total = total + 1
						if conn.Script == ac then mine = mine + 1 end
					end
					if total > 0 then w(string.format("  sig %s: %d conns (%d AC-owned)", pair[1], total, mine)) end
				end)
			end
		end

		pcall(function()
			local okT, th = pcall(getscriptthread, ac)
			if okT and th then w(string.format("  script thread: %s status=%s", tostring(th), tostring(coroutine.status(th)))) end
		end)
	end

	w("===== END SCAN =====")
	local report = table.concat(L, "\n")
	statusPush(report)
	local saved
	pcall(function()
		if type(writefile) == "function" then
			writefile("AutoParry_ACScan.txt", report); saved = "AutoParry_ACScan.txt"
		end
	end)
	pcall(function() if type(setclipboard) == "function" then setclipboard(report) end end)
	aclog(string.format("[AC] scan complete — %d lines%s%s", #L,
		saved and (" · saved " .. saved) or "",
		type(setclipboard) == "function" and " · copied to clipboard" or ""))
end

if Config.AntiCheatBypass then
	task.spawn(function()
		aclog("[AC] scanning for anticheat…")
		for _ = 1, 20 do
			pcall(muteAC)
			if State.acScript then break end
			task.wait(0.5)
		end
		pcall(neutralizeAC)
		if (State.acNeutralized or 0) > 0 then
			aclog(string.format("[AC] READY — %d report method(s) neutralized in GC%s; Kick+HTTP also blocked",
				State.acNeutralized, (State.acMuted or 0) > 0 and (" + " .. State.acMuted .. " conns muted") or ""))
		elseif (State.acMuted or 0) > 0 then
			aclog(string.format("[AC] READY — anticheat muted (%d connections disabled); Kick+HTTP reports also blocked", State.acMuted))
		elseif State.acScript then
			aclog("[AC] anticheat found but nothing muteable/neutralizable yet — Kick+HTTP report blocking still active")
		else
			aclog("[AC] anticheat script not found — Kick+HTTP report blocking still active as fallback")
		end
		pcall(function()
			local lp = Players.LocalPlayer
			if lp then lp.CharacterAdded:Connect(function()
				task.wait(0.5); pcall(muteAC)
			end) end
		end)
	end)
end

if Config.AntiCheatBypass and Config.AutoScanAC then
	task.spawn(function()
		task.wait(5)
		aclog("[AC] auto-running deep scan (also on key O)…")
		local ok, err = pcall(scanAC)
		if not ok then aclog("[AC] auto-scan ERROR: " .. tostring(err)) end
	end)
end

local classifyCombat = function(a)
	if type(a) ~= "table" or a.Type ~= "Combat" then return nil end
	if a.Action == "M1" or a.Action == "M2" then return "attack" end
	if a.Action == "Evasive" then return "dash" end
	return nil
end

local function desyncApplies(action)
	if action == "M1" then return Config.DesyncApplyM1 end
	if action == "M2" then return Config.DesyncApplyM2 end
	return false
end

local function desyncMag()
	local ms = Config.DesyncDelayMs or 0
	if ms < 0 then ms = 0 end
	return ms / 1000
end

local function captureIdleId(animator)
	local myHRP = localHRP()
	local speed = 0
	if myHRP then
		local v = myHRP.AssemblyLinearVelocity
		if v then speed = Vector3.new(v.X, 0, v.Z).Magnitude end
	end
	if speed > 3 then return _C.capturedIdleId end
	local best, bestW
	pcall(function()
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			local tid, looped, w = nil, false, 0
			pcall(function() tid = tonumber(tostring(t.Animation.AnimationId):match("(%d+)")) end)
			pcall(function() looped = t.Looped end)
			pcall(function() w = t.WeightCurrent end)
			if tid and looped and not _D.AttackIds[tid] then
				if not bestW or w > bestW then best, bestW = tid, w end
			end
		end
	end)
	if best then _C.capturedIdleId = best end
	return _C.capturedIdleId
end

local function getIdleDecoy(animator)
	local id = captureIdleId(animator) or Config.DesyncDecoyId or 507766388
	if _C.decoyId ~= id then
		_C.decoyId    = id
		_C.decoyTrack = nil
		pcall(function()
			_C.decoyAnim = Instance.new("Animation")
			_C.decoyAnim.AnimationId = "rbxassetid://" .. tostring(id)
		end)
	end
		if not _C.decoyTrack and _C.decoyAnim then
			pcall(function() _C.decoyTrack = animator:LoadAnimation(_C.decoyAnim) end)
			local owners = State.ap.trackOwners()
			if owners and _C.decoyTrack then owners[_C.decoyTrack] = { owner = "antiparry-idlemask" } end
		end
		return _C.decoyTrack
end

_D.SelfVerify = { conn = nil, lastLog = {}, decoyId = nil }

_D.DesyncTest = { on = false }
local toggleDesyncTest
do
local function pickAttackId()
	if Config.DesyncTestId then return Config.DesyncTestId end
	for id, e in pairs(_D.AttackIds) do
		if e and e.kind == "M1" then return id end
	end
	for id in pairs(_D.AttackIds) do return id end
	return 507766388
end
local function getTestDecoy(animator)
	local id = pickAttackId()
	if _C.testId ~= id then
		_C.testId, _C.testTrack = id, nil
		pcall(function()
			_C.testAnim = Instance.new("Animation")
			_C.testAnim.AnimationId = "rbxassetid://" .. tostring(id)
		end)
	end
		if not _C.testTrack and _C.testAnim then
			pcall(function() _C.testTrack = animator:LoadAnimation(_C.testAnim) end)
			local owners = State.ap.trackOwners()
			if owners and _C.testTrack then owners[_C.testTrack] = { owner = "antiparry-decoy" } end
		end
		return _C.testTrack, id
end
function toggleDesyncTest()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	_D.DesyncTest.on = not _D.DesyncTest.on
	if _D.DesyncTest.on then
		local track, id = getTestDecoy(animator)
		if not track then _D.DesyncTest.on = false; return end
		_D.SelfVerify.decoyId = "rbxassetid://" .. tostring(id)
		local topPrio = Enum.AnimationPriority.Action
		pcall(function() topPrio = Enum.AnimationPriority.Action4 end)
		local wgt = Config.DesyncClientVisible and 1 or 0.03
		pcall(function()
			track.Priority = topPrio
			track.Looped = true
			track:Play(0.1)
			track:AdjustWeight(wgt, 0)
		end)
		if _D.DesyncTest.conn then pcall(function() _D.DesyncTest.conn:Disconnect() end) end
		local autoEvery = 0.5
		pcall(function() local L = _C.testTrack.Length; if type(L) == "number" and L > 0.15 then autoEvery = L * 0.92 end end)
		local function replayInterval()
			local hz = tonumber(Config.DesyncSendHz) or 0
			if hz > 0 then return 1 / hz end
			return autoEvery
		end
		local nextReplay = os.clock() + replayInterval()
		_D.DesyncTest.conn = RunService.Heartbeat:Connect(function()
			if not _D.DesyncTest.on or not _C.testTrack then return end
			pcall(function()
				_C.testTrack.Priority = topPrio
				local nowc = os.clock()
				if nowc >= nextReplay or not _C.testTrack.IsPlaying then
					nextReplay = nowc + replayInterval()
					_C.testTrack:Stop(0)
					_C.testTrack:Play(0.05)
					_C.testTrack:AdjustWeight(wgt, 0)
				end
				if _C.testTrack.WeightCurrent < wgt * 0.5 then _C.testTrack:AdjustWeight(wgt, 0.1) end
			end)
		end)
	else
		if _D.DesyncTest.conn then pcall(function() _D.DesyncTest.conn:Disconnect() end); _D.DesyncTest.conn = nil end
		pcall(function() if _C.testTrack then _C.testTrack:Stop(0.1) end end)
	end
end
end
getgenv().AP_DESYNC_TEST = toggleDesyncTest

_D.DZ = {}
do
local function localAnimator()
	local ch = LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	return hum and hum:FindFirstChildOfClass("Animator")
end
local function topPriority()
	local p = Enum.AnimationPriority.Action
	pcall(function() p = Enum.AnimationPriority.Action4 end)
	return p
end
_D.IdleMask = { conn = nil }
local function stopIdleMask()
	if _D.IdleMask.conn then pcall(function() _D.IdleMask.conn:Disconnect() end); _D.IdleMask.conn = nil end
	pcall(function() if _C.decoyTrack then _C.decoyTrack:Stop(0.1) end end)
end
local function startIdleMask()
	if _D.IdleMask.conn then return end
	local animator = localAnimator()
	if not animator then aclog("[DESYNC:idlemask] нет аниматора (заспавнись)"); return end
	local track = getIdleDecoy(animator)
	if not track then aclog("[DESYNC:idlemask] idle-decoy не найде��"); return end
	local topPrio = topPriority()
	local wgt = Config.DesyncClientVisible and 1 or 0.92
	pcall(function() track.Priority = topPrio; track.Looped = true; track:Play(0.2); track:AdjustWeight(wgt, 0.1) end)
	_D.IdleMask.conn = RunService.Heartbeat:Connect(function()
		local an = localAnimator(); if not an then return end
		local tr = getIdleDecoy(an); if not tr then return end
		pcall(function()
			tr.Priority = topPrio
			if not tr.IsPlaying then
				tr.Looped = true
				tr:Play(0.2); tr:AdjustWeight(wgt, 0.1)
			elseif tr.WeightCurrent < wgt * 0.5 then
				tr:AdjustWeight(wgt, 0.1)
			end
		end)
	end)
	aclog("[desync] idlemask on")
end

_D.PreRun = { busyUntil = 0 }
local function firePreRunDecoy()
	local now = os.clock()
	if now < _D.PreRun.busyUntil then return end
	_D.PreRun.busyUntil = now + 0.22
	local animator = localAnimator(); if not animator then return end
	local track, id = getTestDecoy(animator); if not track then return end
	local topPrio = topPriority()
	local wgt = Config.DesyncClientVisible and 1 or 0.92
	local dur = (Config.DesyncDelayMs or 140) / 1000
	_D.SelfVerify.decoyId = "rbxassetid://" .. tostring(id)
	task.spawn(function()
		pcall(function() track.Priority = topPrio; track.Looped = false; track:Play(0.02); track:AdjustWeight(wgt, 0) end)
		task.wait(dur)
		pcall(function() track:Stop(0.05) end)
	end)
end

local function applyDesyncMode()
	stopIdleMask()
	if Config.DesyncAttack and Config.DesyncMode == "idlemask" then
		startIdleMask()
	end
end
_D.DESYNC_CYCLE = { "delay", "firedelay", "idlemask", "prerun" }
local function cycleDesyncMode()
	local cur, idx = Config.DesyncMode or "delay", 1
	for i, m in ipairs(_D.DESYNC_CYCLE) do if m == cur then idx = i break end end
	Config.DesyncMode = _D.DESYNC_CYCLE[(idx % #_D.DESYNC_CYCLE) + 1]
	applyDesyncMode()
	aclog(string.format("[desync] mode: %s%s", Config.DesyncMode, Config.DesyncAttack and "" or " (off)"))
end

_D.DZ.firePreRunDecoy = firePreRunDecoy
_D.DZ.applyDesyncMode = applyDesyncMode
_D.DZ.cycleDesyncMode = cycleDesyncMode
end
getgenv().AP_DESYNC_MODE = _D.DZ.cycleDesyncMode

_D.IV = {}
do
	local RS = RunService
	local function char()      return LocalPlayer.Character end
	local function humanoid()  local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
	local function rootOf()
		local c = char()
		return c and (c:FindFirstChild("HumanoidRootPart") or (humanoid() and humanoid().RootPart))
	end

	local Inv = { enabled = false, bindKey = nil, hb = nil, resp = nil, track = nil, oldcf = nil }

	local function playContort()
		if not Config.InvisibleAnim then return end
		local hum = humanoid(); if not hum then return end
		local animator = hum:FindFirstChildOfClass("Animator"); if not animator then return end
		local isR15 = hum.RigType == Enum.HumanoidRigType.R15
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. (isR15 and "18537363391" or "215384594")
		local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
		pcall(function() anim:Destroy() end)
		if ok and tr then
			Inv.track = tr
			pcall(function()
				tr.Priority = Enum.AnimationPriority.Action4
				tr:Play(0, 0.001, 0)
			end)
			task.delay(0, function() pcall(function() tr.TimePosition = isR15 and 0.77 or 0.38 end) end)
		end
	end

	local function stopInvisible()
		Inv.enabled = false
		if Inv.bindKey then pcall(function() RS:UnbindFromRenderStep(Inv.bindKey) end); Inv.bindKey = nil end
		if Inv.hb   then pcall(function() Inv.hb:Disconnect()   end); Inv.hb   = nil end
		if Inv.resp then pcall(function() Inv.resp:Disconnect() end); Inv.resp = nil end
		if Inv.track then pcall(function() Inv.track:Stop(); Inv.track:Destroy() end); Inv.track = nil end
		local r = rootOf()
		if r and Inv.oldcf then pcall(function() r.CFrame = Inv.oldcf end) end
		Inv.oldcf = nil
	end

	local function startInvisible()
		if Inv.enabled then return end
		Inv.enabled = true
		Inv.oldcf = nil
		playContort()

		Inv.bindKey = "AP_Invisible_" .. tostring(math.random(1e6, 9e6))
		pcall(function()
			RS:BindToRenderStep(Inv.bindKey, 0, function()
				local r = rootOf()
				if r and Inv.oldcf then
					r.CFrame = Inv.oldcf
					if Inv.track then pcall(function() Inv.track:AdjustWeight(0.001) end) end
				end
			end)
		end)

		Inv.hb = RS.Heartbeat:Connect(function()
			if not Inv.enabled then return end
			local r = rootOf(); local hum = humanoid()
			if not r or not hum then return end
			Inv.oldcf = r.CFrame
			local isR15 = hum.RigType == Enum.HumanoidRigType.R15
			local baseDrop = (hum.HipHeight or 2) + (r.Size.Y / 2) - 1
			local drop = baseDrop + (tonumber(Config.InvisibleHeight) or 0)
			local cf = r.CFrame - Vector3.new(0, drop, 0)
			pcall(function()
				r.CFrame = cf * CFrame.Angles(math.rad(isR15 and 180 or 90), 0, 0)
				if Inv.track then Inv.track:AdjustWeight(100) end
			end)
		end)

		Inv.resp = LocalPlayer.CharacterAdded:Connect(function()
			if not Config.InvisibleOn then return end
			task.wait(0.6)
			stopInvisible()
			if Config.InvisibleOn then startInvisible() end
		end)
	end

	function _D.IV.setInvisible(on)
		Config.InvisibleOn = on and true or false
		if Config.InvisibleOn then startInvisible() else stopInvisible() end
	end
end

_D.Observers = {}
local function observeOtherPlayer(name)
	local target = Players:FindFirstChild(name)
	if not target then
		aclog(string.format("[DESYNC-OBSERVE] игрок '%s' не найден рядом", tostring(name)))
		return
	end
	local last = {}
	local function hook(char)
		if not char then return end
		task.spawn(function()
			local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 8)
			local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 8))
			if not animator then return end
			if _D.Observers[name] then pcall(function() _D.Observers[name]:Disconnect() end) end
			_D.Observers[name] = animator.AnimationPlayed:Connect(function(track)
				pcall(function()
					local aid = track and track.Animation and track.Animation.AnimationId or "?"
					local now = os.clock()
					if (now - (last[aid] or 0)) < 0.25 then return end
					last[aid] = now
					local isAttack = _D.AttackIds and _D.AttackIds[aid] ~= nil
					local line = string.format("[OBSERVE %s] REPLICATED-TO-ME: id=%s %s prio=%s", name, tostring(aid), isAttack and "(=ATTACK id!)" or "(non-attack/idle)",
							tostring(track and track.Priority))
					aclog("[DESYNC-OBSERVE] " .. line)
					desyncPush(line)
				end)
			end)
			aclog(string.format("[DESYNC-OBSERVE] watching %s's animator — what THEY replicate to me is now logged (this is the enemy's-eye view)", name))
			desyncPush(string.format("[OBSERVE] started watching %s (enemy's-eye view of what replicates)", name))
		end)
	end
	hook(target.Character)
	target.CharacterAdded:Connect(hook)
end
getgenv().AP_OBSERVE = observeOtherPlayer

Players.PlayerRemoving:Connect(function(plr)
	local n = plr.Name
	local c = _D.Observers[n]
	if c then pcall(function() c:Disconnect() end); _D.Observers[n] = nil end
	if State.antiDecoySig then State.antiDecoySig[n] = nil end
	if Pending then Pending[n] = nil end
	if ComboState[n] ~= nil then
		ComboState[n] = nil
		ComboState._count = math.max((ComboState._count or 1) - 1, 0)
	end
end)

local function saveDesyncDebug()
	local header = table.concat({
		"===== AUTOPARRY DESYNC DEBUG (V75) =====",
		string.format("player=%s  mode=%s  DesyncAttack=%s  applyM1=%s applyM2=%s clientVisible=%s", LocalPlayer.Name, tostring(Config.DesyncMode), tostring(Config.DesyncAttack),
				tostring(Config.DesyncApplyM1), tostring(Config.DesyncApplyM2), tostring(Config.DesyncClientVisible)),
		string.format("raknet API present=%s  (add_send_hook=%s remove_send_hook=%s)", tostring(type(raknet) == "table"),
				tostring(type(raknet) == "table" and type(raknet.add_send_hook) == "function"),
				tostring(type(raknet) == "table" and type(raknet.remove_send_hook) == "function")),
		"legend: [SWING]=ServerCheck packet timing (SENT=immediate, HELD=delayed) | [DESYNC]=animation timing",
		"        [OBSERVE]=track seen on ANOTHER player's animator from a 2nd client (true enemy view)",
		"        [SCAN]=raknet outgoing-packet histogram (near=during my attacks, far=background)",
		"how to get the enemy-view lines: run this script on a 2nd account near your main,",
		"  then call getgenv().AP_OBSERVE(\"YourMainName\") and swing on the main.",
		"=========================================",
	}, "\n")
	local body = header .. "\n\n" .. table.concat(_D.DesyncLog, "\n") .. "\n"
	local fname = string.format("autoparry_desync_%d.txt", os.time() % 1000000)
	local ok = pcall(function() if writefile then writefile(fname, body) end end)
	if ok and writefile then
		aclog(string.format("[DESYNC] SAVED -> %s  (%d lines). Отправь мне этот файл.", fname, #_D.DesyncLog))
		if setclipboard then pcall(setclipboard, fname) end
	else
		aclog("[DESYNC] writefile unavailable — dumping debug to status log:")
		statusPush(body)
	end
	return fname
end
getgenv().AP_SAVE_DESYNC = saveDesyncDebug

_C.desyncBusyUntil = setmetatable({}, { __mode = "k" })
function AnimLib.desyncOwnTrack(track, id, animator)
	if not track then return end
	local entry = _D.AttackIds[id]
	if not entry then return end
	local kind = (entry.kind == "M2") and "M2" or "M1"
	if not desyncApplies(kind) then return end
	local now = os.clock()
	local busy = _C.desyncBusyUntil[track]
	if busy and now < busy then return end

	if (Config.DesyncMode or "delay") ~= "delay" then return end
	if track == _C.testTrack or track == _C.decoyTrack then return end
	if _D.DesyncTest.on then
		if (os.clock() - (State.lastAAPSkipLog or 0)) > 2 then
			State.lastAAPSkipLog = os.clock()
			aclog("[desync] anim-delay skipped �� anti-autoparry owns the anim channel (use firedelay instead)")
		end
		return
	end

	local window = (Config.DesyncDelayMs or 0) / 1000 + 0.05
	_C.desyncBusyUntil[track] = now + window

	local origSpeed = 1
	pcall(function() local s = track.Speed; if type(s) == "number" and s > 0.05 then origSpeed = s end end)
	State.desyncFires = (State.desyncFires or 0) + 1

	local animId = id
	local mag = desyncMag()
	pcall(function() track:Stop(0) end)
	task.delay(mag, function()
		pcall(function()
			track:Play(0)
			track:AdjustSpeed(origSpeed > 0 and origSpeed or 1)
		end)
	end)
	if (os.clock() - (State.lastDelayLog or 0)) > 0.15 then
		State.lastDelayLog = os.clock()
		aclog(string.format("[desync] %s anim held +%dms", kind, math.floor(mag * 1000)))
	end
end

task.spawn(function()
	local check = (type(checkcaller) == "function") and checkcaller or nil
	local function interceptFire(self, oldFire, ...)
		if self ~= ServerRemote then return oldFire(self, ...) end
		if (State.desyncPass or 0) > 0 then return oldFire(self, ...) end
		local mine = (check and check()) or false
		local a1 = select(1, ...)
		if mine then
			if type(a1) ~= "table" or a1.Action == "Block" then
				return oldFire(self, ...)
			end
		end
		local kind = classifyCombat(a1)
		if kind then
			if not State.combatFireSeen then
				State.combatFireSeen = true
				aclog(string.format("[desync] combat FireServer intercepted (%s/%s) — hook OK", tostring(a1.Action), tostring(a1.Func)))
			end
			local now = os.clock()
			if kind == "attack" then
				State.selfBusyUntil = now + Config.SelfBusyDur
				State.attackBusyUntil = now + Config.SelfBusyDur
				local func = a1.Func
				if Config.DesyncAttack and func == "ServerCheck"
				   and (Config.DesyncMode == "firedelay" or Config.DesyncMode == "prerun")
				   and desyncApplies(a1.Action) then
					if Config.DesyncMode == "prerun" then
						local firePre = _D.DZ and _D.DZ.firePreRunDecoy
						if firePre then firePre() end
					end
					local remote, packed, d = self, table.pack(...), desyncMag()
					task.delay(d, function()
						State.desyncPass = (State.desyncPass or 0) + 1
						remote:FireServer(table.unpack(packed, 1, packed.n))
						State.desyncPass = State.desyncPass - 1
					end)
					if (now - (State.lastSwingLog or 0)) > 0.15 then
						State.lastSwingLog = now
						aclog(string.format("[desync] %s send held +%dms", tostring(a1.Action), math.floor(d * 1000)))
					end
					return
				end
			elseif kind == "dash" then
				State.selfBusyUntil = now + Config.DashDuration
			end
		end
		return oldFire(self, ...)
	end

	local hooked = false
	if type(hookfunction) == "function" then
		local oldFire
		oldFire = hookfunction(ServerRemote.FireServer, function(self, ...)
			return interceptFire(self, oldFire, ...)
		end)
		if Config.BlockKick then
			pcall(function()
				hookfunction(LocalPlayer.Kick, function(self, ...)
					State.kicksBlocked = (State.kicksBlocked or 0) + 1
					diagPush("BYPASS  t=%.2f  blocked local Kick on %s", os.clock(), tostring(self.Name))
					aclog(string.format("[AC] !! KICK BLOCKED #%d — anticheat tried to Player:Kick() us; swallowed", State.kicksBlocked))
				end)
			end)
		end
		if Config.BlockACReports then
			local Http = game:GetService("HttpService")
			local function wrapHttp(methodName)
				local old
				old = hookfunction(Http[methodName], function(self, ...)
					local caller = (type(getcallingscript) == "function") and getcallingscript() or nil
					if caller and caller == State.acScript then
						State.reportsBlocked = (State.reportsBlocked or 0) + 1
						diagPush("BYPASS  t=%.2f  blocked AC HTTP %s", os.clock(), methodName)
						if State.reportsBlocked <= 3 or (os.clock() - (State.lastReportLog or 0)) > 5 then
							State.lastReportLog = os.clock()
							aclog(string.format("[AC] REPORT BLOCKED #%d — anticheat tried %s (detection phone-home); swallowed", State.reportsBlocked, methodName))
						end
						return
					end
					return old(self, ...)
				end)
			end
			pcall(wrapHttp, "PostAsync")
			pcall(wrapHttp, "RequestAsync")
			pcall(wrapHttp, "GetAsync")
		end
		hooked = true
		AnimLib.desyncHooked = true
		dbg("combat hook active (FireServer/Kick/HTTP, no __namecall)")
		aclog("[desync] hook=hookfunction (no global namecall)")
	end

	if not hooked and type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
		local NC_WATCHED = {
			FireServer = true, Kick = true,
			PostAsync = true, RequestAsync = true, GetAsync = true,
		}
		local nc_getMethod = getnamecallmethod
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", LPH_NO_VIRTUALIZE(function(self, ...)
			local method = nc_getMethod()
			if not NC_WATCHED[method] then return oldNamecall(self, ...) end
			if method == "FireServer" then
				return interceptFire(self, oldNamecall, ...)
			end
			if Config.BlockKick and method == "Kick" then
				if typeof(self) == "Instance" and self:IsA("Player") then
					State.kicksBlocked = (State.kicksBlocked or 0) + 1
					return
				end
			end
			if Config.BlockACReports
			   and (method == "PostAsync" or method == "RequestAsync" or method == "GetAsync") then
				local caller = (type(getcallingscript) == "function") and getcallingscript() or nil
				if caller and caller == State.acScript then
					State.reportsBlocked = (State.reportsBlocked or 0) + 1
					return
				end
			end
			return oldNamecall(self, ...)
		end))
		AnimLib.desyncHooked = true
		dbg("combat hook active (namecall fallback)")
		aclog("[desync] hook=namecall fallback")
	elseif not hooked then
		dbg("combat hook: no hookfunction/hookmetamethod — Guard/BlockKick/Desync disabled")
		aclog("[desync] no hook api")
	end
end)

local activeRestrictZone = LPH_NO_VIRTUALIZE(function(now)
	if not Config.RestrictZone then return nil end
	local best, bestC
	for _, th in ipairs(Threats) do
		if th.threatens and th.attackerHRP and th.attackerHRP.Parent then
			local isLong   = (not Config.RestrictLongOnly) or th.kind == "M2" or th.kind == "SKILL"
			local windupOK = (th.contact0 or 0) >= Config.RestrictMinWindup
			local future   = (th.contactAbs or 0) > now
			if isLong and windupOK and future then
				if not bestC or th.contactAbs < bestC then best, bestC = th, th.contactAbs end
			end
		end
	end
	if not best then return nil end
	local center, _forward, aPos, look = hitboxGeom(best)
	if not center then return nil end
	local radius = math.max(Config.HitboxDepth or 4, Config.HitHalfWidth or 3.2)
	return {
		center = center, keepOut = radius + Config.RestrictPad, radius = radius,
		aPos = aPos, look = look, th = best,
	}
end)

local restrictStep = LPH_NO_VIRTUALIZE(function(now)
	if not Config.RestrictZone then return end
	if #Threats == 0 then return end
	local hrp = localHRP(); if not hrp then return end
	if (now - State.lastDodge) < (Config.DashDuration + 0.05) then return end
	local z = activeRestrictZone(now); if not z then return end
	local pos  = hrp.Position
	local toC  = Vector3.new(z.center.X - pos.X, 0, z.center.Z - pos.Z)
	local dist = toC.Magnitude
	if dist < 0.05 or dist >= z.keepOut then return end
	local inward = toC.Unit
	local vel = hrp.AssemblyLinearVelocity
	local hv  = Vector3.new(vel.X, 0, vel.Z)
	local vin = hv:Dot(inward)
	if vin <= 0 then return end
	local newHV = hv - inward * vin
	hrp.AssemblyLinearVelocity = Vector3.new(newHV.X, vel.Y, newHV.Z)
	if not Config.RestrictSoft then
		local b = z.center - inward * z.keepOut
		hrp.CFrame = CFrame.new(Vector3.new(b.X, pos.Y, b.Z)) * (hrp.CFrame - hrp.CFrame.Position)
	end
end)

V93.schedulerPhase = RunService.PreSimulation and "PreSimulation" or "Heartbeat-fallback"
local frameHandler = LPH_NO_VIRTUALIZE(function(hbDt, source)
	local nowWall = os.clock()
	if (nowWall - (V93.lastStepClock or 0)) < 0.00045 then
		return
	end
	V93.lastStepClock = nowWall
	V93.schedulerSource = source or V93.schedulerPhase
	local wallDt = nowWall - (V93.lastWall or nowWall)
	V93.lastWall = nowWall
	local d
	if wallDt > 1e-4 and wallDt < 0.5 then
		d = math.clamp(wallDt, 1/480, 0.25)
	elseif type(hbDt) == "number" and hbDt > 0 then
		d = math.clamp(hbDt, 1/480, 0.25)
	end
	if d then
		V93.frameDt = V93.frameDt + (d - V93.frameDt) * 0.2
		if d > V93.frameDtPeak then
			V93.frameDtPeak = d
		else
			local hl = Config.FrameLookaheadPeakDecay or 1.10
			V93.frameDtPeak = V93.frameDtPeak + (d - V93.frameDtPeak) * math.clamp(d / hl, 0, 1)
		end
	end
	do
		local lowFps = (Config.LowFpsComp ~= false)
			and (V93.frameDt > ((Config.LowFpsFrameMs or 25) / 1000))
		V93.lowFps = lowFps
		local peakK = lowFps and (Config.LowFpsPeakK or 0.85)
			or (Config.FrameLookaheadPeakK or 0.5)
		local byEma  = V93.frameDt     * (Config.FrameLookahead or 0.5)
		local byPeak = V93.frameDtPeak * peakK
		local want   = (byEma > byPeak) and byEma or byPeak
		want = want + (V93.stepCost or 0) * (Config.FrameStepCostComp or 0.60)
		local cap = Config.FrameLookaheadCap or 0.045
		local capByPeak = V93.frameDtPeak * (Config.FrameLookaheadCapK or 0.75)
		if capByPeak > cap then cap = capByPeak end
		local capHi = lowFps and (Config.LowFpsCapHi or 0.13)
			or (Config.FrameLookaheadCapHi or 0.11)
		if cap > capHi then cap = capHi end
		V93.lookahead = (want < cap) and want or cap
	end
	if not Config.Enabled then
		if State.blocking then releaseBlock() end
		State.status = "OFF"
		return
	end
	local now = nowWall
	_C.FrameId = _C.FrameId + 1
	if _C.scanPlayingAttacks then _C.scanPlayingAttacks() end
	local wantSteer = State.ap.steerUntil and now < State.ap.steerUntil and State.ap.steerDir
	local wantDodgeSteer = State.ap.dodgeSteerUntil and now < State.ap.dodgeSteerUntil and State.ap.dodgeSteerDir
	if wantSteer or wantDodgeSteer then
		local c = localChar()
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum then
			if wantSteer then hum:Move(State.ap.steerDir, false) end
			if wantDodgeSteer then hum:Move(State.ap.dodgeSteerDir, false) end
		end
	end
	local stepT0 = os.clock()
	schedulerStep(now)
	local stepMs = os.clock() - stepT0
	V93.stepCost = V93.stepCost + (stepMs - V93.stepCost) * 0.15
	if Config.PerfProbe then
		if not V93.probeLast then V93.probeLast = now end
		if stepMs > (V93.probeStepPeak or 0) then V93.probeStepPeak = stepMs end
		local tn = #Threats
		if tn > (V93.probeThreatPeak or 0) then V93.probeThreatPeak = tn end
		V93.probeFrames = (V93.probeFrames or 0) + 1
		local elapsed = now - (V93.probeLast or now)
		if elapsed >= 1 then
			local inv = 1 / math.max(elapsed, 0.001)
			diagTrace("[perf] threats(peak)=%d | schedulerStep avg=%.2fms peak=%.2fms | willHitMe=%.0f/s GetPartBoundsInBox=%.0f/s | fps~%.0f src=%s",
				V93.probeThreatPeak or 0, (V93.stepCost or 0) * 1000, (V93.probeStepPeak or 0) * 1000,
				(V93.probeWHM or 0) * inv, (V93.probeGPBB or 0) * inv, (V93.probeFrames or 0) * inv,
				tostring(V93.schedulerSource or "?"))
			V93.probeLast = now
			V93.probeWHM, V93.probeGPBB, V93.probeStepPeak, V93.probeThreatPeak, V93.probeFrames = 0, 0, 0, 0, 0
		end
	end
	restrictStep(now)

	if State.guardUp and not State.blocking then
		sendDeactivate(true)
	end

	if _C.FrameId % 15 == 0 then
		for name, q in pairs(Pending) do
			for i = #q, 1, -1 do
				if now - q[i].clock > 3 then table.remove(q, i) end
			end
			if #q == 0 then Pending[name] = nil end
		end
	end

	if not State.blocking and State.status ~= "THREAT" then
		if now >= State.flashUntil then State.status = "ARMED" end
	end
	if nowWall - (V93.hrpSampleAt or 0) >= 0.05 then
		V93.hrpSampleAt = nowWall
		sampleNearbyHRPs()
	end
end)
;(RunService.PreSimulation or RunService.Heartbeat):Connect(LPH_NO_VIRTUALIZE(function(hbDt)
	frameHandler(hbDt, V93.schedulerPhase)
end))
if RunService.PreSimulation and Config.SchedulerWatchdog ~= false then
	RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function()
		local now = os.clock()
		local staleAfter = math.max((V93.frameDt or 1/60) * 1.85, 0.028)
		if (now - (V93.lastStepClock or 0)) > staleAfter then
			frameHandler(0, "Heartbeat-watchdog")
		end
	end))
end

local function summary()
	local t = State.tally
	local total = (t.PERFECT or 0)+(t.EARLY or 0)+(t.LATE or 0)+(t.GUARDBREAK or 0)
	local hits = (t.LATE or 0) + (t.GUARDBREAK or 0)
	local stateHits = State.stateHits or 0
	local realMiss = math.max(0, hits - stateHits)
	local blockable = total - stateHits
	local parryAcc = blockable > 0 and (100 * (t.PERFECT or 0) / blockable) or 0
	local acc = blockable > 0 and (100 * ((t.PERFECT or 0) + (t.EARLY or 0)) / blockable) or 0
	local rawAcc = total > 0 and (100 * (t.PERFECT or 0) / total) or 0
	-- V304: per-style M2 outcome buckets (kind:style → PERFECT/BLOCK/HIT/GB).
	-- "one M2 never times right" shows up here as a style with 0 PERFECT.
	local m2Buckets = {}
	do
		local mt = State.m2Tally
		if type(mt) == "table" then
			local keys = {}
			for k in pairs(mt) do keys[#keys + 1] = k end
			table.sort(keys)
			for _, k in ipairs(keys) do
				local b = mt[k]
				m2Buckets[#m2Buckets + 1] = string.format(
					"%s P%d/B%d/H%d/GB%d", k,
					b.PERFECT or 0, b.EARLY or 0, b.LATE or 0, b.GUARDBREAK or 0)
			end
		end
	end
	return table.concat({
		string.format("===== AUTOPARRY %s DIAG =====  (dumped %s UTC)", tostring(Config.Version or "?"), os.date("!%Y-%m-%d %H:%M:%S")),
		string.format("player=%s  ping=%.0fms(raw) %.0fms(med) %.0fms(gnpEma) jit=%.0fms jumps>20ms=%d  uplink=%.0fms  mode=%s  autoface=%s", LocalPlayer.Name, getPingRaw()*1000, getPing()*1000, (V93.gnpEma or 0)*1000, (V93.gnpJit or 0)*1000, V93.gnpJumps or 0, uplink()*1000, Config.Mode, tostring(Config.AutoFace)),
		string.format("scheduler: phase=%s src=%s fps=%.1f frame=%.1fms peak=%.1fms lookahead=%.1fms step=%.1fms lowFps=%s", tostring(V93.schedulerPhase or "?"), tostring(V93.schedulerSource or "?"), 1 / math.max(V93.frameDt or 1/60, 1/480),
			(V93.frameDt or 0)*1000, (V93.frameDtPeak or 0)*1000,
			(V93.lookahead or 0)*1000, (V93.stepCost or 0)*1000,
			V93.lowFps and "YES(aggressive)" or "no"),
		string.format("model: V216 wall + live rate (no min(wall,live) EARLY) | lead=%.0fms hold=%.0fms window=[%.0f,%.0f]ms", Config.PerfectLead*1000, Config.HoldAfter*1000, Config.PerfectMin*1000, Config.PerfectWindow*1000),
		string.format("outcomes: PERFECT=%d  BLOCK=%d  HIT=%d  GUARDBREAK=%d  total=%d", t.PERFECT or 0, t.EARLY or 0, t.LATE or 0, t.GUARDBREAK or 0, total),
		"M2 by style: " .. (#m2Buckets > 0 and table.concat(m2Buckets, " | ") or "none"),
		string.format("attacks=%d  presses=%d  dodges=%d  outnumbered-escapes=%d  desync-anims=%d  ac-muted=%d  kicks-blocked=%d  reports-blocked=%d", State.parryCount, State.fireCount, State.dodgeCount, State.grantEscapes or 0, State.desyncFires or 0, State.acMuted or 0, State.kicksBlocked or 0, State.reportsBlocked or 0),
		string.format("HIT breakdown: %d total → %d game-state-locked (stun/attack/cooldown, unblockable) + %d real timing miss", hits, stateHits, realMiss),
		string.format("landed = %.1f%%  (%d/%d PERFECT of all outcomes) | blockable-only = %.1f%% (%d/%d) | block-inclusive = %.1f%%", rawAcc, t.PERFECT or 0, total, parryAcc, t.PERFECT or 0, blockable, acc),
		string.format("off-target swings rejected=%d  |  boxing-counter fired=%d  |  dodges skipped by counter i-frames=%d", State.offTargetRej or 0, State.counterCount or 0,
			State.counterCoverSkips or 0),
		string.format("fresh-keep=%d  poll-detect=%d  decoy-drop=%d  lastSkip=%s  diag=%d/%d", State.decoyFreshKeep or 0, State.pollDetect or 0, State.decoyDropped or 0, tostring(State.lastAnimSkip or "-"), #_D.DiagLog, _D.DIAG_MAX),
		"=============================",
	}, "\n")
end

Config.RingA       = Config.RingA       or Color3.fromRGB(196, 158, 255)
Config.RingB       = Config.RingB       or Color3.fromRGB(122, 214, 255)
Config.ConeSafe    = Config.ConeSafe    or Color3.fromRGB(96, 214, 140)
Config.ConeHit     = Config.ConeHit     or Color3.fromRGB(255, 84, 84)
Config.RestrictCol = Config.RestrictCol or Color3.fromRGB(255, 72, 72)

local vizUpdate, vizHideAll
local RING_SEG  = 24
local CONE_SEG  = 12
local CONE_FILL = 0.32
local VIZ_CONE_HALF = math.rad(64)
local VIZ_CONE_PAD  = 5.0
local VIEW_DIST = 100

-- Luraph VM does not always see executor globals via GETGLOBAL. Drawing lives on getgenv().
-- Nested `pcall(function() ln = Drawing.new(...) end)` also fails to write the upvalue
-- after obfuscation, so the pool latches ok=false and visuals stay dark forever.
-- This pipeline is module-scope (not a `do` block): Luraph remaps `do`-block upvalues
-- poorly, so wrapping vizUpdate while it still lived in `do` made drawings vanish.
local drawingLib = LPH_NO_VIRTUALIZE(function()
	local genv = getgenv and getgenv()
	return (genv and genv.Drawing) or rawget(_G, "Drawing") or Drawing
end)
local drawingNew = LPH_NO_VIRTUALIZE(function(kind)
	local D = drawingLib()
	if not (D and D.new) then return nil end
	local ok, obj = pcall(D.new, kind)
	if ok then return obj end
	return nil
end)

local LinePool = { items = {}, used = 0, ok = true }
LinePool.begin = LPH_NO_VIRTUALIZE(function(self) self.used = 0 end)
LinePool.get = LPH_NO_VIRTUALIZE(function(self)
	self.used = self.used + 1
	local ln = self.items[self.used]
	if ln then return ln end
	ln = drawingNew("Line")
	if not ln then
		self.used = self.used - 1
		self.ok = false
		return nil
	end
	self.ok = true
	self.items[self.used] = ln
	return ln
end)
LinePool.finish = LPH_NO_VIRTUALIZE(function(self)
	local hidden = self.hiddenTo or #self.items
	for i = self.used + 1, hidden do self.items[i].Visible = false end
	self.hiddenTo = self.used
end)
LinePool.hideAll = LPH_NO_VIRTUALIZE(function(self)
	for _, ln in ipairs(self.items) do ln.Visible = false end
	self.used, self.hiddenTo = 0, 0
end)

local TriPool = { items = {}, used = 0, ok = true }
TriPool.begin = LPH_NO_VIRTUALIZE(function(self) self.used = 0 end)
TriPool.get = LPH_NO_VIRTUALIZE(function(self)
	self.used = self.used + 1
	local tr = self.items[self.used]
	if tr then return tr end
	tr = drawingNew("Triangle")
	if not tr then
		self.used = self.used - 1
		self.ok = false
		return nil
	end
	self.ok = true
	tr.Filled = true
	self.items[self.used] = tr
	return tr
end)
TriPool.finish = LPH_NO_VIRTUALIZE(function(self)
	local hidden = self.hiddenTo or #self.items
	for i = self.used + 1, hidden do self.items[i].Visible = false end
	self.hiddenTo = self.used
end)
TriPool.hideAll = LPH_NO_VIRTUALIZE(function(self)
	for _, tr in ipairs(self.items) do tr.Visible = false end
	self.used, self.hiddenTo = 0, 0
end)

vizHideAll = LPH_NO_VIRTUALIZE(function() LinePool:hideAll(); TriPool:hideAll() end)

local Viz = { t = 0 }

local NEAR = 0.6

Viz.rotY = LPH_NO_VIRTUALIZE(function(v, ang)
	local c, s = math.cos(ang), math.sin(ang)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end)

Viz.projRaw = LPH_NO_VIRTUALIZE(function(cam, world)
	local sp = cam:WorldToViewportPoint(world)
	return sp.X, sp.Y, sp.Z
end)

Viz.proj = LPH_NO_VIRTUALIZE(function(cam, world)
	local x, y, z = Viz.projRaw(cam, world)
	return Vector2.new(x, y), z
end)

Viz.drawWorldSeg = LPH_NO_VIRTUALIZE(function(cam, a, b, color, thick)
	local ax, ay, az = Viz.projRaw(cam, a)
	local bx, by, bz = Viz.projRaw(cam, b)
	if az <= NEAR and bz <= NEAR then return end
	if az <= NEAR or bz <= NEAR then
		local t = (NEAR - az) / (bz - az)
		local mx, my = Viz.projRaw(cam, a:Lerp(b, t))
		if az <= NEAR then ax, ay = mx, my else bx, by = mx, my end
	end
	local ln = LinePool:get(); if not ln then return end
	ln.From, ln.To = Vector2.new(ax, ay), Vector2.new(bx, by)
	ln.Color, ln.Thickness, ln.Transparency, ln.Visible = color, thick, 1, true
end)

Viz.pickTarget = LPH_NO_VIRTUALIZE(function()
	-- Nearest enemy always. vizTarget is the swinging attacker — user
	-- wants rings on whoever is closest, not only the one mid-swing.
	local nowc = os.clock()
	if Viz.pickCacheHrp and Viz.pickCacheHrp.Parent and (nowc - (Viz.pickCacheT or 0)) < 0.15 then
		return Viz.pickCacheModel, Viz.pickCacheHrp
	end
	local me = localHRP(); if not me then return nil end
	local best, bestHrp, bestD = nil, nil, (Config.VizRange or VIEW_DIST)
	for _, p in ipairs(Players:GetPlayers()) do
		local ch = p.Character
		if ch then
			local ok, hrp = isEnemyModel(ch)
			if ok and hrp then
				local d = (hrp.Position - me.Position).Magnitude
				if d < bestD then best, bestHrp, bestD = ch, hrp, d end
			end
		end
	end
	Viz.pickCacheModel, Viz.pickCacheHrp, Viz.pickCacheT = best, bestHrp, nowc
	return best, bestHrp
end)

Viz.bboxRaw = LPH_NO_VIRTUALIZE(function(m) return m:GetBoundingBox() end)
Viz.bbModel, Viz.bbClock, Viz.bbC, Viz.bbS = nil, -1, nil, nil
Viz.ringPts = {}
Viz.coneW   = {}
Viz.cone2d  = {}
Viz.coneZ   = {}
Viz.bboxOf = LPH_NO_VIRTUALIZE(function(model)
	local nowc = os.clock()
	if model == Viz.bbModel and (nowc - Viz.bbClock) < 0.004 then return Viz.bbC, Viz.bbS end
	local ok, c, s = pcall(Viz.bboxRaw, model)
	if ok and typeof(c) == "CFrame" and typeof(s) == "Vector3" then
		Viz.bbModel, Viz.bbClock, Viz.bbC, Viz.bbS = model, nowc, c, s
		return c, s
	end
	return nil
end)

Viz.ribbonQuad = LPH_NO_VIRTUALIZE(function(cam, a, b, c, d, color, transp)
	local ax, ay, az = Viz.projRaw(cam, a)
	local bx, by, bz = Viz.projRaw(cam, b)
	local cx, cy, cz = Viz.projRaw(cam, c)
	local dx, dy, dz = Viz.projRaw(cam, d)
	if az <= 0 or bz <= 0 or cz <= 0 or dz <= 0 then return end
	local a2, b2 = Vector2.new(ax, ay), Vector2.new(bx, by)
	local c2, d2 = Vector2.new(cx, cy), Vector2.new(dx, dy)
	local t1 = TriPool:get()
	if t1 then
		t1.PointA, t1.PointB, t1.PointC = a2, b2, c2
		t1.Color, t1.Transparency, t1.Visible = color, transp, true
	end
	local t2 = TriPool:get()
	if t2 then
		t2.PointA, t2.PointB, t2.PointC = a2, c2, d2
		t2.Color, t2.Transparency, t2.Visible = color, transp, true
	end
end)

Viz.gradLUT, Viz.gradA, Viz.gradB = {}, nil, nil
Viz.grad = LPH_NO_VIRTUALIZE(function(a, b, f)
	if Viz.gradA ~= a or Viz.gradB ~= b then
		Viz.gradA, Viz.gradB = a, b
		local lut = Viz.gradLUT
		for i = 0, 32 do lut[i] = a:Lerp(b, i / 32) end
	end
	local i = f * 32 + 0.5
	i = (i < 0 and 0) or (i > 32 and 32) or (i // 1)
	return Viz.gradLUT[i]
end)

Viz.drawRing = LPH_NO_VIRTUALIZE(function(cam, model, hrp, hot)
	local footY = hrp.Position.Y - 2.8
	local radius = 3.2
	local bc, bs = Viz.bboxOf(model)
	if bc and bs then
		footY  = bc.Y - bs.Y * 0.5 + 0.08
		radius = math.clamp(math.max(bs.X, bs.Z) * 0.75, 2.4, 6)
	end
	radius = radius * (Config.VizRingScale or 1.0)
	local spd   = Config.VizRingSpeed or 1.0
	local style = Config.VizRingStyle or "Flat"
	local seg   = math.clamp(math.floor(Config.VizRingSeg or 30), 8, 48)
	local t     = Viz.t * spd
	local cx, cz = hrp.Position.X, hrp.Position.Z

	if style ~= "Orbit" and style ~= "OrbitSwirl" then
		local pulse = 1 + math.sin(t * 3.0) * 0.05
		local wpts = Viz.ringPts
		for i = 0, seg - 1 do
			local a = i / seg * math.pi * 2
			local r = radius * pulse * (1 + math.sin(a * 4 + t * 5) * 0.03)
			wpts[i] = Vector3.new(cx + math.cos(a) * r, footY, cz + math.sin(a) * r)
		end
		local thick = hot and 4 or 2.5
		for i = 0, seg - 1 do
			local j = (i + 1) % seg
			local f = 0.5 + 0.5 * math.sin(i / seg * math.pi * 2 + t * 2.2)
			Viz.drawWorldSeg(cam, wpts[i], wpts[j], Viz.grad(Config.RingA, Config.RingB, f), thick)
		end
		return
	end

	local bodyY = footY + ((bs and bs.Y or 5) * 0.5)
	local swirl = (style == "OrbitSwirl") and (t * 0.75) or 0
	local tilt  = Config.VizRingTilt or 0.7
	local rIn   = radius * 0.985

	for i = 0, seg - 1 do
		local a1 = (i / seg) * math.pi * 2 + swirl
		local a2 = ((i + 1) / seg) * math.pi * 2 + swirl
		local dy = math.cos(t + (i / seg) * math.pi * 2) * tilt
		local f  = 0.5 + 0.5 * math.sin((i / seg) * math.pi * 2 + t * 2.2)
		local col = Viz.grad(Config.RingA, Config.RingB, f)

		local y = bodyY + dy
		local c1, s1 = math.cos(a1), math.sin(a1)
		local c2, s2 = math.cos(a2), math.sin(a2)
		Viz.ribbonQuad(cam,
			Vector3.new(cx + c1 * rIn,    y, cz + s1 * rIn),
			Vector3.new(cx + c2 * rIn,    y, cz + s2 * rIn),
			Vector3.new(cx + c2 * radius, y, cz + s2 * radius),
			Vector3.new(cx + c1 * radius, y, cz + s1 * radius), col, 1)

		if Config.VizRingMirror ~= false then
			local ym = bodyY - dy
			local rMid = (rIn + radius) * 0.5
			Viz.drawWorldSeg(cam,
				Vector3.new(cx + math.cos(-a1) * rMid, ym, cz + math.sin(-a1) * rMid),
				Vector3.new(cx + math.cos(-a2) * rMid, ym, cz + math.sin(-a2) * rMid),
				Viz.grad(Config.RingA, Config.RingB, 1 - f), hot and 3 or 2)
		end
	end
end)

Viz.footYOf = LPH_NO_VIRTUALIZE(function(model, hrp)
	local y = hrp.Position.Y - 2.8
	local bc, bs = Viz.bboxOf(model)
	if bc and bs then y = bc.Y - bs.Y * 0.5 + 0.05 end
	return y
end)
Viz.drawTargetHitbox = LPH_NO_VIRTUALIZE(function(cam, model, hrp)
	local look = hrp.CFrame.LookVector
	local flook = Vector3.new(look.X, 0, look.Z)
	if flook.Magnitude < 0.05 then return end
	flook = flook.Unit

	local style = styleOf(model)
	local styleReach = math.max(styleForward(style, "M1"), styleForward(style, "M2"))
	local reach = styleReach + VIZ_CONE_PAD
	local half  = VIZ_CONE_HALF
	local y = Viz.footYOf(model, hrp)
	local origin = Vector3.new(hrp.Position.X, y, hrp.Position.Z)

		local col = Config.ConeSafe
		local me  = localHRP()
		if me then
			local forward = styleReach
			local off  = Vector3.new(me.Position.X - hrp.Position.X, 0, me.Position.Z - hrp.Position.Z)
			local fwd  = off:Dot(flook)
			local side = math.abs(off:Dot(Vector3.new(-flook.Z, 0, flook.X)))
			local slack = Config.HitboxSlack or 0
			if fwd >= (forward - Config.HitboxDepthBack - slack) and fwd <= (forward + Config.HitboxDepth + slack)
			   and side <= (Config.HitHalfWidth + slack) then
				col = Config.ConeHit
			end
		end

	local wArc = Viz.coneW
	for i = 0, CONE_SEG do
		local ang = -half + (i / CONE_SEG) * (half * 2)
		wArc[i] = origin + Viz.rotY(flook, ang) * reach
	end
	local o2d, oz = Viz.proj(cam, origin)
	local a2d, az = Viz.cone2d, Viz.coneZ
	for i = 0, CONE_SEG do a2d[i], az[i] = Viz.proj(cam, wArc[i]) end
	for i = 0, CONE_SEG - 1 do
		if oz > NEAR and az[i] > NEAR and az[i + 1] > NEAR then
			local tr = TriPool:get()
			if tr then
				tr.PointA, tr.PointB, tr.PointC = o2d, a2d[i], a2d[i + 1]
				tr.Color, tr.Transparency, tr.Filled, tr.Visible = col, CONE_FILL, true, true
			end
		end
	end
	Viz.drawWorldSeg(cam, origin, wArc[0], col, 2)
	Viz.drawWorldSeg(cam, origin, wArc[CONE_SEG], col, 2)
	for i = 0, CONE_SEG - 1 do Viz.drawWorldSeg(cam, wArc[i], wArc[i + 1], col, 2) end
end)

Viz.drawRestrictZone = LPH_NO_VIRTUALIZE(function(cam)
	if not (Config.RestrictZone and Config.RestrictShowZone) then return end
	local z = activeRestrictZone(os.clock()); if not z then return end
	local aHRP = z.th.attackerHRP; if not (aHRP and aHRP.Parent) then return end
	local y  = Viz.footYOf(z.th.attackerModel, aHRP)
	local cx, cz = z.center.X, z.center.Z
	local r  = z.keepOut * (1 + math.sin(Viz.t * 4) * 0.02)
	local center3 = Vector3.new(cx, y, cz)

	local bracket = math.rad(34)
	for k = 0, 3 do
		local mid = math.rad(45) + k * math.rad(90)
		local a0, a1 = mid - bracket / 2, mid + bracket / 2
		local prev
		for i = 0, 7 do
			local a = a0 + (a1 - a0) * (i / 7)
			local p = Vector3.new(cx + math.cos(a) * r, y, cz + math.sin(a) * r)
			if prev then Viz.drawWorldSeg(cam, prev, p, Config.RestrictCol, 3) end
			prev = p
		end
	end

	local ch = math.max(r * 0.14, 0.7)
	Viz.drawWorldSeg(cam, Vector3.new(cx - ch, y, cz), Vector3.new(cx + ch, y, cz), Config.RestrictCol, 2)
	Viz.drawWorldSeg(cam, Vector3.new(cx, y, cz - ch), Vector3.new(cx, y, cz + ch), Config.RestrictCol, 2)

	if z.aPos then
		local from = Vector3.new(z.aPos.X, y, z.aPos.Z)
		local dir  = Vector3.new(cx - z.aPos.X, 0, cz - z.aPos.Z)
		if dir.Magnitude > 0.1 then
			local edge = center3 - dir.Unit * r
			Viz.drawWorldSeg(cam, from, edge, Config.RestrictCol, 1.5)
		end
	end
end)

vizUpdate = LPH_NO_VIRTUALIZE(function(dt)
	local cam = Workspace.CurrentCamera
	if not (Config.Enabled and Config.ShowVisuals and cam) then vizHideAll(); return end
	local nowc = os.clock()
	local maxFps = Config.VizMaxFPS or 30
	if maxFps > 0 and (nowc - (Viz.lastDraw or 0)) < (1 / maxFps) then return end
	Viz.lastDraw = nowc
	Viz.t = Viz.t + dt

	local skipLim = Config.VizSkipNearPress or 0.20
	if skipLim > 0
	   and (nowc - (V93.nearPressStamp or 0)) < 0.20
	   and math.abs(V93.nearPress or math.huge) < skipLim
	   and (Viz.skipRun or 0) < (Config.VizSkipMaxFrames or 2) then
		Viz.skipRun = (Viz.skipRun or 0) + 1
		return
	end
	Viz.skipRun = 0

	LinePool:begin(); TriPool:begin()
	local model, hrp = Viz.pickTarget()
	publishVizTarget(model, hrp)
	if model and hrp then
		local hot = (State.status == "PARRY" or State.status == "DODGE")
		if Config.VizHitbox ~= false then Viz.drawTargetHitbox(cam, model, hrp) end
		if Config.VizRing ~= false then Viz.drawRing(cam, model, hrp, hot) end
	end
	if Config.VizRestrict ~= false then Viz.drawRestrictZone(cam) end
	LinePool:finish(); TriPool:finish()
end)

local applyFacing = LPH_NO_VIRTUALIZE(function()
	local goalPos = State.faceGoalPos
	local goalHRP = State.faceGoalHRP
	if not (goalHRP or goalPos) and not State.faceHum then return end
	local ec = localChar()
	local equipped = ec and ec:GetAttribute("Equip")
	if not (goalHRP or goalPos) or os.clock() > (State.faceGoalUntil or 0)
	   or (goalHRP and not goalHRP.Parent)
	   or (Config.RequireEquip ~= false and not equipped) then
		if State.faceHum then State.faceHum.AutoRotate = true; State.faceHum = nil end
		State.faceGoalHRP = nil
		State.faceGoalPos = nil
		return
	end
	if not Config.AutoFace then return end
	local myHRP = localHRP()
	if not myHRP then return end
	local myPos = myHRP.Position
	local hum = ec and ec:FindFirstChildOfClass("Humanoid")
	if (Config.RotationMethod or "LookAt") ~= "AimLock" then
		if hum and hum.AutoRotate then hum.AutoRotate = false; State.faceHum = hum end
	elseif State.faceHum then
		State.faceHum.AutoRotate = true; State.faceHum = nil
	end
	local aimPos = goalPos or (goalHRP and goalHRP.Position)
	if not aimPos then return end
	local lead   = math.clamp(getPing() * (Config.FacePingLead or 1.0), 0, Config.FaceLeadCap or 0.28)
	if lead > 0 and goalHRP then
		local vel = goalHRP.AssemblyLinearVelocity
		if vel then
			local flatVel = Vector3.new(vel.X, 0, vel.Z)
			local gp = goalHRP.Position
			local toMe = Vector3.new(myPos.X - gp.X, 0, myPos.Z - gp.Z)
			if toMe.Magnitude > 0.05 then
				local axis     = toMe.Unit
				local radialVec = axis * flatVel:Dot(axis)
				local latVec    = flatVel - radialVec
				local latOff = latVec * lead
				local latCap = Config.FaceLatMaxStuds or 18
				if latOff.Magnitude > latCap then latOff = latOff.Unit * latCap end
				local radOff = radialVec * lead
				local radCap = Config.FaceRadMaxStuds or 5
				if radOff.Magnitude > radCap then radOff = radOff.Unit * radCap end
				aimPos = aimPos + latOff + radOff
			else
				local off = flatVel * lead
				local mx  = Config.FaceLeadMaxStuds or 16
				if off.Magnitude > mx then off = off.Unit * mx end
				aimPos = aimPos + off
			end
		end
	end
	local d = flatDirTo(myPos, aimPos)
	if not d then return end

	if (Config.RotationMethod or "LookAt") == "AimLock" then
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local cp = cam.CFrame.Position
		local target = aimPos + Vector3.new(0, 1.2, 0)
		local goalCam = CFrame.lookAt(cp, target)
		if State.faceGoalHard then
			cam.CFrame = goalCam
		else
			cam.CFrame = cam.CFrame:Lerp(goalCam, math.clamp(Config.AimLockLerp or 0.35, 0.05, 1))
		end
		return
	end

	local goal = CFrame.lookAt(myPos, myPos + d)
	if State.faceGoalHard then
		myHRP.CFrame = goal
	else
		myHRP.CFrame = myHRP.CFrame:Lerp(goal, Config.FaceLerp or 0.8)
	end
end)

RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt)
	if not (Config.Enabled and Config.ShowVisuals) then return end
	vizUpdate(dt)
end))

RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function()
	applyFacing()
end))

indexAllAnims()
task.spawn(function()
	local anims = ReplicatedStorage:WaitForChild("Animations", 90)
	local combat = anims and anims:WaitForChild("Combat", 90)
	if not combat then return end
	indexAllAnims()
	if _C.animWatch then return end
	_C.animWatch = true
	combat.DescendantAdded:Connect(function(d)
		if d.ClassName == "Animation" or d.ClassName == "Folder" then
			indexAllAnims()
		end
	end)
end)
loadGameModules()
scanAnimators()
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then hookAnimator(animator) end
	end)
end)
task.spawn(function()
	while true do task.wait(8); scanAnimators() end
end)

return function(_Lib, _Core)
	local M = {}

	function M.start()
		Config.Enabled     = false
		Config.DesyncAttack = false
		if _D.DesyncTest.on then pcall(toggleDesyncTest) end
	end

	function M.buildUI(ctx)
		local uiReady = false
		local function notify(title, body)
			if uiReady then pcall(ctx.notify, title, body) end
		end

		local function feature(section, o)
			local guard, togEl = false, nil
			local function commit(val)
				val = val and true or false
				o.set(val)
				notify(o.Title, val and "Enabled" or "Disabled")
				guard = true
				if togEl then pcall(function() togEl:UpdateState(val) end) end
				guard = false
			end
			togEl = section:Toggle({
				Name    = "Enabled",
				Default = o.get(),
				Callback = function(v)
					if guard then return end
					commit(v)
				end,
			}, ctx.flag(o.Flag))
			if o.Desc then section:SubLabel({ Text = o.Desc }) end
			ctx.keybind(section, {
				Name = "Keybind",
				Flag = ctx.flag(o.Flag .. "_KB"),
				Toggle = function() commit(not o.get()) end,
			})
			return { commit = commit }
		end

		local function boolToggle(section, name, title, get, set)
			local guard, togEl = false, nil
			togEl = section:Toggle({
				Name = name, Default = get(),
				Callback = function(v)
					if guard then return end
					set(v and true or false)
					notify(title, v and "Enabled" or "Disabled")
				end,
			}, ctx.flag(name:gsub("%s+", "") .. "_T"))
			return togEl
		end

		local function slider(section, o)
			return section:Slider({
				Name = o.Name, Default = o.Default, Minimum = o.Min, Maximum = o.Max,
				Precision = o.Precision or 0, Suffix = o.Suffix,
				Callback = o.Callback,
			}, ctx.flag(o.Flag))
		end

		local AP = ctx.tabs.AutoParry

		local apMain = AP:Section({ Side = "Left" })

		apMain:Header({ Name = "AutoParry" })
		feature(apMain, {
			Title = "AutoParry", Flag = "AP_Enabled",
			get = function() return Config.Enabled end,
			set = function(v)
				Config.Enabled = v
				if not v then pcall(releaseBlock); pcall(vizHideAll) end
			end,
			Desc = "Parries incoming attacks.",
		})

		apMain:Divider()
		apMain:Header({ Name = "Whitelist" })
		do
			local function wlNames()
				local t = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= LocalPlayer then
						t[#t + 1] = p.Name
					end
				end
				table.sort(t)
				return t
			end
			local function wlSelectedList()
				local d, w = {}, Config.ParryWhitelist
				if type(w) == "table" then
					for name, on in pairs(w) do
						if on == true then d[#d + 1] = name end
					end
				end
				return d
			end
			local function applyWl(sel)
				local t = {}
				if type(sel) == "table" then
					for k, v in pairs(sel) do
						if v == true and type(k) == "string" then
							t[k] = true
						elseif type(v) == "string" then
							t[v] = true
						end
					end
				end
				Config.ParryWhitelist = t
			end
			local wlDrop = apMain:Dropdown({
				Name = "Friends",
				Options = wlNames(),
				Multi = true,
				Search = true,
				Default = wlSelectedList(),
				ForceAutoLoad = true,
				Callback = function(sel)
					applyWl(sel)
				end,
			}, ctx.flag("AP_ParryWL"))
			apMain:SubLabel({ Text = "Ignores these players." })
			apMain:Button({
				Name = "Clear all",
				Callback = function()
					Config.ParryWhitelist = {}
					pcall(function() wlDrop:UpdateSelection({}) end)
					notify("Whitelist", "Cleared")
				end,
			})
			local function refreshWl()
				pcall(function()
					wlDrop:ClearOptions()
					wlDrop:InsertOptions(wlNames())
					local keep = wlSelectedList()
					if #keep > 0 then wlDrop:UpdateSelection(keep) end
				end)
			end
			Players.PlayerAdded:Connect(function()
				task.defer(refreshWl)
			end)
			Players.PlayerRemoving:Connect(function(plr)
				local w = Config.ParryWhitelist
				if type(w) == "table" and plr then
					w[plr.Name] = nil
				end
				task.defer(refreshWl)
			end)
		end

		apMain:Divider()
		apMain:Header({ Name = "Detection" })
		slider(apMain, { Name = "FOV", Flag = "AP_FOV", Default = Config.FOV or 360,
			Min = 1, Max = 360, Suffix = "°", Callback = function(v) Config.FOV = v end })
		apMain:SubLabel({ Text = "Only reacts inside this cone. 360 is all around." })
		slider(apMain, { Name = "Range", Flag = "AP_Range", Default = Config.Range or 32,
			Min = 8, Max = 64, Suffix = " st", Callback = function(v) Config.Range = v end })
		slider(apMain, { Name = "Max Height Diff", Flag = "AP_MaxHeight", Default = Config.MaxHeightDiff or 8,
			Min = 4, Max = 40, Suffix = " st", Callback = function(v) Config.MaxHeightDiff = v end })
		apMain:SubLabel({ Text = "Ignores enemies above or below this height." })
		boolToggle(apMain, "Server Proof", "Server Proof",
			function() return Config.ServerProofGate ~= false end,
			function(v) Config.ServerProofGate = v end)
		apMain:SubLabel({ Text = "Only parries server-confirmed swings." })
		slider(apMain, { Name = "Proof Grace", Flag = "AP_ProofGrace",
			Default = math.floor((Config.ProofGraceSec or 0.06) * 1000),
			Min = 20, Max = 150, Suffix = " ms",
			Callback = function(v) Config.ProofGraceSec = v / 1000 end })
		apMain:SubLabel({ Text = "Wait time for server confirmation." })
		apMain:Divider()
		apMain:Header({ Name = "Time Spoof" })
		boolToggle(apMain, "Time Spoof", "Time Spoof",
			function() return Config.TimeSpoof == true end,
			function(v) Config.TimeSpoof = v end)
		apMain:SubLabel({ Text = "Shifts the parry timestamp earlier." })
		slider(apMain, { Name = "Back-date", Flag = "AP_TimeShift",
			Default = Config.TimeShiftMs or 40,
			Min = 0, Max = 120, Suffix = " ms",
			Callback = function(v) Config.TimeShiftMs = v end })
		apMain:SubLabel({ Text = "How far back to shift the timestamp." })

		apMain:Divider()
		apMain:Header({ Name = "Rotation" })
		feature(apMain, {
			Title = "Auto Face", Flag = "AP_AutoFace",
			get = function() return Config.AutoFace end,
			set = function(v) Config.AutoFace = v end,
			Desc = "Turns you toward the attacker.",
		})
		local aimEls = {}
		local function rotVis()
			local isAim = (Config.RotationMethod or "LookAt") == "AimLock"
			for _, el in ipairs(aimEls) do pcall(function() el:SetVisibility(isAim) end) end
		end
		apMain:Dropdown({
			Name = "Method",
			Options = { "LookAt", "AimLock" },
			Default = Config.RotationMethod or "LookAt",
			Callback = function(v)
				if type(v) == "string" and v ~= "" then Config.RotationMethod = v; rotVis() end
			end,
		}, ctx.flag("AP_RotMethod"))
		apMain:SubLabel({ Text = "LookAt turns the character. AimLock turns the camera." })
		aimEls[#aimEls + 1] = slider(apMain, { Name = "Aim Speed", Flag = "AP_AimLockLerp",
			Default = math.floor((Config.AimLockLerp or 0.35) * 100), Min = 5, Max = 100, Suffix = "%",
			Callback = function(v) Config.AimLockLerp = v / 100 end })
		rotVis()
		boolToggle(apMain, "Instant Multi-Target Snap", "Multi Snap",
			function() return Config.MultiFaceHard end, function(v) Config.MultiFaceHard = v end)
		apMain:SubLabel({ Text = "Snaps to the next attacker in a group." })
		boolToggle(apMain, "Hard Snap Near Contact", "Hard Snap", function() return Config.BlockFaceHard end, function(v) Config.BlockFaceHard = v end)
		apMain:SubLabel({ Text = "Snaps onto the attacker before contact." })
		slider(apMain, { Name = "Rotation Speed", Flag = "AP_FaceLerp",
			Default = Config.FaceLerp or 0.80, Min = 0.10, Max = 1.00, Precision = 2,
			Callback = function(v) Config.FaceLerp = v end })

		local apDodge = AP:Section({ Side = "Right" })

		apDodge:Header({ Name = "Dodge" })
		feature(apDodge, {
			Title = "Auto Dodge", Flag = "AP_AutoDodge",
			get = function() return Config.AutoDodge ~= false end,
			set = function(v) Config.AutoDodge = v end,
			Desc = "Dodges instead of blocking when enabled.",
		})
		local aggroEls = {}
		local function aggroVis()
			local on = (Config.DodgeMode or "Defensive") == "Aggressive"
			for _, el in ipairs(aggroEls) do pcall(function() el:SetVisibility(on) end) end
		end
		apDodge:Dropdown({
			Name = "Dodge Mode",
			Options = { "Defensive", "Aggressive" },
			Default = Config.DodgeMode or "Defensive",
			Callback = function(v)
				if type(v) == "string" and v ~= "" then Config.DodgeMode = v; aggroVis() end
			end,
		}, ctx.flag("AP_DodgeMode"))
		apDodge:SubLabel({ Text = "Defensive rolls away. Aggressive circles in." })
		aggroEls[#aggroEls + 1] = slider(apDodge, { Name = "Aggro Close-In", Flag = "AP_DodgeAggroClose",
			Default = math.floor((Config.DodgeAggroClose or 0.45) * 100), Min = 0, Max = 100, Suffix = "%",
			Callback = function(v) Config.DodgeAggroClose = v / 100 end })
		apDodge:SubLabel({ Text = "How hard Aggressive dodge closes distance." })
		aggroVis()
		boolToggle(apDodge, "Dodge All Heavies", "Dodge All Heavies",
			function() return Config.DodgeHeavy end, function(v) Config.DodgeHeavy = v end)
		apDodge:SubLabel({ Text = "Dodges M2 when you cannot block." })
		boolToggle(apDodge, "Dodge If Cant Parry", "Dodge If Cant Parry",
			function() return Config.DodgeOnParryCooldown ~= false end,
			function(v) Config.DodgeOnParryCooldown = v end)
		apDodge:SubLabel({ Text = "Dodges when parry is on cooldown." })

		apDodge:Divider()
		apDodge:Header({ Name = "Dodge Tuning" })
		slider(apDodge, { Name = "Dodge Reaction (lead)", Flag = "AP_DodgeLead",
			Default = math.floor((Config.DodgeLead or 0.10) * 1000), Min = 40, Max = 300,
			Suffix = " ms", Callback = function(v) Config.DodgeLead = v / 1000 end })
		apDodge:SubLabel({ Text = "How early to dodge before contact." })
		slider(apDodge, { Name = "Dodge Speed", Flag = "AP_DashSpeed", Default = Config.DashSpeed or 30,
			Min = 10, Max = 90, Suffix = " st/s", Callback = function(v) Config.DashSpeed = v end })
		slider(apDodge, { Name = "i-Frame Window", Flag = "AP_IFrame",
			Default = math.floor((Config.IFrameDur or 0.30) * 1000), Min = 120, Max = 500,
			Suffix = " ms", Callback = function(v) Config.IFrameDur = v / 1000 end })

		apDodge:Divider()
		apDodge:Header({ Name = "Must-Dodge List" })
		do
			local STYLES = {
			"Default","Basic","Boxing","Bulky","Dirty","Hakari","Karate","Kure",
			"MuayThai","SkyGaoLang","Variant","Taekwondo","Wild","WingChun",
			"Wrestling","Capoeira","Slugger","Striker","Ali","CQC","Judo",
			"Jin","Mishima","Lethwei","Kyokushin","Kickboxing",
			"Taijutsu","Aikido","Hikaken","Giovanna","PerfectCopy",
			"Senbonzakura","Hyoga",
			}
			local KINDS = { { label = "M1", key = "M1" }, { label = "M2 (Heavy)", key = "M2" } }
			local mdOptions, mdDefault = {}, {}
			for _, s in ipairs(STYLES) do
				local saved = Config.MustDodgeStyles and Config.MustDodgeStyles[s:lower()]
				for _, k in ipairs(KINDS) do
					local opt = s .. " / " .. k.label
					mdOptions[#mdOptions + 1] = opt
					if saved and (saved[k.key] or saved.all) then
						mdDefault[#mdDefault + 1] = opt
					end
				end
			end
			apDodge:Dropdown({
				Name = "Must-Dodge Attacks", Options = mdOptions, Multi = true, Search = true,
				Default = mdDefault,
				Callback = function(sel)
					local t, n = {}, 0
					for label, on in pairs(sel) do
						if on then
							local st, kindLabel = label:match("^(.-) / (.+)$")
							if st and kindLabel then
								local key = (kindLabel == "M1" and "M1")
									or (kindLabel == "M2 (Heavy)" and "M2")
								if key then
									st = st:lower()
									t[st] = t[st] or {}
									t[st][key] = true
									n = n + 1
								end
							end
						end
					end
					Config.MustDodgeStyles = t
					notify("Must-Dodge", "Selected: " .. n .. " attack(s)")
				end,
			}, ctx.flag("AP_MustDodge"))
			apDodge:SubLabel({ Text = "Dodges these attacks instead of blocking." })
		end

		local apBox = AP:Section({ Side = "Left" })

		apBox:Header({ Name = "Skill Addons" })
		feature(apBox, {
			Title = "Skill Addons", Flag = "AP_SkillAddon",
			get = function() return Config.SkillAddon end,
			set = function(v) Config.SkillAddon = v end,
			Desc = "Enables the style options below.",
		})

		apBox:Divider()
		apBox:Header({ Name = "Boxing" })
		boolToggle(apBox, "Boxing Counter", "Boxing Counter",
			function() return Config.BoxingCounter end, function(v) Config.BoxingCounter = v end)
		apBox:SubLabel({ Text = "On Boxing, counters with M2 instead of parrying." })
		slider(apBox, { Name = "Counter Range", Flag = "AP_CounterReach",
			Default = Config.BoxingCounterReach or 5.5,
			Min = 3, Max = 12, Precision = 1, Suffix = " studs",
			Callback = function(v) Config.BoxingCounterReach = v end })
		apBox:SubLabel({ Text = "Max distance for Boxing Counter." })

		apBox:Divider()
		apBox:Header({ Name = "Ali" })
		boolToggle(apBox, "Ali Counter", "Ali Counter",
			function() return Config.AliCounter end, function(v) Config.AliCounter = v end)
		slider(apBox, { Name = "Ali Counter Range", Flag = "AP_AliCounterReach",
			Default = Config.AliCounterReach or 7.5,
			Min = 3, Max = 14, Precision = 1, Suffix = " studs",
			Callback = function(v) Config.AliCounterReach = v end })
		boolToggle(apBox, "Ali Evasive Counter", "Ali Evasive Counter",
			function() return Config.AliEvasiveCounter end, function(v) Config.AliEvasiveCounter = v end)
		boolToggle(apBox, "Ali Dodge Abuse", "Ali Dodge Abuse",
			function() return Config.AliDodgeAbuse end, function(v) Config.AliDodgeAbuse = v end)
		slider(apBox, { Name = "Ali Rotation Hold", Flag = "AP_AliFaceLockDur",
			Default = math.floor((Config.AliFaceLockDur or 0.75) * 1000),
			Min = 200, Max = 1400, Suffix = " ms",
			Callback = function(v) Config.AliFaceLockDur = v / 1000 end })
		apBox:SubLabel({ Text = "Dodges then fires Ali evasive-counter M2." })
		apBox:Dropdown({
			Name = "Ali M2 Variant",
			Options = { "Right", "Left" },
			Default = Config.AliM2Variant or "Left",
			Callback = function(v)
				if type(v) == "string" and v ~= "" then Config.AliM2Variant = v end
			end,
		}, ctx.flag("AP_AliM2Variant"))

		apBox:Divider()
		apBox:Header({ Name = "Wing Chun" })
		boolToggle(apBox, "Wing Chun Counter", "Wing Chun Counter",
			function() return Config.WingChunCounter end,
			function(v) Config.WingChunCounter = v end)
		apBox:SubLabel({ Text = "On Wing Chun, holds counter stance instead of attacking." })
		slider(apBox, { Name = "Wing Chun Counter Range", Flag = "AP_WCReach",
			Default = Config.WingChunCounterReach or 6.5,
			Min = 3, Max = 14, Precision = 1, Suffix = " studs",
			Callback = function(v) Config.WingChunCounterReach = v end })
		slider(apBox, { Name = "Window Aim Point", Flag = "AP_WCAimFrac",
			Default = math.floor((Config.WCAimFrac or 0.35) * 100),
			Min = 10, Max = 80, Suffix = " %",
			Callback = function(v) Config.WCAimFrac = v / 100 end })
		apBox:SubLabel({ Text = "When in the counter window to fire." })
		boolToggle(apBox, "WC Require Live Track", "WC Require Live Track",
			function() return Config.WCRequireLiveTrack ~= false end,
			function(v) Config.WCRequireLiveTrack = v end)
		boolToggle(apBox, "WC Solo Threat Only", "WC Solo Threat Only",
			function() return Config.WCSoloOnly ~= false end,
			function(v) Config.WCSoloOnly = v end)
		apBox:SubLabel({ Text = "Only uses the stance against one attacker." })
		boolToggle(apBox, "WC Skip Grabs", "WC Skip Grabs",
			function() return Config.WCSkipGrabs ~= false end,
			function(v) Config.WCSkipGrabs = v end)

		apBox:Divider()
		apBox:Header({ Name = "Aikido" })
		boolToggle(apBox, "Aikido Counter", "Aikido Counter",
			function() return Config.AikidoCounter end,
			function(v) Config.AikidoCounter = v end)
		apBox:SubLabel({ Text = "On Aikido, counters incoming attacks with M2." })
		slider(apBox, { Name = "Aikido Counter Range", Flag = "AP_AikidoReach",
			Default = Config.AikidoCounterReach or 6.5,
			Min = 3, Max = 14, Precision = 1, Suffix = " studs",
			Callback = function(v) Config.AikidoCounterReach = v end })
		apBox:SubLabel({ Text = "Max distance for Aikido Counter." })

		apBox:Divider()
		apBox:Header({ Name = "Counter" })
		boolToggle(apBox, "Counter Instead Of Dodge", "Counter Instead Of Dodge",
			function() return Config.CounterPreemptsDodge ~= false end,
			function(v) Config.CounterPreemptsDodge = v end)
		apBox:SubLabel({ Text = "Uses counter when it already covers the hit." })

		apBox:Divider()
		apBox:Header({ Name = "Anti-Grab" })
		boolToggle(apBox, "Wrestling Anti-Grab", "Wrestling Anti-Grab",
			function() return Config.SA_WrestlingGrab end, function(v) Config.SA_WrestlingGrab = v end)
		apBox:SubLabel({ Text = "Dodges Wrestling grabs." })
		boolToggle(apBox, "Dirty Anti-Grab", "Dirty Anti-Grab",
			function() return Config.SA_DirtyGrab end, function(v) Config.SA_DirtyGrab = v end)
		apBox:SubLabel({ Text = "Dodges Dirty grabs." })
		boolToggle(apBox, "CQC Ring Dodge", "CQC Ring Dodge",
			function() return Config.SA_CQCRingDodge ~= false end, function(v) Config.SA_CQCRingDodge = v end)
		apBox:SubLabel({ Text = "Dodges CQC ring M2." })
		boolToggle(apBox, "Wrestling Punish M2", "Wrestling Punish M2",
			function() return Config.SA_WrestlingPunishM2 == true end, function(v) Config.SA_WrestlingPunishM2 = v end)
		apBox:SubLabel({ Text = "After a perfect parry, punishes with Wrestling M2." })

		apBox:Divider()
		apBox:Header({ Name = "Force-Dodge (client)" })
		boolToggle(apBox, "Blatant Force-Dodge", "Blatant Force-Dodge",
			function() return Config.SA_BlatantDodge end, function(v) Config.SA_BlatantDodge = v end)
		apBox:SubLabel({ Text = "Dodges even when the server rejects it." })
		slider(apBox, { Name = "Force-Dodge Window", Flag = "AP_SABlatantWin",
			Default = math.floor((Config.SA_BlatantWindow or 0.32) * 1000), Min = 150, Max = 500, Suffix = " ms",
			Callback = function(v) Config.SA_BlatantWindow = v / 1000 end })

		local apPlay = AP:Section({ Side = "Left" })

		apPlay:Header({ Name = "AutoPlay" })
		feature(apPlay, {
			Title = "AutoPlay", Flag = "AP_AutoPlay",
			get = function() return Config.AutoPlay end,
			set = function(v) Config.AutoPlay = v end,
			Desc = "Automatically attacks nearby enemies.",
		})

		apPlay:Divider()
		apPlay:Header({ Name = "Behaviour" })
		boolToggle(apPlay, "Reliable Attacks", "Reliable Attacks",
			function() return Config.AP_ForceNativeM1 ~= false end, function(v) Config.AP_ForceNativeM1 = v end)
		apPlay:SubLabel({ Text = "Uses the game M1 to attack." })
		boolToggle(apPlay, "Punish After Parry", "Punish After Parry",
			function() return Config.AP_PunishOnParry ~= false end, function(v) Config.AP_PunishOnParry = v end)
	apPlay:SubLabel({ Text = "Attacks NPCs after your parry stuns them." })
	boolToggle(apPlay, "Smooth Swings", "Smooth Swings",
		function() return Config.AP_AnimGuard ~= false end,
		function(v) Config.AP_AnimGuard = v end)
	apPlay:SubLabel({ Text = "Keeps the swing animation from restarting." })
	boolToggle(apPlay, "Counter Interrupt", "Counter Interrupt",
		function() return Config.AP_Interrupt == true end, function(v) Config.AP_Interrupt = v end)
	apPlay:SubLabel({ Text = "Attacks instead of parrying when your hit lands first." })
	boolToggle(apPlay, "Interrupt With M2", "Interrupt With M2",
		function() return Config.AP_InterruptM2 ~= false end, function(v) Config.AP_InterruptM2 = v end)
	apPlay:SubLabel({ Text = "Allows interrupt to use M2." })
	boolToggle(apPlay, "Prefer M2", "Prefer M2",
		function() return Config.AP_InterruptPreferM2 ~= false end, function(v) Config.AP_InterruptPreferM2 = v end)
	apPlay:SubLabel({ Text = "Uses M2 for interrupt when both are in time." })
	slider(apPlay, { Name = "Interrupt M2 Range", Flag = "AP_M2BaseReach",
		Default = Config.AP_M2BaseReach or 6.5,
		Min = 3, Max = 14, Precision = 1, Suffix = " studs",
		Callback = function(v) Config.AP_M2BaseReach = v end })
	apPlay:SubLabel({ Text = "Max distance for interrupt M2." })

	apPlay:Divider()
			apPlay:Header({ Name = "Combo" })
			apPlay:Dropdown({
				Name = "Combo Mode",
				Options = { "Follow", "Fixed" },
				Default = Config.AP_ComboMode or "Follow",
				Callback = function(v)
					Config.AP_ComboMode = v
					notify("Combo Mode", "Selected: " .. tostring(v))
				end,
			}, ctx.flag("AP_ComboMode"))
			apPlay:SubLabel({ Text = "Follow uses the full combo. Fixed repeats one hit." })
			slider(apPlay, { Name = "Fixed Combo Hit", Flag = "AP_FixedHit", Default = Config.AP_FixedHit or 1,
				Min = 1, Max = 4, Callback = function(v) Config.AP_FixedHit = v end })
			apPlay:SubLabel({ Text = "Which combo hit to use in Fixed mode." })
			apPlay:Button({
				Name = "Test Swing",
				Callback = function()
					local combo, ok = State.ap.testSwing()
					if ok then
						notify("Test Swing", "sent M1 hit #" .. tostring(combo)
							.. (Config.AP_ComboMode == "Fixed" and " (Fixed)" or " (next in combo)"))
					else
						notify("Test Swing", "could not swing (equip weapon / rate-limited / M1 not resolved)")
					end
				end,
			})
			apPlay:SubLabel({ Text = "Sends one M1 now." })

		apPlay:Divider()
			apPlay:Header({ Name = "Tuning" })
			slider(apPlay, { Name = "M1 Rate", Flag = "AP_MaxPerSec", Default = Config.AP_MaxPerSec or 6,
				Min = 3, Max = 8, Suffix = " /s", Callback = function(v) Config.AP_MaxPerSec = v end })
			apPlay:SubLabel({ Text = "Attacks per second while punishing." })
			slider(apPlay, { Name = "M1 Reach", Flag = "AP_BaseReach", Default = Config.AP_BaseReach or 5.5,
				Min = 3, Max = 10, Precision = 1, Suffix = " st", Callback = function(v) Config.AP_BaseReach = v end })
	apPlay:SubLabel({ Text = "M1 attack range." })

		local apVis = AP:Section({ Side = "Right" })

		apVis:Header({ Name = "Visuals" })
		feature(apVis, {
			Title = "Visuals", Flag = "AP_ShowVisuals",
			get = function() return Config.ShowVisuals end,
			set = function(v)
				Config.ShowVisuals = v
				if not v then pcall(vizHideAll) end
			end,
			Desc = "Shows AutoParry drawings.",
		})

		apVis:Divider()
		apVis:Header({ Name = "What To Draw" })
		boolToggle(apVis, "Target Ring", "Target Ring",
			function() return Config.VizRing end,
			function(v) Config.VizRing = v; if not v then pcall(vizHideAll) end end)
		boolToggle(apVis, "Attack Cone", "Attack Cone",
			function() return Config.VizHitbox end,
			function(v) Config.VizHitbox = v; if not v then pcall(vizHideAll) end end)
		apVis:SubLabel({ Text = "Shows the attacker's reach." })
		boolToggle(apVis, "Keep-Out Zone", "Keep-Out Zone",
			function() return Config.VizRestrict end,
			function(v) Config.VizRestrict = v; if not v then pcall(vizHideAll) end end)

		apVis:Divider()
		apVis:Header({ Name = "Ring" })
		local ringOrbitEls, ringSwirlEls = {}, {}
		local function ringVis()
			local st = Config.VizRingStyle or "Flat"
			local isOrbit = (st == "Orbit" or st == "OrbitSwirl")
			for _, el in ipairs(ringOrbitEls) do pcall(function() el:SetVisibility(isOrbit) end) end
			for _, el in ipairs(ringSwirlEls) do pcall(function() el:SetVisibility(st == "OrbitSwirl") end) end
		end
		apVis:Dropdown({
			Name = "Style",
			Options = { "Flat", "Orbit", "OrbitSwirl" },
			Default = Config.VizRingStyle or "Flat",
			Callback = function(v)
				if type(v) == "string" and v ~= "" then Config.VizRingStyle = v; ringVis() end
			end,
		}, ctx.flag("AP_VizRingStyle"))
		apVis:SubLabel({ Text = "How the target ring is drawn." })
		slider(apVis, { Name = "Size", Flag = "AP_VizRingScale",
			Default = math.floor((Config.VizRingScale or 1) * 100), Min = 40, Max = 250, Suffix = "%",
			Callback = function(v) Config.VizRingScale = v / 100 end })
		slider(apVis, { Name = "Speed", Flag = "AP_VizRingSpeed",
			Default = math.floor((Config.VizRingSpeed or 1) * 100), Min = 10, Max = 300, Suffix = "%",
			Callback = function(v) Config.VizRingSpeed = v / 100 end })
		slider(apVis, { Name = "Smoothness", Flag = "AP_VizRingSeg",
			Default = Config.VizRingSeg or 30, Min = 8, Max = 48, Suffix = "",
			Callback = function(v) Config.VizRingSeg = v end })
		ringOrbitEls[#ringOrbitEls + 1] = slider(apVis, { Name = "Depth", Flag = "AP_VizRingTilt",
			Default = math.floor((Config.VizRingTilt or 0.7) * 100), Min = 10, Max = 200, Suffix = "%",
			Callback = function(v) Config.VizRingTilt = v / 100 end })
		ringOrbitEls[#ringOrbitEls + 1] = boolToggle(apVis, "Mirror Band", "Ring Mirror",
			function() return Config.VizRingMirror ~= false end,
			function(v) Config.VizRingMirror = v end)
		ringVis()
		apVis:Colorpicker({ Name = "Color A", Default = Config.RingA,
			Callback = function(c) Config.RingA = c end }, ctx.flag("AP_RingA"))
		apVis:Colorpicker({ Name = "Color B", Default = Config.RingB,
			Callback = function(c) Config.RingB = c end }, ctx.flag("AP_RingB"))

		apVis:Divider()
		apVis:Header({ Name = "Cone & Zone Colors" })
		apVis:Colorpicker({ Name = "Cone (safe)", Default = Config.ConeSafe,
			Callback = function(c) Config.ConeSafe = c end }, ctx.flag("AP_ConeSafe"))
		apVis:Colorpicker({ Name = "Cone (in range)", Default = Config.ConeHit,
			Callback = function(c) Config.ConeHit = c end }, ctx.flag("AP_ConeHit"))
		apVis:Colorpicker({ Name = "Keep-Out", Default = Config.RestrictCol,
			Callback = function(c) Config.RestrictCol = c end }, ctx.flag("AP_Restrict"))

		apVis:Divider()
		apVis:Header({ Name = "Performance" })
		slider(apVis, { Name = "Draw Distance", Flag = "AP_VizRange",
			Default = Config.VizRange or 100, Min = 20, Max = 250, Suffix = " st",
			Callback = function(v) Config.VizRange = v end })

		local DS = ctx.tabs.Desync

		local dsSelf = DS:Section({ Side = "Left" })
		dsSelf:Header({ Name = "Anti AutoParry" })
		feature(dsSelf, {
			Title = "Anti AutoParry", Flag = "DS_Test",
			get = function() return _D.DesyncTest.on end,
			set = function(v)
				if (_D.DesyncTest.on and true or false) ~= v then pcall(toggleDesyncTest) end
			end,
			Desc = "Sends fake swings while you move.",
		})
		slider(dsSelf, { Name = "Send Frequency", Flag = "DS_SendHz", Default = Config.DesyncSendHz or 0,
			Min = 0, Max = 20, Suffix = " Hz", Callback = function(v) Config.DesyncSendHz = v end })
		dsSelf:SubLabel({ Text = "Fake swing sends per second. 0 is automatic." })
		boolToggle(dsSelf, "Client Visible", "Desync Client Visible",
			function() return Config.DesyncClientVisible end,
			function(v) Config.DesyncClientVisible = v end)

		local dsAtk = DS:Section({ Side = "Right" })
		dsAtk:Header({ Name = "Attack Desync" })
		feature(dsAtk, {
			Title = "Attack Desync", Flag = "DS_Attack",
			get = function() return Config.DesyncAttack end,
			set = function(v) Config.DesyncAttack = v end,
			Desc = "Desyncs your attacks.",
		})
		dsAtk:Dropdown({
			Name = "Desync Mode", 			Options = { "delay", "firedelay", "idlemask", "prerun" },
			Default = Config.DesyncMode or "delay",
			Callback = function(v)
				Config.DesyncMode = v
				pcall(function() if _D.DZ and _D.DZ.applyDesyncMode then _D.DZ.applyDesyncMode() end end)
				notify("Desync Mode", "Selected: " .. tostring(v))
			end,
		}, ctx.flag("DS_Mode"))
		dsAtk:SubLabel({ Text = "How attack desync is applied." })
		slider(dsAtk, { Name = "Desync Delay", Flag = "DS_Delay", Default = Config.DesyncDelayMs or 140,
			Min = 40, Max = 400, Suffix = " ms", Callback = function(v) Config.DesyncDelayMs = v end })
		boolToggle(dsAtk, "Apply to M1", "Desync M1", function() return Config.DesyncApplyM1 end, function(v) Config.DesyncApplyM1 = v end)
		boolToggle(dsAtk, "Apply to M2", "Desync M2", function() return Config.DesyncApplyM2 end, function(v) Config.DesyncApplyM2 = v end)

		local dsInv = DS:Section({ Side = "Left" })
		dsInv:Header({ Name = "Invisible" })
		feature(dsInv, {
			Title = "Invisible", Flag = "DS_Invisible",
			get = function() return Config.InvisibleOn end,
			set = function(v) pcall(function() _D.IV.setInvisible(v) end) end,
			Desc = "Hides your character from other players.",
		})
		slider(dsInv, { Name = "Invisible Height", Flag = "DS_InvHeight", Default = Config.InvisibleHeight or 0,
			Min = 0, Max = 15, Suffix = " studs", Callback = function(v) Config.InvisibleHeight = v end })
		dsInv:SubLabel({ Text = "How far underground to hide." })
		boolToggle(dsInv, "Contort Anim", "Invisible Anim",
			function() return Config.InvisibleAnim end, function(v) Config.InvisibleAnim = v end)

		local DB = ctx.tabs.Debug

		local dbLog = DB:Section({ Side = "Left" })
		dbLog:Header({ Name = "Combat Debug" })
		local verboseEl
		boolToggle(dbLog, "Combat Debug", "Combat Debug",
			function() return Config.Debug end,
			function(v)
				applyCombatDebug(v)
				if not v then
					Config.TraceDiag = false
					if verboseEl then pcall(function() verboseEl:UpdateState(false) end) end
				end
			end)
		dbLog:SubLabel({ Text = "Logs combat events." })
		verboseEl = boolToggle(dbLog, "Verbose Trace", "Verbose Trace",
			function() return Config.TraceDiag end,
			function(v)
				Config.TraceDiag = v and Config.Debug and true or false
				Config.PerfProbe = Config.TraceDiag and true or false
			end)
		dbLog:SubLabel({ Text = "Logs swing geometry and timing." })
		dbLog:Divider()
		dbLog:Header({ Name = "Status Log" })
		local statusPara = dbLog:Paragraph({ Header = "Live events", Body = "—" })
		local function renderStatus()
			local src = Config.Debug and _D.DiagLog or _D.StatusLog
			local n = #src
			if n == 0 then
				statusPara:UpdateBody(Config.Debug and "No combat events yet." or "No events yet.")
				return
			end
			local shown = math.min(16, n)
			local out = { string.format("Showing %d of %d (newest first):", shown, n), "" }
			for i = n, n - shown + 1, -1 do
				out[#out + 1] = "• " .. tostring(src[i])
			end
			statusPara:UpdateBody(table.concat(out, "\n"))
		end
		renderStatus()
		dbLog:Button({ Name = "Refresh", Callback = renderStatus })
		dbLog:Button({ Name = "Clear", Callback = function()
			table.clear(_D.StatusLog)
			table.clear(_D.DiagLog)
			table.clear(_D.TraceLog)
			statusPara:UpdateBody(Config.Debug and "No combat events yet." or "No events yet.")
		end })
		task.spawn(function()
			while statusPara do
				task.wait(Config.Debug and 0.75 or 2.5)
				pcall(renderStatus)
			end
		end)

		local dbDiag = DB:Section({ Side = "Right" })
		dbDiag:Header({ Name = "Diagnostics" })
		local copyDiag = false
		dbDiag:Button({
			Name = "Save AutoParry diag",
			Callback = function()
				local body  = summary() .. "\n\n" .. table.concat(_D.DiagLog, "\n")
				if _D.TraceLog and #_D.TraceLog > 0 then
					body = body .. "\n\n===== VERBOSE TRACE =====\n" .. table.concat(_D.TraceLog, "\n")
				end
				body = body .. "\n"
				local fname = string.format("autoparry_diag_%d.txt", os.time() % 1000000)
				local wrote = pcall(function() if writefile then writefile(fname, body) end end) and (writefile ~= nil)
				if copyDiag and type(setclipboard) == "function" then
					pcall(setclipboard, body)
				end
				if wrote then
					notify("Diagnostics", (copyDiag and "Saved + copied: " or "Saved: ") .. fname)
				elseif copyDiag and type(setclipboard) == "function" then
					notify("Diagnostics", "writefile unavailable — copied log to clipboard")
				else
					notify("Diagnostics", "writefile/clipboard unavailable")
				end
			end,
		})
		boolToggle(dbDiag, "Copy", "Diag Copy",
			function() return copyDiag end,
			function(v) copyDiag = v end)

		task.defer(function() uiReady = true end)
	end

	return M
end
