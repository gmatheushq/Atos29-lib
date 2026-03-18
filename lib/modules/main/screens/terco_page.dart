import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class TercoPage extends StatefulWidget {
  const TercoPage({super.key});

  @override
  State<TercoPage> createState() => _TercoPageState();
}

class _TercoPageState extends State<TercoPage> {
  // ===== PALETA (sua) =====
  static const Color vinhoProfundo = Color(0xFF3A0808);
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xEB4E070D);

  static const Color vinhoSelecionado = Color(0xFF560405);

  static const Color paper = Color(0xFFFBFAF8);
  static const Color cardBase = Colors.white;

  static const double rCard = 22;

  Set<String> _misteriosSelecionados = {};
  String? _meditacaoExpandidaChave;

  final ValueNotifier<bool> _lockSheetScroll = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _carregarSelecaoTerco();
  }

  @override
  void dispose() {
    _lockSheetScroll.dispose();
    super.dispose();
  }

  Future<void> _carregarSelecaoTerco() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _misteriosSelecionados =
          (prefs.getStringList('terco_misterios_selecionados') ?? []).toSet();
    });
  }

  Future<void> _toggleSelecaoMist(String grupo, String tituloMist) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = "$grupo|$tituloMist";

    setState(() {
      if (_misteriosSelecionados.contains(chave)) {
        _misteriosSelecionados.remove(chave);
      } else {
        _misteriosSelecionados.add(chave);
      }
    });

    await prefs.setStringList(
      'terco_misterios_selecionados',
      _misteriosSelecionados.toList(),
    );
  }

  Future<void> _limparSelecao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('terco_misterios_selecionados');
    if (mounted) setState(() => _misteriosSelecionados.clear());
  }

  String _getMisterioDoDia() {
    final weekday = DateTime.now().weekday;
    if (weekday == DateTime.monday || weekday == DateTime.saturday) return "Gozosos";
    if (weekday == DateTime.tuesday || weekday == DateTime.friday) return "Dolorosos";
    if (weekday == DateTime.thursday) return "Luminosos";
    return "Gloriosos";
  }
  String _labelMisterioDoDia() {
    final w = DateTime.now().weekday; // 1..7
    final grupo = _getMisterioDoDia();

    final dia = switch (w) {
      DateTime.monday => "segunda",
      DateTime.tuesday => "terça",
      DateTime.wednesday => "quarta",
      DateTime.thursday => "quinta",
      DateTime.friday => "sexta",
      DateTime.saturday => "sábado",
      _ => "domingo",
    };

    return "$grupo • $dia";
  }


  TextStyle get _title => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: vinhoProfundo,
  );

  TextStyle get _subtitle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: Colors.black.withOpacity(0.55),
  );

  TextStyle get _chip => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.1,
    color: vinhoIdentidade.withOpacity(0.95),
  );

  BoxShadow get _softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 22,
    spreadRadius: 0,
    offset: const Offset(0, 10),
  );

  @override
  Widget build(BuildContext context) {
    final recomendado = _getMisterioDoDia();

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: paper,
        foregroundColor: vinhoProfundo,
        centerTitle: true,
        title: const Text(
          "Santo Terço",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        children: [
          _itemGrupo(
            "Gozosos",
            "Segundas e Sábados",
            "assets/images/gozoso.png",
            vinhoDestaque,
            recomendado,
          ),
          _itemGrupo(
            "Dolorosos",
            "Terças e Sextas",
            "assets/images/doloroso.png",
            vinhoIdentidade,
            recomendado,
          ),
          _itemGrupo(
            "Gloriosos",
            "Quartas e Domingos",
            "assets/images/glorioso.png",
            vinhoDestaque,
            recomendado,
          ),
          _itemGrupo(
            "Luminosos",
            "Quintas-feiras",
            "assets/images/luminoso.png",
            vinhoDestaque,
            recomendado,
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: vinhoDestaque.withOpacity(0.06),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: const Icon(Icons.help_outline, color: vinhoIdentidade),
            title: const Text(
              "Como rezar o Terço?",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            trailing: const Icon(Icons.chevron_right, color: vinhoIdentidade),
            onTap: _abrirGuiaComoRezar,
          ),
        ],
      ),
    );
  }

  Widget _itemGrupo(
      String nome,
      String dias,
      String imageAsset,
      Color cor,
      String recomendado,
      ) {
    final isHoje = nome == recomendado;

    const double imgW = 92;
    const double cardH = 115;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHoje ? vinhoIdentidade : cardBase,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(
          color: isHoje ? vinhoIdentidade.withOpacity(0.70) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isHoje ? vinhoIdentidade.withOpacity(0.22) : Colors.black.withOpacity(0.05),
            blurRadius: isHoje ? 26 : 22,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(rCard),
          onTap: () => _mostrarDetalhesMisterio(nome, cor),
          child: SizedBox(
            height: cardH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(rCard),
                    bottomLeft: Radius.circular(rCard),
                  ),
                  child: SizedBox(
                    width: imgW,
                    height: cardH,
                    child: Image.asset(
                      imageAsset,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nome,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isHoje
                                      ? Colors.white.withOpacity(0.96)
                                      : Colors.black.withOpacity(0.82),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: isHoje
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.black.withOpacity(0.35),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dias,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isHoje
                                ? Colors.white.withOpacity(0.82)
                                : Colors.black.withOpacity(0.55),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalhesMisterio(String grupo, Color cor) {
    final Map<String, List<Map<String, String>>> dadosMisterios = {
      "Gozosos": [
        {
          "m": "1º Mistério",
          "t": "A Anunciação do Anjo",
          "f":
          '''"Então Maria disse: "Eis aqui a serva do Senhor, faça-se em mim a tua palavra."" - Lucas 1,38

MEDITAÇÃO: O "Sim" que mudou a história.
1. A Perturbação Santa: O chamado de Deus pode nos assustar, mas traz um propósito maior.
2. O Consentimento: Deus respeita nossa liberdade e espera nossa autorização para agir.
3. O impossível: Quando Deus pede algo, Ele mesmo providencia a força do Espírito Santo para realizar.'''
        },
        {
          "m": "2º Mistério",
          "t": "Visitação de Maria a Santa Isabel",
          "f":
          '''"Aconteceu que, apenas Isabel ouviu a saudação de Maria, o menino saltou no seu ventre, e Isabel ficou cheia do Espírito Santo;
e exclamou em alta voz: "Bendita és tu entre todas as mulheres, e bendito é o fruto do teu ventre.[...]"" - Lucas 1,41-42

MEDITAÇÃO: A caridade que se apressa em servir.
1. O Movimento: Maria não se fecha em sua glória, ela sai de si para ajudar quem precisa.
2. Levar Jesus: A maior caridade de Maria não foi o trabalho manual, mas levar o Salvador no ventre.
3. Reconhecimento: Isabel reconhece a presença de Deus no outro. Você consegue ver Deus no seu próximo?'''
        },
        {
          "m": "3º Mistério",
          "t": "Nascimento de Jesus",
          "f":
          '''"E deu à luz o seu filho primogénito, e o enfaixou, e o reclinou numa manjedoura, porque não havia lugar para eles na estalagem." - Lucas 2,7

MEDITAÇÃO: A humildade do Criador.
1. O Desapego: O Rei do Universo nasce na pobreza para mostrar que o ter não supera o ser.
2. A Acolhida: Não havia lugar na estalagem. Será que há lugar para Jesus em nossa rotina agitada?
3. A Luz na Noite: Jesus nasce no momento mais escuro para ser a luz que guia nossos passos.'''
        },
        {
          "m": "4º Mistério",
          "t": "Apresentação no Templo",
          "f":
          '''"Levaram-no a Jerusalém para o apresentar ao Senhor." - Lucas 2,22

MEDITAÇÃO: A oferta total de si mesmo.
1. Obediência: Maria e José cumprem as leis de Deus com alegria e humildade.
2. O Encontro: Simeão esperou a vida toda por esse momento. A paciência na fé sempre é recompensada.
3. A Espada: O sofrimento faz parte da missão. Entregar algo a Deus exige coragem e sacrifício.'''
        },
        {
          "m": "5º Mistério",
          "t": "Encontro de Jesus no Templo",
          "f":
          '''"Não sabíeis que devo ocupar-me nas coisas de meu Pai?" - Lucas 2,49

MEDITAÇÃO: A busca constante pelo Senhor.
1. A Perda: Às vezes perdemos a sensibilidade da presença de Deus por distração.
2. A Busca: Maria e José nos ensinam que buscar Jesus deve ser nossa prioridade absoluta.
3. O Lugar: Ele sempre nos espera na 'Casa do Pai' - na oração, na Igreja e na Palavra.'''
        },
      ],
      "Dolorosos": [
        {
          "m": "1º Mistério",
          "t": "Agonia no Horto",
          "f":
          '''"Pai, se é do teu agrado, afasta de mim este cálice; não se faça, contudo, a minha vontade, mas a tua." - Lucas 22,42

MEDITAÇÃO: A vitória sobre a vontade própria.
1. A Luta Interna: Jesus sente medo e angústia, mostrando que ser santo não é ser insensível.
2. A Oração: Diante da dor, a resposta de Jesus é intensificar a conversa com o Pai.
3. O Abandono: A paz real vem quando paramos de lutar contra a vontade de Deus e descansamos nela.'''
        },
        {
          "m": "2º Mistério",
          "t": "Flagelação de Jesus",
          "f":
          '''"Pilatos tomou então Jesus e mandou-o flagelar." - João 19,1

MEDITAÇÃO: O reparo pelas nossas faltas.
1. O Sacrifício Corporal: Jesus oferece Sua carne para curar os pecados da nossa carne.
2. O Silêncio: Ele sofre sem reclamar, ensinando a nobreza da paciência nas injustiças.
3. Valor da Pureza: Contemplamos aqui a necessidade de respeitar nosso corpo como templo sagrado.'''
        },
        {
          "m": "3º Mistério",
          "t": "Coroação de Espinhos",
          "f":
          '''"Em seguida, tecendo uma coroa de espinhos, puseram-lha sobre a cabeça, e na mão direita uma cana." - Mateus 27,29

MEDITAÇÃO: A realeza da humildade.
1. O Escárnio: Jesus é zombado por quem Ele veio salvar. Ele suporta a humilhação para curar nosso orgulho.
2. Pensamentos: Os espinhos ferem a cabeça; peçamos a Deus para purificar nossos pensamentos.
3. Verdadeiro Reino: O Reino de Cristo não é deste mundo; não se baseia em poder, mas em serviço.'''
        },
        {
          "m": "4º Mistério",
          "t": "Jesus carregando a Cruz",
          "f":
          '''"Tomaram pois, Jesus, o qual, levando a sua cruz, saiu para o lugar chamado do Crânio (em hebraico Gólgotha)" - João 19,17

MEDITAÇÃO: A persistência no caminho do bem.
1. O Peso: Nossas faltas são o peso daquela cruz. Ele a carrega por amor infinito.
2. As Quedas: Jesus cai, mas levanta. Cair não é o fim, o pecado é não querer levantar.
3. O Auxílio: Cirineu ajuda Jesus. Deus nos chama a sermos alívio na vida de quem carrega fardos pesados.'''
        },
        {
          "m": "5º Mistério",
          "t": "Crucifixão e Morte",
          "f":
          '''"Jesus, exclamando em alta voz, disse: "Pai, nas tuas mãos encomendo o meu espírito." Dizendo isto, expirou." - Lucas 23,46

MEDITAÇÃO: A entrega suprema.
1. O Perdão: Mesmo pregado na cruz, Jesus perdoa Seus carrascos. O perdão é a maior prova de amor.
2. Tudo está consumado: Ele cumpriu a missão até o fim. Não deixou nada pela metade.
3. Abrir o Céu: A morte de Jesus não é derrota, e a porta que se abre para a nossa eternidade.'''
        },
      ],
      "Gloriosos": [
        {
          "m": "1º Mistério",
          "t": "Ressurreição de Jesus",
          "f":
          '''""Vós não temais, porque sei que procurais a Jesus, que foi crucificado.
Ele já aqui não está, ressuscitou como tinha dito.[...]"" - Mateus 28,5-6

MEDITAÇÃO: A vitória definitiva da Vida.
1. A Esperança: A morte foi vencida. Não há problema que Deus não possa transformar em vida.
2. Vida Nova: Ressuscitar com Cristo significa deixar para trás o 'homem velho' e seus vícios.
3. A Alegria: O cristao e um povo que vive no Domingo da Ressurreição, não no luto do Sábado.'''
        },
        {
          "m": "2º Mistério",
          "t": "Ascensão de Jesus",
          "f":
          '''"O Senhor, depois que assim lhes falou, elevou-se ao céu, e foi sentar-se à direita de Deus." - Marcos 16,19

MEDITAÇÃO: Nossa meta é o alto.
1. O Destino: Jesus foi na frente para nos preparar um lugar. Nossa casa não é aqui.
2. A Missão: Ele sobe, mas nos deixa a tarefa de sermos Suas mãos e pés na terra.
3. Confiança: Ele subiu, mas prometeu estar conosco todos os dias até o fim dos tempos.'''
        },
        {
          "m": "3º Mistério",
          "t": "Vinda do Espírito Santo",
          "f":
          '''"E apareceram-lhes repartidas umas como línguas de fogo, das quais pousou uma sobre cada um deles.
Ficaram todos cheios do Espirito Santo e começaram a falar várias línguas, conforme o Espírito Santo lhes concedia que falassem" - Atos 2,3-4

MEDITAÇÃO: O fogo que transforma.
1. O Medo vencido: Os apóstolos estavam escondidos; o Espírito os faz sair para o mundo.
2. A Unidade: O Espírito Santo une o que estava disperso e nos faz falar a língua do amor.
3. Os Dons: Cada um recebeu um talento para colocar a serviço da comunidade. Qual é o seu?'''
        },
        {
          "m": "4º Mistério",
          "t": "Assunção de Maria",
          "f":
          '''"A imaculada Mãe de Deus, a sempre virgem Maria, terminado o curso da vida terrestre, foi assunta em corpo e alma à glória celestial." - Pio XII, Munificentissimus Deus, 1º de novembro de 1950

MEDITAÇÃO: A recompensa da fidelidade.
1. O Prêmio: Maria serviu a Deus com perfeição e por isso é levada à glória eterna.
2. O Corpo Sagrado: Aquela que carregou o Verbo não conheceu a corrupção do sepulcro.
3. Nossa Esperança: O que aconteceu com Maria e a promessa do que Deus quer fazer conosco.'''
        },
        {
          "m": "5º Mistério",
          "t": "Coroação de Maria",
          "f":
          '''"Depois apareceu no céu um grande sinal: uma Mulher vestida de sol, com a lua debaixo de seus pés, e uma coroa de doze estrelas sobre a sua cabeça." - Apocalipse 12,1

MEDITAÇÃO: A Rainha que intercede.
1. Realeza de Serviço: Maria reina servindo e cuidando de seus filhos na terra.
2. Confiança de Filho: Temos uma Mãe no céu que olha por nós. Nunca estamos órfãos.
3. O Triunfo: No fim, o Imaculado Coração dela triunfará em nossas vidas.'''
        },
      ],
      "Luminosos": [
        {
          "m": "1º Mistério",
          "t": "Batismo de Jesus",
          "f":
          '''"Logo que foi baptizado, Jesus saiu da água. E eis que se abriram os céus, e viu o Espírito de Deus descer como pomba, e vir sobre ele. E eis (que se ouviu) uma voz do céu, que dizia: "Este é o meu Filho amado, no qual pus as minhas complacências."" - Mateus 3,16-17

MEDITAÇÃO: A identidade dos filhos.
1. Exemplo: Jesus não precisava, mas se batiza para santificar nossas águas.
2. Voz do Pai: Deus nos chama de 'filhos amados' todos os dias. Você acredita nisso?
3. Compromisso: O batismo nos chama a viver uma vida de luz e afastada do mal.'''
        },
        {
          "m": "2º Mistério",
          "t": "Bodas de Caná",
          "f":
          '''"Disse sua Mãe aos que serviam: "Fazei tudo o que ele vos disser."" - João 2,5

MEDITAÇÃO: A transformação da nossa água em vinho.
1. A Intercessão: Maria percebe nossa necessidade antes mesmo de pedirmos.
2. A Obediência: O milagre só acontece quando os servos obedecem a ordem de Jesus.
3. A Alegria: Jesus quer estar presente em nossas festas e momentos de felicidade, não só na dor.'''
        },
        {
          "m": "3º Mistério",
          "t": "Anúncio do Reino",
          "f":
          '''"Está completo o tempo e aproxima-se o reino de Deus; fazei penitência, crede no Evangelho." - Marcos 1,15

MEDITAÇÃO: O convite à conversão.
1. Mudança de Rumo: Arrepender-se é decidir caminhar na direção de Deus.
2. O Reino dentro de nós: O Reino não é um lugar geográfico, mas Deus reinando em nosso coração.
3. Anúncio: Todo cristão é chamado a ser um missionário da boa notícia.'''
        },
        {
          "m": "4º Mistério",
          "t": "Transfiguração",
          "f":
          '''"E transfigurou-se diante deles. O seu rosto ficou refulgente como o sol, e as suas vestiduras tornaram-se luminosas de brancas que estavam." - Mateus 17,2

MEDITAÇÃO: Um vislumbre da glória.
1. Força para a Cruz: Jesus mostra Sua glória para que os discípulos aguentem o sofrimento que virá.
2. Escutar Jesus: 'Ouvi-o'. A vida espiritual consiste em silenciar para ouvir a voz do Mestre.
3. O Tabor e a Vida: Não podemos ficar apenas na montanha; devemos descer e transformar o mundo.'''
        },
        {
          "m": "5º Mistério",
          "t": "Instituição da Eucaristia",
          "f":
          '''"Depois tomou o pão, deu graças, partiu, e deu-lho, dizendo: "Isto é o meu corpo, que é dado por vós; fazei isto em memória de mim." - Lucas 22,19

MEDITAÇÃO: O Deus que se faz alimento.
1. Presença Real: Jesus não nos deixou sozinhos; Ele se esconde no pão para estar conosco.
2. Entrega: 'Dado por vós'. A Eucaristia nos ensina a também sermos doação para os outros.
3. União: Ao comungar, nos tornamos um só corpo com Cristo e com nossos irmãos.'''
        },
      ],
    };

    _meditacaoExpandidaChave = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) => _GlassSheet(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Column(
              children: [
                const SizedBox(height: 10),
                const _Handle(),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 TÍTULO (sozinho)
                      Text(
                        "Mistérios $grupo",
                        style: _title.copyWith(color: cor),
                      ),

                      const SizedBox(height: 6),

                      // 🔹 SUBTÍTULO + LIMPAR
                      Row(
                        children: [
                          Text(
                            "toque para selecionar",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              await _limparSelecao();
                              modalSetState(() {});
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: vinhoIdentidade,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(40, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "LIMPAR",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(color: Colors.black.withOpacity(0.08), height: 18),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: 5,
                    separatorBuilder: (context, index) => Divider(
                      height: 22,
                      color: Colors.black.withOpacity(0.06),
                    ),
                    itemBuilder: (context, index) {
                      final m = dadosMisterios[grupo]![index];
                      final titulo = m['t']!;
                      final chave = "$grupo|$titulo";
                      final isSelected = _misteriosSelecionados.contains(chave);
                      final isExpanded = _meditacaoExpandidaChave == chave;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(rCard),
                          onTap: () async {
                            await _toggleSelecaoMist(grupo, titulo);
                            _meditacaoExpandidaChave = null;
                            modalSetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? vinhoSelecionado : cardBase,
                              borderRadius: BorderRadius.circular(rCard),
                              border: Border.all(
                                color: isSelected
                                    ? vinhoSelecionado.withOpacity(0.55)
                                    : Colors.black.withOpacity(0.06),
                              ),
                              boxShadow: [_softShadow],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['m']!,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white.withOpacity(0.95) : cor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        titulo,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: isSelected ? Colors.white : Colors.black.withOpacity(0.82),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Icon(Icons.check_rounded, color: Colors.white.withOpacity(0.95)),
                                      ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () {
                                        modalSetState(() {
                                          _meditacaoExpandidaChave = isExpanded ? null : chave;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: AnimatedRotation(
                                          duration: const Duration(milliseconds: 180),
                                          turns: isExpanded ? 0.5 : 0.0,
                                          child: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 24,
                                            color: isSelected
                                                ? Colors.white.withOpacity(0.95)
                                                : Colors.black.withOpacity(0.45),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                AnimatedCrossFade(
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      m['f']!,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.85)
                                            : Colors.black.withOpacity(0.62),
                                        fontStyle: FontStyle.italic,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                  crossFadeState: isExpanded
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 180),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abrirGuiaComoRezar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => _GlassSheet(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.86,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const _Handle(),
              const SizedBox(height: 10),
              Text("Como Rezar o Terço", style: _title),
              const SizedBox(height: 10),
              Divider(color: Colors.black.withOpacity(0.08), height: 18),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _lockSheetScroll,
                  builder: (context, locked, _) {
                    return ListView(
                      physics: locked
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        _TercoInterativoGuia(
                          misterioDoDiaLabel: _labelMisterioDoDia(),
                          onInteractionLockChanged: (v) => _lockSheetScroll.value = v,
                        ),

                        const SizedBox(height: 10),
                        Text(
                          "Siga pelo botão PRÓXIMA — o card abaixo do terço mostra a oração completa do passo atual",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.3,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Widgets auxiliares do Terço =====

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.child});
  final Widget child;

  static const double rSheet = 30;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(rSheet)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(rSheet)),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PassoTerco extends StatelessWidget {
  const _PassoTerco({required this.numero, required this.titulo, required this.desc});

  final String numero;
  final String titulo;
  final String desc;

  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: vinhoDestaque.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: vinhoDestaque.withOpacity(0.16)),
            ),
            child: Center(
              child: Text(
                numero,
                style: const TextStyle(
                  color: vinhoIdentidade,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.black.withOpacity(0.82),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====== TERÇO INTERATIVO (GUIA) — BLOCO COMPLETO ======

class _TercoInterativoGuia extends StatefulWidget {
  const _TercoInterativoGuia({
    required this.misterioDoDiaLabel,
    this.onInteractionLockChanged,
  });

  final String misterioDoDiaLabel;
  final ValueChanged<bool>? onInteractionLockChanged;

  @override
  State<_TercoInterativoGuia> createState() => _TercoInterativoGuiaState();
}


class _TercoInterativoGuiaState extends State<_TercoInterativoGuia> with TickerProviderStateMixin {
  static const Color vinhoIdentidade = Color(0xFF6A0F0F);
  static const Color vinhoDestaque = Color(0xFF8E2A2A);
  static const Color vinhoSelecionado = Color(0xFFB44A4A);
  static const Color paper = Color(0xFFFBFAF8);

  final TransformationController _tc = TransformationController();

  late final AnimationController _animCtrl;
  Animation<Matrix4>? _matrixAnim;

  late final AnimationController _pulseCtrl;

  ui.Image? _medalImage;

  int _selected = 0;
  final Set<int> _marcadas = {};
  _OverlayStep? _overlay;

  Size _viewportSize = Size.zero;
  Size _sceneSize = Size.zero;
  Size _lastViewport = Size.zero;
  bool _worldReady = false;

  bool get _tercoConcluido {
    return _overlay != null && _overlay!.kind == _OverlayStepKind.gloriaDecade && _overlay!.decade == 5;
  }

  List<_Bead> _beads = const [];
  List<int> _ordem = const [];

  static const double _autoZoom = 2.25;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..addListener(() {
      final a = _matrixAnim;
      if (a != null) _tc.value = a.value;
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _loadMedalImage();
  }

  Future<void> _loadMedalImage() async {
    final data = await rootBundle.load('assets/images/logo_atos29_branco.png');
    final bytes = data.buffer.asUint8List();

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    if (!mounted) return;
    setState(() => _medalImage = frame.image);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _animCtrl.dispose();
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marcadasAve = _countMarkedAll();
    final bead = (_selected >= 0 && _selected < _beads.length) ? _beads[_selected] : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 26,
            offset: const Offset(0, 14),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spa_rounded, color: vinhoIdentidade.withOpacity(0.92), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Terço interativo",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black.withOpacity(0.84),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Mistérios do dia: ${widget.misterioDoDiaLabel}",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),

                  ],
                ),

              ),
              _miniIconButton(
                icon: Icons.center_focus_strong_rounded,
                tooltip: "Centralizar",
                onTap: () => _ensureCentered(animated: true),
              ),
              const SizedBox(width: 6),
              _miniIconButton(
                icon: Icons.restart_alt_rounded,
                tooltip: "Reiniciar",
                onTap: _reset,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill("Ave-Marias", "$marcadasAve/50"),
              _pill("Agora", _shortStatus(bead)),
            ],
          ),
          const SizedBox(height: 12),
          Listener(
            onPointerDown: (_) => widget.onInteractionLockChanged?.call(true),
            onPointerUp: (_) => widget.onInteractionLockChanged?.call(false),
            onPointerCancel: (_) => widget.onInteractionLockChanged?.call(false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 330,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [paper, Colors.white],
                  ),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final vp = Size(c.maxWidth, c.maxHeight);

                    if (_lastViewport != vp) {
                      _lastViewport = vp;
                      _viewportSize = vp;

                      _sceneSize = Size(_viewportSize.width * 2.4, _viewportSize.height * 2.8);

                      _beads = _RosaryLayout.generate(_sceneSize);
                      _ordem = _RosaryLayout.buildPrayerOrder(_beads);

                      if (_selected < 0 || _selected >= _beads.length) _selected = 0;

                      _worldReady = true;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _ensureCentered(animated: false, forceZoom: true);
                      });
                    }

                    return Stack(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            if (!_worldReady) return;
                            final scenePoint = _tc.toScene(d.localPosition);
                            final hit = _hitTest(scenePoint, _beads);
                            if (hit != null) _selectAndCenter(hit);
                          },
                          onDoubleTap: () => _zoomBy(1.18),
                          child: InteractiveViewer(
                            transformationController: _tc,
                            constrained: false,
                            clipBehavior: Clip.none,
                            boundaryMargin: const EdgeInsets.all(800),
                            minScale: 0.6,
                            maxScale: 7.0,
                            panEnabled: true,
                            scaleEnabled: true,
                            child: CustomPaint(
                              size: _sceneSize,
                              painter: _TercoPainter(
                                beads: _beads,
                                selected: _selected,
                                marcadas: _marcadas,
                                pulse: _pulseCtrl,
                                medalImage: _medalImage,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Column(
                            children: [
                              _floatCtl(Icons.add_rounded, "Zoom +", () => _zoomBy(1.18)),
                              const SizedBox(height: 8),
                              _floatCtl(Icons.remove_rounded, "Zoom -", () => _zoomBy(1 / 1.18)),
                              const SizedBox(height: 8),
                              _floatCtl(Icons.my_location_rounded, "Centralizar",
                                      () => _ensureCentered(animated: true)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _prev,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text("ANTERIOR"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: vinhoIdentidade,
                    side: BorderSide(color: vinhoDestaque.withOpacity(0.22)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _marcarEProxima,
                  icon: Icon(_tercoConcluido ? Icons.check_circle_rounded : Icons.chevron_right_rounded),
                  label: Text(_tercoConcluido ? "FIM" : "PRÓXIMA"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vinhoIdentidade,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatusTerco(info: _getStatus()),
        ],
      ),
    );
  }

  // ====== UI helpers ======

  Widget _miniIconButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withOpacity(0.03),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Icon(icon, size: 20, color: Colors.black.withOpacity(0.55)),
          ),
        ),
      ),
    );
  }

  Widget _pill(String a, String b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: vinhoDestaque.withOpacity(0.06),
        border: Border.all(color: vinhoDestaque.withOpacity(0.14)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withOpacity(0.78),
          ),
          children: [
            TextSpan(text: "$a: ", style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: b, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _floatCtl(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.92),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.black.withOpacity(0.62)),
          ),
        ),
      ),
    );
  }

  void _selectAndCenter(int idx) {
    if (!_worldReady) return;
    if (idx < 0 || idx >= _beads.length) return;

    _animCtrl.stop();
    _matrixAnim = null;

    setState(() => _selected = idx);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureCentered(animated: true);
    });
  }

  void _reset() {
    _animCtrl.stop();
    _matrixAnim = null;

    setState(() {
      _selected = 0;
      _marcadas.clear();
      _overlay = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureCentered(animated: true, forceZoom: true);
    });
  }

  void _prev() {
    final i = _ordem.indexOf(_selected);
    if (i <= 0) return;
    _selectAndCenter(_ordem[i - 1]);
  }

  void _marcarEProxima() {
    if (_tercoConcluido) return;

    if (_overlay != null) {
      setState(() => _overlay = null);

      final i = _ordem.indexOf(_selected);
      if (i < 0 || i >= _ordem.length - 1) return;
      _selectAndCenter(_ordem[i + 1]);
      return;
    }

    if (_selected < 0 || _selected >= _beads.length) return;

    final b = _beads[_selected];

    if (b.kind == _BeadKind.small && b.section == _BeadSection.loop) {
      _marcadas.add(_selected);

      if (b.aveIndex == 10) {
        setState(() {
          _overlay = _OverlayStep(_OverlayStepKind.gloriaDecade, decade: b.decade);
        });
        return;
      }
    }

    final i = _ordem.indexOf(_selected);
    if (i < 0 || i >= _ordem.length - 1) return;
    _selectAndCenter(_ordem[i + 1]);
  }

  void _ensureCentered({required bool animated, bool forceZoom = false}) {
    if (_viewportSize == Size.zero || _sceneSize == Size.zero) return;
    if (_selected < 0 || _selected >= _beads.length) return;

    final target = _matrixToCenterOn(_beads[_selected].pos, forceZoom: forceZoom);

    if (!animated) {
      _tc.value = target;
      return;
    }

    _animCtrl.stop();
    _animCtrl.reset();

    _matrixAnim = Matrix4Tween(begin: _tc.value.clone(), end: target).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );

    _animCtrl.forward();
  }

  Matrix4 _matrixToCenterOn(Offset scenePoint, {bool forceZoom = false}) {
    final currentScale = _tc.value.getMaxScaleOnAxis();
    final scale = forceZoom ? _autoZoom : (currentScale == 0 ? _autoZoom : currentScale);

    final vx = _viewportSize.width / 2;
    final vy = _viewportSize.height / 2;

    final tx = vx - scenePoint.dx * scale;
    final ty = vy - scenePoint.dy * scale;

    return Matrix4.identity()
      ..translate(tx, ty)
      ..scale(scale);
  }

  void _zoomBy(double factor) {
    if (_viewportSize == Size.zero) return;

    _animCtrl.stop();
    _matrixAnim = null;

    final current = _tc.value.clone();
    final scale = current.getMaxScaleOnAxis();
    final nextScale = (scale * factor).clamp(0.75, 6.0);

    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final before = _tc.toScene(center);

    final target = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(nextScale)
      ..translate(-before.dx, -before.dy);

    _animCtrl.reset();
    _matrixAnim = Matrix4Tween(begin: _tc.value.clone(), end: target).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
  }

  int? _hitTest(Offset p, List<_Bead> beads) {
    int? bestIdx;
    double bestDist = double.infinity;

    for (var i = 0; i < beads.length; i++) {
      final d = (beads[i].pos - p).distance;
      final r = switch (beads[i].kind) {
        _BeadKind.cross => 26.0,
        _BeadKind.medal => 30.0,
        _BeadKind.large => 22.0,
        _BeadKind.small => 20.0,
      };
      if (d < r && d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  int _countMarkedAll() {
    int c = 0;
    for (final idx in _marcadas) {
      if (idx >= 0 && idx < _beads.length) {
        final b = _beads[idx];
        if (b.section == _BeadSection.loop && b.kind == _BeadKind.small) c++;
      }
    }
    return c;
  }

  String _shortStatus(_Bead? b) {
    if (b == null) return "Toque para selecionar";
    if (b.kind == _BeadKind.cross) return "Cruz • Credo";
    if (b.kind == _BeadKind.medal) return "Medalha • Mistério";
    if (b.section == _BeadSection.stem) return "Início";
    if (b.section == _BeadSection.loop && b.kind == _BeadKind.large) return "Dezena ${b.decade} • Pai Nosso";
    if (b.section == _BeadSection.loop && b.kind == _BeadKind.small) return "Dezena ${b.decade} • Ave ${b.aveIndex}/10";
    return "Terço";
  }

  _TercoStatus _getStatus() {
    if (_overlay != null && _overlay!.kind == _OverlayStepKind.gloriaDecade) {
      final d = _overlay!.decade ?? 0;
      final isUltima = d == 5;

      return _TercoStatus(
        titulo: isUltima ? "Conclusão do Terço" : "Após a Dezena $d",
        subtitulo: isUltima
            ? "Glória ao Pai e orações finais."
            : "Agora reze: Glória ao Pai (e, se quiser, Ó meu Jesus).",
        oracao: isUltima
            ? "Glória ao Pai, ao Filho e ao Espírito Santo. Como era no princípio, agora e sempre. Amém.\n\n"
            "Ó meu Jesus, perdoai-nos, livrai-nos do fogo do inferno, levai as almas todas para o céu "
            "e socorrei principalmente as que mais precisarem.\n\n"
            "Infinitas graças vos damos, soberana Rainha, pelos benefícios que todos os dias recebemos "
            "de vossas mãos liberais. Dignai-vos, agora e para sempre, tomar-nos debaixo de vosso poderoso "
            "amparo e para mais vos obrigar, vos saudamos com uma Salve-Rainha:\n\n"
            "Salve, Rainha, Mãe de misericórdia, vida, doçura e esperança nossa, salve! "
            "A vós bradamos, os degredados filhos de Eva; a vós suspiramos, gemendo e chorando neste vale de lágrimas. "
            "Eia, pois, advogada nossa, esses vossos olhos misericordiosos a nós volvei; e depois deste desterro "
            "mostrai-nos Jesus, bendito fruto do vosso ventre. Ó clemente, ó piedosa, ó doce sempre Virgem Maria."
            : "Glória ao Pai, ao Filho e ao Espírito Santo. Como era no princípio, agora e sempre. Amém.\n\n"
            "Ó meu Jesus, perdoai-nos, livrai-nos do fogo do inferno, levai as almas todas para o céu "
            "e socorrei principalmente as que mais precisarem.",
      );
    }

    final b = (_selected >= 0 && _selected < _beads.length) ? _beads[_selected] : null;
    if (b == null) {
      return const _TercoStatus(
        titulo: "Terço",
        subtitulo: "Toque em uma conta para selecionar.",
        oracao: "",
      );
    }

    if (b.kind == _BeadKind.cross) {
      return const _TercoStatus(
        titulo: "Cruz",
        subtitulo: "Sinal da Cruz e Credo.",
        oracao: "Em nome do Pai, do Filho e do Espírito Santo. Amém.\n\n"
            "Creio em Deus Pai todo-poderoso, criador do céu e da terra; e em Jesus Cristo, seu único Filho, nosso Senhor...",
      );
    }

    if (b.section == _BeadSection.stem) {
      final si = b.stemIndex;

      if (si == 0) {
        return const _TercoStatus(
          titulo: "Conta grande",
          subtitulo: "Reze o Pai Nosso.",
          oracao: "Pai nosso que estais no céu, santificado seja o vosso nome; venha a nós o vosso reino; "
              "seja feita a vossa vontade, assim na terra como no céu. O pão nosso de cada dia nos dai hoje; "
              "perdoai as nossas ofensas, assim como nós perdoamos a quem nos tem ofendido; e não nos deixeis cair em tentação, "
              "mas livrai-nos do mal. Amém.",
        );
      }

      if (si >= 1 && si <= 3) {
        return const _TercoStatus(
          titulo: "Contas pequenas",
          subtitulo: "Reze 3 Ave-Marias (uma em cada conta).",
          oracao: "Ave Maria, cheia de graça, o Senhor é convosco; bendita sois vós entre as mulheres e bendito é o fruto "
              "do vosso ventre, Jesus. Santa Maria, Mãe de Deus, rogai por nós, pecadores, agora e na hora da nossa morte. Amém.",
        );
      }

      if (si == 4) {
        return const _TercoStatus(
          titulo: "Antes do Mistério",
          subtitulo: "Reze o Glória ao Pai.",
          oracao: "Glória ao Pai, ao Filho e ao Espírito Santo. Como era no princípio, agora e sempre. Amém.",
        );
      }

      if (si == 5 || b.kind == _BeadKind.medal) {
        return const _TercoStatus(
          titulo: "Medalha",
          subtitulo: "Anuncie o Mistério do dia e inicie a Dezena 1.",
          oracao: "Anuncie o mistério (ex.: “A Anunciação”).\nIntenções: coloque suas intenções diante do Senhor.\n"
              "Depois siga para a conta grande da Dezena 1 (Pai Nosso).",
        );
      }
    }

    if (b.section == _BeadSection.loop) {
      if (b.kind == _BeadKind.large) {
        return _TercoStatus(
          titulo: "Dezena ${b.decade}",
          subtitulo: "Conta grande: Pai Nosso.",
          oracao: "Pai nosso que estais no céu, santificado seja o vosso nome; venha a nós o vosso reino; "
              "seja feita a vossa vontade, assim na terra como no céu. O pão nosso de cada dia nos dai hoje; "
              "perdoai as nossas ofensas, assim como nós perdoamos a quem nos tem ofendido; e não nos deixeis cair em tentação, "
              "mas livrai-nos do mal. Amém.",
        );
      }

      if (b.kind == _BeadKind.small) {
        final marcadasNaDezena = _countMarkedInDecade(b.decade);
        final extra = (b.aveIndex == 10) ? "Ao concluir esta, o próximo passo será: Glória ao Pai." : "Siga para a próxima conta.";

        return _TercoStatus(
          titulo: "Dezena ${b.decade}",
          subtitulo: "Ave Maria ${b.aveIndex}/10 • marcadas: $marcadasNaDezena/10",
          oracao: "Ave Maria, cheia de graça, o Senhor é convosco; bendita sois vós entre as mulheres e bendito é o fruto "
              "do vosso ventre, Jesus. Santa Maria, Mãe de Deus, rogai por nós, pecadores, agora e na hora da nossa morte. "
              "Amém.\n\n$extra",
        );
      }
    }

    return const _TercoStatus(
      titulo: "Terço",
      subtitulo: "Toque em uma conta para selecionar.",
      oracao: "",
    );
  }

  int _countMarkedInDecade(int decade) {
    int c = 0;
    for (final idx in _marcadas) {
      if (idx >= 0 && idx < _beads.length) {
        final b = _beads[idx];
        if (b.section == _BeadSection.loop && b.kind == _BeadKind.small && b.decade == decade) c++;
      }
    }
    return c;
  }
}

// ====== STATUS CARD ======

class _StatusTerco extends StatelessWidget {
  const _StatusTerco({required this.info});
  final _TercoStatus info;

  static const Color vinhoIdentidade = Color(0xEB4E070D);
  static const Color vinhoDestaque = Color(0xFF560405);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: vinhoDestaque.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vinhoDestaque.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.titulo,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black.withOpacity(0.82),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info.subtitulo,
            style: TextStyle(
              color: Colors.black.withOpacity(0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (info.oracao.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              info.oracao,
              style: TextStyle(
                color: Colors.black.withOpacity(0.72),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TercoStatus {
  const _TercoStatus({
    required this.titulo,
    required this.subtitulo,
    required this.oracao,
  });

  final String titulo;
  final String subtitulo;
  final String oracao;
}

// ====== MODELOS ======

enum _BeadKind { cross, medal, large, small }
enum _BeadSection { stem, loop }

enum _OverlayStepKind { gloriaDecade }

class _OverlayStep {
  const _OverlayStep(this.kind, {this.decade});
  final _OverlayStepKind kind;
  final int? decade;
}

class _Bead {
  const _Bead({
    required this.pos,
    required this.kind,
    required this.section,
    this.stemIndex = -1,
    this.decade = 0,
    this.aveIndex = 0,
  });

  final Offset pos;
  final _BeadKind kind;
  final _BeadSection section;

  final int stemIndex;
  final int decade;
  final int aveIndex;
}

// ====== LAYOUT DO TERÇO ======

class _RosaryLayout {
  static List<_Bead> generate(Size size) {
    final beads = <_Bead>[];

    final cx = size.width * 0.30;
    final bottom = size.height * 0.80;
    final medalY = size.height * 0.44;

    beads.add(_Bead(
      pos: Offset(cx, bottom),
      kind: _BeadKind.cross,
      section: _BeadSection.stem,
      stemIndex: -1,
    ));

    final stemGap = (bottom - medalY) / 7.0;

    beads.add(_Bead(
      pos: Offset(cx, bottom - stemGap * 1.3),
      kind: _BeadKind.large,
      section: _BeadSection.stem,
      stemIndex: 0,
    ));

    for (var i = 0; i < 3; i++) {
      beads.add(_Bead(
        pos: Offset(cx, bottom - stemGap * (2.5 + i)),
        kind: _BeadKind.small,
        section: _BeadSection.stem,
        stemIndex: 1 + i,
      ));
    }

    beads.add(_Bead(
      pos: Offset(cx, bottom - stemGap * 6.0),
      kind: _BeadKind.large,
      section: _BeadSection.stem,
      stemIndex: 4,
    ));

    final medalPos = Offset(cx, medalY);
    beads.add(_Bead(
      pos: medalPos,
      kind: _BeadKind.medal,
      section: _BeadSection.stem,
      stemIndex: 5,
    ));

    final loopCx = cx;

    final w = size.width * 0.58;
    final h = size.height * 0.78;

    const double gap = 48.0;
    final bottomLoopTarget = medalY - gap;
    final loopCy = bottomLoopTarget - (h * 0.5);

    final left = loopCx - w * 0.5;
    final right = loopCx + w * 0.5;
    final top = loopCy - h * 0.5;
    final bottomLoop = loopCy + h * 0.5;

    final path = Path()
      ..moveTo(loopCx, top)
      ..cubicTo(
        loopCx + w * 0.48, top + h * 0.05,
        right, loopCy - h * 0.18,
        right, loopCy + h * 0.08,
      )
      ..cubicTo(
        right, loopCy + h * 0.42,
        loopCx + w * 0.30, bottomLoop,
        loopCx, bottomLoop,
      )
      ..cubicTo(
        loopCx - w * 0.30, bottomLoop,
        left, loopCy + h * 0.42,
        left, loopCy + h * 0.08,
      )
      ..cubicTo(
        left, loopCy - h * 0.18,
        loopCx - w * 0.48, top + h * 0.05,
        loopCx, top,
      )
      ..close();

    final metric = path.computeMetrics().first;
    final totalLength = metric.length;

    const beadsPerDecade = 11;
    const int decades = 5;
    const int avesPerDecade = 10;

    const double minGap = 14.0;

    final loopLength = totalLength;
    final decadeLength = loopLength / decades;

    final positions = <Offset>[];
    double cursor = loopLength;

    for (int d = 0; d < decades; d++) {
      final pnTangent = metric.getTangentForOffset(cursor % loopLength);
      if (pnTangent != null) {
        positions.add(pnTangent.position);
      }

      final usable = decadeLength - (minGap * 2);
      final aveStep = usable / avesPerDecade;

      double aveCursor = cursor - minGap - (aveStep / 2);

      for (int i = 0; i < avesPerDecade; i++) {
        final aveTangent = metric.getTangentForOffset(aveCursor % loopLength);
        if (aveTangent != null) {
          positions.add(aveTangent.position);
        }
        aveCursor -= aveStep;
      }

      cursor -= decadeLength;
    }

    int entry = 0;
    double bestScore = double.infinity;

    for (int i = 0; i < positions.length; i++) {
      final p = positions[i];
      if (p.dy >= medalPos.dy) continue;

      final dx = (p.dx - medalPos.dx).abs();
      final dy = (medalPos.dy - p.dy);

      final score = dx * 3.0 + dy * 0.5;

      if (score < bestScore) {
        bestScore = score;
        entry = i;
      }
    }

    final rotated = <Offset>[
      ...positions.sublist(entry),
      ...positions.sublist(0, entry),
    ];

    if (rotated.isNotEmpty) {
      rotated[0] = Offset(medalPos.dx, rotated[0].dy);
    }

    for (int i = 0; i < rotated.length; i++) {
      final decade = (i ~/ beadsPerDecade) + 1;
      final within = i % beadsPerDecade;

      if (within == 0) {
        beads.add(_Bead(
          pos: rotated[i],
          kind: _BeadKind.large,
          section: _BeadSection.loop,
          decade: decade,
        ));
      } else {
        beads.add(_Bead(
          pos: rotated[i],
          kind: _BeadKind.small,
          section: _BeadSection.loop,
          decade: decade,
          aveIndex: within,
        ));
      }
    }

    int? idxAveFinal5;
    int? idxAveInicial1;
    int? idxPaiNosso1;

    for (int i = 0; i < beads.length; i++) {
      final b = beads[i];

      if (b.section == _BeadSection.loop && b.kind == _BeadKind.small && b.decade == 5 && b.aveIndex == 10) {
        idxAveFinal5 = i;
      }

      if (b.section == _BeadSection.loop && b.kind == _BeadKind.small && b.decade == 1 && b.aveIndex == 1) {
        idxAveInicial1 = i;
      }

      if (b.section == _BeadSection.loop && b.kind == _BeadKind.large && b.decade == 1) {
        idxPaiNosso1 = i;
      }
    }

    if (idxAveFinal5 != null && idxAveInicial1 != null && idxPaiNosso1 != null) {
      final p1 = beads[idxAveFinal5].pos;
      final p2 = beads[idxAveInicial1].pos;

      final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);

      final b = beads[idxPaiNosso1];

      beads[idxPaiNosso1] = _Bead(
        pos: center,
        kind: b.kind,
        section: b.section,
        stemIndex: b.stemIndex,
        decade: b.decade,
        aveIndex: b.aveIndex,
      );
    }

    const double dx = 18.0;

    for (int i = 0; i <= 6 && i < beads.length; i++) {
      final b = beads[i];
      beads[i] = _Bead(
        pos: Offset(b.pos.dx + dx, b.pos.dy),
        kind: b.kind,
        section: b.section,
        stemIndex: b.stemIndex,
        decade: b.decade,
        aveIndex: b.aveIndex,
      );
    }

    return beads;
  }

  static List<int> buildPrayerOrder(List<_Bead> beads) {
    final order = <int>[];
    if (beads.isEmpty) return order;

    final stemEnd = math.min(6, beads.length - 1);
    for (int i = 0; i <= stemEnd; i++) {
      order.add(i);
    }

    for (int i = 7; i < beads.length; i++) {
      order.add(i);
    }

    return order;
  }
}

// ====== PAINTER ======

class _TercoPainter extends CustomPainter {
  _TercoPainter({
    required this.beads,
    required this.selected,
    required this.marcadas,
    required this.pulse,
    required this.medalImage,
  }) : super(repaint: pulse);

  final ui.Image? medalImage;

  final List<_Bead> beads;
  final int selected;
  final Set<int> marcadas;
  final Animation<double> pulse;

  static const Color vinhoIdentidade = Color(0xFF560808);
  static const Color vinhoDestaque = Color(0xFF6B1515);
  static const Color vinhoSelecionado = Color(0xFF560808);
  static const Color paper = Color(0xFFFBFAF8);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [Colors.transparent, Colors.black.withOpacity(0.05)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    final chain = Paint()
      ..color = Colors.black.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final stemPts = beads.take(math.min(7, beads.length)).map((b) => b.pos).toList();
    if (stemPts.length >= 2) {
      canvas.drawPath(_smoothPathFromPoints(stemPts, close: false), chain);
    }

    if (beads.length > 7) {
      canvas.drawLine(beads[6].pos, beads[7].pos, chain);
    }

    if (beads.length > 8) {
      final loopPts = <Offset>[];
      for (int i = 7; i < beads.length; i++) {
        loopPts.add(beads[i].pos);
      }
      canvas.drawPath(_smoothPathFromPoints(loopPts, close: true), chain);
    }

    final p = pulse.value;

    for (int i = 0; i < beads.length; i++) {
      final b = beads[i];
      final isSel = i == selected;
      final isMarked = marcadas.contains(i);

      if (isSel) {
        final halo = Paint()..color = vinhoSelecionado.withOpacity(0.10 + p * 0.06);
        canvas.drawCircle(b.pos, 30 + p * 6, halo);
      }

      switch (b.kind) {
        case _BeadKind.cross:
          _drawCross(canvas, b.pos, selected: isSel);
          break;
        case _BeadKind.medal:
          _drawMedal(canvas, b.pos, selected: isSel);
          break;
        case _BeadKind.large:
          _drawBead(canvas, b.pos, isLarge: true, selected: isSel, marked: false);
          break;
        case _BeadKind.small:
          _drawBead(canvas, b.pos, isLarge: false, selected: isSel, marked: isMarked);
          break;
      }
    }
  }

  Path _smoothPathFromPoints(List<Offset> pts, {required bool close}) {
    final path = Path();
    if (pts.length < 2) return path;

    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    final last = pts.last;
    path.quadraticBezierTo(last.dx, last.dy, last.dx, last.dy);

    if (close) {
      final first = pts.first;
      final mid = Offset((last.dx + first.dx) / 2, (last.dy + first.dy) / 2);
      path.quadraticBezierTo(last.dx, last.dy, mid.dx, mid.dy);
      path.quadraticBezierTo(first.dx, first.dy, first.dx, first.dy);
      path.close();
    }

    return path;
  }

  void _drawBead(Canvas canvas, Offset c,
      {required bool isLarge, required bool selected, required bool marked}) {
    final r = isLarge ? 12.8 : 9.8;

    canvas.drawCircle(c + const Offset(0, 2), r, Paint()..color = Colors.black.withOpacity(0.10));

    final fill = Paint()
      ..color = selected ? vinhoSelecionado : (marked ? vinhoDestaque.withOpacity(0.18) : Colors.white)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = selected
          ? vinhoSelecionado
          : (marked ? vinhoDestaque.withOpacity(0.42) : Colors.black.withOpacity(0.16))
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3 : 2;

    canvas.drawCircle(c, r, fill);
    canvas.drawCircle(c, r, border);

    canvas.drawCircle(
      c + const Offset(-3, -3),
      isLarge ? 3.8 : 3.2,
      Paint()..color = Colors.white.withOpacity(selected ? 0.18 : 0.10),
    );
  }

  void _drawMedal(Canvas canvas, Offset c, {required bool selected}) {
    final r = 24.0;

    canvas.drawCircle(c + const Offset(0, 2), r, Paint()..color = Colors.black.withOpacity(0.12));

    final fill = Paint()
      ..color = selected ? vinhoSelecionado : vinhoDestaque.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = selected ? vinhoSelecionado : vinhoDestaque.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3 : 2;

    canvas.drawCircle(c, r, fill);
    canvas.drawCircle(c, r, border);

    if (medalImage != null) {
      final imgSize = r * 1.60;

      final src = Rect.fromLTWH(
        0,
        0,
        medalImage!.width.toDouble(),
        medalImage!.height.toDouble(),
      );

      final dst = Rect.fromCenter(
        center: c,
        width: imgSize,
        height: imgSize,
      );

      canvas.drawImageRect(
        medalImage!,
        src,
        dst,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high,
      );
    }
  }

  void _drawCross(Canvas canvas, Offset c, {required bool selected}) {
    canvas.drawCircle(
      c,
      22,
      Paint()..color = (selected ? vinhoSelecionado : Colors.black).withOpacity(0.08),
    );

    final paint = Paint()
      ..color = selected ? vinhoSelecionado : vinhoIdentidade.withOpacity(0.92)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(c + const Offset(0, -18), c + const Offset(0, 18), paint);
    canvas.drawLine(c + const Offset(-12, -2), c + const Offset(12, -2), paint);
  }

  @override
  bool shouldRepaint(covariant _TercoPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.marcadas.length != marcadas.length ||
        oldDelegate.beads.length != beads.length ||
        oldDelegate.medalImage != medalImage;
  }
}
