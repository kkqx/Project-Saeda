# Project Saeda — protótipo

Plataforma 2D em Godot 4.x (testado na 4.3) com o dash como mecânica central.

## Como abrir
1. Extraia o `.zip`.
2. Na Godot, clique em **Importar** e escolha o arquivo `project.godot`.
3. Aperte **F5**. O jogo abre na tela inicial.

## Controles
| Ação | Teclado | Controle |
|---|---|---|
| Mover / navegar nos menus e no mapa | Setas / WASD | Direcional / analógico |
| Pular / confirmar / entrar na fase | Z / Espaço / K / Enter | A |
| Dash (8 direções) | X / Shift / J | X ou B |
| Pausar (fase) / voltar (mapa → título) | Esc | — |

As teclas ficam em `scripts/input_setup.gd`.

## Fluxo do jogo
**Título → Mapa de fases → Fase → (concluiu) volta ao Mapa**

- **Tela inicial**: arte da Saeda com o cabelo balançando (shader) e menu INICIAR / SAIR.
- **Mapa de fases** (no estilo do Super Mario World e do mapa do Celeste): a Saeda anda pelos caminhos entre as fases com o direcional; dá para voltar no meio do caminho. Z entra na fase. Ao concluir uma fase, o caminho para a próxima se acende. O painel de baixo mostra o nome da fase e, nas já concluídas, memórias e melhor tempo.
- **Progresso salvo** automaticamente (`user://project_saeda.cfg`). Para zerar, apague esse arquivo ou chame `Game.reset_progress()`.

## O que tem
- **Fases abertas**: sem paredes nem teto de blocos. Quem limita a visão é a câmera, e paredes invisíveis só impedem de sair do mapa.
- **Personagem** com sprites próprios; as poses se misturam com um crossfade por shader (`shaders/pose_blend.gdshader`), mais inclinação ao correr, balanço de passo, respirar parada, squash/stretch no pulo, pouso e dash, e rastro do dash. Fica azulada quando o dash está gasto. A física usa interpolação (`physics_interpolation`), então o movimento fica liso em monitores acima de 60 Hz.
- **HUD limpa**: nada fixo na tela. O contador de memórias aparece por um instante, as dicas surgem só quando você chega perto, e o resumo só aparece ao concluir a fase.
- **Cenário pós-apocalíptico**: cidade abandonada tomada pela vegetação ao fundo (parallax), concreto com musgo, ferragem enferrujada. Sem partículas flutuando no fundo.
- **Checkpoints** (lamparinas): ao morrer, você volta da última acesa.
- Pulo variável, coyote time, jump buffer, wall slide/jump, dash com freeze frame, cristais que recarregam o dash.

## As fases
| Fase | Nome | Foco |
|---|---|---|
| 1 | Praia | primeiros passos: andar, pular, primeiro dash, buracos seguros |
| 2 | Torres Médias | chaminé de wall jump, ilhas sobre fosso de ferragem, descida em degraus e dash final |
| 3 | Cidade | pulo+dash sobre fossos, ilhas em zigue-zague com cristais, corredor baixo e chaminé final |

O 4º ponto do mapa ("???") é um espaço reservado para a próxima fase.

## Áudio
`scripts/sfx.gd` (autoload `Sfx`) toca os efeitos e a música em loop de `assets/audio/`.
Para tocar um som: `Sfx.play("dash")`. Volume da música: `Sfx.set_music_volume(-12.0)`.

## Estrutura
```
project.godot
scenes/   title.tscn  world_map.tscn  main.tscn (fase)  player.tscn
scripts/  game.gd (autoload: progresso e troca de cenas)  title.gd  world_map.gd
          level.gd  player.gd  player_sprite.gd  pickup.gd  input_setup.gd
shaders/  hair_sway.gdshader  pose_blend.gdshader
assets/   title/ (arte do menu)  sprites/ (personagem)  bg/ (fundo da fase)
          map/ (mapa de fases: overworld.png, node_icons.png, marker.png, map_data.json)
levels/   level_1.txt  level_2.txt  level_3.txt   <- mapas das fases, em texto
```

