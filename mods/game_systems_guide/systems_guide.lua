-- BestServerOt custom systems guide (PT-BR / EN)

local window = nil
local currentLang = 'pt'
local currentTopic = 'overview'
local SETTINGS_KEY = 'systemsGuideLang'

local TOPICS = {
  'overview',
  'helperStart',
  'helperHealTools',
  'helperCombat',
  'helperMore',
  'bestTasks',
  'upgradeStones',
  'skillPerks',
  'passport',
  'levelReward',
  'roulette',
}

-- Menu colors: Helper topics stay green; other topics share one blue.
local TOPIC_MENU_COLOR = {
  overview = '#9fd4ffff',
  helperStart = '#7dff9fff',
  helperHealTools = '#7dff9fff',
  helperCombat = '#7dff9fff',
  helperMore = '#7dff9fff',
  bestTasks = '#9fd4ffff',
  upgradeStones = '#9fd4ffff',
  skillPerks = '#9fd4ffff',
  passport = '#9fd4ffff',
  levelReward = '#9fd4ffff',
  roulette = '#9fd4ffff',
}

local COLOR_BODY = '#e0e0e0ff'
local COLOR_SECTION = '#6ad7ffff'   -- section dividers / big titles
local COLOR_SUBTITLE = '#ffd76aff'  -- Spell Healing:, Auto Haste:, etc.
local COLOR_TIP = '#7dff9fff'       -- tips / golden rules

