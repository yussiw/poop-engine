# Poop Engine (Haxe / HaxeFlixel)

Engine inspirada na Kade Engine (chart no formato vanilla/Kade, julgamento sick/good/bad/shit, ghost tapping),
feita pra Android: **hitbox** no gameplay e **gestos** nos menus. Compila pelo GitHub Actions
(`.github/workflows/build.yml` -> artefato `PoopEngine-apk`).

## Controles
- Visual identico ao da Kade/vanilla (strums oponente esq / jogador dir, healthbar, icones, score, rating popup, pausa, game over). So o input muda.
- Gameplay: hitbox invisivel com 4 faixas verticais da tela inteira (esq/baixo/cima/dir). Toque na faixa = aperta a seta; segure pros holds.
  Pra ver as faixas piscando: `Controls.showHitbox = true` em `source/Controls.hx`.
- Pause: botao voltar do Android (ou tocar no cantinho superior direito, invisivel).
- Menus: deslizar cima/baixo = navegar, toque no item selecionado = confirmar, deslizar pra direita / voltar = voltar.
- PC (teste): D F J K, setas, ENTER, ESC.

## Como moddar (tudo e dado, quase nada precisa de codigo)
| O que | Onde |
|---|---|
| Musicas no menu | `assets/data/songlist.json` |
| Musica (chart) | `assets/songs/<id>/chart.json` + `Inst.ogg` + `Voices.ogg` (opcional) |
| Script da musica | `assets/songs/<id>/script.hx` (HScript) |
| Modchart da musica | `assets/songs/<id>/modchart.hx` (HScript; veja o exemplo em `assets/songs/demo/modchart.hx`) |
| Script global / de stage | `assets/scripts/global.hx`, `assets/stages/<stage>.hx` |
| Personagens | `assets/data/characters/<id>.json` (imagem, animacoes, offsets, icone, cor da barra) |
| Stages | `assets/data/stages/<id>.json` (lista de sprites, zoom, posicao de bf/dad) |
| Sprites/sons | `assets/images`, `assets/sounds`, `assets/music` |

### Mods (pasta externa, no estilo da Codename Engine Mobile)
Cada mod e uma **subpasta** dentro de `mods/`, com a mesma estrutura de `assets/` (sem o prefixo `assets/`):

```
<pasta externa>/mods/MeuMod/data/characters/bf.json
<pasta externa>/mods/MeuMod/songs/minha-musica/chart.json
<pasta externa>/mods/MeuMod/images/menus/menuBG.png
```

- **Android:** `/storage/emulated/0/.PoopEngine/mods/` (raiz do armazenamento, igual `.CodenameEngine`/`.PsychEngine`).
  Na primeira abertura o app pede "acesso a todos os arquivos" (Android 11+) ou a permissao de armazenamento; depois de conceder, a pasta e criada sozinha.
- **PC:** `mods/` ao lado do executavel.
- O caminho exato aparece no canto superior direito do menu principal quando nao ha mods.
- **Escolher o mod:** no menu principal, deslizar pra esquerda (ou TAB no PC) abre a tela de selecao (base + cada pasta de `mods/`).
  Deslize cima/baixo, toque no item selecionado pra aplicar, deslize pra direita pra voltar. O mod escolhido fica salvo.
- **Recarregar:** no menu principal, deslizar pra direita (ou R no PC) re-escaneia a pasta de mods. Se nao houver mods (ou faltar permissao),
  uma faixa de aviso aparece no rodape do menu.
- Arquivo no mod ativo substitui o do jogo base com o mesmo caminho. Pra uma musica aparecer no Freeplay,
  o mod precisa do seu proprio `data/songlist.json` (ele substitui o da base).
- **Mod template:** `example_mods/TemplateMod` (musica nova com `Inst.ogg`, personagem, stage, fundo do Freeplay e script). Copie a pasta inteira pra `mods/`; o `LEIA-ME.txt` dentro explica cada arquivo.
- Tem um mod de teste em `example_mods/ExampleMod` (copie a pasta inteira pra `mods/`).

### Editor de chart
Toque em **[ EDITOR DE CHART ]** no canto superior esquerdo do menu principal (ou tecla E no PC). Escolha uma musica ou "+ nova musica".
Visual minimalista com fonte normal (`assets/fonts/ui.ttf`, so o editor usa; o resto do jogo continua com a vcr).