## Fases com TileSet e TileMap (editor da Godot)
As 3 fases agora são cenas `levels/level_N.tscn`, pintadas com o TileSet `assets/tiles/tileset.tres`.
Abra a cena na Godot e pinte com a aba **TileMap**:
- **Chao** (TileMapLayer): blocos de concreto (use o modo **Terreno** e eles se encaixam sozinhos, com musgo em cima) e espinhos.
- **Objetos** (TileMapLayer): marcadores de início (P), checkpoint, cristal de dash, memória (fadinha azul) e **porta de chegada**. No jogo esta camada fica invisível e vira os objetos de verdade.
- **Dicas** (Node2D): coloque nós `Label` com o texto; eles aparecem quando o jogador chega perto.
O que cada tile significa vem do dado customizado `kind` do TileSet (`ground`, `spike`, `start`, `checkpoint`, `crystal`, `berry`, `door`). A origem da fase é o tile (0, 0).
Para registrar uma fase nova, aponte `LEVELS` em `scripts/game.gd` para o `.tscn`.
Os arquivos de texto continuam funcionando; para converter um deles em cena:
`godot --headless --script res://tools/txt_para_tilemap.gd -- res://levels/level_4.txt res://levels/level_4.tscn`

## Criando uma fase nova
1. Copie um `levels/level_N.txt` e edite (legenda abaixo).
2. Em `scripts/game.gd`, adicione uma linha em `LEVELS` (`name`, `subtitle`, `path`).
3. Em `assets/map/map_data.json`, troque o `"level": -1` do nó "???" pelo número da fase (começa em 0), ou adicione um nó e um caminho (`edges`) novos.

## Editando uma fase (`levels/level_N.txt`)
Cada caractere é um bloco de 8x8 px.

| Caractere | Significado |
|---|---|
| `#` | bloco sólido |
| `^` | ferragem (mata ao encostar) |
| `P` | posição inicial |
| `K` | checkpoint |
| `C` | cristal de dash |
| `S` | memória (fadinha azul; vai formando uma coroa em volta da cabeça) |
| `F` | porta de chegada |
| `.` | vazio |

Depois de uma linha `---` ficam as dicas escritas no cenário, no formato `coluna,linha,texto`
(a dica aparece quando o jogador se aproxima).

## Ajustando o "feeling"
Ajuda nas quinas (`_forgive_corners` em `scripts/player.gd`): bater a cabeça na quina do teto empurra de lado e
pulo/dash que raspa na beirada de uma plataforma sobe até 4 px. Mude `CORNER_FORGIVE` (0 desliga).

Os valores de movimento são `@export` em `scripts/player.gd`: selecione o nó **Player** e mexa no Inspetor
(velocidade, gravidade, altura do pulo, velocidade e duração do dash etc.). A caixa de colisão tem 7x16 px e
o sprite tem cerca de 18 px de altura (`sprite_height`).

## Próximos passos sugeridos
Sons e música, mais fases, animação de wall slide, animação de morte.

## Novidades

- **Mecânicas novas**: `B` mola, `D` bloco que desmorona, `H`/`V` plataformas móveis (horizontal/vertical).
- **Opções** (título e pausa): volume de música/efeitos, tela cheia, dash infinito e velocidade do jogo (modo de ajuda).
- **Fundos por fase**: definidos em `scripts/game.gd` (chaves `bg` e `sky`).
- **Log de teste**: mortes e eventos ficam em `user://playtest_log.txt`.
- **Exportar**: `export_presets.cfg` traz Windows, Linux e Web. Instale os export templates do Godot 4.3 e use Projeto > Exportar.
- Ícone: `icon.svg`.

## Música e abertura

