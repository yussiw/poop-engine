# Chart Editor — eventos

Esta revisão adiciona uma aba **Eventos** ao Chart Editor e execução de eventos na gameplay.

## Controles

1. Abra a aba **Eventos** no painel direito.
2. Posicione a linha de reprodução no instante desejado.
3. Toque em **Adicionar evento**.
4. Toque em **Tipo** para alternar entre Zoom, Camera Focus, Camera Move, HUD Visibility, BPM Change e Character Change.
5. Use **Valor 1** e **Valor 2** para ajustar os parâmetros. Em Character Change, Valor 1 percorre os personagens encontrados em `data/characters` e Valor 2 alterna Jogador/Oponente.
6. Selecione eventos pelos marcadores na grade ou pelos botões Anterior/Próximo. Mova em um passo quantizado ou exclua.
7. Salve o chart. Os eventos são serializados no campo `song.events`.

## Formato salvo

Cada evento tem `time` em milissegundos, `type`, `value1` e `value2`.

Tipos implementados no runtime:
- `Zoom`: `value1` é o zoom da câmera.
- `Camera Focus`: `value1` é `player` ou `opponent`.
- `Camera Move`: `value1` e `value2` são as coordenadas X/Y do alvo da câmera.
- `HUD Visibility`: `value1` é `true`/`false`; `value2` pode ser `all`, `health`, `score`, `notes` ou `strums`.
- `BPM Change`: `value1` é o novo BPM.
- `Character Change`: `value1` é o ID do personagem; `value2` é `player` ou `opponent`.

Os eventos também disparam o callback de script `onEvent(type, value1, value2)`.
