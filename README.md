# Rapstar

Jogo de gerenciamento de carreira musical, feito em Godot 4.7 (GDScript), para desktop.

## Estrutura

```
assets/theme/       Tema visual (cores, botões, painéis, abas, tabelas, fontes de destaque)
assets/icons/       Ícones SVG do menu, dos indicadores e das caixas de seleção
data/               game_balance.tres (valores) e collaborators.tres (colaboradores)
scenes/             main.tscn, screens/ (uma cena por tela) e components/
scripts/
  core/             GameManager (autoload), ActionResult, Fmt
  definitions/      Formato dos dados configuráveis (trabalhos, formatos, colaboradores, regras)
  models/           Dados da carreira: CareerData, SongData, AlbumData, ScheduledRelease...
  systems/          Regras: tempo, semana, trabalho, música, nota, álbum, lançamento,
                    desempenho, economia, capas, save e migração
  ui/               GameShell (menu lateral + barra de status), tabela reutilizável,
                    componentes e script de cada tela
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
| Plataforma, trajetória de sucesso, descoberta e vazamentos | `data/streaming.tres` |
| Sample | `data/samples.tres` |
| Opção de produção de videoclipe, prazo, risco e desempenho | `data/videos.tres` |
| Cidade, local, produção, equipe, merch, festival, patrocinador, tipo de turnê e regras ao vivo | `data/live.tres` |
| Ações sociais, descontos por amizade, convites e regras de beef | `data/social.tres` |
| Carro da concessionária (marca, modelo, ano, categoria, preço, imagem em `assets/cars/`) | `data/vehicles.tres` |
| Artista (nota, cachê-base de feat, país, nível) | `feats` em `data/collaborators.tres` |
| Fase da carreira (nome, fama mínima, descrição) | `career_stages` em `data/game_balance.tres` |
| Item do menu lateral | `NAV` em `scripts/ui/game_shell.gd` |
| Cores, botões e painéis | `assets/theme/default_theme.tres` |
| Peça de aparência (pele, cabelo, barba, roupa, acessório...), países e idades | `data/character.tres` (estilo novo: uma função de desenho em `character_view.gd`) |
| Pesos da nota, custo e limite das melhorias | `song_quality` em `data/game_balance.tres` |
| Formato de projeto | Nova entrada em `album_formats` em `data/game_balance.tres` |
| Atributo de música (gênero, duração...) | `SongData`: campo, `to_dict` e `from_dict` |
| Algoritmo de streams e vendas | `scripts/systems/performance_system.gd` |
| Cálculo da nota das músicas | `scripts/systems/song_quality_system.gd` |
| Evento, despesa, show... | Nova etapa em `WeekSystem.process_week` |
| Campo que muda o formato do save | Aumente `SAVE_VERSION` e adicione a conversão em `save_migration.gd` |

## Saves e capas

Ficam em `%APPDATA%\Rapstar\saves\` (e não em `res://`, que é somente leitura no `.exe`):

- `career_<id>.json`: uma carreira por arquivo, em JSON legível. Cada carreira é independente.
  O `career.json` das versões anteriores continua sendo uma carreira da lista.
- `covers/`: as capas, recortadas em quadrado e convertidas para WEBP. O save guarda só o nome
  do arquivo, que vem do conteúdo da imagem. Capas que deixam de ser usadas continuam na pasta.
- `career.json.v1.bak`, `career.json.v2.bak`...: cópia do save original, criada ao migrar de uma versão antiga.

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

```bash
godot --headless --path . --script res://tests/test_streaming.gd
```

```bash
godot --headless --path . --script res://tests/test_videos.gd
```

```bash
godot --headless --path . --script res://tests/test_live.gd
```

```bash
godot --headless --path . --script res://tests/test_character.gd
```

```bash
godot --headless --path . --script res://tests/test_progression.gd
```

```bash
godot --headless --path . --script res://tests/test_social.gd
```

```bash
godot --headless --path . --script res://tests/test_content.gd
```

## Regras do sistema musical

**Nota da música (0 a 100):** Beat (30%), Produção (25%), Vocal (20%), Letra (15%) e participações
(10%). Beat, Produção e participações usam a média do talento do time, mais um bônus por colaborador
extra. Sem colaboradores, cada uma vale 50, e Vocal e Letra partem de 50. Times menos consistentes
variam mais para cima ou para baixo. Essa variação é sorteada uma vez na criação, então editar não
sorteia a nota de novo.

**Melhorias:** cada atributo evolui sozinho e custa só energia: Vocal 20, Letra 15, Beat 20 e
Produção 25. Cada melhoria soma de 2 a 4 pontos, até 15 pontos acima da nota base do atributo, sem
passar de 100. A energia volta por completo a cada semana. Editar e melhorar só valem antes do
lançamento.

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

**Plataformas:** Spotify, Apple Music, Deezer, SoundCloud, YouTube, Loja digital e Rádio.