local CONTENT = {
  pt = {
    windowTitle = 'Sistemas BestServerOt',
    header = 'Guia dos Sistemas',
    subHeader = 'Entenda como funcionam os sistemas exclusivos do BestServerOt.',
    topicsTitle = 'Topicos',
    footer = 'Dica: abra a qualquer momento pelo botao Guide (ao lado do Helper).',
    close = 'Fechar',
    topics = {
      overview = {
        title = 'Visao Geral',
        tag = 'BestServerOt / BTC',
        body = table.concat({
          'Bem-vindo ao BestServerOt!',
          '',
          'Este guia explica os sistemas customizados do servidor de forma clara.',
          'Use o menu a esquerda para navegar e os botoes PT-BR / EN para trocar o idioma.',
          '',
          'Sistemas cobertos:',
          '  - BTC Helper (bot / assistente do client)',
          '  - Best Tasks System',
          '  - Upgrade Stones (Spell Forge)',
          '  - Skills & Perks',
          '  - Best Partner Passport',
          '  - Level Rewards',
          '  - Magic Roulette',
          '',
          'Topicos do Helper:',
          '  - Helper: Inicio',
          '  - Helper: Healing e Tools',
          '  - Helper: Shooter e Target',
          '  - Helper: Equip, Cavebot e Mais',
          '',
          'Atalhos uteis:',
          '  - Botoes laterais abrem as janelas principais',
          '  - BTC Helper (ou Ctrl+H) abre o assistente',
          '  - BTC Guide abre este guia dos sistemas',
          '  - Ctrl+Z abre o Bug Report',
        }, '\n'),
      },
      helperStart = {
        title = 'Helper: Inicio',
        tag = 'BTC Helper  |  Ctrl+H  |  Shortcuts',
        body = table.concat({
          'O BTC Helper e o assistente automatico do client: cura, combate, equip,',
          'cavebot, timer, alarmes e ferramentas.',
          '',
          'Leia tambem os topicos:',
          '  - Helper: Healing e Tools',
          '  - Helper: Shooter e Target',
          '  - Helper: Equip, Cavebot e Alarmes',
          '',
          '========== COMO ABRIR E LIGAR ==========',
          '  - Botao BTC Helper (ao lado do Guide) ou Ctrl+H.',
          '  - Na primeira vez, aceite os Termos e Condicoes.',
          '  - No rodape: Helper Status deve ficar Enabled (verde).',
          '  - Marque Shortcuts para mostrar a barrinha de atalhos rapidos.',
          '',
          'Regra de ouro:',
          '  Helper Status Enabled + checkbox Enable da funcao = ela trabalha.',
          '  Se so o Status estiver ligado, Healing/Shooter/etc. NAO disparam.',
          '',
          'Abas do Helper (icones no topo):',
          '  1 Healing | 2 Tools | 3 Magic Shooter (+ Auto Target)',
          '  4 Equip | 5 Cavebot | 6 Timer',
          '',
          '========== CHECKLIST "NAO FAZ NADA" ==========',
          '  1) Helper Status = Enabled.',
          '  2) O Enable da funcao especifica esta marcado.',
          '  3) Spell/item/regra/municao selecionado e na backpack.',
          '  4) Fora de PZ se Target/Shooter usam Disable in Protect Zone.',
          '  5) Monstro nao esta na Ignore Monster List.',
          '  6) Count / HP% / MP% / Harmony da regra estao ok.',
          '  7) Cavebot realmente em On (nao so o Helper Status).',
          '  8) Depois de entrar em PZ (opcao padrao), RELIGUE Target/Shooter.',
        }, '\n'),
      },
      helperHealTools = {
        title = 'Helper: Healing e Tools',
        tag = 'Abas Healing e Tools',
        body = table.concat({
          '========== HEALING ==========',
          'Spell Healing:',
          '  - Escolha a magia e o HP% para castar automaticamente.',
          '  - Vocacoes diferentes tem quantidades diferentes de slots.',
          '',
          'Potion Healing:',
          '  - Configure potions de life/mana e o %.',
          '  - Icone de prioridade: vermelho = Life, azul = Mana',
          '    (importante para Paladin/Monk).',
          '',
          'Special Foods:',
          '  - Botao abre a janela de comidas especiais de HP/Mana.',
          '  - Ative o slot, escolha item, % e prioridade.',
          '',
          'Heal Friend / Natures Embrace / Mass Healing:',
          '  - Conforme a vocacao (Sorc/Druid/Monk).',
          '  - Heal Target: Screen (todos na tela) ou Party (so party).',
          '  - Configure Enable + HP% + Priority por vocacao alvo.',
          '',
          '========== TOOLS ==========',
          'Mana Training:',
          '  - Enable + magia de treino + MP% minimo.',
          '  - Sem magia selecionada, nao treina.',
          '',
          'Auto Haste:',
          '  - Enable: mantem haste ativo.',
          '  - PZ Cast: permite castar haste DENTRO de PZ.',
          '  - If Walking: so castar andando (evita spam parado).',
          '',
          'Outras ferramentas:',
          '  - Exercise Training: em PZ, parado ~2s, com dummy + exercise.',
          '  - Change Gold: container de gold precisa estar ABERTO.',
          '  - Auto Eat Food: come quando a regen de food esta baixa.',
          '  - Follow: follow entre andares; conflita com Cavebot.',
          '  - Quiver Refill (Paladin): move flechas para o quiver.',
          '  - Magic Shield (mage): Utamo/Exana por HP% + potion opcional.',
          '  - Alarms (engrenagem): abre Alarm Settings.',
        }, '\n'),
      },
      helperCombat = {
        title = 'Helper: Shooter e Target',
        tag = 'Aba Magic Shooter + Auto Target',
        body = table.concat({
          '========== PRESETS E REGRAS ==========',
          '  - Crie presets (New / Rename / Duplicate / Remove).',
          '  - Set Key pode trocar de preset por hotkey.',
          '  - A lista de regras = prioridade (de cima para baixo).',
          '',
          'Campos da regra:',
          '  - Tipo Spell ou Rune',
          '  - Count de criaturas',
          '  - HP% Min/Max do monstro',
          '  - MP%/HP% do player, Delay',
          '  - Nomes de monstro (opcional)',
          '',
          'Condition Settings:',
          '  - Cast If Trapped',
          '  - Count Lower Than (ex.: C:1- = no maximo 1 criatura)',
          '  - Cast On Foot / Extended Area / Force Spell On Target',
          '',
          'Marque o checkbox de cada regra para ativa-la.',
          '',
          '========== ENABLE SHOOTER ==========',
          '  - Sem Enable Shooter, NENHUMA regra castar.',
          '  - Helper Status Enabled sozinho NAO basta.',
          '',
          '========== AUTO TARGET ==========',
          '  - Enable + Mode A..J',
          '  - A = mais perto | C = menor HP | J = lista de prioridade',
          '  - Ignore Monster List: monstro listado e IGNORADO',
          '  - Priority List: so vale no Mode J (ordem importa)',
          '',
          '========== DISABLE IN PROTECT ZONE ==========',
          'Padrao: ligado.',
          '  - Ao ENTRAR em PZ: desliga Auto Target e Magic Shooter.',
          '  - Ao SAIR: voce precisa marcar de novo.',
          '  - Se desmarcar a opcao: pausa em PZ e volta sozinho ao sair.',
          '',
          '========== SHOOTER PARADO? ==========',
          '  - Enable Shooter desmarcado (ou desligado pela PZ).',
          '  - Testando no templo/depot (PZ).',
          '  - Cacando monstro da Ignore List.',
          '  - Regra pede 2+ e so tem 1 monstro.',
          '  - Sem mana / sem runa / magia em cooldown.',
        }, '\n'),
      },
      helperMore = {
        title = 'Helper: Equip, Cavebot e Mais',
        tag = 'Equip | Cavebot | Timer | Alarmes | Hotkeys',
        body = table.concat({
          '========== EQUIP HELPER ==========',
          '  - Regras para equipar/desequipar ring/amulet.',
          '  - Condicoes: HP%, MP%, Rooted, Feared, PZ, Utamo Vita.',
          '  - Precisa Enable Equipment + Helper Status.',
          '  - Item na backpack; Skip if equipped evita troca inutil.',
          '',
          '========== CAVEBOT ==========',
          '  - Waypoints: Walk, Stand, Node, Use, Rope, Shovel, Clear.',
          '  - Recording: botao Not Recording + tecla em Settings.',
          '  - Settings: Safety Lure, distancia, Walk Delay, Map Walk.',
          '  - Rodape Cavebot: Off/On (aviso de uso de ferramentas).',
          '  - Cavebot NAO roda so com Helper Status: precisa iniciar On.',
          '  - BotCheck do servidor pode forcar Cavebot/Follow off.',
          '',
          '========== TIMER ==========',
          '  - Casta palavras ou usa item em cooldown.',
          '  - Conditions: PZ / non-PZ / Cast if targeting monster.',
          '  - Enable Timer + regra marcada + Helper Status.',
          '',
          '========== ALARMS ==========',
          'Em Tools > Alarms:',
          '  - Cap / Low Health / Low Mana / Full Dust / Private Message.',
          '  - Low Supply: item + quantidade minima + Alert In Protect Zone.',
          '  - Flash BTC Taskbar: pisca a barra se o client estiver em segundo plano.',
          '  - BotCheck (servidor): alarme especial; desliga Cavebot/Follow.',
          '',
          '========== HOTKEYS ==========',
          'Use Set Key para:',
          '  Helper, Auto Target, Magic Shooter, Target+Shooter,',
          '  trocar preset do Shooter/Equip, Cavebot, Recording,',
          '  Timer, Supply Alarm, Follow.',
          '',
          'Obs.: hotkeys nao disparam enquanto digita no chat/NPC/store',
          '(exceto F1-F12).',
          '',
          'Dica: configure uma aba por vez, ligue so o Enable daquela',
          'funcao, teste fora de PZ e depois monte presets complexos.',
        }, '\n'),
      },
      bestTasks = {
        title = 'Best Tasks System',
        tag = 'Janela lateral: Best Tasks',
        body = table.concat({
          'O Best Tasks e o sistema de missoes do servidor. Voce aceita tasks em salas (rooms),',
          'caca os monstros pedidos, coleta recompensas e investe pontos em bonus permanentes.',
          '',
          'Como comecar:',
          '  1) Abra a janela Best Tasks pelo botao lateral.',
          '  2) Escolha uma sala/grupo e uma task disponivel.',
          '  3) Aceite a task e cace ate completar o progresso.',
          '  4) Clique em Claim para receber a recompensa.',
          '',
          'Moedas do sistema:',
          '  - Best Points: usados na aba Bonuses (Capacity, Crit, Damage, Loot, XP).',
          '  - Task Tokens: usados na loja de outfits da propria janela.',
          '  - Premium Points: usados apenas no Respec dos bonuses.',
          '',
          'Bonuses (Best Points):',
          '  - Cada Invest +1% gasta pontos nao gastos (Unspent).',
          '  - Cap / Crit Chance / Crit Damage / Loot: maximo 30%.',
          '  - Experience: maximo 45%.',
          '  - O custo sobe conforme o rank do bonus.',
          '',
          'Respec:',
          '  - Reseta todos os bonuses investidos.',
          '  - Custa Premium Points (padrao: 10).',
          '  - Devolve os Best Points investidos para Unspent.',
          '  - Sempre pede confirmacao antes de cobrar.',
          '',
          'Dica: acompanhe Unspent, Invested e Premium Points no topo da aba Bonuses.',
        }, '\n'),
      },
      upgradeStones = {
        title = 'Upgrade Stones',
        tag = 'Janela lateral: Upgrade Stones  |  !spellupgrade / !us',
        body = table.concat({
          'O sistema Upgrade Stones fortalece magias e equipamentos com Forge Resonance.',
          '',
          'Como obter stones:',
          '  - Principalmente matando monstros Influenced / Fiendish da forge.',
          '  - O saldo fica no personagem (nao precisa carregar item na backpack).',
          '',
          'Passo a passo:',
          '  1) Junte Upgrade Stones.',
          '  2) Use !upgradestones (ou !us) para ver saldo e crafting.',
          '  3) Crie runes de item: attack | armor | defense | damage.',
          '  4) Cada rune crafted aumenta Forge Resonance.',
          '  5) Abra !spellupgrade (ou !du) e upagrade magias liberadas.',
          '',
          'Forge Resonance:',
          '  - Comeca com 2 magias liberadas.',
          '  - A cada 3 runes crafted libera +1 magia.',
          '  - Cap inicial de magia: 25 | cada rune: +1 cap | max absoluto: 100.',
          '',
          'Custo de upgrade de magia:',
          '  - Formula: 10 + nivel atual da magia (em Upgrade Stones).',
          '  - +1% de dano daquela magia por nivel.',
          '  - Limite diario: 25 niveis de magia (reseta a meia-noite do servidor).',
          '',
          'Observacao: magias de quest WAW e tutorial nao entram neste sistema.',
        }, '\n'),
      },
      skillPerks = {
        title = 'Skills & Perks',
        tag = 'Janela lateral: Skills & Perks  |  !perks',
        body = table.concat({
          'Skills & Perks sao upgrades permanentes comprados com Exalted Cores.',
          'Cada perk sobe individualmente e continua ativo apos logout e morte.',
          '',
          'Como usar:',
          '  1) Abra a janela Skills & Perks (botao lateral) ou digite !perks.',
          '  2) Escolha Core Perks ou Resistances.',
          '  3) Selecione o perk e clique em Upgrade.',
          '',
          'Custos e limites:',
          '  - Moeda: Exalted Core',
          '  - Custo: 10 cores por nivel',
          '  - Maximo: 50 niveis por perk',
          '',
          'Core Perks:',
          '  - Potion Upgrade: +1% cura/mana de potions por nivel',
          '  - Regen: +1 HP/s e +1 MP/s por nivel',
          '  - Money Maker: +1% quantidade de gold dropado por nivel',
          '  - Damage / Health / Mana: +0.6% por nivel (max +30%)',
          '',
          'Resistances:',
          '  - Physical, Fire, Energy, Ice, Earth, Holy, Death,',
          '    Lifedrain, Manadrain e Drown',
          '  - +0.6% de absorcao por nivel (max +30% cada)',
          '',
          'Dica: priorize o que combina com sua build (ex.: Damage + resistencias da hunt).',
        }, '\n'),
      },
      passport = {
        title = 'Best Partner Passport',
        tag = 'Janela lateral: Best Partner Passport  |  !passport',
        body = table.concat({
          'O Best Partner Passport libera hunts privadas e beneficios exclusivos da conta.',
          '',
          'Requisitos:',
          '  - Conta com Passport ativo (loja do site).',
          '  - Para abrir hunt: estar em PZ e fora de combate.',
          '  - Para entrar (join): passport ativo e fora de combate.',
          '',
          'Comandos principais:',
          '  - !passport .............. status e resumo',
          '  - !passport focus ........ tempo de Hunt Focus',
          '  - !passport hunt ......... criar hunt privada (em PZ)',
          '  - !passport hunt join .... entrar na sua hunt / hunt da party',
          '  - !passport leave ........ sair da hunt',
          '',
          'Hunt Focus (stamina da hunt):',
          '  - Maximo: 60 horas',
          '  - Dentro da hunt: consome 1 min por minuto',
          '  - Fora da hunt: recupera 1:1',
          '  - Com 24h ou menos: metade de XP somente na passport hunt',
          '  - Em 0: voce e removido automaticamente',
          '',
          'Como abrir uma hunt:',
          '  1) Va ate uma PZ.',
          '  2) Digite !passport hunt.',
          '  3) Escolha 1 a 4 monstros, dificuldade e respawn.',
          '  4) Clique em Start.',
          '',
          'Party: ate 4 jogadores na mesma hunt se estiverem na mesma party.',
          'O lider abre; os membros usam !passport hunt join.',
        }, '\n'),
      },
      levelReward = {
        title = 'Level Rewards',
        tag = 'Janela lateral: Level Rewards',
        body = table.concat({
          'Level Rewards entrega equipamentos e premios em marcos de level.',
          '',
          'Como funciona:',
          '  1) Alcance o level do marco.',
          '  2) Abra a janela Level Rewards.',
          '  3) Selecione o premio disponivel e clique em Claim.',
          '',
          'Regras importantes:',
          '  - Itens de Level Reward sao bound ao personagem.',
          '  - Nao podem ser negociados no market / trade.',
          '  - Somente voce pode move-los.',
          '',
          'Dica: sempre que subir de level importante, abra a janela e confira',
          'se ha recompensa pendente para coletar.',
        }, '\n'),
      },
      roulette = {
        title = 'Magic Roulette',
        tag = 'Janela lateral: Magic Roulette  |  site: ?roulette',
        body = table.concat({
          'A Magic Roulette e a roleta de premios do servidor.',
          '',
          'Como usar:',
          '  1) Abra a janela Magic Roulette pelo botao lateral.',
          '  2) Veja seu saldo de Roulette Points, jackpots e premios.',
          '  3) Gire quando tiver pontos suficientes.',
          '',
          'O que voce encontra na janela:',
          '  - Saldo de pontos da roleta',
          '  - Jackpots ativos',
          '  - Lista / historico de premios',
          '  - Pacotes e informacoes da roleta',
          '',
          'Observacao:',
          '  - Premios e chances seguem a configuracao atual do servidor.',
          '  - Jackpots especiais podem aparecer conforme o evento/config.',
          '',
          'Dica: acompanhe a roleta tambem pelo site oficial quando quiser',
          'ver ranking/historico publico.',
        }, '\n'),
      },
    },
  },
  en = {
    windowTitle = 'BestServerOt Systems',
    header = 'Systems Guide',
    subHeader = 'Learn how BestServerOt exclusive systems work.',
    topicsTitle = 'Topics',
    footer = 'Tip: open anytime from the Guide button (next to Helper).',
    close = 'Close',
    topics = {
      overview = {
        title = 'Overview',
        tag = 'BestServerOt / BTC',
        body = table.concat({
          'Welcome to BestServerOt!',
          '',
          'This guide explains the server custom systems in a clear way.',
          'Use the left menu to browse and the PT-BR / EN buttons to switch language.',
          '',
          'Covered systems:',
          '  - BTC Helper (client bot / assistant)',
          '  - Best Tasks System',
          '  - Upgrade Stones (Spell Forge)',
          '  - Skills & Perks',
          '  - Best Partner Passport',
          '  - Level Rewards',
          '  - Magic Roulette',
          '',
          'Helper guide topics:',
          '  - Helper: Start',
          '  - Helper: Healing and Tools',
          '  - Helper: Shooter and Target',
          '  - Helper: Equip, Cavebot and More',
          '',
          'Useful shortcuts:',
          '  - Side buttons open the main windows',
          '  - BTC Helper (or Ctrl+H) opens the assistant',
          '  - BTC Guide opens this systems guide',
          '  - Ctrl+Z opens Bug Report',
        }, '\n'),
      },
      helperStart = {
        title = 'Helper: Start',
        tag = 'BTC Helper  |  Ctrl+H  |  Shortcuts',
        body = table.concat({
          'BTC Helper is the client automation suite: healing, combat, equipment,',
          'cavebot, timer, alarms and tools.',
          '',
          'Also read:',
          '  - Helper: Healing and Tools',
          '  - Helper: Shooter and Target',
          '  - Helper: Equip, Cavebot and More',
          '',
          '========== OPEN AND ENABLE ==========',
          '  - BTC Helper button (next to Guide) or Ctrl+H.',
          '  - On first use, accept the Terms and Conditions.',
          '  - Footer: Helper Status must be Enabled (green).',
          '  - Check Shortcuts to show the quick toggle strip.',
          '',
          'Golden rule:',
          '  Helper Status Enabled + feature Enable checkbox = it runs.',
          '  Status alone does NOT cast/heal/target.',
          '',
          'Helper tabs (top icons):',
          '  1 Healing | 2 Tools | 3 Magic Shooter (+ Auto Target)',
          '  4 Equip | 5 Cavebot | 6 Timer',
          '',
          '========== "IT DOES NOTHING" CHECKLIST ==========',
          '  1) Helper Status = Enabled.',
          '  2) The feature own Enable checkbox is on.',
          '  3) Spell/item/rule/ammo selected and in backpack.',
          '  4) Outside PZ if Target/Shooter use Disable in Protect Zone.',
          '  5) Monster is not on the Ignore Monster List.',
          '  6) Rule Count / HP% / MP% / Harmony conditions are met.',
          '  7) Cavebot is actually On (not only Helper Status).',
          '  8) After entering PZ (default option), RE-ENABLE Target/Shooter.',
        }, '\n'),
      },
      helperHealTools = {
        title = 'Helper: Healing and Tools',
        tag = 'Healing and Tools tabs',
        body = table.concat({
          '========== HEALING ==========',
          'Spell Healing:',
          '  - Pick the spell and HP% threshold for auto-cast.',
          '  - Different vocations get different slot counts.',
          '',
          'Potion Healing:',
          '  - Configure life/mana potions and %.',
          '  - Priority icon: red = Life, blue = Mana',
          '    (important for Paladin/Monk).',
          '',
          'Special Foods:',
          '  - Opens special HP/Mana food window.',
          '  - Enable slot, pick item, %, and priority.',
          '',
          'Heal Friend / Natures Embrace / Mass Healing:',
          '  - Available by vocation (Sorc/Druid/Monk).',
          '  - Heal Target: Screen (everyone on screen) or Party only.',
          '  - Configure Enable + HP% + Priority per target vocation.',
          '',
          '========== TOOLS ==========',
          'Mana Training:',
          '  - Enable + training spell + minimum MP%.',
          '  - Without a selected spell it will not train.',
          '',
          'Auto Haste:',
          '  - Enable: keeps haste up.',
          '  - PZ Cast: allow casting haste INSIDE PZ.',
          '  - If Walking: only cast while moving.',
          '',
          'Other tools:',
          '  - Exercise Training: in PZ, stand still ~2s, dummy + exercise item.',
          '  - Change Gold: gold container must be OPEN.',
          '  - Auto Eat Food: eats when food regen is low.',
          '  - Follow: multi-floor follow; conflicts with Cavebot.',
          '  - Quiver Refill (Paladin): moves ammo into the quiver.',
          '  - Magic Shield (mage): Utamo/Exana by HP% + optional potion.',
          '  - Alarms (gear icon): opens Alarm Settings.',
        }, '\n'),
      },
      helperCombat = {
        title = 'Helper: Shooter and Target',
        tag = 'Magic Shooter + Auto Target tab',
        body = table.concat({
          '========== PRESETS AND RULES ==========',
          '  - Create presets (New / Rename / Duplicate / Remove).',
          '  - Set Key can cycle presets with a hotkey.',
          '  - Rule list order = priority (top to bottom).',
          '',
          'Rule fields:',
          '  - Spell or Rune type',
          '  - Creature Count',
          '  - Monster HP% Min/Max',
          '  - Player MP%/HP%, Delay',
          '  - Optional monster names',
          '',
          'Condition Settings:',
          '  - Cast If Trapped',
          '  - Count Lower Than (e.g. C:1- = at most 1 creature)',
          '  - Cast On Foot / Extended Area / Force Spell On Target',
          '',
          'Check each rule checkbox to enable it.',
          '',
          '========== ENABLE SHOOTER ==========',
          '  - Without Enable Shooter, NO rule will cast.',
          '  - Helper Status Enabled alone is NOT enough.',
          '',
          '========== AUTO TARGET ==========',
          '  - Enable + Mode A..J',
          '  - A = closest | C = lowest HP | J = priority list',
          '  - Ignore Monster List: listed monsters are IGNORED',
          '  - Priority List: only used in Mode J (order matters)',
          '',
          '========== DISABLE IN PROTECT ZONE ==========',
          'Default: on.',
          '  - On ENTERING PZ: turns Auto Target and Magic Shooter OFF.',
          '  - On LEAVING: you must check them again.',
          '  - If you uncheck this option: pauses in PZ and resumes on leave.',
          '',
          '========== SHOOTER IDLE? ==========',
          '  - Enable Shooter unchecked (or disabled by PZ).',
          '  - Testing in temple/depot (PZ).',
          '  - Hunting a monster on the Ignore List.',
          '  - Rule needs 2+ creatures and only 1 is present.',
          '  - No mana / no rune / spell on cooldown.',
        }, '\n'),
      },
      helperMore = {
        title = 'Helper: Equip, Cavebot and More',
        tag = 'Equip | Cavebot | Timer | Alarms | Hotkeys',
        body = table.concat({
          '========== EQUIP HELPER ==========',
          '  - Rules to equip/unequip rings/amulets.',
          '  - Conditions: HP%, MP%, Rooted, Feared, PZ, Utamo Vita.',
          '  - Needs Enable Equipment + Helper Status.',
          '  - Item in backpack; Skip if equipped avoids useless swaps.',
          '',
          '========== CAVEBOT ==========',
          '  - Waypoints: Walk, Stand, Node, Use, Rope, Shovel, Clear.',
          '  - Recording: Not Recording button + key in Settings.',
          '  - Settings: Safety Lure, distance, Walk Delay, Map Walk.',
          '  - Footer Cavebot: Off/On (tools warning).',
          '  - Cavebot does NOT run from Helper Status alone: start it On.',
          '  - Server BotCheck can force Cavebot/Follow off.',
          '',
          '========== TIMER ==========',
          '  - Periodically casts words or uses an item on cooldown.',
          '  - Conditions: PZ / non-PZ / Cast if targeting monster.',
          '  - Enable Timer + rule checked + Helper Status.',
          '',
          '========== ALARMS ==========',
          'Under Tools > Alarms:',
          '  - Cap / Low Health / Low Mana / Full Dust / Private Message.',
          '  - Low Supply: item + minimum count + Alert In Protect Zone.',
          '  - Flash BTC Taskbar: flashes taskbar when client is unfocused.',
          '  - BotCheck (server): special alarm; turns Cavebot/Follow off.',
          '',
          '========== HOTKEYS ==========',
          'Use Set Key for:',
          '  Helper, Auto Target, Magic Shooter, Target+Shooter,',
          '  change Shooter/Equip preset, Cavebot, Recording,',
          '  Timer, Supply Alarm, Follow.',
          '',
          'Note: hotkeys do not fire while typing in chat/NPC/store',
          '(except F1-F12).',
          '',
          'Tip: configure one tab at a time, enable only that feature,',
          'test outside PZ, then build complex presets.',
        }, '\n'),
      },
      bestTasks = {
        title = 'Best Tasks System',
        tag = 'Side button: Best Tasks',
        body = table.concat({
          'Best Tasks is the server mission system. Accept tasks in rooms,',
          'hunt the requested monsters, claim rewards and invest points into permanent bonuses.',
          '',
          'How to start:',
          '  1) Open Best Tasks from the side button.',
          '  2) Pick a room/group and an available task.',
          '  3) Accept the task and hunt until progress is complete.',
          '  4) Click Claim to receive the reward.',
          '',
          'System currencies:',
          '  - Best Points: spent in the Bonuses tab (Capacity, Crit, Damage, Loot, XP).',
          '  - Task Tokens: spent in the outfits shop inside the same window.',
          '  - Premium Points: used only for bonus Respec.',
          '',
          'Bonuses (Best Points):',
          '  - Each Invest +1% spends Unspent points.',
          '  - Cap / Crit Chance / Crit Damage / Loot: max 30%.',
          '  - Experience: max 45%.',
          '  - Cost rises as the bonus rank increases.',
          '',
          'Respec:',
          '  - Resets all invested bonuses.',
          '  - Costs Premium Points (default: 10).',
          '  - Refunds invested Best Points as Unspent.',
          '  - Always asks for confirmation before charging.',
          '',
          'Tip: track Unspent, Invested and Premium Points at the top of the Bonuses tab.',
        }, '\n'),
      },
      upgradeStones = {
        title = 'Upgrade Stones',
        tag = 'Side button: Upgrade Stones  |  !spellupgrade / !us',
        body = table.concat({
          'Upgrade Stones power up spells and gear through Forge Resonance.',
          '',
          'How to get stones:',
          '  - Mainly by killing Influenced / Fiendish forge monsters.',
          '  - Balance is stored on the character (not as backpack items).',
          '',
          'Step by step:',
          '  1) Collect Upgrade Stones.',
          '  2) Use !upgradestones (or !us) to check balance and crafting.',
          '  3) Craft item runes: attack | armor | defense | damage.',
          '  4) Each crafted rune increases Forge Resonance.',
          '  5) Open !spellupgrade (or !du) and upgrade unlocked spells.',
          '',
          'Forge Resonance:',
          '  - Starts with 2 unlocked spells.',
          '  - Every 3 crafted runes unlocks +1 spell.',
          '  - Spell cap starts at 25 | +1 per rune | absolute max 100.',
          '',
          'Spell upgrade cost:',
          '  - Formula: 10 + current spell level (in Upgrade Stones).',
          '  - +1% damage for that spell per level.',
          '  - Daily limit: 25 spell levels (resets at server midnight).',
          '',
          'Note: WAW quest spells and tutorial spells are excluded.',
        }, '\n'),
      },
      skillPerks = {
        title = 'Skills & Perks',
        tag = 'Side button: Skills & Perks  |  !perks',
        body = table.concat({
          'Skills & Perks are permanent upgrades bought with Exalted Cores.',
          'Each perk levels individually and stays active after logout and death.',
          '',
          'How to use:',
          '  1) Open Skills & Perks (side button) or type !perks.',
          '  2) Choose Core Perks or Resistances.',
          '  3) Select a perk and click Upgrade.',
          '',
          'Costs and limits:',
          '  - Currency: Exalted Core',
          '  - Cost: 10 cores per level',
          '  - Cap: 50 levels per perk',
          '',
          'Core Perks:',
          '  - Potion Upgrade: +1% potion heal/mana per level',
          '  - Regen: +1 HP/s and +1 MP/s per level',
          '  - Money Maker: +1% gold drop quantity per level',
          '  - Damage / Health / Mana: +0.6% per level (max +30%)',
          '',
          'Resistances:',
          '  - Physical, Fire, Energy, Ice, Earth, Holy, Death,',
          '    Lifedrain, Manadrain and Drown',
          '  - +0.6% absorption per level (max +30% each)',
          '',
          'Tip: prioritize what fits your build (e.g. Damage + hunt resistances).',
        }, '\n'),
      },
      passport = {
        title = 'Best Partner Passport',
        tag = 'Side button: Best Partner Passport  |  !passport',
        body = table.concat({
          'Best Partner Passport unlocks private hunts and exclusive account benefits.',
          '',
          'Requirements:',
          '  - Account with an active Passport (website store).',
          '  - To open a hunt: be in PZ and out of combat.',
          '  - To join: active passport and out of combat.',
          '',
          'Main commands:',
          '  - !passport .............. status and summary',
          '  - !passport focus ........ Hunt Focus time',
          '  - !passport hunt ......... create private hunt (in PZ)',
          '  - !passport hunt join .... join your hunt / party hunt',
          '  - !passport leave ........ leave the hunt',
          '',
          'Hunt Focus (private-hunt stamina):',
          '  - Max: 60 hours',
          '  - Inside hunt: consumes 1 minute per minute',
          '  - Outside hunt: recovers 1:1',
          '  - At 24h or less: half XP only inside passport hunt',
          '  - At 0: you are removed automatically',
          '',
          'How to open a hunt:',
          '  1) Go to a PZ.',
          '  2) Type !passport hunt.',
          '  3) Choose 1 to 4 monsters, difficulty and respawn.',
          '  4) Click Start.',
          '',
          'Party: up to 4 players can share the same hunt if in the same party.',
          'Leader opens; members use !passport hunt join.',
        }, '\n'),
      },
      levelReward = {
        title = 'Level Rewards',
        tag = 'Side button: Level Rewards',
        body = table.concat({
          'Level Rewards grants gear and prizes at milestone levels.',
          '',
          'How it works:',
          '  1) Reach the milestone level.',
          '  2) Open the Level Rewards window.',
          '  3) Select an available prize and click Claim.',
          '',
          'Important rules:',
          '  - Level Reward items are bound to your character.',
          '  - They cannot be traded on market / player trade.',
          '  - Only you can move them.',
          '',
          'Tip: after important level-ups, open the window and check',
          'for pending rewards to claim.',
        }, '\n'),
      },
      roulette = {
        title = 'Magic Roulette',
        tag = 'Side button: Magic Roulette  |  site: ?roulette',
        body = table.concat({
          'Magic Roulette is the server prize wheel.',
          '',
          'How to use:',
          '  1) Open Magic Roulette from the side button.',
          '  2) Check Roulette Points, jackpots and prizes.',
          '  3) Spin when you have enough points.',
          '',
          'What you will find in the window:',
          '  - Roulette points balance',
          '  - Active jackpots',
          '  - Prize list / history',
          '  - Packages and roulette info',
          '',
          'Note:',
          '  - Prizes and odds follow the current server configuration.',
          '  - Special jackpots may appear depending on events/config.',
          '',
          'Tip: you can also follow public roulette history/ranking on the official website.',
        }, '\n'),
      },
    },
  },
}

