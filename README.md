# Rapstar

Jogo de gerenciamento de carreira musical, feito em Godot 4.7 (GDScript), para desktop.

## Estrutura

```
assets/theme/       Tema visual da interface
data/               game_balance.tres (valores) e collaborators.tres (colaboradores)
scenes/             main.tscn, screens/ (uma cena por tela) e components/
scripts/
  core/             GameManager (autoload), ActionResult, Fmt
  definitions/      Formato dos dados configuráveis (trabalhos, formatos, colaboradores, regras)
  models/           Dados da carreira: CareerData, SongData, AlbumData, ScheduledRelease...
  systems/          Regras: tempo, semana, trabalho, música, nota, álbum, lançamento,
                    desempenho, economia, capas, save e migração
  ui/               Navegação, tabela reutilizável, componentes e script de cada tela
tests/              Testes das regras, sem interface, e um save v1 real em fixtures/
```

**Fluxo:** a tela chama um método do `GameManager`, ele aciona o sistema certo e emite
`career_changed`, e as telas abertas se atualizam. Só os sistemas alteram a `CareerData`.

## Como estender

| Para adicionar | Onde |
| --- | --- |
| Trabalho, ou mudar preços e valores iniciais | `data/game_balance.tres` (pelo Inspector do Godot) |
| Produtor, beatmaker ou feat, e seus atributos | `data/collaborators.tres` |
| Custo de um colaborador | `cost` em `data/collaborators.tres` |
| Ação ou resultado de marketing, e os parâmetros da expectativa | `data/marketing.tres` |
| Pesos da nota, custo e limite das melhorias | `song_quality` em `data/game_balance.tres` |
| Formato de projeto | Nova entrada em `album_formats` em `data/game_balance.tres` |
| Atributo de música (gênero, duração...) | `SongData`: campo, `to_dict` e `from_dict` |
| Algoritmo de streams e vendas | `scripts/systems/performance_system.gd` |
| Cálculo da nota das músicas | `scripts/systems/song_quality_system.gd` |
| Evento, despesa, show... | Nova etapa em `WeekSystem.process_week` |
| Campo que muda o formato do save | Aumente `SAVE_VERSION` e adicione a conversão em `save_migration.gd` |

## Saves e capas

Ficam em `%APPDATA%\Rapstar\saves\` (e não em `res://`, que é somente leitura no `.exe`):

- `career.json`: o save, em JSON legível.
- `covers/`: as capas, recortadas em quadrado e convertidas para WEBP. O save guarda só o nome
  do arquivo, que vem do conteúdo da imagem. Capas que deixam de ser usadas continuam na pasta.
- `career.json.v1.bak`, `career.json.v2.bak`: cópia do save original, criada ao migrar de uma versão antiga.

## Testes

```bash
godot --headless --path . --script res://tests/test_core.gd
```

```bash
godot --headless --path . --script res://tests/test_music.gd
```

```bash
godot --headless --path . --script res://tests/test_song_attributes.gd
```

```bash
godot --headless --path . --script res://tests/test_marketing.gd
```

## Regras do sistema musical

**Nota da música (0 a 100):** Beat (30%), Produção (25%), Vocal (20%), Letra (15%) e participações
(10%). Beat, Produção e participações usam a média do talento do time, mais um bônus por colaborador
extra. Sem colaboradores, cada uma vale 50, e Vocal e Letra partem de 50. Times menos consistentes
variam mais para cima ou para baixo. Essa variação é sorteada uma vez na criação, então editar não
sorteia a nota de novo.

**Melhorias:** cada atributo evolui sozinho, com botão e custo próprios, e soma de 2 a 4 pontos, até
15 pontos acima da nota base dele, sem passar de 100. A energia volta por completo a cada semana.
Editar e melhorar só valem antes do lançamento.

| Atributo | Energia | Dinheiro |
| --- | --- | --- |
| Vocal | 20 | $50 |
| Letra | 15 | $25 |
| Beat | 20 | $75 |
| Produção | 25 | $100 |

**Colaboradores:** cada produtor, beatmaker e feat tem um custo, pago ao entrar na música e mostrado
antes de confirmar. Ao editar, só quem é novo na música é pago. Remover não dá reembolso, e
recontratar paga de novo. Cada pagamento vira uma linha do histórico financeiro.

**Projetos:** podem ser criados vazios e ganhar músicas ao longo da carreira. O mínimo só é exigido
para lançar ou agendar.

| Formato | Para lançar | Produção | Lançamento | Vendas | Fama | Reputação |
| --- | --- | --- | --- | --- | --- | --- |
| EP | 3 a 6 | $100 + $20 por música | $75 | x0,6 | x0,8 | x1 |
| Álbum | 7 a 20 | $200 + $25 por música | $150 | x1 | x1 | x1 |
| Mixtape | 3 a 20 | $50 + $10 por música | $40 | x0,4 | x1,2 | x0,5 |

- A nota do projeto é a média das músicas, e projetos não recebem melhorias próprias.
- Um projeto agendado não pode ficar abaixo do mínimo: é preciso cancelar o agendamento antes.
- Antes do lançamento, melhorar ou editar uma faixa atualiza a média.
- Uma música só pode entrar em um projeto, mesmo que já tenha sido lançada.
- Faixas inéditas saem junto com o projeto e rendem como parte dele, sem streams próprios.
- Ao editar, paga-se só o que passar do custo já pago. Remover músicas não dá reembolso.

**Agenda:**

- O custo é pago ao agendar e devolvido ao cancelar. Remarcar é gratuito.
- O lançamento acontece no processamento da semana marcada e rende a partir da semana seguinte,
  como um lançamento imediato.
- Se uma faixa com single agendado sair antes em um projeto, o single é cancelado e reembolsado.
- O formato de um projeto agendado só muda depois de cancelar o agendamento.

**Marketing (singles):** a campanha é montada na tela de Marketing da música.

- Ações ficam planejadas até o agendamento, que paga lançamento e marketing juntos.
- Com a música já agendada, uma ação nova é paga na hora e começa com menos tempo que as outras.
- Cada ação tem uma duração ideal. Menos tempo reduz o rendimento, e tempo demais também.
- A expectativa depende das ações, do tempo, da qualidade, da fama, da quantidade de ações e do
  alcance.
- Cancelar devolve só o custo do lançamento. O marketing pago continua valendo para um novo
  agendamento, e ações pagas não saem da campanha.
- No lançamento, um sorteio define o resultado: abaixo do esperado, normal, muito bom ou oportunidade
  inesperada. Ele gera alcance, expectativa, pré-saves, novos fãs, exposição, popularidade e potencial.
- Do resultado, só o potencial afeta o jogo por enquanto: multiplica os streams em até 1,5x na
  primeira semana, e o bônus cai 30% por semana. Os demais dados ficam guardados para sistemas futuros.

**Reputação:** muda só ao lançar. Qualidade acima de 50 aumenta, abaixo de 50 diminui.

**Desempenho:** cai 10% por semana, até o piso de 10%.

**Saves antigos:** todo o progresso é mantido, e cada música mantém a nota geral. Colaboradores já
presentes não são cobrados. Na v1, álbuns não lançados com 3 a 6 músicas viram EP, e os já lançados
não mudam. Na v2, Beat, Produção e participações são mantidos sempre que possível, e Vocal e Letra
recebem o valor que completa a mesma nota.