- Ao sair oficialmente, cada música entra nas plataformas. Em um projeto, cada faixa recebe 30% das
  reproduções de um single, ajustado pelo formato, e o projeto continua vendendo como antes.
- Cada música recebe um público fixo e uma trajetória (hit imediato, fracasso, explosão viral...)
  sorteada uma vez. Qualidade, expectativa, fama e sample pesam no sorteio.
- As reproduções semanais vêm do público, da qualidade, da fama, da trajetória, dos seguidores, do
  momento do lançamento, do marketing e da descoberta, com variação de 10%.
- Cada plataforma valoriza um atributo e paga um valor próprio. A Rádio exige fama 50 ou uma ação de
  Rádio na campanha.
- Reproduções viram ouvintes e seguidores, e cada 500 seguidores novos dão 1 de fama.
- A fama ganha não considera a fama atual, e o bônus de fama tem teto, para o crescimento não
  disparar.

**Vazamentos:** a cada semana, um lançamento agendado tem 2% de chance de vazar, mais até 3% conforme
a expectativa. O vazamento não gera receita nem entra nas plataformas, reduz a expectativa da
campanha e traz alguma atenção. O lançamento oficial continua valendo.

**Samples:** icônicos, reconhecíveis, obscuros ou próprios. Mudam a nota, o interesse do público, a
chance de chamar atenção e podem ter custo. O sample próprio exige escolher qual música será usada.

**Videoclipes:** qualquer música pode ganhar um, inclusive as já lançadas.

- **Montagem:** conceito, escala, locações, direção, equipe, figurantes, dançarinos, figurino,
  cenário, direção visual, participação do artista, edição, efeitos e complexidade.
- **Orçamento e prazo:** a escala multiplica o custo das demais escolhas, e locações extras,
  cenários, efeitos e edição aumentam o prazo. A complexidade multiplica o prazo.
- **Notas e risco:** as escolhas definem técnica, visual, criatividade, identidade, coerência,
  apelo comercial, descoberta, potencial viral e risco.
- **Coerência:** depende de as escolhas combinarem com o conceito, e de o conceito valorizar o
  atributo forte da música.
- **Problemas de produção:** o risco pode atrasar a produção e prejudicar a parte técnica. Escolhas
  muito acima da escala e equipes pequenas para produções complexas aumentam o risco.
- **Lançamento:** automático, junto com a música (ou assim que ficar pronto, se a música já saiu),
  ou em uma data própria. Um videoclipe nunca sai antes da música. A capa é grátis e pode mudar.
- **Desempenho:** metade da nota vem da música e metade do videoclipe, então música fraca não vira
  sucesso só com videoclipe caro.
- **YouTube:** as visualizações entram nele com o valor que ele paga por visualização, viram
  inscritos e dão um bônus de reproduções para a música. O marketing da música ou do projeto amplia
  o início.
- **Vazamento:** tem chance semanal de 3% antes do lançamento oficial. As visualizações vazadas
  ficam separadas e não geram receita. O vazamento pode prejudicar a estreia ou virar burburinho.

**Marketing (singles, EPs, álbuns e mixtapes):** a campanha é montada na tela de Marketing, aberta
pela navegação principal, pela música ou pelo projeto. Ela amplia alcance, público e potencial, mas
não devolve o dinheiro: o retorno depende do desempenho do lançamento.

- Ações ficam planejadas até o agendamento, que paga lançamento e marketing juntos.
- Com a música já agendada, uma ação nova é paga na hora e começa com menos tempo que as outras.
- Cada ação tem uma duração ideal. Menos tempo reduz o rendimento, e tempo demais também.
- A expectativa depende das ações, do tempo, da qualidade, da fama, da quantidade de ações e do
  alcance.
- Cancelar devolve só o custo do lançamento. O marketing pago continua valendo para um novo
  agendamento, e ações pagas não saem da campanha.
- No lançamento, um sorteio define o resultado: abaixo do esperado, normal, muito bom ou oportunidade
  inesperada. Ele gera alcance, expectativa, pré-saves, novos fãs, exposição, popularidade e potencial.
- O potencial multiplica as reproduções em até 1,5x na primeira semana, e o bônus cai 30% por semana.
  A exposição ajuda a descoberta, e os novos fãs viram seguidores.

**Reputação:** muda ao lançar (qualidade acima de 50 aumenta, abaixo de 50 diminui) e nos shows
(show muito bom aumenta, show ruim ou compromisso contratado cancelado diminui).

**Navegação:** dentro de uma carreira, a barra superior mostra o artista, a fase, a semana, o
dinheiro, a fama, os fãs e a energia (com as mudanças aparecendo na hora), e tem "Próxima semana",
que avança e salva automaticamente. O menu lateral leva a todas as áreas. O Início reúne a fase da
carreira, a agenda, os próximos passos e o resumo da última semana.

**Visual:** fundo com luzes de palco, cartões com profundidade, capas geradas (gradiente e vinil
únicos por nome) para músicas, projetos e propostas sem imagem, e o personagem como foto do artista
nas plataformas quando não há foto. Músicas, projetos e propostas de show aparecem como grades de
capas (`CardGrid`/`MediaCard`); detalhes ficam em abas ou sob demanda.