- **Grade quadrada:** cada celula = 1 step de altura x 1 coluna de largura. Notas e receptores ocupam a celula inteira, entao a nota encaixa certinho no receptor quando passa pela linha branca. O **zoom** (75% a 150%) escala a grade toda, entao ela continua quadrada. Linhas: fina = step, media = beat (4 steps), grossa = secao (16 steps); o **snap** (1/4 a 1/64) soma linhas de subdivisao.
- **Linha do tempo continua** (como a Codename): a grade rola sem divisao de secoes; os receptores ficam fixos na linha branca e a musica passa por eles no PLAY.
- **Colunas absolutas:** esquerda = OPONENTE, direita = JOGADOR. A faixa colorida a esquerda da grade e o **foco da camera** de cada secao (azul = jogador, rosa = oponente); toque nela (ou em *Camera* na aba Secao) pra alternar. Ao salvar, o editor converte tudo pro formato Kade/vanilla (`mustHitSection`) sem mudar nenhuma nota de lado.
- **Painel esquerdo (sempre visivel):** Reproduzir/Pausar, tempo, Inicio / Secao anterior / proxima, ferramenta (**Nota**, **Selecao**, **Caixa**), Snap, Zoom, Desfazer/Refazer, Copiar/Colar/Apagar e mover a selecao (setas). Botoes que nao se aplicam (ex.: Copiar sem selecao) ficam apagados.
- **Painel direito (3 abas):** **Secao** (camera, copiar da anterior, selecionar secao, limpar secao), **Audio** (metronomo, som ao passar nas notas, vozes, instrumental), **Musica** (BPM e velocidade).
- **Topo:** voltar, **Testar** (salva e abre a musica) e **Salvar** (grava em `<mod ativo>/songs/<id>/chart.json` e inclui a musica no `songlist.json` do mod). **Barra da direita** = minimapa da musica inteira (arraste pra pular pra qualquer ponto).
- **Nota:** toque = poe/tira nota; arraste uma nota **pra baixo** = sustain; arraste no vazio = rola (com inercia). **Selecao:** toque marca/desmarca. **Caixa:** arraste um retangulo.
- Eventos (lane -1) e notas fora da grade de charts importados ficam guardados e **voltam no arquivo ao salvar** (nao aparecem na grade).
- Precisa de um mod ativo pra salvar (a base e somente leitura). Musica nova recebe o id `nova-musica-N`; ponha seu `Inst.ogg` em `songs/<id>/`.
- PC: ESPACO play, setas = rolar/secao, 1-8 poe nota no playhead, Ctrl+Z / Ctrl+Y / Ctrl+S / Ctrl+C / Ctrl+V, DELETE, roda do mouse.

### Transicoes (TransitionSubState)
`source/states/TransitionSubState.hx`: cortina preta com borda em degrade que desce cobrindo a tela e, na tela nova, desce de novo revelando. Use
`TransitionSubState.go(new MeuState())` no lugar de `FlxG.switchState(new MeuState())`. A parte de "entrada" abre sozinha (gancho em `Main`).
Funciona tambem a partir de um substate (ex.: sair da pausa). Duracao em `TransitionSubState.DURATION`.

### Chart (formato Kade/vanilla)
`{"song":{"bpm":102,"speed":2,"player1":"bf","player2":"dad","stage":"default","notes":[{"mustHitSection":true,"sectionNotes":[[tempoMs, lane0-7, duracaoHoldMs]]}]}}`

### Hooks de script
`onCreate, onCreatePost, onSongStart, onUpdate(elapsed), onStepHit(step), onBeatHit(beat), onNoteHit(note, rating), onOpponentHit(note), onMiss(note)`
Variaveis: `game` (PlayState), `FlxG, FlxSprite, FlxTween, FlxEase, Paths, Conductor, Math, Std, rgb(r,g,b), add(), addHUD(), remove()`.

## Android: aparelhos antigos e novos
Configurado em `Project.xml`:
- **targetSdk 35 / minSdk 21** (Android 5.0+). O aviso do Play Protect "app criado para uma versao antiga do Android" aparece quando o target esta mais de 2 niveis abaixo do Android do aparelho; com 35 ele some em aparelhos ate o Android 17.
  Se o Gradle do CI reclamar do SDK 35, troque `target-sdk-version` pra 34 (cobre ate o Android 16).
- **arm64 + armv7:** o Lime 8.1.2 so gera arm64 por padrao, o que deixaria de fora aparelhos 32 bits antigos. Os dois sao gerados (o build demora mais). Pra emulador x86_64, acrescente `<architecture name="x64" if="android" />`.
- Permissoes `READ_MEDIA_*` declaradas (Android 13+); `MANAGE_EXTERNAL_STORAGE` continua pra pasta de mods.
- Obs.: em aparelhos que usam paginas de memoria de 16 KB, o Android pode avisar sobre bibliotecas nativas nao alinhadas. Resolver isso pede Lime 8.3+ (NDK r28c); o workflow atual segue no Lime 8.1.2 / NDK r21e.

## Observacoes
- `assets/images/characters/dad.png` veio sem `dad.xml`, entao o oponente de exemplo usa o sprite do BF espelhado.
- A musica demo usa `music/freakyMenu.ogg` (102 BPM) como Inst, pois o zip nao tinha musicas de verdade.
- Mudancas de BPM no meio da musica nao sao suportadas (as notas funcionam, so o "bop" de camera/icones nao acompanha).
- Story Mode / Options / Credits abrem uma tela "Em breve" (o zip nao tinha os assets dessas telas). Sem downscroll; hold sem "cap" final.