- Músicas em `assets/music/` (.ogg): `dusty_horizon` (título, abertura, mapa e Praia), `ultima_luz` (Torres Médias e Cidade) e `last_light` (Pontes). A faixa de cada fase é a chave `"music"` em `scripts/game.gd`; `Sfx.play_music("dusty")` troca de faixa.
- NOVO JOGO passa pela cena de abertura (`scenes/intro.tscn`, `scripts/intro.gd`): Saeda acorda na floresta perto da praia enquanto as memórias vão embora. Enter/Z/Esc pula. As poses dela acordando ficam em `assets/intro/wake_*.png`.

## Memórias

As memórias (antes morangos) são fadinhas azuis espalhadas pelas fases. Cada uma pega entra numa coroa que gira em volta da cabeça da Saeda, e as de fases já concluídas continuam lá nas próximas. A tela inicial é animada: o cabelo balança, a imagem respira e memórias flutuam pela tela.

## Final do jogo

- Depois de concluir as 4 fases, a porta nas montanhas do mapa (nó 5) aparece. Ela só abre se **todas as memórias** das fases foram recuperadas (o mapa avisa quando faltam).
- Ao entrar pela primeira vez, toca a cena do despertar (`scripts/awakening.gd`): luz azul, o olho verde acende e ela ganha **dash infinito**.
- A fase **Montanha** (`levels/level_5.txt`) é uma subida vertical com dash infinito (`"infinite_dash": true` em `scripts/game.gd`). No topo está o gatinho; ao encontrá-lo, vai para os créditos (`scripts/credits.gd`, lista `CREDITS` editável).

## Poder da fase final (atualizado)

- A cutscene do despertar toca **toda vez** que você entra na Montanha (Enter pula). Os olhos se abrem com os quadros de `assets/intro/eye_*.png`, o iris acende em verde e ela faz uma demonstração de dashes verdes.
- O dash infinito dura `POWER_TIME` segundos (20, em `scripts/game.gd`), com barra e contagem no topo. Ao acabar, pegue uma **memória verde** (fadinha verde) para despertar de novo. O rastro do dash é verde enquanto o poder está ativo.
- As fadinhas (azul = memória, verde = poder) usam `assets/sprites/fairy_*.png`; o cristal de dash segue o seu desenho; a mola virou uma **planta saltitante** (`scripts/spring.gd`).

## Animação de andar

O ciclo de andar agora tem 8 quadros (`assets/sprites/walk1..8.png`): os pés fazem passada de verdade (um sobe e balança para frente enquanto o outro empurra para trás), com o corpo subindo a cada passo. Para refinar, troque os PNGs (72x112, pés alinhados na base) mantendo os nomes.

## Despertar rápido (memória verde)

Ao pegar uma memória verde, toca `scripts/persona_flash.gd` (menos de 1 s): a tela corta para preto, uma faixa mostra os olhos dela em close em tons de verde, linhas de velocidade cruzam, um símbolo angular pisca no canto e a faixa fecha. O jogo fica em câmera lenta só durante o efeito.

## Tela inicial nova e gatinho preto
- A tela inicial agora é o campo de flores azuis (`assets/title/title_flores.png`), com as memórias (fadinhas azuis) subindo sobre ela. A tela antiga (retrato) continua no jogo.
- Em **OPÇÕES → TELA INICIAL** dá para alternar entre NOVA e ATUAL (a antiga); a escolha fica salva.
- O gatinho da fase final e dos créditos usa `assets/cat/cat.png` (4 quadros de 72x64: parado, parado 2, piscando, feliz com brilhos).

## Créditos e fases
- Créditos: logo nova (`assets/title/logo_flores.png`) no lugar do texto "PROJECT SAEDA"; removidas as linhas com nomes de autoria.
- Fases: sem o banner com o nome da fase e sem dicas de texto, exceto na primeira fase (Praia), que mostra só os comandos básicos: andar e dash.