**Carros:** a área Carros tem a concessionária (34 carros, filtro por categoria, foto, preço e quanto
sobra) e a garagem. Cada modelo é comprado uma vez, à vista, e aparece no Início.

**Artistas:** 70 artistas (EUA, Reino Unido e Canadá), do underground a superstar, cada um com seu
cachê-base de feat. O preço final passa pelas relações. Os cachês são valores internos do jogo.

**Relações:** cada artista do catálogo tem uma relação com o jogador (de -100 a 100), com status
de Desconhecido a Melhor amigo, ou de Neutro a Grande rival, e histórico. A confiança cresce no
máximo 12 pontos por semana com cada artista. Amizade barateia feats e participações em shows (melhor
amigo do seu nível faz feat de graça de tempos em tempos; estrelas muito maiores limitam o desconto),
traz convites (faixas, shows, datas de turnê, divulgação) e defesa em conflitos. Inimizade e beef
fazem o artista recusar feats, shows e turnês. Diss tracks são músicas normais com um alvo: ao
lançar, a repercussão depende da nota, o beef escala, o alvo reage (ignora, responde, lança outra
diss ou propõe paz) e os aliados de cada lado tomam partido. Beefs esfriam sem resposta e podem ser
encerrados, voltando a relação a neutro. As relações entre artistas são estáveis por padrão e só as
mudanças ficam no save.

**Fases da carreira:** Desconhecido, Underground, Em ascensão, Relevante, Grande artista e Estrela,
pela fama. Subir de fase aparece no relatório da semana, que também mostra o saldo real de dinheiro,
fama, fãs e streams.

**Personagem e carreiras:** cada carreira tem nome artístico (identidade pública), nome real, idade
(cresce um ano a cada 52 semanas), país, cidade, aparência e a opção de energia infinita. A aparência
é montada por peças independentes de `data/character.tres` e desenhada em camadas pelo
`CharacterView`, no hub, na lista de carreiras, na criação e em Personagem. Trocar a aparência só muda
a aparência e grava no save da carreira. Com energia infinita, as atividades não gastam energia.

**Ao vivo (shows, turnês, festivais e merch):** fica na área "Ao vivo" da navegação principal.

- O calendário é por dia (7 por semana). Dois compromissos não podem cair no mesmo dia, e cidades
  distantes exigem dias de viagem entre as datas.
- O público vem da fama, dos seguidores das plataformas, do mercado e da cena da cidade, do preço,
  da divulgação, da produção e dos convidados. Lotação nunca é garantida. Fora do país, o alcance
  cresce com a fama.
- Despesas do artista são pagas ao confirmar o show ou a turnê. No dia, entram cachê ou bilheteria
  e merch. Shows independentes pagam local e segurança; nos contratados, o contratante paga o local e
  pode pagar transporte e hospedagem. Shows contratados e festivais têm comissão do agente.
- Modelos: cachê fixo, porcentagem da bilheteria, cachê + porcentagem e garantia mínima contra
  porcentagem. O co-headliner fica com parte da receita.
- Turnês: datas em planejamento até a confirmação, com previsão de custos, avisos e conflitos. A
  ordem das cidades muda transporte, hospedagem e desgaste; dias de descanso reduzem o desgaste, que
  baixa a qualidade. Pausar cancela as datas que passarem durante a pausa; cancelar devolve parte das
  despesas das datas futuras. Patrocínios são fechados no planejamento.
- Merch: fabricado e pago antes, com desconto por volume. Só vende com estoque, nos shows (o local
  fica com uma parte) e na loja oficial. Produtos exclusivos de turnê ou show só vendem neles.
- Festivais: uma edição por ano, com lineup próprio formado pelo catálogo de artistas. A posição
  (de Abertura a Headliner) depende da fama em relação ao prestígio do festival, e define cachê,
  público e impacto. Convites chegam em Ofertas; inscrições são respondidas na semana seguinte.
- Cada show gera um relatório (público, ingressos, receitas, despesas, resultado, fãs, fama e
  repercussão), e a turnê concluída gera um relatório consolidado.

**Desempenho:** cai 10% por semana, até o piso de 10%.

**Saves antigos:** todo o progresso é mantido, e cada música mantém a nota geral. Colaboradores já
presentes não são cobrados. Na v1, álbuns não lançados com 3 a 6 músicas viram EP, e os já lançados
não mudam. Na v2, Beat, Produção e participações são mantidos sempre que possível, e Vocal e Letra
recebem o valor que completa a mesma nota. Saves até a v6 começam a carreira ao vivo vazia, e as
edições dos festivais são criadas ao carregar. Saves até a v7 recebem aparência padrão, 20 anos,
país Brasil, nome real e cidade vazios e energia normal. Saves até a v8 começam a rede social vazia. Saves até a v9 começam com a garagem vazia, e saves sem
o campo de Energia Infinita ficam com ela desligada.
