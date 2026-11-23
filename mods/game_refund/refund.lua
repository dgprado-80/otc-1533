-- Season refund UI. Server remains authoritative for all balances and claims.
local OPCODE = (ExtendedIds and ExtendedIds.Refund) or 228

local window
local currentLang = 'en'
local lastMessage = nil
local lastMessageError = false
local loadingTimeoutEvent = nil
local state = {
  pointsTotal = 0,
  pointsRemaining = 0,
  passportDays = 0,
  nextClaimAt = 0,
  maxPointsPerClaim = 1000,
  cooldownDays = 5,
  available = false,
}

local STRINGS = {
  en = {
    windowTitle = 'Season Refund',
    subtitle = 'Claim Premium Points and Best Partner Passport days from the previous season.',
    pointsTitle = 'Premium Points',
    passportTitle = 'Best Partner Passport',
    claimPoints = 'Claim points',
    claimPassport = 'Claim days',
    close = 'Close',
    langButton = 'PT-BR',
    langTooltip = 'Switch to Portuguese',
    loading = 'Loading current refund information...',
    ready = 'Refund data updated.',
    loadTimeout = 'Could not refresh refund data. Close and open again, or try Claim.',
    requestingPoints = 'Requesting Premium Points refund...',
    requestingPassport = 'Requesting Best Partner Passport days...',
    noPoints = 'No Premium Points are available for refund.',
    pointsReady = '%d points available. You can claim %d points now.',
    pointsWait = '%d points available. Next claim in %s.',
    noPassport = 'No Best Partner Passport days are available for refund.',
    passportReadyOne = '1 Passport day available. Claim it now.',
    passportReadyMany = '%d Passport days available. Claim all days now.',
    instructions = 'Premium Points: claim up to 1,000 points every 5 days. Passport days: claim all available days at once. Refunds are linked to your account, not your character.',
  },
  pt = {
    windowTitle = 'Ressarcimento',
    subtitle = 'Resgate Premium Points e dias de Best Partner Passport da temporada anterior.',
    pointsTitle = 'Premium Points',
    passportTitle = 'Best Partner Passport',
    claimPoints = 'Resgatar pontos',
    claimPassport = 'Resgatar dias',
    close = 'Fechar',
    langButton = 'EN',
    langTooltip = 'Alternar para ingles',
    loading = 'Carregando informacoes de ressarcimento...',
    ready = 'Informacoes de ressarcimento atualizadas.',
    loadTimeout = 'Nao foi possivel atualizar o ressarcimento. Feche e abra de novo, ou tente Resgatar.',
    requestingPoints = 'Solicitando ressarcimento de Premium Points...',
    requestingPassport = 'Solicitando dias de Best Partner Passport...',
    noPoints = 'Nao ha Premium Points disponiveis para ressarcimento.',
    pointsReady = '%d pontos disponiveis. Voce pode resgatar %d pontos agora.',
    pointsWait = '%d pontos disponiveis. Proximo resgate em %s.',
    noPassport = 'Nao ha dias de Best Partner Passport disponiveis para ressarcimento.',
    passportReadyOne = '1 dia de Passport disponivel. Resgate agora.',
    passportReadyMany = '%d dias de Passport disponiveis. Resgate todos agora.',
    instructions = 'Premium Points: resgate ate 1.000 pontos a cada 5 dias. Dias de Passport: resgate todos de uma vez. O ressarcimento fica vinculado a conta, nao ao personagem.',
  },
}

local function t(key)
  local pack = STRINGS[currentLang] or STRINGS.en
  return pack[key] or (STRINGS.en[key] or key)
end

local function getSideButton()
  local root = g_ui.getRootWidget()
  return root and root:recursiveGetChildById('refundBtn') or nil
end

local function updateSideButton()
  local sideButtons = modules.game_sidebuttons
  if sideButtons and sideButtons.setRefundButtonVisible then
    sideButtons.setRefundButtonVisible(state.available and not sideButtons.isHiddenMenuActive)
    return
  end

  local button = getSideButton()
  if not button then return end
  local hidden = sideButtons and sideButtons.isHiddenMenuActive
  button:setVisible(state.available and not hidden)
end