local function langPack()
  return CONTENT[currentLang] or CONTENT.pt
end

local function estimateBodyHeight(text, width)
  if not text or text == '' then
    return 120
  end
  local lineHeight = 17
  local charsPerLine = math.max(36, math.floor((width or 560) / 7))
  local totalLines = 0
  for line in (text .. '\n'):gmatch('(.-)\n') do
    local len = #line
    if len <= 0 then
      totalLines = totalLines + 1
    else
      totalLines = totalLines + math.max(1, math.ceil(len / charsPerLine))
    end
  end
  return math.max(120, totalLines * lineHeight + 28)
end

local function formatGuideBody(text)
  if not text or text == '' then
    return ''
  end
  local lines = {}
  for line in (text .. '\n'):gmatch('(.-)\n') do
    local section = line:match('^%=+%s*(.-)%s*%=+$')
    if section and section ~= '' then
      lines[#lines + 1] = string.format('[color=%s]== %s ==[/color]', COLOR_SECTION, section)
    elseif line:match('^%=+$') then
      lines[#lines + 1] = string.format('[color=%s]------------------------[/color]', COLOR_SECTION)
    elseif line:match('^[Rr]egra de ouro:') or line:match('^[Gg]olden rule:')
        or line:match('^[Dd]ica') or line:match('^[Tt]ip:')
        or line:match('^[Ff]inal tip:') or line:match('^[Dd]ica final:') then
      lines[#lines + 1] = string.format('[color=%s]%s[/color]', COLOR_TIP, line)
    elseif line:match('^[^%s].+:$') and #line < 48 then
      lines[#lines + 1] = string.format('[color=%s]%s[/color]', COLOR_SUBTITLE, line)
    else
      lines[#lines + 1] = line
    end
  end
  return table.concat(lines, '\n')
end

local function applyBodyText(body, text, width)
  if not body then return end
  local plain = text or ''
  local colored = formatGuideBody(plain)
  if body.parseColoredText then
    body:parseColoredText(colored, COLOR_BODY)
  elseif body.setColorText then
    body:setColorText(colored, COLOR_BODY)
  else
    body:setText(plain)
  end

  local height = estimateBodyHeight(plain, width)
  if body.getTextSize then
    local size = body:getTextSize()
    if size and size.height and size.height > height then
      height = size.height + 8
    end
  end
  body:setHeight(height)
end

local function refreshChrome()
  if not window then return end
  local pack = langPack()
  window:setText(pack.windowTitle)
  local header = window:recursiveGetChildById('headerLabel')
  local sub = window:recursiveGetChildById('subHeader')
  local topicsTitle = window:recursiveGetChildById('topicTitle')
  local footer = window:recursiveGetChildById('footerHint')
  local closeBtn = window:recursiveGetChildById('closeButton')
  local ptBtn = window:recursiveGetChildById('langPtButton')
  local enBtn = window:recursiveGetChildById('langEnButton')

  if header then header:setText(pack.header) end
  if sub then sub:setText(pack.subHeader) end
  if topicsTitle then topicsTitle:setText(pack.topicsTitle) end
  if footer then footer:setText(pack.footer) end
  if closeBtn then closeBtn:setText(pack.close) end
  if ptBtn then
    ptBtn:setColor(currentLang == 'pt' and '#7dff9fff' or '#c8c8c8ff')
  end
  if enBtn then
    enBtn:setColor(currentLang == 'en' and '#7dff9fff' or '#c8c8c8ff')
  end
end

local function fillTopics()
  if not window then return end
  local list = window:recursiveGetChildById('topicList')
  if not list then return end
  local pack = langPack()
  local prev = currentTopic
  list:destroyChildren()

  local focusChild = nil
  for _, id in ipairs(TOPICS) do
    local topic = pack.topics[id]
    if topic then
      local row = g_ui.createWidget('SystemsGuideTopicRow', list)
      row.topicId = id
      local title = row:getChildById('title')
      if title then
        title:setText(topic.title)
        title:setColor(TOPIC_MENU_COLOR[id] or '#e8e0c8ff')
      end
      if id == prev then
        focusChild = row
      end
    end
  end

  if focusChild then
    focusChild:focus()
  elseif list:getChildCount() > 0 then
    list:getChildByIndex(1):focus()
  end
end

local function showTopic(topicId)
  if not window then return end
  currentTopic = topicId or currentTopic or 'overview'
  if currentTopic == 'helperBot' then
    currentTopic = 'helperStart'
  end
  local pack = langPack()
  local topic = pack.topics[currentTopic] or pack.topics.overview
  local title = window:recursiveGetChildById('articleTitle')
  local tag = window:recursiveGetChildById('articleTag')
  local body = window:recursiveGetChildById('articleBody')
  local scroll = window:recursiveGetChildById('articleScroll')

  if title then
    title:setText(topic.title or '')
    title:setColor(TOPIC_MENU_COLOR[currentTopic] or '#ffd76aff')
  end
  if tag then tag:setText(topic.tag or '') end
  if body then
    local panel = window:recursiveGetChildById('articleScrollPanel')
    local w = 560
    if panel then
      w = math.max(320, panel:getWidth() - 4)
      body:setWidth(w)
    end
    applyBodyText(body, topic.body or '', w)
  end
  if scroll and scroll.setValue then
    scroll:setValue(0)
  end
end

function onTopicSelected()
  if not window then return end
  local list = window:recursiveGetChildById('topicList')
  if not list then return end
  local focused = list:getFocusedChild()
  if focused and focused.topicId then
    showTopic(focused.topicId)
  end
end

function setLanguage(lang)
  if lang ~= 'pt' and lang ~= 'en' then return end
  currentLang = lang
  if g_settings then
    g_settings.set(SETTINGS_KEY, currentLang)
    g_settings.save()
  end
  refreshChrome()
  fillTopics()
  showTopic(currentTopic)
end

function toggle()
  if window and window:isVisible() then
    hide()
  else
    show()
  end
end

function show(topicId)
  if not g_game or not g_game.isOnline or not g_game.isOnline() then
    return
  end
  if not window then
    window = g_ui.displayUI('systems_guide')
  end
  if not window then return end

  if g_settings then
    local saved = g_settings.getString(SETTINGS_KEY)
    if saved == 'pt' or saved == 'en' then
      currentLang = saved
    end
  end

  currentTopic = topicId or currentTopic or 'overview'
  refreshChrome()
  fillTopics()
  showTopic(currentTopic)
  window:show()
  window:raise()
  window:focus()
end

function hide()
  if window then
    window:hide()
  end
end

function init()
  if g_settings then
    local saved = g_settings.getString(SETTINGS_KEY)
    if saved == 'pt' or saved == 'en' then
      currentLang = saved
    end
  end
  connect(g_game, {
    onGameEnd = hide,
  })
end

function terminate()
  disconnect(g_game, {
    onGameEnd = hide,
  })
  if window then
    window:destroy()
    window = nil
  end
end