local function formatRemaining(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  if days > 0 then return string.format('%dd %dh %dm', days, hours, minutes) end
  if hours > 0 then return string.format('%dh %dm', hours, minutes) end
  return string.format('%dm', minutes)
end

local function send(action)
  if not g_game.isOnline() then return false end
  local protocol = g_game.getProtocolGame and g_game.getProtocolGame()
  if not protocol or not protocol.sendExtendedOpcode then return false end
  local ok, payload = pcall(function() return json.encode({ action = action }) end)
  if not ok then return false end
  return pcall(function() protocol:sendExtendedOpcode(OPCODE, payload) end)
end

local function setMessage(text, error)
  lastMessage = text
  lastMessageError = error and true or false
  if not window then return end
  local label = window:recursiveGetChildById('message')
  if label then
    label:setText(text or '')
    label:setColor(error and '#ff8c8cff' or '#a8dca8ff')
  end
end

local function refreshStaticTexts()
  if not window then return end

  window:setText(t('windowTitle'))

  local map = {
    subtitle = 'subtitle',
    pointsTitle = 'pointsTitle',
    passportTitle = 'passportTitle',
    instructions = 'instructions',
  }
  for widgetId, key in pairs(map) do
    local widget = window:recursiveGetChildById(widgetId)
    if widget then
      widget:setText(t(key))
    end
  end

  local claimPoints = window:recursiveGetChildById('claimPoints')
  local claimPassport = window:recursiveGetChildById('claimPassport')
  local closeButton = window:recursiveGetChildById('closeButton')
  local langButton = window:recursiveGetChildById('langButton')
  if claimPoints then claimPoints:setText(t('claimPoints')) end
  if claimPassport then claimPassport:setText(t('claimPassport')) end
  if closeButton then closeButton:setText(t('close')) end
  if langButton then
    langButton:setText(t('langButton'))
    langButton:setTooltip(t('langTooltip'))
  end
end

local function applyState(newState)
  if type(newState) == 'table' then
    for key, value in pairs(newState) do state[key] = value end
  end
  state.pointsRemaining = math.max(0, tonumber(state.pointsRemaining) or 0)
  state.passportDays = math.max(0, tonumber(state.passportDays) or 0)
  state.available = state.pointsRemaining > 0 or state.passportDays > 0

  updateSideButton()
  if not window then return end

  refreshStaticTexts()

  local now = os.time()
  local nextClaimAt = tonumber(state.nextClaimAt) or 0
  local canClaimPoints = state.pointsRemaining > 0 and (nextClaimAt == 0 or nextClaimAt <= now)
  local claimAmount = math.min(tonumber(state.maxPointsPerClaim) or 1000, state.pointsRemaining)
  local pointsText
  if state.pointsRemaining <= 0 then
    pointsText = t('noPoints')
  elseif canClaimPoints then
    pointsText = string.format(t('pointsReady'), state.pointsRemaining, claimAmount)
  else
    pointsText = string.format(t('pointsWait'), state.pointsRemaining, formatRemaining(nextClaimAt - now))
  end

  local passportText
  if state.passportDays == 1 then
    passportText = t('passportReadyOne')
  elseif state.passportDays > 1 then
    passportText = string.format(t('passportReadyMany'), state.passportDays)
  else
    passportText = t('noPassport')
  end

  local pointsLabel = window:recursiveGetChildById('pointsLabel')
  local passportLabel = window:recursiveGetChildById('passportLabel')
  local claimPoints = window:recursiveGetChildById('claimPoints')
  local claimPassport = window:recursiveGetChildById('claimPassport')
  if pointsLabel then pointsLabel:setText(pointsText) end
  if passportLabel then passportLabel:setText(passportText) end
  if claimPoints then claimPoints:setEnabled(canClaimPoints) end
  if claimPassport then claimPassport:setEnabled(state.passportDays > 0) end
end

function hasAvailableRefund()
  return state.available and true or false
end

function toggleLanguage()
  currentLang = currentLang == 'en' and 'pt' or 'en'
  applyState(state)
  if lastMessage and lastMessage ~= '' then
    if lastMessage == STRINGS.en.loading or lastMessage == STRINGS.pt.loading then
      setMessage(t('loading'), false)
    elseif lastMessage == STRINGS.en.ready or lastMessage == STRINGS.pt.ready then
      setMessage(t('ready'), false)
    elseif lastMessage == STRINGS.en.requestingPoints or lastMessage == STRINGS.pt.requestingPoints then
      setMessage(t('requestingPoints'), false)
    elseif lastMessage == STRINGS.en.requestingPassport or lastMessage == STRINGS.pt.requestingPassport then
      setMessage(t('requestingPassport'), false)
    else
      setMessage(lastMessage, lastMessageError)
    end
  end
end

local function cancelLoadingTimeout()
  removeEvent(loadingTimeoutEvent)
  loadingTimeoutEvent = nil
end

local function armLoadingTimeout()
  cancelLoadingTimeout()
  loadingTimeoutEvent = scheduleEvent(function()
    loadingTimeoutEvent = nil
    if not window or not window:isVisible() then return end
    if lastMessage == STRINGS.en.loading or lastMessage == STRINGS.pt.loading
      or lastMessage == STRINGS.en.requestingPoints or lastMessage == STRINGS.pt.requestingPoints
      or lastMessage == STRINGS.en.requestingPassport or lastMessage == STRINGS.pt.requestingPassport then
      setMessage(t('loadTimeout'), true)
    end
  end, 4000)
end

function show()
  if not window then return end
  window:show()
  window:raise()
  window:focus()
  applyState(state)
  setMessage(t('loading'), false)
  armLoadingTimeout()
  send('sync')
end

function hide()
  cancelLoadingTimeout()
  if window then window:hide() end
end

function claimPoints()
  setMessage(t('requestingPoints'), false)
  armLoadingTimeout()
  send('claim_points')
end

function claimPassport()
  setMessage(t('requestingPassport'), false)
  armLoadingTimeout()
  send('claim_passport')
end

local function onOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE then return end
  local ok, payload = pcall(function() return json.decode(buffer) end)
  if not ok or type(payload) ~= 'table' then return end
  cancelLoadingTimeout()
  if payload.state then applyState(payload.state) end

  local message = payload.message
  if type(message) == 'string' and message ~= '' then
    setMessage(message, payload.error)
  else
    -- Sync often arrives without a message; clear the "Loading..." placeholder.
    setMessage(t('ready'), false)
  end
end

local function online()
  if ProtocolGame and ProtocolGame.registerExtendedOpcode then
    pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
    ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
  end
  scheduleEvent(function()
    if g_game.isOnline() then send('sync') end
  end, 500)
end

local function offline()
  cancelLoadingTimeout()
  hide()
  state = {
    pointsTotal = 0,
    pointsRemaining = 0,
    passportDays = 0,
    nextClaimAt = 0,
    maxPointsPerClaim = 1000,
    cooldownDays = 5,
    available = false,
  }
  lastMessage = nil
  lastMessageError = false
  updateSideButton()
  if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
  end
end

function init()
  window = g_ui.displayUI('refund')
  if window then
    window:hide()
    refreshStaticTexts()
  end
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  if g_game.isOnline() then online() end
end

function terminate()
  cancelLoadingTimeout()
  offline()
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
  if window then
    window:destroy()
    window = nil
  end
end
